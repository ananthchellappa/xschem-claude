# F5 (nice_drag_rerouting §7 fixture matrix) -- two adjacent nets, drag TOWARD: the no-short
# hazard case for P2. Spec §8 PREDICTS F5 is RED (the fast path can silently merge two nets);
# Phase 0 is assert-only, so this fixture RECORDS the actual GREEN/RED verdict via
# pred_verdict and pins the baseline to OBSERVED reality (not to the spec's guess). When
# Phase 4 (no-short guard + rip-up) lands, a RED->GREEN flip fails here on purpose, prompting
# a baseline update.
#
# Fixture: net A = resistor RA (pin M at (0,30)) + a wire up to a NETA label; net B = a
# parallel vertical wire 40 units to the right with a NETB label. Dragging RA by +40 in x
# brings pin M onto net B's lower endpoint -- the canonical silent short (kissing connects a
# dragged pin to whatever net it lands on). A "nice" reroute must keep NETA and NETB distinct.
#
# Net-label instances get UNIQUE names (LA/LB): lab_pin.sym's template name is `p1`, so two
# unnamed labels would collide and instance_nodemap would read the same instance twice,
# defeating p2's intended-vs-resolved net comparison.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_22_F5_no_short.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}

# --- build: two adjacent, distinct nets ------------------------------------
we_reset 1 1
set cadence_compat 1
set autotrim_wires 1
set fluid_editing  1

xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}   ;# pins P(0,-30) M(0,30)
xschem wire 0 30 0 130
xschem instance {lab_pin.sym} 0 130 0 0 {name=LA lab=NETA}   ;# net A

xschem wire 40 30 40 130                                     ;# net B, 40 units to the right
xschem instance {lab_pin.sym} 40 130 0 0 {name=LB lab=NETB}

check "F5: two distinct nets before the move" [nets_distinct 0 1]
set snap [net_snapshot]

# --- drag net A's device toward net B (+40 x) ------------------------------
set ra [inst_by_name RA]
check "F5: RA located" [expr {$ra >= 0}]
xschem unselect_all
xschem select instance $ra
we_move_stretch 40 0                                          ;# pin M 0,30 -> 40,30 (onto net B)

# --- record the predicate verdicts (assert-only, baseline pinned to reality) ---
# OBSERVED (2026-07-05, today's fast path): the drag DOES short -- pin M lands on net B's end
# and the netlister merges NETA+NETB into one physical net (all wires resolve to NETA; NETB's
# name vanishes). Recorded baseline:
#   P2 = RED   -- p2_no_short catches it: the intended net NETB no longer appears as a wire net.
#   P1 = GREEN -- and this is the point of having BOTH: instance_nodemap ECHOES each label's
#                 own lab= (LB still reports NETB), so the node-map snapshot is unchanged and
#                 P1 is BLIND to a merge. P1 catches disconnects; P2 catches merges. F5 is the
#                 fixture that proves they are complementary, not redundant.
#   P4 = GREEN -- every leg stays axis-aligned.
# Spec §8 predicted F5 RED (on the no-short axis) -- CONFIRMED for P2. When Phase 4 lands the
# no-short guard, P2 flips GREEN and this fixture fails on purpose -> update the baseline.
pred_verdict "F5.P1 connectivity invariant" [p1_netlist_invariant $snap] GREEN
pred_verdict "F5.P2 no-short (NETA vs NETB)" [p2_no_short]               RED
pred_verdict "F5.P4 orthogonality"           [p4_orthogonal]             GREEN

we_result
