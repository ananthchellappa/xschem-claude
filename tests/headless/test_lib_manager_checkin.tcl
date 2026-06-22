# Library Manager — git check-in / check-out / cancel (specs/library_git.md §4.2,
# Phase 4). Drives the dialog-free do_* workers (the testable seam under each
# ctx_* menu action) against a real git-backed library, plus asserts the new
# menu entries exist. Modal commit-comment / confirm dialogs remain manual.
#
# Needs X. Run with --pipe from src/:
#   REPO=<repo> DISPLAY=:0 ./xschem --rcfile $REPO/tests/headless/minrc \
#       --pipe -q --nolog --script $REPO/tests/headless/test_lib_manager_checkin.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc touch {f txt} { file mkdir [file dirname $f]; set fp [open $f w]; puts -nonewline $fp $txt; close $fp }
proc slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }
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

# --- fixture: a git-backed library, one committed cell (and2/symbol) ---------
set tmp [file join [pwd] _ci_[pid]]
file delete -force $tmp
set glib [file join $tmp glib]
touch $glib/and2/symbol/and2.sym "v {and2 sym}\n"
ginit $glib
exec git -C $glib add -A
exec git -C $glib commit -q -m seed
set and2 [file join $glib and2 symbol and2.sym]

set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE glib $glib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
set ::library_registry_defs_only 1

library_manager
update idletasks

# CI1 — new menu entries are present on the three context menus
check "CI1a lib menu: Show Checkouts + Check in" [expr {[has_label .libmgr.mlib "Show Checkouts"] && [has_label .libmgr.mlib "Check in…"]}] "(=> [menu_labels .libmgr.mlib])"
check "CI1b cell menu: Check out / Check in / Cancel checkout" [expr {
  [has_label .libmgr.mcell "Check out"] && [has_label .libmgr.mcell "Check in…"] && [has_label .libmgr.mcell "Cancel checkout"]}] "(=> [menu_labels .libmgr.mcell])"
check "CI1c view menu: Check out / Check in / Cancel checkout" [expr {
  [has_label .libmgr.mview "Check out"] && [has_label .libmgr.mview "Check in…"] && [has_label .libmgr.mview "Cancel checkout"]}] "(=> [menu_labels .libmgr.mview])"

# CI2 — check out a clean, committed view -> recorded as a checkout (marker)
check "CI2a do_checkout (view) succeeds" [expr {[libmgr::do_checkout glib and2 symbol] == 1}] {}
check "CI2b view shows as checked out" [expr {[lsearch [lib_git_checkouts $glib] and2/symbol] >= 0}] "(=> [lib_git_checkouts $glib])"

# CI3 — Show Checkouts: a local-mode-labelled report window
check "CI3a checkouts_text labels local mode + lists the view" [expr {
  [string match -nocase "*local*" [libmgr::checkouts_text glib]] &&
  [string match "*and2/symbol*" [libmgr::checkouts_text glib]]}] "(=> [libmgr::checkouts_text glib])"
check "CI3b do_show_checkouts opens a viewdata window" [expr {[libmgr::do_show_checkouts glib] == 1 && \
  [llength [lsearch -all -inline [winfo children .] {.view*}]] >= 1}] {}
catch {foreach w [winfo children .] { if {[string match {.view*} $w]} { destroy $w } }}

# CI4 — check in a modified view with a commit message -> clean afterwards
touch $and2 "v {and2 sym EDITED}\n"
check "CI4a modified before check-in" [expr {[dict exists [lib_git_status_map $glib] and2/symbol]}] {}
check "CI4b do_checkin (view) succeeds" [expr {[libmgr::do_checkin glib and2 symbol "edit and2"] == 1}] {}
check "CI4c view is clean (committed)" [expr {![dict exists [lib_git_status_map $glib] and2/symbol]}] "(keys: [dict keys [lib_git_status_map $glib]])"
check "CI4d commit recorded in history" [string match "*edit and2*" [lib_git_log $glib [list and2]]] {}

# CI5 — cancel a checkout: roll the datafile back to HEAD
touch $and2 "v {and2 sym DIRTY-AGAIN}\n"
check "CI5a do_cancel_checkout succeeds" [expr {[libmgr::do_cancel_checkout glib and2 symbol] == 1}] {}
check "CI5b datafile restored to committed content" [expr {[slurp $and2] eq "v {and2 sym EDITED}\n"}] "(=> [slurp $and2])"

# CI6 — library-level check-in commits everything pending under the library
touch $glib/or3/symbol/or3.sym "v {or3 sym}\n"   ;# new untracked cell
check "CI6a untracked before" [expr {[dict get [lib_git_status_map $glib] or3/symbol] eq "untracked"}] {}
check "CI6b do_checkin_lib succeeds" [expr {[libmgr::do_checkin_lib glib "add or3"] == 1}] {}
check "CI6c library now clean" [expr {[dict size [lib_git_status_map $glib]] == 0}] "(keys: [dict keys [lib_git_status_map $glib]])"

# CI7 — soft failure: checking in with nothing to commit returns 0 (no crash)
check "CI7 nothing-to-commit is a soft failure" [expr {[libmgr::do_checkin glib and2 symbol "noop"] == 0}] \
  "(status: [.libmgr.status cget -text])"

catch {destroy .libmgr}
catch {foreach w [winfo children .] { if {[string match {.view*} $w]} { destroy $w } }}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
