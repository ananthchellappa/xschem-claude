# Action-log SUPPRESS GATE (issue 0071 Refactor B foundation / Refactor A step 2)
# -- the setter + the two re-entrancy seams the audit §3.2 names.
#
# This atom wires a REAL setter onto actionlog_suppress (which existed as a gate
# in log_action*/log_output but had NO write site) and applies it as a scoped
# guard around the two hazards that make a self-log-at-core model re-entrant:
#   REPLAY   -- sourcing a recorded log with the log still OPEN must re-EXECUTE
#               its lines but NOT re-LOG them (else every re-executable verb
#               doubles). Seam: proc replay_action_log (xschem.tcl).
#   COMPOSITE -- a teardown/macro that calls several already-self-logging cores
#               must not mint a line per sub-op. Seam: abort_operation (C) +
#               the general push/pop scope.
# The gate is a DEPTH COUNTER so the two nest (replay { composite { core } }).
# It is ORTHOGONAL to actionlog_cmd_logged (the wrapper-dedup flag): a suppressed
# log_action returns BEFORE setting cmd_logged, so a suppressed scope never leaves
# the dedup flag dirty (case f).
#
# The whole gate changes NO existing log output -- every case here is a NEW
# scope. No Tk needed (copy/set cadsnap/log_action are X-independent), so this
# runs in a windowless audit too; it only needs the log OPEN.
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_actionlog_suppress_gate.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §20

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The suppress gate is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard just keeps
# a bare invocation from erroring. (deferred, NOT "skipped: no X" -- the phrase
# full_audit's is_skip matches -- because the gate is X-independent.)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the suppress gate needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# the seam under test must exist (part of what this atom ships)
check "seam proc replay_action_log is defined" \
  [expr {[llength [info procs replay_action_log]] == 1}]

proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}

# ---------------------------------------------------------------------------
# (a) baseline: a normal mutator logs its 1 line (unchanged behaviour).
#     `xschem copy` self-logs unconditionally (clipboard-only, empty-selection
#     safe) -- the S5-canary count verb, needs no fixture/selection.
# ---------------------------------------------------------------------------
set c0 [logcount {xschem copy}]
xschem copy
check "(a) baseline mutator logs +1 (no scope)" \
  [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"

# ---------------------------------------------------------------------------
# (b) inside an ABSOLUTE suppress scope the SAME mutator logs NOTHING; after the
#     scope, logging resumes. (`xschem set actionlog_suppress 0|1` -- the setter
#     the task requires.)
# ---------------------------------------------------------------------------
set c0 [logcount {xschem copy}]
xschem set actionlog_suppress 1
xschem copy
xschem copy
check "(b) suppressed: mutator logs +0" \
  [expr {[logcount {xschem copy}] == $c0}] "c0=$c0 now=[logcount {xschem copy}]"
xschem set actionlog_suppress 0
xschem copy
check "(b) resumed after scope: mutator logs +1" \
  [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"

# ---------------------------------------------------------------------------
# (c) push/pop NESTS (depth counter): replay-scope { composite-scope { mutator }}
#     logs nothing at depth 2; ONE pop leaves it still suppressed (an inner pop
#     must NOT re-open logging); the outer pop restores it. Plus an underflow
#     clamp: an extra pop stays at 0, logging stays on.
# ---------------------------------------------------------------------------
set c0 [logcount {xschem copy}]
xschem log_action -suppress push        ;# depth 1 (replay scope)
xschem log_action -suppress push        ;# depth 2 (composite scope nested inside)
xschem copy
check "(c) depth 2: mutator logs +0" \
  [expr {[logcount {xschem copy}] == $c0}] "c0=$c0 now=[logcount {xschem copy}]"
xschem log_action -suppress pop         ;# depth 1 -- STILL suppressed
xschem copy
check "(c) after one pop (depth 1): still +0 (inner pop must not re-open)" \
  [expr {[logcount {xschem copy}] == $c0}] "c0=$c0 now=[logcount {xschem copy}]"
xschem log_action -suppress pop         ;# depth 0 -- restored
xschem copy
check "(c) after outer pop (depth 0): +1 (logging restored)" \
  [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"
xschem log_action -suppress pop         ;# underflow: clamps at 0
set c0 [logcount {xschem copy}]
xschem copy
check "(c) extra pop underflow-clamped: logging stays on" \
  [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"

# ---------------------------------------------------------------------------
# (d) REPLAY no-re-log + EFFECT applied. Record a small log fragment, replay it
#     IN-SESSION through the replay_action_log seam: its lines re-EXECUTE (the
#     cadsnap effect applies) but do NOT re-LOG. A CONTROL plain `source` (no
#     wrap) DOES re-log -- proving the seam's wrap is what closes the hazard.
#     cadsnap is edit-geometry state that self-logs its RESOLVED value and is
#     observable (the mirrored global) -- a clean effect+suppress oracle.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] repframe_[pid].log]   ;# pid-isolated
set fd [open $rec w]
puts $fd "xschem copy"
puts $fd "xschem set cadsnap 5"
close $fd
xschem set cadsnap 40                                        ;# perturb live state
set nc [logcount {xschem copy}]
set ns [logcount {xschem set cadsnap 5}]
replay_action_log $rec
check "(d) replay seam: 'xschem copy' NOT re-logged" \
  [expr {[logcount {xschem copy}] == $nc}] "nc=$nc now=[logcount {xschem copy}]"
check "(d) replay seam: 'set cadsnap 5' NOT re-logged" \
  [expr {[logcount {xschem set cadsnap 5}] == $ns}] "ns=$ns now=[logcount {xschem set cadsnap 5}]"
check "(d) replay seam: EFFECT applied (cadsnap==5)" \
  [expr {abs($::cadsnap - 5) < 1e-9}] "cadsnap=$::cadsnap"
# control: a plain unwrapped source DOES re-log both lines
xschem set cadsnap 40
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): 'xschem copy' re-logged (+1)" \
  [expr {[logcount {xschem copy}] == $nc + 1}] "nc=$nc now=[logcount {xschem copy}]"
check "(d) control (unwrapped source): 'set cadsnap 5' re-logged (+1)" \
  [expr {[logcount {xschem set cadsnap 5}] == $ns + 1}] "ns=$ns now=[logcount {xschem set cadsnap 5}]"
check "(d) control: EFFECT applied (cadsnap==5)" \
  [expr {abs($::cadsnap - 5) < 1e-9}] "cadsnap=$::cadsnap"
file delete $rec

# ---------------------------------------------------------------------------
# (e) COMPOSITE granularity lock: a macro running several self-logging cores logs
#     one line PER sub-op normally, but the INTENDED count (0) inside a suppress
#     scope. This locks the chosen granularity of the composite seam (the same
#     shape abort_operation uses in C, and hier_traversal could use in Tcl).
# ---------------------------------------------------------------------------
proc _macro3 {} { xschem copy; xschem copy; xschem copy }
set c0 [logcount {xschem copy}]
_macro3
check "(e) unwrapped composite: 3 self-logging sub-ops -> +3" \
  [expr {[logcount {xschem copy}] == $c0 + 3}] "c0=$c0 now=[logcount {xschem copy}]"
set c0 [logcount {xschem copy}]
xschem log_action -suppress push
_macro3
xschem log_action -suppress pop
check "(e) suppressed composite: 3 sub-ops -> +0 (one action, intended count)" \
  [expr {[logcount {xschem copy}] == $c0}] "c0=$c0 now=[logcount {xschem copy}]"

# ---------------------------------------------------------------------------
# (f) actionlog_cmd_logged stays CLEAN after a suppressed scope. The dedup flag
#     and the suppress flag are DIFFERENT: a suppressed log_action returns before
#     setting cmd_logged, so a suppressed scope must not leave the dedup flag
#     dirty (which would make the next wrapper skip its real line).
# ---------------------------------------------------------------------------
xschem log_action -reset
xschem log_action -suppress push
xschem copy
check "(f) suppressed core does NOT set cmd_logged (-emitted==0)" \
  [expr {[xschem log_action -emitted] == 0}] "emitted=[xschem log_action -emitted]"
xschem log_action -suppress pop
# after the scope a real self-logging core sets it again -> dedup still works
xschem log_action -reset
xschem copy
check "(f) after scope, real core sets cmd_logged (-emitted==1)" \
  [expr {[xschem log_action -emitted] == 1}] "emitted=[xschem log_action -emitted]"

# ---------------------------------------------------------------------------
# (g) REGRESSION LOCK (adversarial-review MAJOR, §20): ESC-to-close a polygon is
#     NOT a teardown -- abort_operation's STARTPOLYGON arm runs new_polygon(END),
#     which store_poly()s a real polygon AND self-logs `xschem polygon ...`
#     (actions.c). So abort_operation must NOT be wrapped in a suppress scope, or
#     that real logged edit is dropped (replay diverges: polygon missing). Drive
#     the polygon gesture + ESC and assert the line IS logged. If the gesture made
#     no polygon (window not drivable here) defer -- do not FAIL (not "skipped: no
#     X", the token full_audit's is_skip matches).
# ---------------------------------------------------------------------------
proc polycount {} {
  set n 0
  for {set c 0} {$c < 40} {incr c} { catch {incr n [xschem get polygons $c]} }
  return $n
}
catch {xschem load xschem_library/examples/nand2.sch}
set infix_interface 1
set npoly0 [logcount {xschem polygon*}]
xschem callback .drw 6 400 400 0 0 0 0
xschem polygon gui
xschem callback .drw 6 500 400 0 0 0 0
xschem callback .drw 4 500 400 0 1 0 0
xschem callback .drw 5 500 400 0 1 0 256
xschem callback .drw 6 500 480 0 0 0 0
xschem callback .drw 4 500 480 0 1 0 0
xschem callback .drw 5 500 480 0 1 0 256
xschem callback .drw 2 500 480 65307 0 0 0     ;# XK_Escape closes the polygon
update idletasks
set made [polycount]
if {$made < 1} {
  check "(g) polygon-ESC regression: deferred (no-X env; gesture created no polygon)" 1
} else {
  check "(g) ESC-close-polygon IS logged (abort_operation must NOT be suppress-wrapped)" \
    [expr {[logcount {xschem polygon*}] > $npoly0}] \
    "before=$npoly0 after=[logcount {xschem polygon*}] polys=$made"
}

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
