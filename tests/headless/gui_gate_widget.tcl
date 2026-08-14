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
#   $GATE_DIR/allow_until    epoch: while in the future, suites start WITHOUT
#                            asking (the "Allow 30m/2h" approval window).
#   $GATE_DIR/grant_count    how many suites have used the current window.
#
# THE ONE RULE: the only thing that holds tests up indefinitely is a user
# PAUSE. Everything else self-releases.
#   * a waiting suite arms a 2-minute auto-start countdown
#     ($GUI_GATE_AUTOSTART seconds overrides; 0 disables) and runs when it
#     expires — the panel warns the user who is AT the desk, it must never
#     strand a suite behind a dialog nobody is there to click;
#   * Snooze pushes that deadline out, it does not remove it;
#   * PAUSE freezes it — an explicit "I am here, hold off" — and is also how you
#     stop the flood once a suite is already running;
#   * STOP is per-suite and SELF-CLEARS once the suites it aborted have drained.
#     It used to persist in the control file, so one Stop press silently made
#     every future suite exit 3 forever — a hold nobody asked for.
#
# ATTENTION: the panel is useless if it opens on a virtual desktop the user is
# not looking at. `raise`/-topmost only act within a desktop, and there is no
# portable way to ask a window manager which desktop a window is on, so the
# shell side RELAUNCHES this process when a suite wants go-ahead (see
# _gate_attention in gui_gate.sh) — a fresh window maps on the CURRENT desktop.
# This process does the in-desktop half: deiconify, raise, force focus, bell and
# a brief flash, on startup and whenever a NEW request appears.
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
set ALLOW     [file join $GATE_DIR allow_until]
set GRANTN    [file join $GATE_DIR grant_count]

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
  # "<until> <kind>" — the kind is what lets a relaunched panel say SNOOZED
  # rather than silently relabelling a 30-minute snooze as a 2-minute autostart.
  # Old single-field files still parse: lindex 0 is the epoch either way.
  set fp [open $SNOOZE w]; puts -nonewline $fp "$until $kind"; close $fp
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

# ADOPT a deadline that outlived the process. The shell kills and relaunches
# this panel routinely (_gate_attention, and the mid-suite revive), and the
# deadline lived only in memory — so `snooze_until` was written and never read
# back, and every relaunch silently downgraded a user's "Snooze 30m" to a fresh
# 2-minute autostart. Only a FUTURE deadline is adopted; a stale one is junk.
if {![catch {set fp [open $SNOOZE r]}]} {
  set v [string trim [read $fp]]; close $fp
  set vt [lindex $v 0]
  if {[string is integer -strict $vt] && $vt > [clock seconds]} {
    set ::deadline $vt
    set ::deadline_kind [expr {[lindex $v 1] eq "auto" ? "auto" : "snooze"}]
  }
}

# ---- approval window -----------------------------------------------------
# "Allow 30m" / "Forever": suites start WITHOUT asking until it expires. The
# gate used to warn before every suite, which turned forty two-second suites
# into forty Proceed presses — or, with nobody at the desk, forty two-minute
# autostart waits to run two minutes of tests. Approve once, walk away.
#
# Deliberately NOT a mode that suppresses control: Pause and Stop are read at
# every pause point regardless, so an approved batch stays fully steerable.
# Returns an epoch, the literal "forever", or 0 for "no grant".
#
# "forever" is a KEYWORD, not merely "something that isn't a number". The file
# is world-writable state that outlives every process here, so anything
# unrecognised in it must keep meaning "no grant" -- test_gui_gate_batch B4
# writes "yes please" and asserts it is ignored, and that must stay true. One
# accepted word, everything else rejected.
proc grant_until {} {
  global ALLOW
  if {[catch {set fp [open $ALLOW r]}]} { return 0 }
  set v [string trim [read $fp]]; close $fp
  if {$v eq "forever"} { return forever }
  if {![string is integer -strict $v]} { return 0 }
  return $v
}
proc grant_forever {} { return [expr {[grant_until] eq "forever"}] }
proc grant_live {} {
  set u [grant_until]
  if {$u eq "forever"} { return 1 }
  return [expr {$u > [clock seconds]}]
}
proc grant_count {} {
  global GRANTN
  if {[catch {set fp [open $GRANTN r]}]} { return 0 }
  set v [string trim [read $fp]]; close $fp
  if {![string is integer -strict $v]} { return 0 }
  return $v
}
proc set_grant {until} {
  global GRANTN
  set_grant_keepcount $until
  set fp [open $GRANTN w]; puts -nonewline $fp 0; close $fp
}
# same, but leaves the "suites run under this grant" counter alone — used when
# PAUSE pushes the window forward, which is not a new grant.
proc set_grant_keepcount {until} {
  global ALLOW
  set fp [open $ALLOW w]; puts -nonewline $fp $until; close $fp
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
button .go.a30 -text "Allow 30m" -bg #1b5e20 -fg white -width 9 \
  -activebackground #2e7d32 -command {do_allow 30}
button .go.a120 -text "Forever" -bg #1b5e20 -fg white -width 9 \
  -activebackground #2e7d32 -command do_allow_forever
button .go.revoke -text "Revoke" -width 8 -command do_revoke
pack .go.proceed .go.a30 .go.a120 .go.revoke -side left -padx 3 -pady 4

frame .snz -bg #2b2b2b
pack .snz -fill x -padx 6
button .snz.s5  -text "Snooze 5m"  -width 9 -command {do_snooze 5}
button .snz.s15 -text "Snooze 15m" -width 9 -command {do_snooze 15}
button .snz.s30 -text "Snooze 30m" -width 9 -command {do_snooze 30}
pack .snz.s5 .snz.s15 .snz.s30 -side left -padx 3 -pady {0 4}

# persistent run controls — one Pause/Resume toggle + Stop, plus the hard brake
frame .run -bg #2b2b2b
pack .run -fill x -padx 6 -pady {8 2}
button .run.toggle -text "Pause" -bg #f9a825 -fg black -width 10 \
  -command do_toggle_pause
button .run.stop -text "Stop suite" -bg #b71c1c -fg white -width 10 \
  -command do_stop
button .run.halt -text "Halt ALL xschem" -bg #4a148c -fg white -width 15 \
  -activebackground #6a1b9a -command do_toggle_halt
button .run.kill -text "Kill" -bg #b71c1c -fg white -width 5 \
  -command do_kill_xschem
pack .run.toggle .run.stop .run.halt .run.kill -side left -padx 3 -pady 4

label .state -bg #1e1e1e -fg #9ccc65 -anchor w -font {Helvetica 11 bold}
pack .state -fill x -padx 6 -pady {6 2}

label .statushdr -text "Running suites:" -anchor w
pack .statushdr -fill x -padx 8 -pady {4 0}
text .status -height 8 -width 56 -bg #1e1e1e -fg #cfcfcf -bd 0 \
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
proc do_allow {mins} {
  # Approving a window also releases whatever is waiting right now — otherwise
  # "Allow 30m" would open the window and still leave this suite sitting there.
  set_grant [expr {[clock seconds] + $mins*60}]
  do_proceed
}
# "Forever" replaced "Allow 2h". Two hours was an arbitrary guess at how long a
# person intends to be away, and guessing short is the expensive direction: the
# window expires mid-batch, the next suite sits waiting for a Proceed nobody is
# there to press, and it burns the 2-minute autostart countdown per suite from
# then on. An open-ended grant cannot expire at the wrong moment. It stays fully
# steerable — Pause and Stop are read at every pause point regardless — and
# Revoke ends it in one press.
proc do_allow_forever {} {
  set_grant forever
  do_proceed
}
proc do_revoke {} {
  global ALLOW
  catch {file delete $ALLOW}
}

# ---- the hard brake ------------------------------------------------------
# Pause/Stop only reach suites that ENROLLED in the gate (they are read at
# gate_pause_point). A bare `for i in 1..12; do xschem --script ...; done` never
# calls the gate at all, so the panel could watch a flood it had no authority
# over. This is the authority: signals, which need no cooperation.
#
# SIGSTOP is a brake, not a graceful pause — a halted run will fail or time out,
# and an X client frozen mid-request can leave the display sluggish until it is
# resumed. That is the correct trade when the alternative is an unusable PC, but
# it is why this is a separate, differently-coloured button and why Resume is
# always one click away.
proc brake_name {} {
  # Overridable so the self-test can aim the brake at a throwaway process
  # instead of at the user's real xschem windows.
  if {[info exists ::env(GUI_GATE_BRAKE_NAME)] && $::env(GUI_GATE_BRAKE_NAME) ne ""} {
    return $::env(GUI_GATE_BRAKE_NAME)
  }
  return xschem
}
proc xschem_procs {} {
  set out {}
  if {![file isdirectory /proc]} { return $out }
  set want [brake_name]
  foreach d [glob -nocomplain -directory /proc -tails -type d *] {
    if {![string is integer -strict $d]} continue
    if {[catch {set fp [open [file join /proc $d cmdline] r]}]} continue
    set raw [read $fp]; close $fp
    # /proc/<pid>/cmdline is NUL-separated. Split on the NUL to get a REAL Tcl
    # list: a command line is arbitrary text, and treating it as a list (lindex
    # on the joined string) throws "list element in quotes followed by..." the
    # moment any process on the box has a quote in its arguments — which is
    # most of the time. That fired inside refresh, i.e. it would have killed
    # this panel on startup. Never parse foreign text as a list.
    set args {}
    foreach a [split $raw "\x00"] { if {$a ne ""} { lappend args $a } }
    if {![llength $args]} continue
    # argv[0]'s BASENAME must be exactly xschem: matching the string anywhere
    # would catch every process whose path merely runs through .../xschem/...,
    # this panel's own launcher included.
    if {[file tail [lindex $args 0]] ne $want} continue
    set c [join $args " "]
    set st T
    if {[catch {set fp [open [file join /proc $d stat] r]}]} { set st ? } else {
      set sl [read $fp]; close $fp
      # field 3, after the parenthesised comm which may itself contain spaces
      set st [lindex [split [string range $sl [expr {[string last ")" $sl]+2}] end]] 0]
    }
    lappend out [list $d $c $st]
  }
  return $out
}
proc halted_count {} {
  set n 0
  foreach p [xschem_procs] { if {[lindex $p 2] eq "T"} { incr n } }
  return $n
}
proc do_toggle_halt {} {
  set procs [xschem_procs]
  if {![llength $procs]} { return }
  if {[halted_count] > 0} {
    foreach p $procs { catch {exec kill -CONT [lindex $p 0]} }
    return
  }
  foreach p $procs { catch {exec kill -STOP [lindex $p 0]} }
}
proc do_kill_xschem {} {
  set procs [xschem_procs]
  if {![llength $procs]} { return }
  set n [llength $procs]
  if {[tk_messageBox -type yesno -icon warning -title "Kill xschem" \
        -message "Kill $n xschem process(es)?\n\nAny test run using them will\
fail. This cannot be undone."] ne "yes"} { return }
  # CONT first: a SIGSTOPped process never reaches its SIGTERM handler, so a
  # halted xschem would sit there un-killed until something resumed it.
  foreach p $procs { catch {exec kill -CONT [lindex $p 0]} }
  foreach p $procs { catch {exec kill -TERM [lindex $p 0]} }
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
  set ::stop_since [clock seconds]
  # also release anyone blocked at the go-ahead so they can exit
  foreach r [pending_reqs] { catch {file delete [file join $REQDIR $r]} }
}

# ---- attention -----------------------------------------------------------
# Make the panel impossible to miss ON THIS DESKTOP. The cross-desktop half is
# the shell side's relaunch (_gate_attention); this is everything a live
# process can do for itself. All of it is `catch`ed: a window manager that
# refuses focus-stealing must not take the panel down with it.
proc flash {n} {
  set c [expr {$n % 2 ? "#7a2b2b" : "#3a2b2b"}]
  catch {.top configure -bg $c}
  catch {.top.h configure -bg $c}
  catch {.top.msg configure -bg $c}
  if {$n > 0} { after 180 [list flash [expr {$n - 1}]] }
}
proc attention {} {
  catch {wm deiconify .}
  catch {wm attributes . -topmost 1}
  catch {raise .}
  catch {focus -force .}
  catch {bell}
  flash 7
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
# The poll loop must be UNKILLABLE. `after 300 refresh` used to be the last
# statement of the body, so any throw inside skipped the re-arm: the panel then
# kept its pid and its window — looking perfectly healthy to _gate_widget_alive
# — while no longer reading req/ or control at all. A suite would block at
# gate_start forever behind a frozen countdown, which is the one thing this gate
# promises never to do. (Not hypothetical: parsing /proc cmdlines as Tcl lists
# threw here, fatally, until the fix above.) Re-arm unconditionally; report the
# error to widget.log and carry on.
proc refresh {} {
  if {[catch {refresh_body} err]} {
    catch {puts stderr "gui_gate: refresh error: $err"; flush stderr}
  }
  after 300 refresh
}
proc refresh_body {} {
  global STATUSDIR REQDIR AUTOSTART_SECS
  set reqs [pending_reqs]
  set nctrl [read_control]
  set now [clock seconds]

  # A request that was not there last tick is a NEW suite asking — grab the
  # user's attention. Compared as a set, so one suite finishing while another
  # waits does not re-flash, and a suite that is merely still waiting does not
  # re-flash every 300 ms.
  foreach r $reqs {
    if {[lsearch -exact $::seen_reqs $r] < 0} { attention ; break }
  }
  set ::seen_reqs $reqs

  # STOP is per-suite, not a mode. Once the suites it aborted have drained
  # (no live status files, nothing waiting) put the control file back to RUN,
  # or the next suite to call gate_start would exit 3 having never been told
  # to stop. The grace period covers suites that have not yet reached their
  # next pause point and so have not read the STOP.
  if {$nctrl eq "STOP"} {
    if {![info exists ::stop_since]} { set ::stop_since $now }
    set running [llength [glob -nocomplain -directory $STATUSDIR *]]
    if {$running == 0 && [llength $reqs] == 0 && $now - $::stop_since >= 5} {
      write_control RUN
      unset ::stop_since
      set nctrl RUN
    }
  } elseif {[info exists ::stop_since]} {
    unset ::stop_since
  }

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
  # ...and freezes the approval window too, for the same reason: an hour
  # approved is an hour of TESTS, and burning it while everything is held would
  # quietly expire the window the user is waiting to use.
  # A "forever" grant has no countdown to freeze, and must NOT go through this
  # arithmetic: `[grant_until] + elapsed` on the string "forever" would either
  # error or, worse, resolve to a small number and silently downgrade an
  # open-ended approval to a few seconds.
  if {$nctrl eq "PAUSE" && [grant_live] && ![grant_forever] \
      && [info exists ::last_tick]} {
    set_grant_keepcount [expr {[grant_until] + ($now - $::last_tick)}]
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
    .snz.s5  configure -state normal
    .snz.s15 configure -state normal
    .snz.s30 configure -state normal
    catch {wm attributes . -topmost 1}
    catch {raise .}
  } elseif {[grant_live]} {
    set n [grant_count]
    set left [expr {[grant_forever] ? "until you Revoke" \
                                    : "another [fmt_left [expr {[grant_until] - $now}]]"}]
    .top.msg configure -fg #a5d6a7 -text \
      "APPROVED — suites start without asking for $left.\
[expr {$n == 1 ? "1 suite has" : "$n suites have"}] run so far.\nPause still\
holds them between tests; Revoke goes back to asking."
    .go.proceed configure -state disabled
    .snz.s5  configure -state disabled
    .snz.s15 configure -state disabled
    .snz.s30 configure -state disabled
  } else {
    .top.msg configure -fg #a5d6a7 -text \
      "No suite waiting for go-ahead.\nAllow 30m / Forever to approve a whole\
batch up front — no prompt per suite."
    .go.proceed configure -state disabled
    .snz.s5  configure -state disabled
    .snz.s15 configure -state disabled
    .snz.s30 configure -state disabled
  }
  # Allow is always available: approving BEFORE launching a batch is the point.
  .go.revoke configure -state [expr {[grant_live] ? "normal" : "disabled"}]

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
    # SWEEP a status file whose suite is gone. An interrupted suite (Ctrl-C,
    # `timeout`, worktree teardown) used to leave one forever, and STOP only
    # self-clears once no status file remains — so one orphan silently restored
    # the old "a single Stop press breaks every future suite" bug.
    set spid [file tail $f]
    if {[file isdirectory /proc] && [string is integer -strict $spid]
        && ![file exists [file join /proc $spid]]} {
      catch {file delete $f}
      continue
    }
    if {[catch {set fp [open $f r]}]} continue
    set line [string trim [read $fp]]; close $fp
    if {$line ne ""} { .status insert end "$line\n"; set any 1 }
  }
  # Anything running xschem that never enrolled in the gate. Pause/Stop cannot
  # touch these — only the brake can — so the panel says so plainly rather than
  # showing "(none)" while the display is being flooded.
  set xp [xschem_procs]
  set nhalt 0
  foreach p $xp {
    if {[lindex $p 2] eq "T"} { incr nhalt }
    set cmd [lindex $p 1]
    if {[string length $cmd] > 46} { set cmd "[string range $cmd 0 43]..." }
    .status insert end \
      "[expr {[lindex $p 2] eq {T} ? {HALTED } : {UNGATED}}] pid [lindex $p 0]  $cmd\n"
    set any 1
  }
  if {!$any} { .status insert end "  (none)\n" }
  .status configure -state disabled

  if {[llength $xp] == 0} {
    .run.halt configure -state disabled -text "Halt ALL xschem" -bg #4a148c
    .run.kill configure -state disabled
  } elseif {$nhalt > 0} {
    .run.halt configure -state normal -text "Resume $nhalt xschem" -bg #1565c0
    .run.kill configure -state normal
  } else {
    .run.halt configure -state normal \
      -text "Halt [llength $xp] xschem" -bg #4a148c
    .run.kill configure -state disabled
  }
}

proc on_close {} {
  global PIDFILE REQDIR GATE_DIR
  # closing the panel must never wedge blocked suites: release every
  # go-ahead request and set RUN so paused suites resume, then exit. (Closing
  # is "get out of the way", NOT "abort the suite" — that is the Stop button.)
  clear_deadline
  write_control RUN
  foreach r [pending_reqs] { catch {file delete [file join $REQDIR $r]} }
  # A DELIBERATE CLOSE MUST LEAVE NO MARKER AT ALL (v6).
  #
  # The shell side revives a panel that CRASHED and never one that was closed,
  # and it tells them apart by what is left on disk: a crash cannot run this
  # handler. v6 added two more such markers -- widget.pid.crashed (the corpse of
  # a panel a revive is already working on) and widget.launching (a wish that
  # was forked but has not connected to the X server yet) -- and EITHER of them
  # left behind here would authorise a revive one pause point after the user
  # closed the panel: the endless relaunch loop, which is the worst possible
  # regression in this file. So clear all three.
  #
  # widget.launching may also name a SECOND wish still trying to start (the user
  # can close this panel while a stale launch is in flight); killing it is the
  # same rule -- "get out of the way" must mean no window comes back.
  catch {file delete $PIDFILE}
  catch {file delete ${PIDFILE}.crashed}
  set lf [file join $GATE_DIR widget.launching]
  if {[file exists $lf]} {
    catch {
      set fp [open $lf r]; set v [string trim [read $fp]]; close $fp
      set p [lindex [split $v " "] 0]
      if {[string is integer -strict $p] && $p ne [pid]} { catch {exec kill $p} }
    }
    catch {file delete $lf}
  }
  destroy .
  exit 0
}
wm protocol . WM_DELETE_WINDOW on_close

# The shell side relaunches this process precisely so a fresh window maps on the
# desktop the user is looking at — so announce ourselves the moment we are up,
# not only once a request has been noticed by the poll loop. gate_start writes
# req/<pid> BEFORE it relaunches us, so that path still announces itself.
#
# But ONLY when something is actually waiting. A MID-SUITE revive (the shell's
# _gate_revive_widget, after the X server aborted and took the panel down with
# it) has no pending request — and there `attention`'s `focus -force` would
# steal the keyboard from the xschem window a running test is driving with
# `event generate`, turning the fix for a missing panel into a new class of test
# flake. Coming back silently is exactly right in that case: the suite was
# already running, nobody needs waking, the Pause button simply exists again.
set ::seen_reqs {}
after 120 { if {[llength [pending_reqs]] > 0} { attention } }

refresh
