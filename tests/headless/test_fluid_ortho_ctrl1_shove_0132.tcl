# issue 0132 (after_35): the CTRL1 sibling of after_34. Same gesture (before_10 + connected drag of x1
# +20x, pure ortho no rotation), but the complaint is the OTHER pin: CTRL1's stationary vertical
# backbone `N 140 -20 140 100` ended up INSIDE the moved pin-inclusive body of x1 (body box, from the C
# fluid_inst_body_box trace at x1=(130,20) rot1, is x[97.5,150] y[-132.5,82.5], so x=140 is interior).
# The CTRL1 pin (140,80) landed mid-span on that stationary backbone and nothing shoved it out.
#
# FIXED (fluid_shove_body_crossing_backbone, move.c): the BODY-driven shove -- the advancing body
# pushes the engulfed same-net backbone one grid past the body edge (x=160), the pin reconnecting via
# a short jog, the dead overhang (140,80)-(140,100) dropped. Distinct from the PIN-driven
# fluid_shove_connected_wire (which needs a parallel stub with a moving-pin endpoint -- CTRL1's pin
# exits +y then jogs, so that trigger never matches). P5 below was the xfail tripwire, promoted to a
# hard check when the shove landed; P5b is the whole-net body-clearance invariant (the after_34
# lesson: a single-wire check let a second defect on the same gesture pass green).
#
#   src/xschem -q --pipe -x --script tests/headless/test_fluid_ortho_ctrl1_shove_0132.tcl

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set XSCHEM_LIBRARY_DEFS [file join $repo xschem_libs_newsym library.defs]
set library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH {}
set library_default_layout nested
set cadence_compat 1
set fluid_editing 1
set orthogonal_wiring 1

# body box of x1 at (130,20) rot1 (from the C fluid_inst_body_box ES-DBG trace)
set ::BX1 97.5; set ::BY1 -132.5; set ::BX2 150; set ::BY2 82.5

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc share_net {a b} {
  xschem resolved_net 0
  set am [xschem instance_nodemap [inst_by_name $a]]
  set bm [xschem instance_nodemap [inst_by_name $b]]
  set an {}; foreach {p nn} [lrange $am 1 end] { if {$nn ne {}} { lappend an $nn } }
  foreach {p nn} [lrange $bm 1 end] { if {$nn ne {} && [lsearch -exact $an $nn] >= 0} { return 1 } }
  return 0
}
proc ndiag {} {
  set n 0; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    if {$a != $c && $b != $d} { incr n }
  }
  return $n
}
# CTRL1 vertical wire segments: {x ylo yhi} for each vertical CTRL1 wire.
proc ctrl1_verticals {} {
  set out {}; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    if {[xschem getprop wire $k lab] ne "CTRL1"} continue
    lassign [xschem wire_coord $k] a b c d
    if {$a == $c && $b != $d} { lappend out [list $a [expr {min($b,$d)}] [expr {max($b,$d)}]] }
  }
  return $out
}

xschem load [file join $repo tests/from_user/before_10.sch]
xschem set readonly 0
xschem select instance x1
xschem move_objects 20 0 stretch kissing
lassign [xschem instance_coord x1] a1 a2 nx ny nrot nflip
check "after: x1 at (130,20) rot 1"    [expr {$nx==130 && $ny==20 && $nrot==1 && $nflip==0}] "got ($nx,$ny) rot $nrot"
check "P1: x1<->l1 connected (CTRL1)"  [share_net x1 l1]
check "P1: x1<->l0 connected (TRIANG)" [share_net x1 l0]
check "P4: no diagonal wire"           [expr {[ndiag]==0}] "diag=[ndiag]"

# P5: no CTRL1 vertical backbone left threading the body column x=140 (inside the body box). The
# vertical must be pushed right, clear of the body's right edge (x=150).
set threading {}
set pushed 0
foreach v [ctrl1_verticals] {
  lassign $v x ylo yhi
  # a vertical strictly inside the body x-range whose span dips into the body y-range = threads it
  if {$x > $::BX1 && $x < $::BX2 && $ylo < $::BY2 && $yhi > $::BY1} { lappend threading $v }
  if {$x >= $::BX2} { set pushed 1 }
}
check "P5: CTRL1 vertical backbone pushed clear of body (none threading x in (97.5,150))" \
  [expr {[llength $threading]==0}] \
  "threading=$threading verticals=[ctrl1_verticals]"
check "P5: a CTRL1 vertical exists at/right of the body edge (the shoved backbone)" $pushed \
  "verticals=[ctrl1_verticals]"

# P5b: WHOLE-NET body-clearance invariant (the after_34 lesson: asserting one named wire let the
# CTRL1 defect escape green). NO wire of ANY net may strictly thread the pin-inclusive body box
# unless it carries an endpoint exactly ON a moved pin (a pin's own feed/jog legitimately clips the
# box -- e.g. the CTRL1 reconnect jog (140,80)-(160,80) and the TRIANG +y feed). Direction of the
# pin-attached feed (the after_34 inward-slide class) is asserted by its own test,
# test_fluid_ortho_second_drag_0132.tcl.
# x1 at (130,20) rot 1 pin coords: TRIANG (100,80), CTRL1 (140,80), top feeds (120,-130) (140,-130).
set ::MOVEDPINS {{100 80} {140 80} {120 -130} {140 -130}}
proc seg_threads_body {a b c d} {
  # strictly-interior crossing, same semantics as C fluid_seg_crosses_sel_body (no exemption)
  if {$a == $c && $b != $d} {
    if {$a <= $::BX1 || $a >= $::BX2} { return 0 }
    set lo [expr {min($b,$d)}]; set hi [expr {max($b,$d)}]
    return [expr {$lo < $::BY2 && $hi > $::BY1}]
  } elseif {$b == $d && $a != $c} {
    if {$b <= $::BY1 || $b >= $::BY2} { return 0 }
    set lo [expr {min($a,$c)}]; set hi [expr {max($a,$c)}]
    return [expr {$lo < $::BX2 && $hi > $::BX1}]
  }
  return 0
}
set viol {}
set nw [xschem get wires]
for {set k 0} {$k < $nw} {incr k} {
  lassign [xschem wire_coord $k] a b c d
  if {![seg_threads_body $a $b $c $d]} continue
  set onpin 0
  foreach mp $::MOVEDPINS { lassign $mp mx my
    if {($a==$mx && $b==$my) || ($c==$mx && $d==$my)} { set onpin 1; break } }
  if {!$onpin} { lappend viol [list [xschem getprop wire $k lab] $a $b $c $d] }
}
check "P5b: whole-net body clearance (no wire threads the body except a moved pin's own feed)" \
  [expr {[llength $viol]==0}] "viol=$viol"

# --- SECOND-generation incremental drag: the one-sided inward feed (issue 0132 §11.9d, after_36) ----
# A SECOND +20x drag from the fixed state puts the body (now x[117.5,170]) back over the shoved
# backbone (x=160), and the CTRL1 pin (160,80) lands exactly ON the run's END, not mid-run. The old
# strictly-both-sides shove gate (its over-fire guard) DECLINED this, so the backbone survived as an
# INWARD vertical feed diving through the whole body to reach the l1 rail (this is exactly the user's
# after_36 complaint, recreated by every subsequent incremental drag). FIXED by re-gating the shove on
# "same-net copper strictly inside the body along-span by > one grid" (the user's ">=1 grid outside
# body" spec): the one-sided inward feed qualifies and is shoved one grid past the advanced body edge
# (x=180); the TRIANG +y escape feed (<= a grid inside) still declines. Was an xfail; now a hard check.
xschem unselect_all
xschem select instance x1
xschem move_objects 20 0 stretch kissing
lassign [xschem instance_coord x1] a1 a2 nx ny nrot nflip
check "drag2: x1 at (150,20) rot 1"     [expr {$nx==150 && $ny==20 && $nrot==1 && $nflip==0}] "got ($nx,$ny) rot $nrot"
check "drag2 P1: x1<->l1 still connected (CTRL1)"  [share_net x1 l1]
check "drag2 P1: x1<->l0 still connected (TRIANG)" [share_net x1 l0]
check "drag2 P4: no diagonal wire"      [expr {[ndiag]==0}] "diag=[ndiag]"
# body box of x1 at (150,20) rot1 = drag-1 box shifted +20x
set ::BX1 117.5; set ::BX2 170
set threading2 {}
set pushed2 0
foreach v [ctrl1_verticals] {
  lassign $v x ylo yhi
  if {$x > $::BX1 && $x < $::BX2 && $ylo < $::BY2 && $yhi > $::BY1} { lappend threading2 $v }
  if {$x >= $::BX2} { set pushed2 1 }
}
check "drag2 P5: CTRL1 vertical clear of the advanced body (none threading x in (117.5,170))" \
  [expr {[llength $threading2]==0}] \
  "one-sided inward feed must be shoved out; threading=$threading2 verticals=[ctrl1_verticals]"
check "drag2 P5: the shoved CTRL1 backbone exists at/right of the advanced body edge (x>=170)" \
  $pushed2 "verticals=[ctrl1_verticals]"

# drag2 P5b: WHOLE-NET body-clearance (mirror of drag-1). x1 at (150,20) rot 1 moved pins:
# TRIANG (120,80), CTRL1 (160,80), top feeds (140,-130) (160,-130).
set ::MOVEDPINS {{120 80} {160 80} {140 -130} {160 -130}}
set viol2 {}
set nw [xschem get wires]
for {set k 0} {$k < $nw} {incr k} {
  lassign [xschem wire_coord $k] a b c d
  if {![seg_threads_body $a $b $c $d]} continue
  set onpin 0
  foreach mp $::MOVEDPINS { lassign $mp mx my
    if {($a==$mx && $b==$my) || ($c==$mx && $d==$my)} { set onpin 1; break } }
  if {!$onpin} { lappend viol2 [list [xschem getprop wire $k lab] $a $b $c $d] }
}
check "drag2 P5b: whole-net body clearance (no wire threads the body except a moved pin's own feed)" \
  [expr {[llength $viol2]==0}] "viol=$viol2"

puts "RESULT: [expr {$::fails==0 ? {ALL PASS} : {FAIL}}] ($::npass ok, $::fails fail)"
puts "OVERALL: [expr {$::fails==0 ? {ok} : {FAIL}}]"
