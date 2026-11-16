# Stage D verification: issues 1716 and 1715

Patch verified: `doc/claude/drag_perf_batch/receipts/D-fix.patch`, md5
`b01c6eb1ee97e592eb777d056ca86270`, applied on `e6b38ba83`. Verified 2026-11-15 by an
independent crew that re-measured rather than read the crew's receipt `D-fix.md`.

## Verdict: SAFE WITH LIMITS

The two fixes do what they say, and the risk the brief named first does not happen: the
modify hold is never left set after a gesture, so it cannot swallow a later real edit. Base
and patch produce the same saved files and netlists on ten real pages the crew did not use,
and the same suite verdicts on both arms.

One regression was found (F1, medium). A live fluid drag can end without an END or an ABORT.
On the patch, the moved shapes then stay on screen while the sheet says it is not modified,
no `~` backup is written, and quitting does not ask to save. One physical way in is to press
`u`, `Shift-U` or `n` while still holding the mouse button during a drag. Base flagged this
case, by accident, through the per-step `set_modify(1)` that the patch now holds back. A
two-hunk fix was built and measured below; it closes every case found and changes nothing
else that was measured. **Recommendation: land D with fix A and a row for it.**

## In plain English

- Cancelling a drag with Escape, or having a drag refused, now leaves a clean sheet clean,
  with no backup file. Before the patch the sheet stayed "modified" and the cancelled shape
  was written to the backup. This holds for scripted drags, for real Tk events on Xvfb, for
  clean and dirty sheets, and through two windows (tabs).
- Going back up the hierarchy no longer picks up a `~` file another session left behind. It
  picks up only a file this session wrote for that level. Another session's file, or a
  crash-recovery file, is left untouched instead of being adopted, or deleted by "No".
- The gap (F1): a drag can be ended by something that is neither a release nor Escape, such
  as Undo, Redo, Netlist or Unselect pressed mid-drag. Then the moved shapes stay on screen,
  unflagged. If the user quits, the move is lost without a prompt. If they make any later
  edit, the move is saved along with it. Earlier unsaved edits are not affected: their flag
  is never cleared.

## 1. Findings

### F1 (MEDIUM, regression): a fluid drag ended by `unselect_all()` leaves its moved geometry undeclared

**Physical repro (Xvfb + openbox, synthesised events, with `fluid_editing`,
`cadence_compat` and `fluid_enforce_invariants` all 1, as the cadence-style rc sets them):**

1. Open the bandgap page clean.
2. Press-drag a selection, keeping the button held for four motions.
3. Tap `u`, then Escape, then release.

On the patch, the shapes stay moved (`changed=1`), the sheet reads `modified=0`, no `~` is
written, and `hierarchy_modified` is 0, so quitting does not prompt. Base gives
`modified=1 bak=1`. `Shift-U` (redo) and `n` (netlist) behave the same. Of 58 keys swept
mid-drag, these three are the only patch regressions.

A third way in, so far seen only with synthesised events (`disp.tcl` d08/d09): press `m` to
start a move, then send motion events that carry the Button-1 state without a press. The
motion handler takes its area-select branch, and that branch calls `unselect_all(1)` without
excluding STARTMOVE. Afterwards p2 sits at 170,-110 with `modified=0 bak=0` on the patch, and
`modified=1 bak=1` on base. A real pointer normally cannot produce this sequence. The same
sequences with motion state 0, followed by a click or a press-drag, are declared on the patch
(`d08b.tcl`), because the press drops through END.

**Scripted repro:**

```
xschem move_objects start X Y stretch
xschem move_objects step ...      (3 times)
xschem unselect_all               (or: xschem undo | xschem redo | xschem netlist -noalert)
```

Read `modified`, the `~`, and the instance position. Patch: `modified=0 bak=0`, p2 moved from
150,-130 to 180,-100. Base: `modified=1 bak=1`.

**Cause:**

- `unselect_all()` (`select.c`) sets `xctx->ui_state = 0`. It clears STARTMOVE without
  `move_objects(END|ABORT)`, so neither the accept arm nor the refuse arm ever runs.
- The undo and redo paths reach it through `pop_undo_keep_selection()`, which calls
  `unselect_all(0)`. `netlist` and the area-select branch of the motion handler call it too.
- The live steps already committed geometry under the hold, and nobody declares it. The hold
  itself is released correctly: no leak was found (section 3).

**Consequence (measured, `orphan.tcl`):**

- `hierarchy_close quit` returns 1 with no prompt on the patch, against one prompt on base.
- A later real edit declares the sheet, and `xschem save` then writes the orphaned geometry
  to the cell.
- Undo cannot reach the pre-drag position, on base or patch.

So the damage is limited to the gesture's own geometry, but screen and disk disagree while
the sheet reads clean.

**Fix A (built in a scratch copy, measured):**

```diff
--- a/src/select.c
+++ b/src/select.c
@@ unselect_all()
   if((xctx->ui_state & SELECTION) || xctx->lastsel) {
     dbg(1, "unselect_all(%d): start\n", dr);
+    /* issue 1716: a live fluid stretch this reset orphans (no END/ABORT will follow) has
+     * committed geometry the modify hold kept undeclared; declare it here. */
+    if((xctx->ui_state & STARTMOVE) && xctx->fluid_reroute_active && xctx->fluid_reroute_dirty)
+      set_modify(1);
     xctx->ui_state = 0;
--- a/src/move.c
+++ b/src/move.c
@@ fluid_reroute_restore()
   int saved_preview_n = xctx->preview_sel_n;
+  xctx->modify_hold++;   /* the unselect_all() inside mem_restore_slot() is not an orphaning */
   mem_restore_slot(&xctx->fluid_reroute_snap, 0);
+  xctx->modify_hold--;
   xctx->ui_state = saved_ui;
```

The second hunk is required, not tidy. Without it, the first hunk fires inside every live
step, because `fluid_reroute_restore()` → `mem_restore_slot()` calls `unselect_all()` with
STARTMOVE set and the previous step's `fluid_reroute_dirty`. That first version was built and
measured. It made `xschem save` mid-drag write the half-dragged geometry to disk again, which
is the 1716 class. With both hunks, `stepmod.tcl` reads `0/0` (modified/backup) at every live
step and after an abort, the same as the patch.

**Measured on fix A (both hunks):**

| check | patch | fix A |
|---|---|---|
| `unsel.tcl` unselect_all mid-drag | modified 0, bak 0 | **1, 1** |
| `cmds.tcl` (36 xschem commands mid-drag): UNDECLARED | unselect_all, undo, redo, netlist, make_symbol | make_symbol only (same as base) |
| `keys.tcl` `u` / `U` / `n` mid-drag | UNDECLARED | **declared** |
| `disp.tcl` d08/d09 (m-key, Button-1-state motion) | modified 0, bak 0, moved | **1, 1** |
| `keys.tcl` Ctrl-S, Delete, `j` | unchanged | unchanged |
| `savemid.tcl` `xschem save` mid-drag | not saved, drag continues | same |
| `orphan.tcl` quit after the orphan | no prompt | **prompts** |
| `stepmod.tcl` per-step flag/backup | 0/0 ×4 | 0/0 ×4 |
| `hold.tcl` (34 rows) and `bk.tcl` (K1–K15) | — | output identical to patch |
| new suite, both arms | 45 / 52 PASS | 45 / 52 PASS |
| 244 headless suites | — | verdicts and counts identical to patch |
| `-std=c89 -pedantic` on select.c and move.c | 5 / 77 warnings | 5 / 77 |
| ABAB timing (see section 9) | — | within noise |

Not done for fix A:
- The display-arm suite list.
- A row in the suite.

**Suggested row:** start a stretch, run 3 steps, then `xschem unselect_all`. Assert
`modified 1`, `~` present, and `hierarchy_modified 1`. Repeat with `xschem undo` in place of
`unselect_all`. Both versions are red on the patch and green on fix A (measured with
`unsel.tcl` and `cmds.tcl`).

A side effect of fix A, conservative and the same as base: `unselect_all` followed by
`move_objects abort` leaves the sheet flagged while the geometry is back where it started.

### F2 (LOW, test quality): row Z of the new suite cannot fail

Row Z claims *"no crash-recovery prompt was raised by any load in this suite"*. It counts
calls to a stubbed `::xschem_recover_backup`. The product calls that proc in exactly one
place: the `xschem load` branch of `scheduler.c`, under `if(!force && has_x)`, on an
interactive `-gui` load. The suite never issues one.

Measured with a binary built from the patch with that `tcl_call(...)` removed, so crash
recovery is never offered at all: the new suite reads **ALL PASS (45 checks)** headless and
**ALL PASS (52 checks)** on the display arm.

Fix: drop the row, or give it teeth. For example, on the display arm, `xschem load -gui` a
cell that still has a kept foreign `~` (the 1715 K8/K9 state), and assert `recovers == 1`.
That is also the one place where 1715's "the crash recovery is kept" pays off for the user.

### F3 (LOW, comment): `level_backup_is_mine()` overstates one case

The comment ends: *"...that file then holds this session's own edits up to that write --
which go_back adopted before this change too."* That is true only if `autosave_backup` is on
again by the time of `go_back`. `load_backup_as()` returns early with autosave off; the
patch's own RT5 comment in `test_ase_core.tcl` says so. Suggested wording: "...which go_back
adopts, as before, whenever autosave is on at the time of the ascent."

### F4 (INFO, improvement): `xschem save` / Ctrl-S mid-drag no longer writes half-dragged geometry

Base, `savemid.tcl`: the per-step `set_modify(1)` made `save()` write the mid-drag geometry
to the cell file. The save's `unselect_all` then orphaned the drag.

Patch (and fix A): `save()` sees `modified 0` and does nothing, and the drag continues. An
ABORT then leaves disk, memory and flag consistent. The keys sweep's Ctrl-S row shows the
same on real events.

### F5 (INFO): an edit made by Tcl running inside the hold is swallowed

A deliberate probe in `hold.tcl` (`mid_edit_in_trace`) does a real `xschem wire` from a
variable trace that fires during a live step. The instrumented binary logs it as
`TCL-IN-HOLD xschem wire`. Its `set_modify(1)` is held, and the gesture's verdict then
decides. The final state matched base in the measured case (`modified=1`, same wire count).
This needs Tcl to run inside `move_objects`. No shipped path doing that was found apart from
read-only `xschem get` calls from the redraw (3600 of them in one display-arm suite,
harmless).

### F6 (INFO, unchanged from base): other mid-drag commands

- `delete`, `cut` and `align` issued mid-drag, followed by an abort, leave the sheet flagged
  with the geometry restored. This is the conservative direction, the same on both binaries.
- `make_symbol` mid-drag leaves changed geometry unflagged on both binaries. Pre-existing.

Five keys hung a scripted mid-drag run on **both** binaries until its 40 s timeout: `t`,
`Insert`, `e`, Ctrl-F and `b`. Each probably opens a modal dialog; this was not investigated,
and those keys were not judged. Two of these runs left a child `xschem -b -s` process
(DISPLAY `:270`/`:271`, scratch HOME) after the timeout killed its parent. Both were killed.

## 2. What held up (claims re-measured)

| crew claim | re-measured how | result |
|---|---|---|
| Escape / abort of a clean drag leaves no flag and no `~` | `hold.tcl`, `stepmod.tcl`, real-event `disp.tcl` d02/d05/d06/d07/d13/d16 (base: all `modified=1 bak=1`) | holds: patch `modified=0 bak=0`, p2 back at 150,-130 in each |
| Loading another sheet mid-drag leaves no `~` behind | `disp.tcl` d14 | holds: base leaves `bak=1`, patch `bak=0` |
| Refusal leaves the flag and `~` as they were | `hold.tcl` refusal cases; identity: 9 refused no-op ENDs on 10 pages | holds (patch `mod=0`, base `mod=1`) |
| A completed drag declares exactly as before | identity: every accepted END has the same `mod` and the same backup md5 on both binaries | holds |
| The hold is released on every path | instrumented binary over 34 scripted + 17 Tk scenarios; detector proven by a build that leaks on purpose (2923 `LEAK` lines) | 0 LEAK, 0 CTXSWITCH, 0 NESTED, 0 swallowed-outside-commit |
| No early `return`/`goto` between take and release | read `move_objects()` between the take and both releases | none |
| `go_back` adopts only this session's own `~` | `bk.tcl` K1–K15 both binaries; suite band G | holds; base differs exactly at K5, K8, K9, K14 and K15 |
| A crash-recovery `~` is not deleted by "No" | K8 (`crash_kept=1` patch, 0 base), K9, K14 | holds |
| `sch_backup_mine` travels to a new window | K11, G10, two-tab D2 d18/d19 | holds; base hangs at d18 (a modal) |
| Constructors initialise the record | one constructor, `my_calloc` in `xinit.c` | zeroed |
| CADMAXHIER bound | both descend paths refuse `currsch + 1 >= CADMAXHIER` before writing `[currsch]` | in bounds (by reading; no 40-deep hierarchy built) |
| New suite red on base for the right reasons | patch suite, base binary | 16 FAILED (29 passed) headless: A1–A3, R1–R4 (1716), G1–G9 (1715); display adds E1, E2, E3 (19 FAILED) |
| RT5 change is red-first | patched `test_ase_core`, base binary | `1 FAILED (673 passed)`, row RT5 only |
| Epilogue matches `banner_complete` | sourced `tests/banner_rule.tcl` on real captures | `banner_complete=1`, `OVERALL: ok` before `RESULT:` |

The d01/d03 position difference noted mid-session (240 vs 230) did not reproduce. d01 was run
3 times on each binary, with the displays swapped and then with fresh identical homes. Each
time the final position and the saved-file md5 were identical (`ce32adf3…`, then `60c69f88…`).
The initial zoom does differ by a constant 4e-4 between the two binaries, before any gesture.
That was not chased, because the outcome is identical.

## 3. The hold hunt

Every gesture was followed by a real edit, and each run asserted `modified`,
`hierarchy_modified`, a `~` holding the edit, and that quit prompts.

- **Scripted (`hold.tcl`):** 30 gestures and 4 refusals.
  - Seam stretch, rotate and flip.
  - Kiss END, merge and place.
  - Mid-gesture undo, redo, delete, wire, load, new tab and clear.
  - A Tcl error raised from a trace, and an edit made from a trace.
  - Context switch, and nested starts.

  Results: 34/34 on base, patch, fix A and the instrumented build.
- **Tk events on Xvfb + openbox (`disp.tcl` d01–d17, D2 d18/d19):**
  - Release, Escape and right-click.
  - `R`, Alt-R, `F` and `m` mid-drag; `m`-key moves; `c` copy.
  - Ctrl- and Shift-drags.
  - Load, new tab, `abort_operation` and focus-out mid-drag.
  - Destroying the drag's tab mid-drag, and switching tabs mid-drag with an edit in the other
    tab.
- **Mid-drag commands and keys:** 36 commands (`cmds.tcl`) and 58 keys (`keys.tcl`), plus
  five modified-button presses (`morph.tcl`). This is where F1 came from.

## 4. Identity (pages the crew did not use)

| page | insts / wires |
|---|---|
| sky130A `mips_cpu/alu` | 14 / 0 |
| sky130A `sky130_tests/cla_4bits` | 88 / 3 |
| sky130A `sky130_tests/charge_pump2` | 59 / 153 |
| ihp-sg13g2 `sg13g2_tests/dc_logic_not` | 14 / 21 |
| ihp-sg13g2 `sg13g2_tests_ase/ac_hbt_13g2` | 12 / 15 |
| gf180mcuD `test_ppolyf_s` | 8 / 3 |
| gf180mcuD `test_cap_nmos_06v0` | 10 / 7 |
| xschem_library `examples/poweramp` | 86 / 67 |
| xschem_library `examples/greycnt` | 54 / 74 |
| xschem_library `examples/LCC_instances` | 33 / 21 |

Method:
- The PDK pages were run on Xvfb with each PDK's `cadence_style_rc`; that rc needs Tk. The
  `xschem_library` pages were run `--nogui`. Each page was copied to scratch first, so
  nothing was saved in a clone.
- On each page, at snaps 10 and 20 and selections of 1, 8 and 4 instances:
  - a stepwise stretch END, then undo and redo;
  - a stepwise ABORT;
  - a one-shot move, then undo;
  - a two-drag undo/undo/redo chain;
  - a netlist after each END and after each one-shot move.

**510 saved-schematic and netlist md5s compared, 0 differ.** Netlists were compared after
mapping the clone and scratch letters in embedded paths. All 60 aborts read `mod=0` on the
patch; 57 read `mod=1` on base. The 9 ENDs whose `mod` differs are refused drags: in each,
END == undo, so the geometry did not change. The backup md5 differs only on those aborts and
refusals, where the patch keeps the previous file instead of rewriting it.

## 5. Suites, base vs patch

All runs used private `/tmp` namespaces, so suites with fixed `/tmp` dirs never collided, and
throwaway homes.
- **Headless (`AUDIT_DISPLAY=none`), 245 suites:** verdicts and check counts identical. The
  one difference is `test_home_isolation_sh`. My list's prefix match picked it up, and I
  killed it mid-run on one stream under the brief's rule. It is disclosed, not a result.
- **Display arm (`:272`/`:273`, Xvfb + openbox), 245 suites:** identical, `diff` rc 0.
  - 215 PASS, 9 FAIL, 9 NORESULT, 7 SKIP and 5 TIMEOUT, the same names and counts on both.
  - Four drag- or modify-related reds were rerun alone at a 600 s timeout and stayed
    identical: `test_cadence_drag` (2 FAILED), `test_rotate_stretch_short_0104` (1 FAIL), and
    `test_descend_symbol` and `test_paste_modify_flag_0244` (TIMEOUT at 600 s on both).
    So these four suites prove nothing about the patch on the display arm.
- **`test_wave_markers`:** PASS on both binaries on both arms, with 437 checks headless and
  984 on the display arm. No change.
- **Harness suites, both clones headless:** `test_issue_stamp` 102, `test_registered_banner_1626`
  10, `test_suite_watchdog_1403` 40, `test_scratch_home_note` 22 and
  `test_regression_concurrency_1476` 46 checks, all PASS on both.
  `tclsh tests/headless/issue_stamp.tcl` reads `ok (0 problems)`. `test_t1_display_arm` was
  not run, because it starts its own Xvfb on numbers outside my range.

## 6. T1 delta (derived, not run)

- **Registration:** `hcases` 137 → 138, `dcases` 60 → 61 and `planned_cases` 201 → 203,
  evaluated from each tree's own list text.
- **Captures:** the new suite was captured in both arm shapes:
  - `hcases`: `env -u DISPLAY … --nogui --pipe -q --script headless/…`, run from `tests/`;
  - `dcases`: `--pipe -q --logdir D --script headless/…` on `:272`.
- **Scoring:** all 16 top-level procs were lifted out of `tests/run_regression.tcl`, with
  `banner_complete` sourced from `tests/banner_rule.tcl` and the HARNESS rule applied.
  - Patch binary: each arm gives 1 block, 0 counted, 0 skips and 3 lines.
  - Base binary: each arm gives counted 1, from the HARNESS line.
- **Delta: cases +2, blocks +2, counted_failures +0, skips +0, `wc -l` +6.** This agrees with
  the crew's §7. `skips` holds because band E's headless skip is spelled `SKIP:` and
  `summarize_all` counts only lowercase `^skip:`.
- A full T1 was not run.

## 7. Health

- **Warnings:** identical warning lists on base and patch for cairo (6), no-cairo (6),
  `-std=c89 -pedantic` (67) and `-Wextra` (377).
- **valgrind (patch binary, new suite):**
  - headless: `ALL PASS (45 checks)`, `ERROR SUMMARY: 0 errors`;
  - display arm: `ALL PASS (52 checks)`, `0 errors`.

## 8. Comments vs code

- The `set_modify` and `modify_hold` comments match the code, including *"acquired and
  released inside one block of move_objects(), never across a return"*: there is no return
  or goto between the take and either release.
- The `set_modify` comment *"The gesture's own END declares the edit"* is accurate but
  silent about gestures that never reach END; that silence is F1.
- One overstatement in `level_backup_is_mine()` (F3).
- The `go_back`, `hierarchy_modified` and `sch_backup_mine` comments match the code.
- Crew limit 5 (stale comments in `ase.tcl`, `op_annot.tcl` and `test_op_annot.tcl`) stands.
  `test_op_annot` passes unchanged on both trees (486 checks headless).

## 9. Timing (ABAB, one real page)

Setup: the bandgap page on Xvfb + openbox, with drawing. Each cell is 40 live steps × 3 drags,
4 rounds, base and patch alternating, on a quiet machine (load about 1). Values are the mean
µs per step and per END, one per round.

| devices | finish | base step | patch step | base END | patch END |
|---|---|---|---|---|---|
| 1 | end | 5283–5503 | 5048–5315 | 6258–6650 | 6150–6582 |
| 1 | abort | 5390–5551 | 5047–5279 | 2455–2702 | 2466–3025 |
| 8 | end | 11133–11533 | 10301–10619 | 15428–16862 | 14581–15390 |
| 8 | abort | 11248–11439 | 10339–10853 | 3928–4255 | 3857–4445 |

- The patch is about 4% faster per step at 1 device and about 7% at 8 devices, because live
  steps no longer write the backup. END is unchanged.
- Fix A against the patch, 3 rounds: every cell overlaps (for example, 8-device step
  10258–10411 against 10360–10609).
- An earlier run taken under heavy load (load about 9) was discarded as noise.

## 10. The crew's §8 limits

- **Limits 1, 3, 4 and 6:** consistent with what was measured.
  - Limit 3: the K13 autosave-off loss is the same on both binaries.
  - Limit 6: kept foreign and crash `~` files exist and are not adopted (K8, K9, K14). F2
    notes that nothing in the suite exercises the recovery prompt they feed.
- **Limit 2** (ownership is by path, not content): consistent with K7 and K15. For two
  contexts on the same cell (K15), the patch loads disk in the context that did not edit,
  where base adopted the other context's file. That is correct.
- **Limit 7:** the stamps resolve (`ok (0 problems)`).
- **Limit 8:** this verification is also synthesised input on Xvfb.
- **Limit 9:** not re-checked.

## 11. Not covered

- No real hand drag on a real display (the user's screen was never used).
- Fix A has no suite row yet and was not run over the display-arm list.
- A 40-deep hierarchy was not built for the CADMAXHIER bound; it was checked by reading.
- `test_t1_display_arm` and `test_home_isolation` were not run (display range; the brief).
- Display-arm verdicts for `test_descend_symbol` and `test_paste_modify_flag_0244`: both
  time out on both binaries.
- Five modal-opening keys mid-drag (F6).
- No full T1 run.
- Windows and Tcl 8.4 builds.

## 11b. The instrumented binary over the suite lists

The instrumented build is the patch plus logging. It logs when a context still holds the
modify hold at every `xschem` command (`LEAK`), a held `set_modify` outside a commit block,
a context switch between the take and a release, a nested take, and any Tcl `xschem`
command run while held.

It was run over the new suite plus the 244-suite list on both arms.

- **Headless:** verdicts identical to the patch and to fix A. Log: 32 `TCL-IN-HOLD xschem
  get` and nothing else.
- **Display arm (`:274`):** log: 3688 `TCL-IN-HOLD xschem get` and nothing else. All are
  read-only queries from the redraw.
- **Display verdicts:** identical to the patch except three suites.
  - `test_hier_pdf_links_1333` and `test_wave_hilight` passed when rerun alone with the
    instrumented binary: load flakes.
  - `test_load_window_routing` is F7.
- **Positive control:** the build that leaks on purpose logged 2923 `LEAK` lines on
  `hold.tcl`.

### F7 (INFO, test pollution, not the patch): a leftover `nand2~.sch` hangs `test_load_window_routing`

- `test_undo_link_symbols` leaves `xschem_library/examples/nand2~.sch` in the clone on both
  binaries.
- `test_load_window_routing`'s `xschem load -gui nand2.sch` then raises the crash-recovery
  dialog, and the suite hangs on it until TIMEOUT. That happens on both binaries: with a
  planted `nand2~.sch`, base and patch both read TIMEOUT. Remove the file and both read
  `ALL PASS (14 checks)`.
- On the display arm, `test_cadence_drag` happens to delete the file, on both binaries. So
  whether the hang shows depends on suite order. In my runs it showed only in the patch
  clone's later streams.
- Neither suite is registered in T1, so the gate is unaffected. A suite that leaves a `~`
  beside a shipped example is the defect. It is worth a ruling-free fix: delete the `~` in
  that suite's epilogue.

## 12. State left behind

- **`~/gdv1`:** exactly `e6b38ba83` + `D-fix.patch` (`git apply --check -R` is clean). No
  verifier binaries left.
- **`~/gdb1`:** clean `e6b38ba83`.
- **Backup files:** my runs left 55 `*~.sch`/`*~.sym` files in each clone. All were dated
  after the clones were made; they were listed, then deleted. None are left. No `untitled*`
  files.
- **Displays:** Xvfb and openbox on `:270`–`:275` are stopped, matched by display number.
  `:300`–`:303` belong to someone else and were not touched. `:99`, `:0` and `$DISPLAY` were
  never used.
- **Processes:** the `test_home_isolation` kill-watcher is stopped. No process of mine is
  running.
- **Scratch:** trimmed to about 2 MB of scripts and logs in
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/dragDv/`,
  which holds `scr/*.tcl`, `rs/` and `t1/`. It is session scratch and may vanish.
- **Main tree:** nothing written except this file. No commits, pushes or stashes.
