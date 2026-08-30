# 0974 — the run says which transistor disagrees, but not by the name on the schematic

**Status:** FILED, NOT FIXED.
**Found:** item S4a's verification pass, 2026-08-30; reproduced first-hand by the
write-up before filing, on the bench, from the shipped code.
**Scope:** the wording of one sentence added by issue **0965**. No behaviour
depends on it.

## What the user gets today, measured

Issue 0965's fix makes the annotation show numbers for the two bandgap
passgates whose schematic line overrides the p-channel model, and — because the
numbers were measured for a different model than the schematic names, ruling
**D5-1** — say so. On every netlist of `sky130_tests_ase/tb_bandgap` the run
prints these two lines, and I reproduced them verbatim:

    the schematic line for M2 asks for model "pfet_01v8_lvt", but the cell it
    sits in does not pass that setting into the netlist, so the simulator was
    given "pfet_01v8" for it instead. The numbers shown on this device are the
    ones measured for "pfet_01v8". In the results it is called
    @m.x1.x5.xm2.msky130_fd_pr__pfet_01v8

    the schematic line for M2 asks for model "pfet_01v8_lvt", but the cell it
    sits in does not pass that setting into the netlist, so the simulator was
    given "pfet_01v8" for it instead. The numbers shown on this device are the
    ones measured for "pfet_01v8". In the results it is called
    @m.x1.x6.xm2.msky130_fd_pr__pfet_01v8

`op_annot::last_counts` reads `... netlist_model_differs 2`.

## The two defects in it

**1. It never names the thing the user can point at.** The user is looking at a
sheet with five passgates on it, called `x1 x3 x4 x5 x6`. Every one of them
contains an `M2`. The two lines above are byte-for-byte identical for their
first 280 characters and diverge only in the trailing `@m.x1.x5...` /
`@m.x1.x6...`, which is a raw-file device path — an internal name, and the one
thing the reporting rule says not to lead with. So the sentence that exists to
tell the user *which transistor* is out of step does not tell them which
transistor, and the reader has to parse a simulator vector name to find out.

The fix is to lead with the enclosing instance the user placed — `x5` — and
keep the device path at the end where it belongs.

**2. It says what happened and never says what to do.** The standing PLAIN
ENGLISH ruling requires both, and this very feature already enforces that
elsewhere: `test_op_annot.tcl` row A11-13b asserts that every blank-row
explanation says what to do next. This sentence stops at the diagnosis.

There is something to say. The disagreement is issue **0970** — the cell's
symbol drops the setting — and the user's real options are to leave it (the
numbers are honest, just for the other model), or to change the passgate
symbol's `format=` string so the override reaches the netlist, which changes
what the bench simulates.

## Why row N3 does not catch either

`test_ase_optier_0963.tcl` **N3** searches each warning for the substring `x5`
and for both model spellings. It passes on the text above because `x5` appears
inside `@m.x1.x5.xm2...`. It is a correct row for what it pins — that the
disagreement is reported once per instance, naming both models — and it is
blind to which name the sentence leads with.

## What would pin it

A row on the same bench asserting that each warning contains the placed
instance name as a word of its own, before the device path; and a row in the
PLAIN ENGLISH family asserting the sentence tells the user what they can do,
the way A11-13b does for the blank-row causes.

## Not fixed here

The write-up pass files and does not fix: a change to this sentence with no row
watching it is the defect the sabotage pass failed this item for once already.
Whoever fixes it should add the two rows in the same change.
