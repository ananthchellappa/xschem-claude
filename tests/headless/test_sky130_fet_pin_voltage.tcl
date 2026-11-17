# test_sky130_fet_pin_voltage.tcl -- the sky130 FET symbols show the DC node
# voltage at their D, G and S terminals in the annotation mode Alt-6 turns on.
#
# User report 2026-11-16: "When I annotate OP node voltages using Alt-6
# shortcut, the FET terminals in sky130 ... do not display node voltages.
# Schematic input/output pins do and devices/lab_pin wire labels do. We really
# need FET terminals to display DC node voltages when in annotation mode."
# Ruling the same day: "annotation for D,G,S (skip B) terminals".
#
# WHY THEY DID NOT. A node voltage is painted only by a symbol text whose WHOLE
# content is one of the `@spice_get_voltage` spellings (annot_content_class,
# src/actions.c): that text is the node-voltage class, hidden while annot_show
# bit 1 is off and shown while it is on. lab_pin, ipin and opin carry one. The
# sky130 FET symbols carried none per terminal -- only device-OP records, all
# `hide=true` -- so there was nothing to paint.
#
# THE FIX IS IN THE SYMBOLS: three records appended to every FET symbol of
# sky130A/xschem_libs/sky130_fd_pr,
#
#   T {@#D:spice_get_voltage} X Y 0 1 0.15 0.15 {layer=15}      (and G, and S)
#
# addressed by pin NAME, so a pfet (whose D and S swap places) needs no index
# swap, and carrying NO `hide=` token (one would move the text to View > Show
# hidden texts and out of Alt-6). Placed just outside each pin, from the pin
# rectangle: a top pin `(cx-2.5, cy-12.5)`, a bottom pin `(cx-2.5, cy+6.5)`, the
# gate `(cx-2.5, cy-12.5)`, all right-aligned. Not at B, and not at `sub`.
#
# BANDS. FP1-FP6 read the shipped symbol files; the population is every symbol
# of the library whose K block says nmos or pmos, derived each run. FP7-FP10
# load a sheet with one nfet and one pfet, attach an operating point and look at
# what the instances resolve and what an export paints with the mode off and on.
#
# No display is needed. From the repo ROOT:
#   tests/headless/run_suites.sh --nogui test_sky130_fet_pin_voltage

source [file join [file dirname [info script]] scratch.tcl]

set no_recent_files 1
set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

if {[catch {

set here [file dirname [file normalize [info script]]]
set repo [file dirname [file dirname $here]]
set tmp  [test_scratch fetpinv]
set libdir [file join $repo sky130A xschem_libs sky130_fd_pr]

# ---------------------------------------------------------------------------
# the symbol files
# ---------------------------------------------------------------------------
proc fp_slurp {p} { set f [open $p r] ; set d [read $f] ; close $f ; return $d }
## {name cx cy} of every pin rectangle
proc fp_pins {txt} {
    set out {}
    foreach line [split $txt \n] {
        if {![regexp {^B 5 (\S+) (\S+) (\S+) (\S+) \{(.*)\}} $line -> x1 y1 x2 y2 attrs]} { continue }
        if {![regexp {(?:^| )name=([A-Za-z0-9_]+)} $attrs -> nm]} { continue }
        lappend out [list $nm [expr {($x1 + $x2) / 2.0}] [expr {($y1 + $y2) / 2.0}]]
    }
    return $out
}
## {pin x y rot flip xs ys attrs} of every per-pin voltage record
proc fp_carriers {txt} {
    set out {}
    foreach line [split $txt \n] {
        if {[regexp {^T \{@#([A-Za-z0-9_]+):spice_get_voltage\} (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) \{(.*)\}$} \
               $line -> pin x y rot flip xs ys attrs]} {
            lappend out [list $pin $x $y $rot $flip $xs $ys $attrs]
        }
    }
    return $out
}
## where the record of a pin at (cx,cy) belongs; {} for a pin that gets none
proc fp_place {cx cy} {
    if {$cy < -20}     { return [list [expr {$cx - 2.5}] [expr {$cy - 12.5}]] }
    if {$cy > 20}      { return [list [expr {$cx - 2.5}] [expr {$cy + 6.5}]] }
    if {$cx < 0}       { return [list [expr {$cx - 2.5}] [expr {$cy - 12.5}]] }
    return {}
}

set fets {}
foreach f [lsort [glob -nocomplain -directory $libdir */symbol/*.sym]] {
    if {[regexp -line {^K \{type=[np]mos} [fp_slurp $f]]} { lappend fets $f }
}
set names [lmap f $fets {file rootname [file tail $f]}]
check_true "FP1 the population: the library's nmos and pmos symbols were found (3-, 4- and 5-pin among them)" \
    [expr {[llength $fets] > 0 && {nfet_01v8} in $names && {pfet_01v8} in $names
           && {nfet3_01v8} in $names && {nfet_20v0_iso} in $names}]

set missing {} ; set extra {} ; set notpin {} ; set hidden {} ; set shape {} ; set place {}
set with_b 0 ; set with_sub 0 ; set ncar 0
foreach f $fets nm $names {
    set txt [fp_slurp $f]
    set pins [fp_pins $txt]
    set pnames [lmap p $pins {lindex $p 0}]
    if {{B} in $pnames} { incr with_b }
    if {{sub} in $pnames} { incr with_sub }
    set cars [fp_carriers $txt]
    incr ncar [llength $cars]
    set cnames [lmap c $cars {lindex $c 0}]
    foreach want {D G S} {
        if {[llength [lsearch -all -exact $cnames $want]] != 1} { lappend missing "$nm: $want" }
    }
    foreach c $cars {
        lassign $c pin x y rot flip xs ys attrs
        if {$pin ni {D G S}} { lappend extra "$nm: $pin" }
        if {$pin ni $pnames} { lappend notpin "$nm: $pin" ; continue }
        if {[string match {*hide=*} $attrs]} { lappend hidden "$nm: $pin" }
        if {[list $rot $flip $xs $ys [string trim $attrs]] ne {0 1 0.15 0.15 layer=15}} {
            lappend shape "$nm: $pin {$rot $flip $xs $ys $attrs}"
        }
        foreach p $pins {
            if {[lindex $p 0] ne $pin} { continue }
            set w [fp_place [lindex $p 1] [lindex $p 2]]
            if {[llength $w] != 2 || $x != [lindex $w 0] || $y != [lindex $w 1]} {
                lappend place "$nm: $pin at {$x $y}, the pin asks {$w}"
            }
        }
    }
}
check "FP2 every FET symbol carries exactly one node-voltage record for each of D, G and S" $missing {}
check "FP3 ...and for no other pin: not the bulk, not sub" $extra {}
check_true "FP3 ...which is a statement about something: symbols with a B pin and with a sub pin are in the population" \
    [expr {$with_b > 0 && $with_sub > 0}]
check "FP3 ...three records per symbol, no more" $ncar [expr {3 * [llength $fets]}]
check "FP4 each record names a pin the symbol has" $notpin {}
check "FP5 no record carries a hide= token (it would leave Alt-6 for View > Show hidden texts)" $hidden {}
check "FP5 ...each is unrotated, right-aligned, size 0.15, layer 15" $shape {}
check "FP6 each sits just outside its own pin: above a top pin and the gate, below a bottom pin" $place {}

# ---------------------------------------------------------------------------
# a sheet, an operating point, and what is painted
#
# One nfet and one pfet as an inverter. Every net has a devices/lab_pin, whose
# own `@spice_get_voltage` text is the comparand for the FET's `@#<pin>:` ones:
# the same number reached by another road. The four node voltages differ, so a
# record reading the wrong pin shows.
# ---------------------------------------------------------------------------
file mkdir [file join $tmp lib inv schematic]
set sch [file join $tmp lib inv schematic inv.sch]
set fp [open $sch w]
puts $fp {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -370 420 -230 {lab=OUT}
N 380 -400 360 -400 {lab=IN}
N 360 -400 360 -200 {lab=IN}
N 360 -200 380 -200 {lab=IN}
N 420 -460 420 -430 {lab=VDD}
N 420 -400 440 -400 {lab=VDD}
N 420 -170 420 -140 {lab=VSS}
N 420 -200 440 -200 {lab=VSS}
C {sky130_fd_pr/nfet_01v8} 400 -200 0 0 {name=M1 W=2 L=0.5 nf=1 mult=1 model=nfet_01v8 spiceprefix=X}
C {sky130_fd_pr/pfet_01v8} 400 -400 0 0 {name=M2 W=4 L=0.5 nf=1 mult=1 model=pfet_01v8 spiceprefix=X}
C {devices/lab_pin} 420 -300 0 1 {name=l1 lab=OUT}
C {devices/lab_pin} 360 -300 0 0 {name=l2 lab=IN}
C {devices/lab_pin} 420 -460 0 0 {name=l3 lab=VDD}
C {devices/lab_pin} 440 -400 0 1 {name=l4 lab=VDD}
C {devices/lab_pin} 420 -140 0 0 {name=l5 lab=VSS}
C {devices/lab_pin} 440 -200 0 1 {name=l6 lab=VSS}}
close $fp
set raw [file join $tmp inv_op.raw]
set fp [open $raw w]
puts -nonewline $fp "Title: fet pin voltages
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 4
No. Points: 1
Variables:
\t0\tv(out)\tvoltage
\t1\tv(in)\tvoltage
\t2\tv(vdd)\tvoltage
\t3\tv(vss)\tvoltage
Values:
0\t0.375
\t0.9
\t1.8
\t0.25
"
close $fp
set fp [open [file join $tmp library.defs] w]
puts $fp "DEFINE fetpinv [file join $tmp lib]"
puts $fp "DEFINE sky130_fd_pr $libdir"
puts $fp "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $fp
set ::XSCHEM_LIBRARY_DEFS [file join $tmp library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

pcall xschem load $sch
check "FP7 fixture: the sheet loaded with its two FETs and six labels, and the operating point attached" \
    [list [pcall xschem get instances] [catch {xschem annotate_op $raw}] [pcall xschem raw loaded]] {8 0 0}
## the four nets as the LABELS read them
set v_out [pcall xschem translate l1 {@spice_get_voltage}]
set v_in  [pcall xschem translate l2 {@spice_get_voltage}]
set v_vdd [pcall xschem translate l3 {@spice_get_voltage}]
set v_vss [pcall xschem translate l5 {@spice_get_voltage}]
check_true "FP7 fixture: the labels read four numbers, all different" \
    [expr {[llength [lsort -unique [list $v_out $v_in $v_vdd $v_vss]]] == 4
           && [string is double -strict [string map {m e-3} $v_out]] && ![string match ERR:* $v_out]}]
check "FP8 the nfet's D, G and S records read their own nets (by pin NAME)" \
    [list [pcall xschem translate M1 {@#D:spice_get_voltage}] \
          [pcall xschem translate M1 {@#G:spice_get_voltage}] \
          [pcall xschem translate M1 {@#S:spice_get_voltage}]] [list $v_out $v_in $v_vss]
check "FP8 ...and the pfet's, whose D and S pins sit the other way up" \
    [list [pcall xschem translate M2 {@#D:spice_get_voltage}] \
          [pcall xschem translate M2 {@#G:spice_get_voltage}] \
          [pcall xschem translate M2 {@#S:spice_get_voltage}]] [list $v_out $v_in $v_vdd]

## WHAT IS PAINTED, off an SVG export: how many texts show each net's number.
## The labels account for 1 (OUT), 1 (IN), 2 (VDD), 2 (VSS). The FETs add two
## drains, two gates, the pfet's source and the nfet's source -- and nothing for
## a bulk, which would make VDD and VSS one more each.
proc fp_painted {mask svg vals} {
    if {[catch {
        xschem set annot_show $mask
        xschem update_all_sym_bboxes
        xschem zoom_full
        catch {file delete $svg}
        xschem print svg $svg
        set f [open $svg r] ; set t [read $f] ; close $f
    } e]} { return "ERR:$e" }
    return [lmap v $vals {regexp -all ">[string map {. \\.} $v]<" $t}]
}
set vals [list $v_out $v_in $v_vdd $v_vss]
check "FP9 with the mode Alt-6 turns on, every FET terminal shows its node voltage: D, G, S and not the bulk" \
    [fp_painted 2 [file join $tmp inv2.svg] $vals] {3 3 3 3}
check "FP9 ...and with the device-OP overlay on beside it (annot_show 3) just the same" \
    [fp_painted 3 [file join $tmp inv3.svg] $vals] {3 3 3 3}
check "FP10 with the mode off nothing of it is painted, on the FETs or the labels" \
    [fp_painted 0 [file join $tmp inv0.svg] $vals] {0 0 0 0}
check "FP10 ...nor under the device-OP overlay alone (annot_show 1)" \
    [fp_painted 1 [file join $tmp inv1.svg] $vals] {0 0 0 0}
pcall xschem set annot_show 0

} err]} {
    puts "UNEXPECTED ERROR: $err"
    incr fail
}

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
