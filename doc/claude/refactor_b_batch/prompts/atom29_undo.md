# Refactor B ATOM 29 — migrate `undo` onto the perform_action boundary (the NORMALIZING-LOG-ARM twin of redo)

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are the implement stage of
Refactor B batch item 05. The scout has already verdicted PROCEED and re-verified every anchor below
from source on 2026-07-18. Atom number: **29** (the 29th per-verb migration; audit section to write:
**§49**).

The shape (decided, do not re-litigate — see the decision doc): a **full delegation with NO arity gate
and a per-verb NORMALIZING `core_log_action` arm** — the undo-family twin of redo (atom 28, §48), a
consistency-only migration with ZERO coverage gain by design. The old branch is already boundary-shaped
(inline `!xctx` guard + readonly reject + core call + unconditional log + reset-on-success); unlike
redo's fixed bare line, undo's old branch logs a **NORMALIZED** form of its two optional integer args —
atoi canonicalization (`00`→`0`), default fill (`xschem undo 1` logs `xschem undo 1 1`), tail drop
(extra words never logged) — so the log CANNOT ride the default `%s` arm nor a raw-argv passthrough: it
needs a per-verb arm that reads argv IDENTICALLY to run_core (the rotate/break_wires/attach_labels
invariant). Tolerant argc is the PRESERVED behaviour (no `if(argc==2)` skip-body ever existed — the §48
arity-gate-is-a-consequence rule). There is **NO callback.c edit**: legacy `case 'u'` plain is gone and
the `u` key is a Tcl-funneled binding that already reaches the branch.

## READ FIRST (in order)

1. `doc/claude/code_analysis/perform_action_atom29_undo_decision.md` — the decision doc (the
   normalizations §1, the arm shapes §2, the entry map §3, the guard-row hand-off from atom 28 §4).
2. `doc/claude/code_analysis/perform_action_atom28_redo_decision.md` + audit §48 — the twin this atom
   completes (its S7 rows were written to fail closed against THIS atom done wrong).
3. `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` — §4 (boundary),
   §33 (log-on-success + the Tcl_ResetResult landmine), §30/§32 (no-op-still-logs; Layer-A
   `actionlog_cmd_logged` dedup + `mutates=1`), §44-§48 (the latest shapes).
4. `doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md` §2 (contract + F-codes).
5. `doc/claude/refactor_b_batch/PLAN.md` — header rules + item 05.
6. Templates: `tests/headless/test_perform_action_redo.tcl` (the twin's test — house style AND a suite
   that must keep passing), `tests/headless/test_selflog_grep_guard.tcl` (S1 manifest :327+, S7 blocks
   :1642+).

## DISCIPLINE (non-negotiable)

Re-verify EVERY anchor below from source before editing (line numbers drift). A green suite does not
prove the changed code ran: every named sabotage must fail EXACTLY its target check, be reverted with a
targeted `git checkout -- <file>` ONLY after `git diff` confirms that file holds nothing but the
sabotage, and a clean re-run must be green. C89: declarations at block top; no `//` comments. Never
`git add -A`, `git commit -a`, `git reset --hard`, never push — stage the explicit file list only. Do
not touch the `_nhangle_*`/`_allm_*`/`_bold_*` junk dirs or any file outside the scope listed at the
end. Headless tests: each test is its own process; relative paths need repo-root cwd; a script error
idles, not hangs.

## ANCHORS (verified 2026-07-18 — re-verify, do not trust)

- **Branch**: `src/scheduler.c:11335` `else if(!strcmp(argv[1], "undo"))` inside `xschem_cmds_u`
  (fn at 11323). Body: locals `int redo = 0, set_modify = 1;` 11337; `!xctx` guard 11338; inline
  `scheduler_readonly_reject(interp, "undo")` 11339; `if(argc > 2) redo = atoi(argv[2]);` 11340-11342;
  `if(argc > 3) set_modify = atoi(argv[3]);` 11343-11345; `pop_undo_keep_selection(redo, set_modify);`
  11346; the TWO log forms 11349 (`log_action("xschem undo")`, argc==2) / 11350
  (`log_action("xschem undo %d %d", redo, set_modify)`, argc>2); `Tcl_ResetResult` 11351. NO argc gate
  anywhere (every argc executes + logs — preserve this). NO result any caller consumes (zero
  `xschem undo]` matches repo-wide; error paths return before the reset, so the boundary's success-only
  reset is observably identical). The sibling `undo_type` branch (11357+) is a DIFFERENT verb — its
  `log_action` regexes never collide with `"xschem undo"` closing-quote patterns.
- **Core**: `pop_undo_keep_selection(int redo, int set_modify)` `src/select.c:2360` (decl
  `src/xschem.h:2120`) — issue-0095 wrapper over `xctx->pop_undo` (disk `pop_undo` save.c:4134 /
  `mem_pop_undo` in_memory_undo.c:596). Undo-stack NAVIGATION — NO push_undo on this path, NONE added
  (the at-head `xctx->push_undo()` save.c:4159-4164 that arms the redo slot is the CORE's own).
  Empty-undo-stack no-op: `cur_undo_ptr == tail_undo_ptr` → return (save.c:4156) = a no-op SUCCESS the
  old branch already logged. Flag semantics save.c:4147-4172 (0/4 undo, 1 redo, 2 peek) pass through
  verbatim — `xschem undo 1 1` IS a redo wearing the undo verb, with its own distinct log line.
  **F-shared twin**: run_core's redo arm `scheduler.c:1073-1093` calls the FIXED-arg
  `pop_undo_keep_selection(1, 1)` at 1091. Exactly TWO scheduler.c call sites before AND after this
  atom — the argv-parsed site just MOVES from the branch into run_core's undo arm.
- **Boundary machinery**: `scheduler_readonly_reject` scheduler.c:173 (same fn + same `"undo"` verb
  string → byte-identical message + ciw_echo); `run_core` 225 (header roster from 191;
  `(void)argc; (void)argv;` 227; last arm `redo` ends 1093; unreachable default 1094);
  `core_log_action` 1115 (header roster 1097-1114; DEFAULT bare `%s` arm 1445-1447; the
  check_unique_names arm ends 1444); `perform_action` 1481 (log-on-success 1487-1490).
  `extern int perform_action(...)` `src/xschem.h:2134`.
- **Keys/menus — NO EDIT NEEDED (assert, don't change)**: legacy `case 'u'` plain is GONE
  (callback.c:5880-5884 comment; the surviving Alt-u=align / Ctrl-u=unselect-floaters arms 5885-5897
  never touch undo). Key `u` = `keybindings.csv:52` (`key,117,0,canvas,edit.undo,1`, idle-gated),
  seeded callback.c:4034 → Tcl-backed ActionDef callback.c:3728
  `{ "edit.undo", NULL, "xschem undo; xschem redraw", "Undo", 1 /*mutates*/ }` →
  `dispatch_input_action` callback.c:4124: read-only gate at 4136 (`action_id_mutates` +
  `readonly_block`, headless-safe callback.c:35), Layer-A wrapper log skipped when the inner log set
  `actionlog_cmd_logged` (util.c:503; log_action itself util.c:489, suppress gate 493) — the key
  records exactly ONE `xschem undo` line, never the compound, before AND after. Menu
  `src/xschem.tcl:14209` + toolbar `:12711` run the same compound (`-accelerator U` display-only);
  `actions.csv:73` is the same id's metadata. Issue 0068 NOT implicated.
- **Grep guard**: `tests/headless/test_selflog_grep_guard.tcl:333` S1 row
  `{log_action\("xschem undo"} 1 {undo branch}` — its closing-quote regex pins ONLY the bare form
  11349 (the `%d %d` form has a space after `undo`, no match); S1 rows are `>= min` FLOORS. Atom-28 S7
  rows :1659-1664: `pop_undo_keep_selection\(1, 1\)` == 1 and (semicolon-anchored)
  `pop_undo_keep_selection\(redo, set_modify\);` == 1 — both counts SURVIVE this atom (the argv-parsed
  site moves, its row's prose must follow). `undo` ALREADY in S2 CVERBS (:608), OUT of S3. S5 runtime
  canary :735 (`foreach verb {undo redo copy trim_wires}` exactly-+1) — untouched, must keep passing.
- **Existing coverage that must keep passing**: `test_perform_action_redo.tcl` — its check (g)
  (:221-223) drives `xschem undo 1 1` and pins **+1 byte-exact `xschem undo 1 1`, +0 `xschem redo`**
  (the normalizing arm reproduces this exactly); `test_selflog_output.tcl:43-44` ("raw undo
  self-logs") + :53-57 ("menu wrapper logs undo exactly once" via `menu_action_logged` — the
  `actionlog_cmd_logged` dedup, still set by core_log_action→log_action); the bare `xschem undo`
  fixture-plumbing calls across ~30 headless tests + `tests/undo_stable_ids.tcl:83` (`xschem undo 1`,
  logs `xschem undo 1 1` today — unchanged after).
- **full_audit registration**: `tests/headless/full_audit.sh` `logdir_tests` list (:40-62, currently
  ends with `test_perform_action_redo`).
- **Key injection idiom** (deterministic headless, real handle_key_press→dispatch chain):
  `xschem callback .drw 2 400 300 117 0 0 0` — keysym 117 (`u`), state 0, matches keybindings.csv:52.
  Idle-gated: inject only while `xctx->semaphore < 2`.

## DO

1. **`run_core` arm** (src/scheduler.c, after the `redo` arm ends ~1093, before the unreachable
   default ~1094):
   ```c
   else if(!strcmp(verb, "undo")) {
     /* Refactor B atom 29 (audit §49; decision doc perform_action_atom29_undo_decision.md): the
      * undo-family twin of redo (§48) -- the old branch was already boundary-shaped (inline
      * readonly reject + normalized two-form log + reset-on-success), so gate and log consolidate
      * with NO observable change. pop_undo_keep_selection(redo, set_modify) (select.c, the
      * issue-0095 selection-keeping wrapper over xctx->pop_undo) is undo-stack NAVIGATION: NO
      * push_undo is added here (the at-head push that arms the redo slot lives INSIDE the core,
      * save.c pop_undo; a spurious push here would pop back the just-pushed state = a no-op undo).
      * NO ARITY GATE -- tolerant argc is the preserved behaviour (§48 rule: an arity gate is a
      * consequence of an OLD if(argc==N) silent no-op, which undo never had); extra args are
      * consumed by the atoi defaults exactly as the old branch did. The redo flag passes through
      * verbatim (0/4 undo, 1 redo, 2 peek -- save.c), so `xschem undo 1 1` IS a redo wearing the
      * undo verb, logged as its OWN `xschem undo 1 1` line by core_log_action's NORMALIZING arm
      * (which reads argv IDENTICALLY to this parse -- the rotate/break_wires/attach_labels
      * invariant). An empty undo stack no-ops in-core (cur==tail early return) = a no-op SUCCESS
      * that still logs one idempotent line (§30). F-shared: the redo arm above calls the SAME core
      * fixed-arg (1, 1) -- distinct verb, distinct line, no double-log path; the S7 exact-count
      * rows pin both call sites (this arm is now the ONE argv-parsed site). */
     int redo = 0, set_modify = 1;
     if(argc > 2) redo = atoi(argv[2]);
     if(argc > 3) set_modify = atoi(argv[3]);
     pop_undo_keep_selection(redo, set_modify); /* issue 0007: keep selection across undo */
     return TCL_OK;
   }
   ```
   (C89: the two decls at block top. The `(void)argc; (void)argv;` at run_core's top stays — other
   arms still need it.)
2. **`core_log_action` arm** (before the default `%s` arm ~1445), the NORMALIZING two-form log:
   ```c
   } else if(!strcmp(verb, "undo")) {
     /* atom 29: NORMALIZING arm -- byte-identical to the OLD branch's two log forms at every
      * argc/argv. argv is read IDENTICALLY to run_core's undo arm (same defaults, same atoi), so
      * the logged line can never diverge from the applied pop: `xschem undo 00 01` logs
      * `xschem undo 0 1` (atoi canonicalization), `xschem undo 1` logs `xschem undo 1 1`
      * (default fill -- replay preserves DIRECTION), `xschem undo 0 1 extra` logs
      * `xschem undo 0 1` (tail drop). A raw-argv passthrough would diverge on all three; the
      * default `%s` arm would flip `xschem undo 1 1` to a bare undo on replay -- a WRONG-direction
      * replay. Reached ONLY on TCL_OK (log-on-success); bareword ints, no Tcl metachars, so
      * log_action %d is replay-safe (no Tcl_Merge needed). */
     int redo = 0, set_modify = 1;
     if(argc > 2) redo = atoi(argv[2]);
     if(argc > 3) set_modify = atoi(argv[3]);
     if(argc == 2) log_action("xschem undo");
     else          log_action("xschem undo %d %d", redo, set_modify);
   }
   ```
3. **Branch** (src/scheduler.c:11335) — collapse the body to the delegation:
   ```c
   /* undo  [redo [set_modify]]
    *   Undo last action. Optional integers redo and set_modify are passed to pop_undo()
    *   (redo: 0/4 = undo, 1 = redo, 2 = peek -- so `xschem undo 1 1` performs a redo with its
    *   own log line, distinct from the `redo` verb's).
    *   Refactor B atom 29 (audit §49): routes through the perform_action boundary. The ONE
    *   readonly gate (same scheduler_readonly_reject + "undo" verb string = byte-identical
    *   message), the argv-parsed pop_undo_keep_selection effect and the ONE NORMALIZED log site
    *   (core_log_action's undo arm: bare at argc==2, `xschem undo %d %d` else -- atoi-canonical,
    *   default-filled, tail-dropped, exactly the old branch's forms) all live in
    *   perform_action/run_core. Every entry funnels here: the `u` key is a Tcl-funneled binding
    *   (edit.undo -> `xschem undo; xschem redraw`, legacy case 'u' deleted), deduped via
    *   actionlog_cmd_logged; menu/toolbar run the same compound; scripts call the verb.
    *   Tolerant argc PRESERVED (no arity gate -- every argc executes + logs, as before). */
   else if(!strcmp(argv[1], "undo"))
   {
     return perform_action("undo", argc, argv);
   }
   ```
   Dropping: the inline `!xctx` guard, the inline `scheduler_readonly_reject(interp, "undo")`, the
   argv parse, the core call, both inline `log_action` forms and the `Tcl_ResetResult` (the boundary +
   the two arms own all of it).
4. **Rosters**: add `undo` to the run_core header comment (~191-224, note it beside redo as the
   argv-parsed twin) and to the core_log_action header comment (~1097-1114, the normalizing-arm note).
   **Update the stale F-shared prose**: run_core's redo-arm comment (~1087-1090) says the undo branch
   "STAYS RAW (batch item 05)" — rewrite that tail to name run_core's undo arm (atom 29) as the
   argv-parsed site.
5. **Keys: NO EDIT.** Do not touch callback.c, keybindings.csv, actions.csv, or xschem.tcl. The funnel
   + dedup + read-only dispatch gate are already correct (assert them in test (g)).
6. **Do NOT edit `test_perform_action_redo.tcl`**: its checks — including (g), which byte-pins the
   `xschem undo 1 1` line — must pass UNCHANGED against the migrated binary (run it; it is a live
   invariant of this atom). Its "undo stays RAW" comments are historical atom-28-time prose.

## TEST — `tests/headless/test_perform_action_undo.tcl`

House style = test_perform_action_redo.tcl (check proc, LOG guard header, byte-EXACT line counting —
count lines string-equal to `xschem undo` / `xschem undo 0 1` / `xschem undo 1 1`; full_audit
`--logdir` note). **Pin the effect oracle on the PRE-migration binary FIRST** (atom-20 discipline):
build HEAD, confirm every check below already passes (near-zero-delta — the normalized log forms, the
tolerant argc, the readonly reject and the no-op log are all today's behaviour; the delta must be
ZERO everywhere).

Fixture: fresh sheet; `xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}` (placement pushes
undo). Oracle: `xschem get instances`.

Checks (each named, each independently assertable; (e) runs FIRST while the stack is empty):
- **(e) NO-OP-STILL-LOGS**: before any placement, `xschem undo` on the EMPTY undo stack
  (`cur==tail` in-core early return) → rc TCL_OK, instances unchanged, **+1 exact-bare**
  `xschem undo` (§30; byte-identical to the old unconditional log).
- **(a) SUCCESS**: place R1; `xschem undo` → instances 1→0, rc TCL_OK, exactly **+1 byte-exact bare**
  `xschem undo`, interp result blank.
- **(b) THE HEADLINE — the NORMALIZING log arm** (four sub-checks):
  - (b1) `xschem undo 1 1` → REDOES (0→1), rc TCL_OK, **+1 exact** `xschem undo 1 1`, **+0** bare,
    **+0** `xschem redo` (pins the twin-independence AND the two-int form).
  - (b2) `xschem undo 00 01` → undoes (1→0), **+1 exact** `xschem undo 0 1`, **+0**
    `xschem undo 00 01` (atoi canonicalization).
  - (b3) `xschem undo 1` → redoes (0→1), **+1 exact** `xschem undo 1 1` (default fill — a replay of
    this line preserves the redo DIRECTION).
  - (b4) `xschem undo 0 1 extra` → undoes (1→0), rc TCL_OK, **+1 exact** `xschem undo 0 1`, **+0**
    lines containing `extra` (tolerant argc + tail drop).
- **(c) READONLY CONSOLIDATION**: read-only cell (`xschem set readonly 1` on a saved fixture, the
  delete-(c) pattern) → `xschem undo` TCL_ERROR with a NON-EMPTY message matching `*undo*read-only*`
  (the §33 landmine), no mutation, **+0** log.
- **(d) REPLAY**: a recorded `xschem undo` line re-executes through the `replay_action_log` suppress
  seam (re-applies against the ambient stack) WITHOUT re-logging; a control unwrapped `source` DOES
  re-log (+1).
- **(f) STACK ROUND-TRIP + SIBLING LOCK**: with R1 placed: `xschem undo` → 0, `xschem redo` → 1,
  twice — round-trips clean (the spurious-push detector), and the redo verb logs **+1 exact-bare**
  `xschem redo` each time with **+0** undo lines.
- **(g) KEY FUNNEL + LAYER-A DEDUP**: arm state (R1 placed); `xschem callback .drw 2 400 300 117 0 0 0`
  (key `u` through the real dispatch chain) → undo applied (1→0), **+1 exact-bare** `xschem undo`,
  **+0** lines containing `xschem undo; xschem redraw` (compound-dedup proof). Then read-only + the
  same injection → blocked at dispatch (`mutates=1` → readonly_block, headless-safe: no dialog when
  `!has_x`), no mutation, **+0** log.

**Sabotages** (each targets EXACTLY ONE check-group; rebuild, confirm the targeted fail, `git diff`
the file, targeted `git checkout --` revert, rebuild, clean green re-run):
- **(A)** bypass the boundary at the branch (restore the raw inline guard+parse+pop+log+reset body) →
  the runtime `.tcl` STILL PASSES IN FULL (the §48/§32 zero-delta lesson) while the S1 delegation row
  + the S7 scattered-log/scattered-readonly-reject rows fail closed — the grep guard is the
  load-bearing exclusivity lock. Target: grep-guard rows (record which runtime checks, if any, also
  trip).
- **(B)** spurious `xctx->push_undo();` in the run_core arm before the pop → (a) fails (instances
  stays 1 — push-then-pop restores the just-pushed state; collateral on (f)).
- **(C)** replace the normalizing arm's body with a raw-argv passthrough (`log_action_argv` of
  argc/argv) → ONLY (b2) fails (`xschem undo 00 01` logs non-normalized; exact `xschem undo 0 1` +0).
- **(D)** delete the per-verb arm (fall through to the default bare `%s`) → (b1) fails
  (`xschem undo 1 1` logs BARE; exact `xschem undo 1 1` +0; collateral (b2)/(b3)/(b4)).
- **(E)** gate the log on did-something (run_core returns TCL_ERROR when
  `xctx->cur_undo_ptr == xctx->tail_undo_ptr`) → ONLY (e) fails (+0 log, rc error — the
  no-op-still-logs discriminator).

## GREP GUARD — `tests/headless/test_selflog_grep_guard.tcl`

- **REPLACE** the S1 scheduler.c row at :333 (`{log_action\("xschem undo"} 1 {undo branch}`) with the
  delegation row, in the redo-row prose style:
  `{return perform_action\("undo", argc, argv\);} 1 {undo branch routes through the perform_action
  boundary (Refactor B atom 29 -- the undo-family twin of redo §48: the old branch was already
  boundary-shaped, gate/log/reset consolidate with no observable change; NO arity gate -- tolerant
  argc preserved; the log is core_log_action's NORMALIZING undo arm (bare at argc==2, atoi-canonical
  default-filled `xschem undo %d %d` else -- byte-identical to the old branch's two forms, and a
  replay of `xschem undo 1 1` preserves the redo direction); NO push_undo added -- undo is stack
  navigation, the at-head redo-slot push lives inside save.c pop_undo; the `u` key is a Tcl-funneled
  binding deduped via actionlog_cmd_logged, legacy case 'u' deleted)}`.
- **ADD an S7 exact-count block** (the fail-closed lock — S1 rows are `>=` floors):
  - scheduler.c `== 1` for `log_action\("xschem undo"\)` (the arm's bare form — the closing
    quote+paren regex matches neither the `%d %d` form nor `undo_type`; it must live ONLY in
    core_log_action's undo arm),
  - scheduler.c `== 1` for `log_action\("xschem undo %d %d"` (the arm's normalized form — a
    re-scattered branch log of EITHER form bumps its row),
  - scheduler.c `== 0` for `scheduler_readonly_reject\(interp, "undo"\)` (the boundary's generic
    gate covers it),
  - callback.c `== 0` for `log_action\("xschem undo"` (no key self-logs it — the `u` key funnels
    through the branch's Tcl command).
- **UPDATE the atom-28 S7 rows' prose (counts unchanged)**: the row at ~:1662
  (`pop_undo_keep_selection\(redo, set_modify\);` == 1) currently names "the RAW undo branch (batch
  item 05's scope...)" — rewrite its check-name to pin **run_core's undo arm (atom 29), the ONE
  argv-parsed site** (still semicolon-anchored so comment mentions don't count). Amend the ~:1659
  `(1, 1)` row's parenthetical and the atom-28 S1 row :334's "stays batch item 05's scope" tail the
  same way. Both counts must remain `== 1` before and after.
- `undo` STAYS in S2 CVERBS (:608) — no change; stays OUT of S3. The S5 canary (:735) is untouched
  and must keep passing.

## BUILD + AUDIT

- `cd src && make` (default cairo config). C89 — no `//` comments, decls at block top; no allocations
  anywhere in this atom (two int locals per arm; if one were ever needed it would use
  `my_malloc`/`my_strdup` with the `_ALLOC_ID_` placeholder, never hand-numbered).
- Run: the new test (repo-root cwd,
  `DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) --script tests/headless/test_perform_action_undo.tcl`),
  plus siblings `test_perform_action_redo` (MUST stay green — its check (g) byte-pins the
  `xschem undo 1 1` line this atom re-homes), `test_perform_action_delete`,
  `test_perform_action_clear_drawing`, `test_perform_action_check_unique_names`,
  `test_selflog_output`, `test_selflog_grep_guard`, `test_undo_selection`, `test_undo_link_symbols`,
  `test_undo_move_keep_selection`, `test_action_log_dispatch`, and `tests/undo_stable_ids.tcl` (the
  `xschem undo 1` machinery caller).
- Register the new test in `tests/headless/full_audit.sh` `logdir_tests` (:40-62).
- Run `tests/headless/full_audit.sh`. **Baseline fails are pre-existing, NOT yours** (PLAN.md header,
  2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag, test_ciw,
  test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui, test_lib_sweep,
  test_phase3_mints, test_reopen_readonly, test_save_as_cellview, test_select_at,
  test_selflog_output, test_untitled_reuse, test_wire_split (test_fluid_editing may flake either way
  on WSLg). ANY new fail is this atom's problem, full stop. test_selflog_output's baseline fail is
  the WSLg transform-key set — its deterministic undo checks (:43-44, :53-57) must not newly fail.

## DOCS

- Audit: add **§49** (atom 29) to
  `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` in the §48 house
  style (the normalizing-log-arm class, the tolerant-argc preservation, the entry-map/no-key-edit
  finding, the F-shared twin-rows hand-off, checks, sabotages, grep rows, RECOMMENDED NEXT → the
  PLAN.md ledger item 06 `wire`). Update §48's RECOMMENDED NEXT tail (item 05 is done).
- Update the `run_core`/`core_log_action` header-comment rosters + the redo-arm F-shared prose — part
  of DO steps 1/2/4.
- Decision doc: append one implementation-outcome line to
  `perform_action_atom29_undo_decision.md`'s Status section.
- NO issue file: 0068 is NOT implicated (the `u` key left the legacy switch in Phase 3d.2; nothing to
  close) and no new issue arises.
- Memory: update the `action-logging` line in MEMORY.md (atom 29 done; next = PLAN.md item 06 `wire`).
- PLAN.md ledger/receipt: owned by the pipeline's ledger stage — do NOT tick it yourself unless your
  driver instructs.

## CONSTRAINTS

- C89 throughout; declarations at block top; allocations (if ever needed — none are) via
  `my_malloc`/`my_strdup` with the `_ALLOC_ID_` placeholder, never hand-numbered.
- Do NOT disturb the 28 migrated verbs or their tests/guards beyond the named prose-only guard-row
  updates: trim_wires(1) align(2) rotate_in_place(3) flip_in_place(4) flipv_in_place(5) rotate(6)
  flip(7) flipv(8) break_wires(9) floaters_from_selected_inst(10) attach_labels(11) toggle_ignore(12)
  reset_inst_prop(13) replace_symbol(14) show_unconnected_pins(15) embed_rawfile(16) wire_cut(17)
  apply_pin_prop(18) move_instance(19) image(20) change_elem_order(21) reset_symbol(22)
  instance_number(23) delete(24) add_pin_stubs(25) check_unique_names(26) clear_drawing(27) redo(28).
- Do NOT touch callback.c, keybindings.csv, actions.csv, xschem.tcl, or
  tests/headless/test_perform_action_redo.tcl — this atom edits NO entry point and no sibling test.
- Scope (the ONLY files you may edit): `src/scheduler.c`,
  `tests/headless/test_perform_action_undo.tcl` (new),
  `tests/headless/test_selflog_grep_guard.tcl`, `tests/headless/full_audit.sh`, the two docs files
  named above (audit + decision-doc status line), and `MEMORY.md`.
- ONE commit, explicit file list only. Message:
  `feat(action-log): route undo through perform_action boundary (Refactor B atom 29)`
  + a body in the atom-28 style (the normalizing-log-arm class, the tolerant-argc preservation, the
  no-key-edit entry map, the F-shared twin guard-row hand-off, behaviour deltas: NONE), ending with
  the atom-29 line and:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
