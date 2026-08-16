# 0351 — the CI hard gate covers no 2026-08 gesture suite

Status: FIXED (implementation landed; write-up agent to expand)
Area: .github/workflows/ci.yaml
Found: 2026-08-09, unattended backlog run, item D1
Related: 0350, WIRING.md:1066-1068

## Symptom

`.github/workflows/ci.yaml` had exactly two hard test gates:

* `:29` — `full_audit.sh test_sweep_diff test_nogui`, no `AUDIT_MIN_PASS`
* `:44` — an xvfb gate whose list is `ls test_fluid_*.tcl test_rotate_*.tcl
  test_cadence_stretch_move.tcl test_drag_keeps_selection.tcl` + wireedit

and one informational step (`:52`, `|| true`).

Every suite the 2026-08 gesture work produced falls outside all three globs:
test_shape_draw_gate, test_paste_modify_flag_0244, test_add_wire_label,
test_placement_wire_gate, test_label_ride, test_placement_preview_doors,
test_label_strand_oracle, test_sch_add_pin, test_wire_split,
test_crossview_paste, test_instance_update. A regression in any of them could
not fail CI. `tests/headless/run.sh` (6 committed goldens) was in no CI step at all.

## Fix

Widen the CHEAP headless gate, not the xvfb one. Measured: all eleven suites pass
with `DISPLAY` unset, and eight are not even in full_audit's `nogui_tests` list —
they pass in the plain `--pipe -q --nolog` arm. They are true-headless.

The step now names 15 suites explicitly and carries `AUDIT_MIN_PASS=15` — the
EXACT count, not a slack floor. That floor is the structural repair of "a SKIP
can never fail the audit": any listed test that flips PASS→SKIP now fails CI. A
renamed/deleted test is already caught by full_audit's `MISSING | … → FAIL` arm,
so the explicit list cannot silently shrink.

`tests/headless/run.sh` gets its own hard step.

The xvfb gate list and its `AUDIT_MIN_PASS=15` are deliberately untouched.

Locked from the ci.yaml side by test_audit_classifier.tcl checks C15a/C15b.

## Caveat on the floor (added by the write-up agent, 2026-08-09)

`AUDIT_MIN_PASS` == the exact suite count closes the **SKIP-shaped** hollow green:
a gated suite that flips PASS→SKIP drops the count below the floor and CI goes red.
It does **not** close the PASS-shaped one. `full_audit`'s `is_pass` is still an
unanchored substring test, so a suite that prints FAIL lines, prints `OVERALL:
notok` and exits 1 is scored PASS — and counts toward this floor — if any line of
its output merely contains the substring `OVERALL: ok`. Measured against the fixed
harness; filed as **issue 0354**. The ci.yaml comment has been narrowed to say so.

Verified after landing: the gate command runs 15/15 PASS with `DISPLAY` unset,
exit 0. Note that running it locally **dirties the working tree** with
`untitled-NN.sch` in the repo root while full_audit still reports
`SCRATCH: 0 leaked dir(s)` — issue 0353.
