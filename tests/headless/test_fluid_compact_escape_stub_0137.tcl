# issue 0137 (before_41): fluid connected-drag must leave MINIMUM copper on every move.
#
# Fixture before_41.sch: res R1 @ (100,100). Its TOP pin P (100,70) escapes NORTH (0,-1); the net
# routes up-and-over to a destination BELOW/SOUTH at (130,90) via a 1-grid escape stub -- the minimal
# P3-respecting route:
#     P(100,70) -> (100,60) [escape stub, 1 grid north] -> (130,60) [over] -> (130,90) [down to dest]
#   total copper = 10 + 30 + 30 = 70.
#
# DEFECT `escape-stub-overshoot-not-reclaimed`: drag R1 UP by D (pin pushes north; the push-through slide
# shoves the horizontal jog up to y=60-D, staying connected -- "perfect"), then drag R1 back DOWN by D
# (pin recedes south). On the RETREAT nothing PULLS the shoved jog back: the horizontal is now pre-existing
# START copper, so fluid_straighten_reversals (novel-span gate, move.c:3589) and
# fluid_collapse_axis_overshoot_stub (START-deg==0 dangle gate) both skip it. The escape stub is left
# stretched to 10+D and the down-leg to 30+D -- excess = 2*D copper, growing without bound per round trip
# (D=30 -> copper 130 vs 70; D=60 -> 190). Connected, no short: a pure minimum-copper / beautification defect.
#
# FIX: an END compaction pass slides a moved pin's over-long perpendicular escape stub back inward along
# the lead normal to the minimal 1 grid (pulling its attached jog + far leg with it), stopping before any
# collision / foreign contact; double partition-verified, exact revert (never worse).
#
# NEEDS A REAL X DISPLAY (the interactive multi-motion connected-drag arms the fluid pipeline; a headless
# --nogui move_objects does NOT move the instance). Self-skips with no display.
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_compact_escape_stub_0137.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
for {set i 0} {$i < 40} {incr i} {
  if {![catch {winfo viewable $WIN} vv] && $vv} break
  update idletasks; after 100; update
}
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- drag test needs a real display"
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

xschem load [file join $repo tests/from_user/before_41.sch]
xschem set readonly 0
catch { xschem set fluid_editing 1 }
catch { xschem set orthogonal_wiring 1 }
catch { xschem set intuitive_interface 1 }
xschem zoom_full; update idletasks

proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$zm))}] [expr {int(round(($sy+$yo)/$zm))}]
}
proc copper {} { set nw [xschem get wires]; set t 0
  for {set k 0} {$k<$nw} {incr k} { lassign [xschem wire_coord $k] a b c d; set t [expr {$t+abs($c-$a)+abs($d-$b)}] }
  return $t }
proc touched {X Y} {
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {($a==$X && $b==$Y) || ($c==$X && $d==$Y)} { return 1 }
  }
  return 0
}
proc nnets {} {  ;# distinct net labels over all wires (1 == still one connected net, no orphan split)
  set s {}; set nw [xschem get wires]
  for {set k 0} {$k<$nw} {incr k} { lappend s [xschem getprop wire $k lab] }
  return [llength [lsort -unique $s]]
}
proc ndiag {} { set n 0; set nw [xschem get wires]
  for {set k 0} {$k<$nw} {incr k} { lassign [xschem wire_coord $k] a b c d
    if {$a!=$c && $b!=$d} { incr n } }
  return $n }
proc wiredump {} { set nw [xschem get wires]; set s {}
  for {set k 0} {$k<$nw} {incr k} { lassign [xschem wire_coord $k] a b c d
    lappend s [format {%s:%d,%d-%d,%d} [xschem getprop wire $k lab] $a $b $c $d] }
  return [join $s "  "] }
proc drag {dx dy} {
  global WIN BP BR MOTION Button1Mask
  xschem unselect_all
  lassign [xschem instance_coord R1] j1 j2 rx ry
  lassign [screen $rx $ry] psx psy
  xschem callback $WIN $BP $psx $psy 0 1 0 0
  xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
  set tx $psx; set ty $psy
  set steps [expr {abs($dx)+abs($dy)}]; if {$steps<1} {set steps 1}
  for {set s 1} {$s <= $steps} {incr s} {
    set fx [expr {$rx + int(round(double($dx)*$s/$steps))}]
    set fy [expr {$ry + int(round(double($dy)*$s/$steps))}]
    lassign [screen $fx $fy] tx ty
    xschem callback $WIN $MOTION $tx $ty 0 0 0 $Button1Mask
  }
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

check "setup: single connected net, copper=70" [expr {[nnets]==1 && [copper]==70}] "copper=[copper] nets=[nnets]"

# drag UP 30 (pin 100,70 -> 100,40), then back DOWN 30 (pin -> 100,70)
drag 0 -30
drag 0 30
lassign [xschem instance_coord R1] a1 a2 rx ry
puts "  after up30/dn30: R1=($rx,$ry) copper=[copper] | [wiredump]"

check "R1 back at origin (100,100)" [expr {$rx==100 && $ry==100}] "got ($rx,$ry)"
check "still ONE connected net (no orphan split)" [expr {[nnets]==1}] "nets=[nnets]"
check "no diagonal wire" [expr {[ndiag]==0}] "diag=[ndiag]"
# --- the compaction assertions (RED before fix, GREEN after) ---
check "0137: total copper reclaimed to minimal 70 (was 130)" [expr {[copper]==70}] "copper=[copper]"
check "0137: escape stub compacted to 1 grid -- stub (100,60)-(100,70) present" \
  [expr {[touched 100 60] && [touched 100 70]}]
check "0137: horizontal jog pulled back to y=60 (not stranded high)" [touched 130 60]
check "0137: no copper stranded north of the escape row (nothing at y<60 on col x=100)" \
  [expr {![touched 100 50] && ![touched 100 40] && ![touched 100 30]}]

puts "PASS=$::npass FAIL=$::fails"
if {$::fails == 0} { puts "RESULT: ALL PASS"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED"; puts "OVERALL: FAIL" }
