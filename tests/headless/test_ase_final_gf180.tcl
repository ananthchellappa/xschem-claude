# ASE-L de-clutter proof for the gf180mcuD workarea (companion to the sky130
# tests/headless/test_ase_final.tcl). Drives the COMMITTED cell
# gf180mcuD/xschem_libs/gf180mcu_tests/test_nfet_final (schematic = circuit ONLY:
# nfet_03v3 M1 + symbolic Vds/Vgs sources + gnd + net labels; no models, no
# corner, no .control) plus its committed ngspice_state1 state view end-to-end
# through the PUBLIC ase:: API only:
#   state_load -> cell_views -> netlist -> render_deck hook -> run -> wait ->
#   last_result, expecting Id ~ 484.35 uA (|Id*1e6 - 484.35| < 1.0).
# Checks:
#   G1/G2  committed state file loads; version/simulator/design as committed
#   G3     round-trip byte-stability (committed file is state_save-canonical)
#   G4     ngspice_state1 + schematic enumerated by cell_views
#   G5     de-clutter at source (the committed .sch carries no sim clutter)
#   G6     ase::netlist artifact + symbolic V1/V2 lines
#   G7     THE DE-CLUTTER PROOF: netlist artifact BEFORE any deck append has
#          no .control, no .lib, no .include, and ends at .end
#   G8     deck render expands $::180MCU_MODELS -> absolute paths for BOTH the
#          .include design.ngspice (global switches) and the .lib sm141064
#          typical, in that order, and carries .param Vgs/Vds + .options + .save
#   G9/G10 real ngspice run (guarded on auto_execok): exit 0, log data rows,
#          Id within 1 uA of 484.35 uA  <- the acceptance gate
#
# gf180 twist vs sky130: sm141064's `typical` section is NOT self-contained — it
# references design.ngspice's global switch .params (sw_stat_global, mc_skew,
# fnoicor, ...). The committed state carries design.ngspice in the `includes`
# schema field; render_deck emits it as a top-level `.include` ahead of the
# `.lib`. So the clean state runs headless with NO switch params leaking into
# the Design Variables (variables = Vgs/Vds only).
#
# The model var is resolved exactly like gf180mcuD/cadence_style_rc does:
# ::180MCU_MODELS -> <repo>/gf180mcuD/models; the STATE FILE stores the portable
# $::180MCU_MODELS/... form. Libraries come from a scratch library.defs pointing
# at the REAL committed trees.
#
# RUNS IN BOTH ARMS, with the SAME checks and the same verdict (issue 0698 --
# this suite used to pass headless and abort under X, and that asymmetry was
# carried in briefs as folklore instead of being fixed). Run from the repo ROOT:
#   headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final_gf180.tcl
#   display:   tests/headless/run_suites.sh test_ase_final_gf180
# Under X the design window is bound explicitly before the first ase::netlist
# (ase_design_window.tcl); headless, ase::netlist self-loads and that arm of the
# guard stays the thing under test. Nothing else differs between the two.

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
source [file join $here ase_design_window.tcl]  ;# ase_bind_design_window (issue 0698)
set scratch [test_scratch ase_final_gf180]

set cellroot  [file join $repo gf180mcuD xschem_libs gf180mcu_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]
set modelsdir [file join $repo gf180mcuD models]

# model resolution exactly as gf180mcuD/cadence_style_rc sets it
set ::180MCU_MODELS $modelsdir

# --- scratch registry pointing at the REAL committed trees ------------------
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE gf180mcu_tests [file join $repo gf180mcuD xschem_libs gf180mcu_tests]"
puts $f "DEFINE gf180mcu_pr [file join $repo gf180mcuD xschem_libs gf180mcu_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

if {[catch {

# --- G1/G2: the committed state file loads as committed ----------------------
set st [ase::state_load $statefile]
check "G1 state version is 1" [dict get $st version] 1
check "G1 state simulator is ngspice" [dict get $st simulator] ngspice
check "G2 state design is the schematic view" [dict get $st design] \
  {lib gf180mcu_tests cell test_nfet_final view schematic}

# --- G3: committed file is state_save-canonical (round-trip byte-identity) ---
ase::state_save [file join $scratch roundtrip.state] $st
set f [open $statefile rb];                           set a [read $f]; close $f
set f [open [file join $scratch roundtrip.state] rb]; set b [read $f]; close $f
check_true "G3 committed state file round-trips byte-identical" [expr {$a eq $b}]

# --- G4: the view is a first-class citizen of cell_views ---------------------
set views [xschem cell_views gf180mcu_tests test_nfet_final]
check_true "G4 cell_views lists ngspice_state1" \
  [expr {[lsearch -exact $views ngspice_state1] >= 0}]
check_true "G4 cell_views lists schematic" \
  [expr {[lsearch -exact $views schematic] >= 0}]

# --- G5: de-clutter at source (committed schematic bytes) --------------------
set f [open $schfile r]; set schtext [read $f]; close $f
check_true "G5 .sch has no simulator_commands" \
  [expr {![string match {*simulator_commands*} $schtext]}]
check_true "G5 .sch has no code_shown (models)" \
  [expr {![string match {*code_shown*} $schtext]}]
check_true "G5 .sch has no .control" [expr {![string match {*.control*} $schtext]}]
check_true "G5 .sch has no .lib" [expr {![string match {*.lib*} $schtext]}]

# --- G6: netlist through the public API (hermetic rundir) -------------------
set rundir [file normalize [file join $scratch run]]
dict set st rundir $rundir
# --- 0698: the design window must be BOUND before the first ase::netlist -----
# ase::netlist (src/ase.tcl:866-874) self-loads the design ONLY when no display
# exists; under X it refuses with "design ... is not the current schematic" and
# this suite fell into its UNEXPECTED ERROR catch-all with most of its checks
# never reached. The guard is CORRECT -- it must never clobber an open GUI
# window -- so the wrong side is the suite, which never opens the design window
# the guard's GUI arm documents (Session > Design Window).
#
# THE BIND BELONGS ABOVE THIS ROW; this row is its postcondition. It must also
# stay AFTER the scratch library.defs block: bound earlier, the symbol resolves
# against the ambient registry and the XM1 row below fails instead -- a failure
# that looks nothing like this one.
#
# The path is resolved through `xschem cellview_path`, the SAME accessor
# ase::netlist compares against, so the row and the guard cannot disagree about
# which file "the design" is. Headless the expectation is vacuously true, and
# deliberately so: there the guard's own self-load arm is what must stay
# exercised, and an unconditional bind would silently stop exercising it.
ase_bind_design_window $st
set _d698 [dict get $st design]
set _v698 schematic
if {[dict exists $_d698 view] && [dict get $_d698 view] ne {}} { set _v698 [dict get $_d698 view] }
set _p698 [file normalize [xschem cellview_path \
             [dict get $_d698 lib]/[dict get $_d698 cell] $_v698]]
set _c698 [file normalize [xschem get schname]]
if {![info exists ::has_x] || $_c698 eq $_p698} {
  set _b698 bound
} else {
  set _b698 "UNBOUND (current=[file tail $_c698])"
}
check "G6 design window bound before the first netlist (0698)" $_b698 bound

set nl [ase::netlist $st]
check "G6 netlist path" $nl [file join $rundir test_nfet_final.spice]
check_true "G6 netlist file exists" [file isfile $nl]
set f [open $nl r]; set nltext [read $f]; close $f
check_true "G6 netlist contains XM1" [string match {*XM1*} $nltext]
check_true "G6 symbolic V1 ... Vds line" [regexp -line {^V1\s+\S+\s+\S+\s+Vds\s*$} $nltext]
check_true "G6 symbolic V2 ... Vgs line" [regexp -line {^V2\s+\S+\s+\S+\s+Vgs\s*$} $nltext]

# --- G7: THE DE-CLUTTER PROOF (netlist artifact BEFORE any deck append) ------
check_true "G7 netlist has no .control line" \
  [expr {![regexp -line {^\.control} $nltext]}]
check_true "G7 netlist has no .lib line" [expr {![regexp -line {^\.lib } $nltext]}]
check_true "G7 netlist has no .include line" \
  [expr {![regexp -line {^\.include } $nltext]}]
check "G7 last non-blank netlist line is .end" \
  [string trim [lindex [split [string trimright $nltext "\n"] "\n"] end]] {.end}

# --- G8: deck render (public hook) expands BOTH model refs, include-before-lib
set render [ase::backend_hook ngspice render_deck]
set deck [$render $st $nltext]
check_true "G8 deck .include has EXPANDED design.ngspice path" \
  [string match "*.include [file join $modelsdir design.ngspice]*" $deck]
check_true "G8 deck .lib has EXPANDED sm141064 path + typical" \
  [string match "*.lib [file join $modelsdir sm141064.ngspice] typical*" $deck]
check_true "G8 deck has no raw \$::180MCU_MODELS" \
  [expr {![string match {*180MCU_MODELS*} $deck]}]
set iidx [string first ".include " $deck]
set lidx [string first ".lib "     $deck]
check_true "G8 .include emitted before .lib" [expr {$iidx >= 0 && $lidx > $iidx}]
check_true "G8 deck .param Vgs=3.3" [regexp -line {^\.param Vgs=3\.3$} $deck]
check_true "G8 deck .param Vds=1.65" [regexp -line {^\.param Vds=1\.65$} $deck]
check_true "G8 clean vars: no switch .param (fnoicor absent from vars)" \
  [expr {![regexp -line {^\.param fnoicor} $deck]}]
check_true "G8 deck .options savecurrents" \
  [regexp -line {^\.options savecurrents$} $deck]
check_true "G8 deck .save -i(v1)" [string match {*.save -i(v1)*} $deck]
set cidx [string first "\n.control\n" $deck]
set oidx [string first "\nop\n" $deck]
set eidx [string first "\n.endc\n" $deck]
check_true "G8 op line inside the .control block" \
  [expr {$cidx >= 0 && $oidx > $cidx && $eidx > $oidx}]

# --- G9/G10: real ngspice run — THE ACCEPTANCE GATE (guarded) ----------------
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: G9/G10 run leg (ngspice not found)"
} else {
  set id [ase::run $st]
  set ec [ase::wait $id]
  check "G9 ngspice exit code 0" $ec 0
  check_true "G9 ase deck file written" \
    [file isfile [file join $rundir test_nfet_final_ase.spice]]
  set logf [file join $rundir test_nfet_final_ase.log]
  set logtext {}
  if {[file isfile $logf]} { set f [open $logf r]; set logtext [read $f]; close $f }
  check_true "G9 log file written with data rows" \
    [expr {[file isfile $logf] && [string match {*No. of Data Rows*} $logtext]}]
  set res [ase::last_result]
  set idok 0
  if {[dict exists $res id]} {
    set v [dict get $res id]
    if {abs($v * 1e6 - 484.35) < 1.0} { set idok 1 }
  }
  check_true "G10 Id within 1 uA of 484.35 uA (expect 4.843529e-04)" $idok
  if {!$idok} { puts "  G10 last_result: $res" }
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
