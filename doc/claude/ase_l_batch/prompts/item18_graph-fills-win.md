# Implementer prompt — ASE-L item 18 `graph-fills-win` (Round 5 core fix)

Repo: `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
You are the IMPLEMENTER. Execute this end-to-end: code, tests, sabotage-verify,
ONE commit with the explicit file list at the bottom. Do NOT touch PLAN.md or any
receipt/ledger (the Ledger role owns those). Do NOT push.

## READ FIRST (in order)
1. `doc/claude/ase_l_batch/RUNBOOK.md` — policies are non-negotiable (copied verbatim at the end of this file).
2. `doc/claude/specs/waveform_viewer.md` — viewer contract; especially "Item 12/13/14 notes".
3. `doc/claude/specs/ase_l.md` — parent ASE-L spec.
4. `src/wave_viewer.tcl` — the viewer window (namespace `wviewer::`).
5. Receipts `doc/claude/ase_l_batch/receipts/11_*.md … 14_*.md, 17_*.md` for context.

## The user bug (what "done" looks like)
The Direct-Plot / Waveform viewer currently looks like a *schematic* window: a grid
canvas with a small fixed 800x400 graph rect floating in it. Zooming the canvas
while the pointer is outside the graph shrinks that rect. The fix: the graph must
**FILL the whole viewer window**, the grid/schematic chrome must be OFF in the viewer
(and ONLY the viewer), the graph must re-fill on window resize, and multi-graph
(Add Graph) splits the window into equal full-width vertical bands. Do NOT do the
wheel/RMB/zoom-interaction rebinding — that is item 19.

---

## Corrected anchors (re-verified from source 2026-07-22; the item brief's line
## numbers had drifted — these are the TRUE current lines)

| What | Brief said | TRUE current location |
|------|-----------|----------------------|
| `wviewer::graph_geometry {i}` (fixed `i*450`, `800x400`) | :444 | **src/wave_viewer.tcl:457** (body 458-460) |
| `wviewer::place_graph_rect` | :618 | **src/wave_viewer.tcl:631** |
| `wviewer::regenerate` proc | — | **src/wave_viewer.tcl:573** |
| `xschem zoom_full` (canvas-zoom shrink) inside regenerate | :608 | **src/wave_viewer.tcl:621** (redraw at :622) |
| graphbb rebuilt from `graph_geometry` inside regenerate | — | **src/wave_viewer.tcl:615-619** |
| `wviewer::fit` `xschem zoom_full` | — | **src/wave_viewer.tcl:1041** (LEAVE — item 19) |
| `keepseqs` list incl. `<Configure>` (kept by strip; append-safe) | — | **src/wave_viewer.tcl:115-118** |
| `wviewer::open` (window build; add `<Configure>` bind + `set no_grid`) | — | **src/wave_viewer.tcl:213-310** |
| `wviewer::over_graph` (uses graphbb) | — | **src/wave_viewer.tcl:1338** |
| `wviewer::btn3_filter` / `strip_bindings` install | :1376 | **src/wave_viewer.tcl:1388 / :1412-1420** (leave — item 19) |
| `drawgrid()` proc + early-out guard | 3568-3572/3668-3677 (that's the graph box) | **src/draw.c:1123** proc; guard **:1147** `if( !tclgetboolvar("draw_grid") \|\| !has_x) return;`; called at **:5958** `if(!xctx->only_probes) drawgrid();` |
| C graph box drawn from rect corners `r->x1..r->x2` | 3568-3572 | **src/draw.c:3569-3572** (`gr->rx1=r->x1 …`); 14% margin inset **:3662-3675** |
| graph interaction routes via `graph_master` = graph under pointer | callback.c :109 | **src/callback.c:109/114** `POINTINSIDE(...)`; set `xctx->graph_master=i` **:126**, `=-1` **:134** (item-19 context only) |
| coord transform macros | — | **src/xschem.h:439-440** `X_TO_XSCHEM(x)= x*xctx->zoom - xctx->xorigin`, `Y_TO_XSCHEM(y)= y*xctx->zoom - xctx->yorigin` |
| `xschem get zoom/xorigin/yorigin` | — | **src/scheduler.c:4306 / :4270 / :4288** (all per-window, read `xctx->`) |
| `xschem get rects <layer>` | — | **src/scheduler.c:4065** |
| `xschem get no_draw` getter (case 'n' bucket, mirror shape) | — | **src/scheduler.c:3975-3981** |
| `xschem set no_draw` setter (`argv[2][0] >= 'n'` branch) | — | **src/scheduler.c:10067-10071** |
| `xctx` struct draw-suppression flags (`only_probes`, `no_draw`, `draw_window`) | — | **src/xschem.h:1501 / :1504 / :1526** |
| `alloc_xschem_data` zeroes the ctx (`my_calloc`) → new fields default 0 per window | — | **src/xinit.c:617** |
| existing fixed-geometry test assertions to UPDATE | — | **tests/headless/test_wave_viewer.tcl:237-238 (H4), :558-561 (G10), :696 (G14)** |

`no_grid` is a FREE symbol (grep-verified: no existing use anywhere in `src/`).

---

## Design decisions (RESOLVED by the scout — implement exactly these; each justified)

**D1 — Grid/chrome-off = a per-window C flag `xctx->no_grid`, NOT the global `draw_grid`.**
`draw_grid` is a single global Tcl var shared by every window/context; flipping it
would drop the grid in normal schematic windows too (the item forbids that). A
per-context `int no_grid` in `Xschem_ctx` scopes grid-off to the viewer's own ctx
with zero effect on other windows — exactly the `only_probes` precedent (draw.c:5958).
`alloc_xschem_data` calls `my_calloc` (xinit.c:617) so every new window's `no_grid`
defaults to 0 = grid on. The viewer sets it once at open and never clears it. It is
NOT mirrored to any Tcl var (nothing syncs it on window switch, so it can't be
clobbered — unlike the `en_pin_select` desync that needed re-sync).

**D2 — Viewport rect is computed PURE-TCL; NO new `xschem get` accessor.**
Inverting the documented transform (xschem.h:439-440): a canvas pixel `px` maps to
schematic `px*zoom - xorigin`. So the schematic-coord rect covering the visible
canvas `[0..W]×[0..H]` (W=`winfo width $wp`, H=`winfo height $wp`) is:
```
vx1 = -xorigin              vx2 = W*zoom - xorigin
vy1 = -yorigin              vy2 = H*zoom - yorigin
```
read from `xschem get zoom`, `xschem get xorigin`, `xschem get yorigin` on the
viewer ctx. Cleanly computable in Tcl → no C accessor is warranted.

**D3 — Replace fixed `graph_geometry {i}` with a PURE, headless-testable band
proc + a GUI viewport helper.**
- `wviewer::viewport_rect {wp}` (GUI): switch/read `zoom/xorigin/yorigin` + winfo
  W/H, return `{vx1 vy1 vx2 vy2}`. If `W<=1 || H<=1` (canvas not yet mapped),
  fall back to a sane default (`{0 0 800 600}`) so the first placement is
  reasonable; the map-time `<Configure>` refit (D6) is the authority that makes
  the final state exact.
- `wviewer::band_geometry {i n vx1 vy1 vx2 vy2}` (PURE, no Tk/xschem calls):
  tile `[vy1,vy2]` into `n` equal full-width bands, **no gap** (the engine's 14%
  margins at draw.c:3662-3675 already separate adjacent graphs):
  ```
  bandh = (vy2 - vy1) / double(n)
  by1   = vy1 + i*bandh ;  by2 = vy1 + (i+1)*bandh
  return [list $vx1 $by1 $vx2 $by2]
  ```
  Keeping the pure sub-proc preserves headless unit checks.
- REMOVE `graph_geometry` (or keep it ONLY if some caller outside regenerate/graphbb
  still needs it — grep shows the only callers are regenerate:593/617; both move to
  band_geometry). Do not leave a dead fixed-geometry proc.

**D4 — Kill the canvas-zoom shrink: regenerate no longer `zoom_full`s.**
regenerate builds the rects to cover the *current* viewport (via viewport_rect +
band_geometry), so the graph fills by construction. Delete the `xschem zoom_full`
at wave_viewer.tcl:621; keep `xschem new_schematic switch $wp` + `xschem redraw`.
DO NOT touch `wviewer::fit`'s zoom_full (:1041) — Fit acting on the graph is item 19.
The graph internal DATA-range autozoom (`setprop rect … fullxzoom/fullyzoom`,
:600-613) is UNCHANGED — that writes the axes ranges into the rect's node attrs, not
the rect corners.

**D5 — Multi-graph = equal vertical bands via band_geometry.** regenerate computes
`n = llength graphs`, places band `i` for each, and rebuilds `graphbb` from the SAME
band rects (over_graph/cursor-key gate feeds off graphbb — must match the placed
rects exactly). Since the rects now fill the viewport, over_graph returns 1 nearly
everywhere — the intended precondition for item 19.

**D6 — `<Configure>` refit.** In `wviewer::open`, APPEND (never replace — `<Configure>`
is in `keepseqs` and the editor's own resize handler must keep running):
`bind $wp <Configure> "+[list wviewer::on_configure $token]"`. `on_configure`:
debounce with `after idle` (coalesce resize storms — cancel a pending id), guard
`winfo width $wp > 1`, and if the canvas pixel size changed since the last fill,
call `wviewer::regenerate $token` (the single fill path → refit + graphbb rebuild).
Record last-filled W/H per token to suppress no-op Configure churn.

**D7 — Regression isolation is by construction.** Every fill/grid-off code path lives
in `wviewer::` and the viewer sets `no_grid=1`; normal schematic windows never call
any `wviewer::` proc and keep `no_grid=0`, so their grid draws and their (embedded)
graph rects are geometrically untouched. The regression leg proves this empirically.

---

## Deliverables (map 1:1 to the PLAN item-18 points)

1. **Grid/chrome OFF, viewer-window-only.** Add `int no_grid;` to `Xschem_ctx`
   (xschem.h after :1501, next to `only_probes`). Gate `drawgrid()` by extending the
   existing early-out at draw.c:1147 to `if( xctx->no_grid || !tclgetboolvar("draw_grid") || !has_x) return;`
   (this point preserves the 0082 GC-dash ordering — the guard stays first). Add
   `xschem set no_grid 0|1` (scheduler.c `>= 'n'` branch near no_draw :10067) and
   `xschem get no_grid` (scheduler.c case 'n' near no_draw :3975, mirror its shape).
   In `wviewer::open`, after `xschem set readonly 1`, add `xschem set no_grid 1`.
2. **Single graph fills the viewport** + `<Configure>` refit (D2/D3/D4/D6).
3. **Multi-graph vertical split** (D5) — replaces the 800x400 / i*450 geometry.
4. **Canvas-zoom shrink killed** (D4).
5. **No regression** in normal schematic windows (D7) — verified by the RG leg.
6. **Tests** (below), headless where computable, GUI DISPLAY-guarded, ≥2 sabotages.

Interactive draw path only (draw.c). Export paths (svgdraw.c/psprint.c grids) and
the crosshair are OUT OF SCOPE.

---

## Tests (extend `tests/headless/test_wave_viewer.tcl`)

Put the new pure checks in the headless H-section and the GUI checks in the existing
`if {[info exists ::has_x] && [info commands winfo] ne {}}` block, reusing the
existing scaffolding: `wviewer::open $tok` → `wviewer::window_for $tok`(vtop),
`$vtop.drw`(vdrw), `viewer_ready $vtop`, `dict get $::wviewer::graphbb $vdrw`,
`xschem raw read $rawpath dc`, Add-Graph via `$mb.graph invoke [$mb.graph index {Add Graph}]`.
GUI legs MUST self-SKIP when `viewer_ready` is false (never FAIL on an unmapped window).

### Headless (pure band_geometry — no window)
- **H-band1 single fills**: `band_geometry 0 1 0 0 1000 800` == `{0 0 1000 800}`.
- **H-band2 two equal full-width bands**: `band_geometry 0 2 0 0 1000 800` ==
  `{0 0 1000 400}` and `band_geometry 1 2 0 0 1000 800` == `{0 400 1000 800}`.
- **H-band3 tiling**: for n=3, band i+1's top == band i's bottom (contiguous, no
  gap/overlap); union spans `[vy1,vy2]`; all three share `[vx1,vx2]`.
- **H-band4 nonzero origin**: `band_geometry 1 2 -100 -50 900 550` uses the passed
  viewport verbatim (proves it is viewport-relative, not hardcoded 0/800).
- **UPDATE H4 (test :237-238)**: the old `graph_geometry` fixed-slot asserts are
  removed/replaced by the H-band checks above (justify in the receipt: geometry is
  now viewport-relative, not fixed 800x400/i*450).

### GUI (DISPLAY-guarded)
- **GF1 single graph fills viewport**: open viewer, add one graph (Add Graph or a raw
  trace), `viewer_ready`; switch to vdrw; compute `{vx1 vy1 vx2 vy2}` from
  `xschem get zoom/xorigin/yorigin` + `winfo width/height $vdrw`; assert
  `graphbb[0]` ≈ that rect within a few schematic units (rounding tolerance).
- **GF2 grid off in viewer, on elsewhere**: `xschem new_schematic switch $vdrw;`
  `xschem get no_grid` == 1; switch to `.drw` (the design/main canvas),
  `xschem get no_grid` == 0. Also assert `xschem redraw` on the viewer returns 0
  (draw path with no_grid runs clean).
- **GF3 resize refit**: record `graphbb[0]`; `wm geometry $vtop 1200x900` (a clearly
  different size); `update`; wait for the Configure/`after idle` to settle; assert
  `graphbb[0]` COVERS the NEW viewport and its width/height grew vs the recorded
  bbox (proves on_configure→regenerate ran). SKIP if the WM refused the resize
  (compare `winfo width` before/after).
- **GF4 two graphs each fill a half**: Add Graph ×2 → 2 graphs; assert `graphbb` has
  2 entries; entry 0 is the TOP half (by1≈vy1, by2≈midpoint), entry 1 the BOTTOM
  half (by1≈midpoint, by2≈vy2); both span the full width `[vx1,vx2]`; contiguous.
- **GF5 regenerate does not reframe the canvas**: after the viewer is stable, record
  `zoom0/xo0/yo0` (`xschem get`); call `wviewer::regenerate $tok`; assert
  `zoom/xorigin/yorigin` unchanged (regenerate no longer `zoom_full`s) AND the graph
  still fills (graphbb[0] still ≈ viewport). This is the "kill the shrink" proof.
- **UPDATE G10 (test :558-561) and G14 (test :696)**: replace the fixed
  `{0 450 800 850}` / `graph_geometry 1` / `{0 0 800 400}` asserts with
  viewport-relative expectations (compute the expected band from the live viewport +
  band_geometry, or assert the two-graph top/bottom-half relationship). Justify in
  the receipt.

### Regression (normal window — D7)
- **RG1 grid stays on in normal windows**: load `xschem_library/examples/test_ne555.sch`
  read-only in a normal window (e.g. `xschem load_new_window` then load, or the
  test's own load path); assert `xschem get no_grid` == 0.
- **RG2 embedded graph intact**: on that window assert `xschem get rects 2` >= 1 (the
  ne555 graph rect is present — fixture has 1 `flags=graph` rect) and `xschem redraw`
  returns 0. (No viewer geometry code runs for a plain file load — this window never
  entered `wviewer::`.)

---

## Sabotage plan (run ≥2; each must fail EXACTLY its target check and nothing else;
## revert with `git checkout -- <file>` ONLY after `git diff` shows the file holds
## nothing but the sabotage; clean re-run must be green)

- **S-band**: make `band_geometry` return the OLD fixed `{0 [expr {$i*450}] 800 …}`
  ignoring the viewport args → **H-band1..4, GF1, GF4 fail**; GF2/GF3/RG pass.
- **S-refit**: make `on_configure` an immediate `return` (no regenerate) → **GF3
  fails** (graphbb does not grow on resize); GF1/GF4 still pass.
- **S-shrink**: re-add `xschem zoom_full` at the end of `regenerate` → **GF5 fails**
  (zoom/xorigin/yorigin change across regenerate); others may still pass.
- **S-wiring**: comment out `xschem set no_grid 1` in `wviewer::open` → **GF2 fails**
  (viewer `no_grid` reads 0). Note: this proves the flag WIRING; the draw-side gate
  (draw.c:1147) has no pixel-level automated witness and is eyeball-verified — call
  this out honestly in the receipt.
- **S-band-multi** (optional): make `band_geometry` ignore `i` (always band 0) →
  **GF4 fails** (both graphs overlap, not top/bottom halves).

Pick at least two that hit DIFFERENT checks (recommended: S-band + S-refit, or
S-band + S-shrink).

---

## Verify green
- The changed suite: `tests/headless/full_audit.sh test_wave_viewer` (with a DISPLAY;
  in CI `xvfb-run -a`). Headless-only run: `--nogui --pipe -q --nolog --script`.
- The full ASE/wave protected set MUST stay green (assertion updates in
  test_wave_viewer justified in the receipt): `test_ase_core test_ase_view
  test_ase_window test_ase_dialogs test_ase_final test_ase_interact test_ase_plot
  test_ase_persist test_ase_launch test_ase_dirty test_wave_viewer`.
- `tests/headless/full_audit.sh` overall: the ONLY tolerated failures are the
  batch-start baseline (see below). `test_ase_plot` P4/P6/ESC gesture legs and
  `test_deselect_mode`/`test_hover_highlight` are known WSLg flakes — rerun-first
  with the correct invocation; they are NOT your regressions.
- Build C cleanly: `cd src && make` (C89; `_ALLOC_ID_` placeholders; guard any
  unix-only code — but no subprocess code is added here).

**Baseline full_audit fails at batch start (pre-existing, the ONLY tolerated fails):**
`test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste, test_fluid_editing,
test_hi_descend, test_launch_context, test_lib_manager_gui, test_lib_sweep,
test_palette, test_phase3_mints, test_pin_type_edit, test_reopen_readonly,
test_select_at, test_selflog_output, test_verb_noun_copy_move, test_wire_split,
test_wire_vertex_grab`; TIMEOUT `test_key_graph_context`.

---

## Commit — explicit file list ONLY (no `git add -A`, no `-a`, no reset, no push)
Stage exactly:
```
src/xschem.h
src/draw.c
src/scheduler.c
src/wave_viewer.tcl
tests/headless/test_wave_viewer.tcl
```
NEVER stage any pre-existing dirty tracked file (PLAN.md preflight list):
`doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
`src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`, `tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`.
This batch does NOT register tests in `tests/run_regression.tcl` (it is dirty
pre-batch); `full_audit.sh` auto-discovers `test_*.tcl`. Do NOT create junk dirs.
Do NOT edit PLAN.md / receipts (Ledger owns them).

Commit message: normal prose describing the fill/grid-off fix, ending with the
repo's `Co-Authored-By:` trailer.

---

## RUNBOOK policies (verbatim — non-negotiable)

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.

### Stop conditions
Whichever first: all 4 items [x]/[F]; any BLOCKED scout; two consecutive
FAILED; build broken; non-baseline full_audit failure no current item explains.
