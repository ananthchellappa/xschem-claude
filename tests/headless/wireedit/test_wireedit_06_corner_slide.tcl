# TC6 (Issues D1/D2, RED today) — corner-slide: moving the device perpendicular to
# its exit stub should slide the stub+corner, keeping the run orthogonal, with no
# spurious segment and the same wire count (reproduces golden desired2).
source [file join [file dirname [info script]] fixtures.tcl]
# fluid_editing now defaults ON (0091-0096 reroute chain). This test pins the BASE
# (fluid-off) stretch mechanic it was written for; the fluid-on behavior for the same
# scene is covered by test_wireedit_20..51. See doc/claude/issues/0096 re-baseline.
uplevel #0 {set fluid_editing 0}
we_reset 1 1
we_device 1360 -930          ;# pin M (1360,-900)
we_wire 1270 -900 1360 -900  ;# stub  (pin -> corner)
we_wire 1270 -900 1270 -680  ;# riser (corner down)
we_wire 1110 -680 1270 -680  ;# rail
xschem unselect_all; xschem select instance 0
we_move_stretch 0 30         ;# perpendicular to the stub
check "TC6 stub slid to y=-870" [has_seg 1270 -870 1360 -870]
check "TC6 riser top follows to -870" [has_seg 1270 -870 1270 -680]
check "TC6 rail unchanged" [has_seg 1110 -680 1270 -680]
check "TC6 no segment left at old y=-900" \
  [expr {![has_endpoint 1270 -900] && ![has_endpoint 1360 -900]}]
check "TC6 same wire count (no spurious stub)" [expr {[nwires] == 3}]
we_result
