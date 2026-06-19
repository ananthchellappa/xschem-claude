# Shared helpers for the wire-editing-on-move test suite (Phase 0 scaffold).
# Spec: code_analysis/wire_editing_spec_and_plan.md.
#
# Fixtures are built IN MEMORY (xschem instance / xschem wire), moved with the
# scripted stretch path (`xschem move_objects dx dy stretch`, which is byte-identical
# to the interactive drag's release per the spec Appendix), then wire records are
# read back and asserted as an ENDPOINT-ORDER-INDEPENDENT set.
#
# Building block: res.sym (a 2-pin device) at (X,Y): pin P = (X, Y-30),
# pin M = (X, Y+30). Snap grid = 10.
#
# Run each test from the REPO ROOT under X:
#   DISPLAY=:0 src/xschem --pipe -q --nolog --script tests/headless/wireedit/<test>.tcl

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}
proc we_result {} {
  puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
  flush stdout
  exit [expr {$::fails != 0}]
}

# --- fixture construction --------------------------------------------------
# Fresh empty schematic with the two wire-follow switches set as requested
# (both default OFF, matching stock xschem).
proc we_reset {{stretch 0} {ortho 0}} {
  xschem clear force
  uplevel #0 [list set enable_stretch $stretch]
  uplevel #0 [list set orthogonal_wiring $ortho]
  uplevel #0 {set cadsnap 10}   ;# spec snap grid = 10 (=> sub-grid tolerance 5)
}
# a 2-pin res.sym at (X,Y); pins P=(X,Y-30), M=(X,Y+30)
proc we_device {X Y {rot 0} {flip 0}} { xschem instance {res.sym} $X $Y $rot $flip {} }
proc we_wire {x1 y1 x2 y2 {prop {}}} {
  # `xschem wire x1 y1 x2 y2 [pos] [prop]` -- prop is the 6th arg, so a pos (-1 =
  # append) must precede it; passing prop in the pos slot silently drops it.
  if {$prop eq {}} { xschem wire $x1 $y1 $x2 $y2 } \
  else { xschem wire $x1 $y1 $x2 $y2 -1 $prop }
}

# --- geometry readback (order-independent) ---------------------------------
# Canonicalize a wire's two endpoints into a fixed order so that
# (x1 y1 x2 y2) and (x2 y2 x1 y1) compare equal.
proc we_norm {coord} {
  lassign $coord x1 y1 x2 y2
  if {$x1 < $x2 || ($x1 == $x2 && $y1 <= $y2)} {
    return [list $x1 $y1 $x2 $y2]
  } else {
    return [list $x2 $y2 $x1 $y1]
  }
}
# the set of all current wire segments (normalized, sorted) -- the "segset"
proc segset {} {
  set s {}
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend s [we_norm [xschem wire_coord $i]] }
  return [lsort $s]
}
# is the segment with the given endpoints present (in any endpoint order)?
proc has_seg {x1 y1 x2 y2} {
  expr {[lsearch -exact [segset] [we_norm [list $x1 $y1 $x2 $y2]]] >= 0}
}
# number of wires (convenience)
proc nwires {} { xschem get wires }
# does any wire have an endpoint exactly at (x,y)?
proc has_endpoint {x y} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1 == $x && $y1 == $y) || ($x2 == $x && $y2 == $y)} { return 1 }
  }
  return 0
}
# is every wire axis-aligned (horizontal or vertical, i.e. Manhattan)?
proc all_manhattan {} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 != $x2 && $y1 != $y2} { return 0 }
  }
  return 1
}

# --- net membership --------------------------------------------------------
# Net name of wire i. The net identity used is the wire's cached `lab` token,
# which prepare_netlist_structs() fills with the derived net name. We refresh that
# cache by calling `xschem resolved_net` (which runs prepare_netlist_structs(0)
# unconditionally; spec §2c trap: net data must be rebuilt before querying) and
# then read the bare token with `getprop wire`. This avoids resolved_net's own
# inconsistent hierarchy-prefixing (e.g. "0NETA" vs "NETA") and its
# stale-sel_array dependency -- giving a stable, comparable net identity.
proc we_net {i} {
  xschem resolved_net   ;# refresh the per-wire net-name cache (prepare_netlist_structs)
  return [xschem getprop wire $i lab]
}
# place a net label (lab_pin.sym) named `name` at (X,Y) -- gives a wire touching
# that point a definite, queryable net identity
proc we_label {X Y name} { xschem instance {lab_pin.sym} $X $Y 0 0 [list lab=$name] }
# are wires i and j on DISTINCT nets?
proc nets_distinct {i j} { expr {[we_net $i] ne [we_net $j]} }
# number of distinct nets across all wires
proc netcount {} {
  set seen {}
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    set n [we_net $i]
    if {[lsearch -exact $seen $n] < 0} { lappend seen $n }
  }
  return [llength $seen]
}

# --- moves -----------------------------------------------------------------
# Stretch-move the current selection by (dx,dy): the faithful scripted mirror of
# the interactive plain (cadence/intuitive) stretch drag. That drag does
# select_attached_nets() (endpoint-on-pin follow) AND connect_by_kissing()
# (abutment + mid-span/T-junction follow), wired into handle_button_press
# (callback.c). The `stretch` keyword runs select_attached_nets(); the `kissing`
# keyword sets connect_by_kissing=2 -- together they reproduce the drag's release
# output (spec wire_editing Phase 3).
proc we_move_stretch {dx dy} { xschem move_objects $dx $dy stretch kissing }
# Plain (non-stretch) move of the current selection by (dx,dy).
proc we_move {dx dy} { xschem move_objects $dx $dy }
