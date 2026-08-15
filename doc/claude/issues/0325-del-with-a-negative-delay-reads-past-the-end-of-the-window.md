# 0325 — `del()` with a negative delay reads past the end of the window

Status: **FIXED** 2026-08-15 (Calculator batch item 12). Found by the adversarial check of the
authored function catalogue (`doc/claude/calculator_batch/recon/catalogue_defects.md`, finding
**D2**), which noticed that the Calculator spec's own `lshift` recipe — "`del()` with a negative
arg" — could not work; confirmed here with a reproducer under valgrind, and found to be worse
than the finding claimed (an uninitialised index as well as the one-past-the-end read).

Area: `plot_raw_custom_data()`, the `DEL` arm — `src/save.c:2586` (pre-fix numbering
`:2586`-`2607`), and `ravg_store()` `src/save.c:2280`-`2309` (the `my_calloc` at `:2297`);
also `raw_add_vector()` `src/save.c:1186`-`1226` and `draw_graph_points()` `src/draw.c:4282`
(both added in the fix round below)
Tests: `tests/headless/test_del_negative_arg.tcl` (new, 24 checks) +
`tests/headless/del_negative_arg_child.tcl` (its valgrind/graph-door helper)
Found: 2026-08-15, by the recon crew of the Calculator batch
Related: **0213** (the last out-of-bounds read in this subsystem), spec
`doc/claude/specs/calculator.md` §3.1/§3.2/§7.2/§7.2a,
`doc/claude/code_analysis/waveform_subsystem_reference.md`

## Symptom

Any expression containing `del()` whose delay operand is negative makes the evaluator read one
element past the end of two different allocations, and start its search from an **uninitialised**
index. Nothing is written out of bounds.

**It is a reproducible crash on the door this issue calls "the path a user takes".** The first cut
of this issue said "there is no crash on this machine — the result is a column of wrong numbers";
that was measured only through `xschem raw add`. Re-measured in the review round, on a binary
built from `6ce8bf3d` with **both** `src/save.c` and `src/draw.c` reverted, against an 8-point
transient raw and a graph rect carrying `node="v(a) -2.6e-09 del()"`:

```
graph node= door, redrawn twice   : FATAL: signal 11  in 15 runs out of 15
xschem raw add door, same process : 0 crashes in 15 runs (but SIGSEGVs under valgrind,
                                    which moves the heap — 129 errors / 11 contexts)
same fixture, fixed binary        : 0 crashes in 15, valgrind clean on both doors
```

The search index is garbage, so *which* invalid address it lands on is a function of what was on
the stack — "reads only" bounds the damage of the walk, it does not bound the consequence. Do not
read "no crash was seen" in any part of this file as "this is only a wrong-numbers bug".

`valgrind` on the reproducer, **before** the fix (8-point transient raw, `v(a) -2.6e-09 del()`
through `xschem raw add`):

```
==1268101== Invalid read of size 8
==1268101==    at 0x1E3E07: plot_raw_custom_data
==1268101==  Address 0x704cc60 is 0 bytes after a block of size 64 alloc'd
==1268101==    by 0x1DBD8F: my_realloc
==1268101==    by 0x1DDDF5: read_raw_data_block            <-- x[last + 1], the sweep column
==1268101== Invalid read of size 8
==1268101==    at 0x1E3E6E: plot_raw_custom_data
==1268101==  Address 0x5bcb850 is 0 bytes after a block of size 64 alloc'd
==1268101==    by 0x1DBC0D: my_calloc                      <-- arr[i][last + 1], ravg_store()'s
==1268101== ERROR SUMMARY: 382 errors from 10 contexts
```

plus four `Use of uninitialised value of size 8` and three `Conditional jump … depends on
uninitialised value(s)` contexts, all in `plot_raw_custom_data`, whose origin `--track-origins=yes`
gives as *"Uninitialised value was created by a stack allocation at … plot_raw_custom_data"*.

Same reproducer **after** the fix, running the whole new test file: `ERROR SUMMARY: 0 errors from
0 contexts`.

## The path a user takes to hit it

No Calculator needed — this is shipped behaviour on the graph:

1. Open a schematic with a graph and load a raw file.
2. Edit the graph's `node=` attribute (or type into the node entry) to any RPN containing a
   negative `del()` delay, e.g. `v(a) -2n del()`. A token counts as an expression as soon as it
   contains whitespace (landmine L3), so this is exactly what a user types.
3. Redraw. `draw_graph_variables()`/`draw_graph_points()` hand the string to
   `plot_raw_custom_data()` — `src/draw.c:5432`, `:5449`, `:5653`, `:6704`, `:7142`, `:8298`,
   `:9171`, `:9221` — and the out-of-bounds read happens **once per redraw, per dataset**.

The other reachable door is `xschem raw add <name> <rpn>` → `raw_add_vector()`
(`src/save.c:1207`), which is what the test drives.

## Root cause

```c
case DEL:
  tmp = stack2[stackptr2 - 1];                      /* the delay */
  ravg_store(1, i, p, last, stack2[stackptr2 - 2]); /* remember this point's input */
  if(fabs(x[p] - x[first]) <= tmp) {
    result = stack2[stackptr2 - 2];
    stack1[i].prevp = first;                        /* <-- the ONLY seed of prevp */
  } else {
    double delta = fabs(x[p] - x[stack1[i].prevp]);
    while(stack1[i].prevp <= last && delta > tmp) { /* <-- runs to last + 1 */
      stack1[i].prevp++;
      delta = fabs(x[p] - x[stack1[i].prevp]);      /* <-- reads x[last + 1] */
    }
    …
    result = ravg_store(2, i, stack1[i].prevp, 0, 0); /* <-- arr[i][last + 1] */
  }
```

Three facts compose:

1. **`delta` is a `fabs()`**, so `delta > tmp` is true at *every* point when `tmp < 0`. The search
   is a forward walk only — it can never produce a left shift, which is what "`del()` with a
   negative arg" was supposed to mean.
2. **The walk's bound is `prevp <= last`**, tested *before* the increment, so `prevp` legitimately
   reaches `last + 1` and the next line indexes `x[last + 1]`. `x` is
   `xctx->raw->values[sweep_idx]`, allocated with `raw->allpoints` doubles in
   `read_raw_data_block()`; `ravg_store()`'s `arr[i]` is `my_calloc(_ALLOC_ID_, last + 1,
   sizeof(double))` (`src/save.c:2297`), so `last + 1` is one past both.
3. **`Stack1 stack1[STACKMAX]` is an uninitialised local** (`src/save.c:2386`) and the only
   assignment to `stack1[i].prevp` is in the `if` arm — the arm a negative `tmp` can never take,
   *including at `p == first`*, where `fabs(x[first] - x[first])` is 0 and `0 <= tmp` is false.
   So the first search of the wave starts from whatever was on the stack.

For a **non-negative** `tmp` none of this is reachable: `prevp <= p <= last` at all times and
`delta` is 0 at `prevp == p`, so `delta > tmp` stops the walk before the bound ever matters, and
`p == first` always takes the `if` arm and seeds `prevp`. That is why the fix cannot move a
positive `del()`.

## Fix

`src/save.c`, `case DEL` only:

- **Reject a negative (or NaN) delay** the way §3.1 says an unresolvable vector name is rejected:
  `dbg(1, …)`, `ravg_store(0, …)` to release the static scratch, and `return -1` for the whole
  evaluation. With a constant argument — the only form a generated expression emits — the
  rejection happens at `p == first`, i.e. **before the first `y[p] = …` store at the bottom of the
  point loop**, so the destination column is not touched at all. (A *vector* argument that only
  goes negative part-way through aborts at that point, leaving the prefix it had already written;
  callers treat the `-1` as "no data" either way.)
- **Bound the search with `prevp < last`** instead of `<= last`, so neither `x[]` nor
  `ravg_store()`'s `arr[i][]` can be indexed past its end even if a future change reopens the
  negative path.
- **Seed `stack1[i].prevp = first` at `p == first`**, so the search never starts from an
  uninitialised local.

## Not fixed here, deliberately

**`ravg()` has the same runaway search with a negative window** (`src/save.c` `case RAVG`, the
`while(stack1[i].prevp <= last && x[p] - x[stack1[i].prevp] > stack2[stackptr2 - 1])` loop). There
is no `fabs()` there, so a *positive* window is bounded by `p` and safe; a negative one walks to
`last + 1` and `ravg_store(2, …)` reads `arr[i][last + 1]` — measured:

```
$ valgrind … 'v(a) -2e-09 ravg()'
==1267871== Invalid read of size 8 … at plot_raw_custom_data
==1267871==  Address 0x7015050 is 0 bytes after a block of size 64 alloc'd by my_calloc
==1267871== ERROR SUMMARY: 2 errors from 2 contexts
```

Item 12's scope was `del()` and forbade touching neighbouring opcodes, so this is recorded rather
than fixed. It wants the same two-line treatment (reject a negative window, bound the walk), plus
a decision about what a negative running-average window should *mean*.

**Do not defer it on the strength of "reads only, no crash".** That was this issue's own first
reading of the `del()` twin, and the review round then measured a deterministic SIGSEGV through
the `node=` door (see Symptom). The `ravg()` sibling walks the same index into the same two
arrays; nothing about it is safer, and it is still live on the fixed binary
(`valgrind` on `node="v(a) -2e-09 ravg()"` still shows `Invalid read of size 8 at
plot_raw_custom_data`). It should be scheduled as a crash, not as a cosmetic.

## Fixed in the review round, same item

Two more were left out of the first cut and are **now fixed** (the review round measured both and
found the first one made memory safety *worse*, not better, on one of the two doors):

- **`raw_add_vector()` did not zero a newly created column when it was given an expression**
  (`src/save.c:1206`). The column a new vector gets is the previous scratch column, never zeroed,
  so a rejected evaluation — this one, *or* the pre-existing unknown-vector `-1` — registered a
  plottable, Tcl-readable vector made of uninitialised heap. The first cut's rejection turned a
  column of defined-but-wrong numbers into that, on the door
  `wviewer::add_trace` takes: `src/wave_viewer.tcl:3785` passes an auto-generated NEW name and
  `wviewer::validate_rpn` accepts both `-2.6e-09` and `del()`. FIXED: the zeroing loop now runs for
  any newly created column, before the expression is evaluated into it. Pinned by DN13 and,
  deterministically, by DN11's valgrind child (which reads the column back through Tcl, so an
  unzeroed one is an uninitialised-value *use*).
- **`draw_graph_points()` loaded `raw->values[idx]` before its own `if(idx == -1) return;`**
  (`src/draw.c:4282`). That is not "a pointer load, never dereferenced" as this issue first
  recorded it: the load itself is an 8-byte read 8 bytes *before* the `values[]` block, which
  valgrind reports as `Invalid read of size 8`, on every redraw of a graph whose expression was
  rejected — which is exactly what the `del()` rejection newly routes into it. FIXED: the load
  moved below the guard. Pinned by DN11's graph-door leg.
  *Nuance worth keeping*: at `-O2` the defect only reproduces because the original load sits
  **above the `dbg()` call**, which is an optimisation barrier. Moving the load below the call but
  above the branch lets GCC sink the dereference past the branch on its own (measured: `lea`
  before the `je`, `mov (%rax)` after it), and valgrind then reports nothing. A sabotage of this
  line must restore the original *order*, not merely put the load before the `if`.

## Spec consequence

`doc/claude/specs/calculator.md` §7.2 prescribed `lshift` as "C (`del()` with negative arg) or T".
Phase 1d had already demoted the row to **T** on the strength of the unconfirmed finding; §7.2a and
§3.2 now record the confirmed behaviour and point here, so nobody re-derives it.
