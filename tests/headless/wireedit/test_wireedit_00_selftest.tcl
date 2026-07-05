# Phase 0.1 self-test: proves the fixtures.tcl helpers work before any TC relies
# on them. Spec: doc/claude/code_analysis/wire_editing_spec_and_plan.md, Phase 0.
#   DISPLAY=:0 src/xschem --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_00_selftest.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

# --- build a known fixture: a device + two colinear wires up pin M ---------
we_reset 0 0
we_device 0 0                 ;# pins P(0,-30) M(0,30)
we_wire 0 30 0 130            ;# on pin M
we_wire 0 130 0 230           ;# colinear continuation, meeting wire 0 at (0,130)
check "device placed (res.sym resolved)" [expr {[xschem get instances] == 1}]
check "two wires built" [expr {[xschem get wires] == 2}]

# --- segset round-trips the build, endpoint-order-independent --------------
check "segset size is 2" [expr {[llength [segset]] == 2}]
check "has_seg finds wire 0 (given reversed)" [has_seg 0 130 0 30]
check "has_seg finds wire 1" [has_seg 0 130 0 230]
check "has_seg rejects an absent segment" [expr {![has_seg 5 5 6 6]}]
# we_norm is idempotent and order-independent
check "we_norm order-independent" \
  [expr {[we_norm {0 130 0 30}] eq [we_norm {0 30 0 130}]}]

# --- net helpers: labeled nets resolve and distinguish ---------------------
# Use explicit labels for unambiguous net identity (unlabeled wire-to-wire
# propagation is not what we are testing here).
we_reset 0 0
we_wire 0 0 0 100
we_label 0 0 NETA            ;# wire 0 -> net NETA
we_wire 500 0 500 100
we_label 500 0 NETB          ;# wire 1 -> net NETB
check "we_net resolves a labeled net" [string match *NETA [we_net 0]]
check "differently-labeled wires are distinct nets" [nets_distinct 0 1]
check "netcount sees 2 nets" [expr {[netcount] == 2}]
# a third wire sharing NETA's label is the SAME net (not distinct from wire 0)
we_wire 0 0 -100 0
we_label -100 0 NETA
check "same-label wire shares the net" [expr {![nets_distinct 0 2]}]

# --- predicate library self-tests: p1/p4/p7 must have teeth -----------------
# Each predicate gets a POSITIVE case (holds when it should) and a SABOTAGE case
# (fails when the invariant is violated), per the green-but-hollow discipline.

# P1 -- connectivity invariant. A connectivity-preserving stretch move keeps the
# net map; a rigid move that tears a pin off its wire changes it.
we_reset 1 1
xschem instance {res.sym} 0 0 0 0 {name=R7}   ;# pins P(0,-30) M(0,30)
we_wire 0 30 0 130                             ;# wire on pin M
we_label 0 130 NETM                            ;# give the net a definite name
set p1snap [net_snapshot]
xschem unselect_all; xschem select instance 0
we_move_stretch 40 0                           ;# wire follows the pin -> connectivity kept
check "p1 holds under a connectivity-preserving stretch move" [p1_netlist_invariant $p1snap]
we_reset 1 1
xschem instance {res.sym} 0 0 0 0 {name=R7}
we_wire 0 30 0 130
we_label 0 130 NETM
set p1snap2 [net_snapshot]
xschem unselect_all; xschem select instance 0
we_move 40 0                                   ;# rigid move: wire stays, pin M leaves it
check "p1 detects a disconnect (rigid move tears pin off wire)" \
  [expr {![p1_netlist_invariant $p1snap2]}]

# P2 -- no-short. Holds for two separate labeled nets; a short (two differently-named
# labels forced onto one wire = one physical net) makes the loser's name vanish -> RED.
we_reset 0 0
xschem wire 0 0 0 100
xschem instance {lab_pin.sym} 0 0 0 0 {name=LA lab=NETA}
xschem wire 300 0 300 100
xschem instance {lab_pin.sym} 300 0 0 0 {name=LB lab=NETB}
check "p2 holds for two separate nets" [p2_no_short]
we_reset 0 0
xschem wire 0 0 0 100
xschem instance {lab_pin.sym} 0 0   0 0 {name=LA lab=NETA}
xschem instance {lab_pin.sym} 0 100 0 0 {name=LB lab=NETB}   ;# both on the one wire = short
check "p2 detects a short (two labels, one net, has teeth)" [expr {![p2_no_short]}]
# seg_touch primitive: crossing/collinear touch vs a clear gap
check "seg_touch: crossing segments touch"   [seg_touch {0 0 100 0} {50 -50 50 50}]
check "seg_touch: collinear abutting touch"  [seg_touch {0 0 50 0} {50 0 100 0}]
check "seg_touch: parallel-but-apart do not" [expr {![seg_touch {0 0 100 0} {0 40 100 40}]}]
check "seg_touch: disjoint do not"           [expr {![seg_touch {0 0 10 0} {90 0 100 0}]}]

# P6 -- minimality metrics. route_length sums legs; route_bends counts perpendicular corner
# vertices only (not collinear splits, not T-junctions); p6_bends_len compares lexicographically.
we_reset 0 0
xschem wire 0 0 0 100                            ;# V, len 100
xschem wire 0 100 50 100                         ;# H, len 50; L corner at (0,100)
check "route_length sums leg lengths"      [expr {[route_length] == 150}]
check "route_bends counts an L corner"     [expr {[route_bends] == 1}]
check "p6 holds vs equal reference"        [p6_bends_len 1 150]
check "p6 holds vs looser reference"       [p6_bends_len 2 0]
check "p6 fails vs fewer-bend reference"   [expr {![p6_bends_len 0 999]}]
check "p6 fails vs equal-bend shorter ref" [expr {![p6_bends_len 1 100]}]
we_reset 0 0
xschem wire 0 0 0 100
xschem wire 0 100 0 200                          ;# collinear continuation
check "route_bends: collinear split is 0 bends" [expr {[route_bends] == 0}]
we_reset 0 0
xschem wire -50 0 50 0                            ;# H through
xschem wire 0 0 0 100                             ;# V ending mid-span of the H wire (T-junction)
check "route_bends: T-junction is 0 bends" [expr {[route_bends] == 0}]

# P4 -- orthogonality. Holds for axis-aligned wires, fails on a diagonal.
we_reset 0 0
we_wire 0 0 0 100
check "p4 holds for axis-aligned wires" [p4_orthogonal]
we_wire 0 0 50 100                             ;# a diagonal leg
check "p4 detects a diagonal (has teeth)" [expr {![p4_orthogonal]}]

# P5 -- no body crossing. Pin stubs (endpoint ON a pin) are exempt though they dip into the
# bbox; a wire ploughing straight through the body with neither endpoint on a pin is flagged.
we_reset 0 0
xschem instance devices/res 0 0 0 0 {name=RA}   ;# pins P(0,-30) M(0,30), body ~x[-17,41] y[-32.5,32.5]
xschem wire 0 30 0 130                           ;# pin M stub up (exempt)
xschem wire 0 -30 0 -130                         ;# pin P stub down (exempt)
check "p5 holds: pin stubs are not body crossings" [p5_no_body_cross]
xschem wire -100 0 100 0                          ;# straight through the body, no pin endpoint
check "p5 detects a wire through the body (has teeth)" [expr {![p5_no_body_cross]}]

# P7 -- stability. An unrelated wire must survive untouched; a segment that was
# translated wholesale must NOT pass as stable. Rigid-move one wire and assert its
# OLD position is gone while the other is intact.
we_reset 0 0
we_wire 0 0 100 0                              ;# wire 0 -- will be translated
we_wire 300 0 300 100                          ;# wire 1 -- untouched
xschem unselect_all; xschem select wire 0
we_move 0 40                                   ;# wire 0: y=0 -> y=40
check "p7 holds: the untouched wire survives" [p7_stability {{300 0 300 100}}]
check "p7 detects a moved 'stable' wire (has teeth)" \
  [expr {![p7_stability {{0 0 100 0}}]}]

we_result
