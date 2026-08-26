# 0840 — the Waveform Viewer opens EXACTLY over the design window, because it restores the design window's own geometry out of the `untitled.sch` slot

Status: **FIXED 2026-08-26** (the congruence). Two residuals below are **OPEN and
NOT REPRODUCED**. Reported by the user 2026-08-26 on the real screen; root cause
measured on Xvfb + openbox 3.6.1, where it reproduces exactly.
Related: 0680 (VcXsrv compositing — **not** the cause here), 0616, 0172.

⚠ **THIS ISSUE'S FIRST DIAGNOSIS WAS WRONG AND HAS BEEN REPLACED.** It said the
two toplevels *"commonly"* land in the same spot on a WM default placement, and
attributed the duplicated taskbar preview to VcXsrv's composite redirection. Both
were guesses. The overlap is not common, it is **exact and every session**, it
has a specific cause in this tree, and it reproduces under a completely different
window manager on a completely different X server. The user's second report is
what broke the wrong theory open — see *"What killed the first diagnosis"*.

## The user's reports, verbatim

First:

> ASE-L is launched and (sometimes) so is a Waveform Viewer window … Sometimes,
> it's as if this waveform viewer "replaces" the schematic window … I can drag
> the Waveform viewer window and that reveals the schematic.

Second, and much sharper:

> The schematic window appears to get replaced by a Waveform Window - but there
> is no additional icon on taskbar. The title is still "Xschem [..". If I click
> in the "Waveform viewer", it turns into a schematic window. There is no
> Waveform Viewer window. If I press Ctrl-W to close it, the title changes to
> "Xschem [5] - untitled.sch (read-only)" and the display is again a waveform
> viewer with two empty strips …
>
> Note that untitled.sch - the default for empty Schematic editor - should never
> be read-only.

## What killed the first diagnosis

*"If I click in the Waveform viewer, it turns into a schematic window"* cannot
happen to two overlapping toplevels. That is one canvas showing the wrong
content, or two windows so exactly congruent that the user cannot tell which one
they clicked. It sent the investigation to the window model instead of to the
window manager, which is where the answer was.

## Measured — the toplevels are congruent to the pixel

Probe: load `tb_bandgap.sch`, open the session, call `wviewer::open`, dump every
toplevel. On `:99` with openbox 3.6.1:

```
NEW  .x1  Toplevel  state=normal mapped=1  geom=1110x761+404+132
          title='Waveforms tb_bandgap (ngspice_state1)'
MAIN .              state=normal mapped=1  geom=1110x761+404+132
          title='xschem [3] - tb_bandgap.sch'
```

**Same size, same position, both mapped.** Not "commonly the same spot" —
identical. The viewer's own title is correct, so nothing is confused about what
it is; it is simply placed on top of the design window with 100% coverage.

## Root cause — a shared geometry slot, holding the WRONG window's geometry

`store_geom` / `set_geom` (`src/xschem.tcl`) key a window's saved geometry by
`[xschem get current_name]`, persisted in `$USER_CONF_DIR/geometry`. The
waveform viewer is built on a schematic buffer named **`untitled.sch`** — the
same name every untitled scratch buffer carries. One slot, many windows.

And the numbers in that slot are **the main window's own**, which is why the
overlap is exact rather than merely likely, and why it happens every session:

1. xschem starts with `untitled.sch` in the main window;
2. the user loads a schematic — and the load path stores geometry **first**:
   `store_geom [xschem get topwindow] [xschem get current_name]`
   (`src/scheduler.c:7656`) runs with `current_name` still `untitled.sch`, so the
   **main window's** geometry lands in the untitled slot;
3. `wviewer::open`'s buffer is `untitled.sch` too, so `set_geom` hands it
   straight back.

The user's own `~/.xschem/geometry`, which is what made this legible:

```
sky130A/.../tb_bandgap.sch   1110x761+404+132   1787767602
untitled.sch                 1110x761+404+132   1787767601
```

Two entries, one second apart, identical geometry. The second one is the trap.

It also explains the `untitled.sch (read-only)` title the user objected to: the
viewer buffer genuinely **is** `untitled.sch`, and `xschem set readonly 1`
(`wave_viewer.tcl`, decision D1 — the viewer buffer must never be modifiable, so
no save prompt can appear on close) rewrites the WM title into that form. The
read-only is correct and deliberate. The **name** is what is wrong, and the user
is right that it reads as nonsense.

## As fixed

`wviewer::geom_key` gives the viewer its own slot, `__waveviewer__`, and
`store_geom`/`set_geom` consult it. Keyed by the **toplevel path**, not the
context: `store_geom` runs from C at moments when the current context belongs to
somebody else, so a per-context flag cannot answer *"whose window is this"*.
(The viewer already marks its context — `xschem set wave_viewer 1`, issue 0172,
for exactly this family of confusion. Geometry never got the memo.)

The **read** half is the load-bearing one. Under the tabbed interface
`store_geom` is main-window-only (`if {$win eq {.} || $tabbed_interface eq 0}`),
so a viewer never writes the slot at all; the write half matters in the
non-tabbed model, where the viewer would otherwise overwrite `untitled.sch` with
its own place and move the next `File > New`. Row **K0** pins that asymmetry so
nobody "fixes" K1 by widening `store_geom`.

`wviewer::uncover` is the deterministic backstop for the **first** open, when no
viewer geometry is stored yet and placement falls to the window manager: if the
new viewer landed exactly congruent with the window it was launched from, step it
by 48px, back toward the origin near a screen edge so the title bar stays
reachable. Congruence is the defect; proximity is not, and row **U2** pins that
it leaves a merely-nearby window alone.

Measured after: `+452+180` against the main window's `+404+132`.

`tests/headless/test_wave_viewer_geometry.tcl`, 15 checks, ALL PASS. Sabotages:

| | | |
|---|---|---|
| SB1 | `set_geom` key swap removed | K3 red |
| SB2 | `store_geom` key swap removed | K1 red |
| SB3 | `geom_key` claims every window | G2, K2, K4 red |
| SB4 | `uncover` neutralised | U1, U4 red |
| SB5 | `uncover` moves a non-congruent window | U2 red |

SB3 and SB5 are the over-reach directions; both are caught.

## STILL OPEN — measured as unreproduced, not as absent

1. **TWO viewer windows existed in the user's session.** They closed one with
   Ctrl-W and found another behind it. `/tmp/Xschem.log.5` corroborates it:
   `xschem new_schematic destroy .x1.drw` appears **twice**. `wviewer::open` is
   per-token idempotent (the re-open arm raises the existing window and returns),
   so a duplicate needs the registry entry to have been lost, or a second entry
   point. **Not reproduced** on the dev display.
2. **The second window's title was `untitled.sch (read-only)`, not
   `Waveforms …`.** `wave_viewer.tcl:791` exists precisely to re-assert the
   viewer title after every `xschem set readonly` toggle, because that verb
   rewrites the WM title. A window showing the un-asserted form is one whose
   `open` got as far as `xschem set readonly 1` and no further. Consistent with
   residual 1 and probably the same defect.
3. **`ase::ui::viewer_restore` opened NO viewer at all on the dev display**,
   although the state file carries `viewer {open 1 …}` and the user gets one every
   time. The registry came back empty. That discrepancy is unexplained and is the
   most promising thread for residuals 1 and 2 — the path that really opens the
   user's viewer is not the one a direct `wviewer::open` exercises.
4. **The name.** The user's point stands on its own: a buffer presented to the
   user as `untitled.sch` should not be read-only, and if the viewer is going to
   borrow the untitled machinery it should at least not borrow the **name**.
   Whether the fix is a distinct buffer name or a suppressed title is an
   unratified user-visible decision — `rule` debt.
