# Issue 0095 -- undo after a move must NOT drop (or mutate) the selection.
# doc/claude/issues/0095-undo-after-move-drops-selection.md
#
# The issue-0007 fix (pop_undo_keep_selection, select.c) re-selected the post-undo set by
# ARRAY POSITION, gated on ALL SEVEN per-type object counts being unchanged. A fluid
# stretch move that RE-ROUTES wires (rip-up / exit-stub / trim) changes the wire count, so
# that single global count guard went FALSE and the WHOLE selection was dropped -- including
# the untouched moved instance. On the MEMORY backend a second bug: the undo slot, serialized
# mid-gesture, carried the follow-wires' stale SELECTED1/2 flags, so restoring it re-ADDED
# tool-owned wires to the user's selection.
#
# 0095 fix: re-select by session-stable object id (survives pop_undo in both backends), and
# normalize the restored selection to empty first (clears memory stale flags). The count guard
# is kept only as a fallback for the disk restore_undo_ids shape-mismatch bail.
#
# This test drives REAL editor ops -- xschem move_objects (the interactive-drag release seam)
# and xschem undo -- headless (no X). `xschem selection` reports each selected object as
# {type index col id}; we assert on the id-keyed SET so it is index-order independent.
#
# RED (pre-fix): U1 disk count-change move -> after undo selection is EMPTY;
#                U2 memory move -> after undo selection has an EXTRA follow-wire.
# GREEN: after undo the selection == the moved instance(s), exactly.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_undo_move_keep_selection.tcl
source [file join [file dirname [info script]] wireedit fixtures.tcl]

# id-keyed selection set: sorted list of "type:id" (index-order independent)
proc selset {} {
  set out {}
  foreach e [xschem selection] { lappend out "[lindex $e 0]:[lindex $e 3]" }
  return [lsort $out]
}
# just the instance rows of the selection (drop any wires), sorted
proc sel_insts {} {
  set out {}
  foreach e [xschem selection] { if {[lindex $e 0] eq "instance"} { lappend out "instance:[lindex $e 3]" } }
  return [lsort $out]
}

proc scene {fluid backend} {
  xschem clear force
  uplevel #0 [list set fluid_editing $fluid]
  uplevel #0 {set enable_stretch 0}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set cadsnap 10}
  xschem undo_type $backend
}

# ---------------------------------------------------------------------------
# U1: DISK backend, fluid stretch, TOPOLOGY-CHANGING move (the reported bug).
#   Device pin M=(100,130) sits on a horizontal wire end; moving the instance UP by 60
#   detaches the pin -> fluid inserts a vertical connector stub, so wires 1 -> 2 (count
#   change). Pre-fix: the count guard trips and undo drops the selection entirely.
scene 1 disk
we_device 100 100
we_wire 100 130 400 130
xschem unselect_all
xschem select instance 0
set before [selset]
check "U1 pre: exactly the instance selected" [expr {[llength $before] == 1 && [string match instance:* $before]}]
set w0 [nwires]
xschem move_objects 0 -60 stretch
set w1 [nwires]
check "U1 the move actually changed the wire count (topology change)" [expr {$w1 != $w0}]
check "U1 after move only the instance stays selected (drag keeps the set)" [expr {[selset] eq $before}]
xschem undo
check "U1 after undo the instance is STILL selected (not dropped)" [expr {[sel_insts] eq $before}]
check "U1 after undo the selection is EXACTLY the instance (no stray wire)" [expr {[selset] eq $before}]
check "U1 the move was actually undone (wire count back to $w0)" [expr {[nwires] == $w0}]

# ---------------------------------------------------------------------------
# U2: MEMORY backend -- same gesture. Pre-fix the restored slot's stale follow-wire
#   flags re-add a wire to the selection after undo.
scene 1 memory
we_device 100 100
we_wire 100 130 400 130
xschem unselect_all
xschem select instance 0
set before [selset]
xschem move_objects 0 -60 stretch
check "U2(memory) after move only the instance selected" [expr {[selset] eq $before}]
xschem undo
check "U2(memory) after undo selection is EXACTLY the instance (no stale follow-wire)" [expr {[selset] eq $before}]

# ---------------------------------------------------------------------------
# U3: MULTI-instance selection survives a move+undo (both instances, by id).
scene 1 disk
we_device 100 100
we_device 300 100
xschem unselect_all
xschem select instance 0
xschem select instance 1
set before [selset]
check "U3 pre: two instances selected" [expr {[llength $before] == 2}]
xschem move_objects 40 -20 stretch
xschem undo
check "U3 after undo BOTH instances still selected" [expr {[sel_insts] eq $before}]

# ---------------------------------------------------------------------------
# U4: plain move, no topology change -- must also keep the selection (regression guard;
#   this case already worked via the old count guard and must keep working).
scene 0 disk
we_device 100 100
we_wire 100 130 100 300
xschem unselect_all
xschem select instance 0
set before [selset]
xschem move_objects 60 0
xschem undo
check "U4 plain move: after undo instance still selected" [expr {[selset] eq $before}]

# ---------------------------------------------------------------------------
# U5: a property edit undo (issue-0007 core) still keeps selection -- the id path must not
#   regress the count-unchanged case.
scene 1 disk
xschem instance {res.sym} 100 100 0 0 {name=RX value=1k}
xschem unselect_all
xschem select instance RX
set before [selset]
check "U5 pre: RX selected" [expr {[llength $before] == 1}]
xschem setprop instance RX value 30k
xschem undo
check "U5 property-edit undo keeps the instance selected" [expr {[selset] eq $before}]
check "U5 property-edit undo reverted the value" [string match {*value=1k*} [xschem getprop instance RX]]

# ---------------------------------------------------------------------------
# U6: MEMORY backend, empty selection at undo time (nsel==0). The memory undo slot was
#   serialized mid-gesture with the follow-wires grabbed SELECTED1/2; if the user deselects
#   everything after the move and then undoes, the restore must NOT resurrect those stale
#   flags as a ghost selection. Regression for review wf_579a8cff -- the stale-flag normalize
#   must run even when nothing is selected (nsel==0), so it lives OUTSIDE the nsel>0 guard.
#   Detection: the leaked .sel bits are latent until a rebuild_selected_array runs (a real GUI
#   redraw triggers it; headless `redraw` is a no-op). Force the rebuild by selecting ONLY the
#   instance after the undo -- if the fix regresses, the ghost follow-wire is scooped into the
#   selection alongside it. RED (normalize back inside nsel>0): a wire appears in the set.
proc n_sel_wires {} { set n 0; foreach e [xschem selection] { if {[lindex $e 0] eq "wire"} { incr n } }; return $n }
scene 1 memory
we_device 100 100
we_wire 100 130 400 130
xschem unselect_all
xschem select instance 0
xschem move_objects 0 -60 stretch
xschem unselect_all
check "U6(memory) pre-undo nothing selected" [expr {[llength [selset]] == 0}]
xschem undo
xschem select instance 0     ;# forces need_reb_sel_arr + rebuild, surfacing any leaked bits
check "U6(memory) undo with empty selection leaves NO ghost follow-wire selected" [expr {[n_sel_wires] == 0}]

we_result
