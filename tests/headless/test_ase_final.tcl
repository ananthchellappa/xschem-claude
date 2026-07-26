# ASE-L de-clutter proof (P4 of doc/claude/specs/ase_l.md) — the batch
# acceptance gate. Drives the COMMITTED cell
# sky130A/xschem_libs/sky130_tests/test_nfet_final (schematic = circuit ONLY:
# M1 + symbolic Vds/Vgs sources + gnd + net labels; no corner, no
# simulator_commands, no .control) plus its committed ngspice_state1 state
# view end-to-end through the PUBLIC ase:: API only:
#   state_load -> cell_views -> netlist -> render_deck hook -> run -> wait ->
#   last_result, expecting Id ~ 409.68 uA (|Id*1e6 - 409.68| < 1.0).
# Checks:
#   F1/F2  committed state file loads; version/simulator/design as committed
#   F3     round-trip byte-stability (committed file is state_save-canonical)
#   F4     ngspice_state1 + schematic enumerated by cell_views
#   F5     de-clutter at source (the committed .sch carries no sim clutter)
#   F6     ase::netlist artifact + symbolic V1/V2 lines
#   F7     THE DE-CLUTTER PROOF: netlist artifact BEFORE any deck append has
#          no .control, no .lib, and ends at .end
#   F8     deck render expands $::SKYWATER_MODELS -> absolute model path, and
#          carries .param/.options/.save/.control op
#   F9/F10 real ngspice run (guarded on auto_execok): exit 0, log data rows,
#          Id within 1 uA of 409.68 uA  <- the acceptance gate
#
# The model path is resolved exactly like sky130A/cadence_style_rc does:
# the test sets ::SKYWATER_MODELS to <repo>/sky130A/models/libs.tech/combined
# and the STATE FILE stores the portable $::SKYWATER_MODELS/... form.
# Libraries come from a scratch library.defs pointing at the REAL committed
# trees (never the pre-batch-dirty workarea library.defs). The only state
# mutation is the rundir override into the scratch dir (hermetic run
# location through the public schema — no sim content is added anywhere).
#
# True headless (no X). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch ase_final]

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]
set modelsdir [file join $repo sky130A models libs.tech combined]

# model resolution exactly as sky130A/cadence_style_rc sets it (decision D2)
set ::SKYWATER_MODELS $modelsdir

# --- scratch registry pointing at the REAL committed trees (decision D3) -----
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

if {[catch {

# --- F1/F2: the committed state file loads as committed ----------------------
set st [ase::state_load $statefile]
check "F1 state version is 1" [dict get $st version] 1
check "F1 state simulator is ngspice" [dict get $st simulator] ngspice
check "F2 state design is the schematic view" [dict get $st design] \
  {lib sky130_tests cell test_nfet_final view schematic}

# --- F3: committed file is state_save-canonical (round-trip byte-identity) ---
ase::state_save [file join $scratch roundtrip.state] $st
set f [open $statefile rb];                       set a [read $f]; close $f
set f [open [file join $scratch roundtrip.state] rb]; set b [read $f]; close $f
check_true "F3 committed state file round-trips byte-identical" [expr {$a eq $b}]

# --- F4: the view is a first-class citizen of cell_views ---------------------
set views [xschem cell_views sky130_tests test_nfet_final]
check_true "F4 cell_views lists ngspice_state1" \
  [expr {[lsearch -exact $views ngspice_state1] >= 0}]
check_true "F4 cell_views lists schematic" \
  [expr {[lsearch -exact $views schematic] >= 0}]

# --- F5: de-clutter at source (committed schematic bytes) --------------------
set f [open $schfile r]; set schtext [read $f]; close $f
check_true "F5 .sch has no simulator_commands" \
  [expr {![string match {*simulator_commands*} $schtext]}]
check_true "F5 .sch has no corner" [expr {![string match {*corner*} $schtext]}]
check_true "F5 .sch has no .control" [expr {![string match {*.control*} $schtext]}]

# --- F6: netlist through the public API (hermetic rundir, decision D7) -------
set rundir [file normalize [file join $scratch run]]
dict set st rundir $rundir
set nl [ase::netlist $st]
check "F6 netlist path" $nl [file join $rundir test_nfet_final.spice]
check_true "F6 netlist file exists" [file isfile $nl]
set f [open $nl r]; set nltext [read $f]; close $f
check_true "F6 netlist contains XM1" [string match {*XM1*} $nltext]
check_true "F6 symbolic V1 D GND Vds line" \
  [regexp -line {^V1\s+D\s+GND\s+Vds\s*$} $nltext]
check_true "F6 symbolic V2 G GND Vgs line" \
  [regexp -line {^V2\s+G\s+GND\s+Vgs\s*$} $nltext]

# --- F7: THE DE-CLUTTER PROOF (netlist artifact BEFORE any deck append) ------
check_true "F7 netlist has no .control line" \
  [expr {![regexp -line {^\.control} $nltext]}]
check_true "F7 netlist has no .lib line" [expr {![regexp -line {^\.lib } $nltext]}]
check "F7 last non-blank netlist line is .end" \
  [string trim [lindex [split [string trimright $nltext "\n"] "\n"] end]] {.end}

# --- F8: deck render (public hook) expands the model path + carries the state
set render [ase::backend_hook ngspice render_deck]
set deck [$render $st $nltext]
check_true "F8 deck .lib has the EXPANDED absolute model path + tt" \
  [string match "*.lib [file join $modelsdir sky130.lib.spice] tt*" $deck]
check_true "F8 deck has no raw \$::SKYWATER_MODELS" \
  [expr {![string match {*$::SKYWATER_MODELS*} $deck]}]
check_true "F8 deck .param Vgs=1.8" [regexp -line {^\.param Vgs=1\.8$} $deck]
check_true "F8 deck .param Vds=1.0" [regexp -line {^\.param Vds=1\.0$} $deck]
check_true "F8 deck .options savecurrents" \
  [regexp -line {^\.options savecurrents$} $deck]
check_true "F8 deck .save -i(v1)" [string match {*.save -i(v1)*} $deck]
set cidx [string first "\n.control\n" $deck]
set oidx [string first "\nop\n" $deck]
set eidx [string first "\n.endc\n" $deck]
check_true "F8 op line inside the .control block" \
  [expr {$cidx >= 0 && $oidx > $cidx && $eidx > $oidx}]

# --- F9/F10: real ngspice run — THE ACCEPTANCE GATE (guarded) ----------------
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: F9/F10 run leg (ngspice not found)"
} else {
  set id [ase::run $st]
  set ec [ase::wait $id]
  check "F9 ngspice exit code 0" $ec 0
  check_true "F9 ase deck file written" \
    [file isfile [file join $rundir test_nfet_final_ase.spice]]
  set logf [file join $rundir test_nfet_final_ase.log]
  set logtext {}
  if {[file isfile $logf]} { set f [open $logf r]; set logtext [read $f]; close $f }
  check_true "F9 log file written with data rows" \
    [expr {[file isfile $logf] && [string match {*No. of Data Rows*} $logtext]}]
  set res [ase::last_result]
  set idok 0
  if {[dict exists $res id]} {
    set v [dict get $res id]
    if {abs($v * 1e6 - 409.68) < 1.0} { set idok 1 }
  }
  check_true "F10 Id within 1 uA of 409.68 uA (expect 4.096837e-04)" $idok
  if {!$idok} { puts "  F10 last_result: $res" }
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
