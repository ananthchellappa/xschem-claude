## File: ciw.tcl
##
## CIW (Command Interpreter Window, after Virtuoso's) -- a standalone toplevel
## with a live view of the action log plus a command entry evaluated by the
## xschem Tcl interpreter (starts at one line; dragging the sash grows it).
## Spec: doc/claude/specs/action_logging.md section 3.
##
## Sourced from xschem.tcl at startup; ciw_create is called automatically for
## interactive sessions (spec decision 8). The C action-log sink (log_action()
## in util.c) mirrors every line it writes to Xschem.log into the upper pane
## by calling ciw_echo. Commands typed in the lower entry are echoed here
## (input tag), recorded in Xschem.log via `xschem log_action -noecho`, and
## evaluated at global scope; their result or error is shown in the pane only,
## never written to the file, so the file stays source-able (decision 7).

# =============================================================================
# xschem::notify -- THE ONE NOTIFICATION CHANNEL (issue 0650, rulings R-0653-a
# .. R-0653-d, doc/claude/issues/0650-*.md and 0653-*.md)
# =============================================================================
# MEASURED 2026-08-23 on the user's own configuration: with the CIW closed, a
# gate-off netlist reached ZERO visible sinks. `.statusbar.12` was {} before AND
# after the notice, `.statusbar.1` was unchanged, no popup appeared, and the only
# surviving trace was one `#! ` line in a log file nobody was reading. That is
# issue 0648's report from the outside -- "I ticked the box, re-ran, and still
# get no OP info" -- with no mention of any message, because there was none.
#
# ⚠ 0650's AND 0653's OWN MECHANISM SENTENCE IS FALSE, AND IT CHANGES THE FIX.
# 0650's sink table says ciw_echo "No-ops silently when shut
# (src/ciw.tcl:450)"; 0653 says "The CIW is a closable toplevel. Closed ->
# silent no-op." Both are wrong. `wm protocol .ciw WM_DELETE_WINDOW
# {wm withdraw .ciw}` (in ciw_create below) means a close WITHDRAWS: `.ciw` and
# `.ciw.l.t` still EXIST, `winfo ismapped .ciw` is 0, and ciw_echo happily writes
# into the invisible widget (measured: the pane text GREW). A fallback whose
# condition is `winfo exists` is therefore dead code in EXACTLY the user's
# situation, and it passes review. The predicate is `winfo ismapped` --
# xschem::notify_ciw_visible below, pinned by PS17 in
# tests/headless/test_ase_log_seam_0207.tcl.
#
# WHY THIS FILE (decision D1, ladder rung L2). ciw.tcl already owns two of the
# four sinks (ciw_echo, and ciw_exec -- the entry field a printed remedy is
# pasted into), it is already in the src/Makefile.in install list, and it is
# sourced unconditionally in every mode including --nogui. A new src/notify.tcl
# would force src/Makefile.in + ./configure + a rebuild on an otherwise pure-Tcl
# step, and issue 0424 is the recorded startup SEGFAULT from getting that
# ceremony wrong. REJECTED for the same reason: src/ase.tcl (the channel must
# not live inside its first consumer).
#
# ⚠ CONSEQUENCE OF LIVING HERE: this file is sourced at src/xschem.tcl:14854,
# AFTER ase.tcl (:14802), ase_window.tcl (:14804) and wave_viewer.tcl (:14806).
# A SOURCE-TIME notify call from any of those files would fail. Runtime calls are
# fine, which is all any consumer makes. (No Tcl home would help an xschemrc
# either -- the rc is read before all of these; see the note at xschem.tcl:14795.)
#
# ⚠ AND THAT CONSEQUENCE HAD A SHARPER EDGE THAN THIS PARAGRAPH ADMITTED
# (issue 0658): if THIS FILE fails to load, every consumer above loses the
# channel entirely -- the durable log line included, which before 0650 was
# inline in ase::echo and had no cross-file dependency at all. src/xschem.tcl
# now defines a deliberately degraded BOOTSTRAP channel before :14796 (and
# CATCHES the source at :14854, which used to be bare and SEGFAULTED startup),
# so a dead ciw.tcl costs the visible sinks and nothing else. The durable-log
# writer itself lives there too, as xschem::notify_log, and sink 2 below CALLS
# it: one builder, two consumers (invariant I1).
#
# ⚠ DO NOT TEE INSIDE ciw_echo. It has ~190 direct call sites (wave_viewer 129,
# xschem.tcl 35, ciw.tcl 13, ase.tcl 11, alt2_toggle_view 5, property_form 3,
# cmdmode 2, calculator 1, action_registry 1) and it is also the sink the C
# action-log mirror calls for lines ALREADY in the file. Teeing there would route
# every one of them to the statusbar and DOUBLE every asserted notice count
# (test_ase_locked_wire_pick_0160:175 and test_sod_pick_no_select_0204:138/295
# assert `llength $::notices == 1`). Add a sink; do not reroute.

namespace eval xschem {
  ## the last notice, as a dict {tag msg line short menu command sinks}. THE
  ## HEADLESS WITNESS: `sinks` lists only the sinks that ACTUALLY succeeded, so
  ## "the statusbar was skipped" is a value rather than an absence of evidence.
  ## Deliberately left UNSET until the first notice (the tests read
  ## `info exists ::xschem::notify_last`).
  variable notify_last
  ## the generalised R-0653-c suppression latch: dict keyed on {subject state}.
  variable notify_latch [dict create]
}

# R-0653-a: `ciw` (the shipped default) or `popup` (opt-in). `set_ne` so a user
# rc that set it BEFORE this file was sourced still wins, and it is read at CALL
# time (invariant I5) so setting it from the CIW entry field takes effect on the
# very next notice with no restart.
set_ne notify_style {ciw}

# Is the CIW pane actually IN FRONT OF THE USER? Not `winfo exists` -- see the
# refutation above. Under --nogui `winfo` itself is undefined; under --nolog
# ciw_create is never called (xschem.tcl:16705), so `.ciw` does not exist.
proc xschem::notify_ciw_visible {} {
  if {![llength [info commands winfo]]} { return 0 }
  if {![winfo exists .ciw]} { return 0 }
  if {[catch {winfo ismapped .ciw} m]} { return 0 }
  return [expr {$m ? 1 : 0}]
}

# THE SHORT-FORM BUDGET, one builder, two consumers (invariant I1: the sink and
# the test that proves the budget).
#
# ⚠ `.statusbar.12` CLIPS SILENTLY. Measured twice on this box at
# `wm geometry . 1000x800` with a live mouse readout in `.statusbar.1`: the
# widget is allotted 199px and first clips at char 30, or 314px and first clips
# at char 42, depending on what else is in the bar. Tk warns about NOTHING. 28 is
# the floor of the two measurements. This is issue 0639's defect class (an
# unbudgeted line into a fixed field) in a field an order of magnitude smaller;
# the wall itself is recorded as issue 0654.
#
# An explicit -short wins when it fits. Newlines and tabs are collapsed to
# spaces: a Tk label renders an embedded newline as a box glyph, not a break.
proc xschem::notify_short {short msg} {
  set s [expr {$short ne {} ? $short : $msg}]
  set s [string map [list "\n" { } "\r" { } "\t" { }] $s]
  if {[string length $s] <= 28} { return $s }
  return "[string range $s 0 24]..."
}

# SINK 3, the can't-miss fallback: the drawing window's shared red status field.
#
# ⚠ ADDRESSED AS `[xschem get top_path].statusbar.12`, NEVER BARE. Both C writers
# prefix xctx->top_path (hilight.c:2201 writes *BUSY* here; hilight.c:2305 CLEARS
# it to {} unconditionally at the end of propagate_logic(), so a parked notice is
# wiped by any digital propagation -- recorded in issue 0654). A bare
# `.statusbar.12` posts to the MAIN window while the user works in `.x1`;
# src/xschem.tcl:14146 already ships that bug for `.statusbar.7`. `xschem get
# topwindow` returns "." and would build "..statusbar.12"; top_path is "" for the
# main window, which is exactly what the C side prefixes.
#
# Returns 1 only when the text really landed, so notify's `sinks` cannot claim a
# sink that was not there.
proc xschem::notify_statusbar {short tag} {
  if {![llength [info commands winfo]]} { return 0 }
  if {[catch {xschem get top_path} tp]} { return 0 }
  set w "$tp.statusbar.12"
  if {![winfo exists $w]} { return 0 }
  if {[catch {$w configure -text $short}]} { return 0 }
  return 1
}

# SINK 4, opt-in (::notify_style popup): ONE reusable, NON-BLOCKING toplevel that
# APPENDS and raises.
#
# ⚠ alert_ (src/xschem.tcl:11954) IS THE WRONG PRECEDENT. It uses a FIXED
# `.alert` path and `tkwait window .alert`. ase::op_cards_capture emits up to SIX
# notices inside ase::netlist inside Netlist-and-Run, so a modal would STALL THE
# RUN and the second notice would raise `window name .alert already exists`. The
# user asked for "dismissed with OK button or ESC button" -- never for blocking.
proc xschem::notify_popup {line tag} {
  if {![llength [info commands winfo]]} { return 0 }
  if {[catch {
    if {![winfo exists .xschem_notify]} {
      toplevel .xschem_notify
      wm title .xschem_notify {xschem notices}
      text .xschem_notify.t -width 76 -height 8 -wrap word -state disabled \
        -yscrollcommand {.xschem_notify.y set}
      scrollbar .xschem_notify.y -command {.xschem_notify.t yview}
      .xschem_notify.t tag configure error -foreground red
      button .xschem_notify.ok -text OK -command {destroy .xschem_notify}
      pack .xschem_notify.ok -side bottom -pady 4
      pack .xschem_notify.y -side right -fill y
      pack .xschem_notify.t -side top -fill both -expand yes
      bind .xschem_notify <Escape> {destroy .xschem_notify}
      wm protocol .xschem_notify WM_DELETE_WINDOW {destroy .xschem_notify}
    } else {
      catch {raise .xschem_notify}
    }
    .xschem_notify.t configure -state normal
    .xschem_notify.t insert end "$line\n" $tag
    .xschem_notify.t configure -state disabled
    .xschem_notify.t see end
  }]} { return 0 }
  return 1
}

# --- R-0653-c: the generalised suppression latch -----------------------------
# "Suppress an identical notice while the underlying state is unchanged; re-arm
# when it changes." 0648's latch (ase::op_cards_nudge_ok) was keyed on the design
# cellview; the ruling says GENERALISE it, do not write a second one, so the
# STORAGE lives here and ase::op_cards_nudge_{ok,rearm,reset} became thin
# wrappers over subject `opcards` -- keeping their names, their `::ase_op_card_nudge`
# off switch and `op_cards_nudge_reset` as the test seam.
#
# Keyed on {subject state}, not on subject alone: a per-subject key would let
# cellview A's nudge permanently eat cellview B's (F19n in test_ase_final).

# 1 iff this (subject, state) may speak NOW -- and if so the turn is CONSUMED.
proc xschem::notify_latch_ok {subject {state {}}} {
  variable notify_latch
  set k [list $subject $state]
  if {[dict exists $notify_latch $k]} { return 0 }
  dict set notify_latch $k 1
  return 1
}

# Give exactly ONE (subject, state) its turn back. Idempotent, never raises, and
# it is NOT notify_latch_reset -- an unconditional clear is 0636's
# three-identical-lines-per-session defect.
proc xschem::notify_latch_rearm {subject {state {}}} {
  variable notify_latch
  catch { dict unset notify_latch [list $subject $state] }
  return
}

# Forget every state held for ONE subject. Subject-scoped deliberately: a reset
# that freed every subject would let one subsystem's re-arm unsilence another's.
proc xschem::notify_latch_reset {subject} {
  variable notify_latch
  foreach k [dict keys $notify_latch] {
    if {[lindex $k 0] eq $subject} { dict unset notify_latch $k }
  }
  return
}

# The witness. Called on every notice that was not suppressed.
proc xschem::notify_record {tag msg line short menu command sinks} {
  variable notify_last
  set notify_last [dict create tag $tag msg $msg line $line short $short \
                               menu $menu command $command sinks $sinks]
  return
}

# --- THE CHANNEL --------------------------------------------------------------
#
#   xschem::notify <msg> ?-tag {}|error? ?-short S? ?-menu M? ?-command C?
#                        ?-once SUBJECT? ?-state KEY?
#
# Returns 1 when the notice was delivered, 0 when the latch suppressed it.
#
# THE FIRST TWO SINKS ARE ase::echo's BODY, MOVED VERBATIM, and that is
# load-bearing in four separate ways (all four were measured, all four have rows):
#   * the pane half runs FIRST and UNCONDITIONALLY, so an EMPTY message still
#     echoes a blank line (the tests that capture ASE notices rename ::ciw_echo,
#     and ase.tcl's own comment says the blank line is a contract);
#   * an empty message logs NOTHING -- `xschem log_action -result` with a missing
#     value fell through the dispatcher's argc gates and wrote the literal line
#     `-result` into Xschem.log, aborting a replay `source`;
#   * the trailing-backslash pad goes on the LOGGED copy ONLY (a `#= foo\` line
#     continues onto the next one and swallows it on replay). The pane copy stays
#     byte-identical to the argument;
#   * ONE notify produces EXACTLY ONE ::ciw_echo call. A short form AND a long
#     form to the pane would redden test_ase_locked_wire_pick_0160:175 and
#     test_sod_pick_no_select_0204:138/295 from a distance.
#
# R-0653-d: -menu and -command are DISTINCT FIELDS, not prose baked into the
# message. The rendered line carries both (the user reads one sentence) while the
# witness keeps them separable, so a test can EXECUTE the command without parsing
# the sentence -- which is the whole point, because `ciw_exec` runs
# `uplevel #0 $cmd` and the printed string IS the contract.
#
# SUPPRESSION IS TOTAL, the log included. That contradicts 0650's sink table
# ("log: always") and is deliberate (decision D7): it is byte-identical to
# shipped behaviour -- op_cards_capture consults the latch BEFORE echoing
# anything at all -- and the alternative would make `grep` on Xschem.log disagree
# with what the user was told.
proc xschem::notify {msg args} {
  ## THE FIRST STATEMENT, and it must stay first (issues 0664/0665). `sinks` was
  ## a LOCAL and died with any raise, so xschem::notify_safe had no way to know
  ## what this call had already delivered and re-made the whole notice -- a
  ## second durable line, and a "notices are LOG-ONLY from here on" claim
  ## asserted while every sink below was alive. The record is
  ## ::xschem::notify_progress, a NAMESPACE variable declared in src/xschem.tcl
  ## (never here: the degraded state it serves is the one where this file is
  ## absent), and `sinks` is now nothing but its snapshot -- ONE account of one
  ## fact, invariant I1.
  ##
  ## ⚠ NOT DOWN WHERE `set sinks {}` USED TO SIT, after option parsing and after
  ## the notify_latch_ok gate. A raise in EITHER of those would then leave the
  ## PREVIOUS call's record standing, and notify_safe -- reading `log` from a
  ## notice that succeeded minutes ago -- would skip a durable write that never
  ## happened. That is a G1 regression wearing a 0665 fix (test_ase_core NT23).
  set sinks [xschem::notify_mark_reset]
  set tag {} ; set short {} ; set menu {} ; set command {}
  set once {} ; set state {}
  foreach {o v} $args {
    switch -exact -- $o {
      -tag     { set tag $v }
      -short   { set short $v }
      -menu    { set menu $v }
      -command { set command $v }
      -once    { set once $v }
      -state   { set state $v }
      default  { return -code error "xschem::notify: unknown option '$o'" }
    }
  }
  if {$once ne {}} {
    if {![xschem::notify_latch_ok $once $state]} { return 0 }
  }

  ## the rendered sentence: message, then the remedy, in that order
  set line $msg
  if {$msg ne {}} {
    if {$menu ne {}}    { append line " Fix: $menu." }
    if {$command ne {}} { append line " CIW command: $command" }
  }

  ## SINK 1 -- the CIW pane. First, unconditional, catch'd, and resolved by NAME
  ## at call time (that is the rename-able spy point every ASE suite stubs).
  if {[info commands ::ciw_echo] ne {}} {
    if {![catch {::ciw_echo $line $tag}]} { set sinks [xschem::notify_mark ciw] }
  }

  if {$msg eq {}} {
    xschem::notify_record $tag $msg $line {} $menu $command $sinks
    return 1
  }

  ## SINK 2 -- the action log FILE.
  ##
  ## ⚠ THE BODY NO LONGER LIVES HERE (issue 0658). It is `xschem::notify_log`,
  ## defined in src/xschem.tcl BEFORE this file is sourced, because the degraded
  ## bootstrap channel there must write the SAME durable line and invariant I1
  ## forbids two builders of it: the trimright, the trailing-backslash pad, the
  ## empty-message guard and 0657's actionlog_filename honesty gate would
  ## otherwise exist twice, in two files, drifting silently. ONE builder, TWO
  ## consumers -- this sink and the bootstrap. Everything the old comment here
  ## recorded (the `#= `/`#! ` comment form, the replay landmines, why a closed
  ## log cannot be detected from the return of `xschem log_action`) is on
  ## notify_log itself.
  if {[xschem::notify_log $line $tag]} { set sinks [xschem::notify_mark log] }

  ## SINK 3/4 -- style-selected, and the style is read HERE, at call time (I5).
  ##
  ## ⚠ A WHITESPACE-ONLY MESSAGE STOPS HERE. ase::echo returned TWICE: once on
  ## an empty argument and again AFTER `string trimright`. Moving the body here
  ## kept the first return and narrowed the second to the log sink, so a message
  ## that renders as nothing still reached sinks 3/4 -- and `configure -text` is
  ## a REPLACE, not an append. Measured on :99: a parked notice, then
  ## `xschem::notify "\n\n"`, left `.statusbar.12` reading '  '. The same hole
  ## blanks a live *BUSY* (hilight.c:2201). Restore the second return for the Tk
  ## sinks, which is what the moved body did. (Write-up pass, issue 0656.)
  set style ciw
  if {[info exists ::notify_style]} { set style $::notify_style }
  set shortform [xschem::notify_short $short $msg]
  if {[string trim $line] eq {}} {
    xschem::notify_record $tag $msg $line $shortform $menu $command $sinks
    return 1
  }
  if {$style eq {popup}} {
    if {[xschem::notify_popup $line $tag]} { set sinks [xschem::notify_mark popup] }
  } elseif {![xschem::notify_ciw_visible]} {
    ## the CIW is not in front of the user -- withdrawn, iconified, never
    ## created (--nolog), or absent (--nogui). Fall back to the drawing window's
    ## status field. ⚠ THAT IS THE HONEST SCOPE OF "cannot be invisible": those
    ## four states, and NOT occlusion (issue 0659). When the CIW IS mapped the
    ## statusbar is left ALONE: it is shared with *BUSY* (hilight.c:2201) and
    ## must not become ASE's private field.
    ##
    ## ⚠ STILL OPEN, and NOT fixed here: `winfo ismapped` is 1 for a CIW that
    ## is open but STACKED BEHIND the design window, so that ordinary
    ## arrangement still reaches zero visible sinks (issue 0659); the short form
    ## carries no remedy and the field is last-writer-wins (issue 0660).
    if {[xschem::notify_statusbar $shortform $tag]} { set sinks [xschem::notify_mark statusbar] }
  }

  xschem::notify_record $tag $msg $line $shortform $menu $command $sinks
  return 1
}

## Command history state (Up/Down in the entry). hist_pos == llength(history)
## means "on the live line"; the draft typed there is stashed in hist_pending
## by the first Up and restored when Down walks past the newest entry.
set ::ciw_history {}
set ::ciw_hist_pos 0
set ::ciw_hist_pending {}

## Tab-completion: the `xschem` subcommand vocabulary, loaded lazily from the
## build-generated xschem_subcommands.txt (see doc/claude/specs/ciw_autocomplete.md). Empty
## until the first Tab, and stays empty (gracefully) if the file is absent, in
## which case only command/var/path completion work.
set ::ciw_subcommands {}

## Build (or re-show) the CIW. The two panes sit in a vertical panedwindow so
## the split is user-adjustable by dragging the sash (spec decision 9); the
## entry pane starts at its natural one-line height and stays fixed on window
## resize (the log pane takes the extra space).
proc ciw_create {} {
  if {[winfo exists .ciw]} {
    ## a bare `raise` is a no-op under Weston/WSLg (issue 0054): use the shared
    ## withdraw+deiconify+activate helper that the Library Manager uses, then put
    ## the keyboard focus on the command entry so the user can type immediately.
    raise_activate_toplevel .ciw
    catch {focus -force .ciw.c.e}
    return
  }
  toplevel .ciw
  ## title shows the full path of the action-log file being displayed (e.g.
  ## /tmp/Xschem.log.38), so the user always knows which file the pane mirrors.
  set _log [xschem get actionlog_filename]
  if {$_log ne {}} {
    wm title .ciw "xschem CIW - [file normalize $_log]"
  } else {
    wm title .ciw {xschem CIW}
  }
  ## closing the CIW must not exit xschem: withdraw, keeping the accumulated
  ## log so a later ciw_create just re-shows it
  wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}

  ## fat raised sash: the default is a near-invisible few-pixel strip that is
  ## both undiscoverable and a poor drag target (8px was still too thin on a
  ## HiDPI display -- user feedback). Darker background makes the sash band
  ## read as a control, and the cursor signals draggability on hover.
  panedwindow .ciw.p -orient vertical -sashwidth 14 -sashrelief raised \
    -background gray55 -sashcursor sb_v_double_arrow

  # upper pane: read-only log display, fed by ciw_echo
  frame .ciw.l
  text .ciw.l.t -width 80 -height 14 -font {Monospace 10} -state disabled \
    -yscrollcommand {.ciw.l.yscroll set}
  scrollbar .ciw.l.yscroll -command {.ciw.l.t yview}
  .ciw.l.t tag configure input  -foreground blue
  .ciw.l.t tag configure result -foreground gray30
  .ciw.l.t tag configure error  -foreground red
  # `note` is a result the user must NOTICE without it being an error: today the
  # only producer is the co-simulation resolver telling the user that the scope
  # recorded by the netlister is not the one its signals actually live in
  # (RULING 5f-1, doc/claude/specs/mixed_signal_signal_browser.md). Without this
  # line the tag is undefined and Tk renders the notice exactly like any other
  # result line, i.e. the visibility the ruling asserts does not exist.
  .ciw.l.t tag configure note   -foreground {dark orange}
  pack .ciw.l.yscroll -side right -fill y
  pack .ciw.l.t -side top -fill both -expand yes

  # lower pane: command entry. A text widget (not an entry) so its height
  # actually FOLLOWS the sash: dragging the sash up gives a taller entry area
  # where long commands wrap visibly. It still starts at one line (decision 9)
  # and Return executes instead of inserting a newline ('break' stops the
  # class binding that would).
  frame .ciw.c
  text .ciw.c.e -height 1 -font {Monospace 10} -wrap char -undo 1
  bind .ciw.c.e <Return>   {ciw_exec; break}
  bind .ciw.c.e <KP_Enter> {ciw_exec; break}
  ## shell-style line editing. 'break' everywhere: the Text class bindings
  ## would otherwise also delete one char / move the cursor a display line.
  bind .ciw.c.e <Control-BackSpace> {ciw_delete_word; break}
  bind .ciw.c.e <Up>   {ciw_hist_move -1; break}
  bind .ciw.c.e <Down> {ciw_hist_move  1; break}
  ## Tab completes the token under the cursor (readline/bash style). 'break' is
  ## load-bearing: without it Tk also runs the default <Tab> binding and moves
  ## keyboard focus out of the entry.
  bind .ciw.c.e <Tab> {ciw_complete; break}
  pack .ciw.c.e -side top -fill both -expand yes -padx 3 -pady 5

  .ciw.p add .ciw.l .ciw.c
  ## -stretch needs Tk >= 8.5; without it the default (last pane stretches)
  ## merely makes resizes grow the entry pane instead of the log pane.
  ## -minsize keeps either pane from being collapsed to nothing by the sash.
  catch {
    .ciw.p paneconfigure .ciw.l -stretch always -minsize 60
    .ciw.p paneconfigure .ciw.c -stretch never  -minsize 34
  }
  pack .ciw.p -side top -fill both -expand yes

  ## Window-activation logging (doc/claude/specs/window_numbering.md): the CIW is
  ## window 1. Fire on FocusIn to the toplevel or any of its descendants; the '+'
  ## keeps any other binding and notify_window_active dedupes the repeats.
  bind .ciw <FocusIn> {+notify_window_active 1 CIW}
}

## Append one line to the CIW log pane. 'tag' selects the style: {} for
## mirrored action-log lines, input/result/error for CIW command traffic.
## Called from C (the log_action mirror) and from ciw_exec; safe no-op when
## the CIW does not exist.
proc ciw_echo {line {tag {}}} {
  # headless-safe: under --nogui there is no Tk, so `winfo` itself is undefined
  if {![llength [info commands winfo]] || ![winfo exists .ciw.l.t]} return
  .ciw.l.t configure -state normal
  .ciw.l.t insert end $line\n $tag
  .ciw.l.t configure -state disabled
  .ciw.l.t see end
}

## Cadence-style window-activation log: print "window N activated: <cell>" to the CIW
## when a window becomes the active one. The CIW is window 1, the Library Manager is
## window 2, and editor contexts are 3,4,5,... For an editor window the caller omits
## 'name' and it is filled in from the active schematic's cell. Deduped on
## ::last_active_window so repeated FocusIn events (and WSLg focus thrash) log only on an
## actual change of the active window. Safe no-op when the CIW is closed (ciw_echo
## no-ops). Spec: doc/claude/specs/window_numbering.md.
proc notify_window_active {num {name {}}} {
  global last_active_window
  if {[info exists last_active_window] && $last_active_window eq $num} return
  set last_active_window $num
  if {$name eq {}} { catch {set name [file tail [xschem get schname]]} }
  ciw_echo "window $num activated: $name" result
}

## Run the command in the entry: echo it (visually distinct), evaluate at
## global scope, show the result or error in the pane, and record it in the
## action log file. Recording happens AFTER evaluation so the file stays
## source-able: a command that errored is written as a '# failed:' comment
## (replaying it would abort the source), a successful one is written raw.
## Delete the word before the cursor, shell-style: skip any whitespace
## immediately behind the cursor first, then eat to the start of the word.
proc ciw_delete_word {} {
  set w .ciw.c.e
  set i [$w index insert]
  while {[$w compare $i > 1.0] && [string is space -strict [$w get "$i -1c"]]} {
    set i [$w index "$i -1c"]
  }
  if {[$w compare $i > 1.0]} { set i [$w index "$i -1c wordstart"] }
  $w delete $i insert
}

## Walk the command history (dir -1 = older, +1 = newer) into the entry.
## History-always semantics (terminal/Virtuoso style): Up recalls even when
## the cursor sits inside a tall wrapped command.
proc ciw_hist_move {dir} {
  set w .ciw.c.e
  set n [llength $::ciw_history]
  if {!$n} return
  set pos [expr {$::ciw_hist_pos + $dir}]
  if {$pos < 0 || $pos > $n} return
  if {$::ciw_hist_pos == $n} { set ::ciw_hist_pending [$w get 1.0 end-1c] }
  set ::ciw_hist_pos $pos
  $w delete 1.0 end
  if {$pos == $n} { $w insert end $::ciw_hist_pending } \
  else           { $w insert end [lindex $::ciw_history $pos] }
}

## Route a captured `puts` (its raw arg list) to the CIW log pane: a stdout write (`puts STRING`
## or `puts stdout STRING`) uses the `result` tag, a `puts stderr STRING` uses the `error` (red)
## tag, and any OTHER channel (a file/socket) or a malformed call is delegated VERBATIM to the real
## puts (saved as ::ciw_saved_puts while capture is active). `-nonewline` is accepted and ignored
## for the console channels (the log pane is line-oriented), but preserved when delegating. Only
## installed for the dynamic extent of a CIW command -- see ciw_exec. Spec: doc/claude/specs/ciw_puts_capture.md.
proc ciw_capture_puts {argl} {
  set a $argl
  if {[lindex $a 0] eq "-nonewline"} {set a [lrange $a 1 end]}
  set n [llength $a]
  ## Bug B (issue 0129): mirror console puts to the action-log FILE too -- but BUFFER it in
  ## ::ciw_out_pending instead of writing now, so ciw_exec can emit it AFTER the command line
  ## (0129 ordering follow-up: output must FOLLOW its command in the transcript, not precede it).
  ## ciw_echo still updates the pane immediately. Only the console forms are buffered; a channel
  ## puts (else) writes to a file, not the console, and must NOT be recorded.
  if {$n == 1} {
    ciw_echo [lindex $a 0] result
    lappend ::ciw_out_pending result [lindex $a 0]
  } elseif {$n == 2 && [lindex $a 0] eq "stdout"} {
    ciw_echo [lindex $a 1] result
    lappend ::ciw_out_pending result [lindex $a 1]
  } elseif {$n == 2 && [lindex $a 0] eq "stderr"} {
    ciw_echo [lindex $a 1] error
    lappend ::ciw_out_pending error [lindex $a 1]
  } else {
    eval [linsert $argl 0 ::ciw_saved_puts]   ;# 8.4-safe form of: ::ciw_saved_puts {*}$argl
  }
  return {}   ;# the real puts returns "" -- keep that (else `lappend`'s value would become the
              ;# result of a command ending in puts, minting a spurious "#= " result line -- 0129)
}

## A command TYPED here by a human is an interactive open, so a bare
## `xschem load <file>` should behave like File>Open: reuse the current window
## only if it is a pristine empty untitled scratch, otherwise open a new window
## (doc/claude/specs/load_window_routing.md). The scheduler routes only when the
## `-gui` flag is present, so inject it. Menu/keybinding opens already pass -gui;
## scripts, --script files and action-log replays do NOT go through here, so they
## keep the in-place behavior the regression suite relies on.
## Only a plain `xschem load ...` is rewritten -- never load_new_window /
## load_backup (no space after "load"), and never when the user already gave a
## routing/scripted flag. The regsub touches only the "xschem load" prefix, so
## braces / spaces / backslashes in the file path are untouched.
proc ciw_interactive_load {cmd} {
  if {[regexp {^xschem[ \t]+load[ \t]} $cmd] &&
      ![regexp -- {[ \t](-gui|-inplace|-window|-nodraw|-keep_symbols|-nofullzoom|-noundoreset|-nosymbols)([ \t]|$)} $cmd]} {
    regsub {^(xschem[ \t]+load)[ \t]} $cmd {\1 -gui } cmd
  }
  return $cmd
}

proc ciw_exec {} {
  set cmd [string trim [.ciw.c.e get 1.0 end-1c]]
  if {$cmd eq {}} return
  set cmd [ciw_interactive_load $cmd]
  ## record into history (failed commands too, bash-style; consecutive
  ## duplicates collapse) and reset the cursor to the live line
  if {$cmd ne [lindex $::ciw_history end]} { lappend ::ciw_history $cmd }
  set ::ciw_hist_pos [llength $::ciw_history]
  set ::ciw_hist_pending {}
  .ciw.c.e delete 1.0 end
  ciw_echo "> $cmd" input
  ## Capture the command's stdout/stderr `puts` into the log pane, scoped to exactly this command
  ## (spec: ciw_puts_capture.md). Redefine puts around the eval and restore it right after; the
  ## rename pair is balanced and the catch keeps an error from skipping the restore. puts still
  ## returns "" so the result-echo below does not print captured text a second time.
  ## Dedup + echo-suppress (self-log-at-core): reset the flag, and while the command runs tell a
  ## core self-log to write the FILE but skip the CIW mirror (we already echoed the input line).
  xschem log_action -reset
  xschem log_action -suppressecho 1
  set ::ciw_out_pending {} ;# 0129: captured console puts buffers here; emitted after the command
  rename ::puts ::ciw_saved_puts
  proc ::puts {args} {ciw_capture_puts $args}
  ## Bug A (issue 0129): a command that ends the process (exit/quit) never returns to
  ## the post-eval log-write at the tail of this proc, so record it NOW. The action-log
  ## stream is line-buffered, so the newline flushes it to disk before Tcl's exit runs.
  ## This also sets the cmd_logged flag, so the tail below will not duplicate the line.
  if {[regexp {^(exit|quit)(\s|$)} $cmd]} { xschem log_action -noecho $cmd }
  set code [catch {uplevel #0 $cmd} res]
  rename ::puts {}
  rename ::ciw_saved_puts ::puts
  xschem log_action -suppressecho 0
  if {$code} {
    ciw_echo $res error
  } elseif {$res ne {}} {
    ciw_echo $res result
  }
  ciw_log_outcome $code $cmd $res
}

## Emit the action-log transcript for a just-run CIW command in console order (issue 0129):
## the COMMAND line first, then its captured console output (::ciw_out_pending, filled by
## ciw_capture_puts), then its result -- so the file reads top-to-bottom like the pane. The
## command line is written only HERE (post-eval), so a FAILED command stays a "# failed:"
## comment rather than a live line that would abort a replay `source`. The `-emitted` guard
## skips our command line when the core already self-logged it (self-log-at-core dedup); the
## buffered output then correctly trails that core line too. Split out of ciw_exec so the
## ordering is unit-testable without the Tk CIW widget.
proc ciw_log_outcome {code cmd res} {
  if {$code} {
    if {![xschem log_action -emitted]} { xschem log_action -noecho "# failed: $cmd" }
    foreach {kind txt} $::ciw_out_pending { xschem log_action -$kind $txt }
    xschem log_action -error $res   ;# D1 (issue 0070): error output as a source-able comment
  } else {
    if {![xschem log_action -emitted]} { xschem log_action -noecho $cmd }
    foreach {kind txt} $::ciw_out_pending { xschem log_action -$kind $txt }
    if {$res ne {}} { xschem log_action -result $res }
  }
  set ::ciw_out_pending {}
}

## --- Tab completion ---------------------------------------------------------
## Readline/bash-style completion of the token under the cursor. Spec:
## doc/claude/specs/ciw_autocomplete.md.

## Load the xschem-subcommand vocabulary once, on the first Tab. The file is
## build-generated from scheduler.c (see the Makefile rule) and shipped to
## XSHAREDIR alongside ciw.tcl. A missing file is not an error: the list simply
## stays empty and subcommand completion is a no-op while the other sources work.
proc ciw_load_subcommands {} {
  if {[llength $::ciw_subcommands]} return
  global XSCHEM_SHAREDIR
  set f [file join $XSCHEM_SHAREDIR xschem_subcommands.txt]
  if {[catch {open $f r} fh]} return
  set ::ciw_subcommands [split [string trim [read $fh]] \n]
  close $fh
}

## Longest common prefix of a non-empty list of strings (case-sensitive). Used
## to advance an ambiguous token as far as is unambiguous before listing.
proc ciw_lcp {strings} {
  set pfx [lindex $strings 0]
  foreach s [lrange $strings 1 end] {
    while {![string equal -length [string length $pfx] $pfx $s]} {
      set pfx [string range $pfx 0 end-1]
      if {$pfx eq {}} return {}
    }
  }
  return $pfx
}

## Filesystem candidates for a path token (the fallback source: arguments to
## load/save/instance/... without having to know which subcommands take a path).
## Directories come back with a trailing '/' so a single match descends instead
## of terminating the token. glob expands a leading '~'.
proc ciw_path_candidates {tok} {
  set out {}
  foreach p [glob -nocomplain ${tok}*] {
    if {[file isdirectory $p]} { append p / }
    lappend out $p
  }
  return $out
}

## Candidate list for the token at position 'idx' (tok), given all tokens to the
## left of the cursor. Sources, most-specific first: $variable, xschem
## subcommand (2nd token), Tcl command/proc (1st token), else file path.
proc ciw_candidates {toks idx tok} {
  if {[string index $tok 0] eq "\$"} {
    set pfx [string range $tok 1 end]
    set out {}
    foreach v [info globals ${pfx}*] { lappend out "\$$v" }
    return $out
  }
  if {$idx == 1 && [lindex $toks 0] eq {xschem}} {
    ciw_load_subcommands
    set out {}
    foreach c $::ciw_subcommands {
      if {[string match ${tok}* $c]} { lappend out $c }
    }
    return $out
  }
  if {$idx == 0} {
    return [lsort -unique [info commands ${tok}*]]
  }
  return [ciw_path_candidates $tok]
}

## Replace the current token (its last [string length tok] chars before the
## cursor) with 'full'. A unique, non-directory completion (addspace) gets a
## trailing space so the next token can be typed straight away; a directory
## (ends in '/') and longest-common-prefix insertions never do.
proc ciw_insert_completion {tok full addspace} {
  set w .ciw.c.e
  set n [string length $tok]
  if {$n} { $w delete "insert - $n chars" insert }
  $w insert insert $full
  if {$addspace && [string index $full end] ne "/"} { $w insert insert { } }
}

## The <Tab> handler. The current token is the trailing run of non-whitespace
## before the cursor (empty when the cursor follows a space or the line is
## empty -- then Tab lists everything valid in that position).
proc ciw_complete {} {
  set line [.ciw.c.e get 1.0 insert]
  set toks [regexp -all -inline {\S+} $line]
  if {$line eq {} || [regexp {\s$} $line]} {
    set tok {}
    set idx [llength $toks]
  } else {
    set tok [lindex $toks end]
    set idx [expr {[llength $toks] - 1}]
  }
  set cands [ciw_candidates $toks $idx $tok]
  if {![llength $cands]} { bell; return }
  if {[llength $cands] == 1} {
    ciw_insert_completion $tok [lindex $cands 0] 1
  } else {
    set lcp [ciw_lcp $cands]
    if {[string length $lcp] > [string length $tok]} {
      ciw_insert_completion $tok $lcp 0
    } else {
      ciw_echo [join [lsort $cands] {  }] result
    }
  }
}
