# Hardening sprint Track B / step B2 -- MIXED-SELECTION rot-free P2 safety net (WIRING.md risk #2,
# issue 0093-D2). RED-first.
#
# The three leg_snap arms in move_objects END all required fluid_startsel_wires==0 (a TOOL-OWNED
# follow set). A drag whose selection ALSO contains a wire of the user's own (fluid_startsel_wires>0)
# fell through to `if(!leg_snapped) break;` and committed sight-unseen -- no attempt ladder, no P2
# verify. Because the push-through slide (the 0109 collinear-plow fix) is ITSELF gated
# startsel==0 (compute_wire_slide), a mixed selection re-exposes the pre-0109 plow with zero safety.
#
# Repro (before_8 == tests/from_user/before_8.sch, rebuilt in memory for robustness): drag R18
# (res, pins P #net3 / M #net1, both follow anchors on the y=0 row) DIAGONALLY by (-110,-80), with
# the selection made MIXED by also grabbing a DECOY wire far in the corner -- its only role is to
# set fluid_startsel_wires>0 (a real user box-drag catching R18 plus any of her own wire produces
# the identical gate state; the decoy just isolates the variable with zero routing side-effects).
#
#   RED  (pre-B2, unarmed mixed): the follow stubs plow -> R18.P and R18.M merge -> device short
#        committed sight-unseen. p2_no_device_merge FAILS.
#   GREEN (post-B2, leg_snap armed for mixed): the attempt ladder verifies the composite route,
#        rolls the shorted attempt back and lands the rigid diagonal relay -> P and M stay on
#        DISTINCT nets. P4 is deliberately NOT asserted: an accepted relay may legally keep one
#        diagonal wire ("electrically correct beats pretty", WIRING.md §9) -- P1/P2 are the contract.
#
# NOTE: a PURE-AXIS mixed drag along y=0 (the after_26 topology) has a DEGENERATE relay (anchor and
# moved pin stay collinear) that cannot lift the plow off the row -- the ladder engages but cannot
# repair, so that short is only REFUSED by B3, not repaired here. This test uses the diagonal drop,
# which the relay CAN repair, so B2's win is observable in isolation. See
# doc/claude/suggestions/hardening_sprint_plan.md (B2, RED-repro correction) and WIRING.md risk #2.
#
# True headless (scripted release path is byte-identical to the interactive drag's release, and this
# is a release-topology short, not a per-motion one -- WIRING.md §0.7):
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_53_mixed_selection_safetynet_0113.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

# before_8 rebuilt in memory with the user's launch gates (cadence_style_rc).
proc setup_before8 {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 0}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -320 -190 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res      -40    0 3 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140} {-550 140 -400 140}
    {-400 140 -390 140} {-400 -40 -400 140} {-320 -300 -320 -220} {-420 -300 -320 -300}
    {-320 -160 -320 -150} {-320 -150 -80 -150} {-400 -40 0 -40} {-80 -150 -80 0}
    {0 -40 0 0} {-80 0 -70 0} {-10 0 0 0}
  } { xschem wire {*}$w }
  # DECOY wire far in the corner: its sole purpose is to make the selection MIXED
  # (fluid_startsel_wires > 0). It routes to nothing and moving it perturbs no device net.
  xschem wire 400 400 500 400
}
proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap $inst]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}

setup_before8
set before [dev_pin_map]
check "setup: R18.P and R18.M start on DISTINCT nets (P=[pinnet R18 P] M=[pinnet R18 M])" \
  [expr {[pinnet R18 P] ne [pinnet R18 M]}]

# MIXED selection: R18 (instance) + the decoy wire (box-select) -> fluid_startsel_wires = 1.
xschem unselect_all
xschem select instance R18
xschem select_inside 395 395 505 405
# Diagonal drop the rigid relay can repair.
xschem move_objects -110 -80 stretch kissing

# --- P2 no-short: the RED-first discriminator (R18's two DISTINCT pins must not merge) ---
check "P2: R18's two pins stay on DISTINCT nets (no device short) P=[pinnet R18 P] M=[pinnet R18 M]" \
  [expr {[pinnet R18 P] ne [pinnet R18 M]}]
check "P2: device-pin-merge detector passes (no foreign device merged)" \
  [p2_no_device_merge $before]
# --- P1 connectivity preserved: R18.M's follow net still reaches the ammeter ---
check "P1: R18.M still reaches v8.plus (follow net intact)" \
  [expr {[pinnet R18 M] eq [pinnet v8 plus]}]
check "P1: OUT preserved (v8.minus == opin p5)" \
  [expr {[pinnet v8 minus] eq [pinnet p5 p]}]

we_result
