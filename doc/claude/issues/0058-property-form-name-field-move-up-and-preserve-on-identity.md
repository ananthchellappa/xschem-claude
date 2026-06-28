# 0058 — Edit Properties: move the Name field up + preserve it across an identity change

## Summary

Two changes to the slick Edit Properties form, requested by the user:

1. **Move the instance Name field up** so it sits directly below the View row (under the
   Library/Cell/View identity block), instead of being buried in the scrollable per-field
   grid.
2. **Exempt the Name from the issue-0057 identity reset.** Changing an instance's source
   (Library/Cell, or the raw Symbol entry) re-reads the new cell and resets the *other*
   attributes to its defaults — but the Name must be preserved verbatim. An instance name
   is arbitrary; re-pointing `C3` from `capa` to `res` must leave it `C3`, only the other
   props taking res's defaults.

## Root cause / why a C change is needed

The display side is pure Tcl (move the row, don't repopulate Name on `on_identity_changed`).
But the apply side re-prefixes the name in C: `apply_symbol_prop` (editprop.c:981) does
`name[0]=prefix` when the symbol's template name prefix changes (`C`→`R`) on a symbol
change. Even if the form keeps `name=C3` in the new prop, C rewrites it to `R3`. So the
re-prefix must be suppressible for the slick apply path.

## Fix

See `doc/claude/specs/property_form_name_field.md` for the full design. In short:

- **Tcl** (`property_form.tcl`): dedicated `.dialog.fname` row packed below the identity
  block (tracked in `update_lcv`); `build_fields` routes the `name` token to it (grid-row
  fallback when no dialog, for the core tests); `on_identity_changed` substitutes the
  current Name into the new template before rebuilding (preserve verbatim); `do_apply`
  passes `keep_name=1` to `apply_properties`.
- **C** (`editprop.c`, `scheduler.c`): `apply_symbol_prop`/`apply_instance_properties`
  gain a `keep_name` flag that skips the re-prefix; `xschem apply_properties` parses an
  optional 5th `keep_name` arg (default 0 = legacy) so replay stays faithful.

## Test

`tests/property_form/body.tcl` NA1–NA7 (RED-first), plus updated PF65/PF66 (name now
preserved on capa→res, not re-prefixed).
