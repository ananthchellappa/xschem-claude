# issue 0112 (amnesty hole, adversarial review wf_bfc3c5e4) -- the push-through landing guard's
# grandfather clause is contact-KIND-blind: a foreign wire that already bbox-overlapped a promoted
# leg pre-move (an electrically-inert interior X crossing) amnesties ALL post-move contact with
# that same wire -- including a NEW, electrically-REAL endpoint-on-span T weld.
#
# Scene (38B geometry + a pre-crossing foreign wire): R1.M drives S down; V corners at J=(0,50).
# Foreign net FOO runs vertically at x=50 from y=45 to y=80: pre-move it crosses V's INTERIOR at
# (50,50) -- closed-bbox overlap, zero electrical contact (no endpoint of either lies on the
# other). The +30 drag pushes V through J onto row y=80, where FOO's endpoint (50,80) lands
# EXACTLY ON V's span: a T junction, FOO welded into R1.M's net. FOO is label-only (no device
# pin), so the pin-indexed leg_snap partition verify cannot see the merge -- the guard is the
# only line of defense, and the bbox-pair grandfather waves it through.
# Guard fix: a NEW exact endpoint-on-span contact declines even when the pair is grandfathered.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_52_pushthrough_amnesty_0112.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap $inst]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}
proc net_of_wire_at {x y} {
  xschem resolved_net 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$x && $y1==$y) || ($x2==$x && $y2==$y)} { return [xschem getprop wire $i lab] }
  }
  return {}
}

xschem clear force
uplevel #0 {set cadence_compat 1}
uplevel #0 {set fluid_editing 1}
uplevel #0 {set orthogonal_wiring 1}
uplevel #0 {set autotrim_wires 1}
uplevel #0 {set enable_stretch 1}
uplevel #0 {set unselect_partial_sel_wires 0}
uplevel #0 {set cadsnap 10}
xschem instance devices/res 0 0 0 0 {name=R1 m=1 value=1k}          ;# M at (0,30)
xschem wire 0 30 0 50   ;# S
xschem wire 0 50 90 50  ;# V (net of R1.M)
# V's far corner feeds a riser to label GOOD: V is LOAD-BEARING, so the delete-only de-shorters
# cannot repair a weld on V by pruning it (that would tear GOOD off R1.M -- a P1 break)
xschem wire 90 50 90 20
xschem instance {lab_pin.sym} 90 20 0 0 {name=lg lab=GOOD}
# foreign FOO: crosses V's interior at (50,50) pre-move (inert X crossing); its endpoint (50,80)
# sits exactly on V's push-through landing row y=80
xschem instance {lab_pin.sym} 50 45 0 1 {name=lf lab=FOO}
xschem wire 50 45 50 80
set before [dev_pin_map]
set r1 [inst_by_name R1]
xschem unselect_all
xschem select instance $r1
we_move_stretch 0 30                                                ;# M -> (0,60); V would land y=80
# NOTE: p2_no_short is deliberately NOT used here -- its geometric arm is bbox-strict and this
# scene's load-bearing ingredient IS a pre-existing inert X crossing (FOO across V), which that
# predicate flags even pre-gesture. The weld-specific checks below are the P2 assertions.
check "0112-amnesty P2: R1.M net stays distinct from FOO"         [expr {[pinnet R1 M] ne {FOO}}]
check "0112-amnesty P2: FOO wire not welded into R1.M's net" \
  [expr {[net_of_wire_at 50 45] ne [pinnet R1 M]}]
check "0112-amnesty P4: all manhattan"                            [all_manhattan]
check "0112-amnesty P1: no device pin-merge"                      [p2_no_device_merge $before]
check "0112-amnesty P1: GOOD still on R1.M's net (V not simply deleted)" \
  [expr {[net_of_wire_at 90 20] eq [pinnet R1 M]}]
we_result
