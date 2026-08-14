# Issue 0116: Alt-R / Alt-F transform correctness.
#   bug 2 (standalone, NOT in a drag): a multi-object selection must rotate/flip as one rigid
#          body about its bbox centre (group), NOT each object spun about its own origin
#          (the old unconditional ROTATELOCAL). A single object keeps the in-place transform.
#   bug 1 (mid connected-drag): a live fluid stretch must COMMIT the rotate/flip immediately so
#          it is visible without a mouse jiggle -- verified here by reading the committed
#          instance geometry right after the ALT-R keypress, before any further motion.
# Issue doc: doc/claude/issues/0116-alt-transform-group-and-live-commit.md
#
# RED-first: pre-fix, standalone ALT-R/ALT-F leave member positions unchanged (local spin) and a
# mid-drag ALT-R does not advance the committed rotation until a motion event arrives.
#
# MUST run from the repo ROOT under X (move_objects + Xlib drawtemp SIGSEGV --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_alt_transform_group_0116.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- alt-transform test needs a real display"
  puts "RESULT: SKIP (no X)"; puts "OVERALL: ok"; exit 0
}
update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} {incr ::fails}
}

set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256 ; set Mod1Mask 8 ; set KSYM_m 109 ; set KSYM_r 114 ; set KSYM_f 102

proc sch2scr {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$z))}] [expr {int(round(($sy+$yo)/$z))}]
}
proc inst_pos {n} { lrange [xschem instance_coord $n] 2 3 }
proc inst_rot {n} { lindex [xschem instance_coord $n] 4 }

proc setup_vstack {} {
  xschem clear force
  set ::persistent_command 0
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::enable_stretch 0; set ::cadence_compat 1; set ::fluid_editing 1
  set ::orthogonal_wiring 1
  xschem instance {res.sym} 0 0 0 0 {}       ;# pins P=(0,-30) M=(0,30)
  xschem instance {res.sym} 0 -200 0 0 {}    ;# pins P=(0,-230) M=(0,-170)
  xschem wire 0 -30 0 -170                    ;# connects inst0.P to inst1.M
  xschem zoom_full; update idletasks
}

# place the pointer (sets mousex/y_snap) then fire a key with modifier `st`, no button/drag.
proc key_at {sx sy ksym st} {
  global MOTION KP WIN
  xschem callback $WIN $MOTION $sx $sy 0 0 0 0
  xschem callback $WIN $KP     $sx $sy $ksym 0 0 $st
  update idletasks
}

# === bug 2 A -- standalone ALT-R on a 2-object selection => GROUP rotate ======
setup_vstack
xschem unselect_all; xschem select instance 0; xschem select instance 1
set p0b [inst_pos 0]; set p1b [inst_pos 1]
lassign [sch2scr 100 100] mx my
key_at $mx $my $KSYM_r $Mod1Mask
set p0a [inst_pos 0]; set p1a [inst_pos 1]
# stacked => both x=0 before; a GROUP rotate about the bbox centre sends them to different x
check "A1 standalone ALT-R rotates the pair as a GROUP (members no longer share x)" \
  [expr {abs([lindex $p0a 0]-[lindex $p1a 0]) > 1}] "before {$p0b}{$p1b} after {$p0a}{$p1a}"
# members must actually MOVE (a local spin leaves x0,y0 fixed)
check "A2 standalone ALT-R moved the members (not an own-origin spin)" \
  [expr {$p0a ne $p0b || $p1a ne $p1b}] "inst0 $p0b->$p0a inst1 $p1b->$p1a"

# === bug 2 B -- standalone ALT-F on a 2-object selection => GROUP flip ========
setup_vstack
# horizontal offset so a group flip about the bbox centre is observable
xschem clear force
set ::intuitive_interface 1; xschem set intuitive_interface 1
set ::cadence_compat 1; set ::fluid_editing 1; set ::orthogonal_wiring 1
xschem instance {res.sym} 0 0 0 0 {}
xschem instance {res.sym} 200 0 0 0 {}
xschem zoom_full; update idletasks
xschem unselect_all; xschem select instance 0; xschem select instance 1
set p1b [inst_pos 1]
lassign [sch2scr 100 100] mx my
key_at $mx $my $KSYM_f $Mod1Mask
set p1a [inst_pos 1]
# inst1 at x=200, inst0 at x=0; a group flip about bbox centre x=100 sends inst1 to x=0-ish (<100)
check "B1 standalone ALT-F flips the pair as a GROUP (inst1 crosses the bbox axis)" \
  [expr {[lindex $p1a 0] < 100}] "inst1 before=$p1b after=$p1a"

# === bug 2 C -- single object ALT-R stays per-object in-place (negation) ======
setup_vstack
xschem unselect_all; xschem select instance 0
set pb [inst_pos 0]; set rb [inst_rot 0]
lassign [sch2scr 100 100] mx my
key_at $mx $my $KSYM_r $Mod1Mask
check "C1 single-object standalone ALT-R is in-place (position fixed, rot advances)" \
  [expr {[inst_pos 0] eq $pb && [inst_rot 0] ne $rb}] "pos $pb->[inst_pos 0] rot $rb->[inst_rot 0]"

# === bug 1 -- mid connected-drag ALT-R commits LIVE (no mouse jiggle needed) ==
setup_vstack
xschem unselect_all; xschem select instance 0; xschem select instance 1
set r0b [inst_rot 0]
lassign [sch2scr 0 0]   gx gy       ;# grab at inst0 origin
lassign [sch2scr 60 40] tx ty       ;# translate target
xschem callback $WIN $KP $gx $gy $KSYM_m 0 0 0                     ;# 'm' connected stretch start
xschem callback $WIN $MOTION [expr {($gx+$tx)/2}] [expr {($gy+$ty)/2}] 0 0 0 0
xschem callback $WIN $MOTION $tx $ty 0 0 0 0                       ;# translate (RUBBER commits)
xschem callback $WIN $KP $tx $ty $KSYM_r 0 0 $Mod1Mask             ;# ALT-R -- NO further motion after
update idletasks
# committed geometry read WITHOUT any further motion: the rotation must already be applied
set r0a [inst_rot 0]
check "D1 mid-drag ALT-R commits the rotation live (committed rot advanced with no further motion)" \
  [expr {$r0a ne $r0b}] "inst0 rot $r0b->$r0a (pre-fix stays $r0b until a motion event)"
# drop to finish cleanly
xschem callback $WIN $BP $tx $ty 0 1 0 0
xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
update idletasks

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS (5 checks)"; puts "OVERALL: ok" } \
else { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
