# Identity is not address: a tutorial on stable handles

*A worked lesson in one of the most useful distinctions in computer science —
told through a real bug we fixed in a 25-year-old C program, and connected to
the places you will meet the same idea again: garbage collectors, game engines,
databases, lock-free data structures, and operating systems.*

Audience: a CS student who has written some C or Java, knows what an array and a
pointer are, and has never seen this codebase. You do not need to know anything
about the program (XSCHEM, a circuit schematic editor). Every example is
self-contained.

---

## Part 0 — The one-sentence idea

> **Where a thing is** (its address — an array index, a pointer, a row offset,
> a file position) and **which thing it is** (its identity) are *different
> questions*, and a shocking number of bugs come from using the answer to the
> first as if it were the answer to the second.

That is the whole tutorial. The rest is making you feel it in your bones and
showing you the standard engineering moves for keeping the two apart.

---

## Part 1 — The bug, in eight lines

A drawing program keeps its rectangles in a plain array. A script asks: "give me
a handle to the third rectangle so I can watch it while I edit."

```tcl
set r 2                 ;# "the third rectangle" — its index
# ... the user deletes the FIRST rectangle ...
# now what is rectangle $r ?
```

When you delete an element from the middle of an array, you have two choices,
and both are traps for our script:

1. **Leave a hole** (`rects[0]` becomes "dead"). Now the array has gaps, every
   traversal must skip them, and your length count lies.
2. **Compact** — slide everything after the hole down by one to keep the array
   dense. This is what almost every real system does (it keeps iteration fast
   and memory tight). XSCHEM does this:

```c
/* delete: keep the array dense by shifting survivors left */
for (i = 0, j = 0; i < n; i++) {
    if (doomed(i)) continue;        /* drop it */
    if (j != i) arr[j] = arr[i];    /* slide survivor down */
    j++;
}
n = j;
```

After compaction, the rectangle the script called `2` is now at index `1`. The
script's saved index `2` now points at a **different rectangle** — or off the
end of the array. Nothing crashed. Nothing logged an error. The script just
quietly does the wrong thing from now on.

This is not an exotic bug. It is the single most common consequence of **using a
position as a name**. The position was only ever true "at the instant you looked"
(the program's own internal comment literally says so). An index is a fact about
*now*; the script wanted a fact about *that object, forever*.

---

## Part 2 — Why your first three fixes are also wrong

Students reliably propose these. Each fails instructively.

**"Don't compact — use a free list / tombstones."** You can, but you have only
moved the problem: now index `2` stays valid, but if anything ever *reuses* slot
2 for a new rectangle, the stale handle silently aliases the newcomer. (Hold
that thought — it has a famous name, coming in Part 6.)

**"Use a pointer to the rectangle instead of an index."** Worse. The array is
grown with `realloc`, which is *allowed to move the whole block*. Every pointer
into it becomes dangling the moment the array resizes. An index at least
survives a `realloc`; a raw pointer does not. (This is exactly why the classic
Macintosh memory manager handed out **handles** — pointers-to-pointers — instead
of pointers, so the OS could move memory under your feet.)

**"Use the rectangle's coordinates / its name as the identity."** Tempting when
the object *has* a natural-looking key. In our program, *instances* (circuit
components) have a name like `R37`. But we probed it and found two fatal
properties:

- **names get reused**: delete `R37`, create a new component, and it is
  auto-named `R37` again — a held name now points at a different object;
- **names are editable**: the user can rename `R37` to `R99`, and a held name
  resolves to nothing.

A "natural key" that the user controls is **user data, not identity**. This is
the same reason database designers warn against using a person's email or phone
number as a primary key: it is real, it is unique *today*, and it will betray
you.

So: not the index, not the pointer, not the name. We need to *manufacture* an
identity that has the properties identity requires.

---

## Part 3 — What makes a good identity (the spec)

Before coding, write the contract. A usable stable identity must be:

| property | why |
| --- | --- |
| **unique** | two live objects never share one |
| **never reused** | a freed id is retired forever, so a stale handle can be *detected*, not silently re-pointed |
| **stable under relocation** | survives compaction, sorting, array growth, swaps |
| **independent of mutable attributes** | survives the user renaming/recoloring the object |
| **cheap to mint and to store** | one machine word, stamped in O(1) |

Notice what is *not* required: it need not be meaningful, human-readable, or
even persistent across program restarts. Dropping those requirements is what
makes it cheap. (When you *also* need a human- or cross-session-stable name,
that is a *second*, different identifier — see Part 7.)

The minimal thing that satisfies the table is a **monotonic counter**: a single
integer that only ever increases. Stamp each new object with the next value.

```c
obj.id = ++context->id_counter;   /* 1, 2, 3, ... never repeats */
```

"Never reused" falls out for free: the counter only goes up, so a deleted
object's id is never handed to anyone again. A handle to a dead object resolves
to "not found" — loud and checkable — instead of to a stranger.

---

## Part 4 — Where to stamp it: the chokepoint principle

Here is the move that separates a clean implementation from a buggy one.

To stamp every new object exactly once, you must find **every place an object is
born**. In a young codebase that is one constructor. In a 25-year-old one, we
went looking and found objects created in *twelve* different places across three
files — an interactive "create" command, a clipboard "paste", a file "load" —
each filling the struct's fields slightly differently. Twelve places to stamp is
twelve places to *forget* to stamp.

The disciplined fix is not "stamp in twelve places." It is: **first make the
twelve places funnel through one**, then stamp in the one.

```c
/* The funnel. Every birth, however it filled the struct, ends here. */
void register_object(int type, int layer, int n) {
    objs[layer][n].id = ++ctx->id_counter;   /* <-- the ONLY stamp site */
    counts[layer]++;                          /* the object is now "live" */
}
```

We did this in two separate steps *on purpose*, and the order is the lesson:

1. **Funnel first, stamping nothing.** Replace the twelve scattered
   `count++` lines with twelve calls to `register_object(...)` that, for now,
   *only* does `count++`. This changes the code's structure but not its
   behavior. You can prove it is a no-op by running the whole test suite — it
   must stay 100% green, because you changed nothing observable.

2. **Then stamp.** Add the one `obj.id = ++counter` line inside the funnel.

Separating "move the code" from "change the behavior" means that if something
breaks, you know *which* of the two caused it. Mixing them is how refactors turn
into debugging marathons. This "make it a no-op refactor, then make the small
behavioral change" rhythm is worth building into your hands for life.

> **Transferable name for the pattern:** a *chokepoint* (or *narrow waist*).
> Find the one place every instance of an event must pass through, and enforce
> your invariant there. Compilers do it (every allocation through one arena),
> kernels do it (every syscall through one trap), web apps do it (every request
> through one middleware). When you find yourself about to enforce a rule in N
> places, ask: is there a 1-place I can route them through first?

---

## Part 5 — Resolving a handle: the decision that teaches the most

Now the reverse direction. Given an id, find the object. The obvious move is a
hash map `id -> index`, updated on every insert, delete, and move. **We
deliberately did not build it.** Understanding *why* is the deepest lesson in
this document.

The whole reason this bug existed is that a *position* was treated as a
*durable fact* and went stale. A map from `id` to `index` is **another copy of
position-as-durable-fact** — it would need updating on every single mutation
(every compaction shift, every swap, every array-grow, every undo). Each of
those is a chance to forget, and a forgotten update is exactly a stale
`id -> wrong index` entry: *the same disease, in a new organ.*

So we made the array itself the single source of truth, and resolved by scanning
it:

```c
int index_from_id(unsigned int id) {
    for (int i = 0; i < n; i++)
        if (arr[i].id == id) return i;   /* the id rides INSIDE the struct */
    return -1;                            /* not found = honestly gone */
}
```

Because the id travels *inside* the struct, every operation that moves an object
— compaction, the swap in a reorder, the bulk copy in undo — carries the id
along automatically. There is **nothing to keep in sync**, so there is nothing
to get out of sync. The array is authoritative by construction.

"But that's O(n)!" Yes. Two responses, and both are real engineering:

1. **Know your n.** These arrays hold hundreds of objects and the queries come
   from a human-speed scripting layer. O(n) over 100 elements, a few times a
   second, is *free*. Optimizing it would be spending complexity to buy
   performance nobody can perceive — and paying for it in exactly the bug
   currency we are trying to stop spending.
2. **The escape hatch is hidden behind the same function.** If a profiler ever
   proves the scan matters, you can add a rebuild-on-miss cache *inside*
   `index_from_id` without changing a single caller. The slow-but-correct
   version is also the *interface*, so the fast version is a private,
   reversible optimization later — not an architectural commitment now.

> **Transferable lesson:** every cache is a second copy of a truth, and every
> copy can drift. Before adding one, ask "what is the authoritative copy, and
> can I just read it?" Derived/duplicated state that must be manually kept
> coherent is one of the great sources of bugs; the cure is often to *not keep a
> second copy* until measurement forces you to, and then to hide it behind the
> function that already gives the right answer.

---

## Part 6 — The famous cousin: the ABA problem

Why was "never reused" in the spec (Part 3) so important? Because of this
scenario, which has a name you will see in interviews and lock-free data
structure papers:

1. You read a reference to object **A**.
2. While you are not looking, A is deleted and its slot/id is **reused** for a
   brand-new object **B**.
3. You compare: "is it still the same reference?" The slot/id matches, so you
   conclude *yes* — but it is now a different object. You proceed to corrupt
   something.

This is the **ABA problem**. It is the bane of lock-free programming (a
compare-and-swap sees the same pointer value and wrongly assumes nothing
changed) and it is *exactly* the "name reuse" trap from Part 2.

The fix is the same everywhere: **make the identifier monotonic so it is never
reused** — then step 2 can never make the identifier match, and the staleness is
*detected* instead of silently swallowed. Lock-free algorithms bolt a
monotonically-increasing **tag/version counter** onto the pointer for precisely
this reason. Our never-reused id is the same medicine.

A close relative you should know by name: **generational indices**, the standard
identity scheme in modern game engines (Entity-Component-Systems) and in Rust
crates like `slotmap`. A handle there is a pair `(index, generation)`. The slot
array stores a generation counter; freeing a slot bumps its generation; a handle
is valid only if its generation still matches the slot's. A stale handle has an
old generation and is rejected. That buys O(1) lookup (you index straight in)
at the cost of a side array you must keep coherent. We made the opposite
trade — id-in-struct + scan, O(n) lookup but *zero* coherence machinery —
because our n is tiny and our entire project is a war on coherence bugs. Two
defensible points on one design curve; the *art* is knowing which end your
problem sits at.

---

## Part 7 — Two identifiers are sometimes the right answer

A subtlety worth its own section, because students over-rotate on "there must be
one true id."

Our circuit *components* genuinely need two identifiers, doing two jobs:

- the **manufactured numeric id** — durable *within a session*, never reused,
  rename-proof: the machine handle a script holds across edits;
- the **human name** (`R37`) — editable, reused, and *saved in the file*: the
  only identifier that still means "the same component" after you close and
  reopen the document tomorrow.

Neither dominates. The id is safe but evaporates when the program exits (it is
never written to disk). The name persists across sessions and is what a human
types, but it is reusable and renamable. So we keep **both**, with a written
contract about which is for what: *hold the id across edits; use the name to
talk to humans and to survive a reload.*

This is the same two-identifier pattern databases use deliberately: a **surrogate
key** (an autoincrement integer with no meaning, for the machine to join on) and
a **natural key** (an email, an order number — for humans, possibly mutable).
Mature schemas carry both and never confuse their jobs. When you see a table
with both an `id SERIAL PRIMARY KEY` and a `unique email`, you are looking at
exactly this lesson.

---

## Part 8 — When "the id survives X" is a lie you can afford, and when it isn't

One concrete decision from the work captures a subtle general principle.

We wanted the rule "an object's id survives the user changing its layer (its
color group)." It seemed obviously right — identity should not depend on a
cosmetic attribute, just as a component's id survives a rename.

Then we read how "change layer" is actually implemented: it **deletes** the
object and **recreates** it on the new layer. A recreate goes through the birth
funnel, so it mints a *fresh* id. To honor "id survives," we would have had to
*rewrite* the change-layer operation to carry the old id through the
reconstruction — a real change to how the program behaves, not the additive,
behavior-preserving stamp the rest of the feature was.

So we let reality win and *documented* the honest rule: a layer change
reconstructs the object, therefore it gets a new identity; the old handle
dangles. The lesson generalizes:

> An invariant of the form "identity survives operation X" is **free** only when
> X is an *in-place edit*. When X is implemented as *destroy-and-rebuild*,
> preserving identity across it is a deliberate behavioral choice with a cost.
> Notice the difference before you promise the invariant.

A rename was in-place (edit a field) → id survives, cheaply. A layer change was
destroy-and-rebuild → id does not survive, unless you pay. Same program, two
"attribute changes," opposite answers — decided entirely by *implementation
shape*, not by intuition.

---

## Part 9 — How did we know any of this actually worked? (the testing thread)

A correctness claim you did not *test for its failure* is a guess. Three habits
from this work, each a transferable lesson:

**1. Characterize before you change.** Before touching the code, we wrote tests
that pinned down the *current* behavior — including the buggy index-dangle — and
made them pass. Now the refactor has a tripwire: if the "no-op" funnel (Part 4)
changes anything observable, a test that was green goes red. You cannot safely
refactor code whose behavior you have not first nailed down.

**2. Red-first.** Every test for the new id feature was committed **failing**,
*before* the C code existed. Why bother? Because a test you have only ever seen
pass might be passing for the wrong reason — testing nothing, asserting a
tautology, or never actually running. Watching it fail first, then pass after
your change, proves the test is wired to the thing you built.

**3. Sabotage the green bar.** The deepest one. A 100%-green suite tempts you to
believe your code is exercised. It may not be. So we *deliberately broke the
implementation* — made the id-stamp write a constant `42` instead of the counter
— rebuilt, and re-ran. Ten tests went red. That is the proof the tests are
actually reaching the stamp: if vandalizing the code changes nothing, your tests
were *green but hollow*, guarding nothing. Then we reverted and confirmed green
again.

> **Transferable lesson:** "the tests pass" is evidence only if the tests can
> *fail for the right reason*. Make them fail on purpose — by withholding the
> code (red-first) and by sabotaging it (mutation testing) — or you do not yet
> know what your green bar is worth. This idea, generalized and automated, is a
> real field called *mutation testing*: systematically mutate the program and
> measure how many mutants your suite catches.

---

## Part 10 — The shape of the whole thing

Step back and the solution is small — a field, a counter, a funnel, a scan — but
each piece is a named, reusable idea:

```
identity ≠ address                     (Part 0,1)  the founding distinction
a position is a fact about NOW         (Part 1)    not a durable name
manufacture identity; don't borrow it  (Part 2,3)  not index/pointer/user-name
monotonic counter ⇒ never reused       (Part 3)    so staleness is DETECTED
stamp at one chokepoint                (Part 4)    funnel first, then change
keep ONE source of truth; scan it      (Part 5)    a cache is a 2nd truth to rot
never-reused defeats ABA               (Part 6)    same cure as lock-free tags
surrogate key + natural key            (Part 7)    two ids, two jobs
"survives X" is free iff X is in-place (Part 8)    know the op's shape
make tests fail before trusting green  (Part 9)    red-first + sabotage
```

You will meet every row of that table again — in a garbage collector that moves
objects but keeps handles valid, in an ECS that hands out generational indices,
in a database schema that separates surrogate from natural keys, in a lock-free
queue that version-tags its pointers, in an OS that gives you a file
*descriptor* (a stable handle) instead of a raw disk offset. They are all the
same insight wearing different clothes:

> **Give things an identity you control, separate from where they happen to
> live, and never reuse it — so that "is this still the thing I meant?" always
> has an honest answer.**

---

## Exercises

1. **Feel the bug.** In any language, make an array of structs, hand out an
   index, delete an earlier element with compaction, and show the index now
   names the wrong struct. Then fix it with a monotonic id + scan.

2. **The hole alternative.** Re-do exercise 1 using tombstones (mark-deleted)
   instead of compaction. Show that index stability returns — and then show the
   ABA bug by reusing a tombstoned slot for a new object. Conclude why "never
   reuse the id" matters even when the slot is reused.

3. **Generational index.** Implement the `(index, generation)` handle scheme:
   a slot array, a free list, a generation bump on free, and an O(1) `lookup`
   that rejects stale handles. Compare its code complexity and its lookup cost
   to the id-in-struct + scan scheme. For what `n` and query rate does each win?

4. **Mutation test by hand.** Take any function you believe your tests cover.
   Introduce three small bugs (flip a `<` to `<=`, change a `+` to `-`, return a
   constant). For each, does a test go red? Every mutant your suite fails to
   catch is a test you are missing. Write it.

5. **Spot the natural-key trap.** Find a schema or API that uses a mutable,
   user-facing value (email, username, file path, display name) as a stable
   identifier. Describe the bug that appears when that value is reused or
   changed, and design the surrogate-key fix.

---

*This tutorial was distilled from a real feature — adding session-stable handles
to wires, components, and shapes in the XSCHEM editor. The production write-ups
live alongside it: `stable_handles_extension_strategy.md`,
`graphical_lifecycle_census.md`, the `doc/stable_*_handles.md` manuals, and the
`introspection_probes/probe*.tcl` demonstrations. The point of this document is
not those files; it is the handful of ideas in the table above, which outlast
any one program.*
