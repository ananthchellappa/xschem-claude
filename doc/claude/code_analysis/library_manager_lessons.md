# How to Change Software That Is Already Used: Lessons from the Library Manager

*A teaching write-up for people who want to get good at changing real, messy,
already-working systems without breaking them. The running example is the xschem
"library / cell / view" project (see `library_manager_design.md`), but every
lesson is meant to transfer to whatever you build next.*

The task sounded simple: "the way schematics and symbols are managed is cluttered
— make it slick, like Cadence; introduce libraries, cells and views; ship
migration tools; keep the file format the same." That is a *re-architecture of a
core subsystem in a 25-year-old C/Tcl program that people use for real chip
design.* Here is how it was done in six shippable phases without ever breaking the
existing tool, and the general principles that made it possible.

---

## 1. Find the narrow waist before you write anything

The biggest fear with "introduce a whole new data model" is blast radius. The
codebase resolves symbol references in hundreds of places: loading, saving,
descending into a sub-schematic, netlisting to five formats, the GUI browser.

But when we actually traced the code, **every reference resolution funneled through
two Tcl functions**: `abs_sym_path` (reference → absolute file path) and
`rel_sym_path` (absolute path → portable reference). Save called one, load called
the other, descend and netlist called the first. Two functions.

That is a *narrow waist* (a.k.a. a chokepoint, a seam, an hourglass). When all the
flow passes through one thin point, you can change the world behind that point and
the rest of the system never notices.

> **Principle.** Before designing a big change, map the data flow and look for the
> point everything passes through. A change made at a narrow waist has small blast
> radius; the same change scattered across call sites is a months-long migration.
> The first deliverable of any refactor is *knowing where the waist is.*

If there is **no** narrow waist, that itself is the finding: your real first task
is to *create* one (introduce the function everyone should have been calling) and
route callers through it. You cannot safely change what you cannot funnel.

In this project the waist was so clean that Phase 3 (load/save round-trip) required
**zero new code** — teaching the two functions the new rules in Phase 2 had already
made placing, saving, loading and netlisting "just work." A verification phase that
finds nothing to fix is not a wasted phase; it is the waist paying off.

---

## 2. Backward compatibility is a fallback chain, never a flag day

The existing tool had to keep working *the entire time* — for users, for the test
suite, and for the thousands of `.sch` files already on disk that say
`C {nmos4.sym}`. The temptation is a "version 2 mode" switch. Resist it. A mode
switch doubles your states and forces every user to flip it on the same day.

Instead, resolution became an **ordered fallback chain**:

```
resolve(reference):
  1. absolute path / URL?        -> use as-is        (oldest rule)
  2. lib-qualified "lib/cell"?   -> new lib/cell/view layout
  3. otherwise                   -> legacy flat search of the path   (unchanged)
```

New behavior is tried *first*; on any miss it *falls through* to the old behavior,
which is byte-for-byte what it always was. Old files hit rule 3 and resolve exactly
as before. New files hit rule 2. A single file may mix both. Nobody has a flag day.

> **Principle.** Make new behavior *additive with fallback*, ordered most-specific
> to most-general. "It still does the old thing when the new thing doesn't apply"
> is the property that lets you ship a deep change to live users on a Tuesday.

A pleasant emergent effect: because rule 2 is tried before rule 3, an *old* file
that says `C {devices/res.sym}` automatically upgrades to the new layout once
`devices` is migrated — without editing the file. Good fallback chains don't just
preserve the past; they let it benefit from the future for free.

---

## 3. RED-first is a design tool, not a chore

Every phase followed the same loop: write a failing test first (RED), make it pass
(GREEN), then try to break your own success. Writing the test *first* forces you to
answer "what exactly should this do, and how will I observe it?" before you are
emotionally invested in an implementation. Several API decisions
(`xschem cellview_path lib/cell view`, the `library.defs` format) were really made
while writing the test, not the code.

The non-obvious half is the third step: **sabotage verification.**

> A green test suite only proves the tests pass. It does **not** prove your new
> code *ran*.

After every GREEN, we deliberately broke the new code (commented out the new
branch, made the new helper return `""`) and re-ran the tests. If a test *stayed*
green with the feature disabled, that test was **hollow** — it was passing for some
other reason and would never catch a regression. Only tests that turn RED when you
sabotage the feature are actually guarding it.

This caught a real hollow test here. A check asserted that netlisting a migrated
subcircuit emitted `.subckt sub`. It passed. But when we disabled the fix, *it
still passed* — because xschem emits the `.subckt` header from the symbol's pins
even when it can't find the schematic body. The header was not evidence the fix
worked. We strengthened the test to require the transistor lines (`M1`, `M2`) that
only appear if the schematic was actually located. *Then* it went red under
sabotage. That is the difference between a test and a decoration.

> **Principle.** For each test ask: "what single change to the product would make
> this fail?" If you can't name one, the test is hollow. Prove it by breaking the
> product on purpose.

---

## 4. Separate the pure core from the messy shell

The migration tool (`tools/migrate/xschem_libmigrate.py`) does filesystem surgery:
move hundreds of files, rewrite references, write registries. Filesystem code is
annoying to test (temp dirs, cleanup, ordering). So the design split it in two:

- **Pure functions** with no I/O: `build_index` (which cell lives in which
  library), `rewrite_reference` (one string in, one string out),
  `rewrite_text` (one file body in, one out). These are total functions of their
  inputs — trivially testable, no mocks, no temp dirs.
- **A thin orchestration shell** (`migrate`) that does the I/O and calls the pure
  core.

The bulk of the test suite hammers the pure core with edge cases
(`nmos4.sym`, `devices/res.sym`, generators with parentheses, absolute paths,
already-migrated idempotent inputs) at zero I/O cost. The shell gets a couple of
end-to-end checks. This is "functional core, imperative shell," and it is the
single highest-leverage structure for making code testable.

> **Principle.** Push decisions into pure functions; keep side effects in a thin
> rind around them. You test the decisions exhaustively and the plumbing lightly.

Two free properties fell out of writing the core as pure string transforms:
**idempotency** (running the migrator twice changes nothing the second time,
because rewriting an already-rewritten reference is a fixed point) and
**non-destructiveness** (the tool writes a new tree and never mutates the source,
so "undo" is `rm -rf`). Both are far easier to guarantee in a pure transform than
in code that edits in place.

---

## 5. To verify a transformation, compare *behavior*, not *bytes*

How do you prove that moving 500 files into a new directory structure and rewriting
163 references *didn't change what the circuits mean*? You cannot eyeball 500 files.
You cannot diff the bytes — the bytes are *supposed* to differ.

The answer is **differential testing on a semantic invariant.** For every migrated
schematic we asked the real engine for the one thing that must not change: its
**netlist** (the actual electrical circuit). Then:

```
for each schematic that exists in both trees:
    flat_netlist     = netlist(flat version)
    migrated_netlist = netlist(migrated version)
    assert  normalize(flat_netlist) == normalize(migrated_netlist)
```

155 schematics, 0 differences. That is a *proof of behavior preservation* far
stronger than reading files, and it is fully automated. The old system is its own
oracle: whatever it produced is the correct answer, and the new system must match.

> **Principle.** When you transform data or refactor code, find an observable that
> should be invariant, and assert old == new across a large, real corpus. You don't
> need to know the right answer in advance; you only need the two sides to agree.
> (This is "differential / characterization testing." It is how you refactor things
> you don't fully understand and still sleep at night.)

---

## 6. Normalize away the incidental, or your equivalence test cries wolf

The first equivalence run failed on a couple of schematics. The "difference" was a
line like:

```
.include /tmp/run_A/model.txt        vs        .include /tmp/run_B/model.txt
```

Same circuit. The only thing that differed was the *directory* the two test runs
wrote to — an artifact of the harness, not of the migration. If you compare raw,
your invariant test drowns in false positives and you stop trusting it.

So the comparison **normalizes the incidental**: it strips comment lines and
reduces `.include <path>` to its basename, because the directory is
deployment-specific while the file *name* is semantic. The skill is drawing that
line precisely: normalize the directory (incidental) but keep the filename
(semantic), so a migration that included the *wrong* file would still be caught.

> **Principle.** A differential test is only as good as its notion of "the same."
> Spend real effort deciding what is semantic versus incidental, and normalize away
> exactly the incidental — no more, no less. Over-normalize and you mask bugs;
> under-normalize and you cry wolf until everyone ignores the alarm.

---

## 7. A broad sweep finds the bugs you would never have thought to enumerate

We could have tested migration on the two or three schematics we understood well.
Instead the sweep ran over **every** schematic in **every** migrated library. That
breadth paid for itself by surfacing edge cases no human would have listed:

- `C {reg.sch}` — a reference with a `.sch` extension. It turns out xschem lets you
  instantiate a *schematic directly* (auto-generating a symbol), and such a cell may
  have **no symbol view at all**. The migrator had been blindly stripping the
  extension, turning `reg.sch` into `pcb/reg`, which then hunted for a symbol that
  did not exist — silently dropping a whole sub-circuit. The fix: preserve `.sch`
  (`reg.sch` → `pcb/reg.sch`). We would *never* have invented this test case from
  imagination; the corpus handed it to us.
- Libraries built on mechanisms that don't fit the new model at all — on-the-fly
  `.tcl` symbol *generators*, instance-level schematic *selection*, a library nested
  *inside* another library. The sweep flagged each as a netlist mismatch, and the
  honest engineering response was not to force them: **leave them flat, and write
  down why.** A migration that converts 12 libraries and clearly documents the 5 it
  deliberately skips is more trustworthy than one that claims to convert all 17 and
  quietly corrupts a few.

> **Principle.** Run new code over the largest pile of real inputs you can find, not
> the handful you understand. Real corpora encode decades of edge cases that your
> imagination does not. And when something genuinely doesn't fit, *excluding it on
> purpose with a documented reason* beats a forced conversion that breaks silently.

> **Corollary — no silent caps.** When you decide to skip, sample, or truncate, say
> so loudly (in the README, in the report, in the log). Silent scope-narrowing reads
> downstream as "everything was handled" — the most expensive kind of lie, because
> no one knows to check.

---

## 8. Borrow a proven ontology instead of inventing one

We did not invent a naming scheme for "a thing that has a schematic and a symbol."
The EDA industry settled that decades ago: **Library → Cell → View**, with a
`cds.lib`-style registry mapping a library *name* to a *directory*. We mapped the
new design straight onto that vocabulary (and onto the OpenAccess directory shape),
down to a `library.defs` that behaves like `cds.lib`, including the convention that
relative paths resolve against the registry file's own location.

The payoff is twofold: experienced users already know the mental model (zero
learning curve), and a battle-tested ontology has already discovered the corner
cases you would otherwise hit one at a time.

> **Principle.** Before designing a new abstraction, find out whether your problem
> domain already has a standard one. Reusing a proven model buys you both user
> familiarity and a pre-debugged design.

---

## 9. Decide the irreversible things on paper first

Before a single line of engine code, Phase 0 was a written design-and-decision
record, and the genuinely hard, expensive-to-reverse choices were put to the user
explicitly: *How are data files named inside a view directory? How is a reference
spelled? How are libraries registered?* Those choices ripple through every later
phase; changing one after Phase 4 would mean redoing Phases 1–4.

The cheap, reversible choices (which helper function, which file to put a proc in)
were just *made* and noted. The expensive, irreversible ones were *ratified* before
they could metastasize.

> **Principle.** Spend your "ask and deliberate" budget on the decisions that are
> costly to undo and that constrain everything downstream. Make the cheap,
> reversible decisions quickly and move on. Confusing the two — agonizing over a
> variable name while sleepwalking past a file-format choice — is a classic failure
> mode.

---

## 10. Ship in increments that each stand on their own

The work was six phases — registry, resolver, round-trip, descend, migration tool,
data migration — and **each one was independently shippable, tested, and committed**
before the next began. At no point did the repository sit in a broken half-migrated
state for days. If the project had been cancelled after Phase 2, Phase 2 would still
have been a coherent, working improvement.

This is the difference between a *long-lived branch that scares everyone* and a
*sequence of small, reviewable, reversible steps.* It also keeps a human in the loop
at every boundary: each phase ended with a summary and a genuine choice about what
to do next.

> **Principle.** Decompose a big change into increments that are each correct on
> their own and leave the system working. "One giant correct commit" is a myth; "a
> chain of small correct commits" is how real systems move.

---

## The shape of the whole thing

```
Phase 0  decision record         (paper)        decide the irreversible things
Phase 1  library registry        narrow waist   read-only, additive
Phase 2  resolver (lib/cell/view) narrow waist   the fallback chain lives here
Phase 3  save/load round-trip    verify only    the waist already covered it
Phase 4  descend + netlist       one real bug   same waist serves 2 callers
Phase 5  migration tool          pure core      functional core / thin shell
Phase 6  migrate the repo data   differential   155 netlists, 0 diffs, sweep
```

None of these ideas is specific to schematics, Tcl, or EDA. They are the general
craft of changing software that people already depend on:

1. find the narrow waist;
2. make change additive with a fallback chain;
3. write the test first, then sabotage it to prove it bites;
4. pure core, imperative shell;
5. verify transformations by comparing behavior, not bytes;
6. normalize away the incidental, precisely;
7. sweep over real corpora, and exclude misfits out loud;
8. borrow proven ontologies;
9. ratify the irreversible decisions on paper first;
10. ship self-standing increments.

Learn these on a small project and they will scale to a large one. The library
manager was "just" a directory reshuffle for a schematic editor — but the way it
was done is how you change the engine of a moving car.
