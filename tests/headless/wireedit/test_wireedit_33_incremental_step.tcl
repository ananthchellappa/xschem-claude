# incremental_wire_reroute.md Phase II -- INCREMENTAL PER-SNAP-STEP REROUTE (timing, not algorithm).
#
# Today the follow-wire reroute runs ONCE, at move_objects(END) (release); during the drag
# (RUBBER) only a rubber-band preview is drawn. Phase II makes the reroute run incrementally, per
# snap grid step, in move_objects(RUBBER) -- the route the user sees while dragging becomes live --
# via RESTORE-AND-REAPPLY: each qualifying RUBBER step restores the pristine pre-move geometry and
# re-applies the CURRENT TOTAL delta through the UNCHANGED reroute pipeline (decision record
# doc/claude/suggestions/incremental_reroute_phase2_decision.md). The algorithm is byte-for-byte
# today's END path, so the committed result on release MUST equal the release-only path
# ("release == stepwise"). Gated on fluid_editing (default off => the whole incremental path is
# skipped => RUBBER still only previews => byte-identical to today).
#
# The stepping is driven through the headless seam added to `xschem move_objects` (scheduler.c):
#   move_objects start <ax> <ay> [kissing] [stretch]   arm + move_objects(START) at anchor
#   move_objects step  <x>  <y>                         one move_objects(RUBBER) at (x,y)
#   move_objects end   [<dx> <dy>]                      move_objects(END) (explicit delta if given)
#
# RED-first teeth:
#   A  a mid-drag `step` must COMMIT the reroute (live geometry changes before END). FALSE until the
#      Phase-II hook exists (RUBBER only previews) => RED; TRUE after => GREEN.
#   B/F release == stepwise: the committed .sch is byte-identical (headline acceptance) and the
#      segset matches, for a 2-step and a many-small-step drag (drift stress).
#   C  fluid OFF: a mid-drag `step` must NOT commit (pure preview) -- proves the path is gated.
#   D  fluid OFF: stepwise .sch still equals release (END path unchanged when off).
#   E  ONE undo entry per gesture: a single `xschem undo` after a stepwise drag restores pristine
#      (a per-step undo push would leave an intermediate route).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_33_incremental_step.tcl
source [file join [file dirname [info script]] fixtures.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}

# Canonical fixture: res RA at (0,0) (pin M=(0,30), P=(0,-30)); a vertical riser on M up to (0,130),
# continued by a horizontal to (60,130). A +X stretch of RA slides the riser+horizontal corner --
# a nontrivial multi-wire reroute. `fluid` toggles the Phase-II gate.
proc setup {fluid} {
  we_reset 1 1                                   ;# enable_stretch=1, orthogonal_wiring=1, cadsnap=10
  uplevel #0 [list set cadence_compat 1]
  uplevel #0 [list set autotrim_wires 1]
  uplevel #0 [list set fluid_editing $fluid]
  uplevel #0 [list set unselect_partial_sel_wires 0]
  xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}
  xschem wire 0 30 0 130
  xschem wire 0 130 60 130
  return [inst_by_name RA]
}

# Release-path drag by (dx,dy): the one-shot START+END stretch move (today's committed route).
proc drag_release {dx dy} {
  set ra [inst_by_name RA]
  xschem unselect_all
  xschem select instance $ra
  we_move_stretch $dx $dy
}
# Stepwise drag by (dx,dy) via `steps` intermediate snap positions, ending with explicit (dx,dy).
# Anchor at (0,0); each step advances the cursor a fraction of the way; END applies the exact total.
proc drag_stepwise {dx dy steps} {
  set ra [inst_by_name RA]
  xschem unselect_all
  xschem select instance $ra
  xschem move_objects start 0 0 kissing stretch
  for {set k 1} {$k <= $steps} {incr k} {
    set sx [expr {int(round(double($dx) * $k / $steps / 10.0)) * 10}]   ;# snap to cadsnap=10
    set sy [expr {int(round(double($dy) * $k / $steps / 10.0)) * 10}]
    xschem move_objects step $sx $sy
  }
  xschem move_objects end $dx $dy
}

# save current schematic to a path and report whether two saved files are byte-identical
proc save_sch {path} { catch { file delete $path }; xschem saveas $path schematic }
proc files_identical {a b} { expr {![catch {exec diff $a $b}]} }

set R [file join /tmp we33_release.sch]
set S [file join /tmp we33_stepwise.sch]

# ---- Case A: a mid-drag step COMMITS the reroute (RED-first teeth) --------------------------------
setup 1
set ra [inst_by_name RA]
xschem unselect_all
xschem select instance $ra
xschem move_objects start 0 0 kissing stretch
set base [segset]                                  ;# post-START (incl. any kiss stubs), pre-step
xschem move_objects step 20 0
set mid [segset]
check "A: a mid-drag snap step commits the live reroute (geometry changed before END)" \
  [expr {$mid ne $base}]
xschem move_objects end 20 0                        ;# finish the gesture cleanly

# ---- Case B: release == stepwise, fluid ON (segset + byte-identical .sch), 2-step ----------------
setup 1
drag_release 20 0
set segRB [segset]
save_sch $R
setup 1
drag_stepwise 20 0 2
set segSB [segset]
save_sch $S
check "B: stepwise segset equals release (fluid on)" [expr {$segSB eq $segRB}]
check "B: stepwise .sch is BYTE-IDENTICAL to release (headline acceptance)" [files_identical $R $S]

# ---- Case F: release == stepwise under MANY small steps (accumulation/drift stress) --------------
setup 1
drag_release 60 -40
set segRF [segset]
save_sch $R
setup 1
drag_stepwise 60 -40 10
set segSF [segset]
save_sch $S
check "F: many-small-step stepwise segset equals release" [expr {$segSF eq $segRF}]
check "F: many-small-step stepwise .sch is byte-identical to release" [files_identical $R $S]

# ---- Case C: fluid OFF -- a mid-drag step must NOT commit (proves the path is gated) --------------
setup 0
set ra [inst_by_name RA]
xschem unselect_all
xschem select instance $ra
xschem move_objects start 0 0 kissing stretch
set baseC [segset]
xschem move_objects step 20 0
set midC [segset]
check "C: fluid OFF -- a mid-drag step does NOT commit (RUBBER only previews)" \
  [expr {$midC eq $baseC}]
xschem move_objects end 20 0

# ---- Case D: fluid OFF -- stepwise .sch still equals release (END path unchanged when off) -------
setup 0
drag_release 20 0
save_sch $R
setup 0
drag_stepwise 20 0 3
save_sch $S
check "D: fluid OFF -- stepwise .sch byte-identical to release (default-off unchanged)" \
  [files_identical $R $S]

# ---- Case E: ONE undo entry per gesture -- a single undo restores pristine ------------------------
setup 1
set pristineE [segset]
drag_stepwise 20 0 3
check "E: stepwise gesture changed geometry" [expr {[segset] ne $pristineE}]
xschem undo
check "E: a SINGLE undo restores the exact pre-drag wire set (one undo entry per gesture)" \
  [expr {[segset] eq $pristineE}]

# ---- Case G: LIVE multi-step route == release to the same point (teeth for the per-step restore) --
# The HEART of Phase II: what the user SEES mid-drag must be the correct route, not an accumulation
# of prior steps. Because each step RESTORES the pristine snapshot and re-applies the CURRENT TOTAL
# delta, the LIVE geometry after stepping (10,0)->(20,0) equals a one-shot release by (20,0). Without
# the per-step restore it DRIFTS (step 2 re-applies the total onto step 1's already-moved route).
# (Cases B/F only compare the committed END result, which END's own restore makes correct even if the
# per-step restore were broken -- so this case is the one with teeth for the live reroute.)
setup 1
drag_release 20 0
set segRG [segset]
setup 1
set ra [inst_by_name RA]
xschem unselect_all
xschem select instance $ra
xschem move_objects start 0 0 kissing stretch
xschem move_objects step 10 0
xschem move_objects step 20 0
set segLiveG [segset]                              ;# LIVE committed geometry mid-drag (before END)
check "G: live multi-step route equals release to the same point (per-step restore, no drift)" \
  [expr {$segLiveG eq $segRG}]
xschem move_objects end 20 0                        ;# finish the gesture cleanly

# ---- Case H: END consuming the ACCUMULATED delta (interactive path) == release --------------------
# The interactive release is move_objects(END,0,0,0): it takes NO explicit delta and consumes the
# accumulated xctx->deltax/deltay left by the last RUBBER step. The incremental step zeroes delta
# only transiently for its redraw and MUST restore it, else END applies zero and the whole move snaps
# back to the origin. Here `move_objects end` (no dx/dy) exercises that path; it must equal release.
setup 1
drag_release 30 -20
set segRH [segset]
setup 1
set ra [inst_by_name RA]
xschem unselect_all
xschem select instance $ra
xschem move_objects start 0 0 kissing stretch
xschem move_objects step 10 -10
xschem move_objects step 30 -20
xschem move_objects end                            ;# END(0,0,0): must use the accumulated (30,-20), not 0
set segH [segset]
check "H: END with accumulated delta (interactive path) equals release (no snap-back to origin)" \
  [expr {$segH eq $segRH}]
check "H: the move actually happened (not reverted to pristine)" \
  [expr {![has_seg 0 30 0 130]}]

# ---- Case J: buffer teardown mid-gesture must NOT resurrect the cleared geometry (review major) ---
# A fluid stretch START arms the pristine snapshot. If the buffer is then cleared/reloaded and a
# stray RUBBER step fires, an un-discarded snapshot would restore the PRE-CLEAR geometry onto the
# empty buffer (deleted content resurrected, delta-shifted). Fix: clear_schematic() discards the
# snapshot AND the RUBBER incremental gate now requires ui_state&STARTMOVE (which clear zeroes).
setup 1
set ra [inst_by_name RA]
xschem unselect_all
xschem select instance $ra
xschem move_objects start 0 0 kissing stretch      ;# arms fluid_reroute_snap (2 wires captured)
xschem clear force                                 ;# tears down the buffer
check "J: buffer is empty after clear (0 wires)" [expr {[xschem get wires] == 0}]
xschem move_objects step 20 0                       ;# stray step: must NOT restore the snapshot
check "J: a stray step after clear does NOT resurrect the cleared geometry (still 0 wires)" \
  [expr {[xschem get wires] == 0}]

# ---- Case K: ABORT of a live incremental drag rolls geometry back to pristine (one gesture) -------
setup 1
set pristineK [segset]
set ra [inst_by_name RA]
xschem unselect_all
xschem select instance $ra
xschem move_objects start 0 0 kissing stretch
xschem move_objects step 20 0                       ;# commit a live step (dirty)
check "K: the live step changed geometry" [expr {[segset] ne $pristineK}]
xschem move_objects abort                           ;# ESC: roll back
check "K: ABORT of a live incremental drag restores the exact pristine wire set" \
  [expr {[segset] eq $pristineK}]

we_result
