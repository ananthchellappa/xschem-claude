# Next session — continue the action-logging feature

**Branch:** `feature/action-logging`. **Last commit:** Layer C (`73096349` +
docs). **Spec:** `specs/action_logging.md` (decisions locked). **Progress
tracker:** `specs/action_logging_checklist.md` (keep the Implemented? column
current). **Running tutorial:** `claude_suggs/lessons_learnt_action_registry.md`.

## Where we are

Phases 0–2 are DONE: log file (+`--logdir`/`--nolog`), CIW, Layer A (bound
keys/buttons/wheel at `dispatch_input_action`), Layer B (context-menu picks),
Layer C (gesture ENDs — `73096349`, plan
`claude_suggs/plan_layer_c_gesture_end.md`). Acceptance smoke
`tests/headless/test_action_replay.sh` now diffs a byte-identical saved
schematic across record/replay processes; `test_gesture_end_log.tcl` covers
every gesture in-process.

## NEXT: Phase 3 — mint the missing subcommands, close the `#` markers and silent ids

Checklist rows 29–32 + the deferrals Layer C recorded. Worklist, roughly in
value order:

1. **`xschem polygon x1 y1 x2 y2 ...` coordinate form** (store_poly is ready;
   model on the `xschem rect` branch). Then upgrade the Layer C marker in
   `new_polygon` (actions.c) to the real command — the point list is in
   `xctx->nl_polyx/nl_polyy[0..nl_points-1]` at the store.
2. **`pan` / `scroll` / `snap` subcommands** (rows 29–31) to un-silence the
   empty-command Layer A ids (`actions.csv` rows with no command) and row 32
   (middle-button pan gesture — its END is in callback.c, look for STARTPAN).
3. **Reconcile gesture-START vs gesture-END log lines.** Layer A logs the
   start commands (`xschem wire`, no-arg `xschem move_objects`, `xschem
   zoom_box` from key Z, …); Layer C now logs the END. Replaying the start
   forms leaves benign MENUSTART state. Decide: csv-`nolog` the start forms
   (log shows only the effect) or keep both (log shows intent + effect).
   Audit which ids are affected via `grep ',xschem \(wire\|line\|rect\|polygon\|arc\|move_objects\|copy_objects\|zoom_box\)' src/actions.csv`.
4. **Optional fidelity upgrades** noted in the Layer C plan: log layer
   switches (rectcolor) so line/rect replay lands on the right layer;
   rotate/flip-during-move (needs an anchor-preserving subcommand — audit
   before minting, `xschem rotate` uses a different anchor).

Then the feature is functionally complete → do a spec/checklist
reconciliation pass (row 11 "every user action" will still be bounded by
issues 0003/0005 — state that explicitly rather than chasing it).

## Layer C facts the next session will want

- Move/copy logging lives in `end_move_copy_logged()` (callback.c): captures
  deltax/deltay/move_rot/move_flip/ui_state BEFORE the END (which resets
  them), logs after. Placement drops (PLACE_SYMBOL/PLACE_TEXT) read the
  placed object back post-END instead.
- Placement logging lives at the `storeobject` sites inside
  `new_wire/new_line/new_rect/new_arc/new_polygon` (actions.c) — every
  gesture path funnels there; the scheduler's coordinate forms do NOT, so
  replays never double-log. Keep that invariant when minting new subcommands:
  the replay path must not pass through `new_*`.
- `tcl_braceable()` (callback.c) guards embedded free text; refuse-don't-fix.
- The saved-schematic diff in the acceptance smoke needs
  `xschem rebuild_connectivity` before `saveas` in BOTH processes (the
  gesture path stamps the derived `lab=` cache eagerly, replay defers it).
- Driving gestures headless: motion = `xschem callback .drw 6 x y 0 0 0 0`,
  click = press(4)+release(5) button 1; `set infix_interface 1` makes
  `xschem wire/rect/polygon gui` start at the mouse; menu-started move/copy
  is click-to-start then click-to-drop; a no-motion RMB release opens the
  context menu — stub `proc context_menu {} {return 21}` or it blocks.

## Standing context / conventions

- **Build:** `cd src && make xschem`. **GUI smokes:** `DISPLAY=:0 ./src/xschem
  --pipe -q --nolog --script tests/headless/<t>.tcl` (use `--logdir $(mktemp -d)`
  instead of `--nolog` for the logging/CIW smokes; `test_nolog.tcl` needs
  `--nolog` itself). **Engine harness:** `cd tests/headless && ./run.sh`.
- **Rhythm:** scope → short plan doc → implement (pure addition, no spaghetti) →
  test → commit code+tests, then a separate docs/memory commit. Keep the
  checklist + spec status + project memory current each step.
- **Deferred-by-design issues (do NOT implement without a steer):** 0003
  (stdin-REPL + TCP command logging holes), 0004 (TCP server has no auth), 0005
  (replayable click-select needs stable object referents — bounds Layer B/C
  selection-dependent commands).
- **WSLg ghost frames:** smokes that open toplevels `destroy .ciw; update`
  before exit; if a windowless empty frame appears after a run, it is the issue
  0002 RAIL leak — `wsl --shutdown` clears it (commit work first).
