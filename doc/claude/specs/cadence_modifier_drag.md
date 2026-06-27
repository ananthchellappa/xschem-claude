# Cadence-style modifier-drag on objects (when `cadence_compat` is set)

**Status:** specification + code analysis + RED-first plan. **No code changed yet.**
**Branch:** `fluid-editing`.

This doc specifies the left-button drag gestures a Cadence user expects, scopes them
to the `cadence_compat` setting, maps each onto the existing xschem edit machinery,
identifies the one real gap, and lays out an atomic, test-first plan.

**Companion docs (read for the wire-follow mechanism, not repeated here):**
- `doc/claude/code_analysis/wire_follow_stretch_move.md` — how `select_attached_nets()` /
  `place_moved_wire()` / orthogonal rubber-banding work, with line refs.
- `doc/claude/code_analysis/wire_editing_spec_and_plan.md` — the wire-follow bug breakdown
  (issues A–G, the *quality* of an attached move). **Routing/connection quality is
  out of scope here** — this doc only governs *which intent each gesture maps to*.

---

## 1. The spec (normative)

When `cadence_compat` is **on**, a left-mouse-button (Button1) click-drag that starts
**on an object** (instance, wire, or any graphical object / text) behaves as:

| Gesture | Intent | Meaning |
|---|---|---|
| **LMB drag** (no modifier) | **attached move** | the object moves and **wires stay connected** — attached nets rubber-band along. |
| **Ctrl + LMB drag** | **detached move** | the object moves; wires are **left behind** (plain move, no wire-follow). |
| **Shift + LMB drag** | **copy** | a duplicate of the object is dragged off; the original stays put. |

Notes / edge cases:
- **Plain click (no drag) on an object** = select it (unchanged; the move is aborted
  if the pointer didn't move — see `handle_button_release`). The "attached move" only
  begins once the pointer actually drags.
- **Ctrl+Shift + LMB drag** = copy (Shift wins; copy is inherently detached). Not a
  distinct gesture.
- This is the **inverse default** of stock xschem, where wire-follow is opt-in via
  `enable_stretch` and a plain drag leaves wires behind. Under `cadence_compat` the
  *attached* move is the no-modifier default and Ctrl is the escape hatch to the
  detached move — matching Virtuoso, where Move keeps connectivity and you reach for
  a modifier to break it.
- Requires the **intuitive interface** (`intuitive_interface`, default `1`) — that is
  what makes click-drag-on-object start a move at all. `cadence_compat` must imply /
  assume it (see Plan Phase 0).
- "Attached move" here means the **stretch** path (`select_attached_nets()`): wires
  whose endpoint lands on a moved instance pin follow. How *well* it follows (T-junctions,
  sub-grid endpoints, orthogonal re-routing) is the companion wire-follow work and is
  **not** gated by this spec.

---

## 2. How the existing code already does most of this

The whole gesture→intent decision lives in **one block** in the Button1-press path,
gated on the intuitive interface:

`src/callback.c:5236` (inside `handle_button_press`, the
`if(sel.type && xctx->intuitive_interface && xctx->lastsel >= 1 && !shape_point_selected)`):

```c
/* enable_stretch (TCL var) reverses command if enabled:
 *   move --> stretch move ;  stretch move (with ctrl) --> move */
int stretch = (state & ControlMask ? 1 : 0) ^ enable_stretch;   /* :5243 */
xctx->drag_elements = 1;
if(stretch && !(state & ShiftMask)) {
  select_attached_nets();                       /* wires follow */
}
if((state & ShiftMask) && stretch) {            /* Shift + stretch */
  xctx->connect_by_kissing = 2;
  move_objects(START,0,0,0);
}
else if(state & ShiftMask) copy_objects(START); /* Shift only -> copy */
else move_objects(START,0,0,0);                 /* plain -> move */
```

Helpers: `select_attached_nets()` `src/select.c:1317`; `move_objects()`
`src/move.c:1143`; `copy_objects()` `src/move.c:600`; `connect_by_kissing()`
`src/actions.c:1163`.

Completion is in `handle_button_release` (`src/callback.c:5358`+): `STARTCOPY` ⇒
`end_move_copy_logged(1)`; `STARTMOVE` ⇒ abort if no motion else
`end_move_copy_logged(0)`. **No release-side change is needed** — copy vs move is
already distinguished there by the `ui_state` bit the press path set.

### What `cadence_style_rc` produces today

`src/cadence_style_rc` sets `cadence_compat 1`, `enable_stretch 1`,
`orthogonal_wiring 1` (and leaves `intuitive_interface` at its default `1`). Tracing
the block above with `enable_stretch = 1`:

| Gesture | `stretch` | Branch taken | Result today | Spec wants | Match? |
|---|---|---|---|---|---|
| plain | `0^1 = 1` | `select_attached_nets()` + `move_objects` | **attached move** | attached move | ✅ |
| Ctrl | `1^1 = 0` | `move_objects` only | **detached move** | detached move | ✅ |
| Shift | `0^1 = 1` | `connect_by_kissing=2` + `move_objects` | **kissing-connect MOVE** | **copy** | ❌ |
| Ctrl+Shift | `1^1 = 0` | `copy_objects` | copy | copy | ✅ |

So with the rc loaded, **plain = attached move and Ctrl = detached move already work**
(this is the XOR coincidence of `enable_stretch=1`). **The single real gap is Shift:**
it currently starts a kissing-connect *move*, and *copy* has migrated onto Ctrl+Shift.

### Two structural problems with relying on that coincidence

1. **Behavior is tied to `enable_stretch`, not `cadence_compat`.** A user who sets
   `cadence_compat 1` but not `enable_stretch 1` gets the stock mapping (plain =
   detached, Shift = copy) — the spec's plain-drag attached move silently doesn't
   happen. The spec says the mapping follows `cadence_compat`.
2. **Shift is wrong** even with the rc (copy is the headline Cadence gesture and it's
   not on Shift).

---

## 3. Design decision

When `cadence_compat` is on **and** the intuitive direct-drag block is entered, replace
the `enable_stretch`-XOR dispatch with an explicit, modifier-driven mapping:

```c
if(cadence_compat) {
  xctx->drag_elements = 1;
  if(state & ShiftMask) {                 /* Shift (± Ctrl) = copy */
    copy_objects(START);
  } else if(state & ControlMask) {        /* Ctrl = detached move */
    move_objects(START,0,0,0);
  } else {                                /* plain = attached move */
    select_attached_nets();
    move_objects(START,0,0,0);
  }
} else {
  /* ...existing enable_stretch XOR block, unchanged... */
}
```

Rationale:
- **Independent of `enable_stretch`.** Plain drag calls `select_attached_nets()`
  directly, so the attached move happens whenever `cadence_compat` is on, regardless
  of the `enable_stretch` var. (`enable_stretch`/`orthogonal_wiring` continue to govern
  *routing quality* downstream via the wire-follow machinery — out of scope here.)
- **Reuses the existing seams** (`select_attached_nets`, `move_objects`,
  `copy_objects`) and the existing release-side completion — no new lifecycle.
- **Smallest blast radius:** the non-`cadence_compat` path is byte-for-byte unchanged,
  so default xschem behavior and every existing test are untouched.

**DECIDED (2026-06-18):** the plain cadence move uses **`select_attached_nets()` only**
(endpoint-on-pin follow). **T-junction / mid-span (`connect_by_kissing`) following is
deferred** to the companion wire-follow plan — not special-cased here.

### Plumbing

`handle_button_press` (`src/callback.c:5005`) does **not** currently receive
`cadence_compat` (its siblings `handle_button_release` / `handle_double_click` do).
Add the parameter and pass it at the call site (`src/callback.c:5741`), sourcing it
from the already-read `cadence_compat` local (`src/callback.c:5614`). (Reading
`tclgetboolvar("cadence_compat")` inside the block is the lazier alternative; passing
the param matches the sibling handlers and is preferred.)

---

## 4. RED-first plan (atomic)

Each phase: write the failing test first, confirm it RED for the right reason, make it
GREEN with the smallest change, sabotage-verify, then run the move/select regressions.

**Test seam.** Drive the real dispatch through `xschem callback .drw <event> <x> <y>
<keysym> <button> <aux> <state>` exactly as `tests/headless/test_gesture_bindings.tcl`
does (event: `4`=ButtonPress, `6`=MotionNotify, `5`=ButtonRelease; `state` carries the
modifier mask — `ShiftMask=1`, `ControlMask=4`; Button1 = button `1`). Gesture =
press-on-object → motion (>5px so `mouse_moved` sets) → release. These tests need
`DISPLAY` (GUI); mind WSLg fresh-process flakiness — always `cd src`, check exit 0.

Fixture: a tiny schematic with one instance whose pin sits on a wire endpoint, plus a
known instance/wire count, so each assertion is a count/coordinate check via
`xschem get instances`, `xschem objects`, wire endpoint coords, and selection queries.

- **Phase 0 — `cadence_compat` forces the intuitive interface (DECIDED: force).**
  When `cadence_compat` is on, the press/select/drag gestures in `handle_button_press`
  run as if `intuitive_interface` were on, regardless of the var — so cadence mode is
  self-contained even if a user sets `intuitive_interface 0`. Implementation: a local
  effective flag `int intuitive = xctx->intuitive_interface || cadence_compat;` used
  by the intuitive gates in `handle_button_press` (`:5173 :5196 :5201 :5207 :5219
  :5237`). Test: with `cadence_compat 1` **and `intuitive_interface 0`**, a press-drag
  on an instance starts a move (`ui_state & STARTMOVE`).

- **Phase 1 — plumb `cadence_compat` into `handle_button_press`.** Pure refactor:
  add the param + pass it; no behavior change. Green = existing suites still pass.

- **Phase 2 — Shift = copy (the real gap). ✅ DONE.** RED: with `cadence_compat 1`
  + `enable_stretch 1`, Shift+drag on an instance must **increase the instance count
  by one**. Today it does a kissing move (count unchanged) → RED (sabotage-verified).
  GREEN: guard the kissing-move branch with `!cadence_compat` (`callback.c:5254`) so
  Shift falls through to `copy_objects(START)`. Test
  `tests/headless/test_cadence_drag.tcl` (click the instance **bbox center** via
  `xschem get bbox_selected`, not the placement anchor — the anchor can sit off-body).
  Gesture suites unaffected (the branch is identical when `cadence_compat 0`).

- **Phase 0 — cadence_compat forces the intuitive interface. ✅ DONE.** Effective
  flag `int intuitive = xctx->intuitive_interface || cadence_compat;` introduced in
  both `handle_button_press` and `handle_button_release`, replacing the six/three
  `xctx->intuitive_interface` gates. Test: with `cadence_compat 1` + `intuitive_interface
  0`, a plain press-drag moves the instance. Sabotage-verified (drop the `||
  cadence_compat` → reddens only that check).

- **Phase 3 — plain drag = attached move, independent of `enable_stretch`. ✅ DONE.**
  The explicit `cadence_compat` branch (spec §3) calls `select_attached_nets()` on the
  no-modifier path, so a plain drag of a wired gate carries its wires even with
  `enable_stretch 0`. RED with stock code (stretch=0 → wire left behind);
  sabotage-verified (drop `select_attached_nets()` → reddens only that check).

- **Phase 4 — Ctrl drag = detached move. ✅ DONE (guard, green on arrival).** With
  `cadence_compat 1`, Ctrl+drag moves the gate but no wire follows and the instance
  count is unchanged. Guards the inverse of Phase 3.

- **Phase 5 — no regression off the cadence path. ✅ DONE.** With `cadence_compat 0`
  + `enable_stretch 0`, plain drag is a stock detached move (instance moves, wires
  left behind). Existing `test_gesture_bindings` / `test_gesture_end_log` /
  `test_hover_selection_repair` still pass (the latter two flaky under WSLg — 3/3 on
  re-run). The non-cadence branch is byte-identical to the original XOR dispatch.

**Implementation note:** Phases 0/3/4 landed together via the explicit `cadence_compat`
branch of the dispatch (spec §3), which subsumed the minimal Phase-2 `!cadence_compat`
guard. All five behaviors live in `tests/headless/test_cadence_drag.tcl`.

**Sabotage checks:** force the Shift branch to `move_objects` (Phase 2 reddens);
delete the `select_attached_nets()` call (Phase 3 reddens); force plain to
`select_attached_nets` under Ctrl (Phase 4 reddens).

---

## 5. Files in scope

- `src/callback.c` — `handle_button_press` dispatch block (`:5236`–`:5259`), its
  signature (`:5005`) and call site (`:5741`); possibly `cadence_compat`→
  `intuitive_interface` coupling.
- `src/cadence_style_rc` — already sets `cadence_compat 1`; confirm/add
  `intuitive_interface 1` per Phase 0 decision.
- `src/xschem.tcl` — `cadence_compat` default (`:12042`); no mirrored-C field needed
  (read via `tclgetboolvar`).
- `tests/headless/test_cadence_drag.tcl` — new suite (Phases 0–5).
- Docs: cross-link from `doc/claude/code_analysis/wire_editing_spec_and_plan.md`.

## 6. Out of scope (explicitly)

- Wire-follow *quality* (T-junctions, sub-grid endpoints, orthogonal re-routing) —
  owned by `wire_editing_spec_and_plan.md` (issues A–G).
- Non-intuitive (`intuitive_interface 0`) interface gestures.
- Changing stock (non-`cadence_compat`) defaults.
