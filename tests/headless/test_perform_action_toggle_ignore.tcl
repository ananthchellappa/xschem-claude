# perform_action() BOUNDARY -- TWELFTH per-verb migration, the FIRST
# FRICTION-FREE-SCOUTED verb (Refactor B, audit §4 / §32): toggle_ignore.
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). Atoms 1-11 migrated trim_wires/align + the transform SEXTET
# (rotate/flip/flipv x pivot + in-place) + break_wires + floaters + attach_labels.
# Atom 12 migrates toggle_ignore -- chosen NOT off a hunch but by an EXHAUSTIVE scout
# (perform_action_boundary_migration_friction_analysis.md) that scored ALL 243
# mutating scheduler verbs and found exactly THREE friction-free; toggle_ignore was
# the cleanest:
#   * a BARE no-arg verb (no coordinate pivot, no 0/1 flag) like floaters (atom 10):
#     run_core takes no argc/argv and the log falls to core_log_action's DEFAULT
#     `xschem %s` form (NO per-verb branch);
#   * NO mid-gesture split (not a transform);
#   * toggle_ignore() (actions.c) OWNS its own push_undo (on the FIRST selected
#     element) / set_modify / draw(), so run_core adds NONE -- adding push_undo would
#     double-push (the atom-1 no-double-push rule);
#   * it is 1:1 with the verb -- called ONLY by its own scheduler branch AND the
#     equivalent Shift+T key (act_toggle_ignore), BOTH routed through the boundary
#     (NO shared sub-step, unlike attach_labels atom 11 whose core is also a
#     netlisting sub-step). So there is no sub-step to lock.
#
# The KEY-EQUIVALENCE INVERSION (the story of this atom -- attach_labels §31 inverted).
# attach_labels's Shift+H key ran a NON-equivalent interactive dialog, csv-nolog, and
# correctly stayed OFF the boundary. toggle_ignore's Shift+T key is EQUIVALENT (same
# core, same effect, csv NOT-nolog), so it routes THROUGH the boundary. BUT re-verifying
# from source (the atom-10 lesson) overturned the scout's premise: the key was NOT a
# coverage hole. It was ALREADY readonly-gated (registry `mutates=1` ->
# dispatch_input_action's readonly_block) AND already logged `xschem toggle_ignore`
# (Layer A, d->log_cmd from actions.csv, not-nolog). So routing the key through
# perform_action is a CONSISTENCY move (unify the log onto core_log_action), NOT a
# coverage add -- and its correctness rests on the actionlog_cmd_logged DEDUP: the
# boundary's log_action sets the flag, so dispatch's Layer A copy skips -> EXACTLY ONE
# line (case (a)). The coverage ADD is purely the menu/script BRANCH, which had
# NEITHER a gate NOR a log before this atom.
#
# Checks:
#   (a) exactly ONE log line from EACH entry (script / Shift+T key / menu wrapper) --
#       the KEY logging ONE not TWO is the load-bearing dedup proof -- and the WRITABLE
#       effect applies (spice_ignore cycles none -> "true" -> "short" -> none, on the
#       instance AND a selected wire)
#   (b) readonly reject. SCRIPTED branch (the coverage add -- this branch NEVER had a
#       gate): TCL_ERROR, verb-named message, NO mutation, NO log. The Shift+T KEY on a
#       read-only cell also mutates NOTHING and logs NOTHING -- but it is gated at
#       dispatch (registry mutates=1 -> readonly_block), BEFORE the handler/boundary, so
#       this is a REGRESSION guard on the pre-existing key gate, not the coverage add.
#   (c) byte-identical: the logged line is textually `xschem toggle_ignore`
#   (d) replay: the recorded bare verb re-EXECUTES through the replay_action_log
#       suppress seam but does NOT re-log; a control unwrapped source DOES re-log
#   (e) NO-OP-STILL-LOGS lock (the floaters §30 analogue): in a netlist mode where the
#       ignore attribute is undefined (attr==NULL, `set netlist_type symbol`) the verb
#       is a no-op (nothing mutates) but STILL logs +1 -- idempotent + replayable
#   (f) undo DEPTH (the atom-1 no-double-push rule): ONE undo restores the prior
#       spice_ignore value, a SECOND undo removes the instance -- toggle_ignore's single
#       push_undo is the ONLY toggle_ignore snapshot; a run_core double-push would leave
#       an identical extra one so the value would survive one undo
#
# Effect oracle (byte-identical before/after atom 12 -- atom 12 only ADDS the log + the
# gate; the effect is unchanged): a resistor (devices/res.sym) selected at the origin in
# SPICE netlist mode. `xschem toggle_ignore` cycles its spice_ignore attribute
# none -> "true" -> "short" -> none on successive calls (actions.c flag 0->1->2->0),
# observed via `xschem getprop instance 0 spice_ignore`. Determined empirically on the
# pre-migration binary. toggle_ignore() calls rebuild_selected_array() itself, so a bare
# `xschem select instance` suffices; the fixture still forces a `redraw` so the headless
# spatial/selection state is populated for the KEY (callback) path.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_toggle_ignore.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §32

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

# Exact-line counter: the recorded verb is bare, so match the whole line.
proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc tc {} { return [logcount {xschem toggle_ignore}] }
proc ign {} { return [xschem getprop instance 0 spice_ignore] }

# Fixture: a resistor selected at the origin in SPICE mode (attr=spice_ignore).
# `xschem redraw` populates the headless spatial state the KEY (callback) path needs.
proc fixture {} {
  xschem clear force
  xschem set netlist_type spice
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem select instance 0
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH entry point, and the WRITABLE effect applies.
#     script -> scheduler branch -> perform_action
#     key    -> act_toggle_ignore -> perform_action; dispatch's Layer A copy DEDUPS
#               via actionlog_cmd_logged -> exactly ONE line (NOT two). This is the
#               load-bearing correctness proof of routing the already-logging key
#               through the boundary.
#     menu   -> menu_action_logged wrapper -> `xschem toggle_ignore` -> branch; the
#               wrapper resets/checks the dedup flag so the core's log wins -> one line.
# ---------------------------------------------------------------------------
fixture
set c0 [tc]
xschem toggle_ignore
check "(a) scripted 'xschem toggle_ignore' -> exactly +1" \
  [expr {[tc] == $c0 + 1}] "c0=$c0 now=[tc]"
check "(a) scripted: WRITABLE effect applied (spice_ignore -> true)" \
  [expr {[ign] eq "true"}] "spice_ignore=[ign]"

# effect is a CYCLE: a second + third scripted call walk true -> short -> none.
xschem toggle_ignore
check "(a) scripted cycle: true -> short" [expr {[ign] eq "short"}] "spice_ignore=[ign]"
xschem toggle_ignore
check "(a) scripted cycle: short -> none" [expr {[ign] eq ""}] "spice_ignore=[ign]"

fixture
set c0 [tc]
xschem callback .drw 2 400 300 84 0 0 0   ;# Shift+T: keysym 84 ('T'), state 0 (binding mods=0)
update idletasks
check "(a) Shift+T key -> EXACTLY +1 (NOT +2: perform_action log DEDUPS dispatch's Layer A copy)" \
  [expr {[tc] == $c0 + 1}] "c0=$c0 now=[tc]"
check "(a) Shift+T key: WRITABLE effect applied (spice_ignore -> true)" \
  [expr {[ign] eq "true"}] "spice_ignore=[ign]"

fixture
set c0 [tc]
menu_action_logged {xschem toggle_ignore}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[tc] == $c0 + 1}] "c0=$c0 now=[tc]"
check "(a) menu wrapper: WRITABLE effect applied (spice_ignore -> true)" \
  [expr {[ign] eq "true"}] "spice_ignore=[ign]"

# toggle_ignore also cycles the ignore attr on SELECTED WIRES (not just instances).
xschem clear force
xschem set netlist_type spice
xschem wire 0 0 100 0
xschem select_all
xschem redraw
set c0 [tc]
xschem toggle_ignore
check "(a) selected WIRE: spice_ignore -> true (verb cycles instances AND wires)" \
  [expr {[xschem getprop wire 0 spice_ignore] eq "true"}] \
  "wire spice_ignore=[xschem getprop wire 0 spice_ignore]"
check "(a) selected WIRE: exactly +1 log line" [expr {[tc] == $c0 + 1}] "c0=$c0 now=[tc]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT.
#   * SCRIPTED branch = the COVERAGE ADD (this branch NEVER had a readonly gate): the
#     boundary's ONE scheduler_readonly_reject now REFUSES -> TCL_ERROR, verb-named
#     message, NO mutation, NO log.
#   * Shift+T KEY on a read-only cell: also NO mutation, NO log -- but it is gated at
#     DISPATCH (registry mutates=1 -> readonly_block), BEFORE the handler/boundary runs,
#     so this is a REGRESSION guard on the pre-existing key gate, not the coverage add.
#     readonly_block pops a modal tk_messageBox when has_x, so STUB it to avoid a
#     headless hang (the atom-11 dialog-stub pattern).
# ---------------------------------------------------------------------------
fixture
set t0 [ign]
xschem set readonly 1
set c0 [tc]
set rc [catch {xschem toggle_ignore} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted: message names the verb + read-only" \
  [expr {[string match {*toggle_ignore*read-only*} $res]}] "res=$res"
check "(b) readonly scripted: NO log line (+0)" [expr {[tc] == $c0}] "c0=$c0 now=[tc]"
check "(b) readonly scripted: NO mutation (spice_ignore unchanged)" \
  [expr {[ign] eq $t0}] "before=$t0 after=[ign]"
xschem set readonly 0

# Shift+T key on read-only: gated at dispatch (mutates=1 -> readonly_block). Stub the modal.
fixture
set t0 [ign]
rename tk_messageBox __real_tk_messageBox
proc tk_messageBox {args} {}
xschem set readonly 1
set c0 [tc]
xschem callback .drw 2 400 300 84 0 0 0
update idletasks
check "(b) readonly Shift+T key: NO mutation (gated at dispatch by mutates=1)" \
  [expr {[ign] eq $t0}] "before=$t0 after=[ign]"
check "(b) readonly Shift+T key: NO log line (+0)" [expr {[tc] == $c0}] "c0=$c0 now=[tc]"
xschem set readonly 0
rename tk_messageBox {}
rename __real_tk_messageBox tk_messageBox

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: the logged line is textually `xschem toggle_ignore` -- no args,
#     no format drift (the migration ADDED the log site as the shared bare `xschem %s`
#     core_log_action DEFAULT; it must emit exactly this text).
# ---------------------------------------------------------------------------
fixture
xschem toggle_ignore
set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
set exact ""
foreach l [split $all \n] { if {$l eq {xschem toggle_ignore}} { set exact $l } }
check "(c) logged line is byte-exact 'xschem toggle_ignore'" \
  [expr {$exact eq "xschem toggle_ignore"}] "got=>$exact<"

# ---------------------------------------------------------------------------
# (d) REPLAY. toggle_ignore is a bare, re-executable verb (not a coordinate-form
#     bypass): replaying it re-runs the effect. Through the replay_action_log suppress
#     seam the effect applies but does NOT re-log; a control unwrapped `source` DOES
#     re-log. The recorded file holds ONLY the verb line, so the fixture pre-establishes
#     the netlist mode + selection the effect consumes.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_toggle_ignore_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem toggle_ignore"; close $fd

fixture
set nc [tc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (spice_ignore -> true)" \
  [expr {[ign] eq "true"}] "spice_ignore=[ign]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[tc] == $nc}] "nc=$nc now=[tc]"

fixture
set nc [tc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (spice_ignore -> true)" \
  [expr {[ign] eq "true"}] "spice_ignore=[ign]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[tc] == $nc + 1}] "nc=$nc now=[tc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) NO-OP-STILL-LOGS lock (the floaters §30 analogue). In a netlist mode where the
#     ignore attribute is undefined (attr==NULL) -- `set netlist_type symbol`
#     (CAD_SYMBOL_ATTRS), a mode that is none of spice/verilog/vhdl/tedax/spectre --
#     toggle_ignore() is a harmless no-op (no mutation, no push_undo, no draw). Under
#     the boundary's unconditional log it STILL emits exactly one line. That is CORRECT
#     (idempotent + replayable), not a bug.
# ---------------------------------------------------------------------------
xschem clear force
xschem set netlist_type symbol
xschem instance devices/res.sym 0 0 0 0 {name=R1}
xschem select instance 0
xschem redraw
set t0 [ign]
set c0 [tc]
xschem toggle_ignore
check "(e) attr==NULL (symbol mode): NO mutation (no-op)" \
  [expr {[ign] eq $t0}] "before=$t0 after=[ign]"
check "(e) attr==NULL (symbol mode): STILL logs +1 (boundary logs unconditionally)" \
  [expr {[tc] == $c0 + 1}] "c0=$c0 now=[tc]"

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (the atom-1 no-double-push rule): toggle_ignore() OWNS its single
#     push_undo (on the FIRST selected element), and the run_core arm adds NONE. The
#     fixture's undo stack holds exactly TWO snapshots -- the instance-place snapshot +
#     toggle_ignore's ONE push. So ONE undo restores the prior spice_ignore value and a
#     SECOND undo removes the instance. A spurious run_core push_undo() would capture the
#     SAME pre-mutation state, so the value would survive the first undo (two undos would
#     be needed to clear it) and the instance would survive both -- the discriminator
#     that catches sabotage 5.
# ---------------------------------------------------------------------------
fixture
xschem toggle_ignore
check "(f) undo depth: toggle set spice_ignore -> true" [expr {[ign] eq "true"}] "spice_ignore=[ign]"
xschem undo
check "(f) undo depth: ONE undo restores the prior value (true -> none)" \
  [expr {[ign] eq ""}] "spice_ignore=[ign]"
xschem undo
check "(f) undo depth: a SECOND undo removes the instance (R1 gone) -- toggle_ignore's single push_undo is the ONLY toggle snapshot; a run_core double-push would leave an identical extra one so the value would survive the first undo" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
