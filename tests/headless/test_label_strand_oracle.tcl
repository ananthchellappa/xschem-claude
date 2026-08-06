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
#    (cadence_compat_sync, xschem.tcl:16260-16264). This is issue 0227's OWN repro -- the label
#    is STATIONARY and the WIRE translates out from under it -- so it is the RIDE case (S3) and
#    neither S1's leash (which needs the label to be the moving object) nor S2 addresses it.
#
#    RE-AUTHORED for S2 (R2, changes #6/#7). Pre-S2 the split put the label on an ENDPOINT of both
#    halves, so connect_by_kissing()'s WIRE-endpoint arm (actions.c, change #8 -- deliberately NOT
#    removed until S3) found it in instpin_spatial_table and minted a TETHER stub, and the label
#    stayed connected. That accident is what MASKED 0227 for the cadence_compat user (spec §4.2,
#    §13.5 row 2). With `label_splits_wires 0` the label is strictly INTERIOR to one wire, the
#    wire's endpoints are 100 units away, the tether arm finds nothing, and the label strands.
#
#    So S2 removes the mask. That is a real, measured behaviour change for the cadence user and it
#    is recorded here as ground truth rather than smoothed over -- but it is NOT a new defect
#    class: it makes them behave exactly like a stock-config user, who has stranded on this
#    gesture all along (case A1 above, autotrim off, same fixture, strands 1). Measured
#    2026-08-06, all three configs, same gesture:
#      autotrim 0 (stock default)            wires 1  strands 1  net #net1
#      autotrim 1, label_splits_wires 1      wires 3  strands 0  net VOUT   <- the pre-S2 mask
#      autotrim 1, label_splits_wires 0      wires 1  strands 1  net #net1  <- S2, == default
#    RIDE (S3) is what closes it, for both configs at once. Until then `label_splits_wires 1`
#    restores the mask, and DM below keeps that promise honest.
# ---------------------------------------------------------------------------
scene
set autotrim_wires 1
set label_splits_wires 0
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem trim_wires
check "D0 S2: the label does not split the wire (R2)"      [xschem get wires] 1
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "D1 S2 unmasks 0227: moving the wire strands it -> 1" [strands] 1
check "D2 ... and the net really was lost (S3 owed)"        [xschem getprop wire 0 lab] {#net1}

# DM the mask itself, under the escape hatch: `label_splits_wires 1` must restore the pre-S2
#    result exactly, or the switch is not a switch. This is also the sabotage variant of A1
#    (WIRING.md §10: every predicate needs one) -- if the strand test ever degrades into an
#    absolute count of off-copper labels, DM1 goes red.
scene
set label_splits_wires 1
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem trim_wires
check "DM0 legacy: autotrim splits the wire at the label pin" [xschem get wires] 2
xschem unselect_all
xschem select wire 0
xschem select wire 1
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "DM1 legacy: the split+tether mask keeps it connected -> 0" [strands] 0
check "DM2 legacy: ... and the net name survives"                [xschem getprop wire 0 lab] {VOUT}
set label_splits_wires 0

# D3 the hole autotrim never masked, in either setting: the keyboard stretch paths do not arm
#    kissing (issue 0228), so there is no tether to mint. Same repro, kissing withheld. Asserted
#    under `label_splits_wires 1` so it stays the 0228 claim and not a restatement of D1.
scene
set label_splits_wires 1
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
set label_splits_wires 0
set autotrim_wires 0

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
