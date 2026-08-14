# Window managers, WSLg, and openbox — a plain-English tutorial

*Why Linux GUI apps feel slightly broken under WSL, what is actually missing, and
what a 2 MB program called openbox fixes. Written for someone who has never
thought about window managers, because until something breaks, nobody does.*

Every number in this document was measured on this machine on 2026-08-14. The
commands are included so you can re-measure rather than trust me.

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
DISPLAY=:0 xprop -root _NET_SUPPORTED
```

Measured results:

| Window manager | capabilities advertised |
|---|---|
| **openbox** (full Linux WM) | **70** |
| **Weston WM** (what WSLg runs) | **7** |
| nothing (a bare X server) | *no window manager at all* |

Seven out of seventy. WSLg supports move/resize, fullscreen, maximise, "which
window is active", and frame sizes. That covers what most people do most of the
time, which is why WSLg feels fine.

What is missing includes minimise (`_NET_WM_STATE_HIDDEN`), always-on-top,
"give me the list of open windows", window *types* (so a tool palette can be
told apart from a dialog), modal dialogs, and virtual desktops.

---

## 3. What that costs you in practice

### Minimise silently does nothing

This is the clearest one. A program asks to be minimised; nothing happens; no
error is reported; the program is told everything is fine. Measured with a small
Tk program that asks to iconify itself and then reports its own state:

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

The recipe, standalone:

```sh
# start a virtual screen, run a window manager in it, then run your program
xvfb-run -a -s "-screen 0 1920x1080x24" bash -c 'openbox & sleep 0.3; exec your-program'
```

In this repo it is already wired in and you don't type any of that.
`tests/headless/full_audit.sh` and `tests/headless/run_suites.sh` do it
automatically:

```sh
tests/headless/run_suites.sh test_wave_viewer      # virtual screen + openbox
AUDIT_WM=none tests/headless/run_suites.sh ...     # virtual screen, no WM
AUDIT_DISPLAY=:0 tests/headless/run_suites.sh ...  # your real screen
```

### One trap worth knowing, because it cost real time here

A window manager takes a moment to take charge. A window created before it is
ready is **never** picked up — it stays unmanaged for its whole life. So you
cannot just start openbox and immediately launch your program; you have to wait
until it has actually claimed the screen.

`sleep 0.3` above is the crude version and is fine for a one-off. The proper
check is to poll until the WM has registered itself:

```sh
until xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id #'; do
  sleep 0.05
done
```

Note `'window id #'` and not just `window`. When no WM is running, `xprop`
prints:

```
_NET_SUPPORTING_WM_CHECK:  no such atom on any window.
```

which contains the word "window" — so a check for `window` matches the *failure
message* and reports success immediately, forever. This exact bug shipped in
this repo's harness and survived a review, because openbox happened to win the
race anyway and nothing looked wrong. If you write a readiness check, **match
the success text, never a word that also appears in the error text.**

---

## 6. Use B — openbox on your actual WSLg desktop (possible, with a real trade)

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
untouched, and you can close the whole thing by killing `Xvfb`.

To back out of a `--replace` if you did try it: killing openbox leaves the
screen with *no* window manager, which is worse. Restart the WSL session
(`wsl --shutdown` from a Windows prompt) to get Weston WM back cleanly.

---

## 7. Which should you use?

| Situation | Do this |
|---|---|
| Automated GUI tests | Virtual screen + openbox. Already the default here. |
| Everyday development | Leave WSLg alone. It is good, and the Windows integration is the point. |
| Testing something that minimises, stacks, or manages window lists | Virtual screen + openbox, or the VNC recipe in §6. |
| Chasing a bug only you can reproduce under WSL | Your real `:0`. That is where WSLg's quirks live, and they are real. |

---

## 8. The general lesson, which outlives openbox

The temptation, on finding a bug that only reproduces on one display, is to make
the other environments more realistic until the bug appears there too. That is a
treadmill: we added a window manager to the virtual screen specifically hoping it
would reproduce the resize bug from §3, and it did not, because the cause was
WSLg's event traffic and not window management at all.

The durable fix was to stop depending on the environment. The test now **creates
the interruption itself** — it deliberately fires the disruptive event in the
middle of the operation and checks the operation survives. That test fails on
every display when the protection is removed, including the plain virtual screen
with no window manager at all.

**A safeguard that only fires on one developer's machine is not protected. It is
observed, occasionally, by one person.** If you can describe the hazard, you can
usually trigger it on purpose, and then it is tested everywhere.

---

## 9. Command reference

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

# run something on a private, managed, invisible screen
xvfb-run -a -s "-screen 0 1920x1080x24" bash -c 'openbox & sleep 0.3; exec <cmd>'
```

Packages: `xvfb` (virtual screen), `openbox` (window manager), `x11-utils`
(`xprop`), `x11vnc` (to look at a virtual screen).

---

## Related

- `tests/headless/xvfb_arm.sh` — the implementation, with the measurements in its header
- `CLAUDE.md`, "The display arm" — the short version for this repo
- `doc/claude/specs/gui_test_gate.md` — the control panel that guards real-screen runs
- `doc/claude/calculator_batch/receipts/00-phase0-skeleton.md` — the resize bug, its A/B, and the test that replaced it
