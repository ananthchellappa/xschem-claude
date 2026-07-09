# Rotate / flip that keeps wires connected during a stretch

## Status
Branch `fluid-editing`. Written 2026-07-09.

- **Cases 1, 2, 3 — IMPLEMENTED + tested (UNCOMMITTED).** Prompt-for-object rotate/flip.
  New `MENUSTARTROTATE` ui_state2 bit + `xctx->menu_pending_transform` (PENDING_TR_* codes),
  armed in the 6 rotate/flip key handlers (R/Alt-R/F/Alt-F/V/Alt-V) when the selection is
  empty, consumed by a new branch in `check_menu_start_commands` (callback.c). Case 3 falls
  out naturally: firing a rotate verb reassigns `ui_state2`, abandoning a pending `m`
  verb-noun stretch. Available always (no `cadence_compat` gate, Decision 6).
  Test `tests/headless/test_rotate_prompt_object.tcl` — 20/20 PASS under X, sabotage-verified
  (neutering the consumer select flips T2b/T3c/T4b red; neutering the arm flips T2b/T3c red).
  No regressions in adjacent tests (verb_noun_copy_move, drag_keeps_selection,
  undo_move_keep_selection, fluid_reversal_0096 all PASS). Pre-existing unrelated failures:
  cadence_drag ×2 (detached-drag wire asserts), select_at SA8b (shift-click add-logging).
- **Case 4 — NOT started** (the connected-stretch rotate reroute; the hard part below).

Scope note: prompt-for-object arming lives in the callback.c KEY handlers only (interactive
"fire the rotate command"), NOT the scheduler subcommands — a menu `xschem rotate` with an
empty selection still no-ops (unchanged), and scripted `xschem rotate x0 y0` replay is
untouched. Menu-path prompt is a possible follow-up.

Companion to:
- `doc/claude/specs/cadence_stretch_move_keys.md` (the `m`/`Shift+M` stretch/move verbs)
- `doc/claude/specs/nice_drag_rerouting.md` + `doc/claude/specs/incremental_wire_reroute.md`
  (the fluid keep-connected reroute engine this feature extends)
- `doc/claude/specs/fluid_editing.md` (the `fluid_editing` toggle that gates all live reroute)

## Goal

Let **rotate** (and, by parity, **flip**) participate in a connected move, so that a
**stretch-in-progress that is rotated re-establishes the same electrical connections
afterward** by rerouting wires — mirroring Cadence Virtuoso Stretch, where rotating the
grabbed object keeps its net attachments and bends the rubber wires to follow.

Rotate keeps connections **only** during an in-progress connected move (stretch). In every
other situation rotate behaves exactly as today (rotate geometry, ignore wire connectivity).

## Current behavior (grounded)

All facts below are from the source as of this branch HEAD; file:line cited so the reviewer
can check.

1. **Rotate/flip are not standalone ops.** Every variant funnels through `move_objects()`
   (`src/move.c:5094`) or `copy_objects()` (`src/move.c:664`) via the flag bits
   `ROTATE=64`, `FLIP=128`, `ROTATELOCAL=2048` (`src/xschem.h:321-332`). Fired via 5 scheduler
   subcommands — `rotate`, `rotate_in_place`, `flip`, `flip_in_place`, `flipv`
   (`src/scheduler.c:7455-7505, 1772-1838`) — and 5 keys: `Shift-R` rotate, `Alt-R`
   rotate_in_place, `Shift-F` flip, `Alt-F` flip_in_place, `V` flipv
   (`src/callback.c:5027-5059, 4533-4569, 5233-5281`).

2. **Rotate always acts on the current selection; there is no prompt-for-object path.**
   The standalone branch does `rebuild_selected_array()` then
   `move_objects(START|ROTATE|END)`; an **empty selection is a silent no-op**
   (`src/move.c:5121-5128`). Nothing today asks the user to click an object to rotate.

3. **Rotate already works mid-move.** When `ui_state & STARTMOVE` (or `STARTCOPY`) is set,
   the rotate/flip commands call `move_objects(ROTATE,0,0,0)` (or `copy_objects(ROTATE)`)
   **without** START/END (`src/scheduler.c:7466-7467`; `src/callback.c:5046-5047` etc). Each
   ROTATE does `move_rot=(move_rot+1)&0x3`; each FLIP toggles `move_flip`; these **accumulate**
   across keypresses within one gesture and are baked into stored geometry only at the END
   commit (`src/move.c:5244-5254`, commit at `5706-5726`).

4. **A "stretch" is a `STARTMOVE` whose `stretch_select` is set.** There is no distinct
   `STARTSTRETCH` ui_state bit. `select_attached_nets()` (`src/select.c:1579`) is the single
   funnel that makes a move connected: it sets `xctx->stretch_select=1` (`select.c:1589`) and
   partial-selects (`SELECTED1`/`SELECTED2`) the near endpoint of each wire touching a moved
   pin so those wires follow (`select.c:1617-1642`). A disconnected move simply skips
   `select_attached_nets()`. The verb-noun deferred pickup is flagged connected by
   `ui_state2 & MENUSTARTSTRETCH` (`src/xschem.h:279-281`), consumed in
   `check_menu_start_commands` (`src/callback.c:2133-2158`).

5. **The keep-connected reroute is translation-only, by explicit guard.** The live fluid
   reroute fires per RUBBER step only when
   `fluid_editing && (ui_state&STARTMOVE) && stretch_select && fluid_reroute_active
   && move_rot==0 && move_flip==0` (`src/move.c:5228-5229`; comment: *"Pure translation only
   (RUBBER never rotates; the rot/flip==0 test is a guard)."*). When it passes it recomputes
   the total translation delta, calls `fluid_reroute_restore()` (rolls all geometry back to a
   pristine snapshot taken at START — `move.c:5043-5055, 5162-5170`), and sets `commit_now=1`
   to fall through the shared commit block.

6. **The commit block is already rotation-aware — but only for a rigid transform.** It applies
   `ROTATION(move_rot,move_flip, pivot, coord)+delta` to every object, including both wire
   endpoints (`src/move.c:5417-5452`) and instances (`5706-5726`). END always runs
   `trim_wires`+`remove_move_orphan_wires` (`5779-5780`).

## Why Case 4 is not a one-line gate relax (the crux)

Relaxing the `move_rot==0 && move_flip==0` guard at `src/move.c:5228-5229` is **not
sufficient** and would produce broken geometry. Two independent load-bearing assumptions:

**(a) The anchored far endpoint of a follow-wire would be spuriously rotated.**
A stretch follow-wire is partial-selected: only the endpoint on the moving pin follows; the
far endpoint is anchored to a stationary object and must stay put. But the commit block rotates
**both** endpoints about the grab pivot and adds the drag delta only to the selected one
(`src/move.c:5427-5441`):

```c
ROTATION(move_rot, move_flip, x1,y1, wire[n].x1, wire[n].y1, rx1,ry1);
ROTATION(move_rot, move_flip, x1,y1, wire[n].x2, wire[n].y2, rx2,ry2);
if (wire[n].sel & (SELECTED|SELECTED1)) { rx1+=deltax; ry1+=deltay; }
if (wire[n].sel & (SELECTED|SELECTED2)) { rx2+=deltax; ry2+=deltay; }
```

With `rot==0` the `ROTATION` on the non-selected endpoint is the identity, so the anchored end
keeps its pristine coordinates — that is the *only* reason it stays pinned today. With
`rot!=0` the anchored end is displaced about the grab pivot, tearing it off its stationary
object; `place_moved_wire()` then routes to the moved-away point and the connection is lost.

**(b) Every reroute-quality layer is separately gated on `move_rot==0 && move_flip==0`.**
P1..P8 L-orientation selection (`src/move.c:1167`), `compute_wire_slide` (`5406`),
`fluid_shove_connected_wire`/`fluid_reroute_around_obstacles`/`fluid_offset_foreign_pin_landing`
(`5741`), and the END redundant-route cleanup (`5790-5791`) all switch off under rotation.
Relaxing only the outer gate silently disables short-avoidance, so a rotated stretch would emit
naive manhattan L-bends that can short across foreign nets.

**Consequence:** a rotation-capable reroute must (i) hold each follow-wire's anchored far
endpoint at its **pristine** coordinates (do not rotate it) while rotating only the moving-pin
endpoint, and (ii) make the P1..P8 / slide / shove / cleanup layers rotation-aware (or run them
after the moving pins reach their final rotated positions). This is the bulk of the work.

## Unified state model

The behavior is a function of two axes at the moment the rotate/flip verb fires:

| Selection / mode when rotate fires | Behavior |
|---|---|
| **A.** Nothing selected, no command mode | *Case 1* — arm "click an object to rotate", rotate the clicked object, **ignore** connectivity |
| **B.** Something selected, no command mode | *Case 2* — rotate selection, **ignore** connectivity (= today) |
| **C.** Disconnected move/stretch in progress (`STARTMOVE`, `stretch_select==0`) | *(missed)* rotate in-flight set, **no reroute** (= today) |
| **D.** Copy in progress (`STARTCOPY`) | *(missed)* rotate the copy, **no reroute** (= today) |
| **E.** Nothing selected, armed verb-noun stretch pending (`MENUSTARTMOVE|MENUSTARTSTRETCH`, no click yet) | *Case 3* — cancel the pending stretch, arm "click an object to rotate" (plain rotate) |
| **F.** Connected stretch in progress (`STARTMOVE`, `stretch_select==1`), `fluid_editing==1` | *Case 4* — rotate the moving set, **rip-up-and-reroute** follow-wires to re-establish the same net attachments |
| **G.** Connected stretch in progress but `fluid_editing==0` | *(missed)* rotate the moving set; connectivity restored only by the END `trim_wires` sweep (best-effort, = today). No live reroute. |
| **H.** Another tool mode (wire draw, place symbol, rect/line draw) | out of scope — current behavior unchanged |

Rows C, D, E, G, H are the cases not enumerated in the original request; they are included so
"in another command mode" in Cases 1–2 is precisely bounded.

## Design decisions (RESOLVED with reviewer 2026-07-09)

1. **Flip parity — YES.** Apply the same policy to `flip`/`flip_in_place`/`flipv` as to
   `rotate`. During a connected stretch, flip reroutes; elsewhere it ignores connectivity.
   Both funnel through the same `move_objects` FLIP path, so Rows F/G cover both.

2. **Pivot during a connected stretch — the GRABBED PIN, rigid, shared.** Rotate the whole
   moving set about the **grabbed pin** (the pin/tip the stretch grabbed), *not* the snapped
   mouse and *not* per object. The stretch already records the grab point — see
   `xctx->stretch_grabbed_xy` (freed at move END, `src/move.c:5997-6002`); the pivot must be
   the grabbed pin coordinate, captured at START, in place of the mouse-snap `xctx->x1,y1` used
   by an ordinary global rotate. If the grab did not land exactly on a pin, use the nearest
   grabbed tip; this is more predictable than the raw snapped mouse.

3. **In-place variants (`Alt-R`/`Alt-F`) mid-stretch — coerce to the shared grabbed-pin
   pivot.** For a multi-object selection, per-object `ROTATELOCAL` would scatter the pins and
   defeat the reroute, so it is coerced to a rigid rotate about the grabbed pin. For a
   single-object selection the distinction is largely moot; default it to the grabbed-pin pivot
   too, for consistency (reviewer accepted this as the sensible default).

4. **Case-4 gating — `fluid_editing==1` only.** The live rip-up-reroute path (Row F) runs only
   when `fluid_editing` is on. With `fluid_editing` off (Row G) rotate-during-stretch keeps
   today's behavior: rotate the geometry, and the END `trim_wires` sweep does **best-effort**
   cleanup. No live reroute, no rotate-blocking. (Reviewer: best-effort END trim, not block.)

5. **Case-1 / Case-3 rotate is PLAIN (ignore connectivity).** The prompt-for-object rotate arms
   a *disconnected* rotate: after the user clicks an object it is selected and rotated about the
   click point, with no attached-net grab. Case 3 abandoned the stretch, so there is nothing to
   keep connected.

6. **Prompt-for-object (Cases 1 & 3) is available ALWAYS**, regardless of `cadence_compat` — it
   is a strict superset of today's silent no-op on an empty selection. No profile gate.

## Proposed implementation

### Cases 1 & 3 — prompt-for-object rotate (new arming state)
- Add a `ui_state2` bit `MENUSTARTROTATE` (next free bit after `MENUSTARTSTRETCH=8192`,
  `src/xschem.h:264-281`) and, if flip parity wants its own prompt text, `MENUSTARTFLIP`.
  Store the pending transform (rot vs flip vs flipv, and the in_place bit) alongside — a small
  `xctx->pending_menu_transform` enum, since one bit cannot distinguish the 5 verbs.
- In the rotate/flip key handlers and scheduler subcommands, when the selection is empty **and**
  no move/copy gesture is live: instead of the silent no-op, set `ui_state|=MENUSTART`,
  `ui_state2|=MENUSTARTROTATE`, record the transform, and prompt
  `"Rotate: click an object to rotate"` (analogous to the move prompt at `callback.c:4750`).
- Extend `check_menu_start_commands` (`src/callback.c:2133-2158`) with a `MENUSTARTROTATE`
  branch: select the object under the click (`select_object`/`find_closest_*`), then run
  `move_objects(START|ROTATE|END)` about the click point. No `select_attached_nets` (plain
  rotate per decision 4).
- **Case 3** (Row E): when a rotate verb fires while `MENUSTARTMOVE|MENUSTARTSTRETCH` is armed
  but unclicked, clear those bits and the pending stretch state first, then arm
  `MENUSTARTROTATE`. Reuse the existing menu-abort/cleanup path used by ESC.
- ESC while `MENUSTARTROTATE` is armed cancels (mirror the move-verb ESC handling); a click on
  empty canvas cancels the arm (no object to rotate).

### Case 2 — unchanged
Already correct (`move_objects(START|ROTATE|END)` on the current selection). No code change.

### Cases C, D, G, H — unchanged
Rotate mid disconnected-move / mid-copy / non-fluid-stretch / other-tool-mode already do the
right thing (rotate the in-flight set / pending object, no reroute). Verify with tests; no code
change expected.

### Case 4 — rotation-aware connected reroute (the substantial work)
Target region: `move_objects()` in `src/move.c`, the RUBBER branch (`5220-5240`), the wire
commit (`5417-5452`), and the reroute-quality layers (`1167, 5406, 5741, 5790`).

0. **Pivot = grabbed pin, not snapped mouse (Decision 2).** During a connected stretch the
   rotation center passed to `ROTATION` in the commit block must be the grabbed-pin coordinate,
   not the mouse-snap `xctx->x1,y1` used by an ordinary global rotate. Capture the grabbed pin
   at START (the stretch already tracks `xctx->stretch_grabbed_xy`, `move.c:5997-6002`) and use
   it as the pivot for wires *and* instances whenever `stretch_select` is set. `ROTATELOCAL`
   (Alt-R/Alt-F) is coerced to this same shared pivot mid-stretch (Decision 3).

1. **Relax the outer RUBBER gate** (`move.c:5228-5229`) to also fire when `move_rot||move_flip`,
   so that after a rotate the live path runs `fluid_reroute_restore()` + commit-from-pristine.
   `fluid_reroute_restore()` is transform-agnostic (`move.c:5043-5055`) so restoring pristine
   then re-applying the accumulated `move_rot/move_flip/delta` is sound *for the moving pins*.

2. **Hold anchored follow-wire endpoints pristine.** In the wire commit (`move.c:5417-5452`),
   for a partial-selected follow-wire do **not** apply `ROTATION` to the non-selected (anchored)
   endpoint — keep its pristine coordinate. Only the moving-pin endpoint gets
   `ROTATION(...)+delta`. This is the fix for crux (a). (For a *fully* selected wire that is
   part of the rigid moving body, both endpoints still rotate as today.)

3. **Make the reroute-quality layers rotation-aware.** Remove the `move_rot==0 && move_flip==0`
   guards at `move.c:1167, 5406, 5741, 5790-5791` and confirm each layer operates purely on the
   final absolute endpoint positions (`rx1..ry2`), which are already rotated+translated by the
   commit block. Where a layer secretly assumes the moved delta is axis-aligned, feed it the
   composed final positions instead. This is where the review/verification risk concentrates.

4. **Repeated-rotate continuity (Row F, item 10).** Because the same restore-from-pristine +
   commit path now runs for every RUBBER/ROTATE step regardless of `move_rot`, rotating 4× back
   to 0° is just another step through the identical path — no special case. Verify no
   discontinuity at the `move_rot: 3->0` wrap.

5. **END commit + undo.** Unchanged: the accumulated transform bakes at END, one undo entry per
   gesture (`move.c:5277-5280` snapshot handling already covers this).

## Open questions — RESOLVED

All six answered 2026-07-09 (folded into Design decisions above):
1. Pivot → **grabbed pin** (not snapped mouse). Decision 2.
2. Flip parity → **yes**, flip/flipv reroute during a stretch. Decision 1.
3. In-place mid-stretch → **coerce to shared grabbed-pin pivot** (single object: same). Decision 3.
4. Prompt-for-object scope → **available always**. Decision 6.
5. Case-3 tail → **plain rotate**. Decision 5.
6. Non-fluid stretch → **best-effort END trim**, do not block. Decision 4.

Remaining implementation risk (not a user decision): making the P1..P8 / slide / shove /
cleanup layers rotation-aware (crux (b)) is the main verification surface.

## Test plan

Headless Tcl regression under `tests/headless/`, driving `xschem callback`
(pattern from `tests/headless/test_cadence_stretch_move.tcl`). Cases, each with a
sabotage-verify counterpart:

- **T1 (Case 2)** selection + `Shift-R` rotates geometry, no wire follows (baseline unchanged).
- **T2 (Case 1)** empty selection + rotate verb → armed prompt; click on an instance rotates
  just that instance; ESC cancels; empty-canvas click cancels.
- **T3 (Case 3)** arm `m` verb-noun (nothing selected) → fire rotate → pending stretch cleared,
  rotate armed; subsequent click rotates the clicked object without net-grab.
- **T4 (Case 4, translation baseline)** connected stretch, translate only, wires reroute
  (existing nice-drag coverage — regression guard).
- **T5 (Case 4, rotate)** connected stretch of an instance whose pin has an attached wire;
  rotate 90°; assert the follow-wire reconnects the rotated pin to the **unchanged** far
  endpoint with a valid Manhattan L, and the far endpoint did **not** move. Sabotage: force the
  anchored endpoint to rotate and assert the test flips red (guards crux (a)).
- **T6 (Case 4, no-short)** rotate a stretch where the naive L would cross a foreign net; assert
  the shove/offset layer still fires under rotation (guards crux (b)).
- **T7 (Case 4, 4×)** rotate 4× back to 0° mid-stretch; assert geometry equals the pure-
  translation result (guards item 10).
- **T8 (Rows C/D/G)** rotate during a disconnected move, a copy, and a `fluid_editing=0` stretch
  — assert no reroute path runs (behavior unchanged).
- **T9 (flip parity)** repeat T5 with `Shift-F` if Decision 1 is confirmed.

Each stretch/rotate test needs KeyPress + MOTION + drop against a controlled fixture (per the
`cadence-stretch-move-keys` memo: a controlled fixture beats `wires_moved` under autotrim).
