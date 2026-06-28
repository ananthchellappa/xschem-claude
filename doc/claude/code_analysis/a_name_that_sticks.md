# A name that sticks

*The story of giving thousands of nameless objects a stable identity inside a
25-year-old program — and, woven through it, the handful of decisions that look
ordinary on the page but are the difference between a talented beginner and an
engineer with twenty years of scar tissue. Written to be readable by anyone, with
a few deeper seams marked for computer-science students.*

---

## 1. A problem you have already felt

Imagine a theatre with numbered seats and no names. You tell a friend, "I'm in
seat 5, come find me at intermission." Someone in seat 2 leaves early. The usher,
tidying up, asks everyone behind the empty seat to shuffle one place forward to
keep the rows neat. Now your friend walks to seat 5 — and finds a stranger. You
are in seat 4. Nobody lied, nothing broke, and yet the message is now wrong.

This is one of the most common bugs in all of software, and it is exactly that
mundane. Programs keep their things — in our case the wires, components, and
shapes of a circuit-drawing tool — in lists. The natural way to point at the
third thing is to say "number 3." But "number 3" is a fact about *where it is
sitting right now*, not about *which thing it is*. Delete something earlier in
the list, the rest shuffle forward to fill the gap, and every "number 3" written
down beforehand now points at the wrong object. The program quietly does the
wrong thing from then on.

The quiet is the dangerous part. A crash is honest; it stops and tells you. This
bug just keeps going, drawing the wrong conclusion forever, and you find out days
later when a result makes no sense.

The whole project this report describes was the cure: give every object a **name
that sticks** — an identity that stays attached to *that* object no matter how
the list is shuffled, sorted, or compacted.

## 2. The cure, in one idea

You cannot use the seat number (it shifts). You cannot use the person's
real-world name either, because — and this surprised us until we checked — those
get **reused**: delete component `R37`, create a new one, and the program hands
out the name `R37` again. A held name now points at a different object, the same
trap in a new disguise. (Anyone who has used a database knows the cousin of this
rule: never use someone's email or phone number as their permanent ID. It is
real, it is unique *today*, and it will betray you.)

So we *manufacture* an identity that has the one property identity needs:
**a number that only ever counts up and is never reused.** The first object
gets 1, the next 2, and a number, once retired by a deletion, is never handed out
again. Hold that number, and later ask "where is the object with id 470 now?"
The answer is either an honest location or an honest "it's gone" — never a
stranger wearing the dead object's seat.

That is the entire idea. The interesting part — and the reason this is worth a
report — is everything we chose *not* to do.

---

## 3. Five forks in the road where the beginner and the veteran turn differently

Skill in programming is rarely about cleverness; beginners can be dazzlingly
clever. It is mostly about *judgment* — and judgment shows up at unremarkable
forks where the "obvious" move and the right move point in opposite directions.
Here are five we hit, and which way each turns.

### Fork 1 — "This code is ancient and messy. Rewrite it."

The codebase is twenty-five years old, written in an old dialect of C, with
almost all of the program's state hanging off one enormous shared structure. The
object-creation logic is scattered across a dozen places in several files. A
beginner looks at this and feels a powerful urge: *tear it down and rebuild it
properly.*

The veteran feels that urge too — and distrusts it. Working, shipped code that is
twenty-five years old is not messy by accident; it is messy because it has
survived twenty-five years of real bugs, edge cases, and fixes that a rewrite
would silently throw away. (Joel Spolsky's famous 2000 essay, *Things You Should
Never Do*, calls a from-scratch rewrite "the single worst strategic mistake" a
software company can make, precisely because every ugly line is a scar over a bug
someone already found.) The senior move was the disciplined opposite of a
rewrite: **retrofit the new capability with the smallest possible additions, and
respect the existing grain of the code.** Everything we added is purely additive
— some two hundred and thirty existing commands kept working untouched the entire
time. Restraint, not ambition.

### Fork 2 — "To look something up fast, use a hash map." *(CS students, read this one twice.)*

We need to answer "given id 470, where is that object now?" Every instinct
trained by an algorithms course screams: build a **hash map** from id to
location, and the lookup is O(1) — constant time, the gold standard.

We deliberately did **not**. We used a **linear scan** — walk the array and
compare — which is O(n), the very thing those courses teach you to avoid. On
purpose. Here is the reasoning, because it is the most counter-intuitive decision
in the project and the clearest fingerprint of experience:

- A hash map from id to location is *a second copy of the answer*. The truth of
  "where is each object" lives in the array; the map would be a duplicate that
  has to be **updated on every single change** — every deletion, every shuffle,
  every undo. Each of those updates is a chance to forget. A forgotten update is
  a stale map entry — which is **the exact bug we were hired to kill**, now
  living in a new organ. We refused to build a cache whose failure mode is the
  disease we were curing.
- The linear scan has no second copy. The id rides *inside* each object, so
  however the array is shuffled, the id is carried along automatically. The array
  is always, by construction, the one and only truth. There is nothing to keep in
  sync, so there is nothing that can fall out of sync.
- And the "slow" cost is imaginary here. These lists hold a few hundred items,
  and the questions arrive at human, scripting speed. A few hundred comparisons,
  a few times a second, is *free*. We would have been spending real complexity —
  and reopening the exact bug class — to buy a speed-up no human could ever
  perceive.

The beginner optimizes reflexively because "O(1) beats O(n)" is a rule they were
graded on. The veteran asks the question the rule omits: *optimize for what, and
at what cost in the currency that actually hurts — which is bugs, not
microseconds.* Choosing the asymptotically slower algorithm, and being **right**
to, is a move that takes years to become comfortable making — because you have to
be willing to defend "I made it slower on purpose" in a code review. (We even
left the escape hatch: if a profiler ever proves the scan matters, a fast cache
can hide *inside the same function* without any caller knowing. Slow-but-correct
is the interface; fast is a private, reversible afterthought — never an upfront
commitment.)

> **The deeper cut, for CS students:** the never-reused number is the standard
> defence against the **ABA problem** — the bane of lock-free data structures,
> where a value is read, swapped away, and swapped *back* so that a naive check
> sees "no change" and corrupts everything. The fix everywhere is the same:
> attach a monotonically increasing tag so the "same" value can never actually
> recur. You will also meet our scheme's faster cousin, the **generational
> index** (the identity system in modern game engines and in Rust's `slotmap`):
> a handle of `(slot, generation)` where freeing a slot bumps its generation, so
> a stale handle is *detected* by a generation mismatch. We chose id-in-the-array
> + scan over that because our `n` is tiny and our whole mandate was to *minimise*
> coherence machinery, not add a clever new piece of it. Two defensible points on
> one design curve; the craft is knowing which end your problem actually sits at.

### Fork 3 — "Make the change and the cleanup in one go."

To stamp every new object, we first had to route a dozen scattered
object-creation sites through a single chokepoint — and *then* stamp the id at
that one place.

The beginner does both in one commit: move the code and add the new behaviour
together. It works, the tests pass, done. Until something is subtly off, and now
they are bisecting a change that did two unrelated things at once, unable to tell
which half caused the trouble.

The veteran splits it deliberately. First: route the dozen sites through the new
single function, where that function does *nothing new yet* — a pure
reorganisation that cannot change behaviour, proven by the entire test suite
staying green. Only then, second: add the one line that stamps the id. Two
commits, each with exactly one job. If the second breaks something, you know it
was the second. This "make it a no-op move, *then* make the small real change"
rhythm is unglamorous and is worth more debugging hours than almost any clever
trick.

### Fork 4 — "The tests are green. Ship it." *(The second one CS students should steal.)*

A green test bar is reassuring and treacherous. Tests can pass for the wrong
reasons: asserting something trivially true, or never actually exercising the
code you think they do. A beginner sees green and believes.

The veteran does not trust a green bar until it has been *proven able to go red
for the right reason.* We did this two ways:

- **Red first.** Every test for the new feature was written and committed
  **failing**, before the code that satisfies it existed. Watching it fail, then
  pass after the change, proves the test is actually wired to the thing we built
  — not quietly passing on nothing.
- **Sabotage.** With everything green, we deliberately *broke* the code — made
  the id-stamp write a constant `42` instead of the real counter — rebuilt, and
  re-ran. Ten tests went red. *That* is the proof the tests genuinely reach the
  thing they claim to guard: vandalise the implementation, and the guards must
  scream. Then we reverted and confirmed green again. (Done at industrial scale
  and automated, this idea is a real research field called **mutation testing** —
  measuring a test suite by how many deliberately-injected bugs it catches.)

"My tests pass" is evidence only if your tests *can fail when the code is wrong*.
Most people never check. The habit of proving it — by withholding the code and by
breaking it on purpose — is hard-won, because it usually comes from having once
trusted a green bar that was guarding nothing.

### Fork 5 — "My design said X, so build X."

We had written down a sensible-sounding rule in advance: *an object's identity
should survive the user changing its colour/layer* (just as a component keeps its
id when renamed). Then we read how "change layer" is actually implemented and
found it **deletes the object and builds a new one** on the new layer. To honour
the written rule, we would have had to *rewrite* that operation to smuggle the
old id through the rebuild — real new risk, in service of a rule we had only
guessed at.

The beginner does one of two things: forces the original plan through (adding the
risk), or quietly notices the mismatch and says nothing. The veteran lets reality
overrule the plan, *out loud*: we documented that a layer change reconstructs the
object and therefore mints a fresh id, chose the additive low-risk path, and
extracted the general principle for next time — *"identity survives an operation
for free only when that operation edits in place; when it rebuilds the object,
preserving identity costs you a behaviour change."* Being publicly, cheerfully
wrong about your own plan — and turning the surprise into a reusable lesson — is a
senior trait. Junior pride defends the plan; senior pride defends the result.

---

## 4. So, what here was "twenty years of experience," and not luck?

You asked directly, so here it is directly. None of the senior moves above are
clever. **That is the point.** The thing experience buys is not bigger tricks; it
is *better restraint* — a trained sense for what **not** to do:

- **Not** rewriting a working 25-year-old system, even though it itched.
- **Not** reaching for the faster algorithm, because the slower one removed an
  entire bug class and the speed was imperceptible — and being willing to defend
  "slower on purpose" in writing.
- **Not** adding a cache, because a cache is a second truth that rots, and rot
  was the enemy.
- **Not** mixing a refactor with a behaviour change in one step.
- **Not** trusting a green test bar until it was proven able to fail — by
  building red-first and by sabotaging the code to watch the alarms go off.
- **Not** clinging to the written plan when the code revealed a better, smaller
  answer — and documenting the reversal instead of hiding it.
- **Not** charging ahead after each milestone, but stopping to lay out the
  options and let the human choose the next direction.

Any one of these, in isolation, a sharp newcomer might do. Doing *all of them,
consistently, as defaults* — treating "what is the smallest, most reversible,
least clever change that provably works?" as the first question rather than the
last — is what twenty years in production systems quietly installs in you. It is
the difference between an engineer who can make the computer do a thing and one
who can make a change to a system other people depend on **without breaking their
trust in it.** The second is the whole job.

And there is a measurable signature of that judgment in the result: across four
rounds of this work, on seven kinds of object, every change was additive, every
phase left all tests green, every claim of "it works" was backed by a test we had
first watched fail, and not one of the program's hundreds of existing features
was disturbed. Boring, on purpose. In production software, *boring is the highest
compliment.*

---

## 5. Three things to carry away

**For everyone.** *Where a thing is* and *which thing it is* are different
questions. A position, a row number, a seat — these tell you where, only for an
instant. If you need to refer to *that very thing* over time, give it a name that
is never reused, and keep that name separate from its location. You will see this
everywhere once you notice it: order numbers separate from "the third item in
your cart," account IDs separate from email addresses, the little coat-check
ticket separate from which hook your coat hangs on.

**For the computer-science student.** The two seams marked above — *deliberately
choosing the O(n) scan over the O(1) map because the map would rot,* and *proving
a test can fail before trusting it to pass* — are worth more than they look.
They are the moments where textbook reflexes ("always optimise," "green means
good") meet engineering judgment ("optimise for the cost that hurts," "evidence
requires falsifiability"). Learn the names attached to the deep versions: the
**ABA problem**, **generational indices**, **mutation testing**. They will recur
for your whole career.

**For anyone who builds on top of what others made.** The hardest and most
valuable skill on display was not invention. It was *changing a large, old,
load-bearing system gently* — additively, reversibly, provably, and with the
humility to let the code correct the plan. The flashy part of engineering is
making something new. The senior part is making a change that, years later, no
one even remembers was risky, because it never once went wrong.

---

*This report is a companion to the technical write-ups it summarises:
`identity_vs_address_tutorial.md` (the concept in depth),
`stable_handles_extension_strategy.md` (the "don't rewrite it" analysis),
the `*_lifecycle_census.md` files (the "prove you found every site" criterion),
the `doc/stable_*_handles.md` and `doc/object_query_api.md` manuals, and the
`introspection_probes/probe*.tcl` demonstrations. The point of this one is not
the code; it is the judgment.*
