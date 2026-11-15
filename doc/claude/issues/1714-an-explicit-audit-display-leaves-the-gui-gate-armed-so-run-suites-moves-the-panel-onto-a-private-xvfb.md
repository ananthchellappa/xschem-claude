# 1714 — an explicit `AUDIT_DISPLAY=:<n>` leaves the GUI-test gate armed, so `run_suites.sh` launches the shared panel onto a private Xvfb, where `lookshot.sh` then photographs it

**STAMP:** `v1 claim=open tree=e3c43487e stamped=2026-11-15 fix=untried open=2 by=selection_look-docs`

Found by the selection-look batch's stage A crew
(`doc/claude/selection_look_batch/receipts/A-prototype.md`, "Harness finding"). It was
re-measured while filing on a private Xvfb `:296`, with a scratch gate directory, so the
shared `~/.claude/gui_test_gate/` was not touched. Filed, not fixed.

## What happened (the receipt)

- The crew brief's counted-arm recipe is
  `AUDIT_DISPLAY=:<n> tests/headless/run_suites.sh --nogui <suite>`. Two briefs carry it
  word for word: `doc/claude/selection_look_batch/CREW_BRIEF.md` and
  `doc/claude/backlog_1112_batch/CREW_BRIEF.md`. Both add `GUI_GATE=0` to the hand-run
  recipe only, not to this one.
- The crew's counted-arm run on its private `:263` launched the shared panel
  (`gui_gate_widget.tcl`) **onto `:263`**, where nobody could see it.
  `~/.claude/gui_test_gate/events.log` records:

  ```
  2026-11-15T00:40:42-0700 [84263] panel launched pid=84346
  2026-11-15T00:40:42-0700 [84263] approval window open -- 'run_suites: 15 run(s) [nogui] (test_hover_highlight ...)' starts without asking
  ```

  `widget.pid` named 84346. It still does; the crew killed that process.
- The panel's title is `xschem GUI-test control`. `lookshot.sh`, run on the same display,
  matched the panel instead of xschem, so one batch of the crew's screenshots showed the
  panel. The crew re-shot that batch with `GUI_GATE=0`.
- The user's screen was not touched: the panel carried `DISPLAY=:263`.

## Which arm forces `GUI_GATE=0`

Read in `xvfb_arm()` (`tests/headless/xvfb_arm.sh`) and measured through its POSIX entry,
`bash xvfb_arm.sh --arm sh -c 'echo "DPY=${DISPLAY:-unset} GATE=${GUI_GATE:-unset}"'`. The
calling shell had `DISPLAY`, `GUI_GATE` and `AUDIT_DISPLAY` unset.

| `AUDIT_DISPLAY` | arm | what it exports | measured 2026-11-15 |
|---|---|---|---|
| unset / `auto` / `dev`, dev display up and not held | attach | `DISPLAY` = the dev display, **`GUI_GATE=0` forced** | not here (it needs `:99`); row `D5` of `test_devdisplay.sh` asserts `GATE=0` |
| unset / `auto` / `private`, no usable dev display | spawn through `xvfb-run` | **`GUI_GATE=0` forced** | `AUDIT_DISPLAY=private AUDIT_XVFB_BASE=297 AUDIT_WM=none` gave `DPY=:297 GATE=0`; `_gate_enabled` returned 1 (off) |
| `none` | no display | `DISPLAY` unset, `GUI_GATE` untouched; the gate is off anyway | `DPY=unset GATE=unset` |
| **`:<n>`, anything else** | **explicit** | `DISPLAY=:<n>`, **`GUI_GATE` left as the caller set it**; the arm prints `display arm: :<n> (explicit; the gate is left as you set it)` | `AUDIT_DISPLAY=:296` gave `DPY=:296 GATE=unset`; **`_gate_enabled` returned 0 (armed)**. With `GUI_GATE=0` it returned 1 |
| (no `xvfb-run` on `PATH`) | fallback | inherited or unset `DISPLAY`, `GUI_GATE` untouched | not measured |

So CLAUDE.md's *"`GUI_GATE=0` is forced on the Xvfb arm"* and `gui_test_gate.md`'s v7
section are true of the arm's own two paths, attach and spawn. A private Xvfb that the caller
started and named with `AUDIT_DISPLAY` goes through the explicit arm. That arm cannot tell it
from `:0`, so the gate stays armed.

## The gate side

`_gate_enabled` in `tests/headless/gui_gate.sh` turns the gate off in four cases:

- `GUI_GATE=0`;
- an empty `DISPLAY`;
- `DISPLAY` naming the dev display (`_gate_dev_display`, `dev_display.md` R601);
- no `wish` on `PATH`.

On any other display the gate is armed. Nothing excludes a private Xvfb. That is by design:
R603 reads *"the gate stays fully armed on any other display"*, and row `D9` of
`test_devdisplay.sh` asserts the gate armed on `:0`.

`run_suites.sh` calls `gate_start` in every mode, `--nogui` included, although a `--nogui`
xschem maps no window. With the gate armed, `gate_start` then does one of two things:

- **An approval window is open.** The shared directory's `allow_until` reads `forever`.
  `gate_start` calls `_gate_ensure_widget`, which launches a panel on the current `DISPLAY`
  if none is alive. This is the receipt's path.
- **No approval window is open.** `gate_start` calls `_gate_attention`, which kills a live
  panel and relaunches it on the current `DISPLAY`. The run then waits for Proceed on a
  panel nobody can see. This is the hazard R602 and `xvfb_arm.sh`'s "THE HAZARD" comment
  describe. It was read in the code and not exercised here.

Once an invisible panel is alive, `_gate_widget_alive` is true for every later run from every
session. So none of them puts a panel back where the user can see it, and Pause and Stop
stay out of reach until that process dies.

## Re-measured while filing (2026-11-15, private `:296`)

Setup:

- Xvfb `:296` with openbox (`_NET_SUPPORTING_WM_CHECK` set).
- `DISPLAY` and `WAYLAND_DISPLAY` unset in the calling shell.
- `GUI_GATE_DIR` pointed at a scratch directory whose `allow_until` holds `forever`,
  mirroring the shared directory.
- A do-nothing suite file containing `puts "OVERALL: ok (0 checks)"; exit 0`.

Results:

1. `AUDIT_DISPLAY=:296 GUI_GATE_DIR=<scratch> run_suites.sh --nogui <trivial suite>`:
   - rc 0, `PASS`.
   - The scratch `events.log` got the same two lines as the receipt's:
     `panel launched pid=2311173` and
     `approval window open -- 'run_suites: 1 run(s) [nogui] (trivial_suite.tcl ...)'`.
   - The `wish`'s environment held `DISPLAY=:296` and the real `HOME`. The real `HOME` is
     by design: `_gate_panel_env` restores the pre-arm environment for a shared panel.
   - `xwininfo -root -tree` on `:296` listed `"xschem GUI-test control"` at 516x432. It
     was still there after the run ended.
2. `LOOK_DISPLAY=:296 lookshot.sh out.png <pose ending in vwait forever>`, with that panel
   up:
   - rc 0, and the PNG is 516x432: **a photograph of the panel**. Its "Running suites" list
     shows the posed xschem as `UNGATED`.
   - With the panel killed, the same command gave a 1110x791 PNG of xschem's main window.
3. Step 1 again with `GUI_GATE=0`: rc 0, `PASS`. `events.log` was empty, there was no
   `widget.pid`, and no panel window appeared on `:296`.

Afterwards the panel, Xvfb and openbox were each stopped by pid, after checking their command
lines. The shared control directory's `events.log` and `widget.pid` kept their earlier
mtimes.

## `lookshot.sh` is the victim, not a launcher

`lookshot.sh` sources neither `xvfb_arm.sh` nor `gui_gate.sh`. It never reads
`AUDIT_DISPLAY`: its display is `LOOK_DISPLAY`, default `:99`. It starts no panel. It was hit
because it shared `:263` with a run that did start one.

Its window search is `winshot.sh -name xschem`, which is `find_win` in
`tests/headless/winshot.c`: a depth-first walk that takes the first viewable window whose
`WM_NAME` or `_NET_WM_NAME` contains the string. The panel's title contains `xschem`. The
capture succeeds, so `lookshot.sh` exits 0 and reports nothing wrong.

## Proposed fix (NOT built)

1. **Force `GUI_GATE=0` in the explicit arm when `AUDIT_DISPLAY` names a local Xvfb.**
   - In `xvfb_arm()`'s explicit arm, recognise a private Xvfb by process identity: a live
     process whose `comm` is `Xvfb` and whose `argv[1]` is `:<n>`. `gui_test_gate.md`
     already states that rule for its reaper.
   - Then force `GUI_GATE=0` and say so in the arm's notice.
   - `:0` (Xwayland) and `$DISPLAY` (the Windows X server over TCP) are not local Xvfb
     processes, so the gate stays armed on them. That keeps R603 and row `D9`.
   - This covers `run_suites.sh`, `full_audit.sh` and `gated_xschem.sh`, which all go
     through the arm.
   - The fence would be rows beside `D5`/`D7` in `test_devdisplay.sh`: an explicit private
     Xvfb must give `GATE=0`, and an explicit `:0` must leave the gate as set.
   - A wider alternative puts the same exclusion in `_gate_enabled`, beside R601's
     dev-display test. That would also cover a script that sources `gui_gate.sh` without
     the arm. It must first be measured against the `test_gui_gate_*.sh` self-tests, which
     drive the gate on purpose.
2. **`lookshot.sh` should photograph the xschem it launched, not the first window titled
   `xschem`.** It knows that process's pid. Matching on `_NET_WM_PID` is one way: libtk8.6
   here contains that atom name, but nobody has checked that every xschem toplevel sets the
   property. At least, the match should never accept the panel's title.

Two smaller points to decide with these:

- `run_suites.sh --nogui` could skip `gate_start`, since it has no window to pause. Nobody
  has measured whether any `--nogui` suite maps a window.
- `_gate_log "panel launched"` could record the `DISPLAY`. As it stands, `events.log` cannot
  say which display any earlier launch went to.

Until a fix lands, use the workaround the batch's later stages used: set `GUI_GATE=0` with
every explicit `AUDIT_DISPLAY=:<n>`. The two crew briefs named above could say so.
