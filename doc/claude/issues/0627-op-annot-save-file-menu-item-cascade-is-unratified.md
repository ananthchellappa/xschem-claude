# 0627 — where does `Create device OP .save file` belong in the menus?

STATUS: **SETTLED 2026-08-29 — RATIFIED AS SHIPPED under the user's instruction "decide the 23"; nothing moves, no code change. See the RULING at the foot of this file.** Originally filed as a ratification, not a defect. Shipped 2026-08-22 by the S3
crew under decision-ladder rung **L3**: the choice is user-visible, no prior
ratification covers it, so it was implemented and the exact question handed over.

---

## WHAT SHIPPED

`src/xschem.tcl`, in the **Simulation > Graphs** cascade, immediately after
`Add device OP annotator`:

```
Simulation > Graphs
    …
    Annotate Operating Point into schematic
    Add device OP annotator
    Create device OP .save file        <-- new
    Live annotate probes with 'b' cursor
    Hide graphs if no spice data loaded
```

Guardian: `tests/headless/test_op_annot.tcl` row **W29**, which asserts the item
exists, that the entry **above** it is `Add device OP annotator`, and that all
three of its outcomes (wrote a file / nothing to save / raised) reach the user as
text. W29 needs a display and self-skips under `--nogui`.

## THE ARGUMENT FOR WHERE IT IS

The three op_annot items sit together, so a user who found one finds the other
two. Its output is consumed by the same OP-annotation loop as the two above it.

## THE ARGUMENT AGAINST

It is not a *graph* item at all: it generates a `.save` file you `.include` into
a testbench, which makes it netlist-adjacent. A user looking for it would
plausibly look under `Simulation` directly, or in the `Netlist` cascade beside
the other file-producing verbs.

## THE ALTERNATIVES, AND WHY THEY WERE NOT TAKEN

* **a top-level `Simulation` item** — a larger diff, and it separates the item
  from the two it belongs with. No measured advantage.
* **the `Netlist` cascade** — same objection plus a worse one: the item does not
  produce a netlist, and sitting next to `Netlist` invites the reading that it
  replaces one.

**THE QUESTION FOR THE USER: Simulation > Graphs, or a top-level Simulation
item?** Moving it is a one-line change and no test outside W29 depends on the
position.

*(This is attempt 4's D9 returning unanswered; the plan's `:15315`/`:15324`
anchors for it are stale — the cascade is built at src/xschem.tcl:15440 onward.)*

---

## RULING — 2026-08-29, decided under the user's instruction "decide the 23"

**STATUS: CLOSED — RATIFIED AS SHIPPED. No code change.**

`Create device OP .save file` **stays in `Simulation > Graphs`, immediately below
`Add device OP annotator`.** It is not promoted to a top-level `Simulation` item
and it does not move to the `Netlist` cascade.

### What was verified in the tree before deciding

* `src/xschem.tcl:16179` — the item, label `{Create device OP .save file}`,
  `-command` calling `op_annot::write_save_file` with the two failure messages
  inline. It is the only occurrence anywhere in the tree (one `grep` hit outside
  `doc/`).
* `src/xschem.tcl:16154` — `Add device OP annotator` is the entry directly above
  it; `src/xschem.tcl:16091` — `[annot_lbl_annotate_op]` (`Annotate Operating
  Point into schematic`) directly above that. The three sit together as the issue
  claims. (The file note's `:15440` anchor is stale; the cascade is created at
  `src/xschem.tcl:16081-16082`.)
* `tests/headless/test_op_annot.tcl:9985` — W29 reads the cascade's entries and
  asserts the neighbour by label, so position is pinned by exactly one row, as
  the issue says.
* `src/op_annot.tcl:2696` — `write_save_file` calls `::op_annot::save_cards`, the
  same producer ASE-L's blanket uses (`src/ase.tcl:804`), confirming the item and
  the annotator above it are two ends of one loop.
* `src/ase_window.tcl:496-510, 3435` — the **Cadence-shaped** route already
  ships inside ASE-L: `Outputs > Save All… > Save device OP parameters (gm, gds,
  vth, ...)`.

### Why

1. **Cadence or nothing cuts against promoting it.** In Virtuoso the schematic
   window owns no output-saving control at all; ADE does. Our ADE is ASE-L, and
   its `Outputs > Save All… > Save device OP parameters` tick already ships and
   already drives the same card producer. This menu item is therefore the manual
   escape hatch for a hand-written testbench you `.include` the file into — real
   and worth keeping, but *not* the Cadence route. Giving a non-Cadence
   convenience its own top-level `Simulation` slot would rank it above the
   Cadence path, which is backwards.
2. **The "it isn't a graph item" objection, taken seriously, argues for moving
   all three — not this one.** `Annotate Operating Point into schematic` and
   `Add device OP annotator` are no more graph items than this is. Moving only
   the third splits the trio *and* leaves the mismatch it was meant to fix. And
   moving all three is not on the table while issue 0683's redirection of
   annotation into ASE-L is still in flight.
3. **It feeds the entry directly above it.** Without these `.save` cards every
   `params` row of the annotator renders blank (issue 0617). Adjacency is the
   cheapest possible hint about that dependency; distance would cost it.

### What is NOT decided here

Nothing about *whether* the item should exist, its refusal behaviour on a
modified sheet (0628/0632/0633), or the ASE-L label drift (0661). Only its home
in the menus.

### Line the user gets

> The **Simulation → Graphs** menu keeps **Create device OP .save file** right
> under **Add device OP annotator** — the three operating-point items stay
> together, and the ADE-style route stays where Cadence users expect it, in the
> Netlist-and-Run window under **Outputs → Save All…**.

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29:

> **"decide the 23, leave 0861 and 0299 for me"**

The ruling queue stood at 57 entries and the user had said more than once that
the reading burden was too heavy. A read-only audit classified 25 of them as
questions whose answer is cheap and obvious; **0627 was one of the 23** the user
then handed over to be decided. (0861 and 0299 were excluded and remain theirs.)

This section is the settled record. It **supersedes the draft ruling immediately
above it** on two points, both flagged by the adversary and both re-verified
here: the *Line the user gets*, and the claim in that draft's reason 2 that
issue 0683 is "still in flight". Nothing above is rewritten; read this section as
the authority where the two differ.

### The ruling, as an instruction to the codebase

**`Create device OP .save file` stays in the schematic window's
`Simulation > Graphs` menu, immediately below `Add device OP annotator`
(`src/xschem.tcl:16179`). Do not promote it to a top-level `Simulation` item.
Do not move it to the `Netlist` cascade.**

The ADE-style route stays where it already ships — inside the Netlist-and-Run
window (ASE-L), at `Outputs > Save All… > Save device OP parameters (gm, gds,
vth, ...)`. Row **W29** in `tests/headless/test_op_annot.tcl` continues to pin
the position and stays exactly as it is.

### Why

**The leg that carries it: the item feeds the entry directly above it.**
Without these `.save` cards, every `params` row of the annotator placed by
`Add device OP annotator` renders **blank** — that is invariant **I3**'s blank,
and it is the exact silent failure issue **0617** is still open on (its display
half is unfixed). Producer sitting next to consumer is the cheapest possible
hint about that dependency, costs nothing, and distance would throw it away.
That alone settles the tie-break.

**Two supporting points, each weaker than it first looks — recorded honestly so
nobody rebuilds the argument on them:**

* *Cadence or nothing* points away from promoting the item, but not as strongly
  as the draft above claims. In Virtuoso the schematic window owns no
  output-saving control at all; ADE does, and our ADE (ASE-L) already ships that
  path. So this menu item is the **manual escape hatch** for a hand-written
  testbench, not the Cadence route. But the two controls live in **two different
  windows and are never on screen together**, so a top-level `Simulation` slot
  could not literally "rank above" the Cadence path — the user perceives no
  ordering between them. The point survives as a statement of which route is
  primary; it does not survive as a ranking argument.
* The "it isn't a graph item" objection, taken seriously, argues for moving
  **all three** op-annotation items, not this one — `Annotate Operating Point
  into schematic` and `Add device OP annotator` are no more graph items than
  this is, and moving only the third splits the trio while leaving the mismatch
  it was meant to fix. **Correction to the draft above:** the reason all three
  are off the table is *not* that issue 0683 is in flight. 0683 reads **FIXED /
  LANDED 2026-08-25 (attempt 2)** and 0682 reads **IMPLEMENTED 2026-08-25,
  RATIFIED 2026-08-29**. What is actually open in that area is **0809** (the
  annotation mask leaking into a new window with a null stamp) — a
  binding-lifetime defect, not the redirection. A wholesale move of the trio is
  simply out of scope for 0627, which asks only where *this* item lives.

Note too that the "trio" is **not uniform**: `src/xschem.tcl:15693` and `:16119`
are the only two `ase::annot_binding_ok` guard sites, so `Annotate Operating
Point into schematic` refuses without a bound ASE-L session while
`Add device OP annotator` and `Create device OP .save file` do not. They are
neighbours, not clones.

### What was verified in the tree

* `src/xschem.tcl:16179` — the item ships with label `{Create device OP .save
  file}` calling `op_annot::write_save_file`. A tree-wide `grep` outside `doc/`
  returns this one occurrence plus three references in
  `tests/headless/test_op_annot.tcl`; there is no duplicate menu entry anywhere.
  (`sky130A/sky130_procs.tcl:235`'s `Create FET .save file` is an unrelated
  PDK-cascade sibling, not a second copy.)
* `src/xschem.tcl:16154` — `Add device OP annotator` is the entry immediately
  above it, with only comments between the two `add command` calls.
  `src/xschem.tcl:16091` — `[annot_lbl_annotate_op]` (`Annotate Operating Point
  into schematic`) immediately above that. The three are contiguous.
* `src/xschem.tcl:16081-16082` — the Graphs cascade is created here.
  **The closing note earlier in this file citing `:15440` is stale**; so were
  attempt 4's `:15315`/`:15324`. Later readers: use `:16081`.
* `src/xschem.tcl:15349` — `annot_lbl_graphs` really does return `Graphs`, so
  the menu name printed in the user-facing line below is accurate.
* `tests/headless/test_op_annot.tcl:9978-10027` — row **W29** hardcodes the
  widget path `.menubar.simulation.graph` **and** asserts the neighbour label
  `Add device OP annotator`. Promotion would therefore break it on **two**
  counts, not one — a correction in the decider's favour to this file's earlier
  "one row pins the position".
* `src/op_annot.tcl:2696` — `write_save_file` calls `::op_annot::save_cards`,
  writes `$netlist_dir/<cell>.save`, opens a text window on it under `has_x`,
  and returns `{}` having written nothing when there are no cards.
* `src/ase_window.tcl:496-510` and `:3435` — ASE-L already ships
  `Outputs > Save All…` with the checkbutton `Save device OP parameters (gm,
  gds, vth, ...)`; `src/ase.tcl:804` confirms that blanket drives
  `op_annot::save_cards`, i.e. the **same producer**.
* `src/ase.tcl:814-845` — but **not the same output**. ASE-L's tick writes **no
  file at all**: it injects the cards straight into the deck ASE-L is about to
  run and reports `device OP save card(s) added to the deck`. The menu item
  writes a real `.save` file. They are two different deliverables from one
  producer, and the user-facing line below now says so.
* `src/ase_window.tcl:3410-3425` — this branch's own recorded rule on printed
  menu paths: one that drops the ellipsis "or misses a cascade level is a wrong
  direction printed with authority, which is worse than printing none." The
  draft line above stopped at `Outputs → Save All…` and omitted the checkbutton
  the user actually clicks. Fixed below.

### Does this move any code?

**No. This ratifies what already ships.** No file changes, no label changes, no
test changes. `Simulation > Graphs` keeps the item where it has been since
2026-08-22 and W29 keeps guarding it.

### Two things found while deciding, deliberately NOT treated as grounds to move

Scoped out of 0627, but recorded so they are not lost:

1. **The same producer refuses on a dirty design from ASE-L and does not from
   this menu item.** `src/ase.tcl:814` bails out on `ase::design_is_dirty` with
   a written explanation; `op_annot::write_save_file` walks anyway. That
   inconsistency belongs to **0632/0633**, whose ruling is still the user's.
2. **The "nothing to save" sentence is minted twice, in two spellings** —
   inline at `src/xschem.tcl:16182-16186` and again at `src/ase.tcl:841-844`.
   That is the **D5-4** shape (one sentence, one place) already filed as
   **0661**. Not fixed here.

### Line the user gets

> The **Simulation → Graphs** menu keeps **Create device OP .save file** right
> under **Add device OP annotator**, so the three operating-point items stay
> together. That item writes a real file — `<cell>.save` in your netlist
> directory — for you to `.include` in a testbench you wrote by hand.
>
> If instead you want those device parameters in a run you launch from the
> **Netlist-and-Run** window, that is a different control in a different window:
> tick **Outputs → Save All… → Save device OP parameters (gm, gds, vth, ...)**.
> It puts the cards straight into the deck it is about to run and does **not**
> write a `.save` file, so don't go looking for one.

*(Amended from the draft above, which called the two "the same route" and stopped
one cascade level short of the box you tick — both errors the adversary caught.)*

### Adversary

An adversary ran against this ruling and **could not overturn the placement.** It
knocked out one supporting argument as rhetorical, corrected the 0683 status, and
broke the user-facing sentence twice; all three corrections are folded in above.
Its own summary: *"I tried to break this and could not break the placement. I did
break one sentence of it."*

---

**The user may reverse this at any time; it was decided to spare their attention,
not to bind them.**
