# 0647 — the restored waveform viewer opens pixel-coincident ON TOP OF the design window

STATUS: **OPEN — measured 2026-08-23 by the 0616 crew.** Not a regression; it is
how session restore has always behaved. Filed because it produces the *same
user-visible complaint* as issue 0616 ("the schematic is gone") by a different
mechanism, and because 0616's fix depends on working around it.

## Measured

Opening `sky130_tests_ase/tb_bandgap` / `ngspice_state1` — whose committed state
ends with `viewer {open 1 sharedx 0 …}` — on a fresh session,
`ase::ui::viewer_restore` opens the waveform viewer. Immediately after open, with
no user action at all:

```
stackorder = . .ase4 .x1
above: .ase4 rect=1023 60 1821 601   partial/none
above: .x1   rect=13 89 1013 889     partial/none      <- the viewer
design toplevel `.` rect = 13,90 - 1013,890
```

The viewer `.x1` is **1000x800 at +13+89**; the design window is **1000x800 at
+13+90**. One pixel apart, and the viewer is **above** the design in the stacking
order. From the user's seat the schematic is not on screen.

`wviewer::open` uses `new_schematic create_window`, so the viewer is always a
real toplevel and never shares the design's tab; the geometry comes from the
saved state and the WM placed both at the same origin.

## Why it matters

1. **It is a second way to report "the schematic disappeared".** A user who opens
   a saved session and finds no schematic will describe it exactly as issue 0616
   was described, and the fix is completely different.
2. **It is why issue 0616's fix must keep a `raise`.** The first cut of that fix
   removed the withdraw/deiconify re-map from the Netlist-and-Run path
   *entirely*, which also removed the only thing that had been putting the
   schematic above this viewer. Measured: `stackorder` after the run stayed
   `. .ase4 .x1` — still buried. The shipped remedy keeps the cheap half of the
   raise (`raise` + `activate_window`) for exactly this reason.
3. **It also leaves the current context on the viewer** (`current_win_path =
   .x1.drw`), which is what makes `do_run`'s guard fire on a design window that
   needs nothing — the trigger for 0616 in the first place.

## Options (none ratified — this needs the user)

| option | note |
|---|---|
| offset the restored viewer (cascade it) rather than placing it at the design's origin | least surprising; a user can still move it back |
| restore the viewer but leave the **design** on top | matches "the schematic is the thing you are working on" |
| restore the previous **context** after `viewer_restore` (so `do_run`'s guard stops firing spuriously) | narrower: fixes the guard trigger for the first press, but not after a descend or a click in the viewer; touches `test_ase_persist`'s viewer-restore rows |
| leave it alone | it is the geometry the user saved |

## Acceptance

- Opening a saved session with `viewer {open 1 …}` leaves the schematic
  reachable without a menu detour, *or* the placement is a deliberate ratified
  choice recorded here.
- If a fix restores the context, `test_ase_persist`'s viewer-restore rows are
  re-checked.
