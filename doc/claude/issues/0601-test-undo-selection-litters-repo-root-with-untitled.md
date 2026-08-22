# 0601 - tests/headless/test_undo_selection.tcl litters the repo root with `untitled~.sch`

STATUS: OPEN - FILED, NOT FIXED (found during X0498)

Every run of `tests/headless/test_undo_selection.tcl` deposits `untitled~.sch` (a backup of its
own two-resistor fixture) in the **repository root**. Proven causally: delete the file, run only
that suite, it reappears (count 0 -> 1). Measured again during X0498's verification pass.

That is exactly the file class that turns `save_as_cellview`, `untitled_reuse` and
`descend_untitled_preserve` red (see the project memory note "untitled litter fails 3 tests"), so
a suite that is itself green can red three unrelated suites that run after it.

Fix direction: the suite should build its fixture under its own tmp dir and `cd` there (or set
`::netlist_dir` / the current dir) so the editor's backup file lands outside the repo, and should
clean up after itself.

## Measured, twice, on separate days

* X0498 Measure agent, 2026-08-21: deleted the file, ran only that suite, count `0 -> 1`. The
  file's content is the suite's own two-resistor fixture (`res.sym` R1/R2 `value=1k`).
* X0498 Verify-A agent, 2026-08-22: reproduced again during the verification pass, and removed
  it before reporting so the T1 baseline was not polluted.

**Ordering trap worth recording:** because the litter appears only *after* the suite runs, a
`run_regression.tcl` measured before it is clean and one measured after it is not. A crew that
runs `test_undo_selection` and then measures tiers will see three unrelated suites go red and
will attribute them to its own change.

## Related, and fixed rather than filed

`tests/headless/test_undo_link_symbols.tcl` had the same class of defect — it resolved its
scratch tree to `./undo_link_child` (i.e. the repo root) when run without `--logdir`. X0498
fixed that in passing (`:44-60`, TMPDIR fallback) because it was extending that suite anyway,
and added a row asserting **0** `untitled*.sch` in the repo root after its children run.
