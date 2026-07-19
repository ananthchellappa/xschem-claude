# Item 31 descend — DEFERRED at scout stage.

fr: 99

reasons:

- DEFER TRIGGER 1 CONFIRMED (pure pass-through): the required self-logging-core variant must EXEMPT all three services perform_action exists to provide -- (a) no scheduler_readonly_reject (descend is read-only-legal navigation: no readonly gate anywhere in branch scheduler.c:2793-2832 or core actions.c:3445; descend_readonly forces readonly=1 on the child at actions.c:3638-3641 and hi_descend sets readonly post-descend at xschem.tcl:5783, so a boundary gate would refuse every browse descend); (b) no core_log_action/log-on-success (core self-logs at actions.c:3614 gated on descend_ok, actions.c:3608); (c) no Tcl_ResetResult (the dtoa(ret) result at scheduler.c:2831 is consumed live). Stripping all three leaves ONLY the !xctx guard -- which the branch ALREADY performs at scheduler.c:2797. The variant reduces to `if(!xctx) return ERR; return run_core(...)`, providing nothing the existing branch does not.

- The grep-guard invariant the plan wants to lock ALREADY HOLDS in current source and is lockable with grep rows alone, WITHOUT any migration: verified today exactly one log_action_descend("descend"...) site (actions.c:3614), ZERO 'descend' arms in run_core (scheduler.c:229-1145) or core_log_action (1146-1526), ZERO log_action in the branch (2793-2832), ZERO scheduler_readonly_reject for descend. So the guard-row value the deliverable cites cannot justify building the pass-through machinery.

- ZERO coverage gain, no gate added, no bug fixed: descend is a COMPLETED Refactor-A verb (audit section 4: 'log at the core when the core IS the verb'). The single self-log at actions.c:3614 already covers branch + 'e' key (callback.c:5127) + ctx-menu picks 12/22 (callback.c:3267/3270) + toolbar (xschem.tcl:12882) + hi_descend (xschem.tcl:5774) + hier_traversal (xschem.tcl:3701). issue 0068 lists no descend key gap. Unlike atom 26 (closed a readonly-rename bug + 0068 key gap) or atom 27 (silent->logged + NEW gate), this migration is purely cosmetic indirection.

- DEFER TRIGGER 2 (hard stop) is the only alternative to trigger 1: expressing the variant either (i) adds an exempt-mode flag/param to perform_action, WEAKENING the one-shape boundary contract (unconditional gate at scheduler.c:1531, log-on-success 1534, reset 1535) for the 29 already-migrated verbs -- an explicit hard stop -- or (ii) spawns a separate navigate-only function that merely duplicates the branch's existing !xctx guard for no benefit.

- descend does not fit run_core's contract: the branch does non-trivial pre-work run_core cannot cleanly own -- the semaphore==0 gate (scheduler.c:2798) whose blocked path returns the consumed result "0" (neither TCL_ERROR nor a logged success, a third state run_core's 'return TCL_OK' shape does not model), plus -inst name resolution (get_instance/unselect_all/select_element), n/set_title parsing, and Tcl_SetResult(dtoa(ret)). No run_core arm today sets a Tcl result or returns a non-error no-op sentinel.

- Absorb interference re-confirmed: log_action_descend (util.c:479-482) absorbs the pending select_at only on an instance-index match; ANY boundary log_action would flush it instead (util.c:496). The boundary sees only raw numeric argv (not the replay-stable name captured pre-load at actions.c:3484), so a boundary log = double-log + broken select_at absorb; a stripped core log = lost transformed -inst form + lost raw-entry coverage.

- Items 32 (descend_symbol) and 33 (go_back) AUTO-DEFER with item 31 per the plan's family rule; the pattern-extension family stops here. In-core modal dialogs (save_file_dialog actions.c:3472, input_line actions.c:3524) remain replay-nondeterministic regardless of where the log lives -- explicitly out of scope and not solved by this pattern.
