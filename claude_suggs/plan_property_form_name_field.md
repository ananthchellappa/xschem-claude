# Plan — issue 0058 (Name field move-up + preserve-on-identity), RED-first

Spec: `doc/claude/specs/property_form_name_field.md`. Issue: `0058-*`.

## Step 0 — RED tests first
Add `NA1..NA7` to `tests/property_form/body.tcl` (real dialog, gui2_ok-guarded; NA7 uses
the OA library tree like PF66). They must FAIL against current code:
- NA1 `.dialog.fname.e` exists and `cur(entry,name)` resolves to it; `name` is not a grid
  row under `.dialog.fa.c.inner`.
- NA2 the dedicated field shows the instance name on open.
- NA3 capa(name=C3)→res via Symbol entry: Name field still `C3`.
- NA4 OK preserves the instance name `C3` (NOT re-prefixed to `R…`).
- NA5 OTHER props reset: value=1k after the change.
- NA6 editing the Name field to `Cnew` renames the instance.
- NA7 LCV Cell-field capa→res preserves the name.
Run, confirm RED.

## Step 1 — C: keep_name flag
- `editprop.c`: add `int keep_name` param to `apply_symbol_prop` and
  `apply_instance_properties`; gate the re-prefix `if(!keep_name && prefix && old_prefix
  && old_prefix != prefix)`. Update the internal caller (`update_symbol`, legacy path)
  to pass `0`.
- `scheduler.c` `apply_properties` branch: parse optional `argv[6]` keep_name (default 0),
  pass to `apply_instance_properties`. Update the usage string.
- Build.

## Step 2 — Tcl: dedicated Name row
- `edit_form`: create `.dialog.fname` (frame: dot label `.i`, "Name" label `.l`, entry
  `.e`) once, after `.dialog.flcv` is created. Bind dirty-cue + FocusIn on `.e`.
- `update_lcv`: after showing flcv/f1, `pack .dialog.fname` after the visible one; hide it
  when the current field set has no `name` (use a namespace flag set by build_fields).

## Step 3 — Tcl: build_fields routes name
- In the `foreach f $fields` loop, special-case `name`: if `[winfo exists .dialog.fname.e]`
  wire `cur(ind,name)=.dialog.fname.i`, `cur(entry,name)=.dialog.fname.e`,
  `cur(loaded,name)`, normalfg, append to `cur(tokens)`, populate `.e`, bind dirty/focus,
  `continue` (no grid row). Else legacy grid row.
- Record `slickprop::has_name_field` (0/1) for update_lcv's show/hide.

## Step 4 — Tcl: preserve on identity change
- `on_identity_changed`: read `slickprop::field_value name` (current Name), and if
  non-empty subst it into the new template before `build_fields`
  (`xschem subst_tok $template name [requote $nm]`). So the rebuilt grid/field keep the
  name and `cur(orig)` carries it.

## Step 5 — Tcl: do_apply passes keep_name
- `do_apply`: pass trailing `1` to `xschem apply_properties …` (both the call and the
  logged `log_apply` line).

## Step 6 — GREEN + regression
- Run NA1..NA7 → GREEN. Update PF65j/PF66 name expectations (preserved, not re-prefixed).
- Full suite `cd src && ./xschem -q --script ../tests/property_form/wrap.tcl` → all green.
- Sabotage-verify: revert the keep_name gate → NA4/NA7 redden (not hollow); revert the
  build_fields name-routing → NA1 reddens.

## Step 7 — docs/memory, commit
- Update spec status, memory ([[slick-property-forms]]), commit on fluid-editing.
