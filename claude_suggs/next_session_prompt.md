# Next session — action-logging feature is functionally COMPLETE

**Branch:** `feature/action-logging`. **Spec:** `specs/action_logging.md`
(status section current through Phase 3). **Tracker:**
`specs/action_logging_checklist.md` (reconciled 2026-06-11). **Tutorial:**
`claude_suggs/lessons_learnt_action_registry.md`.

## State

Phases 0–3 all DONE: log file (+`--logdir`/`--nolog`), CIW, Layer A
(dispatch logging incl. the Phase-3-minted scroll/pan/snap/toggle
subcommands), Layer B (context menu), Layer C (gesture ENDs incl. drag-pan),
nolog gate for gesture-start commands. Acceptance smoke diffs a
byte-identical saved schematic across record/replay processes.

There is NO scoped next step. This is a decision menu — present it, don't
pick unilaterally:

1. **Click-select marker + replayable selection** (checklist row 17 +
   issue 0005): `xschem select_at x y` exposing `find_closest_obj()`, stable
   object referents. Unblocks faithful replay of the selection-dependent
   commands (move/copy/cut/delete). The largest remaining fidelity gap.
2. **stdin-REPL / TCP logging holes** (issue 0003) — and 0004 (TCP auth) if
   touching that code anyway.
3. **Merge planning**: feature/action-logging → its base
   (refactor/dispatcher-decomposition) or master; decide rebase/squash
   strategy, run the full suite, write release notes.
4. **Resume the un-migrated key work** (action-registry Phase 3d well):
   every key migrated INTO the binding table automatically gains Layer A
   logging (and the 14 nolog'd gesture-start ids arm automatically when
   registered). The logging feature gives key migration new value.
5. **Need-driven only** — stop here; the parked items (rectcolor logging,
   rotate-during-move replay, dialogs) wait for a user need.

## Standing context / conventions

- **Build:** `cd src && make xschem`. **GUI smokes:** `DISPLAY=:0 ./src/xschem
  --pipe -q --nolog --script tests/headless/<t>.tcl` (logging/CIW smokes use
  `--logdir $(mktemp -d)`; `test_nolog.tcl` needs `--nolog` itself).
  **Engine harness:** `cd tests/headless && ./run.sh`. **Acceptance:**
  `DISPLAY=:0 sh tests/headless/test_action_replay.sh`.
- **Key invariants:** placements log inside `new_*` (actions.c) — scheduler
  coordinate forms must NOT route through `new_*` or replays double-log;
  `xschem get` dispatches on argv[2][0] — new getters go in the right
  first-char case (a 'p' entry in the 'r' case is silently unreachable);
  a smoke that needed `timeout` to die is a bug in the smoke AND a WSLg
  ghost-frame factory (issue 0002 §9) — stub popups/dialogs
  (`proc context_menu {} {return 21}`, `proc alert_ {args} {}`,
  `proc enter_text {l m} {...}`).
- **Deferred-by-design issues (do NOT implement without a steer):** 0003,
  0004, 0005.
- **WSLg ghost frames:** `destroy .ciw; update` before exit; a leftover
  empty frame on the Windows desktop is the issue 0002 RAIL leak —
  `wsl --shutdown` clears it (commit work first).
