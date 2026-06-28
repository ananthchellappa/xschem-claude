# The wire that forgot its name — a tutorial on metadata loss across object re-creation

*A field guide written from the TC12 / R19 bug (commit `06b08e61`): a stretch move
silently wiped a wire's properties. The bug is small; the **class** of bug is everywhere.
Read this before you touch any code that deletes-and-recreates objects, or any test that
asserts on a value you didn't prove is a source of truth.*

---

## Part 0 — The bug in one sentence

Dragging a component so an attached wire *stretched* turned a wire saved as
`N 0 30 0 130 {bus=4}` into `N 0 70 0 130 {}` — the geometry followed, but the wire's
entire property string was gone.

Two independent mistakes were hiding in that one sentence. One was in the **engine**
(it really did drop the data). One was in the **test** (it was asserting on a value that
was never going to survive anyway, for an unrelated reason). You have to find and fix
*both*, and the second one is the more insidious teacher.

---

## Part 1 — The symptom and the first wrong instinct

The failing assertion read:

```tcl
we_wire 0 30 0 130 {lab=A[3:0]}      ;# a "bus" wire
... move the device so the wire stretches ...
check "lab preserved" {[xschem getprop wire 0 lab] eq {A[3:0]}}   ;# FAILS
```

The instinct is: *"the move code forgot to copy the `lab`. Find where it copies
geometry, copy the property too."* That instinct is **half right and half a trap**. If
you act on it without proving what `lab` actually is, you will "fix" the bug, watch the
test still fail (now showing `#net1` instead of empty), and have no idea why.

**Lesson 0: a red test tells you *a* value is wrong, not *which mechanism* produced it.
Reproduce and characterize before you theorize.**

---

## Part 2 — Probe-driven bisection (how the root cause was actually found)

No debugger was harmed. The whole investigation was four tiny headless scripts, each
asking exactly one question. This is the technique worth copying.

**Probe 1 — "Does it survive a *plain* stretch, with the kissing path turned off?"**
Strip the gesture down to the minimum that reproduces. It still failed *and* revealed the
smoking gun:

```
BEFORE: wire 0: coord=0 30 0 130  lab='A[3:0]'  id=1
AFTER : wire 0: coord=0 70 0 130  lab=''         id=2     <-- id CHANGED
```

The `id` jumped `1 → 2`. In this codebase every wire gets a monotonic id at its single
birth door (`wire_store()`, store.c). **A changed id means the object was destroyed and a
new one born** — it was *not* mutated in place. That one number reframed the entire hunt:
stop looking for "where does it copy the property" and start looking for "where does it
*re-create* the wire."

**Probe 2 — "What's the *literal* saved property, not the live getter?"** `saveas` to a
temp file and read the raw `N` record. The live getter and the on-disk form disagreed,
which was the second clue (see Part 4):

```
after_stretch_only:  N 0 70 0 130 {lab=#net1}
```

**Probe 3 — "Is this even a *move* bug? Reproduce with NO move at all."** Create the
wire, run `xschem resolved_net` (which forces `prepare_netlist_structs`), save:

```
bare-before:            N 0 30 0 130 {lab=A[3:0]}
bare-after-netlistprep: N 0 30 0 130 {lab=#net1}     <-- changed with ZERO moves
```

This is the probe that saves you from shipping a wrong fix. The `lab` mutates *without a
move*. So `lab` was never the thing to test.

**Probe 4 — "Does a *genuinely persistent* attribute survive?"** Use `bus=4` (a real
stored field) instead of the cache token:

```
WITHOUT fix:  N 0 70 0 130 {}        bus=''     <-- real data loss
WITH fix:     N 0 70 0 130 {bus=4}   bus='4'    <-- preserved
```

Now both the engine bug and the test premise are nailed, each by a one-question script.

**Lesson 1: bisect with disposable single-question probes. Watch for *identity signals*
(a changed id, a re-minted handle) — they tell you "re-created, not mutated," which is a
completely different bug than "field not copied."**

---

## Part 3 — Root cause: the degenerate-then-collapse trick that ate the prop

Here is the actual mechanism, in `place_moved_wire()` (move.c). When one endpoint of a
wire is dragged, the router may need to bend it into an L (an "H-V" or "V-H" jog). It does
so by **rewriting the original wire into one leg and `storeobject()`-ing a brand-new wire
for the other leg**:

```c
else if(wire[n].sel == SELECTED1 && (xctx->manhattan_lines & 2)) /* V - H */
{
  wire[n].x1 = xctx->rx1; wire[n].y1 = xctx->ry1;
  wire[n].x2 = xctx->rx2; wire[n].y2 = xctx->ry1;   /* original becomes leg A */
  order_wire_points(n);
  if( xctx->ry1 != xctx->ry2 ) {
    storeobject(-1, xctx->rx2,xctx->ry1,xctx->rx2,xctx->ry2, WIRE,0,0, NULL); /* leg B, prop = NULL ! */
  }
}
```

Now play it forward for the case that bit us — a **colinear** slide, where a *vertical*
wire's lower endpoint moves *vertically*. The "bend" is degenerate:

```
   before                during place_moved_wire             after collapse
   (0,130) ●             (0,130) ●  leg B  {NULL prop}        (0,130) ●
          │                     │   (the REAL survivor)               │
          │  {bus=4}            │                                     │  {NULL}
          │              leg A: (0,70)-(0,70)  ZERO LENGTH            │
   (0,30) ●  id=1        (0,70) ●  still holds {bus=4}        (0,70) ●  id=2
   on pin M                     ↑ degenerate, holds the prop          prop GONE
```

`recompute_orthogonal_manhattanline(0,70, 0,130)` sees a taller-than-wide segment and
picks `manhattan_lines = 2` (V-H). The branch sets **leg A to `(0,70)-(0,70)` — zero
length** (it still carries `{bus=4}`), and stores **leg B `(0,70)-(0,130)` — the real
surviving segment — with `NULL` properties**. Then, at move end,
`check_collapsing_objects()` does exactly what it's supposed to: it deletes the
zero-length leg A. But leg A was the one holding the property. The survivor, leg B, was
born blank.

So the data wasn't "not copied." It was **carried by the object that got garbage-collected,
while the object that lived was created empty.** That is the signature of this whole bug
class: *a delete-and-recreate where the metadata rode the wrong horse.*

**The fix** is one idea applied to all four jog-store sites: the second leg is the *same
electrical net* as the original, so it must inherit the same attributes.

```c
storeobject(-1, ... , WIRE,0,0, wire[n].prop_ptr);   /* was NULL */
```

Unlabeled wires have `prop_ptr == NULL`/`""`, so they are byte-identical to before — the
fix only changes behavior for wires that actually carry data. (A bent labeled wire now
has the label on *both* legs, which is correct: they are one net.)

**Lesson 2: `storeobject(... NULL)` — or any "create a sibling/continuation object" call
that hard-codes empty metadata — is a code smell. A continuation of an object is not a
blank object. Ask "what net / owner / style / id does this new thing belong to?" and pass
it.**

---

## Part 4 — The other half: the test asserted on a write-only cache

Even after the engine fix, the original assertion (`lab == "A[3:0]"`) failed — now showing
`#net1`. Probe 3 already told us why: **a wire's `lab` token is not a property you set; it
is a cache the netlister writes.**

In xschem a net is *named* by a label **instance** (`lab_pin.sym`, a `type=label` symbol),
not by a token on the wire. When `prepare_netlist_structs()` runs, it derives each net's
name and **writes it back into the wire's `lab` token** as a convenience cache
(`#net1` for an unnamed net). So `lab=A[3:0]` typed onto a bare wire is overwritten the
first time anything triggers netlisting — *with or without a move*. The token is
**write-only from the wire's perspective**: the engine writes it, nothing reads it back as
truth.

That means the Phase-1 test was **hollow**: it could only have passed by accident, and it
was "testing" a value the system is contractually allowed to clobber. We rewrote TC12 to
assert on things that are actually real and persistent:

1. geometry follows (the rubber-band itself),
2. a genuine stored attribute (`bus=4`) survives the move — the real bug, and
3. a real `lab_pin` net-label *instance* still names the wire's net afterwards.

**Lesson 3: before you assert that X "is preserved," prove X is a *source of truth* and
not a *derived cache*. The tell: does X change when you do something unrelated to the
operation under test (here, "run netlisting without moving")? If yes, your assertion is
measuring the cache, and a green is meaningless. This is a [[green-but-hollow]] special
case — the test executes, but it never had teeth.**

---

## Part 5 — The general anti-patterns (carry these to any codebase)

This bug is xschem-specific only in its variable names. The shapes recur everywhere:

- **Re-create-drops-metadata.** Any path that implements "edit" as delete + insert (CRDT
  merges, immutable-data "copy with changes," ORM cascade rewrites, AST rewrites, undo/
  redo snapshots, React `key`-churn that remounts a component) must forward *every* field
  that isn't recomputed — id, owner, style, ACL, net, dirty-flag — not just the one the
  feature is about. The fields you forget are the ones nobody's test covers.

- **The survivor isn't the original.** When an operation produces several objects and then
  prunes some, check *which one lives*. Metadata attached to "the natural original" is
  worthless if a later cleanup pass keeps a different sibling. Trace the object through the
  *whole* pipeline, including the collapse/dedup/GC at the end.

- **Cache masquerading as state.** A field that is "usually right because something keeps
  it in sync" is a cache. Reading or asserting on it as if it were authoritative is a
  latent bug. Know, for every field, *who writes it and when*.

- **Identity signals are free breadcrumbs.** If your objects have stable ids/handles, a
  changed id across an operation is a loud "I re-created this" — invaluable for telling
  "field not copied" apart from "object reborn." If they don't, this bug is invisible;
  that's an argument for stable handles (see [[stable-object-handles]]).

---

## Part 6 — A reviewer's checklist

When reading a diff (or your own code) that moves/edits structured objects:

1. **Does it `create` instead of `mutate`?** Grep the touched function for the
   construction/store call. In this codebase: `storeobject(`, `wire_store(`,
   `*_store_split(`. Every one with a literal `NULL`/`0`/`""` in a metadata slot is a
   question to answer, not a default to accept.
2. **For each created object, list its fields. Which are recomputed, which inherited?**
   Anything neither recomputed nor inherited is dropped — name it and justify it.
3. **Is there a cleanup/collapse/dedup pass after?** If so, re-ask question 2 about the
   *survivors*, not the objects as first created.
4. **Round-trip it.** Save → reload (or serialize → deserialize) and diff. A getter can lie
   (caches, defaults); the persisted form is closer to truth. Here, `saveas` + reading the
   raw record exposed both the loss and the cache.
5. **Undo it.** Re-creation churn often also breaks undo (new ids, lost selection). One
   undo must restore *exact* prior state, metadata included.

---

## Part 7 — Prompting proactively (for AI-assisted and human-assisted work alike)

You can stop this bug *at the prompt*, before a line is written. Bake these into the task
framing:

- **State the invariant up front, not just the feature.** Not "make the wire follow the
  move," but *"make the wire follow the move **while preserving its net, bus width, and
  any property tokens; one undo must restore the exact prior wire including its props.**"*
  An invariant in the prompt becomes an assertion in the test.

- **Demand a round-trip + a no-op control in the test plan.** "Prove the property survives
  by saving and reading the raw record, **and** show what the same value does under an
  operation that should *not* affect it (e.g. netlist-prep with no move)." The control is
  what exposes a cache.

- **Ask "is this field a source of truth or a cache?" explicitly.** Before asserting any
  field is preserved, require a one-line justification of who writes it and when. If the
  answer is "the netlister writes it," the test is wrong before it's run.

- **Treat `create-with-NULL-metadata` as requiring a comment.** A standing rule —
  *"any new object spawned as a continuation/split of an existing one must inherit that
  one's identity-and-attribute fields, or carry a comment explaining why blank is
  correct"* — turns a silent omission into a visible decision.

- **Make re-creation loud.** Prefer mutate-in-place; when you must re-create, log/annotate
  it and assert on the identity signal in a test (here: "after the move the wire's id may
  change, but its `bus=` must not"). If you can't observe re-creation, you can't guard it.

- **Sabotage-verify the fix.** Revert just the fix, rebuild, and watch the property get
  wiped. A green test that never executed the fixed line is theater
  ([[green-but-hollow]]). This is non-negotiable.

---

## Part 8 — The thirty-second version

> An "edit" that is secretly a delete-and-recreate will drop every field you didn't
> explicitly carry forward — and a later cleanup pass can make the *wrong* sibling the
> survivor, so even the field you "kept" vanishes. Before trusting that a value is
> preserved, prove it's a real stored field and not a cache the system rewrites on its own.
> Probe with one-question scripts, watch identity signals (a changed id = re-created),
> round-trip through save/reload, and sabotage-verify. Then bake the invariant into the
> prompt so the next person tests for it by default.

---

*See also: [[green-but-hollow]] (tests that run but don't bite), [[stable-object-handles]]
(why ids make re-creation visible), `doc/claude/code_analysis/net_identity_decision.md` and the
`stable_handles` net investigation (why a wire's `lab` is a derived cache, not state),
`doc/claude/code_analysis/wire_editing_spec_and_plan.md` Part III TC12 (the corrected test).*
