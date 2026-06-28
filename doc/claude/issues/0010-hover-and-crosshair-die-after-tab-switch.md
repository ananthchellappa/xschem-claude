# Issue 0010 — hover (and crosshair) silently die after a tab switch

**Opened:** 2026-06-15
**Status:** RESOLVED 2026-06-15 — fixed on `library-manager` (commit: one-line
change in `handle_motion_notify`, `src/callback.c`). RED→GREEN test `HV9` in
`tests/headless/test_hover_highlight.tcl` (now 12 checks). End-to-end repro
(open A → Library Manager → open B → close B → move in A) confirmed fixed.
**Affects:** the hover-highlight cue and the crosshair, in the **tabbed**
interface, after the active tab changes back to a schematic without the mouse
physically re-entering the canvas.
**Severity:** medium (a headline feature silently stops working; recovers only by
reopening the schematic — easy to misread as "hover is broken").
**Related:** [[hover-highlight]]; surfaced while building the Library Manager
([[library-manager]] Phase 7), whose new-window open/close is the everyday trigger.

> **Why this write-up exists.** The bug itself is one line. The *path to finding
> it* is the lesson: a reasonable reproduction script said "everything is fine"
> while the real GUI was clearly broken. Learning to notice when your test is
> measuring the wrong thing is a transferable skill. Read this if you ever debug a
> "works in my test, broken in the app" problem.

---

## 1. The symptom (reported)

1. Open schematic **A**. Hover works — moving over an object outlines it.
2. From the Library Manager, open another view **B** (it opens in its own tab).
3. Close **B**. You are back in **A**.
4. **Hover no longer works in A.** Moving the mouse produces no outline.
5. It stays broken until you *close and reopen A*, after which it works again.

---

## 2. First, a quick model of the feature

Hover is drawn by `draw_hover()` (`callback.c`), called on every mouse motion. It
only acts when the pointer is over the canvas, gated by a per-context flag:

```c
if(tclgetboolvar("hover_highlight") && xctx->mouse_inside &&
   (xctx->ui_state & ~SELECTION) == 0 && xctx->semaphore < 2) {
    newsel = find_closest_obj(...);      /* what is under the cursor */
} else {
    newsel.type = 0;                     /* nothing -> no outline */
}
```

So "hover does nothing" means the gate is false. Four inputs: the enable var,
`mouse_inside`, `ui_state`, `semaphore`. The job is to find which one is wrong
after step 3 — and *why nothing fixes it*.

---

## 3. The reproduction that lied (important)

The natural first move is a headless repro that drives the same commands and asks
the engine for the hover state:

```tcl
xschem load <A>
xschem callback .drw 7 ...      ;# Enter
# move over an instance ...
puts "before: [xschem hover]    sem=[xschem get semaphore] ui=[xschem get ui_state]"
xschem load_new_window <B>
xschem new_schematic destroy <Bpath> {}    ;# close B, back to A
# move over the instance again ...
puts "after:  [xschem hover]    sem=[xschem get semaphore] ui=[xschem get ui_state]"
```

Output:

```
before: {type instance ...}  sem=0 ui=0
after:  {type instance ...}  sem=0 ui=0      <-- hover STATE is fine!
```

The script reported the bug **does not happen**. `semaphore` and `ui_state` were
clean, and `xschem hover` returned the object both times. So is the report wrong?

No. **The test was measuring the wrong layer.** Two mistakes were hiding the bug:

- **`xschem hover` returns the computed `hover_type`, not whether the outline was
  drawn.** `draw_hover()` sets `hover_type` and *separately* strokes the outline
  with a GC. The query reflects the first, the user sees the second. A query that
  reports "instance" proves the detection ran — it says nothing about pixels.
- **The script fed events with `xschem callback .drw 6 ...`, bypassing the Tk
  bindings.** It manufactured a clean motion directly into the handler. The real
  GUI delivers motion through Tk's event bindings on the *physical* window — and
  the bug lives in the difference between those two paths.

> **Lesson 1.** When a faithful-looking repro disagrees with a real report,
> suspect the repro before the report. Ask: *what does my probe actually observe,
> and is it the same thing the user observes?* State ≠ rendering. A synthesized
> event ≠ a real one.

---

## 4. The real reproduction

Make the script mimic what the *hands* do, not just what the *commands* do. The
key realization: to use the Library Manager you move the mouse **out of the
canvas** (into the Library Manager window) and back. So insert the `LeaveNotify`:

```tcl
xschem callback $A 7 ...          ;# Enter A   -> mouse_inside = 1, hover works
xschem callback $A 8 ...          ;# Leave A   (mouse goes to the Library Manager)
xschem load_new_window <B>        ;# open B
xschem new_schematic destroy $B {} ;# close B, back to A
# now ONLY a motion arrives in A (no Enter) ...
motion_over_instance $A
puts "after: [xschem hover]"       ;# -> ""   BUG REPRODUCED
```

With the `Leave` in place, `after` is empty. The bug is real and now deterministic.

---

## 5. Root cause

`mouse_inside` has exactly two writers:

| Event | Handler | Effect |
|---|---|---|
| `EnterNotify` | `handle_enter_notify` (`callback.c:3324`) | `mouse_inside = 1` |
| `LeaveNotify` | motion-notify switch (`callback.c:5693`) | `mouse_inside = 0` |

`MotionNotify` **never** sets it. Normally that's fine: you cannot get a motion
without first having entered. **But the tabbed interface breaks that assumption.**

In tabbed mode every tab shares ONE physical canvas window (`create_new_tab`):

```c
xctx->window = save_xctx[0]->window;   /* all tabs draw on the same drawable */
```

Now trace the pointer:

1. Pointer in A's canvas → `EnterNotify` → **A.mouse_inside = 1**.
2. Pointer leaves to the Library Manager window → `LeaveNotify` → **A.mouse_inside = 0**.
3. Open B, close B. The active context flips B→A. **No `EnterNotify` is generated**
   — the pointer is already inside the shared physical window; it never crossed a
   window boundary. So **A.mouse_inside stays 0.**
4. You move inside the canvas → `MotionNotify`. It does not set `mouse_inside`, so
   the gate stays false. Hover (and the crosshair, which uses the same flag) is
   dead — and stays dead, because no further `EnterNotify` will ever come while
   the pointer remains in the window.
5. Reopening A builds a fresh context whose next real `EnterNotify` sets the flag —
   which is why reopening "fixes" it.

> **Lesson 2.** A flag maintained by paired begin/end events (Enter/Leave,
> open/close, lock/unlock) is only correct if *every* begin is actually
> delivered. Shared/virtualized resources (here: one window backing many tabs)
> quietly drop the "begin" half. When you rely on an edge event, ask "can the
> state change without that edge firing?"

---

## 6. The fix

A `MotionNotify` delivered to the canvas *is* proof the pointer is inside it.
Assert the flag there:

```c
/* handle_motion_notify(), after the win_path guard */
xctx->mouse_inside = 1;   /* a motion in the canvas means we are inside it */
```

`LeaveNotify` still clears it when the pointer genuinely leaves, so the flag
stays correct in both directions. One line; fixes hover and the crosshair
together (same gate, same latent bug).

> **Lesson 3.** Prefer state that is *re-derivable from the events you actually
> receive* over state that depends on a perfectly-paired history. "I got a motion,
> therefore I'm inside" is self-correcting; "I'm inside because I remember an
> Enter" drifts the moment an Enter goes missing.

---

## 7. The test (capture the cause, not the scene)

`HV9` does not stage the whole tab dance — that would be slow and couple the test
to window management. It targets the **root cause** directly: clear the flag with
a `LeaveNotify`, then assert a *motion alone* re-establishes hover.

```tcl
motion_to 200 100
check "HV9a hover works before leave"  {[hov_type] eq "wire"}
xschem callback .drw 8 100 100 0 0 0 0      ;# LeaveNotify -> mouse_inside = 0
motion_to 200 100                           ;# motion only, no Enter
check "HV9b motion re-establishes hover" {[hov_type] eq "wire"}
```

RED before the fix (`HV9b` empty), GREEN after. It will catch any future change
that makes motion stop asserting "inside," regardless of how tabs are managed.

> **Lesson 4.** Test the mechanism, not the anecdote. The bug arrived via a tab
> switch, but the *fault* was "motion doesn't imply inside." A test pinned to that
> sentence is short, fast, deterministic, and still guards the real-world scenario.

---

## 8. Takeaways (the portable bits)

1. **State vs rendering.** A query that returns the right value does not prove the
   right pixels were drawn. Know which layer your probe lives in.
2. **Synthesized ≠ real.** Injecting events past the binding layer can hide bugs
   that only the real input path triggers. Reproduce at the layer the user uses.
3. **Edge-triggered flags drift** when a shared resource swallows one edge. Either
   guarantee both edges or make the state re-derivable from the events you do get.
4. **Test the cause.** Reduce a multi-step scenario to the one invariant that was
   violated, and assert that.
