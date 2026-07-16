# Phase IV P6 (min-bend) -- doc/claude/specs/incremental_wire_reroute.md sec8 / nice_drag_rerouting sec4.
#
# The fluid escape (P3) was implemented as insert_exit_stubs(): when a follow wire's pin-incident leg
# is PERPENDICULAR to the pin's escape normal, it slides that leg one grid out and drops a short
# perpendicular exit stub -- a STAIRCASE (pin -> tiny stub -> perpendicular leg -> ...), a redundant
# bend at IDENTICAL manhattan length. P6 removes it: place_moved_wire() now BIASES the L orientation
# so the pin-incident leg exits ALONG the escape normal (a straight P3 exit); insert_exit_stubs then
# SKIPS it (a leg colinear with the normal is left alone, move.c:1648-1649). Same length, one fewer
# bend -- and where the anchor's continuation is colinear with the along-normal arrival, even fewer
# bends AND shorter (cont=right).
#
# Conflict order P1=P2 > P3 > P5 > P4 > P7 > P6: P6 acts ONLY in the both-orientations-P2-clear arm
# (a P2 obstacle flip dominates; a both-blocked case is left to the Layer-2 reroute), only when the
# anchor is on the OUTWARD-normal side (an away escape is a genuine P3-mandated stub -- kept), and
# stands down for an explicit wire_exit_stub preference. In the perpendicular, non-kissed case length
# does not increase (both L orientations have identical |dx|+|dy|; the anchor + pin-corridor vetoes
# decline the cases where one orientation dedups a stationary wire the other does not). Two pre-existing
# quality exceptions are OUT OF SCOPE -- they reproduce on the guard-free and pre-P6 binaries and break
# NO correctness predicate (P1/P2/P4/P5 all hold): a stationary corridor wire that CROSSES the pin
# becomes a kissed (.sel) follow wire the stationary-only veto cannot see; and diagonal drags (issue
# 0081, per-axis decomposition).
#
# RED-first: the Group-A bend counts are the pre-fix STAIRCASE + 1 (fluid @ HEAD lays 2/3 bends where
# P6 now lays 1/0). GROUP B are the decline/no-regression anchors (byte-identical off, veto, away,
# wire_exit_stub, bare-wire) plus release==stepwise. Sabotage: force the pre-fix orientation (revert
# the bias) and the Group-A bend asserts flip RED.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_39_p6_min_bend.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc ix {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
# the user's cadence launch gates (cadence_compat forces autotrim); wire_exit_stub default OFF.
proc G {fluid {stub 0}} {
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  uplevel #0 [list set fluid_editing $fluid]
  uplevel #0 [list set wire_exit_stub $stub]
}
# +y-normal res RA at origin, follow wire M(0,30)->anchor(0,130), optional same-net continuation
# leaving the anchor, then a perpendicular +x drag of RA. dir in {none,up,down,left,right}.
proc build_plusY {dir} {
  xschem clear force
  xschem instance devices/res 0 0 0 0 {name=RA}                 ;# P(0,-30) M(0,30) normal +y
  xschem wire 0 30 0 130
  xschem instance devices/lab_pin 0 130 0 0 {name=LA lab=NA}
  switch $dir {
    up    { xschem wire 0 130 0 200 }
    down  { xschem wire 0 60 0 130 }
    left  { xschem wire -70 130 0 130 }
    right { xschem wire 0 130 70 130 }
  }
}

# ============================ GROUP A -- P6 improves (RED @ HEAD) ============================
# each: [dir expect_bends expect_len]. HEAD(fluid) bends noted in comments.
foreach {dir eb el head} {
  none  1 160 2
  left  1 230 3
  right 0 170 3
} {
  G 1
  build_plusY $dir
  set snap [net_snapshot]
  xschem unselect_all; xschem select instance [ix RA]
  we_move_stretch 60 0
  check "A:$dir bends=$eb (HEAD fluid staircase=$head)" [expr {[route_bends] == $eb}]
  check "A:$dir length=$el (never increases)"           [expr {[route_length] == $el}]
  check "A:$dir P1 connectivity"                        [p1_netlist_invariant $snap]
  check "A:$dir P2 no-short"                            [p2_no_short]
  check "A:$dir P3 escape-perpendicular (straight exit)" [p3_escape_perp RA 10]
  check "A:$dir P4 orthogonal"                          [p4_orthogonal]
}

# A4 -- ROTATION invariance: res rot1, pin M(-30,0) normal -x, follow left to anchor(-130,0),
# perpendicular +y drag. HEAD fluid = 2-bend staircase; P6 = 1-bend straight -x exit.
G 1
xschem clear force
xschem instance devices/res 0 0 1 0 {name=RA}                   ;# rot1: M(-30,0) normal -x, P(30,0) +x
xschem wire -30 0 -130 0
xschem instance devices/lab_pin -130 0 0 0 {name=LA lab=NA}
set snap [net_snapshot]
xschem unselect_all; xschem select instance [ix RA]
we_move_stretch 0 60
check "A:rot -x-normal bends=1 (HEAD staircase=2)" [expr {[route_bends] == 1}]
check "A:rot -x-normal length=160"                 [expr {[route_length] == 160}]
check "A:rot -x-normal straight exit present (-130,0)-(-130,60)" [has_seg -130 0 -130 60]
check "A:rot P1"  [p1_netlist_invariant $snap]
check "A:rot P3"  [p3_escape_perp RA 10]

# ============================ GROUP B -- decline / no regression ============================

# B1 default-off BYTE-IDENTICAL: fluid=0 lays the pre-fix perpendicular route, untouched by P6.
G 0
build_plusY none
xschem unselect_all; xschem select instance [ix RA]
we_move_stretch 60 0
check "B:off segset == pre-fix perpendicular route" \
  [expr {[segset] eq [lsort [list [we_norm {0 30 0 130}] [we_norm {0 30 60 30}]]]}]

# B2 VETO decline: a stationary along-normal (vertical) continuation at the anchor -- the perpendicular
# baseline arrival merges it, so P6 declines to baseline (no bend gain possible; P3 needs 2 bends here).
# No regression vs HEAD fluid (also 2). This is the fluid_anchor_absorbs_along_normal length veto.
G 1
build_plusY up
set snap [net_snapshot]
xschem unselect_all; xschem select instance [ix RA]
we_move_stretch 60 0
check "B:veto(cont=up) declines -> 2 bends (no regression)" [expr {[route_bends] == 2}]
check "B:veto P1" [p1_netlist_invariant $snap]
check "B:veto P2" [p2_no_short]
check "B:veto P3 (the escape is still perpendicular)" [p3_escape_perp RA 10]

# B3 wire_exit_stub explicit -> P6 stands down, the literal stub is preserved (protects test_29's
# insert_exit_stubs unordered-coordinate disconnect guard).
G 1 1
build_plusY none
xschem unselect_all; xschem select instance [ix RA]
we_move_stretch 60 0
check "B:wire_exit_stub on -> literal +y stub kept (60,30)-(60,40)" [has_seg 60 30 60 40]
check "B:wire_exit_stub on -> 2 bends (P6 stood down)" [expr {[route_bends] == 2}]

# B4 BARE wire (moved endpoint is not on any instance pin -> no escape normal -> P6 declines).
G 1
xschem clear force
xschem wire 0 0 0 100
xschem wire 0 100 100 100
xschem unselect_all; xschem select wire 0
we_move_stretch 40 0
check "B:bare-wire drag unchanged (no pin normal)" \
  [expr {[segset] eq [lsort [list [we_norm {40 0 40 100}] [we_norm {40 100 100 100}]]]}]

# ============================ release == stepwise (P8 determinism) ============================
# Drive the cont=none improvement one snap-grid at a time, then once at the total delta; the committed
# geometry must be identical (P6 is a pure function of snapshot+total-delta+geometry).
G 1
build_plusY none
xschem unselect_all; xschem select instance [ix RA]
xschem move_objects start 0 0 kissing stretch
for {set s 10} {$s <= 60} {incr s 10} { xschem move_objects step $s 0 }
xschem move_objects end 60 0
set segStep [segset]
G 1
build_plusY none
xschem unselect_all; xschem select instance [ix RA]
we_move_stretch 60 0
set segRelease [segset]
check "release == stepwise: cont=none P6 route identical both ways" [expr {$segStep eq $segRelease}]
check "release == stepwise: is the 1-bend route" [expr {[route_bends] == 1}]

# ============ GROUP C -- adversarial review regressions (wf_6e97238b, all RED @ 503189ff) ============

# C1 -- P5 body cross (P5 > P6): a STATIONARY foreign device (res RX, rot1) sits on the along-normal
# leg's column x=60; RX's pins lie OFF x=60 so the P2-clear gate sees no short, but the straight exit
# would drive through RX's body. The fix (fluid_seg_crosses_stationary_body) must DECLINE -> keep the
# P5-clean baseline. RED @ 503189ff: fluid=1 laid {60 30 60 130} through RX, p5_no_body_cross -> 0.
G 1
xschem clear force
xschem instance devices/res 0 0 0 0 {name=RA}
xschem wire 0 30 0 130
xschem instance devices/lab_pin 0 130 0 0 {name=LA lab=NA}
xschem instance devices/res 60 80 1 0 {name=RX}            ;# stationary body straddling x=60
set snap [net_snapshot]
xschem unselect_all; xschem select instance [ix RA]
we_move_stretch 60 0
check "C1:P5 no body cross (declined the body-crossing straight exit)" [p5_no_body_cross]
check "C1:P5 the along-normal leg through RX is NOT present"           [expr {![has_seg 60 30 60 130]}]
check "C1:P1"                                                          [p1_netlist_invariant $snap]
check "C1:P2"                                                          [p2_no_short]

# C2 -- length: a STATIONARY wire lies along the BASELINE perpendicular pin-leg (pin row y=30); the
# baseline horizontal leg dedups its overlap, the along-normal route does not, so biasing only adds
# copper for 0 bend gain. fluid_perp_pinleg_absorbs must DECLINE. RED @ 503189ff: fluid=1 len 480.
G 1
xschem clear force
xschem instance devices/res 0 0 0 0 {name=RA}
xschem wire 0 30 0 130
xschem instance devices/lab_pin 0 130 0 0 {name=LA lab=NA}
xschem wire 20 30 300 30                                   ;# stationary wire on the pin's escape row
xschem unselect_all; xschem select instance [ix RA]
we_move_stretch 100 0
# (no P1-invariant assert: dragging pin M onto the stationary wire legitimately kisses/merges it, a
#  connectivity change that both baseline and P6 share -- the point here is length + no short.)
check "C2:length not inflated (declined the 0-bend-gain bias)" [expr {[route_length] == 400}]
check "C2:P2 no-short" [p2_no_short]

# C3 -- pin binding: cornerpin.sym has two pins on PERPENDICULAR edges within cadsnap/2 at cadsnap=30
# (a(30,40) normal +y declared 2nd, b(40,30) normal +x declared 1st, ~14 apart). The follow wire is on
# pin a; the fix's EXACT pin match must read a's +y normal (not b's +x, the tolerance/first-match bug),
# so the route stays the clean 1-bend baseline. RED @ 503189ff: fluid=1 -> 220/2-bend (wrong normal).
G 1
uplevel #0 {set cadsnap 30}                                ;# AFTER G (which sets cadsnap 10); pins a,b ~14 apart < cadsnap/2=15
xschem clear force
xschem instance [file join [file dirname [info script]] cornerpin.sym] 0 0 0 0 {name=X1}
xschem wire 30 40 130 40
xschem unselect_all; xschem select instance 0
we_move_stretch 0 60
check "C3:pin-binding exact match -> clean 1-bend route (not the wrong-normal staircase)" \
  [expr {[route_bends] == 1 && [route_length] == 160}]
uplevel #0 {set cadsnap 10}

we_result
