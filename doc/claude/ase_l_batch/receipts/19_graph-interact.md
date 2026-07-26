# Receipt — item 19 graph-interact (round-5 FINAL, Waveform Viewer interaction)

Verdict: **DONE** [x]. In the Waveform Viewer, wheel / RMB drag / `f` / View-menu
zoom now act on the **GRAPH content**, never on the canvas: the canvas
`xorigin`/`yorigin`/`zoom` are provably unchanged across every one of these
gestures (item 18 pinned them; this item keeps them pinned while re-routing the
interaction to the graph axes). Pure Tcl in `src/wave_viewer.tcl` — **no C
touched**. No fixer rounds. Not pushed. This was the round-5 acceptance item.

## Shipped commit (not pushed)

Single feature commit on `fluid-editing`, HEAD = **a5135deb**
`feat(ase): Waveform Viewer wheel/RMB/zoom act on the graph, not the canvas (item 19 graph-interact)`.
Exactly the four in-scope files staged explicitly; no pre-batch dirty tracked
file swept in; nothing else staged; not on any remote branch.

| File | Δ | What |
|------|---|------|
| `src/wave_viewer.tcl`                 | +236/−19 | new helpers `graph_at_pointer`/`graph_range`/`apply_range`/`wheel`/`graph_zoom`/`wheel_bind`; wheel + Button-3 + f/Z key routing to the graph; `fit` + View-menu de-canvased |
| `tests/headless/test_wave_viewer.tcl` | +197     | 25 new IX* checks (213 total), each asserting graph-range change AND canvas origin/zoom == captured baseline |
| `doc/ase_l_tutorial.html`             | +33/−… | viewer key table + new mouse/wheel tables + View-menu note |
| `doc/claude/specs/waveform_viewer.md` | +59      | "Item 19 notes (as shipped)" interaction section |

## Ledger-agent re-verification (at HEAD = a5135deb)

- `git show --name-only a5135deb` = exactly the four files above; `git rev-parse
  HEAD` = a5135deb; `git branch -r --contains a5135deb` empty (not pushed);
  working tree clean for all four (changes fully committed); `git diff --cached`
  empty (nothing staged, PLAN.md and pre-batch dirty files untouched).
- **No C in the commit** — only `src/wave_viewer.tcl` among source; xschem.h /
  draw.c / scheduler.c / callback.c NOT in the diff. The C over-graph paths the
  PLAN cites (callback.c:1170/1133 pan, :1836/159/1048 zoom-box, :1419 fit) are
  reused as-is; item 19 only changes which Tk binds forward to them.
- Helper procs confirmed present: `wviewer::fit` :1107, `graph_at_pointer` :1161,
  `graph_range` :1183, `apply_range` :1203, `wheel` :1226, `graph_zoom` :1262,
  `wheel_bind` :1298, `key_filter` :1620, `btn3_filter` :1673, `strip_bindings`
  :1696.
- `wviewer::fit` contains **no** `xschem zoom_full` (de-canvased, confirmed by
  proc-body grep) — it now does `xschem setprop -fast rect 2 $gi fullxzoom`
  (:1118) on the graph rect node instead.
- Test file: 213 `check` invocations (grep counts 214 lines, one being the
  `proc check` definition), 25 of them the new IX* legs.

## What landed (maps 1:1 to PLAN item-19 points 1–5)

- **D1 — plain wheel = graph vertical pan; Shift = horizontal; Ctrl = X zoom.**
  `strip_bindings` (:1696) sweeps the canvas binds, then re-adds
  `<Button-4>`/`<Button-5>` (+`Shift-`/`Control-` variants) and the portable
  `<MouseWheel>` (+`Shift-`/`Control-`) binds AFTER the sweep (wave_viewer.tcl
  :1715–1726), each ending in `break`. These more-specific binds PRE-EMPT the
  kept generic `<Button>`/`<MouseWheel>` that used to forward the X11 wheel to
  the C waveform-wheel handler (which did horizontal pan, and Ctrl=CANVAS zoom —
  both wrong per D1). `wheel_bind` resolves the token from `%W` at event time
  (no stale capture) → `wviewer::wheel` → `apply_range` on the graph under the
  pointer. Documented Shift/Ctrl choice (Cadence-consistent: Ctrl=zoom,
  Shift=horizontal) is in the spec + tutorial.
- **D2 — RMB press+drag = graph zoom-box.** `btn3_filter` (:1673, bound via
  `<ButtonPress-3>`/`<ButtonRelease-3>` :1703–1704) forwards Button-3 press AND
  release **unconditionally** (no over_graph gate — since item 18 the graph
  fills the window the pointer is always inside a graph, but this is robust: the
  viewer never swallows RMB). The C over-graph `GRAPHPAN` path then rubber-bands
  a box and zooms the graph x-range to it. `<Double-Button-3>` is `break`ed
  (:1707) so no graph-props dialog.
- **D3 — `f` = fit (full x+y) on the graph; View menu de-canvased.** `key_filter`
  (:1620) intercepts `f`=fit (`wviewer::fit`), `Z`=graph zoom-in, `Ctrl-z`=graph
  zoom-out (:1637/:1640 → `wviewer::graph_zoom`); arrows still forward to the C
  x-pan/zoom. `wviewer::fit` (:1107) dropped its trailing `xschem zoom_full`
  (which would SHRINK the graph now that it fills the window) and reframes the
  graph data range via `fullxzoom` on the rect node. View menu Zoom In/Out are
  `-command wviewer::graph_zoom` (:1759/:1761); Redraw stays a canvas-safe plain
  redraw.
- **D4/D7 — graph-not-canvas + frozen axes.** `apply_range` (:1203) is
  canvas-safe (no `zoom_full`), keeps the model↔rect node in sync, and never
  touches canvas origin/zoom. Range writes freeze all four axes (D7) so a
  `regenerate` after a pan/zoom does not autozoom the graph back.
- **D5 — tests + docs.** 25 IX* legs (below); tutorial + spec updated.

## Tests

`tests/headless/test_wave_viewer.tcl` — **213 checks** (DISPLAY=:0, `RESULT: ALL
PASS`), up from 188 at item 18. The 25 new IX* legs each assert BOTH the intended
graph-range change AND `canvas origin/zoom == a once-captured baseline` — the
"graph-not-canvas teeth." Per the item-17 de-flake lesson, each witnesses a
**synchronous state write** (the graph rect node x1/x2/y1/y2, or the pinned
canvas origin/zoom read back) rather than a gesture's stacking/timing. RMB legs
are driven through `wviewer::btn3_filter` with synthetic Button-3 press/release
at 30%/70% body pixels; wheel legs through `wviewer::wheel_bind`.

IX coverage: vertical-pan up/dn (IX-vpan-up/dn), horizontal pan (Shift), Ctrl
zoom, RMB box → x-range narrows (IX-rmb), `f` fit (IX-fit), View>Zoom on graph —
each paired with a canvas-stability assertion.

## Sabotage table (three; each failed EXACTLY its target)

| # | Sabotage | Target | Exact? |
|---|----------|--------|--------|
| S1 | `return` before `apply_range` in `wviewer::wheel` default branch (wheel vertical no-op) | IX-vpan-up / IX-vpan-dn vertical-pan checks (3) | yes |
| S2 | re-insert `xschem zoom_full` in `wviewer::fit` | IX-fit "canvas == baseline" assertion (1) | yes |
| S3 | `btn3_filter` unconditional bare `return` (swallow RMB) | IX-rmb graph x-range-narrowing checks (3) | yes |

Revert mechanism (documented deviation, same guarantee as receipts 15/16/17/18):
the item-19 changes were still uncommitted at sabotage time, so each sabotage was
reverted by a targeted reverse-`Edit` (not `git checkout -- <file>`, which would
have wiped the uncommitted feature), confirmed sabotage-only by `git diff` before
committing; a clean re-run then went green (213).

## Deviations (accepted, reality-forced)

1. **IX-fit ordered LAST among IX legs.** The S2 sabotage's under-sabotage canvas
   drift (`zoom_full` moves the canvas) must isolate to IX-fit alone; putting
   IX-fit last lets the single captured canvas baseline still hold for every
   earlier IX leg. The real shipped code never moves the canvas, so the baseline
   is valid throughout — this is a test-ordering choice, not a product concession.
2. **Sabotage revert by Edit, not `git checkout`** (see sabotage table) — forced
   because the feature was uncommitted during verify.

## Fix-round history

None. Single feature commit a5135deb; no fixer rounds. Item verdict DONE from the
implementer with an empty outstanding-problems list; ledger re-verification found
nothing to open.

## Outstanding problems

**None.** Empty problem list at ledger time; working tree clean at HEAD for all
four committed files.

Note on the audit: the implementer's `full_audit.sh` run was cut short by the
forced finalize. Its partial output showed only baseline fails plus one
non-baseline early FAIL, `test_alt_transform_group_0116` — a fluid ALT-R/F WSLg
gesture test that never touches `wave_viewer.tcl` — which PASSED on rerun (5
checks). Known-class WSLg gesture flake, not a regression (does not exercise any
item-19 code). All 11 protected ASE/wave suites reported green:
core 66 (--nogui), final 28 (--nogui), view 36, window 155, dialogs 133,
interact 63, plot 102, persist 109, launch 38, dirty 41, wave_viewer 213.
`cd src && make` green (no C changed).

## Corrected anchors worth keeping (verified at HEAD a5135deb, src/wave_viewer.tcl)

- **Wheel routing**: `strip_bindings` :1696 re-adds, AFTER the keep-sweep,
  `<Button-4>` :1715 / `<Button-5>` :1716 (+`Shift-` :1717/:1718, `Control-`
  :1719/:1720) and `<MouseWheel>` :1724 (+`Shift-` :1725, `Control-` :1726),
  each `break`ing so the kept generic wheel binds never also fire →
  `wviewer::wheel_bind` :1298 → `wviewer::wheel` :1226 → `apply_range` :1203.
- **RMB zoom-box**: `<ButtonPress-3>`/`<ButtonRelease-3>` :1703/:1704 →
  `wviewer::btn3_filter` :1673 forwards Button-3 press+release unconditionally
  (the C over-graph GRAPHPAN → zoom-x-to-box path narrows the graph x-range);
  `<Double-Button-3>` `break`ed :1707.
- **Keys**: `wviewer::key_filter` :1620 — `f`=fit, `Z`=`graph_zoom in` :1637,
  `Ctrl-z`=`graph_zoom out` :1640; arrows still forward to C x-pan/zoom.
- **Fit / graph zoom**: `wviewer::fit` :1107 (NO `zoom_full`; `fullxzoom` on rect
  node 2 at :1118); `wviewer::graph_zoom` :1262 (→ `apply_range` :1256); View
  menu Zoom In/Out `-command wviewer::graph_zoom` :1759/:1761.
- **Graph selection under pointer**: `wviewer::graph_at_pointer` :1161;
  `wviewer::graph_range` :1183 reads the graph rect node axes.
- **Supersedes prior anchors**: the item-18 note that `wviewer::fit` (then
  wave_viewer.tcl:1102/:1134) "keeps its OWN `xschem zoom_full` for item 19" is
  now CLOSED — that trailing `zoom_full` is REMOVED by this item. The PLAN's
  pre-item-18 `btn3_filter`/`key_filter` line refs (~1347–1411) drifted to
  :1673/:1620 after the item-18 fill/refit growth; use these.
