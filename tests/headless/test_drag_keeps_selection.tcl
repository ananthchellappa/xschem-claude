# Cadence deferred-selection: a press-hold-drag-release must NOT change the selection membership.
#   - nothing selected + DRAG an object      -> object moves, ends UNSELECTED
#   - nothing selected + CLICK (no motion)    -> object is selected (normal click-select)
#   - selection S + DRAG an object NOT in S   -> object moves, S preserved, object not added
#   - object in S  + DRAG it                  -> S moves, stays selected
# doc/claude/specs/cadence_modifier_drag.md (deferred-selection).
#
# NEEDS A REAL X DISPLAY (drives the GUI callback press/motion/release path). Self-skips under --nogui.
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_drag_keeps_selection.tcl

set fluid_editing 1
set orthogonal_wiring 1
set cadence_compat 1
set snap_cursor 1
set en_pin_select 1

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN)"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } else { puts "FAIL: $name $detail : FAIL"; incr ::fails }
}
proc sch2scr {sx sy} { set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  return [list [expr {int(round(($sx+$xo)/$z))}] [expr {int(round(($sy+$yo)/$z))}]] }
proc gpress {sx sy {st 0}} { xschem callback $::WIN 4 $sx $sy 0 1 0 $st }
proc gmotion {sx sy {st 256}} { xschem callback $::WIN 6 $sx $sy 0 0 0 $st }
proc grelease {sx sy {st 256}} { xschem callback $::WIN 5 $sx $sy 0 1 0 $st }
proc drag_sch {gx gy dx dy} {
  lassign [sch2scr $gx $gy] psx psy
  lassign [sch2scr [expr {$gx+$dx}] [expr {$gy+$dy}]] tsx tsy
  gpress $psx $psy 0
  gmotion [expr {($psx+$tsx)/2}] [expr {($psy+$tsy)/2}] 256
  gmotion $tsx $tsy 256
  grelease $tsx $tsy 256
  catch { update idletasks }
}
proc click_sch {gx gy} {
  lassign [sch2scr $gx $gy] psx psy
  gpress $psx $psy 0
  grelease $psx $psy 256
  catch { update idletasks }
}
set here [file dirname [info script]]
proc reload {} { xschem load "$::here/../from_user/before_5.sch"; xschem unhilight_all; xschem unselect_all; update idletasks }
proc r18_cx {} {  ;# bbox-center x of R18, to confirm it actually moved
  set N [xschem get instances]
  for {set i 0} {$i < $N} {incr i} {
    if {[xschem getprop instance $i name] eq "R18"} {
      set bb [xschem instance_bbox $i]
      if {[regexp {Instance:\s+(-?\d+(?:\.\d+)?)\s+\S+\s+(-?\d+(?:\.\d+)?)} $bb -> x1 x2]} { return [expr {($x1+$x2)/2.0}] }
    }
  }
  return 0
}

# CASE 1: nothing selected, DRAG R18 -> not selected, but moved
reload
set cx0 [r18_cx]
drag_sch -260 -50 40 0
check "1a drag of unselected R18 leaves nothing selected" [expr {[xschem get lastsel] == 0}] "lastsel=[xschem get lastsel]"
check "1b R18 actually moved (dx~40)" [expr {abs([r18_cx]-$cx0-40) < 5}] "dx=[expr {[r18_cx]-$cx0}]"

# CASE 2: nothing selected, CLICK R18 (no motion) -> selected
reload
click_sch -260 -50
check "2 click (no motion) selects R18" \
  [expr {[xschem get lastsel]==1 && [lsearch [xschem selected_set] R18]>=0}] "sel=[xschem selected_set]"

# CASE 3: select C12, DRAG unselected R18 -> C12 preserved, R18 not added
reload
xschem select_at -320 -190 nodraw
drag_sch -260 -50 40 0
check "3 dragging unselected R18 preserves the C12 selection untouched" \
  [expr {[xschem get lastsel]==1 && [lsearch [xschem selected_set] C12]>=0 && [lsearch [xschem selected_set] R18]<0}] \
  "sel=[xschem selected_set]"

# CASE 4: select R18, DRAG it -> stays selected
reload
xschem select_at -260 -50 nodraw
set cx0 [r18_cx]
drag_sch -260 -50 40 0
check "4a dragging a SELECTED R18 keeps it selected" \
  [expr {[lsearch [xschem selected_set] R18] >= 0}] "sel=[xschem selected_set]"
check "4b selected R18 moved (dx~40)" [expr {abs([r18_cx]-$cx0-40) < 5}] "dx=[expr {[r18_cx]-$cx0}]"

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED, $::npass passed"; puts "OVERALL: fail" }
exit [expr {$::fails ? 1 : 0}]
