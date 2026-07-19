# 0126 — scripted `xschem apply_properties` mutates a read-only cell

**Status: OPEN** (found 2026-07-18 by the Refactor B batch item-09 scout while DEFERring the
`apply_properties` migration; standalone gate fix, independent of any boundary work).

## Symptom

A CIW-typed or scripted `xschem apply_properties <ref> <new_prop> ...` edits a read-only cell.
No gate exists anywhere on the scripted path: the scheduler branch (scheduler.c:1594) and
`apply_instance_properties` (editprop.c:1094) check nothing. Only the interactive property form
self-gates (`[xschem get readonly]` at property_form.tcl:542) — so the hole is invisible in
normal GUI use and open to every replay/script/CIW path.

## Fix

A standalone `scheduler_readonly_reject(interp, "apply_properties")` at the top of the raw
branch. No query/mutate split needed: the verb is pure mutate, and no over-reject risk exists
because the form never issues the command when readonly (it self-gates first).

This does NOT require the boundary migration — that stays DEFERRED (consumed 0/1/-1 interp
result vs Tcl_ResetResult; ratified Tcl-side log site; see the batch receipt for the full
result-preserving-variant requirements).

## Cross-refs

- Batch scout receipt: doc/claude/refactor_b_batch/receipts/09_apply_properties.md
- Standing log-site decision: doc/claude/code_analysis/apply_properties_logging_decision.md (D1)
- Readonly-gate-as-correctness-fix precedents: audit §30/§38/§42
- Sibling batch-found issues: 0124 (Ctrl+Shift+H phantom log), 0125 (instance refusal set_modify)
