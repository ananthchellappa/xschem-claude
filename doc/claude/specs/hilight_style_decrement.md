# Spec — ALT-minus: step the net-highlight style cursor back

Status: IN PROGRESS 2026-06-28. Builds on the net-highlight-styles feature
(`xctx->hilight_color` cursor, `xctx->n_net_hilight_styles`, `incr_hilight_color()` in
`hilight.c`, the style table built by `build_net_hilight_styles()`).

## Motivation

Each net highlight uses the style at the cursor `xctx->hilight_color`, then
`incr_hilight_color()` advances the cursor (modulo the number of styles) so the *next*
highlight gets the next style — this auto-increment is how the styles cycle. There is no
matching way to go **back**. The user wants ALT-minus to **decrement** the cursor so a
recently used style can be re-applied to the next highlight (e.g. highlight several nets
in the same style without it advancing past it).

## Behavior (normative)

- **ALT-minus** steps the style cursor back one, wrapping: `hilight_color =
  (hilight_color - 1 + n) % n` where `n = n_net_hilight_styles` (or 1 if none).
- Both the **main-row** minus key (keysym `minus`) and the **numeric keypad** minus
  (keysym `KP_Subtract`) are bound, both with the Alt modifier.
- The new cursor value is echoed to the CIW so the user sees which style is now queued
  for the next highlight. No redraw of existing highlights — only the *next* highlight
  is affected, exactly like the auto-increment.

## Implementation

- **C** (`src/hilight.c`): `decr_hilight_color()`, the mirror of `incr_hilight_color()`
  (declared in `xschem.h`).
- **C** (`src/scheduler.c`): two new `xschem` subcommands, each returning the resulting
  style index (string). They live in the per-first-letter dispatch handlers — the
  dispatcher routes by `argv[1][0]` — so `incr_hilight_color` goes in `xschem_cmds_i`
  and `decr_hilight_color` in `xschem_cmds_d`. Both build the style table first if it is
  empty (`build_net_hilight_styles()`).
- **Tcl** (`utils/hilight_style_nav.tcl`): `cadence::prev_hilight_style` calls
  `xschem decr_hilight_color` and echoes the new index to the CIW.
- **Tcl** (`src/cadence_style_rc`): binds `<Alt-Key-minus>` and `<Alt-Key-KP_Subtract>`
  to `cadence::prev_hilight_style`.

## Test

`tests/hilight_style_decr.tcl` headless: drive `xschem incr_hilight_color` /
`decr_hilight_color`, asserting forward/back stepping and the wrap-around at 0. The
key bindings and CIW echo are GUI-verified.
