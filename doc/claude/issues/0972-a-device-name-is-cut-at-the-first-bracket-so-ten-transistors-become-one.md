# 0972 — a device name is cut at the FIRST bracket, so ten transistors become one

**Status:** FIXED (item S4a's repair pass, 2026-08-30).
**Found by:** the sabotage pass on item S4a, reproduced independently here.

## What the user would see

Nothing. That is the whole problem.

On `sky130A/xschem_libs/sky130_tests_ase/sky130_mismatch` the ten matched
transistors are drawn as ONE symbol whose name is `M1[9:0]`. The run asks the
simulator for their numbers, the numbers do not come back, and the run says
nothing — because as far as the "which devices did not answer" report is
concerned all ten are the same device, and if any one of them came back they
all did.

## Measured, on this tree, before the fix

`op_annot::save_cards` on that bench emits, among others:

    .save @m.xm1[9:0].msky130_fd_pr__nfet_01v8[id]

and `ase::op_cards_devices` answers:

    @m.xm18.msky130_fd_pr__nfet_01v8 @m.xm1

`@m.xm1` is not a device. The cut is `string first {[}`, and on a bussed
instance the FIRST bracket is the bus index, not the parameter suffix.

Two consequences, both real:

1. **The short-and-wide form writes a name that does not exist.** That form
   puts the bare device names on the `write` line; `write ... @m.xm1` costs the
   whole operating point at exit 0 (the failure mode measured for issue 0965).
2. **The "did not come back" report goes silent.** Both sides of its
   comparison truncate the same way, so `@m.xm1[3]...` and `@m.xm1[7]...`
   collapse onto one key and one device answering covers for the other nine.

## The fix

One splitter, `ase::op_dev_of`, cutting at the LAST bracket, used by both
`ase::op_cards_devices` and `ase::op_report_missing`. A parameter name never
contains a bracket, so the last one is always the parameter's.

Rows: Q7 (a name that is a prefix of another), Q8 (bussed names), Q11
(STRUCTURAL — one splitter, both callers) in
`tests/headless/test_ase_optier_0963.tcl`.

## What this does NOT fix

The name itself is still the bus RANGE and no such device is in the deck —
that is issue **0973**, which needs a ruling, not a patch. What changes here is
that the run now NAMES it instead of saying nothing.
