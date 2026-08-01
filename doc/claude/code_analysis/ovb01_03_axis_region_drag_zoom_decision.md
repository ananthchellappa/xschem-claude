# OVB-03 — axis-region drag zoom: scout decision doc

**Verdict: PROCEED.**
**Scouted 2026-08-01, at HEAD `1ec3ce89`** (item 02's commit). Every anchor below
was re-read from source that day; the PLAN.md item notes were re-verified claim by
claim and **six of them are corrected in §5**.

**Status:** IMPLEMENTED (2026-08-01). Every decision below was taken as
recorded; the implementation prompt
(`doc/claude/overnight_batch_2026_08_01/prompts/03_axis-region-drag-zoom.md`)
was executed in full — six named sabotages verified, suite
`tests/headless/test_wave_axis_zoom.tcl` (119 checks `--nogui` / 173 with a
display). Issue file: `doc/claude/issues/0190-axis-region-drag-zoom.md`; spec:
`doc/claude/specs/waveform_viewer_modes.md` §17.

**Two corrections found during implementation** (both recorded in the issue
file, §3):

1. **§3.3's "the GRAPHPAN latch needs no change" is WRONG.** The Y region is
   "left of the plot box, anywhere in the container", so a press in the TOP-LEFT
   corner of a strip owning no legend entry there (`legend=0`, or no `node`
   token yet) arms a Y drag with `graph_top` already 1, and the release is then
   silently dropped (landmine 36). The latch grew
   `|| xctx->graph_axis_drag`, exactly as the marker drag did.
2. **`graph_axis_zoom()` must read `digital` OFF THE RECT**, not from a scratch
   `Graph_ctx` as §3.2 implies. `setup_graph_data()` parses `digital` *below* its
   off-screen early return (landmine 37a), so an off-screen digital strip
   answered 0 and the Y write landed in `y1`/`y2`. Caught by the `AV5` leg.

---

## 1. The request

> LMB press-and-drag outside the plot area of a strip and in the AXIS region —
> where axis numbers are displayed — will result in zooming along that axis only.
> For the X-axis, if user presses-and-drags from left to right, that is a zooming
> in. The portion of the trace(s) that occupy the strip from x1 (press location)
> to x2 (LMB release location) will now be zoomed in and take up the entire plot
> area. If user presses-and-drags from right to left, then, the entire portion of
> the trace(s) currently displayed in the strip will be displayed between x1 and
> x2 (axis numbers will change accordingly to accommodate the zoom). In the right
> to left, the right-most (x2) is where LMB was pressed. Similarly for the Y axis.
> If drag is upwards, then zoom in, if downwards (towards origin) then zoom out —
> similar to what is done for X-axis.

---

## 2. What exists today (verified anchors)

### 2.1 The geometry: a strip is a container rect with four margins

`setup_graph_data()` (`src/draw.c:3796`) computes, at `:3993-4008`:

```c
tmp = gr->rw * 0.14;  gr->marginx = tmp;      /* :3994 */
tmp = gr->rh * 0.14;  gr->marginy = tmp;      /* :3996 */
gr->x1 = gr->rx1 + gr->marginx;               /* :4000 plot-box LEFT  */
gr->x2 = gr->rx2 - gr->marginx * 0.35;        /* :4001 plot-box RIGHT (0.35x!) */
if(gr->digital)      gr->y1 = gr->ry1 + gr->marginy * 0.4;   /* :4002 */
else if(gr->vlegend) gr->y1 = gr->ry1 + gr->marginy / 3.0;   /* :4004 */
else                 gr->y1 = gr->ry1 + gr->marginy;         /* :4005 */
gr->y2 = gr->ry2 - gr->marginy;               /* :4007 plot-box BOTTOM */
```

`rx1/ry1/rx2/ry2` are the **container** rect in XSCHEM coordinates
(`src/xschem.h`, *"container rectangle, xschem coordinates"*), `sx1/sy1/sx2/sy2`
their screen pixels (`draw.c:3893-3896`). So:

| region | XSCHEM extent | what is drawn there |
|---|---|---|
| plot box | `x1..x2` × `y1..y2` | traces, grid |
| **bottom margin — the X-axis numbers** | `x1..x2` × `y2..ry2` | X tick labels; the **x-cursor readout label** (`draw_cursor`, `draw.c:4082`, at `gr->ry2-1`) |
| **left margin — the Y-axis numbers** | `rx1..x1` × `y1..y2` | Y tick labels; the **y-cursor readout label** (`draw_hcursor`, `draw.c:4146`, at `gr->rx1+5`); **and the VERTICAL / DIGITAL legend** |
| top margin | `ry1..y1` | the horizontal legend (`legend_slot_hit`, `draw.c:4485`) |
| right margin | `x2..rx2` | nothing; its rightmost 14 screen px is the reorder grip |

### 2.2 The three region flags already exist and are already latched at press

`waves_callback()` (`src/callback.c:816`) computes them at `:1202-1216`, right
**after** `if(xctx->ui_state & GRAPHPAN) goto finish;` (`:1201`) — so they are
frozen at press time for the whole drag (landmine 36):

```c
if(xctx->mousey_snap < W_Y(gr->gy2)) xctx->graph_top    = 1;  /* :1203  above the box */
if(xctx->mousex_snap < W_X(gr->gx1)) xctx->graph_left   = 1;  /* :1208  left of it   */
if(xctx->mousey_snap > W_Y(gr->gy1)) xctx->graph_bottom = 1;  /* :1213  below it     */
```

`W_Y(gy2) == gr->y1`, `W_X(gx1) == gr->x1`, `W_Y(gy1) == gr->y2`.

### 2.3 There is already a margin-aware drag zoom — on **Button 3**

Issue 0142. `src/callback.c:2077` `else if(event == ButtonRelease) {`:

* `:2082-2126` — RMB interior drag: X window written to every **participating**
  graph, Y window to the master only.
* `:2128-2160` — **RMB drag in the LEFT margin (`graph_left && !graph_top`) is a
  Y-ONLY zoom**, on the master only, with a `digital` branch writing
  `ypos1`/`ypos2` through `DG_Y` instead of `y1`/`y2` through `G_Y`.

The participation test, verbatim (`:2088`, and the same expression at `:1970`,
`:2023`, `:2063`):

```c
r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master
```

where `same_sim_type` (`:1697-1702`) additionally requires the **master** not to
be `unlocked` and the two `sim_type` tokens to match.

### 2.4 The live rubber rectangle is `drawtemprect`, not a prop token

`src/callback.c:1642-1673` — on every `MotionNotify` with `Button3Mask` and
`GRAPHPAN`, erase the previous outline with `xctx->gctiled`, draw the new one with
`xctx->gc[SELLAYER]`, both via `drawtemprect(..., NOW, ...)`; state in
`xctx->graph_rubber_x/y/active` (`src/xschem.h:1684-1685`). `:1674-1681` erases it
on the Button3 release. **`draw_graph` is not involved and no token is written.**

### 2.5 What an LMB press in an axis margin does **today**

Traced end to end:

1. `waves_selected()` (`callback.c:77`) accepts it — `POINTINSIDE` of the rect
   inset by `border = 5.0 * tk_scaling * xctx->zoom` (`:114`) — and sets
   `graph_master`.
2. `waves_callback` seeds `graph_press_x/y` (`:879-880`) and calls
   `graph_marker_drag_abort()` (`:890`).
3. `graph_marker_press()` (`:594`) — normally 0 in a margin (a callout is clamped
   inside the plot box) but **not by construction**: it declines only the reorder
   grip column (`:605-606`).
4. `:1232-1291` the cursor grabs. **They have no plot-box confinement** —
   `fabs(mousey - W_Y(cursor)) < 10` (`:1240`, `:1250`) and
   `fabs(mousex - W_X(cursorN)) < 10` (`:1269`, `:1288`), in **XSCHEM units**, not
   screen pixels. So a press in the left margin at an hcursor's height grabs it.
5. `:1568-1588` the **GRAPHPAN routing latch** — gated on
   `(!xctx->graph_top || xctx->graph_marker_drag)`, so a bottom- or left-margin
   press latches normally.
6. Motion: the graph pan needs `Button2Mask` (`:1709`) — an LMB drag does nothing.
7. Release (`:2077`): `button != Button3` → clear `GRAPHPAN` and the cursor-move
   flags. The wave-bold arm (`:935`) requires travel `<= GRAPH_CLICK_TOL * zoom`
   **and** then splits on `on_body = POINTINSIDE(..., gr->x1, gr->y1, gr->x2,
   gr->y2)` (`:947`); off the body it asks `graph_legend_at` (`:1003`), which
   answers −1 in the axis margins, and **changes nothing**.

**Conclusion: in the C engine, an LMB press-and-drag in an axis margin is a
no-op today.** The feature is purely additive there.

### 2.6 …except in the ASE viewer, where Tcl owns the press

`wviewer::strip_drag_press` (`src/wave_viewer.tcl:2954`) resolves the strip with
`strip_at_pixel` (`:2283`), which tests the **whole band** from `graphbb` — margins
included. It refuses only: a modified press (`:2958`), the reorder grip
(`:2966`, `strip_handle_at_pixel`), an armed **marker** drag (`:2982`,
`marker_grabbed` → `xschem get graph_marker_drag`), a trace within
`GRAPH_TRACE_PICK_TOL` (`:2986`) and a **cursor grab** (`:2987`,
`cursor_grabbed` → `xschem get graph_flags` bits 16/32/512/1024). Everything else
— **including both axis margins** — arms the strip drag-reorder (`:2993-2997`).

The spec's own description of the reorder zone is *"the reorder handle (always)
or empty waveform body"* (`waveform_viewer_modes.md` §12.1). The margins are
neither; they are in the zone only because the implementation used the whole
band.

### 2.7 Existing query surface this item extends

* `xschem get graph_plotbox_at <gi> <px> <py>` → `draw.c:5031`. Local
  `Graph_ctx`, hcursor bits bracketed (landmine 37), fails closed, **refuses
  digital strips and requires a loaded raw**.
* `xschem get graph_legend_at <gi> <px> <py>` → `draw.c:4546` /
  `legend_slot_hit` `:4485`. **The vertical legend's slots are
  `rx1+5 .. x1-5` — inside the left margin** (`:4501-4502`); the digital
  legend's are `rx1 .. x1 - 20*txtsizelab` (`:4508-4509`); only the horizontal
  layout lives in the top band (`:4519-4522`).
* `xschem graph_coord <gi> <px> <py>` → `scheduler.c:5099`, data-space
  coordinates of a canvas pixel. **No landmine-37 bracket** (known, out of scope).
* `xschem get graph_marker_drag` → `scheduler.c` `xschem_cmds_g`, the
  "C armed the whole gesture" signal the viewer press seam already consults.
* Getters live in `xschem_cmds_g` (`scheduler.c:3615`), `get` sub-key `case 'g'`;
  top-level verbs dispatch on `argv[1][0]`, so `graph_axis_zoom` belongs in the
  same function as `graph_coord`/`graph_marker`.

### 2.8 Log / dirty / undo behaviour of the neighbours

Landmine 19, re-verified: `waves_callback` (`:816-2196`) contains **zero**
`set_modify(1)` and **zero** `push_undo()`. `xschem pan` / `xschem zoom_box`
(canvas view changes) *do* `log_action` (`callback.c:2464`, `:2502`); no graph
gesture does. `wviewer::wheel_zoom` (`wave_viewer.tcl:5424`) writes the model and
regenerates but does **not** `log_action` and does **not** `push_undo`.

---

## 3. The design

### 3.1 Where the gesture lives: **the C engine**

Five reasons, all from source:

1. The twin gesture (RMB box zoom, including its `graph_left` Y-only arm) is C.
2. It needs `G_X`/`G_Y`, the participation test and `drawtemprect` — all C.
3. It needs the region flags, which are already computed and already latched.
4. Embedded schematic graphs get it for free (they have axis margins too).
5. Item 04 (CTRL+wheel in the same regions) reuses the region query.

The ASE viewer needs **one** change and it carries no geometry: after
`strip_drag_press` has forwarded the press to C, ask C whether that press armed an
axis drag — byte-for-byte the `marker_grabbed` rung at `wave_viewer.tcl:2982`.

### 3.2 New C surface (`src/draw.c`)

```c
/* xschem.h */
#define GRAPH_AXIS_NONE 0
#define GRAPH_AXIS_X    1
#define GRAPH_AXIS_Y    2
#define GRAPH_AXIS_ZOOM_MAX_FACTOR 1000.0

int graph_axis_at (int i, double px, double py);
int graph_axis_map(int i, int axis, double p0, double p1, double *lo, double *hi);
int graph_axis_zoom(int i, int axis, double lo, double hi);
```

**`graph_axis_at(i, px, py)`** — which axis-number region a CANVAS PIXEL is in.
Local `Graph_ctx`, hcursor bits bracketed, `gr->scx == 0.0 || gr->scy == 0.0` ⇒ 0
(the correct off-screen detector, landmine 37). Rules, in order:

1. bad index / non-graph rect / off-screen → `NONE`;
2. inside the plot box → `NONE`;
3. outside the container rect → `NONE`;
4. `gr->reorder_handle` set and `px >= S_X(rx2) - GRAPH_REORDER_HANDLE_W` →
   `NONE` (the grip keeps unconditional first refusal, exactly as
   `graph_marker_press` gives it at `callback.c:605`);
5. `graph_legend_at(i, px, py) >= 0` → `NONE` (the vertical and digital legends
   live in the left margin — §2.7);
6. left of the plot box → `Y`;
7. below the plot box → `X`;
8. otherwise (top margin, right margin) → `NONE`.

The **bottom-left corner is `Y`**, matching the RMB arm, which tests `graph_left`
first and never consults `graph_bottom` (`callback.c:2129`).

Deliberate difference from `graph_plotbox_at`: **no raw requirement and no
digital refusal** — this is pure geometry, and both axes are meaningful on a
digital strip (X is `x1`/`x2`, Y is the `ypos1`/`ypos2` band the RMB arm already
writes).

**`graph_axis_map(i, axis, p0, p1, &lo, &hi)`** — THE FORMULA, in one place.
`p0`/`p1` are canvas pixels along that axis (px for X, py for Y). Returns 0 when
the travel is `<= GRAPH_CLICK_TOL` screen px, when there is no transform, or on a
bad index.

Work entirely in `gr` space (`gx1..gx2` / `gy1..gy2`), which is **already log
space when `logx`/`logy` is set** — see §5.3. Normalise `A = min`, `B = max`,
`R = B - A`.

```
u(p)  = (G_axis(p) - A) / R          normalised position of a pixel, 0..1
ua    = u(p0)   (press)              ub = u(p1)   (release)
s     = ub - ua
```

* **`s > 0` — zoom IN** (X: left→right; Y: upward, since screen y grows down and
  data y grows up, so `cy < 0`):
  `lo = A + ua*R`, `hi = A + ub*R` — i.e. exactly the two data coordinates.
* **`s < 0` — zoom OUT**: the current window must end up occupying the screen span
  between release and press. One anchored linear map:
  `R' = R / |s|`, `lo = A - ub*R'`, `hi = lo + R'`.
* `|s|` clamped below at `1.0 / GRAPH_AXIS_ZOOM_MAX_FACTOR`.
* `hi == lo` ⇒ `hi += 1e-6` (the shipped idiom, `callback.c:1638`).

Two checks that make the formula self-evident and that the suite asserts:

* a **full-extent reverse drag** (press at one edge, release at the other) leaves
  the window **exactly unchanged** — `ua = 1`, `ub = 0`, `s = -1`, `R' = R`,
  `lo = A - 0 = A`. This is the leg that a width-only implementation also passes,
  which is precisely why both endpoints are asserted elsewhere.
* a **half-extent reverse drag from the far edge** gives `R' = 2R`,
  `lo = A - R`, `hi = A + R`.

**`graph_axis_zoom(i, axis, lo, hi)`** — THE APPLY, in one place, shared by the
gesture and by the Tcl verb.

* `axis == X`: write `x1`/`x2` on rect `i` **and on every participating rect**,
  reproducing §2.3's predicate exactly.
* `axis == Y`: rect `i` only. `gr->digital` ⇒ `ypos1`/`ypos2`, else `y1`/`y2` —
  mirroring `callback.c:2136-2158`.
* `subst_token` + `my_strdup(_ALLOC_ID_, ...)`, like every neighbour.
* **No `set_modify`, no `push_undo`** (landmine 19 — this is a view change and the
  ASE viewer's buffer is read-only for life).
* **One `log_action("xschem graph_axis_zoom %d %s %.17g %.17g\n", ...)`** — the
  verb form, with numeric bounds. (`my_snprintf` does not understand `%.*g`;
  `log_action` is a plain varargs printf, so `%.17g` is fine there.)

### 3.3 The gesture (`src/callback.c`)

New transient state in `xctx`, beside the marker block
(`src/xschem.h:1691-1720`) and reset in **both** gesture-state reset sites
(`actions.c:clear_drawing()` ~`:1919`, `xinit.c:alloc_xschem_data()` ~`:671`):

```c
int    graph_axis_drag;       /* GRAPH_AXIS_NONE|X|Y — what is armed */
int    graph_axis_draggraph;  /* rect[GRIDLAYER] index the drag is bound to */
double graph_axis_press;      /* press position on that axis, SCREEN PIXELS */
```

Arm — inside the existing `else if(event == ButtonPress && button == Button1)`
block (`callback.c:1232`), **at its end**:

```c
      /* The axis-region drag zoom arms LAST, and only when this same press
       * grabbed no cursor. A cursor's LINE crosses the margin and its numeric
       * READOUT is DRAWN there (draw.c draw_cursor :4077/:4082,
       * draw_hcursor :4139/:4146), so a press there really can be aimed at the
       * cursor -- the shipped "a press that grabbed a cursor keeps the whole
       * drag" rule (waveform_viewer_modes.md 12.1/13.1). */
      if(!(xctx->graph_flags & (16 | 32 | 512 | 1024))) {
        int ax = graph_axis_at(i, (double)mx, (double)my);
        if(ax != GRAPH_AXIS_NONE) { ...arm... }
      }
```

A marker press already pre-empts this whole block (`:1224-1231`).

Motion — a rubber **band** beside the Button3 rubber (`:1642-1673`), same
`gctiled`-erase / `gc[SELLAYER]`-draw / `graph_rubber_*` bookkeeping. For X it
spans the full plot-box height between press and pointer, for Y the full width;
both clamped to the plot box. Guard it with `(state & Button1Mask)`,
`xctx->graph_axis_drag`, `!(state & Button3Mask)` and
`!xctx->graph_marker_drag`; add the reciprocal `!xctx->graph_axis_drag` term to
the Button3 rubber guard at `:1644-1646` (the B1+B3 chord class the marker guard
there already exists for).

Release — in the `finish:` section (`:1592`), beside the existing box-zoom
parameter computation:

```c
  if(event == ButtonRelease && button == Button1 && xctx->graph_axis_drag) {
    int ax = xctx->graph_axis_drag, gi = xctx->graph_axis_draggraph;
    double p1 = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my, lo, hi;
    double p0 = xctx->graph_axis_press;
    graph_axis_drag_clear();                       /* erases the rubber too */
    if(graph_axis_map(gi, ax, p0, p1, &lo, &hi)) {
      graph_axis_zoom(gi, ax, lo, hi);
      need_fullredraw = 1;
    }
  }
```

Release position **clamped to the plot-box extent** inside `graph_axis_map`
(decision D-11).

ESC — `graph_axis_drag_abort()` next to `graph_marker_drag_abort()` in
`abort_operation()` (`callback.c:260`). `case XK_Escape` (`:6936`) has **no**
`waves_selected` guard, so ESC always reaches it, from the viewer too
(`wviewer::key_filter` forwards ESC, `wave_viewer.tcl:5976-5981`);
`abort_operation` ends in `draw()`, which repaints over the rubber.

### 3.4 Tcl surface (`src/scheduler.c`, all in `xschem_cmds_g`)

| verb | answer |
|---|---|
| `xschem get graph_axis_at <gi> <px> <py>` | `""` \| `x` \| `y` — fails soft |
| `xschem get graph_axis_map <gi> x\|y <p0> <p1>` | `{lo hi}` \| `{}` — fails soft; **the formula seam the suite drives** |
| `xschem get graph_axis_drag` | `""` \| `x` \| `y` — what is armed, the `graph_marker_drag` twin |
| `xschem graph_axis_zoom <gi> x\|y <lo> <hi>` | `1`\|`0`; usage error ⇒ `TCL_ERROR`. **NOT readonly-rejected** (D-13) |

### 3.5 Viewer seam (`src/wave_viewer.tcl`)

* `wviewer::axis_grabbed {wp}` beside `marker_grabbed` (`:2818`): switch ctx,
  `catch {xschem get graph_axis_drag}`, `""`/error ⇒ 0.
* One rung in `strip_drag_press`, immediately after the `marker_grabbed` rung
  (`:2982`) and **before** the trace/cursor rungs — the press has already been
  forwarded to C at `:2965`, so C has already decided:
  ```tcl
    if {[wviewer::axis_grabbed $W]} { return 1 }
  ```
  Nothing else changes: `<B1-Motion>` falls through to the C forward
  (`:6536-6541`), `<ButtonRelease-1>` already forwards unconditionally
  (`strip_drag_release`, `:3037`), Escape already calls `strip_drag_cancel` and
  then forwards.
* **No `with_edit`**: a range write is view state the engine has always been
  allowed to put in a read-only rect — landmine 17 lists the box zoom by name.

---

## 4. Every spec hole, resolved

| # | question | decision | why | rejected |
|---|---|---|---|---|
| D-1 | What is "the axis region"? | The **bottom margin** (`y2..ry2`) for X and the **left margin** (`rx1..x1`) for Y, taken from `gr->x1/x2/y1/y2` + `gr->rx1/ry1/rx2/ry2`, minus the grip column and minus any pixel `graph_legend_at` claims. | PLAN Q1's recommendation, with two corrections source forces: derive from the **plot box**, not from `marginx`/`marginy` (the right edge is `0.35*marginx` and the top edge has three different formulas, `draw.c:4001-4005`); and the vertical/digital **legend lives in the left margin** (`draw.c:4501`, `:4508`). | Deriving the region from the margin widths (re-implements three special cases); ignoring the legend (would steal `vlegend` strips' picking surface). |
| D-2 | Which existing gestures collide? | Full map in §6. The only **committed** gesture actually given up is the ASE viewer's strip drag-reorder in the two axis margins — which the spec never claimed (§12.1: *"the reorder handle (always) or empty waveform body"*). | In C the region is a verified no-op today (§2.5). In Tcl `strip_at_pixel` covers the whole band, so the margins were in the reorder zone only by permissiveness. | Keeping the margins for the reorder and putting the zoom on a modifier (contradicts the user's plain-LMB request). |
| D-3 | Cursor grab vs axis drag? | **The cursor wins.** The axis drag arms only when `!(graph_flags & (16\|32\|512\|1024))`. | An x-cursor's line is drawn `ry1..ry2` and its readout label at `ry2-1` — *in* the bottom margin (`draw.c:4077`, `:4082`); an hcursor's line is `rx1+10..rx2-10` and its label at `rx1+5` — *in* the left margin (`:4139`, `:4146`). A press there can genuinely be aimed at the cursor, and "a press that grabbed a cursor keeps the whole drag" is the shipped rule. | Axis-drag-wins (would make a visible, labelled cursor ungrabbable at its own readout). |
| D-4 | Reorder grip vs axis drag? | **The grip wins, unconditionally**, in C (rule 4 of `graph_axis_at`). | `graph_marker_press` already gives it unconditional first refusal for exactly this overlap (`callback.c:601-606`), and the Tcl seam tests the grip before it tests anything else (`wave_viewer.tcl:2966`). Two owners of one column is how the reorder/marker overlap was settled. | Letting the axis region take the bottom-right 14 px (a silent, invisible split of the grip). |
| D-5 | Marker vs axis drag? | **The marker wins** — the arm sits inside the `else` branch of `mkpress > 0` (`callback.c:1224-1232`), so no code change is needed. | A callout is clamped inside the plot box, but `graph_marker_at`'s 8-px tolerance can reach out of it; the marker gesture has owned first refusal since it shipped. | Testing the axis region first. |
| D-6 | Legend vs axis drag? | **The legend wins**: `graph_axis_at` returns NONE wherever `graph_legend_at >= 0`. | For `vlegend=1` and for digital strips the legend *is* the left margin (`draw.c:4501`, `:4508`). The ASE viewer emits no `vlegend` (`wave_viewer.tcl:1770`), so viewer strips are unaffected — but the ~127 embedded schematic graphs are not all horizontal-legend. | Refusing `vlegend`/`digital` strips wholesale (would also kill their X axis, which has no conflict). |
| D-7 | The bottom-LEFT corner: X or Y? | **Y.** | Matches the shipped RMB arm, whose Y branch tests `graph_left && !graph_top` and never consults `graph_bottom` (`callback.c:2129`). One precedence rule in the file, not two. | X-wins; refusing the corner (a dead 14×14 hole users would find). |
| D-8 | `sharedx` stacks — X on one strip or all? | **All**, via the shipped participation test `r->sel \|\| (same_sim_type && !(r->flags & 2)) \|\| i == graph_master`, evaluated inside `graph_axis_zoom`. Y is always the one strip. | Identical to MMB pan, RMB box zoom and the arrow-key pans. **It is not the viewer's `sharedx` flag** — see §5.4. | Consulting `sharedx` from C (a Tcl-side window option C cannot see); X on the master only (would desynchronise a time-aligned stack). |
| D-9 | Click-vs-drag threshold? | `GRAPH_CLICK_TOL` (3.0, `callback.c:34`) × `xctx->zoom`, on the **dragged axis's own component**, tested inside `graph_axis_map`. Sub-threshold ⇒ no write, no log. | The same constant the strip drag, the trace drag and the wave-bold click use; the axis's own component because a Y drag has no meaningful X travel. | A new constant; testing both components (a pure X drag with 4 px of hand tremor in Y would then be judged on the wrong axis). |
| D-10 | Rubber-band preview? | **Yes** — `drawtemprect` with `gctiled`/`gc[SELLAYER]` and `graph_rubber_*`, a band spanning the plot box across the un-dragged axis. **Not** a prop token under `draw_graph` bit 16. | §5.1: the C-side live rubber has never gone through `draw_graph`; `reorder_handle=2/3/4` is the *Tcl*-driven feedback path. Reusing the shipped mechanism gets the erase bookkeeping and the `!has_x` no-op for free. | A new `reorder_handle` value (would need Tcl to rewrite a token per motion event for a gesture Tcl does not own). |
| D-11 | Release outside the window? | **Clamp** to the plot-box extent inside `graph_axis_map` and commit. | PLAN Q10; also what the RMB rubber already does with its moving corner (`callback.c:1652-1653`). `GRAPHPAN` keeps the drag routed to the graph after the pointer leaves it (landmine 36), so the release does arrive. | Cancelling (a drag that overshoots by 2 px would silently do nothing). |
| D-12 | Degenerate / explosive zoom-out? | Clamp `\|s\|` at `1/GRAPH_AXIS_ZOOM_MAX_FACTOR` (1000.0, new `#define` in `xschem.h`, **not** mirrored in Tcl). Also the shipped `hi == lo ⇒ hi += 1e-6` guard. | Never divide by zero; D-9's 3-px threshold normally binds first (max factor ≈ plot width / 3), so the clamp is a backstop, not a policy. | No clamp (an `inf` range poisons the tokens permanently); a small factor like 100 (would silently cap a legitimate 4-px-drag zoom-out on a narrow strip). |
| D-13 | Read-only? | The primitive and the verb both **apply**. No `readonly_block`, no `scheduler_readonly_reject`. | A range write is view state the engine has always been allowed to put in a read-only rect (landmine 17 names the box zoom); the ASE viewer is read-only for life and its MMB pan / RMB zoom already write there. Rejecting would break the viewer *and* abort any replay of the logged line. | Mirroring the `graph_marker` verbs' readonly rejection (markers are durable **content**; a zoom is not). |
| D-14 | Dirty flag / C undo? | **Neither.** | Landmine 19, re-verified: `waves_callback` has zero `set_modify(1)` and zero `push_undo()`; `graph_fullxzoom`/`graph_fullyzoom` have no `set_modify` either. | Copying the marker discipline (markers deliberately *do* dirty because they are content that would otherwise be lost on close). |
| D-15 | Viewer undo (`u`/`U`)? | **No `push_undo`.** | PLAN Q8. Window view state is deliberately outside a `wviewer` snapshot (`waveform_viewer_modes.md` §14.1); `wheel_zoom` and `zoom_about` push nothing either. | Pushing (a `u` after a zoom would revert an unrelated model edit). |
| D-16 | `capture_live_graph_state` first? | **No.** | §5.2: a C-side gesture reaches no `regenerate`. `capture_live_graph_state` is what a *later* viewer mutation runs to fold C-written `x1/x2/y1/y2` back into the model — `move_strip`, `move_trace`, `delete_items` already do it, and this gesture rides that machinery unchanged. | Calling it from C (it is Tcl, and calling it would need a context switch on a mouse release). |
| D-17 | Replay logging? | **Yes**, one `log_action` line per commit, from `graph_axis_zoom()`: `xschem graph_axis_zoom <gi> x\|y <lo> <hi>`, `%.17g`, never pixels. | PLAN Q9. Precedent for logging a view change exists in C (`xschem pan` `callback.c:2464`, `xschem zoom_box` `:2502`). The verb is the replay form, exactly as `graph_marker add_at` is for markers. | No logging (matches the box zoom, but throws away a free, assertable, replayable seam). |
| D-18 | Log-scale axes? | Nothing special: the map runs in `gr` space, which **is** log space when `logx`/`logy` is set. | §5.3. The shipped box zoom writes `dtoa(G_X(...))` straight into `x1`/`x2` with no `pow(10,·)`, while the cursor arms *do* apply it — because `cursor1_x` is stored linear and `x1`/`x2` are not. | Reading `logx` off the rect and converting (would double-apply the log and is the exact landmine-35 mistake). |
| D-19 | Digital strips? | Supported. X writes `x1`/`x2`; Y writes `ypos1`/`ypos2` through `DG_Y`. | Mirrors `callback.c:2151-2157` line for line. `graph_axis_at` does **not** refuse digital (unlike `graph_plotbox_at`) — but the digital legend occupies most of its left margin, so D-6 refuses the Y region there anyway, without a special case. | Refusing digital wholesale (would also lose its X axis, which has no conflict). |
| D-20 | No raw loaded / empty strip? | Allowed. `graph_axis_at` does **not** require a loaded raw. | It is a geometry query; `setup_graph_data` produces a valid transform from the tokens alone (defaults `gx1=0, gx2=1e-6`, `draw.c:3868-3876`). Zooming an empty strip's axis is harmless and consistent with the arrow keys and `f`. | Copying `graph_plotbox_at`'s raw gate (would make the region silently dead before the first simulation). |
| D-21 | Where does the *formula* live? | One function, `graph_axis_map()`, called by the gesture **and** exposed as `xschem get graph_axis_map` so the suite drives it in both arms. | The `graph_marker_label_box` doctrine — one function owns one geometry — and landmine 45(a): a feature whose feedback and whose commit compute the same thing twice will drift. A source-level leg asserts the formula appears once. | Duplicating the map in the release arm and in the verb. |
| D-22 | How does the viewer keep out of the way? | It **asks C what the press armed** (`xschem get graph_axis_drag`), it does not hit-test the margins in Tcl. | Byte-for-byte the shipped `marker_grabbed` rung (`wave_viewer.tcl:2982`). Nothing to mirror, nothing to drift (contrast `GRAPH_REORDER_HANDLE_W`, which *is* mirrored and carries a "change both" warning). | A Tcl `axis_at` wrapper doing its own geometry (a second source of truth for the plot box). |
| D-23 | Return shapes of the two new getters? | Both answer `""` \| `x` \| `y`. Fail soft, never an error. | One vocabulary for the whole feature; `""` is the same "nothing there" sentinel `graph_marker_at` uses, and the ASE viewer's `catch`-wrapped readers must read a missing verb as "nothing", never as "locked out". | `0/1/2` integers to match `graph_marker_drag` (would give the feature two vocabularies). |
| D-24 | Which suite? | A **new** `tests/headless/test_wave_axis_zoom.tcl`, auto-discovered by `full_audit.sh` (`ls test_*.tcl`, `:118`). The log leg runs in a `--logdir` **child process**, the `test_wave_markers.tcl` `MD3` pattern (`:1767-1799`). | No existing suite owns axis geometry; `test_wave_markers` is already the batch's shared red-leg risk. A child process is the only honest way to assert a C self-logged line from a `--nolog` suite. | Extending `test_wave_viewer.tcl` (its `TD`/`SD` groups own the LMB *body* seam); registering the new suite in `logdir_tests` (not needed with the child). |

---

## 5. PLAN.md claims that source refutes

### 5.1 Q5 — "a transient band drawn under `draw_graph` **flags bit 16**, same transient rules as `reorder_handle` values 2/3/4"

**Refuted.** The C-side live rubber for the RMB box zoom is
`drawtemprect(xctx->gctiled | xctx->gc[SELLAYER], NOW, ...)` in
`callback.c:1642-1681`, with state in `xctx->graph_rubber_x/y/active`. It never
touches `draw_graph` and writes no token. `reorder_handle=2/3/4` is the
**Tcl**-driven feedback path: Tcl rewrites the token on the two affected rects
when the prospective destination changes (`waveform_viewer_modes.md` §12.6). A
C-owned drag has no Tcl in the loop, so bit 16 would mean a token write per motion
event from a layer that is not running. Use `drawtemprect`.

### 5.2 Q12 — "does it need `capture_live_graph_state` first? → yes, if it goes through any path that can `regenerate`"

**Refuted for this implementation.** A C-side gesture reaches no `regenerate`.
`capture_live_graph_state` (`wave_viewer.tcl:2481`) is the helper a *later* Tcl
model mutation runs to fold C-written `x1 x2 y1 y2 hilight_wave` back out of the
rects — it exists **because** C writes ranges behind the model's back. This
gesture is one more producer for it, not a consumer of it. (Consequence to state
in the spec: as with MMB pan and RMB box zoom, a plain window **resize** —
`regenerate` from `on_configure` — discards an axis zoom the model never saw.
That is shipped behaviour for every C-side range write, not new.)

### 5.3 Q7 — "**Beware**: `setup_graph_data` returns early for an off-screen graph *before* parsing `logx` — read the token off the rect"

**True in general (landmine 37a), but not applicable here — and following it would
introduce a bug.** `gr->gx1/gx2/gy1/gy2`, and therefore `G_X`/`G_Y`, are
**already in log space** when `logx`/`logy` is set: the shipped box-zoom arm writes
`dtoa(G_X(mx_double_save))` straight into `x1`/`x2` with no `pow(10,·)`
(`callback.c:1630-1640`, `:2091-2093`), while the cursor arms *do* apply
`pow(10,·)` (`:1186`) because `cursor1_x` is stored linear. So the map is uniform
in log space **for free**, and applying `pow(10,·)` to it would double-convert.
The off-screen case is detected the correct way — `gr->scx == 0.0 || gr->scy ==
0.0`, which is landmine 37's own prescription for callers that need the transform.

### 5.4 Q3 — "`sharedx` stacks — does an X zoom apply to one strip or all? → **all**, since that is what `sharedx` means"

**Right answer, wrong mechanism.** The C engine cannot see the viewer's `sharedx`;
propagation comes from the shipped participation test (§2.3), whose
`same_sim_type` term additionally requires the master rect to be *locked*.
`wviewer::graph_props` emits `flags=graph` and never `unlocked`
(`wave_viewer.tcl:1770`), so in the viewer X propagates to every strip of the same
`sim_type` **whatever `sharedx` is set to** — exactly as MMB pan and RMB box zoom
already do. `sharedx` only affects `regenerate`, which forces graph 0's stored
range onto the others (`:1840-1848`).

### 5.5 Q2 — the collision list is incomplete

Three additions, all measured from source:

* **The x/y CURSORS are missing from it.** Their grab tests have **no plot-box
  confinement** (`callback.c:1240`, `:1250`, `:1269`, `:1288`) and their lines and
  numeric readout labels are **drawn inside the margins** (`draw.c:4077`/`:4082`
  for x, `:4139`/`:4146` for y). This is the collision that actually shapes the
  design (D-3).
* **The vertical / digital LEGEND is missing from it.** PLAN says *"the top of the
  rect is the legend (`legend_slot_hit` starts at `gr->ry1`)"* — that is only the
  **horizontal** layout. `vlegend` slots are `rx1+5 .. x1-5`
  (`draw.c:4501-4502`) and digital slots `rx1 .. x1-20*txtsizelab` (`:4508-4509`)
  — i.e. the left margin (D-6).
* **The `waves_selected` inset is not universal.** `border = 5.0 * tk_scaling *
  xctx->zoom` (`callback.c:114`) applies to the `event != -3` and `event == -3`
  arms; the **Button3 press/release arm hit-tests the full rect** (`:150-153`). So
  the seam is LMB/motion-only. (It does bound the LMB gesture this item adds, which
  is why the suite scans for a margin pixel rather than assuming one.)

Everything else in Q2 checks out: `GRAPH_REORDER_HANDLE_W` is 14
(`xschem.h:393`), the graph pan is on MMB, and the LMB body is strip-reorder /
trace-drag.

### 5.6 Q1 — "Take the geometry from `Graph_ctx`, do not hardcode"

Correct in spirit; the fields matter. Use the **plot box** (`gr->x1/x2/y1/y2`) and
the **container** (`gr->rx1/ry1/rx2/ry2`), not `marginx`/`marginy`: the right edge
is `rx2 - 0.35*marginx` and the top edge is one of three formulas depending on
`digital`/`vlegend` (`draw.c:4001-4005`). Deriving the regions from the margin
widths re-implements those special cases and will drift.

### 5.7 One PLAN claim confirmed

*"Button3-drag XY box-zoom (issue 0142) … left-margin drag = Y-only"* — **true**,
`callback.c:2128-2160`. It is the closest precedent this item has and the design
follows it.

---

## 6. Collision map

| gesture on a strip | where | owner today | after this item |
|---|---|---|---|
| LMB press-drag | plot body (empty) | Tcl — strip drag-reorder | unchanged |
| LMB press-drag | within 10 px of a trace | Tcl — trace drag between strips | unchanged |
| LMB press-drag | the 14-px grip column, **any height** | Tcl — strip drag-reorder | unchanged (`graph_axis_at` rule 4) |
| LMB press-drag | the top/legend band | Tcl — strip drag-reorder | unchanged |
| LMB press-drag | on a marker anchor/label | C — marker drag | unchanged (`mkpress` pre-empts) |
| LMB press-drag | on a cursor (±10 xschem units, anywhere) | C — cursor drag | unchanged (D-3) |
| LMB press-drag | **left margin**, no cursor, no legend entry | Tcl — strip drag-reorder | **C — Y-axis zoom** |
| LMB press-drag | **bottom margin**, no cursor, outside the grip | Tcl — strip drag-reorder | **C — X-axis zoom** |
| LMB click (no travel) | either margin | nothing | nothing (D-9) |
| MMB drag | anywhere | C — graph pan; bottom margin = absolute X positioning | unchanged (Button2Mask) |
| RMB drag | body | C — XY box zoom | unchanged |
| RMB drag | left margin | C — Y-only box zoom | unchanged (Button3) |
| Wheel / Ctrl+wheel | anywhere | Tcl `wheel_bind` (viewer) / C (canvas) | unchanged — **item 04's turf** |
| `f`, arrows | left margin | C — Y fit / Y pan | unchanged (keys) |
| ESC | — | `abort_operation` | also drops an armed axis drag |

**The one thing given up:** the ASE viewer's strip drag-reorder in the two axis
margins. The reorder keeps the grip (which the spec calls its always-available
grab, §12.1), the empty body and the legend band.

---

## 7. Invariants the suite asserts

1. `graph_axis_at` answers `x` only below the plot box, `y` only left of it,
   `""` inside the box, in the top margin, in the right margin, in the grip
   column, on a legend entry, outside the rect, and on a bad/non-graph index.
2. The bottom-left corner answers `y`.
3. **Forward drag**: `lo`/`hi` equal the data coordinates of the press and release
   pixels, computed independently through `xschem graph_coord`.
4. **Reverse drag**: `R' = R/|s|` **and** `lo = A - ub*R'` — **both endpoints**.
5. **Full-extent reverse drag leaves the window bit-for-bit unchanged**
   (the anchor term is zero there, which is exactly why leg 4 must assert `lo`).
6. **Half-extent reverse drag from the far edge** gives `[A-R, A+R]`.
7. Travel `<= 3` screen px on the dragged axis ⇒ `{}` and no write.
8. `|s|` clamped at `1/GRAPH_AXIS_ZOOM_MAX_FACTOR`; the result is always finite.
9. A log-axis strip maps in log space (agrees with `graph_coord`, which returns
   `G_X`/`G_Y`).
10. X propagates to every participating rect — **witness every rect**, not the one
    dragged; an `unlocked` rect does not follow; Y touches only its own rect.
11. A digital strip's Y writes `ypos1`/`ypos2`, not `y1`/`y2`.
12. `xschem get modified` is 0 after a zoom (with a `setprop` control that proves
    the probe can go to 1).
13. The verb still applies with `xschem set readonly 1`.
14. One `log_action` line per commit, with numeric bounds, and **replaying that
    exact line reproduces the same window**.
15. Gesture: a margin press arms (`graph_axis_drag` = `x`/`y`), a body/legend/grip
    press does not, a press that grabbed a cursor does not, the release commits
    the map's answer, ESC commits nothing, and the arm is cleared on every exit.
16. Viewer: a margin press does **not** arm the strip reorder and does not change
    the strip order (`sdid` witness); a body press and a grip press still do; the
    viewer buffer stays `modified 0` / `readonly 1`.
17. Source-level: the anchored map appears **once** in `draw.c` — the gesture and
    the verb share `graph_axis_map()` (landmine 45(a), the `LS5` idiom).

---

## 8. Test plan

New suite `tests/headless/test_wave_axis_zoom.tcl`, fixture built hermetically
with `xschem raw new` / `raw add` + `xschem rect` on GRIDLAYER (the
`test_wave_markers.tcl` `MP*` pattern, which runs in **both** arms).

| group | arm | covers |
|---|---|---|
| `AZ*` | both | the region query — invariants 1, 2, plus fail-closed |
| `AM*` | both | the map — invariants 3–9 |
| `AV*` | both | the verb / apply — invariants 10–13 |
| `AL*` | both (spawns a `--nogui --logdir` child) | invariant 14 |
| `AG*` | DISPLAY | the real C gesture on an on-canvas graph — invariant 15 |
| `AX*` | DISPLAY | the ASE viewer seam — invariant 16 |
| `AS*` | both | invariant 17 (source-level, `count_code`) |

Named sabotages, each with its exact kill list, are in the implementation prompt
§9. The load-bearing pair:

* **SAB-2** (drop the anchoring term, keep the width) must kill the reverse-drag
  **endpoint** legs while leaving the full-extent reverse leg green — that
  asymmetry is the whole reason both endpoints are asserted.
* **SAB-5** (arm the axis drag before the cursor grab) must kill exactly the
  cursor non-collision leg.

---

## 9. Out of scope / recorded, not fixed

* `xschem graph_coord` (`scheduler.c:5099`) still lacks the landmine-37
  `graph_flags & (128|256)` bracket. Known, self-contained, not this item's.
* The cursor grab tolerance `< 10` (`callback.c:1240/1250/1269/1288`) is in
  **XSCHEM units**, not screen pixels — at viewer zoom ≈ 0.27 that is ≈ 37 screen
  px. Same class as the `waves_selected` border bug landmine 44 fixed. Not this
  item's; D-3 is designed to be correct either way.
* `find_closest_wave`'s two open `extra_rawfile` defects (landmine 40).
* Item 04 will want `GRAPH_AXIS_ZOOM_MAX_FACTOR` and the region query; both are
  provided here. Whether item 04's wheel handler ends up in C or in
  `wviewer::wheel_bind` is item 04's decision — this item does not constrain it.

---

## 10. Assertability

Strong. Everything in §7 is a numeric or structural assertion. What no check can
reach is listed in the receipt as the eyeball list: the rubber band's pixels, the
drag feel, the tick-label legibility after a zoom, the (absent) pointer-cursor
change during the drag, and whether losing the axis margins from the viewer's
strip reorder is noticeable. Expect **`[E]`**.
