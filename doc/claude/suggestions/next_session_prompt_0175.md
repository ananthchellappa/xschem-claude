# Issue 0175 — select a trace by clicking its LEGEND text, and hold more than one
# trace selected (Ctrl-click add / remove)

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
**0174 HAS SHIPPED** (2026-07-30, commits `a094552a` + `7e6272c9`, unpushed).
Read `doc/claude/issues/0174-trace-pick-needs-proximity.md` FIRST for what the
LMB body arm now does — in particular its defect (d) and D2/D3, which were
reversed at review and are the ground this issue builds on. Never push.

## The asks, as reported

> We also want to be able to select a trace by clicking on the legend text. Goes
> without saying that CTRL-click should add an unselected trace to the selection
> and CTRL-click on a selected trace should deselect it.

Two things, and the second is the one with teeth: **today the selection cannot
hold two traces at all.**

⚠ **What 0174 round 2 already settled, so you do not re-decide it** (its review
produced the plain-click rules directly):

> clicking on a selected trace should not deselect it
> clicking on empty space SHOULD deselect all currently selected traces
> clicking on another trace SHOULD deselect all currently selected traces
> if a few traces are selected and user clicks on A trace, then, only the
> recently clicked-on trace will be selected.
> It takes a CTRL+click to add to selection.
> CTRL+Click on a selected trace will also deselect that trace.

The first three are SHIPPED (0174, incl. the cross-strip sweep). The last three
are THIS issue. Note what that means for the plain click once multi-select
exists: it must **collapse** the selection to the one trace clicked — which the
current one-assignment arm plus the cross-strip sweep already does for a scalar,
and which whatever D1 picks must preserve.

## The recon is done. VERIFY it, do not re-derive it

### 1. Legend hit-testing is NOT missing. It is shipped, and fused to the wrong button

Two comments in the tree claim otherwise and **both are stale — correct them as
part of this issue**:

- `wave_viewer.tcl` ~76: *"canvas legend click-select has no C hit-test API"*
- `wviewer::delete_dialog` ~5148: *"canvas-legend click-select has no C hit-test
  API (receipts/11: rect descriptors carry no coordinates)"*

What is actually true: no **standalone query** is exposed. The hit test exists,
inside `edit_wave_attributes(what, i, gr)` (`draw.c` ~4291-4420), which walks the
`node` token and tests three legend layouts. The ASE viewer's horizontal legend
is the third branch (`draw.c` ~4378):

```c
double xt1 = gr->rx1 + 2 + gr->rw / n_nodes * wcnt;
double yt1 = gr->ry1;
double xt2 = xt1 + gr->rw / n_nodes;
double yt2 = gr->y1;
if(POINTINSIDE(xctx->mousex_snap, xctx->mousey_snap, xt1, yt1, xt2, yt2)) {
```

**Fixed per-node slots** — the same geometry the legend DRAW uses
(`draw.c` ~4142: `gr->rx1 + 2 + gr->rw / n_nodes * wcnt`), so the two cannot
drift. `what == 1` opens the wave dialog (`graph_edit_wave`); **`what == 2`
toggles `hilight_wave` for the entry under the pointer** — and it compares the
right thing:

```c
if(gr->hilight_wave == wcnt) { gr->hilight_wave = -1; } else { gr->hilight_wave = wcnt; }
```

It is wired only to `callback.c` ~896, a **Button3 PRESS outside the plot body**.
Issue 0152 records the state of play: *"RMB on the legend still toggles bold for
the trace ... legend LMB does not"*. So **legend selection already works on the
wrong button.**

⚠ **Two coordinate gotchas, both real:**
- It tests `xctx->mousex_snap / mousey_snap` — **GRID-SNAPPED** coordinates. With
  snap on, the legend hit box is being tested against a snapped point, not the
  pointer.
- `rx1 / ry1 / rw / rh` are **XSCHEM coordinates** (`xschem.h` ~1067: *"container
  rectangle, xschem coordinates"*), while `graph_plotbox_at` / `graph_wave_at`
  compare **screen pixels** via `S_X`/`S_Y`. **The two picking surfaces of one
  strip do not share a coordinate space.** A pixel-taking legend query must
  convert with `X_TO_SCREEN`/`Y_TO_SCREEN`, and landmine 4 applies (the macros
  need `gr` in scope).

### 2. The selection cannot hold two traces — this is the real work

`hilight_wave` is a **single int** in the graph rect's prop token:

- parsed at `draw.c` ~3740 (`get_tok_value(..., "hilight_wave")`, else -1);
- compared with `==` in **14 places** in `draw.c` (~2907/2914 the trace stroke,
  ~4062-4235 the per-node draw, ~4130-4145 the legend face incl. the
  `legendbold` bold-vs-bold-italic distinction from viewer plan item 1,
  ~4328+ inside `edit_wave_attributes`);
- **persisted in the `.sch`/`.sym` prop string**, so it is shared with every one
  of the **~127 embedded schematic graphs** in the tree and with the SVG/PS
  export paths (`svgdraw.c`, `psprint.c`);
- `graph_marker_sel` is likewise a single int.

**There is no multi-select precedent anywhere in the waveform subsystem.** That
is the whole risk in this issue, and it is D1.

## READ FIRST

1. `doc/claude/issues/0174-*.md` — what the body pick now does, and its `tol`.
2. `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — **landmine 34**
   (NODE vs MODEL index: `hilight_wave`, `graph_trace_at` and any legend query all
   speak NODE; `node_index_of_trace` / `trace_index_of_node` / `node_count` are the
   mapping and every crossing goes through them; a `vec`-less trace occupies a
   model slot and no node slot), **landmine 33**, **landmine 19** (selection is
   view state: no dirty, no undo), **landmines 11 + 37** (a query uses a LOCAL
   `Graph_ctx` and brackets the hcursor bits), **landmine 39** (a rect's
   `prop_ptr` is duplicated by TWO paths — matters if you add a token),
   **landmine 42** (0173: switching context into a viewer is a loan —
   `enter_ctx`/`leave_ctx`, never a bare `new_schematic switch`).
3. `doc/claude/issues/0152-graph-rmb-bolds-wave.md` — the `WB*` table, including
   the `WB-legend` row (*"legend RMB still bolds that trace / un-bolds; legend LMB
   does not"*), which this issue changes.
4. `doc/claude/specs/waveform_viewer_modes.md` §12.5 **"Bindings and interaction
   ownership"** — and §12/§13 for what LMB and drags already own.
5. `wave_viewer.tcl`'s header, **D2 (the binding sweep)** — `strip_bindings`
   clears every sequence on the viewer canvas except a keep-set, then installs
   `key_filter`. Anything you bind lives with that.

## Seams — compose, do not reinvent

| what | where | note |
|---|---|---|
| `edit_wave_attributes(2,...)` | `draw.c` ~4291 | the shipped legend hit test + per-entry toggle, three layouts (vlegend / digital / horizontal) |
| legend draw geometry | `draw.c` ~4142 | the slot formula the query must match |
| `graph_plotbox_at` | `draw.c` ~4813 | **the shape to copy** for a new pixel-taking query: LOCAL `Graph_ctx`, hcursor bits bracketed, fails closed |
| `graph_wave_at` / `xschem get graph_trace_at` | `draw.c` ~4790 / `scheduler.c` ~3848 | 0174's body pick |
| `node_index_of_trace` / `trace_index_of_node` / `node_count` | `wave_viewer.tcl` ~2984-3024 | PURE index mapping |
| `wviewer::trace_menu_pick` | ~5587 | fail-closed gate pattern |
| `wviewer::with_edit` | ~862 | mutation bracket (prop writes) |
| `wviewer::enter_ctx` / `leave_ctx` | ~816 / ~837 | the 0173 read bracket |
| `legendbold` / `legendmag` | `wave_viewer.tcl` ~1199-1216, `draw.c` ~4130 | the legend's existing per-rect tokens, and the **bold-italic** cue that already distinguishes the selected entry when `legendbold` is on |

## Decisions to make BEFORE writing code — answer them in the spec

- **D1 (THE decision): what represents a multi-trace selection?**
  - **(a)** `hilight_wave` becomes a space-separated LIST of node indices, with
    one `wave_is_hilighted(gr, wcnt)` helper replacing all 14 `==` comparisons.
  - **(b)** a bitmask int (caps traces per strip at 32/64).
  - **(c)** a NEW token, e.g. `sel_waves=`, leaving `hilight_wave` alone as
    "the one bold trace" for the embedded graphs and the export paths.

  **My recommendation is (c)**, with `hilight_wave` kept as a derived
  convenience (say, the first element) if anything still needs a scalar —
  because (a) and (b) change the meaning of a token **persisted in every existing
  `.sch` that carries a graph**.

  **You must state explicitly, in the spec:** what an existing
  `hilight_wave=3` file renders as under your choice; what a file written by the
  new code renders as in an older build; and, if you pick (a), how the `-1`
  "none" sentinel coexists with a list. A silent format change here is the worst
  outcome available in this issue.
- **D2: is the selection per-STRIP or per-WINDOW?** ✅ **ALREADY SETTLED — by
  0174 round 2, so this is no longer an open question, only a constraint.**
  `hilight_wave` is still stored per-rect, but the SELECTION is now **one trace
  per WINDOW**: the LMB body arm clears the token on every other graph rect, so a
  plain click on strip B de-selects whatever was bold on strip A. It was reported
  at 0174's review — "clicking on another trace SHOULD deselect all currently
  selected traces ... It is currently true only if the two traces are within the
  same strip" — and measured as `{0 0}` (both strips bold) before the fix.
  So: **window-wide selection, stored per-strip, queried as a fold** is what
  exists. Ctrl-click across strips must ADD to that fold rather than reset it, and
  the plain-click sweep in `callback.c` is the code you are extending, not
  replacing. ⚠ Whatever multi-selection representation D1 picks, the sweep has to
  keep working: it currently walks `xctx->rect[GRIDLAYER]` writing
  `hilight_wave=-1`, and treats an ABSENT token as "nothing bold" (never as node
  0 — `atoi("")` would say 0). See
  `doc/claude/issues/0174-trace-pick-needs-proximity.md` defect (d).
- **D3: is Ctrl+Button1 actually free on the viewer canvas?** ⚠ **Measure this,
  do not assume.** Issue 0149 swallowed Shift+B1 and Alt+B1 outright; `strip_bindings`
  sweeps the canvas; `waves_selected` (`callback.c`) has deliberate Button2 and
  Shift+Button1 skips whose ordering against the `semaphore>=2` gate is
  load-bearing (**landmine 8** — "don't simplify them"). Check what Ctrl+B1 does
  today in both the viewer and an embedded schematic graph, and report it.
- **D4: how is a multi-selection DRAWN?** One bold trace is the current cue. Two
  bold traces is fine for the strokes, but the legend already uses bold (and
  bold-italic when `legendbold` is on, viewer plan item 1) to mark *the* selected
  entry. Say what N selected entries look like, and make sure the item-1
  `legendbold` interaction still reads. **This is a pixels decision and I will
  want to see it** — propose, do not just implement.
- **D5: does the legend LMB pick go through C or Tcl?** I recommend **extracting a
  pure query** — `graph_legend_at(i, px, py)` → NODE index or -1, LOCAL
  `Graph_ctx`, hcursor bits bracketed, **raw pixels not snapped coords**,
  mirroring `graph_plotbox_at`'s shape — exposed as `xschem get graph_legend_at`,
  and then having **both** the existing RMB arm and the new LMB arm call it. That
  deletes the duplicated slot arithmetic and makes the whole thing headlessly
  testable. Say which of the three legend layouts the query supports and what it
  returns for the others (fail closed → -1).
- **D6: legend LMB single-click vs the existing double-click dialog.** Legend
  double-click opens `graph_edit_wave` (`callback.c` ~1199). The viewer swallows
  double-clicks wholesale (header D9: `graph_edit_properties`' writeback is
  readonly-rejected). Say what happens in the viewer and what happens in an
  embedded schematic graph, and make sure a single-click select cannot eat the
  double-click where the double-click still lives.
- **D7: does legend RMB keep its current meaning?** It toggles bold today and
  there is also an RMB trace context menu (item 7) posted from the plot body. Two
  RMB meanings on one strip is already the status quo; say whether legend RMB
  becomes "the context menu for that trace" or stays a bold toggle.
- **D8: does a selection change log?** The bold toggle logs nothing today.
  A multi-select is still view state (landmine 19), so I lean **no logging** —
  but 0176 will want to replay a delete, so say how a replayed
  `wviewer::delete_traces` names its targets without depending on selection state
  at replay time (explicit indices, the 0151 precedent).

## Hard constraints

- **Landmine 19: selection is view state.** No `set_modify`, no undo push, for
  select/deselect.
- **Do not regress the ~127 embedded schematic graphs**, the SVG export or the PS
  export. If `hilight_wave`'s meaning changes, those paths change with it.
- **Landmine 34: everything here speaks NODE index.** The model, menus and delete
  speak MODEL. Cross only through the three pure procs.
- **Digital and bus strips**: `graph_wave_at` answers -1 across their body, so the
  legend may be the only way to select there (see 0174's D5). Make sure the
  legend query does NOT inherit that limitation — the `digital` branch of
  `edit_wave_attributes` has its own working hit box (`draw.c` ~4345).
- **Landmine 39**: a rect's `prop_ptr` is duplicated by two paths. If you add a
  token, follow what `active` / `markers` / `legendbold` already do, and check
  `wviewer::graph_props` emits it in the documented byte-deterministic order.
- **Persistence**: decide whether the selection survives a session save/restore
  (`wviewer::snapshot` / `restore`). I lean **no** — selection is transient, like
  the drag state, and §14 says a saved layout carries state, not history. But
  `hilight_wave` IS persisted today, so say what changes.

## ⚠ THE HOLLOWNESS TRAP

1. **Multi-select legs must assert the SET, not the count.** `{0 2}` and `{0 1}`
   are both "two selected", and a leg that checks `llength == 2` passes on the
   wrong one.
2. **Ctrl-click deselect must be driven from a ≥2-element selection**, so
   "removed the right one" is distinguishable from "cleared everything". From a
   1-element selection those two are identical.
3. **The legend query needs an OFF-BY-ONE leg**: click near a slot BOUNDARY and
   assert which entry wins, on a strip with ≥3 traces. A single-trace strip has
   one slot spanning the whole width and proves nothing about the arithmetic.
4. **Assert the query is fed RAW pixels**, not snapped: with grid snap on, a
   click that snaps into a neighbouring slot must still select the entry actually
   under the pointer. This is the leg that catches the `mousex_snap` inheritance.
5. **A `vec`-less trace must be in the fixture** so MODEL and NODE indices differ
   (landmine 34). Otherwise every index-space bug passes.
6. **Count the `WB*` legs and every `getprop ... hilight_wave` assertion before
   you start** — if D1 changes the token, all of them change, which is expected,
   but a silent drop must be visible. Today: `test_wave_modes` 28 mentions,
   `test_wave_markers` 26, `test_wave_trace_menu` 27, `test_wave_split_strip` 12,
   `test_wave_viewer` 8, `test_wave_legend` 0. (trace_menu went 18 -> 27 with
   0174's `TB*` block; its `TB-cross` legs witness the WHOLE STACK via
   `tb_bolds`, and a per-strip token needs exactly that — a single-rect witness
   is how 0174's cross-strip defect hid from a green suite.)
7. Sabotage-verify, each turning **different** legs red: (a) legend query off by
   one slot; (b) Ctrl-click replaces instead of adds; (c) Ctrl-click on a selected
   trace re-adds instead of removing; (d) legend query fed snapped coords;
   (e) plain legend click adds instead of replacing; (f) cross-strip selection
   silently dropped.

## Tests

- `tests/headless/test_wave_trace_menu.tcl` (**249** / **71**) — owns hit-test
  gating and fail-closed rungs. The legend query and its refusals go here.
- `tests/headless/test_wave_viewer.tcl` (**356** / **48**) — owns the `WB*`
  selection legs. Multi-select and Ctrl-click go here.
- `tests/headless/test_wave_legend.tcl` (**44** / **33**) — owns legend geometry
  and `legendmag`/`legendbold`. The D4 drawing-cue plumbing goes here.
- `tests/headless/test_wave_modes.tcl` (**410** / **137**) — owns multi-trace
  strips and the index mapping.

Full battery, must stay green at these counts (DISPLAY / nogui):
`test_wave_snap` 59/36, `test_wave_grid` 80/44, `test_wave_legend` 44/33,
`test_wave_empty_strips` 94/28, `test_wave_modes` 410/137,
`test_wave_markers` 712/328, `test_wave_viewer` 356/48,
`test_wave_clear_all` 68/3, `test_ase_plot` 150/30,
`test_wave_trace_menu` 249/71, `test_wave_split_strip` 221/80,
`test_wave_drag_preview` 46/18, `test_ase_persist` 109/17,
`test_ase_unnamed_net` 28/28, `test_ase_window` 166/31.
(These ARE the post-0174 numbers, measured 2026-07-30 — 0174 took
`test_wave_viewer` 349 -> 356 and `test_wave_trace_menu` 223 -> 249.)

⚠ **Known WSLg flakes — measured on PRISTINE code, do not chase them.**
`test_ase_plot`'s gesture legs (P4/P6/P8/P9) flake 1-2 in 10 and always have.
`test_wave_trace_menu`'s `TG9 it was posted in ROOT coordinates` flakes **4 in
10** (measured against a pristine worktree). `test_ase_window`'s `W3`/`W6c` and
`test_wave_markers`' `MF0`/`MF1` flake ~1 in 10. All are synthetic-gesture,
focus, or scan-found-nothing failures. If one goes red, judge whether the leg is
upstream of what you touched, then re-run — do not "fix" it.

⚠ **A green line is not a green suite — read the check COUNT.** When WSLg stops
mapping toplevels, every GUI leg self-SKIPs and the suite still prints
`RESULT: ALL PASS`, at 73 checks instead of 356. This wasted a verification pass
during 0174.
Judge upstream/downstream, then re-run.

## Process

`tests/headless/run_suites.sh` with `SUITE_TIMEOUT=900`, never a bare loop.
**Soak the DISPLAY arm 10x.** Then **build → suites green → COMMIT → raise
`tools/review_gate/review_gate.sh` in the background.** Never push.

⚠ **D1 and D4 are decisions I want to see before they are load-bearing.** If the
selection model or the multi-select drawing cue is a coin-flip, raise the gate
with the question rather than building both. And the final verdict here is an
eyeball: hand me the manual sequence (which legend entries to click, in what
order, with and without Ctrl) and what should look selected at each step.

## Docs to update

- **New issue file** `doc/claude/issues/0175-trace-legend-click-and-multiselect.md`
  — the stale-comment correction, D1 with its **file-format compatibility
  statement**, and the measured answer to D3 (is Ctrl+B1 free).
- `doc/claude/issues/0152-graph-rmb-bolds-wave.md` — the `WB-legend` row
  (*"legend LMB does not"*) is now **superseded**. Mark it, do not delete it.
- `doc/claude/specs/waveform_viewer_modes.md` — a **trace SELECTION** section next
  to §12/§13, with the full LMB/RMB ownership table for the viewer canvas
  (body pick, legend pick, strip drag, trace drag, cursor grab, box-zoom, context
  menus) — that table is the thing future work will read.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — **add a
  landmine**: *"the legend HAS a C hit test, but it is fused into
  `edit_wave_attributes`' action and keyed off grid-SNAPPED XSCHEM coordinates,
  while the trace hit test takes RAW SCREEN pixels — the two picking surfaces of
  one strip do not share a coordinate space."* Plus whatever D1 makes true about
  `hilight_wave`.
- Correct the two stale "no C hit-test API" comments in `wave_viewer.tcl` (~76 and
  ~5148).
- If D1 changes a persisted token, `XSCHEM_FILE_VERSION` deserves a thought and
  the spec needs the compatibility statement.
