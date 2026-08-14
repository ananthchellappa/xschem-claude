# Phase 3b: proves the right-drag zoom-rectangle GESTURE is data-driven through the
# C binding table — the initiating chord is a table lookup, while the rubber-band
# (motion) and completion (release) stay in C, keyed off ui_state STARTZOOM.
#  1. The default binding exists (button 3 0 canvas -> view.zoom_rect).
#  2. A full press->drag->release gesture starts (STARTZOOM set), zooms, and ends
#     (STARTZOOM cleared) — i.e. identical to the old hard-coded right-drag.
#  3. Unbinding the chord makes button-3 press inert (no STARTZOOM): proof the
#     dispatch — not hard-coded C — drives it. Rebinding restores it.
# Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_gesture_bindings.tcl
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# X11 constants
set BP 4         ;# ButtonPress
set BR 5         ;# ButtonRelease
set MOTION 6     ;# MotionNotify
set B3 3         ;# Button3
set B3MASK 1024  ;# Button3Mask (1<<10)
set STARTZOOM 128

proc startzoom_set {} { global STARTZOOM; expr {([xschem get ui_state] & $STARTZOOM) != 0} }

# press button3 (no modifiers) at (x,y)
proc press {x y} { global BP B3; xschem callback .drw $BP $x $y 0 $B3 0 0; update idletasks }
# drag (motion with Button3 held) to (x,y)
proc drag {x y}  { global MOTION B3MASK; xschem callback .drw $MOTION $x $y 0 0 0 $B3MASK; update idletasks }
# release button3 at (x,y)
proc release {x y} { global BR B3 B3MASK; xschem callback .drw $BR $x $y 0 $B3 0 $B3MASK; update idletasks }

# --- 1. default binding present ---
check "default button3 zoom_rect bound" \
  [expr {[lsearch -exact [xschem bindings dump] {button 3 0 canvas view.zoom_rect}] >= 0}] {}

# --- 2. full gesture: start -> drag -> end ---
set z0 [xschem get zoom]
press 200 200
check "press sets STARTZOOM"      [startzoom_set] {}
drag 600 480
release 600 480
check "release clears STARTZOOM"  [expr {![startzoom_set]}] {}
set z1 [xschem get zoom]
check "gesture changed zoom"      [expr {$z1 != $z0}] "(z0=$z0 z1=$z1)"

# --- 3. unbind -> press is inert (proves it was the table, not hard-coded C) ---
check "unbind removes one"        [expr {[xschem unbind button 3 0 canvas] == 1}] {}
check "unbound: dump lost row" \
  [expr {[lsearch -exact [xschem bindings dump] {button 3 0 canvas view.zoom_rect}] < 0}] {}
press 250 250
check "unbound press: no STARTZOOM" [expr {![startzoom_set]}] {}
# (no STARTZOOM pending, so nothing to release/clean up)

# --- 3b. rebind -> gesture works again ---
xschem bind button 3 0 canvas view.zoom_rect
press 250 250
check "rebound press sets STARTZOOM" [startzoom_set] {}
drag 500 400
release 500 400
check "rebound release clears STARTZOOM" [expr {![startzoom_set]}] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
