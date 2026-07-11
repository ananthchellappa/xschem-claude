# Delta-sweep fuzzer harness -- hardening sprint Track C, step C1.
# Spec: doc/claude/suggestions/hardening_sprint_plan.md (Track C); WIRING.md §10-§11.
#
# WHAT THIS IS. A machine that drops a device across a fixture at a grid of deltas and
# GESTURES, then runs the P-predicate assertion pack against each drop -- so a "next 0105"
# (a silent saved short, a stale-anchor tail, a non-Manhattan save) is FOUND by the sweep,
# not by a user. The whole thing runs TRUE HEADLESS (--nogui, has_x=0): the scripted move
# path (`xschem move_objects`) is byte-identical to the interactive drag's RELEASE
# (WIRING.md §0.7), and -- verified this session -- a mid-drag rotate/flip injected via
# `xschem rotate_in_place`/`flip_in_place` while STARTMOVE is active is ALSO headless-safe
# (draw_selection is a no-op with has_x=0). No X server, no xvfb, deterministic.
#
# COVERAGE BOUNDARY (state it, don't hide it -- WIRING.md §0.7): the scripted path
# reproduces RELEASE-topology bugs only. A PER-MOTION commit bug (the 0109 class, where an
# intermediate pointer waypoint commits a short that a later waypoint hides) needs real
# pointer waypoints under X and is out of this fuzzer's reach -- those stay in the gesture
# suite. The sweep is the release-topology net; the gesture suite is the per-motion net.
#
# Reuses tests/headless/wireedit/{fixtures.tcl,predicates.tcl} (P1/P2/Manhattan/net helpers).
# Source THIS file; it sources those. Public procs:
#   fuzz_load    {fixture}            -- load a tests/from_user fixture headless + set gates
#   fuzz_snapshot {}                  -- capture the before-state the assertion pack diffs
#   fuzz_apply   {gesture}            -- select the target + run the scripted gesture
#   fuzz_assert  {snap gesture}       -- run the assertion pack (C1: P1+P2; C2 extends to 5)
#   fuzz_drop    {fixture gesture}    -- load->snapshot->apply->assert; returns a verdict dict
#   fuzz_spec_line {fixture gesture}  -- the one-line replayable reproducer (C3 writes files)
#
# GESTURE SPEC = a Tcl dict: {target <inst> type <t> dx <n> dy <n>}, where type is one of
#   stretch  plain/m connected stretch          (one-shot move_objects, == release)
#   rot      m + ALT-R   (one rotate_in_place)
#   rot2     m + ALT-R x2 (two rotate_in_place)
#   flip     m + ALT-F   (one flip_in_place)
#   split    the same (dx,dy) delivered as TWO half-drops (re-selecting between)
# (In cadence_compat a plain LMB drag and the 'm' key are the SAME path -- WIRING.md §2.1 --
#  so "plain drag" and "m-stretch" collapse to the one `stretch` type.)

set ::FUZZ_HERE [file dirname [file normalize [info script]]]
source [file join $::FUZZ_HERE .. wireedit fixtures.tcl]
source [file join $::FUZZ_HERE .. wireedit predicates.tcl]

# The user's launch environment (cadence_style_rc): reproduce bugs in THAT mode, or the
# whole fluid engine is gated off (fluid_editing) and the sweep tests naive routing.
proc fuzz_gates {} {
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 0}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  uplevel #0 {set fluid_enforce_invariants 1}   ;# B3 enforcement is the shipped default
}

# Load a tests/from_user fixture by bare name (e.g. before_8) TRUE HEADLESS.
proc fuzz_load {fixture} {
  fuzz_gates
  xschem load [file join $::FUZZ_HERE .. .. from_user $fixture.sch]
  xschem resolved_net 0
}

# ---- gesture engine -------------------------------------------------------
# A device's grab anchor = its body origin (what the user grabs). For a plain stretch the
# anchor is irrelevant to the RELEASE output (the follow set is pin-driven, and the one-shot
# form leaves mousex_snap stale yet is byte-identical -- wireedit proves this), so `stretch`
# and each `split` half use the one-shot form. A mid-drag ROTATE/FLIP must be injected while
# STARTMOVE is live, so those use the start/verb/end form, anchored at the body origin.
proc _fuzz_inst_origin {inst} {
  set c [xschem instance_coord $inst]
  return [list [lindex $c 2] [lindex $c 3]]
}
proc _fuzz_select {inst} { xschem unselect_all; xschem select instance $inst }

# one-shot connected stretch by (dx,dy) -- the release path
proc _fuzz_stretch {inst dx dy} {
  _fuzz_select $inst
  xschem move_objects $dx $dy stretch kissing
}
# start/verb/end connected stretch with mid-drag transform verbs (ALT-R = rotate_in_place,
# ALT-F = flip_in_place). Anchored at the body origin. `end <dx> <dy>` = explicit total delta.
proc _fuzz_transform {inst dx dy verbs} {
  _fuzz_select $inst
  lassign [_fuzz_inst_origin $inst] ax ay
  xschem move_objects start $ax $ay stretch kissing
  foreach v $verbs { xschem $v }
  xschem move_objects end $dx $dy
}

# Apply a gesture spec to the current schematic.
proc fuzz_apply {gesture} {
  set inst [dict get $gesture target]
  set dx   [dict get $gesture dx]
  set dy   [dict get $gesture dy]
  switch -- [dict get $gesture type] {
    stretch { _fuzz_stretch   $inst $dx $dy }
    rot     { _fuzz_transform $inst $dx $dy {rotate_in_place} }
    rot2    { _fuzz_transform $inst $dx $dy {rotate_in_place rotate_in_place} }
    flip    { _fuzz_transform $inst $dx $dy {flip_in_place} }
    split {
      # deliver (dx,dy) as two half-drops, re-selecting between (a saved intermediate state).
      set hx [expr {int($dx / 2)}]; set hy [expr {int($dy / 2)}]
      _fuzz_stretch $inst $hx $hy
      _fuzz_stretch $inst [expr {$dx - $hx}] [expr {$dy - $hy}]
    }
    default { error "fuzz_apply: unknown gesture type '[dict get $gesture type]'" }
  }
}

# ---- before-state snapshot ------------------------------------------------
# Everything the assertion pack diffs against. A dict so it grows without churning callers.
# Captures the connectivity PARTITION (name-invariant), P2-device (device-pin map), the
# intended label nets (P2-label), the geometry (segset), and -- for the C2 move-relative
# QUALITY checks -- the diagonal count, the dangling-endpoint set, and the total copper length.
proc fuzz_snapshot {} {
  dict create \
    part [fuzz_partition] \
    p2   [dev_pin_map] \
    lab  [fuzz_label_nets] \
    geo  [segset] \
    diag [fuzz_count_diag] \
    dang [fuzz_dangling_eps] \
    len  [route_length]
}

# Name-INVARIANT connectivity partition: the set of device-pin groups, each group = the pins
# that share a net. Keyed by pin identity, NOT by net name, so a benign #netN RENUMBER (nets
# are numbered in traversal order and shuffle when a reroute changes that order -- WIRING.md
# §5: "never compare across rebuilds, use partition vectors") does NOT read as a connectivity
# change. A real merge collapses two groups into one; a real disconnect splits a group -- both
# change the set-of-groups and ARE caught. Label instances are skipped (instance_nodemap
# echoes a label's own lab=, the P1/P2 echo trap).
proc fuzz_partition {} {
  xschem resolved_net 0
  set ni [xschem get instances]
  array unset g
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i lab] ne {}} continue
    set nm [xschem getprop instance $i name]
    foreach {pin net} [lrange [xschem instance_nodemap $nm] 1 end] {
      if {$net eq {}} continue                 ;# floating pin: not part of any group
      lappend g($net) "$nm:$pin"
    }
  }
  set parts {}
  foreach net [array names g] { lappend parts [lsort $g($net)] }
  return [lsort $parts]
}
proc fuzz_partition_preserved {before} { expr {[fuzz_partition] eq $before} }

# The set of intended net LABELS (lab= on any instance) present now. A label states net
# intent; if it later vanishes from the wire nets, two nets the user NAMED distinctly merged.
proc fuzz_label_nets {} {
  set s {}
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    set lab [xschem getprop instance $i lab]
    if {$lab ne {}} { lappend s $lab }
  }
  return [lsort -unique $s]
}
# Move-relative label-conflict check: every label net that existed BEFORE still resolves to a
# distinct wire net AFTER. (This is p2_no_short's arm (b), made before-relative so a fixture
# without the label isn't judged against it, and a dragged label is judged against its own
# pre-state.)
proc fuzz_labels_survive {before_labs} {
  xschem resolved_net 0
  set nw [xschem get wires]; set wirenets {}
  for {set i 0} {$i < $nw} {incr i} {
    set wn [xschem getprop wire $i lab]
    if {[lsearch -exact $wirenets $wn] < 0} { lappend wirenets $wn }
  }
  foreach l $before_labs { if {[lsearch -exact $wirenets $l] < 0} { return 0 } }
  return 1
}

# ---- C2 QUALITY checks (move-relative: judge only what the MOVE introduced) --------------
# Quality objectives (P3>P5>P4>P7>P6, WIRING.md §9): NOT hard invariants -- a relay may legally
# save a diagonal ("electrically correct beats pretty"). A quality failure flags a route
# REGRESSION (AMBER), never corruption (RED). Each is scoped to novelty so a pre-existing
# condition in the fixture (before_8's benign crossing, a stationary user stub) is not blamed
# on the move.

# (2) Manhattan: the move introduced no NEW diagonal wire. Fixtures start all-Manhattan, so
# `diag_after <= diag_before` == "no novel diagonal". count_diag = # of non-axis-aligned wires.
proc fuzz_count_diag {} {
  set n 0; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 != $x2 && $y1 != $y2} { incr n }
  }
  return $n
}
proc fuzz_no_novel_diag {before_diag} { expr {[fuzz_count_diag] <= $before_diag} }

# (3) No novel dangling end: a wire endpoint touching NO pin and NO other wire is a dangling
# tail (the 0103/0104 stale-anchor residue class). The move must add none: dangling set AFTER
# subset of BEFORE (pre-existing user stubs are stationary and stay in both). Ported from
# test_rotate_stretch_short_0104 (on_seg / allpins / allwires / dangling_eps).
proc fuzz_allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
proc fuzz_allpins {} {
  set P {}; set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    set nm [xschem getprop instance $i name]
    if {$nm eq ""} continue
    foreach {pin net} [lrange [xschem instance_nodemap $nm] 1 end] {
      set pc [xschem instance_pin_coord $nm name $pin]
      if {[llength $pc] >= 3} { lappend P [lindex $pc 1] [lindex $pc 2] }
    }
  }
  return $P
}
proc fuzz_on_seg {x y a b c d {tol 0.01}} {
  set cross [expr {($c-$a)*($y-$b) - ($d-$b)*($x-$a)}]
  set len   [expr {hypot($c-$a, $d-$b)}]
  if {$len == 0} { return [expr {abs($x-$a) < $tol && abs($y-$b) < $tol}] }
  if {abs($cross)/$len > $tol} { return 0 }
  set dot [expr {($x-$a)*($c-$a) + ($y-$b)*($d-$b)}]
  if {$dot < -$tol || $dot > $len*$len+$tol} { return 0 }
  return 1
}
proc fuzz_dangling_eps {} {
  set ws [fuzz_allwires]; set ps [fuzz_allpins]; set D {}
  set nw [llength $ws]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [lindex $ws $i] x1 y1 x2 y2
    foreach {ex ey} [list $x1 $y1 $x2 $y2] {
      set hit 0
      foreach {px py} $ps { if {abs($px-$ex) < 0.6 && abs($py-$ey) < 0.6} { set hit 1; break } }
      if {!$hit} {
        for {set j 0} {$j < $nw} {incr j} {
          if {$j == $i} continue
          lassign [lindex $ws $j] a b c d
          if {[fuzz_on_seg $ex $ey $a $b $c $d]} { set hit 1; break }
        }
      }
      if {!$hit} { lappend D [list $ex $ey] }
    }
  }
  return $D
}
proc fuzz_no_novel_dangling {before_eps} {
  foreach e [fuzz_dangling_eps] {
    lassign $e ex ey; set found 0
    foreach p $before_eps { lassign $p px py
      if {abs($px-$ex) < 0.6 && abs($py-$ey) < 0.6} { set found 1; break } }
    if {!$found} { return 0 }        ;# a dangling end the move CREATED
  }
  return 1
}

# (4) No novel copper through a stationary instance body: a NOVEL wire (segset entry absent
# from the pre-set) crossing an instance body interior, with neither endpoint on that
# instance's own pins (the P5 through-cross, WIRING.md §4 P5). Reuses predicates.tcl's
# _inst_pin_coords / seg_in_rect_interior, but uses the TIGHT symbol-graphic box (below), NOT
# predicates.tcl's _inst_body_box (the text-inflated `Instance:` box): the inflated box false-
# flags a wire that merely passes under a device's attribute text (e.g. the 0105 backbone bump
# at y=-50 clips R18's value-text region but clears its real body by 2.5 units).

# xschem's ROTATION macro (xschem.h:386): flip first (about x0), then rotate rot*90 about
# pivot (x0,y0). Verbatim port so the transformed corners match the C engine exactly.
proc _fuzz_rotation {rot flip x0 y0 x y} {
  set xxtmp [expr {$flip ? 2*$x0 - $x : $x}]
  switch -- $rot {
    0 { return [list $xxtmp $y] }
    1 { return [list [expr {$x0 - $y + $y0}] [expr {$y0 + $xxtmp - $x0}]] }
    2 { return [list [expr {2*$x0 - $xxtmp}] [expr {2*$y0 - $y}]] }
    default { return [list [expr {$x0 + $y - $y0}] [expr {$y0 - $xxtmp + $x0}]] }
  }
}
# The instance's SYMBOL graphic box (no attribute text) transformed to world coords -> {x1 y1
# x2 y2}. instance_bbox prints both `Instance:` (text-inflated) and `Symbol:` (tight, symbol-
# local, centered on the origin); transform the tight box's 4 corners about the instance origin.
proc _inst_symbol_box_world {name} {
  set bb [xschem instance_bbox $name]
  if {![regexp {Symbol:\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $bb -> sx1 sy1 sx2 sy2]} {
    return [_inst_body_box $name]                ;# fallback: conservative Instance box
  }
  set c [xschem instance_coord $name]
  set x0 [lindex $c 2]; set y0 [lindex $c 3]; set rot [lindex $c 4]; set flip [lindex $c 5]
  set xs {}; set ys {}
  foreach {sx sy} [list $sx1 $sy1 $sx2 $sy1 $sx2 $sy2 $sx1 $sy2] {
    lassign [_fuzz_rotation $rot $flip $x0 $y0 [expr {$x0+$sx}] [expr {$y0+$sy}]] wx wy
    lappend xs $wx; lappend ys $wy
  }
  set xlo [lindex $xs 0]; set xhi $xlo; set ylo [lindex $ys 0]; set yhi $ylo
  foreach v $xs { if {$v < $xlo} {set xlo $v}; if {$v > $xhi} {set xhi $v} }
  foreach v $ys { if {$v < $ylo} {set ylo $v}; if {$v > $yhi} {set yhi $v} }
  return [list $xlo $ylo $xhi $yhi]
}
proc fuzz_no_novel_body_cross {pre_geo} {
  set nw [xschem get wires]; set ni [xschem get instances]
  for {set k 0} {$k < $ni} {incr k} {
    if {[xschem getprop instance $k lab] ne {}} continue     ;# label: not a body obstacle
    set nm [xschem getprop instance $k name]
    set box [_inst_symbol_box_world $nm]; set pins [_inst_pin_coords $nm]
    for {set w 0} {$w < $nw} {incr w} {
      set s [we_norm [xschem wire_coord $w]]
      if {[lsearch -exact $pre_geo $s] >= 0} continue        ;# not novel
      if {![seg_in_rect_interior $s $box]} continue
      lassign $s x1 y1 x2 y2; set exempt 0
      foreach p $pins { lassign $p px py
        if {($x1 == $px && $y1 == $py) || ($x2 == $px && $y2 == $py)} { set exempt 1; break } }
      if {!$exempt} { return 0 }
    }
  }
  return 1
}

# (5) Copper budget: the move's total-length GROWTH must stay within k*(|dx|+|dy|) + slack.
# NB the plan said "novel length" (segset-diff), but that counts the whole TRANSLATED follow
# set (every follow wire lands at a novel coordinate), giving ratios of 5-13x the Manhattan
# distance on clean drops -- useless. TOTAL-length growth is the right metric: a rigid
# translation preserves length, so a clean drag grows length by O(|delta|) (measured
# grow/|man| in [-2,+2] across fixtures), while a runaway detour / staircase blowup grows it
# far more. k=3, slack=100 clears every clean landed drop with margin. (A same-length
# monotone staircase -- extra bends, equal length -- is a bend-count axis this does not cover;
# revisited if C3's 0111 revert needs it.)
proc fuzz_within_budget {before_len dx dy {k 3} {slack 100}} {
  set grow [expr {[route_length] - $before_len}]
  expr {$grow <= $k*(abs($dx)+abs($dy)) + $slack}
}

# ---- assertion pack (5 checks: 3 HARD electrical + 4 folded into hard/quality) -------------
# Returns a list of {name ok severity} triples. severity is `hard` (a violation = saved
# corruption = RED) or `quality` (a violation = a route REGRESSION = AMBER, never RED).
#
# WHY NOT the absolute p2_no_short: its geometric arm (a) uses seg_touch (bbox overlap), which
# flags a distinct-net CROSSING (two nets sharing a mid-span point with NO junction dot) like a
# real short. before_8 SHIPS such a benign crossing (its #net3 riser at x=-80 crosses the #net1
# backbone at y=-40, no shared endpoint -> touch() does NOT merge them -> two distinct nets, no
# electrical short), so p2_no_short is 0 on the pristine fixture and can never pass. The
# before_8 wireedit tests (53/54) already sidestep it and use p2_no_device_merge. So P2 is
# MOVE-RELATIVE electrical:
#   (1) P1  connectivity: the device-pin GROUPING (partition) is unchanged -- name-invariant,
#       so a benign #netN renumber under a reroute is not a false RED (WIRING.md §5).
#       P2-device: no instance had two distinct-net pins MERGE onto one net (R18/v8 short).
#       P2-label:  every net the user NAMED (lab=) still resolves to a distinct wire net.
#   (2) Manhattan: no NEW diagonal wire.                         [quality]
#   (3) no novel dangling end: dangling set AFTER subset BEFORE. [quality]
#   (4) no novel copper through a stationary instance body.      [quality]
#   (5) copper budget: total-length growth <= k*(|dx|+|dy|)+slack. [quality]
proc fuzz_assert {snap gesture} {
  set dx [dict get $gesture dx]; set dy [dict get $gesture dy]
  set r {}
  lappend r [list P1_connectivity  [fuzz_partition_preserved [dict get $snap part]]      hard]
  lappend r [list P2_no_dev_merge   [p2_no_device_merge [dict get $snap p2]]             hard]
  lappend r [list P2_labels_survive [fuzz_labels_survive [dict get $snap lab]]           hard]
  lappend r [list Q_manhattan       [fuzz_no_novel_diag [dict get $snap diag]]           quality]
  lappend r [list Q_no_dangling     [fuzz_no_novel_dangling [dict get $snap dang]]       quality]
  lappend r [list Q_no_body_cross   [fuzz_no_novel_body_cross [dict get $snap geo]]      quality]
  lappend r [list Q_copper_budget   [fuzz_within_budget [dict get $snap len] $dx $dy]    quality]
  return $r
}

# The device's body origin translates by exactly (dx,dy) on a committed drop -- even under a
# mid-drag rotate_in_place/flip_in_place (ROTATELOCAL keeps the origin and adds the delta;
# verified this session: R18 (-40,0) + rot + (-30,70) -> (-70,70)). So origin_post ==
# origin_pre + (dx,dy) IFF the move committed. If the origin is unchanged (delta != 0) the
# move was REFUSED (B3 rolled it back to pristine) -- a DISTINCT outcome from a clean route,
# and the reason "pins distinct + no short" must NOT be read as success (plan C4 note).
proc _fuzz_landed {inst pre dx dy} {
  lassign $pre px py
  lassign [_fuzz_inst_origin $inst] qx qy
  expr {$qx == $px + $dx && $qy == $py + $dy}
}

# ---- one drop -------------------------------------------------------------
# Load, snapshot, apply, assert. Returns a dict:
#   verdict  GREEN | RED | REFUSED | AMBER   (priority RED > REFUSED > AMBER > GREEN)
#            RED     = a HARD check FAILED -- saved electrical corruption (the sweep's target).
#            REFUSED = hard-clean but the device did NOT move (B3 enforcement rolled it back;
#                      no corruption saved, but the drag produced no route).
#            AMBER   = landed + hard-clean, but a QUALITY check failed -- a route regression
#                      (extra copper / diagonal / dangling / body-cross), not corruption.
#            GREEN   = landed at the requested delta AND every check (hard + quality) passed.
#   checks   {{name ok severity} ...}
#   fails    the names of the failing checks (empty on GREEN)
#   landed   1|0
#   spec     the replayable one-line reproducer
proc fuzz_drop {fixture gesture} {
  fuzz_load $fixture
  set snap [fuzz_snapshot]
  set inst [dict get $gesture target]
  set pre  [_fuzz_inst_origin $inst]
  fuzz_apply $gesture
  set checks [fuzz_assert $snap $gesture]
  set hard_ok 1; set qual_ok 1; set fails {}
  foreach c $checks {
    lassign $c name ok sev
    if {!$ok} {
      lappend fails $name
      if {$sev eq "hard"} { set hard_ok 0 } else { set qual_ok 0 }
    }
  }
  set landed [_fuzz_landed $inst $pre [dict get $gesture dx] [dict get $gesture dy]]
  set verdict [expr {!$hard_ok ? "RED" : (!$landed ? "REFUSED" : (!$qual_ok ? "AMBER" : "GREEN"))}]
  dict create \
    verdict $verdict \
    checks  $checks \
    fails   $fails \
    landed  $landed \
    spec    [fuzz_spec_line $fixture $gesture]
}

# The replayable reproducer line: a single `fuzz_drop` call C3 can drop into a standalone
# RED test. Deterministic (no timestamps) so the same drop always yields the same line.
proc fuzz_spec_line {fixture gesture} {
  return "fuzz_drop $fixture {target [dict get $gesture target] type [dict get $gesture type] dx [dict get $gesture dx] dy [dict get $gesture dy]}"
}

# A filesystem-safe tag for a drop (C3 replay filenames). e.g. before_8_R18_stretch_m90_m40
proc fuzz_tag {fixture gesture} {
  set sx [expr {[dict get $gesture dx] < 0 ? "m[expr {-[dict get $gesture dx]}]" : [dict get $gesture dx]}]
  set sy [expr {[dict get $gesture dy] < 0 ? "m[expr {-[dict get $gesture dy]}]" : [dict get $gesture dy]}]
  return "${fixture}_[dict get $gesture target]_[dict get $gesture type]_${sx}_${sy}"
}
