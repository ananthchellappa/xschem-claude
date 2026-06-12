# Plan: Layer C — gesture END logging (Phase 2, checklist rows 26–28)

Log, when a drag/click gesture *completes*, the single `xschem …` command that
reproduces its effect (or a `#` marker where no faithful subcommand exists).
Record-after-evaluation, as in Layers A/B.

## Audit results (step 0)

### Where gestures actually complete

| Gesture | Completion point | All paths funnel there? |
|---|---|---|
| zoom-rect | `end_place_move_copy_zoom()` STARTZOOM | yes (only caller of `zoom_rectangle(END)`) |
| move/copy drag | `end_place_move_copy_zoom()` STARTMOVE/STARTCOPY **and** the intuitive-interface release path (callback.c ~5111/5121) | no — 2 sites; plus `end_shape_point_edit()` (a *different* gesture: control-point drag) |
| wire/line/rect/poly/arc placement | the `storeobject`/`store_arc`/`store_poly` calls inside `new_wire`/`new_line`/`new_rect`/`new_arc`/`new_polygon` (actions.c) | yes — every entry path (release, intermediate click, persistent mode, infix gui, context menu) places through these; **the END states themselves place nothing** (wire/line place at PLACE with rubber-tracked `nl_*`, possibly 2 manhattan segments) |

The inline `move_objects(START…ROTATE…END)` key sequences (F/R cases) and the
scheduler's own `move_objects(END)` calls are NOT drag gestures — hooking
move.c would double-log replays and key actions. So: hook the two callback
completion sites via one shared helper, not move.c.

### Replay-command audit (cmd that *looks* right vs what END does)

- `xschem zoom_box x1 y1 x2 y2` (factor defaults 1) — **byte-equivalent** to
  `zoom_rectangle(END)`: same origin/zoom math, factor-1 recentering terms
  vanish. Degenerate (x1==x2 && y1==y2) does nothing in both → skip logging.
- `xschem move_objects dx dy [kissing]` / `xschem copy_objects dx dy [kissing]`
  = START+END(dx,dy) on current selection → faithful for a plain translation
  drop. Selection-dependent (issue 0005), same bound as Layer B cut/copy.
  NOT faithful when the gesture mixed in rotate/flip (`move_rot/move_flip`,
  applied by END around the START anchor — `xschem rotate` uses a different
  anchor) → `#` marker. END *resets* deltax/deltay/move_rot/move_flip →
  capture before, log after.
- Drops that complete placement flows (flags read pre-END):
  - PLACE_SYMBOL → read the placed instance back post-END (sel_array[0]) and
    log `xschem instance {name} x0 y0 rot flip {prop}` — coordinate-replayable,
    closes the Layer-B "place symbol" deferral. Brace-safety guard (below).
  - PLACE_TEXT → read text back, `xschem text x y rot flip {txt} {prop} size 1`
    (scheduler: create_text). Brace-safety guard; marker on failure.
  - STARTMERGE (paste drop) / START_SYMPIN → `#` markers (replay of the drop
    needs the pending merge state; defer).
- `xschem wire x1 y1 x2 y2` — storeobject(WIRE)+trim, equivalent per segment.
  Manhattan modes place 1–2 segments per PLACE → log one line per segment with
  the exact stored coords. Accepted deltas: undo granularity (gesture = one
  push for both segments), autotrim runs per-command at replay vs once per
  PLACE. Replay does NOT pass through new_wire → no double-log.
- `xschem line x1 y1 x2 y2`, `xschem rect x1 y1 x2 y2` — equivalent stores on
  **current rectcolor**; replay layer fidelity bounded by un-logged layer
  switches (note in spec; Phase-3 candidate).
- `xschem arc x y r a b layer` — takes explicit layer → fully faithful.
- polygon — **no coordinate subcommand exists** → `#` marker with point count
  (Phase 3 mint, row 29–31 territory).

### Brace safety
Logged free text (symbol name, prop strings, text body) is emitted as a
`{braced}` Tcl word. Conservative guard `tcl_braceable()`: refuse strings
containing `{`/`}`/`\` (marker instead) so the log file ALWAYS stays
source-able (the Layer-B invariant).

### Layer A interplay (accepted, documented)
Bound gesture-start keys already log their start command (`xschem wire`,
`xschem move_objects`, …, no-arg forms → MENUSTART). Replay runs start + end:
the start leaves benign MENUSTART state, the END command does the real work.
Cleanup decision (csv-nolog the start forms?) deferred to the Phase-3
reconciliation pass.

## Implementation

1. callback.c: log in STARTZOOM branch; add `tcl_braceable()` +
   `end_move_copy_logged(is_copy)` helper wrapping the END call at the 3
   move/copy completion sites; `#` marker in `end_shape_point_edit`.
2. actions.c: `log_action` per stored segment in new_wire/new_line (5 sites
   each), new_rect (1), new_arc SET-store (1, with rectcolor), polygon marker.
3. Tests: new `tests/headless/test_gesture_end_log.tcl` (drive each gesture by
   `xschem callback` press/motion/release, assert log lines + actual state
   change + file source-ability); extend `test_action_replay.sh` with a
   gesture so the acceptance smoke covers Layer C.
4. Checklist rows 26–28 + spec status + memory updates (docs commit).
