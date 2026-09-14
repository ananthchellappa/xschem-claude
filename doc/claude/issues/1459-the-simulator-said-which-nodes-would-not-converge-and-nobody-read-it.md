# 1459 — the simulator said which nodes would not converge, and nobody ever read it

**Branch** `fluid-editing`. **Batch** `doc/claude/ase_analyses_batch/`, **PLAN.md Stage 10**,
task 1 of two — the **DECK** half. `src/ase_window.tcl` is untouched; the ladder pane, the
remedy assistant, the canvas highlight and the run-health strip are task 2.

## What goes wrong for the user

`grep -c 'CKTncDump\|Last Node Voltages\|optran\|wrnodev' src/ase.tcl` returned **zero**.
Three things ngspice already prints on every run, and no GUI has ever shown:

* **`CKTncDump`'s `Last Node Voltages` table.** After a failed operating point it prints one
  row per node with a trailing ` *` on **every node that still fails the convergence test**
  (`cktncdump.c:23-39`). `evidence/convergence.md` calls it *"the single most useful
  diagnostic in ngspice for 'why did it not converge'"*. It is on stdout, in the middle of a
  run log, and read by nobody.
* **The four-rung operating-point ladder** (`cktop.c`), which is on **stderr**, and whose
  per-step trace only exists under `set ngdebug`.
* **`optran`** — the fourth rung, **ON BY DEFAULT** since the `cp_init` call at
  `optran.c:643-646` — which hands back **the transient state at its stop time** as your
  operating point.

## The measurement that makes the third one matter

MEASURED 2026-09-13 on **both** binaries (`/usr/bin/ngspice` 45.2 and the `ver_50` fork), on
a 1 kΩ / 1 nF RC driven to 1 V:

| deck | `v(out)` |
|---|---|
| plain `op` | `1.000000e+00` |
| `.options noopiter gminsteps=0 srcsteps=0` → the transient rung answers | **`9.999550e-01`** |

`1 - e^-10 = 0.99995460`. The operating point is wrong in the fifth digit on a *trivial* RC;
on a real bench the error is whatever the slowest time constant has left unsettled at
optran's 10 µs stop, and nothing bounds it. **The only signal is one stderr line no user
sees.**

## Four accepted-and-inert cases, all measured here, all at rc 0

This batch's standing rule is that *"ngspice's usual answer to a request it cannot honour is
to take it and say nothing"*. Stage 10 found four more.

1. **`.options optran 1 1 1 0 10u 0` does nothing.** `optran` is a **command**
   (`commands.c:672-675`) and is absent from `OPTtbl[]`. Three deck spellings were tried and
   all three left `Note: Transient op started` in the log at rc 0 with nothing on either
   stream. The spelling that works is the command inside `.control`.
2. **`optran`'s first three arguments override `.options noopiter / gminsteps / srcsteps` on
   the same task, silently.** A deck carrying both answers the plain-Newton value; three
   option rows the user set did nothing and nobody was told.
3. **`optran 1 1 1 1u 10u 0` silently replaces the step with `finaltime/50`**
   (`optran.c:173-176`), and `optran 1 1 1 20u 10u 0` prints `Error in command 'optran'` and
   **still exits 0**, the run carrying on under whatever settings it had before.
4. **`rusage devtimes` prints nothing at all, in any stock build.** `resource.c:322-335`
   reads `CKTstat->devCounts[]`, written only inside `#ifdef PER_DEVICE_STATS` — and
   `cktload.c:30` is the literal line `// #define PER_DEVICE_STATS`. Every counter is zero,
   the loop `continue`s over all of them, and nothing is printed. On the fork an *unknown*
   keyword at least draws `Note: no resource usage information for …`; `devtimes` draws
   nothing, and apt 45.2 is silent for both. **PLAN.md §10c names it for the health strip.**

## And the "fastest fix" that silently changes the answer

PLAN.md §10c calls `wrnodev` save/restore *"the fastest fix for a bench that takes four
minutes to find its operating point"*. `wrnodev` writes **`.ic`** cards (`com_wr_ic.c:63`),
and `.ic` is an **initial condition** for a transient — not the starting guess it is for an
operating point. ⚠ **This paragraph first said it was *"a clamp applied for every Newton phase
with no `INITF` qualification … never released"*. The driver measured that and it is WRONG**: on a
node with state, the restored run goes `2.499900e+00` → `1.893447e+00` at one time constant →
`1.500000e+00` by twenty, on **both** binaries. The clamp **is** released; what persists is the
initial condition, and the trajectory converges once the circuit forgets it. The original table was
measured **at t = 0 only**, and one point cannot tell those two mechanisms apart. **The hazard, the
two restore modes and the default are all unchanged** — the `.nodeset` respelling was re-verified by
the driver as giving `1.500000e+00` from the first point on both binaries, and an `op` with the
`.ic` file restored is unaffected, which is the whole purpose of `wrnodev`. Only the *reason* was
wrong, and it *changes the
answer*.

MEASURED on both binaries, one bench, one edit:

| run | `v(a)` at t = 0 |
|---|---|
| saved at 5 V | the file says `.ic v(a) = 2.5` |
| re-run at 3 V, no file | `1.500000e+00` ← correct |
| re-run at 3 V, the file `.include`d verbatim | **`2.500000e+00`** ← wrong |
| re-run at 3 V, the same values re-spelt `.nodeset` | `1.500000e+00` ← correct |

rc 0 and nothing on either stream, in all three.

## The fix

`src/ase.tcl` only. Schema in core, content in the adapter (D34/D36).

* **Core** — three state keys (`opstrategy`, `opstate`, `runhealth`, all `{}` by default and
  all in `ase::omit_if_empty`), `ase::ncdump_parse` / `ase::ncdump_failing`,
  `ase::ladder_rungs` / `ase::ladder_parse` / `ase::ladder_ran_notes`, `ase::optran_line`,
  `ase::opstrategy_refusals`, `ase::wrnodev_lines`, `ase::opstate_refusals`,
  `ase::runhealth_lines` / `ase::runhealth_parse`, and the memo `ase::ladder_cache_clear`
  dropped by `ase::register_backend` beside the other two. Not one simulator word.
* **Adapter** — the table's layout, the ladder's literal markers, the four rung labels, the
  `optran` spelling, the `wrnodev` command and the `.nodeset` re-spelling, the `rusage`
  keywords. A backend with no hook gets **no fallback content**: every reader answers `{}`
  and every feature then refuses rather than guessing.
* **Refusals rather than cautions**, at the form and again in `render_deck`'s third tier: the
  `optran`-versus-`.options` clash by row name, every rung off, a transient step the
  simulator would reject or silently replace, a save with no enabled OP row, and a seed
  restore from a file that is not there.
* **The restore's default mode is `seed`**, which re-spells the simulator's own `.ic` file as
  `.nodeset` — released before the final Newton phase, so it can only ever steer. `force` is
  the verbatim `.include`, for a user who means `.ic`.

## Tests

`tests/headless/test_ase_converge_1459.tcl`, **new**, **76 checks on both arms, identical
rows**. Sections NC / LD / OT / WR / RH / DK are canned log text captured verbatim from real
runs (one fixture is `SPLICED` and says so in its own row name); section **EE** runs the real
thing on **both** binaries and asks the **surplus** question — is there a ladder line in that
log this parser has never heard of. `test_ase_core` **636 → 638** (R1's key list 19 → 22,
plus R1x, the non-vacuity half).

## Rulings

⚖ **R9** — the four rung labels, the transient-rung caution, the two "this operating point
came from …" sentences and the seven refusal sentences are new user-facing text and are the
user's. Filed as `owed.sh add rule 1459`; listed verbatim in
`doc/claude/ase_analyses_batch/receipts/36-stage-10-deck.md`.

⚠ **And one correction to the plan's own sentence.** §10b wants *"this operating point may
come from a transient"* on the OP form. Measured: with the shipped defaults the transient
rung is **armed and never called**, because Newton converges above it. Said unconditionally
the sentence would tell a user their exact operating point is suspect when it is exact. It is
**conditional on the run having actually descended the ladder**, which the run itself says —
`ase::ladder_ran_notes`.
