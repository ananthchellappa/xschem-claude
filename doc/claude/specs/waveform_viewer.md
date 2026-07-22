# Waveform Viewer — standalone wave window for ASE-L (Results > Direct Plot)

Status: SPEC (round 3 of doc/claude/ase_l_batch/)
Related: doc/claude/specs/ase_l.md (ASE-L), src/ase.tcl, src/ase_window.tcl

## Decisions (user, 2026-07-21)

1. **Architecture**: dedicated viewer WINDOW reusing xschem's C graph engine
   (Option A). Not a pure-Tcl reimplementation, not external gaw/bespice.
2. **Persistence**: the viewer session is PART OF THE ASE SAVED STATE (a
   `viewer` key in the ngspice_state dict). Load State containing a viewer
   section relaunches the viewer with its layout. Future (NOT now): ASE-L
   opens a saved RESULT (archived raw) and plots from it — leave the seam
   (viewer references the run's rawfile path, do not hardcode live-run-only).
3. **v1 scope**: analog core — tran/dc/ac traces, stacked graphs, A/B
   cursors with readout, zoom/fit, log axes, add/remove trace, expression
   waves (db/mag/ph via `xschem raw add`). DEFER: digital/bus lanes,
   multi-dataset sweep selector UI, cursor back-annotation onto schematic.

## Current-state facts (recon 2026-07-21, file:line verified)

- Graph = `xRect` with flags bit0 (`B 2 … {flags=graph node=… color=… x1/x2
  y1/y2 divx/divy logx/logy digital dataset…}`) drawn ON the schematic
  canvas; 127 shipped files carry embedded graphs (47 xschem_library,
  37 sky130A, 43 newsym). Engine untouched by this feature; embedded graphs
  keep working. De-cluttering shipped files = separate later hygiene.
- C engine: draw.c `draw_graph` 4536-4950 (+grid 3415-3780, points 3288-3400,
  buses 3203-3220, hcursors 3783-3820, `draw_graph_all` 4958); cursor
  interpolation/backannotate callback.c:404-535; graph property dialog
  `graph_edit_properties` xschem.tcl:4736-5357.
- Raw layer: save.c `raw_read`/`read_dataset` 593-843/1002-1075 (ngspice
  binary+ascii, multi-dataset sweeps); `xschem raw` scheduler API
  (scheduler.c 8370-8517+): read, table_read, switch/switch_back, clear,
  loaded, info, datasets, points, vars, list, sim_type, rawfile, value,
  values, pos_at, index, del, rename, set, new, add <RPN expr> (eval_expr.y:
  db mag ph re im sqrt min max …).
- Post-sim hook today: `simulate()` xschem.tcl:4056 sets callback
  `raw_read $rawfile $sim_type`.
- Windows: `create_new_window` xinit.c:1873 → `build_widgets` xschem.tcl:14168
  builds a PER-WINDOW menubar → a viewer window can carry its own reduced
  menu set. `load_new_window`/`new_schematic create_window` can open an
  empty untitled canvas programmatically.
- External viewers (gaw :2020 default spicewave, ngspice plotter,
  rawtovcd→gtkwave, bespice) stay available, unchanged.

## Architecture

`src/wave_viewer.tcl`, namespace `wviewer::`, one viewer window per ASE
session (raise-or-open; N sessions → N viewers).

- **Window**: real toplevel via the create_new_window path; canvas hosts
  ONLY graph rects (untitled buffer never offered for schematic save);
  editing verbs stripped (no instance placement/wiring; graph-context
  bindings + zoom/pan kept); per-window menubar replaced with viewer menus:
  File (Close), View (Fit, Zoom, Redraw), Graph (Add Graph, Add Trace…,
  Delete selection, Axes/log toggles), Cursors (A, B, readout panel),
  Help-less. ASE-style theme (ase::theme palette + fonts). Window number via
  notify_window_active; title `Waveforms <design cell> (<state view>)`.
- **Model**: viewer layout = list of graph dicts
  `{traces {{expr -i(v1) name id color 4} …} logx 0 logy 0 x1 {} x2 {}
  y1 {} y2 {} height 1}` mirrored to graph rects on the viewer canvas
  (create/update via `xschem setprop rect` on the graph rects, stacked
  vertically, shared x-range option). Raw attach: `xschem raw read
  <rundir>/<cell>_ase.raw <sim_type>` (ASE run gains `-r` rawfile arg if
  not already present).
- **ASE integration**:
  - Results > Direct Plot: reuse item-08 Select-On-Design click machinery
    with flavor `plot` — click wires/terminals queues traces, ESC ends →
    viewer raised, traces added, redraw.
  - Outputs pane Plot checkboxes: after a successful run, checked rows
    auto-plot into the viewer ("plot after simulation" — v1 always-replace
    policy, Cadence's Auto/Replace default).
  - `~` action-strip button: raise-or-open viewer (live from this round).
  - Simulation temperature/variables unaffected; viewer only reads raw +
    state.
- **Persistence** (item 14, as shipped): the state dict gained a `viewer`
  schema key (appended LAST in `ase::schema_keys`, default `viewer {}` in
  `ase::state_default` — the empty dict, so a session that never touched
  the viewer keeps a clean `viewer {}` line and old states load through
  the default merge with NO viewer auto-open). Non-empty shape (fixed
  build order for byte-deterministic snapshots):
  `viewer {open 0|1 sharedx 0|1 rawfile {} graphs {…}}` — graphs are the
  live wviewer model dicts VERBATIM (traces incl. expr/name/vec/color,
  logx/logy, x1/x2/y1/y2 with {} = auto, and the `auto 1` marker, which
  MUST round-trip or always-replace appends a second auto graph after
  reload). Save State snapshots the live viewer (open → `open 1` + current
  layout; closed → `open 0` with the last-known graphs KEPT); Load/open
  with `viewer open 1` relaunches the viewer after the session window is
  up and re-attaches the raw when it exists. Saved-results seam: a
  non-{} `rawfile` in the dict is honored at restore (absolute as-is,
  relative against the state's rundir); v1 snapshots always write
  `rawfile {}` (= the current run's raw). Details: "Item 14 notes" below.

## Item 13 notes (as shipped, 2026-07-21)

- **Direct Plot queues TRACES, not outputs**: the item-08 click mode gained a
  `mode` argument (`outputs` default / `plot`); in `plot` mode clicks collect
  expressions into a per-mode queue and session outputs are NEVER written
  (Cadence Direct Plot creates no save entries). ESC → `ase::ui::dp_finish`:
  one NEW stacked graph per invocation, queued traces appended to it.
- **Auto-plot always-replace**: after each successful run, outputs rows with
  plot==1 rebuild ONE dedicated graph marked by an extra `auto 1` key on its
  model dict (graph_props ignores unknown keys; item-14 serialization
  round-trips it). Rebuild = `clear_graph_traces` + re-add — clear-NOT-remove
  keeps Direct-Plot graph indices stable; Direct-Plot graphs are never
  touched. Zero plot rows never opens a viewer (an open viewer's stale auto
  graph is emptied).
- **op-only results** (`ase::plot_sim_type` = `op`): Direct Plot and
  auto-plot report a ciw_echo notice (no sweep, nothing plottable) and touch
  nothing — no crash, the click mode still exits clean.
- **Raw seams**: `ase::plot_sim_type <state>` = the LAST enabled analysis in
  the fixed op/dc/ac/tran emit order (the analysis owning ngspice's CURRENT
  plot when the in-.control `write` runs — the correct `raw read` type);
  `ase::last_rawfile <key>` = the backend raw_file path ONLY when the file
  exists (file existence == "has results"; also the saved-results seam for a
  fresh session). `wviewer::attach_raw` = switch ctx + `raw clear` + `raw
  read` + regenerate — the SAME helper implements re-run replace; cleared
  `raw add` vectors are re-added by auto-plot, other stale expression traces
  draw as nothing (redraw rc 0). `-<token>` output exprs (e.g. `-i(v1)`)
  map to RPN `<token> -1 *` via `ase::ui::plot_map_expr`, materialized
  through `raw add`.
- **Lifecycle**: `ase::ui::close` now closes the session's viewer
  (`wviewer::close` — the item brief's "already item-11 semantics" was wrong,
  the hook did not exist before item 13). `~` strip button + Results >
  Direct Plot are live (D13 wiring).

## Item 14 notes (as shipped, 2026-07-21)

- **Dict shape** (superset of the round-1 sketch): `viewer {open 0|1
  sharedx 0|1 rawfile {} graphs {…}}`, built in exactly that key order by
  `wviewer::snapshot` so identical layouts serialize byte-identically.
  `sharedx` IS persisted (the live layout is `{sharedx graphs}` — dropping
  it would silently lose the Shared-X toggle on reload); the menu mirror is
  re-synced on restore. Cursor state (cva/cvb/cvr mirrors) is NOT
  persisted — the mirrors die with the window by item-12 design; re-enable
  cursors through the relaunched viewer's menu.
- **Snapshot-at-Save-only**: `ase::ui::viewer_snapshot` runs FIRST in both
  Save State paths (`do_save_state_as` — all three target arms — and the
  plain `ase::ui::save_state` seam) and folds `wviewer::snapshot` into the
  session state IFF it differs. There is NO continuous sync: viewer-layout
  edits do not dirty the session until a Save runs the snapshot, and
  closing the session/viewer DISCARDS the in-memory layout like any
  unsaved edit (no snapshot at close — by `ase::ui::close` time the
  session is already unregistered when `wviewer::close` runs). Closed-arm
  semantics: `open 0` with the PREVIOUS dict's graphs kept (the state dict
  is the only survivor of `wviewer::forget`); no previous dict → `{}`.
  Accepted side effect: save-as to a DIFFERENT view leaves the session
  dirty-marked when the snapshot changed the in-memory state — honest,
  the session's own file now differs.
- **Relaunch = fresh-open only**: `ase::ui::viewer_restore` is called at
  the end of `ase::ui::open` (after populate) and of
  `ase::ui::do_load_state_from` (Session > Load State import). The
  `ase::open_state` RAISE arm is exempt — re-raising an existing session
  must not resurrect a viewer the user closed. Headless is naturally
  excluded (`ase::ui::open` only runs under has_x; `wviewer::open`
  returns 0 headless and `wviewer::restore` bails).
- **Load State arm**: viewer_restore acts ONLY on `open 1`; `open 0` /
  absent / `viewer {}` → return 0, no viewer action — an already-open
  viewer is left exactly as it is (minimal contract arm).
- **Restore mechanics** (`wviewer::restore {token vdict rawfile
  sim_type}`): open the window, OVERWRITE the layout from the dict + sync
  the sharedx mirror, then — when a usable rawfile resolved — inline
  raw clear + `raw read` (type word omitted when sim_type is {}) and
  RE-MATERIALIZE every multi-token RPN expression trace via `xschem raw
  add <vec> <expr>` (the clear killed those vectors; without the re-add
  restored traces draw empty and the readout interp throws — RPNs were
  validated at trace creation, so a bare catch suffices), ONE regenerate
  at the end (attach_raw is NOT reused: it regenerates internally and
  would double-regenerate before the re-materialize).
- **Raw resolution** (in `ase::ui::viewer_restore`): dict `rawfile`
  override first (absolute as-is, relative against `[ase::rundir
  $state]`, attached IFF it exists), else `ase::last_rawfile` (file
  existence == "has results"); sim_type = `ase::plot_sim_type` with NO
  op-only gate (restoring an op raw is harmless, unlike plotting into
  it). No rawfile at all → the viewer opens with its layout, traces draw
  empty (regenerate autozooms only when `raw loaded >= 0`, redraw rc 0),
  a ciw_echo notice reports "traces will fill after a run" — no crash.
- **Fixture**: the committed test_nfet_final state gained the trailing
  `viewer {}` line so the state_save-canonical byte-identity round trip
  (test_ase_final F3) holds under the 14-key schema; `library_new_view`
  seeds new ngspice_state* views from `ase::state_default`, which now
  carries `viewer {}` automatically.
- **Acceptance-flow finding — Direct Plot needs the net SAVED**: ngspice
  restricts the raw to the `.save` set, and the item-13 `add_trace`
  honestly refuses a vector missing from a loaded raw — so Direct Plot of
  a net that was never marked To Be Saved lands no trace. The acceptance
  flow (test_ase_persist G3s) therefore marks the D net To Be Saved
  (Outputs > To Be Saved > Select On Design) before Netlist-and-Run,
  exactly what a real ADE-L user does.
- **C fix ridden in (reality-forced)**: `graph_fullxzoom` (src/draw.c)
  dereferenced `xctx->rect[GRIDLAYER][xctx->graph_master]` unguarded, but
  `graph_master` is MOUSE state (-1 whenever the pointer is not over a
  graph, callback.c waves_selected) — a programmatic
  `setprop rect 2 n fullxzoom` (regenerate/Fit/restore) could read
  `rect[2][-1]` and intermittently SIGSEGV, killing the viewer-relaunch
  legs. Fix: an out-of-range master is clamped to the target graph
  (self-master). Pre-existing since item 12; surfaced by item 14's
  close/reopen cycles.

## Non-goals (v1)

Digital lanes, sweep-family selector, cursor backannotate-to-schematic,
graph printing/export, standalone viewer outside an ASE session (viewer
always belongs to a session; a bare "open viewer on arbitrary .raw" File
menu item is a cheap later add).

## Round-3 batch items (ledger in doc/claude/ase_l_batch/PLAN.md)

11 viewer-window — window shell, stripped bindings, menus, theme, numbering
12 viewer-core — traces/graphs model, add/remove, cursors, zoom, log, expr
13 ase-plot — Direct Plot click mode, Plot checkboxes auto-plot, `~`, raw wiring
14 persistence-accept — `viewer` state key, Save/Load relaunch, dc-sweep
   end-to-end acceptance (plot -i(v1) vs swept Vgs, cursor readout sane)
