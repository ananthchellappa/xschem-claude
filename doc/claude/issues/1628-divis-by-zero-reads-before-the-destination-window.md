# 1628 — `x/0` in the RPN engine reads before the destination window

**STAMP:** `v1 claim=fixed tree=99a948e8 stamped=2026-10-01 fix=taken open=1`

Status: **FIXED** 2026-10-01 (calculator_batch stage `E-engine-divis-1628`). Found through the
Calculator's new Evaluate door: `1 0 /` typed into the buffer and Evaluated answered
`= 8.068092e-321` with `ok=1` — a confident garbage number, not an error.

Area: `plot_raw_custom_data()`, the `DIVIS` arm — `src/save.c`. Reached from
`raw_add_vector()` (which passes `first = 0`) and from the graph redraw / marker paths in
`src/draw.c` (which pass the offset of the dataset the point lives in, i.e. a `first > 0`).
Tests: `tests/headless/test_divis_zero_1628.tcl` (new, 33 checks, `hcases`) +
`tests/headless/divis_zero_child.tcl` (its valgrind / `-d 1` helper)
Found: 2026-10-01, driving the Calculator's Evaluate button against the committed fixture
Related: **0325** (`del()` with a negative delay — **the same defect class in the same
function**, and the template for both this fix and its fence), **0213**, spec
`doc/claude/specs/calculator.md` §3 / §3.1 / landmine **L2**,
`doc/claude/code_analysis/waveform_subsystem_reference.md`

## Symptom

Any RPN expression that divides a non-zero value by zero **at the first point of the
evaluated window** answers a number that came from outside that window. There are two
distinct cases, and only the first is a memory-safety defect:

```
1 0 /  through the Calculator's Evaluate      = 8.068092e-321   (ok=1)
1 0 /  through `xschem raw add`               = 4.0019317e-322  at every point
v(a) 0 /  under valgrind                      = 8.8210093e+252  at every point
```

Three doors, three different "answers" for the same expression. Nothing is written out of
bounds.

Under `valgrind`, **before** the fix (8-point ascii transient raw, `v(a) 0 /` through
`xschem raw add`):

```
==1952196== Invalid read of size 8
==1952196==    at 0x40E8735: plot_raw_custom_data
==1952196==    by 0x40E9A4E: raw_add_vector
==1952196==  Address 0x687ac38 is 8 bytes BEFORE a block of size 64 alloc'd
==1952196==    at realloc (vg_replace_malloc.c:1804)
==1952196==    by 0x40DE4CF: my_realloc
==1952196==    by 0x40E1515: read_raw_data_block
```

Same reproducer **after** the fix, running the whole new suite's child: `ERROR SUMMARY: 0
errors from 0 contexts` (exit 0 under `--error-exitcode=42`).

## The path a user takes to hit it

**Two doors, and the second one is shipped behaviour that predates the Calculator.**

1. **The Calculator.** Type `1/0` (or anything whose divisor is zero at the first sample —
   a ratio of two signals where the denominator starts at 0 is the ordinary analog case:
   a gain `v(out) v(in) /` on a circuit that starts from rest) and press **Evaluate**. The
   answer is reported as a value, with no indication that the division failed.
2. **The graph.** Put the same RPN in a graph's `node=` attribute, or place a marker on an
   expression trace. `draw_graph_variables()` / `draw_graph_points()` /
   `graph_marker_sample()` hand the string to `plot_raw_custom_data()` with `first` set to
   the offset of the dataset the point lives in — so on a **multi-dataset** raw the read is
   in bounds, lands in the shared scratch column, and returns whatever the previous pass
   left there. Measured on a two-dataset raw whose divisor is zero at dataset 1's first
   sample: the marker answered **4**, then **400** after an unrelated expression had been
   plotted in between. Same point, same file, two answers.

## Root cause

```c
case DIVIS:
  if(stack2[stackptr2 - 1]) {                    /* divisor non-zero: ordinary divide */
    stack2[stackptr2 - 2] = stack2[stackptr2 - 2] / stack2[stackptr2 - 1];
  } else if(stack2[stackptr2 - 2] == 0.0) {      /* 0/0 -> 0 */
    stack2[stackptr2 - 2] = 0;
  } else {
    stack2[stackptr2 - 2] =  y[p - 1];           /* x/0 -> hold the previous output */
  }
```

⚠ **That `else` is not nonsense and must not simply be deleted.** It is a deliberate
hold-the-previous-output heuristic, so a transient zero crossing in a divisor does not
destroy a whole trace. **The defect is the INDEX, not the idea.**

`y` is the destination column base (`xctx->raw->values[xctx->raw->nvars]`, the single
shared scratch column, or `values[yidx]` when the caller named a destination) and the point
loop is

```c
for(p = first ; p <= last; p++) { ... y[p] = (SPICE_DATA)stack2[0]; }
```

so `y[p - 1]` is "the previous point this pass computed" **only while `p > first`**. Two
facts compose:

1. **`p == 0`**, which is what `raw_add_vector()` passes (`plot_raw_custom_data(sweep_idx,
   0, raw->allpoints - 1, expr, varname)`): `y[-1]` is an **out-of-bounds read** one
   `SPICE_DATA` before the column — the heap bookkeeping word, which is why the garbage
   value is a function of the column's *size* and differs between a raw of 8 points and one
   of 64. Undefined behaviour, and then the garbage **propagates**: every later point of an
   all-zero divisor column takes the hold arm and copies it forward, so one bad read fills
   the whole trace.
2. **`p == first > 0`**, which the graph door passes: `y[first - 1]` is **in bounds** and
   therefore invisible to valgrind, but was never written by this pass. It is stale data
   from whatever last used the shared scratch column — **landmine L2 of
   `doc/claude/specs/calculator.md` arriving from inside the engine** rather than from a
   caller re-using a destination name.

A **zero** numerator never reaches the arm: `0/0` is handled two lines up. That is why the
obvious reproducers on the committed fixture (`v(sq) 0 /`, `v(ramp) 0 /`) look innocent —
both columns are exactly 0 at sample 0 — and why the suite's DZ1 band uses `v(dcmid)`,
which is 3 V at every sample. A row that picks the wrong numerator measures the `0/0` arm
and passes on the broken tree.

## Fix

`src/save.c`, `case DIVIS` only, one line:

```c
stack2[stackptr2 - 2] = p > first ? y[p - 1] : 0.0;
```

- **`p > first` keeps the heuristic** where there genuinely is a previous point this pass
  computed. Not `p > 0`: that fixes only the memory-safety half and leaves the graph door
  reading the previous pass's leftovers (sabotage **S3** below).
- **`p == first` answers 0**, because that is the choice this very switch already makes for
  `0/0` two lines up — the function's own convention rather than a new one — and it is the
  minimum behavioural change.

`first` is the **widened** window start: the token scan pulls it back for `integ()`,
`deriv*()`, `prev()` and `del()` before the point loop runs, and the loop uses that value,
so `p > first` is exactly "this pass has already written `y[p - 1]`" for every expression,
widening operators included.

### Alternatives considered and rejected

- **`return -1`, rejecting the whole expression** (what §3.1 does for an unresolvable
  vector name, and what issue 0325 chose for a negative `del()` delay). Rejected: a much
  larger behavioural change for every existing graph trace that currently survives a
  transient zero divisor, and it would turn a cosmetic first-point glitch into a vanished
  trace. 0325 could afford it because a *negative delay* has no meaningful reading at all;
  a zero divisor does.
- **Guarding in Tcl, in the Calculator.** Rejected by the user: the wrong number should
  become impossible rather than hidden, and the fix should reach every caller — Calculator
  Evaluate, Calculator Plot, graph expression traces and `xschem raw add`.
- **Propagating an IEEE infinity.** Rejected: it changes what every downstream consumer
  sees, including axis autoscaling, and nothing in this file produces infinities today.
  ⚠ Measured as sabotage **S4**: with the ordinary divide let through, `xschem graph_marker
  add_at` stopped creating markers at all (`NOMARKER`) on the expression trace. So an
  infinity is not merely cosmetic — it breaks a door that currently works.

## Scope — the rest of the switch was checked and is clean

`y[p - 1]` has exactly **one** site in `src/save.c`, and `y[p]` exactly one other (the
store at the bottom of the point loop). No other arm of this switch indexes the destination
column relative to `p`; the operators that need the previous point (`PREV`, `DERIV*`,
`DEL`, `RAVG`) carry their own per-operator state in `stack1[i]` (`prevy`, `prevprevy`,
`prev`, `prevp`) and were not touched. Row **DZ6** of the new suite re-derives that site
list from the file's own text on every run — comments and string literals stripped first,
with three control rows proving the stripper neither blanks the code nor leaves the prose
in — so a second unguarded site added later reddens rather than hiding.

## Not fixed here, and still open

**`ravg()` with a negative window** — recorded by issue 0325 as the deliberate
leave-alone, measured there under valgrind (`Invalid read of size 8 at
plot_raw_custom_data`), and **still live on today's binary**. It is a different index on a
different allocation (`ravg_store()`'s `arr[i][last + 1]`), not the one this issue fixed,
and 0325's instruction — *"it should be scheduled as a crash, not as a cosmetic"* — stands
unexecuted. This file does not touch it: the stage's scope was `DIVIS`.

## Spec consequence

`doc/claude/specs/calculator.md` §3 describes the operator set but states no contract for
`x/0`. There is one now and it is this: **hold the previous output of this pass; at the
first point of the window, 0.** Landmine L2's note should gain a sentence saying the shared
scratch column was reachable from **inside** the engine and no longer is.
