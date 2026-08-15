# issue 0132 (after_37, defect P-D "ref-net-drop"): a DIAGONAL connected drag of x1 (delta +20,-10)
# from before_10.sch dropped the REF pin's whole net. The pure-ortho X-then-Y decomposition shorts
# and rolls back to the rigid diag_relay fallback; its post-accept cleanup
# (fluid_manhattanize_relay_diagonals -> fluid_reroute_body_crossing_feeds ->
# fluid_delete_body_crossing_copper) then DELETED REF's own feed `-60 -140 120 -140`, because REF's
# pin (120,-140) lies strictly inside the pin-inclusive body box (under rot1 the symbol-left pins map
# to the box interior), so its lead necessarily crosses that box and was mis-classified as "stale
# through-body copper". The delete's partition-verify was fooled by a transient relay weld that a
# later prune removed, so REF ended ORPHANED and the surviving LED net annexed the #net1 label
# (electrical error, saved silently because a P1 disconnect is not in the B3 refuse signal).
#
# FIX (move.c fluid_wire_end_on_moved_pin, guard in fluid_delete_body_crossing_copper): a wire whose
# endpoint sits exactly on a moved (selected) instance pin is that pin's OWN lead and is never deleted
# as through-body copper -- deleting it can only orphan the pin. Safe for the §11.9b self-drop case
# (there the feed is re-routed body-free first, so it is not a delete candidate; the deleted backbone
# does not touch the pin).
#
# NEEDS A REAL X DISPLAY (interactive multi-motion gesture -- a single move_objects does not reproduce
# the accumulated RUBBER history that feeds the END diag_relay cleanup). Self-skips cleanly with no
# display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_diagonal_ref_drop_0132.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
for {set i 0} {$i < 40} {incr i} {
  if {![catch {winfo viewable $WIN} vv] && $vv} break
  update idletasks; after 100; update
}
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- diagonal drag test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}

set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256
set ::HERE [file dirname [file normalize [info script]]]
set repo [file normalize [file join $::HERE .. ..]]

set XSCHEM_LIBRARY_DEFS [file join $repo xschem_libs_newsym library.defs]
set library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH {}
set library_default_layout nested
set cadence_compat 1; set intuitive_interface 1
set fluid_editing 1; set orthogonal_wiring 1; set fluid_enforce_invariants 1

xschem load [file join $repo tests/from_user/before_10.sch]
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
# GEOMETRIC connectivity: is any wire endpoint exactly on (X,Y)?  (instance_net reports a phantom
# auto-name for an orphaned pin, so it cannot tell connected from orphaned -- geometry can.)
proc touched {X Y} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {($a==$X && $b==$Y) || ($c==$X && $d==$Y)} { return 1 }
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

# replay the interactive drag: press on x1, motion through the RUBBER waypoints, release
xschem unselect_all
lassign [xschem instance_coord x1] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
xschem callback $WIN $BP $psx $psy 0 1 0 0
xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
set tx $psx; set ty $psy
foreach wp {{10 0} {10 -10} {20 -10}} {
  lassign $wp dx dy
  lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
  xschem callback $WIN $MOTION $tx $ty 0 0 0 $Button1Mask
}
xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord x1] a1 a2 nrx nry
check "x1 landed at (130,10)" [expr {$nrx==130 && $nry==10}] "got ($nrx,$nry)"

# pins after the (+20,-10) move (rot1): REF 100,-130 -> 120,-140 ; LED 120,-130 -> 140,-140
set REFX 120; set REFY -140
set LEDX 140; set LEDY -140
set ref_conn [touched $REFX $REFY]
set led_conn [touched $LEDX $LEDY]
# THE tripwire: pre-fix the diag_relay cleanup deletes REF's feed, orphaning the pin (0 here).
check "P-D: REF pin ($REFX,$REFY) stays connected (not orphaned)" $ref_conn
check "P-D: LED pin ($LEDX,$LEDY) stays connected" $led_conn

set ref_after [pnet REF]; set led_after [pnet LED]
# both pins really connected AND resolving to distinct real nets => the two top nets did NOT collapse
check "P-D: REF and LED stay on DISTINCT nets, no collapse (REF=$ref_after LED=$led_after)" \
  [expr {$ref_conn && $led_conn && $ref_after ne $led_after}]

# ---- P-A/P-C (§11.9f): the CTRL1 backbone must be shoved CLEAR of x1's body, not left threading it ----
# x1 body box at (130,10) rot1 (pin-inclusive, from fluid_inst_body_box): x[97.5,150] y[-142.5,72.5].
set BX1 97.5; set BX2 150; set BY1 -142.5; set BY2 72.5
proc ctrl1_verticals {} {
  set out {}; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    if {[xschem getprop wire $k lab] ne "CTRL1"} continue
    lassign [xschem wire_coord $k] a b c d
    if {$a == $c && $b != $d} { lappend out [list $a [expr {min($b,$d)}] [expr {max($b,$d)}]] }
  }
  return $out
}
# CTRL1 pin (140,70) must stay connected
check "P-C: CTRL1 pin (140,70) connected" [touched 140 70]
# no CTRL1 vertical may thread the body column (x strictly inside body, span dipping into body y)
set threading {}; set pushed 0
foreach v [ctrl1_verticals] {
  lassign $v x ylo yhi
  if {$x > $BX1 && $x < $BX2 && $ylo < $BY2 && $yhi > $BY1} { lappend threading $v }
  if {$x >= $BX2} { set pushed 1 }
}
check "P-A: no CTRL1 vertical threads x1's body (x in ($BX1,$BX2))" \
  [expr {[llength $threading]==0}] "threading=$threading verticals=[ctrl1_verticals]"
check "P-A: a CTRL1 vertical exists at/right of the body edge (the shoved backbone at x=160)" \
  $pushed "verticals=[ctrl1_verticals]"
check "P-A/P-C: no diagonal wire remains" [expr {[ndiag]==0}] "diag=[ndiag]"

# ---- P-B (§11.9g): the old pin-riser elbows the moved pin vacated must not survive as dangling
# named-copper overhangs. TRIANG's old elbow (80,90) and CTRL1's old elbow (120,100) had a wire
# endpoint each in the buggy result; after the fix no wire touches those vacated vertices. ----
check "P-B: TRIANG old-elbow overhang gone (nothing at 80,90)" [expr {![touched 80 90]}]
check "P-B: CTRL1 old-elbow overhang gone (nothing at 120,100)" [expr {![touched 120 100]}]
# and no CTRL1 dead-branch stub above the pin jog: the only CTRL1 vertical is the live 160,-20..160,70
proc named_free_ends {lab} {
  set out {}; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    if {[xschem getprop wire $k lab] ne $lab} continue
    lassign [xschem wire_coord $k] a b c d
    foreach {ex ey} [list $a $b $c $d] {
      set deg 0
      for {set j 0} {$j < $nw} {incr j} {
        if {$j==$k} continue
        lassign [xschem wire_coord $j] p q r s
        if {($p==$ex && $q==$ey) || ($r==$ex && $s==$ey)} { incr deg }
      }
      # a free end not shared with another wire, not on the label pin (220,±20) or a device pin
      if {$deg==0 && !($ex==220)} { lappend out [list $ex $ey] }
    }
  }
  return $out
}
# CTRL1 free ends: only the device pin (140,70) is a legit dangling-looking end (it sits on a pin).
set c1free [named_free_ends CTRL1]
set c1bad {}
foreach fe $c1free { if {$fe ne {140 70}} { lappend c1bad $fe } }
check "P-B: no stray CTRL1 dead-branch free end (only the pin 140,70)" \
  [expr {[llength $c1bad]==0}] "stray=$c1bad free=$c1free"

puts "PASS=$::npass FAIL=$::fails"
if {$::fails == 0} { puts "RESULT: ALL PASS"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED"; puts "OVERALL: FAIL" }
