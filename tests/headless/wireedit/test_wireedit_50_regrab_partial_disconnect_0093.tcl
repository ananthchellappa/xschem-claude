# issue 0093 -- RE-GRAB of a wire left PARTIALLY selected by a prior fluid stretch DISCONNECTS the net.
# doc/claude/issues/0093-fluid-regrab-partial-selection-disconnect.md
#
# Repro (tests/from_user/before_6.sch -> after_13.sch): grab R18.M's #net1 rung, drag it (0092 shoves
# the rail riser to x=-510), RELEASE, then WITHOUT reselecting grab the SAME rung again and drag it
# diagonally (up+right). A fluid stretch relays the user's own grabbed wire to a PARTIAL selection
# (SELECTED1/2); with the cadence default unselect_partial_sel_wires=0 that persists. On the 2nd
# gesture an already-selected press skips the fresh select_object(), so select_attached_nets() sees the
# rung as SELECTED2 (not full SELECTED) and its `!= SELECTED` guard SKIPS grabbing the follow-risers.
# The rung then translates ALONE: the rail riser (-510,70)-(-510,140) orphans and fluid_straighten_
# reversals deletes it -> R18.M silently drops off #net1 onto an isolated #net3.
#
# Fix (move.c, END selection normalize): in the fluid mixed case (fluid_startsel_wires>0) restore the
# user's OWN wires (by 0091 session-stable id) to FULL SELECTED + deselect tool follow-wires, so a
# re-grab is a clean whole-object move that follows its risers.
#
# RED-first: pre-fix the 2nd drag leaves rung on #net3, deletes the rail riser (-510,40)-(-510,140),
# and R18.M no longer reaches the top rail. GREEN: risers follow, R18.M stays on #net1 end-to-end.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_50_regrab_partial_disconnect_0093.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc sel_wire {ax ay bx by} {
  xschem unselect_all
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {(($x1==$ax && $y1==$ay && $x2==$bx && $y2==$by) ||
         ($x1==$bx && $y1==$by && $x2==$ax && $y2==$ay))} { xschem select wire $i; return $i }
  }
  return -1
}
proc wire_exists {ax ay bx by} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$ax && $y1==$ay && $x2==$bx && $y2==$by) ||
        ($x1==$bx && $y1==$by && $x2==$ax && $y2==$ay)} { return 1 }
  }
  return 0
}
proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc inst_nets {name} {
  xschem resolved_net 0
  set m [xschem instance_nodemap [inst_by_name $name]]; set out {}
  foreach {p nn} [lrange $m 1 end] { if {$nn ne {}} { lappend out $nn } }
  return $out
}
proc net_of_wire {ax ay bx by} {
  xschem resolved_net 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$ax && $y1==$ay && $x2==$bx && $y2==$by) ||
        ($x1==$bx && $y1==$by && $x2==$ax && $y2==$ay)} { return [xschem getprop wire $i lab] }
  }
  return ""
}
# R18.M reaches the top rail iff the rail wire carries one of R18's nets (R18.P is #net2, so any
# shared net is the #net1 staircase, not a coincidence)
proc r18_reaches {ax ay bx by} {
  set wn [net_of_wire $ax $ay $bx $by]
  return [expr {$wn ne "" && [lsearch -exact [inst_nets R18] $wn] >= 0}]
}
proc share_net {a b} {
  foreach na [inst_nets $a] { foreach nb [inst_nets $b] { if {$na eq $nb} { return 1 } } }
  return 0
}

proc build_before6 {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res     -360  -10 0 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140}
    {-550 140 -470 140} {-470 140 -390 140}
    {-420 -170 -420 -100} {-360 -100 -360 -40} {-420 -100 -360 -100}
    {-470 50 -360 50} {-470 50 -470 140} {-360 20 -360 50}
  } { xschem wire {*}$w }
}

# ============ build fixture + gesture 1 (grab rung, drag left -> 0092 shoves riser to x=-510) ========
build_before6
check "pre: middle rung selected" [expr {[sel_wire -470 50 -360 50] >= 0}]
we_move_stretch -40 20
check "g1: rung shoved to (-510,70)-(-360,70)"        [wire_exists -510 70 -360 70]
check "g1: rail riser at x=-510 (-510,70)-(-510,140)" [wire_exists -510 70 -510 140]
check "g1: R18.M reaches top rail after g1"           [r18_reaches -550 140 -510 140]

# ============ gesture 2: RE-GRAB the SAME rung WITHOUT reselecting, drag diagonally up+right =========
# NO sel_wire here -- drive the move on the selection the 1st stretch LEFT behind (the GUI's
# already-selected press path). The incremental seam's `start` runs select_attached_nets on that
# leftover selection, exactly as the interactive re-grab does.
xschem move_objects start -460 70 kissing stretch
xschem move_objects step  -460 60
xschem move_objects step  -450 50
xschem move_objects step  -440 50
xschem move_objects step  -440 40
xschem move_objects end

# ---- P1 (connectivity, the HARD invariant) : R18.M must still reach the top rail on ONE net --------
check "g2: R18.M STILL reaches top rail (-550,140)-(-510,140)" [r18_reaches -550 140 -510 140]
check "g2: R18 and v8 share a net (staircase intact)" [share_net R18 v8]
check "g2: rung NOT on an isolated #net3" [expr {[lsearch -glob [inst_nets R18] {#net3}] < 0}]
# ---- the rail riser followed the drag (was orphaned+deleted pre-fix) --------------------------------
check "g2: rail riser followed to (-510,40)-(-510,140)" [wire_exists -510 40 -510 140]
check "g2: rung followed to (-510,40)-(-360,40)"        [wire_exists -510 40 -360 40]
check "g2: pin riser followed to (-360,20)-(-360,40)"   [wire_exists -360 20 -360 40]
# ---- no disconnect debris ---------------------------------------------------------------------------
check "g2: NO orphan down-stub at (-490,40)-(-490,70)"  [expr {![wire_exists -490 40 -490 70]}]
check "g2: no dangling tip at (-490,40)"                [expr {![has_endpoint -490 40]}]
check "g2: manhattan"                                    [all_manhattan]
check "g2: P2 no short"                                  [p2_no_short]

we_result
