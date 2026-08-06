# Regression: wire segment splitting (independent click regions between attachment points).
# See doc/claude/specs/wire_segment_splitting.md.
#
# Phase W0 -- the linchpin: trim_wires' collinear-rejoin MERGE must be PIN-AWARE.
# trim_wires (check.c) welds two collinear touching segments when both shared-endpoint
# connection counters (end1/end2) are 0. Those counters count only OTHER WIRES, never
# instance pins -- so it used to merge two segments across a tap, destroying the segment
# boundary the split feature depends on. W0 adds an any_inst_pin_at(x,y) guard so a joint
# carrying a pin is NOT merged (and, once the pin is later removed, IS merged again -> free
# auto-rejoin on delete).
#
# W0-W6 cover the spec's test matrix T1-T8; W7 covers the mid-span-tap drag.
#
# ===========================================================================================
# RE-AUTHORED 2026-08-06 for doc/claude/specs/wire_label_ride.md S2 = R2 (changes #6/#7/#12).
#
# A `type=label` instance's PINLAYER rect is a NAMING ANCHOR, not copper geometry: as of S2 it
# neither splits a wire (break_wires_at_attach_points) nor blocks trim_wires' collinear rejoin
# (any_inst_pin_at's new skip-labels argument). A DEVICE pin still does both, so the feature this
# file tests is intact -- but every fixture here used a `devices/lab_wire` as its split source and
# there was not one `devices/res` tap among them, so the SUITE had to move to device pins to keep
# testing the machinery. That is spec §6 change #12, and it is why this is a re-author and not a
# re-run.
#
# Each phase therefore now has, where it is meaningful, THREE legs:
#   - the device-pin leg   -- the split machinery, unchanged by S2;
#   - the label mirror     -- the S2 claim, that a label does NOT cut but still NAMES;
#   - a `label_splits_wires 1` legacy leg -- the escape hatch must restore the pre-S2 result
#     exactly, so a netlist difference blamed on S2 has a switch rather than a bisect.
# Phase S2 at the end holds the claims that are new rather than amended, including the netlist
# bug §4.4 measured and this stage fixes.
#
# res.sym geometry used throughout: pins P=(X,Y-30) and M=(X,Y+30) for an instance at (X,Y),
# rot 0 flip 0. So `devices/res` at (X, T+30) taps (X,T) with P and dangles M at (X,T+60);
# every fixture below keeps that M coordinate clear of other copper on purpose.
# ===========================================================================================
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

# a devices/res whose P pin taps exactly (X,T); M dangles at (X,T+60)
proc res_tap {X T name} { xschem instance devices/res $X [expr {$T + 30}] 0 0 "name=$name m=1 value=320" }
# ... and the same as a .sch record line
proc res_line {X T name} { return "C {devices/res} $X [expr {$T + 30}] 0 0 {name=$name m=1 value=320}" }
# resolved net name of wire i. `resolved_net 0` back-annotates lab= on every wire; a bare
# `resolved_net` would stamp the SELECTED net onto all of them and hide a real difference
# (WIRING.md §10, net readback).
proc wire_net {i} { xschem resolved_net 0; return [xschem getprop wire $i lab] }

set ::label_splits_wires 0      ;# S2 default, restated so a phase that flips it must restore it

# Build a fresh sheet with two collinear abutting horizontal wires meeting at (jx,-60), built
# with autotrim OFF so construction never merges them prematurely, then run one trim_wires with
# autotrim ON. `what` places the attachment sitting exactly at the joint:
#   none  -> nothing            label -> devices/lab_wire (pin centred on the placement coord)
#   dev   -> devices/res P pin
proc build_two_segments {jx what} {
  catch {xschem clear force}
  set ::autotrim_wires 0
  xschem wire -100 -60 $jx -60
  xschem wire $jx -60 100 -60
  if {$what eq "label"} { xschem instance devices/lab_wire $jx -60 0 0 "name=l1 lab=GB" }
  if {$what eq "dev"}   { res_tap $jx -60 RJ }
}

if {[catch {xschem clear force} e]} { bail "no xschem command / clear failed: $e" }

# --- Positive control: WITHOUT an attachment at the joint, trim_wires MUST still merge the two
#     collinear segments into one. Proves the merge machinery is intact (must stay GREEN
#     before and after the W0 fix; guards against a fix that just disables merging). ---
build_two_segments 0 none
check "W0 control: 2 segments built (no attachment)" [xschem get wires] 2
set ::autotrim_wires 1
xschem trim_wires
check "W0 control: collinear segments merge with no pin at joint" [xschem get wires] 1

# --- W0 anchor: WITH a DEVICE pin exactly at the joint, trim_wires must NOT merge.
#     (Pre-W0, the pin-blind merge yielded 1.) Re-aimed from a net label onto a resistor for
#     S2 -- the pin-aware merge is a DEVICE-pin rule now, and this is where that is pinned. ---
build_two_segments 0 dev
check "W0: 2 segments + device tap built" [xschem get wires] 2
check "W0: resistor instance placed" [expr {[xschem get instances] >= 1}] 1
set ::autotrim_wires 1
xschem trim_wires
check "W0: no merge across a joint carrying a DEVICE pin" [xschem get wires] 2

# --- Secondary: the two segments must be DISTINCT stable wire_ids (not one object). ---
if {[xschem get wires] == 2} {
  set id0 [xschem wire_id 0]
  set id1 [xschem wire_id 1]
  check "W0: the two segments are distinct wire_ids" [expr {$id0 ne $id1}] 1
}

# --- W0/S2: a NET LABEL at the joint is NOT a boundary -- the halves re-weld (R2, change #7).
#     This is the only LIVE consumer of any_inst_pin_at(): merge_collinear_wires' pin-aware arm
#     is unreachable on the current call graph (its sole caller, save.c, is pin-blind), so the
#     skip-labels argument is exercised HERE and nowhere else. Sabotage: revert change #7 alone
#     and this goes red while everything else stays green -- which is the permanent-fragment bug
#     the two changes exist to prevent together. ---
build_two_segments 0 label
set ::autotrim_wires 1
xschem trim_wires
check "W0/S2: two halves meeting at a NET LABEL re-weld (R2)" [xschem get wires] 1
check "W0/S2: ... and the welded run still carries the label's name" \
      [wire_net 0] GB
# legacy leg: the escape hatch restores the pre-S2 refusal exactly.
build_two_segments 0 label
set ::autotrim_wires 1; set ::label_splits_wires 1
xschem trim_wires
check "W0/S2 legacy: label_splits_wires 1 -> no weld across the label" [xschem get wires] 2
set ::label_splits_wires 0

# --- W0/D2 gate: with the feature OFF (autotrim_wires 0) trim_wires keeps its ORIGINAL
#     behavior and DOES merge across a pin -- default mode is byte-for-byte unchanged. The
#     pin-aware guard is gated on autotrim_wires; this catches a regression that would let
#     the guard alter default trim/join. (Same fixture: OFF -> 1, ON -> 2 above.) ---
build_two_segments 0 dev
set ::autotrim_wires 0
xschem trim_wires
check "W0/D2: default mode (autotrim off) still merges across a pin" [xschem get wires] 1

# ===========================================================================
# Phase W1 -- read-time split at attachment points.
# Loading a .sch with autotrim_wires on must split each wire at every interior
# attachment point into independent in-memory segments.
# Fixture: one wire -100..100 (y=0) with two resistor P pins tapping it at x=-50 and x=+50.
# Expect 3 segments after load. The label mirror (same geometry, lab_wire taps) asserts the S2
# rule: no split, and the wire still gets the name.
# ===========================================================================
proc write_sch {path body} { set fd [open $path w]; puts -nonewline $fd $body; close $fd }
set wdir [test_scratch ws_w1]
set hdr "v {xschem version=3.4.8RC file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nF {}\nE {}\n"

# f1d -- two DEVICE taps: the splitting fixture.
set f1d [file join $wdir two_taps.sch]
write_sch $f1d "${hdr}N -100 0 100 0 {}\n[res_line -50 0 R1]\n[res_line 50 0 R2]\n"
# f1 -- two NET LABEL taps, same geometry: the S2 mirror, and the default-mode byte-stability
#       fixture used by W4 T7.
set f1 [file join $wdir two_labels.sch]
write_sch $f1 "${hdr}N -100 0 100 0 {}\nC {devices/lab_wire} -50 0 0 0 {name=l1 lab=GB}\nC {devices/lab_wire} 50 0 0 0 {name=l2 lab=GB}\n"

set ::autotrim_wires 1
if {[catch {xschem load $f1d} e]} { bail "W1 load fixture: $e" }
check "W1 T1: 1 wire + 2 mid-span device taps -> 3 segments" [xschem get wires] 3
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

# W1/S2 mirror -- the same geometry tapped by two NET LABELS stays ONE clickable wire (R2), and
# the label still names it. Both facts matter: the split was never what made the connection
# (name_attached_inst_to_net binds a pin to any wire it touch()es, interior included).
xschem load $f1
check "W1/S2: two mid-span NET LABELS do not split (1 wire)" [xschem get wires] 1
check "W1/S2: ... a click anywhere on the run hits that one wire" \
      [lindex [xschem select_at -75 0] 3] [xschem wire_id 0]
check "W1/S2: ... and the run is still named by the labels" \
      [wire_net 0] GB
set ::label_splits_wires 1
xschem load $f1
check "W1/S2 legacy: label_splits_wires 1 -> 3 segments again" [xschem get wires] 3
set ::label_splits_wires 0

# ===========================================================================
# Phase W2 -- connectivity / netlist invariance (INV-1).
# Splitting a wire into collinear touching segments must NOT change which nodes exist,
# which pins are on which node, or the auto #netN numbering. Fixture: a resistor R7
# whose P pin taps a wire mid-span, plus a net label naming that wire. Load split OFF then ON
# and assert the instance node map is byte-identical -- while proving the split actually
# happened, so the invariance is not vacuous.
# Under S2 the ON case yields 2 segments (the resistor tap only), not 3: the label names the
# net without cutting it. INV-1 is asserted across BOTH the split difference and that change.
# ===========================================================================
set f2 [file join $wdir res_label.sch]
write_sch $f2 "${hdr}N -100 -60 110 -60 {}\nC {devices/lab_wire} -80 -60 0 0 {name=l8 lab=GB}\nC {devices/res} 0 -30 0 1 {name=R7 m=1 value=320}\n"
proc load_at {file at} { set ::autotrim_wires $at; xschem load $file }

load_at $f2 0
set nmap_off [xschem instance_nodemap R7]
set nwire_off [xschem get wires]
load_at $f2 1
set nmap_on [xschem instance_nodemap R7]
set nwire_on [xschem get wires]

check "W2 T2: the device tap still splits (1 wire -> 2 segments)" [list $nwire_off $nwire_on] {1 2}
check "W2 T2: R7 node map byte-identical split OFF vs ON (INV-1)" $nmap_on $nmap_off
check "W2 T2: R7.P taps net GB through the split" [lindex $nmap_on 2] GB
# and the same file under the escape hatch: 3 segments, SAME node map -- INV-1 holds across the
# S2 switch too, which is the load-bearing claim behind "connectivity-neutral" (spec §9).
set ::label_splits_wires 1
xschem load $f2
check "W2 T2 legacy: label_splits_wires 1 -> 3 segments" [xschem get wires] 3
check "W2 T2 legacy: R7 node map STILL identical (S2 is connectivity-neutral here)" \
      [xschem instance_nodemap R7] $nmap_off
set ::label_splits_wires 0

# Optional integration on the real sandbox fixture -- SKIP (not fail) if it is absent,
# since it is an untracked SANDBOX file not shipped with these commits.
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here .. ..]]
set realf [file join $root xschem_libs_newsym SANDBOX test_wire_splits schematic test_wire_splits.sch]
if {[file exists $realf]} {
  load_at $realf 1
  check "W2 integration: real test_wire_splits.sch -> 2 segments (device tap only)" [xschem get wires] 2
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

# Canonical baseline: render f1d (1 wire -100..100 + 2 device taps) with split OFF -> exactly 1 N
# record, in xschem's precise on-disk form. This is the byte target D1 must reproduce.
set base [file join $wdir w4_base.sch]
set ::autotrim_wires 0
xschem load $f1d
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

# T6b -- prop divergence: split a wire at a DEVICE pin (2 segments), diverge ONE segment's
# prop; coalesce must REFUSE to merge across the real difference -> 2 records persist (H7).
set f3d [file join $wdir one_tap.sch]
write_sch $f3d "${hdr}N -100 20 100 20 {}\n[res_line 0 20 R9]\n"
set ::autotrim_wires 1
xschem load $f3d
check "W4 T6b: one wire + mid-span device tap -> 2 segments" [xschem get wires] 2
xschem setprop wire 0 lab XX
set d3 [file join $wdir w4_diverge.sch]
xschem saveas $d3 schematic
check "W4 T6b: divergent-prop segments NOT coalesced (2 N records persist)" [count_N $d3] 2
# control (non-vacuous): same fixture, NO divergence -> coalesces to 1.
xschem load $f3d
set d3b [file join $wdir w4_conv.sch]
xschem saveas $d3b schematic
check "W4 T6b control: same fixture, no divergence -> coalesces to 1 N" [count_N $d3b] 1

# T6c -- a genuine T-junction (a 3rd wire's ENDPOINT lands mid-span) is a real connection
# node: coalesce must NOT weld the two collinear halves across it (spec 6.3: "no 3rd-wire
# endpoint at the joint"). This preserves trim_wires' in-memory split and matches pre-W4
# autotrim save behaviour -- W4 only re-joins ITS OWN attachment-pin splits, not T-splits.
set f4 [file join $wdir tee.sch]
write_sch $f4 "${hdr}N -100 -20 100 -20 {}\nN 0 -80 0 -20 {}\n"
set ::autotrim_wires 1
xschem load $f4
check "W4 T6c: autotrim load splits the horizontal at the T (3 wires)" [xschem get wires] 3
set t4 [file join $wdir w4_tee.sch]
xschem saveas $t4 schematic
check "W4 T6c: coalesce keeps the T split (3 N records; no weld across a 3rd-wire endpoint)" \
      [count_N $t4] 3

# ===========================================================================
# Phase W3 -- edit-time re-split / rejoin, routed through maintain_wire_segments() with the
# enclosing edit's undo. Deleting the attachment that caused a split must REJOIN the two
# collinear stubs (free, via the W0 pin-aware merge once the pin is gone); placing or drawing
# a new attachment must SPLIT; and undo must restore the pre-edit segment state in one step.
# ===========================================================================

# --- T4: delete a mid-span device tap -> its two segments rejoin (3 -> 2); undo restores 3. ---
set ::autotrim_wires 1
xschem load $f1d
check "W3 T4: load -> 3 segments" [xschem get wires] 3
xschem unselect_all
xschem select instance 0                 ;# R1, the resistor at x=-50
xschem delete
check "W3 T4: deleting the -50 tap rejoins its stubs (3 -> 2)" [xschem get wires] 2
xschem undo
check "W3 T4: undo restores the pre-delete 3 segments" [xschem get wires] 3
check "W3 T4: undo restored the deleted instance" [xschem get instances] 2

# --- T4/S2 net-invariance: deleting one of two NET LABELS must not change the segment count
#     (there was never a split to rejoin) and must not change connectivity -- the surviving
#     label still names the run, and the resistor's node map is untouched. ---
set f5 [file join $wdir res_two_labels.sch]
write_sch $f5 "${hdr}N -100 -60 110 -60 {}\nC {devices/lab_wire} -80 -60 0 0 {name=l1 lab=GB}\nC {devices/lab_wire} 80 -60 0 0 {name=l2 lab=GB}\nC {devices/res} 0 -30 0 1 {name=R7 m=1 value=320}\n"
xschem load $f5
set nmap_pre [xschem instance_nodemap R7]
set nw_pre [xschem get wires]
xschem unselect_all
xschem select instance 0                 ;# l1, the label at x=-80
xschem delete
check "W3 T4/S2: deleting one label changes no segment count (2 -> 2)" \
      [list $nw_pre [xschem get wires]] {2 2}
check "W3 T4/S2: R7 node map unchanged after label delete (INV-1)" \
      [xschem instance_nodemap R7] $nmap_pre
# legacy leg: pre-S2 this fixture was 4 segments and the delete rejoined one pair.
set ::label_splits_wires 1
xschem load $f5
set nw_pre_l [xschem get wires]
xschem unselect_all; xschem select instance 0; xschem delete
check "W3 T4 legacy: label delete rejoined its stubs (4 -> 3)" \
      [list $nw_pre_l [xschem get wires]] {4 3}
check "W3 T4 legacy: R7 node map unchanged by the rejoin (INV-1)" \
      [xschem instance_nodemap R7] $nmap_pre
set ::label_splits_wires 0

# --- T4b: placing a mid-span DEVICE tap SPLITS the wire (1 -> 2); undo restores 1. ---
catch {xschem clear force}
set ::autotrim_wires 1
xschem wire -100 0 100 0
check "W3 T4b: one plain wire" [xschem get wires] 1
res_tap 0 0 RP
check "W3 T4b: placing a mid-span device tap splits the wire (1 -> 2)" [xschem get wires] 2
xschem undo
check "W3 T4b: undo removes the tap and rejoins (2 -> 1)" [xschem get wires] 1
check "W3 T4b: undo removed the placed instance" [xschem get instances] 0

# --- T4b/S2 mirror: placing a mid-span NET LABEL must NOT split, and must still name the run. ---
catch {xschem clear force}
set ::autotrim_wires 1
xschem wire -100 0 100 0
xschem instance devices/lab_wire 0 0 0 0 {name=lp lab=GB}
check "W3 T4b/S2: placing a mid-span label does NOT split (still 1)" [xschem get wires] 1
check "W3 T4b/S2: ... and it names the run anyway" \
      [wire_net 0] GB
xschem undo
check "W3 T4b/S2: undo removes the label" [xschem get instances] 0

# --- T4c: drawing a wire UNDER an existing device tap splits it at the pin (1 -> 2); undo -> 0. ---
catch {xschem clear force}
set ::autotrim_wires 1
res_tap 0 0 RP
check "W3 T4c: tap placed, no wire yet" [xschem get wires] 0
xschem wire -100 0 100 0
check "W3 T4c: drawing a wire under the tap splits at the pin (1 -> 2)" [xschem get wires] 2
xschem undo
check "W3 T4c: undo removes the drawn wire (-> 0)" [xschem get wires] 0

# --- T4c/S2 mirror: drawing a wire under an existing NET LABEL must not split it. ---
catch {xschem clear force}
set ::autotrim_wires 1
xschem instance devices/lab_wire 0 0 0 0 {name=lp lab=GB}
xschem wire -100 0 100 0
check "W3 T4c/S2: drawing a wire under a label does NOT split (1 wire)" [xschem get wires] 1

# ===========================================================================
# Phase W5 -- hazard guards. Auto-split must split ONLY at an exact instance-pin coordinate
# (never a projected/snapped near point -- H2) and ONLY at pins, never at a bare wire-wire
# crossing (H3). break_wires_at_attach_points respects both by construction
# (get_inst_pin_coord + exact touch(), pin-only sweep); these lock it against a regression.
# Each guard is paired with a positive control so the "no split / distinct nets" assertions
# are not vacuous. The positive controls use DEVICE pins as of S2 -- a label no longer splits,
# so a label control would be vacuous in the other direction.
# ===========================================================================

# --- T3 (H3): two wires that merely CROSS (neither has an endpoint or a pin at the cross)
#     must NOT split and must stay on TWO distinct nets (splitting there would make 4 stubs
#     meet at the cross and wirecheck would short the two nets). Labels sit at wire ENDPOINTS
#     (not interior) so they name each net without themselves splitting -- true in both
#     label_splits_wires settings, which is why this fixture needed no re-authoring. ---
set ::autotrim_wires 1
set f6 [file join $wdir cross.sch]
write_sch $f6 "${hdr}N -100 0 100 0 {}\nN 0 -100 0 100 {}\nC {devices/lab_wire} -100 0 0 0 {name=lh lab=HH}\nC {devices/lab_wire} 0 -100 0 0 {name=lv lab=VV}\n"
xschem load $f6
check "W5 T3: bare X-crossing does NOT split (stays 2 wires)" [xschem get wires] 2
if {[xschem get wires] == 2} {
  set netH [xschem net @wire [xschem wire_id 0]]
  set netV [xschem net @wire [xschem wire_id 1]]
  check "W5 T3: crossing wires stay on DISTINCT nets (H3: no false short)" [expr {$netH ne $netV}] 1
}

# --- T3b positive control: a DEVICE pin placed AT the crossing (0,0) is interior to BOTH
#     wires -> both split (2 -> 4) AND the pin connects all four stubs to one net. Proves the
#     machinery WOULD split+short at (0,0) if there were a real attachment there, so T3's
#     "2 wires / 2 nets" is a genuine no-op, not a dead assertion.
#     The vertical wire is shortened to y=+40 so the resistor's M pin at (0,60) dangles clear
#     of it -- otherwise M would tap the vertical too and split it a second time. ---
set f7d [file join $wdir cross_junction_dev.sch]
write_sch $f7d "${hdr}N -100 0 100 0 {}\nN 0 -100 0 40 {}\n[res_line 0 0 RC]\n"
xschem load $f7d
check "W5 T3b: a DEVICE pin AT the crossing splits BOTH wires (2 -> 4 segments)" [xschem get wires] 4
if {[xschem get wires] == 4} {
  set nets {}
  for {set i 0} {$i < 4} {incr i} { lappend nets [xschem net @wire [xschem wire_id $i]] }
  check "W5 T3b: all 4 segments now share ONE net (the pin connects the junction)" \
        [llength [lsort -unique $nets]] 1
}

# --- T3c/S2: the SAME geometry with a NET LABEL at the crossing does NOT split, so the two
#     wires stay two objects. They do share a net here -- but by NAMING, not by geometry: the
#     label's lab=CC is applied to every wire its pin touch()es. Phase S2d below is the case
#     that separates the two mechanisms, with an EMPTY lab=. ---
set f7 [file join $wdir cross_junction.sch]
write_sch $f7 "${hdr}N -100 0 100 0 {}\nN 0 -100 0 100 {}\nC {devices/lab_wire} 0 0 0 0 {name=lc lab=CC}\n"
xschem load $f7
check "W5 T3c/S2: a NET LABEL at the crossing splits nothing (2 wires)" [xschem get wires] 2
set ::label_splits_wires 1
xschem load $f7
check "W5 T3c legacy: label_splits_wires 1 splits both (4 segments)" [xschem get wires] 4
set ::label_splits_wires 0

# --- T8 (H2): an instance pin NEAR but not exactly on the wire (off by 5) must NOT split it
#     and must NOT connect (a projected/snapped split would silently create a stub + a false
#     connection). Compared against T8b where the SAME pin sits EXACTLY on the wire. A net
#     label at the wire's ENDPOINT names the run so there is something to compare against. ---
catch {xschem clear force}
set ::autotrim_wires 1
set namer "C {devices/lab_wire} -100 0 0 0 {name=le lab=NEAR}"
set f8 [file join $wdir nearmiss.sch]
write_sch $f8 "${hdr}N -100 0 100 0 {}\n$namer\n[res_line 0 5 RN]\n"
set f8b [file join $wdir exacthit.sch]
write_sch $f8b "${hdr}N -100 0 100 0 {}\n$namer\n[res_line 0 0 RN]\n"
xschem load $f8
set w_near [xschem get wires]
set node_near [lindex [xschem instance_nodemap RN] 2]
xschem load $f8b
set w_exact [xschem get wires]
set node_exact [lindex [xschem instance_nodemap RN] 2]
check "W5 T8: near pin -> NO split; exact pin -> split (H2: exact-touch only)" \
      [list $w_near $w_exact] {1 2}
check "W5 T8: near pin does NOT connect (RN.P is not on net NEAR)" [expr {$node_near ne "NEAR"}] 1
check "W5 T8b: exact pin DOES connect (RN.P is on net NEAR)" [expr {$node_exact eq "NEAR"}] 1

# --- T8/S2 mirror: the same exact/near distinction still governs a LABEL's NAMING, which is
#     the half of a label's behaviour S2 keeps. Neither case splits. ---
set fl8 [file join $wdir nearlabel.sch]
write_sch $fl8 "${hdr}N -100 0 100 0 {}\nC {devices/lab_wire} 0 5 0 0 {name=ln lab=NEAR}\n"
set fl8b [file join $wdir exactlabel.sch]
write_sch $fl8b "${hdr}N -100 0 100 0 {}\nC {devices/lab_wire} 0 0 0 0 {name=le lab=NEAR}\n"
xschem load $fl8
xschem resolved_net 0
check "W5 T8/S2: a label 5 units OFF the wire neither splits nor names it" \
      [list [xschem get wires] [expr {[xschem getprop wire 0 lab] eq "NEAR"}]] {1 0}
xschem load $fl8b
xschem resolved_net 0
check "W5 T8b/S2: a label EXACTLY on the wire names it without splitting it (R2)" \
      [list [xschem get wires] [xschem getprop wire 0 lab]] {1 NEAR}

# ===========================================================================
# Phase W6 -- end-to-end integration through the REAL user path: cadence_compat (which
# force-enables autotrim_wires via the cadence_compat_sync write-trace, NOT set directly as the
# earlier phases do). Uses the exact test_wire_splits.sch geometry (wire -100..110 tapped by a
# net-label at -80 and a resistor pin at 0). Asserts the full loop at once: the clickable
# segments, netlist identical to default mode (INV-1), and saveas byte-identical to the coalesced
# form (D1), re-splitting on reload. Self-contained (does not depend on the untracked SANDBOX
# file); the real file is an extra skip-if-absent check.
# S2: that geometry now yields 2 segments, not 3 -- the resistor tap is the only cut. This is the
# exact user-visible loss spec §9 lists first: per-segment click granularity AT A NET LABEL,
# cadence_compat only. The resistor's boundary is untouched, which is the point.
# ===========================================================================
proc N_line {p} { foreach ln [split [slurp $p] \n] { if {[string match "N *" $ln]} { return $ln } }; return "" }

set f9 [file join $wdir wsplit_real.sch]
write_sch $f9 "${hdr}N -100 -60 110 -60 {lab=GB}\nC {devices/res} 0 -30 0 1 {name=R7 m=1 value=320}\nC {devices/lab_wire} -80 -60 0 0 {name=l8 lab=GB}\n"

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
check "W6: real fixture geometry -> 2 clickable segments under cadence_compat" [xschem get wires] 2
check "W6: split is real vs default mode (1 wire -> 2 segments)" [list $nw_def [xschem get wires]] {1 2}
if {[xschem get wires] == 2} {
  set ids {}
  foreach x {-40 55} { set row [xschem select_at $x -60]; lappend ids [lindex $row 3] }
  check "W6: the 2 inter-attachment regions are 2 distinct clickable wire_ids" \
        [llength [lsort -unique $ids]] 2
  # the LABEL's own tap at x=-80 is no longer a click boundary (spec §9 loss 1): a click just
  # left of it and one just right of it now hit the SAME segment.
  check "W6/S2: clicks either side of the label hit ONE segment (granularity given up)" \
        [expr {[lindex [xschem select_at -90 -60] 3] eq [lindex [xschem select_at -40 -60] 3]}] 1
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
check "W6: round-trip reload re-splits to 2 clickable segments" [xschem get wires] 2

# Extra: the actual untracked SANDBOX artifact, if present (integration on the shipped file).
if {[file exists $realf]} {
  set ::cadence_compat 0; set ::autotrim_wires 0
  xschem load $realf
  set rmap_def [xschem instance_nodemap R7]
  set ::cadence_compat 1
  xschem load $realf
  check "W6 real: SANDBOX test_wire_splits.sch -> 2 segments under cadence" [xschem get wires] 2
  check "W6 real: SANDBOX netlist invariant (R7 nodemap)" [xschem instance_nodemap R7] $rmap_def
  set rout [file join $wdir w6_real_out.sch]
  xschem saveas $rout schematic
  check "W6 real: SANDBOX saveas coalesces to 1 N record" [count_N $rout] 1
} else {
  puts "ok:   W6 real SANDBOX fixture skipped (untracked file absent; self-contained W6 covers it)"
}
set ::cadence_compat 0

# Phase W7 -- moving a mid-span TAP must not drag the through-wire.
# A net-label taps the interior of a wire; moving the label (the cadence stretch+kissing drag)
# must LEAVE the through-run in place -- not jog the whole run into a U-detour.
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
# net-label l8 tapping mid-span at -80. Under S2 only the RESISTOR cuts it -> 2 segments.
catch {xschem clear force}
xschem wire -100 -60 110 -60
xschem instance devices/res 0 -30 0 1 {name=R7 m=1 value=320}
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
check "W7: the device tap alone splits the run into 2 clickable segments" [xschem get wires] 2
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
# is a NET LABEL, and a net label's pin is a naming anchor rather than copper geometry:
#   - connect_by_kissing() no longer mints the vertical rescue stub -80,-110 -> -80,-60, so the
#     drag creates NO new copper (R1);
#   - the label is projected back onto its owner span at move END (R7), so it returns to
#     (-80,-60) instead of committing off the run.
# AMENDED for S2 (change #6): the run was never split at -80 to begin with, so S1's transient
# weld of the two halves is now simply the resting state. Every post-drag assertion below is
# byte-identical to the S1 result.
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

# W7b -- a stretch move WITHOUT kissing.  RE-AUTHORED FOR S2, AND IT IS A REAL BEHAVIOUR CHANGE,
# recorded here rather than smoothed over.
#
# What this used to assert: that the moved tap stays connected. It did, but by ACCIDENT -- the
# label split the run at -80, so the label's pin coincided with the two halves' shared ENDPOINT,
# and select_attached_nets()' ELEMENT arm (which fires only on `endpoint_near`) grabbed both
# halves and stretched them to follow. Remove the split and the label is strictly INTERIOR, that
# arm never fires (exactly what spec §6 change #11 predicts), the gesture does not arm kissing so
# there is no stub, and the LEASH is deliberately gated on connect_by_kissing (§14.6, policy
# pinned by test_label_ride.tcl K1/K2) -- so the label commits off copper and the run loses its
# name.
#
# This is the SAME root cause as the strand-oracle D1 case: the split was masking two separate
# endpoint-keyed rescues (this ELEMENT arm, and connect_by_kissing's wire-endpoint tether), and
# S2 removes the mask for both. It is not a new defect class -- a stock-config user (autotrim
# off, no split, ever) has had this exact result all along. RIDE (S3) is what closes it.
# Measured 2026-08-06; the legacy leg below keeps the escape hatch's promise honest.
catch {xschem clear force}
xschem wire -100 -60 110 -60
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
xschem unselect_all; xschem select instance [lab_inst_index]
xschem move_objects 0 -50 stretch   ;# NO kissing keyword
check "W7b/S2: stretch without kissing strands the tap (mask removed, S3 owed)" \
      [all_wire_nets] [list "#net1"]
check "W7b/S2: ... and the run itself is untouched (no copper invented)" [segset] \
      [list [nwire {-100 -60 110 -60}]]
set ::label_splits_wires 1
catch {xschem clear force}
xschem wire -100 -60 110 -60
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
xschem unselect_all; xschem select instance [lab_inst_index]
xschem move_objects 0 -50 stretch
check "W7b legacy: label_splits_wires 1 restores the endpoint-arm rescue (net GB)" \
      [all_wire_nets] GB
set ::label_splits_wires 0

# W7c -- 4-way (+) cross tapped by a moving label stays on one net (no orphan/short). Under S2
# the cross is not split, so the two wires are two objects joined only by the label's NAME -- and
# the leash must still return the label to its owner run for that to hold.
catch {xschem clear force}
xschem wire -100 -60 110 -60
xschem wire -80 -160 -80 40
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
xschem unselect_all; xschem select instance [lab_inst_index]
xschem move_objects 0 -50 stretch kissing
check "W7c: moving a label at a 4-way cross stays a single named net" [all_wire_nets] GB

# W7d -- the through-wire guard must be PERPENDICULAR-only: a tap dragged ALONG a rail
# parallel to the move must still SLIDE cleanly (rail stays straight, split point slides),
# not jog. Vertical rail split at (0,0); horizontal wire to a moving label at (200,0); drag
# the label DOWN (parallel to the rail). point_is_collinear_pass must NOT block this slide.
# (Review finding: orientation-blind guard re-introduced the corner-slide jog.)
# The label sits at a wire ENDPOINT here, so S2 changes nothing: the rail's split at (0,0) is a
# T-junction driven by the horizontal wire's ENDPOINT, not by any pin.
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

# ===========================================================================
# Phase S2 -- doc/claude/specs/wire_label_ride.md R2: a net label NAMES copper, it does not CUT
# it. The claims here are new rather than amended, and each is stated so that exactly one of
# changes #6 / #7 can make it fail:
#   S2a  the merge side (#7, check.c any_inst_pin_at skip-labels) -- the LIVE consumer
#   S2b  the splitter side (#6, break_wires_at_attach_points)
#   S2c  nothing new reaches disk (spec §12.3, already settled -- asserted, not re-measured)
#   S2d  the netlist bug this stage FIXES (spec §4.4). The only intentional netlist change in S2.
#   S2e  `label_splits_wires` is inert in default mode -- its own gate, not a reuse of the
#        autotrim gate (spec D2 stays load-bearing)
# ===========================================================================
set ::cadence_compat 0
set ::autotrim_wires 1
set ::label_splits_wires 0

# --- S2a: the merge. Two abutting collinear wires meeting at a label re-weld; a DEVICE pin at
#     the same joint still refuses. Sabotage: revert #7 only -> the first goes red, the second
#     stays green, and a wire split at a label could never re-weld again. ---
build_two_segments 0 label
set ::autotrim_wires 1; xschem trim_wires
check "S2a: label joint welds"            [xschem get wires] 1
build_two_segments 0 dev
set ::autotrim_wires 1; xschem trim_wires
check "S2a: device joint still refuses"   [xschem get wires] 2

# --- S2b: the splitter. Sabotage: revert #6 only -> the label split returns; on a plain single
#     wire trim's now-label-blind merge immediately welds it back so the count looks right, but
#     the CROSSING case below cannot be welded (four wire endpoints meet at the joint, so
#     end1/end2 != 0 and the merge is refused) and goes red. ---
catch {xschem clear force}
set ::autotrim_wires 1
xschem wire -100 0 100 0
xschem instance devices/lab_wire 0 0 0 0 {name=l1 lab=GB}
check "S2b: mid-span label leaves one wire"  [xschem get wires] 1
check "S2b: ... spanning the whole run"      [segset] [list [nwire {-100 0 100 0}]]
catch {xschem clear force}
xschem wire -100 0 100 0
xschem wire 0 -100 0 100
xschem instance devices/lab_wire 0 0 0 0 {name=l1 lab=GB}
check "S2b: a label at a CROSSING splits neither wire" [xschem get wires] 2

# --- S2c: nothing new reaches disk. save_wire() coalesces PIN-BLIND (ignore_pins=1), so the
#     label split never persisted and no golden is owed either way (spec §12.3, SETTLED). Assert
#     both settings write the same single N record from the same source file. ---
set fs2 [file join $wdir s2_disk.sch]
write_sch $fs2 "${hdr}N -100 0 200 0 {}\nC {devices/lab_wire} 0 0 0 0 {name=l1 lab=GB}\n"
set o0 [file join $wdir s2_disk_off.sch]; set o1 [file join $wdir s2_disk_on.sch]
set ::label_splits_wires 0; xschem load $fs2; xschem saveas $o0 schematic
set ::label_splits_wires 1; xschem load $fs2; xschem saveas $o1 schematic
set ::label_splits_wires 0
check "S2c: one N record on disk either way" [list [count_N $o0] [count_N $o1]] {1 1}
check "S2c: ... byte-identical files (no golden regeneration owed)" [slurp $o0] [slurp $o1]

# --- S2d: THE NETLIST FIX (spec §4.4), and the only intentional netlist change in S2.
#     Splitting BOTH wires at a shared crossing gives four segments a COINCIDENT ENDPOINT, and
#     coincident endpoints ARE connectivity (wirecheck, netlist.c) -- so a label whose lab= is
#     EMPTY, which names nothing at all, silently merged two independent nets. Measured, and it
#     is the strongest argument for this stage.
#     Fixture: two crossing wires, an empty-lab= lab_wire at the crossing, four resistors tapping
#     the four wire ENDPOINTS (endpoint taps never split, so the label is the only interior
#     attachment). RH1/RH2 sit on the horizontal, RV1/RV2 on the vertical -- RV1 taps with M and
#     RV2 with P so that every dangling pin stays clear of the copper. ---
proc s2d_fixture {} {
  catch {xschem clear force}
  set ::autotrim_wires 1
  xschem wire -200 0 200 0
  xschem wire 0 -200 0 200
  xschem instance devices/res -200 30 0 0 {name=RH1 m=1 value=320}   ;# P -> (-200,0)
  xschem instance devices/res 200 30 0 0 {name=RH2 m=1 value=320}    ;# P -> ( 200,0)
  xschem instance devices/res 0 -230 0 0 {name=RV1 m=1 value=320}    ;# M -> (0,-200)
  xschem instance devices/res 0 230 0 0 {name=RV2 m=1 value=320}     ;# P -> (0, 200)
  xschem instance devices/lab_wire 0 0 0 0 {name=lc lab=}            ;# EMPTY lab: names nothing
}
s2d_fixture
# fixture self-check: the four taps really are where the comment says (guards a silent
# res.sym geometry change from making the whole case vacuous)
check "S2d fixture: RH1.P taps the horizontal at (-200,0)" [lrange [xschem instance_pin_coord RH1 name P] 1 2] {-200 0}
check "S2d fixture: RV1.M taps the vertical at (0,-200)"   [lrange [xschem instance_pin_coord RV1 name M] 1 2] {0 -200}
check "S2d: no split at the crossing (2 wires)" [xschem get wires] 2
set s2d_h [lindex [xschem instance_nodemap RH1] 2]
set s2d_v [lindex [xschem instance_nodemap RV2] 2]
check "S2d: horizontal and vertical stay on DISTINCT nets (the fix)" [expr {$s2d_h ne $s2d_v}] 1
# non-vacuous control: the escape hatch reproduces the bug exactly.
set ::label_splits_wires 1
s2d_fixture
check "S2d legacy: pre-S2 splits both wires at the crossing (4 segments)" [xschem get wires] 4
check "S2d legacy: ... and SHORTS the two nets (the measured bug)" \
      [expr {[lindex [xschem instance_nodemap RH1] 2] eq [lindex [xschem instance_nodemap RV2] 2]}] 1
set ::label_splits_wires 0

# --- S2e: `label_splits_wires` has its OWN gate and must not disturb the default path. With
#     autotrim off nothing splits at any pin, so both settings must be identical -- and both
#     must still merge across a pin (spec D2, byte-for-byte default trim/join). Sabotage: fold
#     the label rule into `split_active` and the legacy legs above stop restoring pre-S2
#     behaviour; drop the `!split_active ||` short-circuit and W0/D2 goes red. ---
foreach ls {0 1} {
  set ::label_splits_wires $ls
  catch {xschem clear force}
  set ::autotrim_wires 0
  xschem wire -100 0 0 0
  xschem wire 0 0 100 0
  xschem instance devices/lab_wire 0 0 0 0 {name=l1 lab=GB}
  xschem trim_wires
  check "S2e: autotrim off, label_splits_wires $ls -> unchanged default merge" [xschem get wires] 1
  catch {xschem clear force}
  xschem wire -100 0 100 0
  xschem instance devices/lab_wire 0 0 0 0 {name=l1 lab=GB}
  check "S2e: autotrim off, label_splits_wires $ls -> no split at all" [xschem get wires] 1
}
set ::label_splits_wires 0

if {$fail == 0} { puts "OVERALL: ok"; exit 0 } else { puts "OVERALL: notok"; exit 1 }
