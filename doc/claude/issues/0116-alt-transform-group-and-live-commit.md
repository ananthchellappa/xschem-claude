# 0116 — Alt-R / Alt-F transform: live-commit during a drag + group transform on a standalone selection

**Status: FIXED** (working tree). Two related ALT-R/ALT-F (rotate / flip-horizontal) UX defects
reported together by the user.

**Branch:** `fluid-editing`. **Related:** 0114 (the in-drag group coercion this reuses/extends),
0115 (the overlay-ghost fix that made the in-drag rotate render correctly), `rotate_keep_connected_
stretch.md` Case 4b, WIRING.md §8 class J.

---

## Bug 1 — mid connected-drag ALT-R / ALT-F needs a mouse jiggle to show

**Symptom.** In connected-drag mode (`m` fluid stretch), pressing ALT-R or ALT-F did nothing
visible until the user moved the mouse; only then did the rotation/flip appear.

**Root cause.** During a fluid stretch each RUBBER (motion) step *live-commits* the rerouted
geometry (Phase II). A mid-drag ALT-R reaches `move_objects(ROTATE|…)` with `what == ROTATE` (no
`RUBBER` bit): the ROTATE branch only erased the overlay, bumped `move_rot`, and updated bboxes — it
did **not** re-commit. The committed geometry stayed at the old orientation; the new `move_rot` was
baked in only by the *next* motion RUBBER. A following bare RUBBER without motion early-returns on
the no-move guard (`mousex_snap==x2`), so the user had to jiggle the mouse.

**Fix** (`src/move.c`, ROTATE/FLIP branches). When the transform fires during a LIVE fluid stretch
(`fluid_editing && STARTMOVE && stretch_select && fluid_reroute_active`), after bumping
`move_rot`/`move_flip` roll back to pristine (`fluid_reroute_restore` if dirty) and set `commit_now`
so control falls into the shared commit block, which re-applies `ROTATION(move_rot,move_flip)+delta`
and repaints immediately. The non-fluid path keeps its overlay-XOR erase + bottom `draw_selection`
(already immediate). **Release==stepwise:** the END rolls back to pristine and re-applies (total
delta + final rot/flip), so the extra intermediate commit cannot change the dropped result — the
rotate_stretch suites (0099/0100/0103/0104/0110) stay green and wireedit is byte-identical.

## Bug 2 — standalone ALT-R / ALT-F spun each object about its own origin

**Symptom.** With a multi-object selection and NOT in a drag, ALT-R / ALT-F rotated/flipped **each
object about its own centre** (the group scattered / stayed put per object) instead of transforming
the whole selection as one rigid body. The user wants "the entire selection treated as one object".

**Root cause.** The standalone Alt-R (callback.c `case 'r'`) and Alt-F (`case 'f'`) branches issued
`move_objects(ROTATE|ROTATELOCAL)` / `FLIP|ROTATELOCAL` unconditionally — `ROTATELOCAL` = per-object
own-origin transform. (Shift-R/Shift-F already do the group form, `ROTATE`/`FLIP` about a pivot.)

**Fix** (`src/callback.c`, helper `standalone_group_transform(what, c_snap)`). Mirrors 0114: when
`connected_drag_group_transform()` reports >1 user object, drop `ROTATELOCAL` and transform the
whole selection about its **grid-snapped bounding-box centre** (`calc_drawing_bbox(&bb,1)`), so it
rotates/flips in place as one object. A single object keeps `ROTATELOCAL` (own-origin in-place).
Replay logs the matching verb: group → `xschem rotate|flip <px> <py>`; single →
`xschem rotate_in_place|flip_in_place`.

Pivot choice = bbox centre (not the mouse, unlike Shift-R): "as if it were one object" ⇒ in-place;
a mouse pivot would translate the selection. In-drag (bug 1 / 0114) already pivots on the grab point,
which the user confirmed feels right.

## Verification

New RED-first windowed test `tests/headless/test_alt_transform_group_0116.tcl` (5 checks):
- **A1/A2** standalone ALT-R on a vstacked pair → group rotate about bbox centre: (0,0)/(0,-200) →
  (-90,-110)/(110,-110) (members move, no longer share x).
- **B1** standalone ALT-F on a horizontal pair → inst1 crosses the bbox axis (200 → 20).
- **C1** single-object standalone ALT-R stays in-place (pos fixed, rot advances) — the negation.
- **D1** mid connected-drag ALT-R commits live: committed `inst rot` advances 0→1 with **no** further
  motion.

RED-first proven by stash+rebuild of baseline: A1/A2/B1/D1 fail (positions unchanged / rot stays 0),
C1 passes. Post-fix 5/5.

**Regression:** wireedit 56/56 ALL PASS (byte-identical committed geometry) + memcheck 0 errors;
valgrind on the 0116 windowed test (the new ROTATE-commit + standalone paths) 0 errors; windowed
0114 7/7, 0113 7/7, rotate_stretch_reconnect 17/17 + 0099 21/21 + 0100 51/51 + 0103 77/77 + 0104
76/76 + 0110 9/9. (`test_fluid_editing` FE8 fails identically on baseline HEAD — pre-existing, unrelated.)

## Repro (interactive)

1. `src/xschem --script src/cadence_style_rc`
2. **Bug 2:** select ≥2 objects, press Alt-R / Alt-F. Pre-fix each spins in place; post-fix the whole
   selection rotates/flips as one body about its centre.
3. **Bug 1:** press `m`, drag, then Alt-R mid-drag WITHOUT moving the mouse further. Pre-fix nothing
   changes until you jiggle the mouse; post-fix the rotation shows immediately.
