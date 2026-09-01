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

## The instrumentation, and what it already showed

`wviewer::diag` (opt-in, `WVDIAG=1`) traces every entry, arm and exit of
`wviewer::open`, plus `forget` and `viewer_restore`, and dumps every mapped
toplevel with its title and geometry at each point.

⚠ **It writes through `xschem log_action`, into the ACTION LOG, not a file of
its own.** The first version opened `/tmp/wvdiag.log` and under the user's own rc
the `open` itself failed, so the trace came back silently empty — which looks
exactly like *"the event never happened"*, the one thing a diagnostic must never
look like. The action log is already produced by the user's `--logdir /tmp` run,
so the trace lands in the file they ALREADY send. `#= ` is the shipped
non-replayable-comment prefix (`util.c:538`), so the log stays source-able.
(Note `--pipe` gates the action log, so this cannot be exercised from a scripted
run — it was verified with an interactive-shaped `--logdir` run.)

**It has already localised residual 2.** Trace of a clean open on the dev
display:

```
#= wvdiag open-FRESH   token=…/ngspice_state1 top=.x1 ctx=.x1.drw registry={…}
#=        .x1 normal 1110x761+452+180 'xschem [4] - untitled.sch (read-only)'
#= wvdiag open-RETURN  token=…/ngspice_state1 top=.x1 ctx=.x1.drw registry={…}
#=        .x1 normal 1110x761+452+180 'Waveforms tb_bandgap (ngspice_state1)'
```

So the `untitled.sch (read-only)` title is not a rare corruption — **it is the
window's NORMAL state for most of `open`**. `xschem set readonly 1` runs early
(it rewrites the WM title as a side effect), and `wviewer::retitle` runs at
`wave_viewer.tcl:1373`, near the end. Everything between the two is a window in
which the viewer wears the wrong name.

**Which yields one hypothesis for BOTH residual 1 and residual 2**: an exception
somewhere in that span.

* thrown **before** `dict set windows` → an orphan toplevel that is in no
  registry, so `forget` cannot see it, the re-open arm cannot find it, and the
  next `wviewer::open` builds a **second** window → residual 1;
* and that orphan has `readonly` set and was never retitled → residual 2.

The trace distinguishes the two cases without any guessing: an `open-ENTER` with
no matching `open-FRESH` means it threw before the registry entry; `open-FRESH`
with no `open-RETURN` means it threw after.

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

---

# ADDENDUM 2026-08-26 — the shove had THREE reasons not to work, and the third was the real one

The user's `window_report` census (`/tmp/Xschem.log.2`) finally made this measurable
instead of anecdotal. Two censuses, 700 ms apart, from one viewer open:

```
#= window_report viewer-open  ...
#=   .     stack=2  normal  1110x761+3628+358  'xschem [3] - tb_bandgap.sch (read-only)'
#=   .x1   stack=5  normal  1110x761+3676+406  'Waveforms tb_bandgap (ngspice_state1)'

#= window_report viewer-open+ ...
#=   .     stack=2  normal  1110x761+3628+358  'xschem [3] - tb_bandgap.sch (read-only)'
#=   .x1   stack=5  normal  1110x761+3628+358  'Waveforms tb_bandgap (ngspice_state1)'
```

`+3676+406` is `+3628+358` plus exactly 48 in both axes — **the shove fired.** And 700 ms
later the viewer is pixel-identical to the design window again. The shove was not missing;
it was being **undone**.

## The third reason: `raise_activate_toplevel` re-maps, and a re-map forgets

Traced by intercepting every Tcl-side `wm geometry` during a real
`ase::open_state sky130_tests_ase tb_bandgap ngspice_state1` on `:99`:

```
#= GEO SET .x1 -> 1110x740+0+285   (from: raise_activate_toplevel)
```

`raise_activate_toplevel` performs issue 0054's WSLg idiom — `wm withdraw` then
`wm deiconify` — and re-requests the geometry it captured. Its own comment already said
the quiet part: *"best-effort; this WM ignores it for client placement"*. A **re-mapped
window is placed where the program originally asked**, and the program originally asked
(via `set_geom`, reading the `untitled.sch` slot) for the design window's exact spot.

That also explains why the two censuses disagree: `viewer-open` reads Tk's just-issued
**request**, `viewer-open+` reads the WM's **answer**.

The user's own geometry store shows the seed:

```
sky130A/.../tb_bandgap.sch   1110x761+3628+358
untitled.sch                 1110x761+3628+358    <- the same, and the viewer's buffer name
```

## Fix

* `wviewer::uncover` **verifies its own work**: after applying the offset it re-checks
  300 ms later. The re-check is just another `uncover` — if the shove held, the pair is no
  longer congruent, it returns 0 and stops by itself. Bounded (`verify` defaults to 2) so
  an insistent WM is argued with twice, not for the rest of the session.
* The call moved from before `raise_activate_toplevel` to after it, so the viewer does not
  spend ~300 ms sitting on the schematic before being corrected.

## Three new rows, and one honest gap

* **U8** — a shove that is undone is re-applied. This is the row that carries the fix.
* **U9 / U9b** — positive twins: once it sticks the window is left alone, and an insistent
  WM (congruence restored on every tick) is argued with at most a few times.
* **U10** — the full field sequence with the *real* `raise_activate_toplevel` in it.

⚠ **The ordering is NOT pinned.** Moving the `uncover` call back to before the re-map
leaves every row green, because the verification repairs it either way. The reorder is an
improvement; the verification is the fix. Sabotage removing the verification reds U8 and
U10; making it unbounded reds U9b.

## Earlier in the same day, for the record

Two further reasons the shove was inert, both fixed and both real:

1. it decided **at creation time**, when `wm geometry` still reports the *requested*
   geometry, so it compared a not-yet-placed window and returned 0 (fixed: wait for the
   map, bounded retries);
2. it demanded an **exact string match**, while 0647's own measurement was one pixel apart
   (fixed: same size and same corner within 8 px).

---

# ADDENDUM 2 — the shove worked, and the result was still wrong

`/tmp/Xschem.log.1`, both censuses identical, so the verification held:

```
.     stack=2  1110x761+3728+382  'xschem [3] - tb_bandgap.sch (read-only)'
.x1   stack=5  1110x761+3776+430  'Waveforms tb_bandgap (ngspice_state1)'
```

Two mapped toplevels, 48px apart, viewer on top. The user's reading of that same screen:

> *"The double-click still corrupts the schematic window display with waveforms. There is
> an offset, but no new Waveform Window. When I click in the schematic window, it's
> restored to show tb_bandgap."*

Both windows are 1110x761 and 48px apart, so 95% of the schematic is hidden and the
result reads as **one window gone wrong**. "Clicking restores the schematic" is not a
repaint — it raises `.` above `.x1`. The user's own earlier session already proved the
two-window reading (*"I was able to drag the waveform viewer to reveal schematic"*); a
canvas painting the wrong content would not have been fixed by moving a different window.

## The lesson worth keeping

The bug as **filed** was pixel-congruence. 48px fixes pixel-congruence completely and
fixes nothing the user cares about. Congruence was the measurable proxy someone reached
for; *"I can still see my schematic"* was the requirement, and no amount of green on the
proxy was ever going to satisfy it.

## Ruled by the user 2026-08-26

Offered: tile side by side / open behind without raising / a much bigger offset / do not
auto-open the viewer at all. **Chosen: a much bigger offset**, knowing it still overlaps.

Implemented as a **fraction of the window (a third), never a constant**, so it stays right
at any window size — `dx = w/3`, `dy = h/3`, floored at 48, with the existing flip and
clamp keeping the window on screen. Measured on the real `ase::open_state` path on `:99`:
design at `+808+0`, viewer at `+438+253` (flipped in x because the step would have gone
off the right edge).

Rows: U1c pins the step as a fraction and reds on a return to 48px; U1d pins that the
result stays fully on screen.

⚠ **Not pinned:** there is no upper bound on the step. Sabotaging it to 5x the window
width still passes — the flip and clamp land it in a corner and nothing complains. Left
unguarded deliberately, and said so in the suite rather than dressed up.
