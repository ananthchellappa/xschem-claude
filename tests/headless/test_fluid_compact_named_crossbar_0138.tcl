# issue 0138 (before_39 -> after_41): fluid multi-motion connected-drag must compact NAMED nets too.
#
# Fixture before_39.sch: x1 = SANDBOX/solar_ctl rot1 @ (80,10). It has two SOUTH-lead output pins that
# route to lab_pins on the right: TRIANG pin (50,70) -> l0 (220,20); CTRL1 pin (90,70) -> l1 (220,-20)
# (CTRL1 via an x=140 trunk). Both pins escape SOUTH (their lead normal), so each net dips below the pin
# then rises to its label.
#
# DEFECT `named-net escape-stub overshoot not reclaimed` (two named sub-problems, see the 0134 memory):
#   1. push-only-retreat-slack: a multi-motion jiggle drag (down to a deep excursion, then back up) pushes
#      each crossbar OUT to the pin's low-water mark, then never PULLS it back on the return.
#   2. explicit-label reclaim carve-out (ROOT): fluid_straighten_reversals' min-copper reclaim
#      (fluid_jog_is_moved_pin_escape_overshoot) BAILED on any wire whose lab is explicit (non-'#')
#      -- move.c:3578 / :3594 / the pass-1 :3687 skip. So #net1/#net2 (auto) compacted every gesture but
#      TRIANG/CTRL1 (named) were left stranded (after_41: TRIANG crossbar y=150, CTRL1 y=160).
#
# FIX (0138): admit a VERIFIED escape-stub overshoot on explicit nets (the slide is a pure same-net inward
# shorten; the partition + foreign-copper verify keeps it rename/merge-safe). Plus an outward search: when
# the minimal 1-grid escape row is foreign-blocked by a sibling that already took it (TRIANG holds y=130
# across the full width), step out grid-by-grid to the nearest CLEAR row (CTRL1 -> y=140, crossing TRIANG's
# crossbar perpendicularly at (140,130) -- a legal cross, not a short).
#
# Minimal result: TRIANG copper 300 (crossbar y=130), CTRL1 copper 320 (crossbar y=140); down from 340/360.
#
# NEEDS A REAL X DISPLAY (the interactive multi-motion connected-drag arms the fluid pipeline; a headless
# --nogui move_objects does NOT move the instance). Self-skips with no display.
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_compact_named_crossbar_0138.tcl

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
proc netcopper {net} { set nw [xschem get wires]; set t 0
  for {set k 0} {$k<$nw} {incr k} { if {[xschem getprop wire $k lab] eq $net} {
    lassign [xschem wire_coord $k] a b c d; set t [expr {$t+abs($c-$a)+abs($d-$b)}] } }
  return $t }
proc nnets {} { set s {}; set nw [xschem get wires]
  for {set k 0} {$k<$nw} {incr k} { lappend s [xschem getprop wire $k lab] }
  return [llength [lsort -unique $s]] }
proc ndiag {} { set n 0; set nw [xschem get wires]
  for {set k 0} {$k<$nw} {incr k} { lassign [xschem wire_coord $k] a b c d
    if {$a!=$c && $b!=$d} { incr n } }
  return $n }
proc seg {net X1 Y1 X2 Y2} { ;# is there a wire of net `net` with exactly these endpoints (either order)
  set nw [xschem get wires]
  for {set k 0} {$k<$nw} {incr k} {
    if {[xschem getprop wire $k lab] ne $net} continue
    lassign [xschem wire_coord $k] a b c d
    if {($a==$X1 && $b==$Y1 && $c==$X2 && $d==$Y2) || ($a==$X2 && $b==$Y2 && $c==$X1 && $d==$Y1)} {return 1}
  }
  return 0 }
proc onnet {net X Y} { ;# does net `net` touch grid point (X,Y) as an endpoint
  set nw [xschem get wires]
  for {set k 0} {$k<$nw} {incr k} {
    if {[xschem getprop wire $k lab] ne $net} continue
    lassign [xschem wire_coord $k] a b c d
    if {($a==$X && $b==$Y) || ($c==$X && $d==$Y)} {return 1}
  }
  return 0 }
proc wiredump {} { set nw [xschem get wires]; set s {}
  for {set k 0} {$k<$nw} {incr k} { lassign [xschem wire_coord $k] a b c d
    lappend s [format {%s:%d,%d-%d,%d} [xschem getprop wire $k lab] $a $b $c $d] }
  return [join $s "  "] }
proc drag {dx dy} {
  global WIN BP BR MOTION Button1Mask
  xschem unselect_all
  lassign [xschem instance_coord x1] j1 j2 rx ry
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

check "setup: 4 nets, no diagonal" [expr {[nnets]==4 && [ndiag]==0}] "nets=[nnets] diag=[ndiag]"

# faithful reproduction of the user's /tmp/Xschem.log.7 gesture (6-move jiggle producing after_41.sch):
# instance-origin y visits 10->30->0->20->50->80(x->70)->60 -- a deep DOWN excursion then partial retreat.
drag 0 20
drag 0 -30
drag 0 20
drag 0 30
drag -10 30
drag 0 -20
lassign [xschem instance_coord x1] a1 a2 rx ry
puts "  after jiggle: x1=($rx,$ry) TRIANG=[netcopper TRIANG] CTRL1=[netcopper CTRL1] | [wiredump]"

check "x1 landed at (70,60)"                [expr {$rx==70 && $ry==60}] "got ($rx,$ry)"
check "still 4 distinct nets (no merge/short)" [expr {[nnets]==4}] "nets=[nnets]"
check "no diagonal wire"                    [expr {[ndiag]==0}] "diag=[ndiag]"

# --- TRIANG compaction (RED before fix: copper 340, crossbar stranded at y=150) ---
check "0138: TRIANG copper reclaimed to 300 (was 340)" [expr {[netcopper TRIANG]==300}] "copper=[netcopper TRIANG]"
check "0138: TRIANG crossbar pulled up to y=130"       [seg TRIANG 40 130 220 130]
check "0138: TRIANG escape stub is 1 grid (40,120)-(40,130)" [seg TRIANG 40 120 40 130]
check "0138: TRIANG not stranded low (nothing at y=150 col x=40)" [expr {![onnet TRIANG 40 150]}]

# --- CTRL1 compaction (RED before fix: copper 360, crossbar stranded at y=160) ---
# CTRL1's ideal 1-grid row (y=130) is taken by TRIANG's full-width crossbar, so it lands one grid out (y=140).
check "0138: CTRL1 copper reclaimed to 320 (was 360)"  [expr {[netcopper CTRL1]==320}] "copper=[netcopper CTRL1]"
check "0138: CTRL1 crossbar at y=140 (80,140)-(140,140)" [seg CTRL1 80 140 140 140]
check "0138: CTRL1 escape stub (80,120)-(80,140)"        [seg CTRL1 80 120 80 140]
check "0138: CTRL1 not stranded low (nothing at y=160 col x=80)" [expr {![onnet CTRL1 80 160]}]
check "0138: CTRL1 still reaches l1 feed (140,-20)-(220,-20)" [seg CTRL1 140 -20 220 -20]

puts "PASS=$::npass FAIL=$::fails"
if {$::fails == 0} { puts "RESULT: ALL PASS"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED"; puts "OVERALL: FAIL" }
