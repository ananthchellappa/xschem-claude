# Issue 0081 — support diagonal (non-axis-aligned) drags for the slide/shove family via per-axis decomposition

**Opened:** 2026-07-06
**Status:** IMPLEMENTED 2026-07-07 (branch `fluid-editing`, uncommitted at time of writing).
Design sketch below is the original plan; see **Implementation** for what actually shipped and the
one design correction (a P2 safety net the "P1/P2 by construction" sketch missed).

---

## Implementation (2026-07-07)

**Mechanism (design workflow `wf_05c05cc1` — 3 proposals converged + judge):** a fixed **X-then-Y
two-leg loop** wrapping the shared geometry-commit region in `move_objects()` (`move.c`), with the
follow set **re-derived between legs** via `select_attached_nets()` (new `move_regrab_follow_set()`).
Each leg feeds a pure-axis delta, so `compute_wire_slide()` / `fluid_shove_connected_wire()` fire
naturally (their `dxnz==dynz` bail is never reached) with NO edit to their internals. The region is
left **byte-for-byte in place** (only wrapped + per-leg delta set), matching the Phase-II discipline.
Gated: `fluid_editing && stretch_select && orthogonal_wiring && rot==flip==0 &&
fluid_startsel_wires==0 && Dx!=0 && Dy!=0` ⇒ `nlegs=2`, else `nlegs=1` (single pass, byte-identical
to HEAD). Fixed X-then-Y (not magnitude-derived) ⇒ deterministic ⇒ release==stepwise. Grafts folded
in from the review-of-proposals: `orthogonal_wiring` in the gate; `movelastsel=lastsel` after the
re-grab (else the dce0bea6 `symbol_bbox` heap-overflow); `fluid_startsel_wires` save/restore.

**DESIGN CORRECTION — the sketch's "P1/P2 by construction" (Open Q3) was WRONG.** The obstacle detour
(`fluid_reroute_around_obstacles`) only fires on the DIAGONAL sweep (the crossing is moving-pin-
incident); a per-axis leg can lay the same stationary-device straddle as a **non-pin-incident** wire
the detour misses. Concretely, R18 → ammeter v8 (`test_wireedit_34`): the one-shot diagonal detours
the riser below v8 (no short), but the X-leg alone already shorts v8 (a pre-existing pure-axis
limitation the diagonal never exposed), and the Y-leg cannot recover it. So P2 does NOT hold by
construction. **Fix = a P2 safety net** (an `attempt` loop): snapshot pristine (`mem_snapshot_*`),
run the two legs, and if they CHANGE CONNECTIVITY the one-shot would not (`fluid_partition_changed()
>0`), roll back to pristine and re-run as a SINGLE diagonal pass (the proven no-short Layers 1–3).
The trigger is the **partition-change** signal (canonical first-seen pin ids vs START) — the COMPLETE
P1/P2 test: device merge, merge onto a single-pin net LABEL, AND disconnect. (An earlier version
triggered on the two-pin `fluid_check_device_merge()` alone; the adversarial review `wf_99e41f72`
found it MISSED a merge onto a net label — R18's net silently merged onto a stationary GND `lab_pin`
on the shoved-V corridor — so the trigger was broadened. `test_wireedit_40` Drive 3 locks it,
sabotage-verified.) Decomposition is lowest in the conflict order (`P1=P2 > … > P6`) and must yield
to P2. R18 falls back and is **byte-identical to the HEAD one-shot** (verified). before_1's shove
(no obstacle) preserves the partition ⇒ keeps the two-leg aesthetic.

**Tests:** `test_wireedit_40_diagonal_shove` (before_1 diagonal `we_move_stretch 20 20`; RED-first @
HEAD — reversed stub + no shove — GREEN after; release==stepwise). `test_wireedit_34`/`36` (R18-class
diagonal) now doubly serve as the **fallback sabotage test** — remove the safety net ⇒ they go RED
(v8 short). Full wireedit suite ALL PASS (40) + `--memcheck` clean; default-off + axis-aligned +
R18-fallback all byte-identical vs the pre-change binary. **NOT yet done:** user real-window eyeball
(the acceptance gate). Deferred/limitations: the between-leg re-grab does not re-arm
`connect_by_kissing`, so a mid-span tap on a follow wire follows rigidly (P1-safe, possibly less
pretty); seam artifacts (P4/P7 quality) from the X-only intermediate are possible (P2 stays safe via
the net + END invariants).

---
&nbsp;

<details><summary>Original design sketch (pre-implementation)</summary>
**Affects:** interactive fluid stretch-move of an instance with `fluid_editing` on,
when the drag vector is **diagonal** (both Δx and Δy nonzero).
**Severity:** medium (ergonomics/aesthetics + a re-appearing P5 own-body intrusion on
diagonal drags) — connectivity stays correct (Layers 1–3 already run for diagonal), so
no wrong netlist.
**Branch:** `fluid-editing`.
**Related:** issue 0015 (the axis-aligned shove this generalizes); `compute_wire_slide`
and `fluid_shove_connected_wire` in `move.c` (both axis-gated); Phase II incremental
per-snap-step reroute (`incremental_wire_reroute.md` §5); the occupancy model
(issue 0015 §6).

---

## 1. The gap

Two members of the "make the wiring look right as you drag" family are gated to
**pure axis-aligned** moves:

- `compute_wire_slide()` — `move.c:1386`: `if(dxnz == dynz) return;`
- `fluid_shove_connected_wire()` — `move.c:2417`: `if(dxnz == dynz) return;`

So on a **diagonal** drag neither the corner-slide nor the drag-toward **shove**
fires. Concretely: drag an instance diagonally *toward* a connected perpendicular
wire and the pin's stub is relayed as a **reversed leg back through the instance's own
body** (the issue-0015 / `after_1.sch` P5 intrusion) — the exact thing the shove fixes
for axis-aligned drags.

**What already works on diagonal** (do not re-solve): the obstacle/no-short spine —
`place_moved_wire`'s Layer-1 ml-flip and `fluid_reroute_around_obstacles` (Layers 2/3)
— gates on `rot==flip==0`, **not** on axis. The headline R18 acceptance case is itself
a diagonal drag (`we_move_stretch 110 120`), and it is no-short. The manhattan router
always emits orthogonal wire even for a diagonal drag. So the gap is **only** the
aesthetic slide/shove family, not correctness.

**Cadence has no such limitation** — any drag angle behaves; the wiring stays clean.

## 2. The key insight (design direction — from the user)

A diagonal drag at human speed is **already a sequence of small incremental steps**,
and can be decomposed into **a move in X followed by a move in Y** (or Y then X),
each of which is a pure axis-aligned move the existing slide/shove logic handles
correctly. So the fix is *not* new geometry — it is **running the existing
axis-aligned machinery once per axis** instead of bailing out on `dxnz == dynz`.

This lands naturally on the Phase II architecture, which already **restores the
pristine snapshot and re-applies the current total delta every snap step** and is a
pure function of `(pristine, total delta)`. Decomposing the total diagonal delta into
an X leg then a Y leg is deterministic ⇒ **release == stepwise for free**, exactly as
today.

## 3. Design sketch (to be refined before coding)

Reapply the total delta as two sequential axis-aligned passes from pristine:

1. apply `(Δx, 0)` → run the axis-aligned pipeline (place_moved_wire + slide + shove +
   Layers 1–3) as if a pure horizontal move;
2. apply `(0, Δy)` on the resulting geometry → run it again as a pure vertical move.

Each pass sees a pure axis-aligned delta, so `compute_wire_slide` /
`fluid_shove_connected_wire` fire normally; the obstacle layers (already diagonal-safe)
still hold. The composition of two axis moves reaches the same final pin position as
the diagonal.

### Open questions (write the tests from the answers)
1. **Total-delta decomposition vs per-incremental-step.** Decompose the *total* delta
   (X-leg then Y-leg from pristine, deterministic, release==stepwise) — vs replay the
   actual incremental per-step deltas. The former is simpler and matches Phase II; the
   latter is closer to "what the human did" but is path-dependent and harder to make
   release==stepwise. **Proposed: total-delta X-then-Y.**
2. **Axis order (X-then-Y vs Y-then-X).** Does the order change the final route? Pick a
   deterministic rule (e.g. the larger component first, or always X-then-Y) so
   stepwise==release; document it. Test a case where the two orders differ.
3. **Interaction with Layers 1–3.** They already handle a diagonal delta in one shot;
   after decomposition each pass hands them an axis delta. Confirm the two-pass result
   is no-short and no worse than today's one-shot diagonal (regression: R18 stays
   no-short).
4. **compute_wire_slide too, or shove only?** Generalize both (they share the gate) or
   start with the shove. The corner-slide's own diagonal behavior today is "jog"; check
   it does not regress.
5. **Cost.** Two pipeline passes per snap step (plus a `prepare_netlist_structs` in the
   shove) — acceptable at human drag speed? Measure; the passes are O(wires).
6. **Idempotence / degenerate legs.** A decomposed leg with a zero component must be a
   no-op (don't run an axis pass for a zero delta). Overrun boundaries at the seam
   between the X and Y legs (a pin landing exactly on a wire after the X leg, then moved
   by the Y leg) — mirror the issue-0015 overrun==0 handling.

## 4. Acceptance

- A **diagonal** drag-toward a connected perpendicular wire **shoves** it (no reversed
  stub through the body), matching the axis-aligned behavior of issue 0015.
- R18 (diagonal) stays no-short; the full wireedit suite + memcheck stay green.
- Default-off byte-identical; release == stepwise; P1/P2/P5 preserved (guards from
  issue 0015 §8 apply per axis-pass).
- Real-window eyeball: dragging a device diagonally leaves clean wiring at any angle
  (the Cadence parity bar).

## 5. RED-first test to start from

`test_wireedit_39_diagonal_shove`: the `before_1` scene but drag R18 **diagonally**
(e.g. `we_move_stretch 20 20` — pin driven past its perpendicular wire on the Y axis
while also moving in X). Assert the shove fired (no reversed stub in body, wire pushed
ahead) — RED at HEAD (the `dxnz==dynz` gate bails), GREEN after decomposition. Drive
release + stepwise; assert identical.

</details>
