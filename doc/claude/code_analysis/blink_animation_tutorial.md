# Making things blink — a tutorial on animation loops, dirty rectangles, and testable time

*How we made highlighted nets in XSCHEM blink on and off, and what that small
feature teaches about the parts of interactive graphics that beginners almost
never get told: that **time is not frames**, that you must **erase before you
draw**, that a render gate which is "always on" will **leak into code paths you
forgot existed**, and that **time-dependent code is untestable until you make
the clock an input**. Written for a CS student or game designer who can write a
loop but has never had to paint a moving picture sixty times a second.*

This is a teaching companion to `doc/claude/specs/net_hilight_styles.md` (the feature spec)
and `doc/claude/suggestions/plan_net_hilight_styles.md` (the plan; see its "Pass 2"
section). It is a sibling to `doc/claude/code_analysis/hover_highlight_tutorial.md`, which
covers the *static* overlay; this one adds *time*. All code is real and lives in
`src/hilight.c`, `src/draw.c`, `src/scheduler.c`, and `src/xschem.tcl`; line
numbers were read from source and are reproducible.

The feature is trivial to *describe* — "a highlighted wire flashes on and off" —
and that is exactly why it is a good teacher. Almost everything hard about it is
invisible in the description. We will spend the whole document on the invisible
parts.

---

## Part 0 — The one-sentence idea

> A blinking highlight is a tiny game loop: a clock you read in real time, a
> rule that turns the clock into "show / hide", a way to **un-draw** the last
> frame before drawing the next, and a way to **stop** when there is nothing
> left to animate — all without melting the CPU or breaking the parts of the
> program that never asked for animation.

Every clause in that sentence is a section below. If you build a game, a chart
that updates live, a progress spinner, a typing cursor that blinks, or a CAD
tool, you will write something with this exact shape.

---

## Part 1 — Where highlights live, and why blinking is hard

XSCHEM draws a schematic with **double buffering**. It does not paint shapes
straight onto the visible window. It paints them onto an off-screen image (a
"pixmap" — think of it as a hidden canvas the same size as the window), and then
copies that whole image to the screen in one fast block transfer. In
`draw.c` the copy is literally one call:

```c
MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, ...);   /* draw.c:1704 */
```

Double buffering is the single most important trick in interactive graphics.
Without it, the user sees the picture being built up shape by shape — flicker.
With it, the user only ever sees finished frames. Every game engine, every GUI
toolkit, every browser does this. (If you've used OpenGL, `SwapBuffers` /
`glfwSwapBuffers` is the same idea; in a browser it's the compositor.)

Net highlights are painted **into that same off-screen pixmap**, layered on top
of the schematic, by `draw_hilight_net()` in `hilight.c`. There is no separate
"highlight layer" kept aside — the highlight pixels and the wire pixels are
mixed together in one image.

That one design fact is the source of *all* the difficulty. Stop and think about
what "make the highlight disappear for the off-phase of a blink" actually
requires:

- The highlight is **not** a sprite floating above the scene that you can simply
  hide. It is paint that has already been mixed into the canvas, on top of — and
  obscuring — the wire underneath.
- To make it vanish, you cannot "remove" it. **There is nothing to remove.** You
  must *repaint the wire that was underneath it*, which means repainting that
  region of the schematic from scratch.

This is **the erase problem**, and it is the heart of the feature. A beginner
imagines blinking is `if (off) dont_draw_highlight()`. That only works on the
very first frame. On every subsequent frame the highlight is *already on the
canvas from last frame*, and "not drawing it again" leaves it exactly where it
was. To turn it off you must actively erase it by redrawing what it covered.

> **Transfer to games.** This is identical to sprite animation on a framebuffer
> without hardware compositing. To move a sprite you must (1) restore the
> background where the sprite *was*, then (2) draw the sprite where it *is*. The
> 1980s term is "blitting with background save/restore." Modern engines hide this
> behind a scene graph that re-renders every frame, but the obligation never
> went away — it just moved. The moment you cache rendered pixels (a pre-rendered
> tilemap, a baked light map, a UI surface you don't redraw every frame) the
> erase problem comes straight back.

---

## Part 2 — Time is not frames

Here is the mistake every beginner makes with animation:

```c
int frame = 0;
while (running) {
    frame++;
    if ((frame / 30) % 2 == 0) show_highlight();   /* WRONG */
    render();
}
```

"Blink every 30 frames." The bug: **frames are not a unit of time.** If the
machine is fast you blink too quickly; if it's loaded you blink too slowly; if
another window steals the CPU the blink stutters. The animation's *meaning*
("blink twice a second") is tied to the *speed of the loop*, which is an
accident of the hardware and the moment.

The fix, which professional engines call **delta-time** or **wall-clock**
animation, is to drive animation from a real clock, not from a frame counter.
Read the actual time; compute the visual state as a pure function of that time.
Then the same wall-clock second always means the same thing no matter how many
times you happened to redraw during it.

In our feature, the clock is `net_hilight_now_ms()` (`hilight.c:2458`):

```c
double net_hilight_now_ms(void)
{
  Tcl_Time t;
  if(xctx->net_hilight_test_active) return xctx->net_hilight_test_ms;   /* (Part 7) */
  Tcl_GetTime(&t);
  return (double)t.sec * 1000.0 + (double)t.usec / 1000.0;
}
```

Ignore the first line for now (it is the testing hook — Part 7). The real body
asks the operating system "what time is it, in milliseconds?" We deliberately do
*not* use the C standard `time()`, because it has one-second resolution and a
blink needs sub-second precision. We use Tcl's portable `Tcl_GetTime` so the
same code works on Linux and Windows.

### The duty-cycle rule

Given a real time `now` (ms) and a blink period `blink_ms`, is the highlight
*on* or *off* right now? `net_hilight_style_on_now()` (`hilight.c:2468`):

```c
int net_hilight_style_on_now(NetHilightStyle *st, double now)
{
  double half;
  if(!st || st->blink_ms <= 0) return 1;             /* 0 = "never blinks" = always on */
  half = st->blink_ms / 2.0;
  return fmod(floor(now / half), 2.0) < 0.5;
}
```

The idea: chop time into slices of length `half` = half the period. Slice 0 is
on, slice 1 is off, slice 2 is on, slice 3 is off… `floor(now / half)` is *which
slice we're in*; its parity (even/odd) is the on/off state. A "50% duty cycle":
equal time on and off. (Want a highlight that's on 90% of the time and winks off
briefly? That's a different duty cycle — same structure, different threshold.
Turn-signal indicators, cursor blinks, and "low battery" LEDs are all just
duty-cycle choices.)

Notice the guard `blink_ms <= 0 → return 1`. A non-blinking style is just the
degenerate case "always on." We did **not** write a separate code path for
steady highlights; we made steady a special value of the same rule. Collapsing a
special case into a parameter of the general case is a recurring win — fewer
branches, fewer bugs.

### The overflow trap (a real bug we shipped and caught)

Our first version wrote the parity the "obvious" way:

```c
return (((long)(now / half)) & 1L) == 0L;            /* the bug */
```

Cast the slice index to an integer and test its low bit. It worked on the
author's 64-bit Linux box. A code review flagged it as broken on Windows, and
the reviewer was right. Here's why, and it's a lesson worth internalizing:

`now` is milliseconds **since 1970**. Today that is about 1.75 × 10¹² — about
1.75 *trillion*. Divide by `half` (say 250) and you still have ~7 × 10⁹, seven
*billion*. On Windows (and any "ILP32 / LLP64" platform) a `long` is **32 bits**,
whose maximum is about 2.1 billion. Seven billion does not fit. The cast is
out-of-range, the result is garbage, and the parity bit — the entire point — is
random. The blink would freeze or stutter on exactly the platform the project
promises to support.

The fix is to never put an epoch-scale number into a fixed-width integer. Stay in
floating point, where `double` holds 53 bits of integer precision (≈9 × 10¹⁵,
plenty), and take the parity with `fmod`:

```c
return fmod(floor(now / half), 2.0) < 0.5;           /* overflow-proof */
```

> **Lessons that transfer.** (1) **Wall-clock, not frame count** — the
> foundational rule of animation; in Unity it's `Time.time`, in a game loop it's
> your accumulated `dt`. (2) **Epoch time overflows 32-bit integers** — this is
> the same family as the Year-2038 problem, which is a genuine deadline for
> 32-bit `time_t`. When a value can be "absolute time since 1970," respect how
> big it is. (3) **Your machine is not the only machine** — `long` being 64 bits
> is a property of *your* compiler, not of C. Portable code states its width
> assumptions (`int32_t`, `int64_t`) or avoids them (stay in `double`).

---

## Part 3 — Erase by repainting: the dirty rectangle

Back to the erase problem from Part 1. To turn a highlight off we must repaint
the region it covered. The naive solution is "just redraw the whole screen every
frame." That works and it is what a typical 3D game does (it rebuilds the entire
frame from scratch 60+ times a second). But for a 2-D CAD tool with a large
schematic and an otherwise *static* picture, redrawing everything 20 times a
second to flash one wire is wasteful and visibly flickery.

The classic answer is the **dirty rectangle**: redraw only the small region that
actually changed, not the whole screen. XSCHEM already has the machinery for
this; it's used for moving and pasting objects. The pattern is four calls
(`select.c`, used all over `actions.c`):

```c
bbox(START, …);     /* begin accumulating a bounding box */
bbox(ADD,   x1,y1,x2,y2);   /* grow it to include this rectangle (schematic coords) */
bbox(SET,   …);     /* install that box as the GPU/Xlib clip region */
draw();             /* redraw — but pixels outside the clip are left untouched */
bbox(END,   …);     /* restore the full-screen clip */
```

`bbox(SET)` sets a **clip rectangle**: a promise to the graphics system that
"everything I draw next is confined to this box; leave the rest of the canvas
alone." So `draw()` runs its normal full-scene logic, but only the pixels inside
the box are actually written. Repaint the schematic there (which erases the old
highlight by covering it with the real wire), let the highlight logic repaint the
*current* phase, and copy just that region to the screen.

Our animation frame, `draw_hilight_region()` (`hilight.c:2555`), is exactly this
once you strip the bookkeeping:

```c
  marg = xctx->cadhalfdotsize + (INT_BUS_WIDTH(xctx->lw) * (double)maxw) / (2.0 * xctx->mooz);
  xctx->in_hilight_anim_frame = 1;                   /* (Part 6) */
  bbox(START, 0.0, 0.0, 0.0, 0.0);
  bbox(ADD, x1u - marg, y1u - marg, x2u + marg, y2u + marg);   /* union of the blinking nets */
  bbox(SET, 0.0, 0.0, 0.0, 0.0);
  draw();
  bbox(END, 0.0, 0.0, 0.0, 0.0);
  xctx->in_hilight_anim_frame = 0;
```

Two details worth your attention, because both are general:

**The margin.** We don't clip to the exact wire endpoints; we grow the box by
`marg`. A thick highlight is a fat line whose edges stick out past the wire's
center-line, and round endpoint "dots" stick out past the endpoints. If the clip
box were tight, those few pixels would be left un-erased — a faint ghost outline
of the old highlight. The margin is "half the widest highlight, plus a dot
radius." **Always grow a dirty rectangle by the size of the thing you're
drawing**, never by zero. (This is also why `bbox(SET)` itself adds a line-width
pad internally; we chose `SET` over its inward-shrinking sibling `SET_INSIDE` for
exactly this reason — see the plan's discussion. A dirty rect that's slightly too
big costs a few wasted pixels; one that's too small leaves trails.)

**The union.** When several nets blink we don't issue one clip per net — the clip
hardware here is a single rectangle. We compute one box that contains *all* the
blinking nets and redraw that. If they're scattered across the screen the box is
large (and we redraw more than strictly necessary), but it is always *correct*.
Correct-and-sometimes-wasteful beats clever-and-occasionally-wrong; the tighter
multi-rect version is a later optimization, not a launch requirement.

> **Transfer.** "Dirty rectangles" is the canonical 2-D optimization. Old
> Windows sent `WM_PAINT` with an invalid-region rectangle and you were expected
> to repaint only that. Game UIs, terminal emulators (which redraw only changed
> character cells), and `react`'s reconciler ("only re-render the components
> whose inputs changed") are all the same instinct: *find the smallest region
> that changed and touch only that.* The hard part is never the redraw — it's
> computing the dirty region correctly, including the margins.

---

## Part 4 — The loop that schedules itself (and knows when to die)

Something has to call `draw_hilight_region()` repeatedly. That something is the
**animation loop**. XSCHEM's core is single-threaded and event-driven (a Tcl/Tk
GUI), so we don't spawn a thread; we use the GUI toolkit's timer: `after N ms,
run this command`. The trick — used by Tk, by JavaScript's `setTimeout`, by any
event-loop UI — is a callback that **reschedules itself**:

```tcl
proc net_hilight_anim_tick {win} {                    ;# xschem.tcl:455
  ...guards...
  if { [catch {xschem redraw_hilight_region $win} r] || $r == 0 } return
  set net_hilight_after($win) [after $net_hilight_tick_ms [list net_hilight_anim_tick $win]]
}
```

The last line says "in `net_hilight_tick_ms` (50) milliseconds, call me again."
Each tick does one frame and arms the next. This is a loop made of
self-perpetuating timer events instead of a `while`. (In a browser you'd write
`requestAnimationFrame(tick)` at the end of `tick`; same shape.)

Two things make this *good* rather than a CPU bonfire:

**It paces, it doesn't spin.** The tick fires at most every 50 ms — a 20 Hz cap.
The blink *cadence* (how fast it flashes) comes from `blink_ms` in the
duty-cycle rule, not from how often the tick runs. **Decouple your update rate
from your animation rate.** A 20 Hz heartbeat can drive a 1 Hz blink, a 0.5 Hz
blink, and a fast 5 Hz alarm blink all at once — each net reads the same shared
clock and decides for itself.

**It is self-terminating.** Look at the guard: if `xschem redraw_hilight_region`
returns 0, the proc `return`s *without* rescheduling — the loop simply stops. The
C side returns 0 to mean "nothing here animates anymore." So when the user clears
the last blinking highlight, the next tick discovers there's nothing to do and
the loop quietly dies. **A timer you start must have a condition under which it
stops, and that condition must be checked by the timer itself** — otherwise you
have leaked a forever-running timer, the single most common bug in event-loop
code.

The mirror image is *starting* the loop. After any operation that might have
added a blinking highlight, the C core calls `net_hilight_anim_update()`
(`hilight.c:2588`), which asks the Tcl side to (re)evaluate whether a timer
should be running. You can see the call sites peppered through `hilight.c` —
after styling a net (`:2246`), after un-highlighting (`:2280`), after a
highlight-by-name (`:1408`):

```c
  net_hilight_anim_update(); /* Pass 2a: a blinking style may have just been applied */
```

Start logic and stop logic must be **symmetric** and they must funnel through
**one** place. We did not scatter `after cancel` across the codebase; every
start/stop decision goes through `net_hilight_anim_update`, which is the single
owner of the timer's lifetime. (Precedent: XSCHEM's existing
`update_process_status` self-rescheduling poll at `xschem.tcl:515`. When you find
a pattern already in the codebase, copy its shape — reviewers and future readers
recognize it.)

> **Transfer.** Self-rescheduling timers are everywhere: `setTimeout`-driven
> polling, game "coroutines," OS kernel timer wheels, the cron-like schedulers in
> CI systems. The two laws are always the same: (1) **every start needs a
> stop**, owned in one place; (2) **the loop checks its own liveness each tick**
> so it can't outlive its reason to exist.

---

## Part 5 — Don't repaint what didn't change

A 1 Hz blink changes appearance exactly **twice** a second (on→off, off→on). But
our tick fires 20 times a second. If every tick did a full regional redraw, 18
of those 20 would repaint pixels that are *identical to what's already on
screen* — pure waste, and on a slow machine, visible stutter.

So before redrawing, the frame asks: **did anything actually change since last
time?** This is **change detection**, and the cheap way to do it is a
**signature** (a small fingerprint of the current state). If this frame's
signature equals last frame's, nothing visible changed — skip the redraw.

We fold every blinking net's current on/off state into one integer
(`hilight.c:2503`, inside the shared scan of Part 9):

```c
    *sig = *sig * 1000003u + (unsigned int)(st->index * 2 + net_hilight_style_on_now(st, now));
```

This is a **rolling hash** (`hash = hash * prime + next_item`) — the same
technique behind string hashing and Rabin–Karp substring search. Each net
contributes its style id and its current phase; the accumulated number is a
fingerprint of "what all the blinking nets look like right now." Then
(`hilight.c:2567`):

```c
  if(sig == xctx->net_hilight_anim_sig) return 2;   /* no blink edge since last frame */
  xctx->net_hilight_anim_sig = sig;
  ...redraw...
```

Same signature → return early, no redraw. Different signature → a blink edge
happened → repaint and remember the new signature. Now a 1 Hz blink causes 2
redraws a second, not 20, while the tick still runs at 20 Hz so it reacts within
50 ms of any edge. **Poll often (cheap); act rarely (expensive).**

### The sentinel collision (a subtle bug, caught by sabotage testing)

There's a trap hiding here that took a real debugging session to corner. We
start the signature accumulator at a specific nonzero seed (`hilight.c:2559`):

```c
  unsigned int sig = 2166136261u;   /* FNV offset basis */
```

Why not start at 0, the obvious choice? Because `xctx->net_hilight_anim_sig`
starts at 0 too — that's its "no frame has ever been drawn" sentinel value (the
context is zero-initialized). And it turned out that one specific real state — a
single net with style index 0 in its off phase — hashed to **exactly 0**. So the
"current signature" collided with the "nothing drawn yet" sentinel, the
comparison `sig == stored` was accidentally true, and the very first erase got
skipped. The highlight would get stuck *on* during what should have been its
first off-phase.

Seeding the hash with a nonzero constant (here the
[FNV](https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function)
offset basis, a well-known good starting value) guarantees a real signature is
never 0, so it can never be confused with the empty sentinel.

> **The general bug: an in-band sentinel.** Using a value from your normal data
> range (0) to *also* mean "no data" is a classic mistake. SQL invented `NULL`
> precisely so "no value" lives *outside* the value range. The same trap bites
> C strings (is `\0` data or terminator?), "return -1 for not-found" (what if -1
> is valid?), and floating-point `NaN`. **Your sentinel must be a value the real
> data can never take.** When it can't be (you need every bit pattern), carry a
> separate "is-valid" flag instead.

---

## Part 6 — Don't let the gate leak (the most important lesson here)

Now the subtle, architectural part — and the one with the best war story,
because the first version got it wrong and a code review caught three separate
symptoms of the same root mistake.

The blink "gate" is the line inside `draw_hilight_net` that skips an off-phase
net:

```c
if (anim_on && !net_hilight_style_on_now(st, anim_now)) continue;   /* skip: it's off */
```

The first version computed `anim_on` like this:

```c
anim_on = has_x && tclgetboolvar("net_hilight_animate");   /* the leak */
```

Read that carefully. It says: *whenever animation is globally enabled, gate the
highlight on every draw.* That sounds right. It is badly wrong, because
`draw_hilight_net` is called by **every** redraw in the program, not just by our
animation tick:

- **Exporting a PNG** calls `draw()` (`draw.c:128` sets `do_copy_area=0` then
  draws). If the wall-clock happened to be in an off-phase at the instant you
  exported, your saved image would silently **omit the highlight you explicitly
  turned on**. A file written to disk must be *deterministic* — it cannot depend
  on what millisecond you clicked "export."
- **Panning or zooming** while a net blinks triggers an ordinary full redraw. If
  that redraw landed on an off-phase, the highlight would blink off — and if no
  further animation tick happened to fire (say you're mid-drag, which pauses the
  tick), it would **stay** off until something else repainted. The highlight
  looks broken.

Three reported symptoms (PNG export, interactive redraw, plus a stuck state),
**one** root cause: *a behavior meant for one narrow context (animation frames)
was active in every context.* The gate leaked.

The fix is to make the gate ask not just "is animation enabled?" but "**am I
actually rendering an animation frame right now?**" We added a one-bit flag to
the context, `in_hilight_anim_frame`, and set it *only* around the `draw()`
inside `draw_hilight_region` (you saw it in Part 3). The gate now reads
(`hilight.c`, in `draw_hilight_net`):

```c
 anim_on = 0;
 if((xctx->in_hilight_anim_frame || xctx->net_hilight_test_active) &&
    has_x && tclgetboolvar("net_hilight_animate")) {
   anim_on = 1;
   anim_now = net_hilight_now_ms();
 }
```

Now an ordinary redraw — a pan, a zoom, a PNG export — has
`in_hilight_anim_frame == 0`, so `anim_on` stays 0, so **every highlight renders
steady**, exactly as before the feature existed. Only the animation tick, which
sets the flag for the duration of its one `draw()`, sees the gate. The blink is
produced by the tick *toggling that region* between an on-frame and an off-frame;
the rest of the program never blinks anything.

> **The general principle: scope a behavior to its context.** A feature that
> mutates how a shared function behaves must announce *when* that mutation
> applies, and default to "off" everywhere else. This is why thread-local state,
> React's render-phase flags, "am I inside a transaction?" booleans, and
> graphics "render pass" tags all exist. When you add a mode to a function that
> a hundred callers share, the question is never just "what does my mode do?" —
> it's "what happens to the other ninety-nine callers?" The leak bug is what
> happens when you forget to ask.

A second, cheaper benefit fell out of this design. Because the gate is now behind
a one-bit C-field check (`in_hilight_anim_frame`), an ordinary redraw of a
highlighted schematic pays **zero** extra cost — no clock read, no Tcl variable
lookup — until it's genuinely an animation frame. The original "read a Tcl
variable on every single redraw" was a real tax on the hot path (panning a big
schematic redraws constantly). **Put the expensive check behind the cheap one.**
Order your conditions cheapest-first; let the common case bail out before it
touches anything slow.

---

## Part 7 — Make time an input, or you can't test it

Code that reads the wall clock is, by default, **untestable**. "Render the
off-phase and assert the highlight is gone" — but the off-phase happens at a
millisecond *you don't control*. Run the test twice and you sample different
phases. This is the same reason `Math.random()`-dependent code and
`Date.now()`-dependent code are notoriously flaky to test.

The cure is one of the most useful ideas in software design: **don't let the
function fetch the thing it depends on — let the thing be handed to it.** Make
the clock an *input* you can override. That's the first line of
`net_hilight_now_ms` we skipped in Part 2:

```c
  if(xctx->net_hilight_test_active) return xctx->net_hilight_test_ms;
  ...real wall clock...
```

A test sets `net_hilight_test_active` and a fixed `net_hilight_test_ms` (via the
command `xschem net_hilight_test_now <ms>`, `scheduler.c:4338`), and now "now" is
whatever the test says. The test can render an on-phase frame at `now = 0`, an
off-phase frame at `now = 300`, compare the two PNGs, and prove the gate works —
**deterministically**, every run. This is exactly how we verified the feature:

```
ON  (now=0):   red highlight present
OFF (now=300): highlight gone, bare wire shows through    ← proves the gate fires
```

That comparison is the discipline this codebase calls *green-but-hollow*
checking (`doc/claude/code_analysis/`-wide): don't trust a feature because the test is
green; **sabotage it and watch the test notice.** We forced the off-phase and
watched the highlight vanish; then forced the kill-switch and watched it stay
steady at the *same* timestamp. Two renders that differ only by the variable
under test, proving that variable is the cause.

> **The general technique has two names.** Engineers call it **dependency
> injection** (pass the dependency in, don't reach out for it); the testing
> literature calls the override a **seam**. A controllable clock is the textbook
> example — `java.time.Clock` exists for precisely this, as does
> `jest.useFakeTimers()`. The day you make `now()` an input instead of a global
> reach-out is the day your time-dependent code becomes testable. Game replays
> and lockstep multiplayer rest on the same foundation: if the whole simulation
> is a pure function of (inputs, time), you can record it, replay it, and verify
> it.

### A footnote bug: the boolean that ate the third state

One more tiny bug, because it's a perfect cautionary tale. `draw_hilight_region`
returns **three** values — 0 (stop the loop), 1 (redrew), 2 (no change, keep
ticking). The first wiring of the command did this:

```c
Tcl_SetResult(interp, draw_hilight_region() ? "1" : "0", ...);   /* the bug */
```

The `? :` collapses *any* nonzero result to `"1"`. So 2 ("no change, keep
ticking") came back as 1 ("redrew") — the tri-state silently flattened to a
boolean, and the change-detection of Part 5 looked broken in testing even though
the C logic was perfect. The fix was to emit the integer verbatim (`my_itoa`).
**When a function grows from two states to three, hunt down every place that
assumed two.** A boolean coercion is an easy, invisible place for the third state
to die.

---

## Part 8 — One scan, two questions (don't compute the same thing twice)

Two functions needed to walk the highlighted nets: the predicate "should the
timer be running at all?" (`net_hilight_has_animation`, `hilight.c:2537`) and the
frame itself ("redraw the blinking nets," `draw_hilight_region`). The first draft
wrote the wire-and-instance walk *twice*. A reviewer pointed out the obvious
hazard: two copies of "which highlighted objects animate" must be kept in
lock-step forever, and the day someone updates one and forgets the other
(especially when Pass 2b adds marching-ants animation to the predicate), the
timer will say "animate!" while the frame draws nothing, or stop while a net
still blinks.

The fix is a **single source of truth**: one helper does the walk and *optionally*
produces each output, with `NULL` meaning "I don't need that one"
(`scan_animating_hilights`, `hilight.c:2491`):

```c
static int scan_animating_hilights(double now, unsigned int *sig, int *maxw,
                                   double *bx1, double *by1, double *bx2, double *by2)
```

The predicate calls it with all-`NULL` (it only wants the count). The frame calls
it with real pointers (it wants the signature, the widest line, and the bounding
box). One walk, two callers, **zero** opportunity to drift. The tick was likewise
collapsed from two C calls per frame (one to ask "should I animate?", one to
draw) into a single call whose tri-state return answers both — fewer round trips,
and the decision is a byproduct of the work instead of a separate scan.

> **Transfer.** "Don't compute the same thing twice, and don't encode the same
> rule in two places" (DRY — Don't Repeat Yourself) is most valuable not for
> saving keystrokes but for removing the chance that two copies *disagree*.
> Optional out-parameters (or a small result struct) are the standard way to let
> one routine serve callers that each want a different slice of its work.

---

## Part 9 — The whole loop, in one breath

Putting the parts together, here is the life of a blink:

1. The user highlights a net with a blinking style. The highlight is painted into
   the off-screen pixmap and shown (Part 1).
2. That action calls `net_hilight_anim_update()`, which starts the self-scheduling
   Tcl timer for this window (Part 4).
3. Every 50 ms the timer calls `draw_hilight_region()` (Part 4).
4. The frame reads the real clock (Part 2), walks the blinking nets once to
   compute a phase signature and their union bounding box (Parts 5, 8).
5. If the signature matches last frame, it returns "no change" and the timer just
   reschedules — no repaint (Part 5).
6. On a blink edge, it sets the `in_hilight_anim_frame` flag, redraws *only* the
   dirty rectangle (erasing the old phase by repainting the wire, then drawing
   the new phase), clears the flag, and copies that region to the screen
   (Parts 3, 6).
7. Meanwhile every *other* redraw in the program — pan, zoom, PNG export — has the
   flag clear, so highlights render steady there (Part 6).
8. When the user clears the highlight, the next tick finds nothing animating,
   returns 0, and the loop stops (Part 4).

Eight steps, and every one of them is a transferable idea. That's why a feature
you can describe in six words took this long to teach.

---

## Part 10 — The concepts, and where you'll meet them again

| In this feature | The general name | You'll see it again in |
|---|---|---|
| Highlights live in the pixmap; to hide one you repaint the wire | **The erase problem / background restore** | sprite blitting, cached UI surfaces, terminal redraw |
| Blink driven by `Tcl_GetTime`, not a frame counter | **Wall-clock / delta-time animation** | every game loop, CSS animations, physics integration |
| `(now/half)` parity for on/off | **Duty-cycle / phase math** | PWM, LED indicators, cursor blink, audio LFOs |
| Epoch ms overflowing 32-bit `long` | **Integer overflow / Y2038** | timestamps, counters, hashing, `time_t` |
| Redraw only the union box, not the screen | **Dirty rectangles / partial invalidation** | WM_PAINT, React reconciliation, damage tracking |
| A `after`-callback that re-arms itself | **Self-scheduling timer / animation loop** | `requestAnimationFrame`, `setTimeout` polling, kernel timers |
| Every start has a stop, in one owner | **Resource lifetime / no leaked timers** | RAII, `useEffect` cleanup, subscription disposal |
| Skip the redraw when the signature is unchanged | **Change detection / memoization** | React `memo`, build caches, `make`, dirty flags |
| Nonzero hash seed vs the 0 sentinel | **In-band sentinel collision** | `NULL` vs 0, `NaN`, "-1 means not found" |
| Gate active only inside an animation frame | **Scoping behavior to a context** | render passes, thread-local state, transaction flags |
| Override the clock from a test | **Dependency injection / test seams** | fake timers, `Clock` abstractions, replay systems |
| Tri-state return, not a boolean | **Don't flatten your state space** | enums over bools, status codes, result types |
| One scan serves predicate and frame | **Single source of truth / DRY** | shared validators, one query many views |
| Force off → highlight vanishes | **Sabotage / mutation testing** | mutation testing, fault injection, chaos engineering |

If you remember one thing: **the description of an interactive-graphics feature
tells you almost nothing about its difficulty.** "Make it blink" hides a clock,
an erase, a dirty rectangle, a lifecycle, a hot path, and a testability problem.
The craft is in seeing those before they bite you — and in having reviewers and
sabotage tests catch the ones you didn't.

---

*Further reading in this repo: `doc/claude/code_analysis/hover_highlight_tutorial.md` (the
static overlay and the render hot path), `doc/claude/code_analysis/modeless_forms_tutorial.md`
(event loops and re-entrancy), `doc/claude/specs/net_hilight_styles.md` (the feature spec),
and the "Pass 2" section of `doc/claude/suggestions/plan_net_hilight_styles.md` (the plan,
including why blink was built before marching-ants as the lowest-risk way to lay
this shared foundation).*
