# Issue 0054 — Descend-return cross-window hop desyncs engine context from the pointer (input acts on the wrong window)

**Opened:** 2026-06-27
**Status:** RESOLVED 2026-06-27 (branch `fluid-editing`).
**Severity:** HIGH (functional) — after a cross-window return the schematic under the pointer becomes
unresponsive / acts on the *other* window: clicks select in the wrong window, hover highlighting
stops. Plus a cosmetic WM-title "active" lag (WSLg).
**Source:** user report on WSLg, follow-up to the issue 0053 return chain.
**Affects:** `utils/cadence_nav.tcl` `cadence::focus_window` (the cross-window hop used by
`return_one_level` / `return_to_top`). Root mechanism in `callback.c`
`handle_window_switching` (~:5868) + `mouse_follows_focus`. Related: [[descend-newwin-return-chain]],
issue 0053.

---

## 1. Symptom

Hierarchy A→B→C, open A read-only, descend into an instance of B in a **new window** (W2). In W2,
press **Ctrl-E** (return one level). Expected: the first window (W1, showing A) becomes active.
Instead, with the pointer still physically in W2:

- the WM shell does not show W1 as active;
- the schematic "stops responding" — clicking in W2 selects an instance in **W1** (by W2's
  coordinates); **Ctrl-A** selects in W1; **hover highlighting stops** in W2;
- moving the pointer over W1 restores normal behavior (but the WM title only tints "active" on a
  click).

## 2. Root cause

`mouse_follows_focus` (default **on**) makes the engine context follow the **pointer**:
`handle_window_switching` switches `xctx` only on **EnterNotify** (pointer crossing) — Motion and
ButtonPress do *not* switch it. `return_one_level`/`return_to_top` hop windows by calling
`cadence::focus_window`, which switched `xctx` to the parent window via `xschem new_schematic switch`
**while the pointer was still over the child window**. That breaks the invariant "context == window
under the pointer": until the pointer next crosses a boundary, the child window's clicks/hover keep
operating on the parent's context (and the child's own hover stops, since the child is no longer the
active context). The original `focus_window` also tried `focus -force` on the toplevel, which neither
moves the pointer nor reliably moves WM focus on WSLg.

## 3. Fix

`cadence::focus_window` now **warps the pointer into the target canvas** after switching the context:

```tcl
xschem new_schematic switch $win            ;# synchronous: return_to_top's loop sees it
raise [winfo toplevel $win]
event generate $win <Motion> -warp 1 -x <w/2> -y <h/2>   ;# pointer -> target, re-syncs context/focus
focus -force $win
```

Warping makes pointer, Tk focus and engine context agree immediately — the honest meaning of "this
window is now active" under focus-follows-mouse. The context switch stays synchronous so
`return_to_top`'s loop still sees each hop. Verified: after Ctrl-E from W2, both `current_win_path`
**and** `winfo containing` the pointer are W1 (`.drw`).

Not fixed (WM limitation): the WM title-bar "active" tint. On WSLg the title bar only re-tints on a
real click, not on focus-follows-mouse focus; the app cannot synthesize that without a disruptive
withdraw/deiconify of the main window. The schematic itself is fully live after the warp.

## 4. Acceptance

After a cross-window return (Ctrl-E or Alt-E), the pointer is in the target window and that window's
context is active: clicks/selection/hover all act on the window the pointer is in; no input is routed
to the previously-active window. Headless `test_descend_newwin_return.tcl` still passes (context-level
assertions); a GUI check confirms pointer + context land together on the parent window.
