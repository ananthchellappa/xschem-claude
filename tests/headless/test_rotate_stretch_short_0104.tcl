# issue 0104: ALT-R (rotate-in-place) during a connected stretch must not SHORT the two nets
# across the moved device when one pin's follow route passes through the sibling pin's STALE
# pristine anchor.
#
# Repro (tests/from_user/before_7.sch -> after_21.sch): select R18, press 'm' (cadence connected
# stretch), drag, ALT-R mid-drag, keep dragging, drop at delta (-30,70). R18's rotated top pin
# lands at x=-120 -- the pristine bottom-pin anchor's own column -- so its straight follow route
# runs exactly through the anchor point (-120,-40) that the bottom pin's elbow far leg still
# reaches back to. The endpoint touch merges #net1+#net2 across R18; every accept-ladder attempt
# is equally shorted (partition_changed=4 on all three), so the shorted ortho result is kept and
# saved. One grid further left or right is clean (0103 territory) -- only the colliding column
# shorts. Fixed by fluid_prune_shorting_anchor_tails (delete-only, commits a doom only when the
# pin-partition becomes equivalent to the START snapshot again). See
# doc/claude/issues/0104-rotate-stretch-sibling-routes-collide-at-stale-anchor.md.
#
# Discriminator: R18.P ne R18.M (the short collapses them to one net) + the full structural
# partition; dangle SET-subset + user-stub-survival guard the delete-only prune against
# over-deletion; placement asserts keep every case anti-vacuous.
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_rotate_stretch_short_0104.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- 0104 stale-anchor short test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0
set ::nchecks 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  incr ::nchecks
  if {!$ok} {incr ::fails}
}

set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256 ; set Mod1Mask 8
set KSYM_m 109 ; set KSYM_r 114 ; set KSYM_f 102

proc screen {chx chy} {   ;# schematic -> callback coords (inverse of xschem's x*zoom-xorigin)
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($chx+$xo)/$zm)}] [expr {int(($chy+$yo)/$zm)}]
}
proc find_inst {name} {
  set n [xschem get instances]
  for {set i 0} {$i<$n} {incr i} { if {[xschem getprop instance $i name] eq $name} { return $i } }
  return -1
}
proc pinnet {inst pin} { lindex [xschem instance_nodemap $inst $pin] 2 }

set ::HERE [file dirname [file normalize [info script]]]

proc load_fixture {} {
  xschem load [file join $::HERE .. from_user before_7.sch]
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0
  set ::cadence_compat 1
  xschem set fluid_editing 1
  set ::orthogonal_wiring 1
  xschem zoom_full; update idletasks
}

# same in-place gesture as the 0100/0103 tests: m at grab, MOTION, nrot x ALT-r (+ optional ALT-f)
# at the mid-drag point, MOTION on, drop at schematic delta (dx,dy) from grab (R18 body center).
proc gesture_ip {nrot doflip dx dy {gx -120} {gy -80}} {
  global WIN KP BP BR MOTION Button1Mask Mod1Mask KSYM_m KSYM_r KSYM_f
  set r18 [find_inst R18]
  lassign [screen $gx $gy] sx sy
  lassign [screen [expr {$gx+10}] [expr {$gy+30}]] m1x m1y
  lassign [screen [expr {$gx+30}] [expr {$gy+50}]] m2x m2y
  lassign [screen [expr {$gx+$dx}] [expr {$gy+$dy}]] tx ty
  xschem unselect_all; xschem select instance $r18
  xschem callback $WIN $KP $sx $sy $KSYM_m 0 0 0
  xschem callback $WIN $MOTION $m1x $m1y 0 0 0 0
  for {set i 0} {$i<$nrot} {incr i} { xschem callback $WIN $KP $m1x $m1y $KSYM_r 0 0 $Mod1Mask }
  if {$doflip} { xschem callback $WIN $KP $m1x $m1y $KSYM_f 0 0 $Mod1Mask }
  xschem callback $WIN $MOTION $m2x $m2y 0 0 0 0
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP $tx $ty 0 1 0 0
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks
}

# ---------- dangling-endpoint machinery (as 0103) ----------
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
proc allpins {} {   ;# every instance pin coordinate {x y ...}
  set P {}
  set n [xschem get instances]
  for {set i 0} {$i<$n} {incr i} {
    set nm [xschem getprop instance $i name]
    if {$nm eq ""} continue
    foreach {pin net} [lrange [xschem instance_nodemap $nm] 1 end] {
      set pc [xschem instance_pin_coord $nm name $pin]
      if {[llength $pc] >= 3} { lappend P [lindex $pc 1] [lindex $pc 2] }
    }
  }
  return $P
}
proc on_seg {x y a b c d {tol 0.01}} {
  set cross [expr {($c-$a)*($y-$b) - ($d-$b)*($x-$a)}]
  set len   [expr {hypot($c-$a, $d-$b)}]
  if {$len == 0} { return [expr {abs($x-$a)<$tol && abs($y-$b)<$tol}] }
  if {abs($cross)/$len > $tol} { return 0 }
  set dot [expr {($x-$a)*($c-$a) + ($y-$b)*($d-$b)}]
  if {$dot < -$tol || $dot > $len*$len+$tol} { return 0 }
  return 1
}
proc dangling_eps {} {
  set ws [allwires]; set ps [allpins]; set D {}
  set nw [llength $ws]
  for {set i 0} {$i<$nw} {incr i} {
    lassign [lindex $ws $i] x1 y1 x2 y2
    foreach {ex ey} [list $x1 $y1 $x2 $y2] {
      set hit 0
      foreach {px py} $ps { if {abs($px-$ex)<0.6 && abs($py-$ey)<0.6} { set hit 1; break } }
      if {!$hit} {
        for {set j 0} {$j<$nw} {incr j} {
          if {$j==$i} continue
          lassign [lindex $ws $j] a b c d
          if {[on_seg $ex $ey $a $b $c $d]} { set hit 1; break }
        }
      }
      if {!$hit} { lappend D [list $ex $ey] }
    }
  }
  return $D
}
proc ep_in {eps x y {tol 0.6}} {
  foreach e $eps { lassign $e a b
    if {abs($a-$x)<$tol && abs($b-$y)<$tol} { return 1 } }
  return 0
}

# ---------- structural partition asserts (as 0100/0103; #netN names drift, assert shape) ----------
proc instnets {inst} {
  set nets {}
  foreach {pin net} [lrange [xschem instance_nodemap $inst] 1 end] { lappend nets $net }
  return $nets
}
proc check_partition {label} {
  set p [pinnet R18 P]; set m [pinnet R18 M]
  set c12 [instnets C12]; set v8 [instnets v8]
  check "$label: R18.P and R18.M distinct + non-empty" [expr {$p ne $m && $p ne "" && $m ne ""}]
  check "$label: R18.P still shares a C12 pin net"     [expr {[lsearch -exact $c12 $p] >= 0}]
  check "$label: C12 pins on distinct nets (no C12 self-short)" \
        [expr {[lindex $c12 0] ne [lindex $c12 1]}]
  check "$label: R18.M still on the v8/backbone subtree" \
        [expr {[lsearch -exact $v8 $m] >= 0 && $m ne "OUT"}]
}

# one full case: partition + dangle-subset + user-stub survival + placement anti-vacuity.
proc case {label nrot doflip dx dy} {
  load_fixture
  set pre [dangling_eps]
  lassign [xschem instance_coord R18] - - prex prey prerot preflip
  gesture_ip $nrot $doflip $dx $dy
  set post [dangling_eps]
  set subset 1
  foreach e $post { lassign $e ex ey
    if {![ep_in $pre $ex $ey]} { set subset 0 } }
  check "$label: no NEW dangling endpoints (pre=$pre post=$post)" $subset
  set survive 1
  foreach s {{-550 160} {-550 120} {-420 -300}} { lassign $s sx sy
    if {![ep_in $post $sx $sy]} { set survive 0 } }
  check "$label: pre-existing user stubs survive" $survive
  lassign [xschem instance_coord R18] - - px py prot pflip
  check "$label: R18 landed at delta ($dx,$dy)" \
        [expr {$px == $prex+$dx && $py == $prey+$dy}]
  if {$doflip} {
    check "$label: R18 flip toggled" [expr {$pflip != $preflip}]
  } else {
    check "$label: R18 rot == [expr {($prerot+$nrot)%4}]" [expr {$prot == ($prerot+$nrot)%4}]
  }
  check_partition $label
}

# baseline sanity. The #netN literals are a deliberate FIXTURE-IDENTITY anchor: they pin the exact
# auto-numbering of freshly-loaded before_7.sch, so a fixture edit or loader change that renumbers
# nets fails HERE with an obvious message instead of scrambling the structural asserts below
# (which are all name-drift-immune by design).
load_fixture
check "fixture has R18" [expr {[find_inst R18] >= 0}]
check "pre: R18.P=#net2" [expr {[pinnet R18 P] eq "#net2"}]
check "pre: R18.M=#net1" [expr {[pinnet R18 M] eq "#net1"}]

# --- the user's case (trace fltrace_7_8_18: totdx=-30 totdy=70, one ALT-R) -> after_21.sch short.
# The rotated top pin's column == the pristine bottom-pin anchor column (-120): pre-fix this
# collapses R18.P/R18.M onto one net (partition_changed=4 kept by the accept ladder).
case "rot90-ip user drop (-30,70)" 1 0 -30 70
# the stale anchor tail must be gone: no wire endpoint may sit at (-120,-40) -- the merged
# vertical pin0 route passes THROUGH that point post-trim, so a surviving endpoint there can
# only be the tail (or an unmerged route split, equally a leak).
set anchor_bare 1
foreach w [allwires] { lassign $w a b c d
  if {(abs($a+120)<0.6 && abs($b+40)<0.6) || (abs($c+120)<0.6 && abs($d+40)<0.6)} {
    set anchor_bare 0
  }
}
check "user drop: no wire endpoint left at stale anchor (-120,-40)" $anchor_bare

# --- column sweep around the collision at dy=70 (only dx=-30 collides pre-fix; neighbours are
# 0103-clean and must STAY clean -- guards the prune against collateral damage)
case "rot90-ip (-60,70)" 1 0 -60 70
case "rot90-ip (-50,70)" 1 0 -50 70
case "rot90-ip (-40,70)" 1 0 -40 70
case "rot90-ip (-20,70)" 1 0 -20 70
case "rot90-ip (-10,70)" 1 0 -10 70
# --- same colliding drop under flip and the other rotations (safety net breadth)
case "rot90+flip-ip (-30,70)" 1 1 -30 70

# rot180 at this delta is only routable by the attempt-2 RIGID DIAGONAL RELAY (attempts 0/1 short,
# trace: partition_changed=4/4 then relay ACCEPTs with 0). The relay path used to skip the END
# cleanup block, leaving a known 0103-class stale-anchor tail at (-120,-40) (this was a tolerated
# xfail here). Issue 0108 gave the accepted relay a re-anchor + stale-feed prune pass, so the tail
# is gone and this is a FULL case again (the xfail tripwire fired as designed and was promoted).
case "rot180-ip (-30,70)" 2 0 -30 70
case "rot270-ip (-30,70)"     3 0 -30 70

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::nchecks checks, partition+dangle-subset+placement asserts)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL ($::nchecks checks)"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
