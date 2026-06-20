# Phase 7a (library-manager) — headless smoke of the Library Manager panes.
# Cadence-style layout: three always-visible columns Library | Cell | View
# (left->right). Selecting a library fills the Cell list; selecting a cell fills
# the View list. This drives the real listbox logic against xschem_libraries_oa;
# pixels / interaction remain a manual eyeball item.
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_lib_manager_gui.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc lb_items {lb} { return [$lb get 0 end] }
proc lb_index {lb txt} {
  set i 0; foreach v [$lb get 0 end] { if {$v eq $txt} { return $i }; incr i }; return -1
}
# select item $txt in listbox $lb and fire the given handler
proc lb_pick {lb txt handler} {
  set i [lb_index $lb $txt]
  if {$i < 0} return
  $lb selection clear 0 end; $lb selection set $i; $lb activate $i
  eval $handler
}

set repo [file normalize [file join [pwd] ..]]
set ::XSCHEM_LIBRARY_DEFS [file join $repo xschem_libraries_oa library.defs]

library_manager
update idletasks
set libLb  .libmgr.pw.lib.lb
set cellLb .libmgr.pw.cell.lb
set viewLb .libmgr.pw.view.lb
check "GUI1 three panes exist" [expr {[winfo exists $libLb] && [winfo exists $cellLb] && [winfo exists $viewLb]}] {}

# library pane lists the libraries
set libs [lb_items $libLb]
check "GUI2 library pane populated" [expr {[lsearch $libs devices] >= 0 && [lsearch $libs examples] >= 0}] \
  "(=> [llength $libs] libs)"

# cells/views start empty until a selection is made (panes are always present)
check "GUI3 cell+view panes start empty" [expr {[lb_items $cellLb] eq {} && [lb_items $viewLb] eq {}}] {}

# select 'devices' -> cell pane fills
lb_pick $libLb devices libmgr::on_lib
update idletasks
set cells [lb_items $cellLb]
check "GUI4 selecting a library fills cells" [expr {[llength $cells] > 20 && [lsearch $cells res] >= 0}] \
  "(=> [llength $cells] cells)"

# selecting a different library replaces the cell list (no stale rows)
lb_pick $libLb examples libmgr::on_lib
update idletasks
check "GUI5 switching library replaces cells" [expr {[lsearch [lb_items $cellLb] cmos_inv] >= 0}] \
  "(=> [llength [lb_items $cellLb]] cells)"

# select 'cmos_inv' -> view pane fills with its views
lb_pick $cellLb cmos_inv libmgr::on_cell
update idletasks
set views [lb_items $viewLb]
check "GUI6 selecting a cell fills views" [expr {[lsearch $views schematic] >= 0 && [lsearch $views symbol] >= 0}] \
  "(=> $views)"

# current selection resolves to {lib cell}
check "GUI7 current_cell resolves selection" [expr {[libmgr::current_cell] eq {examples cmos_inv}}] \
  "(=> [libmgr::current_cell])"

# GUI8 — "New window" on: each opened cell gets its own window/tab
set libmgr::new_window 1
set n0 [xschem get ntabs]
lb_pick $cellLb cmos_inv libmgr::on_cell; libmgr::open_view
set n1 [xschem get ntabs]
lb_pick $cellLb nand2 libmgr::on_cell; libmgr::open_view
set n2 [xschem get ntabs]
check "GUI8 new-window mode adds a tab per open" [expr {$n1 == $n0 + 1 && $n2 == $n1 + 1}] "(=> $n0 $n1 $n2)"

# GUI9 — "New window" off: opening reuses the current window (no new tab)
set libmgr::new_window 0
lb_pick $cellLb flop libmgr::on_cell; libmgr::open_view
set n3 [xschem get ntabs]
check "GUI9 current-window mode reuses the tab" [expr {$n3 == $n2}] "(=> $n2 -> $n3)"

# GUI10 — a SYMBOL view can be opened (for editing), not only placed
lb_pick $libLb  devices libmgr::on_lib
lb_pick $cellLb res     libmgr::on_cell
lb_pick $viewLb symbol  libmgr::on_view
libmgr::open_view
set want [xschem cellview_path devices/res symbol]
check "GUI10 symbol view opens for editing" [expr {[xschem get schname] eq $want}] \
  "(=> [xschem get schname])"

destroy .libmgr
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
