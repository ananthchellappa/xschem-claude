# 1213 - a setting typed as a space puts a device model that does not exist into the deck

**Branch:** annotate
**Status:** OPEN - measured, not fixed.
**Filed by:** item S6a, write-up pass, 2026-08-31. Measured by that item's two
verify passes and re-measured independently here on the shipped binary.
**Caused by:** [[1201]]. Same shape as [[1204]], which is the regression item
S6a exists to close. RULING D5-1.

## What the user sees

They clear a field in the property dialog and leave a space behind - or type a
tab - instead of leaving it truly empty. The deck they get names a device model
that exists in no PDK, so the simulator rejects it, and the info window tells
them in plain English that XSCHEM wrote the copy for them and they need do
nothing.

## Measured, verbatim (2026-08-31, shipped binary, whole-design netlist)

Sheet:

```
C {w/wp.sym} 120 0 0 0 {name=xS W_P=0.5 modelp=" "}
```

Deck:

```
xS net1 wp__modelp__ W_P=0.5
.subckt wp__modelp__ A  W_P=1
XM2 net1 net2 net3 net4 sky130_fd_pr__ L=0.15 W=W_P nf=1 ad=... as=...
```

The model name is `sky130_fd_pr__` followed by nothing. It names no device in
any PDK. The cell name ends in two underscores. And the info window says:

> Note: ... xS (a wp) sets modelp= , and the wp drawing uses that setting inside
> it, so XSCHEM wrote a separate copy of wp called wp__modelp__ and pointed xS
> at it. ... You do not have to add anything to the sheet.

**The control matters:** the same sheet through "netlist current level only"
(Shift-N, `xschem netlist -nohier`) writes `xS net1 wp` plus a warning - a valid
deck. And a truly empty `modelp=` is handled correctly by GUARD AS-EMPTY: it
calls the plain cell, writes one body, and says so. This case is one character
outside a guard that exists.

## Cause

GUARD AS-EMPTY in `lost_attrs_the_cell_body_reads()` (`src/token.c`) admits a
setting when `(tval = get_tok_value(prop, p, 0)) != NULL && tval[0]`. `tval[0]`
is true for a space. The question the guard is standing in for is *"did the
designer type a value that means anything"*, and one byte is not that question.

## What would fix it

Skip leading whitespace before the test - the same shape the rest of the token
reader already uses. That covers a space, a tab and any run of them, and it
leaves every value with real characters in it exactly where it is.

Worth doing in the same pass: the note prints the raw value, so a blank one
reads `sets modelp= ,` with a floating comma. Whatever value survives the guard
should be the one the sentence quotes.

## Rows

None. A row is a one-line fixture beside row AS54's: a value of one space must
produce no separate copy, no note, and the same "you left the value empty"
sentence AS54 already pins for the empty case.
