# Item 32 descend_symbol - DEFERRED (rank-31 automatic defer).

verdict: [D]
atom: none (deferred items burn no atom number)
processed-by: driver auto-defer (per DESCEND_ROUND_PROMPT.md LOOP step 2: item 31 is [D], so its
prescoped family members 32/33 auto-defer without a workflow launch)

## reason

Item 31 (descend) DEFERRED at its scout stage: the required self-logging-core / result-preserving /
readonly-exempt boundary variant reduces to a pure pass-through — after exempting all three services
perform_action exists to provide (readonly gate, log-on-success, Tcl_ResetResult) nothing remains but
the `!xctx` guard the scheduler branch already performs. The descend-family PATTERN was therefore never
landed, and item 32 is PRE-SCOPED on that pattern.

descend_symbol's own posture is unchanged and independently defer-worthy:
- Core self-logs at save.c:5678-5679, outcome-gated (all refusal paths, incl. embedded-save cancel
  save.c:5563, return 0 pre-log) — a completed self-logging-core verb.
- The branch always Tcl_ResetResult (no consumed result), so a boundary migration gains nothing the
  core self-log does not already cover (branch + 'i' key callback.c:5261-5264 + ctx-menu pick 13
  callback.c:3275-3277 + hi_descend currsch-rise detection xschem.tcl:5747-5751).
- The embedded-symbol save leg (save.c:5558-5563) is the same in-core-modal class as descend's
  unnamed-schematic dialog — replay-nondeterministic regardless of where the log lives, out of scope.

Zero coverage gain, no gate added, no bug fixed. The rank-15 defer ("pattern does not exist") stands;
with the pattern ratified as not-worth-landing at item 31, this closes as a family member.
