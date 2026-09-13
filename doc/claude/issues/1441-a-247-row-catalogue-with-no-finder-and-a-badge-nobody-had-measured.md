# 1441 — A 247-row catalogue with no finder, and a badge nobody had measured

**Stage 7 task 3 of `doc/claude/ase_analyses_batch/` (`PLAN.md` §7c).** Tasks 1 and 2
landed as `d2f4437a` (issue **1437**, §7a+§7b) and `98beb2b5` (issue **1439**, §7d).
This is the **only one of Stage 7's four tasks that draws a pixel**, and it owns the
plan's largest `look` debt.

## What goes wrong for the user

Issue 1437 gave ASE-L a **247-row** option catalogue and issue 1439 gave it a delivery.
Neither gave the user a way to **find** anything. `Simulation > Options…` was a
two-column list of the rows this bench already stored — an editor, not a finder — so an
option whose name you had not already typed was unreachable from the GUI entirely. And
nothing anywhere told you **where** a setting would be written, or whether it would
arrive at all.

## ⚠ AND THE BADGE THE PLAN ASKS FOR HAD NO MEASUREMENT BEHIND IT

`PLAN.md` §7c-5 asks for *"a ⚠ badge on every `results 1` row — the 21 options that
change numbers"*. Issue 1437 shipped `group`, `scope` and `results` **0 / 247 verified**
and said so in its own receipt: all three are **transcribed** out of
`evidence/hidden-vars.md` §2.1 and `evidence/options.md` §10.2. A badge is an
assertion; an assertion with a transcription behind it is a guess in a uniform.

**All 22 `results` rows were probed on BOTH preflight binaries** —
`/usr/bin/ngspice` (`ngspice-45.2`) and `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(`ngspice-46+`) — on 2026-09-13, each on a deck built to make its own documented
mechanism fire. Every value below was identical on the two.

**MEASURED to move a printed value — 9 rows:**

| option | measured |
|---|---|
| `scale` | `.options scale=0.5` → `@m1[w]` 2.000000e-06 → 1.000000e-06, `@m1[l]` 1.5e-07 → 7.5e-08 |
| `wnflag` | two binned BSIM4 models across the W bin edge: `@m1[vth]` 1.088900 → 0.688900, `i(vd)` −7.73196e-05 → −6.23913e-04. The **bare card `.options wnflag` delivers nothing** — 1438/1439's defect, reproduced independently |
| `sqrnoise` | `onoise_total` 3.147875e-07 → 9.909116e-14 |
| `cshunt_value=1n` | every AC, TRAN and NOISE value of the probe deck (`vdb(mid)` −2.74175e-01 → −2.87193e-01) |
| `notrnoise` | a `trnoise` source to 0.000000e+00 at every timepoint |
| `seed` | `seed=12345` and `seed=999` give different samples, both unlike the unseeded run |
| `autostop` | with one `.meas`: 226 data rows → **2** |
| `diode_cj0=10p` | under `ngbehavior=ps`, through the run-directory start-up file: AC current imaginary part 0.000000e+00 → 1.066292e-04 |
| `diode_rser=100` | same route: `i(vb)` 5.670347e-03 → 5.867302e-04 |

**MEASURED NOT TO, with the mechanism demonstrably firing — 3 rows, and this is the
finding:**

| option | measured |
|---|---|
| `warn=1` | five resistors over `bv_max`: **0 → 5 SOA messages, and EVERY printed value byte-identical**. It is a diagnostic printer |
| `maxwarns=2` | 5 SOA messages → 2, every printed value identical |
| `num_threads=1` | against the default: identical OP, AC, TRAN and NOISE. It is an OpenMP thread count |

⚠ **The transcription would have put an authoritative "this option changes your numbers"
badge on all three, two of them pure diagnostics.** `evidence/hidden-vars.md` §2.1's own
R/P column already marks them **P**; the row said `results 1` anyway. That is the exact
class of defect §7c's badge exists to prevent, inside the badge.

**NOT MEASURED — 10 rows**, because no probe deck made the mechanism fire:
`auto_bridge`, `no_auto_bridge_family`, `noisyxspice`, `xtrtol` (event-driven or
A-device XSPICE); `ng_nomodcheck`, `enable_noisy_r` (model and netlist shapes);
`dyngmin`, `topo_reduce`, `nostepsizelimit` (nothing distinguished the two runs);
`soacheck` (needs a PDK library that reads `SWSOA`).

## The fix

**The column carries its own evidence.** `results_ev measured` + `results 1` is a
measured yes; `results 0` + `results_ev measured` is a measured no; `results 1` with no
evidence key is **`unverified`**, and `ase::opt_results` answers in three values rather
than two. ⚠ **The default is `unverified`, not `yes`** — a catalogue cannot acquire a
measured badge by being edited, only by someone taking the measurement. The sheet draws
`⚠ CHANGES RESULTS` for the nine, **nothing** for the three refuted, and
`⚠ MAY CHANGE RESULTS — UNVERIFIED` for the ten, so the uncertainty is **on the surface**
instead of behind it.

**The options sheet** replaces the list dialog at the same toplevel, with the same
treeview path, the same context menu, the same `$w.optrow` row editor and the same
**integer row ids**, because the changed-only default view *is* the bench's stored rows.
`test_ase_dialogs`' G6 and GE9 drive exactly those gestures and neither moved. What is
new is the finder around them: a live substring search over **name, group and help**; a
`Show all` tick that opens the other ~240 rows **in groups**; a scope selector; the
badge column; a detail line; and the **live deck preview**.

**The preview is the point, and it is not a second opinion.** `render_deck`'s option
loop moved into `ase::opt_deck_plan`, which the emitter now calls and the preview reads,
so a line in the pane **is** a line in the deck. The last-resort `.options` spelling is
ngspice syntax and moved to the adapter's own `option_fallback` hook — a backend with no
hook gets no fallback content (**D34**). ⚠ **And the converse guard is the half people
forget**: a line in the preview is not a promise that the setting takes effect. `units`
is read after the circuit is loaded, the deck slot still carries the
`.options units=degrees` card this tree writes today, and that card is measured to leave
the phase in **RADIANS** — so the line is shown **and** a note says it will not arrive.

## What else the measurement refuted

* ⚠ **`PLAN.md` §7c-3 says "the eleven categories"; the catalogue ships fifteen**, and
  one of them, `numerics`, is **not a function at all** — its 20 members were exactly the
  `results`-carrying `cp_getvar` rows, i.e. the `results` column wearing a group's
  clothes. `sqrnoise` belongs in the drawer a user opens looking for noise output, not in
  a drawer named after a property the badge already carries. All 20 were re-filed into
  the function category `evidence/hidden-vars.md` §7 itself places them in; the group
  count is now **14**.
* ⚠ **`PLAN.md` §7c-2's reason for the changed-only view is wrong in the direction that
  hides a real change.** It calls the view *"a FILTER, not a feature, because the
  catalogue carries `default`"*. The catalogue's `default` is not what makes it safe —
  **storage** is. `gminsteps` defaults to 1; a bench that stores 1 would vanish from a
  view filtered on `default`, so a **wrong** default would hide a row the user typed.
  That is §7a's own `gminsteps` note pointing the other way and worse, because the user
  cannot see what is missing. Every stored row is shown; `default` decides the
  **annotation**. And only **65 of 247** rows carry a default at all, so for most of the
  catalogue the comparison cannot be made and the annotation says so (`nodefault`).
* **`scope` cross-checks clean**, which is worth recording: of the catalogue's
  analysis-scoped rows, `evidence/options.md` §10.2 names the **same analysis set for
  every one it lists — zero set-level disagreements over 27 shared rows**. Two rows moved
  (`dyngmin` → `{analysis op}`, `chgtol` → `{analysis tran}`), and the seven rows §10.2
  files under *"Any with XSPICE A-devices"* stay `global` because that is a **device**
  condition and there is no analysis called `xspice`.
* ⚠ **A wrong `scope` cannot hide an option here.** §7c says *"an option shown in the
  wrong scope is worse than one not shown"*, and that failure needs a scope that can
  **hide**. The global surface offers **every** row in the catalogue, so a wrong `scope`
  costs a shortcut on one analysis's short list and never costs the option.
* ⚠ **`units` had no help text.** It is the 57.2958× phase error — 1437's own C104 calls
  it *"the single most consequential option in this batch"* — and it was the one of the
  five sentences that receipt says ASE-L wrote which the shipped row did not carry, so
  its detail line was the badge and nothing else. It has one now. Only **64 of 247** rows
  carry help at all (⚖ R9: minting 190 more would be the user's to ratify), so the search
  leans on name and group for the rest.

## Suites

New suite `test_ase_optsheet_1441` — **62 headless / 87 on the dev display** — registered
in `tests/run_regression.tcl`'s **`hcases` AND `dcases`**, so **T1 covers all 87**. It is
the only Stage 7 suite whose subject is a window and its display arm costs **0.40 s**
against 0.10 s headless, which is the measurement the `dcases` comment asks for before a
`test_ase_*` suite joins that list. `test_ase_options_1437` stays at **75** with **one row
re-baselined** (BR6, the lexical routing row, now over three bodies). No other suite moved,
**no deck golden moved and no `.state` file moved** — no state key was added,
`ase::state_default` still seeds exactly four rows, and there is no `seed_enabled`
anywhere.
