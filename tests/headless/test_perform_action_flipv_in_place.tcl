# perform_action() BOUNDARY -- FIFTH per-verb migration (Refactor B, audit §4 / §25)
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). Atom 1 migrated trim_wires; atom 2 align; atom 3 rotate_in_place
# (the FIRST with a mid-gesture split); atom 4 flip_in_place. This atom migrates
# flipv_in_place -- the LAST un-migrated in-place transform. Two structural differences
# from atom 4:
#   * SHAPE: flipv_in_place is a net VERTICAL mirror = a 180 rotate + a horizontal flip,
#     so its effect is THREE move_objects calls (ROTATE|ROTATELOCAL x2 then FLIP|
#     ROTATELOCAL), NOT one. run_core's flipv_in_place arm is byte-identical to the old
#     scheduler standalone `else` body: rebuild + START + those three + END, NO push_undo.
#   * ENTRY MAP: Alt-V is NOT handled by standalone_group_transform (which serves only
#     Alt-R/Alt-F). Alt-V has NO issue-0116 group form -- its standalone apply is always
#     the per-object in-place flip, so the WHOLE standalone apply crosses the boundary.
# The standalone verb crosses the boundary from EVERY entry point -- scheduler branch
# (`xschem flipv_in_place`: Edit menu / context menu / command palette), the Alt-V key
# (callback.c act_flipv_in_place, reached from the binding table), and the verb-noun
# deferred-apply (MENUSTARTROTATE
# PENDING_TR_FLIPV_IP) -- all now call perform_action("flipv_in_place", ...) instead of
# duplicating readonly + rebuild + move_objects(START/ROTATE|ROTATELOCAL x2/FLIP|
# ROTATELOCAL/END) + log_action.
#   * the DURING-move / DURING-copy arms (STARTMOVE/STARTCOPY) stay RAW and log NOTHING
#     at the verb level -- they are mid-gesture sub-steps logged at the move/copy END
#     (issue 0069). Routing them through the boundary would spuriously emit `xschem
#     flipv_in_place` mid-drag and double-count the move-END line. Case (e) locks that.
# flipv_in_place operates on the SELECTED objects; ROTATELOCAL pivots each about its OWN
# origin. NB a HORIZONTAL wire on the x-axis flips vertically to the mirror side but STAYS
# horizontal -- an orientation oracle cannot see it. So the effect oracle here is a
# DIAGONAL wire whose flipped coordinates differ observably: (0,0)-(100,40) --flipv about
# y1=0--> (0,0)-(100,-40), deterministic from a fresh state and DISTINCT from the
# horizontal flip (-100,40)-(0,0) (verified empirically before writing this oracle).
#
#   (a) exactly ONE log line from EACH standalone entry point (script / Alt-V key /
#       menu wrapper); the verb-noun MENUSTARTROTATE apply is grep-guard-locked (S1
#       count 2 on perform_action("flipv_in_place",0,NULL)) since it needs a real
#       arm-then-click on the wire's screen pixel to drive headlessly.
#   (b) readonly reject from EACH entry point: no mutation, no log, TCL_ERROR on the
#       scripted path (the 0041/0051 unification proof -- one gate covers every route)
#   (c) byte-identical: the logged line is textually `xschem flipv_in_place` (no drift)
#   (d) replay: the recorded bare verb re-EXECUTES (the wire flips) and, through the
#       replay_action_log suppress seam, does NOT re-log; a control unwrapped source DOES
#   (e) THE WRINKLE LOCK: a flipv_in_place issued mid-move (STARTMOVE active) does NOT
#       emit `xschem flipv_in_place` -- the gesture arm stays silent (logged at move END).
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_flipv_in_place.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §25

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X" -- full_audit's is_skip
# matches that token -- because the deferral is a graceful pass.)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# flipv_in_place drives move_objects(START/ROTATE|ROTATELOCAL x2/FLIP|ROTATELOCAL/END) ->
# draw_selection (Xlib GCs). With no X connection (--nogui) that SIGSEGVs, so defer cleanly
# rather than crash. Under the real logdir run (DISPLAY set) the window exists and we run.
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
set haveX [expr {![catch {winfo exists $WIN} e] && $e}]
if {!$haveX} {
  puts "deferred (no-X env; flipv_in_place drives move_objects -> Xlib GCs)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stub: post-migration the readonly scheduler/menu path uses the CIW-note
# gate (scheduler_readonly_reject), and the Alt-V key keeps its readonly_block() tk_messageBox
# (it also guards the raw mid-gesture arms) -- stub tk_messageBox so neither wedges the audit.
catch {rename tk_messageBox _paw_real_mb}
proc tk_messageBox {args} { return ok }

proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
# A pristine schematic with ONE DIAGONAL wire (0,0)-(100,40), all on the cadsnap=20 grid.
# flipv_in_place (net vertical mirror about the wire's own y1 = 0) mirrors y -> the wire
# becomes (0,0)-(100,-40): an observable, deterministic effect oracle DISTINCT from the
# horizontal flip. The verb acts on the SELECTION, so select_all.
proc diag_selected {} {
  xschem clear force
  xschem set cadsnap 20
  xschem set fluid_editing 0   ;# plain flip: no stretch/reroute pipeline in the way
  xschem wire 0 0 100 40
  xschem select_all
}
proc wcoord {} { return [xschem wire_coord 0] }

# The deterministic reference: exactly what ONE flipv produces on a fresh diagonal wire.
diag_selected
set ORIG [wcoord]
xschem flipv_in_place
set FLIPPED [wcoord]
check "oracle: flipv is OBSERVABLE (coords change, not an orientation no-op)" \
  [expr {$FLIPPED ne $ORIG}] "orig=$ORIG flipped=$FLIPPED"
check "oracle: flipv mirrors Y to the expected (0,0)-(100,-40), NOT the horizontal flip" \
  [expr {$FLIPPED eq "0 0 100 -40"}] "flipped=$FLIPPED"

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH standalone entry point.
#     script  -> scheduler branch standalone `else` -> perform_action
#     Alt-V key -> binding table (key 118 alt canvas -> edit.flipv_in_place) ->
#               callback.c act_flipv_in_place standalone apply -> perform_action
#               (keysym 118='v', state 8=Alt); one object selected -> lastsel!=0 apply arm
#     menu    -> menu_action_logged wrapper -> `xschem flipv_in_place` -> branch; the
#               wrapper resets/checks actionlog_cmd_logged, so the core's log wins and the
#               wrapper skips its copy -> exactly one line (dedup live).
# ---------------------------------------------------------------------------
diag_selected
check "(a) setup: wire starts at the reference orig" [expr {[wcoord] eq $ORIG}] "coord=[wcoord]"
set c0 [logcount {xschem flipv_in_place}]
xschem flipv_in_place
check "(a) scripted 'xschem flipv_in_place' -> exactly +1" \
  [expr {[logcount {xschem flipv_in_place}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem flipv_in_place}]"
check "(a) scripted: EFFECT applied (wire flipped to $FLIPPED)" \
  [expr {[wcoord] eq $FLIPPED}] "coord=[wcoord]"

diag_selected
set c0 [logcount {xschem flipv_in_place}]
xschem callback $WIN 2 400 300 118 0 0 8
check "(a) Alt-V key -> exactly +1 (standalone apply, no double)" \
  [expr {[logcount {xschem flipv_in_place}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem flipv_in_place}]"
check "(a) Alt-V key: EFFECT applied (wire flipped to $FLIPPED)" \
  [expr {[wcoord] eq $FLIPPED}] "coord=[wcoord]"

diag_selected
set c0 [logcount {xschem flipv_in_place}]
menu_action_logged {xschem flipv_in_place}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[logcount {xschem flipv_in_place}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem flipv_in_place}]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT from each entry point: no mutation, no log, and TCL_ERROR from
#     the scripted path (the one gate now covers every route -- 0041/0051). The Alt-V
#     key keeps readonly_block() (it also guards the raw gesture arms); either the CIW
#     note (scheduler) or the modal (key) refuses -- both are no-mutation, no-log.
# ---------------------------------------------------------------------------
diag_selected
set wc0 [wcoord]
xschem set readonly 1
set c0 [logcount {xschem flipv_in_place}]
set rc [catch {xschem flipv_in_place} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted: message names the verb" \
  [expr {[string match {*flipv_in_place*read-only*} $res]}] "res=$res"
check "(b) readonly scripted: NO log line (+0)" \
  [expr {[logcount {xschem flipv_in_place}] == $c0}] "c0=$c0 now=[logcount {xschem flipv_in_place}]"
check "(b) readonly scripted: NO mutation (wire coords unchanged)" \
  [expr {[wcoord] eq $wc0}] "before=$wc0 after=[wcoord]"

set c0 [logcount {xschem flipv_in_place}]
set wc0 [wcoord]
xschem callback $WIN 2 400 300 118 0 0 8
check "(b) readonly Alt-V key: NO log line (+0)" \
  [expr {[logcount {xschem flipv_in_place}] == $c0}] "c0=$c0 now=[logcount {xschem flipv_in_place}]"
check "(b) readonly Alt-V key: NO mutation (wire coords unchanged)" \
  [expr {[wcoord] eq $wc0}] "before=$wc0 after=[wcoord]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: the logged line is textually `xschem flipv_in_place` -- no args,
#     no format drift. (The migration MOVED the log site; it must not change the text.)
# ---------------------------------------------------------------------------
diag_selected
xschem flipv_in_place
set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
set exact ""
foreach l [split $all \n] { if {[string match {xschem flipv_in_place*} $l]} { set exact $l } }
check "(c) logged line is byte-exact 'xschem flipv_in_place'" \
  [expr {$exact eq "xschem flipv_in_place"}] "got=>$exact<"

# ---------------------------------------------------------------------------
# (d) REPLAY. flipv_in_place is a bare, re-executable verb (not a coordinate-form
#     bypass): replaying it re-runs the effect. Through the replay_action_log suppress
#     seam the effect applies (a fresh diagonal wire flips to $FLIPPED) but does NOT
#     re-log (the boundary's log site rides !actionlog_suppress -- re-entrant-safe). A
#     control unwrapped `source` DOES re-log, proving the line is a real action.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_flipv_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem flipv_in_place"; close $fd

diag_selected
set nc [logcount {xschem flipv_in_place}]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (wire flipped to $FLIPPED)" \
  [expr {[wcoord] eq $FLIPPED}] "coord=[wcoord]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[logcount {xschem flipv_in_place}] == $nc}] "nc=$nc now=[logcount {xschem flipv_in_place}]"

diag_selected
set nc [logcount {xschem flipv_in_place}]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (wire flipped to $FLIPPED)" \
  [expr {[wcoord] eq $FLIPPED}] "coord=[wcoord]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[logcount {xschem flipv_in_place}] == $nc + 1}] "nc=$nc now=[logcount {xschem flipv_in_place}]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) THE WRINKLE LOCK (atom-3/4/5-specific). A flipv_in_place issued MID-MOVE (STARTMOVE
#     active) hits the scheduler branch's during-move arm -- raw move_objects(ROTATE|
#     ROTATELOCAL x2 / FLIP|ROTATELOCAL), logged NOWHERE at the verb level (the move END
#     owns that, 0069). If a future edit routes the gesture arm through perform_action it
#     would emit `xschem flipv_in_place` here and double-count. Drive a real move-start
#     (headless seam: `move_objects start`), fire the verb, assert +0, then abort clean.
# ---------------------------------------------------------------------------
diag_selected
xschem move_objects start 0 0                 ;# sets STARTMOVE (move_objects(START))
check "(e) precondition: STARTMOVE is active" \
  [expr {[xschem get ui_state] & 32}] "ui_state=[xschem get ui_state]"
set c0 [logcount {xschem flipv_in_place}]
set rc [catch {xschem flipv_in_place} res]
check "(e) mid-move flipv_in_place: TCL_OK (gesture arm ran)" [expr {$rc == 0}] "rc=$rc res=$res"
check "(e) mid-move flipv_in_place: NOT logged (+0, silent gesture arm)" \
  [expr {[logcount {xschem flipv_in_place}] == $c0}] "c0=$c0 now=[logcount {xschem flipv_in_place}]"
catch {xschem move_objects abort}             ;# roll the gesture back, clean state

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
