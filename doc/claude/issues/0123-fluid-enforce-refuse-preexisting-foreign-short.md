# 0123 — Fluid move refused by a PRE-EXISTING short on a foreign net

Status: **FIXED** (primary bug). Secondary pin-placement hiccup: under investigation (see bottom).

## Symptom (user report)

Drew one wire with an S/Z shape (5 clickable segments over one connected net), added a couple
of pins and wire-labels, then **deleted** the middle horizontal segment. Tried to `m`
(connected-stretch) the isolated vertical segment that now belongs only to pin **A** — and the
move was **refused** ("move refused: would short/merge nets"). Ridiculous: that segment is on a
clean single-name net; moving it can short nothing.

Repro schematic: `tests/from_user/move_refuse.sch`. Five wires chain-connect into ONE physical
net that carries **four conflicting names**: `ipin A` (p1), `ipin B` (p2), `lab_pin a` (l1),
`lab_pin b` (l2). Deleting the `y=0` wire splits it: net-α (top + right-vertical) = clean **A**;
net-β (left vertical + `y=60`) still carries `a`,`B`,`b` → **2 label shorts**.

## Root cause

`fluid_check_move_invariants()` (move.c) is the END enforcement gate (hardening sprint Track B3):
after all healers run, if a short/merge survives and `fluid_enforce_invariants` is on, it restores
the pristine snapshot and refuses the gesture. Its refuse signal = `label_shorts + device_merges`.

- The **device-merge** pass (`fluid_check_device_merge`) is correctly a **DELTA**: it compares each
  device pin's net at gesture START (`fluid_g.snap_pinnet`) vs END, so a pre-existing merge (equal at
  both ends) is not counted.
- The **label-short** pass was **ABSOLUTE**: it just scanned every `lab_pin` and counted any whose
  forced name disagreed with the physical net of the wire it touches — with NO reference to the
  gesture-start state. So net-β's pre-existing `a`/`b` naming conflict (which the move never touches)
  contributed 2 to the refuse signal on EVERY subsequent fluid stretch anywhere in the schematic.

FLUID_TRACE confirmed: `p2_merges=2` at the refused END with `violations=2 dev_merges=0`; the
`INVARIANT (P2)` log named `l1`/`l2` on net `B` — a foreign net, unrelated to the moved segment.
A pre-existing short poisoned all future moves.

## Fix (move.c)

Make the label-short pass **delta**, matching the device-merge pass:

1. Extracted the label-short loop into `fluid_count_label_shorts()` (absolute whole-schematic count,
   requires fresh `prepare_netlist_structs`).
2. At the pristine (gesture-START, pre-delta) enforce snapshot, capture
   `enf_short_base = fluid_count_label_shorts()` after a `prepare_netlist_structs(0)`.
3. `fluid_check_move_invariants(int short_baseline)` now returns `max(0, end_shorts - baseline) +
   dev_merges`. A gesture that HEALS a pre-existing short clamps at 0 (never negative).
4. `fluid_last_move_violations` now publishes the DELTA (violations THIS move introduced), which is
   what the var name/tests already mean.

Only fluid stretches with enforcement on pay the extra baseline `prepare_netlist_structs`.

## Verification

- `tests/from_user/move_refuse.sch` scenario reproduced headless (`scratchpad/repro_move_refuse.tcl`):
  before fix the stretch was refused (wire unchanged); after fix `short_base=2 violations=0`, the
  vertical wire moves `70→40` and the top wire follows — **committed**.
- Genuine shorts still refuse: `test_wireedit_26` (label-short delta ≥1 on a real new short) and
  `test_wireedit_54` (device-merge refuse) both PASS.
- Full `tests/headless/wireedit` suite: **56/56 PASS**.

## Secondary: pin-placement hiccup — click captured by fluid tip-grab

Status: **guarded** (conservative fix); desync ROOT open (no headless repro — needs GUI eyeball).

Same session: the FIRST `p` add-pin placement click went into wire-end-drag instead of dropping the
pin (ESC left one pin stranded). Trace opened with `fluid_gesture_arm leaked-armed recover`.

**Mechanism** (mapped in callback.c):
- A live schematic Add-Pin preview is carried by `STARTMOVE | START_SYMPIN` + `sympin_preview=1` + an
  armed fluid gesture (`add_sch_pin -place`, scheduler.c:1639-1644 → `move_objects(START)`).
- On a plain Button1 press, `end_place_move_copy_zoom()` (callback.c:6686) commits the drop — but
  ONLY via its `STARTMOVE` branch (callback.c:1898). No `START_SYMPIN`-alone branch.
- The very next block, the select / fluid tip-grab (callback.c:6693), was gated only by
  `!excl && !STARTSELECT` where `excl = STARTWIRE|STARTRECT|STARTLINE|STARTPOLYGON|STARTARC`.
  **No `PLACE_SYMBOL`/`PLACE_TEXT`/`START_SYMPIN`/`sympin_preview` guard.**
- So once `STARTMOVE` is cleared out from under a still-live placement (e.g. `unselect_all()` zeroes
  `ui_state` at select.c:1068 without a matching `fluid_gesture_free()` — the same call also orphans
  the armed gesture), the drop path is skipped and the press falls into `grab_free_wire_vertex()` /
  `try_grab_shape_point()` → `move_objects(START)`: a spurious wire-stretch + the leaked-armed
  tripwire. ESC then can't delete the preview pin (its delete in `abort_operation` requires STARTMOVE
  still set), so one pin is stranded.

**Fix applied (callback.c:6693 gate):** the select/tip-grab block now also declines when a placement
preview is live — added `!(ui_state & (PLACE_SYMBOL | PLACE_TEXT | START_SYMPIN)) && !sympin_preview`.
Normal placement drops are unaffected (they commit at 6686 with STARTMOVE set, returning before this
block); the guard bites only in the desync window, where declining the grab is strictly safer than
stealing the click into a wire-stretch. Regression-clean: `test_sch_add_pin`, `test_add_wire_label`,
`test_wire_split`, wireedit 57/57 all still pass.

**Residual (open):** the guard stops the WRONG action but the desync ROOT — `STARTMOVE` being cleared
while `START_SYMPIN`/`sympin_preview` stay live, and `unselect_all()` orphaning the armed gesture — is
not closed (candidate: have the ui_state teardown release the gesture, but `unselect_all` runs inside
legit fluid passes too, so a blanket free is risky). No headless repro exists (the capture needs real
X button events; `test_fluid_editing` SKIPs with no X). Needs a GUI repro to close cleanly.
