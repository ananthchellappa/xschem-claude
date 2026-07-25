# GUI-test control gate — warn / Snooze / Pause the headless GUI test suite

Status: SHIPPED v1 (2026-07-22)
Files: tests/headless/gui_gate_widget.tcl, tests/headless/gui_gate.sh,
wired into tests/headless/full_audit.sh.

## Problem

The headless GUI test suite (`full_audit.sh`, run directly and by the
ASE-L workflow crews) opens many short-lived xschem windows on the user's
WSLg display and makes the PC unusable for other work — with no warning and
no way to pause. A previous gate existed as a Claude Code `settings.local.json`
PreToolUse hook; it silently died when that file was rewritten (nothing warned
because the hook was simply gone).

## Design — robust by construction

- **In the git-tracked test harness, NOT a settings hook.** A settings-file
  rewrite cannot clobber it. `full_audit.sh` sources `gui_gate.sh` and calls
  the gate directly.
- **Control dir under `$HOME`** (`~/.claude/gui_test_gate/`, override
  `GUI_GATE_DIR`), not the repo — so ONE panel governs the main session AND
  every worktree/subagent test run. One Pause pauses them all.
- **Fails open**: no `DISPLAY`, `GUI_GATE=0`, `wish` missing, or a
  dead/again-unlaunchable panel → the suite just runs, never wedged. (Proven:
  killing the panel mid-wait prints `panel gone, proceeding` and the tests run.)
- **Singleton `wish` panel**: first suite launches it via a pid/liveness file;
  later suites reuse it.

## Control protocol (files in `$GUI_GATE_DIR`)

- `widget.pid` — panel liveness / singleton lock.
- `req/<pid>` — a suite drops this at start and BLOCKS until it is removed.
  Proceed removes all; the auto-start countdown and Snooze remove them on
  expiry; Stop removes them so blocked suites can exit.
- `control` — `RUN` | `PAUSE` | `STOP`, read by suites at each between-test
  pause point. Written by the panel's Pause/Resume toggle and Stop.
- `status/<pid>` — live "which suite / which test" line the panel displays.
- `snooze_until` — epoch deadline; while set, the panel shows a countdown and
  auto-proceeds at expiry. One deadline serves BOTH the default auto-start
  countdown and a user Snooze (they differ only in length and wording), which
  is why the file keeps its original name.

## Shell API (`gui_gate.sh`)

- `gate_start "<label>"` — ensure the panel, drop a go-ahead request, hold
  until Proceed or countdown expiry. Returns 2 if Stop was pressed while
  waiting. **Warns before EVERY suite** (user choice): each suite re-arms a
  request.
- `gate_pause_point "<status>"` — call BETWEEN atomic tests: writes status,
  holds while `control==PAUSE` (the in-flight test always finishes first),
  returns 2 on `STOP`.
- `gate_finish` — remove this suite's status/request files.

## Panel (`gui_gate_widget.tcl`, run by `wish`)

- Top: warning listing suites waiting for go-ahead + **Proceed** /
  **Snooze 5m/15m/30m** (timed, auto-proceed).
- **Auto-start countdown (v2, 2026-07-25).** A waiting suite arms a 2-minute
  deadline and then runs by itself; `GUI_GATE_AUTOSTART=<seconds>` overrides,
  `0` disables (restoring v1's block-until-clicked behaviour). The gate exists
  to warn a user who is AT the desk — v1 stranded every suite indefinitely when
  nobody was there to click, which is the opposite of "fails open". Snooze
  re-arms the same deadline further out. **Pause freezes it** (the countdown
  stops advancing while `control==PAUSE`) — that is the explicit "I am here,
  hold off"; the Resume button clears the deadline so the countdown restarts at
  full length instead of firing the instant you un-pause.
- Persistent controls: a single **Pause/Resume toggle** (label + colour flip
  with `control` state) + **Stop suite**. Live "Running suites" readout.
- Closing the panel (window-manager close) is "get out of the way": it
  releases all requests and sets `RUN` (never wedges a blocked suite). **Stop**
  is the button that aborts a suite.

## full_audit.sh wiring

`gate_start` before the test loop (exit 3 if stopped there);
`gate_pause_point` at the top of the per-test loop (the current test finishes,
then the suite holds); `gate_finish` after; a Stop mid-loop breaks out and
prints `RESULT: STOPPED ... (partial ...)`, exit 3.

## Verified (2026-07-22)

- State machine (control-file simulation): pause holds then resumes; STOP →
  return 2; go-ahead unblocks on request removal; dead panel fails open.
- Fail-open: `GUI_GATE=0` and no-`DISPLAY` both return immediately.
- Live end-to-end: 3-test `full_audit` subset gated, Proceed → all pass exit 0.

## Not in v1 / future

- `run_regression.tcl` (a Tcl driver, mostly headless cases) is not gated —
  the GUI load is `full_audit.sh`. Gate it via `exec gui_gate.sh` hooks if its
  GUI cases ever grow.
- Ad-hoc direct `xschem --script test_*.tcl` runs are not gated; call
  `gate_start` manually around a heavy ad-hoc loop if needed.
- No kill-current-test-on-pause (pause is between-atomic-tests by design).
