# Issue 0032 — `net_hilight_anim_update()` fans a C→Tcl borrow+query out to every open window on every highlight change, with no short-circuit

**Opened:** 2026-06-25
**Status:** ✅ RESOLVED (2026-06-25) — added two O(1) short-circuits at the top of
`net_hilight_anim_update()` before the fan-out: (a) a cached `net_hilight_has_anim_style` flag
(recomputed at the end of `build_net_hilight_styles()` — nonzero iff some compiled style
blinks/marches) skips the whole loop for the common default table; (b) `!net_hilight_animate`
(kill-switch off) skips it too. The expensive borrow+scan was already gated inside the per-window
Tcl proc (it early-returns on the kill-switch before `xschem get net_hilight_animated`), so the
real storm was kill-switch-ON-but-nothing-animating — exactly what flag (a) cuts. Verified with a
call-counter GUI test (scratchpad/fanout.tcl): default table → 0 fan-out calls (was ≥1), blink/march
style defined → fan-out runs, kill-switch off → 0. Regression suites green. Lazy-cancel on
toggle-off is safe: `draw_hilight_region()` already returns 0 (stop) when the switch is off, so an
orphaned tick self-terminates on its next fire. Originally from the `/code-review high` of
multi-window net-highlight animation Phase D, commit `4ab92062`/`03597562`; finding [3].
**Affects:** `net_hilight_anim_update(void)` (`src/hilight.c`), its 8 callers
(`hilight.c:1441,2279,2313`; `scheduler.c:2815,4406,6931,8220,8273` — the standard
hilight / unhilight_all / interactive 9/8/0 / waveform / edit paths), and the per-window
Tcl `net_hilight_anim_update {win}` it invokes.
**Severity:** low — efficiency only; no wrong behavior. Bounded by `MAX_NEW_WINDOWS`
(20) and only material with many windows open; but it is on an interactive hot path.
**Branch:** `fluid-editing`. See [[net-hilight-styles]], [[multi-window-detach]].

---

## 1. Symptom

With several windows/tabs open, every highlight mutation — each `9`/`8`/`0` keypress,
`hilight` / `unhilight_all` / styled-net / waveform-viewer highlight, every style edit —
walks all open windows and does a full per-window context borrow + animation query for
each, even when **no** net is blinking/marching in **any** window. Before Phase D this was
a single `tclvareval` on the front window.

## 2. Root cause

Phase D generalized the front-only update to a fan-out:

```c
/* src/hilight.c */
void net_hilight_anim_update(void) {
  ...
  for(i = 0; i < MAX_NEW_WINDOWS; ++i) {        /* up to 20 slots */
    ctx = save_xctx[i]; ...
    if(ctx != xctx && (!ctx->top_path || !ctx->top_path[0])) continue; /* skip bg tabs */
    wp = (i == 0) ? ".drw" : get_window_path(i);
    tclvareval("net_hilight_anim_update {", wp, "}", NULL);   /* C -> Tcl, per window */
  }
}
```

Each `tclvareval` enters the Tcl proc, which calls `xschem get net_hilight_animated $win`
— a **context borrow** (`net_hilight_borrow_ctx`) plus `scan_animating_hilights()` over
that window's highlighted wires/instances. So one highlight change costs
`O(open_windows)` C↔Tcl round-trips, borrows, and net scans, with **no global
"is anything animated anywhere?" guard** to skip the whole loop in the common
no-animation case.

## 3. Fix

Add a cheap short-circuit before the fan-out, e.g.:
- If the kill-switch is off (`!tclgetboolvar("net_hilight_animate")`), skip entirely —
  no window can animate. (One `tclgetboolvar`.)
- Optionally, track a global "any in-use animating style" flag (set when an animating
  style is applied, cleared on style-table rebuild / unhilight_all) and skip the fan-out
  when false, so the borrow+scan storm only happens when some net actually animates.

Either keeps the common case (animation enabled but nothing blinking, or nothing
highlighted) to a single boolean check instead of up-to-20 borrow+query round-trips.
Keep the per-window arm/cancel semantics unchanged for the case where something does
animate.

## 4. Tests

- No behavior change: the Phase D arm/cancel tests
  (`scratchpad/phaseD_arm_test.tcl`, `phaseD_tab_test.tcl`) must stay green.
- Optionally assert the short-circuit: with the kill-switch off (or no highlights), a
  highlight op does not arm any `net_hilight_after(<win>)` timer (already implied) and
  performs no per-window query (would need a counter/probe to assert directly).
- Regression (`create_save`/`open_close`/`netlisting`) stays green.

## 5. Notes

Surfaced (CONFIRMED) by the Phase D review; deferred there as a Phase E (perf/finish)
item rather than fixed inline, to keep the review-response commit to correctness only.
Related cleanup flagged in the same review (not logged separately): the `save_xctx[]`
window-iteration idiom in this function is now a 4th near-duplicate of the loop in
`xschem windows` (`scheduler.c`), `scheduler.c:7759`, and `get_tab_or_window_number`
(`xinit.c`); a shared "iterate open contexts → (ctx, win_path)" helper would dedup it and
make a future change to the single-schematic / `save_xctx[0]` invariant a one-site edit.
