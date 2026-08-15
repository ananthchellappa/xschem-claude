# Regression guard for issue 0001: a degenerate window size persisted in
# $USER_CONF_DIR/geometry (e.g. {untitled-1.sch} {1x1+32+32}, saved during a
# WSLg compositor wedge) must NOT be restored by set_geom — it produced an
# unusable half-centimeter window that re-saved itself on every close.
# set_geom already rejects off-screen *positions*; this proves it also
# rejects degenerate *sizes*, while still honoring sane entries.
# Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_geometry_sanity.tcl
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

proc geom_size {geom} {
  if {[scan $geom {%dx%d} w h] == 2} { return [list $w $h] }
  return [list 0 0]
}

# Hermetic fixture: point USER_CONF_DIR at a temp dir with a crafted geometry
# file. set_geom reads the global USER_CONF_DIR, so no HOME games needed.
set fixture /tmp/xschem_geomtest_[pid]
file mkdir $fixture
set saved_ucd $USER_CONF_DIR
set USER_CONF_DIR $fixture
unset -nocomplain initial_geometry  ;# -g on the cmdline would bypass the file path
set saved_fullscreen $fullscreen
set fullscreen 0

set fd [open $fixture/geometry w]
puts $fd "{poison-1x1.sch} {1x1+32+32} {100}"
puts $fd "{poison-thin.sch} {50x500+32+32} {101}"
puts $fd "{sane.sch} {800x600+15+15} {102}"
close $fd

set before [wm geometry .]
lassign [geom_size $before] bw bh

# 1) positive control first — proves set_geom is really reading our fixture
set_geom . sane.sch
lassign [geom_size [wm geometry .]] w h
check "sane 800x600 entry IS applied" [expr {$w == 800 && $h == 600}] "(got ${w}x${h})"

# 2) degenerate sizes must be ignored (window keeps its current geometry)
set_geom . poison-1x1.sch
lassign [geom_size [wm geometry .]] w h
check "degenerate 1x1 entry ignored" [expr {$w == 800 && $h == 600}] "(got ${w}x${h})"

set_geom . poison-thin.sch
lassign [geom_size [wm geometry .]] w h
check "degenerate 50x500 entry ignored" [expr {$w == 800 && $h == 600}] "(got ${w}x${h})"

# 3) a missing entry still leaves geometry alone (no regression of the default path)
set_geom . no-such-entry.sch
lassign [geom_size [wm geometry .]] w h
check "absent entry leaves geometry alone" [expr {$w == 800 && $h == 600}] "(got ${w}x${h})"

# restore real state before exit (xwin_exit re-saves geometry on quit)
wm geometry . $before
update
set USER_CONF_DIR $saved_ucd
set fullscreen $saved_fullscreen
file delete -force $fixture

puts [expr {$fail ? "RESULT: $fail FAILED" : "RESULT: ALL PASS"}]
flush stdout
exit 0
