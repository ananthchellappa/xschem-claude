# Spec — Instance Name field: move up + preserve across identity change

Status: DONE 2026-06-28 (issue 0058; suite 260/260, sabotage-verified; GUI eyeball
pending). Builds on the slick Edit Properties form
(`src/property_form.tcl`, namespace `slickprop::`) and issue 0057 (identity-change
re-read).

## Motivation

Two requests on the Edit Properties form:

1. **Layout.** The instance **Name** is the user's primary handle on an instance, but
   today it is buried as just another row in the scrollable per-field grid (the `name`
   token, usually first). Promote it to a dedicated row **directly below the View row**
   (i.e. immediately under the Library/Cell/View identity block), always visible, not
   scrolled away.

2. **Behavior.** When the user changes an instance's **identity / source** (the Library
   or Cell field, or the raw Symbol entry) the form re-reads the new cell and resets the
   other attributes to that cell's defaults (issue 0057). The **Name must be exempt**:
   an instance name is arbitrary ("can be anything"), so re-pointing `C3` from `capa` to
   `res` must leave it named `C3`, only the *other* properties taking res's defaults.
   Today the C apply path force-rewrites the name's first character to the new symbol's
   template prefix (`C`→`R`) on a symbol change — that re-prefix must be suppressed for
   the slick form, where the dedicated Name field is the single source of truth.

## Behavior (normative)

### Layout
- A dedicated **Name** row (label + entry, with the same modified-cue dot as grid fields)
  is packed immediately **after** the identity block: below `.dialog.flcv` when the
  Library/Cell/View rows are shown, else below the raw `.dialog.f1` Symbol row. It tracks
  whichever identity block is visible (re-packed in `update_lcv`).
- The `name` token no longer gets a row in the scrollable grid; it is rendered in the
  dedicated entry instead. All other tokens are unchanged.
- The Name field participates in the existing edit machinery: modified-cue dot,
  `collect_changes`/`result` (its value is folded back into the `name` token),
  `is_dirty`, and the apply.

### Name preservation on identity change
- Changing the identity (issue 0057's `on_identity_changed`) repopulates the grid with
  the new cell's defaults but **keeps the current Name value verbatim** — the new cell's
  template `name=` default is NOT applied to the Name field.
- On Apply/OK after an identity change, the instance keeps its name; the C re-prefix
  (`apply_symbol_prop` `name[0]=prefix`) is **suppressed**.
- The Name field stays authoritative: if the user *does* edit it, that new name is
  applied verbatim (still no auto-reprefix). Renaming is an explicit Name-field edit.

### Edge cases
- An instance/symbol with no `name` token: the dedicated Name row is hidden (no empty
  mystery field), and nothing in the grid changes.
- Multi-instance scope (All Selected / All same-symbol): each target keeps **its own**
  name across an identity change (C1→C1, C2→C2 as the new cell).
- Non-dialog callers of `build_fields` (the `.pf.f` core tests) have no `.dialog.fname`
  entry; `build_fields` falls back to rendering `name` as a grid row there, so the
  widget-independent core is unaffected.

## Design

### Tcl (`property_form.tcl`)
- `edit_form`: create `.dialog.fname` (dot + "Name" label + entry) once; bind dirty-cue
  (`<KeyRelease>/<<Paste>>/<<Cut>>` → `update_dirty name`) + `<FocusIn>` → `on_focus`.
- `update_lcv`: pack `.dialog.fname` after the visible identity frame; hide it when the
  current field set has no `name` token.
- `build_fields`: when iterating the field list, if the token is `name` AND
  `.dialog.fname.e` exists, wire `cur(entry,name)`/`cur(ind,name)`/`cur(loaded,name)` to
  the dedicated widgets and populate the entry — do NOT create a grid row. Otherwise
  (no dialog, i.e. tests) keep the legacy grid row. Track whether a `name` token was
  seen so `update_lcv` can show/hide the row.
- `on_identity_changed`: before rebuilding, read the current Name value and substitute it
  into the new template (`xschem subst_tok $template name <requoted>`), so the rebuilt
  grid + dedicated field naturally retain the name (no spurious dirty cue) and `cur(orig)`
  carries the preserved name into `result`.
- `do_apply`: pass a trailing `keep_name=1` argument to `xschem apply_properties` (and
  log it), making the instance name authoritative for slick applies.

### C (`editprop.c`, `scheduler.c`)
- `apply_symbol_prop(new, old, inst, scope, keep_name)`: when `keep_name`, skip the
  `name[0]=prefix` re-prefix on a symbol change (everything else — re-point master,
  uniqueness via `new_prop_string`, bbox — unchanged).
- `apply_instance_properties(scope, id, new, old, keep_name)`: thread the flag.
- `xschem apply_properties scope id new old [keep_name]`: parse the optional 5th arg
  (default 0 = legacy re-prefix), so the logged/replayed command is faithful.

## Tests (`tests/property_form/body.tcl`, RED-first)
New `NA*` section (real dialog):
- NA1 dedicated Name row exists below the identity block; `name` is NOT a grid row.
- NA2 the Name field shows the instance's name on open.
- NA3 identity change capa→res keeps the Name field value (not the res default).
- NA4 OK after identity change preserves the instance name (no `C`→`R` reprefix).
- NA5 the OTHER properties DID reset to the new cell defaults (value=1k).
- NA6 explicitly editing the Name field renames the instance.
- NA7 the LCV (Cell-field) path preserves the name too.
Plus: update PF65/PF66 expectations (name now preserved, not re-prefixed).
