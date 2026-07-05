# TC19 (issue 0047) — MULTI-PIN exit-stub move: a stretch move of a component whose
# BOTH pins exit into corner routes must insert EXACTLY ONE exit stub per exiting pin,
# no extras. This is the multi-pin analog of TC10 (single pin); insert_exit_stubs()
# stores stubs via storeobject() (which grows xctx->wires) mid-scan, so the fix
# snapshots nwires0 before the loops and bounds the inner scans by it — a stub just
# stored for one pin must NOT re-enter a later pin's / instance's scan and be mistaken
# for a pre-existing attached/corner wire (which would drop or duplicate a stub).
#
# GUARD scope: this symmetric fixture keeps the two pins far apart, so it locks the
# correct one-stub-per-pin geometry as a regression baseline. It does not by itself
# reproduce the narrow storeobject-reallocation reentrancy (that needs a stub tip to
# land exactly on another moving pin); see issue 0047. res.sym: pin M=(X,Y+30) exits
# +y, pin P=(X,Y-30) exits -y.
source [file join [file dirname [info script]] fixtures.tcl]
we_reset 1 1
uplevel #0 {set wire_exit_stub 1}
we_device 1360 -930               ;# pin M (1360,-900), pin P (1360,-960)
# pin M route (exits left into a corner going down)
we_wire 1270 -900 1360 -900       ;# M first leg
we_wire 1270 -900 1270 -680       ;# M riser
we_wire 1110 -680 1270 -680       ;# M rail
# pin P route (mirror: exits left into a corner going up)
we_wire 1270 -960 1360 -960       ;# P first leg
we_wire 1270 -960 1270 -1180      ;# P riser
we_wire 1110 -1180 1270 -1180     ;# P rail
xschem unselect_all; xschem select instance 0
we_move_stretch 0 30              ;# perpendicular to both first legs

# pin M moved to -870: a +y exit stub (1360,-870)-(1360,-860)
check "TC19 pin M exit stub present (1360,-870)-(1360,-860)" [has_seg 1360 -870 1360 -860]
# pin P moved to -930: a -y exit stub (1360,-940)-(1360,-930)
check "TC19 pin P exit stub present (1360,-940)-(1360,-930)" [has_seg 1360 -940 1360 -930]
# exactly one stub per exiting pin => exactly 8 wires (no spurious extra stubs)
check "TC19 exactly one stub per pin (8 wires, no extras)" [expr {[nwires] == 8}]
# both first legs slid to align with their stub tips
check "TC19 M first leg slid to (1270,-860)-(1360,-860)" [has_seg 1270 -860 1360 -860]
check "TC19 P first leg slid to (1270,-940)-(1360,-940)" [has_seg 1270 -940 1360 -940]
# rails untouched, everything Manhattan, both pins still connected
check "TC19 M rail unchanged" [has_seg 1110 -680 1270 -680]
check "TC19 P rail unchanged" [has_seg 1110 -1180 1270 -1180]
check "TC19 all wires Manhattan" [all_manhattan]
check "TC19 pin M still connected (1360,-870)" [has_endpoint 1360 -870]
check "TC19 pin P still connected (1360,-930)" [has_endpoint 1360 -930]
we_result
