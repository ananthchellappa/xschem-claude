# Regression for issue 0060 — descending from an UNTITLED (never-saved) schematic and
# returning must NOT lose the top-level content. The parent's unsaved objects live only
# in the cellName~.sch autosave backup across a descend (the single object arrays are
# overwritten by the child); write_backup() used to skip untitled buffers, so go_back()
# found no backup, fell back to loading the nonexistent untitled.sch, cleared the drawing
# and (under X) popped "Unable to open file: …/untitled.sch". The content was lost.
#
# Run TRUE HEADLESS from the repo root (content loss is observable without X):
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_untitled_preserve.tcl

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/descend_untitled_work
file delete -force $work; file mkdir $work
foreach fn {descend_child.sch descend_child.sym} { file copy -force $fixdir/$fn $work/$fn }
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
# descend must never prompt; if it does, fail loudly rather than hang
proc ask_save {{a {}} {b {}}} { incr ::asked; return no }
set ::asked 0

# cd into the work dir so the untitled buffer (and its ~ backup) resolve HERE, not the repo.
cd $work

# --- new blank UNTITLED canvas, place a subcircuit instance (an unsaved edit) ---
xschem clear force
set nm [xschem get schname]
check "fresh buffer is untitled (never saved)" \
  [expr {[file tail $nm] eq "untitled.sch" && ![file exists $nm]}]
xschem instance $work/descend_child.sym 0 0 0 0 {name=x1}
check "instance placed on the untitled canvas, buffer modified" \
  [expr {[xschem get instances] == 1 && [xschem get modified] == 1}]
set bak [regsub {\.sch$} $nm {~.sch}]
check "the untitled edit was autosaved to the ~ backup (issue 0060)" [file exists $bak]

# --- descend into the instance, then return ---
xschem unselect_all
xschem select instance 0
check "descended into the child subcircuit" \
  [expr {[xschem descend] == 1 && [file tail [xschem get schname]] eq "descend_child.sch"}]
xschem go_back

# THE FIX: back at the untitled top level, the placed instance must still be there.
check "returned to the untitled top level (logical identity preserved)" \
  [expr {[file tail [xschem get schname]] eq "untitled.sch"}]
check "0060: untitled top-level content PRESERVED across descend/go_back (no data loss)" \
  [expr {[xschem get instances] == 1}]
check "0060: untitled buffer still flagged modified on return" \
  [expr {[xschem get modified] == 1}]
check "descend did not pop a save prompt" [expr {$::asked == 0}]

result
