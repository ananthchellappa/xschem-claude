# RED-first CORE tests for the Library/Cell/View Save-As backend.
# Spec: doc/claude/specs/save_as_cellview.md
#
# The GUI form (.saveform + .savebrowse) is X-gated and tested separately; this
# file exercises the widget-INDEPENDENT core headless:
#   saveform::resolve_target {lib cell view type}
#     -> validate the library exists (throw if not), derive the extension from the
#        buffer TYPE (schematic->.sch, symbol->.sym), build and mkdir the target
#        <libpath>/<cell>/<view>/<cell>.<ext>, and return it.
#   then `xschem saveas <path> <type>` writes there and rebinds the buffer identity.
#
# Run headless (no X):
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_save_as_cellview.tcl

set fail 0
proc check {name ok {detail {}}} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc errs {body} { return [catch [list uplevel 1 $body]] }
proc touch {f {txt {v {xschem version=3.4.8 file_version=1.3}}}} {
  file mkdir [file dirname $f]; set fp [open $f w]; puts $fp $txt; close $fp
}

# --- fixture: one registered (writable) library + a temp cwd for untitled ------
set tmp [file join [pwd] _saveas_[pid]]
file delete -force $tmp
file mkdir $tmp/tlib
# a pre-existing cell so enumeration/overwrite can be exercised
touch $tmp/tlib/existing/schematic/existing.sch
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
set lp $tmp/tlib

check "fixture: tlib resolves" [expr {[xschem library tlib] ne {}}] "(=> [xschem library tlib])"

# === R1 — resolve_target builds + mkdirs the nested path, ext from TYPE ========
set p [saveform::resolve_target tlib newcell schematic schematic]
check "R1a schematic target path is <lp>/newcell/schematic/newcell.sch" \
  [expr {$p eq [file join $lp newcell schematic newcell.sch]}] "(=> $p)"
check "R1b the view directory was created" [file isdirectory [file join $lp newcell schematic]] {}

set ps [saveform::resolve_target tlib newcell symbol symbol]
check "R1c symbol target uses .sym and the given view dir" \
  [expr {$ps eq [file join $lp newcell symbol newcell.sym]}] "(=> $ps)"
check "R1d ext derives from TYPE, not the view NAME" \
  [expr {[saveform::resolve_target tlib c2 myview schematic] eq [file join $lp c2 myview c2.sch]}] \
  "(=> [saveform::resolve_target tlib c2 myview schematic])"

# === R2 — unknown library throws (the GUI wraps this in an error popup) ========
check "R2 unknown library throws" [errs {saveform::resolve_target nolib x schematic schematic}] {}
check "R2b a valid library does NOT throw" [expr {![errs {saveform::resolve_target tlib ok schematic schematic}]}] {}

# === R3 — a full save via `xschem saveas <path>` rebinds identity + writes =====
xschem clear force
xschem instance $lp/existing/schematic/existing.sch 0 0 0 0 {name=x1} ;# any content -> modified
# (using the schematic file as a placeholder instance ref is fine for a content+modified marker)
set target [saveform::resolve_target tlib saved sch1 schematic]
xschem saveas $target schematic
check "R3a the datafile was written" [file exists $target] "(=> $target)"
check "R3b buffer identity rebound to the new cellview" \
  [expr {[file normalize [xschem get schname]] eq [file normalize $target]}] "(=> [xschem get schname])"
check "R3c buffer no longer modified after save" [expr {[xschem get modified] == 0}] {}
check "R3d the new cell now enumerates in the library" \
  [expr {[lsearch [xschem lib_cells tlib] saved] >= 0}] "(=> [xschem lib_cells tlib])"
check "R3e the new view enumerates for the cell" \
  [expr {[lsearch [xschem cell_views tlib saved] sch1] >= 0}] "(=> [xschem cell_views tlib saved])"

# === R4 — saving an UNTITLED buffer rebinds off untitled.sch (issue 0060 combo) =
xschem clear force
set was [xschem get schname]
check "R4a fresh buffer is untitled" [string match {*untitled.sch} $was] "(=> $was)"
set t2 [saveform::resolve_target tlib fromblank schematic schematic]
xschem saveas $t2 schematic
check "R4b untitled buffer rebinds to the cellview datafile" \
  [expr {[file normalize [xschem get schname]] eq [file normalize $t2]} && ![string match {*untitled.sch} [xschem get schname]]] \
  "(=> [xschem get schname])"

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
