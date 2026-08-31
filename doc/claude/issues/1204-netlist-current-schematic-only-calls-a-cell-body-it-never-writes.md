# 1204 - "netlist current schematic only" calls a cell body it never writes

**Branch:** annotate
**Status:** OPEN - measured, not fixed. Found by the verify pass of item S6.
**Filed by:** item S6, write-up pass, 2026-08-31
**Caused by:** [[1201]]. This is a REGRESSION: the same deck was usable before.

## What the user sees

They netlist the current sheet only, rather than the whole hierarchy. The deck
that comes out calls a subcircuit that is defined nowhere - not in that file,
not in any other netlist file, not in any library on disk. The simulator rejects
it. Meanwhile the info window tells them, in plain English, that XSCHEM wrote
that copy for them and they need do nothing.

## Measured, verbatim

The whole deck, from `xschem netlist -nohier` on a two-level fixture:

```
**.subckt advtop2
xm1 net1 advmid
xt1 net2 advpass__modelp_pfet_01v8_lvt W_P=0.5
**.ends
.end
```

There is no `.subckt advpass__modelp_pfet_01v8_lvt` anywhere. Before [[1201]]
that line read `xt1 net2 advpass W_P=0.5`, naming a real cell the user's other
netlist files define.

The info window says at the same time:

> Note: ... so XSCHEM wrote a separate copy of advpass called
> advpass__modelp_pfet_01v8_lvt and pointed xt1 at it ... You do not have to add
> anything to the sheet.

It wrote no such copy. RULING D5-1.

## Cause

`auto_spec_begin()` is called unconditionally at `src/spice_netlist.c:418`,
ahead of `spice_netlist(fd, 0)` which writes the top sheet's call lines. The
`global` argument - 0 for "this sheet only" - is not consulted until the
`if(global)` block at `:477`, which is what writes the `.subckt` bodies. So the
non-hierarchical arm gets the renamed CALL and never the BODY.

The same driver is reached from the current-level netlist keystroke
(`src/callback.c`, `global_spice_netlist(0, 1)`) and from
`xschem netlist -nohier` (`src/scheduler.c`).

## Reachability

Any design that qualifies for [[1201]] at all, the first time its author uses
the current-sheet-only netlist. No shipped sheet qualifies (the 653-sheet
byte-diff measured zero), so this cannot reach an existing deck - it is waiting
for the feature's first real user.

## What would fix it

Gate the window on `global`: open it only for the hierarchical netlist, so the
non-hierarchical arm keeps today's behaviour exactly and the call line names the
plain cell. One line, but it needs a build and a row, and it needs a decision
about whether the note should still be printed on that arm (it should not).

## Why it was not fixed here

No `make` in the write-up pass. A one-line gate that cannot be built and
measured is a guess.

## Rows

None. Every row in `tests/headless/test_auto_specialize_1201.tcl` netlists
hierarchically. A row needs `xschem netlist -nohier` on a qualifying sheet and
must assert that every subcircuit the deck calls is one the deck or the library
defines.
