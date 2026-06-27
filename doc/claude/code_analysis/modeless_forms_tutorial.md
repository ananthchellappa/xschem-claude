# How one shared counter froze a whole UI — a tutorial on modal dialogs, event loops, and re-entrancy

*The story of issue 0009: why XSCHEM's property form blocked the schematic, why
the obvious fix was wrong, and what it teaches about concurrency-without-threads,
overloaded state, and auditing before you cut.*

This is a **teaching** companion to the design record
(`doc/claude/code_analysis/modeless_form_M2_decision.md`) and issue
`doc/claude/issues/0009-property-form-not-fully-modeless-blocks-schematic.md`. It is written
for someone early in their career who already knows how to write a loop and a
function call, but has never had to reason about *an event loop*, *a call stack
that won't unwind*, or *a variable that quietly means two different things*. All
the code is real and on the `slick-property-forms` branch; line numbers were read
from source and are reproducible.

Scattered through are **▶ Level up** sidebars that lift each concrete xschem
detail to the general idea, so you can carry it to any GUI, game loop, or async
system you touch later.

---

## Part 0 — The bug, as the user felt it

XSCHEM is a schematic editor. You double-click a component, a small **Edit
Properties** form pops up, you change `value` from `1k` to `2k`, hit OK. Fine.

But while that form was open, the canvas behind it went *dead*. You could pan and
zoom, and you could Shift-click to add to the selection — and **nothing else**.
No moving parts, no drawing wires, no deleting, no keyboard shortcuts. The form
also refused to give up keyboard focus: clicking the schematic's title bar didn't
"activate" it the way every other window does.

The user's complaint was precise:

> "With the property editor form active I can Shift-click to add to the selection
> and zoom, but cannot otherwise interact with the schematic. The form refuses to
> yield focus."

Professional EDA tools (Cadence) don't do this — their property forms are
**modeless**: they float, and you keep working on the design underneath. Our job
was to make XSCHEM's form modeless too. Simple-sounding. The interesting part is
*why* it was behaving this way, because the cause was not what anyone first
guessed.

---

## Part 1 — Two kinds of dialog: modal and modeless

A **modal** dialog demands you deal with it before anything else. Think of the
"Save changes? Yes/No/Cancel" box — the app waits, frozen, until you answer.

A **modeless** dialog floats alongside your work; you can ignore it, click back to
the main window, and return to it later. Find-and-replace bars are usually
modeless.

XSCHEM's old form was *modal-ish*: it acted modal (canvas frozen) but didn't even
use the proper mechanism for it. Our target was fully modeless.

> **▶ Level up — "modal" is about control flow, not appearance.**
> A dialog isn't modal because of how it *looks*; it's modal because of **who
> holds the thread of execution**. A modal dialog runs a loop that won't return
> control to the rest of the program until it closes. Keep that sentence in mind —
> the entire bug is hiding inside it.

---

## Part 2 — The thing you must understand first: the event loop

XSCHEM's GUI, like almost every desktop GUI, is **single-threaded**. There is no
"UI thread" and "worker thread." There is one thread, running one infinite loop,
conceptually:

```
forever:
    event = wait_for_next_event()      # mouse move, click, keypress, redraw…
    dispatch(event)                    # run the handler for it, then come back
```

That loop is called the **event loop** (or "main loop"). Every click you make is
an `event`; `dispatch` calls a handler; the handler runs to completion and
*returns*; the loop fetches the next event. Because there's only one thread, **two
handlers never run at the same time** — they run one after another. This is why
GUI code can mostly ignore locks and races: the event loop serialises everything
for free.

In XSCHEM the handler for canvas events is one big C function,
`callback()` in `src/callback.c`. Tk (the GUI toolkit) calls it for every mouse
and key event over the drawing area.

> **▶ Level up — concurrency without threads.**
> A single-threaded event loop gives you *interleaving* (many tasks make progress
> over time) without *parallelism* (two tasks running literally at once). The rule
> that buys you safety is brutal and simple: **each handler must return quickly.**
> The moment a handler *doesn't* return — say, it sits and waits for something —
> the whole UI freezes, because the loop can't fetch the next event. Hold that
> thought too.

---

## Part 3 — How do you open a modal dialog inside a single-threaded loop?

Here's a puzzle. A modal dialog must **wait** for the user to click OK. But
"waiting" means not returning. And not returning freezes the event loop — which
means the OK button itself can never be clicked, because the loop that would
deliver the click is stuck. Deadlock. So how does any modal dialog work at all?

The trick every GUI toolkit uses: **run a second, nested event loop**. Tk spells
it `tkwait window .dialog` — "pump events here until the window `.dialog` is
destroyed." It looks like one blocking line, but inside it is *another* copy of
the forever-loop, dispatching events (so the OK button *does* get its click) and
only breaking out when the dialog closes.

XSCHEM's form did exactly this. Stripped down, `slickprop::edit_form` in
`src/property_form.tcl` was:

```tcl
proc slickprop::edit_form {txtlabel} {
    ...
    toplevel .dialog                 ;# create the window + all its widgets
    ...
    tkwait window .dialog            ;# <-- nested event loop: blocks HERE
    ...                              ;#     until OK/Cancel destroys .dialog
    return $::tctx::rcode
}
```

So when you press `Q` to edit properties, the chain is:

```
event loop
  └─ callback()                      (C: you pressed Q)
       └─ … → edit_symbol_property() (C)
              └─ Tcl: edit_prop → edit_form
                     └─ tkwait  ← we are now PARKED here, inside a nested loop
```

Every frame in that chain is **still on the call stack**. `callback()` has not
returned. It *can't* return — it's blocked four levels down in `tkwait`. The
nested loop keeps the screen alive, but the original `callback()` invocation is
frozen mid-flight, waiting for a window that only the user can close.

> **▶ Level up — a blocked call stack is "paused work," not "finished work."**
> When you call a function that internally spins an event loop, your function is
> *suspended*, not *done*. Its local variables, and every caller above it, are all
> still live on the stack. This is the same idea as a coroutine yielding, or
> `await` in async code: control left your function, but your function did not
> finish. Many subtle bugs come from forgetting that the half-finished caller is
> still sitting there, holding whatever it was holding.

Remember that last clause: **holding whatever it was holding.** What was
`callback()` holding?

---

## Part 4 — The shared counter: `xctx->semaphore`

XSCHEM has a single global integer, `xctx->semaphore`. Despite the name it is not
a threading semaphore; it's a **re-entrancy counter**. The very first thing
`callback()` does on entry, and the last thing it does on exit, is:

```c
/* src/callback.c */
xctx->semaphore++;          /* ~line 5568: "to recognize recursive callback() calls" */
   ...                      /* (handle the event) */
if(xctx->semaphore > 0) xctx->semaphore--;   /* ~line 5672, on the way out */
```

So the value of `semaphore` tells you **how deeply nested you are in callbacks**:

| Situation | `semaphore` |
|---|---|
| Idle, sitting in the main event loop | **0** |
| Inside one `callback()` handling an event | **1** |
| A *second* `callback()` runs while the first is still on the stack | **2** |

When does a second callback run while the first is still on the stack? Exactly the
Part-3 situation: a handler opened a dialog, the dialog's *nested* event loop is
pumping, and a new mouse event arrives — Tk calls `callback()` **again**, on top
of the still-parked first one. That's a genuinely re-entrant call, and it's
dangerous: the inner callback could start a "move" gesture while the outer one
thinks it's mid-something-else, corrupting shared state.

So all through `callback()` you find guards like this — about **seventy** of them:

```c
if(xctx->semaphore >= 2) break;     /* don't run this gesture: we're re-entrant */
```

Read in plain English: *"If we're nested two or more callbacks deep, do not start
this side-effectful operation."* That is a completely reasonable safety rule.

> **▶ Level up — re-entrancy is the single-threaded cousin of a data race.**
> You don't need two threads to corrupt shared state. If function `f` mutates a
> global, and partway through it does something that causes `f` to be called again
> (a callback, a signal handler, a recursive event dispatch), the second `f` sees
> the global half-updated. The classic defenses are the same as for locks: a
> "busy" flag or a depth counter checked at the top. `xctx->semaphore` is that
> depth counter.

---

## Part 5 — The overload: one counter, two meanings

Now we can see the bug forming. The form needed the canvas to *ignore* most input
while it was open. The author reached for the tool already lying around — the
re-entrancy counter — and **bumped it on purpose**:

```tcl
xschem set semaphore [expr {[xschem get semaphore] + 1}]   ;# property_form.tcl, on open
...
xschem set semaphore [expr {[xschem get semaphore] - 1}]   ;# on close
```

The intent: "raise the count so the `>= 2` guards trip and the canvas stops
reacting." And it worked — too well. But notice what just happened conceptually.
The counter now means **two different things at once**:

1. *"A callback is genuinely nested inside another"* (the original, correct
   meaning — a real re-entrancy hazard).
2. *"A modal-ish dialog is open"* (the new, bolted-on meaning).

This is **concept overloading**: a single variable encoding two independent ideas.
It's seductive because it's cheap — no new field, no new code — and it usually
*works* for the case you tried. The bug always hides in the **overlap**, where the
two meanings disagree about what should happen.

> **▶ Level up — give each concept its own name.**
> When one variable answers two different questions, every reader (including
> future-you) has to guess *which* question a given test is asking. "Is
> `semaphore >= 2`?" now means "are we re-entrant **or** is a dialog open?" — and
> those need *different* responses. The fix for overloading is almost always:
> **split the concept into two named pieces of state**, then handle each on its
> own terms. We'll see that the form already *had* a second name available, which
> made the cure clean.

---

## Part 6 — The obvious fix, and why it was wrong

The issue, when filed, proposed the natural fix: *the form bumps the semaphore, so
stop bumping it.* Remove the `+1`. Done?

This is where the tutorial earns its keep. **We did not just delete the line and
ship it.** We ran an *audit*: trace what actually holds the lock, line by line,
before changing anything. And the audit found the obvious fix to be insufficient —
for a reason that is invisible until you draw the call stack.

Go back to Part 3. When the form is launched by pressing `Q`, the launching
`callback()` is **still on the stack**, parked in `tkwait`. By the rule in Part 4,
that parked frame is *holding* a `+1` on the semaphore (it incremented on entry
and hasn't reached its decrement, because it hasn't returned). So:

```
baseline while the form is open  =  1 (parked callback)  +  1 (the form's explicit bump)  =  2
a new canvas click then nests    =  3
```

Now remove only the form's explicit `+1`:

```
baseline                         =  1 (the parked callback, all by itself)
a new canvas click then nests    =  2   ← STILL trips every `>= 2` guard!
```

The canvas is **still frozen**. The explicit `+1` was a *red herring* — it was
redundant on top of the real culprit, which is the **blocked call stack** from
Part 3. The launching callback never returned, and *that* is what pins the
baseline above zero.

> **▶ Level up — verify the cause; don't pattern-match the symptom.**
> "The form raises the semaphore, so the semaphore is the problem" is a plausible
> *story*, and a smart person wrote it down. It was wrong because it stopped one
> step too early. The discipline that saves you: before fixing, **reproduce the
> exact value of the relevant state and account for every contributor to it.** Here
> that meant asking "what are *all* the things adding to `semaphore` right now?" —
> and discovering the parked frame was one of them. A two-line experiment (print
> the semaphore from a timer while the form is open) would have shown `2`, not the
> `1` the story predicted.

---

## Part 7 — The actual fix: make the form non-blocking

If the real lock is "the launching callback can't return because it's stuck in
`tkwait`," then the fix is to **not block** — drop the nested event loop entirely:

```tcl
proc slickprop::edit_form {txtlabel} {
    ...
    toplevel .dialog
    ...
    raise .dialog          ;# float it in front once, so it isn't born hidden
    return                 ;# <-- M2: NO tkwait. Return immediately.
}
```

With no `tkwait`, `edit_form` returns the instant the widgets are built. Control
flows back down the chain: `edit_symbol_property` returns, `callback()` returns,
its exit `semaphore--` runs, and the baseline drops to **0**. The form window
keeps existing on its own — Tk windows don't vanish when the proc that created
them returns. From then on, every canvas event runs at `semaphore == 1`, the
`>= 2` guards never trip, and **the whole canvas is live** while the form floats.

Look at what we *didn't* touch: **not one of the ~70 `semaphore >= 2` guards
changed.** They were never wrong. They mean "skip while re-entrant," and now that
the baseline is 0, they correctly fire *only* on genuine nesting. The audit's
real payoff was discovering that the fix has a **tiny blast radius**: change one
thing (stop blocking), and seventy guards quietly start behaving.

> **▶ Level up — the best fix often deletes code and touches little.**
> A junior instinct is to add a special case ("if a form is open, allow this") to
> each of the seventy guards. That's seventy chances to get it wrong, and it
> re-entrenches the overloaded meaning. The audit pointed at the *source* of the
> bad state instead of its seventy *symptoms*. When you find yourself about to
> edit many sites the same way, stop and ask: **is there one upstream cause I could
> fix instead?**

### "But wait — doesn't the modal form need to block to return a result?"

Excellent objection, and it's the reason this fix is *safe* rather than just
*effective*. A modal `edit_form` used to work like a function: open, block, and
when it returns hand back "the user clicked OK with these values." If it returns
immediately, who applies the edit?

The answer was already built (in earlier work): the form applies its changes
**while it is open**, by calling a command `xschem apply_properties …` from its
own OK/Apply buttons. The C side that launches the form (`edit_symbol_property`,
for the instance case) had *already* been written to ignore the old return value
and read a separate flag instead. So the blocking return carried **no information
anyone still depended on**. We could drop it for free.

> **▶ Level up — a contract is what lets you change an implementation safely.**
> We could yank out `tkwait` only because the *contract* between the form and its
> C caller had already moved from "return a value" to "apply via a side command."
> Always know your contract — the precise promise between two pieces of code —
> because it tells you exactly what you're allowed to change underneath without
> anyone noticing. Change the implementation, honor the contract.

---

## Part 8 — Cleaning up the side effects of "blocking"

Removing `tkwait` had two ripples, each a small lesson.

**(a) Cleanup that used to run "after the blocking line" now has no home.** Code
written after `tkwait` used to run when the dialog closed. With `tkwait` gone,
that code would run *immediately* (wrong) or never. The fix: move close-time
cleanup **to the close handlers themselves** — `slickprop::ok` and
`slickprop::cancel`, the procs the buttons actually call. They already cleared a
flag and saved the window geometry; we moved the "remove the variable trace" line
there too.

> **▶ Level up — put teardown where the thing actually ends.**
> "Run cleanup after the blocking call" is a code smell once the call stops
> blocking. Tie teardown to the real lifecycle event (the window closing), not to
> a line that *happened* to execute at the right time because something above it
> blocked.

**(b) The "selection changed" notification lost its hook.** Previously, the form
learned about canvas clicks through a special branch that only ran *because* the
semaphore was `>= 2` (`callback.c`, the `button1 && semaphore >= 2` block). Now
that the form runs at `semaphore == 1`, that branch never fires — a normal click
goes through the *normal* selection path instead. So we **relocated** the
notification to the end of the normal button-release handler, guarded by a plain
boolean "is the form open?":

```c
/* src/callback.c, end of handle_button_release() */
if(tclgetboolvar("slickprop_form_open")) tcleval("slickprop::on_selection_changed");
```

Notice this guard uses a **dedicated, honestly-named flag** — `slickprop_form_open`
— not the overloaded counter. That's Part 5's lesson applied: the question "is the
form open?" now has its own variable, separate from "how deep is the callback
nesting?".

> **▶ Level up — feature flags beat clever reuse of unrelated state.**
> When you need to know "is X happening?", a boolean named `is_x_happening` is
> almost always better than inferring it from some counter that happens to have a
> distinctive value during X. The boolean says what it means; the counter makes
> the next reader reverse-engineer your intent.

---

## Part 9 — Testing something that blocks (and the "green ≠ exercised" rule)

How do you write an automated test for a form that — *before your fix* — blocks
the whole interpreter the moment you open it? If your test just calls
`edit_form`, the test itself hangs forever.

The trick we used is worth stealing. A GUI toolkit's "wait" pumps the event loop,
so **timers still fire while you're blocked.** Schedule a callback *before*
opening the form; it runs from inside the (blocking) nested loop, inspects the
state, records it, and closes the form to unblock:

```tcl
# Pre-fix: edit_prop BLOCKS here. The timer fires from inside its nested loop,
# captures the semaphore + window state, then closes the form to release us.
# Post-fix: edit_prop returns instantly with the form open; we capture in-line
# and cancel the unfired timer. Either way the test cannot hang.
set safe [after 1500 { ...capture state...; slickprop::cancel }]
catch {xschem edit_prop}
if {[winfo exists .dialog]} { ...capture state... }   ;# post-fix path
catch {after cancel $safe}
```

Two of the assertions were written to **fail on purpose** before the fix existed —
this is **RED-first** development:

- *"the semaphore is 0 while the form is open"* — fails (it was the inflated
  value) before the fix, passes after.
- *"the form is a plain window with no transient owner"* — fails before, passes
  after.

We committed those failing tests **first** (the "RED" commit), then implemented
until they went green (the "GREEN" commit). Watching a test flip from fail to pass
is the only way to *know* the test actually checks the thing you changed.

> **▶ Level up — a test you never saw fail is a test you don't trust.**
> A green test proves nothing on its own — it might be green because it never
> exercises your code, or asserts something trivially true. The cheap insurance:
> see it **red for the right reason first**, then make it green. (Its cousin:
> *sabotage testing* — deliberately reintroduce the bug and confirm the suite goes
> red. If it doesn't, your test is hollow.)

There was also a real-world wrinkle worth naming, because you'll hit its like.
Under this project's display server (WSLg), **stale timers from earlier tests
queued up and fired inside our form's event loop**, corrupting the capture. The
fix was a one-liner at the top of each test — *drain the pending timer queue
before opening the form*:

```tcl
foreach id [after info] { catch {after cancel $id} }
```

> **▶ Level up — a shared event loop is shared mutable state.**
> Timers, idle callbacks, and pending events are global to the loop. One test's
> leftover `after` can fire during the next test. Treat the event queue like any
> other shared resource: leave it clean, or clean it before you rely on it.

---

## Part 10 — The shape of the whole fix, in one picture

Before (modal-ish, frozen canvas):

```
event loop
 └─ callback()  sem 0→1
     └─ edit_symbol_property()
         └─ edit_form → tkwait  ──┐   nested loop runs the form
                                  │   PARKED: callback() never returns
   a canvas click arrives here ───┘   → callback() re-enters → sem 2 (or 3)
                                       → every `>= 2` guard trips → canvas dead
```

After (modeless, live canvas):

```
event loop
 └─ callback()  sem 0→1
     └─ edit_symbol_property()
         └─ edit_form → builds window, RETURNS        ← no nested loop
     callback() returns, sem 1→0                       ← stack fully unwound
 (form floats on its own; flag slickprop_form_open = 1)
 a canvas click → callback() sem 0→1 → guards see 1 → everything works
 (release → if form open, notify it of the new selection)
```

The entire bug and its fix live in the difference between those two diagrams: **a
call stack that wouldn't unwind versus one that does.**

---

## Part 11 — Takeaways you can carry anywhere

1. **Modal = control flow, not looks.** A dialog is modal because something is
   running a loop that won't return until it closes.
2. **Single-threaded GUIs survive on "handlers return fast."** The instant one
   blocks, the UI freezes — even though "nothing crashed."
3. **A blocked call stack is paused, not finished** — and every parked frame is
   still holding whatever it grabbed (here, a `+1`).
4. **Beware overloaded state.** One variable encoding two concepts hides bugs in
   the overlap. Split it; name each piece.
5. **Audit before you cut.** Account for *every* contributor to the bad state. The
   obvious cause was real but insufficient; the actual cause was invisible until
   we drew the stack.
6. **Prefer the upstream fix with the small blast radius.** We changed one thing
   and seventy guards started behaving — instead of patching seventy guards.
7. **Know your contract** — it's the license to change an implementation safely.
8. **RED-first, then green; sabotage to be sure.** A test you never saw fail is a
   test you can't trust.

If you internalise one sentence, make it this: **when a fix feels obvious, spend
five minutes proving the cause before you spend an hour on the cure.**

---

*Source map (all on branch `slick-property-forms`): the re-entrancy counter and
its guards — `src/callback.c` (entry `++` ~5568, exit `--` ~5672, the `>= 2`
guards throughout, the relocated selection hook at the end of
`handle_button_release`); the form — `src/property_form.tcl`
(`slickprop::edit_form`, `::ok`, `::cancel`); the C launcher and the apply
contract — `src/editprop.c` (`edit_symbol_property`, `apply_instance_properties`);
the tests — `tests/property_form/body.tcl` (PF60–PF64). Design record:
`doc/claude/code_analysis/modeless_form_M2_decision.md`. Issue: `doc/claude/issues/0009-…md`.*
