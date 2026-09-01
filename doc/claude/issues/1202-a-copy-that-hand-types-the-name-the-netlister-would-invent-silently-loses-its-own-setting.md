# 1202 - a copy that hand-types the name the netlister would invent silently loses its own setting

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6a **for the sheet being netlisted**.
Verified by row AS51 (behavioural) and the extended row AS41 (structural).
**The same defect through the other door is still live and is filed as
[[1212]]:** a `schematic=` name typed on a copy one level DOWN is not in
`xctx->inst[]` when the top sheet's call lines are written, so the probe cannot
see it and that copy still gets someone else's device, silently. The
over-refusal twin this fix creates - two copies asking for the same settings
getting two identical bodies - is [[1215]].
**Filed by:** item S6, write-up pass, 2026-08-31
**Caused by:** [[1201]]. This is a REGRESSION: the case below was correct before
that change landed.

## What the user sees

They place two copies of the same cell. On one they type a setting and nothing
else. On the other they type a different value of that setting AND a
`schematic=` attribute naming a cell of its own - which is the mechanism the
tool has always offered, and which the brief for [[1201]] made a hard
requirement: *explicit beats implicit*.

If the name they typed happens to be the name the netlister would have invented
for the first copy, the second copy silently gets the FIRST copy's device. It is
told nothing. There is no warning and no note about it anywhere.

## Measured, verbatim

Sheet (a cell `advpass` whose own drawing takes its p-device from `@modelp`):

```
C {adv/advpass.sym} 120 0 0 0 {name=xP W_P=0.5 modelp=pfet_01v8_lvt}
C {adv/advpass.sym} 320 0 0 0 {name=xQ W_P=0.5 modelp=pfet_01v8_hvt schematic=advpass__modelp_pfet_01v8_lvt}
```

Deck:

```
xP net1 advpass__modelp_pfet_01v8_lvt W_P=0.5
xQ net2 advpass__modelp_pfet_01v8_lvt W_P=0.5
.subckt advpass__modelp_pfet_01v8_lvt ...
XM2 ... sky130_fd_pr__pfet_01v8_lvt ...
```

`xQ` asked for the high-threshold device and got the low-threshold one. Nothing
is said about `xQ` anywhere: GUARD AS-EXPLICIT sends it straight past the
netlist warning, and the [[1201]] note fires only for `xP`.

**Reverse the two lines on the sheet and it is worse.** `xP` then gets the
high-threshold body, and the info window says, in plain English, a thing that is
not true:

> Note: ... XSCHEM wrote a separate copy of advpass called
> advpass__modelp_pfet_01v8_lvt and pointed xP at it ... You do not have to add
> anything to the sheet.

It wrote no such copy. `xP` is riding `xQ`'s. RULING D5-1.

## Cause

`auto_spec_collides()` (`src/actions.c`) asks four questions about a candidate
name - is a symbol of that name already loaded, has this run already handed the
name out, is there a file of that name on disk (bare, and inside the base
symbol's own library). It never asks the fifth: **what `schematic=` names have
the other copies on this design typed?**

Ordering is what makes that reachable. The top sheet's call lines are written by
`spice_netlist(fd, 0)`, which runs BEFORE `get_additional_symbols(1)` creates
the symbol block for a hand-typed name - so at the moment the name is invented,
the hand-typed one is not yet a loaded symbol. `get_additional_symbols()` then
de-duplicates symbol blocks by name and the two copies fold into one.

## Reachability

Adversarial rather than accidental: the designer has to type the exact spelling
the tool invents, `<cell>__<setting>_<value>`. But the harm when it does happen
is a silently wrong deck, which is the class the [[1201]] brief calls a STOP, and
issue [[0982]] is the same trap - two copies sharing one body with only the first
one's setting kept - which [[1201]] was explicitly required not to reproduce.

## What would fix it

Give `auto_spec_collides()` a fifth probe: walk `xctx->inst[]` and refuse a
candidate that any instance's own `schematic=` attribute names. That is one loop
over instances, in the same function, and it closes the ordering hole because
the property strings are all present before the first call line is written.

## Why it was not fixed here

The write-up pass has no `make` (house rule: only the implement and sabotage
agents build). A product change that cannot be built and measured is worse than
a filed measurement.

## Rows

None today. `AS13` covers explicit-beats-implicit only where the hand-typed name
and the invented name differ. A row for this needs the two-copy sheet above and
must assert BOTH copies get the device they asked for.

---

## Fixed, 2026-08-31, item S6a

`auto_spec_collides()` (`src/actions.c`) grew a **fourth** way a name can already
be spoken for - **GUARD AS-TYPEDNAME**: it walks `xctx->inst[]` and compares the
candidate against the `schematic=` name typed on every other copy on the sheet.

**Why none of the other three probes could see it.** The top sheet's call lines
are written by `spice_netlist()` *before* `get_additional_symbols()` builds the
symbol blocks for hand-typed names, so at the moment a name is minted the
hand-typed one exists only as text inside another copy's property string - not
as a loaded symbol, not as a name this run has handed out, and not as a file on
disk. The ordering is the whole defect.

The value is read **raw**, never through `translate3()`: a hand-typed name may be
a generator call, and running one for every candidate would evaluate Tcl inside
a collision test. Rejected alternative, recorded here.

Measured after: the copy that hand-typed the name keeps its own device
(`pfet_01v8_hvt`), the copy the tool named gets `..._1` and its own
(`pfet_01v8_lvt`), and each body holds what its own copy asked for.
