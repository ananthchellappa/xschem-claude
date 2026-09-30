# Issue 1620 -- THE SELECTION PRIMITIVES LOGGED NOTHING.
#
# `select_all()` and `unselect_all()` were the only wholly unlogged selection
# primitives in the editor, and selection is the commonest macro PREFIX: "select
# everything, then act". A recorded action log could not express that, so every
# macro that begins with a select-all was unplayable -- measured, before the fix,
# on both paths:
#
#   * scripted   `xschem select_all`   -> selection 0 -> 2, log lines: NONE
#   * interactive Ctrl-A over the canvas -> selection 0 -> 2, log lines: NONE
#
# ⚠ THE EFFECT IS ASSERTED ALONGSIDE EVERY LOG COUNT, ON PURPOSE. Stage R of this
# batch concluded "not logged" for a dozen operations when in truth its fixture
# had silently failed to load and NOTHING WAS SELECTED TO ACT ON. A bare "no new
# log line" is uninterpretable, so each W/K row that counts log lines is paired
# with a row that reads the selection back, and each log-counting child also logs
# a CONTROL line (`xschem copy`, which self-logs unconditionally and needs no
# selection) so "the log is empty" can never be mistaken for "the log is shut".
#
# WHERE THE TWO LOGS LIVE IS NOT THE SAME PLACE, and that asymmetry is the whole
# design of this issue (rows G1-G4 pin it):
#
#   * `select_all()` self-logs AT ITS CORE (src/select.c). It has exactly two
#     callers -- the Ctrl-A arm of the legacy `switch (key)` in callback.c and the
#     `xschem select_all` scheduler branch (which is what Edit > "Select all"
#     invokes) -- and BOTH are a user asking for it. One log site therefore covers
#     the key, the menu and the script, which is the `select_grow_connected_step`
#     arrangement this tree already documents ("Self-log at the CORE, not at the
#     scheduler branch ... All three callers funnel here").
#
#   * `unselect_all()` MUST NOT self-log at its core, and a naive reading of the
#     issue would have done exactly that. It has ~87 C call sites -- among them
#     save_schematic(), the netlister, paste, the font change, both undo backends
#     and abort_operation() -- so a log in the core would append a line to
#     Xschem.log after every save, every netlist and every ESC. Its log lives in
#     the `xschem unselect_all` SCHEDULER BRANCH instead, which is the only
#     deliberate "deselect everything" spelling a user or a script can reach.
#
# NO-OP LINES ARE NOT LOGGED (rows W3, W4). This tree already states the rule
# twice in src/select.c -- "a no-op must not leave a replayable phantom line" --
# so `select_all` on an empty drawing and `unselect_all` with nothing selected
# record nothing. `unselect_all`'s predicate is the same one the core itself uses
# to decide whether to do any work.
#
# THE `dr` ARGUMENT IS PRESERVED IN CANONICAL FORM (row W5): `xschem unselect_all
# 0` logs `xschem unselect_all 0`, bare logs bare. That keeps a replay
# BYTE-IDENTICAL (row R1) instead of converging after one round, and it is the
# `xschem undo` arm's existing normalisation shape.
#
# Bands:
#   G*  where the two log sites are, and where they must NOT be (static scans of
#       src/select.c, src/scheduler.c, and the self-log inventory suite's ratchet)
#   W*  the SCRIPTED path, in children with their own --logdir (T1's hcases loop
#       passes none), each with the effect and a control line
#   Z*  the suppress seam: a replay/composite scope logs neither verb
#   R*  the record -> replay ROUND TRIP, both ways: a raw `source` reproduces the
#       log byte-for-byte, and the `replay_action_log` seam reproduces the
#       SELECTION without re-logging
#   K*  the INTERACTIVE path -- Ctrl-A over the canvas through `xschem callback`
#       (display arm only; the headless arm prints an uppercase SKIPPED:, which
#       summarize_all neither counts nor counts as a skip)
#
# ⚠ Ctrl-A IS AN OVERLOADED CHORD. Over a waveform graph it selects all TRACES
# (issue 1617, `waves_callback()` + `graph_sel_waves_all()`, fenced by the CA*
# band of tests/headless/test_wave_viewer.tcl); only over the schematic canvas
# does it reach `select_all()`. This suite touches neither the graph branch nor
# the legacy arm's dispatch -- the core self-log makes an edit to that arm
# unnecessary -- and K1/K2 drive the canvas with no graph in the fixture.
#
# Spec: doc/claude/specs/action_logging.md §2b (the selection primitives, and where a
#       self-log may live).
#
# Run:
#   headless: tests/headless/run_suites.sh --nogui test_select_log_1620
#   display:  tests/headless/run_suites.sh test_select_log_1620
# Registered in hcases AND dcases in tests/run_regression.tcl.
# Prints "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
  flush stdout
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# Everything this suite probes can raise on the unfixed tree (a missing file, a
# child that never started, a regexp over text that is not there). A raise would
# hit the file-scope catch and abort the run -- issue 1616 lost 340 of its 402
# checks to exactly that -- so every probe returns a LEGIBLE SENTINEL instead.
proc q {script} {
  if {[catch {uplevel 1 $script} r]} { return "RAISED($r)" }
  return $r
}

set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here .. ..]]
set bin  [info nameofexecutable]
source [file join $here scratch.tcl]
set work [test_scratch select_log_1620]

proc srctext {rel} {
  if {[catch {open [file join $::root $rel] r} fd]} { return "" }
  set t [read $fd]; close $fd
  return $t
}
proc rxcount {text re} { if {$text eq {}} { return -1 }; return [regexp -all -- $re $text] }

# The body of a top-level C function: from its opening line to the first line
# that is a bare `}` in column 0. Used to ask "does THIS function log?" without
# quoting a line number, which CLAUDE.md forbids.
proc cbody {text signature} {
  set out {}; set in 0
  foreach l [split $text \n] {
    if {!$in} { if {[string first $signature $l] == 0} { set in 1; append out $l \n }; continue }
    if {$l eq "\}"} { append out $l \n; break }
    append out $l \n
  }
  return $out
}

# =====================================================================
# G* -- WHERE THE TWO LOG SITES ARE, AND WHERE THEY MUST NOT BE
# =====================================================================
set sel   [srctext src/select.c]
set sched [srctext src/scheduler.c]

set selall_body [q {cbody $sel "void select_all(void)"}]
check "G1 select_all()'s CORE self-logs (src/select.c, one site)" \
  [q {rxcount $selall_body {log_action\("xschem select_all"\)}}] 1

# The core must stay SILENT: ~87 C call sites, including save_schematic(), the
# netlister, paste, the font change, both undo backends and abort_operation().
# A log here would append a line after every save and every ESC.
set unsel_body [q {cbody $sel "void unselect_all(int dr)"}]
check_true "G2 fixture: the unselect_all() body was located (non-empty)" \
  [expr {[string length $unsel_body] > 200}]
check "G2 unselect_all()'s CORE logs NOTHING (~87 machinery call sites)" \
  [q {rxcount $unsel_body {log_action}}] 0

# S3 of test_selflog_grep_guard: a verb logged in a core must not ALSO log in its
# scheduler branch, or the menu and the script double-log.
check "G3 scheduler.c has NO log_action for select_all (the core owns it)" \
  [q {rxcount $sched {log_action\("xschem select_all}}] 0
# The other entry path, and the one a reader is most likely to "fix": the Ctrl-A
# arm of the legacy switch. A log_action there double-logs the key while every
# scripted row stays green, so without this row the only thing that catches it is
# K2 -- a DISPLAY-arm row. Scan callback.c headless too.
check "G3 callback.c has NO log_action for select_all (the Ctrl-A arm must not double)" \
  [q {rxcount [srctext src/callback.c] {log_action\w*\([^;]*"xschem select_all}}] 0
# ...and the mirror image: unselect_all's ONLY log site is that branch, in both
# arg forms (bare, and the canonical `%d` form that keeps a replay byte-identical).
check "G4 scheduler.c logs unselect_all in BOTH arg forms (bare + canonical %d)" \
  [q {rxcount $sched {log_action\("xschem unselect_all}}] 2

# The self-log inventory suite carries the tree's ratchet: "adding a new C
# self-log means (a) adding its S1 manifest row and (b) adding the verb to the S2
# conflict set". Assert both verbs reached it, so this fix cannot drift out of the
# one place that scans for double-logs.
set guard [srctext tests/headless/test_selflog_grep_guard.tcl]
check "G5 the self-log inventory names select_all (S1 manifest)" \
  [q {rxcount $guard {log_action\\\("xschem select_all}}] 1
check "G5 ...and unselect_all (S1 manifest)" \
  [q {rxcount $guard {log_action\\\("xschem unselect_all}}] 1
check_true "G5 ...and both are in its S2 CVERBS conflict set" \
  [expr {[regexp {\n  select_all unselect_all\n} $guard]}]

# =====================================================================
# child plumbing -- a log can only be observed in a child with --logdir
# =====================================================================
set childn 0
# Run $inner in a fresh xschem with its own action log. `gui` 0 => --nogui (and
# DISPLAY removed, so a headless child can never land on the user's screen);
# 1 => keep the inherited display, for the K band. Returns the log body, or a
# legible sentinel. The child is bounded by its own `exec`; the suite's watchdog
# (scratch.tcl) bounds the suite.
proc run_child {inner {gui 0} {map {}}} {
  global bin work childn
  set d [file join $work c[incr childn]]
  file mkdir $d
  set sf [file join $d inner.tcl]
  set fd [open $sf w]; puts $fd [string map $map $inner]; close $fd
  if {$gui} {
    catch {exec $bin --pipe -q --logdir $d --script $sf 2>@1} out
  } else {
    catch {exec env -u DISPLAY $bin --nogui --pipe -q --logdir $d --script $sf 2>@1} out
  }
  set lf [file join $d Xschem.log]
  if {![file exists $lf]} { return "NO-LOG(child said: $out)" }
  set rf [open $lf r]; set body [read $rf]; close $rf
  return $body
}
proc countlines {body pat} {
  set n 0
  foreach l [split $body \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
# The REPLAYABLE lines of a log: no comments, no blanks. `# MARK1620 ...` marks
# are deliberately comments so they stay out of this list and out of a replay.
proc actionlines {body} {
  set out {}
  foreach l [split $body \n] {
    set t [string trim $l]
    if {$t eq {} || [string index $t 0] eq "#"} continue
    lappend out $t
  }
  return $out
}
# Two wires is the whole fixture: no library file is loaded, so no tracked file
# can be touched (batch decision D9), and `xschem wire <coords>` is the silent
# replay form, so the log contains only what the band under test puts there.
set FIXTURE {xschem wire 0 0 100 0
xschem wire 0 20 100 20}

# =====================================================================
# W* -- THE SCRIPTED PATH (the one the recon measured as silent)
# =====================================================================
set w1 [run_child "$FIXTURE
xschem select_all
xschem copy
xschem log_action -noecho \"# MARK1620 lastsel=\[xschem get lastsel\]\"
exit
"]
check "W1a EFFECT: scripted select_all selected the two fixture wires" \
  [countlines $w1 {# MARK1620 lastsel=2}] 1
check "W1b the log records exactly one `xschem select_all`" \
  [countlines $w1 {xschem select_all}] 1
check "W1c CONTROL: the log was open and writable (`xschem copy` reached it)" \
  [countlines $w1 {xschem copy}] 1

set w2 [run_child "$FIXTURE
xschem select_all
xschem unselect_all
xschem log_action -noecho \"# MARK1620 lastsel=\[xschem get lastsel\]\"
exit
"]
check "W2a EFFECT: scripted unselect_all cleared the selection" \
  [countlines $w2 {# MARK1620 lastsel=0}] 1
check "W2b the log records exactly one `xschem unselect_all`" \
  [countlines $w2 {xschem unselect_all}] 1

# No phantom lines. Both rows would also pass on the unfixed tree (where NOTHING
# logs); they exist to catch the over-logging half, and the sabotage that drops
# the no-op gate reddens exactly these two.
set w3 [run_child "$FIXTURE
xschem unselect_all
xschem copy
xschem log_action -noecho \"# MARK1620 lastsel=\[xschem get lastsel\]\"
exit
"]
check "W3 unselect_all with NOTHING selected logs no phantom line" \
  [countlines $w3 {xschem unselect_all*}] 0
check "W3 ...and the control line still proves the log was open" \
  [countlines $w3 {xschem copy}] 1

set w4 [run_child {xschem select_all
xschem copy
xschem log_action -noecho "# MARK1620 lastsel=[xschem get lastsel]"
exit
}]
check "W4 EFFECT: select_all on an EMPTY drawing selects nothing" \
  [countlines $w4 {# MARK1620 lastsel=0}] 1
check "W4 ...and logs no phantom line" \
  [countlines $w4 {xschem select_all*}] 0
check "W4 ...and the control line still proves the log was open" \
  [countlines $w4 {xschem copy}] 1

# The `dr` argument survives in canonical form, so a replay is byte-identical
# rather than converging after one round (the `xschem undo` arm's shape).
set w5 [run_child "$FIXTURE
xschem select_all
xschem unselect_all 0
xschem log_action -noecho \"# MARK1620 lastsel=\[xschem get lastsel\]\"
exit
"]
check "W5 `xschem unselect_all 0` records its argument verbatim" \
  [countlines $w5 {xschem unselect_all 0}] 1
check "W5 ...and not the bare form (which would drift on replay)" \
  [countlines $w5 {xschem unselect_all}] 0
check "W5 EFFECT: the 0 form still cleared the selection" \
  [countlines $w5 {# MARK1620 lastsel=0}] 1

# The gate is "was anything selected", NOT "did the selection change": a user who
# presses select-all twice performed two actions and the log says so.
set w6 [run_child "$FIXTURE
xschem select_all
xschem select_all
xschem log_action -noecho \"# MARK1620 lastsel=\[xschem get lastsel\]\"
exit
"]
check "W6 two select_alls are two lines (the gate is emptiness, not change)" \
  [countlines $w6 {xschem select_all}] 2

# =====================================================================
# Z* -- THE SUPPRESS SEAM (what a replay and a composite ride on)
# =====================================================================
# ⚠ The MARK is written AFTER the pop, on purpose: `log_action -noecho` is itself
# suppressed inside the scope, so a mark written in-scope reads as "the select_all
# did not happen" on every tree, fixed or not. Measured while writing this row.
set z1 [run_child "$FIXTURE
xschem log_action -suppress push
xschem select_all
set ls \[xschem get lastsel\]
xschem log_action -suppress pop
xschem log_action -noecho \"# MARK1620 in-scope lastsel=\$ls\"
xschem unselect_all
exit
"]
check "Z1a EFFECT: the suppressed select_all really ran (selection is 2)" \
  [countlines $z1 {# MARK1620 in-scope lastsel=2}] 1
check "Z1b inside a suppress scope select_all logs nothing" \
  [countlines $z1 {xschem select_all}] 0
check "Z1c after the pop the very next unselect_all logs again" \
  [countlines $z1 {xschem unselect_all}] 1

# =====================================================================
# R* -- THE RECORD -> REPLAY ROUND TRIP
# =====================================================================
# Record three deliberate selection actions. `xschem wire` is silent in its
# scripted form, so the log's replayable content is exactly these three lines --
# which is also why the replay children rebuild the fixture themselves: a log
# recorded mid-session does not carry the schematic it was recorded against.
set rec [run_child "$FIXTURE
xschem select_all
xschem unselect_all
xschem select_all
exit
"]
set recdir [file join $work c$childn]
set reclog [file join $recdir Xschem.log]
check "R0 the recording holds exactly the three selection lines" \
  [q {actionlines $rec}] {{xschem select_all} {xschem unselect_all} {xschem select_all}}

# R1: LOG-IDEMPOTENCE. A raw `source` of the log in a FRESH process, from the same
# starting state, must produce a byte-identical set of replayable lines. This is
# the property the 29 test_perform_action_* suites assert per verb, and it is what
# makes a recorded log usable as a macro.
set rep [run_child "$FIXTURE
source {@LOG@}
exit
" 0 [list @LOG@ $reclog]]
check "R1 a raw replay reproduces the log's replayable lines byte-for-byte" \
  [q {actionlines $rep}] [q {actionlines $rec}]

# R2: the shipped seam. `replay_action_log` wraps the source in the suppress
# depth counter, so the SELECTION is re-established while NOTHING is re-logged.
set rep2 [run_child "$FIXTURE
replay_action_log {@LOG@}
xschem copy
xschem log_action -noecho \"# MARK1620 after-seam lastsel=\[xschem get lastsel\]\"
exit
" 0 [list @LOG@ $reclog]]
check "R2 EFFECT: the seam replay re-established the selection (2 wires)" \
  [countlines $rep2 {# MARK1620 after-seam lastsel=2}] 1
check "R2 ...and re-logged neither verb" \
  [list [countlines $rep2 {xschem select_all}] [countlines $rep2 {xschem unselect_all}]] {0 0}
check "R2 CONTROL: logging still worked after the seam popped" \
  [countlines $rep2 {xschem copy}] 1

# =====================================================================
# K* -- THE INTERACTIVE PATH (Ctrl-A over the schematic canvas)
# =====================================================================
# A scripted verb is NOT the interactive path and badly under-reports it (Stage R
# measured 9 of 20 verbs logging when scripted, and real commands when the same
# operations were driven as key events). So the key is driven for real, through
# the same `xschem callback .drw 2 <x> <y> <keysym> 0 0 <state>` seam the Tk
# binding uses: keysym 97 = 'a', state 4 = ControlMask. Needs a mapped canvas.
if {[llength [info commands winfo]] && ![catch {winfo exists .}]} {
  set k1 [run_child "$FIXTURE
xschem callback .drw 2 100 100 97 0 0 4
update idletasks
xschem copy
xschem log_action -noecho \"# MARK1620 ctrla lastsel=\[xschem get lastsel\]\"
exit
" 1]
  check "K1 EFFECT: Ctrl-A over the canvas selected the two fixture wires" \
    [countlines $k1 {# MARK1620 ctrla lastsel=2}] 1
  check "K2 the interactive chord records exactly one `xschem select_all`" \
    [countlines $k1 {xschem select_all}] 1
  check "K2 CONTROL: the child's log was open (`xschem copy` reached it)" \
    [countlines $k1 {xschem copy}] 1
  # The legacy switch arm is not wrapped by dispatch_input_action (canvas Ctrl-A
  # is not in the binding table -- only the over_graph row is, issue 1617), so
  # there is no wrapper copy to dedup. K2's count == 1 is what proves it.
} else {
  puts "SKIPPED: K1/K2 interactive Ctrl-A rows (no Tk on this arm; W1 measures the scripted path, G1 the shared core)"
  flush stdout
}

# --- verdict ---
# OVERALL first, RESULT last: banner_rule.tcl's `banner_complete` is the only
# reader run_regression.tcl consults and accepts ONLY `OVERALL: ok`, while
# summarize_all publishes a case's LAST `RESULT:` line into the verdict.
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "OVERALL: notok"
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail != 0}]
