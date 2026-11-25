# tests/headless/test_ase_bar_session_sim_1762.tcl -- the bottom bar of an
# ASE-L window names the simulator a run of ITS OWN state starts, from the
# moment the window opens (issue 1762).
#
# The report (2026-11-25): "When ASE-L is launched, the simulator to be used
# is not matching what is shown on the status bar ... after the first run, it
# displays correctly."  The bar asked which registered program is in force
# for the whole process, and a state's own choice (its `sim_entry` key) went
# in force only when the state was run or the choice was picked.
#
# Code   src/ase.tcl          ase::sim_session_label
#        src/ase_window.tcl   ase::ui::sim_enter, ase::ui::refresh_status,
#                             ase::ui::open, ase::ui::do_load_state_from,
#                             ase::ui::revert_state
#        src/ase.tcl          ase::open_state (the arm that raises a window)
#
# THE STUBS SAY WHO THEY ARE.  Each registered program is a shell script
# that prints its own marker, so "the run starts it" is read off what was
# really started and not off a name.
#
# BANDS
#   BS1-BS4   the label alone, no window: runs on both arms
#   BS5-BS11  the window (display arm; a `skip:` line each without one)
#   BS12      structural, both arms
#
# REGISTERED IN `hcases` AND `dcases`.  Standalone from the repo ROOT, armed
# (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh [--nogui] test_ase_bar_session_sim_1762

source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch asebar1762]
test_sim_registry_isolate

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} ) \" '] $r]" }
  return $r
}
proc wr {path text {perm {}}} {
  file mkdir [file dirname $path]
  set fp [open $path w]; puts -nonewline $fp $text; close $fp
  if {$perm ne {}} { file attributes $path -permissions $perm }
}
set HASX [expr {[info exists ::has_x] && [info commands winfo] ne {}}]

## The Simulator segment of the real bottom bar, through the reader tests and
## scripting use. NOSEG rather than {}: an absent segment must never satisfy
## a row that expects a name.
proc barsim {k} {
  set t [pcall ase::ui::status_text $k]
  if {$t eq {}} { return NOWIDGET }
  foreach seg [split $t |] {
    set seg [string trim $seg]
    if {[string first {Simulator:} $seg] == 0} {
      return [string trim [string range $seg [string length {Simulator:}] end]]
    }
  }
  return NOSEG
}
## Start the command a run composes for the program in force, for real, and
## answer which stub's marker came back.
proc who_runs {deck} {
  if {[catch {ase::backend::ngspice::run_cmd {} $deck} cmd]} { return "REFUSED" }
  if {[catch {eval exec $cmd} out]} { return "RANFAIL" }
  foreach m {ZZ_ALPHA_RAN ZZ_BETA_RAN} {
    if {[string first $m $out] >= 0} { return $m }
  }
  return NOMARKER
}

# --- fixture ------------------------------------------------------------------
set ALPHA [file join $scratch bin ngalpha]
set BETA  [file join $scratch bin ngbeta]
set GONE  [file join $scratch bin nggone]
wr $ALPHA "#!/bin/sh\necho ZZ_ALPHA_RAN \"\$@\"\nexit 0\n" 0755
wr $BETA  "#!/bin/sh\necho ZZ_BETA_RAN \"\$@\"\nexit 0\n" 0755
set DECK [file join $scratch deck.spice]
wr $DECK "* deck\n.end\n"

file mkdir [file join $scratch blib]
wr [file join $scratch library.defs] "DEFINE blib [file join $scratch blib]\n"
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1

## A state view of blib/tb whose state makes `choice` its own:
##   {}            no choice of its own
##   {entry NAME}  that registry entry (registered or not)
##   path          deliberately the program on the PATH
proc mkstate {view choice} {
  library_new_view blib tb $view ngspice_state1
  set p [xschem cellview_path blib/tb $view]
  set st [ase::state_load $p]
  if {$choice ne {}} { set st [ase::sim_choice_set $st {*}$choice] }
  ase::state_save $p $st
  return $p
}
proc reg3 {} {
  ase::sim_clear
  ase::sim_register alpha $::ALPHA
  ase::sim_register beta  $::BETA
  ase::sim_register gone  $::GONE
}

if {[catch {

library_new_cell blib tb schematic
set P_BETA  [mkstate ngspice_state1 {entry beta}]
set P_NONE  [mkstate ngspice_state2 {}]
set P_GHOST [mkstate ngspice_state3 {entry ghostsim}]
set P_PATH  [mkstate ngspice_state4 path]
set P_GONE  [mkstate ngspice_state5 {entry gone}]
set P_ALPHA [mkstate ngspice_state6 {entry alpha}]
foreach v {BETA NONE GHOST PATH GONE ALPHA} {
  set ST_$v [ase::state_load [set P_$v]]
}

# =============================================================================
# BS1-BS4 -- the label, with no window
# =============================================================================
## alpha is registered first, so it is in force and it is the installation
## default; nothing below changes either except where a row says so.
reg3
check {BS0 the fixture: three entries, the first one in force, and each stub answers with its own marker when it is started} \
  [list [pcall ase::sim_selected] [who_runs $DECK] \
        [expr {[catch {exec $BETA -b /dev/null} o] ? {RANFAIL} : [string range $o 0 10]}]] \
  [list alpha ZZ_ALPHA_RAN ZZ_BETA_RAN]

check {BS1 a state that asks for its own simulator is labelled with it while another is in force, and asking changes nothing: the other is still in force afterwards} \
  [list [pcall ase::sim_session_label $ST_BETA] [pcall ase::sim_selected] \
        [pcall ase::sim_label ngspice]] \
  [list beta alpha alpha]

## beta put in force from the Command window's door: no state says so.
pcall ase::sim_select beta
set BS2P [pcall ase::sim_session_label $ST_PATH]
check {BS2 a state with no choice of its own is labelled with the installation default, and a state that asks for the program on the PATH is labelled with no entry's name -- with a third thing in force both times, which stays in force} \
  [list [pcall ase::sim_session_label $ST_NONE] \
        [expr {[string first ngspice $BS2P] == 0 ? 1 : 0}] \
        [expr {[lsearch -exact {alpha beta gone} [lindex $BS2P 0]] < 0 ? 1 : 0}] \
        [pcall ase::sim_selected]] \
  [list alpha 1 1 beta]

## A state naming an entry nobody registered: its run leaves what is in force
## in force (ase::sim_apply_choice, the run's own step, is the witness) and
## says so. The label names the same program and says nothing.
pcall ase::sim_said_clear
set BS3L [pcall ase::sim_session_label $ST_GHOST]
set BS3SAID [pcall ase::sim_said]
pcall ase::sim_apply_choice $ST_GHOST 0
check {BS3 a state asking for a simulator nobody has registered is labelled with what its run would start, which is what is in force, and the label says no sentence of its own} \
  [list $BS3L $BS3SAID [pcall ase::sim_selected]] \
  [list beta {} beta]

set BS4L [pcall ase::sim_session_label $ST_GONE]
check {BS4 a state asking for a registered simulator whose program is gone is labelled with that name and the mark that it will not run, not with the healthy one in force} \
  [list [expr {[string first gone $BS4L] == 0 ? 1 : 0}] \
        [expr {$BS4L ne {gone} ? 1 : 0}] \
        [expr {[string first beta $BS4L] < 0 ? 1 : 0}] \
        [pcall ase::sim_selected]] \
  [list 1 1 1 beta]

# =============================================================================
# BS5-BS11 -- the window
# =============================================================================
if {$HASX} {
  reg3
  set K1 [ase::session_key blib tb ngspice_state1]
  set K2 [ase::session_key blib tb ngspice_state2]
  set K3 [ase::session_key blib tb ngspice_state3]

  # --- BS5: THE REPORT ---------------------------------------------------
  set BS5BEFORE [pcall ase::sim_selected]
  set BS5OPEN [pcall ase::open_state blib tb ngspice_state1]
  update
  set BS5ST [pcall ase::sim_status ngspice]
  check {BS5 THE REPORT a state that asks for its own simulator opens with that simulator on its bar, and it is the one in force from that moment: nothing was run and nothing was picked} \
    [list $BS5BEFORE $BS5OPEN [barsim $K1] [pcall ase::sim_selected] \
          [pcall dict get $BS5ST entry] \
          [expr {[pcall dict get $BS5ST resolved] eq [file normalize $BETA] ? 1 : 0}]] \
    [list alpha 1 beta beta beta 1]

  # --- BS6: AND THAT IS WHAT STARTS ---------------------------------------
  ## The run's own first step (ase::run_deck -> ase::sim_apply_choice), then
  ## the command it composes, started for real.
  pcall ase::sim_apply_choice [pcall ase::session_state $K1]
  check {BS6 the program a run of that state composes and starts is the one the bar named when the window opened} \
    [list [who_runs $DECK] [barsim $K1]] \
    [list ZZ_BETA_RAN beta]

  # --- BS7: A SECOND WINDOW NAMES ITS OWN ----------------------------------
  set BS7OPEN [pcall ase::open_state blib tb ngspice_state2]
  update
  check {BS7 a second state with no choice of its own opens naming the installation default; the first window still names its own; what is in force is the window just opened} \
    [list $BS7OPEN [barsim $K2] [barsim $K1] [pcall ase::sim_selected]] \
    [list 1 alpha beta alpha]

  # --- BS8: COMING BACK TO A WINDOW ----------------------------------------
  set BS8OPEN [pcall ase::open_state blib tb ngspice_state1]
  update
  check {BS8 launching a state whose window is already open raises it and puts its simulator back in force; no bar changes} \
    [list $BS8OPEN [pcall ase::sim_selected] [barsim $K1] [barsim $K2]] \
    [list 1 beta beta alpha]

  # --- BS9: LOAD STATE AND REVERT ------------------------------------------
  set BS9LOAD [pcall ase::ui::do_load_state_from $K1 $P_ALPHA]
  update
  set BS9B [barsim $K1]
  set BS9F [pcall ase::sim_selected]
  pcall ase::ui::revert_state $K1
  update
  check {BS9 a state loaded into a window brings its simulator with it, on the bar and in force; Revert brings the saved one back the same way} \
    [list $BS9LOAD $BS9B $BS9F [barsim $K1] [pcall ase::sim_selected] [barsim $K2]] \
    [list 1 alpha alpha beta beta alpha]

  # --- BS10: A STATE THAT ASKS FOR A SIMULATOR NOBODY HAS REGISTERED --------
  pcall ase::sim_said_clear
  set BS10OPEN [pcall ase::open_state blib tb ngspice_state3]
  update
  set BS10SAID [pcall ase::sim_said]
  set BS10MINT [pcall ase::sim_why noentry ghostsim {} [list alpha beta gone]]
  check {BS10 a state asking for a simulator nobody has registered says so when it opens, once, in the sentence a run says; its bar names what its run would start and what is in force is left as it was} \
    [list $BS10OPEN \
          [expr {[string first $BS10MINT $BS10SAID] >= 0 ? 1 : 0}] \
          [regexp -all -- {ghostsim} $BS10SAID] \
          [barsim $K3] [pcall ase::sim_selected]] \
    [list 1 1 1 beta beta]

  # --- BS11: REPAINTING EVERY BAR MOVES NOTHING ----------------------------
  set BS11F0 [pcall ase::sim_selected]
  pcall ase::ui::refresh_status_all
  update
  check {BS11 repainting every open bar leaves what is in force as it was, and every bar still names its own} \
    [list $BS11F0 [pcall ase::sim_selected] [barsim $K1] [barsim $K2] [barsim $K3]] \
    [list beta beta beta alpha beta]

  foreach k [list $K1 $K2 $K3] { catch {ase::ui::close $k} }
  update
} else {
  foreach r {BS5 BS6 BS7 BS8 BS9 BS10 BS11} {
    puts "skip: $r needs a display (the session window's own bar)"
  }
}

# =============================================================================
# BS12 -- structural
# =============================================================================
set BS12B NOPROC
catch {set BS12B [info body ase::ui::refresh_status]}
check {BS12 STRUCTURAL the bar's simulator segment asks about its own session's state and never asks the process-wide question directly} \
  [list [expr {$BS12B ne {NOPROC} ? 1 : 0}] \
        [regexp -all -- {ase::sim_session_label \$st} $BS12B] \
        [regexp -all -- {ase::sim_label } $BS12B]] \
  [list 1 1 0]

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr : FAIL"
  puts $::errorInfo
  incr fail
}

catch {ase::sim_clear}
catch {test_scratch_drop $scratch}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
