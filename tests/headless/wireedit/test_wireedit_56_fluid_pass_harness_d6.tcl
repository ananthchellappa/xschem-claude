# Hardening sprint Track D / step D6 -- single-pass harness `xschem fluid_pass <name>`.
#
# The END-cleanup passes used to be testable only through a whole gesture (move_objects) whose
# waypoints had to be transcribed from a user's FLUID_TRACE log. D6 exposes two scheduler verbs so
# one pass can be exercised against a SYNTHETIC scene, headless, in milliseconds:
#   xschem fluid_snapshot arm   -- arm the START snapshot on the current geometry (returns 1 if a
#                                  valid snapshot was taken: needs fluid_editing + >=1 instance pin)
#   xschem fluid_pass <name>    -- run one driver-run END-cleanup pass by table name; returns its
#                                  changed-count, 0 when it fail-safe-declines (no armed snapshot),
#                                  or errors for an unknown / MANUAL_SITE name.
#
# GESTURE-STATE CONTRACT (mirrors a real END): arm on the PRISTINE geometry BEFORE the novel copper
# exists -- straighten et al. are novelty-scoped against the START wire snapshot, and that snapshot
# must be NON-empty (a zero-wire baseline makes fluid_wire_is_novel_span return "nothing is novel",
# a deliberate safety default), so the scene needs >=1 baseline wire at arm time.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_56_fluid_pass_harness_d6.tcl
source [file join [file dirname [info script]] fixtures.tcl]

proc wset {} {
  set L {}
  for {set i 0} {$i < [xschem get wires]} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 > $x2 || ($x1 == $x2 && $y1 > $y2)} { lassign [list $x2 $y2 $x1 $y1] x1 y1 x2 y2 }
    lappend L [list $x1 $y1 $x2 $y2]
  }
  return [lsort $L]
}

proc scene_base {} {
  xschem clear force
  uplevel #0 {set fluid_editing 1}; uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}; uplevel #0 {set cadsnap 10}
  xschem instance devices/res 500 500 0 0 {name=Rx m=1 value=1}   ;# pins so the snapshot can arm
  xschem wire 400 400 400 410                                     ;# a NON-empty baseline (novelty scope)
}

# ---- Test 1: straighten collapses a synthetic 3-segment staircase to a 2-segment L ----------------
# Staircase #net between (0,0) and (10,20): riser (0,0)-(0,10), jog (0,10)-(10,10), riser
# (10,10)-(10,20). straighten slides the jog to y=0, collapsing the redundant step: the route becomes
# the L (0,0)-(10,0)-(10,20) -- 2 segments, minimum bends. The baseline wire is untouched.
scene_base
check "harness: fluid_snapshot arm on a scene with pins returns 1" [expr {[xschem fluid_snapshot arm] == 1}]
xschem wire 0  0  0 10
xschem wire 0 10 10 10
xschem wire 10 10 10 20
set changed [xschem fluid_pass straighten_reversals]
check "straighten reshaped the staircase (changed=$changed > 0)" [expr {$changed > 0}]
set want [lsort [list {400 400 400 410} {0 0 10 0} {10 0 10 20}]]
check "staircase collapsed to the 2-segment L (got [wset])" [expr {[wset] eq $want}]

# ---- Test 2: gate enforcement -- a pass with NO armed snapshot declines (returns 0) ----------------
# After clear (which frees any snapshot via fluid_gesture_free) the snapshot is absent, so straighten
# fail-safes to a no-op; the harness reports 0 (declined), NOT a reshape.
scene_base
xschem wire 0  0  0 10
xschem wire 0 10 10 10
xschem wire 10 10 10 20
set pre [wset]
set changed_noarm [xschem fluid_pass straighten_reversals]
check "no armed snapshot: straighten declines (changed=$changed_noarm == 0)" [expr {$changed_noarm == 0}]
check "no armed snapshot: geometry unchanged" [expr {[wset] eq $pre}]

# ---- Test 3: arm with NO instance pins returns 0 (nothing to verify against) -----------------------
xschem clear force
uplevel #0 {set fluid_editing 1}
xschem wire 0 0 0 10
check "arm on a pin-less scene returns 0" [expr {[xschem fluid_snapshot arm] == 0}]

# ---- Test 4: unknown / MANUAL_SITE pass names error, not silently no-op ----------------------------
scene_base
xschem fluid_snapshot arm
check "unknown pass name errors" [expr {[catch {xschem fluid_pass no_such_pass}]}]
check "MANUAL_SITE pass name (insert_exit_stubs) errors -- not driver-run" \
  [expr {[catch {xschem fluid_pass insert_exit_stubs}]}]

we_result
