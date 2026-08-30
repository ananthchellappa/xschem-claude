# 0973 — a vector instance asks for a device the deck never contains

**Status:** FILED, NOT FIXED. Needs a ruling before it can be fixed.
**Found:** item S4a's repair pass, 2026-08-30, while fixing issue 0972.

## What the user sees

Ten blank annotation rows per parameter on
`sky130A/xschem_libs/sky130_tests_ase/sky130_mismatch`, where the ten matched
transistors are one symbol named `M1[9:0]`. Before issue 0972's fix, nothing
anywhere said so. This is issue 0965's failure exactly, on a different bench
and from a different cause.

## Measured, on this tree

The netlister writes ONE ELEMENT PER MEMBER:

    XM1[9] VTH2 VTH2 VSS VSS sky130_fd_pr__nfet_01v8 L=0.15 W=0.5 ...
    XM1[8] ...
    ... through XM1[0]

`op_annot::devpath` builds its name from `@name`, which is the bracketed
RANGE, so the save card reads

    .save @m.xm1[9:0].msky130_fd_pr__nfet_01v8[id]

and the deck contains no such device. ngspice accepts the request without one
character of complaint (issue 0965's measurement), the results file has no such
vector, and the display looks the same name up and finds nothing.

`op_annot::_elements` already knows the answer — it expands `xm1[9:0]` into
`xm1[9] xm1[8] ... xm1[0]` and the walk's membership test uses it. Only the
NAME BUILDER does not.

## Why this is not fixed here

Ten devices, one symbol on the screen, six rows of numbers. Which member's
numbers go next to that symbol? Ruling **D5-1** forbids the obvious shortcut:
painting member 9's `gm` beside a symbol that stands for ten transistors is a
number that was not measured for the thing it is displayed next to. The
plausible answers — annotate the first member, annotate none and say why,
annotate all ten in one stacked block, offer a member picker — are the user's
to choose, not a repair pass's.

Recorded on the owed ledger as a **rule** debt against this number.

## What DID change

With issue 0972 fixed, a run on this bench now names the card that came back
with nothing, in plain English, instead of leaving the schematic blank with no
explanation anywhere.
