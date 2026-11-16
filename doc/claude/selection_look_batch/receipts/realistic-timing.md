# Realistic timing: would anyone notice the halo selection look?

**In plain English.** No one would notice the new look in ordinary use, and when something is
selected it is the faster of the two. On every page measured (sky130 bandgap, its opamp,
tca_main, n_diffamp, charge_pump, comparator and two testbenches, an ihp-sg13g2 flip-flop and DC
bench, a gf180mcuD bench, rom8k, its row predecoder, and the adc), every action other than a drag
stays under one 60 Hz frame (16.7 ms) with the halo, as it does on base. The halo adds 1–5 ms at
the moment of selecting. The worst case is select-all on tb_tca_tran, which goes from 2.9 ms to
7.8 ms. In return it takes up to 9 ms off every pointer movement while a selection is up: on the larger
pages, moving the crosshair with everything selected went from 8–10 ms to 1–2 ms.

**Net highlighting through the hierarchy**, which the user named as where Cadence struggles, costs
the same on both trees within noise. That holds for a 512-bit word-line bus taken through two
iterated levels of rom8k, both with and without a selection active. xschem does not have the
Cadence problem in the first place. It highlights only the level on screen and carries the
highlight down or up when you descend or go back. So the cost does not grow with the depth of the
hierarchy or with the number of iterated instances:

- highlighting a net takes ≤ 7.5 ms;
- descending or going back takes 5–25 ms, with or without a highlight.

**The drag look switch never fires on an ordinary drag.** That holds on every display tested,
including an X server throttled to 12 % CPU. When 1–50 devices are dragged, the probe times the
overlay at 0.1–5 ms against its 16.7 ms limit. Drags of a whole page selected with select-all
(178–499 objects) are the closest:

- the first frame takes up to 35 ms, and later frames 6–13 ms;
- on the 12 % server, four of the ten pages switch to the cheap look, as designed.

**Where a user WILL notice something is dragging, and it is base xschem, not the halo.**

- Dragging one device on an ordinary page costs 20–80 ms per frame on base and on the new look
  alike; dragging a handful of connected devices costs 40–450 ms per frame.
- On a synthetic page the cost grows with the square of page size: about 50 ms per frame at
  100 devices + 100 wires, about 10 s per frame at 1600.
- Stack sampling puts about 80 % of a drag frame in the fluid-wiring passes. These call
  `tclgetdoublevar("cadsnap")` (a Tcl variable lookup plus `sscanf`) inside loops over every pin
  and wire segment.

**That is the current weak spot.** The halo adds nothing measurable to it: H − B is within spread
on 51 of the 54 drag rows that really dragged, and the other three are +1.2 to +2.1 ms.

**On a slow X server the halo's one-off cost at selection time grows, but not into a hitch.** At
12 % server CPU:

- select-all goes from 5–8 ms to 21–29 ms, about 1.5 frames, once, at the click;
- a full redraw with everything selected goes from 17–25 ms to 29–33 ms;
- pointer motion with a selection is still 10–16 ms cheaper with the halo.

I could not measure the user's real Windows X server over TCP, X request or round-trip counts (no
tracer is installed), or real hand input.

Crew: realistic-timing crew, 2026-11-15. Trees, both built before this run and newer than their
sources:

| tree | commit | `src/xschem` md5 | built |
|---|---|---|---|
| base `~/gsl0` | `e3c43487e` | `417c0525c4d7…` | 00:06 |
| new `~/gsa6` | `bd14668b9` + the A2–A6 diff (9 files) | `bfed899eeb5f…` | 11:13 |

Nothing was edited in any tree. Nothing was committed, pushed or stashed.

## How it was measured

**Variants.** These are interleaved on every design:

| variant | tree | settings |
|---|---|---|
| **B** | base `~/gsl0` | classic |
| **H** | `~/gsa6` | `selection_style halo`, `selection_text_style auto`, `selection_text_own_px 16` |
| **C** | `~/gsa6` | `selection_style classic` (the control) |
| **K** | `~/gsa6` | halo with `selection_text_style colour` and own_px 16 (separates the label outline from the halo) |

The settings were confirmed inside the running program, not only in Tcl. A hardware watchpoint
read `xctx->sel_style`, `sel_text_style` and `sel_text_own_px` back out of the context: H gave
`style=2 tstyle=1 own_px=16` and K gave `style=2 tstyle=0 own_px=16` (`SEL_STYLE_HALO`=2,
`SEL_TEXT_OWN`=1, `SEL_TEXT_COLOUR`=0).

**Displays.**
- Private Xvfb `1920x1080x24` plus openbox on :270–:276, one display per stream.
- Two of them, :274 and :275, ran in a systemd scope under `CPUQuota=25 %` (`cpu.max 1000 4000`)
  and `12 %` (`cpu.max 1000 8333`), as stand-ins for a slow X server.
- `DISPLAY` was unset for everything else. Nothing touched :99, :0, `$DISPLAY` or A5b's :286–295.
- Each run had a throwaway `HOME` and `GUI_GATE=0`. Its cwd was a scratch work dir holding copies
  of the libraries and designs; no design was loaded from a clone and none was saved.

**Settings in force.** Each workarea's own `cadence_style_rc` stands, as the user runs it:
- crosshair on (size 2), `hover_highlight 1` and connected stretch;
- a plain wheel scrolls and Ctrl+wheel zooms;
- window 1400×1000 with the dark colour scheme.

**One step.** One step is an X round trip (`winfo pointerxy`), then the action, then `update`,
then another round trip. Its time is wall clock, so it includes the X server's work. Input is
synthesized with `event generate`.

**Statistics.**
- The design matrix ran 3 rounds × 5 repetitions per action; the variant order flipped each round
  (B H C K / K C H B).
- Each cell is the median of the per-round medians. Its spread is the range of those round medians.
- A difference is called **real** (marked `*` below) only when |H − B| exceeds the larger of the
  two spreads.

**Ratings:**

| time per action | rating |
|---|---|
| < 16.7 ms | invisible |
| 16.7–50 ms | borderline |
| 50–100 ms | a noticeable hitch |
| > 100 ms | lag |

## Design sizes

Per page: devices+blocks (instances other than labels, pins and annotations) / instances /
wires / texts. Flat devices are counted through the hierarchy, with vector widths expanded.

| design | levels | flat devices | top page | notable sub-pages |
|---|---|---|---|---|
| sky130 bandgap | 3 | 152 | 47 / 115 / 58 / 3 | zero_opamp 27/70/69, bandgap_opamp 27/73/70 |
| sky130 bandgap_opamp | 2 | 31 | 27 / 73 / 70 / 3 | |
| sky130 tca_main | 2 | 62 | 14 / 109 / 76 / 1 | boost_n, boost_p 13/74/52 |
| sky130 n_diffamp | 1 | 16 | 16 / 37 / 27 / 2 | |
| sky130 charge_pump | 1 | 46 | 46 / 80 / 130 / 6 | |
| sky130 test_comparator | 2 | 71 | 62 / 168 / 196 / 38 | |
| sky130 tb_bandgap | 4 | 159 | 8 / 34 / 11 / 5 | |
| sky130 tb_tca_tran | 3 | 117 | 40 / 167 / 122 / 2 | |
| ihp sg13g2_sdfrbp_2 | 1 | 46 | 46 / 81 / 330 / 0 | |
| ihp dc_mos_temp | 1 | 12 | 12 / 37 / 36 / 0 | |
| gf180 test_nfet_TRAN | 1 | 4 | 4 / 7 / 15 / 0 | |
| rom8k | 4 | **8663** | 26 / 169 / 11 / 5, **538 expanded** | 21 pages; iterated `xcpr[256:0]`, `xrdec[31:0]`, `xsa[15:0]`, `xcdec[15:0]` |
| rom2_predec4 (rom8k) | 2 | | 52 / 102 / 100 / 0 | |
| adc (ngspice examples) | 5 | 1213 | 16 / 53 / 34 / 5 | 13 pages, iterated counter |

A `W` suffix in the tables below means the same page at a working zoom: labels about 18 px tall,
centred on the devices. Without it, the page is zoomed to fit.

## Ordinary actions, normal Xvfb (B → H, ms)

Selection and pointer motion. Here "block" is a rubber-band selection of 10–50 objects on the page,
and "all sel" means everything selected.

| page | click | shift-add | band release | select all | deselect all | redraw (all sel) | hover (all sel) | crosshair (all sel) |
|---|---|---|---|---|---|---|---|---|
| adc | 6.6 → 7.3* | 1.5 → 2.4* | 0.7 → 1.3* | 1.0 → 2.5* | 1.6 → 0.7* | 2.6 → 3.0 | 2.9 → 1.6* | 2.3 → 0.8* |
| bandgap | 8.4 → 9.6 | 1.4 → 2.6* | 0.9 → 1.0 | 2.8 → 6.8* | 3.6 → 0.8* | 8.1 → 9.7 | 9.7 → 1.6* | 7.6 → 0.6* |
| bgopampW | 4.7 → 6.1 | 1.7 → 3.3* | 0.8 → 0.8 | 0.9 → 3.7* | 1.5 → 0.7* | 2.4 → 4.3* | 2.9 → 2.1 | 2.1 → 0.5* |
| bgopamp | 7.0 → 7.7 | 1.2 → 1.6 | 0.8 → 1.6* | 1.5 → 3.9* | 2.1 → 0.7* | 4.3 → 5.3 | 4.8 → 1.2* | 3.8 → 0.6* |
| comparator | 1.3 → 1.4 | 1.1 → 1.2 | 0.8 → 1.6* | 2.6 → 7.0* | 3.5 → 1.0* | 7.3 → 9.1 | 9.1 → 2.5* | 8.4 → 2.1* |
| cpumpW | 8.8 → 10.3* | 2.0 → 4.0* | 0.9 → 1.4* | 1.0 → 5.2* | 1.7 → 0.9* | 3.6 → 5.9* | 3.6 → 2.7* | 2.8 → 0.7* |
| cpump | 8.4 → 9.3 | 1.7 → 2.7* | 0.9 → 1.5* | 2.1 → 4.8* | 2.8 → 0.9* | 5.6 → 6.6 | 7.3 → 1.6* | 6.9 → 1.1* |
| dcmostemp (ihp) | 1.2 → 1.7* | 1.0 → 1.7* | 0.6 → 1.1* | 0.8 → 3.1* | 1.3 → 0.8* | 2.0 → 3.4* | 2.3 → 0.9* | 1.8 → 0.6* |
| gfnfet (gf180) | 1.9 → 3.4* | 1.8 → 2.9* | – | 0.4 → 1.6* | 1.1 → 0.8* | 1.6 → 1.7 | 1.3 → 1.3 | 1.0 → 0.5* |
| ndiff | 2.4 → 3.6* | 2.0 → 3.2* | 1.0 → 1.5* | 1.4 → 5.9* | 2.0 → 0.9* | 3.3 → 7.1* | 4.0 → 2.2* | 3.5 → 1.2* |
| predec4 | 7.8 → 9.3* | 1.8 → 2.6* | 0.7 → 1.2* | 2.1 → 4.8* | 2.9 → 0.8* | 5.6 → 6.5 | 6.8 → 2.0* | 5.7 → 0.8* |
| rom8k | 9.8 → 10.9 | 1.5 → 2.4* | 1.0 → 1.1 | 1.9 → 5.0* | 3.0 → 0.8* | 6.5 → 7.7 | 6.7 → 2.5* | 5.3 → 1.0* |
| sdfrbp (ihp) | 10.6 → 11.0 | – | 1.0 → 2.0* | 3.0 → 7.4* | 3.7 → 0.8* | 8.2 → 10.1 | 10.6 → 2.4* | 9.9 → 1.1* |
| tbtcatran | 2.0 → 2.4 | 1.5 → 2.0* | 0.7 → 0.9 | 2.9 → 7.8* | 3.7 → 0.9* | 9.9 → 11.8 | 11.4 → 2.0* | 9.0 → 1.1* |
| tcamainW | 2.4 → 4.0* | 2.0 → 4.0* | 0.9 → 1.6* | 1.0 → 4.8* | 1.8 → 0.9* | 3.7 → 5.2 | 3.4 → 2.6 | 2.6 → 0.6* |
| tcamain | 2.9 → 3.4 | 1.9 → 2.8 | 1.0 → 1.1 | 1.4 → 3.7* | 2.2 → 0.9* | 5.4 → 4.8 | 4.8 → 1.9* | 4.2 → 1.2* |

Drags (per frame, the median over frames 5–20 of a 20-motion drag), zoom, pan and hierarchy.
"Drag 3" is three devices clicked and dragged. Connected stretch grows that into the devices plus
their wires: 9–39 objects move. "Drag block" grabs the rubber-band block.

| page | hover (block sel) | drag 3 | drag block | ctrl-wheel zoom | zoom in | pan | descend | go back |
|---|---|---|---|---|---|---|---|---|
| adc | 1.0 → 0.7* | 11.5 → 11.8 | 11.9 → 11.9 | 4.4 → 4.6 | 2.9 → 3.1 | 2.1 → 2.1 | – | – |
| bandgap | 1.2 → 0.6* | 21.8 → 23.4 | 32.3 → 32.3 | 6.6 → 7.4 | 6.5 → 6.2 | 4.4 → 4.5 | 15.0 → 15.0 | 16.9 → 17.2 |
| bgopampW | 1.1 → 0.6* | 17.1 → 17.0 | 17.3 → 17.3 | 2.6 → 3.3 | 3.4 → 3.7 | 2.3 → 2.5 | – | – |
| bgopamp | 1.2 → 0.5* | 11.0 → 11.3 | 12.3 → 12.0 | 3.9 → 4.3 | 3.6 → 3.3 | 2.6 → 2.7 | 7.4 → 7.8 | 13.5 → 14.2 |
| comparator | 1.1 → 0.8 | – | – | 6.6 → 6.4 | 6.0 → 5.6 | 4.3 → 4.2 | 8.0 → 8.8 | 18.3 → 20.2 |
| cpumpW | 1.1 → 0.7* | 36.1 → 35.4 | 35.7 → 34.7 | 3.4 → 3.7 | 4.9 → 4.9 | 3.4 → 3.7 | – | – |
| cpump | 1.1 → 0.7* | 37.4 → 37.1 | – | 5.9 → 5.3 | 4.0 → 4.1 | 3.3 → 3.6 | – | – |
| dcmostemp | 1.0 → 0.7* | 4.8 → 4.7 | 6.2 → 6.0 | 3.0 → 3.5 | 2.5 → 2.6 | 1.7 → 2.0 | – | – |
| gfnfet | 0.6 → 0.6 | 4.4 → 4.7 | – | 1.9 → 1.7 | 1.3 → 1.4 | 1.1 → 1.2 | – | – |
| ndiff | 1.8 → 1.2 | 7.6 → 9.0 | 5.2 → 4.8 | 4.3 → 4.1 | 3.9 → 3.9 | 3.1 → 2.5 | – | – |
| predec4 | 1.1 → 0.7* | 22.1 → 23.1 | 16.5 → 18.2* | 3.9 → 4.1 | 3.4 → 4.5* | 2.8 → 3.7* | 3.0 → 3.5 | 6.9 → 7.7* |
| rom8k | 1.2 → 0.8 | 23.0 → 23.3 | 26.8 → 27.6 | 6.1 → 7.9 | 5.9 → 7.0 | 4.1 → 4.6 | 4.0 → 3.7 | 17.8 → 16.7 |
| sdfrbp | 1.4 → 1.3 | – | 67.2 → 67.7 | 5.5 → 5.4 | 5.2 → 5.8 | 4.3 → 5.1 | – | – |
| tbtcatran | 0.9 → 0.7* | 69.6 → 69.3 | 17.0 → 16.6 | 7.1 → 6.1 | 5.4 → 5.2 | 3.4 → 3.2 | 12.1 → 11.1 | 15.5 → 14.9 |
| tcamainW | 1.3 → 0.9* | 29.2 → 26.9 | 9.1 → 10.4 | 2.8 → 4.4 | 3.4 → 4.0 | 3.0 → 3.5 | – | – |
| tcamain | 1.5 → 1.2 | 32.5 → 33.5 | 10.7 → 11.2 | 4.5 → 5.4 | 3.2 → 3.7 | 3.1 → 3.6 | 9.0 → 9.9 | 11.2 → 12.2 |

**Reading it.**

- **Not one non-drag cell reaches 16.7 ms with the halo except go back**, which is 17–20 ms on
  base too (reloading the parent page).
- **The halo's real costs** are at the moment of selecting:
  - select all, +1.2 to +5.0 ms;
  - shift-add, +0.4 to +2.0 ms;
  - band release, +0.1 to +1.0 ms;
  - click, +0.1 to +1.6 ms;
  - a full redraw with everything selected, up to +3.8 ms on ndiff.

  The largest halo figure is 11.8 ms.
- **The halo's real gains** are wherever the pointer moves while something is selected. Deselect
  gains 0.3–2.9 ms. Hover and crosshair motion with everything selected gain 0.5–9.4 ms, on both
  the client and the server side (the mechanism was not traced here).
- **Drags:** H − B is within spread on every row except predec4's block drag (+1.8 to +2.1 ms)
  and gfnfet's first drag frames (+1.2 ms), and the figure is dominated by base work (see below).
- **Controls.**
  - **C** (new tree, classic look) equals **B** within spread on 402 of 407 rows. The largest real
    C − B is +1.6 ms on one predec4 drag row.
  - **K** (halo, coloured labels) equals **H** except on zoomed-in pages, where the label outline at
    own_px 16 costs 1–3.5 ms on select-all and redraw-all-selected. Examples: ndiff 5.9 vs 2.6,
    cpumpW 5.2 vs 3.0, tcamainW 4.8 vs 2.7.

**Gaps.**

- A dash means the row did not run or did not do what it says. The comparator drags and the
  cpump block drag never entered move mode (`ui_state` 1), and several pages had no clickable
  sub-block. I left those cells out rather than report a 0.6 ms "drag".
- The adc descend failed in this pose: it took 0.3 ms and never left the top. The net-highlight
  matrix covers the adc descend instead.

**X server CPU proxy.** On bandgap, server CPU per action (from `/proc/<pid>/schedstat`) was:
- select all: 0.6 ms (B) vs 1.15 ms (H);
- crosshair motion with all selected: 1.7 ms vs 0.16 ms;
- redraw with all selected: 2.7 ms vs 3.3 ms.

The pattern holds on comparator, rom8k, sdfrbp and tcamainW. The client dominates every action:
the server is 5–30 % of the wall time.

## Net highlighting through the hierarchy (B → H, ms)

**How it was run.**
- Highlight a top-level net (`xschem hilight_netname`), redraw, then follow it down through
  sub-block instances that carry it (2–3 levels) and back up.
- Then walk the same path with nothing highlighted, so the highlight's own cost can be separated.
- Mode `none` has nothing selected. Mode `block` re-makes a 10–50-object rubber-band selection at
  each level before every timed step.
- 3 rounds × 3 repetitions, with B/H/C interleaved.
- `romwlF` forces the walk down `xrdec[31:0]` → `x2[15:0]` for the 512-bit `LDWL[511:0]`.

| case (net, levels walked) | highlight net | redraw top (hil) | descend L1 (hil) | redraw L1 (hil) | go back L1 (hil) | descend L1 (no hil) | go back L1 (no hil) | unhighlight |
|---|---|---|---|---|---|---|---|---|
| rom8k LDCP_ROWDEC, xctrl > x395 · none | 6.8 → 7.1 | 7.2 → 7.0 | 10.6 → 10.9 | 3.9 → 4.2 | 24.2 → 23.6 | 10.8 → 10.1 | 22.6 → 22.6 | 6.2 → 6.9 |
| ·· block | 6.5 → 7.3 | 6.3 → 7.4 | 9.8 → 10.2 | 3.8 → 4.4 | 22.2 → 23.7 | 9.2 → 10.0 | 21.3 → 22.5 | 6.2 → 6.8 |
| rom8k LDPRECH, xsa[15:0] > xsacell · none | 6.7 → 6.6 | 6.3 → 6.5 | 8.1 → 8.0 | 2.9 → 2.9 | 24.0 → 22.9 | 7.8 → 7.6 | 22.8 → 22.0 | 6.2 → 6.2 |
| ·· block | 6.8 → 7.4 | 6.3 → 7.1 | 7.9 → 8.1 | 3.0 → 3.7 | 24.1 → 22.6 | 7.7 → 8.4 | 22.4 → 22.5 | 6.5 → 6.5 |
| rom8k vss, xlat > x0[12:0] (> 3rd) · none | 7.6 → 6.8 | 6.7 → 6.7 | 6.5 → 6.4 | 2.4 → 2.4 | 22.9 → 23.8 | 5.9 → 5.5 | 23.1 → 21.5 | 6.0 → 6.1 |
| ·· block | 7.0 → 7.5 | 6.6 → 6.7 | 6.2 → 5.9 | 2.7 → 3.3 | 23.2 → 22.5 | 5.7 → 5.2 | 24.0 → 21.3 | 6.2 → 6.6 |
| **rom8k LDWL[511:0], xrdec[31:0] > x2[15:0]** · none | 7.1 → 6.7 | 6.4 → 5.9 | 6.7 → 6.1 | 2.0 → 1.8 | 25.4 → 24.3 | 5.9 → 5.5 | 23.5 → 22.2 | 6.4 → 5.9 |
| ·· block | 7.3 → 7.5 | 6.5 → 7.2 | 6.9 → 6.4 | 2.5 → 3.5* | 25.6 → 25.2 | 5.5 → 5.8 | 23.3 → 23.8 | 6.5 → 6.8 |
| tb_bandgap VCC, x1 > x1 · none | 3.3 → 3.4 | 2.7 → 2.8 | 24.0 → 24.5 | 6.2 → 6.5 | 10.8 → 10.9 | 24.1 → 23.5 | 10.4 → 10.0 | 2.5 → 2.2 |
| ·· block | 3.1 → 2.9 | 2.9 → 2.5 | 22.1 → 23.0 | 6.5 → 6.9 | 10.9 → 10.6 | 21.6 → 20.5 | 9.9 → 8.9 | 2.5 → 2.5 |
| tb_bandgap EN_N, x1 > x1 · none | 2.8 → 3.1 | 2.3 → 2.3 | 21.3 → 22.2 | 5.4 → 5.4 | 10.4 → 9.8 | 20.9 → 19.8 | 9.4 → 8.9 | 2.5 → 2.0 |
| ·· block | 3.2 → 2.8 | 2.5 → 2.4 | 20.8 → 20.2 | 6.2 → 6.0 | 10.4 → 9.6 | 19.4 → 19.9 | 9.0 → 9.4 | 2.4 → 2.4 |
| tb_tca_tran voutp, xdut · none | 6.6 → 6.6 | 5.6 → 5.9 | 14.4 → 12.7 | 3.1 → 3.0 | 20.2 → 18.9 | 13.1 → 12.0 | 18.6 → 18.2 | 5.9 → 5.7 |
| ·· block | 6.6 → 7.3 | 6.1 → 6.3 | 13.5 → 13.9 | 3.7 → 4.3 | 20.2 → 21.5 | 13.5 → 12.9 | 20.8 → 19.4 | 5.7 → 6.0 |
| tb_tca_tran vinp, xdut · none | 6.6 → 7.0 | 5.8 → 6.1 | 13.1 → 14.1 | 3.0 → 3.0 | 19.1 → 19.1 | 12.5 → 12.9 | 18.7 → 18.9 | 5.8 → 5.9 |
| ·· block | 6.5 → 6.6 | 5.8 → 6.2 | 13.8 → 13.0 | 4.0 → 4.3 | 20.6 → 20.3 | 13.9 → 12.7 | 19.1 → 18.9 | 5.8 → 5.7 |
| adc VCC, x4 > x1[5:0] · none | 3.0 → 2.6 | 3.2 → 3.0 | 6.5 → 6.4 | 2.2 → 1.8* | 8.9 → 7.9 | 5.4 → 5.1 | 7.9 → 7.2 | 2.8 → 3.0 |
| ·· block | 3.7 → 3.6 | 3.6 → 3.7 | 7.2 → 6.9 | 2.6 → 3.8* | 10.1 → 8.7 | 6.0 → 6.3 | 9.3 → 8.6 | 3.8 → 3.5 |
| adc CK, x1 · none | 2.9 → 3.1 | 3.2 → 3.5 | 6.0 → 6.3 | 2.2 → 2.2 | 8.7 → 9.1 | 5.7 → 6.3 | 8.3 → 8.8 | 3.0 → 3.0 |
| ·· block | 3.8 → 3.6 | 3.9 → 4.0 | 7.0 → 6.9 | 2.7 → 3.8* | 9.3 → 9.2 | 6.1 → 6.0 | 9.0 → 8.6 | 3.6 → 3.7 |

Second-level steps (descend L2/L3, go back L2/L3, redraw L2/L3) are 1.5–24 ms on both trees with
no real difference. They are in `log/tab_h.md`.

**(a) Nothing selected.** B and H are identical within spread in every cell.

**(b) A selection active.** The only real differences are one redraw per level on a page that
holds a block selection, at +1.0–1.2 ms. That is the halo's redraw cost from the table above, not a
highlight cost.

**How base xschem itself scales on rom8k (a separate finding).** Highlighting adds at most 1–2 ms
to any step, on any design. That includes a 512-bit bus whose top level alone puts 1536 entries in
the highlight table. Per-level cost does not grow with depth or with the 8663 flat devices.

The table holds only what has been visited: rom8k's LDCP_ROWDEC grows 3 → 6 → 9 entries over two
descents, and LDWL grows 1536 → 1584 → 1587. That is because xschem propagates a highlight lazily,
one level at a time (`propagate_hilights` on descend; `hilight_parent_pins` plus
`propagate_hilights` on go back). The slowest step anywhere is going back up from rom8k's first
level, 22–26 ms. That is a reload of the top page and costs the same without a highlight.

**A base defect seen on the way (both trees).** In tb_bandgap, going back up with VCC highlighted
raised xschem's "Schematic bandgap has unsaved changes" save prompt in round 1. It happened on B and
on H, and in a later diagnostic run on base but not on new. Nothing had been edited, so going back
with a highlight sometimes marks the parent page modified. The harness answered "no" and counted the
prompt: `asks=1` in `h1_tbbg_vcc_none_{B,H}`. Relatedly, `*~.sch` backups appeared in the scratch
copies of every page whose drags this pose aborted with Escape, on both trees. They were in scratch
only, not in the clones. I did not diagnose the cause.

## The drag look switch

**How it was measured.** The probe's own interval was read out of the running program.
- A gdb breakpoint sits on the instruction right after `draw_selection_impl`'s second
  `sel_frame_clock()` call: `draw_selection_impl+0x33c`, `subsd 0x8(%rsp),%xmm0`, in the `~/gsa6`
  binary `bfed899e…`.
- There `xmm0` holds t1 and `8(%rsp)` holds t0. The stop lands after both clock reads, so it never
  falls inside the interval it reports.
- Hardware write watchpoints on `sel_drag_slow` and `sel_drag_cheap` record whether the second slow
  frame flipped the drag to the cheap look.
- Each probe line is matched to its drag by wall clock.
- Drags select the K devices nearest a seed device, press on the seed and make 12 motions, each
  crossing a snap step.

The table gives "first / steady max" overlay ms: frame 1, then the worst of frames 2–4. **SW**
means the drag switched to the cheap look. The limit is 16.7 ms on two frames.

| page (objects at select-all) | K=1 | K=3 | K=12 | K=30 (50) | select all — normal | select all — 25 % server | select all — 12 % server |
|---|---|---|---|---|---|---|---|
| bandgap (178) | 0.7 / 0.4 | 0.9 / 0.5 | 8.3 / 2.0 | 12.4 / 5.4 | **35.4 / 12.7** | 33.7 / 8.8 | 46.8 / 13.3 |
| comparator (499) | 0.3 / 0.3 | 1.1 / 0.5 | 3.0 / 1.3 | (8.4 / 3.6) | 17.7 / 8.1 | 25.5 / 12.9 | 54.8 / 17.4 **SW** |
| cpump (222) | 0.7 / 0.4 | 1.2 / 0.5 | 3.7 / 1.7 | 8.4 / 3.8 | 10.7 / 6.2 | 11.8 / 6.6 | 28.8 / 15.0 |
| cpumpW (222) | 1.4 / 0.8 | 2.0 / 1.0 | 6.5 / 3.2 | 9.7 / 5.1 | 10.9 / 5.8 | 12.3 / 6.1 | 22.4 / 11.8 |
| tcamain (186) | 0.5 / 0.3 | 1.2 / 0.8 | 3.4 / 1.6 | – | 6.4 / 3.2 | 8.8 / 4.8 | 22.5 / 9.5 |
| tcamainW (186) | 1.2 / 0.7 | 2.1 / 1.0 | 6.6 / 3.4 | – | 11.4 / 6.2 | 11.4 / 5.7 | 22.7 / 11.1 |
| tb_tca_tran (291) | 0.5 / 0.3 | 0.8 / 0.4 | 1.2 / 0.5 | 1.8 / 0.6 | 12.6 / 9.3 | 14.7 / 14.5 | 27.0 / 17.1 **SW** |
| sdfrbp (411) | 0.2 / 0.2 | 0.2 / 0.1 | 0.2 / 0.1 | 0.2 / 0.1 | 19.7 / 9.4 | 22.8 / 14.2 | 42.5 / 20.9 **SW** |
| rom8k (219) | 0.4 / 0.3 | 0.6 / 0.7 | 2.1 / 2.0 | – | 9.2 / 6.1 | 9.0 / 7.9 | 13.1 / 16.8 (K: **SW**) |
| predec4 (202) | 0.7 / 0.4 | 1.5 / 0.7 | 4.0 / 2.3 | (10.4 / 5.2) | 12.7 / 6.6 | 13.8 / 8.6 | 14.1 / 20.4 |

**Margin at ordinary group sizes (K ≤ 30).**
- On the normal server the overlay takes 0.1–5.4 ms per frame after the first, which is 3× to
  over 100× under the limit.
- K=12 already moves 34–42 objects, because connected stretch moves the wires too.
- At K=1–30, on any of the three servers, none of the 10 pages ever switched.
- On the 12 % server the small-K steady figures jump to about 7 ms. That jump is the throttle's
  8.3 ms scheduling period, not paint work.

**The closest any drag came** was a select-all drag of bandgap on the normal server. Its first frame
(35 ms) used up the one slow frame the probe allows. The worst of the next three frames was
12.7 ms, a 1.3× margin, so a server about 30 % slower on those three frames would switch it.
- The first frame always costs 2–3× the steady ones, so for big selections the effective margin is
  the steady figure alone.
- The K variant (colour labels) is at or below H in nearly every cell, by up to 6 ms on a
  select-all first frame (bandgap 29.7 vs 35.4), so the label outline is part of what a big
  selection's first frame costs.

**Switching** shows the cheap classic-shape overlay for the rest of that one drag. It is a look
change, not a slowdown.

**The group size at which it switches (synthetic grid).** These are select-all drags of a grid of
N sky130 nfets, each with a gate wire, so 2N objects move. Steady overlay ms on the normal server:

| N (objects) | view 3500 units wide (em 3.8 px) | whole grid (em 1.7 px) |
|---|---|---|
| 200 (400) | 7.0–8.3, no switch | 1.5–3.4, no switch |
| 400 (800) | 13.6–16.3, no switch (first frame 27–30) | 3.0–5.1, no switch |
| 800 (1600) | 24–49, **switch** | 5.6–7.6, no switch |
| 1600 (3200) | 22–53, **switch** | – |

So on Xvfb the switch arrives between about 800 and 1600 selected objects at a moderately
zoomed-out view, and not at 1600 objects when they are drawn small. That is far above anything an
ordinary drag moves. The cost follows on-screen pixel area (halo stroke length, label size), not
the object count, which agrees with A2's finding.

**How close an ordinary drag comes on a slower display.**
- The 25 % server changed nothing at K ≤ 30. At select-all it moved the steady figure up by up to
  5 ms.
- The 12 % server switched select-all drags on comparator, tb_tca_tran, sdfrbp and rom8k (colour
  variant), and never at K ≤ 30.

A real Windows X server over TCP adds one network round trip to each probe interval, because t1's
`XSync` waits for the reply. Its rendering speed for wide lines and stipple patterns is unknown.
Neither was measured.

## Whole drag frames: the base weak spot (not the halo)

Median ms per drag frame, frames that crossed a snap step only. B is base and C is the new tree in
classic; H ran under gdb with only hardware watchpoints armed.

| page | K=1 | K=3 | K=5 | K=12 | K=20 | K=30 / 50 | select all |
|---|---|---|---|---|---|---|---|
| bandgap B / H / C | 20 / 19 / 19 | 29 / 30 / 29 | 38 / 39 / 38 | 56 / 59 / 56 | 86 / 94 / 87 | 132 / 141 / 133 | 45 / 46 / 44 |
| comparator | 55 / 51 / 49 | 104 / 96 / 90 | 121 / 106 / 106 | 172 / 155 / 173 | 235 / 211 / 237 | 50: 412 / 432 / 408 | 37 / 40 / 35 |
| tb_tca_tran | 83 / 80 / 81 | 109 / 110 / 111 | 117 / 122 / 118 | 151 / 151 / 151 | 187 / 188 / 186 | 230 / 228 / 203 | 31 / 35 / 28 |
| charge_pump | 42 / 42 / 42 | 47 / 49 / 47 | 50 / 52 / 49 | 94 / 95 / 94 | 104 / 105 / 104 | 140 / 142 / 137 | 23 / 24 / 23 |
| tca_main | 23 / 24 / 24 | 34 / 35 / 34 | 45 / 45 / 44 | 83 / 85 / 84 | – | – | 13 / 16 / 13 |
| rom8k | 26 / 24 / 31 | 40 / 35 / 50 | 52 / 46 / 65 | 126 / 127 / 149 | 183 / 180 / 193 | – | 25 / 28 / 23 |
| sdfrbp (ihp) | 43 / 40 / 44 | 43 / 40 / 41 | 43 / 41 / 39 | 43 / 41 / 42 | 43 / 42 / 39 | 43 / 41 / 40 | 49 / 47 / 41 |

**What it means.**
- Dragging even one device on an ordinary page is a 20–80 ms frame, which is borderline to a
  noticeable hitch.
- A handful of connected devices is 100–450 ms, which is lag.
- The new look is identical to base here.

**Where the time goes.** Sixteen gdb stack samples during a three-device drag on tb_tca_tran (base
`~/gsl0`) break down like this:

| where the sample landed | samples |
|---|---|
| `move_objects` → the fluid passes (`fluid_reroute_around_obstacles`, `fluid_ml_hazards`/`place_moved_wire`, `fluid_seg_hits_foreign_pin`) or `remove_move_orphan_wires` → `point_on_fixed_pin`, ending in `atof_spice`/`sscanf` | 6 |
| the same paths, ending in `tclgetdoublevar` → `Tcl_GetVar2` | 7 |
| real logic | 1 |
| `XSync` | 1 |
| unresolved frame | 1 |

Eight samples on a 1600-device grid show the same picture.

The leaf comes from `fluid_pin_on_seg()` and `point_near_pin()`. Both start with
`tclgetdoublevar("cadsnap")`, which fetches a Tcl variable and parses it with `sscanf`, and they
are called inside loops over every instance pin × wire segment. One device dragged on an N × (FET +
wire) grid, base, measured:

| N | 100 | 200 | 400 | 800 | 1600 |
|---|---|---|---|---|---|
| ms per frame | 50 | 190 | 800 | 2700 | 10 000 |

H matches within noise (≤ 8 %). About 80 % of the time is re-reading and re-parsing one constant, which
looks like a cheap fix: read `cadsnap` once per pass. The square-law growth would remain.

This is base fluid-editing code, outside this batch, so I did not touch it. It is the strongest
candidate for "what a user will notice". A page with a few hundred devices and wires drags at a few
frames per second on both trees.

## Slow X servers (B → H, ms; Xvfb CPU-throttled)

25 % server CPU:

| page | select all | redraw (all sel) | crosshair (all sel) | drag 3 | drag block | zoom in |
|---|---|---|---|---|---|---|
| bandgap | 3.3 → 9.9* | 9.4 → 14.1* | 8.8 → 0.8* | 23.8 → 29.4* | 32.1 → 35.9 | 7.3 → 9.9 |
| comparator | 3.0 → 10.2* | 10.7 → 13.9 | 9.4 → 1.9* | – | – | 8.1 → 8.5 |
| rom8k | 2.8 → 11.4* | 9.5 → 20.0* | 5.5 → 1.0* | 25.6 → 26.1 | 28.1 → 30.2 | 14.2 → 13.9 |
| sdfrbp | 3.5 → 10.3* | 12.2 → 14.1 | 10.8 → 1.1* | – | 88.4 → 87.7 | 7.9 → 9.6 |
| tcamainW | 1.0 → 5.4* | 3.6 → 6.3 | 2.5 → 0.7* | 27.7 → 28.9 | 9.5 → 10.9 | 6.3 → 7.9 |

12 % server CPU:

| page | select all | redraw (all sel) | crosshair (all sel) | drag 3 | drag block | zoom in |
|---|---|---|---|---|---|---|
| bandgap | 5.9 → 25.1* | 24.5 → 28.6 | 11.2 → 0.7* | 27.9 → 27.9 | 34.1 → 36.8 | 13.0 → 20.8 |
| comparator | 5.4 → 28.5* | 20.8 → 32.7 | 12.9 → 2.7* | – | – | 17.3 → 20.4 |
| rom8k | 7.4 → 24.4* | 24.6 → 33.1* | 12.6 → 1.2* | 32.7 → 25.8* | 33.2 → 33.0 | 29.0 → 29.2 |
| sdfrbp | 8.2 → 20.7* | 17.2 → 29.1* | 16.8 → 1.1* | – | 75.1 → 76.5 | 16.5 → 20.9 |
| tcamainW | 0.8 → 12.6* | 8.2 → 16.3 | 2.4 → 0.6* | 27.5 → 28.9 | 12.4 → 13.1 | 16.5 → 12.7 |

**What it means.** On a slower server the halo's server work shows: select-all costs about 3–4×
classic. Even at 12 % it stays a one-off of 1–2 frames at the click, under the 50 ms "noticeable"
line. Everything continuous (motion, drags, zoom, pan) is equal or better with the halo.

**Caveat on the model.** The throttle limits CPU per scheduling period (4 ms at 25 %, 8.3 ms at
12 %), so times come in steps of that period: 8.2, 16.6, 24.5 and 33 ms are 1–4 periods. It models
a slow renderer, not network latency, and the user's TCP-attached Windows X server was not
measured.

## X traffic

No X protocol tracer is installed: `xtrace`, `x11trace` and `xscope` are all absent. As the brief
says, I did not build one. Request and round-trip counts are therefore **not measured**. To install
one (`apt-cache policy xtrace` shows candidate 1.4.0-1build1):

```sh
sudo apt install xtrace
```

The substitute was server CPU per action from `/proc/<Xvfb pid>/task/*/schedstat` (the "X server
CPU proxy" in the ordinary-actions section above). It says the halo roughly doubles the server's
work at selection time (+0.2–0.7 ms on Xvfb) and cuts it by up to 2 ms per pointer motion while a
selection is up.

## Load and noise

- The machine has 20 cores and was shared throughout with crew A5b (its own Xvfb displays, gsa7
  xschem runs and a klayout job), plus up to four of my own streams on separate displays.
- 1-minute load average over each stream's runs:

  | stream | min | mean | max |
  |---|---|---|---|
  | matrix | 1.4 | 3.8 | 5.6 |
  | net highlight | 1.6 | 6.5 | 10.2 |
  | probe sweep | 4.0 | 5.1 | 6.3 |
  | 25 % matrix | 4.6 | 6.0 | 7.4 |
  | 12 % matrix | 2.4 | 4.8 | 7.4 |

  The load was 1.2 at the start.
- Interleaving and flipping the variant order each round is what makes the B/H comparison fair
  under that load. Absolute figures from the busier streams may run 10–20 % high. That is visible as
  the wider spreads of the highlight matrix's first round (minimums near 15 ms against medians near
  23 ms for go back).
- The gdb runs perturb whole-frame figures slightly; their H drag frames sit within about 10 % of
  the plain B/C runs. They do not perturb the probe intervals, because the stops land outside them.
- **Harness bug, now fixed.** xschem's Tcl clobbers the global `path` (`tclpropeval2` does `global
  path`), and the first net-highlight matrix walked with a global named `path`. Its
  descend/go-back bookkeeping was wrong. It was discarded (kept as `out/h_bad`) and re-run with
  proc-local variables. Each run now checks that it ended back at the top level, and all 192 did.

## What could not be measured

- **The user's real display.** I did not measure the Windows X server (HC-Consult) over TCP, by
  rule. Its round-trip latency and its rendering speed for the halo's wide strokes are unknown. The
  throttled Xvfb is only a stand-in for a slower renderer.
- **X request and round-trip counts.** No tracer is installed (see above).
- **Real hand input.** All input was synthesized. A real pointer sends a stream of motions, and
  the drag numbers are per motion event.
- **The adc descend in the ordinary-actions pose.** It did not enter the sub-block (0.3 ms, still
  at the top). The net-highlight matrix covers the adc descend instead.
- **Comparator and charge_pump block drags in the matrix.** They never entered move mode. The probe
  sweep covers drags on both pages.
- **tb_bandgap's two deepest levels.** The highlight walk reached 2 of its 4 levels: it follows
  the net, and VCC and EN_N stop at the opamp.

## Files

Everything is in the session scratchpad,
`/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/RT/`.

**Scripts** (`scr/`):
- poses: `rtlib.tcl`, `rt.tcl`, `hil.tcl`, `drag.tcl`, `gridrag.tcl`, `census.tcl`;
- drivers: `matrix.sh`, `hilmatrix.sh`, `probesweep.sh`, `slowmatrix.sh`, `xsrv.sh`;
- launchers: `hrun.sh`, `hrun_gdb2.sh`;
- gdb scripts: `dragprobe.py` (the probe-interval breakpoint), `dragwatch.py`, `pmp.py` (stack
  sampling);
- tabulators: `tab.py`, `rtab.py`, `probetab.py`;
- displays: `xstart.sh`, `xstart_slow.sh`, `xstop.sh`.

**Outputs:**
- raw results in `out/m`, `out/h`, `out/hw`, `out/p`, `out/d`, `out/x`, `out/s25`, `out/s12`;
- gdb logs in `log/*.gdb`;
- tables in `log/tab_*.md` and `log/probetab_*.txt`;
- the census in `log/census.txt`.

**Cleanup.**
- All seven of my displays (:270–:276) were stopped by recorded pid, each checked by cmdline and
  `DISPLAY` first.
- No xschem of mine is left running.
- No `*~.sch` or `*~.sym` newer than the start mark exists in `~/gsl0`, `~/gsa6` or
  `~/dev/xschem-claude`, and no file in those trees changed during the run.
- `devdisplay.sh status` reports :99 **stale**: its recorded Xvfb pid 165414 is not running. I never
  started, attached to or signalled :99.
