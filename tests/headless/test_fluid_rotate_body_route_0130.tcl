# issue 0130 (+0133 pin-inclusive body): a ROTATED fluid connected-drag saved Manhattan wires that
# ran THROUGH the moved instance's body, plus (0130) one non-Manhattan diagonal. See
#   doc/claude/issues/0130-fluid-rotate-relay-manhattanize-body-intrusion.md
#
# Under rotation the whole obstacle/exit-stub healer layer is gated OFF (move.c fluid-block,
# rot==flip==0), so the ONLY shaper of the accepted rigid-diagonal relay is
# fluid_manhattanize_relay_diagonals. The 0133 refinement: the body to avoid is the PIN-INCLUSIVE
# bbox (the widest box spanning all of the instance's pins), NOT the tight central drawn body -- a
# backbone threading UNDER the top pins is a body crossing too. fluid_manh_route reshapes each relay
# diagonal into a body-free L / Z / escape-stub route (pin feed legs, which leave a pin along its
# outward normal, are exempt), verified + reverted exactly.
#
# Gesture (Xschem.log.7 -> after_33.sch): load test_hier_descend_etc.sch, select x1
# (SANDBOX/solar_ctl), 'm' connected drag + ALT-R rotate 90, drop (+10,+10). x1 lands (130,0) rot 1.
#   RED (tight-body 0130 / pre-fix): TRIANG backbone `N 100 50 220 50` runs at y=50 straight under
#        the top pins (TRIANG@(100,60), CTRL1@(140,60)); CTRL1 dives through the body at x=140.
#   GREEN: TRIANG routes over the pins (y=70), CTRL1 escapes +y and skirts the body on the right,
#        every wire clear of the pin-inclusive box; netlist unchanged.
#
# True headless (no X): the rotate+connected drag is replayed via the move_objects END seam
# (`move_objects dx dy rot flip local stretch kissing`), byte-identical to the interactive release.
#   src/xschem -q --pipe -x --script tests/headless/test_fluid_rotate_body_route_0130.tcl

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]

# OA (lib/cell/view) registry so SANDBOX/solar_ctl resolves; fluid + orthogonal + cadence, matching
# the launch config (set here directly -- headless has no Tk `bind` for cadence_style_rc).
set XSCHEM_LIBRARY_DEFS [file join $repo xschem_libs_newsym library.defs]
set library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH {}
set library_default_layout nested
set cadence_compat 1
set fluid_editing 1
set orthogonal_wiring 1

xschem load [file join $repo xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch]
xschem set readonly 0

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc share_net {a b} {                               ;# connectivity witness (§10: resolved_net 0 must not stamp)
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
# x1's pin coords + the PIN-INCLUSIVE bbox ("widest box that includes all pins").
proc x1_pins_and_box {} {
  set pins {}; set bx1 1e9; set by1 1e9; set bx2 -1e9; set by2 -1e9
  foreach nm [xschem instance_pins x1] {
    set r [xschem instance_pin_coord x1 name $nm]
    lassign [lrange $r end-1 end] px py
    lappend pins [list $px $py]
    set bx1 [expr {min($bx1,$px)}]; set by1 [expr {min($by1,$py)}]
    set bx2 [expr {max($bx2,$px)}]; set by2 [expr {max($by2,$py)}]
  }
  return [list $pins $bx1 $by1 $bx2 $by2]
}
# strict-interior crossings of the pin-inclusive box, EXEMPTING pin feed stubs (a segment with an
# endpoint exactly on a pin -- the wire's own connection to the pin, which necessarily touches the box).
proc nbodycross {} {
  lassign [x1_pins_and_box] pins bx1 by1 bx2 by2
  set n 0; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    set feed 0
    foreach p $pins { lassign $p px py
      if {($a==$px && $b==$py) || ($c==$px && $d==$py)} { set feed 1; break } }
    if {$feed} continue
    if {$a == $c} {
      if {$a <= $bx1 || $a >= $bx2} continue
      set lo [expr {$b < $d ? $b : $d}]; set hi [expr {$b < $d ? $d : $b}]
      if {$lo < $by2 && $hi > $by1} { incr n }
    } elseif {$b == $d} {
      if {$b <= $by1 || $b >= $by2} continue
      set lo [expr {$a < $c ? $a : $c}]; set hi [expr {$a < $c ? $c : $a}]
      if {$lo < $bx2 && $hi > $bx1} { incr n }
    }
  }
  return $n
}

check "setup: x1 present"               [expr {[inst_by_name x1] >= 0}]
check "setup: no diagonal wires before" [expr {[ndiag] == 0}]

# --- gesture: select x1, connected drag + ALT-R (rot 90) + drop (10,10) ---
xschem select_at 100 -10
xschem move_objects 10 10 1 0 local stretch kissing

lassign [xschem instance_coord x1] a1 a2 nx ny nrot nflip
check "x1 rotated + moved to (130,0) rot 1" \
  [expr {$nx == 130 && $ny == 0 && $nrot == 1 && $nflip == 0}] "got ($nx,$ny) rot $nrot flip $nflip"
check "P1: x1<->l0 still connected (TRIANG)" [share_net x1 l0]
check "P1: x1<->l1 still connected (CTRL1)"  [share_net x1 l1]
check "P4: no diagonal wire left"            [expr {[ndiag] == 0}] "diag=[ndiag]"
check "P5: no wire threads the pin-inclusive body" [expr {[nbodycross] == 0}] "crossings=[nbodycross]"

puts "RESULT: [expr {$::fails==0 ? {ALL PASS} : {FAIL}}] ($::npass ok, $::fails fail)"
puts "OVERALL: [expr {$::fails==0 ? {ok} : {FAIL}}]"
