# D3 verification (adversarial), 2026-11-15

Builds:

- **F** = `~/gdv3`: f039113c5 + `receipts/D3-incremental.patch` (md5 77baeb668be681b099f8b674b3989494, checked).
- **D** = `~/gdd3`: f039113c5, which is stage D plus the selection batch.
- **B** = `~/gdb1`: e6b38ba83.

Each build was compiled from clean. Each gave 6 warnings, and their texts are identical.

Where the runs happened:

- Headless runs: `env -u DISPLAY`, `AUDIT_DISPLAY=none`.
- Display runs: my own Xvfb `:270`–`:273`, each with openbox, and `GUI_GATE=0`.
- Every run used a throwaway HOME and a `timeout`.

The probes are in `scratchpad/dragDv/scr/` and the results in `scratchpad/dragDv/d3/`.

## Verdict

**D3 does what it says.** Every real verb I could reach that quits, closes, goes up, clears or opens in place now asks during a live fluid drag, exactly where base asked, with the same text. Yes, No and Cancel each do the right thing.

Stage D's guarantees are intact. No wrong-level geometry, no double END and no crash were found on any verb D3 touched. valgrind found 0 errors on three probes.

The door is safe at any time. The cost cannot be measured.

Nothing found blocks the patch. Two pre-existing defects are new to this batch's record (G1, G2), and both are worth an issue. Three smaller items are below them.

## Findings, ranked

### G1 (MEDIUM, pre-existing on B, D and F, real input; worth an issue). Closing a window that is not the current one loses its unsaved edits

Setup: tabbed off, a second window open, and the main window current. The second window's close script (`xschem new_schematic destroy $topwin.drw {}`) runs `destroy_window()`, which reads the **current** context's `hierarchy_modified()`:

| case | B | D | F |
|---|---|---|---|
| second window has a real (completed) edit, main is clean | no prompt, window closed, edit lost (only `bandgap~.sch` keeps it, disk unchanged) | same | same |
| second window clean, main dirty | prompts, naming the **main** window's cell; Cancel keeps the clean window | same | same |
| second window has a live drag | closed silently; `bandgap~.sch` holds the live steps | closed silently; no `~` | same as D |

A real user reaches this when the pointer gets to the second window's title bar without crossing its canvas, because the context switch happens only on the canvas's EnterNotify. D3-fix lists this as limit 3. It deserves its own number, because it loses completed edits, not only drags.

### G2 (LOW-MEDIUM, pre-existing on B, D and F, real input; worth an issue or a 1716 note). Ctrl-S during a drag on a sheet that already has an unsaved edit saves the half-dragged geometry

Probe `keysave.tcl`, display: a real press-drag, then a real Ctrl-S with Button-1 held, then Escape or release.

| sheet before the drag | B | D | F |
|---|---|---|---|
| clean | saves the half-drag (disk p2 190 -100); drag over | save is a no-op, drag continues; Escape restores, disk untouched | same as D |
| has an earlier unsaved edit | saves the half-drag (disk p2 370 10); drag over; Escape does nothing | **same as B** | **same as B** |

`save_schematic()` ends the gesture with its `unselect_all(1)` and then writes what is on screen. So D-verify's F4 ("Ctrl-S mid-drag no longer writes half-dragged geometry") holds only on a clean sheet. The scripted twin (`savemid2.tcl`, `xschem save` mid-drag after a prior edit) gives the same result on all three builds. D3 changes nothing here.

### G3 (LOW, new in D3, synthesized events only). After Cancel with the button still held, the next motion starts a rubber band

After Cancel, F ends the gesture: ui 8, shapes kept, modified, `~` holds the screen, file untouched. The next motions with Button-1 still down give ui 16 (STARTSELECT from the press point). The release then leaves `sel=0`, so the object just moved is deselected, though its shapes stay.

B kept the drag live after Cancel, and the release committed it further along. F's result is sane and arguably better. Mentioned so the driver can rule it acceptable.

### G4 (LOW, scripted; amend 1718). The orphan route still crosses levels on F

1718's table is accurate. It is missing one route, which D3 cannot close, because `unselect_all` has already cleared STARTMOVE and so `end_live_fluid_drag()` returns 0 at the verb (probe `attack5.tcl`; identical on B, D and F):

| sequence | result |
|---|---|
| child drag, `unselect_all`, `go_back`, `move_objects abort` | parent tb_bandgap shows the child's 115 inst / 58 wires, modified 0 |
| same, then `end` instead of abort (answer no) | parent modified, `tb_bandgap~.sch` = 115C/58N |
| top drag of x1, `unselect_all`, select x1, `descend`, `abort` | child shows 34 / 11 |

I also confirmed 1718's F-column rows `descend 1 0`+abort and `go_back 0`+end (still present) and the three rows marked gone. 1718's open item, dropping the snapshot on any level change, would cover all of these.

### G5 (LOW, scripted). A scripted `move_objects end` after the door, or after a verb that ended the drag, pushes a no-op undo step and marks the sheet modified

Door then `end`: the geometry is unchanged, but undo gains a step that does nothing. `go_back` then `end` (attack2 `g_up_end`): the parent is modified with its own sheet in `~`. No real-input END site is ungated.

### INFO

- **A titled descend during a drag now goes through the END gate.** A drag of x1 that would short or disconnect nets (enforcement on, the default) is refused at the descend, exactly as a release at that spot would be. The display shows the CIW "move refused" line. The parent returns clean at the disk position (`desc2.tcl`).
  - B instead kept that geometry as an unsaved edit, which bypassed the gate.
  - With `fluid_enforce_invariants 0`, F equals B (parent modified, `~` = moved geometry, quit asks). D loses the drag silently.
  - Consistent with a release. Not a defect.
- **`bandgap~.sch` stays after "OK (discard)"** at quit or destroy_all. All builds.
- **`xschem end_live_drag foo` is accepted and returns 0.** It ignores the extra argument. Harmless.
- **Five keys hang the key sweep on all builds** while a dialog waits: `t`, `Insert`, `e`, Ctrl-`f` and `b`. This is the harness, not D3. Each left an empty `/tmp/xschem_emergencysave_*` and `/tmp/xschem_web_*` behind when its timeout killed it; I removed the 33 of mine (see State left).

## (1) Prompts, answers and the post-Cancel state

`verbs.tcl`, display, real key events with Button-1 held on a live fluid stretch of `l1`. The rows were Ctrl-Q, Ctrl-W, Ctrl-N, Ctrl-O and `xschem exit` at the top, and Ctrl-E, Ctrl-Q, Ctrl-W and Ctrl-N in the child, each answered yes, no and cancel: 27 rows.

| | B | D | F |
|---|---|---|---|
| prompts | 27/27 | **0/27** (the silent loss) | 27/27, same count and text as B |
| Yes | saves the moved `l1` (disk 220 10), `~` removed | (no prompt; drag dropped) | same as B |
| No | file untouched, `~` removed | – | same as B |
| `xschem exit` OK | discards to untitled | – | same as B |
| Cancel | gesture still **live** (ui 40) | – | gesture **over** (ui 8), `l1` kept, modified 1, `~` md5 498153 (= B's `~`), file untouched |

- Ctrl-O asks to save first, then opens the file dialog.
- Tabs and windows (`tabs.tcl`, display): quitting from a tab while the main has a live drag (OK and Cancel), and quitpart in tabbed and windowed modes. F prompts as B does ("bandgap.sch: UNSAVED data: want to exit?").
  - OK closes. Cancel keeps the sheet modified with the gesture over.
  - The END in the non-current context wrote the right cell's `~` (bandgap~ only; tb_bandgap~ none).
  - The canvas matches a forced redraw (0 stale pixels).
  - D asks nothing.
- The keys sweep (58 keys pressed mid-drag, one process each, all three builds in parallel) shows no UNDECLARED row on F or D, and F equals D on every row. B has Ctrl-S UNDECLARED (its F4).

## (2) Wrong writes when ending inside a verb

None found on a path D3 touched.

- A `~` is always the level whose drag it was.
- No child shapes went into the parent through D3's call sites. D3 actually closes three of 1718's rows.
- No double END from real input.
- No crash on descend or go_back mid-drag. The rerun battery is 21 probes × 3 builds, all rc 0 with 0 FAIL lines.
- valgrind `-q` on F gave 0 bytes of log for `door.tcl` (headless, 26 rows), `verbs.tcl` (display, 27 rows) and `tabs.tcl` (display, 12 rows, results identical to the plain run).
- The `destroy_window` oddity is real and pre-existing: G1.

## (3) Stage D's guarantees on F

| guarantee | probe | F against D |
|---|---|---|
| live steps read modified 0 / `~` 0 | `stepmod` | identical |
| Escape/abort leaves the sheet as it was | `disp`, `d0809`, `keystab`, `morph`, `hold` | verdicts identical |
| no hold left set; later real edits declared | `hold` (34 rows) | 34 ok on all three |
| mid-drag save on a clean sheet writes nothing | `savemid` | identical (but see G2 for a dirty sheet) |
| 1715 backup ownership | `bk` | identical |
| other mid-drag commands | `cmds`, `orphan`, `unsel`, `reloadbak`, `attack`, `attack3`, `attack4` | identical except the rows below |

Every F≠D line is one of four things:

- **Prompts that now happen**, at clear, go_back and the quit probes (`asks=1` where D had `asks=0`).
- **Descend and go_back now ending the drag first**: `attack2`, `hold`'s `mid_descend` (whose refusal messages appear only on F) and `d5b` (Ctrl-E now prompts).
- **One `~` md5 in `d3`**: the orphaned window's `~` now holds the ended drag's geometry.
- **Positions 10 units apart in `disp` and `morph`.** These are noise. Re-running each twice in sequence on one display gives the same run-to-run spread within a single build, and the verdict lines are identical.

## (4) The `xschem end_live_drag` door

- **Headless, no drag:** returns 0 twice, and nothing changes.
- **Live fluid drag:** 1, then 0. The sheet is modified and `~` is written. One `undo` restores the pre-drag spot and `redo` re-applies it.
- **Returns 0, and abort stays clean, for:** a drag with no step yet, fluid off, and a plain move with no stretch.
- **After a level or document change mid-drag:** returns 0 after every one I tried. These were descend, descend 1 0, go_back 0/1/2, load (same file and other file, with `-noundoreset` or `-nodraw`), reload, clear force, tab create and netlist.
- **`load_symbol`:** keeps the drag live, and the door then ends it correctly.
- **Called from a variable trace** (`::constr_mv`, `fluid_last_move_violations`) inside the door or inside an END: returns 0, with no re-entry and no crash.
- **With an extra argument:** see INFO.

## (5) Issues 1717–1719

**Numbering.** Neither 1717–1719 nor the new pointer 1720 falls in a reserved band.

- I searched the issue directories and `NUMBERING.md` files across `~/dev/*` and `~/private/*`, using `/usr/bin/grep`. The three issue files exist only in `~/gdf4` (the crew's) and `~/gdv3`.
- The only other hit is the main tree's own pointer line, "The next free number is 1717". It will need to move to 1720 when the patch lands.

**Stamps.** `tclsh tests/headless/issue_stamp.tcl` in gdv3 gives "self-test PASSED (180 parser cases) … ISSUE-STAMP: ok (0 problems)". Each stamp is `v1 claim=open tree=e6b38ba83 … by=drag_perf-D3`.

**Text.**

- 1717 and 1718 match my D2-verify G2 and G3 measurements. The 1718 gap is G4 above.
- 1719's repro reproduces on gdb1 and gdv3: `xschem rect 0 0 100 100 100` gives rc 134, "double free or corruption (!prev)".
- The 0362 and 1716 edits are accurate.
- No private design or premium names appear. The only fixture is the bundled `sky130_tests_ase` tb_bandgap/bandgap, and `~/private/*` appears only in the minting procedure.

**T1.** `tests/run_regression.tcl` is not in the diff, so cases and blocks cannot move. I did not run T1.

**Suite red-first** (`test_drag_abort_backup_1716`), reproduced exactly:

| build | headless | display |
|---|---|---|
| F | ALL PASS (73) | ALL PASS (112) |
| D | 13 FAILED (60 passed) | 32 FAILED (80 passed) |
| B | – | 58 FAILED (54 passed) |

## (6) Cost

The new check is not on the motion or redraw path. Its call sites are at the start of verbs only. The door is called only from `hierarchy_close`.

| measurement (headless, 50 000 calls × 4 rounds) | F |
|---|---|
| `xschem end_live_drag`, no drag | 82.5–85.9 ns per call (the whole Tcl→C round trip) |
| `xschem get ui_state`, for scale | 123.7–128.9 ns |

Drag frames: real Motion with Button-1 held, then `update`, on bandgap; F and D interleaved four rounds on `:273`. Medians in µs:

| | F | D |
|---|---|---|
| 3 devices | 6482 / 6347 / 5732 / 6209 | 6076 / 6579 / 6260 / 6336 |
| 8 devices | 16671 / 14270 / 13528 / 14549 | 14300 / 14742 / 14434 / 14679 |

The ranges overlap; F's first 8-device round is an outlier. The per-command check (TA) measured 99.5–114.5 ns on F against 111.0–116.0 ns on D. No difference can be measured.

## A rule I broke

During this verification I ran `tclsh <<<'puts [package require Tk]'` **without `env -u DISPLAY`**. It inherited the user's real `$DISPLAY` (the HC-Consult Windows X server) and hung. I stopped it within about 120 s, and no tclsh remained afterwards. A Tk root window may have appeared on the user's screen for that time. Every later command used `env -u DISPLAY` or an explicit `:27N`.

## State left

- **Clones:** `~/gdv3` (F, the patch applied and uncommitted), `~/gdd3` (D) and `~/gdb1` (B) are built. None has untracked `*~.sch`, `untitled*` or `title.sch` (checked with `git status --short --ignored --untracked-files=all`).
- **Displays:** my Xvfb and openbox on `:270`–`:273` are stopped. Each process was matched by its DISPLAY in `/proc` before stopping.
- **Processes:** no xschem with my HOMEs remains.
- **`/tmp`:** I removed 33 empty `/tmp/xschem_emergencysave_bandgap_*` and `/tmp/xschem_web_*` dirs. My timed-out key runs left them, and I matched them by their 40-s triplet timestamps. I left the rest, including `/tmp/xschem_undo_*`, which belong to others.
- **Main tree:** I wrote nothing there except this file.
