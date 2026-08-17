# 0430 — the prototype `.save` emitters use `getprop instance … spiceprefix` and drop the `x` on three shipped sky130 cells

Status: **open — measured, not fixed. The generic builder is the CORRECT one
here; the prototype is wrong.** Found by the S2 Verify-C adversary of the
op-annotation run (2026-08-16) on branch `annotate` when it widened the
acceptance diff from the 1 cell the step used to all 45 shipped sky130 test
cells; re-measured by the S2 write-up agent.

## What was measured

`sky130A/sky130_procs.tcl:78` and `ihp-sg13g2/sg13g2_procs.tcl:374/:453/:512`
read the SPICE prefix with

```tcl
xschem getprop instance $instname spiceprefix
```

That returns the property **only when the instance line spells it**. When
`spiceprefix=X` lives solely in the symbol's `template=`, it returns empty —
while `xschem translate` (which `op_annot::devpath` uses) resolves it correctly:

```
$ ./src/xschem --nogui --pipe -q --nolog --script x.tcl     # nfet_test_claude
getprop-spiceprefix   = {}
translate-spiceprefix = {X}
generic devpath       = {@m.xm1.msky130_fd_pr__nfet_01v8}
```

Three shipped sky130 test cells have exactly that shape — their instance line is
`C {sky130_fd_pr/nfet_01v8} … {name=M1 W=1 L=0.15 nf=1}`, with no
`spiceprefix=`:

```
sky130A/xschem_libs/sky130_tests/nfet_test_claude/schematic/nfet_test_claude.sch:12
sky130A/xschem_libs/sky130_tests/test_nfet_TRAN/schematic/test_nfet_TRAN.sch:24
sky130A/xschem_libs/sky130_tests/test_nfet_final/schematic/test_nfet_final.sch:12
```

On those three, the two builders disagree:

```
prototype (sky130_write_save_lines) : .save @m.m1.msky130_fd_pr__nfet_01v8[gm]
generic   (op_annot::devpath)       : .save @m.xm1.msky130_fd_pr__nfet_01v8[gm]
```

**The generic one is right.** Netlisting those cells emits
`XM1 D G GND GND sky130_fd_pr__nfet_01v8 …`, so the device really is `xm1` in the
deck and the prototype's `m1` names nothing. Per spec §6 landmine 9 a name that
names nothing does not blank for a kind-1 parameter — ngspice fabricates a `0.0`
column — so the prototype has been putting plausible zeros on those cells.

(`test_nfet_TRAN` also *contains* the string `spiceprefix=X` at line 41, but on a
different record; its nfet instance line at 24 does not carry it, which is why it
diverges too.)

## Why this matters to the plan, not just to sky130

Two things:

1. **It bounds an S2 claim that is quoted elsewhere.** "The generic builder
   reproduces the prototype byte for byte" is true tree-wide for IHP (49/49
   loadable `sg13g2_tests` cells, 0 mismatches) but **not** for sky130: 3 of 45
   cells differ, for this reason. S2's acceptance row `P3` asserts equality on
   `sky130_tests/test_nmos`, which happens to spell `spiceprefix=` on its
   instance lines, so the row is green and the divergence is invisible to it.
   Any later step that re-states "byte-identical, lost nothing" as a universal is
   overstating it.

2. **It is a user-visible change the moment S3 lands.** A user who regenerates a
   `.save` file for one of those cells gets different cards than the prototype
   produced. The new cards are the correct ones, so this is a fix rather than a
   regression — but it is unratified, and it is half of why S2 is status E.

## Fix

Delete the `getprop instance … spiceprefix` reads from both prototypes and use
`xschem translate <inst> @spiceprefix`. `op_annot::devpath` already does this
(`src/op_annot.tcl`, the devproc branch), and the S2 brief already forbade
porting the `getprop` idiom — this issue records *why* that instruction was
right, with the three cells that prove it.

Cheapest moment: **S5**, which deletes `sky130_write_save_lines` and
`sg13g2_write_save_lines` outright. At that point the divergence disappears
because there is only one builder left — which is invariant I1's whole point.
Until then the two disagree on these three cells and the prototype is the wrong
one.
