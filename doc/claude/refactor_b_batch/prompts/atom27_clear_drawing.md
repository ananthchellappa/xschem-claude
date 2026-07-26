# Refactor B ATOM 27 — migrate `clear_drawing` onto the perform_action boundary (bare-verb, silent→logged + NEW readonly gate)

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are the implement stage of
Refactor B batch item 02. The scout has already verdicted PROCEED and re-verified every anchor below from
source on 2026-07-18. Atom number: **27** (the 27th per-verb migration; audit section to write: **§47**).

The shape (decided, do not re-litigate — see the decision doc): a **plain bare-verb migration in the
delete/§44 mold, NO split, NO per-verb log arm**. `clear_drawing` is today a SILENT free-everything
mutation with NO readonly gate, NO undo, NO second entry point and ZERO repo callers of the verb. The
boundary gives it: the ONE readonly gate (a correctness fix — pre-migration a READ-ONLY view was silently
emptied), the ONE log site (bare `xschem clear_drawing` via `core_log_action`'s DEFAULT `xschem %s` arm),
and the argc gate (the ONE behaviour tighten: `xschem clear_drawing extra` was a silent TCL_OK no-op that
log-on-success would phantom-log). The core stays raw + SILENT below the boundary — it is a shared
teardown primitive of seven C flows (load/undo-restore/window-teardown/`xschem clear`/debug), and a log
inside it would spam every one of them. Destructive-with-NO-undo is ACCEPTED shipped behaviour (the
logged line is faithful on replay but irreversible): do NOT add a push_undo — check (f) locks that.

## READ FIRST (in order)

1. `doc/claude/code_analysis/perform_action_atom27_clear_drawing_decision.md` — the decision doc
   (anchors re-verified 2026-07-18; §3 caller sweep, §5 test plan).
2. `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` — §4 (boundary +
   the log-at-the-verb-when-the-core-is-shared rule), §33 (log-on-success + the Tcl_ResetResult
   landmine), §30 (no-op-still-logs), §44/§45/§46 (delete / add_pin_stubs / check_unique_names — the
   latest shapes; §44 is THE template for this atom).
3. `doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md` §2 (the current
   contract + F-codes) and §5 (the delete migration plan this atom mirrors).
4. Templates: `tests/headless/test_perform_action_delete.tcl` (bare-verb atom test house style),
   `tests/headless/test_selflog_grep_guard.tcl` (S1 manifest ~:330, S2 CVERBS ~:606, S7 exact-count
   blocks ~:1572), `tests/headless/full_audit.sh` (logdir_tests ~:40–61).

## DISCIPLINE (non-negotiable)

Re-verify EVERY anchor below from source before editing (line numbers drift). A green suite does not
prove the changed code ran: every named sabotage must fail EXACTLY its target check, be reverted with a
targeted `git checkout -- <file>` ONLY after `git diff` confirms that file holds nothing but the
sabotage, and a clean re-run must be green. C89: declarations at block top. Never `git add -A`,
`git commit -a`, `git reset --hard`, never push — stage the explicit file list only. Do not touch the
`_nhangle_*`/`_allm_*`/`_bold_*` junk dirs or any file outside the scope listed at the end. Headless
tests: each test is its own process; relative paths need repo-root cwd; a script error idles, not hangs.

## ANCHORS (verified 2026-07-18 — re-verify, do not trust)

- **Branch**: `src/scheduler.c:2388` `else if(!strcmp(argv[1], "clear_drawing"))` inside
  `xschem_cmds_c` (fn at 2119). Body: `!xctx` guard 2390; `if(argc==2) { unselect_all(1);
  clear_drawing(); }` 2391–2394; `Tcl_ResetResult` 2395. NO readonly gate, NO log, NO push_undo, NO
  set_modify, NO draw; extra-arg calls skip the body → silent TCL_OK. Doc comment 2386–2387
  ("Clears drawing but does not purge symbols") — keep it, extend in the delete-branch style
  (scheduler.c:2644–2651).
- **Core**: `src/actions.c:1866` `void clear_drawing(void)` — preview-flag drops 1875–1876, table/
  storage/prop frees, hash frees 1926–1927. NO push_undo/set_modify/draw/log; returns **void** → the
  arm is always TCL_OK. `unselect_all(1)` is the branch's pre-step (selection must be torn down before
  the storage resets free the objects it references) — it moves INTO the run_core arm, same order.
- **Raw C callers (stay raw + silent below the boundary — do NOT touch)**: save.c:3816/3819/3850
  (`load_schematic`), save.c:4173 (disk `pop_undo`), in_memory_undo.c:463 (`mem_restore_slot`),
  xinit.c:879 (`delete_schematic_data`, file-static), actions.c:3780 (`clear_schematic` — the SEPARATE
  `xschem clear` verb's core, Ctrl+N/Ctrl+Shift+N via actions.csv:38/39), font.c:60 + actions.c:4191
  (debug). Netlist backends: commented-out only.
- **Entry map**: PURE SCRIPTED verb (the reset_inst_prop §33 class). NO callback.c key, NO
  keybindings.csv/mousebindings.csv/actions.csv row, NO xschem.tcl `-command`, NO test caller, NO C
  tcleval — repo-wide `xschem clear_drawing` matches only PLAN.md. So: NO callback.c edit, NO
  key-equivalence decision, NO 0068 note, NO double-log path, NO result consumer (the boundary's
  success-path Tcl_ResetResult changes nothing observable — the branch already returned empty).
- **Boundary machinery**: `scheduler_readonly_reject` scheduler.c:173; `run_core` 215 (header comment
  191; LAST arm `check_unique_names` ends 1035, unreachable default 1036); `core_log_action` 1055
  (header 1039 — its bare-verb roster comment lists
  trim_wires/align/…/show_unconnected_pins/delete; DEFAULT `xschem %s` arm at the dispatcher tail);
  `perform_action` 1421–1432 (log-on-success + success-only Tcl_ResetResult, atom 13). `extern int
  perform_action(...)` in `src/xschem.h:2134`.
- **Grep guard**: `tests/headless/test_selflog_grep_guard.tcl` — S1 scheduler.c manifest (delete
  delegation row :330 is the prose model), S2 CVERBS list :606–620 (`clear_drawing` NOT present —
  add), S7 exact-count blocks (atom-26 block :1572–1602 is the layout model; delete-style zero-rows).
- **Oracles**: `xschem get instances` (scheduler.c:3702), `get symbols` (4057), `get texts` (4103),
  `get wires` (4138). `xschem instance devices/res.sym x y 0 0 {name=Rn}` places + pushes its own undo.
- **full_audit registration**: `tests/headless/full_audit.sh` `logdir_tests` list (:40–61).
- **Audit doc**: last section is §46 (line ~4823) → this atom writes **§47**.

## DO

1. **`run_core` arm** (src/scheduler.c, after the `check_unique_names` arm ~1035, before the
   unreachable default):
   ```c
   else if(!strcmp(verb, "clear_drawing")) {
     /* Refactor B atom 27 (audit §47; decision doc perform_action_atom27_clear_drawing_decision.md):
      * a BARE no-arg mutating verb in the delete (atom 24) mold -- empties the current drawing but
      * does NOT purge symbols. clear_drawing() (actions.c) is a SHARED teardown primitive (load_
      * schematic, disk/memory undo restore, delete_schematic_data, clear_schematic = the separate
      * `xschem clear` verb, debug) -- ALL callers stay RAW below the boundary and the core stays
      * SILENT (a core log would spam every load/undo/close; audit §4 log-at-the-verb rule). Only
      * this VERB crosses. NO push_undo/set_modify/draw exist anywhere on this path and NONE are
      * added: destructive-with-no-undo is ACCEPTED shipped behaviour (the logged line replays
      * faithfully but is irreversible -- decision doc §2); a push_undo here would be a behaviour
      * change, not a migration (and the test's undo-depth detector would catch it).
      * THE ONE FRICTION is the ARITY GATE (F-validate, the reset_inst_prop §33 argc-gate): the old
      * branch acted only inside `if(argc==2)`, so `xschem clear_drawing <extra>` was a silent
      * TCL_OK no-op that log-on-success would PHANTOM-log; validate argc==2 and reject otherwise
      * (the one deliberate behaviour tighten). unselect_all(1) is the branch's original pre-step
      * (selection torn down BEFORE the storage resets free the selected objects) -- kept, same
      * order. Bare-verb log via core_log_action's DEFAULT `xschem %s` arm (NO per-verb branch).
      * The boundary's scheduler_readonly_reject is NEW here -- a correctness fix (pre-migration a
      * READ-ONLY view was silently emptied; the 0041/0051 class, like reset_symbol §42). */
     if(argc != 2) {
       Tcl_SetResult(interp, "xschem clear_drawing: too many arguments", TCL_STATIC);
       return TCL_ERROR;
     }
     unselect_all(1);
     clear_drawing();
     return TCL_OK;
   }
   ```
2. **NO `core_log_action` arm** — the bare verb rides the DEFAULT `xschem %s` arm. Update the TWO
   header-comment rosters instead: `core_log_action`'s bare-verb list (~:1041–1042, append
   `clear_drawing`) and `run_core`'s migrated-verb header (~:191–214, append atom 27).
3. **Branch** (src/scheduler.c:2388) — replace the whole body, keeping + extending the doc comment:
   ```c
   /* clear_drawing
    *   Clears drawing but does not purge symbols.
    * Routes through the single mutation boundary (Refactor B atom 27, run_core above): the NEW
    * readonly gate (was NONE -- a read-only view was silently emptied), the argc==2 arity
    * validation (was a silent no-op), the unselect_all+clear_drawing effect and the ONE bare
    * `xschem clear_drawing` log site (was SILENT) all live in perform_action/run_core. No undo
    * exists on this path (accepted -- decision doc §2). The seven raw C teardown callers of
    * clear_drawing() (load/undo-restore/window-teardown/clear_schematic/debug) stay raw + silent
    * below the boundary and never reach this branch. */
   else if(!strcmp(argv[1], "clear_drawing"))
     return perform_action("clear_drawing", argc, argv);
   ```
4. **NO key/menu/callback.c edit** — the verb has no second entry point (anchor "Entry map"). If you
   find one the scout missed, STOP and record it in the receipt instead of improvising.

## TEST — `tests/headless/test_perform_action_clear_drawing.tcl`

House style = test_perform_action_delete.tcl (check proc, LOG-open guard header, byte-exact `lc`
line counter, full_audit `--logdir` note). **Pin the effect oracle on the PRE-migration binary FIRST**
(atom-20 discipline): build HEAD, confirm (i) `xschem clear_drawing` on a READ-ONLY cell empties it
(the bug the gate fixes), (ii) `xschem clear_drawing extra` is a silent TCL_OK no-op, (iii)
`xschem get symbols` stays nonzero after a clear.

Fixture: `xschem clear force`, then place 3 `devices/res.sym` instances at distinct coords (each
placement pushes its own undo). Oracles: `xschem get instances` / `get symbols` / `get texts` /
`get wires`.

Checks (each named, each independently assertable):
- **(a) SUCCESS**: fixture; `xschem clear_drawing` → instances==0, texts==0, wires==0, `get symbols`
  still ≥1 (the "does not purge symbols" contract — the delta vs `xschem clear`), exactly **+1
  byte-exact** `xschem clear_drawing` line, interp result blank.
- **(b) THE ARITY TIGHTEN**: fixture; `xschem clear_drawing extra` → TCL_ERROR with a NON-EMPTY
  verb-named message matching `*clear_drawing*argument*` (the §33 landmine: success-only
  Tcl_ResetResult must not wipe it), NO mutation (instances unchanged), **+0** log. (Pre-migration:
  silent TCL_OK no-op — the oracle run proves the tighten.)
- **(c) THE NEW GATE**: fixture; `xschem set readonly 1`; `xschem clear_drawing` → TCL_ERROR matching
  `*clear_drawing*read-only*`, NO mutation, **+0** log; `xschem set readonly 0` after. (Pre-migration
  this EMPTIED the read-only view — the oracle run proves the fix.)
- **(d) REPLAY**: write a pid-isolated one-line log `xschem clear_drawing`; fixture;
  `replay_action_log` → EFFECT applied (instances==0) and NOT re-logged; fixture; control unwrapped
  `source` → effect applied AND re-logged (+1).
- **(e) NO-OP-STILL-LOGS**: `xschem clear force` (empty sheet); `xschem clear_drawing` → still
  TCL_OK, **+1** log (§30 — a void success; clearing nothing is a success, not a failure).
- **(f) NO-SPURIOUS-PUSH / accepted irreversibility**: `xschem clear force`; place ONE instance (the
  placement pushes the pre-placement EMPTY snapshot); `xschem clear_drawing`; ONE `xschem undo` →
  instances **stays 0** (undo restored the pre-placement empty snapshot — the shipped
  irreversibility, unchanged). A spurious run_core `push_undo` would snapshot WITH the instance, so
  the undo would read 1 — that is what this detector catches.
- **(g) SHARED CORE / SIBLING UNTOUCHED**: fixture; count `xschem clear_drawing` lines; `xschem clear
  force` → still works (untitled sheet, instances==0) and logs **+0** `xschem clear_drawing` lines
  (its `clear_schematic` core calls `clear_drawing()` RAW below the boundary — the F-shared spam
  lock; a core-side log would trip this).

**Sabotages** (each targets EXACTLY ONE check; rebuild, confirm the targeted fail, `git diff` the
file, targeted `git checkout --` revert, clean green re-run):
- **(A)** drop the run_core argc gate (restore the old skip-body semantics) → (b) fails
  (extra-arg mutates and/or phantom-logs).
- **(B)** bypass the boundary in the branch (restore the raw inline `unselect_all(1);
  clear_drawing();` body) → (c) fails (read-only view emptied), AND the S1 delegation + S7 rows fail
  closed.
- **(C)** spurious `xctx->push_undo();` in the run_core arm → (f) fails (undo resurrects the
  instance).
- **(D)** `log_action("xschem clear_drawing");` inside the CORE (actions.c:1866) → (g) fails
  (`xschem clear` spams a phantom line), AND the S7 actions.c `== 0` row fails closed.

## GREP GUARD — `tests/headless/test_selflog_grep_guard.tcl`

- **ADD** an S1 scheduler.c floor row (delete-row :330 prose style):
  `{return perform_action\("clear_drawing", argc, argv\);} 1 {clear_drawing branch routes through the
  perform_action boundary (Refactor B atom 27 -- a BARE no-arg SILENT mutation gaining the log + the
  NEW readonly gate; argc==2 arity gate; core stays raw+silent below the boundary for its seven
  teardown callers; no undo anywhere -- accepted) ...}`
- **ADD** `clear_drawing` to the S2 CVERBS set (:606–620); keep it OUT of S3.
- **ADD an atom-27 S7 exact-count block** (atom-26 block :1572+ is the layout model):
  - scheduler.c `== 1` `return perform_action\("clear_drawing", argc, argv\);` (the delegation).
  - scheduler.c `== 0` `log_action\("xschem clear_drawing` (the bare form logs ONLY via
    core_log_action's default `%s` arm — no literal site may ever exist).
  - scheduler.c `== 0` `scheduler_readonly_reject\(interp, "clear_drawing"\)` (the boundary's generic
    gate is the ONLY gate — no scattered copy).
  - actions.c `== 0` `log_action\("xschem clear_drawing` (the CORE stays silent — the shared-teardown
    spam lock; sabotage D's fail-closed row).

## BUILD + AUDIT

- `cd src && make` (default cairo config). C89 — no `//` comments, decls at block top.
- Run: the new test (repo-root cwd,
  `DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) --script tests/headless/test_perform_action_clear_drawing.tcl`),
  plus siblings `test_perform_action_delete`, `test_perform_action_add_pin_stubs`,
  `test_perform_action_check_unique_names`, `test_selflog_output`, `test_selflog_grep_guard`.
- Register the new test in `tests/headless/full_audit.sh` `logdir_tests` (:40–61).
- Run `tests/headless/full_audit.sh`. **Baseline fails are pre-existing, NOT yours** (PLAN.md header,
  2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag, test_ciw,
  test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui, test_lib_sweep,
  test_phase3_mints, test_reopen_readonly, test_save_as_cellview, test_select_at, test_selflog_output,
  test_untitled_reuse, test_wire_split. ANY new fail is this atom's problem, full stop.

## DOCS

- Audit: add **§47** (atom 27) to
  `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` in the §44/§46
  house style (the silent→logged + new-gate win, the shared-teardown silent-core rule, the accepted
  no-undo irreversibility, checks, sabotages, grep rows, RECOMMENDED NEXT → the PLAN.md ledger).
  Update §46's RECOMMENDED NEXT tail.
- Update the `run_core`/`core_log_action` header-comment rosters (scheduler.c ~:191 / ~:1039).
- Decision doc: append one implementation-outcome line to
  `perform_action_atom27_clear_drawing_decision.md`'s Status section.
- NO issue-file edit (no key involved — 0068 untouched; the readonly fix is recorded in §47 like
  reset_symbol §42's, no standalone issue).
- Memory: update the `action-logging` line in MEMORY.md (atom 27 done; next = PLAN.md item 03 redo).
- PLAN.md ledger/receipt: owned by the pipeline's ledger stage — do NOT tick it yourself unless your
  driver instructs.

## CONSTRAINTS

- C89 throughout; allocations (none should be needed — no argv build, no per-verb log arm) would use
  `my_malloc`/`my_strdup` with the `_ALLOC_ID_` placeholder, never hand-numbered.
- Do NOT add push_undo/set_modify/draw to the arm or the core — behaviour-preserving migration; the
  no-undo irreversibility is accepted and locked by check (f).
- Do NOT disturb the 26 migrated verbs or their tests/guards: trim_wires(1) align(2)
  rotate_in_place(3) flip_in_place(4) flipv_in_place(5) rotate(6) flip(7) flipv(8) break_wires(9)
  floaters_from_selected_inst(10) attach_labels(11) toggle_ignore(12) reset_inst_prop(13)
  replace_symbol(14) show_unconnected_pins(15) embed_rawfile(16) wire_cut(17) apply_pin_prop(18)
  move_instance(19) image(20) change_elem_order(21) reset_symbol(22) instance_number(23) delete(24)
  add_pin_stubs(25) check_unique_names(26).
- Do NOT touch the sibling `xschem clear` verb / `clear_schematic()` or any of the seven raw C
  callers of `clear_drawing()`.
- Scope (the ONLY files you may edit): `src/scheduler.c`,
  `tests/headless/test_perform_action_clear_drawing.tcl` (new),
  `tests/headless/test_selflog_grep_guard.tcl`, `tests/headless/full_audit.sh`, the two docs files
  named above (audit + decision doc), and `MEMORY.md`. (`src/actions.c` only DURING sabotage D,
  reverted before commit.)
- ONE commit, explicit file list only. Message:
  `feat(action-log): route clear_drawing through perform_action boundary (Refactor B atom 27)`
  + a body in the atom-26 style (silent→logged coverage win, the NEW readonly gate correctness fix,
  the argc tighten, the shared-teardown silent-core rule, the accepted no-undo irreversibility),
  ending with the atom-27 line and:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
