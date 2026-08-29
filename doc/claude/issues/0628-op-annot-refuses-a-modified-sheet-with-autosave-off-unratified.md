# 0628 — `op_annot::save_cards` REFUSES a modified sheet when autosave is off — ratify it

STATUS: **OPEN — a ratification, not a defect.** Shipped 2026-08-22 by the S3
crew under decision-ladder rung **L3**.

---

## WHAT SHIPPED

`op_annot::save_cards` (and therefore the `Create device OP .save file` menu
item) **refuses to run** when both of the following hold:

* `xschem get modified` is 1 — the sheet has unsaved edits; **and**
* `::autosave_backup` is 0.

The message names both halves and both remedies:

> this schematic has UNSAVED edits and `autosave_backup` is off. The walk
> descends and returns, and with no autosave backup to come back to that round
> trip silently REVERTS unsaved edits (issue 0626). Save the schematic, or turn
> Options > Autosave backup on, and click again.

Guardian: `tests/headless/test_op_annot.tcl` row **W31** — with autosave **on**
the same modified sheet is walked normally; with it **off** the call raises, and
the instance count, `modified` and `currsch` are all exactly where they were.

## WHY

Measured on a byte-copy of the shipped `sky130_tests_ase/bandgap_opamp`
(issue **0626** carries the full transcript): with `autosave_backup 0`, one
`descend` + `go_back` round trip **silently reverts** an unsaved edit and leaves
`modified` reading 1 over content that matches the disk. The walk does dozens of
such round trips.

save.c **RULING D5-1** — a plausible wrong answer is worse than none — applied to
data rather than to a displayed number: losing the user's unsaved work to a
*read-only annotation click* is the worst outcome available, and a refusal the
user can act on in two clicks is the least surprising alternative.

## THE ALTERNATIVE THAT WAS REJECTED

**Walk it anyway and accept the revert.** Rejected: it is silent data loss from a
menu item whose entire contract is that it changes nothing (invariant **I4**).

## THE ALTERNATIVE THAT IS NOT AVAILABLE HERE

**Fix `go_back`.** Correct, and out of S3's Files cell — its blast radius is
every descend/go_back user in the tree. Issue **0626** carries three options for
it. When one lands, this refusal should be relaxed and W31 rewritten.

**THE QUESTION FOR THE USER: refuse (as shipped), or walk it and accept that an
unsaved edit can vanish?**


---

## NOT RULED, 2026-08-29 — a ratification was drafted, OVERTURNED, and SPLIT

The user instructed *"decide the 23, leave 0861 and 0299 for me"*, and this debt
was one of the 23 a read-only audit had classified as cheap and obvious. A
decision was drafted — *refuse symmetrically: any schematic with unsaved edits,
whatever the Autosave backup setting* — and the adversarial pass **overturned it.**
No ruling was made on the half that is the user's. **Answer 0628 and 0632
together; they are one question.**

### The half that needs NO ruling, and should just ship

* **The refusal when Autosave backup is OFF is right.** `src/save.c:4508` returns
  early, so the walk's return trip is a plain reload from disk and the user's
  unsaved edit is gone. Silent loss, from a menu item that promises to change
  nothing. Nobody needs to be asked about that.
* **The wording must be re-minted in plain English, in one place both surfaces
  render** (PLAIN ENGLISH, RULING D5-4). Today `src/xschem.tcl:16181` hands the
  raised string straight to `alert_`, so the user reads a sentence opening
  `op_annot::save_cards:` and naming a variable `autosave_backup` — neither of
  which is a thing on screen. And `src/ase.tcl:817` still says *"issue 0632,
  ruling pending"* to a designer. Both are plain defects, not decisions.

### The half that IS the user's

Extending the refusal to the **shipped default** — unsaved edits *with* Autosave
backup ON — and promoting ASE's provisional refusal to permanent.

### And the drafted summary was factually wrong, which is why this matters

It told the user that both **Create device OP .save file** and **Netlist and Run**
"will now stop and ask you to save first." **Netlist and Run does not stop, and
never did.** `src/ase.tcl:905` is `catch {ase::op_cards_capture ...}` under the
comment *"an annotation extra can never break Netlist-and-Run"*, and
[0633](0633-ase-refuses-op-save-cards-on-a-dirty-sheet-provisional.md) says it in
one line: *"The run itself proceeds."* A ruling sold to the user on a false
description of what they would experience is worse than no ruling.
