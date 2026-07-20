# Library-Manager smoke for the gf180mcuD migrated workarea (doc/claude/specs/gf180mcud_workarea.md).
#
# Verifies the shipped gf180mcuD/ registry the way the Library Manager consumes it:
#   - gf180mcuD/xschem_libs/library.defs registers exactly the intended libraries;
#   - devices + the general libs are wired to the repo's xschem_libs_newsym/<lib>
#     (not duplicated);
#   - representative cells resolve to real <lib>/<cell>/{symbol,schematic}/<cell>.<ext>
#     files, including cross-lib (devices).
# Registry-only, no Tk: does NOT source cadence_style_rc (that binds .drw). It sets the
# same registry vars the rc sets, then reads `library_list` (what the Library Manager shows).
# Also greps the shipped rc so the wiring itself can't silently regress.
#
# Pure headless. Run from the repo ROOT (or via run_regression.tcl):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_gf180mcud_libmgr.tcl
# Prints "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locate the shipped workarea relative to THIS script (cwd-independent) ---
set here   [file normalize [file dirname [info script]]]        ;# tests/headless
set repo   [file normalize [file join $here .. ..]]             ;# repo root
set wsdefs [file join $repo gf180mcuD xschem_libs library.defs]
set wsrc   [file join $repo gf180mcuD cadence_style_rc]

check_true "library.defs exists" [file isfile $wsdefs]
check_true "cadence_style_rc exists" [file isfile $wsrc]

# --- set the registry the same way gf180mcuD/cadence_style_rc does ---
set ::XSCHEM_LIBRARY_DEFS $wsdefs
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

# --- what the Library Manager will list ---
array set libpath {}
set names {}
foreach pair [library_list] {
  lassign $pair nm pth
  lappend names $nm
  set libpath($nm) $pth
}
set names [lsort $names]
set expect [lsort {devices gf180mcu_pr gf180mcu_tests \
                   analyses examples ngspice ngspice_verilog_cosim xschem_simulator}]
check "library_list = exactly the 8 intended libs" $names $expect

# --- general libs wired to the repo's already-migrated newsym copy (not duplicated) ---
foreach L {devices analyses examples ngspice ngspice_verilog_cosim xschem_simulator} {
  check_true "$L -> xschem_libs_newsym/$L (outside gf180mcuD/)" \
    [expr {[info exists libpath($L)] && [string match *xschem_libs_newsym/$L $libpath($L)] \
           && ![string match */gf180mcuD/* $libpath($L)]}]
}

# --- representative cells resolve to real files ---
proc symfile {base cell} { return [file join $base $cell symbol $cell.sym] }
proc schfile {base cell} { return [file join $base $cell schematic $cell.sch] }
check_true "gf180mcu_pr/nfet_03v3 symbol resolves" \
  [file isfile [symfile $libpath(gf180mcu_pr) nfet_03v3]]
check_true "gf180mcu_pr/pfet_03v3 symbol resolves" \
  [file isfile [symfile $libpath(gf180mcu_pr) pfet_03v3]]
check_true "gf180mcu_pr/cap_mim_1f0fF symbol resolves" \
  [file isfile [symfile $libpath(gf180mcu_pr) cap_mim_1f0fF]]
check_true "gf180mcu_tests/test_nfet_03v3 schematic resolves" \
  [file isfile [schfile $libpath(gf180mcu_tests) test_nfet_03v3]]
check_true "gf180mcu_tests/0_top schematic resolves (device gallery)" \
  [file isfile [schfile $libpath(gf180mcu_tests) 0_top]]
check_true "devices/vsource symbol resolves (cross-lib -> newsym)" \
  [file isfile [symfile $libpath(devices) vsource]]
check_true "devices/code_shown symbol resolves (models block host)" \
  [file isfile [symfile $libpath(devices) code_shown]]

# --- cross-lib reference rewrite baked into a migrated testbench ---
set tsch [schfile $libpath(gf180mcu_tests) test_nfet_03v3]
set txt [read [set f [open $tsch r]]]; close $f
check_true "testbench references gf180mcu_pr/nfet_03v3 (lib-qualified primitive)" \
  [expr {[string first {C {gf180mcu_pr/nfet_03v3}} $txt] >= 0}]
check_true "testbench references devices/code_shown (index-only strip)" \
  [expr {[string first {C {devices/code_shown}} $txt] >= 0}]
check_true "testbench carries no stale symbols/ dir-prefixed ref" \
  [expr {[string first {symbols/} $txt] < 0}]

# --- library sizes ---
check_true "gf180mcu_pr has 66 cell dirs" \
  [expr {[llength [glob -nocomplain -type d [file join $libpath(gf180mcu_pr) *]]] == 66}]
check_true "gf180mcu_tests has 59 cell dirs" \
  [expr {[llength [glob -nocomplain -type d [file join $libpath(gf180mcu_tests) *]]] == 59}]

# --- vendored models present and self-contained ---
set mdir [file join $repo gf180mcuD models]
foreach m {design.spice sm141064.spice sm141064_mim.spice smbb000149.spice} {
  check_true "model $m vendored" [file isfile [file join $mdir $m]]
}
check_true "sm141064.ngspice symlink resolves" [file exists [file join $mdir sm141064.ngspice]]

# --- rc wiring must not silently regress (grep the shipped rc) ---
set rc [read [set f [open $wsrc r]]]; close $f
check_true "rc points XSCHEM_LIBRARY_DEFS at xschem_libs/library.defs" \
  [expr {[regexp {XSCHEM_LIBRARY_DEFS.*xschem_libs.*library\.defs} $rc]}]
check_true "rc sets library_registry_defs_only 1" \
  [expr {[regexp {library_registry_defs_only\s+1} $rc]}]
check_true "rc sets 180MCU_MODELS under models/" \
  [expr {[regexp {180MCU_MODELS.*models} $rc]}]

# --- verdict ---
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
