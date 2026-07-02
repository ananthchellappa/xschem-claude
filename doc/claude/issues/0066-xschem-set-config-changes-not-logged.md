# Issue 0066 — config / display / layer changes via `xschem set` are not logged

**Opened:** 2026-07-02
**Status:** OPEN — identified by the action-log coverage audit; not yet fixed.
**Severity:** MED — the `set` branch is a broad hole. Most cases are session
config/display (lower priority), but **change-layer of a selection**
(`set rectcolor` → `change_layer`) is a genuine schematic mutation and must log.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/scheduler.c` `set` dispatcher branch (~:7562+); `change_layer`
(`scheduler.c:7754`); `set_snap`/`set_grid` (`actions.c:335/357`); `set
header_text` (`scheduler.c:7638`); Options menu (`xschem.tcl:13380–13512`), View
menu (:13592–13665), statusbar grid/snap entries (:13136–13138).
**Related:** [[action-logging]]; 0061 (menu entry points); umbrella 0071.

---

## 1. Symptom

Every `xschem set <var> <val>` performs its change but writes no action-log / CIW
line. This covers most of the Options and View menus, the statusbar grid/snap
entry fields, netlist-format selection, the schematic header, and the
change-layer-of-selection operation.

## 2. Root cause

The `xschem set` branch in `scheduler.c` has no `log_action` calls; the Tcl
callers (menu checkbuttons/radios, entry `<Leave>` bindings) are raw
`xschem set …`. So neither side records the change.

## 3. Scope

Schematic-content mutation (must log — highest value in this issue):
- **Change layer of selection** — `xschem set rectcolor` → `change_layer`
  (`scheduler.c:7754`), `push_undo`. Changes object layers.
- **Schematic header / license** — `update_schematic_header` → `set header_text`
  (`scheduler.c:7638`), saved metadata + `push_undo`.

Session config / display (log if faithful full-session replay is wanted):
- **Options menu**: undo-on-disk (`switch_undo`), enable stretch / pin-select /
  infix / orthogonal wiring, auto join-trim, Cadence compat, crosshair size,
  bus-replacement chars, grid/snap thresholds, draw model, **netlist-format
  radios** (`set netlist_type` spice/spectre/vhdl/verilog/tedax/symbol), flat/
  split netlist, color PS/SVG, transparent SVG, debug.
- **View menu**: Set snap value (`set cadsnap`→`set_snap`), Set grid spacing
  (`set cadgrid`→`set_grid`), dim colors, line width, grid-point size, toggles.
- **Statusbar** grid/snap entry `<Leave>` → `set cadgrid`/`set cadsnap`.

Note: the display-palette editor (`change_color`) and `reset_colors` go through
`build_colors`, also unlogged — related but a separate palette path.

## 4. Fix sketch

Split by intent. For **change-layer** and **header**, add guarded `log_action`
(replayable `xschem set rectcolor N` after a selection change; `xschem set
header_text {…}`). For session config, decide policy per spec (Phase 3 already
minted four toggle commands — extend that pattern, or mark the pure-display ones
`nolog`). Route the Options/View menu commands and statusbar entries through the
chosen logger. Snap/grid should log the resolved *value*, not the dialog-open
string (the bindable `view.set_snap_value` action currently logs only the
`input_line …` prompt).
