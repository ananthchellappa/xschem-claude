# 0985 — the VHDL netlist writes `extra=`-declared nodes into the generic map, where Verilog leaves them out

**Status: FILED, NOT FIXED (2026-08-30, item S4c).** Found while fixing issue
**0980** and deliberately left alone: settling it either way changes what a
shipped VHDL netlist contains, which is a bigger decision than the warning
0980 is about. It is recorded here because issue 0980's fix had to choose a
side, and a later reader must be able to see that the choice was made
knowingly.

## What `extra=` means

A symbol's `extra=` attribute is the whitespace-separated list of attribute
names the netlister treats as **nodes** — subcircuit ports — rather than as
instance parameters. `xschem_library/rom8k/lvnand2.sym` carries
`extra="VCCPIN VSSPIN"`, and the SPICE deck writes them as ports:

    .subckt lvnand2 z a b VCCPIN VSSPIN
    x10 FN DDN vcc vss lvnand2

## The two backends disagree

`print_verilog_element()` in `src/token.c` excludes an `extra=` name from the
parameter map explicitly:

    if(strcmp(token, "name") && xctx->tok_size && (!extra || !strstr(extra, token))) {

`print_vhdl_element()` has no reference to `extra` anywhere in its body. It
emits any template-declared attribute into the generic map.

## Measured, 2026-08-30, on shipped data

Netlisting `xschem_library/rom8k/rom2_predec1.sch`:

| netlist | `VCCPIN` occurrences |
|---|---|
| `rom2_predec1.vhdl` | **128**, as `VCCPIN => "vcc" ,` inside `generic map (`|
| `rom2_predec1.v` | **0** |

So the same power-pin binding is a port in SPICE, a generic in VHDL, and
nothing at all in Verilog.

## Why issue 0980's fix chose the side it did

GUARD UA-TMPL in `src/token.c` asks whether the symbol's `template=` declares a
setting, and treats that as proof the setting reaches a netlist. GUARD UA-EXTRA
sits inside it and takes `extra=` names back OUT again, so an `extra=` name
stays reportable even when the template also carries it.

Counting the VHDL generic map as consumption would have been defensible on the
evidence above — and it would have silenced **issue 0970's own headline case**.
`sky130_tests/passgate.sym` declares `modelp` in its template AND names it in
`extra="VCCBPIN VSSBPIN modeln modelp"`, so a designer who types
`modelp=pfet_01v8_lvt` on one passgate would go back to being told nothing,
which is the defect the whole diagnostic was written for.

**Decision (unratified by the user):** `extra=` names are nodes, not settings,
and stay reportable. The VHDL behaviour above is left exactly as it is.

## What is not known

Whether the VHDL generic map entry is intentional (a way to let a VHDL
component take its supply names as generics) or an oversight that predates the
Verilog exclusion. Nothing in the tree says. Deciding that is what this issue
is for; it is not decided here.
