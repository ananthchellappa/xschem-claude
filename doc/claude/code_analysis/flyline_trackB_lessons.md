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

## 6. Hub-at-cursor (star origin follows the pointer) — testing notes

The follow-up that moves the star ORIGIN to the cursor point on the hovered object
(`flyline_hub_point()`, `suggestions/flyline_hub_at_cursor_plan.md`, H0–H2) was fully headless-
and render-testable:

- **`at X Y` IS the mouse.** The whole origin math (wire clamp-projection, pin/label pin-coord,
  end clamp) is `--nogui`-testable through `xschem flylines at <x> <y>`: the `(x,y)` is the pointer,
  so `segments` originate at the projected hub. No GUI needed for H0.
- **Headless `at` picking is threshold-limited.** `find_closest_wire` uses `dist()` (which returns
  the *squared* distance) against `CADWIREMINDIST² · zoom² · scaling²`. In `--nogui` zoom stays
  `CADINITIALZOOM=1` (no full-zoom without a canvas), so the threshold is `144` → the `at` point must
  be within **12 world units perpendicular** of the wire or the wire is not picked. Keep hover
  fixtures close to the wire and clear of the naming label's bbox. (A wire's own `{lab=CLK}` does
  *not* name it in isolation — a label/pin must physically touch it, which puts a pin in its cluster
  so its anchor becomes the pin, not the midpoint.)
- **The drawn origin needed its own probe.** `flylines shown` is origin-blind (§4). Added
  `xschem flylines origin` (returns `fly_seg[0..1]`) so the render rails can assert the *drawn* origin
  tracks the cursor — both on net change (H1) and on same-net slide (H2). Without it the H2 cheap
  path is green-but-hollow (nothing observes `fly_seg`).
- **H2 same-net slide is the sabotage-critical rail.** Hover a wire at x=60 then x=150 with **no
  empty hover between** (same net): only the cheap-path slide moves the origin; a plain same-net
  short-circuit freezes it at 60. That two-hover sequence is the discriminator — neutering
  `flyline_move_origin()` reds exactly it and nothing else.
- **Key the cheap path on the hub CLUSTER, not the hub OBJECT.** A first cut cached the hub
  object (`fly_hub_type/n/col`); an adversarial perf review flagged that crossing between two
  objects of the *same* hub cluster (a wire junction, a wire→its pin) then fell through to a full
  O(nmem²) re-cluster the P2 review had eliminated. Fix: cache the hub cluster's member keys
  (`fly_hub_mem[]` = `{kind,idx,pin}`, built from the `res.clu[a]==res.hub` members) and test the
  new pick against that set (`flyline_pick_in_hub_cluster`). The **over-match** direction is the
  dangerous one and IS observable: if the check wrongly matches a *different*-cluster object the
  slide keeps stale destinations → a degenerate segment. `xschem flylines seg0` (origin **and**
  destination) plus a cross-cluster render rail catches it (forcing `return 1` reds it with
  `seg0 = {500 0 500 0}`). The under-match direction is perf-only (full recompute still draws the
  correct star), so it is not output-testable — expected for a perf optimization.
