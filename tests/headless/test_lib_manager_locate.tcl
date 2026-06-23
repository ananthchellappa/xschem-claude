# Library Manager locate cascade (CTRL-ALT-S -> locate_selected_in_libmgr ->
# xschem library_manager {lib cell view} -> libmgr::locate -> refresh_after).
#
# Regression for two bugs that left only the LIBRARY selected, not lib+cell+view:
#  1. libmgr::locate ran dead listbox code ($lb get 0 end) that errors on the
#     ttk::treeview panes (the listbox->treeview migration).
#  2. refresh_after's `selection set` queues a deferred <<TreeviewSelect>> that
#     re-runs on_lib and CLEARS the Cell/View panes once the event loop turns -- so
#     the cascade looked right until the first `update`, then collapsed to lib-only.
#     Fixed with a suppress_select guard reset via `after idle`.
#
# Needs X. Run from the repo ROOT (so the in-repo OA registry resolves):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_lib_manager_locate.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}

set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]

# Use ONLY the in-repo OA registry (lib/cell/view), like cadence_style_rc does.
set ::XSCHEM_LIBRARY_DEFS [file join $repo xschem_libraries_oa library.defs]
set ::library_registry_defs_only 1

# pick a real {lib cell view} from the registry
set lib [lindex [dict keys [library_defs_registry]] 0]
set cell [lindex [xschem lib_cells $lib] 0]
set view [lindex [xschem cell_views $lib $cell] 0]

catch {destroy .libmgr}
library_manager
update

# LM-LOC1 -- locate selects all three panes and does not error
set rc [catch {libmgr::locate [list $lib $cell $view]} e]
check "LM-LOC1 locate runs without error (no listbox API on treeview)" \
  [expr {$rc == 0}] "(rc=$rc e=$e)"

# LM-LOC2 -- the selection SURVIVES the event loop (the deferred-clobber bug). This
# is the discriminating check: pre-fix it passed before `update`, then collapsed.
update
set ls [.libmgr.pw.lib.lb selection]
set cs [.libmgr.pw.cell.lb selection]
set vs [.libmgr.pw.view.lb selection]
check "LM-LOC2 lib+cell+view stay selected after update (no deferred clobber)" \
  [expr {$ls eq $lib && $cs eq $cell && $vs eq $view}] \
  "(lib=$ls cell=$cs view=$vs want $lib/$cell/$view)"

# LM-LOC3 -- a real user library change still cascades (clears downstream). Guard
# that the suppress flag did not get stuck on.
set lib2 {}
foreach L [.libmgr.pw.lib.lb children {}] { if {$L ne $lib} { set lib2 $L; break } }
if {$lib2 ne {}} {
  .libmgr.pw.lib.lb selection set $lib2
  update
  check "LM-LOC3 picking another library still clears the old cell/view selection" \
    [expr {[.libmgr.pw.cell.lb selection] eq {} && [.libmgr.pw.view.lb selection] eq {} \
           && [llength [.libmgr.pw.cell.lb children {}]] > 0}] \
    "(cell sel=[.libmgr.pw.cell.lb selection] cells=[llength [.libmgr.pw.cell.lb children {}]])"
} else {
  check "LM-LOC3 picking another library still clears the old cell/view selection" 1 "(only one library; skipped)"
}

catch {destroy .libmgr}
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
