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
# Everything the assertion pack (C2) diffs against. A dict so it grows without churning
# callers. C1 captures the connectivity PARTITION (name-invariant), P2-device (device-pin
# map), the intended label nets (P2-label), and geometry (segset).
proc fuzz_snapshot {} {
  dict create \
    part [fuzz_partition] \
    p2   [dev_pin_map] \
    lab  [fuzz_label_nets] \
    geo  [segset]
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

# ---- assertion pack (C1: the HARD electrical invariants; C2 adds Manhattan/dangle/body/budget) ---
# Returns a list of {name ok} pairs. A drop is GREEN iff every ok is 1.
#
# WHY NOT the absolute p2_no_short: that predicate's geometric arm (a) uses seg_touch (bbox
# overlap), which flags a distinct-net CROSSING (two nets sharing a mid-span point with NO
# junction dot) exactly like a real short. before_8 SHIPS with such a benign crossing (its
# #net3 riser at x=-80 crosses the #net1 backbone at y=-40, no shared endpoint -> touch() does
# NOT merge them -> two distinct nets, no electrical short), so p2_no_short is 0 on the pristine
# fixture and can never pass. The before_8-based wireedit tests (53/54) already sidestep it and
# use p2_no_device_merge. So the fuzzer's electrical P2 is MOVE-RELATIVE:
#   P1  connectivity: the device-pin GROUPING (partition) is unchanged -- name-invariant, so a
#      benign #netN renumber under a reroute is not a false RED (WIRING.md §5).
#   P2-device: no instance had two distinct-net pins MERGE onto one net (the R18/v8 short class).
#   P2-label:  every net the user NAMED (lab=) still resolves to a distinct wire net.
# (A NEW geometric crossing that the *move* introduces -- a quality regression, not an electrical
#  short -- is a C2 novelty-scoped check, not a hard electrical verdict here.)
proc fuzz_assert {snap gesture} {
  set r {}
  lappend r [list P1_connectivity  [fuzz_partition_preserved [dict get $snap part]]]
  lappend r [list P2_no_dev_merge   [p2_no_device_merge [dict get $snap p2]]]
  lappend r [list P2_labels_survive [fuzz_labels_survive [dict get $snap lab]]]
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
#   verdict  GREEN | RED | REFUSED
#            GREEN   = the device landed at the requested delta AND every hard check passed
#            RED     = a hard check (P1/P2/...) FAILED -- a saved violation (the sweep target)
#            REFUSED = every hard check passed but the device did NOT move (B3 enforcement
#                      rolled the whole gesture back; no corruption saved, but no route either)
#   checks   {{name ok} ...}
#   landed   1|0
#   spec     the replayable one-line reproducer
proc fuzz_drop {fixture gesture} {
  fuzz_load $fixture
  set snap [fuzz_snapshot]
  set inst [dict get $gesture target]
  set pre  [_fuzz_inst_origin $inst]
  fuzz_apply $gesture
  set checks [fuzz_assert $snap $gesture]
  set clean 1
  foreach c $checks { if {![lindex $c 1]} { set clean 0 } }
  set landed [_fuzz_landed $inst $pre [dict get $gesture dx] [dict get $gesture dy]]
  set verdict [expr {!$clean ? "RED" : ($landed ? "GREEN" : "REFUSED")}]
  dict create \
    verdict $verdict \
    checks  $checks \
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
