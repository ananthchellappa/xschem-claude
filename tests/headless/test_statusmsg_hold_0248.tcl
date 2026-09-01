# Issue 0248 -- a gate / prompt status line must survive the coordinate readout.
#
# `statusmsg(str, 1)` is the only writer of `.statusbar.1`, but three readout sites (callback.c
# motion + the press/release twins) rewrite that field with `mouse = x y - selected: N w= h=`
# whenever the pointer has moved 8 pixels, guarded by `if(xctx->ui_state)` -- and ui_state is
# non-zero for exactly the reason a gate message exists. Placement verbs had a second clobberer:
# place_symbol() SELECTS the preview it just placed and select.c answers with its own
# "n=%4d x = ... w = ... h = ..." info line. Every "<verb>: in-progress wire abandoned" /
# "<verb>: pending placement abandoned" line shipped since 2026-08-06 was therefore invisible.
#
# The fix is a hold enforced inside statusmsg() itself (xctx->statusmsg_hold_ms), released by the
# next ButtonPress or by its own 5 s deadline. THIS FILE IS THE ONLY TEST THAT SEES REAL PIXELS:
# the status bar is a Tk label, so under --nogui there is nothing to read and the flag-level
# checks live in section H of tests/headless/test_placement_wire_gate.tcl instead.
#
# Needs a real DISPLAY. Run from the repo ROOT, either way:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_statusmsg_hold_0248.tcl
#   ./src/xschem --script tests/headless/test_statusmsg_hold_0248.tcl   ;# then read the log file
# The first form is what tests/headless/full_audit.sh uses and prints the result on stdout. The
# second (plain GUI) prints nothing to the terminal, so every line is ALSO written to
# tests/headless/results/test_statusmsg_hold_0248.log (override with XSCHEM_TEST_LOG).
# NOT registered in tests/run_regression.tcl: that harness runs everything with --nogui and
# demands an "OVERALL: ok" sentinel, which an X-gated self-skip cannot honestly print.
#
# Everything runs at SOURCE time, driven by explicit `update` calls, because with --pipe xschem
# blocks reading stdin and `after` timers never fire.
#
# Measured with this script on 2026-08-08, `xschem add_sch_pin -place` + `xschem wire gui`:
#   pre-fix  after 25 motion events: {mouse = 150 100 - selected: 0 w=250 h=200}
#   post-fix after 25 motion events: {Wire: pending placement abandoned}

if {[catch {winfo exists .}] || ![info exists tk_version]} {
  puts "RESULT: SKIP (needs Tk/X; this test reads a Tk label)"; flush stdout; exit 0
}
if {![winfo exists [xschem get top_path].statusbar.1]} {
  puts "RESULT: SKIP (no status bar widget; needs a real GUI window)"; flush stdout; exit 0
}

# Issue 0601: this suite edits the startup UNTITLED buffer, and set_modify(1) ->
# write_backup() (src/actions.c:208 -> src/save.c:4149) then writes `untitled~.sch` into
# the cwd captured at STARTUP (pwd_dir, src/xinit.c:2952) -- the repo root for a hand run,
# tests/ under run_regression.tcl. Nothing here descends or recovers, so suppress it:
# write_backup() returns early when autosave_backup is off (src/save.c:4156). See
# tests/headless/test_undo_selection.tcl for the full note; guarded by
# tests/headless/test_no_untitled_litter.tcl.
set ::saved_autosave_0601 $::autosave_backup
set ::autosave_backup 0

set fail 0; set npass 0
if {[info exists ::env(XSCHEM_TEST_LOG)]} { set ::LOGF $::env(XSCHEM_TEST_LOG) } \
else { set ::LOGF [file join [file dirname [info script]] results test_statusmsg_hold_0248.log] }
file mkdir [file dirname $::LOGF]
set ::LOG [open $::LOGF w]
proc say {t} { catch {puts $t ; flush stdout} ; puts $::LOG $t ; flush $::LOG }
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { say "ok:   $name"; incr npass } \
  else { say "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc sb {} { return [[xschem get top_path].statusbar.1 cget -text] }
# real pointer motion, through the same Tk binding the mouse uses -> callback() -> the readout
proc wiggle {n x0 y0} {
  set drw "[xschem get top_path].drw"
  for {set i 0} {$i < $n} {incr i} {
    event generate $drw <Motion> -x [expr {$x0+$i*23}] -y [expr {$y0+$i*17}]
    update
  }
}
proc fresh {} {
  xschem abort_operation ; xschem abort_operation
  xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
}

set drw "[xschem get top_path].drw"
update ; update idletasks          ;# map the window before <Motion> can reach its binding
set ::infix_interface 1

# 1. phase 1: a shape draw abandons a live wire draw, and says so where it can be read
fresh ; xschem wire gui ; xschem rect gui
check "1 gate message reaches the bar"   [sb] "Rectangle: in-progress wire abandoned"
wiggle 25 100 100
check "1 survives 25 motion events"      [sb] "Rectangle: in-progress wire abandoned"

# 2. phase 2: a placement, whose own selection info line lands one call after the gate message
fresh ; xschem wire gui ; xschem net_label 0
check "2 gate message beats select info" [sb] "Net label: in-progress wire abandoned"
wiggle 25 200 150
check "2 survives 25 motion events"      [sb] "Net label: in-progress wire abandoned"

# 3. a click releases the hold: the live w=/h= size feedback must come straight back
#    (0248 landmine 1 -- that readout is the one place a user reads exact deltas)
event generate $drw <ButtonPress-1> -x 320 -y 300 ; update
event generate $drw <ButtonRelease-1> -x 320 -y 300 ; update
wiggle 8 400 320
check "3 a click releases the hold"      [string match "mouse = *" [sb]] 1

# 4. the reverse door (issue 0243 F2) had the same defect and takes the same fix
fresh
set ::pin_new_name GG ; set ::pin_new_dir in
xschem add_sch_pin -place ; xschem wire gui
check "4 reverse-door message lands"     [sb] "Wire: pending placement abandoned"
wiggle 25 260 260
check "4 survives 25 motion events"      [sb] "Wire: pending placement abandoned"
xschem abort_operation ; xschem abort_operation

set ::autosave_backup $::saved_autosave_0601   ;# issue 0601
if {$fail == 0} { say "RESULT: ALL PASS ($npass checks)"; say "OVERALL: ok"; set rc 0 } \
else { say "RESULT: $fail FAILED ($npass passed)"; say "OVERALL: notok"; set rc 1 }
close $::LOG
exit $rc
