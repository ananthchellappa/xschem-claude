# issue 0100: ALT-R (rotate-IN-PLACE, ROTATE|ROTATELOCAL) during a connected stretch must not tear
# the follow wires off the pins.
#
# Repro (tests/from_user/before_7.sch -> after_18.sch): select R18, press 'm' (cadence connected
# stretch), drag, press ALT-R mid-drag (the REAL user key -- keysym r + Mod1, callback.c:5100 issues
# move_objects(ROTATE|ROTATELOCAL)), KEEP dragging, drop at delta (40,20). Under rotatelocal the
# commit block rotates the instance about ITS OWN origin (pins land right) but each partial-selected
# follow wire about THE WIRE'S OWN (x1,y1) (move.c:5575) -- a pivot unrelated to the pin -- so both
# follow-wire endpoints land off-pin: R18.P/M end on fresh #net4/#net5 (disconnect, NOT a short).
# The 0099 test drove Shift-R (plain global-pivot ROTATE) and stayed green: green-but-hollow.
#
# Fix (src/move.c): under a rotatelocal fluid stretch a partial-selected follow wire rotates its
# moving endpoint about the OWNING selected instance's origin (the same pivot the ELEMENT commit
# uses), so it lands ON the pin by construction; fluid_ml_hazards gets the pristine pre-move endpoint
# handed down (no pivot-assuming inverse) and predicts co-moving pins about per-instance pivots.
#
# Discriminator: the ELECTRICAL PARTITION is preserved -- R18.P stays on C12's #net2, R18.M on
# #net1, distinct. Pre-fix the rot90-in-place cases DISCONNECT (fresh nets on both pins).
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_rotate_stretch_reconnect_0100.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- 0100 rotate-in-place stretch test needs a real display"
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
set Button1Mask 256 ; set Mod1Mask 8
set KSYM_m 109 ; set KSYM_r 114 ; set KSYM_f 102

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

# Connected stretch on R18 with the ALT-R/ALT-F IN-PLACE transforms fired MID-drag and the drag
# CONTINUED afterwards (the user's trace shows several MOTION steps after the rotate), drop at
# schematic delta (dx,dy) from the grab point (gx,gy) -- default R18 body center (-120,-80).
# NOTE (gx,gy)=(-120,-80) coincides with R18's ANCHOR, where the global grab pivot and the
# instance-origin pivot agree; the off-anchor variant below discriminates the per-instance
# MOVPIN pivot (fix edit C) from the global one.
proc gesture_ip {nrot doflip dx dy {gx -120} {gy -80} {extra {}}} {
  global WIN KP BP BR MOTION Button1Mask Mod1Mask KSYM_m KSYM_r KSYM_f
  set r18 [find_inst R18]
  lassign [screen $gx $gy] sx sy
  lassign [screen [expr {$gx+10}] [expr {$gy+30}]] m1x m1y           ;# mid-drag point (+10,+30)
  lassign [screen [expr {$gx+30}] [expr {$gy+50}]] m2x m2y           ;# post-rotate drag (+30,+50)
  lassign [screen [expr {$gx+$dx}] [expr {$gy+$dy}]] tx ty
  xschem unselect_all; xschem select instance $r18
  foreach e $extra { xschem select instance [find_inst $e] }         ;# multi-instance variants
  xschem callback $WIN $KP $sx $sy $KSYM_m 0 0 0
  xschem callback $WIN $MOTION $m1x $m1y 0 0 0 0                     ;# drag BEFORE the rotate
  for {set i 0} {$i<$nrot} {incr i} { xschem callback $WIN $KP $m1x $m1y $KSYM_r 0 0 $Mod1Mask }
  if {$doflip} { xschem callback $WIN $KP $m1x $m1y $KSYM_f 0 0 $Mod1Mask }
  xschem callback $WIN $MOTION $m2x $m2y 0 0 0 0                     ;# drag AFTER the rotate
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP $tx $ty 0 1 0 0
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

# Structural partition asserts. Auto-assigned #netN names DRIFT with wire creation order (the
# rigid-relay fallback reorders it), so never assert a literal #netN name post-gesture; assert the
# SHAPE of the partition instead: R18.P stays with C12 (whose own two pins stay distinct -- catches
# a C12 top-bottom merge the share test alone would miss), R18.M stays on the v8/backbone subtree,
# and the two R18 pins stay distinct. "OUT" is a real label => stable name, usable literally.
proc instnets {inst} {
  set nets {}
  foreach {pin net} [lrange [xschem instance_nodemap $inst] 1 end] { lappend nets $net }
  return $nets
}
proc partition_ok {} {
  set p [pinnet R18 P]; set m [pinnet R18 M]
  if {$p eq "" || $m eq "" || $p eq $m} { return 0 }
  set c12 [instnets C12]
  if {[lsearch -exact $c12 $p] < 0} { return 0 }
  if {[lindex $c12 0] eq [lindex $c12 1]} { return 0 }
  if {[lsearch -exact [instnets v8] $m] < 0 || $m eq "OUT"} { return 0 }
  return 1
}
proc check_partition {label} {
  set p [pinnet R18 P]; set m [pinnet R18 M]
  set c12 [instnets C12]; set v8 [instnets v8]
  check "$label: R18.P and R18.M distinct + non-empty" [expr {$p ne $m && $p ne "" && $m ne ""}]
  check "$label: R18.P still shares a C12 pin net"     [expr {[lsearch -exact $c12 $p] >= 0}]
  check "$label: C12 pins on distinct nets (no C12 self-short)" \
        [expr {[lindex $c12 0] ne [lindex $c12 1]}]
  check "$label: R18.M still on the v8/backbone subtree" \
        [expr {[lsearch -exact $v8 $m] >= 0 && $m ne "OUT"}]
}

# baseline partition (no gesture)
load_fixture
check "fixture has R18" [expr {[find_inst R18] >= 0}]
check "pre: R18.P=#net2" [expr {[pinnet R18 P] eq "#net2"}]
check "pre: R18.M=#net1" [expr {[pinnet R18 M] eq "#net1"}]

# --- issue 0100 hard asserts: rotate/flip IN-PLACE where a clean L exists per follow wire.
load_fixture; gesture_ip 1 0 40 20 ; check_partition "rot90-ip (user drop 40,20)"  ;# the reported case
load_fixture; gesture_ip 1 0 30 20 ; check_partition "rot90-ip (30,20)"
load_fixture; gesture_ip 0 1 30 20 ; check_partition "flip-ip"    ;# pins on anchor axis: pure P1 check
load_fixture; gesture_ip 1 1 30 20 ; check_partition "rot90+flip-ip"
# Off-anchor grab (-100,-80): global grab pivot != R18's origin, so the co-moving-pin hazard
# prediction (fluid_ml_hazards MOVPIN) must use the PER-INSTANCE rotatelocal pivot or the elbow
# corner lands exactly on rotated pin M (-120,-60) unpredicted -> short. The rot90+flip variant
# guards edit C's FLIP arm too (at the default anchor grab the global and per-instance pivots
# coincide, so an edit-C flip regression would be invisible -- review wf_80304448 finding).
load_fixture; gesture_ip 1 0 30 20 -100 -80 ; check_partition "rot90-ip off-anchor grab"
load_fixture; gesture_ip 1 1 30 20 -100 -80 ; check_partition "rot90+flip-ip off-anchor grab"
# Multi-instance selection (R18 + C12, grab differing from BOTH origins): exercises the owner-
# DISAMBIGUATION scan (which selected instance's pin the follow endpoint sits on) with two ELEMENT
# candidates -- single-instance gestures cannot catch a first-selected-origin regression there.
load_fixture; gesture_ip 1 0 40 20 -220 -140 {C12} ; check_partition "rot90-ip multi-select R18+C12"

# --- issue 0102 (was the 0099/0100 "known limitation"): rot180/270 in-place swap the pins so the
#     two follow routes MUST cross -- no clean 2-leg L exists (the elbow hazard picker flags BOTH
#     orientations: one leg plows the rotated sibling pin, the other T-touches its net's backbone
#     end). Fixed by arming the P2 safety net (attempt loop) under rotation: the shorted ortho
#     route is rolled back and the follow wires relay as rigid diagonals landing exactly on the
#     rotated pins (partition-verified accept). before_7.sch -> after_19.sch was the user repro.
load_fixture; gesture_ip 2 0 -50 80 ; check_partition "rot180-ip (user drop -50,80)"
load_fixture; gesture_ip 2 0 30 20  ; check_partition "rot180-ip (30,20)"
load_fixture; gesture_ip 3 0 30 20  ; check_partition "rot270-ip (30,20)"
# dx==0 drops (review wf_49325abb F2): anchor + rotated pin stay COLLINEAR on the fixture's single
# column, the rigid relay degenerates to axis-aligned wires spanning the swapped sibling pin
# (pin-on-span merge). The degenerate relay is bent into two true diagonals at an off-axis midpoint.
load_fixture; gesture_ip 2 0 0 0    ; check_partition "rot180-ip in-place (drop 0,0)"
load_fixture; gesture_ip 2 0 0 40   ; check_partition "rot180-ip dy-only (0,40)"

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS (51 checks, structural partition asserts)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
