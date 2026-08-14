# Cadence deferred-selection: a press-hold-drag-release must NOT change the selection membership.
#   - nothing selected + DRAG an object      -> object moves, ends UNSELECTED
#   - nothing selected + CLICK (no motion)    -> object is selected (normal click-select)
#   - selection S + DRAG an object NOT in S   -> object moves, S preserved, object not added
#   - object in S  + DRAG it                  -> S moves, stays selected
# doc/claude/specs/cadence_modifier_drag.md (deferred-selection).
#
# NEEDS A REAL X DISPLAY (drives the GUI callback press/motion/release path). Self-skips under --nogui.
#   ./src/xschem --pipe -q --script tests/headless/test_drag_keeps_selection.tcl

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

# ---------------------------------------------------------------------------
# Keyboard verb-move (noun-verb 'm') must NOT inherit a leaked deferred-selection
# restore. A plain CLICK that selects a not-yet-selected object arms drag_sel_restore
# + snapshots the PRE-click selection, then its no-motion release ABORTs the move
# (callback.c) WITHOUT going through end_move_copy_logged -- the flag is normally
# cleared by drag_sel_free() at the NEXT button-press select, but a keyboard 'm' has
# no such press, so the leak reaches the 'm' move's END and drag_sel_restore_now()
# wipes the just-moved object down to the stale snapshot. The fix frees the snapshot
# in the click's no-motion ABORT (and in abort_operation). Reported repro: dblclick
# to grow a selection, click R18, press 'm' to connected-drag it, final click drops it.
# ---------------------------------------------------------------------------
proc key {k gx gy} { lassign [sch2scr $gx $gy] sx sy
  xschem callback $::WIN 2 $sx $sy $k 0 0 0 ;# KeyPress (event=2), no button
  catch { update idletasks } }
proc mmove {gx gy dx dy} {  ;# object already selected: keyboard 'm' connected-move by (dx,dy)
  key 109 $gx $gy                              ;# 'm' picks up the selection (follows cursor)
  lassign [sch2scr [expr {$gx+$dx}] [expr {$gy+$dy}]] tsx tsy
  gmotion $tsx $tsy 0                           ;# NO button held during a keyboard move
  gpress   $tsx $tsy 0                          ;# placement press commits the move
  grelease $tsx $tsy 0
  catch { update idletasks } }

# CASE 5: CLICK-select R18 (arms+leaks drag_sel_restore), keyboard-'m' drag it -> stays selected.
reload
click_sch -260 -50
check "5a click selected R18" [expr {[lsearch [xschem selected_set] R18] >= 0}] "sel=[xschem selected_set]"
set cx0 [r18_cx]
mmove -260 -50 40 0
check "5b keyboard-'m' move keeps R18 selected (drag_sel_restore leak guard)" \
  [expr {[lsearch [xschem selected_set] R18] >= 0}] "sel=[xschem selected_set]"
check "5c R18 moved (dx~40)" [expr {abs([r18_cx]-$cx0-40) < 5}] "dx=[expr {[r18_cx]-$cx0}]"

# CASE 6: the reported flow -- selection on net A, CLICK a not-in-A object (snapshot={A}),
# keyboard-'m' drag it -> the clicked object stays selected, NOT reverted to the snapshot.
reload
xschem select_at -320 -190 nodraw       ;# pre-select C12 (net A) via command (no leak arm)
click_sch -260 -50                       ;# CLICK R18 (net B): snapshots {C12}, arms the leak
check "6a click R18 (drops C12)" \
  [expr {[lsearch [xschem selected_set] R18] >= 0}] "sel=[xschem selected_set]"
set cx0 [r18_cx]
mmove -260 -50 40 0
check "6b keyboard-'m' keeps R18 (not restored to stale snapshot)" \
  [expr {[lsearch [xschem selected_set] R18] >= 0}] "sel=[xschem selected_set]"
check "6c R18 moved (dx~40)" [expr {abs([r18_cx]-$cx0-40) < 5}] "dx=[expr {[r18_cx]-$cx0}]"

# CASE 7: abort_operation leak guard -- press-drag R18 (arms drag_sel_restore), ESC
# mid-gesture (abort_operation), then keyboard-'m' move the (kept) selection. Without
# freeing the snapshot in abort_operation the ESC-aborted drag's leak would deselect it.
reload
xschem unselect_all
lassign [sch2scr -260 -50] psx psy
gpress $psx $psy 0                        ;# press R18: selects it + arms drag_sel_restore
gmotion [expr {$psx+30}] $psy 256         ;# begin dragging
xschem callback $::WIN 2 $psx $psy 65307 0 0 0   ;# XK_Escape: abort the drag (keeps selection)
catch { update idletasks }
check "7a ESC keeps R18 selected (escape_deselects=0)" \
  [expr {[lsearch [xschem selected_set] R18] >= 0}] "sel=[xschem selected_set]"
set cx0 [r18_cx]
mmove -260 -50 40 0
check "7b keyboard-'m' after ESC-aborted drag keeps R18 (abort_operation leak guard)" \
  [expr {[lsearch [xschem selected_set] R18] >= 0}] "sel=[xschem selected_set]"

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED, $::npass passed"; puts "OVERALL: fail" }
exit [expr {$::fails ? 1 : 0}]
