#!/usr/bin/wish
# review_gate_widget.tcl — "review requested" panel for the one-item-at-a-time
# build loop (see doc/claude/specs/review_gate.md).
#
# THE PROBLEM IT SOLVES: a plan like
# doc/claude/suggestions/plan_viewer_enhancements_2026-07.md is built one item
# at a time, and each item wants a human eyeball before the next one starts.
# Blocking on that ack unconditionally means an item finished at 02:00 stalls
# until morning. Blocking on nothing means ten items land unreviewed.
#
# So: the builder raises a request, the panel asks, and the request
# SELF-RELEASES after a timeout (default 30 min) unless the user explicitly
# holds it. Same contract as the GUI-test gate
# (tests/headless/gui_gate_widget.tcl): THE ONLY THING THAT BLOCKS
# INDEFINITELY IS AN EXPLICIT USER HOLD.
#
# Control directory (shared with review_gate.sh, under $HOME so worktrees and
# subagent runs all reach the same panel):
#   $DIR/req/<id>       one line: the item label. Its presence = "blocked".
#   $DIR/body/<id>      free text: what changed, suites, what to eyeball.
#   $DIR/reply/<id>     written by THIS panel, read then deleted by the shell:
#                         line 1 = PROCEED | STOP
#                         line 2+ = the user's notes (may be empty)
#   $DIR/hold/<id>      present while the user is holding: freezes the countdown
#   $DIR/deadline/<id>  epoch seconds the request auto-proceeds at
#   $DIR/widget.pid     this process's pid (liveness / singleton lock)
#
# Deliberately a SEPARATE control dir from ~/.claude/gui_test_gate: a review
# ack and a "do not flood my display with GUI tests" pause are different
# questions, and one must never release the other.
#
# FAIL OPEN, everywhere: closing this window replies PROCEED to everything
# pending (closing is "get out of my way", not "abort"); if this process dies,
# the shell side stops waiting on the next poll. A review gate that can wedge
# the build loop is worse than no review gate.

package require Tk

set DIR [lindex $argv 0]
if {$DIR eq ""} { set DIR [file join $env(HOME) .claude review_gate] }
foreach sub {req body reply hold deadline} { file mkdir [file join $DIR $sub] }

set REQDIR   [file join $DIR req]
set BODYDIR  [file join $DIR body]
set REPLYDIR [file join $DIR reply]
set HOLDDIR  [file join $DIR hold]
set DEADDIR  [file join $DIR deadline]
set PIDFILE  [file join $DIR widget.pid]

set fp [open $PIDFILE w]; puts $fp [pid]; close $fp

# ---- helpers -------------------------------------------------------------
proc slurp {f} {
  if {[catch {set fp [open $f r]}]} { return "" }
  set t [read $fp]; close $fp
  return [string trim $t]
}
# Atomic: the shell side polls for reply/<id> and reads it the instant it
# appears, so a half-written file would be read as a truncated decision.
proc spit_atomic {f txt} {
  set tmp "$f.tmp[pid]"
  if {[catch {set fp [open $tmp w]}]} { return 0 }
  puts -nonewline $fp $txt
  close $fp
  return [expr {![catch {file rename -force $tmp $f}]}]
}
proc pending {} {
  global REQDIR
  return [lsort [glob -nocomplain -tails -directory $REQDIR *]]
}
proc fmt_left {secs} {
  if {$secs < 0} { set secs 0 }
  return "[expr {$secs/60}]m [format %02d [expr {$secs%60}]]s"
}

# ---- widgets -------------------------------------------------------------
wm title . "xschem — review requested"
wm geometry . 560x520+60+60
wm attributes . -topmost 1
. configure -bg #22272e
option add *background #22272e
option add *foreground #e6edf3
option add *font {Helvetica 11}

frame .hdr -bg #2d333b -bd 2 -relief ridge
pack .hdr -fill x -padx 6 -pady {6 4}
label .hdr.h -text "REVIEW REQUESTED" -bg #2d333b -fg #ffd27f \
  -font {Helvetica 14 bold}
pack .hdr.h -anchor w -padx 8 -pady {6 0}
label .hdr.item -bg #2d333b -fg #e6edf3 -justify left -anchor w \
  -wraplength 520 -text "(nothing waiting)" -font {Helvetica 11 bold}
pack .hdr.item -fill x -padx 8 -pady {2 2}
label .hdr.count -bg #2d333b -fg #ff8a80 -justify left -anchor w \
  -wraplength 520 -text ""
pack .hdr.count -fill x -padx 8 -pady {0 6}

label .bodyhdr -text "What landed / what to eyeball:" -anchor w
pack .bodyhdr -fill x -padx 8 -pady {2 0}
frame .bodyf -bg #22272e
pack .bodyf -fill both -expand 1 -padx 6 -pady {0 4}
text .bodyf.t -height 12 -bg #1b1f24 -fg #cfd8dc -bd 0 -wrap word \
  -font {Courier 10} -state disabled -yscrollcommand {.bodyf.sb set}
scrollbar .bodyf.sb -command {.bodyf.t yview}
pack .bodyf.sb -side right -fill y
pack .bodyf.t -side left -fill both -expand 1

label .noteshdr -text "Notes back to the builder (optional):" -anchor w
pack .noteshdr -fill x -padx 8 -pady {2 0}
text .notes -height 4 -bg #1b1f24 -fg #e6edf3 -bd 1 -wrap word \
  -insertbackground #e6edf3 -font {Courier 10}
pack .notes -fill x -padx 6 -pady {0 6}

frame .btns -bg #22272e
pack .btns -fill x -padx 6 -pady {0 8}
button .btns.go -text "Reviewed — proceed" -bg #2e7d32 -fg white -width 18 \
  -activebackground #388e3c -command {do_reply PROCEED}
button .btns.hold -text "Hold (I'm looking)" -bg #f9a825 -fg black -width 16 \
  -activebackground #fbc02d -command do_toggle_hold
button .btns.stop -text "Stop — wait for me" -bg #b71c1c -fg white -width 17 \
  -activebackground #c62828 -command {do_reply STOP}
pack .btns.go .btns.hold .btns.stop -side left -padx 3 -pady 4

label .foot -bg #1b1f24 -fg #9ccc65 -anchor w -font {Helvetica 10}
pack .foot -fill x -padx 6 -pady {0 6}

# ---- actions -------------------------------------------------------------
# One reply serves every pending request: in practice there is exactly one
# (the loop is one-item-at-a-time), and answering "proceed" while a second
# request sits unanswered would be a lie about what was reviewed only if the
# loop were parallel — it is not.
proc do_reply {verdict} {
  global REPLYDIR HOLDDIR DEADDIR
  set notes [string trim [.notes get 1.0 end]]
  foreach id [pending] {
    spit_atomic [file join $REPLYDIR $id] "$verdict\n$notes"
    catch {file delete [file join $HOLDDIR $id]}
    catch {file delete [file join $DEADDIR $id]}
  }
  .notes delete 1.0 end
}

# Hold = "I am at the desk, do not auto-proceed". It freezes the countdown and
# does NOT release the request; the user still has to press Proceed or Stop.
# This is the one state that can block the loop indefinitely, and it is the
# only one, on purpose.
proc do_toggle_hold {} {
  global HOLDDIR
  set ids [pending]
  if {$ids eq ""} return
  set held [file exists [file join $HOLDDIR [lindex $ids 0]]]
  foreach id $ids {
    set f [file join $HOLDDIR $id]
    if {$held} { catch {file delete $f} } else { spit_atomic $f held }
  }
}

# ---- attention -----------------------------------------------------------
# In-desktop half only. The cross-desktop half is the shell side relaunching
# this process so a fresh window maps on the desktop the user is looking at
# (the user runs VirtuaWin; raise/-topmost act only within a desktop). All
# catch'ed: a WM that refuses focus-stealing must not take the panel down.
proc flash {n} {
  set c [expr {$n % 2 ? "#5a3d1a" : "#2d333b"}]
  foreach w {.hdr .hdr.h .hdr.item .hdr.count} { catch {$w configure -bg $c} }
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
set ::seen {}
set ::shown {}
proc refresh {} {
  global REQDIR BODYDIR HOLDDIR DEADDIR
  set ids [pending]
  set now [clock seconds]

  foreach id $ids {
    if {[lsearch -exact $::seen $id] < 0} { attention ; break }
  }
  set ::seen $ids

  if {$ids eq ""} {
    .hdr.item configure -text "(nothing waiting)"
    .hdr.count configure -text "" -fg #9ccc65
    if {$::shown ne ""} {
      .bodyf.t configure -state normal
      .bodyf.t delete 1.0 end
      .bodyf.t insert end "  The builder is working. This panel will pop, beep\n  and flash when the next item is ready for review.\n"
      .bodyf.t configure -state disabled
      set ::shown {}
    }
    .btns.go configure -state disabled
    .btns.hold configure -state disabled -text "Hold (I'm looking)" \
      -bg #f9a825 -fg black
    .btns.stop configure -state disabled
    .foot configure -fg #9ccc65 -text "idle"
  } else {
    set id [lindex $ids 0]
    .hdr.item configure -text [slurp [file join $REQDIR $id]]
    # reload the body only when the request changes — rewriting a text widget
    # every 500 ms would fight the user's scrollbar
    if {$::shown ne $id} {
      .bodyf.t configure -state normal
      .bodyf.t delete 1.0 end
      set b [slurp [file join $BODYDIR $id]]
      if {$b eq ""} { set b "(no detail supplied)" }
      .bodyf.t insert end $b
      .bodyf.t configure -state disabled
      set ::shown $id
    }
    set held [file exists [file join $HOLDDIR $id]]
    set dl [slurp [file join $DEADDIR $id]]
    if {$held} {
      .hdr.count configure -fg #90caf9 \
        -text "HELD — auto-proceed frozen. Press Proceed or Stop when you are done looking."
      .btns.hold configure -text "Un-hold" -bg #1565c0 -fg white \
        -activebackground #1976d2
    } elseif {[string is integer -strict $dl]} {
      .hdr.count configure -fg #ff8a80 \
        -text "Proceeds to the next item by itself in [fmt_left [expr {$dl - $now}]]."
      .btns.hold configure -text "Hold (I'm looking)" -bg #f9a825 -fg black \
        -activebackground #fbc02d
    } else {
      .hdr.count configure -fg #ffd27f -text "Waiting for you."
      .btns.hold configure -text "Hold (I'm looking)" -bg #f9a825 -fg black \
        -activebackground #fbc02d
    }
    .btns.go configure -state normal
    .btns.hold configure -state normal
    .btns.stop configure -state normal
    .foot configure -fg #ffd27f \
      -text "[llength $ids] item(s) awaiting review — notes above are sent with whichever button you press"
    catch {wm attributes . -topmost 1}
    catch {raise .}
  }

  after 500 refresh
}

proc on_close {} {
  global PIDFILE REPLYDIR HOLDDIR DEADDIR
  # Closing must never wedge the build loop: everything pending gets PROCEED,
  # same rule as the GUI-test gate. To actually halt the loop, press Stop.
  foreach id [pending] {
    spit_atomic [file join $REPLYDIR $id] "PROCEED\n(panel closed)"
    catch {file delete [file join $HOLDDIR $id]}
    catch {file delete [file join $DEADDIR $id]}
  }
  catch {file delete $PIDFILE}
  destroy .
  exit 0
}
wm protocol . WM_DELETE_WINDOW on_close

after 120 attention
refresh
