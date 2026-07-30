# Waveform-viewer enhancements — atomic step plan

Status: **PROPOSED 2026-07-28.** Branch `fluid-editing`, HEAD `1c375582` plus the
uncommitted marker-callout polish. Next free issue number: **0172**.

Ten user-requested items. Every one below is **grounded** — the file:line anchors,
the shipped precedent to copy and the difficulty verdict come from a six-lane
read-only census of the working tree, not from guessing. Where the census
**contradicted the request's premise**, that is called out in a ⚠ block; read
those first, they are the highest-value part of this document.

Source docs every step depends on:
`doc/claude/code_analysis/waveform_subsystem_reference.md` (§11 = numbered
landmine list), `doc/claude/specs/waveform_viewer.md`,
`waveform_viewer_modes.md`, `graph_markers.md`,
`doc/claude/code_analysis/lessons_census_before_design.md` (method).

---

## Conventions that apply to EVERY item

- **One item at a time.** Each is independently landable, independently
  revertable, and leaves the tree green. Do not batch.
- **RED-first or sabotage-verify** anything behavioural. A green leg proves
  nothing until you have seen it go red ([[green-but-hollow]]).
- **Headless invocation** from the repo root:
  `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<f>.tcl`
  and the same without `--nogui` for the DISPLAY arm.
- **Suites that must stay green after every item**: `test_wave_markers` (641 /
  310), `test_wave_viewer` (349), `test_wave_modes` (384), `test_wave_clear_all`
  (68), `test_ase_plot` (145, occasionally flakes on ngspice).
  `test_wave_markers.tcl` carries **hand-maintained check-count constants**
  (`mk_expect_x` / `mk_expect_nogui`, ~line 3694) — adding legs means running both
  arms and editing them, or `MZ1` fails.
- **Soak the DISPLAY arm 10+ times** before calling a gesture item green; a
  one-in-six WSLg focus flake reads as green on the first run. ~32 s per run.
  Do **not** run `full_audit.sh` (it pops the control panel).
- **Viewer mutation discipline** (landmine 17): the ASE viewer is read-only for
  its whole life. Every mutation goes through `wviewer::with_edit`, which
  **errors** on a refused context switch and so must be `catch`ed inside a Tk
  binding. `switch_ctx` must be **verified**, never assumed.
- **The viewer model mutation contract** (`wviewer::move_strip`, `wave_viewer.tcl`
  ~2046, whose header comment is the written-down rule):
  *validate → refuse-with-no-log on a no-op → `switch_ctx` (verified) →
  `capture_live_graph_state` → `push_undo` → mutate → remap the stored target
  **in place** → ONE `regenerate` → ONE `log_action` line.*
  Getting the order wrong is the shipped bug class: snapshot-after-mutate makes
  `u` restore the thing it was meant to undo.
- **`draw_graph` flags: bit 8 = durable CONTENT, bit 16 = UI CHROME** stripped
  from every export (landmine 18). Transient drag/hover feedback is bit 16.
  Getting this wrong puts a hover glyph into a printed schematic.
- **Landmine 11**: `xctx->graph_struct` is shared. A query builds a stack-local
  `Graph_ctx`. **Landmine 37**: `setup_graph_data()` returns early for an
  off-screen graph *before* parsing units/log/divs, and rewrites `graph_flags`
  bits 128|256 — a query that calls it must bracket-save those two bits and must
  treat `gr->cx == 0` as "no transform".
- **New transient `xctx` fields** must be reset in `graph_marker_drag_clear`-class
  teardown **and** in `clear_drawing()` (`actions.c`) **and**
  `alloc_xschem_data()` (`xinit.c`). The `xctx` allocation is a single
  `my_calloc`, so a 0 default is free; a non-zero sentinel is not.

---

## Decisions the user must make before the dependent item starts

**ALL ANSWERED 2026-07-28** — the user's choice is recorded as a `→ DECIDED:` line
under each. The question text is kept for the rationale.

- [x] **D-A (item 2, item 3): WHICH GRID?** There are two, and they are
      unrelated. The **schematic dot grid** (`drawgrid()`, `draw.c` ~1161, driven
      by `cadgrid`/`draw_grid`) is **already absent from every waveform window** —
      `wave_viewer.tcl` ~438 does `xschem set no_grid 1` for the viewer ctx for
      life. So "the grid" in a waveform window can only be the **graph grid**
      (`draw_graph_grid()`, `draw.c` ~3440: the dashed majors/subdivisions inside
      each strip). Confirm. If the user meant the schematic grid, items 2 and 3
      become trivial-but-invisible.
      **→ DECIDED: the GRAPH grid** (`draw_graph_grid`, `draw.c` ~3440). The
      schematic dot grid stays suppressed in viewer windows.
- [x] **D-B (item 2): what does "reduce pixel density by 50 %" mean?** Three
      concrete readings, and they look different: (i) **halve the line count** —
      `subdivx`/`subdivy` 1 → 0 skips the subdivision loops entirely; (ii)
      **halve the duty cycle** — `dash_size` is hard-coded `1.5 * mooz` quantised
      to {0,2,3}, and `XSetDashes` is called with n=1 so on-run == off-run == 2 px
      (a 50 % duty cycle today); a 1-on/3-off pattern halves the lit pixels;
      (iii) **dim the colour**. Pick one and write it into the spec.
      **→ DECIDED: (ii) halve the DUTY CYCLE.** Keep every grid line and its
      colour; change the dash pattern from the current 2-on/2-off (n=1
      `XSetDashes`) to 1-on/3-off, halving the lit pixels. This needs a C change
      in `draw_graph_grid`/the dash plumbing, NOT a `subdiv` change.
- [x] **D-C (item 5): after deleting every empty strip, may the window end up
      with ZERO strips?** Right after Ctrl-D (Clear All) the model is *exactly one
      empty strip*, so plain `e` would empty the window. Verified: `regenerate`
      handles n == 0 and `graphs {}` is the legal fresh-open state — it is a blank
      window, not a crash. But `clear_all` deliberately maintains a one-strip
      invariant. Choose: delete-all, or keep-one.
      **→ DECIDED: KEEP ONE.** Never delete the last strip; `e` on a
      single-empty-strip window is a no-op that returns without mutating and
      **without logging** (the `from == to` precedent).
- [x] **D-D (item 5): does `e` delete the AUTO-plot strip when it is empty?**
      `empty_graph_indices` already takes an `auto` argument, so both answers are
      one argument apart.
      **→ DECIDED: SPARE the auto strip.** Pass the `auto` argument so the
      auto-plot strip is never a deletion candidate.
- [x] **D-E (item 6): which gesture?** The request says "moving a strip … the
      associated trace". Those are **two different shipped gestures**: the
      **strip drag** (reorder, LMB on empty strip space, hand2 cursor) moves a
      whole strip and has no single "associated trace"; the **trace drag** (LMB
      on a trace, hand2 cursor, moves it to another strip) has exactly one. The
      hand icon is used by both. Best reading is the **trace drag** — confirm.
      **→ DECIDED: the TRACE DRAG** (LMB press on a trace → drop on another
      strip). The strip reorder gets no preview.
- [x] **D-F (item 8): where do the new strips go, and which trace stays?** A split
      has no precedent and the three existing conventions disagree: `add_graph`
      appends at the bottom, multi-plot `plot_signals` front-inserts (newest on
      top), `move_strip` takes an explicit index. Pick one, and pick which trace
      keeps the original strip (node 0 is the natural answer).
      **→ DECIDED: node 0 keeps the original strip; the remaining traces
      1..N-1 get new strips inserted directly BELOW it, in order** (reading order
      preserved). Full split of the strip, not a one-trace peel-off.
- [x] **D-G (item 1): blast radius.** `draw_graph_variables` is shared by every
      graph in the tree, including ~127 shipped schematics with embedded graphs.
      Does the legend enlargement apply everywhere, or only when the new Tcl var
      is set? (Recommend: a var defaulting to a value that changes ASE and leaves
      the default `legendmag` path alone — state the choice.)
      **→ DECIDED: drive the EXISTING per-rect `legendmag` prop token from the
      ASE strip template** (`wave_viewer.tcl` ~1282), value from a new
      rc-overridable Tcl var. **This supersedes the "new C helper" recommendation
      in item 1 below** — see the ⚠ PLAN CORRECTION there.

- [x] **Item 1 "same weight"** — ~~DECIDED: BOTH size and boldness~~
      **→ REVERSED ON REVIEW 2026-07-29.** The original decision was that legend
      text be enlarged to match the axis numbers **and** every entry drawn
      `CAIRO_FONT_WEIGHT_BOLD`, accepting that this erases the issue-0152
      bold-wave cue. That shipped, was eyeballed, and was rejected:
      *"the legend is always bolded. We want same font size as axis, but bolding
      only when the associated trace is selected."*
      **Final: the SIZE change stands; the WEIGHT reverts to issue 0152** (bold
      marks the selected trace). `wviewer_legend_bold` defaults to 0 and the
      all-bold look plus its bold-italic cue survive as an opt-in.
      **Lesson for the remaining items:** a decision about how something LOOKS
      is provisional until it has been looked at. Ship the knob, default it to
      the conservative side, and let the eyeball settle it.

---

## Review ledger

The build loop raises a review panel after each item and **auto-proceeds after
30 minutes** so an item finished at 02:00 does not stall until morning
(`doc/claude/specs/review_gate.md`). Anything that goes through on the timeout
rather than on a human verdict is carried here until it has actually been
looked at. **This list is the debt; do not let it grow silently.**

| item | commit | outcome |
|---|---|---|
| 5 — `e` deletes empty strips | `6ac7219e` | ✅ REVIEWED (PROCEED) |
| 1 — legend size + weight | `b36fa980` | ✅ REVIEWED — **rejected the all-bold half** |
| 1 correction — bold marks the selected trace only | `d40a3934` | ✅ EYEBALLED OK 2026-07-29 |
| 2 — grid density (**touched `drawline`**) | `9dea8c0e` | ✅ EYEBALLED OK 2026-07-29 |
| 3 — Ctrl-G grid toggle | `0d648465` | ✅ EYEBALLED OK 2026-07-29 |
| 9 — diamond snap cursor | `56edb7ec` | ✅ EYEBALLED OK 2026-07-29 — **after two rejected rounds** (trail; proximity gate) |
| 10 — viewer status bar | `ab1dcb47` | ✅ EYEBALLED OK 2026-07-29 |
| 7 — RMB trace context menu | `50c3537f` | ⚠ PROCEED, panel closed with no notes — **pixels not confirmed by eye** |
| 8 — RMB strip context menu (**touched `scheduler.c`**) | `6ca278c6` | ✅ REVIEWED (PROCEED) — pixels still eyeball-only |
| — `wviewer::open` intermittent (found by item 8's soak) | `5ddb8361` | ✅ REVIEWED with item 8 |
| 6 — mid-drag shrink preview (**touched `draw.c`**) | `9727791a` | ✅ REVIEWED — **rejected Y-only and 10 %** |
| 6 round 2 — both axes at 30 % | `780bd468` | ✅ EYEBALLED OK 2026-07-29 — *"It's eyeball done and pass"* |
| 7 follow-up — reuse an empty strip (any, D1/D2) | `8ac4ea0b` | ✅ EYEBALLED OK 2026-07-29 |
| 8 follow-up — reuse the adjacent empty strip (D3/D4) | `1fd61bca` | ⚠ SUPERSEDED — D3 fired almost never; **reported as a defect** |
| 8 follow-up round 2 — RELOCATE the empty strip (D3 v2) | `9b03489a` | ✅ EYEBALLED OK 2026-07-29 — *"Working ok. Eyeball result pass"* |

**ALL TEN ITEMS ARE NOW BUILT AND COMMITTED** (2026-07-29). Order run:
4, 5, 1, 2, 3, 9, 10, 7, 8, 6.

**Debt: NONE. Every pixel deliverable in this plan has now been looked at
(2026-07-29).** The history of how is worth keeping, because three of the ten
items reversed on sight and no suite here caught any of them:

- **Items 7 and 8: CLEARED.** The reuse follow-up was driven by hand
  through the real RMB menus (that is where `/tmp/Xschem.log.1` came from — the
  `move_trace_to_new_strip` / `split_strip` lines can only be produced by the
  context menus or Graph > Split Strip), and the verdict on the round-2 relocation
  was *"Working ok. Eyeball result pass"*. So both menus have now posted under a
  real pointer and been looked at, which the suites structurally cannot do
  (`tk_popup` is spied — a live popup grabs and swallows the rest of the run).
  ⚠ What is confirmed is the **gesture and the resulting layout**, not a
  pixel-by-pixel review of the menu widget.
- **Item 6 round 2 (`780bd468`): CLEARED** — *"It's eyeball done and pass"*. This
  was the last one standing, and it stood alone for a while: it landed in a
  session that timed out, so its review panel never came up.
- **Item 6 was the worst of the three, and deliberately so.** The shrink has
  **no** automated check and cannot have one: the scaling sits between
  `S_Y()` and `XDrawLines`, so deleting it leaves all 46 checks green. Everything
  its suite proves is plumbing. **Whether the trace visibly shrank was entirely an
  eyeball item, and only the eyeball closed it.**

Three green suites, ~300 checks between them, and not one of them can see. Do not
let the counts read as confirmation — that lesson outlives this plan. The
correction rate here was **3 items in 10 reversed on sight** (item 1's all-bold
legend, item 9's snap cursor after two rounds, item 6's Y-only 10 % shrink), every
one of them green before it was rejected.

The `drawline` change in item 2 — the one thing the
suite structurally could not verify, since nothing here can read back an X GC's
dash pattern — has also been confirmed by eye against ordinary schematics.

---

## The items

### ⚠ Item 1 — legend font too small; match the axis numbers
- [x] **1. Legend font** — **DONE 2026-07-29.** `wviewer_legend_textmag` (1.63)
      + `wviewer_legend_bold` (1) -> the per-rect `legendmag` / new `legendbold`
      tokens; every legend entry bold, the issue-0152 bolded wave now **bold
      ITALIC**; `src/cadence_style_rc` block, spec §"Legend text size + weight",
      `tests/headless/test_wave_legend.tcl` **44 DISPLAY / 33 nogui**.

> **⚠ TWO CORRECTIONS TO THIS SECTION, both material:**
>
> 1. **The landmine below does not apply on the route D-G chose.**
>    `show_node_measures` draws the value at `ry1 + txtsizelab*60` sized
>    `txtsizelab*0.8` — **both already proportional to `txtsizelab`** — and
>    `legendmag` multiplies `txtsizelab` itself (`draw.c`:3718). Name, offset
>    and value scale together; the ratio is unchanged. The overlap would only
>    have happened via the "new C helper" that scaled the name alone, which
>    D-G rejected. No work was needed here at all.
> 2. **"Match the axis numbers" is under-determined and the readings are far
>    apart.** Legend `8.4e-4*rh`, X numbers `9.1e-4*rh`, Y numbers
>    `1.368e-3*rh`. Matching X = **1.083**, an 8% change that is invisible —
>    which cannot be what "too small" meant — so the Y match (**1.63**) is the
>    only reading consistent with the complaint. ⚠ Exact only at the template's
>    `divy=5`: `txtsizey` scales as `1/divy`, `txtsizelab` does not.
>
> Also: the bold had to be a **new per-rect token** (`legendbold`), not an
> unconditional C change — the section's own D-G blast-radius reasoning covers
> the SIZE but the boldness needed the same treatment, and did not have it.
> Defaulted before the `RECT_OUTSIDE` early return, `active`-style.
>
> **Test-seam note:** "a pure Tcl leg on the new var's existence + clamp" was
> an underestimate of what is observable. The prop TOKENS are readable with
> `xschem getprop rect 2 <gi> legendmag|legendbold`, so the tokens reaching the
> rects, surviving a capture round trip, and being ABSENT from the C
> `add_graph` template are all assertable. Only the pixels are eyeball-only.

> **⚠ PREMISE CORRECTION.** The ASE legend is **not** `gr->txtsizelegend`.
> `wave_viewer.tcl` ~1282 never emits `vlegend`, `legend` or `digital`, so
> `draw_graph_variables` takes its final `else` branch and draws the signal name
> at `gr->rx1 + 2 + rw/n_nodes*wcnt, gr->ry1` with **`gr->txtsizelab`**
> (`draw.c` ~4004). `txtsizelegend` only runs on the *vertical* legend path
> (~3947), which ASE never enables. Do not touch it.

**Verdict: EASY.** ~15 lines of C plus one Tcl var.

**Why it is small**: `txtsizelab = marginy * 0.006 * maglegend` (`draw.c` ~3707)
and its only clamp is **commented out** (~3708-3711), so it is purely
strip-height driven: `8.4e-4 * rh`. The axis numbers are `txtsizex = 9.1e-4 * rh`
(bottom-margin clamped, always binding) and `txtsizey = 1.368e-3 * rh` in any
stacked strip. So the legend is already ~0.92× the X numbers and ~0.61× the Y
numbers.

**Do**: add `graph_marker_txtsize`'s twin — one static helper in `draw.c`, base
`gr->txtsizelab`, scaled by a new clamped `set_ne graph_legend_textmag`, using the
same nan-rejecting `>=`/`<=` clamp form. The template is `draw.c` ~5299 +
`xschem.tcl` ~15584, both landed in this working tree; its 25-line comment
already contains the clamp analysis and the px table.

**"Same weight"** is ambiguous — if the user meant *boldness*, note that weight is
already conditional: the bold-wave legend entry (issue 0152) uses
`CAIRO_FONT_WEIGHT_BOLD` (`draw.c` ~3996) while the axis numbers use the default
normal face. Clarify before coding.

**⚠ Landmine, the real work**: `show_node_measures` draws the cursor-1 value as a
*second line* under the name at `gr->ry1 + gr->txtsizelab * 60`, sized
`txtsizelab * 0.8` (`draw.c` ~4106). At 800×500 / 1 strip the name block is
already ~25.3 px against a 25.2 px offset — **touching today**. Enlarging the name
without scaling that offset makes them overlap. The offset and the value size must
move into the same helper.

**Test seam**: eyeball-primary. There is **no** C→Tcl getter for any `Graph_ctx`
txtsize field, and the ASE legend is not hit-tested (`edit_wave_attributes`,
`draw.c` ~4181, only hit-tests the vlegend strip and the digital labels) — so
unlike the marker font this change has **no** hit-box consequence and no existing
verb can observe it. Cheapest real coverage: a pure Tcl leg on the new var's
existence + clamp.

Files: `src/draw.c`, `src/xschem.tcl`, `doc/claude/specs/waveform_viewer.md`.

---

### Item 2 — grid too heavy; config var + 50 % density + rc comment
- [x] **2. Grid density knob** — **DONE 2026-07-29.** `wviewer_grid_dash_off`
      (default 3) -> new per-rect `griddash` token; dash duty 2-on/2-off ->
      1-on/3-off; `src/cadence_style_rc` block, spec §"Graph grid density",
      `tests/headless/test_wave_grid.tcl` 27 nogui + GG* on DISPLAY.

> **⚠ WHAT THIS SECTION MISSED: the change lands in `drawline`, not just in
> `draw_graph_grid`.** D-B is right that the dash plumbing is the target, but
> `XSetDashes` is called from inside `drawline` — the most shared drawing
> routine in the program, ~86 call sites — and it takes a **single `dash` int**,
> so a 1-on/3-off pattern is not expressible without touching it. Resolved by
> splitting it into a `drawline_duty(..., dash, dash_off, ...)` core plus a
> `drawline` wrapper delegating `(dash, dash)`; X11 treats a 1-element dash list
> `{d}` and a 2-element `{d,d}` identically, so every existing call site is
> byte-identical. A mutable global consulted inside the primitive was rejected —
> same landmine class as the shared `graph_struct`, leaking through early
> returns.
>
> Also worth recording: a blanket textual replace of
> `drawline(GRIDLAYER, ADD,` caught **8 nine-argument calls** (axis marks, box
> delimiters, zero lines) that must stay solid and stay on the old signature.
> They are not grid lines and have no duty cycle.

**Verdict: MODERATE.** Blocked on **D-A** and **D-B**.

**Key finding**: the graph grid has **no configuration variable at all** today.
Density comes from the per-rect prop tokens `divx`/`divy`/`subdivx`/`subdivy`
(parsed `draw.c` ~3650), defaulted 5/5/1/1 by **both** templates
(`wave_viewer.tcl` ~1282 and the C `add_graph` template, `scheduler.c` ~1900), and
editable only per-graph in the Graph dialog. Weight is hard-coded: `dash_size =
1.5 * mooz` quantised to {0,2,3}. So this is **"add the knob"**, not "change the
default".

**Do**: follow the shipped viewer-setting pattern — `set_ne wviewer_plot_mode
single` (`wave_viewer.tcl` ~183) + `wviewer::default_plot_mode` (~883) + its rc
documentation (`src/cadence_style_rc` ~226): an rc-overridable var, validated with
a fallback, read lazily at open time and folded into the strip template.

**⚠ Persistence trap**: `subdivx`/`subdivy` are **per-rect and persisted**.
Changing the `wave_viewer.tcl` template only affects newly generated strips;
strips restored from a saved ASE state carry whatever they were saved with. Check
the restore path before claiming the knob is global.

**⚠ Blast radius**: do **not** change the C `add_graph` template
(`scheduler.c` ~1900) — that alters every new on-canvas schematic graph too.

**rc comment**: house style is `##` prose immediately above, then a commented-out
example. Two existing examples live in `src/cadence_style_rc`.

**Test seam**: strong for the rc half — copy
`tests/headless/test_keybind_snap_grid.tcl` ~84-92 verbatim (read the rc, skip
blanks and `#`, assert the new line is present-and-COMMENTED). Weak for the pixels.

Files: `src/wave_viewer.tcl`, `src/cadence_style_rc`, `src/xschem.tcl`,
possibly `src/draw.c`.

---

### Item 3 — remappable Ctrl-G toggles the grid in the active viewer
- [x] **3. Ctrl-G grid toggle** — **DONE 2026-07-29.** `Graph_ctx.grid` + the
      `grid` token, `wviewer::grid_toggle`/`_at`/`grid_shown`, the
      `WaveViewer` Ctrl-G default, a Graph-menu CHECKBUTTON,
      `wviewer_grid_show`, rc block, spec §"Grid on/off". `GT*` in
      `test_wave_grid.tcl`: 44 nogui / 80 DISPLAY.

> **⚠ "Then gate `draw_graph_grid`'s body" WOULD HAVE BROKEN THE PLOT.** That
> function also draws the background, the bounding box, the tick marks, **the
> axis NUMBERS** and the zero lines. Gating the body takes the numbers with it
> and leaves a plot nobody can read. Only the four dashed-line calls are gated.
>
> Two things the section got right and one it did not mention: the `active=1`
> precedent transferred exactly (default before `RECT_OUTSIDE`), and the
> bindtag/rc-wins recipe was correct. Not mentioned: the grid flag is a WINDOW
> property, so it belongs in the layout dict beside `sharedx` and must reach
> `graph_props` as an ARGUMENT — reading it from a namespace global would make
> the rect generator impure, the same objection that shaped item 2's
> `drawline` split. Also: the menu twin has to be a **checkbutton** whose
> `-command` SETS the value Tk already wrote; toggling again inverts twice and
> the menu looks dead.

**Verdict: MODERATE.** Blocked on **D-A**. Binding half is trivial; the feature
half needs a small C change because **there is no grid on/off switch anywhere in
the waveform renderer** — `draw_graph_grid` draws unconditionally.

**Do**, binding half (pure Tcl, a 3-line clone of Ctrl-D):
`bind WaveViewer <Control-Key-g> {wviewer::grid_toggle_at %W; break}` inside
`wviewer::install_default_binds` (~3112), guarded by the same
`if {[bind …] eq {}}` rc-wins test Ctrl-D uses; a `wviewer::grid_toggle_at {W}`
next to `clear_all_at` (~3090); a Graph-menu checkbutton twin next to Clear All
(~4283).

**Do**, feature half — copy the shipped `active=1` precedent (issue 0151) and
`reorder_handle`, the two viewer-only prop tokens already parsed into `Graph_ctx`:
add `int grid;` to `Graph_ctx`; default it to 1 in `setup_graph_data`'s defaults
block and parse a `grid` token beside `subdivx`/`divx`. It **must** be set before
the `RECT_OUTSIDE` early return (landmine 37a / 18), or a stale value leaks onto
the next graph via the shared `graph_struct`. Then gate `draw_graph_grid`'s body.

**Collision check — done, safe**: Ctrl-G in the schematic toggles the global
`draw_grid` (`src/cadence_style_rc` ~274). A `WaveViewer` **bindtag** binding does
not touch it — the schematic canvas does not carry that tag.

**Remappability**: note there are **three** ways a key reaches the viewer
(`graphkeys` forward to C, the `WaveViewer` bindtag, the C binding table). Ctrl-D
uses the bindtag with an rc-wins guard, which is what makes it remappable *and*
viewer-scoped. Copy that, not the C table.

**Test seam**: `graph_props` is PURE — assert the emitted prop string gains/loses
the `grid=0` token, headless. Assert `[bind WaveViewer <Control-Key-g>]` exists,
sits on the canvas bindtags, survives `strip_bindings`, and is **not** overwritten
when an rc bound it first (clone `test_wave_clear_all`'s CG4/CG6).

---

### Item 4 — remappable Ctrl-E deletes all markers in the active viewer
- [x] **4. Ctrl-E delete all markers** — **DONE 2026-07-29**, uncommitted.
      `wviewer::delete_all_markers` / `_at`, the `WaveViewer` Ctrl-E default, the
      Graph-menu twin, spec §6.1.1, landmine 41, and the `MD` test group.
      Suites: markers **712 / 328** (was 641 / 310), viewer 349, modes 384,
      clear_all 68, ase_plot 145. 18 DISPLAY runs, no flake.

> **⚠ TWO THINGS THIS SECTION GOT WRONG** (both found by the map/review passes,
> both corrected in the build):
>
> 1. **"Test seam: fully headless" is FALSE.** `graph_marker_notify()`
>    (`draw.c` ~6073) opens `if(!has_x) return;`, so under `--nogui` the push
>    hook never fires: no model update, no undo point. Every model/undo
>    assertion is a DISPLAY-arm assertion. Now **landmine 41**.
> 2. **"the C verb self-logs, so the wrapper need not" is a trap.** The
>    self-logged `xschem graph_marker delete -all -1` is **not replayable into a
>    viewer** — `scheduler.c` readonly-rejects the arm and returns `TCL_ERROR`,
>    which *aborts* a sourced log rather than warning. The wrapper suppresses it
>    (`xschem log_action -suppress push`/`pop`, **pop unconditional** — the
>    counter is global) and emits one `wviewer::` line instead.
>
> Also missed by the section: `cadence_style_rc:189` binds `<Control-Key-e>` on
> `.drw` and `clone_canvas_bindings` copies it onto every new canvas, viewer
> included. It is neutralised only by `strip_bindings`' sweep — now guarded by a
> leg that plants the clone by hand and proves the sweep removes it.
>
> **Spun off: issue 0172** — a viewer buffer can be hijacked by the
> `is_pristine_untitled()` reuse path, after which `Ctrl-D` wipes the loaded
> schematic. Pre-existing, not an item-4 defect, filed rather than fixed.

**Verdict: EASY.** The operation, the log line, the model sync and the viewer undo
point **all already exist**. This is a binding plus a ~12-line wrapper.

`xschem graph_marker delete -all [<gi>]` (`scheduler.c` ~5056) →
`graph_marker_delete_all` (`draw.c` ~5917). With `gi` omitted it clears every graph
rect in the **current context**, which is per-window, so it is already
viewer-scoped. It sweeps dangling `prev` delta links, resets `graph_marker_sel`,
calls `set_modify(1)` and `graph_marker_notify()`, and **self-logs**
`xschem graph_marker delete -all -1`.

**Do**: `wviewer::delete_all_markers` beside `clear_all` (~3059) —
`resolve_token`; `ciw_echo` + return when no viewer resolves; verified
`switch_ctx`; then **`wviewer::with_edit`** around the verb (mandatory:
`graph_marker_delete_all` calls `graph_marker_ro_refuse()` *and* the scheduler arm
readonly-rejects, and the viewer is read-only for life) — the same bracket
`key_filter` already uses for `m`/`d`/`Delete` (~4089); then `xschem redraw`
(`graph_marker_notify` does not repaint).

**Collision check — done, safe**: Ctrl-E in the schematic canvas is `go_back(1)`
(`callback.c` ~5578, `case 'e'` with `rstate == ControlMask`) — a hardcoded legacy
switch case, not a binding-table row. A `WaveViewer` bindtag binding does not
reach it. **Do not** teach `key_filter` to forward keysym 101; `e` is not in
`graphkeys`, so Ctrl-E is swallowed today and the tag binding fires cleanly.

**Test seam**: fully headless. Create markers with `xschem graph_marker add_at`,
call the proc, assert `graph_marker list` is empty, every strip's model dict lost
its `markers` key, `modified` is still 0 (with_edit discipline held), and
`wviewer::undo` brings them back.

---

### Item 5 — remappable `e` deletes all empty strips in the active window
- [x] **5. `e` delete empty strips** — **DONE 2026-07-29.**
      `wviewer::remove_graphs` / `index_after_removal` /
      `empty_strips_to_delete` (pure), `delete_empty_strips` / `_at`, the
      `WaveViewer` bare-`e` default, the Graph-menu twin, the
      `src/cadence_style_rc` block, spec §"Delete Empty Strips", and the new
      `tests/headless/test_wave_empty_strips.tcl` — **94 DISPLAY / 28 nogui**,
      sabotage-verified four ways.

> **⚠ ONE THING THIS SECTION GOT WRONG, and one trap it did not mention:**
>
> 1. **"reordered_index is for MOVES and does not cover deletion" — right, but
>    the reason matters more than the fact.** `target_index` **clamps** every
>    read to the live strip count, so on the obvious fixture (empty strips at
>    the bottom of the stack) the clamp alone lands on exactly the index the
>    remap would have produced — **deleting the remap outright still passed a
>    10-leg target group.** Measured, not theorised: sabotage run 2 was green.
>    The fixture has to be built so the two answers differ (8 strips, empties at
>    1 and 3, target 5 → 3 while the clamp would say 5).
> 2. **A marker record needs ≥ 9 fields** (`num wave dset point x y prev ldx
>    ldy`) — `markers_line_fields` refuses anything shorter, so a short
>    hand-planted fixture reads as "no markers at all" and the whole marker
>    group passes vacuously. And a marker planted in the MODEL only is wiped
>    before the deletion sees it: `capture_live_graph_state` re-reads `markers`
>    from the RECT PROPS, so the fixture must `regenerate` first.
>
> Confirmed as written: the pure half already existed, `empty_graph_indices`'s
> `auto` argument was exactly one argument away from D-D, and `move_strip`'s
> contract transferred verbatim. `set_target_strip` was correctly avoided (it
> would emit a second replay-log line).

**Verdict: MODERATE.** Blocked on **D-C** and **D-D**. The pure half already
exists.

`wviewer::empty_graph_indices` (~903) is already exactly "traceless, non-auto
strips, in index order", PURE and unit-tested. A strip is just a dict in
`[dict get $layout graphs]`, so deleting one is a **list remove + regenerate**,
never a schematic delete of the rect.

**Do**:
1. PURE `wviewer::remove_graphs {graphs indices}` → surviving list, and PURE
   `wviewer::index_after_removal {index removed}` → the new position of the stored
   target. (`reordered_index` ~1854 is for MOVES and does not cover deletion.)
2. Mutating `wviewer::delete_empty_strips` following **`move_strip`'s contract
   verbatim** (~2046), including its *empty set → return without mutating and
   without logging* rule (the `from == to` precedent), and remapping the target
   **in place** rather than via `set_target_strip` (which would emit a spurious
   second log line on replay).
3. Reuse `delete_ok`'s marker bookkeeping (~3811) — deleting strips shifts node
   indices, and `graph_markers.md` §9 makes the remap obligations explicit.

**Test seam**: strong. The three pure procs assert directly with literal lists,
headless. Then with a viewer open: build 4 strips (2 with traces, 1 empty, 1
auto), call the proc, assert the surviving model list, `xschem get graph_rects`,
the remapped target, `modified == 0`, and one log line.

---

### ⚠ Item 6 — mid-drag 10 % shrink preview of the dragged trace
- [x] **6. Drag shrink preview** — **DONE 2026-07-29.** Three transient `xctx`
      fields + `gr->preview_wave`, applied in `draw_graph_points`; the
      `xschem set/get graph_preview` verb pair; `wviewer::drag_preview_arm` /
      `_clear` + the `wviewer_drag_shrink` knob. Contract:
      `doc/claude/specs/waveform_viewer.md` §"Mid-drag shrink preview".
      Suite `tests/headless/test_wave_drag_preview.tcl` — 46 DISPLAY / 18 nogui.

> **⚠ ONE CORRECTION AND ONE HONEST GAP.**
>
> **(1) The route recommendation is backwards.** The section says "pick the
> second unless profiling says otherwise" and the second is the affine shortcut
> that scales `gr->scx`/`gr->sdx` — which the same bullet then warns writes into
> the shared `xctx->graph_struct` (landmine 11) and needs every early exit inside
> the wave body to restore. The **per-point** route was taken instead: one
> multiply-add per sample, inside the loop that was already touching every
> sample, with no shared state to restore and no early-exit obligation. There is
> nothing to profile — the affine version saves arithmetic the loop was doing
> anyway.
>
> **(1b) Y-ONLY AND 10 % WERE BOTH WRONG, and only the eyeball could say so.**
> The section asks for a "10 % shrink" and describes scaling y about the plot-box
> centre. That shipped, was looked at, and was rejected: *"shrink should be in
> both X and Y, not just Y. Bump up the shrink to 30 %."* A Y-only squeeze reads
> as a gain change rather than a pick-up, and 10 % is below the threshold where
> the eye notices at all. Final: both axes, `wviewer_drag_shrink` default 0.7.
> This is item 1's lesson for the third time — **ship the knob, default it
> conservatively, and let the eyeball settle it** — except that here the
> conservative default was itself the thing that was wrong.
>
> **(2) The pixel effect is NOT sabotage-verified, and cannot be.** The Tcl half
> (arming, the node-index mapping, teardown, the rc knob) is, four ways. But the
> scaling happens between `S_Y()` and `XDrawLines`, with no seam to spy and no
> pixel readback, so **deleting the C render line leaves the suite green**. The
> plan's own test seam — `graph_trace_at` unchanged while armed — is in and
> passing, but it proves the preview does NOT move the drop-target maths, which
> is the opposite property. Whether the trace visibly shrinks is an eyeball item
> and nothing else.

**Verdict: MODERATE.** Blocked on **D-E**. ~40 lines of C across 3 sites plus a
setter verb and 2 Tcl call sites. Nothing architecturally novel.

**Do**: copy the **marker scratch** pattern (`graph_markers.md` §3.5 — the
renderer substitutes `xctx->graph_marker_scratch` for the stored record, so a
motion event costs no allocation and no undo point), applied to the trace polyline
instead of a marker record. Three transient `xctx` fields — previewed graph index,
previewed node index, scale — declared beside `graph_marker_scratch`, **reset in
both `clear_drawing()` and `alloc_xschem_data()`** (the marker lesson).

**Gate on `flags & 16`** so exports draw the trace unshrunk.

**Two implementation routes** — pick the second unless profiling says otherwise:
- per-point `v = c + (v - c) * s` about the plot-box screen centre, applied
  **before** the `CLIP(…, -30000, 30000)` (else a rail-clamped sample scales from
  the rail and produces a visible kink);
- the affine shortcut: temporarily scale `gr->scx`/`gr->sdx` etc. — **but** that
  writes into the shared `xctx->graph_struct` (landmine 11) and every early exit
  inside the wave body must restore.

**⚠ `gr->cy` is negative** (landmine 3) — compute the y centre from
`S_Y(gy1)`/`S_Y(gy2)`, never assume ordering.

**Closest existing "render ONE trace of a strip differently"**: `set_thick_waves`
(`draw.c` ~2874), which changes the GC line width around the trace whose `wcnt`
matches `gr->hilight_wave` and restores immediately. Copy its *selection*
comparison, not its mechanism.

**Test seam**: pixels are eyeball-only. The real regression guard: assert
`xschem get graph_trace_at` answers are **unchanged** while a preview is armed —
i.e. the preview is visual only and the drop-target math is unaffected. Cheap and
worth having.

---

### ⚠ Item 7 — RMB context menu on a trace → "move to separate strip"
- [x] **7. Trace context menu** — **DONE 2026-07-29.**
      `wviewer::move_trace_to_new_strip` + the `trace_menu_pick`/`_build`/
      `_post`/`_unpost` quartet + the rewritten `btn3_filter`, all in
      `wave_viewer.tcl`. Pure Tcl; no C change. Contract:
      `doc/claude/specs/waveform_viewer.md` §"Trace context menu".
      Suite `tests/headless/test_wave_trace_menu.tcl` — 128 DISPLAY / 34 nogui.
- [x] **7 follow-up — REUSE AN EMPTY STRIP INSTEAD OF INSERTING ONE.**
      **DONE 2026-07-29** (user request, same day). The gesture now consumes an
      existing empty strip **anywhere** in the stack and inserts only when there
      is none, which is issue 0171's plot-batch reuse (`plan_plot`) applied to
      this gesture. New PURE `wviewer::graph_is_empty` (**the** definition of
      empty — zero MODEL traces — now shared by this, item 8, `plan_plot` and
      item 5's `e`), `wviewer::reuse_strip_for_trace_move` (the D1/D2 choice) and
      `wviewer::reuse_max_distance` (D2's optional cap, **default OFF**).
      Decisions recorded in the spec: **D1** nearest below, else nearest above,
      strictly (below wins even when above is nearer); **D2** a far strip IS
      taken, cap available but off; **D5** the destination is still the target.
      The auto-plot strip stays excluded (D-D). Return value is now "the
      destination", which may be a pre-existing strip.
      Suite grew to **223 DISPLAY / 71 nogui** — `TG12..TG18`, every reuse leg
      asserting the strip COUNT *and* an inert per-strip identity key, because
      "consume the strip at `from_gi + 1`" and "insert one there" produce an
      identical-looking model. Five extra sabotages, each red in a different
      place (never reuse; reuse unconditionally; above-before-below; auto
      exclusion dropped; insert-arm index written to the target).
      ⚠ **Still un-eyeballed, and this does not change that** — see the debt
      list above. The reuse is a *model* change, so the suite can see it; what
      remains unseen is item 7's menu itself.

> **⚠ THREE PLAN CORRECTIONS, all found while building. Read them before item 8,
> which inherits this gesture layer wholesale.**
>
> **(1) The travel tolerance is ZERO, not `GRAPH_CLICK_TOL`.** The recon block
> below cites the LMB wave-bold click (`callback.c` ~879, 3 px) as the precedent
> for the travel test. It is the wrong precedent, and following it shipped a
> defect that the suite caught: **Button1 has no box zoom to collide with, and
> Button3 does.** The engine's Button-3 box-zoom gate is *exact equality* —
> `xmoved = (xctx->mx_double_save != xctx->mousex_snap)` (`callback.c` ~1871) —
> and `mousex_snap` **is the raw pointer** in graph interaction, because the snap
> grid is deliberately disabled there (`callback.c` ~810, issue 0143). So a
> release ONE pixel from its press has already committed a box zoom. With a 3 px
> tolerance the menu posted on top of that zoom, and the gate then ran against
> the post-zoom geometry — the trace had moved out from under the pointer and the
> menu silently did not appear. The measurement quoted below ("a bare RMB click
> is a no-op") is exactly right and exactly as narrow as it sounds: it holds at
> zero travel and nowhere else.
>
> **(2) The stored-target shift is unreachable, so it was not written.** The
> section below says to shift the target through the insert with `plot_signals`'
> arithmetic. It cannot apply: `move_trace` step 6 makes the DESTINATION the
> target, and this command inherits that rule, so the shift would be overwritten
> on the next line. The insert-twin of `index_after_removal` is therefore
> **still owed by item 8**, whose split adopts no single destination and does
> need it.
>
> **(3) Landmine 33 points the other way for THIS gate.** Item 8's note below is
> right that `near_wave` answers 0 across a digital/bus body. The consequence for
> item 7 is not "the menu appears everywhere" but the opposite: `graph_wave_at`
> documents "digital strips and bus traces answer -1" (`draw.c` ~4711), so
> `trace_at` misses everywhere and **item 7's menu never appears on such a
> strip**. Same limit the LMB trace drag already has; recorded in the spec as
> stated behaviour rather than closed.
>
> Two things the section did not anticipate and that are now in the shipped gate:
> a press made while a **marker drag** was armed is refused (the release aborts
> that drag — a menu there would be a side effect of cancelling something else),
> and the arm can only be observed on the **press**, so `btn3_filter` records it.

**Verdict: MODERATE.** The payload is ~30 lines on three shipped PURE primitives
and the gate predicate already exists. **All** the difficulty is in the RMB
gesture plumbing, which is a live minefield.

**Model**: `wviewer::move_trace_to_new_strip` = `wviewer::move_trace` (~2600) with
one extra step, and it must **not** call `add_graph` (which regenerates mid-op and
skips capture/undo/log). `linsert` an `empty_graph` at the chosen slot, then reuse
the PURE `wviewer::move_trace_in_graphs` (~2521) — that buys the marker migration,
the `hilight_wave` hand-off and the empty-destination range blanking **for free**,
with zero new index math. Shift the stored `target` by the insert using
`plot_signals`' arithmetic (~3007), **not** `reordered_index` (which is for moves).

**Gate**: offer the item only when the strip has ≥ 2 drawn traces
(`wviewer::node_count`).

**⚠ Three gesture risks, all real**:
1. **GRAPHPAN leak** — a popup with a grab swallows the real `ButtonRelease-3`,
   and a Button3 release is the one release that does not clear `GRAPHPAN`
   generically (`callback.c` ~1861). Mitigation: hand-forward event 5 before
   posting the menu.
2. **Rubber-rect leak** — the box-zoom outline is erased only on the B3 release
   (`callback.c` ~1458), so a hold with any jitter leaves a painted rectangle.
   Same mitigation.
3. **The numeric cursor set** (`callback.c` ~1097) is a **modal `input_line`** on
   an RMB press within 10 px of a drawn cursor — a forwarded press blocks until
   dismissed, so the hold timer must be armed with that in mind.

**Do first**: enumerate every current Button-3 binding in `wave_viewer.tcl` and
every Button3 arm in `waves_callback`, and decide how a *hold* is distinguished
from a *drag*, before writing any menu code.

> **✅ RECON DONE 2026-07-29 — and it changes the recommended gesture.**
>
> **Every Button-3 site in a viewer window:**
>
> | | site | trigger | effect |
> |---|---|---|---|
> | A | `callback.c` ~896 | B3 press **outside** the plot box (a wave label) | `edit_wave_attributes` dialog |
> | B | `callback.c` ~1097 | B3 press within 10 px of a drawn cursor | **modal** `input_line` |
> | C | `callback.c` ~1356 | any B1/B2/B3 press, `!graph_top` | latches `GRAPHPAN`, saves press coords, clears the rubber flag |
> | D | `callback.c` ~1413 | B3 + `GRAPHPAN`, interior | computes the box-zoom range |
> | E | `callback.c` ~1429 | B3 **motion** + `GRAPHPAN`, interior | paints the rubber rectangle |
> | F | `callback.c` ~1460 | B3 **release** + `graph_rubber_active` | erases the rubber rectangle |
> | G | `wave_viewer.tcl` ~4794 | `<ButtonPress-3>`/`<ButtonRelease-3>` | `btn3_filter` → `xschem callback` |
> | H | `wave_viewer.tcl` ~4835 | `<Double-Button-3>` | `{break}` |
>
> **MEASURED: a bare RMB click in the plot body is a NO-OP today.** Probe —
> record `x1`/`x2`, generate `<ButtonPress-3>` then `<ButtonRelease-3>` at the
> same pixel, re-read: `0 1` → `0 1` → `0 1`. With no motion
> `graph_rubber_active` stays 0 and no zoom is committed, so the
> `if(xx1 == xx2) xx2 += 1e-6` line never reaches the apply loop.
>
> **⇒ USE A CLICK, NOT A HOLD, AND POST ON THE RELEASE.** The section proposes
> a hold timer plus "hand-forward event 5 before posting the menu" to work
> around the three hazards. Posting on the **no-travel ButtonRelease-3**,
> *after* `btn3_filter` has already forwarded the event to C, avoids all three
> **structurally** instead of mitigating them:
> - **Hazard 1 (GRAPHPAN leak)** — there is no grab during press→release, so
>   the real `ButtonRelease-3` is never swallowed and `GRAPHPAN` clears on its
>   normal path.
> - **Hazard 2 (rubber-rect leak)** — site F erases the rectangle on that same
>   release, before the menu is posted.
> - **Hazard 3 (the modal `input_line`)** — it is on the **press** (site B), and
>   this design never touches the press at all.
>
> The travel test has a precedent in this very file: the LMB wave-bold click
> uses `xctx->graph_press_x/y` against `GRAPH_CLICK_TOL` (`callback.c` ~879),
> and the comment there records that B3 *used* to work this way before it became
> box-zoom-only. Tcl can do the same test with the `%x`/`%y` it already receives
> in `btn3_filter`.
>
> Remaining risk is now ordinary, not gestural: the menu must not appear when
> the click was a real box-zoom drag, and must not appear outside a trace.

---

### ⚠ Item 8 — RMB context menu on empty strip space → "split current strip"
- [x] **8. Strip context menu** — **DONE 2026-07-29.**
      `wviewer::split_graph_in_graphs` / `split_strip` / `split_target_strip` +
      the `strip_menu_*` quartet + `ctx_menu_post`, and the PURE
      `index_after_insert` item 7 turned out not to need. One C addition:
      `xschem get graph_plotbox_at`, a read-only wrapper of the existing
      `draw.c graph_plotbox_at`. Contract:
      `doc/claude/specs/waveform_viewer.md` §"Strip context menu".
      Suite `tests/headless/test_wave_split_strip.tcl` — 122 DISPLAY / 38 nogui.
- [x] **8 follow-up — REUSE THE ADJACENT EMPTY STRIP.** **DONE 2026-07-29**
      (user request, same day). New PURE `wviewer::plan_split` →
      `{ok reuse at new}`, called by both `split_graph_in_graphs` and
      `split_strip` so the model op and the target arithmetic cannot disagree.
      **Deliberately narrower than item 7's reuse** (the asymmetry is the user's,
      not a slip): **D3** only `gi + 1` is eligible — an empty strip above would
      put node 1 above node 0 and break the reading order D-F exists for; **D4**
      that one slot takes node 1 and the remaining `nc - 2` are inserted at
      `gi + 2`, so `nc == 2` inserts **nothing** and `split_strip` returns **0**,
      which is a **success** (it mutates, logs and takes an undo point — only `{}`
      is a refusal); **D5** the target shift now uses the plan's ACTUAL `at`/`new`
      (the old `gi + 1`/`nc - 1` pushed the target one strip too far).
      Suite grew to **211 DISPLAY / 72 nogui** — `SG12..SG18`, same
      count-plus-identity discipline as item 7's. Five extra sabotages, each red
      somewhere different; notably "reuse unconditionally" goes red at `SP11` by
      moving a trace *into* a non-dict sentinel, which is how the fail-open
      `graph_is_empty` bug was caught for real (`dict exists` is lenient on a
      non-dict, so the well-formedness test had to be made explicit).
      ⚠ **Menu pixels still un-eyeballed** — unchanged by this.
- [x] **8 follow-up ROUND 2 — D3 REVISED: RELOCATE the empty strip.**
      **DONE 2026-07-29**, after the round-1 build was driven for real and
      **reported as a defect**. Round 1 could consume only the strip at exactly
      `gi + 1`, which almost never fires. The repro (log `/tmp/Xschem.log.1`):
      three strips of one trace each → drag strip 1's trace onto strip 2 (strip 1
      goes empty) → split strip 2. Strip 2 is bottom-most, so `gi + 1` does not
      exist, the free strip is **above**, and round 1 inserted a fourth strip next
      to a blank one.
      **v2 takes the nearest empty strip anywhere (D1's order) and RELOCATES it**
      below the split strip: D-F's reading order survives because the strip is
      *moved*, not filled in place, and the count does not grow while an empty
      strip exists. `plan_split` now reports `{ok take src at block new}`; the
      target remap became the PURE `target_after_split` (a REMOVAL then an
      insertion — a bare `index_after_insert` is now wrong, and a target that IS
      the relocated strip follows it by identity). D2's cap is shared with item 7.
      Suite **221 DISPLAY / 80 nogui**; `SG12` is the reported repro end to end.
      Five fresh sabotages, each red in a different place.
      ⚠ **The lesson, for the record:** the round-1 decision (D3 "adjacent only")
      was mine to recommend and was approved, but it was only *reasoned* about —
      one real gesture sequence showed it fires almost never. A decision about
      *where* something lands is worth driving before it is called done.

> **⚠ TWO CORRECTIONS.**
>
> **(1) The gate needs a THIRD predicate the section does not list: inside the
> PLOT BOX.** "`strip_at_pixel >= 0` and no trace under the pointer" is
> satisfied by the **legend/label margin** at the top of every band — and a
> Button3 *press* there is already the wave-attributes dialog (`callback.c`
> ~896), so the menu posted on top of it. Caught by the suite, not by reasoning.
> The LMB strip reorder does not have this problem because it acts on the press
> and the band is genuinely its territory; an RMB menu is not. Tcl cannot
> re-derive the box, so this exposes `draw.c`'s existing `graph_plotbox_at`
> (item 9's snap-cursor gate) as `xschem get graph_plotbox_at` and uses it
> unchanged.
>
> **(2) Landmine 33, decided: neither menu fires on a digital or bus strip.**
> The section asks whether item 8 firing everywhere on such a strip is
> acceptable. It does not fire there at all: `graph_plotbox_at` refuses digital
> strips for the same reason `graph_wave_at` does. So the honest answer to the
> open question is "explicit refusal, inherited from the engine". Relaxing it
> means relaxing `graph_plotbox_at`, which would also change item 9's snap
> cursor — out of scope here, recorded in the spec.
>
> One thing the section got exactly right and worth keeping: implementing the
> split as a **descending loop over `move_trace_in_graphs`** rather than fresh
> index math. Sabotaging the loop to ascend scrambles 21 checks; nothing about
> markers had to be written at all.
>
> **The 10-run soak earned its keep.** It failed 3 of 10 with
> `invalid command name "..wvmenubar"` — a PRE-EXISTING intermittent in
> `wviewer::open`, live since `cd332719`, that no single run reproduces.
> `xschem load_new_window -window {}` always creates the toplevel but the switch
> to it is a `switch_window`, which no-ops under a raised semaphore, so
> `current_win_path` came back as the OLD window about a third of the time and
> every viewer widget path became `..<name>`. Fixed separately in `5ddb8361`
> (verify the switch and retry, refuse cleanly if it still lands on the root) —
> item 8 only exposed it.

**Verdict: MODERATE**, and **nearly free once item 7 lands** — it shares 100 % of
the gesture plumbing. Blocked on **D-F**. **Sequence after item 7.**

**Model**: one new PURE `wviewer::split_graph_in_graphs {graphs gi}` implemented
as a **loop over the shipped `move_trace_in_graphs`**, descending from the last
trace so the surviving index is stable — *not* as fresh index math. Every
iteration gets the marker migration, the `hilight_wave` hand-off and the range
blanking for free, and the `graph_markers.md` §9 obligations are discharged **by
construction**. Then the usual `split_strip` wrapper repeating `move_strip`'s
ordering contract verbatim.

**Gate**: `strip_at_pixel >= 0` **and** no trace under the pointer **and**
`node_count > 1` — the exact two predicates the LMB strip reorder already uses to
claim "empty waveform space", so the menu fires precisely where the reorder arms.

**⚠ Landmine 33**: `near_wave` answers 0 across the **entire body** of a digital
or bus strip, so on such a strip item 8's menu would appear everywhere and item 7's
never. Decide whether that is acceptable or needs an explicit refusal.

**Test seam**: strictly easier than item 7 because the core is PURE — feed it the
`m8base`/`m8rich`/`m8hl` fixtures already built in `test_wave_modes.tcl` ~414-538
and assert the per-strip vec lists, the migrated markers token and the migrated
`hilight_wave`.

---

### Item 9 — diamond snap cursor on the nearest trace
- [x] **9. Diamond snap cursor** — **DONE 2026-07-29.** `draw_graph_snap_cursor`
      / `graph_snap_clear` in draw.c, per-context arming
      (`xschem set graph_snap_cursor`), the publish seam
      `xschem get graph_snap`, armed by the viewer at open.
      `tests/headless/test_wave_snap.tcl` 15 nogui / 28 DISPLAY.

> **⚠ THE LETTER-DISPATCH LANDMINE BIT BOTH HALVES OF THE NEW VERB.**
> `xschem get` groups its sub-keys by FIRST LETTER, and `xschem set` splits on
> `argv[2][0] < 'n'`. A `g` key filed in the wrong half is **silently
> unreachable** — no error, `xschem set graph_snap_cursor 1` just did nothing
> and the getter kept returning 0. Both halves were mis-filed on the first try.
> `SP5` is now the regression leg. (`[[scheduler-letter-dispatch]]` covers the
> top-level subcommands; this is the same trap one level down, inside
> `get`/`set`.)
>
> **The plan's cost warning was right, and the fix it suggested was not quite
> enough.** `pos_changed` in `draw_snap_cursor` suppresses the REPAINT but not
> the QUERY; since `graph_point_at` is the expensive part, item 9 needs a brake
> on the mouse PIXEL before the query runs, plus the sample-unchanged test to
> suppress the repaint. Both are in.
>
> **Not mentioned by the section: arming must be per CONTEXT** (the `no_grid`
> precedent), not a global Tcl var — `graph_point_at` is shared with the ~127
> embedded schematic graphs. And the obvious test for that (`SG1`, read the
> getter in each window) is HOLLOW: the getter reports the field whatever the
> pump consults. Measured — that sabotage left `SG1` green and merely shrank
> the suite. `SS6` is the leg that bites.
>
> **Bit 16 turned out to be unnecessary**: the cadence paints with
> `draw_pixmap = 0`, so the glyph never enters `save_pixmap` and cannot reach an
> export at all — structurally stronger than the flags bit.
>
> **⚠ TWO DEFECTS SHIPPED PAST A FULLY GREEN SUITE, both caught by eye:**
> 1. **The diamond left a TRAIL.** Erasing by re-stroking with `xctx->gctiled`
>    is the shipped *schematic* path but does not remove the glyph in a viewer
>    window; only a full redraw (`f`) cleared it. Fixed by copying the patch
>    back from `save_pixmap` — the fallback `erase_snap_cursor` itself uses
>    where the tiled fill is known broken.
> 2. **The gate was proximity, not the plot box.** The pointer had to pass
>    within ~20 px of a trace. The spec is: anywhere inside the rectangle
>    delineated by the two axes and the two lines opposite them, snap to the
>    nearest sample of the nearest trace *however far away it is*. Fixed with
>    `graph_plotbox_at()`; `graph_point_at`'s threshold is now unreachable.
>
> **The lesson, and it is the important one for the items still to come:** this
> suite's own header says the glyph is eyeball-only, and the item was reported
> DONE without the eyeball. Everything the tests could reach was right; the
> thing the user sees was wrong, twice. For any item whose deliverable is
> pixels, "suites green" is a precondition for asking, never an answer.

**Verdict: EASY-to-MODERATE.** The query is **100 % shipped**; this is a rendering
and repaint-cadence job.

> **The precedent is almost embarrassingly close**: `draw_snap_cursor_shape()`
> (`callback.c` ~2372) **already draws a diamond** — four lines,
> top→right→bottom→left→top — and `draw_snap_cursor()` (~2422) already implements
> the whole cadence: window-only (`draw_pixmap = 0`), erase-old-with-`gctiled`,
> draw-new, restore, with a `pos_changed` early-out.

**Do**:
1. **Query** — `graph_point_at(i, X_TO_SCREEN(mousex), Y_TO_SCREEN(mousey), tol,
   -1, -1, &hit)`, exactly as `graph_marker_drag_to` calls it. `hit.sx`/`hit.sy`
   are **already screen pixels**; `hit.x`/`hit.y` are the raw data values for the
   status bar (item 10).
2. **State** — `xctx` fields mirroring the hover trio (`hover_type`/`hover_n`/
   `hover_col`, `callback.c` ~2633).
3. **Render** — `draw_snap_cursor()`'s body with
   `draw_snap_cursor_shape()`'s glyph, minus its `X_TO_SCREEN` calls (the hit is
   already screen). For a *filled* diamond instead, build a 4-point `XPoint` array
   and use `drawtemppolygon` — there is no diamond primitive.
4. **Bit 16**, not bit 8 — transient UI chrome.

**⚠ The real risk is per-hover cost**: `graph_point_at` walks every sample of every
trace of the strip on every call. `graph_marker_drag_to` already does exactly this
per motion event, so it is *proven affordable during a drag* — but item 9 runs it
on **bare hover**, constantly. The scan is capped by the graph's visible x window,
and the `pos_changed` test suppresses the **repaint** but not the **query**.
Measure it; if it is too heavy, cache per-strip.

**⚠ Landmine 35**: a *picked* sample's x/y must be returned **raw**, never through
`mylog10` (which hard-clamps ≤ 0 to −35 — a zero-crossing trace would read 1e-35).

**Must yield to**: marker drag, strip drag, trace drag, cursor drag, box zoom.
Enumerate the gestures and put the test in one place.

**Test seam**: half headless. The query half is fully testable under `--nogui`
against a hermetic `xschem raw new` fixture (the MR* pattern, never ngspice); the
glyph is eyeball-only. A new `xschem get` verb exposing the snapped x/y is
probably needed anyway for item 10 — build it here and test it here.

---

### Item 10 — waveform-window status bar: plot mode + diamond cursor x,y
- [x] **10. Viewer status bar** — **DONE 2026-07-29.** Private `$top.wvstatus`,
      PURE `wviewer::status_text`, `wviewer::status_refresh` on the kept generic
      `<Motion>`, the mode PUSHED from `set_plot_mode`, the editor status bar
      `pack forget`'d per window. `ST*` legs in `test_wave_snap.tcl`.

> **The section's warnings were all correct** — do not repurpose
> `$top.statusbar`, copy the `wvreadout` pattern, `-before $top.drw`, push from
> `set_plot_mode`, and call it `Plot:` not `MODE:`. Each is now a test leg.
>
> **⚠ ONE TRAP IT COULD NOT HAVE KNOWN: `wviewer::in_ctx` uses `uplevel #0`.**
> A `set` inside its script body creates a GLOBAL; the caller's local stays
> empty. The status bar showed the plot mode and never a coordinate until the
> value was taken through the **return** instead. `wviewer::with_edit` uses
> `uplevel 1` and DOES reach the caller's scope — which is exactly what
> `delete_all_markers`' count relies on — so the two brackets behave
> differently and nothing warns you.

**Verdict: MODERATE.** **Sequence after item 9** — the x,y does not exist until
item 9 lands.

> **⚠ DO NOT repurpose `$top.statusbar.*`.** `statusmsg()` (`scheduler.c` ~49) and
> `update_statusbar()` (`callback.c` ~7994) rewrite slots .1/.3/.5/.7/.8/.10 from
> C on **every GUI event**, addressed by `xctx->top_path` — so they hit the
> viewer's own copy and every mouse move would undo the change, silently, with no
> error. `ase::ui::select_on_design` already fought this and pays an 80 ms
> re-assert pump for it. Do not sign up for a second one.

**Do** — the viewer owns its own bar, copying the shipped `wvreadout` pattern
verbatim (`wave_viewer.tcl` ~480-497 and ~3252-3317):
1. `catch {pack forget $top.statusbar}` beside the existing
   `catch {pack forget $top.toolbar}` (~455) — per-window, never touching the
   global;
2. a `frame $top.wvstatus` with themed labels next to the `wvreadout` frame;
3. packed `-side bottom -fill x -before $top.drw` (the rule `readout_show` uses,
   so it does not squeeze the canvas);
4. one `wviewer::status_refresh` write proc, modelled line-for-line on
   `readout_refresh`, **including its never-throw `catch` discipline**;
5. teardown needs nothing — the `<Destroy>` bind already calls `wviewer::forget`.

**10(a) plot mode — EASY.** Read `wviewer::plot_mode $token` (~1671), falling back
to `default_plot_mode` on `{}` the way `graph_props` already does. **Push** a
refresh from the ONE mutation site, `set_plot_mode` (~1702), immediately after the
model write — it already early-returns on a no-op, so the refresh fires exactly
once per real change and covers all three entry points (the Options menu,
`ase::plot_mode_for_current`, and state restore). Today the menu label is
**pull-only** via `-postcommand`; without the push the field goes stale silently.
**⚠ Label warning**: the shipped bar already has a field literally labelled
`MODE:` (`xschem.tcl` ~14908) — that is the *netlisting* mode. Call the new one
`Plot: single` / `Plot: multi` or the window shows two contradictory MODEs.

**10(b) cursor x,y — BLOCKED on item 9.** Item 10 must **not** compute the
position; it consumes one contract item 9 owns. Recommended, in the tree's idiom:
item 9 keeps per-window Tcl mirror arrays (`::wviewer::dcx($token)` /
`dcy($token)` / an on-off flag), exactly like the existing per-window `cva`/`cvb`/
`cvr` mirrors (~227-231); item 10 formats them with `ase::format_value`. Copy the
**measurement tooltip**'s formatting rules (`callback.c` ~905-936 — same job, same
per-motion cadence, already handles logx/logy, unit suffixes and the digital
y remap); do **not** copy its toplevel.

**Test seam**: split the **formatting** from the **widget**. A pure
`wviewer::status_text {mode x y}` returning the string is assertable under
`--nogui` with no DISPLAY; the widget half is DISPLAY-gated `cget -text`
(precedent: `test_wave_viewer.tcl` ~824-832 already reads `wvreadout` back).

---

## Recommended order

1. **4** (easiest, self-contained, proves the binding+logging shape)
2. **5** (same shape, more model work) — needs D-C, D-D
3. **1** (isolated C, no gesture risk) — needs D-G
4. **2** → **3** (same subject; 2 defines the knob 3 toggles) — needs D-A, D-B
5. **9** (unblocks 10; also builds the getter 10 needs)
6. **10** — after 9
7. **7** → **8** (7 pays the RMB plumbing cost; 8 is then nearly free) — needs D-F
   — **7 DONE 2026-07-29.** The plumbing 8 inherits: `btn3_filter`'s press
   record + **zero**-travel test, the modifier and marker-arm refusals,
   `trace_menu_build`/`_post`/`_unpost`. What 8 still owes: its own gate (empty
   space instead of a trace), `split_graph_in_graphs`, and the insert-twin of
   `index_after_removal` that item 7 turned out not to need (correction (2)).
8. **6** last (pure polish, highest pixel risk, lowest user cost if deferred) — needs D-E
