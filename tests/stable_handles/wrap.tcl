# Characterization + handle test suite for the stable-object-handles work
# (doc/claude/suggestions/plan_stable_handles_step1.md, Phase A onward).
#
# Run from the source tree (needs an X display, no rebuild for Tcl changes):
#
#   cd src && timeout -s KILL 120 ./xschem -q --script ../tests/stable_handles/wrap.tcl
#
# Results in /tmp/sh_test.log. PASS/FAIL per check, XFAIL allowed only for
# checks explicitly marked expected-fail (Phase D red tests), final line DONE.
# The user's $USER_CONF_DIR/recent_files is backed up and restored around the
# run. All schematic edits happen on a /tmp copy of the fixture — the repo
# tree is never written to.

set ::qo_dir [file normalize [file dirname [info script]]]
set ::logfd [open /tmp/sh_test.log w]

proc check {what cond} {
  if { [catch {uplevel 1 [list expr $cond]} res] } {
    puts $::logfd "FAIL: $what (eval error: $res)"
  } elseif { $res } {
    puts $::logfd "PASS: $what"
  } else {
    puts $::logfd "FAIL: $what"
  }
  flush $::logfd
}
# expected-failure variant for TDD red tests: logs XFAIL when (still) failing,
# logs "PASS (was XFAIL...)" once the implementation lands so the marker can
# be flipped to a plain check.
proc xcheck {what cond} {
  if { [catch {uplevel 1 [list expr $cond]} res] } {
    puts $::logfd "XFAIL: $what (eval error: $res)"
  } elseif { $res } {
    puts $::logfd "PASS (was XFAIL — flip to check): $what"
  } else {
    puts $::logfd "XFAIL: $what"
  }
  flush $::logfd
}

set ::qo_conf_bak {}
if { [info exists USER_CONF_DIR] && [file exists $USER_CONF_DIR/recent_files] } {
  set ::qo_conf_bak /tmp/sh_recent_files.bak
  file copy -force $USER_CONF_DIR/recent_files $::qo_conf_bak
}

if { [catch {source $::qo_dir/test_body.tcl} err] } {
  puts $::logfd "ERROR: $err"
  puts $::logfd $::errorInfo
}

if { $::qo_conf_bak ne {} } {
  catch {file copy -force $::qo_conf_bak $USER_CONF_DIR/recent_files}
}
foreach f [glob -nocomplain /tmp/sh_fixture.sch /tmp/sh_snap_*.sch /tmp/sh_save_*.sch] {
  catch {file delete -force $f}
}

puts $::logfd "DONE"
flush $::logfd
close $::logfd
exit
