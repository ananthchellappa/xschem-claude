# 1204 - "netlist current schematic only" calls a cell body it never writes

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6a. Verified by rows AS44-AS48 of `tests/headless/test_auto_specialize_1201.tcl`.
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

---

## Fixed, 2026-08-31, item S6a

**The choice, and it was between two honest answers.** Option (a) was taken:
**"netlist current schematic only" does not write a specialised copy at all, so
the call line names the plain cell exactly as it did before [[1201]].**

Option (b) - write the specialised cell bodies on the single-sheet arm too - was
rejected, and the reason is measured rather than stylistic. Those bodies are
written by `get_additional_symbols(1)` at `src/spice_netlist.c`, inside the
`if(global)` block, together with the descend and `pop_undo` machinery that goes
with it. Teaching that to the single-sheet arm means making "current schematic
only" descend into sub-cells and emit their bodies, which stops it being
current-schematic-only, and puts duplicate `.subckt` definitions into the decks
of everybody who netlists each level of a design separately and includes the
files together. That is a far bigger blast radius than the regression. Option
(a) is one flag and it restores the pre-[[1201]] deck byte for byte.

**The code.** `auto_spec_begin()` now takes the caller's own `global` flag
(`src/spice_netlist.c`, one call site) and holds it in `auto_spec_whole`. GUARD
AS-WHOLE in `auto_spec_name()` (`src/actions.c`) returns NULL when it is 0, so
no name is minted on that arm. **The window still opens on both arms** - two
flags, not one - because the classification's caches are wanted on both, and
because the warning below has to be able to ask "would this copy have
qualified" without dropping the body-read cache.

**RULING D5-1 is the other half, and returning early is what pays it.** The
"XSCHEM wrote a separate copy of this cell for you" note is printed at the
bottom of `auto_spec_name()`, so leaving before it is what stops the tool
claiming work it did not do. Row AS45 asserts that not one such sentence appears
on the single-sheet arm.

**What the user is told instead** (row AS46), in plain English:

> ...but `asnh` never reads `modelp` when the netlist is written, so that
> setting did not reach the simulator and changed nothing. The `asnh` drawing
> does use `modelp`, so this is not a spelling mistake. XSCHEM can give this
> copy its own version of `asnh`, but it only writes those when it netlists the
> whole design, and this run wrote just this one sheet. Netlist the whole design
> and this setting will be in the deck.

**The other four backends were checked, not assumed.** Spectre, VHDL, Verilog
and tEDAx never open the window at all; row AS31 counts that structurally and
new row **AS48** measures their single-sheet decks and finds the plain cell name
in all four. Nothing of this shape exists to fix in them.

**Not ratified by the user.** Which of (a) and (b) is right, and the three new
sentences the warning can now print, are on the owed ledger as a `rule` debt.

**A naming slip left in the comments, filed as [[1218]].** Two comments this
fix added describe the single-sheet netlist as a checkbutton the designer
ticks, `"netlist current schematic only"`. This build has no such widget: the
doors are the **Shift-N** key and `xschem netlist -nohier`. The fix is right
and complete; only the name for the door is invented.
