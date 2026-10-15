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
#   SWX*  INDEPENDENT X (stage 2). SWX1-SWX3 both arms: the axis-margin apply
#         (`xschem graph_axis_zoom`) on an ordinary schematic carrying the
#         viewer's `xgroup=` tokens, the selected arm, a string compare, and
#         controls with the tokens stripped. SWX4-SWX12 display: the C gesture
#         loop through `xschem callback .drw` -- MMB pan, RMB box zoom, the four
#         arrows, MMB in the X margin, the LMB axis-margin drag, f, and the
#         selected arm -- each with a tokenless CONTROL proving the gesture
#         does reach the other rects. SWX13-SWX18 display: the same claims in
#         the REAL viewer through Tk events on its canvas (MMB, RMB, Ctrl+wheel,
#         Shift+wheel, Left arrow, f on the target subwindow).
#   SWD*  DESTINATIONS (stage 3). SWD1-SWD9 both arms: dest_norm / labels
#         (five, New SubWin), no `-> appends` under multi, plan_plot plans New
#         SubWin as Append, sw_clear_graphs, and the REAL plot_signals ->
#         dest_prepare -> clear_subwin / new_subwin -> plot_sites chain on a
#         model-only window (Replace single and multi empties the target
#         subwindow only, with one undo point and no per-strip clear; New SubWin
#         at the end, targeted, logged; empty batches inert; Append / New Strip
#         confined). SWD10-SWD15 display: the same in the real window with
#         rects and undo, the Add Trace dialog's Replace (the NAMED graph's
#         subwindow) and New SubWin, New Tab.
#   SWR*  REPLAY, both arms, in a child with its own --logdir: a CIW-typed plot
#         under New SubWin replays to exactly one subwindow holding the plot
#         (SWR2); Replace is the control (SWR1).
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
# Stage 2 (independent X), measured 2026-10-15, each reverted to green:
#   R0 the stage-1 C (draw.c, callback.c, xschem.h at 5cd0ee6d)
#        -> display SWX1 (x2), SWX2, SWX3, SWX5-SWX12 (x10), SWX14 (x2), SWX15;
#           nogui SWX1 (x2), SWX2, SWX3
#   R1 graph_shares_x: drop the graph_same_xgroup test
#        -> as R0 minus the two SWX8 rows (the arrow X zoom has its own flag)
#   R2 callback.c xlink_loose: drop its graph_same_xgroup term -> SWX8 (x2) ONLY
#   R3 graph_shares_x: let a SELECTED rect skip the group test
#        -> SWX2 (both arms), SWX12
#   T1 wheel_zoom: scope = every strip -> SWG10 wheel leg, SWX16 Ctrl+wheel
#   T2 pan_x: scope = every strip -> SWG10 pan leg, SWX16 Shift+wheel, SWX17
#   T3 fit: scope = every strip -> SWX18 ONLY (no stage-1 row fenced Fit)
#   NOT fenced: graph_fullxzoom()'s `master = i` when the stale mouse master is
#   in another X group. With one raw loaded every group's union is the same
#   extent, so no fixture here can tell the two apart.
#
# Stage 3 (destinations), measured 2026-10-15, each reverted to green:
#   V1 dest_prepare: drop the replace arm (ruling 24's Replace)
#        -> nogui SWD5 (x2), SWD6 (x2); display adds SWD10 undo, SWD11 (x2),
#           SWD12 (x2), SWD13 (x2)
#   V2 dest_prepare: drop the newsubwin arm -> SWD7 (x3) both arms, SWD12
#   V4 sw_clear_graphs: clear the WHOLE tab, not the subwindow
#        -> SWD4 (x2), SWD5, SWD6 (x2), SWD9
#   V14 plot_signals: no empty-batch guard before dest_prepare -> SWD8 ONLY
#   V15 sw_clear_graphs: survivor a fresh empty_graph (view lost) -> SWD4 view row
#   V16 clear_subwin: no push_undo -> SWD5 undo row, SWD9
#   V17 add_trace_ok: no re-read of the target after dest_prepare
#        -> SWD13 New SubWin row ONLY
#   V20 dest_menu_label: the old `-> appends` suffix back -> SWD2 ONLY
# Follow-ups, measured 2026-10-15, each reverted to green:
#   F1 dest_prepare: new_subwin called LOGGED again (the stage-3 code)
#        -> SWR2 ONLY (the replay rebuilt an EMPTY subwindow, the plot lost:
#           new_subwin's line set the dedup flag that drops the typed line)
#   F2 tabs_serialize: inactive tabs written with sharedx 0 and no sw tags
#        -> display SWG14 ONLY (SWG13 serialises the ACTIVE branch)
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
# SWD* -- DESTINATIONS (stage 3, spec §6), both arms. New SubWin is a real
# destination; Replace empties the TARGET SUBWINDOW in both plot modes (ruling
# 24's "Replace appends under multi" limit retired); Append and New Strip stay
# inside the target subwindow; empty batches do nothing.
# SWD5-SWD9 drive the REAL wviewer::plot_signals -> dest_prepare ->
# clear_subwin / new_subwin -> plot_sites chain on a model-only window: only
# the Tk doors (regenerate, the fold, add_trace's raw lookup) are stood in for,
# and the stand-in add_trace records each landing and puts the trace in the
# model as the real one does.
# ============================================================================
check "SWD1 dest_norm: the five labels, the codes, ViVA's NewSubWin / NewWin, junk" \
  [lmap v {Append Replace {New Strip} {New SubWin} {New Tab} newsubwin {new subwin} \
           NewSubWin {New Win} newwin zzz} {wviewer::dest_norm $v}] \
  {append replace newstrip newsubwin newtab newsubwin newsubwin newsubwin newtab newtab append}
check "SWD1 the viewer offers five, New SubWin before New Tab, each a distinct code" \
  [list [wviewer::dest_labels] [llength [lsort -unique [lmap l [wviewer::dest_labels] {wviewer::dest_norm $l}]]]] \
  {{Append Replace {New Strip} {New SubWin} {New Tab}} 5}
set ::wviewer::mode(__swd_m) multi
check "SWD2 under MULTI every menu label is the plain label (no -> appends: Replace clears in both modes)" \
  [lmap l [wviewer::dest_labels] {wviewer::dest_menu_label __swd_m $l}] [wviewer::dest_labels]
unset ::wviewer::mode(__swd_m)
set swd_eq 1
foreach {m ng t n e} {single 3 1 2 {} multi 3 0 2 {1} single 0 0 1 {} multi 2 1 3 {0 1}} {
  if {[wviewer::plan_plot $m $ng $t $n -1 $e newsubwin] ne [wviewer::plan_plot $m $ng $t $n -1 $e append]} {
    set swd_eq 0
  }
}
check "SWD3 plan_plot plans New SubWin as an Append (its window half made the subwindow)" $swd_eq 1

set gq [list [G a 1] [G b 1] [G c 2] [G d 3]]
lassign [pcall {wviewer::sw_clear_graphs $gq 2}] gc f l
check "SWD4 clearing subwindow 2 of three: one empty strip in its place, the rest untouched" \
  [list [names [lreplace $gc 2 2]] [tags $gc] [wviewer::graph_is_empty [lindex $gc 2]] $f $l] \
  {{a b d} {1 1 2 3} 1 2 2}
lassign [pcall {wviewer::sw_clear_graphs $gq 1}] gc f l
check "SWD4 clearing a two-strip subwindow: strips after it move up by one" \
  [list [names [lrange $gc 1 end]] [tags $gc] [wviewer::graph_is_empty [lindex $gc 0]] $f $l] \
  {{c d} {1 2 3} 1 0 1}
lassign [pcall {wviewer::sw_clear_graphs [list [G a] [G b]] 0}] gc f l
check "SWD4 one subwindow: the WHOLE tab is one empty untagged strip (Cadence's Replace)" \
  [list [llength $gc] [tags $gc] [wviewer::graph_is_empty [lindex $gc 0]]] {1 - 1}
set ga [dict replace [G a 1] x1 0.1 x2 0.2]
set gb [dict replace [G b 1] auto 1 x1 0.3 x2 0.4 markers {1 0 0 0 0 0 0 0 0}]
lassign [pcall {wviewer::sw_clear_graphs [list $ga $gb [G c 2]] 0}] gc
set s0 [lindex $gc 0]
check "SWD4 the survivor keeps the view of the subwindow's first AUTO strip, minus traces, markers and the marker" \
  [list [wviewer::dget $s0 x1 -] [wviewer::dget $s0 x2 -] [dict exists $s0 auto] \
        [dict exists $s0 markers] [wviewer::dget $s0 traces -]] {0.3 0.4 0 0 {}}
check "SWD4 the empty list" [pcall {wviewer::sw_clear_graphs {} 0}] {{} -1 -1}

# a model-only viewer window
proc swd_open {gs tgt mode} {
  dict set ::wviewer::layouts __swd [dict create sharedx 0 graphs $gs]
  dict set ::wviewer::windows __swd top .__swd
  set ::wviewer::mode(__swd) $mode
  set ::wviewer::target(__swd) $tgt
  set ::wviewer::undo_hist(__swd) {}
  set ::wviewer::dest(__swd) append
}
proc swd_close {} {
  catch {dict unset ::wviewer::layouts __swd}
  catch {dict unset ::wviewer::windows __swd}
  foreach v {mode target undo_hist redo_hist dest wavehl} { catch {unset ::wviewer::${v}(__swd)} }
}
proc swd_lay {} { dict get [wviewer::layout_for __swd] graphs }
proc swd_tr {} { lmap g [swd_lay] {lmap t [wviewer::dget $g traces {}] {dict get $t expr}} }
set ::swd_stubbed {regenerate capture_live_view_state add_trace log_action clear_graph_traces}
foreach p $::swd_stubbed { rename ::wviewer::$p ::swd_orig_$p }
proc ::wviewer::regenerate {args} { return {} }
proc ::wviewer::capture_live_view_state {args} { return 0 }
proc ::wviewer::log_action {line} { lappend ::swd_log $line }
proc ::wviewer::clear_graph_traces {args} {
  lappend ::swd_clears $args
  return [::swd_orig_clear_graph_traces {*}$args]
}
proc ::wviewer::add_trace {token gi rpn args} {
  set gs [dict get [wviewer::layout_for $token] graphs]
  set G [lindex $gs $gi]
  dict lappend G traces [dict create expr $rpn name $rpn vec $rpn color 4]
  wviewer::set_graphs $token [lreplace $gs $gi $gi $G]
  return {}
}
if {[catch {
  set ::swd_log {}; set ::swd_clears {}
  swd_open [list [G a 1] [G b 1] [G c 2]] 2 single
  set pre [swd_lay]
  check "SWD5 Replace (single) into subwindow 2: it is emptied, then holds the batch; subwindow 1 untouched" \
    [list [pcall {wviewer::plot_signals __swd {p} {} replace}] [swd_tr] [tags [swd_lay]]] \
    {{} {a b p} {1 1 2}}
  check "SWD5 ...the plan's own clear list was empty: plot_signals made NO clear_graph_traces call" \
    [llength $::swd_clears] 0
  check "SWD5 ...ONE undo point, holding the pre-Replace subwindow" \
    [list [llength $::wviewer::undo_hist(__swd)] \
          [expr {[lindex $::wviewer::undo_hist(__swd) 0 0] eq $pre}]] {1 1}
  swd_open [list [G a 1] [G c 2] [G d 2] [G e 2]] 2 multi
  check "SWD6 Replace under MULTI empties the target subwindow too (ruling 24's limit retired): one strip per signal, newest on top" \
    [list [pcall {wviewer::plot_signals __swd {p q} {} replace}] [swd_tr] [tags [swd_lay]]] \
    {{} {a q p} {1 2 2}}
  check "SWD6 ...the target stays in the replotted subwindow" \
    [wviewer::sw_index [swd_lay] [wviewer::target_index __swd]] 1
  swd_open [list [G a] [G b]] 1 single
  check "SWD6 one subwindow: Replace clears the whole tab, then plots (the change §6.2 declares)" \
    [list [pcall {wviewer::plot_signals __swd {p} {} replace}] [swd_tr]] {{} p}
  set ::swd_log {}
  swd_open [list [G a 1] [G b 2]] 0 single
  check "SWD7 New SubWin: a third subwindow at the END, made the target, holding the batch" \
    [list [pcall {wviewer::plot_signals __swd {r s} {} newsubwin}] [swd_tr] [tags [swd_lay]] \
          [wviewer::target_index __swd]] \
    {{} {a b {r s}} {1 2 3} 2}
  check "SWD7 ...new_subwin reaches the log seam once (in C it is suppressed: SWR2 replays the gesture line)" \
    [lsearch -all -inline -glob $::swd_log {wviewer::new_subwin *}] [list [list wviewer::new_subwin __swd]]
  swd_open [list [G a] [G b]] 0 multi
  check "SWD7 New SubWin under multi: one strip per signal in the NEW subwindow, newest on top" \
    [list [pcall {wviewer::plot_signals __swd {r s} {} newsubwin}] [swd_tr] [tags [swd_lay]]] \
    {{} {a b s r} {1 1 2 2}}
  swd_open [list [G a 1] [G b 2]] 0 single
  set pre [swd_lay]
  set ::swd_log {}
  foreach d {replace newsubwin append newstrip} {
    pcall {wviewer::plot_signals __swd {} {} $d}
  }
  check "SWD8 an EMPTY batch changes nothing under any destination, and logs nothing" \
    [list [expr {[swd_lay] eq $pre}] $::swd_log [llength $::wviewer::undo_hist(__swd)]] {1 {} 0}
  swd_open [list [G a 1] [G b 1] [G c 2]] 0 single
  pcall {wviewer::plot_signals __swd {p} {} append}
  pcall {wviewer::plot_signals __swd {q} {} newstrip}
  check "SWD9 Append and New Strip stay inside the target subwindow (1); subwindow 2 untouched" \
    [list [swd_tr] [tags [swd_lay]]] {{{a p} b q c} {1 1 1 2}}
  swd_open [list [G a 1] [E 1] [G c 2]] 0 single
  pcall {wviewer::clear_subwin __swd 1}
  pcall {wviewer::clear_subwin __swd 0}
  check "SWD9 clear_subwin on a subwindow that is already one empty strip makes no undo point" \
    [list [tags [swd_lay]] [llength $::wviewer::undo_hist(__swd)]] {{1 2} 1}
  check "SWD9 clear_subwin with no viewer answers {} without throwing" \
    [pcall {wviewer::clear_subwin nosuchtoken}] {}
} swderr]} { check "SWD* band ran to its end" "ERR:$swderr" ok }
swd_close
foreach p $::swd_stubbed { rename ::wviewer::$p {}; rename ::swd_orig_$p ::wviewer::$p }

# ============================================================================
# SWR* -- REPLAY, both arms: a plot whose destination MAKES something (New
# SubWin) must replay to the window it recorded, exactly one subwindow. Run in a
# CHILD with its own --logdir, because T1's hcases loop passes none and the
# action log only exists when one is open. The child records two CIW-typed
# gestures through the CIW's own seam (`ciw_log_outcome`, the dedup a typed line
# rides), resets the model-only window, replays the recorded lines through
# `replay_action_log` and prints both end states. Replace is the CONTROL: its
# window half (clear_subwin) was never logged, so it replays right at HEAD too
# and proves the row compares something real.
# ============================================================================
set swr_inner {
  proc G {nm {sw {}}} {
    set g [dict create traces [list [dict create expr $nm name $nm vec $nm color 4]] \
             logx 0 logy 0 x1 {} x2 {} y1 {} y2 {} nm $nm]
    if {$sw ne {}} { dict set g sw $sw }
    return $g
  }
  proc swr_open {} {
    dict set ::wviewer::layouts __swr [dict create sharedx 0 graphs [list [G a 1] [G b 2]]]
    dict set ::wviewer::windows __swr top .__swr
    set ::wviewer::mode(__swr) single
    set ::wviewer::target(__swr) 1
    set ::wviewer::undo_hist(__swr) {}
    set ::wviewer::dest(__swr) append
  }
  proc swr_state {} {
    set gs [dict get [wviewer::layout_for __swr] graphs]
    list [lmap g $gs {wviewer::dget $g sw -}] \
         [lmap g $gs {lmap t [wviewer::dget $g traces {}] {dict get $t expr}}]
  }
  foreach p {regenerate capture_live_view_state} { proc ::wviewer::$p args {} }
  proc ::wviewer::add_trace {token gi rpn args} {
    set gs [dict get [wviewer::layout_for $token] graphs]
    set G [lindex $gs $gi]
    dict lappend G traces [dict create expr $rpn name $rpn vec $rpn color 4]
    wviewer::set_graphs $token [lreplace $gs $gi $gi $G]
    return {}
  }
  set lf [xschem get actionlog_filename]
  set out {}
  foreach d {newsubwin replace} {
    swr_open
    set fd [open $lf r]; set before [llength [split [read $fd] \n]]; close $fd
    foreach cmd [list [list wviewer::set_plot_dest $d __swr] {wviewer::plot_signals __swr {p}}] {
      xschem log_action -reset
      set code [catch {uplevel #0 $cmd} res]
      set ::ciw_out_pending {}
      ciw_log_outcome $code $cmd $res
    }
    set rec [swr_state]
    set fd [open $lf r]; set lines [lrange [split [read $fd] \n] [expr {$before - 1}] end]; close $fd
    set fx [file join [file dirname $lf] fx_$d.tcl]
    set fd [open $fx w]; puts $fd [join $lines \n]; close $fd
    swr_open
    set rc [catch {replay_action_log $fx} err]
    lappend out [list $d $rec [swr_state] [expr {$rc ? "ERR:$err" : 0}]]
  }
  xschem log_action -noecho "#SWR [list $out]"
  exit
}
set swr_dir [file join $scratch swr]
file mkdir $swr_dir
set swr_sf [file join $swr_dir inner.tcl]
set fd [open $swr_sf w]; puts $fd $swr_inner; close $fd
catch {exec /usr/bin/env -u DISPLAY timeout 120 [info nameofexecutable] \
         --nogui --pipe -q --logdir $swr_dir --script $swr_sf 2>@1}
set swr {}
if {![catch {set fd [open [file join $swr_dir Xschem.log] r]} ]} {
  foreach l [split [read $fd] \n] {
    if {[string match {#SWR *} $l]} { set swr [lindex [string range $l 5 end] 0] }
  }
  close $fd
}
check "SWR1 control: a replayed Replace plot rebuilds the recorded window" \
  [lindex $swr 1] {replace {{1 2} {a p}} {{1 2} {a p}} 0}
check "SWR2 a replayed New SubWin plot makes exactly ONE subwindow, holding the plot" \
  [lindex $swr 0] {newsubwin {{1 2 3} {a b p}} {{1 2 3} {a b p}} 0}

# ============================================================================
# SWX* -- INDEPENDENT X (spec §7, stage 2): the time axes of different
# subwindows are ALWAYS independent. The C half is ONE predicate,
# graph_shares_x() (draw.c), which tests graph_same_xgroup() -- the rects'
# `xgroup=` token, absent == absent -- before any arm, the `selected` arm
# included; callback.c's gesture loop reads it (and its arrow-key variant)
# through two per-rect flags and holds no copy of its own.
#
# Fixture: an ORDINARY schematic window (.drw), four graph rects showing one
# trace. Rects 0,1 carry xgroup=1 and rects 2,3 xgroup=2 -- the exact tokens
# wviewer::sw_props writes. Every gesture starts on rect 0, so the rows read:
# rect 1 FOLLOWED (strips inside a subwindow stay linked) and rects 2,3 are
# BYTE-IDENTICAL. A CONTROL with the tokens stripped shows the same gesture
# DOES move rects 2,3, so "byte-identical" is a measurement of the predicate and
# not of a gesture that did nothing.
#   SWX1-SWX3  both arms: the axis-margin apply (`xschem graph_axis_zoom`,
#              which the LMB axis-margin drag calls) and its group
#   SWX4-SWX11 display: the C gesture loop through `xschem callback .drw`
#              (has_x 0 returns before the loop, so --nogui cannot reach it)
# ============================================================================
proc swx_reset {} {
  catch {xschem unselect_all}
  catch {xschem select_all}
  catch {xschem delete}
  catch {xschem unselect_all}
  catch {xschem set_modify 0}
}
proc swx_x {i} {
  return [list [xschem getprop rect 2 $i x1] [xschem getprop rect 2 $i x2]]
}
proc swx_all {} { lmap i {0 1 2 3} {swx_x $i} }
# every rect back to x 0..1; `groups` 1 writes the subwindow tokens, 0 strips them
proc swx_set {groups} {
  for {set i 0} {$i < 4} {incr i} {
    foreach {k v} {x1 0 x2 1.0 y1 0 y2 2.5} { xschem setprop -fast rect 2 $i $k $v }
    if {$groups} {
      xschem setprop -fast rect 2 $i xgroup [expr {$i < 2 ? 1 : 2}]
    } else {
      xschem setprop -fast rect 2 $i xgroup
    }
  }
  catch {xschem unselect_all}
}
# rect 0 moved, rect 1 identical to it, rects 2/3 at {0 1.0}: the verdict word
proc swx_verdict {} {
  set w [swx_all]
  set moved [expr {[lindex $w 0] ne {0 1.0}}]
  set linked [expr {[lindex $w 1] eq [lindex $w 0]}]
  set alone [expr {[lindex $w 2] eq {0 1.0} && [lindex $w 3] eq {0 1.0}}]
  return [list moved=$moved linked=$linked others_alone=$alone]
}
# the CONTROL verdict: the same gesture with no tokens moves all four together
proc swx_control {} {
  set w [swx_all]
  return [list moved=[expr {[lindex $w 0] ne {0 1.0}}] \
               all_follow=[expr {[llength [lsort -unique $w]] == 1}]]
}

if {[catch {
swx_reset
pcall {xschem raw clear}
pcall {xschem raw new swx.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
for {set i 0} {$i < 4} {incr i} {
  xschem set rectcolor 2
  xschem rect 0 [expr {$i * 500}] 800 [expr {$i * 500 + 400}] -1 {flags=graph} 0
  xschem setprop -fast rect 2 $i node v_a
}
check "SWX0 four graph rects in the fixture" [pcall {xschem get graph_rects}] 4

# --- SWX1-3: the apply (both arms) -----------------------------------------
swx_set 1
check "SWX1 axis apply on rect 0: its subwindow follows, the other is byte-identical" \
  [pcall {xschem graph_axis_zoom 0 x 0.25 0.75; swx_verdict}] {moved=1 linked=1 others_alone=1}
swx_set 1
check "SWX1 ...and from the OTHER side: rect 2 leaves rects 0,1 alone, 3 follows" \
  [pcall {xschem graph_axis_zoom 2 x 0.25 0.75; swx_all}] {{0 1.0} {0 1.0} {0.25 0.75} {0.25 0.75}}
swx_set 1
xschem select rect 2 2
check "SWX2 a SELECTED rect in another subwindow does not follow either" \
  [pcall {xschem graph_axis_zoom 0 x 0.25 0.75; swx_verdict}] {moved=1 linked=1 others_alone=1}
swx_set 0
xschem setprop -fast rect 2 2 sim_type ac
xschem setprop -fast rect 2 3 sim_type ac
xschem select rect 2 2
check "SWX2 control: with no tokens the selected arm DOES pull rect 2 across\
 (rect 3, another sim_type, does not)" \
  [pcall {xschem graph_axis_zoom 0 x 0.25 0.75; lmap i {1 2 3} {swx_x $i}}] \
  {{0.25 0.75} {0.25 0.75} {0 1.0}}
xschem setprop -fast rect 2 2 sim_type
xschem setprop -fast rect 2 3 sim_type
swx_set 0
check "SWX3 control: with no tokens (one subwindow, any schematic) all four follow" \
  [pcall {xschem graph_axis_zoom 0 x 0.25 0.75; swx_control}] {moved=1 all_follow=1}
swx_set 1
xschem setprop -fast rect 2 1 xgroup
check "SWX3 a token is compared as a string: absent vs 1 is a different group" \
  [pcall {xschem graph_axis_zoom 0 x 0.25 0.75; lindex [swx_all] 1}] {0 1.0}

# --- SWX4-11: the C gesture loop (display only) ------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {} && [winfo exists .drw]} {
  # X11 codes: 2 KeyPress, 4 ButtonPress, 5 ButtonRelease, 6 MotionNotify;
  # masks 256 Button1, 512 Button2, 1024 Button3
  proc swx_cb {ev x y key btn st} { xschem callback .drw $ev $x $y $key $btn 0 $st }
  # drop a stale latch (GRAPHPAN freezes graph_master): ESC, releases, a move
  # to a pixel no strip occupies
  proc swx_unlatch {} {
    foreach b {1 2 3} { catch {swx_cb 5 2 2 0 $b 0} }
    catch {swx_cb 2 2 2 65307 0 0}
    catch {swx_cb 6 2 2 0 0 0}
    catch {xschem unselect_all}
  }
  # WORLD -> canvas pixel, through the engine's own transform (X_TO_SCREEN)
  proc swx_px {wx wy} {
    set z [xschem get zoom]; set xo [xschem get xorigin]; set yo [xschem get yorigin]
    return [list [expr {int(($wx + $xo) / $z)}] [expr {int(($wy + $yo) / $z)}]]
  }
  catch {wm deiconify .}
  for {set i 0} {$i < 100} {incr i} {
    catch {update}
    if {[winfo ismapped .drw]} break
    after 20
  }
  catch {xschem zoom_full}
  catch {update}
  # rect 0's plot box, asked of the engine (graph_plotbox_at) along the rect's
  # mid row / mid column -- never predicted from the rect
  lassign [swx_px 0 0] ux1 uy1
  lassign [swx_px 800 400] ux2 uy2
  set my [expr {($uy1 + $uy2) / 2}]
  set mx [expr {($ux1 + $ux2) / 2}]
  set bx1 -1; set bx2 -1; set by1 -1; set by2 -1
  for {set x $ux1} {$x <= $ux2} {incr x} {
    if {[xschem get graph_plotbox_at 0 $x $my]} { if {$bx1 < 0} { set bx1 $x }; set bx2 $x }
  }
  for {set y $uy1} {$y <= $uy2} {incr y} {
    if {[xschem get graph_plotbox_at 0 $mx $y]} { if {$by1 < 0} { set by1 $y }; set by2 $y }
  }
  set bw [expr {$bx2 - $bx1}]
  check_true "SWX4 rect 0's plot box was located (box=$bx1 $by1 $bx2 $by2)" \
    [expr {$bx1 >= 0 && $by1 >= 0 && $bw > 60 && $uy2 - $by2 > 6}]
  set cx [expr {$bx1 + $bw / 3}]
  set cy [expr {($by1 + $by2) / 2}]
  set xmy [expr {($by2 + $uy2) / 2}]         ;# the bottom (X) margin row

  # each gesture: unlatch, put the pointer on rect 0, run the events
  proc swx_mmb {} {
    global cx cy bw
    swx_unlatch
    swx_cb 6 $cx $cy 0 0 0
    swx_cb 4 $cx $cy 0 2 0
    swx_cb 6 [expr {$cx + $bw / 8}] $cy 0 0 512
    swx_cb 6 [expr {$cx + $bw / 4}] $cy 0 0 512
    swx_cb 5 [expr {$cx + $bw / 4}] $cy 0 2 512
  }
  proc swx_rmb {} {
    global cx cy bw
    swx_unlatch
    swx_cb 6 $cx $cy 0 0 0
    swx_cb 4 $cx $cy 0 3 0
    swx_cb 6 [expr {$cx + $bw / 8}] $cy 0 0 1024
    swx_cb 6 [expr {$cx + $bw / 4}] $cy 0 0 1024
    swx_cb 5 [expr {$cx + $bw / 4}] $cy 0 3 1024
  }
  proc swx_key {n} {
    global cx cy
    swx_unlatch
    swx_cb 6 $cx $cy 0 0 0
    swx_cb 2 $cx $cy $n 0 0
  }
  proc swx_bottom {} {
    global cx xmy bw
    swx_unlatch
    swx_cb 6 $cx $xmy 0 0 0
    swx_cb 4 $cx $xmy 0 2 0
    swx_cb 6 [expr {$cx + $bw / 8}] $xmy 0 0 512
    swx_cb 6 [expr {$cx + $bw / 4}] $xmy 0 0 512
    swx_cb 5 [expr {$cx + $bw / 4}] $xmy 0 2 512
  }
  proc swx_axis {} {
    global cx xmy bw
    swx_unlatch
    swx_cb 6 $cx $xmy 0 0 0
    swx_cb 4 $cx $xmy 0 1 0
    swx_cb 6 [expr {$cx + $bw / 8}] $xmy 0 0 256
    swx_cb 6 [expr {$cx + $bw / 4}] $xmy 0 0 256
    swx_cb 5 [expr {$cx + $bw / 4}] $xmy 0 1 256
  }
  # f wants a window to widen: start every rect at 0.25..0.5
  proc swx_fit {} {
    for {set i 0} {$i < 4} {incr i} {
      xschem setprop -fast rect 2 $i x1 0.25
      xschem setprop -fast rect 2 $i x2 0.5
    }
    swx_key 102
  }
  proc swx_fit_verdict {} {
    set w [swx_all]
    return [list fit=[expr {[lindex $w 0] ne {0.25 0.5}}] \
                 linked=[expr {[lindex $w 1] eq [lindex $w 0]}] \
                 others_alone=[expr {[lindex $w 2] eq {0.25 0.5} && [lindex $w 3] eq {0.25 0.5}}]]
  }
  set gestures {
    SWX5  swx_mmb              {MMB pan}
    SWX6  swx_rmb              {RMB box zoom}
    SWX7  {swx_key 65361}      {Left-arrow pan}
    SWX7  {swx_key 65363}      {Right-arrow pan}
    SWX8  {swx_key 65364}      {Down-arrow X zoom (the looser locked-or-selected rule)}
    SWX8  {swx_key 65362}      {Up-arrow X zoom (the looser locked-or-selected rule)}
    SWX9  swx_bottom           {MMB drag in the X margin (absolute positioning)}
    SWX10 swx_axis             {LMB axis-margin drag}
  }
  foreach {id g what} $gestures {
    swx_set 0
    pcall $g
    set ctl [swx_control]
    swx_set 1
    pcall $g
    check "$id $what on rect 0: its subwindow follows, the other stays byte-identical\
 (control without tokens: $ctl)" \
      [list $ctl [swx_verdict]] {{moved=1 all_follow=1} {moved=1 linked=1 others_alone=1}}
  }
  swx_set 0
  pcall swx_fit
  set ctl [swx_fit_verdict]
  swx_set 1
  pcall swx_fit
  check "SWX11 f (full X) on rect 0 fits its subwindow and leaves the other alone\
 (control without tokens: $ctl)" \
    [list $ctl [swx_fit_verdict]] {{fit=1 linked=1 others_alone=0} {fit=1 linked=1 others_alone=1}}
  # the selected arm through the real loop, not only the apply
  swx_set 1
  swx_unlatch
  xschem select rect 2 2
  pcall {
    global cx cy bw
    swx_cb 6 $cx $cy 0 0 0
    swx_cb 4 $cx $cy 0 2 0
    swx_cb 6 [expr {$cx + $bw / 8}] $cy 0 0 512
    swx_cb 6 [expr {$cx + $bw / 4}] $cy 0 0 512
    swx_cb 5 [expr {$cx + $bw / 4}] $cy 0 2 512
  }
  check "SWX12 a SELECTED rect of the other subwindow does not follow an MMB pan" \
    [swx_verdict] {moved=1 linked=1 others_alone=1}
  swx_unlatch
}
swx_reset
pcall {xschem raw clear}
} swxerr]} { check "SWX* band ran to its end" "ERR:$swxerr" ok }

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

  # ---- SWX13-SWX18: independent X in the REAL viewer, through Tk events -----
  # The same claims as SWX5-SWX11, end to end: events generated ON THE VIEWER
  # CANVAS go through its own bindings (the generic <Button>/<Motion> forward to
  # C for MMB/RMB, wheel_bind for Ctrl+wheel, key_filter for the arrows and f)
  # into the subwindow tokens that regenerate wrote. Five strips: 0-3 in
  # subwindow 1, 4 in subwindow 3. `-when now` delivers synchronously and the
  # pump runs BEFORE each gesture, never between its motion and its press
  # (issue 1659: a pumped <Configure> rewrites C's mouse pair). Pixels are the
  # canvas' own strip bands; event -x/-y are canvas pixels, which is what C's
  # callback takes.
  proc swxv_reset {} {
    wviewer::capture_live_view_state $::tok
    set gs [lay]
    for {set i 0} {$i < [llength $gs]} {incr i} {
      lset gs $i [dict replace [lindex $gs $i] x1 0 x2 1]
    }
    wviewer::set_graphs $::tok $gs
    wviewer::regenerate $::tok
    update
  }
  proc swxv_x {gi} { list [rprop $gi x1] [rprop $gi x2] }
  # the gesture started in subwindow `from` (strip list), the other is `other`
  proc swxv_verdict {from other} {
    set w0 [swxv_x [lindex $from 0]]
    set moved [expr {$w0 ne {0 1}}]
    set linked 1
    foreach gi $from { if {[swxv_x $gi] ne $w0} { set linked 0 } }
    set alone 1
    foreach gi $other { if {[swxv_x $gi] ne {0 1}} { set alone 0 } }
    return [list moved=$moved linked=$linked others_alone=$alone]
  }
  proc ev {args} { event generate $::vdrw {*}$args -when now }
  proc swxv_drag {gi btn} {
    lassign [mid $gi] px py
    set mask [expr {$btn == 2 ? 512 : 1024}]
    set dx [expr {[lindex [lindex [wviewer::strip_bands_px $::vdrw] $gi] 2] -
                  [lindex [lindex [wviewer::strip_bands_px $::vdrw] $gi] 0]}]
    set qx [expr {$px + $dx / 6}]
    update
    ev <Motion> -x $px -y $py
    ev <ButtonPress-$btn> -x $px -y $py
    ev <Motion> -x [expr {($px + $qx) / 2}] -y $py -state $mask
    ev <Motion> -x $qx -y $py -state $mask
    ev <ButtonRelease-$btn> -x $qx -y $py -state $mask
    update
  }
  set sw1 {0 1 2 3}; set sw3 {4}
  set wvs [wviewer::strip_bands_px $vdrw]
  check_true "SWX13 the viewer holds two subwindows whose strips carry two xgroups" \
    [expr {[ltags] eq {1 1 1 1 3} && [rprop 0 xgroup] ne [rprop 4 xgroup]
           && [rprop 0 xgroup] eq [rprop 3 xgroup] && [rprop 0 xgroup] ne {}}]
  swxv_reset
  check "SWX13 teeth: the reset really puts every strip's rect on 0..1" \
    [lsort -unique [lmap gi {0 1 2 3 4} {swxv_x $gi}]] {{0 1}}
  swxv_drag 1 2
  check "SWX14 MMB pan in subwindow 1 (strip 1): its strips move together, subwindow 3 is byte-identical" \
    [swxv_verdict {1 0 2 3} $sw3] {moved=1 linked=1 others_alone=1}
  swxv_reset
  swxv_drag 4 2
  check "SWX14 MMB pan in subwindow 3 leaves all of subwindow 1 byte-identical" \
    [swxv_verdict $sw3 $sw1] {moved=1 linked=1 others_alone=1}
  swxv_reset
  swxv_drag 0 3
  check "SWX15 RMB box zoom in subwindow 1 leaves subwindow 3 byte-identical" \
    [swxv_verdict $sw1 $sw3] {moved=1 linked=1 others_alone=1}
  catch {destroy .wvtracemenu}
  swxv_reset
  lassign [mid 0] px py
  update
  ev <Motion> -x $px -y $py
  ev <ButtonPress-4> -x $px -y $py -state 4
  update
  check "SWX16 Ctrl+wheel (a real Control-Button-4) in subwindow 1 leaves subwindow 3 alone" \
    [swxv_verdict $sw1 $sw3] {moved=1 linked=1 others_alone=1}
  swxv_reset
  lassign [mid 4] px py
  update
  ev <Motion> -x $px -y $py
  ev <ButtonPress-4> -x $px -y $py -state 1
  update
  check "SWX16 Shift+wheel pan in subwindow 3 leaves subwindow 1 alone" \
    [swxv_verdict $sw3 $sw1] {moved=1 linked=1 others_alone=1}
  swxv_reset
  lassign [mid 2] px py
  update
  ev <Motion> -x $px -y $py
  send_key $vdrw <KeyPress-Left> {[rprop 2 x1] != 0}
  check "SWX17 the Left arrow over subwindow 1 pans it and leaves subwindow 3 alone" \
    [swxv_verdict {2 0 1 3} $sw3] {moved=1 linked=1 others_alone=1}
  # f fits the TARGET subwindow: put every strip on a narrow window, target
  # subwindow 3, press f, and subwindow 1 must keep the narrow window. Fit
  # skips a traceless strip, so both sides must plot something or the row
  # would pass with the scoping deleted (teeth leg first).
  wviewer::set_target_strip 4 $tok
  if {[trx 4] eq {}} { wviewer::plot_signals $tok {b1} }
  check_true "SWX18 teeth: every strip of both subwindows plots a trace" \
    [expr {[lsearch -exact [lmap gi {0 1 2 3 4} {llength [trx $gi]}] 0] < 0}]
  wviewer::capture_live_view_state $tok
  set gs [lay]
  for {set i 0} {$i < [llength $gs]} {incr i} {
    lset gs $i [dict replace [lindex $gs $i] x1 0.2 x2 0.4]
  }
  wviewer::set_graphs $tok $gs
  wviewer::regenerate $tok
  wviewer::set_target_strip 4 $tok
  update
  lassign [mid 4] px py
  ev <Motion> -x $px -y $py
  send_key $vdrw <KeyPress-f> {[rprop 4 x1] != 0.2}
  check "SWX18 f fits the target subwindow (3) and leaves subwindow 1 on its window" \
    [list [expr {[swxv_x 4] ne {0.2 0.4}}] [lsort -unique [lmap gi $sw1 {swxv_x $gi}]]] \
    {1 {{0.2 0.4}}}
  swxv_reset

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

  # ---- SWD10-SWD15: the destinations in the REAL window ----------------------
  # Tab B (active) is subwindows {1 1 1 1 3}. Every row reads the model AND the
  # canvas (one graph rect per strip, xgroup per subwindow), because a model
  # that moved while the rects did not is exactly what regenerate exists to stop.
  proc nrects {} { xschem new_schematic switch $::vdrw; return [pcall {xschem get graph_rects}] }
  wviewer::set_plot_mode single $tok
  wviewer::set_target_strip 4 $tok
  set sw1before [lmap gi {0 1 2 3} {trx $gi}]
  pcall {wviewer::plot_signals $tok {p1 p2} {} replace}
  check "SWD10 Replace in the real viewer empties subwindow 3 and plots into it; subwindow 1 untouched" \
    [list [ltags] [trx 4] [lmap gi {0 1 2 3} {trx $gi}]] [list {1 1 1 1 3} {p1 p2} $sw1before]
  check "SWD10 ...one graph rect per strip, and the cleared strip still in its own X group" \
    [list [nrects] [rprop 4 xgroup] [rprop 0 xgroup]] {5 3 1}
  pcall {wviewer::undo $tok}
  check "SWD10 undo brings subwindow 3's previous plot back" \
    [expr {[trx 4] ne {p1 p2}}] 1
  pcall {wviewer::redo $tok}
  wviewer::set_plot_mode multi $tok
  wviewer::set_target_strip 0 $tok
  pcall {wviewer::plot_signals $tok {a1 a2 a3} {} replace}
  check "SWD11 Replace under MULTI empties subwindow 1 (four strips) to one strip per signal, newest on top" \
    [list [ltags] [trx 0] [trx 1] [trx 2] [trx 3]] {{1 1 1 3} a3 a2 a1 {p1 p2}}
  check "SWD11 ...rects follow the model" [nrects] 4
  wviewer::set_plot_mode single $tok
  set ::sw_log {}
  pcall {wviewer::set_plot_dest newsubwin $tok}
  pcall {wviewer::plot_signals $tok {b1}}
  check "SWD12 New SubWin (the window's own destination): a third subwindow, target, holding the batch" \
    [list [ltags] [wviewer::target_index $tok] [trx 4] [rprop 4 xgroup] [nrects]] {{1 1 1 3 4} 4 b1 4 5}
  set bb [wviewer::strip_bands_px $vdrw]
  set H [winfo height $vdrw]
  # pcall'd: under a sabotage strip 4 may not exist, and a bare expr on {}
  # would abort the band and delete every row after it from the verdict
  check "SWD12 ...the grid re-tiled: three subwindows, the new one bottom-LEFT" \
    [pcall {list [expr {[lindex $bb 4 0] < 1.5}] [expr {abs([lindex $bb 4 1] - $H / 2.0) < 1.5}]}] {1 1}
  pcall {wviewer::set_plot_dest append $tok}
  # the Add Trace dialog names its graph: Replace empties THAT graph's subwindow
  set w [pcall {wviewer::add_trace_dialog $tok}]
  if {[winfo exists $w]} {
    $w.graph set 3
    $w.dest set Replace
    $w.expr delete 0 end
    $w.expr insert 0 c1
    pcall {wviewer::add_trace_ok $tok}
  }
  check "SWD13 Add Trace with Replace on graph 3 empties ITS subwindow (3) and lands there" \
    [list [ltags] [trx 3] [trx 0] [trx 4]] {{1 1 1 3 4} c1 a3 b1}
  set w [pcall {wviewer::add_trace_dialog $tok}]
  if {[winfo exists $w]} {
    $w.dest set {New SubWin}
    $w.expr delete 0 end
    $w.expr insert 0 c2
    pcall {wviewer::add_trace_ok $tok}
  }
  check "SWD13 Add Trace with New SubWin lands in a new subwindow at the end" \
    [list [ltags] [trx 5] [wviewer::target_index $tok]] {{1 1 1 3 4 5} c2 5}
  check "SWD13 ...and the dialog's choice persisted for the window (item 7)" \
    [wviewer::plot_dest $tok] newsubwin
  pcall {wviewer::set_plot_dest append $tok}
  set ntabs [llength [wviewer::tab_records $tok]]
  pcall {wviewer::plot_signals $tok {p1} {} newtab}
  check "SWD14 New Tab: one more tab, ONE subwindow, holding the batch" \
    [list [expr {[llength [wviewer::tab_records $tok]] - $ntabs}] [ltags] [trx 0] [nrects]] {1 - p1 1}
  set ::sw_log {}
  pcall {wviewer::plot_signals $tok {} {} newsubwin}
  pcall {wviewer::plot_signals $tok {} {} replace}
  check "SWD15 an empty batch under New SubWin / Replace changes nothing in the real window" \
    [list [ltags] [trx 0] $::sw_log] {- p1 {}}

  # ---- SWG14: an INACTIVE subwindowed tab survives save / close / restore ----
  # SWG13 serialises with the subwindowed tab ACTIVE, which reads the live
  # arrays; this one reads tabs_serialize's OTHER branch, the stash record. The
  # tab gets Shared X on first so the layout's sharedx key is witnessed too.
  pcall {wviewer::select_tab 2 $tok}
  set swtags [ltags]
  set ::wviewer::sharedx($tok) 1
  pcall {wviewer::sharedx_toggle $tok}
  set swxg [lmap gi [lsearch -all $swtags *] {rprop $gi xgroup}]
  pcall {wviewer::new_tab $tok}
  set ntab [llength [wviewer::tab_records $tok]]
  set inact [lsearch -exact [lmap r [wviewer::tab_records $tok] {wviewer::dget $r id {}}] 2]
  check "SWG14 fixture: the subwindowed tab is tagged, Shared X, and NOT the active one" \
    [list [expr {[llength [lsort -unique $swtags]] > 1}] \
          [expr {$inact >= 0 && $inact != [wviewer::tab_index $tok]}]] {1 1}
  set snap [pcall {wviewer::snapshot $tok {}}]
  pcall {wviewer::close $tok}
  pcall {wviewer::restore $tok $snap {} {}}
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  viewer_ready $vtop
  pcall {wviewer::select_tab 2 $tok}
  check "SWG14 restored and selected: the same sw tags, X groups and Shared X" \
    [list [ltags] [lmap gi [lsearch -all [ltags] *] {rprop $gi xgroup}] \
          [wviewer::dget [wviewer::layout_for $tok] sharedx 0] \
          [llength [wviewer::tab_records $tok]]] \
    [list $swtags $swxg 1 $ntab]

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

if {$::arm eq {nogui}} { set expect 73 } else { set expect 170 }
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
