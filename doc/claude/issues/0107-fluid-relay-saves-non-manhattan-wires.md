# 0107 — accepted rigid diagonal relay saved raw: non-Manhattan wires under orthogonal mode

**Status: FIXED** (src/move.c, new `fluid_manhattanize_relay_diagonals` END pass)

## Name / class

**Relay diagonals saved raw**: when every orthogonal attempt of the accept ladder is dirty
and the rigid diagonal relay (attempt 2, the P2 last resort) restores the START partition,
its result is accepted and saved AS IS — follow wires running pin→anchor diagonally, in a
schematic drawn under `orthogonal_wiring`. Electrically correct, geometrically illegal.

## Repro (user session, FLUID_TRACE=/tmp/fltrace_7_8_21.log)

- `tests/from_user/before_8.sch`, plain LMB drag R18 NW by (-130,-90) → R18 to (-170,-90).
- Saved `tests/from_user/after_24.sch` keeps two diagonals:
  `N -200 -90 -80 0` (left pin → its #net3 anchor) and `N -140 -90 0 0` (right pin →
  its #net1 anchor).

## Why the ladder fell through (trace forensics)

Both follow anchors sit on the y=0 row, so the two ortho routes must share it:

1. Attempt 0 (2-leg): during the x-leg the pins sweep through each other's corridor — the
   two routes collinear-overlap on y=0 → merge → rollback.
2. Attempt 1 (single diagonal, ortho elbows): left route becomes riser x=-210 + horizontal
   `[-210,0]→[-80,0]`; right route's riser drops at x=-130 and its bottom endpoint T-lands
   ON that horizontal → #net3 welded to #net1. No de-shorter reaches it: the weld is at
   (-130,0) where there is no pin (rip-up/jog are pin-anchored and decline — nothing
   extends beyond the pin on its row), short-tail's single doom is partial (4→3, reverted).
3. Attempt 2 (rigid relay): the two direct diagonals are parallel and touch nothing →
   partition_changed=0 → ACCEPT. The relay path runs with `leg_ortho==0`, which skips the
   whole END cleanup block, so nothing downstream ever re-Manhattanizes the result.

## Fix

New END-only pass `fluid_manhattanize_relay_diagonals()`, called after the accept ladder
when `!commit_now && diag_relay && orthogonal_wiring && stretch_select && fluid_editing`:

- Entry no-op unless the live partition equals START (i.e. the relay really was accepted;
  the attempt-1-alt-restored path is dirty and declines).
- Candidates: diagonal, non-bus wires with one endpoint exactly on a moved (selected)
  device pin — the wires whose endpoint the relay translated. Pristine user diagonals not
  touching a moved pin are never candidates.
- Each candidate is converted to an L: try corner (pin.x, anchor.y) (V-first) then
  (anchor.x, pin.y) (H-first); keep the first orientation whose result leaves
  `fluid_partition_changed()==0`, else revert that attempt and keep the diagonal
  (electrically correct beats pretty). Reshape/add-only, per-wire verified — the pass can
  only re-Manhattanize or decline.
- On any conversion: `trim_wires()` + `check_collapsing_objects()` and a final netlist
  rebuild.

On the repro both diagonals convert (`manh: wire=13 → L via (-200,0)`, `manh: wire=14 → L
via (0,-90)` — wire 14's first orientation is rejected by the verify because its
horizontal would land on the capacitor riser's bottom endpoint). Saved result is fully
Manhattan: left route `(-200,-90)→(-200,0)→(-80,0)`, right route `(-140,-90)→(0,-90)→
(0,-40)` into the backbone. No shorts, no diagonals.

Live RUBBER previews of the relay stay diagonal on purpose — the saved END result is what
the user keeps; mid-drag the diagonal telegraphs "last-resort routing" honestly.

Known cosmetic leftover (pre-existing relay-path limitation, 0104 doc): the relay skips the
END cleanup block, so an anchor-side stub like `[0,-40 0,0]` can stay as a same-net tail.
Electrically clean. **UPDATE: fixed by issue 0108** — the pass now RE-ANCHORS each relay
diagonal to the closest same-net copper (the stale-anchor L is only a fallback) and prunes
the abandoned stale feed. See doc/claude/issues/0108-fluid-relay-reanchors-to-stale-feet.md.

## Verification

- `tests/headless/test_fluid_relay_manhattanize_0107.tcl` (fixture shared with 0105/0106):
  5/5 PASS including a zero-diagonal-wires assert; sabotage-RED against pre-0107 move.c.
- Battery green: 0105, 0106, 0098×2, 0088, 0089, 0096, 0099, 0100, 0103, 0104, reconnect,
  wireedit suite, run_regression.
