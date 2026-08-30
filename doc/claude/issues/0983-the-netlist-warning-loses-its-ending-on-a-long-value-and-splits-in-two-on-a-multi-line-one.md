# 0983 — the netlist warning loses its ending on a long value, and splits in two on a multi-line one

**Status: FILED, NOT FIXED (2026-08-30, item S4b write-up).** One surface, two
measured shapes, one fix site. `src/token.c`, needs a rebuild.

The sentence issue 0970 half two added interpolates the instance's attribute
**value** into a fixed `char str[2048]` with `my_snprintf`, raw. Neither an
oversized value nor an embedded newline is handled, and both shapes are
reachable on data this repository already ships or a user can type in one
keystroke.

## Shape 1 — the recommended action is cut off, with no marker

An instance carrying a 1700-character `notes=` value. Measured, verbatim, with
the value elided for readability:

    Warning: on this sheet, instance xq (a uapass) sets notes=<1700 A
    characters>, but uapass never reads notes when the netlist is written, so
    that setting did not reach the simulator and changed nothing. Check the
    spelling against the settings this cell does read, or take it off. If you
    meant to change only this one copy of the cell, give xq

It ends there. The **entire recommended action** — the half of the sentence
that issues 0970 and 0974 were written to add, and the half a designer needs —
is gone, and nothing on screen says it was cut. `my_snprintf` truncates
silently. The full 1700 characters are also echoed into the window verbatim.

## Shape 2 — the sentence splits across two info-window lines

Measured on **shipped data**, in the sweep of `xschem_library/`. Two of the 149
lines do not begin with `Warning:`; they begin mid-sentence:

    symbol reference to use in netlist, but SYMBOL_include never reads comm
    when the netlist is written, so that setting did not reach the simulator
    and changed nothing. ...

The instance on `examples/tb_symbol_include.sch` carries a quoted two-line
`comm=` value, and the newline inside it lands inside the sentence. A reader
scanning the ERC window sees a stray fragment starting mid-word, twice, and the
line that names the instance is a different line from the one that says what
happened.

## What would fix it

At the mint site: elide the value at a sane length with an explicit marker
(`...`), and flatten embedded newlines to a space before interpolating. The
sentence's structure — instance, property, cell, consequence, action — must
survive any value, because the action is the part that makes it a diagnostic
rather than a complaint.

Consider also putting the value **last**, after the action, so an unusual value
can only ever cost the reader the value and never the advice.

## Acceptance rows this needs

None exist. Every fixture value in `tests/headless/test_unused_attr_0970.tcl`
is short and single-line. Two rows: one value over the buffer, one containing a
newline; both assert the sentence still ends with the action and occupies one
line.

## Related

**0980** and **0981** are the other two ways this same sentence is wrong.
