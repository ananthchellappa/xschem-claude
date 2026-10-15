# ASE Waveform Viewer — SUBWINDOWS

Status: **spec, stage 0** (2026-10-15). Nothing below is built except §12's
stage 0. Builds on `doc/claude/specs/waveform_viewer_tabs.md` (a tab is a MODEL,
not a context — every rule there still binds) and on the plot-destination policy
of `doc/claude/specs/waveform_signal_browser.md` (`wviewer::plot_dest`, ruling 24).
ASE-L side: `doc/claude/specs/ase_l.md` R-OUT14 and R-OUT15.

## 1. What the user ratified (2026-10-15, a practising Cadence user)

These are rulings, not guesses. Words in quotes are the user's.

- A viewer **tab** is ViVA's **New Win**. Tabs already exist (`f134a85c9`).
- A **subwindow** is a tiled plot area inside one tab, with its own strips,
  traces and axes. A tab starts with one subwindow — today's behaviour.
- Tiling is a **grid**. *"If one has only 2, they are side by side —
  horizontal. With 3, there are two rows, with the bottom-most row having only
  one sub-window — meaning one-fourth of the screen real estate is wasted."*
  4 is 2x2.
- Exactly one subwindow per tab is the **target**. *"Clicking does it."* The
  target is visibly framed.
- New plots from ASE-L (`~` and the run-end auto-plot), Direct Plot, the signal
  browser and the Calculator go to the target subwindow, under the plot
  destination: **Append / Replace / New SubWin / New Win**.
- *"Lining up — always independent."* X axes of different subwindows are never
  linked, and cannot be made to be.
- ASE-L gets the destination as a drop-down at the right end of its status bar,
  saved with the session state.

## 2. Requirements

| # | requirement |
|---|---|
| SW1 | A tab holds an ordered list of 1..N subwindows; a new tab, an opened viewer and a Clear All start with ONE. |
| SW2 | Every subwindow holds 1..M strips (never zero). Strips inside a subwindow tile vertically exactly as a tab's strips do today. |
| SW3 | Subwindows tile the viewport by the grid rule of §4: `cols = ceil(sqrt(n))`, `rows = ceil(n/cols)`, filled row-major, last row partial and LEFT-aligned, all cells equal. For n = 1..4 this is the user's ruling; **for n >= 5 it is our declared assumption** (same formula, extended). |
| SW4 | Exactly one subwindow per tab is the target. Pressing Button-1 anywhere inside a subwindow makes it the target (and, as today, the pressed strip the target strip). |
| SW5 | While a tab has 2+ subwindows the target subwindow carries a visible frame; with one subwindow there is no frame (byte-identical rendering to today, the issue 0151 rule). |
| SW6 | The existing target-strip bar (`active=1`) is drawn on the target strip of the target subwindow only, and only while that subwindow holds 2+ strips. |
| SW7 | Every plot door — `~`, the run-end auto-plot, Direct Plot, the signal browser, the Add Trace dialog, the Calculator — lands in the ACTIVE tab's TARGET subwindow (or the one its destination creates). |
| SW8 | Destination **Append**: add to the target subwindow, spread over its strips by the tab's plot mode (today's append rule, confined to the subwindow). |
| SW9 | Destination **Replace**: clear the target subwindow (every strip in it), then plot into it by the plot mode. Under BOTH modes — this retires ruling 24's "Replace appends under multi" limit (§6.2). |
| SW10 | Destination **New SubWin**: add a subwindow at the end of the tab's list, make it the target, plot into it. |
| SW11 | Destination **New Win**: new tab (its one subwindow is the target), plot into it (today's `newtab`). |
| SW12 | The viewer keeps its own **New Strip** destination as a viewer-only fifth choice, now confined to the target subwindow (§6.3). ASE-L offers exactly the four user choices. |
| SW13 | X axes of different subwindows are ALWAYS independent: MMB pan, RMB box zoom, arrows, plain/Shift/Ctrl wheel, axis-margin zoom, View > Fit, full-X zoom and Shared X in one subwindow never change another's `x1`/`x2`. No setting links them. |
| SW14 | Within one subwindow strips keep today's X linking (same `sim_type`, locked, selected, Shared X). Shared X stays a per-TAB flag applied within each subwindow. |
| SW15 | Closing a subwindow (Graph > Close SubWin on the target; deleting its last strip) re-tiles the rest; the target moves to the subwindow that took its slot, else the previous one. Closing the ONLY subwindow does nothing and says so (the D9a shape). |
| SW16 | A trace can be dragged from a strip in one subwindow to a strip in another; Ctrl-V pastes into the target subwindow. |
| SW17 | Subwindows (membership, order, target) are saved and restored per tab with the ASE session state; undo/redo and tab freeze/thaw carry them. A state saved before this feature loads as one subwindow per tab. |
| SW18 | ASE-L status bar: a read-only drop-down at its RIGHT end, labels `Append` `Replace` `New SubWin` `New Win`, a session-state key (`plot_dest`), dirtying the session on change, logged as one replayable line, used by `~` and the run-end auto-plot. |
| SW19 | The multi-plot auto-plot strip ORDER (last Outputs row on top, R-OUT14) is unchanged. A separate user ruling is pending on it; nothing here touches it. |
| SW20 | Every new gesture/command is logged through `wviewer::log_action`/`wviewer::echo` (tabs R6) and is undoable as ONE step where it mutates the model. |

## 3. Data model

The tabs spec's stash is untouched: `layouts($token)` describes the ACTIVE tab,
inactive tabs are frozen records. A subwindow adds **no new array and no new
key space** — it is a tag on the graphs the layout already holds.

- **Graph dict** gains `sw <id>`: a positive integer, unique within its tab,
  never reused while the tab lives (`swseq` per tab, like `tabseq`).
- **Layout** `{sharedx graphs}` gains `subwins {<id> ...}` — the tiling ORDER —
  and nothing else. Membership is the graphs' `sw` tags.
- **The graph list stays FLAT and is kept CONTIGUOUS by subwindow**, in
  `subwins` order. So strip N is still rect N (every `rect 2 $gi` site, graphbb,
  the hilight set and undo keep their index space), and "the strips of
  subwindow k" is one contiguous index range.
- **The target subwindow is DERIVED**: it is the `sw` of the target strip
  (`target($token)`). No separate field, so the two can never disagree, and the
  existing clamp (`wviewer::target_index`) keeps it valid.
- **PURE normaliser** `wviewer::sw_normalize layout` is the one door every
  reader/writer of a layout passes (restore, thaw, paste, undo apply): a graph
  with no `sw` gets the first id; `subwins` missing → ids in first-appearance
  order; ids in `subwins` with no strip are dropped; ids on strips but absent
  from `subwins` are appended; the graph list is stably re-grouped to be
  contiguous. Idempotent.
- **Serialisation**: graphs go into the state dict verbatim (as today), so `sw`
  rides for free; `wviewer::tabs_serialize` and the one-tab flat `viewer` keys
  carry `subwins`. **Back-compat**: an old state has no `sw` and no `subwins`
  and normalises to one subwindow `{1}` — the exact old picture. **Forward**:
  an older build ignores both keys and stacks every strip in one column; no
  data is lost. No new top-level state key on the viewer side.
- **Rect props** (written by `wviewer::graph_props`): `xgroup=<id>` on every
  strip of a tab with 2+ subwindows (§7); `swframe=<edges>` on the strips of the
  target subwindow (§5). Neither is written with one subwindow, so a one-
  subwindow tab's rects are byte-identical to today's.

## 4. Grid geometry

`wviewer::sw_grid n` (PURE) → `{cols rows}`; `wviewer::sw_cell k n vx1 vy1 vx2 vy2`
(PURE) → the cell rect of subwindow k (row-major: `r = k / cols`, `c = k % cols`),
each cell `(vx2-vx1)/cols` wide and `(vy2-vy1)/rows` tall, boundaries computed
as `v1 + k*span/n` like `wviewer::band_geometry` so cells tile exactly. Strips
inside a cell use `band_geometry` over the cell rect. Regenerate, graphbb and the
drop-bar math read the same two procs.

| n | cols x rows | layout (row-major) | empty cells |
|---|---|---|---|
| 1 | 1x1 | `[0]` | 0 |
| 2 | 2x1 | `[0 1]` — side by side | 0 |
| 3 | 2x2 | `[0 1] / [2 .]` | 1 (a quarter, bottom right) |
| 4 | 2x2 | `[0 1] / [2 3]` | 0 |
| 5 | 3x2 | `[0 1 2] / [3 4 .]` | 1 (a sixth) — **our assumption** |

(6 → 3x2 full; 7 → 3x3 `[0 1 2]/[3 4 5]/[6 . .]`.) The single formula
reproduces the user's n = 1..4 rulings exactly, which is why it is the
extension chosen. Equal sizes only; divider drag is later (§10).

## 5. Target and its frame

- `wviewer::click_target` already maps a pixel to a strip in 2-D through
  `wviewer::strip_at_pixel`; making the strip the target makes its subwindow the
  target. A click in an EMPTY grid cell (n = 3, 5, 7…) does nothing.
- A target change that crosses subwindows rewrites `swframe` on the old and new
  subwindows' strips IN PLACE, like `wviewer::move_marker` does for `active`
  (never a regenerate — that would discard an engine-side zoom).
- **Frame**: a new `draw.c` prop token `swframe=<bitmask>` (1 left, 2 right,
  4 top, 8 bottom) read in `setup_graph_data` beside `active`, defaulted BEFORE
  the `RECT_OUTSIDE` early return for the same shared-`graph_struct` reason.
  Every strip of the target subwindow gets 1|2; its first strip adds 4, its last
  adds 8, so the union outlines the whole subwindow. Drawn in the accent colour
  the `active` bar uses. **No decoration rects**: `graphbb` and every
  `rect 2 $gi` site assume every rect is a graph.
- Pixels are eyeball-only (memory `pixel-deliverables-need-eyeball`): a `look`
  debt is recorded when stage 2 ships.

## 6. Destinations

### 6.1 Codes and labels

| code | viewer label | ASE-L label | meaning |
|---|---|---|---|
| `append` | Append | Append | SW8 |
| `replace` | Replace | Replace | SW9 |
| `newstrip` | New Strip | — | SW12 |
| `newsubwin` | New SubWin | New SubWin | SW10 |
| `newtab` | New Tab | New Win | SW11 |

`wviewer::dest_norm` learns `newsubwin` (and `new subwin`, `new win` →
`newtab`); unrecognised still → `append`. The viewer keeps calling a tab a TAB
(File > New Tab, `Ctrl-N`), so its label stays `New Tab`; ASE-L uses the user's
Cadence word `New Win` for the same code. One code, two label maps:
`wviewer::dest_labels` (viewer, five) and `ase::ui::plot_dest_labels` (four).

### 6.2 Replace clears the subwindow — and retires ruling 24's limit

Today `replace` clears the target STRIP in single mode and nothing in multi mode
(`wviewer::plan_replace_clear`, `wviewer::dest_menu_label`'s suffix). The user's
ruling is "clear the target subwindow then plot", in either mode. So Replace
removes every strip of the target subwindow, leaving one empty strip, and then
plans the batch as an Append into that clean subwindow. The `(=Append)` menu
suffix and the declared multi limit go away. ⚠ **This is a change for a
one-subwindow tab**: Replace there now clears the whole tab, where single-mode
Replace used to clear only the target strip. That is the Cadence semantics the
user ratified, and subwindows are what makes it safe: plots that must survive a
Replace live in another subwindow.

### 6.3 New Strip is kept, viewer-only

Decision: KEEP `newstrip`, confined to the target subwindow, and do not offer it
in ASE-L. Reasons: (a) it is a strip-level operation and New SubWin is a
subwindow-level one — folding either into the other changes what an existing
user gesture does; (b) saved `browser_state`, replay logs and the DS rows carry
the code, and `dest_norm` would otherwise silently map it to `append`; (c)
memory `ase-l-is-benchmarked-against-cadence-ade-l`: a convenience ADE-L lacks
may be kept. ASE-L shows exactly the user's four.

### 6.4 One door

Direct Plot (`ase::ui` → `wviewer::plot_signals`), the signal browser, the Add
Trace dialog and the Calculator (`calc` → `wviewer::plot_signals`) already share
`wviewer::plot_signals` → `wviewer::dest_prepare` → `wviewer::plan_plot`. The
subwindow scope is applied THERE: `dest_prepare` creates the subwindow/tab;
`plan_plot` is handed the target subwindow's index range as its universe (empty
strips to reuse, insert point for multi's front-insert = the subwindow's first
index). One change point; no door re-implements the policy.

## 7. Independent X (C and Tcl)

**C.** The X-link predicate `r->sel || (same_sim_type && !(r->flags & 2)) || i == graph_master`
is copied **10x** in the graph loop of `callback.c` (the loop that follows the
master graph's pan/zoom) and factored once as `graph_shares_x()` in `draw.c`
(callers: `graph_axis_zoom()`'s group, the joint full-X domain). Design: a
helper `graph_same_xgroup(master, k)` compares the two rects' `xgroup` prop
tokens (absent == absent, so every non-viewer schematic and every one-subwindow
tab is unchanged). It is applied ONCE at the head of the `callback.c` loop
(`if(i != graph_master && !graph_same_xgroup(graph_master, i)) continue;`,
before any arm — so the `r->sel` arm cannot cross either) and as the first test
of `graph_shares_x()`. Eleven copies inherit it; none is edited.

**Tcl.** Most viewer X gestures never reach that loop: `wviewer::wheel` routes
plain/Shift/Ctrl wheel to `wviewer::pan_x` (iterates EVERY strip) and
`wviewer::wheel_zoom` (reuses the pointed strip's X anchor for every strip);
`wviewer::fit`, `wviewer::graph_zoom {gi all}` and `wviewer::regenerate`'s
Shared X copy (from strip 0 to all) are tab-wide too. Each is scoped to the
subwindow of the pointed strip (or the target subwindow when no pointer), through
one PURE helper `wviewer::sw_range layout gi` → `{first last}`.

**Cursors A/B**: `xctx->graph_cursor1_x/2_x` are per window, so the two cursors
sit at one X across subwindows. **Declared limit** for this version.

## 8. ASE-L

- Status bar: `ttk::combobox $top.status.dest -state readonly -values
  {Append Replace {New SubWin} {New Win}}`, packed `-side right` after the left
  labels, driven by `<<ComboboxSelected>>` (never `-textvariable`: the binding
  is what produces one replayable `ase::ui::set_plot_dest <key> <code>` line).
- State key `plot_dest` (codes `append|replace|newsubwin|newtab`). **Default
  `replace`** — our declared choice, because it is closest to today's
  always-replace `~`; ADE-L's own default is a question for the user, not a
  fact recorded here. A missing/unknown value reads `replace`. Changing it
  dirties the session (memory `ase-l-registry-is-environment-choice-is-state`).
- `ase::ui::auto_plot` (both `~` and `auto_plot_idle`) reads it, in the active
  tab, and today's `auto 1` strips behave per choice:

| choice | where the run's strips go | previous `auto` strips |
|---|---|---|
| Replace | target subwindow cleared, then `want` fresh `auto 1` strips (1 single / one per row multi) | gone with the clear (they were in it), else kept |
| Append | target subwindow, viewer append rule (single: target strip; multi: new strips on top); ASE's own batch may land in an `auto` strip | kept, traces kept |
| New SubWin | a new subwindow, made the target, `want` `auto 1` strips | kept |
| New Win | a new tab, `want` `auto 1` strips | kept |

  The zero-ticked-rows path empties the target subwindow under Replace only.
  Direct Plot still never lands in an `auto` strip under Append (R-OUT14).
- The viewer's own `wviewer::plot_dest` and ASE-L's `plot_dest` are
  INDEPENDENT settings: the first serves the viewer's doors, the second `~` and
  the run-end plot (ADE-L's plotting mode is a session option, ViVA's is its
  own).

## 9. Close, drag, paste, undo, tabs

- Close SubWin: Graph menu entry acting on the target; the trace context menu
  entry on the pressed strip's subwindow. One undo step. Logged.
- Deleting the last strip of a subwindow closes the subwindow when others exist.
- Trace drag across subwindows: `wviewer::move_trace` and `strip_at_pixel` are
  already 2-D. **Strip** drag-reorder stays within its subwindow in v1 (declared
  limit): `strip_drop_index` is vertical and is confined to the source range.
- `wviewer::plan_paste` is handed the target subwindow's range.
- Undo snapshots the layout, so `sw`/`subwins` ride; `wviewer::tab_freeze` /
  `tab_thaw` / `tabs_serialize` / `restore_tabs` pass layouts through
  `sw_normalize`.
- New SubWin from the viewer: Graph > New SubWin. No key in v1 (a key owes the
  tabs §5 collision check).

## 10. Declared limits

Equal cell sizes, no divider drag. Cursors A/B share one X across subwindows.
Strip reorder stays inside its subwindow. No subwindow drag-reorder, rename or
tear-off. The n >= 5 grid is our extension of the user's rule. An older build
reading a new state stacks all strips in one column. The plot mode is per TAB,
shared by its subwindows.

## 11. Recon corrections (verified at `948f8e86`)

- The X-link predicate is copied 10x in `callback.c` (not ~13), plus the factored
  `graph_shares_x()` in `draw.c`.
- Plain/Shift/Ctrl wheel, Fit and Shared X are TCL-side in the viewer
  (`wviewer::wheel` → `pan_x`/`wheel_zoom`, `wviewer::fit`, `regenerate`), all
  tab-wide; a C-only `xgroup` would leave them linked. §7 covers both.
- `tabview` (tabs D6) shipped as the tab record's `view` field
  (`wviewer::tab_view_read`), not as an array of that name.
- `test_wave_tabs` printed no `OVERALL: ok` sentinel, so it was unregisterable as
  it stood (fixed in stage 0).

## 12. Staged test plan

New suite `tests/headless/test_wave_subwin.tcl` (registered in BOTH lists in the
commit that creates it, delta derived first). Every stage red-first.

| stage | content | rows |
|---|---|---|
| 0 | this spec; register `test_wave_tabs` (both lists); tabs §15 | — (registration delta) |
| 1 | PURE: `sw_grid`, `sw_cell`, `sw_normalize`, `sw_range`, add/close index remaps, serialise round trip both directions | `SWP1`–`SWP12` (both arms); sabotages: grid rounds `sqrt` down; normalise not contiguous; close forgets to move target |
| 2 | render: regenerate tiles the grid; graphbb per cell; `xgroup`/`swframe` written; `swframe` drawn in `draw.c`; click retargets the subwindow; frame moves in place | `SWG1`–`SWG10` (display); look debt |
| 3 | independent X: C `graph_same_xgroup` + Tcl scoping | `SWX1`–`SWX10`: MMB pan, RMB box, arrows, wheel, Ctrl+wheel, axis margin, Fit, Shared X in A leave B's `x1`/`x2` byte-identical; strips inside A still linked; sabotage: drop the loop-head test → red |
| 4 | destinations in the viewer: `newsubwin`, Replace clears the subwindow, New Strip confined, all doors routed via `plot_signals` | `SWD1`–`SWD12`; DS rows of `test_wave_sigbrowser` and `test_calc_wave_dest` updated where ruling 24's limit was pinned |
| 5 | close + re-tile, cross-subwindow trace drag, paste to target, undo, tab freeze/thaw/serialise/restore | `SWC1`–`SWC8`, `SWS1`–`SWS6`; `test_wave_tabs` and `test_wave_add_graph_undo` stay green |
| 6 | ASE-L drop-down + `auto_plot` under four choices; real `tb_bandgap` run on the display arm | `test_ase_plot_outputs` band `PO16`, `test_ase_persist` (state key count), `test_ase_window` (status bar right end) |
| 7 | user docs; owed `look` for the frame and grid | — |

Affected suites to re-run at stages 2–6: `test_wave_viewer`,
`test_wave_viewer_geometry`, `test_wave_modes`, `test_wave_split_strip`,
`test_wave_empty_strips`, `test_wave_add_graph_undo`, `test_wave_axis_zoom`,
`test_wave_cursor_crossdb`, `test_wave_markers`, `test_wave_hilight`,
`test_wave_drag_preview`, `test_wave_trace_menu`, `test_wave_tabs`,
`test_wave_grid`, `test_wave_sigbrowser`, `test_calc_plot`,
`test_ase_plot_outputs`, `test_ase_persist`, `test_ase_window`.
