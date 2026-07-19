# Refactor B ATOM 28 — migrate `redo` onto the perform_action boundary (the ZERO-DELTA consistency atom)

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are the implement stage of
Refactor B batch item 03. The scout has already verdicted PROCEED and re-verified every anchor below
from source on 2026-07-18. Atom number: **28** (the 28th per-verb migration; audit section to write:
**§48**).

The shape (decided, do not re-litigate — see the decision doc): a **bare-verb delegation with NO
arity gate and NO per-verb log arm** — the first strictly ZERO-DELTA migration. The branch is already
boundary-shaped (inline readonly reject + fixed-literal log + reset-on-success); the migration
consolidates gate and log onto the boundary with **no observable behaviour change**: the old branch
executes AND logs bare `xschem redo` at ANY argc (no `if(argc==2)` skip-body), so — unlike
delete §44 / clear_drawing §47 — there is no phantom-log hazard and an arity gate would be gratuitous
churn (the toggle_ignore §32 tolerant-argc precedent). The bare log rides `core_log_action`'s DEFAULT
`xschem %s` arm, byte-identical at every argc. Coverage gain is ZERO by design; the deliverable is
uniformity + the S7 fail-closed exclusivity lock. There is **NO callback.c edit**: the legacy
`case 'U'` is gone and the Shift+U key is a Tcl-funneled binding that already reaches the branch.

## READ FIRST (in order)

1. `doc/claude/code_analysis/perform_action_atom28_redo_decision.md` — the decision doc (anchors,
   the tolerant-argc decision §2, the entry map §3, the F-shared guard-row story §4).
2. `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` — §4 (boundary),
   §33 (log-on-success + the Tcl_ResetResult landmine), §30/§32 (no-op-still-logs; the Layer-A
   `actionlog_cmd_logged` dedup + `mutates=1` rules), §44/§45/§46/§47 (the latest shapes).
3. `doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md` §2 (the current
   contract + F-codes).
4. `doc/claude/refactor_b_batch/PLAN.md` — header rules + item 03 + item 05 (`undo`, the twin that
   STAYS RAW this atom).
5. Templates: `tests/headless/test_perform_action_delete.tcl` (bare-verb atom test house style),
   `tests/headless/test_perform_action_clear_drawing.tcl` (atom-27 sibling),
   `tests/headless/test_selflog_grep_guard.tcl` (S1 manifest :327+, S7 block :786+).

## DISCIPLINE (non-negotiable)

Re-verify EVERY anchor below from source before editing (line numbers drift). A green suite does not
prove the changed code ran: every named sabotage must fail EXACTLY its target check, be reverted with
a targeted `git checkout -- <file>` ONLY after `git diff` confirms that file holds nothing but the
sabotage, and a clean re-run must be green. C89: declarations at block top. Never `git add -A`,
`git commit -a`, `git reset --hard`, never push — stage the explicit file list only. Do not touch the
`_nhangle_*`/`_allm_*`/`_bold_*` junk dirs or any file outside the scope listed at the end. Headless
tests: each test is its own process; relative paths need repo-root cwd; a script error idles, not
hangs.

## ANCHORS (verified 2026-07-18 — re-verify, do not trust)

- **Branch**: `src/scheduler.c:8861` `else if(!strcmp(argv[1], "redo"))` inside `xschem_cmds_r`
  (fn at 8276). Body: `!xctx` guard 8863; inline `scheduler_readonly_reject(interp, "redo")` 8864;
  `pop_undo_keep_selection(1, 1)` 8865; `log_action("xschem redo")` 8866; `Tcl_ResetResult` 8867.
  NO argc handling anywhere (extra args execute + log bare TODAY — preserve this). NO result any
  caller consumes (zero `[xschem redo]` matches repo-wide; the old branch already reset-on-success,
  so the boundary's success-only reset is observably identical; `test_selflog_output.tcl:61–63`
  reads the `-emitted` FLAG after `xschem redo`, not the interp result — still set via
  `core_log_action`→`log_action`, util.c:503).
- **Core**: `pop_undo_keep_selection(int redo, int set_modify)` `src/select.c:2360` (decl
  `src/xschem.h:2120`) — issue-0095 wrapper over `xctx->pop_undo` (disk `pop_undo` save.c:4134 /
  `mem_pop_undo` in_memory_undo.c:596). NO push_undo on this path (a redo is stack navigation);
  `set_modify` is passed INTO the core (select.c:2395); disk redo with an empty redo stack
  early-returns (save.c:4147–4154) = a no-op SUCCESS the old branch already logged. **SECOND call
  site — the F-shared twin**: the `undo` branch `scheduler.c:11303–11320` (in `xschem_cmds_u`)
  calls `pop_undo_keep_selection(redo, set_modify)` at 11314 with argv-parsed ints — so
  `xschem undo 1 1` performs a redo through the RAW undo branch with its OWN `xschem undo %d %d`
  log (11317/11318). That branch STAYS RAW (batch item 05's scope). Exactly TWO
  `pop_undo_keep_selection` call sites in scheduler.c, before and after this atom.
- **Boundary machinery**: `scheduler_readonly_reject` scheduler.c:173 (same fn + same `"redo"` verb
  string the branch passes today → byte-identical message + ciw_echo); `run_core` 219 (header
  roster comment from 191; `(void)argc; (void)argv;` at 221; last arm `clear_drawing` ends 1066;
  unreachable default 1067); `core_log_action` 1087 (header roster 1070–1075; DEFAULT bare
  `log_action("xschem %s", verb)` arm 1417–1419); `perform_action` 1453 (log-on-success 1459 +
  success-only Tcl_ResetResult 1461). `extern int perform_action(...)` `src/xschem.h:2134`.
- **Keys/menus — NO EDIT NEEDED (assert, don't change)**: legacy `case 'U'` is GONE
  (callback.c:5901–5903 comment only). Shift+U = `keybindings.csv:51`
  (`key,85,0,canvas,edit.redo,1` — keysym 85, mods 0 because printable keysyms strip ShiftMask:
  callback.c:4884 `kmods = (key < 0xff00) ? rstate : state`; idle-gated) → Tcl-backed ActionDef
  callback.c:3727 `{ "edit.redo", NULL, "xschem redo; xschem redraw", "Redo", 1 /*mutates*/ }` →
  `dispatch_input_action` callback.c:4124: read-only gate at 4136 (`action_id_mutates` +
  `readonly_block`, headless-safe callback.c:35), Tcl eval 4156, Layer-A wrapper log 4162 skipped
  when the inner branch log set `actionlog_cmd_logged` (util.c:503) — the key records exactly ONE
  bare `xschem redo`, never the compound, before AND after. Menu `src/xschem.tcl:14210` + toolbar
  `12712` run the same plain compound (`-accelerator {Shift+U}` display-only); `actions.csv:74` is
  the same id's metadata row (idle=1, nolog empty).
- **Grep guard**: `tests/headless/test_selflog_grep_guard.tcl:334` S1 row
  `{log_action\("xschem redo"} 1 {redo branch}` (S1 rows are `>= min` FLOORS — the fail-closed lock
  is the NEW S7 block; S7 starts :786). `redo` ALREADY in S2 CVERBS (:608) and OUT of S3 — keep
  both. S5 runtime canary :735 (`foreach verb {undo redo copy trim_wires}` exactly-+1) — untouched,
  must keep passing. The undo S1 row :333 `{log_action\("xschem undo"}` pins 11317 only (its
  closing-quote regex does not match the `%d %d` form) — untouched.
- **Existing coverage that must keep passing**: `test_selflog_output.tcl:45–46` ("raw redo
  self-logs"), :61–63 (`-emitted` flag after `xschem redo`); the many bare `xschem redo` drivers in
  `test_undo_selection.tcl:44`, `test_undo_link_symbols.tcl:64`, `tests/stable_handles/*`,
  `tests/undo_link_child/drive.tcl:10`.
- **full_audit registration**: `tests/headless/full_audit.sh` `logdir_tests` list (:40+).
- **Key injection idiom** (deterministic headless, real handle_key_press→dispatch chain):
  `xschem callback .drw 2 400 300 85 0 0 0` — keysym 85 with state 0 matches the mods-0 binding row
  (ShiftMask is stripped for printable keysyms anyway). The binding is idle-gated: inject only while
  `xctx->semaphore < 2` (normal idle).

## DO

1. **`run_core` arm** (src/scheduler.c, after the `clear_drawing` arm ~1066, before the unreachable
   default):
   ```c
   else if(!strcmp(verb, "redo")) {
     /* Refactor B atom 28 (audit §48; decision doc perform_action_atom28_redo_decision.md): the
      * ZERO-DELTA consistency migration -- the old branch was already boundary-shaped (inline
      * readonly reject + fixed bare log + reset-on-success), so this arm changes NOTHING
      * observable. pop_undo_keep_selection(1,1) (select.c, the issue-0095 selection-keeping
      * wrapper over xctx->pop_undo) is undo-stack NAVIGATION: NO push_undo exists on this path
      * and NONE is added (a push here would fire at cur<head and TRUNCATE the redo tail --
      * save.c push_undo snaps head=++cur -- turning every redo into a no-op); set_modify is
      * passed INTO the core. NO ARITY GATE -- deliberately unlike delete (§44)/clear_drawing
      * (§47), whose OLD branches were if(argc==2) silent no-ops (phantom-log hazard): redo's old
      * branch EXECUTES and logs bare at ANY argc, so tolerant argc is the preserved behaviour
      * (the toggle_ignore §32 precedent) and the DEFAULT `xschem %s` log arm keeps the line
      * byte-identical bare at every argc. An empty redo stack early-returns in-core = a no-op
      * SUCCESS that still logs one idempotent line (§30) -- byte-identical to the old
      * unconditional log. F-shared: the RAW undo branch (xschem_cmds_u) calls
      * pop_undo_keep_selection(redo, set_modify) with argv-parsed ints (`xschem undo 1 1` = a
      * redo with its OWN `xschem undo %d %d` log) -- it STAYS RAW (batch item 05), distinct
      * verb, distinct line, no double-log path; the S7 exact-count rows lock both call sites. */
     pop_undo_keep_selection(1, 1); /* issue 0007: keep selection across redo */
     return TCL_OK;
   }
   ```
2. **`core_log_action`: NO new arm.** The bare form rides the DEFAULT `log_action("xschem %s",
   verb)` arm (~1417). Add `redo` to the bare-verb roster in the core_log_action header comment
   (~1070–1075) and to the run_core header roster (~191–218) — the two rosters are the ONLY
   core_log_action-side edits (the clear_drawing §47 pattern).
3. **Branch** (src/scheduler.c:8861) — collapse the body to the delegation:
   ```c
   /* redo
    *   Redo last undone action.
    *   Refactor B atom 28 (audit §48): routes through the perform_action boundary. The ONE
    *   readonly gate (same scheduler_readonly_reject + "redo" verb string = byte-identical
    *   message), the pop_undo_keep_selection(1,1) effect and the ONE bare `xschem redo` log
    *   site (core_log_action's DEFAULT %s arm) all live in perform_action/run_core. Every
    *   entry funnels here: the Shift+U key is a Tcl-funneled binding (edit.redo ->
    *   `xschem redo; xschem redraw`, legacy case 'U' deleted), deduped via
    *   actionlog_cmd_logged; menu/toolbar run the same compound; scripts call the verb.
    *   Tolerant argc PRESERVED (extra args execute + log bare, as before -- no arity gate). */
   else if(!strcmp(argv[1], "redo"))
   {
     return perform_action("redo", argc, argv);
   }
   ```
   Dropping: the inline `!xctx` guard (boundary line 1456, same `not_avail` string), the inline
   `scheduler_readonly_reject(interp, "redo")`, the inline `log_action("xschem redo")` and the
   `Tcl_ResetResult` (boundary owns all four).
4. **Keys: NO EDIT.** Do not touch callback.c, keybindings.csv, actions.csv, or xschem.tcl. The
   funnel + dedup + read-only dispatch gate are already correct (assert them in test (h)).
5. **Do NOT touch the undo branch** (scheduler.c:11303–11320) — it is batch item 05's scope. Its
   raw `pop_undo_keep_selection(redo, set_modify)` call and both its log forms stay byte-identical.

## TEST — `tests/headless/test_perform_action_redo.tcl`

House style = test_perform_action_delete.tcl (check proc, LOG guard header, byte-EXACT line counting
— count lines string-equal to `xschem redo`, so the extra-arg check can also assert +0
`xschem redo extra` lines; full_audit `--logdir` note). **Pin the effect oracle on the PRE-migration
binary FIRST** (atom-20 discipline): build HEAD, confirm the fixture below redoes (instances 0→1),
that `xschem redo extra` ALSO redoes and logs bare, and that read-only `xschem redo` already errors
with the read-only message (consolidation, not a new gate — the delta must be ZERO everywhere).

Fixture: fresh sheet; `xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}` (placement pushes
undo); `xschem undo` (instances 1→0) arms a redo slot. Oracle: `xschem get instances`.

Checks (each named, each independently assertable):
- **(a) SUCCESS**: `xschem redo` → instances 0→1, rc TCL_OK, exactly **+1 byte-exact bare**
  `xschem redo`, interp result blank.
- **(b) TOLERANT EXTRA-ARG + BARE LOG FORM** (the zero-delta headline): re-arm (`xschem undo`);
  `xschem redo extra` → STILL executes (0→1), rc TCL_OK, **+1 exact-bare** `xschem redo`, **+0**
  `xschem redo extra` lines. Pins the no-arity-gate decision AND the default-`%s` byte-identical
  log shape.
- **(c) READONLY CONSOLIDATION**: read-only cell (`xschem set readonly 1` on a saved fixture, the
  delete-(c) pattern) → `xschem redo` TCL_ERROR with a NON-EMPTY message matching
  `*redo*read-only*` (the §33 landmine: the success-only reset must not wipe it), no mutation,
  **+0** log.
- **(d) REPLAY**: the recorded `xschem redo` re-executes through the `replay_action_log` suppress
  seam (re-applies against the ambient stack) WITHOUT re-logging; a control unwrapped `source`
  DOES re-log.
- **(e) NO-OP-STILL-LOGS**: with an EMPTY redo stack (fresh state, nothing undone), `xschem redo`
  → rc TCL_OK, instances unchanged, **+1** exact-bare line (byte-identical to the old
  unconditional log; §30).
- **(f) STACK NEUTRALITY**: after (a): `xschem undo` → 0, `xschem redo` → 1 again (round-trip). A
  spurious run_core push_undo would truncate the redo tail (push at cur<head snaps head=++cur,
  save.c:4115–4116) and leave instances at 0 — the (B) sabotage's detector.
- **(g) SIBLING RAW — the F-shared lock**: arm a redo slot; `xschem undo 1 1` redoes via the RAW
  undo branch → instances restored, **+1** `xschem undo 1 1`, **+0** `xschem redo`.
- **(h) KEY FUNNEL + LAYER-A DEDUP**: arm a redo slot; `xschem callback .drw 2 400 300 85 0 0 0`
  (Shift+U through the real dispatch chain) → redo applied, **+1 exact-bare** `xschem redo`, **+0**
  lines containing `xschem redo; xschem redraw` (the compound-dedup proof). Then read-only + the
  same injection → blocked at dispatch (`mutates=1` → readonly_block, headless-safe: no dialog when
  `!has_x`), no mutation, **+0** log.

**Sabotages** (each targets EXACTLY ONE check-group; rebuild, confirm the targeted fail, `git diff`
the file, targeted `git checkout --` revert, rebuild, clean green re-run):
- **(A)** bypass the boundary at the branch (restore the raw inline gate+pop+log+reset body) → the
  runtime `.tcl` may STILL PASS (the §32 sabotage-2 lesson) while the S1 delegation row + the S7
  scattered-log + scattered-readonly-reject rows fail closed — the grep guard is the load-bearing
  exclusivity lock. Target: grep-guard rows (record which runtime checks, if any, also trip).
- **(B)** spurious `xctx->push_undo();` in the run_core arm before the pop → (a)/(f) fail
  (instances stays 0 — the truncated-redo-tail detector).
- **(C)** add a per-verb raw-argv log arm to core_log_action (`log_action_argv` passthrough of
  argc/argv for "redo") → (b) fails (`xschem redo extra` logs a non-bare line; exact-bare +0).
- **(D)** gate the log on did-something (run_core returns TCL_ERROR when
  `xctx->cur_undo_ptr >= xctx->head_undo_ptr`) → (e) fails (+0 log, rc error) — the
  no-op-still-logs discriminator.

## GREP GUARD — `tests/headless/test_selflog_grep_guard.tcl`

- **REPLACE** the S1 scheduler.c row at :334 (`{log_action\("xschem redo"} 1 {redo branch}`) with
  the delegation row, in the delete-row prose style:
  `{return perform_action\("redo", argc, argv\);} 1 {redo branch routes through the perform_action
  boundary (Refactor B atom 28 -- the ZERO-DELTA consistency migration: the old branch was already
  boundary-shaped, so gate/log/reset consolidate with no observable change; NO arity gate --
  tolerant argc preserved, bare log via core_log_action's %s default at every argc; NO push_undo
  anywhere -- a redo is stack navigation and a push would truncate the redo tail; the Shift+U key
  is a Tcl-funneled binding deduped via actionlog_cmd_logged, legacy case 'U' deleted)}`.
- **ADD an S7 exact-count block** (the fail-closed lock — S1 rows are `>=` floors):
  - scheduler.c `== 0` for `log_action\("xschem redo"` (the bare form lives ONLY in the default
    `%s` arm; no literal may reappear at branch or arm),
  - scheduler.c `== 0` for `scheduler_readonly_reject\(interp, "redo"\)` (the boundary's generic
    gate covers it),
  - scheduler.c `== 1` for `pop_undo_keep_selection\(1, 1\)` (the run_core redo arm — the ONLY
    fixed-arg site; a routed copy inside the undo branch would double-log and bumps this),
  - scheduler.c `== 1` for `pop_undo_keep_selection\(redo, set_modify\)` (the RAW undo branch —
    batch item 05's scope, the F-shared lock: it must neither disappear nor route this atom),
  - callback.c `== 0` for `log_action\("xschem redo"` (no key self-logs it — the U key funnels
    through the branch's Tcl command).
- `redo` STAYS in S2 CVERBS (:608) — no change; stays OUT of S3. The S5 canary (:735) and the S1
  undo row (:333) are untouched.

## BUILD + AUDIT

- `cd src && make` (default cairo config). C89 — no `//` comments, decls at block top.
- Run: the new test (repo-root cwd,
  `DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) --script tests/headless/test_perform_action_redo.tcl`),
  plus siblings `test_perform_action_delete`, `test_perform_action_clear_drawing`,
  `test_perform_action_check_unique_names`, `test_perform_action_toggle_ignore`,
  `test_selflog_output`, `test_selflog_grep_guard`, `test_undo_selection`,
  `test_undo_link_symbols`, `test_action_log_dispatch`.
- Register the new test in `tests/headless/full_audit.sh` `logdir_tests` (:40+).
- Run `tests/headless/full_audit.sh`. **Baseline fails are pre-existing, NOT yours** (PLAN.md
  header, 2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag, test_ciw,
  test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui, test_lib_sweep,
  test_phase3_mints, test_reopen_readonly, test_save_as_cellview, test_select_at,
  test_selflog_output, test_untitled_reuse, test_wire_split (test_fluid_editing may flake either
  way on WSLg). ANY new fail is this atom's problem, full stop. test_selflog_output's baseline fail
  is the WSLg transform-key set — its deterministic redo checks (:45–46, :61–63) must not newly
  fail.

## DOCS

- Audit: add **§48** (atom 28) to
  `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` in the §47
  house style (the zero-delta class, the tolerant-argc decision, the entry-map/no-key-edit finding,
  the F-shared undo-twin guard rows, checks, sabotages, grep rows, RECOMMENDED NEXT → the PLAN.md
  ledger item 04). Update §47's RECOMMENDED NEXT tail.
- Update the `run_core`/`core_log_action` header-comment rosters (scheduler.c ~191/~1070) — part of
  DO step 2.
- Decision doc: append one implementation-outcome line to
  `perform_action_atom28_redo_decision.md`'s Status section.
- NO issue file: 0068 is NOT implicated (the U key left the legacy switch in Phase 3d.2; nothing to
  close) and no new issue arises.
- Memory: update the `action-logging` line in MEMORY.md (atom 28 done; next = PLAN.md item 04
  `get_additional_symbols`).
- PLAN.md ledger/receipt: owned by the pipeline's ledger stage — do NOT tick it yourself unless
  your driver instructs.

## CONSTRAINTS

- C89 throughout; NO allocations should be needed anywhere in this atom (no flag arrays, no heap
  argv — the log is the default `%s` arm); if one were ever needed it would use
  `my_malloc`/`my_strdup` with the `_ALLOC_ID_` placeholder, never hand-numbered.
- Do NOT disturb the 27 migrated verbs or their tests/guards: trim_wires(1) align(2)
  rotate_in_place(3) flip_in_place(4) flipv_in_place(5) rotate(6) flip(7) flipv(8) break_wires(9)
  floaters_from_selected_inst(10) attach_labels(11) toggle_ignore(12) reset_inst_prop(13)
  replace_symbol(14) show_unconnected_pins(15) embed_rawfile(16) wire_cut(17) apply_pin_prop(18)
  move_instance(19) image(20) change_elem_order(21) reset_symbol(22) instance_number(23) delete(24)
  add_pin_stubs(25) check_unique_names(26) clear_drawing(27).
- Do NOT touch the `undo` branch (batch item 05), callback.c, keybindings.csv, actions.csv or
  xschem.tcl — this atom edits NO entry point.
- Scope (the ONLY files you may edit): `src/scheduler.c`,
  `tests/headless/test_perform_action_redo.tcl` (new),
  `tests/headless/test_selflog_grep_guard.tcl`, `tests/headless/full_audit.sh`, the two docs files
  named above (audit + decision-doc status line), and `MEMORY.md`.
- ONE commit, explicit file list only. Message:
  `feat(action-log): route redo through perform_action boundary (Refactor B atom 28)`
  + a body in the atom-27 style (the zero-delta consistency class, the tolerant-argc decision, the
  no-key-edit entry map, the F-shared undo-twin guard rows, behaviour deltas: NONE), ending with
  the atom-28 line and:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
