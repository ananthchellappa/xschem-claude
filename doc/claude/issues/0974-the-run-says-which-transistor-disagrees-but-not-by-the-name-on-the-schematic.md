# 0974 — the run says which transistor disagrees, but not by the name on the schematic

**Status:** **FIXED 2026-08-30 by item S4b.** (Filed by item S4a's
verification pass; the finding below is kept verbatim because it is the
measurement. What was done is at the end.)
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


---

# THE REPAIR, 2026-08-30 (item S4b)

## The sentence now

> On this sheet, the transistor **M2** inside **x5** has "pfet_01v8_lvt" written
> on its schematic line, but **x5** does not pass that setting down into the
> netlist, so the simulator was given "pfet_01v8" for it instead. The numbers
> put next to it are the ones measured for "pfet_01v8", not for the model the
> schematic names. **What you can do:** give **x5** a `schematic=` attribute of
> its own, which makes this one copy of the cell netlist with your model in it;
> or leave it as it is and read these numbers as belonging to "pfet_01v8". In
> the results this device is called `@m.x5.xm2.msky130_fd_pr__pfet_01v8`

The placed instance leads. The device inside the cell is named as being inside
it. Both model spellings are given. The sentence ends with the action. The
results-file path goes last, where a person can ignore it.

## Three changes

1. **`op_annot::_why_model_differs`** — the ONE place this sentence is written
   (ruling D5-4). `op_annot::_walk` now holds none of its words and only renders
   what comes back. Row **GC4** is structural and pins that.
2. **`op_annot::_pathseg_shown`** — the last component of `sch_path` **with the
   case the schematic gave it**. GUARD **GC-NAME**: an instance a sheet calls
   `X7` is called `X7`, never `x7`. `op_annot::_pathseg` keeps the lowercased
   form — it exists to compare against the deck, where the netlister has already
   lowercased everything — and is now *derived* from `_pathseg_shown`, so the two
   cannot drift about which component they mean. Row **GC2**.
3. **The action.** 0974's own text suggested editing the symbol's `format=`
   string. That is **not** the advice given, because it changes every placement
   of the symbol tree-wide and still cannot substitute a model NAME through a
   `.subckt` parameter. The advice is the per-instance `schematic=` attribute —
   the mechanism measured to work, the one issue 0970's repair used, and the
   same one the netlist-time warning recommends. One story, three surfaces.
   Rows **GC1**, **GC3**.

## ⚠ Why this guard's witness is a fixture now

Repairing issue 0970 removed the only disagreement in the shipped tree, and with
it the only place this sentence was ever produced. Rows **GC1–GC5** of
`tests/headless/test_unused_attr_0970.tcl` keep it on a fixture whose `x5` and
`X7` are deliberately left without a copy of the cell to themselves, so it cannot
be repaired away. Row **N3** of `test_ase_optier_0963.tcl` is inverted to assert
the bench is now silent, and its own text points at GC1–GC5 so a reader cannot
mistake that silence for the guard being gone.
