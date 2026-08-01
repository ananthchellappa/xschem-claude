# 0192 — a trace drag carries the whole selection, and shrinks all of it

**Status:** FIXED (2026-08-01)
**Branch:** `fluid-editing`. Reported as item 05 of the 2026-08-01 overnight
waveform batch.

> When multiple traces are selected, an LMB-press-and-drag with press on/near one
> of the traces, and drag to a destination strip will cause all selected traces to
> be moved to the destination. All selected traces being moved will display the
> cool-factor shrink during the press-and-drag

---

## 1. WHAT EXISTED BEFORE, AND WHAT WAS MEASURED

Two shipped features that had never been joined:

* **The trace drag** (`waveform_viewer_modes.md` §13, 2026-07-28). Press inside
  the 10-px zone around a drawn trace, drag > 3 px, drop on another strip: **one**
  trace moves. The model op `move_trace_in_graphs` is PURE and already carries
  the trace dict whole, migrates the marker on the moved trace, hands the
  `hilight_wave`/`sel_waves` selection over, and blanks an EMPTY destination's
  ranges back to auto.
* **The trace SELECTION as a SET** (§15, issue 0175). Plain click selects,
  Ctrl+click adds/removes, window-wide, stored across `hilight_wave` (the head)
  plus an optional `sel_waves` companion.

Two things were **measured** before any code was written, because the design
rests on them:

1. **The "cool-factor shrink" is already shipped** — and PLAN.md's notes for this
   item are out of date about it. `xschem set graph_preview 0 1 0.7` →
   `xschem get graph_preview` answers `0 1 0.7`, and `wviewer::drag_shrink`
   answers `0.7`. It shrinks in **both** axes about the plot box centre, it is
   `flags & 16` chrome (no export sees it), the magnitude is already ONE rc knob
   (`::wviewer_drag_shrink`, default `0.7` — the value the user asked for on
   2026-07-29), and it already has a 46-check suite. **The work was one trace →
   N, not building a shrink.**
2. **A press does not change the selection; only the no-travel RELEASE does.**
   Driven through the shipped bindings: with nodes 0 and 2 selected, a press on
   node 1 left the selection at `{0 2}`; the release collapsed it to `{1}`.
   That is what makes reading the selection at PRESS time correct — and it is
   also why reading it at DROP time would have been wrong, since
   `strip_drag_release` forwards the release to C **before** `trace_drag_drop`
   runs.

---

## 2. THE FIX

**The moving set is decided at the press.** `trace_drag_arm` asks whether the
picked trace is in the live selection: if it is, the moving set is the whole
window-wide selection; if it is not, it is that trace alone. It is stored in a
new per-window array `tdrag_pairs` as MODEL `{gi ti}` pairs.

**One reader of the live selection.** New `wviewer::selection_pairs {W}` folds
`selected_waves` across every strip into MODEL pairs (crossing NODE→MODEL space
through `trace_index_of_node`, landmine 34). `delete_selection_at` was **rewired
onto it**, so there is exactly one such fold in the file.

**The move is a FOLD over the shipped pure primitive.**
`move_traces_in_graphs {graphs pairs to_gi}` normalises (integers, in range,
deduped, ascending by `(gi, ti)`, every pair already ON the destination dropped)
and then folds `move_trace_in_graphs`, subtracting from each `ti` the number of
traces already removed from **that same source graph**. That one term is the
whole of the new index arithmetic; everything else — dict, markers, selection
hand-off, empty-destination blanking — comes along unchanged.

**`move_traces {pairs to_gi ?token?}` is the one mutation**, in `delete_items`'
N-object shape: validate loudly, refuse a no-op without logging, verified
`switch_ctx`, `capture_live_graph_state`, **ONE** `push_undo`, the pure fold,
target set in place, **ONE** `regenerate`, **ONE** `log_action` carrying the
NORMALISED pairs.

**The drop dispatches.** Exactly the pressed trace ⇒ the shipped
`wviewer::move_trace` (and its shipped log line); anything else ⇒ `move_traces`.

**What a drop REFUSES is decided by `movable_pairs`, not by `to == from`**
(added in the fixup below). The carried pairs whose `gi` is not the destination
are what moves; only an EMPTY result refuses. So a drop back on the strip the
press landed on is a normal drop when the selection spans other strips — those
traces move in and the pressed strip's own stay put (D-44) — and the
`reorder_handle=4` frame reads the same predicate, so it is lit exactly when a
release would commit.

**The shrink preview became a SET**, in the `graph_marker_sel` shape:
`graph_preview_scale`/`_gi`/`_wave` stay as the HEAD, joined by
`graph_preview_set_gi[GRAPH_MAX_PREVIEW_WAVES]` / `_set_wave[]` /
`graph_preview_n`. ONE writer `graph_preview_arm()`, ONE draw-side predicate
`graph_preview_has()`, `Graph_ctx.preview_wave` → `preview_gi` (*the rect index
this draw may preview*). `xschem set graph_preview` grew trailing pairs;
`xschem get graph_preview` is byte-identical and the set is read through the new
`xschem get graph_preview_set`. Tcl: `drag_preview_arm_set {token pairs}` is the
plural arm and `drag_preview_arm` a one-line wrapper over it.

---

## 3. THE DECISIONS THAT MATTERED

Full list D-41…D-60 in
`doc/claude/code_analysis/ovb01_05_multi_trace_drag_to_strip_decision.md` §5.
The five the user is most likely to want to revisit:

* **D-41** a press on an UNSELECTED trace drags that trace alone — the selection
  is neither extended, collapsed nor cleared;
* **D-42** the single-trace case keeps calling `move_trace` and keeps writing its
  log line, because that line is a replay contract;
* **D-44** traces already on the destination stay exactly where they are; a drop
  where nothing would move mutates nothing and logs nothing;
* **D-45** the arrivals are appended in SOURCE order (ascending `(gi, ti)`),
  because a selection is a set and has no pick order;
* **D-50** traces on different source strips shrink about **their own** strip's
  centre, in place — they do not gather at the pointer.

---

## 4. THE SOURCE-LEVEL LEG

`DM6` in `tests/headless/test_wave_drag_preview.tcl`, both arms. It counts, on
CODE lines of `src/draw.c` only (the `LS5`/`MS13` idiom):

* `graph_preview_has(` defined once, called once — the ONE draw-side test;
* **zero** surviving bare `preview_gi ==` / `preview_wave ==` comparisons;
* and, inside the predicate's own body, that the membership test matches on
  **both** `graph_preview_set_gi[k] == gi` **and**
  `graph_preview_set_wave[k] == wcnt`.

It has to be at source level: with **one** carried trace a bare comparison and
the predicate agree exactly, so no behavioural leg that drags a single trace can
tell them apart — and the `gi` term affects pixels only, so no leg of any kind
can see it. `SAB-6` (drop the `gi` term) kills exactly that one check and
nothing else in the suite.

---

## 5. FILES

```
src/xschem.h        GRAPH_MAX_PREVIEW_WAVES, the xctx set fields, Graph_ctx.preview_gi,
                    two prototypes, and the stale graph_preview_clear() comment
src/draw.c          graph_preview_arm(), graph_preview_has(), the one comparison in
                    draw_graph_points, the arm in draw_graph, the setup_graph_data default
src/scheduler.c     `set graph_preview` trailing pairs; `get graph_preview_set`
src/actions.c       clear_drawing(): reset graph_preview_n
src/xinit.c         alloc_xschem_data(): reset graph_preview_n
src/wave_viewer.tcl selection_pairs, tdrag_pairs, trace_drag_arm/clear/motion/drop,
                    drag_preview_arm_set, move_traces_in_graphs, move_traces,
                    delete_selection_at rewired onto selection_pairs
tests/headless/test_wave_modes.tcl         MV1-MV13   (both arms)
tests/headless/test_wave_drag_preview.tcl  DV8-DV12, DM0-DM6
tests/headless/test_wave_trace_menu.tcl    MM0-MM14   (display)
doc/claude/specs/waveform_viewer_modes.md  §19 (new), the §15.1 row, the §13 cross-ref
doc/claude/specs/waveform_viewer.md        the item-6 "arm is a SET" revision block
doc/claude/code_analysis/waveform_subsystem_reference.md  landmine 49, §8, §9, §13
```

**Deliberately NOT touched:** `src/callback.c` (no C gesture routing change),
`graph_wave_at` / `graph_trace_at` / `graph_near_wave` / `GRAPH_TRACE_PICK_TOL`,
`move_trace`, `move_trace_in_graphs`, `move_trace_to_new_strip`, `delete_items`,
and the shrink factor / maths / knob.

---

## 5b. EYEBALLED — PASS (2026-08-01)

Verified by the user on a real ASE waveform window: *"all working as expected.
No issues seen. Legibility OK."* That closes all four items of §6:

1. **N traces really do render shrunk at once.**
2. **`0.7` is right for a BUNDLE too.** It had only ever been tuned on a single
   trace (2026-07-29). No retune requested; the knob
   (`set ::wviewer_drag_shrink <0..1>`, read fresh per drag by
   `wviewer::drag_shrink`) stays at its default.
3. **D-50 ACCEPTED** — traces on different source strips shrinking about **their
   own** strip's centre, in place, does read as "I am carrying these". The
   rejected alternative (a pointer-following ghost of the bundle) stays rejected;
   it would be a new feature, not a tweak.
4. **Legible** at real viewer window sizes: destination frame + N shrunk traces +
   `hand2` cursor together.

The behavioural clauses were exercised in the same pass, including **D-44** — the
drop back onto the pressed strip, which was broken in `5648fe6f` and fixed in the
fixup below.

## 6. WHAT NO CHECK CAN SEE

The move, the selection remap, the undo, the logging and the *arming* of the
preview are all asserted. These are not, and this is why the item is `[E]`:

1. **That N traces actually RENDER shrunk at once.** Nothing headless reads
   pixels back, and there is no seam between `S_Y()` and `XDrawLines` to spy —
   the shipped single-trace suite states the same limitation for one trace.
2. **Whether `0.7` is the right shrink for a BUNDLE.** It was eyeballed for a
   single trace ("bump up the shrink to 30 %", 2026-07-29). Several traces
   shrinking together may read as too much or too little.
   **One-line tune: `set ::wviewer_drag_shrink <0..1>`** (rc-overridable;
   `1.0` disables the effect without disabling the drag).
3. **Whether traces shrinking in place on their OWN strips reads as "I am
   carrying these"** when the selection spans several source strips (D-50).
4. **Whether the destination frame plus N shrunk traces is legible** at the sizes
   a real viewer window uses.

---

## 7. FIXUP (adversarial review of `5648fe6f`)

**Defect: D-44 was not implemented, and the doc claimed it was.**
`trace_drag_drop` refused on `!$active || $to < 0 || $to == $from` **before** the
`movable` filter ran, so a drop back on the strip the press landed on committed
nothing and logged nothing — even with the selection spanning other strips whose
traces should have moved in. PLAN.md §05 question 3 and D-44 both say the
opposite, and the decision doc recorded no deviation. No leg covered it: `MM8` is
the all-on-one-strip case (nothing could move anyway) and `MM6` drops on strip 1,
never on the pressed strip.

**Repair (implement the clause, not re-negotiate it).**
`wviewer::movable_pairs {pairs to_gi}` is now the ONE predicate — read by the
drop, by the refusal and by the drop-target frame. `$to == $from` is gone;
`!$active` and `$to < 0` still refuse outright. `trace_drag_feedback` takes the
carried pairs instead of the press strip, and `trace_drag_arm` starts `tdrag_to`
at `-1` ("no destination decided yet") so the first motion inside the pressed
strip is a real destination change and paints the frame.

**Second defect: the `MM*` fixture had no vec-less trace**, so MODEL index ==
NODE index in every `MM` leg and the end-to-end `trace_at` → `trace_index_of_node`
→ `selection_pairs` → `move_traces` chain would have passed with a broken
mapping. `mmspec` now carries one (`-` in the spec, planted at MODEL index 1 of
strip 0). Measured both ways: with `selection_pairs` sabotaged to use the node
index as a model index, the pre-fixup suite is `ALL PASS (381)` and the fixed-up
one is `13 FAILED (384)`.

New legs: `MV13` (9 pure checks, `test_wave_modes.tcl`), `MM14` (12 checks) and
`MM8`'s three added checks (`test_wave_trace_menu.tcl`). Counts after:
`test_wave_modes` 212 / 485, `test_wave_trace_menu` 397,
`test_wave_drag_preview` 43 / 94, `test_wave_viewer` **368, unchanged** (D-42's
single-trace regression witness).
