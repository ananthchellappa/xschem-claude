# 1206 - an empty setting value writes a second, identical copy of a cell

**Branch:** annotate
**Status:** OPEN - measured, not fixed. Found by the verify pass of item S6.
**Filed by:** item S6, write-up pass, 2026-08-31
**Caused by:** [[1201]].

## What the user sees

They clear a field in the property dialog, leaving `modelp=` with nothing after
it. The deck grows a second copy of the cell - byte-for-byte identical to the
first - and the info window says XSCHEM wrote it for them because the drawing
uses that setting.

## Measured, verbatim

```
C {adv/advpass.sym} 520 0 0 0 {name=xC W_P=0.5 modelp=}
```

Deck:

```
xC net3 advpass__modelp_ W_P=0.5
.subckt advpass__modelp_ ...
```

That body was diffed line by line against `.subckt advpass`: **identical, 8
lines each.** The note reads:

> xC (a advpass) sets modelp=, and the advpass drawing uses that setting inside
> it, so XSCHEM wrote a separate copy of advpass called advpass__modelp_ ...

A cell name ending in an underscore, for a setting that says nothing.

## Cause

Nothing checks that the value is non-empty, and - the more general miss -
nothing checks that the specialised body would actually DIFFER from the base
before minting it. The same single test would also kill the case where the typed
value equals the symbol template's own default.

## What would fix it

Either refuse an empty value in `lost_attrs_the_cell_body_reads()`, or - better,
because it covers the template-default case too - compare the specialised body
against the base before writing it and fall back to the base when they match.
The second is more code and touches `get_additional_symbols()`; the first is one
test and fixes what was measured.

## Why it was not fixed here

No `make` in the write-up pass.

## Rows

None. A row is a one-line fixture: an empty value must produce no separate copy,
no note, and a deck holding exactly one body of that cell.
