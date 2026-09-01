# 0633 — ASE refuses the OP save cards on a dirty sheet (PROVISIONAL, pending the 0632 ruling)

Status: **OPEN — a ruling is owed by the user.** Filed by plan step S4.
Related: 0617 (the user report), 0628, 0632 (the ruling this defers to), 0631.

## What shipped in S4

`ase::op_cards_capture` (src/ase.tcl) is the one place that decides whether the
op_annot device operating-point `.save` cards are built for an ASE run. It
refuses outright when the design buffer has unsaved edits:

```tcl
if {[ase::design_is_dirty]} {
  ase::echo "ASE: no device OP save cards were added — this schematic has
   unsaved edits, and walking a dirty sheet rewrites the `~` autosave backups of
   ancestor cells you never touched (issue 0632, ruling pending). Save the
   schematic, then netlist again." error
  return {}
}
```

The run itself proceeds normally: node voltages, the per-output `.save` rows and
every existing behaviour are untouched. Only the device-parameter cards are
withheld, and the withholding is reported.

## Why it is provisional and not a decision

Issue 0632 records that on a **dirty entry buffer** the S3 hierarchy walk
rewrites the `<cell>~.sch` autosave backups of ancestor cells the user never
touched, and 0628 records that over a **stale** backup it silently drops cards.
That ruling is with the user. Two behaviours are in dispute:

* **(a) refuse** — what S4 shipped. No cards, a sentence saying why.
* **(b) walk anyway** — what `op_annot::save_cards` does today when
  `autosave_backup` is on (the shipped default), accepting the ancestor-backup
  rewrite.

Adopting (b) inside ASE would have manufactured the 0632 ruling by shipping one
of the disputed behaviours as though it were settled, so S4 took the safe side
under the crew's pick-the-safe-one instruction (decision ladder L3).

Note that op_annot's own `_assert_saveable` gate is **not** the same gate: it
refuses only `modified=1 + autosave_backup=0`, and 0632's live hazard is
`modified=1 + autosave_backup=1`, which is the shipped default. That is why the
predicate lives in `ase.tcl` as `ase::design_is_dirty` rather than being folded
into `op_annot::_assert_saveable` — tightening the latter would also silently
change the shipped `Create device OP .save file` menu item and redden
test_op_annot's W31, both outside S4's scope.

## THE QUESTION FOR THE USER

> When the schematic has unsaved edits and `autosave_backup` is ON, should
> Netlist-and-Run **(a)** refuse the OP save cards and say so (as shipped), or
> **(b)** walk anyway and accept that the walk rewrites the `~.sch` autosave
> backups of ancestor cells the user never touched (issue 0632)?

A third option exists and was not taken because it is a bigger change than S4's
Files cell allows: make the walk read-only with respect to backups, which would
dissolve 0632 and make the question moot.

## Where it is pinned

`tests/headless/test_ase_core.tcl`, rows C11 and C12. C11 proves
`ase::design_is_dirty` really is `xschem get modified` in both directions; C12
stubs the predicate to 1 and proves capture never reaches
`op_annot::save_cards`, leaves the cache empty, and reports both the unsaved
edits and the open ruling. If the ruling lands on (b), C12 is the row to rewrite.
