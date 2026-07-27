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
  first (**LMB-click wave-bold** via `find_closest_wave` — issue 0152, see
  landmine 20; RMB-on-legend per-trace bold via `edit_wave_attributes`, hover
  measurement tooltip via `G_X`/`G_Y`, cursor
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
- **New per-graph UI decoration (on-screen only):** a prop token written by
  `wviewer::graph_props`, a `Graph_ctx` field parsed in `setup_graph_data`
  (before the `RECT_OUTSIDE` return), a draw block in `draw_graph` gated on a
  flags bit the on-screen callers set, and a dedicated GC created in
  `create_gc` / freed in `free_gc` / coloured in `build_colors` from a Tcl
  colour var (`gc_hover` is the worked example; issue 0151 is the second).
- **New viewer op:** a pure model transform on `layouts` + `regenerate`
  (`wave_viewer.tcl`); persist via the `viewer` state dict snapshot/restore.
- **New viewer KEY (issue 0171):** a `<seq>` row in
  `wviewer::install_default_binds` (the `WaveViewer` bindtag), guarded by
  `[bind WaveViewer <seq>] eq {}` so an rc keeps winning, plus a `%W`-resolving
  wrapper like `clear_all_at`. NOT a `key_filter` arm (those are the C-forward
  and intercept cases) and NOT a `bind $wp` — `strip_bindings` sweeps that.

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
18. **`Graph_ctx.active` + `draw_graph` flags bit 16** (issue 0151). The
    viewer's target-strip marker is a prop token `active=1` parsed in
    `setup_graph_data` — parsed **before** the `RECT_OUTSIDE` early return,
    because `gr` is the shared `xctx->graph_struct` and a stale value would
    leak onto the next graph. It is painted only when `flags & 16` is set,
    which the **on-screen** callers do (`draw_graph_all`, `callback.c` ×3, the
    `xschem draw_graph` verb) and the **export** callers deliberately do not
    (`svg_embedded_graph`, `psprint.c` ×2). A new on-screen `draw_graph` caller
    must set bit 16 or the marker will blink out on that redraw path.
19. **Zooming/annotating a graph marks the file dirty** — `graph_fullxzoom`/
    `fullyzoom` write `x1`/`x2`/`y1`/`y2` tokens via `subst_token`
    (`set_modify`). `create_graph.tcl` calls `set_modify 0` afterward.
20. **A graph gesture must not be triggered on a PRESS that a drag also starts**
    (issue 0152). The wave-bold toggle used to fire on Button3 *press*, so every
    RMB press-drag box-zoom (0142) bolded a trace. It is now the **release of a
    Button1 press that did not travel** more than `GRAPH_CLICK_TOL` (3) pixels.
    The press anchor is `xctx->graph_press_x/y`, **never**
    `mx/my_double_save`: the Button1 drag-pan **re-seeds** those on every motion
    step (`save_mouse_at_end`, end of `waves_callback`), so at the end of a long
    pan they equal the release point and a click test against them fires. Also
    note `find_closest_wave()` has **no distance threshold** — "near a trace" is
    really "anywhere in the plot body" — and the toggle tests the *currently*
    bold wave, not the one just found (a click anywhere un-bolds whatever is
    bold). RMB inside the plot body is box-zoom only; RMB on a **legend** entry
    is a separate, per-trace bold (`edit_wave_attributes(2,...)`) and is
    unchanged.
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
    `actions.c:3568-3572` strips at build time; the attribute path got its own
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

---

## 12. Improvement backlog (ranked, with where-to-touch)

Effort: S=hours, M=days, L=weeks. Impact in caps.

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
   the one channel that declares an attribute to be a NODE — and the accepted
   value gets the same loose `#` strip. See landmine 29. A sweep of every
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
  `test_wave_viewer.tcl` (`WB` = the LMB wave-bold gesture, issue 0152),
  `test_wave_modes.tcl` (plot modes / target strip, issue 0151; `M6`/`MG6c`/
  `MG6d` = the trace-color policy, issue 0153),
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
  `test_wave_viewer.tcl` is the pattern).
- `test_nh_angle_*` etc. create per-pid scratch dirs under `[pwd]`; the
  `_*_[0-9]*/` gitignore + end-cleanup pattern is the convention (commit
  `cf57955c`).

---

## 14. Cross-references

- `doc/claude/specs/waveform_viewer.md` — ASE-L viewer feature decisions +
  as-shipped ledger (items 13/14/19). The authority on viewer UX contracts.
- `doc/claude/specs/waveform_viewer_modes.md` — plot modes (single/multi),
  target strip, the active-strip marker and the mode command surface
  (issue 0151).
- `waveform_display_explained.md` (this folder) — the plain-English tour.
- Memory: `ase-l-plan`, `scheduler-letter-dispatch`, `green-but-hollow`,
  `gesture-test-full-sequence`, `wslg-dialog-open-repaint`.
- `doc/claude/WIRING.md` — the model for this kind of subsystem reference.
