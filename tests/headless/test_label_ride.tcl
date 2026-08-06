# RED-first regression for wire_label_ride S1 = R1 (no extruded copper) + LEASH
# (doc/claude/specs/wire_label_ride.md §7 S1; changes #1, #2, #4, #5).
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
#     across 21 shipped files sit off copper by design).  This is also the 0223 boundary --
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

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
