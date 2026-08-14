# perform_action() BOUNDARY -- Refactor B ATOM 13: the FIRST SHARED-MACHINERY atom
# (audit §4 / §33). Two coupled halves in ONE atom:
#   1. THE BOUNDARY CHANGE: perform_action now logs (and resets the interp result)
#      ONLY on rc == TCL_OK -- LOG-ON-SUCCESS. Atoms 1-12 migrated verbs onto an
#      UNCHANGED boundary whose contract was "log unconditionally after the effect";
#      that contract could not host a VALIDATING verb -- one that rejects a bad
#      argument/precondition with an early TCL_ERROR *before* mutating -- because the
#      rejected call would be phantom-logged (a replayable line that does nothing or
#      errors on replay). Atom 13 changes the SHARED machinery to fix that for the
#      WHOLE validating class (reset_inst_prop, replace_symbol, load_backup,
#      reset_symbol, move_instance, apply_properties, ...).
#   2. THE FIRST BENEFICIARY: reset_inst_prop (resets an instance's property string
#      from its symbol template). It is the FIRST validating verb migrated -- the
#      boundary change has no observable behaviour without a verb whose run_core can
#      fail, so the two ship together.
#
# THE LANDMINE (locked by check (b)/(c) message-non-empty): the log-on-success guard
# ALSO guards the Tcl_ResetResult. reset_inst_prop's run_core Tcl_SetResult's an error
# ("needs 1 more argument" / "instance not found") and returns TCL_ERROR; an
# UNCONDITIONAL Tcl_ResetResult (the old boundary) would WIPE that message before
# returning, so the caller saw an empty error (a known C-side empty-error bug class).
# Resetting only on the TCL_OK path preserves the message on failure AND skips the
# phantom log. The readonly early-return keeps its own message the same way.
#
# THE INVARIANT (locked by check (e)): log-on-success must not silently DROP a log any
# already-migrated verb emits. Every run_core arm returns TCL_OK on its success AND its
# NO-OP path -- crucially the no-op-still-logs verbs (floaters nothing-selected,
# toggle_ignore attr==NULL) return TCL_OK, so they STILL log under log-on-success (a
# no-op is a SUCCESS, not a failure -- the §30/§32 property MUST survive this atom).
#
# reset_inst_prop specifics: it is ARG-CARRYING and SELECTION-INDEPENDENT (targets an
# instance BY NAME or numeric index via get_instance), so the log is the SELF-CONTAINED
# `xschem reset_inst_prop <ref>` (argv[2] read IDENTICALLY in run_core + core_log_action;
# replay re-resolves the referent). It has NO key and NO menu entry -- it is a pure
# scripted verb -- so (a) has ONLY the script entry. Its core is 1:1 (only its own
# scheduler branch calls the inline effect), and run_core owns the SINGLE push_undo
# (there is no self-undo core fn, unlike toggle_ignore/floaters).
#
# Checks:
#   (a) SUCCESS: the script entry -> exactly +1 log line + the effect applies (value
#       resets from a non-template 999 to the template 1k) + byte-exact
#       `xschem reset_inst_prop R1`.
#   (b) THE ATOM-13 HEADLINE -- FAILURE IS NOT LOGGED: `xschem reset_inst_prop` (no
#       arg) and `xschem reset_inst_prop bogus_name` each return TCL_ERROR, set a
#       NON-EMPTY verb-named message (the landmine: Tcl_ResetResult did not wipe it),
#       mutate NOTHING, and log +0. This is the new capability the whole atom exists for.
#   (c) READONLY reject: TCL_ERROR, verb-named + read-only message (non-empty), no
#       mutation, no log.
#   (d) REPLAY: the recorded self-contained `xschem reset_inst_prop R1` re-EXECUTES
#       through the replay_action_log suppress seam but does NOT re-log; a control
#       unwrapped `source` DOES re-log.
#   (e) INVARIANT REGRESSION (the atom-13 safety proof): the no-op-still-logs verbs
#       STILL log under log-on-success. floaters-nothing-selected AND toggle_ignore-
#       attr==NULL each mutate NOTHING but STILL emit +1 -- a no-op returns TCL_OK, so
#       log-on-success keeps logging it. This locks that atom 13 did not break §30/§32.
#   (f) UNDO DEPTH (the atom-1 no-double-push rule): run_core owns reset_inst_prop's
#       SINGLE push_undo. ONE undo restores the prior property (1k -> 999) and a SECOND
#       undo removes the instance -- a spurious run_core double-push would capture the
#       same pre-reset state so the value would survive the first undo.
#
# Effect oracle (byte-identical effect before/after atom 13 -- the migration MOVES the
# validation + gates the log, it does not change the reset): a resistor (devices/res.sym,
# template `value=1k`) placed at the origin with a non-template `value=999`.
# `xschem reset_inst_prop R1` copies the symbol template back into the instance prop,
# so `xschem getprop instance 0 value` goes 999 -> 1k. Determined empirically on the
# pre-migration binary.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_reset_inst_prop.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §33

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X".)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counters (the recorded verbs are single-line, so match the whole line).
proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc rc {} { return [logcount {xschem reset_inst_prop R1}] }      ;# the success line
# ANY reset_inst_prop* line -- to prove a FAILED call logs NOTHING (not even a variant).
proc rc_any {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem reset_inst_prop*} $l]} { incr n } }
  return $n
}
proc val {} { return [xschem getprop instance 0 value] }

# Fixture: a resistor placed at the origin with a NON-template value (999); the template
# is value=1k, so a successful reset is observable as 999 -> 1k. reset_inst_prop targets
# by NAME, so no selection is needed.
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1 value=999}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: the ONE script entry (no key, no menu wrapper) -> exactly +1 log line,
#     the effect applies, and the logged line is the self-contained name form.
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: non-template value in place (999)" [expr {[val] eq "999"}] "value=[val]"
set c0 [rc]
xschem reset_inst_prop R1
check "(a) scripted 'xschem reset_inst_prop R1' -> exactly +1" [expr {[rc] == $c0 + 1}] "c0=$c0 now=[rc]"
check "(a) scripted: effect applied (value resets 999 -> template 1k)" [expr {[val] eq "1k"}] "value=[val]"
# byte-exact: Tcl_Merge quotes MINIMALLY, so a plain refdes logs unbraced `xschem reset_inst_prop R1`.
set fd [open [xschem get actionlog_filename] r]; set allR1 [read $fd]; close $fd
set exactR1 ""
foreach l [split $allR1 \n] { if {$l eq {xschem reset_inst_prop R1}} { set exactR1 $l } }
check "(a) logged line is byte-exact 'xschem reset_inst_prop R1' (Tcl_Merge unbraced for a plain refdes)" \
  [expr {$exactR1 eq "xschem reset_inst_prop R1"}] "got=>$exactR1<"

# (a2) REPLAY-SAFE REFERENT (the adversarial-review finding). An arrayed/bussed instance name
# carries Tcl metacharacters -- a real shipped case is `x2[3:0]` (its instname is literally
# `x2[3:0]`). A RAW `xschem reset_inst_prop x2[3:0]` log line would replay `[3:0]` as a Tcl
# command substitution ("invalid command name 3:0"); the log MUST Tcl-quote the referent
# (log_action_argv/Tcl_Merge -> `xschem reset_inst_prop {x2[3:0]}`) so it round-trips. Assert
# the logged line is brace-quoted AND that replaying that EXACT line re-resolves + resets.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0] value=999}
xschem redraw
set nm [xschem getprop instance 0 name]
check "(a2) arrayed instance instname is literally x2\[3:0\]" [string equal $nm {x2[3:0]}] "name=$nm"
xschem reset_inst_prop {x2[3:0]}
check "(a2) arrayed name: reset applied (999 -> template 1k)" [expr {[val] eq "1k"}] "value=[val]"
set fd [open [xschem get actionlog_filename] r]; set allA [read $fd]; close $fd
set exactA ""
foreach l [split $allA \n] { if {[string match {xschem reset_inst_prop *x2*} $l]} { set exactA $l } }
check "(a2) arrayed name logged BRACE-QUOTED (Tcl_Merge), not raw" \
  [expr {$exactA eq {xschem reset_inst_prop {x2[3:0]}}}] "got=>$exactA<"
# replay-safety: re-place at 888, eval the EXACT logged line, assert it resolved (no Tcl error) + reset.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0] value=888}
xschem redraw
set rrc [catch {uplevel #0 $exactA} rres]
check "(a2) arrayed name: the logged line REPLAYS without a Tcl error (metachar-safe)" \
  [expr {$rrc == 0}] "rc=$rrc res=>$rres<"
check "(a2) arrayed name: replay applied the reset (888 -> 1k)" [expr {[val] eq "1k"}] "value=[val]"

# ---------------------------------------------------------------------------
# (b) THE ATOM-13 HEADLINE -- FAILURE IS NOT LOGGED, and the error message SURVIVES.
#   * no-arg   -> argc<3   -> TCL_ERROR "needs 1 more argument", +0 log, no mutation.
#   * bogus    -> not found -> TCL_ERROR "instance not found",  +0 log, no mutation.
#   The message-non-empty check is the landmine proof (success-only Tcl_ResetResult).
# ---------------------------------------------------------------------------
fixture
set t0 [val]
set a0 [rc_any]
set e1 [catch {xschem reset_inst_prop} m1]
check "(b) no-arg: TCL_ERROR" [expr {$e1 == 1}] "rc=$e1"
check "(b) no-arg: NON-EMPTY verb-named message (landmine: Tcl_ResetResult did not wipe it)" \
  [expr {[string match {*reset_inst_prop*argument*} $m1]}] "msg=>$m1<"
check "(b) no-arg: NO log line (+0 -- failure not logged)" [expr {[rc_any] == $a0}] "a0=$a0 now=[rc_any]"
check "(b) no-arg: NO mutation" [expr {[val] eq $t0}] "before=$t0 after=[val]"

set a1 [rc_any]
set e2 [catch {xschem reset_inst_prop bogus_name} m2]
check "(b) bogus-name: TCL_ERROR" [expr {$e2 == 1}] "rc=$e2"
check "(b) bogus-name: NON-EMPTY verb-named message (landmine)" \
  [expr {[string match {*reset_inst_prop*not found*} $m2]}] "msg=>$m2<"
check "(b) bogus-name: NO log line (+0 -- failure not logged)" [expr {[rc_any] == $a1}] "a1=$a1 now=[rc_any]"
check "(b) bogus-name: NO mutation" [expr {[val] eq $t0}] "before=$t0 after=[val]"

# ---------------------------------------------------------------------------
# (c) READONLY reject: the boundary's ONE generic gate refuses -> TCL_ERROR, verb-named
#     read-only message (non-empty), NO mutation, NO log.
# ---------------------------------------------------------------------------
fixture
set t0 [val]
xschem set readonly 1
set a0 [rc_any]
set e3 [catch {xschem reset_inst_prop R1} m3]
check "(c) readonly: TCL_ERROR" [expr {$e3 == 1}] "rc=$e3"
check "(c) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*reset_inst_prop*read-only*} $m3]}] "msg=>$m3<"
check "(c) readonly: NO log line (+0)" [expr {[rc_any] == $a0}] "a0=$a0 now=[rc_any]"
check "(c) readonly: NO mutation" [expr {[val] eq $t0}] "before=$t0 after=[val]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY. reset_inst_prop is a self-contained, re-executable verb (name in the
#     line, not a coordinate-form bypass): replaying re-runs the reset. Through the
#     replay_action_log suppress seam the effect applies but does NOT re-log; a control
#     unwrapped `source` DOES re-log. The fixture pre-establishes R1 at value=999 so the
#     recorded reset is observable.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_reset_inst_prop_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem reset_inst_prop R1"; close $fd

fixture
set nc [rc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (value -> 1k)" [expr {[val] eq "1k"}] "value=[val]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[rc] == $nc}] "nc=$nc now=[rc]"

fixture
set nc [rc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (value -> 1k)" [expr {[val] eq "1k"}] "value=[val]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[rc] == $nc + 1}] "nc=$nc now=[rc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) INVARIANT REGRESSION -- the atom-13 safety proof. Log-on-success must NOT drop a
#     log any already-migrated verb emits. The subtle case is the NO-OP-STILL-LOGS
#     verbs: their run_core returns TCL_OK even when nothing mutated, so they MUST still
#     log +1 under log-on-success (a no-op is a SUCCESS). Drive both §30 (floaters,
#     nothing selected) and §32 (toggle_ignore, attr==NULL in symbol mode) and assert
#     each STILL emits +1. A regression that gated the log on "did something mutate"
#     (rather than rc==TCL_OK) would silently drop these -- this check catches it.
# ---------------------------------------------------------------------------
proc lc {v} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {$l eq "xschem $v"} { incr n } }; return $n
}
# floaters nothing-selected: no-op, but STILL logs +1. The drive is wrapped in `catch`
# so a migrated verb that regressed to TCL_ERROR (log-on-success would then DROP its log)
# reports a CLEAN log-count FAIL here instead of aborting the script (sabotage 7).
xschem clear force
xschem unselect_all
set c0 [lc floaters_from_selected_inst]
catch {xschem floaters_from_selected_inst}
check "(e) INVARIANT floaters no-op (nothing selected) STILL logs +1 under log-on-success" \
  [expr {[lc floaters_from_selected_inst] == $c0 + 1}] "c0=$c0 now=[lc floaters_from_selected_inst]"

# toggle_ignore attr==NULL (symbol netlist mode): no-op, but STILL logs +1. Same catch guard.
xschem clear force
xschem set netlist_type symbol
xschem instance devices/res.sym 0 0 0 0 {name=R1}
xschem select instance 0
xschem redraw
set ti0 [xschem getprop instance 0 spice_ignore]
set c1 [lc toggle_ignore]
catch {xschem toggle_ignore}
check "(e) INVARIANT toggle_ignore no-op (attr==NULL symbol mode): NO mutation" \
  [expr {[xschem getprop instance 0 spice_ignore] eq $ti0}] \
  "before=>$ti0< after=>[xschem getprop instance 0 spice_ignore]<"
check "(e) INVARIANT toggle_ignore no-op STILL logs +1 under log-on-success" \
  [expr {[lc toggle_ignore] == $c1 + 1}] "c1=$c1 now=[lc toggle_ignore]"
xschem set netlist_type spice

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (the atom-1 no-double-push rule): run_core owns reset_inst_prop's
#     SINGLE push_undo (captured BEFORE set_inst_prop, so the snapshot is value=999).
#     The fixture's undo stack holds the instance-place snapshot + reset's ONE push. So
#     ONE undo restores the prior value (1k -> 999) and a SECOND undo removes the
#     instance. A spurious run_core double-push would capture the SAME pre-reset state,
#     so the value would survive the first undo (two undos needed) and the instance both.
# ---------------------------------------------------------------------------
fixture
xschem reset_inst_prop R1
check "(f) undo depth: reset applied (value -> template 1k)" [expr {[val] eq "1k"}] "value=[val]"
xschem undo
check "(f) undo depth: ONE undo restores the prior value (1k -> 999)" [expr {[val] eq "999"}] "value=[val]"
xschem undo
check "(f) undo depth: a SECOND undo removes the instance (R1 gone) -- reset_inst_prop's single push_undo is the ONLY reset snapshot; a run_core double-push would leave an identical extra one so the value would survive the first undo" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
