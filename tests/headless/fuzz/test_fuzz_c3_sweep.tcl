# Hardening sprint Track C / step C3 -- self-test for the sweep DRIVER + replay capture.
# Spec: doc/claude/suggestions/hardening_sprint_plan.md (C3).
#
# The full sweep (fuzz_sweep.tcl) is the nightly artifact; this is its fast smoke test,
# asserting the driver's load-bearing properties on a tiny grid:
#   1. Under the shipped default (B3 enforcement ON) the sweep finds NO escaped saved short
#      (RED == 0) on before_8 -- B3 has no gap there.
#   2. Reverting B3 (enforce OFF) makes the very drops B3 was REFUSING SAVE their shorts, so
#      the sweep produces RED replays (the revert-teeth demonstration -- the plan's 0111
#      revert is un-catchable, being a same-length pure-bend staircase; this is the catchable
#      substitute, see the plan's C3 note). The enforce-ON REFUSED set == the enforce-OFF RED
#      set (same drops, different verdict).
#   3. The split gesture snaps each half to the grid: a naive int(dx/2) would land a 5-unit
#      (sub-grid) intermediate that FALSELY shorts (WIRING.md §1.2); grid-snapped it does not.
#   4. A written replay file round-trips: sourced standalone it reproduces the same verdict.
#
# True headless:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/fuzz/test_fuzz_c3_sweep.tcl
source [file join [file dirname [info script]] harness.tcl]

# mini in-process sweep -> dict of verdict counts + the RED and REFUSED delta sets
proc minisweep {fixture type dxs dys enforce} {
  set ::fuzz_enforce $enforce
  set c [dict create GREEN 0 AMBER 0 RED 0 REFUSED 0]
  set reds {}; set refused {}
  foreach dx $dxs { foreach dy $dys {
    if {$dx == 0 && $dy == 0} continue
    set v [dict get [fuzz_drop $fixture [list target R18 type $type dx $dx dy $dy]] verdict]
    dict incr c $v
    if {$v eq "RED"} { lappend reds "$dx,$dy" }
    if {$v eq "REFUSED"} { lappend refused "$dx,$dy" }
  }}
  return [list $c [lsort $reds] [lsort $refused]]
}

set dxs {10 20 30 40 50 60}; set dys {-40 -20}

# 1 + 2: enforce ON finds no escaped short; enforce OFF (B3 reverted) does.
lassign [minisweep before_8 stretch $dxs $dys 1] c_on reds_on refused_on
lassign [minisweep before_8 stretch $dxs $dys 0] c_off reds_off refused_off
check "enforce ON: sweep finds NO escaped saved short on before_8 (RED == 0)" \
  [expr {[dict get $c_on RED] == 0}]
check "enforce ON: some drops route clean (GREEN > 0), i.e. not all refused" \
  [expr {[dict get $c_on GREEN] > 0}]
check "revert-teeth: enforce OFF SAVES shorts the sweep catches as RED (RED > 0)" \
  [expr {[dict get $c_off RED] > 0}]
check "the enforce-ON REFUSED set == the enforce-OFF RED set (same drops, B3 flips verdict)" \
  [expr {$refused_on eq $reds_off}]
puts "  enforce ON:  $c_on  (refused: $refused_on)"
puts "  enforce OFF: $c_off  (red: $reds_off)"

# 3: split grid-snap -- (20,-40) must not sub-grid-short.
set ::fuzz_enforce 1
check "split grid-snap: before_8 split (20,-40) is not RED (no sub-grid false short)" \
  [expr {[dict get [fuzz_drop before_8 {target R18 type split dx 20 dy -40}] verdict] ne "RED"}]

# 4: a replay round-trips. fuzz_spec_line produces the exact `fuzz_drop ...` call a replay
# file runs; evaluating it (with the same baked enforce mode) must reproduce the verdict.
set ::fuzz_enforce 0
set spec [fuzz_spec_line before_8 {target R18 type stretch dx 10 dy -40}]
check "replay round-trip: the generated spec line ($spec) reproduces RED under enforce OFF" \
  [expr {[dict get [eval $spec] verdict] eq "RED"}]

we_result
