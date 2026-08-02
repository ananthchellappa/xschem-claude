# Net-highlight styles on waveform traces

**Status:** specified 2026-08-01, not implemented.
**Load first:** `doc/claude/code_analysis/waveform_subsystem_reference.md` (§4 render,
§5 interaction, landmines 11/19/33/37/38/40/43/44/46/50), then
`doc/claude/specs/net_hilight_styles.md` (the style table) and
`doc/claude/specs/apply_hilight.md` (the ad-hoc style parser).

---

## 1. Goal

A trace is a polyline. It has no junctions, no direction and no branches, so the
whole of the net-highlight vocabulary — colour, width, dash pattern, blink,
marching ants — applies to it unchanged. Give the ASE Waveform Viewer the same
three keys a schematic has:

| key | in a schematic | here |
|---|---|---|
| `9` | highlight the picked net in the current style | **apply the current style to the SELECTED trace(s)** |
| `8` | un-highlight the picked net | **remove the style from the selected trace(s)** |
| `0` | un-highlight everything | **remove every trace highlight in this window** |

…plus the ad-hoc form already shipped for nets:

```tcl
apply_hilight {color purple thickness 3 pattern {20 20}}   ;# F5 in cadence_style_rc
```

All three keys are defaults on the `WaveViewer` bindtag, so an rc remaps them
(`doc/waveform_viewer_guide.html` §10.1).

**The constraint that shapes the design:** the animated case must stay cheap
regardless of how many samples the trace has. The shoddiest rendering the user
cannot catch out is the right rendering.

---

## 2. Decisions (LOCKED 2026-08-01 by the requester)

- **D1 — One style vocabulary.** Traces use the **same `net_hilight_style`
  table and the same current-style cursor** the schematic `9` uses. Cycling with
  `Alt+-` / `Alt++`, the style editor and every existing rc line apply to traces
  with no new table, no new editor and no new variable.
- **D2 — The highlight is an OVERLAY, not a recolour.** The trace is drawn
  normally, in its palette colour, and the style is stroked **on top** of it. The
  legend colour therefore still identifies the curve. This is also what makes D6
  possible: the base draw path is never touched, so the overlay can be erased
  with one `XCopyArea` instead of a redraw.
- **D3 — No cross-probe in v1.** Highlighting a trace does not highlight the
  schematic net, and vice versa. Deferred; see §11.
- **D4 — The highlight set is SESSION-ONLY view state.** It is not a prop token,
  it is not written to the session state, and it is not an undo point. It dies
  with the window.
  ⚠ **D4 has one consequence that must be engineered around, not accepted:**
  `wviewer::regenerate` runs `xschem clear_drawing` and re-places every rect, and
  a plain window RESIZE calls it (landmine 50). Session-only state held in `xctx`
  alone would therefore vanish on a resize, which reads as a bug. So the
  **authority is a per-window Tcl array** (`wviewer`'s transient class, beside
  `undo_hist` / `drag_from`), and `regenerate` re-applies it to the fresh rects.
  Still session-only: created on open, dropped by `forget`, never serialised,
  never in a snapshot.
- **D5 — Applies to the SELECTION, never to a pick.** `9`/`8` act on the trace
  selection of §7 of the guide (`hilight_wave` + `sel_waves`, built by clicking
  and Ctrl+clicking). With nothing selected they refuse with one `ciw_echo` line
  and change nothing. No pick mode, no modal — unlike the schematic `9`, which is
  interactive, because the viewer already has a first-class selection.
- **D6 — The overlay is WINDOW-ONLY chrome.** It is never written into
  `save_pixmap`. Erasing it is `MyXCopyArea(save_pixmap → window)` over its own
  bbox — the shipped `graph_snap_erase()` mechanism (`draw.c`), which exists
  precisely because the tiled-fill erase left a trail in a viewer window.
- **D7 — The animated frame must NOT go through `draw()`.** See §5.
- **D8 — Analog polyline traces only in v1.** A digital or bus trace refuses with
  a CIW line (§9). Its rendering is a band/ribbon, not a polyline; `graph_wave_at`
  already answers -1 across its whole body (landmine 33).

---

## 3. What already exists (read these, do not re-derive)

| Piece | Where | What it gives you |
|---|---|---|
| The style table + normalisation | `net_hilight_style`, `net_hilight_style_norm`, `net_hilight_style_current`, `xschem update_net_hilight_style` (`src/xschem.tcl`) | 8 columns: `index color width dash angle blink_ms anim rate_persec` |
| Style lookup + animation math | `get_hilight_style`, `net_hilight_style_animates`, `net_hilight_style_on_now`, `net_hilight_march_offset`, `net_hilight_next_edge_ms`, `net_hilight_dash_period` (`src/hilight.c`) | Everything blink/march needs, already written and already cached |
| The ad-hoc style parser | `aphl::parse` (`utils/apply_hilight.tcl`) + `net_hilight_apply` (`src/xschem.tcl`) | Three accepted argument forms, and a **dedup-or-append that returns a table INDEX**. An ad-hoc style is therefore just an index like any other — nothing new to store |
| The per-window animation tick | `net_hilight_anim_tick {win}` / `net_hilight_anim_update {win}` (`src/xschem.tcl`), `net_hilight_has_animation()` / `draw_hilight_region()` / `scan_animating_hilights()` (`src/hilight.c`) | Adaptive delay, visibility gate, change-detection signature, per-window arming — all of it already multi-window |
| The window-only overlay precedent | `draw_graph_snap_cursor()` / `graph_snap_erase()` / `graph_snap_clear()` (`src/draw.c`) | Paint-to-window, erase-by-copy-from-pixmap, yield-to-every-gesture, and the motion brake |
| Trace geometry + the sample walk | `graph_point_at()` (`src/draw.c`), `S_X`/`S_Y`/`DS_Y` | The correct node / sweep / dataset / `%N` / per-graph-rawfile resolution |
| The selection | `hilight_wave` + `sel_waves` tokens, `graph_sel_waves_get`, `wviewer::selected_waves`, `wviewer::model_sel` | What `9` and `8` act on |
| Index remaps | `wviewer::remap_sel_after_trace_move` / `_delete`, `reordered_index`, `index_after_removal` (all PURE) | Reuse verbatim for the highlight set (§8) |

---

## 4. Data model

### 4.1 Tcl — the authority (session-only, per window)

```tcl
variable wavehl;  array set wavehl {}   ;# token -> list of {gi ni style}
```

Same lifetime class as `undo_hist` / `drag_from` / `tdrag_pairs`: created in
`wviewer::open`, dropped by `wviewer::forget`, **never** in `layouts`, **never**
in `wviewer::snapshot`. `gi` is a MODEL strip index, `ni` is a **NODE** index
(landmine 34 — the two index spaces differ whenever a trace carries an empty
`vec`; cross with `node_index_of_trace` / `trace_index_of_node`).

### 4.2 C — the frame state

```c
/* xschem.h, beside graph_marker_sel_set / graph_preview_set_gi */
#define GRAPH_MAX_HILIGHT_WAVES 16
int wave_hilight_gi[GRAPH_MAX_HILIGHT_WAVES];
int wave_hilight_ni[GRAPH_MAX_HILIGHT_WAVES];
int wave_hilight_style[GRAPH_MAX_HILIGHT_WAVES];
int wave_hilight_n;
```

**Fixed arrays, never pointers** — `xctx` is reset, not freed, and a pointer adds
a free path to `clear_drawing()` for nothing (landmine 46(b)). Reset in
`clear_drawing()` **and** `alloc_xschem_data()`, with the gesture-state class.

The **envelope cache** (§5.2) is the one malloc'd side structure; it is freed in
`clear_drawing()` and in the per-context teardown, and it is a cache — losing it
is a rebuild, never a behaviour change.

### 4.3 Predicate

One function answers "is this trace highlighted, and in what style":

```c
int wave_hilight_style_of(int gi, int ni);   /* style index, or -1 */
```

Every draw-side and query-side test goes through it. The 0175/0189/0192 rule:
with a single highlighted trace a bare `gi == ... && ni == ...` comparison and
the predicate agree exactly, so a missed site is **invisible to any behavioural
leg** — assert the call sites at source level (`count_code`, the `LS5`/`MS13`
idiom).

---

## 5. Rendering — the cheap part, which is the whole point

### 5.1 Where it is painted

At the **tail of `draw()`**, after everything else, into the **window only**
(`draw_pixmap = 0` for the whole cadence, exactly as `draw_graph_snap_cursor`
does). Landmine 44's rule applies: the "does this context have wave highlights"
test goes **inside the drawer**, not in a caller's local, or the erase paths and
the paint paths drift apart.

Consequence, and it is the desired one: **exports never carry the overlay**
(SVG/PS/PNG go through their own callers and never touch the window). Same
doctrine as `draw_graph` bit 16.

### 5.2 The envelope — how a 100 k-sample trace costs 2000 points

Do **not** stroke the real polyline. Build, per highlighted trace, a **min/max
envelope at one column per screen pixel**:

```
for each screen column x in [plotbox_x1 .. plotbox_x2]:
    emit (x, ymin_of_samples_in_that_column)
    emit (x, ymax_of_samples_in_that_column)
```

≤ `2 × plotbox_width_px` points regardless of sample count, and on a dense trace
it reproduces the same solid band the real draw produces — which is why the user
cannot tell. On a sparse trace (fewer samples than columns) the envelope
degenerates to the samples themselves, so it is exact there too.

⚠ The envelope walk must resolve the node the way every other walker does:
**consume the `sweep` token before any `continue`** (landmine 38), switch to the
graph's own `rawfile`/`sim_type` **once, above the node loop, and unwind only if
the switch took** (landmine 40), and bracket `graph_flags` `128|256` around
`setup_graph_data` (landmine 37). The safe route is to model it on
`graph_point_at()` rather than to write a fresh walker.

**Cache it.** Key = `(gi, ni, gx1, gx2, gy1, gy2, plotbox x1/y1/x2/y2, digital,
dataset, raw generation)`. Rebuild only when the key changes. A marching frame
changes **none** of them, so a tick costs zero rebuilds.

### 5.3 One frame

Per highlighted, animating trace:

1. erase — `MyXCopyArea(save_pixmap → window)` over the entry's **previous**
   overlay bbox, clamped to the plot box;
2. if the style's blink phase is OFF this instant, stop here;
3. set the GC: style colour, `width`, `XSetDashes(dash_arr, dash_offset =
   net_hilight_march_offset(st, now))`;
4. `XDrawLines(window, …)` on the cached envelope, chunked at `MAX_POLY_POINTS`
   like every other polyline path (landmine 16 — repeat the last point of a chunk
   as the first of the next);
5. record the new bbox.

Cost per tick: **one XCopyArea + one GC change + one XDrawLines of ≤ 2 W
points**, per animating trace. No sample walk, no `draw()`, no pixmap write.

### 5.4 Steady (non-animating) styles

Painted once, at the tail of `draw()`. **No tick is armed** — a solid or
non-blinking, non-marching style must not make `net_hilight_has_animation()`
answer 1, or the window burns 20 fps drawing an unchanging line.

### 5.5 Known, accepted imperfections (state them in the guide)

- The erase restores `save_pixmap`, so it transiently clears any *other*
  window-only chrome inside the overlay bbox — today that is the snap diamond,
  which repaints on the next motion event. Nobody can see a one-frame gap in a
  glyph that already follows the pointer.
- The marching phase advances along the **envelope's** arc length, which on a
  noisy trace is dominated by the vertical excursions. On a dense trace the band
  is solid and the phase is invisible; on a sparse one the envelope *is* the
  polyline and the phase is exact. There is no zoom at which the discrepancy is
  observable, which is the criterion.
- Sub-pixel dash scroll is quantised to whole pixels by `XSetDashes`, exactly as
  the shipped wire marching already is.

---

## 6. Animation wiring — and the trap

`scan_animating_hilights()` (`src/hilight.c`) is the single source of truth for
*what animates / its bbox / the change signature / the next blink edge*. It gets
a **fourth loop**, beside the wire, instance and buried-cue loops, over
`xctx->wave_hilight_*`. Fold the blink phase **and** the whole-pixel march offset
into `*sig` (the wire loop's two-term idiom), grow the bbox from the strips' plot
boxes, track `maxw`, lower `*next_ms`.

⚠ **THE TRAP, and it is the reason this feature is not a 50-line patch.**
`draw_hilight_region()` renders a frame as

```c
bbox(START); bbox(ADD, x1u-marg, …); bbox(SET); draw(); bbox(END);
```

— a **clipped full redraw**. A wire's bbox is small, so this is cheap for the
shipped feature. **A trace's bbox is the whole strip**, so reusing this path
re-walks every sample of every trace on that strip, every tick — precisely the
cost this design exists to avoid. Therefore:

- split the frame: if the animating set contains **only** trace highlights, call
  the cheap `draw_wave_hilight_frame()` of §5.3 and **never** `draw()`;
- if any wire / instance / buried cue also animates (possible only in a schematic
  window that embeds a graph), run the existing `draw()` frame **and then**
  re-stroke the trace overlays, because `draw()` into the window wipes
  window-only chrome. The overlay is always painted last;
- the entry gate `if(!has_x || !xctx->hilight_nets) return 0;` appears in **both**
  `net_hilight_has_animation()` and `draw_hilight_region()`. A viewer has no
  highlighted nets, so **both must gain `&& !xctx->wave_hilight_n`** or the
  feature is silently dead in the only window that has it.

---

## 7. Surface

### 7.1 C verbs (`scheduler.c`, matching first-letter dispatch — see memory `scheduler-letter-dispatch`)

| verb | args | result |
|---|---|---|
| `xschem wave_hilight` | `<gi> <ni> <style>` | `1`/`0`. `style` `-1` clears that trace. Usage error ⇒ `TCL_ERROR` (fails LOUD, the `graph_marker` convention) |
| `xschem wave_hilight` | `-clear [<gi>]` | count cleared |
| `xschem get wave_hilights` | — | `{gi ni style} …`, `""` for none. Fails SOFT |
| `xschem get wave_hilight_at` | `<gi> <ni>` | style index or `-1`. Fails SOFT |
| `xschem get wave_hilight_points` | `<gi> <ni>` | **the cached envelope's point count** — the seam a headless leg uses to assert decimation actually happened. Fails SOFT, `0` when nothing is cached |

Not `scheduler_readonly_reject()`ed: this is view state the engine has always
been allowed to write into a read-only rect (landmine 17 names the box zoom), the
viewer is read-only for life, and rejecting would abort every replay.

### 7.2 Tcl (`src/wave_viewer.tcl`)

| proc | does |
|---|---|
| `wviewer::hilight_traces {?style? ?token?}` | apply `style` (default: the current style cursor) to the selected traces of every strip |
| `wviewer::unhilight_traces {?token?}` | drop the style from the selected traces |
| `wviewer::unhilight_all {?token?}` | drop every trace highlight in the window |
| `wviewer::apply_style_traces {styledef ?token?}` | `aphl::parse` → the `net_hilight_apply` dedup-or-append → an index → `hilight_traces` |
| `wviewer::wave_hilights {?token?}` | the current set, for tests and for the regenerate bracket |
| `..._at {W}` wrappers | resolve the token from `%W`, never the current ctx (the `clear_all_at` pattern), `catch`ed so no error escapes a Tk binding |

Each mutating proc: refuse-a-no-op **without logging**, verified `switch_ctx`,
exactly one `wviewer::log_action` line carrying the resolved token and the
explicit pairs. No `push_undo` (D4), no `capture_live_graph_state` (the set is
not in the model).

### 7.3 Keys (`wviewer::install_default_binds`, the `WaveViewer` bindtag)

```tcl
bind WaveViewer <Key-9> {wviewer::hilight_traces_at %W; break}
bind WaveViewer <Key-8> {wviewer::unhilight_traces_at %W; break}
bind WaveViewer <Key-0> {wviewer::unhilight_all_at %W; break}
```

Each guarded by `[bind WaveViewer <seq>] eq {}` so an rc that binds first wins;
disabled with `{break}`, never `{}`.

**Collision check, done:** keysyms 57/56/48 are not in `graphkeys`
`{97 98 100 115 109 116 65 66 77}`, so `key_filter` forwards nothing and the C
dispatcher never sees them; `cadence_style_rc`'s `bind .drw <Key-9|8|0>` clones
are swept off the viewer canvas by `strip_bindings`. The keys are free.

An ad-hoc style key is an rc line, exactly like the schematic's F5:

```tcl
bind WaveViewer <Key-F5> \
  {wviewer::apply_style_traces_at %W {color purple thickness 3 pattern {20 20}}; break}
```

---

## 8. Index remaps

The set is keyed by `(gi, ni)`, and both spaces move under ordinary editing. The
remaps already exist, are PURE, and are called from the same places the model
selection is remapped — do not write new ones:

| event | rule |
|---|---|
| strip reorder | `reordered_index` on `gi` |
| trace moved between strips | the entry follows its trace: new `gi`, appended `ni`; `remap_sel_after_trace_move` shape |
| trace deleted | the entry is DROPPED; every entry above the hole in that strip shifts down (`remap_sel_after_trace_delete`) |
| strip deleted | entries on it are dropped, `index_after_removal` on the rest |
| split | entries follow their traces into the new strips |
| `clear_all` | the whole set goes |

---

## 9. Refusals (all one non-modal `ciw_echo`, never a modal)

- nothing selected → *"wviewer: select a trace first (click it, or its legend name)"*;
- a digital or bus trace in the selection → *"wviewer: <name> is a digital/bus trace — highlighting is analog-only"*, and the analog members are still highlighted;
- the cap is full → *"wviewer: at most 16 highlighted traces"*;
- no viewer window resolves → the `clear_all` message shape.

---

## 10. Testing (`tests/headless/test_wave_hilight.tcl`, new)

Split by what each leg needs, the `test_wave_markers.tcl` convention:

- **`WH*` — pure/engine, BOTH arms.** The verbs and their fail-soft/fail-loud
  contracts, the cap, `clear_drawing()` dropping the set, the remaps driven as
  pure list math, and `aphl::parse` → index round-trip.
- **`WD*` — the cost witnesses, and they are the point of the file.**
  1. `xschem get wave_hilight_points` on a trace with ≥ 50 000 samples is
     `<= 2 * plotbox_width + 2` — decimation actually happened;
  2. the same trace zoomed to 10 samples yields the exact sample count — no
     decimation where none is needed;
  3. an animation frame calls `draw()` **zero** times: the `-d 1` probe
     `wviewer::delete_all_markers` already uses (`draw()` logs itself at that
     level) is the shipped idiom;
  4. a STEADY style does not arm the tick
     (`xschem get net_hilight_animated <win>` is 0).
- **`WG*` — display.** The real `9`/`8`/`0` keys through Tk, the overlay
  surviving a `regenerate` (the D4 bracket), the rc-wins and `{break}` contracts
  for all three keys, and the set surviving a strip reorder and a trace move.
- **`SAB*` — sabotage.** At minimum: drop the `&& !xctx->wave_hilight_n` gate
  term (the whole feature dies in a viewer, and no schematic leg can see it), and
  replace the predicate with a bare head comparison (invisible with one
  highlighted trace — that is why `WH` plants **two**).

---

## 11. Deferred, explicitly

- **Cross-probe** to the schematic net (D3). Needs `v(node)` → schematic-token
  resolution, which is landmine 23's problem (`#netN` vs `netN`) plus hierarchy.
- **Digital / bus traces** (D8).
- **Highlights in exports.** Window-only by construction; a printed plot carries
  the trace, not the highlight. If wanted, it becomes `draw_graph` bit-8 content
  and stops being erasable-by-copy — a different design, not a flag flip.
- **Per-trace style in the Add Trace dialog / a right-click menu entry.** The
  keys and the verbs come first.

---

## 12. Documentation obligations (enforced by an existing test)

`doc/waveform_viewer_guide.html` §9.1 must gain a row per new key, carrying the
machine-readable `data-seq` attribute, and §10 must document the rc remap.
**This is not optional and it is not on the honour system:**
`tests/headless/test_wave_grid.tcl` `GH2` asserts that the number of
`bind WaveViewer` statements in `install_default_binds` equals the number of
documented `data-seq` rows, and `GH1`/`GH5` assert each documented sequence
exists in the source and on the live tag. Adding three keys without three doc
rows turns the suite red.

Also: §5.5's accepted imperfections belong in the guide in one sentence, and the
§9.3 note that these keys mean something else in a schematic window belongs in
§9.5's collision table.
