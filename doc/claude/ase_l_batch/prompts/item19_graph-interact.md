# Item 19 — graph-interact (ROUND 5 FINAL / acceptance item)

Repo: `/home/qflow/dev/xschem/claude_1/xschem`  Branch: `fluid-editing`
Baseline HEAD at scout time: **dc249553** (item 18 graph-fills-win). Build green
(`cd src && make` → "Nothing to be done for 'all'").

You are the IMPLEMENTER. Execute this prompt end-to-end: code, tests,
sabotage-verify, then ONE commit with the explicit file list at the bottom.
Read the RUNBOOK policy block (verbatim at the end) — it is non-negotiable.

The whole item is **pure Tcl in `src/wave_viewer.tcl`** plus tests + docs. **NO C
changes are needed or wanted** — the C graph engine and the input-binding table
already do everything the RMB path needs; the wheel/zoom/fit gaps are all closed
in the viewer's own Tcl binding layer.

--------------------------------------------------------------------------------
## 0. Context you must hold

- Item 18 (dc249553) made the viewer graph **fill the whole window** as equal
  full-width vertical bands, turned the schematic grid/origin chrome OFF for the
  viewer window only (`no_grid`), pinned the canvas viewport (regenerate no
  longer runs `xschem zoom_full`), and refits on `<Configure>`. **Consequence:
  the pointer is ALWAYS inside a graph band in the viewer** (`over_graph` is
  structurally always true; the C `waves_selected` agrees — both test the same
  outer band rect).
- Item 17 lesson (de-flake): **witness via a deterministic state change, not via
  Tk gesture stacking/timing.** Every assertion in this item must read a value
  the code writes synchronously (graph rect ranges, canvas origin/zoom), never a
  window-stacking or focus race.

### The user's asks (item detail, authoritative)
(a) up/down wheel scrolling in the viewer must be DEFINED and act on the GRAPH
    content; (b) RMB press+drag must zoom the graph like a schematic; plus: ALL
    zoom/pan/View>Zoom must act on GRAPH content and must **never shrink the
    graph** (i.e. never touch the canvas origin/zoom).

--------------------------------------------------------------------------------
## 1. Corrected anchors (re-verified from source at HEAD dc249553)

### src/wave_viewer.tcl (the ONLY code file you edit)
- `variable keepseqs` — **lines 116-119**:
  `<Expose> <Configure> <Visibility> <Enter> <Leave> <Motion> <Unmap>
   <MouseWheel> <Button> <ButtonRelease>`. The generic `<Button>` (kept) is what
  forwards X11 wheel Button-4/5 to the C callback today; your new, more-specific
  `<Button-4>`/`<Button-5>` binds pre-empt it.
- `variable graphkeys` — **line 107** (`97 98 115 109 116 65 66`).
- `over_graph {wp}` — **line 1431**: returns 1 when `mousex_snap/mousey_snap`
  sits inside any band bbox in `graphbb($wp)`; gated on
  `current_win_path eq $wp`. Reuse its geometry to find the pointed graph index.
- `key_filter {W T x y N K s}` — **line 1453**. Forward gate is **lines
  1463-1464**: `N==102` (f), `N==90` (Z), `N==122 && (s&4)` (Ctrl-z),
  `N>=65361 && N<=65364` (arrows) are ALWAYS forwarded; the `graphkeys` set is
  forwarded only `over_graph`. Forward call `xschem callback $W $T $x $y $N 0 0 $s`
  at **line 1470**.
- `btn3_filter {W T x y b s}` — **line 1481**. Currently: `if {![over_graph $W]}
  {return}` (**line 1482**, swallows RMB off-graph) then focus-on-press (1483) +
  `xschem callback $W $T $x $y 0 $b 0 $s` (**line 1484**).
- `strip_bindings {wp}` — **line 1505**. The SWEEP clears every canvas sequence
  not in `keepseqs` (1507-1509); then re-installs `<KeyPress>`/`<KeyRelease>` →
  key_filter, `<ButtonPress-3>`/`<ButtonRelease-3>` → btn3_filter (1510-1513),
  and `<Double-Button-{1,2,3}>` → `break` (1514-1516). **Add your wheel binds
  here, AFTER the sweep, so they survive and are the most-specific wheel binds.**
- `in_ctx {token script}` — **line 349**: `new_schematic switch` to the viewer
  canvas + `uplevel #0 $script`. Canvas-navigation wrapper (not readonly-gated).
- `with_edit {token script}` — **line 383**: switch ctx + `readonly 0` + run +
  `set_modify 0` + `readonly 1` + title/autosave restore. **Required around any
  `setprop rect`** (setprop is readonly-rejected, scheduler.c:10375).
- `fit {token}` — **line 1102**: runs `fullxzoom`/`fullyzoom` per graph inside
  with_edit (1110-1118), reads the ranges back into the model (1120-1133), then
  **`wviewer::in_ctx $token {xschem zoom_full; xschem redraw}`** at **line 1134**
  — the `xschem zoom_full` is the CANVAS reframe you must remove.
- `regenerate {token}` — **line 651**: clear_drawing + place one band rect per
  model graph, auto-zoom (fullxzoom/fullyzoom) ONLY for model graphs whose x1/x2
  or y1/y2 is `{}` (**lines 685-698**), rebuild graphbb, then `xschem redraw`
  (**line 713**, NO zoom_full — item-18 canvas-safe). Reusable as your
  apply-and-redraw path; it keeps model↔rect in sync and never reframes the
  canvas.
- `build_menubar` View cascade — **lines 1542-1549**: `Fit` → `wviewer::fit`
  (1542-1543); **`Zoom In` → `in_ctx {xschem zoom_in}` (1544-1545)** and
  **`Zoom Out` → `in_ctx {xschem zoom_out}` (1546-1547)** are CANVAS zoom (must
  become graph zoom); `Redraw` → `in_ctx {xschem redraw}` (1548-1549) is
  canvas-safe, leave it.
- Helpers you will reuse: `layout_for`, `set_graphs`, `dget`, `graph_props`.

### src/callback.c (REFERENCE ONLY — do NOT edit; explains why the RMB path already works and why forwarding the wheel is WRONG here)
- `waves_selected` :65 — sets `graph_master` :126; over-graph test POINTINSIDE
  outer rect for Button3 :109, inset for motion/dbl :114/:119; `graph_master=-1`
  when outside :134.
- `waves_callback` :540 — graph region flags `graph_top`/`graph_left`/
  `graph_bottom` set from mouse position :698-712.
- **Plain wheel over a graph (the C "graph pan" the PLAN cites as :1170/:1133)**:
  Button5/down :1133-1168, Button4/up :1170-1205. In the LEFT axis margin
  (`graph_left`) it pans **vertically** (master only); **everywhere else — i.e.
  the whole plot body — it pans HORIZONTALLY** (x1/x2 ±5%). Shift+wheel :1207 /
  :1247 = horizontal ZOOM (body). **So forwarding plain wheel gives HORIZONTAL
  pan over the body — the opposite of the user's ask (a).**
- RMB over a graph: press → GRAPHPAN start :1000-1008; motion/release compute the
  x-zoom box :1048-1059 / **release zoom-x-to-box :1454-1469** (y-box :1471). This
  changes ONLY the graph rect's x1/x2 tokens — it never touches canvas
  origin/zoom.
- `init_input_bindings` :3913 — Button3 canvas `view.zoom_rect` :3922; over_graph
  wheel `graph.forward` :3929-3932; 'f' over_graph `graph.forward` :3938; arrows
  over_graph :3945-3951.
- `handle_button_press` :6536 — **`if(waves_selected) {waves_callback; return;}`
  at :6547-6550 runs BEFORE `dispatch_button_chord` (:6600)**, so over a graph
  Button3 goes to the C graph zoom and `view.zoom_rect` (canvas) is never reached.
  Item-18 tiling ⇒ this is always the case in the viewer.
- `handle_mouse_wheel` :4393 — plain/Shift consult the context (:4411-4416);
  **Ctrl+wheel is hard-pinned to `ACTX_CANVAS` (:4417-4418)** → today Ctrl+wheel
  over a viewer graph runs the cadence_style_rc canvas `view.zoom_in/out`, i.e.
  it ZOOMS THE CANVAS (shrinks the graph). This is the bug your Ctrl+wheel row
  fixes — by owning the wheel in Tcl the C table is never consulted.

### src/cadence_style_rc (the CANVAS wheel scheme your viewer mirrors on the graph)
- **Lines 86-90**: `Ctrl+wheel → view.zoom_in/out`, `plain wheel →
  view.pan_up/down` (VERTICAL), `Shift+wheel → view.pan_left/right` (default,
  comment line 91). Your viewer wheel must feel identical to this — but act on
  the GRAPH content, not the canvas.

### Docs to update
- `doc/ase_l_tutorial.html` — "Viewer menus" View bullet **lines 370-371** + the
  note **378-379**; "Viewer keyboard" table **lines 429-439**; right-click note
  **440-441**.
- `doc/claude/specs/waveform_viewer.md` — add an **"Item 19 notes (as shipped)"**
  section (mirror the "Item 13/14 notes" style) documenting the final
  interaction scheme.

### Environment facts (verified)
- Tcl **8.6.14** → wheel arrives as X11 **Button-4 (up) / Button-5 (down)**
  ButtonPress events; `<MouseWheel>` is only generated on Tcl > 8.7. Tests run on
  this box, so `<Button-4>`/`<Button-5>` are the live path.
- `graph_use_ctrl_key` default **0** (xschem.tcl:15415) — no Ctrl needed to
  operate graphs.
- `xschem setprop rect 2 <n> <tok> <val>` sets an arbitrary rect token
  (scheduler.c:10543-10549); `xschem setprop -fast rect 2 <n> fullxzoom|fullyzoom`
  autozooms (10500-10516); `xschem getprop rect 2 <n> <tok>` reads it
  (scheduler.c:4556). setprop is readonly-gated → wrap in `with_edit`.

--------------------------------------------------------------------------------
## 2. Scout decisions (each with its one-line justification — honor them)

**D1 — Wheel is a pure-Tcl viewer handler that MIRRORS the cadence_style_rc
canvas wheel scheme, applied to GRAPH content:**
- plain wheel up/down → GRAPH **vertical** pan (shift y1/y2),
- Shift+wheel up/down → GRAPH **horizontal** pan (shift x1/x2),
- Ctrl+wheel up/down → GRAPH **zoom in/out on X** (contract/expand x1/x2).
- *Justify:* the viewer wheel must match the schematic wheel the user already
  uses (plain=vertical scroll, Shift=horizontal, Ctrl=zoom) but act on the graph;
  forwarding to the C waveform-wheel instead gives HORIZONTAL pan on plain wheel
  (callback.c:1157-1168) and routes Ctrl+wheel to CANVAS zoom (callback.c:4417) —
  both contradict the user. Pure-Tcl `setprop`/`getprop` keeps it deterministic
  (item-17 lesson), never touches canvas origin/zoom.

**D2 — RMB stays on the C engine; only stop the viewer from swallowing it.**
`btn3_filter` forwards Button3 press+release **unconditionally** (drop the
`over_graph` early-return). Item-18 tiling guarantees the C press→GRAPHPAN /
release→zoom-x-to-box path (callback.c:1000/1454) fires and `view.zoom_rect`
(canvas) is never reached. *Justify:* the C engine already does graph
x-zoom-to-box over a graph and leaves the canvas pinned; the only fix needed is
that the viewer must not swallow RMB anywhere in the window.

**D3 — Zoom axis = X only, around the graph center (menu) / acceptable to center
for the wheel.** *Justify:* xschem's native waveform zoom (Shift+wheel body,
arrows Up/Down) is X-only; y is owned by Fit + vertical-pan. X-only keeps the
idiom and is deterministic.

**D4 — `f` = FIT (full x+y) = `wviewer::fit`; keyboard `Z`/`Ctrl-z` = graph zoom;
arrows unchanged.** `key_filter` routes `f`→`wviewer::fit`, `Z`→`graph_zoom in`,
`Ctrl-z`→`graph_zoom out` (instead of forwarding to the C canvas-zoom keys);
arrows keep forwarding (C over_graph `graph.forward` already pans/zooms the graph
X, not the canvas). *Justify:* "f = fit" means full x+y (only `wviewer::fit` does
both); `Z`/`Ctrl-z` are canvas-zoom keys that would reframe the graph, so they
must act on the graph like View>Zoom.

**D5 — `wviewer::fit` de-canvased.** Replace its trailing `xschem zoom_full;
xschem redraw` (line 1134) with `xschem redraw` only. *Justify:* fullxzoom/
fullyzoom already fit the graph data range; item-18 pins the canvas, so Fit must
not reframe it (deliverable 3/4).

**D6 — View menu Zoom In/Out act on the graph.** `Zoom In` → `wviewer::graph_zoom
$token in`; `Zoom Out` → `wviewer::graph_zoom $token out` (all graphs). `Fit` →
`wviewer::fit` (rewiring unchanged; fit itself is de-canvased by D5). `Redraw`
stays `xschem redraw` (canvas-safe). *Justify:* deliverable 4 — View>Zoom must
act on graph axes, never the canvas.

**D7 — Range writes FREEZE all four axes.** Any pan/zoom reads the current
concrete `{x1 x2 y1 y2}` (via getprop rect), applies the delta to the target
axis, and writes ALL FOUR back into the model as concrete values before
regenerate/redraw. *Justify:* if an untouched axis were left `{}` (auto),
regenerate would re-autozoom it and wipe a prior pan/zoom on the other axis
(e.g. vertical-panning would reset a prior horizontal zoom). Freezing mirrors
what Fit already does with its read-back.

--------------------------------------------------------------------------------
## 3. Deliverables (exact)

### D-A  New pure-Tcl helpers in `wave_viewer.tcl`
1. `wviewer::graph_at_pointer {wp}` → index of the band under
   `mousex_snap/mousey_snap` (iterate `graphbb($wp)` exactly like `over_graph`);
   fallback `0` when none/one graph. (Used by the wheel, which acts on the
   pointed graph.)
2. `wviewer::graph_range {token gi}` → switch to the viewer ctx and return
   `{x1 x2 y1 y2}` from `xschem getprop rect 2 $gi <tok>`; each element `{}` when
   the token is empty or not a finite number (`string is double -strict`). This
   is the current DRAWN range (concrete after regenerate's autozoom).
3. `wviewer::apply_range {token gi x1 x2 y1 y2}` → write the four concrete values
   into model graph `gi` (`dict replace`, keep `{}` for any axis passed `{}`) +
   `set_graphs`, then re-render **without touching the canvas**: either
   `regenerate` (simplest — item-18 canvas-safe, keeps model↔rect sync) OR the
   lighter `fit`-style path (`with_edit { setprop -fast rect 2 gi <axis> <val>
   for each non-{} axis }` then `in_ctx {xschem redraw}`). Either is acceptable
   **iff** canvas xorigin/yorigin/zoom are provably unchanged.
4. `wviewer::wheel {token wp dir mods}` (`dir` ∈ up|down, `mods` ∈ 0|shift|ctrl):
   pick `gi = graph_at_pointer wp`; read `graph_range`; compute per D1/D3:
   - `0`   (plain): `span=y2-y1`; `d = ±0.05*span` (up = pan toward larger y or
     smaller — pick a sign and be consistent; document it); new `y1,y2 = y1+d,
     y2+d`. If `y1|y2` is `{}` → no-op (nothing to pan).
   - `shift`: `span=x2-x1`; `d=±0.05*span`; new `x1,x2 = x1+d, x2+d`.
   - `ctrl`: `span=x2-x1`; `c=(x1+x2)/2`; up → shrink (`span*=0.8`), down → grow
     (`span/=0.8`); new `x1,x2 = c-span/2, c+span/2`. If `x1|x2` is `{}` → no-op.
   Then `apply_range` with all four axes concrete (freeze, D7).
5. `wviewer::graph_zoom {token dir {gi all}}` (`dir` ∈ in|out): for the target
   graph(s), X-only zoom about center like the ctrl-wheel case (`in`→shrink,
   `out`→grow); `apply_range` per graph (freeze all four). `gi all` = every model
   graph (View menu has no pointer).

### D-B  Wire the bindings/menus
- In `strip_bindings`, AFTER the sweep + existing filter installs, add (each body
  ends with `break`):
  `<Button-4>`→`wviewer::wheel <tok> $wp up 0`, `<Button-5>`→`... down 0`,
  `<Shift-Button-4>`→`... up shift`, `<Shift-Button-5>`→`... down shift`,
  `<Control-Button-4>`→`... up ctrl`, `<Control-Button-5>`→`... down ctrl`.
  `strip_bindings` takes only `wp`; resolve `<tok>` via
  `wviewer::token_for_canvas $wp` inside the handler, OR bind through a tiny
  shim `wviewer::wheel_bind {wp dir mods}` that looks up the token — DO NOT
  capture a stale token at bind time. (Portability, optional, tests are X11:
  also bind `<MouseWheel>`/`<Shift-MouseWheel>`/`<Control-MouseWheel>` mapping
  `%D>0`→up else down.)
- `key_filter`: before the current forward, intercept and RETURN (do NOT forward)
  for: `N==102` (f) → `wviewer::fit <tok>`; `N==90` (Z) →
  `wviewer::graph_zoom <tok> in`; `N==122 && (s&4)` (Ctrl-z) →
  `wviewer::graph_zoom <tok> out`. Guard: act on `KeyPress` only (`T==2`) so the
  matching `KeyRelease` is swallowed, and resolve `<tok>` via
  `token_for_canvas $W`; if `{}`, fall through to the old behavior. Leave the
  arrow forward (1463-1464 arrow arm) and the `graphkeys` over-graph forward
  intact.
- `btn3_filter`: remove the `if {![over_graph $W]} {return}` early return so
  Button3 press+release always forward (keep the press-focus and the
  `xschem callback` forward). Add a one-line comment: item-18 tiling makes the
  pointer always over a graph, so this always hits the C graph zoom, never
  `view.zoom_rect`.
- `fit`: line 1134 `xschem zoom_full; xschem redraw` → `xschem redraw`. Update
  the proc's doc comment (drop "canvas zoom_full").
- `build_menubar` View cascade: `Zoom In` command →
  `[list wviewer::graph_zoom $token in]`; `Zoom Out` →
  `[list wviewer::graph_zoom $token out]`. Leave Fit and Redraw.

### D-C  Tests (append to `tests/headless/test_wave_viewer.tcl`, DISPLAY-guarded)
Prefix the block `IX` (interact). Setup (deterministic, no gesture timing): open
the viewer for the fixture ASE session; create ONE model graph with a trace and
KNOWN concrete ranges via `wviewer::set_graphs` (e.g. `x1 0 x2 10 y1 -1 y2 1`) +
`regenerate`; confirm `getprop rect 2 0 x1/...` returns those numbers. Capture a
canvas baseline in the viewer ctx: `set cx0 [xschem get xorigin]`,
`cy0 [xschem get yorigin]`, `cz0 [xschem get zoom]`. Named checks (each asserts
BOTH the intended graph-range change AND `xorigin/yorigin/zoom == baseline` — the
graph-not-canvas teeth):
- **IX-vpan-up / IX-vpan-dn** — `wviewer::wheel $tok $wp up 0` / `down 0`: y1 AND
  y2 shift by the same nonzero delta (opposite signs for up vs down); x1/x2
  unchanged; canvas == baseline.
- **IX-hpan** — `wviewer::wheel $tok $wp up shift`: x1/x2 shift; y1/y2 unchanged;
  canvas == baseline.
- **IX-zoom-in / IX-zoom-out** — `wviewer::wheel $tok $wp up ctrl` / `down ctrl`:
  `(x2-x1)` strictly smaller / larger; canvas == baseline.
- **IX-menu-zoomin / IX-menu-zoomout** — `wviewer::graph_zoom $tok in` / `out`
  (the View-menu command): x-span shrinks / grows on the graph; canvas ==
  baseline.
- **IX-fit** — perturb ranges, then `wviewer::fit $tok`: **canvas == baseline**
  (the removed-`zoom_full` teeth — the PRIMARY assertion, holds with or without
  raw). If a raw is loaded in the fixture, also assert the ranges become the
  fullzoom result.
- **IX-rmb** — deterministic synthetic sequence (no Tk button events): compute a
  body point of band 0 (inside the plot area, NOT the left/top margin — well
  inside `viewport_rect`/band, mid-height), press then release Button3 at two
  different x pixels via `xschem callback $wp 4 $px1 $py 0 3 0 0` (ButtonPress)
  and `xschem callback $wp 5 $px2 $py 0 3 0 0` (ButtonRelease); assert `getprop
  rect 2 0 x1/x2` narrowed toward the box AND canvas == baseline. Reinforce with
  a routing note that `btn3_filter` forwards (state change proves it). If the C
  GRAPHPAN geometry proves WSLg-flaky, keep IX-rmb but add a fallback that drives
  `wviewer::btn3_filter` directly and asserts the same rect-x state change.

Run: `DISPLAY=:0 src/xschem --pipe -q --nolog --script tests/headless/test_wave_viewer.tcl`
(repo-root cwd). All prior test_wave_viewer checks + your IX block must be
`RESULT: ALL PASS`. Without a display the file self-SKIPs (existing guard).

### D-D  Docs
- `doc/ase_l_tutorial.html`: in "Viewer keyboard" set `f` = "fit (full x+y)";
  keep Z/Ctrl-z but note they zoom the **graph** (not the canvas); add a new
  small **"Viewer mouse / wheel"** table: plain wheel = vertical pan (graph),
  Shift+wheel = horizontal pan (graph), Ctrl+wheel = zoom in/out (graph X),
  right-drag = zoom box (graph). Update the View-menu bullet/note to say Fit /
  Zoom In / Zoom Out act on the graph and never reframe the window.
- `doc/claude/specs/waveform_viewer.md`: add "Item 19 notes (as shipped)"
  documenting: the wheel mirrors the cadence_style_rc canvas scheme on graph
  content (plain=vertical pan, Shift=horizontal pan, Ctrl=X zoom); RMB forwards
  everywhere → C graph x-zoom-to-box; f=fit(x+y)/Z/Ctrl-z=graph zoom; View menu
  de-canvased; the graph-not-canvas invariant (canvas origin/zoom never change);
  and that this is pure Tcl (no C touched).

--------------------------------------------------------------------------------
## 4. Sabotage plan (≥2 mandatory; each must fail EXACTLY its target, others green)

- **S1 (wheel vertical)** — in `wviewer::wheel`, make the plain/vertical branch a
  no-op (`return` before `apply_range`). Expect: ONLY IX-vpan-up/IX-vpan-dn FAIL;
  IX-hpan / zoom / menu-zoom / fit / rmb GREEN.
- **S2 (fit canvas teeth)** — re-insert `xschem zoom_full;` before `xschem redraw`
  in `wviewer::fit`. Expect: ONLY IX-fit's canvas-stability assertion FAILS
  (canvas zoom changes); every range assertion + all other IX checks GREEN.
  Proves the graph-not-canvas teeth are real.
- **S3 (recommended, RMB)** — restore `btn3_filter`'s unconditional early
  `return`. Expect: ONLY IX-rmb FAILS (rect x unchanged); everything else GREEN.

Revert deviation (same as items 15-18): the feature is UNCOMMITTED at sabotage
time, so revert each sabotage with a **targeted reverse-Edit** (NOT
`git checkout -- src/wave_viewer.tcl`, which would wipe the whole uncommitted
feature); confirm sabotage-only via `git diff` before/after; clean re-run GREEN.

--------------------------------------------------------------------------------
## 5. Acceptance gate (this is the ROUND-5 acceptance item)

- `test_wave_viewer` GREEN (all prior + IX block), direct GUI run.
- The 11 protected ASE/wave suites must stay GREEN (assertion updates, if any,
  justified in the receipt): `test_ase_{core,view,window,dialogs,final,interact,
  plot,persist,launch,dirty}` + `test_wave_viewer`. `test_ase_core` and
  `test_ase_final` are the two `--nogui` suites (run them with `--nogui`).
- `tests/headless/full_audit.sh` (DISPLAY=:0): every FAIL must be a **strict
  subset** of the batch-start baseline (below). ZERO non-baseline failures.
- `cd src && make` stays green (you touch no C, so this is trivially true — DO NOT
  edit any `.c`/`.h`).

Baseline full_audit fails (pre-existing, the ONLY tolerated fails):
FAIL: test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste, test_fluid_editing,
test_hi_descend, test_launch_context, test_lib_manager_gui, test_lib_sweep,
test_palette, test_phase3_mints, test_pin_type_edit, test_reopen_readonly,
test_select_at, test_selflog_output, test_verb_noun_copy_move, test_wire_split,
test_wire_vertex_grab. TIMEOUT: test_key_graph_context.
Known WSLg gesture flakes (rerun-first, NOT regressions): test_deselect_mode,
test_hover_highlight, and test_ase_plot P4/P6/ESC gesture legs. SKIPs are fine.

--------------------------------------------------------------------------------
## 6. Commit (ONE commit, explicit file list — NO C files)

Stage EXACTLY these four, then commit:
- `src/wave_viewer.tcl`
- `tests/headless/test_wave_viewer.tcl`
- `doc/ase_l_tutorial.html`
- `doc/claude/specs/waveform_viewer.md`

`git add` them by name (NEVER `git add -A` / `commit -a`). Do NOT stage
`doc/claude/ase_l_batch/*` (ledger agent's job), `PLAN.md`, or any pre-existing
dirty tracked file (PLAN preflight: `doc/claude/specs/sky130_workarea.md`,
`sky130A/xschem_libs/library.defs`, `src/ciw.tcl`,
`tests/headless/test_sky130a_libmgr.tcl`, `tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`).
Do NOT register the test in `tests/run_regression.tcl` (dirty pre-batch;
full_audit.sh auto-discovers `test_*.tcl`).

Commit message: normal prose subject like
`feat(ase): Waveform Viewer wheel/RMB/zoom act on the graph, not the canvas (item 19 graph-interact)`
with a short body listing the wheel scheme, RMB, f/Z/View-zoom de-canvasing, and
"pure Tcl, no C". End with the Co-Authored-By trailer per repo convention.

--------------------------------------------------------------------------------
## RUNBOOK — Policies (non-negotiable), copied verbatim

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.

NOTE on the RUNBOOK revert clause: it says revert via `git checkout -- <file>`.
That clause assumes committed-then-sabotaged. This item sabotages the UNCOMMITTED
working tree (feature not yet committed), so — exactly as items 15/16/17/18 did —
revert sabotages by targeted reverse-Edit and confirm sabotage-only via
`git diff`; a `git checkout` there would wipe the whole uncommitted feature. Same
guarantee (file holds nothing but the sabotage before revert; clean re-run green).
