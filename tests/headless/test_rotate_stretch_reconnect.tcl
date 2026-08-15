# Case 4 (Phase 4a): rotate DURING a connected stretch re-establishes wire connections.
# Spec: doc/claude/specs/rotate_keep_connected_stretch.md
#
# A connected stretch ('m' under cadence) grabs the wire endpoints on a moved instance's
# pins so they follow. When the moved set is ROTATED mid-gesture, the follow-wire's near
# endpoint (on the pin) must rotate WITH the pin while its far (anchored) endpoint stays
# PRISTINE -- crux (a). place_moved_wire then bends an L so the wire reconnects the rotated
# pin to the unchanged far endpoint.
#
# Discriminator: the far anchor point must be UNCHANGED after the gesture. Before the
# crux-(a) fix the commit block rotated BOTH endpoints about the pivot, so the anchored far
# end was torn off (moved) and the wire no longer reconnected -> T5c/T5d fail.
#
# Drives the REAL keyboard dispatch: 'm' (START connected stretch) + 'R' (rotate mid-move)
# + MOTION (RUBBER) + Button1 drop (END). Sibling of test_cadence_stretch_move.tcl.
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_rotate_stretch_reconnect.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- rotate-stretch reconnect test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}

set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256 ; set ShiftMask 1
set KSYM_m 109 ; set KSYM_R 82

proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}
proc inst_screen {n} {
  xschem unselect_all; xschem select instance $n
  lassign [xschem get bbox_selected] x1 y1 x2 y2
  xschem unselect_all
  screen [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]
}
proc inst_rot {n} { lindex [xschem instance_coord $n] 4 }
proc pinM {n} { set pc [xschem instance_pin_coord $n name M]; list [lindex $pc 1] [lindex $pc 2] }
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
# is (x,y) an endpoint of some wire? (tol = sub-grid)
proc ep_present {x y {tol 0.6}} {
  foreach w [allwires] {
    lassign $w a b c d
    if {abs($a-$x)<$tol && abs($b-$y)<$tol} { return 1 }
    if {abs($c-$x)<$tol && abs($d-$y)<$tol} { return 1 }
  }
  return 0
}

# connected stretch + rotate + drop. KeyPress 'm' at grab (START), 'R' * nrot (rotate),
# MOTION to dest (RUBBER), Button1 click (END commits).
proc kstretch_rotate {sx sy dx dy nrot} {
  global KP BP BR MOTION Button1Mask ShiftMask KSYM_m KSYM_R WIN
  set tx [expr {$sx+$dx}]; set ty [expr {$sy+$dy}]
  xschem callback $WIN $KP $sx $sy $KSYM_m 0 0 0
  for {set i 0} {$i < $nrot} {incr i} {
    xschem callback $WIN $KP $sx $sy $KSYM_R 0 0 $ShiftMask
  }
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP $tx $ty 0 1 0 0
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

# Fresh fixture: res at origin + one horizontal wire from pin M to a fixed far anchor.
proc setup_fixture {} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0
  set ::cadence_compat 1                 ;# 'm' = connected stretch
  xschem set fluid_editing 1
  xschem instance {res.sym} 0 0 0 0 {}
  lassign [pinM 0] px py
  xschem wire $px $py [expr {$px+300}] $py
  xschem zoom_full; update idletasks
}

# === T5 — connected stretch + rotate 90: reconnect, far anchor pristine =======
setup_fixture
lassign [inst_screen 0] sx sy
lassign [pinM 0] pmx pmy
set fmx [expr {$pmx+300}]; set fmy $pmy        ;# far anchor (anchored end)
set r0 [inst_rot 0]
xschem select instance 0
check "T5pre far anchor is a wire endpoint before"   [ep_present $fmx $fmy]
kstretch_rotate $sx $sy 40 0 1
check "T5  stretch+rotate rotates the instance"      [expr {[inst_rot 0] ne $r0}]
check "T5b far anchor UNCHANGED (crux a: anchored end not rotated)" [ep_present $fmx $fmy]
lassign [pinM 0] nmx nmy                        ;# pin M new position after rotate
check "T5c pin M moved (rotation actually applied)"  [expr {"$nmx,$nmy" ne "$pmx,$pmy"}]
check "T5d follow-wire reconnects the rotated pin M"  [ep_present $nmx $nmy]

# === T6 — rotate 180 (two R): still reconnects, far anchor pristine ==========
setup_fixture
lassign [inst_screen 0] sx sy
lassign [pinM 0] pmx pmy
set fmx [expr {$pmx+300}]; set fmy $pmy
set r0 [inst_rot 0]
xschem select instance 0
kstretch_rotate $sx $sy 40 20 2
check "T6  stretch+rotate180 rotates the instance"   [expr {[inst_rot 0] ne $r0}]
check "T6b far anchor UNCHANGED after 180"           [ep_present $fmx $fmy]
lassign [pinM 0] nmx nmy
check "T6c follow-wire reconnects pin M after 180"   [ep_present $nmx $nmy]

# === T7 — pure translation stretch (no rotate): regression, wire follows =====
setup_fixture
lassign [inst_screen 0] sx sy
lassign [pinM 0] pmx pmy
set fmx [expr {$pmx+300}]; set fmy $pmy
xschem select instance 0
set before [allwires]
kstretch_rotate $sx $sy 40 20 0
check "T7  translation stretch still moves+reroutes (wire changed)" [expr {[allwires] ne $before}]
check "T7b translation stretch far anchor pristine"  [ep_present $fmx $fmy]
lassign [pinM 0] nmx nmy
check "T7c translation stretch reconnects pin M"     [ep_present $nmx $nmy]

# === T8 — MULTI-INSTANCE connected stretch + rotate: group reconnects rigidly ==
# Two res, each with a vertical wire to its own far anchor. Select BOTH, connected stretch,
# rotate 90 about the shared grab pivot, drop. Each follow-wire must reconnect its own pin
# and each far anchor stays pristine (item iv: 4a's shared-pivot rotation handles groups).
proc setup_two {} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0
  set ::cadence_compat 1
  xschem set fluid_editing 1
  xschem instance {res.sym} 0 0 0 0 {}
  xschem instance {res.sym} 200 0 0 0 {}
  lassign [pinM 0] a0x a0y
  lassign [pinM 1] a1x a1y
  xschem wire $a0x $a0y $a0x [expr {$a0y-300}]   ;# res0 pin M -> far anchor below
  xschem wire $a1x $a1y $a1x [expr {$a1y-300}]   ;# res1 pin M -> far anchor below
  xschem zoom_full; update idletasks
}
setup_two
lassign [pinM 0] p0x p0y
lassign [pinM 1] p1x p1y
set f0x $p0x; set f0y [expr {$p0y-300}]
set f1x $p1x; set f1y [expr {$p1y-300}]
set r0 [inst_rot 0]; set r1 [inst_rot 1]
# grab pivot = midpoint of the two instances (a body point between them)
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [xschem get bbox_selected] bx1 by1 bx2 by2
lassign [screen [expr {($bx1+$bx2)/2.0}] [expr {($by1+$by2)/2.0}]] gsx gsy
kstretch_rotate $gsx $gsy 30 30 1
check "T8  multi-inst stretch+rotate rotates res0"   [expr {[inst_rot 0] ne $r0}]
check "T8b multi-inst stretch+rotate rotates res1"   [expr {[inst_rot 1] ne $r1}]
check "T8c res0 far anchor pristine"                 [ep_present $f0x $f0y]
check "T8d res1 far anchor pristine"                 [ep_present $f1x $f1y]
lassign [pinM 0] n0x n0y
lassign [pinM 1] n1x n1y
check "T8e res0 follow-wire reconnects its pin M"    [ep_present $n0x $n0y]
check "T8f res1 follow-wire reconnects its pin M"    [ep_present $n1x $n1y]

puts ""
if {$::fails == 0} {
  puts "RESULT: ALL PASS (17 checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $::fails FAIL"
  puts "OVERALL: FAIL"
}
exit [expr {$::fails ? 1 : 0}]
