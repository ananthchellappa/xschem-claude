# issue 0132 (0130 open follow-up): a SECOND incremental fluid connected-drag that lands the
# already-rotated instance on its OWN previously-routed copper leaves a through-body backbone +
# an orphan stub. See doc/claude/issues/0132-fluid-second-drag-own-copper.md and WIRING.md §11.9b.
#
# Gesture (two drags of x1 = SANDBOX/solar_ctl):
#   drag 1: select x1, 'm' connected drag + ALT-R rotate 90, drop (10,10) -> x1 (130,0) rot 1.
#           This is the 0133 single-drag case: TRIANG/CTRL1/#net1/#net2 route CLEAN over/around the
#           pin-inclusive body (== after_33_fixed.sch). The G1 copper now sits where the body will land.
#   drag 2: select x1 again, 'm' connected drag +0,+20 (no rotation) -> x1 (130,20) rot 1, ON TOP of
#           its own G1 copper.
#     RED (pre-fix): fluid_manhattanize_relay_diagonals phase-1 re-anchors the moved pin to the
#          nearest same-net copper, which is now the STATIONARY backbone running THROUGH the body
#          (`N 100 50 220 50` TRIANG, `N 140 -20 140 80` CTRL1), and SHORT-CIRCUITS the body-aware
#          fluid_manh_route (done=1). An abandoned diagonal feed is left as an orphan stub
#          (`N 80 50 100 50`). == tests/from_user/after_32.sch.  crossings>0, dangles>0.
#     GREEN: the moved pins re-anchor/route CLEAR of the pin-inclusive body (body-aware re-anchor +
#          fall-through to fluid_manh_route); no orphan stub; netlist unchanged.
#
# True headless (no X): each drag is replayed via the move_objects END seam
# (`move_objects dx dy [rot flip local] stretch kissing`), byte-identical to the interactive release.
#   src/xschem -q --pipe -x --script tests/headless/test_fluid_rotate_second_drag_0132.tcl

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
# strict-interior crossings of the pin-inclusive box, EXEMPTING pin feed stubs.
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
# all instance pin coords (world) over EVERY instance -- a dangling test needs to know where real
# pins are (a wire end landing on a lab_pin / x1 pin is anchored, not orphaned).
proc all_pin_coords {} {
  set pts {}
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    set nm [xschem getprop instance $i name]
    foreach pn [xschem instance_pins $nm] {
      set r [xschem instance_pin_coord $nm name $pn]
      lassign [lrange $r end-1 end] px py
      lappend pts [list $px $py]
    }
  }
  return $pts
}
# DANGLING free wire ends: an endpoint that (a) no OTHER wire touches and (b) is not on any instance
# pin -- an orphan stub tip (e.g. after_32's `N 80 50 100 50` left end). Returns the SET (sorted
# unique "x,y" strings). NB: the loaded fixture already carries two pre-existing danglers ((-60,0),
# (-50,-20)) that are not part of this bug -- the test asserts no NOVEL dangler vs the load baseline.
proc dangle_set {} {
  set pins [all_pin_coords]
  set nw [xschem get wires]
  set coords {}
  for {set k 0} {$k < $nw} {incr k} { lappend coords [xschem wire_coord $k] }
  set res {}
  for {set k 0} {$k < $nw} {incr k} {
    lassign [lindex $coords $k] a b c d
    if {$a==$c && $b==$d} continue            ;# degenerate
    foreach {ex ey} [list $a $b $c $d] {
      set onpin 0
      foreach p $pins { lassign $p px py; if {$ex==$px && $ey==$py} { set onpin 1; break } }
      if {$onpin} continue
      set deg 0
      for {set j 0} {$j < $nw} {incr j} {
        if {$j==$k} continue
        lassign [lindex $coords $j] x1 y1 x2 y2
        if {$x1==$x2 && $y1==$y2} continue
        # endpoint (ex,ey) touches wire j if it lies on j's span (axis-aligned)
        if {$x1==$x2} {
          if {$ex==$x1 && $ey>=min($y1,$y2) && $ey<=max($y1,$y2)} { incr deg }
        } elseif {$y1==$y2} {
          if {$ey==$y1 && $ex>=min($x1,$x2) && $ex<=max($x1,$x2)} { incr deg }
        }
      }
      if {$deg==0} { lappend res "$ex,$ey" }
    }
  }
  return [lsort -unique $res]
}
# dangling ends present now that were NOT present at load (the orphan stubs this bug creates)
proc novel_dangles {baseline} {
  set out {}
  foreach d [dangle_set] { if {[lsearch -exact $baseline $d] < 0} { lappend out $d } }
  return $out
}

check "setup: x1 present"               [expr {[inst_by_name x1] >= 0}]
check "setup: no diagonal wires before" [expr {[ndiag] == 0}]
set dangle_base [dangle_set]           ;# pre-existing danglers in the fixture (not this bug)

# --- drag 1: select x1, connected drag + ALT-R (rot 90) + drop (10,10) -> x1 (130,0) rot 1 ---
xschem select_at 100 -10
xschem move_objects 10 10 1 0 local stretch kissing
lassign [xschem instance_coord x1] a1 a2 nx ny nrot nflip
check "drag1: x1 at (130,0) rot 1"       [expr {$nx==130 && $ny==0 && $nrot==1 && $nflip==0}] "got ($nx,$ny) rot $nrot"
check "drag1: clean (no body crossing)"  [expr {[nbodycross]==0}] "crossings=[nbodycross]"
check "drag1: no diagonal"               [expr {[ndiag]==0}] "diag=[ndiag]"

# --- drag 2: select x1 again, connected drag +0,+20 (no rotation) onto its OWN copper -> (130,20) ---
xschem unselect_all
xschem select instance x1
xschem move_objects 0 20 stretch kissing
lassign [xschem instance_coord x1] a1 a2 nx ny nrot nflip
check "drag2: x1 at (130,20) rot 1"      [expr {$nx==130 && $ny==20 && $nrot==1 && $nflip==0}] "got ($nx,$ny) rot $nrot"
check "P1: x1<->l0 still connected (TRIANG)" [share_net x1 l0]
check "P1: x1<->l1 still connected (CTRL1)"  [share_net x1 l1]
check "P4: no diagonal wire left"        [expr {[ndiag]==0}] "diag=[ndiag]"
check "P5: no wire threads the pin-inclusive body" [expr {[nbodycross]==0}] "crossings=[nbodycross]"
check "no NOVEL orphan stub (no new dangling end)" [expr {[llength [novel_dangles $dangle_base]]==0}] \
  "novel=[novel_dangles $dangle_base]"

puts "RESULT: [expr {$::fails==0 ? {ALL PASS} : {FAIL}}] ($::npass ok, $::fails fail)"
puts "OVERALL: [expr {$::fails==0 ? {ok} : {FAIL}}]"
