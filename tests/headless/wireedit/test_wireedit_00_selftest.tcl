# Phase 0.1 self-test: proves the fixtures.tcl helpers work before any TC relies
# on them. Spec: code_analysis/wire_editing_spec_and_plan.md, Phase 0.
#   DISPLAY=:0 src/xschem --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_00_selftest.tcl
source [file join [file dirname [info script]] fixtures.tcl]

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

we_result
