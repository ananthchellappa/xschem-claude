# Item 12 — `del()` with a negative argument: confirmed, filed, fixed

Verdict **[x]**. No pixels. Base `6ce8bf3d`; tree left dirty for the verifier, nothing staged.

> **Review round, 2026-08-15.** Three lenses attacked the first cut and found two real defects in
> it plus four record/coverage faults. All are now fixed; §8 below is the round's own receipt and
> supersedes any number above it that it contradicts. Headline changes: the fix is now **two**
> files (`src/save.c` **and** `src/draw.c`), the suite is **24 checks** (was 18), and the pre-fix
> defect is a **reproducible SIGSEGV** on the `node=` door, not a wrong-numbers bug.

## 1. The claim (recon D2) — CONFIRMED, and worse than claimed

Reproducer, not reading: an 8-point ASCII transient raw synthesized in Tcl (the `mkraw` shape from
`test_ase_cosim.tcl:758`), loaded with `xschem raw_read`, then `xschem raw add k {v(a) -2.6e-09
del()}` → `raw_add_vector()` (`src/save.c:1207`) → `plot_raw_custom_data()` (`:2381`).

`valgrind` on the pre-fix binary, running the new test file:

```
Invalid read of size 8  at plot_raw_custom_data      (0x1E3E07)
  Address … is 0 bytes after a block of size 64 alloc'd by my_realloc <- read_raw_data_block
Invalid read of size 8  at plot_raw_custom_data      (0x1E3E6E)
  Address … is 0 bytes after a block of size 64 alloc'd by my_calloc   <- ravg_store()'s arr[i]
ERROR SUMMARY: 382 errors from 10 contexts
```

- **Both** one-past-the-end reads the finding predicted fire: `x[last + 1]` (the sweep column) and
  `arr[i][last + 1]` (`my_calloc(_ALLOC_ID_, last + 1, sizeof(double))`, `src/save.c:2297`);
  8 points ⇒ 64-byte blocks, address exactly 0 bytes after each. **Nothing is written** out of
  bounds — `ravg_store(1, …)` only ever stores at `p`; the finding said "writes", it reads.
- **Worse than claimed**: `Stack1 stack1[STACKMAX]` (`src/save.c:2386`) is an uninitialised local
  and the *only* seed of `stack1[i].prevp` is the `fabs(x[p] - x[first]) <= tmp` arm — which a
  negative `tmp` never takes, **including at `p == first`** (`0 <= negative` is false). So the
  first search of the wave starts from stack garbage: 4 `Use of uninitialised value of size 8` +
  3 `Conditional jump … depends on uninitialised value(s)` contexts, `--track-origins=yes` →
  *"created by a stack allocation at … plot_raw_custom_data"*.
- Reachable with no Calculator: `node=` on a graph, through `src/draw.c:5432, 5449, 5653, 6704,
  7142, 8298, 9171, 9221`, **once per redraw per dataset**.

Filed: `doc/claude/issues/0325-del-with-a-negative-delay-reads-past-the-end-of-the-window.md`.

## 2. The fix — `case DEL` only, `src/save.c:2586`
*(the review round added two more sites — `raw_add_vector()` and `draw_graph_points()` — see §8.1)*

1. **Reject a negative (or NaN) delay** (`if(!(tmp >= 0.0))`): `dbg(1, …)`, `ravg_store(0, …)` to
   release the static scratch, `return -1` — §3.1's contract for an unresolvable token. With a
   constant argument the rejection lands at `p == first`, *before* the first `y[p] = …` at the
   bottom of the point loop, so the destination column is not touched.
2. **`prevp < last`, not `<= last`** in the search, so neither `x[]` nor `arr[i][]` can be indexed
   past its end if the negative path is ever reopened.
3. **Seed `stack1[i].prevp = first` at `p == first`**, so no search starts from garbage.

Why (1)+(2) cannot move a **positive** `del()`: `prevp <= p <= last` always and `delta` is 0 at
`prevp == p`, so `delta > tmp` ends the walk before the bound is reached (the `<= last` bound is
dead code for `tmp >= 0`), and `p == first` always takes the seeding arm. Measured, not argued:
the controls below stay green with the fix reverted.

`valgrind` after the fix, whole test file: **`ERROR SUMMARY: 0 errors from 0 contexts`** — but
read that as *the `xschem raw add` door only*. The `node=` door still had one, in `src/draw.c`;
it is fixed and separately measured in §8.1(b)/§8.2, and `DN11`'s graph-door leg is what keeps it
honest from now on.

## 3. Test — `tests/headless/test_del_negative_arg.tcl`, 18 checks, new file
*(24 after the review round — see §8.3)*

Band `DN1`–`DN10`, chosen by grepping the (new) file itself; true headless, `test_scratch delneg`,
no droppings. The fixture delays are **2.6 ns**, not 2 ns: measured, the ascii raw reader keeps the
sweep column at full double precision but rounds the other columns to ~7 digits (`2e-09` reads back
as `1.9999999e-09`), so a delay sitting exactly on the sample spacing makes the `<=` test decide on
rounding noise and the literal and vector-valued forms of the *same* delay disagree.

## 4. Sabotage — `src/save.c` reverted from a byte-exact backup, rebuilt, re-run

| | sabotaged (pre-fix code) | fixed |
|---|---|---|
| `DN3 negative del() left the column untouched` | **FAIL** `{0 0 0 0 0 0 0 7}` | ok |
| `DN4 -1p del() left the column untouched` | **FAIL** | ok |
| `DN4 -1 s del() left the column untouched` | **FAIL** | ok |
| `DN5 vector-valued negative delay left the column untouched` | **FAIL** | ok |
| `DN6 mid-wave negative: prefix evaluated, tail untouched` | **FAIL** `{0 1 2 0 0 0 0 7}` | ok |
| `DN9 composed expression with a negative del() is rejected whole` | **FAIL** `{… 700}` | ok |
| `DN2` positive del() values (control) | ok | ok |
| `DN7` vector-valued positive delay (control) | ok | ok |
| `DN8` positive del() / unrelated expr after a rejection (control) | ok | ok |
| `DN10` `prev()` / `ravg()` / `idx()` (controls) | ok | ok |

`RESULT: 6 FAILED (12 passed)` sabotaged → `RESULT: ALL PASS (18 checks)` restored (md5 of the
restored `src/save.c` equals the backup). The controls staying green **through** the sabotage is
the evidence that positive `del()` and the neighbouring opcodes did not move.

## 5. Suites — diff by name against `receipts/00b-audit-baseline-2026-08-14.txt`

| suite | baseline | now |
|---|---|---|
| `test_del_negative_arg` | *absent* (new file) | PASS, 18 checks |
| `test_calc_skeleton` | PASS | PASS, 438 |
| `test_wave_viewer` | PASS | PASS, 400 |
| `test_wave_trace_menu` | PASS | PASS, 397 |
| `test_ase_plot` | PASS | PASS, 150 |
| `test_wave_drag_preview` | PASS | PASS, 94 |
| `test_wave_modes` | PASS | PASS, 488 |
| `test_raw_read_dispatch` | PASS | PASS, 51 |
| `test_wave_markers` | **FAIL** | FAIL, 6 failed / 977 (MX7b/MX7d pixel probes) |
| `test_ase_core` | PASS | **FAIL**, 1 failed / 57 passed — **not this change** |

Both reds were re-run against the **pre-fix binary** rather than assumed:

- `test_wave_markers` is red at baseline, and the file contains no `del()` token at all
  (`grep -n 'del()' test_wave_markers.tcl` → nothing), so the `DEL` arm is never entered.
- `test_ase_core` fails **identically** with `src/save.c` reverted and rebuilt: `UNEXPECTED ERROR:
  ase: design aselib/nfet_clean is not the current schematic` → `RESULT: 1 FAILED (57 passed)`.
  Pre-existing drift since the baseline, from outside this item; recorded, not swept up.

All runs through `run_suites.sh` on the dev display `:99` (`ATTACHED …, GUI_GATE=0`); never `:0`.

**`owed.sh` debt: one SUITE debt, recorded** — `owed.sh add suite test_wave_viewer "issue 0325
changed plot_raw_custom_data(), the evaluator behind every graph redraw; batch item 12 could only
run it on :99"`. (An earlier revision of this line read "No `owed.sh` debt: no GUI surface, no
pixels", which was simply wrong: the debt was recorded at the time and is live in the ledger. No
LOOK debt — there is no pixel payload.)

## 6. Spec corrections (item 12 duty 5)

- **§3.2** — the Sequence row now reads `del()` … **≥ 0 only**, and a new paragraph after the
  window-widening note records the confirmed behaviour, the rejection contract, issue 0325 and
  the test file.
- **§7.2** — the `lshift` row keeps the `T` route item 4 gave it and now says *why* the old
  recipe is worse than wrong: it is a **rejected** expression, so a `lshift` built on it would
  plot nothing.
- **§7.2a** — the first bullet is rewritten from prediction to measurement: both overruns, the
  uninitialised `prevp`, "read, not write", the fix, and the pin on positive `del()`.

## 7. Files

`src/save.c` (the `DEL` arm, `raw_add_vector()`, one `dbg()` line), `src/draw.c`
(`draw_graph_points()`), `doc/claude/specs/calculator.md`, `doc/claude/issues/0325-…md` (new),
`tests/headless/test_del_negative_arg.tcl` (new) and `tests/headless/del_negative_arg_child.tcl`
(new helper, deliberately not `test_*`). Rebuilt with `cd src && make`; `Makefile.in` untouched,
so no `./configure`.

## 8. Review round — what the three lenses found, and what was done

Six findings, all confirmed by at least one reproducer. Two were code defects **created or left
open by the first cut**; four were faults in the record or in the evidence.

### 8.1 Two code defects, both fixed

**(a) `raw_add_vector()` handed back an UNINITIALISED column** (`src/save.c:1206`). Raised
independently by all three lenses. A rejected expression returns `-1` without writing a single
`y[p]` — but on the `raw add <NEW name>` door the vector has already been created, and the column
it gets is the previous scratch column, which nothing zeroes. So the first cut turned "defined but
wrong numbers" into "uninitialised heap, registered and plottable", on exactly the door
`wviewer::add_trace` takes (`src/wave_viewer.tcl:3785`, an auto-generated new name;
`wviewer::validate_rpn` accepts both `-2.6e-09` and `del()`).

Fix: the existing zeroing loop moved out of the `else if(res == 1)` arm so it runs for **any**
newly created column, before the expression is evaluated into it. Three lines net, in the file the
item already owned. Measured, fixed binary:
`xschem raw add brandnew {v(a) -2.6e-09 del()}` → `0 0 0 0 0 0 0 0`, valgrind clean; with the
change reverted → `4.87689e-310 0 …` and `ERROR SUMMARY: 42` (the child's exit code).

**(b) `draw_graph_points()` loaded `raw->values[-1]`** (`src/draw.c:4282`). The first cut recorded
this as "a pointer load only, never dereferenced" and left it; valgrind calls it
`Invalid read of size 8`, and the `del()` rejection is what newly routes a negative-`del()` graph
into it. Fix: the load moved below `if(idx == -1) return;`.

*Compiler nuance, measured and now recorded in the issue*: at `-O2` the defect exists only because
the original load sits **above the `dbg()` call**, which is an optimisation barrier. A first
sabotage attempt that moved the load below the call but above the branch let GCC sink the
dereference past the branch by itself (`lea` before the `je`, `mov (%rax)` after — checked in
`objdump`), and valgrind reported nothing. The sabotage in the table below restores the original
*order*.

### 8.2 The severity in the record was wrong — the pre-fix bug SIGSEGVs

The first cut declared "No crash was ever reproduced on this machine … not a segfault". Re-measured
here on a binary with **both** files reverted to `6ce8bf3d` (`git show HEAD:src/…`, rebuilt, tree
restored byte-exact afterwards, `md5 45056cdf…`/`befda13f…`), with an 8-point transient raw and a
graph rect carrying `node="v(a) -2.6e-09 del()"`, redrawn twice:

| | pre-fix binary | fixed binary |
|---|---|---|
| graph `node=` door, 15 runs | **`FATAL: signal 11` 15/15** | 0 crashes in 8 |
| `xschem raw add` door, 15 runs | 0 crashes | 0 crashes |
| `xschem raw add` door under valgrind | `ERROR SUMMARY: 129 errors / 11 contexts`, then `FATAL: signal 11` | 0 errors |
| graph `node=` door under valgrind | (crashes) | 0 errors |

The search index is uninitialised stack, so *where* it lands depends on the caller — which is
precisely why "no crash on this machine" was never a bound. Issue 0325's Symptom section is
rewritten to say so, and its "Not fixed here" note on the `ravg()` twin now says the twin must be
scheduled as a crash rather than deferred on a "reads only" reading. The twin is still live on the
fixed binary: `node="v(a) -2e-09 ravg()"` → `4 × Invalid read of size 8`, `ERROR SUMMARY: 6 errors
from 4 contexts`.

### 8.3 The suite pinned only half of its own assignment — 18 → 24 checks

The item's brief was "must not read out of bounds **and** must fail the documented way". LENS 3
showed only the second half was pinned: restoring the entire original runaway walk *behind* the
guard left all 18 checks green while valgrind went from 0 errors to 80. Two more holes: the
guard's `ravg_store(0, …)` scratch release (which `DN8`'s header claimed to protect) could be
deleted with everything green, and the driver's named landmine — del()'s backwards window widening
— was measured by nothing in the tree.

Added, all through a new helper `tests/headless/del_negative_arg_child.tcl` (a HELPER, **not**
`test_*.tcl`: `full_audit.sh` globs those):

| check | what it pins | how |
|---|---|---|
| `DN11 valgrind: the raw add door is memory-clean` | the OOB read itself, plus the scratch release and the zeroed new column | child mode `mem` under `valgrind -q --error-exitcode=42`, exit status asserted |
| `DN11 valgrind: the graph node= door is memory-clean` | the `values[-1]` load, on the door the issue calls the user path | child mode `node` under valgrind, needs a DISPLAY |
| `DN12 the graph door passes a first > 0` | the premise: an x-clipped graph really does ask for a partial window | child mode `node` with `x1 = 3.5 ns`, `-d 1` log parsed |
| `DN12 del() widens the window back to the dataset start` | the landmine: `first = p` in the `del()` token handler | the evaluator's new "evaluated window" `dbg(1)` line, asserted `== 0` |
| `DN13 a rejected expression into a NEW vector yields a zeroed column` | 8.1(a) | value comparison |
| `DN13 an unresolvable name into a NEW vector yields a zeroed column` | the same door for the pre-existing §3.1 rejection | value comparison |

`mem` covers the `ravg_store()` boundary deliberately: reject a `del()` **after** a `ravg()` on an
8-point raw, then `raw clear`, load a 64-point raw and run a plain `ravg()`. With the scratch
release deleted the old `arr[]` rows are written past their end — `Invalid write of size 8`, which
is worse than the read this issue was filed for, and was previously behind a check that claimed to
cover it.

A missing tool or DISPLAY simply does not run the leg (24 checks here, 21 with no DISPLAY, 19 with
neither), and **never** prints a self-skip banner — `full_audit.sh` would score the whole file
`SKIP` and discard every check that did run.

### 8.4 Sabotage — every new check, and every check whose subject moved

`src/save.c` md5 `45056cdfdc7bb7c20c6cc2f5562b61fa`, `src/draw.c` md5
`befda13f050aed1f631c417da54bb822`; each sabotage restored from those byte-exact backups, rebuilt,
re-run green before the next.

| # | broken | red | note |
|---|---|---|---|
| S1 | `save.c:1206` zeroing moved back inside `else if(res == 1)` | `DN13` ×2, `DN11 raw add` | 3 FAILED (21 passed) |
| S2 | `draw.c:4282` load restored **above** the `dbg()` call, guard after | `DN11 graph node=` | 1 FAILED (23 passed) — the only check that sees it |
| S3 | `save.c` guard's `ravg_store(0, …)` scratch release deleted | `DN11 raw add` | valgrind: `Invalid write of size 8` + 2 invalid reads, 92 errors / 4 contexts. **This is the hole LENS 2/3 found**: 18/18 green before |
| S4 | the ORIGINAL runaway walk restored *behind* the guard (volatile sink, per LENS 3) | `DN11` ×2 | 2 FAILED (22 passed). All 18 old checks stayed green under this — that is the hole DN11 closes |
| S5 | `first = p;` deleted from the `del()` token handler | `DN12 widens the window` | got `3`, exp `0`. Nothing in the tree saw this before |
| S6 | rejection guard `if(!(tmp >= 0.0))` → `if(0)` (re-run of the first cut's sabotage) | `DN3`, `DN4`×2, `DN5`, `DN6` mid-wave, `DN9`, **and now `DN13`** | 7 FAILED (17 passed) — the original 6 still move, so the fix disarmed nothing |
| S7 | `del()` nearest-sample choice `if(stack1[i].prevp > 0)` → `if(0)` | `DN2 values`, `DN6` mid-wave | 2 FAILED (22 passed) — positive `del()` numbers are still pinned after the `raw_add_vector` change |
| S8 (test-side) | `DN_X1` `3.5e-09` → `0` in the suite | `DN12 the graph door passes a first > 0` | the premise leg is measuring, not asserting a constant |

### 8.5 Suites, this round — diff by name against `receipts/00b-audit-baseline-2026-08-14.txt`

25 suites, all through `run_suites.sh` on `:99`. Every wave/graph/raw suite the verifier ran, plus
`test_node_token_split`, `test_graph_box_zoom_xy`, `test_graph_context`, `test_wave_legend`,
`test_wave_crossdb_trace`, `test_wave_cursor_crossdb`, `test_raw_ascii_point_bounds` — added
because this round touches `draw_graph_points()`, which every graph redraw goes through.

PASS → PASS: `test_calc_skeleton` 438, `test_wave_viewer` 400, `test_wave_trace_menu` 397,
`test_ase_plot` 150, `test_wave_modes` 488, `test_wave_drag_preview` 94, `test_raw_read_dispatch`
51, `test_node_token_split` 168, `test_graph_box_zoom_xy` 10, `test_graph_context` (OVERALL ok),
`test_wave_hilight` 196, `test_wave_axis_zoom` 370, `test_wave_clear_all` 75, `test_wave_grid` 399,
`test_wave_snap` 106, `test_wave_empty_strips` 98, `test_wave_split_strip` 221, `test_ase_persist`
109, `test_wave_legend` 77, `test_wave_crossdb_trace` 130, `test_wave_cursor_crossdb` 93,
`test_raw_ascii_point_bounds` 90.

- `test_del_negative_arg` — absent at baseline (new file) → PASS, **24 checks**.
- `test_wave_markers` — FAIL → FAIL, same 6 MX7b/MX7d pixel-probe legs, 977 passed. No status move.
- `test_ase_core` — PASS → FAIL (1 check, "ase: design aselib/nfet_clean is not the current
  schematic"). **Not this change, re-verified this round**: `XSCHEM=src/xschem.PREFIX
  run_suites.sh test_ase_core` on the binary built from `6ce8bf3d` gives the identical
  `RESULT: 1 FAILED (57 passed)`. Pre-existing drift from outside this item.

No status moved in either direction that is attributable to this item.
