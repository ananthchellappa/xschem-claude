# Net highlight stripe-angle range widened from [0,45] to [-45,45] (allow tilt both ways).
# Pure Tcl, true headless (no X): exercises net_hilight_style_norm, the clamp the editor and
# every style mutator share.
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_nh_angle_range.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# angle is column 4 of a style row {index color width dash angle blink anim rate}
proc norm_angle {a} { lindex [net_hilight_style_norm [list 0 4 1 {6 4} $a 0 none 0] 0] 4 }

# --- in-range negatives must be KEPT (the whole point of the change) ---------
check "AR1 angle -30 kept (not clamped to 0)" [expr {[norm_angle -30] == -30}] "(=> [norm_angle -30])"
check "AR2 angle -45 kept (lower bound)"      [expr {[norm_angle -45] == -45}] "(=> [norm_angle -45])"
check "AR3 angle -1 kept"                     [expr {[norm_angle -1]  == -1}]  "(=> [norm_angle -1])"

# --- out-of-range clamps to the nearest bound -------------------------------
check "AR4 angle -50 clamps to -45"           [expr {[norm_angle -50] == -45}] "(=> [norm_angle -50])"
check "AR5 angle 50 clamps to 45 (unchanged)" [expr {[norm_angle 50]  == 45}]  "(=> [norm_angle 50])"

# --- unchanged behaviour: 0 / positives / junk ------------------------------
check "AR6 angle 0 stays 0"                   [expr {[norm_angle 0]   == 0}]   "(=> [norm_angle 0])"
check "AR7 angle 30 stays 30"                 [expr {[norm_angle 30]  == 30}]  "(=> [norm_angle 30])"
check "AR8 non-integer angle -> 0"            [expr {[norm_angle foo] == 0}]   "(=> [norm_angle foo])"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
