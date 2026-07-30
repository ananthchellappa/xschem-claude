# Issue 0174 — a click anywhere on a strip selects a trace, and always the same one

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
HEAD `2656a694`; `github/fluid-editing` is at `0f1720de`, so **9 commits are
local and unpushed** — do not push unless I say so.

**This is the FIRST of three. 0174 is deliberately the smallest slice: precise
picking with the selection still a SINGLE trace.** `hilight_wave` stays a scalar
here. Multi-select, legend clicks and Ctrl-click are 0175
(`next_session_prompt_0175.md`); DEL is 0176. Do not pull them forward — 0174
shipping alone is a real improvement, and it lets us see precise picking work
before 0175 changes a persisted token.

## The bug, as reported

> Right now, clicking anywhere on a strip selects the first trace that was
> plotted on that strip. Not good. We should only permit a trace to be selected
> when the click happens reasonably close to a point on that trace. Currently, if
> there are multiple traces on a strip, it is only ever possible to select the
> very first trace that was plotted.

Repro: `src/xschem --script sky130A/cadence_style_rc --logdir /tmp`, open
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch`, open
its `ngspice_state1` so the viewer comes up, get **three or more traces onto one
strip**, then click around the plot body.

## The recon is done. VERIFY it, do not re-derive it

**This is TWO independent defects, and both are already documented in-tree as
knowingly out of scope.** Neither is a discovery; the work is removing them.

### (a) There is no distance threshold

The LMB wave-bold arm is C, `callback.c` ~876-893:

```c
else if(event == ButtonRelease && button == Button1 &&
   POINTINSIDE(xctx->mousex, xctx->mousey, gr->x1, gr->y1, gr->x2 , gr->y2) &&
   fabs(xctx->mousex - xctx->graph_press_x) <= GRAPH_CLICK_TOL * xctx->zoom &&
   fabs(xctx->mousey - xctx->graph_press_y) <= GRAPH_CLICK_TOL * xctx->zoom) {
  int wcnt, save;
  save = gr->hilight_wave;
  find_closest_wave(i, gr, &wcnt);
```

`GRAPH_CLICK_TOL` here is the **travel** tolerance (is this release a click or a
drag?), *not* a distance to a trace. The pick itself is
`find_closest_wave()` (`draw.c` ~4488), which has **no threshold at all**: it
measures only `|Δy|` at the nearest sample and keeps a running minimum
(`min` / `closest_dataset` / `*node_number`, ~4670). Landmine 33 says so, and
`doc/claude/issues/0152-graph-rmb-bolds-wave.md` already states *"trace however
far away it is. So 'in the vicinity of' was really 'anywhere in [the body]'"*.

It also reads the C mouse mirror `xctx->mousex/mousey`, which landmine 33 flags as
**stale for a press with no preceding Motion**.

### (b) The toggle compares the wrong thing — this is the "always the first trace" half

The very next lines, with a comment admitting it:

```c
  /* NOTE (pre-existing semantics, kept): the test is on the CURRENT bold wave, not
   * on wcnt -- so while any wave is bold a click anywhere in the body un-bolds it,
   * and only a click with nothing bold selects the closest wave. */
  if(gr->hilight_wave >= 0) gr->hilight_wave = -1;
  else                      gr->hilight_wave = wcnt;
```

So the selection can never move from trace A to trace B: the click that should
pick B instead clears A, and only the *next* click picks anything — whatever
`find_closest_wave` likes from wherever the pointer now is. Issue 0152's
*"Note the pre-existing toggle semantics, which this issue does not change"* is
the same statement.

**Measure which of the two produces the user's exact words before you fix
either, and write down what you measured.** (a) alone would give a wrong-but-
*varying* trace; (b) alone would give alternate-click clearing. My reading is
they compose into what was reported, but "always the first trace" describes (b)
more than (a) — and if (a) turns out to be reporting index 0 for a *different*
reason (e.g. the `min < 0.0` first-candidate seeding at `draw.c` ~4671 winning on
equal distances), that is a third thing and I want to know.

### The fix already exists, and this file's own Tcl already uses it

`graph_wave_at(i, px, py, tol)` (`draw.c` ~4790-4880) answers "which displayed
trace passes within `tol` **screen pixels** of this **canvas pixel**", with a
real point-to-segment distance, returning the trace's **NODE index** or -1.
Exposed as `xschem get graph_trace_at <gi> <px> <py> [tol]`
(`scheduler.c` ~3848); boolean twin `graph_near_wave` / `xschem get
graph_near_wave` (~3805).

**Item 7's RMB trace context menu already gates on it** — `wviewer::trace_at`
(`wave_viewer.tcl` ~3748) → `wviewer::trace_menu_pick` (~5587), whose header
documents the fail-closed rungs. So **the RMB menu is precise while the LMB
select is not, on the same strip, from the same pixel. That asymmetry is the
bug**, and closing it is mostly deleting the old pick.

Unlike `find_closest_wave`, `graph_wave_at` takes the **caller's** pixels, uses a
LOCAL `Graph_ctx` (landmine 11) and brackets the hcursor flag bits (landmine 37).

## READ FIRST

1. `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 —
   **landmine 33** (`graph_near_wave` is not `find_closest_wave`; and its two
   deliberate limits: **digital strips and bus traces answer -1**, because their
   rendering is a band/ribbon, not a polyline), **landmine 34** (NODE index vs
   MODEL index), **landmine 20**, **landmine 19** (a graph gesture does not dirty
   the file and does not push undo — selection is view state), **landmines 11 and
   37** (a query uses a LOCAL `Graph_ctx` and brackets the hcursor bits).
2. `doc/claude/issues/0152-graph-rmb-bolds-wave.md` — **the whole file.** It names
   both defects above as knowingly out of scope, and its `WB*` leg table is what
   this issue modifies.
3. `doc/claude/specs/waveform_viewer_modes.md` §12.4 (hit-testing seams) and
   **§12.5 "Bindings and interaction ownership"** — LMB on the viewer canvas
   already means three other things (strip drag-reorder, trace drag between
   strips, plus the C engine's cursor grab / box-zoom). You are editing one arm
   of a crowded button.

## Seams — compose, do not reinvent

| what | where | note |
|---|---|---|
| `graph_wave_at(i,px,py,tol)` | `draw.c` ~4790 | THE precise hit test. NODE index or -1 |
| `xschem get graph_trace_at` | `scheduler.c` ~3848 | its Tcl verb |
| `wviewer::trace_at` | `wave_viewer.tcl` ~3748 | Tcl wrapper, fails closed |
| `wviewer::trace_menu_pick` | ~5587 | the precise-gate pattern, incl. its refusal rungs |
| `find_closest_wave` | `draw.c` ~4488 | the thresholdless one. **It has OTHER callers** (`callback.c` ~1341, the cursor/measure path) — change this call site, do NOT delete the function |
| `node_index_of_trace` / `trace_index_of_node` / `node_count` | ~2984-3024 | PURE index-space mapping (landmine 34) |

## Decisions to make BEFORE writing code — answer them in the spec

- **D1: what is `tol`?** `graph_wave_at`'s callers pass their own. Find what the
  RMB menu and the trace-drag use and **match them unless there is a reason not
  to** — three picking surfaces on one strip disagreeing about "close enough" is
  the next bug report. Say whether it should be a config var
  (`wviewer_trace_pick_tol`?) or a constant, and whether it scales with zoom
  (note the travel test above multiplies `GRAPH_CLICK_TOL` by `xctx->zoom`).
- **D2: click on empty body space — clear the selection, or leave it?** ⚠ Empty
  body space is **also the strip drag-reorder gesture** (§12), so "clears" means a
  drag that fails its travel threshold also clears the selection. I lean
  **leave it alone** for that reason; if you clear, say how you keep a refused
  drag from clearing.
- **D3: click on the already-selected trace — stays selected, or toggles off?**
  Cadence keeps it selected. But note that today's behaviour is a toggle, and
  some `WB*` legs assert exactly that; whichever you pick, those legs change and
  you must count them first.
- **D4: viewer-only, or every graph in the tree?** This arm is in
  `waves_callback`, shared with the **~127 embedded schematic graphs**. Precise
  picking is strictly better everywhere, so I lean **everywhere** — but say it
  explicitly, because it means on-canvas schematic graphs change behaviour too,
  and if you gate it viewer-only, gate it on something real (not `has_x`).
- **D5: digital and bus strips.** `graph_wave_at` answers -1 across their whole
  body by design, so after this change a digital strip's body becomes
  **unselectable** where today it selects something. That is a real behaviour
  loss. Options: keep `find_closest_wave` as the fallback on `gr->digital`, or
  accept it and note that 0175's legend click becomes the way to select there.
  **Decide and record — do not let it happen silently.**

## Hard constraints

- **Landmine 19: selection is view state.** No `set_modify`, no undo push. (The
  existing arm writes `hilight_wave` into `r->prop_ptr` via `subst_token` and
  does not dirty the file — keep that property.)
- **Landmine 34: `hilight_wave` and `graph_trace_at` both speak NODE index.** A
  trace with an empty `vec` occupies a MODEL slot and no NODE slot. Do not
  introduce a model-index comparison here.
- **Do not change what a marker gesture owns.** The arm above this one
  (`callback.c` ~868) is the marker release and it MUST stay first — its comment
  explains that a no-travel marker select would otherwise also toggle the bold.
- **Do not touch the double-click path** (`callback.c` ~1199,
  `edit_wave_attributes(1, ...)` → the wave dialog).
- **One log line per gesture, and today the bold toggle logs nothing.** Keep it
  that way unless you have a reason; if you add logging, it is one line from one
  site.

## ⚠ THE HOLLOWNESS TRAP

1. **"It picks the nearest trace" is not the test. "A click far from every trace
   picks NOTHING" is.** Write that leg first and watch it fail on today's code —
   a leg that only clicks near a trace passes on the thresholdless pick too.
2. **The "always the first trace" defect needs a fixture where node order differs
   from visual order**, and ideally ≥3 traces. Otherwise "picks the nearest" and
   "picks index 0" are the same answer and the leg proves nothing.
   `test_wave_modes` and `test_wave_trace_menu` already build multi-trace strips —
   reuse a fixture and **add a `vec`-less trace so MODEL and NODE indices differ**
   (landmine 34's own advice; it has caught this class before).
3. **Assert moving the selection A→B directly**, in one click, with no
   intervening click. That is defect (b), and no existing leg does it.
4. `xschem getprop rect 2 <gi> hilight_wave` is the witness the `WB*` legs use.
   **Count those legs before you start** so a silent drop is visible.
5. Sabotage-verify, and (a) and (b) must turn **different** legs red — if one
   sabotage reds both, the legs are not separating the two defects:
   (a) restore `find_closest_wave` / pass a huge `tol`;
   (b) restore the `hilight_wave >= 0` comparison;
   (c) make `tol` zero (nothing is ever selectable);
   (d) pass model index where node index is expected.

## Tests

Extend the suites that own these paths; do not add a new one.

- `tests/headless/test_wave_viewer.tcl` (**349** DISPLAY / **48** nogui) — owns
  the `WB*` wave-bold legs (issue 0152). The precision and semantics legs go here.
- `tests/headless/test_wave_trace_menu.tcl` (**223** / **71**) — owns
  `graph_trace_at`-gated picking and its fail-closed rungs; the shared-`tol`
  agreement leg fits here.

Full battery, must stay green at these counts (DISPLAY / nogui):
`test_wave_snap` 59/36, `test_wave_grid` 80/44, `test_wave_legend` 44/33,
`test_wave_empty_strips` 94/28, `test_wave_modes` 410/137,
`test_wave_markers` 712/328, `test_wave_viewer` 349/48,
`test_wave_clear_all` 68/3, `test_ase_plot` 150/30,
`test_wave_trace_menu` 223/71, `test_wave_split_strip` 221/80,
`test_wave_drag_preview` 46/18, `test_ase_persist` 109/17,
`test_ase_unnamed_net` 28/28, `test_ase_window` 166/31.

⚠ **`test_ase_plot`'s gesture legs flake 1-2 in 10 under WSLg and always have**
(measured: 2/10 on unmodified code, once with a byte-identical failure set). If it
goes red, judge whether the failing leg is upstream or downstream of what you
touched, then re-run. Do not "fix" it.

## Process

Run suites through `tests/headless/run_suites.sh` with `SUITE_TIMEOUT=900`, never
a bare loop, or the GUI-test gate cannot pause them. **Soak the DISPLAY arm 10x.**

Then: **build → suites green → COMMIT → raise
`tools/review_gate/review_gate.sh` in the background.** Never push.

⚠ **This is a pointer behaviour, so the suite cannot close it.** Hand me the
manual sequence: how many traces on the strip, where to click, what should and
should not highlight — including a click in empty body space and a click on a
digital strip if D5 kept them working.

## Docs to update

- **New issue file** `doc/claude/issues/0174-trace-pick-needs-proximity.md`
  (0173 is the highest so far) — the two defects, what you measured about which
  one the user was describing, the fix, and D1-D5.
- `doc/claude/issues/0152-graph-rmb-bolds-wave.md` — its *"Note the pre-existing
  toggle semantics, which this issue does not change"* paragraph is now
  **superseded**. Mark it, do not delete it: that file is the record of why these
  survived this long.
- `doc/claude/specs/waveform_viewer_modes.md` — §12.5's LMB ownership table gains
  the precise-pick rule.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — extend
  landmine 33: its "no exclusion zone" note now has a fixed caller, and record
  the digital/bus consequence from D5.
