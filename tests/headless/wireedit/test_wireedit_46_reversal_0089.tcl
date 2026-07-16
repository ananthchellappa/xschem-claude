# issue 0089 -- REDUNDANT SAME-NET U-TURN (reversal) straighten (doc/claude/issues/0089-*.md).
#
# Sibling of 0088 (test_wireedit_45). The 0088 loop-remover DELETES a redundant same-net CYCLE. But a
# FAR move whose landing COLUMN differs from the stationary riser column leaves a same-net PATH (no
# cycle) that DOUBLES BACK: the route bulges out to an intermediate column and returns. Delete-only
# cannot fix a tree; fluid_straighten_reversals() SLIDES the jog to the nearer neighbour column,
# collapses the overshoot, and retracts the orphaned riser tail -- yielding the clean L the router
# wanted.
#
# Repro: tests/from_user/before_3.sch, drag R18 by (-80,-60) [(-400,-40)->(-480,-100)].
#   RED  (pass compiled out): #net2 is a 5-wire staircase that rings out to x=-400 and back
#        (tests/from_user/after_9.sch): (-420,-90)(-400,-90) / (-400,-90)(-400,-140) /
#        (-480,-140)(-400,-140) + the C12 riser + the R18-M stub.
#   GREEN (fix on): #net2 collapses to the clean 3-seg L
#        (-420,-170)-(-420,-140) / (-480,-140)-(-420,-140) / (-480,-140)-(-480,-130).
#
# The scripted move path (move_objects stretch kissing) is byte-identical to the interactive drag
# release (Phase II), so this runs TRUE HEADLESS via --nogui.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_46_reversal_0089.tcl
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
# list of {x1 y1 x2 y2} for every wire on resolved net $want
proc wires_on_net {want} {
  set nw [xschem get wires]; set out {}
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {[xschem getprop wire $i lab] eq $want} { lappend out [list $x1 $y1 $x2 $y2] }
  }
  return $out
}
proc set_has_cycle {wires} {
  array unset nid; set nn 0; array unset par
  foreach w $wires {
    lassign $w x1 y1 x2 y2
    foreach k [list "$x1,$y1" "$x2,$y2"] { if {![info exists nid($k)]} { set nid($k) $nn; set par($nn) $nn; incr nn } }
  }
  proc _f {a i} { upvar 1 $a p; while {$p($i)!=$i} { set p($i) $p($p($i)); set i $p($i) }; return $i }
  foreach w $wires {
    lassign $w x1 y1 x2 y2
    set u [_f par $nid($x1,$y1)]; set v [_f par $nid($x2,$y2)]
    if {$u == $v} { return 1 }
    set par($u) $v
  }
  return 0
}
proc build_before3 {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res     -400  -40 0 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140} {-400 -10 -400 140}
    {-420 -90 -400 -90} {-550 140 -400 140} {-400 140 -390 140} {-420 -170 -420 -90}
    {-400 -90 -400 -70}
  } { xschem wire {*}$w }
}
proc select_r18 {} { set r [inst_by_name R18]; xschem unselect_all; xschem select instance $r }
proc has_endpoint {x y} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$x && $y1==$y) || ($x2==$x && $y2==$y)} { return 1 }
  }
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

# ---- Case R: the repro. R18 stretch (-80,-60): #net2 U-turn must straighten to the clean L. --------
build_before3
select_r18
we_move_stretch -80 -60

set n2 [wires_on_net "#net2"]
check "R no-cycle: #net2 is a tree (no loop)"                 [expr {![set_has_cycle $n2]}]
check "R three-wire-L: #net2 is exactly 3 wires (not the 5-wire detour)" [expr {[llength $n2] == 3}]
# the reversal excursion to x=-400 is GONE (RED left copper at x=-400)
check "R no x=-400 excursion: no #net2 corner at x=-400"      \
  [expr {![has_endpoint -400 -90] && ![has_endpoint -400 -140]}]
# exact clean-L geometry: C12 riser (-420,-170)-(-420,-140), cross (-480,-140)-(-420,-140), M stub (-480,-140)-(-480,-130)
check "R L-riser: (-420,-170)-(-420,-140)"                    [wire_exists -420 -170 -420 -140]
check "R L-cross:  (-480,-140)-(-420,-140)"                   [wire_exists -480 -140 -420 -140]
check "R L-mstub:  (-480,-140)-(-480,-130)"                   [wire_exists -480 -140 -480 -130]
check "R P1: R18 still shares a net with C12 (net2 preserved)" [share_net R18 C12]
check "R P2: no short (nets not merged)"                      [p2_no_short]
check "R P4: every leg axis-aligned"                         [p4_orthogonal]

# ---- Case S (scope): an ISOLATED user ring on its own net is NOT reshaped by the straightener. -----
# The straightener mutates non-seed copper (its tail-retract), so it MUST be span-novelty scoped: an
# untouched ring elsewhere -- whose auto #net merely renumbers when it is added -- stays 100% intact.
build_before3
foreach w { {200 200 260 200} {260 200 260 260} {260 260 200 260} {200 260 200 200} } { xschem wire {*}$w }
select_r18
we_move_stretch -80 -60
set ring 0
foreach e { {200 200 260 200} {260 200 260 260} {260 260 200 260} {200 260 200 200} } {
  if {[wire_exists {*}$e]} { incr ring }
}
check "S scope: untouched user ring 100% intact (4/4 edges)"  [expr {$ring == 4}]
check "S repro still straightens (x=-400 excursion gone)"     \
  [expr {![has_endpoint -400 -90] && ![has_endpoint -400 -140] && [has_endpoint -420 -140]}]

# ---- Case N: a small NON-reversing stretch must not be over-straightened (strict scope). -----------
build_before3
select_r18
we_move_stretch 0 -20
check "N P1: R18 still shares a net with C12"                 [share_net R18 C12]
check "N P2: no short"                                        [p2_no_short]
check "N manhattan"                                           [all_manhattan]

we_result
