# Efficiency invariant for the backing-file design.
# Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Navigating an UNMODIFIED hierarchy must do no disk writes: descending into and
# back out of clean cells creates no cellName~.sch backups (only a genuine edit
# does). Works on a /tmp copy.
#
# Run: src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_efficiency.tcl

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/beff_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

set ::f 0
proc ck {name ok} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; if {!$ok} {incr ::f} }
proc ask_save {{c {}}} { return no }

set pbak $work/descend_parent~.sch
set cbak $work/descend_child~.sch
file delete -force $pbak $cbak

# descend into an unmodified parent: no backup written
xschem load $work/descend_parent.sch
xschem unselect_all; xschem select instance 0; xschem descend
ck "unmodified descend writes no parent backup" [expr {![file exists $pbak]}]
ck "viewing an unmodified child writes no child backup" [expr {![file exists $cbak]}]

# return: still no backups for a clean round trip
xschem go_back
ck "clean descend/go_back round trip leaves no backups" \
  [expr {![file exists $pbak] && ![file exists $cbak]}]

# sanity: a real edit DOES write one (the hook is live, not disabled)
xschem wire 200 300 300 300
ck "a genuine edit does write a backup (hook live)" [file exists $pbak]

puts [expr {$::f == 0 ? "RESULT: ALL PASS" : "RESULT: $::f FAILED"}]
exit [expr {$::f != 0}]
