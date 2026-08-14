# Window managers, WSLg, and openbox — a plain-English tutorial

*Why Linux GUI apps feel slightly broken under WSL, what is actually missing,
whose fault it is, and what a 2 MB program called openbox fixes. Written for
someone who has never thought about window managers, because until something
breaks, nobody does.*

Every number in this document was measured on this machine, 2026-08-13 and
-08-14. The commands are included so you can re-measure rather than trust me.

---

## 1. The thing nobody tells you: X doesn't manage windows

When you run a Linux GUI program, two separate pieces of software are involved.

**The X server** owns the screen. It knows how to draw pixels, and it knows a
rectangle called a "window" exists. That is *all* it knows.

**The window manager** is a completely separate program that decides everything
you actually think of as "windowing":

- the title bar, the border, the close button
- where a new window is placed
- which window is on top
- what minimise means
- what happens when you alt-tab
- how a dialog stays attached to its parent

The X server does not do any of that. It has no opinion about it. If no window
manager is running, your windows appear with **no title bar, no border, stacked
on top of each other at the top-left corner, and nothing can be moved,
minimised or raised.** The programs still run and still draw. They just sit
there like stickers on glass.

This is a genuinely unusual design. On Windows and macOS, the window manager is
part of the operating system and cannot be missing. On X, it is optional, and
"nothing is managing the windows" is a perfectly legal state that the system
will not warn you about.

That is the whole background you need.

---

## 2. What WSLg actually gives you

WSLg is Microsoft's system for running Linux GUI apps on Windows so that each
one appears as a normal Windows window. It works well and it is genuinely
clever. But it does not run a normal Linux window manager. It runs a small
compatibility shim inside the Weston compositor, whose job is to translate
between X and the Windows-side window frames.

You can ask any X display who is managing it:

```sh
DISPLAY=:0 xprop -root _NET_SUPPORTING_WM_CHECK
# -> window id # 0x200027
DISPLAY=:0 xprop -id 0x200027 _NET_WM_NAME
# -> "Weston WM"
```

So there *is* a window manager. The question is how complete it is.

There is a published list of features a window manager can support, called
EWMH — think of it as a menu of capabilities, where the WM advertises which
dishes it serves:

```sh
DISPLAY=:0 xprop -root _NET_SUPPORTED | tr ',' '\n' | grep -c _NET
```

Measured results:

| Window manager | capabilities advertised |
|---|---|
| **openbox** (full Linux WM) | **70** |
| **Weston WM** (what WSLg runs) | **7** |
| nothing (a bare X server) | *no window manager at all* |

*(Count them with the `tr ',' '\n'` form above. A `grep -o '_NET[A-Z_]*'` form
returns 71 and 8 — it also counts the name of the property being read. Same
data, one off.)*

Seven out of seventy. WSLg supports move/resize, fullscreen, maximise, "which
window is active", and frame sizes. That covers what most people do most of the
time, which is why WSLg feels fine.

What is missing includes minimise (`_NET_WM_STATE_HIDDEN`), always-on-top,
"give me the list of open windows", window *types* (so a tool palette can be
told apart from a dialog), modal dialogs, and virtual desktops.

### 2a. Who is responsible, exactly

Your own machine will tell you:

```sh
cat /mnt/wslg/versions.txt
head -20 /mnt/wslg/weston.log
```

```
WSLg:     1.0.71  (built 2025-10-06)
weston:   9.0.0-211-g2318feca
FreeRDP:  2.4.0
weston --backend=rdp-backend.so --xwayland --shell=rdprail-shell.so
```

Three links in the chain, three owners:

1. **The X window manager itself** — the 7-entry capability list, and what
   happens when a program asks to be minimised — is weston's
   `xwayland/window-manager.c`. Upstream code, from freedesktop.org. **But the
   copy running here is Microsoft's fork pinned at weston 9.0.0, released
   September 2020**, while upstream is on 14.x. Five years of upstream fixes are
   not in this build, and the version choice is Microsoft's.
2. **What minimise and "on top" even mean in WSLg** — `rdprail-shell.so`. RAIL
   is Remote Application Integrated Locally: each Linux surface is delivered to
   Windows as its own window over RDP. **That module does not exist upstream**;
   it is Microsoft-authored. A minimise request has to travel X → Weston WM →
   rdprail-shell → FreeRDP → Windows, and the middle links are theirs.
3. **The Windows-side window** — Microsoft.

So bug reports go to `github.com/microsoft/wslg`. FreeRDP 2.4.0 (2021) and
weston 9.0.0 (2020) suggest the integration is maintained rather than actively
tracked, so do not hold your breath.

---

## 3. What that costs you in practice

### Minimise silently does nothing

A program asks to be minimised; nothing happens; no error is reported; the
program is told everything is fine. Measured with a small Tk program that asks
to iconify itself and then reports its own state:

| Display | did the frame get created? | after asking to minimise | is it still on screen? |
|---|---|---|---|
| bare X server, no WM | no | still `normal` | yes |
| X server + **openbox** | yes | **`iconic`** | **no** |
| **WSLg `:0`** | yes | still `normal` | yes |

Read the last row carefully. **WSLg behaves the same as having no window manager
at all** for minimise. And note the middle row: on this axis, a plain Linux WM
running on a fake screen is *more correct than WSLg*.

For a user this is a mild annoyance. For a developer it is worse: you can write
a feature that minimises to the tray, test it under WSL, see it "work" (no error,
no crash), and ship something that has never actually minimised once.

### Raise silently does nothing either — and this one is expensive

Minimise is the famous example. **Raise is the one that costs real money**, and
it is easy to miss because WSLg *does* advertise `_NET_ACTIVE_WINDOW`. Two
windows, ask the lower one to come to the front, then ask which is on top:

| Display | after `raise .b` |
|---|---|
| X server + openbox | **`B_top`** — it worked |
| **WSLg `:0`** | **`A_top`** — nothing happened |

Advertised is not implemented. And the consequence is structural: because a bare
`raise` does nothing here, every "bring this window forward" in this codebase is
written as a **withdraw + deiconify re-map** — unmap the window and map it again
to force the issue, because a *newly mapped* window is allowed to appear.

That workaround is in `xschem.tcl`'s `raise_activate_toplevel` and its callers
across `ciw.tcl`, `create_instance.tcl`, `wave_viewer.tcl`, `ase_window.tcl`,
`ase.tcl` and `xinit.c`. The cost is not the hack, it is the *asynchrony*: a
re-map is slow and non-atomic, so tests cannot read the stacking order straight
after a raise. They poll and tolerate instead — see the comments in
`test_ase_window` ("~2 s to show in `wm stackorder`", stalls 1 in 5 pristine
runs), `test_ase_plot`, `test_wave_sigbrowser_i11`/`i12`, `test_ase_interact`.

**Do not expect this one to be fixed.** Windows blocks foreground stealing *by
design* — `SetForegroundWindow` refuses an application that does not already own
the foreground. A Linux app calling `raise` is asking for precisely the thing
Windows exists to deny. That is a policy, not a bug, and the withdraw/deiconify
idiom will outlive any WSLg release.

### Silence, not errors

The pattern behind all of this is the same, and it is why it goes unnoticed for
years: **an unsupported window-manager feature is not an error.** The request is
sent, nobody acts on it, and the program carries on believing it succeeded.
There is nothing in a log. You only find out by checking the *result* rather
than the return code.

### The one where WSLg does more, not less

Not everything is WSLg doing less. Asking a window to resize itself produces:

| Display | "your size changed" events |
|---|---|
| bare X server | 1 |
| X server + openbox | 1 |
| **WSLg `:0`** | **3** |

WSLg's translation layer sends the news three times. Harmless for an ordinary
app. But if your code does something during a resize, it gets re-entered twice
more than you designed for. In this repo that produced a real bug: a routine
that was restoring a saved window layout got interrupted by those extra events,
and the interruption overwrote the layout it was in the middle of applying.

The bug was invisible on any other display and perfectly reproducible on WSLg.
It is the mirror image of the minimise problem — there, WSLg does less than a
real WM; here, it does more.

---

## 4. So what is openbox, and where does it help?

openbox is a window manager. Just the window manager — no desktop, no taskbar,
no wallpaper, no settings app. It is small, it starts in well under a second,
and it implements the full 70-capability feature set above.

It has **two quite different uses** here, and it is worth keeping them apart
because one is safe and routine and the other needs care.

---

## 5. Use A — openbox on a *virtual* screen (safe, recommended, already done)

A virtual X server is a real X server whose "screen" is a chunk of memory
instead of a monitor. Programs run normally; you just can't see them. On Debian
or Ubuntu it comes from the `xvfb` package.

This is the ideal place for automated GUI tests: they don't touch your desktop,
they can't be disturbed by you clicking things, and they're faster.

The catch used to be that a virtual server starts *empty* — no window manager —
so anything involving frames, stacking or minimising was untestable there.
**Starting openbox inside it removes that catch.**

In this repo none of it is typed by hand. One command brings up a **persistent**
virtual screen with openbox already running in it:

```sh
tests/headless/devdisplay.sh start     # Xvfb :99 + openbox, ~0.34 s, idempotent
tests/headless/devdisplay.sh view      # watch it in a VNC window, on demand
tests/headless/devdisplay.sh status | stop
```

and the test harness finds it automatically:

```sh
tests/headless/run_suites.sh test_wave_viewer      # attaches to it
AUDIT_WM=none tests/headless/run_suites.sh ...     # virtual screen, no WM
AUDIT_DISPLAY=:0 tests/headless/run_suites.sh ...  # your real screen
```

Full details in `doc/claude/specs/dev_display.md`. **Note who this is for**: the
suites arm themselves, so a human needs nothing beyond `start`. Pointing your own
interactive shell at `:99` is a mistake — when *you* launch xschem you want to
see it.

The standalone equivalent, if you are working outside this repo:

```sh
xvfb-run -a -s "-screen 0 1920x1080x24" bash -c 'openbox & sleep 0.3; exec your-program'
```

---

## 6. Four traps when you script this yourself

Every one of these cost real time here. They are all the same shape: something
reports success, or reports nothing, while being wrong.

### 6a. A window manager takes a moment to take charge

A window created before the WM is ready is **never** picked up — it stays
unmanaged for its whole life. So you cannot start openbox and immediately launch
your program. `sleep 0.3` is the crude version and is fine for a one-off. The
proper check polls until the WM has registered itself:

```sh
until xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id #'; do
  sleep 0.05
done
```

### 6b. …and the obvious way to write that check is broken

Note `'window id #'` and not just `window`. When no WM is running, `xprop`
prints:

```
_NET_SUPPORTING_WM_CHECK:  no such atom on any window.
```

which contains the word "window" — so a check for `window` matches the *failure
message* and reports success immediately, forever. **This exact bug shipped in
this repo's harness and survived a review**, because openbox happened to win the
race anyway and nothing ever looked wrong. If you write a readiness check,
**match the success text, never a word that also appears in the error text.**

### 6c. The X socket file does not exist under WSL

The universal idiom for "is display :N up yet" is to wait for its socket:

```sh
[ -S /tmp/.X11-unix/X99 ]        # WRONG here — never becomes true
```

Under WSLg, `/tmp/.X11-unix` is mounted **mode 777 without the sticky bit**, and
an X server refuses to create a socket file in such a directory:

```
_XSERVTransmkdir: Mode of /tmp/.X11-unix should be set to 1777
_XSERVTransSocketCreateListener: failed to bind listener
```

It carries on regardless and binds the Linux **abstract-namespace** socket
instead — `@/tmp/.X11-unix/X99`, a socket with no filesystem entry. So the
display is up, fully working, `xdpyinfo` returns 0 — and the socket file never
appears. A readiness poll on `[ -S ... ]` waits forever for a server that has
been serving the whole time. Check both forms:

```sh
[ -S "/tmp/.X11-unix/X$N" ] || ss -xl | grep -q "@/tmp/\.X11-unix/X$N\b"
```

### 6d. `xdpyinfo` on a dead display hangs

The natural fix for 6c is "just ask the server". Don't ask it *first*:

```sh
xdpyinfo -display :99      # with no server: HANGS, does not fail
```

The X client library tries the unix socket, fails, and falls back to TCP
`localhost:6099` — which under WSL is neither refused nor answered. It ate a
two-minute command timeout on the first cold status check ever run here. **Test
the listen state before probing, and put a `timeout` on the probe anyway.**

### 6e. Bonus: `pkill -f` can kill the shell that runs it

Cleaning up a test display with

```sh
pkill -f "Xvfb :97"        # kills your own shell too
```

matches *any* process whose command line contains that string — including the
shell currently running that very command line. The symptom is a command that
produces no output and exits strangely. Bracket a character to break the
self-match:

```sh
pkill -f "Xvfb [:]97"
```

---

## 7. Use B — openbox on your actual WSLg desktop (possible, with a real trade)

Can you just run openbox on `:0` and get the missing 63 capabilities on your
real desktop? Sort of, and there is a genuine cost.

**Weston WM already holds the job.** X allows exactly one window manager per
screen. Run `openbox` plainly and it will refuse, because the position is taken.
Run `openbox --replace` and it will evict Weston WM and take over.

The trade you are making:

- **You gain** the full feature set: real minimise, always-on-top, window lists,
  virtual desktops, proper modal dialogs, keyboard shortcuts, alt-tab.
- **You lose the thing that makes WSLg pleasant** — Weston WM is what turns each
  Linux window into a *Windows* window. Replace it and you are asking openbox to
  draw Linux title bars inside the frames Windows is still drawing. Expect double
  title bars, and expect minimise/restore to disagree between the two layers.

So this is not a free upgrade. It is a swap: Windows-native integration for
window-manager completeness.

**If you want to try it, do not experiment on the desktop you are working in.**
The safe pattern is a second, separate screen that has nothing to do with `:0`:

```sh
# a second X screen, entirely separate, viewable in a window
sudo apt install xvfb x11vnc            # if not already present
Xvfb :3 -screen 0 1600x1000x24 &
DISPLAY=:3 openbox &
x11vnc -display :3 -localhost -nopw &   # then point any VNC viewer at localhost:5900
DISPLAY=:3 your-program &
```

Now you have a fully-managed Linux desktop-in-a-window, your normal WSLg `:0` is
untouched, and you can close the whole thing by killing `Xvfb`. (`devdisplay.sh
view` does exactly this for the repo's own display.)

To back out of a `--replace` if you did try it: killing openbox leaves the
screen with *no* window manager, which is worse. Restart the WSL session
(`wsl --shutdown` from a Windows prompt) to get Weston WM back cleanly.

---

## 8. Which should you use?

| Situation | Do this |
|---|---|
| Automated GUI tests | Virtual screen + openbox. Already the default here. |
| Everyday development | Leave WSLg alone. It is good, and the Windows integration is the point. |
| Testing something that minimises, stacks, or manages window lists | Virtual screen + openbox, or the VNC recipe in §7. |
| Chasing a bug only you can reproduce under WSL | Your real `:0`. That is where WSLg's quirks live, and they are real. |

---

## 9. The general lesson, which outlives openbox

Three versions of the same lesson, in increasing order of how much they cost to
learn.

**Don't chase realism.** The temptation, on finding a bug that only reproduces on
one display, is to make the other environments more realistic until the bug
appears there too. That is a treadmill: we added a window manager to the virtual
screen specifically hoping it would reproduce the resize bug from §3, and it did
not, because the cause was WSLg's event traffic and not window management at all.

**Force the hazard instead.** The durable fix was to stop depending on the
environment. The test now **creates the interruption itself** — it deliberately
fires the disruptive event in the middle of the operation and checks the
operation survives. That test fails on every display when the protection is
removed, including the plain virtual screen with no window manager at all.

> **A safeguard that only fires on one developer's machine is not protected. It
> is observed, occasionally, by one person.** If you can describe the hazard, you
> can usually trigger it on purpose, and then it is tested everywhere.

**And check that your test can actually see the thing it guards.** When the
readiness bug from §6b was deliberately re-introduced, the entire 31-check suite
stayed **green** — because openbox wins the race anyway on an idle machine. The
suite could not observe the defect through the front door at all. The fix was to
test the *predicate* directly: a bare Xvfb has no window manager, so the
"is the WM live?" function must return false on it, on every machine, every time.
That check goes red instantly. **If a sabotage doesn't turn your suite red, the
suite was never testing that thing** — and you only find out by trying.

---

## 10. Command reference

```sh
# who is managing this screen?
xprop -root _NET_SUPPORTING_WM_CHECK
xprop -id <the id it printed> _NET_WM_NAME

# what can it do? (count the entries)
xprop -root _NET_SUPPORTED | tr ',' '\n' | grep -c _NET

# does it support minimise specifically?
xprop -root _NET_SUPPORTED | grep -c _NET_WM_STATE_HIDDEN     # 0 on WSLg, 1 on openbox

# is a given window actually framed by a WM? (frame id differs from window id)
# in Tk:  expr {[wm frame .win] != [winfo id .win]}

# is display :N actually up? (the file socket does NOT exist under WSL)
ss -xl | grep "@/tmp/\.X11-unix/X"

# what is WSLg made of, and how old is it?
cat /mnt/wslg/versions.txt
head -20 /mnt/wslg/weston.log

# this repo: a persistent managed virtual screen
tests/headless/devdisplay.sh start|status|view|stop

# elsewhere: a one-shot managed virtual screen
xvfb-run -a -s "-screen 0 1920x1080x24" bash -c 'openbox & sleep 0.3; exec <cmd>'
```

Packages: `xvfb` (virtual screen), `openbox` (window manager), `x11-utils`
(`xprop`, `xdpyinfo`), `iproute2` (`ss`), `x11vnc` (to look at a virtual screen).

---

## Related

- `doc/claude/specs/dev_display.md` — the persistent display: design, requirements, evidence
- `tests/headless/devdisplay.sh` — the implementation
- `tests/headless/xvfb_arm.sh` — how suites choose a display, with measurements in its header
- `CLAUDE.md`, "The persistent dev display" / "The display arm" — the short version
- `doc/claude/specs/gui_test_gate.md` — the control panel that guards real-screen runs
- `doc/claude/calculator_batch/receipts/00-phase0-skeleton.md` — the resize bug, its A/B, and the test that replaced it
