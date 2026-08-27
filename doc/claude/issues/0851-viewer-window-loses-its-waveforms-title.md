# 0851 — the waveform viewer loses its title and stops looking like a viewer

Status: **FIXED 2026-08-26.** Reported by the user from their own VcXsrv session, with
the evidence in their action log. Surfaced by issue 0848; the defect predates it.
Related: 0172 (the `wave_viewer` brand), 0848.

## The report, and why it was phrased the way it was

> *"Here's a case where there is no waveform window, but a fragment of it is painted
> within the schematic window."*

There **was** a waveform window — mapped, on top, at `+3875+545`. It had stopped saying
so. Their `window_report` censuses, 700 ms apart, from one viewer open:

```
viewer-open    .x1  1000x800+3875+545  'Waveforms tb_bandgap (ngspice_state1)'
viewer-open+   .x1  1000x800+3875+545  'xschem [5] - untitled.sch (read-only)'
```

Same window, same geometry, same stacking position. Renamed.

## Mechanism

`set_modify()` (`actions.c`) re-derives a toplevel's title from the schematic name. A
viewer's buffer **is** `untitled.sch` by construction, so any path that lands
`set_modify()` on a viewer context renames it. `wviewer::retitle` is the owner of that
title; nothing told `set_modify()` to keep its hands off. This is the same
surface-vs-document distinction the `wave_viewer` brand was added for in issue 0172,
applied one field further.

**Issue 0848 is what made it reachable.** Before that fix the redraw-only restore hit
`switch_window()`'s *"already there"* early return and never called `set_modify(-1)`.
Once the forward switch really happened, the restore had somewhere to come back *from*,
called `set_modify(-1)` on the viewer, and took the title with it.

Fix: `set_modify()` leaves the title alone when `xctx->wave_viewer` is set.

## ⚠ The trigger is NOT `xschem set_modify`

Measured, with the guard removed and the viewer context asserted current: driving that
verb at `-1`, `0`, `1`, `2` and `3` never changes the title. Three rows written on that
assumption were **hollow — they passed under sabotage — and were deleted rather than
shipped**:

* switch context away and back, then read the title (nothing re-derives it there);
* drive `xschem set_modify` on the viewer;
* the mirror of that on an ordinary window.

Worse, one intermediate version *appeared* to work: removing the guard reddened `G3` in
`test_wave_viewer`. That was an artifact — the hollow rows' own context switching
perturbed the state `G3` later observed. With them removed, `G3` passes under the same
sabotage. **The suite had no coverage of this at all**, and briefly looked as though it
did.

The real trigger is `callback()`'s Expose handling: the redraw-only switch to another
window and the restore back.

## Tests — `tests/headless/test_viewer_title.tcl`, 7 checks

Isolated on purpose: bolting the synthetic Expose into `test_wave_viewer` destabilised
that 404-check suite (it died at 62).

Two windows, one branded a viewer and titled like one, then a real Expose delivered with
`xschem callback <win> 12 …`. T4/T6 are preconditions-as-rows: if the expected context
is not current, the restore lands elsewhere and the check would pass while measuring
nothing.

| sabotage | reds |
|---|---|
| remove the `wave_viewer` title guard | **T5**, with the user's exact symptom: `xschem [4] - untitled.sch` |
| widen the guard to every window | **T6** |

T6 has to *force* a re-derive — corrupt the title, then run the same Expose path in the
other direction. Reading a title that is already correct passes even with the guard
widened to everything; measured.

## What this issue does NOT claim

It does not claim the canvas-corruption half (0848) is fixed on the user's VcXsrv. That
was verified on Xvfb only, and saying "fixed" without their display was over-stated. The
outstanding `test_expose_repaint` suite debt asks for `AUDIT_DISPLAY=$DISPLAY`.
