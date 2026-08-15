# 0310 — a revived WSLg display is a 640×480 stub that parks every window off-screen

**Status:** OPEN — environment defect, not an xschem bug, but the harness can and
should detect it.
**Filed:** 2026-08-10, during Batch F (driver round).
**Related:** the `wslg-xwayland-aborts` reference note; `doc/claude/specs/gui_test_gate.md`.

## What happens

WSLg's Xwayland aborts on its own a few times a session — that much is already
known and recorded. What was not recorded, and what cost this batch an entire
item, is **what `:0` looks like after it comes back**.

It answers. `xdpyinfo -display :0` succeeds, clients connect, `wish` starts, Tk
maps windows, and every automated liveness check in the harness reads green.

But the display is a **640×480 stub**, and the window manager parks new
top-levels at absolute **−32768**:

```
$ xwininfo -root
  Width: 640
  Height: 480
  -geometry 640x480+0+0

$ xwininfo -root -tree
     0x201d48 (has no name): ()  544x547+-32768+-32768  +-32768+-32768
        0x400049 "xschem GUI-test control": (...)  468x450+38+59  +-32730+-32709
```

The panel asks for `+40+40` (`tests/headless/gui_gate_widget.tcl:161`) and is
honoured — relative to a WM frame that is itself nowhere. The user sees no
window and no taskbar icon; there is nothing wrong with the client.

## Why it matters

Two failures, and the second is the expensive one.

1. **The GUI-test control gate becomes unreachable.** The panel is alive,
   `pid == pgid == sid`, `DISPLAY=:0`, gating suites and logging
   "approval window open — starts without asking" — and invisible. Pause and Stop
   survive only through the control file
   (`echo STOP > ~/.claude/gui_test_gate/control`), which is not the interface
   the gate exists to provide. Killing and relaunching does not help: two
   relaunches landed at the identical off-screen coordinates, because the panel
   is going exactly where it is told.

2. **GUI suites keep running, blind, against a 640×480 desktop, and their
   results look real.** Nothing fails loudly. Geometry-sensitive tests
   (root-coordinate checks, anything asserting on window placement or size,
   TG9's family) misbehave in ways that read as ordinary red. In this batch that
   contamination cost three separate passes chasing "green-to-worse" audit rows
   that were finally proved environmental — item 5's salvage receipt has the
   accounting.

An audit taken on a stub display is not a weaker measurement. It is a
measurement of a different machine.

## How to detect it

Cheap, and either check alone is decisive:

```sh
# 1. the root window is the real desktop, not a stub
xwininfo -root | awk '/Width|Height/'

# 2. nothing is parked at the -32768 sentinel
xwininfo -root -tree | grep -- '+-327'
```

A healthy WSLg session reports the real desktop size and has no `-327xx`
coordinates anywhere in the tree.

## Proposed fix in this repo

We cannot fix Xwayland. We can refuse to report meaningless results:

* Add a **display-sanity preflight** to `tests/headless/full_audit.sh` and to
  `gate_start` in `tests/headless/gui_gate.sh`: assert the root geometry is
  larger than some floor (say 1024×768) and that no top-level sits at a
  `-327xx` coordinate. On failure, **abort the run with a distinct status** —
  not SKIP, which `full_audit` scores file-wide and silently discards, and not
  FAIL, which reads as a code regression. Something like `ENVBAD`, printed once
  and loudly.
* Have `_gate_ensure_widget` run the same check before it launches, and log
  `panel launched onto a stub display` when it trips, so the events log records
  the cause rather than a healthy-looking launch.
* Note in `doc/claude/specs/gui_test_gate.md` that panel liveness
  (`pid == pgid == sid`, `DISPLAY=:0`, alive in `/proc`) is **necessary but not
  sufficient** — visibility is a separate property and needs its own assertion.

## Workaround until then

`wsl --shutdown` from the Windows host, then reopen. There is no in-session
recovery: the stub display cannot be resized from a client, and restarting
Xwayland from inside the distro is not possible (it lives in the WSLg system
distro). Any suite that ran between the abort and the restart should be re-run
before its results are trusted.
