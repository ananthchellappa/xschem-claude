# Waveform / Graph Subsystem — maintenance reference for Claude Code

**Purpose.** Load this before any waveform/graph work (rendering, the `Raw`
data model, on-canvas graphs, the ASE Waveform Viewer, `@spice_get_voltage`
back-annotation, `.raw` parsing, cursors). It is the map + contracts +
landmines, in the spirit of `doc/claude/WIRING.md` for wires. It complements,
does not replace: the feature spec `doc/claude/specs/waveform_viewer.md`
(ASE-L viewer decisions/ledger) and the human explainer
`waveform_display_explained.md` (same folder).

**Line numbers are approximate**, captured 2026-07-22 (~commit `cf57955c`).
They drift. **Grep the symbol name, don't trust the number.** Every claim
below names a function/struct/token you can re-locate.

**Golden rule of this subsystem:** *a graph is not a type.* It is an `xRect`
on layer `GRIDLAYER(2)` whose `prop_ptr` text contains `flags=graph`. All
durable graph state is `token=value` text in that string. All transient state
is recomputed each draw. Nothing waveform-specific exists in the file format.

---

## 0. The 30-second model

```
  Simulate (external process)                     translate() @spice_get_voltage
        │ writes                                          ▲ reads cursor_b_val[]
        ▼                                                 │
   <cell>.raw ──raw_read()──►  Raw struct  ──get_raw_value()──►  draw_graph()
   (ngspice)   read_dataset()  (xctx->raw,        │              (draw.c) ──► pixels
               save.c          extra_raw_arr[])   │
                                                  ▼
                             graph = xRect(GRIDLAYER, flags=graph)
                             ~30 prop tokens ──setup_graph_data()──► Graph_ctx
                                                                     (transform coeffs)
  Mouse/keys ──waves_selected()/waves_callback() (callback.c)──► mutate prop tokens ──► redraw
  ASE viewer (wave_viewer.tcl): Tcl model ──regenerate()──► places graph rects ──► same C engine
```

---

## 1. File map (who owns what)

| File | Role in this subsystem |
|---|---|
| `src/save.c` | **The `.raw` parser and `Raw` data model owner.** `raw_read`, `read_dataset`, `read_raw_data_block`, `extra_rawfile`, `get_raw_value`, `get_raw_index`, `table_read`, `new_rawfile`, `raw_add_vector`/`raw_deletevar`/`raw_renamevar`, `update_op`, `free_rawfile`. Also `save_box`/`load_box` (graph rect persistence). |
| `src/draw.c` | **The render engine.** `draw_graph_all`, `setup_graph_data`, `draw_graph`, `draw_graph_grid`, `draw_graph_points`, `draw_graph_bus_points`, `draw_graph_variables`, `draw_cursor*`, `show_node_measures`, `get_bus_value`, `graph_fullxzoom`/`graph_fullyzoom`, `find_closest_wave`, `edit_wave_attributes`, `sch_waves_loaded`, `svg_embedded_graph`. **Also the whole waveform-MARKER engine** (`graph_point_at` and its `graph_wave_at`/`graph_near_wave` wrappers, `graph_markers_parse/format/store`, `graph_marker_*`, `draw_graph_markers`, `graph_marker_notify`) — it lives here because the `W_*`/`S_*`/`G_*` macros textually need a local `Graph_ctx *gr`. See `doc/claude/specs/graph_markers.md`. |
| `src/callback.c` | **On-canvas interaction.** `waves_selected` (gate/hit-test), `waves_callback` (gesture engine), `backannotate_at_cursor_b_pos`, the marker gesture helpers (`graph_marker_press`/`_drag_to`/`_release`/`_drag_abort`), the input-binding table (`init_input_bindings`, `act_graph_forward`, `current_input_ctx`, `dispatch_input_action`), and 15 inline `if(waves_selected){waves_callback}` guards. |
| `src/scheduler.c` | **Tcl verb surface.** `raw`/`raw_query` block, `raw_read`/`raw_clear`/`raw_read_from_attr`, `add_graph`, `annotate_op`, `cursor`, `get graph_lastsel`, `get graph_flags`/`graph_near_wave`/`graph_trace_at`/`graph_marker_*`/`graph_rects`, the `graph_marker` sub-verb family, `setprop rect` special tokens (fullxzoom/fullyzoom). |
| `src/token.c` | `translate()` `@spice_get_voltage`/`@spice_get_node` → substitutes `cursor_b_val[]` into symbol text (C back-annotation display). |
| `src/xschem.h` | `Raw` struct (~975-998), `Graph_ctx` (~1051-1099), `GraphMarker`/`GraphPointHit` (~1108-1130), `SPICE_DATA` (`#define` = `double`, ~505), coord macros `W_*`/`S_*`/`DS_*`/`G_*`/`DG_*` (~465-480), graph constants `GRAPH_REORDER_HANDLE_W`/`GRAPH_TRACE_DROP_W`/`GRAPH_TRACE_PICK_TOL`/`GRAPH_MAX_SEL_WAVES`/`GRAPH_MARKERS_MAX`/`GRAPH_MARKER_TOL` (~388-450; there is deliberately **no** marker CREATION tolerance -- landmine 45), `xctx` graph fields (`raw`, `extra_raw_arr`, `graph_flags`, `graph_master`, `graph_lastsel`, `graph_cursor1_x/2_x`, `graph_struct`, `graph_marker_*`). |
| `src/wave_viewer.tcl` | **ASE Waveform Viewer** — a real read-only editor window driven by a pure-Tcl model. See §8 and the spec. |
| `src/xschem.tcl` | Sim launch (`simulate`, `execute`), `sim()` array + simconf dialog, native graph editor `graph_edit_properties`, `graph_add_nodes_from_list`, `load_raw`/`waves`. |
| `src/ngspice_backannotate.tcl` | Legacy pure-Tcl `.raw` op reader → `ngspice::ngspice_data`. Largely vestigial; `update_op` writes the same array. |
| `src/create_graph.tcl` | Standalone scripted graph recipe (non-ASE). |
| `src/rawtovcd.c` | **Standalone binary** (own `main`), not linked in. `.raw`→VCD for gtkwave. Has its *own* independent parser. |
| `src/gtkwave_server.tcl` | Optional TCP server (port 2022) for gtkwave→xschem command push. |

---

## 2. Data model

### 2.1 `Raw` — the in-memory dataset (`xschem.h` ~975-998)

One `Raw` = one `(rawfile, sim_type)` dataset-group. Fields:

- `char **names` — `names[nvars]`, variable names, **lowercased**.
- `SPICE_DATA **values` — **`values[nvars+1]`** pointers (note the **+1**:
  last column is scratch for custom-wave expressions). Each column is a flat
  `double[allpoints]`. **Column-major**: `values[var][point]`.
- `int nvars` — variable count. **For AC this is 4× the file's complex vars**
  (mag/phase/re/im materialized, interleaved at indices `i<<2 .. (i<<2)+3`).
- `int *npoints` — `npoints[datasets]`, points per dataset (datasets can
  differ in length).
- `int allpoints` — `sum(npoints)`, total columns' length.
- `int datasets` — number of `Plotname` sections concatenated.
- `Int_hashtable table` — lowercased-name → column index (O(1) lookup).
- `char *sim_type` — `"tran"|"dc"|"ac"|"op"|"noise"|"table"|...`.
- `double *cursor_b_val` — `cursor_b_val[nvars]`, interpolated value at cursor
  B; **source for schematic back-annotation**. Plus `annot_p`/`annot_x`/
  `annot_sweep_idx`.
- `char *schname`, `int level` — hierarchy schematic + `currsch` at load time.
  **`sch_waves_loaded()` gates all access on these.**
- `double sweep1, sweep2` — optional half-open `[sweep1, sweep2)` load window
  on the sweep variable (`-1/-1` = load all).

`SPICE_DATA` is hardcoded `double` (the `float` path is nominal only —
struct, `fread`, and all math assume `double`).

### 2.2 The registry (`xctx`, `xschem.h` ~1529-1541)

- `xctx->raw` — the single **currently-active** `Raw*`.
- `xctx->extra_raw_arr[]` (+ `extra_raw_n`/`extra_raw_size`/`extra_idx`/
  `extra_prev_idx`) — all loaded raws. Grown by 20. `extra_idx` = active,
  `extra_prev_idx` = for switch-back.
- **Lazy migration:** the base raw is copied into `extra_raw_arr[0]` only on
  the first `extra_rawfile()` call. Before that, `extra_raw_n` can be 0 while
  `xctx->raw` is set.
- **Per-context:** each open window/tab has its own `xctx`, hence its own raw
  + registry. "The loaded raw" always means `xctx->raw` of the current ctx.

### 2.3 The graph object (an `xRect`)

- Type: `xRect` on layer **`GRIDLAYER` (2)** with `flags` token containing
  `graph`. **There is no `GRAPHLAYER` constant** — do not grep for one.
  Note `GRIDLAYER == SELLAYER == 2` (same `#define` value reused).
- `xRect.flags` (`unsigned short`) is a **cache** of the `flags` text token,
  set by `set_rect_flags()` (`actions.c` ~860). Bits: `1`=graph, `2`=unlocked
  (x-axis not synced), `4`=private_cursor (cursors stored per-rect not
  global), `1024`=image, `2048`=unscaled. **If you edit `prop_ptr` directly,
  you MUST call `set_rect_flags()`** or `flags&1` goes stale (that's why
  load/paste/store/setprop all call it).
- Durable state = ~30 `token=value` tokens in `prop_ptr`: `node` (trace
  list), `color`, `sweep`, `x1`/`x2`/`y1`/`y2` (data window), `divx`/`divy`,
  `subdivx`/`subdivy`, `digital`, `logx`/`logy`, `rawfile`, `sim_type`,
  `autoload`, `unitx`/`unity`, `cursor1_x`/`cursor2_x` (if private),
  `hcursor1_y`/`hcursor2_y`, `mode` (0 Line / 1 HistoV / 2 HistoH), `rainbow`,
  `hilight_wave`, `ypos1`/`ypos2` (digital band), `linewidth_mult`, `dataset`.
- **Persistence is nothing special:** `save_box` (`save.c` ~2746) writes
  `B <layer> x1 y1 x2 y2 {prop}`; `load_box` (~3038) reads it. The `.raw`
  samples are **never** saved — only the `rawfile=` path (or a base64
  `spice_data` embed via `embed_rawfile`/`raw_read_from_attr`).

### 2.4 `Graph_ctx` — transient render context (`xschem.h` ~1051-1099)

Single shared instance `xctx->graph_struct`. **Rebuilt per graph per draw** by
`setup_graph_data()`. Holds decoded flags, data window `gx1..gy2`, plot box
`x1..y2` (container minus 14% margins), and the cached affine transform
coefficients `cx/dx/cy/dy` (graph→xschem) and `scx/sdx/scy/sdy` (graph→screen
direct), plus digital variants. **Not persisted; do not treat as per-graph
storage** — everything durable round-trips through `prop_ptr`.

### 2.5 The `node` trace mini-language (fragile — read before touching)

`node` is a `"`-quoted, **newline-separated** list, one entry per trace. Each
entry's meaning is set by **punctuation** (parsed in `draw_graph`
~6019-6130 and `find_closest_wave`):

- bare `v(out)` → scalar node
- `,` inside → **bus** (`alias;sig[3],sig[2],...`) → `draw_graph_bus_points`
- whitespace in the post-`;` part → **expression** (`expression=1`) →
  `plot_raw_custom_data` + `eval_expr`
- `alias;expr` → text before `;` is the legend label
- `%N` suffix → select dataset N; `%rawfile%simtype` → select source
- `tcleval([...])` → live Tcl substitution at draw time (scope symbols use it)

`color=` and `sweep=` are **separate, space-separated, positional** lists
indexed against `node`. They can desync silently (tolerated by cycling
defaults; no integrity check), and a **short `sweep` list carries its last
entry forward** for every remaining trace — which is why every walker must
consume the sweep token before it skips an entry (landmine 38). Editing traces = rewriting the whole `node`
string, not appending records. In-memory alias inner quotes are
single-backslash-escaped; **`save.c` doubles the backslashes on file write**.

---

## 3. Load pipeline (save.c)

`raw_read` (~1002) → `read_dataset` (~593) → `read_raw_data_block` (~469).

- `raw_read` **refuses if `*rawptr` is already set** — callers must
  `extra_rawfile(3,...)` / `raw_clear` first. Allocates `Raw`, inits hash,
  parses, records `rawfile`/`schname`(=`xctx->sch[currsch]`)/`level`(=`currsch`),
  computes `allpoints`, triggers cursor-B backannotation if cursor2 active,
  greens the Waves menu.
- `read_dataset` walks the ASCII header: `Plotname:` selects `sim_type`
  (matches requested `type`, or first if NULL — this filters a multi-analysis
  file to one analysis); `Flags: complex` → ac; reads `No. Variables:`/
  `No. Points:`; reads `Variables:` names (lowercased, Xyce `:`→`.`). On
  `Binary:` → `read_raw_data_block(1,...)`; on `Values:` (ascii) →
  `(0,...)`. **Non-matching analyses are skipped** by seeking
  `nvars*npoints*sizeof(double)` (binary) — relies on exact block sizing.
  All datasets must share identical `nvars`. Multi-point `op` is auto-promoted
  to `dc`. AC quadruples `nvars` and synthesizes mag/phase/re/im columns
  (mag `= sqrt(re²+im²)`, phase `= atan2·180/π`, zero mag clamped to 1e-35).
- `extra_rawfile` (~1214) — the multiplexer. `what`: 1=read+activate (dedup by
  rawfile+sim_type; `~/` subst via Tcl), 2=switch (by name+type / int index /
  next), 3=remove+free (all / by index / by name+type; compacts, resets to
  arr[0]), 4=info, 5=switch-back. Bit 32 suppresses warnings. Lazily migrates
  `xctx->raw` → arr[0].
- Accessors: `get_raw_index` (~1677) name→column, **fuzzy** (tries case
  variants, `v(node)` wrap, `i(v.x...)` fixup), gated by
  `sch_waves_loaded()>=0`, returns −1 on miss. `get_raw_value` (~2323) returns
  `values[idx][ofs+point]` where `ofs = sum(npoints[0..dataset-1])`
  **recomputed every call** (O(datasets) — see fruit #2).
- Non-ngspice sources: `table_read` (~1509, CSV/table), `new_rawfile` (~1121,
  synthetic sweep-only), `raw_read_from_attr` (~932, base64 `spice_data`).
- `free_rawfile` (~854) — frees `values[0..nvars]` (**`<= nvars`**, incl. the
  scratch column).

---

## 4. Render pipeline (draw.c)

`draw()` → `draw_graph_all((graph_flags & (2|4)) + 8 + …)` (call ~7470, fn
~6476) iterates `rect[GRIDLAYER]` with `flags&1`; per graph:
`setup_graph_data(i,...)` → `draw_graph(i,...)`.

- `setup_graph_data` (~3534): reads tokens → `Graph_ctx`; 14% margins; text
  sizes; transform coeffs. **`cy = -h/gh` is NEGATIVE** (xschem/screen Y grows
  down, data Y grows up). Early-returns if off-screen — landmine 37 has the two
  reasons it is unsafe to call as a query.
- `draw_graph` (~5924): resolves cursor A/B (global `graph_cursor1_x/2_x`, or
  per-rect token if `flags&4`); `draw_graph_grid` under `flags&8`; tokenizes
  `node`; sets a bbox clip (`bbox(SET,...)`, `select.c`); per node, loops
  datasets/samples, detects DC sweep wraps / window-exit to split polylines,
  fills `point[].x = CLIP(S_X(xx), ±30000)`; dispatches to
  `draw_graph_points` (scalar) or `draw_graph_bus_points` (bus); then cursors
  + `show_node_measures`; then `draw_graph_markers` under `flags&8` (~6344) and
  the `flags&16` on-screen chrome (active-strip bar, reorder grip).
- `draw_graph_points` (~3313): fills `point[].y` (analog `S_Y`, or digital
  `DS_Y` band rescale `yy=c+yy*s2`, or `mylog10` for logy), `CLIP`s to short,
  `XDrawLines` to **both** `window` and `save_pixmap`, chunked at
  **`MAX_POLY_POINTS`=65536** (Xlib limit, not perf — last point of each chunk
  repeated as first of next). Modes 1/2 = histogram bars.
- `draw_graph_bus_points` (~3228) + `get_bus_value` (~2795): multi-bit bus as
  two rails + hex labels; per-bit threshold `vthl`/`vthh` (20%/80%); `X` on
  transition. **Fixed 1024-char `busval`/`old_busval` buffers** (fruit #7).
- Cursors: `draw_cursor` (~3758)/`draw_cursor_difference` (~3783) (x),
  `draw_hcursor*` (y), `show_node_measures` (~4020) interpolates node value at
  cursor A.
- Picking: `find_closest_wave` (~4350, no threshold, reads the C mouse mirror)
  vs `graph_point_at` (~4654, caller pixels + a real screen-pixel
  point-to-segment threshold) — landmine 33. `graph_wave_at` (~4881) and
  `graph_near_wave` (~4891) are thin wrappers over `graph_point_at`.
  All three resolve the `sweep` token BEFORE any skip — landmine 38.
  `graph_point_at` also brackets `graph_flags` 128\|256 (landmine 37) and
  unwinds its `extra_rawfile` switch **only when the switch took** (landmine 40).
- Markers (`doc/claude/specs/graph_markers.md`): `graph_markers_parse` (~4927,
  **never truncates** — the 512 cap is a creation bound) … `graph_marker_notify`
  (~5961); parse-once pool `graph_markers_collect` (~5093), label core
  `graph_marker_text_rec` (~5139) with `graph_marker_text` (~5211) a by-number
  wrapper over it, renderer `draw_graph_markers` (~5311), hit-test
  `graph_marker_at` (~5387), **callout geometry `graph_marker_label_box` — THE
  single source of truth, called by the renderer AND the hit-tester so the drawn
  box and the clickable box cannot disagree** (with `graph_marker_pad_box` for
  the padding and `graph_marker_txtsize` for the one font size both callers must
  share; anything that changes the box goes INSIDE that function, never at a call
  site), data read `graph_marker_sample` (~5536,
  bails when its raw switch fails — the pixel path already did),
  the read-only gate `graph_marker_ro_refuse` (~5624), and the window-wide
  dangling-`prev` sweep `graph_marker_clear_prev_n` (~5747) with
  `graph_marker_clear_prev` (~5774) a one-element wrapper over it.
  **The sweep is ONE pass for the whole doomed set**, not one pass per number:
  it must be window-wide (a partial `delete -all <gi>` leaves partners on the
  other strips), so the per-number form is O(deleted × surviving) — the same
  full-window-rescan-per-record shape the parse-once pool exists to remove.
  Measured: `delete -all` at 4000 markers took 10 s, now 41 ms.
- Export (raster only): `svg_embedded_graph` (~7040, base64 PNG),
  `ps_embedded_graph` (`psprint.c` ~253, ASCII85 JPEG q40, needs
  HAS_LIBJPEG+HAS_CAIRO). Traces/grid are raw **Xlib**; only text + export
  rasterization use cairo.

**Coordinate macros** (`xschem.h` ~465-480): `W_X`/`W_Y` graph→xschem,
`S_X`/`S_Y`/`DS_Y` graph→screen, `G_X`/`G_Y`/`DG_Y` inverse. **They reference a
local `Graph_ctx *gr`** and assume `setup_graph_data()` ran for the right
graph. Wrong scope / stale `gr` → silently mis-transformed waveforms.

---

## 5. Interaction (callback.c)

- **Pre-emption layer, not a mode.** 15 inline
  `if(waves_selected(...)){ waves_callback(...); return; }` guards, one per
  event type. A new event path needs the guard added or graphs won't respond
  there.
- `waves_selected` (~77): **side-effectful gate/hit-test.** Skips if a
  schematic gesture is pending (STARTZOOM/RECT/WIRE/MOVE/... mask), if
  `graph_use_ctrl_key` && Ctrl up, if Alt held; **deliberately lets Button2
  pan and Shift+Button1 through** to canvas. `POINTINSIDE` (5px border) per
  graph rect; hit → `graph_master=i`, tcross cursor, return 1; miss →
  `graph_master=-1`, drop GRAPHPAN, return 0. **Cannot be used as a pure
  predicate.**
- `waves_callback` (~724): the gesture engine. Operates on `graph_master`
  first (**waveform-MARKER press/motion/release, which pre-empts everything
  below it** — `doc/claude/specs/graph_markers.md` §7; **LMB-click wave-bold**
  via `graph_wave_at` at `GRAPH_TRACE_PICK_TOL` — issues 0152 and 0174, see
  landmines 20 and 33 (it used `find_closest_wave` until 0174); RMB-on-legend
  per-trace bold via `edit_wave_attributes`, hover measurement tooltip via
  `G_X`/`G_Y`, cursor grab within 10px, numeric cursor set,
  the **`-3` DOUBLE-CLICK arm, which since issue 0189 tests for a MARKER FIRST**
  (`graph_marker_at` at `GRAPH_MARKER_TOL` -> `graph_marker_select_pair()` +
  `need_all_redraw`, because the partner may live on another strip) and only then
  falls through to `edit_wave_attributes` / `graph_edit_properties` -- a marker
  anchor sits on a trace by construction and a callout is clamped inside the plot
  box, so without that rung a double-click aimed at a marker opened the
  graph-properties dialog; the `-1e30` poison line above it is untouched and is
  what still stops the trailing release wave-bolding (landmine 46),
  `a`/`b`/`s`/`t` keys plus `m` = create marker, `d` = create marker with a
  delta block, and `M` = the measurement tooltip **relocated off `m`**.
  ⚠ `m`/`d` gate on the strip's **PLOT BOX**, not on a distance to a trace
  (issue 0188): `graph_marker_create()` asks `graph_plotbox_at()` and then picks
  with `graph_point_at(..., 1e30, -1, -1, ...)` -- byte-for-byte the pair
  `draw_graph_snap_cursor()` makes, so the marker lands under the item-9
  diamond by construction. Trace SELECTION in the same arm keeps its 10-px
  `GRAPH_TRACE_PICK_TOL` (landmines 33 and 45). A marker
  is durable CONTENT, so the three mutating keys `m`/`d`/`Delete` ARE refused in
  a read-only buffer — but **not here**: the arms call the ops unguarded and the
  gate is `graph_marker_ro_refuse()` down in the mutating primitives
  (`draw.c` ~5624), as a NON-MODAL `ciw_echo`. Two reasons, both learned the
  hard way: `readonly_block()` pops a MODAL and a modal on a keystroke deadlocks
  any script that drives the refusal path (it hung the marker suite under a real
  `$DISPLAY`); and the key arms do not cover the DRAG-COMMIT path
  (`graph_marker_release` → `anchor_at`/`label_offset` → `graph_marker_update`),
  which reaches no key arm at all and would otherwise let a MOUSE gesture edit a
  read-only buffer permanently, with no undo point. The read-only ASE viewer
  gets through by forwarding those keys — **and the marker-drag release** —
  inside `wviewer::with_edit`), then loops
  all graphs: participation test `r->sel || (same_sim_type && !(flags&2)) ||
  i==graph_master`; wheel zoom/pan, arrow pan/zoom, `f`=fit, drag pan,
  Button3-drag **XY box-zoom** (issue 0142: interior drag zooms x1/x2 across
  participating graphs + y1/y2 on the master, with a live rubber rect via
  `drawtemprect`/`gctiled`; left-margin drag = Y-only). **No snap grid in
  graphs** (issue 0143): `waves_callback` overrides `mousex_snap`/`mousey_snap`
  with the raw pointer at entry, so every graph gesture **reached through that
  handler** is unsnapped — which is not the same as "on a graph" and was read as
  if it were for two issues (landmine 44). The ASE waveform viewer no longer
  relies on it: its context sets `no_snap`, and `callback()` computes both fields
  unsnapped at the SOURCE for that window (issue 0177). The override above still
  covers graphs EMBEDDED IN A SCHEMATIC, whose context keeps its grid.
  **LMB press-drag in an AXIS-NUMBER MARGIN = an axis-only zoom** (issue 0190,
  `doc/claude/specs/waveform_viewer_modes.md` §17). It arms at the **END of the
  cursor-grab block** — i.e. below the marker press (`mkpress` pre-empts the
  whole block) and below all four cursor grabs, gated on
  `!(graph_flags & (16|32|512|1024))`, because a cursor's line crosses the margin
  and its numeric readout is *drawn* in it. `graph_axis_press_arm()` calls
  `graph_axis_at()` with the EVENT's own pixels; the motion paints a
  `drawtemprect` **band** beside the Button3 rubber (same `gctiled`/`gc[SELLAYER]`
  /`graph_rubber_*` bookkeeping — **not** a prop token and **not** `draw_graph`
  bit 16), and the release in the `finish:` section calls `graph_axis_map()` then
  `graph_axis_zoom()`. ESC drops it through `graph_axis_drag_abort()` in
  `abort_operation()`. The GRAPHPAN latch grew `|| xctx->graph_axis_drag` for the
  same reason the marker drag did (landmine 36): the Y region is "left of the
  plot box, anywhere in the container", so a top-left-corner press on a strip
  with no legend entry there arms with `graph_top` already 1.
  **CTRL+WHEEL in the same two margins = an axis-only zoom about the pointer**
  (issue 0191, `doc/claude/specs/waveform_viewer_modes.md` §18). A new `else if`
  in the SAME chain as the Button1 cursor grab and the Button3 numeric cursor,
  gated on `(state & ControlMask) && !(state & ShiftMask) && !graph_use_ctrl_key`,
  with `graph_axis_at()` as the region oracle and `graph_axis_wheel_map()` +
  `graph_axis_zoom()` for the rest. It has to live here and NOT in the binding
  table — landmine 48. A `NONE` region answer falls through to the plain-wheel
  pan, which is the whole "the body is unchanged" contract; the local
  `wheel_axis_done` is what carries it, because the plain-wheel arms are a
  DIFFERENT if/else chain in the per-graph loop below `finish:` and an `else if`
  cannot reach them. No GRAPHPAN term is owed here (the latch admits
  Button1/2/3 only, so a Button4/5 press never enters it).
  **Writes results into `prop_ptr` tokens via
  `subst_token`, then `draw_graph()`.**
- **Two different flag words — do not confuse:** `xctx->graph_flags` =
  per-session cursor/measure modes (bits 2/4=draw A/B, 16/32=move A/B,
  64=tooltip, 128/256=draw hcursor1/2, 512/1024=move hcursor). `xRect.flags`
  = per-graph type/lock (1/2/4). The **authoritative `graph_flags` legend is
  `callback.c` ~703-715**; the `xschem.h` ~1544 one is incomplete (stops at
  64). A marker drag deliberately sets **no** `graph_flags` bit — it has its own
  `xctx->graph_marker_*` fields, exposed as `xschem get graph_marker_drag`, and
  the MMB-pan / RMB-rubber guards had to grow an explicit `!graph_marker_drag`
  term because the `graph_flags` term cannot see it.
  **`graph_marker_drag` and `graph_marker_dragmode` are two different questions.**
  `drag` is what was GRABBED (0/1/2) and is the exported, Tcl-visible value —
  `wviewer::marker_grabbed`, `wviewer::strip_drag_release`'s `with_edit` bracket,
  `scheduler.c`'s `part == 1 ? "anchor" : "label"` and ~27 test assertions all
  rest on it. `dragmode` is what the gesture DOES (`GRAPH_MARKER_MODE_*`),
  latched at press from the selection state, C-internal, and it is what the
  release commits on. Do not overload `drag` with a third value.
- `graph_master` (`xschem.h` ~1554) = MOUSE state, tracks pointer, can be −1
  or stale. `graph_lastsel` (~1582) = last CLICKED/added, persists — **this**
  is the trace-add target. Don't confuse them.
- `backannotate_at_cursor_b_pos` (~425); marker gesture helpers
  `graph_marker_press` (~567) / `_drag_to` (~610) / `_drag_clear` (~664) /
  `_drag_abort` (~674) / `_release` (~684). `_drag_abort` is called at **every**
  fresh Button1 press (~784, where `graph_press_x/y` is seeded), not only on
  release: the ASE viewer binds `<Shift-ButtonRelease-1>` /
  `<Alt-ButtonRelease-1>` to a bare `{break}`, so a modifier-held release never
  reaches C and the release-side teardown cannot run. `_drag_to` is the fourth
  site that brackets `graph_flags` 128\|256 around `setup_graph_data`
  (landmine 37) — it runs once per motion event.
- Adding a trace: **no drag-onto-graph gesture.** Highlight nets →
  `act_highlight_send_waveform` (~3894) → `hilight.c` send →
  `graph_add_nodes_from_list` (`xschem.tcl` ~4312) appends to
  `graph_lastsel`'s `node`.
- Data-driven bindings: `init_input_bindings` (~4287) seeds ACTX_OVER_GRAPH
  rows → `graph.forward` (`act_graph_forward` ~3802 → `waves_callback`).
  `current_input_ctx` (~4485) picks ctx via `waves_selected()`. To add a graph
  key you need **both** the branch in `waves_callback` **and** the binding row —
  *unless* the key already has an inline `waves_selected` guard in
  `handle_key_press` (`m`, `M`, `Delete` do), in which case a row would make
  that guard dead code. `d` needed the row (`ACTX_OVER_GRAPH`, mirrored in
  `keybindings.csv` as `key,100,0,graph,graph.forward,`); `Delete` deliberately
  did **not**, because a row would consume it over a graph unconditionally.

---

## 6. Back-annotation (numbers on the schematic)

- `annotate_op` (`scheduler.c` ~1995): loads op→dc→tran section via
  `extra_rawfile`, **forces `live_cursor2_backannotate=1`** (side effect),
  calls `update_op`.
- `update_op` (`save.c` ~1465): copies point 0 of each var into
  `cursor_b_val[]` **and** into Tcl `ngspice::ngspice_data`.
- `backannotate_at_cursor_b_pos` (`callback.c` ~404): on cursor-B move,
  interpolates each var at the cursor's sweep position into `cursor_b_val[]`,
  runs `$cursor_2_hook`, redraws. Live cross-probe.
- Display: `translate()` `@spice_get_voltage` case (`token.c` ~4685) — for a
  **1-pin** instance (`no_of_pins==1`), resolves net → fq lowercased node →
  `get_raw_index` → substitutes `cursor_b_val[idx]` (eng-formatted); `0`/`GND`
  →0, unknown→`-`. Gated by `live_cursor2_backannotate` &&
  `sch_waves_loaded()>=0`. `@spice_get_node`/currents go via
  `ngspice::get_current/get_node` reading `ngspice_data`.
- **Two engines coexist** (C `update_op`/`cursor_b_val` + Tcl
  `ngspice::read_raw`/`ngspice_data`); `update_op` writes both. Op text is
  layer-15 (hidden unless `show_hidden_texts=1`).

---

## 7. Sim launch & `.raw` discovery (xschem.tcl)

- `simulate_from_button` (~3986) → `simulate` (~4011): looks up `sim()` array
  default for `netlist_type`, subst's the cmd template (`$N` netlist, `$n`
  no-ext, `$s` cell, `$S` sch, `$d` dir), `cd`s to `netlist_dir`, runs via
  `execute` (~352, `open |cmd`). **Does NOT netlist first.** `fg=1` templates
  block on `vwait`. Green/red via `execute_fileevent` (~242) → callback.
- Canonical raw path: `$netlist_dir/<rootname-of-schname>.raw` (but an
  overridden `netlist_name` silently redirects it).
- `sim()` array (built by `set_sim_defaults` ~2899, persisted
  `$USER_CONF_DIR/simrc`, edited via simconf ~3076): keys `cmd`/`name`/`fg`/
  `st`. Interactive vs batch is purely a template choice. External viewers
  (gaw/gtkwave/bespice) are `*wave` tools launched via `waves external`.

---

## 8. ASE Waveform Viewer (wave_viewer.tcl) — see spec for full detail

- **Not a widget** — a real xschem editor toplevel (`load_new_window`), held
  `readonly` + `no_grid`, toolbar pack-forgotten, replacement menubar, all
  canvas bindings swept by `strip_bindings` (~1696) and replaced with
  `key_filter`/`btn3_filter`/wheel handlers. The **same C engine** draws its
  graph rects.
- Tcl model = single source of truth: `wviewer::layouts` (~125) `token →
  {sharedx graphs {{traces {{expr name vec color}...} logx logy x1 x2 y1 y2}}}`.
  `regenerate` (~651) is the one honest direction model→canvas.
- **All mutation MUST go through `with_edit` (~383):** `switch_ctx` (verify!)
  + `autosave_backup 0` + `readonly 0` + run + `set_modify 0` **before**
  `readonly 1`. Skipping it writes `untitled~.sch` to cwd or dirties the
  buffer.
- **Tcl mirrors that exist only because C lacks getters:** `graphbb` (~103,
  bbox registry — `xschem object rect` returns no coords), `cva`/`cvb`/`cvr`
  (~136, cursor state — no `xschem get graph_flags`), `validate_rpn` (~600, a
  hand-copied `save.c` operator table — the C evaluator swallows errors).
  **These are the desync-risk surface; closing the C-getter gaps deletes
  them** (see backlog #1, #5, #6).
- Scripting seams (pure, headless-testable): `add_trace` (~858, returns error
  string, never throws), `display_raw` (~735), `graph_props`/`band_geometry`/
  `next_color`/`interp_value`, the issue-0153 color policy
  (`first_unused_color`, `graph_colors`, `colors_in_graphs`, `plan_colors`,
  `predict_colors` — landmine 22; `add_trace`/`plot_signals` take an optional
  explicit color, which the Direct Plot picker uses to pin what it painted on the
  schematic), `zoom_about` (0146 anchor-preserving range scale),
  `wheel_zoom` (issue 0144 zoom worker: X on every
  strip, Y only on the pointed strip — the seam tests drive instead of the
  gesture). **All four zoom affordances route through it:** `wheel`'s ctrl arm and
  `graph_zoom` (View-menu Zoom In/Out + `Z`/`Ctrl-z`, issue 0145) only resolve the
  pointed strip via `graph_at_pointer` and delegate.
- `switch_ctx` **verifies** the switch took — it silently no-ops inside a
  raised ctx semaphore (e.g. `ase::wait`'s vwait); `auto_plot` defers via
  `after idle` for exactly this reason (inline aimed clear/read at the DESIGN
  window — probe-verified data loss).
- **Plot modes + target strip (issue 0151,
  `doc/claude/specs/waveform_viewer_modes.md`).** Per-window `mode`
  (`single|multi`, seeded from `wviewer_plot_mode`, default `single`) and
  `target` arrays keyed by token, alongside the `sharedx` mirror; both persist
  in the `viewer` state dict as trailing `mode`/`target` keys. The landing
  policy is the PURE `plan_plot` (mode, ngraphs, target, n, **auto-graph
  index**) applied by `plot_signals` — the one seam `ase::ui::dp_finish` calls.
  **The auto-plot graph is never a landing site** (auto_plot clears it every
  run), so single-plot with the target on it appends a strip instead — or, since
  the 0171 follow-up, REUSES an empty one: `plan_plot`'s 6th arg `empties`
  (`empty_graph_indices` = traceless, non-auto strips) is filled before anything
  is appended, in index order, in BOTH modes. Multi-plot used to append
  unconditionally, so a strip left by Clear All or Add Graph was a permanent
  blank band. `plot_signals` and `predict_colors` must pass the SAME list or the
  picker's painted color drifts from the trace it predicts. Multi-plot grows the
  stack UPWARD (2026-07-27): created strips go at the FRONT of the model list and
  a batch is laid out newest-first (`v1 v2 v3` -> `v3` on top). `plan_plot`
  encodes that in the INDICES — its multi targets are **post-insert** — and
  `plot_signals` does the actual front-insert AND shifts the stored target by the
  same amount, because inserting renumbers every strip already on the canvas.
  A caller that appends instead scrambles the batch. Model order is therefore
  NOT pick order: compare colors per signal, never by walking the strips.
  Commands: `plot_mode` / `set_plot_mode` (single|multi|invert) /
  `target_strip` / `set_target_strip` / `current_token`, all with an optional
  token defaulting to the viewer owning the current xschem ctx; changes are
  logged replayably via the `log_action` seam (**resolved** word + explicit
  token, on real changes only). `<ButtonPress-1>` re-targets and then forwards
  the press to C by hand (it is more specific than the kept generic `<Button>`,
  so the forward is mandatory).
- **Strip drag-to-reorder + the LMB/MMB split (2026-07-27,
  `doc/claude/specs/waveform_viewer_modes.md` §12).** A strip is one graph dict of
  `layouts`, so reordering it is a LIST MOVE (`reorder_graphs`, PURE) plus a
  `regenerate` — never a schematic move of the rect, and never a field-by-field
  rebuild (the dict carries traces, colors, axes, `auto 1` and any future key).
  `move_strip {from to ?token?}` is the one mutation: `to` is the **final index**
  the strip occupies, not an insertion slot. Three things it must do in order and
  that a new caller must not skip: **capture_live_graph_state** first (the C
  engine writes MMB pan / RMB box-zoom ranges and the wave-bold `hilight_wave`
  STRAIGHT into the rect prop where the model never sees them, and `regenerate`
  re-places every rect FROM the model — the `move_marker`/`graph_range` argument,
  generalized); remap the stored target with the PURE `reordered_index` **in
  place**, not through `set_target_strip`, or replay gets a second target line for
  an internal consequence; and log exactly one resolved line, preceded by a
  `set_target_strip` line only when the press really moved the target.
  The gesture seams (`strip_drag_press/motion/release/cancel`) hit-test with the
  EVENT's own pixels via `strip_bands_px` — **never `graph_at_pointer`**, whose C
  mouse mirror is stale for a press with no preceding Motion. The press forwards
  to C verbatim in every case and then decides whether to also arm: it refuses
  inside the 10-px trace zone (`xschem get graph_near_wave`) and when the press
  grabbed a cursor (`xschem get graph_flags` bits 16/32/512/1024). `<B1-Motion>`
  and `<ButtonRelease-1>` are MORE SPECIFIC than the kept generic
  `<Motion>`/`<ButtonRelease>`, so their non-drag paths must forward exactly once
  and the release must also do the readout refresh the generic bind carried.
  **The graph pan moved from LMB to MMB in `callback.c` and that is engine-wide**
  — see landmine 31.
- **Trace drag BETWEEN strips (2026-07-28,
  `doc/claude/specs/waveform_viewer_modes.md` §13).** The other half of that same
  LMB seam: a press INSIDE the 10-px trace zone (the one the reorder refuses)
  picks that trace up — the pointer becomes `hand2` on the PRESS, >3 px of travel
  starts the drag, the destination strip follows the pointer and is framed
  (`reorder_handle=4`), release over a DIFFERENT strip commits, everything else
  (same strip, sub-threshold, Escape) commits and logs nothing so the issue-0152
  wave-bold click is untouched. A cursor grab still beats the trace grab.
  `move_trace` is the one mutation and repeats `move_strip`'s ordering contract
  verbatim; the model side is PURE (`move_trace_in_graphs` plus the node/model
  index mapping). The C pick is `xschem get graph_trace_at`. Everything
  index-shaped here is in NODE space — landmine 34, which also carries the
  empty-destination range-blanking rule and the bold-marker hand-off.
  **Since issue 0192 that drag carries the whole SELECTION** when the pressed
  trace is part of one (`waveform_viewer_modes.md` §19): the moving set is
  decided at PRESS time in `trace_drag_arm` (the release is forwarded to C
  *before* the drop runs, and a no-travel release collapses the selection — so
  drop-time would be a coincidence, not a contract), carried in `tdrag_pairs`,
  previewed as a set, and applied by the PURE fold `move_traces_in_graphs` under
  the one mutation `move_traces`. A press on an UNSELECTED trace is byte-for-byte
  the old gesture, `wviewer::move_trace` log line included — landmine 49.
- **Undo/redo of viewer edits (2026-07-28,
  `doc/claude/specs/waveform_viewer_modes.md` §14).** `u` / `U` on the
  `WaveViewer` bindtag. **Not the C undo stack** — a viewer edit changes the TCL
  MODEL and the buffer is readonly, so the history is a per-window stack of model
  SNAPSHOTS (`{graphs target}`) pushed by the mutating command itself, right
  after its `capture_live_graph_state` (so a mouse pan/zoom/bold comes back with
  the undone edit). `wviewer::push_undo` is the extension seam: any new model
  mutation becomes undoable by calling it at the same point; today that is
  `move_strip`, `move_trace` and `marker_changed`. Window OPTIONS (plot mode,
  sharedx, cursors, the raw) are outside a snapshot on purpose. Transient:
  cleared on open, `forget` and `restore`, never serialized.
  **The ordering is *capture → push_undo → mutate*, all three, in that order.**
  `marker_changed` is the case that shows why each is load-bearing: without the
  capture, one `u` after creating a marker also reverted an unrelated pan; with
  the capture but no `skip_markers` argument it would fold the new marker into
  the model *before* snapshotting it, so `u` would restore the very marker it
  was meant to remove — which is the same defect as pushing after the mutation,
  arriving by the other door. Hence `capture_live_graph_state {token
  {skip_markers 0}}`: a mutating command captures the live state it did **not**
  produce and leaves out the one key it is about to write.
- **Clear All + the `WaveViewer` bindtag (issue 0171,
  `doc/claude/specs/waveform_viewer.md`).** `clear_all ?token?` drops every graph
  and trace and leaves ONE `empty_graph` (target back to 0), KEEPING the plot
  mode, `sharedx`, the cursor mirrors and the **loaded raw** (a `raw clear` would
  kill the `raw add` vectors and force a re-run); the `auto 1` marker goes, so
  the next auto-plot APPENDS its strip. Logged on EVERY successful call, not
  change-only. **Viewer key defaults do not live on the canvas** — `strip_bindings`
  sweeps every widget-level sequence — but on the shared **`WaveViewer` bindtag**
  (`install_default_binds`, one-shot; inserted at bindtags index 1 so `key_filter`,
  which never `break`s, keeps first refusal). That tag is the ONLY rc-reachable
  viewer binding table: `bind WaveViewer <seq> {wviewer::clear_all_at %W; break}`,
  disabled with `{break}` (an empty script deletes the binding and gets
  re-defaulted). `clear_all_at` resolves the token from `%W`, never the current
  ctx. Any new viewer key belongs here, not in `key_filter`'s hardcoded arms.

---

## 9. Subcommand surface (Tcl → C)

- `xschem raw <sub> ...` / `xschem raw_query ...` (`scheduler.c` ~8521):
  `value`/`values`/`set`/`index`/`del`/`rename`/`pos_at`/`add`/`datasets`/
  `points`/`rawfile`/`sim_type`/`vars`/`list`/`loaded`/`new`/`clear`/`switch`.
- `xschem raw_read <file> [sim] [sweep1 sweep2]` (~8755) /
  `xschem raw_clear` (~8740) / `xschem raw_read_from_attr` (~8794).
  **`raw read $file $sim_type`: omit `sim_type` entirely when empty** (absent
  arg ≠ empty arg in the C handler).
- `xschem graph_coord <graph_idx> <screen_x> <screen_y>` (`xschem_cmds_g`) — data-space
  `{dx dy}` under a canvas pixel for a graph rect: pixel -> `X_TO_XSCHEM` -> `G_X`/`G_Y`,
  so callers get the plot-box (14% margin) transform without mirroring it in Tcl. Uses a
  LOCAL `Graph_ctx` (landmine 11); `{}` on a bad index / non-graph rect. Added for the
  viewer's pointer-anchored zoom (issue 0146); partially covers backlog #7.
- `xschem get graph_flags` (`xschem_cmds_g`) — the per-session graph interaction
  flag word (`xctx->graph_flags`; bits 16/32 = x-cursor A/B GRABBED, 512/1024 =
  y-cursor grabbed — authoritative legend in `callback.c`). **Not** `xRect.flags`
  (landmine 6). Added 2026-07-27 for the viewer's drag-reorder press seam.
- `xschem get graph_near_wave <graph_idx> <px> <py> [tol]` (`xschem_cmds_g`) —
  1/0: is that CANVAS PIXEL within `tol` (default 10) **screen pixels** of a drawn
  trace of that graph? Backed by `graph_near_wave()` (`draw.c`), which uses the
  engine's own transform + raw data. The ASE viewer's trace-exclusion zone. See
  landmine 33 for how it differs from `find_closest_wave` and what it refuses.
- `xschem get graph_trace_at <graph_idx> <px> <py> [tol]` (`xschem_cmds_g`) — the
  same query with the IDENTITY kept: the **node index** (position in the `node`
  token, the `hilight_wave` / `find_closest_wave` index space) of the nearest
  trace within `tol`, else -1. Backed by `graph_wave_at()` (`draw.c`);
  `graph_near_wave()` is now a one-line wrapper over it, so "the zone reordering
  refuses" and "the trace you picked up" are the same boundary by construction.
  Added 2026-07-28 for the viewer's drag-a-trace-to-another-strip gesture.
  Since the marker work, **both** are thin wrappers over `graph_point_at()`,
  which keeps the whole sample identity (node, real dataset, absolute point,
  raw x/y) — one scan, three answers. Its x/y are RAW, never log-space:
  landmine 35.
- **Axis-region drag zoom** (`doc/claude/specs/waveform_viewer_modes.md` §17,
  issue 0190, 2026-08-01). Three getters in `xschem_cmds_g`'s `get` `case 'g':`,
  all **fail SOFT** (a sentinel + `TCL_OK`, never an error — the ASE viewer wraps
  them in `catch` and must read a missing verb as "nothing there", never as
  "locked out"), and one top-level verb that **fails LOUD** on a usage error.
  One vocabulary throughout: `""` | `x` | `y`.
  - `xschem get graph_axis_at <gi> <px> <py>` — which axis-number MARGIN that
    canvas pixel is in. Backed by `graph_axis_at()` (`draw.c`). Refuses the plot
    box, everything outside the container, the reorder-grip column at every
    height, and any pixel `graph_legend_at` claims. **Deliberately does NOT
    require a loaded raw and does NOT refuse digital strips**, unlike
    `graph_plotbox_at` — it is pure geometry, and an empty or digital strip still
    has axes. The bottom-LEFT corner answers `y`.
  - `xschem get graph_axis_map <gi> x|y <p0> <p1>` — `{lo hi}` for a drag from
    canvas pixel `p0` to `p1` along that axis, `{}` for a travel of <= 3 screen
    px / a bad index / no transform. **The FORMULA seam**: the release arm in
    `callback.c` and the verb below both call the same `graph_axis_map()`, so a
    headless suite driving this verb drives the gesture's own arithmetic —
    including BOTH endpoints, which is what a width-only zoom-out gets wrong.
  - `xschem get graph_axis_wheel_map <gi> x|y <p> in|out` — the same shape for
    the CTRL+WHEEL (issue 0191, §18): `{lo hi}` for ONE click at canvas pixel
    `p`, `{}` for an unknown axis word, an unknown direction word, a bad index,
    a non-graph rect or no transform. Backed by `graph_axis_wheel_map()`
    (`draw.c`), which both the `callback.c` arm and this getter call — so a
    headless suite driving the verb drives the gesture's own arithmetic,
    including the ANCHOR (`lo = q - u*R2`), which is the only thing a
    "the range shrank" assertion cannot see. ⚠ The **direction word** is the
    input, never a factor: `GRAPH_AXIS_WHEEL_FACTOR` lives inside the formula so
    it has one home, and the suite reads the `#define` out of `src/xschem.h`
    rather than freezing a copy. The axis WINDOW itself comes from
    `graph_axis_window()`, shared with `graph_axis_map()` — landmine 47(d).
  - `xschem get graph_axis_drag` — what the last press ARMED. The
    `graph_marker_drag` twin; `wviewer::axis_grabbed` is the only thing the ASE
    viewer knows about the axis regions (it hit-tests nothing).
  - `xschem graph_axis_zoom <gi> x|y <lo> <hi>` — **THE apply**, and the replay
    form of the gesture. X writes `x1`/`x2` on that rect and on every
    PARTICIPATING rect (the shipped MMB-pan predicate); Y writes `y1`/`y2` — or
    `ypos1`/`ypos2` on a digital strip — on that rect only. `1`/`0`; usage error
    ⇒ `TCL_ERROR`. **NOT `scheduler_readonly_reject()`ed**, unlike
    `graph_marker`: a range write is view state the engine has always been
    allowed to put in a read-only rect (landmine 17 names the box zoom), the ASE
    viewer is read-only for life, and rejecting would abort every replay of the
    line this verb logs. No `set_modify`, no `push_undo` (landmine 19); exactly
    one `log_action` line, `%.17g`, never pixels.
- **Waveform markers** (`doc/claude/specs/graph_markers.md`, 2026-07-28). Four
  read-only getters in `xschem_cmds_g`, all **fail SOFT** (a sentinel +
  `TCL_OK` on a short or bad query, never an error — the ASE viewer wraps them
  in `catch` + `string is integer -strict` and must read a missing verb as
  "nothing there", never as "locked out"):
  - `xschem get graph_marker_at <graph_idx> <px> <py> [tol]` — which marker is
    under that CANVAS PIXEL and **which part**: `""` | `"<num> anchor"` |
    `"<num> label"`. The part matters because the two drive DIFFERENT drags
    (anchor slides along its trace, label just moves). Default `tol` =
    `GRAPH_MARKER_TOL` (8 screen px). Returns `""` under `--nogui` (no cairo
    context, hence no measurable label box). Being a query it saves and restores
    `graph_flags` bits 128\|256 around its `setup_graph_data` call — landmine 37,
    which by now has **four** such bracket sites, not one.
  - `xschem get graph_marker_drag` — `0` none | `1` anchor drag armed | `2`
    label drag armed. The `graph_flags`/`cursor_grabbed` twin: the viewer's
    press seam consults it to decide that C owns the whole gesture.
  - `xschem get graph_marker_sel` — the selected marker NUMBER, `-1` = none.
    The number is the whole identity: `xctx->graph_marker_selgraph` exists only
    as a repaint hint, because a rect index goes stale on a strip reorder or a
    multi-plot prepend, and the `Delete` gate re-resolves the owning strip with
    `graph_marker_find()`. Since issue 0189 it is the **HEAD** of a selection
    SET and keeps its exact old meaning and shape.
  - `xschem get graph_marker_sel_set` — the WHOLE selection as marker numbers,
    **head first**, space separated (`"2 1"`); `""` for none (issue 0189). The
    set is `xctx->graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]` +
    `graph_marker_n_sel`, held in `xctx` and **never** in a prop token — see
    landmine 46(b) for why this is NOT the 0175 trace model.
  - `xschem get graph_rects` — how many layer-2 rects are GRAPHS. **Not**
    `xschem get rects 2`, which is every rect on the layer: the marker push
    hook uses this for its model↔rect 1:1 guard, and a single stray non-graph
    `GRIDLAYER` rect would permanently disable it.
  - `xschem get graph_preview` — `<gi> <ni> <scale>` while the mid-drag shrink
    preview is armed, else the single word `0`. Since issue 0192 this is the
    **HEAD** of a SET and its output shape is deliberately **byte-identical** to
    the single-trace era (the `graph_marker_sel` compatibility rule).
  - `xschem get graph_preview_set` — the WHOLE previewed set as
    `"<gi> <ni> <gi> <ni> …"`, **head first**; `""` when nothing is armed
    (issue 0192). Backed by `xctx->graph_preview_set_gi/_set_wave
    [GRAPH_MAX_PREVIEW_WAVES]` + `graph_preview_n`, fixed arrays, never a prop
    token — transient chrome, landmine 49.
  - `xschem set graph_preview <gi> <ni> <scale> [<gi> <ni> …]` — arm; the
    three-argument form is the single-trace arm and is unchanged, TRAILING PAIRS
    are issue 0192's multi-trace arm. `xschem set graph_preview 0` disarms head,
    set and count together. An over-long set truncates at the cap (the preview is
    chrome; the MOVE is uncapped) and a trailing odd argument is ignored.
- `xschem graph_marker <sub> ...` (`xschem_cmds_g`, top level) — the marker
  mutations, which **fail LOUD** (unknown sub-verb → usage string +
  `TCL_ERROR`). Every sub-verb except `select`/`list`/`text` is
  **readonly-rejected** by `scheduler_readonly_reject()` before the primitive
  runs. That is a **separate gate** from the one the keys and the mouse hit
  (`graph_marker_ro_refuse()` in `draw.c`, a non-modal `ciw_echo`) — deliberately
  so: a script wants a catchable error, a gesture must not raise a modal. The
  ASE viewer defeats both deliberately through `wviewer::with_edit`, the
  established pattern.

  | sub-verb | args | result |
  |---|---|---|
  | `add` | `<gi> <px> <py> [-delta]` | new marker number, or `{}` |
  | `add_at` | `<gi> <wave> <dset> <point> [-delta]` | new number, or `{}` — the **data-addressed** creator, headless-testable and the form `log_action` writes |
  | `anchor` | `<num> <dset> <point>` | `1`/`0` |
  | `move` | `<num> <px> <py>` | `1`/`0` — pixel re-snap along the marker's own trace + dataset |
  | `label` | `<num> <ldx> <ldy>` | `1`/`0` — label offset only |
  | `delete` | `<num>` \| `-all [<gi>]` \| `-selected` | `1`/`0` \| count \| count (`-selected`, issue 0189, removes the whole selection under **ONE** undo point); both forms clear `prev == <removed>` window-wide via **one** `graph_marker_clear_prev_n()` pass over the whole doomed set, including a **partial** `-all <gi>`, which otherwise left deltas dangling on the strips it did not touch |
  | `select` | `<num> [<gi>]` \| `-none` \| `-pair <num> [<gi>]` \| `-set <n1> ...` | **always the new HEAD**, for every form (`-none` still answers `-1`) — pure UI state: no token write, no undo, no modify, no log line. `-pair` is the double-click policy (add the `prev` partner iff it resolves; immediate pair only, never the chain, never the reverse); `-set` is permissive, dedupes and keeps the order given |
  | `list` | `[<gi>]` | list of 10-element sublists `{num graph wave dset point x y prev ldx ldy}`, `x`/`y` at `%.17g` — **the exactness seam** |
  | `text` | `<num>` | the rendered callout string, embedded `\n` |

  Persistence needs no verb: `getprop`/`setprop rect 2 <gi> markers` already
  round-trips the multi-line value byte-for-byte.
- `xschem hilight_netname [-fast] [-style <n> | -layer <n>] <net>` and
  `xschem hilight_instname [-fast] [-layer <n>] <inst>` (`xschem_cmds_h`) —
  `-layer` highlights in the PLAIN color of a drawing layer (the negative-value
  path, landmine 21) without touching the style cursor. Added for the ASE Direct
  Plot picker, which paints each clicked wire in the color its trace will use
  (issue 0153). **Feed these the RAW schematic token** (`#net1`, original case);
  the stripped/lowercased form silently matches nothing — landmine 23.
- `xschem nets [-selected]` / `xschem net <sel>` / `xschem net_members <sel>`
  (`xschem_cmds_n`) — net descriptors `{name {<tok>} nwires N npins M anchor {..}}`.
  `-selected` restricts to the current selection and **rebuilds it first, so a
  COLD call is correct**; these verbs reset the interp result AFTER
  `prepare_netlist_structs`. `resolved_net` / `list_hilights` / `instance_nodemap`
  did not, and were corrupted on a cold GUI call until issue 0155 moved the reset
  into prep itself (landmine 24).
  `sod_net_at` uses `nets -selected` as its auto-named-net fallback (issue 0154).
- `xschem add_graph` (~1887, sets `graph_lastsel`), `xschem draw_graph <i>`
  (~2913), `xschem get graph_lastsel` (~3772), `xschem cursor <which> <on>`
  (~2689), `xschem annotate_op`, `xschem embed_rawfile`.
- **`xschem draw_graph <i>` used to be a two-way SIGSEGV** (pre-existing, found
  while testing markers, fixed 2026-07-28). Under `--nogui` there is no window,
  no pixmap and no GCs, and this verb goes straight to Xlib; and both
  `setup_graph_data()` and `draw_graph()` dereference `rect[GRIDLAYER][i]`
  **unchecked**, so any out-of-range or negative index crashed too. The branch
  now requires `has_x` **and** `0 <= i < xctx->rects[GRIDLAYER]`, and is a silent
  no-op otherwise (`Tcl_ResetResult`, never an error) — a headless test may call
  it freely. If you add another verb that reaches a `draw_*` function, copy this
  guard: `has_x` is the only thing separating the drawing engine from a crash in
  the `--nogui` arm the whole headless suite runs in.
- `xschem setprop rect 2 <i> <tok> <val>` — generic graph-token mutate;
  fullxzoom/fullyzoom special-cased at ~10822/10830 (**hardcoded `c==2`** —
  graphs on any other layer get no special handling). The dirty flag comes from
  this branch's own `if(change_done) set_modify(1)` (~10880), **not** from the
  zoom helpers — landmine 19.
- New verb? Put it in the matching first-letter dispatch fn or it's silently
  unreachable (see memory `scheduler-letter-dispatch`).

---

## 10. Extension recipes ("to add X, touch Y")

- **New graph attribute:** add `get_tok_value` read in `setup_graph_data`
  (parse-time) or `draw_graph` (per-draw); add a `Graph_ctx` field; expose in
  `graph_edit_properties` (`xschem.tcl` ~4736) and/or the viewer. **No `save.c`
  change** — tokens auto-persist.
- **New flag bit:** extend `set_rect_flags` (`actions.c` ~860) + its bit-table
  comment; mirror the Tcl `set_rect_flags` (`xschem.tcl` ~4713).
- **New trace render style:** branch in `draw_graph_points` mode dispatch
  (~3373) + a `gr->mode` value parsed in `setup_graph_data`.
- **New per-node syntax:** extend the parse block in `draw_graph` ~4660-4761;
  expressions route through `plot_raw_custom_data` (`save.c` ~1821).
- **New file format:** produce a `Raw` (populate names/values/npoints/
  datasets/allpoints/table) and register via `extra_rawfile`; `table_read` is
  the worked example.
- **New graph gesture/key:** branch in `waves_callback` **and** an
  ACTX_OVER_GRAPH row in `init_input_bindings`. Respect the participation test.
- **New graph GESTURE IN A MARGIN (not in the plot box):** split it into
  **query / formula / apply**, three functions, and let the Tcl surface reach all
  three. Worked example, issue 0190: `graph_axis_at()` (which region is this
  pixel in — pure geometry, local `Graph_ctx`, the `128|256` bracket, fails
  closed), `graph_axis_map()` (THE arithmetic, in exactly one place, exposed as
  `xschem get graph_axis_map` **so a headless suite can assert both endpoints of
  the transform instead of only its visible consequence**) and
  `graph_axis_zoom()` (THE mutation, shared by the release arm and by a
  replayable verb). The split is what stops the gesture and the replay verb from
  each growing their own copy of the formula — landmine 45(a) in a second shape,
  and the reason the suite carries a source-level leg counting the expression.
  Then read landmine 47 before choosing which pixels the region owns: the
  margins are already occupied.
  **The WHEEL variant** (issue 0191, §18) reuses the SAME query and the SAME
  apply and adds only a second formula (`graph_axis_wheel_map()` +
  `xschem get graph_axis_wheel_map`). Four things it teaches:
  (1) the arm goes in `waves_callback`, **never** in the binding table — landmine
  48; (2) the new arm must explicitly stand the OLDER wheel arms down
  (`wheel_axis_done`), because they live in a different if/else chain in a
  different loop, and it must do so **only when the gesture actually fired** or
  the "unchanged elsewhere" contract breaks; (3) take the direction as a WORD and
  keep the step constant inside the formula, so the suite drives the product's
  own step; (4) if two formulas now ask the same sub-question (here: *what is
  this axis's window?*), factor it — landmine 47(d), where doing so exposed a
  shipped digital-strip defect.
- **New CURSOR (a session-wide, non-persisted overlay):** a `graph_flags` bit
  (keep both legends in sync — landmine 6), a draw path, and grab/move/set
  branches in `waves_callback`. This recipe is **only** right for transient
  session state. It is the WRONG answer for anything durable: `graph_flags` is
  per-session, is not saved, cannot carry an identity, and its legend is already
  a maintenance liability.
- **New durable per-graph ANNOTATION (a marker, a note, a region):** it is
  CONTENT, so it follows the "New graph attribute" recipe, not the cursor one —
  a `token=value` on the graph rect (so it persists, pastes, undoes and exports
  for free), parsed **in the renderer** rather than in `setup_graph_data` (no
  `Graph_ctx` field, therefore no stale-value-leaks-onto-the-next-graph hazard,
  landmine 11), drawn under **flags bit 8 (content), never bit 16 (UI chrome)** —
  bit 16 is stripped from every export path, and a printed schematic must carry
  the user's annotations. Transient interaction state (what is selected, what is
  being dragged) goes in dedicated `xctx` fields exposed through a dedicated
  `xschem get` scalar, **not** in a new `graph_flags` bit. If the ASE viewer must
  see it, add a C→Tcl **push** hook: `wviewer::regenerate` re-places every rect
  from the Tcl model and a plain window resize calls it, so a pull-only mirror
  loses the annotation on resize (§8 of the spec). Worked example, with the
  Button1 precedence table, the token grammar and the node-index remap rules:
  `doc/claude/specs/graph_markers.md`; see also landmines 35-40.
  Four more obligations the marker work only discovered on a second pass, all of
  them cheap up front and expensive later: **renumber in BOTH duplication doors**
  (landmine 39); **reset the transient state in `clear_drawing()`**, because the
  same `xctx` is reused by `xschem clear`, File>Open in the tab, `xschem load`
  and the disk-undo reload, so a surviving id latches onto whatever object in the
  NEW document carries it; **refuse it in a read-only buffer, but gate the
  MUTATING PRIMITIVE, not the key arm** (content that lands in a read-only
  buffer carries no undo point — `push_undo` is skipped — and `xschem undo` is
  itself readonly-rejected, so it is untakeable-back; the key arm is the wrong
  place because it misses every mouse commit path, and `readonly_block()` is the
  wrong refusal because its modal deadlocks any script driving that path — use
  the feature's own non-blocking `ciw_echo`); and
  **parse the window ONCE per operation** if records can reference each other,
  or the redraw, the hit-test *and* the delete sweep all go O(N²).
- **New Tcl query on data:** branch under the `raw`/`raw_query` dispatch.
- **New per-graph UI decoration (on-screen only):** a prop token written by
  `wviewer::graph_props`, a `Graph_ctx` field parsed in `setup_graph_data`
  (before the `RECT_OUTSIDE` return), a draw block in `draw_graph` gated on a
  flags bit the on-screen callers set, and a dedicated GC created in
  `create_gc` / freed in `free_gc` / coloured in `build_colors` from a Tcl
  colour var (`gc_hover` is the worked example; issue 0151 is the second).
- **New viewer op:** a pure model transform on `layouts` + `regenerate`
  (`wave_viewer.tcl`); persist via the `viewer` state dict snapshot/restore. If
  it is an EDIT, call `wviewer::capture_live_graph_state` then
  `wviewer::push_undo` before mutating — that is all `u`/`U` need (§14 of the
  modes spec).
- **New viewer KEY (issue 0171):** a `<seq>` row in
  `wviewer::install_default_binds` (the `WaveViewer` bindtag), guarded by
  `[bind WaveViewer <seq>] eq {}` so an rc keeps winning, plus a `%W`-resolving
  wrapper like `clear_all_at`. NOT a `key_filter` arm (those are the C-forward
  and intercept cases) and NOT a `bind $wp` — `strip_bindings` sweeps that.

---

## 11. Landmines (verify against these before editing)

1. **`values` has `nvars+1` columns** — the last is scratch. Any column loop
   *and every (re)allocation* must respect the +1 (`free_rawfile` loops
   `<= nvars`). The worked failure is `raw_deletevar` (`save.c` ~1126, §12
   backlog item 3, fixed 2026-07-28): `sizeof(SPICE_DATA *) * raw->nvars + 1`
   parses as `(sizeof * nvars) + 1`, dropped the scratch slot, and the next
   `raw add` wrote past the allocation — heap corruption, not a warning.
2. **AC packs 4 columns/var** at `(i<<2)+k` (mag/ph/re/im), `nvars` is 4×.
   Never assume `names[i]` maps 1:1 to source variables for AC.
3. **`cy` is negative**; grid code swaps `gy1`/`gy2` in places. Sign mistakes
   invert waveforms.
4. **Coordinate macros need `Graph_ctx *gr` in scope** and
   `setup_graph_data()` run for the *right* graph. Stale `gr` → silent
   mis-transform.
5. **`graph_master` (mouse, transient) ≠ `graph_lastsel` (clicked, persists).**
   Trace-adds target `graph_lastsel`. `graph_master` can be −1/stale after a
   canvas rebuild — `graph_fullxzoom` guards it (past SIGSEGV class).
6. **`graph_flags` (session cursor modes) ≠ `xRect.flags` (graph type/lock).**
   `graph_flags&2`=draw cursor A; `r->flags&2`=unlocked x-axis. Unrelated.
7. **`private_cursor` (`r->flags&4`)** duplicates every cursor read/write as
   `if(flags&4){token}else{global}` (~10 pairs in `waves_callback`). Miss one
   → per-graph cursors desync.
8. **`waves_selected` is side-effectful** and its ordering vs the
   `semaphore>=2` gate is load-bearing (warnings at `callback.c` ~4878/6985).
   Button2 + Shift+Button1 skips are deliberate — don't "simplify" them.
9. **`sch_waves_loaded()` ties data to `raw->schname`/`level`.** Descend/
   ascend or open another schematic → the SAME data silently becomes invisible
   (returns −1) **without being freed** — easy to misdiagnose as data loss.
   Set `raw_level` manually when a top-level raw should annotate a
   sub-schematic (`xschem.tcl` ~5604-5610).
10. **`raw_read` refuses to overwrite** a loaded `Raw` — `extra_rawfile(3)` /
    `raw_clear` first. A `raw clear` also kills every `raw add` vector, so
    re-materialize RPN traces after clearing.
11. **`draw_graph` re-entrancy:** called by `draw()`, by SVG/PS export, and by
    `raw_read`'s cursor-B backannotation — all writing the shared
    `xctx->graph_struct`. `raw_read` uses a local `gr_ctx` to avoid clobbering.
    New callers must not overwrite `graph_struct` during an active draw.
12. **OP multi-dataset reshape:** `draw_graph` (~4700-4707) mutates
    `xctx->raw` in place (1-point datasets → one `allpoints` dataset) and
    restores it — don't return early past the restore.
13. **`extra_raw_arr[0]` lazy migration:** `extra_raw_n` can be 0 while
    `xctx->raw` is set. Mixing `raw_read` (writes `xctx->raw` directly) with
    `extra_rawfile` can desync `extra_idx`.
14. **Two independent parsers** (`rawtovcd.c` vs `save.c read_dataset`) and
    **two op engines** (C vs Tcl) — a parsing/annotation fix often needs
    applying in both.
15. **Binary blocks = native-endian raw doubles**, no byte-swap/validation
    beyond an `fread`-count warning; skip-non-matching relies on exact
    `nvars*npoints*8` sizing.
16. **`MAX_POLY_POINTS` chunk overlap** repeats the last point as the next
    chunk's first (`offset += MAX_POLY_POINTS-1`); off-by-one → visible gaps.
17. **ASE viewer discipline:** all mutation via `with_edit`; `switch_ctx` must
    verify (silent no-op under a raised semaphore); rebuild `graphbb` every
    `regenerate`; canvas binds appended with `+`, never replaced; wheel bound
    as Button-4/5 with `break`. Getting these wrong writes stray `untitled~.sch`
    or leaks C canvas-box zoom through the viewer.
    **"All mutation" includes mutation the C engine performs on the viewer's
    behalf.** Two seams forward raw C events inside `with_edit`, and both exist
    only because the thing on the other side writes durable content:
    `key_filter` for `m`/`d` (KeyPress only), and
    `strip_drag_release` for `<ButtonRelease-1>` **when
    `xschem get graph_marker_drag` > 0** — that is the release a marker drag
    commits on. The release bracket is conditional on purpose: `with_edit` is a
    context switch plus four state writes, too heavy for every mouse release,
    and every *other* thing that release does (cursor drop, wave-bold, box-zoom,
    end-of-pan) writes view state the engine has always been allowed to put in a
    read-only rect (landmine 19). Any new C gesture that writes a durable token
    needs its own such bracket — and `with_edit` **errors** on a refused context
    switch, so inside a Tk binding it must be `catch`ed.
    ⚠ **`Delete` (65535) was the third bracketed key and is one no longer**
    (issue 0176). It is not forwarded to C from the viewer *at all*: it deletes
    the SELECTION — the selected marker, the selected traces, or both — through
    `wviewer::delete_selection_at` → `delete_items`, which is a pure Tcl model
    edit and therefore needs no bracket, exactly like `move_strip` and
    `delete_empty_strips`. Two things came with that and are worth carrying
    forward when the next key is tempted to forward:
      * **A trace delete has THREE index consequences**, and missing any one of
        them is a silent data bug. The marker ON a doomed trace is DROPPED;
        every marker and every SELECTED node in the same graph above the hole
        shifts DOWN by the doomed count below it; and the dropped marker
        NUMBERS must be swept **window-wide**, because a delta block's `prev`
        partner may live in a strip the deletion never touched and a dangling
        `prev` degrades the block to a plain callout with no indication at all.
        `delete_in_graphs` + `markers_sweep_numbers` are the two halves.
      * **Deleting a marker through the C verb is the wrong reflex in Tcl.**
        `xschem graph_marker delete N` is readonly-rejected at the scheduler, it
        self-logs a line that is readonly-rejected AGAIN on replay and aborts the
        `source`, it pushes a C undo point onto a read-only scratch buffer, and
        it reaches the Tcl model only through the `has_x`-gated notify hook
        (landmine 41) — so headless the rect loses the marker, the model does
        not, and the next `regenerate` puts it straight back. Every Tcl deletion
        path rewrites the token instead, via `markers_drop_number`.
18. **`Graph_ctx.active` + `draw_graph` flags bit 16** (issue 0151). The
    viewer's target-strip marker is a prop token `active=1` parsed in
    `setup_graph_data` — parsed **before** the `RECT_OUTSIDE` early return,
    because `gr` is the shared `xctx->graph_struct` and a stale value would
    leak onto the next graph. It is painted only when `flags & 16` is set,
    which the **on-screen** callers do (`draw_graph_all`, `callback.c` ×3, the
    `xschem draw_graph` verb) and the **export** callers deliberately do not
    (`svg_embedded_graph`, `psprint.c` ×2). A new on-screen `draw_graph` caller
    must set bit 16 or the marker will blink out on that redraw path.
19. **A graph GESTURE does NOT mark the file dirty, and does NOT push undo.**
    (This landmine used to say the opposite; corrected 2026-07-28 by
    measurement.) `graph_fullxzoom` (`draw.c` ~2895) and `graph_fullyzoom`
    (~3004) contain **no `set_modify` at all**, and the whole of
    `waves_callback` (`callback.c` ~706-1868) contains **zero `set_modify(1)`
    and zero `push_undo()`** — its only `set_modify` calls are the five
    `set_modify(-2)` floater-cache refreshes. So every pan, box-zoom, cursor
    move, wave-bold and `f`-fit rewrites `prop_ptr` tokens **silently**: no
    dirty flag, no undo point, no save prompt.
    The real dirty mechanism on this path is **`setprop`'s own
    `if(change_done) set_modify(1)`** (`scheduler.c` ~10880), which fires
    regardless of `-fast` — and note the `fullxzoom`/`fullyzoom` branches never
    set `change_done`, so even `xschem setprop rect 2 n fullxzoom` leaves the
    file clean. `create_graph.tcl`'s `xschem set_modify 0` is still needed, but
    because `xschem rect` calls `set_modify(1)` unconditionally
    (`scheduler.c` ~9251), not because of `fullxzoom`.
    **Consequence for anything NEW that writes durable graph content:** copying
    "whatever the existing graph writes do" means the content is **lost on close
    with no prompt and no undo**. Waveform markers therefore do the opposite on
    purpose — `xctx->push_undo()` (skipped when `xctx->readonly`) *before* the
    prop write and `set_modify(1)` after, on create / delete / drag-**commit**
    only; mid-drag motion does neither, because the drag lives in
    `xctx->graph_marker_scratch` and never touches the token.
    (`set_modify`'s `ro_suppress`, `actions.c` ~189, means this still cannot
    dirty a read-only buffer or trigger an autosave, which is what lets the
    read-only ASE viewer carry markers.)
20. **A graph gesture must not be triggered on a PRESS that a drag also starts**
    (issue 0152). The wave-bold toggle used to fire on Button3 *press*, so every
    RMB press-drag box-zoom (0142) bolded a trace. It is now the **release of a
    Button1 press that did not travel** more than `GRAPH_CLICK_TOL` (3) pixels.
    The press anchor is `xctx->graph_press_x/y`, **never**
    `mx/my_double_save`: the Button1 drag-pan **re-seeds** those on every motion
    step (`save_mouse_at_end`, end of `waves_callback`), so at the end of a long
    pan they equal the release point and a click test against them fires. That
    anchor also carries the DOUBLE-click interlock: the `-3` arm poisons it with
    `-1e30` so the trailing release cannot pass the travel test and bold
    underneath the wave dialog — a replacement gate on different fields silently
    loses that. RMB inside the plot body is box-zoom only; RMB on a **legend**
    entry is a separate, per-trace bold (`edit_wave_attributes(2,...)`) and is
    unchanged.
    ⚠ **Two clauses of this entry were CORRECTED by issue 0174 (2026-07-29).**
    It used to add that `find_closest_wave()` has no distance threshold, so
    "near a trace" was really "anywhere in the plot body", and that the toggle
    tests the *currently* bold wave rather than the one just found. Both were
    true, both were the next bug report, and both are now fixed: the arm picks
    with `graph_wave_at()` at `GRAPH_TRACE_PICK_TOL` (10 screen px, landmine 33)
    off the EVENT's canvas pixels, and the selection simply BECOMES what the
    click picked (`wcnt`, already -1 on a miss). One assignment: a click on
    another trace moves the selection, a click on empty body clears it, and a
    click on the already-selected trace KEEPS it — a plain click never deselects
    what it lands on (that is 0175's Ctrl+click, which is also the only way to
    add to a selection).
    ⚠ **`hilight_wave` is a PER-RECT token, so this arm also sweeps every OTHER
    graph rect and clears it.** Without that, selecting on strip A and clicking
    on strip B leaves both bold — the same defect one level up, and it is
    invisible to any leg that witnesses a single rect. An ABSENT token means
    nothing is bold there; `atoi("")` would read it as node 0 and clear a strip
    that was never selected. The cleared strips are repainted by the all-graphs
    loop via `need_all_redraw`, NOT inline — an inline repaint would need
    `setup_graph_data` on a non-master rect with the shared `xctx->graph_struct`
    the arm is still holding (landmines 11 and 37). Two tolerances now sit
    in this one arm and they answer different questions — `GRAPH_CLICK_TOL`
    (3 px × `xctx->zoom`, WORLD units) is click-vs-drag travel;
    `GRAPH_TRACE_PICK_TOL` (10 SCREEN px, never zoom-scaled) is
    distance-to-trace. Do not merge them.
    ⚠ `GRAPH_CLICK_TOL` itself is used in TWO spaces. The arms whose
    operands are world coordinates write `* xctx->zoom` (this one, and the
    marker click at `callback.c:710`/`:711`); the axis-region drag zoom (0190)
    passes it BARE to `graph_axis_map()`, whose `p0`/`p1` are canvas
    PIXELS. Same 3 screen px either way — different operand space. The
    `#define` stays file-private to `callback.c` (in the header it would
    read as `GRAPH_TRACE_PICK_TOL`'s twin), and the one out-of-file caller,
    the `xschem get graph_axis_map` getter, takes the value from the
    `graph_click_tol()` accessor — never a second literal, or the seam the
    axis-zoom suite drives could disagree with the gesture silently.
21. **Highlight values >= 0 are STYLE indices, not layers** (issue 0153).
    `get_hilight_style` indexes the net-hilight style table, whose default rows
    map style *i* to `active_layer[i]` = layers **>= 7 only**. A **negative**
    value means "plain color of layer `-value`, no style"
    (`get_color`/`hilight_pixel_of`) — the only way to reproduce an arbitrary
    layer color, and what `hilight_netname/-instname -layer <n>` and
    `hilight_graph_node()` use. Viewer palette entries 4 and 5 have no style row
    at all, so `-style` cannot express them.
22. **Trace-color `used` sets are mode-dependent** (issue 0153). Per-graph
    `next_color` is correct for single-plot only; multi-plot lands each signal in
    a fresh EMPTY strip, so a per-graph rule gives every trace palette head 4.
    Batch colors come from the PURE `wviewer::plan_colors` (window-wide `used`
    for multi, per-strip for single), and it is prefix-stable so the Direct Plot
    picker can resolve click *k*'s color before click *k+1* exists.
23. **A schematic net token and its simulator vector name are DIFFERENT
    strings, and the ASE picker carries both** (issue 0154). An unlabeled net is
    `#netN` in `wire[].node` but `netN` in the netlist (`V1 net1 GND`).
    `ase::ui::dp_hilight` needs the **raw** form — `xschem hilight_netname`
    finds `#net1` and returns 0 for `net1` — while `ase::ui::sod_expr` needs the
    **stripped, lowercased** form, because `get_raw_index` never strips `#` and a
    `.save v(#net1)` card makes ngspice **abort the whole analysis** (not just
    skip the vector). `dp_queue(ex, kind, token)` already keeps them in separate
    parameters; both `dp_hilight` call sites are `catch`-guarded, so conflating
    them kills the color cue silently. Do the mapping in `sod_expr` and nowhere
    else. Related: `xschem flylines at` is the picker's primary net resolver but
    **excludes `#` nets by design** (fly-lines rule A6, `flyline.c` — do not
    relax it); `ase::ui::sod_net_at` adds a `nets -selected` fallback gated to
    WIRE hits. Do **not** reach for `xschem resolved_net` here even now that its
    contamination is fixed (issue 0155, landmine 24): `sod_expr` must stay a pure
    string op, because `test_ase_interact` H1 calls it with **no design loaded**.

24. **`prepare_netlist_structs()` used to leave `"0"` in the interp result**
    (issue 0155, FIXED — `Tcl_ResetResult` at the tail of the function,
    `netlist.c`). The `"0"` was the value of the `catch {...}` in `set_modify(-2)`'s
    menu recolor (`actions.c`), so every verb that called prep and then *appended*
    its answer emitted a stray leading `0` — `resolved_net OUT` → `0OUT`,
    `list_hilights` → `0OUT`, `instance_nodemap V1` → `0V1 p …`. **Two masks kept
    it hidden and both still matter when testing anything on this path:** the
    dirtying eval is `has_x`-gated, so the **`--nogui` arm cannot reproduce it**;
    and prep early-returns when already prepped, so only the **first (cold)** call
    after a load or invalidation was wrong. `prep(0)` does not warm a `prep(1)`
    consumer — `xschem nets` then `xschem list_hilights` was still contaminated.
    The same class can still exist in any *other* function that runs a `catch`
    eval and whose caller appends; only prep's callers were swept.

25. **`resolved_net()` builds a bus answer by APPENDING, and a global element is
    the one that must append *without* the path prefix** (issue 0157, FIXED —
    `hilight.c` ~2653). The per-element loop accumulates into `rnet` with
    `my_mstrcat` + a `,` between elements; the global branch used `my_strdup2`,
    which **replaces**, so any global at `k>0` discarded every element resolved
    before it *and* the comma already written for it (`{A,B,GND,VCC}` → `VCC`).
    Two invariants now hold and both are load-bearing, in opposite directions:
    the answer has exactly `mult` `,`-separated items (every consumer —
    `send_net_to_graph` `hilight.c:1595`, `translate()`'s `@#<pin>:resolved_net`
    `token.c:4253` — iterates them with `count_items`/`find_nth`), **and** a
    global is emitted flat, with no `X1.` prefix, because `record_global_node` is
    precisely the "this name has no hierarchy" predicate. Do not "simplify" the
    two branches into one. The whole-net early return at `hilight.c:2586` is a
    different case: `rnet` is `NULL` there, so a replace is correct.
    `@spice_get_voltage` (`token.c:4224`, `:4718`) is scalar-only (`multip == 1`)
    and never saw this.

26. **`#` is an ordinary label character to the parser, so it must be stripped PER
    BUS ELEMENT, and the strip must stay LOOSE** (issue 0158, FIXED —
    `hilight.c` ~2613). `#` sits in `parselabel.l`'s `LAB`/`LAB_NODASH`/`LAB_NUM`/
    `IDX_LAB_NUM_SP`/`LAB_NUM_SP` classes (~162-173), so `expandlabel` passes it
    through and *distributes* it over bracket bits (`#a[1:0]` → `#a[1],#a[0]`).
    `resolved_net` used to strip once on the whole token before `expandlabel`, so
    only element 0 was cleaned; descended, the survivor landed mid-name
    (`{LOC,#x}` → `X1.LOC,X1.#x`). Three rules now hold: **(a)** strip inside the
    loop, once per element; **(b)** keep it LOOSE — do *not* reach for 0156's
    strict `is_auto_net_name()` here, because a user-authored `lab=#foo` was
    measured to netlist as plain `foo`, so a strict test would disagree with the
    netlist for exactly the names 0156 declared legal; **(c)** never strip a bare
    `"#"` to `""` — the `,` separator is written regardless of what the element
    produced, so an emptied element emits `a,`. The portmap path is immune because
    `actions.c:3594-3599` strips at build time; the attribute path got its own
    strip in issue 0163 — see landmine 29.

27. **A `.save` card ngspice cannot parse is fatal ONLY when it is the sole
    `.save`** (issue 0159, measured ngspice-42). This corrects the sweeping
    version of the claim in landmine 23 and issue 0154. The matrix:
    `.save v(a[1:0])` alone → `Error: no data saved for Transient analysis;
    analysis not run`, no raw written; **the same card alongside any other
    valid `.save`** → the run succeeds and the bad token is *silently dropped*;
    `.save all` + a bad `print` → runs with only `Warning from checkvalid:
    vector … is not available or has zero length`. So the usual symptom of a
    bad expr is a **missing trace**, not a dead session — which is why these
    survive unnoticed. Also: the comma form `.save v(d,e)` is accepted outright
    (ngspice saves `v(d)` and `v(e)`), so `v(a,b)` is NOT a broken expr — it is
    ngspice's differential voltage, and any code tempted to "fix" a comma expr
    must not rewrite one a user typed (`ase::bus_expr_bits` is restricted to the
    bracket form for exactly this reason). A bus PICK is different: there the
    token came from the schematic and is known to be a net, so
    `ase::ui::sod_bits` splits both forms. `xschem expandlabel` is the splitter
    and needs **no loaded design**, so it is safe inside the pure ASE helpers
    where `xschem resolved_net` is not.

28. **A hierarchical node name cannot be built by string-prefixing the path**
    (issue 0161). ASE picking at `currsch>0` used to emit `v(mid)` for what
    ngspice calls `v(x1.x2.mid)`; the fix qualifies the token in
    `ase::ui::sod_qualify` (`ase_window.tcl`), called from `sod_click` — **not**
    in `sod_expr`, which must stay pure for `test_ase_interact` H1. Four facts,
    all measured on `tests/headless/fixtures/ase_hier` at depth 2, say the
    prefix must come from `xschem resolved_net` and not from `sch_path`: a
    **port** resolves UP to the parent's net (`A` → `TOPNET`, no prefix at all);
    a port **dangling** one level up stops there (`B` → `x1.net1`, ONE prefix
    level); a **global** is flat (`0` → `0`); and the `#` marker is stripped per
    element (landmine 26). Currents have no resolver, so that arm mirrors
    `send_current_to_graph()` (`hilight.c:1720`): `i(v.<lowercased sch_path>
    <name>)` descended, bare `i(<name>)` at the top — ngspice-42 names the
    branch `v1#branch` at the top but `v.x1.x2.v1#branch` nested, so the two
    forms differ structurally, and `get_raw_index`'s `i(v.x` fixup
    (`save.c:1700`) is the other half of the same convention. Two inherited
    limits ride along: `resolved_net` measures its path from
    `sch_waves_loaded()`, so an expr queued while a raw is loaded BELOW the top
    is relative to that raw; and the attribute lookup (landmine 29) is now on the
    pick path too. Also note the ASE-cannot-run-descended guard is **not**
    a `currsch` test — `ase::netlist` compares `xschem get schname` against the
    design path, and descending changes `schname` to the child.

29. **Only an `extra=`-declared attribute may rebind a net name** (issue 0163,
    FIXED — `hilight.c` ~2629, gate `attr_is_extra_node()`). `resolved_net`'s
    first move at each level is "maybe the parent passed this net down as an
    attribute", and `hier_attr[].prop_ptr` is the parent instance's WHOLE property
    string, so an ungated `get_tok_value` let **any** attribute spelled like a
    child net replace it — measured `value` → `1k`, `spice_ignore` → `false`,
    `name` → `X1`, and on the stock library `m` → `1`, `wn` → `8.4u`. The lookup
    is not junk: it implements `extra=`, upstream's "hidden pins with connections
    passed as parameters" (`doc/xschem_man/symbol_property_syntax.html:284-305`;
    `token.c` "extra is the list of attributes NOT to consider as instance
    parameters"), which `print_spice_subckt_nodes()` turns into real subckt ports
    — `rom8k/lvnot.sym` `extra="VCCPIN VSSPIN"` → `.subckt lvnot y a VCCPIN
    VSSPIN`. Four rules now hold: **(a)** gate on
    `xctx->hier_attr[level-1].sym_extra`, which was already captured next to
    `prop_ptr` at all four write sites (`actions.c`, `save.c`, `spice_netlist.c`,
    `spectre_netlist.c`) and until 0163 was read nowhere; **(b)** the membership
    test is an EXACT whitespace-token match, not the `strstr()` the netlister uses
    internally, so a net `EXTRA` cannot ride in on an `EXTRANET` entry; **(c)**
    do NOT strip a leading `#` off the accepted VALUE — measured, ngspice-42: an
    `extra=` value reaches the subckt CALL LINE verbatim (`X1 topn #hfoo c`) and
    ngspice names that node `#hfoo`, while a wire LABELLED `#hfoo` netlists as
    plain `hfoo`, so in one deck they are two distinct unconnected nodes
    (`hfoo` 0.0V, `#hfoo` 1.0V). A strip here names the WRONG node, and
    `get_raw_index()` — which never strips `#` — would resolve to it rather than
    fail. The portmap path strips only because a pin-passed `#net1` really is
    `net1` downstream; each path follows its own path's netlist. 0163 shipped a
    strip on the opposite premise and reverted it once measured;
    **(d)** there is NO usable "is this an LCC instance" test at this point — the
    `dbg()` line's "lcc" is only the struct's type name (`Lcc *hier_attr`), and
    `.symname` is always `NULL` on `xctx->hier_attr`; and **(e)** when the
    attribute is ABSENT from the instance, fall back to
    `hier_attr[level-1].templ`, because the netlister does — `translate()` at
    `token.c` ~5206 is the exact two-step this mirrors (issue 0164, FIXED). The
    fallback guard is `!xctx->tok_size` ("token absent"), NOT `!ptr[0]` ("value
    empty"): measured, an instance carrying `VCCPIN=""` gets NO node in the
    netlist, so present-but-empty must stop the walk rather than inherit. Do not
    copy the tEDAx chain at `token.c:3245-3247` — it has an extra
    `net:<pinnumber>` step and the looser `!val[0]` guard.
    **(f)** the netlister side now WARNS on what (c) refuses to rewrite: an
    `extra=`-declared node bound to a `#`-leading name is an ERC warning
    (`warn_hash_extra_node()`, `token.c`, called from `print_spice_element()` and
    `print_spectre_element()`), because a strip would not fix the shape — the
    child's `.subckt` PORT list keeps its own `#` too (`token.c:2098`,
    `spice_netlist.c:375`), so the port stays split from its body, and stripping
    properly means ~15 emission sites in five backends (issue 0165, D1 warn / D2
    loose / D3 no backend changes / D4 resolved_net unchanged). Two consequences
    for anyone editing this area: `attr_is_extra_node()` is **no longer static** —
    `resolved_net()` and the netlister share it deliberately so they cannot drift
    on what "`extra=` declares a node" means; and the check reads the RESOLVED
    value, never `get_tok_value(prop_ptr, tok, 0)`, or it misses `@`-forwarding,
    template defaults and `expr()`. Output neutrality is now MEASURABLE rather
    than argued: `tests/netlist_diff/netlist_diff.sh` diffs 920 generated
    netlists (189 designs x 5 backends) between two binaries, and is the harness
    that had to be rebuilt from scratch for 0163, 0164 and 0165 before anyone
    committed it.
    **(g)** `extra=` has a SIBLING list, `extra_pinnumber=`, and the tEDAx
    backend walks the two in LOCKSTEP with a `my_strtok_r()` cursor each
    (`print_tedax_element()`, `token.c` ~3234). Nothing keeps them the same
    length, and `my_strdup()` leaves its destination NULL for an absent
    attribute — so `extra=` without `extra_pinnumber=` used to hand
    `my_strtok_r()` a NULL first argument, which skips its `if(str)` first-call
    branch and dereferences an UNINITIALISED `saveptr` (issue 0179, FIXED: guard
    the call and default a missing number to `"--UNDEF--"`, as the pin loop nine
    lines above already does). Two things generalise. `my_strtok_r()` gives NO
    diagnostic for a NULL first argument, so every call whose first argument can
    be NULL is the same bug. And this backend's `%s` sites are not
    NULL-tolerant: passing the NULL token onward instead of the placeholder
    segfaults too (measured by sabotage), so both halves of that fix are
    load-bearing.

30. **"Which design is this?" is a question about the STACK, not the top of it**
    (issue 0168). Two shipped identity checks read only the *current* level and
    both broke Direct Plot the moment a user descended:
    `ase::design_of_current` → `xschem get schname` (the CHILD once descended, so
    the parent's session was declared not to exist), and
    `ase::ui::raise_design_editor` → `lindex $e 4` of `xschem windows`
    (`ctx->sch[ctx->currsch]`, so a window descended INTO the design looked like it
    was not holding it, and `design_window` re-opened the top elsewhere). The
    replacements walk: `ase::session_for_current` (`ase.tcl`) climbs
    `xschem get schname $l` from `currsch` to 0 taking the **nearest** ancestor
    with a session, and `xschem windows` now carries the whole stack as a **7th**
    field (appended — every `lindex $e 0..5` consumer is untouched). A level that
    resolves to no registered cellview is skipped, not fatal.
    The nearest-ancestor rule has a consequence: the session's design may sit at
    level N>0, and **every name must then be measured from N**, not from the
    window's top. That is what `ase::ui::sod_base_level` computes and what
    `xschem resolved_net <net> ?level?` / `resolved_net_from()` (`hilight.c`) take
    — the C used to measure from `sch_waves_loaded()`, i.e. from wherever a raw
    happened to be loaded, which is a property of the *window*, not of the deck the
    expression is written into (this also retires landmine 28's first inherited
    limit for the ASE path). Currents use `ase::ui::sod_rel_path` (sch_path prefix
    subtraction) instead: an instance path is a pure prefix chain, a net is not.
    Orthogonal trap, and the likelier user-visible one: Direct Plot writes **no**
    `.save` rows by design, so a descended internal node is only plottable if the
    run put it in the raw — no explicit outputs at all, or the Save-All-Voltages
    flag (`.save all`). Otherwise the pick is correct and the trace is simply
    absent.

31. **The graph PAN is on MMB, not LMB, and that change is ENGINE-WIDE**
    (2026-07-27, strip drag-reorder). `waves_selected` used to `skip` Button2
    press/motion/release so `handle_button_press` -> `start_pan_logged()` always
    got it; the graph pan lived on `Button1Mask` motion. LMB over a strip now has
    too much to do (cursor grab + move, trace pick, the issue-0152 wave-bold
    click, and the ASE viewer's drag-to-reorder), so the two swapped: the Button2
    skips are gone, `GRAPHPAN` also starts on Button2, and **both** pan motion
    arms (the main one and the `graph_bottom` absolute-positioning one) test
    `Button2Mask`. Consequences to know before touching this:
    **(a)** it applies to on-canvas schematic graphs too — MMB over an embedded
    graph pans the GRAPH, not the canvas;
    **(b)** off a graph MMB is still the canvas pan, and a canvas pan already in
    flight is protected because `STARTPAN` is in `waves_selected`'s `excl` mask —
    do not remove it;
    **(c)** Button1 stays in the `GRAPHPAN` start set: it still owns cursor drags
    and the wave-bold click, both of which need that routing latch (and the latch
    is also what freezes `graph_left`/`graph_top`/`graph_bottom` at press time);
    **(d)** the cursor-move guard `!(graph_flags & (16|32|512|1024))` stays on the
    pan arm — a MMB drag while a cursor is grabbed must not also pan;
    **(e)** in the ASE viewer MMB is no longer swallowed (issue 0149) but
    forwarded by `wviewer::btn2_filter`, which accepts the **press** only well
    inside a strip. That inset exists because `waves_selected` hit-tests with a
    5-px inner `border`: a press in that seam is NOT graph-routed and would reach
    `start_pan_logged` and slide the tiled canvas. The press decides; the motions
    and the release follow its decision, so a refused press cannot leak a
    half-canvas-pan mid-gesture.

32. **`reorder_handle` is a second on-screen-only decoration and follows the
    `active` rules exactly** (2026-07-27). Parsed in `setup_graph_data` **before**
    the `RECT_OUTSIDE` early return (landmine 11 — `xctx->graph_struct` is shared,
    a stale value leaks onto the next graph) and drawn in `draw_graph` gated on
    **flags bit 16**, so SVG/PS never see it and `print_image()`'s
    `draw_no_ui_decorations` gate covers PNG. Values: `1` grip, `2` grip + TOP
    drop bar, `3` grip + BOTTOM drop bar, `4` grip + a FRAME around the whole
    strip (the destination of a dragged TRACE, landmine 34). **2/3/4 are
    transient drag feedback**
    written by `setprop` on the two affected rects — `wviewer::graph_props` only
    ever emits `1`, so any `regenerate` lands back on a plain grip and a drag
    cannot leave a bar behind. The handle's hit zone is `GRAPH_REORDER_HANDLE_W`
    (`xschem.h`) and it is **MIRRORED IN TCL** in
    `wviewer::strip_handle_at_pixel` — change both or the drawn grip and the
    clickable target drift apart.

33. **`graph_near_wave()` is not `find_closest_wave()`** (2026-07-27). It answers
    "is this pixel within N SCREEN PIXELS of a drawn trace", with a real
    point-to-segment distance, a threshold, a LOCAL `Graph_ctx` (landmine 11) and
    the CALLER's pixels. `find_closest_wave()` has **no distance threshold at
    all**, measures only |Δy| at the nearest sample, and reads the C mouse mirror
    (`xctx->mousex/mousey`) — it can never implement an exclusion zone. Documented
    limits of the new one, both deliberate: **digital strips and bus traces answer
    0** (their rendering is a band/ribbon, not a polyline, so the whole body is
    reorder space there), and the scan is capped by the graph's own x window,
    exactly like the draw. It fails closed — a missing verb or an errored query
    reads as "empty space", never as "locked out". Since 2026-07-28 it is a
    one-line wrapper over `graph_wave_at()` (landmine 34), which returns the
    trace's index instead of a boolean — do not re-implement the distance scan.
    **Updated 2026-07-29 (issue 0174): the "no exclusion zone" note now has a
    FIXED caller.** The LMB wave-bold click no longer uses `find_closest_wave()`
    at all — it picks with `graph_wave_at(i, mx, my, GRAPH_TRACE_PICK_TOL)` off
    the EVENT's canvas pixels, so all four trace-picking surfaces on a strip (the
    click, `trace_menu_pick`, `strip_drag_press`, `strip_menu_pick`) now share
    one tolerance, `#define GRAPH_TRACE_PICK_TOL 10.0` in `xschem.h`. Change that
    and the two `{tol 10}` proc defaults in `wave_viewer.tcl` together.
    Consequences worth knowing before touching this again:
    (i) **digital and bus strips.** They now select NOTHING on a body click.
    Nothing was lost: `find_closest_wave()` refused digital (`draw.c` ~4509) and
    skipped bus entries (~4550) already — but it refused by returning BEFORE
    `*node_number = -1`, and the caller's local was uninitialised, so the click
    persisted stack garbage into the `hilight_wave` token (measured:
    `-1859984240`, on a digital strip and with no raw loaded). `*node_number` is
    now written above both early exits; a query that returns early still owes its
    out-params a value.
    (ii) `find_closest_wave()` **still exists and still has no threshold** — the
    `t` dataset-track arm (`callback.c` ~1341) uses its RETURN value (the
    dataset), never `node_number`. Do not delete it, and do not add a threshold
    to it: `t` genuinely wants "nearest, however far".
    (iii) a MISS CLEARS the selection. The worry that this collides with the
    strip drag-reorder (which owns the same pixels) is unfounded: the two are
    separated by the TRAVEL test, not by the pick — a real reorder drag travels
    past `GRAPH_CLICK_TOL` (3 px) and its release never reaches the arm, so only
    a no-travel click clears. See
    `doc/claude/issues/0174-trace-pick-needs-proximity.md`.

34. **A trace's MODEL index and its NODE index are different spaces, and every C
    answer is in the second one** (2026-07-28, trace drag between strips).
    `wviewer::graph_props` SKIPS a trace whose `vec` is empty when it builds the
    `node` token, so such a trace occupies a model slot and no node slot;
    `hilight_wave`, `find_closest_wave()`'s `node_number` and the new
    `graph_trace_at` all count NODES. `node_index_of_trace` / `trace_index_of_node`
    / `node_count` (`wave_viewer.tcl`, PURE) are the mapping and everything that
    crosses the boundary must go through them. Two more rules the trace move
    carries, both measured: **(a)** an EMPTY destination strip gets its
    `x1/x2/y1/y2` blanked back to auto, because `capture_live_graph_state` has
    just frozen whatever window the last fit left on it and a µA trace dropped
    into a 0–2 V window is drawn off-screen — the drop looks like it failed;
    a destination that already holds traces keeps its window. **(b)** the bold
    marker follows its trace: the source's `hilight_wave` is cleared and the
    destination is bolded at the appended node index, while an unrelated
    destination highlight survives. `move_trace` otherwise repeats `move_strip`'s
    ordering contract exactly (capture live state FIRST, target remapped IN PLACE,
    one regenerate, one log line) — see landmine 32's neighbours and
    `doc/claude/specs/waveform_viewer_modes.md` §13. The drop-target feedback is
    `reorder_handle=4` and obeys all of landmine 32's rules.

35. **A picked sample's x/y must be returned RAW, never in log space**
    (2026-07-28, waveform markers). The pickers COMPARE in log space —
    `xx = mylog10(gvx[p])` — because `gr->gx1..gy2`, and hence `S_X`/`S_Y`, are
    themselves log-space for a log axis (`setup_graph_data`; `graph_fullxzoom`
    writes already-`mylog10`'ed `x1`/`x2`). Every *displayed* number is the
    linear value, so the measurement tooltip and all nine cursor writes apply
    `pow(10, ·)` on the way out. **That round trip is correct only for the
    tooltip**, which starts from a mouse pixel with no raw counterpart. Applying
    it to a PICKED SAMPLE is both redundant and **lossy**: `mylog10(x)` is
    hard-clamped to `-35` for `x <= 0` (`editprop.c` ~26-30), so a zero or
    negative sample comes back as `1e-35`. Return `gvx[p]`/`gvy[p]` directly —
    which is why `GraphPointHit.x/y` are documented as "captured INSIDE the
    sample loop" and are separate from `sx`/`sy`. Delta and slope arithmetic
    must likewise use the raw values: a slope computed in log space is not
    `dy/dx`.

36. **The `graph_top` margin silently disables the GRAPHPAN ROUTING LATCH**
    (2026-07-28, waveform markers; line numbers and the snap clause **corrected**
    2026-07-30, issue 0177). `waves_callback` sets `xctx->graph_top = 1` for any
    press whose y is above the plot box — `mousey_snap < W_Y(gr->gy2)`, and
    `W_Y(gy2)` *is* `gr->y1`, the plot-box top edge (`callback.c` ~1160;
    `graph_left`/`graph_bottom` follow immediately) — and the `GRAPHPAN` latch
    (~1510, the flag set just below) is gated on
    `!xctx->graph_top`. All three margin flags are latched at PRESS time: the
    `if(ui_state & GRAPHPAN) goto finish;` just above the computation jumps past
    both it *and* the latch, so every later motion event in the drag reuses the
    press's verdict. **`GRAPHPAN` is not a pan** — it is the *routing* latch:
    `waves_selected` uses it to keep an in-flight drag routed to the graph after
    the pointer leaves the strip (`check = (ui_state & GRAPHPAN) ||
    POINTINSIDE(...)`) and to **freeze `graph_master`**. So any new LMB gesture
    whose grab target can live in a strip's MARGIN loses its release silently —
    no error, no log line, the drag just evaporates. Two rules, apply both:
    keep the grab target inside the **plot box**, **and** add the gesture's own
    in-flight flag to the latch condition (the marker drag did:
    `(!xctx->graph_top || xctx->graph_marker_drag)`). The second is not
    redundant — but **not for the reason this entry used to give** (corrected
    2026-07-30, issue 0177). Since issue 0143 `waves_callback` overwrites
    `mousex_snap`/`mousey_snap` with the raw pointer at its head,
    unconditionally and before any branch, and nothing writes them again before
    the margin computation — so `graph_top` and the marker hit test read the
    **same** coordinate and no grid setting can put a boundary press on opposite
    sides of them. What survives is a **tolerance** gap: `graph_marker_press`
    hit-tests with `GRAPH_MARKER_TOL` (8.0 screen px) around the anchor, so a
    press up to 8 px ABOVE the plot-box top still grabs a marker anchored just
    inside it while `graph_top` is already 1 — and without the extra term that
    release is silently dropped. (The routing consumer is `waves_selected`'s
    `check = (ui_state & GRAPHPAN) || POINTINSIDE(...)`, which reads the
    unsnapped `xctx->mousex`/`mousey` and always did.) See landmine 44 for the
    surfaces the 0143 override does **not** reach.

37. **`setup_graph_data()` is not safe as a QUERY** (2026-07-28, waveform
    markers). Two independent traps, both real:
    **(a)** it **returns EARLY for an off-screen graph** (the `RECT_OUTSIDE`
    test, `draw.c` ~3607) — *before* it parses `unitx` (~3633), `unity`,
    `xlabmag`, `divx/divy`, `logx` (~3664), `logy`, `y1/y2`, `digital`,
    `dataset`, the margins and the whole transform. Anything read out of `gr`
    after that point is a **default**, not the rect's value. (Only the fields
    defaulted+parsed *above* the return — `active`, `reorder_handle`,
    `hcursor1_y`/`hcursor2_y`, `linewidth_mult` — are trustworthy, and only
    because landmine 18 put them there deliberately.)
    **(b)** it has a **side effect on shared session state**: it unconditionally
    does `xctx->graph_flags &= ~(128|256)` and re-sets those hcursor bits from
    the rect's tokens (~3562-3572).
    So a query that needs a graph's axis tokens must read them **off the rect
    directly** with `get_tok_value`, not through a scratch `Graph_ctx`. This was
    a real bug, caught in the marker label formatter: `graph_marker_text()`
    printed `M2:0,0` for a marker on a graph scrolled off-screen, because
    `gr->unitx`/`gr->logx` were never parsed. `graph_marker_text_rec()` (the
    label core it became) now reads `logx`/`unitx`/`unity` straight from
    `r->prop_ptr`. (Callers that DO need the transform — `graph_point_at`,
    `graph_marker_at`, `graph_marker_create`, `graph_marker_drag_to`,
    `graph_coord` — keep the `gr->scx == 0.0 || gr->scy == 0.0` "no transform"
    gate instead, which is the correct way to detect that the early return
    fired. `graph_coord` uses `gr->cx`/`gr->cy` for the same purpose.)
    **A query that must call it anyway has to put (b) back**, with
    `saveflags = graph_flags & (128|256)` … restore around the call. **Four**
    sites do, and the fix landed on them one at a time as each turned out to be
    reachable: `graph_marker_at()` (`draw.c` ~5418 — reachable from
    `xschem get graph_marker_at` with the pointer nowhere near that strip, the
    original case), `graph_point_at()` (~4687 — backs the `graph_trace_at` /
    `graph_near_wave` verbs *and* runs once per motion event inside a marker
    anchor drag), `graph_marker_create()` (~5689 — it only wants `gr->digital`,
    but pays the side effect anyway) and `graph_marker_drag_to()`
    (`callback.c` ~633 — provably a no-op today, because GRAPHPAN freezes
    `graph_master` for the whole drag and `graph_marker_draggraph` is that same
    graph, but the bracket is two lines and the invariant should not rest on
    that). **`graph_coord` (`scheduler.c` ~4962) still does NOT bracket** — it
    is a pure Tcl query on an arbitrary graph index and has exactly the exposure
    `graph_marker_at` had. Small, self-contained follow-up. Any new query on this
    pattern owes the same two lines.

38. **The `sweep` list CARRIES ITS LAST ENTRY FORWARD, so resolve the sweep
    token BEFORE any `continue`** (2026-07-28, waveform markers). `sweep=` is a
    positional list indexed against `node=` (§2.5) and it is routinely
    **shorter** — one entry for a whole graph is the common case. The walkers
    implement "carry forward" implicitly: `stok = my_strtok_r(sptr, ...)` returns
    NULL once the list runs out, and the `if(stok && stok[0])` guard simply
    leaves `sweep_idx` at its previous value. That only works if **every** node
    entry pulls from the sweep list on every iteration.
    Any `continue` placed above that pull silently breaks it, and the failure is
    never an error — it is a **wrong column**, usually column 0 (`sweep_idx`'s
    initial value), i.e. "nothing found" or "found against the wrong x". Three
    walkers have been bitten:
    **(a)** `find_closest_wave` and **(b)** `graph_point_at` — the *bus* skip
    (`continue` on a `,` entry) jumped the pull, so every trace after a bus was
    measured against the previous entry's sweep variable (that half is fixed in
    both, together with the infinite loop the same `continue` caused — §12's DONE
    callout);
    **(c)** `graph_point_at` again and `graph_wave_resolve` — the
    `restrict_wave` skip (`if(restrict_wave >= 0 && wcnt != restrict_wave)
    continue;`) is *below* the pull for exactly this reason. It was above it, and
    then every RESTRICTED walk — which is **every marker anchor drag** — fell
    back to raw column 0 and found nothing: `xschem graph_marker move` returned
    0, the record never changed, and no message was printed anywhere.
    Rule: in any per-node walk, `stok = my_strtok_r(sptr, ...)`, `nptr = sptr =
    NULL` and the `sweep_idx` update come **first**, before the bus test, before
    any restriction test, before anything that can `continue`. `draw_graph` has
    always done it this way, which is why the draw and the pickers used to
    disagree.

39. **A rect's `prop_ptr` is duplicated by TWO paths, and anything carrying a
    UNIQUE ID in a prop token must renumber in both** (2026-07-28, waveform
    markers). The doors are `merge_box()` (`paste.c` ~254 — the clipboard/paste
    merge) and `copy_objects()` (`move.c` ~962 — the `c`-key copy, and every
    copy-with-transform). Both clone the source string **verbatim**, so a token
    holding an identity produces two objects claiming the same one.
    Markers hit this twice: the paste door was found first, the copy door only
    after review, and a `c`-key copy of a graph then produced two markers
    numbered 1 and two numbered 2 — which breaks `graph_marker_find`, the `prev`
    partner links, the selection and the delete, all of which rest on window-wide
    uniqueness.
    **The two call sites are NOT symmetric — note the ordering.** In `merge_box`
    the renumber runs *before* `gfx_register` bumps `xctx->rects[c]`, so the new
    rect is still invisible to a window-wide numbering scan; in `copy_objects`
    `storeobject()` has **already** registered it, so the scan sees it and the
    computed base comes out above *both* copies. Either way the base must be
    computed **once per rect** and reused for every record on it — recomputing
    per record hands them all the same number in the first case, and marches them
    upward for no reason in the second.
    There is no shared chokepoint, so a third duplication path would inherit the
    bug in silence. Grep both function names when adding an id-bearing token.

40. **`extra_rawfile(5, ...)` is a SWAP, not a stack pop — restore only if the
    switch took** (2026-07-28, waveform markers). `save.c` (~1373-1378)
    implements mode 5 as
    `tmp = extra_idx; extra_idx = extra_prev_idx; extra_prev_idx = tmp;`.
    There is no depth counter and no "no-op if we never switched": an
    **unpaired** mode-5 call does not return you to where you were, it silently
    repoints `xctx->raw` at the previous slot and leaves it there.
    So every `extra_rawfile(<switch>, ...)` / `extra_rawfile(5, ...)` pair must
    be guarded by a local flag recording whether the switch **succeeded**:

    ```c
    int switched = 0;
    ...
    if(extra_rawfile(autoload, file, type, -1.0, -1.0) != 0) switched = 1;
    ...
    if(switched) extra_rawfile(5, NULL, NULL, -1.0, -1.0);
    ```

    `graph_point_at()` (`draw.c` ~4718/~4868) and `graph_marker_sample()`
    (~5566/~5592) both do. `graph_point_at` is what made this reachable: when a
    graph carries no `rawfile=` token it synthesises one from
    `xctx->raw->rawfile`, so it *attempts* a switch on essentially every call.
    Measured before the flag: a **pure hover query** on a graph whose `rawfile=`
    does not resolve flipped `xctx->raw` on every single call — one toggle of
    the session's current raw per motion event, with nothing written and nothing
    logged.
    The sibling rule is that a caller whose switch FAILED must also **refuse to
    read**, not fall through onto whatever raw is current: `graph_point_at` sets
    `valid_rawfile = 0` and skips every node; `graph_marker_sample()` now bails
    with `ok = 0` for the same reason (it used to read anyway, so the pixel path
    and the data path disagreed on an unresolvable graph).
    **`find_closest_wave` (~4350) has BOTH open defects** and is the one place
    left to fix: it still switches at graph level (~4418) *and again per node*
    (~4445) while restoring exactly once (~4563), and that single restore is
    gated on `custom_rawfile[0]` — i.e. on "we intended to switch", not on "the
    switch took". Same self-contained hoist as the §12 DONE-callout item 3, plus
    a `switched` flag.
    Related but distinct from landmine 13 (`extra_idx` desync between
    `raw_read` and `extra_rawfile`) — this one desyncs a *balanced-looking*
    caller.

41. **The C→Tcl marker push hook is `has_x`-gated, so NOTHING about the viewer
    model or the viewer undo stack is observable under `--nogui`** (2026-07-29,
    viewer plan item 4). `graph_marker_notify()` (`draw.c` ~6073) opens with

    ```c
    if(!has_x) return;
    ```

    and it is the *only* route by which a C-side marker mutation reaches Tcl:
    `graph_marker_notify` → `::graph_marker_changed` → `wviewer::marker_changed`,
    which rewrites the strip's model dict **and** pushes the single undo point
    (§8). Under `--nogui` that whole chain is dead code, so after a headless
    `xschem graph_marker delete -all` the rects are correct while the Tcl model
    still carries its stale `markers` key, and `wviewer::history_depth` never
    moves.

    The consequence for **tests** is the one that bites: a plan or a leg that
    says "assert the model lost its `markers` key" or "assert `u` brings them
    back" is a **DISPLAY-arm** assertion, full stop. Written into the `--nogui`
    arm it does not fail — it asserts the *pre-mutation* state and passes for
    entirely the wrong reason. `tests/headless/test_wave_markers.tcl` splits the
    `MD` group on exactly this line (engine half after MF5, viewer half inside
    the `has_x` gate) and says so in its header.

    **The same split, for a second and independent reason: Tk** (2026-07-30,
    issue 0176). Any viewer command that ends in `wviewer::regenerate` goes
    through `viewport_rect` → `winfo width`, and under `--nogui` there is no Tk
    at all — so the whole command layer is DISPLAY-only however the fixture is
    built, `has_x` hook or no hook. `wviewer::delete_items` is the case in point.
    The half that CAN be asserted in both arms is the pure list/index math
    (`delete_in_graphs`), and it lives in a different file
    (`test_wave_modes.tcl`'s `DT` group) for exactly that reason. When splitting
    a new group, ask BOTH questions: does it observe C-pushed model state, and
    does it call anything that regenerates?

    A second consequence for **wrappers**: a Tcl proc must not "helpfully" write
    the model itself to paper over the headless gap. In a real (DISPLAY)
    session the hook has already written it, and the second write lands *after*
    the hook's `push_undo` — the snapshot-after-mutate bug class, where `u`
    restores the very thing it was meant to undo.
42. **A context switch REWRITES THE TARGET WINDOW'S TITLE, and the viewer repairs
    that only on FocusIn — so any Tcl that switches into a viewer must restore the
    context AND re-assert the title** (2026-07-29, issue 0173). This is the
    reusable half of that bug and it generalises past the viewer.

    `xschem new_schematic switch <win_path>` looks like a cheap pointer swap. On
    the window interface it is not: `switch_window` (`xinit.c` ~1784, always
    entered with `tcl_ctx == 1` from Tcl) runs `save_ctx` / `restore_ctx` /
    `housekeeping_ctx` / `reconfigure_layers_button {}` and ends in

    ```c
    set_modify(-1); /* sets window title */
    ```

    whose `mod == -1` arm exists *only* to `wm title` the now-current window from
    its own buffer name (`actions.c` ~241-266). The viewer's buffer is a nameless
    read-only untitled one, so switching into a viewer stamps it
    `xschem [N] - untitled.sch (read-only)`. Nothing repairs that except the
    viewer's own `bind $top <FocusIn> "+wviewer::retitle $token"` — which is why
    the reported symptom was *"hovering over the viewer fixes the title"*. Two
    pieces of collateral ride along, both aimed at the ROOT window regardless of
    which window you switched to: `reconfigure_layers_button {}` recolours `.`'s
    Layers menu entry from the *new* context's `rectcolor`, and
    `housekeeping_ctx` writes a hardcoded `.statusbar.7 configure -text
    $netlist_type`.

    Two early returns matter and they return **opposite** values while doing
    equally nothing: `if(xctx->semaphore) return 1` (the landmine-17 refusal) and
    `if(!strcmp(win_path, xctx->current_win_path)) return 0` (already there).
    The already-there case is free — no title rewrite, no Tcl round trip — which
    is what makes a "restore to where you found it" bracket cost nothing on a
    caller that was already in the right context.

    So the shape for any Tcl that needs to READ or DRAW in another window is a
    ticket, not a switch: capture `xschem get current_win_path`, switch with
    verification, run, switch back **with verification**, re-assert the target's
    title. `wviewer::enter_ctx` / `wviewer::leave_ctx` (`wave_viewer.tcl`) are
    that bracket; `wviewer::switch_ctx` remains the deliberate one-way verified
    switch for destructive callers, and `with_edit` the mutation bracket that
    re-asserts the title but intentionally leaves the context on the viewer.

    **A leaked context does not look like a leaked context.** In issue 0173 the
    user reported "the schematic window loses focus", and no `focus`, `raise` or
    `raise_dialog` call existed anywhere in the chain. What they saw was the
    schematic canvas going *inert*: `handle_motion_notify` (`callback.c`
    ~5083-5093) drops any motion whose `win_path != xctx->current_win_path`, so
    the crosshair and snap cursor freeze mid-canvas; `update_statusbar()`
    addresses `xctx->top_path.statusbar.*` so the status line stops being
    written; and `callback()` dispatches on the global `xctx`, while
    `handle_window_switching` does not switch on KeyPress/ButtonPress. Recovery
    needs an **EnterNotify**, not focus — with `mouse_follows_focus` defaulting
    to 1 the FocusIn arm is skipped entirely (`callback.c` ~7945-7951), which is
    why "click away to another window and back" was the only thing that fixed it.

    **For tests:** the context leg (`xschem get current_win_path`) is assertable
    in BOTH arms, but the title leg is `has_x`-gated inside `set_modify` and is
    therefore **DISPLAY-arm only** — same split as landmine 41. And both FocusIn
    repair paths will mask the whole defect, so a leg must assert with **no
    `update`** between the gesture and the assertion, and must **spy the retitle
    proc**: comparing only the final title string passes just as happily on
    corrupted-and-repaired as on never-corrupted.

43. **The LEGEND has a C hit test — it always did — but it was fused into an
    ACTION and keyed off GRID-SNAPPED XSCHEM coordinates, while the trace hit
    test takes RAW SCREEN pixels. The two picking surfaces of one strip did not
    share a coordinate space** (2026-07-30, issue 0175).

    Two comments in `wave_viewer.tcl` said the engine had *"no C hit-test API"*
    for the legend and both were wrong when written. What was missing was a
    standalone QUERY: the hit test lived inside `edit_wave_attributes(what, i,
    gr)` (`draw.c`), **triplicated once per legend layout** (vertical, digital,
    horizontal) and reachable only from a Button3 press. It is now the static
    `legend_slot_hit()` plus the public `graph_legend_at(i, px, py)`
    (`xschem get graph_legend_at`, `wviewer::legend_at`), and BOTH mouse buttons
    plus Tcl go through it — the ~100 lines of duplicated geometry are gone and
    the drawn label and its clickable target cannot drift apart.

    ⚠ **The coordinate trap, which is the reusable half.** `gr->rx1/ry1/rw/rh`
    are **XSCHEM coordinates** (`xschem.h`: *"container rectangle, xschem
    coordinates"*), so the legend boxes are computed there; `graph_wave_at` /
    `graph_plotbox_at` compare **SCREEN PIXELS** via `S_X`/`S_Y`. The in-place
    version tested `xctx->mousex_snap` / `mousey_snap` — the grid-SNAPPED
    schematic-space mouse mirror — so with a coarse grid a pointer sitting on
    entry 2 tests as entry 1. That is *neutralised* for its two `waves_callback`
    callers, because `waves_callback` overwrites `mousex_snap` with `mousex` at
    its head (issue 0143), but it was never a contract anything else could rely
    on. `graph_legend_at` takes the CALLER's pixels and converts once
    (`px / xctx->mooz - xctx->xorigin`), matching every other picking query.
    Any new picking surface on a strip owes the same: state which space it takes,
    and take the event's pixels.

    Three more properties worth knowing before touching it:
    **(a)** it does NOT refuse digital strips, unlike `graph_plotbox_at` and
    `graph_trace_at` — a digital strip's body answers -1 everywhere (issue 0174
    D5), so its legend is the only place a trace can be picked at all;
    **(b)** it refuses `legend=0`, which the triplicated version did not — it
    would happily pick an entry that is not drawn;
    **(c)** it fails closed on a bad index / non-graph rect / off-screen graph /
    absent `node` token, and uses a LOCAL `Graph_ctx` with the hcursor bits
    bracketed (landmines 11 and 37), like every other query on this pattern.

    **And the selection it drives is now a SET.** `hilight_wave` is still a
    single int and still means "the first selected NODE index, or -1"; a second
    optional token `sel_waves="0 2"` carries the whole set and is emitted ONLY
    when two or more are selected, so a strip that was never Ctrl-clicked
    serialises byte-identically to pre-0175 and an older build bolds the first
    selected trace instead of choking. `graph_sel_waves_get/set/toggle` are the
    only readers/writers of the pair in C, `wviewer::model_sel` /
    `model_sel_set` on the model side — the two tokens cannot drift because
    nothing else touches them.
    ⚠ **Every draw-side comparison must be `wave_is_hilighted(gr, wcnt)`, never
    a bare `gr->hilight_wave == wcnt`.** There were 11 such comparisons in
    `draw.c` (the trace stroke, the per-node draw, all three legend faces
    including item 1's bold-vs-bold-italic distinction). A single missed one
    renders a Ctrl-selected trace THIN while the token says it is selected, and
    no test that only ever selects one trace can see it —
    `test_wave_legend.tcl` `LS5` asserts it at source level for that reason.
    In memory the set is a FIXED array in `Graph_ctx`
    (`sel_wave[GRAPH_MAX_SEL_WAVES]`), never a malloc'ed pointer: six call sites
    build a LOCAL `Graph_ctx` and let it die on return, and a pointer field would
    leak on each of them once per hover motion event.
    Spec: `doc/claude/specs/waveform_viewer_modes.md` §15.

44. **"No snap grid in graphs" was a HANDLER-LOCAL override, not a property of
    the canvas — and the difference is a whole region of every strip**
    (2026-07-30, issue 0177). `xctx->mousex_snap`/`mousey_snap` are BORN
    grid-quantised at the top of `callback()`
    (`mousex_snap = my_round(mousex / c_snap) * c_snap`, `c_snap` =
    `tclgetdoublevar("cadsnap")`), for **every event on every window**. Issue
    0143 undid that at the head of `waves_callback()` — which covers exactly the
    code reached THROUGH that handler and nothing else.
    ⚠ **The useful question is not "is this override safe" (it is) but "what
    does it not reach".** Everything that runs when `waves_selected()` DECLINES
    the event. That includes a band just inside every strip rect, which contains
    **the top of the LEGEND** (`legend_slot_hit` starts its horizontal slots at
    `gr->ry1`, the rect top itself). In that band the schematic arm of
    `handle_motion_notify` runs and paints `draw_crosshair()` **at**
    `mousex_snap` — the snap grid, made visible, over the legend and nowhere
    else. Measured, and it is what the 0175 eyeball reported. Eight further
    grid-quantised surfaces were reachable the same way, including
    `wviewer::graph_at_pointer` (the wheel's strip target, `wave_viewer.tcl`)
    and `wviewer::over_graph` (the `a`/`b`/`s`/`m`/`t`/Delete key gate) — both
    Tcl, both reading `xschem get mousex_snap`, both wrong near a band boundary.
    **The fix is a per-context flag, `xctx->no_snap`, tested at the SOURCE** —
    the one place that covers every present and future reader. Same shape as
    `no_grid` and `graph_snap`, same blast-radius reasoning, armed by
    `wviewer::open`. 0143's local override **stays**: an ordinary schematic
    window can embed graphs, `waves_callback` runs on those too, and that
    context is not `no_snap`.
    ⚠ **A canvas property must be tested inside the DRAWER, never in the
    caller's local.** The first cut gated `callback()`'s `draw_xhair` /
    `snap_cursor` locals and that was wrong twice: `draw()` itself ends with
    `if(tclgetboolvar("draw_crosshair")) draw_crosshair(7, 0);` (`draw.c`) and
    `move.c` has three more such sites, none of which consults those locals — so
    every ERASE path went dead while the PAINT paths stayed live, leaving an
    orphaned crosshair on the waveform after each full redraw. And the locals
    are INITIALISERS, evaluated before `handle_window_switching()` may reassign
    `xctx`, so on the EnterNotify that switches into or out of a viewer they
    describe the previous context. `draw_crosshair()`/`draw_snap_cursor()` now
    carry the test themselves.
    ⚠ **`waves_selected()`'s rect inset was in the wrong units** and had been
    since it was written: `border = (int)(5.0 * tk_scaling)` is documented as
    "screen pixels" but is subtracted from `r->x1`/`r->y1`, which are XSCHEM
    units. One screen pixel is `xctx->zoom` xschem units, so the inset was
    `1/zoom` too wide — MEASURED 21.9 canvas px where 6.7 were intended, which
    is what put the legend's top rows out of reach of a click at all. Now
    `border = 5.0 * tk_scaling * xctx->zoom`. This one is NOT viewer-scoped: it
    changes the grab margin of embedded schematic graphs too, in the direction
    of the value the comment always claimed.
    Issue: `doc/claude/issues/0177-viewer-has-no-snap-grid.md` (per-region hover
    table in §3).

45. **A CREATION gate must match the FEEDBACK gate — and `graph_marker_create`'s
    own `Graph_ctx` cannot answer a geometry question** (2026-08-01, issue 0188).
    Two reusable lessons from one three-line fix.

    **(a) The glyph and the key must ask the same question.** The item-9 diamond
    snap cursor (`draw_graph_snap_cursor`, `draw.c`) is the thing that SHOWS the
    user which sample `m` would mark. Its gate was fixed to the plot box in the
    0177 era; `graph_marker_create()`'s was left as a 20-px distance to a trace
    (`GRAPH_MARKER_PICK_TOL`, now deleted). For a release the two disagreed in
    **both** directions, and both were user-visible: no marker in the middle of
    an empty plot box where a diamond was plainly drawn, and a marker created 6
    px OUTSIDE the box, in the axis-number margin, where no diamond exists
    (measured: `xschem graph_marker add 0 145 480` created one). The fix is to
    make the creator issue the *same two calls* the feedback path issues —
    `graph_plotbox_at(i, px, py)` then
    `graph_point_at(i, px, py, 1e30, -1, -1, &hit)` — not to re-derive an
    equivalent test. Generalise: when a feature has a hover GLYPH and a
    committing KEY/CLICK, the two share a predicate or they will drift, and the
    drift is invisible to any test that only ever aims at a trace.
    ⚠ The sibling constant `GRAPH_TRACE_PICK_TOL` (10 px, landmine 33) was
    deliberately NOT touched: picking a trace with the mouse is an aim and wants
    proximity; pressing `m` is a declaration and does not. Two gates, two
    questions, one strip.

    **(b) `graph_marker_create()` builds its `Graph_ctx` with
    `setup_graph_data(i, 1, gr)` — `skip = 1` — so `gr->digital` is the ONLY
    field of it that may be read.** `skip` suppresses the `x1`/`x2` parse
    (`draw.c`, the `if(!skip)` block), leaving `gx1 == gx2 == gw == 0`; the
    derived `gr->cx = gr->w / gr->gw` is then **infinity**, and so are `dx`,
    `scx`, `sdx`. Worse, the usual `gr->scx == 0.0` "no transform" sentinel is
    useless there, because `inf != 0`. Any geometry question inside that
    function must therefore go through `graph_plotbox_at()`, which builds its
    own `Graph_ctx` with `skip = 0` and is the single source of truth for the
    box — the `graph_marker_label_box` doctrine (one function owns one geometry)
    applied to a second shape. This is a *different* trap from landmine 37's
    off-screen early return, and it bites in the opposite way: 37 hands you
    defaults, this hands you infinities.

    Spec: `doc/claude/specs/graph_markers.md` D12 + §6.3;
    `doc/claude/specs/waveform_viewer_modes.md` §15.7; issue
    `doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md`.
    Suite: `tests/headless/test_wave_markers.tcl` group `MP*` (both arms),
    `MP20`-`MP22` (display) and the inverted `MX4`/`MX4b`.

46. **The marker SELECTION is a SET, it is deliberately NOT a prop token, and a
    multi-object delete owes ONE undo point** (2026-08-01, issue 0189).
    Three reusable lessons from one feature.

    **(a) Every "is *this one* selected" test goes through
    `graph_marker_is_selected()`.** There are exactly FOUR such sites — the
    renderer's `selected = ...` in `draw_graph_markers()` (`draw.c`), the
    RIGID-drag latch in `graph_marker_press()` and the click toggle in
    `graph_marker_release()` (`callback.c`), and the delete's drop-from-the-set —
    plus one "is ANYTHING selected" (`graph_marker_n_sel > 0`). A surviving bare
    `== xctx->graph_marker_sel` renders a selected PARTNER in the *unselected*
    style, and **no behavioural leg that selects a single marker can see it**:
    with `n_sel == 1` the bare comparison and the predicate agree exactly. That
    is why the assertion has to be at SOURCE level (`MS13`, the `LS5` idiom from
    `test_wave_legend.tcl`, counting on CODE lines only with `count_code`), and
    why it asserts the *exact* surviving set rather than a `>= N` count: the
    three sanctioned bare HEAD readers are the getter (`scheduler.c`), the
    `Delete` strip-scope gate and the repaint-scope hint (`callback.c`).
    ⚠ The trace precedent (landmine 43, issue 0175) had **eleven** bare sites.
    Markers have four. Look for the sites, do not import the number.

    **(b) It is NOT a prop token, unlike the 0175 trace selection — and
    "mirror 0175 exactly" is the wrong instinct.** Trace bold *is* per-rect
    render state, carried in the `hilight_wave` token that `sel_waves` extends.
    The marker analogue of `hilight_wave` is `xctx->graph_marker_sel`, a
    **session field**: `graph_markers.md` §3.5 says selection is UI state that
    must die with the document, and `clear_drawing()` resets it precisely so a
    reloaded schematic does not open with a marker mysteriously ringed. So the
    set lives in `xctx` at every size (a fixed `int[GRAPH_MARKER_MAX_SEL]`, never
    a pointer — `xctx` is reset, not freed, and a pointer would add a free path
    to `clear_drawing()` for nothing), and **no `prop_ptr` byte changes under any
    selection**. `n_sel` joins the *gesture-state* reset class (both
    `actions.c:clear_drawing()` and `xinit.c:alloc_xschem_data()`), not the
    press-time-payload class — §3.5 documents that there are two.
    The regression witness is the strongest available form: `MS8` compares the
    **whole serialised buffer** before and after a two-marker selection, not just
    the `markers` token.

    **(c) A multi-object delete owes exactly ONE undo point — split the
    primitive, never loop the public form.** `graph_marker_delete()` became a
    one-line wrapper over `static graph_marker_delete_1(num, push)`;
    `graph_marker_delete_selected()` refuses read-only **once** (one CIW line,
    not one per member), COPIES the set into a local (the drop-from-the-set
    mutates it as records go — iterating it in place skips every other member),
    pushes undo once, then calls the no-push form per member. Each member still
    self-logs its own `xschem graph_marker delete <n>` line, so replay is by
    explicit number and needs no selection state. A one-key gesture that took two
    `u` to undo is the defect this shape prevents; `SAB-5` is its sabotage.

    Compatibility rule that made the whole thing cheap: **the head keeps its
    meaning**. `xschem get graph_marker_sel`, every `graph_marker select` return
    value (including the new `-pair`/`-set` forms) and `wviewer::marker_selected`
    are byte-for-byte unchanged; the set is read through a NEW getter
    (`xschem get graph_marker_sel_set`). ~27 shipped assertions rest on that.

    Spec: `doc/claude/specs/graph_markers.md` D9 + D13 + §3.5 + §7.2/§7.3;
    `doc/claude/specs/waveform_viewer_modes.md` §15.1 + §16; issue
    `doc/claude/issues/0189-dblclick-delta-marker-selects-pair.md`.
    Suite: `tests/headless/test_wave_markers.tcl` group `MS*` (both arms) and
    `MS-X1`-`MS-X6` (display).

47. **An axis MARGIN is not free real estate; the formula gets its own function
    AND its own query verb; and a C-side view write owes no viewer bookkeeping**
    (2026-08-01, issue 0190, the LMB axis-region drag zoom). Three reusable
    lessons from one gesture.

    **(a) Everything is already living in the margins.** Before choosing which
    pixels a new margin gesture owns, list the four owners that are there first,
    because none of them is obvious from a screenshot:
      * the **x/y CURSORS**. An x-cursor's line is drawn `gr->ry1..gr->ry2` and
        its numeric READOUT at `gr->ry2-1` — i.e. *in* the bottom margin
        (`draw_cursor`, `draw.c`); an hcursor's line spans `rx1+10..rx2-10` and
        its readout sits at `gr->rx1+5`, *in* the left margin (`draw_hcursor`).
        ⚠ Their four grab tests have **no plot-box confinement at all** and are
        compared in **XSCHEM units**, not screen pixels
        (`fabs(mousey - W_Y(cursor)) < 10`, `callback.c`) — at viewer zoom ≈ 0.27
        that is ≈ 37 screen px of margin the cursor can claim. So "a press that
        grabbed a cursor keeps the whole drag" has to be an explicit test
        (`!(graph_flags & (16|32|512|1024))`), never an assumption about geometry;
      * the **VERTICAL and DIGITAL legends**, which *are* the left margin
        (`legend_slot_hit`: `rx1+5 .. x1-5`, and `rx1 .. x1-20*txtsizelab`). The
        horizontal legend is the only one in the top band, and reading "the
        legend is at the top" off the horizontal case is how the left margin
        gets stolen from `vlegend` strips;
      * the **reorder GRIP**, the right `GRAPH_REORDER_HANDLE_W` (14) screen px
        at EVERY height, which `graph_marker_press()` already declines
        unconditionally and which the Tcl seam tests before anything else;
      * in the ASE viewer, `strip_at_pixel` covers the **whole band**, so the
        margins were in the strip drag-reorder zone by permissiveness even though
        the spec's own sentence never claimed them ("the reorder handle (always)
        or empty waveform body", `waveform_viewer_modes.md` §12.1). Measured
        before deciding: in the C engine an LMB margin drag was a **complete
        no-op**, and in the viewer it **reordered the stack**.

    **(b) The formula gets its own function AND its own query verb.** A gesture
    computes a transform for its live feedback and again for its commit, and a
    replayable verb computes it a third time — landmine 45(a) says they will
    drift and that no behavioural leg can see it while they still agree. The
    shape that fixes it: `graph_axis_at()` / `graph_axis_map()` /
    `graph_axis_zoom()`, with `graph_axis_map()` exposed as
    `xschem get graph_axis_map`. The verb is not a convenience — it is what lets
    a headless suite assert **both endpoints** of the map instead of only the
    visible consequence, and the anchored zoom-out is exactly the case where a
    width-only implementation passes every "the range grew" assertion with the
    window slid sideways. A source-level leg (`count_code`) then asserts the
    expression appears once in `draw.c` and is CALLED once from `callback.c` and
    once from `scheduler.c`. ⚠ Write it as `zlo = A - ub * R2;` and not
    `*lo = A - ub * R2;`: the `count_code` idiom skips lines beginning with `*`,
    because that is what a C comment continuation looks like.

    **(c) A C-side view write needs no `capture_live_graph_state` and no viewer
    undo.** It is one more PRODUCER for the capture the *next* Tcl mutation runs,
    exactly like the MMB pan and the RMB box zoom — not a consumer of it. It sets
    no dirty flag and pushes no C undo point (landmine 19), which is also what
    lets the read-only ASE viewer perform it with **no `with_edit` bracket** and
    what makes readonly-rejecting the verb wrong (landmine 17 already lists the
    box zoom as view state the engine may put in a read-only rect). The visible
    consequence — a plain window RESIZE discards it, because `regenerate`
    re-places every rect from the model — is shipped behaviour for that whole
    class, not a new defect.
    ⚠ One thing it DOES owe: the GRAPHPAN **routing** latch (landmine 36). Its
    own in-flight flag must join `(!graph_top || graph_marker_drag)`, because a
    region defined as "left of the plot box, anywhere in the container" reaches
    above the box top, and a drag armed with `graph_top == 1` loses its release
    silently.
    ⚠⚠ **AND THE LATCH TERM IS ALMOST UNTESTABLE BY ACCIDENT** — it shipped with
    zero coverage and a green suite (found 2026-08-01 by an adversarial re-read,
    closed by `AG14`). A gesture leg that releases **inside** the strip cannot
    see the term at all: `waves_selected`'s POINTINSIDE arm re-finds the graph on
    its own, `graph_master` is still set, and the release reaches
    `waves_callback` whether the latch fired or not. Both halves are required —
    press in the **TOP-LEFT corner of a strip owning no legend entry** (a `node`
    token puts the horizontal legend's slot 0 across the whole top band, so
    `graph_axis_at` declines it) so `graph_top` is already 1, **and** release
    **outside the container band** so nothing but the latch can route it back.
    Assert `xschem get ui_state & 32768` right after the press as well as the
    commit.
    ⚠⚠ The same line is load-bearing twice, and the second job hid a real bug.
    `waves_selected`'s `if(!is_inside)` branch aborts an armed marker drag; it
    must abort an armed AXIS drag too. It looks unreachable — GRAPHPAN keeps the
    pointer-outside case out of it — but **every `skip = 1` clause jumps the rect
    loop**, leaving `is_inside` 0 with GRAPHPAN still set. Adding Shift mid-drag
    is one (`MotionNotify && Button1Mask && ShiftMask`). Measured before the fix:
    the abandoned arm survived the shift AND the release, `graph_axis_press_arm()`
    returns early rather than clearing it when the next press is not in a margin,
    and a following plain LMB drag in the **plot body** committed a zoom from the
    abandoned press position (`y1/y2 0..2.5 -> 1.2537228..2.3920389`). Leg
    `AG15`, and it must contain **no ESC** — `abort_operation()` clears the arm
    and masks the whole thing.

    **(d) THE AXIS WINDOW ALSO HAS ONE HOME, and its digital branch was wrong
    for one release** (added 2026-08-01, issue 0191). Both formulas must answer
    *"what is this axis's window, and what pixel extent does it occupy?"*, and
    the shipped answer resolved Y from `gy1`/`gy2` and `S_Y` **unconditionally**
    while `graph_axis_zoom()` wrote the result into `ypos1`/`ypos2` on a digital
    strip. MEASURED at `826e1b60` on `y1=0 y2=2.5 ypos1=0 ypos2=4`:
    `xschem get graph_axis_map 0 y 636 310` → `0 1.6437` — the analog window,
    applied to a band of extent `0..4`. Decision D-19 was documented and never
    implemented. It is now `graph_axis_window(gr, axis, &A, &B, &e1, &e2)`
    (static, `draw.c`), called by `graph_axis_map()` and
    `graph_axis_wheel_map()`, with the digital branch written correctly
    (`ypos1`/`ypos2` + `DS_Y`, inverted by `DG_Y` — keep the forward and inverse
    transforms consistent or the map is self-inconsistent).
    ⚠ Two test lessons paid for in blood there:
      * write the three branches into LOCALS and assign the out-parameters once
        at the end. A line beginning with `*` is skipped by the `count_code`
        tripwire (it looks like a C comment continuation), so `*e1 = DS_Y(...)`
        made the digital branch **invisible to its own source-level leg**;
      * a **FORWARD** drag cannot see which window the map used at all.
        `graph_axis_map`'s forward branch is `lo = A + ua*R` with
        `ua = (q - A)/R`, which collapses to `lo = q` for ANY `[A, B]`. Only the
        REVERSE branch (`R/|s|`) depends on the window. Measured: a forward-drag
        digital leg stayed green with the whole digital branch deleted.

    Spec: `doc/claude/specs/waveform_viewer_modes.md` §17 (+ §12.1 and §15.1);
    decision doc `doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md`;
    issue `doc/claude/issues/0190-axis-region-drag-zoom.md`.
    Suite: `tests/headless/test_wave_axis_zoom.tcl` — `AZ*`/`AM*`/`AV*`/`AL*`/`AS*`
    both arms, `AG*`/`AX*` display.

48. **A WHEEL event over a graph NEVER reaches the binding table.** (issue 0191,
    2026-08-01.) `handle_button_press()` (`callback.c` ~7473) opens with the
    inline guard

    ```c
       if(waves_selected(event, key, state, button)) {
         waves_callback(event, mx, my, key, button, aux, state);
         return;
       }
    ```

    and `handle_mouse_wheel()` is only reached **fourteen branches later**
    (~7541). So for any wheel press whose pointer is inside a graph rect,
    `waves_selected()` returns 1, `waves_callback()` runs, and the function
    returns. Three consequences, all of which cost time to discover:

    * the four `ACTX_OVER_GRAPH` wheel rows seeded in `init_input_bindings`
      (~4807) are **unreachable dead code**. `handle_mouse_wheel` computes its
      `ctx` from the same `waves_selected()` that already declined, so `ctx` can
      only ever be `ACTX_CANVAS` by the time `dispatch_input_action()` runs.
      **A binding row is not a way to add or change an over-graph wheel
      gesture** — the arm has to go inside `waves_callback`;
    * three source comments said otherwise and all three are now corrected:
      `callback.c`'s binding-table comment ("Ctrl-wheel … stays canvas pan",
      true only OFF a graph) and `wave_viewer.tcl`'s ("Ctrl+wheel is hard-pinned
      to CANVAS zoom (callback.c:4417)", wrong on both counts and citing a line
      that no longer exists);
    * MEASURED, embedded graph, `graph_use_ctrl_key = 0`, each chord fired as
      `xschem callback .drw 4/5 <px> <py> 0 <4|5> 0 <state>`:

      | chord | plot BODY | bottom (X) margin | left (Y) margin |
      |---|---|---|---|
      | plain | graph X **pan** ±0.05·gw | graph X pan | graph Y **pan** ±gh/divy |
      | Shift | graph X **zoom**, anchored, ×0.8 in / ×1.2 out | same | graph Y zoom, anchored |
      | Ctrl (before 0191) | graph X pan — **byte-identical to plain** | graph X pan | graph Y pan |

      `xorigin`/`yorigin`/`zoom` never moved in any of the twelve trials: **the
      canvas is not involved at all once the pointer is over a strip.**

    The corollary for "leave X unchanged" requirements: *unchanged* has to be
    asserted against the MEASUREMENT, not against the comment, or the regression
    witness passes vacuously. And a new modifier arm in that chain owes the older
    arms an explicit stand-down flag (`wheel_axis_done`) — they are a DIFFERENT
    if/else chain in a DIFFERENT loop (the master block vs the per-graph loop
    below `finish:`), so an `else if` does not exclude them.

    **A modifier guard in the master block can be load-bearing and still leave
    every window byte-identical.** Measured while closing 0191's `!(state &
    ShiftMask)` hole: with the term deleted, a Ctrl+Shift wheel in the **X**
    margin runs the new arm, applies through `graph_axis_zoom()` *and* leaves the
    same numbers behind, because the per-graph loop below opens with
    `gr->gx1 = gr->master_gx1; gr->gx2 = gr->master_gx2;` (~1932) — values
    captured in the master block **before** the arm ran — and the Shift arm then
    overwrites `x1`/`x2` from those pre-zoom values. The **Y** margin is the
    opposite: `setup_graph_data(i, 1, gr)` skips only x, so `gy1`/`gy2` are
    re-read from the tokens the suppressed arm just wrote and the double apply
    *is* visible. So a guard on an X-writing arm here can only be witnessed by
    something other than the window — the replay LOG (`graph_axis_zoom()`
    self-logs one line) is the assertion that sees it, and that also makes the
    guard load-bearing for replay fidelity.

    **AND THE PROBE PIXEL: the plot box's CENTRE cannot witness an ANCHOR.**
    (Second repair pass, 2026-08-01 — the same file, the same helper, the same
    afternoon.) `test_wave_axis_zoom.tcl`'s `az_xmargin`/`az_ymargin` return a
    margin pixel whose ALONG-THE-AXIS coordinate is `(bx1+bx2)/2` /
    `(by1+by2)/2`, i.e. the box centre, u = 0.5. At u = 0.5 the anchored form
    `lo = q - u·R2` and a zoom about the window's centre `lo = A + (R-R2)/2`
    produce the SAME two numbers, so a gesture leg fired there can only ever see
    the new window's **width**. Every Y-margin leg in the file sat on that pixel
    (the X legs did not, and carried an explicit teeth leg saying why), and the
    result was that **two one-token sabotages of shipped source left all 361
    checks green**: `double p = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;`
    → `... : (double)mx;` in the C arm (0.24 off, 12 % of the range) and
    `axis_wheel_window $token $t y $py $wdir` → `... $px $wdir` in
    `wviewer::wheel_zoom`'s y arm (0.20 off). A leg that asserts only a
    magnitude — a width, "the other axis did not move", "the other strip did not
    move" — survives an arbitrarily wrong anchor. Assert **both endpoints**
    (byte-equality with the primitive's own getter for the pixel the gesture was
    fired at) **and** the fixed point, from an **off-centre** pixel, with a teeth
    leg asserting it IS off centre. Those two helpers keep returning the centre
    (correct for a REGION leg) and now carry a ⚠ block; `cv_yprobe` takes a LIST
    of candidate heights, off-centre first, because — MEASURED — which heights of
    the left margin `graph_axis_at` claims depends on the layout of the moment
    (`graph_legend_at` declines first for the legend's own band), and a single
    0.25 height found nothing at all on strip 1 about 1 run in 3.

49. **A multi-object viewer gesture FOLDS the pure primitive and owes ONE of
    everything — and the one term a naive fold gets wrong is per-SOURCE**
    (2026-08-01, issue 0192, the multi-trace drag to a strip). Four reusable
    lessons.

    **(a) The index adjustment is per SOURCE GRAPH, not global, and only a
    non-adjacent multi-index fixture can see it.** `move_traces_in_graphs`
    normalises its `{gi ti}` pairs (integers, in range, deduped, ascending, and
    every pair whose `gi` is already the destination DROPPED) and then folds the
    shipped `move_trace_in_graphs` over them with

    ```tcl
      set graphs [wviewer::move_trace_in_graphs $graphs $gi [expr {$ti - $done($gi)}] $to_gi]
    ```

    where `done(g)` counts the members already moved out of **that same** graph.
    Drop the term and moving model indices **0 and 2** of a four-trace strip
    silently moves the trace that was at **3** — no refusal, no error, the wrong
    data on screen. Moving 0 and 1, or two traces from two different strips,
    cannot tell the two implementations apart, so the fixture has to be
    non-adjacent AND same-source (`MV8`, `SAB-4`). The reverse mistake —
    removing highest-index-first, which `delete_in_graphs` does (0176 D6) — is
    equally valid arithmetic but produces the wrong ARRIVAL ORDER, which is
    `SAB-9`.

    **(b) One gesture owes ONE undo point, ONE regenerate and ONE log line, and
    the line carries the NORMALISED indices.** The same rule landmine 46(c)
    records for the marker delete, arriving from the model side: fold on the
    **PURE** layer so no intermediate state is ever snapshotted, `push_undo`
    once immediately after `capture_live_graph_state`, target remapped **in
    place** (never through `set_target_strip`, which would emit a second replay
    line for an internal consequence), and log the pairs that were actually
    APPLIED rather than the caller's raw list — a replay of the raw list could
    re-derive a different move once a pair had been dropped.

    **(c) A shipped log line is a REPLAY CONTRACT; keep the singular form.** The
    drop dispatches: exactly the pressed trace ⇒ the shipped
    `wviewer::move_trace`, anything else ⇒ `move_traces`. Routing the single case
    through the new verb would rewrite a line that `TD1`/`TD2`/`TD7` assert
    verbatim, that `MG15` drives, and that every action log already on disk
    contains. Four lines of dispatch buy "today's behaviour, unchanged" by
    construction instead of by inspection.

    **(d) The transient CHROME becomes a set the same way the selection did.**
    `xctx->graph_preview_scale/_gi/_wave` stayed as the HEAD and gained
    `graph_preview_set_gi[]`/`_set_wave[]`/`graph_preview_n` beside them — FIXED
    arrays (`xctx` is reset, not freed), ONE writer (`graph_preview_arm`, which
    also owns the disarm), ONE draw-side predicate (`graph_preview_has`, the
    `wave_is_hilighted`/`graph_marker_is_selected` shape). `Graph_ctx.preview_wave`
    became `preview_gi`, *the rect index this draw may preview*, still defaulted
    above the `RECT_OUTSIDE` return (landmine 11). Because the head keeps its
    meaning, `xschem get graph_preview` is byte-identical and the whole set is
    read through a NEW getter — the compatibility rule that made 0189 cheap.
    ⚠ And the same invisibility trap: with **one** carried trace a bare
    `preview_gi == wcnt` and the predicate agree exactly, so the one-site rule is
    asserted at SOURCE level (`DM6`), including that the predicate matches on
    **both** the `gi` and the node index — that `gi` term affects pixels only and
    is unreachable by any behavioural leg.

    **(e) A gesture's REFUSAL must be computed from the same predicate as its
    COMMIT — and a shorthand for "nothing would happen" outlives its truth.**
    `trace_drag_drop` shipped with `!$active || $to < 0 || $to == $from` guarding
    the drop, a guard inherited verbatim from the SINGLE-trace gesture where
    "the destination is the strip I pressed on" and "nothing would move" are the
    same statement. Once the gesture carries a SET they stop being the same, and
    the shorthand silently refused a whole legal gesture (a selection spanning
    strips, dropped back on the pressed one) while the design doc, the spec and
    PLAN.md all described it working. The repair is one PURE predicate —
    `movable_pairs {pairs to_gi}`, the carried pairs whose `gi` is not the
    destination — read by the drop, by the refusal AND by the `reorder_handle=4`
    frame, so the frame can never promise a move the release refuses. Generalise:
    when a gesture goes from one object to N, re-derive every early-return term
    from the SET; a term that reads an attribute of the pressed object
    (`$to == $from`, `$gi`, `$ti`) is the suspect. The frame also needed
    `tdrag_to` to start at `-1` rather than at the pressed index — a "current
    value" seeded from the press suppresses the first real change event.

    **(f) A gesture fixture where two INDEX SPACES coincide tests neither.** The
    `MM*` fixture originally carried no vec-less trace, so MODEL index == NODE
    index on every strip and the whole crossing chain — `trace_at` (NODE) →
    `trace_index_of_node` → `selection_pairs` (MODEL) → `move_traces` (MODEL) —
    passed with an identity mapping. Measured: `selection_pairs` sabotaged to
    use the node index as a model index left that suite `ALL PASS (381)`; with
    one vec-less trace planted at MODEL index 1 of strip 0 the same sabotage
    kills **13** legs, and `MM7`'s log line (`move_trace 0 2 2`, node 1 = model
    2) becomes a witness of the crossing on its own. The pure legs having
    covered the divergence (`MV10`, `DM0`/`DM3`) is NOT the same cover: they
    exercise the fold and the arm, never the gesture end to end.

    ⚠ **What the arm decides, it decides at PRESS time.** The release is
    forwarded to C *before* `trace_drag_drop` runs, and a no-travel release
    collapses the selection to the clicked trace (issue 0174 D3). A drop-time read
    would appear to work — because the drag travelled — and would be a
    coincidence, not a contract. Measured before the design was fixed: a press
    alone never changes the selection.

    Spec: `doc/claude/specs/waveform_viewer_modes.md` §19 (+ the §15.1 ownership
    row) and the item-6 revision block in `doc/claude/specs/waveform_viewer.md`;
    issue `doc/claude/issues/0192-multi-trace-drag-to-strip.md`.
    Suites: `test_wave_modes.tcl` `MV*` (both arms), `test_wave_drag_preview.tcl`
    `DV8`-`DV12` + `DM*`, `test_wave_trace_menu.tcl` `MM*` (display).

50. **A `regenerate` that carries the current strips forward MUST fold the live
    rect state back first — "it is only a window option" excuses `push_undo`,
    never the capture** (2026-08-01, issue 0194).
    Ctrl-G deselected the selected trace, and the same defect sat on eleven
    other commands.

    **(a) The mechanism, and why no behavioural leg had ever caught it.**
    `wviewer::regenerate` does `xschem clear_drawing` and re-places every graph
    rect purely from `graph_props`, i.e. from the Tcl MODEL. The selection is
    not in the model: `graph_sel_waves_set` (`draw.c`) writes `hilight_wave` +
    `sel_waves` straight into the rect's `prop_ptr` and nothing pushes them back
    — 0175 deliberately declined the marker-style C→Tcl hook, on the grounds
    that losing view state on a resize is "a cosmetic annoyance". A one-key
    gesture is not. `clear_drawing` keeps no selection anywhere in `xctx`
    (`graph_struct.hilight_wave` is scratch, refilled by `setup_graph_data`), so
    the answer is total: after a non-capturing regenerate the selection is GONE.

    **(b) The rule, applied to all 22 call sites.** Capture when the model you
    hand to regenerate is meant to carry forward the strips that are on the
    canvas *now* — whether the command is a window OPTION (`grid_toggle`,
    `sharedx_toggle`), a pure repaint (`configure_apply`, i.e. a plain window
    RESIZE), a view gesture (`wheel_zoom`, `pan_x`, `apply_range`, `axes_ok`), a
    data swap (`attach_raw`, `display_raw`) or a structural add (`add_trace`,
    `add_graph`, `plot_signals`). Do NOT capture in the three that replace the
    model wholesale — `restore`, `state_apply` (its caller `history_step`
    captures, and capturing inside would fold pre-undo rect state on top of the
    snapshot being restored) and `clear_all` — nor in `delete_all_markers`,
    which must not regenerate at all (the landmine in that proc's own header).
    The seven content gestures that already captured keep the FULL capture.
    ⚠ `push_undo` is a SEPARATE question and the two must not be bundled: window
    options stay outside the undo stack (spec §14), so `grid_toggle` and
    `sharedx_toggle` capture and do not push. Adding a push would make Ctrl-G
    undoable, which nobody asked for and which an existing leg forbids.
    ⚠ **The rule is about `regenerate`, not about `wave_viewer.tcl`.** A 13th
    site lives in `ase_window.tcl` (`ase::ui::auto_plot`'s no-plottable-rows
    branch calls `wviewer::regenerate $key`), and BOTH a file-scoped audit and a
    source leg matching `regenerate \$token` walk straight past it.

    **(c) The fold must not write the RANGES AT ALL — hence `skip_ranges`,** and
    a capture that "only refreshes an already-pinned axis" is not a safe middle
    ground. Two independent failures:
    *pinning.* `graph_props` always emits a concrete `x1/x2/y1/y2` (substituting
    a placeholder for a model `{}`) and regenerate's autozoom overwrites them
    with the fit, so `xschem getprop rect 2 $gi x1` is NEVER empty. Capturing
    unconditionally on a RESIZE converts every `{}` axis — "autozoom on every
    regenerate" — into a frozen number for every strip, empty ones included, and
    the next Direct Plot into an auto strip lands off-screen.
    *Shared X.* `regenerate` forces graph 0's x onto every other strip's RECT
    when `sharedx 1`, in a LOCAL list, so the model keeps each strip's own — that
    is what makes un-sharing non-destructive. Refreshing a pinned axis off the
    rect therefore copies graph 0's window into every strip's model permanently,
    with no undo point, and turning Shared X on and straight back off silently
    destroys every per-strip x window. This one survived the first round of
    review-by-reading and was caught only by executing the sequence with a
    control.
    So `wviewer::capture_live_view_state` = capture with `skip_ranges 1`: the
    selection (and markers) fold, the axes are not touched, and range lifetime
    stays exactly what spec §17.4 says it is. The flag gates the RANGES ONLY —
    gating the selection with it would reinstate the whole bug and would read
    identically in a single-strip test.

    **(d) The witness rules this bug class needs.** `hilight_wave` is per-RECT,
    so a leg that reads only the strip it clicked cannot see a selection wrongly
    surviving — or wrongly appearing — on its neighbour; read EVERY strip.
    Select on a strip that is not 0 and a node that is not 0 (`atoi("")` reads a
    destroyed token as node 0, so a strip-0/node-0 witness passes on the bug).
    Plant the selection on the RECT, never through the model: a model-side plant
    survives a regenerate whether or not the fix is present, which is
    green-but-hollow by construction. And use a MULTI-trace selection — a
    head-only fold passes every single-selection leg (measured: sabotage SAB-3
    left the single-selection leg green and killed only the multi ones).

    Spec: `doc/claude/specs/waveform_viewer_modes.md` §15.5 (+ §14) and the
    Ctrl-G section of `doc/claude/specs/waveform_viewer.md`; issue
    `doc/claude/issues/0194-ctrlg-grid-toggle-deselects-trace.md`.
    Suite: `tests/headless/test_wave_grid.tcl` `GX*` (source, both arms) and
    `GS*` (behavioural, display).

51. **A gesture cursor written ONCE is a cursor you do not have — the viewer
    canvas has three other writers and every one of them runs later**
    (2026-08-02).
    `hand2` (trace drag) and `sb_v_double_arrow` (strip reorder) were each a
    single `catch {$W configure -cursor ...}` made at the moment the gesture
    engaged. Two clobbers were then measured on a real XTEST pointer with
    XFixes sampling the server-side sprite:

    **(a) The sub-threshold dead zone.** Below the 3-px tolerance the
    `<B1-Motion>` seam DECLINES the event on purpose — it still belongs to the
    C engine (hover readout, an in-flight cursor drag, a press that may still
    turn out to be a wave-bold click). So the binding forwards it,
    `waves_selected()` finds the pointer inside a graph rect and writes
    `.drw configure -cursor tcross` (`callback.c:201`) over the hand
    `trace_drag_arm` set on the press. Measured 3× per drag; at 125 Hz the
    first lands ~8 ms after the press, so the press-time affordance that proc's
    own header promises was effectively invisible.

    **(b) Leaving the canvas mid-drag.** `<Leave>`/`<Enter>` are in
    `wviewer::keepseqs`, so they still reach C: `callback.c:8637` writes
    `-cursor {}` UNCONDITIONALLY on LeaveNotify and `handle_enter_notify`
    (`callback.c:5566`) writes `{}` again coming back in (a viewer is
    `no_snap`, so the crosshair arm is dead). During the implicit button grab
    the pointer still displays the canvas's cursor, so a drag that crossed the
    edge — toward the top strip, over the readout bar, an overshoot — lost its
    pointer for the whole rest of the gesture. This one the seam cannot see at
    all: it is happily CONSUMING every motion while C erases the cursor
    underneath it.

    **The fix is a MAINTAINED INVARIANT, not a third write.**
    `wviewer::drag_cursor_reassert` runs from the `<B1-Motion>` binding
    unconditionally (outside the seam test, because the two clobbers live on
    opposite sides of it) and costs one `cget` per motion. It re-asserts only
    what an ARMED Tcl gesture owns — the arms are tested, never the widget — so
    a C-owned cursor grab / marker drag / axis-region zoom / plain click keeps
    `tcross`, which is the correct affordance for a graph. Do NOT "fix" this in
    `waves_selected()`: that write is shared with embedded schematic graphs and
    is half of a pair with the `!is_inside` restore at `callback.c:227-232`.

    ⚠ Related, and the reason `set_drag_cursor` exists: all five cursor writes
    were bare `catch`es. `catch` is right (a cursor is cosmetic and must never
    abort a drag) but it means a cursor-theme miss produces "the pointer never
    changes" with every other part of the gesture working perfectly —
    indistinguishable from a logic bug, and it costs a session to diagnose. It
    now says so once per window per session.

    Suite: `tests/headless/test_wave_viewer.tcl` `TD8` (dead zone), `TD9`
    (Leave/Enter + the negative "nothing armed" leg) and `SD6` (the reorder arm,
    driven by a DIRECT call and labelled as such — no shipped path forwards a
    past-threshold reorder motion to C).

---

## 12. Improvement backlog (ranked, with where-to-touch)

Effort: S=hours, M=days, L=weeks. Impact in caps.

> **ALREADY FIXED — do not "re-fix", and do not undo.** Four pre-existing defects
> in the trace pickers were fixed as prerequisites of the waveform-marker work
> (2026-07-28), because `graph_point_at()` is a refactor of `graph_wave_at` and
> would otherwise have inherited all four verbatim. Bugs 1 and 2 were fixed in
> **both** pickers, and `find_closest_wave`'s node loop now carries a "keep the
> two in sync" comment — if you touch one, check the other.
> 1. **Infinite loop when a graph's FIRST `node` entry is a bus.** The bus
>    `continue` fired *before* `nptr = sptr = NULL`, and `my_strtok_r` re-seeds
>    from the head of the string whenever `str != NULL` — so the same bus token
>    was returned forever. Both the sweep-token consumption and the NULLing now
>    happen **above** the bus test. Symptom was a hang, not a wrong answer.
> 2. **A bus entry did not consume its `sweep` token**, so every trace *after* a
>    bus was measured against the previous entry's sweep variable. Same edit
>    fixes it; `draw_graph` has always consumed the token for every entry, bus
>    included, which is why the draw and the pick disagreed.
> 3. **`extra_rawfile()` was switched PER NODE but restored ONCE**, so on a graph
>    with ≥ 2 non-bus nodes the trailing `extra_rawfile(5, ...)` unwinds only one
>    level of the switch. `rawfile`/`sim_type` are GRAPH-level tokens, so
>    `graph_point_at` now makes the single switch **before** the node loop, and
>    unwinds it only when the switch actually took (landmine 40).
>    **Still open in `find_closest_wave`**, which keeps its per-node call
>    (`draw.c` ~4418 + ~4445, one restore at ~4563 gated on intent rather than
>    success) — an identical hoist plus a `switched` flag there is a small,
>    self-contained follow-up.
> 4. **`find_closest_wave` read an uninitialised `ofs_end`.** `int p, dset, ofs,
>    ofs_end;` had no initialiser, `if(node_dataset != -1 && node_dataset !=
>    dset) goto done;` jumped **over** the `ofs_end = ofs + npoints[dset];`
>    assignment, and `done:` is `ofs = ofs_end;`. On `dset == 0` that is an
>    uninitialised read and thereafter a stale one. `ofs_end` is now computed
>    **before** the dataset-skip `goto`. `graph_wave_at` always had this right.

0. ~~**[S · MED] Fix `xschem resolved_net`'s first-call contamination.**~~
   **DONE — issue 0155.** Fixed at the source instead of per call site
   (`Tcl_ResetResult` at the tail of `prepare_netlist_structs`, `netlist.c`),
   because the per-site remedy had already leaked: c99beb26 patched `net` /
   `nets` / `net_members` and missed `resolved_net`, `list_hilights` **and
   `instance_nodemap`** (the third site was not in the 0154 report). See
   landmine 24 for the two masks that hid it. Also **DONE — issue 0157**:
   `resolved_net` **truncated a bus at a global element** (`:2654` `my_strdup2`
   replaced where `:2656` `my_mstrcat` appends — `{D,GND}` → `GND`, and in fact
   `{A,B,GND,VCC}` → `VCC`); the global branch now appends without the `path2`
   prefix. See landmine 25. And **DONE — issue 0158**: its `#` strip ran once on
   the whole token before `expandlabel` (`:2602`), so it **leaked on non-first bus
   elements** (`{D,#net1}` → `D,#net1`, and descended `{LOC,#x}` → `X1.LOC,X1.#x`);
   the strip is now per element inside the loop. See landmine 26. And **DONE —
   issue 0163**: the attribute-resolution lookup at `:2630` was unguarded, so
   **any** instance attribute whose name matched a child net name replaced it
   (measured: child net `value` + instance `value=1k` → `1k`; `spice_ignore` →
   `false`; `name` → `X1`), and a `#` in such a value was never stripped
   (`LOC=#foo` → `#foo`). It is now gated on the parent symbol's `extra=` list —
   the one channel that declares an attribute to be a NODE. The accepted value
   is NOT stripped: a `#` strip shipped with 0163 and was reverted once measured
   (see the "corrected in 0163" note below, and landmine 29 rule (c)). A sweep of every
   committed design found 932 attribute/net collisions, 926 of them declared
   `extra=` bindings (the feature) and 6 stray, with **zero** accidental
   `value`/`m`/`model` hijacks; netlist output over 201 stock designs is
   byte-identical across the fix. And **DONE — issue 0164**: the loop read only
   `prop_ptr` and never the symbol TEMPLATE, so an instance that omitted an
   `extra=` attribute and relied on its template default resolved to `X1.VCCPIN`
   where the netlist said `VCC`; it now falls back to `hier_attr[].templ` exactly
   as `translate()` does. Also **corrected in 0163**: the `#` strip that shipped
   on the accepted value was reverted — measured, an `extra=` value reaches the
   subckt call line verbatim and ngspice names that node `#hfoo`, a *different*
   node from the `hfoo` a wire labelled `#hfoo` produces. See landmine 29.
1. **[S · MED] `xschem get graph_flags` + cursor getters.** *(PARTIAL:
   `xschem get graph_flags` now exists — added 2026-07-27 so the viewer's LMB
   drag-reorder seam can tell a cursor grab from empty space, `scheduler.c`
   `get` dispatch case 'g'. The cursor-POSITION getters that would let
   `wave_viewer.tcl` drop the `cva`/`cvb`/`cvr` mirrors (~136) are still open.)*
   *Best ratio.*
2. **[S · MED] Cache per-dataset offsets on `Raw`.** Prefix-sum of `npoints[]`
   at load (`raw_read` ~1002, struct ~953); index it in `get_raw_value`
   (~2323) instead of re-summing per fetch. Hot-path win, no model change.
3. ~~**[S · MED] Fix `raw_deletevar` realloc sizing.**~~
   **DONE — 2026-07-28, with the waveform-marker work** (`save.c` ~1126).
   `sizeof(SPICE_DATA *) * raw->nvars + 1` → `sizeof(SPICE_DATA *) *
   (raw->nvars + 1)`: an operator-precedence bug, not an off-by-one. `values`
   carries `nvars+1` columns, the last being the scratch column custom-wave
   expressions are evaluated into (landmine 1), and the buggy form asked for
   `8*nvars + 1` **bytes** — truncating that slot away. The next `raw add` then
   grew the array back and wrote into what had been uninitialised memory:
   valgrind "Invalid write of size 8" in `plot_raw_custom_data` ←
   `raw_add_vector`, then SIGSEGV. It survived under plain glibc only because
   the shrinking realloc happened to stay in place, which is why it sat here as
   a *latent* item for so long. Pre-existing (upstream 7a45497b); it surfaced
   now because `tests/headless/test_wave_markers.tcl` is the tree's **first and
   only caller of `xschem raw del`**. The fix carries a comment at the call site
   naming this backlog item — leave it there.
4. **[S · LOW] Bound bus-value buffers** (`draw.c` ~3229 `busval`/`old_busval`,
   `get_bus_value` ~2784) by `n_bits` instead of fixed 1024.
5. **[S · LOW] Trace-list integrity check** — when writing `node`/`color`/
   `sweep` (`graph_add_nodes_from_list` `xschem.tcl` ~4312; `setprop rect`
   special tokens `scheduler.c` ~10500), warn/pad on length mismatch.
6. **[M · MED] Propagate RPN eval errors** out of `raw_add_vector`/
   `plot_raw_custom_data` (`save.c` ~971/1821) through `xschem raw add`. Lets
   `wave_viewer.tcl validate_rpn` (~600) be deleted.
7. **[M · HIGH] Graph coordinate / legend hit-test verb** *(PARTIAL: `xschem
   graph_coord` now returns data coords for a pixel, issue 0146; the rect-bbox
   read-back + legend hit-test that would delete `graphbb` are still open.)* — extend
   `xschem object rect` (or add `xschem graph bbox`/`graph hit`) to return
   `x1/y1/x2/y2` + legend-entry hit, reusing `edit_wave_attributes`
   (`draw.c` ~4129) / `setup_graph_data`. Eliminates `graphbb` (~103) and
   enables canvas legend click-select/delete.
8. **[L · HIGH] Decimation.** When samples > plot-box horizontal pixels,
   reduce to a per-pixel min/max envelope before filling `XPoint[]` in
   `draw_graph`'s inner loop (~4550+) / `draw_graph_points` (~3302). **Largest
   perf win**, but touches the core loop and must preserve wrap/window-split
   + cursor-measure semantics. Weeks.
9. **[L · MED] True vector SVG/PS export** — replace the pixmap-capture in
   `svg_embedded_graph` (~5536) / `ps_embedded_graph` (`psprint.c` ~253) with
   a `draw_graph` variant emitting vector primitives.

---

## 13. Testing waveform work

- Headless raw/graph/viewer coverage lives in `tests/headless/`:
  `test_ase_plot.tcl` (Direct Plot; `PL` = the `-layer` highlight verbs),
  `test_wave_viewer.tcl` (`WB` = the LMB wave-bold gesture, issue 0152, plus
  `WB-mmb-drag` = the pan on its new button; `SD*` = the LMB seam between the C
  engine and strip drag-reorder — trace-proximity in screen pixels, cursor-grab
  exclusion, empty-space drag; **`TD*` = dragging a TRACE between strips**,
  2026-07-28 — real raw + full Tk press/motion/release, with an inert `sdid` key
  per strip so "which strip is at index k" is witnessed independently of "which
  trace is in it", the only way to tell a trace move from a strip reorder on a
  two-strip stack; `TD7` = drag a trace then press `u`/`U`, the undo user story
  end to end),
  `test_wave_modes.tcl` (plot modes / target strip, issue 0151; `M6`/`MG6c`/
  `MG6d` = the trace-color policy, issue 0153; **`M7`/`MG14` = strip
  drag-to-reorder**, 2026-07-27 — `M7` is pure list/index math, `MG14` drives the
  real Tk press/motion/release through the shipped bindings and pins the log
  shape; the LMB seam itself is `test_wave_viewer.tcl` `SD*`, which needs a raw;
  `M8`/`MG15` = the same split for the TRACE move, 2026-07-28 — `M8` pure
  (list move, node/model index mapping, hilight remap, empty-destination range
  blanking), `MG15` the `move_trace` mutation against real rects, no raw needed;
  **`MV*` = the MULTI-trace move**, 2026-08-01 issue 0192 — the PURE fold, both
  arms: source order, cross-strip sources, `gi == to_gi` dropped, dict identity,
  the SELECTION as a set, marker migration + the window-wide dangling-`prev`
  check, the refusals, dedupe, and **`MV8`, the index-adjustment teeth** (moving
  model indices 0 and 2 of FOUR — 0 and 1 cannot discriminate);
  **`MG16` = undo/redo of viewer edits**, 2026-07-28 — history semantics,
  live-state survival, the depth cap, `restore` clearing it, and the real `u`/`U`
  keys with the rc-remap and `{break}` contracts),
  `test_wave_clear_all.tcl` (`CA*`/`CG*` = Clear All + the `WaveViewer`
  bindtag, issue 0171; `CG6` pins the rc-remap contract — rc wins, `{break}`
  disables — `CG4` that the tag survives a `strip_bindings` re-sweep, and `CG8`
  that the cleared strip is REUSED by the next plot batch; the policy itself is
  `test_wave_modes.tcl` `M3`/`M3b`),
  `test_ase_unnamed_net.tcl` (`AN*` = picking/naming of auto-named `#netN`
  nets, issue 0154 — hermetic, writes its own fixture, needs no DISPLAY,
  ngspice or ASE session),
  `test_resolved_net_bus_global_0157.tcl` (`RB*` = `resolved_net`'s bus
  accumulation and the flat-global rule, issue 0157 — builds its own two-level
  hierarchy in `test_scratch`, has teeth in both arms),
  `test_resolved_net_hash_bus_0158.tcl` (`HS*` = the per-element `#` strip and
  why it stays loose, issue 0158; `HS0` reads the auto-net name out of
  `xschem nets` rather than hardcoding `#net1`),
  `test_ase_bus_bits_0159.tcl` (`BB*` = the Select Bus Bits dialog, the
  `sod_bits` split and the legacy-state migration, issue 0159; the dialog and
  real-click groups self-SKIP without a DISPLAY),
  `test_wave_markers.tcl` (waveform markers,
  `doc/claude/specs/graph_markers.md` — **NOT YET COMMITTED as of 2026-07-28**:
  the C and Tcl sides shipped ahead of it, so until it lands the marker legs of
  the three suites above are the only cover. Three groups, split by what they
  need, because the file must still be useful under `--nogui`:
  **`MK*`** = no DISPLAY, no raw — pure Tcl (`markers_valid`/`_decode`/
  `_encode` round trips incl. a 17-significant-digit `x`, the `{}`→0 contract,
  rejection of `"`/`\`/`;`/`tcleval(`/`nan`/`inf`/8-field/tab, 10-field forward
  tolerance, `markers_drop_number` and the cross-strip `prev` sweep, both node
  remaps, `graph_props`'s four emission arms, snapshot/restore purity) **plus**
  pure C token math through `setprop`/`getprop`/`graph_marker list` and the
  window-wide number allocator, **plus** the two hang/UB regressions the
  refactor fixed (a graph whose FIRST `node` entry is a bus must RETURN, and a
  `%<n>` dataset selector that skips dataset 0 must be stable), **plus** all
  four getters under `--nogui` asserting no crash;
  **`MR*`** = a raw + a graph, no gestures (hermetic `xschem raw new`/`raw add`,
  never ngspice) — create/delete/renumber, snap-to-a-real-sample, delta text,
  the EXPRESSION-trace read (the leg that pins `plot_raw_custom_data`'s dataset
  window; a bare `get_raw_value` reads the global volatile scratch column),
  `regenerate` **and window-resize** survival (the leg that proves the PUSH
  hook, not just the capture), viewer undo removing the marker from the **rect**
  as well as the model, file save/load precision, paste renumbering with a
  **two**-record rect, C undo/redo on both `undo_type`s, and every refusal;
  **`MX*`** = full Tk press/motion/release under a real DISPLAY — `m`/`d`/`M`
  key behaviour and the bit-64 collision witness, click-to-select vs the
  wave-bold, anchor drag vs label drag (assert **both** halves of each: the
  thing that changed AND an inert witness that did not), the top-edge label drag
  that regressed the `graph_top`/GRAPHPAN fix, the reorder grip still working
  with a marker present, B2/B3 chord suppression and stale-arm teardown, ESC
  cancel, `Delete` scoping, and viewer `u`/`U`.
  **`MF*`** = one named leg per post-review fix (spec §11's hardening table).
  Most are data-addressable and run in BOTH arms: the restricted-walk anchor
  move on a graph whose `sweep` list is shorter than its `node` list
  (landmine 38), a `>512`-record token surviving a mutating op intact, a
  multi-raw graph committing the *graph's* value AND refusing outright when the
  graph's `rawfile=` does not resolve, a partial `delete -all` leaving no
  dangling `prev`, `xschem get graph_marker_at` not disturbing `graph_flags`
  128\|256, delete-after-reorder finding the right strip, the `c`-key copy
  producing unique numbers, `clear_drawing` dropping the selection, and
  `xschem draw_graph` surviving `--nogui`. The display half covers the
  stale-arm-at-press teardown (it reproduces solely through a modifier-held
  ButtonRelease, the case Tk never delivers to C), the read-only refusal on
  both the key path and the drag-commit ops, and the viewer still working
  through `with_edit` at both seams — `key_filter` for the keys,
  `strip_drag_release` for the release. Two things are deliberately NOT
  asserted and say so in the legs' own comments, because no verb can observe
  them: the drag readout tracking the anchor rather than freezing, and the
  repaint scope of a cross-strip selection change. Both are eyeball-only.
  **`MZ*`/`MA0`** = the harness's own invariants: an erroring leg FAILS rather
  than aborting the file, the run asserts its expected check count so silent
  coverage loss is itself a failure, and the run asserts the environment it
  believes it is in),
  `test_ase_*` family. They
  `--pipe`/`--script` the built binary and diff against golden state. Pure
  Tcl helpers in `wave_viewer.tcl` (`graph_props`, `band_geometry`,
  `next_color`, `validate_rpn`, `interp_value`) are directly unit-testable.
- **`tests/headless/test_flylines.sh` is run by NOTHING.** `full_audit.sh`
  globs `test_*.tcl`; this one is a `.sh`. It owns the 43 fly-line rails —
  including the three `A6` ones that pin the auto-named-net exclusion the ASE
  picker must not relax (issue 0154). Run `sh tests/headless/test_flylines.sh`
  by hand after any flyline or picker work.
- **Green ≠ correct** — sabotage-verify that the changed C actually ran (see
  memory `green-but-hollow`). A graph test that never loaded a raw passes
  while drawing nothing.
- Gesture tests must replay the **full Tk event sequence** in the shipping rc
  (memory `gesture-test-full-sequence`) — a lone synthetic event passes while
  the feature is broken. And **stamp `-time` on every synthetic button event**:
  two identical `event generate <ButtonPress-N>` calls close together are
  collapsed by Tk into `<Double-Button-N>`, which the viewer binds to `{break}`,
  so the second press never reaches C at all (issue 0152; `wb_ev` in
  `test_wave_viewer.tcl` is the pattern). A generated **KeyPress** needs a
  `focus -force $canvas; update` first: it is delivered to the FOCUS window, and
  under WSLg the viewer loses focus between legs — without it the Escape-cancel
  legs (`MG14`, `TD5`) silently never reach `key_filter` and fail ~1 run in 2.
  That flake predates the trace-drag work; both legs now force focus.
- `test_nh_angle_*` etc. create per-pid scratch dirs under `[pwd]`; the
  `_*_[0-9]*/` gitignore + end-cleanup pattern is the convention (commit
  `cf57955c`).

---

## 14. Cross-references

- `doc/claude/specs/waveform_viewer.md` — ASE-L viewer feature decisions +
  as-shipped ledger (items 13/14/19). The authority on viewer UX contracts.
- `doc/claude/specs/waveform_viewer_modes.md` — plot modes (single/multi),
  target strip, the active-strip marker and the mode command surface
  (issue 0151), plus strip drag-to-reorder (§12), trace drag between strips
  (§13) and viewer undo/redo (§14).
- `doc/claude/specs/graph_markers.md` — Cadence-style waveform MARKERS: the
  `markers` prop token, the `m`/`d`/`M`/`Delete` keys, the anchor/label drags,
  the full Button1 precedence in both contexts, the `xschem graph_marker` verb
  family and the C→Tcl push hook. The worked example for "a new durable
  per-graph annotation" (§10) and the origin of landmines 35-40, the correction
  to landmine 19 and the fix for backlog item 3 (landmine 1).
- `waveform_display_explained.md` (this folder) — the plain-English tour.
- Memory: `ase-l-plan`, `scheduler-letter-dispatch`, `green-but-hollow`,
  `gesture-test-full-sequence`, `wslg-dialog-open-repaint`.
- `doc/claude/WIRING.md` — the model for this kind of subsystem reference.
