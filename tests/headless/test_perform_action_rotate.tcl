# perform_action() BOUNDARY -- SIXTH per-verb migration (Refactor B, audit §4 / §26)
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). Atoms 1-5 migrated the bare no-arg verbs trim_wires / align /
# rotate_in_place / flip_in_place / flipv_in_place (the in-place transform QUARTET).
# THIS atom migrates `rotate` (the pivot form `xschem rotate x0 y0`) -- the FIRST
# ARG-CARRYING verb to cross the boundary. Its two coord args thread through BOTH
# halves of the boundary:
#   * run_core's rotate arm resolves the SHARED pivot x0,y0 from argv[2]/argv[3]
#     (else the mouse coords), seeds mx_double_save/mousex_snap = x0,y0, then
#     rebuild + START + move_objects(ROTATE) + END -- NO ROTATELOCAL (the pivot is
#     the single shared point, not each object's own origin), byte-identical to the
#     old scheduler standalone `else` body, NO push_undo (move_objects owns it).
#   * core_log_action (the §4 Refactor-A step-2 log-form registry SEED introduced by
#     this atom) formats `xschem rotate <x0> <y0>` from the SAME argv (or the same
#     seeded coord on the mouse-fallback path) -- so the logged pivot can never
#     diverge from the applied pivot. That fidelity is the atom-6-specific risk and
#     is locked by the pivot-fidelity checks below.
# The standalone verb crosses from EVERY standalone entry point -- scheduler branch
# (`xschem rotate [x y]`: Edit menu / context menu / command palette), the Shift-R
# key (callback.c case 'R', keysym 82), the Alt-R GROUP transform
# (standalone_group_transform, issue 0116) and the verb-noun deferred apply
# (MENUSTARTROTATE PENDING_TR_ROTATE) -- all now call perform_action("rotate",4,av).
#   * the DURING-move / DURING-copy arms (STARTMOVE/STARTCOPY) stay RAW and log
#     NOTHING at the verb level -- mid-gesture sub-steps logged at the move/copy END
#     (issue 0069). Routing them through the boundary would spuriously emit `xschem
#     rotate x y` mid-drag and double-count the move-END line. Case (e) locks that.
# EFFECT ORACLE: a lone DIAGONAL wire (0,0)-(100,40), cadsnap=20, select_all,
# `xschem rotate 0 0` (90 deg about the ORIGIN) -> (-40,100)-(0,0). Pivot-SENSITIVE
# (rotate about (100,40) instead gives (100,40)-(140,-60)) and involutive x4 (four
# rotations about the origin return to the start) -- verified empirically before
# writing this oracle. A pivot-form rotate about a NON-origin point MOVES the wire,
# so the oracle fixes the pivot at the origin.
#
#   (a) exactly ONE log line from EACH runtime-drivable standalone entry point
#       (script / Shift-R key / menu wrapper); the Alt-R GROUP transform + the
#       verb-noun MENUSTARTROTATE apply are grep-guard-locked (they need a real
#       arm-then-click on the wire's screen pixel to drive headlessly) -- noted here,
#       not runtime-driven.
#   (b) readonly reject from EACH entry point: no mutation, no log, TCL_ERROR +
#       verb-named message on the scripted path (the 0041/0051 unification proof).
#   (c) byte-identical: a scripted `xschem rotate 0 0` logs textually `xschem rotate 0 0`
#       (the %.16g %.16g pivot form -- this is the NEW drift risk vs the bare verbs).
#   (d) replay: the recorded pivot line re-EXECUTES (the wire rotates about the pivot)
#       and, through the replay_action_log suppress seam, does NOT re-log; a control
#       unwrapped source DOES re-log (a real re-executable action, IN S2 CVERBS).
#   (e) THE WRINKLE LOCK: a rotate issued mid-move (STARTMOVE active) does NOT emit
#       `xschem rotate` -- the gesture arm stays silent (logged at move END).
#   (f) PIVOT FIDELITY (atom-6-specific): the logged pivot reproduces the effect. For
#       a NON-trivial scripted pivot AND for the Shift-R mouse pivot, replaying the
#       exact logged line on a fresh wire lands the SAME coords the live verb did -- a
#       log that emitted a different pivot than the effect used would diverge here.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_rotate.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §26

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

# rotate drives move_objects(START/ROTATE/END) -> draw_selection (Xlib GCs). With no
# X connection (--nogui) that SIGSEGVs, so defer cleanly rather than crash. Under the
# real logdir run (DISPLAY set) the window exists and we run.
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
set haveX [expr {![catch {winfo exists $WIN} e] && $e}]
if {!$haveX} {
  puts "deferred (no-X env; rotate drives move_objects -> Xlib GCs)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stub: the readonly scheduler/menu path uses the CIW-note gate
# (scheduler_readonly_reject), and the Shift-R key keeps its readonly_block()
# tk_messageBox (it also guards the raw mid-gesture arms) -- stub tk_messageBox so
# neither wedges the audit.
catch {rename tk_messageBox _paw_real_mb}
proc tk_messageBox {args} { return ok }

proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
# last "xschem rotate ..." line currently in the log (for byte-exact + fidelity replay)
proc last_rotate_line {} {
  set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
  set exact ""
  foreach l [split $all \n] { if {[string match {xschem rotate *} $l]} { set exact $l } }
  return $exact
}
# A pristine schematic with ONE DIAGONAL wire (0,0)-(100,40), all on the cadsnap=20
# grid. rotate acts on the SELECTION, so select_all.
proc diag_selected {} {
  xschem clear force
  xschem set cadsnap 20
  xschem set fluid_editing 0   ;# plain rotate: no stretch/reroute pipeline in the way
  xschem wire 0 0 100 40
  xschem select_all
}
proc wcoord {} { return [xschem wire_coord 0] }

# The deterministic reference: exactly what ONE `rotate 0 0` produces on a fresh
# diagonal wire (90 deg about the origin).
diag_selected
set ORIG [wcoord]
xschem rotate 0 0
set ROT [wcoord]
check "oracle: rotate is OBSERVABLE (coords change)" \
  [expr {$ROT ne $ORIG}] "orig=$ORIG rot=$ROT"
check "oracle: rotate 0 0 spins 90 deg about the origin to (-40,100)-(0,0)" \
  [expr {$ROT eq "-40 100 0 0"}] "rot=$ROT"
# pivot-sensitivity: a different pivot MOVES the wire elsewhere (proves the pivot is real)
diag_selected
xschem rotate 100 40
check "oracle: rotate 100 40 is DISTINCT from rotate 0 0 (pivot matters)" \
  [expr {[wcoord] ne $ROT}] "rot100_40=[wcoord] rot0_0=$ROT"

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH runtime-drivable standalone entry point.
#     script    -> scheduler branch standalone `else` -> perform_action("rotate",argc,argv)
#     Shift-R   -> callback.c case 'R' standalone apply (keysym 82, state 1=Shift),
#                  one object selected -> lastsel!=0 apply arm -> perform_action("rotate",4,av)
#     menu      -> menu_action_logged {xschem rotate} -> branch; wrapper resets/checks
#                  actionlog_cmd_logged, so the core's log wins and the wrapper skips its
#                  copy -> exactly one line (dedup live).
# ---------------------------------------------------------------------------
diag_selected
check "(a) setup: wire starts at the reference orig" [expr {[wcoord] eq $ORIG}] "coord=[wcoord]"
set c0 [logcount {xschem rotate *}]
xschem rotate 0 0
check "(a) scripted 'xschem rotate 0 0' -> exactly +1" \
  [expr {[logcount {xschem rotate *}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem rotate *}]"
check "(a) scripted: EFFECT applied (wire rotated to $ROT)" \
  [expr {[wcoord] eq $ROT}] "coord=[wcoord]"

diag_selected
set c0 [logcount {xschem rotate *}]
xschem callback $WIN 2 400 300 82 0 0 1
check "(a) Shift-R key -> exactly +1 (standalone apply, no double)" \
  [expr {[logcount {xschem rotate *}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem rotate *}]"
check "(a) Shift-R key: EFFECT applied (wire moved from orig)" \
  [expr {[wcoord] ne $ORIG}] "coord=[wcoord]"

diag_selected
set c0 [logcount {xschem rotate *}]
menu_action_logged {xschem rotate}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[logcount {xschem rotate *}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem rotate *}]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT from each entry point: no mutation, no log, TCL_ERROR + verb-
#     named message on the scripted path (one gate covers every route -- 0041/0051).
#     The Shift-R key keeps readonly_block() (it also guards the raw gesture arms).
# ---------------------------------------------------------------------------
diag_selected
set wc0 [wcoord]
xschem set readonly 1
set c0 [logcount {xschem rotate *}]
set rc [catch {xschem rotate 0 0} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted: message names the verb" \
  [expr {[string match {*rotate*read-only*} $res]}] "res=$res"
check "(b) readonly scripted: NO log line (+0)" \
  [expr {[logcount {xschem rotate *}] == $c0}] "c0=$c0 now=[logcount {xschem rotate *}]"
check "(b) readonly scripted: NO mutation (wire coords unchanged)" \
  [expr {[wcoord] eq $wc0}] "before=$wc0 after=[wcoord]"

set c0 [logcount {xschem rotate *}]
set wc0 [wcoord]
xschem callback $WIN 2 400 300 82 0 0 1
check "(b) readonly Shift-R key: NO log line (+0)" \
  [expr {[logcount {xschem rotate *}] == $c0}] "c0=$c0 now=[logcount {xschem rotate *}]"
check "(b) readonly Shift-R key: NO mutation (wire coords unchanged)" \
  [expr {[wcoord] eq $wc0}] "before=$wc0 after=[wcoord]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: a scripted `xschem rotate 0 0` logs textually `xschem rotate 0 0`
#     (the %.16g %.16g pivot form). The migration MOVED the log site (into
#     core_log_action); it must not change the text or the pivot format.
# ---------------------------------------------------------------------------
diag_selected
xschem rotate 0 0
check "(c) logged line is byte-exact 'xschem rotate 0 0'" \
  [expr {[last_rotate_line] eq "xschem rotate 0 0"}] "got=>[last_rotate_line]<"

# ---------------------------------------------------------------------------
# (d) REPLAY. rotate is a re-executable pivot verb (NOT a coordinate-STORE bypass like
#     `wire x1 y1 x2 y2`): replaying it re-runs the effect. Through the
#     replay_action_log suppress seam the effect applies (a fresh diagonal wire
#     rotates to $ROT) but does NOT re-log; a control unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_rotate_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem rotate 0 0"; close $fd

diag_selected
set nc [logcount {xschem rotate *}]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (wire rotated to $ROT)" \
  [expr {[wcoord] eq $ROT}] "coord=[wcoord]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[logcount {xschem rotate *}] == $nc}] "nc=$nc now=[logcount {xschem rotate *}]"

diag_selected
set nc [logcount {xschem rotate *}]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (wire rotated to $ROT)" \
  [expr {[wcoord] eq $ROT}] "coord=[wcoord]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[logcount {xschem rotate *}] == $nc + 1}] "nc=$nc now=[logcount {xschem rotate *}]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) THE WRINKLE LOCK (atom-3/4/5/6). A rotate issued MID-MOVE (STARTMOVE active)
#     hits the scheduler branch's during-move arm -- raw move_objects(ROTATE), logged
#     NOWHERE at the verb level (the move END owns that, 0069). If a future edit routes
#     the gesture arm through perform_action it would emit `xschem rotate` here and
#     double-count. Drive a real move-start, fire the verb, assert +0, then abort clean.
# ---------------------------------------------------------------------------
diag_selected
xschem move_objects start 0 0                 ;# sets STARTMOVE (move_objects(START))
check "(e) precondition: STARTMOVE is active" \
  [expr {[xschem get ui_state] & 32}] "ui_state=[xschem get ui_state]"
set c0 [logcount {xschem rotate *}]
set rc [catch {xschem rotate 0 0} res]
check "(e) mid-move rotate: TCL_OK (gesture arm ran)" [expr {$rc == 0}] "rc=$rc res=$res"
check "(e) mid-move rotate: NOT logged (+0, silent gesture arm)" \
  [expr {[logcount {xschem rotate *}] == $c0}] "c0=$c0 now=[logcount {xschem rotate *}]"
catch {xschem move_objects abort}             ;# roll the gesture back, clean state

# ---------------------------------------------------------------------------
# (f) PIVOT FIDELITY (atom-6-specific): the logged pivot must reproduce the effect.
#     A log that emitted a DIFFERENT pivot than run_core applied (e.g. mouse coords
#     while the effect used argv, or vice-versa) would diverge here. Test with a
#     NON-trivial scripted pivot AND with the Shift-R mouse pivot: replay the EXACT
#     logged line on a fresh wire and require the SAME coords the live verb produced.
# ---------------------------------------------------------------------------
diag_selected
xschem rotate 40 20
set live [wcoord]
set line [last_rotate_line]
check "(f) scripted pivot: logged line is byte-exact 'xschem rotate 40 20'" \
  [expr {$line eq "xschem rotate 40 20"}] "got=>$line<"
diag_selected
eval $line
check "(f) scripted pivot: replaying the logged line reproduces the live effect" \
  [expr {[wcoord] eq $live}] "live=$live replay=[wcoord]"

diag_selected
xschem callback $WIN 2 360 260 82 0 0 1        ;# Shift-R at a different pixel -> mouse pivot
set live [wcoord]
set line [last_rotate_line]
check "(f) Shift-R mouse pivot: a logged 'xschem rotate <px> <py>' line exists" \
  [expr {[string match {xschem rotate *} $line]}] "got=>$line<"
diag_selected
eval $line
check "(f) Shift-R mouse pivot: replaying the logged line reproduces the live effect" \
  [expr {[wcoord] eq $live}] "live=$live replay=[wcoord]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
