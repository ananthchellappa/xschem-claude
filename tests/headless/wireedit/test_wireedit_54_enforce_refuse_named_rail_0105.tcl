# Hardening sprint Track B / step B3 -- END enforcement gate: rollback-or-REFUSE a move that would
# save a net short/merge no healer can repair (WIRING.md risk #1, the named-rail blackout). RED-first.
#
# fluid_check_move_invariants ran at every move END but was LOG-ONLY: it printed the merge and shipped
# it (the 0094/0098/0099 class). B3 promotes it to rollback-or-refuse when fluid_enforce_invariants is
# set: on a residual P2 short/device-merge it restores the gesture-pristine snapshot, drops the undo
# push, and leaves the schematic byte-identical to pre-gesture (a ciw_echo tells the user).
#
# Repro = issue 0105's gesture on a NAMED rail. before_8 (rebuilt in memory): R18 (res, pins P #net3 /
# M on the y=-40 backbone) dragged by (-90,-40) drops BOTH pins onto that backbone -> device self-short.
# 0105's collinear jog normally un-shorts it, BUT here a `lab_pin VDD` names the backbone: every
# de-shorter blackouts on explicitly-named copper (fluid_wire_explicit_lab), so the short is
# UNREPAIRABLE. Two verdicts, driven off the SAME gesture via the enforcement switch:
#   fluid_enforce_invariants 0 (log-only, the old behavior): the merge SAVES -- R18.P and R18.M both
#       resolve to VDD (RED: silent saved corruption).
#   fluid_enforce_invariants 1 (B3, default): the move is REFUSED -- R18 snaps back to its pristine
#       position, R18.P/M stay DISTINCT, and every wire is byte-identical to pre-gesture (GREEN).
# This drives BOTH sides of the switch, so the test is its own RED baseline (no stash needed).
#
# True headless (0105 is a release-topology drop; move_objects release == the interactive gesture):
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_54_enforce_refuse_named_rail_0105.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap $inst]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}
# a canonical, endpoint-order-independent snapshot of all wire spans (for byte-identical compare).
# resolved_net first so both snapshots carry the SAME resolved labs (a clean move stamps labs as a
# side effect regardless of refuse; the geometry is what "untouched" means, but with resolution
# normalized this compares labs too).
proc wireset {} {
  xschem resolved_net 0
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 > $x2 || ($x1 == $x2 && $y1 > $y2)} { lassign [list $x2 $y2 $x1 $y1] x1 y1 x2 y2 }
    lappend L [list $x1 $y1 $x2 $y2 [xschem getprop wire $i lab]]
  }
  return [lsort $L]
}
proc r18pos {} { lassign [xschem instance_coord R18] a b rx ry; return [list $rx $ry] }

# before_8 with the #net1 backbone NAMED VDD (lab_pin) -> a named rail the de-shorters cannot reshape.
proc setup {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 0}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -320 -190 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res      -40    0 3 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  xschem instance devices/lab_pin -200  -40 0 0 {name=lvdd lab=VDD}   ;# names the y=-40 backbone
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140} {-550 140 -400 140}
    {-400 140 -390 140} {-400 -40 -400 140} {-320 -300 -320 -220} {-420 -300 -320 -300}
    {-320 -160 -320 -150} {-320 -150 -80 -150} {-400 -40 0 -40} {-80 -150 -80 0}
    {0 -40 0 0} {-80 0 -70 0} {-10 0 0 0}
  } { xschem wire {*}$w }
}

# ---- side 1: enforcement OFF -> the named-rail short SAVES (RED baseline) --------------------------
setup
set fluid_enforce_invariants 0
check "setup: R18.P and R18.M start on distinct nets (P=[pinnet R18 P] M=[pinnet R18 M])" \
  [expr {[pinnet R18 P] ne [pinnet R18 M]}]
xschem unselect_all; xschem select instance R18
xschem move_objects -90 -40 stretch kissing
check "enforce OFF: the unrepairable named-rail short SAVES (R18.P == R18.M -- the log-only bug)" \
  [expr {[pinnet R18 P] eq [pinnet R18 M]}]

# ---- side 2: enforcement ON -> the move is REFUSED, geometry byte-identical ------------------------
setup
set fluid_enforce_invariants 1
set pre_wires [wireset]
set pre_r18   [r18pos]
xschem unselect_all; xschem select instance R18
xschem move_objects -90 -40 stretch kissing
check "enforce ON: R18.P and R18.M stay DISTINCT (short refused) P=[pinnet R18 P] M=[pinnet R18 M]" \
  [expr {[pinnet R18 P] ne [pinnet R18 M]}]
check "enforce ON: the checker actually FIRED (dev_merges>0 -> refuse was triggered by a real merge)" \
  [expr {$fluid_last_move_dev_merges > 0}]
check "enforce ON: R18 restored to its pristine position (move refused) got=[r18pos] pre=$pre_r18" \
  [expr {[r18pos] eq $pre_r18}]
check "enforce ON: every wire byte-identical to pre-gesture (schematic untouched)" \
  [expr {[wireset] eq $pre_wires}]

we_result
