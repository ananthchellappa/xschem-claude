# Issue 0017 — grab a FREE wire vertex without pre-selecting.
# A press+drag on a dangling wire end should MOVE that end (toward=shorten, away=grow)
# and COMMIT ON RELEASE (no STARTWIRE / wire-draw mode), instead of starting a new wire.
#
# Drives the REAL press dispatch (handle_button_press, callback.c) via `xschem callback`.
# MUST run from repo ROOT under X:
#   ./src/xschem --pipe -q --script tests/headless/test_wire_vertex_grab.tcl
update idletasks
focus -force .drw
update idletasks

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}
proc result {} {
  puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]; flush stdout
  exit [expr {$::fails != 0}]
}

set BP 4 ; set BR 5 ; set MOTION 6
set ShiftMask 1 ; set ControlMask 4 ; set Button1Mask 256
set STARTWIRE 1   ;# ui_state bit (xschem.h)

proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}
proc drag1 {x1 y1 x2 y2 mod} {
  global BP BR MOTION Button1Mask
  xschem callback .drw $BP     $x1 $y1 0 1 0 $mod
  xschem callback .drw $MOTION $x2 $y2 0 0 0 [expr {$Button1Mask | $mod}]
  xschem callback .drw $BR     $x2 $y2 0 1 0 [expr {$Button1Mask | $mod}]
  update idletasks
}
# drag the schematic point (ax,ay) to (bx,by) with no modifiers
proc sdrag {ax ay bx by} {
  lassign [screen $ax $ay] x1 y1
  lassign [screen $bx $by] x2 y2
  drag1 $x1 $y1 $x2 $y2 0
}
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
proc norm {c} {
  lassign $c x1 y1 x2 y2
  if {$x1 < $x2 || ($x1==$x2 && $y1<=$y2)} { list $x1 $y1 $x2 $y2 } else { list $x2 $y2 $x1 $y1 }
}
proc has_wire {x1 y1 x2 y2} {
  set t [norm [list $x1 $y1 $x2 $y2]]
  foreach w [allwires] { if {[norm $w] eq $t} { return 1 } }
  return 0
}
proc in_wiredraw {} { expr {[xschem get ui_state] & $::STARTWIRE} }

# fresh lone free wire A=(0,0)-B=(100,0), cadence_compat on
proc setup {} {
  xschem clear force
  set ::cadence_compat 1
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0
  set ::cadsnap 10
  xschem wire 0 0 100 0
  xschem zoom_full
  update idletasks
  # make sure we are not stuck in any mode from a previous gesture
  catch {xschem callback .drw 9 0 0 0 0 0 0}
}

# === Case 1: SHORTEN — grab free end B=(100,0), drag toward A to (60,0) ============
setup
sdrag 100 0 60 0
check "shorten: exactly one wire" [expr {[xschem get wires] == 1}]
check "shorten: wire is (0,0)-(60,0)" [has_wire 0 0 60 0]
check "shorten: not left in wire-draw mode" [expr {![in_wiredraw]}]

# === Case 2: GROW — grab free end B=(100,0), drag away to (150,0) =================
setup
sdrag 100 0 150 0
check "grow: exactly one wire" [expr {[xschem get wires] == 1}]
check "grow: wire is (0,0)-(150,0)" [has_wire 0 0 150 0]
check "grow: not left in wire-draw mode" [expr {![in_wiredraw]}]

# === Case 3 (guard): a CONNECTED endpoint (junction) must NOT be grabbed ==========
# Two wires share J=(100,0): horizontal (0,0)-(100,0) + vertical (100,0)-(100,50).
# Pressing J and dragging must NOT shorten the horizontal wire (J is not free -> falls
# through to add_wire_from_wire / new wire, the pre-0017 behavior).
setup
xschem wire 100 0 100 50
xschem zoom_full; update idletasks
sdrag 100 0 60 0
check "junction: horizontal wire NOT shortened (still 0,0-100,0)" [has_wire 0 0 100 0]
check "junction: vertical wire intact (100,0-100,50)" [has_wire 100 0 100 50]

# === Case 4 (guard): stock cadence_compat=0 -> free end NOT grabbed (unchanged) ====
setup
set ::cadence_compat 0
sdrag 100 0 60 0
check "stock(cadence off): free end NOT grabbed, wire keeps length (0,0-100,0)" \
  [has_wire 0 0 100 0]

result
