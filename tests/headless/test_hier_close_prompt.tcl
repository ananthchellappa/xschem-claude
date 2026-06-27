# B9 (deep-hierarchy edge audit, pulled forward): closing/quitting while descended
# must account for unsaved edits in ANCESTOR hierarchy levels, not just the current
# level. Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Background: B5/B6 let you descend past an unsaved parent (its edits live in
# cellName~.sch). xctx->modified only reflects the CURRENT level, so a deep
# close/quit that checks it alone would not prompt though the design has unsaved
# work. hierarchy_modified() is true if the current level is modified OR any
# ancestor on the descend stack still has a ~ backup. The exit/close prompt uses it.
#
# This test pins the detection logic (the prompt wiring itself is GUI-only:
# tk_messageBox under has_x). Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_hier_close_prompt.tcl

set work /tmp/b9_hier_close_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force [file join [file dirname [info script]] fixtures descend $fn] $work/$fn
}
set XSCHEM_LIBRARY_PATH "$work"

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}
proc result {} {
  puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
  flush stdout
  exit [expr {$::fails != 0}]
}
proc ask_save {{c {}}} { return no }

# --- clean top-level: nothing modified anywhere ---
xschem load $work/descend_parent.sch
check "clean top: modified=0" [expr {[xschem get modified] == 0}]
check "clean top: hierarchy_modified=0" [expr {[xschem get hierarchy_modified] == 0}]

# --- current level modified: hierarchy_modified must be 1 too ---
xschem wire 200 300 300 300
check "edited top: modified=1" [expr {[xschem get modified] == 1}]
check "edited top: hierarchy_modified=1" [expr {[xschem get hierarchy_modified] == 1}]

# --- descend past the unsaved parent: current level clean, ancestor dirty ---
xschem unselect_all; xschem select instance 0; xschem descend
check "descended into child (currsch=1)" [expr {[xschem get currsch] == 1}]
check "child level itself is clean (modified=0)" [expr {[xschem get modified] == 0}]
check "parent~ backup still exists on disk" [file exists $work/descend_parent~.sch]
# THE BUG THIS FIXES: a deep close/quit checking only modified would not prompt.
check "DEEP CLOSE GUARD: hierarchy_modified=1 (ancestor has unsaved edits)" \
  [expr {[xschem get hierarchy_modified] == 1}]

# --- back up, save the parent: now the whole hierarchy is clean ---
xschem go_back
check "returned to parent (currsch=0)" [expr {[xschem get currsch] == 0}]
xschem saveas $work/descend_parent.sch schematic
check "after save: modified=0" [expr {[xschem get modified] == 0}]
check "after save: parent~ removed" [expr {![file exists $work/descend_parent~.sch]}]
xschem unselect_all; xschem select instance 0; xschem descend
check "descend again into now-clean parent (currsch=1)" [expr {[xschem get currsch] == 1}]
check "clean hierarchy: hierarchy_modified=0 (no ancestor ~)" \
  [expr {[xschem get hierarchy_modified] == 0}]

result
