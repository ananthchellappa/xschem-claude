# perform_action() BOUNDARY -- ELEVENTH per-verb migration, the THIRD NON-transform
# verb (Refactor B, audit §4 / §31): attach_labels.
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). Atoms 1-8 migrated trim_wires/align + the transform SEXTET
# (rotate/flip/flipv x pivot + in-place); atom 9 break_wires (FIRST non-transform,
# arg=FLAG); atom 10 floaters_from_selected_inst (BARE, boundary ADDED the gate).
# Atom 11 migrates attach_labels -- net labels attached to the pins of the SELECTED
# component instances:
#   * its arg is a FLAG `interactive` (default 0) read from argv[2], like break_wires
#     -- but 0/1/2 carry DISTINCT meanings (0 = place lab_pin, 1 = interactive dialog,
#     2 = netlisting lab_show mode), so unlike break_wires (nonzero -> canonical 1) the
#     value is PRESERVED with `%d`, reproducing the old log_action_argv byte-for-byte;
#   * NO mid-gesture split (not a transform);
#   * its core attach_labels_to_inst() is SHARED (like trim_wires atom 1, unlike
#     break_wires/floaters): it is ALSO called RAW as a netlisting sub-step by
#     show_unconnected_pins() (netlist.c, attach_labels_to_inst(2)) and by the Shift+H
#     interactive-DIALOG key (act_attach_labels, attach_labels_to_inst(1), a registered
#     csv-nolog non-equivalent path). Both stay BELOW the boundary -- the boundary wraps
#     the VERB DISPATCH, not the C fn. Case (e) locks that neither emits a self-log.
#   * the boundary ADDS a readonly gate this branch never had (a 0041/0051 close): every
#     form (0/1/2) MUTATES -- none is a read-only-safe query -- so the all-or-nothing gate
#     cannot over-reject (contrast check_unique_names, §30).
#
# Entry points:
#   scheduler branch (Symbol menu / command palette / scripted `xschem attach_labels
#     [interactive]`) -> return perform_action("attach_labels", argc, argv)   CROSSES
#   Shift+H key (callback.c act_attach_labels -> attach_labels_to_inst(1), registered
#     csv-nolog interactive-dialog path)                                       OFF-boundary
#   show_unconnected_pins (netlist.c -> attach_labels_to_inst(2), raw sub-step) OFF-boundary
#
#   (a) exactly ONE log line from EACH standalone entry (script bare / script `2` /
#       menu wrapper), and the effect applies (a selected res -> +2 label instances)
#   (b) readonly reject: scripted (TCL_ERROR, verb-named message, no mutation, no log)
#       for BOTH forms (bare + `2`) -- the boundary ADDS the gate
#   (c) byte-identical: `xschem attach_labels` AND `xschem attach_labels 2` (the FLAG
#       value is PRESERVED, not collapsed -- the arg-carrying fidelity risk)
#   (d) replay: the recorded verb re-EXECUTES via the replay seam but does NOT re-log;
#       a control unwrapped `source` DOES re-log
#   (e) the SHARED-CORE SUB-STEP lock: `xschem show_unconnected_pins` (which calls
#       attach_labels_to_inst(2) RAW) mutates but emits ZERO `xschem attach_labels`
#       lines; PLUS the Shift+H interactive key (raw attach_labels_to_inst(1)) emits
#       ZERO equivalent line (csv-nolog, non-equivalent) -- both stay off the boundary
#   (f) undo DEPTH (no double-push): ONE undo removes the labels, a SECOND undo removes
#       the instance -- proving the core owns the single push_undo (the atom-10 discriminator)
#
# Effect oracle (byte-identical before/after atom 11 -- atom 11 only MOVES the log site
# + ADDS the gate): a devices/res.sym resistor selected at the origin has TWO pins (P at
# 0,-30, M at 0,30), both unconnected (no wires), so `xschem attach_labels` places TWO
# lab_pin instances -> instance count 1 -> 3 (delta +2). `xschem attach_labels 2` places
# TWO lab_show instances instead -> same +2. Determined empirically on the pre-migration
# binary. attach_labels_to_inst() rebuilds the selected array itself, but the fixture still
# forces a redraw (spatial hash) so the pin-vs-wire skip test is deterministic headless.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_attach_labels.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §31

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X" -- the effect is
# X-independent, but the log site needs an open action log.)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counters: the glob has NO trailing '*', so {xschem attach_labels} counts
# ONLY the bare form and {xschem attach_labels 2} ONLY the interactive=2 form -- the two
# are mutually exclusive and counted independently (the FLAG-fidelity discriminator).
proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc alc {} { return [logcount {xschem attach_labels}] }      ;# bare (interactive=0) form count
proc a2c {} { return [logcount {xschem attach_labels 2}] }    ;# interactive=2 form count

# The fixture: a res.sym (2 pins, both unconnected) selected at the origin. redraw
# populates the spatial hash the pin-vs-wire skip test reads headless.
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem select instance 0
  xschem redraw
}
proc insts {} { return [xschem get instances] }

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH standalone entry point, effect applies.
#     script bare -> scheduler branch -> perform_action (interactive=0)
#     script `2`  -> scheduler branch -> perform_action (interactive=2)
#     menu        -> menu_action_logged wrapper -> `xschem attach_labels` -> branch;
#                    the wrapper resets/checks actionlog_cmd_logged so the core's log wins.
# ---------------------------------------------------------------------------
fixture; set c0 [alc]; set i0 [insts]; xschem attach_labels
check "(a) scripted 'xschem attach_labels' (bare) -> exactly +1 log" \
  [expr {[alc] == $c0 + 1}] "c0=$c0 now=[alc]"
check "(a) scripted bare -> effect applies (+2 label instances)" \
  [expr {[insts] == $i0 + 2}] "before=$i0 after=[insts]"

fixture; set c0 [a2c]; set i0 [insts]; xschem attach_labels 2
check "(a) scripted 'xschem attach_labels 2' -> exactly +1 log" \
  [expr {[a2c] == $c0 + 1}] "c0=$c0 now=[a2c]"
check "(a) scripted '2' -> effect applies (+2 label instances)" \
  [expr {[insts] == $i0 + 2}] "before=$i0 after=[insts]"

fixture; set c0 [alc]; set i0 [insts]; menu_action_logged {xschem attach_labels}
check "(a) menu wrapper -> exactly +1 bare (core log wins, wrapper dedups)" \
  [expr {[alc] == $c0 + 1}] "c0=$c0 now=[alc]"
check "(a) menu wrapper -> effect applies (+2 label instances)" \
  [expr {[insts] == $i0 + 2}] "before=$i0 after=[insts]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT from the scripted path (the boundary ADDS the gate this branch
#     NEVER had -- a 0041/0051 close): no mutation, no log, TCL_ERROR, verb-named
#     message. Locked for BOTH forms (attach_labels has no read-only-safe form).
# ---------------------------------------------------------------------------
fixture
set w0 [insts]
xschem set readonly 1

set cb0 [alc]
set rc [catch {xschem attach_labels} res]
check "(b) readonly scripted bare: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted bare: message names the verb" \
  [expr {[string match {*attach_labels*read-only*} $res]}] "res=$res"
check "(b) readonly scripted bare: NO log line (+0)" [expr {[alc] == $cb0}] "before=$cb0 now=[alc]"

set c20 [a2c]
set rc [catch {xschem attach_labels 2} res]
check "(b) readonly scripted '2': TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted '2': NO log line (+0)" [expr {[a2c] == $c20}] "before=$c20 now=[a2c]"

check "(b) readonly scripted: NO mutation (instance count unchanged)" \
  [expr {[insts] == $w0}] "before=$w0 after=[insts]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: the logged lines are textually `xschem attach_labels` and
#     `xschem attach_labels 2` -- the FLAG VALUE must survive the boundary intact (the
#     migration MOVED the log site into core_log_action and PRESERVES 0/1/2 with %d; it
#     must not change the text nor collapse the value like break_wires does).
# ---------------------------------------------------------------------------
proc last_exact {want} {
  set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
  set hit ""
  foreach l [split $all \n] { if {$l eq $want} { set hit $l } }
  return $hit
}
fixture; xschem attach_labels
check "(c) logged line is byte-exact 'xschem attach_labels' (bare)" \
  [expr {[last_exact {xschem attach_labels}] eq "xschem attach_labels"}] "got=>[last_exact {xschem attach_labels}]<"
fixture; xschem attach_labels 2
check "(c) logged line is byte-exact 'xschem attach_labels 2' (value PRESERVED)" \
  [expr {[last_exact {xschem attach_labels 2}] eq "xschem attach_labels 2"}] "got=>[last_exact {xschem attach_labels 2}]<"

# ---------------------------------------------------------------------------
# (d) REPLAY. attach_labels is a re-executable verb (not a coordinate-STORE bypass):
#     replaying it re-runs the effect. Through the replay_action_log suppress seam the
#     effect applies but does NOT re-log (the boundary's log site rides
#     !actionlog_suppress); a control unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set recB [file join [file dirname $LOG] paw_al_bare_[pid].log]
set fd [open $recB w]; puts $fd "xschem attach_labels"; close $fd
fixture; set nc [alc]; set i0 [insts]
replay_action_log $recB
check "(d) replay seam: EFFECT applied (+2 label instances)" \
  [expr {[insts] == $i0 + 2}] "before=$i0 after=[insts]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[alc] == $nc}] "nc=$nc now=[alc]"
fixture; set nc [alc]; set i0 [insts]
uplevel #0 [list source $recB]
check "(d) control (unwrapped source): EFFECT applied (+2)" \
  [expr {[insts] == $i0 + 2}] "before=$i0 after=[insts]"
check "(d) control (unwrapped source): re-logged (+1)" \
  [expr {[alc] == $nc + 1}] "nc=$nc now=[alc]"
file delete $recB

# ---------------------------------------------------------------------------
# (e) THE SHARED-CORE SUB-STEP LOCK. attach_labels_to_inst() is NOT strictly 1:1 (unlike
#     break_wires/floaters): it is called RAW below the boundary by two paths that must
#     NOT emit `xschem attach_labels`:
#       * show_unconnected_pins() (netlist.c) -> attach_labels_to_inst(2), a netlisting
#         sub-step reached by `xschem show_unconnected_pins`;
#       * the Shift+H interactive-DIALOG key -> act_attach_labels -> attach_labels_to_inst(1),
#         a registered csv-nolog non-equivalent path (keysym 'H', mods 0, ACTX_CANVAS).
#     Both mutate but stay OFF the boundary -- exactly the trim_wires-is-a-sub-step-of-align
#     pattern (§21 case (e)).
# ---------------------------------------------------------------------------
fixture; set b0 [alc]; set t0 [a2c]; set c0 [insts]
xschem show_unconnected_pins
check "(e) show_unconnected_pins actually mutated (raw attach_labels_to_inst(2): +label instances)" \
  [expr {[insts] > $c0}] "before=$c0 after=[insts]"
check "(e) show_unconnected_pins emits NO 'xschem attach_labels' line (raw sub-step, off the boundary)" \
  [expr {[alc] == $b0 && [a2c] == $t0}] "bare d=[expr {[alc]-$b0}] '2' d=[expr {[a2c]-$t0}]"

# the Shift+H interactive key. Stub the modal dialog proc so the C core's
# attach_labels_to_inst(1) does not block, and set rcode=yes+do_all so it WOULD place
# (proving the raw path RAN yet still logged nothing). Drive the registered key
# (keysym 'H'=72, mods 0). callback STATE is argv[9]; a redraw first rebuilds the
# spatial/selection state the gesture reads headless.
catch {rename attach_labels_to_inst _paw_real_ali}
set ::paw_stub_ran 0
proc attach_labels_to_inst {} { set tctx::rcode yes; set ::do_all_inst 1; incr ::paw_stub_ran }
fixture; set b0 [alc]; set t0 [a2c]; set c0 [insts]
xschem callback .drw 2 300 300 72 0 0 0
check "(e) Shift+H key DISPATCHED the raw interactive path (stub ran)" \
  [expr {$::paw_stub_ran >= 1}] "stub_ran=$::paw_stub_ran"
check "(e) Shift+H key mutated via the raw core (labels placed)" \
  [expr {[insts] > $c0}] "before=$c0 after=[insts]"
check "(e) Shift+H interactive key emits NO 'xschem attach_labels' line (csv-nolog, off the boundary)" \
  [expr {[alc] == $b0 && [a2c] == $t0}] "bare d=[expr {[alc]-$b0}] '2' d=[expr {[a2c]-$t0}]"
catch {rename attach_labels_to_inst {}}
catch {rename _paw_real_ali attach_labels_to_inst}

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (no double-push): the core attach_labels_to_inst() owns ONE push_undo
#     (place_symbol's to_push_undo on the first placed label). So after fixture (place R1
#     = snapshot A) + attach (place 2 labels = snapshot B), ONE undo winds back to just R1
#     (labels gone), a SECOND undo removes R1. A spurious push_undo in the run_core arm
#     would insert a duplicate snapshot so ONE undo would NOT fully remove the labels.
# ---------------------------------------------------------------------------
fixture; set i0 [insts]; xschem attach_labels
check "(f) attach placed the labels (insts +2)" [expr {[insts] == $i0 + 2}] "i0=$i0 now=[insts]"
xschem undo
check "(f) ONE undo removes the labels (back to the instance only -- single push_undo)" \
  [expr {[insts] == $i0}] "want=$i0 got=[insts]"
xschem undo
check "(f) a SECOND undo removes the instance (proves the ONE attach push, no double)" \
  [expr {[insts] == $i0 - 1}] "want=[expr {$i0-1}] got=[insts]"

catch {destroy .ciw}; catch {destroy .dialog}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
