# Spec — ALT+ScrollWheel: grow / shrink selected (bus width + wire thickness)

Status: IN PROGRESS 2026-06-28. New Cadence-style gesture. Builds on the input
action/bind registry (`src/callback.c`: `action_registry[]`, `handle_mouse_wheel()`,
`dispatch_input_action()`), the per-wire `bus` width property, and the instance
`name` / `lab` attributes.

## Motivation

A fast, mouse-only way to resize what's selected:

- **ALT+ScrollWheel-Up = "increase"**, applied to **every** selected object:
  - **wire** → increase drawn thickness ~10% (always by a *visible* increment).
  - **pin / net label / instance** → grow the bus suffix on the relevant name:
    `something` → `something[1:0]`; `something[1:0]` → `something[2:0]`; in general
    `something[N:M]` → `something[N+1:M]`.
- **ALT+ScrollWheel-Down = "decrease"** — the opposite, on every selected object:
  - **wire** → decrease thickness ~10% (always a visible decrease, unless already at
    the minimum = a plain wire).
  - **pin / net label / instance** → shrink the bus suffix, never going negative:
    `something[2:0]` → `something[1:0]`; `something[1:0]` → `something` (a 2-bit bus
    shrinks back to a scalar); `something` → `something` (scalar is the floor).

The chord must be **customizable/extensible**: another user should be able to put this
on, say, CTRL+SHIFT+ScrollWheel, via the same `xschem bind` mechanism.

## Decisions (from the user)

- **Bracket notation:** use xschem's native convention — square brackets `[N:M]` for
  both storage and on-canvas display. (xschem's bus expansion/netlister expect `[]`;
  angle-bracket output is a separate netlist concern via `bus_replacement_char`.) The
  delimiters are kept in Tcl variables (`::busresize::open` / `close` / `sep`, default
  `[ ] :`) so a different convention is a one-line change — but the default is native.
- **Which name:** for a **pin / net label** (`IS_LABEL_SH_OR_PIN`) edit the **`lab`**
  attribute (the net/pin name the user sees); the auto instance name (`l3`, `p1`) is
  left alone. For a **generic instance** edit the instance **`name`** (an `[N:M]` there
  is an iterated/array instance).

## Behavior (normative)

### Bus-name transform (pure, configurable delimiters `O N sep M C`)
- **grow(name):** if name ends in `O N sep M C` → `O N+1 sep M C` (extend the larger
  end; for the normal descending `[high:low]` this increments `high`). Else append
  `O 1 sep 0 C` (scalar → 2-bit bus).
- **shrink(name):** if name ends in a range → decrement the larger end by 1; if the
  result would be a **single bit** (high == low) collapse to the bare base name (drop
  the bracket). Else (no range / scalar) → unchanged (floor; never negative).
- Round-trip: grow then shrink (and vice-versa) returns the original, e.g.
  `clk` ⇄ `clk[1:0]` ⇄ `clk[2:0]`.

### Wire thickness (stored in the existing numeric `bus` property)
A wire's drawn width is already driven by its `bus` attribute (`draw.c`: `bus>0` →
`width = XLINEWIDTH(bus*mooz)`). Thickness is modeled as that numeric value:
- numeric thickness `t` = the `bus` token if it is a positive number; `true/1/yes/on`
  (a "thick bus") is read as a baseline `4.0`; empty / `0` / `false` = plain wire
  (`t = 0`, the minimum).
- **grow:** plain wire → `::busresize::wire_start` (default `2.0`, a visibly thick
  line). Otherwise `t' = max(t*1.1, t + 0.5)` (the `+0.5` floor guarantees a visible
  step). Stored via `xschem setprop wire <i> bus <t'>`.
- **shrink:** plain wire → no-op (already minimum). Otherwise `t' = min(t*0.9, t-0.5)`;
  if `t'` drops below `wire_start`, the wire reverts to plain (`bus 0`).
- Factor (`1.1`), min step (`0.5`), start (`2.0`) and the `true`-baseline are all
  `::busresize::*` variables, so the 10%/visibility policy is tunable.

### Selection handling
Iterate `xschem objects -selected`; for each, branch on `type`:
`wire` → thickness; `instance` → if its symbol type is a label/pin, edit `lab`, else
edit `name`. Non-matching types (text, rect, …) are ignored.

**One notch = one undo step (even over a multi-object selection).** A wheel notch is a
single user operation, so it must be a single undo. In xschem's snapshot-undo model
that means: pass 1 collects only the changes that actually differ; if there are none
the gesture pushes nothing; otherwise pass 2 calls `xschem push_undo` exactly once,
then applies every change with the non-snapshotting `setprop -fast`. Because the fast
path also skips `symbol_bbox`, each changed instance is refreshed with
`xschem recompute_inst_bbox <idx>` (so hit-testing / re-selection stay correct after a
label's text grows), and a single `xschem redraw` paints the result. One `xschem undo`
then reverts the entire gesture.

## Extensibility design

- The behavior is two **registered actions** — `edit.grow_selection` /
  `edit.shrink_selection` (Tcl-backed, calling `busresize_apply grow|shrink`) — added
  to `action_registry[]` and to `action_id_mutates` (so read-only blocks them).
- The wheel path is widened: `handle_mouse_wheel()` currently dispatches only
  no-mod / Shift / Ctrl and drops everything else. It is changed so any *other*
  modifier combo (Alt, Super, Ctrl+Shift, …) consults the bind table on the canvas.
  Lone Shift / lone Ctrl / no-mod keep their exact current routing (incl. the
  graph_use_ctrl_key reservation).
- Default chord shipped in `cadence_style_rc`:
  `xschem bind wheel up alt canvas edit.grow_selection` /
  `… wheel down alt canvas edit.shrink_selection`. A user re-homes it with one line,
  e.g. `xschem bind wheel up ctrl+shift canvas edit.grow_selection`.

## Files

- `utils/bus_resize.tcl` (new): the transform + wire-thickness model + `busresize_apply`
  (single-undo: collect changes → one `push_undo` → `-fast` edits → `recompute_inst_bbox`
  → one `redraw`).
- `src/callback.c`: wheel dispatch widening + two `action_registry[]` rows +
  `action_id_mutates` entries.
- `src/scheduler.c`: `xschem recompute_inst_bbox [inst]` — refresh one (or all selected)
  instance bbox(es) without undo/redraw, so a `-fast` batch keeps hit-testing correct.
- `src/cadence_style_rc`: source the util + the two default binds.
- `tests/bus_resize.tcl` (new): RED-first, incl. the single-undo regression.

## Test

`tests/bus_resize.tcl` (headless, under xschem): the pure transform across the spec's
cases (incl. round-trip and collapse), plus integration — place a label and grow/shrink
its `lab`, a generic instance name, and a wire's thickness via the `bus` property, all
through `busresize_apply` over a real selection. The actual ALT-wheel chord + live
redraw are GUI-verified.
