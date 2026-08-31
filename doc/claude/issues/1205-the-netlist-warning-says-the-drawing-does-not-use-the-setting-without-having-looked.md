# 1205 - the netlist warning says the drawing does not use the setting, without having looked

**Branch:** annotate
**Status:** OPEN - measured, not fixed. Found by the verify pass of item S6.
**Filed by:** item S6, write-up pass, 2026-08-31
**Caused by:** [[1201]], which rewrote this advice. RULING D5-1.

## What the user sees

The netlister tells them their setting went nowhere, and then makes a flat claim
about their own drawing that it never checked - and that is false whenever the
tool declined to write a separate copy for a STRUCTURAL reason rather than
because the drawing really does ignore the setting.

## Measured, verbatim

Sheet: a cell `advtmpl` whose symbol template declares `model=advtmpl_body`
(GUARD AS-TMPLMODEL) and whose own `advtmpl.sch` contains `model=@modelp`.

```
C {adv/advtmpl.sym} 320 0 0 0 {name=xB W_P=0.5 modelp=pfet_01v8_lvt}
```

Warning, verbatim:

> Warning: ... instance xB (a advtmpl) sets modelp=pfet_01v8_lvt, ... but the
> advtmpl drawing does not use modelp anywhere, so there is nothing a separate
> copy could change. To make it count, that drawing has to use modelp on the
> part meant to follow it.

The advtmpl drawing DOES use `modelp`. The tool's own deck proves it - the
template default is substituted into that very `@modelp`:

```
.subckt advtmpl_body ... XM2 ... sky130_fd_pr__pfet_01v8
```

The identical false sentence appears on the GUARD AS-SYMBODY arm (a symbol
carrying its own `schematic=`, whose named drawing also reads `@modelp`).

## Cause

`src/token.c:3580`:

```c
if(auto_spec_name(inst) && cell_body_reads_token(inst, p)) { p = q; continue; }
```

`&&` short-circuits. Whenever `auto_spec_name()` returns NULL for a structural
reason - GUARD AS-SYMBODY, GUARD AS-TMPLMODEL, GUARD AS-IGNORE, name exhaustion
- `cell_body_reads_token()` is never called at all. The sentence built below
nevertheless asserts its answer.

## It is also a truthfulness regression

The sentence this replaced - "add a schematic= attribute to <inst> naming a cell
name that no other instance asks for" - was CORRECT advice for exactly this
population, because an instance-level `schematic=` does override a symbol-level
one. [[1201]] deleted it for the right reason (a tool that fixes the problem must
not still tell you to fix it yourself) and put an unmeasured claim in its place.

## What would fix it

Ask `cell_body_reads_token()` in its own right rather than behind the
short-circuit, and pick the sentence from ITS answer: one wording for "your
drawing does not use this", another for "your drawing does use it, but this cell
is written out under a name fixed by its symbol or its template, so a copy per
setting is not possible here". Both stay 9th-grade and both are minted in the
one `my_snprintf` (RULING D5-4).

## Why it was not fixed here

No `make` in the write-up pass, and the replacement is two sentences of new
user-facing wording, which is a ruling the user has not been asked for.

## Rows

`AS24` cannot see it: it only checks that the string `schematic=` is absent from
every line of that shape. A row needs the `advtmpl` fixture above and must
assert the sentence does NOT claim the drawing ignores the setting when the deck
shows it using it.
