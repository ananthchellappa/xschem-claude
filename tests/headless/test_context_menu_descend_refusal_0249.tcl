# A REFUSED context-menu descend must not be recorded as if it had run. Issue 0249.
#
# context_menu_action() (src/callback.c) ends with
#     if(logcmd && !actionlog_cmd_logged) log_action("%s", logcmd);
# -- gated on "the core did not already log it", NOT on whether the verb did
# anything. descend_symbol() self-logs only on its success path, so a REFUSED
# retval-13 pick falls through to the classification table and writes a bare
# "xschem descend_symbol" for a descend that never happened. Replaying that log
# descends where the recording did not: the log is not a record of what the user
# did, it is a record of what they clicked.
#
# This is the direct generalization of the ratified "an aborted gesture must not
# lie about the modify flag" (issues 0244 / 0267 / 0270) to the action log, and
# it is the one place in the 0249/0251/0254/0256 batch where a silent refusal
# actively CORRUPTS a record rather than merely withholding information.
#
# X-ONLY. context_menu_action is static and reachable only from the Button3
# release handler, so this cannot be driven from --nogui. xvfb is not the user's
# display, so the GUI gate is correctly bypassed here:
#   GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_context_menu_descend_refusal_0249.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).
#
# Deliberately a FILE OF ITS OWN rather than a section of
# tests/headless/test_context_menu_log.tcl: that suite HANGS partway under xvfb
# today (see the 0367 stub), and its "descend pick logs NO xschem command" check
# scans the whole log rather than the window it just opened, so any earlier
# descend line -- including a legitimate one -- trips it. Merging the two is a
# separate repair, not this one.
#
# Works on a /tmp copy so the ~ backups never pollute the committed fixtures.

update idletasks
focus -force .drw
update idletasks

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/ctxmenu_descend_refusal_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc ask_save {{cmd {}}} { return no }

proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
# how many lines appended since index $n0 match $pat
proc count_since {n0 pat} {
  set c 0
  foreach l [lrange [loglines] $n0 end] { if {[string match $pat $l]} { incr c } }
  return $c
}
# choose context-menu pick N, then fire a Button3 release (ButtonRelease=5,
# state=Button3Mask=1024) at 100,100 -- the path that calls context_menu_action
proc ctxpick {n} {
  proc context_menu {} "return $n"
  xschem callback .drw 5 100 100 0 3 0 1024
  update idletasks
}

check "action log open" [expr {[xschem get actionlog_filename] ne {}}] 1

xschem load $work/descend_parent.sch
xschem instance $work/descend_child.sym 500 500 0 0 {name=x2}
update idletasks

# --- the refused pick: two instances selected, so descend_symbol declines -----
xschem unselect_all
xschem select instance x1 fast
xschem select instance x2 fast
check "setup: two instances selected (descend_symbol must decline)" \
      [llength [xschem selected_set]] 2
set lvl0 [xschem get currsch]
set n0 [llength [loglines]]
ctxpick 13
check "setup: the refused pick did not move the hierarchy" \
      "[xschem get currsch] [file tail [xschem get schname]]" "$lvl0 descend_parent.sch"
check "a REFUSED context-menu 'descend symbol' appends NO descend line" \
      [count_since $n0 {xschem descend_symbol*}] 0

# --- the accepted pick: exactly one line, from the core's own self-log -------
xschem unselect_all
xschem select instance x1 fast
set n0 [llength [loglines]]
ctxpick 13
check "setup: the accepted pick descended into the symbol view" \
      [file tail [xschem get schname]] descend_child.sym
check "an ACCEPTED context-menu 'descend symbol' appends exactly one descend line" \
      [count_since $n0 {xschem descend_symbol*}] 1
xschem go_back
update idletasks

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts ""
if {$fail} { puts "OVERALL: $fail FAILED, $npass passed" } \
else       { puts "OVERALL: ok ($npass checks)" }
flush stdout
exit [expr {$fail != 0}]
