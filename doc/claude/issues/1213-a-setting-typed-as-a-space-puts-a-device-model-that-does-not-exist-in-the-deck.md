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

---

## FIXED, item S6b (2026-08-31)

**Not by another guard.** Trimming the blanks and carrying on was rejected: it
keeps the separate copy, but then the cell name and the deck disagree with what
the designer actually typed. What shipped instead is an ALLOW-rule --
`ua_value_specialisable()` in `src/token.c`, GUARD AS-VALUE -- and everything
that fails it falls back to the plain cell and is reported as a setting that
went nowhere, exactly as before issue 1201.

**The rule, in the words the user gets:** XSCHEM can write a separate copy of a
cell for a setting only when the value is ONE WORD with at least one letter or
digit in it. Formally: not empty, no blank space of any kind anywhere in it, at
least one `[A-Za-z0-9]`.

Measured against every shape this file lists, plus two the file did not:

| value | before | after |
|---|---|---|
| empty | plain cell, warned (1206) | unchanged |
| one space | second cell, `sky130_fd_pr__` | plain cell, warned |
| one tab | second cell, `sky130_fd_pr__` | plain cell, warned |
| one line break | transistor line CUT IN TWO, phantom `XL=` element | plain cell, warned |
| punctuation only | `sky130_fd_pr__---` | plain cell, warned |
| **trailing space on a real value** | TWO byte-identical 314-byte bodies | one body; the spaced copy warned |
| real value in quotes | correct | correct, unchanged |

The trailing-space row was a duplicate-body defect of its own, a third shape
beside 1214 and 1215, and it was filed nowhere. It is closed by the same rule
and is pinned by row AS63.

**Both doors move together.** The rule sits at the one point the netlister and
the schematic annotation surface share, so `lcc[N].auto_spec` -- which the
annotation surface uses to look device numbers up by cell name -- stops
answering yes for these shapes too. Row AS66.

**What the designer is told** is a fifth shape of the warning, SHAPE 3b: the
name is right and the drawing does read it, but the value "is nothing but blank
space" / "has a space, a tab or a line break in it" / "has no letters or digits
in it", and a value has to be one word with at least one letter or digit. The
truly empty value keeps 1206's own wording.

**Rows:** AS59 (space), AS60 (tab), AS61 (line break, plus no deck line may
begin `XL=`), AS62 (punctuation), AS63 (trailing space), AS64 (quotes, a
control), AS65 (one unusable setting beside one real one -- the only row that
sees the warning half), AS66 (the other door), AS67 (structural).

**Known and NOT widened, deliberately.** Two copies with equal keys share one
cell body, so a setting this rule rejected on one of them can still reach that
shared body through `parent_prop_ptr`. That is not new -- the empty value has
behaved so since 1206, and row AS55 pins the behaviour -- and the allow-rule
only extends the existing shape. Recorded here rather than fixed.

**On the user's ruling queue:** the strictness itself. A value with a space
anywhere in it, including a trailing one nobody can see, now falls through to
the plain cell rather than being trimmed.

---

## 2026-08-31, item S6b's REPAIR pass: the "known and NOT widened" paragraph above was WRONG as measured, and is now closed as issue 1227

The paragraph says the leak through `parent_prop_ptr` "is not new -- the empty
value has behaved so since 1206". Measured control: a truly EMPTY value does NOT
leak, because the template default wins. Only the whitespace and punctuation
shapes leaked, and only on a copy carrying one usable setting beside the
unusable one -- in which case the whole 1213 transcript came straight back,
`sky130_fd_pr__` and the split `XL=` line included, under the warning saying the
setting changed nothing.

Closed by GUARD AS-STRIP: a refused setting is now removed from the property
string handed to the cell body XSCHEM writes, so it falls back to the symbol's
own default and the warning is true. See **1227** for the measurements, the two
further shapes it fixed, and the `@`/`%` extension to the allow-rule. Rows
AS78-AS81, plus two new elements on AS65.

The user-facing rule clause changed with it: "one word made of ordinary
characters, with at least one letter or digit in it and no '@' or '%' in it."
