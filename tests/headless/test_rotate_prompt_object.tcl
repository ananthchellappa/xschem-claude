# Prompt-for-object rotate/flip — Cases 1, 2, 3 of the rotate-keep-connected feature.
# Spec: doc/claude/specs/rotate_keep_connected_stretch.md
#
# Case 2 (baseline, pre-existing): something selected + rotate verb -> rotate the
#         selection, ignoring wire connectivity.
# Case 1 (NEW): nothing selected + rotate/flip verb -> arm a "click an object to rotate"
#         prompt (ui_state MENUSTART); the next canvas click selects the object under the
#         cursor and applies the transform (PLAIN: wires NOT kept connected). ESC cancels;
#         a click on empty canvas cancels.
# Case 3 (NEW): nothing selected + an armed verb-noun stretch ('m' under cadence) + rotate
#         verb -> abandon the pending stretch, arm the rotate instead; the next click does a
#         PLAIN rotate (proof: the instance ROTATES and the wire does NOT follow, whereas a
#         still-pending stretch would pick the instance up to MOVE and never rotate it).
#
# Drives the REAL keyboard dispatch (handle_key_press, callback.c case 'R'/'F') +
# check_menu_start_commands (the Button1 consumer) via `xschem callback`. Sibling of
# test_cadence_stretch_move.tcl.
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_rotate_prompt_object.tcl

# --- X-availability gate: self-skip cleanly with no usable display -----------
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- rotate prompt-for-object test needs a real display"
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

# X11 event/mask/keysym constants
set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set ShiftMask 1 ; set Button1Mask 256
set KSYM_R 82 ; set KSYM_F 70 ; set KSYM_m 109 ; set KSYM_Esc 65307
set MENUSTART 65536 ; set STARTMOVE 32

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
proc inst_pos {n} { lrange [xschem instance_coord $n] 2 3 }
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
proc armed {} { expr {[xschem get ui_state] & $::MENUSTART ? 1 : 0} }
proc in_move {} { expr {[xschem get ui_state] & $::STARTMOVE ? 1 : 0} }

# KeyPress a verb at a canvas point (arms / or acts on selection)
proc kpress {ks sx sy {st 0}} {
  global KP WIN
  xschem callback $WIN $KP $sx $sy $ks 0 0 $st
  update idletasks
}
# Button1 click (press+release) at a canvas point
proc kclick {sx sy} {
  global BP BR Button1Mask WIN
  xschem callback $WIN $BP $sx $sy 0 1 0 0
  xschem callback $WIN $BR $sx $sy 0 1 0 $Button1Mask
  update idletasks
}

# Fresh fixture: res at origin + one wire from its pin M to a fixed far anchor.
proc setup_fixture {cadence} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0
  set ::cadence_compat $cadence
  xschem instance {res.sym} 0 0 0 0 {}
  set pc [xschem instance_pin_coord 0 name M]
  set px [lindex $pc 1]; set py [lindex $pc 2]
  xschem wire $px $py [expr {$px+300}] $py   ;# horizontal run, far end fixed
  xschem zoom_full; update idletasks
}

# === T1 — Case 2: selection present + rotate -> rotates, wire ignored =========
setup_fixture 0
lassign [inst_screen 0] sx sy
xschem select instance 0
set r0 [inst_rot 0]; set before [allwires]
kpress $KSYM_R $sx $sy $ShiftMask
check "T1  Case2 selected 'R' rotates the instance"          [expr {[inst_rot 0] ne $r0}]
check "T1b Case2 rotate leaves the wire unchanged (plain)"   [expr {[allwires] eq $before}]

# === T2 — Case 1: nothing selected + rotate -> arm, click rotates =============
setup_fixture 0
lassign [inst_screen 0] sx sy
xschem unselect_all
set r0 [inst_rot 0]; set before [allwires]
kpress $KSYM_R 3 3 $ShiftMask   ;# fire in empty space, nothing selected
check "T2  Case1 'R' on empty selection arms MENUSTART prompt" [expr {[armed] == 1}]
kclick $sx $sy                  ;# click the instance -> select + rotate
check "T2b Case1 click rotates the clicked instance"          [expr {[inst_rot 0] ne $r0}]
check "T2c Case1 rotate leaves the wire unchanged (plain)"    [expr {[allwires] eq $before}]
check "T2d Case1 prompt is consumed (MENUSTART cleared)"      [expr {[armed] == 0}]

# --- T2 ESC-cancel: arm then Escape -> disarmed, click does nothing ----------
setup_fixture 0
lassign [inst_screen 0] sx sy
xschem unselect_all
set r0 [inst_rot 0]
kpress $KSYM_R 3 3 $ShiftMask
check "T2e arm then ESC disarms"                             [expr {[armed] == 1}]
xschem callback $WIN $KP 3 3 $KSYM_Esc 0 0 0 ; update idletasks
check "T2f after ESC not armed"                             [expr {[armed] == 0}]
kclick $sx $sy
check "T2g after ESC a click does NOT rotate"               [expr {[inst_rot 0] eq $r0}]

# --- T2 empty-click-cancel: arm then click empty canvas ----------------------
setup_fixture 0
xschem unselect_all
set r0 [inst_rot 0]
kpress $KSYM_R 3 3 $ShiftMask
kclick 4 4                       ;# far from res/wire -> nothing under cursor
check "T2h Case1 click on empty canvas cancels (disarmed)"  [expr {[armed] == 0}]
check "T2i Case1 empty click rotates nothing"               [expr {[inst_rot 0] eq $r0}]
check "T2j Case1 empty click selects nothing"               [expr {[xschem get lastsel] == 0}]

# === T3 — Case 3: armed 'm' stretch + rotate -> abandon stretch, plain rotate =
setup_fixture 1                  ;# cadence_compat: 'm' = connected stretch verb
lassign [inst_screen 0] sx sy
xschem unselect_all
set r0 [inst_rot 0]; set before [allwires]
kpress $KSYM_m 3 3               ;# arm verb-noun STRETCH (MENUSTARTMOVE|MENUSTARTSTRETCH)
check "T3  'm' verb-noun arms a pending command"            [expr {[armed] == 1}]
kpress $KSYM_R 3 3 $ShiftMask    ;# rotate verb -> abandon stretch, arm rotate
check "T3b rotate verb keeps a pending command armed"       [expr {[armed] == 1}]
kclick $sx $sy                   ;# click the instance
check "T3c Case3 click ROTATES the instance (rotate path ran, not move)" [expr {[inst_rot 0] ne $r0}]
check "T3d Case3 is a PLAIN rotate: wire did NOT follow"    [expr {[allwires] eq $before}]
check "T3e Case3 no lingering move gesture"                 [expr {[in_move] == 0}]

# === T4 — Case 1 parity: flip verb also arms + flips on click ================
setup_fixture 0
lassign [inst_screen 0] sx sy
xschem unselect_all
set f0 [lindex [xschem instance_coord 0] 5]
kpress $KSYM_F 3 3 $ShiftMask
check "T4  Case1 'F' on empty selection arms the prompt"    [expr {[armed] == 1}]
kclick $sx $sy
check "T4b Case1 click flips the clicked instance"          [expr {[lindex [xschem instance_coord 0] 5] ne $f0}]

puts ""
if {$::fails == 0} {
  puts "RESULT: ALL PASS"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $::fails FAIL"
  puts "OVERALL: FAIL"
}
exit [expr {$::fails ? 1 : 0}]
