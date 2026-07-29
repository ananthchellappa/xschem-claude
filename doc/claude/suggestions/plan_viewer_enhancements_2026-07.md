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

## ⚠ UN-EYEBALLED — auto-proceeded, review still owed

The build loop raises a review panel after each item and **auto-proceeds after
30 minutes** so an item finished at 02:00 does not stall until morning
(`doc/claude/specs/review_gate.md`). Anything that went through on the timeout
rather than on a human verdict is listed here until it has actually been
looked at. **This list is the debt; do not let it grow silently.**

| item | commit | raised | outcome |
|---|---|---|---|
| 5 — `e` deletes empty strips | `6ac7219e` | 2026-07-29 | ✅ **REVIEWED** (verdict PROCEED) |
| 1 — legend size + weight | `b36fa980` | 2026-07-29 | ✅ **REVIEWED** — rejected the all-bold half, corrected below |
| 1 correction — bold marks the selected trace only | `d40a3934` | 2026-07-29 | ⚠ **AUTO-PROCEEDED, un-eyeballed** |
| 2 — grid density | `9dea8c0e` | 2026-07-29 | ⚠ **AUTO-PROCEEDED, un-eyeballed** |

**The highest-value thing in this list**: item 2 had to modify `drawline`,
which every line drawn in the program goes through (~86 call sites). The wave
suites pass 1833 checks and X11's dash semantics make the wrapper provably
equivalent, but *"no dashed line anywhere in xschem looks different"* is a claim
the test suite structurally cannot make — there is no way to read back an X GC's
dash list. It wants one human glance at an ordinary schematic.

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

### Item 6 — mid-drag 10 % shrink preview of the dragged trace
- [ ] **6. Drag shrink preview**

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

### Item 7 — RMB context menu on a trace → "move to separate strip"
- [ ] **7. Trace context menu**

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

---

### Item 8 — RMB context menu on empty strip space → "split current strip"
- [ ] **8. Strip context menu**

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
- [ ] **9. Diamond snap cursor**

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
- [ ] **10. Viewer status bar**

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
8. **6** last (pure polish, highest pixel risk, lowest user cost if deferred) — needs D-E
