# GUI-test control gate — warn / Snooze / Pause the headless GUI test suite

Status: SHIPPED **v6** (2026-08-04; v5 2026-07-30, v4 2026-07-30, v3 2026-07-29,
v2 2026-07-25, v1 2026-07-22)
Files: tests/headless/gui_gate_widget.tcl, tests/headless/gui_gate.sh,
wired into tests/headless/full_audit.sh **and tests/headless/run_suites.sh**,
plus tests/headless/gated_xschem.sh (enrolment wrapper for bare loops).
Self-tests: tests/headless/test_gui_gate_revive.sh (v4 + **v6**),
tests/headless/test_gui_gate_batch.sh (v5).

## v7 (2026-08-13): the gate is no longer the everyday path

`full_audit.sh` and `run_suites.sh` now take a **private Xvfb by default**
(`tests/headless/xvfb_arm.sh`), so a routine suite never reaches the user's
display and the panel never pops. The gate is unchanged and still correct — it
now guards the *deliberate* real-screen runs, reached with `AUDIT_DISPLAY=:0`.

Two consequences worth stating, because they invert earlier assumptions:

- **A panel popping for a routine suite is now a symptom**, not the design. It
  means something bypassed `xvfb_arm.sh` — a bare loop, or a script that has not
  been wired.
- **`GUI_GATE=0` is forced by the Xvfb arm, not left to the caller.**
  `_gate_enabled` only tests that `$DISPLAY` is non-empty, so a virtual display
  arms the gate exactly like a real one, and `gate_start` → `_gate_attention`
  would then kill the live panel and relaunch it on a display nobody can see —
  for every session sharing `~/.claude/gui_test_gate/`. An Xvfb arm without
  `GUI_GATE=0` does not free the screen; it breaks Pause. The forcing lives in
  `xvfb_arm.sh` so no caller can forget it.

The virtual session now runs **openbox** (`AUDIT_WM`, default `openbox`, `none`
to opt out), so window-manager behaviour is no longer a reason to reach for the
real screen: measured, an empty Xvfb does not reparent and silently no-ops
`wm iconify`, while openbox does both — and is *more* faithful than WSLg on
iconify, which WSLg does not honour either.

The real screen keeps two jobs: a human eyeball, and WSLg's own quirks. The
sharpest quirk is event traffic — one `wm geometry` request yields 3 `<Configure>`
events on `:0` against 1 under Xvfb with or without a WM. Calculator phase 0
passed 49/49 under Xvfb and failed three checks on `:0` for exactly that reason.
The durable fix was not a bigger matrix of window managers but a test that
**forces** the race (`test_calc_skeleton` S12), which goes red on every arm.

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
- `widget.launching` — v6. `"<pid> <epoch>"` of a `wish` that has been forked
  but has not written `widget.pid` yet. Its presence is what stops a second one
  being forked, and what lets a later pause point adopt or reap it.
- `widget.pid.crashed` — v6. `"<pid> <epoch>"`, the corpse of a panel a revive
  is working on. v4/v5 *deleted* `widget.pid` before relaunching, which
  destroyed the crashed-vs-closed evidence (below).
- `revive.lock/` — v6. `mkdir` mutex around the whole revive (throttle read +
  corpse rename + launch + pending write), holding `owner` = `"<pid> <epoch>"`.
  Broken if the owner is dead or the lock is older than `GUI_GATE_LOCK_TTL`
  (300 s), so a SIGKILLed suite cannot disable revives for everyone else.
- `events.log` — v4. Timestamped shell-side trail: panel launched / launch
  PENDING / launch abandoned / revived late / death detected / revived /
  fail-open taken. Capped at ~200 lines.
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
  **revives a dead panel (v4)** and **adopts or reaps a launch still in flight
  (v6)**, holds while `control==PAUSE` (the in-flight
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

- **`_gate_revive_widget`** — drops the stale pid file and relaunches (**v6
  renames it to `widget.pid.crashed` instead** — deleting it is what silenced
  every later revive in a run).
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
  when **no marker at all** is present (v4: when `widget.pid` was absent; v6
  adds `widget.pid.crashed` and `widget.launching`, and `on_close` deletes all
  three) — closing the panel means "get out of the way"
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

**Panel liveness is NECESSARY BUT NOT SUFFICIENT (2026-08-10, issue 0310).**
`pid == pgid == sid`, `DISPLAY=:0`, alive in `/proc`, `_gate_widget_alive` green
— and the user sees no window and no taskbar icon, because the display Xwayland
came back with is a **640×480 stub whose WM parks every top-level at -32768**.
The panel is going exactly where it is told; there is nothing wrong with the
client. **Visibility is a separate property and needs its own assertion.**
`tests/headless/wslg_health.sh` is that assertion — five checks, of which the
decisive one maps a real Tk window and compares where it landed with where it
asked to go (spec: `doc/claude/specs/wslg_health_probe.md`).
**It is NOT wired into this gate yet**: `_gate_ensure_widget` should run it
before launching and log `panel launched onto a stub display` rather than a
healthy-looking launch, and `full_audit.sh` should refuse the run with a distinct
`ENVBAD` status. Both remain open under 0310.

**That probe MAPS A WINDOW, so it answers this panel (2026-08-11).** Its check 5
puts a real top-level on the user's desktop, and its first draft consulted
nothing: probe windows flashed past during a sabotage run, the user pressed
**Pause**, and nothing stopped. Anything that paints on the user's screen answers
this button — that is the one rule this gate exists to enforce, and a preflight
is not exempt from it. `wslg_health.sh` now **reads `$GATE_DIR/control` before it
maps anything** — once at startup, and again **before every one of its up-to-3
probe attempts**, sharing one deadline — and exits **4 STOPPED** / **5 DEFERRED**
without mapping. (Consulting only once before the retry loop was not enough: a
button pressed as probe window 1 appeared was answered with two more windows and
a health verdict, and hardest of all on a stub, which misplaces every attempt and
so always takes all three.) Three consequences for this file:

* It **reads the file directly and does NOT source `gui_gate.sh`** — on purpose.
  The probe is meant to become a preflight *inside* `gate_start`, and sourcing
  the gate from something the gate calls is a circular dependency. It also never
  writes into `$GATE_DIR`; that dir belongs to the user and the panel.
* Whoever wires the preflight in must treat **4 and 5 as "not measured"**, not as
  a bad environment: a run the user paused must not be reported as a stub
  display. Only exit 1 means `ENVBAD`.
* A **standing STOP is treated differently by the two**. `gate_start`
  deliberately CLEARS a STOP it finds already set when a new suite arrives (it
  was aimed at some earlier suite); the probe refuses on any standing STOP. As a
  preflight inside `gate_start`, a stale self-clearing STOP would therefore make
  the probe report STOPPED for a run the gate itself would have let through —
  decide that order explicitly when wiring it in.

## The revive that could not (v6, 2026-08-04) — the launch is ASYNCHRONOUS

v4's revive **failed seven times in one day**, each time logging
`revive FAILED -- suite continues UNGATED` and each time exactly 3 s after
`panel death detected`. A 283-test audit ran with no Pause button and the user
relaunched the panel by hand twice. The 3 s were never `wish`'s.

**WSLg dies in TWO ways, and only one of them is survivable at 3 s.**

- **Mode A — Xwayland alone exits** (`weston.log: xserver exited, code 134`)
  with weston alive. Weston respawns it in **2–60 ms**. Every revive in mode A
  succeeded, all eight of them.
- **Mode B — weston itself SIGABRTs** (`stderr.log: WSLGd: ... terminated with
  signal 6`) and WSLGd restarts the whole compositor. The fresh weston binds
  `:0` **immediately** but spawns Xwayland **lazily**: measured 2.83, 2.89,
  2.91, 2.91, 3.05 s — and once **54.4 s**. Every `revive FAILED` was a mode-B
  abort, timestamped within one second of the weston restart. The one mode-B
  abort whose respawn happened to be instant (20 ms) is the one revive that
  succeeded. The discriminator is perfect.

**And `wish` does not fail against a half-up X server — it BLOCKS, silently.**
`connect()` into a restarting compositor succeeds and the X handshake never
completes: measured 25 s with **zero bytes** on stderr and no pidfile (that line
— `gui_gate_widget.tcl`'s `open $PIDFILE w` — runs *after* Tk initialises X, so
an X-less `wish` never reaches it); against a display with no listener at all,
269 s of Xlib TCP-fallback SYN retries. So "empty `widget.log` + absent
`widget.pid` + a live `wish`" is the NORMAL outcome of launching into mode B,
not an anomaly. **`wish` itself is never slow**: fork → pidfile is 106 ms idle,
**76–92 ms under 20 busy loops** on a 14-core box — the 3 s budget has ~33x of
headroom whenever an X server actually exists.

**Two defects, one of which silenced the rest of every run.**

1. The 3 s poll declared `FAILED` and **walked away from a live `wish`**. One of
   those leaked processes wrote its pidfile **134.2 s later** and became the real
   panel — unsupervised, hours after the suite that spawned it had gone ungated.
2. `_gate_revive_widget` deleted `widget.pid` before launching and never put it
   back, so its own precondition `[ -f widget.pid ] || return 1` — the "the user
   closed it deliberately" rule — was false from then on and **suppressed every
   later revive in that run, with no log line at all**. Proof: weston aborted
   again 80 s into the same 283-test audit and `events.log` has no gate event of
   any kind for it.

**The fix is not a longer poll.** The number that would have covered the
observed cases is 134 s, and holding a pause point for 134 s would break THE ONE
RULE. Instead the launch became asynchronous and **tracked**:

- The healthy path keeps its 3 s (33x the measured need).
- A launch still in flight is **recorded in `widget.launching`, not abandoned**:
  the log says `panel launch PENDING (X server may be restarting) -- suite
  continues UNGATED for now`. It is honest — during a compositor restart there
  is genuinely no panel and the suite genuinely is ungated for a few seconds;
  the gate can only make that window short and stop lying about it.
- Later pause points (`gate_pause_point` runs for the suite's whole life)
  **adopt** it the moment `widget.pid` appears → `panel revived late (+Ns)`.
  This is what used to happen by accident at +134 s; now it is deliberate and
  logged.
- A pidfile-less `wish` past **`GUI_GATE_PENDING_DEADLINE` (180 s)** is TERMed,
  then KILLed → `panel launch abandoned`. Justified against the 134 s worst case
  end-to-end with ~35% headroom, and against a *retryable* consequence: after
  reaping, the next attempt (throttled) starts at once. **This is the only place
  a `wish` is killed for being slow**, and it is the anti-orphan clause.
- **Never a second `wish`** while `widget.launching` names a live one; a reviver
  that loses the `revive.lock` waits for the winner's panel instead of forking.
- The corpse is **renamed, not deleted** (`widget.pid` → `widget.pid.crashed`),
  so a failed attempt no longer silences the ones after it. Revive is authorised
  by `widget.pid` **OR** `widget.pid.crashed` **OR** `widget.launching`.
- `_gate_attention` had the same defect on the same path (it kills a healthy
  panel on purpose, then relaunched into the same window) and now leaves the
  same corpse marker.

**The deliberate-close rule survives all of that — it had to.** `on_close` now
deletes **all three** markers and kills any launch still in flight, so a close
still leaves the "no marker" state that means *stay away*, even if it lands in
the middle of a failed revive. Get this wrong and the panel resurrects itself
every time the user closes it; that is the worst regression this file can have,
so it is asserted from both sides (shell arm X3, widget arm W3). A
`widget.pid.crashed` older than `GUI_GATE_CRASH_TTL` (1800 s) expires rather
than authorising revives forever.

**Reproducing mode B without killing the compositor.** Never SIGKILL weston or
Xwayland to test this — it takes down the user's desktop and every X client,
which is what the gate exists to prevent. Two safe stand-ins, both used:
`tests/headless/test_gui_gate_revive.sh`'s PENDING arm puts a stub `wish` on
`PATH` that stays alive, silent and pidfile-less for as long as the test likes;
and for a *real* `wish`, a TCP proxy on `127.0.0.1:6099` that accepts at once,
stays quiet for N seconds and only then relays to `/tmp/.X11-unix/X0`
(`DISPLAY=127.0.0.1:99`) reproduces the blocked handshake exactly — verified
against v4, which logs `revive FAILED` at 3 s and leaks the wish, and against
v6, which logs PENDING and adopts the same wish at +12 s.

**Verified (v6, under load — 20 spinners on 14 cores, loadavg 10→16):**
`test_gui_gate_revive.sh` **51/51** including the new X1–X5 and W3; the same new
arms run against the v4 file (`git show HEAD:...gui_gate.sh` into a scratch dir)
fail **10** checks, so they are not hollow; `test_gui_gate_batch.sh` green,
unchanged.

## The approval window (v5) — "batch the batches"

The gate warned before EVERY suite. Right for one big run, wrong for how testing
actually happens: forty tiny suites of a couple of seconds each meant forty
Proceed presses — or, with nobody at the desk, **forty two-minute autostart
waits to run about two minutes of tests**. The gate was costing an order of
magnitude more time than the tests it guarded, which is its own kind of "stops
being a gate": the pressure is all towards `GUI_GATE=0`.

**Proceed gained siblings: `Allow 30m` / `Forever`.** `Forever` replaced an
`Allow 2h` button: two hours was a guess at how long a person means to be away,
and guessing short is the expensive direction — the window expires mid-batch,
the next suite waits for a Proceed nobody is there to press, and every suite
after that pays the 2-minute autostart. An open-ended grant cannot expire at the
wrong moment, stays fully steerable (Pause and Stop are read at every pause
point regardless), and `Revoke` ends it in one press. It writes the literal word
`forever` rather than an epoch; both sides match that as a **keyword**, before
the numeric test, so every *other* non-number in the file still means "no grant"
(`test_gui_gate_batch` B4). The one place that must not see it is the PAUSE
push-forward, which adds elapsed time to the deadline — on `forever` that
arithmetic would silently downgrade an open-ended grant to seconds, so it is
skipped (`V10`). They otherwise write an epoch into
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
