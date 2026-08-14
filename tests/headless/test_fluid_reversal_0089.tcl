# issue 0089: a fluid stretch-drag must not leave a redundant same-net U-TURN (detour).
# Repro: before_3.sch, drag R18 by (-80,-60) [(-400,-40)->(-480,-100)] = after_9.sch.
# Before the fix net #net2 is a 5-seg staircase ringing out to x=-400; after the fix a clean 3-seg L.
# (-420,-170)-(-420,-140) & (-480,-140)-(-420,-140) & (-480,-140)-(-480,-130).
#
# NEEDS A REAL X DISPLAY (the gesture runs move_objects + Xlib drawtemp). Self-skips cleanly
# under --nogui so it is safe to register in the headless case list.
#
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_reversal_0089.tcl

# cadence_style_rc essentials (only the LAST --script runs when chained, so set them here)
set fluid_editing 1
set orthogonal_wiring 1
set cadence_compat 1
set snap_cursor 1
set en_pin_select 1

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
set HASX 1
if {[catch {winfo viewable $WIN} vv] || !$vv} { set HASX 0 }
if {!$HASX} {
  puts "SKIP: no viewable X window ($WIN) -- fluid loop test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail : FAIL"; incr ::fails }
}

proc sch2scr {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  return [list [expr {int(round(($sx + $xo)/$z))}] [expr {int(round(($sy + $yo)/$z))}]]
}
proc gpress   {sx sy {st 0}}   { xschem callback $::WIN 4 $sx $sy 0 1 0 $st }
proc gmotion  {sx sy {st 256}} { xschem callback $::WIN 6 $sx $sy 0 0 0 $st }
proc grelease {sx sy {st 256}} { xschem callback $::WIN 5 $sx $sy 0 1 0 $st }

# Grab body at schematic (bx,by), drop at (tx,ty). Two motions guarantee a non-zero delta commit.
proc grab_drag_sch {bx by tx ty} {
  lassign [sch2scr $bx $by] psx psy
  lassign [sch2scr $tx $ty] tsx tsy
  gpress  $psx $psy 0
  gmotion [expr {($psx+$tsx)/2}] [expr {($psy+$tsy)/2}] 256
  gmotion $tsx $tsy 256
  grelease $tsx $tsy 256
  catch { update idletasks }
}

# Round-trip scratch file. Own dir per test (0089 and 0088 used to write the SAME literal
# /tmp name) and the helper removes it on every exit path -- issue 0148.
source [file join [file dirname [info script]] scratch.tcl]
set ::RBTMP [file join [test_scratch fluid_rev_0089] rb.sch]
# Return list of {x1 y1 x2 y2 lab} for every wire whose lab matches $want (or all if want=="").
proc net_wires {want} {
  file delete -force -- $::RBTMP
  catch { xschem saveas $::RBTMP schematic }
  set out {}
  if {![file exists $::RBTMP]} { return $out }
  set f [open $::RBTMP r]; set data [read $f]; close $f
  foreach line [split $data "\n"] {
    if {![string match "N *" $line]} continue
    if {![regexp {^N\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+\{(.*)\}} $line -> x1 y1 x2 y2 props]} continue
    set lab ""
    regexp {lab=([^ \}]+)} $props -> lab
    if {$want eq "" || $lab eq $want} { lappend out [list $x1 $y1 $x2 $y2 $lab] }
  }
  return $out
}

# Does the wire set (list of {x1 y1 x2 y2 ...}) contain a cycle? Graph: nodes=endpoints,
# edges=wires. For each connected component, cycle iff (#edges >= #nodes).
proc has_cycle {wires} {
  array unset ::nid; set ::nn 0
  set edges {}
  foreach w $wires {
    lassign $w x1 y1 x2 y2
    set a "$x1,$y1"; set b "$x2,$y2"
    foreach k [list $a $b] { if {![info exists ::nid($k)]} { set ::nid($k) $::nn; incr ::nn } }
    lappend edges [list $::nid($a) $::nid($b)]
  }
  # union-find
  for {set i 0} {$i < $::nn} {incr i} { set par($i) $i }
  proc _find {arrname i} { upvar 1 $arrname par
    while {$par($i) != $i} { set par($i) $par($par($i)); set i $par($i) }; return $i }
  set ecount 0
  foreach e $edges {
    lassign $e u v
    set ru [_find par $u]; set rv [_find par $v]
    if {$ru == $rv} { return 1 } ;# edge within same component closes a cycle
    set par($ru) $rv
  }
  return 0
}

set here [file dirname [info script]]
xschem load "$here/../from_user/before_3.sch"
xschem unhilight_all
update idletasks
# --- the repro drag: R18 by (-80,-60) ---
grab_drag_sch -400 -40 -480 -100

proc wex {wires ax ay bx by} {
  foreach w $wires { lassign $w x1 y1 x2 y2
    if {($x1==$ax&&$y1==$ay&&$x2==$bx&&$y2==$by)||($x1==$bx&&$y1==$by&&$x2==$ax&&$y2==$ay)} { return 1 } }
  return 0
}
set n2 [net_wires "#net2"]
check "0089-no-cycle: #net2 is a tree (no loop)" [expr {![has_cycle $n2]}] "wires=$n2"
check "0089-three-wire-L: #net2 is exactly 3 wires (not 5-seg detour)" [expr {[llength $n2] == 3}] "wires=$n2"
set stray 0
foreach w $n2 { lassign $w x1 y1 x2 y2; if {$x1==-400||$x2==-400} { set stray 1 } }
check "0089-no-x400-excursion: no #net2 copper at x=-400" [expr {!$stray}] "wires=$n2"
check "0089-L-riser: (-420,-170)-(-420,-140)" [wex $n2 -420 -170 -420 -140] "wires=$n2"
check "0089-L-cross:  (-480,-140)-(-420,-140)" [wex $n2 -480 -140 -420 -140] "wires=$n2"
check "0089-L-mstub:  (-480,-140)-(-480,-130)" [wex $n2 -480 -140 -480 -130] "wires=$n2"

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAILED, $::npass passed"; puts "OVERALL: fail" }
exit [expr {$::fails ? 1 : 0}]
