# Issue 0030 — `net_hilight_dash_period` recomputed twice per marching wire each animation frame

**Opened:** 2026-06-25
**Status:** ✅ RESOLVED (2026-06-25) — split out `net_hilight_march_offset_p()` /
`net_hilight_next_edge_ms_p()` (period-precomputed cores); `scan_animating_hilights()` now computes
`P = net_hilight_dash_period(st)` once per wire and feeds both. Public signatures unchanged. Verified:
clean build, regression suite 0 FATAL/0 FAIL, and `net_hilight_march_offset` bit-matches the analytic
`P*frac(rate*now/1000)` across even/odd-dash periods, march_fwd/rev, and the non-marching guard.
Originally logged from `/code-review high` of the multi-window-anim Phase A work;
finding was on **pre-existing Pass 2b code**, not the Phase A borrow primitive.
**Affects:** `scan_animating_hilights()` wire loop (`src/hilight.c`), via
`net_hilight_march_offset()` (line ~2591) and `net_hilight_next_edge_ms()` (line ~2555),
both of which call `net_hilight_dash_period()` (line ~2572).
**Severity:** low — pure repeated work; no wrong output. Bounded (short dash arrays, bounded
highlighted-wire count) but it sits on the ~30fps marching-ants tick hot path.
**Branch:** `fluid-editing`. See [[net-hilight-styles]].

---

## 1. Symptom

On every marching-ants animation frame, the dash-array sum that defines a style's dash period
is walked **twice per highlighted marching wire** instead of once per style.

## 2. Root cause

`draw_hilight_region()` calls `scan_animating_hilights(now, &sig, &maxw, &next, ...)` with BOTH
`sig` and `next_ms` requested. In the wire loop, for each animating wire:

```c
/* src/hilight.c — scan_animating_hilights() wire loop */
if(sig) {
  ...
  term = term * 31u + (unsigned int)(int)net_hilight_march_offset(st, now);  /* line ~2632 */
  *sig = *sig * 1000003u + term;
}
...
if(next_ms) { double d = net_hilight_next_edge_ms(st, now); if(d < *next_ms) *next_ms = d; } /* ~2636 */
```

Both helpers independently recompute the per-style dash period:

```c
double net_hilight_march_offset(NetHilightStyle *st, double now) {
  ...
  P = net_hilight_dash_period(st);          /* walk #1 */
  ...
}
static double net_hilight_next_edge_ms(NetHilightStyle *st, double now) {
  ...
  double P = net_hilight_dash_period(st);   /* walk #2 */
  double px_ms = ... / ((double)st->rate_persec * P) ...;
}
```

`net_hilight_dash_period()` is a `sum(dash_arr)` loop that depends **only on the style**, not on
the wire or on `now`. So with N highlighted wires sharing one marching style, the dash-array sum
is computed `2N` times per frame, when it is invariant for the whole frame (really per style).

## 3. Fix

Compute `P = net_hilight_dash_period(st)` **once** per style per frame and reuse it for both the
marching offset and the cadence. Options, cheapest first:

1. Compute `P` once in the wire loop and pass it into both `net_hilight_march_offset` /
   `net_hilight_next_edge_ms` (add a `double P` param, or split out a `_with_period` variant).
2. Memoize per `st->index` across the loop (styles repeat across wires; a small cache keyed by
   index avoids recomputation even without threading a param).

Keep the "single source of truth" property the current comments stress — whatever holds `P` must
stay the same value feeding `net_hilight_march_offset`'s `P * frac` and the
`1000/(rate*P)` cadence, so the signature flip and the wake interval cannot drift.

## 4. Tests

No behavioral change, so no RED is available; this is a refactor verified by:
- the existing marching-ants animation still ticks/redraws identically (PNG byte-diff at forced
  `net_hilight_test_now` times across a march step, as in the Pass 2a/2b checks);
- the regression suite (`create_save`/`open_close`/`netlisting`) stays green.

## 5. Notes

Surfaced (CONFIRMED) by the high-effort code review of the Phase A context-borrow work
(commit `c85b4751`); flagged there as a "separate cleanup" and logged here so it is not lost.
A related, lower-confidence review observation: the marching wake-interval formula
`1000/(rate*P)` in `net_hilight_next_edge_ms` encodes the same "dashes move one whole pixel per
step" truth as the `(int)net_hilight_march_offset` signature in `scan_animating_hilights`; if the
offset model is ever retuned (sub-pixel / non-linear scroll), the two could drift. Worth keeping
in mind when doing the fix above, but not in itself a defect today.
