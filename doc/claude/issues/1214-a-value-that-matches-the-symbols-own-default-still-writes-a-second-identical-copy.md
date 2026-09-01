# 1214 - a value that matches the symbol's own default still writes a second, identical copy of the cell

**Branch:** annotate
**Status:** OPEN - measured, not fixed. This is [[1206]]'s recorded residue,
given its own number so it is not lost inside a closed issue.
**Filed by:** item S6a, write-up pass, 2026-08-31. Re-measured independently
here on the shipped binary.
**Caused by:** [[1201]].

## What the user sees

They type a setting whose value is the one the cell already uses - often by
typing out what the property dialog showed them. The deck grows a second copy of
the cell that is byte-for-byte the first one, and the info window announces it.

## Measured, verbatim (2026-08-31, shipped binary)

The symbol's own template already says `modelp=pfet_01v8`. The designer types
the same thing on one copy:

```
C {w/wp.sym} 320 0 0 0 {name=xU W_P=0.5 modelp=pfet_01v8}
```

Deck:

```
xU net1 wp__modelp_pfet_01v8 W_P=0.5
.subckt wp A  W_P=1
.subckt wp__modelp_pfet_01v8 A  W_P=1
```

Both bodies measured: **294 bytes each, identical**. And:

> Note: ... xU (a wp) sets modelp=pfet_01v8, and the wp drawing uses that
> setting inside it, so XSCHEM wrote a separate copy of wp called
> wp__modelp_pfet_01v8 and pointed xU at it. ... You do not have to add anything
> to the sheet.

[[1206]]'s own ruling was **a copy that differs in nothing is not a copy**. This
is that case, one step further out than the blank value [[1206]] closed.

## Cause

Nothing compares the specialised body against the base before minting it.
[[1206]] fixed the measured case with a cheap test on the typed value; the
general test - does this copy actually differ - was named there and left.

## What would fix it

Compare the candidate against the symbol's own template values before
specialising: if every setting in the candidate set already holds the value the
template supplies, there is nothing to specialise and the copy should call the
plain cell (and get no note). That is a value comparison in
`auto_spec_qualifies()`, not a body diff, so it does not touch
`get_additional_symbols()`.

The body-diff alternative recorded in [[1206]] - build the body, compare it to
the base, fall back - is stronger (it catches a setting the drawing reads but
whose value happens not to change anything) and is more code.

## Rows

None. A row is one fixture: a copy typing the template's own value must call the
plain cell, produce exactly one body, and get no note.
