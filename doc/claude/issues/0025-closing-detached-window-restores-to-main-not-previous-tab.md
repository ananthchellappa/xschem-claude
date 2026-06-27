# Issue 0025 — closing a detached window in tabbed mode restores focus to the main window, not the previously-active tab

**Opened:** 2026-06-22
**Status:** ✅ RESOLVED 2026-06-22 (branch `fluid-editing`). When `destroy_window` closes the
CURRENT window it now restores to the most-recently-active tab (`tab_queue GET`) instead of
unconditionally `save_xctx[0]`, falling back to main when there is none/invalid. Real windows
are never stored in `tab_queue`, so GET is the last tab visited; closing a NON-current window
is unchanged. Windowed-mode behavior is preserved (empty queue → main). Regression test
`tests/headless/test_close_window_restores_prev_tab.tcl` (RED→GREEN): on a tab, switch to a
window, close it → lands on the tab, not `.drw`; no zombie toplevel.
**Affects:** `destroy_window()` (`src/xinit.c`) when reached for a real window in tabbed mode
via the new `is_window_context()` routing in `new_schematic("destroy", ...)`.
**Severity:** low — focus/restore-target UX regression, not data corruption; bookkeeping
(`window_count`, slots) stays consistent.
**Branch:** `fluid-editing`. See [[multi-window-detach]].

---

## 1. Symptom

In tabbed mode with tab `.x3` active, focus a detached window `.x1`, then close `.x1`. The
editor lands on the main window (`.drw`) instead of the tab (`.x3`) the user came from.

## 2. Root cause

The destroy dispatch now routes a real window to `destroy_window` even in tabbed mode (the
correct fix for the zombie-toplevel bug):

```c
/* src/xinit.c (new_schematic, "destroy") */
if(!tabbed_interface || is_window_context(win_path)) {
  destroy_window(&window_count, win_path);
} else {
  destroy_tab(&window_count, win_path);
}
```

`destroy_tab` consults `tab_queue PREVIOUS` to pick the restore target, so closing a tab
returns to the previously-active tab. `destroy_window` has no `tab_queue` awareness and
restores `xctx` to slot 0 / `.drw`. So a cross-kind close (closing a window while a tab was
the prior context) loses the navigation history.

## 3. Fix

When `destroy_window` closes a context in tabbed mode, choose the restore target from
`tab_queue PREVIOUS` (as `destroy_tab` does) instead of unconditionally falling back to slot
0, so focus returns to the last-active context regardless of whether it was a tab or a
window. Keep the toplevel-destroy behavior that fixed the zombie window.

## 4. Tests

Extend `tests/headless/test_multi_window.tcl`: open a tab `.x?`, a detached window, switch
focus between them, close the window, and assert the current context is the tab, not `.drw`.
