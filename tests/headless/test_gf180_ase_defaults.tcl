# A fresh Tools > Launch ASE-L session must preload the FULL gf180 typical corner
# (all device-class .lib sections + design.ngspice) so any gf180mcu_pr device
# netlists + simulates without "unknown subckt".
#   Part A: the generic ASE_DEFAULT_MODELS/ASE_DEFAULT_INCLUDES -> state_default
#           -> render_deck plumbing (includes emitted BEFORE .lib models).
#   Part B: gf180mcuD/cadence_style_rc actually seeds all six sections + include.
#   run:  ./src/xschem --pipe -q --nolog --script tests/headless/test_gf180_ase_defaults.tcl
set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp})"; incr fail }
}
proc check_true {name c} { check $name [expr {$c ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]

# --- Part A: generic seed plumbing ------------------------------------------
set ::ASE_DEFAULT_MODELS   [list [list file {$::M/a.ngspice} section typical] \
                                 [list file {$::M/a.ngspice} section res_typical]]
set ::ASE_DEFAULT_INCLUDES [list [list file {$::M/design.ngspice}]]
set ::M [file join $repo gf180mcuD models]   ;# so expand_path resolves
set st [ase::state_default]
check "state_default models from ASE_DEFAULT_MODELS"     [llength [dict get $st models]] 2
check "state_default includes from ASE_DEFAULT_INCLUDES" [llength [dict get $st includes]] 1
dict set st design {lib gf180mcu_tests cell test_nfet_TRAN view schematic}
set deck [ase::backend::ngspice::render_deck $st "* dummy\n.end"]
check_true "deck has the .include"          [expr {[string first {design.ngspice} $deck] >= 0}]
check_true "deck has the res_typical .lib"  [expr {[string first {res_typical} $deck] >= 0}]
check_true "deck emits .include BEFORE .lib" \
  [expr {[string first ".include" $deck] < [string first ".lib" $deck]}]

# --- Part B: the gf180 rc seeds the full typical corner ----------------------
set rc [read [set fp [open [file join $repo gf180mcuD cadence_style_rc] r]]][close $fp]
foreach sec {typical res_typical mimcap_typical moscap_typical bjt_typical diode_typical} {
  check_true "gf180 rc seeds section $sec" \
    [expr {[regexp "section $sec\\y" $rc]}]
}
check_true "gf180 rc sets ASE_DEFAULT_INCLUDES design.ngspice" \
  [expr {[regexp {ASE_DEFAULT_INCLUDES} $rc] && [regexp {design\.ngspice} $rc]}]
# every section name the rc references must actually exist in sm141064.ngspice
set mdl [read [set fp [open [file join $repo gf180mcuD models sm141064.ngspice] r]]][close $fp]
foreach sec {typical res_typical mimcap_typical moscap_typical bjt_typical diode_typical} {
  check_true "sm141064.ngspice defines .lib $sec" [expr {[regexp "\n\\.lib $sec\\y" "\n$mdl"]}]
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
