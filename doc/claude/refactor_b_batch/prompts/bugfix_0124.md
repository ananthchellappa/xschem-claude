# Bugfix 0124 — Ctrl+Shift+H phantom-logs a cancelled make_sch_from_sel dialog

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch `fluid-editing`.
Issue file: doc/claude/issues/0124-ctrl-shift-h-phantom-logs-cancelled-dialog.md (Status: OPEN).
Scout receipt: doc/claude/refactor_b_batch/receipts/07_make_sch_from_sel.md (reason 6 = this bug).

## Bug (re-verified from source 2026-07-18)

Ctrl+Shift+H dispatches the C-backed action `sym.make_schematic_and_symbol_from_selected_components`.
The act handler returns 1 unconditionally (callback.c:3434); the core
`make_schematic_symbol_from_sel()` self-logs ONLY on the real edit (save.c:5397) and skips
`log_action` when the Save dialog is cancelled (empty filename) or the name equals the current
schematic. On those no-op outcomes `actionlog_cmd_logged` stays 0, and `dispatch_input_action`'s
Layer-A fallback (callback.c:4143-4145, `if(ret && d->log_cmd && !actionlog_cmd_logged)
log_action("%s", d->log_cmd);`) records a phantom `xschem make_sch_from_sel` line. Replaying such
a log re-pops a dialog for an edit that never happened.

Fix shape: mark the actions.csv row `nolog`. The startup loop (xschem.tcl:13933-13941) then calls
`xschem set_action_nolog` and NEVER pushes `log_cmd` for the id, so `d->log_cmd` stays NULL and the
Layer-A fallback goes permanently silent for this action. The core self-log keeps covering the
success line from EVERY entry point. No C behavior change.

## Verified anchors (2026-07-18 — re-verify before editing; lines drift)

- `src/actions.csv:37` header `id,type,menu,label,accel,command,submenu,hook,help,idle,nolog`;
  nolog column documented at :27-32. Loader (action_registry.tcl:66-95,
  `foreach col $header val $fields`) pads short rows, so appending an 11th field `1` yields nolog=1.
- `src/actions.csv:124` — the target row (currently 10 fields, trailing comma = empty idle, NO
  nolog field):
  `sym.make_schematic_and_symbol_from_selected_components,command,sym,Make schematic and symbol from selected components,Ctrl+Shift+H,xschem make_sch_from_sel,,,Make schematic and symbol from selected components,`
- `src/xschem.tcl:13933-13941` — startup loop: nolog row -> `xschem set_action_nolog $id; continue`
  (log_cmd never pushed). `src/callback.c:4288-4305` `action_cmd_set_nolog`.
- `src/callback.c:4124-4146` `dispatch_input_action`; readonly gate
  (`action_id_mutates(...) && readonly_block()`) returns BEFORE the fn branch; C-backed Layer-A
  fallback at :4143-4145.
- `src/callback.c:3434` `act_make_sch_sym_from_sel` returns 1 unconditionally (leave as-is —
  harmless once the row is nolog).
- `src/callback.c:3690-3691` ActionDef row: fn set, tcl NULL, mutates=1.
- `src/callback.c:3976` chord: `set_input_binding(DEV_KEY, 'H', ControlMask, ACTX_CANVAS, ...)`.
  handle_key_press normalizes printable-keysym mods to rstate = state & ~ShiftMask
  (callback.c:~4884), so driving `state=5` (Ctrl|Shift) with keysym 72 ('H') matches mods=4.
- `src/save.c:5362-5399` core: cancel/overwrite-refuse branches skip the whole edit block AND the
  log; success block ends with `log_action("xschem make_sch_from_sel")` at save.c:5397 (sets
  actionlog_cmd_logged). STALE comment at save.c:5392-5396 claims the Ctrl+H key logs via Layer A
  on success — update it (see Edits).
- Paths NOT affected by nolog (verified): the Symbols-menu entry is HAND-WRITTEN at
  xschem.tcl:14426 (`-command "xschem make_sch_from_sel"`, subcommand -> scheduler.c:6515-6524 ->
  core); only the File menu is table-generated (xschem.tcl:14045 is the sole
  build_menu_from_table call). The command palette (action_registry.tcl:471-487 palette_run) runs
  the row command bare — core self-log covers it, palette never consults nolog. Context menu has
  no make_sch_from_sel entry. So the nolog flag silences ONLY the key path's Layer-A copy — the
  defer trigger ("nolog silences a path not covered by the core self-log") is refuted.
- Locks that must stay green: `tests/headless/test_selflog_grep_guard.tcl:492` requires EXACTLY
  ONE occurrence of the literal `log_action("xschem make_sch_from_sel"` in save.c — do NOT write
  that literal into the new comment; :615/:671 CVERBS/S3 families (scheduler/save source,
  untouched). `tests/headless/test_key_graph_context.tcl:232` asserts the binding-dump row
  (untouched).
- `tests/headless/test_selflog_output.tcl:253-277` — subcommand cancel/success/readonly checks;
  UNCHANGED by this fix. NOTE: this file is in the batch BASELINE-FAIL list (transform-keys
  section), so do not use its overall exit as a signal — grep its output for the three
  make_sch_from_sel `ok` check lines instead.
- Dialog stubbing precedent (answers the "messageBox nondeterminism" defer trigger):
  test_selflog_output.tcl:214-221 — `proc tk_messageBox {args} {return ok}`,
  `proc make_symbol_lcc {args} {return {}}`, `proc save_file_dialog {args} {return $::sfd_ret}`.
  The cancel path never reaches the messageBox at all; the success path's okcancel is the stub.
- Key-drive template: `tests/headless/test_delete_cut_selflog.tcl` — logdir SKIP guard,
  `winfo viewable .drw` X-guard (soft-pass when no display), drive =
  `xschem callback .drw 2 <mx> <my> <keysym> 0 0 <state>` + `update idletasks`,
  `RESULT: ALL PASS` banner, `catch {destroy .ciw}; update` teardown.
- `tests/headless/full_audit.sh:~40-61` `logdir_tests` list — the new test MUST be added there or
  it runs without an action log and self-SKIPs.

## Edits (exact)

1. `src/actions.csv` line 124: append `,1` so the row ends
   `...,Make schematic and symbol from selected components,,1`
   (field 10 idle stays empty, field 11 nolog=1). Nothing else on the line changes.

2. `src/save.c` — comment-only update of the stale sentence above the self-log (currently
   :5392-5396). Replace the last two comment lines ("Covers menu/script; the Ctrl+H registered
   action logs ... via Layer A on success (deduped ...)") with wording like:
   `* ONLY log site for every entry: menu/script subcommand AND the Ctrl+Shift+H registered`
   `* action -- its actions.csv row is nolog (issue 0124), so dispatch's Layer A fallback`
   `* never fires (it used to phantom-log a cancelled dialog).`
   MUST NOT contain the literal `log_action("xschem make_sch_from_sel"` (grep-guard :492 counts
   exactly one). No code change. Rebuild: `cd src && make`.

3. NEW test `tests/headless/test_key_make_sch_from_sel_log.tcl` (see Test plan). New file (own
   process) rather than extending test_selflog_output.tcl because that file is a pre-existing
   baseline FAIL — a new file gives the audit a clean PASS/FAIL signal.

4. `tests/headless/full_audit.sh`: add ` test_key_make_sch_from_sel_log ` to `logdir_tests`.

5. Docs: issue file Status -> FIXED (see Docs step). No change to scheduler.c, callback.c, or the
   core log itself.

## Test plan — tests/headless/test_key_make_sch_from_sel_log.tcl

Harness: copy the test_delete_cut_selflog.tcl skeleton (check proc, `logcount` exact-line
counter, SKIP-if-no-log, RESULT banner, .ciw teardown). Fixture: load
`xschem_library/examples/nand2.sch`, `xschem saveas $scratch schematic` into the logdir
(`key_msfs_gen.sch`), then stubs:
`proc tk_messageBox {args} {return ok}` ; `proc make_symbol_lcc {args} {return {}}` ;
`set ::sfd_ret {}` ; `set ::sfd_calls 0` ;
`proc save_file_dialog {args} {incr ::sfd_calls; return $::sfd_ret}`.
Count pattern throughout: exact line `xschem make_sch_from_sel`.

Checks (names load-bearing for the sabotage table):
- **A1 "subcommand cancel logs nothing"** — `xschem select_all; xschem make_sch_from_sel` with
  `::sfd_ret {}` -> count unchanged. (Unchanged-behavior control for the scheduler path.)
- **A2 "subcommand success logs exactly one line"** — `::sfd_ret` = logdir `key_msfs_lcc.sch`,
  select_all, run -> count +1 exactly. (Core-covers-success control.)
- Key block, X-guarded exactly like the template (`winfo viewable .drw` else soft-pass check
  "key path (skipped: no X)"); `update idletasks; catch {focus -force .drw}; update idletasks`.
  Drive = `xschem callback .drw 2 400 300 72 0 0 5 ; update idletasks` (keysym 72='H', state
  5=Ctrl|Shift -> rstate 4 matches the ControlMask binding).
- **B "KEY cancelled/refused dialog logs nothing (issue 0124 phantom)"** — one check, two drives:
  `xschem load $scratch; xschem select_all`, (i) `::sfd_ret {}` + drive, (ii) `::sfd_ret $scratch`
  (== current sch -> overwrite-refuse messageBox branch) + drive; assert count is unchanged after
  BOTH. This is THE regression check for the bug.
- **E "KEY cancel mutates nothing"** — capture `xschem get instances` before the B drives, assert
  equal after (cancel pushes no undo, edits nothing).
- **C "KEY success logs exactly one line (core, no Layer-A double)"** — `::sfd_ret` = fresh logdir
  `key_msfs_lcc2.sch`, `xschem select_all`, drive -> count +1 EXACTLY (not +2, not +0).
- **D1 "KEY readonly logs nothing"** / **D2 "KEY readonly never opens the dialog"** —
  `xschem load $scratch; xschem select_all; xschem set readonly 1; set ::sfd_ret {}`, snapshot
  `$::sfd_calls`, drive -> count unchanged (D1) AND `::sfd_calls` unchanged (D2: dispatch's
  mutates=1 readonly_block fires BEFORE the fn). Then `xschem set readonly 0`.

Run it standalone from the REPO ROOT (relative fixture paths), each test its own process:
`DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) --script tests/headless/test_key_make_sch_from_sel_log.tcl`
(and once via `tests/headless/full_audit.sh test_key_make_sch_from_sel_log`).

## Sabotage verification (green-but-hollow discipline)

Each sabotage: apply, run ONLY the new test, confirm EXACTLY the predicted check(s) fail, then
`git diff` to confirm only the sabotage is present, revert with targeted
`git checkout -- <file>` (or Edit-revert for the uncommitted csv change — re-apply the real fix
after), then a clean re-run must be all green.

- **S1** (targets B): remove the `,1` just added to actions.csv:124 (revert to the buggy row).
  Expected: EXACTLY check B fails (the phantom line reappears on cancel/refuse); A1/A2/C/D/E stay
  green (success still +1 because the core logs first and Layer A dedups via
  actionlog_cmd_logged). Re-apply the fix after.
- **S2** (targets the core-success pair): wrap save.c's self-log in `if(0)` (keep the literal on
  the line so grep-guard :492 still counts one; rebuild). Expected: EXACTLY A2 and C fail (+0
  instead of +1); B/D/E/A1 stay green. Declared two-check failure set — both checks assert the
  same invariant (core logs the real edit) on the two entry paths. Revert + rebuild.
- **S3** (targets D2): change the registry row's mutates field to 0 at callback.c:3690-3691,
  rebuild. Expected: EXACTLY D2 fails (readonly no longer blocks before the fn, the
  save_file_dialog stub gets invoked); D1 stays green (the stub cancels -> no log line). Revert +
  rebuild.

## Full audit + baseline

`tests/headless/full_audit.sh` before-vs-after: the PLAN.md-header baseline fail list (14 tests,
recorded 2026-07-18: test_cadence_descend_newwin_ro, test_cadence_drag, test_ciw,
test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui, test_lib_sweep,
test_phase3_mints, test_reopen_readonly, test_save_as_cellview, test_select_at,
test_selflog_output, test_untitled_reuse, test_wire_split) must be UNCHANGED; the new test must
PASS. Additionally single-run and require green: test_selflog_grep_guard, test_key_graph_context,
test_action_log_dispatch, test_delete_cut_selflog, test_keybindings_help. For test_selflog_output
(baseline FAIL), grep its output for the three make_sch_from_sel check names
(:253-277 — "cancel logs nothing", "(real edit) self-logs", "read-only logs nothing") and require
they still print `ok`.

## Docs + memory

- Issue file doc/claude/issues/0124-ctrl-shift-h-phantom-logs-cancelled-dialog.md: Status ->
  **FIXED** (date, commit), what changed (actions.csv:124 nolog + save.c comment + new test +
  full_audit registration), and two notes: (a) the overwrite-refuse messageBox branch was a second
  phantom on the same mechanism, fixed by the same flag and covered by check B; (b) the act
  handler's unconditional `return 1` is now harmless (Layer A permanently silent for this id) —
  left as-is deliberately.
- Auto-memory (per discipline: detail in the topic file, index stays one line): append a short
  0124 block to
  /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/action-logging.md
  (batch section) — bug, fix = csv nolog row, sabotage results, new test name. Update the
  action-logging line in MEMORY.md only if needed to mention 0124; keep it one short line.

## Commit (explicit file list — never -a / -A, never push)

```
git add src/actions.csv src/save.c tests/headless/test_key_make_sch_from_sel_log.tcl \
        tests/headless/full_audit.sh \
        doc/claude/issues/0124-ctrl-shift-h-phantom-logs-cancelled-dialog.md
git commit -m "fix(action-log): nolog Ctrl+Shift+H csv row - cancelled make_sch_from_sel dialog no longer phantom-logs (issue 0124)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

## Discipline reminders

- Re-verify every anchor line above from source before editing; they were fresh 2026-07-18 but
  drift.
- C89 (only a comment changes in C here — keep it that way). Headless tests: repo-root cwd, own
  process. Key tests replay the full `xschem callback` event with the real keysym/state in the
  shipping profile.
- NEVER git reset --hard, no bulk adds, no push. Do not touch junk dirs (_nhangle_* etc.) or any
  file outside the list above.
