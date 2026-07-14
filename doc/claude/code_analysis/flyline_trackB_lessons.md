# Track B (fly-line render) — lessons

Status: 2026-07-13. What surprised us building the on-screen fly-line overlay
(`draw_flylines()`), for the next person touching hover overlays or GUI gesture tests.

## 1. GUI gesture tests run under `--pipe`, NOT `-x`

`./src/xschem -x --script foo.tcl` gives a **Tcl-only** interp: `event`, `winfo`, and
`package present Tk` are all absent, so `event generate` fails with `invalid command name
"event"`. The invocation that yields a real Tk interp with a viewable `.drw` (so
`event generate .drw <Motion>` fires the shipping binding) is:

```
DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_foo.tcl
```

This matches every existing render test (`test_dblclick_connected_grow.tcl`,
`test_connected_drag_*`, `test_select_at.tcl`). Guard with
`if {[catch {winfo viewable $WIN} vv] || !$vv} { ...SKIP... }` and derive `$WIN` from
`xschem get current_win_path` (falls back to `.drw`).

## 2. Build fixtures INLINE; `xschem load` reroutes under the GUI

Under the interactive GUI, `xschem load <file>` opens the file in a **new window**
(the load-window-routing behavior) — in a `--script` run it hangs the script (the child
window's event loop never returns to source the rest). So render tests must build fixtures with
primitive commands (`xschem clear force`, `xschem wire ...`, `xschem instance lab_pin.sym x y r f
{name=.. lab=..}`), exactly as the connected-drag/dblclick tests do. `xschem load` is fine only in
`--nogui` logic tests.

## 3. Cache invalidation: net-name change-detection is not enough

`draw_flylines()` skips recompute when the hovered net name is unchanged (same-net motion → O(1)).
But an **edit** can restructure a net while keeping its name (e.g. dropping a wire between two
same-name labels merges two clusters into one). Keying only on the name left a **stale star**. Fix:
capture `xctx->prep_hi_structs` *before* `prepare_netlist_structs(0)`; if it was clear, an edit
invalidated the connectivity → force a recompute. This is the §5.4 "invalidate when the prep epoch
clears" rule, and it is easy to forget because the name looks unchanged. (Caught by the wired-pair
render rail: rebuild a fixture with the same net name and the old star must not persist.)

## 4. What the render rails can and cannot prove

`xschem flylines shown` exposes the overlay **state machine** (which net's star is tracked). The
render rails assert on it: hover A→B updates it, empty/`<Leave>`/feature-off clear it, `zoom_full`
preserves it. That is genuinely sabotage-catchable (neutering the transition path reds 7 rails).

But `shown` is **independent of the pixels** — it does not observe the regional-`draw()` erase or
the `flyline_restamp()` re-stroke. Breaking the erase or the re-stamp leaves `shown` correct while
the picture is wrong. Those two are **visual-only** in v1 (headless has no framebuffer to read).
Verify them by eye; don't mistake a green render suite for "the star erases/redraws cleanly."

## 5. Overlay erase ordering

The erase (`flyline_erase_region`) repaints the old bbox via a regional `draw()`, which re-runs the
`draw()` re-stamp block — including `flyline_restamp()`. So you MUST clear `fly_nseg`/`fly_shown_net`
**before** calling the erase-`draw()`, or the re-stamp immediately redraws the very star you are
erasing. `flyline_clear()` enforces this order. Same trap as `draw_hover`'s gctiled erase.
