# Item 12 — `del()` with a negative argument: the out-of-bounds read

Verdict **[x]**. No pixel payload. Base `6ce8bf3d`. Recon finding **D2 CONFIRMED** under valgrind, filed as issue
**0325**, fixed, tested, spec corrected. Long evidence log: `12-del-negative-arg.md`, same directory.

## 1. Files changed

```
 doc/claude/specs/calculator.md | 47 +++++++++++++++++++++++++++------
 src/draw.c                     | 10 +++++--
 src/save.c                     | 59 +++++++++++++++++++++++++++++++++++++++---
 3 files changed, 102 insertions(+), 14 deletions(-)
```

New: `doc/claude/issues/0325-del-with-a-negative-delay-reads-past-the-end-of-the-window.md` (194) ·
`tests/headless/test_del_negative_arg.tcl` (312) · `del_negative_arg_child.tcl` (101, DN11/DN12 helper, **not**
named `test_*.tcl` — `full_audit.sh` would score it) · `12-del-negative-arg.md` (265) · this file.

## 2. Decisions, and the evidence for each

**D2 is real, and worse than the finding said.** In the `DEL` arm (`src/save.c:2586`) `delta` is a `fabs()`, so a
negative `tmp` makes `delta > tmp` true at every point: the forward walk reached `prevp == last + 1` and read
**both** `x[last+1]` and `ravg_store()`'s `arr[i][last+1]` (`my_calloc(_ALLOC_ID_, last + 1, …)`,
`src/save.c:2297`) — from an **uninitialised** `stack1[i].prevp`, since the only arm that seeds it is one a
negative `tmp` can never take. Evidence: pre-fix valgrind, `Invalid read of size 8 … 0 bytes after a block of size
64` from both allocation sites plus uninitialised-value contexts, and on the `node=` door a deterministic
**SIGSEGV, 15 of 15 runs**. Reads only — the finding's "writes" is wrong, corrected in the issue. Reachable
without the Calculator, once per redraw.

**RULING — a negative (or NaN) delay is REJECTED, not clamped, not redefined.** The search only walks forward, so
there is no left shift to be had; `plot_raw_custom_data()` returns `-1` for the whole expression exactly as §3.1
rejects an unresolvable vector name. Into `specs/calculator.md` §3.2 (new paragraph, plus "**≥ 0 only**" in the
Sequence row) and §7.2/§7.2a. `lshift` keeps the **T** route item 4 gave it, and §7.2 records *why* the old
"C (`del()` with negative arg)" recipe is worse than wrong: post-fix it is a rejected expression, so an `lshift`
built on it plots a flat zero trace.

**RULING — "the column is not touched" is safe only if the column is defined.** Review found
`raw add <NEW name> <rejected expr>` handing back a registered, plottable, Tcl-readable vector made of
uninitialised heap: `raw_add_vector()` creates the column before the evaluator runs and only zeroed it when there
was no expression — and `wviewer::add_trace` takes that door with an auto-generated name. Fixed: zeroed **before**
evaluation (`src/save.c:1206`), in §3.2, pinned by DN13.

**RULING — the `idx == -1` load in `draw_graph_points()` moves under its own guard.** The first cut relocated the
overrun instead of removing it, on the very path the issue documents: `gv = raw->values[idx];` sat one line
*above* `if(idx == -1) return;`, so every rejected expression loaded `values[-1]` on each redraw. Fixed at
`src/draw.c:4283-4292`, pinned by DN11's `node=` leg. Pre-existing (an unknown name reaches it too), but this item
routes negative `del()` into it. The `dbg()` call there is the `-O2` barrier that makes the old order a real read.

**A positive `del()` does not move.** `prevp < last` is unreachable for `tmp >= 0` (`prevp <= p <= last`,
`delta == 0` at `prevp == p`). Measured: a reviewer diffed 68 cases (4 raw shapes × 17 expressions, incl. a
non-uniform sweep, a two-dataset raw, a decreasing DC sweep) byte-identical across the pre- and post-fix binaries;
DN2/DN12 and the DEL-nearest-sample sabotage pin it from the suite side. **Out of scope, deliberately:** the
identical runaway in the neighbouring `RAVG` arm, recorded in 0325 under "Not fixed here" and now flagged as a
probable **crash** — the "reads only" reasoning that deferred it is what this round disproved for the `del()` twin.

## 3. Test and result

`tests/headless/test_del_negative_arg.tcl` — **24 checks**, bands DN1–DN13, `test_scratch`, no droppings.
Verbatim: `RESULT: ALL PASS (24 checks)`. The count is environment-dependent **by design**: 24 with valgrind and a
`DISPLAY` (this machine, and every `run_suites.sh` run), 21 with no `DISPLAY`, 19 with neither. A missing leg prints
a plain `note:` line, never a self-skip banner (that substring makes `full_audit.sh` score the file SKIP).

## 4. Sabotage table — one row per check

| check | what was broken | red? | restored green? |
|---|---|---|---|
| DN1 fixture loads | `scheduler.c:10108` raw_read result → `my_itoa(0)` | yes | yes |
| DN1 fixture points/vars | `scheduler.c:10000` `raw->allpoints` → `- 1` | yes | yes |
| DN2 positive del() created a vector | `save.c:1204` new-vector arm `res = 1` → `0` | yes | yes |
| DN2 positive del() values unchanged | DEL nearest-sample `if(stack1[i].prevp > 0)` → `if(0)` | yes | yes |
| DN3 negative del() does not throw | two-file: `raw_add_vector()` propagates `-1`, `scheduler.c:9994` returns `TCL_ERROR` | yes | yes |
| DN3 negative del() left the column untouched | `save.c:2602` rejection guard → `if(0)` (**S6**) | yes | yes |
| DN4 -1p del() left the column untouched | S6 | yes | yes |
| DN4 -1 s del() left the column untouched | S6 | yes | yes |
| DN5 vector-valued negative delay untouched | S6 | yes | yes |
| DN6 zero delay is legal and is the identity | guard widened to reject zero: `!(tmp >= 0)` → `!(tmp > 0)` | yes | yes |
| DN6 mid-wave negative: prefix kept, tail untouched | guard restricted to `p == first` | yes | yes |
| DN7 vector-valued positive delay still evaluates | guard also rejects a delay that came from a vector | yes | yes |
| **DN8 a positive del() after a rejected one is still correct** | **UNSABOTAGED — not evidence.** The sabotage aimed at it (delete the guard's `ravg_store(0,…)` scratch release) left all 18 first-cut checks green; it compares against `$positive` captured at runtime, so it restates DN2. That property is now pinned by **DN11**, which does go red on it (Invalid write + 2 Invalid reads, 92 errors / 4 contexts). | n/a | n/a |
| DN8 an unrelated expression after a rejected one | `save.c:2573` `case MULT:` `*` → `+` | yes | yes |
| DN9 composed expression rejected whole | S6 | yes | yes |
| DN10 prev() is unchanged | `save.c:2823` `case PREV:` result ← `stack2[stackptr2-1]` | yes | yes |
| DN10 ravg() over a positive window unchanged | `save.c:2654` `case RAVG:` divisor doubled | yes | yes |
| DN10 idx() is unchanged | `save.c:2526` `IDX` pushes `p + 1` | yes | yes |
| DN13 rejected expr into a NEW vector zeroed | **S1** — zeroing loop put back inside the `else if(res == 1)` arm | yes | yes |
| DN13 unresolvable name into a NEW vector zeroed | S1 | yes | yes |
| DN11 valgrind: the `raw add` door is memory-clean | S3 — the guard's `ravg_store(0,…)` deleted; also red under S1 and under **S4**, the *entire* original runaway walk restored behind the guard with the visible contract intact — the sabotage that beat all 18 first-cut checks | yes | yes |
| DN11 valgrind: the graph `node=` door is memory-clean | S2 — `draw.c:4282` `gv = raw->values[idx];` moved back above the `idx == -1` guard | yes | yes |
| DN12 the graph door passes a `first > 0` | S8 (test-side) — `DN_X1 3.5e-09` → `0`; restored from a byte-exact backup | yes | yes |
| DN12 del() widens the window to the dataset start | S5 — `first = p;` deleted from the `del()` token handler (the driver's named landmine) | yes | yes |

`DN1/DN7/DN8/DN10` also served as **controls**, green through S1/S4/S6/S7 — the evidence that neither the
`raw_add_vector` zeroing nor the `draw.c` move touched positive `del()`, `prev()`, `ravg()`, `idx()` or the
unrelated-expression path. DN13's redness under S1 is heap-dependent (the recycled scratch differed from zero in
element 0 only); DN11 is the deterministic pin there.

## 5. What was NOT verified

- **The `prevp < last` bound and the `p == first` prevp seed are pinned by no check** — both were sabotaged, both
  left 24/24 green. Provably dead code once the rejection guard is in place, so defence-in-depth, not measured: no
  compiled assert, and no **multi-dataset or wrapping DC sweep** (caller window off a dataset boundary while the
  DEL arm rewrites `first`) was ever run. Nor was a positive `del()` driven with a caller-supplied `first > 0`, the
  case the driver's landmine names — DN12 widens with a *negative* delay, the fuzz and DN2/DN7 run at `first == 0`.
- **No out-of-bounds *write* was ever proven** pre-fix in any fixture — consistent with the correction to the
  recon finding, but absence in three fixtures is not proof.
- **The pre-fix crash is fixture- and door-dependent**, as UB is: `node=` SIGSEGVs 15/15, the `raw add` door 0/15
  bare but reliably under valgrind — do not read "0/15" as "that door is safe". Counts differ per fixture (382/10,
  142/8, 129/11 all measured); the shape is the evidence, not the number. A reviewer also saw `FATAL: signal 11`
  from what their notes call the *fixed* binary in four early runs, unreproducible in 35 more and most likely their
  own binary bookkeeping (one run from outside `src/` cannot find `XSCHEM_SHAREDIR`) — recorded, unresolved.
- **Not driven end to end:** whether the (now zeroed) new-vector column is *plotted* through the Add Trace
  dialog, vs merely readable via `xschem raw value`. Traced in source only.
- **The `ravg()` twin is still live** — `node="v(a) -2e-09 ravg()"` on the fixed binary still gives 6 valgrind
  errors / 4 contexts. Out of scope by instruction; recorded in 0325. **Eyeball owed: none** — no pixel changed.
- **`test_ase_core` red vs the baseline is NOT this change** — verified here, not assumed, on a binary built from
  `6ce8bf3d` with **both** `src/save.c` and `src/draw.c` reverted (byte-exact restore afterwards, md5-checked):
  identical `RESULT: 1 FAILED (57 passed)`, `UNEXPECTED ERROR: ase: design aselib/nfet_clean is not the current
  schematic`. Pre-existing drift from outside this item; unexplained, someone should chase it.
- **One live suite debt** covers this work: `owed.sh` `[test_wave_viewer]`, a `:0` run, since the change sits in
  the evaluator behind every graph redraw and this batch may only use `:99`. No new debt recorded.
