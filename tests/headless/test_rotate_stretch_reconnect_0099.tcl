# issue 0099: rotate/flip DURING a connected stretch must not short/disconnect the follow wires.
#
# Repro (tests/from_user/before_7.sch -> after_17.sch): select R18 (a res, pins P=#net2, M=#net1),
# press 'm' (connected stretch), rotate 90 (ALT-R) mid-drag, drop at delta (30,20). R18's two pins
# swap spatial arrangement under the rotation, so place_moved_wire's elbow for the P-follow wire can
# route straight through M's NEW (rotated) position -- a self-short. The elbow hazard picker
# (fluid_ml_hazards) was rotation-blind: it tested a co-moving sibling pin at pre-move-coord+delta
# (translation only), missed M's rotated landing, scored the shorting orientation "clean", and picked
# it. Symptom in the saved file: R18.P and R18.M shorted (both on #net2), or both torn onto fresh nets
# #net4/#net5, and C12's #net2 backbone split off.
#
# Fix (src/move.c fluid_ml_hazards): apply ROTATION(pivot)+delta to a co-moving pin (so a rotated
# sibling pin is tested at its TRUE post-move position) and invert the rotation to recover M's true
# pre-move net. Byte-identical on the translation path (move_rot==0 && move_flip==0 skips both).
#
# Discriminator: the ELECTRICAL PARTITION is preserved for EVERY orientation -- R18.P stays on C12's
# #net2, R18.M on the #net1 subtree, and the two stay DISTINCT. Before the fix the 90-deg case shorts
# (built-in P1/P2 invariant printer fires "device short/merge").
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_rotate_stretch_reconnect_0099.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- 0099 rotate-stretch test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}

set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256 ; set ShiftMask 1
set KSYM_m 109 ; set KSYM_R 82 ; set KSYM_F 70

proc screen {chx chy} {   ;# schematic -> callback coords (inverse of xschem's x*zoom-xorigin)
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($chx+$xo)/$zm)}] [expr {int(($chy+$yo)/$zm)}]
}
proc find_inst {name} {
  set n [xschem get instances]
  for {set i 0} {$i<$n} {incr i} { if {[xschem getprop instance $i name] eq $name} { return $i } }
  return -1
}
proc pinnet {inst pin} { lindex [xschem instance_nodemap $inst $pin] 2 }  ;# "R18 P <net>" -> <net>

set ::HERE [file dirname [file normalize [info script]]]

proc load_fixture {} {
  xschem load [file join $::HERE .. from_user before_7.sch]
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0
  set ::cadence_compat 1
  xschem set fluid_editing 1
  set ::orthogonal_wiring 1
  xschem zoom_full; update idletasks
}

# connected stretch on R18, apply `nrot` ALT-R (and `doflip` ALT-F), drop at schematic delta (dx,dy)
# about pivot (-120,-80) = R18 body center. Returns nothing; caller probes the partition.
proc gesture {nrot doflip dx dy} {
  global WIN KP BP BR MOTION Button1Mask ShiftMask KSYM_m KSYM_R KSYM_F
  set r18 [find_inst R18]
  lassign [screen -120 -80] sx sy
  lassign [screen [expr {-120+$dx}] [expr {-80+$dy}]] tx ty
  xschem unselect_all; xschem select instance $r18
  xschem callback $WIN $KP $sx $sy $KSYM_m 0 0 0
  for {set i 0} {$i<$nrot} {incr i} { xschem callback $WIN $KP $sx $sy $KSYM_R 0 0 $ShiftMask }
  if {$doflip} { xschem callback $WIN $KP $sx $sy $KSYM_F 0 0 $ShiftMask }
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP $tx $ty 0 1 0 0
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

# true iff R18's electrical partition is preserved (P on #net2 w/ C12, M on #net1, distinct).
proc partition_ok {} {
  set p [pinnet R18 P]; set m [pinnet R18 M]
  if {$p ne "#net2" || $m ne "#net1" || $p eq $m} { return 0 }
  set shared 0
  foreach {pin net} [lrange [xschem instance_nodemap C12] 1 end] { if {$net eq $p} { set shared 1 } }
  return $shared
}
# Assert the electrical partition is preserved after a gesture variant.
proc check_partition {label} {
  set p [pinnet R18 P]; set m [pinnet R18 M]
  check "$label: R18.P on #net2 (C12 side)" [expr {$p eq "#net2"}]
  check "$label: R18.M on #net1"            [expr {$m eq "#net1"}]
  check "$label: R18.P and R18.M NOT shorted" [expr {$p ne $m && $p ne "" && $m ne ""}]
  set shared 0
  foreach {pin net} [lrange [xschem instance_nodemap C12] 1 end] { if {$net eq $p} { set shared 1 } }
  check "$label: C12 still shares R18.P net (#net2 backbone intact)" $shared
}

# baseline partition (no gesture)
load_fixture
check "fixture has R18" [expr {[find_inst R18] >= 0}]
check "pre: R18.P=#net2" [expr {[pinnet R18 P] eq "#net2"}]
check "pre: R18.M=#net1" [expr {[pinnet R18 M] eq "#net1"}]

# --- Fixed by issue 0099: rotations/flips where a clean (non-crossing) L exists for each follow wire.
#     The rotation-aware fluid_ml_hazards picks the orientation that avoids the co-moving sibling pin.
load_fixture; gesture 1 0 30 20 ; check_partition "rot90"      ;# the reported case (after_17)
load_fixture; gesture 0 1 30 20 ; check_partition "flip"
load_fixture; gesture 1 1 30 20 ; check_partition "rot90+flip"

# --- issue 0102 (was the documented known limitation): rot180 / rot270 swap R18's two pins so the
#     follow routes must CROSS -- no clean L per wire exists. The P2 safety net (attempt loop) is now
#     ARMED under a rotated/flipped fluid stretch: a partition-changing ortho route rolls back and
#     the follow wires relay as rigid diagonals landing exactly on the rotated pins. Structural
#     asserts (auto #netN names can drift with wire creation order under the relay).
foreach {lbl nrot} {rot180 2 rot270 3} {
  load_fixture; gesture $nrot 0 30 20
  set p [pinnet R18 P]; set m [pinnet R18 M]
  check "$lbl: R18.P and R18.M distinct + non-empty" [expr {$p ne $m && $p ne "" && $m ne ""}]
  set c12nets {}
  foreach {pin net} [lrange [xschem instance_nodemap C12] 1 end] { lappend c12nets $net }
  check "$lbl: R18.P still shares a C12 pin net" [expr {[lsearch -exact $c12nets $p] >= 0}]
  check "$lbl: C12 pins on distinct nets (no C12 self-short)" \
        [expr {[lindex $c12nets 0] ne [lindex $c12nets 1]}]
}

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS (21 checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
