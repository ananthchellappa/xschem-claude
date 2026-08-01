# OVB-03 — LMB press-and-drag in an axis-number region zooms that axis only

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are the
**implement** stage of overnight batch 2026-08-01 item **03**. The scout verdicted
**PROCEED** and re-verified every anchor below from source on **2026-08-01**, at
HEAD `1ec3ce89` (item 02's commit).

The shape (decided — do **not** re-litigate; the reasoning is in the decision doc):
the gesture lives in the **C engine**, beside the RMB box zoom it is the twin of.
Three new `draw.c` functions — `graph_axis_at()` (which margin is this pixel in),
`graph_axis_map()` (THE formula, in exactly one place) and `graph_axis_zoom()`
(THE apply, shared by the gesture and by a new Tcl verb). `waves_callback` arms on
the press, paints a `drawtemprect` band on motion and commits on the release. The
ASE viewer needs **one** rung, and it carries **no geometry**: after it has already
forwarded the press to C, it asks C whether that press armed an axis drag — the
byte-for-byte shape of the shipped `marker_grabbed` rung.

## READ FIRST (in order)

1. `doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md` — the
   decision doc. §2 is what exists today with anchors, §3 the design, §4 **all 24
   resolved spec holes (that is your contract — do not re-decide them)**, §5
   **seven PLAN.md claims source refutes or corrects — read these before trusting
   the PLAN notes**, §6 the collision map, §7 the invariants, §8 the test plan.
2. `doc/claude/code_analysis/waveform_subsystem_reference.md` — the WIRING.md of
   waveforms. Landmines **3** (`cy` is NEGATIVE — `S_Y(gy1)` and `S_Y(gy2)` come
   back in the opposite order to the X pair), **11** (local `Graph_ctx`), **19**
   (a graph gesture does NOT dirty and does NOT push undo), **20** (the
   click-vs-drag anchor `graph_press_x/y` and the `-1e30` poison), **31** (the pan
   is on MMB and that is engine-wide), **33** (`graph_near_wave` ≠
   `find_closest_wave`), **35** (a picked sample's x/y are RAW, never log-space —
   and the *opposite* rule for `x1`/`x2`, see decision D-18), **36** (`graph_top` /
   the GRAPHPAN **routing** latch, and its press-time freeze), **37**
   (`setup_graph_data` is not safe as a query: the off-screen early return **and**
   the `graph_flags & (128|256)` side effect), **43** (the legend is a picking
   surface, and the XSCHEM-vs-SCREEN coordinate trap), **44** (`no_snap`, and the
   `waves_selected` border that used to be in the wrong units), **45**
   (a CREATION gate must match the FEEDBACK gate — the reason `graph_axis_map`
   exists once).
3. `doc/claude/specs/waveform_viewer_modes.md` — **§12.1** (the strip-reorder
   gesture table: *"the reorder handle (always) or empty waveform body"* — the
   sentence that makes the axis margins fair game), **§12.4/§12.5** (the press
   seam and the ownership table), **§13.1** (the "a press that grabbed a cursor
   still wins" rule you are keeping), **§14.1** (why window view state is outside
   the viewer undo snapshot), **§15.1** (the full LMB/RMB ownership table — you
   add two rows), **§15.7** (what a hover draws by region).
4. `doc/claude/specs/graph_markers.md` §7.2/§7.3 — the Button1 precedence tables
   your new arm slots into (below the marker, below the cursor grab).
5. `doc/claude/overnight_batch_2026_08_01/PLAN.md` — the header (verdict alphabet,
   spec-hole policy, run policy, PREFLIGHT baseline, universal facts, test
   discipline) and the `## 03 axis-region-drag-zoom` section.
6. `CLAUDE.md` — build, tests, conventions.
7. Templates you will copy from:
   * `tests/headless/test_wave_markers.tcl:2002` (`mp_band`) and `:2011`
     (`mp_box`) — **the plot-box scanner**: never predict pixels from the rect,
     ask the engine and walk out to the edges. Your margin scanner is its sibling.
   * `tests/headless/test_wave_markers.tcl:1767-1799` — the **`--logdir` child
     process** pattern, the only honest way to assert a C self-logged line from a
     `--nolog` suite.
   * `tests/headless/test_wave_trace_menu.tcl:476-489` — the hermetic
     `xschem raw new` / `raw add` fixture (no ngspice, no `.raw` file).
   * `tests/headless/test_wave_snap.tcl:40` (`count_code`) and
     `tests/headless/test_wave_legend.tcl:264-282` (`LS5`) — the source-level
     "this appears exactly once / never bare" leg.

## DISCIPLINE (non-negotiable)

* **Re-verify every anchor below from source before editing.** Line numbers drift
  and the PLAN notes for this item contain claims source refutes (decision doc
  §5). A claim you cannot reproduce is a finding for your summary, not a blocker.
* **A green suite does not prove the changed code ran.** Every named sabotage in
  §9 must fail **exactly** its stated kill list, be reverted with a targeted
  `git checkout -- <file>` **only after** `git diff` confirms that file holds
  nothing but the sabotage, and the clean re-run must be green.
* **C89**: declarations at block top, `/* */` comments only in `.c`/`.h`, no `//`.
  Allocations use `my_malloc`/`my_strdup`/`my_realloc` with the literal
  `_ALLOC_ID_` placeholder — never hand-numbered. (The prop writes use
  `my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(...))`, like every neighbour.)
* **`my_snprintf` does not understand `%.*g`** (PLAN universal facts). `log_action`
  is a plain varargs printf, so `%.17g` is fine *there*; anywhere else use `dtoa`
  / `dtoa_eng` as the neighbouring code does.
* **New `xschem get` keys and new top-level verbs are letter-dispatched.**
  `graph_axis_at` / `graph_axis_map` / `graph_axis_drag` all start with `g`, so
  they go in `xschem_cmds_g`'s `get` `case 'g':` beside `graph_plotbox_at`; the
  verb `graph_axis_zoom` goes in the same function's top-level chain beside
  `graph_coord` / `graph_marker`. A key filed in the wrong half is **silently
  unreachable** — no error.
* **Nothing in this item is `MIRRORED IN TCL`.** That is deliberate and is the
  point of D-22: the viewer asks C what it armed instead of re-deriving the plot
  box. Do not add a Tcl copy of any geometry. (Contrast
  `GRAPH_REORDER_HANDLE_W`, which *is* mirrored and carries a "change both"
  warning — leave it alone.)
* **`GUI_GATE=0`** in the environment for every suite run — overnight, nobody at
  the desk. Use `tests/headless/run_suites.sh`, never a bare `for` loop over
  `./src/xschem`.
* Git: **never** `git push`, `git reset --hard`, `git add -A`, `git commit -a`.
  Stage the explicit file list in §11 and nothing else. Do not touch the ~60
  pre-existing untracked scratch/log paths, and leave the two pre-existing dirty
  tracked files alone (`doc/claude/suggestions/next_session_prompt_0165.md`,
  `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state`).
* Scratch files go in the test's own `test_scratch` dir, never the repo root.

## ANCHORS (verified by the scout 2026-08-01 — **verify, do not trust**)

**Geometry — where the margins come from**

* `src/draw.c:3796` `void setup_graph_data(int i, int skip, Graph_ctx *gr)`.
  `:3893-3896` the screen rect `sx1/sy1/sx2/sy2`; `:3898-3899` the
  `RECT_OUTSIDE` early return (landmine 37a); `:3993-4008` the margins and the
  **plot box** `x1/x2/y1/y2` — note `x2 = rx2 - marginx*0.35` and three different
  top-edge formulas. `:3868-3876` the `x1`/`x2` parse under `if(!skip)` with
  defaults `gx1=0, gx2=1e-6`.
* `src/draw.c:4485` `static int legend_slot_hit(...)` — `:4501-4502` the
  **vertical** legend's slots are `rx1+5 .. x1-5`, i.e. **inside the left
  margin**; `:4508-4509` the digital legend's are `rx1 .. x1-20*txtsizelab`;
  `:4519-4522` only the horizontal layout is in the top band.
* `src/draw.c:4546` `int graph_legend_at(int i, double px, double py)` — the
  public wrapper. **Copy its whole shape**: local `Graph_ctx`, `memset`,
  `saveflags = graph_flags & (128|256)` … restore around `setup_graph_data`,
  `gr->scx == 0.0 || gr->scy == 0.0` ⇒ fail, SCREEN→XSCHEM as
  `px / xctx->mooz - xctx->xorigin`.
* `src/draw.c:5031` `int graph_plotbox_at(int i, double px, double py)` — the
  other shape to copy, including the landmine-3 normalisation of `S_Y(gy1)` vs
  `S_Y(gy2)`. **Note what you must NOT copy**: `:5043` requires a loaded raw and
  `:5049` refuses digital — decisions D-19/D-20 say `graph_axis_at` does neither.
* `src/draw.c:4063` `draw_cursor` — `:4077` the line spans `gr->ry1..gr->ry2`,
  `:4082` its numeric label is drawn at `gr->ry2-1`, **in the bottom margin**.
  `src/draw.c:4126` `draw_hcursor` — `:4139` the line spans `rx1+10..rx2-10`,
  `:4146` its label at `gr->rx1+5`, **in the left margin**. This is why D-3 gives
  the cursor grab priority.

**The gesture engine**

* `src/callback.c:34` `#define GRAPH_CLICK_TOL 3.0` — file-private, WORLD units
  (`* xctx->zoom`). `src/callback.c:77` `waves_selected`, `:114`
  `border = 5.0 * tk_scaling * xctx->zoom`, `:150-153` the Button3 arm that
  hit-tests the **full** rect (the inset is LMB/motion-only).
* `src/callback.c:260` `graph_marker_drag_abort();` inside `abort_operation()` —
  **where your `graph_axis_drag_abort()` goes**. The function ends at `:328` with
  `xctx->ui_state = 0; ... draw();`.
* `src/callback.c:594` `graph_marker_press`, `:605-606` its **unconditional
  reorder-grip refusal** — copy that rule into `graph_axis_at`.
* `src/callback.c:816` `waves_callback`. `:879-880` seeds `graph_press_x/y`;
  `:890` `graph_marker_drag_abort()`; `:926` the marker release rung; `:935` the
  wave-bold arm and `:947` its `on_body` split.
* `src/callback.c:1201` `if(xctx->ui_state & GRAPHPAN) goto finish;` —
  **everything below it runs on the PRESS only**. `:1202-1216` the three region
  flags. `:1224` `mkpress = ... graph_marker_press(...)`. `:1232` `else if(event
  == ButtonPress && button == Button1) {` — the cursor-grab block, ending `:1291`;
  its four `< 10` tests at `:1240`, `:1250`, `:1269`, `:1288`. **Your arm goes at
  the END of that block**, gated on `!(xctx->graph_flags & (16|32|512|1024))`.
* `src/callback.c:1568-1588` the GRAPHPAN latch (`:1584` `ui_state |= GRAPHPAN`,
  `:1585-1586` the `mx/my_double_save` seed, `:1587`
  `graph_rubber_active = 0`). Gated on `(!xctx->graph_top ||
  xctx->graph_marker_drag)` — a bottom/left-margin press latches fine, so **no
  change is needed here**; verify that and say so.
* `src/callback.c:1592` `finish:`. `:1630-1640` the Button3 box-zoom parameter
  computation (`xx1 = G_X(mx_double_save)` — note **no `pow(10,·)`**, decision
  D-18). `:1642-1673` the **rubber** (erase with `gctiled`, draw with
  `gc[SELLAYER]`, clamp the moving corner to the plot box at `:1652-1653`);
  `:1674-1681` the Button3-release erase. **Your motion band and your release go
  beside these.**
* `src/callback.c:1682` the per-graph loop; `:1697-1702` `same_sim_type`;
  `:2077` `else if(event == ButtonRelease)`; `:2082-2126` the RMB XY box zoom
  (`:2088` the participation test verbatim); `:2128-2160` the **RMB left-margin
  Y-only zoom**, with the `digital` → `ypos1`/`ypos2` branch at `:2151-2157`;
  `:2164-2167` the per-graph redraw; `:2170-2173` `need_fullredraw` → `draw()`;
  `:2174` `clear_graphpan_at_end`.
* `src/callback.c:6936` `case XK_Escape:` — **no `waves_selected` guard**, so ESC
  always reaches `abort_operation()`, from the viewer too.

**State**

* `src/xschem.h:1681-1683` `graph_top` / `graph_bottom` / `graph_left`;
  `:1684-1685` `graph_rubber_active` + `graph_rubber_x/y`; `:1691`
  `graph_press_x, graph_press_y`; `:1692-1720` the marker transient block —
  **your three new fields go at its end**, with the same "ALL TRANSIENT" framing.
* `src/xschem.h:393` `GRAPH_REORDER_HANDLE_W 14`; `:418` `GRAPH_TRACE_PICK_TOL`;
  `:434` `GRAPH_MAX_SEL_WAVES`; `:448-449` the marker constants; `:458`
  `GRAPH_MARKER_MAX_SEL` — **the new `#define`s go after `:458`**, in the same
  commented style.
* `src/xschem.h:1983-1984`, `:2022-2025`, `:2246` — the graph/marker extern
  block; the three new prototypes go there.
* Reset sites (the gesture-state class): `src/actions.c:1919-1923` in
  `clear_drawing()` and `src/xinit.c:671-675` in `alloc_xschem_data()`.

**Verb surface**

* `src/scheduler.c:3615` `static int xschem_cmds_g(...)`; the `get` sub-key
  `switch(argv[2][0]) { case 'g':` block; `:3859` `graph_plotbox_at`, `:3895`
  `graph_legend_at`, `:3905` `graph_trace_at` — the fail-soft getter shape to
  copy (`if(!xctx) {... TCL_ERROR}` then `argc > N` else a sentinel).
* `src/scheduler.c:5099` `xschem graph_coord` — the top-level verb shape, and the
  one place already returning a `{lo hi}`-style pair. (It still lacks the
  landmine-37 bracket; **do not fix that here**, record it.)
* `src/scheduler.c:5153` `xschem graph_marker` — the top-level verb with a
  sub-verb table and `scheduler_readonly_reject`. **Yours does NOT
  readonly-reject** (D-13).

**Viewer**

* `src/wave_viewer.tcl:2283` `strip_at_pixel` (whole band, margins included);
  `:2693` `strip_bands_px`; `:2733` `strip_handle_at_pixel`.
* `src/wave_viewer.tcl:2818` `marker_grabbed` — **the exact proc your
  `axis_grabbed` copies** (switch ctx, `catch`, fail-closed).
* `src/wave_viewer.tcl:2954` `strip_drag_press`: `:2958` the modifier refusal,
  `:2965` **the unconditional forward of the press to C**, `:2966` the grip test,
  `:2982` the `marker_grabbed` rung (**your rung goes immediately after it**),
  `:2986-2987` the trace/cursor rungs, `:2993-2997` the arm.
* `:3006` `strip_drag_motion` (returns 0 ⇒ the binding forwards to C),
  `:3037` `strip_drag_release` (**always** forwards the release to C), `:3087`
  `strip_drag_cancel`.
* `:5976-5981` `key_filter`'s Escape arm — cancels the Tcl drag, then forwards
  ESC to C. No change needed; verify.
* `:6490` `strip_bindings`; `:6524-6531` `<ButtonPress-1>`, `:6536-6541`
  `<B1-Motion>`, `:6542-6548` `<ButtonRelease-1>`.
* `:1770` `graph_props`' returned prop string — emits `flags=graph`, never
  `unlocked`, and never `vlegend` (so viewer strips are horizontal-legend and
  their left margin is clean).
* `:2481` `capture_live_graph_state` — **you do not call it** (D-16); it is what a
  later viewer mutation runs to fold your rect writes back into the model.
* `:5424` `wheel_zoom` — the existing zoom affordance: no `log_action`, no
  `push_undo`. Leave it alone (item 04's turf).

**Test-side anchors**

* `tests/headless/test_wave_markers.tcl:327-368` `check` / `check_true` / `note` /
  `stall` / `pcall`; `:423` `mk_reset`, `:431` `mk_graph`; `:1985-1994`
  `count_code`; `:2002` `mp_band`, `:2011` `mp_box`, `:2044` `mp_far`;
  `:1767-1799` the `--logdir` child.
* `tests/headless/full_audit.sh:118` — suites are auto-discovered
  (`ls test_*.tcl`), so a new file needs **no** registration. `:40-64`
  `logdir_tests` is only for suites that need `--logdir` in the PARENT — yours
  does not (it spawns its own child).
* The shipped footer, copied **exactly** (`test_wave_trace_menu.tcl` tail):
  `RESULT: ALL PASS ($npass checks)` + `exit 0/1`.

## DO — in this order

### 1. Baseline first, before any edit

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
cd src && make && cd ..
GUI_GATE=0 tests/headless/run_suites.sh test_wave_viewer test_wave_modes \
                                        test_wave_markers test_wave_trace_menu \
                                        test_wave_snap
```

Record every check count and verdict. These are the suites that own the LMB seam
and the graph queries — they are your regression witnesses. PLAN.md's PREFLIGHT
says `test_wave_markers` is red at `MF1`; item 01's and item 02's scouts both
measured it green on their day. **Measure, do not assume.**

### 2. `src/xschem.h` — constants, state, prototypes

After `:458` (`GRAPH_MARKER_MAX_SEL`):

```c
/* Axis-region drag zoom (issue 0190,
 * doc/claude/specs/waveform_viewer_modes.md 17). Which axis-number margin of a
 * strip a canvas pixel is in -- the BOTTOM margin owns X, the LEFT margin owns
 * Y. Not a bitmask: a pixel is in at most one of them (the bottom-left corner
 * answers Y, matching the shipped RMB left-margin arm). */
#define GRAPH_AXIS_NONE 0
#define GRAPH_AXIS_X    1
#define GRAPH_AXIS_Y    2
/* Upper bound on the ZOOM-OUT factor of one drag. A reverse drag scales the
 * window by 1/|s| where s is the drag span as a fraction of the plot extent, so
 * s -> 0 is 1/0. The 3-px click threshold normally binds first (max factor ~
 * plot_width/3); this is the backstop that keeps an inf out of the x1/x2 tokens,
 * where it would be permanent. NOT mirrored in Tcl -- no Tcl code computes the
 * map (that is the whole point of graph_axis_map). */
#define GRAPH_AXIS_ZOOM_MAX_FACTOR 1000.0
```

At the end of the marker transient block (after `:1720`):

```c
  /* Axis-region drag zoom (issue 0190). ALL TRANSIENT, like the marker block
   * above: the durable state is the rect's x1/x2/y1/y2 (or ypos1/ypos2) tokens,
   * written once on the release. graph_axis_press is in SCREEN PIXELS because
   * that is what graph_axis_map() takes -- the same space every other picking
   * query on a strip takes (landmine 43). */
  int    graph_axis_drag;      /* GRAPH_AXIS_NONE | _X | _Y -- what is armed */
  int    graph_axis_draggraph; /* rect[GRIDLAYER] index the drag is bound to */
  double graph_axis_press;     /* press position on that axis, screen pixels */
```

Three prototypes beside `graph_plotbox_at` (`:2246`), each with a one-paragraph
contract comment in the house style.

### 3. `src/draw.c` — one region query, one formula, one apply

Put all three next to `graph_plotbox_at` (`:5031`), before the marker block.

**`int graph_axis_at(int i, double px, double py)`** — decision D-1/D-4/D-6/D-7.
Copy `graph_legend_at`'s skeleton exactly (local `Graph_ctx`, `memset`, the
`128|256` bracket, the `scx/scy == 0.0` off-screen sentinel). Then, in order:

1. inside the plot box (normalise both `S_X` and `S_Y` pairs — **landmine 3**,
   `cy` is negative) ⇒ `GRAPH_AXIS_NONE`;
2. outside the container rect (`S_X(rx1..rx2)`, `S_Y(ry1..ry2)`, normalised) ⇒
   `NONE`;
3. `gr->reorder_handle && px >= X_TO_SCREEN(gr->rx2) - GRAPH_REORDER_HANDLE_W` ⇒
   `NONE` — the grip keeps unconditional first refusal, exactly as
   `graph_marker_press` gives it at `callback.c:605-606`;
4. `graph_legend_at(i, px, py) >= 0` ⇒ `NONE` — the vertical and digital legends
   live in the LEFT margin (`draw.c:4501`, `:4508`);
5. left of the plot box ⇒ `GRAPH_AXIS_Y`;
6. below the plot box ⇒ `GRAPH_AXIS_X`;
7. otherwise ⇒ `NONE`.

**No raw requirement and no digital refusal** (D-19/D-20) — say so in the comment,
naming `graph_plotbox_at` as the function it deliberately differs from.

**`int graph_axis_map(int i, int axis, double p0, double p1, double *lo, double *hi)`**
— decisions D-9/D-11/D-12/D-18. THE formula, and it must appear here and nowhere
else (§9 SAB-6 and the `AS1` leg exist to enforce that).

* local `Graph_ctx`, same bracket + off-screen sentinel;
* pick the axis's plot extent in SCREEN pixels — `S_X(gx1)`/`S_X(gx2)` for X,
  `S_Y(gy1)`/`S_Y(gy2)` for Y — and **normalise** (landmine 3);
* **clamp** `p0` and `p1` to that extent (D-11);
* travel test: `fabs(p1 - p0) <= GRAPH_CLICK_TOL_SCREEN` ⇒ return 0. The 3.0 lives
  in `callback.c`; pass the threshold in as a parameter **or** duplicate the
  literal with a comment naming `callback.c:34` — do **not** move
  `GRAPH_CLICK_TOL` into the header (landmine-20's warning that it and
  `GRAPH_TRACE_PICK_TOL` answer different questions is why it is file-private).
  Prefer the parameter;
* `A = min(g_lo, g_hi)`, `B = max(...)`, `R = B - A` — all in **`gr` space, which
  IS log space when `logx`/`logy` is set** (D-18: the shipped box zoom writes
  `dtoa(G_X(...))` with no `pow(10,·)`; applying one here would double-convert);
* `ua = (Gaxis(p0) - A) / R`, `ub = (Gaxis(p1) - A) / R`, `s = ub - ua`;
* `s > 0` ⇒ `*lo = A + ua*R; *hi = A + ub*R;`
* `s < 0` ⇒ `f = -s; if(f < 1.0/GRAPH_AXIS_ZOOM_MAX_FACTOR) f = 1.0/GRAPH_AXIS_ZOOM_MAX_FACTOR;`
  `R2 = R / f; *lo = A - ub*R2; *hi = *lo + R2;`
* `if(*hi == *lo) *hi += 1e-6;` (the shipped idiom, `callback.c:1638`);
* return 1.

Write the two worked checks into the comment, because they are what make the
formula reviewable and they are two of the suite's legs: a **full-extent reverse
drag leaves the window unchanged** (`ua=1, ub=0, s=-1, R2=R, lo=A`), and a
**half-extent reverse drag from the far edge** gives `[A-R, A+R]`.

**`int graph_axis_zoom(int i, int axis, double lo, double hi)`** — decisions
D-8/D-13/D-14/D-17/D-19. THE apply.

* validate `i`, `flags & 1`, `axis`;
* `axis == GRAPH_AXIS_X`: write `x1`/`x2` on rect `i` **and on every participating
  rect**, reproducing `callback.c:2088`'s predicate — `rk->sel ||
  (same_sim_type && !(rk->flags & 2)) || k == i`, where `same_sim_type` needs the
  MASTER (`i`) not to be `unlocked` and the two `sim_type` tokens to match
  (`callback.c:1697-1702`);
* `axis == GRAPH_AXIS_Y`: rect `i` only. Build a local `Graph_ctx` to read
  `gr->digital`; digital ⇒ `ypos1`/`ypos2`, else `y1`/`y2` (mirror
  `callback.c:2151-2157`);
* `my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, tok, dtoa(v)))`;
* **no `set_modify`, no `push_undo`** — landmine 19, and the ASE viewer's buffer is
  read-only for life;
* exactly ONE
  `log_action("xschem graph_axis_zoom %d %s %.17g %.17g\n", i, axis == GRAPH_AXIS_X ? "x" : "y", lo, hi);`
  and it must be the **verb form**, so a replay reproduces the whole propagation;
* return 1 when anything was written.

### 4. `src/callback.c` — the gesture

Add three statics beside the marker gesture helpers (`:594`-`:800`):
`graph_axis_drag_clear()`, `graph_axis_drag_abort()` (the `abort_operation` hook)
and `graph_axis_press_arm(int i, int mx, int my)`.

* **Arm** at the END of the cursor-grab block (`:1232`-`:1291`), inside it:

  ```c
      /* The axis-region drag zoom arms LAST, and only when this same press
       * grabbed no cursor (issue 0190, decision D-3). A cursor's LINE crosses
       * the margin and its numeric READOUT is DRAWN there -- draw_cursor
       * (draw.c) spans gr->ry1..gr->ry2 and labels at gr->ry2-1, draw_hcursor
       * spans rx1+10..rx2-10 and labels at rx1+5 -- so a press there really can
       * be aimed at the cursor, and "a press that grabbed a cursor keeps the
       * whole drag" is the shipped rule (waveform_viewer_modes.md 12.1/13.1).
       * A press on a MARKER pre-empts this whole block already (mkpress above). */
      if(!(xctx->graph_flags & (16 | 32 | 512 | 1024))) graph_axis_press_arm(i, mx, my);
  ```

  `graph_axis_press_arm` calls `graph_axis_at(i, (double)mx, (double)my)` — the
  **event's own canvas pixels**, never `xctx->mousex/mousey` (landmine 43) — and
  on a hit stores `drag`, `draggraph = i` and `press = (ax == X ? mx : my)`.

* **Motion band** beside the Button3 rubber (`:1642`). Same `gctiled`-erase /
  `gc[SELLAYER]`-draw / `graph_rubber_x/y/active` bookkeeping. Guard:
  `event == MotionNotify && (state & Button1Mask) && !(state & Button3Mask) &&
  xctx->graph_axis_drag && !xctx->graph_marker_drag &&
  xctx->graph_master == xctx->graph_axis_draggraph`. For X the band spans the
  plot box's full height, for Y its full width; clamp the moving edge to the plot
  box exactly as `:1652-1653` does. Add the reciprocal `!xctx->graph_axis_drag`
  term to the Button3 rubber guard at `:1644-1646` (the B1+B3 chord class the
  `!xctx->graph_marker_drag` term there already exists for).

* **Release** in the `finish:` section (`:1592`), after the existing Button3
  parameter block:

  ```c
  if(event == ButtonRelease && button == Button1 && xctx->graph_axis_drag) {
    int ax = xctx->graph_axis_drag, gi = xctx->graph_axis_draggraph;
    double p0 = xctx->graph_axis_press;
    double p1 = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;
    double lo, hi;
    if(xctx->graph_rubber_active) { ...erase, exactly like :1674-1681... }
    graph_axis_drag_clear();
    if(graph_axis_map(gi, ax, p0, p1, &lo, &hi, GRAPH_CLICK_TOL)) {
      graph_axis_zoom(gi, ax, lo, hi);
      need_fullredraw = 1;
    }
  }
  ```

  Declarations at block top — C89.

* **ESC**: `graph_axis_drag_abort();` immediately after
  `graph_marker_drag_abort();` in `abort_operation()` (`:260`), with a one-line
  comment mirroring the marker one. `abort_operation` ends in `draw()`, which
  repaints over the band.

* **Verify and state in a comment that the GRAPHPAN latch (`:1568-1588`) needs no
  change**: it is gated on `(!xctx->graph_top || xctx->graph_marker_drag)` and
  both axis regions have `graph_top == 0`, so the routing latch (landmine 36) is
  already granted. If your measurement disagrees, add the term — but measure
  first, and say which it was.

Do **not** touch: `GRAPH_TRACE_PICK_TOL`, `GRAPH_CLICK_TOL`'s value or its
file-private scope, the `-1e30` poison sites, the wave-bold arm, the marker arms,
the MMB pan, or the Button3 arms' behaviour.

### 5. `src/actions.c` + `src/xinit.c` — the resets

Add the three fields to the gesture-state reset class, next to the marker fields
at `actions.c:1919-1923` and `xinit.c:671-675`, with the same reasoning: the same
`xctx` is reused by `xschem clear`, File>Open in the tab, `xschem load`, the
disk-undo reload **and `wviewer::regenerate`'s `xschem clear_drawing`**, so a
surviving arm would latch onto whatever rect lands at that index next.

### 6. `src/scheduler.c` — three getters, one verb

In `xschem_cmds_g`'s `get` `case 'g':`, beside `graph_plotbox_at` (`:3859`):

```
xschem get graph_axis_at   <gi> <px> <py>       -> "" | x | y
xschem get graph_axis_map  <gi> x|y <p0> <p1>   -> {lo hi} | {}
xschem get graph_axis_drag                      -> "" | x | y
```

All three **fail soft** (a sentinel + `TCL_OK`, never an error) — the ASE viewer
wraps them in `catch` and must read a missing verb as "nothing there", never as
"locked out". `graph_axis_map` prints with `%.17g` through `my_snprintf`? **No** —
`my_snprintf` does not do `%.*g` but a literal `%.17g` is fine; use the
`graph_coord` line at `scheduler.c:5117` as the template it already is.

Top level, beside `graph_coord` (`:5099`):

```
xschem graph_axis_zoom <gi> x|y <lo> <hi>   -> 1 | 0
```

Fails **loud** on a usage error (wrong argc, unknown axis word) — a script wants a
catchable error. A bad graph index answers `0`. **No `scheduler_readonly_reject`**
(D-13) — say why in the comment, naming landmine 17's "view state the engine has
always been allowed to put in a read-only rect", or the ASE viewer's own gesture
and every replay of the logged line would be refused.

### 7. `src/wave_viewer.tcl` — one rung, no geometry

* `wviewer::axis_grabbed {wp}` beside `marker_grabbed` (`:2818`): switch ctx,
  `catch {xschem get graph_axis_drag}`, empty/error ⇒ 0, `x`/`y` ⇒ 1. Comment it
  as the `marker_grabbed` twin and say explicitly that the viewer does **not**
  hit-test the axis margins itself (D-22) — C already decided, on the press this
  proc's caller forwarded at `:2965`.
* In `strip_drag_press`, immediately after the `marker_grabbed` rung (`:2982`):

  ```tcl
    # An axis-region drag zoom (issue 0190) is C's for the whole gesture, for the
    # same reason the marker drag above is: the press has already been forwarded
    # to C, C armed it, and a >3 px drag here must zoom the axis rather than
    # reorder the stack. This is the ONLY place the viewer learns about the axis
    # regions -- there is deliberately no Tcl hit test to drift (D-22). It sits
    # inside the handle test with the marker rung, so the reorder GRIP keeps
    # unconditional first refusal (graph_axis_at declines that column itself).
    if {[wviewer::axis_grabbed $W]} { return 1 }
  ```

* Nothing else changes: `<B1-Motion>` already forwards when `strip_drag_motion`
  returns 0, `strip_drag_release` already forwards the release unconditionally,
  and `key_filter`'s Escape arm already forwards ESC. **Verify each of those three
  and say so** — a silent change there is how a gesture loses its release.
* **No `with_edit`** (D-13/landmine 17). Say so in the comment, because every
  neighbouring marker seam *does* bracket.

### 8. Tests — new suite `tests/headless/test_wave_axis_zoom.tcl`

Header comment in the house style: what the feature is, what each group asserts,
what is **not** asserted (the pixels — §10), and the standalone repro line. Fixture
is hermetic: `xschem raw new` / `raw add` (no ngspice) plus `mk_graph`-style rects
on GRIDLAYER. Auto-discovered by `full_audit.sh` — **no registration needed**;
confirm that from `full_audit.sh:118` rather than assuming.

**Write a margin scanner** that is the sibling of `mp_box`
(`test_wave_markers.tcl:2011`): find the plot box by asking
`graph_plotbox_at`, find the container band from the world rect through the
engine's own zoom/origin (`mp_band`, `:2002`), then pick pixels by asking
`graph_axis_at` — **never** by predicting from `0.14 * rh`. Re-scan after any leg
that zooms (PLAN test discipline).

#### 8a. `AZ*` — the region query (BOTH arms)

| leg | asserts |
|---|---|
| `AZ0` | staging, with teeth: two graph rects, the plot box was scanned and is > 100 px wide/tall, and at least one pixel of each margin was found (**FAIL, never skip**, if the scan came up empty) |
| `AZ1` | a plot-box pixel ⇒ `""` |
| `AZ2` | a bottom-margin pixel ⇒ `x` |
| `AZ3` | a left-margin pixel ⇒ `y` |
| `AZ4` | a top-margin (legend band) pixel ⇒ `""` |
| `AZ5` | the grip column (`reorder_handle=1`) at bottom-margin height ⇒ `""`; and with `reorder_handle` absent the same pixel answers `x` (teeth: the refusal is the grip's, not the geometry's) |
| `AZ6` | a pixel outside the container rect ⇒ `""` |
| `AZ7` | bad index, negative index, a non-graph layer-2 rect ⇒ `""` |
| `AZ8` | the bottom-LEFT corner ⇒ `y` (D-7) |
| `AZ9` | with `vlegend=1`, a left-margin pixel that `graph_legend_at` claims ⇒ `""`, while the bottom margin still answers `x` (D-6) |
| `AZ10` | with **no raw loaded** the margins still answer `x`/`y` (D-20 — the leg that dies if `graph_plotbox_at`'s raw gate is copied) |
| `AZ11` | a **digital** strip's bottom margin answers `x` (D-19) |

#### 8b. `AM*` — the formula (BOTH arms)

Read the current window back with `xschem getprop rect 2 <gi> x1|x2|y1|y2` and the
plot-box pixel extent from the scanner; compute every expectation **in Tcl, from
the closed form**, and compare with a relative tolerance.

| leg | asserts |
|---|---|
| `AM1` | forward X drag: `lo`/`hi` equal `graph_coord`'s data x at the press and release pixels — **both** endpoints, cross-checked against an independent source |
| `AM2` | reverse X drag: **both** endpoints against `R2 = R/|s|`, `lo = A - ub*R2` |
| `AM3` | **full-extent reverse X drag leaves the window unchanged** (this is the leg SAB-2 does *not* kill — say so in the comment) |
| `AM4` | half-extent reverse X drag from the right edge ⇒ exactly `[A-R, A+R]` |
| `AM5` | forward Y drag (**upward** = decreasing pixel y) ⇒ `[a, b]`, `a < b` |
| `AM6` | reverse Y drag (downward) ⇒ both endpoints |
| `AM7` | travel of exactly 3 px ⇒ `{}`; 4 px ⇒ a result (the boundary, both sides) |
| `AM8` | a 4-px reverse drag on a wide box: the range is finite and `<= R * GRAPH_AXIS_ZOOM_MAX_FACTOR * (1+eps)` |
| `AM9` | `logx=1`: the map agrees with `graph_coord` (i.e. it is in log space), and the returned values are NOT `pow(10,·)`-converted |
| `AM10` | release pixel outside the plot box is **clamped**, not refused: a drag ending 50 px past the right edge gives the same answer as one ending exactly on it |
| `AM11` | bad index / unknown axis word / off-screen graph ⇒ `{}` |

#### 8c. `AV*` — the apply (BOTH arms)

| leg | asserts |
|---|---|
| `AV1` | `graph_axis_zoom 0 x lo hi` writes `x1`/`x2` on rect 0 **and on rect 1** — **witness every rect**, not the one addressed |
| `AV2` | `... 0 y lo hi` writes `y1`/`y2` on rect 0 only; rect 1's `y1`/`y2` are byte-identical |
| `AV3` | a rect carrying `flags=graph,unlocked` does **not** follow X |
| `AV4` | a rect with a different `sim_type` does **not** follow X |
| `AV5` | a **digital** rect's Y writes `ypos1`/`ypos2` and leaves `y1`/`y2` alone |
| `AV6` | `xschem get modified` is 0 after the zoom — with a control leg proving a plain `setprop` DOES set it (otherwise the probe is untested) |
| `AV7` | with `xschem set readonly 1` the verb still applies (D-13); restore `readonly 0` |
| `AV8` | a bad index ⇒ `0` and nothing written; a bad axis word ⇒ `catch` non-zero |

#### 8d. `AL*` — the log line (BOTH arms, in a `--logdir` child)

Copy `test_wave_markers.tcl:1767-1799`. The child builds two graph rects, calls
the verb once, prints a sentinel and exits.

* `AL1` — the child ran to its end and really had a log open.
* `AL2` — **exactly one** `xschem graph_axis_zoom 0 x * *` line for one call.
* `AL3` — its bounds are numeric (glob a float), and no line carries a pixel
  coordinate.
* `AL4` — **replay**: sourcing that exact line in the child reproduces the same
  `x1`/`x2` on **both** rects (so the line carries the propagation).

#### 8e. `AG*` — the real C gesture (DISPLAY only)

On an on-canvas schematic graph, through `xschem callback .drw <T> <px> <py> 0 <b>
0 <s>` with `T` = 4 press / 6 motion / 5 release, `update` between, replaying the
**whole** sequence.

| leg | asserts |
|---|---|
| `AG1` | a bottom-margin press ⇒ `xschem get graph_axis_drag` = `x` |
| `AG2` | a left-margin press ⇒ `y` |
| `AG3` | a plot-body press ⇒ `""` |
| `AG4` | a legend-band press ⇒ `""` |
| `AG5` | a grip-column press ⇒ `""` |
| `AG6` | **the cursor non-collision**: set `hcursor1_y` so `graph_flags & 128`, press in the left margin at that cursor's height ⇒ `graph_axis_drag` is `""` **and** `graph_flags & 512` is set (the cursor really was grabbed — without this second half the leg passes when nothing happened at all) |
| `AG7` | full forward X gesture ⇒ the window is exactly `AM1`'s answer, and `graph_axis_drag` is back to `""` |
| `AG8` | full reverse X gesture ⇒ `AM2`'s answer |
| `AG9` | a sub-threshold press+release ⇒ the window is byte-identical and the arm is cleared |
| `AG10` | ESC mid-drag (press, motion, `xschem callback .drw 3 ... 65307 ...`) ⇒ arm cleared, window unchanged, and the trailing release commits nothing |
| `AG11` | a Y drag on rect 0 leaves rect 1's `y1`/`y2` untouched, while an X drag changes rect 1's `x1`/`x2` — one leg, both rects |
| `AG12` | after the whole block, `xschem get modified` is still 0 |

#### 8f. `AX*` — the ASE viewer seam (DISPLAY only)

Real viewer, shipped bindings, `sdid`-style per-strip witness so "which strip is
at index k" is independent of "what is in it" (PLAN test discipline).

| leg | asserts |
|---|---|
| `AX1` | a bottom-margin press through `<ButtonPress-1>` does **not** arm the strip reorder (`wviewer::strip_drag_press` returns 1 and `drag_from` is unset/-1) **and** `axis_grabbed` is 1 |
| `AX2` | a full press→motion→release drag in the bottom margin changes that strip's `x1`/`x2` and leaves the **strip order** unchanged |
| `AX3` | the same in the left margin changes `y1`/`y2` |
| `AX4` | a press in the plot BODY still arms the strip reorder (non-collision) |
| `AX5` | a press on the grip still reorders |
| `AX6` | the viewer buffer is still `modified 0` and `readonly 1` |
| `AX7` | ESC during a viewer axis drag cancels: window unchanged, arm cleared |
| `AX8` | `wviewer::history_depth` did not move (D-15: a zoom is not a viewer undo point) |

#### 8g. `AS*` — source-level tripwire (BOTH arms)

`AS1` — using `count_code` (`test_wave_snap.tcl:40`): the anchored zoom-out
expression appears in `src/draw.c` exactly **once**, `graph_axis_map(` is called
from `src/callback.c` exactly once and from `src/scheduler.c` exactly once, and
`src/callback.c` contains **no** second copy of the map. This is landmine 45(a)
applied: a gesture and a verb that each carry their own copy of the formula will
drift, and no behavioural leg can see it while they still agree.

### 9. Build, sabotage-verify, run

```sh
cd src && make && cd ..
GUI_GATE=0 tests/headless/run_suites.sh --nogui test_wave_axis_zoom
GUI_GATE=0 tests/headless/run_suites.sh         test_wave_axis_zoom
```

Then each sabotage in turn — apply, rebuild, run, confirm the kill list
**exactly**, `git diff <file>` to confirm it holds nothing but the sabotage,
`git checkout -- <file>`, rebuild, confirm green again:

| # | sabotage | must kill | must stay green |
|---|---|---|---|
| **SAB-1** | invert the direction test in `graph_axis_map` (treat every drag as zoom-in) | `AM2`, `AM3`, `AM4`, `AM6`, `AG8` | `AM1`, `AM5`, `AM7`–`AM11`, all `AZ*`, all `AV*` |
| **SAB-2** | drop the anchoring term in the zoom-out branch (`*lo = A;` — width right, position wrong) | `AM2`, `AM4`, `AM6`, `AG8` | **`AM3` stays GREEN** — the full-extent reverse drag has `ub = 0`, so the anchor term vanishes there. That asymmetry is the entire reason both endpoints are asserted; if `AM3` also dies, `AM3` is wrong |
| **SAB-3** | widen `graph_axis_at` to answer `x` inside the plot box | `AZ1`, `AG3`, `AX4` | everything else |
| **SAB-4** | drop the participation loop from `graph_axis_zoom` (write only rect `i`) | `AV1`, `AG11`'s X half, `AL4` | `AV2`–`AV8`, all `AM*`, all `AZ*` |
| **SAB-5** | arm the axis drag **before** the cursor grab (remove the `!(graph_flags & (16\|32\|512\|1024))` guard) | `AG6` **only** | everything else |
| **SAB-6** | give the release arm its own inline copy of the map instead of calling `graph_axis_map` | `AS1` **only** | everything else — this is the leg that carries the one-function-owns-one-geometry decision |

If a sabotage kills more or fewer legs than its list, **the leg is wrong, not the
sabotage** — fix the leg and re-run all six.

Then the neighbouring suites (the LMB seam and the graph queries):

```sh
GUI_GATE=0 tests/headless/run_suites.sh test_wave_viewer test_wave_modes \
                                        test_wave_markers test_wave_trace_menu \
                                        test_wave_snap test_wave_legend \
                                        test_wave_clear_all test_wave_grid \
                                        test_wave_drag_preview test_wave_split_strip \
                                        test_wave_empty_strips
```

Finally the wider audit (it is the batch's contract, not optional):

```sh
GUI_GATE=0 bash tests/headless/full_audit.sh
```

Compare against the PLAN.md PREFLIGHT baseline —
`SUMMARY: 239 pass  20 fail  1 crash/timeout  11 skip  (total 271)`,
`WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)` — plus the verbatim 20-name FAIL list
and `TIMEOUT | test_key_graph_context`, and **+1 pass for your new suite**.
**Any fail not on that list is yours.** Known-flaky and not yours:
`test_cadence_drag` (12/12 red on pristine), `test_wave_trace_menu` TG9 (4-in-10
under WSLg), `test_ase_plot` P4/P6/P8 — and for the last two the **check COUNT is
the signal, not the verdict** (145 = a real `test_ase_plot` run, 30 = a WSLg
geometry skip that still prints `ALL PASS`; `test_wave_clear_all` 68 real vs 58
skipped). A whole-suite wipeout with `NORESULT`/connection errors is a WSLg
Xwayland abort — re-run before attributing it to your change.

`test_graph_context` is already RED and `test_key_graph_context` already TIMES
OUT (PLAN.md, "three baseline fails on this batch's turf"). Their failing legs are
wheel/key routing over a graph. **If either gets worse, that is yours** — an LMB
arm should not touch them. If either incidentally gets better, say so and do not
chase it.

### 10. Docs

* `doc/claude/specs/waveform_viewer_modes.md`
  * **new §17 "Axis-region drag zoom (2026-08-01, issue 0190)"**: the gesture
    table (where it grabs, the 3-px threshold, the two maths **written out as
    formulas**, the two worked checks, the clamp, ESC, the release clamp), the
    region definition and its four refusals (plot box, grip, legend, top/right
    margin), the corner rule, the X-propagates/Y-does-not rule **with the
    correction that it is the C participation test and not `sharedx`**, and the
    "no dirty flag, no C undo, no viewer undo, one log line" paragraph.
  * **§15.1** — two new rows in the ownership table: `LMB press-drag | the bottom
    (X-number) margin | C | zoom X on every participating strip` and `LMB
    press-drag | the left (Y-number) margin | C | zoom Y on that strip`. Add a
    seventh "easy to get wrong" rule: **a cursor grab and the reorder grip both
    still win in the margins**, and the viewer learns this by asking C, not by
    hit-testing.
  * **§12.1** — one sentence recording that the two axis margins have left the
    strip-reorder zone, and that the handle and the empty body (the two the
    section always named) are unchanged.
* `doc/claude/code_analysis/waveform_subsystem_reference.md`
  * §5, the `waves_callback` bullet — the new arm, where it sits in the Button1
    precedence order, and that its rubber is `drawtemprect`, not a token.
  * §9 — the three new getters and the new verb, with their fail-soft/fail-loud
    split and the **no readonly reject** note.
  * §10 — a new recipe line: *"New graph GESTURE in a margin"*, pointing at
    `graph_axis_at`/`graph_axis_map`/`graph_axis_zoom` as the worked example of
    query / formula / apply separated so a Tcl suite can drive the formula.
  * **new landmine 47**, three reusable lessons:
    (a) **an axis margin is not free real estate** — the x/y cursor LINES cross it
    and their numeric READOUTS are drawn in it (`draw.c:4077/4082/4139/4146`),
    the VERTICAL and DIGITAL legends *are* the left margin
    (`draw.c:4501/4508`), and the reorder grip owns its right 14 px at every
    height; a new gesture there must yield to all three, and the cursor grab
    tests have **no plot-box confinement** and are in XSCHEM units, not pixels;
    (b) **the formula gets its own function and its own query verb** — the
    gesture and the replay verb must not each carry a copy (landmine 45(a) in a
    second shape), and exposing it as `xschem get graph_axis_map` is what lets a
    headless suite assert *both endpoints* of a zoom instead of only its width;
    (c) **a C-side view write needs no `capture_live_graph_state` and no viewer
    undo** — it is one more producer for the capture the *next* Tcl mutation
    runs, exactly like the MMB pan and the RMB box zoom, and the visible
    consequence (a plain window resize discards it) is shipped behaviour for
    that whole class.
* `doc/claude/issues/0190-axis-region-drag-zoom.md` — new, house shape
  (`# 0190 — …`, `**Status:** FIXED (2026-08-01)`, `**Branch:** fluid-editing`,
  the user's request quoted verbatim, what existed before — including the measured
  fact that an LMB margin drag was a **no-op in C and a strip reorder in the
  viewer** — the decisions that mattered (region definition, cursor/grip/legend
  precedence, the two maths, no dirty/undo, one log line), and the legs that defend
  each). **Verify 0190 is still free** (`ls doc/claude/issues/`) before writing. Do
  **not** edit `doc/claude/issues/status.md` — it is an explicit point-in-time
  snapshot.

### 11. COMMIT

Stage exactly this list — nothing else, no `-A`, no `-a`:

```sh
git add src/xschem.h src/draw.c src/callback.c src/scheduler.c \
        src/actions.c src/xinit.c src/wave_viewer.tcl \
        tests/headless/test_wave_axis_zoom.tcl \
        doc/claude/specs/waveform_viewer_modes.md \
        doc/claude/code_analysis/waveform_subsystem_reference.md \
        doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md \
        doc/claude/overnight_batch_2026_08_01/prompts/03_axis-region-drag-zoom.md \
        doc/claude/issues/0190-axis-region-drag-zoom.md
git status --short          # confirm ONLY the two pre-existing dirty tracked files remain
```

Message:

```
feat(0190): LMB drag in an axis-number margin zooms that axis only

The axis-number margins of a waveform strip were dead space: measured,
an LMB press-drag there did nothing at all in the C engine, and in the
ASE viewer it armed the strip drag-reorder -- a zone the spec never
claimed for it ("the reorder handle (always) or empty waveform body").

A forward drag zooms IN to exactly the two data coordinates the press
and the release land on. A reverse drag zooms OUT by the one anchored
linear map that puts the CURRENT window back between those two screen
positions: new_range = range / |s|, new_lo = lo - ub * new_range. Both
endpoints matter -- a width-only implementation slides the window
sideways and still passes every "the range grew" assertion, which is
why the suite asserts lo and hi separately and why a full-extent
reverse drag is asserted to change nothing at all.

The formula lives in ONE function, graph_axis_map(), called by the
gesture and exposed as `xschem get graph_axis_map` so the suite drives
it headlessly; graph_axis_at() answers which margin a pixel is in, and
graph_axis_zoom() is the single apply, shared with the new replayable
verb. The margin is not free real estate: the x/y cursor lines cross it
and their numeric readouts are DRAWN in it, the vertical and digital
legends ARE the left margin, and the reorder grip owns its right 14 px
-- all three keep priority. The ASE viewer learns none of that geometry:
after forwarding the press it simply asks C what got armed, the same
rung shape marker drags already use.

No dirty flag, no C undo point and no viewer undo snapshot -- a zoom is
view state (landmine 19), which is also what lets the read-only viewer
perform it without a with_edit bracket.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

## CONSTRAINTS

* **The gesture is C, not Tcl.** The Tcl change is one rung plus one 6-line proc,
  and it contains **no geometry** (D-22). If you find yourself computing a plot
  box in `wave_viewer.tcl`, stop.
* **The formula appears once.** `graph_axis_map()` is called by the release arm
  and by the verb; neither may inline it. `AS1` and `SAB-6` exist for this.
* **Do not `set_modify`, do not `push_undo`, do not `wviewer::push_undo`, do not
  call `capture_live_graph_state`.** Landmine 19 and decisions D-14/D-15/D-16.
* **Do not readonly-reject the verb or the primitive** (D-13). The ASE viewer is
  read-only for life and this is view state — landmine 17 names the box zoom.
* **Do not put the rubber band in a prop token or under `draw_graph` flags bit
  16** (D-10, decision doc §5.1). `drawtemprect` + `graph_rubber_*`, like the
  Button3 rubber it sits beside.
* **Do not convert log axes.** `gr->gx1..gy2` and `G_X`/`G_Y` are already in log
  space; a `pow(10,·)` here is the landmine-35 mistake arriving from the other
  side (D-18, decision doc §5.3).
* **Do not take the reorder grip, a cursor grab, a marker press or a legend entry**
  (D-3 … D-6). Each already owns those pixels and each has a leg.
* **Do not touch** `GRAPH_TRACE_PICK_TOL`, `GRAPH_REORDER_HANDLE_W`,
  `GRAPH_CLICK_TOL`'s value or its file-private scope, the `-1e30` poison, the
  wave-bold arm, the MMB pan, or any Button3 behaviour.
* **Do not bump `XSCHEM_FILE_VERSION`.** No new token, no grammar change — the
  gesture writes `x1`/`x2`/`y1`/`y2`/`ypos1`/`ypos2`, which have always existed.
* **Wheel handling is item 04's**, including `<Control-Button-4/5>` in
  `strip_bindings` (`wave_viewer.tcl:6585-6586`) and `wviewer::wheel_zoom`. Leave
  them alone; item 04 will reuse `graph_axis_at` and
  `GRAPH_AXIS_ZOOM_MAX_FACTOR`.
* Do not "re-fix" pre-existing defects you notice — record them in your summary
  instead. Known and out of scope: `graph_coord`'s missing landmine-37 bracket
  (`scheduler.c:5099`); the cursor-grab `< 10` tolerance being in XSCHEM units
  rather than screen pixels (`callback.c:1240/1250/1269/1288`);
  `find_closest_wave`'s two open `extra_rawfile` defects (landmine 40);
  `test_graph_context` / `test_key_graph_context` being red at baseline.
