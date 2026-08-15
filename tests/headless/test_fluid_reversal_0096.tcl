# issue 0096: a fluid GROUP drag (instance(s)+wire) must not leave a FOREIGN-net redundant
# reversal jog crossing the moved selection's bounding box.
#
# Repro: tests/from_user/before_5.sch. Leftward crossing-select C12 + R18 + their #net2
# connecting wire (3 segments), drag by (-60,+80). R18's #net1 riser reverses out to the OLD
# column x=-260 and the backbone returns LEFT at y=-10 straight THROUGH the moved parts
# (after_15.sch). The redundant-jog straighten declined the reversal's NEAR slide (x=-320) because
# it drives the jog through the moved R18 between its two pins (a #net1/#net2 short) and -- before
# the fix -- never tried the FAR target. The fix lets a reversal fall back to the far target
# (x=-400, body-guarded), rerouting #net1 cleanly PAST the selection (preferred_15.sch topology).
#
# NEEDS A REAL X DISPLAY (the gesture runs move_objects + Xlib drawtemp). Self-skips under --nogui.
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_reversal_0096.tcl

set fluid_editing 1
set orthogonal_wiring 1
set cadence_compat 1
set snap_cursor 1
set en_pin_select 1

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- fluid reversal test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail : FAIL"; incr ::fails }
}

proc sch2scr {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  return [list [expr {int(round(($sx + $xo)/$z))}] [expr {int(round(($sy + $yo)/$z))}]]
}
proc gpress   {sx sy {st 0}}   { xschem callback $::WIN 4 $sx $sy 0 1 0 $st }
proc gmotion  {sx sy {st 256}} { xschem callback $::WIN 6 $sx $sy 0 0 0 $st }
proc grelease {sx sy {st 256}} { xschem callback $::WIN 5 $sx $sy 0 1 0 $st }

# replay pointer path: grabx,graby schematic grab point; path = list of {dx dy} cumulative offsets
proc grab_drag_path {grabx graby path} {
  lassign [sch2scr $grabx $graby] psx psy
  gpress $psx $psy 0
  foreach wp $path {
    lassign $wp dx dy
    lassign [sch2scr [expr {$grabx+$dx}] [expr {$graby+$dy}]] sx sy
    gmotion $sx $sy 256
  }
  lassign [lindex $path end] edx edy
  lassign [sch2scr [expr {$grabx+$edx}] [expr {$graby+$edy}]] esx esy
  grelease $esx $esy 256
  catch { update idletasks }
}

set ::RBTMP "/tmp/xschem_0096_rb_[pid].sch"
proc all_wires {} {
  file delete -force -- $::RBTMP
  catch { xschem saveas $::RBTMP schematic }
  set out {}
  if {![file exists $::RBTMP]} { return $out }
  set f [open $::RBTMP r]; set data [read $f]; close $f
  foreach line [split $data "\n"] {
    if {![string match "N *" $line]} continue
    if {![regexp {^N\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+\{(.*)\}} $line -> x1 y1 x2 y2 props]} continue
    set lab ""; regexp {lab=([^ \}]+)} $props -> lab
    lappend out [list $x1 $y1 $x2 $y2 $lab]
  }
  return $out
}
proc net_wires {all want} {
  set out {}
  foreach w $all { if {[lindex $w 4] eq $want} { lappend out $w } }
  return $out
}
# does axis-aligned segment (x1,y1)-(x2,y2) have any point strictly inside open box (xlo,xhi)x(ylo,yhi)?
proc seg_in_box {seg xlo ylo xhi yhi} {
  lassign $seg x1 y1 x2 y2
  set sxlo [expr {min($x1,$x2)}]; set sxhi [expr {max($x1,$x2)}]
  set sylo [expr {min($y1,$y2)}]; set syhi [expr {max($y1,$y2)}]
  # overlap of [sxlo,sxhi] with open (xlo,xhi) and [sylo,syhi] with open (ylo,yhi)
  return [expr {$sxhi > $xlo && $sxlo < $xhi && $syhi > $ylo && $sylo < $yhi}]
}

set here [file dirname [info script]]
xschem load "$here/../from_user/before_5.sch"
xschem unhilight_all
update idletasks

# select C12, R18 + the 3 #net2 connecting wires (== the leftward crossing box; startsel_w=3)
xschem select_at -320 -190 nodraw
xschem select_at -260 -50  add nodraw
xschem select_at -290 -150 add nodraw
xschem select_at -260 -115 add nodraw
xschem select_at -320 -155 add nodraw
update idletasks
check "0096-selected-5: C12+R18+3 #net2 wires" [expr {[xschem get lastsel] == 5}] "lastsel=[xschem get lastsel]"

set PATH {
  {0 10} {-10 20} {-20 40} {-20 60} {-20 80} {-10 100} {-10 110} {0 110}
  {0 120} {10 130} {20 130} {30 130} {40 130} {40 120} {40 110} {40 100}
  {30 90} {20 80} {10 80} {0 80} {-10 80} {-20 80} {-30 80} {-40 80} {-50 80} {-60 80}
}
grab_drag_path -320 -190 $PATH

set all [all_wires]
set n1 [net_wires $all "#net1"]
set n2 [net_wires $all "#net2"]
set n3 [net_wires $all "#net3"]

# The moved selection interior (C12 x[-390,-370], R18 body ~x[-330,-310], #net2 x[-380,-320],
# y from C12 top pin -140 down to R18 bottom pin 60). Any #net1 copper strictly inside is a cross.
set XLO -388; set YLO -138; set XHI -318; set YHI 58
set crossing {}
foreach w $n1 { if {[seg_in_box $w $XLO $YLO $XHI $YHI]} { lappend crossing $w } }
check "0096-no-cross: no #net1 wire passes through the moved selection" \
  [expr {[llength $crossing] == 0}] "crossing=$crossing"

# the specific offending backbone segment (after_15.sch) must be gone: a #net1 row at y=-10
set badrow 0
foreach w $n1 { lassign $w x1 y1 x2 y2 lab; if {$y1 == -10 && $y2 == -10 && [expr {min($x1,$x2)}] < -320} { set badrow 1 } }
check "0096-no-y-10-backbone: #net1 has no leftbound y=-10 backbone row" [expr {!$badrow}] "n1=$n1"

# positive: #net1 routes BELOW the selection -- a horizontal rung at y=70
set rung 0
foreach w $n1 { lassign $w x1 y1 x2 y2; if {$y1 == 70 && $y2 == 70} { set rung 1 } }
check "0096-rung-y70: #net1 rung routed below the selection (y=70)" $rung "n1=$n1"

# connectivity (P1): #net2 (C12<->R18) intact and DISTINCT -- exactly one net2 vertical riser survives,
# and R18's two pins remain on different nets (no reversal-collapse short).
check "0096-net2-present: #net2 copper survived the drag" [expr {[llength $n2] >= 1}] "n2=$n2"
# R18 bottom pin (-320,60) must be #net1; R18 top pin (-320,0) must be #net2 (still two nets)
proc pin_on_net {all px py want} {
  foreach w $all {
    lassign $w x1 y1 x2 y2 lab
    if {$lab ne $want} continue
    if {$x1 == $x2 && $x1 == $px && $py >= [expr {min($y1,$y2)}] && $py <= [expr {max($y1,$y2)}]} { return 1 }
    if {$y1 == $y2 && $y1 == $py && $px >= [expr {min($x1,$x2)}] && $px <= [expr {max($x1,$x2)}]} { return 1 }
  }
  return 0
}
check "0096-R18-bot-net1: R18 bottom pin (-320,60) on #net1" [pin_on_net $all -320 60 "#net1"] "n1=$n1"
check "0096-R18-top-net2: R18 top pin (-320,0) on #net2"    [pin_on_net $all -320 0  "#net2"] "n2=$n2"

file delete -force -- $::RBTMP
puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED, $::npass passed"; puts "OVERALL: fail" }
exit [expr {$::fails ? 1 : 0}]
