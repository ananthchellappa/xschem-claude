# Acceptance test for crash-safe hierarchical editing (backing-file design).
# Spec: specs/descend_hierarchy_in_memory.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_preserve.tcl
#
# S1 (no data loss): with an UNSAVED edit to the PARENT, descending into a child and
# returning must NOT lose that edit -- even when the save prompt is declined. The
# edit is persisted to cellName~.sch by the autosave hook and reloaded by go_back.
# S2 (no prompt): descending must not pop the save dialog. RED until B5.
#
# Works on a /tmp copy so the ~ backup never pollutes the committed fixtures.

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/b3_descend_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

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

# Count + decline the save prompt: the edit must survive either way.
set ::ask_count 0
proc ask_save {{cmd {}}} { incr ::ask_count; return no }

set bak $work/descend_parent~.sch
file delete -force $bak

xschem load $work/descend_parent.sch
set base [xschem get wires]
check "fixture loaded (parent, 1 wire, 1 instance)" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch" && $base == 1 && [xschem get instances] == 1}]

# --- unsaved edit to the PARENT (autosave writes the ~ backup) ---
xschem wire 200 300 300 300
set edited [xschem get wires]
check "parent edit applied: wire added, modified flag set" \
  [expr {$edited == $base + 1 && [xschem get modified] == 1}]
check "edit was autosaved to the ~ backup" [file exists $bak]

# --- descend into the child, declining the save ---
xschem unselect_all
xschem select instance 0
xschem descend
check "descended into child schematic" \
  [expr {[file tail [xschem get schname]] eq "descend_child.sch"}]

# --- return to the parent ---
xschem go_back
check "returned to parent schematic (logical identity preserved)" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch"}]

# S1: the unsaved parent edit must still be there (reloaded from the ~ backup)
check "S1: parent edit preserved across descend/go_back (no data loss)" \
  [expr {[xschem get wires] == $edited}]
check "S1: parent still flagged modified (unsaved edit present on return)" \
  [expr {[xschem get modified] == 1}]

# S2: descend must not have prompted at all (RED until B5)
check "S2: descend did not pop the save prompt" \
  [expr {$::ask_count == 0}]

result
