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
#
#    RE-AUTHORED for S3 (R3 = RIDE, changes #8/#9/#10). The oracle is unchanged; what changed is
#    the schematic it is measuring. S0 built this counter precisely so 0227 would be audible while
#    S1/S3 were built, and S3 is the stage that silences it: the wire now carries the label, so
#    the anchor is never left behind and the net keeps its name. The 0-strand answer here is
#    therefore a claim about the RIDE, not about the oracle -- AL below re-runs the identical
#    gesture with `label_ride 0` and still scores 1, which is what keeps the counter honest.
# ---------------------------------------------------------------------------
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "A0 S3: the label rode, so the net survives"         [xschem getprop wire 0 lab] {VOUT}
check "A0b ... and it really moved with the wire"          [lrange [xschem instance_pin_coord l1 name p] 1 2] {100 100}
check "A1 S3: no strand"                                   [strands] 0
check "A2 the blind counter stays 0 (why we needed A1)"    [v fluid_last_move_violations] 0

# AL the same gesture with the S3 escape hatch off: this is the pre-S3 world, and it is the
#    POSITIVE witness the oracle needs. If the strand test ever degrades into "count labels that
#    are off copper" or stops being published, AL goes red while A stays green.
scene
set label_ride 0
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "AL0 legacy: the net really was lost (0227)"          [xschem getprop wire 0 lab] {#net1}
check "AL1 legacy: mid-span label stranded -> 1"            [strands] 1
set label_ride 1

# ---------------------------------------------------------------------------
# B. Controls that must NOT fire.
# ---------------------------------------------------------------------------
# B1 label at an ENDPOINT stays on copper. RE-AUTHORED for S3: it used to stay because
#    connect_by_kissing() minted a tether stub at the coincident endpoint; change #8 removed that
#    for labels and the RIDE carries it instead. Same 0 either way -- which is the claim, since the
#    end-of-stub case is the one #8 must not regress (test_label_ride.tcl V13/U4).
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
# C. The count is per-LABEL, not per-gesture. RE-AUTHORED for S3: under the ride both labels now
#    travel with their own wire, so the S3 answer is 0 and the per-label claim moves to CL, where
#    the hatch is off and the count must be 2 rather than 1.
# ---------------------------------------------------------------------------
proc twolabels {} {
  scene
  xschem wire 0 0 200 0
  xschem wire 0 -100 200 -100
  xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=A}
  xschem instance {lab_pin.sym} 100 -100 0 0 {name=l2 lab=B}
  xschem unselect_all
  xschem select wire 0
  xschem select wire 1
  xschem move_objects 0 200 stretch kissing
}
twolabels
check "C S3: both labels rode their own wire -> 0" [strands] 0
check "C0b ... l1 landed on its wire"              [lrange [xschem instance_pin_coord l1 name p] 1 2] {100 200}
check "C0c ... l2 landed on its wire"              [lrange [xschem instance_pin_coord l2 name p] 1 2] {100 100}
set label_ride 0
twolabels
check "CL legacy: two mid-span labels stranded -> 2 (per-label)" [strands] 2
set label_ride 1

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
#
#    RE-AUTHORED AGAIN for S3 (2026-08-06), which is the "until then" arriving. The ride closes
#    this cell in BOTH configs, so the three-row table above collapses to one row:
#      autotrim 0, label_ride 1            wires 1  strands 0  net VOUT   <- A above
#      autotrim 1, label_ride 1            wires 1  strands 0  net VOUT   <- D below
#      any config,  label_ride 0           wires as before, strands 1, net #net1  <- AL / DL
#    The escalation on issue 0227 is therefore lifted, and `label_splits_wires 1` stops being a
#    load-bearing mitigation and goes back to being the one-release escape hatch S2 intended.
#    DM is kept, but it can no longer witness the SPLIT+TETHER mask on its own -- with the ride on,
#    the label stays connected for a completely different reason -- so it now carries its own
#    `label_ride 0` leg (DM3/DM4) to keep testing the thing it was written to test.
# ---------------------------------------------------------------------------
proc cadence_midspan {} {
  scene
  set ::autotrim_wires 1
  xschem wire 0 0 200 0
  xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
  xschem trim_wires
  xschem unselect_all
  for {set i 0} {$i < [xschem get wires]} {incr i} { xschem select wire $i }
  xschem move_objects 0 100 stretch kissing
  xschem resolved_net 0
}
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
check "D1 S3 closes 0227 for the cadence user too -> 0"     [strands] 0
check "D2 ... and the net keeps its name"                   [xschem getprop wire 0 lab] {VOUT}
check "D2b ... the label rode"                              [lrange [xschem instance_pin_coord l1 name p] 1 2] {100 100}

# DL the S2 measurement, preserved: with the ride off this is exactly the row S2 recorded, and it
#    is what issue 0227's escalation note was about.
set label_ride 0
cadence_midspan
check "DL1 legacy (label_ride 0): S2's unmasked strand -> 1" [strands] 1
check "DL2 legacy: ... and the net really was lost"          [xschem getprop wire 0 lab] {#net1}
set label_ride 1

# DM the pre-S2 data model under the escape hatch: `label_splits_wires 1` must still restore the
#    split, or the switch is not a switch. Under S3 the label stays connected either way, so the
#    connectivity half of this claim is no longer a mask witness -- DM3/DM4 withhold the ride to
#    get that back. DM1 is also the sabotage variant of A1 (WIRING.md §10: every predicate needs
#    one): if the strand test ever degrades into an absolute count of off-copper labels it goes red.
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
check "DM1 legacy: the label is carried -> 0"                    [strands] 0
check "DM2 legacy: ... and the net name survives"                [xschem getprop wire 0 lab] {VOUT}
set label_ride 0
cadence_midspan
check "DM3 legacy split + no ride: the TETHER mask still works" [strands] 0
check "DM4 legacy: ... which is the pre-S2 row, restored"        [xschem getprop wire 0 lab] {VOUT}
set label_ride 1
set label_splits_wires 0

# D3 the hole autotrim never masked, in either setting: the keyboard stretch paths do not arm
#    kissing (issue 0228), so there is no tether to mint. Same repro, kissing withheld. Asserted
#    under `label_splits_wires 1` so it stays the 0228 claim and not a restatement of D1.
#    RE-AUTHORED for S3: this is the case the spec's §8 disposition means by "the label half of
#    0228 is subsumed by S3" -- RIDE is deliberately NOT gated on connect_by_kissing, so it fires
#    here where neither the tether nor S1's leash ever could. D3L keeps the 0228 measurement.
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
check "D3 S3: no kissing needed, the label rides (0228) -> 0" [strands] 0
check "D4 ... and the net keeps its name"                    [xschem getprop wire 0 lab] {VOUT}
set label_ride 0
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
check "D3L legacy: autotrim, kissing NOT armed (0228) -> 1"  [strands] 1
check "D4L legacy: ... and the net really was lost"          [xschem getprop wire 0 lab] {#net1}
set label_ride 1
set label_splits_wires 0
set autotrim_wires 0

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
