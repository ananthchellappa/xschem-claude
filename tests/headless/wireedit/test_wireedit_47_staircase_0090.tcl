# issue 0090 -- REDUNDANT SAME-NET MONOTONE STAIRCASE left by a MULTI-GESTURE fluid drag.
#
# Sibling of 0089 (test_wireedit_46). 0089 straightens a same-side REVERSAL (U-turn); this handles the
# opposite-side MONOTONE STAIRCASE. When a fluid stretch is performed as SEVERAL successive gestures
# (mouse down/drag/up, repeated), each gesture re-derives its follow set from the PREVIOUS gesture's
# committed geometry (its pristine). A mid-drag corner-slide that would flatten the jog is correctly
# DECLINED per gesture (a co-moving foreign-net pin's future corridor would cross the slid copper = a
# transient short), but across gestures the jogs pile into a monotone staircase. A SINGLE-gesture
# equivalent move routes cleanly, so the staircase is purely a multi-gesture composition artifact. It is
# same-net (no short, no disconnect) -- a pure bend-count / legibility (P6) defect.
#
# Repro (mirrors the user's tests/from_user/before_3.sch -> after_10.sch): R18 dragged to (-150,-10)
# in TWO gestures, (150,-90) then (100,120).
#   RED  (opposite-side collapse compiled out): R18.M's #net1 riser is a V-H-V-H-V staircase that steps
#        out to an intermediate column x=-250 and keeps going: (-400,140)v(-400,50)h(-250,50)v(-250,30)
#        h(-150,30)v M. Endpoints at x=-250.
#   GREEN (fix on): the staircase collapses to the clean 3-seg L the single-gesture move produces:
#        riser (-400,30)-(-400,140) / cross (-400,30)-(-150,30) / M stub (-150,20)-(-150,30). No x=-250.
#
# fluid_straighten_reversals() now collapses BOTH shapes: a reversal (neighbours same side) slides to
# the nearer neighbour and only shortens; a staircase (neighbours opposite side) EXTENDS the far
# neighbour, so it also body-cross-guards the reshaped legs and, when the nearer target would drive the
# riser through the moving device's own body, falls back to the farther target (merge into the riser +
# pass-2 tail retract). Partition-verified + novelty-scoped, exactly like 0089.
#
# The scripted gesture path (per gesture: select + move_objects stretch kissing) mirrors the interactive
# repeated drag, so this runs TRUE HEADLESS via --nogui.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_47_staircase_0090.tcl
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
proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap [inst_by_name $inst]]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}
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
# is there any #net1 wire endpoint strictly at column x (the staircase jog signature)?
proc net_endpoint_at_col {want x} {
  xschem resolved_net 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    if {[xschem getprop wire $i lab] ne $want} continue
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1==$x || $x2==$x} { return 1 }
  }
  return 0
}

# ---- Case R: the repro. R18 to (-150,-10) in TWO gestures -> the M-riser staircase must collapse. ----
build_before3
select_r18 ; we_move_stretch 150 -90       ;# gesture 1
select_r18 ; we_move_stretch 100 120        ;# gesture 2 (total -> R18 @ (-150,-10), == after_10.sch)

# the intermediate jog column x=-250 (RED staircase left an endpoint there) is GONE
check "R no x=-250 jog: no #net1 endpoint at column -250" [expr {![net_endpoint_at_col "#net1" -250]}]
# the clean L the single-gesture move produces is present
check "R L-cross:  (-400,30)-(-150,30)"          [wire_exists -400 30 -150 30]
check "R L-riser:  (-400,30)-(-400,140)"         [wire_exists -400 30 -400 140]
check "R M-stub:   (-150,20)-(-150,30)"          [wire_exists -150 20 -150 30]
# safety rails
check "R P1: R18 still shares a net with the rail (via v8)" [share_net R18 v8]
check "R P1: R18 still shares a net with C12"     [share_net R18 C12]
check "R no self-short: R18.P net != R18.M net"   [expr {[pinnet R18 P] ne [pinnet R18 M] && [pinnet R18 P] ne {}}]
check "R P2: no short (nets not merged)"         [p2_no_short]
check "R P4: every leg axis-aligned"             [p4_orthogonal]

# ---- Case R2: a DIFFERENT gesture split reaching the same endpoint collapses identically. -----------
build_before3
select_r18 ; we_move_stretch 70 -90
select_r18 ; we_move_stretch 80 0
select_r18 ; we_move_stretch 100 120
check "R2 no x=-250 jog"                          [expr {![net_endpoint_at_col "#net1" -250]}]
check "R2 P2: no short"                           [p2_no_short]
check "R2 P4: manhattan"                          [p4_orthogonal]

# ---- Case S (scope): a SINGLE-gesture move is already clean and must stay byte-clean (no regress). ---
build_before3
select_r18 ; we_move_stretch 250 30
check "S single-gesture clean L-cross (-400,30)-(-150,30)" [wire_exists -400 30 -150 30]
check "S single-gesture no x=-250 jog"            [expr {![net_endpoint_at_col "#net1" -250]}]
check "S P2: no short"                            [p2_no_short]

# ---- Case N: a small non-staircasing stretch must not be over-reshaped (strict scope). --------------
build_before3
select_r18 ; we_move_stretch 0 -20
check "N P1: R18 still shares a net with C12"     [share_net R18 C12]
check "N P2: no short"                            [p2_no_short]
check "N manhattan"                               [all_manhattan]

we_result
