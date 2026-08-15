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
#   ./src/xschem --pipe -q --script tests/headless/test_dblclick_connected_grow.tcl
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
# T5 -- coord-form escalation is SEED-driven: it recomputes the selection from
# the seed each call, so it SURVIVES an external unselect_all (repeated
# double-clicks on the same object keep escalating). Reset happens on SEED CHANGE
# (T4), not on selection clearing. This is deliberate: the interactive gesture
# cannot reliably observe an intervening deselect (its own press re-selects the
# seed before -3 fires), so the coord path keys off seed identity, not selection.
# ---------------------------------------------------------------------------
build_chain
set l [grow 50 0]
check "T5 first grow -> level 1"                     [expr {$l == 1}] "level=$l"
xschem unselect_all
set l [grow 50 0]
check "T5 same seed after unselect_all -> level 2"   [expr {$l == 2}] "level=$l"
check "T5 recompute-from-seed yields ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T5b -- the COORDLESS form is incremental and DOES reset on external selection
# change (sel_sig). Used for scripting.
# ---------------------------------------------------------------------------
build_chain
xschem select_at 50 0
set l [xschem select_grow_connected]
check "T5b coordless after fresh select -> level 1" [expr {$l == 1}] "level=$l"
check "T5b coordless ring1 (2 wires)"               [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
xschem unselect_all
xschem select_at 50 0
set l [xschem select_grow_connected]
check "T5b coordless resets on external change -> level 1" [expr {$l == 1}] "level=$l"

# ---------------------------------------------------------------------------
# T7 -- the REAL cadence_compat double-click GESTURE, full Tk event sequence
# (press, release, press, Double(-3), release). This is the case that a bare -3
# misses: with the cadence profile (fluid_editing + en_pin_select) the 2nd press
# arms a transient STARTMOVE / pin STARTWIRE, so -3 must abort it and the release
# must not collapse the grown selection. Escalates ring1 -> ring2 -> whole chain.
# ---------------------------------------------------------------------------
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  list [expr {int(($sx + $xo)/$z)}] [expr {int(($sy + $yo)/$z)}]
}
proc real_dblclick {sx sy} {
  global WIN
  lassign [screen $sx $sy] SX SY
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 1
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 2
  xschem callback $WIN -3 $SX $SY 0 1 0 0    ;# Double-Button-1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 2
  update idletasks
}
set cc_save [set ::cadence_compat]
set fe_save [set ::fluid_editing]
set ps_save [set ::en_pin_select]
set ::cadence_compat 1
set ::fluid_editing 1
set ::en_pin_select 1
build_chain
xschem unselect_all
real_dblclick 50 0
check "T7 real gesture dblclick1 -> ring1 (2 wires)" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
real_dblclick 50 0
check "T7 real gesture dblclick2 -> ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
real_dblclick 50 0
check "T7 real gesture dblclick3 -> whole chain (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
set ::cadence_compat $cc_save
set ::fluid_editing $fe_save
set ::en_pin_select $ps_save

# ---------------------------------------------------------------------------
# T8 -- the GESTURE escalation RESETS on ANY intervening non-double gesture, so the
# next double-click on the seed restarts at ring1 instead of jumping to whole-net.
# This is the click-path counterpart to T5's coord-form (which deliberately survives
# an explicit `unselect_all`). The reset is event-driven: a button-1 RELEASE that is
# not a double-click's release2 snapshots+zeroes the level; the double's following -3
# restores the snapshot. Here: empty-space click and different-object click.
# ---------------------------------------------------------------------------
proc real_click {sx sy} {
  global WIN
  lassign [screen $sx $sy] SX SY
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 1
  update idletasks
}
set ::cadence_compat 1
set ::fluid_editing 1
set ::en_pin_select 1
build_chain
xschem unselect_all
real_dblclick 50 0 ; real_dblclick 50 0 ; real_dblclick 50 0
check "T8 escalate to whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
real_click 400 400                          ;# empty space -> deselect
check "T8 empty click deselects (0 wires)" [expr {[nsel_type wire] == 0}] "sel=[xschem selection]"
real_dblclick 50 0
check "T8 re-dblclick after deselect -> ring1 (2 wires), NOT whole" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
# and the full escalation works again from the restart
real_dblclick 50 0
check "T8 re-escalate ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
real_dblclick 50 0
check "T8 re-escalate whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
# clicking a DIFFERENT object also resets: dblclick back to the seed -> ring1
real_click 250 200                          ;# click W4 (a different segment)
real_dblclick 50 0
check "T8 different-object click then re-dblclick seed -> ring1 (2 wires)" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T9 -- the hard case: a single click ON the seed itself. Under cadence deferred
# selection this leaves the selection VISUALLY UNCHANGED (the seed stays selected,
# the ring stays selected), so no selection- or seed-identity check can see it --
# only the event stream (a non-double button-1 release) reveals it. It must still
# reset the escalation: re-dblclick the seed -> ring1, not whole-net.
# ---------------------------------------------------------------------------
build_chain
xschem unselect_all
real_dblclick 50 0 ; real_dblclick 50 0 ; real_dblclick 50 0
check "T9 escalate to whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
real_click 50 0                             ;# plain single click ON the seed W0
real_dblclick 50 0
check "T9 single-click ON seed then re-dblclick -> ring1 (2 wires)" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
real_dblclick 50 0
check "T9 re-escalate after seed-click ring2 (3 wires)" \
  [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T10 -- drive the REAL Tk double-click event stream. Ground truth (verified via
# Tk `event generate`): a double-click fires  P1, R1, <Double>(-3), R2 -- the 2nd
# press emits ONLY the -3 (Double-Button-1 is more specific than the generic
# <ButtonPress> binding), NOT a second callback-4. The other procs here inject a
# synthetic extra press2 (4,5,4,-3,5); this proc uses the real 4,5,-3,5 so the
# escalation + reset are proven under actual dispatch, not just the synthetic model.
# ---------------------------------------------------------------------------
proc realtk_dbl {sx sy} {
  global WIN
  lassign [screen $sx $sy] SX SY
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 1
  xschem callback $WIN -3 $SX $SY 0 1 0 0    ;# Double-Button-1 (press2 == only this)
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 2
  update idletasks
}
build_chain
xschem unselect_all
realtk_dbl 50 0
check "T10 realTk dbl1 -> ring1 (2 wires)" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
realtk_dbl 50 0
check "T10 realTk dbl2 -> ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
realtk_dbl 50 0
check "T10 realTk dbl3 -> whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
real_click 50 0                             ;# single click on seed
realtk_dbl 50 0
check "T10 realTk single-click ON seed then re-dbl -> ring1 (2 wires)" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"

set ::cadence_compat $cc_save
set ::fluid_editing $fe_save
set ::en_pin_select $ps_save

# ---------------------------------------------------------------------------
# T11 -- ACTION-LOG COVERAGE (issue 0071 core-self-log). The double-click GESTURE
# must record a replayable `xschem select_grow_connected x y` line, and the script
# subcommand must log EXACTLY ONCE. select_grow_connected_step() now self-logs at its
# CORE (select.c); handle_double_click() calls that core directly (callback.c), so
# before the fix the gesture logged NOTHING while only the scheduler branch did.
# Moving the log to the core covers both; the branch no longer logs (no double).
# See doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md.
# Needs the action log open -> registered in full_audit.sh logdir_tests (--logdir).
# ---------------------------------------------------------------------------
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  check "T11 action-log open (skipped: run with --logdir to exercise)" 1 "no log file"
} else {
  proc grow_logcount {} {
    if {[catch {open [xschem get actionlog_filename] r} fd]} { return -1 }
    set body [read $fd]; close $fd
    set n 0
    foreach line [split $body \n] {
      if {[string match "xschem select_grow_connected*" $line]} { incr n }
    }
    return $n
  }
  set ::cadence_compat 1 ; set ::fluid_editing 1 ; set ::en_pin_select 1
  build_chain
  xschem unselect_all
  # (a) the real double-click GESTURE logs -- THE fix (was silent: the gesture calls
  #     the core directly, bypassing the scheduler branch that used to hold the log)
  set before [grow_logcount]
  realtk_dbl 50 0
  set after_gesture [grow_logcount]
  check "T11a real dblclick GESTURE logs one select_grow_connected line" \
    [expr {$after_gesture == $before + 1}] "before=$before after=$after_gesture"
  # (b) the script subcommand logs EXACTLY ONCE (core logs; branch does not double)
  xschem select_grow_connected 50 0
  set after_cmd [grow_logcount]
  check "T11b script subcommand logs exactly once (no double, no drop)" \
    [expr {$after_cmd == $after_gesture + 1}] "delta=[expr {$after_cmd - $after_gesture}]"
  # (the logged line `xschem select_grow_connected <x> <y>` is itself the replayable
  #  command by construction -- T11a/b prove it was written exactly once per action.)
  set ::cadence_compat $cc_save ; set ::fluid_editing $fe_save ; set ::en_pin_select $ps_save
}

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

# ---------------------------------------------------------------------------
puts ""
if {$::fails == 0} {
  puts "OVERALL: ok  (all checks passed)"
  puts "RESULT: ALL PASS"
} else {
  puts "OVERALL: FAIL  ($::fails failed)"
  puts "RESULT: $::fails FAILED"
}
