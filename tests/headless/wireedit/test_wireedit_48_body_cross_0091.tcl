# issue 0091 -- a STATIONARY same-net follow-wire CROSSES the MOVED instance's own body because the
# END redundant-route cleanup (0088-0090) was WHOLESALE-gated off whenever the user selected any wire.
# doc/claude/issues/0091-fluid-reroute-samenet-crosses-moved-body.md
#
# Repro: tests/from_user/before_5.sch. Select C12 + R18 + the #net2 connecting wire (the user's real
# gesture: fluid_startsel_wires=3), drag the group by (-20,+60). R18 lands at (-280,10); its M pin
# (#net1) sits below the fixed #net1 backbone at y=-10, so the follow reroute wraps the M riser around
# R18's right side and joins the backbone at (-260,-10) -- but the backbone then runs from -260 to -400
# at y=-10 straight THROUGH R18's body (x in [-287.5,-272.5]).
#   RED  (HEAD f66aec00): #net1 keeps the backbone (-400,-10)-(-260,-10) crossing R18 -> p5 FAILS.
#   GREEN (fix on): the cleanup now runs (declining only the user's own net PER-COMPONENT) and routes
#         R18.M under R18 and up the far-left column x=-400 -- no body cross, ~40u shorter.
#
# The fix relaxes the wholesale fluid_startsel_wires==0 gate to a per-component decline
# (fluid_mark_user_protected): a follow-wire on a net the user did NOT select is cleaned; the user's own
# selected net is left intact. Runs true-headless (scripted move == interactive release, Phase II).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_48_body_cross_0091.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
# do instances a and b share at least one resolved net? (connectivity witness)
proc share_net {a b} {
  xschem resolved_net 0
  set ai [inst_by_name $a]; set bi [inst_by_name $b]
  set am [xschem instance_nodemap $ai]; set bm [xschem instance_nodemap $bi]
  set an {}; foreach {p nn} [lrange $am 1 end] { if {$nn ne {}} { lappend an $nn } }
  foreach {p nn} [lrange $bm 1 end] { if {$nn ne {} && [lsearch -exact $an $nn] >= 0} { return 1 } }
  return 0
}
proc wire_exists {ax ay bx by} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$ax && $y1==$ay && $x2==$bx && $y2==$by) || ($x1==$bx && $y1==$by && $x2==$ax && $y2==$ay)} { return 1 }
  }
  return 0
}
# reconstruct tests/from_user/before_5.sch in memory (bare wires; nets resolve from geometry)
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
# the three #net2 spans that connect C12's bottom pin to R18's M pin (the user's selected connecting wire)
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

# ---- Case R: the repro. Group drag (-20,+60) with #net2 user-selected: #net1 must NOT cross R18. -----
build_before5
select_group_with_net2
we_move_stretch -20 60

check "R P5 no body cross: no wire threads R18's body (the reported defect)" [p5_no_body_cross]
# the crossing backbone (-400,-10)-(-260,-10) that RAN THROUGH R18 is gone
check "R crossing gone: no #net1 backbone at y=-10 through x=-280" \
  [expr {![wire_exists -400 -10 -260 -10]}]
# the clean route: R18.M exits down (-280,40)-(-280,50), runs left under R18, up the far-left column -400
check "R clean M-stub: (-280,40)-(-280,50)"      [wire_exists -280 40 -280 50]
check "R clean under-run: (-400,50)-(-280,50)"   [wire_exists -400 50 -280 50]
check "R clean riser:    (-400,50)-(-400,140)"   [wire_exists -400 50 -400 140]
check "R P1: R18 still shares a net with C12 (net2 preserved)"  [share_net R18 C12]
check "R P1: R18.M still shares a net with ammeter v8 (net1 preserved)" [share_net R18 v8]
check "R P2: no short (nets not merged)"        [p2_no_short]
check "R P4: every leg axis-aligned"            [p4_orthogonal]

# ---- Case A: instances-only group drag was already clean; it must STAY clean (no regression). --------
build_before5
xschem unselect_all
xschem select instance [inst_by_name C12]
xschem select instance [inst_by_name R18]
we_move_stretch -20 60
check "A P5 no body cross (instances-only, was already clean)" [p5_no_body_cross]
check "A crossing absent"                        [expr {![wire_exists -400 -10 -260 -10]}]
check "A P1 net2 preserved"                       [share_net R18 C12]
check "A P2 no short"                             [p2_no_short]

# ---- Case P (protection / "selection wins"): if the user ALSO selects a #net1 wire, the cleanup must
#      DECLINE reshaping #net1 (per-component protection) -- but must never break connectivity/short. --
build_before5
select_group_with_net2
# additionally select the #net1 M-riser wire (-260,-20)-(-260,-10): now #net1 is user-protected
set nw [xschem get wires]
for {set i 0} {$i < $nw} {incr i} {
  lassign [xschem wire_coord $i] x1 y1 x2 y2
  if {($x1==-260 && $y1==-20 && $x2==-260 && $y2==-10) || ($x1==-260 && $y1==-10 && $x2==-260 && $y2==-20)} {
    xschem select wire $i
  }
}
we_move_stretch -20 60
check "P P1: R18 still shares a net with C12 (protected move safe)"   [share_net R18 C12]
check "P P1: R18.M still shares a net with ammeter v8 (protected move safe)" [share_net R18 v8]
check "P P2: no short in the protected move"     [p2_no_short]
check "P P4: orthogonal in the protected move"   [p4_orthogonal]

# ---- Case N: a small non-crossing group drag must not be over-reshaped (strict scope, no-op safety). -
build_before5
select_group_with_net2
we_move_stretch 0 -20
check "N P1 net2 preserved"                       [share_net R18 C12]
check "N P2 no short"                             [p2_no_short]
check "N P5 no body cross"                        [p5_no_body_cross]

we_result
