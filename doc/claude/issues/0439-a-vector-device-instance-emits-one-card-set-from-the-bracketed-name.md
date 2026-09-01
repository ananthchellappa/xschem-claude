# 0439 — a VECTOR device instance (`name=M1[3:0]`) gets one card set built from the literal bracketed name

Status: OPEN, unmeasured (inspection only), not fixed. STUB filed by the S3b
implement agent (op-annotation crew, branch `annotate`).

⚠ **PARTLY ABOUT CODE THAT IS NOT IN THE TREE.** S3b was refuted (issue 0442)
and reverted; the save-card emitter is preserved in
`doc/claude/issues/0442-attempt-2-reverted.patch`. The hole in the two **PDK
prototypes** is real and still shipped; the half about `op_annot`'s emitter is a
standing requirement on whoever re-lands the walk.

Related: spec §5 I1, issue 0436 (the basis), 0437 (the filter). Both PDK
prototypes have the same hole.

## What it is

`op_annot::_walk` (src/op_annot.tcl) expands the multiplicity of a VECTOR
SUBCIRCUIT instance and visits each member:

```tcl
set ninst [lindex [split [xschem expandlabel $instname] { }] 1]
for {set n 1} {$n <= $ninst} {incr n} { ... xschem change_sch_path $n ... }
```

That arm is entered only when `type eq {subcircuit}`. A **device** instance
carrying a vector name — `name=M1[3:0]` on a symbol a descriptor claims — never
reaches it: `_cards_for` is called once with the literal string `M1[3:0]`, so
the block gets ONE card set naming a device that does not exist in the deck
under that spelling, instead of four naming `xm1[3]` … `xm1[0]`.

Per spec landmine 9 that does not blank at read time: ngspice writes a full 0.0
column under exactly the name it was asked for, so the failure surfaces on the
schematic as a plausible zero rather than as a blank (I3).

`sg13g2_hier_sch_expand` (ihp-sg13g2/sg13g2_procs.tcl:395-417) and
`sky130_hier_sch_expand` (sky130A/sky130_procs.tcl:114+) both have the identical
hole, so this is inherited from the port and not introduced by it.

## Not measured

No shipped PDK test schematic instantiates a vector FET, so nothing in the tree
reproduces it today. The measurement owed is: place `name=M1[1:0]` on
`sky130_fd_pr/nfet_01v8.sym`, netlist, and read what element names
`xschem netlist` actually writes — the netlister is the oracle here exactly as it
is for issue 0437 (row S31).
