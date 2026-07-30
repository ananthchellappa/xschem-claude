# 0175 — select a trace by clicking its LEGEND text, and hold more than one selected

- **Status:** FIXED (2026-07-30)
- **Area:** `src/draw.c` (`graph_legend_at`, `legend_slot_hit`, `wave_is_hilighted`,
  `graph_sel_waves_get/set/toggle`, `edit_wave_attributes` rewritten, the 11 draw-side
  comparisons, `setup_graph_data`), `src/callback.c` (the LMB wave-select arm),
  `src/xschem.h`, `src/scheduler.c` (`xschem get graph_legend_at`),
  `src/wave_viewer.tcl` (`legend_at`, `selected_waves`, `sel_waves_norm`, `model_sel`,
  `model_sel_set`, the two structural remaps, `graph_props`,
  `capture_live_graph_state`, two STALE comments corrected)
- **Tests:** `tests/headless/test_wave_trace_menu.tcl` — the new `TL*` (legend query)
  and `TS*` (multi-select) blocks; `tests/headless/test_wave_legend.tcl` — the new
  `LS*` block; `tests/headless/test_wave_viewer.tcl` — the retargeted `WB-legend` legs
- **Related:** 0174 (the body pick — this issue is the other half of its D3),
  0152 (the `WB-legend` row is SUPERSEDED here), 0151 (viewer modes), 0176 (delete)
- **Reference:** `doc/claude/code_analysis/waveform_subsystem_reference.md`
  landmines 11, 19, 33, 34, 37, 39, 43 (new);
  `doc/claude/specs/waveform_viewer_modes.md` §12.6

## Report

> We also want to be able to select a trace by clicking on the legend text. Goes
> without saying that CTRL-click should add an unselected trace to the selection
> and CTRL-click on a selected trace should deselect it.

Two things, and the second had the teeth: **the selection could not hold two
traces at all.** `hilight_wave` is a single int.

## The two stale comments, corrected

Both claimed the engine had no legend hit test. Both were wrong when written:

- `wave_viewer.tcl` ~76 — *"canvas legend click-select has no C hit-test API"*
- `wviewer::delete_dialog` — *"canvas-legend click-select has no C hit-test API
  (receipts/11: rect descriptors carry no coordinates)"*

The hit test shipped. It lived **inside the action** of
`edit_wave_attributes(what, i, gr)` (`draw.c`), triplicated once per legend
layout, reachable only from a Button3 PRESS outside the plot body. There was no
standalone query, which is a different claim from "no hit test" and is what the
comments should have said. Both now carry the correction rather than the claim.

## Decisions

### D1 (THE decision) — a NEW token `sel_waves`, `hilight_wave` untouched

Option (c) of the three on the table. `hilight_wave` keeps its grammar, its `-1`
sentinel and its meaning; a second, **optional** token carries the rest:

```
hilight_wave=0            the FIRST selected node, or -1. Unchanged.
sel_waves="0 2"           the WHOLE set, ascending, no duplicates.
                          Written ONLY when two or more are selected.
```

**Invariant: `hilight_wave` is always the head of the selection.** One writer
(`graph_sel_waves_set`) emits the pair, so they cannot drift.

**FILE-FORMAT COMPATIBILITY STATEMENT** (the thing that had to be explicit):

| case | what happens |
|---|---|
| an existing `hilight_wave=3` file, NEW build | `sel_waves` is absent → the selection is `{3}`. Renders identically, saves identically. |
| a file written by the NEW build with ONE trace selected | **byte-identical to pre-0175.** `sel_waves` is not emitted at all below two. This is why the "only when >= 2" rule exists and it is asserted (`LS4`, `TS8`). |
| a file written by the NEW build with TWO selected, read by an OLDER build | `hilight_wave=0` bolds the first selected trace; `sel_waves` is an unknown token — `setup_graph_data` ignores it, `save.c` carries it verbatim through a round trip. **Fewer bold traces, never a wrong one, never a parse error.** |
| an older build then CLICKS that graph | it rewrites `hilight_wave` and leaves `sel_waves` stale. The new build's parse then wins (the list is the whole truth), so the selection reads as the old set. Acceptable: an older build cannot express a two-trace selection at all, and nothing is corrupted. |
| a hand-edited `sel_waves=3 hilight_wave=-1` | the PARSE wins: node 3 renders bold. The list is deliberately not collapsed to "0 when it holds one" precisely so this case is well-defined. |

**No `XSCHEM_FILE_VERSION` bump.** An additive optional rect prop token is
exactly how `active`, `markers`, `reorder_handle`, `legendbold`, `griddash` and
`grid` were all added — none bumped it. The format's extension mechanism *is*
"unknown tokens are preserved and ignored", and this change does not alter the
meaning of a single byte any older build can read.

**Why not (a), `hilight_wave` becomes a list.** It degrades acceptably (`atoi("0 2")`
is 0) but it changes the grammar of a token persisted in every `.sch` carrying a
graph, including the ~127 embedded ones and both export paths. The compatibility
argument then rests on `atoi`'s prefix behaviour rather than on a token an old
build never looks at. Not worth it for one fewer token.

**Why not (b), a bitmask.** It caps the **node index** at 32/64 and, worse, an
older build reading `hilight_wave=5` would bold **node 5** instead of nodes 0 and
2. A silent wrong answer, which is the one outcome this issue could not ship.

**In memory:** `Graph_ctx` gains `int sel_wave[GRAPH_MAX_SEL_WAVES]` (64) and
`int n_sel_waves`, parsed beside `hilight_wave` in `setup_graph_data`.
⚠ A **fixed array, not a malloc'ed pointer**: six call sites build a LOCAL
`Graph_ctx` and let it die on return (`graph_plotbox_at`, `graph_point_at`,
`graph_marker_at`, `graph_marker_create`, `graph_marker_drag_to`, `raw_read`'s
`gr_ctx`) — a pointer field would leak on every one of them, once per hover
motion event. The cap is on the **selected count**, not the node index; the 65th
`Ctrl+click` is refused (with a `dbg`) rather than silently dropped.

### D2 — per-WINDOW, not per-strip: already settled by 0174 round 2, and extended

`hilight_wave`/`sel_waves` stay per-RECT; the SELECTION is window-wide. A plain
click still sweeps every other graph rect clear (0174 defect (d)) — **Ctrl+click
deliberately does not**, and that is exactly how a selection spanning two strips
is built. The sweep now goes through `graph_sel_waves_set(k, NULL, 0)` so it
clears both tokens; its "an ABSENT token is not node 0" guard is unchanged.

### D3 — Ctrl+Button1 IS free. **Measured, not assumed**

Measured on the shipping build before anything was written
(`probe_d3.tcl`, ASE viewer, 2 strips, 3 separated traces):

```
Q1 plain click on node0  -> {0 -1}      Q2 CTRL click on node0        -> {0 -1}
Q1 plain click on node2  -> {2 -1}      Q2 CTRL click on node2        -> {2 -1}
                                        Q2 CTRL click on node2 again  -> {2 -1}
                                        Q2 CTRL click on EMPTY body   -> {-1 -1}
Q3 strip_drag_press with Ctrl -> 0      (declines: `$state & 13`)
Q3 strip_drag_press plain     -> 1
```

**Ctrl+B1 over a graph does today exactly what a plain B1 does.**
`wviewer::strip_drag_press` refuses a modified press and the pre-existing
fallback forwards it to C verbatim; the C arm never looked at `state`. So
nothing is taken away, and no viewer binding had to change — `<ButtonPress-1>` is
bound unmodified, so Tk routes Ctrl+B1 to it already.

⚠ **The one other meaning ControlMask carries over a graph**, and it is real:
`waves_selected` (`callback.c` ~116) skips a rect carrying `lock=true` **unless
Ctrl is held**. On such a graph Ctrl+click is the *only* click there is, and its
meaning therefore changes from "replace the selection" to "add/remove". The ASE
viewer never writes `lock` (`graph_props` has no such key), so this is an
embedded-schematic-graph corner; recorded rather than worked around, because
gating the modifier on `lock` would make the gesture inconsistent between graphs.

### D4 — N selected traces get exactly the cue ONE has always had

- **stroke:** thick, every selected trace (`set_thick_waves`);
- **legend:** bold — and **bold ITALIC** where `legendbold` is on, which is
  viewer plan item 1's existing "the selected entry is the slanted one" cue,
  now applied to N entries instead of one.

**No separate cue for the "primary".** `hilight_wave` remains the head of the set
but is not drawn differently: Cadence marks a multi-selection uniformly, a third
weight/slant does not exist on the toy-font path, and item 1 has already spent
the slant axis. ⚠ **This is a pixels decision and it is eyeball-only** — the
suite asserts everything up to the renderer's door (`LS5`), never the pixels.

**The SVG and PS exports inherit this for free and deliberately.** Neither has a
`hilight_wave` comparison of its own — `svgdraw.c` and `psprint.c` both go
through `draw_graph`, so an export of a graph with two traces selected shows two
thick strokes and two bold legend entries, exactly as the screen does. That is
the same rule `hilight_wave` has always followed (it is durable content, unlike
`active` / `reorder_handle`, which are flags-bit-16 chrome the exporters
deliberately do not set).

The load-bearing implementation detail: **all 11 draw-side comparisons became
`wave_is_hilighted(gr, wcnt)`**. A single surviving `gr->hilight_wave == wcnt`
renders a Ctrl-selected trace thin while the token says it is selected, and that
is invisible to any leg that only ever selects one trace — so `LS5` asserts it at
SOURCE level.

### D5 — one pure query in C, `graph_legend_at`, and both buttons call it

```c
int graph_legend_at(int i, double px, double py);   /* NODE index, or -1 */
```
`xschem get graph_legend_at <gi> <px> <py>`; `wviewer::legend_at` is the
fail-closed Tcl wrapper (the `trace_at`/`plotbox_at` shape).

- **All three legend layouts** — vertical (`vlegend`), `digital`, and the ASE
  viewer's horizontal one. The arithmetic is now written ONCE, in the static
  `legend_slot_hit()`, and `edit_wave_attributes` calls it too: the function lost
  ~100 lines of triplicated geometry and the RMB and LMB arms cannot disagree.
- **RAW SCREEN PIXELS.** The in-place version tested `xctx->mousex_snap` —
  grid-snapped, schematic-space. That is neutralised for its two existing callers
  (`waves_callback` overwrites `mousex_snap` with `mousex` at its head, issue
  0143) but it is the wrong contract for a query, so the new one converts the
  caller's pixels once and reads nothing off the mouse mirror. `TL4` drives this
  directly: with the pointer parked on entry 0, a query about entry 2 answers 2.
- **Fails closed** exactly like `graph_plotbox_at`: bad index, non-graph rect,
  off-screen graph, `legend=0`, or no `node` token → -1, never a plausible 0.
  LOCAL `Graph_ctx`, hcursor bits bracketed (landmines 11 + 37).
- ⚠ **It does NOT refuse digital strips** — unlike `graph_plotbox_at` /
  `graph_trace_at`. A digital strip's body answers -1 everywhere (0174 D5), so
  its legend is the only place a trace can be picked at all.
- **One behaviour change fell out and is deliberate:** `legend=0` now refuses on
  BOTH buttons. The triplicated version did not test it and would happily pick an
  entry that is not drawn.

### D6 — the double-click is untouched, and cannot be eaten

The `-3` arm poisons `graph_press_x/y` with `-1e30`, so the trailing release can
never pass the travel test — the same interlock that has protected the body click
since 0152, and the new legend arm sits under the same gate.

- **embedded schematic graph:** a legend double-click still opens
  `graph_edit_wave` and does **not** change the selection.
- **ASE viewer:** `<Double-Button-1>` is bound to `{break}`, so the second PRESS
  never reaches C and the anchor is never poisoned; the second RELEASE therefore
  passes the travel test against the FIRST press anchor and acts as a second
  single click. Plain → idempotent (the same trace stays selected). Ctrl →
  toggled twice, i.e. a no-op. Measured, harmless, recorded.

### D7 — legend RMB keeps the button and gains the set

It toggles that entry's **membership** of the selection. A strict superset: for a
selection of at most one trace it is byte-identical to what it always did. It
does **not** sweep the other strips — it never did, and now that a multi-trace
selection is legal that stops being an inconsistency and becomes the second way
to build one. `Ctrl+LMB` and `RMB` on a legend entry are now the same gesture on
two buttons.

⚠ Pre-existing and NOT changed: an RMB release on the legend also reaches
`btn3_filter`'s context-menu gate. That posts a menu which GRABS, so a *second*
RMB at the same spot goes to the menu rather than the canvas. It confounded the
first D7 probe and is worth knowing before probing this by hand.

### D8 — a selection change logs NOTHING, and 0176 must not depend on it

Selection is view state (landmine 19): no `set_modify`, no `push_undo`, no
`log_action`. Asserted by `TS4`.

**What that means for 0176 (delete the selected traces):** the replayable log line
must name its targets as **explicit model indices** — the 0151 precedent — never
"the selection". A replay runs with no selection state at all, so a line that
said "delete the selected traces" would delete nothing (or, worse, whatever the
replaying session happened to have selected).

### Persistence — `sel_waves` follows `hilight_wave` exactly

Captured by `capture_live_graph_state`, emitted by `graph_props`, and therefore
carried by `wviewer::snapshot`/`restore` and by the viewer undo stack
(`state_snapshot` carries the whole graphs list). Same lifetime, same
absent-means-absent rule, one fewer special case.

⚠ It **had** to be captured: `regenerate` rebuilds every rect from the model and
runs from ~18 sites including a plain window RESIZE, so without the capture a
multi-select would silently collapse to one trace the next time the window was
resized. `hilight_wave` has always had that same exposure on the regenerate sites
that do not capture first; this deliberately does NOT grow a C→Tcl push hook the
way markers needed one, because selection is view state and losing it on a resize
is a cosmetic annoyance, not data loss.

### The structural remaps — a stale index is worse than a lost selection

Three paths shift node indices, and all three had to learn the set:

| path | rule |
|---|---|
| `move_trace_in_graphs` | every selected index that STAYS shifts down past the hole; the one that LEFT migrates to the destination **and is ADDED to whatever the destination already had selected** |
| `delete_ok` | per element through `remap_node_after_trace_delete`; a selected trace that died just leaves the set |
| `clear_graph_traces` | every node index is gone, so both keys go |

⚠ The **destination hand-off changed** (`test_wave_modes` M8). It used to
`dict replace $D hilight_wave $dst_ni`, i.e. **overwrite** the destination's own
highlight. With a set, adding is the coherent answer, and the neighbouring leg
("the destination's unrelated highlight is preserved") already said that
highlight has no reason to die. M8 is retargeted, with a teeth leg proving a
destination with nothing selected still gets exactly the migrant and no
`sel_waves` key.

## The arm

`callback.c`, the ButtonRelease+Button1 arm:

```c
else if(event == ButtonRelease && button == Button1 && <travel test>) {
  int on_body = POINTINSIDE(mousex, mousey, gr->x1, gr->y1, gr->x2, gr->y2);
  int ctrl = (state & ControlMask) ? 1 : 0;
  int selchg = 0, wcnt;
  if(on_body) wcnt = graph_wave_at(i, mx, my, GRAPH_TRACE_PICK_TOL);
  else        wcnt = graph_legend_at(i, mx, my);
  if(ctrl) {
    if(wcnt >= 0 && graph_sel_waves_toggle(i, wcnt)) selchg = 1;
  } else if(on_body || wcnt >= 0) {
    if(graph_sel_waves_set(i, &wcnt, wcnt >= 0 ? 1 : 0)) selchg = 1;
    /* ... the 0174 cross-strip sweep, now through graph_sel_waves_set(k, NULL, 0) */
  }
  if(selchg) need_redraw_master = 1;
}
```

Three things about that shape are load-bearing:

- **`POINTINSIDE` moved out of the `else if` condition** so a legend release
  reaches the arm at all. The **travel test stayed in the condition** — it is
  what the double-click interlock rides on (D6) and what separates a click from
  the end of a strip drag-reorder (0174 D2).
- **`on_body` is carried separately**, not folded into `wcnt < 0`. A click that
  hits NEITHER surface — an axis margin, the reorder grip — must change nothing.
  Only the plot BODY clears. `TS6`'s axis-margin leg is that boundary.
- **The redraw keys off `selchg`, not off `hilight_wave` changing.** Collapsing
  `{0,2}` to `{0}` or adding node 5 behind node 2 both leave the scalar alone
  while changing every pixel; the old `save != gr->hilight_wave` test would have
  skipped those repaints. It also moved from an inline `draw_graph` to
  `need_redraw_master`, so the tail loop re-runs `setup_graph_data` and reads the
  tokens back instead of relying on this arm having hand-patched every field of
  the SHARED `xctx->graph_struct` (it now writes two).

## Tests + teeth

| leg | asserts |
|---|---|
| `TL1` (trace_menu) | three columns of one legend band give three DIFFERENT entries |
| `TL2` | the SLOT BOUNDARY, found by scanning, asserted on both sides, and shown to sit near 1/3 of the width — an off-by-one slot moves it and every centre-of-slot leg stays green |
| `TL3` | the refusals, all fail-closed; and the two picking surfaces are disjoint (`trace_at` answers nothing in the band) |
| `TL4` | **RAW pixels**: pointer parked on entry 0, a query about entry 2 says 2; and a `cadsnap 400` grid moves no answer |
| `TS1` | Ctrl+click ADDS — witnessed as the SET `{0 2}`, then `{0 1 2}` IN ORDER |
| `TS2` | Ctrl+click REMOVES, driven from a 2-element selection, and removing the OTHER member leaves the OTHER survivor |
| `TS3` | a plain click COLLAPSES to the one clicked; empty body clears the whole set |
| `TS4` | Ctrl+click on empty body changes nothing; no undo point, no modify, no log line |
| `TS5` | window-wide: Ctrl spans strips, a plain click on strip B clears a multi-select on strip A. Witness is the WHOLE STACK |
| `TS6` | the legend drives add/remove/collapse too, agrees with the body pick, and an AXIS MARGIN click changes nothing |
| `TS7` | the witness is a NODE index — the fixture's node 0/2 are model 0/3 |
| `TS8` | the set survives a regenerate; and a ONE-trace selection grows NO `sel_waves` token |
| `LS1-LS3` | the pure set algebra: normalise, the two-token composition, and the move/delete remaps |
| `LS4` | `graph_props` emits `sel_waves` only at >= 2, quoted, in the documented byte order |
| `LS5` | blast radius (the C `add_graph` template has no such token, one emitter in Tcl) **and the D4 source leg**: the only bare `gr->hilight_wave == wcnt` left in `draw.c` is `wave_is_hilighted`'s own body |
| `WB-legend` (viewer) | legend LMB SELECTS (was: "does not bold"), a second plain click KEEPS it, and the body arm still clears afterwards |

**Anti-hollowness, applied:**
- multi-select legs assert the **SET**, never `llength == 2` — `{0 2}` and
  `{0 1}` are both "two selected";
- the Ctrl REMOVE is driven from a **>= 2-element** selection, so "removed the
  right one" and "cleared everything" are different states;
- the slot boundary is **scanned**, not computed from the formula under test;
- the fixture carries a **vec-less trace** at model index 1, so NODE and MODEL
  index spaces diverge;
- click columns are **slot centres found by scanning**, never a fixed fraction:
  the outermost columns of the band sit inside `waves_selected`'s 5-px routing
  border, where a press never reaches the graph at all. The first cut of `TS6`
  used `0.02 * W` and failed for exactly that reason — a leg driven from there
  would otherwise have "passed" by never doing anything.

### Two fixture bugs this issue exposed (neither is a regression)

- **`test_wave_markers`' `mf_empty_px`** scanned the whole graph RECT for a row
  with no trace on it, so on a strip whose traces sit near the top it handed back
  the **label margin** — the legend. Harmless while a click there did nothing;
  since this issue a click there selects an entry, and `MF10` went red asserting
  a trace had not been bolded. Fixed by requiring `graph_plotbox_at`, the same
  requirement `tb_far_px` already carried. 712 restored.
- **`test_wave_viewer`'s WB far-pixel** was scanned once at the top of the block
  and reused after `WB-rmb-drag` ZOOMS and `WB-mmb-drag` PANS the graph, so a
  once-empty row can have a trace on it by the end. The new leg re-scans; a
  `wb_far_row` helper was added and the hazard written down.

### Landmine 39 does NOT apply, and that was checked

`merge_box()` (paste) and `copy_objects()` (the `c`-key copy) both clone a rect's
`prop_ptr` verbatim, so a token holding an **identity** produces two objects
claiming the same one — which is why markers renumber in both. `sel_waves` holds
**NODE indices**, not identities: a copied graph rect legitimately has the same
traces selected as its original. Nothing to renumber, and nothing added to either
door. What *was* checked is the emission order (`LS4`): `sel_waves` sits directly
after `hilight_wave` and before `markers` in `graph_props`' byte-deterministic
template.

### The existing `hilight_wave` assertions — none had to change

Counted before starting, per the prompt: `test_wave_modes` 28,
`test_wave_markers` 26, `test_wave_trace_menu` 27, `test_wave_split_strip` 12,
`test_wave_viewer` 8, `test_wave_legend` 0. **After: 32 / 26 / 31 / 12 / 8 / 24.**
Every one of them still asserts `hilight_wave`, and every count either held or
GREW — nothing was silently dropped or rewritten, which is the direct consequence
of D1 choosing a new token instead of changing this one. The new `sel_waves`
assertions are additional: 4 / 0 / 8 / 0 / 0 / 34. `WB*` legs: 18 (0174) → 21 →
**26** here.

## Sabotage matrix — six sabotages, six DIFFERENT leg sets

Each was applied to the shipping code, rebuilt, and run against
`test_wave_trace_menu` + `test_wave_viewer` + `test_wave_legend`.

| # | sabotage | red legs |
|---|---|---|
| **(a)** | legend query off by one slot (`rw/n * (wcnt+1)`) | `TL1` ×4, `TL2 the boundary is near 1/3 of the width`, `TL4` ×2, `TS6` slot-centre setup, `WB-legend` ×3 (RMB **and** LMB — one query, both buttons). `test_wave_legend` **green** |
| **(b)** | Ctrl+click REPLACES instead of adding | **15** `TS*` legs — `TS1` ×3, `TS2` ×5, `TS3`, `TS4`, `TS6` ×2, `TS8` ×3. `TL*` **green**, `test_wave_legend` **green** |
| **(c)** | Ctrl+click on a SELECTED trace re-adds instead of removing | `TS2` ×4, `TS6 CTRL on a selected legend entry REMOVES it`, `WB-legend second legend RMB un-bolds` — **and nothing else** |
| **(d)** | legend query fed SNAPPED coords (`mousex_snap`) | `TL1` ×4, `TL2 a 0->1 slot boundary was found`, `TL4` ×2, `TS6` setup. `test_wave_viewer` and `test_wave_legend` **green** |
| **(e)** | a PLAIN legend click adds instead of replacing | **exactly 2**: `TS6 a plain legend click COLLAPSES to that entry` and `WB-legend a second plain legend click KEEPS it selected` |
| **(f)** | the cross-strip sweep dropped | the four `TB-cross` legs (0174's own) **plus** `TS5` ×2 — the window-wide half, at both the scalar and the set level |

Three things worth reading off that table:

- **(a) and (d) are NOT the same failure.** (a) shifts the answers
  (`{-1 0 1}` where `{0 1 2}` was expected); (d) freezes them
  (`{0 0 0}` — the parked pointer's entry). `TL4`'s
  *"with the pointer parked on entry 0, a query about entry 2 says 2"* leg exists
  for nothing but (d), and it caught it with exactly the value that names the
  defect.
- **(e) turning only TWO legs red is the tight one.** Without the
  `WB-legend a second plain legend click KEEPS it selected` leg added by this
  issue it would have been ONE. That is how close the plain-legend-click rule
  came to resting on a single assertion.
- **(f) re-verifies 0174**, not just this issue: the same sweep guards both the
  scalar and the set, and the `TB-cross` legs still fail first.

`TL2`'s *"the pixel just LEFT of the boundary"* / *"the boundary pixel itself"*
pair stayed GREEN under (a): a uniform shift moves the boundary but does not
remove it. The *"near 1/3 of the width, not 1/2"* leg is what catches that, and
it is the reason the boundary block has three legs and not two.

## Suites

Full waveform battery, DISPLAY arm: **15/15**, every count as pinned
(`test_wave_snap` 59, `test_wave_grid` 80, `test_wave_empty_strips` 94,
`test_wave_markers` 712, `test_wave_clear_all` 68, `test_ase_plot` 150,
`test_wave_split_strip` 221, `test_wave_drag_preview` 46, `test_ase_persist` 109,
`test_ase_unnamed_net` 28, `test_ase_window` 166) plus the four this issue moved:
`test_wave_trace_menu` 249 → **300**, `test_wave_legend` 44 → **77**,
`test_wave_viewer` 356 → **359**, `test_wave_modes` 410 → **413**.
nogui arm **5/5**: `test_wave_legend` 33 → **66**, `test_wave_modes` 137 → **140**,
`test_wave_markers` 328, `test_wave_viewer` 48, `test_wave_trace_menu` 71.

**10× soak of the whole battery: 146/150.** (0174's was 136/150 on the same
machine.) The four non-passes are four *different* legs in three *different*
suites, each at 1-in-10, and every one of them is a documented WSLg
synthetic-gesture or keysym family that is upstream of everything changed here:

| leg | rate | why it is not this issue |
|---|---|---|
| `test_ase_plot` P4/P6 | 1/10 | the documented always-flaky ESC + wire-click Direct-Plot legs. Schematic side; never enters `waves_callback` |
| `MG13 Ctrl+Shift+4 resolves to <Control-Key-dollar>` | 1/10 | Tk keysym string resolution. No C graph code at all. Also 1/10 in 0174's soak |
| `MF1 the anchor really SLID` | 1/10 | **measured 1/10 on PRISTINE code** during 0174's control run |
| `MX9 nothing was logged` | 1/10 | a synthetic `<Key-Escape>` that arrived late, so the drag was not cancelled and the release COMMITTED the marker move (which logs). With `graph_marker_drag` still set the release is taken by the MARKER branch — the wave-select arm is the `else if` below it and never runs |

⚠ **`TG9`, the 4-in-10 pristine flake, did not fire in these ten runs.** That is
luck, not a fix — do not read it as a change.

**Zero failures in 150 runs from any leg this issue added** (`TL*`, `TS*`,
`LS*`, the retargeted `WB-legend`).

## Not verified

- ⚠ **FOUND AT EYEBALL, 2026-07-30 — the schematic SNAP GRID is still visible on
  the legend.** The user's verdict was "implementation seems ok except that the
  snap grid seems to be at play when it comes to clicking on the legend text",
  with the broader point that a viewer canvas has no business having a snap grid
  at all. **Measured immediately after the report, and it is NOT the pick
  arithmetic:** a full synthetic press+release through the production bindings
  selects the same legend entry at `cadsnap 400` as at `cadsnap 10`, and so does
  a body click. So whatever it is, it is something a REAL pointer does that a
  synthetic event does not — the motion path, a snapped readout, or the
  schematic crosshair / snap cursor being drawn over the legend band. Carried to
  **issue 0177**, prompt in
  `doc/claude/suggestions/next_session_prompt_0177.md`.
  The hollowness gap that let it ship is named there too: `TL4` asserts the
  QUERY is snap-immune and nothing drives a real gesture — or a HOVER — under a
  coarse grid.
  **CLOSED by issue 0177 (2026-07-30).** Measured mechanism: `waves_selected()`
  insets each strip rect by a margin computed in SCREEN pixels but applied to
  XSCHEM coordinates — 21.9 canvas px instead of 6.7 at the viewer's zoom — and
  that band sits on top of the legend, which `legend_slot_hit()` starts at the
  rect's own top edge. Inside it the event never reaches `waves_callback`, so
  0143's local un-snap never runs and the schematic arm paints `draw_crosshair()`
  **at** the grid-snapped mirror. Invisible on the shipped defaults, live on the
  reporter's `cadence_style_rc` (`draw_crosshair 1`, `snap_cursor 1`). Fixed by a
  per-context `no_snap` property tested at the source, plus the units conversion.
  The hollowness gap is closed by `test_wave_snap` `SNG4` (a real
  Motion→Press→jitter→Release under a 40x grid) and `SNG5` (the first hover leg
  the viewer has ever had); `TL4` itself had to be repaired, because once
  `no_snap` is armed `cadsnap` no longer perturbs that canvas and the leg would
  have gone **hollow rather than red**.
- **Pixels.** That N bold strokes and N bold-italic legend entries actually read
  as "these are selected" is eyeball-only (D4). The manual sequence is handed
  over with this issue.
- Behaviour at the `GRAPH_MAX_SEL_WAVES` cap (64 selected traces on one strip).
  The refusal is coded and logged; no leg drives it.
- The `lock=true` graph corner of D3. No fixture in the tree carries one.

## Manual sequence (this is a POINTER behaviour — the suite cannot close it)

```
src/xschem --script sky130A/cadence_style_rc --logdir /tmp
```
Open `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch`,
then its `ngspice_state1` so the viewer comes up. Get **three or more traces onto
one strip** and Fit (`f`). The legend is the row of names along the TOP of a
strip, above the plot box.

| # | do | expect | must NOT happen |
|---|---|---|---|
| 1 | click the FIRST legend name | that trace goes bold, its legend entry too | ❌ nothing happens (the old behaviour) |
| 2 | click the THIRD legend name | the third is bold, the first is thin | ❌ both bold |
| 3 | **Ctrl**-click the first legend name | **BOTH** are bold now | ❌ only one — this is the whole issue |
| 4 | **Ctrl**-click the second legend name | **three** bold | — |
| 5 | **Ctrl**-click the second name again | it goes thin, the other two STAY bold | ❌ everything un-bolds |
| 6 | plain-click the first name | **only** it stays bold — the selection collapses | ❌ the others stay bold |
| 7 | **Ctrl**-click a trace in the plot BODY | it joins the selection | ❌ it replaces it |
| 8 | **Ctrl**-click empty body space | **nothing changes** | ❌ the selection clears |
| 9 | plain-click empty body space | everything un-bolds | ❌ something stays bold |
| 10 | **two strips**: select a trace on strip 1, **Ctrl**-click one on strip 2 | both bold, on both strips | ❌ strip 1 goes thin |
| 11 | now plain-click any trace | only that one is bold, **window-wide** | ❌ the other strip stays bold |
| 12 | select two traces, then **resize the window** | both are still bold | ❌ the selection collapses to one |
| 13 | select two, then drag one to another strip | it arrives bold; the other stays bold where it was | ❌ either loses its bold |
| 14 | RMB a legend entry | it toggles, same as Ctrl+click (a context menu may also appear — pre-existing) | ❌ it clears the others |
| 15 | click in the LEFT AXIS margin (left of the y-axis numbers) | nothing changes | ❌ the selection clears |
| 16 | on an **embedded schematic graph** (`xschem_library/examples/test_ne555.sch`), click a legend name | it bolds — D5 applies everywhere | ❌ nothing, or a crash |
| 17 | on a **digital** strip (embedded graph with `digital=1`), click a legend name | it bolds — the legend is the ONLY way to select there | ❌ nothing |
| 18 | double-click a legend name on an embedded graph | the wave dialog opens, the bold state is UNCHANGED by the double-click | ❌ a trace bolds under the dialog |

Steps 3-6 are the reported ask. Step 8 is what makes Ctrl useful. Steps 10-11 are
D2. Step 12 is the persistence rule. Step 17 is the digital-strip payoff that
0174 D5 promised this issue would deliver.
