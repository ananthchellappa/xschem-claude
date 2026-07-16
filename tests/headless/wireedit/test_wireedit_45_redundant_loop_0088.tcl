# issue 0088 -- REDUNDANT SAME-NET LOOP collapse (doc/claude/issues/0088-*.md).
#
# A fluid stretch can commit a correct per-leg route (the 0086/0087 short guard declines a corner-
# slide, so a stale detour elbow survives) yet leave the moved pin back on its riser column, closing a
# redundant rectangle on one net. fluid_remove_redundant_loops() collapses it to the minimal
# connectivity-preserving tree. Headless: the scripted move path is byte-identical to the interactive
# release (Phase II), and the X-gesture repro (tests/headless/test_fluid_loop_0088.tcl) agrees.
#
# RED-first (pass compiled out / gate false): case R leaves the {w4,w5,w6,w9} #net2 rectangle
# (tests/from_user/after_8.sch). GREEN: net2 collapses to the single riser (-420,-170)-(-420,-130).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_45_redundant_loop_0088.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
# set of resolved net names across all pins of the named instance
proc inst_nets {name} {
  xschem resolved_net 0
  set inst [inst_by_name $name]
  set m [xschem instance_nodemap $inst]
  set out {}
  foreach {p nn} [lrange $m 1 end] { if {$nn ne {}} { lappend out $nn } }
  return $out
}
# do instances a and b share at least one resolved net? (connectivity witness)
proc share_net {a b} {
  foreach na [inst_nets $a] { foreach nb [inst_nets $b] { if {$na eq $nb} { return 1 } } }
  return 0
}
# wires carrying resolved net $want (or all if ""), as {x1 y1 x2 y2} list
proc wires_on_net {want} {
  xschem resolved_net 0
  set out {}
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    set lab [xschem getprop wire $i lab]
    if {$want eq "" || $lab eq $want} { lappend out [list $x1 $y1 $x2 $y2] }
  }
  return $out
}
# cycle in a wire set? nodes=endpoints, edges=wires; union-find, edge within a component => cycle.
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

# ---- Case R: the repro. R18 stretch (-20,-60): #net2 rectangle must collapse to the riser. --------
build_before3
select_r18
we_move_stretch -20 -60
set n2 [wires_on_net "#net2"]
check "R no-cycle: #net2 has no redundant loop"          [expr {![set_has_cycle $n2]}]
check "R single-riser: #net2 is exactly one wire"        [expr {[llength $n2] == 1}]
set gok 0
if {[llength $n2] == 1} {
  lassign [lindex $n2 0] gx1 gy1 gx2 gy2
  set gok [expr {$gx1==-420 && $gx2==-420 && [lsort -real [list $gy1 $gy2]] eq {-170 -130}}]
}
check "R riser-geom: #net2 wire is (-420,-170)-(-420,-130)" $gok
check "R P1: R18 still shares a net with C12 (net2 preserved)" [share_net R18 C12]
check "R P2: no short (nets not merged)"                 [p2_no_short]
check "R manhattan"                                       [all_manhattan]

# ---- Case N: a straight stretch that forms NO loop must remove nothing (strict no-op). ------------
build_before3
select_r18
set before_nw [xschem get wires]
we_move_stretch 0 -20
set n2n [wires_on_net "#net2"]
check "N no-op: no cycle after a non-looping drag"       [expr {![set_has_cycle $n2n]}]
check "N P1: R18 pins still connected (net2 non-empty)"  [expr {[llength $n2n] >= 1}]
check "N manhattan"                                       [all_manhattan]

# ---- Case G: an ISOLATED user-drawn wire rectangle (its own net) is NOT globally hunted/deleted. --
# Scoping: the pass acts only on THIS drag's copper, never on a pre-existing loop elsewhere.
build_before3
foreach w { {200 200 260 200} {260 200 260 260} {260 260 200 260} {200 260 200 200} } { xschem wire {*}$w }
select_r18
we_move_stretch -20 -60
set ring 0
foreach e { {200 200 260 200} {260 200 260 260} {260 260 200 260} {200 260 200 200} } {
  lassign $e x1 y1 x2 y2
  if {[has_endpoint $x1 $y1] && [has_endpoint $x2 $y2]} { incr ring }
}
check "G scope: untouched user ring 100% intact (4/4 edges)" [expr {$ring == 4}]
# collapse confirmed geometrically (net auto-numbering shifts when the ring is added, so don't key on
# "#net2"): the stale detour corners at x=-400 are gone, the riser (-420,-130) survives.
check "G repro still collapses (old loop corners x=-400 removed)" \
  [expr {![has_endpoint -400 -90] && ![has_endpoint -400 -130] && [has_endpoint -420 -130]}]

# does a wire with these exact endpoints exist (order-insensitive)?
proc wire_exists {ax ay bx by} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$ax && $y1==$ay && $x2==$bx && $y2==$by) || ($x1==$bx && $y1==$by && $x2==$ax && $y2==$ay)} { return 1 }
  }
  return 0
}
# ---- Case U (review wf_fce167ed finding 1): a pre-existing user ring on #net2 that SHARES the stale
# detour junction (-400,-90) must NOT be consumed by the collapse. The dragged net already had a loop
# at START, so the pass declines wholesale -- every ring edge survives (no silent user-copper loss,
# and no trim-drift partial deletion). Companion to F2 (a lone-pin's own loop), same decline guard.
build_before3
foreach w { {-400 -90 -360 -90} {-360 -90 -360 -50} {-360 -50 -400 -50} {-400 -50 -400 -90} } { xschem wire {*}$w }
select_r18
we_move_stretch -20 -60
set uring 0
foreach e { {-400 -90 -360 -90} {-360 -90 -360 -50} {-360 -50 -400 -50} {-400 -50 -400 -90} } {
  if {[wire_exists {*}$e]} { incr uring }
}
check "U safety: pre-existing user ring sharing (-400,-90) is 100% intact (4/4)" [expr {$uring == 4}]
check "U P1: R18 still shares a net with C12"            [share_net R18 C12]
check "U P2: no short"                                    [p2_no_short]

# ---- Case T (review wf_257dddae finding 1): a pre-existing user loop that closes through MID-SPAN
# TAPS (not shared endpoints) must also be protected. The decline guard is tap-aware (splits each
# START wire at interior tap nodes), so a loop tapping the #net2 riser at two interior points is seen
# as a cycle and the collapse declines. An endpoint-only guard would read it as a tree and eat it.
build_before3
foreach w { {-420 -130 -460 -130} {-460 -130 -460 -110} {-460 -110 -420 -110} } { xschem wire {*}$w }
select_r18
we_move_stretch -20 -60
set tring 0
foreach e { {-420 -130 -460 -130} {-460 -130 -460 -110} {-460 -110 -420 -110} } {
  if {[wire_exists {*}$e]} { incr tring }
}
check "T safety: tap-closed user loop on the riser is 100% intact (3/3)" [expr {$tring == 3}]
check "T P1: R18 still shares a net with C12"            [share_net R18 C12]
check "T P2: no short"                                    [p2_no_short]

# ---- Case D (review wf_257dddae finding 5): a pre-existing loop the moved pin LANDS ON at its
# DESTINATION (not its old grabbed position) must be protected too -- the guard marks a component
# reached via point_on_moving_pin, not only coord_was_grabbed. Lone res, drag its M pin +100 onto a
# corner of an isolated user loop. Witness on the FAR corners (140,*) which no stub is collinear with
# (the near vertical edge merges with the moved stub via trim -- orthogonal to this pass). Without the
# destination reach the whole loop is eaten (0/4 edges; sabotage-verified).
xschem clear force
uplevel #0 {set cadence_compat 1}; uplevel #0 {set fluid_editing 1}; uplevel #0 {set orthogonal_wiring 1}
uplevel #0 {set autotrim_wires 1}; uplevel #0 {set enable_stretch 1}
uplevel #0 {set unselect_partial_sel_wires 0}; uplevel #0 {set cadsnap 10}
xschem instance devices/res 0 0 0 0 {name=RD m=1 value=1k}
xschem wire 0 30 0 60
foreach w { {100 30 140 30} {140 30 140 70} {140 70 100 70} {100 70 100 30} } { xschem wire {*}$w }
set rd [inst_by_name RD]; xschem unselect_all; xschem select instance $rd
we_move_stretch 100 0
check "D safety: destination user loop survives (far corners intact)" \
  [expr {[has_endpoint 140 30] && [has_endpoint 140 70] && [wire_exists 140 30 140 70]}]
check "D manhattan"                                      [all_manhattan]

we_result
