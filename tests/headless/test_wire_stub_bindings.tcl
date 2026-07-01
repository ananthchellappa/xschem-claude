# B6 wire-stubs invocation (doc/claude/specs/wire_stub_netlabel.md §4.8): SPACE is
# released from the hardcoded C `case ' '` into three rebindable actions. SPACE now
# DEFAULTS to edit.add_pin_stubs, which SELF-GATES: mid-gesture or with an empty
# selection it declines (dispatch returns 0) and falls through to the case ' '
# fallback -- so the historical SPACE behaviors (cycle the manhattan corner during a
# move/wire/line, else drag-pan) are preserved from the SAME extracted cores.
#
# This drives the REAL key dispatch via `xschem callback`, so it needs a window:
#   1. default binding present (key 32 0 canvas -> edit.add_pin_stubs)
#   2. SPACE with a selection (idle)  -> add_pin_stubs runs (stubs+labels), NOT a pan
#   3. SPACE with no selection (idle) -> a drag-pan starts (STARTPAN), NO stubs
#   4. SPACE mid wire-gesture         -> the manhattan corner cycles: gesture intact,
#                                        NO pan, NO stubs (self-gate declined -> fallback)
#   5. unbind SPACE -> SPACE+selection adds NO stubs (proves the BINDING drove it, not
#      the case ' ' fallback); rebinding restores add_pin_stubs.
#
# Run under X with --pipe from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_wire_stub_bindings.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}

# X11 constants
set KP 2          ;# KeyPress
set MOTION 6      ;# MotionNotify
set SPACE 32      ;# space keysym
set STARTWIRE 1
set STARTPAN 512

proc st {} { xschem get ui_state }
# press SPACE (no modifiers) at screen-ish coords (mx,my only matter for the pan path)
proc space {{x 300} {y 300}} { global KP SPACE; xschem callback .drw $KP $x $y $SPACE 0 0 0; update idletasks }

# A read-only SPACE must PAN, not pop a modal dialog. Stub tk_messageBox so that if a
# regression re-introduces the old readonly_block() dialog the test FAILS cleanly (the pan
# assertion goes false) instead of hanging the headless run on a blocking messagebox.
catch {rename tk_messageBox {}} ; proc tk_messageBox {args} { return ok }

# wait for a real, mapped canvas (WSLg can be slow to map the window)
proc ready {} {
  catch {wm geometry . 1000x800}
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo ismapped .drw] && [winfo width .drw] > 300 && [winfo height .drw] > 300} break
  }
  xschem zoom_full; update idletasks
}
ready

# fixture: a 4-pin block symbol with all pins UNCONNECTED (so add_pin_stubs produces stubs)
set here [file dirname [file normalize [info script]]]
set wd   $here/wire_stub_bindings_work
file delete -force $wd; file mkdir $wd
set sym $wd/blk.sym
set fp [open $sym w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nK {type=subcircuit}\nV {}\nS {}\nE {}"
puts $fp "B 5 -22.5 -2.5 -17.5 2.5 {name=L dir=in show_pinname=true}"
puts $fp "B 5 17.5 -2.5 22.5 2.5 {name=R dir=in show_pinname=true}"
puts $fp "B 5 -2.5 -22.5 2.5 -17.5 {name=T dir=in show_pinname=true}"
puts $fp "B 5 -2.5 17.5 2.5 22.5 {name=B dir=in show_pinname=true}"
close $fp

proc fresh {} {
  global sym
  xschem clear force
  xschem instance $sym 200 200 0 0 {name=x1}
  xschem zoom_full; update idletasks
}

# --- 1. default binding present (idle_only: skipped while busy, so it dumps with " idle") ---
check "SPACE defaults to edit.add_pin_stubs (idle)" \
  [expr {[lsearch -exact [xschem bindings dump] {key 32 0 canvas edit.add_pin_stubs idle}] >= 0}] {}

# --- 2. SPACE with a selection (idle) runs add_pin_stubs (stubs + labels), not a pan ---
fresh
xschem unselect_all; xschem select instance x1; update idletasks
set w0 [xschem get wires]; set n0 [xschem get instances]
space
check "SPACE+selection adds stub wires"   [expr {[xschem get wires] == $w0 + 4}] "(wires $w0 -> [xschem get wires])"
check "SPACE+selection adds lab_pins"      [expr {[xschem get instances] == $n0 + 4}] "(inst $n0 -> [xschem get instances])"
check "SPACE+selection did NOT pan"        [expr {([st] & $STARTPAN) == 0}] "(ui_state [st])"
# one undo removes them all (add_pin_stubs pushed exactly one undo)
xschem undo; update idletasks
check "one undo removes the stubs+labels"  [expr {[xschem get wires] == $w0 && [xschem get instances] == $n0}] {}

# --- 3. SPACE with no selection (idle) starts a drag-pan, adds no stubs ---
fresh
xschem unselect_all; update idletasks
set w0 [xschem get wires]; set n0 [xschem get instances]
space 400 400
check "SPACE no-selection adds no stubs"   [expr {[xschem get wires] == $w0 && [xschem get instances] == $n0}] {}
check "SPACE no-selection starts a pan"    [expr {([st] & $STARTPAN) != 0}] "(ui_state [st])"
catch {xschem abort_operation}; update idletasks
check "pan cleaned up"                      [expr {([st] & $STARTPAN) == 0}] "(ui_state [st])"

# --- 3b. SPACE on a NON-STUBBABLE selection (only a wire) still PANS (not a dead key) ---
xschem clear force
xschem wire 500 500 560 500
xschem zoom_full; update idletasks
xschem unselect_all; xschem select_all; update idletasks    ;# selects the lone wire
set w0 [xschem get wires]; set n0 [xschem get instances]
space 400 400
check "non-stubbable (wire) selection adds no stubs" \
  [expr {[xschem get wires] == $w0 && [xschem get instances] == $n0}] {}
check "non-stubbable selection still PANS (not a dead key)" [expr {([st] & $STARTPAN) != 0}] "(ui_state [st])"
catch {xschem abort_operation}; update idletasks

# --- 3c. SPACE in a READ-ONLY view PANS (no stubs, no modal dialog) ---
fresh
xschem unselect_all; xschem select instance x1; update idletasks
xschem set readonly 1
set w0 [xschem get wires]; set n0 [xschem get instances]
space 400 400
check "read-only SPACE adds no stubs" \
  [expr {[xschem get wires] == $w0 && [xschem get instances] == $n0}] {}
check "read-only SPACE PANS (no dialog, no dead key)" [expr {([st] & $STARTPAN) != 0}] "(ui_state [st])"
xschem set readonly 0
catch {xschem abort_operation}; update idletasks

# --- 4. SPACE mid wire-gesture cycles the manhattan corner: gesture intact, no pan, no stubs ---
fresh
set infix_interface 1
xschem callback .drw $MOTION 250 250 0 0 0 0; update idletasks
xschem wire gui; update idletasks
xschem callback .drw $MOTION 350 250 0 0 0 0; update idletasks
check "wire gesture active before SPACE"   [expr {([st] & $STARTWIRE) != 0}] "(ui_state [st])"
set w0 [xschem get wires]
space 350 250
check "mid-gesture SPACE adds no stubs"     [expr {[xschem get wires] == $w0}] "(wires $w0 -> [xschem get wires])"
check "mid-gesture SPACE keeps the gesture" [expr {([st] & $STARTWIRE) != 0}] "(ui_state [st])"
check "mid-gesture SPACE did NOT pan"       [expr {([st] & $STARTPAN) == 0}] "(ui_state [st])"
catch {xschem abort_operation}; update idletasks

# --- 5. unbind SPACE: SPACE+selection now adds NO stubs (proves the binding drove it) ---
fresh
xschem unbind key 32 0 canvas
xschem unselect_all; xschem select instance x1; update idletasks
set w0 [xschem get wires]
space
check "unbound SPACE adds no stubs (binding drove add_pin_stubs)" \
  [expr {[xschem get wires] == $w0}] "(wires $w0 -> [xschem get wires])"
catch {xschem abort_operation}; update idletasks
# rebind and prove it works again
xschem bind key 32 0 canvas edit.add_pin_stubs
fresh
xschem unselect_all; xschem select instance x1; update idletasks
set w0 [xschem get wires]
space
check "rebound SPACE adds stubs again"      [expr {[xschem get wires] == $w0 + 4}] "(wires $w0 -> [xschem get wires])"

file delete -force $wd
if {$fail == 0} { puts "RESULT: ALL PASS ($npass)" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
