# perform_action() BOUNDARY -- Refactor B ATOM 25 (audit §45): migrate the `add_pin_stubs` verb.
#
# add_pin_stubs draws a wire stub + an outward lab_pin net-label out of each selected/unconnected pin.
# It was the atom-24 re-scout's fr-4 runner-up; the friction dissolved once the RETURN-VALUE CONDLOG
# decision was resolved as OPTION (c) NO-OP-STILL-LOGS -- see
# doc/claude/code_analysis/perform_action_atom25_add_pin_stubs_returnvalue_condlog_decision.md.
#
# THE DECISION (option c). The core add_pin_stubs() returns `added` (stub count); the OLD branch gated
# its log on `if(added>0)`. Under log-on-success the boundary cannot re-derive `added` in
# core_log_action (unlike atom-21's re-queryable had_sel). Rather than reconcile (TCL_ERROR on
# added==0, which would mis-classify a legit "nothing to stub" no-op as a FAILURE; or a bespoke
# side-channel), option (c) recognises `added==0` as a no-op SUCCESS -- exactly like floaters-nothing-
# selected (§30), toggle_ignore-attr==NULL (§32), delete-nothing-selected (§44), all of which log their
# no-op. So run_core DISCARDS `added`, always returns TCL_OK, and the boundary logs one idempotent
# replayable line UNCONDITIONALLY. Net friction drops to F-flagarg (a per-verb core_log_action arm for
# the -prefix/-suffix/-inst-prefix tail) + F-2ndentry (the SPACE key stays raw) -- a clean, precedented
# atom, NOT a boundary-shape change.
#
# TWO behaviour changes (both benign, both asserted):
#   (1) added==0 no-op now LOGS one line (old `if(added>0)` suppressed it) -- check (b).
#   (2) the success-path count interp-result is dropped (the boundary clears the interp on success; NO
#       Tcl caller consumed it -- Symbol-menu -command discards it, the SPACE key reads the C-fn int
#       return not the Tcl result; the apply_pin_prop §38 precedent). And the scripted verb now REJECTS
#       a read-only cell (TCL_ERROR) where it used to silently return "0" -- a correctness fix (check c).
#
# THE SPACE KEY (act_add_pin_stubs, callback.c) stays RAW below the boundary: it needs the C-fn int
# return for its pan-on-decline dual-use and never reaches this branch, so it cannot double-log (the
# delete/cut F-2ndentry pattern; locked structurally by the grep guard, not driven here).
#
# Checks:
#   (a) SUCCESS bare: select an instance with unconnected pins, `xschem add_pin_stubs` -> 2 stubs
#       (2 wires + 2 lab_pin), exactly +1 byte-exact `xschem add_pin_stubs`.
#   (a2) FLAG form: `xschem add_pin_stubs -prefix p_ -suffix _s` applies (net names p_P_s / p_M_s) and
#       logs the flag tail byte-exact.
#   (b) THE OPTION-(c) HEADLINE -- NO-OP-STILL-LOGS: nothing selected -> add_pin_stubs mutates nothing
#       (collect returns 0 before push_undo) but STILL logs +1 (a no-op is a SUCCESS). Old suppressed it.
#   (c) READONLY reject: TCL_ERROR + verb-named read-only message (non-empty), no mutation, no log --
#       the boundary ADDS the gate the scripted verb never had (was a silent "0").
#   (d) REPLAY: the recorded line re-executes through the replay_action_log suppress seam (re-stubs the
#       ambient selection) but does NOT re-log; a control unwrapped `source` DOES re-log.
#   (e) FLAG-FIDELITY / metachar (the issue-0048 pattern): `-prefix a[0]` logs BRACE-QUOTED
#       (`{a[0]}`, via log_action_argv/Tcl_Merge, NOT raw %s) and the exact logged line REPLAYS without
#       a Tcl error (a raw line would replay `[0]` as a command substitution).
#   (f) UNDO DEPTH (the atom-1 no-double-push rule): add_pin_stubs() owns the SINGLE push_undo. After
#       stubbing, ONE undo removes the stubs (3->1 inst), a SECOND undo removes the placed instance
#       (1->0). A spurious run_core double-push would leave an identical extra snapshot so the second
#       undo would still read 1.
#
# Effect oracle: a resistor (devices/res.sym, pins P and M) alone at the origin -> both pins
# unconnected. `xschem add_pin_stubs` adds 2 wires + 2 lab_pin instances (inst 1->3, wires 0->2).
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_add_pin_stubs.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §45

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# ANY add_pin_stubs* line (proves a no-op logs, and a failure does NOT).
proc apc {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem add_pin_stubs*} $l]} { incr n } }
  return $n
}
proc lc {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {$l eq $pat} { incr n } }; return $n
}
proc ninst {} { return [xschem get instances] }
proc nwire {} { return [xschem get wires] }
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem redraw
}
proc lab_of {i} { set v ""; catch {set v [xschem getprop instance $i lab]}; return $v }

# ---------------------------------------------------------------------------
# (a) SUCCESS bare + (a2) FLAG form.
# ---------------------------------------------------------------------------
fixture
xschem select instance 0
set c0 [apc]
xschem add_pin_stubs
check "(a) bare add_pin_stubs adds 2 stubs (inst 1->3)" [expr {[ninst] == 3}] "inst=[ninst]"
check "(a) bare add_pin_stubs adds 2 stub wires (0->2)" [expr {[nwire] == 2}] "wires=[nwire]"
check "(a) bare -> exactly +1 log line" [expr {[apc] == $c0 + 1}] "c0=$c0 now=[apc]"
check "(a) logged line byte-exact 'xschem add_pin_stubs'" [expr {[lc {xschem add_pin_stubs}] >= 1}] \
  "count=[lc {xschem add_pin_stubs}]"

fixture
xschem select instance 0
set c0 [apc]
xschem add_pin_stubs -prefix p_ -suffix _s
check "(a2) flag form adds stubs" [expr {[ninst] == 3}] "inst=[ninst]"
# net names carry prefix+pinname+suffix (P/M pins of res.sym)
set labs {}
for {set i 0} {$i < [ninst]} {incr i} { set l [lab_of $i]; if {$l ne ""} { lappend labs $l } }
check "(a2) flag form net names reflect -prefix/-suffix (p_P_s / p_M_s)" \
  [expr {[lsearch $labs p_P_s] >= 0 && [lsearch $labs p_M_s] >= 0}] "labs=$labs"
check "(a2) flag tail logged byte-exact" [expr {[lc {xschem add_pin_stubs -prefix p_ -suffix _s}] == 1}] \
  "count=[lc {xschem add_pin_stubs -prefix p_ -suffix _s}]"

# ---------------------------------------------------------------------------
# (b) THE OPTION-(c) HEADLINE -- NO-OP-STILL-LOGS. Nothing selected -> mutates nothing but logs +1.
# ---------------------------------------------------------------------------
fixture
xschem unselect_all
set i0 [ninst]; set w0 [nwire]; set c0 [apc]
catch {xschem add_pin_stubs}
check "(b) no-op (nothing selected): NO mutation" [expr {[ninst] == $i0 && [nwire] == $w0}] \
  "inst=[ninst] wires=[nwire]"
check "(b) no-op STILL logs +1 under log-on-success (option c; old if(added>0) suppressed it)" \
  [expr {[apc] == $c0 + 1}] "c0=$c0 now=[apc]"

# ---------------------------------------------------------------------------
# (c) READONLY reject (the boundary ADDS the gate; old scripted verb silently returned "0").
# ---------------------------------------------------------------------------
fixture
xschem select instance 0
set i0 [ninst]; set c0 [apc]
xschem set readonly 1
set e3 [catch {xschem add_pin_stubs} m3]
check "(c) readonly: TCL_ERROR (old silently returned 0)" [expr {$e3 == 1}] "rc=$e3"
check "(c) readonly: message names verb + read-only (non-empty)" \
  [expr {[string match {*add_pin_stubs*read-only*} $m3]}] "msg=>$m3<"
check "(c) readonly: NO log line (+0)" [expr {[apc] == $c0}] "c0=$c0 now=[apc]"
check "(c) readonly: NO mutation" [expr {[ninst] == $i0}] "inst=[ninst]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY (selection-dependent: re-establish the selection before each).
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_aps_[pid].log]
set fd [open $rec w]; puts $fd "xschem add_pin_stubs"; close $fd

fixture
xschem select instance 0
set nc [apc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (stubs added)" [expr {[ninst] == 3}] "inst=[ninst]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[apc] == $nc}] "nc=$nc now=[apc]"

fixture
xschem select instance 0
set nc [apc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied" [expr {[ninst] == 3}] "inst=[ninst]"
check "(d) control (unwrapped source): re-logged (+1)" [expr {[apc] == $nc + 1}] "nc=$nc now=[apc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) FLAG-FIDELITY / metachar (issue-0048): -prefix a[0] must log BRACE-QUOTED and REPLAY.
# ---------------------------------------------------------------------------
fixture
xschem select instance 0
xschem add_pin_stubs -prefix a\[0\]
set fd [open [xschem get actionlog_filename] r]; set allE [read $fd]; close $fd
set exactE ""
foreach l [split $allE \n] { if {[string match {xschem add_pin_stubs -prefix *a*} $l]} { set exactE $l } }
check "(e) -prefix a\[0\] logged BRACE-QUOTED (Tcl_Merge, not raw %s)" \
  [expr {$exactE eq {xschem add_pin_stubs -prefix {a[0]}}}] "got=>$exactE<"
# replay-safety: the exact logged line must eval without a Tcl error (raw would hit `invalid command 0`)
fixture
xschem select instance 0
set rrc [catch {uplevel #0 $exactE} rres]
check "(e) the logged metachar line REPLAYS without a Tcl error" [expr {$rrc == 0}] "rc=$rrc res=>$rres<"

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (no-double-push): one undo removes the stubs (3->1), a second removes the instance (1->0).
# ---------------------------------------------------------------------------
fixture
xschem select instance 0
xschem add_pin_stubs
check "(f) undo depth: stubbed (inst 3)" [expr {[ninst] == 3}] "inst=[ninst]"
xschem undo
check "(f) undo depth: ONE undo removes the stubs (3->1, add_pin_stubs' single snapshot)" \
  [expr {[ninst] == 1}] "inst=[ninst]"
xschem undo
check "(f) undo depth: a SECOND undo removes the placed instance (1->0) -- a run_core double-push would leave an identical extra snapshot so this would still read 1" \
  [expr {[ninst] == 0}] "inst=[ninst]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
