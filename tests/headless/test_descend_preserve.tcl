# Acceptance test for in-memory hierarchy preservation.
# Spec: specs/descend_hierarchy_in_memory.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_preserve.tcl
#
# S1 (no data loss): with an UNSAVED edit to the PARENT schematic, descending into a
# child and returning must NOT lose that edit -- even when the save prompt is declined.
# Today descend overwrites the parent's arrays and go_back reloads the parent from disk,
# so the edit vanishes: this assertion is RED until go_back restores the parent from the
# in-memory snapshot (Step 5).
#
# S2 (no prompt): descending must not pop the save dialog at all. RED until the descend
# save block is removed (Step 7). Guarded by [info exists] so this file is the single
# acceptance test that flips both gates as the implementation lands.

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]

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

# Count + decline the save prompt. Declining is exactly what the current code does on a
# "no", and what removing the prompt will do unconditionally: the edit must survive either
# way. The count lets S2 assert the prompt is gone once Step 7 lands.
set ::ask_count 0
proc ask_save {{cmd {}}} { incr ::ask_count; return no }

# make the fixture's child symbol resolvable
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$fixdir:$XSCHEM_LIBRARY_PATH"

xschem load $fixdir/descend_parent.sch
set base [xschem get wires]
check "fixture loaded (parent, 1 wire, 1 instance)" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch" && $base == 1 && [xschem get instances] == 1}]

# --- unsaved edit to the PARENT ---
xschem wire 200 300 300 300
set edited [xschem get wires]
check "parent edit applied: wire added, modified flag set" \
  [expr {$edited == $base + 1 && [xschem get modified] == 1}]

# --- descend into the child, declining the save ---
xschem unselect_all
xschem select instance 0
xschem descend
check "descended into child schematic" \
  [expr {[file tail [xschem get schname]] eq "descend_child.sch"}]

# --- return to the parent ---
xschem go_back
check "returned to parent schematic" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch"}]

# S1: the unsaved parent edit must still be there (RED until Step 5)
check "S1: parent edit preserved across descend/go_back (no data loss)" \
  [expr {[xschem get wires] == $edited}]
check "S1: parent still flagged modified (unsaved edit present on return)" \
  [expr {[xschem get modified] == 1}]

# S2: descend must not have prompted at all (RED until Step 7)
check "S2: descend did not pop the save prompt" \
  [expr {$::ask_count == 0}]

result
