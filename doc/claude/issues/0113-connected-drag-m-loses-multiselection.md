# 0113 — connected-drag 'm' placement collapses a multi-selection

**Status: FIXED** (reported by user: "select a few objects, press `m`, click, move, click to
place → selection is lost. The same objects should remain selected." A regression that
"went away, then came back".)

## Symptom

Under `cadence_compat` (the user's `src/cadence_style_rc` setup): select ≥2 objects, press
`m` (noun-verb connected stretch — the selection is picked up immediately, attached wires
follow), move the pointer, click to place. After the drop **only the single object under the
drop point stays selected** — the rest of the selection is dropped. A single-object move was
unaffected (so the bug hid behind the common case).

## Root cause — class F (selection/ownership debt, WIRING.md §8)

A keyboard `m` move is a *click-move-click* gesture, not a press-drag-release. The
**placement click's PRESS** commits the move: `handle_button_press` →
`end_place_move_copy_zoom()` → `move_objects(END)`, which clears `STARTMOVE`. The press also
reset `xctx->mouse_moved = 0` at its top (callback.c:5996).

The matching **RELEASE** then reached the cadence "deselect everything but the item under the
cursor" branch (callback.c, `handle_button_release`, guarded
`cadence_compat && lastsel != 1 && Button1Mask && !mouse_moved && !(STARTMOVE|STARTCOPY)`).
That guard's `!(STARTMOVE|STARTCOPY)` was meant to protect an in-flight move (the
`cadence_stretch_move_keys.md` "5th edit") — but it is **useless here because the move already
ENDED on the press**, and `mouse_moved` was 0 (keyboard motion never sets it; only a
Button1-held drag does, callback.c:4238). So the branch fired and isolated the drop-point
object, collapsing the moved multi-selection.

This is the press-completes-then-release-deselects shape; the earlier guard only covered the
mouse press-drag-release path where `STARTMOVE` is still live at release.

## Fix (callback.c + xschem.h)

A one-shot latch `xctx->place_click_committed`:

- **Set** at the placement press: the `end_place_move_copy_zoom()` call site (callback.c:6074)
  records whether `STARTMOVE|STARTCOPY` was live *before* the call; if it was and the call
  committed (returned 1), a verb-noun/keyboard placement just happened → latch it.
- **Consumed** once at the very top of `handle_button_release` — *before* the
  `waves_selected()` early-return — read + clear, and when set force `xctx->mouse_moved = 1`.
  The completed placement then reads as a moved gesture, so the `!mouse_moved` deselect branch
  (and every other bare-click-select path) is naturally suppressed. Cleared unconditionally on
  EVERY release exit path so it can never leak to a later gesture.

**Review fix (adversarial review wf_fdd928d4).** The first cut consumed the latch *after* the
`waves_selected()` early-return. A placement dropped with the pointer over a waveform graph
routes the release to `waves_callback()` and returns before the consume: the press cleared
`STARTMOVE`, so `waves_selected` (skipped on the press by its `STARTMOVE` excl-mask) now fires
on the release. The latch was stranded at 1 and the NEXT unrelated plain click consumed it,
spuriously suppressing that click's deselect. Fixed by moving the consume to the top of
`handle_button_release`, ahead of the waves branch — it now runs on every exit path.
Regression-guarded by test E1 (a click-isolate after a prior `m` placement).

Scope: the latch is set ONLY when a press finds an already-live `STARTMOVE|STARTCOPY` and
commits it — exactly the verb-noun/keyboard placement. A mouse press-drag-release move STARTS
the move on the press (no pre-existing STARTMOVE) so the latch is never set there; its release
still completes normally via the `STARTMOVE && drag_elements` branch.

## Negations (WIRING.md rule #4)

- Single-object `m` move → `lastsel == 1` after END, the deselect branch was already skipped;
  latch changes nothing. (test C1)
- A bare click on one of several selected objects (no `m`, no prior move) → no live
  STARTMOVE at the press → latch NOT set → cadence deselect-others still isolates as designed.
  (test D1)
- Copy placement (`c`/Shift+drag) commits on the press the same way → latch also protects it.

## Verification

- `tests/headless/test_connected_drag_keeps_selection_0113.tcl` 6/6 PASS; RED-first: pre-fix
  A2/B1/B2 fail (selection collapses to 1), C1/D1 stable across the fix.
- No regression: test_cadence_stretch_move, test_drag_keeps_selection (6/6),
  test_rotate_stretch_reconnect (17/17), wireedit 56/56, golden regression 0 fail.
- memcheck: definite-leak set byte-identical to the load-only baseline (4,728 B / 5 blocks =
  the documented cairo/resetwin teardown) — the fix adds no allocations.
