# OVB-04 — CTRL+wheel in an axis-number region zooms that axis only, about the pointer

You are implementing item **04** of the overnight batch
`doc/claude/overnight_batch_2026_08_01/PLAN.md`. Repo
`/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

**The user's spec, verbatim:**

> In the axis regions - where the LMB press-and-drag for zoom is supported,
> CTRL+Scroll_wheel will support zoom in/out for THAT AXIS ONLY. Zooming will be
> around the mouse pointer. That is, the point(s) on the trace(s) that are at x1
> (position of the mouse pointer) will remain there after zoom.

The scout has already resolved every spec hole. **Read the decision doc first and
implement what it decided** — do not re-litigate D-25…D-40.

Issue to open: `doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md`.
Spec home: `doc/claude/specs/waveform_viewer_modes.md` **§18** (new).

---

## READ FIRST (in order)

1. `doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md`
   — **your contract.** Design, all resolved spec holes, the collision map, the
   exact formulas, the sabotage table, the eyeball list.
2. `doc/claude/code_analysis/waveform_subsystem_reference.md` — the WIRING.md of
   this subsystem. §2.3 (a graph is an `xRect`), §4 (render pipeline), §5
   (interaction), §9 (verb surface), §10 (the "New graph GESTURE IN A MARGIN"
   recipe), landmines **3, 6, 11, 19, 20, 35, 36, 37, 43, 44, 45, 47**.
3. `doc/claude/specs/waveform_viewer_modes.md` — **§17** (item 03, the LMB axis
   drag: you are building its wheel twin and reusing all three of its functions),
   §15.1 (the LMB/RMB ownership table you will add rows to), §15.7 (what a hover
   draws by region), §14.1 (why view state is outside a viewer undo snapshot).
4. `doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md` — item
   03's decisions D-1…D-24. Yours continue the same numbering and several of
   yours are "D-n verbatim".
5. `doc/claude/specs/graph_markers.md` §7.2/§7.3 (the Button1 precedence table —
   you must not disturb it).
6. `CLAUDE.md` — build, tests, conventions.

---

## DISCIPLINE (non-negotiable)

* **C89.** Declarations at the top of a block. No `//` comments in `.c` files.
  Allocations use `my_malloc`/`my_strdup`/`my_realloc` with the literal
  `_ALLOC_ID_` placeholder — never a hand-written number.
* **A new `xschem get` sub-key is letter-dispatched.** `graph_axis_wheel_map`
  goes in `xschem_cmds_g`'s `get` `case 'g':` chain, beside `graph_axis_map`. A
  key filed in the wrong first-letter function is **silently unreachable** — no
  error, the getter just answers nothing.
* **Constants mirrored between C and Tcl must be changed on both sides**, and
  the mirror must carry a "change both" comment on each side (the
  `GRAPH_REORDER_HANDLE_W` precedent). `GRAPH_AXIS_WHEEL_FACTOR` is such a
  constant.
* **`my_snprintf` does not understand `%.*g`.** Use it for `%.17g` (it does
  handle that) exactly as `scheduler.c:3968` already does; `log_action` is a
  plain varargs printf and takes `%.17g` directly.
* **A green suite does not prove your code ran.** Every named sabotage below
  must fail **exactly** its target check; revert it with a targeted
  `git checkout -- <file>` **only after** `git diff` confirms that file holds
  nothing but the sabotage; then a clean re-run must be green again.
* **Run every suite with `GUI_GATE=0` in the environment.** Nobody is at the
  desk. Prefer `tests/headless/run_suites.sh`; never a bare `for` loop over
  `./src/xschem`.
* **Never `git push`. Never `git reset --hard`. Never `git add -A` / `git commit
  -a`.** Stage the explicit file list at the end of this prompt and nothing else.
  Do not touch the ~60 pre-existing untracked scratch paths in the tree.
* Scratch files go in the test's own `test_scratch` dir, never the repo root.
* **Do not "re-fix" pre-existing bugs you notice outside this item's scope** —
  record them in your summary. (The one exception is already decided for you:
  D-29's shared `graph_axis_window()` helper, which necessarily corrects item
  03's digital branch because your new formula asks the same question.)

---

## ANCHORS (verified by the scout 2026-08-01 — **verify, do not trust**)

Line numbers drift. Grep the symbol, then confirm the line says what this table
claims before you edit near it.

### `src/draw.c`

| line | symbol | what it does |
|---|---|---|
| 4546 | `graph_legend_at()` | which legend slot a pixel is in; `graph_axis_at` uses it to decline the vertical/digital legend |
| 5031 | `graph_plotbox_at()` | is this pixel in the plot box (refuses digital + requires a raw) |
| **5105** | **`graph_axis_at(i, px, py)`** | **which axis MARGIN a canvas pixel is in → `GRAPH_AXIS_NONE/_X/_Y`. Reuse verbatim; do not widen.** |
| **5191** | **`graph_axis_map(...)`** | **item 03's DRAG formula. Lines 5213-5219 are the axis-window resolution you are factoring out (D-29).** |
| **5277** | **`graph_axis_zoom(i, axis, lo, hi)`** | **THE apply. X propagates + Y per-strip + digital `ypos` + one `log_action`. Reuse verbatim; do not edit.** |
| 3981-3987 | `setup_graph_data` digital block | parses `ypos1`/`ypos2`, computes `posh` |
| 4050-4058 | same | `dcy`/`ddy` and `dsy` — the DIGITAL y transform (`DS_Y`/`DG_Y`) |

### `src/callback.c`

| line | what it does |
|---|---|
| 59 | `graph_click_tol()` — exports the file-private `GRAPH_CLICK_TOL` |
| **145** | `waves_selected`'s `border = 5.0 * tk_scaling * xctx->zoom` — the 5-screen-px rect-edge inset; the outermost band of every margin is not graph-routed |
| **152** | the `graph_use_ctrl_key` reservation in `waves_selected` |
| **927** | `waves_callback()` starts |
| 931 / 941 | the `graph_use_ctrl_key` local and `access_cond` |
| **1312** | `if(xctx->ui_state & GRAPHPAN) goto finish;` — a wheel during an in-flight drag never reaches the arm |
| **1313-1328** | `graph_top` / `graph_left` / `graph_bottom` / `zoom_m` — computed just above where your arm goes |
| 1335 | `mkpress = graph_marker_press(...)` — Button1 only; pre-empts the whole chain |
| **1343** | `else if(event == ButtonPress && button == Button1)` — the cursor-grab arm |
| **1414** | `graph_axis_press_arm(i, mx, my)` — item 03's arm, inside the Button1 branch |
| **1416** | `else if(event == ButtonPress && button == Button3)` — **your new arm goes after this branch, in the same chain** |
| **1687-1688** | the `GRAPHPAN` latch condition — `button == Button1 \|\| Button2 \|\| Button3` only, so **a wheel never latches and owes no latch term** |
| **1955** | `else if(event == ButtonPress && button == Button5 && !(state & ShiftMask))` — the plain wheel-down graph PAN. **Add `&& !wheel_axis_done`.** |
| **1992** | the Button4 twin. **Add `&& !wheel_axis_done`.** |
| **2029 / 2069** | the **Shift**+wheel graph ZOOM arms — already pointer-anchored, `var = 0.2 * range`, axis chosen by `graph_left`. **Do not touch.** |
| **2357** | the per-graph `if(need_redraw \|\| need_all_redraw \|\| …) { setup_graph_data; draw_graph(i, 1+8+16+…); }` — what `need_all_redraw` buys you |
| **4804-4806** | the comment claiming Ctrl-wheel "stays canvas pan" over a graph. **Wrong; correct it.** |
| 4807-4810 | the four `ACTX_OVER_GRAPH` wheel binding rows — **unreachable dead code** (see 7483). Leave the rows; fix the comment. |
| 4989 | `current_input_ctx()` → `waves_selected()` |
| 5279-5326 | `handle_mouse_wheel()`; `:5303-5305` is the Ctrl→`ACTX_CANVAS` branch |
| **7483-7486** | `handle_button_press`'s inline `if(waves_selected(...)) { waves_callback(...); return; }` — **this is why `handle_mouse_wheel` is never reached over a graph and why a binding row cannot implement this feature** |
| 7541 | `else if(handle_mouse_wheel(...)) return;` — fourteen branches later |

### `src/xschem.h`

| line | what |
|---|---|
| 393 | `GRAPH_REORDER_HANDLE_W 14` — the "mirrored in Tcl, change both" precedent |
| 418 | `GRAPH_TRACE_PICK_TOL 10.0` |
| **466-468** | `GRAPH_AXIS_NONE / _X / _Y` |
| **469-475** | `GRAPH_AXIS_ZOOM_MAX_FACTOR 1000.0` + the comment explaining it guards a **division by a drag span** — **put `GRAPH_AXIS_WHEEL_FACTOR` right after it** |
| **2277-2313** | the item-03 prototype block (`graph_axis_at`, `graph_axis_map`, `graph_click_tol`, `graph_axis_zoom`) — **add `graph_axis_wheel_map` here** |

### `src/scheduler.c`

| line | what |
|---|---|
| **3933** | `xschem get graph_axis_at` |
| **3957-3972** | `xschem get graph_axis_map` — **copy this shape** (fail soft, `Tcl_ResetResult`, `my_snprintf "%.17g %.17g"`, `TCL_VOLATILE`) |
| 3980 | `xschem get graph_axis_drag` |
| **5215-5232** | `xschem graph_axis_zoom` (top level, fails loud) |

### `src/wave_viewer.tcl`

| line | what |
|---|---|
| 828 | `wviewer::switch_ctx` — verifies the switch took |
| 2838 | `wviewer::axis_grabbed` — the fail-closed "ask C" idiom to copy |
| **5361-5362** | the comment claiming Ctrl+wheel is "hard-pinned to CANVAS zoom (callback.c:4417)". **Wrong twice; correct it.** |
| **5372** | `wviewer::graph_at_pointer` — resolves the pointed strip from the C mouse mirror |
| 5394 | `wviewer::graph_range` |
| 5414 | `wviewer::apply_range` |
| **5433** | `wviewer::zoom_about {lo hi a f}` — the shipped anchored scale, `{a-(a-lo)*f, a+(hi-a)*f}` |
| **5454-5508** | `wviewer::wheel_zoom` — **add the trailing `{axis {}}` argument here**; `f` is set at `:5458` (`0.8` / `1/0.8`) |
| **5560-5584** | `wviewer::wheel` — **the `ctrl` arm at ~:5570 gets the one new rung** |
| 5601 | `wviewer::graph_zoom` (View menu, `Z`, `Ctrl-z`) — a `wheel_zoom` caller that must stay untouched |
| 5613 | `wviewer::wheel_bind` |
| **6611-6623** | the wheel binds, including `<Control-Button-4/5>` and `<Control-MouseWheel>` — already bound; **add no bind** |

### `tests/headless/test_wave_axis_zoom.tcl`

| line | helper you will reuse |
|---|---|
| 68 / 77 | `check` / `check_true` |
| 84 / 88 | `pcall` / `pexpr` (never throw) |
| 94 | `az_close` |
| 143 / 150 | `az_reset` / `az_graph` |
| 157 / 167 | `az_band` (world→pixel, `(w + origin)/zoom`) / `az_box` (asks `graph_plotbox_at`) |
| 196 / 204 | `az_xmargin` / `az_ymargin` |
| 215 | `az_count_code` — regexp count over CODE lines only |
| 244 | `az_define` — reads a numeric `#define` out of C source |
| 254 | `az_windows` — every rect's `x1 x2 y1 y2 ypos1 ypos2`, the every-rect witness |
| 267 | `az_coord` — data coord of a pixel via `xschem graph_coord` |
| 955-976 | `ag_press` / `ag_drag` / `ag_rel` / `ag_move` / `ag_key` / `ag_unlatch` / `ag_gesture` |
| ~1767+ | the `AL*` `--logdir` child-process pattern |
| AX group | a real ASE viewer under `$DISPLAY`, with `ax_ev`, `ax_win`, `ax_reset_arms`, `wviewer::history_depth` |

**MEASURED baseline of that suite today (record it, you must beat it):**
`ALL PASS (128 checks)` under `--nogui`, `ALL PASS (196 checks)` under
`$DISPLAY`.

---

## DO — in this order

### 1. Reproduce the two measurements the design rests on

Before writing a line, confirm for yourself, with a throwaway script in your own
`test_scratch` dir:

* **(a)** Ctrl+wheel over an embedded graph today is a **graph X pan of
  0.05·gw**, and `xorigin`/`yorigin`/`zoom` do not move. Fire it as
  `xschem callback .drw 4 <px> <py> 0 4 0 4` (ButtonPress / Button4 /
  state = `ControlMask` = 4). If you cannot reproduce this, **stop and report**:
  the whole "the body is unchanged" contract is built on it.
* **(b)** `xschem get graph_axis_map <gi> y <p0> <p1>` on a **digital** strip
  staged with `y1=0 y2=2.5 ypos1=0 ypos2=4` answers **inside `[0, 2.5]`** — the
  analog window — proving D-29's premise.

### 2. `src/xschem.h`

* Add, immediately after `GRAPH_AXIS_ZOOM_MAX_FACTOR`:

```c
/* Range MULTIPLIER of one CTRL+wheel click in an axis-number margin (issue
 * 0191, doc/claude/specs/waveform_viewer_modes.md §18). Wheel-up multiplies the
 * axis window by this; wheel-down divides by it, so N clicks in followed by N
 * clicks out restore the window EXACTLY -- unlike the shipped Shift+wheel arms
 * (callback.c), whose 0.2-of-the-range step is x0.8 in / x1.2 out and loses 4%
 * per round trip.
 * ⚠ MIRRORED IN TCL: wviewer::wheel_zoom's `f` (src/wave_viewer.tcl) carries the
 * same literal because the viewer's BODY zoom still computes its own window with
 * wviewer::zoom_about. Change BOTH -- tests/headless/test_wave_axis_zoom.tcl CS2
 * reads the two out of source and asserts they are equal. */
#define GRAPH_AXIS_WHEEL_FACTOR 0.8
```

* Add the `graph_axis_wheel_map` prototype to the item-03 block (~2277-2313),
  with a comment saying: the WHEEL formula's one home; `p` is a canvas pixel
  along `axis`; `dir` is `+1` in / `-1` out; the factor lives **inside** so the
  constant has one home and a suite driving the verb drives the product's own
  step; the fixed point is the specification.

### 3. `src/draw.c` — the shared window helper (D-29)

Add, immediately above `graph_axis_map()`:

```c
static void graph_axis_window(Graph_ctx *gr, int axis,
                              double *A, double *B, double *e1, double *e2)
```

It resolves, for an already-`setup_graph_data`'d `gr`:

* `axis == GRAPH_AXIS_X` → `*A = gr->gx1`, `*B = gr->gx2`,
  `*e1 = S_X(gr->gx1)`, `*e2 = S_X(gr->gx2)`;
* `axis == GRAPH_AXIS_Y` **and `gr->digital`** → `*A = gr->ypos1`,
  `*B = gr->ypos2`, `*e1 = DS_Y(gr->ypos1)`, `*e2 = DS_Y(gr->ypos2)`;
* `axis == GRAPH_AXIS_Y` otherwise → `gr->gy1`/`gr->gy2` / `S_Y(...)`.

then normalises **both** pairs (`if(*e1 > *e2) swap;` `if(*A > *B) swap;`) —
`gr->cy` is negative (landmine 3) so the Y pixel pair comes back inverted.

Carry a comment naming: (a) that this is the ONE home for "what is this axis's
window and what pixel extent does it occupy", called by both formulas; (b) that
the digital branch is what makes `graph_axis_zoom`'s `ypos1`/`ypos2` write
correct — MEASURED before this change, `graph_axis_map … y` on a digital strip
answered in the `y1`/`y2` window while the apply wrote `ypos`; (c) the landmine-3
sign note.

**Rewire `graph_axis_map()` onto it**: delete its inline `if(axis == GRAPH_AXIS_X)
{...} else {...}` window block (~5213-5219) and its two normalising swaps, and
call the helper. Everything else in that function — the clamp, the `clicktol`
refusal, the `s > 0` / `s < 0` branches, the `zlo = A - ub * R2;` anchor line —
is unchanged.

Note that `graph_axis_map`'s `G_X`/`G_Y` conversions of `p0`/`p1` must ALSO use
the digital transform when the strip is digital: use `DG_Y` in that case, the
inverse of the `DS_Y` the helper used. Keep the two consistent or the map is
self-inconsistent on digital strips.

### 4. `src/draw.c` — `graph_axis_wheel_map()`

Immediately after `graph_axis_map()`:

```c
int graph_axis_wheel_map(int i, int axis, double p, int dir,
                         double *lo, double *hi)
```

Same preamble as `graph_axis_map`: null/index/`flags & 1` checks, `memset` a
local `Graph_ctx`, `saveflags = xctx->graph_flags & (128 | 256)`,
`setup_graph_data(i, 0, gr)`, restore the two bits (landmines 11 + 37), then the
`gr->scx == 0.0 || gr->scy == 0.0` off-screen sentinel.

Then:

```c
  graph_axis_window(gr, axis, &A, &B, &e1, &e2);
  R = B - A;
  if(R == 0.0 || e2 == e1) return 0;
  if(p < e1) p = e1; if(p > e2) p = e2;          /* D-11, same as the drag map */
  q = (axis == GRAPH_AXIS_X) ? G_X(X_TO_XSCHEM(p))
                             : (gr->digital ? DG_Y(Y_TO_XSCHEM(p))
                                            : G_Y(Y_TO_XSCHEM(p)));
  u = (q - A) / R;
  f = (dir > 0) ? GRAPH_AXIS_WHEEL_FACTOR : 1.0 / GRAPH_AXIS_WHEEL_FACTOR;
  R2 = R * f;
  /* THE ANCHOR, and the only place it is written: q keeps its fraction of the
   * window, therefore its screen pixel. Drop the `- u * R2` term and the new
   * range still has the right WIDTH -- every "the range shrank" assertion
   * passes while the window slid sideways. Landmine 45(a)/47(b); a named local
   * rather than `*lo = ...` so a count_code tripwire can see the line (the
   * idiom skips lines starting with `*`, which is what a comment continuation
   * looks like). */
  zlo = q - u * R2;
  *lo = zlo;
  *hi = zlo + R2;
  if(*hi == *lo) *hi += 1e-6;
  dbg(1, "graph_axis_wheel_map: ...");
  return 1;
```

C89: every one of `A B R e1 e2 q u f R2 zlo` declared at the top of the function.

**No `GRAPH_AXIS_ZOOM_MAX_FACTOR` here** (D-34): there is no division by a
user quantity.

### 5. `src/callback.c` — the arm

* Add `int wheel_axis_done = 0;` to `waves_callback`'s locals (~933-939), with a
  one-line comment: "the Ctrl+wheel axis zoom consumed this event, so the plain
  wheel PAN arms below must stand down — and *only* then, which is what keeps
  Ctrl+wheel over the plot BODY behaving exactly as it does today (a graph X
  pan, MEASURED)."
* Add the new `else if` after the Button3 branch (~1416..), exactly as spelled in
  the decision doc §3.3. Its comment must name:
  - why it is here and not a binding row (`handle_button_press:7483` pre-empts
    `handle_mouse_wheel`, so the `ACTX_OVER_GRAPH` wheel rows are dead);
  - why `!(state & ShiftMask)` (Ctrl+Shift+wheel keeps the shipped Shift zoom);
  - why `!graph_use_ctrl_key` (D-32: in that mode Ctrl *is* the access key);
  - why no `GRAPHPAN` term is owed (`:1687-1688` admits Button1/2/3 only);
  - that `graph_axis_at` is the region oracle and a `NONE` answer means "fall
    through to the pan", which is the whole body contract.
* Add `&& !wheel_axis_done` to the two plain arms at `:1955` and `:1992`.
* Correct the stale comment at `:4804-4806`: the over_graph wheel rows are
  unreachable because of `:7483`, and Ctrl+wheel over a graph is decided in
  `waves_callback`, not in the binding table.

### 6. `src/scheduler.c` — the getter

Add `xschem get graph_axis_wheel_map <gi> x|y <p> in|out` to the `case 'g':`
chain right after `graph_axis_map`. Fail SOFT: `Tcl_ResetResult(interp)` then
answer only on success; `{}` for a short argc, an unknown axis word, an unknown
direction word, a bad index or no transform. Format with
`my_snprintf(res, S(res), "%.17g %.17g", lo, hi)` + `TCL_VOLATILE`, exactly as
`:3968` does.

Comment: this is THE formula seam — the `callback.c` arm and this getter call the
same `graph_axis_wheel_map()`, so a headless suite driving the verb drives the
gesture's own arithmetic, including the anchor. And the **direction word**, not a
factor, is the input, so `GRAPH_AXIS_WHEEL_FACTOR` has exactly one home.

### 7. `src/wave_viewer.tcl` — the viewer

* `proc wviewer::wheel_zoom {token dir gi {px {}} {py {}} {axis {}}}`.
  - `axis {}` — leave the existing body **byte for byte**: X on every strip and Y
    on `gi`, both via `zoom_about`. Every current caller passes nothing.
  - `axis x` — run the same per-strip loop, but for each strip `t` take the new
    window from `xschem get graph_axis_wheel_map $t x $px <in|out>` and write
    only `x1`/`x2`; leave `y1`/`y2` at their frozen read-back values. A strip the
    verb answers `{}` for is left completely unchanged (**never** fall back to
    `zoom_about` — that would be a second formula answering for the same
    gesture).
  - `axis y` — same, for `$gi` only, writing only `y1`/`y2`.
  - Keep the D7 "freeze all four concrete axes first" rule intact in every arm,
    and keep the single `set_graphs` + `regenerate` at the end.
  - `switch_ctx` before any `xschem get` (the verb answers for the current ctx).
  - Comment: why the axis arms take their window from C (one formula, D-25/D-28)
    while the body arm keeps `zoom_about` (out of scope to change shipped
    behaviour), and that `CS3` asserts the two agree numerically.
* `wviewer::wheel`'s `ctrl` arm gets exactly one rung:

```tcl
    ctrl {
      # issue 0191: in a strip's AXIS-NUMBER margin, Ctrl+wheel zooms THAT AXIS
      # ONLY, anchored at the pointer. C owns the geometry — the viewer
      # hit-tests nothing (D-22/D-38), and a stale mouse mirror can only make
      # this answer {} and degrade to the shipped both-axes zoom, never pick the
      # wrong strip.
      set ax {}
      if {[wviewer::switch_ctx $token]} {
        catch {set ax [xschem get graph_axis_at $gi $px $py]}
      }
      if {$ax ne {x} && $ax ne {y}} { set ax {} }
      wviewer::wheel_zoom $token $dir $gi $px $py $ax
      return
    }
```

* Correct the stale comment at `:5361-5362` (Ctrl+wheel over a graph is neither
  the canvas nor a zoom; it is a graph pan, MEASURED, and `callback.c:4417` no
  longer exists).
* **Add no bind.** `<Control-Button-4/5>` and `<Control-MouseWheel>` are already
  bound at `:6617-6618` / `:6624`.

### 8. `tests/headless/test_wave_axis_zoom.tcl` — five new groups

Extend the existing file. Keep the shipped footer **exactly**
(`RESULT: ALL PASS ($npass checks)` + `exit 0/1`) — `run_suites.sh` classifies on
the literal string `ALL PASS`. Read `GRAPH_AXIS_WHEEL_FACTOR` with `az_define`,
never a frozen copy. Every "far/empty" pixel is scanned with
`az_box`/`az_xmargin`/`az_ymargin` and **re-scanned after any leg that zooms**.

**`CW*` — the wheel map and its verb. BOTH arms.**

| id | asserts |
|---|---|
| CW0 | the verb exists and fails SOFT: bad index → `{}`; non-graph rect (`az_graph … {}`) → `{}`; unknown axis word → `{}`; unknown direction word → `{}`; short argc → `{}`. Never a Tcl error. |
| CW1 | for an X-margin pixel `p`: both endpoints equal the closed form computed in Tcl from `A`/`B` read off the rect and `q = [az_coord 0 $p $cy 0]` (`graph_coord` is an INDEPENDENT pixel→data transform) |
| CW2 | `hi-lo == (B-A)*K` on `in` and `== (B-A)/K` on `out`, `K` from `az_define`. **This leg must SURVIVE SAB-1** — that is why it is separate from CW3 |
| **CW3** | **THE FIXED POINT.** After `xschem graph_axis_zoom 0 x $lo $hi`, `[az_coord 0 $p $cy 0]` equals its pre-zoom value to 1e-9 relative. SAB-1 kills this |
| CW4 | the same pair for Y in the left margin |
| CW5 | round trip: `in` then `out` at the same pixel restores `x1`/`x2` to 1e-12 relative — the payoff of the reversible factor (D-27) |
| CW6 | X zoom leaves **every** rect's `y1 y2 ypos1 ypos2` byte-identical (`az_windows`); Y zoom leaves **every** rect's `x1 x2` byte-identical. SAB-2 kills this |
| CW7 | X propagates to the participating rect 1; Y does not (witness both rects) |
| CW8 | pointer at the plot-box edge: `p = e1 ⇒ lo == A`; `p = e2 ⇒ hi == B` |
| CW9 | a pixel outside the plot extent is CLAMPED and still commits (D-11), it does not answer `{}` |

**`CD*` — the digital window. BOTH arms.** Stage the digital strip with **disjoint**
ranges (`y1=0 y2=2.5`, `ypos1=10 ypos2=14`) so the two spaces cannot be confused.

| id | asserts |
|---|---|
| CD1 | `graph_axis_wheel_map <gi> y <p> in` answers inside `[10,14]` and outside `[0,2.5]`. SAB-4 kills this |
| CD2 | `graph_axis_map <gi> y <p0> <p1>` (item 03's DRAG map, now on the shared helper) answers in the same band — the leg that makes §17.3's D-19 true |
| CD3 | the fixed point on the digital strip, using an INDEPENDENT Tcl transform derived from the scanned plot box and `ypos1`/`ypos2` (`graph_coord` uses the analog `G_Y` and is the wrong oracle here — say so in the leg's comment) |
| CD4 | applying it writes `ypos1`/`ypos2` and leaves `y1`/`y2` byte-identical |

**`CS*` — source-level one-home tripwires. BOTH arms** (except CS3, see below).

| id | asserts |
|---|---|
| CS1 | `az_count_code src/draw.c {q - u \* R2}` == 1; `az_count_code src/callback.c {graph_axis_wheel_map\(}` == 1; `az_count_code src/scheduler.c {graph_axis_wheel_map\(}` == 1 |
| **CS2** | `az_define src/xschem.h GRAPH_AXIS_WHEEL_FACTOR` equals the `0.8` literal parsed out of `wviewer::wheel_zoom` in `src/wave_viewer.tcl` — the MIRRORED-IN-TCL leg. SAB-5 kills this |
| CS3 | numeric equivalence: `wviewer::zoom_about $A $B $q $f` == `xschem get graph_axis_wheel_map 0 x $p in` for the same strip and pixel. Run it where `wviewer::zoom_about` is defined (the DISPLAY arm, with the viewer open) and **assert that it IS defined** — never a silent skip |
| CS4 | `az_count_code src/draw.c {graph_axis_window\(}` == 3 (one definition + two calls) and the digital/`ypos` decision appears exactly once. SAB-4 kills this |

**`CE*` — the real C gesture on an embedded schematic graph. DISPLAY only.**
Use `xschem callback .drw 4 <px> <py> 0 4 0 4` / `… 5 … 0 4 0 4` (Button4/5,
state = `ControlMask` = 4). Deliver a `Motion` first (`ag_move`) and `ag_unlatch`
between legs.

| id | asserts |
|---|---|
| CE1 | Ctrl+wheel-up in the X margin narrows `x1`/`x2` by exactly `K` |
| CE1b | …and does **not** also pan: the window's centre moved only by what the anchor demands, i.e. the result equals `xschem get graph_axis_wheel_map` exactly. SAB-7 kills this |
| **CE2** | the pointer's data x is at the same pixel after (`graph_coord` before/after). SAB-1 kills this |
| CE3 | Ctrl+wheel in the Y margin moves `y1`/`y2` on the pointed rect only and leaves **every** rect's `x1`/`x2` byte-identical. SAB-2 kills this |
| CE4 | wheel-down is the inverse; in-then-out restores the window |
| **CE5** | **Ctrl+wheel in the plot BODY is UNCHANGED** — still a graph X pan of exactly `0.05 * (x2-x1)`, not a zoom, and `xorigin`/`yorigin`/`zoom` do not move. SAB-3 kills this |
| CE6 | plain wheel in the X margin still pans X by `0.05*gw`; plain wheel in the Y margin still pans Y (regression witnesses, D-31) |
| CE7 | Shift+wheel in the X margin still zooms X by ×0.8 in / **×1.2** out — the shipped arm, deliberately NOT the new factor |
| CE8 | the gesture leaves `xschem get modified` at 0 (D-35) |
| CE9 | in a `--logdir` CHILD (the `AL*` pattern): the gesture self-logged exactly one `xschem graph_axis_zoom <gi> x <lo> <hi>` line, and replaying that line in a second child reproduces the window |
| CE10 | the same gesture on a NON-ZERO strip index acts on THAT strip (the `AG13` lesson: the Y half is decisive because Y never propagates) |
| CE11 | with `graph_use_ctrl_key 1`, Ctrl+wheel in the X margin **pans** and does not zoom (D-32) — and restore the variable afterwards |

**`CV*` — the ASE viewer seam. DISPLAY only.** Reuse the `AX*` staging
(`ax_ev`, `ax_win`, `ax_reset_arms`, `wviewer::history_depth`). Deliver
`<Motion>` before each wheel so `graph_at_pointer` is not stale (D-38), and
`-state 4` on the `<Button-4>`/`<Button-5>` events.

| id | asserts |
|---|---|
| CV1 | Ctrl+wheel in a strip's X margin zooms X on **every** strip and leaves **every** strip's `y1`/`y2` unchanged |
| **CV2** | Ctrl+wheel in the Y margin zooms Y on the pointed strip only and leaves **every** strip's `x1`/`x2` unchanged. SAB-6 kills this |
| CV3 | Ctrl+wheel in the plot BODY is UNCHANGED: X on every strip **and** Y on the pointed strip |
| CV4 | it went into the **MODEL**, not just the rect: force a `wviewer::regenerate` and read the range back — it survives (D-36) |
| CV5 | `wviewer::history_depth` did not move (D-35, the `AX8` idiom) |
| CV6 | the fixed point holds in the viewer (data coord under the pointer unchanged). SAB-1 kills this |

Also add one **staging leg with teeth** per group, in the `AC1` style: if the
pixel scan or the `az_define` read came up empty, that must FAIL loudly, never
silently compare against `{}`.

### 9. Build and run

```sh
cd /home/qflow/dev/xschem/claude_1/xschem/src && make
```

Then, with `GUI_GATE=0` in the environment:

```sh
GUI_GATE=0 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_axis_zoom.tcl
GUI_GATE=0 ./src/xschem         --pipe -q --nolog --script tests/headless/test_wave_axis_zoom.tcl
GUI_GATE=0 bash tests/headless/full_audit.sh
```

**Gates.**

* `test_wave_axis_zoom.tcl` must be `ALL PASS` in both arms, with the check count
  **risen from 128 / 196** by exactly the number of legs you added.
* `full_audit.sh` must match the PLAN.md PREFLIGHT baseline:
  `SUMMARY: 239 pass  20 fail  1 crash/timeout  11 skip  (total 271)`,
  `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`, and the 20 fails must be exactly
  the 21-line list in PLAN.md (20 FAIL + `TIMEOUT test_key_graph_context`).
  **Any fail not on that list is yours until proven otherwise.**
* `test_graph_context` and `test_key_graph_context` are **already red / already
  timing out at baseline**, and their failing legs are wheel-and-key-over-graph
  routing — i.e. your turf. Read their failures before and after your change.
  They are **not yours**, but if your change makes either greener, say so in the
  receipt; do not chase it.
* Known-flaky and NOT yours: `test_cadence_drag` (12/12 red on pristine),
  `test_wave_trace_menu` TG9 (4-in-10 under WSLg), `test_ase_plot` P4/P6/P8 (1-2
  in 10). **The check COUNT is the signal, not the verdict** — `test_ase_plot`
  prints `ALL PASS` at 30 checks when WSLg geometry fails and it skips P1-P7 (145
  = a real run); `test_wave_clear_all` is 68 real vs 58 skipped. A whole-suite
  wipeout with `NORESULT`/connection errors is a WSLg Xwayland abort killing
  every X client — re-run before attributing it to your change.

### 10. Sabotage-verify

Run every row of the table in the decision doc §7 (SAB-1 … SAB-7). For each:
apply it, run the suite, confirm it fails **exactly** its named target check and
nothing else, `git diff` the file to confirm it holds nothing but the sabotage,
`git checkout -- <file>`, and re-run clean. Record each result.

**SAB-1 is the one that matters most**: it must kill CW3/CE2/CV6 and must
**leave CW2 green**. If SAB-1 also kills CW2, your width leg is accidentally
testing the anchor and you have lost the distinction the whole suite is built on.

### 11. Docs

* **`doc/claude/specs/waveform_viewer_modes.md`** — new **§18 "Axis-region
  Ctrl+wheel zoom (2026-08-01, issue 0191)"**, mirroring §17's shape:
  §18.1 the gesture table (where, refusals, the `graph_use_ctrl_key` gate, what
  the body/plain/Shift keep doing — with the MEASURED table), §18.2 the maths and
  the fixed-point invariant with the two worked checks, §18.3 where it applies
  (X propagates, Y does not), §18.4 no dirty flag / no C undo / no viewer undo /
  one log line **on the engine path only** and why the viewer path logs nothing,
  §18.5 the surface (the new function, the new getter, the viewer's two edits),
  §18.6 the tests. Add three rows to **§15.1**'s ownership table (Ctrl+wheel in
  the bottom margin, in the left margin, in the body) and a cross-reference from
  §17. Also correct §17.3's D-19 sentence and §17.6's stale check counts.
* **`doc/claude/code_analysis/waveform_subsystem_reference.md`** — a new
  **landmine 48**: *"A wheel event over a graph never reaches the binding table"*
  — `handle_button_press`'s inline `waves_selected` guard (`:7483`) pre-empts
  `handle_mouse_wheel` (`:7541`), so the `ACTX_OVER_GRAPH` wheel rows are
  unreachable, a modifier's over-graph wheel behaviour is decided **inside
  `waves_callback`**, and three comments in the tree said otherwise. Include the
  MEASURED chord × region table. Add a clause to **landmine 47** recording that
  the axis WINDOW resolution now has one home (`graph_axis_window`) and that its
  digital branch corrects a shipped mismatch. Update §5 (the interaction
  section's `waves_callback` paragraph), §9 (the verb list gains
  `graph_axis_wheel_map`), and §10's "New graph GESTURE IN A MARGIN" recipe with
  the wheel variant.
* **`doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md`** — an issue file in
  the house style of `0190-axis-region-drag-zoom.md`: symptom, what was measured,
  the decision list pointer, the fix, the tests, and the eyeball list.
* **`doc/claude/issues/0190-axis-region-drag-zoom.md`** — add one short block
  recording that its D-19 digital branch was documented but never implemented,
  what was measured, and that 0191's shared `graph_axis_window()` corrects it.

### 12. Receipt

Write `doc/claude/overnight_batch_2026_08_01/receipts/04_axis-region-ctrl-wheel-zoom.md`
in the shape of `03_axis-region-drag-zoom.md`: commit sha, files changed, test
counts before/after in both arms, every non-baseline audit fail with its
attribution, docs updated, the decision list copied from the decision doc §5
(the user reads these), the sabotage results, and the eyeball list from decision
doc §11.

---

## COMMIT

Stage **exactly** this list — nothing else, no `git add -A`, no `git commit -a`:

```
src/xschem.h
src/draw.c
src/callback.c
src/scheduler.c
src/wave_viewer.tcl
tests/headless/test_wave_axis_zoom.tcl
doc/claude/specs/waveform_viewer_modes.md
doc/claude/code_analysis/waveform_subsystem_reference.md
doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md
doc/claude/overnight_batch_2026_08_01/prompts/04_axis-region-ctrl-wheel-zoom.md
doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md
doc/claude/issues/0190-axis-region-drag-zoom.md
```

(The receipt is committed by the batch's final ledger commit, not by this one.)

Before committing, `git status` must show only these files plus the two
pre-existing dirty tracked files from the PLAN.md PREFLIGHT
(`doc/claude/suggestions/next_session_prompt_0165.md` and
`sky130A/.../tb_bandgap.state`) and the pre-existing untracked paths.

Commit message:

```
feat(0191): CTRL+wheel in an axis-number margin zooms that axis about the pointer

The margins item 0190 gave to the LMB drag now also take a CTRL+wheel, and it
zooms THAT AXIS ONLY: the bottom (X-number) margin scales x1/x2 on every
participating strip, the left (Y-number) margin scales y1/y2 -- ypos1/ypos2 on a
digital strip -- on that strip alone. The data coordinate under the pointer keeps
its screen pixel, which is the whole specification: lo = q - u*R2 is the anchor,
and dropping it leaves a window of the right width in the wrong place, which no
"the range shrank" assertion can see.

Three things source made non-obvious and that the suite now pins:

  * a wheel over a graph NEVER reaches the binding table -- handle_button_press's
    inline waves_selected guard pre-empts handle_mouse_wheel, so the
    ACTX_OVER_GRAPH wheel rows are dead code and the arm has to live in
    waves_callback. Measured: CTRL+wheel over a strip is today a graph X PAN,
    identical to a plain wheel, not the canvas pan three comments claimed;
  * the step is x0.8 in / x1/0.8 out, one #define mirrored in wave_viewer.tcl, so
    N clicks in and N back out restore the window exactly. The shipped Shift+wheel
    arms are x0.8 / x1.2 and lose 4% per round trip;
  * both formulas now take the axis window from one graph_axis_window() helper,
    whose digital branch makes 0190's own D-19 true for the first time: the drag
    map computed a digital strip's Y in the y1/y2 window while the apply wrote
    ypos1/ypos2.

No dirty flag, no C undo, no viewer undo point: a zoom is view state. The engine
path self-logs one replayable graph_axis_zoom line; the ASE viewer path writes its
Tcl model, so it survives a resize like its body zoom does.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## CONSTRAINTS

* **Do not touch `graph_axis_at()` or `graph_axis_zoom()`.** They are item 03's
  and they are correct; reuse them.
* **Do not change the shipped Shift+wheel arms** (`callback.c:2029`, `:2069`) or
  the plain-wheel pan arithmetic. The only edit to the plain arms is the
  `&& !wheel_axis_done` guard.
* **Do not change `wviewer::wheel_zoom`'s default behaviour.** The new `axis`
  argument defaults to `{}` and every existing caller must keep passing nothing.
* **Do not add a Tcl hit test for the axis margins.** The viewer asks C. That is
  item 03's D-22 and it is not reopened.
* **Do not add a viewer undo point, a `set_modify`, a `push_undo`, a
  `capture_live_graph_state` call or a `with_edit` bracket.** All four are
  decided (D-35) and all four would be wrong.
* **Do not delete the unreachable `ACTX_OVER_GRAPH` wheel binding rows.** Fix
  their comment only; removing them has its own regression surface
  (`xschem bind`, `keybindings.csv`).
* **Do not touch `callback.c:1714`'s `|| xctx->graph_axis_drag` GRAPHPAN term.**
  It is item 03's, a wheel never latches, and it is out of scope.
* **Do not fix anything else you notice.** Record it in the receipt.
* If a claim in the ANCHORS table cannot be reproduced from source, that is a
  **finding to report**, not a blocker — say so and proceed from what source
  actually shows.
