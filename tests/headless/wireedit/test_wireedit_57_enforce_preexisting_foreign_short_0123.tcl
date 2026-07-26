# issue 0123 -- the END enforce gate (fluid_enforce_invariants) must refuse ONLY on shorts THIS
# gesture introduces, not on a PRE-EXISTING naming short elsewhere in the schematic.
#
# Regression scene (tests/from_user/move_refuse.sch): five wires chain-connect into ONE physical
# net carrying four conflicting names (ipin A, ipin B, lab_pin a, lab_pin b). Deleting the y=0 wire
# splits it: net-alpha (top + right-vertical) is a CLEAN single-name net "A"; net-beta (left) still
# carries a/B/b -> 2 pre-existing label shorts. Connected-stretching net-alpha's isolated vertical
# segment can short nothing, yet the ABSOLUTE label-short pass counted net-beta's 2 shorts and
# refused the move. Fix: label-short signal is now DELTA vs the gesture-start baseline.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_57_*.tcl
source [file join [file dirname [info script]] fixtures.tcl]

proc setvars {} {
  foreach {k v} {cadence_compat 1 orthogonal_wiring 1 autotrim_wires 1 enable_stretch 1
                 unselect_partial_sel_wires 0 cadsnap 10 fluid_editing 1 wire_exit_stub 0
                 fluid_enforce_invariants 1} { uplevel #0 [list set $k $v] }
}
proc vcoord {x1 y1 x2 y2} {  ;# find wire index by its (order-independent) endpoints, -1 if none
  set nw [xschem get wires]
  set want [lsort [list [list $x1 $y1] [list $x2 $y2]]]
  for {set i 0} {$i < $nw} {incr i} {
    set c [xschem wire_coord $i]
    set got [lsort [list [list [lindex $c 0] [lindex $c 1]] [list [lindex $c 2] [lindex $c 3]]]]
    if {$got eq $want} { return $i }
  }
  return -1
}

setvars
xschem clear force
xschem wire -20 -60 70 -60
xschem wire 70 -60 70 0
xschem wire -20 0 70 0
xschem wire -20 0 -20 60
xschem wire -20 60 70 60
xschem instance devices/ipin    -20 -60 0 0 {name=p1 lab=A}
xschem instance devices/ipin    -20 30  0 0 {name=p2 lab=B}
xschem instance devices/lab_pin  -20 0  0 0 {name=l1 lab=a}
xschem instance devices/lab_pin  -20 60 0 0 {name=l2 lab=b}
xschem unselect_all

# delete the y=0 bridge wire -> net splits into clean alpha + shorted beta
xschem unselect_all
xschem select_at 25 0
xschem delete
check "setup: y=0 wire deleted, net split" [expr {[vcoord -20 0 70 0] < 0}]

# connected-stretch net-alpha's isolated vertical (70,-60)-(70,0) LEFT by 30
xschem unselect_all
xschem select_at 70 -30
xschem move_objects -30 0 stretch kissing

# the pre-existing beta short must NOT be attributed to this move (delta == 0)
check "0123: pre-existing foreign short does NOT count as a move violation" \
  [expr {$::fluid_last_move_violations == 0}]

# the move must COMMIT: the vertical moved 70 -> 40, so no wire remains at x=70,
# and a vertical now exists at x=40.
check "0123: valid stretch was NOT refused (vertical committed 70 -> 40)" \
  [expr {[vcoord 70 -60 70 0] < 0 && [vcoord 40 -60 40 0] >= 0}]

# the top wire followed the moved tip to x=40
check "0123: top wire followed the stretch (-20,-60)-(40,-60)" \
  [expr {[vcoord -20 -60 40 -60] >= 0}]

we_result
