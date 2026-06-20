# Phase 7b (library-manager) — mutation backend behind the right-click context
# menu. These procs (in src/library_defs.tcl) copy/rename/delete cells & views,
# create cells & libraries and unregister libraries, on BOTH the nested
# (lib/cell/view/<cell>.<ext>) and legacy flat (<cell>.{sym,sch}) layouts.
# Deletes are RECOVERABLE: files move to <libpath>/.xschem_trash/.
#
# Headless (no X needed). Run with --pipe from src/:
#   ./xschem --pipe -q --script ../tests/headless/test_library_ops.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
# does calling `body` raise a Tcl error?  (used to assert guard rails)
proc errs {body} { return [catch [list uplevel 1 $body]] }
proc touch {f {txt {v {xschem}}}} {
  file mkdir [file dirname $f]; set fp [open $f w]; puts $fp $txt; close $fp
}
proc has {lib cell} { expr {[lsearch [xschem lib_cells $lib] $cell] >= 0} }
proc views {lib cell} { return [lsort [xschem cell_views $lib $cell]] }

# --- fixture: two libraries, both layouts -----------------------------------
set tmp [file join [pwd] _libops_[pid]]
file delete -force $tmp

# tlib: flat cell 'inv' (sym+sch), flat 'res' (sym only), nested 'buf' (both)
touch $tmp/tlib/inv.sym "v {inv sym}"
touch $tmp/tlib/inv.sch "v {inv sch}"
touch $tmp/tlib/res.sym "v {res sym}"
touch $tmp/tlib/buf/schematic/buf.sch "v {buf sch}"
touch $tmp/tlib/buf/symbol/buf.sym    "v {buf sym}"
# dlib: empty destination library for cross-library ops
file mkdir $tmp/dlib

set defs [file join $tmp library.defs]
set fp [open $defs w]
puts $fp "DEFINE tlib $tmp/tlib"
puts $fp "DEFINE dlib $tmp/dlib"
close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

set trash [file join $tmp tlib .xschem_trash]

# === delete (recoverable) ====================================================
# flat cell -> both files leave the library, land in trash, content preserved
check "OP1a inv present before delete" [has tlib inv] {}
library_delete_cell tlib inv
check "OP1b flat cell delete removes it" [expr {![has tlib inv]}] {}
check "OP1c trashed file is recoverable" \
  [expr {[file exists [file join $trash inv.sym]] && \
         [string match {*inv sym*} [exec cat [file join $trash inv.sym]]]}] {}

# nested cell -> whole cell dir trashed
library_delete_cell tlib buf
check "OP2a nested cell delete removes it" [expr {![has tlib buf]}] {}
check "OP2b nested cell dir trashed" [file isdirectory [file join $trash buf]] {}

# delete a single VIEW of a nested cell, keeping the cell
touch $tmp/tlib/buf2/schematic/buf2.sch "v {buf2 sch}"
touch $tmp/tlib/buf2/symbol/buf2.sym    "v {buf2 sym}"
check "OP3a buf2 has both views" [expr {[views tlib buf2] eq {schematic symbol}}] "(=> [views tlib buf2])"
library_delete_view tlib buf2 symbol
check "OP3b delete view drops just that view" [expr {[views tlib buf2] eq {schematic}}] "(=> [views tlib buf2])"

# delete the sole (symbol) view of a flat cell -> cell disappears
library_delete_view tlib res symbol
check "OP4 delete flat view removes the file" [expr {![has tlib res]}] {}

# guard: deleting a missing cell errors
check "OP5 delete missing cell errors" [errs {library_delete_cell tlib nope}] {}

# === rename (in place) =======================================================
# rebuild a flat 'inv' and nested 'buf'
touch $tmp/tlib/inv.sym "v {inv sym}"
touch $tmp/tlib/inv.sch "v {inv sch}"
touch $tmp/tlib/buf/schematic/buf.sch "v {buf sch}"
touch $tmp/tlib/buf/symbol/buf.sym    "v {buf sym}"

library_rename_cell tlib inv tlib inv2
check "OP6a flat rename: old gone" [expr {![has tlib inv]}] {}
check "OP6b flat rename: new has both views" [expr {[views tlib inv2] eq {schematic symbol}}] "(=> [views tlib inv2])"

library_rename_cell tlib buf tlib buf_r
check "OP7a nested rename: old gone" [expr {![has tlib buf]}] {}
check "OP7b nested rename: datafiles renamed" \
  [expr {[file exists [file join $tmp tlib buf_r schematic buf_r.sch]] && \
         [file exists [file join $tmp tlib buf_r symbol buf_r.sym]]}] {}

# guard: rename onto an existing cell errors
check "OP8 rename collision errors" [errs {library_rename_cell tlib inv2 tlib buf_r}] {}

# === copy ====================================================================
# same-library copy of a flat cell
library_copy_cell tlib inv2 tlib inv_copy
check "OP9a copy keeps source" [has tlib inv2] {}
check "OP9b copy creates dest with both views" [expr {[views tlib inv_copy] eq {schematic symbol}}] "(=> [views tlib inv_copy])"

# cross-library copy of a nested cell -> appears in dlib, stays in tlib
library_copy_cell tlib buf_r dlib buf_r
check "OP10a cross-lib copy: present in dest" [has dlib buf_r] {}
check "OP10b cross-lib copy: still in source" [has tlib buf_r] {}
check "OP10c cross-lib copy: datafile renamed under dest cell name" \
  [file exists [file join $tmp dlib buf_r schematic buf_r.sch]] {}

# guard: copy onto an existing cell errors
check "OP11 copy collision errors" [errs {library_copy_cell tlib inv2 tlib inv_copy}] {}

# === rename across libraries (= move) ========================================
library_rename_cell tlib inv_copy dlib inv_moved
check "OP12a cross-lib rename: present in dest" [has dlib inv_moved] {}
check "OP12b cross-lib rename: gone from source" [expr {![has tlib inv_copy]}] {}

# === new cell ================================================================
library_new_cell tlib brandnew
check "OP13a new_cell appears in the library" [has tlib brandnew] {}
check "OP13b new_cell defaults to a schematic view" [expr {[views tlib brandnew] eq {schematic}}] "(=> [views tlib brandnew])"
set nf [xschem cellview_path tlib/brandnew schematic]
check "OP13c new_cell file has a valid xschem header" \
  [expr {$nf ne {} && [string match {v \{xschem*} [exec head -1 $nf]]}] "(=> [exec head -1 $nf])"
check "OP14 new_cell collision errors" [errs {library_new_cell tlib brandnew}] {}

# === new library + register ==================================================
set newpath [file join $tmp made_lib]
library_new mylib $newpath
check "OP15a new library resolves" [expr {[library_resolve mylib] ne {}}] "(=> [library_resolve mylib])"
check "OP15b new library dir created" [file isdirectory $newpath] {}
library_new_cell mylib c1
check "OP15c can create a cell in the new library" [has mylib c1] {}
check "OP16 new library name collision errors" [errs {library_new mylib $newpath}] {}

# === unregister ==============================================================
library_unregister mylib
check "OP17a unregister removes from registry" [expr {[library_resolve mylib] eq {}}] {}
check "OP17b unregister leaves files on disk" [file isdirectory $newpath] {}

# auto-discovered library (via pathlist, no DEFINE) cannot be unregistered
file mkdir $tmp/autolib
set fp [open [file join $tmp autolib library.tag] w]; puts $fp "NAME autolib"; close $fp
lappend ::pathlist $tmp/autolib
check "OP18a auto-discovered lib is visible" [expr {[library_resolve autolib] ne {}}] "(=> [library_resolve autolib])"
check "OP18b unregister of auto-discovered lib errors" [errs {library_unregister autolib}] {}

# === view-level copy / rename / new (nested layout) ==========================
# A view's editor type comes from the <cell>.<ext> file it holds, so views are
# freely named: rename relabels the dir (datafile keeps the cell name); copy can
# target another view name / cell / library; new_view creates a typed empty view.
touch $tmp/tlib/vc/schematic/vc.sch "v {vc sch}"
touch $tmp/tlib/vc/symbol/vc.sym    "v {vc sym}"
touch $tmp/tlib/vflat.sym           "v {vflat sym}"

# rename a view: the label changes, the cell's datafile keeps its name
library_rename_view tlib vc symbol sym2
check "VOP1a rename_view relabels the view" [expr {[views tlib vc] eq {schematic sym2}}] "(=> [views tlib vc])"
check "VOP1b renamed view still resolves to the .sym" \
  [expr {[xschem cellview_path tlib/vc sym2] eq [file join $tmp tlib vc sym2 vc.sym]}] "(=> [xschem cellview_path tlib/vc sym2])"

# copy a view within the same cell, under a new name
library_copy_view tlib vc schematic tlib vc sch_copy
check "VOP2a copy_view adds the new view, keeps source" [expr {[views tlib vc] eq {sch_copy schematic sym2}}] "(=> [views tlib vc])"
check "VOP2b copied view resolves to a .sch" \
  [string match {*sch_copy/vc.sch} [xschem cellview_path tlib/vc sch_copy]] "(=> [xschem cellview_path tlib/vc sch_copy])"

# copy a view into a NEW cell -> the datafile is renamed to the dest cell
library_copy_view tlib vc schematic tlib vcopy schematic
check "VOP3a copy_view into a new cell" [has tlib vcopy] {}
check "VOP3b dest datafile renamed to the dest cell" [file exists [file join $tmp tlib vcopy schematic vcopy.sch]] {}

# new typed view under a non-canonical name (schematic type, named 'altsch')
library_new_view tlib vc altsch schematic
check "VOP4a new_view appears" [expr {[lsearch [views tlib vc] altsch] >= 0}] "(=> [views tlib vc])"
check "VOP4b new schematic-typed view holds a .sch and resolves" \
  [string match {*altsch/vc.sch} [xschem cellview_path tlib/vc altsch]] "(=> [xschem cellview_path tlib/vc altsch])"

# guards
check "VOP5 rename onto an existing view errors" [errs {library_rename_view tlib vc schematic sym2}] {}
check "VOP6 copy onto an existing view errors" [errs {library_copy_view tlib vc schematic tlib vc sch_copy}] {}
check "VOP7 new_view name collision errors" [errs {library_new_view tlib vc altsch schematic}] {}
check "VOP8 view ops on a flat cell error" [errs {library_rename_view tlib vflat symbol s2}] {}

# === copy across layout STYLES (destination style wins) ======================
# Fresh, isolated libraries so each style is unambiguous.
set tmp2 [file join [pwd] _libops2_[pid]]
file delete -force $tmp2
# flatlib: only flat cells.  nestlib: only nested cells.  emptylib: no cells.
touch $tmp2/flatlib/fa.sym "v {fa sym}"
touch $tmp2/flatlib/fa.sch "v {fa sch}"
touch $tmp2/nestlib/na/schematic/na.sch "v {na sch}"
touch $tmp2/nestlib/na/symbol/na.sym    "v {na sym}"
file mkdir $tmp2/emptylib
# taglib: empty but tagged LAYOUT flat -> must stay flat even though default=nested
file mkdir $tmp2/taglib
set fp [open [file join $tmp2 taglib library.tag] w]; puts $fp "NAME taglib"; puts $fp "LAYOUT flat"; close $fp
set defs2 [file join $tmp2 library.defs]
set fp [open $defs2 w]
foreach l {flatlib nestlib emptylib taglib} { puts $fp "DEFINE $l $tmp2/$l" }
close $fp
set ::XSCHEM_LIBRARY_DEFS $defs2
set ::library_default_layout nested

# style detection
check "CV0a flatlib style is flat"   [expr {[library_layout_style flatlib]  eq {flat}}]   "(=> [library_layout_style flatlib])"
check "CV0b nestlib style is nested" [expr {[library_layout_style nestlib]  eq {nested}}] "(=> [library_layout_style nestlib])"
check "CV0c emptylib style follows default(nested)" [expr {[library_layout_style emptylib] eq {nested}}] "(=> [library_layout_style emptylib])"
check "CV0d taglib LAYOUT tag forces flat" [expr {[library_layout_style taglib] eq {flat}}] "(=> [library_layout_style taglib])"

# flat source -> nested destination: convert to <cell>/<view>/<cell>.<ext>
library_copy_cell flatlib fa nestlib fa_n
check "CV1a flat->nested present" [has nestlib fa_n] {}
check "CV1b flat->nested has nested datafiles" \
  [expr {[file exists [file join $tmp2 nestlib fa_n schematic fa_n.sch]] && \
         [file exists [file join $tmp2 nestlib fa_n symbol fa_n.sym]]}] {}
check "CV1c flat->nested NOT left flat" [expr {![file exists [file join $tmp2 nestlib fa_n.sch]]}] {}

# flat source -> empty(default nested) destination: also converts
library_copy_cell flatlib fa emptylib fa_e
check "CV2 flat->empty(nested-default) nests" \
  [file exists [file join $tmp2 emptylib fa_e schematic fa_e.sch]] {}

# nested source -> flat destination: flatten to <cell>.<ext>
library_copy_cell nestlib na flatlib na_f
check "CV3a nested->flat present" [has flatlib na_f] {}
check "CV3b nested->flat datafiles flattened" \
  [expr {[file isfile [file join $tmp2 flatlib na_f.sch]] && \
         [file isfile [file join $tmp2 flatlib na_f.sym]]}] {}
check "CV3c nested->flat has no cell dir" [expr {![file isdirectory [file join $tmp2 flatlib na_f]]}] {}

# flat source -> taglib (LAYOUT flat) stays flat despite default=nested
library_copy_cell flatlib fa taglib fa_t
check "CV4 LAYOUT-flat tag keeps copy flat" \
  [expr {[file isfile [file join $tmp2 taglib fa_t.sym]] && \
         ![file isdirectory [file join $tmp2 taglib fa_t]]}] {}

# global default=flat makes an empty destination flat
set ::library_default_layout flat
file mkdir $tmp2/emptflat
set fp [open $defs2 a]; puts $fp "DEFINE emptflat $tmp2/emptflat"; close $fp
library_copy_cell flatlib fa emptflat fa_ef
check "CV5 default=flat nests nothing in an empty lib" \
  [expr {[file isfile [file join $tmp2 emptflat fa_ef.sym]] && \
         ![file isdirectory [file join $tmp2 emptflat fa_ef]]}] {}
set ::library_default_layout nested
file delete -force $tmp2

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
