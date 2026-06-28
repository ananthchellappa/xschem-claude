# 0057 — Edit Properties: changing the cell identity keeps the old cell's attributes

## Summary

In the slick Edit Properties form (`src/property_form.tcl`), the per-field grid is
derived once from the **displayed instance's** property string + its symbol template.
If the user then changes the instance's *identity* — the Library/Cell/View rows, or the
raw **Symbol** entry — to point at a *different* master, the field grid is NOT re-read.
The old cell's attributes stay on screen and, worse, survive the Apply.

Repro: place `devices/capa` (template `name=C1 m=1 value=1p …`). Edit Properties, change
the Cell to `res` (template `name=R1 value=1k footprint=1206 …`). The form still shows
`m`, `value=1p`, etc. On OK the instance is re-pointed to `res` but keeps `m=1 value=1p`
— attributes that mean nothing on a resistor.

Expected (Cadence behavior): changing the cell identity re-reads the new cell and
repopulates the form with that cell's **defaults**, exactly as if a fresh `res` had been
placed. The user can then tweak from there.

## Root cause

Two coupled gaps:

1. **Form (display).** Nothing re-runs `build_fields` when the identity rows change.
   `lcv_compose_symbol` only folds an L/C/V edit back into the Symbol reference at
   Apply time; it never refreshes the attribute grid.

2. **Apply (C convergence).** The apply path (`apply_symbol_prop`, `only_different=1`)
   converges each instance's prop toward `new_prop` by *diffing against* `old_prop`
   (`set_different_token`): tokens in `old` but not in `new` are removed, tokens in
   `new` that differ are written. The form passes `new_prop = result(cur(orig)+edits)`
   and `old_prop = cur(orig)`. With no field edits and `cur(orig)` still the *capa*
   prop, `new == old`, so the diff is empty and the instance keeps every capa token.

   For the reset to flow through this machinery, `new_prop` must be the **new cell's
   template** and `old_prop` must be the instance's **actual current prop** (capa).
   Then `set_different_token` removes `m`, rewrites `value`, adds `footprint`, etc.,
   converging the instance to the res template. The C side already re-points the master
   and re-prefixes the name (`C1`→`R…`) when the `symbol` global differs.

## Fix (Tcl-only, in `property_form.tcl`)

- `slickprop::current_symbol_ref` — resolve the symbol reference currently entered in
  the identity rows (compose L/C/V via `cellview_path` when the LCV form is active,
  else the raw Symbol entry). Returns `{}` if incomplete/unresolvable.
- `slickprop::on_identity_changed` — when a committed identity edit names a *different*,
  resolvable symbol (compared by absolute path) **with a readable template**, adopt it:
  update the `symbol` global / Symbol entry / header / LCV rows, then **rebuild the
  field grid from the new template's defaults** (`build_fields … $template $template`).
  A flag `identity_pending` makes `is_dirty` true so Next/Prev/selection-change still
  prompt. Unresolvable or unchanged references are a no-op (a typo never wipes fields).
- Bind it to commit events (`<FocusOut>`, `<Return>`, `<<ComboboxSelected>>`) on the
  L/C/V entries and the Symbol entry.
- Capture `loaded_prop` = the instance's prop as displayed (set in `load_pos` and the
  single-shot path; NOT touched by the identity rebuild). `do_apply` passes `loaded_prop`
  as `old_prop` instead of `cur(orig)`. In the normal (no identity change) flow
  `loaded_prop == cur(orig)`, so behavior is unchanged; after an identity rebuild
  `cur(orig)` is the new template (→ `new_prop`) while `loaded_prop` stays the real old
  prop (→ `old_prop`), giving `set_different_token` the right pair to converge on.

No C change: the existing `apply_symbol_prop` already does symbol re-pointing, name
re-prefixing, and the `set_different_token` convergence — it was only being fed the
wrong `new`/`old` pair.

### Follow-up: the LCV (Library/Cell/View) path failed silently

First pass tested only the raw **Symbol** entry. The user hits the **Cell** field of the
OA Library/Cell/View rows (cadence_style_rc, nested `devices/capa/symbol` layout). There
`current_symbol_ref` returns the **absolute** path from `xschem cellview_path`, but the
target cell is not loaded yet, so `template_of` `load_symbol`s it — and `load_symbol`
keys the definition under its **lib-qualified rel name** (`devices/res`), not the absolute
path. `template_of` only retried absolute forms → `getprop symbol` missed → returned
`""` → `on_identity_changed` bailed out → "nothing changes". Fix: `template_of` now also
queries `rel_sym_path $abs` (the lib-qualified name) after the on-demand load. The
`<FocusOut>`/`<Return>` bindings were already correct; this was purely the name-form
lookup. Covered by `PF66` (OA registry, real LCV rows, Cell field capa→res).

## Test

`tests/property_form/body.tcl`, new GUI-level section (real dialog, raw-Symbol path so
it runs without the OA registry):

- place a `capa` (`name=C1 m=1 value=1p`), open the form, set the Symbol entry to
  `res.sym`, call `on_identity_changed`;
- assert the field grid now has `value` (=1k default) and `footprint`, and **no `m`
  row**; `cur(orig)` equals the res template; `is_dirty` is true;
- click OK and assert instance 0 is now a `res` (symbol re-pointed), its prop has
  `value=1k`, **no `m`**, and the name is re-prefixed to `R…`.
