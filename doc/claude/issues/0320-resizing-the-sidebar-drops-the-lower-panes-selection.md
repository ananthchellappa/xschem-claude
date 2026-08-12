# 0320 — resizing the sidebar drops the lower pane's selection

**Status:** OPEN. Not fixed. Found while fixing issue 0318 (fixed by 95a7e3ce); deliberately NOT
widened into it (0318's brief: a further door onto "a geometry event is treated
as navigation" gets its own issue).
**Area:** `src/wave_viewer.tcl` — `browser_sea_configure` → `browser_sea_refresh`
(the `set browserseasel($token) {}` / `set browserseaanchor($token) 0` pair) vs
`browser_sea_select`.
**Found:** 2026-08-12, by reading, while issue 0318 was being fixed.
**Related:** issue 0318 (the same `<Configure>` door, a different casualty — the
F5 notice; FIXED), issue 0312 (whose grip makes this trivial to hit), issue 0313
(same family: a non-navigation event treated as a navigation).

## What happens

Select signals in the signal browser's LOWER pane (click one, shift-click or
ctrl-click more — the pane's selection is a SET, spec R4/§5.3). Now change the
sidebar's width: drag issue 0312's grip, drag the sash, resize the toplevel, or
let a window manager tile the window.

**The selection is gone.** Not re-drawn somewhere else — cleared. The selection
rectangles disappear and any gesture that acts on "the selected cells" (Plot to,
Send to Add Trace, Copy name, Descend to here) has nothing to act on. The user
changed how wide the pane is and asked for nothing.

## Why — the same one line as 0318, one field over

`browser_sea_refresh` rebuilds the pane's model and then resets both selection
fields unconditionally:

```tcl
  set browsersea($token) $pairs
  set browserseasel($token) {}
  set browserseaanchor($token) 0
```

That is right for a NAVIGATION — a new node's pane has different cells, and an
index set carried across would select whatever now happens to sit at those
indices, which is worse than selecting nothing. It is wrong for GEOMETRY: the
canvas's `<Configure>` is wired into `browser_sea_configure`, which calls the
same refresh, and a resize does not change WHICH names the pane lists — only how
they flow into columns. The indices stay valid; only their pixels move.

Issue 0318 fixed this exact shape for `browserseanote` by giving the geometry
caller a `keepnote 1` argument and leaving the default at "navigation". The
selection was left alone on purpose: it is a second ruling (does a resize keep
the selection?), it wants its own check, and 0318's scope was the reported
symptom.

## Reachability

Every door 0318 lists, because it is the same door: the width grip, the sash, the
toplevel resized, the tab bar appearing, a WM tiling the window. Before issue
0312 the sidebar had no draggable edge, which is why nobody hit it by hand.

Note the tree's selection is NOT affected — `ttk::treeview` owns its own and a
resize does not touch it. So after a drag the two panes disagree: the tree still
shows the node, the pane below it has silently forgotten what the user picked.

## Fix, when someone takes it

The cheap shape is already built: `browser_sea_refresh` takes `keepnote`; a
`keepsel` beside it (or one argument meaning "this is geometry, not navigation")
would cover both fields with one classification, and the `<Configure>`
trampoline is still the only geometry caller. The check has to READ THE DRAWN
`selbox` ITEMS as well as `browser_sea_selection`, for issue 0318's reason: the
model is what survives, the rectangles are what the user sees.

⚠ **Decide the ruling first.** "A resize keeps the selection" is the obvious
answer, but the pane's selection is INDEX-based, so the fix must state what
happens if the model ever changes under a geometry event (it cannot today —
`browser_sea_layout` re-flows the same `browsersea` list — and a check should
pin that it cannot).

## Measurement

*Owed.* The mechanism above is read off the source (one unconditional write, one
geometry caller reaching it) and the GUI test panel was PAUSED when this was
written, so the drag was not driven. The probe is small: seed the sea fixture of
`tests/headless/test_wave_sigbrowser_0318.tcl`, `browser_sea_select` two cells,
read `browser_sea_selection` and `$c find withtag selbox`, drag the grip, read
both again.
