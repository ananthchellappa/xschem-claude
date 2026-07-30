# Issue 0177 — the waveform viewer must have NO schematic snap grid, anywhere

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
**0175 HAS SHIPPED** (2026-07-30, commits `5189c065` + `7ffceaea`, unpushed) and
was **EYEBALLED PASS with exactly one exception**, which is this issue. Never push.

## The report

> Implementation seems ok except that the "snap grid" seems to be at play when
> it comes to clicking on the legend text.
>
> though a schematic window has been used to implement the waveform viewer,
> there is no concept of schematic snap grid, so clean that up.

Two asks, and the second is the bigger one. The first is a defect on the legend
click. The second is **architectural**: the viewer is built on a schematic
window and has been inheriting schematic snap machinery piecemeal, patched one
site at a time (issue 0143 did `waves_callback`). The ask is to make "this canvas
has no snap grid" a **property of the viewer**, not a local override that every
new code path has to remember to repeat.

## ⚠ WHAT IS ALREADY MEASURED — do not re-derive it, and do not chase the pick

I measured this before writing the prompt. **The pick arithmetic is NOT the bug.**

`graph_legend_at()` (`draw.c`, added by 0175) takes RAW canvas pixels and
converts them itself (`px / xctx->mooz - xctx->xorigin`). It reads no mouse
mirror at all. Measured on the shipping build, ASE viewer, 3 traces, `W=1000`,
legend row 54, with the snap grid set **40× coarser than default**:

```
cadsnap=10   QUERY : 100=>0 300=>0 500=>1 700=>2 900=>2
cadsnap=10   CLICK : 100=>0 300=>0 500=>1 700=>2 900=>2
cadsnap=400  QUERY : 100=>0 300=>0 500=>1 700=>2 900=>2      <- identical
cadsnap=400  CLICK : 100=>0 300=>0 500=>1 700=>2 900=>2      <- identical
cadsnap=10   BODY click on node2 -> 2
cadsnap=400  BODY click on node2 -> 2                        <- identical
```

A full synthetic press+release through the PRODUCTION bindings selects the same
legend entry at `cadsnap 400` as at `cadsnap 10`. So:

- it is **not** `graph_legend_at`'s arithmetic;
- it is **not** the LMB arm's `on_body` test or its travel test (both read
  `xctx->mousex/mousey`, which are unsnapped — `callback.c` ~8192
  `xctx->mousex = X_TO_XSCHEM(mx)`);
- it is **not** `edit_wave_attributes`' `mousex_snap` read, because
  `waves_callback` overwrites `mousex_snap` with `mousex` at its head
  (`callback.c` ~810, issue 0143).

**So the thing the user saw is something a REAL pointer does that a synthetic
event does not.** That is the whole investigation, and it is where you start.

## The one structural fact that explains why this keeps happening

`callback.c` ~8192-8195, run for **every event on every window**, viewer
included:

```c
xctx->mousex = X_TO_XSCHEM(mx);
xctx->mousey = Y_TO_XSCHEM(my);
xctx->mousex_snap = my_round(xctx->mousex / c_snap) * c_snap;
xctx->mousey_snap = my_round(xctx->mousey / c_snap) * c_snap;
```

Issue 0143's fix was a **local** override inside `waves_callback`:

```c
xctx->mousex_snap = xctx->mousex;
xctx->mousey_snap = xctx->mousey;
```

That is correct but it only covers code reached **through `waves_callback`**.
Anything on the viewer canvas that runs BEFORE the routing decision, or that
runs when `waves_selected()` declines the event, still sees a **grid-snapped
schematic coordinate**. That is the surface to clean up, and it is why the
comment in `waves_callback` saying "this override is safe and does not leak"
is only true of the paths that existed when it was written.

## Ranked candidates — MEASURE each, do not assume

Ordered by how well they fit "*when it comes to clicking on the legend text*",
i.e. something that behaves differently over the legend band than over the plot
body. Report which one it actually was.

1. **The MOTION path, not the click path.** A real click is preceded by
   `<Motion>` events; my probe generated none. `handle_motion_notify`
   (`callback.c` ~5230-5260) branches on whether the pointer is over a graph:
   when it is, it calls `draw_graph_snap_cursor(mx, my)` and **returns**; when
   the pointer "left every graph" it calls `graph_snap_clear()` and then the
   SCHEMATIC `draw_crosshair()` / `draw_snap_cursor()`.
   ⚠ **The legend band is inside the rect but OUTSIDE the plot box.** Find out
   which side of that branch it lands on, because if a legend hover falls into
   the "left every graph" arm, the user gets the schematic crosshair / snap
   cursor — grid-snapped — drawn over the legend, which *is* "the snap grid is
   at play", and it would appear over the legend and nowhere else. This is my
   leading hypothesis and it costs one probe to confirm or kill.
2. **A visible SNAPPED READOUT.** `callback.c` ~8197 writes
   `mouse = %.16g %.16g` from `mousex_snap/mousey_snap` — computed BEFORE any
   override — into the status bar on every >8px pointer move. Check what the
   viewer's own status bar (viewer plan item 10) shows while hovering the legend
   band, and whether the editor's `statusmsg()` is reaching any widget the user
   can see.
3. **`draw_snap_cursor` / `draw_crosshair` on the viewer canvas at all.**
   `snap_cursor` and `draw_crosshair` are Tcl config vars. Neither is a viewer
   concept. Decide whether the viewer canvas should ever draw either, and if the
   answer is no, make that structural (see "The fix I want" below).
4. **`xctx->graph_top`.** Landmine 36 says it is computed from the **snapped** y
   ("`waves_callback` sets `graph_top = 1` for any press whose snapped y is above
   the plot box"). Post-0143 that should be the unsnapped value inside
   `waves_callback` — **verify the landmine text is not stale and correct it if
   it is.** `graph_top` gates the `GRAPHPAN` routing latch, and the legend band
   is exactly the region above the plot box, so if any of this is still snapped
   it bites the legend and nothing else.
5. **`waves_selected()`'s hit test.** It uses `xctx->mousex/mousey` (unsnapped)
   with a 5-px `border` inset from the RECT. Confirm a legend hover/press is
   routed to the graph at all — if `waves_selected` declines it, everything in
   candidate 1 follows automatically.

## The fix I want — make it a PROPERTY, not another override

Whatever candidate turns out to be the mechanism, the deliverable is not one
more local patch. **Decide and implement how "this window has no snap grid" is
expressed once**, so the next person adding a viewer gesture cannot reintroduce
this. Options to weigh explicitly in the issue file:

- **(a)** compute `mousex_snap`/`mousey_snap` un-snapped at the source in
  `callback()` when the event's window is a viewer canvas — one test, before the
  grid arithmetic, covering every downstream reader forever. Needs a cheap,
  reliable "is this a viewer window" test in C; `wviewer` knows it in Tcl.
  ⚠ This changes the value seen by *every* handler on that window, which is the
  point, but it must be checked against the ones that legitimately want a grid
  (there should be none on a viewer canvas — say so and prove it).
- **(b)** a per-window snap value (`c_snap` becomes context-scoped), with the
  viewer's set to "no snap". Bigger, but it is the honest data model, and
  `xschem set cadsnap` is already a global that the viewer has no business
  sharing.
- **(c)** keep the local overrides but add the missing ones. **Say plainly why
  the first two were rejected if you pick this** — it is the option that
  guarantees a fourth session on the same subject.

State in the issue what the viewer canvas draws for a pointer hover **in each
region**: plot body (item 9's diamond, on the nearest sample), legend band, axis
margins, the reorder grip. The answer should be a table, and "the schematic
crosshair" should not appear in it.

## READ FIRST

1. `doc/claude/issues/0175-trace-legend-click-and-multiselect.md` — D5 and the
   landmine-43 write-up: which coordinate space each picking surface speaks.
2. `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — **landmine
   43** (the two picking surfaces of one strip did not share a coordinate space),
   **landmine 36** (`graph_top` and the GRAPHPAN latch — the entry whose snap
   claim needs verifying), **landmine 33**, **landmine 19**.
3. `src/callback.c` ~8192 (where `mousex_snap` is born), ~810 (0143's override
   and its "safe, does not leak" comment — which this issue tests), ~5230
   (`handle_motion_notify`'s over-a-graph branch).
4. Issue **0143** itself for what "snap does not apply to graph windows" was
   decided to mean the first time.

## Tests

⚠ **There is a REAL HOLLOWNESS GAP in 0175's own suite and it is why this
shipped.** `test_wave_trace_menu.tcl` `TL4` asserts that
**`graph_legend_at` the QUERY** is snap-immune. Nothing drives a **real Tk
gesture** under a coarse snap, and nothing at all covers **hover**. That is
exactly the shape of the escape: a green leg next to an unasserted neighbour.

Add, at minimum:
- a leg that performs a full `<Motion>` → `<ButtonPress-1>` → `<ButtonRelease-1>`
  on a legend entry with `cadsnap` set coarse, and asserts the SAME entry is
  selected as with the default grid — **including the Motion**, which is the
  thing my probe omitted and the user's hand did not;
- a HOVER leg over the legend band asserting whatever candidate 1 resolves to
  (no schematic crosshair / no snap cursor / the viewer's own readout);
- if you take fix (a) or (b): a leg asserting the viewer canvas reports an
  unsnapped pointer coordinate while a SCHEMATIC canvas still reports a snapped
  one — the blast-radius leg, because the whole risk of (a)/(b) is breaking
  ordinary schematic snapping.

Full battery must stay green at these post-0175 counts (DISPLAY / nogui):
`test_wave_snap` 59/36, `test_wave_grid` 80/44, `test_wave_legend` 77/66,
`test_wave_empty_strips` 94/28, `test_wave_modes` 413/140,
`test_wave_markers` 712/328, `test_wave_viewer` 359/48,
`test_wave_clear_all` 68/3, `test_ase_plot` 150/30,
`test_wave_trace_menu` 300/71, `test_wave_split_strip` 221/80,
`test_wave_drag_preview` 46/18, `test_ase_persist` 109/17,
`test_ase_unnamed_net` 28/28, `test_ase_window` 166/31.

⚠ **`test_wave_snap` is the one to watch.** It owns the item-9 diamond and the
`graph_snap` readout, it drives `<Motion>` sweeps, and it is the suite most
likely to be legitimately affected by any of (a)/(b). Its `SG6`/`ST21` legs are
also known 1-in-10 scan flakes — judge, then re-run.

⚠ **Known WSLg flakes, measured, do not chase.** `test_ase_plot` P4/P6/P8/P9
1-2 in 10; `test_wave_trace_menu` `TG9` **4 in 10 on pristine code**;
`test_ase_window` `W3`/`W6c`, `test_wave_markers` `MF0`/`MF1`/`MX9`,
`test_wave_modes` `MG13` ~1 in 10. The 0175 10× soak measured **146/150** with
exactly four such non-passes.

⚠ **A green line is not a green suite — read the check COUNT.** When WSLg stops
mapping toplevels every GUI leg self-SKIPs and the suite still prints
`RESULT: ALL PASS`, at a fraction of the checks.

## Process

`tests/headless/run_suites.sh` with `SUITE_TIMEOUT=900`, never a bare loop.
Soak the DISPLAY arm 10×. Then **build → suites green → COMMIT → raise
`tools/review_gate/review_gate.sh` in the background.** Never push.

⚠ **This one ends in an EYEBALL and the suite cannot close it**, same as 0175:
hand over the manual sequence — where to put the pointer, what should and should
not appear under it, and what a click there should select — for the plot body,
the legend band, the axis margins and the reorder grip.

## Docs to update

- **New issue file** `doc/claude/issues/0177-viewer-has-no-snap-grid.md` — the
  MEASURED mechanism (not a list of suspects), the option chosen from (a)/(b)/(c)
  with the two rejections justified, and the per-region hover table.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — **landmine 36
  needs its snap claim verified and corrected if stale**, and whatever this issue
  makes true about where `mousex_snap` is born deserves its own entry (or an
  amendment to 43, which already owns "which surface speaks which space").
- `doc/claude/specs/waveform_viewer_modes.md` §15 — the ownership table gains
  the hover row(s); §12.5 if the motion routing changes.
- `doc/claude/issues/0175-*.md` — add a line under "Not verified" recording that
  the snap exception was found by eyeball and closed by 0177.
- If issue 0143's decision is superseded, mark it, do not delete it.
