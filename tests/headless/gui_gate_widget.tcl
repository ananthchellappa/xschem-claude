#!/usr/bin/wish
# gui_gate_widget.tcl — persistent GUI-test control panel (issue: GUI testing
# makes the PC unusable with no warning/control).
#
# Runs as a SINGLETON wish process (tests/headless/gui_gate.sh launches it).
# It owns a control directory shared by every test-suite process (the main
# Claude session AND background workflow-crew/worktree runs), so ONE panel
# governs them all:
#
#   $GATE_DIR/req/<pid>      a suite dropped this on start and is BLOCKED until
#                            it is removed (Proceed removes all; the auto-start
#                            countdown and Snooze remove them on expiry).
#   $GATE_DIR/control        RUN | PAUSE | STOP — running suites read this at
#                            each between-test pause point.
#   $GATE_DIR/status/<pid>   "<suite> | <i>/<N> <testname>" live status line.
#   $GATE_DIR/widget.pid     this process's pid (liveness / singleton lock).
#
# The gate ASKS but never blocks forever: a waiting suite arms a 2-minute
# auto-start countdown ($GUI_GATE_AUTOSTART seconds overrides; 0 disables) and
# runs when it expires. The panel is here to warn the user who is AT the desk,
# not to strand a suite behind a dialog nobody is there to click. Snooze pushes
# the deadline out; Pause freezes it — an explicit "I am here, hold off" — and
# is also how you stop the flood once a suite is running.
#
# The shell side FAILS OPEN if this process dies, so a crashed panel never
# blocks testing forever. Design: doc/claude/specs/gui_test_gate.md.

package require Tk

set GATE_DIR [lindex $argv 0]
if {$GATE_DIR eq ""} { set GATE_DIR [file join $env(HOME) .claude gui_test_gate] }
file mkdir [file join $GATE_DIR req]
file mkdir [file join $GATE_DIR status]

# seconds a suite waits before it starts by itself (0 disables auto-start)
set AUTOSTART_SECS 120
if {[info exists env(GUI_GATE_AUTOSTART)]
    && [string is integer -strict $env(GUI_GATE_AUTOSTART)]} {
  set AUTOSTART_SECS $env(GUI_GATE_AUTOSTART)
}

set CONTROL   [file join $GATE_DIR control]
set REQDIR    [file join $GATE_DIR req]
set STATUSDIR [file join $GATE_DIR status]
set SNOOZE    [file join $GATE_DIR snooze_until]
set PIDFILE   [file join $GATE_DIR widget.pid]

set fp [open $PIDFILE w]; puts $fp [pid]; close $fp

# ---- state ---------------------------------------------------------------
proc read_control {} {
  global CONTROL
  if {[catch {set fp [open $CONTROL r]} ]} { return RUN }
  set v [string trim [read $fp]]; close $fp
  if {$v eq ""} { return RUN }
  return $v
}
proc write_control {v} {
  global CONTROL
  set fp [open $CONTROL w]; puts -nonewline $fp $v; close $fp
}
if {![file exists $CONTROL]} { write_control RUN }

# Auto-proceed deadline (epoch seconds; 0 = none armed). ONE deadline serves
# both the default auto-start countdown and a user Snooze -- they differ only in
# length and in what the panel says, so a Snooze simply re-arms it further out.
# The file keeps its `snooze_until` name for compatibility with the spec.
set ::deadline      0
set ::deadline_kind {}      ;# auto | snooze
proc arm_deadline {secs kind} {
  global SNOOZE
  set until [expr {[clock seconds] + $secs}]
  set ::deadline $until
  set ::deadline_kind $kind
  set fp [open $SNOOZE w]; puts -nonewline $fp $until; close $fp
}
proc clear_deadline {} {
  global SNOOZE
  set ::deadline 0
  set ::deadline_kind {}
  catch {file delete $SNOOZE}
}
proc fmt_left {secs} {
  if {$secs < 0} { set secs 0 }
  return "[expr {$secs/60}]m [format %02d [expr {$secs%60}]]s"
}

# ---- widgets -------------------------------------------------------------
wm title . "xschem GUI-test control"
wm geometry . +40+40
wm attributes . -topmost 1
. configure -bg #2b2b2b
option add *background #2b2b2b
option add *foreground #f0f0f0
option add *font {Helvetica 11}

frame .top -bg #3a2b2b -bd 2 -relief ridge
pack .top -fill x -padx 6 -pady 6
label .top.h -text "GUI TEST SUITE" -bg #3a2b2b -fg #ffcc88 \
  -font {Helvetica 13 bold}
pack .top.h -anchor w -padx 8 -pady {6 2}
label .top.msg -bg #3a2b2b -fg #f0f0f0 -justify left -anchor w \
  -wraplength 380 -text "No suite waiting."
pack .top.msg -fill x -padx 8 -pady {0 6}

# pending-suite go-ahead controls
frame .go -bg #2b2b2b
pack .go -fill x -padx 6
button .go.proceed -text "Proceed" -bg #2e7d32 -fg white -width 10 \
  -activebackground #388e3c -command do_proceed
button .go.s5  -text "Snooze 5m"  -width 9 -command {do_snooze 5}
button .go.s15 -text "Snooze 15m" -width 9 -command {do_snooze 15}
button .go.s30 -text "Snooze 30m" -width 9 -command {do_snooze 30}
pack .go.proceed .go.s5 .go.s15 .go.s30 -side left -padx 3 -pady 4

# persistent run controls — one Pause/Resume toggle + Stop
frame .run -bg #2b2b2b
pack .run -fill x -padx 6 -pady {8 2}
button .run.toggle -text "Pause" -bg #f9a825 -fg black -width 10 \
  -command do_toggle_pause
button .run.stop -text "Stop suite" -bg #b71c1c -fg white -width 10 \
  -command do_stop
pack .run.toggle .run.stop -side left -padx 3 -pady 4

label .state -bg #1e1e1e -fg #9ccc65 -anchor w -font {Helvetica 11 bold}
pack .state -fill x -padx 6 -pady {6 2}

label .statushdr -text "Running suites:" -anchor w
pack .statushdr -fill x -padx 8 -pady {4 0}
text .status -height 5 -width 52 -bg #1e1e1e -fg #cfcfcf -bd 0 \
  -font {Courier 10} -state disabled
pack .status -fill both -expand 1 -padx 6 -pady {0 6}

# ---- actions -------------------------------------------------------------
proc pending_reqs {} {
  global REQDIR
  return [lsort [glob -nocomplain -tails -directory $REQDIR *]]
}
proc do_proceed {} {
  global REQDIR
  clear_deadline
  foreach r [pending_reqs] { catch {file delete [file join $REQDIR $r]} }
}
proc do_snooze {mins} {
  arm_deadline [expr {$mins*60}] snooze
}
proc do_toggle_pause {} {
  if {[read_control] eq "PAUSE"} {
    # Resume: drop the frozen deadline so the countdown restarts from full
    # length rather than firing the instant the user un-pauses.
    write_control RUN; clear_deadline
  } else {
    write_control PAUSE
  }
}
proc do_stop   {} {
  global REQDIR
  write_control STOP
  # also release anyone blocked at the go-ahead so they can exit
  foreach r [pending_reqs] { catch {file delete [file join $REQDIR $r]} }
}

# ---- poll loop -----------------------------------------------------------
proc req_label {r} {
  global REQDIR
  set f [file join $REQDIR $r]
  if {[catch {set fp [open $f r]}]} { return "pid $r" }
  set txt [string trim [read $fp]]; close $fp
  if {$txt eq ""} { return "pid $r" }
  return $txt
}
proc refresh {} {
  global STATUSDIR REQDIR AUTOSTART_SECS
  set reqs [pending_reqs]
  set nctrl [read_control]
  set now [clock seconds]

  if {[llength $reqs] == 0} {
    # nothing waiting -> nothing to count down to
    if {$::deadline > 0} { clear_deadline }
  } elseif {$::deadline == 0 && $AUTOSTART_SECS > 0} {
    # a suite is waiting and no deadline is armed -> start the countdown
    arm_deadline $AUTOSTART_SECS auto
  }

  # PAUSE freezes the countdown: the user is demonstrably at the desk, so push
  # the deadline forward by the elapsed tick instead of letting it run out.
  if {$::deadline > 0 && $nctrl eq "PAUSE"} {
    if {[info exists ::last_tick]} { incr ::deadline [expr {$now - $::last_tick}] }
  }
  set ::last_tick $now

  # auto-proceed when the countdown (default or snoozed) expires
  if {$::deadline > 0 && $now >= $::deadline} {
    do_proceed
    set reqs {}
  }

  # top message + go-button state
  if {[llength $reqs] > 0} {
    set names {}
    foreach r $reqs { lappend names [req_label $r] }
    set who "[llength $reqs] suite(s) want to run:\n  [join $names "\n  "]"
    if {$nctrl eq "PAUSE"} {
      .top.msg configure -fg #90caf9 -text \
        "$who\nHELD — countdown frozen while Paused. Resume to restart it, or Proceed to start now."
    } elseif {$::deadline == 0} {
      .top.msg configure -fg #ff8a80 -text \
        "$who\nProceed to allow, or Snooze to keep your PC free."
    } elseif {$::deadline_kind eq "snooze"} {
      .top.msg configure -fg #ffd27f -text \
        "$who\nSNOOZED — starts by itself in [fmt_left [expr {$::deadline - $now}]].\nProceed to start now, Pause to hold."
    } else {
      .top.msg configure -fg #ff8a80 -text \
        "$who\nSTARTING BY ITSELF in [fmt_left [expr {$::deadline - $now}]] — Proceed to start now, Snooze to defer, Pause to hold."
    }
    .go.proceed configure -state normal
    .go.s5  configure -state normal
    .go.s15 configure -state normal
    .go.s30 configure -state normal
    wm attributes . -topmost 1
    catch {raise .}
  } else {
    .top.msg configure -fg #a5d6a7 -text "No suite waiting for go-ahead."
    .go.proceed configure -state disabled
    .go.s5  configure -state disabled
    .go.s15 configure -state disabled
    .go.s30 configure -state disabled
  }

  # global control state line + the toggle button's dual face
  switch -- $nctrl {
    RUN {
      .state configure -fg #9ccc65 -text "State: RUN (tests may run)"
      .run.toggle configure -text "Pause" -bg #f9a825 -fg black \
        -activebackground #fbc02d
    }
    PAUSE {
      .state configure -fg #ffd54f -text "State: PAUSED (suites hold between tests)"
      .run.toggle configure -text "Resume" -bg #1565c0 -fg white \
        -activebackground #1976d2
    }
    STOP {
      .state configure -fg #ef9a9a -text "State: STOP (suites aborting)"
      .run.toggle configure -text "Pause" -bg #f9a825 -fg black \
        -activebackground #fbc02d
    }
    default { .state configure -fg #cfcfcf -text "State: $nctrl" }
  }

  # live running-suite status
  .status configure -state normal
  .status delete 1.0 end
  set any 0
  foreach f [lsort [glob -nocomplain -directory $STATUSDIR *]] {
    if {[catch {set fp [open $f r]}]} continue
    set line [string trim [read $fp]]; close $fp
    if {$line ne ""} { .status insert end "$line\n"; set any 1 }
  }
  if {!$any} { .status insert end "  (none)\n" }
  .status configure -state disabled

  after 300 refresh
}

proc on_close {} {
  global PIDFILE REQDIR
  # closing the panel must never wedge blocked suites: release every
  # go-ahead request and set RUN so paused suites resume, then exit. (Closing
  # is "get out of the way", NOT "abort the suite" — that is the Stop button.)
  clear_deadline
  write_control RUN
  foreach r [pending_reqs] { catch {file delete [file join $REQDIR $r]} }
  catch {file delete $PIDFILE}
  destroy .
  exit 0
}
wm protocol . WM_DELETE_WINDOW on_close

refresh
