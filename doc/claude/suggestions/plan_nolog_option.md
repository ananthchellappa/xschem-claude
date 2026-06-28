# Plan — `--nolog` option (and closure of issue 0002)

**Date:** 2026-06-11. **Branch:** `feature/action-logging`.
**Requested by:** user — "add a --nolog option that could be used with headless
tests: no logging and also no CIW window being opened."
**Resolves:** issue 0002 (WSLg ghost RAIL frame after smoke sweeps) by removing
the trigger from test runs; supersedes the earlier "auto-detect --script"
proposal in that issue's §7 with an *explicit* opt-out, which is simpler and
has no spec ambiguity about what "interactive" means.

## Decisions (proposed, lock at implementation)

1. **Name/semantics:** `--nolog` = do not open the action log AND do not
   auto-open the CIW. One flag, both effects — they are the same feature's two
   faces and tests want them off together.
2. **Conflict `--nolog` + `--logdir`:** error + exit 1 (matches Phase 0's
   strict handling of an uncreatable logdir; both flags together is a
   confusion worth surfacing, and no test needs both).
3. **Manual `ciw_create` under `--nolog` stays allowed** and degrades sanely:
   the CIW becomes a plain command console — typed commands run and echo in
   the pane (ciw_exec echoes directly), but nothing reaches a file and
   `log_action()`/`xschem log_action` are no-ops (`actionlog_fp` is NULL).
   No extra code needed; document it.
4. `xschem get actionlog_filename` returns `{}` under `--nolog` (already true:
   the filename is only set when the file opens).

## Steps

### 1. C core
- `globals.c` + `xschem.h`: `int cli_opt_nolog = 0;` (+ extern).
- `options.c`: parse LONG `nolog` → `cli_opt_nolog = 1` (no SHORT form).
- `util.c` `init_action_log()` (called from main.c:100):
  - conflict check first: `cli_opt_nolog && cli_opt_logdir[0]` → fprintf
    stderr + `tcleval exit`-style hard exit 1, same shape as the uncreatable
    logdir path;
  - then `if(cli_opt_nolog) return;` (before the has_x/logdir gate).
- `xschem.help`: document `--nolog` next to `--logdir`.

### 2. Tcl mirror + CIW gate
- `xinit.c`, where `has_x` is exposed to Tcl before `xschem.tcl` is sourced:
  `tclsetvar` an integer `cli_opt_nolog` (0/1), following the MIRRORED-IN-TCL
  convention.
- `xschem.tcl` auto-open site (~11696): wrap `ciw_create` in
  `if {!$cli_opt_nolog} { ... }`, comment pointing at issue 0002 + spec
  decision 8.

### 3. Adopt in tests (the actual issue-0002 fix)
- `tests/headless/run.sh`: add `--nolog` to the xschem invocation. Side
  benefit discovered while planning: the engine harness runs with X and no
  --logdir, so since Phase 0 it has been BOTH littering
  `tests/headless/Xschem.log{,.1}` (masked by a .gitignore entry) AND
  auto-opening a CIW per run — it was a ghost-frame trigger too, not just the
  GUI smokes. Delete the two stray files; consider dropping the .gitignore
  mask later so litter fails loudly (keep for now: user cwd launches).
- GUI smokes: the standard invocation becomes
  `xschem --pipe -q --nolog --script <test>.tcl` for all smokes EXCEPT the
  logging/CIW ones (`test_ciw.tcl`, `test_action_log_dispatch.tcl`), which
  keep `--logdir $(mktemp -d)` because the log/CIW is their subject.
  Update `tests/headless/README.md` with the rule:
  "--nolog unless the test tests logging".
- Residual trigger budget: 2 smokes × 1 CIW each per sweep (was ~16).
  Optional hardening in those two: `destroy .ciw; update` just before `exit`
  so Weston gets a clean destroy while the client is alive.

### 4. New smoke — `tests/headless/test_nolog.tcl`
Run WITH a display and `--nolog` (this is the case Phase 0's `-x` smoke
cannot cover):
- `.ciw` does not exist at startup (auto-open suppressed);
- `xschem get actionlog_filename` is empty;
- no `Xschem.log*` appears in the launch cwd (use a mktemp cwd);
- a Tcl-backed bound key (K, keysym 75) still dispatches fine — logging off
  must not break dispatch (log_action no-ops);
- `xschem log_action {x}` is a safe no-op;
- manual `ciw_create` still builds the console (decision 3).
Plus extend `test_action_log.sh` (-x, no display needed) with the conflict
case: `--nolog --logdir <ok-dir>` → rc 1 + error text.

### 5. Docs
- `doc/claude/specs/action_logging.md`: §1 bullet for `--nolog`; decision 8 reworded —
  "CIW auto-opens at startup of interactive sessions **unless `--nolog`**;
  test/automation runs pass `--nolog`"; new decision 10 for the
  conflict-is-fatal rule; §5 status line.
- `doc/claude/specs/action_logging_checklist.md`: add rows (58–61): --nolog disables the
  log file; --nolog suppresses CIW auto-open; --nolog+--logdir exits 1;
  test runner uses --nolog. Flip to yes as they land.
- `doc/claude/issues/0002-...md`: status → RESOLVED, mechanism = explicit `--nolog`
  adopted by all non-logging test invocations (note it supersedes §7's
  auto-detect proposal), residual = 2 logging smokes (+ optional clean
  teardown), verified-by = test_nolog.tcl + a full sweep.

### 6. Verify
- Rebuild; run test_nolog.tcl, test_action_log.sh, test_ciw.tcl,
  test_action_log_dispatch.tcl, engine harness via updated run.sh, full GUI
  smoke loop with --nolog. All green; confirm no new `Xschem.log` litter in
  tests/headless after the harness run.
- Ghost-frame verification is inherently user-side (the frame lives on the
  Windows desktop): ask the user to watch for ghosts over the next few sweeps
  before closing 0002 for good.

### 7. Wrap up
- Commit (code+tests+docs can be one commit; keep the plan doc in
  suggestions). Update memory: --nolog landed, issue 0002 resolved-pending-
  user-observation, checklist rows.

## Order of work
1→2 (build) → 4 (red on old binary where applicable, green on new) → 3 →
5 → 6 → 7. Small enough for one session.
