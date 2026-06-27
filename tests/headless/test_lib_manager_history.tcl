# Library Manager — History form on the cell/view right-click (doc/claude/specs/library_git.md
# §4.2/§4.1). A two-pane, non-modal dialog: the upper ttk::treeview lists commits
# (date + short hash + subject), the lower read-only text shows the SELECTED
# commit's full message. Driven through the do_history_* seam.
#
# Needs X. Run with --pipe from src/:
#   REPO=<repo> DISPLAY=:0 ./xschem --rcfile $REPO/tests/headless/minrc \
#       --pipe -q --nolog --script $REPO/tests/headless/test_lib_manager_history.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc touch {f txt} { file mkdir [file dirname $f]; set fp [open $f w]; puts -nonewline $fp $txt; close $fp }
proc ginit {repo} {
  exec git init -q $repo
  exec git -C $repo config user.email test@example.com
  exec git -C $repo config user.name  Tester
  exec git -C $repo config commit.gpgsign false
}
proc menu_labels {m} {
  set out {}
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[$m type $i] in {command cascade}} { lappend out [$m entrycget $i -label] }
  }
  return $out
}
proc has_label {m l} { return [expr {[lsearch -exact [menu_labels $m] $l] >= 0}] }

# --- fixture: a git-backed library, two commits on and2/symbol --------------
set tmp [file join [pwd] _hist_[pid]]
file delete -force $tmp
set glib [file join $tmp glib]
touch $glib/and2/symbol/and2.sym "v {and2 v1}\n"
ginit $glib
exec git -C $glib add -A
exec git -C $glib commit -q -m "initial and2"
set and2 [file join $glib and2 symbol and2.sym]
touch $and2 "v {and2 v2}\n"
exec git -C $glib add -- and2/symbol/and2.sym
exec git -C $glib commit -q -m "tweak and2" -m "added a second body paragraph"

set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE glib $glib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
set ::library_registry_defs_only 1

library_manager
update idletasks

# HI1 — History entries on the cell and view context menus
check "HI1a cell menu has History" [has_label .libmgr.mcell "History"] "(=> [menu_labels .libmgr.mcell])"
check "HI1b view menu has History" [has_label .libmgr.mview "History"] "(=> [menu_labels .libmgr.mview])"

# HI2 — do_history_view opens the two-pane dialog with the commit list on top
set w [libmgr::do_history_view glib and2 symbol]
update idletasks
check "HI2a dialog window created" [expr {$w ne "" && [winfo exists $w]}] "(=> $w)"
check "HI2b upper pane is a ttk::treeview" [expr {[winfo exists $w.top.tv] && [winfo class $w.top.tv] eq "Treeview"}] {}
check "HI2c lower pane is a text widget" [expr {[winfo exists $w.bot.txt] && [winfo class $w.bot.txt] eq "Text"}] {}
set rows [$w.top.tv children {}]
check "HI2d both commits listed, newest first" [expr {[llength $rows] == 2 && \
  [$w.top.tv set [lindex $rows 0] subject] eq "tweak and2"}] "(=> [llength $rows] rows, top=[$w.top.tv set [lindex $rows 0] subject])"
check "HI2e a row shows a date + short hash column" [expr {
  [regexp {^\d{4}-\d{2}-\d{2}} [$w.top.tv set [lindex $rows 0] date]] &&
  [string length [$w.top.tv set [lindex $rows 0] hash]] > 0}] \
  "(date=[$w.top.tv set [lindex $rows 0] date] hash=[$w.top.tv set [lindex $rows 0] hash])"

# HI3 — selecting a commit shows ITS message in the lower pane
$w.top.tv selection set [lindex $rows 0]
event generate $w.top.tv <<TreeviewSelect>>
update idletasks
set msg [$w.bot.txt get 1.0 end]
check "HI3a lower pane shows selected commit subject" [string match "*tweak and2*" $msg] "(=> [string range $msg 0 80])"
check "HI3b lower pane shows the body paragraph" [string match "*second body paragraph*" $msg] {}

# select the OLDER commit -> lower pane updates, no stale text
$w.top.tv selection set [lindex $rows 1]
event generate $w.top.tv <<TreeviewSelect>>
update idletasks
set msg2 [$w.bot.txt get 1.0 end]
check "HI3c selecting another commit updates the message" [expr {[string match "*initial and2*" $msg2] && ![string match "*second body paragraph*" $msg2]}] "(=> [string range $msg2 0 80])"
catch {destroy $w}

# HI4 — graceful: History on a non-git library reports, opens no commit list
set plib [file join $tmp plainlib]
touch $plib/buf/symbol/buf.sym "v {buf}\n"
set fp [open $defs a]; puts $fp "DEFINE plainlib $plib"; close $fp
libmgr::refresh
set w2 [libmgr::do_history_view plainlib buf symbol]
check "HI4 non-git history degrades, never errors" [expr {$w2 eq "" || ([winfo exists $w2.top.tv] && [llength [$w2.top.tv children {}]] == 0)}] "(=> $w2)"
catch {destroy $w2}

catch {destroy .libmgr}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
