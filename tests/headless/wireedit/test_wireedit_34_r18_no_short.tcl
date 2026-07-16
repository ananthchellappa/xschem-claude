# incremental_wire_reroute.md Phase III -- OBSTACLE-AWARE STOP-SHORT (lands the R18 no-short).
#
# The headline acceptance fixture (spec §2, §9). Rebuilds tests/from_user/before.sch IN MEMORY
# (robust: a disk fixture can be clobbered by a stray `xschem save` from another process) and
# drives the exact failing move: R18 (res) dragged SE by delta=(+110,+120). before.sch has an
# ammeter v8 (foreign, NOT moved) whose pins straddle the reroute -- plus=(-390,140) on R18.M's
# net, minus=(-330,140) on OUT, body spanning x in [-390,-330] at y=140. R18 lands to the RIGHT of
# v8; the obstacle-blind jog sweeps R18.M's riser leg along y=140 straight through v8, bridging its
# two pins -> v8 shorted -> the two nets merge (P2 violation).
#
# RED-first @ 51ab5298 (ships the short): the P2 checks below FAIL (v8.plus == v8.minus net; a wire
# bridges the pins at y=140). GREEN after Phase III's stop-short reroute. Style is asserted
# route-agnostically (no wire bridges v8's two pins; nothing crosses the body centre) -- NOT pinned
# to beautified.sch's exact coords. Driven BOTH stepwise (per-snap move_objects RUBBER) and via the
# one-shot release path; the two must agree (Phase II release==stepwise) and both must be no-short.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_34_r18_no_short.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

# before.sch rebuilt in memory with the user's launch gates (cadence_style_rc: cadence_compat=1
# forces autotrim_wires=1; fluid_editing=1; orthogonal_wiring=1).
proc setup_r18 {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res     -420 -110 0 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-420 -170 -420 -140} {-550 120 -550 140} {-330 140 -270 140}
    {-550 140 -420 140} {-420 -80 -420 140} {-420 140 -390 140}
  } { xschem wire {*}$w }
}
proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
# resolved net at a named pin of a named instance (refresh the netlist first)
proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap $inst]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}
# is (x,y) on ANY wire segment (endpoint or mid-span)? axis-aligned on-segment test.
proc point_on_any_wire {x y} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 == $x2 && $x == $x1 && $y >= min($y1,$y2) && $y <= max($y1,$y2)} { return 1 }
    if {$y1 == $y2 && $y == $y1 && $x >= min($x1,$x2) && $x <= max($x1,$x2)} { return 1 }
  }
  return 0
}

# The full set of P1/P2/style assertions, applied after a drive (release or stepwise).
proc assert_no_short {tag before} {
  # --- P2 no-short (the RED-first discriminators) ---
  check "$tag P2: v8.plus and v8.minus resolve to DISTINCT nets (ammeter not shorted)" \
    [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
  check "$tag P2: device-pin-merge detector passes (no foreign device merged)" \
    [p2_no_device_merge $before]
  # --- style / geometry: never bridge v8's two pins; approach v8.plus from the clear (left) side ---
  check "$tag style: no wire crosses v8 body centre (-360,140) (leg stops short, never bridges)" \
    [expr {![point_on_any_wire -360 140]}]
  check "$tag style: nothing sits strictly between the pins at (-350,140)" \
    [expr {![point_on_any_wire -350 140]}]
  check "$tag conn: a wire still reaches v8.plus (-390,140)" [point_on_any_wire -390 140]
  # --- P1 connectivity partition preserved (holds in both states; guards a future disconnect) ---
  check "$tag P1: R18.M still reaches v8.plus (same net)" \
    [expr {[pinnet R18 M] eq [pinnet v8 plus]}]
  check "$tag P1: OUT preserved (v8.minus == opin p5)" \
    [expr {[pinnet v8 minus] eq [pinnet p5 p]}]
  check "$tag P1: R18.P still on C12's net (the other follow net intact)" \
    [expr {[pinnet R18 P] eq [pinnet C12 m]}]
  check "$tag P1: R18's two pins stay on DISTINCT nets" \
    [expr {[pinnet R18 P] ne [pinnet R18 M]}]
}

# ---- Drive 1: one-shot RELEASE path -------------------------------------------------------------
setup_r18
set before [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
we_move_stretch 110 120
set segRelease [segset]
assert_no_short "release:" $before

# ---- Drive 2: STEPWISE path (per-snap move_objects RUBBER; Phase II restore-and-reapply) --------
# The interactive drag fires one RUBBER per cadsnap step; each step restores pristine and re-applies
# the CURRENT TOTAL delta, so the committed route must equal the one-shot release AND be no-short.
setup_r18
set before2 [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {20 20   40 40   60 60   80 90   100 110   110 120} {
  xschem move_objects step $sx $sy
}
xschem move_objects end 110 120
set segStep [segset]
assert_no_short "stepwise:" $before2

# ---- release == stepwise (Phase II invariant, specialised to the R18 obstacle case) -------------
check "release == stepwise: R18 committed route identical both ways" [expr {$segStep eq $segRelease}]

we_result
