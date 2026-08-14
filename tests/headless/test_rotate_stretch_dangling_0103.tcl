# issue 0103: ALT-R (rotate-in-place) during a connected stretch must not leave DANGLING TAIL
# wires at the follow wires' pristine pre-move anchors.
#
# Repro (tests/from_user/before_7.sch -> after_20.sch): select R18, press 'm' (cadence connected
# stretch), drag, ALT-R mid-drag, keep dragging, drop at delta (-40,70). The electrical partition
# is CORRECT (0099/0100/0102 machinery reconnects both pins) but two dangling stubs survive:
#   N -190 -40 -120 -40 {#net1}   elbow 2nd leg back to R18.M's pristine anchor (-120,-40)
#   N -130 -150 -120 -150 {#net2} elbow 2nd leg back to the pristine rail attach (-120,-150)
# Mechanism: place_moved_wire lays the elbow's far leg to the PRISTINE anchor (0100 design);
# trim_wires splits the stationary backbone at the elbow corner + dedups the overlap, leaving a
# corner->anchor tail whose free end touches nothing. Same-net => invisible to the partition
# accept ladder; remove_move_orphan_wires needs the kept end on a MOVING pin (it is a rail T);
# the tail-capable aesthetic passes are rotfree-gated. See
# doc/claude/issues/0103-rotate-stretch-dangling-anchor-tails.md.
#
# Discriminator: DANGLING-ENDPOINT COUNT (wire endpoint touching no pin, no other wire endpoint,
# no other wire interior) must not grow across the gesture; plus the specific pristine-anchor
# spots must be bare. Structural partition asserts guard against the prune breaking reconnect.
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGVs --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_rotate_stretch_dangling_0103.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- 0103 dangling-tail test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
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

# same in-place gesture as the 0100 test: m at grab, MOTION, nrot x ALT-r (+ optional ALT-f)
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

# ---------- dangling-endpoint machinery ----------
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
# point (x,y) on segment (a,b)-(c,d) inclusive? works for diagonals (0102 relays) too.
proc on_seg {x y a b c d {tol 0.01}} {
  set cross [expr {($c-$a)*($y-$b) - ($d-$b)*($x-$a)}]
  set len   [expr {hypot($c-$a, $d-$b)}]
  if {$len == 0} { return [expr {abs($x-$a)<$tol && abs($y-$b)<$tol}] }
  if {abs($cross)/$len > $tol} { return 0 }
  set dot [expr {($x-$a)*($c-$a) + ($y-$b)*($d-$b)}]
  if {$dot < -$tol || $dot > $len*$len+$tol} { return 0 }
  return 1
}
# list of dangling wire endpoints: endpoint touching NO pin and NO other wire (endpoint or interior)
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
proc ep_present {x y {tol 0.6}} {
  foreach w [allwires] {
    lassign $w a b c d
    if {abs($a-$x)<$tol && abs($b-$y)<$tol} { return 1 }
    if {abs($c-$x)<$tol && abs($d-$y)<$tol} { return 1 }
  }
  return 0
}

# ---------- structural partition asserts (as 0100; #netN names drift, assert shape) ----------
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

# is endpoint (x,y) present in an endpoint list (tol match)?
proc ep_in {eps x y {tol 0.6}} {
  foreach e $eps { lassign $e a b
    if {abs($a-$x)<$tol && abs($b-$y)<$tol} { return 1 } }
  return 0
}

# one full case. Review wf_8b4088de hardening:
#  - dangle SET-subset assert (post ⊆ pre), not count: a count-only <= pre would stay green if the
#    delete-only prune ATE a pre-existing user stub, or swapped one for a leaked tail;
#  - the fixture's 3 deliberate far-away stubs must SURVIVE every case (over-deletion guard);
#  - anti-vacuity: R18 must actually land at (x0+dx, y0+dy) with the expected rot/flip -- all the
#    partition+dangle asserts also hold on the pristine fixture, so a silently aborted gesture
#    (ALT-R not engaging, move aborted) would otherwise pass 8 of 9 cases green-but-hollow.
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

# baseline sanity
load_fixture
check "fixture has R18" [expr {[find_inst R18] >= 0}]
check "pre: R18.P=#net2" [expr {[pinnet R18 P] eq "#net2"}]
check "pre: R18.M=#net1" [expr {[pinnet R18 M] eq "#net1"}]
set base_dangle [llength [dangling_eps]]
puts "info: fixture baseline dangling endpoints = $base_dangle"

# --- the user's case (trace fltrace_7_8_17: totdx=-40 totdy=70, one ALT-R) -> after_20.sch tails
case "rot90-ip user drop (-40,70)" 1 0 -40 70
# pristine anchors must be BARE after the gesture (this drop leaves both tails pre-fix)
check "user drop: no wire endpoint left at pristine anchor (-120,-40)"  [expr {![ep_present -120 -40]}]
check "user drop: no wire endpoint left at pristine anchor (-120,-150)" [expr {![ep_present -120 -150]}]

# --- other rotated drops (0100's hard-assert deltas) must stay tail-free too
case "rot90-ip (40,20)"      1 0 40 20
case "rot90-ip (30,20)"      1 0 30 20
case "rot90+flip-ip (30,20)" 1 1 30 20
# anchor-side drops mirroring the user's negative-dx geometry
case "rot90-ip (-30,20)"     1 0 -30 20
case "rot90+flip-ip (-40,70)" 1 1 -40 70
# rot180/270 relay (0102 diagonals) paths must not leak tails either
case "rot180-ip (-50,80)"    2 0 -50 80
case "rot180-ip (30,20)"     2 0 30 20
case "rot270-ip (30,20)"     3 0 30 20

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ([expr {3+2+9*8}] checks, dangle-subset+placement+partition asserts)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
