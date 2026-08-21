# 0481 — the S11 rows that name the overlay-invalidation contract and the floater refresh do not discriminate

Status: **OPEN — a TEST defect, not a code defect. Measured by the S11 sabotage
pass; deliberately not repaired in the S11 commit.**
Filed by the S11 write-up agent (2026-08-20).
Related: 0466 (S9 attempt 1, reverted for exactly the failure these rows claim to
cover), invariant **I3**, spec §4.7 landmine 14, `tests/headless/test_op_annot.tcl`
section **T**.

## What happened

S11 shipped with 8 sabotage variants and 23 new rows. Three variants were
**not** caught, and one of them is the step's own central safety argument.

| variant | predicted red | observed | verdict |
|---|---|---|---|
| SAB-1 helper neutered (`return 0`) | T1 T2 T3 T4 T5 T6 T8 T9 T10 T16 T17 T18 | 14 red (all predicted + T21 T22) | caught, superset |
| SAB-2 memset-0 `Graph_ctx` (the rejected design) | T1 T2 T3 T4 T5 T6 T8 T10 T16 T18 | 12 red (all predicted + T21 T22) | caught, superset |
| **SAB-3 bypass the public entry** | **T9 T10 T22** | **0 red — suite stayed ALL PASS (241)** | **MISSED** |
| SAB-4 `has_graph` = `rects>0` | T21 | T21 | caught, exact |
| SAB-5 direct arm fires with a graph too | T13 T14 T15 | T13 T14 T15 | caught, exact |
| SAB-6 drop the `sch_waves_loaded()` gate | T19 T20 | T19 T20 | caught, exact |
| **SAB-7 delete RULING D4-4's clamp** | T16 T17 T18 + XCW4 XCW5 XCW6 | T13 T17 + XC16 XC31 XC33 XC74 XCW6 | **4 predicted reds MISSING** |
| **SAB-8 drop `set_modify(-2)` from the new arm** | **T22** | **0 red — suite stayed ALL PASS (241)** | **MISSED** |

## 1. SAB-3 — the I3 breach that reverted S9 attempt 1 is uncovered

The design argument S11 rests on (decision **D4**) is: the new arm must call the
**public** `backannotate_at_cursor_b_pos()`, because only that function bumps
`annot_data_changed()`; the static inner `backannotate_cursor_b_in_db()` does
not, and a **within-segment** cursor move changes no other field of the 14-field
`Annot_epoch`. Bypassing it therefore leaves the S9b overlay rendering the
previous timepoint's numbers while `xschem raw value <v> -1` reports the new
ones — exactly what got S9 attempt 1 reverted (issue 0466).

Measured by the sabotage agent, comparing the shipped build with the SAB-3
build, on a **within-segment** move 3.2 ns → 3.6 ns:

| | flush delta | `$cursor_2_hook` | rendered rows |
|---|---|---|---|
| shipped | 1 | fires | 36u, 360u (new timepoint) |
| SAB-3 | **0** | **never fires** | **32u, 320u (STALE)**, while `raw value -1` says 3.6 |

**Why rows T9/T10/T22 stay green:** every cursor move they make is
**cross-segment** (point 0 → 3 ns → 1 ns), so `raw_annot_p` changes and the
epoch flushes on that field regardless of `data_seq`. The rows measure a real
thing; they just cannot see the field they were written to protect. T22 is worse
still — see §3.

**The fix, and it is small:** add a row that moves the cursor **between two
samples of one segment** (e.g. 3.2 ns → 3.6 ns on the section's 1 ns-spaced
fixture), asserting both that `xschem get annot_overlay_flushes` moves by 1
across `(set cursor2_x; redraw)` **and** that the rendered block changes. That
single row reds SAB-3 and nothing else.

## 2. SAB-7 — the upper clamp has no behavioural coverage anywhere

Deleting **both** lines of RULING D4-4's `frac` clamp left T16, T18, XCW4 and
XCW5 green. Mechanism, measured: past the last sample `interpolate_yval()`
returns at the `(p + 1 < ofs_end)` guard **before** `frac` is computed, so the
"holds the last sample" behaviour that T16/XCW5 assert is that guard, not the
clamp; XCW4 is a VCD sparse-stream early return, likewise clamp-independent;
XC74 is a source-text grep row, not behavioural. Only the **lower** bound (T17,
XCW6) actually exercises the clamp.

**T18 is structurally blind by design and should be documented as such**: it
compares the graphless path with the graph path, and both reach the *same*
shared code, so any defect in that shared code degrades them identically and the
comparison still holds. T18 can only red when the two paths **diverge** — which
is what it is for; it is not a clamp test.

## 3. SAB-8 — row T22 does not exercise the line it names

T22 was written (decision D7) to make `if(floaters) set_modify(-2);` in the new
arm non-vacuous. It does not: `xschem get texts` is **0** on the `s5_flat.sch`
fixture (5 instances, zero `T {}` records), so `there_are_floaters()` returns 0
and the guarded call **never executes**. T22 passes `d 0` → `d 3` across its two
SVG exports because the export path re-translates the `lab_pin` symbol text each
time — a different mechanism entirely.

**The fix:** the plan's own D7 recipe, which the shipped row dropped — select the
probe instance and run `xschem floaters_from_selected_inst` so the symbol text
becomes a real schematic floater before the two exports.

Consequence for the record: the S11 implement report's claim that T22 "proves
the `if(floaters) set_modify(-2)` half of the arm is load-bearing" is **not
supported**. The line is correct (it is the graph arm's line, carried over
verbatim) but it is untested.

## Why this was not repaired in the S11 commit

Ladder rung **L2**. The three fixes are test-only and each is a few lines, but
they land after the verification pass that produced this step's recorded tier
numbers (218 → 241 headless, 223 → 246 on the display leg). Editing the suite
in the write-up commit would move the baseline the next crew diffs against
without a Red/Verify cycle behind it. Filed instead, with the exact recipes
above, as the first task of S12.

## Still open

Everything in this file. Nothing here changes what the shipped code does — the
shipped build is the one that passes all three probes above; what is missing is
the ability of the suite to *notice* if a later refactor stops passing them.
