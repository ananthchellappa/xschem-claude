# Issue 0030 — `net_hilight_dash_period` recomputed twice per marching wire each animation frame

**Opened:** 2026-06-25
**Status:** ✅ RESOLVED (2026-06-25). Final fix: cache the dash period on the style
(`NetHilightStyle.period`, computed once at build via `net_hilight_compute_dash_period()`), so
`net_hilight_dash_period()` is an O(1) read everywhere — scan, render, and the striped renderer.
The first fix (a per-wire `_p` precompute-and-thread split) was correct but wrong-scoped and was
superseded; see §5 for that arc and §7 for the lessons. Verified: clean build, regression suite
0 FATAL/0 FAIL, and `net_hilight_march_offset` bit-matches the analytic `P*frac(rate*now/1000)`
across even/odd-dash periods, march_fwd/rev, and the non-marching guard. Originally logged from
`/code-review high` of the multi-window-anim Phase A work; finding was on **pre-existing Pass 2b
code**, not the Phase A borrow primitive.
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

## 5. Resolution arc — the first fix was correct but wrong-scoped (2026-06-25)

A `/code-review high` of the fix found the `_p` (precompute-P) split was incomplete: it deduped the
`scan_animating_hilights` wire loop but **not** the render hot path `draw_hilight_net()`, which still
called `net_hilight_march_offset()` per wire per frame and re-walked the dash array; and even in the
scan it was per-*wire*, though the period is per-*style*. Replaced the whole `_p` approach with a
cached `NetHilightStyle.period` (computed once at build via `net_hilight_compute_dash_period()`);
`net_hilight_dash_period()` is now an O(1) read, so scan AND render AND the striped renderer all read
the cached value — no per-wire/per-frame walk anywhere. The `_p` variants and the now-dead
`net_hilight_next_edge_ms` wrapper were removed. Verified: analytic offsets identical (march_check.tcl),
0031/0032 tests and the regression suites still green.

## 6. Notes

Surfaced (CONFIRMED) by the high-effort code review of the Phase A context-borrow work
(commit `c85b4751`); flagged there as a "separate cleanup" and logged here so it is not lost.
A related, lower-confidence review observation: the marching wake-interval formula
`1000/(rate*P)` in `net_hilight_next_edge_ms` encodes the same "dashes move one whole pixel per
step" truth as the `(int)net_hilight_march_offset` signature in `scan_animating_hilights`; if the
offset model is ever retuned (sub-pixel / non-linear scroll), the two could drift. Worth keeping
in mind when doing the fix above, but not in itself a defect today.

## 7. Lessons: how loop-invariant-recompute bugs arise — and how to prevent them

This is a textbook **loop-invariant recomputation** bug, and its two-stage fix history is itself the
most useful part: the first fix was *verified correct* yet still *wrong-scoped*. Both stages teach
something.

### What creates bugs like this

- **Invariance hidden behind a function boundary.** `net_hilight_march_offset(st, now)` *looks* like
  it depends on the per-frame `now`, so at the call site it doesn't read as loop-invariant. But
  nearly all of its cost is `net_hilight_dash_period(st)`, which depends only on `st`. Encapsulation
  hid the expensive, invariant sub-computation from everyone reading the loop.
- **The cost lives at the call site; the work lives at the definition.** Whoever wrote
  `net_hilight_dash_period` saw a cheap `sum()` over a 2–4 element array. What makes it matter —
  "called 2 × N-wires × ~30 fps" — is visible only in the scan/render loops, far away. Neither
  location, read in isolation, looks wrong. *The multiplier is the bug, and it is non-local.*
- **Self-contained signatures duplicate shared sub-results.** Two helpers (`_march_offset`,
  `_next_edge_ms`) were each designed to be callable with just `(st, now)`. Convenient — but each
  independently re-derives the same `P`, and neither can see the other doing it.
- **Accretion across feature passes.** Blink (Pass 2a) and marching (Pass 2b) each added a helper
  that needed the period. The duplication grew one locally-reasonable step at a time; no single
  commit "added a redundant computation."
- **The compiler can't save you here.** Loop-invariant code motion will hoist a plain `sum` out of a
  loop — but it cannot hoist `net_hilight_dash_period(st)` across an opaque, non-`pure` function call
  it can't prove is side-effect-free and whose `st` fields it can't prove are unmodified in the loop.
  *Invariance that crosses a function boundary is the human's job, not the optimizer's.*

### Why the *first* fix was also instructive

The initial fix precomputed `P` once per wire and threaded it through `_p` variants. It was correct
and verified — but it fixed the bug **at the scope of the symptom** (the one loop named in the
ticket) rather than **at the scope of the invariant**:

- It missed the *other* hot loop — `draw_hilight_net()`, the actual renderer — which recomputed the
  same period, because it reacted to "this loop calls it twice" instead of asking "how often does the
  answer actually change?"
- It left the work at O(highlighted wires) per frame, when the period only changes when the **style
  table is rebuilt** (a rare user action).

The replacement caches the period on the style at build time, so it is computed **once per style per
table edit** and read O(1) everywhere. **Match the fix to the lifetime of the data, not to the loop
you happened to be standing in.**

### How to prevent them proactively

1. **For every argument feeding an expensive call in a hot loop, know whether it varies.** `(st, now)`:
   `now` varies per frame, `st` is loop-invariant. An invariant argument feeding expensive work is a
   hoist-or-cache signal.
2. **Cache at the scope of invariance — ideally when you construct the data.** Find the widest scope
   over which the value is constant (here: a style's lifetime) and compute it there. Derived-but-fixed
   fields belong next to the data they derive from.
3. **Follow the codebase's own caching patterns.** This very struct already caches per-style derived
   data — `resolve_hilight_style_rgb()` lazily fills `cr/cg/cb` + `rgb_resolved`. The dash period
   simply didn't follow the established pattern; doing so from the start would have prevented the bug.
   *Inconsistency with a neighbouring convention is itself a smell.*
4. **When fixing a recompute, grep every caller of the recomputed function.** The render-path miss
   happened because the first fix touched only the call site in the ticket. Enumerating all callers of
   `net_hilight_dash_period` / `net_hilight_march_offset` would have surfaced `draw_hilight_net`
   immediately.
5. **Make the hot-path contract explicit at the definition.** A pure helper used on an animation tick
   should either memoize or carry a comment like "read O(1); do not re-walk per wire per frame." The
   cache field + its comment now do this, so the next person can't silently reintroduce the walk.
6. **Reason with the multiplier.** "Negligible per call × large call count = material." On a
   ~30 fps × N-object tick, treat *everything* invariant as something to precompute.

### Best practices that were violated

- **DRY at the level of *work*, not just text.** There was a single `net_hilight_dash_period`
  function (no copy-pasted source), yet the *computation* was repeated. DRY is about not repeating
  knowledge/work — duplication of effort counts even when the code is shared.
- **Compute-once / single source of truth at the right altitude.** Comments insisted the *value* of
  `P` be consistent between the offset and the cadence — but consistency-by-recomputation is both
  fragile and wasteful; consistency-by-storing-once is cheaper *and* safer.
- **Fix the cause at its scope.** The first fix addressed a symptom in one loop; the systemic cause
  (the period re-derived wherever needed) called for a fix at the data's scope.
- **Consistency with local convention.** An adjacent, established per-style cache (`rgb_resolved`)
  was the obvious template and was not followed.
