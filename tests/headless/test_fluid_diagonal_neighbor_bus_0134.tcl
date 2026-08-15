# issue 0134 (after_38): a DIAGONAL connected drag of x1 (SANDBOX/solar_ctl, rot1) by delta (-20,-10)
# from before_10.sch. x1 has two NORTH-edge INPUT pins on parallel buses ONE grid apart:
#   REF (100,-130) -> net #net1, backbone y=-140 ;  LED (120,-130) -> net #net2, backbone y=-150.
# The -10 vertical component lands LED (the invader) on REF's y=-140 backbone row.
#
# THREE defects (see doc/claude/issues/0134-*.md):
#   A (ROOT) ripup-jogs-wrong-pin-welds-neighbor-bus: fluid_ripup_foreign_pin_short walks pin-pairs in
#     INDEX order, reaches REF (the NON-invader) first, and the 0105 collinear jog bumps REF's y=-140
#     backbone DOWN one grid onto #net2 -> WELDS #net1+#net2 and orphans REF. Its pin-pair partition
#     verify is single-pin-net BLIND, so END accepts (partition_changed=0) before any delete.
#   B (DATA-LOSS): remove_redundant_loops + straighten pass-2 then DELETE the welded/orphaned copper
#     (verifying against post-short, name-blind geometry) -> #net1 AND #net2 vanish entirely.
#   C (STAIRCASE, independent): the elbow axis is picked from |dx| vs |dy| alone (tie -> horizontal-
#     first) and never reads the moved pin's lead dir=; TRIANG's SOUTH-lead out-pin exits sideways.
#
# ALL checks below are RED before the fix. NEEDS A REAL X DISPLAY (the interactive multi-motion gesture
# accumulates the RUBBER history that feeds the END cleanup; a single move_objects does NOT reproduce
# it -- it does not even move the instance headlessly). Self-skips cleanly with no display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_diagonal_neighbor_bus_0134.tcl

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
# GEOMETRIC connectivity: is any wire endpoint exactly on (X,Y)?
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
proc nlab {lab} {
  set n 0; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    if {[xschem getprop wire $k lab] eq $lab} { incr n }
  }
  return $n
}
# the wire that owns endpoint (X,Y); returns {a b c d} or {} if none
proc wire_on {X Y} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {($a==$X && $b==$Y) || ($c==$X && $d==$Y)} { return [list $a $b $c $d] }
  }
  return {}
}

set ref_before [pnet REF]; set led_before [pnet LED]
check "setup: REF/LED on distinct nets (REF=$ref_before LED=$led_before)" \
  [expr {$ref_before ne $led_before}]

# replay the interactive drag (-20,-10): press on x1, motion through RUBBER waypoints, release
xschem unselect_all
lassign [xschem instance_coord x1] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
xschem callback $WIN $BP $psx $psy 0 1 0 0
xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
set tx $psx; set ty $psy
foreach wp {{-10 0} {-20 0} {-20 -10}} {
  lassign $wp dx dy
  lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
  xschem callback $WIN $MOTION $tx $ty 0 0 0 $Button1Mask
}
xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord x1] a1 a2 nrx nry
check "x1 landed at (90,10)" [expr {$nrx==90 && $nry==10}] "got ($nrx,$nry)"

# pins after the (-20,-10) move (rot1):
#   REF 100,-130 -> 80,-140 ; LED 120,-130 -> 100,-140 ; TRIANG 80,80 -> 60,70 ; CTRL1 120,80 -> 100,70
set REFX 80;  set REFY -140
set LEDX 100; set LEDY -140

# ---- Defect A + B: REF/LED nets must SURVIVE and stay DISTINCT (no weld, no deletion) ----
set n1 [nlab #net1]; set n2 [nlab #net2]
check "B: #net1 survives (>=1 wire, got $n1)" [expr {$n1 >= 1}]
check "B: #net2 survives (>=1 wire, got $n2)" [expr {$n2 >= 1}]
set ref_conn [touched $REFX $REFY]
set led_conn [touched $LEDX $LEDY]
check "A: REF pin ($REFX,$REFY) stays connected (not orphaned)" $ref_conn
check "A: LED pin ($LEDX,$LEDY) stays connected (not orphaned)" $led_conn
set ref_after [pnet REF]; set led_after [pnet LED]
check "A: REF and LED stay on DISTINCT nets, no weld (REF=$ref_after LED=$led_after)" \
  [expr {$ref_conn && $led_conn && $ref_after ne $led_after}]
check "no diagonal wire remains" [expr {[ndiag]==0}] "diag=[ndiag]"

# ---- Defect C: first wire segment out of the moved TRIANG pin (60,70) must be VERTICAL ----
# lead is SOUTH, so the exit must be x-constant ((60,70)->(60,90)), not the horizontal staircase leg.
set TRX 60; set TRY 70
check "C: TRIANG pin ($TRX,$TRY) connected" [touched $TRX $TRY]
set tw [wire_on $TRX $TRY]
if {[llength $tw]==4} {
  lassign $tw a b c d
  set vertical [expr {$a==$c && $b!=$d}]
  check "C: first segment out of TRIANG pin is VERTICAL (no staircase), wire=[list $a $b $c $d]" $vertical
} else {
  check "C: first segment out of TRIANG pin is VERTICAL (no staircase)" 0 "no wire on ($TRX,$TRY)"
}

puts "PASS=$::npass FAIL=$::fails"
if {$::fails == 0} { puts "RESULT: ALL PASS"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED"; puts "OVERALL: FAIL" }
