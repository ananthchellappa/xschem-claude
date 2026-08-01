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

## Item 19 notes (as shipped, 2026-07-22)

Round-5 acceptance item. Item 18 made the graph FILL the viewer window and
pinned the canvas viewport (regenerate no longer runs `xschem zoom_full`);
item 19 makes every zoom/pan/View verb act on the **graph** content, so it can
never shrink the graph (the canvas xorigin/yorigin/zoom never change). **Pure
Tcl in `src/wave_viewer.tcl` + tests + docs — NO C touched** (the C graph engine
and the input-binding table already do everything the RMB path needs).

- **Wheel (D1)** mirrors the `cadence_style_rc` canvas wheel scheme, applied to
  GRAPH content, as a pure-Tcl viewer handler (`wviewer::wheel`, bound in
  `strip_bindings` AFTER the sweep as the most-specific wheel binds):
  - **plain wheel up/down** = GRAPH **vertical** pan (shift y1/y2 by ±5% of the
    y span; up = toward larger y),
  - **Shift+wheel** = GRAPH **horizontal** pan (shift x1/x2 by ±5% of the x span),
  - **Ctrl+wheel** = GRAPH zoom about centre (up = span×0.8 in, down = span÷0.8
    out). **Both axes on the pointed strip (issue 0144):** the X window is zoomed
    on **every** strip so the stack stays time-aligned, the Y window **only** on
    the strip under the cursor (Y is per-strip — each carries its own signal
    scale). Implemented in `wviewer::wheel_zoom`, the synchronous-write seam the
    tests drive directly; `wviewer::wheel`'s ctrl arm just resolves the pointed
    strip (`graph_at_pointer`) and delegates. This also fixes X under
    `sharedx 1`, where `regenerate` makes non-master strips inherit graph-0's x
    range — zooming the pointed strip alone was clobbered. (Was X-only on the
    pointed strip.) **The View-menu Zoom In/Out and `Z`/`Ctrl-z` share this
    contract (issue 0145):** `graph_zoom` delegates to `wheel_zoom`, resolving the
    pointed strip with `graph_at_pointer` (for the menu that is the last strip the
    pointer was over — the click leaves the canvas but `mousex_snap` keeps the
    last canvas position; fallback strip 0). An explicit `gi` names the Y target.
    **Anchored AT the pointer (issue 0146):** the data point under the cursor
    stays put, like the schematic's `view_zoom` — `wviewer::zoom_about` scales a
    range about an anchor, and the anchor comes from the new C verb
    `xschem graph_coord <gi> <px> <py>` (pixel → data; Tcl must not re-derive the
    plot box's 14% margins). The wheel binds and `Z`/`Ctrl-z` pass the event
    `%x %y`; the x anchor (a time) is shared by every strip so the stack stays
    aligned and pinned, the y anchor applies to the pointed strip. The View menu
    passes no pixel (its click is off-canvas) and so keeps zooming about centre.
  On Tcl 8.6/X11 the wheel arrives as `Button-4`(up)/`Button-5`(down); the new
  `<Button-4/5>` + `<Shift-*>` + `<Control-*>` binds (each ending in `break`)
  pre-empt the kept generic `<Button>` that used to forward X11 wheel to the C
  waveform handler. **Forwarding to the C waveform-wheel was rejected:** plain
  wheel there is a HORIZONTAL body pan (callback.c:1157-1168) and Ctrl+wheel is
  hard-pinned to CANVAS zoom (callback.c:4417) — both contradict the user's ask.
  `<MouseWheel>`/`<Shift-*>`/`<Control-*>` (signed `%D`) are also bound for
  Tcl>8.7/non-X11 portability. The token is resolved from `%W` at event time
  (`wviewer::wheel_bind`) — never captured stale at bind time.
- **RMB (D2)** stays on the C engine. `btn3_filter` dropped its `over_graph`
  early-return and now forwards Button-3 press+release **unconditionally**:
  item-18 tiling guarantees the pointer is always inside a graph, so the C
  press→GRAPHPAN / release→box-zoom path (callback.c:1000/:1454) always fires
  and `view.zoom_rect` (the canvas zoom box) is never reached; the canvas stays
  pinned. **XY box-zoom (issue 0142):** an interior RMB press-drag now draws a
  live rubber rectangle and zooms **both** axes — X window (x1/x2) across the
  participating graphs, Y window (y1/y2, or ypos1/ypos2 for digital) on the
  master graph. Dragging on the **left Y-axis margin** stays a Y-only zoom;
  Shift still inverts to zoom-out. (Previously the interior drag narrowed only
  x1/x2 and drew no rectangle.) All in shared C `waves_callback`, so on-canvas
  schematic graphs get it too. **No snap grid in graphs (issue 0143):**
  `waves_callback` overrides `mousex_snap`/`mousey_snap` with the raw pointer at
  entry, so the box-zoom (and pan/cursors) select any sub-region, not grid
  steps — the schematic snap grid is a schematic-only concept.
- **`f` / `Z` / `Ctrl-z` (D4)** are intercepted in `key_filter` (KeyPress only;
  the matching KeyRelease is swallowed) BEFORE the forward: `f`→`wviewer::fit`
  (fit is the only path that fits BOTH x and y), `Z`→`graph_zoom in`,
  `Ctrl-z`→`graph_zoom out`. An unknown canvas (`token_for_canvas` `{}`) falls
  through to the old forward. ~~Arrows still forward~~ — **superseded by issue
  0149**: forwarding them let the CANVAS own the gesture (off-graph bare arrow →
  `view.scroll_*`; any modifier → `SET_MODMASK` → the hard-coded origin pan;
  Ctrl+Left/Right → tab switch). Arrows are now intercepted too: bare Left/Right
  = graph horizontal pan, bare Up/Down = graph vertical pan (`wviewer::arrow_pan`
  → `wviewer::wheel`, the same ±5 % as the wheel); every modified arrow is
  swallowed. Item-19's Up/Down X-zoom is gone — zoom has four affordances
  already, an arrow means pan.
- **`wviewer::fit` de-canvased (D5)**: its trailing `xschem zoom_full; xschem
  redraw` became `xschem redraw`. fullx/fullyzoom already fit the graph data
  range; item-18 pins the canvas, so Fit must not reframe the window.
- **View menu (D6)**: `Zoom In`/`Zoom Out` → `wviewer::graph_zoom $token in|out`
  (X-only zoom about centre, every graph); `Fit` → `wviewer::fit` (de-canvased);
  `Redraw` stays a plain canvas redraw (canvas-safe).
- **Range writes freeze all four axes (D7)**: any pan/zoom reads the current
  concrete `{x1 x2 y1 y2}` (`graph_range` via `getprop rect`), applies the delta
  to the target axis, and writes ALL FOUR back into the model as concrete values
  before regenerate (`apply_range`). Freezing an untouched axis stops
  regenerate's autozoom from wiping a prior pan/zoom on the other axis.
- **New pure-Tcl helpers**: `graph_at_pointer` (band under the pointer; fallback
  0 for none/one graph), `graph_range`, `apply_range`, `wheel`, `wheel_zoom`
  (0144: X-all + Y-pointed ctrl-wheel zoom), `graph_zoom`, `wheel_bind`.
- **The graph-not-canvas invariant** is the deterministic test teeth: every IX*
  leg in `test_wave_viewer.tcl` asserts the intended graph-range change AND that
  `xschem get xorigin/yorigin/zoom` still equal a once-captured baseline (item-17
  lesson: witness a synchronous state write, not a gesture/stacking race). IX-fit
  runs last because the S2 sabotage (re-inserting `zoom_full`) moves the canvas;
  the real code never does, so the single baseline holds for every leg.

## Plot modes + target strip (issue 0151, 2026-07-25)

Full contract: **`doc/claude/specs/waveform_viewer_modes.md`**. What it changes
in the ledger above:

- (Issue 0153 later made the landing mode decide trace COLORS too — see below.)
- Item 13's "**ONE new stacked graph per invocation**" is now **mode
  dependent**. `ase::ui::dp_finish` delegates to `wviewer::plot_signals`:
  *single-plot* (the shipped default, `wviewer_plot_mode`) appends every queued
  signal into the window's **target strip** and creates no graph; *multi-plot*
  appends **one new strip per signal**. Empty queue is still a no-op.
- The invariant "**Direct-Plot graphs and the auto graph never touch each
  other**" is PRESERVED and is now enforced in code: the auto-plot graph is
  never a landing site — single-plot treats "target == auto graph" like an
  empty stack (append one strip, land there, and make it the target), because
  auto-plot clears and rebuilds that graph after every run.
- Auto-plot itself and the Add Trace… dialog **deliberately ignore the mode**.
- New per-window state (`mode`, `target`) persists in the `viewer` state dict
  as two keys appended **after** `graphs`; states written before 0151 load
  unchanged (missing keys → the config default and strip 0).
- The viewer menubar gained an **Options** cascade (Options > Plot Mode), so
  the fixed cascade list is now `File View Graph Cursors Options`.
- `<ButtonPress-1>` is now bound on the viewer canvas (re-target the strip,
  then forward the press to the C engine verbatim + `break`); it joins the
  keep-set survivors asserted by G1s.
- The target strip is marked by a dull-yellow bar at its right edge, drawn by
  the C engine from an `active=1` prop token, only while more than one strip is
  up, only on screen (never in SVG/PS export).

## Wave bold is an LMB click (issue 0152, 2026-07-25)

Full detail: `doc/claude/issues/0152-graph-rmb-bolds-wave.md`. Changes the item-19
"RMB stays on the C engine" note: inside the plot body RMB is now **box-zoom
only**. The wave-bold toggle (`hilight_wave`, the trace drawn thick) moved from
Button3 PRESS to the **release of a Button1 press that did not travel** — on the
press it also fired at the start of every RMB box-zoom drag (0142). Applies to
**every** graph, on-canvas schematic graphs included (shared `waves_callback`),
which is a deliberate change to long-standing upstream behavior.

RMB on a **legend entry** is untouched: it is the separate, per-trace bold
(`edit_wave_attributes(2,...)`), and a legend double-click still opens the
attributes dialog. LMB on the legend does nothing, as before.

## Trace colors + color-matched picker highlight (issue 0153, 2026-07-25)

Full detail: `doc/claude/issues/0153-trace-colors-and-picker-hilight.md`.

- **Multi-plot no longer paints every trace the same color.** Per-graph
  `next_color` was right for single-plot only; multi-plot lands each signal in a
  fresh EMPTY strip, so all of them got palette head 4 (`#88dd00`). Batch colors
  now come from the PURE `wviewer::plan_colors` — `used` is seeded window-wide for
  multi, per-landing-strip for single (**single-plot is unchanged**). Any caller
  of `plot_signals` gets this, not just the picker.
- **The Direct Plot / Ctrl-4 signal picker paints the schematic.** As each signal
  is clicked, the wire (or, for a current probe, the source body) is highlighted
  in **the exact color that signal's trace will use**, so the viewer maps back
  onto the schematic. The color is resolved once at click time
  (`wviewer::predict_colors`, prefix-stable), carried in the queue, and pinned
  through `plot_signals`/`add_trace` — the cue and the trace cannot disagree.
- Highlights **persist past ESC** (user decision); pre-existing highlights are not
  wiped on entry, so colors may coincide with them.
- New C surface: `xschem hilight_netname [-layer <n>]` /
  `xschem hilight_instname [-layer <n>]` — highlight in the plain color of a
  drawing layer, without using or advancing the style cursor. Required because
  highlight values >= 0 are *style* indices and palette layers 4/5 have no style
  row at all.
- Unchanged: the **Add Trace… dialog** and **auto-plot** still ignore the plot
  mode and use per-graph `next_color`.

## Auto-named nets are pickable (issue 0154, 2026-07-25)

Full detail: `doc/claude/issues/0154-ase-cannot-plot-auto-named-net.md`.

An UNLABELED net carries the engine's marker name `#netN` (`get_unnamed_node`,
`netlist.c`) and the netlister emits it **without** the marker (`V1 net1 GND`).
Clicking one in Select On Design / Direct Plot used to print the
"v1 queues source currents only" notice and plot nothing. Two causes:

- the picker resolved the net through `xschem flylines at`, and fly-lines rule
  **A6 deliberately excludes `#` nets** (a `#netN` cluster is unique per physical
  cluster, so a star for it is meaningless). **A6 is unchanged** — the overlay,
  the query and `tests/headless/test_flylines.sh` keep it exactly as shipped. The
  picker now has its own resolver, `ase::ui::sod_net_at`, which keeps `flylines
  at` as the primary and falls back to `xschem nets -selected` **for WIRE hits
  only** (a device body reports every net it touches, and a two-pin device shorted
  onto one net reports exactly one — a length test alone would misread it as a
  voltage pick and break the I6 "non-source click queues nothing" contract);
- `sod_expr` wrapped the raw token, giving `v(#net1)`. It now strips the leading
  `#` (mirroring `send_net_to_graph`, `hilight.c`). Not just a missing trace: a
  `.save v(#net1)` card makes ngspice abort the whole analysis, killing every
  other trace in the session.

**The two names are NOT interchangeable and the split is load-bearing:**
`xschem hilight_netname` finds `#net1` and does **not** find `net1`, so
`dp_hilight` (the issue-0153 color cue) keeps the RAW token while only the
expression is mapped. Both call sites are `catch`-guarded, so conflating them
fails silently.

`sod_expr` stays a **pure** string op — it is called with no design loaded
(`test_ase_interact` H1) — rather than using `xschem resolved_net`, which is
also contaminated on its first call (issue 0154's adjacent-defect list).
Unchanged: a BUS pick still emits a single invalid `v(a[1:0])`, and descended
picking still emits an unqualified name.

## X is shared, Y is per-strip (issue 0150, 2026-07-25)

The stack is time-aligned: **any x change must hit every strip; y is
independent per strip.** Uniform since 0150 — `wviewer::pan_x` (Shift+wheel and
the Left/Right arrows) joins `wheel_zoom` (Ctrl+wheel, View>Zoom In/Out, `Z`,
`Ctrl-z`, X on all + Y on the pointed strip, 0144/0145) in obeying it. Before
0150 the horizontal pan moved only the pointed strip. Plain wheel / Up / Down
pan y on the pointed strip alone, by design. Remaining per-strip x writers are
the explicit ones: **Graph > Axes…** (one graph's form; `Shared X Axis` is the
toggle that forces graph-0's x onto the rest at regenerate) and **Fit** (each
strip to its own data).

## The graphs OWN the viewer window (issue 0149, 2026-07-25)

Contract, stated once: **no gesture in the viewer may move the canvas.** The
graphs tile the viewport (item 18) and every zoom/pan verb edits graph ranges
(item 19); a canvas pan/scroll slides that tiled stack inside a larger canvas and
opens blank space, and it is NOT blocked by the readonly flag (readonly only
refuses object mutation). Two survivors were closed in `strip_bindings` /
`key_filter`, per-widget, pure Tcl:

- **Middle button swallowed** (`<ButtonPress-2>`, `<ButtonRelease-2>`,
  `<B2-Motion>`). `waves_selected` (callback.c:88-92) explicitly skipped Button-2
  so the schematic pan keeps working over on-canvas graphs — meaning MMB in the
  viewer could only ever be `start_pan_logged()`. Ctrl+MMB (the
  `edit.cycle_pin_type` chord, a readonly modal) dies with it.
  **SUPERSEDED 2026-07-27** (strip drag-reorder, below): MMB over a graph is now
  the GRAPH pan — `waves_selected` no longer skips it and the pan motion arm
  moved from `Button1Mask` to `Button2Mask` — so it is forwarded through
  `wviewer::btn2_filter` instead of swallowed. The contract above is unchanged:
  the filter accepts the **press** only well inside a strip, so it can still
  never reach `start_pan_logged`, and Ctrl/Alt+MMB stay inert.
- **Arrows intercepted, never forwarded** (`wviewer::arrow_pan`): bare
  Left/Right/Up/Down pan the graph, every modified arrow is swallowed. See the
  item-19 note above for what each forwarded form used to do.
- **`<Shift-…>`/`<Alt-Button-1>` triples swallowed** — rubber-band/copy-drag and
  unselect-at-pointer, canvas-only by the same `waves_selected` skips.

Not a hole (recorded in issue 0149): a graph rect can still be *selected* by a
click in the 5 px `border` inset at a band edge — cosmetic; the drag-move itself
is gated on `!xctx->readonly`, so nothing in the viewer can be moved or deleted.
Making a graph "move" (swap strip positions) shipped on 2026-07-27 as strip
drag-reorder (below) — and, as anticipated here, it is deliberately NOT a
schematic move: it is a list move on the Tcl model followed by a regenerate.

## A viewer context says so: `wave_viewer` (issue 0172, 2026-07-31)

`wviewer::open` stamps a **fifth** per-context C flag next to `readonly` (D1),
`no_grid` (item 18), `no_snap` (issue 0177) and `graph_snap_cursor` (item 9):

```tcl
catch {xschem set wave_viewer 1}
```

Why a flag and not an inference: the viewer is built on an ordinary schematic window and
is **indistinguishable from a pristine untitled scratch buffer by shape** — top level,
named `untitled.sch`, no instances, no wires (its content is graph *rects*) — and D1
makes that permanent, because `with_edit` ends every mutation with `xschem set_modify 0`
so `modified` is 0 for the buffer's life. `is_pristine_untitled()` (`scheduler.c`), the
predicate behind the "reuse the current window" rule, therefore offered a **live viewer**
as a reuse target: File>Open loaded a user schematic *into* the viewer window, destroying
its graph rects, and the window kept its `WaveViewer` bindtag and menubar — so the next
`Ctrl-D` (Clear All) wiped the user's document. `xctx->wave_viewer` makes the refusal
honest: a viewer is excluded because it *is* one.

Rules that come with it:

- **Stamped inside the same block as the other four**, below that block's
  `[xschem get current_win_path] ne $wp` refusal — never above it, or a detached editor
  that took the context by accident would be branded a viewer.
- **Never cleared.** A viewer stays a viewer for the window's life;
  `alloc_xschem_data()`'s `my_calloc` gives every other context 0 for free.
- **Settable from Tcl**, which is what lets a regression test brand a buffer as a viewer
  headlessly — `tests/headless/test_pristine_untitled_viewer_0172.tcl` needs no Tk and no
  `DISPLAY`. `test_wave_clear_all.tcl` CG9 (needs X) is the leg that proves
  `wviewer::open` really stamps it in production.
- **`ask_new_file()` reads it too** (`src/actions.c`): that path — `xschem load` with no
  filename, Ctrl-O / Alt-O — never consulted `is_pristine_untitled()` at all and loaded
  in place over whatever the current context held, so the flag is what makes it choose
  the new-window arm for a viewer. CG10 is its guard. Not reachable from the viewer's own
  keyboard (`key_filter` does not forward `o`, and the viewer's File menu has only Close)
  but reachable by typing `xschem load` in the CIW while the viewer holds the context.

See `doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md` and
`doc/claude/specs/load_window_routing.md` ("What pristine means").

## Ctrl-4 schematic entry + status-line prompt (as shipped, 2026-07-24)

Keyboard entry to item-13 Direct Plot straight from the DESIGN window, so the
user never has to reach the ASE window's Results menu. Pure Tcl, no C change, no
recompile (decision: pure-Tcl `.drw` bind, defer device-pin terminal currents).

- **Entry proc** `ase::direct_plot_for_current` (`src/ase.tcl`, next to
  `launch_for_current`): `design_of_current` -> `session_for_design` -> if a
  session is bound, `ase::ui::direct_plot $key`; no session -> honest `ciw_echo`
  and `{}`; non-schematic view -> `{}` (design_of_current already reported it).
  has_x-guarded; returns the session key or `{}`.
- **Keybind** `bind .drw <Control-Key-4> {ase::direct_plot_for_current; break}`
  in `src/cadence_style_rc` (by the Ctrl-2 group). The `break` overrides the C
  default (Ctrl+4 = select drawing layer 4, `callback.c` case '4'), same idiom as
  `Ctrl-2 -> cadence::make_editable`. `clone_canvas_bindings` propagates it to
  every canvas. Remap = edit that one line.
- **Bottom status-line prompt** "select signals to plot" on the design window's
  green mode slot `$top.statusbar.10` (the "DRAW WIRE!"/"HIGHLIGHT NET!"
  convention) while the mode is armed; cleared on ESC. Because C
  `update_statusbar()` (end of `callback()`, `callback.c`) BLANKS `.statusbar.10`
  on every event when no C ui_state bit is set — and focus/window churn
  re-establishes the generic canvas bindings, so an appended (`+`) re-assert does
  NOT survive — the prompt is kept up by a light `after 80` re-assert pump
  (`ase::ui::sod_prompt_pump`), self-cancelling when the mode ends. This is
  per-mode (`plot` -> "select signals to plot", `outputs` -> "select outputs on
  design"). **Known tradeoff:** a blanking event shows a sub-100ms flicker before
  the pump restores the prompt; a proper fix (zero flicker) is a new C ui_state
  bit + an `update_statusbar()` branch + a clear in `abort_operation()` — deferred
  with the "no recompile" decision.
- **Deferred (explicit):** clicking an arbitrary device TERMINAL to queue its
  current. v1 currents still come only from `vsource`/`ammeter` bodies
  (`sod_click`). The device-pin path needs a new C verb wrapping
  `find_closest_pin` (`findnet.c`), a PDK `@spice_get_current` token builder
  (D/G/S/B -> id/ig/is/ib via `xschem translate`), and auto `.options
  savecurrents` (`save_all_i`, `ase.tcl`). See the ctrl4-directplot workflow
  findings.
- **Interactive fixes (first real GUI use, 2026-07-24):**
  - *ESC dead / nothing plotted*: `design_window`'s `raise_activate_toplevel` +
    `focus $tp` moved keyboard focus to the TOPLEVEL, but the mode's seized
    `<Key-Escape>`/`<ButtonPress-1>` binds live on the CANVAS (and the Button-1
    `break` pre-empts the generic `<ButtonPress>` that would refocus it). Real ESC
    never reached `sod_end` → mode stuck, `dp_finish` never ran → no plot (mouse
    picking worked because it needs no focus). Fix: `catch {focus $cv}` at the end
    of `select_on_design`'s arm. (The item-13 menu Direct Plot had this latent too;
    test P4 hid it with `focus -force`.)
  - *Window flash / "hiccup"*: `raise_activate_toplevel` does `wm withdraw` +
    `wm deiconify` — a visible flash — even when the design is already front.
    Ctrl-4 knows the design IS the current front window, so `direct_plot_for_current`
    now calls `ase::ui::direct_plot $key 0`; the new `do_raise` arg on
    `direct_plot`/`select_on_design` skips `design_window` entirely on the Ctrl-4
    path (also sidesteps any `raise_design_editor` path-mismatch duplicate-window
    open). The menu path keeps `do_raise 1`.
- **Tests**: `tests/headless/test_ase_plot.tcl` PH5 (pure: proc + statusbar-slot
  mapping) and P9/P10 (GUI: entry proc arms Direct Plot, CANVAS holds focus so ESC
  fires [sabotage-verified], prompt shows/returns via pump/clears, no-session honest
  no-op). 124 checks green.

## Clear All (issue 0171, 2026-07-27)

**Ctrl-D in the viewer deletes every graph and every trace and leaves ONE empty
strip.** Command: `wviewer::clear_all ?token?` (optional token, {} = the viewer
owning the current xschem context, like the 0151 mode/target commands); also
**Graph > Clear All** (accelerator `Ctrl+D`) and CIW-typable.

- **Kept by design:** the plot mode (single/multi — the explicit request), Shared
  X, the cursor/readout mirrors, and the **attached raw data**. Clearing the raw
  would also kill every `xschem raw add` expression vector and force a re-run;
  the point of a clear is re-picking signals from the *same* results.
- **Gone:** all graphs, all traces, and the `auto 1` marker with them. The
  survivor is a plain `empty_graph`, never the auto-plot strip: item 13's
  always-replace rebuild would silently wipe hand-picked traces landed there
  (the reason `plan_plot` already excludes it as a landing site). A later
  auto-plot run appends its own strip and leaves the empty one at index 0.
- **Target strip** resets to 0.
- **Logged replayably on every successful call** through the `log_action` seam —
  `wviewer::clear_all <token>`, resolved and explicit. Unlike `set_plot_mode` /
  `set_target_strip` (change-only), a redundant clear IS logged: a destructive
  gesture dropped from a replay rebuilds a different window.
- **The key is on a BINDTAG, not the canvas.** `strip_bindings` sweeps every
  widget-level sequence on a viewer canvas, so neither a widget default nor the
  repo's usual `bind .drw ...` rc idiom survives into the viewer. The default is
  installed once (first viewer open) on the shared **`WaveViewer`** tag, which
  `strip_bindings` inserts at bindtags index 1 — after the widget (so
  `key_filter` keeps first refusal; it never `break`s, so a swallowed key still
  reaches the tag) and before the `Canvas` class. rc remap:

  ```tcl
  bind WaveViewer <Control-Key-d> {break}                      ;# drop the default
  bind WaveViewer <Control-Key-r> {wviewer::clear_all_at %W; break}
  ```

  An rc binding **wins** (defaults are only installed for a sequence nothing has
  bound). Disable with `{break}`, never `{}` — an empty script deletes the
  binding, which reads as "never bound" and gets re-defaulted. `clear_all_at`
  takes the token from the EVENT's canvas (`%W`), not the current C context: Tk
  focus can lead the context switch, and clearing "whatever is current" would
  wipe the wrong window.
- **The strip a clear leaves behind GETS USED** (follow-up, same day). Landing
  now reuses EMPTY strips before appending — `wviewer::empty_graph_indices` +
  `plan_plot`'s 6th arg, full contract in
  `doc/claude/specs/waveform_viewer_modes.md` §4. Without it multi-plot appended
  past the cleared strip and left a blank band pinned at the top of the window
  (the reported symptom); `Graph > Add Graph`'s strip had the same fate. The
  auto strip is still never a landing site, and an explicit usable target still
  beats reuse. Multi-plot also grows the stack UPWARD now: created strips go on
  top and a batch reads newest-first (`v1 v2 v3` -> `v3` topmost), so a cleared
  viewer plus three picks reads exactly like three successive gestures would.
- **Tests:** `tests/headless/test_wave_clear_all.tcl` (`CA*` no-window, `CG*`
  GUI) — 67 checks, sabotage-verified. Documented in `src/cadence_style_rc`.

## Viewer status bar (viewer plan item 10, 2026-07-29)

**Each viewer window carries its own bottom status bar** showing the plot mode
and, while the item-9 diamond is snapped, that sample's x and y:
`Plot: single    x: 1.5u    y: 900m`.

- **⚠ It is NOT `$top.statusbar`.** `statusmsg()` (`scheduler.c` ~49) and
  `update_statusbar()` (`callback.c` ~7994) rewrite that bar's slots from C on
  **every GUI event**, addressed by `xctx->top_path` — so anything written into
  it here would be silently overwritten on the next mouse move.
  `ase::ui::select_on_design` already fought this and pays an 80 ms re-assert
  pump for it; one of those in the tree is enough. The viewer builds a private
  `$top.wvstatus` and `pack forget`s the editor bar for the window's life, the
  same per-window treatment the toolbar already gets.
- **Packed `-side bottom -fill x -before $top.drw`**, the rule `readout_show`
  uses, so the bar takes its height from the canvas rather than squeezing it.
- **The formatting is a PURE proc**, `wviewer::status_text {mode x y}` — no Tk,
  no `xschem` — so the whole formatting half is assertable headless. Values go
  through `ase::format_value` (engineering notation, and it returns
  non-numerics verbatim so `{}`/`Inf`/`NaN` cannot throw).
- **⚠ The label is `Plot:`, never `MODE:`.** The shipped editor bar already
  carries a field literally labelled `MODE:` (`xschem.tcl` ~14908) and that one
  is the **netlisting** mode. Two contradictory MODEs in one window is worse
  than no status bar.
- **The mode is PUSHED, not polled**: `set_plot_mode` — the one mutation site —
  refreshes immediately after the model write, so the bar is right however the
  mode changed (Options menu, `ase::plot_mode_for_current`, the chord, state
  restore). The menu's own label is pull-only via `-postcommand`; without the
  push the bar would go stale silently.
- **The position rides the motion pump.** The snapped sample changes on a
  C-side motion event with no Tcl hook, so the bar appends to the **kept
  generic `<Motion>`** — never a more-specific sequence, which would preempt
  the generic editor bind (the readout's `<ButtonRelease>` comment applies
  verbatim). `status_refresh` never throws, and only touches Tk when the string
  actually changed, because it runs on every mouse move.
- **Item 10 does not compute the position.** It consumes item 9's published
  contract, `xschem get graph_snap`.
- **⚠ `wviewer::in_ctx` runs its script with `uplevel #0`** — GLOBAL level — so
  a `set` inside the script body creates a *global* and the caller's local is
  untouched. Take the value through the **return** instead.
  (`wviewer::with_edit` uses `uplevel 1` and *does* reach the caller's scope,
  which is what `delete_all_markers`' count relies on. **The two brackets
  differ and the difference is silent.**) Measured: the bar showed the plot
  mode and never a coordinate.
- **Tests:** `ST*` in `tests/headless/test_wave_snap.tcl` — 14 pure legs under
  `--nogui` plus the widget half on DISPLAY (`cget -text`, the editor bar
  hidden, the push, and the position dropping outside the plot box).
  Sabotage-verified three ways.

## Diamond snap cursor (viewer plan item 9, 2026-07-29)

**While the pointer hovers a waveform graph, a diamond sticks to the nearest
SAMPLE of the nearest trace**, and that sample is published for the status bar
(item 10) as `xschem get graph_snap` → `"<graph-index> <node-index> <x> <y>"`,
or `""` when nothing is snapped.

- **THE GATE IS THE PLOT BOX, NOT A DISTANCE TO A TRACE.** While the pointer is
  anywhere inside the rectangle delineated by the two axes and the two lines
  opposite them, the diamond snaps to the nearest sample of the nearest trace
  **however far away that trace is**; outside the box there is no snap.
  `graph_plotbox_at()` is the gate and `graph_point_at()` is handed a threshold
  nothing can exceed — its *ranking* is wanted, its *threshold* is not.
  ⚠ The first cut used `graph_point_at`'s `tol` as the gate, so the pointer had
  to pass within ~20 px of a trace before anything appeared. Reported from a
  real session: *"the mouse pointer needs to be too close to the trace"*.
  `graph_plotbox_at` brackets `graph_flags` and uses a local `Graph_ctx` exactly
  as `graph_point_at` does (landmines 11 and 37), and **normalises both axis
  pairs** because `gr->cy` is negative (landmine 3) so the y screen bounds come
  back reversed.
- **The query was 100% shipped.** `graph_point_at()` already returns the
  nearest sample with `hit.sx`/`hit.sy` in **screen pixels** and `hit.x`/`hit.y`
  as the **raw** values — landmine 35 is handled inside it, so a zero sample
  cannot come back as `1e-35`. This item is a rendering and repaint-cadence job
  plus a publish seam, as the plan predicted.
- **⚠ THE ERASE COPIES BACK FROM `save_pixmap`**, and must not be the `gctiled`
  stroke that `draw_snap_cursor`/`erase_snap_cursor` use on this platform. That
  stroke is the shipped *schematic* erase, guarded there by
  `fix_broken_tiled_fill || !_unix`; with `FIX_BROKEN_TILED_FILL` undefined (the
  default) the guard picks the stroke, and **in a viewer window the stroke does
  not remove the glyph** — the diamond left a TRAIL across the strip and only a
  full redraw (`f` = fit) cleared it. Reported from a real session. The
  copy-back is the fallback `erase_snap_cursor` itself uses where the tiled fill
  is known broken; it is the reliable one of the two, so it is used
  unconditionally. This is also why the glyph must never be written into
  `save_pixmap`: the copy-back would restore the diamond it was meant to erase.
- **Arming is PER CONTEXT** (`xschem set graph_snap_cursor 1`), the `no_grid`
  precedent — **not** a global Tcl var. `graph_point_at` walks every sample of
  every trace, and it is shared with the ~127 shipped schematics that embed a
  graph; arming globally would put that cost on every one of them. The ASE
  viewer sets it on its own window at open and never clears it.
  ⚠ `SG1` alone does **not** protect this: the getter reports `xctx->graph_snap`
  whatever the *pump* consults, so re-arming the pump from a global leaves
  `SG1` green. `SS6` is the leg that bites — verified by sabotage.
- **Two brakes on the per-hover cost.** The query is skipped entirely unless the
  mouse **pixel** changed (`draw_snap_cursor`'s `pos_changed` guards only the
  *paint* — not enough when the query is the expensive part), and the repaint is
  skipped when the snapped **sample** is unchanged, which is the common case:
  the pointer moves several pixels and still resolves to the same sample.
- **It yields to every armed gesture** — marker drag, strip drag, trace drag,
  cursor drag, graph pan, box zoom. The test is `xctx->ui_state ||
  xctx->graph_marker_dragmode`, deliberately the broadest available: in a
  read-only viewer canvas `ui_state` is 0 at rest, so anything set means a
  gesture owns the pointer. The hook sits **after** `waves_callback` so a
  gesture starting on this very event is already reflected.
- **Window-only, so it cannot reach an export at all.** The whole cadence runs
  with `draw_pixmap = 0`, so the glyph never enters `save_pixmap`. That is a
  stronger guarantee than the `flags & 16` "UI chrome" rule it would otherwise
  need, and it is obtained structurally rather than by remembering a bit.
- **Cleared** on LeaveNotify, when the pointer moves off every graph, when a
  gesture arms, when disarmed, and in `clear_drawing()`. Every field is
  0-at-rest so the single `my_calloc` of `xctx` is the only initialisation
  needed.
- **⚠ The letter-dispatch landmine bit both halves of the verb.** `xschem get`
  groups sub-keys by first letter and `xschem set` splits on
  `argv[2][0] < 'n'`; a `g` key filed in the wrong half is **silently**
  unreachable — no error, the setter simply does nothing. `SP5` is the
  regression leg.
- **Tests:** `tests/headless/test_wave_snap.tcl` — 22 nogui / 38 DISPLAY,
  sabotage-verified. The DISPLAY arm sweeps real `<Motion>` events to find the
  box, asserts the published `y` equals `2*x` for a `vv = vsweep*2` fixture
  (which is what proves the values are raw rather than screen or log-mapped),
  then walks a VERTICAL line through the box and asserts the snapping band
  covers **most of the sweep** — a box gate snaps on ~78% of it, a proximity
  gate on ~7%. ⚠ That leg first used a magic `> 12` count and a 20-px proximity
  band sampled every 3 px yields ~13, so the sabotage squeaked past it and the
  leg proved nothing; it is a FRACTION now.
- **⚠ THE GLYPH IS EYEBALL-ONLY, and that is not a formality.** Both defects
  above — the trail and the proximity gate — shipped past a fully green suite,
  because everything the suite can reach (the query, the publish seam, the
  arming, the yields) was correct while the thing the user actually sees was
  not. A green run here is necessary and nowhere near sufficient.

## Grid on/off — Ctrl-G (viewer plan item 3, 2026-07-29)

**Ctrl-G shows/hides the graph grid of the active viewer window.** Command:
`wviewer::grid_toggle ?want? ?token?` (`want` {} = invert, else 0/1), also
**Graph > Grid** (a **checkbutton**, accelerator `Ctrl+G`). Returns the new
state, or `{}` plus a CIW error. Initial state from `wviewer_grid_show`
(default 1).

- **⚠ Only the DASHED LINES go.** The plan said "gate `draw_graph_grid`'s
  body" — that function also draws the background, the bounding box, the tick
  marks, **the axis numbers** and the zero lines, so gating the body would
  leave a plot with no readable axis. Only the four dashed-line calls are
  gated; `GT16`/`GT17` assert that no `draw_string` sits behind the gate.
- **`grid` is a WINDOW property, not a strip property** — it lives in the
  layout dict beside `sharedx`, and is passed **as an argument** to
  `graph_props` (like `active`), *not* read from a namespace global. Making
  the rect generator impure is the same objection that shaped item 2's
  `drawline` split.
- **The token is emitted ONLY when OFF.** An absent `grid` token means "draw
  it", which is what every non-viewer graph in the tree relies on, and it keeps
  a grid-on window's rects byte-identical to pre-item-3 — the
  `hilight_wave`/`markers` "absent means absent" rule. (Contrast `legendbold`,
  whose 0 *must* be written because its default is not the shipped value.)
  In C, `gr->grid` defaults to **1** and is set before the `RECT_OUTSIDE` early
  return.
- **Not an undo point.** This is a window OPTION (like plot mode, sharedx,
  cursors), and window options are deliberately outside the model snapshot —
  so no `push_undo`, no `capture`, matching `sharedx_toggle`/`set_plot_mode`.
  It keeps the rest of the contract: refuse-a-no-op-without-logging, verified
  `switch_ctx`, ONE regenerate, ONE log line.
- **The menu mirror is PUSHED, not polled.** `sync_grid_mirror` runs on every
  change, so the checkbutton is right however the state changed (key, command,
  restore) — the staleness `plot_mode_menu_post` has to solve with a
  `-postcommand`. The `-command` **sets** the value Tk already wrote rather
  than toggling again, or the menu would invert twice and appear dead.
- **Collision check — clean.** Ctrl-G in a schematic toggles the global
  `draw_grid` via `bind .drw` in `src/cadence_style_rc`; a `WaveViewer` bindtag
  binding cannot reach it, `strip_bindings` sweeps the cloned widget binds, and
  the viewer sets `no_grid 1` on its context for life so the dot grid was never
  drawn in this window anyway.
- **Tests:** `tests/headless/test_wave_grid.tcl` `GT*` — 44 nogui / 80 DISPLAY
  including a real Ctrl-G, the sweep-survival seam, the menu checkbutton's type
  and double-invert, the change-only log rule and "not an undo point".

## Graph grid density (viewer plan item 2, 2026-07-29)

**The graph grid keeps every line and every colour but lights half as many
pixels**: the dash duty cycle goes from 2-on/2-off to 1-on/3-off. One
rc-overridable var, `wviewer_grid_dash_off` (default **3**), read lazily at
strip-template time and folded into a new per-rect prop token `griddash`.

- **Which grid (D-A).** The *graph* grid (`draw_graph_grid`, `draw.c` ~3440),
  not the schematic dot grid — `wave_viewer.tcl` already does
  `xschem set no_grid 1` on the viewer ctx for life, so the dot grid is not
  present in a waveform window at all.
- **Which reading of "reduce pixel density by 50%" (D-B).** Not the line count
  (`subdiv` 1→0) and not the colour: the **duty cycle**. `XSetDashes` had always
  been called with a **one-element** dash list, which makes the on-run and the
  off-run equal — a 50% duty cycle. `griddash` is the OFF run against a
  **1-pixel ON run**, so the default 3 gives 1-on/3-off: *the same 4-pixel
  period, half the lit pixels*. `griddash=0` restores the shipped pattern
  exactly.
- **⚠ This needed a change to `drawline`, the most shared drawing routine in
  the program** (~86 call sites), because a 1-on/3-off pattern needs a
  two-element dash list and `drawline` took a single `dash` int. It was split
  into a `drawline_duty(..., dash, dash_off, ...)` core plus a `drawline`
  wrapper delegating with `(dash, dash)`. **X11 treats a 1-element list `{d}`
  and a 2-element `{d,d}` identically** — the pattern alternates on/off through
  the list and repeats — so every existing call site is byte-identical.
  The alternative considered and rejected: a mutable global consulted *inside*
  the primitive. That is the same landmine class as the shared
  `xctx->graph_struct` — it would leak onto every later line through any early
  return.
- **Blast radius.** `draw_graph_grid` is shared with every embedded schematic
  graph, so the knob is a **per-rect token** emitted only by `graph_props`, the
  viewer's own rect generator. The C `add_graph` template has no `griddash`.
  Defaulted **before the `RECT_OUTSIDE` early return** like `active` /
  `reorder_handle` / `legendbold` (shared `graph_struct`, landmine 37a), and
  clamped in C as well as in Tcl.
- **The axis marks, the box delimiters and the zero lines are solid** and stay
  solid — they pass `dash = 0` and are not part of the grid's duty cycle.
- **`dash_on` stays 0 when `dash_size` is 0**: at that zoom the grid is already
  solid, and a solid line has no duty cycle to halve.
- **Tests:** `tests/headless/test_wave_grid.tcl` — 27 under `--nogui` (`GP*`
  clamp + token, `GD*` the drawline split incl. a tripwire on the wrapper's
  exact shape, `GB*` blast radius) plus the `GG*` rect legs on DISPLAY.
  **⚠ The PIXELS are eyeball-only**: there is no C→Tcl getter for a
  `Graph_ctx` field and no way to read back an X GC's dash list. The
  behavioural evidence for the `drawline` refactor is the rest of the wave
  suites staying green.

## Legend text size + weight (viewer plan item 1, 2026-07-29)

**The viewer legend is drawn at the size of the Y-axis numbers and in the bold
face.** Two rc-overridable vars, `wviewer_legend_textmag` (default **1.63**) and
`wviewer_legend_bold` (default **0**), read lazily at strip-template time and
folded into the per-rect prop tokens `legendmag` / `legendbold`.

> **⚠ REVERSED BY REVIEW, 2026-07-29.** The plan's recorded decision was "both
> size and boldness — every legend entry drawn `CAIRO_FONT_WEIGHT_BOLD`", and
> that is what shipped first. Seen on screen the verdict was the opposite:
> *"the legend is always bolded. We want same font size as axis, but bolding
> only when the associated trace is selected."* So **the size change stands and
> the weight reverts to the issue-0152 rule** — bold marks the SELECTED trace,
> which carries information, where bolding everything is just weight. The knob
> survives (`wviewer_legend_bold 1` restores the all-bold look), and at the 0
> default the C side takes the pre-existing conditional-bold path unchanged.
> **The bold-italic cue below therefore only applies at `legendbold 1`.**

**⚠ The reported symptom named the wrong field.** The ASE legend is **not**
`gr->txtsizelegend` — `graph_props` never emits `vlegend`, `legend` or
`digital`, so `draw_graph_variables` takes its final `else` branch and draws the
signal name with **`gr->txtsizelab`** (`draw.c` ~4025). `txtsizelegend` only runs
on the *vertical* legend path, which this viewer never enables.

**Which axis numbers?** They are not one size, and the two readings are far
apart. From `setup_graph_data` (`draw.c` ~3707-3733), for a strip of container
height `rh` at the template's `divx`/`divy` = 5:

| | formula | value |
|---|---|---|
| legend | `marginy * 0.006 * legendmag`, `marginy = rh*0.14` | `8.4e-4 * rh` |
| X numbers | `min(w/divx*0.0070, marginy*0.0065)` — the margin clamp always binds | `9.1e-4 * rh` |
| Y numbers | `min(h/divy*0.0095, marginx*0.004)`, `h = rh - 2*marginy` | `1.368e-3 * rh` |

So at `legendmag` 1.0 the legend is already **0.92×** the X numbers — matching
those would be an 8% change nobody could see, which cannot be what "too small"
asked for — and only **0.61×** the Y numbers. Hence **1.63 = 1.368e-3 / 8.4e-4**.

- **⚠ The match is exact only at `divy = 5`**, the template's value. `txtsizey`
  scales as `1/divy` while `txtsizelab` does not, so a strip edited to
  `divy = 10` in the Graph dialog has axis numbers half the size and the legend
  then overshoots. Making it exact for every `divy` means computing
  `txtsizelab` **from** `txtsizey` in C — the "new C helper" route decision D-G
  deliberately rejected in favour of driving the existing `legendmag` token.
- **The plan's overlap landmine does not apply on this route.**
  `show_node_measures` draws the cursor-1 value under the name at
  `gr->ry1 + gr->txtsizelab * 60`, sized `gr->txtsizelab * 0.8` (`draw.c`
  ~4126) — **both already proportional to `txtsizelab`**, and `legendmag`
  multiplies `txtsizelab` itself (`draw.c` :3718). Name, offset and value scale
  together and the spacing ratio is unchanged. A helper that scaled only the
  name *would* have collided; this does not.
- **Blast radius (decision D-G).** `draw_graph_variables` is shared by every
  graph in the tree, including the ~127 shipped schematics with embedded
  graphs. The size rides the pre-existing per-rect `legendmag`, and the bold is
  a **new per-rect token `legendbold`** — *not* a global — parsed into
  `Graph_ctx` beside `active`/`reorder_handle` and, like them, defaulted
  **before the `RECT_OUTSIDE` early return** (landmine 37a: `graph_struct` is
  shared, so an off-screen graph that returned early would inherit the previous
  graph's value). `graph_props` is the only emitter, and it is the viewer's own
  rect generator — so on-canvas schematic graphs are untouched, and the C
  `add_graph` template (`scheduler.c` ~1909) still says `legendmag=1.0` with no
  `legendbold` at all.
- **`legendbold=0` is EMITTED, not omitted**, unlike `hilight_wave`/`markers`.
  Those belong to the "absent means absent" class because the C engine writes
  them; this one is generated, and emitting the 0 is what makes an rc that
  turns the bold *off* take effect on a regenerate instead of leaving the old
  value in the rect.
- **The replacement cue for issue 0152 — only needed at `legendbold 1`.** The
  bolded wave's cue *is* "its legend entry is the only bold one"; that only
  breaks down when every entry is bold. On a `legendbold=1` graph the bolded
  wave is therefore distinguished by **slant**: bold italic against bold
  upright. At the 0 default nothing about the weight changes at all. One token in the existing toy-font call, no new drawing
  code, and no layout change (entries sit in fixed per-node slots, so nothing
  shifts). Without `legendbold` the shipped conditional-bold behaviour is
  byte-identical.
- **Clamps.** `legend_textmag` accepts 0.25 .. 6.0 and falls back to 1.63
  otherwise. The comparison form is `>=` / `<=`, **not** `<` / `>`: both `<`
  and `>` are FALSE for a NaN, so the negated form would let a NaN through,
  `atof()` would hand `setup_graph_data` a NaN `txtsizelab` and the strip would
  render nothing at all. `string is double` accepts `NaN`/`Inf`, so it cannot be
  the guard on its own. `legend_bold` fails **safe**: anything unrecognised
  keeps the feature on.
- **Tests:** `tests/headless/test_wave_legend.tcl` — `LP*` pure (33 under
  `--nogui`, incl. the four non-finite legs), `LG1`/`LG2`/`LG4` the tokens
  reaching and surviving on the rects, `LG3` the blast radius asserted against
  the C and Tcl sources. 44 checks on the DISPLAY arm.
  **⚠ The PIXELS are eyeball-only** and the suite says so in its header: there
  is no C→Tcl getter for any `Graph_ctx` txtsize field, and the ASE legend is
  not hit-tested (`edit_wave_attributes` only hit-tests the vlegend strip and
  the digital labels), so "the text is bigger" and "the bolded wave is italic"
  cannot be asserted. Everything up to the renderer's door is.

## Delete Empty Strips (viewer plan item 5, 2026-07-29)

**Bare `e` in the viewer deletes every strip that holds no traces.** Command:
`wviewer::delete_empty_strips ?token?` (optional token, {} = the viewer owning
the current xschem context); also **Graph > Delete Empty Strips** (accelerator
`e`) and CIW-typable. Returns the NUMBER deleted, `0` for a no-op, `{}` plus a
CIW error when no viewer resolves.

- **Two strips are never candidates**, both by user decision:
  - **the auto-plot strip (D-D).** It is *rebuilt* after every simulation run
    (traces cleared, then re-added — item 13's always-replace contract), so it
    is legitimately traceless *between* runs. Deleting it would destroy tool
    state the user cannot see. `empty_graph_indices` already takes the exclusion
    as its `auto` argument.
  - **the last strip standing (D-C).** Right after `Ctrl-D` the model is exactly
    one empty strip, so a literal reading would empty the window. That would not
    crash — `regenerate` handles `n == 0` and `graphs {}` is the legal fresh-open
    state — but `clear_all` deliberately maintains a one-strip invariant. When
    every strip would go, index 0 is spared, which is where `clear_all`'s own
    survivor sits. **Consequence:** `e` on a window holding a single empty strip
    is a no-op that returns without mutating and **without logging**, the
    `move_strip` `from == to` rule.
- **A strip is a dict in the layout's `graphs` list**, so this is a list remove
  plus a `regenerate` — never a schematic delete of the rect. `regenerate`
  re-places every rect from the model and the surplus rects go with it.
- **Ordering: `move_strip`'s contract verbatim** — validate → refuse a no-op
  without logging → verified `switch_ctx` → `capture_live_graph_state` →
  `push_undo` → mutate → remap the stored target **in place** → ONE `regenerate`
  → ONE log line. Snapshot-after-mutate is the shipped bug class this order
  exists to prevent.
- **The stored target follows graph IDENTITY**, through the new PURE
  `wviewer::index_after_removal` — the deletion twin of `reordered_index`, which
  cannot serve here (a move preserves the element count, a deletion does not).
  A target that was *itself* deleted answers with the slot its follower moved
  into; `target_index` clamps every read, so it can never dangle.
  ⚠ **That clamp is also why this is easy to test hollow**: on a fixture whose
  empty strips sit at the bottom, the clamp alone lands on the same index the
  remap would have produced. `EG4` uses an 8-strip fixture with the empties at 1
  and 3 specifically so the two answers differ, and asserts that.
- **Markers** (`graph_markers.md` §9): a traceless strip *should* hold no
  markers, but the model is not its only writer, so `delete_ok`'s bookkeeping is
  reused — the doomed strips' marker numbers are swept out of the survivors'
  `prev` links, because a delta block whose partner is gone degrades to a plain
  callout with no indication at all.
- **No `with_edit`**: unlike `delete_all_markers` this calls no C mutation verb
  the read-only viewer would refuse. Tcl model edit + regenerate, like
  `move_strip`, which is also bare.
- **The key is on the `WaveViewer` BINDTAG**, same rules and same rc-wins
  guarantee as Clear All above:

  ```tcl
  bind WaveViewer <Key-e> {break}                              ;# drop the default
  bind WaveViewer <Key-y> {wviewer::delete_empty_strips_at %W; break}
  ```

  **Collision check, clean on all three paths a key can reach this window by:**
  keysym 101 is **not** in `graphkeys` `{97 98 100 115 109 116 65 66 77}`, so
  `key_filter` forwards nothing and the C dispatcher never sees it (in the
  *schematic*, bare `e` is `descend_schematic`, `callback.c` `case 'e'` with
  `rstate == 0`); no rc binds `<Key-e>` on `.drw`, so `clone_canvas_bindings`
  has nothing to copy in (unlike `Ctrl-E`, which it does clone and
  `strip_bindings` has to sweep); and the `break` holds whatever the lower tags
  carry.
- **Pure half, all headless-assertable**: `wviewer::remove_graphs`,
  `wviewer::index_after_removal`, `wviewer::empty_strips_to_delete` (where D-C
  and D-D live, so both decisions are pinned by assertions rather than by a
  comment).
- **"Empty" is `wviewer::graph_is_empty` — ZERO MODEL TRACES**, and since
  2026-07-29 it is shared with the two gesture reuses below (items 7 and 8) and
  with `plan_plot`'s reuse arm, so all four agree by construction. A strip holding
  only `vec`-less traces draws nothing and is still **not** empty: `e` leaves it
  alone, and neither gesture may consume it.
- **⚠ Interaction with the item 7/8 reuse (2026-07-29): those gestures CONSUME
  empty strips** — item 7 moves a trace into one, item 8 *relocates* one into its
  destination run — so after either there is less for `e` to find. Asserted from
  both sides (`TG18`, `SG18`). Nothing about `e` changed: D-C still spares the
  last strip and D-D still spares the auto-plot strip.
- **Tests:** `tests/headless/test_wave_empty_strips.tcl` — `EP*` pure (28 under
  `--nogui`), `EN*` no-window, `EG1..EG11` GUI; **94 checks** on the DISPLAY arm.
  Sabotage-verified four ways: removing the D-C clause, dropping the target
  remap, moving `push_undo` after the mutation, and skipping the marker sweep
  each turn legs red.

## Trace context menu — RMB → Move to Separate Strip (viewer plan item 7, 2026-07-29)

**A right-click that does not travel, on a trace inside the plot body, posts a
menu whose one entry gives that trace a strip of its own.** Command:
`wviewer::move_trace_to_new_strip <from_gi> <from_ti> ?token?` (optional token,
`{}` = the viewer owning the current xschem context), CIW-typable and logged
replayably. Returns the index of the **destination** strip — an existing empty
strip when one was reused, otherwise the newly inserted one — `{}` plus a CIW
error on a refusal.

- **The gesture is a CLICK, posted on the `ButtonRelease-3`** — not a hold
  timer, and not the press. The item-7 recon enumerated all eight Button-3 sites
  in a viewer window and *measured* that a bare RMB click in the plot body is a
  no-op today, so a click-menu is a pure addition. Posting on the release,
  **after** `btn3_filter` has already forwarded that release to C, dissolves the
  three hazards the plan expected to mitigate:
  - **GRAPHPAN leak** — no grab exists during press→release, so the real release
    reaches C and `GRAPHPAN` clears on its normal path.
  - **Rubber-rect leak** — `callback.c` ~1460 erases the box-zoom outline on that
    same release, before the menu appears.
  - **The modal numeric-cursor `input_line`** is on the **press**
    (`callback.c` ~1097), which this design never touches.
- ⚠ **The travel tolerance is ZERO, and that is not tidiness.** The obvious
  choice — `GRAPH_CLICK_TOL`, the 3 px the LMB wave-bold click uses — is wrong
  here, because Button1 has no box zoom to collide with and Button3 does. The
  engine's box-zoom gate is **exact equality** on the raw pointer
  (`xmoved = (mx_double_save != mousex_snap)`, `callback.c` ~1871), and graph
  interaction deliberately disables the snap grid (`callback.c` ~810, issue
  0143) — so a release **one pixel** from its press has already committed a
  zoom. A 3 px tolerance posted the menu on top of one, and the gate then ran
  against the post-zoom geometry: probe-verified, the menu simply vanished
  because the trace had moved out from under the pointer. Zero makes menu and
  box zoom mutually exclusive by construction.
- **Gate**, all rungs failing closed (`wviewer::trace_menu_pick`, returns
  `{gi ti}` in MODEL index space or `{-1 -1}`): inside a strip →
  `node_count >= 2` → a trace within `graph_trace_at`'s tolerance → a live model
  trace index. The `node_count` rung mirrors the command's own refusal: a menu
  offering an entry the command will refuse is worse than no menu.
  - **Empty waveform space is deliberately not claimed** — that is item 8's.
  - ⚠ **Digital and bus strips get no menu at all**, and that is the engine's
    answer rather than a choice: `graph_wave_at` documents "digital strips and
    bus traces answer -1 (their rendering is a band/ribbon, not a polyline)"
    (`draw.c` ~4711), so `trace_at` misses everywhere on such a strip. It is the
    same limit the LMB trace drag already lives with, and the two must not
    diverge.
  - **A press made while a MARKER drag was armed keeps the whole gesture.** A
    non-Button1 release *aborts* that drag (`callback.c` ~866), so a menu there
    would be a side effect of cancelling something else. The arm can only be
    seen on the **press**, so `btn3_filter` records it (`b3mk`) and refuses on
    the release; `trace_menu_pick` stays a question about geometry alone.
  - **A modified RMB is refused** (`state & 13` = Shift|Control|Mod1, the
    `strip_drag_press` mask). On a release `%s` reports the pre-release state, so
    Button3Mask is set and must be ignored.
  - **A release with no recorded press posts nothing.** That is also what makes
    the second half of a double-RMB inert: `<Double-Button-3>` is `{break}`, so
    the second *press* never reaches the filter, and the second *release* finds
    the record already dropped.
- **The payload is `move_trace` plus ONE `linsert`**, and deliberately **not**
  `add_graph` — which regenerates on the spot and takes neither an undo point nor
  a log line, so a strip created that way would land between the capture and the
  mutation and split one gesture into two half-states. An inserted strip goes
  **directly below the source** (D-F's reading-order rule, which item 8's split
  follows), and the move itself is the shipped PURE
  `wviewer::move_trace_in_graphs`: marker migration, the `hilight_wave` hand-off
  and the empty-destination range blanking all come from there, with no new index
  math.
- **REUSE BEFORE CREATE (2026-07-29).** When the stack already holds an empty
  strip, the trace is moved **into it** and nothing is inserted. Same rationale
  `plan_plot` records for plot batches (issue 0171's follow-up): an empty strip
  *is* a place to put a trace, and appending past one pins a blank band on the
  window and shrinks every real strip for nothing. `wviewer::empty_graph_indices`
  supplies the candidates and the whole choice is the PURE
  `wviewer::reuse_strip_for_trace_move` (headless-assertable with literal lists);
  `-1` means "insert one".
  - **EMPTY means ZERO MODEL TRACES**, not `node_count == 0` — stated here rather
    than left implied, because the two differ: a strip holding only `vec`-less
    traces draws nothing yet is **not** empty and must never be consumed or
    deleted. `wviewer::graph_is_empty` is now the single definition, shared by
    this gesture, item 8's split, `plan_plot`'s reuse and `e`'s kill list. It
    fails **closed** on a malformed entry (⚠ `dict exists` is lenient — it
    answers 0 for a non-dict instead of erroring, so the well-formedness test has
    to be explicit; without it the split moved a trace *into* a non-dict).
  - **D1, WHICH empty strip when several are free:** the **nearest below** the
    source, else — only when none is below — the **nearest above**. "Below" is
    D-F's reading-order direction and is where an inserted strip would have gone;
    "nearest" keeps the trace close to where it was picked up. The direction
    preference is **strict**: an empty strip below wins even when one above is
    nearer (`TP35`).
  - **D2, distance: a FAR empty strip is taken.** Deliberate — it is what was
    asked for, and it matches `e`, which treats every empty strip alike wherever
    it sits. The "trace teleported seven strips away" reading is answered by an
    optional cap, `wviewer::reuse_max_distance` (`::wviewer_reuse_max_distance`),
    **OFF by default** (0 = no cap) and applied *before* D1's direction
    preference so a capped-out strip below does not block a reachable one above.
  - **D5, the target:** unchanged — the **destination** becomes the target strip,
    reused or new (`move_trace` step 6). The reuse arm needs no index remap at
    all: nothing is inserted, so nothing moves.
  - **The auto-plot strip is never consumed** (D-D, the `e` rule): it is
    traceless *between* runs and item 13 rebuilds it after every one, so a trace
    parked there is silently destroyed at the next run. The exclusion is
    `empty_graph_indices`' `auto` argument, fed from `wviewer::auto_graph_index`.
  - **Autozoom comes for free**: `move_trace_in_graphs` blanks an empty
    destination's `x1/x2/y1/y2` back to `auto`, so a *reused* strip's stale
    ranges go too and `regenerate` re-fits it exactly as it does a fresh one.
  - **Boundary, recorded not closed:** a traceless strip *should* hold no
    markers, but the model is not its only writer — a stale `markers`/
    `hilight_wave` key on a reused strip would now annotate whatever lands there.
    Identical exposure to the shipped `plan_plot` reuse arm; not made worse here.
  - **Replay stays deterministic** and it is asserted, not assumed: the log line
    carries the source indices only, so a replay *recomputes* the choice — sound
    because the choice is a pure function of the model a replay reproduces
    (`TG17` undoes, replays the logged line and compares strip identities).
- **Ordering: `move_strip`'s contract verbatim** — validate → refuse without
  logging → verified `switch_ctx` → `capture_live_graph_state` → `push_undo` →
  insert + pure move → target **in place** → ONE `regenerate` → ONE log line.
- **The NEW strip becomes the target**, `move_trace` step 6 verbatim (the
  destination is the target), set in place rather than through
  `set_target_strip`, which would emit a second replay-log line for an internal
  consequence of one command.
  ⚠ **`target_index` clamps every read**, so this is easy to test hollow: on a
  shallow stack "the new strip is the target" is also what a command that never
  touched the target would answer. `TG4` uses a five-strip fixture with the
  target on strip 4 and the source on strip 1 specifically so the two differ.
- **No `with_edit`**: no C mutation verb the read-only viewer would refuse. Tcl
  model edit plus `regenerate`, like `move_strip` and `move_trace`.
- **The menu widget** is a real Tk `menu` on the viewer TOPLEVEL
  (`$top.wvtracemenu`) — out of reach of the canvas binding sweep — rebuilt on
  every post, because its entries carry *this* click's indices. Entry 0 is a
  disabled header naming the picked trace by the legend's own rule
  (`wviewer::trace_label`): a click near two traces resolves to the nearest, and
  the user is entitled to see which. `tk_popup` supplies the grab, Escape and
  click-away; `wviewer::trace_menu_unpost` drops it, and `forget` calls it so a
  grab can never outlive its window.
- **No menubar twin.** Unlike every other item here, the operation needs a trace
  under the pointer, which a menubar entry does not have. The context menu is the
  whole surface.
- **Known boundary, recorded rather than desired**: an RMB press within 10 px of
  a drawn cursor *and* on a trace opens the modal numeric-cursor `input_line`
  first; the menu then posts when it is dismissed. Escape closes it. Closing this
  would need a C-side cursor-proximity query (the `graph_near_wave` precedent),
  and the press path is unchanged either way.
- **Tests:** `tests/headless/test_wave_trace_menu.tcl` — `TP*` pure + `TN*`
  no-window (**71 checks** under `--nogui`), `TG1..TG18` GUI; **223 checks** on
  the DISPLAY arm. `tk_popup` is spied rather than called in the gesture legs: a
  live popup takes a global grab that would swallow every later leg's events.
  Sabotage-verified seven ways — restoring the 3 px tolerance, inserting at the
  end instead of below the source, dropping the `>= 2` refusal at the command
  and again at the gate, keeping the press record past the release, removing the
  marker rung, and skipping the target write each turn legs red.
  ⚠ **The reuse legs (`TG12..TG18`) are the ones that go hollow the most
  easily**: consuming the strip at `from_gi + 1` and inserting one there leave the
  trace at the same index, so a leg checking only `vecs_at` passes either way.
  Both discriminators are asserted on every reuse leg — the strip **COUNT**
  (reuse never grows the stack) and strip **IDENTITY** (an inert `tmid` key per
  fixture strip, so a strip the gesture *created* reads back as `-`; the
  `test_wave_viewer.tcl` SD legs set the precedent). Sabotage-verified five more
  ways: never reuse → `TG12/13/16/17/18` red; reuse unconditionally →
  `TP31/33-45` + `TG1` red; above-before-below → `TP35`; dropping the auto
  exclusion → `TG15`; writing the insert-arm index to the target → `TG13`.
  The `e` interaction is asserted too (`TG18`): a consumed strip is one `e` no
  longer finds, and D-C (never delete the last strip) still holds.

## Strip context menu — RMB → Split Strip (viewer plan item 8, 2026-07-29)

**A right-click that does not travel, on waveform space with no trace under it,
posts a menu whose one entry splits that strip into one strip per drawn trace.**
Command: `wviewer::split_strip <gi> ?token?`, plus **Graph > Split Strip**, which
acts on the **target** strip (the one carrying the active bar — a menubar entry
has no pointer position to resolve). Returns the NUMBER of **new** strips — which
with reuse may be **0**, still a success — `{}` plus a CIW error on a refusal.

- **Decision D-F**: node 0 **keeps** the original strip; the remaining drawn
  traces get strips directly **below** it, in order — a strip reading `a, b, c`
  becomes three strips reading `a, b, c` top to bottom. A full split, not a
  one-trace peel-off. Traces carrying an empty `vec` reach no node slot, so they
  are not traces for this purpose and stay with node 0.
- **REUSE BEFORE CREATE (2026-07-29): the split RELOCATES an empty strip.** The
  whole decision is the PURE `wviewer::plan_split` -> `{ok take src at block new}`,
  called by both `split_graph_in_graphs` (the model op) and `split_strip` (the
  target remap), so the two cannot disagree about what moved where.
  - ⚠ **D3 was REVISED the same day, after the first cut was driven for real.**
    v1 could consume only the strip at *exactly* `gi + 1` ("adjacency in place"),
    and that almost never fires. The reported repro: three strips of one trace
    each, drag strip 1's trace down onto strip 2 (strip 1 goes empty), then split
    strip 2 — it is bottom-most, so `gi + 1` does not exist, the free strip sits
    **above** it, and v1 inserted a fourth strip right next to a blank one.
  - **D3 (v2): the nearest empty strip in the WHOLE stack is taken** — D1's order,
    nearest below first, then nearest above — **and RELOCATED into the destination
    run** rather than filled where it lies. That reconciles the two constraints
    which made v1 narrow: D-F's reading order survives because the strip is
    *moved* to below the split strip (nothing ends up above node 0 — filling an
    empty strip above **in place** is what would break it, and that stays
    forbidden), and the strip count does not grow while any empty strip exists.
    Relocation preserves the relative order of every *other* strip: lifting one
    strip out and re-inserting it lower down moves only itself.
  - **D4, the shortfall:** a split needs `nc - 1` destination strips; as many as
    are available are relocated (nearest first, taking the slots nearest the
    source) and only the shortfall is created. **Zero created is normal** —
    `nc == 2` with one empty strip anywhere creates nothing at all.
  - **`split_strip` then returns 0.** ⚠ **0 is a SUCCESS, not a refusal** — it
    mutates, it takes an undo point and it logs; only `{}` means nothing happened.
    A caller testing `if {!$n}` would read a legitimate split as a failure.
  - **The auto-plot strip is never taken** (D-D), and "empty" is
    `wviewer::graph_is_empty` — **zero MODEL traces**, the same definition item 7,
    `plan_plot` and `e` use, failing closed on a malformed entry.
  - **D2's distance cap is shared** with item 7 (`reuse_max_distance`, OFF by
    default): both gestures now travel, so one config governs both.
  - **D5, the target remap is a REMOVAL then an insertion** — the PURE
    `wviewer::target_after_split`, never a bare `index_after_insert`: relocating a
    strip from above the split lifts every strip below it up one slot *before* the
    destination block goes in, and a target that **is** the relocated strip
    follows it into its slot by identity. The insertion count is the whole
    `block` (`nc - 1`), not the created count.
    ⚠ `SG16` separates the correct answer from the clamp-alone answer but **not**
    from the bare-insert answer (on a six-strip stack the clamp pulls 6 back to
    5); **`SG12` is the leg that catches a bare `index_after_insert`**, and `SP48`
    pins the arithmetic itself.
  - **Replay stays deterministic**: the logged line is still `split_strip <gi>
    <token>` with no plan in it, which is sound because `plan_split` is a pure
    function of the model a replay reproduces. Asserted in `SG17`, not assumed.
- **The core is a LOOP over the shipped `move_trace_in_graphs`**, not fresh index
  math, and that is the whole point: every iteration gets the marker migration,
  the `hilight_wave` hand-off and the empty-destination range blanking for free,
  so `graph_markers.md` §9's obligations are discharged **by construction**.
  Nothing in `split_graph_in_graphs` touches a marker record. (That blanking is
  also what makes reuse free: a consumed strip's stale ranges go back to `auto`,
  so `regenerate` re-autozooms it like a fresh one.)
  Two ordering rules make that safe: **every destination strip is in place
  first** — created, or relocated from elsewhere in the stack — so node *k*'s
  destination is `src + k` and never moves under the loop (`src` is the split
  strip's index *after* the relocations are lifted out, which is why `plan_split`
  reports it rather than leaving the loop to recompute `gi`);
  and the traces move **descending**, from the last node to node 1, because
  removing node *k* renumbers only the nodes above it — which are already placed.
  Ascending renumbers the remaining work on every step (sabotage-verified: it
  scrambles the result).
- **Ordering: `move_strip`'s contract verbatim**, with the same refusal rule — a
  strip with fewer than two drawn traces is already split, so the command
  returns without mutating and **without logging**, and the menu gate mirrors it.
- **The target follows graph IDENTITY** through the new PURE
  `wviewer::index_after_insert` — the **insert** twin of `index_after_removal`,
  and `plot_signals`' multi-plot `cur + nnew` arithmetic generalised to an
  arbitrary insertion point. Unlike item 7 there is no single destination to
  adopt, so the target stays on whatever strip it was on; the source strip does
  not move, so a target that *was* the split strip stays with node 0.
  ⚠ Same clamp trap as everywhere else: `SG4` puts the target *below* the split
  on a four-strip stack specifically so the shifted and unshifted answers differ.
- **Gate** (`wviewer::strip_menu_pick`, returns the strip index or -1), all rungs
  failing closed: inside a strip → **inside the PLOT BOX** → `node_count >= 2` →
  **no** trace under the pointer.
  - ⚠ **The plot-box rung is not decoration, it closes a real collision.** The
    first cut asked only "no trace here", which the **legend/label margin** at
    the top of every band also satisfies — and a Button3 **press** there is
    already the wave-attributes dialog (`callback.c` ~896), so the menu posted on
    top of it. Tcl cannot re-derive the box (the margins come out of the engine's
    transform), so this exposes `draw.c`'s existing `graph_plotbox_at` — item 9's
    snap-cursor gate — as a new read-only getter, **`xschem get graph_plotbox_at
    <gi> <px> <py>`**. The C function is used unchanged.
  - **The trace rung is what makes the two menus partition the body**: the strip
    gate refuses any pixel the trace gate accepts, by asking `trace_at` itself.
    `wviewer::ctx_menu_post` also offers the trace menu first, but that ordering
    is a second line of defence, not the separator — reversing it leaves the
    suite green.
- ⚠ **Digital and bus strips get NO context menu at all**, and this is the
  answer to the plan's open question about landmine 33. Both engine queries
  refuse them: `graph_wave_at` because their rendering is a band/ribbon rather
  than a polyline (`draw.c` ~4711), and `graph_plotbox_at` for the same reason
  (`if(gr->digital) return 0`). So neither menu fires there. Recorded rather than
  closed: relaxing it means relaxing `graph_plotbox_at`, which would also change
  item 9's snap cursor.
- **Everything else is item 7's plumbing, unchanged**: the same no-travel
  `ButtonRelease-3` with a **zero**-pixel tolerance, the same modifier and
  marker-arm refusals, the same press record, and the same
  `ctx_menu_widget`/`_drop`/`_popup` helpers (the trace menu was refactored onto
  them; its widget path and proc signatures are unchanged).
- **Tests:** `tests/headless/test_wave_split_strip.tcl` — `SP*` pure + `SN*`
  no-window (**80 checks** under `--nogui`), `SG1..SG18` GUI; **221 checks** on
  the DISPLAY arm. Sabotage-verified five ways — dropping the plot-box rung
  (which reproduces the margin collision), running the split loop ascending,
  dropping the target shift, and dropping the trace exclusion each turn legs red;
  reversing the dispatcher order does not, which is why the comment there says so.
  ⚠ **The relocation legs (`SG12..SG18`) carry the same hollowness risk as item
  7's** and answer it the same way: the strip **COUNT** (relocation never grows the
  stack while an empty strip exists) and strip **IDENTITY** (an inert `smid` key,
  so a created strip reads back as `-`). `SG12` *is* the reported repro, driven end
  to end. Five more sabotages, each red somewhere different: never relocate →
  `SG12/13/14/16/17/18` + 11 `SP*`; not shifting `src` through the removal →
  `SG12/14/16` + 7 `SP*`; above-before-below → `SG14` + `SP35/36/37/46`; a bare
  `index_after_insert` for the target → `SG12` + `SP48`; dropping the auto
  exclusion → `SG15` + `SP38`. The `e` interaction is asserted in `SG18`.
  (An earlier v1-era sabotage worth keeping on record: making reuse
  unconditional went red at `SP11` by moving a trace *into* a non-dict sentinel —
  that is how the fail-open `graph_is_empty` bug was caught for real.)

## Mid-drag shrink preview (viewer plan item 6, 2026-07-29)

**While a trace is being dragged to another strip it is drawn shrunk in BOTH
axes about the plot box centre**, so the pointer visibly carries something and
the dragged trace stops being confusable with the ones it passes over. Decision
D-E: the **TRACE** drag (LMB press on a trace → drop on another strip). The strip
reorder drag gets no preview.

⚠ **REVISED ON REVIEW 2026-07-29.** It shipped as a 10 % shrink in **Y only**,
which is what the plan asked for, and was rejected on sight: *"shrink should be
in both X and Y, not just Y. Bump up the shrink to 30 %."* Y-only reads as a
gain change rather than a pick-up, and 10 % is below the threshold where the eye
notices at all. Final: **both axes, `wviewer_drag_shrink` default `0.7`.**
Item 1's lesson again — a decision about how something looks is provisional
until it has been looked at.

- **Render state only.** Three transient `xctx` numbers —
  `graph_preview_scale` / `_gi` / `_wave` — and nothing else: no prop token, no
  model write, no undo point, no log line. That is the marker-scratch idea
  (`graph_markers.md` §3.5) applied to a polyline instead of a marker record, so
  a motion event costs nothing. Armed **once**, when the gesture passes the 3 px
  threshold, because nothing about it changes as the pointer moves.
- **`graph_preview_scale == 0.0` is the ARM**, and it is the free `my_calloc`
  default — the other two fields are only meaningful when it is non-zero. That
  is deliberate: a `-1` sentinel would have to be maintained in
  `alloc_xschem_data()` *and* `clear_drawing()`, and forgetting one is the
  shipped bug class. Both reset it anyway, explicitly, so a future non-zero
  default cannot slip in silently.
- **Chrome, not content**: `draw_graph` applies it only for `flags & 16`
  (landmine 18), so **no export ever draws a shrunk trace**. It also needs
  `has_x` — a preview is a thing you look at. `setup_graph_data` defaults
  `gr->preview_wave` to -1 **before** the `RECT_OUTSIDE` early return, the shared
  `graph_struct` rule, so a query that calls it cannot inherit the previous
  graph's arming.
- **Y is scaled per-point, BEFORE the clamp**: `y = c + (y - c) * s` on the
  screen y, where `c` is the plot box centre. After the clamp a rail-clipped
  sample would shrink *from the rail* and put a visible kink where the trace
  leaves the box.
  ⚠ **`gr->cy` is negative** (landmine 3), so `S_Y(gy1)` and `S_Y(gy2)` come back
  in the opposite order to their data values — the centre is their **mean**,
  which sidesteps the ordering instead of assuming it. Same for x.
- **X is scaled IN PLACE and restored**, not per-point, because
  `draw_graph_points` does not own that array: `point[].x` is built by the caller
  and — unlike y, which this function rewrites for every wave — is not
  necessarily rebuilt per wave. So the previewed trace's x values are saved,
  scaled, drawn and put back **verbatim from the saved shorts**. Restoring by
  inverse transform would round; restoring from the copy cannot. One allocation
  per drawn frame of one dragged trace, and only while a drag is live.
- **Analog only.** The arming query (`graph_wave_at`) refuses digital and bus
  strips, so such a trace can never be picked up and never previewed; scaling one
  about the box centre would also drag it out of its own lane.
- **NODE index, not model trace index.** The C side speaks the
  `hilight_wave`/`graph_trace_at` space, so `drag_preview_arm` maps the model
  index through `node_index_of_trace` first. The two diverge as soon as any trace
  carries an empty `vec`.
- **Knob**: `wviewer_drag_shrink`, default `0.7` (a 30 % shrink, applied to X
  and Y alike). `1.0` turns the effect off without disabling the drag; anything
  outside `(0, 1]` falls back — `0` would disarm and a negative would mirror the
  trace.
- **The regression guard the plan asked for**: `graph_trace_at` answers are
  asserted **unchanged** while a preview is armed. The preview is visual only, so
  the drop-target maths must not move under it.
- **Tests:** `tests/headless/test_wave_drag_preview.tcl` — `DP*`/`DN*`/`DV*`
  (**18 checks** under `--nogui`, including the `xschem set/get graph_preview`
  round-trip), `DG1..DG7` GUI; **46 checks** on the DISPLAY arm.
  ⚠ **What no leg covers: that the trace actually looks smaller.** Nothing here
  can read pixels back, and unlike the arming there is no seam to spy — the
  scaling happens between `S_Y()` and `XDrawLines`. The Tcl half is
  sabotage-verified four ways (no arm on drag, arming with the model index, no
  disarm on reset, ignoring the rc knob); **the C render line itself is
  eyeball-only and was not sabotage-verified**, because no assertion could have
  caught it.

## Strip drag-to-reorder (2026-07-27)

Full contract: `doc/claude/specs/waveform_viewer_modes.md` §12. As shipped:

- **LMB drags a whole strip up or down the stack.** A strip is one graph dict of
  `wviewer::layouts` — traces, colors, axis settings and any `auto 1` marker move
  as one list element; the order of traces *inside* a strip never changes.
- **Two grab surfaces:** a **14-screen-pixel handle** at the strip's right edge
  (the C engine draws a three-bar grip in it, prop token `reorder_handle`) and
  **empty waveform body**. A fixed **10-screen-pixel zone around every trace**,
  and any press that grabbed a cursor, stay with the C engine — cursor drags,
  trace picking and the LMB wave-bold click (issue 0152) are unchanged. That seam
  is deliberately reserved for future LMB trace-to-strip dragging.
- **The gesture:** >3 px of vertical travel starts it; crossing another strip's
  midpoint selects it; past the ends it clamps; release commits; **Escape
  cancels**; a sub-threshold click and a drop back at the origin do nothing and
  log nothing. The destination is shown by a bar on the edge the strip will
  arrive at, painted by rewriting `reorder_handle` on the two affected rects —
  never by regenerating the stack.
- **`wviewer::move_strip <from> <to> ?token?`** is the one authoritative
  mutation, with pure `reorder_graphs` / `reordered_index` underneath. It
  captures the live C-written rect state first
  (`wviewer::capture_live_graph_state`: `x1 x2 y1 y2 hilight_wave`), so a reorder
  cannot undo a pan/zoom/bold the user just made with the mouse; it remaps the
  target with `reordered_index` so the marker follows graph IDENTITY; it
  regenerates once and logs one resolved line (preceded by a `set_target_strip`
  line only when the press actually moved the target).
- **The graph pan moved from LMB to MMB** (`callback.c`, engine-wide) to free LMB
  for this. Two new read-only verbs back the seam: `xschem get graph_near_wave`
  (real screen-pixel distance to a drawn trace) and `xschem get graph_flags`.
- **Tests:** `test_wave_modes.tcl` `M7`/`MG14` and `test_wave_viewer.tcl` `SD*` +
  `WB-mmb-drag` — sabotage-verified against 9 independent breakages. The grip and
  drop-bar PIXELS are eyeball-only, like the wave rendering itself.

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
