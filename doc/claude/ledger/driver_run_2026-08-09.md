# Driver run 2026-08-09 — open_pdk backlog D1–D10

Status codes: **x** done+verified+committed · **F** failed (tree left clean, nothing committed) ·
**D** deferred (blocked; nothing committed) · **E** landed but needs a human eyeball
(GUI-only proof, or a user-visible behaviour change nobody ratified)

| item | status | commit | tests | new issues | one-line result |
|---|---|---|---|---|---|
| D1 (CI wiring / full_audit is_skip) | **E** | _see commit below_ | shape_draw 421→421, paste_modify 376→376, add_wire_label 178→178, placement_wire 171→171, label_ride 157→157, preview_doors 115→115, strand_oracle 32→32, sch_add_pin 21→21, instance_update 95→95, wireedit ALL PASS, run.sh 6/6, run_regression 3 known-red; NEW audit_classifier 19, descend_inert_class 107; CI gate 15/15 | 0350, 0351, 0352, 0353, 0354 | full_audit's `is_skip` is now line-anchored + failure-guarded, so 4 suites (59 checks) that were structurally incapable of failing the audit are PASS again, and 13 more suites hard-gate CI — but `is_pass` carries the *same* unanchored defect (issue 0354), so a failing suite can still be scored PASS and still count toward the new `AUDIT_MIN_PASS=15` floor. **Question for the human: keep the new CI hard gate as landed, or hold it until `is_pass` is anchored too (0354)?** |
| D1b (driver misdispatch — crew ran unbriefed and continued D1's audit-classifier work; issue 0263 NOT touched) | E | 825d69ce | shape_draw 421->421, paste_modify_0244 376->376, add_wire_label 178->178, placement_wire_gate 171->171, label_ride 157->157, preview_doors 115->115, strand_oracle 32->32, sch_add_pin 21->21, instance_update 95->95, audit_classifier 19->49, wire_split/crossview OVERALL ok, wireedit ALL PASS, run.sh 6 goldens HARNESS PASS, run_regression exactly 3 known FAIL, CI headless gate 15 pass 0 fail ec=0 | 0355, 0356, 0357 | Widen full_audit's leak arm to see gitignored *~.sch/*~.sym backups (which re-introduces the name-guessing this item exists to remove), or accept permanently that issue 0356's emitter is undetectable by it? |
| D2 | E | ee290c5b | placement_preview_doors 115->177, shape_draw 421->421, paste_modify_0244 376->376, add_wire_label 178->178, placement_wire_gate 171->171, label_ride 157->157, strand_oracle 32->32, sch_add_pin 21->21, wire_split/crossview_paste/instance_update ok, wireedit ALL PASS, run.sh 6 goldens PASS, run_regression exactly 3 known-red FAILs | 0358, 0359, 0360, 0361 | Should a READ verb (`netlist`, and by extension `save`) end a live placement/paste gesture at all, or should the gesture survive the read? |
| D3 | F | 80979605 | shape_draw 421->421, paste_modify_0244 376->376, add_wire_label 178->178, placement_wire_gate 171->171, label_ride 157->157, preview_doors 177->177 (doc baseline 115 is stale), strand_oracle 32->32, sch_add_pin 21->21, instance_update 95->95, wireedit ALL PASS, run.sh 6 goldens HARNESS PASS, run_regression exactly 3 known-red; attempt-only backup_recovery 3 FAILED->22 PASS and hier_close_prompt 2  | 0362, 0363, 0364, 0365 | 0264 is now MEASURED (3 repros, real content loss, 0 prompts) and its severity raised to High, but the fix was refuted and reverted -- no source change landed; next attempt should ship the ~3-line clear_schematic guard alone and put the predicate behind 0362. |
| D4 | E | b1326180 | shape_draw 421->421, paste_modify 376->376, add_wire_label 178->178, placement_wire_gate 171->171, label_ride 157->157, preview_doors 177->177, strand_oracle 32->32, sch_add_pin 21->21, wire_split/crossview_paste/instance_update ok, wireedit ALL PASS, run.sh 6 goldens PASS, run_regression 3->3 pre-existing FAIL; NEW descend_symbol 32, inert_class 177, refusal_channel_0251 34, ctx_menu_0249 6 (xvfb | 0366,0367,0368,0369,0370,0371,0372,0373 | Is turning `xschem descend_symbol` from a value-less command into one that evaluates to "1"/"0" acceptable, given out-of-tree rc/PDK glue cannot be audited from here and a user script written as `if {[xschem descend_symbol] eq {}}` would silently invert? |
| D5 (attempt 1, VOID — API transport death in the Plan agent, not a result; rerun resumed from cache) | F | none | not reached | none | crew aborted: plan produced nothing |
| D5 | F | 504e38c7 | REVERTED so all back to baseline: shape_draw 421->421, doors 177->177, inert_class 177->177, refusal_channel_0251 34->34 (fix had measured 67), descend_symbol 32->32 (fix 38), log_absorb 25->25 (fix 29), wireedit ALL PASS, harness PASS, regression 3 known-red | 0378,0379,0380,0381 (plus planner stubs 0374,0375,0376,0377 committed) | Fix built and measured green, then REVERTED IN FULL: the 0252 chooser filter deletes the create-the-child-by-descending workflow whenever an instance is selected; src/ is byte-identical to b1326180 and only doc/claude write-ups are committed. |
| D6 | E | 5c5671b5 | descend_symbol 32->38, refusal_channel_0251 34->45, hi_descend 18->24, cadence_descend_newwin_ro 5->11 (+2 GATE-brace by write-up), cmdmode_descend_0201 +19 MS rows xvfb ALL PASS; tiers unchanged: shape_draw 421, paste_modify 376, add_wire_label 178, placement_wire 171, label_ride 157, preview_doors 177, strand_oracle 32, sch_add_pin 21, instance_update 95, inert_class 177, log_absorb 23, WIREEDIT | 0382, 0383, 0384, 0385, 0386, 0387, 0388, 0389, 0390, 0391, 0392 | Alt+Shift+I on a .sym already open in THIS process now refuses out loud (returns 3, holds a message) instead of spawning a second editable copy - is refuse-and-say-why right, or should it spawn the second process? |
| D7 | E | 2f866dec | shape_draw 421->421, paste_modify 376->376, placement_wire_gate 171->187, add_wire_label 178->182, sch_add_pin 21->25, create_instance 56->72, preview_doors 177->177, label_ride 157, strand_oracle 32, instance_update 95, inert_class 177, descend_symbol 38, refusal_0251 45, hi_descend 24, cadence_newwin_ro 11, log_absorb 23->23, wire_split/crossview ok, wireedit ALL PASS, run.sh 6/6, run_regression | 0393, 0394, 0395, 0396 | With a placement form open, Escape (canvas OR focus still in the form) now runs the full C terminal, so it also sets tclstop=1 (stopping a running simulation) and deselects for escape_deselects=1 users, while the Close button still does not — ratified, or should the form path forward only the abort and skip tclstop? |
| D8 (attempt 1, VOID — API transport death in the write-up agent, not a result; rerun resumed from cache) | F | none | not reached | none | crew aborted before write-up |
| D8 | E | 9e51b4c8 | preview_doors 177->206, shape_draw 421->421, paste_modify 376->376, add_wire_label 182->182, placement_wire_gate 187->187, label_ride 157, strand_oracle 32, sch_add_pin 25, instance_update 95, inert_class 177, descend_symbol 38, refusal_0251 45, hi_descend 24, cadence_newwin_ro 11, log_absorb 23, wireedit ALL PASS, run.sh 6/6, run_regression 3 known-red | 0397, 0398, 0399, 0400 | A stuck placement preview now self-repairs (3 flags + one status line) at the next command/event entry instead of leaving the canvas dead for the session, but it deletes nothing — is "repair the flags, keep the object, say so once" right, given the kept object renames a net while `modified` can still read 0 (issue 0398), or should the repair also delete the orphan and accept a deferred delete() be |
| D9 | x | d99f3791 | add_wire_label 182->196, sch_add_pin 25->34, lib_symbol_view 12->14, shape_draw 421->421, paste_modify 376->376, placement_wire_gate 187->187, preview_doors 206->206, label_ride 157->157, strand_oracle 32->32, instance_update 95->95, create_instance 72->72(xvfb), descend tiers 177/38/45/24/11/23 unchanged, wireedit ALL PASS, run.sh HARNESS PASS, run_regression exactly 3 known-red | 0401, 0402, 0403 | `::sympin_place` deleted at all 4 sites; the commit-funnel drop witness is now split per owner in C (sympin_drops_pin/_label via wirelabel_preview), so a sibling form's drop can no longer drain a queue, and the 0122-E1 pause is reachable again. |
| D10 | E | dd5ca7b8 | paste_modify_0244 376->444, readonly_guard 11->13 ok, shape_draw 421->421, add_wire_label 196, placement_wire_gate 187, label_ride 157, preview_doors 206, strand_oracle 32, sch_add_pin 34, instance_update 95, wireedit ALL PASS, run.sh 6 goldens PASS, run_regression exactly 3 known FAIL | 0404,0405,0406,0407,0408,0409 | Should `xschem move_objects <garbage>` raise a Tcl error -- aborting a user's .tcl/xschemrc script or an action-log replay at that line, where it previously ran on past a silent no-op -- rather than keep arming a deferred menu move? (the crew implemented the error; no shipped call site, menu, keybinding, emitted log line or gold fixture passes a bad slot) |

## Close-out

Run complete: D1–D10 all dispatched, all returned a receipt, all rows landed.

### Counts (11 result rows; the 2 VOID rows are transport deaths, not results)

- **x** (done, verified, committed, nothing to ratify): **1** — D9
- **E** (landed, needs a human eyeball): **8** — D1, D1b, D2, D4, D6, D7, D8, D10
- **F** (failed; tree left clean, no source change): **2** — D3, D5
- **D** (deferred): **0**
- VOID (API transport death mid-crew, rerun from cache): 2 — D5 attempt 1, D8 attempt 1

Commits, in order: `118d6937` (D1), `825d69ce` (D1b), `ee290c5b` (D2), `80979605` (D3, docs only),
`b1326180` (D4), `504e38c7` (D5, docs only), `5c5671b5` (D6), `2f866dec` (D7), `9e51b4c8` (D8),
`d99f3791` (D9), `dd5ca7b8` (D10). Nothing pushed; no PR opened.

### Questions awaiting a human — one per E item

1. **D1** — Keep the new `AUDIT_MIN_PASS=15` CI hard gate as landed, or hold it until `is_pass` is line-anchored too (issue 0354)? As shipped, a failing suite can still be scored PASS and still count toward the floor.
2. **D1b** — Widen `full_audit`'s leak arm to see gitignored `*~.sch` / `*~.sym` backups (re-introducing the filename guessing that item existed to remove), or accept permanently that issue 0356's emitter is invisible to it?
3. **D2** — Should a READ verb (`netlist`, and by extension `save`) end a live placement/paste gesture at all, or should the gesture survive the read?
4. **D4** — Is turning `xschem descend_symbol` from a value-less command into one that evaluates to `"1"`/`"0"` acceptable, given out-of-tree rc/PDK glue cannot be audited from here and a user script written as `if {[xschem descend_symbol] eq {}}` would silently invert?
5. **D6** — Alt+Shift+I on a `.sym` already open in THIS process now refuses out loud (returns 3, holds a message) instead of spawning a second editable copy — is refuse-and-say-why right, or should it spawn the second process?
6. **D7** — With a placement form open, Escape now runs the full C terminal, so it also sets `tclstop=1` (stopping a running simulation) and deselects for `escape_deselects=1` users, while the Close button still does not — ratified, or should the form path forward only the abort and skip `tclstop`?
7. **D8** — A stuck placement preview now self-repairs (3 flags + one status line) but deletes nothing: is "repair the flags, keep the object, say so once" right, given the kept object renames a net while `modified` can still read 0 (issue 0398), or should the repair also delete the orphan and accept a deferred `delete()` behind all 866 scripted `unselect_all` sites including the Property-form Cancel path?
8. **D10** — Should `xschem move_objects <garbage>` raise a Tcl error — aborting a user's `.tcl`/`xschemrc` script or an action-log replay at that line, where it previously ran on past a silent no-op — rather than keep arming a deferred menu move? (No shipped call site, menu, keybinding, emitted log line or gold fixture passes a bad slot.)

### Blockers — F items

- **D3** (issue 0264) — 0264 is now MEASURED (3 repros, real content loss, 0 prompts) and its severity was raised to High, but the fix was **refuted and reverted**: nothing landed in `src/`, only the write-up. Blocker: the discard predicate is wrong in the general case. Next attempt should ship the ~3-line `clear_schematic` guard alone and put the predicate behind issue 0362.
- **D5** (descend census part 2) — Fix was built and measured green (refusal_channel_0251 34→67, descend_symbol 32→38, log_absorb 25→29), then **REVERTED IN FULL**; `src/` is byte-identical to `b1326180` and only `doc/claude` write-ups are committed. Blocker: the issue-0252 chooser filter deletes the create-the-child-by-descending workflow whenever an instance is selected. Root causes filed as 0379 (`get_sym_type` blanks while an instance is selected) and 0378 (`hi_descend`'s unconditional channel clear); those must land before the census fix is re-attempted.

### New issues filed: 0350–0409 (60, contiguous)

D1 0350–0354 · D1b 0355–0357 · D2 0358–0361 · D3 0362–0365 · D4 0366–0373 ·
D5 0374–0381 · D6 0382–0392 · D7 0393–0396 · D8 0397–0400 · D9 0401–0403 · D10 0404–0409

The 0273–0349 gap is still clear, as intended.

## Post-run items

Dispatched after the D1–D10 close-out, from a human report made while eyeball-verifying the run.

| item | status | commit | tests | new issues | one-line result |
|---|---|---|---|---|---|
| D11 (cadence parity: descend-into-symbol had no key) | x | _this commit_ | cadence_descend_newwin_ro 11→21 (CY1–CY10, ALL PASS), altf5_ciw +3 (CYT1–CYT3, ALL PASS under its logdir/GUI run mode); RED proof taken by the driver: with the bind line deleted, 8 of the 10 CY rows go red (CY4 and CY10 correctly stay green — they assert the untouched `i` steal and the absence of a competing chord) | 0410, 0411, 0412 | `Ctrl-Y` now reaches `xschem descend_symbol` in cadence mode, where the `i` steal for Create Instance had left the verb unreachable by any key. Calls the BARE verb, not a `cadence::` wrapper: the wrapper's gate accepts a strictly smaller set than the core's `descend_pick_target`, so wrapping would have added a new silent refusal, and the 0251 refusal channel already makes the empty-selection case speak up (CY7 witnesses the message). The `e`-offers-the-symbol half of the request is filed as 0411, NOT built — it is the 0252 chooser, blocked behind 0379. Found en route: 0412, `descend_readonly` is applied in `descend_schematic()` only, so cadence browse mode opens a `.sym` editable while a child schematic opens read-only — pre-existing, shared with the Edit menu and right-click item. |

Note: the D11 crew's own write-up and RED agents were blocked by a safety classifier
(the crew was about to commit to a branch a sister session is mid-merge on, on the strength
of an offhand remark). The driver stopped, reported the uncommitted tree, and the human
ratified both the commit and the Ctrl-Y-over-`i` choice before anything landed. The RED
proof and both suite runs above were then taken by the driver directly, not by the crew.
