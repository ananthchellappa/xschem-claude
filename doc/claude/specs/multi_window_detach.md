# Detachable tabs & true multi-window (Tabs AND Windows)

Status: **proposed** (target branch `fluid-editing`).
Related: `doc/claude/suggestions/plan_multi_window_detach.md` (the RED-first build plan),
`doc/claude/specs/library_manager_launch.md` (the "New Window" checkbox that motivated this),
`src/xinit.c` (`new_schematic`, `create_new_tab`, `create_new_window`,
`switch_tab`, `switch_window`), `src/scheduler.c` (`load_new_window` dispatch).

## Goal

Give XSCHEM **Chrome-style** behavior: tabs **and** real top-level windows at the
same time, plus the ability to **detach** a tab into its own OS window (and
re-attach it). The concrete user story: put one schematic on monitor A and another
on monitor B, side by side, while still keeping a stack of tabs in each window.

## What already exists (and why it is so close)

XSCHEM already has *two complete* implementations of "open another schematic",
both built on the same per-schematic `Xschem_ctx` and the same
`save_xctx[]` / `window_path[]` context arrays and `switch_*` machinery:

| | **Tabbed** (`create_new_tab`, xinit.c:1805) | **Windowed** (`create_new_window`, xinit.c:1680) |
|---|---|---|
| Tk widget | a `.tabs.xN` button in the **one** shared tab bar | a real `toplevel .xN` (`build_widgets`/`pack_widgets`) |
| X11 window | **shares** the main canvas: `xctx->window = save_xctx[0]->window` (1891) | its **own** id via `Tk_WindowId` (1751) |
| GCs / pixmap | reuses the main window's | own GCs `create_gc()` against own window (1767) |
| rendering | repaints the single `.drw` on tab switch | independent OS window, composited by X |

The schematic *data* (wires, instances, zoom, selection…) is entirely
window-independent. The only thing separating a tab from a window is the
**render target**: which X window, which GCs, which widget bindings.

**Three assumptions block mixing tabs and windows today:**

1. **Global either/or.** `new_schematic("create",…)` (xinit.c:2189) reads the
   *global* `tabbed_interface` and dispatches to tab **or** window — there is no
   per-open choice. So the Library Manager "New Window" checkbox
   (`library_manager.tcl:115/432` → `xschem load_new_window` →
   `new_schematic("create",…)`, scheduler.c:3657) yields a **tab** whenever
   `tabbed_interface=1` (the default).
2. **One global tab bar, one canvas.** There is a single `.tabs` button strip,
   and every tab hardcodes its canvas to `save_xctx[0]->window` — the *main*
   window. A tab cannot belong to a second top-level.
3. **Mode lock.** Creating any 2nd context disables the "Tabbed interface" toggle
   (`entryconfigure {Tabbed interface} -state disabled`, xinit.c:1726, 1852), so
   you are locked into whichever mode you started in.

The hard part — independent contexts, X windows, GCs, the full windowed path —
is **done**. This spec is about relaxing those three assumptions.

## Design

### Model: a "window group" owns tabs

Introduce an explicit grouping. Each top-level window is a **group** identified by
its toplevel path (`.` for the main window, `.x1`, `.x2`, … for extras) and its X
window id. Each schematic context belongs to exactly one group. A group with one
context shows no tab strip; a group with N contexts shows a tab strip with N tabs.

This is the single most important invariant: **a tab renders to its own group's
window, never to `save_xctx[0]->window`.** Everywhere a tab currently assumes the
main window/canvas/tab-bar, it must instead use *its group's* window/canvas/tab-bar.

Concretely, each context already stores `top_path` and `current_win_path` in
`Xschem_ctx` (xschem.h:1222). The group key is `top_path` (`""`/`.` for main).
The per-group tab bar moves from the single `.tabs` to one bar per toplevel
(`.tabs` for main, `.xN.tabs` for extras — `build_widgets` already builds the
rest of a toplevel's chrome, so it gains a tab bar too).

### Introspection seam (the test anchor)

Add a read-only query so behavior is assertable headless:

```
xschem windows
```

returns a Tcl list, one element per open context:
`{win_path top_path group xwindow current_name}` — where `group` is the owning
toplevel path. Tests assert the **grouping** (which tabs live in which window) and
that detach actually moves a context between groups and changes its `xwindow`.
This is the analogue of `get_inst_lcv` in the Library Manager spec — a tiny query
that makes an otherwise GUI-only behavior unit-testable.

### Operations (new `xschem new_schematic` verbs / options)

1. **Force window even in tabbed mode.**
   `xschem new_schematic create_window <win_path> <file> [dr]` — always runs the
   `create_new_window` path regardless of `tabbed_interface`. `load_new_window`
   gains an option: `xschem load_new_window -window [f]`. The Library Manager
   "New window" checkbox routes through this, so it finally opens a real window.

2. **Detach a tab to a new window.**
   `xschem new_schematic detach <win_path>` — takes an existing **tab** context and
   re-homes it into a fresh toplevel: build the toplevel + widgets, get its X
   window id, **repoint** `xctx->window`, **recreate** GCs against the new window
   (`create_gc` after freeing the old set), reset the pixmap (`resetwin`), move the
   key/mouse bindings (`set_bindings`, `set_replace_key_binding`), remove the old
   `.tabs.xN` button, and add the context to the new group. The context's data is
   untouched — only the render target changes. If the source group is left with one
   context, its tab strip hides.

3. **Re-attach / move a tab between windows.**
   `xschem new_schematic attach <win_path> <dest_top_path>` — the reverse: re-home a
   context into an existing group, rebinding window/GCs/bar. The drag gesture
   (dropping a tab onto another window's strip, or tearing it off) builds on the
   existing `swap_tabs` / `tab_context_menu` machinery (xinit.c:1870-1872).

### Mode toggle

Relax the lock (assumption 3): the "Tabbed interface" menu item stays enabled, and
a tab→window or window→tab conversion is just detach/attach applied to the current
context. "Tabbed interface" becomes the *default placement* for new schematics, not
a one-way global mode.

## Acceptance / tests

Headless, X required (creates toplevels), `tests/headless/` harness
(`check name ok detail`, `fail` counter), run via
`DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_multi_window.tcl`:

- **MW1** `xschem windows` lists exactly the open contexts with correct
  `group`/`xwindow` (baseline: one entry, group `.`).
- **MW2** `xschem new_schematic create_window …` makes a real toplevel: the new
  drw's `[winfo toplevel]` is `.xN`, **not** `.`, even with `tabbed_interface=1`.
- **MW3** that window's X id differs from the main window's id (truly separate, not
  the shared canvas).
- **MW4** `xschem load_new_window -window f` opens `f` in a separate toplevel; the
  Library Manager "New window" checkbox routes through it (proc-level check).
- **MW5** create a tab (tabbed mode), then `detach` it: `xschem windows` shows it
  moved from group `.` to a new group `.xN`; its `xwindow` changed; the old
  `.tabs.xN` button is gone.
- **MW6** after detach, a redraw in **both** windows succeeds (`xschem draw` /
  zoom) — i.e. GCs were validly recreated against the new window (no BadDrawable),
  proving the render-target swap, not just a data move.
- **MW7** `attach` moves a detached context back into a target group; `xschem
  windows` reflects the regrouping; both strips update.
- **MW8** mode-lock relaxed: with ≥2 contexts the "Tabbed interface" menu item is
  **not** disabled.

**Not auto-tested (manual eyeball):** dragging a tab across monitors, WM focus
arbitration on detach, geometry of the torn-off window. Per
`doc/claude/specs/library_manager_launch.md`, scripted toplevels are auto-mapped/focused under
WSLg/Xvfb regardless of the code, so those assertions cannot tell bug from fix.

## Reusable building block: the context-borrow primitive

The multi-window **net-highlight animation** work (FAQ Q20;
`doc/claude/suggestions/plan_net_hilight_multiwindow_anim.md`; `doc/claude/specs/net_hilight_styles.md`) added a
small primitive that is **reusable for any background-window redraw**, not just animation:

- **`net_hilight_borrow_ctx(win_path)` / `net_hilight_restore_ctx(saved)`** (`src/hilight.c`)
  repoint the global `xctx` at another open window's context and back, with **no** GUI side
  effects — unlike `switch_window()` it does not raise/focus/retitle or run the Tcl
  `save_ctx`/`restore_ctx`/layer-button machinery. It is the minimal pointer swap, safe to use
  synchronously inside a timer/idle callback. (`net_hilight_win_known(win_path)` tells an
  unknown window from the current one, since the borrow returns NULL for both.)
- **Audit / constraints** (the borrow's `plan` Phase A3): the draw path is `xctx`-relative
  except the **file-scope draw batch buffers** in `draw.c`; a borrow is safe to *draw* only if
  it wraps one **complete, non-reentrant** `draw()`/regional redraw with no `vwait`/`update`
  inside, and never runs while the focused window is **mid-gesture**. Background **tabs** share
  the main `.drw` canvas, so a borrowed redraw of a non-front tab must bail (it would scribble
  the shown tab); only **detached** windows (own canvas) and the front context draw. Gate
  per-window work on **`winfo viewable`**.

Any future feature that needs to redraw or query a non-front window from a single-threaded
callback (live cross-probe markers, background waveform cursors, etc.) should reuse this borrow
rather than reaching for `switch_window()`.

## Out of scope

- Persisting the multi-window layout across sessions (which tabs in which windows,
  geometries) — a follow-on.
- Tearing a tab out by mouse-drag *animation*; the gesture lands as a drop target,
  not a live drag preview.
- Merging two arbitrary running xschem **processes** into one window manager — this
  is all within a single process/interp.
