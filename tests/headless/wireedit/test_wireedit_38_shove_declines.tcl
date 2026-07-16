# issue 0015 §7 -- CONNECTED-WIRE SHOVE: the DECLINE guards (adversarial review wf_44288957 findings).
#
# The shove (test_37) fires only on a CLEAN corner. This locks the guards that make a MESSY topology
# DECLINE to baseline (never worse) instead of shoving into a P1 disconnect / P4 diagonal / P2 short.
# Scenes are the review's decisive fluid-OFF-vs-ON repros; here we assert the CORRECTNESS invariants
# the guard restores (connected, no-short, manhattan) AND a decline marker (the tapped/loaded junction
# is not shoved away). Each was sabotage-checked: neutering the matching guard turns its case RED.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_38_shove_declines.tcl
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

# ---- Case A: MID-SPAN TAP on V (P1 disconnect + P4 diagonal guards; clean-span guard) ------------
# before_1-style scene + a wire tapping V's interior at (-380,-10), landing on FIXED device RTAP.M.
# A naive wholesale translate of V strands the tap (autotrim=0 -> RTAP.M torn off) or bends V's split
# half into a diagonal (autotrim=1). Guard = V's span must be clean -> DECLINE -> baseline.
proc case_A {trim tag} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 [list set autotrim_wires $trim]
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/res -330  -50 0 1 {name=R18 m=1 value=200}    ;# M pin (-330,-20)
  xschem instance devices/res -380 -100 0 0 {name=RTAP m=1 value=100}   ;# M pin (-380,-70)
  xschem wire -420 -10 -330 -10   ;# V (tap lands mid-span at -380,-10)
  xschem wire -420 -10 -420 140   ;# arm (V far corner C=(-420,-10))
  xschem wire -330 -20 -330 -10   ;# S (R18.M stub)
  xschem wire -380 -10 -380 -70   ;# TAP -> RTAP.M
  set before [dev_pin_map]
  set r18 [inst_by_name R18]
  xschem unselect_all
  xschem select instance $r18
  we_move_stretch 0 20
  check "A/$tag P1: mid-span tap RTAP.M still on R18.M net (not stranded)" [expr {[pinnet RTAP M] eq [pinnet R18 M] && [pinnet R18 M] ne {}}]
  check "A/$tag P4: no diagonal wire injected (V not bent)"                [all_manhattan]
  check "A/$tag P2: no short"                                              [p2_no_short]
  check "A/$tag P1: no device pin-merge"                                  [p2_no_device_merge $before]
  check "A/$tag decline: tap junction (-380,-10) preserved -> baseline"    [has_endpoint -380 -10]
}
case_A 0 notrim
case_A 1 trim

# ---- Case B: foreign-net WIRE across V's shove landing (P2 wire-level guard) ---------------------
# R18.M drives DOWN; the shove would push V down onto a DISTINCT-net (FOO) wire -> silent merge. The
# pin-only P2 guard misses wires; fluid_seg_hits_foreign_wire declines -> no short.
proc case_B {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/res 0 0 0 0 {name=R1 m=1 value=1k}          ;# M at (0,30)
  xschem wire 0 30 0 50   ;# S
  xschem wire 0 50 90 50  ;# V (net of R1.M)
  # foreign net FOO crossing the shove landing row y=70 at x=50
  xschem instance {lab_pin.sym} 50 100 0 0 {name=lf lab=FOO}
  xschem wire 50 60 50 100
  set before [dev_pin_map]
  set r1 [inst_by_name R1]
  xschem unselect_all
  xschem select instance $r1
  we_move_stretch 0 30                                                ;# M -> (0,60), J=50, shove target y=70
  check "B P2: no distinct-net short (V not shoved onto FOO wire)" [p2_no_short]
  check "B P2: R1.M net stays distinct from FOO"                  [expr {[pinnet R1 M] ne {FOO}}]
  check "B P4: all manhattan"                                     [all_manhattan]
  check "B decline: V NOT shoved onto y=70 (still touches J=(0,50))" [has_endpoint 0 50]
}
case_B

we_result
