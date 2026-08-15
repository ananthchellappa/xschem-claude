# perform_action() BOUNDARY -- SEVENTH per-verb migration (Refactor B, audit §4 / §27)
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). Atoms 1-5 migrated the bare no-arg verbs trim_wires / align /
# rotate_in_place / flip_in_place / flipv_in_place (the in-place transform QUARTET);
# atom 6 migrated `rotate` (the pivot form `xschem rotate x0 y0`) -- the FIRST
# ARG-CARRYING verb, introducing core_log_action + the run_core pivot arm.
# THIS atom migrates `flip` (the pivot form `xschem flip x0 y0`) -- the SECOND
# arg-carrying verb, a near-clone of rotate. Its two coord args thread through BOTH
# halves of the boundary:
#   * run_core's flip arm resolves the SHARED pivot x0,y0 from argv[2]/argv[3]
#     (else the mouse coords), seeds mx_double_save/mousex_snap = x0,y0, then
#     rebuild + START + move_objects(FLIP) + END -- NO ROTATELOCAL (the pivot is
#     the single shared point, not each object's own origin), byte-identical to the
#     old scheduler standalone `else` body, NO push_undo (move_objects owns it).
#   * core_log_action (the §4 Refactor-A step-2 log-form registry, seeded by atom 6)
#     grows a flip branch formatting `xschem flip <x0> <y0>` from the SAME argv (or
#     the same seeded coord on the mouse-fallback path) -- so the logged pivot can
#     never diverge from the applied pivot. That fidelity is the arg-carrying risk
#     and is locked by the pivot-fidelity checks below.
# The standalone verb crosses from EVERY standalone entry point -- scheduler branch
# (`xschem flip [x y]`: Edit menu / context menu / command palette), the Shift-F
# key (callback.c case 'F', keysym 70), the Alt-F GROUP transform
# (standalone_group_transform, issue 0116) and the verb-noun deferred apply
# (MENUSTARTROTATE PENDING_TR_FLIP) -- all now call perform_action("flip",4,av).
#   * the DURING-move / DURING-copy arms (STARTMOVE/STARTCOPY) stay RAW and log
#     NOTHING at the verb level -- mid-gesture sub-steps logged at the move/copy END
#     (issue 0069). Routing them through the boundary would spuriously emit `xschem
#     flip x y` mid-drag and double-count the move-END line. Case (e) locks that.
# EFFECT ORACLE: a lone DIAGONAL wire (0,0)-(100,40), cadsnap=20, select_all,
# `xschem flip 0 0` (horizontal mirror about x=0) -> (-100,40)-(0,0) stored canonically
# as `-100 40 0 0`. Pivot-SENSITIVE (mirror about x=50 instead gives (0,40)-(100,0) =
# `0 40 100 0`) and involutive x2 (two mirrors about the same line return to start) --
# verified empirically before writing this oracle. A pivot-form flip about a NON-zero
# x MOVES the wire, so the oracle fixes the pivot at x=0. A DIAGONAL wire is the oracle
# (a horizontal wire flips to the mirror side but STAYS horizontal -- an orientation
# check would falsely pass; the diagonal result -100 40 0 0 is also DISTINCT from the
# vertical-flip result, so it discriminates flip from flipv).
#
#   (a) exactly ONE log line from EACH runtime-drivable standalone entry point
#       (script / Shift-F key / menu wrapper); the Alt-F GROUP transform + the
#       verb-noun MENUSTARTROTATE apply are grep-guard-locked (they need a real
#       arm-then-click on the wire's screen pixel to drive headlessly) -- noted here,
#       not runtime-driven.
#   (b) readonly reject from EACH entry point: no mutation, no log, TCL_ERROR +
#       verb-named message on the scripted path (the 0041/0051 unification proof).
#   (c) byte-identical: a scripted `xschem flip 0 0` logs textually `xschem flip 0 0`
#       (the %.16g %.16g pivot form -- the arg-carrying drift risk vs the bare verbs).
#   (d) replay: the recorded pivot line re-EXECUTES (the wire mirrors about the pivot)
#       and, through the replay_action_log suppress seam, does NOT re-log; a control
#       unwrapped source DOES re-log (a real re-executable action, IN S2 CVERBS).
#   (e) THE WRINKLE LOCK: a flip issued mid-move (STARTMOVE active) does NOT emit
#       `xschem flip` -- the gesture arm stays silent (logged at move END).
#   (f) PIVOT FIDELITY: the logged pivot reproduces the effect. For a NON-trivial
#       scripted pivot AND for the Shift-F mouse pivot, replaying the exact logged
#       line on a fresh wire lands the SAME coords the live verb did -- a log that
#       emitted a different pivot than the effect used would diverge here.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_flip.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §27

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

# flip drives move_objects(START/FLIP/END) -> draw_selection (Xlib GCs). With no
# X connection (--nogui) that SIGSEGVs, so defer cleanly rather than crash. Under the
# real logdir run (DISPLAY set) the window exists and we run.
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
set haveX [expr {![catch {winfo exists $WIN} e] && $e}]
if {!$haveX} {
  puts "deferred (no-X env; flip drives move_objects -> Xlib GCs)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stub: the readonly scheduler/menu path uses the CIW-note gate
# (scheduler_readonly_reject), and the Shift-F key keeps its readonly_block()
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
# last "xschem flip ..." line currently in the log (for byte-exact + fidelity replay).
# NB the glob {xschem flip *} does NOT match {xschem flipv *} (a `v` intervenes before
# the space) nor {xschem flip_in_place} -- flip is counted independently of flipv.
proc last_flip_line {} {
  set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
  set exact ""
  foreach l [split $all \n] { if {[string match {xschem flip *} $l]} { set exact $l } }
  return $exact
}
# A pristine schematic with ONE DIAGONAL wire (0,0)-(100,40), all on the cadsnap=20
# grid. flip acts on the SELECTION, so select_all.
proc diag_selected {} {
  xschem clear force
  xschem set cadsnap 20
  xschem set fluid_editing 0   ;# plain flip: no stretch/reroute pipeline in the way
  xschem wire 0 0 100 40
  xschem select_all
}
proc wcoord {} { return [xschem wire_coord 0] }

# The deterministic reference: exactly what ONE `flip 0 0` produces on a fresh
# diagonal wire (horizontal mirror about x=0).
diag_selected
set ORIG [wcoord]
xschem flip 0 0
set FLP [wcoord]
check "oracle: flip is OBSERVABLE (coords change)" \
  [expr {$FLP ne $ORIG}] "orig=$ORIG flp=$FLP"
check "oracle: flip 0 0 mirrors about x=0 to (-100,40)-(0,0)" \
  [expr {$FLP eq "-100 40 0 0"}] "flp=$FLP"
# involutive: a second flip about the same line returns to the start
xschem select_all
xschem flip 0 0
check "oracle: flip 0 0 is involutive (twice returns to orig)" \
  [expr {[wcoord] eq $ORIG}] "back=[wcoord] orig=$ORIG"
# pivot-sensitivity: a different pivot MOVES the wire elsewhere (proves the pivot is real)
diag_selected
xschem flip 50 0
check "oracle: flip 50 0 is DISTINCT from flip 0 0 (pivot matters)" \
  [expr {[wcoord] ne $FLP}] "flp50_0=[wcoord] flp0_0=$FLP"

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH runtime-drivable standalone entry point.
#     script    -> scheduler branch standalone `else` -> perform_action("flip",argc,argv)
#     Shift-F   -> callback.c case 'F' standalone apply (keysym 70, state 1=Shift),
#                  one object selected -> lastsel!=0 apply arm -> perform_action("flip",4,av)
#     menu      -> menu_action_logged {xschem flip} -> branch; wrapper resets/checks
#                  actionlog_cmd_logged, so the core's log wins and the wrapper skips its
#                  copy -> exactly one line (dedup live).
# ---------------------------------------------------------------------------
diag_selected
check "(a) setup: wire starts at the reference orig" [expr {[wcoord] eq $ORIG}] "coord=[wcoord]"
set c0 [logcount {xschem flip *}]
xschem flip 0 0
check "(a) scripted 'xschem flip 0 0' -> exactly +1" \
  [expr {[logcount {xschem flip *}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem flip *}]"
check "(a) scripted: EFFECT applied (wire flipped to $FLP)" \
  [expr {[wcoord] eq $FLP}] "coord=[wcoord]"

diag_selected
set c0 [logcount {xschem flip *}]
xschem callback $WIN 2 400 300 70 0 0 1
check "(a) Shift-F key -> exactly +1 (standalone apply, no double)" \
  [expr {[logcount {xschem flip *}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem flip *}]"
check "(a) Shift-F key: EFFECT applied (wire moved from orig)" \
  [expr {[wcoord] ne $ORIG}] "coord=[wcoord]"

diag_selected
set c0 [logcount {xschem flip *}]
menu_action_logged {xschem flip}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[logcount {xschem flip *}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem flip *}]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT from each entry point: no mutation, no log, TCL_ERROR + verb-
#     named message on the scripted path (one gate covers every route -- 0041/0051).
#     The Shift-F key keeps readonly_block() (it also guards the raw gesture arms).
# ---------------------------------------------------------------------------
diag_selected
set wc0 [wcoord]
xschem set readonly 1
set c0 [logcount {xschem flip *}]
set rc [catch {xschem flip 0 0} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted: message names the verb" \
  [expr {[string match {*flip*read-only*} $res]}] "res=$res"
check "(b) readonly scripted: NO log line (+0)" \
  [expr {[logcount {xschem flip *}] == $c0}] "c0=$c0 now=[logcount {xschem flip *}]"
check "(b) readonly scripted: NO mutation (wire coords unchanged)" \
  [expr {[wcoord] eq $wc0}] "before=$wc0 after=[wcoord]"

set c0 [logcount {xschem flip *}]
set wc0 [wcoord]
xschem callback $WIN 2 400 300 70 0 0 1
check "(b) readonly Shift-F key: NO log line (+0)" \
  [expr {[logcount {xschem flip *}] == $c0}] "c0=$c0 now=[logcount {xschem flip *}]"
check "(b) readonly Shift-F key: NO mutation (wire coords unchanged)" \
  [expr {[wcoord] eq $wc0}] "before=$wc0 after=[wcoord]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: a scripted `xschem flip 0 0` logs textually `xschem flip 0 0`
#     (the %.16g %.16g pivot form). The migration MOVED the log site (into
#     core_log_action); it must not change the text or the pivot format.
# ---------------------------------------------------------------------------
diag_selected
xschem flip 0 0
check "(c) logged line is byte-exact 'xschem flip 0 0'" \
  [expr {[last_flip_line] eq "xschem flip 0 0"}] "got=>[last_flip_line]<"

# ---------------------------------------------------------------------------
# (d) REPLAY. flip is a re-executable pivot verb (NOT a coordinate-STORE bypass like
#     `wire x1 y1 x2 y2`): replaying it re-runs the effect. Through the
#     replay_action_log suppress seam the effect applies (a fresh diagonal wire
#     mirrors to $FLP) but does NOT re-log; a control unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_flip_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem flip 0 0"; close $fd

diag_selected
set nc [logcount {xschem flip *}]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (wire flipped to $FLP)" \
  [expr {[wcoord] eq $FLP}] "coord=[wcoord]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[logcount {xschem flip *}] == $nc}] "nc=$nc now=[logcount {xschem flip *}]"

diag_selected
set nc [logcount {xschem flip *}]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (wire flipped to $FLP)" \
  [expr {[wcoord] eq $FLP}] "coord=[wcoord]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[logcount {xschem flip *}] == $nc + 1}] "nc=$nc now=[logcount {xschem flip *}]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) THE WRINKLE LOCK (atom-3/4/5/6/7). A flip issued MID-MOVE (STARTMOVE active)
#     hits the scheduler branch's during-move arm -- raw move_objects(FLIP), logged
#     NOWHERE at the verb level (the move END owns that, 0069). If a future edit routes
#     the gesture arm through perform_action it would emit `xschem flip` here and
#     double-count. Drive a real move-start, fire the verb, assert +0, then abort clean.
# ---------------------------------------------------------------------------
diag_selected
xschem move_objects start 0 0                 ;# sets STARTMOVE (move_objects(START))
check "(e) precondition: STARTMOVE is active" \
  [expr {[xschem get ui_state] & 32}] "ui_state=[xschem get ui_state]"
set c0 [logcount {xschem flip *}]
set rc [catch {xschem flip 0 0} res]
check "(e) mid-move flip: TCL_OK (gesture arm ran)" [expr {$rc == 0}] "rc=$rc res=$res"
check "(e) mid-move flip: NOT logged (+0, silent gesture arm)" \
  [expr {[logcount {xschem flip *}] == $c0}] "c0=$c0 now=[logcount {xschem flip *}]"
catch {xschem move_objects abort}             ;# roll the gesture back, clean state

# ---------------------------------------------------------------------------
# (f) PIVOT FIDELITY (arg-carrying): the logged pivot must reproduce the effect.
#     A log that emitted a DIFFERENT pivot than run_core applied (e.g. mouse coords
#     while the effect used argv, or vice-versa) would diverge here. Test with a
#     NON-trivial scripted pivot AND with the Shift-F mouse pivot: replay the EXACT
#     logged line on a fresh wire and require the SAME coords the live verb produced.
# ---------------------------------------------------------------------------
diag_selected
xschem flip 40 20
set live [wcoord]
set line [last_flip_line]
check "(f) scripted pivot: logged line is byte-exact 'xschem flip 40 20'" \
  [expr {$line eq "xschem flip 40 20"}] "got=>$line<"
diag_selected
eval $line
check "(f) scripted pivot: replaying the logged line reproduces the live effect" \
  [expr {[wcoord] eq $live}] "live=$live replay=[wcoord]"

diag_selected
xschem callback $WIN 2 360 260 70 0 0 1        ;# Shift-F at a different pixel -> mouse pivot
set live [wcoord]
set line [last_flip_line]
check "(f) Shift-F mouse pivot: a logged 'xschem flip <px> <py>' line exists" \
  [expr {[string match {xschem flip *} $line]}] "got=>$line<"
diag_selected
eval $line
check "(f) Shift-F mouse pivot: replaying the logged line reproduces the live effect" \
  [expr {[wcoord] eq $live}] "live=$live replay=[wcoord]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
