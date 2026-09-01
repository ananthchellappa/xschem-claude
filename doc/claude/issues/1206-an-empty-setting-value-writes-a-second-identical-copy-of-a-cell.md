# 1206 - an empty setting value writes a second, identical copy of a cell

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6a. Verified by rows AS54 and AS55.
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

---

## Fixed, 2026-08-31, item S6a

**GUARD AS-EMPTY**, in `lost_attrs_the_cell_body_reads()` (`src/token.c`): a
setting is admitted to the specialised set only if a value was actually typed
after the `=`. A copy that differs in nothing is not a copy.

**One setting, not the whole copy.** A copy carrying one blank setting beside one
real one is still specialised on the real one - the blank one takes no part in
the cell name or in the note - and the designer is **still told** about the one
they left unfinished. That needed a matching term in GUARD UA-HONOURED's skip in
`warn_unused_instance_attr()`: `spec && body_reads && haveval`. Without the
value term the warning about the blank setting vanishes, because the copy as a
whole was specialised. Row **AS55** is the only row that can see that
difference; row AS54 passes with or without it.

What the designer now reads instead: *"The `asnh` drawing does use `modelp`, so
the name is right - but you left the value empty, so there is nothing to pass
down. Put the value you want after the '=', or take the setting off."*

**Residue, recorded rather than fixed.** Only the measured case is closed - a
value typed with nothing after the `=`. The wider miss this issue names, a typed
value that happens to equal the symbol template's own default and therefore also
produces an identical copy, is left. On the owed ledger as a `rule` debt, and
now filed with its own measurement as [[1214]] so it is not lost inside a
closed issue. A THIRD case in the same family was measured after this fix and
is filed as [[1213]]: a value typed as a single SPACE passes GUARD AS-EMPTY's
`tval[0]` test, and the deck it writes names a device model - `sky130_fd_pr__`
- that exists in no PDK.
