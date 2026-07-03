# Issue 0066 — config / display / layer changes via `xschem set` are not logged

**Opened:** 2026-07-02
**Status:** RESOLVED 2026-07-02 — change-layer (`83419d64`) + header_text +
cadsnap/cadgrid resolved-value self-log; pure session-config sets unlogged by
policy (see §5). Tests: `test_selflog_output.tcl` §3j.
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

---

## 5. Resolution — RESOLVED 2026-07-02 (branch `fluid-editing`)

**Policy decided.** The `xschem set` branch is not one thing; it splits three
ways, and the action log's contract (spec §6: *replay-where-possible per-action
log, NOT full-session config replay in v1*) draws the line:

1. **Saved-schematic mutations** (push_undo / written to the `.sch`/`.sym`) —
   **MUST log**, replayable, read-only-guarded.
   - `set rectcolor` + a selection → `change_layer()` — **already done**
     (commit `83419d64`): logs `xschem set rectcolor N`, rejects on read-only,
     bare layer-cursor pick (no selection) stays unlogged.
   - `set header_text` — **done here**: license/header metadata is saved,
     undo-pushed content. Self-logs the replayable command via
     `log_action_argv` (Tcl_Merge quotes arbitrary/multi-line license text so it
     stays source-able), gated *inside* the existing "value actually changed"
     guard (a no-op set logs nothing and pushes no undo), and now rejects on a
     read-only view via `scheduler_readonly_reject` exactly like `rectcolor`
     (previously it mutated a read-only schematic — a latent 0041 hole).

2. **Edit-geometry state the log must reproduce for faithful coordinate replay**
   — **log the resolved value** at the C core.
   - `set cadsnap` / `set cadgrid` → self-log `xschem set cadsnap <value>` /
     `xschem set cadgrid <value>` reading the *resolved* `cadsnap`/`cadgrid` back
     (so `set cadsnap 0` → the default is logged, not `0`). This covers every
     active path by construction — the View-menu dialog OK button, the statusbar
     `<Leave>` entry, the Options half/double items, and raw script — all funnel
     through the same core. Snap is not a content edit (no undo, allowed on a
     read-only view), so it is **not** read-only-guarded.
   - The `view.set_snap_value` ActionDef (ships unbound) is flagged `nolog`:
     `input_line` is async (returns before the user types), so the dispatcher
     would otherwise log the *dialog-open prompt string* as a bogus line while
     the resolved value logs later at the core. `nolog` + core self-log = one
     clean `xschem set cadsnap <value>` line whenever a user binds the key.
     Mirrors the Phase-3 gesture-START rule (suppress the start, log the effect).

3. **Pure session config / display preference** — everything else in the branch
   (`color_ps`, `draw_window`, `change_lw`, `crosshair_layer`, `line_width`,
   `netlist_type`, `hide_symbols`, transparent/color SVG, draw model, Cadence
   compat, debug, grid-point size, dim colors, bus-replacement chars, …).
   **Unlogged by design.** These do not alter saved content or replayable edit
   geometry; logging them is *full-session config replay*, explicitly out of v1
   (spec §6). Left bare with a one-line policy comment at the branch head so a
   future coverage audit does not re-flag them. (Deliberately-logged display
   toggles like `toggle_colorscheme` are Phase-3 minted subcommands with a stable
   replayable form — a different, already-handled path, not `xschem set`.)

**Tests:** `tests/headless/test_selflog_output.tcl` §3j (7 checks) — header_text
logs / no-op silent / read-only rejects + logs nothing; cadsnap + cadgrid log the
resolved value; a pure-display `set` (`color_ps`) logs nothing. Sabotage-verified.

**Not in scope (unchanged, by policy above):** the netlist-format radios, the
Options/View preference toggles, the palette editor (`change_color`/
`reset_colors` → `build_colors`, a separate path noted in §3).
