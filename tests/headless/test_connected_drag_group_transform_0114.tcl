# Issue 0114: a multi-object connected drag rotates/flips the WHOLE selection as a rigid
# group about a shared pivot (Cadence Stretch semantics, wires kept connected) -- NOT each
# object spun about its own origin (ROTATELOCAL).
# Issue doc: doc/claude/issues/0114-connected-drag-group-rotate-flip.md
#
# Pre-fix: mid-drag ALT-R / ALT-F / ALT-V used ROTATE|ROTATELOCAL, so with >1 object each
# member spun in place -- the group scattered / overlapped and relative positions were kept.
# Fix (callback.c connected_drag_group_transform): when the in-flight move/copy holds >1
# user object, drop ROTATELOCAL so the transform is the group form (shared pivot). A single
# object keeps the in-place rotatelocal (its own-origin rotate that Case 4 reconnects).
#
# Discriminator: a GROUP rotate/flip about a pivot MOVES the member positions (the vector
# between two members rotates/mirrors); a per-object LOCAL transform leaves x0,y0 unchanged.
#
# Drives the REAL keyboard dispatch: 'm' (START connected stretch) + ALT-R/ALT-F/ALT-V/Shift-R
# (transform mid-move) + Button1 drop (END, no translation). RED-first: pre-fix A/B/E fail
# (positions unchanged = local spin).
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_connected_drag_group_transform_0114.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- connected-drag group transform test needs a real display"
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
set Button1Mask 256 ; set ShiftMask 1 ; set Mod1Mask 8
set KSYM_m 109 ; set KSYM_r 114 ; set KSYM_R 82 ; set KSYM_f 102 ; set KSYM_v 118

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
proc inst_rot {n} { lindex [xschem instance_coord $n] 4 }
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
proc pin_xy {n name} { set pc [xschem instance_pin_coord $n name $name]; list [lindex $pc 1] [lindex $pc 2] }
# is (x,y) an endpoint of some wire?
proc ep_present {x y {tol 0.6}} {
  foreach w [allwires] {
    lassign $w a b c d
    if {abs($a-$x)<$tol && abs($b-$y)<$tol} { return 1 }
    if {abs($c-$x)<$tol && abs($d-$y)<$tol} { return 1 }
  }
  return 0
}

# connected 'm' start at grab, apply transform keys, drop at same point (no translation).
# ktrans {list of {ksym state}} applied between START and drop.
proc kdrag_transform {sx sy keys} {
  global KP BP BR Button1Mask KSYM_m WIN
  xschem callback $WIN $KP $sx $sy $KSYM_m 0 0 0
  foreach k $keys { lassign $k ks st; xschem callback $WIN $KP $sx $sy $ks 0 0 $st }
  xschem callback $WIN $BP $sx $sy 0 1 0 0
  xschem callback $WIN $BR $sx $sy 0 1 0 $Button1Mask
  update idletasks
}

# two res stacked vertically, connected by a straight wire pin0.P(0,-30)->pin1.M(0,-170)
proc setup_vstack {} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0; set ::cadence_compat 1; set ::fluid_editing 1
  set ::orthogonal_wiring 1
  xschem instance {res.sym} 0 0 0 0 {}       ;# pins P=(0,-30) M=(0,30)
  xschem instance {res.sym} 0 -200 0 0 {}    ;# pins P=(0,-230) M=(0,-170)
  xschem wire 0 -30 0 -170                    ;# connects inst0.P to inst1.M
  xschem zoom_full; update idletasks
}
# two res side by side (horizontal) for a clean flip discriminator
proc setup_hpair {} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0; set ::cadence_compat 1; set ::fluid_editing 1
  set ::orthogonal_wiring 1
  xschem instance {res.sym} 0 0 0 0 {}
  xschem instance {res.sym} 200 0 0 0 {}
  xschem zoom_full; update idletasks
}

# === A -- group ROTATE (ALT-R): the two stacked res rotate about the pivot ==
setup_vstack
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [inst_screen 0] sx sy   ;# pivot = inst0 centre
xschem select instance 0; xschem select instance 1
set p0b [inst_pos 0]; set p1b [inst_pos 1]
kdrag_transform $sx $sy [list [list $KSYM_r $Mod1Mask]]
set p0a [inst_pos 0]; set p1a [inst_pos 1]
# stacked => both x=0 before; a group rotate about (0,0) sends them to different x
set x0 [lindex $p0a 0]; set x1 [lindex $p1a 0]
check "A1 ALT-R rotates the pair as a GROUP (members no longer share x)" \
  [expr {abs($x0-$x1) > 1}] "before {$p0b}{$p1b} after {$p0a}{$p1a}"
# connectivity: both connected pins still carry wire copper after the reroute
lassign [pin_xy 0 P] px0 py0
lassign [pin_xy 1 M] px1 py1
check "A2 group rotate keeps the connection (inst0.P has wire copper)" [ep_present $px0 $py0] "P=($px0,$py0)"
check "A3 group rotate keeps the connection (inst1.M has wire copper)" [ep_present $px1 $py1] "M=($px1,$py1)"

# === B -- group FLIP (ALT-F): the horizontal pair mirrors about the pivot ====
setup_hpair
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [inst_screen 0] sx sy   ;# pivot = inst0 centre (x=0 axis)
xschem select instance 0; xschem select instance 1
set p1b [inst_pos 1]
kdrag_transform $sx $sy [list [list $KSYM_f $Mod1Mask]]
set p1a [inst_pos 1]
# inst1 at x=200; a group flip about the x=0 axis sends it to x=-200; local keeps x=200
check "B1 ALT-F flips the pair as a GROUP (inst1 crosses the pivot axis)" \
  [expr {[lindex $p1a 0] < -1}] "inst1 before=$p1b after=$p1a"

# === C -- single object ALT-R stays per-object rotatelocal (negation) ========
setup_hpair
xschem unselect_all; xschem select instance 0
lassign [inst_screen 0] sx sy
xschem select instance 0
set pb [inst_pos 0]; set rb [inst_rot 0]
kdrag_transform $sx $sy [list [list $KSYM_r $Mod1Mask]]
check "C1 single-object ALT-R is a per-object rotate (position unchanged, rot advances)" \
  [expr {[inst_pos 0] eq $pb && [inst_rot 0] ne $rb}] "pos $pb->[inst_pos 0] rot $rb->[inst_rot 0]"

# === D -- Shift-R already groups; still groups for multi (regression) ========
setup_hpair
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [inst_screen 0] sx sy
xschem select instance 0; xschem select instance 1
set p1b [inst_pos 1]
kdrag_transform $sx $sy [list [list $KSYM_R $ShiftMask]]
check "D1 Shift-R rotates the pair as a group (inst1 moves off the x axis)" \
  [expr {abs([lindex [inst_pos 1] 1]) > 1}] "inst1 before=$p1b after=[inst_pos 1]"

# === E -- group vertical flip (ALT-V) on the vertical stack ==================
# flipv mirrors y about the pivot row, so a member must be OFF that row to discriminate:
# the vstack's inst1 sits at (0,-200), a group flipv about (0,0) sends it to (0,+200);
# a per-object local flipv keeps its own (0,-200).
setup_vstack
xschem unselect_all; xschem select instance 0; xschem select instance 1
lassign [inst_screen 0] sx sy
xschem select instance 0; xschem select instance 1
set p1b [inst_pos 1]
kdrag_transform $sx $sy [list [list $KSYM_v $Mod1Mask]]
check "E1 ALT-V transforms the pair as a group (inst1 mirrored across the pivot row)" \
  [expr {[lindex [inst_pos 1] 1] > 1}] "inst1 before=$p1b after=[inst_pos 1]"

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS (7 checks)"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
