# Regression: wire segment splitting (independent click regions between attachment points).
# See doc/claude/specs/wire_segment_splitting.md.
#
# Phase W0 -- the linchpin: trim_wires' collinear-rejoin MERGE must be PIN-AWARE.
# trim_wires (check.c) welds two collinear touching segments when both shared-endpoint
# connection counters (end1/end2) are 0. Those counters count only OTHER WIRES, never
# instance pins / net-labels -- so today it merges two segments across a label pin,
# destroying the segment boundary the split feature depends on. W0 adds an
# any_inst_pin_at(x,y) guard so a joint carrying a pin is NOT merged (and, once the pin
# is later removed, IS merged again -> free auto-rejoin on label delete).
#
# This file will grow to cover W1-W6 (see the spec's test matrix T1-T8); W0 checks first.
#
# Pure headless. Run from the repo ROOT (or tests/, paths are normalized):
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_wire_split.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name = $got"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc bail {msg} { puts "FATAL: $msg : FAIL"; puts "OVERALL: notok"; exit 1 }

# Build a fresh sheet with two collinear abutting horizontal wires meeting at (jx,-60),
# built with autotrim OFF so construction never merges them prematurely. `withlabel` places
# a devices/lab_wire whose pin sits exactly at the joint (its PINLAYER rect is centered on
# the instance origin, so the pin coincides with the placement coordinate).
proc build_two_segments {jx withlabel} {
  catch {xschem clear force}
  set ::autotrim_wires 0
  xschem wire -100 -60 $jx -60
  xschem wire $jx -60 100 -60
  if {$withlabel} {
    xschem instance devices/lab_wire $jx -60 0 0 "name=l1 lab=GB"
  }
}

if {[catch {xschem clear force} e]} { bail "no xschem command / clear failed: $e" }

# --- Positive control: WITHOUT a pin at the joint, trim_wires MUST still merge the two
#     collinear segments into one. Proves the merge machinery is intact (must stay GREEN
#     before and after the W0 fix; guards against a fix that just disables merging). ---
build_two_segments 0 0
check "W0 control: 2 segments built (no label)" [xschem get wires] 2
set ::autotrim_wires 1
xschem trim_wires
check "W0 control: collinear segments merge with no pin at joint" [xschem get wires] 1

# --- W0 RED anchor: WITH a net-label pin exactly at the joint, trim_wires must NOT merge.
#     Today (pin-blind merge) this yields 1 -> FAIL. After the any_inst_pin_at guard: 2. ---
build_two_segments 0 1
check "W0: 2 segments + label built" [xschem get wires] 2
check "W0: label instance placed" [expr {[xschem get instances] >= 1}] 1
set ::autotrim_wires 1
xschem trim_wires
check "W0 RED: no merge across a joint carrying a label pin" [xschem get wires] 2

# --- Secondary: the two segments must be DISTINCT stable wire_ids (not one object). ---
if {[xschem get wires] == 2} {
  set id0 [xschem wire_id 0]
  set id1 [xschem wire_id 1]
  check "W0: the two segments are distinct wire_ids" [expr {$id0 ne $id1}] 1
}

# ===========================================================================
# Phase W1 -- read-time split at attachment points.
# Loading a .sch with autotrim_wires on must split each wire at every interior
# attachment point (instance pin / net-label) into independent in-memory segments.
# Fixture: one wire -100..100 (y=0) with two lab_wire net-labels tapping it at x=-50 and
# x=+50 (same lab=GB, so one net, no ERC short). Expect 3 segments after load.
# ===========================================================================
proc write_sch {path body} { set fd [open $path w]; puts -nonewline $fd $body; close $fd }
set wdir [file join /tmp ws_w1_[pid]]
file mkdir $wdir
set f1 [file join $wdir two_labels.sch]
write_sch $f1 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 100 0 {}
C {devices/lab_wire} -50 0 0 0 {name=l1 lab=GB}
C {devices/lab_wire} 50 0 0 0 {name=l2 lab=GB}
}
set ::autotrim_wires 1
if {[catch {xschem load $f1} e]} { bail "W1 load fixture: $e" }
check "W1 T1: 1 wire + 2 mid-span labels -> 3 segments" [xschem get wires] 3
if {[xschem get wires] == 3} {
  # UX: each inter-attachment region is an independent click target resolving to ONE
  # distinct segment (the whole point of the feature).
  set ids {}
  foreach x {-75 0 75} {
    set row [xschem select_at $x 0]
    check "W1 T1: select_at $x 0 hits a wire" [lindex $row 0] wire
    lappend ids [lindex $row 3]
  }
  check "W1 T1: 3 regions -> 3 distinct wire_ids" [llength [lsort -unique $ids]] 3
  # geometry preserved exactly: boundaries at the two taps, full span -100..100, no gaps.
  set xs {}
  for {set i 0} {$i < 3} {incr i} { lassign [xschem wire_coord $i] a b c d; lappend xs $a $c }
  check "W1 T1: segment endpoints = {-100 -50 50 100} (taps exact, span intact)" \
        [lsort -real -unique $xs] {-100 -50 50 100}
}
# (connectivity invariance across the split is asserted in W2.)

if {$fail == 0} { puts "OVERALL: ok"; exit 0 } else { puts "OVERALL: notok"; exit 1 }
