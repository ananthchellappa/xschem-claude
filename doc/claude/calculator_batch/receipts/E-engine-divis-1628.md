# Receipt E-engine-divis-1628 — issue 1628: `x/0` read before the destination window

Stage label `E-engine-divis-1628`. Branch `fluid-editing`, tree at `99a948e8`, **nothing
committed, pushed or stashed**. All scratch under `…/scratchpad/E-engine-divis-1628/`.

The user's ruling was implemented as given: **fixed in C, in the engine**, one line in
`plot_raw_custom_data()`. It was not re-opened, and the heuristic the `else` arm exists for
was preserved rather than deleted.

---

## 0. The verdicts

| suite | `--nogui` arm | display arm (`:99`) | before this stage |
|---|---|---|---|
| **`test_divis_zero_1628`** (NEW, `hcases`) | `RESULT: ALL PASS (33 checks)` | `RESULT: ALL PASS (33 checks)` | did not exist |
| `test_del_negative_arg` (the 0325 twin) | `RESULT: ALL PASS (24 checks)` | — | 24 |
| `test_calc_engine` | `RESULT: ALL PASS (120 checks)` | — | 120 |
| `test_calc_scratch_reuse` | `RESULT: ALL PASS (46 checks)` | — | 46 |
| `test_calc_skeleton` | — | `RESULT: ALL PASS (548 checks)` | 548 |
| `test_calc_widgets` | — | `RESULT: ALL PASS (246 checks)` | 246 |
| `test_calc_buffer` | — | `RESULT: ALL PASS (130 checks)` | 130 |

All through the armed spelling `tests/headless/run_suites.sh [--nogui] <t>`, display arm
attached to the persistent dev display `:99`, left exactly as found (never
`start`/`stop`/`view`). `RESULT: 6/6`, `6/6`, `6/6`, `4/4` and `4/4 runs passed` for the five
batches in §5.

**The new suite scores 33 on BOTH arms and prints no `skip:` line on either**, because
nothing in it is display-only — see §3.

---

## 1. What I changed, by symbol

| file | symbol | what changed |
|---|---|---|
| **`src/save.c`** | `plot_raw_custom_data()`, `case DIVIS` | the `x/0` hold arm's index is guarded: `stack2[stackptr2 - 2] = p > first ? y[p - 1] : 0.0;` (was `y[p - 1]` unconditionally), plus the comment block that records why the arm exists at all, why the guard is `p > first` and not `p > 0`, and the three rejected alternatives. **Nothing else in the function, the file or the tree was touched.** |
| **`tests/headless/test_divis_zero_1628.tcl`** (NEW, `hcases`) | — | 33 checks, bands `DZ0`–`DZ6`. |
| **`tests/headless/divis_zero_child.tcl`** (NEW, helper) | `dz_plot`, `dz_mkraw`, `dz_graph` | the valgrind (`mem`) and `-d 1` (`win`) child, deliberately **not** named `test_*.tcl` — `full_audit.sh` globs those and would score a zero-check file FAIL forever. Same shape as `del_negative_arg_child.tcl`. |
| **`tests/run_regression.tcl`** | `hcases` | one entry: `"headless/test_divis_zero_1628"`, plus a comment block saying why it is `hcases` ALONE and why `test_del_negative_arg` was left unregistered. |
| **`doc/claude/issues/1628-divis-by-zero-reads-before-the-destination-window.md`** (NEW) | — | the issue, stamped `v1 claim=fixed tree=99a948e8 stamped=2026-10-01 fix=taken open=1`. |
| **`doc/claude/issues/NUMBERING.md`** | the `1628` entry and the tail pointer | pointer `1628` → `1629`. |

### The C diff, and why that shape

```diff
             } else {
-              stack2[stackptr2 - 2] =  y[p - 1];
+              /* …30 lines recording the heuristic, the two defects, the
+               *  convention the 0 comes from, and the rejected options… */
+              stack2[stackptr2 - 2] = p > first ? y[p - 1] : 0.0;
             }
```

`p > first`, not `p > 0`: `first` is the **widened** window start (the token scan pulls it
back for `integ()`, `deriv*()`, `prev()` and `del()` before the point loop runs, and the loop
uses that value), so `p > first` is exactly "this pass has already written `y[p - 1]`" for
every expression, widening operators included. `p > 0` fixes only the memory-safety half and
is sabotage **S3** below.

**0, not anything else**, because it is the value this same switch already produces for `0/0`
two lines up — the function's own convention rather than a new one, and the minimum
behavioural change.

### I agree with the driver's rejection of all three alternatives, and one of them got worse under measurement

* **`return -1`** (reject the whole expression, what an unresolvable vector name does, and
  what issue 0325 chose for a negative `del()` delay). Agree. 0325 could afford it because a
  negative delay has no meaningful reading; a zero divisor does, and the arm exists precisely
  so a transient crossing does not destroy a trace.
* **Guarding in Tcl.** Agree, and the measurement makes it stronger than the ruling needed:
  the half of the defect that matters most (`first > 0`, §2.2) is **not reachable from the
  Calculator at all** — `raw_add_vector()` hardcodes `first = 0`. A Tcl-side guard in
  `calculator.tcl` would have left the graph and marker doors reading the previous pass's
  leftovers forever.
* **IEEE infinity.** Agree, and ⚠ **it is worse than "changes what downstream sees"**:
  measured as sabotage **S4**, with the ordinary divide let through, `xschem graph_marker
  add_at` stopped creating markers at all on the expression trace (`NOMARKER`, four rows).
  An infinity breaks a door that works today.

### The same index defect elsewhere in the switch: there is none

`y[p - 1]` has exactly **one** site in `src/save.c` and `y[p]` exactly one other (the store at
the bottom of the point loop). The operators that need a previous point (`PREV`, `DERIV*`,
`DEL`, `RAVG`) carry per-operator state in `stack1[i]` (`prevy`, `prevprevy`, `prev`, `prevp`)
and index `x[]`/`arr[]`, not `y[]`. Nothing was touched outside `DIVIS`. Band **DZ6**
re-derives that site list from the file's own text every run, so a second unguarded site added
later reddens.

⚠ **One pre-existing crash in the same function is still live and I did not touch it**:
issue 0325's `ravg()` sibling (`case RAVG`'s runaway search with a negative window), which
0325 says should be *"scheduled as a crash, not as a cosmetic"*. Still reproducible on today's
binary per that file. Recorded as issue 1628's one open item.

---

## 2. The red, verbatim

Captured on the **unfixed** tree (`src/xschem` rebuilt from `99a948e8`'s `save.c` first —
see §6), `…/scratchpad/E-engine-divis-1628/red2.log`. **11 rows red, 19 green.**

```
FAIL: DZ1a a literal x/0 answers 0 at the first point, not a number from before the column -> {1 8.068092e-321} (exp {1 0}) : FAIL
FAIL: DZ1b ...and at every one of the fixture's 202 points -> {8.06809e-321} (exp {0}) : FAIL
FAIL: DZ1c a nonzero vector numerator over a zero divisor answers 0 at the first point -> {1 8.068092e-321} (exp {1 0}) : FAIL
FAIL: DZ1c ...and at every point -> {8.06809e-321} (exp {0}) : FAIL
FAIL: DZ1d re-evaluating x/0 into an EXISTING column answers 0, not that column's old numbers -> {0 8.06809e-321} (exp {0 0}) : FAIL
FAIL: DZ1e the first-point answer does not move with the destination column's size -> {2.6136073e-321 4.0019317e-322} (exp {0}) : FAIL
FAIL: DZ2d the first point of a first>0 window answers 0, not the previous pass's last output -> {4} (exp {0}) : FAIL
FAIL: DZ2f ...and the first point of the first>0 window still answers 0 -> {400} (exp {0}) : FAIL
FAIL: DZ3c a divisor zero only at the FIRST point: 0 there, the true quotient after -> {1 {4.00193e-322 1 1.5 2 2.5 3 3.5 4}} (exp {1 {0 1 1.5 2 2.5 3 3.5 4}}) : FAIL
FAIL: DZ6 every y[p - 1] read in src/save.c CODE is on a line that also tests p > first -> {4603} (exp {}) : FAIL
FAIL: DZ5 valgrind: the raw add and graph-marker doors are memory-clean -> {42} (exp {0}) : FAIL
RESULT: 11 FAILED (19 passed)
```

`DZ1a`'s `8.068092e-321` is **the same number the driver measured through the Calculator's
Evaluate button**, reached independently here through `xschem raw add` over the committed
fixture.

### Both defects re-verified independently before the fix

**(1) `p == 0` is an out-of-bounds read.** Not inferred — witnessed:

```
==1952196== Invalid read of size 8
==1952196==    at 0x40E8735: plot_raw_custom_data
==1952196==    by 0x40E9A4E: raw_add_vector
==1952196==  Address 0x687ac38 is 8 bytes BEFORE a block of size 64 alloc'd
==1952196==    at realloc (vg_replace_malloc.c:1804)
==1952196==    by 0x40DE4CF: my_realloc
==1952196==    by 0x40E1515: read_raw_data_block
```

**And the answer is not any defensible value.** The same expression gave three different
numbers on three doors — `8.068092e-321` (Calculator), `4.0019317e-322` (`raw add`),
`8.8210093e+252` (under valgrind) — and a fourth, `2.6136073e-321`, on an 8-point raw against
`4.0019317e-322` on a 64-point one. The read lands on the heap bookkeeping word immediately
before the column, so **the garbage is a function of the column's size**, which is what row
`DZ1e` asserts without naming any of those numbers. It then **propagates**: every later point
of an all-zero divisor column takes the hold arm and copies it forward, so one bad read fills
the whole trace (`DZ1b`).

**(2) `p == first > 0` is in-bounds stale data.** Measured deterministically and headlessly,
with no valgrind in it, through the graph-marker door on a two-dataset raw whose divisor is
zero at dataset 1's first sample:

```
STEP1 dataset0 point3 y = 2      <- fills the shared scratch column, y[7] = 4
STEP2 dataset1 point8 y = 4      <- dataset 1's FIRST point "answers" dataset 0's last quotient
STEP3 dataset0 point3 y = 200    <- same graph, node= changed to `v(a) 100 * v(m) /`
STEP4 dataset1 point8 y = 400    <- the same point now "answers" 400
```

Same file, same point, two answers, decided by an unrelated expression plotted in between.
That is landmine **L2** arriving from *inside* the engine. Rows `DZ2d`/`DZ2f`.

---

## 3. The green, and the fence's shape

After the fix, both arms: `OVERALL: ok (33 checks)` / `RESULT: ALL PASS (33 checks)`
(`…/scratchpad/E-engine-divis-1628/green2.log`).

| band | what it fences | red before? |
|---|---|---|
| `DZ0` | the committed fixture is the artefact `tests/headless/data/README.md` describes; the child's generators were **lifted from the child file**, not copied | no (premise) |
| `DZ1` | defect (1) at `p == first == 0` through `xschem raw add`: the committed fixture, a literal and a vector numerator, an existing destination, and the size-independence row | **6 rows** |
| `DZ2` | defect (2) at `p == first > 0` through the graph-marker door, plus a `-d 1` premise row proving the caller really passes a `first > 0`, plus the ordinary-quotient control inside that window | **2 rows** |
| `DZ3` | **the heuristic is preserved** — a mid-window zero still holds, and the held value scales with the expression; a first-point-only zero gives 0 then the true quotient | **1 row** (`DZ3c`) |
| `DZ4` | `0/0` still answers 0, including *at* a mid-window zero where the hold arm would otherwise fire; ordinary division and an unrelated operator unchanged | no (controls) |
| `DZ5` | the memory property, under `valgrind -q --error-exitcode=42` around the child | **1 row** |
| `DZ6` | the index *shape* in `src/save.c`, derived from the file's own text | **1 row** |

Three things about the fence worth the next stage's attention:

* **No row asserts a garbage value.** The driver's instruction was followed literally: every
  row asserts the defensible value (`0`, or the true quotient, or the held previous output).
  `DZ1e` is the row that asserts *no garbage* without naming a number — it requires the
  first-point answer to be identical on an 8-point and a 64-point raw.
* **Nothing throws on the broken tree.** Every engine call goes through `pcall`. The red run
  printed 11 `FAIL:` lines and reached its own verdict; it did not abort at check 6.
* ⚠ **`DZ6` scans CODE, not prose, and has three control rows for its own stripper.** Its
  first cut reddened on the **fixed** tree, because the fix's own explanatory comment contains
  the characters `y[p - 1]` — the comment became the row's counterexample, which is exactly
  the failure CLAUDE.md records for `test_snprintf_fmt_1608`. It now blanks comments and
  string literals first (newlines preserved so line numbers stay the file's own) and asserts
  that the stripper kept the line count, kept `case DIVIS`, and removed strictly more
  `y[p - 1]` lines than the raw text holds. Sabotage **S1** reddens `DZ6`'s "at least one site
  to guard" row, which is what stops the stripper passing by blanking everything.

### ⚠ The new suite needs NO display, and that is a finding, not a convenience

Issue 0325's equivalent band (`DN12` of `test_del_negative_arg`) needs a `DISPLAY`, because it
reaches a `first > 0` through a **graph redraw**. `DZ2` reaches one through
`xschem graph_marker add_at` → `graph_marker_create_at` → `graph_marker_sample`, which
**re-evaluates the expression over the point's dataset window and returns the sample through
`xschem graph_marker list`** — and touches no X at all. That is why this suite is `hcases`
alone, scores 33 on both arms and emits no `skip:` line. `graph_marker_sample`'s own comment
is the reason it re-evaluates: *"An EXPRESSION trace lives in the single GLOBAL scratch column
`values[nvars]`, so its dataset window must be re-evaluated before the read."*

---

## 4. What I sabotaged and what it reddened

Six variants, each one **rebuilt** (`make -C src`) and run before the next; the fixed
`save.c` was restored and rebuilt afterwards. Logs `…/scratchpad/E-engine-divis-1628/sab_S*.log`.

| # | the wrong implementation | rows it reddened |
|---|---|---|
| **S0** | `y[p - 1]` — the original defect, **with the fix's comment still in place** | the 11 red rows above, `DZ6` reporting the new line number. ⚠ Proves `DZ6`'s stripper does not mask the real site while the prose above it survives. |
| **S1** | `= 0.0;` always — **delete the heuristic**, the most tempting "fix" | `DZ2c`, `DZ2e` (the premises stop reading a hold), `DZ3a`, `DZ3b` (the mid-window hold is gone: `{0.5 1 1.5 0 2.5 …}`), and `DZ6`'s "at least one site to guard" |
| **S2** | `p >= first ? …` — the guard off by one | all 11, identical to S0 (the test is always true) |
| **S3** | `p > 0 ? …` — ⚠ **the plausible partial fix**: guards the out-of-bounds read and nothing else | `DZ2d`, `DZ2f` (4 and 400 again) and `DZ6`. **This is the sabotage the band exists for**: every value row in `DZ1`, `DZ3`, `DZ4` and the whole valgrind band go green, so a fence without `DZ2` would have passed a half-fix. |
| **S4** | let the ordinary divide through (**the IEEE-infinity alternative**) | 15 rows — all of `DZ1` including the `0/0` control `DZ1f`, all four `DZ2` marker rows as `NOMARKER` (markers stop being created), `DZ3a`–`DZ3c`, `DZ6` |
| **S5** | `p > first ? y[p - 1] : stack2[stackptr2 - 2]` — first point = the numerator, a defensible-looking alternative | 9 rows (`DZ1a`–`DZ1e`, `DZ2d`, `DZ2f`, `DZ3c`) |

---

## 5. Existing callers and suites — every one I found, and what each now does

`/usr/bin/grep -n 'plot_raw_custom_data\|raw_add_vector' src/*.c src/*.h` gives the complete
caller set:

| caller | reaches the arm with | changed behaviour? |
|---|---|---|
| `raw_add_vector()` ← `xschem raw add` (`src/scheduler.c`, two sites) | `first = 0` **always** | **yes** — `x/0` at point 0 now answers 0 instead of out-of-bounds garbage, and the garbage no longer propagates down the column. This is the Calculator's only door to the engine (`calc::eval_rpn`, `calc::tmpvec`), and `wviewer::add_trace`'s too. |
| `draw.c` graph redraw, the **dataset-offset** family (`:5973`, `:7024`, `:7462`, measured at `99a948e8`) | `ofs` / `ofs_end - 1`, the dataset offset — `first > 0` on any dataset after the first | **yes** — the first point of each dataset's window stops reading the previous pass's output. |
| `draw.c` graph redraw, the **visible-run** family (`:5752`, `:5769`, `:9520`, `:9570`) | a local `first`, a VISIBLE-RUN scan variable: initialised `first = -1` and set by walking points to where a plottable run begins | **yes, and this row is the correction below** |

> ### ⚠ CORRECTION BY THE DRIVER, 2026-10-01 — this table was FALSE and understated the blast radius
>
> The row above originally listed all seven `draw.c` sites together as passing *"`ofs` of the
> dataset"* and concluded *"Unchanged on dataset 0 of a single-dataset raw, where `first` is
> already 0."* **Both halves are wrong**, and two independent adversarial lenses found it.
>
> There are **eight** call sites in `src/draw.c`, in **two families that mean different things**.
> Four pass the dataset offset. Four pass a local `first` that is a visible-run scan variable
> (`first = -1; last = ofs;` then a walk) — which is **greater than zero on a single-dataset raw**
> whenever the plottable run does not start at point 0: a zoomed x range, or leading unplottable
> points. So the behaviour change reaches **more** callers than this receipt claimed, including the
> ordinary case of a zoomed single-dataset graph.
>
> **The fix is still right there** — that is the whole point of it: the old code read `y[first-1]`,
> a point *this pass never wrote*, so a zoomed trace's first visible sample was showing stale data
> from whatever last used the shared scratch column. The defect was the claim, not the code.
>
> ⚠ **The same false sentence was in `src/save.c` itself, and predates this stage.** The engine's
> own comment above the point loop said *"the graph door (`src/draw.c:9171`, `:9221`) is the ONLY
> caller that passes a `first > 0`"* — wrong about the count (eight, in two families) and wrong in
> form (bare `file:line`, rotted by ~350 lines). Corrected in the same change, citing by symbol.
> This receipt repeated that sentence's error because it trusted it, which is exactly why
> CLAUDE.md says to cite by symbol and re-grep before quoting a coordinate.
>
> **Two consequences follow and are recorded rather than fixed**, with the reasons:
>
> * **An undisclosed visible effect.** `calc_custom_data_yrange()` computes a trace's y range, and
>   the first-point `0` now participates in it. An expression trace whose first *visible* sample
>   has a zero divisor will have its autoscaled range extended down to 0 as a one-point artefact.
>   That is a better failure than an autoscale driven by a heap bookkeeping word, which is what it
>   replaced, but it is a change a user could see and nothing said so until now.
> * **A coverage gap, named as one.** Band `DZ2` reaches `first > 0` through
>   `graph_marker_sample()`, which is a *dataset-offset* site. **No row exercises the visible-run
>   family**, so the zoom flavour is fixed but unfenced. It is the same one-line expression, so this
>   is a confidence gap and not a correctness one — but it should not be read as covered. Fencing it
>   needs a graph with a zoomed x range and an expression trace, which is a GUI fixture this stage
>   did not build.
| `graph_marker_sample()` ← `xschem graph_marker add_at` / `anchor` / drag-commit (`src/draw.c:8642`) | same `ofs` | **yes**, same reason; this is the door `DZ2` drives. |
| mid-window `x/0`, every caller | `p > first` | **no** — bit-identical. `DZ3a`/`DZ3b` pin it. |
| `0/0`, ordinary division, every other operator | — | **no** — the arm is not reached. `DZ4` pins it. |

### Suites run, with their `RESULT` lines

Batch 1 (`--nogui`, the engine arm) — `RESULT: 6/6 runs passed`:

```
PASS     | test_divis_zero_1628         RESULT: ALL PASS (33 checks)
PASS     | test_del_negative_arg        RESULT: ALL PASS (24 checks)
PASS     | test_calc_engine             RESULT: ALL PASS (120 checks)
PASS     | test_calc_scratch_reuse      RESULT: ALL PASS (46 checks)
PASS     | test_ev_precision_bound_1606 RESULT: ALL PASS (73 checks)
PASS     | test_raw_case_mode           RESULT: ALL PASS (277 checks)
```

Batch 2 (`--nogui`, the raw/graph readers) — `RESULT: 6/6 runs passed`:

```
PASS     | test_raw_ascii_point_bounds  RESULT: ALL PASS (90 checks)
PASS     | test_node_token_split        RESULT: ALL PASS (174 checks)
PASS     | test_wave_hilight            RESULT: ALL PASS (139 checks)
PASS     | test_wave_trace_menu         RESULT: ALL PASS (71 checks)
PASS     | test_wave_axis_zoom          RESULT: ALL PASS (200 checks)
PASS     | test_wave_cursor_crossdb     RESULT: ALL PASS (93 checks)
```

Batch 3 (`--nogui`, the `node=` expression consumers) — `RESULT: 6/6 runs passed`:

```
PASS     | test_op_annot                RESULT: ALL PASS (486 checks)   [5 skip: lines, all pre-existing display-only rows]
PASS     | test_results_select          RESULT: ALL PASS (375 checks)
PASS     | test_backannotate_digital    RESULT: ALL PASS (84 checks)
PASS     | test_spice_get_node_0861     RESULT: ALL PASS (23 checks)
PASS     | test_registered_banner_1626  RESULT: ALL PASS (10 checks)
PASS     | test_scratch_home_note       RESULT: ALL PASS (22 checks)
```

Batch 4 (`--nogui`, the tree/harness readers my new files change) — `RESULT: 4/4 runs passed`:

```
PASS     | test_issue_stamp             RESULT: ALL PASS (102 checks)
PASS     | test_regression_concurrency_1476 RESULT: ALL PASS (46 checks)
PASS     | test_selflog_grep_guard      RESULT: ALL PASS (390 checks)
PASS     | test_audit_classifier        RESULT: ALL PASS (75 checks)
```

Batch 5 (display arm, `:99`) — `RESULT: 4/4 runs passed`:

```
PASS     | test_calc_skeleton           RESULT: ALL PASS (548 checks)
PASS     | test_calc_widgets            RESULT: ALL PASS (246 checks)
PASS     | test_calc_buffer             RESULT: ALL PASS (130 checks)
PASS     | test_divis_zero_1628         RESULT: ALL PASS (33 checks)
```

`tclsh tests/headless/issue_stamp.tcl` → `ISSUE-STAMP: ok (0 problems)` (180 parser
self-tests, full-clone revision resolution).

### How the caller set was narrowed, so "I ran some suites" is checkable

A census of every `tests/headless/test_*.tcl` for an RPN expression containing the `/`
operator finds **four** files, all of them Calculator suites (`test_calc_buffer`,
`test_calc_engine`, `test_calc_scratch_reuse`, `test_calc_skeleton`) — all four run above.
No other suite in the tree divides inside an expression, which is *why* the batch-2 and
batch-3 suites can only be affected through the **graph door**, and that is the arm they
exercise. That census is in the receipt rather than in a row; a row asserting it would have
to be re-derived every run, and the number will move the moment anyone writes a dividing
suite.

---

## 6. `test_wave_markers` TIMEOUT — measured as pre-existing, not cited as pre-existing

`tests/headless/run_suites.sh test_wave_markers` on the display arm reports
`TIMEOUT | test_wave_markers run 1/1 (after 200s)`. CLAUDE.md says this is issue **1488** and
not your change — but `graph_marker_sample()` is the exact function `DZ2` drives, so citing
the note was not good enough.

**Measured both ways in this tree, same arm, same dev display, same throwaway HOME:**

```
fixed binary    (p > first ? y[p - 1] : 0.0)   TIMEOUT | test_wave_markers run 1/1 (after 200s)
pristine binary (git show HEAD:src/save.c)     TIMEOUT | test_wave_markers run 1/1 (after 200s)
```

Identical on both, so the TIMEOUT is **not** this change. It is issue 1488's known
interaction between that suite and an attached dev display, now confirmed by measurement in
this clone rather than by quoting a note. **It is also therefore NOT verified by me**: no run
of `test_wave_markers` completed on either binary, so the one suite most specific to
`graph_marker_sample()` contributes no evidence either way, and I did not take `:99` down to
get a private Xvfb (the dev display is on the do-not-touch list, and CLAUDE.md says no knob
goes private while `:99` is up). The marker door is instead covered by `DZ2`'s four rows,
which drive `graph_marker_create_at` → `graph_marker_sample` directly, headless, with asserted
values — a narrower instrument on the same function.

---

## 7. ⚠ WARN: NO TEST HARNESS BUILDS — what I rebuilt, and when

Every measurement in this receipt was taken on a binary rebuilt immediately before it.
`make -C src` recompiled **`save.o` only** and relinked, each time — not the whole tree, so
no header moved.

* **Before the red**: `make -C src` → `Nothing to be done for 'all'` on arrival (the committed
  `save.c` and the binary already agreed), then the red was taken.
* **Before the green**: `make -C src` after editing `src/save.c` → `gcc -c … save.c` + link.
* **Before each of the six sabotages**: rebuilt, measured, next.
* **After the sabotages**: the fixed `save.c` restored from the stage's own copy and rebuilt;
  `/usr/bin/grep -n 'p > first ? y\[p - 1\] : 0.0' src/save.c` confirms the one site.
* **For §6**: `git show HEAD:src/save.c` built, measured, then the fixed file restored and
  rebuilt again — and the suite re-run to confirm the tree I am leaving behind is the green
  one.

The pre-existing `-Wdiscarded-qualifiers` warning in `align_sch_pins_with_sym()` is on the
`.c` file but in an unrelated function and predates this stage.

---

## 8. The T1 trailer delta — derived, not predicted

**Not guessed and not remembered.** `summarize_all`'s own four regexp arms were lifted
verbatim out of `tests/run_regression.tcl` and run over the suite's **real captured green
output**, with `banner_complete` sourced from `tests/banner_rule.tcl`:

```
counted_failures contributed = 0
skips contributed            = 0
published RESULT line        = RESULT: ALL PASS (33 checks)
banner fallback (unused)     = OVERALL: ok (33 checks)
```

So the case's verdict block is exactly three lines (`headless/test_divis_zero_1628`, the
published `RESULT:`, `Total num fail: 0`):

| term | delta |
|---|---|
| `cases=` | **+1** |
| `blocks=` | **+1** |
| `counted_failures=` | **+0** |
| `skips=` | **+0** — the suite emits **no** `^skip:` line on either arm; its one conditional leg (valgrind) prints `note: valgrind is not installed here…`, which no arm of `summarize_all` matches |
| `wc -l` | **+3** |

List counts by CLAUDE.md's own method (find `set <n> [list`, pipe through
`/usr/bin/grep -o '"[^"]*"' | wc -l`): `tcases` **3**, `hcases` **93**, `dcases` **23**, plus
`xschemtest` → **120 cases, 119 blocks**. Stage C's receipt measured 92/23/3 → 119/118 before
this stage, so the delta above is a difference of two measurements rather than of a
remembered figure.

⚠ **I am stating a delta, not a trailer.** CLAUDE.md records three occasions where someone
reasoned carefully about registration shape and got `skips=` wrong — most recently 1625, where
an adversarial verifier and the driver both predicted a move and both were wrong. The driver
should read the gate's own `T1-RUN-END`, and `tests/results.<pid>.log`, not `results.log`.
**I did not run a full T1** — that is the driver's job.

`banner_complete` was checked **before** registering, as the brief requires, against the
suite's real body rather than against `run_suites.sh`:

```
banner_complete(green run)   = 1
banner_died(green run)       = 0
regression_case_failed(0, green) = 0
banner_complete(red run)     = 0
regression_case_failed(1, red)   = 1
RESULT lines in green run: 1
OVERALL lines in green run: {OVERALL: ok (33 checks)}
```

Exactly one `RESULT:` line, last, with the sentinel added **additively** above it — issue
**1627**'s hazard (a second trailing `RESULT:` silently rewriting the published count) does not
apply, and the file has one exit path by construction.

---

## 9. What I got wrong during the stage

Four things, and the second is the one worth carrying forward.

1. **My first two defect rows were green on the broken tree, and for a reason the issue now
   records.** `DZ1c` used `v(sq) 0 /` and `DZ1d` used `v(ramp) 0 /` — both obvious picks from
   the fixture — and both passed on the unfixed binary. Both columns are **exactly 0 at
   sample 0**, so point 0 takes the `0/0` arm two lines up and never reaches the defect at
   all. The red run is what caught it; had I written the rows after the fix I would have
   shipped two rows that fence nothing. Corrected to `v(dcmid)` (3 V at every sample), and
   `DZ1f` keeps `v(sq)` as an explicit control so a later reader cannot conclude that any
   zero-divisor expression exercises the arm.
2. ⚠ **`DZ6` reddened on the FIXED tree, because the fix's own comment contains `y[p - 1]`.**
   The structural row scanned raw file text and found the site it was asserting about inside
   the prose explaining the site. That is CLAUDE.md's *"a comment must not quote a count a
   command produces over the tree's own text"* arriving from the other direction — not a
   wrong number in a comment, but a right comment defeating a row. Fixed by stripping comments
   and string literals, with three control rows so the stripper cannot pass by blanking
   everything. **The general lesson: a structural row over C source must decide, explicitly,
   whether it is scanning code or text, and prove which.**
3. **I reached for a `-d 1` log read for `DZ2`'s behaviour before checking whether the door
   was Tcl-readable.** Issue 0325's `DN12` needs a DISPLAY and reads debug lines, and I
   assumed the same constraint. `graph_marker_sample()` returns the sample through
   `xschem graph_marker list`, headless — which turned a display-arm, log-scraping band into
   four ordinary value rows. The `-d 1` leg survives only as the premise row that the caller
   really does pass a `first > 0`.
4. **I nearly reported `test_wave_markers`'s TIMEOUT on CLAUDE.md's authority.** It is the
   suite around the exact function `DZ2` drives; a note in a file is not a measurement of
   this tree. §6/§7 record what the before/after run found.

---

## 10. What I did NOT do

* **No full T1.** Driver's job, and two concurrent runs plus hand-run suites can redden a gate.
* **Nothing committed, pushed or stashed.** The work is uncommitted in the tree.
* **`ravg()` with a negative window was not fixed** — issue 0325's recorded sibling, still
  live, still a crash rather than a cosmetic. Out of scope (`DIVIS` only), recorded as 1628's
  one open item and in `NUMBERING.md`.
* **`test_del_negative_arg` was not registered**, although it is the twin fence for the same
  function and is in neither `hcases` nor `dcases`. Its `DN11`/`DN12` bands are conditional on
  valgrind **and** a DISPLAY, so registering it is its own judgement with its own gate, not a
  free addition to this change. Noted in `run_regression.tcl` beside my entry.
* **`doc/claude/specs/calculator.md` was not edited.** The issue file records the sentence §3
  and landmine L2 should gain (there is now a stated contract for `x/0`), but the spec is the
  batch's own document and editing it is not this stage's call.
* **The committed fixture was not regenerated**, read only. `tests/headless/data/` is
  untouched (`git status`).
* **No `look` or `rule` debt was filed.** Nothing here is a pixel deliverable and nothing is
  an unratified user-visible decision: the user already ruled on where the fix goes, and the
  value `0` is the function's existing convention rather than a new sentence. If the driver
  disagrees that `0` is invisible enough to skip a ruling, it is one `owed.sh add rule` away.

---

## 11. For the next stage

* **The engine's `x/0` contract is now stated**: hold the previous output of *this* pass; at
  the first point of the window, 0. Anything in the Calculator that reports a quotient can
  rely on it, and `calc::eval_rpn` needs no guard of its own.
* ⚠ **`raw_add_vector()` still discards the evaluator's return value**, so §3.1's `-1` remains
  unreachable from Tcl — stage C's finding, unchanged by this stage. A rejected expression and
  a legitimately-all-zero one are still indistinguishable by return value, and a `1 0 /`
  expression now *legitimately* produces an all-zero column, which makes that conflation one
  case commoner than it was. **R607 still cannot be built on the engine's `-1`.**
* **`xschem graph_marker add_at` + `graph_marker list` is a headless, numeric door into the
  evaluator with a caller-chosen window.** It is the only one in the tree that passes a
  `first > 0` without a display, and it is how any future `first`-sensitive engine defect
  should be fenced. Worth knowing before anyone writes another DISPLAY-gated band for one.
* **This brief's statement that the Calculator's answer is `dcases`** is right for the
  Calculator and wrong as a general rule for this batch: an engine defect the Calculator
  merely *reveals* belongs in `hcases`, where it gates the arm the Tk suites cannot run on.
