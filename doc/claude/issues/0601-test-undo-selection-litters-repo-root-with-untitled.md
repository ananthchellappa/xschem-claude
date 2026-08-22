# 0601 - tests/headless/test_undo_selection.tcl litters the repo root with `untitled~.sch`

STATUS: FIXED 2026-08-22 (found during X0498). Guarded suite + a guardian; see "The fix" below.

Every run of `tests/headless/test_undo_selection.tcl` deposits `untitled~.sch` (a backup of its
own two-resistor fixture) in the **repository root**. Proven causally: delete the file, run only
that suite, it reappears (count 0 -> 1). Measured again during X0498's verification pass.

**CORRECTION, measured in both directions (2026-08-22).** The line this issue used to carry --
"that is exactly the file class that turns `save_as_cellview`, `untitled_reuse` and
`descend_untitled_preserve` red" -- is WRONG for the file this suite actually leaves. A controlled
3x3 (clean root / root holding only `untitled~.sch` / root holding `untitled.sch`, one suite at a
time) put all three suites at `RESULT: ALL PASS` with the `~` file present, and red only with a
NON-backup `untitled.sch`: `get_unused_untitled_name()` stats only the non-backup candidate
(src/xinit.c:191-192), so a `~` twin never bumps the number, and all three assert on the exact
basename (test_untitled_reuse.tcl:54, test_save_as_cellview.tcl:73,
test_descend_untitled_preserve.tcl:48 and :64). `test_undo_selection` never creates that file.

The honest cost of the `~` is smaller but real: it is gitignored (.gitignore:75 `*~.sch`), so
full_audit.sh's `tree_delta_snapshot()` arm is structurally blind to it (full_audit.sh:351-360,
issues 0353/0356); the next `xschem clear force` in the same cwd silently deletes it
(src/actions.c:4618 -> src/save.c:4175-4182 -- issue 0356's unidentified emitter, now identified);
and an interactive open of that cell pops the "Recover unsaved changes?" modal
(src/xschem.tcl:6719-6736).

## Root cause (chain, all file:line verified)

`set_modify(1)` -> `write_backup()` on the FIRST edit of the launch untitled buffer:
src/actions.c:208 -> src/save.c:4149, the create at src/save.c:4164, the `~` name at
src/save.c:4126-4141. It backs up untitled buffers ON PURPOSE (src/save.c:4159-4162, issue 0060).
The directory is the cwd captured at STARTUP (`pwd_dir`, src/xinit.c:2952, and note
src/xinit.c:3690-3693 -- `$env(PWD)` WINS over `getcwd()`), so the repo root gets it for a hand run
and for full_audit.sh (which pins cwd=$REPO at full_audit.sh:64), and `tests/` gets it under
tests/run_regression.tcl. Bisected: the `xschem clear force schematic` at
test_undo_selection.tcl:22 writes nothing; the `xschem instance` on the next line writes the file.

**The fix direction this issue originally proposed does not work.** A Tcl `cd` moves NEITHER
`pwd_dir` NOR `$env(PWD)` (src/xinit.c:174 records this; it is issue 0323's root cause), so a
suite cannot relocate its own untitled buffer by changing directory. What works is suppressing the
write.

## The fix

Two lines, the same guard tests/headless/test_placement_wire_gate.tcl:69-70 and
tests/headless/test_shape_draw_gate.tcl:44 already carry -- `write_backup()` returns early when
`autosave_backup` is off (src/save.c:4156), and this suite neither descends nor recovers:

    set ::saved_autosave_0601 $::autosave_backup
    set ::autosave_backup 0
    ...
    set ::autosave_backup $::saved_autosave_0601

Applied to tests/headless/test_undo_selection.tcl and to four more measured emitters:
test_delete_cut_selflog, test_perform_action_align, test_statusmsg_hold_0248, test_instance_update.
All five: `RESULT: ALL PASS` before and after, 0 files left in the launch dir (was 1 each).

Guardian: **tests/headless/test_no_untitled_litter.tcl** (auto-discovered by full_audit.sh:392).
It re-runs each guarded suite as a child in a private cwd, carries a POSITIVE CONTROL row proving
an unguarded edit still litters (so the guardian cannot go vacuous), and greps the guard out of
each suite's source. Verified sensitive: removing the guard from test_undo_selection turns it
`RESULT: 2 FAILED`.

## Still open: the class is 80 suites wide

Measured 2026-08-22: of the 116 headless suites that touch an untitled buffer and carried no
guard, **80 leave `untitled~.sch` in their cwd** (each run in a private cwd, one at a time). So a
`full_audit.sh` run still ends with one `untitled~.sch` in the repo root, written and re-written by
dozens of suites. A blanket guard is NOT safe -- suites that exercise descend/go_back need the `~`
backup to exist (issue 0060; test_backup_file.tcl:70 and test_descend_untitled_preserve.tcl:53
assert it is written). The containment that would close the class is harness-level: give each test
its own cwd, remembering that `$env(PWD)` must be set too, not just `cd`. Not attempted here.

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
