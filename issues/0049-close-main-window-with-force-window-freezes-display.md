# Issue 0049 — Closing the main window while a detached force-window is open freezes the main display

**Opened:** 2026-06-27
**Status:** ✅ RESOLVED (2026-06-27, commit `1130bda7`) — `swap_tabs()` (`src/xinit.c`) now also swaps
the `window` (X Window id) field between the two contexts, mirroring `swap_windows()`. For genuine tabs
(which share the single `.drw` X window) this is a no-op; for a force-window (its own X window) it keeps
each X window with its path, so after the main window absorbs the detached schematic and destroys the
detached window, the surviving `.drw` context draws into its OWN live canvas instead of the destroyed
drawable. Also added `xschem get drawwindowid` (`xctx->window`) as an introspection/test seam.
**Affects:** `src/xinit.c` `swap_tabs()` (~:1436). Reached from the window-close path
`xschem exit [force]` (`src/scheduler.c` ~:1328, tabbed branch) ← `close_schematic_window`
(`src/xschem.tcl`) ← Ctrl+W (`callback.c` case `'w'`). The complementary `swap_windows()` (non-tabbed
branch) already swapped the window id and was unaffected.
**Severity:** HIGH — the main application window becomes unusable (frozen canvas); only Ctrl+Q exits,
leaving (under WSLg) a wedged shell.
**Branch:** `fluid-editing`.
**Reported by:** user (WSLg, run via `xschem --script src/cadence_style_rc`).
**Related:** [[multi-window-detach]], issues 0021 (window-switch unguarded save_xctx deref), 0025
(closing detached window restore target), 0001/0002 (WSLg display wedge / ghost window).

---

## 1. Symptom

1. Open a schematic (e.g. read-only `test_hier_descend_etc`) — it replaces `untitled.sch` in the only
   xschem window.
2. Select an instance and press **Ctrl+Shift+N** (`cadence::open_inst_sch_readonly`) → the instance's
   schematic (`solar_ctl.sch`) opens **read-only in a NEW, separate window**.
3. Go back to the main (first) window and press **Ctrl+W** (close).

The detached `solar_ctl` window vanishes and the main window now shows `solar_ctl.sch` (its title is
**correct**), but the canvas is **FROZEN** — no redraw, and **resizing does not help**. A further Ctrl+W
re-titles to `untitled.sch` (correct) yet the display stays stuck. Ctrl+Q exits the process but (on
WSLg) leaves an empty shell window immune to `xkill`.

## 2. Root cause

Closing the main window (`.drw`) while another window is open cannot destroy `.drw` (it is the app
root), so the close path **absorbs** the other window's schematic into `.drw` and **destroys the other
window** — hence the main window correctly ends up showing `solar_ctl`.

In **tabbed mode** (the default, `set_ne tabbed_interface 1`) this routes through `swap_tabs()`:

```c
/* src/xinit.c swap_tabs() — BEFORE the fix */
SWAP top_path           between save_xctx[i] and save_xctx[j]
SWAP current_win_path   between save_xctx[i] and save_xctx[j]
/* (window id NOT swapped) */
swap the two save_xctx[] struct pointers
... new_schematic("switch_tab", ...) ; caller then new_schematic("destroy", ...) ...
```

It swaps `top_path` and `current_win_path` but **not** the `window` (X Window id) — unlike
`swap_windows()` (the non-tabbed branch), which does `SWAP(save_xctx[i]->window, save_xctx[j]->window, ...)`.

For genuine **tabs** this is harmless: all tabs in a window share the *same* `.drw` X window, so the id
is identical in both slots and swapping it is a no-op. But **Ctrl+Shift+N** opens a **force-window**
(`xschem schematic_in_new_window force window`) — a real, separate top-level with its **own** X window.
After `swap_tabs()` the surviving primary (`.drw`) context keeps the **sub-window's** X id; the
sub-window is then destroyed, so `.drw` is left drawing into a **destroyed drawable** → frozen.

(The logical state is otherwise healthy: after the close `.drw` is still `winfo` viewable / mapped /
`wm state normal`, and the schematic/title are correct. The *only* defect is the stale `xctx->window`,
which is why a resize — which redraws into the same dead drawable — does not recover it.)

## 3. Fix

`swap_tabs()` now swaps the `window` field too, right after the `current_win_path` swap:

```c
Window window;
...
window = save_xctx[i]->window;
save_xctx[i]->window = save_xctx[j]->window;
save_xctx[j]->window = window;
```

No-op for real tabs (shared id); for a force-window it moves each X window with its path, so the
surviving main window draws into its own live canvas. (One-statement fix, symmetric with
`swap_windows()`.)

## 4. Test / verification

`tests/headless/test_close_window_force.tcl` (GUI) reproduces the flow with self-contained library
schematics: `xschem load a.sch`, `xschem load_new_window -window b.sch` (a real separate `.x1` window),
switch back to `.drw`, then `xschem exit force`. It asserts the surviving main's draw target equals its
canvas:

```
[xschem get drawwindowid] == [winfo id .drw]
```

Pre-fix this is the **destroyed** sub-window's id (check **C6** fails); post-fix it is the live `.drw`
id (C6 passes) while C1–C5 — including "main absorbed b.sch" and ".x1 destroyed" — are unchanged.
A **pure-tab** close (`load_new_window` with no `-window`) was verified unaffected (the window swap is a
no-op there), and the user's exact SANDBOX files (`test_hier_descend_etc` + `solar_ctl`) reproduce
`drawmatch=1` after the fix. Regression suite (create_save / open_close / netlisting) clean.

### Notes for future work in this area
- **The freeze is invisible to logical probes** — `.drw` stays viewable/mapped/normal; only
  `xctx->window` is wrong. `xschem get drawwindowid` vs `[winfo id <canvas>]` is the detectable signal
  (compare **numerically** — drawwindowid is decimal, `winfo id` is hex `0x…`; realize the window first
  via `zoom_full`/a draw or `xctx->window` is 0 in script mode).
- **`xschem get` dispatches on `argv[2][0]`** (a `switch` on the key's first char in `xschem_cmds_g`,
  `scheduler.c`), so a new get-key must be added under the matching `case '<firstletter>':`.
- The fallback `my_snprintf` (non-`HAS_SNPRINTF`, `util.c`) supports only `%s/%d/%x/%c/%u/%p/%g/%e/%f`
  as `int` — **no `%lx`/`%l`**; format XIDs with `%u` and an `(unsigned int)` cast (they fit in 32 bits).
