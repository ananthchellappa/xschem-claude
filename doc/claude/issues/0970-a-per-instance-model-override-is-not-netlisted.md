# 0970 — the bandgap bench does not simulate what its schematic says

**FILED, NOT FIXED.** Found while fixing issue **0965**, reproduced first-hand
before filing. Status: **OPEN**. Scope: **netlister / symbol format string**,
wider than annotation — which is why it is not fixed here.

## What is true today, measured

`sky130A/xschem_libs/sky130_tests/bandgap/bandgap.sch` places five passgates.
Two of them override the p-channel model on their own schematic line:

    C {sky130_tests/passgate} 1380 -530 0 0 {name=x5 W_N=0.5 L_N=0.35 W_P=0.6
    L_P=0.35 VCCBPIN=VCC VSSBPIN=VSS m=1
    modelp=pfet_01v8_lvt}

`sky130_tests/passgate/symbol/passgate.sym:19`'s `format=` string is

    format="@name @pinlist @VCCBPIN @VSSBPIN @symname W_N=@W_N L_N=@L_N W_P=@W_P L_P=@L_P m=@m"

It never mentions `@modelp`. So `modelp` is not a subcircuit parameter, cannot
vary per call, and the netlister writes **one** `.subckt passgate` body for all
five instances, built from the symbol template's default `modelp=pfet_01v8`.
Measured on the generated deck:

    .subckt passgate count      : 1
    occurrences of "modelp"     : 0
    XM2 Z GP A VCCBPIN sky130_fd_pr__pfet_01v8 L=L_P W=W_P nf=1 …

**x5 and x6 are not simulated with an lvt pfet at all.** The schematic's stated
override is dead in the deck.

## Why it matters, and why it is D5-1's shape

Whichever way issue 0965 is fixed, the user ends up looking at a schematic that
says `modelp=pfet_01v8_lvt` next to numbers measured from a standard-Vt device.
A number that was not measured for the thing it is displayed next to is the
defect (ruling **D5-1**).

Issue 0965's fix takes the only honest position annotation can take on its own:
it names the device the way the DECK spells it, so the numbers are real and
readable, and it **says** that the schematic and the netlist disagree — once per
offending instance, in plain English, through the channel
`ase::op_cards_capture` already echoes. That removes the fabricated attribution.
It does not remove the underlying disagreement, because annotation cannot: the
netlist is not annotation's to write.

## The three candidate fixes, none of them annotation's

1. **Add `modelp=@modelp` and `modeln=@modeln` to `passgate.sym`'s `format=`**,
   and take the models as subcircuit parameters in `passgate.sch`. Correct and
   local, but it CHANGES WHAT THE USER'S BENCH SIMULATES — x5 and x6 would
   become lvt devices — so it is a design change on a committed bench and needs
   the user's word.
2. **Warn at netlist time**, from the netlister: an instance attribute that the
   symbol's `format=` string does not pass down, and that is not `name` or one
   of the netlister's own tokens, is a setting the user wrote and the deck threw
   away. That is a general check and would catch this class everywhere, on every
   PDK.
3. **Leave it and document it on the symbol.** Cheapest, and the least honest.

Option 2 is the recommendation: it is the same rule this whole area has been
applying to itself — a request that quietly does nothing is the defect — turned
on the netlister.

## Generality

This is not a sky130 quirk. ANY per-instance override of an attribute a symbol's
`format=` does not interpolate is silently discarded, on any PDK. It only became
visible here because the annotation surface builds a device name out of the
model and therefore had to ask which model the deck used.
