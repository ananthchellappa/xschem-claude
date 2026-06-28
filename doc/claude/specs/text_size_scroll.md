# Spec — CTRL+Plus / CTRL+Minus: grow / shrink displayed text size

Status: IN PROGRESS 2026-06-28. Third sibling of the selection-edit gestures
(`bus_thickness_scroll.md`, `bus_transpose_scroll.md`); reuses the single-undo applier
and the input action/bind registry, but is a **key** chord (not wheel) and edits text
**size**, not names.

## Motivation

A keyboard way to resize the visible text of what's selected:

- **CTRL+Plus = grow displayed text ~10%** (always by at least a minimum increment),
  applied to every selected object it applies to:
  - **text note** (a standalone `xText`) → bigger.
  - **pin / net label** → the displayed **name** text (the `@lab` text) gets bigger.
    The instance's auto name (`l3`, `p1`) is **not** touched, only the displayed size.
  - every other selected object (wire, generic instance, …) is **ignored**.
- **CTRL+Minus = shrink displayed text ~10%** (at least a minimum decrement if 10%
  wouldn't be visible), never below the per-object-type **minimum**.

"Plus" is the `+` key — either `Shift+=` on the main row (the `=` key by Backspace) or
the numeric-keypad `+`. "Minus" is the `-` key — main row (next to `0`) or keypad.

## How text size is stored (two mechanisms)

- **Text note (`xText`):** size is the object's `xscale`/`yscale` fields (set uniformly
  by the `size` arg of `xschem text …`). Not previously reachable from Tcl.
- **Pin / net label name:** the displayed name is the symbol's `@lab` text. Its size for
  one instance is overridden by the per-instance attribute `text_size_<n>` (read by
  `get_sym_text_size()`); absent the override it falls back to the symbol's own text
  `xscale`. For `lab_pin` / `ipin` / `opin` the `@lab` text is index 0.

## Behavior (normative)

### Size transform (pure)
- **grow(s):** `s' = max(s*1.1, s + min_step)` — the `min_step` floor guarantees a
  visible bump even for small `s` (10% of 0.33 ≈ 0.033 < min_step).
- **shrink(s, floor):** `s' = min(s*0.9, s - min_step)`, then clamped up to `floor`
  (the per-type minimum) — never smaller; shrinking something already at `floor` is a
  no-op. Factor (`1.1`/`0.9`), `min_step`, and the floors are `::textsize::*` vars.

### Selection handling
Iterate `xschem objects -selected`; per `type`:
- `text` → grow/shrink its `size` (`xscale`=`yscale`), floor `::textsize::min_text`.
- `instance` → only if it has an `@lab` name text (`xschem inst_name_text` returns its
  index + current effective size); grow/shrink that, floor `::textsize::min_label`,
  applied as the per-instance `text_size_<idx>` attribute. Non-label instances return
  "" and are skipped.
- any other type → skipped (tolerated).

One CTRL+Plus/Minus press is **one undo step** for the whole selection, via the shared
`busresize::apply_changes` (one `push_undo` → `setprop -fast` per change →
`recompute_inst_bbox` for instances → one `redraw`). A label's text size affects the
instance bbox, so the instance path's bbox refresh keeps hit-testing correct. An
all-no-op / all-at-floor gesture pushes no undo step.

## C changes (no key-dispatch change needed)

The key path already strips Shift for printable keys, so `Ctrl+Shift+=` arrives as
keysym `plus` (43) with `ControlMask`; binding the four keysyms to `mods=ctrl` suffices.

- `getprop text <n> size` → the text object's `xscale` (new pseudo-token).
- `setprop text <n> size <v> [fast|fastundo]` → set `xscale`=`yscale`=`v` (new pseudo-
  token; reuses the branch's existing undo/bbox/redraw, honours `-fast`).
- `xschem inst_name_text <inst>` → `"<idx> <effsize>"` for the instance's `@lab` text
  (index + `get_sym_text_size`), or `""` if the symbol has no `@lab` text.
- Two registered actions `edit.text_grow` / `edit.text_shrink` (Tcl-backed
  `textsize_apply grow|shrink`) + `action_id_mutates` entries.
- `busresize::apply_changes` gains a `text` kind (`setprop -fast text <idx> size <v>`).

## Files

- `utils/text_resize.tcl` (new): `textsize::grow`/`shrink` + `textsize_apply`.
- `utils/bus_resize.tcl`: `apply_changes` `text` kind.
- `src/scheduler.c`: `getprop`/`setprop text size`, `inst_name_text`.
- `src/callback.c`: two `action_registry[]` rows + `action_id_mutates`.
- `src/cadence_style_rc`: source the util + `xschem bind key {43,45,65451,65453} ctrl`.
- `tests/text_size.tcl` (new): RED-first.

## Test

`tests/text_size.tcl` (headless): pure transform (10% vs min-step, floor clamp,
no-op-at-floor), plus integration — a text note's size grows/shrinks; a net-label's
`@lab` size grows via `inst_name_text` + `text_size_0`; a generic instance is ignored;
a multi-object gesture is one undo step. The actual CTRL+/− chords + live redraw are
GUI-verified via synthesized key events.
