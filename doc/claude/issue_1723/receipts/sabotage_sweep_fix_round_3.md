# Issue 1723 items 5-7, fix round 3: red first, and the sabotage sweep (2026-11-21)

This is a dated record, not a baseline. It was measured on the working tree that became the commit
adding this file (parent `96c8ec091`), and nothing re-runs it. The counts are what that tree printed,
and any later edit to the suites moves them.

## Red first

The new rows were written first and run against `96c8ec091`'s `src/ase.tcl` and `src/ase_window.tcl`.
Those two files were copied in with `git show HEAD:`, then restored and checked with `cmp`.

`test_ase_preflight`, headless (armed throwaway HOME, `DISPLAY` unset), gave **21 FAILED (328 passed)**.
Every older row passed. These rows were red:

- `PF1723r9`, `PF1723r10`, `PF1723r11` and `PF1723s11`: finding 1 (a `;` or comment line indented)
- `PF1723r13` and `PF1723s12`: finding 2 (`.nodeset all=`)
- `PF1723r14`: finding 4 (a value on the next `+` line)
- `PF1723r12`: finding 5 (the BOM)
- `PF1723r15` and `PF1723s13`: finding 6 (`.if` blocks)
- `PF1723y5`: finding 7 (a symlinked model file)
- `PF1723t7`: finding 9 (fold, the spelling and the target)
- `PF1723aj`, `PF1723aj2`, `PF1723aj3`, `PF1723aj4`, `PF1723aj5` and `PF1723t6`: findings 3 and 8 (the
  two halves). Where `ase::preflight_fix_all` did not exist, a leg raised `invalid command name`.
- `PF1723ak` and `PF1723ak2`: finding 10 (a shared file)
- `PF1723ah4`: end to end on `/usr/bin/ngspice`. On that code the bench was refused before ngspice
  (`{1 -1 0 0 0 1 0 1}`).

`PF1723t8` (two folded spellings with different targets) was added after the sweep below showed a hole.
It was not part of that red run.

`test_ase_window`, display arm (`AUDIT_DISPLAY=private`: a private Xvfb with openbox), gave **2 FAILED
(389 passed)**:

- `FX1723Cb3`: the confirmation has no Shared line.
- `FX1723Ce3`: OK logged `{ase::preflight_fix_includes <key>} {ase::preflight_fix_session <key>}`, two
  commands, where the fix logs one, `ase::preflight_fix_all <key>`.

## The sweep

Each sabotage undoes one fix in the working tree's sources. `test_ase_preflight` then runs headless, and
the files are restored byte for byte (checked) before the next sabotage. The sweep itself had 349 rows;
the S7 rows were re-run after `PF1723t8` brought it to 350.

| sabotage | what it undoes | red rows |
|---|---|---|
| S1 | `ase::spice_lines` reads column 0 of the raw line again, so leading blanks are not dropped | `PF1723r9`, `r10`, `s11`, `ah4` |
| S1b | `ase::include_top_words` takes an element word from a `;`-led card again | `PF1723r11`, `ah4` |
| S2 | `ase::include_card_names` has no `.nodeset all` stop | `PF1723r13`, `s12`, `ah4` |
| S3 | a name's value is read only from its own physical line | `PF1723r14` |
| S4a | the include reader's early out does not allow a BOM | `PF1723r12` |
| S4b | `ase::spice_lines` does not drop the BOM | `PF1723r12` |
| S5a | the card reader never sets `cond` | `PF1723r15`, `s13`, `ah4` |
| S5b | `ase::preflight_scan` ignores `cond`, so a `.if` card refuses | `PF1723s13`, `ah4` |
| S6 | a models entry is listed only as spelled | `PF1723y5` |
| S7 | under fold, the first spelling speaks for the group whatever the targets | `PF1723t7`, `t8` |
| S7b | under fold, every spelling is its own record, even when the targets agree | `PF1723l`, `l2`, `t4` |
| S7c | the gate counts a folded spelling's names whatever their target | `PF1723t8` |
| S8a | `ase::preflight_strand` on the files half never finds a loss | `PF1723aj`, `aj2`, `aj3` |
| S8b | `ase::preflight_strand` on the session half never finds a loss | `PF1723aj`, `aj4` |
| S9 | `ase::preflight_commit_both` skips the session half | `PF1723aj3`, `aj5` |
| S10 | a refusal with both halves keeps the file half's own sentence | `PF1723t6` |
| S11a | `ase::include_sharers` compares paths as spelled | `PF1723ak`, `ak2` |
| S11b | `ase::ui::repair_confirm_lines` drops the Shared line | `PF1723ak2` |

Every sabotage reddens at least one row, and the row named for its finding.

**Two holes the sweep found, both closed before this record.**

- **S11a was green at first.** The fixture reached the shared file through a linked folder, which
  `file normalize` already resolves, so comparing paths as spelled found it anyway. `PF1723ak` now
  includes a state whose include is a link to the file itself, the case where only following the last
  link makes the paths equal. S11a then reddened `PF1723ak` and `ak2`. Where no symbolic link can be
  made, that leg prints `skip:` and drops out of the expected list.
- **S7c had no row.** Every fold fixture's spellings agreed on one target, so the gate's per-target
  count was never driven. `PF1723t8` (`x1.` to `xdut`, `X1.` to `xother`, each with a line of its own)
  was added, and S7c and S7 redden it.

## The display arm, sabotage by hand

`FX1723Ce3` is the only row that sees the OK's log line, and `FX1723Cb3` the only one that sees the
real dialog's Shared line. Both were red on `96c8ec091`'s code (above). Both pass on this tree
(`test_ase_window`, display arm, 391 checks).

## Not in this sweep

- `G2sens` in `test_ase_dialogs` is red on the display arm with the same values as in round 2
  (`{1 1 0 1 0 Entry Entry normal}`, expected `{1 1 0 0 0 Entry Entry normal}`). That is issue 1436:
  filed, not fixed, and not this round's.
- `test_ase_optier_0963` on the display arm TIMES OUT on this tree and on `96c8ec091`'s sources alike
  (`SUITE_TIMEOUT=300`). xschem sits on a modal descend-fallback question about `x5` in
  `tb_bandgap.sch` (`passgate_lvtp` is not there; open `passgate.sch` instead?). T1 runs this suite
  headless only, and `doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md` records the
  display-arm hang. Headless, it passes on this tree (110 checks).
