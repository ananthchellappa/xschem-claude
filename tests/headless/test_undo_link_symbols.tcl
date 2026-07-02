# test_undo_link_symbols.tcl
#
# Regression for issue 0072 (doc/claude/issues/0072-setprop-instance-hangs-on-churned-buffer.md).
#
# Root cause fixed: disk pop_undo() serialized the autosave "~" backup (via
# set_modify(1) -> write_backup()) BEFORE link_symbols_to_instances() had resolved
# the freshly read-back instances, so every restored instance was written with
# .ptr = -1 (unresolved symbol) -- emitting save_inst() ".ptr = -1" warnings and,
# for embedded symbols, failing to clear the EMBEDDED flag on the backup. The fix
# moves set_modify(1) to AFTER link_symbols_to_instances()/synth_pin_views().
#
# This test spawns a CHILD xschem that drives a disk-undo restore of a populated
# schematic and asserts:
#   1. no "save_inst(): WARNING: inst N .ptr = -1" appears (symbols linked first);
#   2. undo/redo preserve the instance population (data integrity);
#   3. `xschem setprop instance <n> ...` on the churned buffer RETURNS in bounded
#      time (acceptance criterion 1: no infinite loop / hang), whether it succeeds
#      or reports "instance not found".
#
# Run under X with --pipe and --logdir, from the repo root:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_undo_link_symbols.tcl

set ::fail 0
proc check {name ok} {
  if {$ok} { puts "ok   - $name" } else { puts "FAIL - $name" ; set ::fail 1 }
}

# --- locate the running binary + a scratch area -----------------------------
set xschem [info nameofexecutable]
check "found xschem binary" [expr {[file executable $xschem]}]

# Resolve nand2.sch to an ABSOLUTE path so the child works regardless of cwd
# (full_audit.sh runs from tests/headless, not the repo root). Dev tree puts the
# examples under <repo>/xschem_library/...; an installed tree under $XSCHEM_SHAREDIR.
set nand2 ""
set cand {}
catch { lappend cand [file join [file dirname $::XSCHEM_SHAREDIR] xschem_library examples nand2.sch] }
catch { lappend cand [file join $::XSCHEM_SHAREDIR xschem_library examples nand2.sch] }
lappend cand [file normalize [file join [file dirname [info script]] .. .. xschem_library examples nand2.sch]]
lappend cand xschem_library/examples/nand2.sch
foreach c $cand { if {[file exists $c]} { set nand2 [file normalize $c] ; break } }
check "resolved nand2.sch path" [expr {$nand2 ne "" && [file exists $nand2]}]

set tmp [file join [file dirname [xschem get actionlog_filename]] undo_link_child]
file mkdir $tmp
set child [file join $tmp drive.tcl]
set out   [file join $tmp out.txt]

# --- child driver -----------------------------------------------------------
# Disk undo is the default; force it explicitly so the test pins the fixed path
# regardless of any rc override. The churn (delete -> undo) restores instances
# through read_xschem_file(), the code path that used to autosave while unlinked.
set fd [open $child w]
puts $fd "set NAND2 [list $nand2]"
puts $fd {
  xschem undo_type disk
  xschem load $NAND2
  set n0 [xschem get instances]
  xschem select_all ; xschem delete
  set n1 [xschem get instances]
  xschem undo            ;# disk pop_undo(): read-back + link + autosave
  set n2 [xschem get instances]
  xschem redo
  set n3 [xschem get instances]
  xschem undo
  set n4 [xschem get instances]
  puts "COUNTS $n0 $n1 $n2 $n3 $n4"
  # setprop on the restored buffer must RETURN (bounded), success or error:
  set rc [catch {xschem setprop instance 0 selflogtok selflogval} res]
  puts "SETPROP rc=$rc res=$res"
  puts "CHILD_DONE"
  flush stdout
  exit 0
}
close $fd

# --- run the child, capturing stdout+stderr; `timeout` bounds a hang --------
# A regression to the infinite-loop hang trips the timeout -> non-empty errmsg
# and the CHILD_DONE / COUNTS / SETPROP assertions below fail loudly.
set logdir [file join $tmp clog] ; file mkdir $logdir
set errmsg ""
if {[catch {
  exec timeout 45 $xschem --pipe -q --logdir $logdir --script $child >& $out
} e]} { set errmsg $e }

set body ""
if {[file exists $out]} { set fd [open $out r] ; set body [read $fd] ; close $fd }

check "child completed (no hang)"        [expr {[string first CHILD_DONE $body] >= 0}]
check "undo does not warn .ptr = -1"     [expr {[string first {WARNING: inst} $body] < 0}]

# instance population round-trips through undo/redo (COUNTS n0 n1 n2 n3 n4)
set counts_ok 0
if {[regexp {COUNTS (\d+) (\d+) (\d+) (\d+) (\d+)} $body -> n0 n1 n2 n3 n4]} {
  set counts_ok [expr {$n0 > 0 && $n1 == 0 && $n2 == $n0 && $n3 == 0 && $n4 == $n0}]
}
check "undo/redo preserve instance count" $counts_ok
check "setprop on churned buffer returns" [expr {[string first {SETPROP rc=} $body] >= 0}]

if {$::fail} { puts "RESULT: FAIL" } else { puts "RESULT: ALL PASS" }
exit $::fail
