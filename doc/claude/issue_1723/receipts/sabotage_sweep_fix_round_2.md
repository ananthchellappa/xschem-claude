# Issue 1723 items 5-7, fix round 2: red first, and the sabotage sweep (2026-11-21)

This is a dated record, not a baseline. It was measured on the working tree that became the commit
adding this file (parent `2f1b8bca7`), and nothing re-runs it. The counts are what that tree printed,
and any later edit to the suites moves them.

## Red first

The new and moved rows were written first and run against `2f1b8bca7`'s `src/ase.tcl`,
`src/ase_window.tcl` and `src/xschem.tcl` (copied in with `git show HEAD:`, then restored and checked
with `cmp`).

`test_ase_preflight`, headless (`run_suites.sh --nogui`, an armed throwaway HOME), gave **10 FAILED
(318 passed)**:

- `PF1723r6`: a `$` comment line inside a card
- `PF1723r7`: `v (x1.q)` with a blank
- `PF1723r8`: the `\\` continuation
- `PF1723s8`: a top-level node whose own name holds a dot
- `PF1723s9`: a mis-cased leaf under `distinguish`
- `PF1723s10`: two spellings of a stale prefix under `fold`
- `PF1723t5`: a read-only include
- `PF1723af3`: the console command's last sentence
- `PF1723ai`: the text window's change test. On that code the proc does not exist, so every leg
  raised `invalid command name`.
- `PF1723ah3`: end to end on `/usr/bin/ngspice`

`test_ase_window`, display arm (`AUDIT_DISPLAY=private`, a private Xvfb with openbox), gave **2 FAILED
(387 passed)**: `FX1723Ie` (a model folder's file opened with no Save) and `FX1723Ih` (Save wrote over a
changed file without asking).

These rows were green on that code, which is right, because the code they cover was already correct:

- `PF1723t4`: the refusal's arms
- `PF1723ag3`, widened: the peek creates no folder
- `FX1723Id2`: Remove from a clean session
- `FX1723Ie3`: a file the user cannot write

They exist so that breaking that code is seen. The sweep below shows that each one can go red.

## Method

A scratch Python driver, not committed, made one text substitution per sabotage in one of the three
source files. It refused any site whose text did not occur exactly once. For each sabotage it:

1. checked that the file was the fixed copy;
2. wrote the sabotaged text over the file;
3. ran the named suite, either `--nogui` (the counted headless arm) or with `AUDIT_DISPLAY=private`;
4. wrote the fixed text back and checked its md5.

All three files compared equal to the fixed copies after the sweep.

The baseline is `test_ase_preflight` ALL PASS (327 headless) and `test_ase_window` ALL PASS (389 on the
display arm). `PF1723ah3` was added after the sweep, which brought the count to 328. S1, S2 and S3 were
then run again on the 328-check tree, and each also reddened `PF1723ah3`.

## Results

| id | site (symbol) | substitution | what it breaks | arm | red rows |
|---|---|---|---|---|---|
| S1 | `ase::spice_lines` | the skip test drops `$` | finding 1: a `$` line ends the card and its words become element words | P | PF1723 r6, ah3 |
| S2 | `ase::spice_lines` | the `\\` pass → `if {0}` | finding 3: a continued card's next line is not read | P | PF1723 r8, ah3 |
| S3 | `ase::include_card_idents` | `preflight_ident_spans $seg 1` → `$seg` | finding 2: `v (x1.q)` is not read | P | PF1723 r7, ah3 |
| S4 | `ase::netlist_map_resolve` | the dotted-node lookup → `if {0}` | finding 6: `out.p` is refused and "corrected" | P | PF1723s8 |
| S5 | `ase::include_name_fix` | the whole-name arm → `if {0}` | finding 4: `x1.A1` is written `xdut.A1` | P | PF1723s9 |
| S6 | `ase::preflight_rename_solve` | group by the folded prefix again | finding 7: `x1`/`X1` decided as one group | P | PF1723s10 |
| S7a | `ase::preflight_gate` | not-editable arm → "ASE-L does not edit your files" | finding 9 | P | PF1723 t4, t5 |
| S7b | `ase::preflight_gate` | mixed arm → the same sentence | finding 9 | P | PF1723t4 |
| S7c | `ase::preflight_gate` | door-only line → the same sentence, no door | finding 9 | P | PF1723 t4, t5 |
| S7d | `ase::preflight_gate` | resolved-only arm drops `($door)` | finding 9 | P | PF1723t4 |
| S8 | `ase::include_hand_first` | always `{}` | finding 5: a read-only file is not said | P | PF1723t5 |
| S9 | `ase::preflight_fix_includes` | the blocked-file note → `if {0}` | findings 8/10 | P | PF1723af3 |
| S10 | `ase::include_rundir_peek` | returns `[ase::rundir $state]` | finding 11: the peek creates the folder | P | PF1723ag3 |
| S11 | `textwindow_disk_changed` | always 0 | finding 13, the decision | P | PF1723ai |
| S12 | `textwindow_save` | the ask condition → `0 &&` | finding 13, the press | W | FX1723Ih |
| S13 | `ase::ui::incdlg_remove` | `ase::session_save $key` after the update | finding 12 | W | FX1723Id2 |
| S14 | `ase::ui::incdlg_open` | read-only by the press's verdict (`include_edit_verdict`) again | finding 5 | W | FX1723Ie |

P is `test_ase_preflight --nogui` and W is `test_ase_window` with `AUDIT_DISPLAY=private`. Every
sabotage reddened only the rows listed; every other row stayed green.

## Measurements behind the rows

The hand decks (`/usr/bin/ngspice` 45.2, and the fork ver_53 with `-D casemode=distinguish -D
casemodewrite`) are tabulated in the issue file's "Fix round 2" section. Each row's fixture uses a
shape from that table: rc 1 with `.nodeset syntax error` for the stale shapes, and rc 0 for the
dotted node `out.p`.

## Not in this sweep

`G2sens` in `test_ase_dialogs` is red on the display arm with the same values at `a464b7f6b`, at
`2f1b8bca7` and on this tree (`{1 1 0 1 0 Entry Entry normal}`, expected `{1 1 0 0 0 Entry Entry
normal}`). That is issue 1436, filed and not fixed, and not this round's.

`N9` in `test_op_annot`, which was run because `textwindow` changed, is red on both arms. It is equally
red with `2f1b8bca7`'s sources (1 FAILED, 485 passed, headless). The row compares a status-bar sentence
that carries an absolute path, and the product shortens that sentence ("…") when the path is long.
This worktree's path is 71 characters. That is CLAUDE.md's deep-clone rule, not a defect here.
