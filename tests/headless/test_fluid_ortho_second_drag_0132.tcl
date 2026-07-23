# issue 0132 (pure-ortho variant of after_32): a SECOND fluid connected-drag that is a PURE
# TRANSLATION (no rotation) of an already-rotated instance onto its OWN previously-routed copper.
# The first 0132 fix only reached the rotated diagonal-relay path (fluid_manhattanize_relay_diagonals,
# gated diag_relay); a pure +dx translation accepts clean at attempt 0 (diag_relay=0) so that path is
# skipped (trace: `manhattanize_relay_diagonals: SKIP`, `diag_relay=0`).
#
# ROOT CAUSE (traced, not the earlier place_moved_wire guess): place_moved_wire lays a CLEAN +y feed
# (`100 80 100 90`); the END-cluster `insert_exit_stubs` then SLIDES it -x back through the body. It
# read the escape normal from get_pin_escape_normal, whose nearest-edge test on the TEXT-INFLATED
# inst.x1..y2 mis-picks -x/Left for the rot-1 solar_ctl TRIANG pin, so a route already exiting +y
# reads as "bends at the pin -> slide". FIX: a pin-inclusive body-box guard in insert_exit_stubs
# declines any slide whose stub/leg would thread the moved instance's own body (never worse -- P3
# aesthetic pass, and a true outward normal is escape-exempt). See doc/claude/issues/0132-* + WIRING §11.9b.
#
# Evidence: /tmp/Xschem.log.2 -> tests/from_user/before_10.sch (x1 = SANDBOX/solar_ctl at (110,20)
# rot 1, copper already routed) then `move_objects 20 0` -> tests/from_user/after_34.sch (x1 (130,20)
# rot 1). RED: the TRIANG pin feed routes -x (`N 90 80 100 80`) INTO the pin-inclusive body instead of
# escaping +y over the top. GREEN: feed escapes +y (`N 100 80 100 90`), lands on the backbone, no dead
# copper.
#
#   src/xschem -q --pipe -x --script tests/headless/test_fluid_ortho_second_drag_0132.tcl

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}
# XFAIL tripwire: the ortho-path fix is not yet landed (see below). A failure is EXPECTED and does not
# fail the suite; an unexpected PASS means the fix arrived -> promote to a hard `check`.
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
proc pin_xy {name} { return [lrange [xschem instance_pin_coord x1 name $name] end-1 end] }
# directions (dx,dy) of every wire leaving point (px,py).
proc feed_dirs {px py} {
  set d {}; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c e
    if {$a==$c && $b==$e} continue
    if {$a==$px && $b==$py}      { lappend d [list [expr {$c-$a}] [expr {$e-$b}]] } \
    elseif {$c==$px && $e==$py}  { lappend d [list [expr {$a-$c}] [expr {$b-$e}]] }
  }
  return $d
}
# The reported bug is precise: the TRIANG top pin's feed routes -x (dy==0, dx<0) INTO the pin-inclusive
# body (`N 90 80 100 80`) instead of escaping +y over the top. This is C-box-exact (unlike a Tcl
# re-derivation of fluid_inst_body_box, which misjudges the rot-1 right edge by a pin-rect half and
# then false-flags the CTRL1 x=140 column). Returns {escapes_up feeds_inward}.
proc triang_feed {} {
  lassign [pin_xy TRIANG] px py
  set up 0; set inward 0
  foreach v [feed_dirs $px $py] { lassign $v dx dy
    if {$dx==0 && $dy>0} { set up 1 }
    if {$dy==0 && $dx<0} { set inward 1 }
  }
  return [list $up $inward]
}

# --- 0. sanity: the detector flags the RECORDED buggy save (after_34.sch): TRIANG feed goes -x ---
xschem load [file join $repo tests/from_user/after_34.sch]
xschem set readonly 0
lassign [triang_feed] up0 in0
check "detector: after_34.sch (RED ref) TRIANG feed threads body (-x, not +y)" [expr {$in0 && !$up0}] "up=$up0 inward=$in0"

# --- 1. reproduce from before_10 + move +20,0 (pure ortho, no rotation) ---
xschem load [file join $repo tests/from_user/before_10.sch]
xschem set readonly 0
lassign [xschem instance_coord x1] a1 a2 nx ny nrot nflip
check "before_10: x1 at (110,20) rot 1"  [expr {$nx==110 && $ny==20 && $nrot==1 && $nflip==0}] "got ($nx,$ny) rot $nrot"
lassign [triang_feed] upb inb
check "before_10: TRIANG feed already clean (+y, not -x)" [expr {$upb && !$inb}] "up=$upb inward=$inb"

xschem select instance x1
xschem move_objects 20 0 stretch kissing
lassign [xschem instance_coord x1] a1 a2 nx ny nrot nflip
check "after: x1 at (130,20) rot 1"       [expr {$nx==130 && $ny==20 && $nrot==1 && $nflip==0}] "got ($nx,$ny) rot $nrot"
check "P1: x1<->l0 connected (TRIANG)"    [share_net x1 l0]
check "P1: x1<->l1 connected (CTRL1)"     [share_net x1 l1]
check "P4: no diagonal wire"              [expr {[ndiag]==0}] "diag=[ndiag]"
lassign [triang_feed] upa ina
# FIXED (was xfail): insert_exit_stubs now declines a slide that would thread the moved instance's
# own pin-inclusive body (the mis-picked -x escape normal), leaving the clean +y route place_moved_wire
# already laid. Promoted from xcheck to a hard check.
check "P5: TRIANG feed escapes +y over the top (not -x into body)" [expr {$upa && !$ina}] \
  "up=$upa inward=$ina"

puts "RESULT: [expr {$::fails==0 ? {ALL PASS} : {FAIL}}] ($::npass ok, $::fails fail)"
puts "OVERALL: [expr {$::fails==0 ? {ok} : {FAIL}}]"
