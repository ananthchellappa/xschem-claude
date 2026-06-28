# Plan — ALT+ScrollWheel grow/shrink (RED-first)

Spec: `doc/claude/specs/bus_thickness_scroll.md`. Branch `fluid-editing`.

## Slices

1. **Docs** — spec + this plan. (done)

2. **RED tests** — `tests/bus_resize.tcl`, run as
   `../src/xschem --nogui --pipe -q --script bus_resize.tcl`:
   - Pure transform (source `utils/bus_resize.tcl`):
     - grow: `clk`→`clk[1:0]`; `clk[1:0]`→`clk[2:0]`; `d[5:2]`→`d[6:2]`.
     - shrink: `clk[2:0]`→`clk[1:0]`; `clk[1:0]`→`clk` (collapse 2-bit→scalar);
       `clk`→`clk` (floor); `d[6:2]`→`d[5:2]`; `d[3:2]`→`d` (2-bit collapse).
     - round-trip: shrink(grow(x))==x for `clk` and `clk[2:0]`.
     - wire thickness helper: grow from plain → `wire_start`; grow again ≈ ×1.1 with
       ≥+0.5 step; shrink below start → `0` (plain); shrink plain → `0` (no-op).
   - Integration (needs xschem): place `devices/lab_pin.sym {lab=clk}`, select, run
     `busresize_apply grow` → `getprop instance i lab` == `clk[1:0]`; grow → `[2:0]`;
     shrink → `[1:0]`; shrink → `clk`; shrink → `clk`. Generic instance `name` grow.
     Wire: `xschem wire`, select, grow → `getprop wire i bus` numeric > 0; shrink to 0.
   - Confirm RED (procs/commands absent) before implementing.

3. **Tcl** — `utils/bus_resize.tcl`:
   - namespace `busresize`; vars `open ] close sep` (default `[ ] :`), `wire_factor 1.1`,
     `wire_min_step 0.5`, `wire_start 2.0`, `wire_true_base 4.0`.
   - `grow_name {n}` / `shrink_name {n}` (regex from the delimiters).
   - `wire_thickness {tok}` (parse), `wire_grow {tok}` / `wire_shrink {tok}`.
   - `busresize_apply {dir}` (global proc): `xschem push_undo`; foreach
     `xschem objects -selected` branch on `type`/symbol type; `setprop -fast`;
     final `xschem redraw` (single undo/redraw per gesture). Falls back to non-fast
     if -fast leaves the display stale (decided by GUI smoke).

4. **C hooks** — `src/callback.c`:
   - `handle_mouse_wheel()`: replace the final `else { return 0; }` so any modifier
     combo other than lone Shift / lone Ctrl / none computes its normalized mask and
     dispatches on `ACTX_CANVAS` (bind-table lookup; no binding ⇒ harmless no-op).
   - `action_registry[]`: add `edit.grow_selection` / `edit.shrink_selection`
     (Tcl-backed `busresize_apply grow|shrink`).
   - `action_id_mutates`: add both ids (read-only block).
   - `make` and re-run tests GREEN.

5. **Wire-up + verify** — `src/cadence_style_rc`: source `utils/bus_resize.tcl`; add
   `xschem bind wheel up alt canvas edit.grow_selection` and the `down` shrink. GUI
   smoke: Alt-wheel over a selected label (lab grows/shrinks) and a selected wire
   (thickness changes), one undo per notch. Commit.

## Risks / notes
- `-fast` setprop skips `symbol_bbox`/`draw`; if a label's outline goes stale after a
  fast `lab` change, use non-fast per element (correct display, multiple undo) or find
  a recompute call. Resolve in slice 3/5 via GUI smoke.
- Numeric `bus` is visual only (connectivity is by node); a netlist-unchanged check is
  optional but cheap.
- Wheel widening must NOT alter lone Ctrl/Shift/no-mod (graph zoom/pan, graph_use_ctrl_key).
