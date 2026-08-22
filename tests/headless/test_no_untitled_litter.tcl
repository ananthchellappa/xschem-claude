# Guardian for issue 0601 -- a headless suite must not leave `untitled*.sch` in the
# directory it was launched from.
#
# THE MECHANISM (all file:line verified, 2026-08-22):
#   The startup buffer is named `<pwd_dir>/untitled[-N].sch` (src/save.c:4508-4511,
#   src/actions.c:4639-4652), where pwd_dir is the cwd captured at STARTUP
#   (src/xinit.c:2952) -- a Tcl `cd` does NOT move it (src/xinit.c:174, issue 0323).
#   The FIRST edit to that buffer runs set_modify(1) -> write_backup()
#   (src/actions.c:208 -> src/save.c:4149), which backs up untitled buffers ON PURPOSE
#   (src/save.c:4159-4162, issue 0060) and so drops `untitled~.sch` next to the caller.
#   For a hand run and for tests/headless/full_audit.sh (which pins cwd=$REPO at
#   full_audit.sh:64) that directory is the REPO ROOT; under tests/run_regression.tcl
#   it is tests/. write_backup() returns early when autosave_backup is off
#   (src/save.c:4156), which is the whole of the fix the guarded suites carry.
#
# SCOPE, deliberately a LIST and not "the repo root is clean": a measured sweep of the
# 116 headless suites that touch an untitled buffer and carried no guard (each run in a
# private cwd, 2026-08-22) found 80 of them leaving `untitled~.sch` behind. The class is
# not closed, and a blanket guard is NOT safe -- suites that exercise descend/go_back
# (which restores the parent sheet from `cellName~.sch`, issue 0060) need the backup to
# be written. So this file locks the suites that have been fixed, and grows a row when
# another one is. Asserting "the repo root holds no untitled*.sch" would be red for a
# reason this suite cannot fix, and would fail on whichever suite full_audit ran first.
#
# ROWS
#   N0  the binary and the fixed suites are where this test thinks they are
#   N1  POSITIVE CONTROL: an unguarded edit to the untitled buffer DOES litter the cwd.
#       Without this row every row below could pass because the detector was blind or
#       because the C default changed, and the guardian would be silently vacuous.
#   N2  the two-line guard suppresses it (the fix shape itself, on the same child)
#   N3+ each fixed suite, re-run as a CHILD in its own scratch cwd: it still reports a
#       RESULT banner (so the row is not vacuous) and leaves no untitled*.sch
#   S1  source guard: each fixed suite still contains `set ::autosave_backup 0`
#   Z1  this suite's own launch directory gained no untitled*.sch while it ran
#
# Run under X with --pipe, from the repo root:
#   ./src/xschem --pipe -q --script tests/headless/test_no_untitled_litter.tcl
# Children are spawned with an explicit --logdir so the two action-log suites really
# run instead of self-skipping.

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

set here [file dirname [file normalize [info script]]]
source [file join $here scratch.tcl]
set repo [file normalize [file join $here .. ..]]
set root [test_scratch nolitter]
set xschem [info nameofexecutable]

# The suites this guardian owns. Each carries the `set ::autosave_backup 0` guard.
#   {name run-as-child?}  -- the two --nogui-only suites are source-guarded only
#   (they print "RESULT: SKIP (needs --nogui ...)" under X, so a child run would
#   assert nothing; see test_placement_wire_gate.tcl:58-66).
set guarded {
  test_undo_selection        1
  test_delete_cut_selflog    1
  test_perform_action_align  1
  test_statusmsg_hold_0248   1
  test_instance_update       1
  test_traversal_flag_leak   1
  test_placement_wire_gate   0
  test_shape_draw_gate       0
}

set missing {}
foreach {nm run} $guarded {
  if {![file exists [file join $here $nm.tcl]]} { lappend missing $nm }
}
check "N0 binary + [expr {[llength $guarded]/2}] guarded suites present" \
  [expr {[file executable $xschem] && $missing eq {}}] "(missing: $missing)"

# glob the untitled files of a directory, as a sorted list
proc untitled_in {d} { return [lsort [glob -nocomplain -directory $d untitled*.sch]] }

# Snapshot the launch directory NOW, before any child runs (row Z1).
set ::launch_cwd [pwd]
set ::untitled_before [untitled_in $::launch_cwd]

# Run one --script child with cwd=$d. `cd` is safe for the PARENT: its own buffer path
# was fixed at startup (src/xinit.c:174), so moving the cwd cannot re-point it.
#
# TRAP, measured here: `cd` ALONE DOES NOT ISOLATE THE CHILD. xschem prefers
# $env(PWD) over getcwd() when composing pwd_dir (src/xinit.c:3690-3693, "does not
# dereference symlinks"), and Tcl's `cd` does not touch ::env(PWD) -- which `exec`
# then hands to the child. Without the two lines below the children of this suite
# named their untitled buffers in the PARENT's launch directory (the repo root), row
# N1 read 0 files because the litter had gone somewhere else entirely, and the later
# children's `xschem clear force` -> remove_backup() (src/actions.c:4618 ->
# src/save.c:4175-4182) then silently deleted it again -- issue 0356 in miniature.
proc run_child {d script} {
  global xschem
  set out [file join $d out.txt]
  set log [file join $d log] ; file mkdir $log
  set save [pwd]
  set had [info exists ::env(PWD)]
  if {$had} { set savepwd $::env(PWD) }
  set err {}
  cd $d
  set ::env(PWD) $d
  if {[catch {exec timeout 60 $xschem --pipe -q --logdir $log --script $script >& $out} e]} { set err $e }
  cd $save
  if {$had} { set ::env(PWD) $savepwd } else { unset -nocomplain ::env(PWD) }
  set body ""
  if {[file exists $out]} { set fd [open $out r] ; set body [read $fd] ; close $fd }
  return $body
}

proc result_line {body} {
  foreach l [split $body \n] { if {[string match {RESULT:*} $l]} { return [string trim $l] } }
  return ""
}

# --- N1/N2: the detector and the fix shape, on a two-line child ---------------
foreach {tag guard} {ctl_on 0 ctl_off 1} {
  set d [file join $root $tag] ; file mkdir $d
  set s [file join $d drive.tcl]
  set fd [open $s w]
  if {$guard} { puts $fd "set ::autosave_backup 0" }
  puts $fd {xschem instance res.sym 0 0 0 0 {name=R1 value=1k}}
  puts $fd {puts CHILD_DONE ; flush stdout ; exit 0}
  close $fd
  set body [run_child $d $s]
  set n [llength [untitled_in $d]]
  set done [expr {[string first CHILD_DONE $body] >= 0}]
  if {$guard} {
    check "N2 the guard suppresses it (0 files)" [expr {$done && $n == 0}] \
      "(child_done=$done files=[lsort [glob -nocomplain -tails -directory $d untitled*.sch]])"
  } else {
    check "N1 CONTROL: an unguarded edit DOES litter its cwd" [expr {$done && $n == 1}] \
      "(child_done=$done files=[lsort [glob -nocomplain -tails -directory $d untitled*.sch]])"
  }
}

# --- N3+: each fixed suite, re-run as a child in a private cwd ----------------
set i 3
foreach {nm run} $guarded {
  if {!$run} continue
  set d [file join $root $nm] ; file mkdir $d
  set body [run_child $d [file join $here $nm.tcl]]
  set res [result_line $body]
  set left [lsort [glob -nocomplain -tails -directory $d untitled*.sch]]
  check "N$i $nm ran and left no untitled*.sch" \
    [expr {$res ne "" && $left eq {}}] "(left={$left} child said: $res)"
  incr i
}

# --- S1: the guard is still in the source of every suite this file owns -------
set unguarded {}
foreach {nm run} $guarded {
  set f [file join $here $nm.tcl]
  if {![file exists $f]} { lappend unguarded $nm ; continue }
  set fd [open $f r] ; set src [read $fd] ; close $fd
  if {![regexp {set +::autosave_backup +0} $src]} { lappend unguarded $nm }
}
check "S1 every guarded suite still sets ::autosave_backup 0" [expr {$unguarded eq {}}] \
  "(without the guard: $unguarded)"

# --- Z1: this suite littered nothing where it was launched -------------------
# Compared as a SET against the snapshot taken at the top, so a stray left by an
# earlier suite (80 in the tree still do that, see the header) cannot red this row.
check "Z1 the launch directory gained no untitled*.sch" \
  [expr {[untitled_in $::launch_cwd] eq $::untitled_before}] \
  "(before={$::untitled_before} after={[untitled_in $::launch_cwd]})"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
