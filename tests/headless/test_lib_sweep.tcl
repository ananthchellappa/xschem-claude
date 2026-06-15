# Phase 6 (library-manager) — full sweep: the repo's standard libraries migrated
# to the sibling xschem_library_oa/ (lib/cell/view). The flat xschem_library/ is
# untouched. Migrated set (12): devices examples ngspice ngspice_verilog_cosim
# logic xschem_simulator binto7seg pcb rom8k analyses xTAG rulz-r8c33.
# Intentionally left FLAT (special mechanisms, documented in the README):
# generators, inst_sch_select, gschem_import, viewdraw_import, symgen.
#
# Proof = SEMANTIC EQUIVALENCE: every migrated schematic that has a flat
# counterpart must netlist to the same set of spice statements (path/comment
# lines excluded), with the search setup mirrored (flat: legacy path; migrated:
# library.defs + the oa lib dirs on the path, the intended deployment).
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_lib_sweep.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }
proc body {text} {
  set out {}
  foreach ln [split $text \n] {
    set t [string trim $ln]
    if {$t eq "" || [string index $t 0] eq "*"} continue
    lappend out $t
  }
  return [lsort $out]
}

set repo [file normalize [file join [pwd] ..]]
set OA   [file join $repo xschem_library_oa]
set FLAT [file join $repo xschem_library]
set MIGRATED {devices examples ngspice ngspice_verilog_cosim logic xschem_simulator
              binto7seg pcb rom8k analyses xTAG rulz-r8c33}

# --- P1 — every migrated library is present with cells in view dirs ----------
set allpresent 1
foreach lib $MIGRATED {
  if {[llength [glob -nocomplain [file join $OA $lib */symbol/*.sym] \
                                 [file join $OA $lib */schematic/*.sch]]] == 0} {
    set allpresent 0; puts "    (missing cells for $lib)"
  }
}
check "P1 all 12 libraries migrated with view dirs" $allpresent {}
check "P1b flat tree untouched" [file isfile [file join $FLAT devices/res.sym]] {}

# --- P2 — library.defs registers all 12 -------------------------------------
set defs [file join $OA library.defs]
set ndef 0
if {[file isfile $defs]} {
  foreach lib $MIGRATED { if {[regexp "DEFINE $lib " [slurp $defs]]} { incr ndef } }
}
check "P2 library.defs registers all 12" [expr {$ndef == 12}] "(=> $ndef/12)"

# --- P3 — migrated refs are lib-qualified (spot check) -----------------------
set cm [file join $OA examples/cmos_inv/schematic/cmos_inv.sch]
check "P3 refs lib-qualified" [expr {[file isfile $cm] && [regexp {C \{devices/nmos4\}} [slurp $cm]] \
                                     && ![regexp {C \{nmos4\.sym\}} [slurp $cm]]}] {}

# --- P4 — netlist-equivalence sweep over every migrated schematic ------------
set oadirs {};   foreach d [glob -nocomplain -type d $OA/*]   { lappend oadirs $d }
set flatdirs {}; foreach d [glob -nocomplain -type d $FLAT/*] { lappend flatdirs $d }
proc netlist_body {sch defs dirs outdir} {
  file delete -force $outdir; file mkdir $outdir
  set ::XSCHEM_LIBRARY_DEFS $defs
  set ::pathlist $dirs
  set ::netlist_dir $outdir
  xschem set netlist_type spice
  if {[catch {xschem load $sch}]} { return "<loadfail>" }
  if {[catch {xschem netlist}]}   { return "<nlfail>" }
  set sp [file join $outdir [file rootname [file tail $sch]].spice]
  if {![file exists $sp]} { return "<none>" }
  return [body [slurp $sp]]
}
set tmp [file join [pwd] _sweep_[pid]]
set compared 0; set diffs {}
foreach lib $MIGRATED {
  foreach msch [lsort [glob -nocomplain [file join $OA $lib */schematic/*.sch]]] {
    set cell [file rootname [file tail $msch]]
    set fsch [file join $FLAT $lib $cell.sch]
    if {![file isfile $fsch]} continue
    set fb [netlist_body $fsch  ""    $flatdirs [file join $tmp f]]
    set mb [netlist_body $msch  $defs $oadirs   [file join $tmp m]]
    incr compared
    if {!($fb eq $mb && [llength $fb] > 0)} {
      lappend diffs "$lib/$cell (flat=[llength $fb] mig=[llength $mb])"
    }
  }
}
file delete -force $tmp
check "P4 netlist equivalence over all migrated schematics" \
  [expr {[llength $diffs] == 0 && $compared > 50}] "(compared=$compared, diffs=[llength $diffs])"
foreach d $diffs { puts "    DIFF $d" }

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
