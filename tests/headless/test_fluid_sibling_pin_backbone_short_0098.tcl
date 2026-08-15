# issue 0098 -- fluid connected-stretch lands a device pin mid-span on its SIBLING
# pin's net backbone -> device self-short (a "loop"). See
#   doc/claude/issues/0098-fluid-stretch-pin-on-sibling-net-backbone-short.md
#
# Fixture (fixture_0098_pre.sch): the settled pre-final-gesture state distilled from the
# user's session trace (FLUID_TRACE=/tmp/fltrace_7_8_13.log). R18 (res, flip1) sits at
# (-40,-120): pin P(0) at (-40,-150) on #net3 (a horizontal backbone at y=-160 whose left
# end is C12.m at (-320,-160)); pin M(1) at (-40,-90) on #net1. The two pins are on
# DISTINCT nets.
#
# Gesture: a cadence 'm' CONNECTED stretch drags R18 by (-20,-70) -> R18 to (-60,-190):
# P(-60,-220), M(-60,-160). M's new pin lands MID-SPAN on P's #net3 backbone
# [-320 -160 -40 -160] -> a device self-short (both pins collapse to one net). Saving this
# reproduces the user's after_16.sch byte-for-byte in the R18 region.
#
# PASS = R18's two pins stay on DISTINCT nets after the stretch (the tool routed around the
# short, or declined to commit it). RED before the 0098 fix: both pins land on one net.
#
# NEEDS A REAL X DISPLAY (move_objects + Xlib drawtemp SIGSEGV under --nogui). Self-skips
# cleanly with no display so it is safe in the --nogui regression harness. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_sibling_pin_backbone_short_0098.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- fluid stretch test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}

# match the user's launch config (src/cadence_style_rc)
set ::intuitive_interface 1; xschem set intuitive_interface 1
set ::cadence_compat 1
set ::fluid_editing 1; catch { xschem set fluid_editing 1 }
set ::orthogonal_wiring 1; catch { xschem set orthogonal_wiring 1 }
set ::autotrim_wires 1
set ::enable_stretch 0

set ::HERE [file dirname [file normalize [info script]]]
xschem load [file join $::HERE fixture_0098_pre.sch]
xschem zoom_full; update idletasks

proc pnet {pin} { return [lindex [xschem instance_net R18 $pin] 0] }
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$zm))}] [expr {int(round(($sy+$yo)/$zm))}]
}

set p_before [pnet P]; set m_before [pnet M]
check "setup: R18 pins start on distinct nets (P=$p_before M=$m_before)" \
  [expr {$p_before ne $m_before}]

# --- cadence 'm' noun-verb CONNECTED stretch, R18 selected, drag by (-20,-70) sch ---
set KP 2; set BP 4; set BR 5; set MOTION 6; set Button1Mask 256; set KSYM_m 109
xschem unselect_all; xschem select instance R18
lassign [xschem instance_coord R18] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
lassign [screen [expr {$rx-20}] [expr {$ry-70}]] tsx tsy
xschem callback $WIN $KP     $psx $psy $KSYM_m 0 0 0
xschem callback $WIN $MOTION $tsx $tsy 0 0 0 0
xschem callback $WIN $BP     $tsx $tsy 0 1 0 0
xschem callback $WIN $BR     $tsx $tsy 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord R18] a1 a2 nrx nry
check "R18 landed at (-60,-190) [list got $nrx $nry]" [expr {$nrx==-60 && $nry==-190}]
set p_after [pnet P]; set m_after [pnet M]
check "R18 pins stay on DISTINCT nets after connected stretch (no self-short) -- P=$p_after M=$m_after" \
  [expr {$p_after ne $m_after}]

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
