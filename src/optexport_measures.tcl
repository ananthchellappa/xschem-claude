# measures.tcl -- written by ASE-L Tools > Export for Optimizer (FAQ Q92).
#
# Run ONLY through measures.py, which launches
#   xschem --nogui --pipe -q --nolog --script measures.tcl
# with DISPLAY removed and a private throwaway HOME.
#
# Inputs are ENVIRONMENT VARIABLES, never argv (xschem reads extra words as
# files to open):
#   ASEXP_RUNDIR  the directory ngspice ran in (absolute)
#   ASEXP_OUT     the results file to write (absolute)
#   ASEXP_LOG     optional: a file holding ngspice's captured output, read only
#                 for the case rule (result_casemode)
#
# All the logic is ase::optexport_measure in xschem's own src/ase.tcl -- the
# procs that fill the ASE-L Outputs pane -- so the values match the pane by
# construction. This file only reads the frozen bench (measures_state.tcl, read
# as DATA, never sourced) and writes the results file atomically: a killed
# process leaves no file, never half of one.
set ::asexp_rc 3
set ::asexp_here [file dirname [file normalize [info script]]]
set ::asexp_text {}
if {[catch {
  set f [open [file join $::asexp_here measures_state.tcl] r]
  fconfigure $f -encoding utf-8
  set frozen [read $f]
  close $f
  set log {}
  if {[info exists ::env(ASEXP_LOG)] && $::env(ASEXP_LOG) ne {}} {
    set f [open $::env(ASEXP_LOG) r]
    set log [read $f]
    close $f
  }
  set ::asexp_text [ase::optexport_measure [dict get $frozen state] \
                      [file normalize $::env(ASEXP_RUNDIR)] $log \
                      [dict get $frozen casemode_requested]]
  set ::asexp_rc 0
} err]} {
  set ::asexp_text [ase::optexport_failure_json $err $::errorInfo]
}
if {[catch {
  set tmp $::env(ASEXP_OUT).part
  set f [open $tmp w]
  fconfigure $f -encoding utf-8 -translation lf
  puts -nonewline $f $::asexp_text
  close $f
  file rename -force -- $tmp $::env(ASEXP_OUT)
}]} {
  set ::asexp_rc 4
}
exit $::asexp_rc
