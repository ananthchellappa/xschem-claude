# P1: "Make symbol from schematic" routes the .sym into the OA library's symbol
# view dir. Spec: doc/claude/specs/create_symbol_view.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_make_symbol_view.tcl
#
# Nested/OA cell <lib>/<cell>/schematic/<cell>.sch -> symbol becomes the cell's
# symbol view <lib>/<cell>/symbol/<cell>.sym (NOT next to the schematic). Flat /
# unregistered keeps the legacy same-dir <cell>.sym.

set work /tmp/p1_makesym_work
file delete -force $work; file mkdir $work

proc mk_sch {path} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {}"; puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
  puts $fp "C {ipin.sym} 0 0 0 0 {name=p1 lab=IN}"
  puts $fp "C {opin.sym} 100 0 0 0 {name=p2 lab=OUT}"
  close $fp
}

# nested library "nlib" with cell "amp" (schematic view) + a flat cell
file mkdir $work/nlib/amp/schematic
mk_sch $work/nlib/amp/schematic/amp.sch
mk_sch $work/nlib/flatamp.sch
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work/nlib:$XSCHEM_LIBRARY_PATH"

set ::fails 0
proc check {name ok} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout; if {!$ok} {incr ::fails} }
proc result {} { puts [expr {$::fails==0 ? {RESULT: ALL PASS} : "RESULT: $::fails FAILED"}]; flush stdout; exit [expr {$::fails!=0}] }

# --- symbol_view_path (pure) ---
check "nested symbol_view_path -> symbol/ view" \
  [expr {[symbol_view_path $work/nlib/amp/schematic/amp.sch] eq "$work/nlib/amp/symbol/amp.sym"}]
check "flat symbol_view_path -> same dir" \
  [expr {[symbol_view_path $work/nlib/flatamp.sch] eq "$work/nlib/flatamp.sym"}]

# --- make_symbol generation (nested) ---
make_symbol $work/nlib/amp/schematic/amp.sch
check "nested: symbol created in the symbol/ view dir" [file exists $work/nlib/amp/symbol/amp.sym]
check "nested: symbol NOT written into schematic/ dir" \
  [expr {![file exists $work/nlib/amp/schematic/amp.sym]}]
set f [open $work/nlib/amp/symbol/amp.sym]; set symdata [read $f]; close $f
check "nested: generated symbol has both pins (dir=in + dir=out)" \
  [expr {[regexp {dir=in} $symdata] && [regexp {dir=out} $symdata]}]

# --- make_symbol generation (flat) ---
make_symbol $work/nlib/flatamp.sch
check "flat: symbol written next to the schematic" [file exists $work/nlib/flatamp.sym]

result
