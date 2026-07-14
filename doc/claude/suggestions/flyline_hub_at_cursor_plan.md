# Implementation plan — fly-line hub at the cursor point

Status: 2026-07-13. Follow-up to Track B (`doc/claude/specs/hover_flylines.md`,
`code_analysis/flyline_trackB_lessons.md`). RED-first, one commit per step.

## Goal

Today the star origin ("hub") is the hovered **cluster's canonical anchor** — a pin coord, else the
first member's point, and for a wire that point is the wire **midpoint** (`flyline.c`,
`cx[hub]/cy[hub]`). Requested change: the hub is the **point on the hovered wire/pin/label closest to
the mouse pointer**, so fly-lines emanate from exactly where the cursor is. Destinations (the other
clusters' anchors) are unchanged; only the segment **origin** moves.

## What changes vs what stays

- **Changes:** the segment *origin* only. `flyline_compute()` must know the pointer position and
  project it onto the hovered object.
- **Stays:** destination anchors (`cx[c]/cy[c]` for the other clusters), clustering, the implicit-only
  rule, cap/global/bus logic, the `clusters {…}` dict anchors (keep canonical/stable), C1.
- **`net <name>` form:** no pointer → keep origin = cluster-0 anchor (unchanged; keeps existing A5
  rails green). Only the `at`/hover form gets a cursor hub.

## The hub-point projection

New helper in `flyline.c`, read-only:

```
flyline_hub_point(pick, mx, my) -> (hx, hy):
  WIRE     : clamp-projection of (mx,my) onto segment wire[pick.n] (t in [0,1])
  INST_PIN : get_inst_pin_coord(pick.n, pick.col)          (pin is a point)
  ELEMENT  : get_inst_pin_coord(pick.n, 0)                  (label/pin symbol pin)
  else     : (mx,my)                                        (fallback)
```

`t = clamp( ((m-p1)·(p2-p1)) / |p2-p1|² , 0, 1 )`, guard the zero-length wire. Pure geometry over
`xctx->wire[]` / pin coords — no state writes (C1).

## Steps

**H0 — hub origin = cursor point (headless-testable via `at`).**
The `at X Y` query *is* the "mouse": `(X,Y)` is the point passed to `find_closest_obj`. So the whole
hub-origin behavior is testable with `--nogui`, no GUI needed.
- Signature: `flyline_compute(netname, have_pick, pick, double mx, double my, FlyResult*)`.
  Callers: scheduler `at` passes `atof(argv[3]), atof(argv[4])`; scheduler `net` passes any
  (unused, have_pick=0); `draw_flylines` passes `xctx->mousex, xctx->mousey`.
- In `flyline_compute`, when `have_pick`, compute `flyline_hub_point(pick, mx, my)` and use it as the
  segment **origin** in the star loop instead of `cx[hub]/cy[hub]`. Destinations stay `cx[bestc]`.
- RED: fixture = wire `(0,0)-(200,0)` + a far same-name label (2 clusters). `flylines at 50 30` →
  first segment starts at `50 0` (projection), NOT `100 0` (midpoint). `at 10 5` → starts `10 0`.
  Label/pin hub → starts at the pin coord. `net CLK` form → origin unchanged (cluster-0 anchor).
- Sabotage-verify (force origin back to midpoint → rail reds).

**H1 — draw path uses the cursor hub (GUI).**
`draw_flylines` already passes the pointer (H0 signature). On each net change the star now starts at
the cursor. Render rail: hover a wire near one end vs the middle → `flylines shown` unchanged (net),
and the drawn origin differs. `shown` can't see the origin, so assert the origin another way: extend
`xschem flylines shown` is out of scope — instead add `xschem flylines at <mx> <my>` spot-checks in
the render test (same process) comparing segment[0] origin to the projected point. (Headless already
covers the math; H1 is just wiring + a smoke that it draws.)

**H2 — origin TRACKS the pointer within the same net (perf-sensitive).**
Decision point. Today same-net motion short-circuits (change-detect on `fly_last_net`) → the origin
would freeze at the first-hover point. To make it follow the cursor, motion within the same net must
re-derive the origin and redraw — WITHOUT re-clustering (the review just fixed the full-rescan cost).
- Cache the destination anchors + hub cluster id in `xctx` (keyed by resolved net) alongside
  `fly_seg`. On same-net / same-hub-cluster motion: recompute only `flyline_hub_point`, rebuild
  `fly_seg = hub → each cached dest`, erase the old bbox (regional draw over the union), re-stroke,
  update bbox. On net / hub-cluster change or an edit (`prep_hi_structs` clear): full recompute +
  refresh the cache.
- Cost per motion (cheap path): one regional `draw()` over the star bbox + O(dest) re-stroke — no
  member scan, no clustering. If that feels heavy on large sheets, swap the regional erase for the
  strip re-stamp from `save_pixmap` (spec §5.6) — defer until measured.
- Guard: still skip mid-gesture (the Track-B gesture-mask) and off-canvas.
- RED (render): hover a long wire at x=10 then x=180 (same net) → the drawn origin moves with the
  cursor while `shown` stays the net; verify via an inline `flylines at` origin check at each point.

**H3 — docs + eyeball.**
Update spec §5.3/§5.4 (hub = cursor projection; per-motion origin cache), note the perf decision,
short lessons if anything surprised. Eyeball: hover along a wire, watch the fly-line origin slide
under the cursor.

## Risks / notes

- **Perf is the whole risk** and it lives in H2 (per-motion erase+redraw). H0/H1 are cheap and
  fully headless-tested. Land H0 first (correct origin on net change), then H2 only if the
  "slides with the cursor" feel is wanted (it is — the request implies it).
- **C1 unaffected**: projection is read-only geometry; still no writes to schematic state.
- **Anchor for destinations** stays as-is (spec §12 open item); only the hub moves. If a destination
  should also aim at *its* nearest point to the hub, that is a separate enhancement — not in scope.
- Keep the `clusters {…}` dict anchors canonical (stable ids/points for the query API); the cursor
  hub affects only `segments {…}` origins.
