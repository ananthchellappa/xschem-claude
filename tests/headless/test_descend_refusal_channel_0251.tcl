# The descend refusal channel: `xschem descend` and open_sub_schematic.
# Issues 0249 / 0251 / 0254 / 0256, plus 0366 (the false success).
#
# Companion to tests/headless/test_descend_symbol.tcl (which covers the
# descend_symbol verb) and to tests/headless/test_descend_inert_class.tcl (which
# locks the SILENT half of the split). This file covers:
#
#   A  descend_schematic()'s target rule and its reason tokens
#   B  the reason channel's own discrimination guard
#   C  open_sub_schematic (Alt+E / File > "Open selected schematic in new window")
#   D  the hi_descend proc family's missing failure arms
#
# The design being pinned: ONE per-context reason channel, `xschem get
# descend_error`, RECORDED at every refusal and SPOKEN only where the user asked
# for the descend. It is a SECOND channel -- the "0"/"1" of `xschem descend` is
# load-bearing at src/xschem.tcl, in the sky130/ihp/cadence glue and in
# tests/buried_hilight.tcl, and must not be widened into a reason string.
# See doc/claude/code_analysis/descend_silent_refusal_census.md.
#
# Pure headless (open_sub_schematic and hi_descend both run under --nogui; the
# window table is exercised through `xschem new_schematic`, not through Tk).
# Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_refusal_channel_0251.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).
#
# Works on a /tmp copy so the ~ backups never pollute the committed fixtures.

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set repo   [file normalize [file join [file dirname [info script]] .. ..]]
set dev    [file join $repo xschem_library devices]
set work   /tmp/descend_refusal_channel_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
# A SECOND child, structurally identical but a different file: 0366 is only
# provable with two distinct destinations, otherwise "descended again" and
# "never left" look the same.
set fp [open $work/childB.sch w]
puts $fp "v {xschem version=3.4.4 file_version=1.2}"
puts $fp "G {}"
puts $fp "V {}"
puts $fp "S {}"
puts $fp "E {}"
puts $fp "N 0 0 0 -100 {}"
close $fp
set fp [open $work/childB.sym w]
puts $fp "v {xschem version=3.4.4 file_version=1.2}"
puts $fp "G {type=subcircuit"
puts $fp "template=\"name=xB\"}"
puts $fp "V {}"
puts $fp "S {}"
puts $fp "E {}"
puts $fp "L 4 -20 -20 20 -20 {}"
puts $fp "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=inout}"
close $fp
# the parent that carries BOTH children
set fp [open $work/two_child_parent.sch w]
puts $fp "v {xschem version=3.4.4 file_version=1.2}"
puts $fp "G {}"
puts $fp "V {}"
puts $fp "S {}"
puts $fp "E {}"
puts $fp "N 200 200 300 200 {}"
puts $fp "C {descend_child.sym} 0 0 0 0 {name=x1}"
puts $fp "C {childB.sym} 400 0 0 0 {name=xB}"
close $fp

if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# never prompt: this file is about refusals, not about save dialogs
proc ask_save {{cmd {}}} { return no }

proc fresh {{sch descend_parent.sch}} {
  global work
  catch { xschem new_schematic switch .drw }
  set g 0
  while {[xschem get currsch] > 0 && $g < 10} { xschem go_back; incr g }
  xschem clear force
  xschem load $work/$sch
  xschem unselect_all
}
proc nwin {} { return [llength [xschem windows]] }
# {schname currsch} of an arbitrary window, read WITHOUT switching to it
proc winstate {w} {
  foreach row [xschem windows] {
    if {[lindex $row 0] eq $w} {
      return "[file tail [lindex $row 4]] lvl=[expr {[llength [lindex $row 6]] - 1}]"
    }
  }
  return "ABSENT"
}

# ===========================================================================
puts "--- A. descend_schematic: the target rule and the reason tokens ---"
# ===========================================================================

# R15 (issue 0366). descend_schematic tests only sel_array[0].type, and with
# nothing selected rebuild_selected_array() leaves the PREVIOUS rebuild's entry
# in place -- so `e` after a go_back descends again into the last child and
# returns 1. Two different children make the false success visible: a process
# that has never selected anything refuses correctly, which is why this hides.
fresh two_child_parent.sch
xschem unselect_all
xschem select instance xB fast
check "R15 setup: descend into childB" \
      "[xschem descend] [file tail [xschem get schname]]" "1 childB.sch"
xschem go_back
check "R15 setup: back on the parent with nothing selected" \
      "[file tail [xschem get schname]] lastsel=[xschem get lastsel] sel={[xschem selected_set]}" \
      "two_child_parent.sch lastsel=0 sel={}"
set lvl [xschem get currsch]
set ret [xschem descend]
check "R15 descend with an EMPTY selection refuses (no stale sel_array reuse)" \
      "ret=$ret sch=[file tail [xschem get schname]] moved=[expr {[xschem get currsch] - $lvl}]" \
      "ret=0 sch=two_child_parent.sch moved=0"
check "R15 ... and records why" [xschem get descend_error] {no-selection}

# R16. The SILENT half, on the descend verb: an annotation instance the user
# never asked to descend records a reason but says nothing. (The full 262-symbol
# lock lives in tests/headless/test_descend_inert_class.tcl.)
fresh
xschem instance [file join $dev lab_pin.sym] 400 400 0 0 {name=l1 lab=NN}
xschem unselect_all
xschem select instance l1 fast
set sm0 [xschem get statusmsg]
set ret [xschem descend]
check "R16 descend on a type=label instance refuses" "$ret" "0"
check "R16 ... records not-descendable:label" [xschem get descend_error] {not-descendable:label}
check "R16 ... and stays SILENT (statusmsg untouched)" \
      [expr {[xschem get statusmsg] eq $sm0}] 1

# R17. The LOUD half, from the same guard neighbourhood: a ---MISSING SYMBOL---
# placeholder is exactly what a user clicks to find out what broke, so the
# unresolved name must be said out loud. issue 0254.
fresh
xschem instance no_such_cell_0254.sym 700 700 0 0 {name=XM}
xschem unselect_all
xschem select instance XM fast
set sm0 [xschem get statusmsg]
set ret [xschem descend]
check "R17 descend on the missing-symbol placeholder refuses" "$ret" "0"
check "R17 ... records the unresolved name" \
      [xschem get descend_error] {missing-symbol:no_such_cell_0254.sym}
set sm1 [xschem get statusmsg]
check "R17 ... and SPEAKS it (statusmsg names the symbol, held per issue 0248)" \
      "changed=[expr {$sm1 ne $sm0}] names=[string match {*no_such_cell_0254.sym*} $sm1]\
 held=[xschem get statusmsg_hold]" "changed=1 names=1 held=1"

# R18. sel_array is ordered by object type and TEXT sorts ahead of ELEMENT, so a
# rubber-band that caught a comment refuses today on a selection whose only
# instance is unambiguous. The picker takes the first ELEMENT, not entry 0.
fresh
xschem text 600 600 0 0 {a comment} {} 0.4 0
xschem unselect_all
xschem select instance x1 fast
xschem select text 0
check "R18 setup: one ELEMENT selected alongside a text" \
      "lastsel=[xschem get lastsel] elements=[llength [xschem selected_set]]" \
      "lastsel=2 elements=1"
set lvl [xschem get currsch]
set ret [xschem descend]
check "R18 instance + text descends into the instance" \
      "ret=$ret sch=[file tail [xschem get schname]] moved=[expr {[xschem get currsch] - $lvl}]" \
      "ret=1 sch=descend_child.sch moved=1"

# R19. Capability that is deliberately NOT narrowed: `descend` keeps "first
# ELEMENT, any count" (descend_symbol is the verb with the exactly-one rule).
# The invariant for this whole batch is that no descend which succeeds today
# stops succeeding -- 0366's false success is the single exception. A future
# unification of the two verbs has to break this row ON PURPOSE.
fresh two_child_parent.sch
xschem unselect_all
xschem select instance x1 fast
xschem select instance xB fast
check "R19 setup: two ELEMENTs selected" [llength [xschem selected_set]] 2
set ret [xschem descend]
check "R19 descend with 2 instances still descends into the first" \
      "ret=$ret sch=[file tail [xschem get schname]]" "ret=1 sch=descend_child.sch"

# ===========================================================================
puts "--- B. the reason channel's discrimination guard ---"
# ===========================================================================
# `xschem get <unknown key>` is the empty string, and so is "no error". Every
# row above therefore asserts an EXACT token and never merely non-empty; this
# row is what makes that discipline honest.
fresh
check "R20 a freshly loaded sheet has no descend reason" [xschem get descend_error] {}
check "R20 an unknown get key is ALSO empty (so {} proves nothing on its own)" \
      [xschem get bogus_key_zz] {}

# ===========================================================================
puts "--- C. open_sub_schematic (issue 0256) ---"
# ===========================================================================

# R21 (0256a). The else-arm was written for the argument form, but control also
# lands there for a bare call with 2+ objects selected, where
# `lsearch -exact $instlist {}` is -1: the proc returns 0 having created nothing
# and said nothing -- while `xschem descend` accepts the identical selection.
fresh
xschem select_inside -1000 -1000 1000 1000
check "R21 setup: >1 object selected, exactly one ELEMENT" \
      "lastsel=[expr {[xschem get lastsel] > 1}] elements=[llength [xschem selected_set]]" \
      "lastsel=1 elements=1"
set n0 [nwin]
set ret [open_sub_schematic]
check "R21 open_sub_schematic on a rubber-band selection opens the child" \
      "ret=$ret newwin=[expr {[nwin] - $n0}] sch=[file tail [xschem get schname]]" \
      "ret=1 newwin=1 sch=descend_child.sch"

# R22 (0256b). One WIRE selected: `lindex [xschem selected_set] 0` is empty, the
# proc falls through the whole window-creating body and returns 1 for an
# operation that descended nothing -- a duplicate of the PARENT reported as a
# successful descend.
fresh
xschem select wire 0
check "R22 setup: one object selected, no ELEMENT in it" \
      "lastsel=[xschem get lastsel] elements=[llength [xschem selected_set]]" \
      "lastsel=1 elements=0"
set n0 [nwin]
set ret [open_sub_schematic]
check "R22 open_sub_schematic with only a wire selected refuses" \
      "ret=$ret newwin=[expr {[nwin] - $n0}]" "ret=0 newwin=0"
check "R22 ... and says so" \
      [string match {*instance*} [xschem get statusmsg]] 1

# R23 (0256b'). Same shape with a single NON-descendable instance: `xschem
# descend` returns 0 for it, so the window is left stranded on the parent.
fresh
xschem instance [file join $dev lab_pin.sym] 400 400 0 0 {name=l1 lab=NN}
xschem unselect_all
xschem select instance l1 fast
set n0 [nwin]
set ret [open_sub_schematic]
check "R23 open_sub_schematic on a type=label instance refuses, no orphan window" \
      "ret=$ret newwin=[expr {[nwin] - $n0}] sch=[file tail [xschem get schname]]" \
      "ret=0 newwin=0 sch=descend_parent.sch"

# R26. newwin_capture_unsaved runs `xschem backup write` BEFORE any refusal can
# be taken, so a refused open leaves a <cell>~.sch for an operation that never
# happened. Delete the autosave backup first: what is measured is whether the
# REFUSED call re-creates it.
fresh
xschem wire 700 700 800 700
set bak $work/descend_parent~.sch
check "R26 setup: the edit is autosaved and the buffer is modified" \
      "modified=[xschem get modified] bak=[file exists $bak]" "modified=1 bak=1"
file delete -force $bak
xschem unselect_all
xschem select wire 0
set ret [open_sub_schematic]
check "R26 a refused open_sub_schematic writes no backup for work it did not do" \
      "ret=$ret bak=[file exists $bak]" "ret=0 bak=0"

# R24 (0256c2). `open_sub_schematic <inst>` never unselect_all's, so with 2
# objects still selected schematic_in_new_window takes its `lastsel > 1` branch
# and returns 0 -- but copy_hierarchy has ALREADY run, into a
# last_created_window that names an unrelated EARLIER window (a static in
# xinit.c, only ever set on success and never reset). The earlier window's
# hierarchy is clobbered by a call that then reports failure.
fresh
xschem unselect_all
xschem select instance x1 fast
set ok [open_sub_schematic]
set victim [xschem get last_created_window]
check "R24 setup: a legitimate new window sits on the child" \
      "ret=$ok state=[winstate $victim]" "ret=1 state=descend_child.sch lvl=1"
catch { xschem new_schematic switch .drw }
xschem unselect_all
xschem select_inside -1000 -1000 1000 1000
check "R24 setup: back on .drw with 2 objects selected" \
      "win=[xschem get current_win_path] many=[expr {[xschem get lastsel] > 1}]" \
      "win=.drw many=1"
set before [winstate $victim]
set ret [open_sub_schematic x1]
check "R24 a refused open_sub_schematic leaves the earlier window untouched" \
      "ret=$ret before={$before} after={[winstate $victim]}" \
      "ret=0 before={descend_child.sch lvl=1} after={descend_child.sch lvl=1}"

# ===========================================================================
puts "--- D. hi_descend's missing failure arms ---"
# ===========================================================================
# hi_descend_finish's `if {$ok}` has no else, and hi_descend_newwin has the same
# gap: in a proc family that echoes to the CIW at sixteen sites, the one failure
# that fires when the descend itself is refused is the one that says nothing.
# Record what ciw_echo is asked to say, then drive the two shapes.
set ::REC {}
if {[info procs ciw_echo] ne {}} { rename ciw_echo ciw_echo_orig }
proc ciw_echo {line {tag {}}} { lappend ::REC $line }
proc rec_has {pat} { return [expr {[lsearch -glob $::REC $pat] >= 0}] }

# R27: a non-descendable instance, schematic view, current window.
fresh
xschem instance [file join $dev lab_pin.sym] 400 400 0 0 {name=l1 lab=NN}
xschem unselect_all
set ::REC {}
set ret [hi_descend inst=l1 view=schematic target=current]
check "R27 hi_descend on a type=label instance returns 0" "$ret" "0"
check "R27 ... and reports the reason to the CIW (today it echoes NOTHING)" \
      [rec_has {*not-descendable*}] 1

# R28: the symbol view. hi_descend_finish infers success from currsch rising
# because "descend_symbol has no return value" -- it does, the dispatcher throws
# it away. The proxy cannot carry a reason, so the missing placeholder is mute.
fresh
xschem unselect_all
set ::REC {}
set ret [hi_descend inst=x1 view=symbol target=current]
check "R28 hi_descend into a real symbol view still succeeds" \
      "ret=$ret sch=[file tail [xschem get schname]]" "ret=1 sch=descend_child.sym"
fresh
xschem instance no_such_cell_0254.sym 700 700 0 0 {name=XM}
xschem unselect_all
set ::REC {}
set ret [hi_descend inst=XM view=symbol target=current]
check "R28 hi_descend into a MISSING symbol view returns 0" "$ret" "0"
check "R28 ... and reports missing-symbol to the CIW" [rec_has {*missing-symbol*}] 1

# ===========================================================================
puts "--- C'. the window table, exhausted (issue 0256 c1) --- MUST RUN LAST ---"
# ===========================================================================
# new_schematic() refuses past MAX_NEW_WINDOWS, but schematic_in_new_window() is
# void-on-refusal and returns 1 anyway, so open_sub_schematic descends into the
# STALE last_created_window: the user's 20th window is hijacked and the call
# reports success. Closed in Tcl by treating an unchanged last_created_window
# across the call as failure. This section fills the table, so nothing after it
# can open a window.
fresh
set guard 0
while {[nwin] < 20 && $guard < 40} {
  xschem unselect_all
  xschem schematic_in_new_window force
  catch { xschem new_schematic switch .drw }
  incr guard
}
set last [xschem get last_created_window]
check "R25 setup: the window table is full and .drw is current" \
      "nwin=[nwin] win=[xschem get current_win_path] last=$last" \
      "nwin=20 win=.drw last=.x19.drw"
fresh
xschem unselect_all
xschem select instance x1 fast
set before [winstate $last]
set ret [open_sub_schematic]
check "R25 open_sub_schematic on a full window table refuses instead of hijacking" \
      "ret=$ret before={$before} after={[winstate $last]}" \
      "ret=0 before={descend_parent.sch lvl=0} after={descend_parent.sch lvl=0}"

puts ""
if {$fail} { puts "OVERALL: $fail FAILED, $npass passed" } \
else       { puts "OVERALL: ok ($npass checks)" }
