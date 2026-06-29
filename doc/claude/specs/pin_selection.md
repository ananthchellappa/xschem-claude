# Spec: selectable instance pins

Branch: `fluid-editing`. Status: **IMPLEMENTED (2026-06-28), pending manual GUI
test.** Companions: analysis `../code_analysis/pin_selection_analysis.md` (its §0
has the as-built notes + verified file:line map), implementation plan
`../suggestions/pin_selection_plan.md` (§0.1 lists the refinements). Headless
regression: `tests/pin_select.tcl`.

## 1. Goal

Let the user select an **individual pin of a placed instance** — not just the
whole instance — behind a user-controllable on/off toggle, with the selection
highlight rendering correctly on the selected pin. This is the foundation for
later pin-level features (probing, pin-property inspection, net operations); it
is intentionally a *minimal, inert* selection capability, not an editing one.

## 2. Background

Today the selectable object classes are wire, line, rect, instance (`ELEMENT`),
text, polygon, arc. Several support **sub-part** selection — wire/line
endpoints, rect corners, and (the direct model here) **polygon vertices** via a
per-vertex `selected_point[]` array plus a `SELECTED1` "partial" summary bit. An
instance has only whole-object selection; its pins — `xRect`s on the symbol's
`PINLAYER`, locatable in schematic space via `get_inst_pin_coord()` — are not
independently selectable. This spec adds that, mirroring the polygon model.

## 3. Ratified decisions

- **D1 — pins are INERT in edits.** Selecting a pin sets selection state, renders
  a highlight, and is queryable from Tcl. It MUST NOT participate in move, copy,
  cut, delete, stretch, rotate, or flip. Those operations ignore pin selections
  entirely. (Chosen over "pins participate in edits", which roughly doubles the
  work; deferred to a future spec if ever needed.)
- **D2 — click priority = tight radius, else instance.** When the toggle is on, a
  click selects a pin only if the cursor is within a small snap radius of that
  pin's point; otherwise the whole instance is selected exactly as today. (Chosen
  over a modifier-key chord and over "toggle fully replaces instance selection",
  for discoverability with no regression to instance selection.)
- **Toggle default OFF.** The feature is opt-in; with the toggle off, behavior is
  byte-for-byte today's behavior.

### 3.1 Revision (2026-06-28) — gesture, marker, properties viewer

Manual GUI testing of the first cut surfaced three follow-ups, now ratified:

- **D3 — click selects a pin, drag-from-a-pin draws a wire.** With the toggle ON, a
  *plain click* (press+release, no motion) on a pin **selects the pin** and does NOT
  enter wire-drawing mode. A *press+drag* starting on a pin still draws a wire (the
  legacy `add_wire_from_inst` behavior, now deferred to the drag). Disambiguation is
  by `xctx->mouse_moved` at button release. With the toggle OFF, the legacy
  click-starts-a-wire behavior is unchanged. (Supersedes D2's "click selects the pin
  *or* the instance" — when ON, a pin click never starts a wire.)
- **D4 — the selected-pin marker is a box + diagonal cross (X) in the SELECTION
  colour.** A selected pin draws a small **box + X** centred on the pin point, stroked
  in `gc[SELLAYER]`. (First tried `gc[PINLAYER]` to "stand out", but pins are usually
  drawn in PINLAYER — typically **red** — so the marker was invisible on the pin.
  Corrected 2026-06-28.) The box+X *shape* is what distinguishes a selected pin from a
  whole-instance outline; the colour just has to contrast with the pin, which the
  selection colour does by construction.
- **D5b — pin selection works in a READ-ONLY view.** Selecting a pin is inert (no
  edit), and inspecting/probing pins is exactly what browse mode is for, so the
  click-to-select path is NOT gated on `!readonly`. In a read-only view the click
  selects the pin immediately (no wire is possible); crucially it must NOT call
  `start_wire()`, whose `readonly_block()` would pop a modal "View is Read Only"
  dialog on every pin click. Wire-drawing (the drag) remains blocked in read-only.
- **D5 — `Q` (Edit Properties) on a selected pin opens a READ-ONLY viewer.** Showing
  the instance name, **pin name**, **direction** (`dir` = input/output/inout), and the
  connected net — all fields greyed/disabled, since a pin on an instance is not
  editable. Consistent with the read-only Properties viewer pattern already used for
  read-only schematics (issue 0051).

## 4. User-facing behavior (requirements)

### 4.1 The toggle
- A boolean option **"Enable pin selection (click a pin to select it)"** lives in
  the top-level **Options** menu (next to "Enable stretch"), bound to the mirrored
  C/Tcl variable `en_pin_select` (default `0`). (It was first added under
  View → Show/Hide, which proved undiscoverable — moved to Options 2026-06-28.)
- Scriptable: `xschem set en_pin_select {0|1}` sets it; the Tcl variable reflects
  the state for the menu. Users who want it always on can add `set en_pin_select 1`
  to their rc (e.g. `src/cadence_style_rc`).
- While OFF, no pin is ever selectable and there is **no observable change** from
  current behavior (including click behavior over pins).
- Pin hit-testing uses the **raw cursor** position (not the snapped one) with a
  zoom-scaled radius, so a pin off the snap grid is still selectable.

### 4.2 Selecting a pin (mouse)
- With the toggle ON, a left-click whose cursor is within the tight snap radius
  of a pin point selects **that pin only** — the enclosing instance is not
  selected.
- A left-click on the instance body (outside any pin's radius) selects the
  **whole instance**, as today.
- The tight radius scales with zoom (derived from the existing snap/pick
  distance), so pins remain clickable at any zoom without stealing ordinary
  instance clicks.
- Rubber-band / area selection picking up pins is **optional for v1** (may ship
  click-only first); if implemented it mirrors the polygon-vertex area rule.

### 4.3 Selecting a pin (script)
- `xschem select pin <instance> <pinindex>` selects pin `pinindex` of the named
  instance; the `unselect`/`clear` form deselects it. Returns success/failure
  like the existing `xschem select instance` form. This exists primarily so
  regression tests can drive the feature headless.

### 4.4 The selection highlight
- A selected pin draws a small handle/marker centered exactly on the pin point,
  in the selection color (the `SELLAYER` GC), visually consistent with existing
  selection handles.
- The marker lands **exactly on the pin** for instances that are rotated and/or
  flipped (the highlight goes through `get_inst_pin_coord`, which applies the
  instance transform).
- The highlight **survives** pan, zoom, and full redraws (it is rebuilt from
  selection state every redraw, like every other selected object).
- Deselecting the pin (clicking empty space, ESC, "select none", or the script
  unselect) clears the marker cleanly with no leftover pixels.
- Multiple pins (on the same or different instances) may be selected at once,
  each highlighted independently.

### 4.5 Interaction with edit operations (D1)
- With one or more pins selected and **no** whole object selected, Delete, Move,
  Copy, Cut, Stretch, Rotate, and Flip do **nothing** — pin selections are inert.
- An instance that has pins selected but is not itself wholly selected is **not**
  treated as a movable/deletable instance.

## 5. Non-goals (explicit)

- Moving, deleting, copying, or otherwise editing pins.
- Persisting pin selection in `.sch`/`.sym` files (selection is transient).
- Dragging attached wires from a selected pin.
- Any change to netlisting, the file record format, or symbol definitions.

## 6. Acceptance criteria

Functional / headless (regression test, see plan §4):
- [ ] `xschem set en_pin_select 1` then `xschem select pin <inst> 0` results in a
      selection containing exactly that pin; `xschem unselect all` empties it.
- [ ] With the toggle off, the pin-select path is inert and instance selection is
      unchanged (golden output identical to baseline).

Manual / visual (the suite cannot assert pixels):
- [ ] Toggle OFF: clicking a pin selects the whole instance (no regression).
- [ ] Toggle ON, click on a pin point: only the pin highlights.
- [ ] Toggle ON, click instance body away from pins: whole instance selects.
- [ ] Pin highlight lands on the pin for a **rotated + flipped** symbol.
- [ ] Highlight survives pan / zoom / redraw; deselect leaves no residue.
- [ ] With a pin selected, Delete / Move / Copy do nothing to the instance.
- [ ] No allocation leak across repeated select/deselect
      (`xschemtest.tcl -d 3 -l log`).

## 7. Design summary (see plan for the step-by-step)

Per-instance pin-selection state `unsigned char *pin_sel` on `xInstance`
(length = symbol pin count, lazily allocated, transient) plus reuse of the
`SELECTED1` bit in `inst.sel` as the "has selected pins" summary — the exact
polygon `selected_point[]` model. A new selection type code `INST_PIN` carries
`(instance, pinindex)` through `sel_array`. Wiring touches five known sites —
`find_closest_obj`/new `find_closest_pin` (toggle-gated, tight threshold),
`select_object`/new `select_pin`, `rebuild_selected_array`, `draw_selection`,
`unselect_all` — plus the toggle plumbing and the `xschem select pin`
subcommand. Edit ops are made pin-safe by a switch-default audit (D1). Full
file/function touch-list and code sketches: `claude_suggs/pin_selection_plan.md`.
