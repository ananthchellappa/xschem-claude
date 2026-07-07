# incremental_wire_reroute.md §10 item 10 / issue 0081 -- DIAGONAL drag slide/shove decomposition.
#
# Acceptance fixture: tests/from_user/before_1.sch, R18 (res) dragged DIAGONALLY (dx=20, dy=20).
# The bottom pin M is driven DOWN past its connected horizontal wire V (N -420 -10 -330 -10) AND
# right by 20. On a diagonal drag both compute_wire_slide() and fluid_shove_connected_wire() bail
# (move.c: `if(dxnz == dynz) return;`), so at HEAD:
#   - place_moved_wire relays the M stub as a REVERSED stub N -310 -10 -310 0 back through R18's own
#     body (the issue-0015 P5 own-body intrusion), and
#   - V is merely STRETCHED right to (-420,-10)-(-310,-10), never shoved below the pin.
# (Confirmed empirically at HEAD, dx=dy=20.)
#
# DESIRED (issue 0081 §3, X-then-Y total-delta decomposition -- order-independent for this scene
# because the X slide and the Y shove compose the same either way): the X leg SLIDES V right with
# the pin, the Y leg SHOVES V below the new pin. At cadsnap=10 the diagonal shove lands:
#   S (M stub) = (-310,0)-(-310,10)    one cadsnap OUTWARD (down) from the moved pin
#   V (shoved) = (-420,10)-(-310,10)   connected wire pushed below the pin, slid right to x=-310
#   A (V arm)  = (-420,10)-(-420,140)  V's far corner followed
# and NO reversed stub (-310,-10)-(-310,0) through R18's body. The AWAY side (top pin P, net2) is a
# pure diagonal STRETCH at HEAD already and must stay so (the shove must not over-fire).
#
# RED-first @ HEAD (decomposition not built): the S/V/A/P5 discriminators FAIL (baseline has the
# reversed stub + un-shoved V). GREEN after the diagonal decomposition lands. Driven BOTH one-shot
# RELEASE and per-snap STEPWISE; the committed route must agree (Phase II release==stepwise).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_40_diagonal_shove.tcl
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

# The full set of diagonal-shove structure + P1/P2/away assertions, applied after a drive.
proc assert_diag_shove {tag before} {
  # --- shove structure at cadsnap=10 (the RED-first discriminators) ---
  check "$tag S: one-cadsnap OUTWARD stub below moved M (pin never crosses V)" [has_seg -310 0 -310 10]
  check "$tag V: connected wire shoved below the pin + slid right"            [has_seg -420 10 -310 10]
  check "$tag A: V's far arm bottom followed the shove (one level)"           [has_seg -420 10 -420 140]
  # --- P5 own-body / occupancy: no reversed stub back through R18 body ---
  check "$tag P5: NO reversed stub back through R18 body"  [expr {![has_seg -310 -10 -310 0]}]
  check "$tag P5: old junction (-330,-10) fully vacated"   [expr {![has_endpoint -330 -10]}]
  # --- away side (top pin P, net2): pure diagonal stretch, unchanged (shove must NOT over-fire) ---
  check "$tag away: P stub STRETCHED not shoved"   [has_seg -310 -90 -310 -60]
  check "$tag away: net2 V slid right, not shoved" [has_seg -420 -90 -310 -90]
  check "$tag away: net2 arm unchanged"            [has_seg -420 -170 -420 -90]
  # --- P1 partition preserved (holds both states; guards a diagonal disconnect) ---
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
we_move_stretch 20 20
set segRelease [segset]
assert_diag_shove "release:" $before

# ---- Drive 2: STEPWISE path (per-snap move_objects RUBBER; Phase II restore-and-reapply) --------
setup_before1
set before2 [dev_pin_map]
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {10 10   20 20} { xschem move_objects step $sx $sy }
xschem move_objects end 20 20
set segStep [segset]
assert_diag_shove "stepwise:" $before2

# ---- release == stepwise (Phase II invariant, specialised to the diagonal shove case) -----------
check "release == stepwise: R18 committed route identical both ways" [expr {$segStep eq $segRelease}]

# ---- Drive 3: net-label-merge P2 fallback (adversarial review wf_99e41f72 finding) ---------------
# A bare GND lab_pin at (-360,10) sits on the two-leg shoved-V corridor (y=10). WITHOUT a complete P2
# fallback trigger the diagonal decomposition routes R18's net through the GND label -> SILENT MERGE
# (v8.plus becomes GND). fluid_check_device_merge() is blind to it (a label is a single pin, no two-
# pin merge); fluid_partition_changed() catches it (a device pin changed net vs START) and rolls back
# to the proven one-shot pass. Sabotage: narrow the trigger back to fluid_check_device_merge() -> RED.
proc setup_before1_gnd {} {
  setup_before1
  xschem instance devices/lab_pin -360 10 0 0 {name=lg1 lab=GND}
}
setup_before1_gnd
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
we_move_stretch 20 20
set segRelGnd [segset]
check "label-merge: v8.plus NOT merged onto GND (P2 fallback fired)" [expr {[pinnet v8 plus] ne {GND}}]
check "label-merge: R18.M NOT merged onto GND"                       [expr {[pinnet R18 M] ne {GND}}]
check "label-merge: v8 pins stay DISTINCT"                           [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
# stepwise must agree with release (the fallback is a deterministic fn of the total delta)
setup_before1_gnd
set r18 [inst_by_name R18]
xschem unselect_all
xschem select instance $r18
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {10 10   20 20} { xschem move_objects step $sx $sy }
xschem move_objects end 20 20
check "label-merge: release == stepwise" [expr {[segset] eq $segRelGnd}]

we_result
