# test_selflog_output.tcl
#
# Verifies the self-log-at-core + command-output plumbing
# (doc/claude/code_analysis/action_log_ciw_coverage_and_virtuoso_parity.md,
#  issues 0070 / 0071, D1 comment-lines + D2 core self-log):
#   - mutating subcommands (cut/delete/undo/redo) self-log even when driven
#     RAW (as a hand-written menu item or toolbar button would);
#   - the menu_action_logged wrapper de-dups (exactly one line, not two);
#   - the -reset / -emitted dedup primitives report core self-logging;
#   - -result / -error write source-able '#=' / '#!' comment lines, one per
#     physical line of output.
#
# Run under X with --pipe and --logdir:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_selflog_output.tcl

set ::fail 0
proc check {name ok} {
  if {$ok} { puts "ok   - $name" } else { puts "FAIL - $name" ; set ::fail 1 }
}
proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
proc count_lines {pat} {
  set n 0
  foreach l [loglines] { if {[string equal $l $pat]} { incr n } }
  return $n
}
proc has_line {pat} { expr {[lsearch -exact [loglines] $pat] >= 0} }

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]

xschem load xschem_library/examples/nand2.sch

# --- 1. RAW self-log (no wrapper): the Edit-menu / toolbar path ---------------
# A bare `xschem <cmd>` is exactly what a hand-written menu -command or a toolbar
# button issues. Previously unlogged; must now self-log at the core.
xschem select_all
xschem delete
check "raw delete self-logs"      [has_line "xschem delete"]
xschem undo
check "raw undo self-logs"        [has_line "xschem undo"]
xschem redo
check "raw redo self-logs"        [has_line "xschem redo"]
xschem select_all
xschem cut
check "raw cut self-logs"         [has_line "xschem cut"]

# --- 2. menu_action_logged dedup: exactly ONE line, not two -------------------
# The wrapper must see the core self-log (via -emitted) and skip its own copy.
xschem undo   ;# restore from the cut so there is something to act on
set before [count_lines "xschem undo"]
menu_action_logged {xschem undo}
set after [count_lines "xschem undo"]
check "menu wrapper logs undo exactly once" [expr {$after - $before == 1}]

# --- 3. -reset / -emitted primitive ------------------------------------------
xschem log_action -reset
xschem redo
check "core self-log sets -emitted"        [expr {[xschem log_action -emitted] == 1}]
xschem log_action -reset
xschem get xorigin                         ;# a query: no self-log
check "non-mutating cmd leaves -emitted 0" [expr {[xschem log_action -emitted] == 0}]

# --- 3b. transform family self-logs at core (0061 Edit/Tools menu, 0062 toolbar) --
# Standalone (non-gesture) flip/rotate/align must self-log from ANY entry point --
# the hand-written Edit-menu `-command {xschem flip}` items and the toolbar were
# previously unlogged. Explicit-coord forms are deterministic and replayable.
xschem select_all
xschem flip 10 20
check "flip self-logs with pivot"        [expr {[count_lines "xschem flip 10 20"] == 1}]
xschem select_all
xschem flipv 10 20
check "flipv self-logs with pivot"       [expr {[count_lines "xschem flipv 10 20"] == 1}]
xschem select_all
xschem rotate 10 20
check "rotate self-logs with pivot"      [expr {[count_lines "xschem rotate 10 20"] == 1}]
xschem select_all
xschem flip_in_place
check "flip_in_place self-logs"          [has_line "xschem flip_in_place"]
xschem select_all
xschem flipv_in_place
check "flipv_in_place self-logs"         [has_line "xschem flipv_in_place"]
xschem select_all
xschem rotate_in_place
check "rotate_in_place self-logs"        [has_line "xschem rotate_in_place"]
xschem select_all
xschem align
check "align self-logs"                  [has_line "xschem align"]
# wrapper dedup for a transform verb: exactly one line, not two.
xschem select_all
set before [count_lines "xschem rotate 10 20"]
menu_action_logged {xschem rotate 10 20}
set after [count_lines "xschem rotate 10 20"]
check "menu wrapper logs rotate exactly once" [expr {$after - $before == 1}]

# --- 3c. wire-surgery self-logs at core (0061 Tools menu, 0062 toolbar) --------
# trim_wires / break_wires were driven raw from the Tools menu and the toolbar
# (`toolbar_add ... "xschem trim_wires"`) -- previously unlogged. break_wires
# carries an optional `remove` arg; the exact canonical form must be preserved.
xschem trim_wires
check "trim_wires self-logs"             [has_line "xschem trim_wires"]
xschem break_wires
check "break_wires (bare) self-logs"     [has_line "xschem break_wires"]
xschem break_wires 1
check "break_wires 1 self-logs with arg" [has_line "xschem break_wires 1"]
# wrapper dedup for a wire-surgery verb: exactly one line, not two.
set before [count_lines "xschem trim_wires"]
menu_action_logged {xschem trim_wires}
set after [count_lines "xschem trim_wires"]
check "menu wrapper logs trim_wires exactly once" [expr {$after - $before == 1}]

# --- 3d. read-only rejects mutating transform/surgery AND logs nothing (0041) -
# flipv / *_in_place / break_wires previously mutated a read-only design (only
# flip and rotate carried scheduler_readonly_reject). With the guard added they
# must reject -- and, crucially for the action log, emit NO line for an edit that
# never happened.
xschem set readonly 1
foreach v {flipv flip_in_place flipv_in_place rotate_in_place break_wires} {
  set before [llength [loglines]]
  catch {xschem $v}
  set after [llength [loglines]]
  check "read-only rejects $v with no log line" [expr {$after == $before}]
}
xschem set readonly 0

# --- 3e. keyboard shortcuts self-log at their inline callback.c handlers (0068) -
# The transform/surgery keys are handled inline in callback.c and never reach the
# scheduler branch, so they carry their own log_action. Drive them via
# `xschem callback` (headless `event generate` is unreliable). rstate strips
# ShiftMask, so an uppercase keysym alone selects the Shift-<K> branch (state 0);
# Alt-<k> = lowercase keysym + Mod1Mask. Assert a NEW matching line appears (count
# delta >= 1) so a line left by an earlier section cannot make this pass falsely.
proc count_pfx {pfx} {
  set n 0 ; foreach l [loglines] { if {[string match "$pfx*" $l]} { incr n } } ; return $n
}
proc keydelta {ks st matcher pat} {
  xschem select_all
  set b [$matcher $pat]
  xschem callback .drw 2 400 300 $ks 0 0 $st ; update idletasks
  return [expr {[$matcher $pat] - $b}]
}
set Ctrl 4 ; set Alt 8   ;# ShiftMask is stripped from rstate, so Shift-<K> uses state 0
check "key Shift-F logs flip"          [expr {[keydelta 70  0     count_pfx   {xschem flip }] >= 1}]
check "key Alt-F logs flip_in_place"   [expr {[keydelta 102 $Alt  count_lines {xschem flip_in_place}] >= 1}]
check "key Shift-R logs rotate"        [expr {[keydelta 82  0     count_pfx   {xschem rotate }] >= 1}]
check "key Alt-R logs rotate_in_place" [expr {[keydelta 114 $Alt  count_lines {xschem rotate_in_place}] >= 1}]
check "key Shift-V logs flipv"         [expr {[keydelta 86  0     count_pfx   {xschem flipv }] >= 1}]
check "key Alt-V logs flipv_in_place"  [expr {[keydelta 118 $Alt  count_lines {xschem flipv_in_place}] >= 1}]
check "key Alt-U logs align"           [expr {[keydelta 117 $Alt  count_lines {xschem align}] >= 1}]
check "key & logs trim_wires"          [expr {[keydelta 38  0     count_lines {xschem trim_wires}] >= 1}]
check "key ! logs break_wires"         [expr {[keydelta 33  0     count_lines {xschem break_wires}] >= 1}]
check "key Ctrl-! logs break_wires 1"  [expr {[keydelta 33  $Ctrl count_lines {xschem break_wires 1}] >= 1}]

# --- 4. -result / -error output comments (source-able) ------------------------
xschem log_action -result "hello world"
check "result -> '#= ' comment"   [has_line "#= hello world"]
xschem log_action -error "boom"
check "error  -> '#! ' comment"   [has_line "#! boom"]
# multi-line output: every physical line must carry its own comment prefix, or a
# continuation line would become live Tcl on replay.
xschem log_action -result "line1\nline2"
check "multiline result prefixes each line" \
  [expr {[has_line "#= line1"] && [has_line "#= line2"]}]

# --- 5. whole log stays source-able: every non-blank line is a comment or a
#         valid `xschem ...` command (no bare output leaked in) -----------------
set srcok 1
foreach l [loglines] {
  if {$l eq {}} continue
  if {[string index $l 0] eq "#"} continue          ;# comment (header/output)
  if {[string match "xschem *" $l]} continue         ;# replayable command
  set srcok 0 ; puts "  non-source-able line: <$l>"
}
check "log file is source-able" $srcok

if {$::fail} { puts "RESULT: FAIL" } else { puts "RESULT: ALL PASS" }
