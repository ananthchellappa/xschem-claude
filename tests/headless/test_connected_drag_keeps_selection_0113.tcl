# Issue 0113: a connected-drag ('m') placement must KEEP the selection.
# Issue doc: doc/claude/issues/0113-connected-drag-m-loses-multiselection.md
#
# Repro (cadence_compat): select >1 object, press 'm' (noun-verb: pick up now, wires
# follow), move, click to place. The placement click's PRESS commits the move (move END,
# clearing STARTMOVE) and resets mouse_moved to 0; the matching RELEASE then fell into the
# cadence "deselect everything but the item under the cursor" branch (callback.c) and
# COLLAPSED the multi-selection down to the single object at the drop point.
# Fix: the press latches xctx->place_click_committed; the release consumes it and suppresses
# the click-select/deselect path, so the moved set stays exactly as selected.
#
# Drives the REAL keyboard dispatch ('m' + MOTION + Button1 drop). Sibling of
# test_cadence_stretch_move.tcl. RED-first: pre-fix A2/B2 fail (selection collapses to 1).
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_connected_drag_keeps_selection_0113.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- connected-drag selection test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} {incr ::fails}
}

set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256
set KSYM_m 109

proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}
proc inst_screen {n} {
  xschem unselect_all; xschem select instance $n
  lassign [xschem get bbox_selected] x1 y1 x2 y2
  xschem unselect_all
  screen [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]
}
proc inst_pos {n} { lrange [xschem instance_coord $n] 2 3 }
# array-index list of the selected instances (index field of `xschem selection` rows)
proc sel_insts {} {
  set L {}; foreach e [xschem selection] { if {[lindex $e 0] eq "instance"} { lappend L [lindex $e 1] } }
  return [lsort -integer $L]
}
proc nsel {} { xschem get lastsel }

# noun-verb keyboard 'm' move: selection already made. KeyPress at grab anchor (START),
# MOTION carries the set, Button1 press+release drops (PRESS commits, RELEASE = the bug).
proc kmove {sx sy dx dy} {
  global KP BP BR MOTION Button1Mask KSYM_m WIN
  set tx [expr {$sx+$dx}]; set ty [expr {$sy+$dy}]
  xschem callback $WIN $KP     $sx $sy $KSYM_m 0 0 0
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP     $tx $ty 0 1 0 0
  xschem callback $WIN $BR     $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

proc setup {} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0
  set ::cadence_compat 1
  set ::fluid_editing 1
  xschem instance {res.sym} 0 0 0 0 {}
  xschem instance {res.sym} 200 0 0 0 {}
  xschem zoom_full; update idletasks
}

# === A -- two instances, connected-drag 'm': BOTH stay selected =============
setup
xschem unselect_all; xschem select instance 0; xschem select instance 1
set before [sel_insts]
lassign [inst_screen 0] sx sy
xschem select instance 0; xschem select instance 1   ;# inst_screen unselected
kmove $sx $sy 40 40
check "A1 the move actually happened (inst0 moved)" [expr {[inst_pos 0] ne {0 0}}] "pos=[inst_pos 0]"
check "A2 both instances stay selected after the drop (issue 0113)" \
  [expr {[sel_insts] eq $before}] "before=$before after=[sel_insts]"

# === B -- three objects (2 inst + connecting wire): selection count kept ====
setup
xschem wire 0 30 200 30    ;# a user wire between the two res
xschem unselect_all; xschem select instance 0; xschem select instance 1
# also select the wire (find it: last added wire is index [wires]-1)
set nw [xschem get wires]
xschem select_inside [expr {-5}] 25 205 35    ;# enclose the horizontal wire + pins region
set n0 [nsel]
lassign [inst_screen 0] sx sy
# rebuild the 3-object selection (inst_screen cleared it)
xschem unselect_all; xschem select instance 0; xschem select instance 1
xschem select_inside [expr {-5}] 25 205 35
set before [nsel]; set bi [sel_insts]
kmove $sx $sy 40 0
check "B1 multi-object move keeps the selection count" [expr {[nsel] == $before}] "before=$before after=[nsel]"
check "B2 both instances still in the selection" [expr {[sel_insts] eq $bi}] "before=$bi after=[sel_insts]"

# === C -- single instance 'm' move still stays selected (regression) ========
setup
xschem unselect_all; xschem select instance 0
lassign [inst_screen 0] sx sy
xschem select instance 0
kmove $sx $sy 40 40
check "C1 single-instance move keeps it selected" [expr {[sel_insts] eq {0} && [nsel] == 1}] "sel=[sel_insts] n=[nsel]"

# === D -- plain click still isolates one of a multi-selection (deselect-others intact) ==
setup
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [inst_screen 1] sx sy
xschem select instance 0; xschem select instance 1
xschem callback $WIN $BP $sx $sy 0 1 0 0
xschem callback $WIN $BR $sx $sy 0 1 0 $Button1Mask
update idletasks
check "D1 a bare click on one of two selected insts isolates it (cadence deselect-others)" \
  [expr {[sel_insts] eq {1}}] "sel=[sel_insts]"

# === E -- latch hygiene: a placement must NOT leak into the NEXT click =======
# The place_click_committed latch is consumed at the top of handle_button_release on EVERY
# path (review wf_fdd928d4 found it stranded when a placement release routed to waves_callback
# before the consume). Guard: after a real 'm' placement (latch set+consumed), a subsequent
# unrelated plain click-isolate must still collapse a fresh multi-selection to the clicked one.
setup
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [inst_screen 0] sx sy
xschem select instance 0; xschem select instance 1
kmove $sx $sy 40 40                              ;# placement: sets + consumes the latch
# now a bare click-isolate on a fresh 2-selection
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [inst_screen 1] cx cy
xschem select instance 0; xschem select instance 1
xschem callback $WIN $BP $cx $cy 0 1 0 0
xschem callback $WIN $BR $cx $cy 0 1 0 $Button1Mask
update idletasks
check "E1 latch does not leak: click-isolate still works after a prior 'm' placement" \
  [expr {[sel_insts] eq {1}}] "sel=[sel_insts]"

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS (7 checks)"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
