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
  `<B2-Motion>`). `waves_selected` (callback.c:88-92) explicitly skips Button-2
  so the schematic pan keeps working over on-canvas graphs — meaning MMB in the
  viewer could only ever be `start_pan_logged()`. Ctrl+MMB (the
  `edit.cycle_pin_type` chord, a readonly modal) dies with it.
- **Arrows intercepted, never forwarded** (`wviewer::arrow_pan`): bare
  Left/Right/Up/Down pan the graph, every modified arrow is swallowed. See the
  item-19 note above for what each forwarded form used to do.
- **`<Shift-…>`/`<Alt-Button-1>` triples swallowed** — rubber-band/copy-drag and
  unselect-at-pointer, canvas-only by the same `waves_selected` skips.

Not a hole (recorded in issue 0149): a graph rect can still be *selected* by a
click in the 5 px `border` inset at a band edge — cosmetic; the drag-move itself
is gated on `!xctx->readonly`, so nothing in the viewer can be moved or deleted.
Making a graph "move" (swap strip positions) is future work, deliberately NOT a
schematic move.

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
  beats reuse.
- **Tests:** `tests/headless/test_wave_clear_all.tcl` (`CA*` no-window, `CG*`
  GUI) — 67 checks, sabotage-verified. Documented in `src/cadence_style_rc`.

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
