# Item 16 go_back - DEFERRED at scout stage.

fr: 99

## reasons

- Family defer trigger CONFIRMED: go_back is the third member of the descend-family (items 14+15 SETTLED) - a readonly-legal navigation composite whose core self-logs; the self-logging-core + readonly-exempt boundary variant was ratified as nonexistent, so the rank-14 automatic defer fires.
- Core tail self-log verified at actions.c:3747-3748 inside if(xctx->currsch>0) (actions.c:3653), AFTER the ask_save dialog (tcleval actions.c:3661-3663); Cancel early-returns at actions.c:3665 and the currsch==0 no-op never reaches the log - outcome-gated exactly as receipt 14 claimed, and no boundary placement can reproduce this resolved-outcome gating.
- Three raw C entries bypass the scheduler branch and are covered ONLY by the core log: Ctrl-E at callback.c:5131, BackSpace at callback.c:6370, context-menu case 14 at callback.c:3279 (wrapper string callback.c:3165 deduped via actionlog_cmd_logged). Boundary migration either strips their coverage or double-logs every Tcl-path call.
- Branch verified at scheduler.c:4789-4798 (plan's 4654 drifted): semaphore!=0 is a silent TCL_OK no-op and Tcl_ResetResult leaves no consumable result; a boundary log-on-success would phantom-log the semaphore, dialog-Cancel, and top-level no-ops because the void core reports no outcome.
- Readonly gate would over-reject: no readonly check exists anywhere in the path by design - ascending out of a read-only descend child is the descend-readonly feature's exit ramp; the boundary's all-or-nothing gate breaks it and no readonly-exempt variant exists.
- go_back-specific extras beyond the family blockers: live machinery callers depend on current branch semantics (xschem go_back 2 at xschem.tcl:3692/3695, walk-up loops at xschem.tcl:3831/3859/3882/3898/3908, window-close walk-up xschem.tcl:13213, toolbar xschem.tcl:12721); and the ask_save Yes arm nests save_schematic, coupling any boundary log to the deferred save family (items 18/19).
