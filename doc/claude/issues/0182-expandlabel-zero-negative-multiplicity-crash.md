# 0182 — `expandlabel()` segfaults on zero- and negative-multiplicity label expressions

Status: **FIXED** 2026-07-31. Semantics were decided by the user before the fix (see
"Decided"); session prompt: `doc/claude/suggestions/next_session_prompt_0182.md`.
Area: `src/expandlabel.y` — `expandlabel_strmult()`, `expandlabel_strmult2()`, the four
`expandlabel_strbus*()`; `src/parselabel.l` (`expandlabel_collapsed`); `src/netlist.c` (the
warning)
Tests: `tests/headless/test_expandlabel_zero_neg_mult_0182.tcl` — **92 checks**
Found: 2026-07-31, by the label battery run for issue 0180's Phase 1
Related: 0180 (the battery that turned it up), 0184 (a *different* crash in the same file,
found by extending this battery — still open)

## The crash, three variants

All three are reachable from a plain `lab=` attribute on an instance in a schematic —
ordinary user data — **and** from the pure `xschem expandlabel` command, which needs no
design at all.

### 1. A zero-multiplicity sub-expression multiplied again

`expandlabel_strdup("")` returns **NULL**, because it calls `my_strdup`, which NULLs its
destination for an empty source (`src/util.c:193`). So `0*a` yields a NULL list string
with `m = 0`:

```c
src/expandlabel.y   if(n==0) return expandlabel_strdup("");   /* -> NULL */
src/expandlabel.y   len=strlen(s);                            /* <- strlen(NULL) if n != 0 */
```

Multiply that NULL by anything non-zero and `strlen(NULL)` faults.
`expandlabel_strmult2()` has the identical shape.

### 2. A bus index range with a zero repetition count

```c
src/expandlabel.y   for(r=0; r < $7; r++) { ... ++$$[0] ... }   /* $7 == 0 -> no iterations */
src/expandlabel.y   my_realloc(_ALLOC_ID_, &res, n[0]*(strlen(s)+20));   /* n[0]==0 -> size 0 */
src/expandlabel.y   sprintf(res+l, "%s[%d]", s, n[i]);                   /* res NULL; n[1] uninit. */
```

`my_realloc()` with size 0 **frees** its target and sets it to NULL (`util.c:907-910`), so
`res` is NULL by the time the tail `sprintf` writes through it, and `i` is 1 rather than
`n[0]` so `n[1]` was never assigned. `a[3:0:1:0]` and `a[0:0:0:0]` both fault here.
A **negative** repetition count (`a[3:0:1:-1]`) lands on the same `n[0] == 0`.

### 3. A negative multiplier

`expandlabel_strmult(-1, "a")` computes `my_malloc((len+1) * n)` with `n = -1`, which
converts to a huge `size_t`; `my_malloc` prints `allocation failure for -2 bytes`, returns
NULL, and the `memcpy` writes through it.

## Measured — 29 crashing expressions, not the 8 first reported

Re-measured 2026-07-31 on the shipped binary, one subprocess per candidate. The original
filing found 8; extending the battery found **21 more**, all of them the same three
mechanisms reached through untried spellings:

| class | crashing inputs |
|---|---|
| re-multiplied zero list | `2*(0*a)` `(0*a)*2` `0*a*2` `2*0*a` `a*0*2` `2*((0*a))` `2*(0*$foo)` `2*0*a,c` `2*(0*a),b` `2*0*a[3:0]` `a[3:0]*0*2` |
| zero-width bus, all four `strbus*` variants | `a[3:0:1:0]` `a[0:0:0:0]` `a[3:0:1:-1]` `a[3:0:1:0]_x` `a[0:0:0:0]_x` `a[3..0..1..0]` `a[3..0..1..-1]` `a[3..0..1..0]_x` `2*a[3:0:1:0]` `a[3:0:1:0]*2` `0*a[3:0:1:0]` `2*(a[3:0:1:0])` `a[3:0:1:0],b` `b,a[3:0:1:0]` |
| negative multiplier | `-1*a` `-2*a` `2*-1*a` `-1*(a,b)` `-1*a[3:0]` |

The `_x` suffix and `..` (nobracket) spellings matter: they reach
`expandlabel_strbus_suffix()`, `expandlabel_strbus_nobracket()` and
`expandlabel_strbus_nobracket_suffix()`, three functions the original filing never named.

**Reachable from schematic data**: an instance carrying `lab=2*(0*a)` segfaults
`xschem list_nets` *and* `xschem netlist`; so does `lab=c[3:0:1:0]`.

**Only `expandlabel_strmult()` can see a negative multiplier.** The postfix spelling
`a*-1` never reaches `expandlabel_strmult2()`: at `*` the lexer prefers
`{SP}\*{SP}/({ID}|[(])` (`parselabel.l:316`) over `{MULTIP}/{INT}` (`:322`) because `ID`
admits a leading `-`, so `-1` comes back as `B_NAME` and `list '*' list` is a syntax error
already. `strmult2()` is guarded anyway.

## Decided (2026-07-31) — and what implementing them cost

1. **Zero-collapse follows the `0*a` precedent.** Every collapsing form returns **the
   original input string** with **`*m == -1`**, exactly as `0*a` and `a*0` already do.
   *Rejected:* a real zero-width bus (`""` with `m == 0`), and treating the zero cases as
   errors.
2. **A negative multiplier is a typo** — the existing `yyparse_error` path. *Rejected:*
   silently clamping negative to zero.
3. **Warn once per schematic**, in the style of the `'#'`-label warning from issue 0165.
   *Rejected:* fixing it silently; warning only during netlisting.

(1) needed **no new semantics**: the fall-through at `parselabel.l:139-142` already
re-`my_strdup2`s the input and sets `*m = -1` whenever the parse produced a NULL. The whole
of rule 1 is therefore "stop the fault and let the NULL propagate":

* `expandlabel_strmult()` / `expandlabel_strmult2()` — `if(!s) return NULL;` after the
  `n==0` early return.
* the four `expandlabel_strbus*()` — `if(!s || n[0] < 1) return NULL;` at entry, before the
  `my_realloc` that would free `res` to NULL.

Rule 2 is `if(n<0) { yyerror(...); return NULL; }` in both `strmult` functions. `yyerror()`
(`expandlabel.y:61-66`) is the precedent and does exactly `if(yyparse_error == 0)
yyparse_error = 1;`. Verified that this reaches the report: `parselabel.l:114-117` is
`yy_scan_string; yyparse(); yy_delete_buffer; if(yyparse_error==1)`, with nothing in between
that writes the flag, and the only two resets to 0 in the tree are at the start of a netlist
run (`scheduler.c:7601`, `callback.c:6200`). Measured: `-1*a` now prints
`syntax error in -1*a` and returns `-1*a` with `m = -1`.

**`$$.m` is still assigned in the productions that now return NULL** (`expandlabel.y:341`,
`:348`, `:385`, ...) and `line: list` still copies it into `dest_string.m`. That is harmless
only because `dest_string.str` is NULL and the else-branch overwrites `*m` with -1. Do not
"tidy" the helpers into returning `""` — `""` is not NULL, the if-branch would win, and the
zero-width-bus semantics the user rejected would ship silently.

The `*m == -1` half of rule 1 is load-bearing: `expandlabel()` returns NULL only for a NULL
input and sets `*m = -1` there, and sibling loops such as `hilight.c:1008` are safe only
because of that coupling.

## The warning (rule 3)

`expandlabel()` is the wrong place to emit it — it runs on every redraw, hit-test and
hierarchy walk. Instead a new global records *what the last expansion did*:

```c
src/parselabel.l   int expandlabel_collapsed = 0;   /* cleared at the top of expandlabel() */
```

set **only** by the six new guards, and read at the 0165 ERC site inside
`name_nodes_of_pins_labels_and_propagate()` (`netlist.c`), on the same `print_erc` gate
(`netlist.c:1426`) that makes ERC print once per schematic per netlist pass:

```
Warning: instance: lA: net name '2*(0*a)' has a zero-width sub-expression and
expands to nothing; it names no node
```

The discrimination is the point. `0*a` reaches NULL through the `n==0` early return, which
does **not** set the flag, so the long-standing legal forms — `0*a`, `a*0`, `0*a,b`,
`b,0*a`, `(a,b)*0`, `0*(a,b)`, `0*a[3:0]`, `a[3:0]*0`, `a*-1` — stay silent. Test leg EW3
pins that, and is worth more than the legs that prove the broken label *does* warn.

## Verification

* `tests/headless/test_expandlabel_zero_neg_mult_0182.tcl` — 92 checks, every one in its own
  subprocess. **RED verified**: against the stashed pre-fix binary it scores
  **41 FAILED / 51 passed**; after the fix, 92/92.
* The battery's 44 non-crashing rows are **controls**, byte-identical before and after.
  Four of them (`a[3:0]`, `a[3..0]`, `a[3:0]_z`, `a[0..3]_z`) exercise the working path of
  each of the four guarded `strbus*` functions.
* `tests/netlist_diff/netlist_diff.sh <pre-fix>` — 189 schematics x 5 backends x 2 binaries,
  945 runs per arm, 0 errors: **BYTE-IDENTICAL (920 netlists)**.
* Ten named suites re-run green at their recorded counts (0180 9, 0165 15, 0179 10, 0163 34,
  0164 23, 0157 19, 0158 21, 0156 23, ase_unnamed_net 28, 0155 12), plus
  `tests/stable_handles/net_body.tcl` 39 PASS / 0 FAIL on the `--nogui` arm.

## What this did NOT fix

Extending the battery turned up a **separate** heap-corruption bug in the same file: the
file-static `idxsize` is only reset on the success path of the `B_NAME '[' index ']'`
productions, so a malformed bus label leaves it large and the *next* bus label overflows its
8-int allocation (`realloc(): invalid next size`, glibc abort). It reproduces identically
before and after this fix and needs no zero multiplicity at all. Filed as
**0184** (`doc/claude/issues/0184-expandlabel-idxsize-static-leaks-across-parses.md`).

Also unaddressed, and out of scope: an absurd multiplier (`2000000000*a`) or bus span still
asks the allocator for the full result. That is a resource question, not a correctness one —
the arithmetic does not overflow `size_t` on a 64-bit build because `n` is an `int`.

## What is NOT wrong here

The battery also settled a question issue 0180 raised: **is there a label whose reported
multiplicity exceeds the number of non-empty comma tokens in its expansion?** That would be
a second, independent trigger for 0180.

**Measured across all 73 candidates: the empty string is the only one.** `{}` → `""` with
`mult == 1` and zero tokens. Every zero-multiplier form either reports `mult = -1` (so the
loop never runs) or reports a multiplicity that matches its token count exactly.
`my_strtok_r` **skips** empty tokens (`util.c:168`) rather than returning NULL for them, so
an interior `,,` does not truncate either. That angle is closed.

## Reproduce (pre-fix)

```sh
./src/xschem --nogui --pipe -q --nolog --script /dev/stdin <<'EOF'
puts [xschem expandlabel {2*(0*a)}]
EOF
```
