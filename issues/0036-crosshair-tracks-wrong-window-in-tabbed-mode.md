# Issue 0036 — crosshair / mouse tracking follows the wrong window when a detached window is open in tabbed mode

**Opened:** 2026-06-25
**Status:** ✅ FIX APPLIED (2026-06-26) — needs interactive two-window confirmation.
Two complementary parts:

1. **Stop the wrong-window draw** — `handle_motion_notify()` (`src/callback.c`) drops
   motion whose `win_path` differs from `xctx->current_win_path` whenever a REAL
   (detached) window is involved on either side (`win_is_real || cur_is_real`, computed
   as in `handle_window_switching`), in addition to the old non-tabbed case. (This alone,
   shipped first, removed the wrong-window crosshair — confirmed by the user — but left
   the HOVERED window with no crosshair at all, since nothing made it draw.)
2. **Draw in the hovered window** — `mouse_follows_focus` (new mirrored Tcl global,
   default 1): a plain `EnterNotify` into a different visible window now does the same
   full context switch as `FocusIn` (`handle_window_switching`, idle/`semaphore==0`
   only), so the drawing context follows the pointer across windows and the hovered
   window runs the FULL motion handler — crosshair AND hover-highlight — without needing
   a click. Set `mouse_follows_focus 0` to require a click/FocusIn instead.

Together: the crosshair + hover track the pointer into whatever visible window it is
over; part (1) prevents stray cross-window draws during the brief gap before the switch.
Background tabs share `.drw` and still match the active tab's path, preserving the
tab-switch-keeps-crosshair-alive case (issue 0010). Verified: context follows the pointer
on `EnterNotify` (and respects the flag); single-window motion unchanged; regression
green. The visual crosshair/hover behaviour wants a GUI eyeball: detach a window via
`hi_descend` Destination → New window and confirm both windows show the crosshair + hover
under the pointer.
**Affects:** `handle_motion_notify()` motion guard (`src/callback.c:3586`),
`handle_window_switching()` (`src/callback.c` ~5905), the `<FocusIn>`/`<Enter>`/`<Motion>`
bindings (`set_bindings`, `src/xschem.tcl`). Reachable from any
real-detached-window-in-tabbed-mode scenario (`open_sub_schematic` Alt+E, `hi_descend`
new-window, manual detach).
**Severity:** medium — confusing/unusable hover + crosshair across windows; no data risk.
**Branch:** `fluid-editing`. See [[hi-descend]], [[multi-window-detach]], issue 0010.

---

## 1. Symptom

With a detached window active (e.g. after `hi_descend target=new_window`), moving the
mouse over the **other** (old/main) window still moves the tracking crosshair in the
**descended/new** window — the crosshair follows the wrong window.

## 2. Root cause

The motion handler short-circuits "motion belongs to another window" ONLY in
non-tabbed mode:

```c
/* src/callback.c:3586 — handle_motion_notify() */
if(!tabbed_interface && strcmp(win_path, xctx->current_win_path)) return;
```

`tabbed_interface` is on by default, so the guard is skipped and a Motion delivered to
ANY canvas draws the crosshair in `xctx` (the currently-focused context). When a real
**detached** window is the focused context and the pointer moves over the main window,
that main-window Motion (`win_path == .drw`) is processed against the detached window's
`xctx` (`current_win_path == .x1.drw`), so `draw_crosshair()` (3597) renders in the
wrong window. The real context switch only happens on `FocusIn`
(`handle_window_switching`, `callback.c` ~5947, the `event == FocusIn && semaphore==0`
arm), so without a focus change (focus-follows-mouse off / no click) the context never
switches and every stray Motion mis-targets.

The `!tabbed_interface` gate predates window+tab coexistence: it exists so that a
tab-switch (which shares `.drw` and does not regenerate an `EnterNotify`) keeps the
crosshair/hover alive (comment at `callback.c:3587-3590`). But it over-broadly disables
the cross-window guard for **real detached windows**, which DO have distinct paths.

## 3. Fix direction (verify interactively)

Make the guard fire on a window mismatch whenever a **real** (detached, own
`top_path`/canvas) window is involved, while still letting pure background tabs (shared
`.drw`, matching the active tab's `current_win_path`) through:

```c
/* ignore motion that belongs to a different window's canvas; background tabs share
 * .drw and legitimately match the active tab's path, so they still pass */
if(strcmp(win_path, xctx->current_win_path) &&
   (!tabbed_interface || (xctx->top_path && xctx->top_path[0]) || win_is_real)) return;
```

where `win_is_real` is computed as in `handle_window_switching`
(`get_tab_or_window_number(win_path)` → `save_xctx[n]->top_path[0]`). An unconditional
`if(strcmp(win_path, xctx->current_win_path)) return;` is likely also correct (a tab
switch leaves `current_win_path == .drw`, and `.drw` Motion then still matches), but
must be checked against the tab-switch hover case the original gate protected.

Care: this subsystem has regressed repeatedly (issues 0010 hover/crosshair-die-after-
tab-switch, 0020 clone-bindings, 0021 unguarded switch deref), so the fix needs real
two-window GUI verification, not just a headless probe.

## 4. Tests

- Interactive: open a detached window via `hi_descend target=new_window`; move the
  mouse over each window in turn and confirm the crosshair tracks the window under the
  pointer (and a tab-switch still keeps the crosshair alive — the 0010 case).
- Headless (partial): a `xschem callback .drw 6 …` Motion while `current_win_path` is a
  detached `.x1.drw` should NOT update that window's crosshair state. (Synthetic repro
  already shows the context does not switch on Enter/Motion — only FocusIn switches.)
