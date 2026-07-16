# 0118 — Wire property form looks poorer than the instance form

Status: IN PROGRESS. Spec: `doc/claude/specs/wire_property_form_parity.md`.

## Symptom

The wire "Edit Properties" dialog (`text_line_slick` for `type==wire`) shows only a
plain "Width" entry + a raw "Other properties" box + OK/Cancel, in default Tk fonts
with no header — visibly plainer than the instance form (`slickprop::edit_form`) for
the same operation. The wire's net name (`lab`) is buried in the raw box.

## Fix (ratified scope, see spec §2)

Give the shared graphical editor the instance form's *look* (grey60 header, named
monospace value fonts, dirty-● cue, footer hint, remembered geometry, OK-default) and
promote the wire's **net name (`lab`) as a read-only "Net name" row**. Only **Width**
stays editable; `lock` / `*_ignore` are NOT promoted (kept in the "Other properties"
box). The form stays **modal**. Pure-Tcl, no C change.

## Files

- `src/property_form.tcl` — `gfx_schema`: read-only `lab` row on the wire schema.
- `src/xschem.tcl` — `gfxform::` (init/desired + `update_dirty`) and `text_line_slick`
  (fonts, header, dot, readonly render, footer, geometry).
- `tests/property_form/body.tcl` — RL6d update + RL9 block (RED-first).

## Non-goals

Modeless / Apply button / Apply-to scope / Next-Prev (instance-only). Authoritative
net rename (that is placing a net label). Editable `lock`/`*_ignore` fields.
