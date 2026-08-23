# 0615 — node voltages render in the SAME layer as the OP block, so the two annotations are indistinguishable

STATUS: **OPEN — requested by the user 2026-08-22.** Pairs with
[0614](0614-annot-chords-must-own-node-voltages.md) (same predicate, same draw
pass). Related: 0613 (the measurement that found both).

---

## The request, verbatim

> "for node voltage display, use white, not same color as the OP info."

## Measured — it is literally the same layer number

| annotation | carrier | layer |
|---|---|---|
| device OP block (the six rows) | `xschem_library/devices/annotate_params.sym:9` | **15** |
| node voltage | `devices/lab_pin.sym:32`, `ipin.sym:36`, `iopin.sym:36`, `bus_tap.sym:37` | **15** |
| branch current | `devices/ammeter.sym:40`, `capa.sym:58`, `ind.sym:53`, `diode.sym:51`, `isource.sym:43`, `bsource.sym:39`, `cccs.sym:49`, `isource_table.sym:44` | 17 |

Layer 15 resolves to `#ff7777` on the dark palette and `#aa2222` on the light one
(`src/xschem.tcl:16405/16412`). So the OP block and every node voltage are drawn
in the *identical* colour — the user cannot tell which subsystem produced a
number, which is exactly the confusion 0613/0614 is about. Branch currents at
layer 17 (`#00ffcc`) already differ; only the voltages collide.

## What "white" costs — the crew must decide this, and record it

There is **no layer that is white in both themes**
(`src/xschem.tcl:16400-16412`):

| layer | dark | light |
|---|---|---|
| 9 | `#ffffff` **white** | `#00aaaa` teal |
| 3 | `#cccccc` near-white | `#222222` near-black |
| 0 (BACKLAYER) | `#000000` | `#ffffff` |

White text on the light palette's white background is **invisible**. So a hard
`#ffffff` satisfies the request on the user's dark setup and silently deletes the
annotation for anyone on light. Options, in the order the decision ladder ranks
them:

1. **RATIFIED BY THE USER 2026-08-22 — "Go with layer 9 for node voltages."**
   A dedicated layer index, default 9, exposed as a config var
   (`annot_voltage_layer`, mirrored in Tcl like its siblings). White on dark out
   of the box — which is what was asked for — remappable in one line, and it
   travels through the existing per-layer colour machinery, so a user who
   switches to the light palette gets layer 9's light entry rather than a hole.
   **This is the decision. Options 2 and 3 below are recorded only so nobody
   re-opens them.**
2. Hard-code white at the draw site for the VOLTAGE class. Satisfies the letter
   of the request; breaks the light palette. Only acceptable with an explicit
   background-luminance fallback, which is more machinery than option 1.
3. Edit the layer number in all twelve shipped `.sym` files. Rejected for the
   same reason 0614 rejects its option A: library churn, and a third-party or
   user PDK symbol never gets the treatment.

## Landmines

- Do this in the **same pass** as 0614. Both need one predicate — "is this text
  a node-voltage / branch-current annotation" — and implementing it twice is
  invariant **I1**'s failure mode (two builders that drift, silently).
- The colour must apply to the **resolved annotation**, not to the symbol at
  rest: a `lab_pin` with no raw loaded must look exactly as it does today (I7).
- Branch currents (layer 17) are already distinct. Decide explicitly whether they
  join the voltage colour or keep 17, and write down which — do not leave it to
  whichever branch of the predicate happens to run.
- The colour override must reach **all three back ends** the way the visibility
  test does: `draw.c`, `svgdraw.c`, `psprint.c`. An override in `draw.c` alone
  means the schematic on screen and the exported PDF disagree.

## Acceptance

- With a raw loaded and `Alt-6`: node voltages are visibly a different colour
  from the six-row OP blocks, white on the default dark palette.
- Same schematic exported to SVG and to PostScript shows the same two colours.
- With no raw loaded, the sheet renders byte-identically to before (I7).
