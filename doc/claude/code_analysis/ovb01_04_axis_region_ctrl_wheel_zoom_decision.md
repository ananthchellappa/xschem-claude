# ovb01 item 04 — axis-region CTRL+wheel zoom — decision doc

**Status: IMPLEMENTED (2026-08-01), REPAIRED TWICE (2026-08-01).** Every decision
below was implemented as written; the suite is
`tests/headless/test_wave_axis_zoom.tcl` at **200** checks `--nogui` / **370**
with a display (was 128 / 196; 190 / 308 at first commit; 200 / 338 after the
first repair; 361 once item 03's own fixup landed `AG14`/`AG15` in the same
file), all **thirteen** sabotages verified. SAB-8..SAB-11 and §7.1 came out of
the first adversarial verifier's four findings — see
`doc/claude/issues/0191-…md` §3.1 for what each hole was and why the window alone
could not close SAB-8. **SAB-12/SAB-13 and §7.2 came out of the second
verifier's single finding: the Y half of the gesture was unwitnessed on BOTH
paths because every Y probe pixel sat at the plot box's vertical CENTRE, where
an anchored zoom and a zoom about the window's centre are numerically identical
— two one-token sabotages of shipped source left all 361 checks green. See
§3.2 of the issue.** `src/` is unchanged by both repair passes.
Issue: `doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md`. Spec:
`doc/claude/specs/waveform_viewer_modes.md` §18. Two implementation findings the
scout could not have had, both recorded in §18.6 / landmine 47(d): a
`graph_axis_window()` written as `*e1 = DS_Y(...)` is invisible to the
`count_code` tripwire that guards it, and `CD2` must be a **REVERSE** drag
because `graph_axis_map`'s forward branch collapses to `lo = q` for any window.
Batch: `doc/claude/overnight_batch_2026_08_01/PLAN.md` item 04. Issue to open:
`doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md`. Spec home:
`doc/claude/specs/waveform_viewer_modes.md` **§18** (new), plus rows in §15.1.

Scouted 2026-08-01 against `826e1b60` (`fluid-editing`). Every file:line below was
re-opened today; every behavioural claim marked **MEASURED** was produced by a
probe run against the built binary, not read off a comment.

---

## 1. The user's ask, verbatim

> In the axis regions - where the LMB press-and-drag for zoom is supported,
> CTRL+Scroll_wheel will support zoom in/out for THAT AXIS ONLY. Zooming will be
> around the mouse pointer. That is, the point(s) on the trace(s) that are at x1
> (position of the mouse pointer) will remain there after zoom.

Two halves: (a) the **region** — the same two margins item 03 (issue 0190) gave
to the LMB drag; (b) the **invariant** — the data coordinate under the pointer
maps to the same screen pixel after the zoom.

---

## 2. What exists today — verified anchors

### 2.1 Item 03 shipped, and its three functions are the foundation

| what | where (verified today) | one line |
|---|---|---|
| `graph_axis_at(i, px, py)` | `src/draw.c:5105` | which axis-number MARGIN a canvas pixel is in → `GRAPH_AXIS_NONE\|_X\|_Y`. Declines the plot box, outside the container, the reorder grip column, and any pixel `graph_legend_at()` (`draw.c:4546`) claims. Bottom-LEFT corner answers Y. Pure geometry: no loaded-raw requirement, no digital refusal. |
| `graph_axis_map(i, ax, p0, p1, &lo, &hi, ctol)` | `src/draw.c:5191` | THE drag formula. Local `Graph_ctx`, the `128\|256` bracket, clamps `p0`/`p1` to the plot extent, refuses travel ≤ `ctol`. |
| `graph_axis_zoom(i, ax, lo, hi)` | `src/draw.c:5277` | THE apply. X writes `x1`/`x2` on rect `i` **and every PARTICIPATING rect** (`rk->sel \|\| (same_sim_type && !(rk->flags & 2)) \|\| k == i`); Y writes `y1`/`y2` — or `ypos1`/`ypos2` on a digital strip — on rect `i` only. No `set_modify`, no `push_undo`. Emits exactly one `log_action` line. |
| `GRAPH_AXIS_NONE/_X/_Y`, `GRAPH_AXIS_ZOOM_MAX_FACTOR` | `src/xschem.h:466-475` | the vocabulary + the zoom-out backstop |
| `graph_click_tol()` | `src/callback.c:59` | exports callback.c's file-private `GRAPH_CLICK_TOL` without exporting the confusion with `GRAPH_TRACE_PICK_TOL` |
| verbs | `src/scheduler.c:3933` / `:3957` / `:3980` (getters, fail soft) and `:5215` (`xschem graph_axis_zoom`, fails loud) | `xschem get graph_axis_at\|graph_axis_map\|graph_axis_drag` and the apply verb |
| the LMB drag arm | `src/callback.c:1414` (arm), `:1825` (band), `:1854` (release/commit) | |
| viewer rung | `src/wave_viewer.tcl:2838` `wviewer::axis_grabbed`, consumed at `:3012` in `strip_drag_press` | the viewer hit-tests nothing |
| suite | `tests/headless/test_wave_axis_zoom.tcl` | **MEASURED baseline today: `ALL PASS (128 checks)` `--nogui`, `ALL PASS (196 checks)` under `$DISPLAY`.** (The spec's §17.6 line still says 119/173 — stale, see §9.) |

### 2.2 The wheel: how the event actually reaches a graph — MEASURED

This is the single most load-bearing fact of the item and **three source comments
in the tree get it wrong**.

`handle_button_press()` (`src/callback.c:7473`) opens with an inline guard:

```c
   if(waves_selected(event, key, state, button)) {
     waves_callback(event, mx, my, key, button, aux, state);
     return;
   }                                              /* src/callback.c:7483-7486 */
```

`handle_mouse_wheel()` is only reached **fourteen branches later**
(`src/callback.c:7541`). So for **any** wheel press whose pointer is inside a
graph rect, `waves_selected()` returns 1, `waves_callback()` runs, and the
function returns — `handle_mouse_wheel()` never executes.

Consequences:

* the four `ACTX_OVER_GRAPH` wheel rows seeded at `src/callback.c:4807-4810` are
  **unreachable dead code**: `handle_mouse_wheel` computes `ctx` from the same
  `waves_selected()` that already declined at `:7483`, so `ctx` can only ever be
  `ACTX_CANVAS` by the time `dispatch_input_action()` runs;
* the comment at `src/callback.c:4804-4806` ("Ctrl-wheel never did, so it has no
  over_graph row and stays canvas pan") is true only when the pointer is **off**
  every graph;
* `src/wave_viewer.tcl:5361-5362` ("Ctrl+wheel is hard-pinned to CANVAS zoom
  (callback.c:4417)") is wrong twice over — over a graph it is neither the canvas
  nor a zoom, and the cited line number no longer exists.

**MEASURED, embedded schematic graph, `graph_use_ctrl_key = 0`** (probe: one
`flags=graph` rect, `x1..x2 = 0..1`, `y1..y2 = 0..2.5`, pixels derived from
`graph_plotbox_at`; each chord fired as `xschem callback .drw 4/5 <px> <py> 0
<4|5> 0 <state>` and the four range tokens + `xorigin`/`yorigin`/`zoom` diffed):

| chord | plot BODY | bottom (X) margin | left (Y) margin |
|---|---|---|---|
| plain wheel | graph X **pan** ±0.05·gw | graph X **pan** | graph Y **pan** ±gh/divy |
| Shift+wheel | graph X **zoom, anchored at the pointer**, ×0.8 in / ×1.2 out | same | graph Y **zoom, anchored**, ×0.8 / ×1.2 |
| **Ctrl+wheel** | graph X **pan** — byte-identical to the plain wheel | graph X **pan** | graph Y **pan** |

`xorigin`/`yorigin`/`zoom` never moved in any of the twelve trials: the canvas is
not involved at all once the pointer is over a strip.

So: **Ctrl+wheel over a graph is today indistinguishable from a plain wheel.**
The feature is real (the ask is not already implemented), and "leave the body
unchanged" means "leave it panning", not "leave it panning the canvas".

Also MEASURED and worth knowing: the shipped Shift+wheel arms
(`src/callback.c:2029`, `:2069`) are **already** a pointer-anchored single-axis
zoom — `zoom_m = (mousex - gr->x1) / gr->w` (`src/callback.c:1328`) is the
normalised pointer, `xx1 = gx1 - var*zoom_m; xx2 = gx2 + var*(1-zoom_m)` with
`var = 0.2*gw`. Their axis choice is `xctx->graph_left` (`:1318-1322`), i.e. the
left margin gives Y and *everything else, body included*, gives X. Item 04 is
that arm with (a) a different modifier, (b) `graph_axis_at()` instead of
`graph_left` as the axis oracle, and (c) confinement to the two margins.

### 2.3 The ASE viewer never forwards the wheel to C

`src/wave_viewer.tcl:6611-6623` binds `<Button-4>`/`<Button-5>` and their
Shift/Control variants (plus `<MouseWheel>` for non-X11) to
`wviewer::wheel_bind` (`:5613`), each with a `break`. Nothing reaches the C
engine. The chain is:

`wheel_bind` → `wviewer::wheel` (`:5560`) → the `ctrl` arm →
`wviewer::wheel_zoom` (`:5454`) → per strip: `wviewer::graph_range` (`:5394`)
then `wviewer::zoom_about` (`:5433`) then one `set_graphs` + `regenerate`.

`wviewer::zoom_about {lo hi a f}` is `{a - (a-lo)*f, a + (hi-a)*f}` — the exact
anchored scale this item needs, already shipped, with `f = 0.8` in / `1/0.8` out
(`:5458`). The anchor `a` comes from `xschem graph_coord $gi $px $py`.
`wheel_zoom` applies X to **every** strip and Y to the **pointed** strip only —
so today, Ctrl+wheel in the X margin of a viewer strip zooms X *and* Y.

That is the behaviour the user wants narrowed.

### 2.4 A defect in item 03 that lands on this item's own code path — MEASURED

`graph_axis_map()` resolves the Y window as

```c
    e1 = S_Y(gr->gy1); e2 = S_Y(gr->gy2);
    A = gr->gy1; B = gr->gy2;                       /* src/draw.c:5215-5217 */
```

— unconditionally the **analog** window and the **analog** transform. But
`graph_axis_zoom()` writes the answer into `ypos1`/`ypos2` when the strip is
digital (`src/draw.c:5305-5313`). `setup_graph_data()` keeps the two apart:
`ypos1`/`ypos2` are parsed at `src/draw.c:3981-3985`, `posh` at `:3987`, and the
digital transform is `dcy`/`ddy`/`dsy` at `:4050-4058`, while `gy1`/`gy2` stay
the `y1`/`y2` tokens.

**MEASURED** on a digital strip with `y1=0 y2=2.5 ypos1=0 ypos2=4`:

```
xschem get graph_axis_at  0 22 526        -> y
xschem get graph_axis_map 0 y  526 267    -> 0.34586281243181671 1.9021063678409851
```

Both endpoints lie inside `[0, 2.5]` — the analog window — and
`graph_axis_zoom` would put them into a band whose real extent is `[0, 4]`. So
item 03's own decision **D-19** ("Y writes `ypos1`/`ypos2` **through `DG_Y`**")
is documented but not implemented; a full-height left-margin drag on a digital
strip mis-zooms it by ~2.6× and anchors in the wrong place.

This is recorded, not hidden. Item 04 does **not** "re-fix a pre-existing bug for
its own sake": it must answer the identical question (*what is this axis's
window, and what pixel extent does it occupy?*) for a second formula, and the
one-home doctrine (landmine 45(a), 47(b)) forbids a second copy. So the answer is
factored into one helper that both formulas call — and the helper is written
correctly, because shipping a **new** gesture with a known-wrong digital branch
is not an option. See D-6.

---

## 3. The design

### 3.1 One formula, in C, reached by both surfaces

```
                       graph_axis_window()        <- NEW, static, draw.c
                       (which window, which pixel extent, digital-aware)
                          |                 |
          graph_axis_map()                  graph_axis_wheel_map()   <- NEW
          (item 03, the DRAG)               (item 04, the WHEEL)
                 |      |                       |          |
    callback.c release  |     callback.c Ctrl+wheel arm    |
                 scheduler.c                     scheduler.c getter
                 `xschem get graph_axis_map`     `xschem get graph_axis_wheel_map`
                                                            ^
                                                            |
                                     wviewer::wheel_zoom's new `axis` arm
```

`graph_axis_zoom()` is unchanged and is THE apply for both.

### 3.2 The maths (this is the specification the suite asserts)

Let `A`,`B` be the axis's current window with `A < B`, `R = B - A`, and `e1`,`e2`
the plot box's extent along that axis in canvas pixels. Let `p` be the pointer's
canvas pixel along that axis, **clamped to `[e1, e2]`**. Let
`K = GRAPH_AXIS_WHEEL_FACTOR` and

```
  f  = wheel-up ? K : 1/K          the range MULTIPLIER
  q  = G_axis(p)                   the data coordinate under the pointer
  u  = (q - A) / R                 0..1
  R2 = R * f
  lo = q - u * R2                  <-- THE ANCHOR TERM
  hi = lo + R2
  if(hi == lo) hi += 1e-6          the shipped idiom
```

**The invariant, and the only assertion that matters:**
`(q - lo) / (hi - lo) == u`, i.e. `q` is at the same fraction of the window and
therefore at the same screen pixel. Substituting: `(q - (q - u·R2))/R2 = u`. ∎

**Why `lo = q - u·R2` and not `lo = A + (R - R2)/2`:** the second form has the
right WIDTH and the wrong POSITION. It passes "the range shrank by K", it passes
"both endpoints moved", and it fails only a test that measures where `q` ended
up. That is exactly the trap item 03's anchored zoom-out had, arriving from the
other side — and it is why the suite's decisive leg re-asks `xschem graph_coord`
for the same pixel **after** the write and requires the same answer.

Two worked checks, which are also two legs:

* **round trip.** `in` then `out` at the same pixel: `R → R·K → R·K·(1/K) = R`,
  and `lo` returns to `A` because `u` is unchanged (the anchor `q` is a fixed
  point of both steps). Exact to floating point, not "approximately".
* **pointer at the left edge.** `p = e1 ⇒ u = 0 ⇒ lo = q = A`, `hi = A + R·f`:
  the window pins its left edge and only the right edge moves.

**Log axes:** nothing special. `gr->gx1..gy2` and `G_X`/`G_Y` are *already* in log
space when `logx`/`logy` is set, which is why the shipped box zoom writes
`dtoa(G_X(...))` straight into `x1`/`x2` with no `pow(10,·)`. Applying one here
would double-convert (landmine 35 from the other side; item 03 D-18 verbatim).

### 3.3 The C engine arm

A new `else if` in `waves_callback()`'s master block, in the same chain as the
Button1 cursor-grab arm (`src/callback.c:1343`) and the Button3 numeric-cursor
arm (`:1416`), i.e. **below** `mkpress` (a marker press pre-empts everything) and
**below** the `graph_top`/`graph_left`/`graph_bottom`/`zoom_m` computation
(`:1313-1328`):

```c
    else if(event == ButtonPress && (button == Button4 || button == Button5) &&
            (state & ControlMask) && !(state & ShiftMask) && !graph_use_ctrl_key) {
      int ax = graph_axis_at(i, (double)mx, (double)my);
      if(ax != GRAPH_AXIS_NONE) {
        double p = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;
        double lo = 0.0, hi = 0.0;
        if(graph_axis_wheel_map(i, ax, p, button == Button4 ? 1 : -1, &lo, &hi)) {
          graph_axis_zoom(i, ax, lo, hi);
          wheel_axis_done = 1;
          need_all_redraw = 1;
        }
      }
    }
```

and the two **plain** wheel arms (`src/callback.c:1955` Button5, `:1992`
Button4) gain `&& !wheel_axis_done`. That flag is the whole "the body is
unchanged" contract: it is set **only** when the axis zoom actually fired, so a
Ctrl+wheel in the body / the legend / the grip column falls through to the pan it
does today.

`need_all_redraw` (not `need_fullredraw`): X propagates, so every rect must
repaint, and the per-graph loop's `draw_graph(i, 1+8+16+…)` (`src/callback.c:2357`)
repaints the background, the grid and the axis NUMBERS under bit 8. There is no
rubber band to erase, so the full `draw()` item 03's release arm needs is not
needed here.

No `GRAPHPAN` term is owed (landmine 36/47(c)): the latch is gated on
`button == Button1 || Button2 || Button3` (`src/callback.c:1687-1688`), so a
Button4/5 press never latches, and a wheel is a single event with no release to
lose.

### 3.4 The ASE viewer

Two surgical edits, no new geometry in Tcl (item 03 D-22 verbatim).

1. `wviewer::wheel_zoom {token dir gi {px {}} {py {}} {axis {}}}` — one new
   trailing optional argument.
   * `axis {}` — **today's behaviour, byte for byte**: X on every strip and Y on
     `gi`, both through `zoom_about`. Every existing caller (`wviewer::wheel`'s
     body case, `wviewer::graph_zoom` at `:5601` for the View menu / `Z` /
     `Ctrl-z`) passes nothing and is untouched.
   * `axis x` — X only, on every strip, each strip's new window taken from
     `xschem get graph_axis_wheel_map $t x $px <in|out>`. A strip the verb
     answers `{}` for is left unchanged (never silently zoomed by a second
     formula).
   * `axis y` — Y only, on `gi` only, same source.
2. `wviewer::wheel`'s `ctrl` arm (`src/wave_viewer.tcl:5570-5576`) gains the one
   rung that asks C which region the pointer is in, and passes the answer down.

### 3.5 What the user will see

| where | plain wheel | Shift+wheel | **Ctrl+wheel** |
|---|---|---|---|
| viewer, plot body | Y pan (unchanged) | X pan of the stack (unchanged) | X on every strip + Y on the pointed strip (**unchanged**) |
| viewer, bottom (X) margin | Y pan (unchanged) | X pan (unchanged) | **X only, on every strip, anchored at the pointer** |
| viewer, left (Y) margin | Y pan (unchanged) | X pan (unchanged) | **Y only, on the pointed strip, anchored at the pointer** |
| embedded graph, body | X pan (unchanged) | X zoom anchored (unchanged) | X pan (**unchanged**) |
| embedded graph, X margin | X pan (unchanged) | X zoom anchored (unchanged) | **X only, participating rects, anchored** |
| embedded graph, Y margin | Y pan (unchanged) | Y zoom anchored (unchanged) | **Y only, that rect, anchored** |

---

## 4. Collision map — every owner of a wheel event over a strip

| claimant | where | verdict for Ctrl+wheel in a margin |
|---|---|---|
| the plain-wheel graph pan | `callback.c:1955`, `:1992` (`!(state & ShiftMask)` matches a Ctrl chord) | **stands down**, and only when the zoom actually fired (`wheel_axis_done`) |
| the Shift-wheel graph zoom | `callback.c:2029`, `:2069` | untouched — the new arm requires `!(state & ShiftMask)`, so Ctrl+Shift+wheel keeps the Shift zoom |
| the canvas Ctrl+wheel pan (`view.pan_up`/`_down`) | `callback.c:4798-4799` via `handle_mouse_wheel:5303` | untouched — it is only reachable **off** every graph (§2.2), and the new arm lives inside `waves_callback` |
| `graph_use_ctrl_key` mode | `callback.c:152`, `:941`, `:5300-5305`; default `0` (`xschem.tcl:15458`) | **the new arm is gated off.** In that mode Ctrl *is* the graph access modifier and Ctrl+wheel is the ordinary graph wheel; taking it would make graphs unusable there |
| the reorder GRIP column | `GRAPH_REORDER_HANDLE_W`, refused inside `graph_axis_at` (`draw.c:5137`) | declines, unconditionally, at every height |
| the vertical / digital LEGEND | `graph_legend_at` (`draw.c:4546`), refused inside `graph_axis_at` (`draw.c:5139`) | declines |
| the x/y CURSORS | grab flags `graph_flags & (16\|32\|512\|1024)` | **irrelevant here.** Those are *drag* grabs armed by a Button1 press; a wheel arms nothing and a wheel while a cursor drag is in flight is already short-circuited by `if(xctx->ui_state & GRAPHPAN) goto finish;` (`callback.c:1312`) |
| the waveform MARKERS | `mkpress` (`callback.c:1335`) is Button1-only | no interaction |
| the viewer's strip drag-reorder / trace drag | Button1 only | no interaction |
| the viewer's `<Control-Button-4/5>` binds | `wave_viewer.tcl:6617-6618`, `:6624` | already bound to `wheel_bind ... ctrl`; the item narrows what that does in the margins, adds no bind |
| the 5-screen-px rect-edge inset | `waves_selected`'s `border = 5.0 * tk_scaling * xctx->zoom` (`callback.c:145`) | outermost 5 px of every margin is not graph-routed at all — shipped, §15.7's last row, unchanged |

---

## 5. Resolved spec holes

Numbering continues item 03's `D-` series so the two features share one ledger.

### D-25. Where does the gesture live — C engine, Tcl viewer, or both?

**Decision.** Both surfaces, **one formula in C**. A new arm in `waves_callback`
serves embedded schematic graphs; the ASE viewer's existing Tcl wheel handler
learns to ask C for the region *and* for the new window, and writes the result
into its own model.

**Why.** PLAN's "likely files" list assumed the item is a `callback.c` change.
Source says a C-only implementation would be **silently dead in the viewer** —
the very failure mode PLAN Q10 flagged — because `wave_viewer.tcl:6611-6623`
binds every wheel sequence with a `break` and never forwards. And a Tcl-only
implementation would leave embedded graphs behind, contradicting item 03, which
deliberately put the drag in the engine "beside the Button3 box zoom it is the
twin of". Putting the **arithmetic** in C and letting the viewer consume it as a
query keeps landmine 45(a) satisfied with no third copy.

**Rejected.** C-only (dead in the viewer). Tcl-only (dead on embedded graphs, and
a second copy of the map). Making the viewer forward the wheel to C: it would
work, but the margin zoom would then write only the rect and be discarded by the
next `regenerate` (a plain window resize), while the body zoom on the same
modifier survives — an inconsistency inside one gesture family that no user could
predict.

### D-26. What is the region?

**Decision.** `graph_axis_at()`, unchanged and unwidened: bottom margin = X, left
margin = Y, bottom-left corner = Y; plot box, outside-the-container, the grip
column and any legend pixel all decline.

**Why.** PLAN said "reuse it, do not write a second one" and source agrees
completely — it is already the shared oracle for the C gesture and (via
`graph_axis_drag`) for the viewer's press seam. Widening or re-deriving it here
would give one feature two region definitions.

**Rejected.** A wheel-specific region (e.g. "anywhere outside the plot box").

### D-27. Zoom factor per wheel click.

**Decision.** `GRAPH_AXIS_WHEEL_FACTOR = 0.8`, a new `#define` in `src/xschem.h`
next to `GRAPH_AXIS_ZOOM_MAX_FACTOR`. Wheel-up multiplies the range by `0.8`;
wheel-down by `1/0.8`. **Mirrored in Tcl** as `wviewer::wheel_zoom`'s existing
`0.8` literal, with a "change both" comment on each side and a source-level test
leg asserting they are equal.

**Why.** PLAN Q1 said "match the existing graph wheel-zoom factor in
`callback.c`". Source shows there are *two* existing factors and they differ:
`callback.c`'s **Shift**+wheel arms use `var = 0.2 * range` → ×0.8 in / **×1.2**
out (MEASURED: `[0,1] → [0.0999, 0.8999]` and `→ [-0.0999, 1.1001]`), which is
**not reversible** — in-then-out loses 4 % of the range every round trip. The
viewer's **Ctrl**+wheel uses ×0.8 / ×(1/0.8), which is exact. The gesture being
extended is Ctrl+wheel, and the viewer is this batch's subject, so the viewer's
Ctrl+wheel factor is the right ancestor; it also buys a tight round-trip
assertion instead of a loose one.

**Rejected.** Copying the Shift-wheel 0.8/1.2 pair (a "returns approximately to
the start" leg is the kind that passes while broken). A brand-new number. Two
factors (0.2 analog / 0.05 digital, as the Shift-wheel arms carry) — one gesture,
one step.

### D-28. Where does the wheel formula live, and how does a headless suite reach it?

**Decision.** `graph_axis_wheel_map(i, axis, p, dir, &lo, &hi)` in `src/draw.c`,
immediately after `graph_axis_map()`, exposed as
`xschem get graph_axis_wheel_map <gi> x|y <p> in|out` → `{lo hi}` | `{}` (fail
soft). The **direction word** is the input, not a factor, so the constant has
exactly one home *inside* the formula and a suite driving the verb is driving the
product's own step size.

**Why.** Landmine 47(b) in a second shape, and the same reason
`graph_axis_map` was exposed: it is the only way to assert **both endpoints**
(and hence the anchor) without replaying a Tk gesture, and it is what makes the
`--nogui` arm meaningful.

**Rejected.** Taking `f` as a numeric argument (the constant would then have a
second home at every call site, including the getter — precisely the
`graph_click_tol()` problem item 03 had to solve after the fact). Computing the
map inline in the arm and again in the viewer.

### D-29. Two formulas need the same axis window. Where does that live?

**Decision.** A new `static` helper in `src/draw.c`,
`graph_axis_window(gr, axis, &A, &B, &e1, &e2)` (called after the caller's own
`setup_graph_data` + `128|256` bracket), used by **both** `graph_axis_map()` and
`graph_axis_wheel_map()`. It carries the **digital** branch: on a digital strip
the Y window is `ypos1`/`ypos2` and the pixel extent comes from the digital
transform (`DS_Y`), not `gy1`/`gy2` / `S_Y`.

**Why.** The new formula must answer the identical question, and a second copy is
the drift landmine 45(a)/47(b) exists to prevent. Writing the helper correctly is
not optional: source shows the existing analog-only resolution is **wrong for
digital strips** (§2.4, MEASURED), and item 04's Y arm would otherwise ship that
same defect as new behaviour. This is the *minimum* correct thing, not an
opportunistic fix — and it makes item 03's own decision D-19 true for the first
time.

**Rejected.** Duplicating the analog-only resolution into the new function
(consistent-but-wrong, and a second home). Writing the new function correctly and
leaving `graph_axis_map` alone (the drag and the wheel would then disagree on
digital strips — a worse maintenance smell than either). Refusing digital strips
in the wheel arm (arbitrary, and `graph_axis_at` deliberately does not refuse
them).

### D-30. Ctrl+wheel over the strip BODY — what does "unchanged" mean?

**Decision.** It keeps doing exactly what it does today, which — **MEASURED** —
is a **graph X pan of 0.05·gw**, identical to a plain wheel. Not a canvas pan,
not a canvas zoom. The plain-wheel arms stand down **only** when the new arm
actually fired.

**Why.** PLAN Q3 said "out of scope, unchanged, and witnessed as unchanged", but
the tree's own comments would have led an implementer to believe "unchanged"
means "the canvas pans" (`callback.c:4805`) or "the canvas zooms"
(`wave_viewer.tcl:5362`). Both are false over a graph (§2.2). The regression
witness must therefore assert the *measured* behaviour, or it will be written
against a comment and pass vacuously.

**Rejected.** Making Ctrl+wheel inert over the body (loses a shipped affordance).
Extending the axis zoom to the body (the user asked for the margins, and the body
already has Shift+wheel).

### D-31. Plain / Shift / Alt+wheel in the axis regions.

**Decision.** Unchanged, all of them, with explicit regression witnesses.
MEASURED today: plain wheel in the X margin pans X, in the Y margin pans Y;
Shift+wheel in the X margin zooms X anchored ×0.8/×1.2, in the Y margin zooms Y.
Alt+wheel falls through the `else` branch of `handle_mouse_wheel`
(`callback.c:5306-5318`) only when off a graph, and over a graph reaches
`waves_callback`, which has no Alt arm — inert. All unchanged.

**Why.** PLAN Q2 / Q4. The witnesses matter because the new arm sits in the same
`if/else` chain and the same event type.

**Rejected.** Nothing.

### D-32. `graph_use_ctrl_key`.

**Decision.** The new arm is gated on `!graph_use_ctrl_key`. In that mode Ctrl is
the graph *access* modifier and Ctrl+wheel remains the ordinary graph wheel.

**Why.** Source: `waves_selected:152` refuses every graph event without Ctrl in
that mode, `waves_callback`'s `access_cond` (`:941`) is the same test, and
`handle_mouse_wheel`'s Shift and Ctrl branches (`:5300`, `:5303`) already carry
the identical `!graph_use_ctrl_key` reservation. Taking Ctrl+wheel there would
leave that mode with no graph wheel pan at all. Default is `0`
(`xschem.tcl:15458`), so the feature is on out of the box.

**Rejected.** Ignoring the flag (would break the mode). Making the axis zoom the
Ctrl+wheel behaviour in that mode too (Ctrl carries no information there — every
graph gesture holds it).

### D-33. `sharedx` stacks — does an X zoom hit one strip or all?

**Decision.** All, via the shipped participation predicate inside
`graph_axis_zoom()` for the C path, and via `wheel_zoom`'s existing
every-strip X loop for the viewer path. Y is always the one strip.

**Why.** PLAN Q5, and item 03's D-8 measured the mechanism: the C engine cannot
see the viewer's `sharedx` at all, and `wviewer::graph_props` never emits
`unlocked`, so X follows every same-`sim_type` strip regardless. The viewer path
calls the C map **per strip**, so each strip is anchored in its own window at the
same pointer pixel — which is the same answer when the windows agree and the
right answer when they do not.

**Rejected.** Consulting `sharedx` from C (impossible). Zooming only the pointed
strip's X (would desynchronise a time-aligned stack).

### D-34. Range clamping.

**Decision.** No new clamp and no reuse of `GRAPH_AXIS_ZOOM_MAX_FACTOR`. The only
guard is the shipped `if(hi == lo) hi += 1e-6`, plus the existing
`R == 0.0 || e2 == e1 ⇒ return 0` refusal.

**Why.** PLAN Q9 said "share the clamp, do not duplicate the number". Source shows
what that constant actually guards: `R2 = R / |s|` in the *drag* map, where `|s|`
is a user-controlled drag span that can approach zero and put an `inf` into
`x1`/`x2` permanently (`xschem.h:469-475`). The wheel map has no such division —
`R2 = R * f` with `f` a compile-time constant — so importing the clamp would be
cargo. Repeated wheel-ins shrink `R` geometrically but can never reach 0 in
finite clicks, and `hi == lo` catches the denormal end.

**Rejected.** Applying `GRAPH_AXIS_ZOOM_MAX_FACTOR` to the accumulated range (it
is a per-gesture factor bound, not a window-size bound, and a "minimum span"
policy is a new user-visible rule nobody asked for).

### D-35. Dirty flag, C undo, viewer undo, `capture_live_graph_state`.

**Decision.** None of them, on either path. Item 03's D-14/D-15/D-16 verbatim.

**Why.** PLAN Q7. Landmine 19: the whole of `waves_callback` contains zero
`set_modify(1)` and zero `push_undo()`; a zoom is view state, and the read-only
ASE viewer buffer must not be dirtied. Landmine 47(c): a C-side view write is a
*producer* for the capture a later Tcl mutation runs, never a consumer.
`wviewer::wheel_zoom` pushes no undo snapshot today and must not start
(§14.1 — window view state is deliberately outside a snapshot), or a single `u`
after a zoom would revert an unrelated model edit.

**Rejected.** Copying the marker discipline (markers are durable content; a zoom
is not).

### D-36. Does the viewer path survive a `regenerate` / window resize?

**Decision.** **Yes** — and that is a deliberate difference from item 03. The
viewer writes the C map's answer into the Tcl **model** (`set_graphs` +
`regenerate`), exactly as `wheel_zoom` already does for the body zoom.

**Why.** The consequence item 03 documented and accepted — "a plain window resize
discards it" — is tolerable for a gesture that has no Tcl in its loop. Here there
*is* Tcl in the loop (the viewer owns the wheel bind), so writing the model costs
nothing and avoids the surprise of two Ctrl+wheel gestures with different
lifetimes.

**Rejected.** Having the viewer call `xschem graph_axis_zoom` (rect-only, and
inconsistent with the body arm three lines away).

### D-37. Replay logging.

**Decision.** The **C engine** path logs exactly one
`xschem graph_axis_zoom <gi> x|y <lo> <hi>` line at `%.17g`, for free, because it
applies through `graph_axis_zoom()`. The **viewer** path logs nothing, exactly
like `wviewer::wheel_zoom`, `pan_x` and `graph_zoom` today.

**Why.** PLAN Q8 asked for numeric bounds and the engine path delivers them,
assertable in a `--logdir` child (the AL* pattern). The viewer's `log_action`
seam is for **model mutations** (`move_strip`, `move_trace`, `set_target_strip`,
`clear_all`); ranges are not in that class — no viewer range gesture has ever
logged, and adding a line to one arm of one modifier would make a replayed
session inconsistent with itself.

**Rejected.** Logging from the viewer (one line in a family of five silent ones).
Logging pixels (they do not exist at replay time).

### D-38. Which strip does the viewer act on, and what if the C mouse mirror is stale?

**Decision.** `wviewer::graph_at_pointer` (shipped) resolves `gi`; the axis
question is then asked of C with the **event's own** `%x`/`%y`. If the mirror is
stale (a wheel with no preceding Motion), `graph_axis_at $gi $px $py` answers
`""` and the gesture degrades to today's body zoom — never to the wrong strip.

**Why.** `graph_at_pointer` reads `mousex_snap`/`mousey_snap`
(`wave_viewer.tcl:5385-5386`), the C mouse mirror, which landmine (§8, strip
drag) warns is stale for an event with no preceding Motion. Introducing a second
Tcl strip resolver here would be the exact second-source-of-truth item 03's D-22
refused. The failure mode is graceful and the test discipline (replay the whole
event sequence, Motion first) covers the real path.

**Rejected.** A `strip_bands_px`-based resolver for this gesture alone. Changing
`graph_at_pointer` (out of scope; it serves four other callers).

### D-39. Empty strip / no raw loaded / off-screen strip.

**Decision.** Allowed for empty and no-raw (pure geometry — item 03 D-20); the
map refuses an **off-screen** graph through the shipped
`gr->scx == 0.0 || gr->scy == 0.0` sentinel and returns `{}`.

**Why.** `graph_axis_at` already declines nothing on the raw axis, and
`setup_graph_data` produces a valid transform from tokens alone. Landmine 37 says
the `scx/scy` sentinel is the correct way to detect the off-screen early return
for a caller that needs the transform.

**Rejected.** Copying `graph_plotbox_at`'s raw gate (would make the whole gesture
dead before the first simulation).

### D-40. Which suite?

**Decision.** Extend `tests/headless/test_wave_axis_zoom.tcl` (item 03's suite)
with five new groups. No new file, no `full_audit.sh` registration change.

**Why.** PLAN's own suggestion, and it is right: that suite already owns the axis
geometry, already has the `az_box`/`az_xmargin`/`az_ymargin` pixel scanners, the
`az_define` source-constant reader, the `az_windows` every-rect witness, the
`--logdir` child-process pattern and a live ASE viewer under `$DISPLAY`.
`full_audit.sh` globs `test_*.tcl` (`:118`) so the file is already discovered.
Deliberately **not** `test_wave_markers.tcl`, which carries this batch's inherited
red leg (`MF1`).

**Rejected.** A new suite (would duplicate ~250 lines of scanners).

---

## 6. Formulas and invariants the suite asserts numerically

With `K` read out of `src/xschem.h` at run time (never a frozen copy):

| # | assertion |
|---|---|
| 1 | `hi - lo == (B - A) * K` on wheel-up; `== (B - A) / K` on wheel-down |
| 2 | **`(q - lo)/(hi - lo) == (q - A)/(B - A)`** where `q = G_axis(p)` — the fixed point |
| 3 | equivalently and decisively: `xschem graph_coord <gi> <px> <py>` returns the **same** data coordinate before and after the apply |
| 4 | `in` then `out` at the same pixel restores `x1`/`x2` (or `y1`/`y2`) to within 1e-12 relative |
| 5 | `p = e1 ⇒ lo == A`; `p = e2 ⇒ hi == B` (edge pinning falls out of the same map) |
| 6 | X: every PARTICIPATING rect's `x1`/`x2` moved and every rect's `y1`/`y2`/`ypos1`/`ypos2` is byte-identical. Y: the reverse, on the pointed rect only |
| 7 | digital strip: `graph_axis_wheel_map … y` **and** `graph_axis_map … y` both answer inside `[ypos1, ypos2]` and outside `[y1, y2]` (staged disjoint) |
| 8 | `GRAPH_AXIS_WHEEL_FACTOR` (from `src/xschem.h`) `==` the `f` literal in `wviewer::wheel_zoom` (from `src/wave_viewer.tcl`) |
| 9 | `wviewer::zoom_about $A $B $q $f` `==` `xschem get graph_axis_wheel_map` for the same strip and pixel — the two anchored-scale implementations agree |
| 10 | the anchored expression appears **once** in `draw.c`; `graph_axis_wheel_map(` is called once from `callback.c` and once from `scheduler.c`; `graph_axis_window(` is called exactly twice in `draw.c` |

---

## 7. Sabotage plan (each must kill EXACTLY its target)

| # | sabotage | must kill, and nothing else |
|---|---|---|
| SAB-1 | in `graph_axis_wheel_map`, replace `zlo = q - u * R2;` with `zlo = A + (R - R2) / 2.0;` (zoom about centre) | the fixed-point legs (`CW3`, `CE2`, `CV6`) — and **not** `CW2`/`CW1`'s width legs, which is the whole point |
| SAB-2 | in the `callback.c` arm, call `graph_axis_zoom` for **both** axes | the "other axis byte-identical" legs (`CW6`, `CE3`) |
| SAB-3 | in the `callback.c` arm, drop the `graph_axis_at` test and always fire | the "Ctrl+wheel in the BODY still pans" leg (`CE5`) |
| SAB-4 | in `graph_axis_window`, delete the `digital` branch | the digital-band legs (`CD1`, `CD2`) and the source count `CS4` |
| SAB-5 | change `wviewer::wheel_zoom`'s `0.8` literal to `0.75` | the mirrored-constant leg (`CS2`) |
| SAB-6 | in `wviewer::wheel`'s `ctrl` arm, drop the `axis` argument (always both axes) | the viewer single-axis legs (`CV1`/`CV2`) |
| SAB-7 | remove `&& !wheel_axis_done` from the two plain-wheel arms | the "the margin zoom is not also a pan" leg (`CE1b`) |

### 7.1 Added by the repair pass (2026-08-01)

| # | sabotage | must kill, and nothing else |
|---|---|---|
| SAB-8 | in the `callback.c` arm, delete `&& !(state & ShiftMask)` | `CE13`'s two log legs, `CE12`'s Y-margin leg, `CE9`'s two line-count legs. **No X-margin window leg moves** — the Shift arm downstream recomputes from the pre-zoom `master_gx1/gx2` and overwrites with the same numbers, which is why `CE13` had to be an assertion about the LOG |
| SAB-9 | `wviewer::wheel_zoom`'s X arm asks C for `$gi` instead of `$t` | `CV7`'s two per-strip legs only. `CV1` stays green: its two strips carry the identical window, so a broadcast and a per-strip anchor agree — the fixture coincidence `CV7` exists to break |
| SAB-10 | `wviewer::wheel_zoom`'s Y branch gated on `$t == 0` | `CV8`'s two legs only. `CV2` stays green: it points at strip 0 |
| SAB-11 | `q = pow(10.0, q)` on a log axis in `graph_axis_wheel_map` | `CW10`/`CW11`'s six log legs only. `CW10`'s WIDTH leg survives — the same anchor-vs-width asymmetry SAB-1 exploits |

### 7.2 Added by the SECOND repair pass (2026-08-01)

| # | sabotage | must kill, and nothing else |
|---|---|---|
| SAB-12 | in the `callback.c` arm, `double p = (ax == GRAPH_AXIS_X) ? (double)mx : (double)mx;` — the Y branch handed the X pixel | `CE3b`, `CE3c` and `CE10`'s map leg **only**. Every width leg, every "the other axis is byte-identical" leg and every "the other strip did not move" leg stays GREEN — they cannot see an anchor error, which is the point |
| SAB-13 | `wviewer::wheel_zoom`'s y arm passes `$px` where it should pass `$py` | `CV2b`, `CV2c` **only** |

**§6's assertion 2 was true of X and vacuous on Y, and that is the lesson.**
The table in §6 lists the fixed point as "the only assertion that matters", and
the X legs carry it. The Y legs did not — not because anyone decided they should
not, but because the pixel they fired at came from a helper (`az_ymargin`) whose
y is the plot box's **CENTRE**. At u = 0.5 the anchored form and a
zoom-about-centre form give the same two numbers, so on Y the file measured only
assertion 1 (the width) and assertion 6 (the other axis / other rect). Both
survive an arbitrarily wrong anchor: MEASURED, an 18 %-of-range error in the Y
window with all 361 checks green.

The repair is probe placement, not new product code: `$epy = eby2 - int(ebh*0.25)`
on the C path, `cv_yprobe`'s new `fracs` **list** on the viewer path (`CV2` passes
off-centre heights only and goes red if none lands; `CV8`, which is about which
STRIP moved, takes the default list that ends at 0.5), each with a teeth leg
asserting the off-centre-ness — the CV one stated in **data** space
(`|u - 0.5| > 0.1`) so no box re-scan can drift it — and then the two assertions
the X legs already had. `az_xmargin`/`az_ymargin` keep returning the centre (they
are correct for a REGION leg) and now carry a ⚠ block naming the trap.

**Why the height is a list.** A single 0.25 height found no Y-margin pixel at all
on **strip 1** about 1 run in 3 (strip 0 was fine 11/11): which heights of the
left margin `graph_axis_at` claims depends on the layout of the moment, and
`graph_legend_at` declines first for whatever band the legend occupies. Asking
rather than predicting is 0190's rule; asking at more than one height is the same
rule one level down.

**D-33's fixture requirement, learned here.** The decision says the viewer calls
the map per strip so each is anchored "in its OWN window at the same pointer
pixel — the same answer when the windows agree and the right one when they do
not". Every leg written for it staged the two strips to the *same* window, i.e.
exactly the half of the sentence that cannot distinguish the two readings. A
decision whose whole content is "and the right one when they differ" needs a
fixture in which they differ; `CV7` is that fixture (`0..1.0` and `0..2.0`,
`sharedx` 0 so `regenerate` leaves them alone).

---

## 8. Files this item touches

| file | why |
|---|---|
| `src/xschem.h` | `GRAPH_AXIS_WHEEL_FACTOR` + the `graph_axis_wheel_map` prototype and its doc comment |
| `src/draw.c` | `graph_axis_window()` (new static) + `graph_axis_wheel_map()` (new); `graph_axis_map()` rewired onto the helper |
| `src/callback.c` | the Ctrl+wheel arm, the `wheel_axis_done` local, `&& !wheel_axis_done` on the two plain arms, and a correction to the stale comment at `:4804-4806` |
| `src/scheduler.c` | `xschem get graph_axis_wheel_map` in the `case 'g':` getter chain |
| `src/wave_viewer.tcl` | `wheel_zoom`'s `axis` argument, `wheel`'s `ctrl` rung, and a correction to the stale comment at `:5361-5362` |
| `tests/headless/test_wave_axis_zoom.tcl` | `CW*` `CD*` `CS*` `CE*` `CV*` |
| `doc/claude/specs/waveform_viewer_modes.md` | new §18, rows in §15.1 |
| `doc/claude/code_analysis/waveform_subsystem_reference.md` | new landmine 48 + §5/§9/§10 updates |
| `doc/claude/issues/0191-…md` | the issue |
| `doc/claude/issues/0190-axis-region-drag-zoom.md` | one line recording that its D-19 digital branch was unimplemented and is corrected here |

---

## 9. Claims in PLAN.md / the tree that source refutes

1. **PLAN Q10 ("verify the wheel event reaches the viewer") understates it.** The
   viewer receives it fine; it is the **C engine** side that is surprising:
   `handle_button_press:7483` pre-empts `handle_mouse_wheel:7541` for every wheel
   press over a graph, so the `ACTX_OVER_GRAPH` wheel binding rows
   (`callback.c:4807-4810`) are unreachable dead code and a binding-table row is
   **not** a viable way to add this gesture.
2. **PLAN Q3's premise.** Ctrl+wheel over a graph body is not a canvas pan today;
   MEASURED, it is a graph X pan identical to the plain wheel.
3. **PLAN Q1 ("match the existing graph wheel-zoom factor in `callback.c`").**
   There are two existing factors and they differ; `callback.c`'s is not
   reversible. See D-27.
4. **PLAN Q9 ("share the clamp").** `GRAPH_AXIS_ZOOM_MAX_FACTOR` guards a
   division by a drag span that does not exist in a wheel map. See D-34.
5. **`callback.c:4804-4806`** — "Ctrl-wheel … stays canvas pan" is true only off
   a graph.
6. **`wave_viewer.tcl:5361-5362`** — "Ctrl+wheel is hard-pinned to CANVAS zoom
   (callback.c:4417)" is wrong on both counts and cites a line that no longer
   exists.
7. **Item 03's D-19 / `waveform_viewer_modes.md` §17.3** — "Y writes
   `ypos1`/`ypos2` **through `DG_Y`**". MEASURED: `graph_axis_map` computes the Y
   window from `gy1`/`gy2` and `S_Y` unconditionally; on a digital strip with
   `y1..y2 = 0..2.5` and `ypos1..ypos2 = 0..4` it answered `0.3459 1.9021`.
   Corrected here (D-29).
8. **`waveform_viewer_modes.md` §17.6** — "119 checks in the `--nogui` arm, 173
   with a display". MEASURED today: **128** and **196**.

## 10. Out of scope, recorded, not fixed here

* The **`GRAPHPAN` latch term `|| xctx->graph_axis_drag`** (`callback.c:1714`)
  that item 03's verifier rejected as untested is untouched by this item: a
  Button4/5 press never enters the latch (`:1687-1688` admits Button1/2/3 only).
* `find_closest_wave`'s per-node `extra_rawfile` switch (backlog fruit #3).
* The unreachable `ACTX_OVER_GRAPH` wheel rows themselves. This item corrects the
  **comment** that misdescribes them but does not delete the rows: they are inert,
  and removing them is a separate change with its own regression surface
  (`xschem bind` / `keybindings.csv` round-trip).

## 11. Deliverables no assertion can reach (the eyeball list)

The item introduces **no new rendering** — no band, no glyph, no chrome. What a
test cannot see:

* whether one wheel click of 20 % is the right *step* in a narrow margin, or
  whether the margin is a comfortable place to aim the pointer at all;
* whether the anchored zoom *feels* anchored when the pointer sits in the margin
  rather than on a trace (the invariant is exact; the perception is not tested);
* whether narrowing the viewer's margin Ctrl+wheel from "both axes" to "one axis"
  reads as a feature or as a dead zone to a user who learned the old behaviour.

Per PLAN's assertability note, feel alone does not force `[E]`: this item is an
`[x]` candidate.
