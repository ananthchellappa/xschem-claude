# GUI-test control gate — warn / Snooze / Pause the headless GUI test suite

Status: SHIPPED **v3** (2026-07-29; v2 2026-07-25, v1 2026-07-22)
Files: tests/headless/gui_gate_widget.tcl, tests/headless/gui_gate.sh,
wired into tests/headless/full_audit.sh **and tests/headless/run_suites.sh**.

## THE ONE RULE (v3)

**The only thing that holds tests up indefinitely is a user PAUSE.** Every other
state self-releases: the go-ahead countdown expires and starts the suite, Snooze
only pushes that deadline out, and STOP now clears itself once the suites it
aborted have drained. Anything that can strand a suite behind a panel nobody is
there to click is a bug against this rule, not a feature.

**Corollary: the panel must be SEEN.** A gate the user never notices is worse
than no gate — the suite waits out its countdown and then floods a display the
user never got the chance to defend. See "Attention" below.

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
- **Launched with `setsid`, in its OWN process group (v3).** A plain
  `( wish ... & )` leaves the panel in the *launching suite's* process group, so
  anything that kills that group — which is how a background or CI task is
  normally torn down once it finishes — kills the panel too. Observed in the
  wild: after a 6-run soak completed, the panel was gone with `widget.pid` still
  on disk, i.e. killed by signal so none of `on_close`'s cleanup ran.
  Reproduced deterministically with `kill -TERM -<pgid>` against the launcher's
  group, and fixed by `setsid` (verified: `pid == pgid`, survives the kill).
  This matters more than it looks: the panel is a singleton meant to outlive
  every individual suite, and a silently-dead panel is the exact failure mode
  this whole gate was built to replace.

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
- **STOP self-clears (v3).** `control=STOP` used to persist in the file forever:
  one Stop press made *every future suite* return 2 from `gate_start` and exit 3
  — a permanent hold nobody asked for, i.e. a direct breach of the one rule.
  Stop is per-suite, so the panel now writes `RUN` back once no `status/*` file
  and no `req/*` remain, after a 5 s grace for suites that have not yet reached
  their next pause point. `gate_start` independently clears a STOP that was
  already standing when it arrived: that Stop was aimed at an earlier suite, and
  this one has never been told to stop. A Stop pressed *while* a suite waits is
  still honoured — that is the `return 2` path.

## Attention (v3) — the panel must appear where the user is

The user runs a virtual-desktop manager (VirtuaWin). A window created on
desktop A is not reachable from desktop B: `raise` and `-topmost` act *within* a
desktop, and there is no portable way to ask a window manager which desktop a
window is on, let alone move it there. So a long-lived singleton panel reliably
ends up somewhere the user is not looking.

`_gate_attention` (in `gui_gate.sh`, called from `gate_start`) therefore
**kills and relaunches the panel** — a fresh window maps on the *current*
desktop. Explicitly authorised by the user. Details that matter:

- **Never while `control==PAUSE`.** Pause means "I am here, hold off", and a
  dead panel *fails open* by design (`gate_pause_point` returns 0 when the
  widget is gone) — so killing it mid-pause would march every held suite
  straight through the hold. Not raising a paused panel costs nothing: whoever
  pressed Pause is by definition at the desk.
- **A plain `TERM`, not the close button.** The panel's `WM_DELETE_WINDOW`
  handler releases every pending request (closing must not wedge a suite);
  running that here would let the requesting suite through ungated.
- **10 s thrash guard** (`last_raise`), so several suites starting at once do
  not relaunch the panel repeatedly.
- **Request file is written BEFORE the relaunch**, so the new widget sees it on
  its first poll and flashes for it immediately.
- The widget does the in-desktop half itself: `deiconify`, `raise`,
  `focus -force`, `-topmost`, `bell` and a red header flash — on startup and
  whenever a *new* request appears (set comparison, so a still-waiting suite
  does not re-flash every 300 ms). All `catch`ed: a WM that refuses
  focus-stealing must not take the panel down with it.

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

## run_suites.sh — gated ad-hoc runs and soaks (v3)

`full_audit.sh` used to be the gate's ONLY caller, which left the most common
heavy pattern completely ungated:

```sh
for i in 1 2 3 ... 12; do ./src/xschem --pipe -q --nolog --script <t>.tcl; done
```

A 12-run soak is ~6 minutes of windows opening and closing with the Pause button
doing nothing. **Use `tests/headless/run_suites.sh` instead** — same
`gate_start` / `gate_pause_point` / `gate_finish` wiring, same fail-open:

```sh
tests/headless/run_suites.sh -n 12 test_wave_markers        # a gated soak
tests/headless/run_suites.sh --nogui test_wave_markers      # engine arm
tests/headless/run_suites.sh -n 3 test_wave_viewer test_wave_modes
tests/headless/run_suites.sh --logdir test_actionlog_suppress_gate
```

Repeats are the OUTER loop (`-n 3 a b` runs `a b a b a b`), so a multi-suite
soak interleaves and offers a pause point every run rather than every suite.
Exits 0 only if every run passed, 3 if Stopped. **Brief subagents to use it
too** — they run the same bare loops otherwise.

## Not in v1 / future

- `run_regression.tcl` (a Tcl driver, mostly headless cases) is not gated —
  the GUI load is `full_audit.sh`. Gate it via `exec gui_gate.sh` hooks if its
  GUI cases ever grow.
- No kill-current-test-on-pause (pause is between-atomic-tests by design).
- The relaunch-for-attention is unconditional (modulo PAUSE and the 10 s guard)
  because "which desktop is this window on" is unanswerable portably. If a
  future WM exposes it (`_NET_WM_DESKTOP` via `xprop`), prefer querying and
  relaunching only on a mismatch.

## Verified (v3, 2026-07-29)

Against a throwaway `GUI_GATE_DIR`, each with its real countdown:

- STOP with no live suite → back to `RUN` after the 5 s grace; STOP **with** a
  live `status/*` file → still `STOP` at 8 s, then `RUN` 7 s after it drained.
- `PAUSE` → still `PAUSE` after 12 s idle (nothing but the user clears it).
- `_gate_attention` while `PAUSE` → widget pid **unchanged**; while `RUN` →
  new pid, old process reaped; called twice inside 10 s → pid unchanged.
- `gate_start` with a stale `STOP` standing → returns **0**, not 2, and leaves
  `control=RUN`; released by autostart at exactly `GUI_GATE_AUTOSTART`.
- `run_suites.sh`: fail-open (`GUI_GATE=0`) clean; missing suite → exit 1;
  no suites / bad option → exit 2; gated 4-run and 6-run soaks → all pass with
  `req/` and `status/` both empty afterwards.
- Panel survival: `kill -TERM -<launcher pgid>` killed the panel BEFORE the
  `setsid` fix and does not after; full lifecycle (request → autostart expiry →
  status churn → `gate_finish`) leaves it alive throughout; it also survives its
  launching shell simply exiting.
