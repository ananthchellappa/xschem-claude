# incremental_wire_reroute.md / issue 0015 §7 -- CONNECTED-WIRE SHOVE (drag-toward the occupancy model).
#
# Acceptance fixture: tests/from_user/before_1.sch -> desired_beautified_1.sch. R18 (res) is dragged
# straight DOWN 20. Its bottom pin M (world (-330,-20) -> (-330,0)) is driven ALONG its own vertical
# stub PAST the connected horizontal wire V (N -420 -10 -330 -10) it is attached to at the junction
# J=(-330,-10). R18's body+leads after the move span x=-330, y in [-60,0].
#
# BUG @ HEAD (after_1.sch): place_moved_wire relays the M stub as a REVERSED stub N -330 -10 -330 0
# running back through R18's own body [-60,0] (P5 own-body intrusion). DESIRED (shove): the component
# is solid, so it PUSHES V ahead of it -- V drops below the new pin and the stub becomes a short
# one-grid OUTWARD stub. At cadsnap=10 the shove lands:
#   S (M stub) = (-330,0)-(-330,10)   one cadsnap DOWN from the pin (outward), pin never crosses V
#   V (shoved) = (-420,10)-(-330,10)  connected wire pushed below the pin
#   A (V arm)  = (-420,10)-(-420,140) V's far corner followed the shove (one level, no chain)
# (desired_beautified_1.sch uses a coarser 20 offset by hand; we assert STRUCTURE at cadsnap=10, not
# the literal 20.) The AWAY side (top pin P, net2) must stay a pure stretch -- the shove must not
# over-fire on a drag AWAY from the connected wire.
#
# RED-first @ HEAD (shove not built): the five S/V/A/P5 discriminators FAIL (baseline has the reversed
# stub). GREEN after fluid_shove_connected_wire lands. Driven BOTH one-shot RELEASE and per-snap
# STEPWISE; the committed route must agree (Phase II release==stepwise) and both must shove.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_37_connected_wire_shove.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

# before_1.sch rebuilt in memory with the user's launch gates (cadence_style_rc). cadsnap=10.
proc setup_before1 {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res     -330  -50 0 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140}
    {-550 140 -420 140} {-420 140 -390 140}
    {-420 -90 -330 -90} {-420 -10 -330 -10} {-420 -170 -420 -90}
    {-420 -10 -420 140} {-330 -90 -330 -80} {-330 -20 -330 -10}
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

# The full set of shove-structure + P1/P2/away assertions, applied after a drive.
proc assert_shove {tag before} {
  # --- shove structure at cadsnap=10 (the RED-first discriminators) ---
  check "$tag S: one-cadsnap OUTWARD stub below M (pin never crosses V)" [has_seg -330 0 -330 10]
  check "$tag V: connected wire shoved one grid past the pin"           [has_seg -420 10 -330 10]
  check "$tag A: V's far arm bottom followed the shove (one level)"     [has_seg -420 10 -420 140]
  # --- P5 own-body / occupancy: no reversed stub, old junction vacated ---
  check "$tag P5: NO reversed stub back through R18 body"  [expr {![has_seg -330 -10 -330 0]}]
  check "$tag P5: old junction (-330,-10) fully vacated"   [expr {![has_endpoint -330 -10]}]
  # --- away side (top pin P, net2): pure stretch, unchanged (shove must NOT over-fire) ---
  check "$tag away: P stub STRETCHED not shoved" [has_seg -330 -90 -330 -60]
  check "$tag away: net2 V unchanged"            [has_seg -420 -90 -330 -90]
  check "$tag away: net2 arm unchanged"          [has_seg -420 -170 -420 -90]
  # --- P1 partition preserved (holds both states; guards a future disconnect) ---
  check "$tag P1: R18.M still reaches v8.plus (same net)" [expr {[pinnet R18 M] eq [pinnet v8 plus]}]
  check "$tag P1: R18's two pins stay on DISTINCT nets"   [expr {[pinnet R18 P] ne [pinnet R18 M]}]
  check "$tag P1: no device pin-merge vs before"          [p2_no_device_merge $before]
  # --- P2 no-short + P4 orthogonal ---
  check "$tag P2: no distinct-net wire short" [p2_no_short]
  check "$tag P4: all legs manhattan"         [all_manhattan]
}

# ---- Drive 1: one-shot RELEASE path -------------------------------------------------------------
setup_before1
set before [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
we_move_stretch 0 20
set segRelease [segset]
assert_shove "release:" $before

# ---- Drive 2: STEPWISE path (per-snap move_objects RUBBER; Phase II restore-and-reapply) --------
setup_before1
set before2 [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {0 10   0 20} { xschem move_objects step $sx $sy }
xschem move_objects end 0 20
set segStep [segset]
assert_shove "stepwise:" $before2

# ---- release == stepwise (Phase II invariant, specialised to the shove case) --------------------
check "release == stepwise: R18 committed route identical both ways" [expr {$segStep eq $segRelease}]

we_result
