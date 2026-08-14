# perform_action() BOUNDARY -- Refactor B ATOM 24 (audit §44): migrate the `delete` verb.
#
# `delete` is the pick from a fresh exhaustive re-scout (303 branches, 22 dispatch groups) of
# scheduler.c's mutating verbs under the CURRENT (log-on-success, atom 13) boundary contract; see
# doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md. It is a BARE no-arg
# mutating verb, the near-twin of toggle_ignore (atom 12) / floaters (atom 10): the core delete()
# (select.c) OWNS its undo (push_undo on the first mutation), set_modify + draw, and returns VOID =>
# the run_core arm is always TCL_OK and adds NO push_undo/draw (the atom-1 no-double-push rule). The
# bare `xschem delete` logs via core_log_action's DEFAULT `xschem %s` arm.
#
# THE ONE FRICTION is the ARITY GATE (F-validate, the reset_inst_prop §33 argc-gate): the OLD branch
# acted only inside `if(argc==2)`, so a malformed `xschem delete <extra>` was a SILENT no-op returning
# TCL_OK -- which under log-on-success would PHANTOM-log. run_core now validates argc==2 and returns
# TCL_ERROR otherwise (mutating nothing, logging nothing). This is the ONE deliberate behaviour tighten
# the migration introduces: malformed -> rejected error, not silent-OK. Check (b) is its proof.
#
# THE SHARED-PRIMITIVE / SECOND-ENTRY discipline (locked by check (g)): delete() is a widely shared
# primitive -- the `cut` verb, preview teardowns (delete(0)), and the Ctrl-X / XK_Delete inline
# legacy-switch KEYS (callback.c) all call it RAW and self-log; they NEVER reach this scheduler branch.
# Only the `delete` VERB crosses the boundary (the trim_wires atom-1 shared-sub-step rule). Migrating
# the verb must NOT disturb the sibling `cut` (which is `save_selection(2)` + `delete(1)` + self-logged
# `xschem cut`): check (g) drives `xschem cut` and asserts it still deletes + logs its OWN line.
#
# Checks:
#   (a) SUCCESS: select an instance, `xschem delete` -> instance removed, exactly +1 `xschem delete`.
#   (b) THE ATOM-24 HEADLINE -- ARITY TIGHTEN: `xschem delete extra` returns TCL_ERROR with a
#       NON-EMPTY verb-named message (Tcl_ResetResult did not wipe it -- the atom-13 landmine),
#       mutates NOTHING, and logs +0. (Pre-migration this was a silent TCL_OK no-op.)
#   (c) READONLY reject: TCL_ERROR, verb-named read-only message (non-empty), no mutation, no log.
#   (d) REPLAY: the recorded `xschem delete` re-EXECUTES through the replay_action_log suppress seam
#       (deletes the ambient selection) but does NOT re-log; a control unwrapped `source` DOES re-log.
#       delete is selection-dependent, so the fixture re-establishes a selection before each replay.
#   (e) NO-OP-STILL-LOGS (the §30/§32 property, now for delete): `xschem delete` with NOTHING selected
#       mutates nothing (delete() bails before push_undo) but STILL logs +1 -- a no-op is a SUCCESS
#       (rc==TCL_OK), so log-on-success keeps logging it.
#   (f) UNDO DEPTH (the atom-1 no-double-push rule): delete() owns the SINGLE push_undo. After delete,
#       ONE undo restores the deleted instances. A spurious run_core double-push would need TWO undos.
#   (g) SIBLING UNTOUCHED: `xschem cut` still deletes the selection and logs its OWN `xschem cut` line
#       (NOT `xschem delete`) -- the shared delete() primitive and the cut branch are undisturbed.
#
# Effect oracle: N resistors (devices/res.sym) placed at distinct coords; `xschem get instances`
# reads the count. Selecting + `xschem delete` drops the count to 0; one undo restores it.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_delete.tcl
# doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md §5

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers this in
# logdir_tests so LOG is always set in the real run; the guard keeps a bare invocation from erroring.
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counters (the recorded verbs are single-line, so match the whole line).
proc lc {v} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {$l eq "xschem $v"} { incr n } }; return $n
}
proc dc {} { return [lc delete] }                 ;# `xschem delete` count
proc ninst {} { return [xschem get instances] }

# Fixture: place `n` resistors at distinct coords; no selection yet.
proc fixture {{n 3}} {
  xschem clear force
  for {set i 0} {$i < $n} {incr i} {
    xschem instance devices/res.sym [expr {$i*40}] 0 0 0 "name=R[expr {$i+1}]"
  }
  xschem redraw
}
# select every instance (delete targets the ambient selection)
proc select_all_inst {} {
  set n [ninst]
  for {set i 0} {$i < $n} {incr i} { xschem select instance $i }
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: a selection deleted -> removed + exactly +1 `xschem delete`.
# ---------------------------------------------------------------------------
fixture 3
check "(a) fixture: 3 instances placed" [expr {[ninst] == 3}] "instances=[ninst]"
select_all_inst
set c0 [dc]
xschem delete
check "(a) scripted 'xschem delete' removes the selection" [expr {[ninst] == 0}] "instances=[ninst]"
check "(a) scripted 'xschem delete' -> exactly +1 log line" [expr {[dc] == $c0 + 1}] "c0=$c0 now=[dc]"
# byte-exact bare form (core_log_action default `xschem %s` arm).
set fd [open [xschem get actionlog_filename] r]; set allD [read $fd]; close $fd
set exactD ""
foreach l [split $allD \n] { if {$l eq {xschem delete}} { set exactD $l } }
check "(a) logged line is byte-exact 'xschem delete' (bare-verb default form)" \
  [expr {$exactD eq "xschem delete"}] "got=>$exactD<"

# ---------------------------------------------------------------------------
# (b) THE ATOM-24 HEADLINE -- ARITY TIGHTEN. `xschem delete extra` -> TCL_ERROR, NON-EMPTY
#     verb-named message (the atom-13 landmine: success-only Tcl_ResetResult did not wipe it),
#     NO mutation, +0 log. Pre-migration this was a SILENT TCL_OK no-op.
# ---------------------------------------------------------------------------
fixture 2
select_all_inst
set t0 [ninst]
set a0 [dc]
set e1 [catch {xschem delete extra} m1]
check "(b) extra-arg: TCL_ERROR (was a silent no-op pre-migration)" [expr {$e1 == 1}] "rc=$e1"
check "(b) extra-arg: NON-EMPTY verb-named message (landmine: message survives on TCL_ERROR)" \
  [expr {[string match {*delete*argument*} $m1]}] "msg=>$m1<"
check "(b) extra-arg: NO log line (+0 -- failure not logged)" [expr {[dc] == $a0}] "a0=$a0 now=[dc]"
check "(b) extra-arg: NO mutation (selection intact)" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"

# ---------------------------------------------------------------------------
# (c) READONLY reject: the boundary's ONE generic gate refuses -> TCL_ERROR, verb-named
#     read-only message (non-empty), NO mutation, NO log.
# ---------------------------------------------------------------------------
fixture 2
select_all_inst
set t0 [ninst]
xschem set readonly 1
set a0 [dc]
set e3 [catch {xschem delete} m3]
check "(c) readonly: TCL_ERROR" [expr {$e3 == 1}] "rc=$e3"
check "(c) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*delete*read-only*} $m3]}] "msg=>$m3<"
check "(c) readonly: NO log line (+0)" [expr {[dc] == $a0}] "a0=$a0 now=[dc]"
check "(c) readonly: NO mutation" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY. delete is selection-dependent: the recorded `xschem delete` replays against the
#     ambient selection. Through the replay_action_log suppress seam the effect applies but does
#     NOT re-log; a control unwrapped `source` DOES re-log. Re-establish a selection before each.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_delete_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem delete"; close $fd

fixture 2
select_all_inst
set nc [dc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (selection deleted)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[dc] == $nc}] "nc=$nc now=[dc]"

fixture 2
select_all_inst
set nc [dc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (selection deleted)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[dc] == $nc + 1}] "nc=$nc now=[dc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) NO-OP-STILL-LOGS (the §30/§32 property, now for delete). `xschem delete` with NOTHING
#     selected: delete() bails at the has_deletable check BEFORE push_undo, mutates nothing, and
#     returns void => TCL_OK => log-on-success STILL emits +1. A regression that gated the log on
#     "did something delete" (rather than rc==TCL_OK) would drop this.
# ---------------------------------------------------------------------------
fixture 2
xschem unselect_all
set t0 [ninst]
set c0 [dc]
catch {xschem delete}
check "(e) no-op (nothing selected): NO mutation" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
check "(e) no-op (nothing selected) STILL logs +1 under log-on-success" [expr {[dc] == $c0 + 1}] "c0=$c0 now=[dc]"

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (the atom-1 no-double-push rule): delete() owns the SINGLE push_undo. The fixture
#     places 3 instances (each `xschem instance` pushes its own undo), then delete pushes ONE more.
#     So the undo stack is [place R1, place R2, place R3, delete]. ONE undo restores all 3 (delete's
#     snapshot); a SECOND undo peels back place-R3 -> 2 instances. A spurious run_core double-push
#     would leave TWO identical "3 instances" snapshots, so the second undo would STILL read 3 (the
#     duplicate) instead of 2 -- that is what this two-step check catches.
# ---------------------------------------------------------------------------
fixture 3
select_all_inst
xschem delete
check "(f) undo depth: delete removed all 3" [expr {[ninst] == 0}] "instances=[ninst]"
xschem undo
check "(f) undo depth: ONE undo restores the deleted instances (delete's single snapshot)" \
  [expr {[ninst] == 3}] "instances=[ninst]"
xschem undo
check "(f) undo depth: a SECOND undo peels back one placement (3 -> 2) -- a run_core double-push would leave an identical extra snapshot so this would still read 3" \
  [expr {[ninst] == 2}] "instances=[ninst]"

# ---------------------------------------------------------------------------
# (g) SIBLING UNTOUCHED. `xschem cut` = save_selection(2) + delete(1) + self-logged `xschem cut`.
#     Migrating `delete` must not disturb it: cut still deletes the selection and logs its OWN line
#     (NOT `xschem delete`).
# ---------------------------------------------------------------------------
fixture 2
select_all_inst
set dc0 [dc]
set cc0 [lc cut]
xschem cut
check "(g) sibling cut still deletes the selection" [expr {[ninst] == 0}] "instances=[ninst]"
check "(g) sibling cut logs its OWN 'xschem cut' line (+1)" [expr {[lc cut] == $cc0 + 1}] "cc0=$cc0 now=[lc cut]"
check "(g) sibling cut does NOT log a 'xschem delete' line (+0)" [expr {[dc] == $dc0}] "dc0=$dc0 now=[dc]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
