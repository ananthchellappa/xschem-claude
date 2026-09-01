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

---

## THE SEPARATING MEASUREMENT WAS TAKEN — 2026-08-26. It is the SECOND arm.

The section above names the measurement that splits this issue in two, and says
the user can do it. They did, with the assistant, on their own VcXsrv. **Nothing
is there.** The viewer is mapped-but-unrendered, and the fragments are all that
was ever drawn of it. This is **not** a repaint defect in xschem, and the
`force_window_repaint` / issue 0052 lead above is the wrong tree.

### 1. The X server and Windows disagree about how many windows exist

The census (`window_report`) and `xwininfo` both reported **five** toplevels with
the viewer `IsViewable`. A PowerShell `EnumWindows` sweep of the `vcxsrv` process
found **four** native Windows windows, and no viewer among them. The user
independently confirmed the same count from the taskbar: CIW, Library Manager,
ASE-L, schematic — no waveform window.

So under `-multiwindow`, **an X window can be `IsViewable` with no native Windows
window behind it.** No native window means no taskbar button and no pixels of its
own. The window exists only inside the X server.

### 2. The visible fragment is exactly the geometric intersection

Recorded at each observation, with the user reporting what they saw before the
arithmetic was done:

| | viewer rect | intersection, viewer-relative | user saw |
|---|---|---|---|
| before | `1110x790+3930+665` | x 0–740, y 0–538 | "top-left quadrant" |
| after `wmctrl` move | `1110x790+3000+700` | x 560–1110, y 0–503 | "top-right quadrant" |

Schematic window `1110x791+3560+412` (x 3560–4670, y 412–1203) throughout.

Both match. **The fragment tracks the orphaned X window when it moves, in the
right direction, by the right amount.** VcXsrv renders that window's content into
the shared screen framebuffer at its absolute coordinates, and it becomes visible
only where a *real* native window overlaps and paints. Clicking the schematic
makes xschem repaint the region, which is why the fragment wipes — a raise, not a
repair.

### 3. What this changes

- **Root cause is NOT understood.** Why VcXsrv fails to create the native window
  on some launches and not others is unknown, and it is not repeatable: four
  sittings produced four arrangements. The user's standing instruction, verbatim,
  is *"Don't 'fix'. We don't know root cause. It appears to be a VcXsrv failure."*
- **It never reproduces on WSLg** (`DISPLAY=:0`), reported by the user. Consistent
  with the mechanism: Xwayland is not creating native Win32 windows at all.
- **Issue 0848's fix stands on its own evidence** (`switch_no_tcl_ctx` silently
  no-opping for the main window was a real defect, two bugs in series) but it is
  **not** the cause of what the user saw here, and any note implying otherwise is
  wrong.
- **The `wviewer::uncover` far-edge clamp (commit 5fff9f77) is NOT this fix.** It
  corrects a genuine overhang measured along the way and is justified by its own
  row (U4b); it does not address this issue. Its comment says so explicitly.
- An upstream VcXsrv bug report is **drafted and NOT filed**.

### 4. The "Do not" above still stands, and now has a second clause

⚠ Do not fix this by moving the viewer further away — unchanged. And ⚠ **do not
add repaint treatment to the viewer-open path on the strength of this issue**: the
measurement says there is nothing to repaint. A repaint workaround here would be
a change that cannot help, shipped against evidence, and it would make the real
mechanism harder to find the next time someone reads this file.
