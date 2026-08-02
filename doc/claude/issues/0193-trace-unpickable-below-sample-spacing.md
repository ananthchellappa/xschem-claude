# 0193 — a trace is unpickable, and the diamond vanishes, once the zoom is tighter than the sample spacing

**Status:** RESOLVED — fixed `12bc3fef`, **eyeballed PASS by the user 2026-08-02**
("the snap issue at high zoom is fixed")
**Reported:** 2026-08-02, by the user, on the ASE Waveform Viewer
**Area:** `src/draw.c` (`graph_point_at`, `draw_graph_snap_cursor`, the
trace-highlight envelope), `src/callback.c` (the marker drag),
`src/scheduler.c` (the two marker replay verbs)

## The report

> "When I zoom into one trace a LOT, the diamond snap cursor doesn't behave the
> way I expect. It snaps to just one point on the trace. If I zoom in some more,
> it doesn't snap to any point on the trace at all. In that condition, it is not
> possible to select the trace by clicking on it. One can select it by clicking
> on the legend name text."

And the observation that framed it, which is the whole issue in one sentence:

> "A trace will be generated from simulation. Something like an enable signal
> that goes to a logic high level can be specified with just two points. A
> supply voltage that is always up can be specified with just one point."

## The two meanings of "a point on a trace"

1. **A sample** — a row in the raw file. How many there are is the simulator's
   decision, not the viewer's, and it does not change with zoom. A steady supply
   is one; an enable edge is two.
2. **A point on the rendered curve** — the polyline drawn *between* the samples.
   There are infinitely many and they are zoom-independent.

The renderer draws (2). Every hit-test answered (1). That is the defect.

## Mechanism

Three loops walk the samples of a trace, and they carried **three different
window clips**.

**The renderer** (`draw.c` ~8221) keeps one sample OUTSIDE each edge, precisely
so the segment spanning the view is still stroked:

```c
if((gr->mode == 2) || (xxfollowing >= start && xxprevious <= end)) {
```

**The hit-test** (`graph_point_at`, `draw.c` ~5970) threw them away, and broke
the chain while doing it:

```c
if(xx < start || xx > end) { have_prev = 0; continue; }
```

`have_prev = 0` is the sharp end: it is what forms the segment. Downstream,

```c
if(have_prev) d = graph_point_seg_dist(px, py, prev_sx, prev_sy, sx, sy);
else          d = pd;              /* point distance only */
```

so the three regimes the user described fall straight out of it:

| samples inside the x window | behaviour |
|---|---|
| ≥ 2 | segments form — correct |
| exactly 1 | `have_prev` never set, `d = pd` → **snaps to that one point and nothing else** |
| 0 | the loop body never runs, `nd_min` stays −1 → **no hit at all**: unpickable, no diamond |

The legend still worked because `legend_slot_hit()` is a different path that
never touches sample data.

**The third loop** — the trace-highlight envelope (`draw.c` ~6301) — carried
`if(xx < start || xx > end) continue;`, so a highlighted trace lost its overlay
at exactly the same zoom, while the trace under it stayed drawn.

## Measured, before and after

`raw new p0193.raw dc vsweep 0 1.0 0.5` — three samples at 0, 0.5, 1.0;
`vv = 2*vsweep`. One sweep of 20223 canvas pixels per row, counting
`xschem get graph_near_wave 0 px py`:

| x window | samples in view | before | after |
|---|---|---|---|
| 0 .. 1.0 | 3 | 821 | 821 |
| 0.4 .. 0.6 | 1 | **16** | 719 |
| 0.10 .. 0.20 | **0** | **0** | 716 |

Probe: `scratchpad/probe_0193.tcl` (re-runnable).

## The fix

**1. Clip the SEGMENT, not the samples.** A segment is relevant unless *both*
its ends are off the same edge:

```c
seg_ok = have_prev && !(xx < start && prev_xx < start)
                   && !(xx > end   && prev_xx > end);
```

Samples outside the window still participate in the walk. The nearest-SAMPLE
answer keeps a two-tier form (`nd_*` for in-window, `no_*` as the fallback) so
that a marker anchor lands on exactly the sample it always did whenever one is
in view, and only falls back to a straddling neighbour when there is none.

**2. The snap point is the point on the CURVE.** `graph_point_seg_dist()` now
also returns the foot of the perpendicular, clamped to the segment. The hit
carries it as `seg_sx/seg_sy` (screen) and `seg_x/seg_y` (unscaled, `pow(10,…)`
undoing `mylog10` on a log axis — landmine 35), alongside the sample fields,
which are unchanged. The diamond and its readout use the curve point, so it
slides along the trace instead of hopping sample to sample, and it still has
somewhere to be when no sample is in view.

**3. Markers follow the diamond.** Decided by the user when the collision
surfaced. Issue 0188's promise — *"add a marker at the point that the diamond
cursor has snapped to"* — is only true if both read the same field, and at this
zoom the nearest sample is off-screen, so marking it would put the marker
outside the view. `GraphMarker.point`/`dataset` become the **anchor** (the
segment's left sample); `x`/`y` are the interpolated position. Creation
(`graph_marker_create`), the drag (`graph_marker_move`) and the drag *commit*
(`callback.c`) all take `seg_*`.

⚠ The mid-drag no-op test had to move with them. It compared `(dataset, point)`,
which is now **constant along a whole segment**, so a drag inside one segment
became a no-op and the marker hopped sample to sample. It compares the position
now. This is what MX6b defends — see "sabotages" below.

**4. Replay carries the position.** `x`/`y` used to be re-derivable from
`(dataset, point)`; they are not any more, so both log lines grew a trailing
`%.17g %.17g` and both verbs accept it optionally:

```
xschem graph_marker add_at <gi> <wave> <dataset> <point> [-delta] [<x> <y>]
xschem graph_marker anchor <num> <dataset> <point> [<x> <y>]
```

Without the position they resolve the sample — which is exactly what every log
line written before this issue meant, so old logs replay unchanged.

## Tests

`tests/headless/test_wave_snap.tcl` — 106 checks (was 93):
* `SZ1/SZ2/SZ3` the three regimes, counted against the full-view control;
* `SZ4/SZ5` the published pick in the zero-sample window is inside the visible
  x range and its y is the interpolated value on the curve;
* `SZS1`–`SZS9` source tripwires: the clip, the both-ends test, the diamond's
  field, the repaint test, the marker's field, the drag's no-op test, the
  envelope, and both log lines.

`tests/headless/test_wave_markers.tcl` — 983 / 437 (was 979 / 435). Eight legs
were rewritten from "x == the sample's sweep value" to "x is inside its own
segment and y is the raw LERPed across it" (`mk_in_seg` / `mk_lerp`, plus the
step-agnostic `mk_between` for MF1, whose fixture sweeps 100..101). That is
*stronger*, not weaker: the old assertion is the t == 0 case. `MX7e`'s
"it SNAPPED, it did not slide" is inverted by name.

## Sabotages (all five applied, built and run)

| # | sabotage | went red |
|---|---|---|
| A | restore the old window clip | SZ2, SZ3, SZS1 ×2 |
| B | marker reads `hit.point/x/y` again | **MP22 ×2** (issue 0188's equality), SZS5, MX6 |
| C | `graph_point_seg_dist` never computes the foot | SZ4, MX6 |
| D | mid-drag no-op test compares the anchor again | SZS7 — **and nothing else** |
| E | restore the envelope clip | SZS6 (source only — stated) |

⚠ **D survived the whole behavioural suite the first time.** Every existing drag
leg travels far enough to cross a sample boundary, so a marker that hops instead
of sliding satisfies all of them; only a SHORT drag tells them apart. `MX6b`
(an 8-px drag) was written for it and kills it.

## Not covered

* **The envelope's pixels are eyeball-only** — `SZS6` is a source tripwire. The
  overlay is painted window-only, so there is nothing to read back.
* **The diamond is not clamped to the plot box.** It was not before either (a
  trace clipped above the box already drew its glyph outside), and the entry
  gate is still `graph_plotbox_at()`.
* **Digital / bus traces.** They render as a band and a ribbon, not a polyline;
  `graph_point_at` skips bus entries as it always has.
* **`graph_marker_create_at` still validates the triple** even when given x/y,
  so a replay naming a nonexistent trace refuses rather than inventing a marker.
