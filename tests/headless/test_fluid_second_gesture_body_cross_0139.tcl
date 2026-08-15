# issue 0139 (before_39 -> after_42): a TWO-gesture connected-drag of x1 (SANDBOX/solar_ctl, rot1).
# Action-log replay: select x1 ; move_objects 0 20 ; move_objects -10 -40  => net delta (-10,-20),
# x1 origin (80,10) -> (70,-10). Both gestures are separate press-drag-release; the fluid pipeline
# arms once per gesture, so the SECOND gesture's start snapshot is the FIRST gesture's result.
#
#   DEFECT `second-gesture-buries-pin-tracked-trunk`: the LED net (#net1) reaches its rail through a
#   crossbar the first gesture already relocated to y=-130. The second gesture advances x1's body top up
#   to y=-140, ENGULFING that crossbar, and the moved LED pin's stub stretches south into the body to
#   meet the trapped elbow (80,-130). Result (after_42): #net1 saved as `-50 -130 80 -130` +
#   `80 -160 80 -130` -- the horizontal crossbar and the stub's lower leg both thread the DEVICE body
#   box x[50,90] y[-140,30].
#
#   The 0136 fluid_shove_jog_separated_trunk -- the pass purpose-built to shove exactly such an off-pin-
#   row jog-separated through-body trunk -- FAILED to fire here for two independent reasons:
#     (1) its PRE-EXISTING gate (fluid_wire_is_novel_span) read the crossbar as this-drag copper because
#         gesture 2 SHRANK its span (x2 90->80, the right end tracked the LED column inward under the
#         -10 x-delta) -- so it is no longer byte-identical to the per-gesture start snapshot;
#     (2) its LOAD-BEARING gate (pin-partition change) is BLIND to a SINGLE-PIN net: #net1 carries only
#         the LED pin (its rail dead-ends), so dooming the sole stub->rail path moves no pin between
#         components even though the crossbar IS load-bearing.
#
# FIX (move.c):
#   - fluid_wire_pretracked_shrink re-admits a novel-span wire that is collinear INSIDE a start-wire
#     footprint AND has an endpoint on a moved pin's column (a pin-tracked shrink, not a fresh detour);
#   - a WIRE-level cut-edge fallback in the load-bearing gate (flood with the run doomed: a genuine
#     bridge disconnects its attachments) so a single-pin feed's crossbar reads load-bearing;
#   - the shove target STEPS one grid further out when a neighbour net (REF #net2, parked at y=-170 by
#     straighten) occupies the one-grid line, so the crossbar clears BOTH the body and the neighbour.
#   Result: #net1 crossbar y=-130 -> y=-180 (above #net2's -170); route LED(80,-160)->(80,-180)->
#   (-50,-180)->rail, body-clear. The #net1 rail's mid-span crossing of the #net2 crossbar at (-50,-170)
#   shares no endpoint => not an electrical short (partition-verified: LED stays #net1, REF stays #net2).
#
# NEEDS A REAL X DISPLAY (the interactive multi-motion connected-drag arms the fluid pipeline; a headless
# --nogui select_at + move_objects does NOT move the instance). Self-skips with no display.
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_second_gesture_body_cross_0139.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
for {set i 0} {$i < 40} {incr i} {
  if {![catch {winfo viewable $WIN} vv] && $vv} break
  update idletasks; after 100; update
}
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- multi-gesture drag test needs a real display"
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
# does any wire of net $want strictly ENTER the x1 DEVICE body poly box x(50,90) y(-140,30)?
proc net_crosses_body {want} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    if {[xschem getprop wire $k lab] ne $want} continue
    lassign [xschem wire_coord $k] a b c d
    if {$a==$c} {                                        ;# vertical at x=a
      if {$a>50 && $a<90} { set lo [expr {$b<$d?$b:$d}]; set hi [expr {$b<$d?$d:$b}]
        if {$lo<30 && $hi>-140} { return 1 } }
    } elseif {$b==$d} {                                  ;# horizontal at y=b
      if {$b>-140 && $b<30} { set lo [expr {$a<$c?$a:$c}]; set hi [expr {$a<$c?$c:$a}]
        if {$lo<90 && $hi>50} { return 1 } }
    }
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
# one full press-drag-release connected-drag from schematic point (ox,oy) through waypoints (dx dy)...
proc gesture {ox oy waypoints} {
  global WIN BP BR MOTION Button1Mask
  xschem unselect_all
  lassign [screen $ox $oy] psx psy
  xschem callback $WIN $BP $psx $psy 0 1 0 0
  xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
  set tx $psx; set ty $psy
  foreach wp $waypoints {
    lassign $wp dx dy
    lassign [screen [expr {$ox+$dx}] [expr {$oy+$dy}]] tx ty
    xschem callback $WIN $MOTION $tx $ty 0 0 0 $Button1Mask
  }
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

set led_before [pnet LED]; set ref_before [pnet REF]
check "setup: LED/REF on distinct nets (LED=$led_before REF=$ref_before)" \
  [expr {$led_before ne $ref_before}]

# ---- gesture 1: (0,+20) from origin (80,10) ----
gesture 80 10 {{0 10} {0 20}}
lassign [xschem instance_coord x1] j1 j2 g1x g1y
check "gesture 1 landed x1 at (80,30)" [expr {$g1x==80 && $g1y==30}] "got ($g1x,$g1y)"

# ---- gesture 2: (-10,-40) from the gesture-1 result origin ----
gesture $g1x $g1y {{0 -10} {0 -20} {-10 -30} {-10 -40}}
lassign [xschem instance_coord x1] k1 k2 g2x g2y
check "gesture 2 landed x1 at (70,-10)" [expr {$g2x==70 && $g2y==-10}] "got ($g2x,$g2y)"

# ---- P5: the LED net must NOT thread x1's body (the user-reported bug) ----
check "0139: #net1 (LED) net does NOT cross the x1 body box (was -50 -130 80 -130 + 80 -160 80 -130)" \
  [expr {![net_crosses_body {#net1}]}]
# the buried elbow (80,-130) inside the body must be gone (crossbar shoved out)
check "0139: no #net1 copper left at the buried elbow (80,-130)" [expr {![touched 80 -130]}]
# the crossbar shoved past the body top AND past the REF #net2 crossbar (parked at y=-170) -> y=-180
check "0139: #net1 crossbar clears the body+neighbour to y=-180 (80 -180 and -50 -180 present)" \
  [expr {[touched 80 -180] && [touched -50 -180]}]

# ---- P1/P2: connectivity preserved, nets stay distinct (no merge across the mid-span crossing) ----
check "LED pin (80,-160) stays connected" [touched 80 -160]
set led_after [pnet LED]; set ref_after [pnet REF]
check "LED net preserved (#net1 => net1)" [expr {$led_after eq {net1}}] "got $led_after"
check "REF net preserved (#net2 => net2)" [expr {$ref_after eq {net2}}] "got $ref_after"
check "LED/REF stay distinct nets (no merge at the -50,-170 crossing)" [expr {$led_after ne $ref_after}]
check "CTRL1/TRIANG preserved and distinct" \
  [expr {[pnet CTRL1] eq {CTRL1} && [pnet TRIANG] eq {TRIANG} && [pnet CTRL1] ne [pnet TRIANG]}]
check "no diagonal wire remains" [expr {[ndiag]==0}] "diag=[ndiag]"

# ---- regression scope: the neighbour net is not itself dragged into the body ----
check "#net2 (REF) does NOT cross the body" [expr {![net_crosses_body {#net2}]}]

puts "PASS=$::npass FAIL=$::fails"
if {$::fails == 0} { puts "RESULT: ALL PASS"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED"; puts "OVERALL: FAIL" }
