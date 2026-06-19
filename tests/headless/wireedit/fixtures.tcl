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
}
# a 2-pin res.sym at (X,Y); pins P=(X,Y-30), M=(X,Y+30)
proc we_device {X Y {rot 0} {flip 0}} { xschem instance {res.sym} $X $Y $rot $flip {} }
proc we_wire {x1 y1 x2 y2 {prop {}}} {
  if {$prop eq {}} { xschem wire $x1 $y1 $x2 $y2 } \
  else { xschem wire $x1 $y1 $x2 $y2 $prop }
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
# Stretch-move the current selection by (dx,dy): selects attached nets then
# moves, exactly as the interactive stretch drag does at release.
proc we_move_stretch {dx dy} { xschem move_objects $dx $dy stretch }
# Plain (non-stretch) move of the current selection by (dx,dy).
proc we_move {dx dy} { xschem move_objects $dx $dy }
