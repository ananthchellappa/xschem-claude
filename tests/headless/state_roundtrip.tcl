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
#  Usage, from a suite that has already sourced the ASE-L environment:
#
#        source [file join $repo tests headless state_roundtrip.tcl]
#        set r [ase_state_roundtrip $repo]
#        # -> dict: tracked bad control_disagrees control_agrees
#
#  `bad` is the list of files that did not round-trip; it must be empty, and
#  `control_disagrees` and `control_agrees` must both be 1.
#

proc ase_state_roundtrip {repo} {
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
    # ⚠ THE `\n` IS THE WHOLE POINT. See the header.
    if {"[ase::state_serialize [ase::state_load $f]]\n" ne $orig} {
      lappend bad [file tail $f]
    }
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
    set c_dis [expr {"[ase::state_serialize $st]\n" ne $orig}]
  }

  # --- CONTROL 2: an untouched one MUST keep matching ----------------------
  # Control 1 alone is satisfied by a comparison that always disagrees.
  set c_agr 0
  if {[llength $files]} {
    set f [lindex $files 0]
    set fh [::open $f rb] ; set orig [read $fh] ; ::close $fh
    set c_agr [expr {"[ase::state_serialize [ase::state_load $f]]\n" eq $orig}]
  }

  return [dict create tracked $n bad $bad \
                      control_disagrees $c_dis control_agrees $c_agr]
}
