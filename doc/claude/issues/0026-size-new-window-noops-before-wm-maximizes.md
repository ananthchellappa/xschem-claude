# Issue 0026 — `size_new_window` reads geometry before the WM realizes it, so it no-ops on exactly the maximizing-WM case it targets

**Opened:** 2026-06-22
**Status:** ✅ RESOLVED 2026-06-22 (branch `fluid-editing`) **as hardening**. The clamp logic
was split into `_size_new_window_apply`; `size_new_window` now runs it immediately AND once
more on the first `<Map>` (a one-shot binding that removes itself, so a later USER resize is
never overridden). This catches WMs that maximize a new toplevel only after creation, when
the immediate `winfo width` is still the requested size. No reliable RED (needs a maximizing
WM, not available in this WSLg environment); verified by inspection and that the multi-window
GUI suite stays green.
**Affects:** `size_new_window` (`src/xschem.tcl`), called from `create_new_window` and
`detach_tab` to "tame fullscreen new windows".
**Severity:** low — on window managers that maximize new toplevels, the new/detached window
can still come up (near-)fullscreen.
**Branch:** `fluid-editing`. See [[multi-window-detach]].

---

## 1. Symptom

On a WM that maximizes new toplevels (the documented motivating case), a new or detached
window still appears fullscreen despite `size_new_window`.

## 2. Root cause

```tcl
# src/xschem.tcl:10896
proc size_new_window {win} {
  ...
  update idletasks
  set sw [winfo screenwidth $win]; set sh [winfo screenheight $win]
  # only intervene if the window is hogging (near-)the whole screen
  if {[winfo width $win] <= int($sw * 0.9) && [winfo height $win] <= int($sh * 0.9)} return
  ...
  wm geometry $win ${w}x${h}+60+60
}
```

`size_new_window` runs right after the window is created, with only a single
`update idletasks`. A freshly-created, not-yet-mapped toplevel typically reports its
*requested* width (small, e.g. 400 or 1), not the maximized size the WM will apply slightly
later. So the `<= sw*0.9` guard passes and the function returns without resizing — precisely
on the maximizing-WM case it exists to fix.

## 3. Fix

Defer the sizing decision until the window is actually mapped/configured: run the check on
the first `<Configure>` (or `<Map>`) event, or `tkwait visibility $win` before measuring,
rather than relying on one `update idletasks`. Guard against re-firing on every later
`<Configure>` (one-shot binding).

## 4. Tests

Hard to assert deterministically without a maximizing WM. At minimum, add a headless check
that `size_new_window` on an artificially over-sized window clamps it, and document the
mapped-vs-requested timing in the proc comment so the no-op case is not reintroduced.
