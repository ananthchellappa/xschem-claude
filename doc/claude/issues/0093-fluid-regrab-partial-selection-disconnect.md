# 0093 — Re-grabbing a wire left partially selected by a prior fluid stretch DISCONNECTS the net

Status: **FIXED** (move.c END selection normalize). Branch `fluid-editing`.
Repro fixture: `tests/from_user/before_6.sch` → `tests/from_user/after_13.sch` (bad).
Test: `tests/headless/wireedit/test_wireedit_50_regrab_partial_disconnect_0093.tcl` (RED-first).
Trace that reported it: `/tmp/fltrace_7_8_10.log` (user), reproduced byte-for-byte.

## Symptom

Two back-to-back fluid drags of the SAME wire silently disconnect a net:

1. Grab R18.M's `#net1` rung (`-470 50 -360 50`) and drag it left/down — the issue-0092
   along-axis pass SHOVES the rail riser to `x=-510` (a clean, connected result).
2. **Release** LMB.
3. WITHOUT reselecting, grab the SAME rung again and drag it diagonally (up+right).

Result: the rung ends on an ISOLATED `#net3` — R18.M drops off `#net1`, no longer reaching the
ammeter/top-rail. The rail riser `(-510,70)-(-510,140)` vanishes; a spurious down-stub
`(-490,40)-(-490,70)` is left. `fluid_check_move_invariants()` logs
`P1: 3 instance pin(s) changed net partition after move -- possible disconnect`.

## Root cause (two collaborating defects)

**D1 — partial-selection re-grab drops the follow-risers (the trigger).**
A fluid stretch relays the user's OWN grabbed wire to a PARTIAL selection state (`SELECTED1/2`),
not full `SELECTED`. With the cadence default `unselect_partial_sel_wires=0` that partial
selection PERSISTS after release. On the next gesture, an already-selected press skips the fresh
`select_object()` (callback.c), so the wire reaches `select_attached_nets()` still marked
`SELECTED2`. Its WIRE branch guards `if(xctx->wire[wire].sel != SELECTED) continue;`
(select.c ~1571) — so it SKIPS grabbing the wire's connected follow-risers. The rung then
TRANSLATES ALONE: the rail riser (whose far end sits on the slideable top rail, i.e. a legitimate
follow) is left behind and orphaned.

**D2 — the nlegs==1 path has no P1/P2 rollback (why nothing repairs it).**
Because the user selected a wire (`fluid_startsel_wires>0`), the issue-0081 diagonal decomposition
is gated OFF (`nlegs==1`, move.c). The partition-change safety net (the attempt-loop that rolls
back and retries on `fluid_partition_changed()`) runs ONLY when `leg_snapped` — i.e. only for
`nlegs==2`. So a single-leg diagonal stretch that disconnects the START partition is committed
sight-unseen. `fluid_straighten_reversals()` then deletes the now-genuinely-orphaned riser as a
dangling stub (its partition check is vs the straighten-ENTRY baseline, which is ALREADY
disconnected), cementing the loss.

The disconnect is CAUSED by the drag (D1 leaves the riser behind); the straighten deletion is
legitimate cleanup of already-dead copper. A headless replay that RE-selects the rung to full
`SELECTED` between gestures stays connected — proving D1 (the partial-selection state), not the
delta or the pristine geometry, is the trigger.

## Fix

`move.c`, the fluid END selection normalize (the block that previously only handled
`fluid_startsel_wires==0`). Add the MIXED case (`fluid_startsel_wires>0`): restore the user's OWN
wires — identified by the issue-0091 session-stable id snapshot `fluid_startsel_id[]`, preserved
across the in-place relay — to FULL `SELECTED`, and deselect every tool-owned follow-wire. A
re-grab is then a clean whole-object move that follows its risers. Allocation-free (sel-flag writes
+ the existing `rebuild_selected_array`); gated on `fluid_editing` ⇒ default-off byte-identical.
This also completes the Phase-I ownership-decoupling item that was deferred for the mixed case
(the user's wire stays selected after a stretch; transient follow copper does not).

## Deferred (not this fix)

- D2 proper: a P1/P2 rollback for the `nlegs==1` path (currently only `fluid_check_move_invariants`
  DETECTS such a disconnect, log-only). Left as backlog — the D1 normalize removes the trigger for
  the reported class; a general nlegs==1 safety net is a larger, riskier change.
- D1 at source: relaxing the `select_attached_nets` `!= SELECTED` guard to follow risers for any
  whole-object-moved wire (broader, not fluid-gated) — deferred in favor of the localized,
  fluid-gated selection normalize.
