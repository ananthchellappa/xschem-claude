# "It passed" is not "it is correct": five lessons from reviewing green code

*A lessons-learnt tutorial from one concrete episode: an adversarial code review of
a change that was **already written, tested, committed, and pushed — with a fully
green suite** — and the string of real bugs that review, and the act of *verifying
its fixes*, then uncovered. The bug is incidental. The subject is what a passing
test suite does and does not prove, and the habits that catch what it misses.
Written for a CS-literate reader; it leans on human analogies because a picture
outlives the abstraction.*

> **Companion reading.** The technical thread this reflects on:
> `net_highlight_hierarchy_and_linked_windows.md` and its
> `..._agent_guide.md` (the deep-gap net-highlight relay), and the earlier method
> tutorial `lessons_multi_agent_orchestration.md`. This document is about the
> *review round* that followed — how green code still hid bugs, and how they were
> found.

---

## Part 0 — The episode, in one breath

A "deep-gap net-highlight relay" had just been built for XSCHEM (a hierarchical
schematic editor in C+Tcl): when a net is highlighted in a window descended two-plus
levels into a subcircuit, and a linked window sits at a different depth with no window
loaded at the intervening level, the relay transiently loads each intermediate
schematic and translates the highlight one hop at a time so the far window lights the
right net. It shipped with a GUI regression test (**44 checks**) and a set of headless
tests. **All green.** Committed. Pushed.

Then an independent, adversarial review was run over the change — and found real
correctness bugs the 44 passing tests had never touched. Fixing one of them required
writing a *verification* test, and writing that test surfaced *yet another* bug in a
neighbouring subsystem. Five distinct lessons fell out of that round; each is below,
with the human picture that makes it stick.

---

## Part 1 — The thesis: a green bar is evidence of presence, never of absence

Here is the whole tutorial in one sentence, before the stories that earn it:

> A passing test proves the code does what you **thought to check**. It can never
> prove there are no bugs on the paths you never imagined — and the instrument that
> would notice is usually the same mind that wrote both the code and the test, so it
> agrees with itself. Correctness needs a **second instrument**: an independent
> reviewer, a test that goes red when you delete the fix, and a positive signal that
> the run actually finished.

### Lesson 1 — Your own suite is your inner ear (green ≠ correct)

A pilot who flies into cloud loses the horizon, and something strange happens to the
body. Ease into a gentle bank, hold it steady, and the fluid in the inner ear
re-centres — so your own senses now *insist* the wings are level while the aircraft is
quietly tightening into a spiral. The instrument that produced the sensation is the
same one reading it, so it cannot detect its own error. The phenomenon has a name —
**"the leans"** — and it kills experienced pilots who trust it. What saves you is a
*different* instrument on a *different* physical principle: the gyroscopic horizon on
the panel, and ATC radar painting your track from the ground.

Your own test suite is your inner ear. It and the code it guards come from one mind and
one mental model of the spec, so a passing test is nearly a tautology: it asserts the
code does what the author already believes. The lethal paths are the ones that mind
never modelled — and where there is no test, there is no red bar to warn you. *Absence
of a failing check is not evidence of correctness; it is the absence of any check.*

This episode makes it concrete. The relay shipped **committed, pushed, 44 checks
green**. An independent review — a different instrument, with adversarial priors and no
stake in the author's convenience assumptions — then found three real correctness bugs
those tests never exercised: the relay translated highlights through *stale on-disk
topology* (Lesson 4); an introspection getter was *off by one* (Lesson 5); and the
headless harness was itself *hollow-green* (Lesson 2). The meter had read GREEN while
measuring the wrong quantity.

> **Rule.** Before you call code "correct," put a second instrument on it: an
> independent adversarial review by a *different* mind (not merely more tests from your
> own), at least one **sabotage test** that goes red when the fix is deleted, and a
> completion signal the run can only emit if it truly finished. A green bar you wrote
> yourself is proof of the cases you imagined — never of the ones you didn't.

---

## Part 2 — Where the bugs actually were

### Lesson 2 — "Hollow green" recurs at every layer: the watchman needs a watchman

A test can pass without exercising the code. So can the *harness* that grades the
tests. Here the headless runner decided pass/fail by trusting the child process's exit
code — nonzero meant a crash or a failed check, zero meant success. Reasonable, except
`xschem --nogui --pipe --script` exits **0 even when an uncaught mid-script Tcl error
aborts the interpreter**. A case that printed only its per-check `ok` lines and then
collapsed halfway left exactly the footprint of a clean run: a truncated log ending in
`ok`, and a zero exit. The harness dutifully recorded **PASS**. Hollow green — one
level *above* the tests.

A night watchman is paid to walk the full perimeter every hour. The naive check is
"did an alarm ring?" — but silence is treacherous: a watchman asleep in the guardhouse
triggers no alarm either. "No alarm" is indistinguishable from "asleep." So real
facilities bolt a punch-clock to a post at each station, and the watchman must
physically punch the *final* station to close the round. Now the record shows positive
proof the whole route was walked; a missing final punch means the round didn't
complete, no matter how quiet the night.

The fix does exactly that. Each headless case now prints `OVERALL: ok` as its literal
last act, and `run_regression.tcl` passes a case only when **both** the exit code is 0
**and** that sentinel is present. A process that died mid-script cannot punch the final
clock, so its absence is treated as failure — *silence-by-default becomes
failure-by-default*, the safe direction. (`buried_hilight.tcl`, which had no `exit` at
all, gained both the sentinel and the exit.)

The deeper point is recursion: **the watchman needs a watchman.** Tests can be hollow,
the harness that grades them can be hollow, and CI above that can be hollow. Every
layer that renders a verdict is unverified until something independent checks it —
which is what the review pass, and the deliberate mid-script-error case that confirmed
the harness now goes red, provided.

> **Rule.** Never let a pass hinge on a purely negative signal. For every gate that
> judges success, require a **positive proof-of-completion emitted as the last action**
> and treat its absence as failure — then prove the gate by feeding it a mid-run abort
> and confirming it goes red.

### Lesson 3 — A convenient reload is a cache; a cache of live state is a bug waiting for the first edit

The relay walked a net across the hierarchy gap by loading each intermediate schematic
from disk and translating one hop at a time. The tidy decision was "load every hop
uniformly from disk." But the two *endpoints* of that walk are, by definition, already
open in windows — they are the source and target of the relay. Re-reading the shallow
endpoint from disk quietly re-materialised a **stale snapshot** of a schematic whose
live window may have been rewired, renamed, or re-pinned in memory since the last save.
The relay then translated the highlight through topology that no longer existed, and
lit the wrong net.

An author sits across the desk from you, marking up her manuscript in red ink. You need
to quote chapter three. Instead of leaning over to read the pages in front of her, you
walk to the library and photocopy the shelved first edition — because "one uniform
source for every quote" feels clean. Your quote is now wrong in exactly the passages
she just corrected. The disk file is the shelved first edition; the live window is the
author's marked-up desk copy; the highlight net name (the stale `CTRL` versus the
unsaved `CTRL2`) is the quote you get wrong. *The convenience of fetching a uniform copy
off the shelf is precisely what makes you misquote the person sitting in the room.*

The fix special-cases the shallow endpoint (`L == dS` in
`net_hilight_relay_reconcile`) to read the **live context** — the source directly for a
downward relay, or a borrowed target for an upward one. Only the genuinely windowless
intermediate hops still load from disk, where a reload is legitimate because nothing
owns them in memory.

> **Rule.** For mutable state, name the **single source of truth** — the live in-memory
> owner — and read *that*. A reload from a serialised store (disk, a snapshot, a cache)
> is valid only for data that is immutable or not yet loaded. When a loop treats
> endpoints (owned in memory) and interior nodes (unowned) identically, suspect the
> endpoints are being silently downgraded to a stale cache. "Uniform" is not a
> correctness argument.

### Lesson 4 — Copy-paste inherits the sibling's hidden assumptions (especially indices)

When XSCHEM needed a new introspection getter, `xschem get sch_inst_number`, the natural
move was to clone the getter right beside it, `get sch_path`. The sibling was mature and
well-tested; its no-argument default read `x = currsch` and returned `sch_path[x]`. The
clone kept that exact line. It compiled, it read cleanly, and it looked correct
*precisely because it matched its trusted neighbour.*

But the two arrays are indexed by different conventions. `sch_path[currsch]` **is** the
current level — the path array is written at the level it names. `sch_inst_number`,
though, is recorded during descent at the *parent* level (`sch_inst_number[currsch] =
inst_number`, `actions.c:3508`) and only *then* does `currsch++` (`actions.c:3516`). So
from the vantage of the now-current level, the slice that entered it lives at
`[currsch-1]`, and the raw element at `[currsch]` is stale or unset. The inherited
default quietly read the wrong cell.

Think of a fire-drill card copied from a colleague's building into your identical-looking
one: *"the defibrillator is on floor 2."* Both lobbies look the same — but their
building numbers the ground floor 0 and yours numbers it 1, so their "floor 2" is your
"floor 1." The instruction transfers verbatim, reads as obviously correct, and in an
emergency sends you one floor too high. The word that looked most portable — "floor 2" —
was exactly the one carrying an unstated origin.

The fix re-derived the convention from the data itself: read `sch_inst_number[x-1]`,
guard `x >= 1`, and special-case the top level (`x == 0` → `"1"`, no entering slice).
The corrected comment even names the trap: *"do NOT default to it (that was an
off-by-one copy of the sch_path getter)."*

> **Rule.** When you clone code, copy the **intent, not the bytes**: re-derive every
> index and edge convention from the new data's own semantics. The lines that look
> byte-identical to the sibling are not the safe parts you can skip reviewing — they are
> the prime hiding place for an assumption that was true next door and false here.
> Symmetry tempts a copy, and copies carry latent flaws.

---

## Part 3 — The one that matters most: verifying a fix is a bug-finding activity

Save the sharpest for last, because it is the one people skip.

There is a quiet difference between *checking that a bug is gone* and *proving that a fix
works*, and it shows up in what each one actually **touches**. A confirmation check
inspects the symptom: re-run the action, glance at the result, move on. A verification
test reconstructs the exact conditions the bug lived in and drives them *for real* — and
in doing so it becomes a **fault injector aimed straight at the neighbourhood of your
change.**

A plumber who has just re-soldered a leaking joint can wipe it, eyeball the solder, and
call it done — or he can cap the line and charge it to full working pressure. Only the
second finds the *next* weak joint downstream, the one that held under a trickle but
blows under real load. Pressure-testing the repair is how you discover the pipe's other
faults; the very act of proving one joint sound stresses its neighbours until a hidden
one gives.

That is exactly what happened. To prove the endpoint-live fix (Lesson 3) — that an
unsaved net rename in the primary window must surface the *live* name `CTRL2`, not the
stale on-disk `CTRL` — the author wrote a **sabotage-grade** test that made a *real*
unsaved edit (`xschem setprop instance l3 lab CTRL2`) and drove a *real* descend. A
"looks fixed" check would have stubbed both away. But the real edit plus descend tripped
XSCHEM's descend-autosave, which writes a `parent~.sch` **backing file** on
`set_modify(1)`. On the next run, `xschem load parent.sch` silently loaded `parent~.sch`
in its place — the backing file masquerading as the fixture — and the *separate*
single-window oracle test failed, because its `CTRL` net had been renamed out from under
it. The pressure test of one repair had exposed a completely separate latent bug in an
adjacent subsystem. The cure was fixture hygiene: delete stray `*~.sch` before loading
and again at teardown.

Notice the compounding with Lesson 1: reaching for the *external instrument* — a real,
discriminating verification test — is precisely what surfaced a fourth fault no one had
imagined. The sabotage test paid for itself twice: once by proving the fix (disable the
`L == dS` branch and *both* assertions flip to the stale `CTRL`), and once by finding
the fixture bug.

> **Rule.** Verify a fix by reproducing the **real** failure conditions end to end (real
> edit, real state transition, then a fresh run), never by asserting the symptom is
> gone. Treat every verification test as a fault injector pointed at your change's
> neighbourhood: budget time to chase the separate failures it kicks up, and add
> teardown/hygiene for any real side effect it creates on disk or shared state — so the
> test that proves your fix doesn't silently poison the next run.

---

## Part 4 — The playbook

Distilled, in order, for the next time you are about to trust a green bar:

1. **Treat your own green suite as your inner ear** — proof of the cases you imagined,
   nothing more. Get a *second instrument*: an independent adversarial review by a
   different mind.
2. **Demand positive proof-of-completion** at every judging layer (test, harness, CI):
   a sentinel emitted as the last act; absence = failure. Then feed the gate a mid-run
   abort and confirm it goes red. The watchman needs a watchman.
3. **Name the single source of truth for mutable state** and read it live; a reload from
   disk/snapshot/cache is valid only for immutable or unloaded data. Uniformity is not
   correctness.
4. **When you clone code, port the intent** and re-derive every index/edge convention
   from the new data. Stare hardest at the lines that look identical to the sibling.
5. **Verify by reproducing the real failure end to end** — a sabotage test that fails
   when the fix is removed — and expect it to unearth neighbours. Clean up its side
   effects.

## The one thing to remember

The suite was green, and the code was wrong — in three places, then four. None of the
bugs were exotic; each was a small, reasonable decision (trust the exit code; load
uniformly from disk; copy the neighbour's default; confirm the fix looks right) whose
hidden assumption a passing test could not see, because the same mind wrote the
assumption into both the code and the test. The bugs came out only when a *different*
instrument was applied — an outside reviewer, a completion sentinel, a sabotage test —
and the act of applying it kept finding more. **"It passed" is a hypothesis. "I tried to
break it, from outside my own head, and watched exactly the right thing fail" is the
closest you get to proof.**
