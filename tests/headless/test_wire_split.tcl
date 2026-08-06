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
source [file join [file dirname [info script]] scratch.tcl]

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
set wdir [test_scratch ws_w1]
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

# ===========================================================================
# Phase W3 -- edit-time re-split / rejoin, routed through maintain_wire_segments() with the
# enclosing edit's undo. Deleting the net-label that caused a split must REJOIN the two
# collinear stubs (free, via the W0 pin-aware merge once the pin is gone); placing or drawing
# a new attachment must SPLIT; and undo must restore the pre-edit segment state in one step.
# ===========================================================================

# --- T4: delete a mid-span label -> its two segments rejoin (3 -> 2); undo restores 3. ---
set ::autotrim_wires 1
xschem load $f1
check "W3 T4: load -> 3 segments" [xschem get wires] 3
xschem unselect_all
xschem select instance 0                 ;# l1, the label at x=-50
xschem delete
check "W3 T4: deleting the -50 label rejoins its stubs (3 -> 2)" [xschem get wires] 2
xschem undo
check "W3 T4: undo restores the pre-delete 3 segments" [xschem get wires] 3
check "W3 T4: undo restored the deleted label instance" [xschem get instances] 2

# --- T4 net-invariance: the rejoin must not change connectivity. Fixture keeps the net named
#     (two GB labels), so deleting ONE still leaves the net GB; a resistor R7 taps mid-span. ---
set f5 [file join $wdir res_two_labels.sch]
write_sch $f5 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 -60 110 -60 {}
C {devices/lab_wire} -80 -60 0 0 {name=l1 lab=GB}
C {devices/lab_wire} 80 -60 0 0 {name=l2 lab=GB}
C {devices/res} 0 -30 0 1 {name=R7 m=1 value=320}
}
xschem load $f5
set nmap_pre [xschem instance_nodemap R7]
set nw_pre [xschem get wires]
xschem unselect_all
xschem select instance 0                 ;# l1, the label at x=-80
xschem delete
check "W3 T4: res fixture rejoin drops one segment (l2 still names the net)" \
      [list $nw_pre [xschem get wires]] {4 3}
check "W3 T4: R7 node map unchanged after label delete + rejoin (INV-1)" \
      [xschem instance_nodemap R7] $nmap_pre

# --- T4b: placing a net-label mid-span SPLITS the wire (1 -> 2); undo restores 1. ---
catch {xschem clear force}
set ::autotrim_wires 1
xschem wire -100 0 100 0
check "W3 T4b: one plain wire" [xschem get wires] 1
xschem instance devices/lab_wire 0 0 0 0 {name=lp lab=GB}
check "W3 T4b: placing a mid-span label splits the wire (1 -> 2)" [xschem get wires] 2
xschem undo
check "W3 T4b: undo removes the label and rejoins (2 -> 1)" [xschem get wires] 1
check "W3 T4b: undo removed the placed label" [xschem get instances] 0

# --- T4c: drawing a wire UNDER an existing label splits it at the pin (1 -> 2); undo -> 0. ---
catch {xschem clear force}
set ::autotrim_wires 1
xschem instance devices/lab_wire 0 0 0 0 {name=lp lab=GB}
check "W3 T4c: label placed, no wire yet" [xschem get wires] 0
xschem wire -100 0 100 0
check "W3 T4c: drawing a wire under the label splits at the pin (1 -> 2)" [xschem get wires] 2
xschem undo
check "W3 T4c: undo removes the drawn wire (-> 0)" [xschem get wires] 0

# ===========================================================================
# Phase W5 -- hazard guards. Auto-split must split ONLY at an exact instance-pin coordinate
# (never a projected/snapped near point -- H2) and ONLY at pins, never at a bare wire-wire
# crossing (H3). W1's break_wires_at_attach_points already respects both by construction
# (get_inst_pin_coord + exact touch(), pin-only sweep); these lock it against a regression.
# Each guard is paired with a positive control so the "no split / distinct nets" assertions
# are not vacuous.
# ===========================================================================

# --- T3 (H3): two wires that merely CROSS (neither has an endpoint or a pin at the cross)
#     must NOT split and must stay on TWO distinct nets (splitting there would make 4 stubs
#     meet at the cross and wirecheck would short the two nets). Labels sit at wire ENDPOINTS
#     (not interior) so they name each net without themselves splitting. ---
set ::autotrim_wires 1
set f6 [file join $wdir cross.sch]
write_sch $f6 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 100 0 {}
N 0 -100 0 100 {}
C {devices/lab_wire} -100 0 0 0 {name=lh lab=HH}
C {devices/lab_wire} 0 -100 0 0 {name=lv lab=VV}
}
xschem load $f6
check "W5 T3: bare X-crossing does NOT split (stays 2 wires)" [xschem get wires] 2
if {[xschem get wires] == 2} {
  set netH [xschem net @wire [xschem wire_id 0]]
  set netV [xschem net @wire [xschem wire_id 1]]
  check "W5 T3: crossing wires stay on DISTINCT nets (H3: no false short)" [expr {$netH ne $netV}] 1
}

# --- T3b positive control: a net-label pin placed AT the crossing (0,0) is interior to BOTH
#     wires -> both split (2 -> 4) AND the pin connects all four stubs to one net. Proves the
#     machinery WOULD split+short at (0,0) if there were a real attachment there, so T3's
#     "2 wires / 2 nets" is a genuine no-op, not a dead assertion. ---
set f7 [file join $wdir cross_junction.sch]
write_sch $f7 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 100 0 {}
N 0 -100 0 100 {}
C {devices/lab_wire} 0 0 0 0 {name=lc lab=CC}
}
xschem load $f7
check "W5 T3b: a pin AT the crossing splits BOTH wires (2 -> 4 segments)" [xschem get wires] 4
if {[xschem get wires] == 4} {
  set nets {}
  for {set i 0} {$i < 4} {incr i} { lappend nets [xschem net @wire [xschem wire_id $i]] }
  check "W5 T3b: all 4 segments now share ONE net (the pin connects the junction)" \
        [llength [lsort -unique $nets]] 1
}

# --- T8 (H2): an instance pin NEAR but not exactly on the wire (off by 5) must NOT split it
#     and must NOT connect (a projected/snapped split would silently create a stub + a false
#     connection). Compared against T8b where the SAME label sits EXACTLY on the wire. ---
catch {xschem clear force}
set ::autotrim_wires 1
set f8 [file join $wdir nearmiss.sch]
write_sch $f8 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 100 0 {}
C {devices/lab_wire} 0 5 0 0 {name=ln lab=NEAR}
}
set f8b [file join $wdir exacthit.sch]
write_sch $f8b {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 100 0 {}
C {devices/lab_wire} 0 0 0 0 {name=le lab=NEAR}
}
xschem load $f8
set w_near [xschem get wires]
set net_near [xschem net @wire [xschem wire_id 0]]
xschem load $f8b
set w_exact [xschem get wires]
set net_exact [xschem net @wire [xschem wire_id 0]]
set net_label [xschem net NEAR]
check "W5 T8: near pin -> NO split; exact pin -> split (H2: exact-touch only)" \
      [list $w_near $w_exact] {1 2}
check "W5 T8: near pin does NOT connect (wire net != the NEAR label net)" [expr {$net_near ne $net_label}] 1
check "W5 T8b: exact pin DOES connect (wire net == the NEAR label net)" [expr {$net_exact eq $net_label}] 1

# ===========================================================================
# Phase W6 -- end-to-end integration through the REAL user path: cadence_compat (which
# force-enables autotrim_wires via the cadence_compat_sync write-trace, NOT set directly as the
# earlier phases do). Uses the exact test_wire_splits.sch geometry (wire -100..110 tapped by a
# net-label at -80 and a resistor pin at 0). Asserts the full loop at once: 3 CLICKABLE segments,
# netlist identical to default mode (INV-1), and saveas byte-identical to the coalesced form (D1),
# re-splitting on reload. Self-contained (does not depend on the untracked SANDBOX file); the real
# file is an extra skip-if-absent check.
# ===========================================================================
proc N_line {p} { foreach ln [split [slurp $p] \n] { if {[string match "N *" $ln]} { return $ln } }; return "" }

set f9 [file join $wdir wsplit_real.sch]
write_sch $f9 {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 -60 110 -60 {lab=GB}
C {devices/res} 0 -30 0 1 {name=R7 m=1 value=320}
C {devices/lab_wire} -80 -60 0 0 {name=l8 lab=GB}
}

# Default-mode baseline FIRST (both flags off), before enabling cadence (the cadence->autotrim
# trace is one-directional, so autotrim would otherwise stay latched on).
set ::cadence_compat 0
set ::autotrim_wires 0
xschem load $f9
set nmap_def [xschem instance_nodemap R7]
set nw_def [xschem get wires]
set canon [file join $wdir w6_canon.sch]
xschem saveas $canon schematic          ;# canonical single-N form

# Real user path: flip cadence_compat -> the write-trace must auto-enable autotrim_wires.
set ::cadence_compat 1
check "W6: cadence_compat=1 auto-enables autotrim_wires (write-trace)" [set ::autotrim_wires] 1
xschem load $canon
check "W6: real fixture geometry -> 3 clickable segments under cadence_compat" [xschem get wires] 3
check "W6: split is real vs default mode (1 wire -> 3 segments)" [list $nw_def [xschem get wires]] {1 3}
if {[xschem get wires] == 3} {
  set ids {}
  foreach x {-90 -40 55} { set row [xschem select_at $x -60]; lappend ids [lindex $row 3] }
  check "W6: the 3 inter-attachment regions are 3 distinct clickable wire_ids" \
        [llength [lsort -unique $ids]] 3
}
check "W6: netlist invariant -- R7 node map identical cadence vs default (INV-1)" \
      [xschem instance_nodemap R7] $nmap_def

# D1 round-trip: saveas under cadence must coalesce back to the byte-identical single-N file.
set out [file join $wdir w6_out.sch]
xschem saveas $out schematic
check "W6: coalesce-on-save writes exactly 1 N record" [count_N $out] 1
check "W6: saved N record == the canonical single wire (D1)" [N_line $out] {N -100 -60 110 -60 {lab=GB}}
check "W6: saved .sch byte-identical to the default-mode canonical file (D1)" [slurp $out] [slurp $canon]
xschem load $out
check "W6: round-trip reload re-splits to 3 clickable segments" [xschem get wires] 3

# Extra: the actual untracked SANDBOX artifact, if present (integration on the shipped file).
if {[file exists $realf]} {
  set ::cadence_compat 0; set ::autotrim_wires 0
  xschem load $realf
  set rmap_def [xschem instance_nodemap R7]
  set ::cadence_compat 1
  xschem load $realf
  check "W6 real: SANDBOX test_wire_splits.sch -> 3 segments under cadence" [xschem get wires] 3
  check "W6 real: SANDBOX netlist invariant (R7 nodemap)" [xschem instance_nodemap R7] $rmap_def
  set rout [file join $wdir w6_real_out.sch]
  xschem saveas $rout schematic
  check "W6 real: SANDBOX saveas coalesces to 1 N record" [count_N $rout] 1
} else {
  puts "ok:   W6 real SANDBOX fixture skipped (untracked file absent; self-contained W6 covers it)"
}
set ::cadence_compat 0

# Phase W7 -- moving a mid-span TAP must not drag the through-wire.
# A net-label taps the interior of a wire; the split feature breaks that wire into two
# abutting COLLINEAR segments, each with an endpoint at the tap. Moving the label (the
# cadence stretch+kissing drag) must LEAVE the through-run in place and drop a SINGLE stub
# from the label's new position back to the tap -- not jog the whole run into a U-detour.
# Fix: select.c wire_through_tap_arm() (don't grab a through-run arm) + move.c
# point_is_collinear_pass() (don't slide a wire whose far end is a straight pass-through).
# See doc/claude/specs/wire_segment_splitting.md and doc/claude/FAQ.md.
proc nwire {c} {  ;# canonicalize a wire's endpoint order so {a b x y} == {x y a b}
  lassign $c a b x y
  if {$a > $x || ($a == $x && $b > $y)} { return [list $x $y $a $b] } else { return [list $a $b $x $y] }
}
proc segset {} {
  set n [xschem get wires]; set L {}
  for {set i 0} {$i < $n} {incr i} { lappend L [nwire [xschem wire_coord $i]] }
  return [lsort $L]
}
proc all_wire_nets {} {  ;# resolved net of every wire, deduped -> a single connected net stays {GB}
  xschem resolved_net 0
  set n [xschem get wires]; set S {}
  for {set i 0} {$i < $n} {incr i} { lappend S [xschem getprop wire $i lab] }
  return [lsort -unique $S]
}
proc lab_inst_index {} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq "l8"} { return $i } }
  return -1
}

set ::cadence_compat 1   ;# arms autotrim_wires (split), orthogonal_wiring not needed for the grab guard
set ::autotrim_wires 1; set ::orthogonal_wiring 1; set ::fluid_editing 1; set ::enable_stretch 0

# Fixture = the exact user case: through-wire -100..110, resistor tap at 0 (fixed pin),
# net-label l8 tapping mid-span at -80. Splits into 3 clickable segments at -80 and 0.
catch {xschem clear force}
xschem wire -100 -60 110 -60
xschem instance devices/res 0 -30 0 1 {name=R7 m=1 value=320}
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
check "W7: mid-span tap splits the run into 3 clickable segments" [xschem get wires] 3
set w7_net_before [xschem instance_nodemap R7]

# Move the label up (0,-50) via the faithful cadence drag path (stretch + kissing).
set li [lab_inst_index]
check "W7: label instance located" [expr {$li >= 0}] 1
xschem unselect_all
xschem select instance $li
xschem move_objects 0 -50 stretch kissing

# DESIRED: the through-run stays at y=-60. The pre-fix bug jogged the left arm into a 5-wire
# U-detour; that claim is what W7 exists to defend and it still holds.
#
# RE-AUTHORED for doc/claude/specs/wire_label_ride.md S1 (change #4 + LEASH). This fixture's tap
# is a NET LABEL, and a net label's pin is now a naming anchor rather than copper geometry:
#   - connect_by_kissing() no longer mints the vertical rescue stub -80,-110 -> -80,-60, so the
#     drag creates NO new copper (R1);
#   - the label is projected back onto its owner span at move END (R7), so it returns to
#     (-80,-60) instead of committing off the run;
#   - with the label transiently away from the -80 split point, maintain_wire_segments welds the
#     two collinear halves, leaving the run split only at the RESISTOR pin (0,-60). That weld is
#     transient under autotrim (the next edit re-splits) and it is what S2/change #6 will make
#     permanent.
# Connectivity and the netlist node map are unchanged -- which is the whole point: the stub was
# never what connected the label (name_attached_inst_to_net binds a pin to any wire it touch()es,
# interior included).  A DEVICE-pin tap is untouched by all of this: see W7c below.
check "W7: run intact, no stub, no through-wire drag" [segset] \
  [lsort [list [nwire {0 -60 110 -60}] [nwire {-100 -60 0 -60}]]]
check "W7: exactly 2 wires (pre-fix bug produced 5 = U-detour)" [xschem get wires] 2
check "W7: the leash put the label back on the run" [lrange [xschem instance_pin_coord l8 name p] 1 2] {-80 -60}
check "W7: connectivity preserved -- every wire still on net GB" [all_wire_nets] GB
check "W7: netlist invariant -- R7 node map unchanged by the move (INV-1)" [xschem instance_nodemap R7] $w7_net_before

# Guard: NO segment leaves the y=-60 run -- the label drag extruded no copper at all (R1).
set w7_off 0
foreach w [segset] { lassign $w a b x y; if {$b != -60 || $y != -60} { incr w7_off } }
check "W7: no stub leaves the run (R1)" $w7_off 0

# W7b -- the skip is gated on kissing: a stretch move WITHOUT kissing must NOT leave the
# moved tap disconnected. Without the gate, skipping both through-arms with no stub dropped
# would orphan the label's net. Here the arms are NOT skipped (no kissing) -> they follow ->
# the net stays whole. (Review finding: stretch-without-kissing disconnect.)
catch {xschem clear force}
xschem wire -100 -60 110 -60
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
xschem unselect_all; xschem select instance [lab_inst_index]
xschem move_objects 0 -50 stretch   ;# NO kissing keyword
check "W7b: stretch without kissing keeps the tap connected (single net GB)" [all_wire_nets] GB

# W7c -- 4-way (+) cross tapped by a moving pin stays connected (no orphan/short).
catch {xschem clear force}
xschem wire -100 -60 110 -60
xschem wire -80 -160 -80 40
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
xschem unselect_all; xschem select instance [lab_inst_index]
xschem move_objects 0 -50 stretch kissing
check "W7c: moving a pin at a 4-way cross stays a single connected net" [all_wire_nets] GB

# W7d -- the through-wire guard must be PERPENDICULAR-only: a tap dragged ALONG a rail
# parallel to the move must still SLIDE cleanly (rail stays straight, split point slides),
# not jog. Vertical rail split at (0,0); horizontal wire to a moving label at (200,0); drag
# the label DOWN (parallel to the rail). point_is_collinear_pass must NOT block this slide.
# (Review finding: orientation-blind guard re-introduced the corner-slide jog.)
catch {xschem clear force}
xschem wire 0 -500 0 500
xschem wire 0 0 200 0
xschem instance devices/lab_wire 200 0 0 0 {name=l8 lab=R}
xschem unselect_all; xschem select instance [lab_inst_index]
xschem move_objects 0 -30 stretch kissing
proc segset_norm {} { set n [xschem get wires]; set L {}; for {set i 0} {$i<$n} {incr i} { lappend L [nwire [xschem wire_coord $i]] }; return [lsort $L] }
check "W7d: tap dragged along a parallel rail SLIDES (rail straight, wire follows)" [segset_norm] \
  [lsort [list [nwire {0 -500 0 -30}] [nwire {0 -30 0 500}] [nwire {0 -30 200 -30}]]]
check "W7d: no jog residue -- exactly 3 wires" [xschem get wires] 3

set ::cadence_compat 0

if {$fail == 0} { puts "OVERALL: ok"; exit 0 } else { puts "OVERALL: notok"; exit 1 }
