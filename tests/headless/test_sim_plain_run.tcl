# test_sim_plain_run.tcl — THE C NETLISTER'S CASE-MODE BRIDGE.
# Issue 0506, then the `annotate` merge. Spec:
# doc/claude/specs/simulator_profiles.md section 18.
#
# ⚠ THIS FILE LOST TWO THIRDS OF ITSELF AT THE `annotate` MERGE, AND THE LOSS IS
# A REAL ONE. Issue 0506 had taught stock xschem's `proc simulate` — the
# Simulation menu, the button most users press — to compose its command from the
# simulator profile, so a registered executable and a case mode the Test button
# had PROVED the binary could deliver reached the run instead of stopping at the
# dialog. Eighteen checks (CS200–CS217, and CS221's simulate half) drove that
# composer: the byte-identity contract for an untouched configuration, the two
# shipped templates that must be DECLINED because their first word is a variable
# or a wrapper, the unplaceable-flags defect that once produced
# `xterm -e {ngspice ...} -D casemode=preserve`, and the rule that a declined exe
# or an unplaceable mode is REPORTED at tag `error` rather than dropped.
#
# The composer is gone because the store it read is gone: the profile fields
# moved onto the ASE-L simulator registry, and `proc simulate` knows nothing
# about ASE-L. Re-teaching it is real work with real questions in it — `sim()` is
# per-TOOL with N rows and the registry is one in-force entry, and stock xschem
# must still run with no ASE-L session anywhere — so it is on the owed ledger,
# not smuggled into a merge. THOSE EIGHTEEN CHECKS ARE NOT MIGRATED ANYWHERE.
# When the composer comes back, so do they; `git show <the merge>^:$0` has them.
#
# WHAT SURVIVES, AND IT IS THE HALF THAT REACHES C:
#   CS218/  THE Tcl BRIDGE C CALLS. `sim_netlist_casemode` is what
#   CS219   netlist_case_mode() (src/save.c) asks, and it must fall back to the
#           global floor when nothing answers — for a netlist type that has no
#           case question at all, and for a stock xschem with nothing registered.
#   CS220   THE C WIRE, observed through behaviour rather than asserted: the
#           netlist-time collision warning is silent under `distinguish` (C2), so
#           moving the registered simulator's mode must silence it. Nothing else
#           in this file can tell whether netlist_case_mode() really moved.
#   CS221a  the netlister emits the schematic's own spelling.
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

proc reset_rows {} { ase::sim_clear ; set ::sim_case_mode fold }

# --- the Tcl bridge C calls ---------------------------------------------------
reset_rows
set ::sim_case_mode fold
eqcheck CS218-the-bridge-falls-back-to-the-global-floor \
  [pcall sim_netlist_casemode spice] fold
set ::sim_case_mode preserve
eqcheck CS218b-the-floor-is-the-fallback-not-a-constant \
  [pcall sim_netlist_casemode spice] preserve
set ::sim_case_mode fold
pcall ase::sim_register netl /bin/sh -casemode distinguish
eqcheck CS219-the-registered-simulator-outranks-the-floor \
  [pcall sim_netlist_casemode spice] distinguish
# ⚠ A NETLIST TYPE WITH NO CASE QUESTION ANSWERS NOTHING, NOT AN ERROR, and
# `{}` is what save.c reads as "keep the floor". A raise here would take the
# netlist down with it: this proc is called from the netlister, and stock xschem
# netlists with ase.tcl sourced, nothing registered and no session anywhere.
eqcheck CS219b-a-non-spice-netlist-type-answers-nothing-not-an-error \
  [pcall sim_netlist_casemode verilog] {}
reset_rows

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
pcall ase::sim_register coll /bin/sh -casemode distinguish
xschem netlist
set n_dist [ncoll]
reset_rows
check CS220-netlist_case_mode-really-reads-the-registered-simulator \
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

# ⚠ CS221's SECOND HALF WAS HERE AND IS GONE. It drove the whole point end to
# end — a schematic net `EN`, netlisted, SIMULATED THROUGH `proc simulate` with a
# case-capable binary and `preserve` configured, and read back out of the raw as
# `v(EN)`. It cannot run without the composer `proc simulate` no longer has, and
# faking it by calling ASE-L instead would be a green row asserting a path the
# user's Simulate button does not take. CS221a above still holds the half that
# does not depend on it: the netlister writes the schematic's own spelling, which
# is what the simulator would have been handed.

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
