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

# --- W0/D2 gate: with the feature OFF (autotrim_wires 0) trim_wires keeps its ORIGINAL
#     behavior and DOES merge across a pin -- default mode is byte-for-byte unchanged. The
#     pin-aware guard is gated on autotrim_wires; this catches a regression that would let
#     the guard alter default trim/join. (Same fixture: OFF -> 1, ON -> 2 above.) ---
build_two_segments 0 1
set ::autotrim_wires 0
xschem trim_wires
check "W0/D2: default mode (autotrim off) still merges across a pin" [xschem get wires] 1

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

# ===========================================================================
# Phase W2 -- connectivity / netlist invariance (INV-1).
# Splitting a wire into collinear touching segments must NOT change which nodes exist,
# which pins are on which node, or the auto #netN numbering. Build a SELF-CONTAINED
# fixture (so the test does not depend on any untracked library file): a resistor R7
# whose P pin taps a GB-labelled wire mid-span. Load split OFF then ON and assert the
# instance node map is byte-identical -- while proving the split actually happened
# (1 wire vs 3), so the invariance is not vacuous.
# ===========================================================================
set f2 [file join $wdir res_label.sch]
write_sch $f2 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 -60 110 -60 {}
C {devices/lab_wire} -80 -60 0 0 {name=l8 lab=GB}
C {devices/res} 0 -30 0 1 {name=R7 m=1 value=320}
}
proc load_at {file at} { set ::autotrim_wires $at; xschem load $file }

load_at $f2 0
set nmap_off [xschem instance_nodemap R7]
set nwire_off [xschem get wires]
load_at $f2 1
set nmap_on [xschem instance_nodemap R7]
set nwire_on [xschem get wires]

check "W2 T2: split actually happened (1 wire -> 3 segments)" [list $nwire_off $nwire_on] {1 3}
check "W2 T2: R7 node map byte-identical split OFF vs ON (INV-1)" $nmap_on $nmap_off
check "W2 T2: R7.P taps net GB through the split" [lindex $nmap_on 2] GB

# Optional integration on the real sandbox fixture -- SKIP (not fail) if it is absent,
# since it is an untracked SANDBOX file not shipped with these commits.
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here .. ..]]
set realf [file join $root xschem_libs_newsym SANDBOX test_wire_splits schematic test_wire_splits.sch]
if {[file exists $realf]} {
  load_at $realf 1
  check "W2 integration: real test_wire_splits.sch -> 3 segments" [xschem get wires] 3
} else {
  puts "ok:   W2 integration skipped (real fixture absent; self-contained fixture covers it)"
}

# ===========================================================================
# Phase W4 -- coalesce-on-save (D1: the on-disk .sch stays the minimal, byte-stable form).
# With autotrim on, a wire tapped mid-span is split into N clickable segments IN MEMORY
# (W1), but the .sch must round-trip as the ORIGINAL single N record: save re-joins the
# collinear, same-prop, pin-free-abutting runs on a private scratch copy WITHOUT disturbing
# the live segmented array (the user keeps clickable segments after saving). Strictly gated
# on autotrim_wires: default mode saves are verbatim -- a default user's deliberately
# abutting collinear wires must never be silently merged.
# ===========================================================================
proc slurp {p} { set fd [open $p r]; set d [read $fd]; close $fd; return $d }
proc count_N {p} {
  set n 0
  foreach ln [split [slurp $p] \n] { if {[string match "N *" $ln]} { incr n } }
  return $n
}

# Canonical baseline: render f1 (1 wire -100..100 + 2 labels) with split OFF -> exactly 1 N
# record, in xschem's precise on-disk form. This is the byte target D1 must reproduce.
set base [file join $wdir w4_base.sch]
set ::autotrim_wires 0
xschem load $f1
xschem saveas $base schematic
check "W4 baseline: split-off canonical file has exactly 1 N record" [count_N $base] 1
check "W4 baseline: split-off load keeps 1 wire" [xschem get wires] 1

# T6 -- open the canonical file WITH split on: 3 segments in RAM, but saveas must coalesce
# back to the identical single-N file (round-trip byte-stable). RED without W4: no coalesce
# => 3 N records => files differ.
set ::autotrim_wires 1
xschem load $base
check "W4 T6: split-on load re-splits to 3 segments in memory" [xschem get wires] 3
set out [file join $wdir w4_out.sch]
xschem saveas $out schematic
check "W4 T6: coalesce-on-save writes exactly 1 N record" [count_N $out] 1
check "W4 T6: saved .sch byte-identical to split-off canonical form (D1)" [slurp $out] [slurp $base]
check "W4 T6: coalesce did NOT disturb the live segmented array (still 3)" [xschem get wires] 3
xschem load $out
check "W4 T6: reload of coalesced file re-splits to 3 (round-trip)" [xschem get wires] 3

# T6 INV-1: the split+coalesce round-trip must not change connectivity (res+label fixture).
set ::autotrim_wires 0
xschem load $f2
set nmap_base [xschem instance_nodemap R7]
set rbase [file join $wdir w4_rbase.sch]
xschem saveas $rbase schematic
set ::autotrim_wires 1
xschem load $rbase
set rout [file join $wdir w4_rout.sch]
xschem saveas $rout schematic
check "W4 T6 INV-1: coalesced round-trip file has 1 N record" [count_N $rout] 1
xschem load $rout
check "W4 T6 INV-1: R7 node map unchanged across split+coalesce round-trip" \
      [xschem instance_nodemap R7] $nmap_base

# T7 -- default mode (autotrim off): no split, saveas VERBATIM, byte-stable open->save->open->save.
set ::autotrim_wires 0
xschem load $f1
check "W4 T7: default-mode load keeps 1 wire (no split)" [xschem get wires] 1
set a [file join $wdir w4_a.sch]; set b [file join $wdir w4_b.sch]
xschem saveas $a schematic
xschem load $a
xschem saveas $b schematic
check "W4 T7: default-mode save is byte-stable (verbatim, no coalesce)" [slurp $a] [slurp $b]

# T7b -- default mode must NOT coalesce two abutting collinear same-prop wires the user built
# on purpose (guards over-eager coalesce leaking into default mode).
catch {xschem clear force}
set ::autotrim_wires 0
xschem wire -100 40 0 40
xschem wire 0 40 100 40
set c [file join $wdir w4_c.sch]
xschem saveas $c schematic
check "W4 T7b: default mode keeps 2 deliberately-abutting collinear wires on disk" [count_N $c] 2

# T6b -- prop divergence: split a wire at a label pin (2 segments), diverge ONE segment's
# prop; coalesce must REFUSE to merge across the real difference -> 2 records persist (H7).
set f3 [file join $wdir one_label.sch]
write_sch $f3 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 20 100 20 {}
C {devices/lab_wire} 0 20 0 0 {name=l9 lab=GB}
}
set ::autotrim_wires 1
xschem load $f3
check "W4 T6b: one wire + mid-span label -> 2 segments" [xschem get wires] 2
xschem setprop wire 0 lab XX
set d3 [file join $wdir w4_diverge.sch]
xschem saveas $d3 schematic
check "W4 T6b: divergent-prop segments NOT coalesced (2 N records persist)" [count_N $d3] 2
# control (non-vacuous): same fixture, NO divergence -> coalesces to 1.
xschem load $f3
set d3b [file join $wdir w4_conv.sch]
xschem saveas $d3b schematic
check "W4 T6b control: same fixture, no divergence -> coalesces to 1 N" [count_N $d3b] 1

# T6c -- a genuine T-junction (a 3rd wire's ENDPOINT lands mid-span) is a real connection
# node: coalesce must NOT weld the two collinear halves across it (spec 6.3: "no 3rd-wire
# endpoint at the joint"). This preserves trim_wires' in-memory split and matches pre-W4
# autotrim save behaviour -- W4 only re-joins ITS OWN attachment-pin splits, not T-splits.
set f4 [file join $wdir tee.sch]
write_sch $f4 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 -20 100 -20 {}
N 0 -80 0 -20 {}
}
set ::autotrim_wires 1
xschem load $f4
check "W4 T6c: autotrim load splits the horizontal at the T (3 wires)" [xschem get wires] 3
set t4 [file join $wdir w4_tee.sch]
xschem saveas $t4 schematic
check "W4 T6c: coalesce keeps the T split (3 N records; no weld across a 3rd-wire endpoint)" \
      [count_N $t4] 3

if {$fail == 0} { puts "OVERALL: ok"; exit 0 } else { puts "OVERALL: notok"; exit 1 }
