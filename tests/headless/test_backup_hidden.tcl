# B7: autosave "~" backups (cellName~.sch / cellName~.sym) must never be listed
# as cells. Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_backup_hidden.tcl
#
# Covers the two listing surfaces that enumerate cell files:
#   - the load/save file dialog lister  (setglob -> file_dialog_files2)
#   - the library-browser / insert-symbol matcher (match_file / sub_match_file)
# The real cells must still appear; only the ~ siblings are filtered.

set work /tmp/b7_backup_hidden_work
file delete -force $work; file mkdir $work
foreach f {foo.sch foo~.sch bar.sym bar~.sym} { close [open $work/$f w] }

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
proc has {lst v} { expr {[lsearch -exact $lst $v] >= 0} }

# --- file dialog lister (setglob) -----------------------------------------
global file_dialog_globfilter file_dialog_files2

set file_dialog_globfilter {*.sch}
setglob $work
check "file dialog lists the real cell foo.sch" [has $file_dialog_files2 foo.sch]
check "file dialog hides foo~.sch backup"  [expr {![has $file_dialog_files2 {foo~.sch}]}]

set file_dialog_globfilter {*.sym}
setglob $work
check "file dialog lists the real symbol bar.sym" [has $file_dialog_files2 bar.sym]
check "file dialog hides bar~.sym backup"   [expr {![has $file_dialog_files2 {bar~.sym}]}]

# globfilter '*' (show everything) must still drop the backups
set file_dialog_globfilter {*}
setglob $work
check "file dialog (filter *) lists foo.sch + bar.sym" \
  [expr {[has $file_dialog_files2 foo.sch] && [has $file_dialog_files2 bar.sym]}]
check "file dialog (filter *) hides both ~ backups" \
  [expr {![has $file_dialog_files2 {foo~.sch}] && ![has $file_dialog_files2 {bar~.sym}]}]

# --- library-browser / insert matcher (match_file) ------------------------
set msch [match_file {\.sch$} [list $work]]
check "match_file finds foo.sch" [has $msch $work/foo.sch]
check "match_file hides foo~.sch" [expr {![has $msch $work/foo~.sch]}]

set msym [match_file {\.sym$} [list $work]]
check "match_file finds bar.sym" [has $msym $work/bar.sym]
check "match_file hides bar~.sym" [expr {![has $msym $work/bar~.sym]}]

result
