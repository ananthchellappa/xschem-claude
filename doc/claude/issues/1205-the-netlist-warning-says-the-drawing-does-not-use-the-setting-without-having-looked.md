# 1205 - the netlist warning says the drawing does not use the setting, without having looked

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6a. Verified by row AS49 (behavioural) and row AS50 (structural, asked of one function body).
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

---

## Fixed, 2026-08-31, item S6a

The short-circuited `if(auto_spec_name(inst) && cell_body_reads_token(inst, p))`
in `warn_unused_instance_attr()` (`src/token.c`) is gone. Both answers are now
worked out once and held in `spec` and `body_reads`, and the advice picks its
shape from them - so the sentence never states a fact the code declined to look
up.

The advice has **four** shapes below the unchanged `UA_ELSEWHERE` one:

1. **the drawing really does not use the setting** - today's wording, word for
   word, and now true rather than assumed. This is the population rows UF10 and
   UF13 of `tests/headless/test_unused_attr_0970.tcl` sit in.
2. **the drawing uses it but the value is blank** - see [[1206]].
3. **the drawing uses it and the copy would have qualified, but this run wrote
   one sheet** - see [[1204]].
4. **the drawing uses it and something structural stops a copy being written**
   (the symbol names its own drawing, its template names the cell body, or the
   copy is left out of the deck): *"The `aslook` drawing does use `modelp`, so
   this is not a spelling mistake. XSCHEM did not give this copy a version of
   its own here, so the setting still changed nothing. For it to count, the
   `aslook` symbol has to pass `modelp` through on its SPICE line."*

RULING D5-4 still holds: all five shapes are assembled into one `advice` buffer
and handed to ONE `my_snprintf`, and the sentence reaches the info window
exactly once.

Two of the three new sentences are un-ratified and on the owed ledger.

**What the fix left behind, filed as [[1216]].** The advice now has four
shapes, and each carries its own copy of the opening clause - `"%s never reads
%s when the netlist is written"` appears four times in `src/token.c`. Only one
of the four is pinned by a row. The four agree today; three of them can drift
with every suite green. RULING D5-4.
