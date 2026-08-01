# ovb01 item 05 — multi-trace drag to a strip — decision doc

**Status: IMPLEMENTED (2026-08-01).** Scouted, then built and committed on
`fluid-editing`; see
`doc/claude/overnight_batch_2026_08_01/receipts/05_multi-trace-drag-to-strip.md`
for the receipt and `doc/claude/issues/0192-multi-trace-drag-to-strip.md` for the
issue write-up. Verdict **[E]** — §11's eyeball list is non-empty by design (the
shrink is pure pixels).
⚠ **A FIXUP COMMIT FOLLOWED**, after an adversarial review of `5648fe6f` found
**D-44 not implemented** in the one case where the destination is the strip the
PRESS landed on — the code refused the whole gesture on `$to == $from`, this
document claimed the opposite, and no leg covered it. The clause is now
implemented (`wviewer::movable_pairs`), not re-negotiated; see the ⚠ block in
D-44, spec §19.1.2, and the fixup section of the receipt. The same fixup closed
a fixture gap the review named: the `MM*` gesture fixture carried no vec-less
trace, so NODE index == MODEL index in every `MM` leg and the end-to-end
`trace_at -> trace_index_of_node -> selection_pairs -> move_traces` chain would
have passed with a broken mapping. **Measured, both ways:** with
`selection_pairs` sabotaged to use the node index as a model index, the
committed suite is `ALL PASS (381)` and the fixed-up one is `13 FAILED (384)`.

Three notes where implementation refined this document, all recorded in the
receipt: (i) §7's *"SAB-4 kills MV-8 and only MV-8"* is unachievable given the
`MV1` the prompt specifies — `MV1` itself moves two traces out of one source, so
every such leg dies with the term; (ii) `SAB-9` (descending fold) is likewise
louder than predicted, because on a 0-and-2 fixture the second adjusted index
goes negative and the move is REFUSED, so arrival-count legs die alongside the
order legs; (iii) `SAB-6`'s named behavioural target (`DM2`) cannot see it — the
`gi` half of `graph_preview_has()` affects pixels only — so it is pinned at
SOURCE level inside `DM6` instead, where it kills exactly one check.
Original scouting header: RESOLVED — PROCEED, against `fluid-editing` at
`e516cc85`. Every spec hole in
`doc/claude/overnight_batch_2026_08_01/PLAN.md` § "05 multi-trace-drag-to-strip"
is decided below (D-41 … D-60; the numbering continues item 04's D-25…D-40).
Implementation prompt:
`doc/claude/overnight_batch_2026_08_01/prompts/05_multi-trace-drag-to-strip.md`.
Issue to open: `doc/claude/issues/0192-multi-trace-drag-to-strip.md`.
Spec home: `doc/claude/specs/waveform_viewer_modes.md` **§19** (new), plus a
revision block in `doc/claude/specs/waveform_viewer.md`'s item-6 section.

**Verdict rationale.** This is an *additive extension of two shipped features*,
not a data-model rewrite. The selection SET already exists (issue 0175), the
trace drag already exists (§13), the shrink preview already exists (viewer plan
item 6) and the multi-object one-undo-point / one-log-line shape already exists
(`delete_items`, issue 0176). The new work is: a plural fold over the shipped
pure move, a plural arm for the shipped preview, and the plumbing to carry a set
of pairs from the press to the drop. No defer trigger fired — in particular the
drag state machine *can* carry a set (D-46).

---

## 1. The user's ask, verbatim

> When multiple traces are selected, an LMB-press-and-drag with press on/near one
> of the traces, and drag to a destination strip will cause all selected traces to
> be moved to the destination. All selected traces being moved will display the
> cool-factor shrink during the press-and-drag

---

## 2. What exists today — verified anchors

Every line number below was read from source on 2026-08-01. They drift: grep the
symbol, confirm the line says what this table claims, then edit.

### 2.1 The trace drag between strips (spec §13) — shipped

| file:line | symbol | what it does |
|---|---|---|
| `src/wave_viewer.tcl:2973` | `strip_drag_press` | re-targets, forwards the press to C **verbatim**, then decides what to arm |
| `:3000` | `marker_grabbed` rung | a marker press belongs to C for the whole gesture |
| `:3011` | `axis_grabbed` rung | issue 0190's axis drag belongs to C |
| `:3015-3021` | the trace-zone rung | `trace_at` >= 0 → cursor grab wins, else `trace_drag_arm` |
| `:4091` | `trace_drag_arm` | stores `tdrag_gi`/`tdrag_ti`/`tdrag_to`/`tdrag_x0`/`tdrag_y0`, sets the `hand2` pointer **on the press** |
| `:4168` | `trace_drag_motion` | 3-px threshold, then arms the preview **once**, then follows the pointer with `strip_at_pixel` and repaints `reorder_handle=4` |
| `:4205` | `trace_drag_drop` | `!active || to < 0 || to == from` → commit nothing, log nothing; else one `move_trace` |
| `:4062` | `trace_drag_reset` | preview down FIRST, then the frame, then clear, then restore the pointer |
| `:3272` | `move_trace_in_graphs` | **PURE**: the list move + marker migration + selection remap + empty-destination range blanking |
| `:3357` | `move_trace` | THE mutation. validate → `from_gi == to_gi` returns silently → verified `switch_ctx` → `capture_live_graph_state` → `push_undo` → pure move → target in place → **one** `regenerate` → **one** `log_action` |
| `:381-391` | the `tdrag_*` arrays | per-window transient drag state, created in `open` |
| `:526-529` | `forget` | unsets them |

### 2.2 The selection SET (issue 0175) — shipped

| file:line | symbol | what it does |
|---|---|---|
| `src/xschem.h:434` | `GRAPH_MAX_SEL_WAVES 64` | per-strip cap, FIXED array (six local `Graph_ctx` call sites) |
| `src/xschem.h:1183-1190` | `Graph_ctx.sel_wave[]`, `n_sel_waves` | the in-memory set |
| `src/draw.c:2925` | `wave_is_hilighted(gr, wcnt)` | **THE** draw-side predicate; 11 former bare comparisons go through it |
| `src/draw.c:2945/2994/3040` | `graph_sel_waves_get/set/toggle` | the ONLY C readers/writers of the `hilight_wave` + `sel_waves` token pair |
| `src/wave_viewer.tcl:3216/3228` | `model_sel` / `model_sel_set` | the model-side mirror; `sel_waves` emitted only at size >= 2 |
| `:3240` | `remap_sel_after_trace_move` | per-element remap for a MOVE |
| `:4010` | `selected_waves {wp gi}` | the live per-strip set, read off the RECT |
| `:4950-4958` | the loop in `delete_selection_at` | the only place that folds `selected_waves` across every strip into MODEL `{gi ti}` pairs |

### 2.3 The mid-drag shrink preview (viewer plan item 6) — **already shipped**

This is the largest correction to PLAN.md's notes (see §9).

| file:line | what |
|---|---|
| `src/xschem.h:1763-1774` | the `xctx->graph_preview_scale` / `_gi` / `_wave` block. `scale == 0.0` is the ARM and is the free `calloc` default |
| `src/xschem.h:1231-1237` | `Graph_ctx.preview_wave` — a NODE index, written by `draw_graph`, not from a prop token |
| `src/draw.c:3823` | `gr->preview_wave = -1;` in `setup_graph_data`, **above** the `RECT_OUTSIDE` return at `:3899` (shared `graph_struct`, landmine 11) |
| `src/draw.c:3548-3553` | the ONE draw-side comparison: `!digital && gr->preview_wave == wcnt && xctx->graph_preview_scale != 0.0`; centre is the **mean** of `S_Y(gy1)`/`S_Y(gy2)` (landmine 3) |
| `src/draw.c:3588` | the Y scale, applied **before** the rail clamp |
| `src/draw.c:3605-3614`, `:3666-3670` | the X scale: saved, scaled in place, restored verbatim from the saved shorts |
| `src/draw.c:7222-7234` | the arming in `draw_graph`: `(flags & 16) && has_x && scale != 0.0 && i == graph_preview_gi` — bit 16 is chrome, stripped from every export |
| `src/scheduler.c:10612-10635` | `xschem set graph_preview <gi> <ni> <scale>` \| `... 0` to disarm |
| `src/scheduler.c:4099-4112` | `xschem get graph_preview` → `<gi> <ni> <scale>` or the single word `0` |
| `src/wave_viewer.tcl:4129` | `wviewer::drag_shrink` — the knob. `::wviewer_drag_shrink`, **default 0.7** (a 30 % shrink), rc-overridable, out-of-range falls back |
| `src/wave_viewer.tcl:4143/4159` | `drag_preview_arm {token gi ti}` / `drag_preview_clear {token}` |
| `src/actions.c:1935-1937`, `src/xinit.c:686-688` | the two resets |
| `tests/headless/test_wave_drag_preview.tcl` | 46 checks, DP\*/DN\*/DV\*/DG1-DG7 |

It shrinks in **both** X and Y — the review of 2026-07-29 rejected the Y-only
10 % version on sight and the fix is shipped
(`doc/claude/specs/waveform_viewer.md`, "Mid-drag shrink preview").

### 2.4 The multi-object gesture shape (issue 0176) — shipped, and the template

`wviewer::delete_items` (`:4786`) is the worked example of "N objects, ONE
gesture": validate LOUDLY, refuse a no-op **without logging**, verified
`switch_ctx`, `capture_live_graph_state`, **one** `push_undo`, the pure
transform, target remapped in place, **one** `regenerate`, **one** log line whose
indices are the *normalised* ones so a replay reproduces this run exactly.
`delete_in_graphs` (`:4690`) removes highest-index-first so every logged index is
in the pre-mutation space (0176 D6).

### 2.5 Measured baselines (2026-08-01, `GUI_GATE=0`, under `$DISPLAY`)

```
tests/headless/test_wave_drag_preview.tcl   ALL PASS (46 checks)
tests/headless/test_wave_trace_menu.tcl     ALL PASS (323 checks)
tests/headless/test_wave_viewer.tcl         ALL PASS (368 checks)
tests/headless/test_wave_modes.tcl          ALL PASS (433 checks)
```

Build green (`make` → "Nothing to be done"), `./src/xschem --version` →
`XSCHEM V3.4.8RC`.

---

## 3. The design

Three layers, each an extension of a shipped one. Nothing is rewritten.

### 3.1 The moving SET is decided at PRESS time

`trace_drag_arm` gains one job: after it has picked the trace, it asks whether
that trace is **in the live selection**. If it is, the moving set is the whole
window-wide selection; if it is not, the moving set is that one trace (D-41).
The answer is stored in a new per-window array `tdrag_pairs($token)` as MODEL
`{gi ti}` pairs (landmine 34 — `selected_waves` answers in NODE space and must go
through `trace_index_of_node`).

Press time, not drop time, for two reasons and both are load-bearing:

* the shrink preview arms at the 3-px threshold and needs the set then;
* the release is forwarded to C **before** `trace_drag_drop` runs
  (`strip_drag_release:3100`), and a no-travel release collapses the selection to
  the clicked trace (issue 0174 D3). Reading at drop time would work only because
  the drag travelled — a coincidence, not a contract.

A new reader `wviewer::selection_pairs {W}` is the ONE place that folds
`selected_waves` across every strip into MODEL pairs; `delete_selection_at` is
rewired onto it so there is exactly one such fold in the file (D-53).

### 3.2 The move: a fold over the shipped pure primitive

```tcl
wviewer::move_traces_in_graphs {graphs pairs to_gi}   ;# PURE
wviewer::move_traces           {pairs to_gi ?token?}  ;# THE mutation
```

`move_traces_in_graphs` normalises `pairs` (integers, in range, deduped, sorted
ascending by `gi` then `ti`, and **`gi == to_gi` dropped** — those traces are
already there, D-43), then folds `move_trace_in_graphs` over them in that order,
subtracting from each `ti` the number of traces already removed from the *same*
source graph:

```tcl
  foreach {gi ti} <ascending> {
    set adj [expr {$ti - $done($gi)}]
    set graphs [wviewer::move_trace_in_graphs $graphs $gi $adj $to_gi]
    incr done($gi)
  }
```

That single `- $done($gi)` term is the whole of the new index arithmetic, and it
is the target of SAB-4. Everything else — the trace dict carried whole, marker
migration, the `hilight_wave`/`sel_waves` hand-off, the empty-destination range
blanking — comes from the shipped primitive unchanged, which is exactly why this
item is not a rewrite.

Three properties fall out of the fold order and are asserted:

* **destination order = source order**, because each step appends at the end;
* **the empty-destination blanking fires exactly once**, on the first step (after
  it, `D` has traces);
* **the destination's selection grows by one appended node index per moved
  trace**, because each step recomputes `dst_ni = node_count $D` before its
  append.

`move_traces` repeats `move_trace`'s ordering contract verbatim (§13.3), with
ONE `push_undo` and ONE `log_action` for the whole gesture:

```tcl
wviewer::move_traces {{0 1} {0 3} {1 0}} 2 <token>
```

### 3.3 The drop chooses singular or plural

```tcl
  if {[llength $movable] == 1 && [lindex $movable 0] eq [list $from $ti]} {
    wviewer::move_trace $from $ti $to $token          ;# shipped, unchanged
  } else {
    wviewer::move_traces $movable $to $token
  }
```

D-42: the single-trace gesture keeps calling the shipped `move_trace` and keeps
writing the shipped log line, so the eight `TD*` assertions in
`test_wave_viewer.tcl` and every recorded action log stay valid, and PLAN's Q1
("today's behaviour, unchanged") is true by construction rather than by
inspection.

### 3.4 The preview becomes a SET — the marker-selection shape, exactly

`xctx` keeps `graph_preview_gi` / `graph_preview_wave` as the **HEAD** and gains
the whole set beside them, mirroring `graph_marker_sel` + `graph_marker_sel_set[]`
+ `graph_marker_n_sel` (`xschem.h:1728-1736`, landmine 46):

```c
#define GRAPH_MAX_PREVIEW_WAVES 64
  int graph_preview_set_gi[GRAPH_MAX_PREVIEW_WAVES];
  int graph_preview_set_wave[GRAPH_MAX_PREVIEW_WAVES];
  int graph_preview_n;        /* 0 <=> graph_preview_scale == 0.0 */
```

FIXED arrays, never pointers: `xctx` is reset, not freed (landmine 46(b)).

* **ONE writer**: `graph_preview_arm(const int *gis, const int *waves, int n,
  double scale)` in `draw.c`. It sets the set, the count, the head and the scale
  together, so the head cannot drift from element 0.
* **ONE draw-side predicate**: `graph_preview_has(int gi, int wcnt)` in `draw.c`,
  beside `wave_is_hilighted`. It returns 0 when `scale == 0.0`, so at rest it
  costs one compare.
* `Graph_ctx.preview_wave` (a node index) becomes `Graph_ctx.preview_gi` (the
  rect index this draw is chrome-enabled for, or -1). `setup_graph_data` defaults
  it to -1 at `:3823`, above the `RECT_OUTSIDE` return, exactly as today.
  `draw_graph:7230` sets `gr->preview_gi = ((flags & 16) && has_x) ? i : -1;`.
  `draw_graph_points:3548` becomes
  `if(!digital && gr->preview_gi >= 0 && graph_preview_has(gr->preview_gi, wcnt))`.
* Traces on **different** source strips each shrink about **their own** strip's
  plot-box centre, because `prev_c`/`prev_cx` are computed from the `gr` of the
  graph being drawn. No change is needed for that and none is made (D-50).

Verb surface:

| verb | shape | note |
|---|---|---|
| `xschem set graph_preview <gi> <ni> <scale> [<gi> <ni> ...]` | arm | trailing pairs are **additive**; the three-argument form is byte-identical to today |
| `xschem set graph_preview 0` | disarm | clears head, set and count |
| `xschem get graph_preview` | `<gi> <ni> <scale>` \| `0` | **unchanged** — the HEAD. All seven shipped `DV*` legs keep passing |
| `xschem get graph_preview_set` | `"gi ni gi ni …"` \| `""` | NEW. Head first. Fails soft, `Tcl_AppendElement` loop, the `graph_marker_sel_set` idiom (`scheduler.c:4062-4071`) |

Tcl:

* `wviewer::drag_preview_arm_set {token pairs}` — maps each MODEL pair through
  `node_index_of_trace`, drops the vec-less ones, issues one `xschem set
  graph_preview`.
* `wviewer::drag_preview_arm {token gi ti}` becomes a one-line wrapper over it,
  so its signature and `DN1` are unchanged (landmine 46(c) in mirror image:
  the public single form wraps the plural primitive).

### 3.5 What the user will see

Select two or three traces (plain click, then Ctrl+click — issue 0175), press on
any one of them and drag. All of them shrink where they sit, the destination
strip gains its drop frame, and on release they all land at the bottom of that
strip in the order they were in. One `u` puts them all back.

---

## 4. Collision map — every owner of an LMB press over a strip in the viewer

Read top to bottom; the first match wins. The only new row is the last one, and
it is a *refinement* of a row that already existed.

| # | condition, in `strip_drag_press` order | owner | changed? |
|---|---|---|---|
| 0 | `state & 13` (Shift/Ctrl/Alt) → `return 0` | C / `strip_bindings` | no. **Ctrl+LMB stays the selection toggle and never arms a drag** |
| 1 | `strip_at_pixel < 0` (outside every band, incl. the 5-px `waves_selected` inset) | schematic canvas | no |
| 2 | the reorder GRIP (right `GRAPH_REORDER_HANDLE_W` = 14 px, every height) | Tcl strip reorder | no — unconditional first refusal |
| 3 | `marker_grabbed` | C marker anchor/label drag | no |
| 4 | `axis_grabbed` (issue 0190 margins) | C axis zoom | no |
| 5 | `trace_at >= 0` **and** `cursor_grabbed` | C cursor drag | no |
| 6 | `trace_at >= 0` | Tcl trace drag | **YES — this row now carries N traces instead of 1** |
| 7 | anything else in the band | Tcl strip reorder | no |

Two further collisions, both pre-existing and both *deliberately left alone*:

* **A plain click on a selected trace COLLAPSES the multi-selection** to that one
  trace (§15.1 rule 2, issue 0174 D3). So the user must press-and-drag; a click
  first then a drag moves one trace. This is shipped behaviour, it is the same
  behaviour Delete has, and this item does not touch the C click arm.
* **The sub-threshold press-release is still the wave-bold click.** The drag
  arms on the press but commits nothing below 3 px, so the shipped
  `TD4`/`MM9` behaviour is untouched.

---

## 5. Resolved spec holes

PLAN.md's recommended answer is taken unless source contradicts it; each entry
says which.

### D-41. Press on a trace that is NOT in the selection.
**Recommendation taken.** Drag that trace alone; today's behaviour exactly. The
selection is **not** extended at press, and it is **not** cleared either — the
gesture simply ignores it.
*Rationale:* the user's sentence is conditional ("When multiple traces are
selected, an LMB-press-and-drag with press **on one of them**"). Silently
extending a selection on a press is the class of surprise issue 0174 D3 already
ruled against for clicks.
*Rejected:* (a) always move the selection (a press on an unrelated trace would
teleport traces the user was not touching); (b) collapse the selection to the
pressed trace at press time (destroys a selection the user built for a different
purpose, and the release-side C arm already does this for a *click*).

### D-42. Which mutation does the drop call?
**Source-driven refinement of the recommendation.** `move_trace` (singular,
shipped) when the moving set is exactly the pressed trace; `move_traces` (new)
otherwise.
*Rationale:* `wviewer::move_trace 0 0 1 <tok>` is a **replay contract** — it is
what the action log records, `TD1`/`TD2`/`TD7` assert it verbatim, and
`test_wave_modes.tcl` `MG15` drives it. Routing the single case through a new
verb would rewrite that line for no behavioural gain and break replay of every
log already on disk. Keeping both is ~4 lines.
*Rejected:* one verb for both (breaks the shipped log line and 8+ assertions);
`move_trace` delegating to `move_traces` (it would then have to suppress the
inner log line and fake the outer one — more code, not less).

### D-43. The selection spans several SOURCE strips.
**Recommendation taken.** Move **all** of them to the destination.
*Rationale:* the user wrote "all selected traces". `move_trace_in_graphs` is
already per-`(from_gi, from_ti)`, so a fold needs no new model concept.
*Rejected:* moving only the traces from the pressed strip (arbitrary, and
invisible to the user until traces go missing from the drop).

### D-44. The destination is one of the source strips.
**Recommendation taken.** Traces already on the destination stay exactly where
they are (they do not get re-appended and their indices do not change); the
others move in. A drop where **nothing** would move mutates nothing and logs
nothing.
*Rationale:* the shipped `from_gi == to_gi` rule (§13.3) says a drop on the
source is not a state change; applying it per pair is the same rule. Re-appending
would reorder a strip the user did not ask to reorder.
*Rejected:* re-appending same-strip traces so the whole selection ends up
contiguous at the bottom (a hidden reorder — §12's first sentence says a strip's
internal trace order is never touched by a drag).

⚠ **AND THE PRESSED STRIP IS NOT AN EXCEPTION** — this clause covers the case
where the destination is the strip the PRESS landed on, not merely "some other
source strip". Pressing a trace on strip 0 with the selection also holding a
trace on strip 1, and releasing back over strip 0, moves strip 1's trace IN and
leaves strip 0's where it is.

`5648fe6f` **did not implement that**: `trace_drag_drop` refused on
`!$active || $to < 0 || $to == $from` **before** the `movable` filter ran, so the
`$to == $from` term short-circuited the whole gesture and the drop committed
nothing and logged nothing. It was invisible to the suite — `MM8` is the
all-on-one-strip case (nothing could move anyway) and `MM6` drops on strip 1,
never on the pressed strip — and the deviation was recorded nowhere, so the
design doc of record and the shipped code contradicted each other.

**Fixed in this item's fixup commit** (direction (a): implement the clause).
`movable_pairs` — a new PURE predicate — is now the single answer read by the
drop, by the refusal and by the `reorder_handle=4` frame; only `!$active` and
`$to < 0` still refuse outright, and the single-strip selection the `to == from`
term was standing in for is already a no-op through an empty `movable`.
`trace_drag_arm` starts `tdrag_to` at `-1` instead of the pressed index, so the
first motion inside the pressed strip is a real destination change and paints
the frame. Legs: `MV13` (`test_wave_modes.tcl`, the predicate — 9 checks),
`MM14` (`test_wave_trace_menu.tcl`, the end-to-end drop plus both frame states)
and `MM8` (extended with the negative frame leg). Spec: §19.1.2, new.

### D-45. Order in the destination.
**Recommendation taken.** Appended at the end, in **source order** = ascending by
`(gi, ti)`, keeping expr / alias / vec / colour.
*Rationale:* it is the shipped single-trace rule applied N times, it is
deterministic (so the log line replays identically), and it preserves the reading
order of the stack.
*Rejected:* pick order (there is none — a selection is a set, not a history);
pressed-trace-first (privileges an accident of where the pointer landed).

### D-46. Can the drag state machine carry a set, or is this a rewrite?
**Source says it can — no DEFER.** One new per-window array `tdrag_pairs`
alongside the five that already exist (`:381-391`), created in `open`, unset in
`forget` (`:526-529`), zeroed by `trace_drag_clear`.
*Rationale:* the state machine already carries `(gi, ti)`; carrying a list of
them changes no control flow. The mutation layer already has the N-object shape
(`delete_items`). The defer trigger in PLAN.md ("if the drag state machine cannot
carry a set without being rewritten") did not fire.

### D-47. What is the "cool-factor shrink", and what is left to build?
**PLAN.md is out of date here (see §9).** The shrink is shipped, both-axes, at
`::wviewer_drag_shrink` default **0.7**, rc-overridable, bit-16 chrome, with a
46-check suite. What this item builds is the **plural** form: the arm takes a set
of `(gi, node)` pairs instead of one.
*Decision:* **do not change the shrink factor, the shrink maths, or the knob.**
The value was tuned by the user's own eyeball on 2026-07-29 ("bump up the shrink
to 30 %"); re-tuning it for a bundle is an eyeball question, listed in §11.
*Rejected:* a second constant for the multi case (two knobs for one effect is
exactly the drift landmine 45(a) describes); scaling the shrink by the number of
traces (unrequested, and unassertable).

### D-48. Where does the multi-preview state live?
**The `graph_marker_sel` shape.** Head scalars unchanged + a FIXED set array +
a count, ONE writer, ONE predicate.
*Rationale:* landmine 46 is explicit that this is the pattern and that a fixed
array is required because `xctx` is reset rather than freed. Keeping the head
means `xschem get graph_preview` and all seven shipped `DV*` legs are
byte-identical.
*Rejected:* (a) replacing the scalars with the array only — churns the shipped
getter and its tests for nothing; (b) an array in `Graph_ctx` instead — six call
sites build a local `Graph_ctx`, and the set is window-wide, not per-graph, so it
would have to be recomputed per graph per draw; (c) a prop token — the preview is
transient chrome, and a token would persist, paste and export (landmine 19 /
graph_markers.md §3.5).

### D-49. The `Graph_ctx` field.
`preview_wave` (a node index) → `preview_gi` (the rect index this draw may
preview, or -1). Defaulted to -1 at `setup_graph_data:3823`, **above** the
`RECT_OUTSIDE` early return, exactly as today (landmine 11: `gr` is the shared
`xctx->graph_struct` and a stale value leaks onto the next graph).
*Rationale:* the per-graph question ("is this graph previewing at all") stays in
`Graph_ctx`; the per-trace question ("is this node in the set") moves to the one
predicate. That keeps `draw_graph_points` free of the set walk when nothing is
armed and keeps exactly ONE comparison site.
*Note the memset trap:* a locally-built `Graph_ctx` is `memset` to 0, so
`preview_gi == 0` is a *valid* index. It is safe only because every local goes
through `setup_graph_data` and `draw_graph_points` is reached solely from
`draw_graph` (`:7506`, `:7556`). The source-level leg `DM6` pins that there is no
second comparison site.

### D-50. Traces on different source strips — where do they shrink to?
**Each shrinks about its OWN strip's plot-box centre, in place.** No change to
`draw_graph_points`' centre computation.
*Rationale:* `prev_c`/`prev_cx` come from the `gr` of the graph currently being
drawn, so this is free. The alternative — gathering the moving traces visually at
the pointer — is a new rendering path (a floating overlay), which is a different
feature and would put chrome outside its own rect's bbox clip.
*Rejected:* a pointer-following ghost. Recorded in §11 as an eyeball question and
in §10 as a possible follow-up.

### D-51. Does the source strip survive being emptied?
**Recommendation taken.** Yes — unchanged. Deleting it would renumber the stack
behind the user's back and lose its axis settings (§13.1). Tidying is bare `e`.

### D-52. The selection after the move.
**Recommendation taken, and it is free.** The selection follows the traces: each
moved trace joins the destination's set at its appended node index, the source's
remaining selection shifts past each hole, and an unrelated destination selection
survives. All of that is `move_trace_in_graphs`' shipped behaviour repeated.
*On PLAN's warning about `remap_hilight_after_trace_move` returning `{}` for two
reasons:* source shows the shipped caller already avoids it — `moved_was_bold` is
computed independently at `:3303` rather than inferred from an empty return, and
`remap_sel_after_trace_move` (`:3240`) is already the SET form. This is an
invariant to **preserve**, not new work.

### D-53. Who reads the live selection?
**One reader.** New `wviewer::selection_pairs {W}` returns window-wide MODEL
`{gi ti}` pairs; `trace_drag_arm` and `delete_selection_at` both call it.
*Rationale:* landmine 43/46(a) — two folds of the same state drift, and the drift
is invisible to any test that exercises one path. The extraction is ~8 lines
moved and behaviour-identical.
*Rejected:* a second inline loop in `trace_drag_arm` (the shipped bug shape).

### D-54. Undo.
**Recommendation taken.** ONE `wviewer::push_undo`, immediately after
`capture_live_graph_state`, so a single `u` restores every trace **and** the
mouse-written pan/zoom/bold. Precedent: `delete_items` (0176 D5) and landmine
46(c) ("a multi-object delete owes exactly ONE undo point — split the primitive,
never loop the public form"). Here the equivalent rule is: the fold runs on the
**pure** layer, so no intermediate state is ever snapshotted.
*Rejected:* one undo point per trace (SAB-2 is exactly this).

### D-55. Empty destination ranges.
**Recommendation taken.** Blanked to `{}` (auto) on the drop so `regenerate`
re-autozooms; a destination that already holds traces keeps its window. This is
landmine 34(a) and it is shipped — the fold gets it for free, and only on the
first step. SAB-3 removes it.

### D-56. Escape / sub-threshold click / drop outside every strip.
**Recommendation taken.** All three commit nothing and log nothing, and all three
must take the shrink preview down. `trace_drag_reset` (`:4062`) already clears
the preview **before** the frame repaint, deliberately; the plural arm must not
change that order.

### D-57. The log line.
**Recommendation taken.** `wviewer::move_traces {{0 1} {0 3} {1 0}} 2 <token>` —
the **normalised** pairs (deduped, ascending, `gi == to_gi` dropped), by explicit
index, plus the explicit token. Selection state does not exist at replay time
(§15, 0175 D8), and the normalised list is what was actually applied (0176 D6).
*Rejected:* logging the raw press-time list (a replay would re-derive a different
move if a pair was dropped); logging N `move_trace` lines (N undo points on
replay, and it would contradict D-54).

### D-58. Which suites?
Three, each the honest home of what it asserts:

| suite | new group | arms | why there |
|---|---|---|---|
| `tests/headless/test_wave_modes.tcl` | `MV*` | **both** | it already owns `M7`/`M8`/`DT*`, the PURE list/index math on literal dicts. `M9` is TAKEN (issue 0173) |
| `tests/headless/test_wave_drag_preview.tcl` | `DV8+`, `DM*` | verb legs both arms, gesture legs DISPLAY | it owns `graph_preview` and the shrink |
| `tests/headless/test_wave_trace_menu.tcl` | `MM*` | DISPLAY | **the only suite with a live multi-trace strip** built hermetically (`xschem raw new`/`raw add`, no ngspice) and with the shipped Ctrl+click selection legs (`TS*`) |

`test_wave_viewer.tcl`'s `TD*` fixture is **one** trace plus **one empty** strip
and cannot host a multi-selection; it stays as the single-trace regression
witness (D-42's teeth). No new suite file, so no `full_audit.sh` registration
change (it globs `test_*.tcl`).

### D-59. Cap and truncation.
`GRAPH_MAX_PREVIEW_WAVES 64`, matching `GRAPH_MAX_SEL_WAVES`. An over-long set
truncates the **preview only** — the move itself is uncapped, so the worst case
is that the 65th carried trace is drawn full size. Documented at the `#define`
and asserted (`DV11`).
*Rationale:* a preview is chrome; refusing the gesture because the bundle is
large would be a functional regression caused by a cosmetic limit.
*Rejected:* a dynamic allocation (landmine 46(b): `xctx` is reset, not freed).

### D-60. Cursor.
**Recommendation taken.** The shipped `hand2` grab hand, set on the PRESS
(`:4107`), unchanged for any number of traces. No second affordance.

---

## 6. Formulas and invariants the suite asserts numerically

Let the pre-move model be `graphs`, the normalised moving list be
`P = [(g0,t0), (g1,t1), …]` ascending by `(gi, ti)` with every `gi != to`, and
`done(g)` the count of members of `P` already moved from graph `g`.

1. **The index adjustment.** Step `k` calls
   `move_trace_in_graphs graphs gk (tk - done(gk)) to`.
   *Witness:* moving model indices **0 and 2** of a 4-trace strip must leave the
   traces that were at 1 and 3 — moving 0 and 1 cannot tell a correct fold from
   one with no adjustment. (`MV`-8, SAB-4.)
2. **Destination content.** `traces(to)` afterwards =
   `traces(to)_before ++ [trace(g0,t0), trace(g1,t1), …]`, each dict
   **byte-identical** to its source dict.
3. **Source content.** For each source `g`, `traces(g)` afterwards = the original
   list with exactly the members of `P` removed, order preserved.
4. **Selection.** `model_sel(to)` afterwards =
   `remap of model_sel(to)_before` (unchanged — nothing left `to`)
   `∪ { node_count(to)_before + j : j = 0 … |P|-1 }`.
   For each source `g`: `model_sel(g)` afterwards = every previously selected node
   of `g` that was **not** moved, each decremented by the number of moved nodes of
   `g` strictly below it.
5. **Ranges.** `to` had no traces before ⇒ its `x1 x2 y1 y2` are `{}` afterwards.
   `to` had traces ⇒ all four are byte-identical to before. (SAB-3.)
6. **Markers.** A marker on a moved trace migrates to `to` at that trace's new
   node index; markers above a hole in a source shift down by the number of moved
   nodes below them; no `prev` is left dangling window-wide.
7. **One of each.** `history_depth` moves by exactly 1; exactly one
   `log_action` line; exactly one `regenerate`; the target ends as `to` with
   **no** separate `set_target_strip` log line.
8. **Preview.** After the 3-px threshold,
   `xschem get graph_preview_set` = `{g0 n0 g1 n1 …}` where `nj` is
   `node_index_of_trace` of pair `j`, head first; and
   `xschem get graph_preview` = `{g0 n0 <shrink>}` — byte-identical in shape to
   the single-trace case.
9. **The preview is visual only.** `xschem get graph_trace_at` answers at a swept
   column are identical with and without a MULTI preview armed (DG4 for N).

---

## 7. Sabotage plan — each must kill EXACTLY its target and nothing else

| id | sabotage | must kill | must LEAVE GREEN |
|---|---|---|---|
| **SAB-1** | in `trace_drag_drop`, always call `move_trace $from $ti $to` (ignore the set) | `MM1`, `MM5` | `MM7` (the unselected-press leg), all `TD*` |
| **SAB-2** | in `move_traces`, move `push_undo` inside the fold (one per pair) | `MM3`'s depth leg | `MM3`'s content leg |
| **SAB-3** | in `move_traces_in_graphs`, force the destination to look non-empty so the range blanking never fires | `MM11`, `MV`-6 | everything else |
| **SAB-4** | drop the `- $done($gi)` term in the fold | `MV`-8 | `MV`-1 (single source, single trace) |
| **SAB-5** | `drag_preview_arm_set` arms only `[lindex $pairs 0]` | `DM1`, `DM2` | `DV8` (the verb round-trip), `DG1` |
| **SAB-6** | `graph_preview_has` ignores its `gi` argument (membership by node only) | `DM2` (cross-strip) | `DM1` (same strip) |
| **SAB-7** | `trace_drag_arm` takes the selection unconditionally, even when the pressed trace is not in it | `DM3`, `MM7` | `MM1` |
| **SAB-8** | `move_traces` logs one line per pair | `MM4` | `MM1` |
| **SAB-9** | the fold sorts descending instead of ascending | `MM1`'s order leg, `MV`-2 | `MM1`'s arrival-count leg |

Procedure for each: apply → run the suite → confirm it fails **exactly** its
named target → `git diff <file>` confirms the file holds nothing but the sabotage
→ `git checkout -- <file>` → clean re-run green.

**SAB-1 is the one that matters most.** If it also kills `MM7`, then `MM7` is not
actually driven from an unselected trace and D-41 is untested.
**SAB-5 must leave `DV8` green** — if the verb leg dies too, the verb leg is
accidentally testing the Tcl arm rather than the C storage.

---

## 8. Files this item touches

```
src/xschem.h                                        GRAPH_MAX_PREVIEW_WAVES, the xctx set
                                                    fields, Graph_ctx.preview_gi, two prototypes,
                                                    and the graph_preview_clear() comment drift (§9.6)
src/draw.c                                          graph_preview_arm(), graph_preview_has(),
                                                    the one comparison at :3548, the arm at :7230
src/scheduler.c                                     set graph_preview trailing pairs,
                                                    get graph_preview_set
src/actions.c                                       clear_drawing(): reset graph_preview_n
src/xinit.c                                         alloc_xschem_data(): reset graph_preview_n
src/wave_viewer.tcl                                 selection_pairs, tdrag_pairs, trace_drag_arm,
                                                    trace_drag_motion/clear/reset, trace_drag_drop,
                                                    drag_preview_arm_set, move_traces_in_graphs,
                                                    move_traces, delete_selection_at rewire
tests/headless/test_wave_modes.tcl                  MV* (both arms)
tests/headless/test_wave_drag_preview.tcl           DV8-DV12, DM1-DM6
tests/headless/test_wave_trace_menu.tcl             MM0-MM12
doc/claude/specs/waveform_viewer_modes.md           §19 (new) + §15.1 rows + §13 cross-ref
doc/claude/specs/waveform_viewer.md                 item-6 section: the plural revision
doc/claude/code_analysis/waveform_subsystem_reference.md   landmine 49, §8, §9, §13
doc/claude/issues/0192-multi-trace-drag-to-strip.md  new
```

**Not touched:** `src/callback.c` (no C gesture changes — the press/release
routing is unchanged), `graph_wave_at`, `graph_trace_at`,
`GRAPH_TRACE_PICK_TOL`, the C click arm, `move_trace`, `move_trace_in_graphs`,
`move_trace_to_new_strip`, `delete_items`, `drag_shrink`.

---

## 9. Claims in PLAN.md / the tree that source refutes

1. **"What is the 'cool-factor shrink'? → … Put the magnitude behind ONE named
   constant so it is a one-line tune at eyeball time … the equivalent viewer-plan
   item 6 was specified Y-only at 10 % and the user rejected it on sight."**
   The shrink is **already shipped and already fixed**: `draw_graph_points`
   (`draw.c:3548-3614`, `:3666-3670`) scales **both** X and Y about the plot-box
   centre; the magnitude is already one knob, `::wviewer_drag_shrink`
   (`wave_viewer.tcl:4129`), default **0.7**, rc-overridable with a documented
   fallback; it is already `flags & 16` chrome; and it already has a dedicated
   46-check suite, `tests/headless/test_wave_drag_preview.tcl`. The 2026-07-29
   rejection was acted on. **Remaining work: one trace → N.**
2. **"`src/xschem.h` (the shrink constant, mirrored in Tcl if Tcl needs it)."**
   There is no C `#define` for the shrink and there must not be: the knob is a
   **Tcl global** so an rc can set it. The only new C constant this item adds is
   the *set cap*, `GRAPH_MAX_PREVIEW_WAVES`, which is deliberately **not**
   mirrored in Tcl (Tcl reads the list, never the cap — the
   `GRAPH_MARKER_MAX_SEL` precedent).
3. **"`src/draw.c` (the shrink render + `graph_wave_at`)" as the likely draw.c
   work.** The render exists and is not edited beyond its one comparison;
   `graph_wave_at` (`draw.c:5851`) is not touched at all — the pick already
   returns the node index the arm needs.
4. **"`remap_hilight_after_trace_move` returns `{}` for two different reasons and
   the caller must test which, or an unbolded move silently bolds something in
   the destination."** True of the helper, but the shipped caller already handles
   it: `move_trace_in_graphs` computes `moved_was_bold` independently
   (`wave_viewer.tcl:3303`) and `remap_sel_after_trace_move` (`:3240`) is already
   the SET form. This is an invariant to preserve, not a defect to fix.
5. **"extend the `TD*` block in `tests/headless/test_wave_viewer.tcl` … Carry the
   inert `sdid` per-strip key."** `sdid` is already there
   (`test_wave_viewer.tcl:1884-1886`), but that fixture is **one** trace on strip
   0 and an **empty** strip 1 — it cannot host a multi-selection. The multi-trace
   fixture is `test_wave_trace_menu.tcl`'s `fill_viewer` (`:406`, three traces on
   strip 0, one on strip 1). D-58 places the gesture legs there and keeps `TD*`
   as the single-trace regression witness.
6. **Tree drift, `src/xschem.h:1771`:** the comment says the preview state is
   "Reset in `graph_preview_clear()`, `clear_drawing()` and
   `alloc_xschem_data()`". **`graph_preview_clear()` does not exist** — the
   resets are inline at `actions.c:1935-1937` and `xinit.c:686-688`. Correct the
   comment while editing that block.
7. **Doc drift, `doc/claude/specs/waveform_viewer.md`:** its item-6 section says
   `setup_graph_data` defaults `gr->preview_wave` before the `RECT_OUTSIDE`
   return — that one is **correct** (`draw.c:3823` vs `:3899`), verified, listed
   here only because it was checked and must stay true of the renamed field.

---

## 10. Out of scope — recorded, not fixed here

* **A pointer-following ghost of the carried traces** (D-50). The shrink happens
  in place, per source strip. Making the bundle visually travel with the pointer
  is a new overlay render outside each rect's bbox clip — a separate feature.
* **`find_closest_wave`'s two open `extra_rawfile` defects**
  (`draw.c:4418`/`:4445`/`:4563`, reference §12 DONE-callout item 3 and landmine
  40). Untouched by this item.
* **A `graph_preview_clear()` function** to match the header comment. The comment
  is corrected instead; adding a function for two assignments is churn.
* **Whether a plain click on a member of a multi-selection should collapse it.**
  Shipped (issue 0174 D3 / §15.1 rule 2) and reconfirmed by the user at that
  review. This item does not reopen it, but it is the most likely source of a
  "my selection disappeared" report once multi-drag exists.

---

## 11. Deliverables no assertion can reach (the eyeball list)

The move, the selection remap, the undo, the logging and the *arming* of the
preview are all fully assertable. What is not:

1. **That N traces actually render shrunk at once.** Nothing headless can read
   pixels back, and there is no seam between `S_Y()` and `XDrawLines` to spy —
   the shipped single-trace suite states this limitation for one trace and it is
   unchanged for N.
2. **Whether 0.7 is the right shrink for a BUNDLE.** It was tuned by eyeball for
   a single trace ("bump up the shrink to 30 %", 2026-07-29). Several traces
   shrinking together may read as too much or too little. One-line tune:
   `set ::wviewer_drag_shrink <0..1>`.
3. **Whether traces shrinking in place on their OWN strips reads as "I am
   carrying these"** when the selection spans several source strips (D-50). They
   do not gather at the pointer.
4. **Whether the destination frame plus N shrunk traces is legible** at the sizes
   a real viewer window uses.

Per PLAN.md's own note for this item ("**The shrink is pure pixels** — it forces
`[E]`"), the honest verdict is **`[E]`**, with item 2 above named as the tunable
the user may want to revise.
