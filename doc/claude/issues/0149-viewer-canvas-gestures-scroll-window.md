# 0149 — Viewer: MMB drag and Alt/plain arrows scrolled the CANVAS, sliding the graphs around

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** ASE waveform viewer input strip (`src/wave_viewer.tcl` `key_filter` /
`strip_bindings` + new `arrow_pan`). Pure Tcl — **no C touched**.
**Reported by:** user, 2026-07-25 — "MMB press-drag is moving the graph elements
around as if one is within a schematic … ALT+Arrow_keys are also doing a scroll
which moves all the graph elements as if they are components in a bigger canvas.
Once some space opens up, it is possible to click in an empty space, and then the
arrow-keys by themselves do additional panning/scrolling. … the graph elements
intended to display traces OWN the window."
**Test:** `tests/headless/test_wave_viewer.tcl` — the CG legs (266 checks total).

## Symptom

Leftovers from the viewer being a real schematic window with graph rects in it
(item 11). Item 18 made the graphs tile the viewport and item 19 moved wheel /
RMB / `f` / `Z` / View-zoom onto the graph, but two canvas **view** gestures were
still reachable, and a view scroll is not readonly-blocked (readonly only refuses
object mutation), so the whole tiled stack slid inside a larger canvas and blank
space appeared around it:

1. **Middle button.** `waves_selected` (`src/callback.c:88-92`) *explicitly*
   skips Button-2 press / release / Button2Mask-motion so the schematic pan can
   work over a graph. So MMB never reaches the graph engine: it hits
   `handle_button_press` → `start_pan_logged()` and the drag moves
   `xorigin`/`yorigin`. Ctrl+MMB is worse — it is the `edit.cycle_pin_type`
   chord, a mutating action, i.e. a readonly modal.
2. **Arrow keys**, in three different ways:
   - bare arrow **off** a graph → the data-driven binding resolves `ACTX_CANVAS`
     → `view.scroll_up/down/left/right` (the "click empty space, then arrows
     scroll" report);
   - **any modifier** → `SET_MODMASK` makes `waves_selected` skip, so
     Alt/Shift+arrow fall into the hard-coded `xctx->xorigin += …` pan in
     `callback.c` `case XK_Left … XK_Up` (the reported Alt+arrow scroll);
   - **Ctrl+Left/Right** → `prev_tab` / `next_tab`.

Actually *moving* a graph rect like a schematic object was already impossible:
the intuitive/cadence drag-move is gated on `!xctx->readonly`
(`callback.c` ~6980) and the viewer holds readonly for the window's life. What
the user saw was the canvas moving under the graphs, not the graphs moving.

## Fix (both in `src/wave_viewer.tcl`)

- **`wviewer::arrow_pan {token wp N s}`** — arrows are intercepted in
  `key_filter` and **never forwarded**. Bare Left/Right = the horizontal graph
  pan, bare Up/Down = the vertical graph pan (both `wviewer::wheel`, ±5 % of the
  span, so arrows and wheel share one implementation). Any of
  Shift(1)/Ctrl(4)/Mod1(8) is swallowed — those chords have no graph meaning and
  every one of them was a canvas gesture.
  This deliberately **replaces item 19's "arrows still forward"** contract, whose
  Up/Down was an X zoom: zoom already has four affordances (Ctrl+wheel, View
  menu, `Z`, `Ctrl-z`, all → `wheel_zoom` since 0145), and an arrow key means
  pan.
- **`strip_bindings`** additionally swallows the canvas-only mouse gestures on
  the viewer canvas (per-widget, so no other window is affected):
  `<ButtonPress-2> <ButtonRelease-2> <B2-Motion>` (canvas pan + the Ctrl+MMB
  edit chord) and `<Shift-ButtonPress-1> <Shift-ButtonRelease-1> <Shift-B1-Motion>`
  / the `<Alt-…>` triple (rubber-band/copy-drag and unselect-at-pointer — both
  are canvas-only by the same `waves_selected` skips). Plain Button-1 still
  reaches the C engine (cursor drag / graph pan); the bands tile the whole
  viewport, so a plain click always lands on a graph.

**Landmine hit while writing this:** a `switch` body is a pattern/body **word
list**, not a script — the `;# Left = view left` comments first written after
each body silently shifted every later pair, so Right and Down fell through to
`default`. The tests caught it; the comment now lives above the switch.

## Tests (CG legs, `test_wave_viewer.tcl`, in the IX block before IX-fit)

Driven through the production `wviewer::key_filter` / real Tk `event generate`,
each re-asserting the IX canvas baseline (`xorigin`/`yorigin`/`zoom`):

- `CG-arrow-right/left` — graph x1+x2 shift by one signed delta, y untouched;
- `CG-arrow-up/down` — graph y1+y2 shift by one signed delta, x untouched;
- `CG-arrow-shift/ctrl/alt` — all four arrows change **nothing** (graph or canvas);
- `CG-binds` — the nine swallowed sequences are bound to `break`;
- `CG-mmb` — a synthetic MMB press → Button2Mask motion → release leaves the
  canvas at the baseline;
- `CG-shift-b1` — the Shift-drag / Alt-click gestures are inert.

Sabotage-verified: removing the swallow binds turns `CG-mmb` red (the canvas
really pans); restoring the arrow forward turns every `CG-arrow-*` red, including
`CG-arrow-alt canvas == baseline` — the user's exact Alt+arrow bug. A selection
witness for `CG-shift-b1` was measured to be **hollow** (neither a shift
rubber-band nor a shift-click inside the full-window graph rect selects it) and
was dropped rather than left in as a green-but-hollow check.

## Known remaining (not holes, recorded)

- A graph rect can still be *selected* (dashed outline) by a plain click within
  the 5 px `border` inset `waves_selected` uses at the band edges — cosmetic
  only; the drag-move is readonly-gated, so it cannot be moved or deleted.
- With **zero** graphs the canvas has no bands, so a Button-3 drag is a canvas
  zoom box; invisible (nothing is drawn) and the next `regenerate` re-tiles the
  current viewport.
- Future: "moving" a graph will mean **swapping strip positions**, not a
  schematic move (user, same report).
