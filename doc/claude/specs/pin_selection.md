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

### 3.2 Revision (2026-06-29) — multi-pin select + pin-aware deselect

Enhancement: (A) SHIFT+Click multi-pin selection, and (B) the deselect-one action also
clears a pin under the cursor.

- **STEP-1 FEASIBILITY — RATIFIED (already proven).** The keybind approach for a
  remappable "deselect one" action is **already shipped**: commit `3b9199b5` pulled the
  hardcoded `case 'd'` deselect OUT of the C key switch into the registered, remappable
  action **`edit.deselect_mode`** (C-backed `act_deselect_mode` → `enter_deselect_mode`;
  also the `xschem deselect_mode` subcommand), default-bound `key 100 0 canvas` in
  `keybindings.csv`, rebindable with `xschem bind key <keysym> <mods> canvas
  edit.deselect_mode`. The C `case 'd'` plain-deselect branch is **deleted** (only
  `Ctrl+d` = delete_files remains); the data-driven `DEV_KEY` dispatch runs at the TOP of
  `handle_key_press` and a bound chord short-circuits before the switch, so there is no
  C-vs-registry conflict. It is a **persistent mode** (press → click-loop → ESC), as the
  user specified originally (`doc/claude/specs/deselect_one_mode.md`). So Step 1's
  question — "can `d`/any key be assigned a deselect action through the bind command?" —
  is answered **YES, end-to-end, in shipped code**. This revision therefore does NOT
  re-migrate `d`; it only adds pin-awareness to that action's click (D7).

- **D6 — SHIFT+Click on a pin ADDS it to the selection (multi-pin).** With the toggle
  ON, a SHIFT+plain-click on a pin calls `select_pin(...)` **additively** — no
  `unselect_all`, no wire arming (it is a pure selection gesture). A plain (no-modifier)
  click still REPLACES (D3, unchanged). The data model already supports N selected pins
  (`xInstance.pin_sel[]`; `rebuild_selected_array` emits one `INST_PIN` per set bit;
  `lastsel` counts them) — verified — so this is a **gesture-only** change, no new
  per-instance heap state. Click-vs-drag is decided at release by `pin_press_x/y` (like
  D3), via a new scalar `xctx->pin_pending_add` flag (not heap, not per-instance):
  - **SHIFT+click** (no motion) on a pin → add that pin.
  - **SHIFT+drag** starting on a pin → **IGNORED** (pins are inert; nothing is
    copied/moved, no wire). The press is intercepted before the SHIFT cadence-copy path,
    so the underlying instance is NOT copied either.
  - **SHIFT+click-drag on a non-pin object** → still COPY (existing cadence_modifier_drag
    behavior, preserved — `find_closest_pin` misses, so the gesture falls through
    untouched).

- **D7 — the deselect-one action (D-mode click) also deselects a PIN under the cursor.**
  In `edit.deselect_mode`, a click whose cursor is within a pin's tight radius (toggle ON)
  AND that pin is currently selected → `select_pin(..., 0)` to clear **just that pin**,
  leaving other selected pins/objects intact; the mode persists. If no selected pin is
  under the cursor, the click falls through to the existing object deselect
  (`unselect_at_mouse_pos`). Pin takes priority over object (matching the select side).
  Read-only safe (deselect is inert; never calls `start_wire`). SHIFT+D area-deselect is
  untouched.

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
- **A click inside the pin's own drawn rectangle selects the pin too, at any
  zoom** (issue 1724, 2026-11-19; `point_in_inst_pin_rect()` in
  `src/findnet.c`, edges included). The radius is a distance on the screen,
  so zoomed far in it is smaller than the pin's square, and a click on the
  square's corner used to miss the pin it was plainly on. The rectangle is
  the symbol's pin-layer rectangle carried through the instance's rotation,
  flip and origin. At an ordinary zoom, where the radius covers the square,
  nothing changes.
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

### 4.6 Asking which pin is under a point, without selecting it (issue 1724, 2026-11-19)
- `xschem pin_at <x> <y> [-all]` answers the instance pin under the
  schematic-coordinate point, by the click's own hit rule: the pin's point is
  within `12 * zoom * tk scaling` of `(x,y)` (inclusive), or `(x,y)` is inside
  the pin's own drawn rectangle (§4.2); pins of a `lock=true` instance do not
  answer, and no pin answers while the pin layer is disabled.
- The plain form returns one row, `<inst> <pin> <instname> <pinname> <px> <py>`
  (instance and pin indexes, their names, the pin's own point), or the empty
  string when no pin is in range. A miss is not an error.
- Both coordinates must be numbers, each word whole: anything else answers
  the usage line `usage: xschem pin_at x y [-all]` as an error. So `-all`
  left in the y slot, `foo`, an empty word and `500x` are refused instead of
  being read as 0. (`strtod` takes `nan`, `inf` and hex words as numbers; a
  query at such a point answers nothing.)
- A pin whose distance from the point is not a number (a symbol file holding
  a `nan` pin coordinate) is out of range and never answers, in either form:
  the in-range test is the one `find_closest_pin()` had before the walk was
  shared.
- `-all` returns a list of such rows, one per pin in range, nearest first; at
  equal distance the lowest instance index, then the lowest pin index. Its
  first row is the plain form's answer. "Nearest" is the distance to the
  pin's point also for a pin reached through its rectangle, so the order is
  the same at every zoom. It is for a caller that must choose
  among pins sharing a point, such as a device pin a net label sits on.
- It is **read-only**: nothing is selected, drawn or logged, the modified flag
  and the undo stack do not move, and the netlist structures are not prepared.
- It does **not** depend on `en_pin_select`. §4.1's "while OFF, no pin is ever
  selectable" stands: the toggle governs selecting, and this selects nothing.
- Names are returned as list elements, so `x17[1:0]` and `A[3:0]` stay one
  element each; coordinates are printed with `%.16g`.
- One walk serves both: `pins_in_pick_radius()` (`src/findnet.c`) is called by
  `find_closest_pin()` and by `find_pins_at()`, the collector behind `-all`, so
  the radius, the lock rule, the pin-layer rule and the tie-break cannot differ
  between the click and the probe.
- Its first consumer is ASE-L's Select On Design, where a click on a device
  pin queues that terminal's current (`ase::ui::sod_terminal_at`;
  `doc/claude/specs/ase_l.md`, "A click on a device pin queues its terminal
  current"). That pick adds rules of its own on top of the rows: a bound of
  10 schematic units; a wire under the cursor, or within a pixel or two of
  it, wins off the pin's own square; and among device pins on one point the
  cursor's side of the point chooses (towards the middle of the device's
  pins, or of its symbol's box where a device's pins say nothing about its
  side), not `-all`'s order, which decides only on the point itself and
  where neither measure tells two devices apart. It uses the raw cursor as
  §4.1 says a pin test must.
  The Calculator's current selectors ask through the same proc.
- **Requested of the engine, not built** (issue 1724, open items). The rows
  of `-all` carry each pin's index and point, but only for pins in range of
  the cursor. To place ALL of an instance's pins that pick has to go by
  name (`xschem instance_pin_coord <n> name <name>`), and for a pin name a
  symbol uses twice (the shipped `examples/xcross.sym`) that verb answers
  the first pin of the name. So the pick claims nothing about such a
  symbol's pins. A verb that gives a pin's coordinates by index would lift
  that. A second request beside it: a read-only verb that prints an
  instance's box without its texts, which the pick now works out in Tcl
  from `xschem instance_bbox` and `xschem instance_coord`. A third, from
  the last build of that issue: `xschem pinlist <n> <attr>` writes each
  value between braces as it stands (`{ {<i>} {<value>} }`), and `xschem
  instance_pin_coord` the name the same way (`{<name>} <x> <y>`), so for
  a pin name that ends in a backslash (symbols of the gschem import
  library) neither answer is a list. Each should give the value as a
  list element, as `xschem pin_at` gives its names. Until then the pick
  asks `xschem pinlist <n> name` and, where that answer is no list, reads
  each name off the pin's attribute string; it reads the point off the
  end of the answer as text (`ase::ui::sod_term_pin_names`,
  `ase::ui::sod_term_pin_xy`). The list of the attribute strings is
  itself no list when one of them ends in a backslash, so it is asked
  second: a symbol with plain pin names and such an attribute is read by
  its names.
- **Which point a mode click asks about.** The raw cursor is the pointer the
  engine last heard of, and the engine takes the position of every event it
  is sent, a `<Configure>` of the canvas included (issue 1659). So the script
  each click mode binds on the press (Select On Design, the Calculator's
  pick, the Results Display Window's pick mode) first hands the engine the
  press's own position as a pointer motion, `xschem callback %W 6 %x %y 0 0 0
  %s`, and then runs the click: the pin test (and, in the Results Display
  Window's mode, the device test) is asked at the pixel that was pressed,
  whatever arrived since the last pointer motion
  (`ase::ui::sod_press_script`, `calc::_pick_seize`, `rdw::_pick_seize`).
  Group PS of `tests/headless/test_pin_marker_1724.tcl` presses on a pin
  after such an event with no motion in between.
- Suite: `tests/headless/test_pin_at_1724.tcl`, bands PA0–PA9. Band PA9 is
  the rectangle, on a fixture with the radius set below the pin's square: a
  point inside the square and outside the radius answers the pin on an
  unrotated, a rotated and a flipped instance; a point outside both answers
  nothing; the order is still by the distance to the pin's point; a locked
  instance and a disabled pin layer still answer nothing; and once the
  radius is wider than the rectangle the answers are the radius rule's
  alone.

### 4.7 Marking a chosen pin: `xschem pin_marker` (issue 1724, 2026-11-19)
A marker is a cue on an instance pin a caller has chosen: a thin, unfilled
ellipse centred on the pin's point, twice as tall as wide and upright on the
screen whatever the instance's rotation or flip, stroked in a layer's colour.
It selects nothing and has nothing to do with `en_pin_select`.

- `xschem pin_marker add ?-fast? ?-layer N? ?-tag T? <inst> <pin>`. The last
  two words are always the instance and the pin; the options come before
  them. `<inst>` is an instance name or index, as other commands take it.
  `<pin>` is a pin index or a pin name, and a word of digits is always an
  index. Default layer 16, default tag the empty string. Marking a pin that
  is already marked replaces its layer and tag. Answers 1 for a new marker
  and 0 for a replaced one. Errors, each one line: an unknown instance, an
  instance with no name, an unknown or out-of-range pin, a layer outside
  1 .. (number of layers − 1), which the default 16 is too when xschem runs
  with 16 layers or fewer.
- `xschem pin_marker remove ?-fast? <inst> <pin>` answers 1 when a marker was
  removed, else 0, and never errors: an instance word that resolves to
  nothing is taken as the marker's own name, so a marker left behind by a
  renamed or deleted instance can still be removed.
- `xschem pin_marker clear ?-fast? ?-tag T? ?-all?` drops every marker of the
  current window or tab, or with `-tag` only those carrying that tag; `-all`
  does so in every window and tab. Answers the number dropped.
- `xschem pin_marker list` answers one row per marker of the current window
  or tab, oldest first: `{path instname pin layer tag x y}`. `x y` is the
  pin's point, or two empty words when the marker is not on the sheet being
  shown (another hierarchy level, or its instance is gone).
- **The key** is (hierarchy path of the sheet shown when it was added,
  instance NAME, pin index), per window or tab. So the instance and pin
  given to `add` are those of the sheet shown; the marker survives a descend
  and the way back, an undo and a redo, and follows a moved, rotated or
  flipped instance; and an instance whose name is a number is found by name
  (the resolver walks names and never calls `get_instance()`). A marker that
  does not resolve on the sheet shown is skipped, not deleted.
- **Derived state.** It is not written to the file, takes no undo slot, is
  not part of the selection and never sets the modified flag. It is not
  written to the action log: the pick that caused it is what a replay
  repeats.
- **Who clears it.** `xschem pin_marker clear`; `xschem unhilight_all`,
  whatever the tag and whether or not a net is highlighted, for the current
  window or tab and for the windows and tabs linked to it by a descend
  (`pin_marker_clear_linked_windows()` in `src/hilight.c`: the contexts
  `net_hilight_prefix_related()` answers 1 for, which are the ones whose net
  colours the same command clears, in both directions; a context showing
  another document keeps its markers; and not while the current window is
  in the middle of a gesture, see Drawing below); and the doors that put
  another document into the window:
  `xschem load` in place (also of the same file), File > Open in place
  (`ask_new_file()`), `xschem clear` (`clear_schematic()`). Not `xschem
  reload`, not a descend or a return, not an undo or a redo. A `-gui` open
  that is routed to a new window leaves the current window's markers alone.
- **Drawing** (`draw_pin_markers()`, `src/draw.c`). `draw()` calls it right
  after the net highlights and before the pixmap is copied to the window, so
  the marker is in the backing pixmap and every overlay that erases itself by
  copying the pixmap back restores it. Half-width: the larger of 5 schematic
  units and `3 * zoom * tk scaling`; half-height: twice that. The stroke is 1
  pixel wide, 2 from a Tk scaling of 1.25 up, whatever the zoom. An ellipse
  wholly outside the drawing area is not sent, and neither is one whose box
  does not fit the 16-bit coordinates of the X protocol; the second is out of
  reach of the editor's own zoom limit and has no row. `add` draws;
  `remove` and `clear` draw when they dropped something; `-fast` draws
  nothing (row E4). `clear -all` repaints the other visible windows when one
  of them lost a marker; a hidden tab is repainted when it is next shown, and
  no other window is repainted while the focused one is in the middle of a
  gesture. `xschem unhilight_all` empties the linked windows' lists and
  leaves their repaint to the clear-through of the net colours, which stands
  down while the focused window is in the middle of a gesture
  (`net_hilight_ctx_gesturing()`). So given in the middle of a gesture the
  command leaves the linked windows' lists alone too: a linked window keeps
  its marker list, its ellipse and its net colours together, and the command
  given again once the gesture is over takes all three. (A list emptied
  during a gesture would leave an ellipse on a screen nothing repaints:
  measured before the guard, with a wire being drawn.) Rows PV1 and PV2.
  Every subcommand works without a display (state only).
- **Not drawn** by the SVG, PS and PDF exports.
- **Colour.** The layer's, in both colour schemes. Layer 16, the default, is
  `#bfff81` in the stock dark scheme and `#7ccc40` in the stock light one.
- **Callers.** ASE-L's Select On Design (`doc/claude/specs/ase_l.md` T11):
  `ase::ui::sod_mark_pin` (layer 16, tag `save`), the `terminal` arm of
  `ase::ui::dp_hilight` (the trace's layer, tag `plot`) and
  `ase::ui::sod_marks_clear` (`clear -tag save -all`).
- **The keys.** Under the stock bindings Shift+K is `xschem unhilight_all`
  and key `0` is not; under `src/cadence_style_rc` key `0` is, also while
  Select On Design is up, and the mode stays armed.
- Suite: `tests/headless/test_pin_marker_1724.tcl`. Bands E, U, H, C, F, L
  and T (the command, the clears, the key, derived state, the doors) and G
  (ASE-L's picks) run on both arms; band P (the pixels, the doors that need
  Tk, a real click and a real ESC) needs a display. Row E4 is which verbs
  redraw. Rows C8 and C9 are a context linked by a descend, in a new window
  and in a new tab, cleared from either side, beside C6's unlinked context
  that keeps its marker. Row T7 judges the LAST line of the profile that
  binds key `0` on the design canvas. On a display: row P0 (nothing of this
  application covers the canvas; it names the window manager), group P7 (two
  linked windows, pixel for pixel, with a net highlighted and with none),
  group PC (the window closed under the mode), group PN (the prompt names
  the pin), group PD (a drag in the mode), group PS (a press after the
  engine's pointer was overwritten), group PW (a window made while the mode
  is up), group PV (the clear-all given in the middle of a gesture, a wire
  being drawn: the linked window keeps its list, its highlight table and its
  screen pixel for pixel, and the command given after the gesture takes all
  three), group PT (the design in a second tab), group PE (after a descend
  into a new window, the prompt names no pin of the window the mode is not
  on), group PF (Direct Plot's window closed with traces queued: the
  sentence says how many were not plotted, and the `plot` marker stays
  until the highlights are cleared) and group P8, last, the clear-all keys
  pressed for real and a drag under the Cadence-style profile (row P8d).

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
