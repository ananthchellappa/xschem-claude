# 0982 — two instances given the same `schematic=` name collide in silence, and the advice this tree now prints leads the user straight into it

**Status: FILED, NOT FIXED (2026-08-30, item S4b write-up).** The sharpest of
the findings against item S4b's own work, because the defect is reached by
**following the advice the tool now gives**.

## What the user is told to do

Both sentences item S4b added end with the same recommendation:

* the netlist-time warning (issue 0970 half two) — *"If you meant to change only
  this one copy of the cell, give `<inst>` a `schematic=` attribute of its own
  as well, and the cell will be written out separately with your setting in
  it."*
* the annotation disagreement sentence (issue 0974) — *"give `<placed>` a
  `schematic=` attribute of its own, which makes this one copy of the cell
  netlist with your model in it."*

That advice is correct, measured, and is the mechanism the same pass used to
repair the bandgap bench. It is also silently wrong the moment a user does it
**twice with the same name**, which is exactly what someone does who has two
passgates to change and copies the attribute from the first onto the second.

## What was measured

A fixture of two instances of one subcircuit symbol, each overriding the model
the symbol's `format=` string never reads, each given the **same**
`schematic=sharedcell`:

    C {ua/uapass.sym} 320 0 0 0 {name=xa W_P=0.6 modelp=pfet_01v8_lvt schematic=sharedcell}
    C {ua/uapass.sym} 520 0 0 0 {name=xb W_P=0.7 modelp=pfet_01v8_hvt schematic=sharedcell}

The generated deck:

    3:xa net1 sharedcell W_P=0.6
    4:xb net2 sharedcell W_P=0.7
    22:.subckt sharedcell A  W_P=1
    28:.ends

    SHAREDCELL-BODIES: 1
    LVT-COUNT: 1   HVT-COUNT: 0
    WARN-LINES: 0

**One** cell body, built from `xa`'s model. `pfet_01v8_hvt` — the model `xb`'s
schematic line names — appears **nowhere in the deck**, and the info window says
**nothing**. That is issue 0970, reproduced exactly, by a user who did what the
new warning told them to do.

## Why the new diagnostic cannot catch it

GUARD **UA-POLY** in `warn_unused_instance_attr()` skips the **whole instance**
when its property string carries `schematic=`. The reasoning is sound as far as
it goes — for such an instance the override usually *does* reach the deck, and
without the guard the repaired bandgap bench would warn about a setting that is
now working. But "usually" is doing the work: the guard cannot tell an instance
whose `schematic=` name is its own from one whose name is already taken, so it
switches the diagnostic off in precisely the case where it was needed.

It also switches it off for every *other* misspelled attribute on that
instance — including on `bandgap.sch`'s `x5` and `x6` as this pass has now left
them.

## What would fix it

Narrow the guard rather than removing it. An instance carrying `schematic=`
should still be checked when another instance in the same netlist claims the
same name, and the sentence for that case is a different and more useful one:
*"`xa` and `xb` both ask for a cell called `sharedcell`, so only one of them can
have their setting; `xb`'s was dropped. Give them different names."*

A cheaper first step that needs no new sentence: refuse to reuse the name, or
say so at netlist time. The netlister already knows both instances by the time
it writes the second call.

## Acceptance rows this needs

None exist. `UB3` proves the single-instance `schematic=` case works, which is
the case that is fine. A fix needs a two-instance-one-name fixture and a row
that asserts the second instance's model is either in the deck or complained
about.

## Related

**0970** (the defect this reproduces), **0979** (the other cost of the
`schematic=` mechanism: the descend command cannot follow a name whose file does
not exist).
