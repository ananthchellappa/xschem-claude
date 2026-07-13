# Cadence double-click incremental connected-select -- engine + subcommand.
# doc/claude/specs/dblclick_connected_select.md, plan
# doc/claude/suggestions/plan_dblclick_connected_select.md (commit 1).
#
# `xschem select_grow_connected [x y]` runs ONE escalation step keyed on a seed:
#   1st call on a seed -> ring1 (seed + directly-touching wire segments)
#   2nd  -> ring2 (one more ring)
#   3rd  -> whole net (geometric flood, WIRES ONLY)
#   4th+ -> no-op (already whole)
# A different seed, or an external selection change, resets the escalation.
#
# Uses select_object() + draw_selection() -> needs a real X window (like
# test_select_at.tcl / test_connected_drag_*). Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_dblclick_connected_grow.tcl
#
# RED-first: on a build without select_grow_connected the command throws (caught
# -> FAIL) so every check reds.

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- connected-grow test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
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
proc nsel      {}  { llength [xschem selection] }
proc nsel_type {t} { set c 0; foreach e [xschem selection] { if {[lindex $e 0] eq $t} {incr c} }; return $c }
proc grow      {args} { eval xschem select_grow_connected $args }

# --- fixture: a linear chain of 5 DISTINCT (perpendicular-jointed, so never
# merged) wire segments W0..W4, each touching the next at an endpoint. Seed W0 at
# its mid-point (50,0). A lab_wire is dropped on W2 to prove rings stay wires-only.
proc build_chain {} {
  xschem clear force
  xschem wire   0   0  100   0    ;# W0  seed, hit at (50,0)
  xschem wire 100   0  100 100    ;# W1  touches W0 at (100,0)
  xschem wire 100 100  200 100    ;# W2  touches W1 at (100,100)
  xschem wire 200 100  200 200    ;# W3  touches W2 at (200,100)
  xschem wire 200 200  300 200    ;# W4  touches W3 at (200,200)
  xschem unselect_all
  xschem redraw
  update idletasks
}

# ---------------------------------------------------------------------------
# T1 -- ring escalation from a wire seed: 2 -> 3 -> 5, then saturates.
# ---------------------------------------------------------------------------
build_chain
# add a net-label sitting on W2 (150,100); wires-only rings must NOT select it.
xschem instance devices/lab_wire 150 100 0 0 {name=l1 lab=NET}
xschem unselect_all
xschem redraw
update idletasks

set l1 [grow 50 0]
check "T1a click1 -> level 1"            [expr {$l1 == 1}]           "level=$l1"
check "T1a click1 -> 2 wires (W0,W1)"    [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
check "T1a click1 -> no instance in sel" [expr {[nsel_type instance] == 0}]

set l2 [grow 50 0]
check "T1b click2 -> level 2"            [expr {$l2 == 2}]           "level=$l2"
check "T1b click2 -> 3 wires"            [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"

set l3 [grow 50 0]
check "T1c click3 -> level 3"            [expr {$l3 == 3}]           "level=$l3"
check "T1c click3 -> all 5 wires"        [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"

set l4 [grow 50 0]
check "T1d click4 -> saturates at 3"     [expr {$l4 == 3}]           "level=$l4"
check "T1d click4 -> still 5 wires"      [expr {[nsel_type wire] == 5}]

# ---------------------------------------------------------------------------
# T6 -- wires-only: even at whole-net the lab_wire on W2 is NOT selected.
# ---------------------------------------------------------------------------
check "T6 whole-net keeps rings wires-only (0 instances)" [expr {[nsel_type instance] == 0}] \
  "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T2 -- seed already selected: first grow still yields ring1 (same as T1a).
# ---------------------------------------------------------------------------
build_chain
xschem select_at 50 0                      ;# pre-select W0 (plain click)
check "T2 pre-select: 1 wire selected"     [expr {[nsel_type wire] == 1}]
set l [grow 50 0]
check "T2 grow on pre-selected -> level 1" [expr {$l == 1}]            "level=$l"
check "T2 grow on pre-selected -> 2 wires" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T3 -- non-wire seed (instance/net-label): grows the touching wire, keeps inst.
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/lab_wire 0 0 0 0 {name=l1 lab=NET}   ;# instance index 0
set pc [xschem instance_pin_coord l1 name p]
set px [lindex $pc 1]; set py [lindex $pc 2]
xschem wire $px $py [expr {$px + 100}] $py                    ;# wire from the label pin
xschem unselect_all
xschem redraw
update idletasks
xschem select instance 0                                     ;# seed = the label instance
set l [grow]                                                 ;# coordless step on current sel
check "T3 label seed -> level 1"           [expr {$l == 1}]            "level=$l"
check "T3 label seed keeps instance"       [expr {[nsel_type instance] == 1}] "sel=[xschem selection]"
check "T3 label seed grows touching wire"  [expr {[nsel_type wire] == 1}]     "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T4 -- different seed resets the escalation (level back to 1, not 3).
# ---------------------------------------------------------------------------
build_chain
grow 50 0 ; grow 50 0                       ;# W0 up to level 2
set l [grow 250 200]                        ;# seed W4 (mid at (250,200)) -> reset
check "T4 different seed resets to level 1" [expr {$l == 1}] "level=$l"

# ---------------------------------------------------------------------------
# T5 -- external selection change resets the escalation.
# ---------------------------------------------------------------------------
build_chain
set l [grow 50 0]
check "T5 first grow -> level 1"            [expr {$l == 1}] "level=$l"
xschem unselect_all                         ;# external change
set l [grow 50 0]
check "T5 after unselect_all -> reset to 1" [expr {$l == 1}] "level=$l"
check "T5 reset yields ring1 (2 wires)"     [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
puts ""
if {$::fails == 0} {
  puts "OVERALL: ok  (all checks passed)"
} else {
  puts "OVERALL: FAIL  ($::fails failed)"
}
