# 1421 — the preflight suite was never in T1, and 21 more ASE suites are not either

**Status:** fixed for `test_ase_preflight`; **the audit below is the open part.**
**Branch:** fluid-editing
**Stage:** commit **C1** of Stage 4 of `doc/claude/ase_analyses_batch/`.

## Why this lands before Stage 4's subject

Stage 4 adds its rows to `tests/headless/test_ase_preflight.tcl`. That file has **125 checks** —
the refusal that stands between a user and a raw file holding twelve mathematical constants — and
**`run_regression.tcl` has never run it, on either arm.** Adding rows to a suite T1 does not run
would have produced another stage reporting "T1 at zero" about work T1 never touched, which is
exactly issue **1413**, found a second time.

## Two halves, and the second is worse

**The banner.** There are two completion banners in this tree: `run_suites.sh` accepts either
`RESULT: ALL PASS` or `OVERALL: ok` (issue 0228), while `tests/banner_rule.tcl` — the rule
`run_regression.tcl` consumes — accepts **only** a whole-line `OVERALL: ok`. A suite printing
`RESULT:` alone is scored a **harness failure** by T1 however many of its own checks passed, so it
cannot be added until it emits both.

**`exit 0`, unconditionally.** A case passes only on **exit 0 AND a completion banner AND no
column-0 death marker** — three independent signals, deliberately. This suite discarded one of them:
it exited 0 whether it passed or failed. Its whole body is wrapped in a `catch` that prints
`FATAL: $err` and increments `fail`, so a fatal error could print, be counted, and still leave the
process claiming success to anything reading only the exit code.

Both are fixed. `test_ase_preflight` now emits the second sentinel, exits nonzero on failure, and is
in `hcases`. **T1 goes 61 → 62 cases.**

## The audit, and it is the part that is still open

Measured 2026-09-12 across all 29 `test_ase_*.tcl` suites — whether each emits `OVERALL:` and
whether `run_regression.tcl` names it:

| in T1 | suites |
|---|---|
| **yes (7 before this commit, 8 after)** | `core`, `dialogs`, `optier_0963`, `persist`, `simcaps_0948`, `simdlg_0937`, `simreg_0931`, **`preflight`** |
| **no (21)** | `bus_bits_0159`, `cosim`, `current_repair`, `dirty`, `final`, `final_gf180`, `hier_pick_0161`, `hier_plot_0168`, `interact`, `launch`, `locked_wire_pick_0160`, `log_seam_0207`, `plot`, `print_bracket_0167`, `result_case`, `savestate_adopt`, `simchoice_1395`, `sod_case`, `unnamed_net`, `view`, `window` |

**Every one of the 21 prints `RESULT:` and no `OVERALL:`**, which is why none of them could be added
— the same single cause, twenty-one times. `test_ase_cosim` alone is 341 checks; `test_ase_window`
is 295.

⚠ **This is not a licence to add all 21 in one commit.** They must be measured standalone first: a
suite that has never been in T1 has never had its *first run under the driver* walked, which is
precisely the hazard CLAUDE.md records for `test_ase_optier_0963`'s display arm — its first run
under a driver nobody had exercised hung for eight hours. Add them in batches, each measured, each
with a bound.

## What this does NOT claim

That T1 now covers ASE. It covers **eight of twenty-nine** ASE suites. Any future statement of the
form "T1 at zero" should be read as covering those eight and no more, and this issue is the list to
check it against.
