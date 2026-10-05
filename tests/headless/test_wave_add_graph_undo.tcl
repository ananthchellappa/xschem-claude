# tests/headless/test_wave_add_graph_undo.tcl — Graph > Add Graph is inside
# undo and inside the replay log, like every other strip-structure command.
#
# THE DEFECT. `wviewer::add_graph` appended a strip, regenerated, and stopped.
# It called neither `wviewer::push_undo` nor `wviewer::log_action`, while every
# sibling that changes the strip structure calls both. Two user-visible
# consequences, and the first is the worse one:
#
#   * the user presses Add Graph, then `u`. Undo pops the point the PREVIOUS
#     gesture pushed, so it backs out that gesture and leaves the new strip on
#     screen. Undo therefore undid something the user did not ask it to undo,
#     and the thing they did ask about is still there. An operation that is
#     merely "not undoable" is a limitation; one that makes `u` act on the wrong
#     edit is a lie about what was undone.
#   * a session recorded with `--logdir` and replayed through Tools > Replay
#     Action Log comes back WITHOUT the strip, so the strips of the replayed
#     window do not match the strips of the recorded one and every later logged
#     line that names a strip index addresses a different strip.
#
# WHAT IS ASSERTED WHERE, and the split is forced by construction. The DECISION
# — does the command take an undo point, does it emit one replayable line, in
# what order relative to the model write — is pure Tcl model work and is
# asserted on the COUNTED arm under a rig that stubs the three collaborators
# that need Tk or the C core (`switch_ctx`, the capture, `regenerate`). The ACT
# — a real strip really leaving a real canvas when `u` is pressed — needs a
# mapped viewer and is asserted on the DISPLAY arm. So this suite is registered
# in BOTH lists.
#
# BANDS
#   AF*  the FAMILY property, derived from src/wave_viewer.tcl's own call graph:
#        the viewer's Graph menu is enumerated out of `wviewer::build_menubar`
#        and each entry's transitive reach of the two helpers is computed and
#        asserted as a whole MAP, so a new Graph-menu entry cannot arrive
#        without a verdict and no entry's reach can change silently.
#   AG*  behaviour of `wviewer::add_graph` under the model rig, counted arm.
#   AL*  the logged line really replays, counted arm.
#   AD*  the ACT against a mapped viewer, display arm (self-SKIPs with no X).
#
# Run:
#   headless: tests/headless/run_suites.sh --nogui test_wave_add_graph_undo
#   display:  tests/headless/run_suites.sh test_wave_add_graph_undo
# Prints "OVERALL: ok" on success, which is what `banner_complete` in
# tests/banner_rule.tcl requires of a registered case.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
  flush stdout
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
# Evaluate in the CALLER's frame and return a legible sentinel instead of
# raising: a tree with no fix at all can make any of these probes throw, and a
# raise reaching the file-scope catch below costs every remaining row.
proc q {script} {
  if {[catch {uplevel 1 $script} r]} { return "RAISED($r)" }
  return $r
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvaddgraph]
set wvsrc_path [file join $repo src wave_viewer.tcl]

if {[catch {

# ============================================================================
# The call-graph derivation, used by band AF. Both arms.
# ============================================================================
#
# `ag_cmd_word_hits` is `bs_cmd_word_hits`'s shape (tests/headless/
# test_wave_sigbrowser.tcl): the callee has to be a WHOLE word in COMMAND
# POSITION — the start of the line, or butted against an open bracket, a
# semicolon or an open brace — so the
# word appearing inside a string, a `-command [list ...]` value or another
# identifier does not make an edge. Two DECLARED limits, neither re-checked
# here: a call reached through `uplevel`/`eval`/a variable holding the name does
# not join, and a whole-line comment is dropped before continuations are
# joined, so a command continued onto a `#` line loses that line's words. The
# control band below runs this derivation over a source minted in this file, so
# which shapes it admits is re-measured every run instead of described.
proc ag_cmd_word_hits {line bare} {
  set out {}
  set len [string length $line]
  set from 0
  while {$from < $len} {
    if {![regexp -indices -start $from \
          "(?:\[A-Za-z_\]\[A-Za-z0-9_\]*::)*${bare}" $line m]} { break }
    lassign $m a b
    set from [expr {$b + 1}]
    if {$a > 0 && [string match {[A-Za-z0-9_:]} [string index $line [expr {$a - 1}]]]} { continue }
    if {$b + 1 < $len && [string match {[A-Za-z0-9_:]} [string index $line [expr {$b + 1}]]]} { continue }
    set pre [string trimright [string range $line 0 [expr {$a - 1}]]]
    if {$pre ne {} && [lsearch -exact [list \x5b \x3b \x7b] [string index $pre end]] < 0} { continue }
    lappend out [list $a [string range $line $a $b]]
  }
  return $out
}

# The file's own proc population, as `proc <name>` in column 0 — which is how
# every proc in src/wave_viewer.tcl is written.
proc ag_procs {src} {
  set out {}
  foreach line [split $src "\n"] {
    if {[regexp {^proc[ \t]+(\S+)} $line -> nm]} { lappend out $nm }
  }
  return $out
}

# The call graph: {caller -> callees} over the file's OWN procs only. A callee
# is matched by its BARE name, so an unqualified call from inside the namespace
# joins the same edge as a fully qualified one.
proc ag_callgraph {src} {
  set names [ag_procs $src]
  array set bare {}
  foreach nm $names { set bare([namespace tail $nm]) $nm }
  array set edge {}
  foreach nm $names { set edge($nm) {} }
  set cur {}
  foreach line [split $src "\n"] {
    if {[regexp {^proc[ \t]+(\S+)} $line -> nm]} { set cur $nm; continue }
    if {[regexp {^\s*#} $line]} { continue }
    if {$cur eq {}} continue
    foreach b [array names bare] {
      if {[llength [ag_cmd_word_hits $line $b]]} {
        if {[lsearch -exact $edge($cur) $bare($b)] < 0} { lappend edge($cur) $bare($b) }
      }
    }
  }
  set out {}
  foreach nm $names { dict set out $nm $edge($nm) }
  return $out
}

# 1 when `target` is reachable from `start` in the call graph (including
# `start` itself), by breadth-first walk with a visited set, so a cycle
# terminates.
proc ag_reaches {g start target} {
  set seen {}
  set q [list $start]
  while {[llength $q]} {
    set p [lindex $q 0]
    set q [lrange $q 1 end]
    if {[lsearch -exact $seen $p] >= 0} continue
    lappend seen $p
    if {$p eq $target} { return 1 }
    if {[dict exists $g $p]} { foreach c [dict get $g $p] { lappend q $c } }
  }
  return 0
}

# The Graph cascade's `add command` entries, read out of the body of the proc
# that BUILDS the menubar, as {label proc} pairs in menu order. The label and
# the -command are on separate physical lines in that proc, so this carries the
# label forward to the next `-command [list wviewer::...]` it meets. Checkbutton
# entries are deliberately not collected: a checkbutton is a window OPTION, and
# spec waveform_viewer_modes.md keeps window options out of the undo stack.
proc ag_graph_menu {src builder} {
  set inb 0
  set out {}
  set pend {}
  foreach line [split $src "\n"] {
    if {[regexp {^proc[ \t]+(\S+)} $line -> nm]} {
      set inb [expr {$nm eq $builder}]
      continue
    }
    if {!$inb} continue
    if {[regexp {^\s*#} $line]} { continue }
    if {[regexp -- {\$mb\.graph add command -label \{([^\}]*)\}} $line -> lbl]} {
      set pend $lbl
      continue
    }
    if {$pend ne {} && [regexp -- {-command \[list (wviewer::\S+)} $line -> p]} {
      lappend out [list $pend $p]
      set pend {}
    }
  }
  return $out
}

# The proc bound to one Graph-cascade label, or {} — `ag_graph_menu` answers a
# list of {label proc} PAIRS, which is not a dict (a label can contain a space
# and the pair list is not flat), so it is looked up rather than `dict get`.
proc ag_menu_proc {ents lbl} {
  foreach e $ents {
    if {[lindex $e 0] eq $lbl} { return [lindex $e 1] }
  }
  return {}
}

# The verdict map band AF asserts: {label {reaches_push_undo reaches_log_action}}.
proc ag_menu_reach {src builder} {
  set g [ag_callgraph $src]
  set out {}
  foreach e [ag_graph_menu $src $builder] {
    lassign $e lbl p
    lappend out $lbl [list [ag_reaches $g $p wviewer::push_undo] \
                           [ag_reaches $g $p wviewer::log_action]]
  }
  return $out
}

set fp [open $wvsrc_path r]; set wvsrc [read $fp]; close $fp

# ============================================================================
# AF* — the FAMILY property, derived from the file's own text. Both arms.
# ============================================================================
#
# The population is the user's own Graph menu, not a list written here, so the
# NEXT entry someone adds joins it without anybody remembering to. The property
# is each entry's transitive reach of the two helpers, and it is asserted as a
# WHOLE MAP rather than per entry: an added entry, a removed entry, a renamed
# label or a changed reach all redden AF3, which is the only shape that cannot
# go quietly stale.

check_true "AF1 the menubar builder was found in src/wave_viewer.tcl" \
  [expr {[lsearch -exact [ag_procs $wvsrc] wviewer::build_menubar] >= 0}]

set ag_menu [q {ag_graph_menu $wvsrc wviewer::build_menubar}]
# NON-VACUITY: a derivation that found nothing would make AF3 a comparison of
# two empty lists, which passes against anything.
check_true "AF2 the Graph cascade derivation found several command entries" \
  [expr {[llength $ag_menu] >= 8}]
check "AF2 ...and Add Graph is one of them, bound to wviewer::add_graph" \
  [q {ag_menu_proc $ag_menu {Add Graph}}] wviewer::add_graph

# AF3 — THE LEDGER. Every zero here is a statement about the tree, and each one
# has a reason:
#   Add Trace... / Delete... / Axes... are DIALOG OPENERS. They mutate nothing
#     themselves; their OK handlers do, and those are reached through a
#     `-command [list ...]` value, which is not command position, so this
#     derivation cannot follow them. That is the declared limit above, not a
#     verdict about those dialogs.
#   Clear All and Delete All Markers log but take no undo point. That is a
#     SEPARATE pre-existing gap, filed rather than fixed here, and this row is
#     what stops it being forgotten: the day one of them gains an undo point,
#     or a third entry loses one, AF3 says so.
# Add Graph's own pair is the defect this suite closes, and AF3 is the
# instrument that states it: no sentence here needs to name the value, because
# the row recomputes the whole map every run and prints both sides on a miss.
#
# Built with `list` rather than written as a braced literal, so the expected
# value carries Tcl's own canonical string representation of the map and the
# comparison cannot fail on whitespace or on which words needed bracing.
set ag_want [list \
  {Add Graph}           {1 1} \
  {Add Trace...}        {0 0} \
  {Delete...}           {0 0} \
  {Axes...}             {0 0} \
  {Clear All}           {0 1} \
  {Delete All Markers}  {0 1} \
  {Delete Empty Strips} {1 1} \
  {Split Strip}         {1 1}]
check "AF3 the whole Graph-menu reach map, derived from the call graph" \
  [q {ag_menu_reach $wvsrc wviewer::build_menubar}] $ag_want

# AF4 — CONTROL. The same two derivations over a source minted HERE, so what
# this scan admits as an edge and as a menu entry is re-measured every run
# rather than asserted in the comment above. `ag_ctl_b` reaches push_undo only
# through `ag_ctl_c`, so the transitive step is exercised; `ag_ctl_d` names
# push_undo inside a string and log_action inside a `-command [list ...]`
# value, which are the two shapes that must NOT make an edge.
#
# ⚠ MINTED LINE BY LINE AND JOINED, not written as one braced literal, and the
# reason is a Tcl parsing rule that silently destroyed the first revision of
# this band: BACKSLASH-NEWLINE IS SUBSTITUTED INSIDE BRACES. A braced literal
# holding the menu's real two-line spelling therefore arrives as ONE physical
# line, the label and the -command collapse together, and the derivation under
# test is handed a shape the file it scans never contains. Measured: a braced
# `{alpha \<newline>  beta}` answers `llength [split $s \n]` == 1.
#
# The lines are DOUBLE-QUOTED words with every brace BACKSLASH-ESCAPED. The
# escape is not decoration: this whole band lives inside a braced `catch` body,
# where brace matching is purely textual and a quote does not shelter a brace,
# so the open brace that starts a minted proc would otherwise unbalance the
# file. `$` and `[` are escaped because a quoted word does substitute those.
# The two helper procs are minted too: `ag_callgraph` only draws edges to procs
# the scanned source DEFINES, so without them this control would measure the
# reach of two names that are not in its population.
set ag_ctl [join [list \
  "proc wviewer::push_undo \{token\} \{" \
  "  return 1" \
  "\}" \
  "proc wviewer::log_action \{line\} \{" \
  "  return 1" \
  "\}" \
  "proc wviewer::ag_ctl_a \{\} \{" \
  "  wviewer::push_undo x" \
  "  wviewer::log_action y" \
  "\}" \
  "proc wviewer::ag_ctl_b \{\} \{" \
  "  wviewer::ag_ctl_c" \
  "\}" \
  "proc wviewer::ag_ctl_c \{\} \{" \
  "  wviewer::push_undo x" \
  "\}" \
  "proc wviewer::ag_ctl_d \{\} \{" \
  "  set s \"wviewer::push_undo is not called here\"" \
  "  button .b -command \[list wviewer::log_action z\]" \
  "\}" \
  "proc wviewer::build_menubar \{\} \{" \
  "  \$mb.graph add command -label \{Ctl A\}" \
  "    -command \[list wviewer::ag_ctl_a \$token\]" \
  "  \$mb.graph add command -label \{Ctl B\}" \
  "    -command \[list wviewer::ag_ctl_b \$token\]" \
  "  \$mb.graph add command -label \{Ctl D\}" \
  "    -command \[list wviewer::ag_ctl_d \$token\]" \
  "  \$mb.graph add checkbutton -label \{Ctl Opt\}" \
  "    -command \[list wviewer::ag_ctl_a \$token\]" \
  "\}"] "\n"]
# the mint itself is checked, so the control cannot go vacuous on a reflow
check "AF4 the control source really is many physical lines" \
  [q {llength [split $ag_ctl "\n"]}] 30
check "AF4 the control's own proc population was found" \
  [q {llength [ag_procs $ag_ctl]}] 7
check "AF4 control: direct, transitive and non-command-position reach" \
  [q {ag_menu_reach $ag_ctl wviewer::build_menubar}] \
  [list {Ctl A} {1 1} {Ctl B} {1 0} {Ctl D} {0 0}]
check "AF4 control: a checkbutton entry is NOT collected" \
  [q {llength [ag_graph_menu $ag_ctl wviewer::build_menubar]}] 3

# ============================================================================
# The MODEL RIG — counted arm. Three collaborators stand in for the ones that
# need Tk or the C core, and nothing else is replaced: `wviewer::add_graph`,
# `push_undo`, `state_snapshot`, `state_apply`, `history_step`, `set_graphs`,
# `layout_for` and `empty_graph` are the shipped procs.
#
#   switch_ctx                -> 1   (there is no second xschem context here)
#   capture_live_graph_state  -> records the call and returns 1. The real one
#                                reads rect props through `xschem getprop` and
#                                carries a 1:1 rect/model guard that FAILS
#                                SILENTLY with no rects, so leaving it in would
#                                make the rig's capture step unobservable.
#   regenerate                -> records the call and returns 1 (it draws).
#
# Every stub is installed by `rename`, and `ag_rig_off` puts the shipped procs
# back, so a later band and the display arm run against the real ones.
# ============================================================================
set ag_trace {}
proc ag_rig_on {} {
  foreach p {switch_ctx capture_live_graph_state regenerate push_undo log_action} {
    if {[info commands wviewer::__ag_real_$p] eq {}} {
      rename wviewer::$p wviewer::__ag_real_$p
    }
  }
  proc wviewer::switch_ctx {token} { return 1 }
  proc wviewer::capture_live_graph_state {token {skip_markers 0} {skip_ranges 0}} {
    lappend ::ag_trace [list capture $skip_markers $skip_ranges]
    return 1
  }
  proc wviewer::regenerate {token} { lappend ::ag_trace regenerate; return 1 }
  # push_undo and log_action are SPIED, not stubbed: the real push_undo runs, so
  # the undo stack this suite later pops is the product's own.
  proc wviewer::push_undo {token} {
    lappend ::ag_trace [list push_undo \
      [llength [dict get [wviewer::layout_for $token] graphs]]]
    return [wviewer::__ag_real_push_undo $token]
  }
  proc wviewer::log_action {line} { lappend ::ag_trace [list log $line]; return {} }
  return 1
}
proc ag_rig_off {} {
  foreach p {switch_ctx capture_live_graph_state regenerate push_undo log_action} {
    if {[info commands wviewer::__ag_real_$p] ne {}} {
      rename wviewer::$p {}
      rename wviewer::__ag_real_$p wviewer::$p
    }
  }
  return 1
}
# A one-strip model under `tok`, with the rig's trace cleared and no history.
proc ag_reset {tok} {
  set ::ag_trace {}
  dict set ::wviewer::windows $tok [dict create win_path .ag_fake.drw]
  set ::wviewer::target($tok) 0
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  wviewer::clear_history $tok
  return [ag_nstrips $tok]
}
proc ag_nstrips {tok} {
  return [llength [dict get [wviewer::layout_for $tok] graphs]]
}
# The rig's trace, with every entry's verb only — the ORDER is the claim.
proc ag_verbs {} {
  set out {}
  foreach e $::ag_trace { lappend out [lindex $e 0] }
  return $out
}
proc ag_logged {} {
  set out {}
  foreach e $::ag_trace { if {[lindex $e 0] eq {log}} { lappend out [lindex $e 1] } }
  return $out
}

set ag_tok AGTOK
ag_rig_on

# ============================================================================
# AG* — what Add Graph does to the model, the undo stack and the log.
# ============================================================================

# NON-VACUITY: the rig must be driving the SHIPPED add_graph, not something this
# file defined. Its body is the product's, and the rig replaced none of it.
check_true "AG0 the rig drives the shipped wviewer::add_graph" \
  [expr {[info commands wviewer::add_graph] ne {} &&
         [string first {wviewer::empty_graph} [info body wviewer::add_graph]] >= 0}]

check "AG1 the rig starts from one strip and no history" \
  [list [ag_reset $ag_tok] [q {wviewer::history_depth $ag_tok}]] {1 {0 0}}

set ag_r [q {wviewer::add_graph $ag_tok}]
check "AG1 add_graph reports success and appended exactly one strip" \
  [list $ag_r [ag_nstrips $ag_tok]] {1 2}

# THE FIRST HALF OF THE DEFECT.
check "AG2 add_graph pushed exactly ONE undo point" \
  [q {wviewer::history_depth $ag_tok}] {1 0}

# THE SECOND HALF. The payload must be FULLY RESOLVED and carry the token
# EXPLICITLY, like every sibling's line, so a replay does not depend on which
# window is current at replay time.
check "AG3 add_graph logged exactly one line, with an explicit token" \
  [ag_logged] [list "wviewer::add_graph $ag_tok"]

# THE ORDER, which is the shipped bug class the file's own ordering contract
# exists to prevent: a snapshot taken AFTER the append makes `u` restore the
# very strip it was meant to remove, and a log line emitted BEFORE the mutation
# would be in the log of a command that then refused.
check "AG4 capture, then the undo point, then the repaint, then the log line" \
  [ag_verbs] {capture push_undo regenerate log}

# AG5 — and the snapshot is of the PRE-append model. The spy recorded the live
# strip count at the moment push_undo was called; one means the point describes
# the window the user was looking at.
check "AG5 the undo point was taken while the model still had one strip" \
  [q {lindex [lsearch -inline $::ag_trace {push_undo *}] 1}] 1

# AG6 — `u` really removes the strip again, through the product's own
# `wviewer::undo` (what the `u` key is bound to), and `U` puts it back.
check "AG6 u removes the added strip; U brings it back" \
  [list [q {wviewer::undo $ag_tok}] [ag_nstrips $ag_tok] \
        [q {wviewer::redo $ag_tok}] [ag_nstrips $ag_tok]] {1 1 1 2}

# AG7 — the no-op discipline every sibling follows: an unresolvable token
# mutates nothing, pushes no undo point and logs no line.
ag_reset $ag_tok
set ag_bad [q {wviewer::add_graph AG_NO_SUCH_TOKEN}]
check "AG7 an unknown token is refused, with no undo point and no log line" \
  [list $ag_bad [ag_nstrips $ag_tok] [q {wviewer::history_depth $ag_tok}] \
        [llength [ag_logged]]] {0 1 {0 0} 0}

# ============================================================================
# AL* — the logged line REPLAYS. A log entry that replays to nothing is worse
# than no entry at all, because it reads as covered.
# ============================================================================
ag_reset $ag_tok
wviewer::add_graph $ag_tok
set ag_line [lindex [ag_logged] 0]
check "AL1 one line was captured to replay" [llength [ag_logged]] 1
# Undo back to the recorded starting point, then run the line the log holds.
wviewer::undo $ag_tok
check "AL1 undone back to the one-strip starting model" [ag_nstrips $ag_tok] 1
set ::ag_trace {}
set ag_rep [q {eval $ag_line}]
check "AL2 the logged line replays to the SAME effect" \
  [list $ag_rep [ag_nstrips $ag_tok]] {1 2}
# A replay is N undo units, not one (test_replay_door_1619 row R2 pins that for
# the door as a whole) — so the replayed line pushes its own point, and it logs
# again, which is exactly what makes a replayed session re-recordable.
check "AL2 ...and the replayed line is itself undoable and logged" \
  [list [q {lindex [wviewer::history_depth $ag_tok] 0}] [ag_logged]] \
  [list 1 [list "wviewer::add_graph $ag_tok"]]

ag_rig_off
check "AL3 the rig put all five shipped procs back" \
  [q {set n 0
      foreach p {switch_ctx capture_live_graph_state regenerate push_undo log_action} {
        if {[info commands wviewer::__ag_real_$p] eq {}} { incr n }
      }
      set n}] 5
catch {dict unset ::wviewer::windows $ag_tok}
catch {unset ::wviewer::target($ag_tok)}
catch {wviewer::clear_history $ag_tok}

# ============================================================================
# AD* — THE ACT, against a mapped viewer. Display arm only: the model rig above
# cannot show that a strip really leaves a real canvas.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  proc ad_viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
  set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
  set f [open [file join $scratch library.defs] w]
  puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
  puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
  puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
  close $f
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "AD0 wviewer::open returns 1" [q {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![ad_viewer_ready $vtop]} {
    puts "SKIPPED: AD* viewer legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

    proc ad_rects {} { return [q {xschem get graph_rects}] }

    wviewer::set_graphs $tok [list [wviewer::empty_graph]]
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    wviewer::clear_history $tok
    set ::ad_log {}
    rename wviewer::log_action wviewer::__ad_real_log
    proc wviewer::log_action {line} { lappend ::ad_log $line; return {} }

    check "AD1 one strip on the canvas to start with" [ad_rects] 1

    check "AD2 Add Graph puts a second RECT on the canvas" \
      [list [q {wviewer::add_graph $tok}] [ad_rects]] {1 2}
    check "AD2 ...and it is one undo point and one log line" \
      [list [q {wviewer::history_depth $tok}] $::ad_log] \
      [list {1 0} [list "wviewer::add_graph $tok"]]

    # THE USER'S GESTURE: press `u`. The strip must leave the CANVAS, not only
    # the model — a model-only undo with no regenerate is the shape that leaves
    # the rect drawn and is invisible to the counted arm's rig.
    check "AD3 u removes the strip from the canvas as well as the model" \
      [list [q {wviewer::undo $tok}] [ad_rects] \
            [q {llength [dict get [wviewer::layout_for $tok] graphs]}]] {1 1 1}
    check "AD3 ...and U puts the rect back" \
      [list [q {wviewer::redo $tok}] [ad_rects]] {1 2}

    # THE REPLAY, against the real viewer: undo to the recorded start, run the
    # line the log holds, and the strip is rebuilt on the canvas.
    set ::ad_log {}
    q {wviewer::undo $tok}
    check "AD4 back to one rect before the replay" [ad_rects] 1
    set ad_line "wviewer::add_graph $tok"
    check "AD4 the logged line rebuilds the strip on the canvas" \
      [list [q {eval $ad_line}] [ad_rects]] {1 2}

    # The menu entry the user actually presses is wired to this proc, asserted
    # against the LIVE Tk menu rather than against the source text band AF read
    # — AF3's derivation and this row are independent instruments over the same
    # claim, which is the point of having both.
    set ad_m $vtop.wvmenubar.graph
    check_true "AD5 the live viewer Graph menu exists at $ad_m" \
      [winfo exists $ad_m]
    if {[winfo exists $ad_m]} {
      set ad_idx [q {$ad_m index {Add Graph}}]
      check "AD5 the live Graph menu's Add Graph entry calls wviewer::add_graph" \
        [q {$ad_m entrycget $ad_idx -command}] [list wviewer::add_graph $tok]
    }

    rename wviewer::log_action {}
    rename wviewer::__ad_real_log wviewer::log_action
    catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: AD* viewer legs (no DISPLAY)"
}

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_add_graph_undo: $npass passed, $fail failed"
# `banner_complete` in tests/banner_rule.tcl is the only Tcl reader of a
# registered case's output and implements no `RESULT:` spelling at all, so this
# line is what makes the suite registerable. RESULT: stays LAST, because
# `summarize_all` publishes a case's last RESULT: line.
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
