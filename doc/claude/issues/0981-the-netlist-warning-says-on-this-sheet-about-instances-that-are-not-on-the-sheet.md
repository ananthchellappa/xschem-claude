# 0981 — the netlist warning says "on this sheet" about instances that are not on the sheet, and names three of them identically

**Status: FILED, NOT FIXED (2026-08-30, item S4b write-up).** This is issue
**0974** exactly one layer down: the same pass that taught the annotation
surface to name a transistor the way the schematic names it shipped a new
netlist-time sentence that cannot name its instance at all. The fix is in
`src/token.c` and needs a rebuild.

## What the user sees

They open `xschem_library/rom8k/rom8k.sch` and press netlist. Twenty-three
warning paragraphs arrive, and **three of them are byte-identical**:

    Warning: on this sheet, instance x2 (a lvnand2) sets VSSBPIN=VSS, but
    lvnand2 never reads VSSBPIN when the netlist is written, so that setting
    did not reach the simulator and changed nothing. ...

Measured on the same tree:

    grep -c lvnand2 xschem_library/rom8k/rom8k.sch   ->  0

There is no `lvnand2` anywhere on that sheet. The three `x2`s live in
`rom2_predec1.sch`, `rom2_predec3.sch` and `rom2_predec4.sch`. The user is told
three times about an instance that is not in front of them, given no way to
tell the three apart, and no way to find any of them.

Full count on that one sheet: **23 lines, 10 distinct**.

## Why it happens

`warn_unused_instance_attr()` is called from `print_spice_element()`, which
runs for **every instance in every cell of the hierarchy**, not only the sheet
the user has open. The sentence opens with the words "on this sheet" and then
names `xctx->inst[inst].instname` — a name that is unique within its own cell
and nowhere else.

## What it should say

The netlister knows the hierarchy it is in. The sentence needs the sub-cell (or
the path), and "on this sheet" has to go or become true. Ruling **D5-4** applies:
the sentence is minted once, so this is one edit at one site.

The 0974 wording is the model to copy — it leads with the instance the user
placed, in the case the sheet spells it, and ends with the action.

## Acceptance rows this needs

None exist. `tests/headless/test_unused_attr_0970.tcl`'s fixture `uatop.sch` is
**one level deep** and every UB row netlists a top sheet whose warned instances
sit on that sheet, so the hierarchical shape is never exercised. A fix needs a
two-level fixture with the same instance name at both levels.

## Related

**0974** (the same defect on the annotation surface, fixed), **0980** (the same
sentence claiming a setting changed nothing when another backend uses it),
**0983** (the same sentence cut in half by an unusual value).
