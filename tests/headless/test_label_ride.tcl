# RED-first regression for wire_label_ride S1 = R1 (no extruded copper) + LEASH
# and S3 = R3 (RIDE: the wire moves, the label follows, orientation included)
# (doc/claude/specs/wire_label_ride.md §7 S1/S3; changes #1, #2, #4, #5, #8, #9, #10).
#
# S3 (section V below) adds the OTHER direction of the same contact-matrix cell: S1 covers "the
# LABEL is dragged and its copper stays", S3 covers "the copper is dragged and the label stays".
# The selection predicate is inverted between the two and the placement math is not shared --
# LEASH corrects an origin the ELEMENT commit already wrote (spec §14.3), RIDE has no committed
# origin to correct and must solve for one (spec §11 hazard D).
#
# TWO claims, and they must ship together (spec §7): change #4 stops connect_by_kissing()
# minting a zero-length stub at a NET LABEL's pin, and the LEASH puts the label back on its
# owner's copper at move END.  #4 alone converts today's ugly-but-connected stub into a silent
# orphan; the leash alone leaves the extruded copper behind.
#
# RED before the implementation (measured 2026-08-05 against the S0 tree):
#   A1  along-wire drag leaks a duplicate collinear N record   -> 2 wires (want 1)
#   B1  perpendicular drag leaves a permanent stub             -> 2 wires (want 1)
#   B2  ... and the label commits OFF the wire                 -> (100,-100) (want (100,0))
#   C1  same with the follow-set armed: 1 N record becomes 3   -> 3 wires (want 1)
#   D1  same under autotrim_wires 1                            -> 3 wires (want 2)
#   E/F/G/M  leash geometry (diagonal, past-the-end, pin anchor, vertical, diagonal owner)
# Every H/I/J/K/L case is a CONTROL that is green on both sides of the change.
#
# Scope note: LEASH is gated on xctx->connect_by_kissing (spec §5.6), i.e. on the CONNECTED
# drag (`m` under cadence_style_rc, the gesture whose stub #4 removes).  The rigid/disconnected
# move (Shift-M, Ctrl+LMB) is deliberately untouched and still strands -- case K1 pins that
# policy so a later stage cannot change it by accident.
#
# Pure headless (no X needed).  Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_label_ride.tcl
# Prints "RESULT: ALL PASS" / "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# label pin anchor (lab_pin/lab_wire carry a single pin named `p` centred on the origin)
proc lp {{nm l1}} { return [lrange [xschem instance_pin_coord $nm name p] 1 2] }
# strand oracle from S0; "<unset>" when fluid_editing withheld publication
proc st {} {
  if {[info exists ::fluid_last_move_label_strands]} { return $::fluid_last_move_label_strands }
  return "<unset>"
}
# sorted wire spans, so an assertion never depends on wire array order
proc spans {} {
  set r {}
  for {set i 0} {$i < [xschem get wires]} {incr i} { lappend r [xschem wire_coord $i] }
  return [lsort $r]
}
proc scene {} {
  unset -nocomplain ::fluid_last_move_label_strands
  xschem clear force
  xschem unselect_all
}

set fluid_editing 1
set fluid_enforce_invariants 0   ;# observe the geometry, do not let a refusal hide it
set cadence_compat 0
set autotrim_wires 0             ;# stock default; D exercises the cadence_compat mode

# a mid-span label on one horizontal wire, the topology the whole spec is about
proc midspan {} {
  scene
  xschem wire 0 0 200 0
  xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
  xschem unselect_all
  xschem select instance 0
}

# ---------------------------------------------------------------------------
# A. R1, along-wire: sliding the label ALONG its wire must not leak a duplicate
#    collinear N record.  autotrim_wires MUST be 0 here -- autotrim's check_includes
#    cull (check.c:312-321) silently eats the duplicate and hides the defect.
#    Kissing WITHOUT stretch: the Phase-5 `trim_wires()` a stretch move runs anyway
#    (move.c, `else if(xctx->stretch_select) trim_wires()`) is the other thing that
#    hides it -- A3 keeps that path honest as a control.
# ---------------------------------------------------------------------------
midspan
xschem move_objects 50 0 kissing
check "A1 along-wire drag creates no copper"        [xschem get wires] 1
check "A2 ... and the label really did slide (R6)"  [lp] {150 0}
check "A3 ... the wire is untouched"                [spans] {{0 0 200 0}}
check "A4 ... the net keeps its name"               [xschem getprop wire 0 lab] {VOUT}
check "A5 ... no strand"                            [st] 0

midspan
xschem move_objects 50 0 stretch kissing
check "A6 along-wire, follow set armed: no copper"  [xschem get wires] 1
check "A7 ... label slid"                           [lp] {150 0}

# ---------------------------------------------------------------------------
# B. R1 + LEASH, perpendicular: the drag must extrude nothing and the label must be
#    projected back onto its owner's span (R7 -- a label can never sit off copper).
# ---------------------------------------------------------------------------
midspan
xschem move_objects 0 -100 kissing
check "B1 perpendicular drag creates no copper"     [xschem get wires] 1
check "B2 ... leash puts the label back on the wire" [lp] {100 0}
check "B3 ... the wire is untouched"                [spans] {{0 0 200 0}}
check "B4 ... the net keeps its name"               [xschem getprop wire 0 lab] {VOUT}
check "B5 ... no strand"                            [st] 0

# C. the same gesture with the follow set armed -- today the stub defeats the save-time
#    coalescer and turns one N record into three (spec §4.1, the .sch byte-stability claim).
midspan
xschem move_objects 0 -100 stretch kissing
check "C1 perpendicular + follow set: still one N"  [xschem get wires] 1
check "C2 ... leash put the label back"             [lp] {100 0}
check "C3 ... the wire is untouched"                [spans] {{0 0 200 0}}

# D. the user's real environment: cadence_compat forces autotrim_wires on.  RE-AUTHORED for S2
#    (R2, changes #6/#7): the label no longer splits the wire at its pin, so `label_splits_wires`
#    (default 0) makes this whole block a single-wire story and D6's weld is the RESTING state,
#    not a transient.  The leash result is BYTE-IDENTICAL either way -- D0/D6 are the only lines
#    that move -- because label_ride_run() already grew the owner across collinear split points on
#    purpose (spec §14.4), which is exactly what S2 makes true of the data model itself.  The
#    pre-S2 numbers are kept as the DL legacy leg below, and they are not redundant: they are the
#    only live exercise of hazard B's geometric re-find in this file.
scene
set autotrim_wires 1
set label_splits_wires 0
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
check "D0 S2: the label does NOT split the wire (R2)"  [xschem get wires] 1
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 stretch kissing
check "D1 autotrim: no third wire extruded"          [xschem get wires] 1
check "D2 ... leash put the label back"              [lp] {100 0}
check "D3 ... the run is untouched"                  [spans] {{0 0 200 0}}
check "D4 ... the net keeps its name"                [xschem getprop wire 0 lab] {VOUT}
check "D5 ... no strand"                             [st] 0
xschem wire 400 0 500 0
check "D6 ... and it STAYS one wire (S2: no re-split)" [spans] {{0 0 200 0} {400 0 500 0}}

# DL. the same gesture with the S2 escape hatch OFF, i.e. the pre-S2 data model.  Two jobs:
#     (a) it proves `label_splits_wires 1` restores the old behaviour exactly, so a netlist
#         difference blamed on S2 has a switch rather than a bisect;
#     (b) it is the ONLY case here that still destroys the captured owner wire id, so it is what
#         keeps hazard B honest.  The apply site is mandatorily AFTER maintain_wire_segments
#         (§11 A), so the cleanup pass runs while the label is transiently off the split point,
#         welds the two collinear halves and frees one id; DL2 then needs the geometric re-find.
#         An id-only label_ride_owner() binds to the wrong half and DL2 goes red.  Under
#         `label_splits_wires 0` no split exists, the owner id survives, and D2 above no longer
#         exercises that path at all -- which is why this leg is not optional.
scene
set autotrim_wires 1
set label_splits_wires 1
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
check "DL0 legacy: autotrim splits the wire at the pin" [xschem get wires] 2
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 stretch kissing
check "DL1 legacy: no third wire extruded"             [xschem get wires] 1
check "DL2 legacy: leash put the label back (hazard B)" [lp] {100 0}
check "DL3 legacy: the halves welded while it was away" [spans] {{0 0 200 0}}
check "DL4 legacy: the net keeps its name"             [xschem getprop wire 0 lab] {VOUT}
check "DL5 legacy: no strand"                          [st] 0
xschem wire 400 0 500 0
check "DL6 legacy: the weld is transient (re-splits)"  [spans] {{0 0 100 0} {100 0 200 0} {400 0 500 0}}
set label_splits_wires 0
set autotrim_wires 0

# ---------------------------------------------------------------------------
# E-G, M. LEASH geometry.  The correction is a projection onto the owner SEGMENT
#         (clamped to its endpoints), so it is orientation-independent and it decomposes
#         a diagonal drag into "parallel applied, perpendicular discarded" (spec §5.4).
# ---------------------------------------------------------------------------
# E: diagonal drag -> the parallel component survives, the perpendicular one is discarded.
midspan
xschem move_objects 50 -100 kissing
check "E1 diagonal drag: parallel component kept"    [lp] {150 0}
check "E2 ... and no copper extruded"                [xschem get wires] 1

# F: sliding PAST the endpoint clamps to the endpoint.  R6/S5 will replace this clamp with
#    "extend the wire"; until then the label must not leave copper.
midspan
xschem move_objects 200 0 kissing
check "F1 past the end clamps to the endpoint"       [lp] {200 0}
check "F2 ... and the wire is not extended (S5)"     [spans] {{0 0 200 0}}

# G: the gnd/vdd-on-a-device-pin idiom -- 1919 labels in the shipped libraries (36%) sit on a
#    device pin with NO wire under them (spec §5.8).  Today connect_by_kissing() mints the stub
#    that keeps such a label attached; with #4 gone the leash must hold it, so its owner is the
#    PIN ANCHOR itself and the label springs back.
scene
xschem instance {res.sym} 0 0 0 0 {name=R1 value=1k}
set pc [lrange [xschem instance_pin_coord R1 name P] 1 2]
xschem instance {lab_pin.sym} [lindex $pc 0] [lindex $pc 1] 0 0 {name=l1 lab=TOP}
xschem unselect_all
xschem select instance 1
xschem move_objects 0 -100 kissing
check "G1 label on a bare device pin springs back"   [lp] $pc
check "G2 ... and no rescue wire is created"         [xschem get wires] 0
check "G3 ... no strand"                             [st] 0

# M1: vertical owner (the projection must not be axis-specific).
scene
xschem wire 0 0 0 200
xschem instance {lab_pin.sym} 0 100 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select instance 0
xschem move_objects 100 0 kissing
check "M1 vertical owner: label projected back"      [lp] {0 100}
check "M2 ... and no copper extruded"                [xschem get wires] 1

# M3: diagonal owner.  The projection of a snapped point onto a diagonal span is generally
#     OFF the snap grid; that is accepted (spec §5.4) -- re-snapping could push it off copper.
scene
xschem wire 0 0 200 200
xschem instance {lab_pin.sym} 100 100 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -50 kissing
check "M3 diagonal owner: projected onto the span"   [lp] {75 75}
check "M4 ... and no copper extruded"                [xschem get wires] 1

# ---------------------------------------------------------------------------
# H-L. CONTROLS.  Every one of these is green BEFORE and AFTER the change; they are the
#      scope fence around inst_is_netlabel() and around the leash's gate.
# ---------------------------------------------------------------------------
# H1: ipin is type=ipin, a real hierarchy terminal -- deliberately NOT covered by
#     inst_is_netlabel() (strcmp "label", not IS_LABEL_OR_PIN).  It must still kiss.
scene
xschem wire 0 0 200 0
xschem instance {ipin.sym} 100 0 0 0 {name=p1 lab=IN}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 kissing
check "H1 ipin still kisses (not a net label)"       [xschem get wires] 2
check "H2 ... the rescue stub is the perpendicular"  [spans] {{0 0 200 0} {100 -100 100 0}}

# H3: a real DEVICE pin sitting on a wire, dragged away, still gets its rescue stub.
scene
xschem wire 0 -100 200 -100
xschem instance {res.sym} 100 -70 0 0 {name=R1 value=1k}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 kissing
check "H3 device pin still kisses"                   [xschem get wires] 2

# I1: end-of-stub label with the follow set armed -- select_attached_nets' ELEMENT arm
#     STRETCHES the wire to follow (select.c; deliberately not edited, spec §10 "label-
#     transparent copper" was rejected).  The label stays on copper, so the leash must be a
#     no-op: it fires only when the anchor lands OFF copper.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 0 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 stretch kissing
check "I1 endpoint label: the wire followed"         [xschem get wires] 1
check "I2 ... leash did not fight the stretch"       [lp] {0 -100}
check "I3 ... span stretched to the label"           [spans] {{0 -100 200 0}}

# J1: label AND its owner wire both selected -> a rigid translation; the label never leaves
#     copper, so the leash must not perturb it.
midspan
xschem select wire 0
xschem move_objects 0 -100 kissing
check "J1 label+wire rigid move: label rides"        [lp] {100 -100}
check "J2 ... and nothing extruded"                  [xschem get wires] 1
check "J3 ... span translated"                       [spans] {{0 -100 200 -100}}

# K1: POLICY PIN.  The rigid/disconnected move (Shift-M, Ctrl+LMB detach) does NOT arm
#     kissing, and LEASH is gated on kissing (spec §5.6).  It still strands, exactly as today.
#     If a later stage makes the leash unconditional this case must be updated DELIBERATELY.
midspan
xschem move_objects 0 -100
check "K1 rigid move still detaches the label"       [lp] {100 -100}
check "K2 ... and the S0 oracle still reports it"    [st] 1

# L1: a label that was ALREADY off copper has no owner, so nothing leashes it (R9: 91 labels
#     across 21 shipped files sit off copper by design).  This is also the 0233 boundary --
#     the invariant is CONSERVATION (never take a label off copper), not prohibition.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 400 -400 0 0 {name=l1 lab=ORPHAN}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 kissing
check "L1 pre-orphan label moves freely"             [lp] {400 -500}
check "L2 ... and no copper is invented for it"      [xschem get wires] 1
check "L3 ... and it is not this gesture's strand"   [st] 0

# ---------------------------------------------------------------------------
# Q. THE COPY PATH.  copy_objects() is a separate entry point -- it calls connect_by_kissing()
#    itself and never goes through move_objects() -- so change #4 reaches it but the LEASH does
#    not.  Consequence, deliberate and pinned here: Shift-drag-copying a net label off its wire
#    used to mint a connecting stub and now simply places the copy off copper, which is upstream
#    XSCHEM's own flow ("drop a lab_wire in free space, then draw a wire to it") and is what R8 /
#    S6 will formalise.  A DEVICE pin copy is unchanged.
# ---------------------------------------------------------------------------
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select instance 0
xschem copy_objects 0 -100 kissing
check "Q1 copying a label extrudes no copper"          [xschem get wires] 1
check "Q2 ... and really did copy it"                  [xschem get instances] 2

scene
xschem wire 0 -100 200 -100
xschem instance {res.sym} 100 -70 0 0 {name=R1 value=1k}
xschem unselect_all
xschem select instance 0
xschem copy_objects 0 -100 kissing
check "Q3 copying a DEVICE still kisses"               [xschem get wires] 2

# Q4-Q7 S3 EXTENDS THE SAME POLICY TO THE OTHER KISSING ARM ON THIS PATH, and it is recorded here
#    because copy_objects() calls connect_by_kissing() directly. Copying a WIRE whose endpoint sits
#    on a stationary net label used to mint a tether stub from the label to the COPY -- copper
#    invented for a name that was never asked to move, which is the artifact §5.1 exists to delete
#    and the same call S1 made for the ELEMENT arm above. There is no ride here (copy_objects never
#    goes through move_objects, §14.9), and none is wanted: copy propagation is R8/S6.
#    A DEVICE pin still kisses on the copy, which is the fence.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 0 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem copy_objects 0 100 kissing
check "Q4 copying a wire past a label invents no stub"  [xschem get wires] 2
check "Q5 ... just the original and the copy"           [spans] {{0 0 200 0} {0 100 200 100}}
scene
xschem wire 0 0 200 0
xschem instance {res.sym} 0 30 0 0 {name=R1 value=1k}     ;# pin P lands at (0,0)
xschem unselect_all
xschem select wire 0
xschem copy_objects 0 100 kissing
check "Q6 copying a wire past a DEVICE pin still kisses" [xschem get wires] 3
check "Q7 ... and the tether stub is the perpendicular"  [spans] {{0 0 0 100} {0 0 200 0} {0 100 200 100}}

# ---------------------------------------------------------------------------
# P. R7: THE OWNER NEVER CHANGES.  §5.4 -- "If the projected anchor happens to land on a different
#    wire, that is irrelevant -- the label stays bound to the wire it started on.  No
#    re-attachment, ever."  So the leash's trigger is "the anchor left ITS OWNER", not "the anchor
#    is off all copper".  The weaker trigger looks equivalent and is not: it lets a label desert
#    its net whenever the drag happens to land on ANY other copper, and it does so silently,
#    because the S0 strand oracle shares the predicate and scores 0.  It is also a regression
#    against the pre-S1 tree, where the kissing stub kept the label on its own net.
#    To move a label to different copper, use the disconnected move (Shift-M / Ctrl+LMB), which
#    is not leashed -- case K1.
# ---------------------------------------------------------------------------
# P1: a neighbouring WIRE is not a re-attachment target.
scene
xschem wire 0 0 200 0
xschem wire 0 -100 200 -100
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 kissing
check "P1 landing on a NEIGHBOUR wire snaps back"      [lp] {100 0}
xschem resolved_net 0
check "P2 ... so the label keeps naming its own net"   [xschem getprop wire 0 lab] {VOUT}
check "P3 ... and did not rename the neighbour"        [xschem getprop wire 1 lab] {#net1}
check "P4 ... and nothing was extruded"                [xschem get wires] 2

# P5: a DEVICE pin is not one either -- same rule, and the drag is otherwise the exact shape of
#     the gnd/vdd-on-a-pin idiom, so this is where "landing on copper" and "landing on my owner"
#     visibly differ.
scene
xschem wire 0 0 200 0
xschem instance {res.sym} 100 -70 0 0 {name=R1 value=1k}   ;# pin P lands at (100,-100)
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
check "P5 the device pin is where the drag will land"  [lrange [xschem instance_pin_coord R1 name P] 1 2] {100 -100}
xschem unselect_all
xschem select instance 1
xschem move_objects 0 -100 kissing
check "P6 landing on a device pin snaps back too"      [lp] {100 0}
check "P7 ... and it is not a strand"                  [st] 0

# P8: two net labels at the SAME coordinate.  A label's pin is a naming anchor, not copper
#     (§5.2), so neither may count as the other's copper -- otherwise each masks the other, both
#     leave the wire, the leash declines for both and fluid_count_label_strands() reports 0.
#     Sabotage: drop the `inst_is_netlabel` filter in fluid_point_on_copper() and P8/P9 go red.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=A}
xschem instance {lab_pin.sym} 100 0 0 0 {name=l2 lab=A}
xschem unselect_all
xschem select instance 0
xschem select instance 1
xschem move_objects 0 -100 kissing
check "P8 coincident labels do not mask each other"    [lp] {100 0}
check "P9 ... both of them"                            [lrange [xschem instance_pin_coord l2 name p] 1 2] {100 0}
xschem resolved_net 0
check "P10 ... and the net survives"                   [xschem getprop wire 0 lab] {A}

# P11: the same rule from the other side -- two labels stacked on NOTHING are both off copper, so
#      neither is an owner and the drag is free (R9).  This is the sabotage variant for the
#      `inst_is_netlabel` filter in fluid_point_on_copper(): drop it and the dragged label is
#      leashed back to the other label's naming anchor, which is copper that does not exist.
scene
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=A}
xschem instance {lab_pin.sym} 100 0 0 0 {name=l2 lab=A}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 kissing
check "P11 labels stacked on nothing are not owners"   [lp] {100 -100}
check "P12 ... and no copper is invented"              [xschem get wires] 0

# ---------------------------------------------------------------------------
# S. THE OWNER IS A COLLINEAR RUN, NOT A WIRE RECORD.  autotrim_wires splits a wire at every
#    attachment point, so a mid-span label normally sits at the shared endpoint of two collinear
#    halves and BOTH touch its anchor.  Binding to whichever comes first in xctx->wire[] makes the
#    clamp a function of record order: a drag toward the other half is reverted to the junction
#    and the label does not move at all, silently.  Here a resistor pin at the junction blocks the
#    weld (any_inst_pin_at, check.c:405), so the two halves are permanent and the defect cannot
#    hide behind §14.7's transient merge.
# ---------------------------------------------------------------------------
foreach {tag dx} {S1right 400 S2left -80} {
  scene
  set autotrim_wires 1
  xschem instance {res.sym} 100 30 0 0 {name=R1 value=1k}   ;# pin P lands at (100,0)
  xschem wire 0 0 1000 0
  xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
  check "$tag fixture really is split at the junction" [expr {[xschem get wires] > 1}] 1
  xschem unselect_all
  xschem select instance 1
  xschem move_objects $dx 5 kissing                          ;# off the run, then leashed back
  check "$tag slide is not decided by wire record order" [lp] [list [expr {100 + $dx}] 0]
  set autotrim_wires 0
}

# ---------------------------------------------------------------------------
# N. The apply skeleton's structural claims: an OFF-ORIGIN pin under rotation, and the
#    gesture lifetime (abort / stepwise == one-shot / teardown mid-gesture).
# ---------------------------------------------------------------------------
# N1 spec §11 hazard (D): lab_pin/lab_wire/vdd/gnd are origin-centred, but bus_connect.sym is a
#    type=label symbol whose pin centre is at (10,-10) -- rotating it moves its pin ~28 units.
#    "Translate then rotate" slides such a label off copper, which R7 forbids.  The apply avoids
#    the whole class by correcting the COMMITTED origin by the ANCHOR delta: a translation moves
#    origin and pin by the same vector, so it is exact for any pin offset and any rot/flip, and
#    get_inst_pin_coord() stays the forward authority.  Assert on the pin, never on the origin.
proc bp {} { return [lrange [xschem instance_pin_coord b1 name p] 1 2] }
proc busscene {} {
  scene
  xschem wire 0 0 200 0
  xschem instance {bus_connect.sym} 90 10 0 0 {name=b1}   ;# pin lands at (100,0), on the wire
  xschem unselect_all
  xschem select instance 0
}
busscene
check "N0 the off-origin pin really starts on the wire" [bp] {100 0}
xschem move_objects 0 -100 kissing
check "N1 off-origin pin, translate: back on the wire"  [bp] {100 0}
check "N2 ... and no copper extruded"                   [xschem get wires] 1

# N3-N5 must ROTATE ABOUT A PIVOT THAT TAKES THE PIN OFF THE SPAN, or the leash never fires and
# the checks are satisfied by the raw ELEMENT commit alone.  `-anchor 100 0` pins the group-rotate
# pivot at the label's own anchor; the +(0,-60) then carries it clear of the wire, so the apply has
# to bring an off-origin, rotated pin back -- which is the measurement §14.3 and §12 question 2
# actually rest on.  Sabotage check: with label_ride_apply() stubbed out, N3/N4 go red.
busscene
xschem move_objects 0 -60 1 0 -anchor 100 0 kissing       ;# translate + rotate 90 about the anchor
xschem unselect_all
check "N3 off-origin pin, rotated: leashed back onto the span" [lindex [bp] 1] 0
check "N4 ... and it really is on copper"               [xschem net_at [lindex [bp] 0] [lindex [bp] 1]] 1
check "N5 ... and no copper extruded"                   [xschem get wires] 1

# N6 ABORT must drop the rider set and leave the label exactly where it started.
midspan
xschem move_objects start 100 0 kissing
xschem move_objects step 100 -50
xschem move_objects abort
check "N6 aborted gesture leaves the label alone"       [lp] {100 0}
check "N7 ... and creates no copper"                    [xschem get wires] 1

# N8 release == stepwise (WIRING.md P8 determinism): the leash is derived from the START anchor
#    and the TOTAL delta, so a drag committed over several live RUBBER steps must land exactly
#    where the same drag committed in one shot does.
#    `stretch` IS REQUIRED HERE.  Without it scheduler.c never calls select_attached_nets(), so
#    stretch_select stays 0, the fluid_reroute snapshot is never taken, and the RUBBER live-commit
#    gate can never fire -- the `step` calls would be pure rubber-band preview and the equality
#    would hold for ANY implementation, including none.  With it the geometry is really committed
#    and rolled back to pristine on each step, which is the question §12 asked.
midspan
xschem move_objects start 100 0 kissing stretch
xschem move_objects step 120 -20
xschem move_objects step 140 -60
xschem move_objects step 150 -100
xschem move_objects end
set n8_stepwise [list [lp] [xschem get wires] [spans]]
midspan
xschem move_objects 50 -100 kissing stretch
check "N8 stepwise == one-shot (live-commit path)" $n8_stepwise [list [lp] [xschem get wires] [spans]]
check "N8b ... and the one-shot really leashed"  [lp] {150 0}

# N9 a buffer teardown mid-gesture must drop the rider set (else a later END would leash
#    instance ids belonging to a different schematic).
midspan
xschem move_objects start 100 0 kissing
xschem move_objects step 100 -50
xschem clear force
check "N9 clear mid-gesture is survivable"              [xschem get wires] 0

# ---------------------------------------------------------------------------
# R. STOCK DEFAULTS.  Everything above runs with fluid_editing on.  Neither change #4 nor the
#    leash is part of the fluid engine -- the capture hangs off move START and the apply off
#    move END, both outside every `tclgetboolvar("fluid_editing")` gate -- so a default-config
#    user gets the same behaviour.  Spec §12 ("the test matrix must cover both settings rather
#    than assuming the default path exercises it").  The S0 strand oracle is NOT published here
#    (fluid_check_move_invariants returns early), which is itself the S0 contract.
# ---------------------------------------------------------------------------
set fluid_editing 0
midspan
xschem move_objects 0 -100 kissing
check "R1 fluid off: perpendicular drag extrudes nothing" [xschem get wires] 1
check "R2 fluid off: the leash still fires"               [lp] {100 0}
midspan
xschem move_objects 50 0 kissing
check "R3 fluid off: the label still slides"              [lp] {150 0}
check "R4 fluid off: and the net keeps its name"          [xschem getprop wire 0 lab] {VOUT}
check "R5 fluid off: the S0 oracle stays unpublished"     [st] {<unset>}
set fluid_editing 1

# ===========================================================================
# V. S3 = R3, THE RIDE.  The label is STATIONARY and the copper it names moves, rotates or flips;
#    the label follows, its own orientation included.  This is issue 0237's own repro, and it is
#    the direction S1's leash deliberately did not cover.
#
#    RED before the implementation (measured 2026-08-06 against the a72ddb34 tree, every case
#    below reproduced by hand first):
#      V1  0237 stock defaults          label stayed at (100,0), net #net1, strands 1
#      V2  0237 under autotrim (S2)     identical -- S2 removed the split that masked it
#      V3  0238 cell, no kissing        identical
#      V4  END-OF-STUB label            2 wires: the kissing TETHER stub, label left at (0,0)
#      V5/V6/V7 rotate / flip           label not moved and not re-oriented at all
#    and every U control below was green on both sides.
#
#    THREE THINGS SHIP TOGETHER and none of them is optional:
#      #8  connect_by_kissing()'s wire-endpoint TETHER stops firing for a net label,
#      RIDE carries the label instead,
#      `label_ride` (default 1) switches BOTH -- 0 gives the stub and no ride, i.e. pre-S3.
#    Shipping #8 without RIDE would take the end-of-stub label (V4 -- the dominant topology the
#    wire-stub+netlabel idiom produces) from "ugly but connected" to "silently orphaned", which is
#    strictly worse than either state.  V4 + U1 are the pair that keeps that honest.
# ===========================================================================
# rot/flip as it reaches DISK -- the honest oracle for "the text rotates with the wire" (R3).
# draw.c orients the symbol's `T {@lab}` record from this same pair, so asserting the pair asserts
# the text.  There is no `getprop instance <n> rot`.
set ::rfsch [file join [file dirname [info script]] _label_ride_rf.sch]
proc rotflip {nm} {
  file delete -force $::rfsch
  xschem saveas $::rfsch
  set fh [open $::rfsch r]; set txt [read $fh]; close $fh
  foreach line [split $txt \n] {
    if {[string match "C \{*" $line] && [string match "*name=$nm*" $line]} {
      set t [split $line]
      return [list [lindex $t 4] [lindex $t 5]]
    }
  }
  return "?"
}
# 0237's own fixture: mid-span label, and the WIRE is what gets selected.
proc ridescene {} {
  scene
  xschem wire 0 0 200 0
  xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
  xschem unselect_all
  xschem select wire 0
}

# V1 issue 0237's measured repro, STOCK DEFAULTS (autotrim off, so no split has ever masked it).
ridescene
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "V1 the label rides the wire (0237)"           [lp] {100 100}
check "V2 ... and no copper is invented for it"      [xschem get wires] 1
check "V3 ... the span just translated"              [spans] {{0 100 200 100}}
check "V4 ... the net keeps its name"                [xschem getprop wire 0 lab] {VOUT}
check "V5 ... and the S0 oracle scores no strand"    [st] 0

# V6 the same under the target environment (cadence_compat => autotrim_wires 1).  S2 removed the
#    split that used to mask 0237 here by putting the label on an endpoint where the tether found
#    it; the ride replaces that accident with the real rule, and the answer is now identical in
#    both configs -- which is the point.
scene
set autotrim_wires 1
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem trim_wires
check "V6 S2: still one wire at rest"                [xschem get wires] 1
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "V7 autotrim: the label rides"                 [lp] {100 100}
check "V8 ... net keeps its name"                    [xschem getprop wire 0 lab] {VOUT}
check "V9 ... no strand"                             [st] 0
set autotrim_wires 0

# V10 issue 0238's cell: `stretch` with kissing NOT armed (the keyboard entry points).  RIDE is
#     deliberately NOT gated on connect_by_kissing -- spec §8, "the rider does not need kissing
#     armed" -- which is exactly how 0238's label half closes for this direction.  The LEASH's gate
#     is untouched (K1/K2 above still pin the rigid detach), so this is not a widening of it.
ridescene
xschem move_objects 0 100 stretch
xschem resolved_net 0
check "V10 no kissing: the label still rides (0238)"  [lp] {100 100}
check "V11 ... and the net keeps its name"            [xschem getprop wire 0 lab] {VOUT}
check "V12 ... no strand"                             [st] 0

# V13 TRAP 1, the case that makes #8 and RIDE inseparable: an END-OF-STUB label sits exactly on the
#     moving wire's endpoint, so connect_by_kissing()'s wire-endpoint arm DOES see it and used to
#     mint a tether stub.  That stub is the only thing that ever held such a label -- and the
#     wire-stub-plus-netlabel idiom produces this topology far more often than the mid-span one.
#     After #8 there is no stub at all and the ride must carry it.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 0 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "V13 end-of-stub label: no tether stub"        [xschem get wires] 1
check "V14 ... the label rode instead"               [lp] {0 100}
check "V15 ... the span is untouched"                [spans] {{0 100 200 100}}
check "V16 ... the net keeps its name"               [xschem getprop wire 0 lab] {VOUT}

# V17 R3's headline claim: ROTATE the wire and the label's own ORIENTATION rotates with it.  The
#     reference is the ELEMENT commit's own result for the SAME gesture with the label selected --
#     asserting against that rather than a literal makes this a "the ride and the normal move agree"
#     claim, which is what "as in Cadence" actually means here.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all; xschem select wire 0; xschem select instance 0
xschem move_objects 0 0 1 0 -anchor 0 0 kissing
set v_rot_ref [list [lp] [rotflip l1] [spans]]
ridescene
xschem move_objects 0 0 1 0 -anchor 0 0 kissing
check "V17 rotate 90: ride == the selected-label commit" [list [lp] [rotflip l1] [spans]] $v_rot_ref
check "V18 ... and it really rotated the text"           [rotflip l1] {1 0}
check "V19 ... the label landed on the rotated span"     [lp] {0 100}

# V20 FLIP, same shape.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all; xschem select wire 0; xschem select instance 0
xschem move_objects 0 0 0 1 -anchor 0 0 kissing
set v_flip_ref [list [lp] [rotflip l1] [spans]]
ridescene
xschem move_objects 0 0 0 1 -anchor 0 0 kissing
check "V20 flip: ride == the selected-label commit"  [list [lp] [rotflip l1] [spans]] $v_flip_ref
check "V21 ... and it really flipped the text"       [rotflip l1] {0 1}

# V22 THE `+2` TERM (spec §5.3 note 3, trap 3).  The rot composition is
#       rot = (rot + (move_flip && (rot & 1) ? move_rot+2 : move_rot)) & 3
#     and a naive (rot + move_rot) & 3 differs ONLY for a label that is already at an ODD rotation
#     when a FLIP is applied.  Sweep every starting orientation against every transform and require
#     the ride to agree with the ELEMENT commit on all of them; drop the `+2` and the odd-rotation
#     flipped cells go red while every even cell stays green.
set v_plus2 0
foreach {r0 f0} {0 0 1 0 2 0 3 0 0 1 1 1 2 1 3 1} {
  foreach {mr mf} {1 0 0 1 1 1 2 1 3 1} {
    scene
    xschem wire 0 0 200 0
    xschem instance {lab_pin.sym} 100 0 $r0 $f0 {name=l1 lab=V}
    xschem unselect_all; xschem select wire 0; xschem select instance 0
    xschem move_objects 0 0 $mr $mf -anchor 0 0 kissing
    set ref [rotflip l1]
    scene
    xschem wire 0 0 200 0
    xschem instance {lab_pin.sym} 100 0 $r0 $f0 {name=l1 lab=V}
    xschem unselect_all; xschem select wire 0
    xschem move_objects 0 0 $mr $mf -anchor 0 0 kissing
    if {$ref ne [rotflip l1]} { incr v_plus2 }
  }
}
check "V22 40 orientation x transform cells all agree" $v_plus2 0

# V23 SPEC §11 HAZARD (D): an OFF-ORIGIN pin under rotation.  bus_connect.sym is a type=label symbol
#     whose pin centre is at (10,-10), so rotating it moves its pin ~28 units.  The ride must pick
#     the TARGET PIN coordinate first, apply rot/flip second and solve for the origin last;
#     translate-then-rotate slides such a label off its copper, which R7 forbids.  Assert on the
#     PIN via get_inst_pin_coord() -- the forward authority -- never on the origin.
scene
xschem wire 0 0 200 0
xschem instance {bus_connect.sym} 90 10 0 0 {name=b1}
check "V23 the off-origin pin starts on the wire"    [lrange [xschem instance_pin_coord b1 name p] 1 2] {100 0}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 0 1 0 -anchor 0 0 kissing
check "V24 rotated wire: the off-origin pin follows" [lrange [xschem instance_pin_coord b1 name p] 1 2] {0 100}
check "V25 ... and it really is on copper"           [xschem net_at 0 100] 1
check "V26 ... and no copper was invented"           [xschem get wires] 1

# V27 hazard (E): a label the user ALSO selected is moved by the ELEMENT commit.  Riding it as well
#     would move it TWICE -- silent, because a 2x delta only looks wrong when the delta is large.
ridescene
xschem select instance 0
xschem move_objects 0 100 kissing
check "V27 selected label is not moved twice"        [lp] {100 100}
check "V28 ... and the span moved once"              [spans] {{0 100 200 100}}

# V29a/V29b the two gestures where "skip a selected label" is not merely belt-and-braces. On a
#   plain rigid translate the ride's ABSOLUTE placement and the ELEMENT commit agree exactly (V27
#   is green with or without the guard, which is worth knowing: what actually prevents a DOUBLE
#   move is solving for the origin rather than accumulating into it). They disagree in two places:
#     - ROTATELOCAL (ALT-R): the ELEMENT commit turns each instance about ITS OWN origin, so a
#       selected label does not travel with the wire at all; the ride's target is on the rotated
#       wire. The user selected the label, so the commit's answer wins.
#     - a PARTIALLY selected owner: the commit gives the label the full delta, the ride would clamp
#       it onto the reshaped span.
#   These are the sabotage anchors for hazard (E): register a RIDE rider for a selected label and
#   both go red while every other case in this file stays green.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=V}
xschem unselect_all; xschem select wire 0; xschem select instance 0
xschem move_objects 0 0 1 0 local kissing
check "V29a ROTATELOCAL: the commit owns a selected label" [lp] {100 0}
check "V29b ... and the wire turned about its own end"     [spans] {{0 0 0 200}}
scene
xschem wire 0 0 200 0
xschem instance {res.sym} 0 30 0 0 {name=R1 value=1k}
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=V}
xschem unselect_all; xschem select instance 0; xschem select instance 1
xschem move_objects 0 -100 stretch kissing
check "V29c partial owner + selected label: commit wins"   [lp] {100 -100}
check "V29d ... and the owner really did reshape"          [spans] {{0 -100 200 0}}

# V29 CONSERVATION, the mirror of the whole feature: when only PART of the copper under the label
#     moves, the label stays.  It is still connected to what stayed, and carrying it off would be
#     the same strand this stage exists to stop, just in the other direction.
scene
xschem wire 0 0 200 0
xschem wire 100 0 100 200
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "V29 stationary crossing wire holds the label" [lp] {100 0}
check "V30 ... and it is not a strand"               [st] 0

# V31 the same rule for a stationary DEVICE pin under the anchor (the gnd/vdd-on-a-pin idiom).
scene
xschem wire 0 0 200 0
xschem instance {res.sym} 100 30 0 0 {name=R1 value=1k}   ;# pin P lands at (100,0)
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
check "V31 the device pin is under the anchor"       [lrange [xschem instance_pin_coord R1 name P] 1 2] {100 0}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "V32 a stationary device pin holds it too"     [lp] {100 0}

# V33 a PARTIALLY selected owner does not translate -- it changes SHAPE (spec §5.3 note 2, trap 6).
#     Dragging a device pin relays the wire into a diagonal here; the transformed anchor lands off
#     it, so the closed-form target is CLAMPED onto the final run by label_ride_project().  A
#     parametric-t-from-endpoint-1 scheme instead of the rotation form mirrors the label to the
#     wrong end (ORDER()/order_wire_points canonicalize endpoints on commit), so the literal here
#     is the measured clamp, and it must be ON the wire -- which V35 asserts independently.
scene
xschem wire 0 0 200 0
xschem instance {res.sym} 0 30 0 0 {name=R1 value=1k}      ;# pin P lands at (0,0)
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -100 stretch kissing
xschem resolved_net 0
check "V33 reshaped owner: the span really moved"    [spans] {{0 -100 200 0}}
check "V34 ... the label was clamped onto it"        [lp] {80 -60}
check "V35 ... i.e. it is on copper"                 [xschem net_at 80 -60] 1
check "V36 ... and the net keeps its name"           [xschem getprop wire 0 lab] {VOUT}
check "V37 ... no strand"                            [st] 0

# V38 every label on the moving copper rides, not just the first.
scene
xschem wire 0 0 300 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=A}
xschem instance {lab_pin.sym} 200 0 0 0 {name=l2 lab=A}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "V38 first label rode"                         [lp l1] {100 100}
check "V39 second label rode"                        [lrange [xschem instance_pin_coord l2 name p] 1 2] {200 100}
check "V40 ... and neither stranded"                 [st] 0

# V41 ABORT drops the rider set and leaves the label exactly where it started.
ridescene
xschem move_objects start 0 0 kissing stretch
xschem move_objects step 0 -50
xschem move_objects abort
check "V41 aborted ride leaves the label alone"      [lp] {100 0}
check "V42 ... and the wire too"                     [spans] {{0 0 200 0}}

# V43 SPEC §12 OPEN QUESTION 1, THE RIDE HALF -- and the reason the clamp/ride is applied LIVE
#     (§5.4) rather than only at release.  The apply now runs on every live RUBBER commit as well
#     as at the real END, so a multi-step drag must land exactly where the same drag committed in
#     one shot does.  `stretch` is REQUIRED: without it stretch_select stays 0, no fluid_reroute
#     snapshot is taken, the RUBBER live-commit gate can never fire, and the equality would hold
#     for ANY implementation, including none (the S1 lesson at N8).
#     Measured 2026-08-06: byte-identical, so live riding needs no restore of its own -- every
#     RUBBER step fluid_reroute_restore()s instances to pristine and re-derives from the total.
ridescene
xschem move_objects start 0 0 kissing stretch
xschem move_objects step 10 -20
xschem move_objects step 20 -40
xschem move_objects step 30 -60
xschem move_objects step 40 -80
xschem move_objects step 50 -100
xschem move_objects end
set v8_stepwise [list [lp] [xschem get wires] [spans]]
ridescene
xschem move_objects 50 -100 kissing stretch
check "V43 RIDE stepwise == one-shot (live commit)"  $v8_stepwise [list [lp] [xschem get wires] [spans]]
check "V44 ... and the one-shot really rode"         [lp] {150 -100}

# V45 spec §11 hazard (C): refuse/rollback and undo cover instances whole-struct, rot/flip included,
#     so a ridden AND rotated label needs no bespoke rollback.  One Ctrl-Z puts everything back.
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 0 1 0 -anchor 0 0 kissing
check "V45 rotated ride happened"                    [list [lp] [rotflip l1]] {{0 100} {1 0}}
xschem undo
check "V46 undo restores position AND orientation"   [list [lp] [rotflip l1]] {{100 0} {0 0}}
check "V47 ... and the wire"                         [spans] {{0 0 200 0}}

# V48 the ride is not part of the fluid engine (capture hangs off move START, apply off the shared
#     commit), so a default-config user with fluid_editing OFF gets it too.  Spec §12: the matrix
#     must cover both settings rather than assume the default path exercises them.
set fluid_editing 0
ridescene
xschem move_objects 0 100 stretch kissing
check "V48 fluid off: the label still rides"         [lp] {100 100}
check "V49 fluid off: no copper invented"            [xschem get wires] 1
set fluid_editing 1
file delete -force $::rfsch

# ===========================================================================
# U. THE `label_ride` SWITCH AND THE SCOPE FENCE AROUND CHANGE #8.
#    The preference owns the tether and the ride TOGETHER (they are a replacement pair), and #8 is
#    scoped to `type=label` exactly like #4 -- a device pin or a hierarchy port at a moving wire's
#    endpoint must still be tethered, or S3 would silently disconnect every one of them.
# ===========================================================================
# U1 the escape hatch restores pre-S3 BYTE-FOR-BYTE, in both topologies.  This is also the sabotage
#    variant for "#8 shipped without RIDE": with label_ride 0 the stub is back AND the ride is off,
#    which is a coherent state; half of each is the state the pairing exists to prevent.
set label_ride 0
ridescene
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0
check "U1 label_ride 0: mid-span label is left behind" [lp] {100 0}
check "U2 ... the net reverts to an auto name"         [xschem getprop wire 0 lab] {#net1}
check "U3 ... and the S0 oracle reports the strand"    [st] 1
scene
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 0 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "U4 label_ride 0: the kissing TETHER is back"    [xschem get wires] 2
check "U5 ... as the perpendicular stub"               [spans] {{0 0 0 100} {0 100 200 100}}
check "U6 ... which is what kept the label attached"   [lp] {0 0}
set label_ride 1

# U7 a hierarchy PORT at a moving wire's endpoint still kisses: inst_is_netlabel() is
#    strcmp(type,"label"), deliberately not IS_LABEL_OR_PIN, so ipin/opin/iopin keep every
#    behaviour they had.
scene
xschem wire 0 0 200 0
xschem instance {ipin.sym} 0 0 0 0 {name=p1 lab=IN}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "U7 ipin at the endpoint still kisses"         [xschem get wires] 2
check "U8 ... the tether stub is the perpendicular"  [spans] {{0 0 0 100} {0 100 200 100}}

# U9 and so does a real DEVICE pin -- the case change #8 must not touch.
scene
xschem wire 0 -100 200 -100
xschem instance {res.sym} 0 -70 0 0 {name=R1 value=1k}    ;# pin P lands at (0,-100)
check "U9 the resistor pin is on the endpoint"       [lrange [xschem instance_pin_coord R1 name P] 1 2] {0 -100}
xschem unselect_all
xschem select wire 0
xschem move_objects 0 100 stretch kissing
check "U10 device pin at the endpoint still kisses"  [xschem get wires] 2
check "U11 ... the tether stub is the perpendicular" [spans] {{0 -100 0 0} {0 0 200 0}}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
