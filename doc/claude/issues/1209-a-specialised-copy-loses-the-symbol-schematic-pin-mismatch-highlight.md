# 1209 - a specialised copy loses the symbol/schematic pin-mismatch highlight

**Branch:** annotate
**Status:** OPEN - measured by inspection, not fixed. Found by the verify pass of item S6.
**Filed by:** item S6, write-up pass, 2026-08-31
**Caused by:** [[1201]]. Error path only; no deck is wrong because of it.

## What the user sees

When a symbol's pins and its drawing's pins disagree, XSCHEM colours the
offending instances red so the designer can find them. A copy that [[1201]] has
given its own version of the cell will no longer be coloured.

## Cause

`auto_spec_name()` is consulted from `get_sym_name()`, so inside the SPICE
netlist window every consumer of that function gets the synthesised name, not
only the two [[1201]] intended (the call line and the `.subckt` line).
`src/netlist.c:2149`, `:2168`, `:2202` and `:2226` compare
`get_sym_name(j, 9999, 1, 0)` against `xctx->sym[i].name` to decide which
instances to highlight; a specialised copy no longer matches, so it is skipped.

## Severity

Cosmetic and confined to the error path - the deck itself is unaffected, and the
mismatch is still reported, just not painted on that one copy. Recorded because
it is a measured consequence of the change with no row anywhere, not because it
is urgent.

## What would fix it

Either have those four comparisons ask for the BASE name, or give
`get_sym_name()` a flag distinguishing "what does the deck call this" from
"which symbol is this".

## Rows

None.
