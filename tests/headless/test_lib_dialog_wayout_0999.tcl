# tests/headless/test_lib_dialog_wayout_0999.tcl
#
# Issue 0999 -- the Library Manager's prompts vanish without answering if you
# press their title-bar close button.
#
# What the user does: right-click in the Library Manager, pick New cell... or
# Rename... or Copy view... or New view... or a Check in..., or Maintain's
# library picker. A small window opens asking for something. Instead of OK or
# Cancel, press the X in its title bar. The window disappears and nothing
# happens -- no cell, no error, no status line -- and the press that opened it
# goes on waiting for an answer that can never arrive, until the user quits.
#
# Mechanism: every prompt in src/library_manager.tcl parks in
# `vwait libmgr::dlg_done`, which returns only when something WRITES that
# variable. OK, Cancel, Return and Escape all write it. The window manager's
# close button writes nothing, and neither does the prompt being destroyed from
# underneath when the Library Manager itself is closed. The toplevel goes away;
# the wait stays.
#
# `libmgr::newlib_dialog` was given the way out under issue 0998 because its
# caller LOOPS and a lost answer there is a hang rather than one lost press.
# The rest were recorded as 0999 rather than changed untested in a repair pass.
#
# See doc/claude/issues/0999-the-library-managers-other-four-prompts-vanish-without-answering-if-you-press-their-close-button.md
#      doc/claude/issues/0998-the-new-library-suite-hangs-instead-of-failing-if-the-re-prompt-loses-its-way-out.md
#
# THE POPULATION IS DERIVED, NOT LISTED. Issue 0999's own text names five
# prompts and the brief that commissioned this suite named six; neither number
# is what the file contains. LV1 asks the interpreter which `libmgr::` procs
# issue a wait in COMMAND POSITION and reports the answer, so a prompt added
# later without a way out reddens LV2 and LV3 with nobody editing a list. A
# hand-kept list is the same defect one level up.
#
# TWO ARMS, TWO LEGITIMATE COUNTS. LV1 and LV2 read the interpreter's own proc
# bodies and need no windows. LV3 drives the real prompts and only exists where
# Tk does.
#   counted arm   tests/headless/run_suites.sh --nogui test_lib_dialog_wayout_0999
#   display arm   tests/headless/run_suites.sh test_lib_dialog_wayout_0999
# The suite prints both totals on every run; reporting one against the other
# arm reads as a standing red. Say which arm produced the number.

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}

source [file join [file dirname [info script]] scratch.tcl]

# === THE DERIVATION =========================================================
# Every command-position command string in a Tcl body, as text.
#
# Comment segments are dropped on purpose. A whole-body text scan counts prose
# ABOUT a predicate as evidence for it -- issue 1646, where a block comment
# quoting a signature in order to say it was pinned kept the pin reading green
# for a month after the pin died -- and src/library_manager.tcl's own comments
# discuss, at length, the very commands the rows below look for.
#
# DECLARED LIMITS, so nobody has to guess them: the split on `;` is naive and
# would cut a semicolon inside a braced word, and a command continued onto the
# next line with a backslash is seen as two segments. Neither can manufacture a
# false segment that BEGINS with `vwait`, `tkwait`, `wm` or `set d`, which is
# all the predicates below read. LV1b and LV2b are the controls that keep those
# predicates honest.
proc lv_segments {body} {
  set out {}
  foreach line [split $body \n] {
    foreach piece [split $line ";"] {
      set t [string trim $piece]
      # a continued block puts close-braces and else/elseif in front of the
      # real command; step over them so the command is in first position
      while {1} {
        if {[string index $t 0] eq "\}"} { set t [string trim [string range $t 1 end]]; continue }
        if {[regexp {^(?:else|elseif|then)[ \t]+(.*)$} $t -> rest]} { set t [string trim $rest]; continue }
        break
      }
      if {$t eq {} || [string index $t 0] eq "#"} continue
      lappend out $t
    }
  }
  return $out
}

# Does this proc park in an event-loop wait, in command position?
proc lv_is_waiter {p} {
  if {[info procs $p] eq {}} { return 0 }
  foreach seg [lv_segments [info body $p]] {
    if {[regexp {^(?:vwait|tkwait)[ \t]} $seg]} { return 1 }
  }
  return 0
}

# The toplevel a prompt builds, taken from the prompt's own `set d <path>`.
proc lv_toplevel_of {p} {
  if {[info procs $p] eq {}} { return {} }
  foreach seg [lv_segments [info body $p]] {
    if {[regexp {^set[ \t]+d[ \t]+(\.\S+)$} $seg -> path]} { return $path }
  }
  return {}
}

# Does this prompt reach a way out for the window manager's close button --
# either installing the close protocol itself, or handing that job to the
# shared helper? Command position only, for the reason stated above.
proc lv_has_way_out {p} {
  if {[info procs $p] eq {}} { return 0 }
  foreach seg [lv_segments [info body $p]] {
    if {[regexp {^wm[ \t]+protocol[ \t]+\S+[ \t]+WM_DELETE_WINDOW} $seg]} { return 1 }
    if {[regexp {^(?:::)?libmgr::dlg_way_out[ \t]} $seg]} { return 1 }
  }
  return 0
}

proc lv_waiters {} {
  set out {}
  foreach p [lsort [info procs ::libmgr::*]] {
    if {[lv_is_waiter $p]} { lappend out $p }
  }
  return $out
}

# === LV1 -- WHICH PROMPTS WAIT ==============================================
set waiters [lv_waiters]
# FLOOR, not a baseline: a ratchet that reddens if the derivation stops finding
# the prompts, and that a new prompt can only push up.
check "LV1a the prompts this file waits on are derived from each proc's own command-position vwait/tkwait (FLOOR: 7)" \
  [expr {[llength $waiters] >= 7}] "(n=[llength $waiters] set='$waiters')"

# CONTROLS for the derivation. Built here on purpose: one proc whose only
# `vwait` is prose and a string literal, one that really waits. A whole-body
# text scan reports both, which is the defect this derivation is shaped around.
proc ::lv_ctl_decoy {} {
  # vwait libmgr::dlg_done -- prose about the predicate, not a wait
  set s "vwait libmgr::dlg_done"
  return $s
}
proc ::lv_ctl_real {} { vwait ::lv_ctl_never }
check "LV1b the derivation sees a real wait and does not see one that is only prose or a string" \
  [expr {[lv_is_waiter ::lv_ctl_real] == 1 && [lv_is_waiter ::lv_ctl_decoy] == 0}] \
  "(real=[lv_is_waiter ::lv_ctl_real] decoy=[lv_is_waiter ::lv_ctl_decoy])"

# Every member must name its own toplevel, or LV3 below would skip it in
# silence -- which is how a fence stops fencing without anybody noticing.
set lv1c_bad {}
foreach p $waiters { if {[lv_toplevel_of $p] eq {}} { lappend lv1c_bad $p } }
check "LV1c every derived prompt names its own toplevel in its own body, so none can be skipped below" \
  [expr {[llength $lv1c_bad] == 0}] "(nameless='$lv1c_bad')"

# === LV2 -- EVERY PROMPT HAS A WAY OUT (text, both arms) ====================
set lv2_missing {}
foreach p $waiters { if {![lv_has_way_out $p]} { lappend lv2_missing $p } }
check "LV2a every prompt in the derived set installs a close-button way out" \
  [expr {[llength $lv2_missing] == 0}] \
  "(without='$lv2_missing' of [llength $waiters])"

# CONTROL for LV2a: a waiter whose only mention of the close protocol is prose
# must FAIL the predicate, or LV2a is green by construction.
proc ::lv_ctl_noway {} {
  # wm protocol $d WM_DELETE_WINDOW -- prose about the handler, not a handler
  vwait ::lv_ctl_never
}
check "LV2b and the way-out predicate can say no: a waiter whose only handler is prose fails it" \
  [expr {[lv_is_waiter ::lv_ctl_noway] == 1 && [lv_has_way_out ::lv_ctl_noway] == 0}] \
  "(waiter=[lv_is_waiter ::lv_ctl_noway] wayout=[lv_has_way_out ::lv_ctl_noway])"

# The shared helper is where LV2a's second arm points, so it is asserted
# directly rather than taken on trust: it must set the close protocol AND bind
# the toplevel's own destruction, since closing the Library Manager takes a
# prompt with it the same way the close button does.
set lv2c_proto 0
set lv2c_destroy 0
if {[info procs ::libmgr::dlg_way_out] ne {}} {
  foreach seg [lv_segments [info body ::libmgr::dlg_way_out]] {
    if {[regexp {^wm[ \t]+protocol[ \t]+\S+[ \t]+WM_DELETE_WINDOW} $seg]} { set lv2c_proto 1 }
    if {[regexp {^bind[ \t]+\S+[ \t]+<Destroy>} $seg]} { set lv2c_destroy 1 }
  }
}
check "LV2c the shared way-out helper sets the close protocol and binds the toplevel going away" \
  [expr {$lv2c_proto && $lv2c_destroy}] \
  "(exists=[expr {[info procs ::libmgr::dlg_way_out] ne {}}] protocol=$lv2c_proto destroy=$lv2c_destroy)"

# A child widget being torn down must not read as the user cancelling, so the
# <Destroy> handler has to compare the window it was given against the
# toplevel. Asserted on the handler the helper actually names.
set lv2d_handler {}
set lv2d_guards 0
if {[info procs ::libmgr::dlg_way_out] ne {}} {
  foreach seg [lv_segments [info body ::libmgr::dlg_way_out]] {
    if {[regexp {^bind[ \t]+\S+[ \t]+<Destroy>[ \t]+\[list[ \t]+(\S+)} $seg -> h]} { set lv2d_handler $h }
  }
}
if {$lv2d_handler ne {} && [info procs $lv2d_handler] ne {}} {
  foreach seg [lv_segments [info body $lv2d_handler]] {
    if {[regexp {^if[ \t]+\{\$w[ \t]+eq[ \t]+\$d\}} $seg]} { set lv2d_guards 1 }
  }
}
check "LV2d the handler it binds only answers for the toplevel itself, not for a child being torn down" \
  [expr {$lv2d_guards == 1}] "(handler='$lv2d_handler' guards=$lv2d_guards)"

# === LV3 -- THE PROMPTS, DRIVEN (display arm only) ==========================
if {[info commands winfo] eq {}} {
  puts "note: no Tk in this session -- the rows that drive the real prompts are display-arm only"
} else {
  library_manager
  update idletasks

  # Make one prompt's window go away without anybody answering it, and ask
  # whether the press came back.
  #
  # A WINDOW THAT WILL NOT LET GO IS A HANG, NOT A RED, and this suite is
  # registered in tests/run_regression.tcl, where a hanging case costs the
  # whole run. So the poller watches for the prompt's wait still standing at
  # its pre-wait -1 after the window is gone, pokes it, and REMEMBERS that it
  # had to -- which is the red. Without the poke the suite would stop dead with
  # no RESULT line and no OVERALL line, and the row written to catch this would
  # never run at all; issue 0998 measured exactly that shape on the sibling
  # window, where the run was killed at its timeout having never reached the row.
  # `how` picks WHICH closing gesture is exercised, and band LV4 exists because
  # the first cut of this suite only ever used `destroy`.
  #   destroy -- tear the toplevel down from underneath the wait. That is the
  #              Library-Manager-closed-over-an-open-prompt case, and it travels
  #              through the `<Destroy>` binding.
  #   wmclose -- EVALUATE the window manager's close-button script, which is the
  #              gesture the issue is actually about. ⚠ Reading
  #              `wm protocol $w WM_DELETE_WINDOW` and then destroying the window
  #              NEVER RUNS THAT SCRIPT, so a suite that only does that passes
  #              against a handler wired to the ACCEPTING value -- a one-character
  #              regression turning the title-bar X into OK. `lv_latch` records
  #              what the wait was released WITH so a row can assert it is Cancel.
  proc lv_drive {p path {how destroy}} {
    set ::lv_state 0
    set ::lv_polls 0
    set ::lv_proto NONE
    set ::lv_rescued 0
    set ::lv_outcome none
    set ::lv_how $how
    set ::lv_latch NOTSET
    set ::lv_path $path
    set call [list $p]
    foreach a [info args $p] { lappend call {} }
    after 60 lv_poll
    set rc [catch {uplevel #0 $call} res]
    for {set i 0} {$i < 60 && $::lv_outcome eq "none"} {incr i} {
      update
      after 40 {set ::lv_tick 1}
      vwait ::lv_tick
    }
    catch {grab release $path}
    catch {destroy $path}
    return [list rc $rc res $res proto $::lv_proto rescued $::lv_rescued \
                 outcome $::lv_outcome latch $::lv_latch how $::lv_how]
  }
  proc lv_poll {} {
    incr ::lv_polls
    if {$::lv_polls > 60} {
      set ::lv_outcome capped
      catch {set ::libmgr::dlg_done 0}
      return
    }
    if {$::lv_state == 0} {
      if {[winfo exists $::lv_path]} {
        catch {set ::lv_proto [wm protocol $::lv_path WM_DELETE_WINDOW]}
        set ::lv_state 1
        if {$::lv_how eq {wmclose}} {
          # the real gesture: run the close-button script the window carries.
          if {$::lv_proto ne {} && $::lv_proto ne {NONE}} {
            catch {uplevel #0 $::lv_proto}
          }
          # what did it release the wait WITH?  Captured BEFORE any rescue, so
          # the accepting value cannot be mistaken for a cancel.
          if {[info exists ::libmgr::dlg_done]} { set ::lv_latch $::libmgr::dlg_done }
          catch {destroy $::lv_path}
        } else {
          catch {destroy $::lv_path}
        }
      }
      after 60 lv_poll
      return
    }
    # the window is gone. The prompt sets its done flag to -1 just before it
    # waits; if it is STILL -1 then nothing ended the wait, which IS the defect.
    if {$::lv_polls > 10} {
      if {[info exists ::libmgr::dlg_done] && $::libmgr::dlg_done == -1} {
        set ::lv_rescued 1
        catch {set ::libmgr::dlg_done 0}
      }
      set ::lv_outcome gone
      return
    }
    after 60 lv_poll
    return
  }

  set lv3_driven 0
  set lv3_rescues 0
  foreach p $waiters {
    set path [lv_toplevel_of $p]
    if {$path eq {}} continue
    set d [lv_drive $p $path]
    incr lv3_driven
    incr lv3_rescues [dict get $d rescued]
    set short [namespace tail $p]
    check "LV3a $short comes back when its window goes away unanswered, with nothing poked" \
      [expr {[dict get $d rc] == 0 && [dict get $d rescued] == 0 \
             && [dict get $d outcome] eq "gone"}] \
      "(rc=[dict get $d rc] outcome=[dict get $d outcome] had-to-poke-it=[dict get $d rescued] err='[dict get $d res]')"
    check "LV3b $short's close button is wired to a way out on the live window" \
      [expr {[dict get $d proto] ne {} && [dict get $d proto] ne "NONE"}] \
      "(handler='[dict get $d proto]')"
    check "LV3c $short answers a window that went away the way Cancel answers, with no result" \
      [expr {[dict get $d rc] == 0 && [dict get $d res] eq {}}] \
      "(rc=[dict get $d rc] result='[dict get $d res]')"
  }
  check "LV3d every derived prompt was actually driven above, not skipped" \
    [expr {$lv3_driven == [llength $waiters] && $lv3_driven >= 7}] \
    "(driven=$lv3_driven of [llength $waiters])"
  check "LV3e and no prompt in the sweep had to be poked to let go" \
    [expr {$lv3_rescues == 0}] "(pokes=$lv3_rescues)"

  ## =========================================================================
  ## BAND LV4 -- THE TITLE-BAR BUTTON IS ACTUALLY PRESSED, AND WHAT IT ANSWERS
  ## IS CHECKED.
  ##
  ## Band LV3 reads `wm protocol $w WM_DELETE_WINDOW` and then DESTROYS the
  ## window, so it travels the `<Destroy>` path and NEVER RUNS the close-button
  ## script. And LV3b asserts only that the handler string is non-empty. Both
  ## together pass against a one-character regression that wires the title-bar X
  ## to the ACCEPTING value -- the X would then mean OK, so closing the box
  ## without answering would CREATE the cell, which is worse than the hang this
  ## issue is about. Measured: that regression leaves LV1/LV2/LV3 entirely green.
  ##
  ## LV4 drives each derived prompt again with `how` = `wmclose`, which evaluates
  ## the script the window really carries, and asserts the wait was released with
  ## the CANCEL value. 0 is that value by inspection of every prompt's own
  ## accepting arm (`if {$ok == 1}`), which LV4c pins from the product text
  ## rather than from this comment.
  set lv4_driven 0
  set lv4_bad {}
  foreach p $waiters {
    set path [lv_toplevel_of $p]
    if {$path eq {}} continue
    set d [lv_drive $p $path wmclose]
    incr lv4_driven
    set tail [namespace tail $p]
    if {[dict get $d latch] ne 0} {
      lappend lv4_bad "$tail:latch=[dict get $d latch]"
    }
    if {[dict get $d rescued] ne 0} { lappend lv4_bad "$tail:had-to-poke-it" }
  }
  check "LV4a pressing the title-bar close button -- its own script, evaluated, not the window torn down -- releases every derived prompt's wait with the CANCEL value and needs no poke" \
    [expr {[llength $lv4_bad] == 0}] "(bad='$lv4_bad')"
  check "LV4b every derived prompt was driven through the close-button path too, not just the destroy path" \
    [expr {$lv4_driven == [llength $waiters] && $lv4_driven >= 7}] \
    "(driven=$lv4_driven of [llength $waiters])"
  ## LV4c -- 0 IS THE CANCEL VALUE, ASSERTED FROM THE PRODUCT'S OWN TEXT rather
  ## than from LV4a's comment. Every prompt gates its accepting work on
  ## `$ok == 1` / `== 1`, so a latch of 0 cannot be mistaken for acceptance. If a
  ## prompt ever accepts on 0 this row reddens before LV4a silently stops meaning
  ## anything.
  set lv4_accept {}
  foreach p $waiters {
    set body {}
    catch {set body [info body $p]}
    foreach seg [lv_segments $body] {
      if {[regexp {^if[ \t]*\{[^\}]*==[ \t]*0[ \t]*\}} $seg]} {
        lappend lv4_accept [namespace tail $p]
      }
    }
  }
  check "LV4c no derived prompt treats 0 as its accepting answer, so LV4a's CANCEL value cannot drift into meaning OK" \
    [expr {[llength $lv4_accept] == 0}] "(accepts-on-zero='[lsort -unique $lv4_accept]')"
  catch {destroy .libmgr}
}

# --- verdict -----------------------------------------------------------------
# THE DUAL BANNER IS REQUIRED. banner_complete in tests/banner_rule.tcl -- the
# only reader tests/run_regression.tcl uses -- matches a WHOLE-LINE
# "OVERALL: ok" and implements no RESULT spelling at all, so a suite registered
# there printing only the RESULT line scores a counted HARNESS failure however
# many of its own checks pass (issue 1615). RESULT stays LAST because
# summarize_all publishes a case's last RESULT line.
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "OVERALL: notok"
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
