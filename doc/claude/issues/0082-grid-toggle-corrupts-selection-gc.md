# Issue 0082 — Toggling the grid off (CTRL-G) corrupts the shared GRIDLAYER/SELLAYER GC → grey selection overlay renders dashed/broken

**Opened:** 2026-07-07
**Status:** FIXED (2026-07-07) — `drawgrid()` now runs the `draw_grid` early-out BEFORE
the axes line-attribute mutation, so a grid-OFF redraw never leaves the shared GC dashed;
see **§4 Resolution**. RED→GREEN verified; regression
`tests/headless/test_grid_toggle_sel_gc.tcl` added.
**Severity:** MEDIUM — visual corruption of a core interaction cue (selection highlight);
no crash / data loss, but the selection grey (and any GRIDLAYER-colored geometry drawn
after the grid pass) renders with a dashed line style until the next grid-ON redraw.
**Class:** shared-GC state leak — a mutation on a GC that is aliased across two logical
layers escapes an early-return path without being reset.
**Branch:** `fluid-editing`.
**Affects:** `drawgrid()` in `src/draw.c` (the Xlib path, `DRAW_ALL_CAIRO==0`).
**Repro build/run:** `src/xschem --script src/cadence_style_rc --logdir /tmp`
(CTRL-G is bound to `view.toggle_draw_grid` in `src/cadence_style_rc`).

---

## 1. Problem

Select one or more objects (they get the grey selection overlay), then press **CTRL-G** to
turn the grid **off**. The grey highlight comes back dashed / broken instead of solid.

CTRL-G is the registered action `view.toggle_draw_grid` (`src/callback.c`), whose body is:

```tcl
set draw_grid [expr {!$draw_grid}]; xschem redraw
```

`xschem redraw` runs the full `draw()` (`src/scheduler.c` → `draw.c`), which paints the
selection overlay last via `draw_selection(xctx->gc[SELLAYER], 0)` (`draw.c:6131`).

The root cause is a **shared GC**:

```c
/* src/xschem.h */
#define GRIDLAYER 2
#define SELLAYER  2      /* SAME GC object: xctx->gc[2] */
```

`draw_selection()` → `drawtemprect()` draws the overlay rectangles with `xctx->gc[SELLAYER]`
**as-is** (no line-attribute set of its own — `draw.c:2611`). So whatever line style that GC
carries is what the selection is stroked with.

`drawgrid()` (`src/draw.c:1123`) mutated that GC to a **dashed** style for the axis lines
*before* the `draw_grid` early-out:

```c
  if(axes) {                                   /* draw_grid_axes, default 1 */
    dash_arr[0] = dash_arr[1] = (char) 3;
    XSetDashes(display, xctx->gc[GRIDLAYER], 0, dash_arr, 1);
    XSetLineAttributes(display, xctx->gc[GRIDLAYER], 0, xDashType /* LineOnOffDash */, ...);
  }
  ...
  if( !tclgetboolvar("draw_grid") || !has_x) return;   /* <-- early-out AFTER the mutation */
  ...
  /* solid reset lives at the very end (draw.c:1301) — only reached on the grid-ON path */
  XSetLineAttributes(display, xctx->gc[GRIDLAYER], XLINEWIDTH(xctx->lw), LineSolid, ...);
```

On a **grid-OFF** redraw with `draw_grid_axes` on (both default `1`), the axes block sets the
shared GC dashed, then the function returns at the early-out — so the trailing solid reset
never runs. `draw_selection()` then strokes the grey overlay with the dashed GC. The axis
lines it set up for are never even drawn (their `XDrawLine`s are all *after* the early-out),
so the mutation is pure corruption plus dead work.

## 2. Why it manifests exactly on the toggle

- Grid **ON** redraw: `drawgrid()` runs fully and ends with the solid reset (`draw.c:1301`),
  so the shared GC is solid by the time `draw_selection()` runs → highlight solid. ✓
- Grid **OFF** redraw (axes on): axes block sets dashed → early-out → no reset → highlight
  dashed. ✗
- Grid **OFF** with `draw_grid_axes` also off: axes block is skipped, GC untouched → no
  corruption (so the bug requires the default `draw_grid_axes=1`).

For a plain selection (no dashed/`NOW` GRIDLAYER geometry between the grid pass and
`draw_selection()`), nothing re-sets the GC in between, so the dashed state reaches the
overlay deterministically.

## 3. Impact

Cosmetic but user-facing: the primary "these objects are selected" cue degrades on a routine
CTRL-G. Also affects any GRIDLAYER-colored content batched after `drawgrid()` in the same
`draw()` (e.g. `skip_wire` wires drawn via the ADD batch path, which don't set their own line
attributes). Self-heals on the next grid-ON redraw.

## 4. Resolution (FIXED)

Move the `draw_grid`/`has_x` early-out **above** the axes line-attribute mutation, so a
grid-OFF redraw returns before ever touching the shared GC. The axis lines the mutation was
for are drawn only on the grid-ON path (all after the guard), so nothing is lost; grid-ON
behavior is byte-identical. This also removes the dead "set attributes then immediately
return" work. The `#if DRAW_ALL_CAIRO==0` guard is preserved so the cairo build is unchanged,
and the early-out stays outside the `#if` so it still guards the cairo path.

```c
  psize_ptr = tclgetvar("grid_point_size");
  if(psize_ptr[0]) grid_point_size = atoi(psize_ptr);
  #endif
  dbg(1, "drawgrid(): draw grid\n");
  if( !tclgetboolvar("draw_grid") || !has_x) return;   /* guard FIRST */
  #if DRAW_ALL_CAIRO==0
  if(axes) {                                            /* mutate shared GC only when we will draw */
    dash_arr[0] = dash_arr[1] = (char) 3;
    XSetDashes(display, xctx->gc[GRIDLAYER], 0, dash_arr, 1);
    ...
  }
  #endif
```

**Test seam.** `draw_selection()` consumes the GC line style but there is no pixel readback
headless. Added a minimal introspection getter mirroring `xschem get drawcount`:

```
xschem get gc_line_style [<layer>]   ;# cached X line_style of gc[layer] (default SELLAYER)
                                     ;# 0=LineSolid, 1=LineOnOffDash, 2=LineDoubleDash, -1=n/a
```

Backed by `XGetGCValues(display, xctx->gc[layer], GCLineStyle, ...)` (`src/scheduler.c`,
`get` dispatch under `case 'g'`).

Verified RED→GREEN: before the `drawgrid()` reorder, after `set draw_grid 0` + `xschem redraw`
with a selected rect, `xschem get gc_line_style` returned `1` (dashed); after the reorder it
returns `0` (solid). Regression `tests/headless/test_grid_toggle_sel_gc.tcl` asserts the GC
stays solid across the grid toggle (grid-ON baseline, grid-OFF with axes, grid-OFF without
axes, grid re-ON).

Two gotchas the test encodes:
- It drives the grid with plain Tcl `set draw_grid 0` (exactly what the `view.toggle_draw_grid`
  action does) — NOT `xschem set draw_grid 0`. `draw_grid` is a pure Tcl global; `xschem set`
  does not touch it, so an early draft was a false-green (the grid never actually toggled).
- It selects a RECT, not a WIRE: the wire overlay (`drawtemp_manhattanline` → `drawtempline`)
  re-sets the GC to `LineSolid` itself and would mask the corruption; `drawtemprect` uses the
  GC verbatim. Crosshair is also disabled (`crosshair_layer` default == 2 == the same GC).

**Not in the `--nogui` `run_regression.tcl` hcases:** the test needs a real X connection
(GCs only exist when `has_x`), and the `--nogui` harness has none — under it the seam returns
`-1` and the test self-SKIPs. It is an X-required manual/CI-under-X case, run like the sibling
`tests/headless/test_altf5_ciw.tcl`:
`DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_grid_toggle_sel_gc.tcl`.

## 5. Related
- `src/xschem.h` — `GRIDLAYER == SELLAYER == 2` (the aliasing this bug turns on).
- `src/draw.c:2611` `drawtemprect()` — the overlay renderer that uses the GC verbatim.
- `src/cadence_style_rc` — CTRL-G → `view.toggle_draw_grid`.
