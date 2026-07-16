# nice_drag_rerouting Phase 3 -- exit-stub slide must NOT orphan a branch tapping the slid leg.
#
# Adversarial-review follow-up: enabling the fluid nice escape fires insert_exit_stubs on every
# orthogonal fluid stretch. The slide shifts a moved pin's first leg one grid along the escape
# normal. If a THIRD wire branches off that leg (a T-tap carrying another instance's pin), the
# slide must carry the branch along, not leave it one grid off the leg -- else that pin is
# silently disconnected (P1). This test proves connectivity IS preserved: xschem keeps wires
# split at the junction so the tap is a corner the has_corner neighbour-drag moves with the leg.
# Checked under BOTH autotrim modes (the review flagged autotrim OFF specifically).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_31_tapped_leg_connectivity.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc ibn {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc pin_net {inst pin} {
  set map [xschem instance_nodemap $inst]
  foreach {p node} [lrange $map 1 end] { if {$p eq $pin} { return $node } }
  return {}
}

# Build a res whose pin M carries a HORIZONTAL first leg (0,30)-(100,30) with a corner up to a
# label, plus a mid-leg tap at (50,30) branching up to a second device RB.P. Dragging RA +X
# (parallel to the leg) keeps the leg horizontal with the tap still on it, and fires the exit
# stub at pin M -- the slide that could orphan the branch. RB.P must stay on net NM.
proc build_tapped {autotrim} {
  we_reset 1 1
  uplevel #0 [list set cadence_compat 1]
  uplevel #0 [list set fluid_editing 1]
  uplevel #0 [list set autotrim_wires $autotrim]
  xschem instance devices/res 0 0 0 0 {name=RA}       ;# pin M(0,30) normal +y
  xschem wire 0 30 100 30                             ;# horizontal first leg
  xschem wire 100 30 100 130                          ;# corner up to label
  xschem instance {lab_pin.sym} 100 130 0 0 {name=LM lab=NM}
  xschem wire 50 30 50 130                            ;# mid-leg tap -> RB.P
  xschem instance devices/res 50 160 0 0 {name=RB}    ;# RB pin P(50,130) on the tap
}

foreach at {0 1} {
  build_tapped $at
  check "autotrim=$at: RB.P starts on net NM (tap connected)" [expr {[pin_net RB P] eq "NM"}]
  set snap [net_snapshot]
  xschem unselect_all; xschem select instance [ibn RA]
  we_move_stretch 40 0                                 ;# slide fires; branch must follow
  check "autotrim=$at: P1 connectivity invariant holds (branch not orphaned)" [p1_netlist_invariant $snap]
  check "autotrim=$at: RB.P still on net NM after the slide" [expr {[pin_net RB P] eq "NM"}]
  check "autotrim=$at: runtime P1 guard flags 0 disconnects" \
    [expr {[info exists ::fluid_last_move_disconnects] && $::fluid_last_move_disconnects == 0}]
  check "autotrim=$at: pin M still on net NM" [expr {[pin_net RA M] eq "NM"}]
  check "autotrim=$at: exit stub fired at pin M (40,30)-(40,40)" [has_seg 40 30 40 40]
}

we_result
