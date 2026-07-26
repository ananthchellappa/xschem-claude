# Item 33 go_back - DEFERRED (rank-31 automatic defer).

verdict: [D]
atom: none (deferred items burn no atom number)
processed-by: driver auto-defer (per DESCEND_ROUND_PROMPT.md LOOP step 2: item 31 is [D], so its
prescoped family members 32/33 auto-defer without a workflow launch)

## reason

Item 31 (descend) DEFERRED at its scout stage as a pure pass-through (the self-logging-core /
readonly-exempt boundary variant provides only the `!xctx` guard the branch already performs). The
descend-family PATTERN was never landed, and item 33 is PRE-SCOPED on it — so it auto-defers.

go_back's own posture is unchanged and independently defer-worthy:
- VOID core with a TAIL self-log at actions.c:3747-3748, inside `if(currsch>0)`, AFTER the ask_save
  dialog (tcleval actions.c:3661-3663); the Cancel path early-returns pre-log. This resolved-outcome
  tail gating is a shape no boundary log_action can reproduce — hence self-log-exempt by nature.
- Three raw C entries (Ctrl-E callback.c:5131, BackSpace callback.c:6370, ctx-menu case 14
  callback.c:3279) are covered solely by that one core self-log; a boundary migration would strictly
  regress a ratified single-site arrangement for zero coverage gain.
- Live machinery callers (xschem.tcl:3692/3695 go_back 2, walk-up loops 3831-3908, window-close
  13213, toolbar 12721) require byte-identical branch semantics — the variant logs nothing, so no new
  coupling, but also no benefit.
- ask_save dialog-Cancel nondeterminism and the save-family coupling (18/19) stay unsolved by the
  pass-through variant regardless.

Third family member; closes with the family. The descend-family pattern-extension line is now closed.
