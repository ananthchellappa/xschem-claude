# Library Manager — bold for revision-controlled items (doc/claude/specs/library_git.md §4.3,
# Phase 3). The three panes migrate from Tk listbox to ttk::treeview so each row
# can carry a per-row font; a library/cell/view whose datafile is git-TRACKED
# renders bold (the `tracked` tag), untracked renders normal.
#
# Needs X. Run with --pipe from src/:
#   REPO=<repo> DISPLAY=:0 ./xschem --rcfile $REPO/tests/headless/minrc \
#       --pipe -q --nolog --script $REPO/tests/headless/test_lib_manager_bold.tcl

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
proc pane {col} { return .libmgr.pw.$col.lb }
# items of a pane (treeview row ids == item names)
proc items {col} { if {[catch {[pane $col] children {}} r]} { return "<ERR>" } ; return $r }
# does row $name in pane $col carry the bold `tracked` tag?
proc bold {col name} {
  if {[catch {[pane $col] item $name -tags} tags]} { return "<ERR>" }
  return [expr {[lsearch -exact $tags tracked] >= 0}]
}
proc pick {col name handler} {
  set t [pane $col]
  $t selection set $name; $t focus $name
  eval $handler
}

# --- fixture: a git-backed library (tracked + untracked cells/views) and a
#     second library that is not under git at all ------------------------------
set tmp [file join [pwd] _bold_[pid]]
file delete -force $tmp
set glib [file join $tmp glib]
touch $glib/and2/symbol/and2.sym    "v {and2 sym}\n"   ;# will be committed -> tracked
ginit $glib
exec git -C $glib add -A
exec git -C $glib commit -q -m seed
touch $glib/and2/schematic/and2.sch "v {and2 sch}\n"   ;# untracked VIEW of a tracked cell
touch $glib/or3/symbol/or3.sym      "v {or3 sym}\n"    ;# untracked CELL
set plib [file join $tmp plainlib]
touch $plib/buf/symbol/buf.sym      "v {buf sym}\n"    ;# library not under git

set defs [file join $tmp library.defs]
set fp [open $defs w]
puts $fp "DEFINE glib $glib"
puts $fp "DEFINE plainlib $plib"
close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
set ::library_registry_defs_only 1

library_manager
update idletasks

# BD1 — the panes are ttk::treeview (the migration itself)
check "BD1 panes are ttk::treeview" [expr {
  [winfo class [pane lib]] eq "Treeview" &&
  [winfo class [pane cell]] eq "Treeview" &&
  [winfo class [pane view]] eq "Treeview"}] "(=> [catch {winfo class [pane lib]} c; set c])"

# BD2 — library pane: a git-tracked library is bold, a non-git one is not
check "BD2a tracked library is bold"      [expr {[bold lib glib] == 1}] "(=> [bold lib glib])"
check "BD2b non-git library is not bold"  [expr {[bold lib plainlib] == 0}] "(=> [bold lib plainlib])"

# BD3 — cell pane: tracked cell bold, untracked cell normal
pick lib glib libmgr::on_lib
check "BD3a tracked cell is bold"     [expr {[bold cell and2] == 1}] "(=> [bold cell and2])"
check "BD3b untracked cell not bold"  [expr {[bold cell or3] == 0}] "(=> [bold cell or3])"

# BD4 — view pane: tracked view bold, untracked view of the same cell normal
pick cell and2 libmgr::on_cell
check "BD4a tracked view is bold"     [expr {[bold view symbol] == 1}] "(=> [bold view symbol])"
check "BD4b untracked view not bold"  [expr {[bold view schematic] == 0}] "(=> [bold view schematic])"

# BD5 — the panes still expose their items (treeview ids == names), so the rest
# of the Library Manager logic keeps working
check "BD5 cell pane lists both cells" [expr {[lsearch [items cell] and2] >= 0 && [lsearch [items cell] or3] >= 0}] "(=> [items cell])"

catch {destroy .libmgr}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
