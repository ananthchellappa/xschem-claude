# Phase 6 (library-manager) — pilot migration of the repo's own libraries.
# The flat xschem_library/ is kept untouched; a sibling xschem_library_oa/ holds
# the migrated devices + examples in lib/cell/view layout plus a library.defs.
# This proves the migrated tree is (a) structurally present and (b) SEMANTICALLY
# equivalent: each migrated example netlists to the same set of spice statements
# as its flat original (path/comment lines excluded).
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_pilot_migration.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }

set repo [file normalize [file join [pwd] ..]]
set OA   [file join $repo xschem_library_oa]
set FLAT [file join $repo xschem_library]

# spice body = non-comment, non-blank lines, sorted (drops ** path markers,
# * expanding..., **.subckt/**.ends wrappers; keeps real device/.subckt lines)
proc body {text} {
  set out {}
  foreach ln [split $text \n] {
    set t [string trim $ln]
    if {$t eq "" || [string index $t 0] eq "*"} continue
    lappend out $t
  }
  return [lsort $out]
}
proc netlist_body {schfile defs outdir} {
  file delete -force $outdir; file mkdir $outdir
  set ::XSCHEM_LIBRARY_DEFS $defs
  set ::netlist_dir $outdir
  xschem set netlist_type spice
  if {[catch {xschem load $schfile}]} { return "<loadfail>" }
  xschem netlist
  set sp [file join $outdir [file rootname [file tail $schfile]].spice]
  if {![file exists $sp]} { return "<nonetlist>" }
  return [body [slurp $sp]]
}

# --- P1 — the migrated tree is structurally present -------------------------
check "P1a devices symbol in view dir"  [file isfile [file join $OA devices/res/symbol/res.sym]] {}
check "P1b example schematic in view dir" [file isfile [file join $OA examples/cmos_inv/schematic/cmos_inv.sch]] {}
check "P1c example symbol in view dir"  [file isfile [file join $OA examples/cmos_inv/symbol/cmos_inv.sym]] {}
check "P1d flat tree untouched"         [file isfile [file join $FLAT devices/res.sym]] {}

# --- P2 — library.defs registry present with both libs ----------------------
set defs [file join $OA library.defs]
set defsok [expr {[file isfile $defs] && [regexp {DEFINE devices } [slurp $defs]] && [regexp {DEFINE examples } [slurp $defs]]}]
check "P2 library.defs has devices+examples" $defsok {}

# --- P3 — migrated refs are lib-qualified -----------------------------------
if {[file isfile [file join $OA examples/cmos_inv/schematic/cmos_inv.sch]]} {
  set c [slurp [file join $OA examples/cmos_inv/schematic/cmos_inv.sch]]
  check "P3 cmos_inv refs lib-qualified" \
    [expr {[regexp {C \{devices/nmos4\}} $c] && ![regexp {C \{nmos4\.sym\}} $c]}] {}
} else { check "P3 cmos_inv refs lib-qualified" 0 "(missing migrated file)" }

# --- P4 — each migrated example netlists identically to its flat original ----
set tmp [file join [pwd] _pilot_[pid]]
foreach ex {cmos_inv nand2 dlatch flop} {
  set flat_sch [file join $FLAT examples $ex.sch]
  set mig_sch  [file join $OA examples $ex schematic $ex.sch]
  if {![file isfile $flat_sch]} { check "P4 $ex equivalence" 0 "(no flat original)"; continue }
  if {![file isfile $mig_sch]}  { check "P4 $ex equivalence" 0 "(no migrated file)"; continue }
  set fb [netlist_body $flat_sch ""   [file join $tmp flat $ex]]
  set mb [netlist_body $mig_sch  $defs [file join $tmp mig  $ex]]
  check "P4 $ex netlist equivalence" [expr {$fb eq $mb && [llength $fb] > 0}] \
    "(flat=[llength $fb] lines, mig=[llength $mb] lines)"
}
file delete -force $tmp

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
