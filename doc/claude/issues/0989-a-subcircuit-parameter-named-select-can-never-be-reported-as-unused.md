# 0989 — a subcircuit parameter named `select` can never be reported as unused

**Filed** 2026-08-30, by the item S4c write-up, from the verify pass's
measurement. **Status** open, low severity. **Parent** issue **0980**.
**Subject** `unused_attr_stoplist[]` in `src/token.c`.

## What was done and why

Item S4c added `select` to the netlister's stoplist — the list of attribute
names the "you typed this and it had no effect" warning never speaks about. The
reason is real: the property editor reads `select=` off the **instance** to
decide which field the cursor lands in (`src/property_form.tcl`,
`xschem get_tok $::tctx::retval select`), and the shipped
`xschem_library/ngspice/solar_panel.sch` sets `select=OFFSET` and
`select=AMPLITUDE` on two comparators for exactly that. Before the stoplist
entry, those two sheets were told on four lines to take them off.

## The cost, measured

A stoplist name is silenced **for every symbol in every design**, forever. So a
subcircuit with a genuine parameter named `select` — a multiplexer is the
obvious one — can never be told its setting was dropped.

Fixture: an instance `xM` with `select=1 zzctl=1` on a cell whose format string
ignores both. Measured:

    SELECT_WARNINGS: 0    CONTROL_WARNINGS: 1    SELECT_IN_DECK: 0

The control attribute is reported, `select` is not, and `select` reaches the
deck zero times. The user gets no warning and no parameter.

## Flagged plainly

**No netlist format consumes `select`**, so by the brief's literal rule this is
not a false positive — it is a stoplist judgement in the same class as
`place`, `sig_type` and `device_model`, which are read by the editor and the
netlister's own machinery rather than by a cell. It is recorded here because it
is the one stoplist entry that collides with a plausible **user** parameter
name, and because it was added by measurement on two shipped sheets rather than
by a decision anyone took about the name.

## Options

1. Leave it (today). Two shipped sheets stay quiet; a `select` parameter on a
   real mux stays unreportable.
2. Drop it from the stoplist and accept four lines of noise on
   `solar_panel.sch`.
3. Make the stoplist consult whether the SYMBOL declares the name as a
   parameter, so an editor-only attribute is skipped while a real parameter of
   that name is still reported. Most precise, most work, and it interacts with
   0987's question about which netlist is being spoken for.

## Rows

`UF19` in `tests/headless/test_unused_attr_0970.tcl` pins the shipped
`solar_panel.sch` sheet as silent; `UF14` exercises all 56 stoplist names beside
a control attribute. Neither pins the cost above, and changing the answer means
changing UF19.
