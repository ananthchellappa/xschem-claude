# 0112 — push-through slide lands promoted copper on foreign wires (wireedit 36d / 38B)

**Status: FIXED** (found by Track A step A3 of
`doc/claude/suggestions/hardening_sprint_plan.md` — first run of the full wireedit suite
after the 0109/0110 commit; the suite was not CI-gated, so the regression shipped in
`3a6643ea` and sat at HEAD until the audit fold-in ran it.)

## Symptom

`3a6643ea` (0109 push-through corner slide) broke two wireedit tests:

- `test_wireedit_36` shape (d) — "both detour rows blocked → clean DECLINE": the
  push-through translated the leg-0 detour row (y=90) down by the leg-1 delta onto
  y=150, whose span contains foreign net NY's wire ENDPOINT at (-350,150) → T-junction,
  NY welded into NA. `partition_changed=0 -> ACCEPT`: the leg_snap P2 verify is
  **pin-indexed and label-blind** — a pin-less/label-only net is invisible to it; only
  the log-only `fluid_check_move_invariants` backstop printed the merge.
- `test_wireedit_38` case B — "shove declines onto foreign wire": the push-through
  translated V from y=50 to y=80, introducing a new X crossing over foreign FOO —
  exactly the contact class the shove's `fluid_seg_hits_foreign_wire` guard exists to
  decline (its contract: any touch → baseline, never worse).

Root-cause class B (trigger-bound detection, WIRING.md §8): the push-through checked
future PIN landings (`fluid_slide_future_hazard`) but never foreign-WIRE contact on the
promoted copper's landing spans.

## Fix (move.c)

Landing guard in `fluid_slide_push_through`, run after every structural gate and before
promotion: for the stub, every promoted corner leg, and every stretch-follower's final
span, decline if the move would create a **new** contact with a stationary foreign-net
wire (`fluid_pushthrough_new_foreign_contact`).

- Contact = closed-bbox overlap (shove-grade conservative: a NEW interior X crossing
  declines too — 38B).
- **Pre-existing pair contacts are grandfathered**: a first cut declined on ANY final
  overlap and killed the legitimate 0109 repair — before_8's #net3 riser x-crosses the
  #net1 feed row both before and after the vacating slide (gesture tests 0109/0111 went
  red on route quality). "Never worse" is literal: only newly-introduced contact counts.
- Needs a fresh `wire[].node` cache → `prepare_netlist_structs(0)` paid only after all
  structural gates pass (never on a plain drag).

## Verification

- wireedit 52/52 `ALL PASS`; memcheck (36, 38) 0 errors.
- Gesture family under X: 0105-0111, 0088/0089/0096/0098/0099/0100/0103/0104,
  cadence_stretch_move, drag_keeps_selection PASS (WSLg window-map SKIPs vary per run).
- Sabotage: helper neutered (`return 0`) → 36/38 RED; restored → GREEN.
- `test_fluid_editing` FE8 fails under X at 98869cbb too — pre-existing, unrelated
  (tracked for the A5 xvfb watch).

## Notes

- The pin-partition's label-blindness (this bug's enabler) is WIRING.md §5's known
  foreign-copper blindness; risk §11.1 family. The guard patches this pass only — the
  fuzzer assertion pack (Track C2, check 1/3) is the systemic net.
