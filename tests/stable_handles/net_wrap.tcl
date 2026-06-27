# Characterization suite for the CURRENT net surface — step-3 direction (c)
# "net-as-object", Phase A. This suite locks today's behavior of the existing
# net query commands (list_nets, resolved_net, selected_wire, instance_net,
# instances_to_net, hilight) BEFORE any net-handle work, so it is the
# sensitivity net for the new commands and the documented baseline.
#
# These are CHARACTERIZATION tests (`check`, not `xcheck`): they assert what the
# shipped commands already do — including the §2c cold-start coherence quirk and
# the §2d derived-name trap (tcl_introspection_wire.md). No `net*` command is
# tested here yet; those land RED-first in Phase C only after the identity model
# (doc/claude/code_analysis/net_identity_decision.md) is ratified.
#
# Run from the source tree (needs an X display, no rebuild for Tcl changes):
#
#   cd src && timeout -s KILL 120 ./xschem -q --script ../tests/stable_handles/net_wrap.tcl
#
# Results in /tmp/sh_net_test.log. PASS/FAIL per check, final line DONE.

set ::net_dir [file normalize [file dirname [info script]]]
set ::logfd [open /tmp/sh_net_test.log w]

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
# expected-failure variant, reserved for the Phase C RED tests of the new
# net* commands (not used by this characterization suite).
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

if { [catch {source $::net_dir/net_body.tcl} err] } {
  puts $::logfd "ERROR: $err"
  puts $::logfd $::errorInfo
}

puts $::logfd "DONE"
flush $::logfd
close $::logfd
exit
