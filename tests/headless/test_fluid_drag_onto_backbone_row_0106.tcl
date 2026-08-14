# issue 0106 -- plain LMB attached drag parks a device (and its follow stub + riser
# T-junction) ON the backbone row of its sibling pin's net -> the one-grid 0098/0105
# route-around gap lands its bump legs on the pin's own follow cluster (or bails on the
# stub swallowed whole by the gap) -> device self-short survives every de-short pass. See
#   doc/claude/issues/0106-fluid-drag-pin-cluster-on-backbone-row-jog-gap.md
#
# Fixture (fixture_0105_pre.sch == tests/from_user/before_8.sch): R18 (res, rot3 flip1) at
# (-40,0), horizontal: pin (-70,0) on #net3 (C12 bottom plate, riser at x=-80 + stub
# [-80,-70] at y=0), pin (-10,0) on #net1 whose backbone runs [-400 -40 0 -40] at y=-40.
#
# Gesture: plain LMB press on R18's body, drag (0,-40) up, release -> R18 to (-40,-40):
# BOTH pins land on the y=-40 backbone, and so do the left pin's stub ([-80,-70]@-40) and
# the capa riser's bottom T (-80,-40). RED before the 0106 fix: the jog's fixed one-grid
# gap [-80,-60] either bailed (stub wholly inside) or welded its qL bump leg to the riser
# T; the saved file (after_23.sch) had R18 bridged and #net3 swallowed by #net1.
#
# PASS = R18's two pins stay on DISTINCT nets after the drag.
#
# NEEDS A REAL X DISPLAY. Self-skips cleanly with no display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_drag_onto_backbone_row_0106.tcl

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

set p_before [pnet P]; set m_before [pnet M]
check "setup: R18 pins start on distinct nets (P=$p_before M=$m_before)" \
  [expr {$p_before ne $m_before}]

# --- plain LMB attached drag on R18's body, (0,-40) sch up, release ---
set BP 4; set BR 5; set MOTION 6; set Button1Mask 256
xschem unselect_all
lassign [xschem instance_coord R18] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
lassign [screen $rx [expr {$ry-40}]] tsx tsy
xschem callback $WIN $BP     $psx $psy 0 1 0 0
xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
xschem callback $WIN $MOTION $tsx $tsy 0 0 0 $Button1Mask
xschem callback $WIN $BR     $tsx $tsy 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord R18] a1 a2 nrx nry
check "R18 landed at (-40,-40) [list got $nrx $nry]" [expr {$nrx==-40 && $nry==-40}]
set p_after [pnet P]; set m_after [pnet M]
check "R18 pins stay on DISTINCT nets after attached drag (no self-short) -- P=$p_after M=$m_after" \
  [expr {$p_after ne $m_after}]

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
