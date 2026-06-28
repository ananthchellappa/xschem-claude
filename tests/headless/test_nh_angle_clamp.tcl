# C-side stripe-angle clamp widened to [-45,45] (parse_net_hilight_styles in hilight.c).
# GUI headless (needs X for has_x so warnings reach ciw_echo, which we override to capture):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_angle_clamp.tcl
#
# Verifies the COMPILED table accepts negative angles end-to-end: an in-range negative angle
# warns NOT AT ALL; an out-of-range negative clamps to -45 (not 0) with the new range message;
# a negative angle with no dash still emits the "no dash" warning (angle != 0, not > 0).

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# isolate from the real ~/.xschem (some startup paths touch it)
set tmp [file join [pwd] _nhangle_[pid]] ; file delete -force $tmp ; file mkdir $tmp
set ::USER_CONF_DIR $tmp

# capture the warning sink (hilight_style_warn -> ciw_echo when has_x)
set ::warns {}
proc ciw_echo {msg} { lappend ::warns $msg }

proc set_style {row} {
  set ::warns {}
  set ::net_hilight_style [list $row]
  xschem update_net_hilight_style
}

# --- W1: an in-range negative angle compiles WITHOUT a range warning --------
set_style {0 4 8 {6 4} -30 0 none 0}
check "W1 angle -30 (in range) emits no out-of-range warning" \
  [expr {[lsearch -glob $::warns {*out of range*}] < 0}] "(=> $::warns)"

# --- W2: an out-of-range negative clamps to -45 with the [-45,45] message ----
set_style {0 4 8 {6 4} -50 0 none 0}
check "W2 angle -50 warns out-of-range, clamped to -45" \
  [expr {[lsearch -glob $::warns {*out of range*clamped to -45*}] >= 0}] "(=> $::warns)"

# --- W3: a negative angle with NO dash still warns (angle != 0, not > 0) -----
set_style {0 4 8 {} -30 0 none 0}
check "W3 angle -30 with no dash warns 'no dash pattern'" \
  [expr {[lsearch -glob $::warns {*no dash pattern*}] >= 0}] "(=> $::warns)"

# --- W4: positive still clamps the same (regression) ------------------------
set_style {0 4 8 {6 4} 50 0 none 0}
check "W4 angle 50 still warns, clamped to 45" \
  [expr {[lsearch -glob $::warns {*out of range*clamped to 45*}] >= 0}] "(=> $::warns)"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
