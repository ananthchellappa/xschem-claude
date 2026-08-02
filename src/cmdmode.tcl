# cmdmode.tcl — a generic suspend/resume contract for canvas command modes.
#
# doc/claude/issues/0201-no-command-suspend-resume-contract.md
#
# THE PROBLEM. A "command mode" is a Tcl-level seize of the design canvas' gesture
# slots: ASE Direct Plot (Ctrl-4) rebinds <ButtonPress-1>/<ButtonRelease-1>/<Key-Escape>
# so every click queues a trace. While it holds them no instance can be selected, so
# descending mid-command was unreachable — and once the verb-noun pick (issue 0200) made
# it reachable, there was still no way to put the mode BACK afterwards. The mode's only
# exit, ase::ui::sod_end, FINISHES the command (in plot flavour it plots the queue), so
# "pause it" simply did not exist anywhere in the tree.
#
# THE CONTRACT.
#   cmdmode::register <key> <suspend_cb> <resume_cb>   declare participation
#   cmdmode::unregister <key>
#   cmdmode::suspend_all                -> release every live mode; returns how many
#   cmdmode::resume_all ?canvas?        -> put back exactly those; returns how many
#   cmdmode::rehome ?canvas?            -> suspend+resume, to follow a window hop
#   cmdmode::is_suspended               -> the latch, for tests and for callers
#
# <suspend_cb> takes no arguments and MUST return 1 if it actually released a live mode,
# 0 if there was nothing to release. It must NOT finish or commit the command: bindings
# go back, timers stop, prompts clear — and the accumulated state STAYS (D3).
#
# <resume_cb> takes one argument, the canvas widget path to come back up on (`.drw`,
# `.x1.drw`, …). That is D2: a command interrupted to descend resumes in the DESCENDED
# context, which after a new-window/new-tab descend is a *different canvas* than the one
# it was seized on. resume_all defaults the argument to the current canvas, read at
# resume time — after the navigation, which is the only moment it is right.
#
# D1 (user, explicit): this mechanism is deliberately orthogonal to the waveform viewer
# and to graph elements. It knows nothing about ASE, sessions, traces or simulation;
# ASE's entire share of it is one cmdmode::register line next to its own suspend/resume
# arms in ase_window.tcl.
#
# D6 — ONE suspended set at a time. suspend_all while already suspended is a no-op that
# returns 0: everything is already released, there is nothing left to take. resume_all
# with nothing suspended is likewise a no-op. That latch is what makes the two-frame
# verb-noun descend honest — arm the pick, N event-loop turns pass, then the dialog and
# the descend run in a different Tcl frame — because the several places that must be
# able to resume (descended / dialog cancelled / pick cancelled) can each call
# resume_all unconditionally and exactly the first one to arrive wins.
#
# ORDERING NOTE, not obvious and load-bearing. Suspending BEFORE a new window or tab is
# created is what keeps clone_canvas_bindings (xschem.tcl) honest: it copies `.drw`'s
# bindings verbatim onto every new canvas, so a still-seized mode would be cloned onto
# the child with the parent's key already substituted — clicks there would queue into a
# mode whose sod_end restores bindings on the *other* canvas, leaving the child
# permanently seized with dead scripts. Because every suspend site in the descend chain
# runs before schematic_in_new_window, the clone always copies pristine bindings.
#
# Pure Tcl, NO Tk anywhere in this file: it is sourced unconditionally from xschem.tcl
# and must survive --nogui, where `winfo` does not even exist as a command. It also must
# not read any set_ne preference global at source time — those defaults are set far
# below the source block in xschem.tcl.

namespace eval cmdmode {
  # key -> {suspend_cb resume_cb}. dict preserves insertion order, so suspend runs in
  # registration order and resume in the reverse (LIFO) — the order a nesting-aware
  # owner would expect even though D6 permits only one suspended set.
  variable modes     [dict create]
  # keys whose suspend_cb reported a live mode, newest first
  variable suspended {}
  # 1 between suspend_all and resume_all. Latched even when nothing was actually live,
  # so a resume that arrives with an empty `suspended` list is still recognised as the
  # terminal of its own suspend rather than as a stray call.
  variable active    0
}

# Declare a command mode. Both callbacks are command PREFIXES (a proc name, optionally
# with leading arguments), evaluated at global level.
proc cmdmode::register {key suspend_cb resume_cb} {
  variable modes
  if {$key eq {}} { return -code error "cmdmode: a mode key cannot be empty" }
  if {$suspend_cb eq {} || $resume_cb eq {}} {
    return -code error "cmdmode: '$key' needs both a suspend and a resume callback"
  }
  dict set modes $key [list $suspend_cb $resume_cb]
  return $key
}

# Drop a mode. Also drops it from the pending-resume list: a mode unregistered while
# suspended must not be resumed by callbacks that may no longer exist.
proc cmdmode::unregister {key} {
  variable modes; variable suspended
  dict unset modes $key
  set suspended [lsearch -all -inline -not -exact $suspended $key]
  return
}

proc cmdmode::registered   {} { variable modes;     return [dict keys $modes] }
proc cmdmode::is_suspended {} { variable active;    return $active }
proc cmdmode::pending      {} { variable suspended; return $suspended }

# Release every live command mode. Returns the number actually released (0 is the
# common case: usually nothing is up). Idempotent — see D6 above.
proc cmdmode::suspend_all {} {
  variable modes; variable suspended; variable active
  if {$active} { return 0 }
  set active 1
  set suspended {}
  dict for {key cbs} $modes {
    # A throwing suspend arm must not strand the modes after it in the dict, and must
    # not be recorded as resumable: we do not know how much of its teardown ran, and
    # resuming a half-released seize is worse than leaving it down.
    if {[catch {uplevel #0 [lindex $cbs 0]} r]} {
      catch {ciw_echo "cmdmode: suspend of '$key' failed: $r" error}
      continue
    }
    if {[string is integer -strict $r] && $r} { set suspended [linsert $suspended 0 $key] }
  }
  return [llength $suspended]
}

# Put back exactly the modes the matching suspend_all released, on `canvas` (default:
# whatever canvas is current NOW — after any descend/ascend/window hop, which is the
# whole point of D2). Returns the number resumed.
proc cmdmode::resume_all {{canvas {}}} {
  variable modes; variable suspended; variable active
  if {!$active} { return 0 }
  set active 0
  set todo $suspended
  set suspended {}
  if {$canvas eq {}} { catch {set canvas [xschem get current_win_path]} }
  set n 0
  foreach key $todo {
    if {![dict exists $modes $key]} { continue }
    if {[catch {uplevel #0 [linsert [lindex [dict get $modes $key] 1] end $canvas]} r]} {
      catch {ciw_echo "cmdmode: resume of '$key' failed: $r" error}
      continue
    }
    incr n
  }
  return $n
}

# Move every live mode to `canvas`. For navigation that was NOT an interruption — the
# user popping back up with Ctrl-E, or hopping to the parent window — where the mode
# should follow rather than be paused (D7). A no-op while a suspend is already in
# flight: that suspend's own resume owns the canvas choice and must not be pre-empted.
proc cmdmode::rehome {{canvas {}}} {
  variable active
  if {$active} { return 0 }
  cmdmode::suspend_all
  return [cmdmode::resume_all $canvas]
}
