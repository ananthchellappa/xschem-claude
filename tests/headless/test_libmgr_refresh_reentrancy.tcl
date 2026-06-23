# Issue 0024: libmgr::refresh_after must keep its lib->cell->view cascade selected even
# when it is invoked more than once in the same event-loop turn. The suppress_select
# guard is re-enabled via `after idle`; without cancelling a pending reset, two
# refresh_after calls schedule two resets -- the first fires while the second call's
# deferred <<TreeviewSelect>> events are still queued, re-running on_lib/on_cell
# un-suppressed and collapsing the panes to library-only.
#
# RED before fix (when the race triggers): after `update` only the library stays
# selected. GREEN after fix: lib+cell+view all survive the event-loop turn.
#
# Needs X + the in-repo OA registry. Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_libmgr_refresh_reentrancy.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]

set ::XSCHEM_LIBRARY_DEFS [file join $repo xschem_libraries_oa library.defs]
set ::library_registry_defs_only 1

set lib  [lindex [dict keys [library_defs_registry]] 0]
set cell [lindex [xschem lib_cells $lib] 0]
set view [lindex [xschem cell_views $lib $cell] 0]

catch {destroy .libmgr}
library_manager
update

# Two refresh_after calls in the SAME turn (no update between) -> exercises the
# re-entrant double-reset path.
libmgr::refresh_after $lib $cell $view
libmgr::refresh_after $lib $cell $view
update

set ls [.libmgr.pw.lib.lb selection]
set cs [.libmgr.pw.cell.lb selection]
set vs [.libmgr.pw.view.lb selection]
check "RR1 lib+cell+view survive two refresh_after in one turn (no double-reset clobber)" \
  [expr {$ls eq $lib && $cs eq $cell && $vs eq $view}] \
  "(lib=$ls cell=$cs view=$vs want $lib/$cell/$view)"

# RR2 — the suppress flag is not stuck on: a genuine user library change still cascades.
set lib2 {}
foreach L [.libmgr.pw.lib.lb children {}] { if {$L ne $lib} { set lib2 $L; break } }
if {$lib2 ne {}} {
  .libmgr.pw.lib.lb selection set $lib2
  update
  check "RR2 a real library change still clears the old cell/view (flag not stuck)" \
    [expr {[.libmgr.pw.cell.lb selection] eq {} && [.libmgr.pw.view.lb selection] eq {}}] \
    "(cell=[.libmgr.pw.cell.lb selection] view=[.libmgr.pw.view.lb selection])"
} else {
  check "RR2 a real library change still clears the old cell/view (flag not stuck)" 1 "(only one library; skipped)"
}

catch {destroy .libmgr}
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
