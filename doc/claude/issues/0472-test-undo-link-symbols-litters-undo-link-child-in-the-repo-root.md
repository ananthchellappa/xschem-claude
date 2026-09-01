# 0472 — `test_undo_link_symbols.tcl` creates an untracked, non-ignored `undo_link_child/` in the REPO ROOT

Status: **OPEN, measured, NOT fixed** (the directory itself was removed by the
S9b write-up agent; the test recreates it on the next run).
Observed independently by the S9b Implement and Verify-A agents.

`tests/headless/test_undo_link_symbols.tcl:45` creates its child schematic
relative to the actionlog directory, which resolves to the **repository root**:

    undo_link_child/
      clog/
      drive.tcl
      out.txt

Measured: `git check-ignore -v undo_link_child` returns rc=1 — it is **not**
covered by `.gitignore`, so it shows up in `git status --short` as untracked
scatter forever after anyone runs that suite.

It is **not** an `untitled*.sch`, so it does not trip the three tests
`CLAUDE.md` warns about (`save_as_cellview`, `untitled_reuse`,
`descend_untitled_preserve`) — but it is litter in exactly that class, and the
crew rule "never `git add -A`" exists because of this kind of thing.

## Fix shape (not applied)

Point the fixture at a temp directory (the crews use
`/tmp/claude-1000/…/scratch_*`), or at minimum add `undo_link_child/` to
`.gitignore`. Writing test output into the repo root is the actual defect;
gitignoring it only hides it.

## Still open

Yes.
