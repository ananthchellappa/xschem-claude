# issue 0105 -- fluid connected-move drops a device back ONTO the collinear backbone that
# fed one of its pins -> both pins land on the same wire run -> device bridged (self-short
# under the body). See
#   doc/claude/issues/0105-fluid-move-lands-device-on-own-collinear-backbone-short.md
#
# Fixture (fixture_0105_pre.sch == tests/from_user/before_8.sch): R18 (res, rot3 flip1) at
# (-40,0), horizontal: pin (-70,0) on #net3 (C12's bottom plate route), pin (-10,0) on
# #net1 whose backbone is the horizontal run [-400 -40 0 -40] at y=-40.
#
# Gesture: cadence 'm' CONNECTED move, drag R18 by (-90,-40) -> R18 to (-130,-40): BOTH
# pins (-160,-40) and (-100,-40) land exactly ON the y=-40 #net1 backbone. The backbone
# splits at the pins; the span between them bridges the device. RED before the 0105 fix:
# 0094's rip-up only knew PERPENDICULAR backbones (slide) and 0098's jog was only tried
# around the sibling Q -- the collinear case fell through and the saved file (after_22.sch)
# had R18 shorted (#net3 swallowed by #net1).
#
# PASS = R18's two pins stay on DISTINCT nets after the move (backbone jogged around the
# invader pin, or the commit declined).
#
# NEEDS A REAL X DISPLAY (move_objects + Xlib drawtemp SIGSEGV under --nogui). Self-skips
# cleanly with no display so it is safe in the --nogui regression harness. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_collinear_backbone_short_0105.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- fluid move test needs a real display"
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

# --- cadence 'm' noun-verb CONNECTED move, R18 selected, drag by (-90,-40) sch ---
set KP 2; set BP 4; set BR 5; set MOTION 6; set Button1Mask 256; set KSYM_m 109
xschem unselect_all; xschem select instance R18
lassign [xschem instance_coord R18] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
lassign [screen [expr {$rx-90}] [expr {$ry-40}]] tsx tsy
xschem callback $WIN $KP     $psx $psy $KSYM_m 0 0 0
xschem callback $WIN $MOTION $tsx $tsy 0 0 0 0
xschem callback $WIN $BP     $tsx $tsy 0 1 0 0
xschem callback $WIN $BR     $tsx $tsy 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord R18] a1 a2 nrx nry
check "R18 landed at (-130,-40) [list got $nrx $nry]" [expr {$nrx==-130 && $nry==-40}]
set p_after [pnet P]; set m_after [pnet M]
check "R18 pins stay on DISTINCT nets after connected move (no self-short) -- P=$p_after M=$m_after" \
  [expr {$p_after ne $m_after}]

# the un-shorted result must also keep the ORIGINAL pairings: the C12-route pin keeps the
# capacitor's bottom-plate net, the backbone pin keeps the ammeter-rail net.
proc cnet {pin} { return [lindex [xschem instance_net C12 $pin] 0] }
proc vnet {pin} { return [lindex [xschem instance_net v8 $pin] 0] }
set c_minus [cnet m]
set v_plus  [vnet plus]
if {$c_minus eq {}} { set c_minus [cnet M] }
if {$v_plus  eq {}} { set v_plus  [vnet p] }
check "one R18 pin still ties to C12's bottom plate ($c_minus)" \
  [expr {$p_after eq $c_minus || $m_after eq $c_minus}]
check "one R18 pin still ties to the ammeter rail ($v_plus)" \
  [expr {$p_after eq $v_plus || $m_after eq $v_plus}]

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
