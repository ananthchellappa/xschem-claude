# TC10 (Issue E -> R13) — exit-stub preserved. After a stretch move, a one-minor-grid
# stub leaves each moved pin along its EXIT DIRECTION (the pin's outward normal) before
# the first bend (the "dream", desired1). Same geometry as TC6, move (0,30).
#
# DESIGN NOTE (Phase 6): the Phase-1 baseline assertion here was a GUESS and was WRONG.
# res.sym pin M sits at the top of a +y lead (box center local (0,30), body below it),
# so its outward normal is VERTICAL (+y), NOT horizontal. After the corner-slide move the
# route leaves pin M HORIZONTALLY (first leg (1270,-870)-(1360,-870)); the exit-stub pass
# inserts a one-grid VERTICAL stub out of the pin and slides that first leg up by one grid
# so everything stays Manhattan and connected. Verified headless against the user golden
# `mos_power_ampli_desired1.sch` (vertical stub `N 1360 -900 1360 -880`).
#
# Biggest behavior change in the plan -> gated behind `wire_exit_stub` (default OFF). This
# test turns it ON; every other wireedit test leaves it OFF, so their geometry is unchanged.
source [file join [file dirname [info script]] fixtures.tcl]

proc build_tc10 {} {
  we_reset 1 1
  we_device 1360 -930          ;# pin M (1360,-900), pin P (1360,-960)
  we_wire 1270 -900 1360 -900  ;# stub (first leg, horizontal)
  we_wire 1270 -900 1270 -680  ;# riser
  we_wire 1110 -680 1270 -680  ;# rail
  xschem unselect_all; xschem select instance 0
}

# --- switch OFF: no stub, plain corner-slide route (desired2) — the gate guard ----------
build_tc10
uplevel #0 {set wire_exit_stub 0}
we_move_stretch 0 30
check "TC10 switch OFF: no vertical exit stub" \
  [expr {![has_seg 1360 -870 1360 -860]}]
check "TC10 switch OFF: plain corner-slide route (horizontal first leg on pin)" \
  [has_seg 1270 -870 1360 -870]

# --- switch ON: vertical exit stub out of pin M, route stays Manhattan + connected -------
build_tc10
uplevel #0 {set wire_exit_stub 1}
we_move_stretch 0 30
# pin M now (1360,-870); a one-minor-grid (cadsnap=10) VERTICAL stub along +y to (1360,-860)
check "TC10 exit stub out of pin M (1360,-870)-(1360,-860)" \
  [has_seg 1360 -870 1360 -860]
# the stub must SURVIVE the full Phase-5 cleanup (trim_wires would merge a colinear stub;
# this one survives because the route bends perpendicular just past it)
check "TC10 exit stub still present after cleanup (route bends, not colinear)" \
  [has_seg 1360 -870 1360 -860]
# first leg slid up by one grid to keep it axis-aligned with the stub tip
check "TC10 first leg slid to (1270,-860)-(1360,-860)" \
  [has_seg 1270 -860 1360 -860]
# riser top dragged up to follow the slid first leg
check "TC10 riser follows to (1270,-860)-(1270,-680)" \
  [has_seg 1270 -860 1270 -680]
# rail untouched
check "TC10 rail unchanged (1110,-680)-(1270,-680)" \
  [has_seg 1110 -680 1270 -680]
# whole route still Manhattan, pin M still connected
check "TC10 all wires Manhattan" [all_manhattan]
check "TC10 pin M still connected" [has_endpoint 1360 -870]

we_result
