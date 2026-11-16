# D3-fix — the save prompt during a live drag (G1), and issues 1717, 1718, 1719

Crew D3. Work done in `~/gdf4` (`e6b38ba83` + `receipts/D-combined.patch`, md5
`6c0d21198ed4827c294d7cba96b1061a`, scratch-committed as `1ed36483f`). Deliverable:
`receipts/D3-incremental.patch`, md5 **`77baeb668be681b099f8b674b3989494`**. It passes
`git apply --check` on `e6b38ba83` + D-combined, and also on the committed stage D (`c2b467535`,
whose `src/` and `tests/` are identical to `1ed36483f`).

Builds compared throughout: **B** = base `e6b38ba83` (`~/gdb1`), **N** = stage D (`~/gdv2`),
**F** = this fix (`~/gdf4`).

## 1. What was wrong (G1)

Stage D stops a live fluid step from declaring the sheet (`xctx->modify_hold`), so a sheet with a
live drag reads clean. On B every live step had declared it, so any verb that leaves or discards the
document asked about the moved shapes. On N those verbs went ahead without asking and the shapes
were lost.

A key sweep measured it on all three builds: 74 keys at their modifier states, each pressed
mid-drag at the top and in the child, with Button-1 held and during a keyboard `m` move. That is
984 jobs on N and F; B has 992, because the 8 Ctrl-L jobs were dropped (see §11).

- **B vs N:** 23 jobs where B asked and N did not: Ctrl-Q, Ctrl-W, Ctrl-N, Ctrl-Shift-N, Ctrl-O,
  Ctrl-E in the child, and BackSpace in the child in `m` mode.
- **B vs F:** zero prompt differences over all 984 shared jobs. The only other differences are the
  `modified` flag and the `~` (853 jobs both, 12 the `~` alone), which is stage D's intended
  per-step change. Prompt and message-box counts, file dialogs, level, file, end state and wire counts are identical.

## 2. Changes, by symbol

- **`end_live_fluid_drag()`** (new, `src/callback.c`; extern in `src/xschem.h`).
  - It acts only when `STARTMOVE` is set and `fluid_reroute_dirty` is set. It then ends the
    gesture through the release's own funnel, `end_move_copy_logged(0)`: the same END, the same
    cadence deselect restore and the same action-log move line. A B3-refused END therefore still
    declares nothing.
  - It saves and restores `actionlog_cmd_logged`, so the move line does not make
    `menu_action_logged` and the menu `invoke` wrapper drop the verb's own line.
  - It zeroes `drag_elements` and `constr_mv` as the release path does. It returns 1 if it ended
    a gesture.
  - Stage D's "armed" test (`fluid_reroute_active`) was dropped from the gate. The dirty flag is
    set only in the live-step arm of an armed gesture, and `fluid_reroute_discard()` clears both
    together, so no copy broken on purpose could redden that term.
- **Call sites.** Each is at the START of the verb, before anything is torn down:
  - `go_back()` when confirming;
  - `clear_schematic()` when asking;
  - `ask_new_file()` when opening in place;
  - `descend_schematic()` with a title (`set_title & 1`), after its refusals;
  - `descend_symbol()`, twice: before the embedded-symbol save prompt, and after the
    missing-symbol refusal;
  - the `exit` branch of `xschem_cmds_e()` without force;
  - `destroy_window()` and `destroy_tab()` of the current context;
  - `destroy_all_windows()` and `destroy_all_tabs()` without force, for each other window.
- **`xschem end_live_drag`** (new subcommand, `xschem_cmds_e()`). It is the door for Tcl, called
  first in `hierarchy_close` (`src/xschem.tcl`), which handles quit and close.
- **Suite** `tests/headless/test_drag_abort_backup_1716.tcl`:
  - New bands L, V and K, and row R7.
  - O11 changed: go_back answered No now ASKS, because the drag is ended first.
  - The header's BANDS list was updated to match.

## 3. Verbs, and why each is or is not hooked

| verb (real input) | path | hooked by |
|---|---|---|
| Ctrl-Q, File > Quit | `quit_xschem` → `hierarchy_close quit` | `xschem end_live_drag` (K1–K3, K10) |
| Ctrl-W | `close_schematic_window` → `hierarchy_close close` | same (K4–K6) |
| File > Close | `xschem exit` | exit branch (K11) |
| Ctrl-E, BackSpace in `m`, Edit > Pop | `go_back(1)` | `go_back` (K7–K9, V1, V2, K18) |
| Ctrl-N, Ctrl-Shift-N, File > Clear | `clear_schematic(1, …)` | `clear_schematic` (K12, V3, V4) |
| Ctrl-O, File > Open (in place) | `ask_new_file()` | `ask_new_file` (K13) |
| `e`, Edit > Push schematic | `descend_schematic(…, 1)` | descend (V5) |
| `i`, Edit > Push symbol | `descend_symbol()` | both sites (V6; V7 embedded) |
| window close button, tabbed on | `xschem exit closewindow` | exit branch and `destroy_window` (K15) |
| window close button, tabbed off | `xschem new_schematic destroy <win>` | `destroy_window` (K15b) |
| a tab's destroy | `destroy_tab()` | `destroy_tab` (K16) |
| Quit with another tab's / window's drag left live | `destroy_all_tabs()` / `destroy_all_windows()` | both (K14, K17) |

**Not hooked, deliberately:**

- **Reload.** It always asks first.
- **Verbs that open elsewhere and leave the current buffer alone:** a routed `load -gui`,
  `load_new_window`, Alt-E, Alt-I, Ctrl-T. The original tab's drag stays live and is asked about
  when that tab is closed or quit (K14–K17).
- **The scripted no-title forms** (`descend 1 0`, `go_back 0|2`). These are kept as stage D had
  them, because they load without an undo reset, so a parent declared there would hand the child
  its modified flag (row O12). Issue 1718 records what they still do.

## 4. Red first

The suite was run on each build with its own binary and Tcl. Headless is
`env -u DISPLAY … --nogui --pipe -q`. The display arm is `--pipe -q --logdir <dir>` on a private
Xvfb + openbox, which is T1's `dcases` shape.

| build | headless | display |
|---|---|---|
| F | **ALL PASS (73)** | **ALL PASS (112)** |
| N | 13 FAILED (60 passed) | 32 FAILED (80 passed) |
| B | 30 FAILED (43 passed) | 58 FAILED (54 passed) |

**Red on N, green on F:**

- **Headless:** O11, L1–L4, V1–V7, R7.
- **Display:** the same rows plus K1–K18 and K15b; the K*n rows pass on N.
- **Structural reds:** L1–L4 and R7 are red on N and B only because the door command does not
  exist there (an `ERR` sentinel).
- **What N actually does:**
  - **K rows:** it neither asks nor keeps the shapes.
  - **V5 and V6:** go_back brings x1 back at its disk position, clean, with no `~`.
  - **V7:** it descends into the embedded symbol without asking.

**B against F.** B asks on every path F asks on, with the same answers. Every row B fails falls into
one of these groups:

- **Stage D's own rows:** A1–A3, O0, O6, O8, O9, O12, O13, R1–R4, the G rows, E1–E3, E4n, and
  every K*n. B declares each live step; D does not.
- **The door rows:** L1–L4 and R7.
- **The gesture-after-Cancel leg:** V1, V3, V7, K1, K4, K7, K10–K17. B keeps the gesture live after
  Cancel (`STARTMOVE` 32), and its release ends it later.
- **K2 and K5 (No):** B's continued live steps rewrite the `~`.
- **K18:** B logs the move only at the later release.

## 5. Copies broken on purpose

Each copy was one edit and a rebuild, then run on the display arm with `--logdir`; the binary uses
`XSCHEM_SHAREDIR=~/gdf4/src`. After every restore, every `.o` was byte-identical to the reference
except `scheduler.o`, which embeds `__DATE__ " : " __TIME__` (`Nov 15 2026 : 23:…`). The Tcl copy
was restored with an identical md5.

| copy | edit | rows red |
|---|---|---|
| C1 | drop the `actionlog_cmd_logged` restore | K18 |
| C2 | drop the `STARTMOVE` gate | L4 |
| C3 | drop the dirty gate | L3 |
| C4 | drop `go_back`'s call | O11, V1, V2, K7, K8, K9, K18 |
| C5 | drop `clear_schematic`'s call | V3, V4, K12 |
| C6 | drop `ask_new_file`'s call | K13 |
| C7 | drop `descend_schematic`'s call | V5 |
| C8 | drop `descend_symbol`'s embedded call | V7 |
| C9 | drop `descend_symbol`'s other call | V6 |
| C10 | drop the exit branch's call | K11 |
| C11 | drop `destroy_window`'s call | K15b |
| C12 | drop `destroy_tab`'s call | K16 |
| C13 | drop `destroy_all_windows`'s call | K17 |
| C14 | drop `destroy_all_tabs`'s call | K14 |
| T1 | drop `xschem end_live_drag` from `hierarchy_close` | K1–K6 |

Three things in this table were learned the hard way:

- **The first restore was done with `cp -p`, which was wrong.** The old mtime meant `make` did not
  rebuild the restored file, so later copies carried earlier breaks. C1–C10 then reddened V5, V6,
  K11 and K14, which none of them should have. The copies were rebuilt with a plain copy plus
  `touch`, and each `.o` was checked against the reference after every restore.
- **Five of the fifteen copies, launched in parallel, died with SIGSEGV** after
  `create_tmpdir(): failed to create /tmp/xschem_undo_…`. That is issue 1706 (same-second
  launches), not this patch. Rerun 2.5 s apart, none crashed.
- **K15 alone did not catch C11.** With the tabbed interface on, the close button runs
  `xschem exit closewindow`, which the exit branch and `destroy_window` both cover, so neither
  copy alone reddened K15. Row K15b drives the tabbed-off close script and catches C11.

## 6. Cancel, measured

On F, Cancel at each prompt leaves the following state:

- **The gesture is over:** `STARTMOVE` is 0.
- **The shapes stay where the screen had them.**
- **The sheet is modified,** and its `~` holds the screen.
- **The cell file is untouched:** its md5 is unchanged and p2 is at the disk position.
- **A release afterwards changes nothing:** no `STARTMOVE` or `STARTSELECT`, still modified, p2
  kept.

The rows that measure this:

- V1 (go_back): `{1 1 0 1 1 1}`
- V3 (clear): `{1 0 0 1 1 1 bandgap.sch}`
- V7 (embedded descend_symbol): `{1 0 0 {470 -460} 1 1}`
- K1, K4 and K7, with the release leg `{0 1 1}`

On a refused drag (R7, B3), the door reverts it exactly as a release would and declares nothing.

## 7. T1 delta (derived, not run)

The suite's real output was captured in T1's arm shapes from `~/gdf4/tests` under
`timeout --kill-after=20 900` and a throwaway HOME. It was scored with stage D's `derive.tcl`: all
16 procs lifted from `tests/run_regression.tcl`, `tests/banner_rule.tcl` sourced.

- **Registration is unchanged:** `tests/run_regression.tcl` is not in this patch.
- **Captures:**
  - `hcases`: exit 0, `OVERALL: ok (73 checks)`.
  - `dcases`: exit 0, `OVERALL: ok (112 checks)`.
  - Zero lowercase `^skip:` lines on either arm.
- **Against `e6b38ba83`:** cases +2, blocks +2, counted_failures +0, skips +0, `wc -l` +6 (as for
  stage D).
- **Against stage D:** no trailer term moves. Only the published counts move: 60 → 73 and
  71 → 112.
- **Under `run_suites.sh`'s `--nolog`,** the display arm reads 111, because K18 prints `SKIP:`
  without an action log.

## 8. Health

- **Warnings.** Every OBJ object was compiled with the build's flags, three ways, for F and N:
  - cairo 6 / 6;
  - no-cairo 6 / 6;
  - `-std=c89 -pedantic` 67 / 67.

  The texts (line numbers stripped) are identical in each pair. The changed files also compile
  without error no-cairo and under c89.
- **valgrind** (`env … valgrind -q`, `env` first, F binary):
  - headless ALL PASS (73);
  - display (`--logdir`, so K18 ran) ALL PASS (112);
  - both logs empty.
- **D2 §9's 39 suites, both arms, F against N.** F ran in `~/gdf4`. N ran in a throwaway clone at
  `1ed36483f` with N's binary. Every run was preceded by a cleanup of `*~.sch` and `untitled*`.
  - **76 of 78 verdicts are identical.** The two that differ are this suite's: both pass; F reads
    73 / 111 and N reads 60 / 71.
  - **The non-passes are identical on both builds, failing row names included:**
    - `test_cadence_drag` display: 2 FAILED;
    - `test_select_at` display: 5 FAILED;
    - `test_load_window_routing` headless: 4 FAILED, the same rows, the messages differing only
      by clone path;
    - `test_paste_modify_flag_0244` display: TIMEOUT;
    - 3 headless `NORESULT`, from display-only suites.
  - **The four `wireedit/` suites:** `run_suites.sh` refuses a subdirectory name ("FATAL: no such
    test file"), so they were run directly. All PASS on both arms, on both builds.
- **Cost:** one call at the start of each listed verb, returning at its first test when no drag is
  live. Nothing is added per motion or per redraw.

## 9. Issues filed (in the patch)

**How the numbers were minted.** The procedure was CLAUDE.md's:

1. Candidate **1717**, taken from this clone's `NUMBERING.md` pointer.
2. 1717–1719 checked against the reserved-band table: in no band.
3. All three `NUMBERING.md` files under `~/dev/*` and `~/private/*` (`xschem-claude`,
   `xschem-op-wcard`, the private clone) and their issue directories checked with `/usr/bin/grep`.
   No file exists for 1717–1719. The only hit is this clone's own pointer line, "next free number
   is 1717"; there are none for 1718 or 1719.
4. The `~/g*` gate clones were checked too: they carry the same pointer line.

The numbers are recorded in `NUMBERING.md`, with the pointer moved to **1720**. Each new issue opens
with `**STAMP:** v1 claim=open tree=e6b38ba83 stamped=2026-11-15 fix=untried open=1 …`.
`tclsh tests/headless/issue_stamp.tcl` prints `ISSUE-STAMP: ok (0 problems)` in a full clone.

- **1717 (G2): crash recovery is offered only on an in-place open.**
  - It is filed as a new issue, not a 0362 addendum. 0362 is the `~`'s missing identity; this is
    the missing offer, which an identity would not supply. 0362's `Related:` line now points to
    1717.
  - Re-measured on B and F, which agree. With a planted foreign `bandgap~.sch`, only an in-place
    `load -gui` offers recovery. A routed `load -gui`, `load_new_window` and descend never offer
    it, and the first edit overwrites the foreign `~` with this session's sheet.
- **1718 (G3): the fluid snapshot survives a level change.**
  - Re-measured on B, N and F. F removes three of the seven sequences: titled descend + abort,
    go_back + abort, and go_back + end.
  - It remains for `descend 1 0` + abort, `go_back 0|2` + end and `go_back 2` + abort. Scripted
    only.
- **1719 (F-C3): `xschem rect|line|wire` with an unbounded position.**
  - Confirmed on B, headless. `xschem rect 0 0 100 100 100` exits rc 134 ("double free or
    corruption"). Under valgrind (env first), the first report is an `Invalid write of size 8` in
    `storeobject` from `xschem_cmds_r`.
  - A 12-call table (rect, line, wire × 1, 100, 100000, -5) is in the issue. A position inside the
    spare capacity loses the object silently, with no report from valgrind.
  - The verb has no layer argument, so the crew's `xschem rect 4 0 0 100 100` passed 100 as the
    position.
  - **The missing check:** the position must be `-1` or `0 <= pos <= count`. Nothing checks it:
    not the three verbs' `if(argc > 6) pos=atoi(argv[6]);`, not `storeobject()`, not
    `wire_store()`. Not fixed.
- **1716:** a short "Follow-up: the save prompt during a live drag (G1)" section was added.

## 10. Not covered, and limits

1. **The scripted no-title forms are left as stage D had them** (issue 1718).
2. **K18 runs only with an action log.** It prints `SKIP:` under `--nolog`, which is
   `run_suites.sh`'s default. T1's display arm passes `--logdir`, so the gate runs it.
3. **A non-current window closed directly** (`xschem new_schematic destroy <other>`) while its own
   drag is live is not ended. That would need a switch. By reading only: `destroy_window()`'s
   prompt reads `hierarchy_modified()` of the *current* context even when another window is being
   closed. This predates D3; it was not measured and not filed.
4. **An open into another window or tab** (Ctrl-T, Alt-I, a routed open) leaves the original
   tab's drag live and undeclared until that tab is closed or quit. On B those live steps had
   written the original's `~` (the 12 `~`-only sweep differences).
5. **Keys the sweep could not score:** plain `t` and Shift-`B`, `H` and `Q` gave the probe no
   result (16 jobs in all, the same 16 on each build). D2 had recorded `e` timing out; in this sweep every
   `e` job completed.

## 11. State left behind

- **`~/gdf4`:** at `1ed36483f`, with the D3 diff uncommitted; the three new issue files are marked
  intent-to-add. The in-tree binary is built from it. `fluid-editing` was fetched from the main
  tree, read-only, for the `c2b467535` apply check.
- **Removed:** the throwaway D-combined clone used for §8, the 15 broken binaries, and the empty
  emergency-save directories my five 1706 crashes left in `/tmp`.
- **Displays :310–:317** (Xvfb + openbox) were stopped by their recorded pids, after checking each
  pid's cmdline and DISPLAY.
- **`~/gdb1` and `~/gdv2`** carry no stray `*~.sch`, `untitled*` or scratch.
- **The Ctrl-L sweep jobs** (`create_sch_from_sym`) had written `xschem_library/devices/title.sch`
  into three clones. They were deleted, and the Ctrl-L jobs were dropped from the N and F sweeps.
- **The scratch directory** was trimmed to about 2.5 MB.
- **The main tree:** only this receipt and `D3-incremental.patch` were written.
