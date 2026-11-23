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
  graph is emptied). ⚠ Since ase_l.md R-OUT14 (2026-10-15) that holds in
  single-plot only: in multi-plot the auto-plot owns one `auto 1` strip per
  row (`wviewer::auto_plot_strips`), still rebuilt every run, with surplus
  auto strips removed and missing ones inserted.
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
"v1 queues source currents only" notice and plot nothing. (That was the miss
notice of the time; since issue 1724 it reads "nothing to queue there — click
a wire or a net label for a voltage, an instance pin for its terminal current,
or a voltage source/ammeter for its current".) Two causes:

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

## Terminal currents from a pin click (issue 1724, 2026-11-19)

Full detail: `doc/claude/specs/ase_l.md`, "A click on a device pin queues its
terminal current" (the pick) and R-OUT17 (the deck and the report).

- In Select On Design and in Direct Plot a click **on a device pin** queues the
  current into that terminal, `i(<path>:<tname>)` (`i(x1.xm1:d)`, `i(r1:n1)`).
  A click on a source's or an ammeter's body is still its branch current, and
  a click on a wire, off the pin's own square, is still the wire's voltage.
  While the mode is up the design window's prompt names the pin a click would
  take, as long as the pointer is in the window the mode is on, and a click
  in a window that does not show the session's design queues nothing and
  says so (ase_l.md T12).
- **Direct Plot plots a terminal only if the last run saved it.** Direct Plot
  writes no session row, so it adds no probe to a deck. The click queues the
  trace when the session's results file lists the vector, and otherwise says
  *"ase: terminal current 'i(x1.xm1:d)' is not in this session's results"*
  and why, where that is known (`ase::ui::sod_terminal_pick`,
  `ase::probe_absent_groups`; ase_l.md T9): *"…: <program>, the simulator of
  the last run, cannot save it. <which registered simulator can, and where to
  pick it>"* when the last run's report said so (ending *"<entry> is picked
  now — run again."* once the session has picked one known able); the reason
  that report gave for any other terminal; *"…: it is set to be saved, and
  these results are from before that — run again."* (or, where that cannot be
  told, *"… but these results do not hold it — run again."*; with no results
  at all, *"… and this session has no results yet — run."*) for a row that is
  already set -- ending, for a terminal below the top level when the session's
  simulator is already known unable, with that program, that it cannot save
  the current, and which registered one can, in place of *"run again"*; and
  for a terminal nothing is known about, *"… — pick it under Outputs > To Be
  Saved > Select On Design and run again"*. This is the terminal's form of
  item 14's finding above, that Direct Plot needs the net saved.
- **Except on the pin of a voltage source or an ammeter.** When that pin's
  terminal is not in the results, or cannot be named, the click plots the
  source's own branch current `i(v1)`, as a click on its body does
  (`ase::ui::sod_terminal_as_source`). Every run holds that current, and it
  is what the same click plotted before pins were picked. On the source's
  first pin, alone on its point, nothing more is said. On its second pin the
  trace is the negative of that pin's own current (`i(v1)` is `i(v1:n1)` and
  the negative of `i(v1:n2)`), and the click says so; on a pin that is
  neither (a controlling pin of a controlled source) it says that the trace
  is not that pin's current; on a point shared with another device's pin it
  names that pin and says it took the source's current
  (`ase::ui::sod_source_standin_notes`; the sentences are in ase_l.md T9).
  If the window Direct Plot is on is closed with traces queued, none is
  plotted and the CIW says how many (ase_l.md T12).
- **The name in the viewer has a dot.** ngspice writes the vector as
  `i(x1.xm1:d)`; `read_dataset()` stores every `:` of a variable name as `.`,
  so `xschem raw list` and the signal browser show `i(x1.xm1.d)`. A trace
  expression in either spelling resolves: `wviewer::name_rungs` appends the
  dotted spelling's candidates for a token that holds a `:`, mirroring rung 5
  of `get_raw_index_in()` (`doc/claude/specs/raw_case_mode.md` §9).
- **The picked pin carries an ellipse in the trace's colour.** The pick hands
  the plot queue the pin, `{<instance index> <pin index>}` of the sheet shown,
  and `ase::ui::dp_hilight terminal <pin> <layer>` runs `xschem pin_marker add
  -layer <layer> -tag plot` (`doc/claude/specs/pin_selection.md` §4.7). The
  layer is the one `ase::ui::dp_queue` takes from `wviewer::predict_colors`
  and hands to `plot_signals`, so the ellipse and the trace cannot disagree:
  measured with the real viewer after a real click and a real ESC, the
  trace's `color` is the marker's layer and the marker's pixels are that
  layer's colour. Any other token under kind `terminal` (the vector's name, a
  net's name) answers 0 and asks the engine nothing: handed to
  `hilight_netname` such a word would colour nothing, or an unrelated net of
  that name. The ellipse stays past ESC, as the net and source colours of
  issue 0153 do, and `xschem unhilight_all` clears it with them, in the
  window it is given in and in the windows linked to it by a descend. The
  source stand-in above colours the source's body and marks no pin.
- **Only Direct Plot's ellipse has its trace's colour, and only while that
  trace is there** (declared). A pin picked under Outputs > To Be Plotted has
  the light-green ellipse of a saved one, which goes when the mode ends, and
  its waveform, plotted after the run, has the viewer's next colour. And a
  Direct Plot ellipse keeps its colour until the highlights are cleared: after
  a run whose plot replaces the viewer's traces (a row with Plot ticked,
  destination Replace) it shows the colour of a trace that is gone, or that
  another signal now has, as a Direct Plot net colour does.
- **In the Signal Browser** a terminal current files under a node named after
  its device and is labelled by its terminal (`d:i`, `in_p:i`;
  `doc/claude/specs/waveform_signal_browser_two_pane.md` §5.4). `Descend to
  here` on such a node is the device ending of *Hierarchy sync*, below.

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
  (2026-11-22: "well inside" is `wviewer::pan_inset_px`, which follows the
  Tk scaling; see "A key that came through another window", the rider.)
- **Arrows intercepted, never forwarded** (`wviewer::arrow_pan`): bare
  Left/Right/Up/Down pan the graph, every modified arrow is swallowed. See the
  item-19 note above for what each forwarded form used to do.
- **`<Shift-…>`/`<Alt-Button-1>` triples swallowed** — rubber-band/copy-drag and
  unselect-at-pointer, canvas-only by the same `waves_selected` skips.

Not a hole (recorded in issue 0149): a graph rect can still be *selected* by a
click in the 5 px `border` inset at a band edge — cosmetic; the drag-move itself
is gated on `!xctx->readonly`, so nothing in the viewer can be moved or deleted.
(2026-11-21: that inset WAS a hole for KEYS. A graph key pressed there ran the
engine's canvas arm; see "What the key filter forwards" below.)
Making a graph "move" (swap strip positions) shipped on 2026-07-27 as strip
drag-reorder (below) — and, as anticipated here, it is deliberately NOT a
schematic move: it is a list move on the Tcl model followed by a regenerate.

## What the key filter forwards (2026-11-21)

Contract: **no key that arrives at a viewer's canvas reaches an editor verb of
the engine**, in the stock profile and in the Cadence one. A key arrives there
while that canvas has the keyboard focus. The engine gives the canvas the
focus when the pointer's entering SWITCHES the context to the viewer (with
`mouse_follows_focus` on, as it ships), and a click in the plot gives it too.
A viewer that has just been opened is already the current context, with the
focus on its toplevel: the pointer coming into its plot switches nothing and
brings no focus, and no viewer key works there until one click in the plot
(see the limits).
(Amended 2026-11-21, second repair of this item: the line read "no key pressed
in a viewer window". That is more than a filter on the viewer's canvas can
keep. A key that reaches the engine through ANOTHER window's canvas while the
viewer's context is current is outside it: see the limits. Amended again the
same day, third repair: the second sentence read "the engine gives it the
focus when the pointer comes in from another window", which is false for the
state every viewer is in right after it opens. Amended 2026-11-22: both of
those states are closed. A key typed in a schematic window while the viewer's
context is current and the pointer is in the viewer is now handed to this same
filter, and so is a key typed while the viewer's toplevel holds the keyboard
(where an open still leaves it) and the pointer is over the plot; see "A key
that came through another window" below. The sentences above about the click
are history.) The read-only flag
was never that guarantee: it stops object mutation, and several of the verbs below
are not mutations (a reload prompt, a Save form, a new window, a view toggle),
while `m` and `d` are forwarded with read-only lifted.

Before this date `wviewer::key_filter` forwarded a graph key by KEYSYM (the
list `graphkeys`, with carve-outs for Ctrl-d and Ctrl-b) whenever the mouse
mirror sat inside a strip. The engine then decided again, by modifiers,
profile, binding table and its own graph test, and where it decided "not the
graph" the same keysym was an editor verb. Measured in a viewer on the product
of that day, pointer in the middle of a strip unless said otherwise:

| chord | what it reached |
|-------|-----------------|
| Ctrl-Shift-M, Caps Lock + Ctrl-m | the "View is Read Only" message box (the schematic's move) |
| plain `s`, Cadence profile | the same box (the snapped wire) |
| Alt-s, Super-s | "Are you sure you want to reload from disk?" |
| Ctrl-Alt-s | the Save-as-symbol form |
| Ctrl-Alt-t | a new schematic (a tab of the main window) |
| Alt-b, Super-b | stepped `hide_symbols`, a global |
| Alt-m, Super-m | with `infix_interface` off, a move armed in the viewer (`ui_state` MENUSTART); with it on, the move started on an empty selection |
| a graph key two pixels inside a strip's edge | the canvas arm: `a` the make-symbol prompt, `s` the run-simulation prompt, `b`/`t`/Shift-M/Shift-B the read-only box, `m` an armed move, Ctrl-s the Save form |
| a bare graph key with `graph_use_ctrl_key` set | the canvas arm, anywhere over a strip |
| a user's `canvas` row in the binding table for a chord the filter forwards (bare `m`, Ctrl-Shift-M) | the row's action, run from the viewer |
| Escape, with a row of the user's for it in the binding table (none ships) | the row's action, run from the viewer (by reading, the abort is skipped too: the engine returns before its Escape arm) |

**The rule.** The filter forwards a graph key only when the engine itself will
hand it to the graph. Two questions, both asked in Tcl before the forward; a
key that fails either is not forwarded, and then nothing happens or the
`WaveViewer` tag runs the viewer's own shortcut for it.

1. **The chord** (`wviewer::key_chord`, pure). With the state reduced the way
   `callback()` reduces it (`wviewer::chord_state`: the bits above the modifier
   range, Num Lock, Caps Lock, Shift and Button-1 dropped), the FILTER forwards
   a graph key in exactly these cases:

   | reduced state | forwarded |
   |---------------|-----------|
   | none | every graph key: `a b d s m t A B M`. Plain `s` only outside the Cadence profile |
   | Control | `a s m t A B`. Never `b`, `d` or `M` |
   | anything else (Alt, Super, any mix) | nothing |

   Every chord of that table is one the engine hands to the graph, and the
   proc reads that rather than listing it twice: a `graph graph.forward` row of
   the engine's binding table (taken live, `xschem bindings dump`), or, for a
   chord with no row at all, an arm of the key switch that opens with the graph
   test (`graphguards`: `m` plain and with Control, `M` plain, `s` plain). A
   row of the table decides before the switch, so a chord with a row but no
   graph row of that action is refused. That closes the user's own `canvas`
   and `global` rows.

   Control with `b`, `d` or `M` is refused BY NAME (`graphown`), before the
   table is read: those three chords are shortcuts of the viewer's own (the
   Signal Browser, Clear All, the plot mode). The stock table has no graph row
   for them, so the table rule alone refuses them there. It would not with a
   `graph graph.forward` row of the user's for one of them (a keybindings file
   from before the Signal Browser took Ctrl-B carries the one for Ctrl-b, and
   it is the natural rc line for a `graph_use_ctrl_key` user who wants cursor B
   back over embedded graphs): the key would go to the graph and the tag would
   run the shortcut as well. (Added 2026-11-21 in the repair of this item; the
   first build of the rule had dropped the old by-keysym refusal of Ctrl-b and
   Ctrl-d and was measured doing both things with such a row.)

   The table is not the whole of what the engine hands to the graph. Under
   Control with a further modifier that is neither Alt nor Super (Mod3, Mod5, a
   held middle or right button) its `case 't'` asks the graph test too. The
   filter does not forward that chord (see the limits).

   Two profile rules on top. With `graph_use_ctrl_key` set a bare graph key is
   refused. In the Cadence profile plain `s` is forwarded AS Control-s, which
   the engine hands to the graph and which swaps the cursors as plain `s` does
   in the stock profile, so `s` does what the guide says in both.

2. **The pixel** (`wviewer::key_at_graph`). The engine's graph test judges the
   key event's own pixel and leaves a border of 5 pixels times the Tk scaling
   inside each graph rect. The filter tests the same pixel (the event's `%x
   %y`; the pointer's when `fix_mouse_coord` is on) against the strips with
   that border trimmed off, rounded up plus one pixel
   (`wviewer::graph_border_px`), and refuses while a gesture is in flight in
   the context (`graphbusy`, the `excl` set of `waves_selected`). The old gate,
   `wviewer::over_graph`, read the mouse mirror against the full strips; it
   stays for Delete, which is never forwarded.

3. **Escape** is the one other key the filter forwards (the engine's abort and
   redraw). The engine asks its binding table before its Escape arm, so with a
   row for the chord (`wviewer::key_has_row`; no table that ships has one, a
   user's rc can) the filter does not forward it: it calls the verb,
   `xschem escape`, on the press and the key stays in the viewer. (Added
   2026-11-21 in the repair of this item.)

**Mirrored in C or in the tag, and what fences each.** All in
`tests/headless/test_wave_subwindows.tcl`, both arms unless said:

| what the Tcl side restates | the row that reads the original |
|----------------------------|----------------------------------|
| `graphguards`, the key switch's arms that open with the graph test | SWK21: the arms are read out of `src/callback.c`, the graph rows from the live table, and `key_chord` is compared with a comparand fed from both over every graph key, a matrix of modifier states and the four profiles |
| `wviewer::chord_state`, the bits `callback()` strips | SWK20: the mask names are read out of `callback()` |
| `graphbusy`, the `excl` set of `waves_selected` | SWK27: the names are read out of `waves_selected` and looked up in `src/xschem.h` |
| the factor of `wviewer::graph_border_px` | SWK25: the factor is read out of `waves_selected`. The proc is asked at Tk scalings from 1.0 to 3.0 with the `tk` command answered by a recorder (both arms), and at the display's own scaling (display arm): each answer is no smaller than the factor times the scaling and less than two pixels larger. (Third repair, 2026-11-21: the row used to compare at the display's scaling only, where a constant passes.) |
| `graphown`, the tag's Control defaults on graph keysyms | SWK28: derived from `wviewer::install_default_binds` as the interpreter holds it, and on the display arm from the live tag |

SWK21's comparand takes its inputs from the engine and combines them by the
steps `key_chord` takes, so it holds the product to those inputs and is no
second reading of the engine. Row KM13 of `test_wave_viewer` is: it sends every
chord the filter forwards, in the four profiles, as a real key through the
real engine and finds nothing outside the graph moved. (Second repair,
2026-11-21: KM13 asks the same comparand BEFORE each key and sends only a
chord it allows; a chord it refuses is counted as an offender and not sent. In
the engine such a chord is an editor verb, several of them a prompt or a form,
and on a product whose filter forwarded one the suite stopped there until its
driver killed it. The comparand's procs are in
`tests/headless/wvkey_engine.tcl`, which both suites source.)

**Limits, declared.**
- A user who rebinds a `graph` row of the table to another action gets nothing
  for that chord in a viewer (the filter forwards only `graph.forward` rows).
- With `graph_use_ctrl_key` set the measurement tooltip has no key in a viewer
  (`graph_markers.md` §6.1).
- Control with Mod3, Mod5 or a held middle or right button, plus `t`, reaches
  the graph in the engine; the viewer refuses it like every other mixed state.
- With `graph_use_ctrl_key` set, cursor A, cursor B and the delta marker have
  no key in a viewer either: Ctrl-a selects all the traces in the engine
  (issue 1617), Ctrl-b is the Signal Browser and Ctrl-d Clear All (row KM10).
- The engine runs a key in the CURRENT context, and the context follows the
  pointer while the keyboard focus does not. A viewer that has the focus while
  another window's context is current (measured: the pointer in the viewer and
  the main window made current by a command) forwards no graph key, since the
  engine would run it there; the keys work again once the pointer has left
  the canvas and come back. Ctrl-Shift-M does not depend on the context
  (`waveform_viewer_modes.md` §9.1), and Escape aborts in whichever context is
  current, as it did before.
- **CLOSED 2026-11-22** (overnight batch item 03b; "A key that came through
  another window" below). What follows is the limit as it was declared on
  2026-11-21, kept as the record of what was measured; row KM14 now holds the
  opposite. **The same rule the other way round is NOT closed, and it still brings up
  the box the user reported.** The viewer's context current and the keyboard
  focus on another window's canvas: the pointer came into the viewer's plot
  (the engine made its context current and gave its canvas the focus), then
  the focus went back to the schematic window with no pointer motion, which is
  what Alt-Tab or a click on the task bar does. A key typed then goes through
  the SCHEMATIC canvas's binding to the engine, and the engine runs it in the
  current context, the viewer's, as the editor key it is. The filter is a
  binding of the viewer's canvas and never sees it. A viewer that has just
  opened is a second way into the state, with no Alt-Tab: where the desktop
  leaves the keyboard focus in the schematic window after the open, a key
  typed with the pointer over the new plot goes the same road (measured
  2026-11-21 by a probe with a real pointer and real keys on the test
  display; on the same display another start left the focus on the viewer's
  toplevel instead, the limit below. Which of the two the user's desktop
  gives was not measurable here). Measured with a real
  pointer and real keys: Ctrl-Shift-M brings up "View is Read Only" and leaves
  the mode; the Cadence profile's `s`, `w` and bare `b` bring up the same box;
  Alt-b steps `hide_symbols`. The state ends when the pointer enters the window
  that has the focus, or a click in the viewer's plot gives it the focus. It
  predates this item and its cause is not the filter's; the engine is
  unchanged. Closing it takes a guard in `callback()` for a viewer context (a
  key whose canvas is not the current context's is dropped, or handed to the
  viewer's filter), which changes what a key does in every such state and is
  the user's to rule on. Row KM14 of `test_wave_viewer` holds the limit as it
  stands: with the viewer's context current and the focus forced onto the main
  canvas, a Ctrl-Shift-M generated there reaches the engine through `.drw`,
  the viewer's filter is not called, the box comes up and the mode stays. Its
  second check builds the state twice more and ends it each way: an Enter on
  the main canvas makes the main window's context current, and a click in the
  viewer's plot gives its canvas the focus, after which the chord is the
  viewer's again. The row turns red the day the engine stops running such a
  key in the viewer.
- **CLOSED 2026-11-22** (the same item; `wviewer::top_key`). The limit as
  it was declared on 2026-11-21, kept as the record. The open still leaves the
  focus on the toplevel (row G1f holds that); a key typed there with the
  pointer over the plot is now the viewer's (row KM23). **A viewer that has just opened takes no key until one click in its plot.**
  `wviewer::open` leaves the viewer's context the current one and asks for the
  focus on the viewer's toplevel, not on the plot canvas. The engine hands a
  canvas the focus only when an Enter switches the context to it, and the
  viewer's context is current already, so the pointer coming into the plot
  brings nothing (with `autofocus_mainwindow` set the canvas's own Enter
  binding asks for the focus, and the pointer coming in is enough). Until a
  click in the plot, or until the pointer has been over another xschem canvas
  and come back, a key typed with the pointer over the plot reaches neither
  the filter nor the `WaveViewer` tag: Ctrl-Shift-M, like every other viewer
  key, does nothing.
  Measured with a real pointer and real keys in the Cadence profile. It
  predates this item (`wviewer::open` is unchanged) and it is the first thing
  a user who opens a viewer and presses the chord meets. Row G1f of
  `test_wave_viewer` holds it as it stands, by Tk's own record of where the
  focus goes inside the toplevel. Changing it (the open gives the plot canvas
  the focus) is the user's to rule on, with the limit above it.
- The one-pixel ring between the engine's border and the filter's rounded-up
  one swallows a graph key the engine would have taken.
- The engine is unchanged. Over a graph embedded in an ordinary schematic every
  chord above does what it did (row KM12 of `test_wave_viewer`), the Cadence
  profile's plain `s` included: there it still starts a wire.

Rows: `test_wave_subwindows` SWK19 to SWK25 and SWK27 to SWK29 (both arms),
SWK26 and one leg of SWK28 (display); `test_wave_viewer` KM0 to KM15 (display,
real keys; the chords that are a reload, a Save form or a new window are asked
of the filter first and sent for real only when it refuses them, and a chord
the filter forwards is sent only when the comparand allows it). Added in the
second repair, each for a break no row caught before: the readout bar after
the Cadence profile's `s` (KM7), the delta marker of a bare `d` (KM2), the
first pixel the gate must accept (KM9, and SWK27 on both arms), the chord with
two tabs (KM6), and a binding of the user's own against every default of the
tag (KM1). Added in the third repair, again each for a break no row caught:
the middle of every strip of a window of more than two (KM9 with real keys,
SWK27 on both arms), the border at other Tk scalings than the display's
(SWK25), the tag walk in the Cadence profile as well as the stock one (KM1),
the band test behind the middle-button pan's press (SWK25, and a CG-mmb leg of
`test_wave_viewer` whose press is generated three pixels inside a strip's
edge), the
readout bar after a typed Control-s (KM7), and the chord's silence in the
command window (KM1). G1f held the limit of the viewer that has just opened
(until 2026-11-22; it now holds where the open leaves the focus, and KM23
that a key typed there with the pointer over the plot is the viewer's).
Added in the fourth repair, once more each for a break no row caught: the
gate in the right-hand one of two subwindows and after the window changed its
size (KM9 with real keys, SWK27 on both arms), the graph keys on a second tab
(KM6), the chord while the cursors show (KM7), the marker keys and the two
cursor keys in the Cadence profile as well as the stock one (KM2), and a
second viewer window open beside the first (KM15 with real keys; SWK19 and
SWK27 hold the wrapper and the gate with two canvases in the registry on both
arms).

## A key that came through another window (2026-11-22)

Overnight batch of 2026-11-21, item 03b, and its first repair of 2026-11-22.
Two contracts:

- **A key typed in a schematic window is the viewer's while the viewer's
  context is the current one and the pointer is in the viewer's window.** The
  context becomes a viewer's when the pointer comes into its plot, or when
  the viewer opens. The key does what it does when the plot has the keyboard
  focus: the viewer's own chords run (Ctrl-Shift-M flips the plot mode), a
  graph key goes to the graph, anything else does nothing. No editor verb
  runs in the viewer.
- **A viewer takes its keys right after it opens or is raised, without a
  click, while the pointer is over its plot.** Where the desktop hands the
  keyboard to the viewer's window, by that window's own door (rule 3); where
  it leaves the keyboard in a schematic window, by the first contract. With
  the keyboard on the viewer's window and the pointer anywhere but over the
  plot, a key does what it did before this item: nothing, but for the keys
  Tk's own `all` tag binds.

**Why.** The engine runs a key in the CURRENT context, whichever canvas's
binding handed it over, and the context follows the pointer (an Enter on a
drawing canvas switches it) while the keyboard focus need not. After Alt-Tab,
after a click on the task bar, or right after a viewer opened on a desktop
that leaves the focus where it was, the focus is in a schematic window and the
pointer rests in a viewer. Measured in that state on the product of
2026-11-21, with a real pointer and real server-side keys on the test display,
the Cadence workarea profile:

| key | what it did |
|-----|-------------|
| Ctrl-Shift-M | the "View is Read Only" message box; the mode stayed |
| `w`, `s`, bare `b`, `m` on a trace | the same box |
| Alt-b | stepped `hide_symbols`, a global |
| any key, its release included | wrote the OTHER window's pixel into the viewer's context as its pointer |
| `i` (a binding of the schematic canvas itself: `bind .drw <Key-i>` of `src/cadence_style_rc`) | the same box, and the engine was never called |
| `q` (another such binding) | a modal property dialog over the viewer |
| right after an open, the focus on the viewer's toplevel | nothing at all, for every viewer key |

The work order named the engine as the door. The tree has a second one: a
schematic canvas carries key bindings of its own that never call the engine
(the command palette, the descend key, and in the Cadence profile several
dozen `bind .drw` lines), and their scripts act on the current context too.
A guard in `callback()` alone would have left `i`, `q`, Control-2 and the
rest of them running in the viewer.

**The rule.** One decision, `wviewer::foreign_key`, behind three doors.

1. **The canvas door.** Every schematic canvas carries the binding tag
   `wviewer::key_door_tag` FIRST in its tag list (`set_bindings` in
   `src/xschem.tcl` calls `wviewer::key_door_attach`), the canvas of a second
   schematic window like the main one (row KM21). Its two bindings, for a key
   press and a key release, ask `wviewer::key_door` before any binding of the
   canvas runs, and `break` when a viewer took the key. A viewer is asked
   only while ITS context is the current one. While a schematic's context is
   current the proc asks the engine for the current context and, when that
   is not the canvas's own, for its viewer flag, and stops there. A viewer's
   own canvas does not carry the tag (`wviewer::strip_bindings` takes it off
   again).
2. **The engine's door.** `viewer_takes_foreign_key()` in `src/callback.c`,
   called above everything else `callback()` does: for a key press or
   release, with the viewer flag on the current context (`xctx->wave_viewer`)
   and a window that is not that context's canvas, it asks the same proc and
   returns at once when the answer is 1. It stands above the write of the
   event's pixel into the context (issue 1659), so the viewer's stored
   pointer stays the viewer's, and above the semaphore increment, so the
   graph key the filter hands back to the engine counts as an ordinary
   first-level call (row KM17 sends a graph key by this door and sees cursor
   B toggle). Not under `has_x` 0. A key Tk delivers is settled at the canvas
   door; this one answers for whatever reaches `callback()` another way (a
   script's `xschem callback`, a binding that forwards).
3. **The viewer window's own door.** A viewer's toplevel carries the binding
   tag `wviewer::top_key_tag` first in its tag list (`wviewer::open` calls
   `wviewer::top_key_attach` for a fresh window). `wviewer::open` leaves the
   keyboard focus inside a viewer on that toplevel, and until this date no
   key was bound there. The tag's two bindings ask `wviewer::top_key`, which
   hands the key to `foreign_key` when the pointer is over that viewer's PLOT
   canvas. The tag is one of its own, not a binding on the toplevel's path:
   the path is a tag of every widget inside the toplevel too. The binding
   does not `break`; Tk goes on with the toplevel's own tags as before (row
   KM23 types F10 there: the viewer's own menu is posted).
4. **The decision.** `wviewer::foreign_key W T N K s` takes the key when `W`
   is a viewer's canvas and the pointer is in that viewer's window: Tk is
   asked which window of this application is under the pointer (`winfo
   containing`), so the plot, the bars, the tab row and the Signal Browser
   all count, and a window lying over the viewer counts as itself. Anywhere
   else it answers 0 and the key runs as it always did. (The viewer window's
   own door asks for the plot before it asks this proc: rule 3.)
5. **What it does with a key it takes.** What Tk would have done had the key
   been delivered to the viewer's canvas: for each binding tag of the canvas,
   from the first through `WaveViewer`, the binding Tk would run for the key,
   with the pointer's pixel in the canvas as the event's. That is the filter
   (the canvas's own key binding) and then the viewer's shortcut, so an rc
   binding on the tag and the Caps Lock dispatch are honoured and nothing
   keeps a second list of chords. A script's `break` stops the walk, and so
   does an error in one, which goes to the background error handler: both as
   with a key Tk delivers (row KM14). `wviewer::tag_key_seq` chooses the
   binding from what `bind <tag>` lists, by Tk's rules: a sequence that names
   the keysym beats one that does not; then the one that asks for more
   modifiers wins when its modifiers include the other's; of two that ask
   for different ones, the one bound later. `wviewer::key_seq_event` reads
   one listed sequence; `wviewer::key_subst` fills the `%` fields. Tk itself
   cannot be asked: `event generate` sends a key to the window that has the
   focus, which is the window the key came from.
6. **Nothing moves.** Neither the keyboard focus nor the context, by any of
   the three doors. Taking the focus for the viewer would leave the
   schematic's keys dead when the pointer goes back there.
7. **The open is as it was.** Both arms of `wviewer::open` (a fresh window,
   and one it only raises, which is what auto-plot asks for after a run) ask
   for the focus by a plain `focus <toplevel>`, as before this item (rows G1f
   and KM18; KM18 records the calls and holds that the one naming the
   toplevel is not forced). Rule 3 is what gives a viewer its keys after it.

**Decided by the lead** (work order 03b; not ruled on by the user):
the pointer decides, and the key works rather than being dropped; a release
follows its press; a key typed in a window that is no xschem drawing window
(ASE-L, the Calculator, the Signal Browser's panes and search box) stays
there; no new chord; and the mirror state is unchanged (first limit below).

**Decided by the crews** (holes in the work order; the build, then the
repair):
- The canvas door (rule 1). Rejected: the engine's door alone, which leaves
  the canvas-bound keys of the Cadence profile running in the viewer.
- For a key from a schematic canvas, "the pointer over the plot" is read as
  "the pointer in the viewer's window, the viewer's context current".
  Rejected: the plot canvas only, which leaves the same editor verb running
  when the pointer rests on the viewer's status bar. Also rejected, in the
  repair: asking which viewer the pointer is in before asking which context
  is current. A pointer that reached the viewer's bars without crossing the
  plot leaves a schematic's context current, and the schematic then runs
  the key in its own context: no editor verb runs in a viewer, so the state
  is not one this item is about. And with `mouse_follows_focus` off the
  context follows the keyboard focus on purpose; a key typed in a schematic
  must stay the schematic's there whatever the pointer rests on.
- With the viewer's context current and the pointer in no viewer, the key is
  NOT taken (second limit). Rejected: taking every key that arrives while a
  viewer's context is current, which would let Control-d typed into a
  schematic clear a viewer the user is not pointing at. Not done either:
  switching the context to the canvas the key was typed in. It would cure
  the limit, and it is the engine's most delicate path; returned to the user
  as a ruling to make.
- (Amended 2026-11-22, the repair.) The build had `wviewer::open` give the
  plot canvas the focus, in both arms, as the work order suggested. While
  this application holds the keyboard a plain `focus` moves it, so the keys
  typed next went to the viewer wherever the pointer was. Measured with real
  keys after the raise auto-plot asks for, the pointer over the schematic:
  `e` deleted the empty strips, `u` undid in the viewer, Control-d cleared
  the traces; before the item the same keys did nothing. That contradicts
  the work order's own third promise (nothing changes for a schematic window
  the pointer is over). The repair took the work order's other road: the
  open as it was, and a door on the toplevel (rule 3).
- The viewer window's own door asks for the pointer over the PLOT, not
  anywhere in the viewer's window. Rejected: the whole window. A key this
  door declines does nothing, where one the canvas door declines runs as an
  editor key, so there is no reason to be wide; and the raise at the end of
  an open takes the keyboard from whatever widget of this application had
  it, the Signal Browser's search box included, where the next character,
  typed with the pointer still in the box, must not run a viewer shortcut
  (row KM23, its check for the Signal Browser: the keyboard on the viewer's
  toplevel, the pointer on the search entry, `e` is declined by the door and
  removes no strip).
  **The promise goes no further than its condition.** The door asks where
  the pointer is, not which widget had the keyboard before the raise. When
  the raise takes the keyboard from the search box, or from any other window
  of this application that held it (an ASE-L field, say), while the pointer
  rests over the plot, the characters typed next run viewer shortcuts.
  Measured by the item's checker: `e` removed an empty strip. Before the
  item those characters were dropped, as they still are with the pointer
  anywhere but over the plot. Not ruled on by the user; returned with the
  ruling on where an open or a raise leaves the keyboard.
- A viewer's own canvas does not carry the canvas door's tag: with the focus
  on one viewer's plot and the pointer in another viewer, the key stays with
  the first. Rejected: routing between viewers, which the mirror-state
  decision excludes. (Not ruled on; returned as a ruling to make.)

**Limits, declared.**
- **The mirror state is unchanged.** The focus on a viewer's plot and the
  pointer over a schematic window, or over another viewer: the key goes to
  the filter of the viewer that has the focus, which swallows it, and a
  shortcut of that viewer's tag runs. A graph key does nothing there (the
  filter forwards one only while its own context is current).
- **The viewer's context current and the pointer in no viewer.** The engine
  switches the context only on an Enter of a drawing canvas. So a viewer
  stays the current context (a) while the pointer, last in the viewer, rests
  outside every drawing canvas: on a title bar, a menubar or toolbar, the
  desktop, another application; and (b) right after it opened, while a
  pointer that was resting over a schematic canvas has not left that canvas.
  A key typed in a schematic canvas then still runs in the viewer's context
  as an editor key: Ctrl-Shift-M and `w` bring up "View is Read Only".
  Measured with real keys in (a) after a click on the schematic window's
  title bar and with the pointer on the bare desktop, and in (b) on a
  display with no window manager. It is the engine's general rule for any
  window, not this item's, and it is what the user's report is about
  wherever it is reached; returned as a ruling to make.
- **Only a pointer crossing ends that state.** The pointer moved into the
  schematic's canvas, or out of it and back in, brings the Enter the engine
  switches on. A click in the schematic does not by itself: the engine
  switches nothing on a button press. Under openbox, the window manager of
  the test display, the click does end it, because that window manager's
  button grab makes the server send a Leave and an Enter around the press;
  on a display with no window manager (`AUDIT_WM=none`) the same click left
  the viewer's context current and the next `w` brought up the box. The
  user's Windows X server is not measured.
- **A pointer that reaches a viewer's bars, tab row or Signal Browser
  straight from a schematic**, without crossing the plot, has not switched
  the context: a key typed in the schematic is the schematic's, in the
  schematic's context. Measured with real keys for the Signal Browser pane
  and the status bar. The same place reached through the plot gives the
  viewer the key.
- **After an open or a raise the keyboard is on the viewer's toplevel**
  wherever the desktop activates the viewer, as before this item. With the
  pointer over a schematic the keys typed then do nothing (rows KM18 and
  KM23), until a click in the schematic gives its canvas the keyboard. If
  the viewer's context is still the current one then, the second limit
  applies. With the pointer over the plot the keys typed then are the
  viewer's, also when the raise took the keyboard from a text field the
  user was typing in (the Signal Browser's search box, an ASE-L field): the
  crews' decision on the viewer window's own door, above, has the case.
- `mouse_follows_focus` off was not measured. There the engine switches the
  context on FocusIn and not on Enter (read from
  `handle_window_switching()`), so a pointer coming into a plot does not make
  the viewer's context current, and while it is not, the canvas door hands
  the viewer nothing.
- A binding of the user's on the tag that `wviewer::key_seq_event` does not
  read runs only for a key Tk delivers to the plot: a sequence of more than
  one event, a multi-press, a virtual event, and a sequence with Meta or
  Extended. Alt is read as Mod1, as the engine reads it.
- Of a binding script's `%` fields, W, x, y, X, Y, N, K, s and T are filled;
  any other becomes `??`.
- The tags after `WaveViewer` are not run for the viewer, and a key the
  canvas door took goes no further: in that state Tab moves no focus and F10
  or an Alt-letter opens no menu, in either window (row KM14 types F10).
- The choice among sequences is Tk 8.6's. Row SWK31 holds
  `wviewer::tag_key_seq` to answers that were measured against Tk on the day
  it was written; it asks Tk nothing and would stay green under a Tk that
  chooses differently. Row KM19 asks Tk itself in every run, on the display
  arm: for every sequence of the live tag, and for three sequences of its
  own that ask for different modifiers, bound in each of the six orders.
- Nothing here was run on the Windows build. `XKeysymToString`, which the
  engine's door calls, is in Tk's Xlib layer there; that was read, not
  measured.

**The middle-button pan's inset** (a rider of the same item). The press of
the pan is taken only `wviewer::pan_inset_px` pixels inside a strip: 8, as it
always was, wherever the engine's border rounded up is no more than 8 pixels,
and `wviewer::graph_border_px` where it is wider. The fixed 8 fell short above
a Tk scaling of 1.6: measured in item 03 at scaling 2.0, a press 9 pixels
inside a strip panned the viewer's schematic canvas.

Rows. `test_wave_viewer` (display; the pointer moved for real by a warp, the
key generated on the window that has the focus; KM14 and KM16 send a chord
with Alt to the engine's entry): KM14 the chord by the canvas door and by the
engine's, its release, the stored pointer, a key bound behind the viewer's
tags, an error in a binding, and the pointer deciding; KM16 the editor keys;
KM17 the graph keys in both profiles, by the canvas door and by the engine's;
KM18 a viewer that has just opened and one that is only raised: where the
focus is left and by what calls, the keys typed over the schematic, the chord
without a click; KM19 parity with Tk on the live tag and for the order of
binding; KM20 the control and two viewers; KM21 an ordinary second schematic
window, expected values taken before the change, and a key typed in it with
the pointer in the plot; KM22 the Signal Browser's search box; KM23 the
viewer window's own door, with the pointer over the plot, on the status bar,
over the main canvas and on the Signal Browser's search box; G1f the focus
after an open and the tag on the toplevel.
`test_wave_subwindows` (both arms): SWK30 `key_seq_event`, SWK31
`tag_key_seq` against the answers measured on the day, SWK32 the installer's
own table, SWK33 `key_subst`, SWK34 the engine's question with the proc a
recorder (on the windowless arm: that it is never asked) and the refusals of
`foreign_key` and `top_key`, SWK35 the pan's inset, and a leg of SWK19 for
the chord with exactly one cursor showing.

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
  - *(2026-08-23, issue **0616**) the same helper bit again, harder.* The same user
    reported the design window **disappearing** on *Netlist and Run*. Same chain, same
    `wm withdraw` + `wm deiconify`: `do_run`'s guard tests the xschem CONTEXT, and a
    restored viewer leaves the context on the viewer canvas, so the guard fires while
    the design window is fully visible — then re-maps it, and WSLg sometimes drops the
    re-map. `do_run` now passes a third mode, `ifhidden`, through
    `design_window`/`raise_design_editor`/`raise_window_entry`: context switch always,
    the cheap `raise` + `activate_window` always, the **withdraw/deiconify re-map only
    when the toplevel is not mapped**. Ctrl-4's `do_raise 0` semantics were explicitly
    rejected for it (never touching the toplevel would strand a user whose window is
    minimised or already lost). Contract table: `doc/claude/specs/ase_l.md`.
  - **The viewer is a placement hazard for the design window (issue 0647).** Measured
    on `tb_bandgap/ngspice_state1`, whose state carries `viewer {open 1 …}`:
    `viewer_restore` opens `.x1` at **1000x800+13+89** while the design toplevel is
    **1000x800+13+90**, and above it in the stacking order. One pixel apart, viewer on
    top, schematic not on screen — a second way for a user to report "the schematic
    disappeared". It is also why 0616's fix has to keep the `raise`.
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
- **Not an undo point — but it MUST capture.** ⚠ CORRECTED 2026-08-01
  (issue 0194). This bullet used to read "so no `push_undo`, **no `capture`**,
  matching `sharedx_toggle`/`set_plot_mode`", and the second half was wrong: it
  is what made Ctrl-G deselect the selected trace. The two are separable and
  answer different questions. `push_undo` is about the UNDO STACK, and a window
  OPTION (plot mode, sharedx, cursors) is deliberately outside the model
  snapshot (`waveform_viewer_modes.md` §14) — so still no `push_undo`.
  `capture_live_graph_state` is about surviving `clear_drawing`: this command
  regenerates, regenerate re-places every rect purely from the Tcl model, and
  the selection lives in the RECT until something folds it back. So it captures,
  in the `skip_ranges` form (`wviewer::capture_live_view_state`) that folds the
  selection and leaves every axis exactly as it was. `set_plot_mode` needs neither —
  it does not regenerate at all. The rest of the contract is unchanged:
  refuse-a-no-op-without-logging, verified `switch_ctx`, ONE regenerate, ONE
  log line.
- **It keeps the view** (user report 2026-11-16: "When I use Ctrl-G in Waveform
  Viewer to toggle grid, it also causes the window to zoom-fit"). Ctrl-Shift-G
  and **Graph > Grid** share the body. See "Keeping the view across a rebuild"
  below.
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

## Keeping the view across a rebuild (2026-11-16)

**A command that edits the plot leaves every strip showing the axis windows it
showed; only View > Fit, a range typed into Graph > Axes… and new data change
them.** User report and three rulings, 2026-11-16: Ctrl-G "also causes the
window to zoom-fit"; then a resize, the aA text size and the Shared X toggle
"should preserve current view"; then Graph > Axes…, adding a trace and adding a
strip "should retain zoom".

- **Why they re-fitted.** Every one of these ends in `wviewer::regenerate`,
  which clears the canvas and re-places every rect from the Tcl model. The
  engine writes a box zoom, an axis drag, a pan and the `t` key's tracked
  dataset into the rect only, and the model keeps `{}` (auto) for an axis nobody
  set through Tcl, so the rebuild fitted it again, on every strip, whichever
  strip the command was about. (A wheel zoom was never affected: it writes the
  model.) The first four did this from the commit that introduced each: Shared X
  `c143cedb1` (2026-07-21), the resize refit `dc2495539` (2026-07-22), Ctrl-G
  `0d648465e` (2026-07-29), aA `47c687ef4` (2026-10-16). Before `dc2495539` a
  resize did not rebuild the strips at all.
- **The carry.** `wviewer::view_take` reads `x1 x2 y1 y2 ypos1 ypos2 dataset`
  off each live rect BEFORE the command changes the model; `wviewer::view_keep`
  turns that into `wviewer::regenerate`'s `keep` for the model as it is AFTER;
  regenerate writes the tokens onto the fresh rects and does not fit an axis an
  entry names. `wviewer::live_axes` is the two in one, for a rebuild that changes
  no strip. **The model is not written**: an auto axis stays auto, and a rebuild
  that carries nothing fits it as before. So the two hazards
  `capture_live_graph_state`'s header gives for folding ranges into the model do
  not arise.
- **Which strip takes which view** (`wviewer::view_map`, pure): by the strips'
  traces, never by index, so a command may add or remove strips in between. A
  strip whose traces did not change is itself; a strip that gained or lost a
  trace is the strip on screen sharing the most traces with it; a strip sharing
  none (a new strip, the first trace into an empty one, every trace replaced)
  takes nothing from them, bar the X window below. No strip on screen serves
  two.
- **What a strip takes** (`wviewer::view_entries`, pure), X and Y judged
  separately. "Moved" is an axis the engine moved since it was last fitted or
  set, i.e. a zoom or a pan (`wviewer::view_zoomed`):
  - **a strip with neither axis moved takes no axis.** It is rebuilt from the
    model and the fit exactly as before this section existed, so the carry can
    only change what happens to a strip somebody zoomed or panned. (A vector
    recomputed in place is therefore still fitted again on an unzoomed strip.)
  - an axis whose range or scale the MODEL changed since the rect was drawn is
    the model's (`wviewer::axis_sigs`), so a range written with `set_graphs`
    reaches the screen at the next rebuild instead of being hidden;
  - a strip with the traces it was drawn with, and an axis moved, keeps BOTH
    axes as shown. Fitting the untouched one again would fit it over the zoomed
    window and change a view the command had no business with;
  - a strip whose traces changed keeps only the axes that were moved. The other
    is fitted again, so a trace added to a strip zoomed in X only gets Y fitted
    over that X window. A trace added to a strip zoomed on both axes leaves both
    alone, exactly as after a wheel zoom, and may be out of view until View >
    Fit.
- **A fresh strip joins the X window its subwindow shows**
  (`wviewer::view_align`, pure; user report 2026-11-16, a Direct Plot into a
  zoomed window: *"the zoom level when the Ctrl-4 sends a plot does not match
  the prevailing zoom level"*). A strip with nothing on screen to take from was
  fitted to its whole sweep, so it came up at 0..20u over strips showing
  1.2u..3.9u. It now takes the X window of the nearest strip of its own
  subwindow whose X is known after the rebuild: one that carries X, else one
  whose model stores X (a wheel zoom). Only between strips whose X is the same
  thing (`wviewer::x_source`: the same databases and X columns behind their
  traces, and the same X scale), never across subwindows, and not when the
  fresh strip's own model stores an X window. Its Y is fitted over the window
  it ends up with. With nothing zoomed there is no known window and the strip
  is fitted as before. The model is not written.
- **"Moved since last fitted"** needs a memory: `regenerate` records, per strip
  (`wviewer::drawn_records`), the model's signature and what each axis read
  right after it was fitted or set. A carried axis keeps the older record, so a
  zoom carried through a grid toggle is still known as a zoom when a trace is
  added afterwards. Two commands make the model say what the rects show with no
  rebuild, and take the record again themselves (`wviewer::drawn_refresh`):
  View > Fit, for the strips it fitted, and `wviewer::marker_changed`, whose
  fold freezes every live window into the model on every marker gesture.
  Without that a zoom made AFTER a Fit or a marker was put back to the fitted
  or frozen window by the next rebuild.
- **The strip a range is set on.** `apply_range` shows the range on the axes it
  was given, the other axis as it was. The Axes dialog's OK shows what the
  dialog says on both axes of the strip it names: a typed range, or a fit for a
  blank, so OK on a zoomed auto strip with nothing typed fits that strip.
  Changing an axis to log or back fits that axis in the new unit.
- **Shared X** (`wviewer::sharedx_keep`, pure). Y, and the first strip of each
  subwindow, keep what they show. Turned ON, the other strips take the first
  strip's X as shown. Turned OFF, a strip whose stored X window differs from the
  first strip's gets its own back (that is what un-sharing is for); a strip
  storing the same window keeps the X it shows.
- **Undo and redo** (`wviewer::history_step`, `state_apply`). An axis the
  snapshot pins shows the snapshot's window, as before. An axis it leaves auto
  keeps what the strip shows instead of being fitted again.
- **A Direct Plot, a re-run and `~` (issue 1733, 2026-11-22).** User report:
  after a run, a strip zoomed, then another signal sent with Direct Plot: every
  strip snapped back to the full sweep, because `ase::ui::dp_finish` attaches
  the session's raw first (`wviewer::attach_raw`) and attach_raw ended in a
  plain rebuild, which fitted every strip. Ruling, the same day: *"yes, re-run
  which then plots in Replace mode should retain zoom level, not reset it"*.
  attach_raw now carries the view, by one of two rules, and records what it
  attached so the next attach can tell which applies:
  - **R1, the same data.** attach_raw re-attaching the same file (normalized
    path), the same analysis and the same VCD list, with every one of those
    files' mtime and size unchanged since its last attach in this window, and
    with the database it left current still current: the view is carried
    exactly as adding a trace carries it (`view_take` before the attach,
    `view_keep` into the rebuild). A Direct Plot after a zoom, and `~` with no
    run in between, keep every strip as shown. (`wviewer::attach_stamp`,
    `wviewer::attach_is_same`, both pure but for the stamp's `file stat`.)
  - **R2, new data** (anything else, a re-run above all). An axis the user
    MOVED (`wviewer::view_zoomed`, the same notion as above) is kept; an axis
    nobody moved is fitted to the new data, over the X window the strip ends up
    with; a strip nobody zoomed is rebuilt exactly as before. A kept X is
    dropped when X is no longer the same thing (`wviewer::x_same` over
    `wviewer::x_resolve`, the notion `view_align` uses: the same analysis and X
    column, the same X scale; another tran file is the same X, an ac file where
    a tran was is not), and when the kept window does not overlap the new sweep
    at all (regenerate fits the strip's X and keeps the window only if
    `wviewer::x_overlaps` says the two meet; a miss is recorded as fitted). A
    strip whose X is no longer the same thing keeps a moved Y neither: another
    analysis is another plot, and a transient's Y window over AC magnitudes
    leaves the curve off screen (review round, measured on a tran -> ac re-run
    under Replace), so that strip is rebuilt as if nobody had zoomed it. A miss
    of the overlap alone keeps a moved Y (the same quantity, another stretch of
    the sweep). A tracked dataset is never kept: it numbers the old data's
    datasets. (`wviewer::view_new_data`, pure.) A failed attach (no database
    read) is new data and leaves no record.
  - **R3, the run-end plot and `~`.** `ase::ui::auto_plot` reads the view right
    after attach_raw kept it, with the strips the target subwindow holds in it,
    and hands it to its last rebuild once the rows are in. Under **Replace** a
    strip of the target subwindow that comes back with the traces it had (a
    re-run, or `~` again) takes its view by R1 or R2, matched by traces
    (`view_map`) **among that subwindow's old strips only**
    (`wviewer::view_keep_subwin`, its pure half `wviewer::view_within`); a strip
    there that matches none joins its subwindow's X window (`view_align`).
    Every strip of every other subwindow shows exactly what it showed: the
    rebuild that reflects the destination's window half carries the live view
    (`live_axes`), as attach_raw and `clear_subwin` did before it. So does the
    rebuild of the press with **nothing ticked** under Replace, which empties
    the target subwindow to one empty auto strip and attaches nothing (second
    review round: it was plain, and fitted every other subwindow again, a zoom
    of 6n..8n coming back at the full sweep). (The first
    cut matched the old view across every subwindow; once the target's strip
    count changed, a zoom moved from one subwindow to another, measured in the
    review round.) Under **Append** the strips already there keep theirs the
    same way and a new strip joins its subwindow's X window. Under **New
    SubWin** the subwindows already on screen keep their view by R1 or R2 (the
    first cut's plain rebuild there reset them, on the same data too; review
    round) and the new subwindow's strips fit: nothing in their subwindow to
    take a view from. Under **New Tab** the tab left behind keeps its view in
    the tab stash (`tab_freeze`) and the new tab's strips fit.
  - **R4, every other loader** keeps today's behaviour: a file opened from the
    Location bar (`rawbar_load`), the Select dialog (`ase::ui::rsel_commit`),
    `display_raw` and `restore` rebuild plain (new data fitted) and DROP
    attach_raw's record, so the next attach is never taken for the same data
    even when the hand load ended on that same file. Every other proc that
    reads, clears or switches a database either puts the current one back as it
    found it or leaves another one current, which `attach_is_same`'s check of
    the current database catches, with one exception that reads the current
    one again in place. `calc::aq_run`, given an `op` expression while the
    current table is a file's noise totals stored as `op` (issue 1657's arm;
    only a read that named no type stores them so), reads that file
    again as the operating point into the same slot. The slot keeps its name,
    the file and `op`, so the `cur` check cannot see the change. The view is not
    hurt by it: the next attach clears that file and reads it again itself
    (`ase::attach_dbs`), so it draws what the previous attach drew, and a
    totals table is one point, with nothing to zoom. The record goes with the window
    (`wviewer::forget`). Row `GZP33` derives the population of loaders from the
    source and requires each to be classified: the loader verbs from the C side
    (every top-level verb of `src/scheduler.c`, and every sub-verb of its `raw`
    branch, whose branch calls a function that changes the raw registry, such
    as `xschem annotate_op` and `xschem raw case <mode>`; the bare `raw case` is
    a query), a verb held in a variable taken for a loader, and every proc
    found by a walk that follows Tcl's brace rule into `namespace eval` bodies.
    What it cannot see (a C branch reaching the registry through another file,
    a callback script registered outside every proc, `xschem {*}$cmd`, a verb
    assembled from pieces, scripts outside `src/*.tcl`) is declared in the
    row's comment; the `cur` check of `attach_is_same` stands behind it.
  - **R5, the other places attach_raw reaches.** Read, and named here:
    *tabs*: the record is per viewer window, since every tab of a window draws
    from the one context's databases; attach_raw rebuilds the tab in front, and
    another tab still shows its stashed view when selected, as before.
    *Subwindows*: each strip is judged alone, and the X window a fresh strip
    joins is its own subwindow's (`view_align`), as before. attach_raw has two
    callers here, `ase::ui::dp_finish` and `ase::ui::auto_plot`, so no other
    place is reached.
  - **Declared limit.** The stamp is `file stat`'s mtime (whole seconds) and
    size: a rewrite of the same file to the same size within the same second
    as the attach before it is taken for the same data (R1), and its strips
    keep both axes as shown. A real re-run takes longer than that between two
    attaches.
- **Rebuilds that do not carry**, each for its own reason; row `GZP20` of
  `tests/headless/test_wave_grid.tcl` holds the list against every call site:
  - new data loaded by hand (`display_raw`, `rawbar_load`): the windows on
    screen fitted the old data. A wheel zoom (stored in the model) is kept and
    a box zoom is not. `attach_raw` left this list with issue 1733 (above).
    Replace keeps the emptied strip's STORED window by `sw_clear_graphs`' rule
    as well.
  - the layout replaced or emptied (`restore`, `clear_all`);
  - another tab's strips (`select_tab`, `new_tab`, `close_tab`): the tab stash
    holds each tab's own view;
  - the strip and trace moves, the split and the deletions freeze the view into
    the model first (`capture_live_graph_state` with ranges), so their plain
    rebuild shows it. That turns auto axes into stored ones, as it always did.
- **Tests:** `tests/headless/test_wave_grid.tcl` rows `GZP*` (counted arm),
  `GZ*` and `GV*` (display arm, including a real Ctrl-G, a real window resize
  and the real Axes dialog). Issue 1733: rows `GZP27`-`GZP34` there (the pure
  rules, attach_raw's order, the loader population, the match inside one
  subwindow) and `GX9`'s auto_plot legs;
  band `PV` of `tests/headless/test_ase_plot_outputs.tcl` (display arm) on the
  real path: a real `dp_finish`, `plot_outputs` under Replace and Append, a
  rewritten raw whose mtime the band moves, a Location-bar load in between,
  every strip read back off its rect; its group `PV5` (review round) puts the
  same rows in two subwindows and plots under Replace and New SubWin, and
  re-runs a tran as an ac.

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

> **⚠ SUPERSEDED FOR SIZE BY ITEM 22 (2026-10-16).** Every viewer strip now
> carries `textpx=<device pixels>` (written by `wviewer::font_props` from
> `wviewer_text_size` points times `tk scaling`, per sub-window), and
> `setup_graph_data` then takes a FIXED branch on a strip that is neither
> digital nor vlegend: with `m` the screen mooz (frozen across an export by
> `save_restore_zoom`), `H = textpx/m` and `S = textpx/(52*cairo_font_scale*m)`,
> all five text sizes are `S` (so `legendmag`, `xlabmag` and `ylabmag` are
> ignored for size), `bottom` solves `b = b/10 + 5S + 2.4H + 0.15H`,
> `top = 60S + 0.96H + 0.6H + 0.15H`, `left = bottom/10 + 5S + 8*0.62H + 0.3H`
> and `right = max(2H, (GRAPH_REORDER_HANDLE_W+4)/m)`, with a floor scaling
> top+bottom (and left+right) down together when they would exceed 80 % of the
> strip. The legend therefore matches the axis numbers by construction and
> `wviewer_legend_textmag` no longer changes viewer strips (one CIW warning per
> process for a non-default value). `legendbold` is unaffected. Schematic graphs
> carry no `textpx` and are unchanged. Spec: `waveform_viewer_subwindows.md`
> SW27-SW31 and §17; rows: band GF of `test_wave_grid`.

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
    **Scope (2026-10-16):** since R-OUT14 a multi-plot run gives every signal
    its own `auto 1` strip, so "the auto-plot strip" is the run plot of a
    subwindow. It is spared only when NO auto strip in that subwindow holds a
    trace (the run plot is between runs), and then only its first auto strip;
    an empty auto strip beside one that still holds the run's traces was
    emptied by the user and is deleted (`empty_strips_to_delete`).
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
  `add_graph`. ⚠ The reason here has inverted while the decision stood: this used
  to read *"takes neither an undo point nor a log line"*, and `add_graph` now
  takes both — it had been outside undo and outside the macro log, so Add Graph
  followed by `u` reverted whatever came before it while the strip stayed. That
  makes calling it from here worse rather than better, because its own
  `push_undo` would split this one gesture into two undo steps and its own
  `log_action` would record a strip the replay then creates twice. An inserted strip goes
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
  returns without mutating and **without logging**. ⚠ Since issue 1662 the menu
  does NOT mirror it at the gate: the strip menu posts on any strip with a drawn
  trace and greys Split Strip out below two (a two-trace gate made right-click
  post nothing in multi mode, where every strip holds one trace). The trace
  menu likewise posts on a one-trace strip with Move to Separate Strip greyed.
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

## Axis context menu — RMB on an axis margin → Linear / Log (2026-11-09)

The user: "We need a context menu on both axes (right click) that lets user
easily switch between linear and logarithmic scale for the axes."

- A no-travel RMB click in a strip's bottom (X number) margin posts
  `Linear X` / `Log X`; in its left (Y number) margin `Linear Y` / `Log Y`.
  Radiobuttons showing the strip's current scale; the wording is the Axes
  dialog's (`Log X` / `Log Y`).
- The region is the engine's `xschem get graph_axis_at` (draw.c
  `graph_axis_at`), the same answer the Ctrl+wheel axis zoom and the LMB axis
  drag use. It refuses the plot box and every legend pixel, so the menu is
  disjoint from the trace and strip menus; `ctx_menu_post` asks it first.
- Before this, a no-travel RMB in either margin did nothing (GRAPHPAN latched on
  the press and cleared on the unmoved release). An RMB drag there still zooms.
- The act is the Axes dialog's: set `logx`/`logy` in the strip model, blank that
  axis's range to auto (a log range is stored in log10 units), `set_graphs`,
  `regenerate`. Y is per strip. X is per strip unless `sharedx`, when it is
  every strip of the subwindow (they share one X range, which must be in one
  unit). Log Y is greyed out on a digital strip. A later plot into the strip
  never overrides `logy` (nothing sets it but the user).
- `graph_props` writes `subdivy=8` for a log Y (the decade minor lines), as it
  writes `subdivx=8` for a log X.
- Data <= 0: `mylog10()` maps it to -35 (1e-35). The log Y auto range is taken
  over the positive samples only (`graph_fullyzoom`), and a log X window over a
  sweep reaching 0 starts at the sweep's smallest positive value
  (`graph_fullxzoom`); before, one zero pulled either range down to -35 decades.
  All-non-positive data keeps the old range (nothing to show).
- Code: `wviewer::axis_at`, `axis_menu_pick`, `axis_scale_targets`,
  `axis_scale_graphs` (pure), `set_axis_scale`, `axis_menu_build/post/unpost`.
  Suite: `tests/headless/test_wave_axis_menu.tcl` (both T1 lists).

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

### REVISION 2026-08-01 (issue 0192): the arm is a SET

A multi-trace drag carries N traces, so it previews N. **The effect itself is
untouched** — same factor, same maths, same centre, same knob, same `flags & 16`
chrome, same X save/restore. What changed is the arm, in the `graph_marker_sel`
shape (landmine 46). Full contract:
`doc/claude/specs/waveform_viewer_modes.md` §19.5.

- **The HEAD keeps its exact meaning.** `graph_preview_scale` / `_gi` / `_wave`
  are now element 0 of the set, so **`xschem get graph_preview` is
  byte-identical** and all seven shipped `DV*` legs pass unchanged. The whole set
  is read through a NEW getter, `xschem get graph_preview_set` →
  `"gi ni gi ni …"` head first, `""` when nothing is armed.
- **The setter grew trailing pairs**:
  `xschem set graph_preview <gi> <ni> <scale> [<gi> <ni> …]`. The
  three-argument form is unchanged and is the single-trace arm; a trailing odd
  argument (a `gi` with no `ni`) is ignored rather than refused — this is chrome,
  and half a pair is not worth a Tcl error. `xschem set graph_preview 0` still
  clears head, set and count together.
- **Storage**: `graph_preview_set_gi[]` / `_set_wave[]` / `graph_preview_n`,
  FIXED arrays capped at `GRAPH_MAX_PREVIEW_WAVES` (**64**, matching
  `GRAPH_MAX_SEL_WAVES`) — `xctx` is reset, not freed, so a pointer would add a
  free path for nothing. **The cap bounds the PREVIEW only**: an over-long set
  TRUNCATES, and the move itself is uncapped, so the worst case of a 65-trace
  selection is that the 65th carried trace travels at full size. Refusing the
  gesture over a cosmetic limit would be a functional regression.
- **ONE writer, ONE predicate**: `graph_preview_arm()` sets set, count, head and
  scale together (and zeroes all five on the disarm, so that has one home);
  `graph_preview_has(gi, wcnt)` is the only draw-side membership test.
  `Graph_ctx.preview_wave` became **`preview_gi`** — *the rect index this draw may
  preview, or -1* — still defaulted in `setup_graph_data` **above** the
  `RECT_OUTSIDE` return, which is unchanged and still load-bearing.
- **Different source strips shrink about their OWN strip's centre**, in place
  (D-50): `prev_c`/`prev_cx` come from the `gr` being drawn, so this is free. The
  carried traces do **not** gather at the pointer — that would be a new overlay
  render outside each rect's bbox clip, and it is recorded as out of scope.
- **Tcl**: `wviewer::drag_preview_arm_set {token pairs}` is the plural arm (one
  `xschem set` per motion threshold, however many traces); `drag_preview_arm
  {token gi ti}` is now a one-line wrapper over it, signature and return contract
  unchanged.
- ⚠ **The same eyeball gap, now N-wide.** No leg can see that N traces render
  shrunk at once, and whether `0.7` is right for a BUNDLE is a question only a
  human can answer — `set ::wviewer_drag_shrink <0..1>` is the one-line tune.
  What *is* asserted at source level (`DM6`) is that exactly one draw-side
  comparison site survives and that the predicate matches on **both** the `gi`
  and the node index: with a single carried trace a bare comparison and the
  predicate agree exactly, so no behavioural leg could ever have caught a bare
  one.

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

## Hierarchy sync: browser → schematic (signal-browser item 11, 2026-08-05)

`Descend to here` moves the ASE-L session's **schematic** window to the point in
the hierarchy the selected Signal Browser row(s) name, raising and activating
that window — or leaves it *exactly* where it started, with a reason, if any
step fails. (One ending is neither: a row that names a DEVICE takes the window
to the device's parent sheet and selects the device there — *A path that ends
in a device*, below.) Entry points: the browser's RMB menu (the slot item 10 reserved),
`View > Descend to here`, and `E` (Shift-e) on the `WaveViewer` bindtag **and**
on the tree widget. All Tcl; no C was added (settled decision 8).

### The pivot is `sim_sch_path`, and that is measured

`xschem get sim_sch_path` is the current hierarchy path **relative to the level
where the raw was loaded** — the same origin the raw's own signal names use, so
`v(x1.x2.net5)`'s path `x1.x2` and the getter are in one coordinate system.
`xschem get sch_path` is absolute and is FORBIDDEN here (settled decision 10).
Measured on `tests/headless/fixtures/wvhier`, currsch 2, `sch_path` fixed at
`.X1.X2.`:

| `raw_level` | `sim_sch_path` |
|---|---|
| 0 | `X1.X2.` |
| 1 | `X2.` |
| 2 | `` |

⚠ **With NO raw loaded the two getters are byte-identical** (`sch_waves_loaded()`
is −1, the C skip loop never runs, and `sim_sch_path` is `sch_path` minus its
leading dot). That is why the mistake is invisible in the common case, and why
the regression test has to read a raw and move `raw_level` to have any teeth at
all.

### Five things the algorithm has to get right, all measured

1. **The trailing dot.** `sim_sch_path` answers `x1.x2.`, `x1.` and `` (the sim
   root). `wviewer::hier_split` normalises; nothing else compares raw strings.
2. **The prefix is byte-exact, the verify is case-insensitive.** ngspice
   lowercases, so a correct walk of `x1.x2` legitimately lands on the
   schematic's `x1.X2`; a byte-exact final verify rejects its own correct result
   and rolls back (reproduced). But the *common prefix* must stay byte-exact, or
   a design carrying both `x1` and `X1` — which the fixture does — never leaves
   the wrong subtree. `hier_common` exact, `hier_same` `-nocase`.
3. **`descend -inst` can refuse WITHOUT throwing.** It returns the string `1` on
   success and the string `0` for a non-subcircuit instance or a raised
   semaphore, and throws only for "instance not found". `catch` alone sees
   success. Every step is confirmed by re-reading `sim_sch_path`.
4. **`go_back` returns void** and returns *without ascending* when the user
   cancels the save prompt, and is a silent no-op at semaphore ≠ 0. Again, only
   the readback is truth.
5. **Rollback is by readback, never by counting.** `descend_schematic()` extends
   `sch_path` *before* `load_schematic()`, so a failed load leaves the tree one
   level deep while returning 0. The rollback is the same walk primitive run
   with rollback off, back to the recorded start.

### A path that ends in a device (issue 1724, 2026-11-19)

A terminal current `i(x1.xm9.d)` files under the path `x1.xm9`, and `xm9` is a
transistor: a place on its parent's sheet, with no sheet of its own. Before
this the walk answered *"no instance 'xm9'"* for a transistor that is on the
sheet (the sheet calls it `M9`, the deck `XM9`), or *"descend refused"*, and
rolled back. What changed, all in `src/wave_viewer.tcl`:

1. **A third tier in the resolver.** When no instance is called the segment in
   any case, the resolver takes the ONE instance that netlists under that
   name. The netlisted name is `ase::inst_path_segment`'s answer, the reader
   the schematic → browser direction already uses (issue 0319), so the two
   directions cannot disagree about what an instance is called. It runs no
   netlister and no symbol's `tcleval(...)` format. The scan behind it
   (`hier_scan`) lists every instance of the current sheet that is called the
   segment or netlists as it; `hier_device` narrows that to the best tier,
   the deck's name first.
2. **The walk can stay.** `hier_walk` takes a third argument `leaf` (default
   0, everything above unchanged), which `browser_descend_to` passes. With it
   on, when the LAST segment resolves and the engine refuses the descend as
   not a block (`xschem get descend_error` answers `not-descendable:<type>`,
   read by `hier_no_sheet`), or when the last segment does not resolve because
   SEVERAL instances could be it, the walk does not roll back. `hier_stay`
   checks, by readback, that the window is standing on the parent of that
   segment, clears the selection, selects the one device by index, reads the
   selection back, and the walk answers a fourth shape,
   `{device <parent path> <instance names> <selected 0|1>}`.
3. **Never the wrong instance.** Several candidates select none, and the
   sentence names them all (`hier_device_msg`): *"'xm9' is a device with no
   sheet of its own; selected M9 at the top level"*, or *"'xm5' could be any
   of 2 instances at the top level (M5, m5); none is selected"*.
   `browser_descend_to` answers 1 only when the device is really selected.

Still an error with a rollback, as before: a last segment nothing on the sheet
answers to; a descend refused for any other reason (`busy`, a schematic or a
symbol that did not load); a device in the middle of a path. Two shapes the
scan cannot see, both misses and never another instance: a format that writes
a literal letter in front of `@name` (`X@name …`), and the second element of a
format that writes two lines. A block whose symbol has no schematic file is
refused by the engine as a failed load, not as "not a block", and stays an
error. Rows BV01 and up of `tests/headless/test_wave_sigbrowser_panes.tcl`.

### The origin guard

`wviewer::hier_origin_ok` is the one claim a readback cannot check. When the
design window's top is *above* the session's design and no raw is loaded there,
the pivot and the verify share the same wrong origin, so a walk would land N
levels off and report success. The guard passes when a raw IS loaded in that
context (`xschem raw loaded` ≥ 0) or when `ase::ui::sod_base_level` says the
window's top IS the session's design; otherwise the command REFUSES and says so.
Neither branch reads `sch_path`.

### Declared limits

* **Vector instances are deferred** — issue 0212. A bracketed segment is
  refused, naming the issue. `sch_path` records the EXPANDED slice `x1[3]` while
  `get_instance` only matches the unexpanded `x1[3:0]`; the `change_sch_path`
  route is written up in the issue.
* **A case-MISMATCHED already-at-target re-walks** rather than no-opping. It
  lands correctly and reports the schematic's spelling; only a byte-exact match
  takes the untouched no-op path.
* **A multi-row target with disagreeing paths is DISABLED, not first-wins.** The
  RMB entry stays grey and the reason goes to the status line.
* **A successful walk clears the selection at every level it traverses**, because
  both `descend -inst` and `go_back` call `unselect_all(1)` in C. The
  already-there path touches nothing.
* **The browser tree does not go stale.** The raw lives in the VIEWER context
  (every `raw read` site is in `wave_viewer.tcl`), so descending the DESIGN
  window touches neither `xctx->raw` of the viewer nor the snapshot behind the
  tree (item 9's D6).
* **`sod_base_level` answers 0 when the session's design is not in the window's
  stack at all** — its own documented rule — so the origin guard passes there
  too. Pre-existing hole in `ase_window.tcl`, asserted as a limit rather than
  closed by item 11.

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
