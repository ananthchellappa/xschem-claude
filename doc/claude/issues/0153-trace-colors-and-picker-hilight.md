# 0153 — multi-plot paints every trace the same color; Direct Plot picker now colors the wire

Status: **FIXED** (2026-07-25)
Area: `src/wave_viewer.tcl` (color policy), `src/ase_window.tcl` (picker),
`src/scheduler.c` (`hilight_netname`/`hilight_instname` `-layer`)
Tests: `tests/headless/test_wave_modes.tcl` — `M6`, `MG6c`, `MG6d`;
`tests/headless/test_ase_plot.tcl` — `PL`, `P4`
Related: 0151 (plot modes / target strip)
Reference: `doc/claude/code_analysis/waveform_subsystem_reference.md` §2.5, §8

## Report

> How are colors assigned to traces? If I plot in single plot mode, they seem to
> get different colors. If I plot in multi plot mode, they are all coming out
> yellow.
>
> What I want: When user enters command mode to
> select-signals-to-be-plotted-on-schematic, as each selected by user, the color
> that will be used to plot that signal should be used to highlight the wire
> corresponding to the signal. This makes it easy to map plots from the Waveform
> Viewer to the schematic.
>
> And yes, even in multi-plot mode, ensure colors are incremented.

## Part 1 — why multi-plot was all one color

`wviewer::next_color` picked the first entry of `wviewer::palette`
(`{4 5 7 8 9 12 14 15 10 11}`, drawing-layer indices) **not used by the landing
graph's own traces**, and `add_trace` called it per trace.

- *single*-plot stacks every signal into one strip, so per-strip uniqueness is
  window uniqueness → colors cycled correctly.
- *multi*-plot (issue 0151) gives each signal a **brand-new empty strip**
  (`plan_plot`), and an empty strip has no used colors → **every** signal got
  palette head `4`, which in the default dark theme is `#88dd00`, a yellow-green.
  Exactly the report.

## Part 2 — the picker had no way to say "this exact color"

Highlight values `>= 0` index the **net-hilight STYLE table**
(`hilight.c get_hilight_style`), and the default table maps style *i* to
`active_layer[i]` — layers **>= 7 only** (`enable_layers`, `actions.c`). Two
palette entries (4 and 5) therefore have **no style at all**, so the existing
`hilight_netname -style N` could not reproduce a trace color.

The engine already had the right mechanism and it was simply unreachable from
Tcl: a **negative** hilight value means "plain color of layer `-value`, no
style" (`get_color`, `hilight_pixel_of`) — which is what `draw.c`'s
`auto_hilight_graph_nodes` path uses via `hilight_graph_node(node, col)`. That
path is useless for the ASE viewer, because the graph lives in the *viewer's*
`xctx` and would highlight nets in the viewer's empty buffer, not the design.

## Decisions (user, 2026-07-25)

- Multi-plot "incremented" = **unique across the whole window**: no two traces
  visible in the viewer share a color until the 10-entry palette is exhausted.
  Single-plot behavior unchanged.
- Picker highlights **persist past ESC** (that is the point — the color map stays
  readable while reading the plots). Pre-existing highlights are **not** wiped on
  entry, so colors may coincide with them.

## Fix

### Color policy (`src/wave_viewer.tcl`, all PURE)

`next_color` was decomposed; its own contract is unchanged.

| proc | role |
|---|---|
| `first_unused_color {used}` | first palette entry not in `used`, else the original D10 `count % len` fallback, verbatim |
| `graph_colors {G}` | one model graph's trace colors, in order ({} for a colorless trace, as the old `used` list had) |
| `colors_in_graphs {gs}` | every color in use anywhere in a strip list, deduped |
| `next_color {G}` | `first_unused_color [graph_colors $G]` — the pre-0153 rule |
| `plan_colors {gs mode targets}` | **the fix**: one color per signal of a batch, simulating accumulation. `used` is seeded from the whole window for `multi`, and per-landing-strip for `single` |
| `predict_colors {token n}` | the colors the next `n` picked signals will get; reads the window's live mode/target/layout, then `plan_plot` + `plan_colors` |

`plan_colors` is **prefix-stable** by construction (a signal's color depends only
on the state and the signals before it) — that is what lets the picker resolve
click *k*'s color while click *k+1* has not happened.

`add_trace` and `plot_signals` gained an optional explicit color / color list.
`plot_signals` derives the colors from `plan_colors` when none are supplied, so
**any** caller gets the multi-plot fix, not only the picker.

### C: an explicit layer color for a highlight (`src/scheduler.c`)

`xschem hilight_netname [-fast] [-style <n> | -layer <n>] <net>` and
`xschem hilight_instname [-fast] [-layer <n>] <inst>`.

`-layer <n>` highlights in the plain color of drawing layer `n` by storing the
negative hilight value described above, and neither uses nor advances the style
cursor. Layer 0 is refused (it is the background, and `-0 == 0 == style 0`), as
is anything `>= cadlayers`. The instance arm restores `hilight_color` on the
error path too.

### The picker (`src/ase_window.tcl`)

- `sod_click` passes the classification (`kind` + the raw net/instance name) into
  `dp_queue` — `ex` is already wrapped as `v(...)`/`i(...)` and is not a
  highlight target.
- `dp_queue` resolves the accepted signal's future color with
  `wviewer::predict_colors` (queue-so-far, take the last), records it in a
  parallel `qcolors` list, and calls the new `ase::ui::dp_hilight`. A duplicate
  re-queue colors nothing.
- `dp_hilight` routes voltage → `hilight_netname -layer`, current →
  `hilight_instname -layer` (a current probe is picked on a source/ammeter
  **body**, which has no wire to color). Fully catch-guarded: an unresolvable
  net must never break the picking mode.
- `sod_end` carries `qcolors` to `dp_finish`, which passes them to
  `plot_signals`. **So the schematic cue and the trace cannot disagree** — the
  color is decided once, at click time, and pinned; there is no second
  prediction to drift.

## Tests + teeth

Pure (`test_wave_modes.tcl` `M6`, runs under `--nogui`): the four helpers, plus
`plan_colors` for both modes including "avoids colors already on screen",
colorless traces, empty batch and prefix stability.

Model end-to-end (`MG6c`/`MG6d`, GUI self-SKIP): multi-plot via `plot_signals`
assigns 3 **different** colors and a later gesture does not reuse them;
single-plot still cycles; explicit colors are honored; `predict_colors` equals
what `plot_signals` then assigns, in both modes.

C verb + picker (`test_ase_plot.tcl` `PL`, `P4`): `-layer` stores the negative
value (read back via `list_hilights all`), works for layer 5 which has no style
entry, `-style` still stores a positive index, out-of-range refused, the style
cursor is left alone; then in the live Direct Plot flow the wire click highlights
net `D` in a plain layer color, the `v(d)` **trace color equals the color painted
on the wire**, the highlight **persists past ESC**, and the two picks differ.

Sabotage-verified:

- **S3b** remove the `plan_colors` call from `plot_signals` (the true pre-0153
  behavior) → `MG6c` reports `{4 4 4}`, the reported defect, and 4 legs FAIL.
- **S3** remove only the window-wide seed → the two "already on screen" legs
  FAIL (within-batch accumulation still covers the rest — recorded so the
  narrower hole is not mistaken for uncovered).
- **S4** make `dp_hilight` a no-op → the `P4` wire-click legs and the `PL`
  refusal legs FAIL.

## Not verified / honest limits

- **Pixels.** That the wire and its trace *look* like the same color is
  eyeball-only. What is asserted is that the highlight value is `-C` and the
  trace color token is `C`, for the same `C` — they resolve through the same
  `xctx->color_index[C]`.
- **Instance highlights are not read back.** `list_hilights` walks the net hash;
  an instance highlight goes to `inst_hilight_hash_lookup` + `inst[].color`. The
  current-probe arm is asserted only as accepted / no-throw.
- **`qcolors` pass-through is redundantly covered.** Dropping it would leave the
  `P4` color-match leg passing, because `plot_signals` would derive the same
  colors from the same policy. The channel itself is covered by `MG6c`
  ("explicit colors are honored verbatim"), not by `P4`.
- **Color collisions with pre-existing highlights** are possible by decision
  (entry does not wipe them).
- The **Add Trace… dialog** and **auto-plot** deliberately ignore the plot mode
  (0151) and keep using per-graph `next_color`; nothing here changed that.
