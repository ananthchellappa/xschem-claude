# 0126 — scripted `xschem apply_properties` mutates a read-only cell

**Status: FIXED** (2026-07-18, fluid-editing, commit `fix(readonly): reject scripted
apply_properties on read-only buffer (issue 0126)` — hash recorded in the batch memory block).
Found 2026-07-18 by the Refactor B batch item-09 scout while DEFERring the
`apply_properties` migration; standalone gate fix, independent of any boundary work.

## What changed

One line in the scheduler `apply_properties` branch (src/scheduler.c, between the `!xctx`
check and the `argc < 6` check):

```c
if(scheduler_readonly_reject(interp, "apply_properties")) return TCL_ERROR;
```

Placed BEFORE argument validation, matching the setprop/wire gate-ordering convention
(!xctx, then readonly reject, then argc parsing), so the issue-0041 guard suite's
bare-verb call gets the read-only refusal rather than the "needs:" argc error.

Live-repro facts (scout, 2026-07-18, Q1.sch): pre-fix, `xschem set readonly 1` followed by a
full-arg `apply_properties` returned rc=0 with result "1" and the instance property WAS
mutated. Aggravating: the mutation was fully silent — `set_modify()`'s `ro_suppress`
(src/actions.c:189) suppresses the modified flag on readonly buffers on the assumption that
"Genuine edits can't reach here while read-only (blocked upstream)", an assumption this verb
violated. So no '*' title marker, no autosave backup, no save-on-close prompt, and the lazy
`push_undo` inside `apply_symbol_prop` also planted a spurious undo slot.

The form's 0/1/-1 did-contract and the Tcl-side log seam (D1) are untouched: the gate returns
TCL_ERROR before the result is set, and the form self-gates (property_form.tcl:542/736 +
viewer mode) so it never issues the command when readonly. No C-side log added (a refused
call logs nothing structurally, per D1).

Tests: new tests/headless/test_apply_properties_readonly.tcl (APRO1-5, controls + refusal +
no-mutation + no-spurious-undo-slot; red-first on the unfixed binary, sabotage-verified
SB-A..SB-E) and `apply_properties` added to the issue-0041 guard suite
(tests/headless/test_readonly_guard.tcl).

Residual: none — the boundary migration for this verb stays DEFERRED per the batch receipt
(doc/claude/refactor_b_batch/receipts/09_apply_properties.md), independent of this gate.

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
