# 1214 - a value that matches the symbol's own default still writes a second, identical copy of the cell

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6b. Verified by rows AS68 (the missing
body AND the silence, in one row) and AS69 (control). This is [[1206]]'s
recorded residue, given its own number so it was not lost inside a closed issue.
Was: OPEN - measured, not fixed.
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

---

## FIXED, item S6b (2026-08-31)

GUARD AS-DEFAULT, `ua_value_is_template_default()` in `src/token.c`: a value
equal to the value the symbol's own template already supplies asks for nothing,
so no second cell body is written.

**And the designer hears NOTHING about it**, which is the half a reader would
get wrong. The setting had precisely the effect they wanted -- the template
hands the same value down -- so nothing was lost and there is nothing to do.
The shared sentence frame is "... did not reach the simulator and changed
nothing", and against a no-op that reads as an accusation. Rejected
alternative: a sixth shape of that sentence; RULING D5-4 mints the frame once
and it would be false-flavoured here whatever the advice said.

Row AS68 asserts BOTH halves in one row -- one cell body, the plain name on the
call line, no note AND no warning -- because a repair that stops writing the
body and starts accusing the designer is not a repair. Row AS69 is its control:
a default-valued copy beside a real-valued one, where the real one still gets
its own cell.

**A trap this cost an hour to find, recorded for the next hand.**
`get_tok_value()` hands every answer back in ONE shared static buffer. The
value being tested is almost always a pointer into it, so reading the template
overwrites it and the comparison becomes the buffer against itself -- "the
same" for every value the template declares, which switched the whole feature
off. The guard copies the value before it looks the template up, and the
warning re-reads the value afterwards. Both sites carry a comment saying so.

**On the user's ruling queue:** the silence.
