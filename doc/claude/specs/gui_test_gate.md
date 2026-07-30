# GUI-test control gate — warn / Snooze / Pause the headless GUI test suite

Status: SHIPPED **v5** (2026-07-30; v4 2026-07-30, v3 2026-07-29, v2 2026-07-25,
v1 2026-07-22)
Files: tests/headless/gui_gate_widget.tcl, tests/headless/gui_gate.sh,
wired into tests/headless/full_audit.sh **and tests/headless/run_suites.sh**,
plus tests/headless/gated_xschem.sh (enrolment wrapper for bare loops).
Self-tests: tests/headless/test_gui_gate_revive.sh (v4),
tests/headless/test_gui_gate_batch.sh (v5).

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
  **v4 caveat:** failing open is the *last* resort, not the first. A dead panel
  is now revived before that fallback is taken — see "Mid-suite panel death".
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
  is why the file keeps its original name. **Known defect (open):** the panel
  *writes* this file but never *reads* it back at startup, so a relaunch — which
  `_gate_attention` does routinely — silently downgrades a user's Snooze 30m to
  a fresh 2-minute autostart.
- `events.log` — v4. Timestamped shell-side trail: panel launched / launch
  failed / death detected / revived / fail-open taken. Capped at ~200 lines.
  **This is the durable record**; `widget.log` is not (below).
- `widget.log` — v4. The panel's own stdout+stderr, replacing `>/dev/null 2>&1`.
  Truncated on *every* launch, so a revive erases the log of the death that
  caused it — which is exactly how the sibling review gate ended up holding a
  0-byte log of a real panel death. Good for "why won't it start", useless for
  "what killed it"; that is what `events.log` is for.
- `last_revive` — v4. Throttle stamp for `_gate_revive_widget`.

## Shell API (`gui_gate.sh`)

- `gate_start "<label>"` — ensure the panel, drop a go-ahead request, hold
  until Proceed or countdown expiry. Returns 2 if Stop was pressed while
  waiting. **Warns before EVERY suite** (user choice): each suite re-arms a
  request.
- `gate_pause_point "<status>"` — call BETWEEN atomic tests: writes status,
  **revives a dead panel (v4)**, holds while `control==PAUSE` (the in-flight
  test always finishes first), returns 2 on `STOP`.
- `gate_finish` — remove this suite's status/request files.

## Mid-suite panel death (v4) — the panel must come BACK

v1–v3 could only ever *build* a panel from `gate_start`. `_gate_ensure_widget`
was reachable from nowhere else (`gate_start` directly, or via
`_gate_attention`), and `gate_start` runs **once per suite invocation**
(`run_suites.sh:76`, `full_audit.sh:152`). A panel that died *between* suites was
therefore rebuilt by the next `gate_start` and nobody ever noticed the gap. A
panel that died *during* one stayed dead until the run ended.

Worse, the one function that runs for the whole life of a suite was blind to it:
`gate_pause_point` tested liveness **only inside its `PAUSE` branch**, so in the
normal `RUN` state it never asked.

**How it happened (2026-07-30, measured).** WSLg's Xwayland aborts on its own —
`(EE) Fatal server error: (EE) request could not be marshaled: can't send file
descriptor`, SIGABRT, `weston.log: xserver exited, code 134` — **three times in
one nine-hour session** (07:44:03, 07:50:37, 08:16:32), each after a *lull*, so
it is not load-proportional and not the suite's fault. Every X client dies with
the server, and a Tk client dies badly: libX11's `_XDefaultIOError` simply
`exit(1)`s and Tk installs no `XSetIOErrorHandler`, so `WM_DELETE_WINDOW` never
fires and `on_close` never runs. **The signature of this death is a stale
`widget.pid` plus an untouched `control` file** — `on_close` would have deleted
one and rewritten the other.

Two of those aborts landed between suites and went unnoticed. The third landed
3 minutes into a 150-run soak: **27 minutes of GUI flood with no Pause button**,
which is precisely the failure this gate exists to prevent.

v4:

- **`_gate_revive_widget`** — drops the stale pid file and relaunches.
  **Throttled (`last_revive`, default 30 s, `GUI_GATE_REVIVE_EVERY`), never
  once-only**: three aborts in one session, and a soak outlives several.
- **Called from `gate_pause_point`, ahead of reading `control`** — between every
  test, for the suite's whole life. Its result is deliberately discarded:
  turning a missing panel into a *blocked* suite would breach the one rule.
- **Also called from `gate_start`'s wait loop**, before the `panel gone,
  proceeding` fallback — the user has still never seen that request.
- **Only a CRASHED panel is revived, never a CLOSED one.** The two are
  distinguishable, and it is the same signature that identified the 07-30 death:
  `on_close` deletes `widget.pid`; a signalled or X-severed panel cannot run
  `on_close` and leaves the file behind. So `_gate_revive_widget` returns early
  when `widget.pid` is **absent** — closing the panel means "get out of the way"
  (see Panel, above), and bringing it back one pause point later would be the
  gate arguing with the user.
- **Reviving while `control==PAUSE` is correct**, and is not a contradiction of
  "never relaunch while paused" under Attention below. That rule forbids
  *killing a live* panel (which would fail-open every held suite). Restoring a
  *dead* one hands the user their Pause back.
- **The reborn panel is SILENT.** `attention` (`focus -force` + `bell`) now only
  fires on startup if a request is actually pending. A mid-suite revive has
  none, and grabbing focus there would steal the keyboard from the xschem window
  a running test is driving with `event generate` — trading a missing panel for
  a new class of test flake. `gate_start` still announces itself: it writes
  `req/<pid>` *before* the relaunch, deliberately.
- **`_gate_widget_alive` checks IDENTITY, not just `kill -0`** — the pid must
  match a `/proc/<pid>/cmdline` containing `gui_gate_widget` (an unreadable
  `/proc` is accepted; unverifiable ≠ wrong). `widget.pid` outlives both the
  process and the boot while pids recycle, and believing a recycled pid is the
  one failure the gate cannot survive: `_gate_ensure_widget` no-ops, no panel
  ever launches, `gate_start` spins **forever**, and `_gate_attention` TERMs then
  SIGKILLs an innocent bystander.

**Not fixed here:** the Xwayland abort itself (a WSLg fd-marshalling bug in
software-render mode — `Failed to initialize glamor, falling back to sw`). Treat
any long-lived X client on this box as mortal.

## The approval window (v5) — "batch the batches"

The gate warned before EVERY suite. Right for one big run, wrong for how testing
actually happens: forty tiny suites of a couple of seconds each meant forty
Proceed presses — or, with nobody at the desk, **forty two-minute autostart
waits to run about two minutes of tests**. The gate was costing an order of
magnitude more time than the tests it guarded, which is its own kind of "stops
being a gate": the pressure is all towards `GUI_GATE=0`.

**Proceed gained siblings: `Allow 30m` / `Allow 2h`.** They write an epoch into
`allow_until`; while that is in the future `gate_start` returns *immediately* —
no `req` file, no countdown, no `_gate_attention` relaunch. Approve once, walk
away, and a whole batch runs back to back.

- **Approving does not give up control.** `control` is read at every pause
  point, so Pause and Stop govern an approved batch exactly as before. That is
  the point of approving it: you leave *because* you can still stop it.
- `gate_start` under a window still ensures a panel exists — **quietly**, with
  no attention grab. A batch running with no panel would be the very flood this
  gate exists to prevent.
- **Allow is enabled even with nothing waiting**, so you can approve *before*
  launching a soak and never be prompted at all.
- **PAUSE freezes the window** as it freezes the countdown: an approved hour is
  an hour of *tests*, and burning it while everything is held would expire the
  window the user is waiting to use.
- `grant_count` — how many suites the window has admitted, shown in the panel
  ("7 suites have run so far") so an open window is never invisible.
- `Revoke` closes it; a malformed or expired `allow_until` is ignored, never
  treated as a blank cheque.

## The hard brake (v5) — authority over runs that never enrolled

Pause and Stop only reach suites that *called* the gate. A bare
`for i in 1..12; do ./src/xschem --script t.tcl; done` never does, so the panel
could only watch a flood it had no authority over.

- The **Running suites** list now also shows every `xschem` process the panel
  did not launch, tagged `UNGATED` (argv[0] basename match, so paths that merely
  run through `.../xschem/...` do not count).
- **`Halt N xschem`** SIGSTOPs them all; the button flips to **`Resume N
  xschem`** (SIGCONT). **`Kill`** unlocks only once something is halted, and
  confirms first — it SIGCONTs before SIGTERM, since a stopped process never
  reaches its handler.
- This is a **brake, not a graceful pause**: halted runs fail or time out, and a
  frozen X client can leave the display sluggish until resumed. Correct when the
  alternative is an unusable PC; hence the separate colour and the always-there
  Resume.
- `GUI_GATE_BRAKE_NAME` retargets it — the self-test aims it at a throwaway
  process so it can never SIGSTOP the user's real windows.

**`gated_xschem.sh`** is the other half: a drop-in for `./src/xschem` that
enrols the run, so the habitual bare loop becomes gated by changing one word.
With an approval window open, such a loop runs unprompted.

## Two defects found while building v5 (both would have killed the panel)

- **`/proc/<pid>/cmdline` parsed as a Tcl list.** `lindex` on that string throws
  `list element in quotes followed by...` the instant any process on the box has
  a quote in its arguments — which is most of the time. It threw inside
  `refresh`, i.e. it killed the panel *at startup*. Command lines are arbitrary
  text: split on the NUL separator into a real list, never `lindex` foreign
  text.
- **The poll loop could die silently.** `after 300 refresh` was the *last*
  statement of the body, so any throw skipped the re-arm — leaving a panel that
  kept its pid and its window, looked perfectly healthy to `_gate_widget_alive`,
  and had stopped reading `req/` and `control` altogether. A suite would then
  block at `gate_start` forever behind a frozen countdown. `refresh` is now a
  wrapper that `catch`es the body, logs to `widget.log`, and **re-arms
  unconditionally**.

**Still open after v5:** nothing *forces* a bare `src/xschem --script` through
the gate — `gated_xschem.sh` and `run_suites.sh` must be chosen. Enforcement
would need a check inside the binary; the brake is the compensating control.

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
