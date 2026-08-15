# issue 0135 (after_39): a DIAGONAL SW connected-drag of x1 (SANDBOX/solar_ctl, rot1) by delta
# (-10,+20) from before_39.sch. Accepted path = END attempt=0 leg-split (nlegs=2, diag_relay=0),
# partition clean; at that point REF/#net2 is a CLEAN L. Then the per-gesture
# `fluid_shove_body_crossing_backbone`, run on this diagonal path via the 0134 hunk-2 PER-AXIS spoof
# (move.c:8767-8782), mis-fires:
#
#   DEFECT D1 `diag-shove-rebuilds-input-feed-as-through-body-U`: the y-run shove (deltay spoofed to
#   +20) reads REF's HORIZONTAL escape feed as a shoveable backbone and rebuilds it 1 grid past the
#   SOUTH body edge (ct=100) -- because `dirpos` (motion "ahead") points south while REF's lead escape
#   normal points NORTH. Result: REF drags from its north pin (60,-120) straight DOWN through the whole
#   pin-inclusive body to y=100 (after_39: `#net2 60 -120 60 100 / -60 100 60 100 / -60 0 -60 100`).
#
# FIX: decline the shove when the pin's escape normal has a component ALONG the shove axis that OPPOSES
# the relocation direction (never drag a feed across the body to the far side); the legitimate CTRL1
# perpendicular-backbone shoves have escape PERPENDICULAR to the shove axis, so they are untouched.
#
# NEEDS A REAL X DISPLAY (the interactive multi-motion gesture accumulates the RUBBER history the END
# shove consumes; a single move_objects does NOT move the instance headless). Self-skips with no display.
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_diagonal_shove_throughbody_0135.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
for {set i 0} {$i < 40} {incr i} {
  if {![catch {winfo viewable $WIN} vv] && $vv} break
  update idletasks; after 100; update
}
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- diagonal drag test needs a real display"
  puts "RESULT: SKIP (no X)"; puts "OVERALL: ok"; exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}

set BP 4 ; set BR 5 ; set MOTION 6 ; set Button1Mask 256
set ::HERE [file dirname [file normalize [info script]]]
set repo [file normalize [file join $::HERE .. ..]]
set XSCHEM_LIBRARY_DEFS [file join $repo xschem_libs_newsym library.defs]
set library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH {}
set library_default_layout nested
set cadence_compat 1; set intuitive_interface 1
set fluid_editing 1; set orthogonal_wiring 1; set fluid_enforce_invariants 1

xschem load [file join $repo tests/from_user/before_39.sch]
xschem set readonly 0
catch { xschem set fluid_editing 1 }
catch { xschem set orthogonal_wiring 1 }
catch { xschem set intuitive_interface 1 }
xschem zoom_full; update idletasks

proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$zm))}] [expr {int(round(($sy+$yo)/$zm))}]
}
proc pnet {pin} { return [lindex [xschem instance_net x1 $pin] 0] }
proc touched {X Y} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {($a==$X && $b==$Y) || ($c==$X && $d==$Y)} { return 1 }
  }
  return 0
}
# is there a VERTICAL wire at column x=$X descending from the pin region (min y <= -100) deep past
# the body (max y >= 0) -- the through-body U signature. Net-agnostic (getprop wire lab carries a '#'
# prefix that instance_net strips; the U is geometrically unique here regardless of net).
proc through_body_vertical {X} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {$a != $c} continue                       ;# not vertical
    if {$a != $X} continue
    set lo [expr {$b < $d ? $b : $d}]; set hi [expr {$b < $d ? $d : $b}]
    if {$lo <= -100 && $hi >= 0} { return 1 }
  }
  return 0
}
proc ndiag {} {
  set n 0; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {$a != $c && $b != $d} { incr n }
  }
  return $n
}

set ref_before [pnet REF]; set led_before [pnet LED]
check "setup: REF/LED on distinct nets (REF=$ref_before LED=$led_before)" \
  [expr {$ref_before ne $led_before}]

# replay the SW-diagonal drag (-10,+20): press on x1, motion waypoints, release
xschem unselect_all
lassign [xschem instance_coord x1] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
xschem callback $WIN $BP $psx $psy 0 1 0 0
xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
set tx $psx; set ty $psy
foreach wp {{-5 10} {-10 20}} {
  lassign $wp dx dy
  lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
  xschem callback $WIN $MOTION $tx $ty 0 0 0 $Button1Mask
}
xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord x1] a1 a2 nrx nry
check "x1 landed at (70,30)" [expr {$nrx==70 && $nry==30}] "got ($nrx,$nry)"

# pins after (-10,+20): REF 70,-140 -> 60,-120 (#net2) ; LED 90,-140 -> 80,-120 (#net1)
set REFX 60;  set REFY -120

# ---- D1: REF's net must NOT be rebuilt as a through-body U ----
check "REF pin ($REFX,$REFY) stays connected" [touched $REFX $REFY]
set ref_after [pnet REF]; set led_after [pnet LED]
check "REF/LED stay distinct nets (REF=$ref_after LED=$led_after)" [expr {$ref_after ne $led_after}]
check "D1: no through-body vertical at REF column x=$REFX (was #net2 60 -120 60 100)" \
  [expr {![through_body_vertical $REFX]}]
check "no diagonal wire remains" [expr {[ndiag]==0}] "diag=[ndiag]"

# ---- D2 (route-quality): REF's feed must EXIT NORTH along the symbol LEAD normal (0,-1), not
# preserve the translated perpendicular-WEST backbone that grazes the body top edge. x1's
# pin-inclusive body is world x[37.5,90] y[-122.5,92.5]; REF's pin (60,-120) is 2.5 inside the top,
# so the correct escape is vertical-north (like LED). Pre-fix REF's feed is `-60 -120 60 -120`
# (horizontal at the pin row y=-120, grazing x[37.5,60] inside the body); post-fix it exits north
# via a vertical stub then a west run at y=-140 (clears the body, no LED short). BOTH checks are RED
# on the pre-D2 binary. issue 0135 D2 / WIRING §11.9a.
proc first_seg {X Y} {                      ;# other endpoints of every wire incident on (X,Y)
  set nw [xschem get wires]; set hits {}
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {$a==$X && $b==$Y} { lappend hits [list $c $d] }
    if {$c==$X && $d==$Y} { lappend hits [list $a $b] }
  }
  return $hits
}
# a horizontal wire running along the body-top interior row (y=-120) overlapping the body x-span
# [37.5,90] -- the D2 graze signature (net-agnostic; nothing should legitimately run there).
proc grazes_body_top {} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {$b != $d} continue                  ;# not horizontal
    if {$b != -120} continue                ;# only the y=-120 body-top graze row
    set lo [expr {$a<$c?$a:$c}]; set hi [expr {$a<$c?$c:$a}]
    if {$hi > 37 && $lo < 90} { return 1 }  ;# overlaps the body x-interior
  }
  return 0
}
set fs [first_seg $REFX $REFY]
check "D2: exactly one wire on REF pin ($REFX,$REFY)" [expr {[llength $fs]==1}] "got {$fs}"
lassign [lindex $fs 0] ox oy
check "D2: REF first segment exits VERTICAL/NORTH along lead normal (not horizontal-grazing)" \
  [expr {$ox==$REFX && $oy<$REFY}] "other end ($ox,$oy)"
check "D2: no wire grazes the body top interior at y=-120" [expr {![grazes_body_top]}]

puts "PASS=$::npass FAIL=$::fails"
if {$::fails == 0} { puts "RESULT: ALL PASS"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED"; puts "OVERALL: FAIL" }
