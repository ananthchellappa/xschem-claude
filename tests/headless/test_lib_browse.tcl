# Phase 7a (library-manager) — enumeration queries that back the Library Manager
# tree (Library -> Cell -> View). Read-only, built on the Phase 1 registry:
#   xschem lib_cells <lib>          -> sorted cell names in a library
#   xschem cell_views <lib> <cell>  -> sorted views present for a cell
# A cell is a subdir of the library that holds a view dir; a view is a subdir of
# the cell that holds a <cell>.<ext> datafile (general: schematic/symbol/...).
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_lib_browse.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc q {args} { if {[catch {xschem {*}$args} r]} { return "<no-cmd>" }; return $r }

# --- fixture: lib 'tlib' with inv (both views), res (symbol only), buf (sch only)
set tmp [file join [pwd] _browse_[pid]]
file delete -force $tmp
proc touch {f} { file mkdir [file dirname $f]; set fp [open $f w]; puts $fp "v {xschem}"; close $fp }
touch $tmp/tlib/inv/symbol/inv.sym
touch $tmp/tlib/inv/schematic/inv.sch
touch $tmp/tlib/res/symbol/res.sym
touch $tmp/tlib/buf/schematic/buf.sch
file mkdir $tmp/tlib/notacell          ;# empty dir: must NOT be reported as a cell
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

# --- LB1 — lib_cells lists cells (dirs with a view), sorted, excludes empties --
check "LB1 lib_cells enumerates cells" [expr {[q lib_cells tlib] eq {buf inv res}}] "(=> [q lib_cells tlib])"

# --- LB2 — cell_views per cell ---------------------------------------------
check "LB2a inv has both views"   [expr {[q cell_views tlib inv] eq {schematic symbol}}] "(=> [q cell_views tlib inv])"
check "LB2b res symbol-only"      [expr {[q cell_views tlib res] eq {symbol}}]            "(=> [q cell_views tlib res])"
check "LB2c buf schematic-only"   [expr {[q cell_views tlib buf] eq {schematic}}]         "(=> [q cell_views tlib buf])"

# --- LB3 — unknown library / cell -> empty ---------------------------------
check "LB3a unknown lib empty"  [expr {[q lib_cells nolib] eq {}}]            "(=> '[q lib_cells nolib]')"
check "LB3b unknown cell empty" [expr {[q cell_views tlib nocell] eq {}}]     "(=> '[q cell_views tlib nocell]')"

# --- LB4 — a FLAT library dir on the search path is a library too -----------
# (no defs entry, no tag): named by basename, with flat-layout cells/views.
# This is what makes the Library Manager non-empty in a stock install.
file mkdir $tmp/flatlib
touch $tmp/flatlib/fa.sym
touch $tmp/flatlib/fb.sch
touch $tmp/flatlib/fc.sym
touch $tmp/flatlib/fc.sch
lappend ::pathlist "$tmp/flatlib"

proc lib_listed {name} { foreach p [q libraries] { if {[lindex $p 0] eq $name} { return 1 } }; return 0 }
check "LB4 flat search-path dir is a library" [lib_listed flatlib] {}
check "LB5 flat lib enumerates cells" [expr {[q lib_cells flatlib] eq {fa fb fc}}] "(=> [q lib_cells flatlib])"
check "LB6a flat cell both views" [expr {[q cell_views flatlib fc] eq {schematic symbol}}] "(=> [q cell_views flatlib fc])"
check "LB6b flat cell symbol-only" [expr {[q cell_views flatlib fa] eq {symbol}}] "(=> [q cell_views flatlib fa])"
check "LB7 cellview_path resolves a flat cell" \
  [expr {[q cellview_path flatlib/fc symbol] eq "$tmp/flatlib/fc.sym"}] "(=> [q cellview_path flatlib/fc symbol])"

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
