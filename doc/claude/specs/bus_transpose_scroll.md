# Spec — ALT+SHIFT+ScrollWheel: transpose selected bus index ([N])

Status: IN PROGRESS 2026-06-28. Sibling of the ALT+wheel grow/shrink feature
(`doc/claude/specs/bus_thickness_scroll.md`); reuses its single-undo machinery and the
input action/bind registry. Distinct gesture, distinct transform.

## Motivation

A mouse-only way to bump the **single bus index** on the name of selected pins / net
labels / instances — e.g. step `dat` → `dat[0]` → `dat[1]` to retarget which bit/leaf a
label or iterated instance refers to. "Transpose" because it moves the index, it does
not widen a bus.

- **ALT+SHIFT+ScrollWheel-Up = "transpose grow"**, on every selected object:
  - **wire** → no effect (a selected wire is tolerated, not an error).
  - **text** → no effect (tolerated).
  - **pin / net label** → grow the index on its **`lab`** net/pin name (not the
    instance name).
  - **instance** → grow the index on its instance **`name`**.
  - index transform: `something` → `something[0]`; `something[0]` → `something[1]`;
    in general `something[N]` → `something[N+1]`.
- **ALT+SHIFT+ScrollWheel-Down = "transpose shrink"** — the opposite, no negatives:
  - `something` → `something` (scalar is the floor);
  - `something[0]` → `something` (index 0 collapses back to the bare name);
  - `something[N]` → `something[N-1]`.

(The user described it with `<N>`; xschem's native notation is `[]`, so the stored/
displayed form is `something[N]`. Delimiters are configurable, default `[ ]`.)

## Relationship to bus_thickness_scroll (ALT+wheel)

| | ALT+wheel (busresize) | ALT+SHIFT+wheel (bustranspose) |
|---|---|---|
| wire | thickness ±10% | no effect (tolerated) |
| text | ignored | no effect (tolerated) |
| pin/netlabel | `lab` range `[N:M]` grow/shrink | `lab` index `[N]` grow/shrink |
| instance | `name` range `[N:M]` | `name` index `[N]` |

Both collapse a whole multi-object notch to **one undo step** via the same shared
applier (`busresize::apply_changes`: one `push_undo` → `setprop -fast` per change →
`recompute_inst_bbox` per instance → one `redraw`).

## Behavior (normative)

### Index transform (pure; configurable `[ ]` delimiters)
- **grow(name):** `name[N]` → `name[N+1]`; a bare scalar → `name[0]`; a name ending in
  some *other* bracket form (e.g. a range `[1:0]`) is left unchanged (don't create a
  double bracket).
- **shrink(name):** `name[N]` with N>0 → `name[N-1]`; `name[0]` → `name` (collapse);
  scalar or non-`[int]` → unchanged (floor, never negative).

### Selection handling
Iterate `xschem objects -selected`; only `instance` objects are acted on (label/pin →
`lab`, else `name`); `wire`, `text` and any other type are skipped (tolerated). One
notch = one undo step (shared applier). An all-no-op gesture pushes no undo step.

## Extensibility / C changes

- Two registered actions `edit.transpose_grow_selection` / `edit.transpose_shrink_selection`
  (Tcl-backed `bustranspose_apply grow|shrink`), added to `action_id_mutates`.
- **Wheel dispatch fix (`handle_mouse_wheel`):** the Shift / Ctrl branches currently
  match any state *containing* the Shift / Ctrl bit (`state & ShiftMask`), so an
  Alt+Shift wheel (mask `Mod1|Shift`) is wrongly consumed as plain Shift and never
  reaches the bind table. Tighten both to **exact** lone-modifier matches (compare the
  normalized mask `m == ShiftMask` / `m == ControlMask`) so any multi-modifier combo
  (Alt+Shift, Ctrl+Shift, …) falls through to the canvas bind table. Lone Shift / lone
  Ctrl / no-mod routing (incl. the graph_use_ctrl_key reservation) is unchanged. Minor
  consequence: Ctrl+Shift+wheel no longer pans (it now hits the bind table; unbound by
  default = no-op).
- `cadence_style_rc` binds `alt+shift` wheel up/down to the two transpose actions; a
  user re-homes with one `xschem bind` line.

## Files

- `utils/bus_resize.tcl`: extract `busresize::apply_changes {changes}` (shared pass-2).
- `utils/bus_transpose.tcl` (new): `bustranspose::grow_name`/`shrink_name` + the
  `bustranspose_apply` entry point (reuses `busresize::is_label_type` / `apply_changes`).
- `src/callback.c`: exact-mask wheel branches + two `action_registry[]` rows +
  `action_id_mutates`.
- `src/cadence_style_rc`: source the util + the alt+shift binds.
- `tests/bus_transpose.tcl` (new): RED-first.

## Test

`tests/bus_transpose.tcl` (headless): the pure transform across the spec's cases, plus
integration — grow/shrink a net-label `lab` and an instance `name` through
`bustranspose_apply` over a real selection; a selection that also contains a wire and a
text is tolerated (those unchanged); a multi-object notch is one undo step. The actual
ALT+SHIFT-wheel chord + live redraw are GUI-verified via synthesized wheel events.
