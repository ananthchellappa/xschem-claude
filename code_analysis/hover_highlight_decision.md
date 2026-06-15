# Hover ("awareness") highlight — design + decisions

**Status:** DONE 2026-06-15 — D2 = on by default; D3 = all drawable types. RED
`7600a024` / GREEN `0a2e8def`. Headless suite `tests/headless/test_hover_highlight.tcl`
8/8; core regression + gesture + property_form suites green. **Manual eyeball PASSED**
on the real display ("works perfectly", user) — pixels + unfocused-window tracking
confirmed. Tutorial: `code_analysis/hover_highlight_tutorial.md`. Branch ready to merge.
**Branch:** `feature/hover-highlight` (off `slick-property-forms`).
**Goal:** Cadence-style awareness cue — when the tracking cursor is over an
object, outline it with a **mild dashed yellow** line (minimum, config-controlled
weight). Must update **even when the schematic window is not focused** (pointer in
the canvas, another app window active).

---

## 1. Characterization (verified this session)

- **Motion path:** Tk's `<Motion>` binding on the canvas fires `xschem callback …`
  → `callback()` → motion handling (`src/callback.c`, `handle_motion` region from
  ~`:3254`). `xctx->mouse_inside` is set 1 on motion (`:3254`), 0 on `<Leave>`
  (`:5619`). **Focus-independent by construction:** X11 delivers `MotionNotify` to
  the window under the pointer regardless of keyboard focus, so the binding fires
  while another window is active — the existing **crosshair already updates
  unfocused** through exactly this path (gated only by `mouse_inside`). The
  headline requirement therefore needs no special plumbing; we just hook the same
  motion path.
- **What is under the cursor:** `find_closest_obj(mx, my, override_lock)`
  (`findnet.c:506`, returns a `Selected {type, n, col}`) is the existing hit-test
  used by click-selection (`callback.c:5092`). Reuse it verbatim.
- **Per-motion transient drawing (the model to copy):** `draw_crosshair()`
  (`callback.c:1730`) draws **window-only** (`xctx->draw_pixmap = 0;
  draw_window = 1`) so the mark never enters the backing `save_pixmap`; it **erases
  the previous mark by re-stamping the background** with `xctx->gctiled` (a GC
  tiled from `save_pixmap`) over the old shape, then re-strokes `draw_selection`
  so the erase didn't wipe the selection overlay. It tracks `prev_crossx/y` to know
  what to erase next time. This is the established, performant per-motion pattern —
  no full `draw()` per event.
- **Per-type outline geometry (reuse):** `draw_scope_highlight()` (`draw.c:5363`)
  already strokes any of the 7 drawable types in its natural shape with a dedicated
  GC (`gc_scope`): ELEMENT→no-text bbox, WIRE→segment, rect/line/poly/arc via
  `gfx_index_from_id`, text→`text_bbox`. The hover renderer is the same dispatch,
  but keyed off a single hovered object (by index, resolved fresh each motion — no
  stable-id needed, the object is re-found every motion) and stroked with a new
  `gc_hover`.
- **Dedicated GC pattern (reuse):** `gc_scope` is created in `xinit.c`
  (`create_gc`/`free_gc` ~`:459/:469`) and colored/sized in `build_colors`
  (`xinit.c:1089`) from Tcl vars `slickprop_highlight_color/_width` via
  `find_best_color` + `XSetLineAttributes`. Hover gets a sibling `gc_hover`, set
  **dashed** (`LineOnOffDash` + `XSetDashes`) yellow.

## 2. Drawing mechanism (D1 — implementer's call, recorded for review)

**Chosen: window-only overlay, crosshair-style (NOT a full `draw()` per motion).**
On each motion, find the closest object; if it differs from the
currently-hovered one: erase the previous hover outline (re-stamp via `gctiled`
over its old shape, then re-stroke selection + scope overlays so they survive),
then stroke the new outline with `gc_hover` to the window only. Track the
previously-hovered object (index + a small descriptor so we can re-derive its
shape to erase). Cleared on `<Leave>` and when suppressed (§4).

Rationale: hover fires on **every** mouse motion; a full `draw()` per
hover-change would jank large schematics and rapid sweeps. The crosshair already
proves the window-only approach is smooth and focus-independent. Cost: we must
re-stroke the other window-only overlays (selection, scope, crosshair) in the
right order after an erase — bounded, and `draw_crosshair` already shows the
shape of that code.

> Alternative considered — add hover to the end of `draw()` like
> `draw_scope_highlight` and call `draw()` on hover-change: far simpler, but a full
> redraw per hovered-object change is the wrong cost on big designs. Rejected for
> the default; the config var can disable hover entirely on slow setups.

## 3. Config variables (proposed — confirm names/defaults)

Mirroring the `slickprop_highlight_*` convention, **C↔Tcl mirrored** vars:

| Tcl var | Meaning | Default |
|---|---|---|
| `hover_highlight` | master enable (0/1) | **see D2** |
| `hover_highlight_color` | outline color | `yellow` (override e.g. `#ffd000`) |
| `hover_highlight_width` | line weight, screen px (0 = thinnest server line) | `1` (minimum, per request) |

Dash pattern: fixed (e.g. `{4,4}` on/off px) — not exposed as a var unless you
want it. Read in `build_colors` alongside the scope vars; re-read on change.

## 4. Behavior (defaults — flag any you'd change)

- **Active when idle, even unfocused** (the headline requirement): highlight
  whenever `mouse_inside` and not mid-gesture.
- **Suppressed during active gestures** (`xctx->ui_state != 0` — move/wire/copy/
  place/rubber-band) and while busy (`semaphore >= 2`, e.g. a modal): hover is an
  idle-awareness cue, not a drag decoration. It resumes when the gesture ends.
- **Stacks independently** with the selection highlight and the property-form
  scope highlight (distinct dashed-yellow; a selected or scope-outlined object can
  also show the hover cue). Draw order: base → selection → scope → crosshair →
  hover (hover on top, being the most transient).
- **Cleared** on `<Leave>` (pointer exits canvas) and on disable.

## 5. Open forks for ratification (STOP here)

- **D2 — default on or off?** Cadence ships it on. It is a new, always-present
  visual motion. Recommendation: **on**, trivially disable via `hover_highlight 0`
  in `xschemrc`/menu. (Your call — busier canvas vs. discoverable feature.)
- **D3 — which object types hover?** `find_closest_obj` returns all 7. Options:
  (a) **all drawable types** (instances, wires, rects, lines, polys, arcs, text) —
  closest to Cadence; (b) **instances + wires only** (the connectivity objects you
  usually point at; quieter on graphics-heavy symbols). Recommendation: **all**,
  since the geometry is already there and the cue is mild.

## 6. Test plan (RED-first, after ratification)

Headless-assertable in a new `tests/...` suite (or extend `property_form`-style):
- Hovered-object tracking: a synthesized `<Motion>` (`xschem callback .drw 6 …`)
  over an instance sets the hovered ref; moving off clears it. (Same
  `xschem callback`-drive used by PF64 and `tests/headless/test_gesture_bindings`.)
- Config: `hover_highlight 0` ⇒ no hovered ref recorded on motion; width/color
  vars reach `gc_hover` (assert via a getter or no-crash render).
- Suppression: with `ui_state` set (a gesture in progress) ⇒ no hover ref.
- **Focus-independence + the actual pixels = MANUAL EYEBALL** (WSLg can't drive a
  real unfocused-window pointer; dash/color/weight are visual). Eyeball checklist:
  hover an instance/wire/text → dashed yellow outline; move another app on top but
  keep the pointer in the canvas → highlight still tracks; width var changes
  weight; disable var removes it; no flicker on rapid sweeps; gesture suppresses it.

## 7. Recipe

Characterize (done) → this decision doc → **STOP for ratification (D2, D3, config
names)** → RED-first tests → implement (`gc_hover` in xinit.c + `build_colors`;
hover state in `xctx`; a `draw_hover_highlight`/erase pair in callback.c hooked
into the motion path next to the crosshair) → eyeball pass → resolve.
