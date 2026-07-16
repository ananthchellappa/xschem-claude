# A point is not a path — a tutorial on moving geometry, razor-edge bugs, and proving a fix is load-bearing

*How one diagonal wire that should have been two straight ones taught us that a
moving object sweeps a **locus**, not a point — and how to debug a bug that fires
at exactly one input and nowhere else. Worked through issue 0087 of XSCHEM's
fluid-editing wire router (branch `fluid-editing`, `src/move.c`).*

This is a **teaching** companion to the design record
`doc/claude/issues/0087-future-point-vs-riser-corridor-diagonal.md`. It is
written for someone who can already write a program that *computes over data*,
but has not yet had to write one that *reasons about geometry that is in motion*
— where the thing you are testing against is not where it is now, but everywhere
it is about to be. Moving geometry has its own traps, and this small routing bug
is a clean place to meet three of them: **the point-vs-locus error**, **the
razor-edge (quantization) bug**, and **the discipline of proving a heuristic fix
is safe rather than merely effective**.

Sidebars marked **▶ Level up** lift each concrete detail to the general idea so
you can carry it to any router, physics engine, collision system, or CAD tool you
build later. All code is real; line numbers were read from `src/move.c`.

> Companion reads in this directory: `fluid_editing_terminology.md` (the decoder
> ring for the vocabulary below), `lessons_green_is_not_correct.md` (why a green
> suite proves less than you think — this tutorial is a concrete application of
> that lesson). Prior issues in the same thread: 0081 (two-leg decomposition),
> 0083 (far-pin landing), 0085 (blind-elbow diagonal fallback), 0086 (future-blind
> leg-0 aesthetics). 0087 is their sequel and closes a gap 0086 explicitly parked.

---

## Part 0 — The feature and the bug, in one breath each

**The feature.** XSCHEM is a schematic editor. When you grab a component and drag
it, the wires attached to it should *follow* — and follow *nicely*: staying
orthogonal (Manhattan: only horizontal and vertical segments, the house style of
every circuit diagram), not crossing through other parts, and — above all — not
accidentally connecting two nets that must stay separate (a **short**). This is
called *incremental rip-up-and-reroute*: each mouse step, the follow wires are
thrown away and re-drawn from scratch under a pile of constraints.

**The bug.** Drag one resistor (R18) by a specific amount, `(+250, −90)`, and two
of its wires came out **diagonal** — a slanted line from corner to pin — even
though a perfectly good all-right-angle route existed. Not wrong electrically
(the right nets were connected), just *ugly*, and "ugly" here means "the router
gave up." The user had reported it, a previous session claimed to have fixed it,
and it was still there.

That "claimed fixed but isn't" is the first clue. It means the previous fix was
*aimed at the right area but missed by a hair*. Hold that thought.

---

## Part 1 — The world the router lives in

You need four facts about the scene to follow everything else. Here is `R18` and
its neighbourhood before the drag (coordinates are schematic units; **y increases
downward**, as on a screen):

```
                              (the "row" at y=140, with ammeter v8 and output pin)
   C12 (capacitor)            ─────────────────────────────
        │                                    │
        │ net2                               │ net1
   (-420,-90)───(-400,-90)                   │
                    │  net2                   │
                    │                         │
              P (-400,-70)  ← R18 top pin (net2)
              ┌───────┐
              │  R18  │      a resistor: two pins, P on top, M on bottom
              └───────┘
              M (-400,-10)  ← R18 bottom pin (net1)
                    │ net1
                    └──────────── up to the row at y=140
```

- **R18 has two pins on two different nets.** `P` (top) is on `#net2` (wired to
  capacitor C12). `M` (bottom) is on `#net1` (wired up to the row at y=140). These
  two nets **must never touch**.
- **The drag is diagonal:** `(+250, −90)` — 250 right, 90 up. After it, `M` lands
  at `(−150, −100)` and `P` lands at `(−150, −160)`.
- **Look where they land:** both pins end up on the *same vertical column*
  `x = −150`, with `M` at y=−100 and `P` at y=−160, and R18's body between them.
  Two different nets, stacked on one column, body in the gap. This is the crux —
  keep it in view.
- **A clean route exists.** `#net1` can drop straight down `M`'s own column;
  `#net2` can climb the *old* column `x=−400`, run across the top, and come down
  to `P` from above. Nothing forces a diagonal.

> **▶ Level up — "connectivity" vs "quality" are different problems.** The router
> has *hard* constraints (don't short, don't disconnect: get the graph right) and
> *soft* ones (look tidy: right angles, few bends, no crossings). A mature tool
> separates them and orders them: in this codebase the order is literally written
> down — `P1=P2 > P3 > P5 > P4 > P7 > P6` (connectivity and no-short first,
> aesthetics last). 0087 is a pure *quality* bug: connectivity was already correct.
> When you build anything that "arranges" or "lays out," decide this ordering
> **explicitly and up front**, because your fallback behaviour (what happens when
> you can't satisfy everything) falls straight out of it.

---

## Part 2 — How a diagonal drag is actually executed: legs, and the birth of "later"

Here is the design decision that everything hinges on (it predates 0087; it is
issue 0081). The router does not know how to route a *diagonal* move directly. So
it doesn't try. It **decomposes** the diagonal into two axis-aligned moves it
*does* know how to handle:

- **Leg 0:** move purely in X (`+250, 0`).
- **Leg 1:** move purely in Y (`0, −90`).

Apply leg 0, re-route (all pure-horizontal machinery). Then apply leg 1 on top,
re-route again (all pure-vertical machinery). If the two-leg composite ends up
changing which nets are connected (a short or a disconnect), throw it all away and
fall back to a cruder method. (That safety net is issue 0085; its last resort is
the diagonal wire we're trying to eliminate.)

This decomposition is powerful, but it manufactures a subtle new concept, and the
whole bug lives inside that concept:

> During **leg 0**, every pin is at an **intermediate** position — it has moved in
> X but *not yet* in Y. Its **final** position is one leg away in the *future*.

The code makes this literal. While leg 0 is committing, two globals hold the
*remaining* delta — the part of the journey not yet taken:

```c
/* src/move.c ~1837 */
static double fluid_leg_future_dx = 0.0, fluid_leg_future_dy = 0.0;
```

Set, per the attempt loop, to `(0, totdy)` during leg 0 and `(0,0)` everywhere
else. So a pin's **final** landing during leg 0 is:

```
final = live_position + this_leg_delta + (fluid_leg_future_dx, fluid_leg_future_dy)
        \_______________ intermediate ______________/   \____ the future ____/
```

For our M pin during leg 0: live `(−400,−10)`, plus leg-0 delta `(+250,0)` =
intermediate `(−150,−10)`; plus the future `(0,−90)` = final `(−150,−100)`.

> **▶ Level up — decomposition creates "tenses."** Whenever you break a
> transformation into ordered steps, mid-sequence state acquires a *past*, a
> *present*, and a *future*. Bugs love the future tense, because the naive
> instinct is to reason about "where things are" (present) when the constraint is
> actually about "where things will be" (future). Physics integrators, animation
> tweening, multi-phase migrations, staged rollouts — all grow this same
> three-tense structure, and all grow the same class of "I checked the wrong
> tense" bug.

---

## Part 3 — The 0086 fix, and the hair it missed

Issue 0086 (the previous session) already understood the future tense. It added
two "future-aware" safety checks that run during leg 0:

1. **`fluid_slide_future_hazard`** — before letting a wire's corner *slide* along
   with the pin, ask: would the slid copper land on a co-moving foreign pin's
   **final** position? If yes, decline the slide.
2. **`fluid_ml_future_covers`** — when choosing between the two L-shapes
   (horizontal-first vs vertical-first) for a follow wire, and both look clean
   *right now*, break the tie by asking: does this orientation lay copper on a
   co-moving foreign pin's **final** position? Avoid the one that does.

Both were correct in spirit and both had the same flaw, and it is the entire
lesson of this document:

> They tested the pin's **final POINT**. But a pin in a decomposed move is not
> going to *be* at a point — it is going to **travel** from its intermediate
> position to its final one, dragging a wire (its "riser") the whole way. Foreign
> copper anywhere along that swept path shorts, not just at the destination.

Here is the exact miss. During leg 0, the `#net2` stub's corner slid east and
parked at `(−150, −90)`. M's **final point** is `(−150, −100)`. Those differ by
**one grid step** (10 units). The point test compared against `(−150,−100)`, saw
the slid copper at `(−150,−90)`, found them unequal, and said "safe." But M is
going to ride *down* column `x=−150` on leg 1 — from its intermediate `(−150,−10)`
to its final `(−150,−100)` — and `(−150,−90)` is squarely **on that path**. Short.

```
   column x = -150

   y=-10   ●  M intermediate (start of leg-1 ride)
   y=-90   ×  ← net2 slid corner parked HERE. On M's path. SHORT.
   y=-100  ◍  M final  ← the ONLY point the 0086 test checked
   ...        M's riser continues down to the row

   The old test asked "is net2 copper at ◍?"  No (it's at ×, one grid up).  "Safe."
   The right question: "is net2 copper anywhere on the segment ● … ◍?"  Yes, at ×.
```

---

## Part 4 — The razor edge: a bug that fires at exactly one input

Before the fix, we swept the neighbourhood of the failing delta and printed, for
each, whether the route came out all-Manhattan:

```
(+250,-70)  clean      (+250,-80)  clean
(+250,-90)  DIAGONAL   ← the only failure in the whole band
(+250,-100) clean      (+260,-90)  clean   (+240,-90)  clean
```

One input fails; every neighbour is fine. This pattern is a **fingerprint**, and
learning to read it is worth more than the fix itself.

Why does `(+250,−80)` pass but `(+250,−90)` fail? Because at `−80`, M's final
point is `(−150,−90)` — which *coincidentally equals the slid corner's position*.
The point test, testing the wrong geometry, happened to be *right by accident*: the
one point it checked landed exactly on the hazard. Move the drag one grid further
(`−90`) and the pin's final point slides off the parked copper, the accident
stops happening, and the latent bug surfaces.

> **▶ Level up — a razor-edge failure means your test and the truth are *tangent*,
> not *equal*.** When a bug appears at an isolated input surrounded by passing
> ones, you are almost never looking at "special-case logic gone wrong." You are
> looking at an **approximation that happens to agree with the exact answer at
> most inputs and diverges at a boundary** — an off-by-one, a `<` that should be
> `≤`, a point that should be an interval, a rounding step. The passing neighbours
> are not evidence the logic is right; they are evidence the approximation is
> *usually close*. The single failure is where "close" isn't "correct." Chase the
> tangency, not the input. (This is the same moral as `lessons_green_is_not_correct.md`,
> viewed through geometry.)

**How we localized it:** the router has an env-gated trace (`FLUID_TRACE`, see the
terminology doc). We ran the drag and diffed the trace of the failing step against
a passing neighbour. The passing step showed `slide … DECLINE` and
`elbow-future … f0=1 f1=0` (the future checks *firing* and steering the route);
the failing step showed *neither line* — the future checks had silently said
"nothing to worry about." That absence, sitting right next to a presence one grid
away, is what pointed at "the future test is under-firing at this delta."

> **▶ Level up — instrument the *decision*, not just the *outcome*.** A log that
> only records "route = diagonal" tells you *that* it failed. A log that records
> *which guard did or didn't fire* tells you *why*. Diffing the decision trace of a
> failing input against a passing neighbour is one of the highest-yield debugging
> moves there is — it turns "somewhere in 10,000 lines" into "this one branch, this
> one input." Build that trace facility *before* you need it.

---

## Part 5 — The fix: model the path, not the point

The correct object is the pin's **riser corridor**: the segment from its
intermediate position to its final one. On leg 0 that is always a *vertical*
segment (the future delta is pure-Y), from `(px+dx, py+dy)` to
`(px+dx+future_dx, py+dy+future_dy)`. Testing "does foreign copper touch this
corridor" instead of "does it touch this point" fixes the miss by construction —
the point is one endpoint of the corridor, so the new test can only find *more*,
never less.

We needed a primitive the codebase didn't have: **do two axis-aligned segments
share any point?** (The old primitive, `fluid_pin_on_seg`, only tests a *point*
against a segment.) Here it is, `src/move.c ~2250`:

```c
/* Do two AXIS-ALIGNED segments A(ax1,ay1)-(ax2,ay2) and B(bx1,by1)-(bx2,by2) share any point? */
static int fluid_seg_pair_touch(double ax1, double ay1, double ax2, double ay2,
                                double bx1, double by1, double bx2, double by2)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0;
  int ah, av, bh, bv;
  if(tol < 1e-6) tol = 1e-6;
  if(ax1 == ax2 && ay1 == ay2) return fluid_pin_on_seg(ax1, ay1, bx1, by1, bx2, by2);  /* A is a point */
  if(bx1 == bx2 && by1 == by2) return fluid_pin_on_seg(bx1, by1, ax1, ay1, ax2, ay2);  /* B is a point */
  ah = (ay1 == ay2); av = (ax1 == ax2);
  bh = (by1 == by2); bv = (bx1 == bx2);
  if(!(ah || av) || !(bh || bv)) return 0;          /* diagonal: unsupported, never a false hit */
  if(ah && bh) { /* both horizontal: same row + overlapping x  */ ... }
  if(av && bv) { /* both vertical:   same column + overlapping y */ ... }
  { /* perpendicular: the cross point must lie inside both spans */ ... }
}
```

Three things in that little function are worth naming, because they are the whole
craft of writing geometry primitives:

1. **Degenerate inputs reduce to the simpler case.** A zero-length segment *is* a
   point, so it delegates to `fluid_pin_on_seg`. This is not a nicety — it is the
   linchpin of the safety argument in Part 7. On leg 1 (and on every non-decomposed
   move) the "corridor" has zero length, so `fluid_seg_pair_touch` collapses to the
   *exact* old point test. **The new code contains the old code as a special case.**
2. **Out-of-domain inputs return the safe answer.** The callers only ever pass
   horizontal/vertical copper, but if a diagonal ever slips in, the function returns
   0 (no hit) rather than computing garbage. A geometry helper should have a defined,
   conservative answer for every input, not just the ones you expect.
3. **Tolerance is explicit and shared.** `cadsnap/2` is the same fuzz the rest of
   the router uses; comparisons are `>= lo - tol`, `<= hi + tol`. Floating-point
   geometry without a stated tolerance is a bug generator.

> **▶ Level up — segment-vs-segment overlap for axis-aligned inputs is *three*
> cases, not one.** Parallel-horizontal (same row, x-ranges overlap),
> parallel-vertical (same column, y-ranges overlap), and perpendicular (the cross
> point lies within both spans). General segment intersection is a determinant/
> orientation test; when everything is axis-aligned you get a far simpler, exact,
> branch-per-case form — and you should prefer it, because it has no near-degenerate
> floating-point regime. Recognizing when your inputs are more constrained than the
> general algorithm assumes is a recurring performance-and-correctness win.

With the primitive in hand, both future tests change from *point* to *corridor*.
The slide test (`src/move.c ~2816`):

```c
double ix = px + dx, iy = py + dy;                                     /* intermediate */
double fxc = ix + fluid_leg_future_dx, fyc = iy + fluid_leg_future_dy;  /* final        */
if(fluid_seg_pair_touch(ix, iy, fxc, fyc, /* slid-copper span */ ...)) return 1;
```

At `(+250,−90)` this now *fires*: the corridor `(−150,−10)–(−150,−100)` and the
slid horizontal copper ending at `(−150,−90)` share that point → decline the
slide → fall back to the hazard-aware jog relay. Half the fix.

---

## Part 6 — The subtlety that took a second try: exempt your own terminus

Declining the slide is not enough. The `#net2` stub still has to be routed as an
L, and now the *elbow tie-break* (`fluid_ml_future_covers`) has to pick the good
orientation. First attempt: just swap its point test for the same corridor test.
Result — still diagonal. The trace explained why:

```
elbow-future: wire=8  f0=1  f1=1  -> ml=1      (both orientations flagged; can't choose; keeps the bad one)
```

Both L-orientations were flagged as hazardous, so the tie-break had no basis to
prefer one, and kept the (bad) default. Why did *both* flag?

Because the `#net2` stub's own moving pin is `P`, and during leg 0 `P` sits at its
intermediate position `(−150,−70)` — which is itself **on M's corridor** (x=−150,
between y=−100 and y=−10). Every possible L-shape for the stub *ends at P*, so
every possible L touches M's corridor at P. The test was flagging the wire for
*arriving at its own destination*.

The resolution is a small, precise idea: **exempt a contact that occurs exactly at
the wire's own moving pin.** That pin is where the wire is *supposed* to end, and —
crucially — it is going to *move away* on the next leg. Only copper crossing the
corridor *somewhere else* is a genuine future short. So we built a second
primitive, `fluid_seg_pair_touch_except(A, B, ex, ey)` — "do A and B share a point
*other than* `(ex,ey)`?" — and the tie-break passes its own pin as the exempt
point (`src/move.c ~2798`):

```c
if(fluid_seg_pair_touch_except(ix, iy, fxc, fyc, rx1, hy, rx2, hy, mx, my) ||
   fluid_seg_pair_touch_except(ix, iy, fxc, fyc, vx, ry1, vx, ry2, mx, my)) return 1;
```

Now the trace reads `f0=1 f1=0`: the horizontal-first orientation still touches
the corridor *away* from P (it runs a leg along y=−90 that crosses x=−150) and is
correctly flagged; the vertical-first orientation touches the corridor *only at P*
and is correctly cleared. The tie-break picks vertical-first, `#net2` climbs the
old `x=−400` column and comes down to `P` from above, and the route is all right
angles.

> **▶ Level up — a constraint check must not penalize the thing it's protecting.**
> This is a general pattern in collision, routing, and layout: an object almost
> always "collides" with its own anchor / its own goal / its own start. The fix is
> an **exemption for the legitimate contact** — the endpoint, the source cell, the
> node you're routing *to*. Get the exemption *too broad* and you hide real
> violations; *too narrow* and you flag benign self-contact. The right exemption
> here is a single point (the pin), justified by a physical fact (that point moves
> next leg). Name the justification, not just the exemption.

And note the second-try shape of this: the *first* corridor patch was correct but
*insufficient*, and the trace (`f0=1 f1=1`) told us exactly what was still missing.
Fix, observe, refine — driven by instrumentation, not guesswork.

---

## Part 7 — Proving it's *safe*, not just *effective*

A heuristic change that fixes your one repro is a liability until you can say what
else it can do. The discipline: bound the **blast radius**. Three arguments, each
one you should be able to make about any change to a heuristic:

**(1) Inertness outside the target regime.** The corridor is non-degenerate *only*
on leg 0 of a decomposed diagonal move (that's the only time `fluid_leg_future_*`
are non-zero). Everywhere else — leg 1, pure-axis moves, plain non-following moves
— the corridor has zero length and the helpers reduce to the *identical* old point
test (Part 5, point 1). Both callers also still early-return 0 when the future
delta is zero. So the change is **byte-for-byte invisible** to every move that
isn't a diagonal follow-drag. Most of the program cannot tell the patch exists.

**(2) Monotonicity.** The corridor *contains* the old final point. So the new test
returns 1 (hazard) in a *superset* of the cases the old one did — it can only fire
*more*, never less. That matters because of where "firing" leads…

**(3) The failure modes of firing are all connectivity-safe.** A slide-test hit
only *declines* a cosmetic slide, falling back to the hazard-aware jog relay. An
elbow-test hit only *biases a choice between two orientations that are already
proven short-free* — it cannot select a hazardous shape, only a less-pretty
safe one. And even if some untested geometry made a *wrong* aesthetic choice, the
two-leg attempt loop re-checks the net partition and rolls back to the old diagonal
relay. So the worst thing this change can produce is a **diagonal wire in a scene
we didn't test** — exactly the pre-existing behaviour. It **cannot** create a
short or a disconnect. The blast radius is "aesthetics," bounded below by "no worse
than before."

> **▶ Level up — "can only fire more" + "firing is safe" = a proof of safety
> without enumerating cases.** When you can show (a) your change is a superset of
> the old behaviour on the trigger, and (b) every consequence of the extra
> triggering is bounded by an existing safe fallback, you have bounded the blast
> radius *analytically* — you don't need to have tested every scene, because you've
> shown the space of bad outcomes is empty (or no worse than baseline). This kind of
> **monotonicity + safe-fallback** argument is how you make aggressive heuristic
> changes without fear. Reach for it whenever "did I break something far away?" is
> the scary question.

---

## Part 8 — Verification: making the fix earn its place

Effective + safe by argument still needs empirical teeth. Four kinds, in order of
increasing strength:

1. **RED first.** Before touching the fix, reproduce the bug headlessly and watch
   it fail (`all_manhattan = 0`, the two diagonal wires printed). A test you never
   saw fail is a test you don't trust.
2. **Neighbourhood sweep.** Assert the *entire* `(+230..+270, −60..−110)` band (30
   deltas) comes out clean — not just the one repro. This *locks the razor edge*:
   if a future change re-introduces a tangency bug anywhere in the band, a test
   fails. (Test 44, drive D7.)
3. **Sabotage verification.** This is the one people skip and shouldn't. Temporarily
   *revert* each half of the fix — collapse the corridor back to a point — rebuild,
   and confirm the razor-edge tests go **RED again**. Do it for *each* half
   independently. Both did → both halves are **load-bearing**; neither is dead code
   riding along. A test that passes with your fix *removed* was testing nothing.
4. **End-to-end replay.** Run the user's actual gesture on the user's actual file
   and diff the saved schematic: 13 wires, zero diagonal, nets distinct. The unit
   test proves the mechanism; this proves the *feature*.

> **▶ Level up — a passing test only means something if you've seen it fail for the
> right reason.** RED-first proves it *can* fail; sabotage proves it fails *because
> of your fix specifically*. Together they close the gap between "the suite is
> green" and "the suite is green *because the code is correct*." That gap is where
> most false confidence lives — see the companion `lessons_green_is_not_correct.md`.

---

## Part 9 — The adversarial review, and refuting a plausible ghost

The fix was then handed to independent reviewers (a small multi-agent review: one
lens on the segment math, one on connectivity safety, one on inertness — each
finding then handed to a skeptic told to *refute* it). Two lenses found nothing.
One raised a plausible-sounding P3: *"the pin-exemption could hide a real short —
if a foreign pin's corridor touches orientation ml0 only at the exempt point and
touches ml1 nowhere, you'd wrongly clear ml0."*

It is worth learning how that was **refuted**, because the refutation is a
*geometric-invariant* argument, and those are the strongest kind:

> The exempt point `(mx,my)` is the wire's own moving pin — and it is a **shared
> endpoint of *both* L-orientations** (both are just the two Manhattan routes
> between the same pair of endpoints). So if a foreign corridor passes through
> `(mx,my)`, it touches ml0 **and** ml1 there; the exemption fires *symmetrically*
> and cancels out of the comparison. The finding's premise — "touches ml0 at the
> pin but ml1 nowhere" — is geometrically **impossible**, because ml1 also owns
> that pin.

The reviewer's proposed "fix" (drop the exemption) would have *re-introduced* the
original bug — without the exemption, both orientations flag at `(+250,−90)` and
the tie-break is stuck again. So the exemption is not only safe, it is *necessary*.
Verdict: false positive, and the exemption is load-bearing (which the sabotage test
in Part 8 had already shown empirically).

> **▶ Level up — the strongest refutation attacks the premise, not the
> conclusion.** A finding of the form "if geometry X happens, bad outcome Y" is
> killed most cleanly by proving **X cannot happen** — usually via an *invariant*
> the code maintains (here: "a moving pin is a shared endpoint of both candidate
> routes"). Invariant arguments beat case analysis because they hold for *all*
> inputs at once. When you review — or defend — geometry code, hunt for the
> invariants first; they are where the airtight arguments are.

---

## Part 10 — What to carry away

Strip away the schematics and this is a compact catalogue of transferable ideas:

1. **A moving object is a locus, not a point.** If you decompose or animate motion,
   test constraints against the **swept path** between states, not the endpoint
   state. The naive instinct — check "where it ends up" — is the point-vs-corridor
   error, and it hides at boundaries.
2. **A razor-edge failure is a tangency.** One failing input in a sea of passing
   ones means your check *approximates* the truth and they *coincide* at most
   inputs. Fix the approximation (point → interval), don't special-case the input.
3. **Decomposition creates tenses.** Split a transform into ordered steps and
   mid-stream state gains a past/present/future; verify against the tense the
   constraint actually cares about (usually the future).
4. **Constraint checks must exempt their own goal** — precisely, and with a stated
   justification, so the exemption is neither too broad (hides bugs) nor too narrow
   (flags benign self-contact).
5. **Bound the blast radius by argument:** inertness outside the regime +
   monotonicity of the trigger + safe fallback for every consequence = a safety
   proof that doesn't require enumerating scenes.
6. **Green isn't correct until you've seen RED.** RED-first, neighbourhood sweeps,
   and *sabotage verification* (revert the fix; confirm the tests fail) are what
   turn a passing suite into evidence.
7. **Refute at the premise.** The best rebuttal to "if X then Y" is an invariant
   proving X is impossible.

The bug was two diagonal wires. The lesson is how to think about geometry that is
in motion, how to read a failure that hides at one input, and how to prove a clever
fix is safe. Those outlast any one router.

---

*Source: `src/move.c` (`fluid_seg_pair_touch`, `fluid_seg_pair_touch_except`,
`fluid_ml_future_covers`, `fluid_slide_future_hazard`, the leg attempt loop).
Design record: `doc/claude/issues/0087-future-point-vs-riser-corridor-diagonal.md`.
Test: `tests/headless/wireedit/test_wireedit_44_diagonal_manhattan_quality.tcl`
(drives D6/D7). Vocabulary: `fluid_editing_terminology.md`.*
