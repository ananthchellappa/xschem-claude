# issue 0107 -- an ACCEPTED rigid diagonal relay (P2 last resort, partition clean) was saved
# RAW: its follow wires run pin->anchor diagonally, violating orthogonal mode. See
#   doc/claude/issues/0107-fluid-relay-saves-non-manhattan-wires.md
#
# Fixture (fixture_0105_pre.sch == tests/from_user/before_8.sch): R18 (res, rot3 flip1) at
# (-40,0), pins (-70,0) #net3 / (-10,0) #net1; both follow anchors sit on the y=0 row.
#
# Gesture: plain LMB attached drag NW by (-130,-90) -> R18 to (-170,-90). Both ortho
# attempts self-collide (the two follow routes share the anchors' row and one route's riser
# T-lands on the other's horizontal -> partition_changed) so the accept ladder falls to the
# rigid diagonal relay, which is partition-clean and ACCEPTED. RED before the 0107 fix: the
# relay result was saved as-is with two diagonal wires (after_24.sch: [-200,-90 -80,0] and
# [-140,-90 0,0]).
#
# PASS = R18 lands at (-170,-90), pins stay on DISTINCT nets, and NO non-Manhattan wire is
# left in the schematic.
#
# NEEDS A REAL X DISPLAY. Self-skips cleanly with no display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_relay_manhattanize_0107.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- fluid drag test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}

# match the user's launch config (src/cadence_style_rc)
set ::intuitive_interface 1; xschem set intuitive_interface 1
set ::cadence_compat 1
set ::fluid_editing 1; catch { xschem set fluid_editing 1 }
set ::orthogonal_wiring 1; catch { xschem set orthogonal_wiring 1 }
set ::autotrim_wires 1
set ::enable_stretch 0

set ::HERE [file dirname [file normalize [info script]]]
xschem load [file join $::HERE fixture_0105_pre.sch]
xschem zoom_full; update idletasks

proc pnet {pin} { return [lindex [xschem instance_net R18 $pin] 0] }
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$zm))}] [expr {int(round(($sy+$yo)/$zm))}]
}
proc count_diag_wires {} {
  set n 0
  set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] wx1 wy1 wx2 wy2
    if {$wx1 != $wx2 && $wy1 != $wy2} { incr n }
  }
  return $n
}

set p_before [pnet P]; set m_before [pnet M]
check "setup: R18 pins start on distinct nets (P=$p_before M=$m_before)" \
  [expr {$p_before ne $m_before}]
check "setup: no diagonal wires before the drag" [expr {[count_diag_wires] == 0}]

# --- plain LMB attached drag on R18's body, NW by (-130,-90) sch, release ---
set BP 4; set BR 5; set MOTION 6; set Button1Mask 256
xschem unselect_all
lassign [xschem instance_coord R18] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
lassign [screen [expr {$rx-130}] [expr {$ry-90}]] tsx tsy
xschem callback $WIN $BP     $psx $psy 0 1 0 0
xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
xschem callback $WIN $MOTION $tsx $tsy 0 0 0 $Button1Mask
xschem callback $WIN $BR     $tsx $tsy 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord R18] a1 a2 nrx nry
check "R18 landed at (-170,-90) [list got $nrx $nry]" [expr {$nrx==-170 && $nry==-90}]
set p_after [pnet P]; set m_after [pnet M]
check "R18 pins stay on DISTINCT nets (no self-short) -- P=$p_after M=$m_after" \
  [expr {$p_after ne $m_after}]
set ndiag [count_diag_wires]
check "no non-Manhattan wires after the drag (got $ndiag diagonal)" [expr {$ndiag == 0}]

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
