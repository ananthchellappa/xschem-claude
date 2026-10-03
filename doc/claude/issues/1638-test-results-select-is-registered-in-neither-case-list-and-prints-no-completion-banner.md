# 1638 — `test_results_select` owns result-selection semantics, is registered in neither case list, and cannot be registered as it stands

**STAMP:** `v1 claim=open tree=a90ffb98 stamped=2026-10-02 fix=none open=2`

Status: **OPEN**, found 2026-10-02 by the calculator batch's recon stages while looking for the
suite that should already have caught issues 1634 and 1636. Pre-existing.

Area: `tests/headless/test_results_select.tcl` (the suite), `tests/run_regression.tcl` (`hcases`
and `dcases`), `banner_complete` in `tests/banner_rule.tcl` (the rule it fails).
Found: counted the two lists and scored the suite's real output through `banner_complete`

## The defect

`test_results_select.tcl` is 191 KB of result-selection fences — the registry cursor,
`results::current`, `results::select`, the selection messages — and **nothing runs it**. Measured
at this tree:

```
hcases entries: 95
dcases entries: 24
tcases entries: 3
occurrences of "results_select" anywhere in tests/run_regression.tcl: 0
```

95 + 24 + 3 + `xschemtest` is 123, which is the case count in the current baseline trailer, so the
two lists were counted correctly. (Counted the way CLAUDE.md prescribes — locate `set hcases [list`
and `set dcases [list`, take the bracketed quoted words. The naive `grep -c '"headless/'` and
`grep -cE '\.log$'` spellings both miscount, and a whole-file `awk` range miscounts worse: the lists
are brace-continued across interleaved comment blocks and an unanchored range runs to EOF, giving
312 and 198.)

**This is the suite that owns the very semantics issues 1634 and 1636 damage.** 1636's measurement —
select a non-zero slot, clear an unrelated database, watch `results::current` change path *and
analysis type* with no message — is three lines in a suite whose subject is `results::current`.
It has been sitting unrun; the defect it would have caught was found by a recon crew with a
hand-written probe.

## ⚠ It CANNOT simply be registered, and that is the part worth knowing before anyone tries

`banner_complete` in `tests/banner_rule.tcl` is the **only** Tcl reader of the completion-banner
rule and the only one `run_regression.tcl` sources. Its pattern is
`^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`, and that file's own header says it *"implements no
`RESULT: ALL PASS` spelling at all"*. This suite's epilogue is:

```tcl
puts "----"
puts "test_results_select: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
```

Scored against its own real captured output, with `banner_rule.tcl` sourced:

```
suite exit code  = 0
RESULT: ALL PASS (377 checks)
banner_complete  = 0
banner_died      = 0
occurrences of "OVERALL" in the output = 0
RESULT: lines = 1
```

So registering it as it stands produces a standing red with every one of its own checks passing —
`HARNESS: … did not complete cleanly (exit=0, OVERALL_ok=0, died=0)` on the line above its own
`RESULT: ALL PASS`. That is issue **1615**'s incident verbatim, and issue **1626**'s for the two
Calculator suites. `run_suites.sh` and `full_audit.sh` carry their own EREs which **do** accept
`RESULT: ALL PASS`, which is why the suite looks healthy from every door except the gate:

```
tests/headless/run_suites.sh --nogui test_results_select
PASS     | test_results_select          run 1/1  RESULT: ALL PASS (375 checks)
RESULT: 1/1 runs passed
```

**So the answer to "is registering this a one-line change or a structural one" is: one line, plus a
gate run.** The sentinel has to be added additively — emit `OVERALL: ok ($npass checks)` and keep
the `RESULT:` line **last**, because `summarize_all` publishes a case's *last* `RESULT:` line into
the verdict. That is exactly the shape issue 1626 used for `wvbs_finish`.

⚠ **Nothing here was changed.** Per CLAUDE.md, *"it passes standalone" is not evidence a suite can
be registered*, and registering a suite is itself a change that needs gating — 1615 gated red doing
exactly this. The epilogue check is done and recorded above so whoever picks it up does not have to
re-derive it; the edit and the gate are theirs.

## A second measurement, noted because it will confuse whoever gates this

The suite reports a **different check count on the two spellings**: `375 checks` through
`tests/headless/run_suites.sh --nogui` and `377 checks` through a bare
`env -u DISPLAY ./src/xschem --pipe -q --nogui --script`. The difference is the test home — the
armed spelling runs on a throwaway `HOME`, the bare one on the real one — so two rows are
environment-sensitive. **Do not treat either number as the suite's size**, and do not write either
into a comment: the suite prints its own total on every run. Which two rows move was not isolated.

## Open items

1. **Add the sentinel and register, in one change, and gate it.** `hcases` or `dcases` is itself a
   measurement and not a guess: run the suite on both arms and read `banner_complete` on each, the
   way the `test_calc_plot` registration was decided. An `hcases` entry for a suite whose rows
   self-skip headless measures nothing; a `dcases` entry for one that does not need a display
   wastes an arm.
2. **The tail this is one instance of.** 334 of the 418 `tests/headless/test_*.tcl` files are in
   neither list (measured 2026-09-28, issue 1615). `full_audit.sh` globs and runs all 418, so the
   tail is audit-reachable and simply never in front of a gate. **This item is not "register
   everything"** — CLAUDE.md's adopted rule is the bounded half, a suite you add a fence to you
   register in the same commit. It is filed so that this suite's registration is not mistaken for
   closing the class.

## What this is NOT

Not a claim that the suite is failing. It passes, on both spellings measured, with 0 failures.

Not a claim that `full_audit.sh` misses it: it globs `test_*.tcl` and runs it. The claim is
narrower and is the one CLAUDE.md says to make — **it does not gate a commit**.
