# 0980 — the new netlist warning tells a designer to delete a setting the VHDL and Verilog netlists really use

**Status: FILED, NOT FIXED (2026-08-30, item S4b write-up).** Reproduced by
measurement on the shipped example library. The fix is in `src/token.c` and
needs a rebuild, which the agent that found it was not permitted to run; it is
filed here rather than half-done.

## What the user sees

They open `xschem_library/logic/ram_tb.sch`, press netlist with SPICE selected,
and the info window fills with **seven** paragraphs like this one:

    Warning: on this sheet, instance x1 (a ram) sets datafile=ram.list, but ram
    never reads datafile when the netlist is written, so that setting did not
    reach the simulator and changed nothing. Check the spelling against the
    settings this cell does read, or take it off. If you meant to change only
    this one copy of the cell, give x1 a schematic= attribute of its own as
    well, and the cell will be written out separately with your setting in it.

Two of those clauses are false for this design and the last piece of advice is
destructive. Netlisting **the same sheet** to Verilog, in the same session,
emits every one of the seven:

    .dim ( 8 )
    .width ( 16 )
    .hex ( 1 )
    .datafile ( "ram.list" )
    .modulename ( "ram" )
    .access_delay ( 3000 )
    .oe_delay ( 300 )

and `xschem_library/logic/ram.sym`'s own body consumes them
(`$readmemh(datafile, mem)`, `assign #access_delay iidata = idata;`). A
designer who does what the sentence tells them — "take it off" — breaks the
Verilog netlist of a working example, and the tool told them to.

The same shape on `xschem_library/examples/loading.sch`: **11** warning lines
in the SPICE netlist, and the VHDL netlist of the same sheet carries
`cap => 30.0`, `cap => 100.0`, `conduct => 1.0/20000.0` and their siblings.

## The measurement

Swept with the shipped stoplist over every schematic in `xschem_library/`,
using the built binary at the S4b commit:

    SWEEP sheets_scanned=179 sheets_with_lines=18 lines=149

Of the 147 lines that parse into a (symbol, property) pair, classified by
reading each symbol's own `generic_type=`, `vhdl_format=`, `verilog_format=`
and non-SPICE body:

| class | lines |
|---|---|
| the property is declared or consumed by another backend of the same symbol | **36** |
| the property is read by nothing at all (a genuine catch) | **111** |

The 36:

    real_capa cap 8 | switch_rreal del 6 | pump conduct 4 | pump val 4
    bts m 4 | latch delay 3 | ram dim/width/hex/datafile/modulename/
    access_delay/oe_delay 1 each

**A number correction, deliberately made.** The verification pass counted **43**
in this class by also counting `del` on `logic/latch` and `logic/mux21`. This
write-up does not: those two symbols declare `generic_type="delay=time"` and
name `del` only in their `template=`, so from the shipped files alone `del`
being a live VHDL generic is not established. 36 is the number this repository
proves. The class is real either way.

## The missing guard

`warn_unused_instance_attr()` consults **only** the format string of the
backend currently selected. It never looks at the symbol's `generic_type=`, its
`vhdl_format=` / `verilog_format=` / `tedax_format=`, or its
`verilog_netlist=true` body. `generic_type` is in `unused_attr_stoplist[]` as
an **attribute name** — that exempts an instance that sets `generic_type=`
itself, which is a completely different thing from reading what a symbol's
`generic_type` declares.

## Why it matters more than the count suggests

The brief that commissioned the check said: *"Do not ship a warning that cries
wolf on a normal netlist; a diagnostic nobody can read is worse than none."*
The check is silent on all three PDK trees and on every simulation bench, which
is what let it ship on by default — and it is right about 111 of its 149 lines.
But a multi-backend cell is a normal thing in this repository, and on those
sheets the sentence is not merely noisy: it states a falsehood ("changed
nothing") and recommends an edit that breaks the design.

## What would fix it

Before emitting, ask whether **any** other backend of that symbol reads the
token — the union of `format`, `spice_format`, `vhdl_format`, `verilog_format`,
`tedax_format`, `spectre_format` and the names declared in `generic_type`. If
one does, either stay silent or say the true thing instead: *"the VHDL netlist
of this cell uses it; the SPICE one does not."* The second is better and is
what a designer needs, but it is a bigger sentence and needs its own rows.

## Acceptance rows this needs

None exist. `tests/headless/test_unused_attr_0970.tcl`'s UB8 — the row named
"the noise budget" — netlists only `sky130_tests_ase`'s `tb_*` benches, which
are pure SPICE and emit zero lines. **No row in the tree netlists a
multi-backend sheet through this check**, which is why the class shipped. A fix
needs a fixture cell carrying a `generic_type=` and two format strings, netlist
to SPICE, and assert silence.

## Related

Issue **0978** records the 149 lines as library data and says they are "all
real". That claim is corrected there by this measurement. Issue **0981** is the
same sentence being wrong about *where* the instance is; **0983** is the same
sentence being cut in half by an unusual value.
