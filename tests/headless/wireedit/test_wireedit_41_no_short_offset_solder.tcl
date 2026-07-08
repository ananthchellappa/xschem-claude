# issue 0083 -- fluid follow-set: a NO-SHORT landing onto a foreign device pin must keep the offset
# solder-joint and stay clear of the device body (incremental_wire_reroute.md §6 stop-short/solder).
#
# Rebuilds tests/from_user/before_3.sch IN MEMORY (robust vs a stray `xschem save`) and drives the
# exact failing move: R18 (res) nudged +10 in X only (a small PURE-AXIS move; NOT diagonal, NOT a
# short). before_3 has an ammeter v8 (foreign, NOT moved): plus=(-390,140) on R18.M's net #net1,
# minus=(-330,140) on OUT, graphic body bbox x in [-390,-330]. In before_3 the #net1 riser drops at
# x=-400 (one grid clear of v8's left edge) to a VISIBLE solder-dot T at (-400,140), then a short
# stub -400..-390 reaches v8.plus.
#
# BUG (baseline): the base stretch-follow TRANSLATES the whole riser +10 (compute_wire_slide promotes
# the vertical + drags its bottom corner) and trim_wires merges the two y=140 horizontals -> the riser
# lands FLUSH on v8's left edge at x=-390 and the solder dot COLLAPSES onto v8.plus (a junction AT the
# pin = invisible/ambiguous). No short (the horizontal stops at plus=-390, never reaches minus=-330),
# so the netlist is correct -- this is a FEEL bug. The obstacle Layers 1-3 correctly decline (they
# need a two-distinct-net STRADDLE; only one v8 pin is contacted here), so nothing restores the offset.
#
# RED-first @ baseline: the "solder dot at (-400,140)" + "riser clear of the body column x=-390"
# discriminators FAIL (riser at -390, no junction at -400). GREEN after the no-short offset pass.
# P1/P2 are guard-RAILS (green both ways -- this is not a short), NOT the discriminators. Driven BOTH
# release and stepwise; the two must agree (Phase II release==stepwise).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_41_no_short_offset_solder.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

# before_3.sch rebuilt in memory with the user's launch gates (cadence_style_rc).
proc setup_r18_3 {} {
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
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140}
    {-400 -10 -400 140} {-420 -90 -400 -90} {-550 140 -400 140}
    {-400 140 -390 140} {-420 -170 -420 -90} {-400 -90 -400 -70}
  } { xschem wire {*}$w }
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
# is (x,y) on ANY wire segment (endpoint or mid-span)?  axis-aligned on-segment test.
proc point_on_any_wire {x y} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 == $x2 && $x == $x1 && $y >= min($y1,$y2) && $y <= max($y1,$y2)} { return 1 }
    if {$y1 == $y2 && $y == $y1 && $x >= min($x1,$x2) && $x <= max($x1,$x2)} { return 1 }
  }
  return 0
}
# connection degree at (x,y): number of wire ENDPOINTS coincident there (a degree>=3 vertex is a
# visible solder-dot T; a degree-2 vertex is a plain corner/collinear join, no dot).
proc wire_degree {x y} {
  set d 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 == $x && $y1 == $y} { incr d }
    if {$x2 == $x && $y2 == $y} { incr d }
  }
  return $d
}

# The acceptance assertions, applied after a drive (release or stepwise). The DESIRED result is the
# SAME canonical geometry for every rightward delta (+10/+20/+30): riser lands at the -400 column with
# the solder dot; only R18.M's x differs (absorbed by the V-H-V jog). So one assert fits all drives.
proc assert_offset_solder {tag before} {
  # --- DISCRIMINATORS (RED @ baseline): the offset solder-joint is kept, riser clears the body ---
  check "$tag DISC solder-dot restored: visible T-junction at pre-move column (-400,140), degree>=3" \
    [expr {[wire_degree -400 140] >= 3}]
  # riser must clear v8's body interior at EVERY naive landing column (-390/-380/-370 = +10/+20/+30)
  foreach bx {-390 -380 -370 -360} {
    check "$tag DISC riser clears v8 body: no wire in body interior at ($bx,120)" \
      [expr {![point_on_any_wire $bx 120]}]
  }
  check "$tag DISC short stub kept: wire -400 140 -390 140 reaches v8.plus from the offset dot" \
    [has_seg -400 140 -390 140]
  # --- connectivity that MUST still hold (reach the pin) ---
  check "$tag conn: a wire still reaches v8.plus (-390,140)" [point_on_any_wire -390 140]
  # --- P1/P2 guard-RAILS (green both ways; this is a feel bug, not a short) ---
  check "$tag P2: v8.plus and v8.minus resolve to DISTINCT nets (ammeter not shorted)" \
    [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
  check "$tag P2: device-pin-merge detector passes (no foreign device merged)" \
    [p2_no_device_merge $before]
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
setup_r18_3
set before [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
we_move_stretch 10 0
set segRelease [segset]
assert_offset_solder "release:" $before

# ---- Drive 2: STEPWISE path (per-snap move_objects RUBBER; Phase II restore-and-reapply) --------
setup_r18_3
set before2 [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
xschem move_objects start 0 0 kissing stretch
xschem move_objects step 10 0
xschem move_objects end 10 0
set segStep [segset]
assert_offset_solder "stepwise:" $before2

# ---- release == stepwise (Phase II invariant) ---------------------------------------------------
check "release == stepwise: R18 committed route identical both ways" [expr {$segStep eq $segRelease}]

# ---- Drive 3: +20 (the user's continuous drag: +10 then +10 more -> riser lands INSIDE the ammeter
#      body, corner NOT on a pin). Broadened trigger must still rebuild to the SAME -400 solder-dot. --
setup_r18_3
set before3 [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
we_move_stretch 20 0
set seg20rel [segset]
assert_offset_solder "release+20:" $before3

# +20 STEPWISE = the true mid-drag (one grid, then another), must equal the +20 release (release==stepwise)
setup_r18_3
set before3b [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
xschem move_objects start 0 0 kissing stretch
xschem move_objects step 10 0
xschem move_objects step 20 0
xschem move_objects end 20 0
set seg20step [segset]
assert_offset_solder "stepwise+20:" $before3b
check "release == stepwise (+20): mid-drag route == one-shot" [expr {$seg20step eq $seg20rel}]

# ---- Drive 4: +30 (three grids in) -- still the canonical -400 solder-dot ------------------------
setup_r18_3
set before4 [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
we_move_stretch 30 0
assert_offset_solder "release+30:" $before4

we_result
