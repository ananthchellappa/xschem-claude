# Hardening sprint Track B / step B4 -- surface SILENT fail-safe degradations.
#
# Every fluid healer/placement pass no-ops when its START snapshot is missing or the instance set
# changed under it (fluid_snap_pinnet==NULL / fluid_count_pins() != fluid_snap_npins) -- "engine gave
# up and routed naively" then looks identical to "clean route". B4 wraps each such bail in
# fluid_failsafe() (count only, condition unchanged) and publishes the per-gesture total to the Tcl
# var fluid_last_move_failsafes (also fltraced at END).
#
#   NORMAL drag -> 0 (snapshot valid, instance set stable -> no pass bails).
#   A gesture that ADDS an instance between START and END (one-shot: no RUBBER step, so the fluid
#   restore does not revert it) drifts the pin count -> the snapshot-indexed passes bail -> nonzero.
#   (A STEPWISE drag that adds an instance mid-step is reverted by fluid_reroute_restore each step, so
#   the drift never reaches the healers -- the one-shot start/end form is the one that exercises it.)
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_55_failsafe_counter_b4.tcl
source [file join [file dirname [info script]] fixtures.tcl]

proc scene {} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}; uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}; uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 0}; uplevel #0 {set cadsnap 10}
  xschem instance devices/capa -320 -190 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res  -40    0 3 1 {name=R18 m=1 value=200}
  foreach w {
    {-400 -40 0 -40} {0 -40 0 0} {-10 0 0 0}
    {-320 -160 -320 -150} {-320 -150 -80 -150} {-80 -150 -80 0} {-80 0 -70 0}
  } { xschem wire {*}$w }
}

# --- a CLEAN one-shot drag reports 0 degradations ---
scene
xschem unselect_all; xschem select instance R18
xschem move_objects -60 0 stretch kissing
check "clean one-shot drag: fluid_last_move_failsafes == 0 ($fluid_last_move_failsafes)" \
  [expr {$fluid_last_move_failsafes == 0}]

# --- a CLEAN stepwise drag reports 0 too ---
scene
xschem unselect_all; xschem select instance R18
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {-20 0 -40 0 -60 0} { xschem move_objects step $sx $sy }
xschem move_objects end -60 0
check "clean stepwise drag: fluid_last_move_failsafes == 0 ($fluid_last_move_failsafes)" \
  [expr {$fluid_last_move_failsafes == 0}]

# --- adding an instance mid-gesture drifts the pin count -> passes fail-safe bail -> nonzero ---
scene
xschem unselect_all; xschem select instance R18
xschem move_objects start 0 0 kissing stretch
xschem instance devices/res 300 300 0 0 {name=RX m=1 value=99}   ;# instance set changes under the snapshot
xschem move_objects end -90 -40
check "instance added mid-gesture: fluid_last_move_failsafes > 0 ($fluid_last_move_failsafes)" \
  [expr {$fluid_last_move_failsafes > 0}]

we_result
