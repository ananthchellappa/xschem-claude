# issue 0092 -- ALONG-AXIS wire-drag OVERSHOOT stub collapse (doc/claude/issues/0092-*.md).
#
# Grab a same-net HORIZONTAL rung and drag it ALONG ITS OWN AXIS (plus a clean perpendicular
# component). The along-axis part overshoots the rung's junction: place_moved_wire relays it as a short
# DANGLING stub collinear with the rung + a solder dot, while the perpendicular riser meeting the
# junction stays put. fluid_collapse_axis_overshoot_stub() SHOVES the riser column to the stub tip (the
# user's preferred route) -- or TRIMS the stub when the riser is pin-anchored.
#
# Headless: the scripted stretch move (we_move_stretch = move_objects ... stretch kissing) is byte-
# identical to the interactive release (Phase II); the X-gesture repro is before_6.sch -> after_12.sch
# (bad) / preferred_12.sch (wanted), grab (-460,50) drag (-20,+10).
#
# RED-first (pass compiled out / gate false): case L leaves the stub (-490,60)-(-470,60) + the riser
# stuck at x=-470 (tests/from_user/after_12.sch). GREEN: the riser + its top-rail junction shove to
# x=-490 and the rung is a single wire (-490,60)-(-360,60) (tests/from_user/preferred_12.sch).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_49_axis_overshoot_0092.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

# select the (only) wire whose endpoints are exactly (ax,ay)-(bx,by), either order
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
# touch-degree of (x,y): number of wires whose SPAN covers it (endpoint or mid-span)
proc deg_at {x y} {
  set nw [xschem get wires]; set c 0
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1==$x2} {                                   ;# vertical
      if {$x==$x1 && $y >= [expr {min($y1,$y2)}] && $y <= [expr {max($y1,$y2)}]} { incr c }
    } elseif {$y1==$y2} {                             ;# horizontal
      if {$y==$y1 && $x >= [expr {min($x1,$x2)}] && $x <= [expr {max($x1,$x2)}]} { incr c }
    }
  }
  return $c
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
proc share_net {a b} {
  foreach na [inst_nets $a] { foreach nb [inst_nets $b] { if {$na eq $nb} { return 1 } } }
  return 0
}
# resolved net carried by the wire with these exact endpoints (either order), or "" if none
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
# P1 witness: the far top-rail wire (ax,ay)-(bx,by) still carries R18's M-pin net -- i.e. the #net1
# staircase is intact end-to-end from R18.M up to the top rail (R18.P is #net2, the OUT/opin side is a
# DISTINCT net beyond the ammeter, so a plain R18<->p5 share is deliberately NOT a connectivity test).
proc r18_reaches {ax ay bx by} {
  set wn [net_of_wire $ax $ay $bx $by]
  return [expr {$wn ne "" && [lsearch -exact [inst_nets R18] $wn] >= 0}]
}

# --- fixture: before_6.sch's R18.M staircase on #net1 ---------------------------------------------
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

# ================= Case L: LEFT drag -> SHOVE the riser column to preferred_12.sch =================
build_before6
check "L pre: middle rung selected" [expr {[sel_wire -470 50 -360 50] >= 0}]
we_move_stretch -20 10

check "L no stub: dangling overshoot (-490,60)-(-470,60) is GONE" \
  [expr {![wire_exists -490 60 -470 60]}]
check "L no solder-dot at (-470,60): degree<=1 (rung passes mid-span, no T)" \
  [expr {[deg_at -470 60] <= 1}]
check "L rung is a SINGLE wire (-490,60)-(-360,60)" [wire_exists -490 60 -360 60]
check "L riser SHOVED to x=-490: (-490,60)-(-490,140)" [wire_exists -490 60 -490 140]
check "L top-rail junction SHOVED to -490: (-550,140)-(-490,140)" [wire_exists -550 140 -490 140]
check "L top-rail right leg (-490,140)-(-390,140)" [wire_exists -490 140 -390 140]
check "L pin riser intact (-360,20)-(-360,60)" [wire_exists -360 20 -360 60]
check "L manhattan"                             [all_manhattan]
check "L P1: #net1 staircase intact to top rail (-550,140)-(-490,140)" [r18_reaches -550 140 -490 140]
check "L P2: no short (nets not merged)"        [p2_no_short]

# ================= Case R: RIGHT drag past the PIN column -> TRIM the dangling stub ================
# The rung's right junction sits on the PIN riser V_R (far end = R18.M, a fixed pin): the riser cannot
# shove, so the overshoot stub (-360,60)-(-340,60) is simply trimmed; the rung stays (-470,60)-(-360,60).
build_before6
check "R pre: middle rung selected" [expr {[sel_wire -470 50 -360 50] >= 0}]
we_move_stretch 20 10
check "R no stub past pin: (-360,60)-(-340,60) is GONE" [expr {![wire_exists -360 60 -340 60]}]
check "R no dangling tip at (-340,60)"                  [expr {![has_endpoint -340 60]}]
check "R rung stays (-470,60)-(-360,60)"                [wire_exists -470 60 -360 60]
check "R riser left leg intact (-470,60)-(-470,140)"    [wire_exists -470 60 -470 140]
check "R pin riser intact (-360,20)-(-360,60)"          [wire_exists -360 20 -360 60]
check "R manhattan"                                     [all_manhattan]
check "R P1: #net1 staircase intact to top rail (-550,140)-(-470,140)" [r18_reaches -550 140 -470 140]
check "R P2: no short"                                  [p2_no_short]

# ================= Case N: a PURE perpendicular drag has NO overshoot -> strict no-op ==============
# Dragging the rung straight up leaves a clean stretch (no along-axis component, no stub); the pass
# must not invent one. Witness: exactly the 3-segment staircase, riser still at its ORIGINAL column.
build_before6
sel_wire -470 50 -360 50
we_move_stretch 0 10
check "N clean stretch: rung (-470,60)-(-360,60)"       [wire_exists -470 60 -360 60]
check "N riser unchanged column (-470,60)-(-470,140)"   [wire_exists -470 60 -470 140]
check "N top-rail junction UNMOVED at -470"             [wire_exists -550 140 -470 140]
check "N no phantom stub at x=-490"                     [expr {![has_endpoint -490 60]}]
check "N manhattan"                                     [all_manhattan]
check "N P1: #net1 staircase intact to top rail (-550,140)-(-470,140)" [r18_reaches -550 140 -470 140]

we_result
