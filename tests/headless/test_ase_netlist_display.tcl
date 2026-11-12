# tests/headless/test_ase_netlist_display.tcl -- Simulation > Netlist > Display
# shows the FINAL deck, as ADE-L's Netlist > Display shows input.scs.
#
# The user's report, 2026-11-11: "ASE-L > Simulation > Netlist > Display should
# show FINAL netlist - with sim cards, path to includes, models, etc ... I get
# only the circuit netlist currently." It opened <rundir>/<cell>.spice, the bare
# circuit netlist. ase::ui::netlist_display_text (src/ase_window.tcl) now renders
# the deck a Run would write, through the backend's own render_deck.
#   ND1  no netlist yet: nothing shown, and the message names the Recreate door
#   ND2  with a netlist: the deck is EXACTLY what render_deck gives for the bench
#   ND3  ...and it carries the circuit, the model card, the options, the
#        analysis and the control block, not the circuit alone
#   ND4  it is a read: Display writes no deck file and leaves the netlist as is
#   ND5  a bench whose simulator has no backend says why instead of opening
#   ND6  display arm: the window opens holding the deck, titled with its path
# Run: tests/headless/run_suites.sh [--nogui] test_ase_netlist_display

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}

set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch netdisp]
catch {ase::sim_clear}

set rundir [file join $scratch run]
file mkdir $rundir
set models [file join $scratch models.lib]
set f [open $models w] ; puts $f "* models\n.lib tt\n.endl tt" ; close $f

proc nd_session {key args} {
  global scratch rundir models
  set st [dict create design [dict create lib $scratch cell $key view schematic] \
            simulator ngspice rundir $rundir \
            models [list [dict create file $models section tt]] \
            options {{name reltol value 1e-4}} \
            analyses {{type tran enabled 1 step 1u stop 1m}} \
            outputs {} temperature 27]
  foreach {k v} $args { dict set st $k $v }
  set p [file join $scratch $key.state]
  ase::state_save $p $st
  ase::session_open $key $p
  ase::session_update $key $st
  return $st
}
set NL "* nd\nv1 in 0 1\nr1 in out 1k\nc1 out 0 1n\n.end\n"

# ND1 -- before any netlist.
set st [nd_session ndcell]
set d [ase::ui::netlist_display_text ndcell]
check {ND1 with no netlist yet Display shows nothing and names the Recreate door} \
  [list [dict get $d deck] [string match "*no netlist yet*Recreate*" [dict get $d msg]]] \
  {{} 1}

# ND2 -- with the netlist artifact on disk.
set nlf [file join $rundir ndcell.spice]
set f [open $nlf w] ; puts -nonewline $f $NL ; close $f
set want {}
catch {set want [ase::backend::ngspice::render_deck [ase::session_state ndcell] $NL]}
set d [ase::ui::netlist_display_text ndcell]
check {ND2 Display shows exactly the deck a Run renders for the bench as it stands} \
  [list [expr {$want ne {}}] [expr {[dict get $d deck] eq $want}] [dict get $d msg] \
        [dict get $d path]] \
  [list 1 1 {} [file join $rundir ndcell_ase.spice]]

# ND3 -- what makes it the FINAL deck rather than the circuit.
set deck [dict get $d deck]
set has {}
foreach {what pat} [list circuit {^r1 in out 1k$} \
                         model "^\\.lib \\S*models\\.lib\\S* tt$" \
                         option {^\.options? .*reltol=1e-4} \
                         analysis {^tran 1u 1m} \
                         control {^\.control$}] {
  lappend has $what [regexp -line -nocase -- $pat $deck]
}
check {ND3 the deck carries the circuit, the model card, the options, the analysis and the control block} \
  $has {circuit 1 model 1 option 1 analysis 1 control 1}

# ND4 -- a read, never a write.
set f [open $nlf r] ; set after [read $f] ; close $f
check {ND4 Display writes no deck file and leaves the netlist untouched} \
  [list [file exists [file join $rundir ndcell_ase.spice]] [expr {$after eq $NL}]] {0 1}

# ND5 -- a refusal is said, not opened.
nd_session ndbad simulator nosuchsim
set f [open [file join $rundir ndbad.spice] w] ; puts -nonewline $f $NL ; close $f
set d [ase::ui::netlist_display_text ndbad]
check {ND5 a bench whose simulator has no backend says why and shows no deck} \
  [list [dict get $d deck] [expr {[dict get $d msg] ne {}}]] {{} 1}

# ND6 -- the window itself.
if {[info commands winfo] eq {} || ![info exists ::has_x]} {
  puts "skip: ND6 needs a display (the window)"
} else {
  set before [winfo children .]
  ase::ui::view_netlist ndcell
  update
  set new {}
  foreach c [winfo children .] { if {[lsearch -exact $before $c] < 0} { lappend new $c } }
  set txt {} ; set title {}
  if {[llength $new] == 1} {
    set w [lindex $new 0]
    catch {set txt [$w.text get 1.0 end-1c]}
    set title [wm title $w]
    destroy $w
  }
  check {ND6 Display opens one window holding the deck, titled with the deck's path} \
    [list [llength $new] [expr {[string trimright $txt "\n"] eq [string trimright $want "\n"]}] $title] \
    [list 1 1 "Netlist: [file join $rundir ndcell_ase.spice]"]
}

set floor 5
if {$npass + $fail < $floor} {
  puts "FAIL: NDFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
