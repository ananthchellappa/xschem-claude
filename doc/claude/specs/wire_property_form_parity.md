# Wire property form — visual parity with the instance form

Status: SPEC (RED-first plan below). Issue: `doc/claude/issues/0118-wire-property-form-parity.md`.
Builds on `slick_text_line_dialog.md` (the `text_line_slick` / `gfxform::` graphical
editor) and mirrors the look of `slickprop::edit_form` (the instance "Edit Properties"
form, see `property_form_name_field.md`, `multi_instance_property_editing.md`).

## 1. Problem

Selecting a wire and pressing the Edit-Properties key opens `edit_wire_property`
(`editprop.c:444`) → `tcleval("text_line {Input property:} 0 normal")` →
`text_line_slick ... wire` (`xschem.tcl:10200`). For a wire the schema is a single
`bus` row (`property_form.tcl:175`), so the user sees:

- a plain modal `.dialog` (no in-window header, default Tk fonts),
- **one** "Width:" entry,
- a raw "Other properties:" box holding every other token verbatim,
- OK / Cancel.

The instance form, by contrast, has a grey60 bold header, named monospace value
fonts, a per-field modified-● cue, a footer hint, and remembered geometry. The wire
form looks visibly poorer than the instance form for the same operation.

Separately, a wire's **net name** (`lab` token) is buried in the raw "Other
properties" box even though it is the wire's most meaningful piece of information.

## 2. Scope (ratified with the user, 2026-07-13)

The user chose a **narrow, look-focused** scope over the broader options offered:

- **D1 — Visual parity, not behavior parity.** Adopt the instance form's *look*
  (header, named/monospace fonts, dirty-● dot, footer hint, remembered geometry,
  OK-as-default). The wire form **stays modal** (`wm transient` + `tkwait`); it does
  **not** become modeless, gains no Apply button, no Apply-to scope, no Next/Prev.
- **D2 — Only Width is editable.** `bus` ("Width") remains the single editable
  field. Do **not** promote `lock` or the six `*_ignore` flags to editable
  first-class fields.
- **D3 — Net name (`lab`) is read-only, info only.** Show it as a **read-only**
  "Net name" row at the top of the Appearance panel. It is a *soft* value — the
  netlister recomputes `wire.node` from label **instances** each run and stamps it
  back into `lab` (`netlist.c:1051/1075/1499`), so it is presented purely for
  information; renaming a net is done by placing a net label, not here.
- **D4 — Keep the "Other properties" box.** Retain the raw escape hatch (unchanged)
  so wires carrying `lock` / `*_ignore` / foreign tokens round-trip byte-for-byte
  and remain hand-editable by power users. Only `lab` and `bus` are promoted out of
  it.
- **D5 — Pure-Tcl, no C change.** All work is in `property_form.tcl` (schema) and
  `xschem.tcl` (`gfxform::` + `text_line_slick`). `edit_wire_property` and the C
  apply path are untouched.
- **D6 — The uplift is applied to the shared `text_line_slick`,** so rect / line /
  poly / arc / pin / pinname editors get the same fonts + header + footer + geometry
  for free (consistency). The read-only `lab` row is wire-only (schema-scoped).

## 3. Design

### 3.1 Schema: promote `lab` as a read-only row (wire only)

`slickprop::gfx_schema` gains a new **read-only** row kind and the wire case lists it
first:

```tcl
set lab [dict create tok lab label {Net name} widget string readonly 1]
...
wire - WIRE { return [list $lab $bus] }
```

`readonly 1` is a generic row attribute (any type could use it). It changes three
things and nothing else:

- **render** (`text_line_slick`): a read-only, flat entry (no edit), value shown in
  the monospace value font, no dirty-● indicator (it can't change).
- **desired** (`gfxform::desired`): a read-only field emits its **loaded** value
  verbatim, so the round-trip is byte-identical and the token is preserved on both
  the "extra unchanged" and "extra edited" assembly paths.
- **schema_extra**: `lab` is now an *owned* token, so it is stripped from the "Other
  properties" box (no more duplication) — handled automatically by the existing
  generic `schema_extra`.

Because `lab` emits `loaded(lab)` (never a user edit), `schema_assemble`'s cardinal
invariant holds: an unedited dialog returns the original prop string byte-for-byte,
and editing only Width changes only the `bus` token — `lab`, `lock`, every
`*_ignore`, and any foreign token are preserved.

### 3.2 View: `text_line_slick` visual uplift

At the top of `text_line_slick`:

- call `slickprop::init_fonts` (creates the four named fonts; the add-pin dialog
  already does this — proven precedent, `xschem.tcl` add-pin);
- add `label .dialog.hdr -bg grey60 -anchor w -font slickPropHeader`. Header text =
  the dialog title, except for a wire it is `"<net>  —  wire"` where `<net>` is the
  wire's `lab` (falls back to `"Wire"` when unnamed) — mirroring the instance form's
  `"R1  —  res"`.

Per Appearance row:

- `-font slickPropLabel` on labels/checkbuttons/combos, `-font slickPropValue`
  (monospace) on entries;
- editable `int`/`num`/`string` rows get a leftmost 2-char indicator label (accent
  colour via `slickprop::accent`) that shows `●` when the value differs from what it
  loaded, updated live via `gfxform::update_dirty` bound to `<KeyRelease>`;
- a fixed-width right-anchored label column so rows align without a shared grid
  (keeps bool/enum/ellipse rows' existing packing untouched);
- read-only rows render a flat `-state readonly` entry and no indicator.

Footer + chrome:

- `label .dialog.hint -text "Enter: OK   Esc: Cancel" -font slickPropHint -fg grey50`;
- OK button `-default active`;
- geometry remembered in `::gfxform_geometry` (saved in `gfxform::ok` and the Cancel
  path, restored on open; falls back to the pointer-relative position first time).

### 3.3 What is deliberately NOT reused from the instance form

`to_fields` / `template_of` (no symbol template for graphical objects), the
Library/Cell/View block, Next/Prev nav, the modeless selection-reactive machinery,
`do_apply`/`apply_properties`-by-id, the Apply-to scope + variance warning, and the
dedicated instance Name row — all are instance-identity concerns with no wire
analogue. The wire form keeps its existing thin modal apply (C round-trip via
`rcode {ok}`).

## 4. RED-first test plan

Correctness is headless and orthogonal to the reskin — it lives entirely in the
schema/assemble core (`tests/property_form/body.tcl`, run via `wrap.tcl`). The visual
layer is WSLg manual-eyeball-gated (fonts rendering, header colour, dot placement,
theme) and covered only by a DISPLAY-gated widget-existence smoke.

**RED (write first, must fail before implementation):**

- **RL6d** changes from `wire schema = bus` → `wire schema = {lab bus}`.
- **RL9a** `lab` row widget is `string`.
- **RL9b** `lab` row is `readonly` (=1).
- **RL9c** `lab` row label is `Net name`.
- **RL9d** `schema_extra` on a wire prop strips `lab` (and `bus`), keeps `lock` /
  `spice_ignore` / a foreign token verbatim.
- **RL9e** `schema_assemble` no-edit is byte-identical on
  `lab=#net3 bus=0.1 lock=true spice_ignore=true foo=bar` when `lab`+`bus` are fed
  their loaded values (proves `lab`/`lock`/ignore/foreign all preserved).
- **RL9f** editing only `bus` updates `bus` and preserves `lab`, `lock`,
  `spice_ignore`, `foo`.

**GREEN (after implementation):**

- The RL9 block + updated RL6d pass; RL1–RL8 / TX1–TX10 / PF* stay green **unchanged**
  (the reskin does not touch their semantics).
- A DISPLAY-gated smoke (modelled on `tests/symbol_pin_scope_form.tcl`): open the wire
  form, poll for its widgets, assert `.dialog.hdr` exists, the Net-name entry is
  `readonly`, the Width entry is editable and carries `-font slickPropValue`. Never
  asserts pixels.

**Manual eyeball (WSLg):** header colour, monospace value font, dot placement,
dark/light theme, dialog-map repaint. Listed as a manual gate.

## 5. Risks

1. `lab` is a soft cache, not an authoritative rename (§2 D3). Mitigated by rendering
   it read-only and, in the future, an optional "place a net label to rename" hint.
2. Multi-wire selection fans the first wire's prop string on OK — this is **existing**
   behaviour (`edit_wire_property` + `set_different_token`), unchanged here; moving
   `lab` from the raw box to a read-only owned field produces the identical
   `tctx::retval`, so fan semantics are byte-for-byte the same as today.
3. WSLg cannot verify the look automatically (synthetic events flaky, `draw()` not
   flushed during dialog mapping) — hence the manual-eyeball gate.
