# Waveform Viewer plot modes — single-plot / multi-plot + target strip

Status: SPEC (issue 0151), 2026-07-25; §12 drag-to-reorder added 2026-07-27
Related: `doc/claude/specs/waveform_viewer.md` (the viewer's shipped UX contracts),
`doc/claude/code_analysis/waveform_subsystem_reference.md` (subsystem map),
`src/wave_viewer.tcl`, `src/ase.tcl`, `src/ase_window.tcl`, `src/draw.c`.

## 1. What this adds

A waveform viewer window gains a **plot mode**, deciding where signals sent
from the schematic land:

- **single-plot** — every signal of one plot gesture goes into the **target
  strip** (one graph of the stack), appended to whatever it already holds.
- **multi-plot** — each signal of the gesture gets **its own strip**: the
  EMPTY strips already on screen are reused first, the rest are created **at the
  TOP** of the stack, and the batch reads **newest-first** — picking `v1 v2 v3`
  leaves `v3` on top and `v1` at the bottom (empty-strip reuse + newest-first
  ordering are the issue 0171 follow-ups, §4).

Plus the machinery the mode needs: a per-window target strip, a click to move
it, a dull-yellow marker showing it, Tcl get/set/invert commands, a viewer menu
entry that logs a replayable line, and a schematic-side chord + window-number
query that reach the viewer through its ASE-L session.

**And, since 2026-07-27, strips can be DRAGGED up and down the stack with LMB**
— see §12, which also records the LMB/MMB ownership split it required (the graph
pan moved from LMB to MMB).

## 2. Decisions (user, 2026-07-25)

| # | Question | Decision |
|---|---|---|
| D1 | single-plot landing | **Append** into the target strip (never replace). Clearing stays explicit (Graph > Delete…). |
| D2 | multi-plot landing | **One strip per signal.** Reuse the EMPTY strips first; create the rest at the **TOP** of the stack, newest-first within the batch (`v1 v2 v3` -> `v3` topmost). Both refinements: issue 0171 follow-ups, 2026-07-27. The ASE auto-plot graph and strips that hold traces are never touched. |
| D3 | which paths obey the mode | **Direct Plot only** (Results > Direct Plot, Ctrl-4, and any future schematic plot command). ASE auto-plot keeps its shipped always-replace-into-one-`auto 1`-graph contract; the Add Trace… dialog keeps its explicit target combobox. |
| D4 | active-strip indicator | **C, inside `draw_graph`** — a dedicated GC, exact dull-yellow RGB, drawn at the graph rect's right edge. The only option that survives partial graph redraws. |
| D5 | persistence | **Mode and target both persist** in the ASE session's `viewer` state dict, after `graphs`. |
| D6 | config default | `wviewer_plot_mode` defaults to **`single`**. |
| D7 | schematic chord | **Ctrl-Shift-4** = invert the associated viewer's mode (next to Ctrl-4 = Direct Plot). |
| D8 | indicator scope | **Viewer only** — gated by a prop token only the viewer writes, so the 127 shipped files with embedded graphs look unchanged. |

## 3. Model

### 3.1 Per-viewer state (`src/wave_viewer.tcl`)

Two new namespace arrays, keyed by session token exactly like `sharedx`:

- `wviewer::mode($token)` — `single` | `multi`.
- `wviewer::target($token)` — integer strip index (model graph index).

Initialised in `wviewer::open` (`mode` from the config var, `target` 0), torn
down in `wviewer::forget`, overwritten by `wviewer::restore`.

**Why arrays and not layout-dict keys:** the layout dict is rebuilt wholesale by
`restore` and by `set_graphs`; mode/target are window properties, not graph
properties, and follow the `sharedx` mirror precedent (menu `-variable` needs an
array element anyway).

There is exactly **one viewer window per ASE session token** (`wviewer::open`
raises rather than opening a second) and an unbounded number of tokens, so
"per-window mode" and "per-session mode" are the same thing here. Two viewer
windows = two sessions = two independent modes.

### 3.2 Config variable

```tcl
set_ne wviewer_plot_mode single      ;# src/wave_viewer.tcl, top of file
```

Sets the mode of **newly opened** viewer windows only. Read lazily, at
`wviewer::open` time, so a `--script` rc (`cadence_style_rc`, headless tests)
can still set it — the `ase_eng_notation` pattern (`src/ase.tcl:80`). An invalid
value falls back to `single` (`wviewer::default_plot_mode`). Once a window is
open, the per-window state is the authority; the global is never consulted again
for that window.

### 3.3 Target strip

`wviewer::target_index {token}` is the only read seam: it clamps the stored
value into `[0, ngraphs-1]` and returns 0 when the layout is empty, so a
deleted strip can never leave a dangling target.

Target changes:

- **Click** — a `<ButtonPress-1>` anywhere in a strip makes that strip the
  target (see §6).
- **Command** — `wviewer::set_target_strip`.
- **Never implicitly** — a multi-plot batch does *not* move the target to the
  strips it created or reused, and `Add Graph` does not move it either. The
  target moves only when the user points at a strip, names one, or a
  **single-plot** batch had to resolve elsewhere because the stored target was
  unusable (empty stack, or the target was the tool-owned auto strip) — then it
  follows the strip the signals actually landed in, so the next gesture
  accumulates there. Clear All resets it to 0, the only strip left.

## 4. Landing policy

The policy is a PURE proc so it is unit-testable headless:

```tcl
wviewer::plan_plot {mode ngraphs target n {auto -1} {empties {}}}
                                            ->  {new <count> targets {gi ...}}
```

`empties` = `wviewer::empty_graph_indices {gs {auto -1}}`, the strips holding NO
traces and not the tool-owned auto strip, in index order. Both callers
(`plot_signals`, `predict_colors`) derive it from the live model; `plan_plot`
re-sanitizes it (in-range, non-auto, deduped, sorted) because it is the policy.

| mode | layout | result |
|---|---|---|
| single | ≥1 strip, usable target | `new 0`, every signal → `target_index` |
| single | 0 strips, or target = the auto strip | reuse the first empty strip if there is one (`new 0`), else `new 1` and use the strip appended at the bottom |
| multi | any | landing sites = up to *n* empty strips (index order) + `new` = the shortfall, created at the TOP. Sites are expressed in the **post-insert** index space (new strips are `0..new-1`, everything already up is `+new`) and handed out **bottom-up**: pick *k* takes the *k*-th site from the bottom, so the LAST pick is topmost |

**Empty-strip reuse (issue 0171 follow-up, 2026-07-27).** An empty strip is a
place to plot, so a plot gesture fills it instead of appending past it. Without
this, Clear All (issue 0171) and Graph > Add Graph left a blank band pinned at
the top of the window that no plotting could ever fill, shrinking every real
strip. Which empty strips are used is decided in index order; how the picks are
DEALT over the resulting sites is newest-first (below). In single-plot mode an explicit, usable target still wins over any empty strip —
reuse only resolves the case where the target is unusable. `plot_signals` moves
the target to whatever strip the batch actually landed in (single mode only,
idempotent, so no spurious log line).

**Newest-first, new strips on top (2026-07-27 request).** A multi-plot gesture
now grows the stack UPWARD: the strips it creates go in front of the model list
and the batch is laid out so the last signal picked is the topmost. `plan_plot`
cannot carry an "insert at the top" flag without changing the result dict every
caller and test compares, so it encodes the insert in the INDICES — its multi
targets are post-insert — and **`plot_signals` is the half that actually inserts
them at the front**. A caller that appended instead would scramble the batch.
Inserting renumbers everything already on the canvas, so `plot_signals` also
shifts the stored target by the same amount: multi-plot still never RE-targets,
but the marker must not drift onto a different strip. Consequence to know: with
Shared X on, strip 0 (the x-range master at regenerate time) is now the newest
strip rather than the oldest.

`wviewer::plot_signals {token exprs {colors {}}}` applies it: create the planned
strips via `add_graph`, then `add_trace` each expression at its planned index,
returning a list of `{expr error}` pairs for the ones that failed (`add_trace`
never throws — it returns a user-displayable string).

**The mode also decides trace COLORS (issue 0153).** Because multi-plot lands
each signal in a fresh EMPTY strip, the original per-graph color cycle gave every
multi-plot trace the palette head — the "all yellow" defect. A second PURE proc
runs off the same plan:

```tcl
wviewer::plan_colors {gs mode targets}  ->  {color-per-signal}
```

`used` is seeded window-wide for `multi` and per-landing-strip for `single` (so
single-plot is unchanged), and it accumulates within the batch. It is
**prefix-stable**, which is what lets the Direct Plot picker resolve click *k*'s
color before click *k+1* exists (`wviewer::predict_colors`). `plot_signals`
derives the colors itself when `colors` is `{}`; the picker passes the colors it
already painted onto the schematic nets so the cue and the trace cannot disagree.
Full detail: `doc/claude/issues/0153-trace-colors-and-picker-hilight.md`.

`ase::ui::dp_finish` (`src/ase_window.tcl`) replaces its hard-wired
`add_graph` + "last index" with one `wviewer::plot_signals` call. Its four
early-return gates (op-only results, viewer-open failure, no raw yet, empty
queue) are unchanged: an empty queue still leaves only a raised viewer.

**Contract change, deliberate (D2):** item 13's "one NEW stacked graph per
invocation" becomes mode-dependent. In single-plot mode a Direct Plot creates
**no** new graph when the stack is non-empty; in multi-plot it creates one per
signal **minus the empty strips it reused** (issue 0171 follow-up) — so a viewer
just cleared with Ctrl-D ends up with exactly *n* strips, not *n+1*.

## 5. The active-strip indicator

- **Model → prop:** `wviewer::graph_props {G {active 0}}` appends `active=1`
  when told to. `regenerate` passes `active 1` for the target strip **only when
  the stack holds more than one strip** — one strip has no ambiguity to resolve,
  so nothing is drawn (spec requirement, and it keeps the single-graph case
  pixel-identical to today).
- **Prop → C:** `setup_graph_data` parses the `active` token into a new
  `Graph_ctx.active` field. The field is defaulted **before** the
  `RECT_OUTSIDE` early return (landmine 11 — `xctx->graph_struct` is reused
  across graphs, a stale value would leak onto an off-screen graph).
- **Draw:** `draw_graph` fills a vertical bar at the container's right edge,
  `(sx2-w, sy1)`–`(sx2, sy2)`, through a dedicated `xctx->gc_graph_active` GC,
  into `xctx->window` and `xctx->save_pixmap` — the `draw_hilight_dot`
  (`draw.c`) idiom, so the bar is repainted by every path that repaints the
  graph, including the interactive partial redraws that erase anything drawn
  from Tcl.
- **Export gate:** drawing is gated on a **new `flags` bit 16** of
  `draw_graph`, set only by the four on-screen callers (`draw_graph_all`,
  `callback.c` ×3, `scheduler.c` `draw_graph` verb). The export callers
  (`svg_embedded_graph`, `psprint.c` ×2) pass `8 + …` and so never draw it —
  a printed schematic must not carry a UI marker.
  **Image export needs a second gate:** `print_image()` (PNG/XPM, the
  `xschem print png` verb) does not call `draw_graph` at all — it renders
  through `draw()`, which *does* set bit 16, into `save_pixmap`, the very
  drawable that gets encoded. It therefore brackets its `draw()` call with the
  file-static `draw_no_ui_decorations`, which `draw()` consults when composing
  the flags word (measured: 1945 marker pixels leaked into a PNG before this
  gate, 0 after). Any future on-screen-only decoration drawn from `draw()` must
  honour the same flag.
- **Color / width:** Tcl vars `graph_active_strip_color` (default `#a0a000`,
  a dull yellow) and `graph_active_strip_width` (default 5 screen px), resolved
  in `build_colors()` via `find_best_color` — the `hover_highlight_color`
  pattern (`xinit.c`), so a theme switch or `xschem build_colors` re-resolves it
  and the user can retune it from an rc.

**Not asserted by tests:** the pixels. Consistent with the viewer suite's
standing note ("the actual PIXEL rendering of the waves is eyeball-only"), the
tests assert the *token* plumbing (which rect carries `active=1`, when it is
absent) and that a redraw with the token present returns rc 0. The C draw itself
is sabotage-verified by hand and eyeball-checked.

## 6. Click to re-target

`strip_bindings` gains a `<ButtonPress-1>` binding on the viewer canvas:

```tcl
bind $wp <ButtonPress-1> {wviewer::click_target %W %x %y
                          focus %W
                          xschem callback %W %T %x %y 0 %b 0 %s
                          break}
```

The manual forward is **required**: `<ButtonPress-1>` is more specific than the
kept generic `<Button>`, so binding it would otherwise swallow the C engine's
cursor-drag / graph-pan press. The forwarded substitution string is byte-for-byte
the generic one from `set_bindings` (`src/xschem.tcl`), and the trailing `break`
makes the outcome identical whether the generic binding lives on this widget's
tag or the toplevel's (exactly one forward either way).

`wviewer::click_target` resolves the strip with `wviewer::strip_at_pixel` (the
`graphbb` registry hit-tested against the event's own pixel, converted with the
inverse of `X_TO_SCREEN`) and does nothing when the pointer is outside every
band or the strip is already the target. It deliberately does **not** use
`graph_at_pointer`, which reads the C-tracked `mousex_snap` — stale for a press
that had no preceding Motion.

**A re-target must never regenerate.** `regenerate` re-places every rect from
the Tcl model, and the C engine writes its own graph state (RMB box-zoom /
graph-pan ranges, private cursors) straight into the rect prop where the model
never sees it — so regenerating on a click would silently undo a zoom the user
had just made with the mouse. Every other Tcl range mutator avoids that by
freezing the live ranges first (`graph_range` / `apply_range`); a marker-only
edit needs neither: `wviewer::move_marker` rewrites the `active` token in place
on the two affected rects (empty value CLEARS it, so an inactive strip reads
exactly as `regenerate` would have written it) and redraws.

## 7. Command surface

All are plain namespaced procs, typable in the CIW (`ciw_exec` does
`uplevel #0`), and headless-safe (`{}` + `ciw_echo`, never a throw).

| Command | Meaning |
|---|---|
| `wviewer::plot_mode ?token?` | current mode, or `{}` when no viewer resolves |
| `wviewer::set_plot_mode <single\|multi\|invert> ?token?` | set/flip; returns the resolved mode or `{}` |
| `wviewer::target_strip ?token?` | current target index, or `{}` |
| `wviewer::set_target_strip <gi> ?token?` | move the target; returns the clamped index or `{}` |
| `wviewer::move_strip <from> <to> ?token?` | reorder strips (§12); returns the final index or `{}` |
| `wviewer::current_token` | token of the viewer owning the current xschem window, else `{}` |
| `ase::plot_mode_for_current ?mode?` | from a DESIGN window: flip (default `invert`) the mode of the viewer of the session bound to this design |
| `ase::window_number_for_current` | from a DESIGN window: the Cadence window number of the associated ASE-L window |
| `ase::ui::number_for <key>` | the ASE-L window number of a session key, or `{}` (public accessor for the private `wnum` dict) |

**Omitted `token` = "the active waveform window"**: `wviewer::current_token`
resolves `xschem get current_win_path` through `token_for_canvas`. The C context
— not Tk focus — is the source of truth, matching every other per-window command
in the tree.

`invert` is resolved by the PURE helper `wviewer::resolve_mode {cur req}`, which
also rejects garbage (`{}`) — so the request word never reaches storage
unvalidated.

### 7.1 Replayable logging

`wviewer::set_plot_mode` logs, on an actual change only:

```
wviewer::set_plot_mode <resolved-mode> <token>
```

through the thin seam `wviewer::log_action` (the `slickprop::log_apply`
pattern: one `catch {xschem log_action $line}`, so tests can hook it as a spy
point). Two properties matter:

- **the resolved mode is logged, never `invert`** — replaying a log must not
  depend on the state at replay time;
- **the token is always explicit** — replay must not depend on which window is
  active.

`log_action` mirrors into the CIW pane, which is what "logged in a replayable
way in the CIW" means here. The same seam logs `wviewer::set_target_strip` on
an actual change, including the click path (a plot sequence is only replayable
if the target moves are in the log). Neither is logged when the value does not
change, so a cursor drag that starts inside the current target is silent.

## 8. Menu

The viewer menubar gains an **Options** cascade (the cascade list in
`build_menubar` is a fixed `foreach` pair list; Options is appended after
Cursors), holding a **Plot Mode** submenu with one dynamic entry:

- current mode `single` → label **`Set Multi-plot Mode`**
- current mode `multi` → label **`Set Single-plot Mode`**

The relabel runs from the submenu's `-postcommand` (`edit_menu_post` is the
in-tree precedent for a state-dependent label), so the label is correct however
the mode was last changed — menu, command, chord, or state restore. Invoking it
calls `wviewer::set_plot_mode invert $token`, which performs the change and
writes the replayable line.

## 9. Schematic-side entry

- **Ctrl-Shift-4** in `src/cadence_style_rc`, next to the Ctrl-4 Direct Plot
  bind, ending in `break` (the same idiom that overrides C's `Ctrl+<digit>` =
  select drawing layer). **The bind that actually fires is the SHIFTED
  keysym**: a physical Ctrl+Shift+4 arrives as `dollar` on a US layout, so
  `<Control-Shift-Key-4>` alone would never match — the same gotcha the rc
  already documents for Ctrl-Shift-2 (`<Control-Key-at>`). Both forms are
  bound; the `Key-4` one covers layouts where Shift-4 stays `4`:

  ```tcl
  bind .drw <Control-Key-dollar>  {ase::plot_mode_for_current invert; break}
  bind .drw <Control-Shift-Key-4> {ase::plot_mode_for_current invert; break}
  ```

- `ase::plot_mode_for_current` resolves design → session (`design_of_current` +
  `session_for_design`, the Ctrl-4 path) → the viewer token (= the session key)
  → `wviewer::set_plot_mode`. Honest `ciw_echo` and `{}` for: not a schematic
  view, no ASE-L session bound to this design, or **no viewer window open** for
  that session (mode is per-window state; there is nothing to flip until the
  window exists — the notice tells the user to open the viewer).

- `ase::window_number_for_current` answers "which window number is my ASE-L
  session?" — design → session → `ase::ui::number_for`. `{}` + `ciw_echo` when
  no session or (headless) no window.

- **The chord GUARANTEES that the schematic keeps the context and the viewer
  keeps its title** (issue 0173). Ctrl-Shift-4 is fired from the design window
  and the design window is where the user still is, so the whole path now
  performs **zero** `new_schematic switch` calls: `wviewer::status_refresh` reads
  `xschem get graph_snap` only when that viewer's context is already current (the
  motion pump inside the viewer — which is the only place the snap is ever
  fresh, since the C hover pump refuses to run for a non-current window). The
  MODE half of the status bar needs no context at all, so the item-10 PUSH
  contract is unaffected.

  Pre-0173 the read went through `wviewer::in_ctx`, which switched into the
  viewer and stayed there. The consequences were not obviously context-shaped:
  the viewer's title became `xschem [N] - untitled.sch (read-only)` (the C
  switch ends in `set_modify(-1)`, whose job is the title), the next click in the
  schematic acted on the viewer, and the schematic canvas went inert in a way
  that read as lost focus. See the issue file for the full mechanism.

  Any future Tcl on this path that must read or draw inside the viewer uses the
  `wviewer::enter_ctx` / `wviewer::leave_ctx` ticket — verified both ways
  (landmine 17), restores the context, re-asserts the viewer title — never a bare
  `new_schematic switch`.

## 10. Persistence

`wviewer::snapshot` gains two keys, appended **after** `graphs`, keeping the
documented byte-deterministic build order:

```
viewer {open 0|1 sharedx 0|1 rawfile {} graphs {…} mode single|multi target N}
```

`wviewer::restore` reads them with defaults (`default_plot_mode`, 0) so every
state file written before this change loads unchanged. The closed-window
snapshot arm (`dict replace $prev open 0`) carries them through untouched.

The committed fixture `test_nfet_final.state` keeps `viewer {}` (a session that
never opened a viewer), so the `test_ase_final` byte-identity round trip is
unaffected.

## 11. Non-goals / deferred

- **Overlaid traces with per-trace y scaling** in single-plot mode. A strip
  carries one `y1/y2` pair; single-plot means "one strip", not "one axis per
  trace".
- **Mode in the window title.** The title is asserted by the shipped suite; the
  menu label and the yellow marker are the affordances for now.
- **Auto-plot and the Add Trace… dialog obeying the mode** (D3) — auto-plot's
  always-replace `auto 1` graph is a different policy axis.
- **A viewer-window-number command** (`ase::window_number_for_current` covers
  the ASE-L window, which is what was asked). The viewer is a normal editor
  window, so `xschem get window_number` already answers it when the viewer is
  the current context.
- **A keyboard chord for target movement.**
- **LMB trace-to-strip dragging** — the 10-pixel trace exclusion zone (§12)
  is reserved for it, but nothing implements it yet.

## 12. Drag-to-reorder strips (2026-07-27)

A strip is one graph of `wviewer::layouts` — its traces, colors, axis settings
and any `auto 1` marker. It can now be dragged up or down the stack with LMB.
Reordering never touches the order of traces *inside* a strip.

### 12.1 The gesture

| | |
|---|---|
| Where LMB grabs | the **reorder handle** (always) or **empty waveform body** |
| Handle | the rightmost **14 screen pixels** of every strip, full band height, with a three-bar grip drawn in it by the C engine (`GRAPH_REORDER_HANDLE_W`, `src/xschem.h`) |
| Trace exclusion zone | **10 screen pixels** around every displayed trace — LMB there stays with the C engine, and is reserved for future LMB trace-to-strip dragging |
| Cursor exclusion | a press that grabbed an x/y cursor keeps the whole drag, wherever it landed |
| Movement threshold | **more than 3 pixels** of vertical travel starts the drag |
| Destination | crossing another strip's vertical **midpoint** selects that strip; past the top/bottom of the stack **clamps** to first/last |
| Commit | LMB release |
| Cancel | **Escape** |
| No-ops | a click below the threshold, and a drop back at the original position — neither mutates, neither logs |

The handle is a *fixed pixel* width, not a fraction of the strip, so it stays
the same size at any canvas zoom; the same is true of the trace exclusion zone,
which is measured by the engine (§12.4) rather than approximated from the strip
geometry in Tcl.

**The two AXIS-NUMBER MARGINS have left the reorder zone (2026-08-01, issue
0190, §17).** They were never in the sentence above — the grab is "the reorder
handle (always) or empty waveform body" — but `strip_at_pixel` tests the whole
band, so a press on the X or Y tick numbers armed the reorder anyway. It now
zooms that axis instead. **The handle and the empty body are unchanged**, and so
is every exclusion listed above: a cursor grab, a marker press and the grip all
still win in the margins, which is why the viewer learns about the change by
asking C what the press armed rather than by hit-testing (§17.5).

### 12.2 Model operations

```tcl
wviewer::reorder_graphs  {graphs from to}   ;# PURE
wviewer::reordered_index {index from to}    ;# PURE
wviewer::move_strip      {from to ?token?}  ;# THE mutation
```

`to` is the **final index the moved strip occupies**, not an insertion slot:

```text
graphs = A B C D ;  from 1 , to 3  ->  A C D B
```

`reordered_index` maps an index that identified a graph *before* the move to the
index of the *same* graph after it — that is how the target strip follows graph
**identity** instead of staying attached to a numeric slot.

`move_strip` resolves the token, validates both indices, returns without
mutating when `from == to`, verifies the context switch, **captures the live
C-written graph state** (§12.3), reorders the list, remaps the stored target
with `reordered_index`, regenerates **exactly once**, and writes **exactly one**
fully-resolved log line. It returns the final index, or `{}` on failure. The
moved dictionary carries its traces, colors, axis settings, `auto 1` identity
and any future per-graph key for free — it is never rebuilt field by field.

### 12.3 Preserving live C-written state

`regenerate` re-places every rect **from the Tcl model**, and the C engine
writes its own results (MMB graph pan, RMB box-zoom, the LMB wave-bold) straight
into the rect prop text where the model never sees them. A reorder must not undo
a pan.

```tcl
wviewer::capture_live_graph_state {token}
```

folds `x1 x2 y1 y2 hilight_wave` back from every live rect into the model first.
`graph_props` emits `hilight_wave` **only when the model carries it**, so a strip
nobody ever bolted keeps generating exactly the props it did before. Cursors are
not captured: the viewer creates its graphs with `flags=graph`, not
`private_cursor`, so cursor positions are global and survive a rect rebuild
untouched — if that ever changes, `cursor1_x`/`cursor2_x`/`hcursor1_y`/
`hcursor2_y` join the list. The helper aborts cleanly when `switch_ctx` fails;
it never reads a rect prop from an unverified context.

Shared X is unaffected: with `sharedx` on, all strips already hold the same live
X range, so a different graph becoming index 0 changes nothing.

### 12.4 Hit testing and gesture seams

```tcl
wviewer::strip_bands_px        {wp}                  ;# graphbb -> canvas pixels
wviewer::strip_handle_at_pixel {canvas px py}
wviewer::strip_drop_index      {canvas py ?from?}
wviewer::strip_at_pixel_inset  {canvas px py ?inset?}
wviewer::near_wave_at          {wp gi px py ?tol?}
wviewer::cursor_grabbed        {wp}
wviewer::strip_drag_press      {W x y state}
wviewer::strip_drag_motion     {W x y state}
wviewer::strip_drag_release    {W x y state}
wviewer::strip_drag_cancel     {W}
```

All of them take the **event's own `%x`/`%y`**. `graph_at_pointer` is
deliberately not used for press or release: it reads the C mouse-position
mirror, which is stale for a press with no preceding Motion (the `strip_at_pixel`
precedent, §6).

`strip_drop_index`'s optional `from` is what makes the midpoint rule symmetric —
without the grabbed strip's identity, "the last midpoint crossed" is biased
downward and an upward drag proposes a move one strip too early. Omitted, it
falls back to "the band whose midpoint is nearest".

Two C-backed queries answer the exclusion questions, because neither can be
honestly approximated in Tcl:

```tcl
xschem get graph_near_wave <graph_idx> <px> <py> ?tol?   ;# default tol 10
xschem get graph_flags
```

`graph_near_wave` (`draw.c`) walks the graph's own transform and raw data and
returns 1 only when the pixel is within `tol` **screen pixels** of a drawn trace
— a real point-to-segment distance, unlike `find_closest_wave`, which has no
threshold at all. It answers 0 for digital strips and bus traces (their rendering
is a band/ribbon, not a polyline), so the whole body is reorder space there.
`graph_flags` exposes the session cursor-mode word so the press seam can tell
"this press grabbed a cursor" from "this landed on empty space" (reference
backlog #1). Both fail closed.

Transient per-window drag state lives in `drag_from` / `drag_to` / `drag_y0` /
`drag_active`, created in `open`, dropped by `forget`, **never serialized**.

### 12.5 Bindings and interaction ownership

| Gesture | Owner |
|---|---|
| LMB on empty body / the handle | **Tcl** — target + strip reorder |
| LMB within 10 px of a trace, or a cursor grab | **C** — cursor drag/move, trace pick, wave-bold click |
| **MMB** drag | **C** — graph pan (data ranges; the canvas never moves) |
| RMB drag | **C** — box zoom (unchanged) |
| LMB **click** (release, no travel) within 10 px of a trace | **C** — that trace becomes THE selection, anywhere in the window; re-clicking it keeps it |
| LMB **click** further than 10 px from every trace | **C** — clears the selection |

**The precise-pick rule (issue 0174).** The wave-bold click is a *pick*, not a
"nearest wins" — it uses `graph_wave_at()` at `GRAPH_TRACE_PICK_TOL`
(`src/xschem.h`, 10 screen px), the same query at the same tolerance that
`trace_menu_pick`, `strip_drag_press` and `strip_menu_pick` already gate on. One
number for every trace-picking surface on a strip: they were allowed to diverge
once (a precise RMB menu and an imprecise LMB select, same strip, same pixel)
and that divergence *was* the bug report. The click also compares the trace it
just picked, so a click on trace B while trace A is selected **moves** the
selection; only a click on the already-selected trace clears it.

**The selection is ONE TRACE IN THE WINDOW, not one per strip.** `hilight_wave`
is a per-RECT prop token, so the arm additionally clears it on every *other*
graph rect; without that, a click on strip B left strip A's trace bold too. A
miss clears everything. Deselecting a SINGLE trace while keeping the rest is
Ctrl+click, which is also the only way to add to a selection — 0175.

⚠ **This table is the REORDER section's view of ownership and it is no longer
complete.** Since issue 0175 the selection is a SET, the LEGEND is a second
picking surface, and Ctrl+LMB adds/removes. **§15 carries the full LMB/RMB
ownership table for the viewer canvas** and supersedes the two selection rows
above; everything else here still stands.

Clearing on a miss does **not** collide with the strip drag-reorder that owns the
same pixels: the two are separated by the TRAVEL test, not by the pick. A real
reorder drag travels well past `GRAPH_CLICK_TOL` (3 px) and its release never
reaches this arm; only a press-release that moved less than that clears, which is
a click by any definition.

Digital strips and bus traces answer -1 across their whole body (a band/ribbon is
not a polyline), so a click there clears. That loses nothing — the pre-0174 pick
refused them too, it just refused by writing an uninitialised value into the
token.

`<ButtonPress-1>` runs `strip_drag_press` first; when it does not consume the
event the pre-existing issue-0151 body runs verbatim (target change, focus, C
callback, `break`). `<B1-Motion>` and `<ButtonRelease-1>` are **more specific**
than the kept generic `<Motion>`/`<ButtonRelease>`, so their non-drag paths
forward the original event to `xschem callback` exactly once — and the release
also does the readout refresh that was appended to the generic bind.

**The graph pan moved from LMB to MMB** (`callback.c`): `waves_selected` no
longer skips Button2, `GRAPHPAN` starts on Button2 as well, and the pan motion
arms test `Button2Mask`. This is engine-wide — MMB over an on-canvas schematic
graph now pans that graph instead of the canvas; off a graph MMB is still the
canvas pan, and a canvas pan already in flight is protected by the `STARTPAN`
entry in `waves_selected`'s exclusion mask. In the viewer, `btn2_filter`
forwards MMB but accepts the **press** only well inside a strip, so it can never
reach `start_pan_logged` and slide the tiled canvas (the issue-0149 invariant);
Ctrl/Alt+MMB stay inert.

`wviewer::key_filter` cancels an in-flight drag on Escape **before** its normal
Escape forward (D10 keeps ESC reaching C for its abort+redraw).

### 12.6 Feedback

The `reorder_handle` prop token drives all of it, parsed in `setup_graph_data`
**before** the `RECT_OUTSIDE` early return (landmine 11) and drawn in
`draw_graph` under the on-screen **flags bit 16** only, exactly like the
active-strip marker — no grip or drop bar ever reaches SVG/PS/PNG export:

| value | drawn |
|---|---|
| 1 | the grip (every viewer strip; `graph_props` writes this) |
| 2 | grip + a drop bar along the strip's **top** edge (drag going up) |
| 3 | grip + a drop bar along the strip's **bottom** edge (drag going down) |

2 and 3 are transient: Tcl rewrites the token in place on the two affected rects
when the prospective destination changes — **not on every Motion**, and never a
regenerate (which would undo a live pan, the `move_marker` argument of §6) — and
clears it on commit or cancel. The pointer becomes `sb_v_double_arrow` while the
drag is active and is restored on both exits.

### 12.7 Persistence and logging

No schema change: snapshots already serialize the graph list in order, so the new
order persists for free.

The log records **committed state changes only** — never Motion, never a
cancelled drag, never a no-op drop:

```tcl
wviewer::set_target_strip 0 <token>     ;# only when the press moved the target
wviewer::move_strip 3 0 <token>
```

The target line comes first when the press changed the target, because replaying
`move_strip` alone against a *different* pre-existing target would remap the
wrong strip. The internal `reordered_index` remap emits **no** second target
line: it is a consequence of `move_strip`, not a separate user action. Both go
through the `wviewer::log_action` seam, following the `set_plot_mode` /
`set_target_strip` conventions (resolved words, explicit token).

### 12.8 Tests

`tests/headless/test_wave_modes.tcl` — `M7` (pure: all 16 from/to permutations
of a four-strip list, up/down by one and several, first↔last, `from == to`,
invalid and non-integer indices, `reordered_index` identity tracking across every
permutation, byte-identical moved dicts, `auto 1`, the `reorder_handle` and
`hilight_wave` tokens) and `MG14` (a real viewer: model/rect/`graphbb` agreement,
target following both cases, live `x1/x2/y1/y2/hilight_wave` survival, auto-plot
identity, save/restore, and full Tk press/motion/release drags from the handle
*and* from empty body — clamping, sub-threshold, no-op drop, Escape, drop-bar
feedback, exactly-one-log-line).

`tests/headless/test_wave_viewer.tcl` — `SD` (the LMB seam, with real raw data:
the screen-pixel semantics of `graph_near_wave`, a near-trace click still bolds,
a near-trace drag never reorders, the same drag from empty space does, a cursor
press-drag-release still moves the cursor and never reorders) and `WB-mmb-drag`
(MMB pans the graph range, LMB no longer does, the canvas stays put).

Not asserted, consistent with the standing note in §5: the **pixels** of the grip
and the drop bar. What is asserted is the token plumbing and that a redraw with
the tokens present returns rc 0.

---

## 13. Drag a trace between strips (2026-07-28)

The other half of the LMB seam §12 opened. Press **on a trace**, drag onto
another strip, release: the trace moves there. The strips themselves never
reorder, and the traces inside a strip keep their order.

The two gestures are mutually exclusive by *where the press landed* — empty
waveform body (or the handle) reorders strips, the 10-screen-pixel zone around a
drawn trace picks that trace up — so one press arms exactly one of them.

### 13.1 The gesture

- **Press on a trace** arms the move and turns the pointer into the grab hand
  (`hand2`, the Acrobat pan-hand affordance the user asked for). The press is
  still forwarded to C verbatim, so the engine's own bookkeeping (`GRAPHPAN`, the
  click anchor `graph_press_x/y`) stays consistent with the release.
- A press that **grabbed a cursor** still wins: a cursor can be parked on top of
  a trace, and cursor dragging is the more precise interaction.
- **> 3 px of travel in either axis** (the click tolerance `GRAPH_CLICK_TOL`)
  starts the drag; from then on Motion is consumed, so no C hover/pan/cursor
  work happens under it.
- The **destination follows the pointer**: the strip its pixel is inside, from
  `strip_at_pixel` — the event's own coordinates, never `graph_at_pointer`
  (§12.4).
- **Release over a different strip commits.** A drop on the source strip, a drop
  outside every strip, a sub-threshold click and Escape all commit nothing and
  log nothing — so the issue-0152 wave-bold click still works exactly as before.
- The moved trace keeps its **expression, alias, vector and color** and lands at
  the **end** of the destination's trace list. A duplicate is allowed (duplicate
  traces are already representable).
- The **source strip stays** even when it ends up empty: deleting it would
  renumber the stack behind the user's back and lose its axis settings.

### 13.2 Model operations

Pure, headless-testable, in `wave_viewer.tcl`:

| proc | what |
|---|---|
| `node_count G` | how many of `G`'s traces reach the `node` token |
| `node_index_of_trace G ti` | model trace index → C **node** index |
| `trace_index_of_node G ni` | the inverse |
| `remap_hilight_after_trace_move hw moved_ni` | the bold-marker index math |
| `move_trace_in_graphs graphs from_gi from_ti to_gi` | the list move itself |

The **model index and the node index are not the same space**: `graph_props`
skips a trace with an empty `vec` when it builds the `node` token, so such a
trace occupies a model slot and no node slot. Every C answer (`graph_trace_at`,
`hilight_wave`) is in node space and must go through the mapping before it
indexes the model.

`move_trace_in_graphs` carries the trace **dictionary whole** — never rebuild it
field by field — and does two things beyond the list move:

- **`hilight_wave` on both graphs.** The bold trace leaving decrements nothing
  and instead clears the source marker and re-bolds the trace at its new node
  index in the destination; a bold trace *above* the moved one shifts down by
  one; an unrelated destination highlight is preserved.
- **An empty destination's ranges are blanked** (`x1/x2/y1/y2` → `{}` = auto).
  `capture_live_graph_state` has just frozen the live rect, so an empty strip's
  stored window is whatever the last fit left it; a µA trace dropped into a
  0–2 V window would be drawn off-screen and the drop would look like it failed.
  `regenerate` re-autozooms blank ranges — the same treatment a trace landing in
  a fresh strip gets from `add_trace`/`plot_signals`. A destination that already
  holds traces keeps the window the user is looking at.

### 13.3 The one mutation

```tcl
wviewer::move_trace {from_gi from_ti to_gi ?token?}   ;# -> destination trace index, or {}
```

Same ordering contract as `move_strip` (§12.2/§12.3), for the same reasons:
validate against the live model → `from_gi == to_gi` returns without mutating or
logging → verified `switch_ctx` → **`capture_live_graph_state` first** → the pure
move → the **destination becomes the target strip**, set *in place* (not through
`set_target_strip`, which would emit a second replay line for an internal
consequence) → exactly one `regenerate` → exactly one fully-resolved log line:

```tcl
wviewer::move_trace 0 2 1 <token>
```

### 13.4 Hit testing

```tcl
xschem get graph_trace_at <graph_idx> <px> <py> ?tol?    ;# node index, or -1
```

Backed by `graph_wave_at()` (`draw.c`), which is `graph_near_wave()` with the
identity of the trace kept — the same point-to-segment screen-pixel distance,
threshold, local `Graph_ctx` and caller-supplied pixels; **nearest wins**, ties
go to the first node in the list. `graph_near_wave()` is now a one-line wrapper
over it, so the zone the strip reorder refuses and the zone a trace is picked up
from are by construction the same boundary. Same documented limits: digital
strips and bus traces answer -1, and the scan is capped by the graph's x window.
It fails closed in Tcl (`trace_at` → -1) so a missing verb degrades to the
previous behaviour instead of grabbing something.

### 13.5 Feedback

A fourth `reorder_handle` value, following the §12.6 rules exactly (parsed before
the `RECT_OUTSIDE` return, drawn under flags bit 16 only, transient, never
written by `graph_props`):

| value | drawn |
|---|---|
| 4 | grip + a **frame** around the whole strip — the trace's drop target |

A frame rather than an edge bar because the whole strip is the target here, not
one of its edges. Rewritten in place on the affected rects only when the
prospective destination changes, cleared on commit/cancel, never a regenerate.

### 13.6 Tests

`tests/headless/test_wave_modes.tcl` — `M8` (pure: first/middle/last trace,
append order, emptied-but-kept source, three-strip isolation, byte-identical
trace dicts, duplicates, every refusal, the node/model index mapping and its
round trip, the `hilight_wave` remap in all four cases, the empty-destination
range blanking) and `MG15` (a real viewer, no raw needed: return value, model and
**rect** agreement, one resolved log line, the destination becoming the target,
every refusal logging and mutating nothing, live `x1/x2/y1/y2/hilight_wave`
survival, the bold marker following its trace).

`tests/headless/test_wave_viewer.tcl` — `TD` (real raw data, full Tk
press/motion/release through the shipped bindings): the grab-hand pointer on
press, a trace drag armed instead of a strip reorder, the drop-target frame
appearing and clearing, the model untouched mid-drag, the move down and back up,
strip identity unchanged throughout (an `sdid` key witnesses *which strip* is at
each index, independently of *which trace* is in it — on a two-strip stack a
trace move and a strip reorder are otherwise indistinguishable), alias/color
preservation down to the rect tokens, one log line, the sub-threshold click still
bolding, Escape cancelling, and the bold marker following the trace across.

---

## 14. Undo / redo of viewer edits (2026-07-28)

The two drags of §12 and §13 are **edits**, so they get a history: `u` undoes,
`U` (Shift-u) redoes.

### 14.1 Why it is not the C undo stack

A viewer edit changes the **Tcl model** (`wviewer::layouts` — the graph list —
plus the target strip). The rects are regenerated wholesale from that model, the
viewer buffer is held `readonly`, and the C undo stack is about schematic
objects. So the history is a per-window stack of **model snapshots**, and undo is
"put that snapshot back and regenerate" — one more model write like every other.

A snapshot is `{graphs target}`. The graph list already carries traces, colors,
axis ranges, `auto` and `hilight_wave`, so everything durable rides along. Window
**options** — plot mode, Shared X, the cursor mirrors, the loaded raw — are
deliberately *outside* it: they are not edits of the plot content, and an undo
that silently flipped the plot mode would be a surprise.

Snapshots are taken **after `capture_live_graph_state`**, so the pan/zoom/bold
the user made with the mouse before the edit comes back with the undo instead of
being replaced by whatever the model last remembered.

### 14.2 Surface

```tcl
wviewer::undo ?token?            ;# -> 1, or {} when there is nothing to undo
wviewer::redo ?token?
wviewer::history_depth ?token?   ;# -> {undo redo}, the test/UI seam
wviewer::push_undo token         ;# record the current state as an undo point
wviewer::clear_history token
```

`push_undo` is the extension seam: **any** future model mutation becomes undoable
by calling it right after its `capture_live_graph_state`. A new edit clears the
redo branch (linear history); the stack is capped at `wviewer::undo_depth` (50)
per window.

The mutations that participate today:

| mutation | notes |
|---|---|
| `move_strip` (§12) | the drag-reorder |
| `move_trace` / `move_trace_to_new_strip` (§13) | trace between strips |
| `split_strip` | |
| `delete_empty_strips` | bare `e` |
| `marker_changed` (the C push hook) | the undo point for **every** marker create/delete/drag, `delete_all_markers` included — the wrapper never pushes one itself |
| **`delete_items`** (§16, issue 0176) | the ONE trace/strip/marker deleter, shared by the Delete dialog and the DEL key. ⚠ Its dialog half had NO undo point and NO log line before 0176 — a pre-existing defect repaired by the extraction, not by this feature |

`clear_all` and `plot_signals` deliberately do **not**: they replace the whole
plot rather than editing it.

The history is transient — created on open, dropped by `forget`, cleared by
`restore` (which replaces the model wholesale) and never serialized: a saved
layout carries the state, not the history that produced it.

Both commands log one resolved line through the usual seam:

```tcl
wviewer::undo <token>
wviewer::redo <token>
```

### 14.3 Keys

On the shared **`WaveViewer` bindtag**, exactly like Clear All (§ issue 0171) —
not on the canvas, which `strip_bindings` sweeps:

```tcl
bind WaveViewer <Key-u> {wviewer::undo_at %W; break}
bind WaveViewer <Key-U> {wviewer::redo_at %W; break}
```

Both are installed only when the sequence is still unbound, so an rc keeps
winning and `{break}` disables. `u`/`U` were inert in this window before —
`key_filter` forwards only the `waves_callback` key set (`a b s m t A B`) — so
nothing is taken away from the C engine. `undo_at`/`redo_at` resolve the token
from `%W`, never from the current xschem context.

### 14.4 Tests

`tests/headless/test_wave_modes.tcl` `MG16`: empty-history refusals (no mutation,
no log), a reorder undone and redone with the target and the **rects** following,
a trace move undone and redone, LIFO across three mixed edits back to the
original layout, a new edit dropping the redo branch, mouse-written zoom and bold
surviving an undo, the depth cap, `restore` clearing the history, and the real
`u`/`U` keys through the bindtag including the rc-remap and `{break}` contracts.

`tests/headless/test_wave_viewer.tcl` `TD7`: the whole user story with real raw
data — drag a trace to another strip, press `u`, press `U`, press `u` again.

## 15. Trace SELECTION (2026-07-30, issue 0175)

The selection is a **SET of traces**, held **per window**, stored **per strip**,
and queried as a fold across the strips. It is view state: no dirty flag, no
undo point, no log line (landmine 19).

### 15.1 The full LMB/RMB ownership table for the viewer canvas

This is the table future work reads. "Body" is the plot box; "legend" is the band
of trace names above it; "margins" is everything else inside the strip rect
(axis numbers, the reorder grip).

| gesture | where | owner | effect |
|---|---|---|---|
| LMB press-drag (> 3 px) | empty body / the grip | **Tcl** | strip drag-REORDER (§12) |
| LMB press-drag (> 3 px) | within 10 px of a trace | **Tcl** | trace drag between strips (§13) |
| LMB press-drag (> 3 px) | the **bottom (X-number) margin** | **C** | zoom X on every PARTICIPATING strip (§17, issue 0190) |
| LMB press-drag (> 3 px) | the **left (Y-number) margin** | **C** | zoom Y on that strip only (§17) |
| LMB press-drag | on a cursor / a marker | **C** | cursor drag, marker anchor/label drag |
| LMB **click** (no travel) | within 10 px of a trace | **C** | the selection BECOMES that trace |
| LMB **click** | empty body | **C** | the selection is CLEARED |
| LMB **click** | a legend entry | **C** | the selection BECOMES that trace |
| LMB **click** | a margin owning no entry | **C** | **nothing** |
| **Ctrl**+LMB click | a trace, or a legend entry | **C** | ADD it, or REMOVE it if already selected |
| **Ctrl**+LMB click | anywhere that owns no trace | **C** | **nothing** — Ctrl never clears |
| LMB **double**-click | a legend entry (embedded graphs) | **C** | the wave dialog; the selection is unchanged |
| LMB **double**-click | **on a marker** (viewer) | **Tcl seam, C policy** | selects that marker **and**, for a difference marker, the reference its deltas are derived from (issue 0189, `graph_markers.md` D13). `wviewer::marker_dblclick_at` asks `xschem get graph_marker_at` and delegates the policy to `xschem graph_marker select -pair`, then `xschem redraw`. Still `break`s |
| LMB double-click | anywhere else (viewer) | **Tcl** | swallowed (`{break}`, D9) — the `break` is **unconditional**, so no graph-properties dialog can ever appear over a read-only viewer |
| **Ctrl**+wheel | the **bottom (X-number) margin** | **Tcl seam, C maths** | zoom **X only**, on every strip, anchored at the pointer (§18, issue 0191). The viewer asks `xschem get graph_axis_at` for the region and `xschem get graph_axis_wheel_map` for the window; it hit-tests and computes nothing |
| **Ctrl**+wheel | the **left (Y-number) margin** | **Tcl seam, C maths** | zoom **Y only**, on the pointed strip, anchored at the pointer (§18) |
| **Ctrl**+wheel | the body, the legend, the grip | **Tcl** | **unchanged**: X on every strip **and** Y on the pointed one, `wviewer::zoom_about` (issue 0144/0146). A `NONE` region answer falls through to exactly this |
| plain / Shift wheel | anywhere | **Tcl** | **unchanged**: Y pan / X pan of the stack |
| MMB drag | anywhere on a graph | **C** | graph pan |
| RMB press-drag | the body | **C** | box zoom |
| RMB **click** | on a trace, in the body | **Tcl** | the trace context menu (item 7) |
| RMB **click** | a legend entry | **Tcl** | the trace context menu for that entry's trace (issue 0178) |
| RMB click | empty body | **Tcl** | the strip context menu (item 8) |
| Shift+LMB, Alt+LMB | anywhere | — | swallowed by `strip_bindings` (issue 0149) |
| **`Delete`** (the one KEY row) | over a graph | **Tcl** | deletes the selection — the marker, the traces, or both (§16, issue 0176). Never forwarded to C |

Six rules that are easy to get wrong and are asserted:

1. **Only the plot BODY clears.** A click that hits neither picking surface
   changes nothing, which is why the C arm carries `on_body` separately from
   "the pick answered -1".
2. **A plain click COLLAPSES the selection** to the one trace clicked, across the
   whole window. A plain click never deselects what it lands on (0174 D3).
3. **Ctrl+click never sweeps the other strips.** That is precisely how a
   selection spanning two strips is built.
4. **RMB means CONTEXT MENU everywhere on this canvas** (issue 0178). The legend
   used to be the one exception: its press fell through to the C engine, whose
   Button3-outside-the-plot-box arm toggles the trace's membership — a second
   button for Ctrl+LMB, and the thing the 0177 eyeball reported. A trace has two
   picking surfaces and every other gesture already honours both, so the trace
   menu's gate now accepts a legend entry and `wviewer::btn3_filter` swallows the
   unmodified press so the engine never sees it. **Selection on the legend is
   LMB's and Ctrl+LMB's alone.** The C arm is untouched, so graphs embedded in a
   SCHEMATIC — which have no context menus — keep the toggle.
   A single-trace strip posts no menu (the `>= 2 traces` rung, shared with the
   body) and no longer toggles either: RMB is simply inert there, as it already
   is on the axis margins.
5. **Every row above is computed from RAW pixels, and nothing on this canvas is
   grid-quantised** (issue 0177). The viewer window's context carries `no_snap`,
   so `callback()` computes `mousex_snap`/`mousey_snap` as honest copies of
   `mousex`/`mousey` *at the source* — the guarantee is structural, not a local
   overwrite inside `waves_callback` that each new code path has to repeat (which
   is what issue 0143 gave, and what let the snap grid reach the top of the
   legend band; see landmine 44). The same property suppresses the two schematic
   pointer glyphs, `draw_crosshair` and `draw_snap_cursor` — neither is a viewer
   concept and the first paints *at* the snapped coordinate.

6. **The double-click SETS the marker selection; it never toggles.** The first
   click of it still does its ordinary single-select and the second **widens**
   that to the pair — so double-clicking an already-selected difference marker
   (whose first click *deselected* it, per `graph_markers.md` §6.2) still ends
   with the pair selected, and a repeat double-click leaves it there. The
   companion rule on the single click: with a **pair** selected, a plain click on
   a member **collapses** to that one member (rule 2's trace behaviour); the
   shipped "click the already-selected one to deselect" survives only for a
   selection of exactly one. Issue 0189.

7. **A cursor grab and the reorder GRIP both still win in the margins, and the
   viewer learns that by asking C, not by hit-testing** (issue 0190, §17). An
   axis margin is not free real estate: an x-cursor's line is drawn `ry1..ry2`
   and its numeric readout at `ry2-1` — *in* the bottom margin — and an
   hcursor's line spans `rx1+10..rx2-10` with its readout at `rx1+5`, *in* the
   left margin; the grip owns its right 14 px at every height; and for
   `vlegend=1` and for digital strips the LEGEND *is* the left margin. So the
   axis drag arms LAST, only when the same press grabbed no cursor, and
   `graph_axis_at()` itself declines the grip column and any pixel
   `graph_legend_at()` claims. `wviewer::strip_drag_press` adds exactly one rung
   for all of that — `if {[wviewer::axis_grabbed $W]} { return 1 }` — because C
   has already decided by the time it runs (§17.5).

### 15.7 What a HOVER draws, by region (issue 0177)

No row of this table says "the schematic crosshair", and that is the contract.

| region | routed to | drawn under the pointer on a plain hover |
|---|---|---|
| plot body | graph | the item-9 diamond, on the nearest sample of the nearest trace |
| legend band | graph | **nothing** (the diamond gates on the plot box) |
| left / bottom axis margin | graph | **nothing** |
| the strip reorder grip | graph | **nothing** — the three grip bars are static, not hover feedback |
| the rect-edge inset (5 screen px) and outside every rect | schematic canvas | **nothing**; `draw_hover` may outline the rect |

The last row is the margin that keeps a graph rect grabbable at all. It is
`5 * tk_scaling` **screen** pixels — before 0177 the conversion was missing and
it was that many XSCHEM units, i.e. `1/zoom` times wider (measured 22 canvas px
on a 1000x776 viewer), which swallowed the top of every legend entry.

**`m` and `d` create exactly where the diamond appears** (issue 0188). One
region rule for the glyph and for the key: `graph_marker_create()` now asks the
same `graph_plotbox_at()` this table's first row asks and then picks with the
same `graph_point_at(..., 1e30, -1, -1, ...)`, so a marker cannot land anywhere
the diamond is not already sitting. Read the table's three **nothing** rows as
"and `m` refuses here" — until 0188 they were not: creation gated on a 20-px
distance to a trace, which both refused inside an empty plot box and *accepted*
in the axis margin next to a trace's endpoint (measured: `xschem graph_marker
add 0 145 480`, 6 px outside the box, created one). See
`doc/claude/specs/graph_markers.md` D12 and §6.3.

### 15.2 Storage — two tokens, one writer

```
hilight_wave=0            the FIRST selected NODE index, or -1. Grammar unchanged.
sel_waves="0 2"           the WHOLE set, ascending, no duplicates.
                          Emitted ONLY when two or more traces are selected.
```

`hilight_wave` is always the head of the set. `graph_sel_waves_get/set/toggle`
(`draw.c`) are the only readers/writers of the pair on the C side and
`wviewer::model_sel` / `model_sel_set` are its model-side mirror, so the two
tokens cannot drift.

A 0- or 1-trace selection emits **no** `sel_waves` at all, so a strip that was
never Ctrl-clicked serialises byte-identically to pre-0175 and an older build
reads it exactly as before. An older build reading a two-trace selection bolds
the first one and ignores the unknown token. No `XSCHEM_FILE_VERSION` bump — an
additive optional rect token, like `active` / `markers` / `legendbold`. The full
compatibility statement is in
`doc/claude/issues/0175-trace-legend-click-and-multiselect.md` D1.

In memory the set lives in `Graph_ctx.sel_wave[GRAPH_MAX_SEL_WAVES]` +
`n_sel_waves` — a FIXED array, because six call sites build a local `Graph_ctx`
and let it die on return.

### 15.3 The legend is a picking surface

`graph_legend_at(i, px, py)` → NODE index or -1, exposed as
`xschem get graph_legend_at` and wrapped by `wviewer::legend_at`. Raw screen
pixels, LOCAL `Graph_ctx`, hcursor bits bracketed, fails closed. All three legend
layouts. It does **not** refuse digital strips: their body answers -1 everywhere,
so the legend is the only way to select a trace there.

The legend and the plot body are **disjoint** surfaces of one strip — neither
answers where the other does — and they no longer live in different coordinate
spaces at the call site (see landmine 43 for what they used to do). Neither is
snapped either: the viewer's context sets `no_snap`, so `mousex_snap`/`mousey_snap`
are raw copies of `mousex`/`mousey` everywhere in that window, not only inside
`waves_callback` (issue 0177, landmine 44).

### 15.4 Drawing

Every selected trace gets exactly the cue one selected trace has always had: a
thick stroke, and a bold legend entry (bold **italic** where `legendbold` is on,
viewer plan item 1). There is no separate cue for the head of the set.

Implementation rule: **every draw-side "is this trace selected" test goes through
`wave_is_hilighted(gr, wcnt)`.** A surviving bare `gr->hilight_wave == wcnt`
renders a Ctrl-selected trace thin while the token says it is selected, and no
leg that selects one trace can see it — `test_wave_legend.tcl` `LS5` asserts it
at source level.

### 15.5 Lifetime

Captured by `capture_live_graph_state`, emitted by `graph_props`, carried by
`wviewer::snapshot`/`restore` and by the viewer undo stack. `sel_waves` follows
`hilight_wave` exactly, including the absent-means-absent rule.

The capture is **required**, not optional: `regenerate` rebuilds every rect from
the model and runs from ~18 sites including a plain window RESIZE, so without it
a multi-select would silently collapse to one trace on the next resize.

Structural edits remap the set rather than dropping it — a stale node index bolds
the WRONG trace, which is worse than losing the selection. A trace moved to
another strip takes its selected-ness with it and is **added** to whatever the
destination already had selected.

### 15.6 Tests

`tests/headless/test_wave_trace_menu.tcl` `TL*` (the query: slots, the slot
BOUNDARY, the refusals, the raw-pixels contract) and `TS*` (the set: add, remove,
collapse, window-wide, the legend, the NODE index space, survival across a
regenerate). `tests/headless/test_wave_legend.tcl` `LS*` (the pure set algebra,
the token emission, the blast radius, the source-level D4 leg).
`tests/headless/test_wave_viewer.tcl` `WB-legend` (legend LMB selects).

---

## 16. `Delete` deletes the SELECTION (2026-07-30, issue 0176)

`doc/claude/issues/0176-del-deletes-selection.md`. One rule, keyed on **what
kind of thing is selected** — not a priority ladder between two owners:

> Delete should delete whatever is selected. If that is a marker, delete it. If
> it is a trace, delete the trace and its associated markers.

### 16.1 The rule

| what is selected | what `Delete` does |
|---|---|
| a MARKER (and the pointer is over the strip that owns **the head**) | the **whole marker selection** — with issue 0189 that can be a difference marker *and* its reference, on two different strips. The scope gate stays on the HEAD (`graph_markers.md` D9): when the head is in scope the whole set goes. `delete_items` already dedupes, filters to live numbers and gives ONE undo point and ONE log line, so the viewer half was a one-line change |
| one or more TRACES (§15's selection, window-wide) | those traces, **and every marker on them** |
| both | both, as ONE gesture (D1 — flagged at review) |
| nothing | **nothing**, and in particular nothing reaches the C engine |

The cascade is not new behaviour bolted on: it is the documented semantics of
`remap_markers_after_trace_delete`, which the Delete dialog has always used.

### 16.2 The one mutation

```tcl
wviewer::delete_items {graphs pairs ?markers? ?token?}   ;# -> count | 0 | {}
```

`graphs` = whole strip indices (the dialog's; **DEL always passes `{}`**, D4),
`pairs` = `{gi ti}` **MODEL** index pairs, `markers` = marker NUMBERS.

Same ordering contract as `move_strip` (§12.2/§12.3), for the same reasons:
validate LOUDLY → a no-op returns without mutating **and without logging** →
verified `switch_ctx` → **`capture_live_graph_state` first** → `push_undo` → the
pure `delete_in_graphs` → the window-wide `markers_sweep_numbers` → the target
remapped *in place* → exactly one `regenerate` → exactly one log line:

```tcl
wviewer::delete_items {} {{0 1} {0 2}} {3} <token>
```

The capture is what puts the live markers *and* the mouse-written pan/zoom inside
the restore point, so **one `u` brings the traces and their markers back
together**.

**One undo point and one log line per GESTURE**, not per trace (D5). Three
selected traces are a single `u`.

**The pairs in the log line are the normalised ones** — deduped, with pairs
inside a doomed strip dropped — and they are stable against the deletions the
line itself performs: `delete_in_graphs` walks the ORIGINAL list with its own
`gi` counter and removes traces highest-index-first, so every index is in the
pre-mutation space (D6). A replay has **no selection state at all** (§15, 0175
D8), which is why the line can never say "the selection".

### 16.3 The marker arm is a MODEL edit, and the scope test moved to Tcl

`key_filter` no longer forwards `Delete` to C on any path. Two consequences,
both deliberate:

- The marker deletion goes through `markers_drop_number` — the primitive every
  other Tcl deletion path in `wave_viewer.tcl` already uses, and the one that
  zeroes dangling `prev` links window-wide. So the marker's number simply joins
  the `gone` list and rides the same sweep the cascade already needed. 0176 D8
  lists the four measured reasons the C verb is wrong here (readonly rejection, a
  self-logged line that aborts a replay, a C undo push on a scratch buffer, and
  the `has_x`-gated notify hook).
- C's strip-scope test (`graph_marker_find(sel) == graph_master`) is
  **reproduced**, not loosened: `wviewer::marker_graph_at` vs
  `wviewer::strip_at_pixel` of the KeyPress coordinates (D9).

Because nothing is forwarded, C's `case XK_Delete` fall-through —
`readonly_block()` and a modal dialog over a read-only viewer — is unreachable
from this window. It **was** reachable before 0176.

### 16.4 What Delete deliberately does not do

- It does **not** delete a strip that loses its last trace (D3). Tidying the
  stack is bare `e`, and it is the user's gesture to make.
- It does **not** delete whole strips (D4). That is the Delete dialog's job.
- It does **not** fire off a graph: `over_graph` is required, as it always was
  for the marker arm (D7).

### 16.5 Tests

`tests/headless/test_wave_modes.tcl` `DT*` — the PURE half (`delete_in_graphs`):
the cascade, the survivor remap, the `gone` numbers, the selection set, and the
vec-less-trace index space (landmine 34). **Both arms.**

`tests/headless/test_wave_markers.tcl` `MQ*` — the command layer: routing both
ways and both together, the live cascade + window-wide sweep, undo/redo, the log
line, the replay, the two refusals (each with an execution trace on `xschem`
proving zero `callback` calls), and one real `Delete` keystroke. **DISPLAY
only** — `delete_items` ends in a `regenerate`, i.e. `winfo`, so the command
layer cannot run under `--nogui` whatever the fixture does. A leg written into
the nogui arm would assert the pre-mutation state and pass for the wrong reason.

`tests/headless/test_wave_viewer.tcl` `G14b` — the Delete dialog, which gained
undo, redo, a replayable log line, a target remap and a no-op discipline as a
consequence of the extraction.

---

## 17. Axis-region drag zoom (2026-08-01, issue 0190)

An LMB press-and-drag in a strip's **axis-number margin** zooms that axis, and
only that axis. It lives in the **C engine**, beside the Button3 box zoom it is
the twin of — so schematic-embedded graphs get it too — and the ASE viewer needs
exactly one rung, carrying no geometry.

> **See also §18**, the WHEEL twin of this gesture (issue 0191): CTRL+wheel in
> the same two margins zooms the same axis about the pointer. It reuses
> `graph_axis_at()` and `graph_axis_zoom()` verbatim and shares the axis-window
> resolution with this section's map through `graph_axis_window()`.

### 17.1 The gesture

| | |
|---|---|
| Where LMB grabs | the **bottom margin** (where the X tick numbers are drawn) for X; the **left margin** (the Y tick numbers) for Y |
| Refusals | the plot box, everything outside the container rect, the reorder **grip** column (right 14 px, every height), and any pixel `graph_legend_at()` claims — for `vlegend=1` and for digital strips the legend *is* the left margin |
| Corner rule | the bottom-**left** corner answers **Y**, matching the shipped RMB left-margin arm, which tests `graph_left` first and never consults `graph_bottom` |
| Cursor exclusion | a press that grabbed an x/y cursor keeps the whole drag (§12.1/§13.1); the axis drag arms LAST and only when `!(graph_flags & (16\|32\|512\|1024))` |
| Marker exclusion | a marker press pre-empts the whole block already (`mkpress`), so no code change was needed for it |
| Movement threshold | more than **3 screen pixels** of travel *on the dragged axis's own component*, `GRAPH_CLICK_TOL`. ⚠ Handed to `graph_axis_map()` in **raw screen pixels** — the older uses of that constant in `callback.c` are `× xctx->zoom` (WORLD units) because their operands are world coordinates; `p0`/`p1` here are canvas pixels. The value has ONE home: the `#define` stays file-private to `callback.c` and the `xschem get graph_axis_map` getter reads it through `graph_click_tol()` rather than repeating the literal |
| Feedback | a live rubber **band** spanning the plot box across the other axis — `drawtemprect` with `gctiled`/`gc[SELLAYER]` and `graph_rubber_*`, exactly like the Button3 rubber. **Not** a prop token and **not** `draw_graph` bit 16 |
| Release outside the box | **clamped** to the plot extent and committed, never silently cancelled |
| Commit | LMB release |
| Cancel | **Escape** (`abort_operation()` → `graph_axis_drag_abort()`, and its trailing `draw()` repaints over the band) |
| No-ops | a click below the threshold: no write, no log |

### 17.2 The two maths

Let the current window on that axis be `[A, B]`, `R = B - A`, and let `u(p)` be
a canvas pixel normalised into it — `u(p) = (G_axis(p) - A) / R`. With
`ua = u(press)`, `ub = u(release)` and `s = ub - ua`:

* **`s > 0` — forward drag (X left→right, Y upward) — ZOOM IN**

  ```
  lo = A + ua*R      hi = A + ub*R
  ```

  i.e. exactly the two data coordinates the press and the release land on.

* **`s < 0` — reverse drag — ZOOM OUT**, anchored:

  ```
  R2 = R / |s|       lo = A - ub*R2      hi = lo + R2
  ```

  i.e. the current window ends up occupying the screen span between the release
  and the press.

**Both endpoints are the specification.** The `- ub*R2` term is the ANCHOR;
drop it and the new range still has the right WIDTH, so every "the range grew"
assertion passes while the window has slid sideways. Two worked checks, which
are also two legs of the suite:

* a **full-extent reverse drag leaves the window unchanged**: `ua = 1`, `ub = 0`,
  `s = -1`, `R2 = R`, `lo = A - 0 = A`, `hi = B`. Note this is precisely the case
  the anchor term vanishes in — which is why it cannot be the only reverse leg;
* a **half-extent reverse drag from the far edge** gives `R2 = 2R`, `lo = A - R`,
  `hi = A + R`.

`|s|` is clamped below at `1/GRAPH_AXIS_ZOOM_MAX_FACTOR` (1000.0, `xschem.h`) so
a degenerate drag can never put an `inf` into `x1`/`x2`, where it would be
permanent; the 3-px threshold normally binds first, so the clamp is a backstop.
`hi == lo ⇒ hi += 1e-6`, the shipped idiom.

**Log axes need nothing special.** `gr->gx1..gy2` and `G_X`/`G_Y` are *already*
in log space when `logx`/`logy` is set — the shipped box zoom writes
`dtoa(G_X(...))` straight into `x1`/`x2` with no `pow(10,·)` — so the map is
uniform in log space for free. Applying a conversion here would double-convert
(landmine 35, arriving from the other side).

### 17.3 Where it applies: X propagates, Y does not

X writes `x1`/`x2` on the dragged rect **and on every PARTICIPATING rect**,
reproducing the shipped predicate of the MMB pan / RMB box zoom / arrow pans
verbatim:

```c
rk->sel || (same_sim_type && !(rk->flags & 2)) || k == i
```

where `same_sim_type` additionally requires the MASTER not to be `unlocked` and
the two `sim_type` tokens to match. **It is NOT the viewer's `sharedx` flag** —
the C engine cannot see that, and `wviewer::graph_props` never emits `unlocked`,
so in the viewer X follows every strip of the same `sim_type` whatever `sharedx`
is set to, exactly as the pan and the box zoom already do. `sharedx` only affects
`regenerate`.

Y is per-graph and touches its own rect only. A **digital** strip's Y is the
`ypos1`/`ypos2` band, not `y1`/`y2` — mirroring the RMB left-margin arm. The
`digital` flag is read straight off the rect with `get_tok_value`, never through
a scratch `Graph_ctx`: `setup_graph_data()` parses it *below* its off-screen
early return (landmine 37a), so an off-screen digital strip would otherwise get
`y1`/`y2` written into it.

> ⚠ **CORRECTED 2026-08-01 (issue 0191).** The paragraph above described only the
> **apply**. Decision D-19 also said the MAP computes a digital strip's Y
> "through `DG_Y`" — and it did not: `graph_axis_map()` resolved the Y window
> from `gy1`/`gy2` and `S_Y` unconditionally, so on a digital strip it answered
> in the **analog** window while `graph_axis_zoom()` wrote the result into a band
> with a different extent. MEASURED at `826e1b60`, `y1=0 y2=2.5 ypos1=0 ypos2=4`:
> `xschem get graph_axis_map 0 y 636 310` → `0 1.6437`. A full-height left-margin
> drag on a digital strip therefore mis-zoomed it by ~2.6×, anchored in the wrong
> place. Item 04 (§18) needed the identical resolution for its own formula, so it
> is now a single shared helper — `graph_axis_window()` in `draw.c`, called by
> **both** maps, with the digital branch written correctly (`ypos1`/`ypos2` and
> `DS_Y`, inverted by `DG_Y`). §18's `CD2` leg is the first assertion that makes
> D-19 true.

### 17.4 No dirty flag, no C undo, no viewer undo — and one log line

A zoom is **view state**. `graph_axis_zoom()` calls neither `set_modify()` nor
`push_undo()`, exactly like every other graph gesture (landmine 19) — which is
also what lets the read-only ASE viewer perform it with **no `with_edit`
bracket** and what lets the verb apply under `xschem set readonly 1`
(landmine 17 already lists the box zoom as view state the engine may put in a
read-only rect). It pushes no `wviewer::push_undo` snapshot either: window view
state is deliberately outside a snapshot (§14.1), and `wheel_zoom` /
`zoom_about` push nothing.

It does **not** call `capture_live_graph_state`. A C-side gesture reaches no
`regenerate`; that helper is what a *later* Tcl model mutation runs to fold
C-written ranges back out of the rects, and this gesture is one more producer for
it. The consequence, which is shipped behaviour for the whole class: a plain
window **resize** (`regenerate` from `on_configure`) discards an axis zoom the
model never saw, exactly as it discards an MMB pan or an RMB box zoom.

It logs exactly **one** line per commit, in the VERB form, from the primitive:

```
xschem graph_axis_zoom <graph_idx> x|y <lo> <hi>
```

`%.17g`, **never pixels** (they do not exist at replay time), and the verb rather
than a `setprop` so one line replays the whole propagation.

### 17.5 Surface

Three C functions, and the split is the point (`src/draw.c`):

| function | question |
|---|---|
| `graph_axis_at(i, px, py)` | which margin is this canvas pixel in? `GRAPH_AXIS_NONE\|_X\|_Y` |
| `graph_axis_map(i, axis, p0, p1, &lo, &hi, clicktol)` | **THE formula**, in exactly one place |
| `graph_axis_zoom(i, axis, lo, hi)` | **THE apply**, shared by the gesture and by the verb |

`graph_axis_at()` deliberately does **not** copy `graph_plotbox_at()`'s
loaded-raw requirement or its digital refusal: it is pure geometry, and zooming
the axis of an empty or digital strip is meaningful. It fails closed on a bad
index, a non-graph rect and an off-screen graph, uses a LOCAL `Graph_ctx` and
brackets `graph_flags`' hcursor bits (landmines 11 and 37).

Tcl:

```
xschem get graph_axis_at   <gi> <px> <py>       -> "" | x | y      (fail soft)
xschem get graph_axis_map  <gi> x|y <p0> <p1>   -> {lo hi} | {}    (fail soft)
xschem get graph_axis_drag                      -> "" | x | y      (fail soft)
xschem graph_axis_zoom     <gi> x|y <lo> <hi>   -> 1 | 0           (fails LOUD on usage)
```

`graph_axis_map` is exposed **so the suite can drive the formula headlessly and
assert both endpoints** — the gesture and the verb share the one function, and a
source-level leg asserts the anchored expression appears exactly once
(landmine 45(a)).

**The viewer carries no geometry.** `wviewer::axis_grabbed` is the
`marker_grabbed` twin — switch ctx, `catch {xschem get graph_axis_drag}`, fail
closed — and `strip_drag_press` gains exactly one rung, immediately after the
marker rung and inside the handle test so the grip keeps unconditional first
refusal:

```tcl
  if {[wviewer::axis_grabbed $W]} { return 1 }
```

The press was already forwarded to C at that point, so C has already decided.
Nothing else changes: `<B1-Motion>` forwards when `strip_drag_motion` returns 0,
`strip_drag_release` forwards the release unconditionally, and `key_filter`'s
Escape arm already forwards ESC after cancelling its own drag.

### 17.6 Tests

`tests/headless/test_wave_axis_zoom.tcl`, auto-discovered by `full_audit.sh`.
`AZ*` the region query, `AM*` the map (every expectation computed in Tcl from
the closed form, with `xschem graph_coord` as an independent pixel→data
transform), `AV*` the apply — **witnessing every rect**, `AL*` the log line and
its replay in a `--logdir` child process, `AS*` the source-level
one-formula-one-home tripwire; `AG*` the real C gesture and `AX*` the ASE viewer
seam under DISPLAY. **200 checks in the `--nogui` arm, 338 with a display**
(2026-08-01, after §18's five groups were added to the same file and then
extended by its repair pass; the count before §18 was 128 / 196, and the
"119 / 173" this line used to carry was stale from the first draft).

---

## 18. Axis-region CTRL+wheel zoom (2026-08-01, issue 0191)

**CTRL+wheel** in a strip's **axis-number margin** — the same two regions §17
gave to the LMB drag — zooms **that axis only**, about the pointer: the data
coordinate under the pointer keeps its screen pixel.

The user's ask, verbatim:

> In the axis regions - where the LMB press-and-drag for zoom is supported,
> CTRL+Scroll_wheel will support zoom in/out for THAT AXIS ONLY. Zooming will be
> around the mouse pointer. That is, the point(s) on the trace(s) that are at x1
> (position of the mouse pointer) will remain there after zoom.

It lives on **both** surfaces with **one formula in C**: a new arm in
`waves_callback()` serves schematic-embedded graphs, and the ASE viewer — which
binds every wheel sequence with a `break` and never forwards — consumes the same
formula as a query and writes its own Tcl model. Decision doc:
`doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md`
(D-25…D-40).

### 18.1 The gesture

| | |
|---|---|
| Where | the **bottom margin** (X tick numbers) → X; the **left margin** (Y tick numbers) → Y. `graph_axis_at()`, unchanged and unwidened — §17.1's table of refusals applies verbatim, including the bottom-left corner answering Y |
| Modifier | **Ctrl**, and `!(state & ShiftMask)`: Ctrl+Shift+wheel keeps the shipped Shift zoom |
| Direction | wheel **up** = zoom IN (multiply the range by `K`), wheel **down** = zoom OUT (divide by `K`) |
| Step | `GRAPH_AXIS_WHEEL_FACTOR = 0.8` (`src/xschem.h`), **mirrored in Tcl** as `wviewer::wheel_zoom`'s `f` literal, both carrying a change-both comment |
| `graph_use_ctrl_key` | **the arm is gated OFF** in that mode (D-32). There Ctrl is the graph *access* modifier — `waves_selected` refuses every graph event without it — so taking Ctrl+wheel would leave the mode with no graph wheel pan at all. Default is `0`, so the feature is on out of the box |
| Cursors / markers | irrelevant: those are *drag* grabs armed by a Button1 press, and a wheel during an in-flight drag is already short-circuited by `if(ui_state & GRAPHPAN) goto finish` |
| GRAPHPAN latch | **no term owed**. The latch admits `Button1 \|\| Button2 \|\| Button3` only, so a Button4/5 press never enters it, and a wheel is one event with no release to lose |
| Off-screen / empty / no raw | allowed for empty and no-raw (pure geometry, §17's D-20); an **off-screen** strip is refused by the shipped `gr->scx == 0.0 \|\| gr->scy == 0.0` sentinel and the verb answers `{}` |
| Dirty flag / undo | none, on either path (§18.4) |

**What every other chord keeps doing — MEASURED**, not read off a comment. Three
comments in the tree said Ctrl+wheel over a graph was a canvas pan or a canvas
zoom; it is neither, and `xorigin`/`yorigin`/`zoom` did not move in any of the
twelve trials:

| chord | plot BODY | bottom (X) margin | left (Y) margin |
|---|---|---|---|
| plain wheel | graph X **pan** ±0.05·gw | graph X **pan** | graph Y **pan** ±gh/divy |
| Shift+wheel | graph X **zoom**, anchored, ×0.8 in / **×1.2** out | same | graph Y **zoom**, anchored |
| **Ctrl+wheel, before 0191** | graph X pan — byte-identical to the plain wheel | graph X pan | graph Y pan |
| **Ctrl+wheel, after 0191** | **unchanged** (still the X pan) | **X zoom, anchored** | **Y zoom, anchored** |

"Unchanged in the body" therefore means *"still panning the graph"*, not *"still
panning the canvas"*. That distinction is what the `wheel_axis_done` flag exists
for: the plain-wheel arms stand down **only** when the axis zoom actually fired,
which happens only when `graph_axis_at()` found a margin AND the map answered.

### 18.2 The maths, and the fixed-point invariant

With `[A, B]` the axis's current window, `R = B - A`, `e1`/`e2` the plot box's
pixel extent along that axis, `p` the pointer's canvas pixel **clamped to
`[e1, e2]`**, and `K = GRAPH_AXIS_WHEEL_FACTOR`:

```
  f  = wheel-up ? K : 1/K          the range MULTIPLIER
  q  = G_axis(p)                   the data coordinate under the pointer
  u  = (q - A) / R                 0..1
  R2 = R * f
  lo = q - u * R2                  <-- THE ANCHOR TERM
  hi = lo + R2
  if(hi == lo) hi += 1e-6          the shipped idiom
```

**The invariant, and the only assertion that matters:**
`(q - lo) / (hi - lo) == u`. Substituting: `(q - (q - u·R2))/R2 = u`. ∎ So `q`
sits at the same fraction of the window and therefore at the same screen pixel.

**Why `lo = q - u·R2` and not `lo = A + (R - R2)/2`.** The second form has the
right WIDTH and the wrong POSITION. It passes "the range shrank by K", it passes
"both endpoints moved", and it fails only a test that measures where `q` ended
up. Measured under SAB-1: the centre form left the width leg (`CW2`) green and
killed nine fixed-point / closed-form legs. **A probe pixel at the box CENTRE
cannot tell the two apart** — at `u = 0.5` they agree — which is why every leg in
the suite probes at 25 % of the extent.

Two worked checks, which are also two legs:

* **round trip.** `in` then `out` at the same pixel: `R → R·K → R·K·(1/K) = R`,
  and `lo` returns to `A` because `u` is unchanged (the anchor is a fixed point
  of both steps). The shipped Shift+wheel arms are ×0.8 / ×1.2 and lose 4 % of
  the range per round trip; this one is exact to the token format.
* **pointer at an edge.** `p = e1 ⇒ u = 0 ⇒ lo = q = A`: the window pins that
  edge and only the other one moves.

**Log axes:** nothing special. `gr->gx1..gy2` and `G_X`/`G_Y` are *already* in
log space when `logx`/`logy` is set; applying a `pow(10, ·)` here would
double-convert (landmine 35 from the other side, §17's D-18 verbatim).

**No `GRAPH_AXIS_ZOOM_MAX_FACTOR`** (D-34). That constant guards the *drag*
map's `R / |s|`, a division by a user-controlled span that can approach zero and
put an `inf` into `x1`/`x2` permanently. `R * f` divides nothing: repeated clicks
shrink `R` geometrically and cannot reach zero in finite steps, and `hi == lo`
catches the denormal end.

**The axis WINDOW has one home.** `graph_axis_window(gr, axis, &A, &B, &e1, &e2)`
(static, `draw.c`) answers *"what is this axis's window and what pixel extent
does it occupy"* for **both** maps, normalising both pairs low-first (`gr->cy` is
negative — landmine 3). Its digital branch is what makes §17.3's D-19 true; see
the correction box there.

### 18.3 Where it applies: X propagates, Y does not

Identical to §17.3, because it is the same apply — `graph_axis_zoom()`,
unchanged. X writes `x1`/`x2` on the pointed rect **and every PARTICIPATING
rect**; Y writes `y1`/`y2` — or `ypos1`/`ypos2` on a digital strip — on the
pointed rect only.

On the **viewer** path the loop is `wviewer::wheel_zoom`'s own: X on every strip,
Y on `gi`. Each strip's new window is asked of C **per strip** (D-33), so each is
anchored in its own window at the same pointer pixel — the same answer when the
windows agree and the right answer when they do not. A strip the verb answers
`{}` for is left **completely unchanged**; it never falls back to `zoom_about`,
which would be a second formula answering for one gesture.

### 18.4 No dirty flag, no C undo, no viewer undo — and one log line

All four decided as §17.4 decided them (D-35 = D-14/D-15/D-16 verbatim):

* no `set_modify()` and no `push_undo()` — a zoom is view state, the whole of
  `waves_callback` contains zero of either (landmine 19), and the ASE viewer's
  buffer is read-only for life so a dirty flag there would be a lie;
* no `wviewer::push_undo`, no `capture_live_graph_state`, no `with_edit` — window
  view state is deliberately outside a viewer undo snapshot (§14.1), and a single
  `u` after a zoom would otherwise revert an unrelated model edit.

**Logging is asymmetric, on purpose (D-37).** The **C engine** path logs exactly
one `xschem graph_axis_zoom <gi> x|y <lo> <hi>` line at `%.17g` — for free,
because it applies through `graph_axis_zoom()` — and replaying that one line
reproduces the whole propagation. The **viewer** path logs **nothing**, exactly
like `wviewer::wheel_zoom`, `pan_x` and `graph_zoom` today: the viewer's
`log_action` seam is for MODEL mutations (`move_strip`, `move_trace`,
`set_target_strip`, `clear_all`), ranges are not in that class, and adding a line
to one arm of one modifier would make a replayed session inconsistent with
itself.

**The viewer path SURVIVES a `regenerate`** — a deliberate difference from §17
(D-36). There is Tcl in this gesture's loop (the viewer owns the wheel bind), so
writing the model costs nothing and avoids two Ctrl+wheel gestures with different
lifetimes three lines apart.

### 18.5 Surface

| what | where |
|---|---|
| `GRAPH_AXIS_WHEEL_FACTOR 0.8` | `src/xschem.h`, next to `GRAPH_AXIS_ZOOM_MAX_FACTOR`. **MIRRORED IN TCL** |
| `graph_axis_window()` (static, NEW) | `src/draw.c`, above `graph_axis_map()`. The one home for the axis window + its pixel extent; called by both maps |
| `graph_axis_wheel_map(i, axis, p, dir, &lo, &hi)` (NEW) | `src/draw.c`, after `graph_axis_map()`. THE wheel formula; `dir` is `+1` in / `-1` out and the factor lives **inside**, so the constant has one home and a suite driving the verb drives the product's own step |
| the engine arm | `src/callback.c`, a new `else if` after the Button3 numeric-cursor arm in `waves_callback`'s master block, plus the `wheel_axis_done` local and `&& !wheel_axis_done` on the two plain-wheel arms |
| `xschem get graph_axis_wheel_map <gi> x\|y <p> in\|out` | `src/scheduler.c`, `xschem_cmds_g`'s `get` `case 'g':`, beside `graph_axis_map`. Fails **soft** (`{}` + `TCL_OK`) |
| `xschem graph_axis_zoom` | **unchanged**, and it is THE apply for both maps |
| `wviewer::axis_wheel_window {token gi axis p dir}` (NEW) | `src/wave_viewer.tcl`. Asks C, fails closed to `{}`. The viewer computes no geometry (§17's D-22, not reopened) |
| `wviewer::wheel_zoom`'s new trailing `{axis {}}` | `{}` = today's body zoom byte for byte; `x`/`y` = the single-axis arms. Every pre-0191 caller passes nothing |
| `wviewer::wheel`'s `ctrl` arm | one new rung: ask `xschem get graph_axis_at` with the **event's own** `%x`/`%y` and pass the answer down |
| binds | **none added**. `<Control-Button-4/5>` and `<Control-MouseWheel>` were already bound |

**Why the arm is in `waves_callback` and not the binding table** — landmine 48.
`handle_button_press()` opens with an inline
`if(waves_selected(...)) { waves_callback(...); return; }` and
`handle_mouse_wheel()` is reached fourteen branches later, so for **any** wheel
press over a graph the function has already returned. The four
`ACTX_OVER_GRAPH` wheel rows in `init_input_bindings` are unreachable dead code;
they are kept (removing them has its own `xschem bind` / `keybindings.csv`
regression surface) but their comment is corrected.

### 18.6 Tests

Five new groups in `tests/headless/test_wave_axis_zoom.tcl` (128 → **200**
`--nogui`, 196 → **338** with a display):

* **`CW*`** — the map and its verb, BOTH arms. Fail-soft on six bad queries; both
  endpoints against the closed form; the WIDTH leg kept **separate** from the
  FIXED-POINT leg so SAB-1 can kill one and not the other; the round trip; the
  other axis byte-identical on **every** rect; propagation; edge pinning; the
  out-of-extent clamp.
  `CW10`/`CW11` are the **log-axis** legs (PLAN Q6): `logx=1` / `logy=1` staged
  at `-3..0`, the anchored form re-derived in log space, both bounds asserted to
  stay inside the token range (a `pow(10,·)` on either end leaves it) and the
  fixed point re-measured through `graph_coord`. Log correctness here is by
  *inheritance* — nothing in `graph_axis_wheel_map()` mentions a logarithm — and
  these are the only legs that hold that inheritance to account.
* **`CD*`** — the digital window, BOTH arms, staged **disjoint** (`y 0..2.5`,
  `ypos 10..14`). `CD2` must be a **REVERSE** drag: `graph_axis_map`'s forward
  branch collapses to `lo = q` for any window and literally cannot see which one
  was used — measured, a forward leg stayed green under SAB-4. `CD3`'s oracle is
  an independent Tcl transform (both transforms share the plot box, so the
  fraction `graph_coord` gives is the fraction in `ypos` space); `graph_coord`
  itself is the WRONG oracle here.
* **`CS*`** — source-level one-home tripwires: the anchored expression appears
  once in `draw.c` and nowhere else, the wheel map is called exactly once from
  each of `callback.c`/`scheduler.c`, `graph_axis_window(` appears exactly 3
  times, the digital decision exactly once, neither formula body still contains
  `S_X(`/`S_Y(`/`DS_Y(`, and the C `#define` equals the Tcl literal. `CS3` (with
  the viewer open) asserts `wviewer::zoom_about` and `graph_axis_wheel_map` agree
  numerically — and asserts the proc IS defined, never a silent skip.
* **`CE*`** — the real C gesture on an embedded graph, DISPLAY only, through
  `xschem callback .drw 4 <px> <py> 0 <4|5> 0 4`. Includes the three regression
  witnesses for the MEASURED table above, `graph_use_ctrl_key`, a non-zero strip
  index (the Y half is decisive — Y never propagates), and a `--logdir` GUI child
  that proves the GESTURE self-logged one replayable line.
  `CE12`/`CE13` cover **Ctrl+Shift** (state 5), which is the `!(state &
  ShiftMask)` term's only reason to exist. `CE12` asserts the chord still gives
  the shipped Shift window byte for byte; that is decisive in the **Y** margin
  and *not* in the X margin, where the per-graph loop reloads `gr->gx1/gx2` from
  `master_gx1/master_gx2` and the Shift arm overwrites the suppressed arm's write
  with an identical result. `CE13` is the leg that sees the X margin: it rides in
  `CE9`'s child (the same `--logdir` process — a second GUI child restacks the
  parent canvas under WSLg and flaked the `AX*`/`CV*` pixel scans ~1 run in 8)
  and asserts the two Ctrl+Shift wheels added **no** `graph_axis_zoom` line to
  the log. Measured: 1 line shipped, 3 with the term deleted.
* **`CV*`** — the ASE viewer seam on a live viewer, DISPLAY only, through the
  shipped `<Control-Button-4>` bind with a `<Motion>` first. Single-axis on both
  margins, the body unchanged, survives a `regenerate`, no undo point, and the
  fixed point.
  `CV7` is D-33's decisive leg and needs its own fixture: `CV1`'s two strips are
  staged to the *identical* window, and there a per-strip anchor and "strip 0's
  answer broadcast to every strip" produce the same numbers. `CV7` stages
  `0..1.0` and `0..2.0` (`sharedx` is 0, so `regenerate` leaves them alone),
  compares each strip against **its own** `graph_axis_wheel_map` answer and
  re-measures the fixed point on strip 1. `CV8` is `CE10`'s viewer counterpart:
  the Y margin of **strip 1**, with `wviewer::graph_at_pointer` asserted to
  resolve 1 — `wheel_zoom`'s y branch is gated on `$t == $gi`, and every other
  viewer leg points at strip 0. Its probe pixel is **asked for, not predicted**
  (`cv_yprobe` walks left from the plot box until `graph_axis_at` says `y`, and
  re-scans if it cannot find one): `az_ymargin`'s midpoint is pure geometry and
  `graph_axis_at` has four refusals geometry cannot see, and a `<Configure>`
  delivered by any `update` re-lays the viewer out. With a predicted midpoint the
  leg answered `NONE` on ~1 standalone run in 3, the gesture degraded to the body
  zoom, and **only** the "every strip's x1/x2 unchanged" leg noticed — the Y legs
  pass either way, because the body zoom scales Y by the same `K`.

Eleven named sabotages, each verified to kill its target and be reverted:
SAB-1 (centre anchor) → the fixed-point legs, **not** the width leg;
SAB-2 (zoom both axes in the arm) → the other-axis witnesses;
SAB-3 (fire regardless of region) → the body-unchanged witness;
SAB-4 (delete the digital branch) → `CD*` and `CS4`;
SAB-5 (drift the Tcl literal) → `CS2`, and nothing else in either arm;
SAB-6 (viewer drops the axis argument) → `CV1`/`CV2`'s single-axis legs;
SAB-7 (drop `!wheel_axis_done`) → the X-margin engine legs, `CE1b` first;
SAB-8 (drop `!(state & ShiftMask)` from the arm) → `CE13`'s two log legs,
`CE12`'s Y-margin leg and `CE9`'s two line-count legs — and **not** any X-margin
window leg, which is exactly why `CE13` had to be a log assertion;
SAB-9 (viewer's X arm asks C for `$gi` instead of `$t`) → `CV7`'s two per-strip
legs **only** — `CV1` stays green, which is the fixture coincidence `CV7` exists
to break;
SAB-10 (viewer's Y branch gated on `$t == 0`) → `CV8`'s two legs only;
SAB-11 (`pow(10,·)` the anchor `q` on a log axis) → `CW10`/`CW11`'s six log legs
and nothing else — the width leg inside `CW10` survives, the same asymmetry
SAB-1 exploits.
