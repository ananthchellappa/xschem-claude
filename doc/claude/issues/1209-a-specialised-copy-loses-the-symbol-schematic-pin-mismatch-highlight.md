# 1209 - a specialised copy loses the symbol/schematic pin-mismatch highlight

**Branch:** annotate
**Status:** OPEN, and its symptom is CORRECTED below - the highlight is not lost. Re-measured 2026-08-31 by item S6a, deliberately not fixed.
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

---

## Re-measured 2026-08-31 by item S6a: the filed symptom is wrong

**The pin-mismatch check does still run on a specialised copy, and it still
complains.** Measured on a cell whose symbol declares one pin and whose drawing
has two, netlisted twice - once as a plain copy, once as a copy the netlister
specialised:

```
===== plain copy =====
  Error: Symbol adv/advmis.sym: schematic pin: B not in symbol
  Error: Symbol adv/advmis.sym has 1 pins, its schematic has 2 pins
===== specialised copy =====
  Error: Symbol adv/advmis.sym: schematic pin: B not in symbol
  Error: Symbol adv/advmis.sym has 1 pins, its schematic has 2 pins
  Error: Symbol advmis__modelp_pfet_01v8_lvt.sym: schematic pin: B not in symbol
  Error: Symbol advmis__modelp_pfet_01v8_lvt.sym has 1 pins, its schematic has 2 pins
```

Nothing is silently un-checked. What IS wrong is different and it is the thing
worth fixing: **the designer now reads four error lines where they read two, and
half of them name a cell (`advmis__modelp_pfet_01v8_lvt.sym`) they never typed
and cannot find in any library.**

## Why it was not fixed in item S6a

It cannot be given a behavioural row today. The highlight is
`xctx->inst[j].color`, and **no Tcl command in this build reads an instance's
colour back** - `xschem list_hilights` reads the hilight hash table, not
`inst[].color`, and `get_sym_name()` is not exposed to Tcl at all. So closing
this needs one of: a new read-back on the instance colour, a structural row over
the four comparison sites in `netlist.c`, or a `look` debt on the user's eyes,
because it is a pixel claim.

Retitle it before working on it: the subject is the duplicated error lines
naming an invented cell, not a lost highlight.
