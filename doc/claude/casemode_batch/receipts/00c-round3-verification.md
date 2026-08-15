# 00c — round-3 upstream drop, verified against OUR deck shape

Measured 2026-08-15 against `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`
(`ngspice-46+`, build stamp **`Sat Aug 15 18:18:34 UTC 2026`** — the tree round 3
was written against) with `/usr/local/bin/ngspice` (`ngspice-46`) as baseline.
No source changed. Scripts, re-runnable: `doc/claude/casemode_batch/repro3/run_r3.sh`
and `run_r3b.sh` (both take `[case-capable-ngspice] [baseline-ngspice]`; `run_r3.sh`
still has two cosmetic `$?`-clobbered rc columns that `run_r3b.sh` re-measures
correctly — read them together, `run_r3b.sh` wins on any rc).

Round 3 landed at `feedback/ngspice_upstream/RESPONSE.md`; round 1 kept beside it
as `RESPONSE_round1.md`. `FINDINGS.md`/`README.md` refreshed from the same drop.

## Why this receipt exists

Both sides measured shapes that are **not** what `render_deck` emits. Upstream's
`ctl_fail.cir` (and our own R1) carried an analysis **dot card *and* a `.control
run`**; `render_deck` (`ase.tcl:3196-3230`) emits analyses as **control commands**
(`op`/`dc`/`ac`/`tran`), no dot card, no `run`, and a **bare `write <abs path>`**
with no vector list. Every row below is that shape.

## What our shape measures

| leg | ver_50 | stock-46 |
|---|---|---|
| `.save v(In)` schematic case, `op`, `preserve` | rc=0, `v(In) v(MidNode)`, `print` echoes `v(In)` | rc=0, folded |
| no flag at all, `tran`, raw minus `Date:`/`Command:` | **byte-identical to stock** | — |
| legacy **folded** `.save v(midnode)` | `preserve` rc=0 → `v(MidNode)` (0056); `distinguish` rc=1 + constants raw | rc=0 folded |
| `.save` of an absent node, with and without `print` | **rc=1**, constants raw written | **rc=1**, same |
| good deck | rc=0 | rc=0 |
| `$sim_status` guard (`if $sim_status ne 0 / quit 1`) | rc=1, `RUN-FAILED`, **raw absent** | identical |
| exactly one saved vector, `op` | 1 var, `v(in)` (0064 fixed) | **2 vars, `v(in)` `v(all)`** |
| one saved vector, `tran` | `time v(in)` | `time v(in)` |
| duplicate column 0073 | **not reachable** — bare `write` is clean (op 2-save → 2, dc 2-save → scale + 2) | same |
| `write f.raw v(In)` (the shape we do *not* emit) | 2 columns `v(in) v(In)` | 2 columns `v(in) v(in)` |
| `.op` **dot card**, empty/ground-only netlist (0072) | rc=134 SIGABRT | rc=134 — **we never emit a dot card**; our `op` in `.control` → rc=0 + constants raw |
| `set casemodewrite` inside `.control` | header line written, valued per mode | **silent no-op, rc=0, no error** |
| `-D casemodewrite` bare / `=TRUE` / absent | 1 / 0 / 0 `Option:` lines | — |
| collision `Out`/`out` | warns in **all three modes**, names the outcome | silent |
| near-miss warning, our shape (1 simulation) | stderr **2** for one token (0057 still doubles) | — |
| `.save all` + `.options savecurrents`, `preserve` | `v(In) v(MidNode) i(Vs) i(@Rl[i]) i(@Rg[i])` | folded |
| hierarchy, `preserve` | `i(V.X1.Vp)`, `i(@R.X1.Rq[i])`, `v(Mid)` — F4 holds | folded |

Probe (item 7 contract), re-verified: `.spiceinit` beside the deck saying `fold`
⇒ probe `fold` **and** the run folds; no `.spiceinit` ⇒ probe `preserve`/
`distinguish` and the run agrees. Wrong cwd still answers confidently wrong.
Stock: empty stdout + `Error: curcasemode: no such variable.`

Our reader, unchanged: a raw carrying `Option: casemode=preserve` at line 5
**and** at the copy position (after `No. Points:`) reads fine — 3 vars, points,
values — and still folds the names (item 1 not started). Stock-46 also loads a
mixed-case preserve raw and `display`s `v(In)`.

`repro2/run_round2.sh` re-run unmodified: R2/R4/R5 unchanged, **R3 no longer
reproduces on ver_50** (stock row still shows `v(all)`), R6 fixed on ver_50 and
rc=134 on stock. Matches round 3 §10 exactly.

## Corrections this forces on PLAN.md

1. **§0b item 1 is wrong for our shape: `rc` IS a signal.** "The same failing
   `.save` exits 0 from a `.control` deck" was measured on a deck with a dot card
   *and* `.control run`. `render_deck`'s shape returns **rc=1** on a failed
   analysis, on both binaries. Item 10 may read rc — but rc=1 arrives **with the
   constants raw already written**, so the content checks stay mandatory, and the
   `$sim_status` guard is still better (it quits before `write`, leaving no
   artefact at all, and works on stock).
2. **§5.10 (phantom `v(all)`) is closed for ver_50 and open for everyone else.**
   Stock ngspice-46 still emits it for a one-vector `op` plot. Any filter is for
   the installed base, not for the enabler.
3. **Item 14a shrinks but does not vanish.** Upstream now warns on a fold
   collision in all three modes, at parse time, and sees `.include`d PDK cards we
   cannot. On stock it is silent, so our own netlister check still covers the
   installed base; the ver_50 path becomes "relay their line" (parse-time, so it
   cannot be captured from inside a `.control` block; dedupe on the quoted pair —
   it repeats per subckt instantiation).
4. **Item 3's `auto` sniff gets an exact source.** `Option: casemode=<mode>` now
   ships from **both** writers (`write` and `-b -r`), opt-in via
   `set casemodewrite`, which we can emit unconditionally — it is a silent no-op
   on stock. Read the header first, probe second, sniff last. Match the `Option:`
   **key** anywhere in the header, not line 5.
5. **0073 is a rule, not a bug, for us:** never name vectors on a `write` line
   (and never round-trip a `.dc` file's `v(v-sweep)` back into one). `render_deck`
   already complies; item 10/12 must not change that.
6. **0072 does not reach us** (no dot cards) — but the same empty-schematic input
   gives our shape rc=0 plus a constants raw, which is item 10's target anyway.
7. **Item 2 scope confirmed wider than `i(v.x`**: under `preserve`,
   `savecurrents` names carry case too (`i(@R.X1.Rq[i])`).

## Cautions carried over

- `casemodewrite` has **no scheduled default flip** (upstream `cp_remvar` patch
  written but **not sent**) — keep "absent means unknown" permanently.
- A raw we write with the header **crashes a stock-46 session that `unset
  casemode`s after loading it** (rc=139, re-measured here). Ours never unsets;
  matters only for published files.
- Never emit `set` **and** `unset` of the same simulator variable (rc=134 on
  stock). Emitting only `set casemodewrite` is safe.
- §5a's `-b -r` deck shape (no `.control`) is not available to us: it cannot name
  its own rawfile, takes no vector list, and drops the `print` lines
  `result_probe` parses.
