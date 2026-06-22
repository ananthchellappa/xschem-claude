# Library Manager — Maintain menu GUI (specs/library_git.md §4.1, Phase 2).
# Drives the real Tk surface added in library_manager.tcl: the Maintain menubar
# cascade, the multi-select library picker, and Show Status / History rendered
# into the read-only `viewdata` window. The modal picker (vwait) is driven
# non-interactively via an `after` that selects rows and releases the dialog.
#
# Needs X (it builds real toplevels). Run with --pipe from src/:
#   REPO=<repo> DISPLAY=:0 ./xschem --rcfile $REPO/tests/headless/minrc \
#       --pipe -q --nolog --script $REPO/tests/headless/test_lib_manager_maintain.tcl

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
# the menu entry labels of a Tk menu
proc menu_labels {m} {
  set out {}
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[$m type $i] eq "command" || [$m type $i] eq "cascade"} { lappend out [$m entrycget $i -label] }
  }
  return $out
}
# the text of the most-recently-created viewdata window (.view<N>)
proc latest_viewdata_text {} {
  set best ""; set bestn -1
  foreach w [winfo children .] {
    if {[regexp {^\.view(\d+)$} $w -> n] && $n > $bestn} { set bestn $n; set best $w }
  }
  if {$best eq "" || ![winfo exists $best.text]} { return "<none>" }
  return [$best.text get 1.0 end]
}

# --- fixture: a git-backed library with one untracked + one modified cell ----
set tmp [file join [pwd] _maint_[pid]]
file delete -force $tmp
set lib [file join $tmp glib]
touch $lib/and2/symbol/and2.sym "v {and2 sym}\n"
ginit $lib
exec git -C $lib add -A
exec git -C $lib commit -q -m seed
touch $lib/or3/symbol/or3.sym   "v {or3 sym}\n"            ;# untracked cell
touch $lib/and2/symbol/and2.sym "v {and2 sym MODIFIED}\n"  ;# modified cell

set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE glib $lib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
set ::library_registry_defs_only 1

library_manager
update idletasks

# MM1 — the menubar + Maintain cascade exist
check "MM1 menubar attached to the window" [expr {[winfo exists .libmgr.menubar] && \
  [.libmgr cget -menu] eq ".libmgr.menubar"}] {}
check "MM2 Maintain cascade present" [expr {[lsearch [menu_labels .libmgr.menubar] Maintain] >= 0}] "(=> [menu_labels .libmgr.menubar])"
check "MM3 Maintain has Show Status + History" [expr {
  [lsearch [menu_labels .libmgr.menubar.maintain] "Show Status…"] >= 0 &&
  [lsearch [menu_labels .libmgr.menubar.maintain] "History…"] >= 0}] "(=> [menu_labels .libmgr.menubar.maintain])"

# MM4 — Show Status: drive the picker (select all libs, OK), inspect viewdata
after 150 {
  if {[winfo exists .libmgr.mp.lb]} {
    .libmgr.mp.lb selection set 0 end
    set ::libmgr::dlg_done 1
  }
}
libmgr::show_status
update idletasks
set txt [latest_viewdata_text]
check "MM4a status report rendered into a viewdata window" [string match "*Library: glib*" $txt] "(=> [string range $txt 0 60])"
check "MM4b untracked cell shown"  [string match "*or3/symbol*" $txt] {}
check "MM4c modified cell shown as pending" [expr {[string match "*and2/symbol*" $txt] && [string match "*modified*" $txt]}] {}
catch {foreach w [winfo children .] { if {[string match {.view*} $w]} { destroy $w } }}

# MM5 — History likewise renders the git log section
after 150 {
  if {[winfo exists .libmgr.mp.lb]} {
    .libmgr.mp.lb selection set 0 end
    set ::libmgr::dlg_done 1
  }
}
libmgr::show_history
update idletasks
set htxt [latest_viewdata_text]
check "MM5 history report shows the seed commit" [expr {[string match "*Library: glib*" $htxt] && [string match "*seed*" $htxt]}] "(=> [string range $htxt 0 80])"

# MM6 — cancelling the picker opens no report window
set before [llength [lsearch -all -inline [winfo children .] {.view*}]]
after 150 { if {[winfo exists .libmgr.mp]} { set ::libmgr::dlg_done 0 } }
libmgr::show_status
update idletasks
set after [llength [lsearch -all -inline [winfo children .] {.view*}]]
check "MM6 cancel opens no report window" [expr {$after == $before}] "(before=$before after=$after)"

catch {destroy .libmgr}
catch {foreach w [winfo children .] { if {[string match {.view*} $w]} { destroy $w } }}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
