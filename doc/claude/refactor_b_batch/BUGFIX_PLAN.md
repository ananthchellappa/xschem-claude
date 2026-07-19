# Mini-batch: the 5 bugs found by the Refactor B batch scouts (issues 0124-0128)

Driver: same loop as PLAN.md, pipeline = bugfix_pipeline.js (scout -> implement -> verify -> ledger).
Baseline full_audit fails = the 14-test list in PLAN.md header (recorded 2026-07-18).
Statuses: `[ ]` pending  `[x]` FIXED (committed+verified)  `[D]` deferred  `[F]` failed.

## Ledger
- [x] 1 issue-0126 apply_properties scripted readonly gap -> FIXED cdb9636d
- [x] 2 issue-0128 edit_vi_prop menu readonly gap -> FIXED bb123115
- [x] 3 issue-0124 Ctrl+Shift+H phantom-logs cancelled dialog -> FIXED e6419588
- [x] 4 issue-0127 scripted rect/arc/line coord forms: no push_undo -> FIXED de1b75d4
- [x] 5 issue-0125 instance refusal: set_modify + spurious undo -> FIXED 84890f12

## Item detail

### 1 issue-0126
- Fix shape: one `scheduler_readonly_reject(interp, "apply_properties")` at the top of the branch (scheduler.c:1594 area). Pure mutate verb, no query arm, form self-gates so no over-reject.
- Test: readonly reject (TCL_ERROR + non-empty msg + no mutation + no log) on scripted path; editable path unchanged (did-result still set, PF47/PF48 seam untouched).
- Defer triggers: any consumer relying on the silent readonly success; interaction with the property form's own gate.
- receipt: receipts/bugfix_0126.md — FIXED cdb9636d; gate in scheduler.c apply_properties branch (after !xctx, before argc<6); new test tests/headless/test_apply_properties_readonly.tcl (6 checks, RED-first) + verb added to test_readonly_guard.tcl (32 verbs); 5/5 sabotages failed exactly on target; verifier OK; only non-baseline fail = test_fluid_editing congestion flake (passes in isolation).

### 2 issue-0128
- Fix shape: one `scheduler_readonly_reject(interp, "edit_vi_prop")` at branch top (scheduler.c:3002-3008). Keys already gate via readonly_block.
- Test: readonly reject on the verb; editable path opens editor unchanged (headless: stub/guard the editor block — scout decides how to test without blocking).
- Defer triggers: headless test cannot exercise the branch without blocking on the external editor AND no safe seam exists.
- receipt: receipts/bugfix_0128.md — FIXED bb123115; gate in scheduler.c edit_vi_prop branch (after !xctx, before edit_property(1)); new test tests/headless/test_edit_vi_prop_readonly.tcl (6 checks, RED-first, editor stubbed via edit_vi_prop Tcl proc seam) + verb added to test_readonly_guard.tcl (33 verbs, inert editor stub); 4/4 sabotages failed exactly on target; verifier OK; non-baseline fails = 3 congestion flakes (all pass in isolation/retry).

### 3 issue-0124
- Fix shape: actions.csv nolog flag on the make_sch_sym_from_sel row (actions.csv:124) so the Layer-A fallback copy stops firing on Cancel; core self-log (save.c:5397) keeps covering success. NO change to C or the core log.
- Test: key-path cancel = +0 log lines; key-path success = exactly +1 (core line) — full Tk event sequence per gesture-test-full-sequence discipline; subcommand path untouched (test_selflog_output.tcl:253-277 stays green).
- Defer triggers: the nolog flag also silences a path NOT covered by the core self-log (verify actions.csv semantics first); Tk key test cannot drive the messageBox deterministically.
- receipt: receipts/bugfix_0124.md — FIXED e6419588; actions.csv:124 nolog=1 (Layer-A fallback silent, core self-log in save.c covers success from every entry point) + comment-only save.c fix; new test tests/headless/test_key_make_sch_from_sel_log.tcl (7 checks, full Tk key sequence); 3/3 sabotages failed exactly on target; verifier OK; non-baseline fails = none (4 congestion flakes all pass in isolation).

### 4 issue-0127
- Fix shape: add the missing `xctx->push_undo()` at the top of the scripted coord arms - rect (scheduler.c:8894-8915), arc (scheduler.c:2084-2098), line (scheduler.c:5774-5780) - mirroring their interactive twins (actions.c:4576/4450/4499). Sites pre-verified by receipts 25/26/30.
- Test: per shape - scripted place, one undo removes ONLY the shape (prior edit survives); second undo peels the prior edit. Watch machinery callers (create_graph.tcl/place_sym_pins.tcl loops now push N undos - scout must decide: per-call push vs first-call-only, and say why; the interactive twin pushes per gesture, so per-call is the consistent choice unless it breaks a golden test).
- Defer triggers: per-call push breaks create_save golden tests or explodes undo depth in machinery flows with no clean gate.
- receipt: receipts/bugfix_0127.md — FIXED de1b75d4; three one-line `xctx->push_undo()` insertions in scheduler.c coord arms (rect before storeobject xRECT, line before storeobject LINE, arc inside the layer-validity gate so a refused arc pushes nothing); new test tests/headless/test_scripted_shape_undo.tcl (18 checks, RED-first SSU-R2/L2/A2); 5/5 sabotages failed exactly on target; create_save outputs byte-identical pre/post fix; verifier OK; non-baseline fails = 5 congestion/WSLg flakes (pass in isolation) + test_fluid_editing FE8 pre-existing (fails identically on pre-fix rebuild). Residual: scripted `text` sibling (scheduler.c:11187, no push_undo AND no set_modify) left OPEN, recorded in issue.

### 5 issue-0125
- Fix shape TWO parts, scout may split: (a) instance branch (scheduler.c:5290-5306): capture place_symbol rc; on refusal skip set_modify(1) and return a distinguishable non-mutation result (keep TCL_OK unless a consumer contract says otherwise - scout verifies consumers first); (b) place_symbol lazy push_undo (push at actions.c:2502 moves after match_symbol at 2504, or to first-store) - touches MANY callers (interactive, add_pin_stubs, wire-stub, save.c embed), riskiest part.
- Test: (a) refusal (bad sym name) leaves modify flag clean + no spurious undo slot; success unchanged; (b) undo-depth checks across an interactive-style and scripted placement.
- Defer triggers: (b) any caller found depending on the early push ordering -> fix (a) only, record (b) residual in the issue; result-contract change needed for (a) -> defer (a) too.
- receipt: receipts/bugfix_0125.md — FIXED 84890f12; scout NARROWED to part (a) only: scheduler.c instance branch captures place_symbol rc into C89-hoisted `placed` in all 3 argc arms, gates set_modify(1) + W3 maintain_wire_segments on it, deterministic "1"/"0" Tcl result (TCL_OK kept — old result proven stale garbage nobody reads). Part (b) DROPPED as refuted (match_symbol never returns -1; empty-name bails precede the push); real residuals (scope-ammeter burnt undo slot, pinned by IR8; bbox_set reentrant alert_) recorded in the issue. New test tests/headless/test_instance_refusal.tcl (10 checks, RED-first: IR1+IR-REF red pre-fix); 6/6 sabotages failed exactly on target; verifier OK; non-baseline fails = none (5 congestion flakes pass in isolation).
