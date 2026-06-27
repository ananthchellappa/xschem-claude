# Issue 0052 — Library Manager open leaves the target window blank (and tab stale) until the user interacts

**Opened:** 2026-06-27
**Status:** OPEN
**Severity:** MEDIUM — confusing display wedge on WSLg; the schematic looks like it failed to open.
No data loss (state is correct; only the on-screen paint is missing).
**Branch:** `fluid-editing`.
**Source:** user report (`src/xschem --script src/cadence_style_rc --logdir /tmp`, Library Manager →
open a cell Read-Only).
**Affects:** `src/library_manager.tcl` `libmgr::open_view` (the `xschem load` / `load_new_window`
calls at ~:453/:456) and `open_view_ro` (~:521). Same WSLg "no settling event → blank until resize"
family as the new-window backstop `newwin_defer_fullzoom` (`src/xschem.tcl:5332`) and issues
0035/0037/0049. Related: [[multi-window-detach]], [[library-git]], [[reopen-readonly]].

---

## 1. Symptom

Launch `src/xschem --script src/cadence_style_rc --logdir /tmp` (tabbed interface, Library Manager
auto-launched). In the Library Manager, open a cell — e.g. **Open (read-only)**. The main xschem
window's **title bar** updates to the cell name, but:

- the **tab title** does not update, and
- the **schematic elements are not drawn** (blank canvas).

The instant the xschem window is interacted with — activate it, or move the mouse pointer into it —
everything snaps to normal (tab renamed, schematic painted).

## 2. Root cause

The open succeeds completely: the schematic loads, `draw()` runs (drawcount increments), the tab
button text is set to the new cell name, and the window title is refreshed. Verified headless — after
`libmgr::open_view_ro`: `tab_text` goes `untitled.sch → demo.sch`, `drawcount 2 → 3`,
`schname=demo.sch`, `readonly=1`. So **all state is correct; only the on-screen paint is missing.**

The reason is the WSLg display quirk already documented for new windows (`newwin_defer_fullzoom`,
issues 0035/0037): WSLg repaints a window only after it processes an X event for it. A load driven
from the **persistent Library Manager dialog** draws into the xschem window while that window does
**not** have focus (the dialog keeps it), and WSLg never delivers the expose/configure that would
flush the paint — so the canvas (and the Tk tab-button repaint) stay stale until the user moves the
pointer in (an `EnterNotify`) or activates it (a `FocusIn`). A File-menu open does not show this
because its file dialog closes and returns focus to the main window, which triggers the repaint.

Note: this is **not** specific to read-only — `open_view_ro` just calls `open_view` (the load) then
`xschem set readonly 1`. A plain editable Library Manager open has the same blank-until-interaction
behavior; the user happened to hit it via Read-Only. On the first open the load also reuses the
pristine untitled `.drw` in place (untitled-reuse) via `xschem load`, so the stale window is the
already-mapped main window — `pending_fullzoom` is 0 and the existing new-window backstop
(`_newwin_fit_fullzoom`, which early-returns unless a full-zoom is pending) does not cover it.

## 3. Fix

After a Library Manager open, force the same work a resize/expose would do on the target window, from
a timer (so it runs in the event loop — which is what makes WSLg flush). Add a small shared helper
`force_window_repaint $win` (sibling of `newwin_defer_fullzoom`) that, once the window is realized,
calls `xschem resetwin <w> <h>` — recreate the backing pixmap + redraw, performing the armed full-zoom
if any. Unlike `_newwin_fit_fullzoom` it does **not** require a pending full-zoom, so it also repaints
an in-place reuse load (where nothing is zoom-pending and the load already fit the view). Call it from
`libmgr::open_view` after both the `load` and `load_new_window` branches.

Behavior by sub-case (one helper covers both):
- **In-place reuse** (`xschem load` into `.drw`, `pending_fullzoom==0`): `resetwin` repaints at the
  current (already-fit) zoom — view preserved, just painted.
- **Forced new window** (`load_new_window -window`, `pending_fullzoom` armed by window creation):
  `resetwin` consumes the pending full-zoom against the settled geometry, then paints.

Cheap, invisible no-op on a normal X server (the window already painted); the existing
`newwin_defer_fullzoom` runs unconditionally on all platforms the same way, so this is the accepted
pattern.

## 4. Acceptance

Library Manager → Open / Open (read-only) of a cell paints the schematic and updates the tab title
immediately, with no need to move the pointer into or activate the window — for both the first open
(untitled-reuse, in-place) and subsequent opens (new window/tab). Editable opens behave identically.
A normal File-menu open is unchanged.
