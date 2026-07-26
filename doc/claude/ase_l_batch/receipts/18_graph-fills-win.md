# Receipt — item 18 graph-fills-win (round-5, Waveform Viewer core fix)

Verdict: **DONE** [x]. The Waveform Viewer no longer looks like a schematic window
(grid canvas with a small 800x400 graph rect floating in it that shrank on
out-of-graph canvas zoom); the graph now FILLS the viewer window, the schematic
grid/origin chrome is off in the viewer (and ONLY the viewer), the graph re-fills
on resize, and Add Graph splits the window into equal full-width vertical bands.
No fixer rounds. Not pushed.

## Shipped commit (not pushed)

Single feature commit on `fluid-editing`, HEAD = **dc249553**
`feat(ase): Waveform Viewer graph fills the window (item 18 graph-fills-win)`.
Exactly the five in-scope files staged explicitly; no pre-batch dirty tracked file
swept in; not on any remote branch.

| File | Δ | What |
|------|---|------|
| `src/xschem.h`                        | +3   | new per-window field `int no_grid` (after `only_probes`) |
| `src/draw.c`                          | +7/-1 | `drawgrid()` early-out extended with `xctx->no_grid`, kept FIRST in the guard chain |
| `src/scheduler.c`                     | +8   | `xschem get no_grid` (getter) + `xschem set no_grid` (setter) |
| `src/wave_viewer.tcl`                 | +117 | viewport_rect + band_geometry, no-zoom_full regenerate, `<Configure>` refit, `no_grid 1` at open |
| `tests/headless/test_wave_viewer.tcl` | +232 | H-band1..4, RG0..2, GF1..5; updated fixed-slot asserts (H4→H-band, G10, G14) |

## Ledger-agent re-verification (at HEAD = dc249553)

- Commit `--name-only` matches the five-file claim; `git merge-base --is-ancestor
  dc249553 HEAD` = HEAD itself; `git branch -r --contains` empty (not pushed).
- Anchors re-confirmed from source (see "Corrected anchors" below): `no_grid`
  field xschem.h:1502; drawgrid gate draw.c:1150 (comment :1147, no_grid FIRST);
  scheduler getter :3982/:3984, setter :10076/:10078; wave_viewer procs
  `open` :224 (`xschem set no_grid 1` :262, `bind $wp <Configure>` APPEND :312),
  `viewport_rect` :487, `band_geometry` :508, `on_configure` :519,
  `configure_apply` :527, `regenerate` :651 (D4 no-zoom_full note :708),
  `place_graph_rect` :724, `fit` :1102 (keeps its own zoom_full :1134 — item 19).
- Test legs all present in the committed file: H-band1..4, RG0..2, GF1..5
  (grep-confirmed); band_geometry/viewport_rect/no_grid referenced 28×.

## What landed (D1–D7, maps 1:1 to PLAN item-18 points 1–5)

- **D1 — grid/chrome OFF viewer-only.** New per-window C flag `int xctx->no_grid`
  (xschem.h:1502, after `only_probes`; zeroed by `alloc_xschem_data` for every
  ctx). `drawgrid()` early-out extended to
  `if(xctx->no_grid || !tclgetboolvar("draw_grid") || !has_x) return;`
  (draw.c:1150) — no_grid stays FIRST so the 0082 shared-GC dash ordering is
  preserved. `xschem get/set no_grid` (scheduler.c getter :3982, setter :10076).
  `wviewer::open` sets `no_grid 1` once (wave_viewer.tcl:262) — never cleared,
  NOT mirrored in Tcl so nothing clobbers it. The window reads as a graph, not a
  schematic.
- **D2/D4 — single graph fills the viewport + canvas-zoom shrink killed.** New
  pure-Tcl `wviewer::viewport_rect {wp}` (:487) inverts `X_TO_XSCHEM`
  (`px*zoom - xorigin`) from `xschem get zoom/xorigin/yorigin` + winfo W/H — **NO
  new C accessor** (the PLAN's fallback option; pure-Tcl computed cleanly). D4:
  `regenerate` (:651) no longer `xschem zoom_full`s (note :708) — verified
  clear_drawing/redraw never touch zoom/origin, so the canvas viewport stays
  pinned and the graph fills regardless of any canvas zoom. `wviewer::fit`
  (:1102) keeps its own zoom_full (:1134) for item 19.
- **D3/D5 — multi-graph + refit.** The fixed-slot `wviewer::graph_geometry`
  REMOVED, replaced by pure `wviewer::band_geometry {i n vx1 vy1 vx2 vy2}` (:508)
  — equal full-width vertical bands, no gap. regenerate places bands and rebuilds
  the graphbb from the SAME bands. Debounced `<Configure>` refit:
  `bind $wp <Configure> "+[list wviewer::on_configure $token]"` (:312, APPENDED —
  kept in `keepseqs`); `on_configure`/`configure_apply` (:519/:527) coalesce via
  `after idle` and re-fill only on a real pixel-size change (fillwh gate).
- **D5 (regression) — normal windows untouched by construction.** Normal
  schematic windows never call `wviewer::` and keep `no_grid = 0` → grid draws +
  embedded graph rects untouched. RG1/RG2 prove this empirically (ne555 shipped
  graph read-only, grid still drawn, rect unchanged).
- **D6/D7 — tests + no C-side automated grid witness.** GUI legs assert fill,
  resize-refit, two-graph half-fill, no-reframe; the draw-side grid-off gate
  (draw.c:1147/:1150) has no pixel-level automated witness and is eyeball-only —
  S-wiring proves the flag wiring instead.

## Tests

`tests/headless/test_wave_viewer.tcl` — **188 checks** GUI run (`RESULT: ALL PASS
(188)`); **48** under `--nogui` (headless-computable legs). DISPLAY-guarded
self-SKIP without a display.

- **H-band1..4** — pure `band_geometry` tiling (whole-number viewport → exact
  integer bands `{0 0 1000 800}` etc; equal full-width contiguous bands).
- **RG0** — `xschem get/set no_grid` roundtrip.
- **RG1/RG2** — normal-window regression: grid still drawn + embedded ne555 graph
  rect unchanged (grid-off + fill is viewer-window-only).
- **GF1** — single graph fills the viewport (rect bbox ≈ viewport within margin).
- **GF2** — viewer `no_grid == 1` here / grid on elsewhere (the flag-wiring
  witness).
- **GF3** — resize the toplevel → graph still fills (refit ran + grew).
- **GF4** — two graphs each fill a half.
- **GF5** — regenerate never re-frames the canvas (no zoom_full shrink).
- Updated fixed-slot asserts to viewport-relative geometry: **H4 → H-band**,
  **G10** (i*450 slot → viewport bands), **G14** (full-viewport fill) — rationale
  is the item-18 geometry replacement itself.

Implementer full audit (DISPLAY=:0, all 221 tests + wireedit): 208 pass / 13 fail
/ 0 crash / 0 timeout / 0 skip, WIREEDIT PASS. All 13 fails a STRICT SUBSET of the
batch-start baseline; ZERO non-baseline failures (the other baseline WSLg-flaky
tests happened to pass this run). C builds clean (`cd src && make`). All 11
protected ASE/wave suites green: test_ase_core 66, view 36, window 155,
dialogs 133, interact 63, persist 109, launch 38, plot 102, dirty 41, final 28,
test_wave_viewer 188.

## Sabotage table (three; each failed EXACTLY its target)

| # | Sabotage | Target | Exact? |
|---|----------|--------|--------|
| S-refit  | `on_configure` returns immediately (graph does not grow/refit on resize) | only GF3 resize-refit legs (3 checks) FAIL; everything else green | yes |
| S-wiring | comment out `xschem set no_grid 1` in `wviewer::open` | only GF2 `viewer no_grid == 1` (1 check) FAILS | yes |
| S-band   | `band_geometry` returns the old fixed i*450 slot | only the viewport-relative-geometry class (24 checks: H-band1..4, G10 contiguity/width, GF1/GF3/GF4/GF5 fill) FAILS; RG0/1/2, GF2, cursors, dialogs all pass | yes |

Revert mechanism (documented deviation, same guarantee as receipts/15/16/17): the
item-18 changes were still uncommitted at sabotage time, so `src/wave_viewer.tcl`
sabotages were reverted by targeted reverse-Edit (not `git checkout -- <file>`,
which would have wiped the uncommitted feature), confirmed sabotage-only by
`git diff` before/after; a clean re-run then went green (188).

## Fix-round history

None. Single feature commit dc249553; no fixer rounds; all three verifier lenses
clean on first pass.

## Deviations (accepted, reality-forced)

1. **Band formula.** `band_geometry` uses `vy1 + (i*span)/n` rather than the
   PLAN D3 pseudocode's `bandh = span/double(n)`. Dropping the `double()` cast
   makes whole-number viewports produce the exact integer band values the H-band
   assertions require (`{0 0 1000 800}`), while fractional GUI viewports still
   tile exactly contiguously. Same tiling, strictly better formatting.
2. **No new C accessor (PLAN option honored).** The PLAN allowed adding a minimal
   `xschem get` viewport-in-schematic-coords accessor "if not cleanly computable
   pure-Tcl." It WAS cleanly computable — `viewport_rect` inverts `X_TO_XSCHEM`
   from existing `xschem get zoom/xorigin/yorigin` + winfo W/H — so no accessor
   was added. The one C touch is the orthogonal per-window `no_grid` flag (D1).
3. **Sabotage revert by Edit, not `git checkout`** (see sabotage table) — forced
   because the feature was uncommitted during verify.

## Outstanding problems

**None.** Empty problem list at ledger time; working tree clean at HEAD for all
five committed files. Interaction rebinding (wheel / RMB zoom-box / graph-not-
canvas Fit) is explicitly OUT of scope here — that is item 19 (graph-interact),
which depends on this item making the pointer always inside a graph.

## Corrected anchors worth keeping (verified at HEAD dc249553)

- **Grid-off flag**: `int xctx->no_grid` **src/xschem.h:1502**; zeroed for every
  ctx by `alloc_xschem_data`.
- **Draw gate**: `drawgrid()` early-out **src/draw.c:1150**
  (`if(xctx->no_grid || !tclgetboolvar("draw_grid") || !has_x) return;`), no_grid
  FIRST per the 0082 shared-GC dash ordering (rationale comment :1147). No
  automated pixel witness — eyeball-only; S-wiring proves the flag path.
- **Accessors**: `xschem get no_grid` **src/scheduler.c:3982/:3984**;
  `xschem set no_grid` **:10076/:10078**.
- **Viewer procs (src/wave_viewer.tcl)**: `wviewer::open` :224 (sets
  `xschem set no_grid 1` :262; APPENDS `bind $wp <Configure>` :312, kept in
  `keepseqs` :117/:143); `viewport_rect` :487 (inverts X_TO_XSCHEM, no new C
  accessor); `band_geometry` :508 (equal full-width vertical bands, replaced the
  removed fixed-slot `graph_geometry`); `on_configure` :519 + `configure_apply`
  :527 (debounced refit via `after idle`, fillwh pixel-size gate);
  `regenerate` :651 (NO `xschem zoom_full` — D4 note :708, so the canvas viewport
  is pinned and the fill is never re-framed/shrunk); `place_graph_rect` :724;
  `fit` :1102 keeps its OWN `xschem zoom_full` :1134 for item 19.
- **PLAN anchors superseded by this item**: the fixed 800x400 / i*450
  `graph_geometry` (old wave_viewer.tcl:444) is GONE — replaced by
  `band_geometry`; the regenerate-ending `xschem zoom_full` (old :608) is GONE.
