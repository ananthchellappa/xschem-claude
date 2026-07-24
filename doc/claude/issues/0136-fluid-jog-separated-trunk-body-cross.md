# 0136 — fluid connected-drag: net threads the moved body via a jog-separated trunk

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** wiring / fluid connected-drag (`src/move.c`) — see `doc/claude/WIRING.md`
**Fixture:** `tests/from_user/before_39.sch` → `tests/from_user/after_40.sch` (buggy) /
`after_40_fixed.sch` (post-fix). Test `tests/headless/test_fluid_jog_separated_trunk_0136.tcl`.

## Gesture

Pointer on the body of `x1` (`SANDBOX/solar_ctl`, rot1), LMB press, drag right+down, release — a
Cadence connected-drag. Action-log replay: `select_at 100 -10 ; move_objects 60 30` → **delta
(+60,+30)**. `x1` origin (80,10) → (140,40). FLUID trace `/tmp/xschem_fltrace_197927.log`.

Accepted path: END **attempt=0, leg-split (nlegs=2, `diag_relay=0`)**, partition clean — the pure-ortho
X-then-Y decomposition of the diagonal delta (NOT the rigid diag_relay fallback).

## Geometry

`x1` DEVICE body box after the move = world **x[120,160] y[-90,80]** (symbol polygon
`P 40 -20 -130 -20 -130 20 40 20`, rot1 about (140,40)). Moved pins: CTRL1(150,100) TRIANG(110,100)
LED(150,-110) REF(130,-110) — all outside the body, escapes correct.

CTRL1 reaches its naming label `l1` (220,-20) through a **stationary vertical trunk at x=140**
(`N 140 -20 140 130`, label-anchored — it was already at x=140 in before_39 and stays put while the pin
translates +60). The advancing body now ENGULFS it. Saved route (after_40):

```
pin(150,100) → (150,130) → (140,130) → ↓ N 140 -20 140 130 → (140,-20) → N 140 -20 220 -20 → l1(220,-20)
                                          └── the elbow (140,-20) is STRICTLY inside the body ──┘
```

Two subsegments thread the body: vertical `(140,80)→(140,-20)` and horizontal `(140,-20)→(160,-20)`.

## Defects (named)

1. **`body-engulfs-jog-separated-trunk`** (primary, user-reported): CTRL1's load-bearing trunk threads
   `x1`'s body. Partition is unchanged (electrically correct) — a **P5 no-body-cross** violation, not a
   short.
2. **`neighbor-net-riser-near-miss`** (secondary, independent — DEFERRED): REF's new riser
   `N 130 -130 130 -110` (#net2) crosses the LED rail `N -50 -120 150 -120` (#net1) at (130,-120) — a
   4-way crossing, **not** an electrical short (no endpoint coincidence). Absent from before_39
   (nets were cleanly split at y=-140/-150). Left as-is: a distinct REF/LED-routing near-miss, not the
   body-cross this issue fixes.
3. **`pin-riser-overshoot`** (secondary, entangled with 1): the CTRL1 pin exits +y down to y=130 before
   the trunk climbs back — a needless up-detour. Largely dissolved by the fix (the trunk now clears the
   body); the riser detour itself is cosmetic.

## Root cause

Both body-crossing repairs that exist structurally miss this shape on the pure-ortho path:

- **`fluid_shove_body_crossing_backbone`** (the only body-crossing repair on the `!diag_relay` path,
  fired per-axis at move.c ~8847) is **PIN-INCIDENT**: it seeds the perpendicular run at the moved
  pin's OWN column (`pc = xmove ? px : py`, move.c:7056; run membership `wire.x == pc`, :7077; seeded at
  the pin, :7067). CTRL1's pin is at x=150; the trunk is at x=140, one grid off-column, reached only
  through a JOG. **No** moved pin sits at column x=140, so the trunk is invisible to every pin — the
  trace shows all four pins declining with `corners=0`.
- The **reroute/delete family** (`fluid_reroute_body_crossing_feeds` / `fluid_delete_body_crossing_copper`,
  move.c ~5027/4969) that could pull a feed off a through-body trunk is invoked ONLY inside
  `fluid_manhattanize_relay_diagonals`, gated on `diag_relay` (move.c:8794). This drag accepted at
  attempt=0 on the pure-ortho path (`diag_relay=0`), so it never runs. Even if it did, its
  nearest-outside-body anchor for CTRL1 is the pin's own riser end (150,130) → the feed never leaves the
  body and the trunk stays load-bearing to the label (exactly the §11.9f situation that needed the shove,
  not the reroute).

Net gap: **the ortho path has no pass that can shove a body-threading backbone that is jog-separated
(not incident) from a moved pin.** New variant of §11.9c/§11.9f — same symbol, same CTRL1-through-body
shape, but the backbone is one jog off the pin (the delta happened to NOT align the pin column with the
trunk column; in after_35 the pin landed on the trunk column x=140, so the pin-incident shove fired).

## Fix

New END pass **`fluid_shove_jog_separated_trunk`** (move.c, sibling of the pin-incident shove; invoked
per-axis right after it at BOTH the diag_relay (~8814) and pure-ortho (~8848) sites via the existing
per-axis delta spoof). For the given axis (xmove ⇒ a VERTICAL trunk at column tc, shoved in x):

1. Candidate = a same-net thin perpendicular-orientation wire strictly threading a moved body
   (`fluid_seg_crosses_sel_body`, which already exempts a pin's own outward feed leg).
2. **Gates** (each closes a specific over-fire found in regression):
   - **PRE-EXISTING span** (`!fluid_wire_is_novel_span`) — never a detour leg THIS gesture's reroute just
     laid (test_wireedit_36 case j: a fresh Layer-3 step-out leg through the moving device's own body).
   - **LOAD-BEARING bridge** — dooming the run must change the pin partition
     (`fluid_loop_partition` doomed mask); a redundant user-ring/loop edge the body merely overlaps
     keeps the partition and is left untouched (test_wireedit_45 cases U/T).
   - **FOLLOW net** — a moved pin carries the trunk's node (only the gesture's OWN copper is reshaped,
     never a foreign rail, §11.1).
   - No moved pin on the run (that is the pin-incident shove's job); no fixed pin on the run (cannot
     re-solder); attachments all plain same-net axis-aligned thin wires.
3. Build the contiguous same-net run at column tc; collect its perpendicular attachments.
4. Shove target `ct` = one grid past the crossed body edge, tried on the side the attachments lean toward
   first (CTRL1: x=140 → x=170, one grid past the right edge x=160). Accept the first side whose rebuilt
   segments (translated trunk + re-anchored attachments) are **body-free** (clear every moved &
   stationary body) and weld no foreign copper.
5. **Translate** (not collapse) the run to ct and move each attachment's near end to ct;
   mem-snapshot + **DOUBLE** partition-verify (restore-START name AND preserve-entry geometric) with
   EXACT revert. No new wires are created, so a named rail is reshaped but never renamed.

Never worse: a decline / failed verify keeps the accepted route byte-identical.

### Result

CTRL1 trunk x=140 → **x=170**: route pin(150,100)→(150,130)→(170,130)→(170,-20)→l1(220,-20), body-clear.
Partition intact (CTRL1/TRIANG distinct), no diagonals.

## Verification

- New test `test_fluid_jog_separated_trunk_0136.tcl`: **RED on baseline** (3 body-cross checks fail),
  **GREEN after fix** (11/11). Real-X; self-skips without DISPLAY.
- Regression: **wireedit 57/57**; all `test_fluid_*` gesture suites green (ortho_ctrl1_shove 14/14,
  bodyshove_guards 14/14, diagonal_ref_drop 12/12, diagonal_neighbor_bus 10/10,
  diagonal_shove_throughbody 9/9, ortho_second_drag, rotate_second_drag, rotate_body_route,
  exit_stub_staircase 20/20, relay_manhattanize/reanchor, …).
- Two over-fires caught + gated during development (both were ALL-PASS on baseline, RED with the naive
  pass, GREEN after the novelty + bridge gates): wireedit_36 case j (novel detour leg) and wireedit_45
  cases U/T (redundant user ring). `test_fluid_editing` FE8 is a **pre-existing** arc-drag failure
  (RED on baseline too), unrelated.

## Deferred

Defect 2 (`neighbor-net-riser-near-miss`) — REF/#net2 riser crossing the LED/#net1 rail at (130,-120).
A 4-way crossing, not an electrical short; a separate REF/LED-routing concern from the CTRL1 body-cross.
No test yet.
