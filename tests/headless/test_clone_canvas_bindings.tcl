# Issue 0020: clone_canvas_bindings must NOT clobber the per-window canvas bindings
# that set_bindings already tailored to the new window. Several standard bindings bake
# the window's own path into their body (not %W): e.g.
#   <Expose>  -> "if {{%W} eq {<canvas>}} {...}"
#   <Control-Shift-Key-P> -> "command_palette <toplevel>; break"
# Blindly copying .drw's versions onto .xN.drw leaves guards that can never match and a
# command palette pointed at the MAIN window. The clone must only carry the user's
# EXTRA .drw bindings (e.g. cadence_style_rc shortcuts), leaving dst's own standards.
#
# RED before fix: the new window's <Expose>/<Ctrl-Shift-P> bodies reference .drw.
# GREEN after fix: they reference the new window; user bindings still propagate.
#
# Needs X. Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_clone_canvas_bindings.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {n} { global repo; return [file join $repo xschem_library examples $n] }

set ::tabbed_interface 1
catch {xschem new_schematic destroy_all {}}
xschem load [ex nand2.sch]

# a user binding on the MAIN canvas (the kind cadence_style_rc adds) must still clone
bind .drw <Control-Key-x> {set ::marker DESCEND; break}

xschem new_schematic create_window .x1 [ex dlatch.sch]
update idletasks

set exp [bind .x1.drw <Expose>]
set pal [bind .x1.drw <Control-Shift-Key-P>]
set usr [bind .x1.drw <Control-Key-x>]

# CB1 — the new window's <Expose> guard references ITS OWN canvas, not .drw
check "CB1 new window <Expose> binding targets its own canvas (not .drw)" \
  [expr {[string match {*.x1.drw*} $exp] && ![string match {*eq {.drw}*} $exp]}] \
  "(=> {$exp})"

# CB2 — the command palette opens on the new window's toplevel, not the main one
check "CB2 new window <Control-Shift-Key-P> opens palette on .x1 (not .)" \
  [expr {[string match {*command_palette .x1*} $pal]}] "(=> {$pal})"

# CB3 — a user .drw binding (not part of set_bindings) STILL clones onto the new window
check "CB3 user .drw binding still clones onto the new window" \
  [string match {*DESCEND*break*} $usr] "(=> {$usr})"

bind .drw <Control-Key-x> {}  ;# clean up
catch {xschem new_schematic destroy_all {}}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
