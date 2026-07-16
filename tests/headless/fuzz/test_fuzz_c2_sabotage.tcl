# Hardening sprint Track C / step C2 -- SABOTAGE tests for the fuzzer assertion pack.
# Spec: doc/claude/suggestions/hardening_sprint_plan.md (C2); [[green-but-hollow]].
#
# The assertion pack is worthless if a check cannot go RED. This proves every check has TEETH:
# for each, the check PASSES on a clean state and FAILS when the specific defect it targets is
# injected. Seven checks (the plan's "five" -- P1/P2 electrical is a 3-check bundle):
#   P1_connectivity   -- a real saved net merge (partition changes)
#   P2_no_dev_merge   -- the same merge collapses a device's two pins
#   P2_labels_survive -- a named net vanishes from the wire nets
#   Q_manhattan       -- a diagonal wire appears
#   Q_no_dangling     -- a wire endpoint touching no pin and no wire appears
#   Q_no_body_cross   -- a wire plows through a device body between non-pin points
#   Q_copper_budget   -- total copper grows far beyond k*(|dx|+|dy|)+slack
#
# True headless:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/fuzz/test_fuzz_c2_sabotage.tcl
source [file join [file dirname [info script]] harness.tcl]

# ---- P1 + P2-device: a REAL saved short (named rail, enforcement OFF) -----------------------
# before_8 + a lab_pin VDD on the backbone -> the 0105 drag's device short is unrepairable and,
# with enforcement OFF, SAVES: R18.P(#net3) merges into VDD. That changes the partition (P1)
# and collapses R18's two pins (P2-device). Faithful corruption, not an injected wire.
fuzz_load before_8
xschem instance devices/lab_pin -200 -40 0 0 {name=lvdd lab=VDD}
set fluid_enforce_invariants 0
set snap [fuzz_snapshot]
check "P1/P2 baseline: partition preserved + no dev merge on the UN-moved fixture" \
  [expr {[fuzz_partition_preserved [dict get $snap part]] && [p2_no_device_merge [dict get $snap p2]]}]
_fuzz_select R18
xschem move_objects -90 -40 stretch kissing
check "P1_connectivity has teeth: the saved merge changes the partition (check FIRES)" \
  [expr {![fuzz_partition_preserved [dict get $snap part]]}]
check "P2_no_dev_merge has teeth: R18's two pins merged (check FIRES)" \
  [expr {![p2_no_device_merge [dict get $snap p2]]}]

# ---- P2-labels-survive: a named net disappears --------------------------------------------
# Snapshot with VDD present, then remove the lab_pin so the backbone reverts to #net -> VDD is
# gone from the wire nets while the snapshot still lists it as an intended label.
fuzz_load before_8
xschem instance devices/lab_pin -200 -40 0 0 {name=lvdd lab=VDD}
set labs [fuzz_label_nets]
check "P2_labels_survive baseline: VDD present -> survives" [fuzz_labels_survive $labs]
xschem unselect_all; xschem select instance lvdd; xschem delete
check "P2_labels_survive has teeth: VDD vanished from the wire nets (check FIRES)" \
  [expr {![fuzz_labels_survive $labs]}]

# ---- Q_manhattan: inject a diagonal wire ---------------------------------------------------
fuzz_load before_3
set d0 [fuzz_count_diag]
check "Q_manhattan baseline: fixture is all-Manhattan (no novel diagonal)" [fuzz_no_novel_diag $d0]
xschem wire 200 200 260 230        ;# a diagonal (dx=60, dy=30)
check "Q_manhattan has teeth: the injected diagonal is caught (check FIRES)" \
  [expr {![fuzz_no_novel_diag $d0]}]

# ---- Q_no_dangling: inject a floating wire -------------------------------------------------
fuzz_load before_3
set e0 [fuzz_dangling_eps]
check "Q_no_dangling baseline: no novel dangling end" [fuzz_no_novel_dangling $e0]
xschem wire 300 300 350 300        ;# isolated: both ends touch no pin, no wire
check "Q_no_dangling has teeth: the injected floating end is caught (check FIRES)" \
  [expr {![fuzz_no_novel_dangling $e0]}]

# ---- Q_no_body_cross: inject a wire through a device body ----------------------------------
# before_3 R18 at (-400,-40) rot0 flip1: a horizontal stab across its body-centre ROW (y=-40),
# which is OFF the pin rows (pins at y=-70/-10), with endpoints outside the body. (A vertical
# stab through the centre COLUMN would land on the pin column and autotrim splits it into an
# exempt pin-to-pin segment -- the row avoids that.)
fuzz_load before_3
set g0 [segset]
check "Q_no_body_cross baseline: no novel copper through any body" [fuzz_no_novel_body_cross $g0]
lassign [_inst_symbol_box_world R18] bx1 by1 bx2 by2
set cy [expr {($by1+$by2)/2}]     ;# body-centre row (not a pin row)
xschem wire [expr {$bx1-20}] $cy [expr {$bx2+20}] $cy
check "Q_no_body_cross has teeth: the injected through-body wire is caught (check FIRES)" \
  [expr {![fuzz_no_novel_body_cross $g0]}]

# ---- Q_copper_budget: inject a huge length -------------------------------------------------
fuzz_load before_3
set l0 [route_length]
check "Q_copper_budget baseline: no growth is within budget" [fuzz_within_budget $l0 0 10]
xschem wire 1000 1000 1000 5000    ;# +4000 units, dwarfs k*(|0|+|10|)+100 = 130
check "Q_copper_budget has teeth: the injected 4000-unit wire blows the budget (check FIRES)" \
  [expr {![fuzz_within_budget $l0 0 10]}]

we_result
