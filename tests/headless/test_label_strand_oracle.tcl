# RED-first regression for the net-label STRAND oracle
# (doc/claude/specs/wire_label_ride.md S0, change #3; issue 0227).
#
# fluid_count_label_shorts() (src/move.c) counts a net label sitting on the WRONG net, but its
# inner loop `break`s on the first touching wire and counts NOTHING when no wire touches at all.
# A label left behind by a wire translation therefore loses its net silently:
# `fluid_last_move_violations` stays 0, stderr stays empty, and the net reverts to #netN.
#
# This test pins the missing arm: a per-gesture DELTA counter published as
# `fluid_last_move_label_strands` -- labels that sat ON COPPER at gesture START and touch
# nothing at gesture END.  Every later stage of wire_label_ride is blind without it.
#
# RED before the implementation: the variable does not exist, so case A1 reports <unset>.
#
# Pure headless (no X needed).  Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_label_strand_oracle.tcl
# Prints "RESULT: ALL PASS" / "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# read a fluid_last_move_* var without throwing when it was never published
proc v {n} { if {[info exists ::$n]} { return [set ::$n] } else { return "<unset>" } }
proc strands {} { return [v fluid_last_move_label_strands] }

set fluid_editing 1
set fluid_enforce_invariants 0   ;# log-only: we want to observe the count, not a refusal
set cadence_compat 0
set autotrim_wires 0             ;# stock default; the cadence_compat mode is exercised in D

# Every case starts from an empty buffer and forgets the previous publish, so a stale value
# can never make a case pass by accident (green-but-hollow guard, WIRING.md §10).
proc scene {} {
  unset -nocomplain ::fluid_last_move_label_strands
  xschem clear force
  xschem unselect_all
}

# ---------------------------------------------------------------------------
# A. The defect: a label tapping the SPAN INTERIOR is stranded by a translation.
#    (issue 0227's measured repro, stock defaults.)
# ---------------------------------------------------------------------------
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "A0 the net really was lost (0227 still reproduces)" [xschem getprop wire 0 lab] {#net1}
check "A1 mid-span label stranded -> 1"                    [strands] 1
check "A2 the blind counter stays 0 (why we needed A1)"    [v fluid_last_move_violations] 0

# ---------------------------------------------------------------------------
# B. Controls that must NOT fire.
# ---------------------------------------------------------------------------
# B1 label at an ENDPOINT: connect_by_kissing mints a tether stub, so it stays on copper.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 0 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "B1 endpoint label rescued by kissing -> 0" [strands] 0

# B2 the label is part of the selection: the ELEMENT commit moves it with the wire.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem select instance 0
xschem move_objects 0 100 stretch kissing
check "B2 label moved together with its wire -> 0" [strands] 0

# B3 a label that was ALREADY off copper before the gesture is NOT this gesture's fault.
#    (1.7% of the shipped corpus -- 91 labels in 21 files -- sits off copper by design.)
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 400 -400 0 0 {name=l1 lab=ORPHAN}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "B3 pre-existing off-copper label -> 0 (delta, not absolute)" [strands] 0

# B4 pin-aware predicate: a label sitting on a DEVICE pin with no wire under it is connected.
#    1919 labels in the shipped libraries use this idiom (gnd/vdd dropped straight on a pin);
#    a wire-only strand test would report every one of them.
scene
xschem instance {res.sym} 0 0 0 0 {name=R1 value=1k}
set pc [xschem instance_pin_coord R1 name P]
set px [lindex $pc 1]; set py [lindex $pc 2]
xschem instance {lab_pin.sym} $px $py 0 0 {name=l1 lab=TOP}
xschem wire 400 -400 500 -400
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "B4 label on a device pin, unrelated wire moved -> 0" [strands] 0

# B4b ... but ANOTHER NET LABEL's pin is NOT copper. A label's PINLAYER rect is a naming anchor,
#     not copper geometry (wire_label_ride.md §5.2), so a label dragged off a wire onto a PARKED
#     off-copper label (the R9 idiom, 91 shipped instances) really is stranded and must be counted.
#     Without that filter the two labels mask each other, the oracle scores 0, and the net reverts
#     to #netN with no diagnostic at all -- the exact silence S0 exists to break.
#     Rigid move (no kissing) so the S1 leash is not involved and this tests the predicate alone.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 -100 0 0 {name=l2 lab=PARKED}
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select instance 1
xschem move_objects 0 -100
xschem resolved_net 0
check "B4b label dragged onto a parked label -> 1" [strands] 1
check "B4c ... and the net really was lost"        [xschem getprop wire 0 lab] {#net1}

# B5 gating contract: with fluid_editing off nothing is published at all
#    (same shape as tests/headless/wireedit/test_wireedit_26_phase1_runtime_guard.tcl).
scene
set fluid_editing 0
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "B5 fluid_editing off -> not published" [expr {![info exists ::fluid_last_move_label_strands]}] 1
set fluid_editing 1

# ---------------------------------------------------------------------------
# C. A stranded label is reported even when the gesture also moves other copper,
#    and the count is per-label, not per-gesture.
# ---------------------------------------------------------------------------
scene
xschem wire 0 0 200 0
xschem wire 0 -100 200 -100
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=A}
xschem instance {lab_pin.sym} 100 -100 0 0 {name=l2 lab=B}
xschem unselect_all
xschem select wire 0
xschem select wire 1
xschem move_objects 0 200 stretch kissing
check "C two mid-span labels stranded -> 2" [strands] 2

# ---------------------------------------------------------------------------
# D. The user's real environment: cadence_compat forces autotrim_wires on
#    (cadence_compat_sync, xschem.tcl:16260-16264), so the wire IS split at the label pin and
#    the label ends up on an ENDPOINT of both halves -- which is what MASKS issue 0227 for this
#    user (spec §4.2). The oracle must agree: no strand here, because the label really is still
#    connected. This is the sabotage variant of A1 (WIRING.md §10: every predicate needs one) --
#    if the strand test ever degrades to "absolute count of off-copper labels", D1 goes red.
# ---------------------------------------------------------------------------
scene
set autotrim_wires 1
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem trim_wires
check "D0 autotrim really split the wire at the label pin" [xschem get wires] 2
xschem unselect_all
xschem select wire 0
xschem select wire 1
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "D1 autotrim+kissing keeps the label connected -> 0" [strands] 0
check "D2 ... and the net name survives"                   [xschem getprop wire 0 lab] {VOUT}

# D3 the hole autotrim does NOT mask: the keyboard stretch paths never arm kissing (issue 0228),
#    so even a split-to-endpoint label is stranded. Same repro, kissing withheld.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem trim_wires
xschem unselect_all
xschem select wire 0
xschem select wire 1
xschem move_objects 0 100 stretch
xschem resolved_net 0
check "D3 autotrim, kissing NOT armed (0228) -> 1" [strands] 1
check "D4 ... and the net really was lost"         [xschem getprop wire 0 lab] {#net1}
set autotrim_wires 0

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
