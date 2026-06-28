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

- W1 is **not raised** — it stays under W2 (a plain `raise` is refused by WSLg/WM focus-stealing
  prevention on an already-open window);
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

`cadence::focus_window` does three things after switching the engine context (kept synchronous so
`return_to_top`'s loop still sees each hop):

```tcl
xschem new_schematic switch $win                    ;# 1. engine context (authoritative)
# 2. RAISE+ACTIVATE the target's toplevel via the freshly-mapped trick (only across toplevels):
if {[winfo ismapped $top]} { set geo [wm geometry $top]; wm withdraw $top; wm deiconify $top
                             catch {wm geometry $top $geo} } else { catch {wm deiconify $top} }
raise $top; update idletasks
# 3. WARP the pointer into the target canvas:
event generate $win <Motion> -warp 1 -x <w/2> -y <h/2>
focus -force $win
```

1. **Re-map raise (the proven Library-Manager trick, `library_manager_launch.md`).** WSLg/WM
   focus-stealing prevention refuses `raise`/`focus` on an already-open window but grants it to a
   freshly **mapped** one, so re-map the target toplevel (`wm withdraw` + `wm deiconify`, geometry
   preserved). This is what reliably brings W1 forward and active when it is under W2 — the thing a
   plain `raise` failed to do. Verified safe on the main window `.`. Skipped when the target shares
   the current toplevel (tab switches need no re-map).
2. **Pointer warp.** With `mouse_follows_focus` on (default) the engine context follows the
   **pointer** (it switches only on `EnterNotify`, not on Motion/Button). When the windows overlap
   (the reported "under another window" case) the raise already slides the now-top canvas under the
   stationary pointer and X fires a real `EnterNotify` that syncs context+focus; the warp
   additionally covers side-by-side / multi-monitor layouts. Together: pointer, Tk focus and context
   all agree, so the old window's clicks/hover no longer act on the new context.

WM title-bar "active" tint: the re-map (a fresh map) is exactly what grants the window focus, so on
WSLg it should now also update the title tint — unlike the earlier plain `raise`/`focus`.

**Validation note:** the headless GUI environment has no real pointer (warps land the pointer at
0,0; `winfo pointerxy` is unreliable), so the raise/warp/title behavior must be confirmed on real
WSLg. The context-switch logic IS verified headless (`test_descend_newwin_return.tcl`,
`current_win_path`/`currsch`/`schname` after each return).

## 4. Acceptance

After a cross-window return (Ctrl-E or Alt-E), the pointer is in the target window and that window's
context is active: clicks/selection/hover all act on the window the pointer is in; no input is routed
to the previously-active window. Headless `test_descend_newwin_return.tcl` still passes (context-level
assertions); a GUI check confirms pointer + context land together on the parent window.
