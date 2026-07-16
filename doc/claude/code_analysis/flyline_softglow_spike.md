# B4 spike — Cadence-style soft-glow fly-lines: DEFER

Status: 2026-07-13. Boxed feasibility spike for step B4 of
`doc/claude/suggestions/flyline_implementation_plan.md`. Companion to
`doc/claude/specs/hover_flylines.md` (§7.3) and `flyline_architecture.md` (C2).

## Verdict

**Defer.** Keep the dashed colored placeholder (`gc_flyline`, constraint C2). A Cadence-style
translucent/cloudy glow is *not* a cheap add on the current interactive draw path; it needs new
Cairo-overlay plumbing that the fly-line erase/re-stamp machinery (built in B3) is not structured
for. The expected outcome from the spec held up under inspection — this note records *why*, so the
decision is not re-litigated.

## What the code actually offers

- **The interactive line path is pure Xlib.** `drawtempline()` (`draw.c:1737`) — the primitive the
  fly-line star strokes through — batches `XDrawSegments`/`XDrawLine` onto `xctx->window`. Xlib
  lines are **solid**: no per-pixel alpha, no blur. This is exactly what draws the star today.
- **Cairo is present but wired to other jobs.** `cairo_set_source_rgba` / `cairo_paint_with_alpha`
  appear only in: image/graph blitting (`draw.c:5481/5495`), PNG/PS export (`psprint.c`), and the
  Windows surface-clear helper (`draw.c:35`). A window-targeting `xctx->cairo_ctx` exists, so alpha
  stroking is *technically reachable* — but it is used for text and image compositing, **not** for
  the interactive overlay lines.

## Why it is not a cheap spike

A glow would have to stroke into `xctx->cairo_ctx` with `cairo_set_source_rgba` + a wide/blurred
`cairo_stroke`, and then coexist with the machinery B3 just established:

1. **Erase.** B3 erases the star with a regional `draw()` that repaints the world bbox from the
   **Xlib backing pixmap** (`save_pixmap`). A Cairo glow painted directly on the window is not in
   that pixmap, so the regional repaint would not cleanly remove it — the erase model would have to
   change (composite the glow into/through the pixmap, or track a separate damage region).
2. **Re-stamp.** `flyline_restamp()` re-strokes `xctx->fly_seg` after every full redraw. A Cairo
   path would need its own re-stamp, ordered against the Xlib hover/crosshair/selection overlays
   that are also re-stamped in `draw()`.
3. **Blur cost & correctness.** A real soft glow means either a multi-pass stroke (several
   decreasing-alpha widths) or an offscreen blur surface — per hover, per redraw. That is the
   "significant new plumbing / new Cairo overlay surface" the spec (§7.3) and architecture (C2)
   already flagged, now confirmed against the B3 erase/re-stamp design.

Risk/reward is poor: it would re-open the C1-clean, erase-correct overlay I just verified, for a
purely cosmetic upgrade. The dashed placeholder reads clearly and is proven (it is exactly
`gc_hover`'s style).

## If revisited later

The lowest-risk route is **not** direct-to-window Cairo. Instead: render the whole overlay (star +
glow) into a dedicated ARGB Cairo surface, and composite that surface in one
`cairo_paint_with_alpha` at the end of `draw()` — mirroring how graph images already blit
(`draw.c:5495`). That isolates the glow from the Xlib erase model (the surface is cleared/rebuilt
per frame, no regional-repaint interaction) at the cost of a per-frame surface paint. Marching-ants
(spec §7.2) is the cheaper cosmetic upgrade and can ride the existing `gc_flyline` dash offset with
no new surface. Neither is needed for v1.
