# Hardening sprint Track C / step C1 -- self-test for the delta-sweep fuzzer HARNESS.
# Spec: doc/claude/suggestions/hardening_sprint_plan.md (C1).
#
# Proves the single-drop machine (harness.tcl) is correct AND non-hollow:
#   1. GREEN  -- the C1 done-when: before_8 + R18 dragged (-90,-40) is the 0105 gesture on
#               AUTO (#net) copper; 0105's collinear jog un-merges the device -> the device
#               LANDS at the requested delta and every hard ELECTRICAL check passes (P1
#               connectivity + P2 device-merge + P2 label-survival).
#               NB: the fuzzer does NOT use the absolute p2_no_short here -- before_8 ships a
#               benign #net3-x-#net1 CROSSING (no junction, not an electrical short) that
#               p2_no_short's bbox arm flags, so it is 0 on the pristine fixture. The
#               before_8 wireedit tests (53/54) already sidestep it for the same reason. See
#               harness.tcl fuzz_assert and hardening_sprint_plan.md (C1/C2 premise fix).
#   2. GREEN via the ROTATE gesture path (headless ALT-R): before_7 + R18 rot (-30,70) is the
#               0104 gesture; the de-short prune keeps R18.P/M distinct -> GREEN + landed.
#               (Proves the start/rotate_in_place/end headless path works, no X.)
#   3. REFUSED -- teeth for the "did it actually move?" classifier: the SAME 0105 drag on a
#               NAMED rail (a lab_pin VDD on the backbone) is UNREPAIRABLE (the de-shorters
#               blackout on named copper), so B3 enforcement REFUSES it. Every hard check
#               still passes (nothing was saved) but the device did NOT move -> REFUSED, not a
#               hollow GREEN (plan C4 note).
#   4. RED   -- teeth for the verdict itself: the same named-rail drag with enforcement OFF
#               (the old log-only behavior) SAVES the short -> P2 fails -> RED.
#
# True headless (release + headless-safe rotate; WIRING.md §0.7):
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/fuzz/test_fuzz_harness_c1.tcl
source [file join [file dirname [info script]] harness.tcl]

# --- 1 + 2: the two GREEN cases, driven through the top-level fuzz_drop -------------------
set d [fuzz_drop before_8 {target R18 type stretch dx -90 dy -40}]
check "C1 done-when: before_8 R18 stretch (-90,-40) is GREEN (0105 repaired, device landed)" \
  [expr {[dict get $d verdict] eq "GREEN"}]
check "  -> and it actually LANDED (not a refused no-op)" [dict get $d landed]
puts "  checks: [dict get $d checks]"
puts "  spec:   [dict get $d spec]"

set d [fuzz_drop before_7 {target R18 type rot dx -30 dy 70}]
check "rotate path: before_7 R18 m+ALT-R (-30,70) is GREEN (0104 de-short, headless rotate)" \
  [expr {[dict get $d verdict] eq "GREEN"}]
check "  -> and it LANDED" [dict get $d landed]

# --- 3 + 4: teeth -- the named-rail drop is REFUSED (enforce on) / RED (enforce off) -------
# Same shape as test_wireedit_54: name the y=-40 backbone with a lab_pin so every de-shorter
# blackouts (fluid_wire_explicit_lab) -> the 0105 short is unrepairable. fuzz_load then a
# post-load mutator, then run the harness core by hand (fuzz_drop reloads, so it can't carry
# the mutation).
proc drop_named_rail {enforce} {
  fuzz_load before_8
  xschem instance devices/lab_pin -200 -40 0 0 {name=lvdd lab=VDD}   ;# names the y=-40 backbone
  uplevel #0 [list set fluid_enforce_invariants $enforce]
  set g {target R18 type stretch dx -90 dy -40}
  set snap [fuzz_snapshot]
  set pre  [_fuzz_inst_origin R18]
  fuzz_apply $g
  set checks [fuzz_assert $snap $g]
  set clean 1
  foreach c $checks { if {![lindex $c 1]} { set clean 0 } }
  set landed [_fuzz_landed R18 $pre -90 -40]
  return [expr {!$clean ? "RED" : ($landed ? "GREEN" : "REFUSED")}]
}
check "teeth REFUSED: named-rail 0105 drag with enforcement ON is REFUSED (clean but no move)" \
  [expr {[drop_named_rail 1] eq "REFUSED"}]
check "teeth RED: named-rail 0105 drag with enforcement OFF is RED (short SAVED, P2 fails)" \
  [expr {[drop_named_rail 0] eq "RED"}]

we_result
