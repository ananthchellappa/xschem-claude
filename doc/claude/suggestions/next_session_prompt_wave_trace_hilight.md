# Session prompt — net-highlight styles on waveform traces

*Written 2026-08-01. Paste the block below into a fresh session.*

---

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Implement **net-highlight styles on waveform traces** in the ASE Waveform Viewer.
The spec is `doc/claude/specs/wave_trace_hilight.md` and its decisions D1-D8 are
**LOCKED** — read it first, in full, and do not re-litigate them. Read
`doc/claude/code_analysis/waveform_subsystem_reference.md` before touching any of
this (it is the map; landmines 11, 16, 17, 19, 33, 34, 37, 38, 40, 43, 44, 46, 50
are all live on this path), then `doc/claude/specs/net_hilight_styles.md` §3 and
`doc/claude/specs/apply_hilight.md`.

## The feature in one paragraph

A trace is a polyline with no junctions and no direction, so the entire
net-highlight vocabulary applies to it unchanged. In a viewer window, `9` applies
the current highlight style to the **selected** trace(s), `8` removes it from
them, `0` removes every trace highlight in the window — the schematic's own three
keys, on the `WaveViewer` bindtag, remappable from an rc. An ad-hoc style works
the way it already does for nets:
`wviewer::apply_style_traces_at %W {color purple thickness 3 pattern {20 20}}`.
The style is drawn as an **overlay on top of** the trace, which keeps its palette
colour.

## The one requirement that decides the design

The animated case (blink, marching ants) must cost the same whether the trace has
200 samples or 200 000. Two things follow, and both are in the spec:

1. **Do not stroke the real polyline.** Stroke a cached **min/max envelope at one
   point per screen column** (§5.2). On a dense trace that reproduces the same
   solid band; on a sparse one it degenerates to the samples themselves. Cache it
   keyed on the data window + plot box, so a marching frame rebuilds nothing.
2. **Do not reuse `draw_hilight_region()`'s frame.** It is `bbox(SET) → draw()`,
   a clipped full redraw. That is cheap for a wire and catastrophic for a trace,
   whose bbox is the whole strip. The overlay is window-only chrome, erased with
   `MyXCopyArea` from `save_pixmap` — the shipped `graph_snap_erase()` mechanism.
   §6 has the split, including the case where a schematic-embedded graph makes
   both kinds of highlight animate at once.

And the gate that will otherwise make the whole feature silently dead:
`net_hilight_has_animation()` and `draw_hilight_region()` both open with
`if(!has_x || !xctx->hilight_nets) return 0;`. **A viewer has no highlighted
nets.** Both need the `wave_hilight_n` term.

## Order of work

1. **C data + predicate** (§4.2/§4.3): fixed arrays in `xctx`, reset in
   `clear_drawing()` *and* `alloc_xschem_data()`, one `wave_hilight_style_of()`
   that every site goes through.
2. **The envelope builder + cache** (§5.2), modelled on `graph_point_at()` rather
   than freshly written — the sweep-token-before-any-`continue` rule (landmine
   38) and the switch-only-restore-if-it-took rule (landmine 40) are not
   optional.
3. **The overlay painter** (§5.3) at the tail of `draw()`, window-only, with the
   drawer carrying its own context test (landmine 44).
4. **The verbs** (§7.1), in the matching first-letter dispatch function.
5. **The animation hook** (§6): the fourth loop in `scan_animating_hilights()`,
   the frame split, the two gate terms.
6. **The Tcl layer + keys** (§7.2/§7.3), including the `regenerate` re-apply
   bracket that D4 owes.
7. **The remaps** (§8) — reuse the existing PURE helpers, write no new ones.
8. **Tests** (§10) and **the guide** (§12).

## Verification — the parts that are easy to fake

- **The cost claims are the feature.** `WD*` must assert the decimated point
  count on a ≥ 50 000-sample trace, the exact count on a sparse one, **zero
  `draw()` calls per animation frame** (the `-d 1` probe
  `wviewer::delete_all_markers` already uses), and that a steady style arms no
  tick. A leg that only asserts "the highlight appears" measures nothing.
- **Plant TWO highlighted traces in every leg that can.** With one, a bare
  `gi == … && ni == …` and the `wave_hilight_style_of()` predicate agree exactly,
  so a missed call site is invisible — the 0175/0189/0192 lesson, three times
  paid for. Assert the call sites at SOURCE level as well (`count_code`, the
  `LS5`/`MS13` idiom).
- **Sabotage before believing the suite** (memory `green-but-hollow`): drop the
  `wave_hilight_n` gate term, and swap the predicate for a bare head comparison.
  If either leaves the file green, the file is not testing the feature.
- The overlay's **pixels** are eyeball-only. Say so, and eyeball them: run
  `src/xschem --script src/cadence_style_rc --logdir /tmp`, open a session,
  plot two traces, select both, press `9`, and watch a marching style actually
  march. A green suite is not a rendering.

## Discipline

- The user runs `src/xschem --script src/cadence_style_rc --logdir /tmp`; the
  surface that matters is the **ASE waveform window**.
- ⚠ **Never** `pkill -f 'src/xschem'` — that pattern matches the user's live
  session. Kill only PIDs you launched, after reading `pgrep -af xschem`.
- Anything under a real `$DISPLAY` goes through the GUI gate: use
  `tests/headless/run_suites.sh` or `tests/headless/gated_xschem.sh`, never a
  bare loop, and press `Allow 30m` / `Allow 2h` once instead of clicking Proceed
  repeatedly.
- **KNOWN-FLAKY, not yours**: `test_cadence_drag`, `test_wave_trace_menu` TG9,
  `test_ase_plot` P4/P6/P8, `test_hover_highlight`, `test_palette`. The check
  COUNT is the signal, not the verdict.
- `src/Makefile` lists objects explicitly — a new `.c` file needs an `OBJ` entry
  and a rule. Prefer putting this in `draw.c` (the coordinate macros need a local
  `Graph_ctx`) and `hilight.c` (the style/animation math), which is where the
  existing halves already live.
- Git: explicit file list, no `git add -A`, no `git reset --hard`, no
  `git push`. Commit message ends with:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

## Deliverables

1. The feature, per the spec's §4-§8.
2. `tests/headless/test_wave_hilight.tcl` with the `WH*` / `WD*` / `WG*` / `SAB*`
   groups of §10, and the sabotage results reported.
3. `doc/waveform_viewer_guide.html` updated: three rows in §9.1 with their
   `data-seq` attributes, the rc remap in §10.1, the accepted imperfections of
   §5.5 in one sentence, and the schematic-vs-viewer meanings in §9.5's collision
   table. **`tests/headless/test_wave_grid.tcl` `GH2` fails until the doc rows
   exist** — that check counts shipped `WaveViewer` defaults against documented
   ones, so the documentation is enforced, not requested.
4. `src/cadence_style_rc`: commented example lines for remapping `9`/`8`/`0` and
   for an ad-hoc style key, matching the shape of the existing `Ctrl-D` / `e` /
   `Ctrl-G` blocks.
5. An explicit list of what you could not exercise.
