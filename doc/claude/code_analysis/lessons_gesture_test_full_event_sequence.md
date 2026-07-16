# Lessons: a synthetic event is not a gesture — test the full input sequence

A practice note distilled from a real incident in the Cadence double-click
connected-select work (`fluid-editing` branch, 2026-07-13; commits `c0d43848`,
`fc00d2dc`, then the fix `2674b948`). Companion to
[`lessons_green_is_not_correct.md`](lessons_green_is_not_correct.md) and the
green-but-hollow note (`../suggestions/green_but_hollow_tests.md`) — this is the
*interactive-input* special case of the same failure mode.

**Short version.** A test that fires one synthetic event (`xschem callback … -3 …`)
in isolation "passed" while the feature added **nothing** in the real editor. The
event a user actually generates is not a lone `-3`; it is a *sequence* —
`press, release, press, Double(-3), release` — and the earlier events in that
sequence mutate the state the `-3` handler reads. Testing the isolated event
verified a code path the product never reaches with that state.

Spec/plan for the feature: [`../specs/dblclick_connected_select.md`],
[`../suggestions/plan_dblclick_connected_select.md`].

---

## 1. The incident, in five beats

1. **Feature.** Under `cadence_compat`, a double-click on a wire/pin/instance
   should grow the selection outward along wire connectivity, one ring per
   double-click. Implemented as a branch in `handle_double_click()`
   (`callback.c`), gated on `ui_state == 0 || ui_state == SELECTION`, calling a
   new `select_grow_connected_step()`.

2. **The green test (T7, first cut).** The headless test fired the double-click as
   a single synthetic event:
   ```tcl
   xschem callback $WIN -3 $SX $SY 0 1 0 0   ;# Double-Button-1, in isolation
   ```
   `ui_state` was `0` (idle) at that moment, the branch ran, the selection grew,
   the assertion passed. Committed as done.

3. **The real bug.** Launching the actual editor with the Cadence profile and
   double-clicking added nothing. Reported by the user: "double-click on anything
   — wires or R18 — nothing is added to the selection."

4. **Root cause.** The Cadence profile sets `fluid_editing=1` *and*
   `en_pin_select=1`. In that profile the **2nd `ButtonPress` of a double-click
   always arms a transient gesture BEFORE `-3` fires**:
   - on a wire or instance body → a fluid move-grab, `ui_state |= STARTMOVE` (=32);
   - on an instance pin → a pin wire-arm, `ui_state |= STARTWIRE` (=1) with
     `pin_pending=1`.

   So at `-3` the real `ui_state` was `40` (`STARTMOVE|SELECTION`) or `1`
   (`STARTWIRE`), **never** the bare `0`/`SELECTION` the branch required. The
   branch was skipped every time; control fell into the draw-gesture-termination
   code, which did nothing useful here. Worse, the trailing **release2** then ran
   the cadence "deselect everything but the object under the cursor" collapse and
   reduced any selection back to one object.

5. **The fix (`2674b948`).**
   - `handle_double_click()` now detects the transient press-arm
     (`STARTMOVE`/`STARTCOPY` with no drag, or `STARTWIRE` + `pin_pending`),
     `abort_operation()`s it, then grows, and latches `place_click_committed` so
     release2 does not collapse the grown selection.
   - The engine's interactive path was changed to **recompute the selection from
     the seed** at the target level (rather than incrementally grow the *live*
     selection, which the fluid gesture had polluted).
   - **T7 was rewritten to drive the full sequence**
     `press, release, press, -3, release` with `fluid_editing`/`en_pin_select`
     on. That test fails on the pre-fix code, and a sabotage that disables the
     transient-abort reds it too.

The reproduction that found the bug was five `xschem callback` lines, not one. The
gap between "one event" and "five events" was the entire bug.

---

## 2. Why the isolated event passed — the precise trap

`handle_double_click()` reads **shared, sequence-accumulated state**: `ui_state`,
`pin_pending`, `mouse_moved`, the current selection. None of those are arguments
of the `-3` event; they are side effects of the events *before* it.

| Event fired | What it does to the state `-3` reads |
|---|---|
| `press1` | arms a transient gesture → `ui_state` gains `STARTMOVE`/`STARTWIRE` |
| `release1` | resolves it as a click → selection settles, `ui_state` → `SELECTION` |
| `press2` | arms the transient gesture **again** → `ui_state` non-idle |
| `-3` | **the handler under test** — now sees the press2 state, not idle |
| `release2` | cadence collapse → can undo what `-3` just did |

The isolated test set up **none** of rows 1–3 or row 5. It invoked the handler in a
state (`ui_state==0`) that the real gesture, in the target profile, never presents.
Green meant "the handler works when called in a state the product does not produce
here." That is not a useful guarantee.

This is the input-handling instance of the general rule: **a test that constructs
its own preconditions can assert whatever those preconditions make true.** The
preconditions have to come from the same place the product's do — here, the event
stream.

---

## 3. The rules

**R1 — Drive the whole gesture, not the climax event.** For any handler keyed on a
compound input (double-click, click-drag, chord, long-press, multi-key), the test
must replay the *full* event sequence a real device emits: every
`ButtonPress`/`ButtonRelease`/`Motion`/`Key` in order, with realistic modifiers and
coordinates. In xschem that means a run of `xschem callback` calls, e.g.
`4`(press) `5`(release) `4`(press) `-3`(double) `5`(release) — not a lone `-3`.
See `test_dblclick_connected_grow.tcl` T7 and the sibling
`test_connected_drag_keeps_selection_0113.tcl` (which already did this correctly).

**R2 — Test under the profile the feature ships in.** The bug only exists with
`fluid_editing=1` + `en_pin_select=1`. The feature is *for* that profile
(`cadence_compat`). A test that runs with defaults tests a configuration no target
user runs. Set the same rc variables the shipping profile sets
(`set ::cadence_compat 1; set ::fluid_editing 1; set ::en_pin_select 1`), and
restore them afterward.

**R3 — If a handler reads shared state, the test must produce that state the way
the product does.** Do not hand-set `ui_state`/selection to the value you *think*
precedes the handler; generate it by replaying the events that set it. Your
mental model of the preceding state is exactly what was wrong here (we assumed
idle; reality was `STARTMOVE`).

**R4 — Sabotage-verify the load-bearing line.** After it passes, break the
specific mechanism (here: disable the transient-abort via a temporary env guard)
and confirm the test *fails*. If it still passes, the test is not exercising that
mechanism. T7's escalation checks red under `SAB_NOTRANS`; the isolated-`-3`
version did not — which is why the isolated version shipped a bug.

**R5 — Reproduce in the user's run mode before believing "done".** The user runs
`xschem --script src/cadence_style_rc …`. The bug was invisible to a headless
`-3` and obvious the moment the real profile drove the real sequence. Cf.
`../../.claude` memory *user-run-config*: "repro bugs in THAT mode."

---

## 4. A checklist for interactive-handler tests

Before calling an input-handler feature done:

- [ ] The test replays **every** event of the gesture, in order (not just the
      final/most-interesting one).
- [ ] The test runs with the **rc profile** the feature targets, variables
      restored at the end.
- [ ] Any `ui_state`/selection/mode precondition is **produced by replayed
      events**, not assigned directly.
- [ ] The gesture is tested where it **competes with other press-armed gestures**
      (fluid grab, pin arm, move/copy, wire draw), since those set the state the
      handler branches on.
- [ ] The trailing **release** is fired too — collapses/commits often happen there
      (issue 0113: release collapsed a multi-selection).
- [ ] **Sabotage** the specific new mechanism and watch the test go red.
- [ ] The feature was **run once by hand in the user's launch mode**.

---

## 5. Design corollary — make handler state a pure function of the seed

The deeper reason the first cut was fragile: it grew the **live selection**
incrementally, and the live selection is co-owned by every other gesture. The fix
made the interactive path **recompute from the seed** (`unselect_all`, re-select
the seed, grow N rings) so the result is a pure function of `(seed, level)` — it no
longer depends on whatever the fluid gesture happened to leave selected. When a
handler must run amid other gestures that mutate shared state, prefer *recomputing
from a stable key* over *incrementally editing shared state*. It is both more
robust in production and far easier to test deterministically.

---

## 6. One-line takeaways

- The event under test is rarely the whole gesture; the earlier events set the
  state your handler reads. **Replay the sequence.**
- **Test in the shipping profile.** A default-config green can hide a
  profile-specific total failure.
- Prefer **recompute-from-a-stable-key** over **mutate-shared-state** for handlers
  that run amid competing gestures.
- **Sabotage the new line** and **run it by hand** — a synthetic-event green is a
  hypothesis, not a result.
