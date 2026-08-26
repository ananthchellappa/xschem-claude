# 0844 — fragments of the waveform strips appear ON other windows, where the viewer overlaps them

Status: **OPEN — reported by the user 2026-08-26 with a corroborating trace; not
reproduced.** Newly VISIBLE as a consequence of fixing issue 0840: the viewer no
longer covers the design window 100%, so the region where it overlaps is now on
screen instead of hidden. Related: 0840, 0052 (deferred repaint), 0680.

## The user's report, verbatim

> This time, I see fragments of the waveform strips being rendered on the other
> windows - like ASE-L and the schematic editor, but there's no other window.
> (this is after I double click on ngspice_state1 to launch ASE-L)

## Measured — the geometry, from the user's own action log

`/tmp/Xschem.log.6`, at `open-RETURN`:

```
.      1000x800+3713+296   'xschem [3] - tb_bandgap.sch (read-only)'
.ciw    659x292+2594+57    'xschem CIW - /tmp/Xschem.log.6'
.libmgr 760x460+2646+109   'Library Manager'
.ase4   791x524+2672+135   'Analog Sim Environment tb_bandgap'
.x1    1000x800+2964+132   'Waveforms tb_bandgap (ngspice_state1)'
```

Spans on the x axis:

| window | x range |
|---|---|
| `.ase4` | 2672 – 3463 |
| `.x1` (viewer) | **2964 – 3964** |
| `.` (design) | 3713 – 4713 |

`.x1` overlaps `.ase4` over 2964–3463 and `.` over 3713–3964 — **exactly the two
windows the user reports fragments on, and no others.** The fragments are in the
overlap regions.

## What this is NOT

* **Not the 0840 congruence bug.** That is fixed and the same log proves it:
  `.` at `+3713+296` and `.x1` at `+2964+132` are no longer identical.
* **Not a missing window.** `.x1` is `normal` (mapped), 1000x800, at a real
  position, with the correct title. The user's *"there's no other window"* is the
  puzzle, not a contradiction: the window exists and is mapped, so either it is
  somewhere they are not looking on a very wide desktop (their coordinates run
  past x=4700, so this is a multi-monitor setup) or it is mapped and not
  rendering.
* **Not a viewer-open failure.** The trace is clean end to end:
  `open-ENTER` → `open-FRESH` → `open-RETURN`, one registry entry, correct final
  title. Issue 0840's residuals 1 and 2 did **not** occur on this run.

## The hypothesis, and the one measurement that separates the two

Overlapping X windows without a compositing window manager rely on **expose
events** to repaint damaged regions. The user runs VcXsrv with `-nocompositewm`
(issue **0680**, where compositing was disabled because it exhausted GDI handles).
So a window that does not repaint its damaged region on expose leaves whatever
was painted there before — which, in the overlap, is the viewer's strips.

There is already a named workaround for this family in the tree —
`force_window_repaint`, issue 0052, applied via `after 120` after a load — which
suggests deferred/missed repaint is a known behaviour of these servers and that
the viewer-open path may simply be missing that treatment.

**The separating measurement is cheap and the user can do it**: look at
`+2964+132`, where the viewer actually is. If a proper waveform window is sitting
there, the fragments are pure repaint damage on the *other* windows. If nothing
is there, the window is mapped-but-unrendered and the fragments are all that was
ever drawn of it — a different defect with a different fix.

## Do not

⚠ **Do not "fix" this by moving the viewer further away** so the overlap stops.
Overlapping windows are normal and every other application handles them; a fix
that works by avoiding overlap would hide the repaint defect until two windows
happened to overlap again.
