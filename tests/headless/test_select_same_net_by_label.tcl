# Logical (net-name) connected select -- engine, subcommand, bound chord, logging.
# doc/claude/specs/select_same_net_by_label.md
#
# `xschem select_same_net [x y] [add]` selects every wire segment carrying the
# same NET NAME as the seed -- including segments that touch nothing but share a
# wire-label, and are therefore one node in the netlist -- plus the net-labels /
# ports that name it. The geometric counterpart is `select_grow_connected`, which
# walks copper only; T2 below pins the difference.
#
# Uses select_object()/draw_selection() -> needs a real X window, like
# test_dblclick_connected_grow.tcl. Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_select_same_net_by_label.tcl
#
# RED-first: on a build without select_same_net the command throws (caught -> FAIL)
# so every check reds.

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- select_same_net test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} {incr ::fails}
}
proc nsel_type {t} { set c 0; foreach e [xschem selection] { if {[lindex $e 0] eq $t} {incr c} }; return $c }
proc samenet {args} { eval xschem select_same_net $args }

# --- fixture -----------------------------------------------------------------
# Three horizontal segments that touch NOTHING:
#   A  labelled NET1   B  labelled NET1   C  labelled NET2
# A and B are one node in the netlist ONLY because they share the label NET1.
# Each wire runs 100 units to the right of its label's pin, so its midpoint is
# ($px+50,$py).  Returns a dict name -> {x y} of those midpoints.
proc build_labelled { } {
  xschem clear force
  set mid [dict create]
  foreach {nm lab yy} {a NET1 0  b NET1 200  c NET2 400} {
    xschem instance devices/lab_wire 0 $yy 0 0 [list name=l$nm lab=$lab]
    set pc [xschem instance_pin_coord l$nm name p]
    set px [lindex $pc 1]; set py [lindex $pc 2]
    xschem wire $px $py [expr {$px + 100}] $py
    dict set mid $nm [list [expr {$px + 50}] $py]
  }
  xschem unselect_all
  xschem redraw
  update idletasks
  return $mid
}

# ---------------------------------------------------------------------------
# T1 -- the whole point: a click on segment A also selects segment B, which it
# does not touch, because both carry the label NET1. Both NET1 labels come along;
# the NET2 group stays out.
# ---------------------------------------------------------------------------
set mid [build_labelled]
lassign [dict get $mid a] ax ay
set n [samenet $ax $ay]
check "T1 selects both NET1 segments"      [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
check "T1 selects both NET1 labels"        [expr {[nsel_type instance] == 2}] "sel=[xschem selection]"
check "T1 returns the object count (4)"    [expr {$n == 4}] "n=$n"
# and nothing from NET2: 2 wires + 2 labels is the whole selection
check "T1 leaves the NET2 group alone"     [expr {[llength [xschem selection]] == 4}] \
  "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T2 -- the contrast that justifies the feature: the GEOMETRIC grow on the same
# seed reaches only segment A, because nothing touches it.
# ---------------------------------------------------------------------------
set mid [build_labelled]
lassign [dict get $mid a] ax ay
xschem select_grow_connected $ax $ay
check "T2 geometric grow stays on 1 segment" [expr {[nsel_type wire] == 1}] "sel=[xschem selection]"
check "T2 geometric grow selects no label"   [expr {[nsel_type instance] == 0}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T3 -- seeding from the LABEL instead of the wire gives the same net.
# ---------------------------------------------------------------------------
set mid [build_labelled]
set pc [xschem instance_pin_coord la name p]
samenet [lindex $pc 1] [lindex $pc 2]
check "T3 label seed -> both NET1 segments" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
check "T3 label seed -> both NET1 labels"   [expr {[nsel_type instance] == 2}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T4 -- replace vs add. A second call on a different net REPLACES by default and
# GROWS with the `add` keyword.
# ---------------------------------------------------------------------------
set mid [build_labelled]
lassign [dict get $mid a] ax ay
lassign [dict get $mid c] cx cy
samenet $ax $ay
samenet $cx $cy
check "T4 second call replaces (1 wire, 1 label)" \
  [expr {[nsel_type wire] == 1 && [nsel_type instance] == 1}] "sel=[xschem selection]"
samenet $ax $ay add
check "T4 'add' grows to both nets (3 wires)"   [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
check "T4 'add' grows to both nets (3 labels)"  [expr {[nsel_type instance] == 3}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T5 -- the COORDLESS form seeds from the current selection, and takes EVERY net
# in it (here: two nets from two clicked segments).
# ---------------------------------------------------------------------------
set mid [build_labelled]
lassign [dict get $mid a] ax ay
lassign [dict get $mid c] cx cy
xschem select_at $ax $ay
xschem select_at $cx $cy add
check "T5 seeded with 2 wires" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
samenet
check "T5 coordless expands both nets (3 wires)"  [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
check "T5 coordless expands both nets (3 labels)" [expr {[nsel_type instance] == 3}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T6 -- UNLABELLED nets must not collapse together. Two disjoint bare segments get
# distinct synthetic node names (#netN), so a click on one selects only that one.
# ---------------------------------------------------------------------------
xschem clear force
xschem wire 0 0 100 0
xschem wire 0 200 100 200
xschem unselect_all
xschem redraw
update idletasks
samenet 50 0
check "T6 unlabelled nets stay separate" [expr {[nsel_type wire] == 1}] "sel=[xschem selection]"
# ...but a genuinely connected unlabelled net comes along whole
xschem clear force
xschem wire   0   0 100   0
xschem wire 100   0 100 100
xschem wire 100 100 200 100
xschem unselect_all
xschem redraw
update idletasks
samenet 50 0
check "T6 connected unlabelled net selected whole (3 wires)" [expr {[nsel_type wire] == 3}] \
  "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T7 -- no net under the pointer: report, change nothing, return 0.
# ---------------------------------------------------------------------------
set mid [build_labelled]
lassign [dict get $mid a] ax ay
samenet $ax $ay
set before [xschem selection]
set n [samenet 5000 5000]
check "T7 empty click returns 0"              [expr {$n == 0}] "n=$n"
check "T7 empty click leaves the selection"   [expr {[xschem selection] eq $before}] \
  "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T8 -- the REAL bound chord. `xschem bind button 1 ctrl+alt+shift canvas ...` is
# what src/cadence_style_rc installs; drive an actual Ctrl+Alt+Shift+Button1 press
# through the dispatcher (state 13 = Shift|Control|Mod1) and prove it reaches the
# same engine. Also proves the chord is REMAPPABLE (this is the remap call).
# ---------------------------------------------------------------------------
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  list [expr {int(($sx + $xo)/$z)}] [expr {int(($sy + $yo)/$z)}]
}
proc chord_click {sx sy {st 13}} {
  global WIN
  lassign [screen $sx $sy] SX SY
  xschem callback $WIN 4 $SX $SY 0 1 0 $st     ;# ButtonPress   1
  xschem callback $WIN 5 $SX $SY 0 1 0 $st     ;# ButtonRelease 1
  update idletasks
}
xschem bind button 1 ctrl+alt+shift canvas select.same_net_by_label
set mid [build_labelled]
lassign [dict get $mid a] ax ay
xschem unselect_all
chord_click $ax $ay
check "T8 Ctrl+Alt+Shift+LMB -> both NET1 segments" [expr {[nsel_type wire] == 2}] \
  "sel=[xschem selection]"
check "T8 Ctrl+Alt+Shift+LMB -> both NET1 labels"   [expr {[nsel_type instance] == 2}] \
  "sel=[xschem selection]"
# the release must NOT collapse the multi-selection back to the clicked segment
# (the cadence deselect-others branch is guarded on a bare Button1Mask state)
set cc_save [set ::cadence_compat]
set ::cadence_compat 1
xschem unselect_all
chord_click $ax $ay
check "T8 selection survives the release under cadence_compat" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
set ::cadence_compat $cc_save
# un-binding works too -> the chord falls through and selects just one segment
xschem unbind button 1 ctrl+alt+shift canvas
xschem unselect_all
chord_click $ax $ay
check "T8 after unbind the chord no longer expands the net" \
  [expr {[nsel_type wire] <= 1}] "sel=[xschem selection]"
xschem bind button 1 ctrl+alt+shift canvas select.same_net_by_label

# ---------------------------------------------------------------------------
# T9 -- ACTION-LOG + CIW coverage (issue 0071 core-self-log). Every use -- the
# script subcommand AND the bound chord, which calls the core directly from
# callback.c -- must write exactly one replayable `xschem select_same_net ...`
# line plus one `#= select_same_net: ...` outcome comment. The same outcome text
# is what ciw_echo puts in the CIW pane (one sink, one call site).
# Needs the action log open -> registered in full_audit.sh logdir_tests (--logdir).
# ---------------------------------------------------------------------------
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  check "T9 action-log open (skipped: run with --logdir to exercise)" 1 "no log file"
} else {
  proc logcount {pat} {
    if {[catch {open [xschem get actionlog_filename] r} fd]} { return -1 }
    set body [read $fd]; close $fd
    set n 0
    foreach line [split $body \n] { if {[string match $pat $line]} { incr n } }
    return $n
  }
  set mid [build_labelled]
  lassign [dict get $mid a] ax ay
  set b_cmd [logcount "xschem select_same_net*"]
  set b_out [logcount "#= select_same_net:*"]
  samenet $ax $ay
  check "T9a subcommand logs exactly one command line" \
    [expr {[logcount "xschem select_same_net*"] == $b_cmd + 1}] "before=$b_cmd"
  check "T9a subcommand logs exactly one outcome line" \
    [expr {[logcount "#= select_same_net:*"] == $b_out + 1}] "before=$b_out"
  set b_cmd [logcount "xschem select_same_net*"]
  set b_out [logcount "#= select_same_net:*"]
  xschem unselect_all
  chord_click $ax $ay
  check "T9b bound chord logs exactly one command line (no drop, no double)" \
    [expr {[logcount "xschem select_same_net*"] == $b_cmd + 1}] "before=$b_cmd"
  check "T9b bound chord logs exactly one outcome line" \
    [expr {[logcount "#= select_same_net:*"] == $b_out + 1}] "before=$b_out"
  # the outcome line names the net and the counts
  if {![catch {open [xschem get actionlog_filename] r} fd]} {
    set body [read $fd]; close $fd
    check "T9c outcome line names the net and the counts" \
      [expr {[string match "*#= select_same_net: net NET1 -- 2 wire segments, 2 label/pins selected*" $body]}] \
      "log tail=[string range $body end-200 end]"
  }
  # a no-op click writes NO replayable command (no phantom), only the report
  set b_cmd [logcount "xschem select_same_net*"]
  samenet 5000 5000
  check "T9d empty click logs no replayable command" \
    [expr {[logcount "xschem select_same_net*"] == $b_cmd}] "before=$b_cmd"
}

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

# ---------------------------------------------------------------------------
puts ""
if {$::fails == 0} {
  puts "OVERALL: ok  (all checks passed)"
  puts "RESULT: ALL PASS"
} else {
  puts "OVERALL: FAIL  ($::fails failed)"
  puts "RESULT: $::fails FAILED"
}
