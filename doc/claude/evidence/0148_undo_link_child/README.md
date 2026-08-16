# Evidence: `undo_link_child/` (atom28 redo decision)

`drive.tcl` and `out.txt` here are the preserved copies of a scratch directory that
`tests/headless/test_undo_link_symbols.tcl:45` builds next to the action log:

    set tmp [file join [file dirname [xschem get actionlog_filename]] undo_link_child]

Under `full_audit.sh` the test runs with `--logdir <mktemp -d>`, so the directory lands
in the temp dir and disappears. On a bare run with the action log in the repo root it is
written into the **repo root** instead and stays there, untracked — the leak filed as
**issue 0352**. Neither `full_audit.sh`'s `scratch_snapshot()` (`_*_[0-9]*`) nor
`.gitignore:64` (`_*_[0-9]*/`) matches the name, so nothing reported it.

These two files are kept because they are cited as evidence by
`doc/claude/code_analysis/perform_action_atom28_redo_decision.md` (the bare
`xschem redo` caller sweep) and by
`doc/claude/refactor_b_batch/prompts/atom28_redo.md:91`. The `clog/Xschem.log*` files
from the leaked copy are run noise and were not preserved.

Regenerate the live directory with:

    ./src/xschem --pipe -q --logdir <dir> --script tests/headless/test_undo_link_symbols.tcl

Filed 2026-08-09 by the item-D1 crew (issues 0350/0351/0352). Do not "fix" 0352 by
widening the scratch glob or by adding the name to `.gitignore` — hiding a leak is the
issue-0148 anti-pattern.
