# RED-first regression: entering a modal PLACEMENT leaves wire/line draw mode.
#
# Issue 0230 established the policy for `l` (Add Wire Label) and the reason it is not optional:
# end_place_move_copy_zoom() tests STARTWIRE BEFORE the placement arm, so while a wire draw is
# live every click feeds the wire and the placement can never be dropped -- and under
# `persistent_command` (cadence_style_rc) the press handler seizes the click even in the RESTING
# command mode, where ui_state has no STARTWIRE at all and only last_command is armed.
# Issue 0233 measured the same clash on the other twelve placement arms. This file covers the two
# the user ratified on 2026-08-07: `p` (Add Pin, schematic and symbol view) and component insert
# (`place_symbol`, i.e. the toolbar / library-manager / context-menu route).
#
# "Wire-draw mode" is THREE states and each verb is checked against all three:
#   LIVE     ui_state & STARTWIRE          -- first vertex placed, rubber band up
#   MENU     MENUSTART + MENUSTARTWIRE     -- armed from the menu, first click not landed
#   RESTING  ui_state clear, last_command  -- segment ended by double-click, diamond cursor up
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_placement_wire_gate.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc ui {}        { return [xschem get ui_state] }
proc bit {b}      { return [expr {([ui] & $b) ? 1 : 0}] }
proc startwire {} { return [bit 1] }
proc startline {} { return [bit 4] }
proc placing {}   { return [bit 16384] }      ;# START_SYMPIN
proc placesym {}  { return [bit 8192] }       ;# PLACE_SYMBOL
proc menuwire {}  { return [expr {([ui] & 65536) && ([xschem get ui_state2] & 1) ? 1 : 0}] }
proc lc {}        { return [xschem get last_command] }
proc reset {} {
  xschem abort_operation ; xschem abort_operation
  xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
}

set saved_infix $::infix_interface
set ::pin_new_name PG ; set ::pin_new_dir in

# ---------------------------------------------------------------------------
# A. `p` (add_sch_pin) -- the schematic Add-Pin form
# ---------------------------------------------------------------------------
set ::infix_interface 1
reset ; xschem wire gui                       ;# LIVE draw
check "A1 live: STARTWIRE armed"         [startwire] 1
xschem add_sch_pin -place
check "A1 live: p clears STARTWIRE"      [startwire] 0
check "A1 live: p clears wire mode"      [lc] 0
check "A1 live: pin preview armed"       [placing] 1
check "A1 live: nothing committed"       [xschem get wires] 1

reset ; xschem wire gui ; xschem abort_operation   ;# RESTING (two-stage ESC = post double-click)
check "A2 resting: no STARTWIRE"         [startwire] 0
check "A2 resting: wire mode armed"      [lc] 1
xschem add_sch_pin -place
check "A2 resting: p clears wire mode"   [lc] 0
check "A2 resting: pin preview armed"    [placing] 1

set ::infix_interface 0
reset ; xschem wire                            ;# MENU-armed, first click not landed
check "A3 menu: menu wire armed"         [menuwire] 1
xschem add_sch_pin -place
check "A3 menu: p clears the menu arm"   [menuwire] 0
check "A3 menu: pin preview armed"       [placing] 1
set ::infix_interface 1

# ---------------------------------------------------------------------------
# B. component insert (`place_symbol`) -- toolbar / library manager / ctx menu
# ---------------------------------------------------------------------------
set sym [find_file_first lab_pin.sym]
reset ; xschem wire gui
xschem place_symbol $sym
check "B1 live: insert clears STARTWIRE" [startwire] 0
check "B1 live: insert clears wire mode" [lc] 0
check "B1 live: PLACE_SYMBOL armed"      [placesym] 1
check "B1 live: nothing committed"       [xschem get wires] 1

reset ; xschem wire gui ; xschem abort_operation
xschem place_symbol $sym
check "B2 resting: insert clears mode"   [lc] 0
check "B2 resting: PLACE_SYMBOL armed"   [placesym] 1

set ::infix_interface 0
reset ; xschem wire
xschem place_symbol $sym
check "B3 menu: insert clears menu arm"  [menuwire] 0
check "B3 menu: PLACE_SYMBOL armed"      [placesym] 1
set ::infix_interface 1
xschem abort_operation

# ---------------------------------------------------------------------------
# C. `p` in a SYMBOL view (add_symbol_pin) -- there the modal draw is a graphic LINE
# ---------------------------------------------------------------------------
source [file join [file dirname [info script]] scratch.tcl]
set symf [file join [test_scratch pwg_sym] pwg.sym]
set fh [open $symf w]
puts $fh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fh "G {}"; puts $fh "K {type=subcircuit}"; puts $fh "V {}"; puts $fh "S {}"; puts $fh "E {}"
puts $fh "L 4 -10 -10 10 -10 {}"
close $fh
xschem load $symf
check "C0 loaded a symbol view"          [string match {*.sym} [xschem get current_name]] 1
xschem line gui                                ;# LIVE line draw
check "C1 live: STARTLINE armed"         [startline] 1
xschem add_symbol_pin -place
check "C1 live: p clears STARTLINE"      [startline] 0
check "C1 live: p clears line mode"      [lc] 0
check "C1 live: pin preview armed"       [placing] 1
xschem abort_operation ; xschem abort_operation

# C2 CONTROL -- the SCRIPTED coordinate form is the replay/test seam and must NOT abort a
#    gesture: it commits a pin at given coordinates and arms no cursor placement at all.
xschem line gui
check "C2 control: STARTLINE armed"      [startline] 1
xschem add_symbol_pin 40 40 SCRIPTED in
check "C2 control: draw NOT aborted"     [startline] 1
check "C2 control: line mode kept"       [lc] 4
check "C2 control: no preview armed"     [placing] 0
xschem abort_operation ; xschem abort_operation
catch {file delete -force $symf}

set ::infix_interface $saved_infix

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
