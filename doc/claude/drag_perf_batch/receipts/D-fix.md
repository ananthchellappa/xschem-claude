# Stage D receipt: issues 1716 and 1715 (a cancelled drag, and a backup that is not ours)

Crew D, 2026-11-15. Base `3b36f24a1` plus stage A's patch (`A-fix.patch`, md5
`a36e6556d0585785dcdb6e3f09a8b6f6`, checked before applying). The fix is in the clone `~/gdf1`,
uncommitted.

- **`D-fix.patch`** (next to this file), **md5 `b01c6eb1ee97e592eb777d056ca86270`**: stage D
  only, incremental over stage A. 9 files, +889 −30, the new suite included. It applies cleanly to
  a `git archive` of the stage-A tree.
- **The whole change against `3b36f24a1`** (stage A plus stage D as one `git diff`, untracked
  files included), **md5 `3e8abb96ccb2b0b0fd6e94e3c36fcb30`**: 14 files, +1402 −61. It is
  not saved as a file. `git apply A-fix.patch` then `git apply D-fix.patch` on a
  `git archive 3b36f24a1` gives every changed file byte-identical to `~/gdf1`.

## In plain English

**Issue 1716: what was wrong.** On a fluid-wiring page, every mouse step of a drag re-routes the
wires to show where they would go. The re-routing code marks the page "modified" as it works,
and marking a page modified also writes its backup file, `cell~.sch`. So every step of the drag
marked the page and wrote the half-finished geometry to the backup. Pressing Escape put the
geometry back, but not the mark and not the file. A page you never changed then showed `*`,
asked to be saved, and had a backup on disk holding a drag you had cancelled. On a page that
already had unsaved edits, the backup of those edits was overwritten by the cancelled drag. A
drag that xschem refuses at release (because it would short two nets) leaked the same way.

**Issue 1715: what was wrong.** Going back up the hierarchy, xschem reloaded the parent from
`cell~.sch` whenever one existed, whoever had written it. A backup left by another session (a
crash, a kill, or issue 1716's cancelled drag) made an untouched parent come back modified,
showing that file's geometry instead of the cell's. The next step up then asked "has unsaved
changes". Yes saved the stale geometry into the design file. No deleted a backup that may have
been somebody's crash recovery.

**What changed.**
- While a drag is in progress, and while xschem is still deciding whether to accept or refuse
  it at release, the "modified" mark and the backup write are put on hold. A completed drag
  then marks the page and writes the backup exactly as before. A cancelled or refused drag
  leaves the page as it found it: the same mark, and the same backup file (or none).
- When you descend, xschem now records, for the level you leave, whether its unsaved edits are
  in a backup this session wrote. Going back up uses the backup only when that record says so.
  Otherwise it loads the cell from disk and leaves any other backup where it is, unread and
  undeleted.

**What a user sees.**
- A cancelled or refused drag no longer marks the page or writes a backup.
- An untouched parent no longer prompts on the way up, and shows the geometry on disk.
- Your own unsaved edits are still restored when you come back up, still marked, and still
  prompted for. That includes a descend into a new window.
- Completed drags save byte-identical files to stage A: 470 saved pages and netlists, and 418
  backups.
- A drag step takes the same time or slightly less, because a step no longer writes the backup
  file (§6).

**Evidence.**
- A new suite, `tests/headless/test_drag_abort_backup_1716.tcl`, registered in both T1 lists.
- On stage A's binary, 16 of its 45 checks fail headless and 19 of 52 fail on the display arm.
  On this tree it passes all 45 and all 52.
- Each part of the fix has a broken-on-purpose build that turns named rows red (§3).
- Warnings, valgrind and `--nogui --pipe` match stage A, apart from the intended change (§6).
- Nothing is committed.

## 1. Issue 1716: cause and fix

**Cause.**
- `move_objects()` (`src/move.c`) runs the whole commit pipeline on every live step of a fluid
  stretch drag (`commit_now`).
- The passes in that pipeline call `set_modify(1)` as they mutate: `insert_exit_stubs()` every
  time, and `trim_wires()`, `remove_move_orphan_wires()` and the fluid shove, reroute and offset
  passes whenever they change something.
- `set_modify(1)` sets the flag, bumps `modify_seq` and calls `write_backup()`, which writes the
  whole live buffer to `cellName~.sch`.
- The ABORT branch rolls the geometry back and, as its own comment says, calls no
  `set_modify()`. So the flag and the file stayed.
- The B3 refusal at END leaked the same way. It also read the pre-gesture flag
  (`enf_mod_before`) at END, after the live steps had already set it. It then "restored" that
  wrong value with `set_modify(1)`, which rewrote the backup with the refused geometry.

**Fix: a hold, not a per-pass edit.**
- **`xctx->modify_hold`** (`src/xschem.h`). While it is above 0, `set_modify(1)` and
  `set_modify(3)` (`src/actions.c`) declare nothing:
  - no flag change and no `modify_seq` bump;
  - no `write_backup()`;
  - no button colours, no title, no `prev_set_modify` update.

  The floater and annotation cache flush still runs, because invalidating a cache is never wrong
  and the live redraw needs it. Other `set_modify()` arguments are not affected.
- **`move_objects()` takes the hold** inside its commit block when `commit_now || enf_snapped`:
  that is, on a live step, or on an END that can still be refused.
  - An END releases the hold at the accept/refuse verdict. An accepted move then declares itself
    with its own unheld `set_modify(1)`, as before.
  - A live step releases it at the end of the block.
  - There is no `return` or `goto` between taking and releasing the hold, and a local
    `mod_held` guards the release, so the counter cannot leak.
- **The refusal arm** now calls `set_modify(-1)` if the sheet was dirty before the gesture. That
  call refreshes the title and the caches and writes nothing, so the `~` keeps the user's edits
  byte for byte. If the sheet was clean, it calls `set_modify(0)`. `enf_mod_before` is now the
  true pre-gesture flag, because the live steps were held.
- **An END that cannot be refused is unheld** and behaves exactly as in stage A: no fluid
  stretch, enforcement off, `xctx->kissing`, a merge, or a place.
- **This is not the shape the issue proposed** (drop `insert_exit_stubs()`'s call, then restore
  on abort). The hold covers every pass, including the ones that only sometimes mutate, and it
  needs no snapshot of the backup file. The issue's new resolution section says so.

## 2. Issue 1715: cause and fix

**Cause.**
- `go_back()` (`src/actions.c`) loaded the parent with `load_backup_as()`. That function adopts
  any `cellName~.sch` that exists and ends in `set_modify(1)`, which rewrites the file and
  records it as this session's (`xctx->backup_owned`).
- Nothing recorded whether this session had written the file.
- `xctx->backup_owned` cannot answer that question on the way up either: it is one slot, and the
  child's first edit overwrites it.

**Fix: record ownership per level at descend time.**
- **`xctx->sch_backup_mine[CADMAXHIER]`** (`src/xschem.h`).
- **`level_backup_is_mine()`** (`src/save.c`) answers yes only when the current level is
  modified and `xctx->backup_owned` is exactly that cell's `~` path.
  - It does not consult `autosave_backup`, on purpose. With autosave off nothing is written, so a
    matching path can only come from an earlier write by this session, and that file holds this
    session's own edits (which `go_back()` adopted before this change too).
  - A first version did test `autosave_backup`. No row could tell the test was there:
    broken-on-purpose build S13 stayed green. It also changed stage A's behaviour when autosave
    was switched off after an own write, so it was removed.
- **`descend_schematic()`** (`src/actions.c`) and both descend sites in **`descend_symbol()`**
  (`src/save.c`) set the record for the level being left, just before `currsch++`.
- **`go_back()`** consumes (clears) the record and calls `load_backup_as()` only if it was set.
  Otherwise it calls `load_schematic()` from disk, and a `~` it did not write is neither adopted,
  rewritten nor deleted. `load_backup_as()` itself is unchanged, so `xschem load_backup` from
  the recovery prompt still adopts what the user chose.
- **`hierarchy_modified()`** (`src/save.c`, the deep close/quit guard) used to count any
  ancestor `~` as unsaved work. It now counts only the ancestors whose record is set.
- **`copy_hierarchy_data()`** (`src/actions.c`) copies the record along with the rest of the
  stack.
  - A descend into a new window builds the new window's hierarchy through this function.
    Without the copy, the new window's `go_back()` loaded the parent from disk and dropped the
    edits made before descending.
  - Row G10 found this on its first run: red on this tree, green on stage A. Broken-on-purpose
    build S14 confirms that the row needs the line.
- **A row that asserted the old behaviour.** Row `RT5` of `tests/headless/test_ase_core.tcl`
  had an unparked control that expected the ascent to come back **modified** beside a planted
  `rt_top~.sch` that this session never wrote. That is exactly issue 1715's defect, and the row
  used it as evidence that the park in `ase::with_design_current` was load-bearing.
  - It now expects the ascent to come back clean and the planted file to be byte-identical
    (`{0 0 1}`).
  - It is red on stage A and green here (674 checks). The park itself is still asserted.

## 3. The fence: red on stage A, green here, every part needed

`tests/headless/test_drag_abort_backup_1716.tcl` is new.
- It is registered in **both** `hcases` and `dcases` of `tests/run_regression.tcl`, in this
  change.
- It prints `OVERALL: ok (N checks)` and then `RESULT:` last, so `banner_complete` accepts it.
- Every cell it loads or writes is a scratch copy of the tree's own
  `sky130A/xschem_libs/sky130_tests_ase` cells (the issues' own designs), with an explicit
  `library.defs`. Row F1 proves the scratch copy is what loaded, before anything writes.

Band E is display-only. Under `--nogui` it prints one uppercase `SKIP:` line and runs nothing.
The other bands run on both arms.

- **A**: the scripted seam (`xschem move_objects start|step|abort|end` and
  `xschem abort_operation`), on `bandgap.sch` with the issue's selection `l1 p2 p4`.
  - A1: an aborted drag of a clean sheet.
  - A2: the same through `abort_operation`, which is Escape's path.
  - A3: an aborted drag of a dirty sheet, with the backup byte-identical at every step.
  - Non-vacuity legs: the selection moved at every step and came back.
  - Controls: A4, a completed drag still flags the sheet and writes the backup. A5, the hold did
    not leak past an aborted drag. A6, a completed drag of a dirty sheet does rewrite its backup.
- **R**: the B3 refusal, on issue 0105's named-rail fixture.
  - R1 and R2: one-shot and stepwise refusal of a clean sheet. R3 and R4: the same on a dirty
    sheet.
  - Controls: R5, with enforcement off the drag is accepted and writes. R6, the hold did not leak
    past a refusal.
  - Every R row also asserts that the refusal really fired.
- **G**: issue 1715, on `tb_bandgap` → `bandgap` → `bandgap_opamp`, with `ask_save` replaced by a
  counter that answers for the user.
  - G1: a foreign `bandgap~.sch` gives no prompt, the disk geometry, and an untouched file.
  - G2: the same, answering Yes: the cell file is byte-identical.
  - G3: `hierarchy_modified` ignores the foreign ancestor.
  - G6: own edits at the top and a foreign `~` in the middle.
  - Controls: G4, own edits at the top survive. G5, own edits in the middle are restored and
    prompt. G7, the same through `descend_symbol`. G10, the same through a descend into a new
    window.
  - G8 and G9 each isolate one of the two ownership tests.
- **E**: real Tk events, with `sky130A/cadence_style_rc` sourced as in the issues' reproduction.
  - E1: press, twelve motions, Escape and release on a clean sheet.
  - E2: the same on a dirty sheet.
  - E3: issue 1715's walk with the rc's settings.

**Red-first**: the same suite file, run with stage A's binary and with this tree's.

| binary | headless | display arm |
|---|---|---|
| stage A | 16 failed of 45: A1 A2 A3 R1 R2 R3 R4 G1 G1b G1c G2 G3 G6 G6b G8 G9 | 19 failed of 52: the same plus E1 E2 E3 |
| this tree | ALL PASS (45) | ALL PASS (52) |

On stage A, the control rows (A4–A6, R5, R6, G4, G5, G7, G10) and the non-vacuity legs pass, as
they should.

**Broken on purpose.** Each build is a one-site change to this tree's source, rebuilt, with
both arms run and then restored. Every time, the restored `move.o`, `actions.o` and `save.o`
md5s matched the recorded ones.

| build | what was broken | rows turned red |
|---|---|---|
| S1 | no hold at all (`if(0)` at the take) | A1 A2 A3 R1 R2 R3 R4; the display arm adds E1 E2 |
| S2 | hold only live steps (`if(commit_now)`), not a refusable END | R1 R2 R3 R4 (both arms) |
| S3 | no release at the verdict (an accepted END stays held) | A4 A4b A6 (both arms) |
| S4 | no release at the block end (the hold leaks past a live step) | A3 A3n A4 A4b A5 A6 R0, band R aborted, G4 G4b G5 G5b G6b G7 G8n G9n G10; the display arm adds E2 E2n |
| S5 | the old refusal line `set_modify(enf_mod_before ? 1 : 0)` | R3 R4 (both arms) |
| S6 | `set_modify()` ignores the hold (`held = 0`) | A1 A2 A3 R1 R2 R3 R4; the display arm adds E1 E2 |
| S7 | `go_back()` adopts any `~` again (the record is ignored) | G1 G1b G1c G2 G6 G6b G8 G9; the display arm adds E3 |
| S8 | `hierarchy_modified()` counts any ancestor `~` again | G3 (both arms) |
| S9 | `descend_schematic()` records 0 | G4 G4b G5 G5b G6b G10 (both arms) |
| S10 | both `descend_symbol()` sites record 0 | G7 (both arms) |
| S11 | `level_backup_is_mine()` skips the owned-path compare | G8 (both arms) |
| S12 | `level_backup_is_mine()` skips the modified test | G9 (both arms) |
| S14 | `copy_hierarchy_data()` does not copy the record | G10 (both arms) |

S13 (drop `level_backup_is_mine()`'s `autosave_backup` test) was green on every row, run on
the suite before G10 existed. So the test was removed rather than fenced (§2), and S13 no
longer has a site to break.

## 4. Identity: completed drags are byte-identical to stage A

This uses stage A's identity harness, ported, run with stage A's binary and with this tree's
final binary. It drags with the scripted seam on 8 real pages (up to 16 devices each, at snaps
10, 5 and 20), and also runs the GUI drag sequence on Xvfb + openbox.
- **Scripted seam:** 390 saved pages and netlists compared, **0 differ**. 366 are
  byte-identical as they stand. The other 24 are netlists that are identical once the tree
  letter in their embedded paths is mapped.
- **GUI sequence:** 80 files compared, **0 differ** (72 byte-identical, 8 path-mapped).
- **Backups:** both runs left the same 418 `~` files (356 seam, 62 GUI), and all 418 are
  identical.
- **Three backups only stage A leaves:** `is_sdfrbp s20.i43~`, `is_tbtcatran s5.undone~` and
  `ig_tbtcatran d0~`. Each sits beside a page whose drag changed nothing, a refused drag. That
  is issue 1716's leak, showing up inside the identity harness itself.
- **A second check on a stock example, `--nogui --pipe`** (§6): an accepted drag of `m1` on
  `xschem_library/examples/cmos_example.sch` gives the same backup md5 and the same saved file
  on both trees.

## 5. Suites: stage A vs this tree

**How they were run.** 245 suites (`suites_D.txt`), each on both arms through
`tests/headless/run_suites.sh` inside `~/gdf1`, with `GUI_GATE=0` and an explicit
`AUDIT_DISPLAY` (`:270` for stage A, `:271` for this tree). The headless arm is `--nogui`. `run_suites.sh`
still hands it that display, so it is not exactly T1's `hcases` arm; §7 captures that arm on its
own. Stage A's binary was a build of the stage-A tree in a scratch copy (`wd/A`);
both binaries ran `~/gdf1`'s tests. The two streams ran at the same time, stage A in list order
and this tree in reverse.

**Which suites.** Stage A's own 137 (79 headless plus the 58 `wireedit` suites); every suite
whose name matches `backup`, `descend`, `hier`, `untitled`, `modif`, `go_back`, `goback`,
`recover`, `autosave` or `close` (42); every suite whose text uses `get modified`, `~.sch`,
`go_back` or `hierarchy_modified` (101); plus `test_ase_core`, `test_op_annot` and the harness
suites (`test_issue_stamp`, `test_registered_banner_1626`, `test_suite_watchdog_1403`,
`test_scratch_home_note`, `test_drag_tclvar_reads`, `test_t1_display_arm`,
`test_regression_concurrency_1476`). Duplicates removed, and `test_home_isolation` left out as
the brief requires.

**Headless arm** (194 runs, 51 of them self-skip): stage A 171 pass, this tree 174. Three
suites differ:

| suite | stage A | this tree | why |
|---|---|---|---|
| `test_drag_abort_backup_1716` | 16 failed of 45 | all pass | the new suite, red first (§3) |
| `test_ase_core` | `RT5` fails | all pass (674) | intended: `RT5`'s unparked control now expects issue 1715's fixed behaviour (§2) |
| `test_descend_doors_1228` | `B2`, `B6` fail | all pass (31) | **where the binary was, not the fix.** Both rows expect paths in the clone, and stage A's binary ran from `wd/A`. Stage A rebuilt *inside* `~/gdf1` (its `move.o`, `actions.o` and `save.o` md5-identical to `wd/A`'s) passes all 31. |

**Display arm** (245 runs, 8 self-skip): stage A 210 pass, this tree 213. Five suites differ:

| suite | stage A | this tree | why |
|---|---|---|---|
| `test_drag_abort_backup_1716` | 19 failed of 52 | all pass | the new suite, red first |
| `test_ase_core` | `RT5` fails | all pass | intended, as above |
| `test_hier_pdf_links_1333` | `S64`, `S64b` fail | all pass (89) | **not stage D.** Stage A rebuilt inside `~/gdf1`: all pass. This tree alone: all pass. |
| `test_wave_hilight` | `WD1b` fails (stroke count 1578 → 1588) | all pass (196) | **not stage D.** Stage A rebuilt inside `~/gdf1`: all pass. Stage A from `wd/A`, run alone after the three suites that come before it in its stream: all pass. |
| `test_wave_markers` | all pass (984) | `TIMEOUT` | **the same on both binaries every time it was run again.** Alone through `run_suites.sh`: `TIMEOUT` on both (200 s, and 300 s for stage A). After the three suites that come before it in stage A's stream: `TIMEOUT` on both. Run directly, as `run_suites.sh` runs it, with a 240 s cap: **the same rows in the same order on both binaries**, 30 failing rows from `MF9` on (`no anchor pixel in the scan`), then a stall after `MF11a`, rc 124. So the pass in stage A's stream is the odd one out. Why that one run passed was not found. |

**Failing the same way on both trees** (same verdict, and the same failing row names wherever
the suite prints them; collected by `failrows.py`):

- **Headless:** `test_context_menu_descend_edit` (`CME1`, `CME2`), `test_load_window_routing`
  (`LR1b`, `LR5b`, `LR5e`, `LR6`), `test_op_param_store_1245` (`PK1`), `test_rdw_seam_1245`
  (`G3b`), `test_results_select` (`SEL462`, `SEL468`); and 15 `NORESULT`.
- **Display:** `test_cadence_drag` (*Ctrl+drag leaves wires behind*, *non-cadence plain drag
  leaves wires behind*), `test_calc_selector_names` (`PK11`), `test_descend_doors_1228`
  (0 passed), `test_op_param_store_1245`, `test_rdw_seam_1245`, `test_results_select`,
  `test_rotate_stretch_short_0104` (`rot180-ip`), `test_select_at` (`SA5`, `SA6b`, `SA7b`,
  `SA8b`), `test_snap_bindkeys`, `test_wave_axis_zoom` (`CV2c`); 7 `NORESULT`; and 6 `TIMEOUT`
  (`test_descend_symbol`, `test_load_window_routing`, `test_paste_modify_flag_0244`,
  `test_placement_preview_doors`, `test_raw_read_dispatch`, `test_shape_draw_gate`).
- **The ones in this batch's area were run again outside the streams**, both binaries at once
  on `:272` and `:273` with a 300 s cap: `test_paste_modify_flag_0244`, `test_cadence_drag`,
  `test_rotate_stretch_short_0104` and `test_snap_bindkeys` gave the same verdicts as in the
  streams on both. `test_descend_symbol` timed out on stage A but ended `NORESULT` on this tree.
  That suite uses a fixed directory, `/tmp/b6_descend_symbol_work`, which it deletes and
  rebuilds at start, and the two runs were in it at the same moment. Run one after the other,
  directly, with a 90 s cap: **the same 37 passing rows in the same order on both, then the
  same stall** at `SNW6` (*symbol_in_new_window* with nothing selected, after
  `load_schematic(): unable to open file: …/descend_parent.sym`), rc 124. So that suite hangs
  on the display arm on both trees. It passes on the headless arm on both.
- None of these was investigated further. They are stage A's verdicts as well, so they are not
  stage D's to explain.

**The binary.** For the confirmation runs, stage A's four changed sources were copied into
`~/gdf1/src` and built. Then this tree's sources were put back from `orig/`
(`cmp`-identical) and rebuilt. All 40 object files are md5-identical to the final build except
`scheduler.o`, which embeds `__DATE__`/`__TIME__`. So the binary's own md5 moved from
`be601ce2a5c8ac40364f37ebf0b65ead` (every measurement in this receipt) to
`b53a5dbba3d367aaa0c2adf16f6e7a4b`, from the same source.

## 6. Health

- **Warnings**, on the final source:
  - cairo build 6 = 6, no-cairo 6 = 6, `-std=c89 -pedantic` 67 = 67; the warning texts diff
    empty;
  - `-Wall -Wextra` on `actions.c`, `move.c` and `save.c`: 46 = 46, identical texts.
- **valgrind memcheck** (`--leak-check=full`):
  - On the new suite, both arms, stage A's binary and the final binary of this tree:
    - 0 invalid reads or writes, 0 uninitialised-value uses, 0 invalid frees;
    - definitely lost: 512 B in 2 blocks headless and 3,208 B in 3 blocks on the display arm,
      identical between A and D. Every one of those blocks is allocated inside fontconfig or
      cairo (for example under `cairo_font_extents` from `text_bbox`);
    - the `ERROR SUMMARY` totals (138 and 143 headless, 301 and 295 display) are possibly-lost
      Tcl/Tk pool records, none of the kinds above.
  - On stage A's seam and GUI drag sweeps (bandgap), measured on the binary before the
    `copy_hierarchy_data()` line (that line is not on a drag path): the same, 3,208 B definite
    in both trees.
- **`--nogui --pipe`**, stdin mode and `--script` mode, on a scratch copy of
  `cmos_example.sch`:
  - Both modes exit 0 on both trees.
  - An accepted drag gives an identical backup and an identical saved file, A vs D and stdin vs
    script.
  - An aborted drag and a refused drag leave the sheet clean with no backup on this tree; on
    stage A both leave it modified with a backup.
- **Per-step drag time**, which this batch is about: median ms per live step of a
  fluid stretch drag through the seam with drawing on (8 devices × 12 steps, Xvfb, two runs
  each, ABAB order). It was measured while the stage-A suite stream ran on the same machine,
  so the absolute figures are loaded ones.

  | page (instances) | stage A | this tree |
  |---|---|---|
  | tb_tca_tran (167) | 11.04 (first run), 8.41 | 8.16, 8.02 |
  | bandgap (115) | 6.52, 6.75 | 6.31, 6.29 |
  | test_comparator (168) | 10.05, 10.71 | 9.84, 9.72 |

  On stage A, all 96 steps of each run left the sheet modified. On this tree, none did. The
  small gain is the `write_backup` per step that stage A's §9 item 4 listed among the remaining
  costs; it is not a goal of this stage.

## 7. T1 delta (derived, not run)

The new suite's real output was captured in both T1 arm shapes: `hcases` is `--nogui --pipe -q
--script` with `DISPLAY` unset, and `dcases` is `--pipe -q --script` on a private Xvfb. It was
scored by lifting all 16 procs out of `tests/run_regression.tcl`'s own text and sourcing
`tests/banner_rule.tcl`.
- **Registration:** `hcases` 137 → 138 and `dcases` 60 → 61, evaluated from the lists' own text.
  So `planned_cases` goes 201 → 203.
- **Captures:** `hcases` arm `RESULT: ALL PASS (45 checks)`, exit 0, `OVERALL: ok`; `dcases`
  arm `ALL PASS (52 checks)`, exit 0.
- **Delta:** cases +2, blocks +2, counted_failures +0, skips +0, `wc -l` +6. The 6 are two
  block names, two `RESULT:` lines and two `Total num fail: 0`.
  - `skips` holds because the suite prints no lowercase `^skip:` line. Band E's one skip on the
    `hcases` arm is spelled `SKIP:`, which `summarize_all` does not count.
- **Stage A's binary on the same suite** scores counted_failures **+2**: one `HARNESS:` line per
  arm (exit=1, OVERALL_ok=0). So the registration is red-first at the gate level too.
- A full T1 was not run; that is the driver's gate.

## 8. Limits (declared, not fixed)

1. **`insert_exit_stubs()` keeps its unconditional `set_modify(1)`.** Under the hold it is
   harmless. A completed drag that ends where it began still flags the sheet modified, as in
   stage A.
2. **Ownership is by path, not content.** If another process overwrites this session's own `~`
   between the descend and the `go_back()`, the overwritten file is adopted.
3. **The autosave-off reload edge is unchanged.** The sequence: edit with autosave on (an own
   `~` is written), reload the cell to discard the edits, turn autosave off, edit again, descend
   and go back. The stale own `~` is not adopted, because `load_backup_as()` declines with
   autosave off. But the new edit is lost, as it was before (issue 0626's family).
   `xctx->backup_owned` is still not cleared on load (issue 1486, one slot).
4. **Traversals that bump `currsch` themselves** (the netlisters, `hilight.c`) neither set nor
   read the record. They restore `currsch` themselves and never reach `go_back()`. Any entry
   above a level that `currsch` was reset to is rewritten by the next descend before anything
   reads it.
5. **Stale comments elsewhere.** `src/ase.tcl` (above `ase::with_design_current`),
   `src/op_annot.tcl` (I4, above `op_annot::_park_backup`) and the W19a/W19b comments in
   `tests/headless/test_op_annot.tcl` describe `go_back()` adopting any `~`, as dated
   measurements. They were not edited. The autosave parks they explain are now redundant for a
   clean buffer, but harmless; `test_op_annot` passes unchanged on both trees.
6. **Foreign `~` files still exist and still trigger the recovery prompt** when a cell is
   opened directly. That path is unchanged. The main tree held 59 `*~.sch`/`*~.sym` files when
   checked (2026-11-15 17:0x; the count moves). This fix stops `go_back()` adopting them; it does
   not remove them.
7. **The stamps say `tree=3b36f24a1`**, the base, as issue 1712's precedent does. The driver may
   restamp them at the commit. `tclsh tests/headless/issue_stamp.tcl` says `ok (0 problems)`.
8. **Input was synthesised, on Xvfb.** No real hand drag was made on the user's display.
   Synthesised Escape goes through the same `abort_operation` → `move_objects(ABORT)` path.
9. **Not built on Windows or against Tcl 8.4.** The change is plain C89 (verified with
   `-std=c89 -pedantic`) and uses no new Tcl API.

## 9. Reproduction

**The new suite, by hand, in a clone with the fix** (it writes only under its own scratch dir;
use a private display, never `$DISPLAY`):

```sh
cd <clone> && GUI_GATE=0 AUDIT_DISPLAY=:<private> tests/headless/run_suites.sh --nogui test_drag_abort_backup_1716
cd <clone> && GUI_GATE=0 AUDIT_DISPLAY=:<private> tests/headless/run_suites.sh test_drag_abort_backup_1716
```

**Scratch** (tmpfs, may be gone):
`/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/dragD/`.
The big outputs (tree copies, identity outputs, warning builds) were deleted at the end. The
scripts and the small result files were kept.

| what | where |
|---|---|
| trees | `~/gdf1` (D); `wd/A` was a copy of the stage-A tree with its own build (deleted); `wd/D/src` was a link to `~/gdf1/src` |
| the new suite on one arm | `st.sh <A\|D\|binary> <nogui\|:27x> <tag>`; logs `log/fin_{A,D}_{ng,dp}.log` |
| broken-on-purpose builds | `sab.py`, `sabrun.sh`; table `sab_table_final.txt` |
| T1 scoring | `derive.tcl`, `planned.tcl`; captures `t1cap/` (D), `t1capA/` (A) |
| suites | `rsstream.sh`, `suites_D.txt` (and `suites_D_rev.txt`, the same list reversed); verdicts `rs/{A,D}_{ng,dp}.txt` and `.norm`; failing row names `failrows.py`; the confirmation runs `rs/recheck/`, and `wmcap.sh` for a direct run in `run_suites.sh`'s shape, logs `log/{wmcap,ds}_{A,D}.log` |
| identity | `id/identpass.sh`, `id/identgui.sh`, `id/ident_seam.tcl`, `id/ident_gui.tcl`, `id/cmpdir.sh`, `id/cmpbak.sh`, `id/hrun.sh` |
| health | `warn.sh`, `vgsuite.sh`, `vgsum.sh`, `id/vg.sh`, `pipe/run_pipe.sh`, `pipe/pipe.tcl` |
| timing | `scr/steptime.tcl` (through `id/hrun.sh`); results `out/st/` |
| the issues' own reproductions | `scr/repro1716.tcl` (real Tk events), `scr/repro1715.tcl` (the walk), through `run.sh`; results `out/r171*` |

Every run used a private Xvfb + openbox on `:270`–`:275` or `env -u DISPLAY`, a throwaway HOME
and `GUI_GATE=0`, plus an explicit `AUDIT_DISPLAY` for `run_suites.sh`. `test_home_isolation`
was not run.
