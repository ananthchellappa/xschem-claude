#
#  File: state_roundtrip.tcl
#
#  THE `.state` BYTE-IDENTITY MEASUREMENT, IN ONE PLACE.
#
#  Every stage of the ASE-L analyses batch has to show that its change did not
#  move the 104 committed `.state` files. THREE separate crews have written this
#  measurement from scratch and ALL THREE got the same false alarm first:
#
#     receipt 30 §6        -- found it and wrote it down
#     issue 1460's crew    -- "my first .state measurement said 104/104
#                             mismatching and was wrong" (correction C24)
#     issue 1464's crew    -- "a maximally alarming false alarm"
#
#  ⚠ THE TRAP, ONCE, SO NOBODY MEETS IT A FOURTH TIME: `ase::state_serialize`
#  OMITS THE TRAILING NEWLINE that the file on disk carries. So the honest
#  comparison is
#
#        "[ase::state_serialize $st]\n"  ne  $orig
#
#  and a harness that compares the two directly reports EVERY file as broken --
#  which is the most alarming possible wrong answer, arriving at the exact
#  moment a crew is deciding whether it has damaged the user's benches.
#
#  ⚠ AND A COMPARISON WITH NO CONTROL MEASURES NOTHING. If the loop cannot be
#  made to DISAGREE, "zero mismatches" is indistinguishable from "the comparison
#  never ran". Both controls below are therefore mandatory, not decoration:
#  one mutates a loaded state and requires it to stop matching, the other
#  requires an untouched one to keep matching.
#
#  ⚠ AND IT CALLS THE WRITER RATHER THAN RE-IMPLEMENTING IT. `ase::state_save`
#  is `puts $f [ase::state_serialize $state]`, and `puts` is where the newline
#  comes from -- so "serialize + \n" is byte-exact TODAY and is still a
#  re-implementation of somebody else's proc. This helper writes with
#  `ase::state_save` to a scratch path and compares bytes, so a change to the
#  writer cannot escape the measurement. Issue 1464's crew put it exactly
#  right: `state_serialize` is not the byte-identity mechanism, `state_save` is.
#
#  Usage, from a suite that has already sourced the ASE-L environment:
#
#        source [file join $repo tests headless state_roundtrip.tcl]
#        set r [ase_state_roundtrip $repo]
#        # -> dict: tracked bad control_disagrees control_agrees
#
#  `bad` is the list of files that did not round-trip; it must be empty, and
#  `control_disagrees` and `control_agrees` must both be 1.
#

proc ase_state_roundtrip {repo {tmp {}}} {
  if {$tmp eq {}} { set tmp [file join [file dirname [info script]] .state_rt_[pid].tmp] }
  set files {}
  set out {}
  catch {exec git -C $repo ls-files -- *.state} out
  foreach rel [split $out "\n"] {
    if {[string trim $rel] ne {}} { lappend files [file join $repo $rel] }
  }

  set n 0
  set bad {}
  foreach f $files {
    if {![file exists $f]} { continue }
    incr n
    set fh [::open $f rb] ; set orig [read $fh] ; ::close $fh
    # ⚠ THE WRITER, NOT A RECONSTRUCTION OF IT. See the header.
    ase::state_save $tmp [ase::state_load $f]
    set fh [::open $tmp rb] ; set again [read $fh] ; ::close $fh
    if {$again ne $orig} { lappend bad [file tail $f] }
  }

  # --- CONTROL 1: a mutated state MUST stop matching -----------------------
  # Without this, a comparison that silently never ran reports a clean sweep.
  set c_dis 0
  if {[llength $files]} {
    set f [lindex $files 0]
    set fh [::open $f rb] ; set orig [read $fh] ; ::close $fh
    set st [ase::state_load $f]
    set rows [ase::state_get $st analyses]
    lappend rows {type op enabled 0 x zz_control_row}
    dict set st analyses $rows
    ase::state_save $tmp $st
    set fh [::open $tmp rb] ; set mutated [read $fh] ; ::close $fh
    set c_dis [expr {$mutated ne $orig}]
  }

  # --- CONTROL 2: an untouched one MUST keep matching ----------------------
  # Control 1 alone is satisfied by a comparison that always disagrees.
  set c_agr 0
  if {[llength $files]} {
    set f [lindex $files 0]
    set fh [::open $f rb] ; set orig [read $fh] ; ::close $fh
    ase::state_save $tmp [ase::state_load $f]
    set fh [::open $tmp rb] ; set same [read $fh] ; ::close $fh
    set c_agr [expr {$same eq $orig}]
  }

  catch {file delete -force -- $tmp}
  return [dict create tracked $n bad $bad \
                      control_disagrees $c_dis control_agrees $c_agr]
}
