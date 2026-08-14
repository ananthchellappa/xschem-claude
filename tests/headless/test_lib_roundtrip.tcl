# Phase 3 (library-manager) — load/save round-trip with lib-qualified refs.
# Proves the new model end-to-end through the real place/save/load/netlist path:
#   - placing an instance of a lib-qualified cell (tlib/myres) stores and SAVES
#     the portable "C {tlib/myres}" reference (not an absolute or flat path)
#   - a legacy reference in the SAME schematic (lab_pin.sym from devices/) still
#     works -> mixed-mode is legal
#   - reloading resolves every reference (all instances rebind)
#   - netlisting produces correct connectivity (both resistors share net MID)
#   - save -> load -> save is byte-stable (the round-trip does not churn the file)
#
# Run under X with --pipe (any cwd -- paths derive from this script's location):
#   ./src/xschem --pipe -q --script tests/headless/test_lib_roundtrip.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }

# --- fixture: a new-layout library "tlib" with cell "myres" (a real resistor
#     symbol copied from devices/) registered via a defs file --------------
# repo root from the script's own location (tests/headless/ -> up 2), NOT from
# [pwd]: the old [pwd]/../xschem_library only resolved when launched from src/,
# and from anywhere else the copy failed with a startup Tcl error popup that
# blocked to the audit timeout (same class as test_migrate_engine).
set repo [file normalize [file join [file dirname [info script]] .. ..]]
source [file join [file dirname [info script]] scratch.tcl]
set tmp [test_scratch rt_test]
file mkdir $tmp/tlib/myres/symbol
file copy [file join $repo xschem_library/devices/res.sym] $tmp/tlib/myres/symbol/myres.sym
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

# --- build a small connected schematic --------------------------------------
# res.sym pins: P at (0,-30), M at (0,+30) relative to the instance origin.
# R1@(0,0): P(0,-30) M(0,30);  R2@(300,0): P(300,-30) M(300,30).
# A wire (0,30)-(300,30) ties both M pins together; lab_pin MID names that net;
# lab_pin A / B name the two P pins. devices/ is on the default path so the
# legacy {lab_pin.sym} reference resolves alongside the lib-qualified one.
xschem set netlist_type spice
set ::netlist_dir $tmp
xschem clear force schematic
xschem instance tlib/myres 0 0 0 0 {name=R1 value=1k}
xschem instance tlib/myres 300 0 0 0 {name=R2 value=2k}
xschem wire 0 30 300 30
xschem instance lab_pin.sym 150 30 0 0 {name=l1 lab=MID}
xschem instance lab_pin.sym 0 -30 0 0 {name=l2 lab=A}
xschem instance lab_pin.sym 300 -30 0 0 {name=l3 lab=B}

set schA [file join $tmp roundtrip.sch]
xschem saveas $schA schematic
set A [slurp $schA]

# --- RT1 — the saved file carries the portable lib-qualified reference -------
check "RT1 saved file has C {tlib/myres}" [regexp {C \{tlib/myres\}} $A] {}
# --- RT1b — and NOT an absolute path or the on-disk view path (neither the
#     launch dir nor the scratch fixture tree may leak into a saved reference) -
check "RT1b ref is not absolute/view path" \
  [expr {![regexp {symbol/myres\.sym} $A] && [string first [pwd] $A] < 0 && [string first $tmp $A] < 0}] {}
# --- RT1c — the legacy reference is preserved verbatim (mixed mode) ----------
check "RT1c legacy {lab_pin.sym} preserved" [regexp {C \{lab_pin\.sym\}} $A] {}

# --- RT2 — reload resolves every reference ----------------------------------
xschem load $schA
check "RT2 reload binds all 5 instances" [expr {[xschem get instances] == 5}] "(=> [xschem get instances])"

# --- RT5 — pure round-trip (save -> load -> save) is byte-stable -------------
# Done BEFORE netlisting: netlisting back-annotates the derived net name into
# the wire's lab= cache (pre-existing behavior, unrelated to references), so the
# reference round-trip must be measured without it in the way.
set schB [file join $tmp roundtrip2.sch]
xschem saveas $schB schematic
set B [slurp $schB]
check "RT5 round-trip is byte-stable" [expr {$A eq $B}] "(lenA=[string length $A] lenB=[string length $B])"

# --- RT3/RT4 — netlist connectivity: both resistors land on net MID ---------
# reload A so the current cell name (hence the .spice filename) is "roundtrip"
# again (saveas above switched it to roundtrip2).
xschem load $schA
xschem netlist
set spice [file join $tmp roundtrip.spice]
set haveR1 0; set haveR2 0
if {[file exists $spice]} {
  foreach line [split [slurp $spice] \n] {
    if {[regexp {^R1 } $line] && [regexp {(^|\s)MID(\s|$)} $line]} { set haveR1 1 }
    if {[regexp {^R2 } $line] && [regexp {(^|\s)MID(\s|$)} $line]} { set haveR2 1 }
  }
}
check "RT3 R1 netlisted on net MID" $haveR1 {}
check "RT4 R2 netlisted on net MID" $haveR2 {}

# --- RT6 — the lib-qualified reference survives a netlist + re-save ----------
set schC [file join $tmp roundtrip3.sch]
xschem saveas $schC schematic
check "RT6 ref still lib-qualified after netlist" [regexp {C \{tlib/myres\}} [slurp $schC]] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
