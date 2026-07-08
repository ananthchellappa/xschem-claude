# issue 0083 far-pin landing -- NEVER-WORSE regression rails from adversarial review wf_dfd3e463.
#
# The far-pin broadening (test_41 drives 6-9) makes fluid_offset_foreign_pin_landing FIRE when the
# dragged riser corner lands on/past a foreign device pin, repairing the naive short. The review found
# three P1-disconnect holes in the first cut (commit 6bb9eaa4), all requiring autotrim_wires=0 (the
# STOCK default -- the cadence rc's autotrim=1 pre-splits buses at taps/pins so classification
# declines) or an off-grid pin:
#   T1 tolerance-band c_on_foreign: an OFF-GRID foreign pin NEAR (not at) the corner exempted an
#      unrelated stationary wire ending exactly at C -> the rebuild vacated C -> disconnect.
#   T2 removed-span tap: the rebuild deletes the naive (P..C] row copper; a stationary tap wire
#      ending strictly inside was stranded (pristine in-body arm, corner ON the far pin).
#   T3 removed-span mid-fed pin: a SECOND stationary device's same-net pin fed MID-SPAN by the bus
#      sat inside the removed span -> stranded.
#   T4 stationary-wS mutation: an unselected user wire spanning [P..C] was accepted as the overshoot
#      and silently reshaped to [C'..P].
# Each fires at 6bb9eaa4 (RED: the pass makes the result WORSE than the naive baseline) and DECLINES
# after the hardening (exact-match fluid_point_on_foreign_fixed_pin, stationary-wires-never-wB/wS,
# fluid_removed_span_unsafe). Decline == naive here, so the asserts check CONNECTIVITY equals the
# naive outcome, not route beauty (some naive outcomes short v8 -- that is the accepted baseline;
# never-worse only forbids the PASS from adding damage).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_42_farpin_never_worse.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc gates0 {} {
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 0}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
}
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
# net of the wire covering point (x,y) (endpoint or mid-span), {} if none
proc net_of_wire_at {x y} {
  xschem resolved_net 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    set on 0
    if {$x1 == $x2 && $x == $x1 && $y >= min($y1,$y2) && $y <= max($y1,$y2)} { set on 1 }
    if {$y1 == $y2 && $y == $y1 && $x >= min($x1,$x2) && $x <= max($x1,$x2)} { set on 1 }
    if {$on} { return [xschem getprop wire $i lab] }
  }
  return {}
}

# ---- T1: tolerance-band c_on_foreign (off-grid foreign pin NEAR the corner) ----------------------
# r18_3 scene + a pristinely-DANGLING stationary wire W3 ending at (-340,140) + a floating off-grid
# opin pF lab=FOO at (-343,143) that touches NOTHING. Drag R18 +60: the corner lands exactly on W3's
# endpoint (10 short of v8.minus -- naive makes NO short, it just solders W3 onto #net1). The pass
# must DECLINE (no pin exactly at C): firing would vacate C and leave W3 dangling again while naive
# keeps it soldered.
xschem clear force
gates0
xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
xschem instance devices/res     -400  -40 0 1 {name=R18 m=1 value=200}
xschem instance devices/ammeter -360  140 3 0 {name=v8}
xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
xschem instance devices/opin    -343  143 0 0 {name=pF lab=FOO}
foreach w {
  {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140}
  {-400 -10 -400 140} {-420 -90 -400 -90} {-550 140 -400 140}
  {-400 140 -390 140} {-420 -170 -420 -90} {-400 -90 -400 -70}
  {-340 140 -340 180}
} { xschem wire {*}$w }
xschem unselect_all
xschem select instance [inst_by_name R18]
we_move_stretch 60 0
check "T1: W3 soldered to R18.M's net (naive outcome kept; no vacate-C disconnect)" \
  [expr {[net_of_wire_at -340 180] ne {} && [net_of_wire_at -340 180] eq [pinnet R18 M]}]
check "T1: v8 not shorted (corner never reached minus)" \
  [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]

# ---- T2: removed-span tap (corner ON the far pin, pristine in-body arm carries a tap) -------------
# Pristine bus runs INTO v8's body to a corner at -340 (legal copper, autotrim off keeps it one
# wire); a stationary tap {-350 140 -350 200} feeds R2. Drag R1 +10: corner lands exactly ON
# v8.minus; the tap endpoint (-350) sits strictly inside the removed span (-390..-330]. The pass
# must DECLINE: firing would strand R2. (Naive shorts v8 -- the accepted baseline; the rail is
# ONLY that R2 stays on R1.M's net exactly as naive keeps it.)
xschem clear force
gates0
xschem instance devices/lab_pin -550  140 0 0 {name=lA lab=NETA}
xschem instance devices/res     -340  -40 0 1 {name=R1 m=1 value=100}
xschem instance devices/ammeter -360  140 3 0 {name=v8}
xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
xschem instance devices/res     -350  230 0 0 {name=R2 m=1 value=100}
foreach w {
  {-550 140 -340 140} {-340 -10 -340 140} {-330 140 -270 140}
  {-350 140 -350 200}
} { xschem wire {*}$w }
xschem unselect_all
xschem select instance [inst_by_name R1]
we_move_stretch 10 0
check "T2: R2 still on R1.M's net (no removed-span strand)" \
  [expr {[pinnet R2 P] eq [pinnet R1 M]}]

# ---- T3: removed-span mid-fed pin (second device's same-net pin inside the span) -----------------
# One bus feeds Q1.B and Q2.B MID-SPAN (autotrim off: single wire, no splits). Drag R1 +20: the
# corner passes Q1; the candidate rebuild's removed span (-390..-240] contains Q2.B at -300 on the
# SAME net. The pass must DECLINE: firing would cut Q2 off.
xschem clear force
gates0
xschem instance devices/lab_pin -550  140 0 0 {name=lA lab=NETA}
xschem instance devices/npn     -370  140 0 0 {name=Q1}
xschem instance devices/npn     -280  140 0 0 {name=Q2}
xschem instance devices/res     -260  -40 0 1 {name=R1 m=1 value=100}
foreach w {
  {-550 140 -260 140} {-260 -10 -260 140}
} { xschem wire {*}$w }
xschem unselect_all
xschem select instance [inst_by_name R1]
we_move_stretch 20 0
check "T3: Q2.B still on R1.M's net (mid-span-fed pin not stranded)" \
  [expr {[pinnet Q2 B] eq [pinnet R1 M]}]
check "T3: Q1.B still on R1.M's net" \
  [expr {[pinnet Q1 B] eq [pinnet R1 M]}]

# ---- T4: a stationary duplicate of the overshoot declines by AMBIGUITY (two [P..C] candidates) ----
# A stationary user wire spans plus..(-360) INTO the body. Drag R18 +40: the corner lands exactly on
# its far endpoint AND the relaid tool overshoot occupies the same [P..C] span -- two overshoot
# candidates -> stranded -> decline. Copper connectivity must equal the naive outcome (the corner
# solders at -360 on plus's net; trim may merge the collinear records, so assert NETS, not segs).
xschem clear force
gates0
xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
xschem instance devices/res     -400  -40 0 1 {name=R18 m=1 value=200}
xschem instance devices/ammeter -360  140 3 0 {name=v8}
xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
foreach w {
  {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140}
  {-400 -10 -400 140} {-420 -90 -400 -90} {-550 140 -400 140}
  {-400 140 -390 140} {-420 -170 -420 -90} {-400 -90 -400 -70}
  {-390 140 -360 140}
} { xschem wire {*}$w }
xschem unselect_all
xschem select instance [inst_by_name R18]
we_move_stretch 40 0
check "T4: copper still reaches -360 on plus's net (in-body wire not stranded/mutated away)" \
  [expr {[net_of_wire_at -360 140] ne {} && [net_of_wire_at -360 140] eq [pinnet v8 plus]}]
check "T4: v8 not shorted" [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]

# ---- and the REPAIR must still fire where it is safe: exact r18_3 far-pin drive under autotrim=0 --
# (The clean scene has nothing inside the removed span except v8.minus's own OUT attachment.)
xschem clear force
gates0
xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
xschem instance devices/res     -400  -40 0 1 {name=R18 m=1 value=200}
xschem instance devices/ammeter -360  140 3 0 {name=v8}
xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
foreach w {
  {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140}
  {-400 -10 -400 140} {-420 -90 -400 -90} {-550 140 -400 140}
  {-400 140 -390 140} {-420 -170 -420 -90} {-400 -90 -400 -70}
} { xschem wire {*}$w }
xschem unselect_all
xschem select instance [inst_by_name R18]
we_move_stretch 70 0
check "repair rail: +70 far-pin landing still FIRES under autotrim=0 (v8 not shorted)" \
  [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
check "repair rail: solder stub -400..-390 restored" [has_seg -400 140 -390 140]

we_result
