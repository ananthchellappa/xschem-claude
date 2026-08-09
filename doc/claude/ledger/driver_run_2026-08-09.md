# Driver run 2026-08-09 — open_pdk backlog D1–D10

Status codes: **x** done+verified+committed · **F** failed (tree left clean, nothing committed) ·
**D** deferred (blocked; nothing committed) · **E** landed but needs a human eyeball
(GUI-only proof, or a user-visible behaviour change nobody ratified)

| item | status | commit | tests | new issues | one-line result |
|---|---|---|---|---|---|
| D1 (CI wiring / full_audit is_skip) | **E** | _see commit below_ | shape_draw 421→421, paste_modify 376→376, add_wire_label 178→178, placement_wire 171→171, label_ride 157→157, preview_doors 115→115, strand_oracle 32→32, sch_add_pin 21→21, instance_update 95→95, wireedit ALL PASS, run.sh 6/6, run_regression 3 known-red; NEW audit_classifier 19, descend_inert_class 107; CI gate 15/15 | 0350, 0351, 0352, 0353, 0354 | full_audit's `is_skip` is now line-anchored + failure-guarded, so 4 suites (59 checks) that were structurally incapable of failing the audit are PASS again, and 13 more suites hard-gate CI — but `is_pass` carries the *same* unanchored defect (issue 0354), so a failing suite can still be scored PASS and still count toward the new `AUDIT_MIN_PASS=15` floor. **Question for the human: keep the new CI hard gate as landed, or hold it until `is_pass` is anchored too (0354)?** |
