# Phase 3c (c2): proves the binding-table dispatch is CONTEXT-AWARE with
# most-specific-wins precedence: an exact-context row beats a context-independent
# (global) row, and a global row is the fallback when no specific row exists.
# Tested with canvas-context events only (no graph fixture needed); the
# over_graph context is exercised later (c3/c6) once graph routing is migrated.
# Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_binding_precedence.tcl
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
# wheel-up, no modifier, on the canvas (ButtonPress=4, Button4=4, state 0)
proc wheel {} { xschem callback .drw 4 400 300 0 4 0 0; update idletasks }

# Discriminator: view.zoom_in changes `zoom`; view.pan_up never touches `zoom`
# (it only moves yorigin). So "did zoom change?" cleanly tells which action ran.

# default: wheel up 0 canvas -> view.zoom_in. Add a GLOBAL row for the same signature.
xschem bind wheel up 0 global view.pan_up
set dump [xschem bindings dump]
check "canvas+global rows both present" [expr {
  [lsearch -exact $dump {wheel up 0 canvas view.zoom_in}] >= 0 &&
  [lsearch -exact $dump {wheel up 0 global view.pan_up}] >= 0 }] {}

# (a) specific context wins: canvas wheel-up runs zoom_in, NOT the global pan
set z0 [xschem get zoom]
wheel
set z1 [xschem get zoom]
check "specific (canvas) beats global" [expr {$z1 != $z0}] "(zoom $z0 -> $z1)"

# (b) global is the fallback: drop the canvas row, same event now hits the global row
xschem unbind wheel up 0 canvas
set z0 [xschem get zoom]
set y0 [xschem get yorigin]
wheel
check "global fallback: zoom unchanged" [expr {[xschem get zoom] == $z0}] "(z=$z0)"
check "global fallback: pan ran (yorigin moved)" [expr {[xschem get yorigin] != $y0}] "(y0=$y0)"

# restore defaults so the process leaves a clean table
xschem unbind wheel up 0 global
xschem bind wheel up 0 canvas view.zoom_in
set z0 [xschem get zoom]
wheel
check "restored: canvas zoom_in again" [expr {[xschem get zoom] != $z0}] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
