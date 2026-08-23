# 0627 — where does `Create device OP .save file` belong in the menus?

STATUS: **OPEN — a ratification, not a defect.** Shipped 2026-08-22 by the S3
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
