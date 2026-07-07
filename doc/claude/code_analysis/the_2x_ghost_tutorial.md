# The ghost at 2×: a tutorial on temporary lies and the events that catch them

*A worked lesson in one of the quietest bug families in all of software —
state that is wrong for only a moment — told through a real rendering bug we
fixed in a 25-year-old C program (XSCHEM, a circuit schematic editor), and
connected to the places you will meet the same shape again: interrupt handlers,
React re-renders, game loops, `async`/`await`, and every "critical section" you
will ever write.*

Audience: a CS student who has written some C or Java, knows what a global
variable and a function call are, and has never seen this codebase. Every
example is self-contained. You do not need to know what a schematic is — think
"a drawing program where you drag boxes around and lines stay attached to them."

The fix, when we finally found it, was about **twenty lines and conceptually
one idea**. Finding it took the better part of an afternoon, and reasoning about
the code by reading it — *static analysis*, done by a human — was confidently
wrong twice before a screenshot settled the argument. That gap, between how small
the fix is and how hard it was to *locate*, is the real lesson. So we spend most
of our time not on the fix but on **why the bug was invisible to reading the
code**.

---

## Part 0 — The one-sentence idea

> **A value that is only *temporarily* wrong is still a real bug — if anything
> else can read it during the moment it is wrong.** In an event-driven program,
> "anything else" quietly includes work you never asked for: a window repaint, a
> hover, a timer. You did not call it. It ran *after* you returned, and it read
> what you left behind.

That is the whole tutorial. The rest is making you feel it in your bones.

---

## Part 1 — The symptom

You grab a resistor with the mouse and drag it. The resistor follows your
pointer, exactly as it should. But a **second, greyed-out copy of the resistor**
appears — floating out ahead, at *twice* the distance you dragged.

Drag from (0,0) to (5,0), and the ghost sits at (10,0). Always double. Let the
mouse go and it vanishes.

```
   start          you dragged here        ghost appears here
     R  ───────────────►  R  ───────────────►  R (grey)
     0                    δ                     2δ
```

The drawing is not *wrong* in any way that matters to the circuit — no wires
break, the saved file is fine. It just looks broken. And "looks broken on every
single drag" is not something you can ship.

---

## Part 2 — Where a moving thing lives (the setup that makes the bug possible)

To drag something smoothly, almost every editor keeps the moving object's
position in **two pieces**:

1. its **committed position** — where the object officially *is* (call it `x0`); and
2. a **pending delta** — how far the mouse has moved since you grabbed it
   (call it `deltax`).

What you see on screen is the sum: **`drawn = x0 + deltax`**.

During a normal drag this split is clean and the two pieces never overlap:

| | committed `x0` | pending `deltax` | `drawn` |
|---|---|---|---|
| grab | 0 | 0 | 0 |
| dragging | 0 (unchanged) | δ | δ |
| release | δ (now baked in) | 0 (reset) | δ |

The object stays put at `x0=0` the whole drag; only `deltax` grows; at release
we "commit" — fold the delta into `x0` and zero the delta. At every instant,
**exactly one of the two pieces carries the offset.** That is an *invariant*: a
promise the code makes to itself. Nobody wrote it down, but every drawing routine
quietly depends on it.

Hold onto that table. The bug is entirely a story about breaking that last
promise.

---

## Part 3 — The feature that broke the promise

Our editor grew a fancier drag mode ("fluid editing"): instead of waiting for you
to release the mouse, it re-routes the attached wires *live*, on every little
step of the drag. To do that, each step it does something new — it **commits the
move immediately**, mid-drag:

```c
inst.x0 = inst.x0 + deltax;   /* fold the delta into the real position, NOW */
```

So now, in the middle of a drag, the object is *already* at `x0 = δ`.

But here is the catch. When you finally release the mouse, the release code
computes the total move by reading `deltax` — it *expects the delta to still be
there*. If we zero it, release thinks you moved nothing and the object jumps back
to the origin. So the live-commit code deliberately **leaves `deltax = δ`**, even
though it just folded that same δ into `x0`.

Read the invariant table again. We have just entered the one state it forbids:

| | committed `x0` | pending `deltax` | `drawn = x0 + deltax` |
|---|---|---|---|
| **fluid mid-drag** | δ | δ | **2δ**  ← both pieces carry the offset |

The offset is now stored **twice**. Anyone who draws with the plain formula
`drawn = x0 + deltax` will place the object at **2δ**. The ghost is not a mystery.
It is arithmetic.

> **Lesson 1 — redundant state is a liability you must actively manage.** The
> same fact (how far the object moved) now lives in two places. That is tolerable
> *only* if every reader knows the new rule ("the delta is already in `x0`; don't
> add it again"). The instant one reader still believes the old rule, the fact
> gets counted twice. This is the **Single Source of Truth** principle, and its
> cousin **DRY** — which, note, was never about code alone: DRY is about
> *knowledge* having one authoritative home, and a position *is* knowledge.
> Databases call the discipline *normalization*; your accountant calls it *not
> entering the same invoice in two ledgers and then summing both*.

---

## Part 4 — "But we handled that!" — the local guard that wasn't enough

The author of the fluid code *knew* about the double-count. Right where the live
commit happens, the code carefully does this before it repaints:

```c
double saved_dx = deltax, saved_dy = deltay;
deltax = 0; deltay = 0;      /* the offset is already in x0; don't double it */
draw();                      /* repaint: now drawn = x0 + 0 = δ.  Correct! */
draw_selection(SEL);         /* the grey overlay: also correct at δ */
deltax = saved_dx; deltay = saved_dy;   /* put it back so release still works */
```

On the frame this code runs, the ghost lands exactly on the real object —
invisible. Perfect. This is *why*, when we first read the code, we concluded the
bug could not exist here. The guard is right there. The math checks out. We were
sure the overlay was drawn coincident.

We were sure, and we were wrong. Twice.

Look at the last line. It **restores** `deltax = δ` and then the function
*returns*. For the entire time between this frame and the next mouse step, the
program sits in the forbidden state: `x0 = δ` **and** `deltax = δ`. The house is
left untidy, and the door is unlocked.

> **Everyday picture.** You tidy the living room, then walk out to the car,
> leaving the *rest* of the house a mess and the front door open. Ninety-nine
> times out of a hundred, nobody comes by. The bug is the hundredth time — a
> visitor arrives while you are at the car and sees the mess. The fluid code
> tidied one room (`deltax = 0`) exactly while *it* was looking, then messed it up
> again and walked out. It never asked whether anyone else might come in.

---

## Part 5 — The knock: work you did not call

Something *does* come in. In any windowed program, the operating system repaints
your window whenever it decides to — you dragged another window off of it (an
"Expose" event), the pointer hovered, a blinking cursor ticked, a menu closed.
Each of those calls the program's master redraw routine, `draw()`. And `draw()`,
dutifully, repaints the moving object's overlay with the plain, honest formula
from Part 2:

```
   drawn = x0 + deltax
```

Now evaluate it in the forbidden state — `x0 = δ`, `deltax = δ`:

```
   drawn = δ + δ = 2δ
```

There it is. The ghost at 2δ is drawn by a repaint that fired **in the gap
between two drag steps**, when the delta was momentarily double-booked. The
fluid code's guard was real — but it only protected the redraws *it* triggered.
It could not protect the redraw the *operating system* triggered, because by then
the fluid step had already returned, with the state left broken.

Notice the precise shape, because it is *not* the shape people first assume:

- The mutating step is **completely finished**. Its call has returned; its stack
  frame is gone. Nothing is running "in the middle" of it.
- Later — a separate, independent event — the repaint handler runs and reads a
  global (`deltax`) that the earlier step left in a **broken resting state**.

> **Lesson 2 — an invariant left broken *between* units of work is a bug, even in
> a single-threaded program where nothing runs "in the middle" of your function.**
> This is the family of *broken invariant observed across event-loop turns*.
> It has two branches, and it is worth keeping them straight:
> - **Preemptive** — something interrupts you *mid-update*: an interrupt handler
>   fires between two writes and reads a torn value; another thread observes a
>   half-finished struct. Fixed with atomics, disabled interrupts, or a mutex —
>   because the danger is a reader running *during* your update.
> - **Cooperative** — nothing runs during your function, but you **return** with a
>   shared invariant still broken, and a *later* handler reads it. `async`/`await`
>   (every `await` is a yield point where other tasks run) and the event loop in
>   this bug live here. There is nothing to "lock" — no one is racing you — the
>   fix is to *not leave the shared state broken across the yield*, or to make
>   every reader tolerant of it.
>
> Our bug is the **cooperative** branch: single-threaded Xlib, no thread, no
> interrupt — just a global left dirty across a turn of the event loop.

---

## Part 6 — Why *reading the code* could not find this

Two honest attempts to reason it out from the source concluded "the overlay is
coincident; no bug here." Both were correct *about the code they were reading* —
the fluid commit tail really does zero the delta around its own draw. The bug was
not in the path we were staring at. It was in a **different control path
entirely** — an OS repaint — that the mutating code never mentions and never
calls, and that therefore never shows up when you trace outward from the drag
logic.

That is the trap of event-driven systems, and it has a name: **inversion of
control**. You do not call the framework; the framework calls you, on its own
schedule, from a place that is nowhere in your call graph. You cannot `grep` for
"the operating system decides to repaint your window." It arrives from *outside*
the story you are reading.

So we stopped arguing with the screenshot and **measured**. We added a few print
statements — log `deltax`, `x0`, and the drawn position every time the overlay
drew during a move — built, and drove the drag in a real window while forcing an
extra repaint mid-drag. The log said, in black and white:

```
COMMIT step:      deltax=40   inst.x0 committed to 40
  overlay draw:   x0=40  deltax=0    drawn=40     <- the guarded frame: correct
=== force a repaint here (mimics an OS Expose) ===
  overlay draw:   x0=40  deltax=40   drawn=80     <- the 2δ ghost, caught red-handed
```

> **Lesson 3 — when your mental model and reality disagree, reality wins;
> go measure.** A screenshot, a log line, a debugger watchpoint. Static reasoning
> is indispensable, but it reasons about the paths you *think* run.
> Instrumentation reports the paths that *actually* ran — including the one that
> arrives from outside your call graph. Two wrong deductions cost more than the
> ten minutes of print-debugging that ended the argument. Reach for the
> measurement sooner.

---

## Part 7 — The fix, and why *this* shape and not another

We had two families of fix.

**Tempting but wrong: shrink the window.** "Just don't restore the delta," or
"commit `x0` differently so the plain formula happens to cancel." These try to
make the forbidden state last a shorter time, or to make the arithmetic work out
in one spot. They are whack-a-mole: they fix the redraws you can see and leave
the state globally inconsistent for the redraws you cannot. Any *new* caller of
`draw()` reintroduces the ghost.

**Right: make every reader of the shared state see a consistent value.** The real
statement of correctness is:

> *Whenever the geometry already includes the move delta, the overlay must draw
> with delta = 0 — no matter who triggered the draw.*

That sentence is conditioned on a **state**, not on a **place**. So we attach the
rule to the state, at the one door every overlay draw must pass through — the
`draw_selection` function itself — and we already had a flag that means exactly
"the geometry is live-committed": `fluid_reroute_dirty`.

```c
/* GC = an Xlib drawing handle; you can ignore that parameter. */
void draw_selection(GC g, int interruptable)
{
  if (xctx->fluid_reroute_dirty) {          /* geometry already holds the delta */
    double sx = xctx->deltax, sy = xctx->deltay;
    xctx->deltax = 0; xctx->deltay = 0;     /* so the overlay must NOT re-add it */
    draw_selection_impl(g, interruptable);
    xctx->deltax = sx; xctx->deltay = sy;   /* restore for the release path */
  } else {
    draw_selection_impl(g, interruptable);  /* normal drag: unchanged */
  }
}
```

Now it does not matter *who* calls the overlay — the fluid step, an OS Expose, a
hover, a future feature nobody has written yet. Every one of them passes through
this door, and the door makes the read see a consistent value based on the state,
not on the caller's good manners.

Be honest about what this fix *is*, because the honesty is the lesson. It does
**not** restore the Part-2 invariant ("exactly one of `x0`, `deltax` carries the
offset"). In fluid mode that invariant stays broken between events *on purpose* —
the release path still needs `deltax`. Instead of repairing the object model, we
add a **weaker, read-time rule** that routes *around* the broken invariant:
*whenever the geometry is committed, every overlay read treats `deltax` as 0.*
When you cannot keep the strong invariant, guarding the reads is the next best
thing — but say plainly which one you did.

Three details worth stealing:

- **The guard lives at the *read* boundary, conditioned on a state flag.** This is
  the difference between "remember to zero the delta everywhere you draw" (a rule
  humans forget) and "the draw function itself refuses to double-count while the
  dirty flag is set" (a rule the code cannot forget). Push the enforcement *down*
  to the single chokepoint every reader shares.
- **It is a wrapper, not an inline edit.** The body has early `return`s (a fast
  path, an interruptible resume). Wrapping guarantees the restore runs no matter
  which `return` fires. One caveat, so you don't over-learn it: a plain
  save/call/restore wrapper in C only survives *normal* returns — which is all
  this body has. True RAII / `try…finally` / a context manager goes further and
  also survives *exceptions and stack unwinding*. Same **instinct** (pair a change
  with its undo so control flow cannot separate them); not the same **guarantee**.
  If you port this pattern to C++ where the inner call can throw, reach for RAII.
- **It costs nothing when the feature is off.** `fluid_reroute_dirty` is only ever
  set while the new mode is active. Old behavior takes the `else` branch, byte-for-
  byte unchanged. A good guard is invisible until the state it guards occurs.

---

## Part 8 — The paradigms, named (and the takeaways)

You just watched several classic ideas collide in one twenty-line bug. Learn
their names; you will use them for the rest of your career. Each comes with the
portable rule.

1. **Single Source of Truth (and DRY for state).** One fact, one home. The offset
   lived in `x0` *and* `deltax`; the moment both were live, it was double-counted.
   → *If one fact must live in two places, name the owner and make every reader
   honor it — or it will be counted zero times or twice, never once, at the worst
   moment.*

2. **Representation invariants (Hoare, Liskov) — and their limits.** A data
   structure carries a promise about which states are legal; ours was "exactly one
   of `x0`, `deltax` carries the offset." The standard rule is that a mutator *may*
   break the invariant **inside** itself but must **restore it before returning**
   to callers. This bug returns to the event loop with it *still broken*. And the
   twist worth remembering: sometimes you *can't* restore the strong invariant (the
   release path needs the delta), so you deliberately relax it and defend the
   **reads** instead. → *Know your invariants, restore them at every boundary you
   can — and when you can't, say so and guard the readers explicitly.*

3. **Broken invariant across event dispatch — not "reentrancy."** The span where
   an invariant is broken is dangerous if *anything else can observe it*. Here
   nothing runs mid-function (single-threaded Xlib), so this is the **cooperative**
   version: state left dirty across a *turn* of the event loop and read by a later,
   independent handler. Its preemptive cousins — interrupt handlers, threads,
   torn reads — break the invariant *during* an update and need atomics or a mutex.
   The fix here is **not** a lock (there is no one to exclude); it is making the
   read tolerant of the state. → *Ask of every window where an invariant is broken:
   can anything else run "now" — where "now" includes after you return? In async,
   event-driven, threaded, or interrupt code the answer is usually yes.*

4. **Immediate-mode rendering re-reads the model every frame.** XSCHEM is an
   immediate-mode renderer: on every `draw()` it *recomputes* the picture from its
   object arrays — nothing is a retained scene graph. (During a drag it does keep a
   **cached raster** of the settled scene — a backing store / double-buffer — and
   recomputes only the moving overlay on top; that is a caching optimization, not
   "retained mode.") The trap of recompute-every-frame is that it faithfully
   reflects the model *even when the model is momentarily a lie*. → *Any system
   that rebuilds the view from the model on every frame — React, game render loops,
   spreadsheet recalculation, observers — requires the model to be consistent at
   **every** frame boundary, not just the ones you personally trigger.*

5. **Inversion of control & instrument-don't-argue.** The caller you needed to
   worry about (the OS repaint) was nowhere in your call graph — the framework
   calls you, not the reverse. Reading outward from the drag logic could never
   reach it. → *When the code says one thing and the screen says another, believe
   the screen and measure; the bug you can't find by reading is often in a caller
   that isn't in your call graph at all.*

And two rules that are pure engineering hygiene, earned above:

- **Guard invariants at the shared chokepoint, keyed on state — not at each call
  site, keyed on the programmer's memory.** Humans forget call sites. A function
  that refuses to misbehave while a flag is set does not.
- **Pair every change with its undo so control flow cannot separate them** —
  wrapper, RAII, `try/finally`, context manager. It turns "I hope every path
  restores this" into "every path restores this."

---

*Source, for the curious.* XSCHEM, branch `fluid-editing`. Symptom + fix:
`doc/claude/issues/0080-fluid-drag-offset-instance-ghost.md`, commit `bceb000d`.
The forbidden state is created in `move.c` (the live-commit tail); the overlay
is drawn by the ELEMENT case in `move.c` via `draw_temp_symbol` in `draw.c`,
reached from `draw()` on any external repaint; the fix wraps `draw_selection` in
`move.c`. One simplification made above for clarity: the real overlay offset is
written `rx1 - inst.x0 + deltax`, where `rx1` is the rotation-transformed copy of
`inst.x0`; with no rotation `rx1 - inst.x0 = 0`, so the expression reduces to the
`x0 + deltax` we used throughout. The 2× comes out identically either way.
