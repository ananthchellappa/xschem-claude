# issue 0098 -- VERTICAL-backbone variant (exercises the vertaxis==0 route-around jog).
# The x<->y transpose of the main 0098 case: a horizontal resistor whose right pin M lands
# mid-span on a VERTICAL #net3 backbone (x=-160, anchored by C12.m at (-160,-320); C12.p at
# (-220,-320) makes the whole-backbone slide swap the short, so the jog must route AROUND M).
# Builds its scene inline (no fixture file). See
#   doc/claude/issues/0098-fluid-stretch-pin-on-sibling-net-backbone-short.md
#
# PASS = R18's two pins stay on DISTINCT nets after the connected stretch. Needs a real X
# display; self-skips under --nogui. Companion to test_fluid_sibling_pin_backbone_short_0098.tcl
# (the horizontal / vertaxis==1 case).

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN)"; puts "RESULT: SKIP (no X)"; puts "OVERALL: ok"; exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0; set ::npass 0
proc check {name ok {d {}}} { if {$ok} {puts "ok:   $name"; incr ::npass} else {puts "FAIL: $name $d"; incr ::fails} }

set ::intuitive_interface 1; xschem set intuitive_interface 1
set ::cadence_compat 1; set ::fluid_editing 1; catch {xschem set fluid_editing 1}
set ::orthogonal_wiring 1; catch {xschem set orthogonal_wiring 1}; set ::autotrim_wires 1; set ::enable_stretch 0

xschem clear force
foreach seg {
 {-160 -320 -160 -40} {-160 -40 -150 -40} {-90 -40 -80 -40}
 {-80 -400 -80 -40} {-300 -320 -220 -320} {-300 -420 -300 -320}
} { eval xschem wire $seg }
xschem instance {devices/capa} -190 -320 3 0 {name=C12 m=1 value="40u"}
xschem instance {devices/res}  -120 -40  3 0 {name=R18 m=1 value=200}
xschem zoom_full; update idletasks

proc screen {sx sy} { set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$zm))}] [expr {int(round(($sy+$yo)/$zm))}] }
set pb [lindex [xschem instance_net R18 P] 0]; set mb [lindex [xschem instance_net R18 M] 0]
check "setup: R18 pins start on distinct nets (P=$pb M=$mb)" [expr {$pb ne $mb}]

# cadence 'm' connected stretch by (-70,-20): R18 (-120,-40) -> (-190,-60);
# M (-90,-40) -> (-160,-60) lands mid-span on the vertical #net3 backbone (x=-160).
xschem unselect_all; xschem select instance R18
lassign [xschem instance_coord R18] j1 j2 rx ry
lassign [screen $rx $ry] psx psy; lassign [screen [expr {$rx-70}] [expr {$ry-20}]] tsx tsy
xschem callback $WIN 2 $psx $psy 109 0 0 0
xschem callback $WIN 6 $tsx $tsy 0 0 0 0
xschem callback $WIN 4 $tsx $tsy 0 1 0 0
xschem callback $WIN 5 $tsx $tsy 0 1 0 256
update idletasks

lassign [xschem instance_coord R18] a1 a2 nrx nry
check "R18 landed at (-190,-60) [list got $nrx $nry]" [expr {$nrx==-190 && $nry==-60}]
set pa [lindex [xschem instance_net R18 P] 0]; set ma [lindex [xschem instance_net R18 M] 0]
check "R18 pins stay on DISTINCT nets (vertaxis==0 route-around) -- P=$pa M=$ma" [expr {$pa ne $ma}]

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
