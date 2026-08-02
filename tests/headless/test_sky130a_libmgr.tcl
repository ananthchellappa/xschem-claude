# Library-Manager smoke for the sky130A migrated workarea (doc/claude/specs/sky130_workarea.md).
#
# Verifies the shipped sky130A/ registry the way the Library Manager consumes it:
#   - sky130A/xschem_libs/library.defs registers exactly the intended libraries;
#   - devices is wired to the repo's xschem_libs_newsym/devices (not duplicated);
#   - representative cells resolve to real <lib>/<cell>/symbol/<cell>.sym files,
#     including cross-lib (devices, draft stdcells).
# Registry-only, no Tk: does NOT source cadence_style_rc (that binds .drw). It sets the
# same registry vars the rc sets, then reads `library_list` (what the Library Manager shows).
# Also greps the shipped rc so the wiring itself can't silently regress.
#
# Pure headless. Run from the repo ROOT (or via run_regression.tcl):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sky130a_libmgr.tcl
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
set wsdefs [file join $repo sky130A xschem_libs library.defs]
set wsrc   [file join $repo sky130A cadence_style_rc]

check_true "library.defs exists" [file isfile $wsdefs]
check_true "cadence_style_rc exists" [file isfile $wsrc]

# --- set the registry the same way sky130A/cadence_style_rc does ---
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
# sky130_tests_ase joined the registry in 15bb25ef (the migrated ASE-L testbench
# library); this expectation was left at the pre-15bb25ef set of 11.
set expect [lsort {devices sky130_fd_pr sky130_stdcells sky130_tests mips_cpu stdcells \
                   sky130_tests_ase \
                   analyses examples ngspice ngspice_verilog_cosim xschem_simulator}]
check "library_list = exactly the 12 intended libs" $names $expect

# --- devices wired to the repo's already-migrated newsym copy (not duplicated) ---
check_true "devices -> xschem_libs_newsym/devices" \
  [expr {[info exists libpath(devices)] && [string match *xschem_libs_newsym/devices $libpath(devices)]}]
check_true "devices path is outside sky130A/" \
  [expr {[info exists libpath(devices)] && ![string match */sky130A/* $libpath(devices)]}]

# --- representative cells resolve to real <lib>/<cell>/symbol/<cell>.sym files ---
proc symfile {base cell} { return [file join $base $cell symbol $cell.sym] }
check_true "sky130_fd_pr/nfet_01v8 symbol resolves" \
  [file isfile [symfile $libpath(sky130_fd_pr) nfet_01v8]]
check_true "sky130_fd_pr/corner symbol resolves" \
  [file isfile [symfile $libpath(sky130_fd_pr) corner]]
check_true "devices/vsource symbol resolves (cross-lib -> newsym)" \
  [file isfile [symfile $libpath(devices) vsource]]
check_true "stdcells/AND2 symbol resolves (draft lib)" \
  [file isfile [symfile $libpath(stdcells) AND2]]
# the extra migrated newsym libraries the workarea also exposes
foreach L {analyses examples ngspice ngspice_verilog_cosim xschem_simulator} {
  check_true "$L registered from newsym (outside sky130A/)" \
    [expr {[info exists libpath($L)] && [string match *xschem_libs_newsym/$L $libpath($L)] \
           && ![string match */sky130A/* $libpath($L)]}]
}
check_true "sky130_stdcells has 437 cell dirs" \
  [expr {[llength [glob -nocomplain -type d [file join $libpath(sky130_stdcells) *]]] == 437}]

# --- rc wiring must not silently regress (grep the shipped rc) ---
set rc [read [set f [open $wsrc r]]]; close $f
check_true "rc points XSCHEM_LIBRARY_DEFS at xschem_libs/library.defs" \
  [expr {[regexp {XSCHEM_LIBRARY_DEFS.*xschem_libs.*library\.defs} $rc]}]
check_true "rc sets library_registry_defs_only 1" \
  [expr {[regexp {library_registry_defs_only\s+1} $rc]}]
check_true "rc sets SKYWATER_MODELS under models/" \
  [expr {[regexp {SKYWATER_MODELS.*models} $rc]}]

# --- verdict ---
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
