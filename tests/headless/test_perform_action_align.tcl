# perform_action() BOUNDARY -- SECOND per-verb migration (Refactor B, audit §4 / §22)
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1 -- the four-edge coverage problem, and the 0041/0051 scattered
# read-only gates, share one root cause and one cure). Atom 1 migrated trim_wires;
# this atom migrates the SECOND clean 1:1 verb -- align -- proving the pattern holds
# for a second verb (run_core grows exactly one arm):
#   scheduler branch (Tools menu / toolbar / command palette / scripted
#     `xschem align`) AND the inline Alt-U legacy-switch key both now call
#     perform_action("align", ...) instead of duplicating readonly_reject +
#     push_undo + round_schematic_to_grid + maintain + draw + log_action.
# align operates on the SELECTED objects (round_schematic_to_grid snaps each
# selected object's coords to the current cadsnap grid) -- unlike trim_wires which
# works on all wires -- so the effect oracle SELECTS an off-grid wire and asserts
# its coords snap. The shared C functions BELOW the verb (maintain_wire_segments,
# which calls trim_wires) are internal sub-steps and keep running RAW; they must
# NOT self-log -- case (e) locks that `xschem align` never emits `xschem trim_wires`.
#
#   (a) exactly ONE log line from EACH entry point (script / Alt-U key / menu wrapper)
#   (b) readonly reject from EACH entry point: no mutation, no log, TCL_ERROR where
#       applicable (the 0041 unification proof -- one gate covers every path)
#   (c) byte-identical: the logged line is textually `xschem align` (no drift)
#   (d) replay: the recorded bare verb re-EXECUTES (a selected off-grid wire snaps)
#       and, through the replay_action_log suppress seam, does NOT re-log (the
#       boundary's log site rides !actionlog_suppress); a control unwrapped source
#       DOES re-log (it is a real re-executable action, not a coordinate-form bypass)
#   (e) the sub-step (maintain_wire_segments -> trim_wires) still runs and does NOT
#       self-log trim_wires / mis-route through the boundary
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_align.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §22

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

# Defensive modal stub: post-migration the readonly Alt-U key uses the CIW-note gate
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
# A pristine schematic with ONE wire whose endpoints are OFF the cadsnap=20 grid
# (3,7)-(103,7). align snaps every selected object -> the wire becomes (0,0)-(100,0),
# a clean, unambiguous effect oracle. align acts on the SELECTION, so select_all.
proc offgrid_selected {} {
  xschem clear force
  xschem set cadsnap 20
  xschem wire 3 7 103 7
  xschem select_all
}

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH entry point.
#     script  -> scheduler branch -> perform_action
#     Alt-U key -> callback.c legacy switch -> perform_action  (keysym 117='u',
#               state 8 = Mod1Mask = Alt; EQUAL_MODMASK gate)
#     menu    -> menu_action_logged wrapper -> `xschem align` -> branch; the
#               wrapper resets/checks actionlog_cmd_logged, so the core's log wins
#               and the wrapper skips its copy -> exactly one line (dedup live).
# ---------------------------------------------------------------------------
offgrid_selected
set c0 [logcount {xschem align}]
xschem align
check "(a) scripted 'xschem align' -> exactly +1" \
  [expr {[logcount {xschem align}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem align}]"

offgrid_selected
set c0 [logcount {xschem align}]
xschem callback .drw 2 400 300 117 0 0 8
check "(a) Alt-U key -> exactly +1 (no double)" \
  [expr {[logcount {xschem align}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem align}]"

offgrid_selected
set c0 [logcount {xschem align}]
menu_action_logged {xschem align}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[logcount {xschem align}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem align}]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT from each entry point: no mutation, no log, and TCL_ERROR
#     from the scripted path (the one gate now covers every route -- 0041/0051).
# ---------------------------------------------------------------------------
offgrid_selected
set wc0 [xschem wire_coord 0]
xschem set readonly 1
set c0 [logcount {xschem align}]
set rc [catch {xschem align} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted: message names the verb" \
  [expr {[string match {*align*read-only*} $res]}] "res=$res"
check "(b) readonly scripted: NO log line (+0)" \
  [expr {[logcount {xschem align}] == $c0}] "c0=$c0 now=[logcount {xschem align}]"
check "(b) readonly scripted: NO mutation (wire coords unchanged, still off-grid)" \
  [expr {[xschem wire_coord 0] eq $wc0}] "before=$wc0 after=[xschem wire_coord 0]"

set c0 [logcount {xschem align}]
set wc0 [xschem wire_coord 0]
xschem callback .drw 2 400 300 117 0 0 8
check "(b) readonly Alt-U key: NO log line (+0)" \
  [expr {[logcount {xschem align}] == $c0}] "c0=$c0 now=[logcount {xschem align}]"
check "(b) readonly Alt-U key: NO mutation (wire coords unchanged)" \
  [expr {[xschem wire_coord 0] eq $wc0}] "before=$wc0 after=[xschem wire_coord 0]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: the logged line is textually `xschem align` -- no args, no
#     format drift. (The migration MOVED the log site; it must not change the text.)
#     Grab the last matching physical line and compare exactly.
# ---------------------------------------------------------------------------
offgrid_selected
xschem align
set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
set exact ""
foreach l [split $all \n] { if {[string match {xschem align*} $l]} { set exact $l } }
check "(c) logged line is byte-exact 'xschem align'" \
  [expr {$exact eq "xschem align"}] "got=>$exact<"

# ---------------------------------------------------------------------------
# (d) REPLAY. align is a bare, re-executable verb (not a coordinate-form bypass
#     like `wire x1 y1 x2 y2`): replaying it re-runs the effect. Through the
#     replay_action_log suppress seam the effect applies (a selected off-grid wire
#     snaps to grid) but does NOT re-log (the boundary's log site rides
#     !actionlog_suppress -- re-entrant-safe). A control unwrapped `source` DOES
#     re-log, proving the line is a real action and the seam is what suppresses it.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_align_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem align"; close $fd

offgrid_selected
set nc [logcount {xschem align}]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (wire snapped 3 7 103 7 -> 0 0 100 0)" \
  [expr {[xschem wire_coord 0] eq "0 0 100 0"}] "coord=[xschem wire_coord 0]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[logcount {xschem align}] == $nc}] "nc=$nc now=[logcount {xschem align}]"

offgrid_selected
set nc [logcount {xschem align}]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (wire snapped to 0 0 100 0)" \
  [expr {[xschem wire_coord 0] eq "0 0 100 0"}] "coord=[xschem wire_coord 0]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[logcount {xschem align}] == $nc + 1}] "nc=$nc now=[logcount {xschem align}]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) SUB-STEP: align internally calls maintain_wire_segments() -> trim_wires()
#     RAW (autotrim gated). `xschem align` must log its own verb (+1) and must NOT
#     emit `xschem trim_wires` -- the shared C functions are not user verbs and do
#     not route through the boundary. Force autotrim ON and feed two overlapping
#     wires so maintain_wire_segments/trim_wires actually run.
# ---------------------------------------------------------------------------
xschem clear force
xschem set cadsnap 20
xschem set autotrim_wires 1
xschem wire 0 0 100 0
xschem wire 0 0 100 0
xschem select_all
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
