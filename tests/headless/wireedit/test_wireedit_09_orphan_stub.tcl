# TC9 (R12, Phase 5) — move-orphaned dangling stub removed. Reproduces the bad2-style
# residue: a moved component (res.sym R18 at 1360,-900; pin M=(1360,-870)) whose pin M
# is already served by the horizontal rail (1270,-870)-(1360,-870) ALSO carries a
# redundant vertical stub (1360,-870)-(1360,-900) whose far end (1360,-900) hangs on
# nothing. The release-time move-scoped cleanup drops that stub (it changes no
# connectivity: pin M stays connected through the rail), while the rail and the riser
# (anchored at the OUTI label) are preserved. Per the plan (option A) the fixture
# builds the residue then performs a stretch move so the in-gesture cleanup fires.
source [file join [file dirname [info script]] fixtures.tcl]
# fluid_editing now defaults ON (0091-0096 reroute chain). This test pins the BASE
# (fluid-off) stretch mechanic it was written for; the fluid-on behavior for the same
# scene is covered by test_wireedit_20..51. See doc/claude/issues/0096 re-baseline.
uplevel #0 {set fluid_editing 0}
we_reset 1 1
we_device 1360 -900            ;# R18: pin M=(1360,-870), P=(1360,-930)
we_wire 1270 -870 1360 -870    ;# horizontal rail: serves pin M
we_wire 1270 -870 1270 -680    ;# riser
we_label 1270 -680 OUTI        ;# anchor the riser far end (a real net continuation)
we_wire 1360 -870 1360 -900    ;# redundant dangling stub off pin M (far end free)
# move the component (no-op delta): the stretch-move release cleanup drops the stub
xschem select instance 0
we_move_stretch 0 0
check "TC9 redundant stub off moved pin removed" \
  [expr {![has_endpoint 1360 -900]}]
check "TC9 rail to pin M preserved"      [has_seg 1270 -870 1360 -870]
check "TC9 riser preserved"              [has_seg 1270 -870 1270 -680]
check "TC9 wire count is 2 (rail+riser)" [expr {[nwires] == 2}]
we_result
