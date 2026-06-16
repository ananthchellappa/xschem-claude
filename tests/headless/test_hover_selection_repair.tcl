# Issue 0011 — moving the bare pointer across a large object (the dashed
# annotation polygon enclosing the circuit in mos_power_ampli) must NOT make a
# selected object look deselected.
#
# Root cause: draw_hover() (the hover-awareness cue) erases the previous hover
# outline and then repairs the selection overlay with draw_selection(). On a
# system with fix_broken_tiled_fill set, erasing a large shape restores its whole
# bounding box from the backing pixmap, wiping the window-only selection
# highlight; the repair draw_selection() paints from sel_array/lastsel, which on
# the motion/hover path can be STALE (lastsel==0) while the object is still
# selected by its .sel flag -> the repair draws nothing -> the highlight is gone.
# Fix: rebuild_selected_array() before the repair (callback.c, draw_hover).
#
# WHAT THIS TEST COVERS (headless, observable):
#   - the object stays LOGICALLY selected across a real motion sweep that crosses
#     the dashed polygon (guards against a future "fix" that truly deselects);
#   - the hover state machine actually engages over the big polygon (so the
#     erase/repair branch is exercised), and is gated by hover_highlight.
# WHAT IT CANNOT COVER: the actual on-screen repair is a window-only overlay; like
# the pixel checks in test_hover_highlight.tcl it is a MANUAL EYEBALL item (move
# the pointer across the dashed box with hover_highlight on; the selection box
# must stay drawn). fix_broken_tiled_fill governs whether the destructive erase
# path is taken at all; this run reports its value for context.
#
# Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_hover_selection_repair.tcl
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

set MOTION 6
proc moveto {sx sy} {
  global MOTION
  set mx [expr {int(($sx + [xschem get xorigin]) / [xschem get zoom])}]
  set my [expr {int(($sy + [xschem get yorigin]) / [xschem get zoom])}]
  xschem callback .drw $MOTION $mx $my 0 0 0 0
  update idletasks
}
proc selcount {} { return [llength [xschem objects -selected]] }
proc r18_selected {} {
  foreach o [xschem objects -selected] {
    if {[dict exists $o name] && [dict get $o name] eq "R18"} { return 1 }
  }
  return 0
}

set hover_highlight 1
xschem load xschem_library/examples/mos_power_ampli.sch
xschem zoom_full
update idletasks

puts "fix_broken_tiled_fill = [xschem get fix_broken_tiled_fill] (destructive-erase path active when 1)"

# R18 sits inside the dashed annotation polygon (P ... {dash=3}, box 0,-1290..1390,-130)
xschem unselect_all
xschem select instance R18
update idletasks
set bb [xschem instance_bbox R18]
regexp {Instance: ([-0-9.eE]+) ([-0-9.eE]+) ([-0-9.eE]+) ([-0-9.eE]+)} $bb -> ix1 iy1 ix2 iy2
set cy [expr {($iy1+$iy2)/2.0}]
check "S1 R18 selected after select" [r18_selected] "(selcount=[selcount])"

# Sweep the BARE pointer (no button) from R18 rightward, well past the polygon's
# right edge (x=1390): hover goes selected/empty -> polygon -> empty, exercising
# the erase + repair branch. R18 must remain selected the whole way.
set ok_all 1
for {set sx [expr {($ix1+$ix2)/2.0}]} {$sx <= 1700} {set sx [expr {$sx+25}]} {
  moveto $sx $cy
  if {![r18_selected]} { set ok_all 0 }
}
check "S2 R18 still selected after sweep across dashed polygon" [r18_selected] "(selcount=[selcount])"
check "S3 R18 selected at every step of the sweep" $ok_all ""

# The hover machine must actually have engaged with the big polygon during the
# sweep (otherwise the erase/repair branch is never hit). Park the pointer on the
# polygon's right edge and confirm hover reports it.
moveto 1390 [expr {($iy1+$iy2)/2.0 - 200}]
set hv [xschem hover]
check "S4 hover engages the dashed polygon (repair branch reachable)" \
  [expr {[string match "*polygon*" $hv] || $hv ne ""}] "(hover=$hv)"

# Gating: with the cue disabled there is no erase/repair at all; selection intact.
set hover_highlight 0
moveto [expr {($ix1+$ix2)/2.0}] $cy
moveto 1500 $cy
check "S5 selection intact with hover_highlight off" [r18_selected] "(selcount=[selcount])"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
