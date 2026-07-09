# The easy invariant and the hard scope — a tutorial on cleanup passes, emergent bugs, and knowing what *not* to touch

*How removing one redundant rectangle of wire took one core idea and seven
guards — and why, on a mature codebase, the danger was never "will it work" but
"what else will it touch." Worked through issue 0088 of XSCHEM's fluid-editing
wire router (branch `fluid-editing`, `src/move.c`).*

Teaching companion to `doc/claude/issues/0088-fluid-reroute-redundant-samenet-loop.md`.
Written for someone who can already design an algorithm that does the right thing
on the input in front of them, but has not yet had to ship one into a large,
stateful system where the input in front of them is one of a million shapes the
users will actually feed it. That gap — between *an* algorithm and a *deployable*
one — is where most of the effort in this issue went, and it is the most
transferable thing here.

Sidebars marked **▶ Level up** lift a concrete detail to the general lesson.
All code is real; line numbers were read from `src/move.c`.

> Companion reads in this directory: `point_vs_corridor_tutorial.md` (the previous
> issue in this thread — moving geometry), `lessons_green_is_not_correct.md` (a
> green suite proves less than you think), `lessons_multi_agent_orchestration.md`
> (how the design and review here were run as fan-out workflows),
> `heap_field_lifecycle_tutorial.md` (the allocation discipline this codebase
> demands). Prior issues in the same router: 0081, 0083, 0085, 0086, 0087.

---

## Part 0 — The bug in one breath

Grab resistor `R18`, drag it up-and-left. The wires follow. The route the tool
lays is, *at every mouse step, correct* — no short, all Manhattan, everything
connected. But when you let go, one net has a **closed rectangle of wire** sitting
in it that carries no connection: two parallel paths between the same two rows,
one of them left over from where the pin used to be. Not a bug in any single step.
A bug in the *sum* of the steps.

That last sentence is the whole reason this was hard, so sit with it.

---

## Part 1 — The shape of the problem: emergent defects

Most bugs are local: a wrong comparison, an off-by-one, a null deref. You find the
line, you fix the line. This was not that. Every function in the reroute pipeline
did exactly what it was designed to do:

- The corner-slide guard (`fluid_slide_future_hazard`) **correctly declined** to
  slide a wire corner, because sliding it would have parked copper where another
  pin lands two steps later — a short it was shipped to prevent (that is issue
  0086/0087, the *previous* two tutorials).
- The elbow builder (`place_moved_wire`) then correctly built a detour.
- The pin, dragged back over its original column, correctly re-attached.

Each decision, defensible in isolation. The redundant loop is what those three
correct decisions *compose into*. The original wire that anchored the old detour
was never selected, never moved, never wrong — it simply became **vestigial** once
the pin left, and nothing was watching for vestigial copper.

> **▶ Level up — emergent defects.** When every unit passes its unit test but the
> whole misbehaves, stop looking for the broken unit; there isn't one. The defect
> lives in an *invariant of the composite* that no single stage owns. Two moves:
> (1) name the composite invariant that's violated ("after a drag, a net should
> carry no redundant cycle"); (2) decide who will own it. You are almost always
> adding a new stage, not fixing an old one. Incremental pipelines — routers,
> compilers, query planners, CRDT merges — breed this class. The tell is that the
> bug only appears after *N* steps and never after one.

---

## Part 2 — How to approach it: five moves that did the work

### 2.1 Make it reproduce before you make it right

The user handed over a `FLUID_TRACE` log and two files (`before_3.sch`,
`after_8.sch`). The first hour was spent *not* fixing anything — only turning "a
gesture that misbehaved once, on someone else's machine" into "a command I can run
that fails the same way every time."

The lever was a property of the system worth knowing existed: this router is a
**pure function of (start snapshot, total delta)** — "release == stepwise." So the
wandering multi-step drag in the trace collapses to a *single* scripted move by
the net delta `(-20,-60)`, which reproduces the loop byte-for-byte against
`after_8.sch`. A 40-line Tcl script, run headless, is now the bug.

> **▶ Level up.** A reproduction you control is worth more than a diagnosis you
> believe. And before you write the reproduction, ask what *algebraic* property of
> the system lets you shrink the user's messy trace to a minimal case — idempotence,
> determinism, "release == stepwise," commutativity. Finding that property is often
> the actual insight; the fix rides in on it.

### 2.2 Read the trace as a state machine, not a log

The trace was 766 lines of `FLTRACE slide … DECLINE` / `FLTRACE elbow …`. The
useful reading is not "what went wrong" but "at which *state transition* did the
redundant edge first close." Tracking the wire set frame by frame showed the
rectangle appearing the instant the pin's column returned to the riser's column —
that pinned the cause to "stale detour + returned pin," not to any one decline.

### 2.3 Prevention vs cleanup — choose with the conflict order, not taste

Two families of fix: **prevent** the stale copper (don't decline the slide; or
retire the base wire when the elbow forms) or **clean up** after (detect and
remove the redundant cycle at the end). A design fan-out (three independent
proposals, adversarially cross-examined — see `lessons_multi_agent_orchestration.md`)
killed prevention decisively: un-declining the slide re-introduces the exact short
0086/0087 exist to stop (a P2 regression), and retiring the base wire *at the leg
where the elbow forms* disconnects the net, because at that moment the base wire is
still the only link (the redundancy doesn't exist yet — it's emergent, Part 1).
Cleanup was the only family that didn't regress a hard invariant.

> **▶ Level up.** When you have a priority order over your invariants (here P1
> connectivity = P2 no-short > … > P6 aesthetics), a fix proposal isn't judged on
> elegance — it's judged on *which invariant it puts at risk*. Prevention here
> traded a hard invariant (P2) for an aesthetic one (P6). That's an automatic no,
> independent of how clean the code would have been.

### 2.4 Find the one load-bearing invariant, then build the algorithm around it

Cleanup could have been a hundred heuristics. It became one idea:

> **Delete a wire only if the geometric partition of the instance pins is
> byte-identical before and after.**

Compute, purely from geometry (`touch()` union-find over wires, then walk every
instance pin to its wire-component), a canonical labelling of which pins are
connected to which. Tentatively mark a wire deleted; recompute; keep the deletion
**iff the pin partition is unchanged**. That single check *is* the safety proof:
delete-only copper can never merge two nets (you can't add a connection by
removing a wire), and a deletion that stranded any pin would change its partition
label and be reverted. Connectivity (P1) and no-short (P2) — the two hard
invariants — fall out of one comparison. Everything else in the 470-line diff is
*scope*, not *safety*.

> **▶ Level up — separate the safety kernel from the scope shell.** The most
> reusable design move in this whole issue: find the single property that makes the
> operation *safe*, express it as one cheap check, and make every other rule answer
> a different question — *should* we, not *may* we. When safety is one auditable
> predicate, reviewers (human or machine) can verify the kernel once and then only
> argue about scope. Contrast the alternative (a pile of special-case guards each
> partly responsible for safety): no one can ever say the whole is correct.

### 2.5 Let counterexamples grow the scope — the guard-discovery loop

The safety kernel was written in an afternoon. The next several days were a loop:

```
propose scope → adversarial review finds a concrete input that over/under-reaches
             → add ONE guard that answers exactly that input → re-verify → repeat
```

Every guard in the final code is a fossil of a specific counterexample:

| Guard | The counterexample that created it |
|---|---|
| **chord gate** (seed must lie on a cycle) | a *single-pin* net's dangling routing is partition-invariant (one pin is a singleton with or without its wires) → the kernel alone would delete it. Tests 38/39 went red. |
| **`get_tok_value` copy** | the label check re-called `get_tok_value` while holding its previous result — same shared buffer → an invalid read (valgrind caught it). |
| **novelty (H3)** | without it the pass could collapse a loop the user drew, not one the drag created. |
| **START-cycle decline** | a pre-existing user *ring* sharing a junction with the junk was eaten (review round 1). |
| **tap-aware graph** | the decline guard's endpoint-only graph was blind to a loop that closes through a mid-span T-tap → it read as a tree and slipped past (review round 2). |
| **destination reach** | the guard checked where the pin *was*, not where it *lands* — a loop the pin is dragged *onto* was uncovered (review round 2). |
| **sub-edge dedup** | duplicate collinear wires made a multigraph that over-declined (review round 3, a safe nit). |

Read that table top to bottom: **not one of these guards is about making the fix
work.** The fix worked on day one. They are all about the fix *not doing harm on a
shape the author didn't picture.* That ratio — one idea, seven guards — is the real
lesson of the issue.

> **▶ Level up — over-reach is the tax on cleanup passes.** Any pass that *deletes*
> or *rewrites* existing user data pays a tax the *creating* code never pays: it can
> destroy work. The creating code only has to be right about what it makes; the
> cleanup code has to be right about everything it might touch. Budget for that
> asymmetry. If you write a "remove redundant X" pass and it's only 30 lines, you
> have almost certainly not yet met the inputs that will make it 300.

---

## Part 3 — What about *this* codebase made it hard

Generic lessons above; here are the specific landmines XSCHEM sets, each of which
cost real time and each of which recurs in systems of its shape (a big C core with
one global state and a long mutating pipeline).

### 3.1 One global `xctx`, a pipeline of stateful passes, order is load-bearing

Almost all state hangs off a single global `Xschem_ctx *xctx`. The move-commit
block runs a *fixed sequence*: `place_moved_wire` → obstacle reroute → offset →
`check_collapsing_objects` → `trim_wires` → `remove_move_orphan_wires` → **[our
pass]** → `insert_exit_stubs`. Where you insert matters enormously: too early and
you see un-merged fragments that hide the cycle; too late and the exit-stub pass
re-beautifies geometry you just changed. The pass runs at `move.c:4783`, *after*
trim (so the cycle is visible) and *before* exit-stubs (so the collapsed riser is
re-decorated). Picking that slot was a design decision, not an afterthought.

> **▶ Level up.** In a pipeline over shared mutable state, "where does my code go"
> is part of the algorithm. Write the invariants each neighbouring stage
> establishes and requires; your slot is the one interval where your preconditions
> hold and you don't break a later stage's.

### 3.2 Two models of connectivity that must agree — the deepest trap

XSCHEM has **two** notions of "are these wires connected," and a whole class of
bugs lives in the gap between them:

1. **Shared-endpoint**: two wires touch if an endpoint coincides.
2. **Tap / mid-span**: a wire's endpoint landing *interior* to another wire's span
   connects them (a T-junction) — this is what `touch()` implements and what the
   netlister actually uses.

The safety kernel used `touch()` (model 2, correct). But the *decline guard* I
first wrote to protect pre-existing user loops built its cycle graph from
**endpoints only** (model 1). Result: a user loop that closes through a tap was
invisible to the guard — it counted the graph as a tree — and the pass ate it. The
review caught it; the fix was to make the guard split each wire at every interior
tap node so its graph matches `touch()`.

> **▶ Level up — your auxiliary computation must use the *same* model as the ground
> truth.** Any time you build a cheaper/simpler side-computation (here: "does this
> net already have a loop?") to gate a precise operation (here: `touch()`-based
> deletion), the two must agree on the underlying relation. A side-model that is a
> *strict simplification* of the truth will silently disagree on exactly the inputs
> the simplification dropped — and those inputs are where the bug hides. If you
> can't reuse the real model, prove your simpler one is conservative *in the safe
> direction* (over-approximate connectivity, so you over-protect, never
> under-protect).

### 3.3 Coordinate identity is not stable across mutating passes

The first version of the loop-protection compared live wire coordinates against a
snapshot to ask "is this the user's pre-existing wire?" It failed, because
`trim_wires` had *merged* a collinear user edge into the new detour — same copper,
different coordinates — so the match missed and the wire was deleted. The fix was
to stop matching live geometry at all and compute the whole decision **from the
immutable START snapshot** (`fluid_start_wire[]` + the grabbed-coordinate set,
both captured before any mutation).

> **▶ Level up.** If pass B mutates the geometry pass C reasons about, C cannot
> identify objects by their coordinates. Either carry a stable identity (an id
> minted at birth — XSCHEM wires *have* one, `xWire.id`, though this pass didn't
> need it), or compute entirely from a snapshot taken before the mutation. "Match
> by value" across a mutation boundary is a bug generator.

### 3.4 `get_tok_value` returns a shared buffer

A tiny, vicious C idiom: `get_tok_value(prop, "lab", 0)` returns a pointer into a
*static, reused* buffer. Hold that pointer, call `get_tok_value` again, and your
first pointer now aliases the second call's result. The label-carrier check did
exactly this in a loop and valgrind flagged the invalid read. The codebase even
warns about it in `other_wire_same_lab` — the knowledge existed; it just isn't
enforced by the type system. Fix: `my_strdup` the token before the inner loop.

> **▶ Level up.** APIs that return borrowed/shared storage are landmines the
> compiler won't find. When you meet one, copy at the boundary. And run the
> memory checker on the *new* code specifically — three of this issue's bugs
> (the aliasing read, and two "does it leak on the early-return path") were caught
> only by pointing valgrind at the tests that exercise the new function.

### 3.5 A gated feature + a broken regression harness = the green-but-hollow trap

`fluid_editing` is default-off, and the repo's `run_regression.tcl` can't run in
this environment at all (it shells out to a bare `xschem` not on `PATH`, so *every*
case "fails" identically for an environmental reason). Both facts conspire to make
"the suite is green" nearly meaningless here. Countermeasures actually used:
drive the real gesture under a real display for the headline test; **sabotage-verify**
every guard (neuter it, watch the specific check go red — so you know it's
load-bearing and the green is real); and lean on the one suite that *does* use the
built binary (`wireedit`, run explicitly against `./src/xschem`). See
`lessons_green_is_not_correct.md`.

> **▶ Level up.** Before you trust a passing test, prove it can fail. A test whose
> red state you have never seen is a decoration. For a *guard*, that means: disable
> the guard, confirm the guard's own test breaks. For a *feature gate*, that means:
> confirm the off-path is byte-identical and the on-path actually reached your code
> (a one-line trace at function entry paid for itself here).

---

## Part 4 — What can still lurk

Honesty about residuals is part of the deliverable. Ordered by how likely they are
to bite.

1. **Buses are declined, not handled** (`A3-d`). A wire whose net is a bus (`[n:m]`
   or `wire.bus != 0`) is never collapsed. Correct bus redundancy needs bit-set
   equality via `expandlabel`, deferred. A redundant bus loop survives — safe, but
   the feature simply doesn't apply there.

2. **Wholesale decline is coarse.** If a *multi-pin* drag touches one net the user
   already looped, the pass declines cleanup on that whole drag — including junk on
   the *other*, innocent nets. Under-reach (misses a cleanup), never damage. A
   per-component decline would fix it but reintroduces the live→START mapping
   fragility of §3.3, so it was deliberately not done.

3. **A pre-existing *acyclic* user branch that the drag makes loop-redundant is
   removed.** This is the same mechanism that (correctly) removes the repro's stale
   base wire `w4`. The partition check guarantees it's only ever *redundant* copper
   (removing it changes no pin's connectivity), and novelty bounds it to
   drag-created redundancy — so it is "the feature working" far more often than
   "user copper lost." But there is no model of *user intent* here: the tool cannot
   tell a redundant wire the user wants kept from one they'd delete themselves. That
   is a genuine, unclosed gap, not a coding error.

4. **The safety kernel is blind to pin-less copper.** The partition is over
   *instance pins*. A decorative wire structure with no pin on it is invisible to
   the kernel — which is precisely why the whole guard apparatus (novelty, START-
   cycle decline) had to be bolted on to protect it. New pin-less-copper scenarios
   are the most likely place a future counterexample hides.

5. **Performance.** The greedy re-runs an `O(W²)` partition per candidate, and the
   decline guard is `O(nodes²)` in its interning/tap-split. Fine for the modest nets
   fluid drags touch; a pathological multi-thousand-wire grabbed component at END
   could stutter. No scaling test exists.

---

## Part 5 — If "0088" is reported again: a root-cause decision tree

A future maintainer sees "redundant loop after a drag" (or its evil twin, "my
wires disappeared after a drag"). Where to look, in order:

**First, classify the report.**

- **"A loop is left behind" (under-reach / the original bug returns).** The pass
  didn't fire or didn't remove enough.
  - Is `fluid_editing` on and is it a *stretch* drag (`stretch_select`)? If not, the
    gate at `move.c:4783` correctly skipped — not a regression, a configuration.
  - Did the **decline guard over-fire**? `fluid_start_grabbed_component_has_cycle`
    returns 1 → the whole collapse is skipped. Most likely if the dragged net has a
    *pre-existing* loop (by design) or the multigraph/over-approximation declined
    (§4.2, or a new over-decline). Add a `FLTRACE loop: DECLINE` check — the trace
    says which.
  - Did the **chord gate** or **novelty gate** reject the seeds? If the redundancy
    is genuinely pre-existing (no novel edge), H3 declines by design.
  - Is the geometry a shape the greedy's `seed`/`dead-end` eligibility never
    reaches (e.g. a redundant wire not incident to any grabbed coord or moved pin,
    and not adjacent to a doomed wire)? That's an eligibility gap — a *new*
    counterexample, extend the seed set.

- **"Wires disappeared / a net broke" (over-reach — the dangerous direction).**
  The pass removed something it shouldn't. This is where to spend real fear.
  - Was **user copper** deleted? Check the two guards that protect it: is the
    START-cycle decline seeing the loop (is it *tap-closed* and did the tap-split
    run — §3.2)? Is the loop reached via `coord_was_grabbed` **or**
    `point_on_moving_pin` (destination — §3.5/round-2 finding)? A user loop that is
    neither grabbed nor landed-on but is *dragged through mid-span* is a plausible
    unguarded shape.
  - Did **connectivity actually change**? If a pin was stranded, the partition
    kernel *should* have reverted the deletion. If it didn't, suspect the kernel's
    model diverging from the netlister's — the two-models trap (§3.2) again, or a
    pin connected by **abutment** (pin-to-pin, no wire), which the wire-touch
    partition does not model. That is the kernel's known blind spot.
  - Did a pass **downstream** (`insert_exit_stubs`) or the H4 backstop mutate things
    after the collapse? Check the `FLTRACE loop:` counts against the final geometry.

**The meta-answer to "where could the root cause lie":** almost never in the
safety kernel (it is one comparison and it is provably safe for what it models).
Overwhelmingly in **scope** — a new input shape that some guard's model doesn't
cover, or a *disagreement between two models of connectivity* (§3.2), or an
*identity-across-mutation* assumption (§3.3). When a "solved" problem in this pass
returns, do not re-derive the algorithm. Ask: *which guard's approximation did this
new shape fall through, and in which direction (delete-too-much vs delete-too-
little)?* The direction tells you whether you have a safety incident (over-reach,
fix now) or a missed optimization (under-reach, fix at leisure).

---

## Part 6 — The transferable core, in five lines

1. When every step is correct but the whole is wrong, you're adding a stage, not
   fixing one — the bad invariant belongs to the composite.
2. Find the single check that makes the operation *safe*; make everything else about
   *scope*. Safety you prove once; scope you grow from counterexamples.
3. A pass that deletes user data pays an over-reach tax the creating code never
   pays. Budget seven guards, not one.
4. Any side-model that gates a precise operation must use the precise operation's
   own model of the world, or be provably conservative in the safe direction.
5. Never identify objects by value across a mutation boundary; compute from an
   immutable snapshot or a stable id.

*— written from issue 0088, `fluid-editing`, after three adversarial review rounds
and four memory-checker passes. The fix is 470 lines; this tutorial exists because
460 of them are the answer to "what else could this break," and that question is
the job.*
