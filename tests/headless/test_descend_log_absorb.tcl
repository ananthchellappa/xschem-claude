# Regression: outcome-level action logging for descend + the select_at holding area.
# See doc/claude/specs/action_log_absorb.md.
#
# A gesture `select_at <x> <y>` + `descend` must be RECORDED as one stable, coordinate-
# free line `xschem descend -inst <name>` (the select_at absorbed), and that line must
# REPLAY to the same end state. We verify by running CHILD xschem processes with
# --logdir and inspecting the resulting Xschem.log.
#
# Pure headless. Run from the repo ROOT (or tests/, paths are normalized):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_log_absorb.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# fatal: report a FAIL line and bail to the sentinel (missing "OVERALL: ok" also fails)
proc bail {msg} { puts "FATAL: $msg : FAIL"; puts "OVERALL: notok"; exit 1 }

set bin  [info nameofexecutable]
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here .. ..]]
set flop [file join $root xschem_library examples flop.sch]
if {![file exists $flop]} { bail "fixture missing: $flop" }

# --- discover the two descendable dlatch instances + their pick points (in THIS proc,
#     under the outer xschem) so the child's logged coords are predictable. ---
if {[catch {xschem load $flop} e]} { bail "outer load flop: $e" }
proc center {inst} {
  lassign [xschem instance_bbox $inst] _tag x1 y1 x2 y2
  return [list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]]
}
lassign [center x5] cx5 cy5
lassign [center x1] cx1 cy1
# the action log records EFFECTIVE (grid-snapped) coordinates (snap_to_grid,
# actions.c), so snap the bbox-midpoint expectations the same way; the child
# runs the same default cadsnap as this outer instance.
proc gridsnap {v} { expr {round($v / $::cadsnap) * $::cadsnap} }
set cx5 [gridsnap $cx5]; set cy5 [gridsnap $cy5]
set cx1 [gridsnap $cx1]; set cy1 [gridsnap $cy1]

set workroot [file join [pwd] descend_log_absorb_work.[pid]]
file mkdir $workroot
set childn 0

# Run an inner script in a fresh CHILD xschem with a private --logdir. Returns a dict
# with -out (merged stdout/stderr) and -log (list of non-comment action-log lines).
proc run_child {inner} {
  global bin workroot childn flop
  set d [file join $workroot c[incr childn]]
  file mkdir $d
  set sf [file join $d inner.tcl]
  set fd [open $sf w]; puts $fd $inner; close $fd
  set out ""
  catch {exec $bin --nogui --pipe -q --logdir $d --script $sf 2>@1} out
  set cmds {}
  set lf [file join $d Xschem.log]
  if {[file exists $lf]} {
    set rf [open $lf r]; set body [read $rf]; close $rf
    foreach ln [split $body "\n"] {
      set ln [string trim $ln]
      if {$ln eq "" || [string match "#*" $ln]} continue
      lappend cmds $ln
    }
  }
  return [dict create -out $out -log $cmds]
}
# pull "KEY=value" markers a child printed
proc marker {out key} {
  foreach ln [split $out "\n"] {
    if {[regexp "^$key=(.*)\$" [string trim $ln] -> v]} { return $v }
  }
  return "<none>"
}

set L "xschem load {$flop}"

# ------------------------------------------------------------------ C1: ABSORB
# select_at (stash) + descend (absorb) -> exactly one line, the outcome form.
set r [run_child "$L
lassign \[xschem instance_bbox x5\] _ a b c d
set cx \[expr {(\$a+\$c)/2.0}\]; set cy \[expr {(\$b+\$d)/2.0}\]
xschem select_at \$cx \$cy
puts \"RET=\[xschem descend\]\"
puts \"SCH=\[file tail \[xschem get schname\]\]\""]
check "C1 absorb: single logged line"        [llength [dict get $r -log]] 1
check "C1 absorb: line is the outcome form"  [lindex [dict get $r -log] 0] "xschem descend -inst x5"
check "C1 absorb: no select_at survived"     [lsearch -glob [dict get $r -log] "*select_at*"] -1
check "C1 absorb: descend actually happened" [marker [dict get $r -out] RET] 1
check "C1 absorb: now in child schematic"    [marker [dict get $r -out] SCH] dlatch.sch

# ------------------------------------------------------------------ C2: EMIT (name-addressed)
# scripted `descend -inst x5` self-logs the same canonical line, no prior select.
set r [run_child "$L
puts \"RET=\[xschem descend -inst x5\]\"
puts \"CS=\[xschem get currsch\]\"
puts \"SCH=\[file tail \[xschem get schname\]\]\""]
check "C2 emit: name-addressed descend ret"  [marker [dict get $r -out] RET] 1
check "C2 emit: currsch advanced"            [marker [dict get $r -out] CS] 1
check "C2 emit: entered child cell"          [marker [dict get $r -out] SCH] dlatch.sch
check "C2 emit: one logged line"             [llength [dict get $r -log]] 1
check "C2 emit: logged canonical form"       [lindex [dict get $r -log] 0] "xschem descend -inst x5"

# ------------------------------------------------------------------ C3: REPLAY reproduces outcome
# Sourcing the recorded line on a fresh load lands in the same place.
set r [run_child "$L
# replay exactly what C1/C2 recorded:
eval {xschem descend -inst x5}
puts \"CS=\[xschem get currsch\]\"
puts \"SCH=\[file tail \[xschem get schname\]\]\""]
check "C3 replay: currsch 0->1"              [marker [dict get $r -out] CS] 1
check "C3 replay: same child cell"           [marker [dict get $r -out] SCH] dlatch.sch

# ------------------------------------------------------------------ C4: NOT FOUND errors cleanly
set r [run_child "$L
puts \"CATCH=\[catch {xschem descend -inst zzz_nope} err\]\"
puts \"CS=\[xschem get currsch\]\""]
check "C4 notfound: raises Tcl error"        [marker [dict get $r -out] CATCH] 1
check "C4 notfound: did not descend"         [marker [dict get $r -out] CS] 0
check "C4 notfound: logged nothing"          [llength [dict get $r -log]] 0

# ------------------------------------------------------------------ C5: FLUSH + ABSORB
# select_at A (x5), then select_at B (x1) flushes A, then descend absorbs B.
# Expect: [ "xschem select_at <x5 coords>", "xschem descend -inst x1" ].
set r [run_child "$L
lassign \[xschem instance_bbox x5\] _ a b c d
xschem select_at \[expr {(\$a+\$c)/2.0}\] \[expr {(\$b+\$d)/2.0}\]
lassign \[xschem instance_bbox x1\] _ a b c d
xschem select_at \[expr {(\$a+\$c)/2.0}\] \[expr {(\$b+\$d)/2.0}\]
xschem descend"]
set log5 [dict get $r -log]
check "C5 flush: two logged lines"           [llength $log5] 2
check "C5 flush: first is a select_at"       [string match "xschem select_at *" [lindex $log5 0]] 1
# the flushed select_at is x5's (the one that got overwritten), NOT x1's
set ok5 0
if {[regexp {^xschem select_at (\S+) (\S+)} [lindex $log5 0] -> lx ly]} {
  if {abs($lx-$cx5) < 0.001 && abs($ly-$cy5) < 0.001} { set ok5 1 }
}
check "C5 flush: flushed coords are x5's"    $ok5 1
check "C5 flush: second absorbed into descend x1" [lindex $log5 1] "xschem descend -inst x1"

# ------------------------------------------------------------------ C6: miss then descend logs nothing
# A select_at that hits empty space does not stash; a descend with no ELEMENT selected
# returns 0 and logs nothing.
set r [run_child "$L
puts \"HIT=\[xschem select_at 100000 100000\]\"
puts \"RET=\[xschem descend\]\"
puts \"CS=\[xschem get currsch\]\""]
check "C6 miss: select_at missed (empty hit)" [marker [dict get $r -out] HIT] ""
check "C6 miss: descend refused"              [marker [dict get $r -out] RET] 0
check "C6 miss: still at top level"           [marker [dict get $r -out] CS] 0
check "C6 miss: logged nothing"               [llength [dict get $r -log]] 0

# ---------------------------------------------------------------------------
file delete -force $workroot
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
