# Spec — the persistent dev display

*A long-lived, private, window-managed X display that GUI testing lands on by
default, so running the suites never takes the developer's screen.*

Status: implemented. `tests/headless/devdisplay.sh`, plus an attach path in
`tests/headless/xvfb_arm.sh` and a gate exclusion in `tests/headless/gui_gate.sh`.
Tests: `tests/headless/test_devdisplay.sh`.

Related: `tests/headless/xvfb_arm.sh` (the per-run arm this extends),
`doc/claude/specs/gui_test_gate.md` (the control panel this makes near-redundant),
`doc/claude/suggestions/openbox_on_wslg_tutorial.md` (why openbox is in the mix).

---

## 1. The problem, measured

`8423240a` gave `full_audit.sh` and `run_suites.sh` a private Xvfb, so whole-suite
runs stopped borrowing the monitor. That fixed the two entry points that were
armed and nothing else:

```
$ grep -rln xvfb_arm tests/
tests/headless/xvfb_arm.sh
tests/headless/full_audit.sh
tests/headless/run_suites.sh
```

What still lands on the developer's screen:

| # | leak | size |
|---|---|---|
| L1 | **direct binary invocation** — `./src/xschem --pipe -q --script tests/headless/<t>.tcl` | 319 `tests/headless/test_*.tcl` + ~25 `tests/*.tcl`; the single most-typed command in a session |
| L2 | `gated_xschem.sh` | sources `gui_gate.sh`, never `xvfb_arm.sh` — it *gates* the screen instead of freeing it, while CLAUDE.md recommends it as the drop-in binary |
| L3 | standalone `.sh` suites | 8 of them map windows: `test_action_replay.sh` (57 launches), `test_file_menu_log.sh` (27), `test_flylines.sh` (43 of 46), `test_action_log.sh` (7), `test_gui_gate_batch.sh` (7), `test_recent_launchlog.sh` (6 of 20), `test_readonly_action_dispatch.sh` (3), `test_readonly_guard.sh` (2) |
| L4 | doc headers | 10+ test files instruct `DISPLAY=:0 ./src/xschem …`, teaching the habit |

**Not leaks, checked and cleared:** `run.sh`, `run_nogui.sh` and all three
`run_regression.tcl` cases pass `--nogui`, which forces `has_x=0` and maps no
window even with `DISPLAY` set. `test_wslg_health.sh` wants the real WSLg display
by definition.

### Why per-harness patches cannot finish the job

L2–L4 are fixable by sourcing the arm. **L1 is not.** There is no wrapper around
a binary name a human types. Any fix that depends on remembering to type
something different has already failed once — that is exactly how `gated_xschem.sh`
came to exist and exactly why it does not help here.

The fix must therefore be **environmental**: make the invisible display the one a
bare `./src/xschem` gets, and make `:0` the thing you opt into.

---

## 2. What this is

One long-lived X display — `Xvfb` plus `openbox` — that outlives any single test
run, with a small manager script and three integration points.

```
devdisplay.sh start      # Xvfb :99 + openbox, readiness-polled, idempotent
devdisplay.sh status     # alive? which display, pids, screen, wm, client count
devdisplay.sh view       # x11vnc on localhost -- look at it, on demand
devdisplay.sh exec CMD…  # run one command on it without exporting
devdisplay.sh shellinit  # the shell-rc snippet (see below)
devdisplay.sh stop
```

### Who the export is actually for

Not the human. This deserves stating plainly because an earlier revision of this
spec got it backwards and told them to append `shellinit` to `~/.bashrc`.

A person launching xschem is launching it **to use it**; routing that to an
invisible display is the bug, not the fix. And they do not need it for suites
either — `full_audit.sh`, `run_suites.sh`, `gated_xschem.sh` and the 8
standalone `test_*.sh` all arm themselves (R501, R801, R802). For the human,
starting the display is the whole of the job:

```sh
tests/headless/devdisplay.sh start
```

**L1 belongs almost entirely to the assistant.** A bare
`./src/xschem --pipe -q --script tests/headless/<t>.tcl` is typed dozens of
times a session by Claude Code and armed by nothing. Two covers, in order of
robustness:

1. **`DISPLAY=:99 claude`** — tool shells inherit the Claude Code process's
   environment, so every bare invocation lands on the dev display while the
   human's terminals keep `:0`. Does not depend on the assistant remembering.
2. **`devdisplay.sh exec <cmd>`**, or running the suite through
   `run_suites.sh` — per-command, and therefore only as reliable as the habit.
   Recorded as a rule in `CLAUDE.md`, which is the assistant's equivalent of a
   shell rc.

**`~/.bashrc` cannot do job 1 on this machine.** It returns at lines 6–9 for
non-interactive shells, and the Bash tool's shell is non-interactive
(`$- = hmtBc`, no `i`, no `l`). It **inherits** its environment rather than
sourcing that file. An earlier revision claimed the opposite, "verified" by
observing `~/eda/bin` on `PATH` — a symptom with two explanations, of which
inheritance is the true one. Test the mechanism, not a symptom it shares.

**`shellinit` still has a use**, a narrow one: a terminal used *only* for
running tests by hand. It exports `DISPLAY` **only when the display is actually
listening**, because an unconditional export in a shell rc outlives the display
it names — after a reboot, a `wsl --shutdown`, or a `stop`, every GUI program in
that shell dies with `cannot open display`. Both directions are tested (D15).

**The display does not survive a reboot.** `Xvfb` is an ordinary process. After
a Windows restart or `wsl --shutdown`, run `devdisplay.sh start` again.

### Why persistent rather than per-run

- **L1 needs a display that already exists.** A bare `./src/xschem` spawns
  nothing; it connects to whatever `$DISPLAY` names. Per-run arming cannot reach it.
- **Immunity to WSLg's Xwayland aborts.** That server dies ~3×/session and takes
  every client with it (`doc/claude/issues/` and the `wslg-xwayland-aborts` note).
  A private Xvfb does not die when WSLg does — long runs stop being murdered
  mid-flight.
- **Speed.** No `xvfb-run` spawn per invocation (~1 s), and the measured suite
  gain stands: `test_wave_modes` 2.3 s virtual vs 6.2–45.6 s on `:0`.
- **Determinism.** 30/30 soak with identical check counts where `:0` flakes
  4-in-10 / 2-in-3 / 1-in-5.

### Explicit non-goal

Reproducing WSLg-specific defects. Those need `:0` by construction — WSLg's 3×
`<Configure>` traffic per `wm geometry` is a property of Xwayland, not of window
management, and openbox does not supply it. `AUDIT_DISPLAY=:0` stays the opt-in,
and the durable answer remains forcing the hazard in the test
(`test_calc_skeleton` S12), not shopping for an environment that supplies it.

---

## 3. Requirements

### R1 — lifecycle

- **R101** `start` brings up `Xvfb :$N -screen 0 $SCREEN` and, unless
  `DEVDISPLAY_WM=none`, a window manager inside it, and does not return until the
  display accepts connections **and** the WM has claimed the screen.
- **R102** `start` is idempotent. A second `start` against a live display makes no
  new server, no new WM, and reports the existing one. Same pids.
- **R103** `stop` terminates WM, viewer and server, and removes the state
  directory's runtime files. Stopping a display that is not running is not an
  error.
- **R104** `status` exits 0 when the display is alive and usable, non-zero
  otherwise, and prints display, screen, WM name, server pid, and connected-client
  count on stdout in both cases.
- **R105** `restart` = `stop` then `start`.

### R2 — state, and surviving a reboot

- **R201** State lives in `${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}`,
  under `$HOME` and not the repo, so one display serves the main session and every
  worktree/subagent — the same argument that put the gate dir there.
- **R202** The state directory holds `display` (e.g. `:99`), `xvfb.pid`, `wm.pid`,
  `vnc.pid`, `screen`, `wm`.
- **R203** **Stale state is detected, not trusted.** pids recycle across a WSL
  boot while files persist. Liveness is *identity*, not `kill -0`: a pid counts as
  ours only if it is alive **and** its `/proc/<pid>/cmdline` still names the
  expected program and display. A stale state directory is cleaned and the display
  restarted rather than reported alive.
- **R204** A display that is alive but not ours (someone else's `:99`) is reported
  and **not** adopted, killed, or overwritten.

### R3 — display number

- **R301** Default `:99`, overridable with `DEVDISPLAY_NUM`.
- **R302** `start` refuses a number whose socket `/tmp/.X11-unix/X<N>` is already
  served by a foreign X server (R204), rather than racing it.
- **R303** A **stale lock** — `/tmp/.X<N>-lock` present with no server behind it —
  is cleaned, not treated as occupied. This is the documented cause of the
  black-frame captures earlier in this batch.

### R4 — screen and window manager

- **R401** Screen spec `DEVDISPLAY_SCREEN`, default `1920x1080x24`, **pinned and
  recorded**. Never `1600x1200` — the one size `test_fluid_bodyshove_guards_0132`
  fails at. A run whose geometry is unrecorded cannot be compared with another.
- **R402** WM `DEVDISPLAY_WM`, default `openbox`, `none` for a bare server. A
  missing WM binary degrades to WM-less with a warning; it is not fatal.
- **R403** WM readiness is polled on `_NET_SUPPORTING_WM_CHECK`, matching the
  **success** form `window id #` and never the bare word `window` — `xprop`'s
  failure text is `no such atom on any window.`, so a `grep -q window` readiness
  check succeeds on the first iteration forever. That exact bug shipped in
  `xvfb_arm.sh` and survived review because openbox happened to win the race.
- **R404** Failure to claim the screen within the bound is **loud and
  non-fatal** — a run without a WM is still a useful run; a run that hangs waiting
  for one is not. The warning must not carry a prefix that routine log filters
  strip.

### R5 — integration: the arm

- **R501** `xvfb_arm.sh` with `AUDIT_DISPLAY` unset/`auto` **attaches** to a live
  dev display instead of spawning a private one: exports its `DISPLAY`, forces
  `GUI_GATE=0`, and returns without re-exec.
- **R502** No live dev display → the existing per-run `xvfb-run` spawn, unchanged.
- **R503** An explicit `AUDIT_DISPLAY` still wins over both. `=:0` means `:0`.
- **R504** The attach path announces itself distinguishably from a spawn, so a
  transcript says which display a result came from.

### R6 — integration: the gate

- **R601** `_gate_enabled` returns false when `$DISPLAY` is the dev display.
- **R602** Rationale, and the hazard it closes: `_gate_enabled` only tests that
  `$DISPLAY` is non-empty, so an invisible display arms the gate exactly like a
  real one. `gate_start` → `_gate_attention` then **kills the live panel and
  relaunches it on the invisible display**, for every session sharing
  `~/.claude/gui_test_gate/`. A dev display without R601 does not free the screen;
  it breaks the Pause button. This is the same hazard `xvfb_arm.sh` contains by
  forcing `GUI_GATE=0`, arriving by a second route: a script that sources
  `gui_gate.sh` but not the arm and inherits `DISPLAY=:99` from the shell.
- **R603** The gate stays fully armed on any other display. R601 is an exclusion,
  not a disablement.

### R7 — looking at it

- **R701** `view` starts `x11vnc` bound to **localhost only**, with no password
  arguments beyond `-nopw`, and prints the port. It never listens on an external
  interface.
- **R702** `view --stop` stops the viewer, leaving the display running.
- **R703** `x11vnc` absent is a clear message naming the package, not a stack trace.
- **R704** Viewing is a read path: nothing about `view` may change how tests
  behave. In particular the VNC client's pointer must not be required for any
  suite to pass.

### R9 — pointing shells at it

- **R901** `shellinit` prints a shell-rc snippet to stdout and changes nothing.
- **R902** The snippet exports `DISPLAY` **only if that display is currently
  listening**, testing both the socket file and the Linux abstract socket
  (see §5a on why the file form never exists under WSLg).
- **R903** When it is not running the snippet leaves `DISPLAY` untouched, so an
  ordinary desktop session is unaffected. An unconditional export in a shell rc
  would instead break every GUI program in every new terminal after a reboot or
  a `stop`.
- **R904** The snippet embeds the resolved state-dir path, so a custom
  `XSCHEM_DEVDISPLAY_DIR` is honoured without the rc needing that variable set.

### R8 — the leaks

- **R801** `gated_xschem.sh` sources the arm (L2).
- **R802** The 8 window-mapping standalone `.sh` suites source the arm (L3), with
  two carve-outs: `test_wslg_health.sh` targets the real WSLg display by
  definition, and the two `test_gui_gate_*.sh` suites test the gate itself — the
  arm forces `GUI_GATE=0` and would neuter them, so they inherit `$DISPLAY`
  (which the dev display already makes invisible via the shell export, with the
  gate correctly armed on it for their purposes only because they set their own
  `GUI_GATE_DIR`).
- **R803** Doc headers that instruct `DISPLAY=:0 ./src/xschem …` are rewritten to
  the armed form, keeping `:0` mentioned only where a test genuinely needs it (L4).

---

## 4. Interface summary

```
devdisplay.sh start|stop|restart|status|view [--stop]|exec CMD…|help

DEVDISPLAY_NUM      display number, default 99
DEVDISPLAY_SCREEN   default 1920x1080x24  (never 1600x1200)
DEVDISPLAY_WM       default openbox; none for a bare server
XSCHEM_DEVDISPLAY_DIR  state dir, default $HOME/.claude/xschem_dev_display
```

Arm, after this change:

```
AUDIT_DISPLAY  unset|auto  -> live dev display if there is one, else private Xvfb
               :0          -> the real screen (gate left as the caller set it)
               none        -> DISPLAY unset, GUI legs self-skip
               <other>      -> verbatim
```

---

## 5. Test plan — `tests/headless/test_devdisplay.sh`

Runs against a **throwaway** display number and state dir so it cannot disturb a
real one.

| # | check |
|---|---|
| D1 | `start` → display answers `xdpyinfo`; state files written |
| D2 | idempotent: second `start` leaves `xvfb.pid` unchanged and spawns no second server |
| D3 | WM claimed the screen; `_NET_WM_NAME` is `Openbox`; `_NET_SUPPORTED` count ≫ WSLg's 7 |
| D4 | `status` exits 0 and names display/screen/wm |
| D5 | arm attaches: `AUDIT_DISPLAY` unset + live dev display → `DISPLAY` is the dev display, `GUI_GATE=0`, no re-exec |
| D6 | arm falls back: no dev display → still spawns a private Xvfb (R502) |
| D7 | `AUDIT_DISPLAY=:0` still wins (R503) |
| D8 | `_gate_enabled` is **false** on the dev display (R601) |
| D9 | `_gate_enabled` is **true** on a non-dev display — negative control (R603) |
| D10 | poisoned pid file → **not** reported alive (reports `foreign`: something answers on that display but the pid is not provably ours, which is the accurate reading); restoring the pid restores `alive` |
| D11 | foreign display is not adopted **and not killed** (R204) |
| D12 | end to end: a real headless suite runs on the dev display and reports ALL PASS |
| D13 | `stop` → server gone, state cleaned, second `stop` still exits 0 |
| D14 | `_wm_claimed` is false on a WM-less display, true on the managed one (R403) |
| D15 | `shellinit` points a shell at a live display, and **leaves `DISPLAY` alone when it is not running** (R902/R903) |

Each requires a sabotage that turns it red; a green suite over untouched code
proves nothing.

**D14 exists because the front door does not cover R403.** Breaking the
readiness poll to `grep -q window` — so it matches `xprop`'s failure text and
declares the WM live before it is — leaves D1–D13 **entirely green**, because
openbox wins the race anyway on an idle machine. That is exactly how the same
bug shipped in `xvfb_arm.sh` and survived review. A hazard that cannot be
observed through the front door gets tested at the predicate instead: a bare
Xvfb has no window manager, so `_wm_claimed` must be false on it, on every
machine, every time. This is the same shape as `test_calc_skeleton` S12 — force
the hazard, never wait for an environment to supply it.

`devdisplay.sh` therefore guards its command dispatcher with
`[ "${BASH_SOURCE[0]}" = "$0" ]`, so the test can source it as a library of
predicates without running `status` as a side effect.

---

## 5a. Evidence

Measured 2026-08-14 on this machine.

```
tests/headless/test_devdisplay.sh
RESULT: ALL PASS (35 checks)

devdisplay.sh start   ->  0.34 s
DISPLAY=:97 xprop -root _NET_SUPPORTED | grep -c _NET   ->  71     (WSLg: 7)
wm iconify under it   ->  iconic                                   (WSLg: normal)
```

Six sabotages, each reverted:

| sabotage | result |
|---|---|
| gate exclusion removed (R601) | `FAIL: D8 gate DISABLED on the dev display -> {0} (exp {1})` |
| arm attach path removed (R501) | `FAIL: D5 ... -> {DPY=:99 GATE=0} (exp {DPY=:96 GATE=0})` |
| pid-identity check dropped from `_ours` (R203/R204) | `FAIL: D10`, `FAIL: D11 start refuses a foreign display -> {0} (exp {4})` |
| abstract-socket detection removed | `FAIL: D1 start exits 0 -> {5}` + 5 more |
| readiness poll → `grep -q window` (R403), **before D14** | **ALL PASS — bug invisible** |
| readiness poll → `grep -q window` (R403), **after D14** | `FAIL: D14 _wm_claimed is FALSE on a WM-less display -> {0} (exp {1})` |

Newly-armed suites, run through the arm: `test_action_log` ALL PASS,
`test_readonly_guard` PASS, `test_readonly_action_dispatch` PASS,
`test_flylines` ALL PASS, `test_recent_launchlog` ALL PASS.
`test_file_menu_log` and `test_action_replay` each report one failure — both
**pre-existing**, confirmed by running the pristine file on the same display and
on `:0` and getting the identical failure line.

### Two platform facts this work turned up

**`/tmp/.X11-unix` is mode 777 without the sticky bit under WSLg**, so an X
server cannot create its socket *file* there:

```
_XSERVTransmkdir: Mode of /tmp/.X11-unix should be set to 1777
_XSERVTransSocketCreateListener: failed to bind listener
```

It carries on and binds the Linux **abstract** socket `@/tmp/.X11-unix/XN`, so
the display works perfectly and `xdpyinfo -display :97` returns 0 — while the
socket file never appears. Every readiness check that polls `[ -S
/tmp/.X11-unix/XN ]` therefore reports "the server never came up" for a server
that is up and serving.

**`xdpyinfo` against a dead display hangs.** The client library falls back to TCP
`localhost:6097`, which under WSL is neither refused nor answered. It ate a
two-minute command timeout on the first cold `status` this file ever ran. Probe
the listen state first; never let a probe be the thing that decides whether
something is listening.

---

## 6. What this does not change

- `:0` remains reachable and remains correct for WSLg-only reproductions.
- The gate panel remains, guarding deliberate `AUDIT_DISPLAY=:0` runs. It should
  become rare; a panel popping for a routine suite is a symptom that something
  bypassed the arm.
- Eyeballing is unaffected: `xschem print png` and `ffmpeg -f x11grab` already work
  against a virtual display, and `view` adds a live window when one is wanted.
  Eyeball was never a reason to take the developer's screen.
