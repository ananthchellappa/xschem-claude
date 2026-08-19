# test_sim_plain_run.tcl — THE PLAIN Simulate PATH COMPOSED FROM THE PROFILE.
# Issue 0506. Spec: doc/claude/specs/simulator_profiles.md section 18.
#
# WHAT THIS IS. Items 6/7/13 built a per-simulator profile — an `exe`, a
# requested `Case` mode, and a Test button that offers only the modes the binary
# was MEASURED to deliver — and `proc simulate` read NONE of it. It ran
# `sim($tool,$def,cmd)` verbatim, whose shipped batch row is a bare `ngspice` off
# PATH with no `-D casemode=`. A user could register a case-capable ngspice, set
# Case=preserve, press Test, read "delivers fold preserve distinguish", press
# Simulate, and get a different binary at `fold`. Item 8 fixed the same gap for
# ASE-L; this is the other run path.
#
# THE LOAD-BEARING CHECKS, and why:
#   CS200   THE COMPATIBILITY CONTRACT, and it carries a configured half in the
#           SAME assertion so it cannot pass by the feature being absent. A row
#           naming no exe and requesting `fold` — the shipped state, and A1's
#           default — must compose BYTE-IDENTICALLY.
#   CS202/  THE TWO SHIPPED TEMPLATES THAT MUST BE DECLINED, named individually
#   CS203   because each defeats a different one of the three conditions:
#           row 0's first word is a VARIABLE, row 4's is a literal that is not
#           the simulator. These are the rows section 10's ban was written about.
#   CS210/  UNPLACEABLE. This was a real defect in the first revision: row 0 had
#   CS211   its exe correctly declined and the flags appended anyway, producing
#           `xterm -e {ngspice ...} -D casemode=preserve` — flags for the
#           TERMINAL, two levels out from the simulator. The measurement that
#           licenses appending is about a DIRECT invocation and says nothing
#           about a wrapped one.
#   CS215   ...and an unplaceable mode is REPORTED at tag `error`. A silent drop
#           would be this issue's own defect one layer along.
#   CS220   THE C WIRE, observed through behaviour rather than asserted: the
#           netlist-time collision warning is silent under `distinguish` (C2), so
#           setting the DEFAULT ROW's mode must silence it. Nothing else in this
#           file can tell whether netlist_case_mode() really moved.
#   CS221   THE WHOLE POINT, end to end: a schematic net `EN`, netlisted,
#           SIMULATED through proc simulate, and read back as `v(EN)`. Skipped
#           (not failed) when no case-capable ngspice is present.
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sim_plain_run.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
set nskip 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
proc skip {name why} { global nskip; puts "skip: $name ($why)"; incr nskip }
# every call goes through this: a proc that does not exist yet must FAIL a
# check, never abort the file with no RESULT line
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc dg {d k} {
  if {[catch {dict get $d $k} v]} { return "NO:$k" }
  return $v
}
proc wfile {path content} {
  set f [open $path w] ; puts $f $content ; close $f
}

set scratch [test_scratch sim_plain_run]
set ::netlist_dir $scratch

# A case-capable ngspice, if this machine has one. Everything that needs a real
# process is guarded on it; everything else is a pure function and always runs.
set NGCASE {}
foreach c [list /home/qflow/dev/ngspice_test/build-ver_50/src/ngspice] {
  if {[file executable $c]} { set NGCASE $c ; break }
}
# A binary that certainly exists, for the exe-plan checks, which never run it.
set NGANY [lindex [auto_execok ngspice] 0]
if {$NGANY eq {}} { set NGANY $NGCASE }

if {[catch {

set_sim_defaults
set ROW0 $sim(spice,0,cmd)
set ROW2 $sim(spice,2,cmd)
set ROW4 $sim(spice,4,cmd)

proc compose {tool idx raw} { return [pcall sim_profile_compose_cmd $tool $idx $raw $raw] }
proc reset_rows {} {
  global sim
  catch {unset sim}
  set_sim_defaults
}

# --- CS200 the compatibility contract, both halves in one assertion ------------
reset_rows
set unconf [dg [compose spice 2 $ROW2] cmd]
pcall sim_profile_set spice 2 exe $NGANY
pcall sim_profile_set spice 2 casemode preserve
set conf [dg [compose spice 2 $ROW2] cmd]
eqcheck CS200-unconfigured-is-byte-identical-and-configured-is-not \
  "unconf=<[expr {$unconf eq $ROW2}]> conf_differs=<[expr {$conf ne $ROW2}]>" \
  {unconf=<1> conf_differs=<1>}

# --- the exe plan -------------------------------------------------------------
reset_rows
pcall sim_profile_set spice 2 exe $NGANY
eqcheck CS201-exe-applied-when-first-word-tail-matches \
  [dg [compose spice 2 $ROW2] exe_status] applied
# the FULL registered path, at word 0 -- not merely "the tail appears somewhere",
# which the untouched template already satisfies
eqcheck CS201b-the-applied-path-is-the-registered-one \
  [lindex [dg [compose spice 2 $ROW2] cmd] 0] $NGANY

# CS201c: a path with a space must survive `eval execute $st $cmd`, which
# re-parses the composed string as a Tcl command line. `[list $exe]` braces it;
# a bare interpolation would split the simulator into two words and run neither.
set spacedir [file join $scratch {exe dir}]
file mkdir $spacedir
set spaced [file join $spacedir ngspice]
catch {file delete $spaced}
if {[catch {file link -symbolic $spaced $NGANY}]} { catch {file copy -force $NGANY $spaced} }
if {[file executable $spaced]} {
  reset_rows
  pcall sim_profile_set spice 2 exe $spaced
  eqcheck CS201c-a-path-with-a-space-stays-one-word \
    "w0=<[lindex [dg [compose spice 2 $ROW2] cmd] 0]> n=<[llength [dg [compose spice 2 $ROW2] cmd]]>" \
    "w0=<$spaced> n=<[llength $ROW2]>"
} else {
  skip CS201c-a-path-with-a-space-stays-one-word {could not create a spaced-path executable}
}

reset_rows
pcall sim_profile_set spice 0 exe $NGANY
eqcheck CS202-row0-variable-first-word-is-declined \
  "st=<[dg [compose spice 0 $ROW0] exe_status]> cmd_unchanged=<[expr {[dg [compose spice 0 $ROW0] cmd] eq $ROW0}]>" \
  {st=<declined> cmd_unchanged=<1>}

reset_rows
pcall sim_profile_set spice 4 exe $NGANY
eqcheck CS203-row4-mpirun-wrapper-tail-mismatch-is-declined \
  "st=<[dg [compose spice 4 $ROW4] exe_status]> cmd_unchanged=<[expr {[dg [compose spice 4 $ROW4] cmd] eq $ROW4}]>" \
  {st=<declined> cmd_unchanged=<1>}

reset_rows
eqcheck CS204-no-exe-registered-is-none-not-declined \
  [dg [compose spice 2 $ROW2] exe_status] none

# --- the flags ----------------------------------------------------------------
reset_rows
pcall sim_profile_set spice 2 exe $NGANY
pcall sim_profile_set spice 2 casemode preserve
eqcheck CS205-non-fold-request-emits-mode-and-casemodewrite \
  [dg [compose spice 2 $ROW2] flags] {-D casemode=preserve -D casemodewrite}

pcall sim_profile_set spice 2 casemode fold
eqcheck CS206-a-fold-request-emits-nothing \
  "flags=<[dg [compose spice 2 $ROW2] flags]> st=<[dg [compose spice 2 $ROW2] flag_status]>" \
  {flags=<> st=<none>}

# CS213: `casemodewrite` never travels alone and never for `fold`. It is what
# makes the raw self-describing (ngspice stamps `Option: casemode=` only when it
# is set), i.e. what lets item 3's header source — mode source 2 — ever fire on a
# file we caused to be written.
pcall sim_profile_set spice 2 casemode distinguish
set fl [dg [compose spice 2 $ROW2] flags]
check CS213-casemodewrite-rides-with-the-mode-never-alone \
  [expr {[lsearch -exact $fl casemodewrite] > 0 && [lsearch -glob $fl casemode=*] > 0}] \
  "(flags '$fl')"

reset_rows
pcall sim_profile_set spice 3 casemode preserve
eqcheck CS207-a-Xyce-row-never-gets-an-ngspice-flag \
  [dg [compose spice 3 [set sim(spice,3,cmd)]] flags] {}

reset_rows
if {[info exists sim(verilog,0,cmd)]} {
  pcall sim_profile_set verilog 0 casemode preserve
  eqcheck CS208-a-non-spice-tool-never-gets-the-flag \
    [dg [compose verilog 0 $sim(verilog,0,cmd)] flags] {}
} else {
  skip CS208-a-non-spice-tool-never-gets-the-flag {no verilog tool configured}
}

reset_rows
pcall sim_profile_set spice 2 exe $NGANY
pcall sim_profile_set spice 2 casemode preserve
set d [compose spice 2 {ngspice -b -D casemode=distinguish -r "$n.raw" "$N"}]
eqcheck CS209-a-hand-written-casemode-in-the-template-wins \
  "st=<[dg $d flag_status]> flags=<[dg $d flags]> once=<[regexp -all {casemode=} [dg $d cmd]]>" \
  {st=<template> flags=<> once=<1>}

# --- placement: the defect the first revision shipped -------------------------
reset_rows
pcall sim_profile_set spice 0 exe $NGANY
pcall sim_profile_set spice 0 casemode preserve
set d [compose spice 0 $ROW0]
eqcheck CS210-a-wrapped-template-is-unplaceable-and-is-not-appended-to \
  "st=<[dg $d flag_status]> cmd_unchanged=<[expr {[dg $d cmd] eq $ROW0}]>" \
  {st=<unplaceable> cmd_unchanged=<1>}

reset_rows
pcall sim_profile_set spice 1 casemode preserve
set sh {sh -c "ngspice -b '$N'"}
set d [compose spice 1 $sh]
eqcheck CS211-a-shell-wrapper-naming-ngspice-is-still-unplaceable \
  "st=<[dg $d flag_status]> cmd_unchanged=<[expr {[dg $d cmd] eq $sh}]>" \
  {st=<unplaceable> cmd_unchanged=<1>}

reset_rows
pcall sim_profile_set spice 1 casemode preserve
set d [compose spice 1 $sim(spice,1,cmd)]
eqcheck CS212-a-bare-ngspice-first-word-takes-the-flags-with-no-exe-registered \
  "st=<[dg $d flag_status]> exe=<[dg $d exe_status]>" \
  {st=<appended> exe=<none>}

# --- the report ---------------------------------------------------------------
proc tags {d} {
  set t {}
  foreach l [pcall sim_profile_compose_report $d] { lappend t [lindex $l 0] }
  return $t
}
reset_rows
eqcheck CS217-a-configuration-nobody-touched-says-nothing \
  [tags [compose spice 2 $ROW2]] {}

reset_rows
pcall sim_profile_set spice 2 exe $NGANY
pcall sim_profile_set spice 2 casemode preserve
eqcheck CS216-a-successful-append-is-a-note \
  [tags [compose spice 2 $ROW2]] note

reset_rows
pcall sim_profile_set spice 4 exe $NGANY
eqcheck CS214-a-declined-exe-is-an-error-not-a-note \
  [tags [compose spice 4 $ROW4]] error

reset_rows
pcall sim_profile_set spice 0 casemode preserve
eqcheck CS215-an-unplaceable-mode-is-an-error-not-a-note \
  [tags [compose spice 0 $ROW0]] error

# --- the Tcl bridge C calls ---------------------------------------------------
reset_rows
set ::sim_case_mode fold
eqcheck CS218-the-bridge-falls-back-to-the-global-floor \
  [pcall sim_profile_netlist_casemode spice] fold
set ::sim_case_mode preserve
eqcheck CS218b-the-floor-is-the-fallback-not-a-constant \
  [pcall sim_profile_netlist_casemode spice] preserve
set ::sim_case_mode fold
pcall sim_profile_set spice [pcall sim_profile_default_index spice] casemode distinguish
eqcheck CS219-a-profile-row-outranks-the-floor \
  [pcall sim_profile_netlist_casemode spice] distinguish
eqcheck CS219b-an-unconfigured-tool-answers-the-floor-not-an-error \
  [pcall sim_profile_netlist_casemode nosuchtool] fold

# --- CS220 the C wire, observed through behaviour -----------------------------
# netlist_case_mode() is C and has no Tcl accessor. What it drives is item 14's
# collision warning, which C2 makes SILENT under `distinguish`. So: netlist a
# schematic whose nets collide, twice, moving only the DEFAULT ROW's casemode.
wfile [file join $scratch pr_coll.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -190 200 -190 {}
N 0 -190 0 -130 {}
N 200 -130 200 -90 {}
C {devices/vsource} 0 -100 0 0 {name=V1 value=1.5}
C {devices/gnd} 0 -70 0 0 {name=l1 lab=0}
C {devices/res} 200 -160 0 0 {name=R1 value=1k}
C {devices/res} 200 -60 0 0 {name=R2 value=1k}
C {devices/gnd} 200 -30 0 0 {name=l2 lab=0}
C {devices/lab_pin} 100 -190 0 0 {name=p1 lab=Out}
C {devices/lab_pin} 200 -110 0 0 {name=p2 lab=OUT}}

proc ncoll {} {
  set n 0
  foreach ln [split [xschem get infowindow_text] \n] {
    if {[string match {*differ only in case*} $ln]} { incr n }
  }
  return $n
}
reset_rows
set ::sim_case_mode fold
xschem load [file join $scratch pr_coll.sch]
xschem netlist
set n_fold [ncoll]
pcall sim_profile_set spice [pcall sim_profile_default_index spice] casemode distinguish
xschem netlist
set n_dist [ncoll]
check CS220-netlist_case_mode-really-reads-the-profile-row \
  [expr {$n_fold > 0 && $n_dist == 0}] \
  "(fold warned $n_fold times, distinguish warned $n_dist)"

# --- CS221 the whole point, end to end ----------------------------------------
wfile [file join $scratch pr_en.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -190 200 -190 {}
N 0 -190 0 -130 {}
N 200 -130 200 -90 {}
C {devices/vsource} 0 -100 0 0 {name=V1 value=1.5}
C {devices/gnd} 0 -70 0 0 {name=l1 lab=0}
C {devices/res} 200 -160 0 0 {name=R1 value=1k}
C {devices/res} 200 -60 0 0 {name=R2 value=1k}
C {devices/gnd} 200 -30 0 0 {name=l2 lab=0}
C {devices/lab_pin} 100 -190 0 0 {name=p1 lab=EN}
C {devices/lab_pin} 200 -110 0 0 {name=p2 lab=OUT}
C {devices/code_shown} 460 -190 0 0 {name=STIMULI only_toplevel=false value=".tran 1n 10n
"}}

reset_rows
xschem load [file join $scratch pr_en.sch]
xschem netlist
set deck [file join $scratch pr_en.spice]
set nl {}
if {[file exists $deck]} { set f [open $deck] ; set nl [read $f] ; close $f }
check CS221a-the-netlister-emits-the-schematic-spelling \
  [expr {[string match {*V1 EN 0*} $nl] && ![string match {*V1 en 0*} $nl]}] \
  "(deck names EN verbatim)"

if {$NGCASE eq {}} {
  skip CS221-EN-survives-schematic-to-viewer {no case-capable ngspice on this machine}
} else {
  pcall sim_profile_set spice 2 exe $NGCASE
  pcall sim_profile_set spice 2 casemode preserve
  set sim(spice,default) 2
  set sim(spice,2,fg) 1
  catch {file delete [file join $scratch pr_en.raw]}
  simulate
  set names {} ; set mode {} ; set src {}
  if {![catch {xschem raw read [file join $scratch pr_en.raw] tran}]} {
    set names [split [xschem raw list] \n]
    set mode [xschem raw casemode]
    set src [xschem raw casemode -source]
    xschem raw clear
  }
  eqcheck CS221-EN-survives-schematic-to-viewer \
    "vEN=<[expr {[lsearch -exact $names {v(EN)}] >= 0}]>\
 ven=<[expr {[lsearch -exact $names {v(en)}] >= 0}]> mode=<$mode> src=<$src>" \
    {vEN=<1> ven=<0> mode=<preserve> src=<header>}
}

} err]} {
  puts "FATAL: $err"
  puts "  $::errorInfo"
  incr fail
}

catch {test_scratch_drop $scratch}
puts "----"
puts "test_sim_plain_run: $npass passed, $fail failed, $nskip skipped"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks, $nskip skipped)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
