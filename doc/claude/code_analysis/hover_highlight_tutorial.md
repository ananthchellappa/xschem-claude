# Drawing on a moving target — a tutorial on render loops, transient overlays, and input routing

*How we made XSCHEM highlight the object under your cursor — a "Cadence-style"
awareness cue — and what it teaches about double-buffering, immediate-mode
overlays, the cost of the hot path, how windowing systems route the mouse, and
building features by composition.*

This is a **teaching** companion to the design record
(`doc/claude/code_analysis/hover_highlight_decision.md`) on branch
`feature/hover-highlight`. It is written for someone who can already write a
program that *computes* something, but has never had to write a program that
*paints sixty times a second while the user is moving the mouse*. That second
kind of program — interactive graphics — has its own physics, and this small
feature is a clean place to learn them. All code is real; line references were
read from source.

Sidebars marked **▶ Level up** lift each concrete detail to the general idea so
you can carry it to any GUI, game engine, or visualization you build later.

> Companion read: `doc/claude/code_analysis/modeless_forms_tutorial.md` taught the *control
> flow* of a GUI (event loops, blocking, re-entrancy). This one teaches the
> *rendering* and *input* side. Together they're a decent first course in "how a
> desktop app actually works."

---

## Part 0 — The feature, in one sentence

When your mouse hovers over a wire or a component in the schematic, that object
gets a faint dashed-yellow outline — a quiet signal that *the editor knows where
you are*. Cadence (the industry tool) does this; it makes the canvas feel alive
and precise. We wanted it too: mild, dashed, yellow, thin, configurable, and — a
specific request — it must keep working **even when the schematic window is not
the active window** (you're in another app, but your pointer is over the
schematic).

Sounds cosmetic. It's actually a tour through the core mechanics of interactive
graphics.

---

## Part 1 — The thing nobody tells you: the screen is redrawn constantly

A program that prints a number computes it once and stops. A program that *draws*
a schematic has to answer, continuously: "given the current state (objects, zoom,
pan, selection, mouse position), what pixels go on the screen **right now**?" When
the state changes — you pan, you select, you move the mouse — the answer changes,
so the picture is recomputed. That recompute is **rendering**, and the function
that does it in XSCHEM is `draw()` (`src/draw.c`).

Two render philosophies exist, and you need to know both:

- **Retained mode:** you build a model of objects, and a framework redraws them
  for you when needed. (HTML/DOM, scene graphs.)
- **Immediate mode:** *you* issue the draw calls, every frame, yourself. (Most
  game engines, and XSCHEM's Xlib drawing.)

XSCHEM is immediate mode: `draw()` walks every wire, instance, rectangle… and
issues line/box/text draw calls into the X server. Our hover outline has to fit
into that world.

> **▶ Level up — "what's on screen" is a pure function of state.**
> The mental model that makes graphics tractable: `screen = render(state)`. Bugs
> are usually either (a) the state is wrong, or (b) `render` and the state
> disagree because you patched pixels without updating state (or vice-versa). Keep
> render a function of state, and keep your *transient* patches honest about what
> state they assume — that second clause is the whole hover story.

---

## Part 2 — Double buffering: why there's a hidden copy of the screen

If you draw a complex schematic shape-by-shape directly onto the visible window,
the user sees it *assemble* — flicker, tearing, ugliness. The fix every graphics
system uses is **double buffering**: draw the whole frame into an off-screen
buffer, then copy the finished buffer to the screen in one shot. The user only
ever sees complete frames.

XSCHEM's off-screen buffer is a **pixmap** called `xctx->save_pixmap`. Look at how
the low-level draw helpers target it (`draw.c`): when `xctx->draw_pixmap` is set,
they draw into `save_pixmap`; when `xctx->draw_window` is set, they draw onto the
visible window. Normal rendering draws into the pixmap, then blits it to the
window.

This backing pixmap is the secret weapon for our feature. It is a **clean copy of
the schematic without any hover outline on it.** That means: to *erase* a hover
outline from the screen, we don't need to know what was underneath — we just copy
that patch of `save_pixmap` back over it. The truth is always one blit away.

> **▶ Level up — keep a clean copy of "the world without the cursor decoration."**
> Transient, cursor-following decorations (hover, crosshair, drag rectangles,
> selection marquees) are *not* part of the document. If you keep a rendered copy
> of the document alone, you can stamp decorations onto the screen and remove them
> by restoring from that copy — no "undo the exact pixels I drew" bookkeeping. This
> is the oldest trick in interactive graphics and it still wins.

---

## Part 3 — The hot path: why we must NOT just call `draw()`

The naive implementation of hover: "on every mouse move, figure out what's under
the cursor and call `draw()` so it repaints with the outline." It would even
work. And it would be wrong.

Mouse-move events (`MotionNotify`) arrive **a lot** — dozens per second as you
sweep across the canvas. `draw()` re-renders the *entire* schematic: every wire,
every component, every piece of text. On a big design that's milliseconds of work.
Do it on every motion event and the canvas turns to molasses; the highlight lags
behind the cursor, which destroys the very "the editor knows where I am" feeling
we're chasing.

This is the **hot path** problem: code that runs on every event must be cheap.
The rule:

> Per-frame work must be proportional to what *changed*, not to the size of the
> whole scene.

What changes on a mouse move? At most two objects: the one you just left, and the
one you just entered. So the right cost is "redraw two outlines," not "redraw ten
thousand objects."

> **▶ Level up — know your event frequency before you choose an algorithm.**
> An O(n) operation is fine once per click and fatal once per motion event. Before
> writing a handler, ask: *how often does this fire?* Click (rare) → almost
> anything goes. Motion / scroll / per-frame (constant, fast) → touch only what
> changed. The same line of code is "fine" or "a bug" depending purely on its call
> frequency.

---

## Part 4 — Immediate-mode transient overlay: the diff-and-patch dance

XSCHEM already had a feature with exactly this shape: the **crosshair**
(`draw_crosshair`, `callback.c`). Studying it gave us the pattern. Here is the
distilled technique for any cursor-following overlay:

1. **Draw to the window only, never the backing pixmap.**
   `xctx->draw_pixmap = 0; xctx->draw_window = 1;`
   The outline is now *on the screen* but *not* in `save_pixmap`. The backing copy
   stays a pristine "document without decoration."
2. **Remember what you drew.** Store the object you outlined
   (`xctx->hover_type/hover_n/hover_col`).
3. **On the next motion, diff.** Find what's under the cursor now. If it's the
   same object as last time, **do nothing** — the screen is already correct.
4. **If it changed: erase the old, draw the new.** Erase by re-stroking the *old*
   shape with a special GC (`xctx->gctiled`) whose paint source is `save_pixmap` —
   i.e. "stamp the clean background back over exactly the pixels I dirtied." Then
   stroke the *new* object's shape with the hover GC.

That's `draw_hover()` (`callback.c`). The core is short:

```c
if (hover enabled && mouse_inside && not mid-gesture && not busy)
    newsel = find_closest_obj(mousex, mousey, 0);   // what's under the cursor?
else
    newsel = nothing;

if (!force && newsel == previously_drawn) return;   // (3) nothing changed — bail

draw_pixmap = 0; draw_window = 1;                    // (1) window-only
if (previously_drawn)                                // (4a) erase old
    draw_hover_shape(gctiled, prev_type, prev_n, prev_col);
if (newsel)                                          // (4b) draw new
    draw_hover_shape(gc_hover, newsel.type, newsel.n, newsel.col);
remember(newsel);                                    // (2)
```

Two details that look small and are not:

**The early-return in step 3 is the performance.** Most motion events keep you
over the *same* object (or the same empty space). The diff makes those events
nearly free — we don't touch the screen at all. We only pay when you actually
cross a boundary. That is the "proportional to what changed" rule made real.

**Erasing can damage neighbors.** When we stamp the background back over the old
outline, we might also wipe part of the *selection* highlight or the property-
form *scope* highlight — because those are window-only overlays too (same trick).
So after erasing, `draw_hover()` re-strokes them. The crosshair code does the same
dance (it re-strokes the selection after erasing). Window-only overlays form a
little stack, and whoever erases must repair the ones below.

> **▶ Level up — a screen patch is shared mutable state.**
> Several features paint onto the same window pixels without going through the
> backing buffer (hover, crosshair, selection, drag rectangle). They *coexist* on
> the glass. The discipline that keeps them from corrupting each other: erase only
> your own marks, and repair anything you overpaint. It's the graphics version of
> "leave shared state the way you found it."

---

## Part 5 — Reuse: the feature is mostly old code

Here's a senior-engineering point worth dwelling on. We wrote very little *new*
geometry. The hard part of an outline is "what's the shape of this object?" — a
bounding box for an instance, a line segment for a wire, an arc for an arc, a
text's font-extent box for a label. That per-type dispatch **already existed**, in
`draw_scope_highlight()` (the property editor's "these are the objects I'll edit"
outline, from earlier work). We had two things to borrow:

- the **per-type shape dispatch** (from `draw_scope_highlight`), and
- the **window-only erase/redraw mechanism** (from `draw_crosshair`).

So `draw_hover_shape()` (`draw.c`) is a near-twin of `draw_scope_highlight`'s body,
with one deliberate change: it takes a live array **index** instead of a stable
**id**. The scope highlight holds objects across time (a dialog stays open while
the document changes), so it stores durable ids and re-resolves them. Hover
re-finds its object *every single motion*, so the index is fresh by construction —
no id machinery needed. Choosing the *simpler* identity model because the lifetime
is shorter is the kind of judgment that keeps code small.

We also hardened it: `draw_hover_shape` bounds-checks every index, so a stale
reference (say the object got deleted) is a silent no-op instead of a crash.

> **▶ Level up — new features are mostly recombinations.**
> The instinct of an inexperienced engineer is to build the new thing from
> scratch; the instinct of an experienced one is to ask "what already does 80% of
> this?" Hover = `draw_scope_highlight`'s shapes + `draw_crosshair`'s mechanism +
> a thin orchestrator. Recognizing that two existing patterns compose into the new
> requirement is most of the design.

---

## Part 6 — When the document repaints under your feet

There's a seam between our two worlds. Hover lives **on the window only**; it is
not in `save_pixmap`. So the moment a *real* `draw()` happens — you pan, you zoom,
you select something — it blits the (hover-free) backing pixmap to the window and
**our outline vanishes.** The cursor hasn't moved, but the highlight is gone. That
feels broken.

The crosshair has the same problem and the same fix: at the very end of `draw()`,
after the document and the selection are on screen, it re-draws itself. We do the
same — the tail of `draw()` (`draw.c`) now reads:

```c
draw_selection(...);          // document's selection overlay
draw_scope_highlight();       // property-editor scope overlay
xctx->hover_type = 0;         // the redraw wiped our window-only outline: forget it
draw_hover(1);                // re-establish it at the current pointer (force)
if (draw_crosshair_enabled) draw_crosshair(7, 0);
```

Two subtleties:

- We **reset `hover_type = 0` first.** That variable means "what outline is
  currently *on the glass*." A full redraw just erased the glass, so the honest
  value is "nothing." If we skipped this, the next motion's diff would try to
  "erase" an outline that's already gone and get confused. **State must match
  reality.** (Recall Part 1: bugs come from render and state disagreeing.)
- We pass `force = 1`, because after the reset the "did it change?" diff would say
  "no" (nothing → nothing-found-again is not a change) and skip the redraw. Force
  says "draw it regardless."

> **▶ Level up — every cache needs an invalidation story.**
> `hover_type` is a tiny cache of "what's painted." Like every cache, it is only
> correct if it's invalidated whenever the underlying thing (the window pixels)
> changes out from under it. Most caching bugs are missing-invalidation bugs. When
> you add a cache, write down *who clears it* — here, the full redraw clears it.

---

## Part 7 — Input routing: why hover works on an unfocused window (for free)

The headline requirement: hover must track even when the schematic window is
**not the active/focused window**. People expected this to be the hard part. It
turned out to be free, and the reason is a genuinely useful fact about how
windowing systems work.

There are two different concepts that beginners conflate:

- **Keyboard focus** — which window receives *keystrokes*. Exactly one window has
  it.
- **Pointer location** — which window the mouse is physically *over*. Independent
  of focus.

In X11 (the Unix windowing protocol), **`MotionNotify` events are delivered to the
window the pointer is over, regardless of which window has keyboard focus.** So if
your pointer is in the schematic while another app is focused, the schematic still
receives motion events — and our hover handler runs. No special code required. The
proof it already worked: the crosshair (same motion path) already tracked on an
unfocused window.

The one precondition we *did* have to respect: XSCHEM only tracks while the
pointer is genuinely inside the canvas, a flag `xctx->mouse_inside`. That flag is
set on an **`EnterNotify`** event (pointer crossed into the window) and cleared on
**`LeaveNotify`** (pointer left). So hover is bracketed by enter/leave, not by
focus — which is exactly the behavior we wanted.

> **▶ Level up — focus ≠ "the window the mouse is in."**
> Almost every windowing system separates *focus* (keyboard) from *pointer
> location*, and delivers pointer/motion events by location. Internalize this and a
> whole class of "why does my hover/tooltip work/not work when the window isn't
> active?" questions answers itself. (It's also why you can scroll a background
> window with the wheel on many systems.)

This same fact bit us in **testing**, in an instructive way — next part.

---

## Part 8 — Testing the invisible

How do you write an automated test for "an outline appears under the cursor"?
There are no eyes in a test harness, and the outline is pixels. Two moves make it
testable.

**Move 1: expose the *state*, not the pixels.** We added a read-only command,
`xschem hover`, that returns *which object the editor currently thinks is hovered*
(or empty). The pixels are a consequence of that state; if the state is right and
the drawing code is exercised, the pixels follow. So the test asserts on the state:

```tcl
motion_to 200 100                 ;# move the cursor over a wire we placed
check "hover reports the wire" {[dict get [xschem hover] type] eq "wire"}
```

**Move 2: drive the *real* input path.** Rather than calling an internal function,
the test synthesizes genuine motion events through the same entry point Tk uses:
`xschem callback .drw 6 <x> <y> …` (event 6 = `MotionNotify`). That exercises the
actual handler, not a test-only shortcut — so the test can't pass while the real
path is broken.

To place the cursor over a known object, the test reverses the screen↔schematic
transform (`mx = (schem_x + xorigin) / zoom`, read live via `xschem get
xorigin/zoom`). It also asserts the negatives — empty space clears the hover, the
config flag gates it, and an in-progress gesture suppresses it — because a cue
that fires when it *shouldn't* is as wrong as one that fails to fire.

**The bug the test caught — and the lesson in it.** First run: the "hover a wire"
and "hover an instance" checks failed, while every "should be empty" check passed.
That asymmetry is a clue, not a coincidence: it means detection was *never*
running — always returning "nothing." The cause was Part 7's precondition.
`mouse_inside` is set by `EnterNotify`, and a synthesized `MotionNotify` had never
been preceded by an `EnterNotify`, so the editor believed the pointer was outside
the canvas and skipped hover entirely. The fix was to make the test send an enter
event first — exactly what a real window manager does when your pointer crosses
into the window:

```tcl
xschem callback .drw 7 100 100 0 0 0 0   ;# EnterNotify (event 7): "pointer is now inside"
```

> **▶ Level up — real input arrives in sequences with invariants.**
> Hardware/OS events aren't independent; they come in lawful orders (enter →
> move… → leave; press → drag → release). Code downstream relies on those
> invariants ("I only track while inside"). When you *synthesize* events in a test,
> you must honor the same grammar, or you test a state the real system never
> produces. The failing-asymmetry ("only the positive cases fail") is also worth
> remembering — it pointed straight at "detection never ran."

> **▶ Level up — green-but-hollow.** Note we wrote these tests *failing first*
> (RED), watched them go green only after the code existed, and the debugging
> above accidentally proved the positive checks *discriminate* (they went red when
> detection didn't run). A test you've never seen fail for the right reason is not
> yet evidence. (More in `doc/claude/suggestions/green_but_hollow_tests.md`.)

---

## Part 9 — The C/Tcl seam: where "config" actually lives

The request included "the line weight should be a config variable." XSCHEM splits
along a classic boundary: a **C engine** (fast drawing, geometry) and a **Tcl
layer** (the GUI, preferences, scripting). Config values live as Tcl variables and
are *read* by C when it draws. So three variables were declared with defaults in
the Tcl layer (`xschem.tcl`):

```tcl
set_ne hover_highlight 1            ;# on by default
set_ne hover_highlight_color yellow
set_ne hover_highlight_width 1      ;# screen pixels; minimum
```

and the C side reads them when it configures the drawing "pen" (the GC), in
`build_colors()` (`xinit.c`): color via `XSetForeground`, and — to make it
*dashed* — `XSetLineAttributes(..., LineOnOffDash, ...)` plus `XSetDashes(...)`.
`set_ne` = "set if not already set," so a user's config file can override a default
before it's applied. Change the variable, re-read, re-draw — no recompile.

> **▶ Level up — separate policy from mechanism.**
> "What color / how thick / on or off" is *policy*; "stamp a dashed line of that
> color over that shape" is *mechanism*. Putting policy in editable config (Tcl)
> and mechanism in fast code (C), with a thin read-bridge between, is a pattern you
> will see everywhere (config files + engine, CSS + render engine, flags +
> binary). It lets users and tests change behavior without touching the engine.

---

## Part 10 — Putting it together: the life of one mouse move

You sweep the mouse one pixel to the right, from over wire A to over instance B.
Here is the whole machine in motion:

```
X server: pointer moved over .drw  →  MotionNotify delivered (focus irrelevant)
  Tk binding:  xschem callback .drw 6 <x> <y> …
    callback() → handle_motion()
      … (no gesture in progress, not busy, mouse_inside = true) …
      draw_hover(0):
         newsel = find_closest_obj(here)         → instance B
         B != A (the remembered one) → proceed
         draw_pixmap=0; draw_window=1            → paint to glass only
         erase A:  stroke A's bbox with gctiled  → stamps clean background back
         repair:   re-stroke selection + scope overlays A may have covered
         draw  B:  stroke B's bbox with gc_hover → dashed yellow on glass
         remember B
      draw_crosshair(2)                          → crosshair stays on top
```

Cheap, local, flicker-free, and it works whether or not the window is focused.
Every design choice in this tutorial is visible in those fifteen lines.

---

## Part 11 — Takeaways you can carry anywhere

1. **`screen = render(state)`.** Keep rendering a function of state; most graphics
   bugs are state and pixels disagreeing.
2. **Double buffering gives you a free "erase."** Keep a clean backing copy of the
   document; restore from it to remove any transient decoration.
3. **Mind the hot path.** Work on a per-motion/per-frame handler must be
   proportional to what *changed*, not to scene size. Diff, then patch.
4. **Transient overlays are a shared-pixel stack.** Erase only your marks; repair
   what you overpaint.
5. **Every cache needs an invalidation owner.** `hover_type` ("what's painted") is
   reset by the full redraw that wipes the glass.
6. **Focus ≠ pointer location.** Windowing systems route motion by where the
   pointer *is*; that's why hover works on an unfocused window for free.
7. **New features are recombinations.** Ask "what already does most of this?"
   before writing anything.
8. **Test the invisible by exposing state and driving real input** — and honor the
   event grammar (enter before move) when you synthesize it.
9. **Policy in config, mechanism in the engine,** with a thin read-bridge.

If you keep one image, keep this: a clean off-screen copy of the world, and a thin
layer of cursor-following decoration stamped on the glass above it — drawn when
you cross a boundary, wiped by restoring from the copy. That single idea powers
hover highlights, crosshairs, selection marquees, drag previews, and rubber-band
boxes in nearly every interactive editor ever written.

---

*Source map (branch `feature/hover-highlight`): orchestrator + window-only
erase/redraw — `src/callback.c` (`draw_hover`, hooked in `handle_motion`, erased
on `LeaveNotify`; modeled on `draw_crosshair`); per-type outline geometry —
`src/draw.c` (`draw_hover_shape`, sibling of `draw_scope_highlight`; the
re-establish at the end of `draw()`); the pen (GC) + dashed style + config read —
`src/xinit.c` (`gc_hover` in `create_gc`/`build_colors`); hit-test —
`src/findnet.c` (`find_closest_obj`); the test seam — `src/scheduler.c`
(`xschem hover`); config defaults — `src/xschem.tcl` (`set_ne hover_highlight*`);
the test — `tests/headless/test_hover_highlight.tcl`. Design record:
`doc/claude/code_analysis/hover_highlight_decision.md`.*
