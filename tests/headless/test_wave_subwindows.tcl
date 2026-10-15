# tests/headless/test_wave_subwindows.tcl -- SUBWINDOWS in the ASE Waveform
# Viewer (contract: doc/claude/specs/waveform_viewer_subwindows.md)
#
# The feature: one viewer TAB tiles 1..N subwindows in a grid
# (cols = ceil(sqrt(n)), rows = ceil(n/cols), row-major, last row partial and
# left-aligned), each with its own strips. Exactly one is the TARGET; clicking
# inside a subwindow makes it the target and the target is framed while there
# are two or more. A subwindow is a TAG (`sw`) on the graphs of the flat model
# list, kept contiguous; a one-subwindow tab carries no tag at all.
#
# WHAT IS ASSERTED
#   SWP*  PURE, both arms -- the model layer on literal arguments: sw_grid,
#         sw_cell (exact outer bounds), sw_rects (== band_geometry with one
#         subwindow), sw_normalize (canonical untagged form, regroup, the
#         untagged-joins-above rule, idempotence), sw_runs/sw_range/sw_index,
#         sw_frame masks, sw_add, sw_close_indices, graph_props' two tokens,
#         and the reuse rules (a trace move / a split never takes an empty
#         strip from another subwindow).
#   SWN*  no-window guards, both arms.
#   SWG*  DISPLAY -- the real window: the grid on the canvas (graphbb), the
#         rect tokens, click-to-target and the in-place frame move, New/Close
#         SubWin through the menu and keys, plotting into the target
#         subwindow (single, multi, New Strip, the Add Graph item), paste into
#         the target, a cross-subwindow trace move, the reorder clamp, Shared X
#         / pan / wheel zoom confined to a subwindow, undo, tab switch and
#         serialisation.
#
# SABOTAGE TABLE -- each one-token edit was MEASURED red on the named rows, then
# reverted to green (2026-10-15):
#   S1 sw_grid `$c * $c < $n` -> `$c * $c < $n - 1` (sqrt rounded down)
#        -> SWP1, SWP2 (x2), SWP3 adjacency; display adds SWG2 (x2), SWG9 re-tile
#   S2 sw_normalize: return the tagged list in input order (no regroup)
#        -> SWP6 regroup, tag, joins-above and joins-below legs
#   S3 close_subwin: drop the `set target(...)` write
#        -> SWG9 "the target stays on ITS strip (4 -> 0)" ONLY. The target sits
#           at a non-last strip on purpose: target_clamp hides a stale index
#           that was the last strip, which is how a first version passed S3.
#   S4 regenerate: graphbb/rects from band_geometry over the whole viewport
#        -> SWG2 (x2), SWG8 (x2), SWG9 re-tile
#   S5 move_marker: skip the swframe rewrite  -> SWG5 frame leg ONLY
#   S6 plot_signals: drop the `+ $swf` plan translation
#        -> SWG6 (all six), SWG7, SWG8, SWG9, then the band aborts
#
# NOT asserted: PIXELS. That the frame looks right is eyeball-only (a `look`
# debt); what IS asserted is the token that draw.c paints from.
#
# Standalone repro from the repo ROOT (armed spelling):
#   tests/headless/run_suites.sh test_wave_subwindows
#   tests/headless/run_suites.sh --nogui test_wave_subwindows

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

set no_recent_files 1
set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvsubwin]

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

set ::arm display
if {[catch {set fd [open /proc/self/cmdline rb]; set cl [read $fd]; close $fd}]} { set cl {} }
if {[string first "--nogui" [string map {\x00 { }} $cl]] >= 0} { set ::arm nogui }

# literal strips: G name ?sw?
proc G {nm {sw {}}} {
  set g [dict create traces [list [dict create expr $nm name $nm vec $nm color 4]] \
           logx 0 logy 0 x1 {} x2 {} y1 {} y2 {} nm $nm]
  if {$sw ne {}} { dict set g sw $sw }
  return $g
}
proc E {{sw {}}} {
  set g [wviewer::empty_graph]
  if {$sw ne {}} { dict set g sw $sw }
  return $g
}
proc names {gs} { lmap g $gs { wviewer::dget $g nm - } }
proc tags {gs} { lmap g $gs { wviewer::dget $g sw - } }

if {[catch {

# ============================================================================
# SWP* -- PURE
# ============================================================================
check "SWP1 grid for n=1..7 (2 side by side, 3 two rows, 4 2x2, 5+ assumption)" \
  [lmap n {1 2 3 4 5 6 7} {pcall {wviewer::sw_grid $n}}] \
  {{1 1} {2 1} {2 2} {2 2} {3 2} {3 2} {3 3}}
check "SWP1 a bad n reads as one" [pcall {wviewer::sw_grid 0}] {1 1}

check "SWP2 n=2: side by side, full height" \
  [list [pcall {wviewer::sw_cell 0 2 0 0 100 100}] [pcall {wviewer::sw_cell 1 2 0 0 100 100}]] \
  {{0 0 50 100} {50 0 100 100}}
check "SWP2 n=3: two rows, the third cell bottom-LEFT, a quarter empty" \
  [lmap k {0 1 2} {pcall {wviewer::sw_cell $k 3 0 0 100 100}}] \
  {{0 0 50 50} {50 0 100 50} {0 50 50 100}}
check "SWP2 n=5: 3x2, last row partial and left-aligned" \
  [lmap k {3 4} {pcall {wviewer::sw_cell $k 5 0 0 90 100}}] \
  {{0 50 30 100} {30 50 60 100}}
check "SWP3 one cell IS the viewport bit for bit (fractional bounds)" \
  [pcall {wviewer::sw_cell 0 1 -0.1 -0.7 0.3 0.2}] {-0.1 -0.7 0.3 0.2}
check "SWP3 adjacent cells share one boundary expression (no gap)" \
  [expr {[lindex [pcall {wviewer::sw_cell 0 2 -0.1 0 0.3 1}] 2] == \
         [lindex [pcall {wviewer::sw_cell 1 2 -0.1 0 0.3 1}] 0]}] 1

set gs1 [list [G a] [G b] [G c]]
set rs1 [pcall {wviewer::sw_rects $gs1 -0.1 -0.7 0.3 0.2}]
check "SWP4 one subwindow: sw_rects == band_geometry, strip for strip" \
  $rs1 [lmap i {0 1 2} {wviewer::band_geometry $i 3 -0.1 -0.7 0.3 0.2}]
set gs3 [list [G a 1] [G b 1] [G c 2] [G d 3]]
check "SWP5 three subwindows (2,1,1 strips): strips cut within their cells" \
  [pcall {wviewer::sw_rects $gs3 0 0 100 100}] \
  {{0 0 50 25} {0 25 50 50} {50 0 100 50} {0 50 50 100}}

check "SWP6 an untagged list is returned unchanged (byte identity)" \
  [expr {[pcall {wviewer::sw_normalize $gs1}] eq $gs1}] 1
check "SWP6 a lone tag collapses to the untagged canonical form" \
  [tags [pcall {wviewer::sw_normalize [list [G a 4] [G b 4]]}]] {- -}
check "SWP6 a NON-contiguous list is regrouped stably (first appearance)" \
  [names [pcall {wviewer::sw_normalize [list [G a 1] [G b 2] [G c 1] [G d 2]]}]] {a c b d}
check "SWP6 ...and every strip carries its tag" \
  [tags [pcall {wviewer::sw_normalize [list [G a 1] [G b 2] [G c 1] [G d 2]]}]] {1 1 2 2}
check "SWP6 an untagged strip joins the subwindow ABOVE it" \
  [tags [pcall {wviewer::sw_normalize [list [G a 1] [G b 2] [G n] [G c 3]]}]] {1 2 2 3}
check "SWP6 ...a leading untagged strip the one BELOW it" \
  [tags [pcall {wviewer::sw_normalize [list [G n] [G a 2] [G c 3]]}]] {2 2 3}
set nn [pcall {wviewer::sw_normalize [list [G a 1] [G b 2] [G c 1] [G d 2]]}]
check "SWP6 idempotent" [expr {[pcall {wviewer::sw_normalize $nn}] eq $nn}] 1
check "SWP6 non-dict sentinels ride through untouched" \
  [pcall {wviewer::sw_normalize [list X [G a] Y]}] [list X [G a] Y]
check "SWP6 the empty list" [pcall {wviewer::sw_normalize {}}] {}

check "SWP7 runs" [pcall {wviewer::sw_runs $gs3}] {{0 1} {2 2} {3 3}}
check "SWP7 runs of an untagged list are one" [pcall {wviewer::sw_runs $gs1}] {{0 2}}
check "SWP7 runs of nothing" [pcall {wviewer::sw_runs {}}] {}
check "SWP7 count" [list [pcall {wviewer::sw_count $gs3}] [pcall {wviewer::sw_count {}}]] {3 1}
check "SWP7 range of strip 1 / 2 / out-of-range clamps" \
  [list [pcall {wviewer::sw_range $gs3 1}] [pcall {wviewer::sw_range $gs3 2}] \
        [pcall {wviewer::sw_range $gs3 99}] [pcall {wviewer::sw_range {} 0}]] \
  {{0 1} {2 2} {3 3} {0 -1}}
check "SWP7 index" [lmap i {0 1 2 3} {pcall {wviewer::sw_index $gs3 $i}}] {0 0 1 2}

set gsf [list [G a 1] [G b 2] [G c 2] [G d 2]]
check "SWP8 frame masks of a 3-strip target subwindow (L|R, +top, +bottom)" \
  [lmap i {0 1 2 3} {pcall {wviewer::sw_frame $gsf $i 2}}] {0 7 3 11}
check "SWP8 a one-strip target subwindow is framed on all four edges" \
  [lmap i {0 1 2 3} {pcall {wviewer::sw_frame $gsf $i 0}}] {15 0 0 0}
check "SWP8 ONE subwindow: no frame anywhere" \
  [lmap i {0 1 2} {pcall {wviewer::sw_frame $gs1 $i 1}}] {0 0 0}

lassign [pcall {wviewer::sw_add $gs1}] ga gai
check "SWP9 New SubWin on an untagged tab: the old strips become subwindow 1" \
  [tags $ga] {1 1 1 2}
check "SWP9 ...the new strip is appended (no index moves) and empty" \
  [list $gai [wviewer::graph_is_empty [lindex $ga 3]]] {3 1}
check "SWP9 the next id is one above the largest" \
  [tags [lindex [pcall {wviewer::sw_add $gs3}] 0]] {1 1 2 3 4}

check "SWP10 closing the ONLY subwindow removes nothing" \
  [pcall {wviewer::sw_close_indices $gs1 1}] {}
check "SWP10 closing a subwindow names its whole contiguous range" \
  [pcall {wviewer::sw_close_indices $gsf 3}] {1 2 3}

check "SWP11 sw_props: nothing at all for one subwindow (no frame, no group)" \
  [pcall {wviewer::sw_props 0 {}}] {}
check "SWP11 ...a frame and a group as two whole token lines" \
  [pcall {wviewer::sw_props 7 2}] "swframe=7\nxgroup=2\n"
check "SWP11 graph_props keeps its three formals (row WD4 of test_calc_wave_dest)" \
  [pcall {info args wviewer::graph_props}] {G active grid}

# the reuse rules never reach across a subwindow boundary
set gr [list [G a 1] [G b 1] [E 2] [G c 2]]
check "SWP12 a trace move does not take the empty strip of another subwindow" \
  [pcall {wviewer::reuse_strip_for_trace_move $gr 1}] -1
check "SWP12 ...but takes one in its own" \
  [pcall {wviewer::reuse_strip_for_trace_move $gr 3}] 2
set gsp [list [dict create traces [list [dict create expr a vec a color 4] \
                                        [dict create expr b vec b color 5]] sw 1] \
              [E 2]]
check "SWP12 a split never relocates an empty strip out of another subwindow" \
  [dict get [pcall {wviewer::plan_split $gsp 0}] take] {}
check "SWP12 sw_same" \
  [list [pcall {wviewer::sw_same $gr 0 1}] [pcall {wviewer::sw_same $gr 1 2}] \
        [pcall {wviewer::sw_same $gr 0 9}]] {1 0 0}

# ============================================================================
# SWN* -- no-window guards, both arms
# ============================================================================
check "SWN1 new_subwin with no viewer answers {} without throwing" \
  [pcall {wviewer::new_subwin nosuchtoken}] {}
check "SWN1 close_subwin likewise" [pcall {wviewer::close_subwin nosuchtoken}] {}
check "SWN1 the _at wrappers likewise" \
  [list [pcall {wviewer::new_subwin_at .nosuch}] [pcall {wviewer::close_subwin_at .nosuch}]] {{} {}}

# ============================================================================
# SWG* -- the real window. Self-SKIPs without a usable DISPLAY.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }
  proc send_key {w ev done} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w]} {
        focus -force [winfo toplevel $w]
        focus -force $w
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
        if {[winfo exists $w] && [focus -displayof $w] eq $w} {
          event generate $w $ev
          update
          if {[uplevel 1 [list expr $done]]} { return 1 }
        }
      }
      after 50
    }
    puts "  send_key: $ev delivery to $w never confirmed"
    return 0
  }
  proc lay {} { dict get [wviewer::layout_for $::tok] graphs }
  proc ltags {} { tags [lay] }
  proc trx {gi} { lmap t [wviewer::dget [lindex [lay] $gi] traces {}] {wviewer::dget $t expr {}} }
  proc rprop {gi k} {
    xschem new_schematic switch $::vdrw
    return [pcall {xschem getprop rect 2 $gi $k}]
  }
  # centre pixel of strip gi, from the canvas' own bands
  proc mid {gi} {
    lassign [lindex [wviewer::strip_bands_px $::vdrw] $gi] x1 y1 x2 y2
    return [list [expr {int(($x1 + $x2) / 2)}] [expr {int(($y1 + $y2) / 2)}]]
  }

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "SWG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: SWG* GUI legs (viewer canvas never mapped)"
  } else {
  set ::sw_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::sw_log $line ; wviewer::__real_log_action $line }
  set ::sw_echo {}
  rename wviewer::echo wviewer::__real_echo
  proc wviewer::echo {msg {tag {}}} { lappend ::sw_echo $msg ; wviewer::__real_echo $msg $tag }

  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvsub.raw dc vsweep 0 1.0 0.1}
  foreach v {a1 a2 a3 b1 b2 c1 c2 p1 p2} { pcall {xschem raw add $v "vsweep 1 +"} }
  wviewer::set_plot_mode single $tok
  wviewer::set_plot_dest append $tok

  # ---- SWG1: one subwindow is the shipped viewer --------------------------
  wviewer::plot_signals $tok {a1}
  wviewer::add_graph $tok
  wviewer::set_target_strip 1 $tok
  wviewer::plot_signals $tok {a2}
  check "SWG1 a fresh tab is one untagged subwindow" [ltags] {- -}
  check "SWG1 no rect carries swframe or xgroup" \
    [list [rprop 0 swframe] [rprop 1 swframe] [rprop 0 xgroup]] {{} {} {}}
  set bb1 [wviewer::strip_bands_px $vdrw]
  check "SWG1 two strips stacked full width (one column)" \
    [expr {[lindex $bb1 0 0] == [lindex $bb1 1 0] && [lindex $bb1 0 2] == [lindex $bb1 1 2]
           && [lindex $bb1 0 3] <= [lindex $bb1 1 1] + 1}] 1

  # ---- SWG2: New SubWin through the menu entry ----------------------------
  set gm $vtop.wvmenubar.graph
  set ix [pcall {$gm index {New SubWin}}]
  check_true "SWG2 Graph > New SubWin exists" [string is integer -strict $ix]
  check "SWG2 ...with its accelerator" [pcall {$gm entrycget $ix -accelerator}] Ctrl+Shift+N
  set ::sw_log {}
  pcall {$gm invoke $ix}
  check "SWG2 two subwindows, the new one with one empty strip" [ltags] {1 1 2}
  check "SWG2 the new subwindow is the target" [wviewer::target_index $tok] 2
  check "SWG2 one replayable line" $::sw_log [list [list wviewer::new_subwin $tok]]
  set bb2 [wviewer::strip_bands_px $vdrw]
  check "SWG2 side by side: subwindow 2 starts where subwindow 1 ends, same top" \
    [list [expr {abs([lindex $bb2 2 0] - [lindex $bb2 0 2]) < 1.5}] \
          [expr {abs([lindex $bb2 2 1] - [lindex $bb2 0 1]) < 1.5}]] {1 1}
  check "SWG2 ...and it is full height (its one strip spans both of the other's)" \
    [expr {abs([lindex $bb2 2 3] - [lindex $bb2 1 3]) < 1.5}] 1

  # ---- SWG3: the rect tokens ------------------------------------------------
  check "SWG3 every strip names its subwindow (xgroup)" \
    [lmap i {0 1 2} {rprop $i xgroup}] {1 1 2}
  check "SWG3 only the target subwindow is framed (all four edges: one strip)" \
    [lmap i {0 1 2} {rprop $i swframe}] {{} {} 15}
  check "SWG3 no active bar in a one-strip target subwindow" [rprop 2 active] {}

  # ---- SWG4: click-to-target ----------------------------------------------
  lassign [mid 1] px py
  set ::sw_log {}
  pcall {wviewer::click_target $vdrw $px $py}
  check "SWG4 a click in subwindow 1 makes its strip the target" \
    [wviewer::target_index $tok] 1
  check "SWG4 ...logged once" $::sw_log [list [list wviewer::set_target_strip 1 $tok]]

  # ---- SWG5: the frame moved IN PLACE --------------------------------------
  check "SWG5 the frame moved to subwindow 1 (top strip L|R|T, bottom L|R|B)" \
    [lmap i {0 1 2} {rprop $i swframe}] {7 11 {}}
  check "SWG5 the active bar sits on the clicked strip (2 strips there)" \
    [list [rprop 0 active] [rprop 1 active]] {{} 1}

  # ---- SWG6: plotting lands in the TARGET subwindow -------------------------
  wviewer::set_target_strip 2 $tok
  wviewer::plot_signals $tok {b1}
  check "SWG6 single Append into the target subwindow's strip" [trx 2] {b1}
  check "SWG6 ...subwindow 1 untouched" [list [trx 0] [trx 1]] {a1 a2}
  wviewer::plot_signals $tok {b2} {} newstrip
  check "SWG6 New Strip lands at the END of the target subwindow" [ltags] {1 1 2 2}
  check "SWG6 ...holding the batch" [trx 3] {b2}
  wviewer::set_target_strip 0 $tok
  wviewer::set_plot_mode multi $tok
  wviewer::plot_signals $tok {c1 c2}
  check "SWG6 multi: new strips at the TOP of the target subwindow, newest first" \
    [list [ltags] [trx 0] [trx 1] [trx 2] [trx 3]] {{1 1 1 1 2 2} c2 c1 a1 a2}
  check "SWG6 ...the target stayed on its strip (shifted with it)" \
    [wviewer::target_index $tok] 2
  check "SWG6 ...and subwindow 2 kept its traces" [list [trx 4] [trx 5]] {b1 b2}
  wviewer::set_plot_mode single $tok

  # ---- SWG7: Add Graph inserts into the target subwindow ---------------------
  wviewer::add_graph $tok
  check "SWG7 Add Graph appends to the bottom of the TARGET subwindow" \
    [list [ltags] [wviewer::graph_is_empty [lindex [lay] 4]]] {{1 1 1 1 1 2 2} 1}
  pcall {wviewer::delete_empty_strips $tok}
  check "SWG7 e removes it again" [ltags] {1 1 1 1 2 2}

  # ---- SWG8: three subwindows tile 2x2 with a quarter empty ----------------
  send_key $vdrw <Control-Key-N> {[wviewer::sw_count [lay]] == 3}
  check "SWG8 Ctrl-Shift-N added a third subwindow" [ltags] {1 1 1 1 2 2 3}
  set bb3 [wviewer::strip_bands_px $vdrw]
  set W [winfo width $vdrw]; set H [winfo height $vdrw]
  check "SWG8 the third subwindow is bottom-LEFT" \
    [list [expr {[lindex $bb3 6 0] < 1.5}] [expr {abs([lindex $bb3 6 1] - $H / 2.0) < 1.5}]] {1 1}
  check "SWG8 ...and the bottom-right quarter is empty (no band there)" \
    [expr {[lsearch -exact [lmap b $bb3 {expr {[lindex $b 0] > $W / 2.0 + 2 && [lindex $b 1] > $H / 2.0 + 2}}] 1] < 0}] 1
  set tg [wviewer::target_index $tok]
  pcall {wviewer::click_target $vdrw [expr {int($W * 0.75)}] [expr {int($H * 0.75)}]}
  check "SWG8 a click in the empty cell changes nothing" [wviewer::target_index $tok] $tg

  # ---- SWG9: Close SubWin re-tiles; the only one refuses ---------------------
  # closing a subwindow ABOVE the target: the target follows its strip. The
  # target sits at 4 (NOT the last strip) so a stale stored index would clamp
  # to 2, not to the right answer 0.
  wviewer::set_target_strip 4 $tok
  pcall {wviewer::close_subwin $tok 0}
  check "SWG9 closing subwindow 1 from outside it: the rest re-tile" [ltags] {2 2 3}
  check "SWG9 ...and the target stays on ITS strip (4 -> 0)" [wviewer::target_index $tok] 0
  pcall {wviewer::undo $tok}
  check "SWG9 undo puts subwindow 1 back, target and all" \
    [list [ltags] [wviewer::target_index $tok]] {{1 1 1 1 2 2 3} 4}
  set ::sw_log {}
  send_key $vdrw <Control-Key-W> {[wviewer::sw_count [lay]] == 2}
  check "SWG9 Ctrl-Shift-W closed the target subwindow (ids are stable: 3 stays 3)" [ltags] {1 1 1 1 3}
  check "SWG9 the target moved to the subwindow that took its slot" \
    [wviewer::target_index $tok] 4
  check "SWG9 ...logged" [lindex $::sw_log end] [list wviewer::close_subwin $tok 4]
  set bb4 [wviewer::strip_bands_px $vdrw]
  check "SWG9 re-tiled side by side, full height" \
    [expr {abs([lindex $bb4 4 1] - [lindex $bb4 0 1]) < 1.5 && abs([lindex $bb4 4 3] - $H) < 1.5}] 1
  check "SWG9 undo brings the subwindow back" \
    [list [pcall {wviewer::undo $tok}] [ltags]] {1 {1 1 1 1 2 2 3}}
  pcall {wviewer::redo $tok}
  check "SWG9 redo closes it again" [ltags] {1 1 1 1 3}
  pcall {wviewer::close_subwin $tok 0}
  check "SWG9 closing subwindow 1 leaves ONE, untagged again" [ltags] {-}
  set ::sw_echo {}
  check "SWG9 closing the only subwindow does nothing" [pcall {wviewer::close_subwin $tok}] 0
  check "SWG9 ...and says so" \
    [expr {[lsearch -glob $::sw_echo {*only one subwindow*}] >= 0}] 1
  pcall {wviewer::undo $tok}
  check "SWG9 undo restores the two" [ltags] {1 1 1 1 3}

  # ---- SWG10: Shared X, pan and wheel zoom stay inside a subwindow ----------
  wviewer::capture_live_view_state $tok
  set gs [lay]
  for {set i 0} {$i < 4} {incr i} {
    lset gs $i [dict replace [lindex $gs $i] x1 0 x2 1]
  }
  lset gs 4 [dict replace [lindex $gs 4] x1 0.25 x2 0.75]
  wviewer::set_graphs $tok $gs
  set ::wviewer::sharedx($tok) 1
  wviewer::sharedx_toggle $tok
  check "SWG10 Shared X: subwindow 2 keeps ITS range" \
    [list [rprop 4 x1] [rprop 4 x2]] {0.25 0.75}
  check "SWG10 ...subwindow 1 its own" [list [rprop 3 x1] [rprop 3 x2]] {0 1}
  set ::wviewer::sharedx($tok) 0
  wviewer::sharedx_toggle $tok
  wviewer::pan_x $tok up 4
  check "SWG10 pan in subwindow 2 leaves subwindow 1's X byte-identical" \
    [lmap i {0 1 2 3} {list [rprop $i x1] [rprop $i x2]}] {{0 1} {0 1} {0 1} {0 1}}
  check "SWG10 ...and moved subwindow 2" [expr {[rprop 4 x1] != 0.25}] 1
  wviewer::pan_x $tok up 0
  check "SWG10 pan in subwindow 1 moves all of ITS strips together" \
    [llength [lsort -unique [lmap i {0 1 2 3} {rprop $i x1}]]] 1
  set b4 [list [rprop 4 x1] [rprop 4 x2]]
  wviewer::wheel_zoom $tok in 0
  check "SWG10 wheel zoom in subwindow 1 leaves subwindow 2 alone" \
    [list [rprop 4 x1] [rprop 4 x2]] $b4

  # ---- SWG11: the strip reorder clamps inside its subwindow -----------------
  set lastpy [lindex [mid 4] 1]
  check "SWG11 a drag of strip 0 to the far bottom clamps to subwindow 1's last" \
    [pcall {wviewer::strip_drop_index $vdrw 100000 0}] 3
  set ::sw_echo {}
  check "SWG11 move_strip across subwindows is refused" [pcall {wviewer::move_strip 0 4 $tok}] {}
  check "SWG11 ...and says why" \
    [expr {[lsearch -glob $::sw_echo {*different subwindows*}] >= 0}] 1

  # ---- SWG12: a trace moves across subwindows; paste lands in the target ----
  set before4 [trx 4]
  pcall {wviewer::move_trace 0 0 4 $tok}
  check "SWG12 a trace dragged from subwindow 1 lands in subwindow 2's strip" \
    [trx 4] [concat $before4 c2]
  check "SWG12 ...membership is unchanged" [ltags] {1 1 1 1 3}
  # copy strip 2's traces by selecting them on the rect, then paste into sw 2
  xschem new_schematic switch $vdrw
  wviewer::set_target_strip 2 $tok
  set ::wviewer::clip [dict create from [list $tok 0] \
    items [list [dict create gi 2 tr [dict create expr p1 name p1 vec p1 color 4]]]]
  wviewer::set_target_strip 4 $tok
  pcall {wviewer::paste_traces $tok}
  check "SWG12 paste lands in the TARGET subwindow's strip" \
    [lindex [trx 4] end] p1
  check "SWG12 ...and nothing landed in subwindow 1" \
    [expr {[lsearch -exact [concat [trx 0] [trx 1] [trx 2] [trx 3]] p1] < 0}] 1

  # ---- SWG13: tabs carry subwindows; serialisation; old states ------------
  set nt [pcall {wviewer::new_tab $tok}]
  check "SWG13 a new tab is ONE subwindow" [ltags] {-}
  pcall {wviewer::select_tab 1 $tok}
  check "SWG13 switching back restores the subwindows" [ltags] {1 1 1 1 3}
  set ser [pcall {wviewer::tabs_serialize $tok}]
  check "SWG13 the serialised layout carries the tags" \
    [tags [dict get [lindex $ser 0] layout graphs]] {1 1 1 1 3}
  pcall {wviewer::close_tab $nt $tok}
  set old [lmap g [lay] {dict remove $g sw}]
  pcall {wviewer::restore_tabs $tok [dict create tabs [list \
            [dict create name A layout [dict create sharedx 0 graphs $old] mode single target 0] \
            [dict create name B layout [dict create sharedx 0 graphs [lay]] mode single target 4]] \
            activetab 0]}
  check "SWG13 an old (untagged) saved tab loads as one subwindow" [ltags] {- - - - -}
  pcall {wviewer::select_tab 2 $tok}
  check "SWG13 ...and a tagged one as two" [ltags] {1 1 1 1 3}

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  rename wviewer::echo {}
  rename wviewer::__real_echo wviewer::echo
  }
  catch {wviewer::close $tok}
} else {
  puts "SKIPPED: SWG* GUI legs (no usable DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts $::errorInfo
  incr fail
}

if {$::arm eq {nogui}} { set expect 42 } else { set expect 104 }
if {$fail == 0 && $expect > 0 && $npass != $expect} {
  puts "FAIL: SWZ1 expected $expect checks on the $::arm arm, ran $npass : FAIL"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
