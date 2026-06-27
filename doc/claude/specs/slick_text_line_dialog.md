# Spec — slick `text_line` dialog (discoverable graphical-object attributes)

*Status:* **L1+L2 IMPLEMENTED 2026-06-14 (RED→GREEN), pending eyeball.** User
decisions: colour/layer **deferred** (§4); ellipse as **checkbox + Start/End angle
fields**. L1 = generic schema core + Rectangle; **L2 = line/poly/arc/wire** (dash/
fill/Width(bus)/Smooth(bezier)). Core+view in `property_form.tcl`/`xschem.tcl`
(`slickprop::gfx_schema` + generic `schema_*`/`bool_*`; `gfxform::` view;
`text_line` dispatch via `xschem selection`; legacy = `text_line_legacy`). Tests
RL1–RL8 (suite 220/0, sabotage-verified). The dashed object in
`mos_power_ampli.sch` is a **poly**, now covered. **Remaining: eyeball pass** (the
five types open the panel; global/header/instance paths unchanged). L3 polish
(extra UX) only if needed.
Follow-up to the slick `enter_text` work ([[slick-property-forms]],
`doc/claude/specs/slick_text_dialog.md`, RESOLVED). Same idea, applied to the legacy
`text_line` dialog (`xschem.tcl`) — the one reached by `q` on a
**rectangle / line / polygon / arc / wire** (the originally-reported dashed
rectangle in `mos_power_ampli.sch`). Reuses the proven subst-into-original core
(`slickprop::apply` / `text_assemble`).

---

## 1. Goal (UX)

`text_line` edits a graphical object's appearance as a **raw token string** — the
user must know `dash=…`, `fill=full`, `bezier=true` to change anything. Replace
that raw box with a **per-type Appearance panel** of discoverable widgets, exactly
as `enter_text` now does for text. Keep the multi-line property box for leftover /
unknown tokens.

---

## 2. The wrinkle `enter_text` did not have

`text_line` is **one proc serving many callers** (`editprop.c`):

| Caller | Invocation | preserve arg | Slick treatment |
| --- | --- | --- | --- |
| rect/line/poly/arc/wire edit | `text_line {Input property:} 0 normal` | `normal` | **Appearance panel** (per object type) |
| global schematic netlist prop | `text_line {Global schematic property:} 0` | `disabled` (default) | **freeform** (Mode combobox) — unchanged |
| header / license text | `text_line … header` | `header` | **freeform** — unchanged |

So the panel appears **only when `preserve_disabled eq "normal"`** (a graphical
object is being edited); the global-netlist-prop and header paths keep today's
plain text editor (those are genuinely freeform directives, not a fixed schema).

**Type detection:** `text_line` is not told which graphical type it is editing.
It will ask the engine: `xschem objects -selected` → the first selected object's
`type` (instance/wire/rect/line/poly/arc/text). That picks the schema. (The C
callers already guarantee the matching object is selected when they call.)

---

## 3. Per-type schema (grounded in `editprop.c`)

Tokens each type's `edit_*_property` actually reads/writes, with verified value
forms. Only **prop-string tokens** are in scope (see §4 on layer/colour).

| Type | Tokens (owned by the panel) |
| --- | --- |
| **Rectangle** | `dash`, `fill`, `ellipse` |
| **Line** | `dash`, `bus` |
| **Polygon** | `dash`, `fill`, `bezier`, `bus` |
| **Arc** | `dash`, `fill`, `bus` |
| **Wire** | `bus` |

Value forms + widgets:

| Token | Meaning | Value form | Widget |
| --- | --- | --- | --- |
| `dash` | dashed stroke | int, **0 = solid**, >0 = dash length | spinbox "Dash (0=solid)" |
| `fill` | interior fill | `full` = solid · `false` = none · absent = default outline | dropdown {Default, None, Full} → {"", false, full} |
| `bus` | stroke width | number (`get_attr_val`); blank/0 = default | entry "Width" |
| `bezier` | smooth polygon | bool `true` | checkbox "Smooth (bezier)" |
| `ellipse` | draw rect/arc as ellipse arc | `a b` (two angles, degrees) | entry "Ellipse (start end)" |

Unknown / not-owned tokens (e.g. pin attrs on a PINLAYER rect — `name`, `dir`,
`pinnumber`) stay in the **"Other properties"** box, round-tripped verbatim — same
as `enter_text`.

---

## 4. Out of scope (this phase)

- **Layer / colour is NOT a prop-string token for graphical objects.** Unlike
  text (`layer=N`), a rect/line/poly/arc lives in `xctx->rect[c]` etc. — its layer
  is *structural*, changed by the separate "change layer" action, not by token
  substitution. So colour is **excluded** from the v1 panel (the existing layer
  controls still apply). A future phase could add a layer dropdown that calls the
  change-layer path instead of editing the prop string.
- Global schematic netlist props and header/license text — stay freeform (§2).
- The instance dialog (already the slick `edit_form`) — untouched.

---

## 5. Reuse / core changes

The `enter_text` core is text-specific (`slickprop::text_schema` is hardcoded).
Generalise the read/assemble helpers to take a **schema argument** so both
dialogs share them (the suite TX1–TX10 guards the refactor):

- `slickprop::gfx_schema <type>` → the per-type ordered descriptor list (§3),
  each field `{tok label widget …}`; `widget` ∈ `int|enum|num|bool`.
- generic `slickprop::schema_fields <schema> <prop>` / `schema_extra <schema>
  <prop>` / `schema_assemble <schema> <orig> <desired> <extra>` — the existing
  `text_*` become thin wrappers passing `text_schema` (tests still green).
- `bool`/`enum` value mapping carried in the descriptor (bezier on=`true`; fill
  enum values), so no per-token special-casing leaks into the UI.

No C change: `set_rect_flags` / `edit_*_property` already parse these tokens from
`prop_ptr`; the slick panel only changes how the Tcl dialog presents the string.
The slick `text_line` keeps the legacy as `text_line_legacy` (rollback parity).

---

## 6. Phasing

1. **L1 — core + Rectangle** (the reported case): generic schema core + `gfx_schema
   rect` (dash/fill/ellipse), wired into `text_line` for the `normal` path when a
   rect is selected. RED-first (RL* tests).
2. **L2 — the other four types** (line/poly/arc/wire schemas; bus/bezier widgets).
3. **L3 — polish:** the `text_line` geometry/Tab/Enter UX fixes already proven on
   `enter_text` (size-to-content, Tab nav, Enter=OK-except-text) — applied here
   too (and the gridded `dialog_minsize_floor`, since `text_line` is gridded).

---

## 7. Tests & gate

- Headless core (suite `tests/property_form`): per-type `gfx_schema` content/order;
  `schema_fields` parses dash int / fill enum / bus num / bezier bool / ellipse;
  `schema_extra` strips owned + preserves pin tokens; `schema_assemble` no-edit
  byte-identical and edit round-trips; sabotage-verify.
- **Eyeball gate:** `q` on a rectangle → Dash/Fill/Ellipse widgets reflect and edit
  the object; a wire → Width; a polygon → Smooth; the canvas updates; an unknown
  token survives; buttons visible; second open sized sanely; Tab/Enter behave.

---

*Open forks for ratification before coding: (a) do all five types in one L-pass
or Rectangle-first then the rest; (b) confirm colour/layer is correctly deferred
(§4); (c) `ellipse` as a single "a b" entry vs a checkbox + two angle spinboxes.*
