# Smoke for --nolog in an INTERACTIVE (has_x) session -- the case the -x
# Phase-0 smoke cannot cover: with a display, logging and the CIW auto-open
# would normally both be on; --nolog must suppress both without breaking
# anything else (issue 0002: test runs must not map short-lived toplevels).
# Runnable from any cwd: the no-litter checks compare against a baseline glob
# taken at script start, so logs left in the cwd by EARLIER sessions (e.g. the
# repo root after interactive use) don't false-fail them.
#   <repo>/src/xschem --pipe -q --nolog \
#       --script <repo>/tests/headless/test_nolog.tcl
update idletasks
focus -force .drw
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  if {!$ok} {incr ::fails}
}
set ::fails 0

set ::log_baseline [lsort [glob -nocomplain Xschem.log*]]
proc no_new_logs {} {
  expr {[lsort [glob -nocomplain Xschem.log*]] eq $::log_baseline}
}

# 1) the option is mirrored to Tcl and the CIW did NOT auto-open
check "cli_opt_nolog mirrored to Tcl" \
  [expr {[info exists cli_opt_nolog] && $cli_opt_nolog == 1}]
check "CIW not auto-opened"          [expr {![winfo exists .ciw]}]

# 2) no action log: no filename, no file in the launch cwd
check "actionlog_filename empty"     [expr {[xschem get actionlog_filename] eq {}}]
check "no new Xschem.log* in cwd"    [no_new_logs]

# 3) logging off must not break dispatch or the log_action entry points:
#    a Tcl-backed bound key (K -> xschem unhilight_all) still runs cleanly,
#    and an explicit log_action is a safe no-op
check "Tcl-backed key dispatch still works" \
  [expr {![catch {xschem callback .drw 2 400 300 75 0 0 0} err]}]
check "xschem log_action is a safe no-op" \
  [expr {![catch {xschem log_action {xschem zoom_full}} err]}]
check "still no new log after that"   [no_new_logs]

# 4) manual ciw_create still works as a plain command console (typed commands
#    run and echo in the pane; they just are not recorded anywhere)
ciw_create
update idletasks
check "manual ciw_create still builds the CIW" [winfo exists .ciw]
.ciw.c.e insert end { xschem get instances }
ciw_exec
check "typed command runs and echoes" \
  [expr {[string first {> xschem get instances} [.ciw.l.t get 1.0 end]] >= 0}]
check "typed command not recorded (no new file)" \
  [no_new_logs]

# clean RAIL teardown (issue 0002 hardening): destroy the toplevel and let the
# event loop deliver it while the client is still alive, THEN exit
destroy .ciw
update

puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
