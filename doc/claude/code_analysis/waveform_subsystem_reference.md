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
| `src/draw.c` | **The render engine.** `draw_graph_all`, `setup_graph_data`, `draw_graph`, `draw_graph_grid`, `draw_graph_points`, `draw_graph_bus_points`, `draw_graph_variables`, `draw_cursor*`, `show_node_measures`, `get_bus_value`, `graph_fullxzoom`/`graph_fullyzoom`, `find_closest_wave`, `edit_wave_attributes`, `sch_waves_loaded`, `svg_embedded_graph`. |
| `src/callback.c` | **On-canvas interaction.** `waves_selected` (gate/hit-test), `waves_callback` (gesture engine), `backannotate_at_cursor_b_pos`, the input-binding table (`init_input_bindings`, `act_graph_forward`, `current_input_ctx`, `dispatch_input_action`), and ~11 inline `if(waves_selected){waves_callback}` guards. |
| `src/scheduler.c` | **Tcl verb surface.** `raw`/`raw_query` block, `raw_read`/`raw_clear`/`raw_read_from_attr`, `add_graph`, `annotate_op`, `cursor`, `get graph_lastsel`, `setprop rect` special tokens (fullxzoom/fullyzoom). |
| `src/token.c` | `translate()` `@spice_get_voltage`/`@spice_get_node` → substitutes `cursor_b_val[]` into symbol text (C back-annotation display). |
| `src/xschem.h` | `Raw` struct (~953-976), `Graph_ctx` (~1028-1067), `SPICE_DATA` (`#define` = `double`, ~483), coord macros `W_*`/`S_*`/`DS_*`/`G_*`/`DG_*` (~442-458), `xctx` graph fields (`raw`, `extra_raw_arr`, `graph_flags`, `graph_master`, `graph_lastsel`, `graph_cursor1_x/2_x`, `graph_struct`). |
| `src/wave_viewer.tcl` | **ASE Waveform Viewer** — a real read-only editor window driven by a pure-Tcl model. See §8 and the spec. |
| `src/xschem.tcl` | Sim launch (`simulate`, `execute`), `sim()` array + simconf dialog, native graph editor `graph_edit_properties`, `graph_add_nodes_from_list`, `load_raw`/`waves`. |
| `src/ngspice_backannotate.tcl` | Legacy pure-Tcl `.raw` op reader → `ngspice::ngspice_data`. Largely vestigial; `update_op` writes the same array. |
| `src/create_graph.tcl` | Standalone scripted graph recipe (non-ASE). |
| `src/rawtovcd.c` | **Standalone binary** (own `main`), not linked in. `.raw`→VCD for gtkwave. Has its *own* independent parser. |
| `src/gtkwave_server.tcl` | Optional TCP server (port 2022) for gtkwave→xschem command push. |

---

## 2. Data model

### 2.1 `Raw` — the in-memory dataset (`xschem.h` ~953-976)

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

### 2.2 The registry (`xctx`, `xschem.h` ~1462-1469)

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

### 2.4 `Graph_ctx` — transient render context (`xschem.h` ~1028-1067)

Single shared instance `xctx->graph_struct`. **Rebuilt per graph per draw** by
`setup_graph_data()`. Holds decoded flags, data window `gx1..gy2`, plot box
`x1..y2` (container minus 14% margins), and the cached affine transform
coefficients `cx/dx/cy/dy` (graph→xschem) and `scx/sdx/scy/sdy` (graph→screen
direct), plus digital variants. **Not persisted; do not treat as per-graph
storage** — everything durable round-trips through `prop_ptr`.

### 2.5 The `node` trace mini-language (fragile — read before touching)

`node` is a `"`-quoted, **newline-separated** list, one entry per trace. Each
entry's meaning is set by **punctuation** (parsed in `draw_graph`
~4660-4761 and `find_closest_wave`):

- bare `v(out)` → scalar node
- `,` inside → **bus** (`alias;sig[3],sig[2],...`) → `draw_graph_bus_points`
- whitespace in the post-`;` part → **expression** (`expression=1`) →
  `plot_raw_custom_data` + `eval_expr`
- `alias;expr` → text before `;` is the legend label
- `%N` suffix → select dataset N; `%rawfile%simtype` → select source
- `tcleval([...])` → live Tcl substitution at draw time (scope symbols use it)

`color=` and `sweep=` are **separate, space-separated, positional** lists
indexed against `node`. They can desync silently (tolerated by cycling
defaults; no integrity check). Editing traces = rewriting the whole `node`
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

`draw()` → `draw_graph_all((graph_flags & (2|4)) + 8)` (~4972) iterates
`rect[GRIDLAYER]` with `flags&1`; per graph: `setup_graph_data(i,...)` →
`draw_graph(i,...)`.

- `setup_graph_data` (~3523): reads tokens → `Graph_ctx`; 14% margins; text
  sizes; transform coeffs. **`cy = -h/gh` is NEGATIVE** (xschem/screen Y grows
  down, data Y grows up). Early-returns if off-screen.
- `draw_graph` (~4550): resolves cursor A/B (global `graph_cursor1_x/2_x`, or
  per-rect token if `flags&4`); `draw_graph_grid` under `flags&8`; tokenizes
  `node`; sets a bbox clip (`bbox(SET,...)`, `select.c`); per node, loops
  datasets/samples, detects DC sweep wraps / window-exit to split polylines,
  fills `point[].x = CLIP(S_X(xx), ±30000)`; dispatches to
  `draw_graph_points` (scalar) or `draw_graph_bus_points` (bus); then cursors
  + `show_node_measures`.
- `draw_graph_points` (~3302): fills `point[].y` (analog `S_Y`, or digital
  `DS_Y` band rescale `yy=c+yy*s2`, or `mylog10` for logy), `CLIP`s to short,
  `XDrawLines` to **both** `window` and `save_pixmap`, chunked at
  **`MAX_POLY_POINTS`=65536** (Xlib limit, not perf — last point of each chunk
  repeated as first of next). Modes 1/2 = histogram bars.
- `draw_graph_bus_points` (~3217) + `get_bus_value` (~2784): multi-bit bus as
  two rails + hex labels; per-bit threshold `vthl`/`vthh` (20%/80%); `X` on
  transition. **Fixed 1024-char `busval`/`old_busval` buffers** (fruit #7).
- Cursors: `draw_cursor`/`draw_cursor_difference` (x), `draw_hcursor*` (y),
  `show_node_measures` (~3996) interpolates node value at cursor A.
- Export (raster only): `svg_embedded_graph` (~5536, base64 PNG),
  `ps_embedded_graph` (`psprint.c` ~253, ASCII85 JPEG q40, needs
  HAS_LIBJPEG+HAS_CAIRO). Traces/grid are raw **Xlib**; only text + export
  rasterization use cairo.

**Coordinate macros** (`xschem.h` ~442-458): `W_X`/`W_Y` graph→xschem,
`S_X`/`S_Y`/`DS_Y` graph→screen, `G_X`/`G_Y`/`DG_Y` inverse. **They reference a
local `Graph_ctx *gr`** and assume `setup_graph_data()` ran for the right
graph. Wrong scope / stale `gr` → silently mis-transformed waveforms.

---

## 5. Interaction (callback.c)

- **Pre-emption layer, not a mode.** ~11 inline
  `if(waves_selected(...)){ waves_callback(...); return; }` guards, one per
  event type. A new event path needs the guard added or graphs won't respond
  there.
- `waves_selected` (~65): **side-effectful gate/hit-test.** Skips if a
  schematic gesture is pending (STARTZOOM/RECT/WIRE/MOVE/... mask), if
  `graph_use_ctrl_key` && Ctrl up, if Alt held; **deliberately lets Button2
  pan and Shift+Button1 through** to canvas. `POINTINSIDE` (5px border) per
  graph rect; hit → `graph_master=i`, tcross cursor, return 1; miss →
  `graph_master=-1`, drop GRAPHPAN, return 0. **Cannot be used as a pure
  predicate.**
- `waves_callback` (~540): the gesture engine. Operates on `graph_master`
  first (RMB wave-bold via `find_closest_wave`, RMB-on-legend via
  `edit_wave_attributes`, hover measurement tooltip via `G_X`/`G_Y`, cursor
  grab within 10px, numeric cursor set, `a`/`b`/`s`/`m`/`t` keys), then loops
  all graphs: participation test `r->sel || (same_sim_type && !(flags&2)) ||
  i==graph_master`; wheel zoom/pan, arrow pan/zoom, `f`=fit, drag pan,
  Button3-drag **XY box-zoom** (issue 0142: interior drag zooms x1/x2 across
  participating graphs + y1/y2 on the master, with a live rubber rect via
  `drawtemprect`/`gctiled`; left-margin drag = Y-only). **No snap grid in
  graphs** (issue 0143): `waves_callback` overrides `mousex_snap`/`mousey_snap`
  with the raw pointer at entry, so every graph gesture is unsnapped.
  **Writes results into `prop_ptr` tokens via
  `subst_token`, then `draw_graph()`.**
- **Two different flag words — do not confuse:** `xctx->graph_flags` =
  per-session cursor/measure modes (bits 2/4=draw A/B, 16/32=move A/B,
  64=tooltip, 128/256=draw hcursor1/2, 512/1024=move hcursor). `xRect.flags`
  = per-graph type/lock (1/2/4). The **authoritative `graph_flags` legend is
  `callback.c` ~527-539**; the `xschem.h` ~1475 one is incomplete (stops at
  64).
- `graph_master` (`xschem.h` ~1485) = MOUSE state, tracks pointer, can be −1
  or stale. `graph_lastsel` (~1489) = last CLICKED/added, persists — **this**
  is the trace-add target. Don't confuse them.
- Adding a trace: **no drag-onto-graph gesture.** Highlight nets →
  `act_highlight_send_waveform` (~3520) → `hilight.c` send →
  `graph_add_nodes_from_list` (`xschem.tcl` ~4312) appends to
  `graph_lastsel`'s `node`.
- Data-driven bindings: `init_input_bindings` (~3913) seeds ACTX_OVER_GRAPH
  rows → `graph.forward` (`act_graph_forward` → `waves_callback`).
  `current_input_ctx` (~4103) picks ctx via `waves_selected()`. To add a graph
  key you need **both** the branch in `waves_callback` **and** the binding row.

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
  `next_color`/`interp_value`.
- `switch_ctx` **verifies** the switch took — it silently no-ops inside a
  raised ctx semaphore (e.g. `ase::wait`'s vwait); `auto_plot` defers via
  `after idle` for exactly this reason (inline aimed clear/read at the DESIGN
  window — probe-verified data loss).

---

## 9. Subcommand surface (Tcl → C)

- `xschem raw <sub> ...` / `xschem raw_query ...` (`scheduler.c` ~8521):
  `value`/`values`/`set`/`index`/`del`/`rename`/`pos_at`/`add`/`datasets`/
  `points`/`rawfile`/`sim_type`/`vars`/`list`/`loaded`/`new`/`clear`/`switch`.
- `xschem raw_read <file> [sim] [sweep1 sweep2]` (~8755) /
  `xschem raw_clear` (~8740) / `xschem raw_read_from_attr` (~8794).
  **`raw read $file $sim_type`: omit `sim_type` entirely when empty** (absent
  arg ≠ empty arg in the C handler).
- `xschem add_graph` (~1887, sets `graph_lastsel`), `xschem draw_graph <i>`,
  `xschem get graph_lastsel` (~3772), `xschem cursor <which> <on>` (~2689),
  `xschem annotate_op`, `xschem embed_rawfile`.
- `xschem setprop rect 2 <i> <tok> <val>` — generic graph-token mutate;
  fullxzoom/fullyzoom special-cased at ~10500/10508 (**hardcoded `c==2`** —
  graphs on any other layer get no special handling).
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
- **New cursor/marker:** a `graph_flags` bit (keep both legends in sync), a
  draw path, grab/move/set branches in `waves_callback`.
- **New Tcl query on data:** branch under the `raw`/`raw_query` dispatch.
- **New viewer op:** a pure model transform on `layouts` + `regenerate`
  (`wave_viewer.tcl`); persist via the `viewer` state dict snapshot/restore.

---

## 11. Landmines (verify against these before editing)

1. **`values` has `nvars+1` columns** — the last is scratch. Any column loop
   must respect the +1 (`free_rawfile` loops `<= nvars`).
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
18. **Zooming/annotating a graph marks the file dirty** — `graph_fullxzoom`/
    `fullyzoom` write `x1`/`x2`/`y1`/`y2` tokens via `subst_token`
    (`set_modify`). `create_graph.tcl` calls `set_modify 0` afterward.

---

## 12. Improvement backlog (ranked, with where-to-touch)

Effort: S=hours, M=days, L=weeks. Impact in caps.

1. **[S · MED] `xschem get graph_flags` + cursor getters.** Add to the `get`
   dispatch (`scheduler.c` near ~3772). Lets `wave_viewer.tcl` drop `cva`/
   `cvb`/`cvr` mirrors (~136) and the access_cond desync risk. *Best ratio.*
2. **[S · MED] Cache per-dataset offsets on `Raw`.** Prefix-sum of `npoints[]`
   at load (`raw_read` ~1002, struct ~953); index it in `get_raw_value`
   (~2323) instead of re-summing per fetch. Hot-path win, no model change.
3. **[S · MED] Fix `raw_deletevar` realloc sizing** (`save.c` ~1115):
   `sizeof(SPICE_DATA*) * raw->nvars + 1` → `* (raw->nvars + 1)`. Latent
   under-alloc / heap corruption on `raw del`.
4. **[S · LOW] Bound bus-value buffers** (`draw.c` ~3229 `busval`/`old_busval`,
   `get_bus_value` ~2784) by `n_bits` instead of fixed 1024.
5. **[S · LOW] Trace-list integrity check** — when writing `node`/`color`/
   `sweep` (`graph_add_nodes_from_list` `xschem.tcl` ~4312; `setprop rect`
   special tokens `scheduler.c` ~10500), warn/pad on length mismatch.
6. **[M · MED] Propagate RPN eval errors** out of `raw_add_vector`/
   `plot_raw_custom_data` (`save.c` ~971/1821) through `xschem raw add`. Lets
   `wave_viewer.tcl validate_rpn` (~600) be deleted.
7. **[M · HIGH] Graph coordinate / legend hit-test verb** — extend
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
  `test_ase_plot.tcl`, `test_wave_viewer.tcl`, `test_ase_*` family. They
  `--pipe`/`--script` the built binary and diff against golden state. Pure
  Tcl helpers in `wave_viewer.tcl` (`graph_props`, `band_geometry`,
  `next_color`, `validate_rpn`, `interp_value`) are directly unit-testable.
- **Green ≠ correct** — sabotage-verify that the changed C actually ran (see
  memory `green-but-hollow`). A graph test that never loaded a raw passes
  while drawing nothing.
- Gesture tests must replay the **full Tk event sequence** in the shipping rc
  (memory `gesture-test-full-sequence`) — a lone synthetic event passes while
  the feature is broken.
- `test_nh_angle_*` etc. create per-pid scratch dirs under `[pwd]`; the
  `_*_[0-9]*/` gitignore + end-cleanup pattern is the convention (commit
  `cf57955c`).

---

## 14. Cross-references

- `doc/claude/specs/waveform_viewer.md` — ASE-L viewer feature decisions +
  as-shipped ledger (items 13/14/19). The authority on viewer UX contracts.
- `waveform_display_explained.md` (this folder) — the plain-English tour.
- Memory: `ase-l-plan`, `scheduler-letter-dispatch`, `green-but-hollow`,
  `gesture-test-full-sequence`, `wslg-dialog-open-repaint`.
- `doc/claude/WIRING.md` — the model for this kind of subsystem reference.
