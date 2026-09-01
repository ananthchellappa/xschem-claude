# 0993 — a setting whose value is empty is claimed to be carried by VHDL, which drops it

**Filed** 2026-08-30, by the S4d sabotage pass.
**Status** FIXED 2026-08-30 by the S4d repair pass. **Class** fabricated carrier name, RULING D5-1. **Missing**
guard, not an unwitnessed one — there is no code here to neutralize.
**Subject** `src/token.c`, `ua_backend_carries()` / `symbol_declares_param()`.

## What is wrong

`ua_backend_carries()` asks only whether the cell's `template=` declares the
name. VHDL applies a second condition the guard never asks about: a generic is
emitted only `if(strcmp(token, "name") && value[0] != '\0')`
(`src/token.c:1605`). Verilog has no such exclusion.

So on a setting whose VALUE is empty, VHDL drops it and Verilog keeps it — and
the carrier list names both.

## Measured on the shipped binary

Cell `pval`: `template="name=x1 knob=1"`, format reads nothing.
Instance: `{name=xZ knob="" zzc=1}`.

> Warning: … instance xZ (a pval) sets knob=, but a SPICE netlist of pval does
> not pass knob through, … **a VHDL or Verilog netlist of the same cell does
> carry it**, so deleting it would break that.

Ground truth:

* VHDL netlist — `knob : integer := 1` twice, the entity's own default. **No
  `knob =>` in the instance's generic map at all.**
* Verilog netlist — `.knob ( "" )`. Carried.

So "Verilog" is measured and "VHDL" is fabricated. Half the sentence is a claim
about the user's design that nobody took.

This is the same class as the `| *_SHORT` finding (issue 0991) and the empty
format override (issue 0992): the guard's model of what a backend writes is
slightly coarser than the backend, and the difference is printed as fact.

## Why no row catches it

There is nothing to delete — the condition was never written. All 57 checks pass
on the defect. The whole-library sweep has zero lines with an empty value, so the
noise sweep cannot see it either.

## Severity

Latent but not exotic. Shipped instances already carry `attrs=""` (26 of them),
`write=""` (11), `sweep=""` (11), `store=""` (11) and `nodeset=""` (10). It needs
only a cell whose template declares one of those names.

## Fix

`ua_backend_carries()` should take the value into account for the VHDL row —
mirror `print_vhdl_element`'s own `value[0] != '\0'` test — and a row should
assert an empty-valued template parameter names `Verilog` alone.


---

# FIXED 2026-08-30 — the S4d repair pass

New **GUARD UA-EMPTY** in `src/token.c`, consulted on the template path of
`ua_backend_carries()` and only there:

```c
if(uses_template == UA_TMPL_NO) return 0;
if(drop_time && ua_generic_is_time(inst, tok)) return 0;   /* GUARD UA-GENTIME */
if(ua_value_is_empty(inst, tok, uses_template)) return 0;   /* GUARD UA-EMPTY */
return symbol_declares_param(inst, tok);
```

## The refinement the filing did not have: THERE ARE TWO SPELLINGS OF EMPTY

The issue proposed mirroring `print_vhdl_element`'s `value[0] != '\0'` test.
That is right for VHDL and WRONG for Verilog, and the difference is measurable.
Both netlisters end on that same test, but they build `value` differently:

* `print_vhdl_element` strips the unescaped quotes as it parses
  (`if(c=='"' && !escape) quote=!quote; else value[value_pos++]=c`), so `""`
  leaves nothing behind and the generic is dropped.
* `print_verilog_element` keeps every character it sees, so `""` is two
  characters and the parameter IS written — `.knob ( "" )`.

So the `uses_template` argument stopped being a bare 0/1 and became a named
mode, which is also what makes the two-way difference readable at the call site:

```c
#define UA_TMPL_NO      0   /* this backend never walks the symbol template */
#define UA_TMPL_DEQUOTE 1   /* VHDL: the parser strips "..." before the test */
#define UA_TMPL_RAW     2   /* Verilog: the parser keeps "..." so "" is a value */
```

`ua_value_is_empty()` asks `get_tok_value()` for the matching spelling — bit 0
is that same quote difference, and bit 1 is set in both so that merely LOOKING
at a value can never run a `tcleval()` hook.

## The row, and it opens the netlists it names

**UF32.** Sheet `uamtv_top.sch`, one copy of the existing `uatpl` cell (template
declares `knob`) typing `knob=""`. The row asserts the sentence is kind B naming
**Verilog alone**, and then netlists the same sheet to VHDL and to Verilog and
reads the products: `knob =>` must occur **0** times in the VHDL, `.knob` must
occur in the Verilog. Ground truth, measured:

    p_empty.vhdl:  xEM : uatpl        <- no generic map at all
                   knob : integer := 1   <- the component's own default only
    p_empty.v:     .knob ( "" )

## Measured

    MUT EMPTY-del      (delete the guard line)                => reds: UF32
    MUT EMPTY-mode     (use the dequoted spelling for both)   => reds: UF32
    MUT TMPL-swapmode  (give VHDL the raw spelling)           => reds: UF32

## Effect on shipped data: none, and that was checked

The whole-library noise sweep is unchanged to the line after the fix:
`sheets_with_lines=17 lines=141 A=98 B=43 suspect=43 loose=120`. The shipped
`attrs=""` / `write=""` / `sweep=""` / `store=""` / `nodeset=""` instances named
above are on cells whose templates do not declare those names, so none of them
was reaching this path.
