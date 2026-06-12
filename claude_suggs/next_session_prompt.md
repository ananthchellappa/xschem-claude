# Next session — continue the action-logging feature

**Branch:** `feature/action-logging`. **Last commit:** `9a3e613e` (Layer B).
**Spec:** `specs/action_logging.md` (decisions locked). **Progress tracker:**
`specs/action_logging_checklist.md` (68 rows; keep the Implemented? column
current). **Running tutorial:** `claude_suggs/lessons_learnt_action_registry.md`.

(This file previously held the action-registry Phase-3 handoff; that work is
complete and its prompt is superseded here.)

## Where we are

The replayable action log + CIW is well advanced. DONE:
- Phase 0 (log file, rotation, `--logdir`, `--nolog`), CIW (live pane + command
  entry, sash UX, history, word-delete), `xschem log_action` / `get
  actionlog_filename`.
- **Layer A** — bound keys/buttons/wheel logged at `dispatch_input_action`
  (callback.c): slice 1 Tcl-backed (`d->tcl`), slice 2 C-backed (canonical
  `actions.csv` command pushed via `xschem set_action_log_cmd`).
- **Layer B** — context-menu picks logged at `context_menu_action` (callback.c)
  via a retval-indexed classification table.
- **Acceptance smoke** — `tests/headless/test_action_replay.sh`: two-process
  record → replay → diff (diffs the zoom *transform* ratio, not absolute — see
  the lesson in §10 of the tutorial).

## NEXT: Layer C — gesture END hooks (Phase 2, checklist rows 26–28)

When a drag gesture *completes*, log the single `xschem …` command that
reproduces its effect. This closes the 10 gesture-start picks deferred from
Layer B AND their keyboard/toolbar twins in ONE place.

**The chokepoint is `end_place_move_copy_zoom()` (callback.c:1421)** — the
single function that completes STARTZOOM / STARTWIRE / STARTARC / STARTLINE /
STARTRECT / STARTPOLYGON / STARTMOVE / STARTCOPY. Logging here (after each END
runs, record-after-evaluation as everywhere else) covers every gesture
regardless of how it was started (RMB-drag, key, context menu). NOTE there are
ALSO `move_objects(END,…)` / `copy_objects(END)` call sites scattered elsewhere
in callback.c (grep shows ~12) — check whether gesture completions all funnel
through `end_place_move_copy_zoom` or some bypass it; log at the common point,
not per call site (the Layer B / slice-2 "single chokepoint, not per-site"
discipline).

### Start with the clear win, then audit the rest

1. **zoom-rectangle → `xschem zoom_box x1 y1 x2 y2`** is the spec's worked
   example and the cleanest: the END (`zoom_rectangle(END)`) has final coords in
   `xctx->nl_x1/nl_y1/nl_x2/nl_y2`, and `zoom_box` already exists
   (`actions.c:3108`, verified distinct from `zoom_rect`). Confirm the arg order
   and that the degenerate (x1==x2) case is skipped — `end_place_move_copy_zoom`
   already returns 0 for it. Geometry-faithful and fully replayable — unlike the
   view zooms, this one DOES round-trip absolute coords.

2. **Everything else needs a per-gesture step-0 audit** (the slice-2 / Layer B
   discipline — read the END body AND the candidate subcommand; a command that
   *looks* right is a hypothesis):
   - wire/line/rect/poly END place at coordinates — is there an `xschem`
     subcommand that places one at given coords? If not, it is a Phase-3 mint
     (rows 29–31 territory) → defer with a `#` marker for now.
   - move/copy END translate the selection by `deltax/deltay` — selection-
     dependent (issue 0005 bound), like Layer B's cut/copy. `xschem
     move`/`paste`? audit args.
   - **`persistent_command` mode** complicates wire/line/poly (multi-segment,
     PLACE vs PLACE|END branches) — make sure the logged command matches the
     branch actually taken.

3. **Defer cleanly, note loudly.** Any gesture whose faithful command needs a
   not-yet-existing subcommand → `#` marker now, real command when Phase 3 mints
   it (pan/scroll/snap + likely place-at-coord). Record deferrals in the spec
   status + checklist, same as Layer B did.

### Test approach

Mirror `test_context_menu_log.tcl` / `test_action_log_dispatch.tcl`: drive a
gesture to its END via `xschem callback` (press → move → release, or the
ui_state path) and assert the log gains the expected command. zoom_box is the
easiest end-to-end (drive an RMB drag, assert `xschem zoom_box …` lands and
replays). Then EXTEND `test_action_replay.sh` with a gesture so the acceptance
smoke covers Layer C too. Wheel/event-arg gotchas and the focus/mapping
flakiness are in the tutorial §13 — guard, don't fight.

## Standing context / conventions

- **Build:** `cd src && make xschem`. **GUI smokes:** `DISPLAY=:0 ./src/xschem
  --pipe -q --nolog --script tests/headless/<t>.tcl` (use `--logdir $(mktemp -d)`
  instead of `--nolog` for the logging/CIW smokes; `--nolog` exists precisely so
  test runs don't auto-open a CIW — issue 0002). **Engine harness:** `cd
  tests/headless && ./run.sh`.
- **Rhythm:** scope → short plan doc → implement (pure addition, no spaghetti) →
  test → commit code+tests, then a separate docs/memory commit. Keep the
  checklist + spec status + project memory current each step.
- **Deferred-by-design issues (do NOT implement without a steer):** 0003
  (stdin-REPL + TCP command logging holes), 0004 (TCP server has no auth), 0005
  (replayable click-select needs stable object referents — blocks faithful
  selection replay; bounds Layer B/C selection-dependent commands).
- **WSLg ghost frames:** smokes that open toplevels `destroy .ciw; update`
  before exit; if a windowless empty frame appears after a run, it is the issue
  0002 RAIL leak — `wsl --shutdown` clears it (commit work first).

## After Layer C

Phase 3 — mint `pan`/`scroll`/`snap` and any place-at-coord subcommands (rows
29–32) to upgrade the Layer-C `#` markers into real commands and close the
empty-command Layer-A silent ids. Then the feature is functionally complete; do
a spec/checklist reconciliation pass.
