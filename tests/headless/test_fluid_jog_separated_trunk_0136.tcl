# issue 0136 (before_39 -> after_40): a SE diagonal connected-drag of x1 (SANDBOX/solar_ctl, rot1) by
# delta (+60,+30) from before_39.sch. Accepted path = END attempt=0 leg-split (nlegs=2, diag_relay=0),
# partition clean. x1's DEVICE body box after the move is world x[120,160] y[-90,80]; the CTRL1 net
# reaches its naming label l1 (220,-20) through a STATIONARY vertical trunk at x=140 that the advancing
# body now ENGULFS.
#
#   DEFECT `body-engulfs-jog-separated-trunk`: the moved CTRL1 pin lands at (150,100); the trunk is at
#   x=140, one grid off-column, reached only through a JOG (150,130)->(140,130). fluid_shove_body_
#   crossing_backbone is PIN-INCIDENT (it seeds the perpendicular run at the moved pin's OWN column), so
#   the x=140 trunk is invisible to it (every pin declines corners=0); the diag_relay reroute/delete
#   family cannot pull it either (nearest outside-body anchor is the pin's own riser end (150,130), and
#   the trunk is load-bearing to the label). Result (after_40): CTRL1 saved as
#   `140 -20 140 130` + `140 -20 220 -20` -- the elbow (140,-20) sits STRICTLY inside the body and both
#   legs thread it.
#
# FIX (fluid_shove_jog_separated_trunk, move.c): shove such a PRE-EXISTING, LOAD-BEARING, jog-separated
# trunk one grid past the crossed body edge (x=140 -> x=170) and re-anchor its attachments; the CTRL1
# route becomes pin(150,100)->(150,130)->(170,130)->(170,-20)->label(220,-20), body-clear. Gated:
# pre-existing span (never a fresh reroute leg), bridge (never a redundant user-ring edge), follow-net
# only; body-free + DOUBLE partition-verified with exact revert (never worse).
#
# NEEDS A REAL X DISPLAY (the interactive multi-motion connected-drag arms the fluid pipeline;
# a headless --nogui select_at + move_objects does NOT move the instance). Self-skips with no display.
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_jog_separated_trunk_0136.tcl

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
# does any wire of net $want strictly ENTER the x1 DEVICE body box x(120,160) y(-90,80)?
proc net_crosses_body {want} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    if {[xschem getprop wire $k lab] ne $want} continue
    lassign [xschem wire_coord $k] a b c d
    if {$a==$c} {                                        ;# vertical at x=a
      if {$a>120 && $a<160} { set lo [expr {$b<$d?$b:$d}]; set hi [expr {$b<$d?$d:$b}]
        if {$lo<80 && $hi>-90} { return 1 } }
    } elseif {$b==$d} {                                  ;# horizontal at y=b
      if {$b>-90 && $b<80} { set lo [expr {$a<$c?$a:$c}]; set hi [expr {$a<$c?$c:$a}]
        if {$lo<160 && $hi>120} { return 1 } }
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

set ctrl1_before [pnet CTRL1]; set triang_before [pnet TRIANG]
check "setup: CTRL1/TRIANG on distinct nets (CTRL1=$ctrl1_before TRIANG=$triang_before)" \
  [expr {$ctrl1_before ne $triang_before}]

# replay the SE-diagonal drag (+60,+30): press on x1, motion waypoints, release
xschem unselect_all
lassign [xschem instance_coord x1] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
xschem callback $WIN $BP $psx $psy 0 1 0 0
xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
set tx $psx; set ty $psy
foreach wp {{10 10} {30 10} {40 20} {50 20} {60 30}} {
  lassign $wp dx dy
  lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
  xschem callback $WIN $MOTION $tx $ty 0 0 0 $Button1Mask
}
xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord x1] a1 a2 nrx nry
check "x1 landed at (140,40)" [expr {$nrx==140 && $nry==40}] "got ($nrx,$nry)"

# ---- P5: CTRL1 must NOT thread x1's body ----
check "0136: CTRL1 net does NOT cross the x1 body box (was 140 -20 140 130 + 140 -20 220 -20)" \
  [expr {![net_crosses_body CTRL1]}]
# the trunk shoved one grid past the RIGHT body edge (x=160) to x=170; its label leg + riser move with it
check "0136: CTRL1 trunk riser exists at x=170 (170 -20 170 130)" \
  [expr {[touched 170 -20] && [touched 170 130]}]
check "0136: no CTRL1 copper left on the old x=140 trunk column inside the body" \
  [expr {![touched 140 -20]}]

# ---- P1/P2: connectivity preserved, no merge ----
check "CTRL1 pin (150,100) stays connected" [touched 150 100]
set ctrl1_after [pnet CTRL1]; set triang_after [pnet TRIANG]
check "CTRL1 still reaches its label l1 (net name preserved: CTRL1)" [expr {$ctrl1_after eq {CTRL1}}]
check "TRIANG net preserved" [expr {$triang_after eq {TRIANG}}]
check "CTRL1/TRIANG stay distinct nets (no merge)" [expr {$ctrl1_after ne $triang_after}]
check "no diagonal wire remains" [expr {[ndiag]==0}] "diag=[ndiag]"

# ---- other nets untouched by the trunk shove (regression scope) ----
check "TRIANG does NOT cross the body" [expr {![net_crosses_body TRIANG]}]

puts "PASS=$::npass FAIL=$::fails"
if {$::fails == 0} { puts "RESULT: ALL PASS"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED"; puts "OVERALL: FAIL" }
