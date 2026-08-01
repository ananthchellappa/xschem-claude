# 0189 — double-clicking a difference marker selects it AND its reference

**Status:** FIXED (2026-08-01)
**Branch:** `fluid-editing`. Reported as item 02 of the 2026-08-01 overnight
waveform batch.

> If a marker is a "difference marker" - created by pressing "d" key so that
> delta and slope are displayed, then, double-clicking the marker will select
> both this marker and the one that its deltas are derived from.

---

## 1. WHAT EXISTED BEFORE

A `d` marker's callout reads out Δx, Δy and a slope **against a partner** —
`GraphMarker.prev`, a marker NUMBER pointing backwards from the difference
marker to its reference (`graph_markers.md` §3). That partner was visible to the
renderer and to nothing else:

* `xctx->graph_marker_sel` held **one** number, `-1` = none
  (`xschem.h`), written by the single function `graph_marker_select()`
  (`draw.c`) and read by four sites that each asked *"is this marker selected"*
  with a bare `== xctx->graph_marker_sel`;
* so the pair could not be **selected** together, could not be **moved over**
  together, and `Delete` could only ever take one of them — leaving the survivor
  with a `prev` link the delete sweep then zeroed, i.e. a silently degraded
  callout;
* `graph_markers.md` §11 listed *multi-marker selection* as explicitly
  **deferred**, with the cost stated as *"making it a list turns `Delete` into a
  loop — contained, but it changes verb result shapes, so it should be decided
  before those are relied on."*

The double-click seam existed on both sides and did something else with it:
`src/xschem.tcl` synthesises `xschem callback %W -3 %x %y 0 %b 0 %s` for every
editor toplevel, and `waves_callback`'s `-3` arm opened the wave-attributes
dialog or `graph_edit_properties`; the ASE viewer bound `<Double-Button-1>` to a
bare `{break}` — *"D9: no graph props dlg"*.

---

## 2. THE FIX

**The selection becomes a SET.** `xctx->graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]`
+ `xctx->graph_marker_n_sel`, with `graph_marker_sel` kept as its **HEAD**. One
trio in `draw.c` owns the pair of fields — `graph_marker_is_selected()` (the
predicate), `graph_marker_select_set()` (the only writer),
`graph_marker_select()` (now a one-line wrapper) — plus the policy
`graph_marker_select_pair()` and a static `graph_marker_sel_drop()`.

**A double-click asks the policy.** `graph_marker_select_pair(num, gi)` resolves
`num` with `graph_marker_find()` and adds `m.prev` **only** when it is `>= 1` and
itself resolves. Two contexts drive it:

* on-canvas graph — a new rung in the existing `-3` arm (`callback.c`), tested
  **before** the wave dialog, because a marker anchor sits on a trace by
  construction and a callout is clamped inside the plot box, so without it the
  double-click reaches `graph_edit_properties`;
* ASE viewer — `<Double-Button-1>` becomes
  `{wviewer::marker_dblclick_at %W %x %y; break}`.

**`Delete` removes the whole set, as one gesture with ONE undo point.**
`graph_marker_delete()` split into a static `graph_marker_delete_1(num, push)`;
`graph_marker_delete_selected()` refuses read-only once, copies the set, pushes
undo once and calls the no-push form per member. The viewer's
`delete_selection_at` hands the whole set to `delete_items`, which already
deduped, filtered to live records and gave one undo point and one log line.

---

## 3. THE DECISIONS THAT MATTERED

| decision | why | the legs that defend it |
|---|---|---|
| **Not a prop token, at any set size.** The set lives in `xctx` and no `prop_ptr` byte changes under any selection. | `graph_markers.md` §3.5 / D9: marker selection is UI state and dies with the document — `clear_drawing()` resets it precisely so a reloaded schematic does not open with a marker mysteriously ringed. The issue-0175 trace model works because `hilight_wave` is a real per-rect **render-state** token; the marker analogue of `hilight_wave` is a session field. | `MS8` compares the WHOLE serialised buffer before/after a two-marker selection, plus `modified`; `MS-X1e` and `MS-X5` re-assert it on the two gesture paths. Sabotage `SAB-4` writes a `sel_markers=` token and kills exactly those. |
| **The immediate pair only — never the chain, never the reverse.** | *"the one that its deltas are derived from"*, singular; the callout renders one Δ block; and `prev` is a back-pointer that N deltas may share, so "select all my dependants" is a different, unasked-for feature. | `MS5` (chain M1←M2←M3: `-pair 3` gives `3 2`, and `1` is not in it); `MS6` (direction). |
| **ONE undo point for a multi-marker delete.** | A one-key gesture that needed two `u` to take back is the defect. Issue 0176 fixed the same class for the viewer's Delete. | `MS10` (one `xschem undo` restores both records across two rects) and `MS-X6` (the same on the C `Delete` KEY path). Sabotage `SAB-5` pushes per delete and kills exactly those. |
| **D9 preserved.** The viewer's `<Double-Button-1>` still `break`s **unconditionally**. | The graph-properties dialog must never appear over a read-only viewer. Forwarding `-3` to C from the viewer would let a Tcl/C hit-test disagreement open `.graphdialog` — the exact fall-through class issue 0176 closed for `Delete`. | `MS-X1d`, `MS-X1f`, `MS-X2` (`winfo exists .graphdialog` is 0 after a marker double-click AND after an empty-body one); `MS-X5`'s control (the same `-3` on an embedded graph still opens the dialog exactly once). |
| **Every verb result shape unchanged.** Every `select` form — including `-pair` and `-set` — returns the HEAD; `-none` still answers `-1`. | This is the thing §11 said to decide first, and deciding it as *no change* keeps ~27 shipped assertions and `wviewer::marker_selected` untouched. The set is read through a NEW getter, `xschem get graph_marker_sel_set`. | `MS3` asserts the return values of `select 2` and `select -none` explicitly. |
| **Selection does not log.** | Trace selection does not either (`waveform_viewer_modes.md` §15: "no dirty flag, no undo point, no log line"), and the replay-critical marker operations already name explicit numbers. Logging one and not the other is an inconsistency the next reader files as a bug. | `MS-X1e` (`llength $::mxlog` does not grow across the gesture). |
| **A plain click on a member of a MULTI selection COLLAPSES to it.** The shipped "second click on the already-selected one deselects" survives for a selection of exactly one. | Two precedents collide: markers deselect on re-click (§6.2), traces collapse and never deselect (0174 D3). Keeping the marker rule at `n_sel == 1` keeps every existing `MX` leg green; collapsing at `n_sel >= 2` is the only reading in which the click disambiguates rather than destroys — and a second click then still deselects. | the whole shipped `MX5`/`MX7`/`MX10` set stays green, which is the assertion. |
| **`Delete`'s strip-scope gate stays on the HEAD.** | The head is the marker the user acted on, and the shipped gate exists so a Delete pressed over *another* strip cannot eat a selection. Any-member-in-scope is looser than the shipped rule; per-member filtering would delete half a pair and leave a dangling `prev`, which is strictly worse. | `MS-X4` (viewer) and `MS-X6` (C key) both fire with the pointer over the head's strip and take both members. |

**No new rendering.** Both members get exactly the cue one selected marker has
always had — `waveform_viewer_modes.md` §15.4's rule that there is no separate
cue for the head of a set. **No token, no grammar change, no
`XSCHEM_FILE_VERSION` bump, no config variable.**

**Still out of scope, deliberately:** rubber-band marker selection, Ctrl+click
accumulation, chained or reverse delta selection, digital-strip markers.
`GRAPH_MARKER_MAX_SEL` is 8 purely so a future Ctrl+click needs no header edit.

---

## 4. THE SOURCE-LEVEL LEG

Four sites in the tree ask *"is this marker selected"* — the renderer
(`draw_graph_markers`), the RIGID text-drag latch (`graph_marker_press`), the
click toggle (`graph_marker_release`) and the delete's drop-from-the-set. A
surviving bare `== xctx->graph_marker_sel` renders a selected **partner** in the
unselected style, and **no behavioural leg that selects a single marker can see
it**: at `n_sel == 1` the bare comparison and the predicate agree exactly.

So `MS13` asserts it at SOURCE level, the way `test_wave_legend.tcl`'s `LS5`
does for traces: it reads `src/draw.c` and `src/callback.c`, counts on CODE
lines only, and pins the **exact** surviving set of bare HEAD readers — the
writer's own two lines in `draw.c`, and in `callback.c` the repaint-scope hint
plus the two lines of the `Delete` strip-scope gate. Sabotage `SAB-2` restores
one bare comparison in the renderer and kills `MS13` and nothing else.

---

## 5. FILES

```
src/xschem.h          GRAPH_MARKER_MAX_SEL, 2 xctx fields, 3 externs
src/draw.c            the trio + the pair policy + sel_drop + the delete split
                      + the renderer predicate
src/callback.c        the -3 arm, the rigid latch, the click toggle,
                      the empty-space deselect
src/scheduler.c       get graph_marker_sel_set; select -pair / -set;
                      delete -selected
src/actions.c         clear_drawing(): reset n_sel
src/xinit.c           alloc_xschem_data(): reset n_sel
src/wave_viewer.tcl   marker_selection, marker_dblclick_at,
                      the <Double-Button-1> bind, one line in delete_selection_at
tests/headless/test_wave_markers.tcl   MS0-MS14 (both arms), MS-X1..MS-X6
                                       (display), the MZ1 constants
doc/claude/specs/graph_markers.md                          D9/D13, 3.5, 6.1,
                                                           6.2, 7.2, 7.3, 9, 11
doc/claude/specs/waveform_viewer_modes.md                  15.1, 16
doc/claude/code_analysis/waveform_subsystem_reference.md   5, 9, landmine 46
```

---

## 5b. EYEBALLED — PASS (2026-08-01)

Verified by the user on a real ASE waveform window: *"eyeball on (2) is pass.
All ok."* This closes every item of §6, and it was the batch's **largest** blind
spot: a `graph_marker_is_selected()` bounded to the head — so that the PARTNER of
every pair renders in the unselected style — passes **all 979 DISPLAY and 437
`--nogui` checks**. No behavioural leg could reach it.

Confirmed in the same pass:

* **both members ring**, including a **cross-strip** pair, with no stale ring left
  behind (`need_all_redraw` is unobservable to any test);
* the **D-15 collapse rule** — a plain click on one member of a two-marker
  selection collapses to that member rather than clearing, and a second click then
  deselects. A sabotage that wipes the whole selection on that click also passes
  all 979 checks;
* the **rigid label-drag latch on the partner** (D11) — behaviour, not pixels, and
  inside the same blind spot, since every shipped `MX7e` leg exercises a *singly*
  selected marker;
* `Delete` takes both with **one** undo point;
* **the design judgement is ACCEPTED**: per `waveform_viewer_modes.md` §15.4 there
  is deliberately **no distinct cue for the head**, both members look identical,
  and that reads correctly as "these two go together". No new rendering was added
  and none is wanted.

## 6. WHAT NO CHECK CAN SEE

* **Two markers rendering selected at once** — the hollow ring and the doubled
  stroke on *both* members. No verb reads pixels; `MS13` asserts at source level
  that the renderer consults the predicate, which is the strongest available
  proxy.
* **The cross-strip repaint** — that both rings appear together and no stale ring
  is left on the partner's strip. `need_all_redraw` / `xschem redraw` is not
  observable.
* **The double-click feel** — Tk's 500 ms / 5 px window is Tk's, and whether a
  real hand lands two clicks inside it is not assertable.
* **That the pair cue reads as "these two go together"** — a design judgement.
  Only an eyeball can reject it.
