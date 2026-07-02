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
