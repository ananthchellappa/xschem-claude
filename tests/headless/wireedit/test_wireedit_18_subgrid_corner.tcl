# TC18 (issue 0046) — SUB-GRID corner-slide: the stretch-attach decision
# (select_attached_nets, tolerance cadsnap/2) and the corner-slide pin tests
# (point_on_moving_pin / point_on_fixed_pin) must use the SAME predicate. Here the
# device pin sits 1 unit off the (on-grid) stub endpoint — within tolerance, so the
# stub IS grabbed for stretching. Pre-fix the corner-slide guard used an exact `==`
# pin test, so it did NOT fire for the sub-grid-grabbed stub: the stub jogged and a
# spurious segment appeared. With the shared tolerance it slides just like the
# on-grid TC6, no spurious stub. RED before the 0046 fix, GREEN after.
source [file join [file dirname [info script]] fixtures.tcl]
we_reset 1 1
# device at sub-grid Y=-931 => pin M = (1360,-901), 1 unit off the on-grid stub
we_device 1360 -931          ;# pin M (1360,-901)
we_wire 1270 -900 1360 -900  ;# stub  (on-grid corner -> near the pin)
we_wire 1270 -900 1270 -680  ;# riser (corner down)
we_wire 1110 -680 1270 -680  ;# rail
xschem unselect_all; xschem select instance 0
we_move_stretch 0 30         ;# perpendicular to the stub
check "TC18 stub slid to y=-870 (corner-slide fired on sub-grid pin)" [has_seg 1270 -870 1360 -870]
check "TC18 riser top follows to -870" [has_seg 1270 -870 1270 -680]
check "TC18 rail unchanged" [has_seg 1110 -680 1270 -680]
check "TC18 no segment left at old y=-900" \
  [expr {![has_endpoint 1270 -900] && ![has_endpoint 1360 -900]}]
check "TC18 same wire count (no spurious jog stub)" [expr {[nwires] == 3}]
we_result
