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
# ORIGINAL baseline (2026-07-05, pre-enforcement fast path): the drag DID short -- pin M lands on
# net B's end and the netlister merged NETA+NETB (P2 = RED). The comment predicted: "when the
# no-short guard lands, P2 flips GREEN and this fixture fails on purpose -> update the baseline."
# 2026-07-11 (hardening Track B, B3): that guard landed as the END enforcement gate. NETB is a
# NAMED net (lab_pin), so every de-shorter blackouts on it (fluid_wire_explicit_lab) and the short
# is unrepairable; the enforcement gate now REFUSES the whole move (fluid_check_move_invariants ->
# rollback-or-refuse) and restores RA to its pristine position -- NETA and NETB stay distinct
# because the merging move never commits. Baseline updated RED -> GREEN as instructed.
#   P2 = GREEN -- p2_no_short: the move is refused, so NETB survives as its own wire net.
#   P1 = GREEN -- geometry is byte-identical to pre-gesture (refuse restored pristine).
#   P4 = GREEN -- pristine is axis-aligned.
# (P1/P2 remain complementary in general -- P1 catches disconnects, P2 catches merges; here both
# read GREEN because the refuse leaves the pristine, already-distinct scene.)
pred_verdict "F5.P1 connectivity invariant" [p1_netlist_invariant $snap] GREEN
pred_verdict "F5.P2 no-short (NETA vs NETB)" [p2_no_short]               GREEN
pred_verdict "F5.P4 orthogonality"           [p4_orthogonal]             GREEN

we_result
