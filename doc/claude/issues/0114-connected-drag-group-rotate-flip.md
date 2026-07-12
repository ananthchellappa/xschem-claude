# 0114 — multi-object connected-drag rotate/flip must transform the whole group

**Status: FIXED** (reported by user: "In connected drag mode, when selection is more than one
object, rotate/flip should rotate/flip the entire selection [keeping wires connected with
rerouting], not operate on individual objects within the selection by themselves.")

## Symptom

During a connected drag of ≥2 objects (`m`, then a mid-drag rotate/flip), the ALT-modified
transforms spun **each object about its own origin**: the group scattered / overlapped and
relative positions were preserved instead of the selection rotating/flipping rigidly about a
shared pivot (Cadence Virtuoso Stretch semantics). Wire connectivity was still repaired
per-pin, but the geometry was wrong.

## Root cause — UX/altitude gap

The mid-drag transform keys split by modifier:

| key | move.c call | pivot |
|---|---|---|
| Shift-R / Shift-F / Shift-V | `ROTATE` / `FLIP` (`rotatelocal=0`) | shared grab pivot `xctx->x1/y1` — **group** |
| ALT-R / ALT-F / ALT-V | `ROTATE\|ROTATELOCAL` etc. (`rotatelocal=1`) | each object's own origin — **per-object** |

`rotatelocal` (rotate/flip "around their anchor points") is correct for a **single** object
(and Case 4, `rotate_keep_connected_stretch.md`, reconnects its follow wires about the owning
instance origin) — but for a multi-object selection it is exactly the per-object spin the user
did not want. The three ALT sites (callback.c: `case 'r'`, `case 'f'`, `case 'v'` under
`EQUAL_MODMASK`, both STARTMOVE and STARTCOPY arms) were unconditionally `ROTATELOCAL`. The
group path (shared pivot, multi-instance connected reroute) already existed and was tested
(Case 4b test T8) — it was simply never selected for the ALT variants.

## Fix (callback.c)

New helper `connected_drag_group_transform()`: is the in-flight move/copy a MULTI-OBJECT
selection? A follow-set (`select_attached_nets`) only ever adds WIREs, so every selected
non-wire object is user-owned; the user's own wires are `fluid_startsel_wires` during a fluid
stretch, or simply every selected wire for a rigid move. It scans the object arrays directly
(not `sel_array`, which may be stale mid-gesture). `> 1` user object ⇒ drop `ROTATELOCAL` so
the transform takes the group form (shared pivot):

```
move_objects(ROTATE | (connected_drag_group_transform() ? 0 : ROTATELOCAL), 0,0,0);
```

Applied to all three ALT sites × {move, copy}. Shift-R/F/V already grouped — unchanged.

## Negations (WIRING.md rule #4)

- Single object (`nonwire + userwires == 1`) → keeps `ROTATELOCAL`, i.e. the existing Case 4
  in-place rotate/flip that reconnects about the owning-instance origin. (test C1)
- Shift-R on a multi-selection already grouped → still groups (test D1).
- Not-in-a-move (nothing selected → prompt-for-object; single selected → immediate) is a
  different code path (`lastsel==0`/standalone), untouched.

## Verification

- `tests/headless/test_connected_drag_group_transform_0114.tcl` 7/7 PASS: ALT-R (A), ALT-F
  (B), ALT-V (E) each transform the pair as a group and keep the connection (A2/A3);
  single-object ALT-R stays rotatelocal (C1); Shift-R still groups (D1). RED-first: pre-fix
  A1/A2/A3/B1/E1 fail (positions unchanged = per-object spin), C1/D1 stable.
- No regression: test_rotate_stretch_reconnect (17/17, single-instance connected rotate),
  test_rotate_prompt_object, test_cadence_stretch_move, wireedit 56/56, golden 0 fail.
- memcheck: no new allocations; definite-leak set = load-only baseline.

## Notes / follow-ups

- Pivot is `xctx->x1/y1` = the grab-snap point (the pickup location), same as the already-
  shipped Shift-R group path. `rotate_keep_connected_stretch.md` decision (1) prefers the
  grabbed-pin coordinate; today the two coincide for the common pickup and the group path is
  the tested one — a pivot refinement is orthogonal to this fix.
- Rotation under a straddle still lacks the Layer-2/3 + exit-stub machinery (WIRING.md
  §11.9); group rotate inherits that limitation but never worsens connectivity (verified by
  the A2/A3 connection checks + the never-worse healer ladder).
