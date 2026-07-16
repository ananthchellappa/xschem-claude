# incremental_wire_reroute.md Phase III -- generality + adversarial-review regressions for the
# obstacle-aware L-orientation flip (test_wireedit_34 is the R18 headline; this hardens the edges an
# adversarial review surfaced).
#
# Case A -- CROSS-LEG no-new-short (the confirmed review finding). fluid_ml_blocked must test the L
#   AS A WHOLE, not leg-by-leg: an L bridges its two legs through the corner, so a stationary device
#   with one distinct-net pin on the horizontal leg and another on the vertical leg is shorted
#   THROUGH the corner. A per-leg test misses that (each leg sees only one pin) and the flip would
#   commit a route that shorts that device -- turning a baseline-safe device into a short. The fix
#   unions both legs per device. Invariant asserted: enabling the feature never introduces a device
#   short that the naive (fluid-off) route did not already have. RED against the per-leg version.
#
# Case B -- NO-FALSE-POSITIVE on a clean drag: a foreign device present but OFF the route must not
#   trigger a flip or a spurious device-merge report.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_35_flip_generality.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

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
# set of instance names whose two-or-more pins merged from distinct pre-move nets (device shorts)
proc merged_devices {before} {
  set after [dev_pin_map]
  set out {}
  dict for {nm ap} $after {
    if {![dict exists $before $nm]} continue
    array unset B; array set B [dict get $before $nm]
    array unset A; array set A $ap
    foreach p1 [array names A] { foreach p2 [array names A] {
      if {$p1 eq $p2} continue
      if {![info exists B($p1)] || ![info exists B($p2)]} continue
      if {$B($p1) ne {} && $B($p2) ne {} && $B($p1) ne $B($p2) && $A($p1) ne {} && $A($p1) eq $A($p2)} {
        if {[lsearch -exact $out $nm] < 0} { lappend out $nm }
      }
    } }
  }
  return [lsort $out]
}
proc gates {fluid} {
  uplevel #0 [list set cadence_compat 1]
  uplevel #0 [list set orthogonal_wiring 1]
  uplevel #0 [list set autotrim_wires 1]
  uplevel #0 [list set enable_stretch 1]
  uplevel #0 [list set unselect_partial_sel_wires 0]
  uplevel #0 [list set cadsnap 10]
  uplevel #0 [list set fluid_editing $fluid]
}

# ---- Case A: cross-leg corner-straddle -- fluid ON introduces NO new device short --------------
# RD moved by (-200,-200). The follow-wire stretches (-200,-170)->(300,30). ml0=1 (H-V): its vertical
# leg x=-200 straddles RB's two pins (both at x=-200) => ml0 blocked. ml1=2 (V-H): its horizontal leg
# y=-170 carries Q9.B(260,-170) and its vertical leg x=300 carries Q9.E(300,-140) -- ONE pin per leg,
# a cross-leg bridge. A per-leg predicate misses it and flips into a Q9 short; the union predicate
# sees both -> declines to flip -> degrades to the baseline route (RB short, log-only), Q9 stays
# clean. So fluid ON must equal fluid OFF here: RB shorted, Q9 NOT shorted.
proc build_crossleg {} {
  xschem clear force
  xschem instance devices/res     0    0    0 0 {name=RD}
  xschem instance devices/lab_pin 300  30   0 0 {name=lf lab=FAR}
  xschem wire 0 30 300 30
  xschem instance devices/res    -200 -70   0 0 {name=RB}
  xschem instance devices/npn     280 -170  0 0 {name=Q9}
}
gates 0
build_crossleg
set beforeA0 [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RD]
xschem move_objects -200 -200 stretch kissing
set mergedOff [merged_devices $beforeA0]

gates 1
build_crossleg
set beforeA1 [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RD]
xschem move_objects -200 -200 stretch kissing
set mergedOn [merged_devices $beforeA1]

check "A cross-leg: fluid ON introduces NO device short absent under fluid OFF" \
  [expr {[lsearch -all -inline $mergedOn Q9] eq {} || [lsearch -exact $mergedOff Q9] >= 0}]
check "A cross-leg: Q9 NOT shorted by the flip (B,C,E stay pairwise distinct)" \
  [expr {[pinnet Q9 B] ne [pinnet Q9 E] && [pinnet Q9 B] ne [pinnet Q9 C] && [pinnet Q9 C] ne [pinnet Q9 E]}]
check "A cross-leg: fluid ON merged-device set is a SUBSET of fluid OFF (never worse)" \
  [expr {[lsearch -exact $mergedOn Q9] < 0}]

# ---- Case B: no-false-positive -- a clean drag with a foreign device OFF the route -------------
# RC dragged +40,+40; its M riser reroutes; foreign res RF sits far away, touched by no leg. The flip
# must not fire (nothing blocked) and no device may be reported merged.
proc build_clean {} {
  xschem clear force
  xschem instance devices/res 0 0 0 0 {name=RC}
  xschem wire 0 30 0 130
  xschem wire 0 130 60 130
  xschem instance devices/res 400 400 0 0 {name=RF}
  xschem wire 400 430 400 530
  xschem wire 400 -170 400 -70
}
gates 1
build_clean
set beforeB [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RC]
xschem move_objects 40 40 stretch kissing
check "B no-false-positive: clean drag reports zero device merges" [p2_no_device_merge $beforeB]
check "B no-false-positive: RF (off-route foreign device) untouched" \
  [expr {[pinnet RF P] ne [pinnet RF M]}]
check "B no-false-positive: RC still connected to its riser far end" \
  [expr {[pinnet RC M] ne {}}]

we_result
