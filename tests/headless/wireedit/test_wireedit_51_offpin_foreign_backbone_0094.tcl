# issue 0094 -- a rigid GROUP drag lands a moved device's OFF-net pin exactly on a foreign net's backbone,
# shorting the two nets and wrapping the follow-riser into a loop through the device body.
# doc/claude/issues/0094-fluid-group-drag-offpin-lands-foreign-backbone-short-loop.md
#
# Repro: tests/from_user/before_5.sch. Select C12 + R18 + the #net2 connecting wire (fluid_startsel_wires=3),
# drag the group by (-40,+70) (0091 is the SAME selection dragged by (-20,+60)). R18 lands so its #net2 TOP
# pin sits at (-300,-10) -- exactly on the fixed #net1 backbone (-400,-10)-(-260,-10) -> #net1 == #net2, and
# the #net1 M-riser wraps (-300,50)-(-300,60)-(-260,60)-(-260,-10) closing a loop through R18's body.
#   RED  (pre-fix): R18's two pins both resolve to #net1 (device short); the backbone crossing survives.
#   GREEN (fix on): fluid_ripup_foreign_pin_short slides the #net1 backbone off R18's top pin down onto R18's
#         bottom-pin row and fluid_prune_novel_orphan_stub trims the tail -> R18.M routes to the far-left
#         column, R18's top pin is clear, no short, no loop (same clean shape as 0091's (-20,+60) result).
#
# The pin position is fixed by the rigid move, so only the foreign copper can move: this is the deferred
# nice_drag_rerouting Phase-4 "no-short + rip-up". Runs true-headless (scripted move == interactive release).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_51_offpin_foreign_backbone_0094.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc share_net {a b} {
  xschem resolved_net 0
  set ai [inst_by_name $a]; set bi [inst_by_name $b]
  set am [xschem instance_nodemap $ai]; set bm [xschem instance_nodemap $bi]
  set an {}; foreach {p nn} [lrange $am 1 end] { if {$nn ne {}} { lappend an $nn } }
  foreach {p nn} [lrange $bm 1 end] { if {$nn ne {} && [lsearch -exact $an $nn] >= 0} { return 1 } }
  return 0
}
# R18's two pins resolve to DISTINCT nets (the device is NOT shorted)
proc r18_pins_distinct {} {
  xschem resolved_net 0
  set m [xschem instance_nodemap [inst_by_name R18]]
  set nets {}
  foreach {p nn} [lrange $m 1 end] { lappend nets $nn }
  return [expr {[lindex $nets 0] ne [lindex $nets 1]}]
}
proc wire_exists {ax ay bx by} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$ax && $y1==$ay && $x2==$bx && $y2==$by) || ($x1==$bx && $y1==$by && $x2==$ax && $y2==$ay)} { return 1 }
  }
  return 0
}
# is there any wire whose span covers world point (px,py)? (used to prove R18's top pin is left clear)
proc wire_covers_point {px py} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$y1==$y2 && $y1==$py && $px >= [expr {min($x1,$x2)}] && $px <= [expr {max($x1,$x2)}]} { return 1 }
    if {$x1==$x2 && $x1==$px && $py >= [expr {min($y1,$y2)}] && $py <= [expr {max($y1,$y2)}]} { return 1 }
  }
  return 0
}
# a net1 vertical column at x=-400 reaching the v8/OUT row (y=140) -- the reroute target
proc has_leftcol_riser {} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1==-400 && $x2==-400 && ([expr {max($y1,$y2)}]>=140)} { return 1 }
  }
  return 0
}
proc build_before5 {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -320 -190 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res     -260  -50 0 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140} {-550 140 -400 140}
    {-400 140 -390 140} {-400 -10 -400 140} {-260 -150 -260 -80} {-320 -300 -320 -220}
    {-320 -150 -260 -150} {-400 -10 -260 -10} {-420 -300 -320 -300} {-320 -160 -320 -150}
    {-260 -20 -260 -10}
  } { xschem wire {*}$w }
}
set NET2_SPANS { {-260 -150 -260 -80} {-320 -150 -260 -150} {-320 -160 -320 -150} }
proc select_group_with_net2 {} {
  global NET2_SPANS
  xschem unselect_all
  xschem select instance [inst_by_name C12]
  xschem select instance [inst_by_name R18]
  set nw [xschem get wires]
  foreach span $NET2_SPANS {
    lassign $span ax ay bx by
    for {set i 0} {$i < $nw} {incr i} {
      lassign [xschem wire_coord $i] x1 y1 x2 y2
      if {($x1==$ax && $y1==$ay && $x2==$bx && $y2==$by) || ($x1==$bx && $y1==$by && $x2==$ax && $y2==$ay)} {
        xschem select wire $i
      }
    }
  }
}

# ---- Case S: the repro. Group drag (-40,+70): R18's top pin lands on the #net1 backbone. -----------------
build_before5
select_group_with_net2
we_move_stretch -40 70

check "S no device short: R18's two pins are on DISTINCT nets (the reported defect)" [r18_pins_distinct]
check "S P1: R18 still shares a net with C12 (#net2 preserved)"            [share_net R18 C12]
check "S P1: R18 still shares a net with ammeter v8 (#net1 preserved)"     [share_net R18 v8]
check "S P1: C12 still shares a net with itself/net3 (top pin kept)"       [expr {[wire_exists -420 -300 -360 -300] || [wire_covers_point -360 -300]}]
check "S crossing gone: no #net1 backbone (-400,-10)-(-260,-10)"           [expr {![wire_exists -400 -10 -260 -10]}]
check "S top pin CLEAR: no wire covers R18's top pin (-300,-10) except its own #net2 leg down" \
      [expr {![wire_exists -400 -10 -300 -10] && ![wire_covers_point -350 -10]}]
check "S reroute: a #net1 riser reaches the far-left x=-400 column"        [has_leftcol_riser]
check "S no loop: the wrapped riser (-260,60)-(-260,-10) is gone"          [expr {![wire_exists -260 60 -260 -10]}]
check "S P2: no short (nets not merged)"                                   [p2_no_short]
check "S P4: every leg axis-aligned"                                      [p4_orthogonal]
check "S P5: no wire threads a device body"                               [p5_no_body_cross]

# ---- Case Z: 0091's own delta (-20,+60) must STAY clean and must NOT need a rip-up (no regression). ------
build_before5
select_group_with_net2
we_move_stretch -20 60
check "Z 0091 delta still no short"                    [r18_pins_distinct]
check "Z 0091 delta #net2 preserved"                   [share_net R18 C12]
check "Z 0091 delta #net1 preserved"                   [share_net R18 v8]
check "Z 0091 delta crossing gone"                     [expr {![wire_exists -400 -10 -260 -10]}]
check "Z 0091 delta P5 no body cross"                  [p5_no_body_cross]

# ---- Case N: a tiny non-shorting group drag must be untouched by the rip-up (strict no-op safety). -------
build_before5
select_group_with_net2
we_move_stretch 0 -20
check "N small move: no short"                         [r18_pins_distinct]
check "N small move: #net2 preserved"                  [share_net R18 C12]
check "N small move: #net1 preserved"                  [share_net R18 v8]
check "N small move: P5 no body cross"                 [p5_no_body_cross]

we_result
