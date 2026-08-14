# Action-log Layer B: right-click context-menu picks are recorded in the log.
# context_menu_action (callback.c) reads an int retval from the `context_menu`
# Tcl proc, switches it to a C action, and then logs the equivalent command
# (replayable), a '#' marker (dialog / object-ref gap), or nothing (gesture
# starts, deferred to Layer C). We test at that retval seam: stub `context_menu`
# to return a chosen pick, fire a Button3 release (the trigger), inspect the log.
# Run under X with --pipe and --logdir:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_context_menu_log.tcl
update idletasks
focus -force .drw
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  if {!$ok} {incr ::fails}
}
set ::fails 0

proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
# choose context-menu pick N, then fire a Button3 release (ButtonRelease=5,
# state=Button3Mask=1024) at 100,100 -- the path that calls context_menu_action
proc ctxpick {n} {
  proc context_menu {} "return $n"
  xschem callback .drw 5 100 100 0 3 0 1024
  update idletasks
}

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]

# 1) a replayable command: copy (retval 15) -> "xschem copy". copy on an empty
#    selection is a safe no-op, but the PICK is still recorded as its command.
set n0 [llength [loglines]]
ctxpick 15
check "copy pick logs 'xschem copy'" \
  [expr {[lsearch -exact [loglines] {xschem copy}] >= $n0}]

# 2) a non-replayable marker: descend (retval 12). `xschem descend` does NOT
#    match the case (descend_schematic(0,1,1,1) vs the subcommand's 0,0), and
#    descend needs an object reference (issue 0005) -> '#' marker, not a command.
set n0 [llength [loglines]]
ctxpick 12
set lines [loglines]
check "descend pick logs a '# ' marker" \
  [expr {[lsearch -glob $lines {# context-menu: descend*}] >= $n0}]
check "descend pick logs NO xschem command" \
  [expr {[lsearch -glob $lines {xschem descend*}] < 0}]

# 3) a gesture-start: place wire (retval 2) -> NOTHING logged in Layer B (its
#    replayable form is the gesture END, Layer C). Clean up the wire mode after.
set n0 [llength [loglines]]
ctxpick 2
check "gesture-start (place wire) logs no line" [expr {[llength [loglines]] == $n0}]
xschem abort_operation
update idletasks

# 4) dynamic command: load recent (retval 9) records the RESOLVED filename, not
#    the $tctx::recentfile lookup. Point it at the real fixture so the load
#    succeeds and is replayable.
set fix [file normalize xschem_library/examples/nand2.sch]
set tctx::recentfile [list $fix]
set n0 [llength [loglines]]
ctxpick 9
check "load-recent logs resolved 'xschem load {<file>}'" \
  [expr {[lsearch -exact [loglines] "xschem load {$fix}"] >= $n0}]

# 5) the whole file stays source-able (commands + '#' comments only)
check "log file is source-able" \
  [expr {![catch {uplevel #0 [list source [xschem get actionlog_filename]]} err]}]

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
