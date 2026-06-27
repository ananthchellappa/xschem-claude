# Forcing a window to the front: window-manager focus-stealing, and why the test had to be an eyeball

*A lessons-learned write-up from one small, stubborn bug: "the Library Manager
window does not get keyboard focus when I launch it." The fix was three lines; the
*lessons* are about how GUI/window-manager behavior fails, how to read the symptom,
and why some correct fixes cannot be guarded by an automated test in your
environment. Running example: `libmgr::raise_to_front` in `src/library_manager.tcl`
(feature: `doc/claude/specs/library_manager_launch.md`). Every lesson transfers to any Tk/X —
or really any windowed — application.*

---

## The bug

The Library Manager is a single-window panel. Tools ▸ Library Manager (and the new
`xschem library_manager` command) should open it, or — if already open — bring it to
the front **with keyboard focus**, so you can immediately type/arrow through it.

Reported symptom, in the user's words: *"If I make the CIW active and then go to
the Xschem main window and do Tools ▸ Library Manager, I see `xschem library_manager`
in the log, but the Library Manager does not get focus. If I close it and do it
again, it opens and is focused."*

That last sentence is the whole diagnosis, if you know how to read it.

---

## 1. The fix attempts — and what each failure taught

The window-raising code went through three versions. The dead ends are the
instructive part, so they are kept here.

**v1 — `raise` only.**
```tcl
if {[winfo exists $w]} { raise $w; refresh; return }
```
`raise` changes *stacking order* (who is in front). It says nothing about
*keyboard focus*. The window came forward but the keyboard still belonged to
whatever was active. **Lesson: raising ≠ focusing.** They are independent in X.

**v2 — `focus` on a child widget.**
```tcl
raise $w; focus $w.pw.lib.lb
```
Still no focus when another window was active. The reason is subtle and important:

> Plain `focus $w` only redirects focus *within the toplevel that currently holds
> the application's input focus.* It does **not** move focus from one toplevel to
> another. When the CIW was the active window, focusing a widget in the Library
> Manager's toplevel was simply ignored.

The Tk fix for "focus a window even though another toplevel/app is active" is
`focus -force`. **Lesson: `focus` is polite and toplevel-local; `focus -force`
crosses toplevels.** Also in v2 the *create* path set no focus at all — it relied
on the window manager auto-focusing a brand-new window, which masked the problem
on first open and hid it on re-open.

**v3 — `focus -force` + idle re-assert, on both paths.**
```tcl
raise $w
catch {focus -force $w.pw.lib.lb}
after idle [list refocus $w]   ;# re-assert after the menu interaction tears down
```
Now *opening from closed* focused correctly. *Re-launching an already-open window
still did not.* This split is the key clue.

> **The diagnostic.** Create works, raise does not. A brand-new window gets focus;
> an already-open one refuses it. That asymmetry is the fingerprint of **window-
> manager focus-stealing prevention.**

**v4 — re-map the existing window.** Modern window managers deliberately refuse to
let an application yank focus to a window that is *already open* (anti-focus-
stealing: it stops background apps from stealing your keystrokes). But a window
that is *freshly mapped* is granted focus — that is the normal "new window comes up
ready to use" behavior, and it is exactly why opening-from-closed worked. So we
make the raise path *look like* a fresh map:
```tcl
if {[winfo ismapped $w]} {
  set geo [wm geometry $w]   ;# remember where it is
  wm withdraw $w             ;# unmap
  wm deiconify $w            ;# re-map -> WM treats it as new -> grants focus
  catch {wm geometry $w $geo};# put it back so it doesn't jump
}
raise $w
catch {focus -force $w.pw.lib.lb}
after idle [list refocus $w]
```
This worked.

> **Principle.** When a window manager won't give focus to an already-open window,
> stop fighting `focus`/`raise` and *re-map* the window (`wm withdraw` then
> `wm deiconify`). You are re-using the one code path the WM is willing to focus —
> the new-window path — which the user has often already proven works for you.

Two practical notes that matter in real use:
- **Preserve geometry** around withdraw/deiconify, or the WM may re-place the
  window and it jumps on every re-launch.
- The re-map causes a brief **flicker** (the window blinks out and back). That is
  the price of defeating focus-stealing prevention portably; it only happens on an
  explicit user request, so it is acceptable — but call it out, don't hide it.

---

## 2. Read the symptom; don't just try things

We could have thrashed through Tk incantations at random. What actually solved it
was treating one sentence — "from closed it focuses, re-launching it doesn't" — as
*data*. "New window: yes. Existing window: no" is not noise; it is a named
phenomenon with a known cause and a known workaround.

> **Principle.** A precise description of *when it works and when it doesn't* is
> worth more than a stack trace. Before reaching for fixes, phrase the asymmetry
> out loud ("X works, the-almost-same-thing-Y doesn't") and ask what single
> difference between X and Y could explain it. The difference here — *mapped vs
> freshly-mapped* — was the whole answer.

This is also why you collect the *user's* exact reproduction. "It doesn't get
focus" alone is unsolvable; "it doesn't get focus *unless I reopen it*" is almost
self-solving.

---

## 3. Some correct fixes cannot be guarded by a test — know when, and say so

We wanted a regression test: spawn a competing toplevel, make it active, launch the
Library Manager, assert focus landed in it. We wrote it. It passed. Good?

No. We **sabotage-verified** it (the discipline from
`library_manager_lessons.md` §3: after green, break the product and confirm the
test goes red). We:

1. downgraded `focus -force` back to plain `focus` → the test *still passed*;
2. removed the focus call *entirely* → the test *still passed*.

Under WSLg/Xvfb, a scripted, rapidly-created toplevel is auto-focused by the
environment regardless of what the code does. So the assertion could not tell the
bug from the fix — it was **hollow**. A hollow test is worse than no test: it is a
green light wired to nothing, and it will reassure the next person into shipping a
regression.

We deleted the focus assertions and wrote down, in the test and the spec, exactly
*why* this behavior is verified by hand:

> **Not auto-tested (manual eyeball):** WM focus arbitration across toplevels.
> Under WSLg/Xvfb a scripted toplevel is auto-focused regardless of the code, so an
> assertion passes even with the fix removed; it cannot tell the bug from the fix.

What we *kept* were the checks that genuinely discriminate and don't depend on WM
focus policy: the command opens the window (LL1), re-launch reuses the same window
rather than building a second (LL2, via a stable X window id), the rc flag's
default (LL5), the back-compat proc (LL6), the menu wiring (LL7), and — in the
action-log test — that the launch writes a replayable `xschem library_manager` line
to `Xschem.log` (AL10, which reads real file content and *is* discriminating).

> **Principle.** Behavior that lives in another process's policy — the window
> manager, the compositor, the desktop — is often not observable from inside your
> app's test harness, and a test that "checks" it may only be checking the
> harness's own defaults. Prove that with sabotage. When a thing is genuinely
> WM-arbitrated, the honest deliverable is: a robust fix, the discriminating tests
> you *can* write, and a loud written note that the rest is a manual eyeball.
> Silently keeping a green-but-hollow test is the failure mode here.

---

## 4. Defer focus past the event that triggered it

One more detail earned its place. The launch comes from a **menu**. A menu posts,
you click an item, the command runs, and *then* Tk tears the menu down — and the
teardown restores focus to wherever the menu came from. A `focus -force` issued
synchronously inside the menu command can therefore be undone a moment later by the
menu closing.

The fix is to re-assert focus on the idle queue, after the current event (and the
menu teardown) has finished:
```tcl
after idle [list refocus $w]   ;# refocus = catch {focus -force $w.pw.lib.lb}
```

> **Principle.** If a UI action is triggered from a transient (a menu, a dialog, a
> tooltip), do focus/grab work *after idle*, not inline — the transient's own
> cleanup runs after your handler and can clobber an inline focus call.

---

## The shape of the whole thing

```
symptom: window won't take focus on launch
  v1 raise only ............ raising ≠ focusing
  v2 plain focus ........... focus is toplevel-local; needs -force to cross toplevels
  v3 focus -force .......... create works, raise doesn't  <- the diagnostic clue
  v4 withdraw+deiconify .... re-map = the new-window path the WM will focus    [FIX]
testing:
  focus assertion .......... passed -> sabotaged -> still passed = HOLLOW -> deleted
  kept: open / singleton-id / flag / proc / menu-wiring / logged-line (all discriminate)
  documented: cross-window focus is a manual eyeball (WM policy, not app-observable)
```

Transferable lessons, none specific to Tcl or xschem:

1. raising a window and focusing it are different operations;
2. polite focus is toplevel-local — forcing focus across toplevels needs the
   "force" escape hatch;
3. "new works, existing doesn't" is the fingerprint of focus-stealing prevention;
   re-map the window instead of fighting the WM;
4. preserve geometry across a re-map, and own the flicker out loud;
5. read the user's *when-it-works-and-when-it-doesn't* as the primary evidence;
6. defer focus work past the transient (menu/dialog) that triggered it;
7. sabotage every GUI test — environment auto-behaviors make hollow ones easy to
   write; when a behavior is WM-arbitrated and untestable, say so in writing rather
   than ship a green light wired to nothing.

See also: `library_manager_lessons.md` (the sabotage discipline, §3),
`doc/claude/specs/library_manager_launch.md` (the feature and its acceptance notes).
