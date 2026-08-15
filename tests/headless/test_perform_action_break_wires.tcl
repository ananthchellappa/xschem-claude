# perform_action() BOUNDARY -- NINTH per-verb migration, the FIRST NON-transform
# verb (Refactor B, audit §4 / §29): break_wires.
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). Atoms 1-8 migrated trim_wires/align + the transform SEXTET
# (rotate/flip/flipv x pivot + in-place). Atom 9 migrates break_wires -- the
# wire-surgery SIBLING of trim_wires (atom 1), and the FIRST verb that is NOT a
# transform:
#   * its arg is a FLAG (0/1 = split / split-and-remove), NOT a coordinate pivot,
#     so it is SIMPLER than the pivot verbs (atoms 6/7/8) -- one flag to thread,
#     no snprintf of a mouse coord;
#   * it has NO mid-gesture split (break_wires is not a transform, so there are no
#     STARTMOVE/STARTCOPY arms and none of the atom-3..8 gesture wrinkle);
#   * break_wires_at_pins() is called ONLY by this verb's own entry points, so it
#     IS the verb (1:1) -- log at the boundary/core_log_action. The DISTINCT
#     break_wires_at_point() (the Alt-Right `wire_cut` mouse gesture) is a SEPARATE
#     verb+gesture and must NOT emit `xschem break_wires` (case (e) locks it).
#
# Entry points, all funnelled through perform_action:
#   scheduler branch (Edit/Tools menu / toolbar / command palette / scripted
#     `xschem break_wires [1]`)  -> return perform_action("break_wires", argc, argv)
#   '!'    key (callback.c legacy switch, keysym 33 state 0) -> bare  -> perform_action("break_wires", 0, NULL)
#   Ctrl-! key (callback.c legacy switch, keysym 33 state 4) -> remove-> perform_action("break_wires", 3, av) av[2]="1"
# The '!'/Ctrl-! keys KEEP their semaphore>=2 + readonly_block() self-guards (they
# guard themselves first, like the transform keys); the boundary's ONE
# scheduler_readonly_reject is what gates the scheduler/menu/script path.
#
#   (a) exactly ONE log line from EACH entry point (script bare / script `1` /
#       '!' key / Ctrl-! key / menu wrapper)
#   (b) readonly reject: scripted (TCL_ERROR, verb-named message, no mutation, no
#       log) for BOTH forms, and the '!' / Ctrl-! key paths (no mutation, no log)
#   (c) byte-identical: `xschem break_wires` AND `xschem break_wires 1` (the FLAG is
#       the arg-carrying fidelity risk -- the analogue of pivot fidelity)
#   (d) replay: the recorded verb (both forms) re-EXECUTES via the replay seam but
#       does NOT re-log; a control unwrapped `source` DOES re-log
#   (e) the FLAG threads correctly: `break_wires 1` REMOVES (mid segment deleted),
#       `break_wires` SPLITS (mid segment kept), each logs its OWN form and NOT the
#       other; and the SEPARATE `wire_cut` (break_wires_at_point) gesture emits NO
#       `xschem break_wires` line.
#
# Effect oracle (byte-identical before/after atom 9 -- atom 9 only MOVES the log
# site): a resistor at the origin (pins at 0,-30 and 0,30) with a wire 0 -60 0 60
# spanning BOTH pins. `xschem break_wires` splits it at both pins into THREE wires
# (the middle span {0 -30 0 30} stays); `xschem break_wires 1` splits AND removes
# the middle span (entirely inside the resistor, touching both pins) -> TWO wires.
# So wire-count 3-vs-2 AND the presence/absence of {0 -30 0 30} distinguish the two
# forms cleanly. Determined empirically on the pre-migration binary.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_break_wires.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §29

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit
# registers this in logdir_tests so LOG is always set in the real run; the guard
# keeps a bare invocation from erroring. (deferred, NOT "skipped: no X" -- the
# effect is X-independent, but the log site needs an open action log.)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stub: the '!'/Ctrl-! keys KEEP readonly_block(), which posts a
# tk_messageBox modal when has_x -- stub it so the read-only key checks cannot wedge
# the audit under a real DISPLAY. (The grep guard is the real lock on the boundary
# being the sole readonly site for the scheduler/menu/script path.)
catch {rename tk_messageBox _paw_real_mb}
proc tk_messageBox {args} { return ok }

# Exact-line counters: the glob has NO trailing '*', so {xschem break_wires} counts
# ONLY the bare form and {xschem break_wires 1} ONLY the remove form -- the two are
# mutually exclusive and counted independently (the FLAG-fidelity discriminator).
proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc bwc {} { return [logcount {xschem break_wires}] }      ;# bare form count
proc rmc {} { return [logcount {xschem break_wires 1}] }    ;# remove form count

# The span fixture: resistor at origin + wire spanning both pins.
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem wire 0 -60 0 60
  xschem select instance 0
}
proc mid_present {} {
  for {set i 0} {$i < [xschem get wires]} {incr i} {
    if {[xschem wire_coord $i] eq {0 -30 0 30}} { return 1 }
  }
  return 0
}

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH entry point.
#     script  -> scheduler branch -> perform_action
#     '!' key -> callback.c legacy switch (keysym 33, state 0) -> bare
#     Ctrl-! key -> callback.c legacy switch (keysym 33, state 4=ControlMask) -> remove
#     menu    -> menu_action_logged wrapper -> `xschem break_wires` -> branch; the
#               wrapper resets/checks actionlog_cmd_logged so the core's log wins.
# ---------------------------------------------------------------------------
fixture; set c0 [bwc]; xschem break_wires
check "(a) scripted 'xschem break_wires' (bare) -> exactly +1" \
  [expr {[bwc] == $c0 + 1}] "c0=$c0 now=[bwc]"

fixture; set c0 [rmc]; xschem break_wires 1
check "(a) scripted 'xschem break_wires 1' (remove) -> exactly +1" \
  [expr {[rmc] == $c0 + 1}] "c0=$c0 now=[rmc]"

fixture; set c0 [bwc]; xschem callback .drw 2 300 300 33 0 0 0
check "(a) '!' key (keysym 33 state 0) -> exactly +1 bare (no double)" \
  [expr {[bwc] == $c0 + 1}] "c0=$c0 now=[bwc]"

fixture; set c0 [rmc]; xschem callback .drw 2 300 300 33 0 0 4
check "(a) 'Ctrl-!' key (keysym 33 state 4) -> exactly +1 remove (no double)" \
  [expr {[rmc] == $c0 + 1}] "c0=$c0 now=[rmc]"

fixture; set c0 [bwc]; menu_action_logged {xschem break_wires}
check "(a) menu wrapper -> exactly +1 bare (core log wins, wrapper dedups)" \
  [expr {[bwc] == $c0 + 1}] "c0=$c0 now=[bwc]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT from each entry point: no mutation, no log, and TCL_ERROR
#     from the scripted path (the one gate now covers the scheduler/menu/script
#     route -- 0041/0051). The keys reject at their own readonly_block() first.
# ---------------------------------------------------------------------------
fixture
set w0 [xschem get wires]
xschem set readonly 1

set cb0 [bwc]
set rc [catch {xschem break_wires} res]
check "(b) readonly scripted bare: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted bare: message names the verb" \
  [expr {[string match {*break_wires*read-only*} $res]}] "res=$res"
check "(b) readonly scripted bare: NO log line (+0)" [expr {[bwc] == $cb0}] "before=$cb0 now=[bwc]"

set cr0 [rmc]
set rc [catch {xschem break_wires 1} res]
check "(b) readonly scripted remove: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted remove: NO log line (+0)" [expr {[rmc] == $cr0}] "before=$cr0 now=[rmc]"

check "(b) readonly scripted: NO mutation (wire count unchanged)" \
  [expr {[xschem get wires] == $w0}] "before=$w0 after=[xschem get wires]"

set cb0 [bwc]; set w1 [xschem get wires]
xschem callback .drw 2 300 300 33 0 0 0
check "(b) readonly '!' key: NO log line (+0)" [expr {[bwc] == $cb0}] "before=$cb0 now=[bwc]"
check "(b) readonly '!' key: NO mutation" [expr {[xschem get wires] == $w1}] "before=$w1 after=[xschem get wires]"

set cr0 [rmc]; set w2 [xschem get wires]
xschem callback .drw 2 300 300 33 0 0 4
check "(b) readonly 'Ctrl-!' key: NO log line (+0)" [expr {[rmc] == $cr0}] "before=$cr0 now=[rmc]"
check "(b) readonly 'Ctrl-!' key: NO mutation" [expr {[xschem get wires] == $w2}] "before=$w2 after=[xschem get wires]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: the logged lines are textually `xschem break_wires` and
#     `xschem break_wires 1` -- the FLAG must survive the boundary intact (the
#     migration MOVED the log site into core_log_action; it must not change the
#     text). Grab the last exactly-matching physical line for each form.
# ---------------------------------------------------------------------------
proc last_exact {want} {
  set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
  set hit ""
  foreach l [split $all \n] { if {$l eq $want} { set hit $l } }
  return $hit
}
fixture; xschem break_wires
check "(c) logged line is byte-exact 'xschem break_wires' (bare)" \
  [expr {[last_exact {xschem break_wires}] eq "xschem break_wires"}] "got=>[last_exact {xschem break_wires}]<"
fixture; xschem break_wires 1
check "(c) logged line is byte-exact 'xschem break_wires 1' (remove)" \
  [expr {[last_exact {xschem break_wires 1}] eq "xschem break_wires 1"}] "got=>[last_exact {xschem break_wires 1}]<"

# ---------------------------------------------------------------------------
# (d) REPLAY. break_wires is a re-executable verb (not a coordinate-STORE bypass
#     like `wire x1 y1 x2 y2`): replaying it re-runs the effect. Through the
#     replay_action_log suppress seam the effect applies but does NOT re-log (the
#     boundary's log site rides !actionlog_suppress); a control unwrapped `source`
#     DOES re-log. Proven for BOTH forms so the FLAG is shown to thread on replay.
# ---------------------------------------------------------------------------
set recB [file join [file dirname $LOG] paw_bw_bare_[pid].log]
set fd [open $recB w]; puts $fd "xschem break_wires"; close $fd
fixture; set nc [bwc]
replay_action_log $recB
check "(d) replay seam bare: EFFECT applied (wires -> 3, mid kept)" \
  [expr {[xschem get wires] == 3 && [mid_present]}] "wires=[xschem get wires] mid=[mid_present]"
check "(d) replay seam bare: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[bwc] == $nc}] "nc=$nc now=[bwc]"
fixture; set nc [bwc]
uplevel #0 [list source $recB]
check "(d) control (unwrapped source) bare: EFFECT applied (wires -> 3)" \
  [expr {[xschem get wires] == 3 && [mid_present]}] "wires=[xschem get wires] mid=[mid_present]"
check "(d) control (unwrapped source) bare: re-logged (+1)" \
  [expr {[bwc] == $nc + 1}] "nc=$nc now=[bwc]"
file delete $recB

set recR [file join [file dirname $LOG] paw_bw_rm_[pid].log]
set fd [open $recR w]; puts $fd "xschem break_wires 1"; close $fd
fixture; set nc [rmc]
replay_action_log $recR
check "(d) replay seam remove: EFFECT applied (wires -> 2, mid DELETED)" \
  [expr {[xschem get wires] == 2 && ![mid_present]}] "wires=[xschem get wires] mid=[mid_present]"
check "(d) replay seam remove: NOT re-logged" \
  [expr {[rmc] == $nc}] "nc=$nc now=[rmc]"
file delete $recR

# ---------------------------------------------------------------------------
# (e) THE FLAG THREADS: `break_wires 1` REMOVES, `break_wires` SPLITS, and each
#     logs its OWN form and NOT the other. Plus the SEPARATE break_wires_at_point
#     (`wire_cut`) gesture must emit NO `xschem break_wires` line.
# ---------------------------------------------------------------------------
fixture; set b0 [bwc]; set r0 [rmc]; xschem break_wires
check "(e) 'break_wires' SPLITS (wires -> 3, mid segment {0 -30 0 30} kept)" \
  [expr {[xschem get wires] == 3 && [mid_present]}] "wires=[xschem get wires] mid=[mid_present]"
check "(e) 'break_wires' logs the BARE form (+1), NOT the remove form (+0)" \
  [expr {[bwc] == $b0 + 1 && [rmc] == $r0}] "bare d=[expr {[bwc]-$b0}] rm d=[expr {[rmc]-$r0}]"

fixture; set b0 [bwc]; set r0 [rmc]; xschem break_wires 1
check "(e) 'break_wires 1' REMOVES (wires -> 2, mid segment {0 -30 0 30} DELETED)" \
  [expr {[xschem get wires] == 2 && ![mid_present]}] "wires=[xschem get wires] mid=[mid_present]"
check "(e) 'break_wires 1' logs the REMOVE form (+1), NOT the bare form (+0)" \
  [expr {[rmc] == $r0 + 1 && [bwc] == $b0}] "rm d=[expr {[rmc]-$r0}] bare d=[expr {[bwc]-$b0}]"

# the SEPARATE gesture: break_wires_at_point via `xschem wire_cut x y`. It splits a
# wire at a point but is a DIFFERENT verb+gesture -- it must not emit `xschem
# break_wires` (nor the remove form). A plain horizontal wire cut at its midpoint.
# (break_wires_at_point reads the wire spatial hash but, unlike break_wires_at_pins,
# does NOT hash_wires() itself -- a redraw populates the hash the live gesture relies on.)
xschem clear force
xschem wire 0 0 100 0
xschem redraw
set b0 [bwc]; set r0 [rmc]; set w0 [xschem get wires]
xschem wire_cut 40 0
check "(e) wire_cut (break_wires_at_point) actually cut the wire (count +1)" \
  [expr {[xschem get wires] == $w0 + 1}] "before=$w0 after=[xschem get wires]"
check "(e) wire_cut emits NO 'xschem break_wires' line (separate gesture, off the boundary)" \
  [expr {[bwc] == $b0 && [rmc] == $r0}] "bare d=[expr {[bwc]-$b0}] rm d=[expr {[rmc]-$r0}]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
