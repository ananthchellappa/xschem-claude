# Phase 3a: proves mouse-wheel input is DATA-DRIVEN through the C binding table.
#  1. Built-in defaults reproduce the previous hard-coded wheel behavior exactly
#     (wheel = zoom, Ctrl/Shift+wheel = pan, same view_zoom factor / pan delta).
#  2. `xschem bindings dump` reports those defaults.
#  3. `xschem bind` remaps a wheel signature at runtime (wheel-up -> pan, not zoom).
#  4. `xschem unbind` removes a binding (wheel-up then does nothing).
# Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_mouse_bindings.tcl
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
# float "almost equal" with relative tolerance
proc approx {a b} { expr {abs($a-$b) <= 1e-9*(abs($a)+abs($b)+1e-30)} }

# X11 event/modifier constants
set BP 4        ;# ButtonPress
set B_UP 4      ;# Button4 = wheel up
set B_DOWN 5    ;# Button5 = wheel down
set M_NONE 0
set M_SHIFT 1   ;# ShiftMask
set M_CTRL 4    ;# ControlMask
set MX 400
set MY 300

# drive one wheel event through the real C dispatch path (callback -> wheel)
proc wheel {button state} {
  global BP MX MY
  xschem callback .drw $BP $MX $MY 0 $button 0 $state
  update idletasks
}

# CADZOOMSTEP / CADMOVESTEP from xschem.h
set ZSTEP 1.2
set MSTEP 200

# --- 1. defaults: wheel-up zooms in (zoom /= 1.2) ---
set z0 [xschem get zoom]
wheel $B_UP $M_NONE
set z1 [xschem get zoom]
check "wheel-up zooms in"  [approx $z1 [expr {$z0/$ZSTEP}]] "(z0=$z0 z1=$z1)"

# wheel-down zooms out (zoom *= 1.2) -> back to z0
wheel $B_DOWN $M_NONE
set z2 [xschem get zoom]
check "wheel-down zooms out" [approx $z2 $z0] "(z2=$z2)"

# --- 1b. Ctrl+wheel-up pans up: yorigin += -MSTEP*zoom/2 ---
set zoom [xschem get zoom]
set y0 [xschem get yorigin]
wheel $B_UP $M_CTRL
set y1 [xschem get yorigin]
check "Ctrl+wheel-up pans (y)" [approx $y1 [expr {$y0 + (-$MSTEP*$zoom/2.0)}]] "(y0=$y0 y1=$y1)"
check "Ctrl+wheel-up keeps zoom" [approx [xschem get zoom] $zoom] {}

# --- 1c. Shift+wheel-up pans left: xorigin += -MSTEP*zoom/2 ---
set zoom [xschem get zoom]
set x0 [xschem get xorigin]
wheel $B_UP $M_SHIFT
set x1 [xschem get xorigin]
check "Shift+wheel-up pans (x)" [approx $x1 [expr {$x0 + (-$MSTEP*$zoom/2.0)}]] "(x0=$x0 x1=$x1)"

# --- 2. bindings dump lists the 6 built-in canvas wheel defaults ---
# (count wheel rows in the canvas context; other devices/contexts add their own)
set dump [xschem bindings dump]
set nwheel 0
foreach row $dump { if {[lindex $row 0] eq "wheel" && [lindex $row 3] eq "canvas"} { incr nwheel } }
check "dump has 6 canvas wheel rows" [expr {$nwheel == 6}] "(=> $nwheel of [llength $dump] total)"
check "dump: wheel up 0 -> zoom_in" \
  [expr {[lsearch -exact $dump {wheel up 0 canvas view.zoom_in}] >= 0}] {}
check "dump: wheel up ctrl -> pan_up" \
  [expr {[lsearch -exact $dump {wheel up ctrl canvas view.pan_up}] >= 0}] {}

# --- 3. remap: bind wheel-up (no mod) to pan_up instead of zoom_in ---
xschem bind wheel up 0 canvas view.pan_up
set zoom [xschem get zoom]
set y0 [xschem get yorigin]
wheel $B_UP $M_NONE
check "remapped wheel-up keeps zoom" [approx [xschem get zoom] $zoom] {}
check "remapped wheel-up now pans"   [approx [xschem get yorigin] [expr {$y0 + (-$MSTEP*$zoom/2.0)}]] {}

# unknown action id is rejected
set rc [catch {xschem bind wheel up 0 canvas view.nope} err]
check "bind rejects unknown action" [expr {$rc != 0}] "(=> $err)"

# --- 4. unbind: wheel-up does nothing ---
check "unbind removes one" [expr {[xschem unbind wheel up 0 canvas] == 1}] {}
set zoom [xschem get zoom]
set y0 [xschem get yorigin]
wheel $B_UP $M_NONE
check "unbound wheel-up is inert" \
  [expr {[approx [xschem get zoom] $zoom] && [approx [xschem get yorigin] $y0]}] {}

# --- restore default so later windows/runs are unaffected ---
xschem bind wheel up 0 canvas view.zoom_in
set z0 [xschem get zoom]
wheel $B_UP $M_NONE
check "restored wheel-up zooms in" [approx [xschem get zoom] [expr {$z0/$ZSTEP}]] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
