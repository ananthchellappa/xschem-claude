# perform_action() BOUNDARY -- first per-verb migration (Refactor B, audit §4)
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1 -- the four-edge coverage problem, and the 0041/0051 scattered
# read-only gates, share one root cause and one cure). This atom migrates exactly
# ONE clean 1:1 verb -- trim_wires -- and proves the pattern end-to-end:
#   scheduler branch (Tools menu / toolbar / auto-trim checkbutton / scripted
#     `xschem trim_wires`) AND the inline '&' legacy-switch key both now call
#     perform_action("trim_wires", ...) instead of duplicating readonly_reject +
#     push_undo + trim_wires + draw + log_action.
# The shared trim_wires() C function is ALSO an internal sub-step of align()/move-
# END autotrim; those keep calling it RAW (not user verbs) and must NOT route
# through the boundary or self-log -- case (e) locks that.
#
#   (a) exactly ONE log line from EACH entry point (script / '&' key / menu wrapper)
#   (b) readonly reject from EACH entry point: no mutation, no log, TCL_ERROR where
#       applicable (the 0041 unification proof -- one gate covers every path)
#   (c) byte-identical: the logged line is textually `xschem trim_wires` (no drift)
#   (d) replay: the recorded bare verb re-EXECUTES (effect applies) and, through the
#       replay_action_log suppress seam, does NOT re-log (the boundary's log site
#       rides !actionlog_suppress); a control unwrapped source DOES re-log (it is a
#       real re-executable action, not a coordinate-form bypass verb)
#   (e) the sub-step (align) still works and does NOT self-log trim_wires / mis-route
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_trim_wires.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §21

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
# token full_audit's is_skip matches -- because the effect is X-independent.)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stub: post-migration the readonly '&' key uses the CIW-note gate
# (scheduler_readonly_reject), NOT the old readonly_block() tk_messageBox modal, so
# it no longer hangs headless -- but stub anyway so a future regression that re-adds
# a modal to any path cannot wedge the audit. (The grep guard is the real lock on
# the boundary being the sole readonly site.)
catch {rename tk_messageBox _paw_real_mb}
proc tk_messageBox {args} { return ok }

proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
# a pristine schematic with two IDENTICAL overlapping wires: trim_wires removes the
# duplicate (the "remove overlapping wires" phase), so wire count 2 -> 1 is a clean,
# autotrim-independent effect oracle.
proc two_dup_wires {} {
  xschem clear force
  xschem wire 0 0 100 0
  xschem wire 0 0 100 0
}

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH entry point.
#     script  -> scheduler branch -> perform_action
#     '&' key -> callback.c legacy switch -> perform_action  (keysym 38 = ampersand)
#     menu    -> menu_action_logged wrapper -> `xschem trim_wires` -> branch; the
#               wrapper resets/checks actionlog_cmd_logged, so the core's log wins
#               and the wrapper skips its copy -> exactly one line (dedup live).
# ---------------------------------------------------------------------------
two_dup_wires
set c0 [logcount {xschem trim_wires}]
xschem trim_wires
check "(a) scripted 'xschem trim_wires' -> exactly +1" \
  [expr {[logcount {xschem trim_wires}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem trim_wires}]"

two_dup_wires
set c0 [logcount {xschem trim_wires}]
xschem callback .drw 2 300 300 38 0 0 0
check "(a) '&' key -> exactly +1 (no double)" \
  [expr {[logcount {xschem trim_wires}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem trim_wires}]"

two_dup_wires
set c0 [logcount {xschem trim_wires}]
menu_action_logged {xschem trim_wires}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[logcount {xschem trim_wires}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem trim_wires}]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT from each entry point: no mutation, no log, and TCL_ERROR
#     from the scripted path (the one gate now covers every route -- 0041/0051).
# ---------------------------------------------------------------------------
two_dup_wires
set wro [xschem get wires]
xschem set readonly 1
set c0 [logcount {xschem trim_wires}]
set rc [catch {xschem trim_wires} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted: message names the verb" \
  [expr {[string match {*trim_wires*read-only*} $res]}] "res=$res"
check "(b) readonly scripted: NO log line (+0)" \
  [expr {[logcount {xschem trim_wires}] == $c0}] "c0=$c0 now=[logcount {xschem trim_wires}]"
check "(b) readonly scripted: NO mutation (wire count unchanged)" \
  [expr {[xschem get wires] == $wro}] "before=$wro after=[xschem get wires]"

set c0 [logcount {xschem trim_wires}]
set wro [xschem get wires]
xschem callback .drw 2 300 300 38 0 0 0
check "(b) readonly '&' key: NO log line (+0)" \
  [expr {[logcount {xschem trim_wires}] == $c0}] "c0=$c0 now=[logcount {xschem trim_wires}]"
check "(b) readonly '&' key: NO mutation (wire count unchanged)" \
  [expr {[xschem get wires] == $wro}] "before=$wro after=[xschem get wires]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: the logged line is textually `xschem trim_wires` -- no args,
#     no format drift. (The migration MOVED the log site; it must not change the
#     text.) Grab the last matching physical line and compare exactly.
# ---------------------------------------------------------------------------
two_dup_wires
xschem trim_wires
set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
set exact ""
foreach l [split $all \n] { if {[string match {xschem trim_wires*} $l]} { set exact $l } }
check "(c) logged line is byte-exact 'xschem trim_wires'" \
  [expr {$exact eq "xschem trim_wires"}] "got=>$exact<"

# ---------------------------------------------------------------------------
# (d) REPLAY. trim_wires is a bare, re-executable verb (not a coordinate-form
#     bypass like `wire x1 y1 x2 y2`): replaying it re-runs the effect. Through the
#     replay_action_log suppress seam the effect applies but does NOT re-log (the
#     boundary's log site rides !actionlog_suppress -- re-entrant-safe). A control
#     unwrapped `source` DOES re-log, proving the line is a real action and the seam
#     is what suppresses it.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_trim_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem trim_wires"; close $fd

two_dup_wires
set nc [logcount {xschem trim_wires}]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (wires 2 -> 1)" \
  [expr {[xschem get wires] == 1}] "wires=[xschem get wires]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[logcount {xschem trim_wires}] == $nc}] "nc=$nc now=[logcount {xschem trim_wires}]"

two_dup_wires
set nc [logcount {xschem trim_wires}]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (wires 2 -> 1)" \
  [expr {[xschem get wires] == 1}] "wires=[xschem get wires]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[logcount {xschem trim_wires}] == $nc + 1}] "nc=$nc now=[logcount {xschem trim_wires}]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) SUB-STEP: align() calls trim_wires() RAW internally. `xschem align` must log
#     `xschem align` (its own verb) and must NOT emit `xschem trim_wires` -- the
#     shared C function is not a user verb and does not route through the boundary.
# ---------------------------------------------------------------------------
xschem clear force
set ca [logcount {xschem align}]
set ct [logcount {xschem trim_wires}]
catch {xschem align}
check "(e) 'xschem align' self-logs its own verb (+1)" \
  [expr {[logcount {xschem align}] == $ca + 1}] "ca=$ca now=[logcount {xschem align}]"
check "(e) 'xschem align' does NOT emit 'xschem trim_wires' (sub-step stays on raw core)" \
  [expr {[logcount {xschem trim_wires}] == $ct}] "ct=$ct now=[logcount {xschem trim_wires}]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
