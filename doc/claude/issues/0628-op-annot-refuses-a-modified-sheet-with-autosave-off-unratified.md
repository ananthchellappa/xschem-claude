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
