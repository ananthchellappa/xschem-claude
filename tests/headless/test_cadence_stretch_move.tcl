# Cadence stretch/move KEYBOARD verbs, gated on cadence_compat.
# Spec: doc/claude/specs/cadence_stretch_move_keys.md  (FAQ Q28 gap #2).
#
# With cadence_compat=1:
#   'm'      -> STRETCH (connected): selection follows cursor, attached wires reroute.
#              noun-verb (pre-selected) picks up now; verb-noun (nothing selected)
#              prompts + the next click selects AND picks up.
#   Shift+M  -> MOVE (rigid/disconnected): only the selection moves, wires stay put.
# With cadence_compat=0: unchanged (plain 'm' = enable_stretch-driven; 'M' = kissing).
#
# Drives the REAL keyboard dispatch (handle_key_press, callback.c case 'm'/'M') via
# `xschem callback` KeyPress (type 2) + MOTION (6) + Button1 click (4/5). Keyboard
# sibling of test_cadence_drag.tcl.
#
# Controlled fixture: ONE res with ONE wire from its pin M to a fixed far anchor, so
# autotrim_wires (forced on by cadence) cannot add spurious wire splits. A CONNECTED
# move makes the wire change (near end follows the pin); a DISCONNECTED move leaves the
# wire byte-identical. Fresh fixture per case -> no cross-test state leak.
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_cadence_stretch_move.tcl
#
# RED-first: before the fix, cadence 'm' was DISCONNECTED (wire unchanged) so A/B fail,
# and Shift+M was a kissing move (wire changed) so C fails.

# --- X-availability gate: self-skip cleanly with no usable display -----------
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- cadence stretch/move keyboard test needs a real display"
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

# X11 event/mask constants
set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set ShiftMask 1 ; set Button1Mask 256
set KSYM_m 109 ; set KSYM_M 77

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
proc inst_pos {n} { lrange [xschem instance_coord $n] 2 3 }
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}

# noun-verb keyboard move: object already selected. KeyPress verb at body anchor
# (move START), MOTION carries the object to the destination (RUBBER updates the
# delta), Button1 click drops (END commits).
proc kmove_nounverb {ks sx sy dx dy {st 0}} {
  global KP BP BR MOTION Button1Mask WIN
  set tx [expr {$sx+$dx}]; set ty [expr {$sy+$dy}]
  xschem callback $WIN $KP     $sx $sy $ks 0 0 $st
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP     $tx $ty 0 1 0 0
  xschem callback $WIN $BR     $tx $ty 0 1 0 $Button1Mask
  update idletasks
}
# verb-noun keyboard move: nothing selected. KeyPress verb (arms MENUSTART), click on
# object to select+pickup, MOTION to destination, Button1 click to drop.
proc kmove_verbnoun {ks px py sx sy dx dy {st 0}} {
  global KP BP BR MOTION Button1Mask WIN
  xschem unselect_all
  set tx [expr {$sx+$dx}]; set ty [expr {$sy+$dy}]
  xschem callback $WIN $KP     $px $py $ks 0 0 $st
  xschem callback $WIN $BP     $sx $sy 0 1 0 0
  xschem callback $WIN $BR     $sx $sy 0 1 0 $Button1Mask
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP     $tx $ty 0 1 0 0
  xschem callback $WIN $BR     $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

# Fresh fixture: res at origin + one wire from its pin M to a fixed far anchor.
proc setup_fixture {cadence stretch} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch $stretch
  set ::cadence_compat $cadence
  xschem instance {res.sym} 0 0 0 0 {}
  set pc [xschem instance_pin_coord 0 name M]
  set px [lindex $pc 1]; set py [lindex $pc 2]
  xschem wire $px $py [expr {$px+300}] $py   ;# horizontal run, far end fixed
  xschem zoom_full; update idletasks
}

# === A — cadence 'm' (noun-verb) = STRETCH: wire follows ====================
setup_fixture 1 0
lassign [inst_screen 0] sx sy
xschem select instance 0
set before [allwires]; set p0 [inst_pos 0]
kmove_nounverb $KSYM_m $sx $sy 30 30
check "A1  cadence 'm' moves the res (noun-verb)"        [expr {[inst_pos 0] ne $p0}]
check "A1b cadence 'm' the attached wire follows/reroutes" [expr {[allwires] ne $before}]

# === B — cadence 'm' (verb-noun) = STRETCH: wire follows ====================
setup_fixture 1 0
lassign [inst_screen 0] sx sy
set before [allwires]; set p0 [inst_pos 0]
kmove_verbnoun $KSYM_m $sx $sy $sx $sy 30 30
check "B1  cadence 'm' verb-noun moves the res"          [expr {[inst_pos 0] ne $p0}]
check "B1b cadence 'm' verb-noun the attached wire follows" [expr {[allwires] ne $before}]

# === C — cadence Shift+M = MOVE (disconnected): wire stays put ==============
setup_fixture 1 0
lassign [inst_screen 0] sx sy
xschem select instance 0
set before [allwires]; set p0 [inst_pos 0]; set i0 [xschem get instances]
kmove_nounverb $KSYM_M $sx $sy 30 30 $ShiftMask
check "C1  cadence Shift+M moves the res"                [expr {[inst_pos 0] ne $p0}]
check "C1b cadence Shift+M leaves the wire unchanged (disconnected)" [expr {[allwires] eq $before}]
check "C1c cadence Shift+M is a move not a copy (count unchanged)"   [expr {[xschem get instances] == $i0}]

# === D — cadence OFF: stock behavior unchanged (regression) ================
# D(i): plain 'm', enable_stretch=0 -> disconnected (wire unchanged).
setup_fixture 0 0
lassign [inst_screen 0] sx sy
xschem select instance 0
set before [allwires]; set p0 [inst_pos 0]
kmove_nounverb $KSYM_m $sx $sy 30 30
check "D1  non-cadence 'm' still moves the res"          [expr {[inst_pos 0] ne $p0}]
check "D1b non-cadence 'm' leaves wire unchanged (enable_stretch=0 stock)" [expr {[allwires] eq $before}]
# D(ii): plain 'm', enable_stretch=1 -> stock stretch, wire follows (proves the
# non-cadence path is untouched and still honors enable_stretch).
setup_fixture 0 1
lassign [inst_screen 0] sx sy
xschem select instance 0
set before [allwires]; set p0 [inst_pos 0]
kmove_nounverb $KSYM_m $sx $sy 30 30
check "D2  non-cadence 'm' with enable_stretch=1 moves the res" [expr {[inst_pos 0] ne $p0}]
check "D2b non-cadence 'm' with enable_stretch=1 stretches the wire" [expr {[allwires] ne $before}]

# === E — cadence 'm' verb-noun on empty canvas: cancels cleanly, no crash ==
setup_fixture 1 0
xschem unselect_all
set i0 [xschem get instances]; set w0 [xschem get wires]
# arm + pickup + drop all in empty space (far from the res/wire)
kmove_verbnoun $KSYM_m 3 3 6 6 20 20
check "E1  verb-noun 'm' on empty canvas leaves object counts unchanged" \
  [expr {[xschem get instances] == $i0 && [xschem get wires] == $w0}]
check "E1b verb-noun 'm' on empty canvas leaves nothing selected" \
  [expr {[xschem get lastsel] == 0}]

puts ""
if {$::fails == 0} {
  puts "RESULT: ALL PASS"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $::fails FAIL"
  puts "OVERALL: FAIL"
}
exit [expr {$::fails ? 1 : 0}]
