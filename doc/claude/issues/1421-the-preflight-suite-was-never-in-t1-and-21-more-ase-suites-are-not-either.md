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

---

## Re-measured by the driver 2026-09-13 — and two things have changed

Taken statically over all 29 `test_ase_*.tcl` at commit `3bb4449e`, with no suite run, so
it cost the running task-crew no load. **The audit above still holds exactly**: 8 in T1,
21 out, and every one of the 21 prints `RESULT:` and no `OVERALL:`. Two facts are new, and
they pull in opposite directions.

### 1. ✅ The unbounded-hang hazard this issue was written against is CLOSED

This issue's *"not a licence to add all 21 in one commit"* paragraph rests on the
`test_ase_optier_0963` display-arm stall — a first run under a driver nobody had exercised,
which hung for eight hours because nothing bounded it. **Issue 1403 has since bounded both
layers**, and both are live today:

* `tests/run_regression.tcl:177-189` — `t1_timeout` / `T1_CASE_TIMEOUT`, default **900 s**,
  prefixing **all four** `exec` sites with `timeout --kill-after=20`, and rc 124 counted as
  a `FAIL` that says `TIMED OUT`.
* **All 29** of these suites source `tests/headless/scratch.tcl`, so **all 29 already carry
  the in-suite watchdog** (`XSCHEM_SUITE_WATCHDOG_MS`, default 900 000 ms, exit **124**,
  printing the last output line). Measured: `grep -c scratch.tcl` is ≥ 1 for every one.

So the specific eight-hour shape is no longer reachable through T1. ⚠ **The watchdog is
still not a general timeout** — a hang in a blocking `exec` or a busy Tcl loop does not
reach the event loop and is not caught (row W13 of `test_suite_watchdog_1403.tcl` pins
that) — which is precisely why `t1_timeout` matters and why it is the load-bearing one
here. **Batching is still right**; the reason is now "a suite whose first driver run
nobody has watched", not "an unbounded wait".

### 2. ⚠ TWO MORE SUITES CARRY THE `exit 0` HALF OF THIS DEFECT, NOT JUST THE BANNER HALF

This issue treated the 21 as a single cause — the missing sentinel. They are not all the
same. Two of them also discard the exit-code signal, which is the **worse** half and the
one this issue calls out in as many words for `test_ase_preflight`:

| suite | line | what it does |
|---|---|---|
| `test_ase_current_repair` | `:701` | `exit 0` — **unconditional**, after printing `RESULT: $fail FAILED` |
| `test_ase_result_case` | `:589` | `exit 0` — **unconditional**, after printing `RESULT: $fail FAILED` |

Every other one of the 21 already exits nonzero on failure — `test_ase_cosim:2277` is
`exit [expr {$fail == 0 ? 0 : 1}]`, and it is the largest of them at 341 checks. So for
**19 of the 21 the change really is one line**, the `OVERALL: ok` sentinel; for these two
it is two, and **adding either of them with only the sentinel would put a suite in T1 that
can fail and still report success to anything reading the exit code.**

⚠ **These two are therefore the ones to fix FIRST and add LAST**, not the reverse: the
exit-code repair is worth landing whether or not the suite ever joins T1, because
`run_suites.sh` and `full_audit.sh` read that code today.

### The batching this suggests

Not a licence, a proposal — it is still a task for a crew, measured standalone with a bound
before each batch is added:

1. **The two exit-code repairs**, alone, with no T1 membership change. They are a live
   defect in the current harness readers.
2. **The quiet headless ones** — `print_bracket_0167`, `result_case`, `sod_case`,
   `unnamed_net`, `bus_bits_0159`, `savestate_adopt` — small, fast, no simulator.
3. **The simulator ones** — `final`, `final_gf180`, `cosim`, `plot` — where `test_ase_final`
   is already known to raise issue **1402**'s flap in `test_ase_optier_0963` when run
   back-to-back with it, so the ORDER inside T1's case list is itself a measurement.
4. **The X-dependent ones** — `dirty`, `log_seam_0207`, `interact`, `launch`, `view`,
   `window`, `hier_pick_0161`, `hier_plot_0168`, `locked_wire_pick_0160`, `simchoice_1395`,
   `current_repair` — last, because the display arm is where the eight-hour stall happened
   and two of them self-skip without an X connection.

**Until that lands, every "T1 at zero" in this batch still means eight of twenty-nine ASE
suites**, and each stage should keep saying so rather than letting the number read wider
than it is.

---

## A third shape, found 2026-09-13: a suite T1 DOES run, on only one of its two arms

This issue counts **suites**. It does not count **arms**, and that turns out to hide a
gap of the same kind.

`test_ase_dialogs` is in `hcases` (`tests/run_regression.tcl:76`, and the file's own
comment at `:105` says so in as many words: *"THEY GO IN `hcases`, NOT HERE.
test_ase_dialogs is 37 checks headless"*). So T1 runs its **headless** arm — **37
checks** — and never its **display** arm, which is **300**.

That mattered immediately. Issue **1435**'s fifteen `GN` rows are the measured evidence
for a **user-visible ruling** — that the precondition banner needs a widget of its own
rather than sharing `$w.status` — and every one of them lives on the arm T1 cannot
reach. So does issue **1436**'s pair of standing reds, which is why they stood unnoticed
across at least one commit.

⚠ **Neither adding the suite nor fixing its banner would close this**, which is why it is
recorded separately: `test_ase_dialogs` already emits what T1 needs and is already named
in `hcases`. What is missing is a **`dcases` entry**, and `dcases` is deliberately short
because the display arm costs wall-clock (`run_regression.tcl:110`). So this is a
scheduling decision about T1's budget, not a banner repair — and it belongs with batch 4
of the order proposed above, where the other X-dependent suites are.

**Until then, "T1 at zero" means eight of twenty-nine ASE suites AND, for at least one of
those eight, one of its two arms.**
