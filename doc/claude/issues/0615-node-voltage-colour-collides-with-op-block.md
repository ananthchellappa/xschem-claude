# 0615 — node voltages render in the SAME layer as the OP block, so the two annotations are indistinguishable

STATUS: **IMPLEMENTED 2026-08-22** — see the implementation section at the
bottom. Layer 9 landed as the configurable `annot_voltage_layer`, all six colour
sites in three back ends. Residuals: **0624**, **0625**, and a note added to
**0619**. Originally: **requested by the user 2026-08-22.** Pairs with
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

---

# ✅ IMPLEMENTED 2026-08-22 — in the SAME pass as 0614, one predicate, six colour sites

Committed on branch `annotate`. The full decision table, sabotage matrix and
residual list live in **[0614](0614-annot-chords-must-own-node-voltages.md)**'s
implementation section; this section records only what is 0615's own.

## BEFORE (Measure agent, verbatim)

```
annot_show 3 :   1.234|#ff7777          <- node voltage
                 gm = 765u|#ff7777      <- OP block   ** IDENTICAL **
                 7.891u|#00ffcc         <- branch current (already distinct)
PS node voltage  (1.234)     RGB -> 0.664062 0.132812 0.132812 RGB
PS OP block      (gm = 765u) RGB -> 0.664062 0.132812 0.132812 RGB
xschem get annot_voltage_layer -> rc=0 result=''
xschem set annot_voltage_layer 9 -> rc=0 result=''   (a silent no-op: BOTH dispatch halves swallowed the word)
```

## AFTER — three distinct colours where the user measured two

SVG:

```
1.234      fill=#ffffff   layer 9    <- node voltage
id =       fill=#ff7777   layer 15   <- OP block
gm = 765u  fill=#ff7777   layer 15
7.891u     fill=#00ffcc   layer 17   <- branch current
```

PostScript — **the back end the prior-art patch never touched**:

```
(1.234)      -> 0 0.664062 0.664062 RGB   = #00aaaa = light_colors[9]
(gm = 765u)  -> 0.664062 0.132812 0.132812 RGB = #aa2222 = light[15]
(7.891u)     -> 0 0.996094 0.796875 RGB   = #00ffcc = [17]
```

With `annot_voltage_layer -1` the same PS string reverts to `#aa2222`, which is
the off-switch working. Note `psprint` uses the **light** palette — a PS
expectation must be written against `light_colors`, not dark.

The screen path was checked too, and it is **not** SVG-only: `xschem print png`
runs `print_image()` -> `draw()`. Under Xvfb the four masks give four distinct
PNGs (5457 / 8588 / 7079 / 9990); pure `#FFFFFF` pixels appear **only** at masks
2 and 3; `annot_voltage_layer -1` -> `#FF7777`, `7` -> `#FF0000`.

## The three landmines this issue named, each answered

1. **"Do it in the same pass as 0614."** Done — one classifier
   (`annot_content_class`), one predicate branch (`text_hidden`), one layer helper
   (`annot_text_layer`), no second builder. Invariant **I1** held.
2. **"The colour must apply to the resolved annotation, not the symbol at rest."**
   Held: `annot_text_layer()` takes the same `ctx` the predicate does and applies
   the D3 floater rule, so a schematic-own NON-floater bare token keeps its own
   `layer=15` and its literal text. Verified cross-binary: a pristine HEAD build
   and the patched build export **16/16 byte-identical SVGs** across four shipped
   sheets × four masks with no raw loaded.
3. **"Decide explicitly whether branch currents join the voltage colour or keep
   17, and write down which."** → **decision D4: they JOIN THE SWITCH (bit1) and
   KEEP LAYER 17.** Re-derived, not inherited from the prior art: 0613's
   surviving-`Ctrl-6` list contains the branch currents, so "`Ctrl-6` -> nothing"
   is false without them; and layer 17 is `#00ffcc` in **both** palettes across 84
   shipped records, already distinct from both 15 and the new 9, while the user's
   request named voltages only. Written into `xschem.h`, `actions.c` and row U17.
   Rejected: a third mask bit (`Alt-6` would become 7 — a fourth state against a
   three-row ruling table); folding currents into `annot_voltage_layer` (erases a
   15-vs-17 distinction the user already has).
4. **"The override must reach all three back ends."** Six sites, two per back end,
   verified by exact-call count: `grep -c 'annot_text_layer(' src/{draw,svgdraw,psprint}.c`
   = `2 2 2`. The **prior-art patch covered four of six** — its own comment claimed
   "psprint.c ×2" and its diff did not contain `psprint.c`. Sabotage variant SB-C
   reproduces exactly that hole in-tree and reds **U18 + U30 only** — the file-set
   row U19 stays green, which is the proof that U19 alone would have shipped it.

## The config var

`annot_voltage_layer`, default **9**, per-context (`xctx->annot_voltage_layer`),
MIRRORED IN TCL, pulled inside `annot_show_sync_cache()` with `tclgetvar()`.

- `xschem get annot_voltage_layer` -> `9` at rest; `set 7` -> `get 7` and
  `::annot_voltage_layer == 7`.
- A **Tcl-only** write reaches the very next export (the pull rides all eight
  bulk-evaluation entry points — issue 0453's staleness shape).
- **Any index outside `[1, cadlayers)` means NO OVERRIDE** (decision D7): `0`
  (== BACKLAYER, i.e. the background colour), `-1`, `999` and `"abc"` all fall
  back to the text's own layer. `-1` is the documented off-switch.
- `set_ne annot_voltage_layer 9` in `src/xschem.tcl` **and** an entry in
  `tctx::global_list`, or it reverts on a tab switch.

## STILL OPEN — 0615's own residuals

1. **Layer 9 is now a single point of failure for all node-voltage annotation.**
   All three back ends guard instance text with
   `inst.color == -PINLAYER || xctx->enable_layer[textlayer]`. A user who
   disables layer 9 in the Layers menu silently loses **every** node voltage —
   consistently across screen/SVG/PS, so nothing diverges, but it is an
   **undocumented second off-switch that looks exactly like the feature being
   broken**. Worth a line beside the documented `annot_voltage_layer -1`.
2. **A missing vector renders `-`, not blank — and 0615 has just made those
   hyphens WHITE.** Pre-existing `translate()` behaviour, and *not* a stale or
   plausible-wrong number (verified across a raw switch), but invariant **I3**
   says "renders BLANK" and the display visibly does not. Filed as
   **[0625](0625-a-missing-vector-renders-a-hyphen-not-blank-which-contradicts-invariant-i3.md)**.
3. **`psprint.c`'s colour push at `:1224` now fires under a NEW condition** — for
   a case the shipped tree does not contain. A classified voltage text with **no
   explicit `layer=`** used to clamp to `c_for_text` (no push, no pop) and now
   gets layer 9 (push + the asymmetric pop at `:1258` that reads
   `ps_colors[cadlayers]`, issue **0619**). Every shipped voltage carrier spells
   `layer=15`, so today's frequency is unchanged — but a **user** symbol with a
   bare `@spice_get_voltage` and no `layer=` would newly reach 0619's over-read.
   0619 was deliberately not fixed here; this change neither fixes nor widens it
   on the shipped corpus, and adds **no** new `set_ps_colors` call.
4. **The explicit-`hide=voltage` colour half has no guardian** — sabotage SB-G's
   missing red. Filed as
   **[0624](0624-an-explicit-hide-voltage-records-colour-half-has-no-guardian.md)**.
5. D9's wording split (status line says "node voltages", the View checkbutton says
   "node voltage / branch current") is an unratified cosmetic decision; recorded
   here rather than filed, since only 0621 was judged worth the user's attention.
