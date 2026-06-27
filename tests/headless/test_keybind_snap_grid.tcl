# Data-driven snap / grid / highlight key actions  (doc/claude/specs/keybind_snap_grid_actions.md,
# plan doc/claude/suggestions/plan_keybind_snap_grid_actions.md).
#
# End state: the five operations -- halve snap, double snap, set snap value,
# highlight-net-and-send-to-waveform, toggle grid -- are registered ACTIONS with NO
# built-in default chord. Every binding is user-specified (xschem bind / rc). The
# hardcoded `case 'g'` and `case '%'` are gone; cadence_style_rc carries the active
# CTRL-G -> toggle-grid binding plus commented recipes for the rest.
#
# RED-first SCAFFOLD (plan Phase 0): checks below map to spec section 7 (KB1..KB5) and
# are expected to FAIL against current code; they go GREEN phase by phase. Run from the
# repo ROOT, with the DEFAULT rc (no cadence_style_rc) so "plain startup" is honest:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_keybind_snap_grid.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {n} { global repo; return [file join $repo xschem_library examples $n] }

# Fire a key chord on the canvas. KeyPress event type = 2; a letter/printable keysym
# uses rstate (= state with ShiftMask stripped). ControlMask = 4, Mod1Mask (alt) = 8.
proc keyfire {keysym state} { xschem callback .drw 2 100 100 $keysym 0 0 $state; update idletasks }

proc dump_has_action {act} {
  foreach row [xschem bindings dump] { if {[lindex $row 4] eq $act} { return 1 } }
  return 0
}

set FAMILY {view.snap_half view.snap_double view.set_snap_value \
            hilight.send_to_waveform view.toggle_draw_grid}

xschem load [ex nand2.sch]
update

# --- KB1 : a plain startup binds NONE of the family --------------------------------
set bound {}
foreach a $FAMILY { if {[dump_has_action $a]} { lappend bound $a } }
check "KB1 plain startup binds none of the snap/grid/highlight family" \
  [expr {[llength $bound] == 0}] "(bound: $bound)"

# --- KB3 : every action id is a registered, bindable target ------------------------
# (done before KB2 so we know which ids resolve). Bind each to a throwaway chord.
set unknown {}
foreach a $FAMILY {
  if {[catch {xschem bind key 200 0 canvas $a}]} { lappend unknown $a } \
  else { catch {xschem unbind key 200 0 canvas} }
}
check "KB3a all five action ids are registered (bindable)" \
  [expr {[llength $unknown] == 0}] "(unknown: $unknown)"

# snap_half is bindable AND fires: bind 'g', fire it, cadsnap halves.
global cadsnap
catch {xschem unbind key 103 0 canvas}
set okb [expr {![catch {xschem bind key 103 0 canvas view.snap_half}]}]
set s0 $cadsnap
keyfire 103 0
set s1 $cadsnap
check "KB3b bind 'g'->snap_half then firing g halves cadsnap" \
  [expr {$okb && $s1 == $s0 / 2.0}] "(cadsnap $s0 -> $s1)"
catch {xschem unbind key 103 0 canvas}

# --- KB2 : bind CTRL-G -> toggle grid, fire it, draw_grid flips --------------------
global draw_grid
set okg [expr {![catch {xschem bind key 103 ctrl canvas view.toggle_draw_grid}]}]
set g0 $draw_grid; set g1 $draw_grid
# Only fire Ctrl-G if the action actually bound. Otherwise the chord falls through to
# the (current) hardcoded `case 'g'` set-snap input_line DIALOG, which blocks headless.
if {$okg} { keyfire 103 4; set g1 $draw_grid }   ;# Ctrl-G (ControlMask = 4)
check "KB2 Ctrl-G (bound to view.toggle_draw_grid) flips draw_grid" \
  [expr {$okg && $g1 != $g0}] "(okbind=$okg draw_grid $g0 -> $g1)"
catch {xschem unbind key 103 ctrl canvas}

# --- KB4 : no hardcoded case 'g' / case '%' in callback.c -------------------------
set fd [open [file join $repo src callback.c] r]; set csrc [read $fd]; close $fd
set hasg   [regexp {case 'g':}  $csrc]
set haspct [regexp "case '%':"  $csrc]
check "KB4 no hardcoded case 'g' / case '%' in callback.c" \
  [expr {!$hasg && !$haspct}] "(case 'g'=$hasg case '%'=$haspct)"

# --- KB5 : cadence_style_rc has the ACTIVE (uncommented) CTRL-G -> grid binding ----
set fd [open [file join $repo src cadence_style_rc] r]; set rctext [read $fd]; close $fd
set active 0
foreach line [split $rctext "\n"] {
  set t [string trim $line]
  if {$t eq {} || [string index $t 0] eq "#"} continue
  if {[regexp {xschem bind key 103 ctrl canvas view\.toggle_draw_grid} $t]} { set active 1 }
}
check "KB5 cadence_style_rc has the active CTRL-G -> toggle grid binding" $active {}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
