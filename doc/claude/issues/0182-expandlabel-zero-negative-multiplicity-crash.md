# 0182 — `expandlabel()` segfaults on zero- and negative-multiplicity label expressions

Status: **OPEN** — reachable, measured, **not fixed**; the fix needs a semantic decision
(see "Why this is not a one-line guard").
Area: `src/expandlabel.y` — `expandlabel_strmult()`, `expandlabel_strmult2()`, `expandlabel_strbus*()`
Tests: none yet
Found: 2026-07-31, by the label battery run for issue 0180's Phase 1
Related: 0180 (the battery that turned it up)

## The crash, three variants

All three are reachable from a plain `lab=` attribute on an instance in a schematic —
ordinary user data — **and** from the pure `xschem expandlabel` command, which needs no
design at all.

### 1. A zero-multiplicity sub-expression multiplied again

`expandlabel_strdup("")` returns **NULL**, because it calls `my_strdup`, which NULLs its
destination for an empty source (`src/util.c:193`). So `0*a` yields a NULL list string
with `m = 0`:

```c
src/expandlabel.y:163   static char *expandlabel_strmult(int n, char *s)
src/expandlabel.y:163     if(n==0) return expandlabel_strdup("");   /* -> NULL */
src/expandlabel.y:164     len=strlen(s);                            /* <- strlen(NULL) if n != 0 */
```

Multiply that NULL by anything non-zero and `strlen(NULL)` faults.
`expandlabel_strmult2()` (`:128-131`) has the identical shape.

### 2. A bus index range with a zero repetition count

```c
src/expandlabel.y:429   for(r=0; r < $7; r++) { ... ++$$[0] ... }   /* $7 == 0 -> no iterations */
src/expandlabel.y:205   my_realloc(_ALLOC_ID_, &res, n[0]*(strlen(s)+20));   /* n[0]==0 -> size 0 */
src/expandlabel.y:216   sprintf(res+l, "%s[%d]", s, n[i]);                   /* res may be NULL; n[1] uninitialised */
```

`a[3:0:1:0]` and `a[0:0:0:0]` both fault here.

### 3. A negative multiplier

`expandlabel_strmult(-1, "a")` computes `my_malloc((len+1) * n)` with `n = -1`, which
converts to a huge `size_t`, the allocation fails, and the `memcpy` at `:169` writes
through the NULL.

## Measured — 38 label expressions, each in its own subprocess

`xschem expandlabel` on the shipped binary. `CRASH` = SIGSEGV.

```
[2*(0*a)]      CRASH          [0*a]          exp=|0*a|   mult=-1
[(0*a)*2]      CRASH          [a*0]          exp=|a*0|   mult=-1
[0*a*2]        CRASH          [0*a,b]        exp=|,b|    mult=1
[2*0*a]        CRASH          [b,0*a]        exp=|b,|    mult=1
[2*0*a,c]      CRASH          [a,0*b,c]      exp=|a,,c|  mult=2
[a[3:0:1:0]]   CRASH          [0*a,0*b]      exp=|,|     mult=0
[a[0:0:0:0]]   CRASH          [2*(0*a,b)]    exp=|,b,,b| mult=2
[-1*a]         CRASH          [a[3:0:1:2]]   exp=|a[3],a[2],a[1],a[0],a[4],a[3],a[2],a[1]| mult=8
```

The same four of these that are expressible as an instance attribute
(`lab=2*(0*a)`, `lab=(0*a)*2`, `lab=0*a*2`, `lab=2*0*a`) crash the **editor** on
`xschem list_nets` over a schematic containing them, not merely the `expandlabel`
command.

## Why this is not a one-line guard

Adding `if(!s) return expandlabel_strdup("");` to `expandlabel_strmult{,2}()` stops the
fault, but it also **decides what these expressions mean**, and that decision reaches the
netlist:

- Is `2*(0*a)` a zero-width bus (multiplicity 0, contributing no nodes), or a syntax
  error the user should see a dialog for?
- `0*a` today returns the **original string** `0*a` with `m = -1` (the `parselabel.l:139-142`
  else-branch re-`my_strdup2`s the input when the parse produced a NULL). Should
  `2*(0*a)` follow that precedent and come back as its own source text, or as `""`?
- `a[3:0:1:0]` currently reads an **uninitialised** `n[1]` — whatever it emits today is
  undefined, so there is no existing behaviour to preserve, only one to choose.
- `-1*a` is arguably a plain input error that deserves the existing
  `yyparse_error` / `tk_messageBox` path rather than a silent empty expansion.

Every one of those choices changes what a netlist contains for a schematic that today
crashes. That is a design call about the label mini-language, not a mechanical
NULL-check, so it is filed rather than patched.

## What is NOT wrong here

The battery also settled a question issue 0180 raised: **is there a label whose reported
multiplicity exceeds the number of non-empty comma tokens in its expansion?** That would
be a second, independent trigger for 0180 — it needs no empty lab, because the
`for(k = 1; k <= mult; ++k)` cursor in `list_nets()` would simply run dry on a later
iteration.

**Measured across all 38 candidates: the empty string is the only one.**
`{}` → `""` with `mult == 1` and zero tokens. Every zero-multiplier form either reports
`mult = -1` (so the loop never runs) or reports a multiplicity that matches its token
count exactly. `my_strtok_r` **skips** empty tokens (`util.c:168`) rather than returning
NULL for them, so an interior `,,` does not truncate either. That angle is closed.

## Reproduce

```sh
./src/xschem --nogui --pipe -q --nolog --script /dev/stdin <<'EOF'
puts [xschem expandlabel {2*(0*a)}]
EOF
```
