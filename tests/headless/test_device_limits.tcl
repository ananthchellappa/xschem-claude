# tests/headless/test_device_limits.tcl -- a property edit that takes a MOSFET's W or L
# past its PDK limit is corrected to the limit, with a CIW warning.
#
# The user's request, 2026-11-12: "if user edits a property and sets a value below
# minimum, Xschem should print a warning in CIW and change the value to the minimum.
# Same for maximum". apply_symbol_prop (src/editprop.c) calls devlim::clamp_edit
# (src/property_form.tcl) with the limits each bundled workarea registers:
# sg13g2_fet_limits, sky130_fet_limits, gf180_fet_limits.
#   DL1  IHP: w below its minimum is set to it; the message says so
#   DL2  IHP: l above its maximum is set to it
#   DL3  the limit is per finger: w/ng below the minimum sets w to minimum x ng
#   DL4  a token the edit did not change is left alone, even out of range
#   DL5  a value that is not a plain number (a parameter) is left alone
#   DL6  SI suffixes and bare metres are read in IHP units
#   DL7  sky130: bare microns, W and L both corrected in one edit
#   DL8  gf180: L corrected; the native cell is keyed on its cell, not its model
#   DL9  the correction is part of the edit's undo step: one undo restores the start
#   DL10 a value inside the limits is not touched and says nothing
#   DL11 the PDK's own drc= check runs again (it was gated on a proc nobody defines)
#   DL12 sky130_fet_drc takes an *_nf symbol's W as per finger whether or not its name
#        ends in .sym (registry workareas name it lib/cell), and still divides others
# Run: tests/headless/run_suites.sh --nogui test_device_limits

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set repo [file normalize [file join $here .. ..]]

foreach f {ihp-sg13g2/sg13g2_procs.tcl sky130A/sky130_procs.tcl gf180mcuD/gf180_procs.tcl} {
  if {[catch {uplevel #0 [list source [file join $repo $f]]} e]} { puts "note: sourcing $f: $e" }
}
check {DL0 all three workareas register a limits provider} \
  [lsort $::devlim::providers] [lsort {sg13g2_fet_limits sky130_fet_limits gf180_fet_limits}]

proc symf {pdk lib cell} {
  global repo
  return [file join $repo $pdk xschem_libs $lib $cell symbol $cell.sym]
}
set IHP_N  [symf ihp-sg13g2 sg13g2_pr sg13_lv_nmos]
set SKY_N  [symf sky130A sky130_fd_pr nfet_01v8]
set GF_N   [symf gf180mcuD gf180mcu_pr nfet_03v3]
set GF_NVT [symf gf180mcuD gf180mcu_pr nfet_06v0_nvt]

# Place one instance and edit it as the form does: `xschem apply_properties` with the
# form's before/after strings. Answers the instance's property string afterwards.
proc place {sym props} {
  xschem clear force schematic
  xschem instance $sym 0 0 0 0 $props
  return 0
}
proc edit {i old new} {
  set ::symbol [xschem getprop instance $i cell::name]
  set id [xschem instance_id [xschem getprop instance $i name]]
  set ::devlim::last {}
  xschem apply_properties current $id $new $old 1
  return [xschem getprop instance $i]
}
proc tok {i t} { xschem getprop instance $i $t }

set P0 {name=M1 l=0.13u w=1u ng=1 m=1 model=sg13_lv_nmos spiceprefix=X}

# DL1
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 w 0.05u]
check {DL1 IHP w below the minimum is set to 0.13u, and the CIW line says so} \
  [list [tok 0 w] [llength $::devlim::last] \
        [string match {M1 (sg13_lv_nmos): w=0.05u is below the minimum 0.13u; w set to 0.13u} \
           [lindex $::devlim::last 0]]] \
  {0.13u 1 1}

# DL2
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 l 20u]
check {DL2 IHP l above the maximum is set to 10u} \
  [list [tok 0 l] [string match {*above the maximum 10u*} [lindex $::devlim::last 0]]] {10u 1}

# DL3
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok [xschem subst_tok $P0 w 0.2u] ng 2]
check {DL3 the limit is per finger: w=0.2u over ng=2 is set to 0.26u} \
  [list [tok 0 w] [tok 0 ng] [string match {*w/ng=0.1u*per finger*} [lindex $::devlim::last 0]]] \
  {0.26u 2 1}

# DL4
set Pbad [xschem subst_tok $P0 l 0.05u]
place $IHP_N $Pbad
edit 0 $Pbad [xschem subst_tok $Pbad w 2u]
check {DL4 a token the edit did not change keeps its old out-of-range value} \
  [list [tok 0 w] [tok 0 l] [llength $::devlim::last]] {2u 0.05u 0}

# DL5
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 w {wp}]
check {DL5 a parameter is not a number and is left alone} [list [tok 0 w] $::devlim::last] {wp {}}

# DL6
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 w 50n]
set a [tok 0 w]
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 w 2e-8]
check {DL6 50n and bare metres 2e-8 are both read as below 0.13u} [list $a [tok 0 w]] {0.13u 0.13u}

# DL7
set S0 {name=M1 W=1 L=0.15 nf=1 mult=1 model=nfet_01v8 spiceprefix=X}
place $SKY_N $S0
edit 0 $S0 [xschem subst_tok [xschem subst_tok $S0 W 0.2] L 25]
check {DL7 sky130 bare microns: W=0.2 -> 0.42 and L=25 -> 20.2, two CIW lines} \
  [list [tok 0 W] [tok 0 L] [llength $::devlim::last]] {0.42 20.2 2}

# DL8
set G0 {name=M1 L=0.28u W=0.22u nf=1 m=1 model=nfet_03v3 spiceprefix=X}
place $GF_N $G0
edit 0 $G0 [xschem subst_tok $G0 L 0.1u]
set a [tok 0 L]
set G1 {name=M1 L=1.80u W=0.80u nf=1 m=1 model=nfet_06v0 spiceprefix=X}
place $GF_NVT $G1
edit 0 $G1 [xschem subst_tok $G1 L 1u]
check {DL8 gf180: nfet_03v3 L=0.1u -> 0.28u; the native cell (model nfet_06v0) L=1u -> 1.8u} \
  [list $a [tok 0 L]] {0.28u 1.8u}

# DL9
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 w 0.05u]
set after [tok 0 w]
xschem undo
check {DL9 the correction rides the edit's undo step: one undo restores w=1u} \
  [list $after [tok 0 w]] {0.13u 1u}

# DL10
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 w 5u]
check {DL10 a value inside the limits is kept and says nothing} [list [tok 0 w] $::devlim::last] {5u {}}

# DL11
place $IHP_N [xschem subst_tok $P0 l 0.05u]
set r [xschem drc_check 0]
place $IHP_N $P0
check {DL11 the PDK drc= check runs: it reports l=0.05u, and nothing on a clean instance} \
  [list $r [xschem drc_check 0]] {1 0}

# DL12 -- the reported false warning: test_nmos M9, nfet_01v8_lvt_nf W=0.5 nf=2.
check {DL12 sky130_fet_drc: an _nf symbol's W=0.5 nf=2 is legal by either name; a plain one at 0.25/finger is not} \
  [list [sky130_fet_drc M9 sky130_fd_pr/nfet_01v8_lvt_nf nfet_01v8_lvt 0.5 0.15 2] \
        [sky130_fet_drc M9 nfet_01v8_lvt_nf.sym nfet_01v8_lvt 0.5 0.15 2] \
        [string match {*finger width is too small*} \
           [sky130_fet_drc M9 sky130_fd_pr/nfet_01v8_lvt nfet_01v8_lvt 0.5 0.15 2]]] \
  {{} {} 1}

xschem clear force schematic
set floor 13
if {$npass + $fail < $floor} {
  puts "FAIL: DLFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
