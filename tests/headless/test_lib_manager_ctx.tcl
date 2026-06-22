# Phase 7b (library-manager) — right-click context menu GUI wiring. Drives the
# Library Manager's do_* workers (the dialog-free seam under each ctx_* menu
# action) against a private temp library, asserting both the backend effect and
# that the panes refresh / reselect correctly. The modal dialogs and tk_popup
# remain a manual eyeball item.
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_lib_manager_ctx.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc touch {f {txt {v {xschem}}}} {
  file mkdir [file dirname $f]; set fp [open $f w]; puts $fp $txt; close $fp
}
proc has {lib cell} { expr {[lsearch [xschem lib_cells $lib] $cell] >= 0} }
# panes are ttk::treeview now: row ids == item names, so children{} is the list
proc lb {col} { return [.libmgr.pw.$col.lb children {}] }
proc tvsel {col name} { .libmgr.pw.$col.lb selection set $name; .libmgr.pw.$col.lb focus $name }

# --- private fixture (never touches the repo libraries) ---------------------
set tmp [file join [pwd] _ctx_[pid]]
file delete -force $tmp
touch $tmp/tlib/inv.sym "v {inv sym}"
touch $tmp/tlib/inv.sch "v {inv sch}"
touch $tmp/tlib/buf/schematic/buf.sch "v {buf sch}"
touch $tmp/tlib/buf/symbol/buf.sym    "v {buf sym}"
file mkdir $tmp/dlib
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; puts $fp "DEFINE dlib $tmp/dlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

library_manager
update idletasks

# CTX1 — the three context menus are built and attached
check "CTX1 context menus exist" [expr {[winfo exists .libmgr.mlib] && \
  [winfo exists .libmgr.mcell] && [winfo exists .libmgr.mview]}] {}

# CTX2 — cell menu carries Copy/Rename/Delete + the read-only open
set labels {}
for {set i 0} {$i <= [.libmgr.mcell index end]} {incr i} {
  if {[.libmgr.mcell type $i] eq "command"} { lappend labels [.libmgr.mcell entrycget $i -label] }
}
check "CTX2 cell menu has the core ops" [expr {
  [lsearch $labels "Copy…"] >= 0 && [lsearch $labels "Rename…"] >= 0 &&
  [lsearch $labels "Delete"] >= 0 && [lsearch $labels "Open (read-only)"] >= 0}] "(=> $labels)"

# CTX3 — ctx_post selects the row under the pointer and syncs the panes
tvsel lib tlib
libmgr::on_lib
check "CTX3 selecting tlib fills cells" [expr {[lsearch [lb cell] inv] >= 0 && [lsearch [lb cell] buf] >= 0}] "(=> [lb cell])"

# CTX3b — the REAL right-click path (regression: ttk::treeview `identify item x y`
# needs both coords; a one-arg `identify row $y` misparses as legacy and throws).
update idletasks
set bb [.libmgr.pw.cell.lb bbox inv]
if {$bb ne ""} {
  lassign $bb bx by bw bh
  set cx [expr {$bx + 2}]; set cy [expr {$by + 2}]
  check "CTX3b identify item returns the pointed row id" \
    [expr {[.libmgr.pw.cell.lb identify item $cx $cy] eq "inv"}] "(=> [.libmgr.pw.cell.lb identify item $cx $cy])"
  set perr [catch {libmgr::ctx_post cell $cx $cy 1 1} pmsg]
  catch {.libmgr.mcell unpost}
  check "CTX3c ctx_post runs without error and selects the row" \
    [expr {$perr == 0 && [libmgr::cursel .libmgr.pw.cell.lb] eq "inv"}] "(err=$perr msg=$pmsg sel=[libmgr::cursel .libmgr.pw.cell.lb])"
} else {
  check "CTX3b cell row visible for identify" 0 "(bbox empty — row not rendered)"
}

# CTX4 — copy a flat cell into another library; panes refresh onto the dest
tvsel cell inv
libmgr::on_cell
check "CTX4a do_copy_cell succeeds" [libmgr::do_copy_cell tlib inv dlib inv] {}
check "CTX4b copy landed in dest library" [has dlib inv] {}
check "CTX4c source cell untouched" [has tlib inv] {}
check "CTX4d panes reselected onto dest" [expr {$libmgr::sel_lib eq "dlib" && $libmgr::sel_cell eq "inv"}] \
  "(=> $libmgr::sel_lib / $libmgr::sel_cell)"

# CTX5 — rename a nested cell in place; pane shows the new name, old one gone
check "CTX5a do_rename_cell succeeds" [libmgr::do_rename_cell tlib buf tlib buffer] {}
check "CTX5b renamed cell present, old gone" [expr {[has tlib buffer] && ![has tlib buf]}] {}
check "CTX5c cell pane reflects rename" [expr {[lsearch [lb cell] buffer] >= 0 && [lsearch [lb cell] buf] < 0}] "(=> [lb cell])"

# CTX6 — new cell appears and is selected
check "CTX6a do_new_cell succeeds" [libmgr::do_new_cell tlib fresh] {}
check "CTX6b new cell present + selected" [expr {[has tlib fresh] && $libmgr::sel_cell eq "fresh"}] {}
check "CTX6c new cell has schematic view" [expr {[lsearch [lb view] schematic] >= 0}] "(=> [lb view])"

# CTX7 — delete a view (recoverable); the other view remains
tvsel cell buffer
libmgr::on_cell
check "CTX7a do_delete_view succeeds" [libmgr::do_delete_view tlib buffer symbol] {}
check "CTX7b view trashed, cell + other view remain" [expr {[has tlib buffer] && \
  [lsearch [xschem cell_views tlib buffer] symbol] < 0 && \
  [lsearch [xschem cell_views tlib buffer] schematic] >= 0}] "(=> [xschem cell_views tlib buffer])"
check "CTX7c symbol view recoverable from trash" [file exists [file join $tmp tlib .xschem_trash symbol]] {}

# CTX8 — delete a whole cell (recoverable)
check "CTX8a do_delete_cell succeeds" [libmgr::do_delete_cell tlib inv] {}
check "CTX8b cell gone from library + pane" [expr {![has tlib inv] && [lsearch [lb cell] inv] < 0}] {}

# CTX9 — new library registers and shows in the Library pane
check "CTX9a do_new_library succeeds" [libmgr::do_new_library extra [file join $tmp extra]] {}
check "CTX9b new library visible" [expr {[lsearch [lb lib] extra] >= 0 && [library_resolve extra] ne {}}] "(=> [lb lib])"

# CTX10 — unregister removes it from the registry/pane but keeps files
check "CTX10a do_unregister succeeds" [libmgr::do_unregister extra] {}
check "CTX10b library gone from registry + pane" [expr {[library_resolve extra] eq {} && [lsearch [lb lib] extra] < 0}] {}
check "CTX10c files left on disk" [file isdirectory [file join $tmp extra]] {}

# CTX11 — backend error surfaces via status, do_* returns 0 (no crash)
check "CTX11 collision is a soft failure" [expr {[libmgr::do_copy_cell tlib buffer tlib buffer] == 0}] \
  "(status: [.libmgr.status cget -text])"

# --- view-level ops on nested cell 'buffer' (schematic view) ----------------
tvsel lib tlib
libmgr::on_lib
tvsel cell buffer
libmgr::on_cell

# CTX12 — rename a view; pane relabels + reselects, and it still resolves to open
check "CTX12a do_rename_view succeeds" [libmgr::do_rename_view tlib buffer schematic sch_main] {}
check "CTX12b view pane relabeled + reselected" [expr {[lsearch [lb view] sch_main] >= 0 && \
  [lsearch [lb view] schematic] < 0 && [libmgr::cursel .libmgr.pw.view.lb] eq "sch_main"}] "(=> [lb view])"
check "CTX12c alt-named schematic view resolves for open" \
  [string match {*buffer/sch_main/buffer.sch} [xschem cellview_path tlib/buffer sch_main]] "(=> [xschem cellview_path tlib/buffer sch_main])"

# CTX13 — new typed view
check "CTX13a do_new_view (symbol) succeeds" [libmgr::do_new_view tlib buffer sym_v symbol] {}
check "CTX13b new view present + resolves to a .sym" [expr {[lsearch [lb view] sym_v] >= 0 && \
  [string match {*sym_v/buffer.sym} [xschem cellview_path tlib/buffer sym_v]]}] "(=> [lb view])"

# CTX14 — copy a view within the cell
check "CTX14a do_copy_view succeeds" [libmgr::do_copy_view tlib buffer sch_main tlib buffer sch_two] {}
check "CTX14b copy added, source kept" [expr {[lsearch [lb view] sch_two] >= 0 && [lsearch [lb view] sch_main] >= 0}] "(=> [lb view])"

# CTX15 — copy a view into a NEW cell (datafile renamed to the dest cell)
check "CTX15a do_copy_view into a new cell" [libmgr::do_copy_view tlib buffer sch_main tlib vnew schematic] {}
check "CTX15b new cell carries the view, datafile renamed" [expr {[has tlib vnew] && \
  [file exists [file join $tmp tlib vnew schematic vnew.sch]]}] {}

# CTX16 — view-name collision is a soft failure (status set, do_* returns 0)
check "CTX16 view rename collision is a soft failure" [expr {[libmgr::do_rename_view tlib buffer sch_main sch_two] == 0}] \
  "(status: [.libmgr.status cget -text])"

destroy .libmgr
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
