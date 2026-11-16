# Stage D2 receipt: findings F1 to F3 of `D-verify.md` (the orphaned drag, row Z, one comment)

Crew D2, 2026-11-15. Base `e6b38ba83` plus `D-fix.patch` (md5 `b01c6eb1ee97e592eb777d056ca86270`,
checked before applying), committed in the clone `~/gdf3` as the scratch commit `18ec56823`. The
D2 change is uncommitted on top of it.

- **`D2-incremental.patch`** (next to this file), **md5 `94056d1e5b096a16720f15ca844d3e32`**: D2 only, over `D-fix.patch`.
  7 files, +395 −6: `src/move.c`, `src/save.c`, `src/scheduler.c`, `src/xschem.h`, the suite,
  and the two issue files. `git diff 18ec56823`.
- **`D-combined.patch`**, **md5 `6c0d21198ed4827c294d7cba96b1061a`**: D-fix plus D2 as one `git diff` against
  `e6b38ba83` (the suite D-fix added is tracked in the scratch commit, so no untracked file is
  left out). 10 files, +1278 −30.
- Applying `D-fix.patch` then `D2-incremental.patch` to a `git archive e6b38ba83`, and
  `D-combined.patch` alone to another, both give all 10 changed files byte-identical to `~/gdf3`.
- Checked against the main tree, not applied: `git -C /home/analog/dev/xschem-claude apply --cached --check D-combined.patch`
  exit 0, and `git -C /home/analog/dev/xschem-claude apply --check D-combined.patch` exit 0.

## In plain English

**What was still wrong after stage D.** Stage D stopped a drag from marking the page modified
while it is still in progress, so that Escape leaves the page as it was. But a drag can also end
without Escape and without a release: pressing `u` (undo), Shift-U (redo) or `n` (netlist) while
the mouse button is still down, or a script running `xschem unselect_all`, `undo`, `redo` or
`netlist` in the middle of one. Those clear the drag without finishing or cancelling it. The
shapes stayed where the drag had put them, but the page read "not modified", no backup was
written, and quitting did not ask to save. Before stage D this worked only by accident, because
every mouse step marked the page.

**What changed.** When any xschem command finishes, it now checks whether it ended a drag that
way. If it did, and the page on screen is still the page the drag started on, the page is marked
modified once, which also writes its backup. If the command replaced the page (opening another
cell, reloading, clearing, going up or down the hierarchy) or saved it, nothing is marked, because
the drag's shapes went with the old page or are already in the file.

**Why not the fix the verifier proposed.** That fix marked the page at the moment the drag was
cleared. It was built and measured. Most commands clear the selection before they tear the page
down, so it wrote stray backups of cancelled drags, wrote a lower level's shapes into the top
cell's backup, wrote an empty backup during an undo, and with a display it crashed xschem on a
descend in the middle of a drag. The shape taken gives the same result on every case the verifier
named, and on all 58 keys pressed mid-drag, without any of those.

**The other two findings.** The suite's crash-recovery row could not fail, because no load in the
suite was of the kind that offers recovery. It now opens a cell interactively with a planted
backup and answers the dialog, and a copy with the offer removed turns it red. One comment in
`src/save.c` said something true only when autosave is on; it now says so.

## 1. Changes, by symbol

**`src/move.c`**
- `fluid_reroute_orphan_check()` (new). Returns unless all of these hold: the reroute snapshot is
  armed and dirty (`fluid_reroute_active`, `fluid_reroute_dirty`); `STARTMOVE` is gone; the
  gesture's latch `fluid_reroute_settled` is not set. It then sets the latch, and calls
  `set_modify(1)` only if `currsch` and `sch[currsch]` are still the level and file recorded at
  START. The latch is set before `set_modify()` because that call's Tcl can re-enter `xschem()`.
- `move_objects()`, START arm: records `fluid_reroute_level`, `fluid_reroute_sch` and clears the
  latch, next to the existing `fluid_reroute_active = 1`.
- `fluid_reroute_discard()`: also clears the latch.

**`src/scheduler.c`**
- `xschem()`: a file-scope nesting depth, `xschem_depth`, incremented on entry (after the argc
  check, before which nothing is done) and decremented after the dispatch switch. At depth 0 it
  calls `fluid_reroute_orphan_check()`, before the `cadsnap_cache_ok = 0` drop. There is no return
  between the two.

**`src/save.c`**
- `load_schematic()`: sets the latch in its `reset_undo` branch. A new document instance; a reload
  is the same level and file, so only this tells them apart.
- `save_schematic()`: sets the latch after `remove_backup()` when the gesture is armed and no longer
  live. The `unselect_all()` earlier in that function is what orphans it, and the geometry is now
  in the file.
- The comment above `level_backup_is_mine()` (F3). Code unchanged.

**`src/xschem.h`**: the three fields in `Xschem_ctx` (`fluid_reroute_level`,
`fluid_reroute_sch[PATH_MAX]`, `fluid_reroute_settled`) and the prototype.

**`tests/headless/test_drag_abort_backup_1716.tcl`**: band O (rows O0 to O13 and O12b), row E4 and
its non-vacuity row E4n in band E, band Z reworked (Z1 to Z3), and the header.

**Issue files**: a D2 follow-up section at the end of 1716 (the shape, why not fix A, the fence,
the descend change) and of 1715 (F2 and F3). Stamps unchanged; `tclsh
tests/headless/issue_stamp.tcl` gives `ISSUE-STAMP: ok (0 problems)`.

## 2. Why fix A was not taken (measured, B = base `e6b38ba83`, D = D-fix, A = fix A, N = this)

Fix A is the verifier's: `set_modify(1)` inside `unselect_all()` when `STARTMOVE`, armed and dirty,
plus a `modify_hold` around `mem_restore_slot()` in `fluid_reroute_restore()`. Built verbatim on
D-fix. Probe `scr/teardown.tcl` (a live stretch of l1 p2 p4, then a verb), headless:

| after the verb, mid-drag | A | D and N |
|---|---|---|
| `xschem clear force` / `clear` / `load` / `load -gui` of another cell, at the top | stray `bandgap~.sch` of the cancelled drag | none |
| child level: `clear force` | `tb_bandgap~.sch` holding the CHILD's geometry (C=115, N=58) | none |
| child level: `load`, `go_back`, `go_back` answered yes | stray `bandgap~.sch` | none |
| `xschem reload` (suite row O9) | stray `bandgap~.sch` | none |
| `undo 0 0` with history (memory and disk undo, and after a save) | an EMPTY `~` (C=0, N=0) | no empty `~` |
| `unselect_all`, `undo` and `netlist` with no history | modified 1, `hierarchy_modified` 1, `~` = the screen | A = N |

On the display arm fix A also **crashes**: SIGSEGV in `set_modify()` called from `unselect_all()`
inside `descend_schematic()` (gdb, `o/gdb_A.txt`), on `xschem descend` and on `xschem descend 1 0`
mid-drag, every time (probe `scr/desc.tcl`). D and N survive both. Headless it does not crash.

On the verifier's own tables A and N are equal: `unsel`, `cmds`, `savemid`, `orphan` (the quit
prompt), `stepmod` (0/0 at every step and after an abort), `hold`, `bk`. The key sweep (§5) is
equal on all 58 keys, and the synthesised area-select gesture (`disp.tcl` d08/d09) is declared on
both (`modified=1 bak=1`, as base; D gives `0 0`).

## 3. Red first

The suite, final version, both arms. Headless 60 checks, display 71.

| build | headless | display |
|---|---|---|
| B (`~/gdb1`) | 23 FAILED (37 passed) | 27 FAILED (44 passed) |
| D (D-fix) | **5 FAILED**: O1 O2 O3 O4 O6 | **6 FAILED**: O1 O2 O3 O4 O6 E4 |
| A (fix A) | 7 FAILED: O6 O8 O9 O10 O11 O12 O13 | SIGSEGV after O11 (exit 139) |
| N (this) | ALL PASS (60) | ALL PASS (71) |

- **Red on D, green on N:** O1 (`unselect_all`), O2 (`undo`), O3 (`redo`), O4 (`netlist
  -noalert`), each asserting modified 1, `hierarchy_modified` 1 and the `~` holding the sheet on
  screen, with legs proving the gesture really was orphaned and p2 really moved; O6 (`undo 0 0`
  with history: on D the `~` is the stale pre-drag one); and E4, the real `u` key pressed with
  Button-1 held (`E4n` proves STARTMOVE was set, nothing declared before the key, STARTMOVE gone
  after it, p2 moved).
- **Green on D and N, red on A:** the rows that fence what fix A got wrong: O8 to O13. O0 (the
  per-step leg) is green on D, A and N, red on B (where every step declares) and red on the copy
  that has fix A's first hunk alone (§4).
- **O6's control**, measured on B, D and N alike: `xschem undo 0 0` of a plain edit, with no drag,
  leaves the `~` stale. Its second argument asks `pop_undo` not to touch the modify state. On N the
  `~` matches the screen after the drag case only because the orphan is declared after the verb.
- B fails the new rows it fails for the 1716 defect itself (every step declares).

## 4. Copies broken on purpose

Built in place in `~/gdf3/src` (`variant.sh`, edits in `ved/*.py`), the binary kept, the sources
restored and rebuilt. After each one, every `.c`, `.h`, `.tcl` and `.o` in `src/` is byte-identical
to the reference taken before the first copy, except `scheduler.o`, which embeds `__DATE__` and
`__TIME__`. Suite counts are for the final suite (60 / 71 checks).

| copy | removed | headless | display |
|---|---|---|---|
| `Ah1` | fix A's FIRST hunk alone, on D-fix (declare in `unselect_all()`, no hold around the live step's restore) | 12 FAILED: **O0**, A1 A2 A3 R2 R4, O6 O8 O9 O10 O11, then band O ABORTED (`instance not found`) | O0, A1 A2 A3, O6 O8 O9 O10 O11, then SIGSEGV (exit 139) |
| `Nstart` | the `STARTMOVE` test | 16 FAILED: O0 O1 O2 O3 O4 O6 O8 O9 O11 O12 O13, A1 A2 A3 R2 R4 | 20 FAILED: those, and E1 E2 E4 E4n |
| `Nident` | the level and file test | O12 O13 | O12 O13 |
| `Nload` | the `load_schematic()` latch | O9 | O9 |
| `Nsave` | the `save_schematic()` latch | O7 | O7 |
| `Nonce` | the latch the check sets itself | O5 | O1 to O6 and E4: the declaration's own Tcl re-enters `xschem()` and the check recurses (Tcl "too many nested evaluations", 96 times) |
| `Ndepth` | outermost-only (check at every `xschem()` exit) | ALL PASS (60) | **O7** |
| `Zoff` | the crash-recovery `tcl_call` in the `xschem load` branch | ALL PASS (Z2 and Z3 skip) | Z2 Z3 |

So every guard has at least one row that goes red without it. The depth guard is fenced on the
display arm only: there, a nested `xschem` call made by display-only Tcl inside `save_schematic()`
runs the check before the save latch is set, and the saved sheet reads modified.

The brief's "first hunk alone turns the per-step row red" is row `Ah1`: O0 red on both arms.

O12 and O13 were added after `Nident` passed the first version of the suite. The first O12 used
plain `xschem descend`, which loads the child with an undo reset, so the latch already covered it.
The no-title forms load without one: `descend 1 0` (bit 0 of the last argument clear, as in
`src/op_annot.tcl`'s `xschem descend $n 2`) and `go_back 2` (`src/op_annot.tcl`, `src/ase.tcl`).

## 5. The key sweep (58 keys pressed mid-drag, display arm)

`keys.sh` with the verifier's `keys.tcl` and key list, one xschem per key, on `:310`–`:313`.
- D against N: 3 keys differ, `u`, `U` and `n`. D reads UNDECLARED on those three, N declares them.
- A against N: 0 keys differ.
- B against N: 47 differ, all because B marks an aborted drag modified (the 1716 defect).
- No key reads UNDECLARED on N.

## 6. F2: row Z

Row Z (`$::recovers == 0`) could not fail: every load in the suite is scripted, and only an
interactive `xschem load -gui` with a display (`if(!force && has_x)` in the `xschem load` branch)
calls `xschem_recover_backup`.
- **Z1** is the old row, renamed for what it measures: no scripted load offered recovery.
- **Z2/Z3** (display arm; headless prints an uppercase `SKIP:` line): the suite keeps the product's
  `xschem_recover_backup` aside, restores it for the band, and answers `tk_messageBox` itself. A
  foreign `bandgap~.sch` is planted after `xschem clear force`, and `xschem load -gui` of
  `bandgap.sch` is made into that pristine untitled window. Z2 answers Yes: one offer, the sheet
  modified, p2 at the backup's 220 -80. Z3 answers No: one offer, clean, p2 at 150 -130, backup
  deleted.
- `Zoff` turns both red; the other three builds pass them.
- **A gap found on the way, not filed:** the first version opened from an OCCUPIED window (`fresh
  $TB` loaded) and got no offer at all, with the backup left in place. Reading the branch: a
  `-gui` open from a non-pristine window sets `route_newwin`, presets `first_loaded`, and goes
  through `new_schematic("create", …)`, which never reaches the `xschem_recover_backup` call. So
  crash recovery is offered only when the open lands in place. This is the code at `e6b38ba83` too
  (one measurement plus reading; base not run). Worth an issue if the driver agrees.

## 7. F3

The comment above `level_backup_is_mine()` now says go_back adopts that file "only if
autosave_backup is on again by the ascent: load_backup_as() declines with autosave off, and the
level is then loaded from disk". Comment only: `gcc -E -P` of `save.c` with the old and the new
comment gives identical output.

## 8. T1 delta (derived, not run)

The suite's real output captured in T1's own arm shapes from `~/gdf3/tests` with the in-tree
binary: `hcases` as `env -u DISPLAY … ../src/xschem --nogui --pipe -q --script headless/…`, `dcases`
as `--pipe -q --logdir <dir> --script …` on a private Xvfb + openbox (`:310`), each under
`timeout --kill-after=20 900` and a throwaway HOME. Scored with stage D's `derive.tcl`: all 16 procs
lifted from `tests/run_regression.tcl`'s own text, `tests/banner_rule.tcl` sourced.
- Registration (evaluated from the lists): `hcases` 137 → 138, `dcases` 60 → 61, so
  **`planned_cases` 201 → 203** against `e6b38ba83`. Unchanged by D2.
- Captures: `hcases` `RESULT: ALL PASS (60 checks)`, exit 0, `OVERALL: ok (60 checks)`; `dcases`
  `ALL PASS (71 checks)`, exit 0.
- **Delta against `e6b38ba83`: cases +2, blocks +2, counted_failures +0, skips +0, `wc -l` +6.**
  No lowercase `^skip:` line on either arm. The two skip announcements on the `hcases` arm
  (band E, band Z) are uppercase `SKIP:`.
- Against D-fix alone only the published counts move: 45 → 60 and 52 → 71.

## 9. Health

- **Warnings**: every object in `src/Makefile`'s OBJ compiled with the build's flags, three ways,
  for `e6b38ba83`, D-fix and N: cairo 6 / 6 / 6, no-cairo 6 / 6 / 6, `-std=c89 -pedantic`
  67 / 67 / 67. The texts (line numbers stripped) diff empty in every pair. N's own `make -C src`
  log shows the same 6.
- **valgrind** (`env … valgrind -q`, `env` first) on the suite with the in-tree N binary: headless
  ALL PASS (60), display ALL PASS (71), both logs empty.
- **Suites touching drag, undo, select and save**, through `tests/headless/run_suites.sh`, each on
  D and N, `--nogui` with `AUDIT_DISPLAY=none` and the display arm with `AUDIT_DISPLAY=:312`, the
  clone cleaned of `*~.sch` and `untitled*` before every run:
  `test_cadence_drag`, `test_cadence_stretch_move`, `test_drag_keeps_selection`,
  `test_drag_tclvar_reads`, `test_connected_drag_keeps_selection_0113`,
  `test_connected_drag_group_transform_0114`, `test_fluid_editing`,
  `test_fluid_ortho_second_drag_0132`, `test_fluid_second_gesture_body_cross_0139`,
  `test_fluid_bodyshove_guards_0132`, `test_label_ride`, `test_rotate_stretch_reconnect`,
  `test_perform_action_move_instance`, `wireedit/test_wireedit_01_stretch_off`,
  `wireedit/test_wireedit_14_undo`, `wireedit/test_wireedit_28_escape_normal`,
  `wireedit/test_wireedit_33_incremental_step`, `test_undo_move_keep_selection`,
  `test_undo_selection`, `test_scripted_shape_undo`, `test_paste_modify_flag_0244`,
  `test_select_at`, `test_wire_complete_with_selection`, `test_autosave_hook`, `test_backup_file`,
  `test_backup_hidden`, `test_backup_recovery`, `test_save_as_cellview`,
  `test_save_reload_copy_selflog`, `test_check_and_save`, `test_hier_close_prompt`,
  `test_untitled_autosave_1486`, `test_no_untitled_litter`, `test_descend_preserve`,
  `test_descend_readonly`, `test_hier_walkup`, `test_close_window_force`,
  `test_load_window_routing`, `test_drag_abort_backup_1716` (39 suites, 78 runs per binary).
  - **76 of the 78 verdicts are identical** on D and N, failing row names included. The 2 that
    differ are this suite's (D 5 and 6 FAILED, N ALL PASS on both arms).
  - The non-passes, identical on both binaries. Each suite is in `D-fix.md` §5's list of suites
    failing the same way on stage A and stage D: `test_cadence_drag` display (*Ctrl+drag leaves wires behind*, *non-cadence plain
    drag leaves wires behind*), `test_select_at` display (`SA5`, `SA6b`, `SA7b`, `SA8b`, and
    *action log open*), `test_load_window_routing` headless (`LR1b`, `LR5b`, `LR5e`, `LR6`; display
    ALL PASS), `test_paste_modify_flag_0244` display `TIMEOUT` (200 s; headless ALL PASS, 444
    checks), and 3 headless `NORESULT` from display-only suites (`test_cadence_drag`,
    `test_select_at`, `test_wire_complete_with_selection`). 9 headless self-skips.

## 10. Not covered, and limits

1. **A scripted `xschem descend` mid-drag now discards the drag.** On B the live steps had declared
   it, so the descend persisted it and go_back brought it back modified. On D, A and N the parent
   comes back clean at its disk geometry. Consistent (nothing undeclared), but a change from B, and
   stage D already had it. Row O12b holds it to "declared or pristine". The key sweep cannot say
   whether the `e` key does this: `e` mid-drag timed out the probe on every build, base included
   (RC 124, as did `Insert`, `b`, Ctrl-`f` and `t`).
2. **The depth guard is fenced on the display arm only** (§4).
3. **An orphaning followed by a new START inside one outermost command** was not driven. START
   re-arms the latch, so the first gesture's geometry would then be declared only by the second
   gesture's own END.
4. **`xschem make_symbol` mid-drag** reads `changed=1 modified=0` on B, D, A and N alike in the
   verifier's `cmds` probe. Not this stage's, and not a regression.
5. **Cost**: one function call per outermost `xschem` command, which returns at its first test
   unless a fluid stretch is armed. Not timed.
6. The crash-recovery routing gap in §6.

## 11. State left behind

- **`~/gdf3`**: `e6b38ba83` + scratch commit `18ec56823` (D-fix) + the D2 change, uncommitted. The
  build in `src/` is N. No `*~.sch` or `untitled*` left in the clone: three ignored
  `tests/from_user/before_*~.sch` written during the suite stream, and one `.scratch/_p0244_*`
  directory from the `test_paste_modify_flag_0244` run its timeout killed, were deleted. `~/gdb1` and `~/gdv1` were
  only read.
- **Displays**: `:310`–`:317`, Xvfb and openbox started by this crew, killed by recorded pid at the
  end after checking each cmdline. Three xschem processes started during the key sweep (cmdline
  `-b -s --tcl set XSCHEM_START_WINDOW {}`, the new-process launch in `src/actions.c`) were found
  on `:311`–`:313` and killed by pid. No lock file is left for any of the eight. openbox may
  have written `~/.cache/openbox`.
- **`/tmp/xschem_emergencysave_*`**: fix A's SIGSEGV runs may have left empty
  `xschem_emergencysave_bandgap_*` directories there. None names this clone or this scratch, so
  none could be proved to be this crew's, and none was removed.
- **Scratch** (tmpfs):
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/dragD2/`.
  Throwaway homes and build copies deleted; scripts and small results kept.

| what | where |
|---|---|
| the suite on one arm | `suite.sh <B\|D\|A\|N2\|copy> <ng\|:31x> <out>`; results `o/suite_*_{ng,dp}.txt` |
| probes | `run.sh`, `dlaunch.sh`; `scr/teardown.tcl`, `scr/desc.tcl`, `scr/undo_nodrag.tcl`; the verifier's `vscr/*` |
| fix A | `fixA_verbatim.diff`; gdb `o/gdb_A.txt` |
| copies broken on purpose | `variant.sh`, `ved/*.py`, `variant_*.diff`, `md5_N_ref.txt`, `md5_after_*.txt` (the binaries in `bin/` were deleted) |
| key sweep | `keys.sh`, `keylist.txt`, `o/keys_{B,D,A,N}.txt` |
| T1 | `t1cap/` (scored with `../dragD/derive.tcl` and `planned.tcl`) |
| health | `warn.sh` (its lists in `wb/` were deleted after the comparison); `vg/`; `rs/stream.sh`, `rs/list.txt`, `rs/verdicts.txt`, `rs/*.log` |
