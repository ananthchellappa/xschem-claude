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

# ---------------------------------------------------------------------------
# Q. Issue 0246 -- this form must own its OWN drop witness, so a sibling form's commit can never
#    be credited to it. The full write-up is section W of tests/headless/test_add_wire_label.tcl;
#    the rows here are the PIN side, which is where the identity swap is user-visible.
#
#    Today the two forms tell each other apart through `::sympin_place`, a bare global with two
#    unconditional writers, two readers and no clear site. Whichever form armed LAST owns the
#    latch, and each after_drop reads it ABOVE the 0122-E1 witness compare -- so the non-owner
#    bails silently, keeps armed=1 and never posts the pause line (measured: pin.armed 1, status
#    {}). With the latch stale the other way round it is worse: a genuine LABEL commit drains the
#    PIN queue "IN OUT" -> "OUT", re-arms an iopin.sym PORT preview on the cursor of a user who is
#    placing net labels, and posts "placing 'OUT' (inout) ...". Q2/Q5 are the detectors for that
#    direction -- green today only because the latch happens to point the other way, and red under
#    the sabotage variant that hands this form the shared total again.
#
#    THE FIX: delete the latch and split the C witness by owner (`sympin_drops_pin` /
#    `sympin_drops_label`); this form compares a counter only a PIN commit can move, so a label
#    drop leaves it equal to drop_snap and the E1 pause fires, as it should.
#
#    Headless harness: no Tk, so `winfo` is stubbed for the duration (arm/after_drop only ever ask
#    `winfo exists`) and both forms' status procs are captured by rename; all of it is undone at
#    the end of the section.
# ---------------------------------------------------------------------------
proc gi {k} { set v {} ; catch {xschem get $k} v ; if {[string is integer -strict $v]} { return $v } ; return -1 }

if {[info commands winfo] ne {}} {
  puts "SKIP: 0246 Q1-Q7 need a headless run (no Tk) -- form stubs would be wrong here"
} else {
  proc winfo {op args} { return 1 }
  rename addpin::status          addpin::status_real0246
  rename addlabel::status        addlabel::status_real0246
  rename addlabel::status_error  addlabel::status_error_real0246
  proc addpin::status         {msg} { set ::pst0246 $msg }
  proc addlabel::status       {msg} { set ::lst0246 $msg }
  proc addlabel::status_error {msg} { set ::lst0246 "ERR $msg" }
  set ::pst0246 {} ; set ::lst0246 {}

  xschem clear force
  xschem wire 0 0 200 0
  xschem unselect_all
  unset -nocomplain ::sympin_place
  addpin::on_destroy ; addlabel::on_destroy       ;# both forms in their freshly-opened state

  # Q1 -- the pin form baselines ITS OWN witness at the arm, not the shared total.
  set addpin::name "IN OUT" ; set addpin::dir inout
  addpin::start_pass
  check "0246 Q1 pin arm baselines the PIN witness" $addpin::drop_snap [gi sympin_drops_pin]

  # the sibling arms ON TOP: the live preview is now the LABEL's, and the pin form is left armed
  # with no preview of its own -- exactly the state a second open form puts it in.
  set addlabel::name "A B"
  addlabel::start_pass
  check "0246 Q1 precondition: label owns the live preview" \
        [list $addpin::armed $addlabel::armed [xschem get instances]] {1 1 1}

  set p0 [gi sympin_drops_pin] ; set l0 [gi sympin_drops_label] ; set t0 [gi sympin_drops]
  check "0246 Q2 precondition: the sibling's LABEL drop commits" [xschem add_wire_label -drop 40 0] 1
  set ::pst0246 {} ; set ::lst0246 {}
  addpin::after_drop 1                            ;# the shared .drw <ButtonRelease>, pin form first

  # Q2/Q5 GUARD (green before and after; the identity-swap detectors)
  check "0246 Q2 GUARD a label drop must not drain the pin queue" $addpin::name "IN OUT"
  check "0246 Q5 GUARD no port preview re-armed on a label user's cursor" [xschem get instances] 1
  # Q3/Q4 -- the pin form owns nothing here and must stop claiming it does, out loud.
  check "0246 Q3 non-owner pin form disarms" $addpin::armed 0
  check "0246 Q4 the 0122-E1 pause line is reachable for the pin form" $::pst0246 \
        "placement paused (another action took over) -- edit the name or reopen to resume"

  # Q6 GUARD -- the OWNER's own drain still works: queue advances "A B" -> "B" and the next
  # preview arms (1 committed lab_pin + 1 live preview = 2 instances).
  addlabel::after_drop 1
  check "0246 Q6 GUARD the owning form still drains and re-arms" \
        [list $addlabel::name [xschem get instances]] {B 2}

  # Q7 -- the parts add up to the whole across a CROSS-FORM commit, and the pin part never moved.
  set p1 [gi sympin_drops_pin] ; set l1 [gi sympin_drops_label] ; set t1 [gi sympin_drops]
  check "0246 Q7 parts add up, pin witness unmoved by a label commit" \
        [list [expr {$t1 - $t0}] [expr {($p1 - $p0) + ($l1 - $l0)}] [expr {$p1 - $p0}]] {1 1 0}

  set addpin::armed 0 ; set addlabel::armed 0
  xschem abort_operation
  rename addpin::status         {} ; rename addpin::status_real0246         addpin::status
  rename addlabel::status       {} ; rename addlabel::status_real0246       addlabel::status
  rename addlabel::status_error {} ; rename addlabel::status_error_real0246 addlabel::status_error
  rename winfo {}
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
