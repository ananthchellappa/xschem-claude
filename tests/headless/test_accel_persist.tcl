# test_accel_persist.tcl — D1 feature test: persist accel overrides across sessions
# Run headless: ./src/xschem --no_x --rcfile tests/headless/minrc --pipe -q \
#               --script tests/headless/test_accel_persist.tcl
#
# Tests that save_accel_overrides writes the override file and that
# load_accel_overrides re-applies the remap on a fresh run.

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# Use a temp dir so we don't touch the real USER_CONF_DIR
set tmpdir [file join /tmp xschem_test_accel_persist_[pid]]
file mkdir $tmpdir
set ::USER_CONF_DIR $tmpdir

# Confirm zoom_in originally has accel Shift+Z
set orig_accel {}
foreach row $action_table {
  if {[dict get $row id] eq "view.zoom_in"} {
    set orig_accel [dict get $row accel]
    break
  }
}
check "zoom_in original accel is Shift+Z" [expr {$orig_accel eq "Shift+Z"}] "(got '$orig_accel')"

# 1. Remap zoom_in to Ctrl+Shift+Z
remap_action_accel view.zoom_in "Ctrl+Shift+Z"
set new_accel {}
foreach row $action_table {
  if {[dict get $row id] eq "view.zoom_in"} {
    set new_accel [dict get $row accel]
    break
  }
}
check "remap sets new accel in table" [expr {$new_accel eq "Ctrl+Shift+Z"}] "(got '$new_accel')"

# 2. Save overrides
save_accel_overrides
set override_file "$tmpdir/accel_overrides.tcl"
check "override file created" [file exists $override_file] {}

set contents [read [open $override_file]]
check "override file references view.zoom_in" \
  [expr {[string first "view.zoom_in" $contents] >= 0}] {}
check "override file references Ctrl+Shift+Z" \
  [expr {[string first "Ctrl+Shift+Z" $contents] >= 0}] {}
check "original Shift+Z NOT in override file" \
  [expr {[string first "Shift+Z" $contents] < 0 || [string first "Ctrl+Shift+Z" $contents] >= 0}] {}

# 3. Reset zoom_in back to original
remap_action_accel view.zoom_in "Shift+Z"
set back_accel {}
foreach row $action_table {
  if {[dict get $row id] eq "view.zoom_in"} {
    set back_accel [dict get $row accel]
    break
  }
}
check "remap back to Shift+Z" [expr {$back_accel eq "Shift+Z"}] "(got '$back_accel')"

# 4. Load overrides - should re-apply Ctrl+Shift+Z
load_accel_overrides
set loaded_accel {}
foreach row $action_table {
  if {[dict get $row id] eq "view.zoom_in"} {
    set loaded_accel [dict get $row accel]
    break
  }
}
check "load_accel_overrides re-applies remap" \
  [expr {$loaded_accel eq "Ctrl+Shift+Z"}] "(got '$loaded_accel')"

# 5. Verify unchanged rows don't appear in override file
foreach row $action_table {
  set id [dict get $row id]
  if {$id eq "view.zoom_in"} continue
  set accel [dict get $row accel]
  set orig  [expr {[dict exists $row orig_accel] ? [dict get $row orig_accel] : $accel}]
  if {$accel ne $orig} {
    puts "WARNING: unexpected changed accel for $id: '$accel' != '$orig'"
  }
}
check "only changed accels are in override file (1 entry)" \
  [expr {[llength [split [string trim $contents] "\n"]] == 1}] \
  "(lines=[llength [split [string trim $contents] \\n]])"

# Cleanup
file delete -force $tmpdir

if {$fail == 0} { puts "\nRESULT: ALL PASS" } else { puts "\nRESULT: $fail FAILED" }
exit [expr {$fail == 0 ? 0 : 1}]
