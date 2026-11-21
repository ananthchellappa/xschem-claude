# cmdmode.tcl — a generic suspend/resume contract for canvas command modes.
#
# doc/claude/issues/0201-no-command-suspend-resume-contract.md
#
# THE PROBLEM. A "command mode" is a Tcl-level seize of the design canvas' gesture
# slots: ASE Direct Plot (Ctrl-4) rebinds the canvas's left-button and Escape sequences
# (the set is ase::ui::sod_slots') so every click queues a trace. While it holds them no instance can be selected, so
# descending mid-command was unreachable — and once the verb-noun pick (issue 0200) made
# it reachable, there was still no way to put the mode BACK afterwards. The mode's only
# exit, ase::ui::sod_end, FINISHES the command (in plot flavour it plots the queue), so
# "pause it" simply did not exist anywhere in the tree.
#
# THE CONTRACT.
#   cmdmode::register <key> <suspend_cb> <resume_cb> ?<held_cb>?   declare participation
#   cmdmode::unregister <key>
#   cmdmode::suspend_all                -> release every live mode; returns how many
#   cmdmode::resume_all ?canvas?        -> put back exactly those; returns how many
#   cmdmode::rehome ?canvas?            -> suspend+resume, to follow a window hop
#   cmdmode::release_order              -> the modes in the order suspend_all releases them
#   cmdmode::is_suspended               -> the latch, for tests and for callers
#   cmdmode::pristine <canvas> <sequence> <script> ?<canon>?  -> that slot's script under every mode
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
# ORDERING NOTE, not obvious and load-bearing. Two things keep the scripts of a paused
# mode off the canvases across a descend, and it takes both.
#
# WHEN: the suspend comes BEFORE a new window or tab is created. clone_canvas_bindings
# (xschem.tcl) copies `.drw`'s bindings onto every new canvas, so a still-seized mode
# would be cloned onto the child with the parent's key already substituted — clicks
# there would queue into a mode whose sod_end restores bindings on the *other* canvas,
# leaving the child permanently seized with dead scripts. Every suspend site in the
# descend chain runs before schematic_in_new_window.
#
# IN WHICH ORDER: the top of a stack is released first (cmdmode::release_order). Two
# modes can hold one canvas at once, one seized over the other, and each hands back
# what the canvas held when it took it. Released top first, the upper mode hands the
# lower mode's scripts back and the lower mode then hands back the editor's: while
# everything is paused the canvas holds the editor's bindings. That is what the clone
# copies, what a click made in the meantime lands on (the descend's own pick waits for
# one), and what the resumes keep as what the canvas had before, on the same canvas or
# on a new one. Released the other way round the canvas holds the lower mode's scripts
# for all of that (a paused mode reports nothing held, so cmdmode::pristine cannot step
# past them), and still holds them after the modes have been ended: it takes no left
# click. resume_all puts the modes back last-released first, which is bottom first, so
# the mode that was on top is on top again.
#
# The order is read from what the modes declare with their <held_cb>. A mode whose
# place cannot be read (it has no <held_cb>, or its <held_cb> raises) is neither over
# nor under any other: it goes as soon as it is the earliest-registered mode not known
# to be under another, which can be ahead of an earlier-registered mode that is
# waiting for the mode over it (registered low, plain, top with top over low: plain,
# top, low). Two such modes go in registration order, and so do two modes that each
# name the other's script as their predecessor. Where such a mode really is part of a
# stack, registration decides whether the stack is released top first: a stack of two
# is released top first only when its upper mode was registered first; otherwise the
# canvas is left as described above.
#
# A window created by any OTHER door while a mode is up (`xschem new_schematic
# create_window`, a profile's new-window key) is not preceded by a suspend. For that
# door clone_canvas_bindings asks cmdmode::pristine for each script it is about to
# copy, which steps down through whatever the modes declare with their <held_cb>.
#
# Pure Tcl, NO Tk anywhere in this file: it is sourced unconditionally from xschem.tcl
# and must survive --nogui, where `winfo` does not even exist as a command. It also must
# not read any set_ne preference global at source time — those defaults are set far
# below the source block in xschem.tcl.

namespace eval cmdmode {
  # key -> {suspend_cb resume_cb held_cb}. dict preserves insertion order, which is the
  # registration order cmdmode::release_order falls back on.
  variable modes     [dict create]
  # keys whose suspend_cb reported a live mode, last released first: the order
  # resume_all puts them back in
  variable suspended {}
  # 1 between suspend_all and resume_all. Latched even when nothing was actually live,
  # so a resume that arrives with an empty `suspended` list is still recognised as the
  # terminal of its own suspend rather than as a stray call.
  variable active    0
}

# Declare a command mode. The callbacks are command PREFIXES (a proc name, optionally
# with leading arguments), evaluated at global level.
#
# <held_cb> is optional (issue 1724). It takes no arguments and answers a flat list
#   canvas sequence script predecessor   canvas sequence script predecessor   ...
# with one group of four for every canvas binding the mode holds NOW: the script it
# bound there and the script that slot held before the mode took it. A mode that is
# not up, or is suspended, answers an empty list. cmdmode::pristine reads it.
proc cmdmode::register {key suspend_cb resume_cb {held_cb {}}} {
  variable modes
  if {$key eq {}} { return -code error "cmdmode: a mode key cannot be empty" }
  if {$suspend_cb eq {} || $resume_cb eq {}} {
    return -code error "cmdmode: '$key' needs both a suspend and a resume callback"
  }
  dict set modes $key [list $suspend_cb $resume_cb $held_cb]
  return $key
}

# The script `canvas` would hold on `sequence` with no command mode up, given that it
# holds `script` now. Each mode that declared a <held_cb> is asked what it holds; when
# one of them holds exactly `script` in that slot, the answer steps down to that
# mode's predecessor, and the walk repeats, so a mode seized over another mode is
# stepped through as well. A script no mode holds is answered unchanged. A <held_cb>
# that raises, or answers a list that is not groups of four, is passed over.
#
# TWO SPELLINGS OF ONE SEQUENCE. Tk lists a binding under its own spelling, which
# is not always the one it was made with (`<ButtonPress-1>` is listed as
# `<Button-1>`), and a mode declares its slots the way it spelled them. `canon`,
# when given, is a command prefix that takes one sequence and answers Tk's spelling
# of it; both sides of the slot comparison go through it. This file has no Tk, so
# the caller that has it passes the prefix; without one the spellings must be equal.
#
# The one caller is clone_canvas_bindings (xschem.tcl): a window created while a mode
# is up, by a door that did not suspend first, must get the bindings the source canvas
# has underneath the mode and not the mode's own scripts (see the ordering note above).
proc cmdmode::pristine {canvas sequence script {canon {}}} {
  variable modes
  set want [cmdmode::seq_spelled $canon $sequence]
  for {set hop 0} {$hop < 8} {incr hop} {
    set stepped 0
    dict for {key cbs} $modes {
      set held [lindex $cbs 2]
      if {$held eq {}} { continue }
      if {[catch {uplevel #0 $held} rows]} { continue }
      if {[catch {llength $rows} n] || $n % 4} { continue }
      foreach {cv sq own prev} $rows {
        if {$cv ne $canvas || $own ne $script || $prev eq $script} { continue }
        if {[cmdmode::seq_spelled $canon $sq] ne $want} { continue }
        set script $prev
        set stepped 1
        break
      }
      if {$stepped} { break }
    }
    if {!$stepped} { break }
  }
  return $script
}

# `sequence` as the `canon` prefix spells it; unchanged when there is no prefix or
# the prefix raises.
proc cmdmode::seq_spelled {canon sequence} {
  if {$canon eq {}} { return $sequence }
  if {[catch {uplevel #0 [linsert $canon end $sequence]} r]} { return $sequence }
  return $r
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

# Does the held list `upper` show its mode seized over the mode whose held list is
# `lower`? It does when a group of `upper` names, as what its slot held before, a
# script that `lower` holds on the same canvas.
#
# WHAT IS COMPARED: the canvas names and the scripts, each as a string. The sequences
# are not compared: two modes may spell one slot differently (`<ButtonPress-1>`,
# `<Button-1>`), and this file has no Tk to ask for one spelling. A script the upper
# mode binds on that canvas itself (a bare `break` on a release, say, which several
# modes bind) cannot tell whose it was and is not taken as evidence, and neither is
# an empty predecessor.
proc cmdmode::holds_over {upper lower} {
  foreach {cv sq own prev} $upper {
    if {$prev eq {}} { continue }
    set shared 0
    foreach {cv1 sq1 own1 prev1} $upper {
      if {$cv1 eq $cv && $own1 eq $prev} { set shared 1 ; break }
    }
    if {$shared} { continue }
    foreach {cv2 sq2 own2 prev2} $lower {
      if {$cv2 eq $cv && $own2 eq $prev} { return 1 }
    }
  }
  return 0
}

# The registered modes in the order suspend_all releases them: the top of a stack
# first, so that each mode hands back what it took and the canvas ends with the
# bindings it had under all of them (the ordering note at the head of this file).
#
# Each mode that declared a <held_cb> is asked once what it holds, before anything is
# released: a released mode reports nothing. Then, step by step, the earliest
# registered mode that no mode still to come is seized over (cmdmode::holds_over) goes
# next. A mode nothing is known about (one with no <held_cb>, one whose <held_cb>
# raises or answers a list that is not groups of four, one that holds nothing now, one
# on a canvas of its own) is neither over nor under any other: it goes as soon as it
# is the earliest-registered mode not known to be under another, which can be ahead of
# an earlier-registered mode that is waiting for the mode over it (registered low,
# plain, top with top over low: plain, top, low). Two such modes go in registration
# order, so with nothing known about any mode the order is the registration order. In
# a ring, where each mode still to come is under another by what they declare, the
# earliest registered of them goes next.
proc cmdmode::release_order {} {
  variable modes
  set all $modes
  set left [dict keys $all]
  foreach key $left {
    set rows {}
    set held [lindex [dict get $all $key] 2]
    if {$held ne {} && ![catch {uplevel #0 $held} got] && ![catch {llength $got} n] && $n % 4 == 0} {
      set rows $got
    }
    set holds($key) $rows
  }
  set out {}
  while {[llength $left]} {
    set next [lindex $left 0]
    foreach key $left {
      set under 0
      foreach other $left {
        if {$other ne $key && [cmdmode::holds_over $holds($other) $holds($key)]} { set under 1 ; break }
      }
      if {!$under} { set next $key ; break }
    }
    lappend out $next
    set left [lsearch -all -inline -not -exact $left $next]
  }
  return $out
}

# Release every live command mode, the top of a stack first (cmdmode::release_order).
# Returns the number actually released (0 is the common case: usually nothing is up).
# Idempotent — see D6 above.
proc cmdmode::suspend_all {} {
  variable modes; variable suspended; variable active
  if {$active} { return 0 }
  set active 1
  set suspended {}
  set order [cmdmode::release_order]
  set all $modes
  foreach key $order {
    if {![dict exists $all $key]} { continue }
    # A throwing suspend arm must not strand the modes after it, and must not be
    # recorded as resumable: we do not know how much of its teardown ran, and
    # resuming a half-released seize is worse than leaving it down.
    if {[catch {uplevel #0 [lindex [dict get $all $key] 0]} r]} {
      catch {ciw_echo "cmdmode: suspend of '$key' failed: $r" error}
      continue
    }
    if {[string is integer -strict $r] && $r} { set suspended [linsert $suspended 0 $key] }
  }
  return [llength $suspended]
}

# Put back exactly the modes the matching suspend_all released, on `canvas` (default:
# whatever canvas is current NOW — after any descend/ascend/window hop, which is the
# whole point of D2), last released first: the bottom of a stack goes back first and
# its top last. Returns the number resumed.
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
# should follow rather than be paused (D7). A stack moves as a stack: the mode that was
# on top is on top again. A no-op while a suspend is already in flight: that suspend's
# own resume owns the canvas choice and must not be pre-empted.
proc cmdmode::rehome {{canvas {}}} {
  variable active
  if {$active} { return 0 }
  cmdmode::suspend_all
  return [cmdmode::resume_all $canvas]
}
