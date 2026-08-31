# 0988 — a setting no netlist format can consume is silent when the symbol's template declares it

**Filed** 2026-08-30, by the item S4c write-up, from the verify pass's
measurement. **Status** open. **Parent** issue **0980**, whose fix caused this.
**Sibling** issue **0987** — same guard, different half. **Subject** GUARD
UA-TMPL in `src/token.c`.

## The rule the fix was given, and the rule it implements

The item brief's rule, verbatim:

> A property is UNUSED only if **NO netlist format this symbol can be written
> in** consumes it.

GUARD UA-TMPL asks a narrower question: *is this name in the symbol's
`template=`?* Those two coincide on almost all shipped data, which is why the
sweep came out clean — but they come apart whenever the symbol **cannot be
written in the other formats at all**. A symbol carrying `vhdl_ignore=true` and
`verilog_ignore=true` is never emitted into a VHDL or Verilog netlist, so a
template name on it is consumed by nothing, anywhere — and the diagnostic is
silent about it.

## Measured

Two fixtures, both built and netlisted against the binary S4c shipped.

**Shape 1 — the format drops it and nothing else picks it up.** A subcircuit
symbol with `type=subcircuit`, `format="@name @pinlist @symname W=@W"` and
`template="name=x1 W=1 DEAD=0"`. An instance sets `W=7 DEAD=9 zzctl=1`. The
netlister warns about `zzctl` only. `DEAD` is silent, and the deck is:

    xR net1 vcread W=7
    .subckt vcread A  W=1 DEAD=0

`DECK_HAS_DEAD9: 0`. The user's `DEAD=9` is gone and unmentioned.

**Shape 2 — the sharp form, where no format anywhere can consume it.** The same
shape plus `vhdl_ignore=true verilog_ignore=true tedax_ignore=true
spectre_ignore=true`. An instance sets `KNOB=99 zzdead=1`. Measured:

    KNOB_WARNINGS: 0    CONTROL_WARNINGS: 1

and the value `99` appears **zero times across all four products the tool
wrote** — `vctop.spice`, `vctop.vhdl`, `vctop.v`, `vctop.tdx`. The VHDL entity
is empty, because the instance is skipped there entirely. The control attribute
proves the instance really did reach the diagnostic, so this is the guard
choosing silence, not the instance being skipped.

## Not synthetic

**112 `.sym` files in this tree carry a `vhdl_ignore` or `verilog_ignore`
flag.** The class is shipped, not invented for the fixture.

## The fix

Consult the `*_ignore` flags before crediting a format with consuming a setting:
a template name on a symbol that no other backend will ever emit is not reached
by anything, and the original 0970 warning is the correct thing to print. That
makes GUARD UA-TMPL implement the brief's rule as written instead of an
approximation of it.

Note this is a **narrowing** of the excuse, so it can only make the warning
speak more; it cannot resurrect any of the 43 false positives 0980 removed
(those symbols carry no `*_ignore` flags — the point of them is that they DO
netlist to VHDL and Verilog).

## Rows

None. A fixture pair for both shapes belongs with the fix; writing rows now
would pin today's silence as the contract.

## Relationship to 0987

0987 is *"the format being written drops it, another format would not"* — a
question about **which netlist**. This one is *"no format takes it at all, and
the guard excused it anyway"* — a straightforward miss against the stated rule.
0987 needs a ruling; this one does not.
