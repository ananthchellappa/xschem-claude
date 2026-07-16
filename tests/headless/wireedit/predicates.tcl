# Predicate library for the "nice" drag-rerouting golden-oracle harness.
# Spec: doc/claude/specs/nice_drag_rerouting.md §4 (formal P-predicates) and §7.
#
# Turns the subjective word "nice" into testable predicates P(before, after). Each is a
# Tcl proc returning a boolean, built ONLY on read-only `xschem` queries plus the
# geometry/net helpers in fixtures.tcl (segset / has_seg / all_manhattan / we_net /
# instance_nodemap).
#
# SOURCE fixtures.tcl FIRST, then this file. This file deliberately does NOT re-source
# fixtures.tcl: fixtures.tcl runs `set ::fails 0` at load, so a second source would reset
# the check counter and hide failures.
#
# Predicate library COMPLETE (Phase 0, per spec §8): P1, P2, P3, P4, P5, P6, P7
# (+ seg_touch primitive, pin_escape_normal getter, pred_verdict recorder).
#
# Hard invariants (a violation is a bug -> block/undo the move): p1, p2.
# Quality objectives (optimize; may trade off): p3 > p5 > p4 > p7 > p6 (spec §4 order).
#
# Phase 0 is ASSERT-ONLY: a known quality gap (a RED predicate on a not-yet-supported
# fixture) must NOT be a build failure -- but a DRIFT from the recorded baseline must be.
# `pred_verdict` prints the GREEN/RED verdict and fails only when it disagrees with the
# pinned expectation (a GREEN gone RED = regression; a RED gone GREEN = the feature landed,
# update the baseline). GROUND-TRUTH fixtures (F1) that must always be green use plain
# `check` instead. The `expect` values are pinned to OBSERVED reality, never to the spec's
# prediction (spec §8's F3/F4/F5/F8-RED guess is explicitly unverified).
proc pred_verdict {name got expect} {
  set g [expr {$got ? "GREEN" : "RED"}]
  puts "PRED: $name = $g (baseline $expect)"; flush stdout
  check "$name matches recorded baseline ($expect)" [expr {$g eq $expect}]
}

# --- P1: connectivity invariant (INV-1) ------------------------------------
# Canonical, comparable snapshot of the whole schematic's connectivity: every instance's
# pin->net map via `xschem instance_nodemap` (which rebuilds the netlist first). Capture
# before the move, capture after, compare byte-identical.
proc net_snapshot {} {
  set ni [xschem get instances]
  set snap {}
  for {set i 0} {$i < $ni} {incr i} {
    set nm [xschem getprop instance $i name]
    lappend snap [list $nm [xschem instance_nodemap $nm]]
  }
  return [lsort $snap]
}
# P1: does the current connectivity equal the captured `before` snapshot? No pin may lose
# or gain a net across the move.
proc p1_netlist_invariant {before} { expr {[net_snapshot] eq $before} }

# --- geometry primitive (shared by P2 and P5 no-body-cross) -----------------
# Axis-aligned segment as its closed bounding box (xlo ylo xhi yhi).
proc _seg_bounds {s} {
  lassign $s x1 y1 x2 y2
  list [expr {min($x1,$x2)}] [expr {min($y1,$y2)}] [expr {max($x1,$x2)}] [expr {max($y1,$y2)}]
}
# Do two AXIS-ALIGNED segments share at least one point? For axis-aligned segments the
# bounding box is zero-thickness in the perpendicular direction, so closed-box overlap is
# EXACTLY the touch test (parallel non-collinear segs are rejected by the zero-height/width
# extent; crossings, T-junctions and collinear overlaps are all accepted). P5 reuses this
# against an instance body box. (Diagonal segments would over-approximate -- callers assume P4.)
proc seg_touch {s1 s2} {
  lassign [_seg_bounds $s1] ax1 ay1 ax2 ay2
  lassign [_seg_bounds $s2] bx1 by1 bx2 by2
  expr {!($ax2 < $bx1 || $bx2 < $ax1 || $ay2 < $by1 || $by2 < $ay1)}
}

# --- P2: no-short (distinct nets never coincide) ----------------------------
# The hazard: a reroute leaves two DISTINCT nets touching (a silent short). Two independent
# failure modes, and P2 must catch BOTH -- one does not subsume the other:
#
#  (a) GEOMETRIC coincidence. Surprising but real: xschem does NOT always merge geometric
#      contact into one net. A stub end landing exactly on another net's wire end can stay
#      two distinct resolved nets that visually/topologically coincide -- the spec's literal
#      P2 ("distinct-net wire pairs never touch()"). Detect by enumerating wire pairs: any
#      two wires on distinct RESOLVED nets that seg_touch => short. (touch() itself is
#      C-only, unreachable from Tcl, so seg_touch reimplements it.)
#  (b) LABEL-CONFLICT collapse. Two nets the user NAMED differently become one physical net.
#      When they merge, the netlister picks ONE name as the winner and the loser's name
#      DISAPPEARS from the wires. So: every intended net (a distinct label `lab=`) must still
#      appear as a distinct physical wire-net name. `lab=` on a label INSTANCE is a stable
#      statement of intent (the netlister reads it but only overwrites WIRE lab tokens with
#      the resolved node). This catches the merge that pass (a) misses once the two nets are
#      already one net at the wire level (no distinct-net pair left to see). Beware:
#      instance_nodemap ECHOES a label's own lab= (its intent), not the resolved winner, so
#      it cannot detect the conflict -- the wire-level resolved names can.
#
# CRITICAL: refresh with `resolved_net 0`, NOT bare `resolved_net`. Bare resolved_net
# resolves the SELECTED net and stamps every wire's lab with it -- after a move the dragged
# instance is still selected, so bare resolved_net mislabels every wire as one net and hides
# the short. The `0` arg forces prepare_netlist_structs(0), a full selection-independent rebuild.
proc p2_no_short {} {
  xschem resolved_net 0                       ;# refresh per-wire net cache once (side effect)
  set nw [xschem get wires]
  set segs {}; set nets {}; set wirenets {}
  for {set i 0} {$i < $nw} {incr i} {
    set wn [xschem getprop wire $i lab]
    lappend segs [xschem wire_coord $i]
    lappend nets $wn
    if {[lsearch -exact $wirenets $wn] < 0} { lappend wirenets $wn }
  }
  # (a) geometric: no distinct-resolved-net wire pair may touch
  for {set i 0} {$i < $nw} {incr i} {
    for {set j [expr {$i + 1}]} {$j < $nw} {incr j} {
      if {[lindex $nets $i] ne [lindex $nets $j] &&
          [seg_touch [lindex $segs $i] [lindex $segs $j]]} { return 0 }
    }
  }
  # (b) label-conflict: every distinct intended net (label lab=) must survive as a wire net
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    set lab [xschem getprop instance $i lab]
    if {$lab eq {}} continue                  ;# not a net label (devices carry no lab=)
    if {[lsearch -exact $wirenets $lab] < 0} { return 0 }   ;# its name vanished => merged
  }
  return 1
}

# --- P2 (general): device-pin-merge no-short --------------------------------
# The label-centric p2_no_short above MISSES a DEVICE short: when a reroute lays a leg across
# a foreign device between two of its pins, the two nets merge, but neither pin carries a lab=
# (they are device pins, not net labels), so neither pass of p2_no_short sees it -- the merge
# just silently renames a #net. This is exactly the R18/v8 short (spec incremental_wire_reroute.md
# §9): v8.plus was on #net1, v8.minus on OUT; the swept leg bridges them -> both become OUT.
#
# GENERAL rule: no instance may have two pins that were on DISTINCT nets before the move end up
# on ONE net after. Capture dev_pin_map() BEFORE the move; assert p2_no_device_merge with that
# snapshot AFTER. instance_nodemap is reliable for DEVICE pins -- it echoes only a net-LABEL's own
# lab= (the P1/P2 echo trap), so label instances are skipped. Unconnected pins (empty net) are
# ignored (a floating pin joining a net is a connect, caught by P1, not a device short).
proc dev_pin_map {} {
  xschem resolved_net 0                          ;# refresh resolved per-pin nets (side effect)
  set ni [xschem get instances]
  set res [dict create]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i lab] ne {}} continue   ;# net label: nodemap echoes intent, skip
    set nm [xschem getprop instance $i name]
    dict set res $nm [lrange [xschem instance_nodemap $nm] 1 end]   ;# {pin net pin net ...}
  }
  return $res
}
# does any device have two pins DISTINCT (both named) before but MERGED (same non-empty net) after?
proc p2_no_device_merge {before} {
  set after [dev_pin_map]
  dict for {nm ap} $after {
    if {![dict exists $before $nm]} continue
    array unset B; array set B [dict get $before $nm]
    array unset A; array set A $ap
    set pins [array names A]
    foreach p1 $pins {
      foreach p2 $pins {
        if {$p1 eq $p2} continue
        if {![info exists B($p1)] || ![info exists B($p2)]} continue
        set b1 $B($p1); set b2 $B($p2); set a1 $A($p1); set a2 $A($p2)
        if {$b1 ne {} && $b2 ne {} && $b1 ne $b2 && $a1 ne {} && $a1 eq $a2} { return 0 }
      }
    }
  }
  return 1
}

# --- P4: orthogonality -----------------------------------------------------
# Every wire leg is axis-aligned (horizontal or vertical). Named alias of the fixtures.tcl
# helper so the predicate library is uniform (spec §4 P4).
proc p4_orthogonal {} { all_manhattan }

# --- P5: no body crossing ---------------------------------------------------
# No wire leg may pass through an instance BODY interior (spec §4 P5). Details that make this
# non-trivial (all verified against real symbols):
#  - Obstacle box = the world-coordinate `Instance:` line of `xschem instance_bbox` (already
#    rotated/translated). It INCLUDES the instance's name/value attribute text, so this is
#    CONSERVATIVE (a leg crossing the text region also flags) -- acceptable for a keep-clear
#    quality check, and the §6 text-inflation caveat. The tighter symbol-graphic box is in
#    untranslated symbol coords and would need a per-instance transform; deferred until F4/F8
#    need it.
#  - NET LABELS are not obstacles: their Instance box is inflated by the label text (e.g. a
#    lab_pin spans ~55 units of "NETA" text). Skip any instance carrying a `lab=` prop.
#  - PIN EXEMPTION: a symbol's pins sit INSIDE its bbox (the pin leads extend a couple units
#    past the pin point), so EVERY legitimate pin connection dips into the interior. A leg is
#    therefore exempt when one of its endpoints is a pin OF THAT instance; only a leg crossing
#    the interior with NEITHER endpoint on the instance's pins (a straight through-cross) is
#    the P5 violation (F4/F8). Limitation: a leg starting at a pin and plowing straight back
#    through the body is wrongly exempted -- pathological, revisit if a fixture needs it.
#
# instance body box in world coords -> {x1 y1 x2 y2}
proc _inst_body_box {name} {
  set bb [xschem instance_bbox $name]
  regexp {Instance:\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $bb -> x1 y1 x2 y2
  return [list $x1 $y1 $x2 $y2]
}
# world coords of every pin of instance `name` -> list of {x y}
proc _inst_pin_coords {name} {
  set map [xschem instance_nodemap $name]     ;# "name pin node pin node ..."
  set coords {}
  foreach {pin node} [lrange $map 1 end] {
    set pc [xschem instance_pin_coord $name name $pin]   ;# "{pin} x y"
    if {[llength $pc] >= 3} { lappend coords [list [lindex $pc 1] [lindex $pc 2]] }
  }
  return $coords
}
# does axis-aligned segment s pass through the OPEN interior of rect r? (edge contact is ok --
# a pin/tap on the boundary is not a crossing). Same closed-box family as seg_touch, but the
# strict > / < makes it the OPEN interior (spec §4 P5 "interior").
proc seg_in_rect_interior {s r} {
  lassign [_seg_bounds $s] sxlo sylo sxhi syhi
  lassign [_seg_bounds $r] rxlo rylo rxhi ryhi
  expr {$sxhi > $rxlo && $sxlo < $rxhi && $syhi > $rylo && $sylo < $ryhi}
}
proc p5_no_body_cross {} {
  set nw [xschem get wires]
  set ni [xschem get instances]
  for {set k 0} {$k < $ni} {incr k} {
    if {[xschem getprop instance $k lab] ne {}} continue   ;# net label -> not a body obstacle
    set nm  [xschem getprop instance $k name]
    set box [_inst_body_box $nm]
    set pins [_inst_pin_coords $nm]
    for {set w 0} {$w < $nw} {incr w} {
      set s [xschem wire_coord $w]
      if {![seg_in_rect_interior $s $box]} continue
      lassign $s x1 y1 x2 y2
      set exempt 0
      foreach p $pins {
        lassign $p px py
        if {($x1 == $px && $y1 == $py) || ($x2 == $px && $y2 == $py)} { set exempt 1; break }
      }
      if {!$exempt} { return 0 }
    }
  }
  return 1
}

# --- P3: pin escape (first leg perpendicular to the pin edge) ----------------
# Spec §4 P3 + §6: the first leg of every wire leaving a pin must be PERPENDICULAR to the
# pin's edge (the outward escape normal), length >= Lmin, and must not re-enter the body.
#
# Escape normal via §6 OPTION 1 (pin nearest-edge geometry), the option the spec prefers over
# the crude centroid heuristic (option 3). The pin sits on/near one edge of the instance body
# box; the outward normal is that edge's direction. This is the Tcl stand-in for the Phase-2
# C getter get_pin_escape_normal(). Caveat: it uses the world `Instance:` box (includes attr
# text); that is safe here because a pin sits near the body outline and FAR from the text
# side, so the nearest edge is the correct body edge. DEVICE pins only -- a net label has zero
# body extent and no meaningful escape direction (spec §2), so p3 is not applied to labels.
#
# outward escape normal of pin `pin` on instance `inst` -> {nx ny}, a unit axis vector
proc pin_escape_normal {inst pin} {
  set pc [xschem instance_pin_coord $inst name $pin]     ;# "{pin} x y"
  set px [lindex $pc 1]; set py [lindex $pc 2]
  lassign [_seg_bounds [_inst_body_box $inst]] x1 y1 x2 y2   ;# normalized xlo ylo xhi yhi
  set dl [expr {abs($px - $x1)}]                          ;# distance to each edge
  set dr [expr {abs($px - $x2)}]
  set db [expr {abs($py - $y1)}]
  set dt [expr {abs($py - $y2)}]
  set m [expr {min($dl, $dr, $db, $dt)}]
  if {$m == $dl} { return {-1 0} }
  if {$m == $dr} { return {1 0} }
  if {$m == $db} { return {0 -1} }
  return {0 1}
}
# P3: for instance `inst`, every wire leaving one of its pins escapes along that pin's
# outward normal, length >= Lmin, and its far end clears the body interior (no re-entry).
proc p3_escape_perp {inst {Lmin 0}} {
  set map [xschem instance_nodemap $inst]
  lassign [_seg_bounds [_inst_body_box $inst]] rx1 ry1 rx2 ry2
  set nw [xschem get wires]
  foreach {pin node} [lrange $map 1 end] {
    set pc [xschem instance_pin_coord $inst name $pin]
    if {[llength $pc] < 3} continue
    set px [lindex $pc 1]; set py [lindex $pc 2]
    lassign [pin_escape_normal $inst $pin] nx ny
    for {set i 0} {$i < $nw} {incr i} {
      lassign [xschem wire_coord $i] x1 y1 x2 y2
      set ox {}; set oy {}
      if {$x1 == $px && $y1 == $py} { set ox $x2; set oy $y2 } \
      elseif {$x2 == $px && $y2 == $py} { set ox $x1; set oy $y1 }
      if {$ox eq {}} continue                              ;# wire not incident to this pin
      set dx [expr {$ox - $px}]; set dy [expr {$oy - $py}]
      set sx [expr {$dx > 0 ? 1 : ($dx < 0 ? -1 : 0)}]
      set sy [expr {$dy > 0 ? 1 : ($dy < 0 ? -1 : 0)}]
      if {$sx != $nx || $sy != $ny} { return 0 }           ;# not perpendicular-outward
      if {[expr {abs($dx) + abs($dy)}] < $Lmin} { return 0 }  ;# stub too short
      if {$ox > $rx1 && $ox < $rx2 && $oy > $ry1 && $oy < $ry2} { return 0 }  ;# re-enters body
    }
  }
  return 1
}

# --- P6: minimality (bends, then length) ------------------------------------
# Spec §4 P6: minimize Σbends, THEN Σlength, over routes satisfying P1-P5. Unlike the boolean
# predicates this is a lexicographic METRIC, so it is compared against a REFERENCE -- the
# hand-authored "nice" route's (bends,len) (spec §7: P6 is the one predicate that needs a
# golden oracle). p6_bends_len holds iff the current route is NO WORSE than the reference.
#
# direction of an axis-aligned segment: H horizontal, V vertical, P degenerate (point)
proc _wire_dir {s} {
  lassign $s x1 y1 x2 y2
  if {$x1 == $x2 && $y1 == $y2} { return P }
  if {$y1 == $y2} { return H }
  return V
}
# total Manhattan wire length (each leg is axis-aligned, so |dx|+|dy| is its length)
proc route_length {} {
  set L 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    set L [expr {$L + abs($x2 - $x1) + abs($y2 - $y1)}]
  }
  return $L
}
# number of BENDS = corner vertices: a point where exactly two wire ENDPOINTS meet, with
# PERPENDICULAR directions, and NO wire passing through it. This deliberately excludes:
# collinear splits (two same-direction ends -> a straight pass, 0 bends), T-junctions and
# crossings (a through-wire at the vertex -> a branch, not a direction change).
proc route_bends {} {
  set nw [xschem get wires]
  set segs {}
  array set ends {}                            ;# "px,py" -> list of dirs of wires ENDING there
  for {set i 0} {$i < $nw} {incr i} {
    set c [xschem wire_coord $i]
    lappend segs $c
    lassign $c x1 y1 x2 y2
    lappend ends($x1,$y1) [_wire_dir $c]
    lappend ends($x2,$y2) [_wire_dir $c]
  }
  set bends 0
  foreach pt [array names ends] {
    lassign [split $pt ,] px py
    if {[llength $ends($pt)] != 2} continue    ;# not a degree-2 endpoint vertex
    lassign $ends($pt) d1 d2
    if {$d1 eq $d2 || $d1 eq "P" || $d2 eq "P"} continue   ;# collinear / degenerate, not a bend
    set through 0
    foreach c $segs {
      lassign $c x1 y1 x2 y2
      if {($px == $x1 && $py == $y1) || ($px == $x2 && $py == $y2)} continue  ;# endpoint, not through
      if {$px >= min($x1,$x2) && $px <= max($x1,$x2) && $py >= min($y1,$y2) && $py <= max($y1,$y2) &&
          (($x1 == $x2 && $px == $x1) || ($y1 == $y2 && $py == $y1))} { set through 1; break }
    }
    if {!$through} { incr bends }
  }
  return $bends
}
# P6: is the current route no worse than the reference, comparing bends first then length?
proc p6_bends_len {ref_bends ref_len} {
  set b [route_bends]; set l [route_length]
  expr {$b < $ref_bends || ($b == $ref_bends && $l <= $ref_len)}
}

# --- P7: stability ---------------------------------------------------------
# Wires NOT attached to the dragged instance must be left byte-identical: the reroute stays
# local, the diff small, the user's mental model intact (spec §4 P7). The caller declares
# the segments that must survive untouched (each as {x1 y1 x2 y2}, any endpoint order); the
# predicate asserts each is still present. New stubs are allowed (superset check) -- P7
# guards against destroying/altering the stable set, not against adding to it.
proc p7_stability {stable_segs} {
  foreach s $stable_segs { if {![has_seg {*}$s]} { return 0 } }
  return 1
}
