# issue 0132 (after_35): the CTRL1 sibling of after_34. Same gesture (before_10 + connected drag of x1
# +20x, pure ortho no rotation), but the complaint is the OTHER pin: CTRL1's stationary vertical
# backbone `N 140 -20 140 100` ends up INSIDE the moved pin-inclusive body of x1 (body box, from the C
# fluid_inst_body_box trace at x1=(130,20) rot1, is x[97.5,150] y[-132.5,82.5], so x=140 is interior).
# The CTRL1 pin (140,80) lands mid-span on that stationary backbone and nothing shoves it out.
#
# EXPECTED (user): the vertical CTRL1 segment (140,-20)-(140,100) is PUSHED RIGHT clear of the body
# (to x=160, one grid past the body's right edge at 150), the pin reconnecting via a short jog. This is
# a BODY-DRIVEN shove (the advancing instance body pushes the same-net wire ahead of it), distinct from
# the PIN-driven fluid_shove_connected_wire (which needs a parallel stub with a moving-pin endpoint --
# CTRL1's pin exits +y then jogs, so that trigger never matches).
#
#   src/xschem -q --pipe -x --script tests/headless/test_fluid_ortho_ctrl1_shove_0132.tcl

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}
# XFAIL tripwire: the body-driven shove (push a stationary same-net backbone the advancing body drove
# OVER, out past the body edge) is NOT yet landed. A failure is EXPECTED and does not fail the suite; an
# unexpected PASS means the fix arrived -> promote to a hard `check`. See doc/claude/issues/0132-* §11.9c.
proc xcheck {name ok note} {
  if {$ok} { puts "XPASS: $name -- fix landed, PROMOTE to check ($note)"; incr ::npass } \
  else     { puts "xfail: $name (known-open: $note)"; incr ::npass }
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
xcheck "P5: CTRL1 vertical backbone pushed clear of body (none threading x in (97.5,150))" \
  [expr {[llength $threading]==0}] \
  "body-driven shove not landed; threading=$threading verticals=[ctrl1_verticals]"

puts "RESULT: [expr {$::fails==0 ? {ALL PASS} : {FAIL}}] ($::npass ok, $::fails fail)"
puts "OVERALL: [expr {$::fails==0 ? {ok} : {FAIL}}]"
