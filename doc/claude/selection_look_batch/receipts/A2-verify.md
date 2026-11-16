# Stage A2 verify: adversarial check of the repair-based selection overlay

Verifier: stage-A2 adversarial verifier, 2026-11-15.
Change verified: the uncommitted working-tree diff, 7 files, `git diff | md5sum` =
`f945790edbc97924438d21885d53a87d` (re-checked at the end; unchanged).
Base: `e3c43487e`.

## Verdict: SAFE WITH LIMITS

- Every stage-A finding (D1–D7, L1) is fixed. I re-ran each one myself. All are AE 0.
- Classic is byte-identical to the base on every state I made.
- Valgrind found no errors in any run.
- No crash with `--nogui` or `--pipe`, in any style.
- One real defect is new (**N1**, medium). With a second real window open, a repair can be
  dropped. The window then shows a stale selection until the next redraw. Fix it before the
  commit. It does not block the stage-B look.
- One cost is higher than classic and has no fallback (**N2**, medium): a rubber band
  while a large selection is shown.
- One cosmetic difference (**N3**, low): a rubber band is cut across selected texts.

## How I measured

- **Builds.** `~/gsv3` = a fresh clone at `e3c43487e` plus this diff, built by me (only the 6
  pre-existing `const` warnings). `~/gsl0` = the base. `~/gsv2` = the fix crew's
  Windows-emulation build (I checked it by diff: this tree's `src/` plus `SEL_REAL_XCLIP 0` and
  the two `#if 0` in `set_clip_mask`; binary newer than its sources).
- **Displays.** My own Xvfb `:283`–`:286` (1920x1080x24), each with openbox. `DISPLAY` unset in
  the calling shell. `GUI_GATE=0`. A throwaway `HOME` per run. One xschem per display, because
  two windows on one display overlap and corrupt `import -window` snapshots. Never `:99`, `:0`
  or the user's screen. No T1.
- **Pixels.** `magick compare -metric AE` of an `import -window` snapshot against a full
  `xschem redraw` of the same state, or against the state named in each test.
- **Events.** Real Tk events on `.drw` (`event generate`), with the user's
  `sky130A/cadence_style_rc` loaded (Cadence keys, fluid editing).
- **Scratch.** Scripts in `.../scratchpad/selshot/V2/scr/`, outputs in `V2/out/`, valgrind logs
  in `V2/vg/`, images in `V2/img/`. Full prefix:
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/V2/`.
  This is scratch, so it is not durable.

## Findings

### N1 (medium): a second real window loses a pending repair

**What happens.** `sel_idle_cb` (move.c) runs the one repair per idle. With
`tabbed_interface 1` (the shipped default) it drops the pending damage of **every** context
that is not current:

```c
if(tabbed) { ctx[i]->sel_pend_n = 0; continue; }
```

The comment says a tab off screen is redrawn when shown. That is true for tabs. It is false for
a real top-level window, which coexists with tabs: `xschem new_schematic create_window` always
makes one (the wave viewer's `-window` path does). It is also false for the main window when
the real window is current. Classic is not affected, because it paints at once.

**Reproduction** (`V2/scr/ctx_detach.tcl`, sky130 `not.sch` in the main window):
1. `xschem new_schematic create_window {} xschem_library/examples/flop.sch`.
2. D1: in that window, `xschem select instance x5`, then `xschem new_schematic switch .drw`
   before the event loop goes idle.
3. D2: in the main window, `xschem select instance M1`, then switch to the new window.
4. D3: in the main window, `xschem select instance M1 clear`, then switch to the new window.

**Evidence.** AE of the window against its own full redraw:

| case | halo | bright | classic (`~/gsl0`) |
|---|---|---|---|
| D1: new window, select dropped | **6633** (identical to the unselected window: AE 0 against it) | **2854** | 0 |
| D2: main window, select dropped | **6173** | **4234** | 0 |
| D3: main window, deselect dropped (a ghost halo stays on M1) | **6173** | **4234** | 0 |
| D4: pending in the new window, window destroyed | 0 | 0 | 0 |

- Deterministic: halo gave the same three numbers on three runs. `own` text style: 6932 / 6303 /
  6303.
- Non-tabbed mode (`ctx_win.tcl`): all 0. Tabs only (`ctx_tab.tcl`): all 0.
- Images: `V2/img/N1b_detached_window_select_dropped_d1.png`,
  `V2/img/N1_detached_tab_damage_dropped_d3.png`.

**How far it reaches.** I could not reach it with a real gesture.
- A real click in the new window, then `<Leave>`, `<Enter>` and `<Motion>` on the main window,
  all queued as one batch before idle (`det_ev.tcl`): AE 0. The click path repairs at once.
- `xschem netlist` of the main window while the new window is current, then switching back,
  as the ASE helpers do (`det_net.tcl`): AE 0, though netlisting deselects.
- So it needs a scripted select or deselect followed by a scripted switch to another real
  window before idle. This tree has many scripted switches (`wave_viewer.tcl`,
  `ase_window.tcl`), so a Tcl path that does this is plausible. I did not find one.
- The damage stays wrong until a full redraw (zoom, pan, load). A hover or crosshair repair
  fixes only its own rects.

**Suggested direction** (not done). Drop pending damage only for a context whose canvas is
not on screen. A real window's context should be flushed with `xctx` switched to it, as the
non-tabbed branch already does.

### N2 (medium, cost): a rubber band over a large selection has no fallback

**What happens.** During a rubber band, each motion calls `draw_selection`, so the styled
overlay is painted in full on every motion. The drag probe (`sel_drag_start`) covers only
`STARTMOVE` and `STARTCOPY`, not `STARTSELECT`, so there is no cheap fallback.

**Reproduction** (`V2/scr/perfb.tcl`). 1600 nfet + 1600 wires, 1400x1000 window, everything
selected, then a Shift rubber band from the lower-right corner. Ten small motions, ms per motion
with `update`, two runs each. Zoom is the view width in schematic units.

| view width | classic `~/gsl0` | classic this tree | halo | bright |
|---|---|---|---|---|
| 2300 | 10.1–10.2 | 10.3 | 15.6–16.1 | 12.9–13.1 |
| 3500 | 57.4–59.6 | 57.5–61.3 | **106.5–119.8** | 91.1–102.0 |
| 8200 | 12.6–15.2 | 14.4–18.0 | **39.1–42.7** | 11.4–12.7 |

- Halo costs about 2x classic at 3500 and 2.6–3x at 8200.
- Classic is already slow at 3500. Halo makes it worse.
- A sweep of a plain band over all 1600 objects hung for 300 s in **every** build,
  base included. So I removed that leg. It is not a defect of this change.

**Also: select all is slower than the crew's table says.** Same sheet and window, ms for
`xschem select_all; update`:

| view width | classic | halo | bright |
|---|---|---|---|
| 2300 | 5.2–5.9 | 13.6–14.0 | 12.6–15.0 |
| 3500 | 19.5–21.5 | 53.0–56.6 | 48.6–50.9 |
| 8200 | 4.5–6.0 | 23.1–26.1 | 8.2–10.6 |

At 8200 halo is about 4–6x classic. The crew wrote "the worst case is about 2.7x". It is a
one-shot cost, not per motion. Unselect all is much cheaper than classic (halo 0.85–2.8 ms
against classic 12.1–118.6 ms).

### N3 (low, cosmetic): a rubber band is cut across selected texts

**What happens.** In `sel_styled_show`, every text bbox is restored from the pixmap before its
glyphs are painted. When a rubber band crosses a selected text, the band's edge is erased
inside that text's bbox. The function's comment says a foreign overlay is cut "only where a
band crosses them". That is not what happens for text.

**Reproduction** (`V2/scr/band.tcl`). Select the floating text in `not.sch`. Start a rubber band
to its right and drag left, so the band's lower edge runs through the text.

**Evidence.** Grey band-edge pixels (#4F4F4F) on that row: classic **829**, halo **518**. The
missing pixels are black, inside the text bbox. Image:
`V2/img/N3_rubberband_cut_by_styled_overlay.png`.

### Not defects, for stage B

- **A large drag switches look partway.** At view width 3500 with 1600 FETs, the drag falls
  back to the cheap look after the first step. Image: `V2/img/bd_halo3500_sel_vs_back.png`
  (left: static halo; right: same objects mid-drag, back at the anchor). This is the crew's
  user decision 6.
- **Selected pin squares.** In halo, a selected instance's pin square shows an orange inside
  with a red edge. A wire over a pin is hidden by the band. The symbol's green line is drawn
  over the pin. Image: `V2/img/pin_crop3.png`.

## Re-run of the stage-A findings

On `~/gsv3`, halo and bright, each with text style `colour` and `own`, dark scheme. Halo `own`
and bright `colour` again on the light scheme. All AE.

| repro | crew (final) | mine |
|---|---|---|
| D1 `partial`: text / wire | 0 / 184 | 0 / **184** in every style. Classic on this tree and on `~/gsl0` is also 184, so it is upstream |
| D2 `fillrect`: back / abort / unselect | 0 / 0 / 0 | 0 / 0 / 0 |
| D2 `instzoom_hide` | 0 / 0 / 0 | 0 / 0 / 0 |
| D3 `scoperep`: white pixels | 30/30 | 30/30 at every stage; sub-repros 0 |
| D4 `xhair` | 0 | 0 |
| D5 `customfont` | 0 / 0 | 0 / 0 |
| D7 `winemu` on `~/gsv2` | 0 / 0 / 0 | 0 / 0 / 0, halo and bright, `colour` and `own`, `fix_broken_tiled_fill` 0 and 1; full repro set under emulation also 0 (wire 184) |
| L1 `fastsel` | 0 / 0 / 0 | 0 / 0 / 0 |

`own` was really live: `own` against `colour` differs by 4621 and 8306 px in two repros.

## The crew's other claims, re-measured

### Timings (`V2/scr/perfv.tcl`; 1600 FET + 1600 wires, all selected, view width 2300; ms; two runs)

| metric | crew classic → halo (ratio) | mine classic `~/gsl0` → halo (ratio) |
|---|---|---|
| hover change | 10.04 → 1.34 (0.13x) | 7.89–8.01 → 1.16–1.33 (0.15–0.17x) |
| crosshair motion | 16.45 → 1.14 (0.07x) | 11.9–12.4 → 0.88–1.03 (0.08x) |
| crosshair full-span motion | 16.97 → 4.98 (0.29x) | 11.5–11.9 → 4.89–5.00 (**0.42x**) |
| unselect all | 9.51 → 1.04 | 6.6–7.6 → 0.96–1.05 |

**Why hover and crosshair are so much cheaper.** Classic calls `draw_selection(gc[SELLAYER])`
over the **whole** selection on every hover or crosshair change. That is upstream behaviour.
With nothing selected, a hover change costs 0.44–0.60 ms in every build. With 1600 selected,
classic costs about 8 ms. Halo repairs only the damaged rects. So the speedup is real. It does
not come from skipping work that matters: with 1600 selected, hover plus a full crosshair is
AE 0 against a redraw in classic, halo and bright (`big1`).

The ratios agree with the crew's within my machine's noise, except full-span (0.42x, not
0.29x). Both are well inside the 1.5x requirement.

### Drag fallback (`V2/scr/bigdrag.tcl`; 1600 FET with texts, 1400x1000; ms per step with `update`)

| view width | crew halo | mine halo | mine bright | look |
|---|---|---|---|---|
| 2300 | 11.69, styled | 13.0–17.9, styled | 10.2–14.8, styled | styled (back at anchor = static, AE 0) |
| 3500 | 9.35, cheap | 28.1, then 8.9–10.3 | 25.2, then 9.0–9.4 | cheap after step 1 (image above) |

- Classic at 3500: 8.2–9.3 (this tree) and 8.3–9.7 (`~/gsl0`).
- At 2300 halo sits at 13–18 ms a step, close to the 16.7 ms budget. A slower server will
  often take the cheap look there.
- **Abort leaves nothing: confirmed.** Move then abort, copy (`c` key) then Escape, and move
  then place: all AE 0, at 2300 and 3500, halo and bright.

### "Classic is unchanged" (crew: 30 of 30 states)

Confirmed on my own states, `~/gsv3` classic against `~/gsl0`, all AE 0:
- 13 real-event drag states (`drag2.tcl`): fluid move and place, move and Escape, copy and
  Escape, copy and place, Shift-R mid-move then Escape, rubber band end;
- 20 overlay states (`ovl.tcl`, the user's hover, crosshair and snap-cursor settings);
- 5 large-drag states, 4 highlight states, print and export states, and the detached-window
  states.

### "Every repro is AE 0 with own"

Confirmed for D1–D7 and L1 above, and for the highlight, context and overlay tests below.

### Shift-click snap-cursor difference (crew: 401 px, not residue)

Same mechanism seen. On Shift motions (`ovl.tcl`), halo and bright differ from the redraw by
15–16 px, classic by 16–19 px, all the snap-cursor diamond that a redraw drops. Not residue.

### Suites (`run_suites.sh`, `AUDIT_DISPLAY=:283`/`:284`, `GUI_GATE=0`)

19 selection suites on the display arm, `~/gsv3` (default style halo) and `~/gsl0`:
identical, line for line.
- 15 pass on both.
- `test_cadence_drag` (2 FAILED), `test_select_at` (5 FAILED) and `test_snap_bindkeys` (FAIL)
  fail the same way on both.
- `test_expose_repaint` self-skips (`no X`) on both, even with a display.

## Everything else I attacked

All AE 0 against a full redraw unless noted.

- **Context changes with damage pending** (`ctx_misc.tcl`, halo, bright `own`, classic):
  delete, cut, paste, zoom in and out, window resize and back, interactive paste then Escape,
  load, descend, go back, `clear force`. All 0.
- **Undo and redo**: nonzero in **every** style, classic and `~/gsl0` included. A scripted
  `xschem undo` leaves the window unrepainted. Upstream, not this change.
- **Tabs** (`ctx_tab.tcl`): select then open a tab, select then switch tabs, switch back,
  select then close the tab, each before idle. All 0.
- **Net highlight** (`hil.tcl`): highlighted net, label and instance, then selected, then hover
  and crosshair repairs over them. All 0. **Striped highlight** (`hil2.tcl`, every style with a
  30° dash): 0, so the cairo stripe path does not thicken on repeated repairs.
- **Overlays together** (`ovl.tcl`): hover, crosshair, snap cursor and a scope outline, ten
  motions. 0 except the snap-cursor diamond above.
- **Exports** (`print.tcl`): SVG, PS and PDF are identical across classic, halo, bright and
  `~/gsl0`. PNG of a selected box: identical. Full-page PNG differs from `~/gsl0` by 213 px in
  every style, which is the title block's file date (the clone's time). Window after each
  export: 0.
- **Settings changed while selected** (`sw.tcl`): changing `selection_style` without a redraw,
  `toggle_colorscheme`, `selection_color red` with halo width 7 and `build_colors`, a PNG
  export, then deselect. All 0.
- **Light scheme**: the D-repros above, 0.
- **Headless**: `--nogui` and `--pipe`, each in classic, bright and halo, each with `colour` and
  `own`, under valgrind with `--error-exitcode=99`: exit 0, 0 errors, all steps reached.
- **Valgrind on the GUI paths**: `ctx_tab`, `ctx_detach` (halo and halo `own`), `ctx_win`,
  `ctx_misc` (halo and bright `own`). Every log is empty. No invalid reads, including after a
  window is destroyed with damage pending.

## What I did not cover

- The user's real X server (Windows, over TCP), `:0`, and Windows itself. D7 is emulated only.
  The drag probe's behaviour on a real server is unmeasured.
- A Tcl path in this tree that actually triggers N1. I proved the mechanism, not a user path.
- Symbol-edit mode, graphs and waveform windows with a selection, and `compare_schematics`.
- Expose of part of a window, beyond window resize.
- Rubber band cost with a plain (not Shift) band over all 1600 objects, because it hangs in
  every build.
- A full suite audit. I ran 19 selection suites, not all of them.

## Housekeeping

- Killed my own Xvfb and openbox processes by pid (`:283`–`:286`), after checking each pid's
  command line and display.
- Removed the backup files my runs wrote in `~/gsv3`, `~/gsl0` and `~/gsv2` (`not~.sch`,
  `untitled~.sch`, `before_5~.sch`, `fixture_0105_pre~.sch`).
- **Not mine, left alone:** the main tree has
  `sky130A/xschem_libs/sky130_tests/not/schematic/not~.sch` (03:14) and
  `tests/from_user/before_5~.sch` (02:59). Both are gitignored. I ran nothing in the main tree.
- `~/gsv3` is left in place (this diff, built). Delete it when stage A is settled.
- This file is the only file I wrote in the main tree.
