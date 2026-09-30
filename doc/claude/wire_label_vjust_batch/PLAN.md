# PLAN — wire_label_vjust_batch

New-list wish item **2**, the "vertical justification" half: *"Wire labels creation in schematic view
with Cadence UX … (need to add support for vertical justification, and place multiple members of bus
in one shot)"*.

Stage R is **done** — `receipts/R-recon-vjust.md`, three parallel read-only crews. **Read it first.**

Opened 2026-09-29 at `1f42914d`. T1 baseline `112/111/0/8` (`tests/results.1010173.log` at
`80dc3bbb`).

## The semantics, settled by the user and NOT open

The user labels a bus by typing a comma-separated token list — their example,
`bg_trim<3:0>,en_fast,iref_trim<2:0>`. The flag controls that list's layout:

* **off** — one line
* **on** — stacked, one token per line, **single-spaced, NO blank line between them**

`busname<3:0>` alone renders identically either way — a single token has nothing to stack. It is
**opt-in**, so the existing (currently disabled) checkbox is the right control. It is **not**
rotation and **not** `hcenter`/`vcenter` re-anchoring; both were proposed by the driver and withdrawn.

## What Stage R established, and what it forbids

1. **Multi-line rendering already works** end to end at **1.1470×** font height on every export
   path. The spacing requirement is already satisfied. No new rendering engine is needed.
2. ⚠⚠ **A newline must NEVER reach the stored `lab=`.** Measured: a SPICE card split across physical
   lines, and the bus expander swallowing the newline as whitespace and **concatenating** tokens into
   wrong bit names. Stacking is a **display** transform over a canonical stored label.
3. ⚠⚠⚠ **`<3:0>` is not a bus range in xschem** — `<` and `>` are ordinary identifier characters in
   `parselabel.l`. `bg_trim<3:0>` is ONE scalar net whose name contains `<3:0>`, and a bus wire
   labelled that way netlists **silently wrong** (measured: `expandlabel` gives 3 where 8 is
   correct, and the short list is cycled over the wide pin with zero warnings). The form already
   normalises `<>`→`[]` through `addlabel::expand_names`, which is the only path to
   `::label_new_name` — so **there is no existing behaviour of displaying angle brackets**, and the
   canonical stored form is comma-separated **and** `[hi:lo]`.
4. **The comma is already a label separator.** The user's example places **three** labels today via
   the queue (`start_pass` → `pending` → `arm` → `after_drop`). So this flag changes
   **tokenisation**, not only display: with it on, the same typed text must become ONE label whose
   `lab=` is the whole comma list. Branch in `addlabel::expand_names` / `start_pass`, and **do not
   alter `expand_names`'s existing contract** — 14 rows pin it and its comma/whitespace equivalence
   is load-bearing for the multi-label queue.

## Stage A — stack the tokens (issue number to be minted by the driver)

**Deliverable:** working code + fence, uncommitted, receipt `receipts/A-vjust.md`.

Red first. Scope: the checkbox becomes live; with it ticked, a comma-separated label is stored
canonically as one label and **rendered** as one token per line.

### ⚠ The mechanism is UNRESOLVED and it is the crew's call

Stage R's two crews disagree, and both arguments are sound. The crew must choose, justify, and
**prove the constraint holds**:

* **Angle 1** — a derived token (e.g. `@lab_vstack`) resolved inside `translate()` (`src/token.c`).
  For: all six sites that render or measure a symbol's text go through `translate(n, text.txt_ptr)`,
  so one edit covers screen, SVG, PS/PDF, bbox and hit-test at once — which is the codebase's own
  invariant **I1** ("four copies, one builder"), recorded in `src/xschem.h` above `text_hidden()`
  along with what the alternative cost last time.
* **Angle 2** — a per-instance token `text_vjust_<n>=`, read by a new helper in `src/draw.c` beside
  its two existing siblings `get_sym_text_layer()` and `get_sym_text_size()`, called at the six
  sites. Against Angle 1: `translate()` has **77** callers including `netlist.c`,
  `spice_netlist.c`, `spectre_netlist.c`, `verilog_netlist.c` and `save.c`, so a newline produced
  there could reach a deck.

**The binding constraint, whichever is chosen: no newline may reach any netlist, save or expansion
path.** Fence that directly — a row that netlists a stacked label and asserts the deck is
single-line per card is worth more than any number of rendering rows.

The per-instance requirement is real either way: the visible text belongs to the **symbol**
(`draw_symbol()` copies out of the shared `symptr->text[j]`), so the flag must travel by instance.
`get_sym_text_layer()` is the exact precedent to imitate, including its mandatory
`xctx->tok_size = 0;` else arm.

### Out of scope

* **Displaying angle brackets.** Today the form normalises to `[3:0]` and the drawn text matches the
  netlisted name. Keep that. Whether the user wants to *see* `<3:0>` is on their queue and is a
  small delta to the display transform afterwards.
* **The other checkbox** (`place_multiple`) and whether `split_bus` defaults ON — two of the four
  ruling questions, still unasked.
* Fixing the `<3:0>` silent-netlist hazard for labels created outside the form. Filed separately.

## Driver-retained

Issue number and `NUMBERING.md`; the issue file and its `**STAMP:**`; the solo T1 gate in a fresh
short-path clone; commits and the push; filing rulings; judging whether a red is real.

## Stage A collected 2026-09-30

Issue **1623** delivered, receipt `receipts/A-vjust.md`, gated by the driver. Mechanism: Angle 2
(`sym_text_vstack()`, six sites, per-instance `vjust=`), with Angle 1 rejected on evidence rather
than preference — see the issue file.

**The finding that outlives the feature:** the driver demanded a netlist fence and specified it as
*"prove it by measurement, not by reasoning about call graphs"*. The crew built that fence, and it
**could not detect the rejected design** — a plain `lab_pin` top emits no deck line that routes
`@lab` through `translate()`, so the deck was byte-identical either way. A measurement can encode the
same blind spot as the argument it was meant to replace. The row that actually holds the boundary
asserts the *expansion* (`xschem translate <inst> {@lab}` has zero newlines), not the *deck*.

Still open and carried out of this batch: `rule/1623` (Split bus is silently ignored when Vertically
justified is ticked), two `look` debts on the stack's appearance, and the `S3` fence specified as open
item 5 of the issue.
