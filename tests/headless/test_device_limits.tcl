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
#   DL13 apply reaches the rule through devlim::corrections: a trace on it fires once
#        for the edit, handed the edit's before/after strings
#   DL14 a finger count changed alone re-checks w per finger
#   DL15 IHP rsil/rppd: w and l below 0.5u are set to it (sg13g2_res_drc's minimum)
#   DL16 IHP rhigh: l below 0.96u is set to it, w below 0.5u to 0.5u
#   DL17 IHP cap_cmim: w below 1.14u is set to it; l alone has no limit (the area
#        rule spans w and l) and is left as typed
#   DL18 IHP cap_rfcmim: w, l kept to 7u..75u and wfeed to 1u..30u (the model note)
#   DL19 gf180 3.3 V _dss: L and W below 0.28u / 0.22u are set to them
#   DL20 gf180 6 V _dss: W below 0.3u is set to it, L above 50u to 50u, and L below
#        every candidate minimum is left as typed (owed rule gf180-dss-lmin)
#   DL21 sky130 and gf180 resistors and capacitors, and IHP sg13_svaricap, have no
#        limit in this tree: a tiny W/L is left as typed and says nothing
#
# A scripted edit is clamped too: `xschem setprop instance <i> <tok> <val>` (scheduler.c)
# calls devlim_clamp (src/editprop.c), the hook apply_symbol_prop uses.
#   SP1  setprop w below the minimum: set to the minimum, with apply's CIW sentence
#   SP2  the correction rides setprop's undo step: one undo restores the start
#   SP3  -fast and -fastundo are clamped the same way
#   SP4  setprop of another token leaves an old out-of-range w/l alone
#   SP5  setprop allprops with an out-of-range w is clamped
#   SP6  setprop of a parameter is left alone and says nothing
#   SP7  setprop of a finger count alone re-checks w per finger
#
# The instance form corrects a value when its field loses focus. The user's request,
# 2026-11-12: "If user enters a value and hits Tab to move to another field, it's as
# good as entering a value and the form needs to take appropriate action and apply
# the clamp." slickprop::limits_check runs devlim::corrections, the rule apply uses,
# over the form's current values whenever a text field loses focus. The FL rows drive
# the REAL form (`xschem edit_prop` on a selected instance), type with `entry
# delete/insert`, leave a field as the Tab key's own `all` binding does
# (tk::TabToWindow [tk_focusNext ...], which moves the focus and so delivers a real
# <FocusOut>), and record ciw_echo instead of reading a live CIW.
#   FL0  non-vacuity: that Tab move delivers one real <FocusOut> to the field left
#   FL1  sky130: L=0 typed and tabbed out of shows the minimum in L's field, with one
#        CIW warning line, the sentence apply says; the sheet is untouched
#   FL2  then OK: the instance's L is the minimum, OK says no line of its own (no
#        second warning), and one undo restores the start
#   FL3  IHP: ng=10 typed at w=1u and tabbed out of corrects w's field per finger
#   FL4  sky130: a parameter typed into W is left as typed, with no line
#   FL5  IHP: a legal value is left as typed, with no line
#   FL6  IHP: a corrected field left by Tab, re-entered by Shift-Tab and left again
#        says one line, not two
#   FL7  read-only sheet: the same correction and line in the form, OK/Apply still
#        disabled, Apply and closing leave the instance and the sheet as they were
#   FL8  control, the OK path unchanged: a value typed and OK pressed with no focus
#        move says apply's line once
#   FL9  one rule: a trace on devlim::corrections fires on FL1's focus-out and on
#        FL2's OK, once each
#   FL10 the declared limit with several instances in scope: the focus-out check
#        reads the displayed instance only, and OK still clamps each instance
#   FL11 the focus moved straight to another field, as a click on it does (no Tab
#        traversal event), corrects the field left the same way
# Without Tk (the headless arm) the FL band prints one `skip:` line naming its rows;
# the display arm (the dcases entry) runs them.
# Run: tests/headless/run_suites.sh --nogui test_device_limits   (DL rows)
#      tests/headless/run_suites.sh test_device_limits           (DL and FL rows)

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
  [lsort $::devlim::providers] \
  [lsort {sg13g2_fet_limits sg13g2_rescap_limits sky130_fet_limits gf180_fet_limits}]

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

# DL13 -- the rule lives once: apply's clamp must reach it through the same proc the
# form's focus-out check calls (FL9 is the form's half). A tree without the proc
# leaves the trace unset and the count at 0.
set ::dl_calls {}
proc dl_trace {cmd op} { lappend ::dl_calls [lrange $cmd 1 end] }
set dl_traced [expr {[info commands ::devlim::corrections] ne {}}]
if {$dl_traced} { trace add execution ::devlim::corrections enter dl_trace }
place $IHP_N $P0
set new13 [xschem subst_tok $P0 w 0.05u]
edit 0 $P0 $new13
if {$dl_traced} { trace remove execution ::devlim::corrections enter dl_trace }
check {DL13 apply reaches the rule through devlim::corrections: a trace on it fires once for the edit, with its before/after strings} \
  [list [llength $::dl_calls] [lindex $::dl_calls 0 3] [lindex $::dl_calls 0 4] [tok 0 w]] \
  [list 1 $P0 $new13 0.13u]

# DL14
place $IHP_N $P0
edit 0 $P0 [xschem subst_tok $P0 ng 10]
check {DL14 a finger count changed alone re-checks w per finger: ng=10 at w=1u sets w to 1.3u} \
  [list [tok 0 w] [tok 0 ng] [lindex $::devlim::last 0]] \
  [list 1.3u 10 {M1 (sg13_lv_nmos): w/ng=0.1u is below the minimum 0.13u per finger; w set to 1.3u}]

# DL15..DL21 -- resistors and capacitors, and the gf180 drain-SAB devices. Each row
# edits through apply (edit), as DL1..DL14 do.
proc edit_tok {i props args} {
  set new $props
  foreach {t v} $args { set new [xschem subst_tok $new $t $v] }
  edit $i $props $new
  return [llength $::devlim::last]
}
set IHP_RSIL  [symf ihp-sg13g2 sg13g2_pr rsil]
set IHP_RPPD  [symf ihp-sg13g2 sg13g2_pr rppd]
set IHP_RHIGH [symf ihp-sg13g2 sg13g2_pr rhigh]
set IHP_CMIM  [symf ihp-sg13g2 sg13g2_pr cap_cmim]
set IHP_RFC   [symf ihp-sg13g2 sg13g2_pr cap_rfcmim]
set IHP_SVAR  [symf ihp-sg13g2 sg13g2_pr sg13_svaricap]

set R0 {name=R1 w=0.5e-6 l=0.5e-6 model=rsil body=sub! spiceprefix=X b=0 m=1}
place $IHP_RSIL $R0
set n [edit_tok 0 $R0 w 0.2e-6 l 0.1u]
set a [list [tok 0 w] [tok 0 l] $n [lindex $::devlim::last 0]]
set R1 [xschem subst_tok $R0 model rppd]
place $IHP_RPPD $R1
edit_tok 0 $R1 w 0.3u l 0.2u
check {DL15 IHP rsil w=0.2e-6 l=0.1u -> 0.5u 0.5u with two lines; rppd w=0.3u l=0.2u -> 0.5u 0.5u} \
  [list {*}$a [tok 0 w] [tok 0 l]] \
  [list 0.5u 0.5u 2 {R1 (rsil): w=0.2e-6 is below the minimum 0.5u; w set to 0.5u} 0.5u 0.5u]

set R2 {name=R1 w=0.5e-6 l=0.96e-6 model=rhigh body=sub! spiceprefix=X b=0 m=1}
place $IHP_RHIGH $R2
edit_tok 0 $R2 w 0.4u l 0.6u
check {DL16 IHP rhigh w=0.4u l=0.6u -> 0.5u 0.96u} [list [tok 0 w] [tok 0 l]] {0.5u 0.96u}

set C0 {name=C1 model=cap_cmim w=7.0e-6 l=7.0e-6 m=1 spiceprefix=X}
place $IHP_CMIM $C0
set n [edit_tok 0 $C0 w 1u l 0.5u]
check {DL17 IHP cap_cmim w=1u -> 1.14u; l=0.5u alone is not limited and stays, one line} \
  [list [tok 0 w] [tok 0 l] $n] {1.14u 0.5u 1}

set C1 {name=C1 model=cap_rfcmim lvs_model=rfcmim w=10.0e-6 l=10.0e-6 wfeed=5.0e-6 spiceprefix=X}
place $IHP_RFC $C1
set n [edit_tok 0 $C1 w 100u l 5u wfeed 0.5u]
set a [list [tok 0 w] [tok 0 l] [tok 0 wfeed] $n]
place $IHP_RFC $C1
edit_tok 0 $C1 wfeed 40u l 80u w 5u
check {DL18 IHP cap_rfcmim w=100u l=5u wfeed=0.5u -> 75u 7u 1u with three lines; wfeed=40u l=80u w=5u -> 30u 75u 7u} \
  [list {*}$a [tok 0 wfeed] [tok 0 l] [tok 0 w]] {75u 7u 1u 3 30u 75u 7u}

set GF_N3D [symf gf180mcuD gf180mcu_pr nfet_03v3_dss]
set GF_P3D [symf gf180mcuD gf180mcu_pr pfet_03v3_dss]
set GF_N6D [symf gf180mcuD gf180mcu_pr nfet_06v0_dss]
set GF_P6D [symf gf180mcuD gf180mcu_pr pfet_06v0_dss]
set D3 {name=M1 L=0.28u W=0.22u nf=1 m=1 model=nfet_03v3_dss spiceprefix=X}
place $GF_N3D $D3
edit_tok 0 $D3 L 0.1u W 0.1u
set a [list [tok 0 L] [tok 0 W]]
set D3p [xschem subst_tok $D3 model pfet_03v3_dss]
place $GF_P3D $D3p
edit_tok 0 $D3p L 0.1u W 0.1u
check {DL19 gf180 nfet_03v3_dss and pfet_03v3_dss each: L=0.1u W=0.1u -> 0.28u 0.22u} \
  [list {*}$a [tok 0 L] [tok 0 W]] {0.28u 0.22u 0.28u 0.22u}

set D6 {name=M1 L=0.70u W=0.30u nf=1 m=1 model=nfet_06v0_dss spiceprefix=X}
place $GF_N6D $D6
set n [edit_tok 0 $D6 L 0.3u W 0.1u]
set a [list [tok 0 L] [tok 0 W] $n]
set D6p {name=M1 L=0.50u W=0.30u nf=1 m=1 model=pfet_06v0_dss spiceprefix=X}
place $GF_P6D $D6p
set n [edit_tok 0 $D6p L 0.3u]
lappend a [tok 0 L] $n
place $GF_P6D $D6p
edit_tok 0 $D6p L 60u
check {DL20 gf180 6 V _dss: nfet L=0.3u stays and W=0.1u -> 0.3u (one line); pfet L=0.3u stays silent; L=60u -> 50u} \
  [list {*}$a [tok 0 L]] {0.3u 0.3u 1 0.3u 0 50u}

set got {}
foreach {pdk lib cell props toks} [list \
    sky130A sky130_fd_pr res_high_po {name=R1 W=1 L=1 model=res_high_po spiceprefix=X mult=1} {W 0.01 L 0.01} \
    sky130A sky130_fd_pr cap_mim_m3_1 {name=C1 model=cap_mim_m3_1 W=1 L=1 MF=1 spiceprefix=X} {W 0.01 L 0.01} \
    gf180mcuD gf180mcu_pr ppolyf_u_1k {name=R1 W=1e-6 L=1e-6 model=ppolyf_u_1k spiceprefix=X m=1} {W 1e-9 L 1e-9} \
    gf180mcuD gf180mcu_pr cap_mim_2f0fF {name=C1 W=1e-6 L=1e-6 model=cap_mim_2f0fF spiceprefix=X m=1} {W 1e-9 L 1e-9} \
    ihp-sg13g2 sg13g2_pr sg13_svaricap {name=C1 model=sg13_hv_svaricap w=3.74u l=0.3u Nx=1 spiceprefix=X} {w 1n l 1n}] {
  place [symf $pdk $lib $cell] $props
  set n [edit_tok 0 $props {*}$toks]
  lappend got "$cell [tok 0 [lindex $toks 0]] [tok 0 [lindex $toks 2]] $n"
}
check {DL21 no limit in this tree: sky130/gf180 res and cap and IHP svaricap keep a tiny W/L, no line} $got \
  {{res_high_po 0.01 0.01 0} {cap_mim_m3_1 0.01 0.01 0} {ppolyf_u_1k 1e-9 1e-9 0} {cap_mim_2f0fF 1e-9 1e-9 0} {sg13_svaricap 1n 1n 0}}

# SP1..SP7 -- `xschem setprop instance` goes through the same clamp. The CIW is recorded
# (ciw_echo replaced for the band) and devlim::last holds the clamp's own messages.
# Only lines starting `warning: ` are recorded, as the FL band's `warnings` does: under
# --logdir (T1's dcases arm) the action log mirrors each `xschem setprop` command into
# the CIW untagged, and that line is not the clamp speaking.
set sp_had_ciw [llength [info commands ::ciw_echo]]
if {$sp_had_ciw} { rename ::ciw_echo ::sp_ciw_echo_saved }
set ::sp_ciw {}
proc ::ciw_echo {line {tag {}}} {
  if {[string match {warning: *} $line]} { lappend ::sp_ciw [list $tag $line] }
}
proc sp {args} { set ::devlim::last {} ; set ::sp_ciw {} ; xschem setprop {*}$args }

place $IHP_N $P0
sp instance 0 w 0.05u
check {SP1 setprop w=0.05u -> 0.13u, with apply's sentence once in the CIW as a note} \
  [list [tok 0 w] $::sp_ciw] \
  [list 0.13u [list {note {warning: M1 (sg13_lv_nmos): w=0.05u is below the minimum 0.13u; w set to 0.13u}}]]

set a [tok 0 w]
xschem undo
check {SP2 the correction rides setprop's undo step: w=0.13u, and one undo restores w=1u} \
  [list $a [tok 0 w]] {0.13u 1u}

place $IHP_N $P0
sp -fast instance 0 l 20u
set a [list [tok 0 l] [llength $::sp_ciw]]
place $IHP_N $P0
sp -fastundo instance 0 w 2e-8
check {SP3 -fast l=20u -> 10u and -fastundo w=2e-8 -> 0.13u, each with its line} \
  [list {*}$a [tok 0 w] [llength $::sp_ciw]] {10u 1 0.13u 1}

place $IHP_N $Pbad
sp instance 0 m 2
check {SP4 setprop m=2 leaves the old out-of-range l=0.05u alone and says nothing} \
  [list [tok 0 m] [tok 0 l] $::sp_ciw] {2 0.05u {}}

place $IHP_N $P0
sp instance 0 allprops [xschem subst_tok $P0 w 0.01u]
check {SP5 setprop allprops with w=0.01u -> 0.13u} [list [tok 0 w] [llength $::sp_ciw]] {0.13u 1}

place $IHP_N $P0
sp instance 0 w wp
check {SP6 setprop w=wp (a parameter) is left alone and says nothing} [list [tok 0 w] $::sp_ciw] {wp {}}

place $IHP_N $P0
sp instance 0 ng 10
check {SP7 setprop ng=10 alone at w=1u re-checks w per finger: w -> 1.3u} \
  [list [tok 0 w] [tok 0 ng] [llength $::sp_ciw]] {1.3u 10 1}

rename ::ciw_echo {}
if {$sp_had_ciw} { rename ::sp_ciw_echo_saved ::ciw_echo }

# ---------------------------------------------------------------------------
# FL -- the instance form's focus-out check (rows listed in the header).
set fl_rows {FL0 FL1 FL2 FL3 FL4 FL5 FL6 FL7 FL8 FL9 FL10 FL11}
set fl_ran 0
if {[catch {winfo exists .}]} {
  puts "skip: [join $fl_rows {, }] -- the instance property form is a Tk dialog and\
 this arm has no Tk; the display arm (dcases) runs them"
} else {
  set fl_ran 1
  proc settle {{n 6}} { for {set i 0} {$i < $n} {incr i} { update idletasks; update } }
  proc close_form {} {
    catch {while {[winfo exists .dialog]} { catch {slickprop::cancel}; catch {destroy .dialog}; update }}
  }
  # <props> of <sym> placed alone on a clean, unmodified sheet, selected, and the
  # real instance form opened on it.
  proc form_on {sym props} {
    close_form
    xschem clear force schematic
    xschem instance $sym 0 0 0 0 $props
    xschem set_modify 0
    xschem unselect_all
    xschem select instance 0
    xschem edit_prop
    settle
    return [winfo exists .dialog]
  }
  proc ent {tok} { return $::slickprop::cur(entry,$tok) }
  # Type <value> into <tok>'s field as a user would: focus it, then replace its text.
  # Answers 1 when the field holds the focus.
  proc type_into {tok value} {
    set e [ent $tok]
    focus -force $e ; settle
    $e delete 0 end
    $e insert 0 $value
    return [expr {[focus] eq $e}]
  }
  # Leave <tok>'s field as Tab does: the `all` binding for Tab runs exactly this (with
  # %W the field), and it moves the focus, so the field gets a real <FocusOut>.
  # shift_tab_into is Shift-Tab pressed in the field after <tok>, landing in <tok>.
  # Named by token rather than read off [focus], which is empty while another client
  # holds the display's focus.
  proc tab_out        {tok} { tk::TabToWindow [tk_focusNext [ent $tok]] ; settle }
  proc shift_tab_into {tok} { tk::TabToWindow [tk_focusPrev [tk_focusNext [ent $tok]]] ; settle }
  # ciw_echo recorded, not shown. warnings answers every recorded line that starts
  # `warning: ` since reset_ciw, whatever its tag; a tag other than apply's `note`
  # is prefixed to the line so it cannot pass for apply's sentence. Untagged action
  # log lines (the CIW mirror of --logdir runs) never start that way.
  set ::fl_ciw {}
  set fl_had_ciw [llength [info commands ::ciw_echo]]
  if {$fl_had_ciw} { rename ::ciw_echo ::fl_ciw_echo_saved }
  proc ::ciw_echo {line {tag {}}} { lappend ::fl_ciw [list $tag $line] }
  proc reset_ciw {} { set ::fl_ciw {} }
  proc warnings {} {
    set out {}
    foreach r $::fl_ciw {
      lassign $r tag line
      if {![string match {warning: *} $line]} continue
      lappend out [expr {$tag eq {note} ? $line : "(tag $tag) $line"}]
    }
    return $out
  }
  set ::fl_calls 0
  proc fl_count {args} { incr ::fl_calls }
  set fl_traced [expr {[info commands ::devlim::corrections] ne {}}]
  set SK1 {name=M1 W=1 L=1 nf=1 mult=1 model=nfet_01v8 spiceprefix=X}
  set IH1 {name=M1 l=1u w=1u ng=1 m=1 model=sg13_lv_nmos spiceprefix=X}
  set sayL {warning: M1 (nfet_01v8): L=0 is below the minimum 0.15; L set to 0.15}

  # FL0, FL1 -- sky130 L, Tab
  form_on $SKY_N $SK1
  set eL [ent L]
  set ::fl_fo 0
  bind $eL <FocusOut> {+incr ::fl_fo}
  set at [type_into L 0]
  reset_ciw
  if {$fl_traced} { trace add execution ::devlim::corrections enter fl_count }
  set ::fl_calls 0
  tab_out L
  set c1 $::fl_calls
  check {FL0 the Tab move delivers one real <FocusOut> to the field left and lands on the next field} \
    [list $at $::fl_fo [expr {[focus] eq [ent nf]}]] {1 1 1}
  check {FL1 sky130: L=0 typed and tabbed out of shows 0.15 in L's field with one CIW warning line, apply's sentence, and the sheet untouched} \
    [list [$eL get] [warnings] [xschem getprop instance 0 L] [xschem get modified]] \
    [list 0.15 [list $sayL] 1 0]

  # FL2 -- then OK: what OK itself says is counted alone
  set ::fl_calls 0
  reset_ciw
  .dialog.fb.ok invoke
  settle
  set c2 $::fl_calls
  if {$fl_traced} { trace remove execution ::devlim::corrections enter fl_count }
  set L2 [xschem getprop instance 0 L]
  set said2 [warnings]
  set open2 [winfo exists .dialog]
  xschem undo
  check {FL2 then OK: the instance's L is 0.15, OK says no CIW line of its own, the form closed, and one undo restores L=1} \
    [list $L2 $said2 $open2 [xschem getprop instance 0 L]] {0.15 {} 0 1}
  check {FL9 one rule: a trace on devlim::corrections fires once on FL1's focus-out and once on FL2's OK} \
    [list $c1 $c2] {1 1}

  # FL3 -- IHP, per finger
  form_on $IHP_N $IH1
  type_into ng 10
  reset_ciw
  tab_out ng
  check {FL3 IHP: ng=10 typed at w=1u and tabbed out of ng shows 1.3u in w's field, with the per-finger apply sentence} \
    [list [[ent w] get] [[ent ng] get] [warnings]] \
    [list 1.3u 10 [list {warning: M1 (sg13_lv_nmos): w/ng=0.1u is below the minimum 0.13u per finger; w set to 1.3u}]]

  # FL4 -- sky130, a parameter
  form_on $SKY_N $SK1
  type_into W {{W_N}}
  reset_ciw
  tab_out W
  check {FL4 sky130: a parameter typed into W and tabbed out of is left as typed, with no CIW line} \
    [list [[ent W] get] [warnings]] [list {{W_N}} {}]

  # FL5 -- IHP, a legal value
  form_on $IHP_N $IH1
  type_into l 0.5u
  reset_ciw
  tab_out l
  check {FL5 IHP: a legal l=0.5u typed and tabbed out of is left as typed, with no CIW line} \
    [list [[ent l] get] [warnings]] {0.5u {}}

  # FL6 -- IHP, the same field left twice
  form_on $IHP_N $IH1
  type_into l 0
  reset_ciw
  tab_out l
  shift_tab_into l
  set back [expr {[focus] eq [ent l]}]
  tab_out l
  check {FL6 IHP: l=0 typed, left by Tab, re-entered by Shift-Tab and left again, says one CIW line, not two} \
    [list $back [[ent l] get] [warnings]] \
    [list 1 0.13u [list {warning: M1 (sg13_lv_nmos): l=0 is below the minimum 0.13u; l set to 0.13u}]]

  # FL7 -- read-only sheet
  close_form
  xschem clear force schematic
  xschem instance $SKY_N 0 0 0 0 $SK1
  xschem set_modify 0
  xschem set readonly 1
  xschem unselect_all
  xschem select instance 0
  xschem edit_prop
  settle
  set ro [list [.dialog.fb.ok cget -state] [.dialog.fb.apply cget -state]]
  type_into L 0
  reset_ciw
  tab_out L
  set got7 [list [[ent L] get] [warnings]]
  catch {slickprop::apply_now}
  settle
  slickprop::cancel
  settle
  check {FL7 read-only sheet: L=0 typed and tabbed out of shows 0.15 with one CIW line while OK/Apply stay disabled; Apply and closing leave L=1 and the sheet unmodified} \
    [list {*}$ro {*}$got7 [winfo exists .dialog] [xschem getprop instance 0 L] [xschem get modified]] \
    [list disabled disabled 0.15 [list $sayL] 0 1 0]
  xschem set readonly 0

  # FL8 -- control: the OK path unchanged
  form_on $SKY_N $SK1
  type_into L 0
  reset_ciw
  .dialog.fb.ok invoke
  settle
  check {FL8 control: L=0 typed and OK pressed with the focus still in L says apply's line once, and the instance's L is 0.15} \
    [list [warnings] [xschem getprop instance 0 L] [winfo exists .dialog]] [list [list $sayL] 0.15 0]

  # FL11 -- a click on another field: the Entry class's <1> binding runs `focus` on it
  # and nothing else that matters here (no <<TraverseOut>>, which the Tab rows send)
  form_on $SKY_N $SK1
  type_into L 0
  reset_ciw
  focus [ent W]
  settle
  check {FL11 sky130: L=0 typed, then the focus moved straight to W as a click on W does, shows 0.15 in L's field with apply's line} \
    [list [expr {[focus] eq [ent W]}] [[ent L] get] [warnings]] [list 1 0.15 [list $sayL]]

  # FL10 -- the declared limit: two instances in scope
  close_form
  xschem clear force schematic
  xschem instance $IHP_N 0 0 0 0 $IH1
  xschem instance $IHP_N 400 0 0 0 {name=M2 l=1u w=2u ng=10 m=1 model=sg13_lv_nmos spiceprefix=X}
  xschem set_modify 0
  xschem unselect_all
  xschem select instance 0
  xschem select instance 1
  xschem edit_prop selected
  settle
  set shown [.dialog.fname.e get]
  type_into w 0.5u
  reset_ciw
  tab_out w
  set w10a [warnings]
  reset_ciw
  .dialog.fb.ok invoke
  settle
  check {FL10 two instances in scope: tabbing out of w=0.5u on the displayed M1 (ng=1) says nothing; OK clamps M2 (ng=10) with its own line} \
    [list $shown $w10a [warnings] [xschem getprop instance 0 w] [xschem getprop instance 1 w]] \
    [list M1 {} [list {warning: M2 (sg13_lv_nmos): w/ng=0.05u is below the minimum 0.13u per finger; w set to 1.3u}] 0.5u 1.3u]
  set ::slickprop_apply_scope current

  close_form
  rename ::ciw_echo {}
  if {$fl_had_ciw} { rename ::fl_ciw_echo_saved ::ciw_echo }
}

xschem clear force schematic
set floor [expr {$fl_ran ? 41 : 29}]
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
