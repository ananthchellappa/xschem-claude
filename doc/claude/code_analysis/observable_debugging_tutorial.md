# You cannot debug what you cannot see: a field guide to observable debugging

*A lessons-learned write-up from one stubborn, multi-pass bug: "verb-noun copy/move
does not work in the symbol editor." The fix, in the end, was small. Getting there
took three passes and a handoff note that pointed at the wrong villain. This document
is about **why** it took three passes, and how to write and instrument code so the next
bug like it takes one. Running example: the Cadence-style C-copy / M-move command mode
(`doc/claude/specs/cadence_pin_name_text.md`), touching `callback.c`, `findnet.c`,
`move.c`, `scheduler.c`. Every lesson transfers to any codebase.*

Audience: a CS student or working engineer who has debugged something by adding
`printf`, has felt the specific misery of "it should work but doesn't," and wants a
mental toolkit so that misery is shorter next time. You do not need to know XSCHEM
(a circuit schematic editor written in C + Tcl/Tk). Every example is self-contained.

---

## Part 0 — The one-sentence idea

> A bug is a disagreement between what you *think* the program does and what it
> *actually* does. You cannot close that gap by thinking harder. You close it by
> making the program **show you** — cheaply, repeatedly, at the exact spot you
> suspect. Most of "debugging skill" is really **observability engineering**: the
> discipline of building the instruments *before* you need them, and of never
> trusting a claim you have not personally watched happen.

That is the whole tutorial. The rest makes you feel it, through a real bug that
punished every shortcut we tried.

---

## Part 1 — The story, in three passes

**The goal.** In the symbol editor you should be able to press **C** and copy the
selected pin; or, with nothing selected, press **C**, then click a pin, and have the
copy pick up and follow the cursor. The first flow (select-then-command) is called
*noun-verb*; the second (command-then-select) is *verb-noun*. Noun-verb already
worked. Verb-noun did not.

**The inherited diagnosis.** A handoff note from a previous session said, in effect:
*"Verb-noun is broken because on drop, `copy_objects(END)` sees `deltax == 0` —
'released without moving' — so no copy is made. The motion updates the mouse position
but the delta never reaches END."* It even recommended: *add a way to read `deltax` to
diagnose.*

**Pass 1 — read the machine, don't guess.** Instead of trusting the note, the first
move was to make the invisible visible. Four tiny getters went into the `xschem get`
dispatcher:

```c
} else if(!strcmp(argv[2], "deltax")) { /* current move/copy gesture x delta */
  my_snprintf(s, S(s), "%.16g", xctx->deltax);  Tcl_SetResult(interp, s, TCL_VOLATILE);
}
/* ... deltay, x1, x2, y1, y2 the same way ... */
```

Then a *script* drove the whole gesture through the real event path (`xschem callback
.drw <type> <x> <y> ...`) and printed the state after every event:

```
AFTER c-key:    MENUSTART=1  STARTCOPY=0  lastsel=0
AFTER press@0:  MENUSTART=1  STARTCOPY=1  lastsel=1   x1=0
AFTER motion60: STARTCOPY=1  deltax=60                x2=60
AFTER drop@60:  STARTCOPY=0  deltax=0     rects5=1  <-- copy did NOT happen
```

The note was **wrong**. `deltax` was a healthy `60` right up to the drop; the copy
machinery completed fine. The one anomaly was the *last line*: `rects5` (the number of
pins) stayed at **1**. A copy had run to completion and produced **nothing**.

**Pass 2 — follow the object, not the symptom.** So the copy engine was innocent.
Instrumenting the copy loop itself revealed the culprit in one line:

```
DBGVN  sel[0] type=4 n=0 col=4      # type 4 = LINE, layer 4
```

The gesture had faithfully copied a **line** — the pin's little stub line — not the
**pin**. Pass 2's discovery: the bug was never in copy/move at all. It was in
**selection**. A click at the pin's center was grabbing the wrong object.

**Pass 3 — understand the tie, then break it correctly.** Why did clicking a pin
select its stub line? Because a pin is really three objects stacked at the same spot
(a rect, a decorative stub line, a name label), and the selection code is a *cascade*
that checks lines before boxes and lets the first-found object win ties. The line sat
at distance 0 through the center; the box's distance metric scored the pin *farther*.
The fix taught the cascade that a click inside a pin body is distance 0, and that pins
win ties. One `if`. Verb-noun worked.

Three passes. Two of them were spent discovering that the map handed to us did not
match the territory. Everything below is how to shrink that from three passes to one.

---

## Part 2 — The lessons

### Lesson 1 — Inherited diagnoses are hearsay. Re-derive the root cause.

The handoff note was written in good faith by someone who had genuinely seen a
`deltax == 0`. But a *symptom observed once* is not a *root cause*. Conditions drift:
a different gesture path, a different config flag (`persistent_command`, `cadence_compat`),
a since-changed line of code. Treating last session's conclusion as a fact cost the
first pass.

> **Metaphor: the map is not the territory.** A prior debugger's notes are a *map*
> drawn on a previous expedition. Terrain shifts. Use the map to pick where to look
> first — never as a substitute for looking.

**Practice.** When you inherit "the bug is X," rank X as a *hypothesis*, not a
premise. The very first thing you do is build an instrument that can **confirm or
refute X directly**. Here: reading `deltax` refuted "deltax is zero" in ten minutes.
A refuted hypothesis is progress — it deletes a whole branch of the search tree.

---

### Lesson 2 — You cannot debug through a keyhole. Build the lantern.

The previous session got *stuck* for one concrete reason, stated in its own note:
*"there is no `xschem get deltax` getter."* The state that governed the bug was
**unobservable from where the tests lived.** So debugging happened by imagination,
and imagination is where wrong diagnoses breed.

The entire log-jam broke the moment six one-line getters existed. Not because the
getters *fixed* anything — they compute nothing, they only *reveal* — but because
they turned a dark room into a lit one.

> **Metaphor: don't grope through a keyhole; open the door and carry a lantern.**
> The getters are the lantern. They are cheap to make and they light up exactly the
> corner you point them at.

**Practice — leave observability seams.** For every important piece of internal
state, ask: *can a test or a REPL read this without a debugger attached?* If not, add
a read-only accessor. In this codebase the pattern already existed (`xschem get
ui_state`, `... semaphore`, `... drag_elements`); the gesture geometry (`deltax`,
`x1`, `x2`) had simply been overlooked. Read-only getters are nearly free, they never
change behavior, and each one you add is a lamp you (or the next person) will be glad
is already hanging on the wall. **Design state to be inspectable, not just correct.**

---

### Lesson 3 — Make the invisible *mechanically* reproducible.

The bug lived in a mouse gesture — press a key, click, drag, click — the kind of
thing people "test" by wiggling the mouse and squinting. Squinting does not scale and
does not bisect. The breakthrough experiment fed synthetic events straight into the
real dispatcher:

```tcl
proc sx {u} { expr {int(($u + [xschem get xorigin]) / [xschem get zoom])} }
xschem callback .drw 2 [sx 200] [sy 200] 99 0 0 0   ;# press 'c'
xschem callback .drw 4 [sx 0]   [sy 0]   0  1 0 0   ;# click pin
xschem callback .drw 6 [sx 60]  [sy 0]   0  0 0 0   ;# move
xschem callback .drw 4 [sx 60]  [sy 0]   0  1 0 0   ;# drop
puts "rects=[xschem get rects 5]"                    ;# <-- the verdict, in a number
```

Now the bug is a *function*: same input, same output, every run, no hands. You can
diff it, bisect it, sabotage it, put it in CI.

But note the honest boundary. There are two kinds of "does it work?" here:

- **The observable part** — did a pin get created? did `STARTCOPY` set? did `deltax`
  reach 60? — is fully scriptable and became `tests/headless/test_verb_noun_copy_move.tcl`.
- **The truly visual part** — does the ghost *smoothly follow* the cursor? — cannot be
  asserted by a headless script and remains a human eyeball check.

> **Metaphor: separate the *machine* from the *paint*.** Automate the machine (state,
> counts, transitions). Reserve human eyes for the paint (does it *look* right). The
> classic testing mistake is to give up on *all* of it because *some* of it is visual.
> Most of a "GUI bug" is not actually visual.

This is the same lesson as `gui_focus_and_testability_lessons.md` in this folder,
from the opposite direction: there, the *fix* could only be eyeballed; here, the
*diagnosis* could be fully scripted. Know which parts of your problem are which.

---

### Lesson 4 — The bug is rarely where the last edit was. Trace the whole pipe.

Everyone's instinct — including the handoff's — was that a *copy/move* bug lives in
the *copy/move* code. It did not. The pipeline was:

```
key press ──▶ arm command ──▶ click ──▶ SELECT object ──▶ pick up ──▶ drag ──▶ drop ──▶ COPY
                                          ^^^^^^^^^^^^^                              ^^^^
                                          the actual bug              where everyone looked
```

The copy stage was flawlessly copying whatever the *select* stage handed it. Garbage
in, garbage out — and the garbage entered two stages upstream.

> **Metaphor: a clog downstream, a leak upstream.** Water pooling by the copy stage
> doesn't mean the copy stage leaks. Walk the pipe from the *source*. The fault is
> wherever the water *first* goes wrong, which is usually upstream of the puddle.

**Practice.** When a late stage produces a wrong result, instrument the *handoff
between stages*, not just the late stage. One `fprintf` of "what did SELECT put in the
selection array?" (`type=4 col=4`) ended a search that staring at `copy_objects` never
would have. Print the *inputs* to the failing step, then walk backward to where those
inputs were born.

---

### Lesson 5 — Cascades, ordering, and the tyranny of the strict `<`.

Selection here is a cascade (`find_closest_obj`, `findnet.c`): try lines, then
polygons, then boxes, then arcs, text, wires, instances. Each finder keeps the closest
hit *so far* and only displaces the incumbent if it is **strictly closer**:

```c
d = distance;               /* best distance found by earlier finders */
if (tmp < d) { winner = i; d = tmp; }   /* STRICT < : ties keep the incumbent */
```

Two consequences hide in that `<`:

1. **Order is policy.** Because lines are tried before boxes, at equal distance the
   *line* wins purely by being earlier in the list. Nobody decided "lines beat pins";
   it fell out of source-code order. Emergent policy is policy you did not review.
2. **Ties are a decision you are making by accident.** `<` versus `<=` is a real
   choice about who wins a draw, and here the accidental choice (`<`, incumbent wins)
   was the wrong one for pins.

> **Metaphor: first-past-the-post.** A cascade with strict `<` is an election where
> the earliest candidate wins every tie. If you never intended earliness to be a
> qualification, you have a rigged election and a surprising result.

**Practice.** Whenever you write a "closest / best / highest-priority wins" loop,
write the tie rule *on purpose* and comment it. If priority matters, encode priority
explicitly (a rank, a bias, a layer check) instead of leaning on iteration order. The
fix here made the intent explicit and local:

```c
if (tmp < d || (c == PINLAYER && tmp <= d))   /* pins win ties, on purpose */
```

---

### Lesson 6 — Know what your primitive *actually computes*, not what its name suggests.

The metric was `dist_from_rect(mx, my, x1, y1, x2, y2)`. The name says "distance from
the rectangle." What it *computes* (in `clip.c`) is the distance to the **nearest
edge** — the minimum of the four side distances:

```c
dist = fabs(mx-x1); tmp = fabs(x2-mx); if (tmp<dist) dist=tmp;   /* ... y sides ... */
return dist*dist;   /* note: also SQUARED */
```

So for a point in the dead center of a 5×5 pin box, this returns `2.5² = 6.25`, not
`0`. By this metric the pin's own center is one of the *farthest* points from the pin.
That is why the stub line (genuine distance 0) beat the pin: the metric measured
"distance to the border," and the click was maximally far from the border.

> **Metaphor: a moat, not a fortress.** `dist_from_rect` measures how far you are from
> the *castle wall*. Stand in the courtyard and you are far from every wall — the
> function reports you as distant, even though you are as inside as inside gets.

**Practice.** Before you build logic on a helper, verify its contract by *observation*,
not by its name — "distance," "size," "contains," "empty" are famous liars. One dumb
`printf` of `dist_from_rect(center)` would have shown `6.25` and collapsed the mystery.
The fix respected the primitive instead of fighting it: *inside the body, override the
metric to 0* rather than trying to reinterpret an edge-distance as a region-distance.

```c
if (c == PINLAYER && POINTINSIDE(mx, my, x1, y1, x2, y2)) tmp = 0.0;
```

---

### Lesson 7 — Discretization is a silent branch-selector.

A subtle twist closed the case. After the fix, an experiment *removed* the `<=` tie
rule but kept the `tmp = 0.0` override — and the center click *still* selected the pin.
By the strict-`<` reasoning it should have failed. Why didn't it?

Because "click the exact center" is a fiction. Screen coordinates are **integers**.
The schematic point under integer pixel *P* is `X_TO_XSCHEM(P)`, which almost never
maps back to exactly `0` — it lands at `0.3`, `-0.1`, some sub-unit crumb. So the stub
line's distance was not `0` but a *tiny positive* number, and the pin's overridden `0`
beat it through plain `<`. The `<=` only matters in the measure-zero case where a pixel
maps *exactly* onto the line. It is real (belt-and-suspenders), but rarely the actor.

> **Metaphor: the pixel grid is a cattle grid.** You think you stepped on the line;
> you actually landed in the gap next to it. Continuous intentions fall through a
> discrete floor.

**Practice.** When behavior depends on equality of computed reals — "on the line," "at
the origin," "exactly overlapping" — remember that quantization and floating point
rarely deliver exact equality. Decide whether your logic should hinge on `<`, `<=`, or
a tolerance band, and test the *quantized* reality, not the idealized one. (Relatedly:
this is why the diagnostic getters print `%.16g`, not `%d` — you want to *see* the
crumbs.)

---

### Lesson 8 — "Sabotage or it didn't happen" — but sabotage *cleanly*.

A green test proves nothing until you have watched it go red for the right reason.
This is the "green-but-hollow" discipline: after a fix, deliberately break the fix and
confirm the test *fails*. Here the natural sabotage was "revert the pin override and
check the copy count drops to 1."

But the *first* sabotage attempt was a mess: a fragile text-substitution matched only
*part* of the change, an editor touched the file mid-experiment, and the result was
ambiguous — the test passed when the theory said it should fail. That ambiguity was
itself a lesson.

> **Metaphor: a controlled experiment has exactly one hand on exactly one knob.** If
> you turn two knobs (or a knob you did not mean to), the reading tells you nothing.

**Practice for clean sabotage.**
1. Change **one** variable; confirm the change actually took (grep the built source,
   check the compiler really recompiled — a stale object file is a silent third knob).
2. Predict the outcome *before* running.
3. If reality disagrees with the prediction, do not hand-wave it — either your model
   is wrong (good, you just learned something) or your experiment is dirty (fix it and
   rerun). Here, the clean rerun revealed Lesson 7: the "impossible" pass was real and
   *taught us about quantization*. A dirty experiment would have buried that insight.

The final, clean sabotage: reverting the override made the center-click copy produce
one pin instead of two — exactly the original bug — so the test genuinely guards the
fix. Only then was it trustworthy.

---

### Lesson 9 — The deepest cause was a modeling smell: an aggregate with no name.

Step back from the tactics. *Why* was there a tie to break at all? Because a "pin" is
not one object in this data model — it is three coincident objects: a `PINLAYER` rect,
a stub `LINE` on the symbol layer, and a name-text "view." They travel together in the
user's mind but are independent in the arrays. Selection, copy, and move each have to
*re-derive* "these three are really one thing," and every place that re-derivation is
imperfect breeds a bug (the P4 copy/paste work in the same feature fought the same war
over the name view).

> **Metaphor: a constellation with no name.** Three stars that everyone *sees* as one
> shape, but the star catalog lists separately. Every navigator must re-spot the
> pattern by eye, and some will connect the wrong dots.

**Practice.** When several primitive records always move, copy, delete, and select
*together*, that is a first-class concept begging for a name — a struct, a group id, a
"these belong to that" back-pointer (this codebase later leaned on
`owner_pin_id` for exactly the name-view half of the problem). Naming the aggregate
turns "re-derive the relationship correctly in five places" into "store the
relationship once." Ambiguous selection is often a *symptom of a missing type.*

---

## Part 3 — How to write code so bugs like this are cheap to find

A checklist distilled from the above. None of it is exotic; all of it is the
difference between a one-pass fix and a three-pass one.

1. **Add read-only accessors for governing state.** If a test cannot read it, you will
   debug it blind. Getters are lanterns; hang them early. (Lesson 2)
2. **Make gestures and side-effecting flows scriptable end-to-end**, driving the *real*
   dispatch path, and assert on numbers (counts, state bits, deltas). Reserve eyeballs
   for the genuinely pictorial. (Lesson 3)
3. **Print/observe the data crossing stage boundaries**, so "which stage first went
   wrong" is answerable without spelunking each stage. (Lesson 4)
4. **Write tie-breaks and priorities explicitly**, and comment *why*. Never let source
   order silently become policy. (Lesson 5)
5. **Comment the non-obvious contract of primitives** at the call site — "returns
   *squared* distance to the *nearest edge*" — so the next reader is not ambushed.
   (Lesson 6)
6. **Treat computed-real equality with suspicion**; know whether discretization/float
   makes your `==`/`<`/`<=` fire the way you think, and print with full precision.
   (Lesson 7)
7. **Every fix ships with a test you have watched fail without the fix** — and the
   sabotage that proved it must be clean (one knob, recompile confirmed). (Lesson 8)
8. **When records always move together, give the group a name.** A missing aggregate
   type shows up as ambiguous selection, duplicated-derivation bugs, and "why did it
   copy the wrong piece." (Lesson 9)
9. **Comment the *why*, not the *what*.** The fix's comment explains that a pin's stub
   line crosses its center at distance 0 and that dist-to-edge scores the center as
   *far* — so the next person meets the reasoning, not just the code. Future-you is a
   stranger; leave a note.

---

## Coda — the shape of the whole thing

The bug was ~one `if`. The *lesson* is that the distance between "I have a bug" and "I
have the one `if`" is almost entirely a function of how well you can **see inside your
own program**. Two of the three passes were spent in the dark, arguing with a map.
The third pass — the one that actually found and fixed it — began the moment we stopped
reasoning about the machine and started *reading* it: getters printing geometry, a
script replaying the gesture, an `fprintf` naming the wrongly-selected object.

> Build the instruments before you need them; distrust every claim you have not
> personally watched happen; automate the machine and eyeball only the paint; and when
> a test goes green, break it on purpose to make sure the green means what you hope.

Do those four things and most bugs stop being detective novels and start being lab
work — which is the point.

---

*Related reading in this folder: `gui_focus_and_testability_lessons.md` (when the fix
is eyeball-only), `identity_vs_address_tutorial.md` (stable handles — the "give the
aggregate a name" idea, generalized), and the P4 notes in
`doc/claude/specs/cadence_pin_name_text.md` (the name-view half of the same
three-objects-one-pin story).*
