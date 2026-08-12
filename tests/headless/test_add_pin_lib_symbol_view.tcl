# Regression: the view-aware Add-Pin (`p`) form must place SYMBOL pins in a symbol
# view opened from a LIBRARY-MANAGER reference (lib/cell, no .sym extension), not just
# an untitled.sym or a plain-path .sym.
#
# BUG: addpin::place_verb decided the view by matching `*.sym` on `xschem get current_name`.
# A library-manager symbol displays as the extension-less "lib/cell" reference
# (rel_sym_path -> lib_qualified_rel drops the .sym), so the match returned 0 and the form
# ran `add_sch_pin -place` -- a NO-OP in a symbol view. Result: `p` opened the form but no
# cursor preview armed and a click placed nothing. `untitled.sym` (name keeps .sym) worked,
# masking it. FIX: place_verb asks the authoritative C `editing_symbol_view()` (real loaded
# path) via `xschem get editing_symbol_view`, which is independent of the display name.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_add_pin_lib_symbol_view.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc placing {} { return [expr {([xschem get ui_state] & 16384) ? 1 : 0}] }

set W /tmp/test_add_pin_lib.[pid]

# ---------------------------------------------------------------------------
# A. `xschem get editing_symbol_view` is the authoritative view test.
# ---------------------------------------------------------------------------
xschem clear force symbol
check "untitled.sym -> editing_symbol_view 1" [xschem get editing_symbol_view] 1
check "untitled.sym -> place_verb add_symbol_pin" [addpin::place_verb] add_symbol_pin
xschem clear force schematic
check "schematic -> editing_symbol_view 0" [xschem get editing_symbol_view] 0
check "schematic -> place_verb add_sch_pin" [addpin::place_verb] add_sch_pin

# ---------------------------------------------------------------------------
# B. The bug: a symbol opened from a registered library shows as lib/cell (no .sym).
#    place_verb MUST still pick add_symbol_pin (was add_sch_pin), and the preview arm.
#    Library shape follows lib_qualified_rel rule 2: <libroot>/<cell>/symbol/<cell>.sym.
# ---------------------------------------------------------------------------
set root [file join $W mylibroot]
file mkdir [file join $root cell1 symbol]
lappend ::pathlist $root                  ;# any pathlist dir auto-registers as a library
set symfile [file join $root cell1 symbol cell1.sym]
xschem clear force
xschem saveas $symfile symbol
xschem load $symfile

check "lib symbol -> current_name is lib/cell (no .sym)" \
      [xschem get current_name] mylibroot/cell1
check "lib symbol -> OLD *.sym heuristic returns 0 (mis-routed the verb)" \
      [string match {*.sym} [xschem get current_name]] 0
check "lib symbol -> editing_symbol_view 1" [xschem get editing_symbol_view] 1
check "lib symbol -> place_verb add_symbol_pin (fixed)" [addpin::place_verb] add_symbol_pin

# end-to-end: the form's arm runs the chosen verb -> preview arms + a PINLAYER rect exists
set ::pin_new_name IN; set ::pin_new_dir in
xschem [addpin::place_verb] -place
check "lib symbol -> preview armed (START_SYMPIN)" [placing] 1
check "lib symbol -> one PINLAYER pin rect"        [xschem get rects 5] 1

# the wrong verb (what the bug ran) is a proven no-op in a symbol view: prove it stays inert
xschem abort_operation
xschem unselect_all
set r0 [xschem get rects 5]
xschem add_sch_pin -place
check "add_sch_pin -place is a no-op in symbol view (no new rect)" [xschem get rects 5] $r0
check "add_sch_pin -place is a no-op in symbol view (no arm)"      [placing] 0

# ---------------------------------------------------------------------------
# S13. DOCUMENTED RESIDUE of issue 0246 (green before the fix and after) -- keep this row and
#      issue 0402 in step with each other.
#
#      In a symbol view `xschem add_wire_label -place` short-circuits (scheduler.c) and arms
#      NOTHING: wirelabel_preview stays 0. addlabel::arm nevertheless sets armed=1 and posts
#      "placing '<name>' ..." unconditionally, because the write sits AFTER the -place with no
#      "did the C actually arm?" check. 0246 removes the HARM of that lie -- once the drop witness
#      is split per owner, a label form that armed nothing can never move sympin_drops_label, so
#      it can no longer drain a name on somebody else's commit -- but NOT the lie itself, which is
#      a user-visible change (an error line instead of a placing line) and is filed as 0402.
#      This row pins the residue so the day 0402 is fixed, it fails here and gets updated
#      deliberately rather than silently.
# ---------------------------------------------------------------------------
if {[info commands winfo] ne {}} {
  puts "SKIP: 0246 S13 needs a headless run (no Tk)"
} else {
  proc winfo {op args} { return 1 }
  xschem load $symfile
  check "S13 precondition: back in the lib symbol view" [xschem get editing_symbol_view] 1
  set addlabel::last {} ; set addlabel::armed 0
  set addlabel::name RESIDUE
  addlabel::start_pass
  check "S13 residue: an arm that armed nothing still claims armed (issue 0402)" \
        [list [xschem get wirelabel_preview] $addlabel::armed] {0 1}
  set addlabel::armed 0 ; set addlabel::last {} ; set addlabel::name {}
  xschem abort_operation
  rename winfo {}
}

catch {file delete -force $W}
puts "PASS=$npass FAIL=$fail"
if {$fail == 0} { puts "OVERALL: ok" } else { puts "OVERALL: FAIL" }
