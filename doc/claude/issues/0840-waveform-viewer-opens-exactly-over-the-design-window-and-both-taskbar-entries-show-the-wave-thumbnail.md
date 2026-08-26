# 0840 — the Waveform Viewer opens exactly ON TOP of the design window, and BOTH taskbar entries show the waveform thumbnail

Status: **OPEN — observed by the user 2026-08-26 on the real screen (VcXsrv over
TCP), not reproducible on Xvfb by inspection.** Severity: medium — nothing is
lost, but the design window appears to have vanished and the taskbar actively
misleads about where it went.
Related: 0616 (`ifhidden` vs `always` remap), 0680 (VcXsrv compositing).

## The user's report, verbatim

> ASE-L is launched and (sometimes) so is a Waveform Viewer window with empty
> strips for v(x1.net3) and v(x1.x1.net6). Sometimes, it's as if this waveform
> viewer "replaces" the schematic window - because, hovering on taskbar icons
> doesn't show another window. If I (in the "replaces" case) click in the
> schematic window, I get back the schematic.
>
> … I get the "replace" case - where the schematic window seems to be replaced by
> a Waveform Viewer. Hovering on the (there are two taskbar icons - one says
> "Xschem [3]", the other says Waveforms, but they both give the same thumbnail -
> empty waveform viewer with two strips). I can drag the Waveform viewer window
> and that reveals the schematic.

## What is actually happening

Nothing is destroyed. The waveform toplevel is being placed at (or very near) the
design window's geometry and stacked above it, so it **occludes** it exactly.
Dragging it aside reveals the schematic, and clicking through returns to it —
both consistent with occlusion, neither consistent with a window being replaced,
reparented or closed.

**The taskbar is the part that turns a cosmetic overlap into a real usability
defect.** Two entries exist (`Xschem [3]` and `Waveforms`), so the window manager
knows there are two toplevels — but both preview the *same* content. Under
VcXsrv the thumbnail is captured from the screen region the window occupies, so
a fully-occluded window previews whatever is on top of it. The user therefore has
no way to tell, from the taskbar, that the design window is still there. Hovering
is precisely the gesture that should have resolved the confusion and it confirms
the wrong thing.

⚠ **This is the same server whose compositing produced 0680.** VcXsrv's
composite-redirection path is what makes thumbnails possible at all, and 0680
already established that its handle accounting is unsound (507 → 10000 GDI
handles in 11 s, zero releases; worked around with `-nocompositewm`). Whether the
duplicate thumbnail persists with `-nocompositewm` in force is **unmeasured** and
is the first thing to check — if it does not, the taskbar half of this issue is
0680's and not ours.

## Two things to separate

1. **Placement.** The waveform viewer should not open exactly over the design
   window. It has no geometry of its own to restore on a first open, so it lands
   on the WM's default placement, which for a same-size toplevel from the same
   client is commonly the same spot. An offset, a size difference, or a saved
   geometry all fix this and none of them require knowing anything about VcXsrv.
2. **Stacking / focus.** It also comes up *above* the design window on a gesture
   (`double-click ngspice_state1`) whose subject is the **session**, not the
   waves. Whether a viewer with **empty strips** deserves to be the top window at
   all is a design question, not a bug — see below.

## The empty strips are their own question

The viewer opens showing `v(x1.net3)` and `v(x1.x1.net6)` as **empty** strips —
a restored strip target with no data behind it. `/tmp/Xschem.log.4` records
`wviewer::set_target_strip 1 sky130_tests_ase/tb_bandgap/ngspice_state1`, so this
is deliberate state restore, not an accident. It is defensible; it is also the
weakest possible thing to put on top of the user's schematic.

## Proposed behaviour (UNRATIFIED — `rule` debt)

Opening a session should leave the **design window** on top, with the waveform
viewer restored but behind, or offset so both are visible. The user's own
standing position on a neighbouring question — *"the CIW should be raised (though
not necessarily steal focus)"* — points the same way: restore the furniture,
raise the thing the gesture was about.

## Acceptance

1. Double-clicking `ngspice_state1` with a saved wave state leaves the schematic
   visible — not occluded — without the user dragging anything.
2. `Session > Design Window` still works and is still the seam that *opens* one
   (0616's rule: never remap on a routine action).
3. Measured on **VcXsrv over TCP** (`AUDIT_DISPLAY=$DISPLAY`), because `:0` is
   Xwayland and `:99` is Xvfb and neither has this taskbar.

## Still open

* **Unmeasured under `-nocompositewm`** (see the ⚠ above). Do this first; it may
  reassign the taskbar half of this issue to 0680.
* **"sometimes"** — the user says the viewer sometimes opens and sometimes does
  not, and sometimes occludes and sometimes does not. The condition is not
  identified. `/tmp/Xschem.log.9` has no `wviewer::set_target_strip` line and
  `/tmp/Xschem.log.4` does, which is a starting thread.
