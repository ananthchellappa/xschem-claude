# 1303 — a Tcl canvas pick reads SNAPPED mouse coordinates and can answer for a device the user did not click

**Status: FILED, NOT FIXED.** Found by item **B4**'s adversary, reproduced
first-hand by B4's write-up agent, and **it is why item B4 was reverted**.
Live in the tree at `735ea26e` in `src/ase_window.tcl`; it was live in B4's
reverted patch too.

## What was measured

`scheduler.c` exposes exactly one mouse-coordinate pair to Tcl —
`mousex_snap` / `mousey_snap` (`:5018`, `:5022`). **There is no unsnapped
accessor.** Measured on this tree:

```
unsnapped accessor exists? [catch {xschem get mousex} m] -> 0 -> ''
```

Every C click path reads the **unsnapped** `xctx->mousex` / `mousey`
(`callback.c:520`, `:530`, `:4305`, `:4471`, and `:4664` — C's own read-only
`find_closest_instance`). So a Tcl pick that defaults to the snapped pair
resolves a **different point** from the one the user's own click resolved.

Reproduced headlessly on the shipped `xschem_library/examples/cmos_inv.sch`,
with `xschem update_all_sym_bboxes` called first:

```
exact  175.175 -199.612 -> 'M1'
snapped 180 -200        -> 'R1'
```

Two different devices, from one pixel. The window names `R1`; the user clicked
`M1`; nothing on screen says which happened.

B4's adversary quantified it by lattice sweep over every instance bbox on that
sheet at the default snap: **23725 points, 1513 (6.4%) miss the device
entirely, 129 (0.5%) resolve to a DIFFERENT device.** Instance bodies are the
bad case precisely because their bbox edges are not on grid, so snapping moves
the point up to half a grid step in each axis — which is exactly the distance
that crosses a boundary.

## Why this is a ruling-shaped defect and not a typo

Invariant **I3** and the `save.c` **D5-1** precedent it cites: *a plausible
wrong number on a schematic is worse than none*. A results window headed
`R1:/` for a click on `M1` is that failure exactly, one object further out —
the number is right for the device named, and the device is the wrong one.

## The shared idiom, live in the tree today

`ase::ui::sod_click` (`src/ase_window.tcl`) has the identical default:

```tcl
if {$x eq {}} { set x [xschem get mousex_snap] }
if {$y eq {}} { set y [xschem get mousey_snap] }
```

**The harm there is not the same and is NOT measured.** ASE Direct Plot picks
nets, wires and source bodies; wires are drawn on grid, so snapping tends to
land *on* the target rather than off it. The mechanism is shared; the measured
consequence above is for **instance-body** picks. Do not quote this issue as
evidence that ASE Direct Plot mis-picks — that has not been driven.

## Options, none taken

* **(a) add an unsnapped accessor** — `xschem get mousex` / `mousey` beside the
  existing pair, two lines in `scheduler.c`. Smallest thing that makes a Tcl
  pick able to agree with C. Costs a C change, which item B4 was not allowed.
* **(b) pass `%x %y` from the binding and convert** — the binding already has
  the pixel; the conversion verb would have to be found or added.
* **(c) wrap the pick in `xschem set no_snap 1` and restore** — the shape
  `ase_window` already uses elsewhere; a mode-global with a restore obligation
  on every error path.

**Recommended: (a).** It is the only one that leaves the caller honest with no
state to restore, and it fixes every future Tcl pick rather than one call site.

## Acceptance, when someone takes it

1. A pick at a pixel resolves the **same** object an ordinary left-click at
   that pixel selects — driven at a point measured to straddle a bbox edge,
   not at a bbox centre. **A fixture that computes click points from
   `xschem instance_bbox` centres cannot see this defect**; that is why B4's
   21-check suite was green while the defect was live.
2. The 175.175/180 pair above, as a regression row.
