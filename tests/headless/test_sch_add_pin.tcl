# RED-first regression for the schematic-editor "Add Pin" feature
# (doc/claude/specs/schematic_add_pin.md): pressing `p` in a SCHEMATIC places
# ipin/opin/iopin INSTANCES (not symbol PINLAYER rects), via `xschem add_sch_pin -place`,
# through the shared view-aware addpin:: dialog, with a rebindable Ctrl+MMB pin-type cycle
# (edit.cycle_pin_type). Every assertion below FAILS before the implementation (the command,
# the action id, and the addpin:: helper procs do not exist yet) -> RED, and passes after.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sch_add_pin.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# read the symbol file of instance 0 (cell::name) and its lab net-name
proc inst0_sym {} { return [xschem getprop instance 0 cell::name] }
proc inst0_lab {} { return [xschem getprop instance 0 lab] }
proc placing {} { return [expr {([xschem get ui_state] & 16384) ? 1 : 0}] }

# ---------------------------------------------------------------------------
# A. Ctrl+MMB action is a real, bindable, DEFAULT-bound registry action.
# ---------------------------------------------------------------------------
set dump ""
catch {xschem bindings dump} dump
check "cycle action default-bound (bindings dump)" \
      [string match {*edit.cycle_pin_type*} $dump] 1
# a bind of an UNKNOWN action id errors; a known one succeeds -> proves the id exists
check "bind edit.cycle_pin_type ok" \
      [catch {xschem bind button 2 ctrl canvas edit.cycle_pin_type}] 0

# ---------------------------------------------------------------------------
# B. add_sch_pin -place places the correct device symbol per Direction, names it,
#    arms the cursor preview, and re-arm REPLACES (one instance) rather than piling up.
# ---------------------------------------------------------------------------
xschem clear force
set ::pin_new_name IN
set ::pin_new_dir  in
xschem add_sch_pin -place
check "input  -> one instance"     [xschem get instances] 1
check "input  -> ipin.sym"         [string match {*ipin.sym} [inst0_sym]] 1
check "input  -> lab=IN"           [inst0_lab] IN
check "preview armed (START_SYMPIN)" [placing] 1

set ::pin_new_dir out
xschem add_sch_pin -place
check "output -> still one instance" [xschem get instances] 1
check "output -> opin.sym"           [string match {*opin.sym} [inst0_sym]] 1

set ::pin_new_dir inout
xschem add_sch_pin -place
check "inout  -> still one instance" [xschem get instances] 1
check "inout  -> iopin.sym"          [string match {*iopin.sym} [inst0_sym]] 1

# drop / commit (the RELEASE-equivalent one-shot; keeps the placed instance)
xschem move_objects end 0 0 0
check "after drop -> one instance"   [xschem get instances] 1
check "after drop -> iopin committed" [string match {*iopin.sym} [inst0_sym]] 1

# ---------------------------------------------------------------------------
# C. In a SYMBOL view, add_sch_pin is a no-op (schematic pins are instances,
#    which a .sym view forbids). Build a tiny .sym fixture and load it.
# ---------------------------------------------------------------------------
source [file join [file dirname [info script]] scratch.tcl]
set symf [file join [test_scratch sch_add_pin_sym] sch_add_pin.sym]
set fh [open $symf w]
puts $fh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fh "G {}"
puts $fh "K {type=subcircuit}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "L 4 -10 -10 10 -10 {}"
close $fh
xschem load $symf
check "loaded a symbol view" [string match {*.sym} [xschem get current_name]] 1
set before [xschem get instances]
set ::pin_new_name Z
set ::pin_new_dir  in
xschem add_sch_pin -place
check "symbol view: add_sch_pin refused" [xschem get instances] $before

# ---------------------------------------------------------------------------
# D. Pure Tcl helpers (headless-safe: no Tk widgets).
# ---------------------------------------------------------------------------
check "names_from splits + trims" [addpin::names_from " IN  OUT VDD "] {IN OUT VDD}
check "names_from empty"          [addpin::names_from "   "] {}
check "next_dir input->output"    [addpin::next_dir input]  output
check "next_dir output->inout"    [addpin::next_dir output] inout
check "next_dir inout->input"     [addpin::next_dir inout]  input
# place_verb dispatches on the current view type
check "place_verb in symbol view" [addpin::place_verb] add_symbol_pin
xschem clear force
check "place_verb in schematic view" [addpin::place_verb] add_sch_pin

catch {file delete -force $symf}

# ---------------------------------------------------------------------------
# P. Issue 0245 -- canvas Escape must reach the C Escape terminal while this form owns the
#    shared `.drw <Key-Escape>` slot. addpin::grab_esc points that slot at addpin::escape
#    (`set armed 0; abort_if_placing; destroy`), and abort_if_placing only fires while
#    START_SYMPIN is set -- so with the form IDLE the entire Escape is a destroy plus a
#    variable write and callback.c's `case XK_Escape:` never runs. Measured under xvfb with
#    .addpin open: `xschem wire` then a real `<Key-Escape>` on .drw left ui=65536 ui2=1,
#    i.e. the arm survived, and the next canvas click started an unrequested wire draw.
#    The fix gives the CANVAS Escape its own entry point, addpin::canvas_escape, ending at
#    the named C terminal `xschem escape`. Headless-safe: no Tk, so the inner
#    `catch {destroy .addpin}` is a no-op and these rows test the FORWARD.
# ---------------------------------------------------------------------------
xschem clear force ; xschem abort_operation ; xschem abort_operation
xschem wire
check "P0 precondition: menu wire armed"   [xschem get ui_state] 65536
catch {addpin::canvas_escape}
check "P1 canvas Escape aborts the arm"    [xschem get ui_state] 0
check "P2 canvas Escape clears ui_state2"  [xschem get ui_state2] 0
xschem abort_operation

# P3 CONTRAST -- the Close BUTTON (-command addpin::escape) is a mouse click, not the Escape
#    key; it must gain nothing. GREEN before the fix and after. The form-focused <Key-Escape>
#    is NOT part of this contrast: it forwards through addpin::canvas_escape, because Tk sends
#    keys to `[focus]` and open() focuses the form. See test_create_instance.tcl CI15b.
xschem clear force ; xschem abort_operation ; xschem abort_operation
xschem wire
catch {addpin::escape}
check "P3 contrast: Close button leaves the arm" [xschem get ui_state] 65536
xschem abort_operation ; xschem abort_operation

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
