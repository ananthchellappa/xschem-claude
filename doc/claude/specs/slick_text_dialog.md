# Spec — slick `enter_text` dialog (discoverable text attributes)

*Status:* **RESOLVED 2026-06-14 — eyeball-confirmed by user ("working well
enough").** Ratified §2 mapping + §3 layout. Core in `src/property_form.tcl`
(`slickprop::text_schema`/`text_fields`/`text_extra`/`text_assemble`/
`text_bool_checked`/`text_bool_value`), tests TX1–TX10 (suite 181/0,
sabotage-verified); Tk form (`enter_text` + `slicktext::` view) in
`src/xschem.tcl`, raw-box preserved as `enter_text_legacy`. Post-eyeball UX
fixes: size-to-content geometry (was mis-sized on reopen), Tab field navigation,
and Enter=OK from every field except the multi-line text box (verified via Tk
binding test). Scope was **`enter_text`** (text objects), **common visual attrs
only**. **NEXT: `text_line` graphical primitives** (rect/line/poly/arc/wire) —
same approach, per-type static schema; see doc/claude/specs/slick_text_line_dialog.md.

---

## 1. Goal (UX)

Today `enter_text` (`xschem.tcl:6611`) edits text appearance as a **raw token
string** in a small text box (`props`) — the user must already know token names
(`weight=bold`, `slant=italic`, `hcenter=true`, …) to change anything. Replace
that raw box with a **structured "Appearance" panel**: one labeled, discoverable
widget per common visual attribute, so *everything settable is visible without
consulting the manual*.

**Keep unchanged:** the multi-line **Text** content area; the OK/Cancel/Load/Del
row; the `preserve unchanged props` checkbox; the `dialog_minsize_floor` fix.

---

## 2. The field → token mapping (the heart of it — verified)

All values below are read by `set_text_flags()` (`actions.c:~970`) from the text
object's `prop_ptr` (the Tcl `props` var), **except size**, which the dialog
already carries in `tctx::hsize`/`tctx::vsize` (the object's `xscale`/`yscale`).
So the panel reads these tokens out of `props` on open and substitutes them back
on OK — exactly the proven `slickprop::to_fields` / `apply` pattern. **Zero C
change:** `set_text_flags` + `draw()` already interpret the tokens.

| Field (label) | Widget | Token in `props` | Value form (verified) |
| --- | --- | --- | --- |
| Size H / V | two spinboxes (existing `tctx::hsize`/`vsize`) + 🔗 link | *(not a token — `xscale`/`yscale`)* | number |
| Font | dropdown | `font=<name>` | font name string |
| Bold | checkbox | `weight=bold` | present = bold; absent = normal |
| Italic | checkbox (or Roman/Italic/Oblique dropdown) | `slant=italic` \| `oblique` | absent = roman |
| Center horizontally | checkbox | `hcenter=true` | bool |
| Center vertically | checkbox | `vcenter=true` | bool |
| Color / layer | layer-swatch dropdown | `layer=<N>` | integer layer index |
| Hidden | checkbox | `hide=true` | bool (`instance` = hide-when-instantiated; keep that value if already set) |
| Floater | checkbox | `floater=true` | bool |

> **Centering is a boolean toggle, not 3-way justify** (`set_text_flags`:
> `hcenter = strboolcmp(str,"true") ? 0 : 1`). So two checkboxes, not Left/Center
> dropdowns.

**Anything not in the table** (unknown / advanced tokens such as `name=…`) stays
editable in a small **"Other properties"** text box so nothing is lost — the same
freeform string, minus the tokens the panel now owns. On OK, the panel writes its
tokens back into that string via `subst_token` (add/replace/remove), preserving
everything else and token order where possible.

---

## 3. Layout

```
┌─ Enter text ───────────────────────────────────┐
│ Text:                                           │
│ ┌─────────────────────────────────────────────┐│
│ │ <multi-line text content — UNCHANGED>       ││
│ └─────────────────────────────────────────────┘│
│ ─ Appearance ─────────────────────────────────  │
│  Size  H [0.40] V [0.40] 🔗   Font [Sans   ▾]   │
│  [✓] Bold   [ ] Italic                          │
│  [ ] Center H   [ ] Center V                    │
│  Color [▣ 4 ▾]   [ ] Hidden   [ ] Floater       │
│ ─ Other properties ───────────────────────────  │
│ ┌─────────────────────────────────────────────┐│
│ │ name=note1                                  ││
│ └─────────────────────────────────────────────┘│
│  [✓] preserve unchanged props                   │
│        [ OK ]  [ Cancel ]  [ Load ]  [ Del ]    │
└─────────────────────────────────────────────────┘
```

Discoverability extras (cheap, optional within this phase): a tooltip per widget
naming its token; the "Other properties" box **mirrors live** so power users see
exactly which token each widget writes (bridges the gap to the manual).

---

## 4. Contract / wiring (reuse, no C change)

- The C side (`edit_text_property`, `editprop.c:658`) is untouched: it still sets
  `tctx::retval` (text), `tctx::hsize/vsize`, `props` before `enter_text`, and
  reads them back after. The slick panel only changes how the Tcl dialog presents
  and edits `props`.
- New Tcl lives beside the instance form (e.g. `slickprop::text_to_fields` /
  `slickprop::text_apply` in `property_form.tcl`, or a small sibling file),
  driven from `enter_text`. Same `tctx::retval`/`rcode` exit contract.
- `read tokens from props → widgets → on OK subst back into props` — booleans
  add/remove their token; dropdowns/spinboxes replace. Leftover string → the
  "Other properties" box, round-tripped verbatim.
- The legacy raw-box `enter_text` is preserved as `enter_text_legacy` for
  rollback (mirrors `edit_prop` / `edit_prop_legacy`).

---

## 5. Out of scope (this phase)

- `text_line` graphical primitives (rect/line/poly/arc/wire) — the **next** phase,
  same approach with a per-type static schema (dash/fill/ellipse/layer…).
- Global schematic netlist props (also routed through `text_line`) — genuinely
  freeform; **stays a plain text editor**, no structured panel.
- Multi-line widgets / new validators beyond what the instance form already has.

---

## 6. Tests & gate

- Headless (`tests/property_form` style): `text_to_fields` parses each token form
  correctly (bold present/absent, slant italic/oblique, hcenter/vcenter bool,
  layer int, hide true/instance, floater); `text_apply` round-trips an unknown
  token untouched; add/replace/remove each token; size via `tctx::hsize/vsize`
  unaffected. Sabotage-verify (flip a mapping → red).
- **Eyeball gate (the real UX check):** open `enter_text` on a text object, flip
  Bold/Italic/Center/Hidden/Color, confirm the canvas updates and the saved `.sch`
  token string matches; confirm an unknown token survives a round-trip; confirm
  the `dialog_minsize_floor` still shows the button row.

---

*Next step: ratify §2 mapping + §3 layout, then RED-first per the project recipe
(characterize → tests → implement). Implementation note joins
`doc/claude/code_analysis/multi_instance_editing_tutorial.md`; user-guide note in
`doc/`.*
