# B2: autosave hooked into the edit funnel (set_modify).
# Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# A genuine edit (set_modify(1)) immediately writes cellName~.sch; a real save
# removes it; loading and highlighting do NOT touch it. Works in a /tmp copy so a
# real save never overwrites a committed fixture.
#
# Run: src/xschem --nogui --pipe -q --nolog --script tests/headless/test_autosave_hook.tcl

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/b2_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

set ::f 0
proc ck {name ok} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; if {!$ok} {incr ::f} }
proc ask_save {{a {}} {b {}}} { return yes }
proc count_wires {file} {
  if {![file exists $file]} { return -1 }
  set n 0; set fp [open $file r]
  foreach ln [split [read $fp] \n] { if {[string match "N *" $ln]} { incr n } }
  close $fp; return $n
}

set bak $work/descend_parent~.sch

# 1) loading does NOT create or touch the backup
file delete -force $bak
xschem load $work/descend_parent.sch
ck "load does not create a backup" [expr {![file exists $bak]}]

# 2) a genuine edit writes the backup immediately, with current content
xschem wire 200 300 300 300
ck "edit writes the backup immediately" [file exists $bak]
ck "backup reflects the live edit (2 wires)" [expr {[count_wires $bak] == 2}]

# 3) a highlight is not an edit -> no backup write
file delete -force $bak
xschem unselect_all; xschem select instance 0; catch {xschem hilight}
xschem unselect_all
ck "highlight does not write a backup" [expr {![file exists $bak]}]

# 4) a real save removes the backup and the buffer goes clean
xschem wire 400 300 500 300   ;# re-dirty -> backup recreated by the edit hook
ck "edit recreated the backup" [file exists $bak]
xschem save                   ;# save to the current (tmp) file
ck "real save removes the backup" [expr {![file exists $bak]}]
ck "buffer is clean after save (modified==0)" [expr {[xschem get modified] == 0}]

# 5) loading a file with a stale ~ present must NOT delete it (recovery artifact)
close [open $bak w]           ;# create a dummy stale backup
xschem load $work/descend_parent.sch
ck "load preserves a pre-existing ~ (no silent delete)" [file exists $bak]
file delete -force $bak

puts [expr {$::f == 0 ? "RESULT: ALL PASS" : "RESULT: $::f FAILED"}]
exit [expr {$::f != 0}]
