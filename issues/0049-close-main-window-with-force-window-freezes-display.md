# Issue 0049 — Closing the main window while a detached force-window is open freezes the main display

**Opened:** 2026-06-27
**Status:** ✅ RESOLVED (2026-06-27, commit `1130bda7`), with a **follow-up** (display no longer froze but
stayed STALE until a manual resize/zoom/pan — see §5 below). The freeze fix below addresses the dead drawable.
**Status (freeze):** `swap_tabs()` (`src/xinit.c`) now also swaps
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

---

## 5. Follow-up — stale (un-redrawn) main display after the close

**Reported by:** user (2026-06-27), same flow. After the freeze fix, the close path no longer wedges the
canvas (resize / `F` zoom-full / pan all recover it), but the main window's title/tab correctly switch to
`solar_ctl` (the absorbed schematic) while the **canvas keeps showing the OLD schematic (`A`)** until one of
those manual gestures triggers a redraw. "Just needs cleaning up."

### Root cause (a second, independent defect on the same path)
The freeze was the X window id; this is a **missing synchronous redraw**. The tabbed close path is:
`swap_tabs()` → `set_modify(0)` → `new_schematic("destroy", xctx->current_win_path, NULL, 1)` (note `dr=1`).
For a force-window that destroy routes to **`destroy_window()`** (real top-level), *not* `destroy_tab()`.

- `destroy_tab()` ends with `resetwin(...); set_modify(-1); … draw();` — it **always redraws** the surviving
  tab, so a genuine-tab close looks fine.
- `destroy_window()` **dropped the `dr` flag entirely** and never drew. The dispatcher passed `dr` to neither
  destroy helper. So `dr=1`'s intent ("draw after") was honored for tabs but silently lost for windows.
- `swap_tabs()`'s `new_schematic("switch_tab", …)` is a **no-op** — there is no `"switch_tab"` branch in the
  `new_schematic()` dispatcher (it uses `"switch"`), so nothing there draws either.

Net: closing the main `.drw` while a force-window is open did **zero synchronous draws** → title updates
(via `set_modify`) but the pixmap stays stale. No expose event fires (the `.drw` canvas neither moved nor
resized — only its backing schematic was swapped), which is why it does **not** self-heal; a resize/zoom/pan
issues the first real `draw()`.

### Fix (one line, symmetric with `destroy_tab`)
Thread `dr` into `destroy_window()` and redraw the surviving window when set:
```c
static void destroy_window(int *window_count, const char *win_path, int dr) { …
    set_modify(-1);
    if(dr && close) draw();   /* destroy_tab() always draws; destroy_window() used to drop dr */
```
and pass it at the call site: `destroy_window(&window_count, win_path, dr);`.
- Tabbed main-close with a force-window (`dr=1`): now redraws → **fixed**.
- Non-tabbed main-close (`dr=0`, scheduler issues its own `draw()` right after): unchanged (single draw).
- Closing a *non-main* detached window (`dr=1`): also now redraws — a latent stale-display fix.
- Genuine-tab close: routes to `destroy_tab()` (unchanged), so no double draw.

### Test / verification
Added **C7** to `tests/headless/test_close_window_force.tcl` plus a new introspection seam
`xschem get drawcount` (a monotonic `unsigned int draw_count` bumped at the top of `draw()`):
sample `drawcount` immediately **before and after** `xschem exit force` (before any `update`) and assert it
incremented — i.e. the close drew **synchronously**, not via a later expose. Sabotage-verified: with the
`draw()` removed, C7 fails (`drawcount 8 → 8`) while **C6 still passes** — confirming C7 catches exactly this
stale-draw defect and that it is independent of the freeze (C6). Post-fix all of C1–C7 pass (`8 → 9`).
Headless regression cases (create_save / open_close / netlisting) run with 0 FATAL.

### Notes for future work
- The two defects are orthogonal: **C6** (`drawwindowid`) guards the live-drawable/freeze; **C7**
  (`drawcount`) guards the synchronous-redraw. A future refactor must keep both — a correct draw *target*
  with no draw *call* still looks broken.
- `new_schematic("switch_tab", …)` in `swap_tabs()` matches no dispatcher branch and is a dead no-op; the
  destroy step is what actually repositions `xctx` (via its `savectx`/`tab_queue GET` fallback).
