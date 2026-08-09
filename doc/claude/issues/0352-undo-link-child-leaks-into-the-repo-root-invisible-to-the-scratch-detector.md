# 0352 — undo_link_child/ leaks into the repo root, invisible to the scratch detector

Status: MEASURED, NOT FIXED (filed by item D1; do not fix silently elsewhere)
Area: tests/headless/test_undo_link_symbols.tcl, tests/headless/full_audit.sh
Found: 2026-08-09, unattended backlog run, item D1
Related: 0148 (the scratch-leak class), 0350, 0353 (same detector blind spot, file-level:
two gated suites leak `untitled-NN.sch` into the repo root on every run)

## Symptom

An untracked `undo_link_child/` directory (drive.tcl, out.txt, clog/Xschem.log*)
sits in the repo root. `git status` shows it; the audit's scratch-leak detector
does not.

## Cause

`tests/headless/test_undo_link_symbols.tcl:45` builds the directory as

    [file dirname [xschem get actionlog_filename]]/undo_link_child

so a bare run with the action log in the repo root leaks it there. It is an
issue-0148-class leak, but the detector cannot see it:
`scratch_snapshot()` (full_audit.sh:146-149) globs `_*_[0-9]*` only, and
`.gitignore:64` ignores `_*_[0-9]*/` — neither pattern matches `undo_link_child`
(nor `_g5` / `_g6` / `_g10` / `_g11` / `_libdiff_fixtures`, which are the same
shape of leftover from a July diff-dialog session).

## Why it was not fixed here

`test_undo_link_symbols` is a `logdir_test` whose own assertions read that
directory, so rerouting it through `tests/headless/scratch.tcl` needs its own
before/after measurement — outside item D1's blast radius.

Rejected alternatives, recorded so a later crew does not repeat them:

* widening `scratch_snapshot`'s glob or adding the name to `.gitignore` — hiding
  a leak is the exact 0148 anti-pattern;
* deleting the directory — `doc/claude/code_analysis/perform_action_atom28_redo_decision.md`
  cites it as evidence. It has been preserved at
  `doc/claude/evidence/0148_undo_link_child/` (named for the leak class it
  belongs to) and the citation updated.

## Untracked scratch inventory at bc4ff4a2 (recorded, deliberately NOT deleted)

81 `untitled*.sch` across the repo root, `src/` and `tests/`, plus seven scratch
dirs: `_libdiff_fixtures/`, `src/_libdiff_fixtures/`, `src/_diffdlg_fixtures/`,
`src/_g5/`, `src/_g6/`, `src/_g10/`, `src/_g11/`. No test, Tcl script or doc in
the tree references any of them by name; `src/_g11/recent_diffs` carries absolute
paths into this working tree and `created {2026-07-05 10:19}`.

`untitled-NN.sch` is exactly the shape of unsaved user work, so nothing was
removed automatically. Cleanup recipe for a human who has confirmed none of it
matters:

    cd /home/analog/dev/xschem-claude
    git clean -nd -- 'untitled*.sch' 'src/untitled*.sch' 'tests/untitled*.sch' \
        _libdiff_fixtures src/_libdiff_fixtures src/_diffdlg_fixtures \
        src/_g5 src/_g6 src/_g10 src/_g11        # -nd first: DRY RUN, read it
    # then re-run with -fd once the list looks right
