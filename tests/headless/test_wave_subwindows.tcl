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
#         (SWR2); Replace is the control (SWR1). SWR3: every destination
#         (Append, New Strip, Replace, New SubWin, New Tab) under both plot
#         modes -- the typed line reaches the log once and its replay rebuilds
#         the recorded window, with a non-vacuity leg per cell.
#   SWM*/SWC*/SWH*  PER-SUBWINDOW SETTINGS (SW21-SW25), both arms, on a
#         model-only window: sw_prop_get/sw_prop_put, the plot mode of the
#         TARGET subwindow (set, invert, one-subwindow byte identity, a new
#         subwindow inherits, close-to-one and Clear All fold, plots follow it,
#         undo does not revert it), clear_target_subwin (Ctrl-Shift-D), the grid
#         per subwindow (Ctrl-Shift-G, Ctrl-G inverts each, inherit, fold).
#   SWV*/SWS*/SWE*  both arms: undo / redo of a close brings every subwindow
#         back with its OWN mode and grid (the close folded the survivor's into
#         the window's own); a change made after the snapshot still wins; a
#         change is no undo step. The flat state's `grid` key (written only
#         off the rc default) and its reader. Ctrl-Shift-4's echo names the
#         target subwindow with two or more.
#   SWK*  DISPLAY -- the same in the real window: Options > Plot Mode and the
#         status bar following real clicks, real Ctrl-Shift-G / Ctrl-G on the
#         rect `grid` tokens, the Grid checkbutton, Graph > SubWin Grid and
#         Clear SubWin, a real Ctrl-Shift-D (and the Caps Lock matrix over every
#         Ctrl-letter pair: the case as typed decides; real Caps Lock chords
#         through the dispatcher to the real Clear SubWin and Clear All;
#         SWK14-16 its pure layer, both arms), undo, a new tab, tab switch, save / close / restore,
#         Graph > Clear SubWin's -command (SWK12), a one-tab grid round trip
#         (SWK13).
#   SWP13/SWT*  both arms: a trace move that empties its strip INTO ANOTHER
#         subwindow removes that strip (user request 2026-10-16): the pure
#         emptied_source_strips (same subwindow, a subwindow's last strip and
#         its switch all keep; an auto-plot strip goes like any other), then
#         move_trace / move_traces on a model-only window (one undo, one log
#         line with the pre-move indices; SWT5 auto-plot strips; SWT6 the
#         target, highlight and marker bookkeeping with a non-last destination).
#   SWD16/SWD17  both arms (user ruling 2026-10-16: the viewer has NO plot
#         destination setting; the source passes one per call): no wviewer proc
#         declares or writes a destination (derived from the proc bodies), the
#         store / accessors / Calculator mirror are gone, plot_signals' formals
#         and defaults (info args / info default), and a plot with no destover
#         lands as Append in the TARGET subwindow under both modes. SWD12/SWD13
#         restated: New SubWin passed per call; the Add Trace Destination is
#         one-shot. The independence rows proper are test_calc_plot's PL5i.
#   SWT6  (item 18 residue R2) a removed strip that carried a marker clears the
#         C marker selection; control: no marker, no clear.
#   SWK18 DISPLAY (item 18 residue R3): key_filter's own case_keysym call
#         (Ctrl-z / Ctrl-a in the keysym case the server did NOT report),
#         case_key's break passed on, and a REAL Caps Lock + Ctrl-g that stops
#         at the viewer's tag (a toplevel recorder would see a leak).
#   SWK17 DISPLAY (issue 1662): REAL RMB with the real tk_popup on every strip
#         of a multi-mode, one-trace-per-strip window, two subwindows then one:
#         the trace menu (Move greyed, Delete live) and the strip menu (Split
#         greyed) are mapped; a two-trace control strip offers both live.
#   SWG15 DISPLAY: a REAL LMB drag of a strip's sole trace into another
#         subwindow removes the strip, one log line, one u; a subwindow's last
#         strip stays; a drag within one subwindow keeps the emptied strip.
#   SWE*  `e` (empty_strips_to_delete) with subwindows: a run strip the user
#         emptied goes, every subwindow is in scope, D-D spares only the first
#         auto strip of a subwindow whose run plot holds no trace.
#   SWG16 DISPLAY: a REAL `e` after a multi-plot run deletes the emptied run
#         strip in the target subwindow, an emptied strip in another and an
#         empty subwindow; Caps Lock + e is typed E, as Shift-e is.
#   SWZ*  both arms: the aA reveal gesture's pure layer -- flick_test (the
#         30/60 deg, 100 px and 400/401 ms edges, the y sign, net displacement,
#         the angle normalisation), flick_state_ok (the B1/B3 mask), flick_push
#         (backwards time, the window, the cap), flick_params, the cells and the
#         hot zone -- and fsz_motion on a model-only window (start-cell reveal,
#         end fallback, Leave/press clears, a B1 motion clears, a bad %t).
#   SWF*  both arms: the text-size model -- the rc default and its admission
#         test, font_props, strip_fonts, per-sub-window isolation, inheritance by
#         a new sub-window, the fold on close and Clear All, undo of a close, the
#         saved keys, the refusals / logged line / replay, the CIW wording, the
#         tip, the key carriers, no undo point. Display halves: SWF3/SWF4/SWF6/
#         SWF9/SWF12 on the real rects and the real button.
#   SWA*  DISPLAY: the aA button through real events -- hidden by default,
#         hover, flick and its timer, re-arm, B1 held / a real B1 drag, the click
#         and Ctrl+click and a second click without moving, focus and stacking, a
#         .graphdialog behind the viewer, the canvas bindtags and an X-axis drag
#         with and without the gesture tag, position across Configure / add /
#         close / Fit, a 2x2 tab and a second tab.
#   SWU*  wviewer::unlogged is transparent: an error keeps -errorinfo and
#         -errorcode, break/continue/return act in the caller, and the suppress
#         depth is balanced on every path (SWU4, in the SWR child).
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
#   F3 plot_signals: plot_sites called LOGGED again (ffdbe643's code)
#        -> SWR3 single/newstrip ONLY, both arms: set_target_strip's own line
#           set the dedup flag, the typed plot line never reached the log
#           (typed 0) and the replay lost the plot. The other nine cells move
#           no target, which is why SWR1/SWR2 never saw it.
#   F4 unlogged: the pre-fix `if {$rc} { return -code error $res }`
#        -> SWU1 errorcode leg (NONE), SWU2 (the continue raised an empty
#           error and the suite died at that row)
#
# Per-subwindow settings, measured 2026-10-15, each reverted to green:
#   Sa plot_mode answers the window's value (no swmode read)
#        -> SWM2 (x2), SWM4, SWM6, SWM7, SWM8
#   Sb set_plot_mode always writes the window's value
#        -> SWM2 (x4), SWM4, SWM5, SWM7
#   Sc set_graphs: no fold of the survivor's mode -> SWM5 ONLY
#   Sd state_apply: no sw_props_carry -> SWM8 ONLY
#   Se new_subwin: no swmode stamp -> SWM4 ONLY
#   Sf grid_apply: the target scope treated as all -> SWH1, SWH2, SWH4
#   Sg regenerate: grid_shown for every strip (display) -> SWK4, SWK5
#   Sh set_target_strip: no status / mirror push (display) -> SWK2, SWK5
#   Si Ctrl-Shift-D bound as <Control-Key-D> (display) -> SWK7, SWK8 Caps Lock
#        row and its log row
#   Sj set_graphs: no sw_props_spread (display) -> SWK8 mode, SWK9 (x2), SWK10
# Verifier follow-ups, measured 2026-10-15, each reverted to green:
#   AP auto_plot_strips reads base_mode -> SWM9 ONLY
#   PC predict_colors reads base_mode -> SWM10 ONLY
#   PT paste_traces reads base_mode -> SWM11 ONLY
#   D  grid_toggle_from_menu: mixed branch disabled -> SWH7 ONLY
#   E  clear_all: drop the target-grid carry -> SWH8 ONLY
#   C  regenerate: no status_refresh / sync_grid_mirror push (display) -> SWK11
#   K  no Caps Lock aliases (the 720898fe binds) (display) -> SWK8 matrix
#        (state 6 fired nothing, state 7 fired Clear All / Ctrl-G)
#        [superseded 2026-10-16: the aliases are gone, the dispatcher decides]
# Caps Lock / right-click / emptied strip (2026-10-16), each measured red at
# 9beec4c4 (the product before the change):
#   the six 32e53cd8 Lock aliases, no dispatcher -> SWK8 (x3), SWK14-SWK16
#   the menu gates' `node_count < 2` rung -> SWK17 (x2); trace_menu TG7 (x2),
#        split_strip SG7, SG9b
#   no drop_emptied_sources -> SWP13 (x4), SWT1, SWT4, SWG12, SWG15 drag row
# Verifier follow-ups (2026-10-16), each measured red, then reverted to green:
#   the auto-plot exclusion in emptied_source_strips (136ce4e2's code)
#        -> SWP13 (x3, two of them the restated argument list), SWT5, SWG15
#           auto drag row
#   case_key: no %W substitution -> SWK8 state-6 row (the real handler)
#   drop_emptied_sources: no highlight remap -> SWT6 highlight row
#   drop_emptied_sources: no marker sweep -> SWT6 marker row
#   move_trace: target set to the stale to_gi -> SWT6 target row
# No viewer destination / item 18 residue (2026-10-16), measured red at
# 3137344c (the product before the change) unless marked as a sabotage:
#   the per-window dest store, set_plot_dest, the W13 mirror -> SWD16 (x3);
#        the persisted Add Trace choice -> SWD13 one-shot row and, through
#        the leaked New SubWin, SWK0-SWK12 (display)
#   drop_emptied_sources: no marker-selection clear -> SWT6 selection row
#   sabotage: key_filter without its case_keysym call -> SWK18 (x2)
#   sabotage: case_key without `return -code break` -> SWK18 break row
# `e` after a multi-plot run (user report 2026-10-16), measured red at 410387cf
# (the product before the fix): SWE1, SWE2, SWE3, SWE5, SWG16 Caps-Lock-off row --
# that row read {{1 1 1 2} {2 0 1 2} ...}: the empty strip in subwindow 2 and
# the empty subwindow went, the emptied run strip stayed, the report verbatim.
#        (the real-event leg read {grid_toggle_subwin_at leak})
# TEXT SIZE / aA (item 22, spec SW27-SW31 and §17), 2026-10-16. RED FIRST, measured
# on the product before the change (src/wave_viewer.tcl at HEAD, the C half in the
# tree): --nogui 60 FAILED (188 passed), display 97 FAILED (343 passed). The rows
# that pass there pass for a stated reason: SWF8's "no undo step" and SWF11's
# "the door prints nothing" (nothing happens at all), SWA2's mousex round trip (a
# fixture precondition) and SWA7 (no click lands). Then each sabotage below was
# MEASURED red on the named rows and reverted to green:
#   N1 flick_test: dy = y - ys (screen y not flipped) -> SWZ1-SWZ4, SWZ6, SWZ7, SWZ11 (x2)
#   N2 fsz_motion reveals the END cell             -> SWZ11 start-cell row ONLY
#   N3 new_subwin inherits the TARGET's size        -> SWF5 (x2)
#   N4 sw_props_stamp ignores bfont                 -> SWD5, SWF8, SWF13 stamp
#   N5 set_text_size: no capture_live_view_state    -> SWF14 ONLY
#   N6 text_step: no success sentence               -> SWF10 success row ONLY
#   N7 snapshot writes `font` at the default too    -> SWF9 ONLY
#   N8 set_text_size: no textlast write             -> SWF5 (x2), SWF9
#   D1 fsz_sync destroys and rebuilds every button  -> SWA6, SWA11, SWA14, SWA8 (x4), SWA10
#   D2 the button keeps the toplevel's bindtag      -> SWA1 bindtags, SWA14
#   D3 WvFszCanvas after the widget (index 1)       -> SWA5, SWA12, SWA13, SWA9
#   D5 the canvas <Leave> does not clear the buffer -> SWA13 ONLY
#   D6 the reveal timer never expires               -> SWA3 (x2), SWA4, SWA5, SWA12, SWA13, SWA6, SWA11, SWA8 (x2)
# SWA14's own control is the plan's SIBLING placement, measured: a sibling mapped
# over the canvas lifts a .graphdialog that sat behind the viewer (raise_dialog on
# the canvas' <Visibility>), which is why the button is a CHILD of the canvas.
#
# NOT asserted: PIXELS. That the frame looks right is eyeball-only (a `look`
# debt); what IS asserted is the token that draw.c paints from. Likewise the aA
# button's look, its corner on the real X server and the FEEL of the flick
# (synthesised events prove nothing about real pointer cadence) are owed a look
# (owed.sh look wviewer_aa_textsize) and the gesture rows a :0 run (owed.sh
# suite test_wave_subwindows).
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

# a strip a trace move EMPTIED into another subwindow goes (user request
# 2026-10-16); gs is the model after the move
set ea [dict replace [E 1] auto 1]
check "SWP13 emptied_source_strips: emptied into ANOTHER subwindow -> removed, an auto-plot strip too; same subwindow, non-empty -> kept" \
  [list [pcall {wviewer::emptied_source_strips [list [E 1] [G b 1] [G a 2]] {0} 2}] \
        [pcall {wviewer::emptied_source_strips [list [E 1] [G b 1] [G a 2]] {0} 1}] \
        [pcall {wviewer::emptied_source_strips [list $ea [G b 1] [G a 2]] {0} 2}] \
        [pcall {wviewer::emptied_source_strips [list [G x 1] [G b 1] [G a 2]] {0} 2}] \
        [pcall {wviewer::emptied_source_strips [list [E] [G a]] {0} 1}]] \
  {0 {} 0 {} {}}
check "SWP13 ...a subwindow's LAST strip stays with keep 1 and goes with keep 0" \
  [list [pcall {wviewer::emptied_source_strips [list [E 1] [G a 2]] {0} 1 1}] \
        [pcall {wviewer::emptied_source_strips [list [E 1] [G a 2]] {0} 1 0}]] {{} 0}
check "SWP13 ...two emptied strips that ARE the whole subwindow: the lowest stays (keep 1), both go (keep 0)" \
  [list [pcall {wviewer::emptied_source_strips [list [E 1] [E 1] [G a 2]] {1 0 1} 2 1}] \
        [pcall {wviewer::emptied_source_strips [list [E 1] [E 1] [G a 2]] {0 1} 2 0}] \
        [pcall {wviewer::emptied_source_strips [list [E 1] [E 1] [G x 1] [G a 2]] {0 1} 3 1}]] \
  {1 {0 1} {0 1}}
check "SWP13 the switch is one proc, and its default keeps the strip" \
  [pcall {wviewer::emptied_subwin_keeps_strip}] 1

# ============================================================================
# SWU* -- wviewer::unlogged is TRANSPARENT to everything but the log: a return
# code, an error's -errorinfo and -errorcode, and a break/continue out of a
# script run in the caller's loop all arrive as if the script had run bare.
# The suppress depth is balanced on every path (SWU4, in the SWR child, which
# has the action log this one lacks: a marker logged after an error, a break
# and a return through unlogged reaches the file only if every push popped).
# ============================================================================
proc swu_raise {} { return -code error -errorcode {SWU INNER} "swu boom" }
set swu_rc [catch {wviewer::unlogged {swu_raise}} swu_msg swu_opts]
check "SWU1 an error inside keeps its message and -errorcode" \
  [list $swu_rc $swu_msg [dict get $swu_opts -errorcode]] {1 {swu boom} {SWU INNER}}
check_true "SWU1 ...and its -errorinfo still names the raising proc" \
  [string match {*swu_raise*} [dict get $swu_opts -errorinfo]]
set swu_seen {}
foreach swu_i {1 2 3 4} {
  wviewer::unlogged {
    if {$swu_i == 2} { continue }
    if {$swu_i == 4} { break }
    lappend swu_seen $swu_i
  }
}
check "SWU2 continue and break inside reach the caller's loop" $swu_seen {1 3}
proc swu_ret {} { wviewer::unlogged { return early } ; return late }
check "SWU3 a return inside returns from the caller" [swu_ret] early
proc swu_ok {} { return fine }
check "SWU3 a plain result passes through" [wviewer::unlogged {swu_ok}] fine

# ============================================================================
# SWD16 -- THE VIEWER HAS NO DESTINATION SETTING (user ruling 2026-10-16: in
# ViVA the plot goes to the active subwindow unless the SOURCE says otherwise;
# the Calculator has its own setting, ViVA does not). This band used to assert
# that every writer of `dest(token)` notified the Calculator's W13 mirror; the
# store, its writers and the mirror are gone, so it now asserts their absence
# and the one behaviour left: a plot from a source with no choice (destover
# {}) lands in the TARGET subwindow exactly as Append does. The writer scan is
# kept, derived from the interpreter's own proc bodies (comment lines dropped),
# so a NEW writer reddens it by existing. The independence rows proper
# (W13 <-> ASE-L <-> viewer) are band PL5 of test_calc_plot.
# ============================================================================
set swd16_w {}
foreach pr [lsort [info procs ::wviewer::*]] {
  set code [join [lmap l [split [info body $pr] \n] {
    if {[regexp {^\s*#} $l]} { continue } ; set l}] \n]
  if {[regexp {(^|[\s\[;\{])(set|lappend|append|unset)\s+(::wviewer::)?dest\(} $code]} {
    lappend swd16_w [namespace tail $pr]
  }
  if {[regexp {(^|\s)variable\s+dest(\s|$)} $code]} { lappend swd16_w [namespace tail $pr] }
}
check "SWD16 no wviewer proc declares or writes a per-window destination (derived from the proc bodies)" \
  [lsort -unique $swd16_w] {}
check "SWD16 the scan's population is real (non-vacuity: it read the viewer's procs)" \
  [expr {[llength [info procs ::wviewer::*]] > 100}] 1
check "SWD16 the store and its accessors are gone: dest array, set_plot_dest, plot_dest, dest_notify" \
  [list [info exists ::wviewer::dest] [info procs ::wviewer::set_plot_dest] \
        [info procs ::wviewer::plot_dest] [info procs ::wviewer::dest_notify]] {0 {} {} {}}
check "SWD16 the Calculator's mirror is gone: viewer_dest, w13_sync, w13_bind, plot_dest_follow" \
  [list [info procs ::calc::viewer_dest] [info procs ::calc::w13_sync] \
        [info procs ::calc::w13_bind] [info procs ::calc::plot_dest_follow]] {{} {} {} {}}
check "SWD16 the per-call machinery stays: dest_norm, dest_labels, dest_prepare, plot_sites" \
  [lmap p {dest_norm dest_labels dest_prepare plot_sites} {expr {[info procs ::wviewer::$p] ne {}}}] \
  {1 1 1 1}
check "SWD16 plot_signals' fourth formal is destover and defaults to {} (a source with no choice)" \
  [list [info args ::wviewer::plot_signals] \
        [info default ::wviewer::plot_signals destover swd16_dv] $swd16_dv \
        [info default ::wviewer::plot_signals colors swd16_cv] $swd16_cv] \
  {{token exprs colors destover} 1 {} 1 {}}

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
}
proc swd_close {} {
  catch {dict unset ::wviewer::layouts __swd}
  catch {dict unset ::wviewer::windows __swd}
  foreach v {mode target undo_hist redo_hist wavehl} { catch {unset ::wviewer::${v}(__swd)} }
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
  # the snapshot also stamps each subwindow's mode, grid and text size (SWV*,
  # SWF8), so all three are stripped for the compare and the sizes asserted
  set u0 [lindex $::wviewer::undo_hist(__swd) 0 0]
  check "SWD5 ...ONE undo point, holding the pre-Replace subwindow" \
    [list [llength $::wviewer::undo_hist(__swd)] \
          [expr {[lmap g $u0 {dict remove $g swmode swgrid swfont}] eq $pre}] \
          [lmap g $u0 {wviewer::dget $g swmode -}] [lmap g $u0 {wviewer::dget $g swfont -}]] \
    {1 1 {single single single} {14 14 14}}
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
  # SWD17: a source with NO destination choice (the browser's Plot, paste,
  # Direct-in-viewer: destover {}) lands exactly as Append, into the TARGET
  # subwindow -- here subwindow 2, so the row cannot pass by landing in the
  # first one. Single appends into the target strip, multi adds one strip at
  # the top of the target subwindow.
  swd_open [list [G a 1] [G b 2] [G c 2]] 2 single
  set swd17_r [pcall {wviewer::plot_signals __swd {p}}]
  set swd17_s [list [swd_tr] [tags [swd_lay]]]
  swd_open [list [G a 1] [G b 2] [G c 2]] 2 single
  pcall {wviewer::plot_signals __swd {p} {} append}
  check "SWD17 no destover = Append into the TARGET subwindow (single: the target strip), equal to an explicit Append" \
    [list $swd17_r $swd17_s [expr {$swd17_s eq [list [swd_tr] [tags [swd_lay]]]}]] \
    {{} {{a b {c p}} {1 2 2}} 1}
  swd_open [list [G a 1] [G b 2] [G c 2]] 1 multi
  pcall {wviewer::plot_signals __swd {p}}
  check "SWD17 no destover under multi: one new strip at the top of the TARGET subwindow" \
    [list [swd_tr] [tags [swd_lay]]] {{a p b c} {1 2 2 2}}
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
# SWM* / SWC* / SWH* -- PER-SUBWINDOW SETTINGS (spec SW21-SW25, user
# 2026-10-15), both arms, on a model-only window. The plot mode and the grid
# belong to each SUBWINDOW; "the active subwindow" is the TARGET one. Ctrl-Shift-D
# clears only it, Ctrl-Shift-G flips only its grid, Ctrl-G flips every
# subwindow's grid individually. The settings are graph keys (`swmode`,
# `swgrid`) carried only where they differ from the window's own value, so a
# one-subwindow tab carries none and serialises as before.
# ============================================================================
proc swm_keys {k} { lmap g [swd_lay] { wviewer::dget $g $k - } }
# switch_ctx answers 1 so grid_apply runs; move_marker (the only with_edit
# caller reached here) is stood in for, or with_edit would mark the MAIN
# schematic read-only behind the next band
set ::swm_stubbed {regenerate capture_live_view_state log_action switch_ctx move_marker}
foreach p $::swm_stubbed { rename ::wviewer::$p ::swm_orig_$p }
proc ::wviewer::move_marker {args} { return 0 }
proc ::wviewer::regenerate {args} { return {} }
proc ::wviewer::capture_live_view_state {args} { return 0 }
proc ::wviewer::log_action {line} { lappend ::swd_log $line }
proc ::wviewer::switch_ctx {args} { return 1 }
if {[catch {
  set gp [list [G a 1] [G b 1] [G c 2]]
  check "SWM1 sw_prop_get: no key on the run reads the base" \
    [list [pcall {wviewer::sw_prop_get $gp 2 swmode single}] [pcall {wviewer::sw_prop_get $gp 0 swmode multi}]] \
    {single multi}
  set gq [pcall {wviewer::sw_prop_put $gp 2 swmode multi single}]
  check "SWM1 sw_prop_put stamps every strip of the run holding gi, and no other" \
    [list [lmap g $gq {wviewer::dget $g swmode -}] [pcall {wviewer::sw_prop_get $gq 2 swmode single}] \
          [pcall {wviewer::sw_prop_get $gq 0 swmode single}]] {{- - multi} multi single}
  set gr [pcall {wviewer::sw_prop_put $gq 2 swmode single single}]
  check "SWM1 ...and a value equal to the base REMOVES the key (no key where it says nothing)" \
    [list [lmap g $gr {dict exists $g swmode}] [expr {$gr eq $gp}]] {{0 0 0} 1}
  set gs2 [list [G a 1] [dict replace [G b 1] swmode multi] [G c 2]]
  check "SWM1 the first strip of the run CARRYING the key decides (a strip added inside the run has none)" \
    [pcall {wviewer::sw_prop_get $gs2 0 swmode single}] multi
  check "SWM1 signatures (info args / info default)" \
    [list [info args wviewer::sw_prop_get] [info args wviewer::sw_prop_put] \
          [info args wviewer::set_plot_mode] [info args wviewer::plot_mode]] \
    {{gs gi key base} {gs gi key val base} {req token} token}

  set ::swd_log {}
  swd_open [list [G a 1] [G b 2]] 1 single
  set r [pcall {wviewer::set_plot_mode multi __swd}]
  check "SWM2 set_plot_mode changes the TARGET subwindow only: it reads multi, the other single" \
    [list $r [wviewer::plot_mode __swd] [swm_keys swmode] \
          [pcall {wviewer::sw_prop_get [swd_lay] 0 swmode [wviewer::base_mode __swd]}]] \
    {multi multi {- multi} single}
  check "SWM2 ...the window's own value is untouched, and one resolved line is logged" \
    [list $::wviewer::mode(__swd) $::swd_log] [list single [list {wviewer::set_plot_mode multi __swd}]]
  pcall {wviewer::set_target_strip 0 __swd}
  check "SWM2 moving the target moves what plot_mode answers" [wviewer::plot_mode __swd] single
  pcall {wviewer::set_plot_mode invert __swd}
  pcall {wviewer::set_target_strip 1 __swd}
  pcall {wviewer::set_plot_mode invert __swd}
  check "SWM2 invert flips the target only: subwindow 1 multi, subwindow 2 back to single" \
    [list [wviewer::plot_mode __swd] [swm_keys swmode] $::wviewer::mode(__swd)] {single {multi -} single}

  swd_open [list [G a] [G b]] 0 single
  set pre [swd_lay]
  pcall {wviewer::set_plot_mode multi __swd}
  check "SWM3 ONE subwindow: the window's value changes, the graph list is byte-identical (no key)" \
    [list [wviewer::plot_mode __swd] $::wviewer::mode(__swd) [expr {[swd_lay] eq $pre}]] {multi multi 1}

  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::new_subwin __swd}
  check "SWM4 a new subwindow inherits the TARGET's mode (multi)" \
    [list [tags [swd_lay]] [wviewer::target_index __swd] [wviewer::plot_mode __swd]] {{1 2 3} 2 multi}
  pcall {wviewer::set_target_strip 0 __swd}
  pcall {wviewer::new_subwin __swd}
  check "SWM4 ...and from a single-plot target, single" \
    [list [tags [swd_lay]] [wviewer::plot_mode __swd]] {{1 2 3 4} single}
  swd_open [list [G a] [G b]] 0 multi
  pcall {wviewer::new_subwin __swd}
  check "SWM4 the first split: both subwindows read the window's mode" \
    [list [tags [swd_lay]] [wviewer::plot_mode __swd] \
          [pcall {wviewer::sw_prop_get [swd_lay] 0 swmode [wviewer::base_mode __swd]}]] {{1 1 2} multi multi}

  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::close_subwin __swd 0}
  check "SWM5 closing down to ONE subwindow keeps the survivor's mode, folded into the window (no key left)" \
    [list [tags [swd_lay]] [wviewer::plot_mode __swd] $::wviewer::mode(__swd) [swm_keys swmode]] \
    {- multi multi -}
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::close_subwin __swd 1}
  check "SWM5 ...closing the multi one leaves the single survivor single" \
    [list [wviewer::plot_mode __swd] $::wviewer::mode(__swd)] {single single}

  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::clear_all __swd}
  check "SWM6 Clear All keeps the TARGET's mode (it becomes the window's)" \
    [list [wviewer::plot_mode __swd] $::wviewer::mode(__swd)] {multi multi}

  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::plot_signals __swd {p q} {} append}
  set tg [tags [swd_lay]]
  check "SWM7 a plot into the multi target subwindow gives each signal a strip THERE" \
    [list [llength [lsearch -all $tg 1]] [llength [lsearch -all $tg 2]]] {1 3}
  pcall {wviewer::set_target_strip 0 __swd}
  pcall {wviewer::plot_signals __swd {r s} {} append}
  check "SWM7 ...and into the single subwindow both land in its target strip" \
    [list [lindex [swd_tr] 0] [llength [lsearch -all [tags [swd_lay]] 1]]] {{a r s} 1}

  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::plot_signals __swd {p} {} replace}
  set u [llength $::wviewer::undo_hist(__swd)]
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::state_apply __swd [lindex $::wviewer::undo_hist(__swd) end]}
  check "SWM8 an undo does not revert a subwindow's mode (the mode is outside undo)" \
    [list [expr {$u > 0}] [swd_tr] [wviewer::plot_mode __swd]] {1 {a b} multi}

  # ---- SWM9-SWM11: the consumers that read the mode through plot_mode -------
  # Each is driven in BOTH directions (target multi on a single window, and
  # target single on a multi window), so a consumer reading the window's own
  # value instead of the target's reddens one leg whichever way it errs.
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::auto_plot_strips __swd 3}
  set tg [tags [swd_lay]]
  set m1 [list [llength [lsearch -all $tg 1]] [llength [lsearch -all $tg 2]]]
  swd_open [list [G a 1] [G b 2]] 1 multi
  pcall {wviewer::set_plot_mode single __swd}
  pcall {wviewer::auto_plot_strips __swd 3}
  set tg [tags [swd_lay]]
  set m2 [list [llength [lsearch -all $tg 1]] [llength [lsearch -all $tg 2]]]
  check "SWM9 auto_plot_strips (ASE-L auto-plot, ~) readies strips by the TARGET's mode: multi 3 auto strips, single 1" \
    [list $m1 $m2] {{1 4} {1 2}}

  # strip a carries colour 5 so the multi plan (which avoids every strip's
  # colours) and the single plan (only the target strip's) part ways
  set pcgs [list [dict replace [G a 1] traces [list [dict create expr a name a vec a color 5]]] [G b 2]]
  swd_open $pcgs 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  set pcm [pcall {wviewer::predict_colors __swd 2}]
  swd_open $pcgs 1 multi
  pcall {wviewer::set_plot_mode single __swd}
  set pcs [pcall {wviewer::predict_colors __swd 2}]
  set ::wviewer::mode(__swd) single
  dict set ::wviewer::layouts __swd graphs $pcgs
  set pcs0 [pcall {wviewer::predict_colors __swd 2}]
  set ::wviewer::mode(__swd) multi
  set pcm0 [pcall {wviewer::predict_colors __swd 2}]
  check "SWM10 predict_colors follows the TARGET's mode (each answer equals a one-mode window's)" \
    [list [expr {$pcm eq $pcm0}] [expr {$pcs eq $pcs0}]] {1 1}
  check "SWM10 ...and the two modes predict DIFFERENT colours here (the row discriminates)" \
    [expr {$pcm0 ne $pcs0}] 1

  set clipsave $::wviewer::clip
  set ::wviewer::clip [dict create from {other 1} raw {{} {}} items [list \
    [dict create gi 0 tr [dict create expr p name p vec p color 4]] \
    [dict create gi 1 tr [dict create expr q name q vec q color 5]]]]
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::paste_traces __swd}
  set p1 [list [tags [swd_lay]] [swd_tr]]
  swd_open [list [G a 1] [G b 2]] 1 multi
  pcall {wviewer::set_plot_mode single __swd}
  pcall {wviewer::paste_traces __swd}
  set p2 [list [tags [swd_lay]] [swd_tr]]
  set ::wviewer::clip $clipsave
  check "SWM11 Ctrl-V lands by the TARGET's mode: multi one strip per group, single both in the target strip" \
    [list $p1 $p2] {{{1 2 2 2} {a b p q}} {{1 2} {a {b p q}}}}

  # ---- SWC*: Ctrl-Shift-D, clear the target subwindow only ------------------
  set ::swd_log {}
  swd_open [list [G a 1] [G b 1] [G c 2]] 0 single
  set r [pcall {wviewer::clear_target_subwin __swd}]
  check "SWC1 clear_target_subwin empties the TARGET subwindow to one strip; the other is untouched" \
    [list $r [tags [swd_lay]] [swd_tr] [wviewer::target_index __swd]] {0 {1 2} {{} c} 0}
  check "SWC1 ...one undo point, and ONE replayable line naming the window" \
    [list [llength $::wviewer::undo_hist(__swd)] $::swd_log] \
    [list 1 [list {wviewer::clear_target_subwin __swd}]]
  swd_open [list [G a] [G b]] 1 single
  pcall {wviewer::clear_target_subwin __swd}
  check "SWC2 one subwindow: the tab is cleared to one empty strip" \
    [list [llength [swd_lay]] [swd_tr]] {1 {{}}}
  check "SWC3 no viewer: {} and no throw" [pcall {wviewer::clear_target_subwin nosuchtoken}] {}
  check "SWC3 signatures" \
    [list [info args wviewer::clear_target_subwin] \
          [expr {[info default wviewer::clear_target_subwin token d] ? $d : {NODEFAULT}}] \
          [info args wviewer::clear_target_subwin_at]] {token {} W}

  # ---- SWH*: the grid per subwindow -----------------------------------------
  set ::swd_log {}
  swd_open [list [G a 1] [G b 1] [G c 2]] 2 single
  set r [pcall {wviewer::grid_toggle_subwin {} __swd}]
  check "SWH1 Ctrl-Shift-G turns the grid off in the TARGET subwindow only" \
    [list $r [pcall {wviewer::strip_grids [swd_lay] [wviewer::grid_base __swd]}] [wviewer::grid_shown __swd]] \
    {0 {1 1 0} 0}
  check "SWH1 ...and logs one resolved line" $::swd_log [list {wviewer::grid_toggle_subwin 0 __swd}]
  set ::swd_log {}
  set r [pcall {wviewer::grid_toggle {} __swd}]
  check "SWH2 Ctrl-G flips EVERY subwindow individually: mixed stays mixed, inverted" \
    [list $r [pcall {wviewer::strip_grids [swd_lay] [wviewer::grid_base __swd]}] [wviewer::grid_shown __swd]] \
    {1 {0 0 1} 1}
  set r [pcall {wviewer::grid_toggle 1 __swd}]
  check "SWH3 grid_toggle 1 turns every subwindow on" \
    [list $r [pcall {wviewer::strip_grids [swd_lay] [wviewer::grid_base __swd]}] [swm_keys swgrid]] \
    {1 {1 1 1} {- - -}}
  set ::swd_log {}
  pcall {wviewer::grid_toggle 1 __swd}
  check "SWH3 ...a second grid_toggle 1 is a no-op and logs nothing" $::swd_log {}
  pcall {wviewer::set_target_strip 0 __swd}
  pcall {wviewer::grid_toggle_subwin {} __swd}
  pcall {wviewer::new_subwin __swd}
  check "SWH4 a new subwindow inherits the target's grid (off)" \
    [list [pcall {wviewer::strip_grids [swd_lay] [wviewer::grid_base __swd]}] [wviewer::grid_shown __swd]] \
    {{0 0 1 0} 0}
  pcall {wviewer::close_subwin __swd 3}
  pcall {wviewer::close_subwin __swd 2}
  check "SWH4 closing down to one folds the survivor's grid into the window" \
    [list [tags [swd_lay]] [wviewer::grid_base __swd] [swm_keys swgrid]] {{- -} 0 {- -}}
  swd_open [list [G a] [G b]] 0 single
  set pre [swd_lay]
  pcall {wviewer::grid_toggle_subwin {} __swd}
  check "SWH5 one subwindow: Ctrl-Shift-G is Ctrl-G, the window's flag, no key on any strip" \
    [list [wviewer::grid_base __swd] [expr {[swd_lay] eq $pre}]] {0 1}
  check "SWH6 signatures" \
    [list [info args wviewer::grid_toggle_subwin] [info args wviewer::grid_toggle_subwin_at] \
          [info args wviewer::strip_grids] [info args wviewer::grid_toggle]] \
    {{want token} W {gs base} {want token}}
  check "SWH6 no viewer: {} and no throw" [pcall {wviewer::grid_toggle_subwin {} nosuchtoken}] {}

  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::grid_toggle_subwin {} __swd}
  set pre [pcall {wviewer::strip_grids [swd_lay] [wviewer::grid_base __swd]}]
  # Tk writes the new checkbutton value BEFORE -command runs: the target is off,
  # so the click writes 1
  set ::wviewer::gridshow(__swd) 1
  pcall {wviewer::grid_toggle_from_menu __swd}
  check "SWH7 the Grid checkbutton on MIXED subwindows inverts each one (the target ends on)" \
    [list $pre [pcall {wviewer::strip_grids [swd_lay] [wviewer::grid_base __swd]}] [wviewer::grid_shown __swd]] \
    {{1 0} {0 1} 1}
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::grid_toggle_subwin {} __swd}
  pcall {wviewer::clear_all __swd}
  check "SWH8 Clear All keeps the TARGET's grid (off) as the window's own" \
    [list [llength [swd_lay]] [wviewer::grid_shown __swd] [wviewer::grid_base __swd]] {1 0 0}

  # ---- SWV*: undo of a close restores each subwindow's OWN settings --------
  # The close folds the survivor's value into the window's own (outside undo),
  # so a restored subwindow that carried no key would read the NEW base. The
  # real undo door (history_step), with the two Tk-side helpers stood in for.
  foreach p {capture_live_graph_state wave_hilight_clear_set} {
    rename ::wviewer::$p ::swv_orig_$p
    proc ::wviewer::$p {args} { return 0 }
  }
  proc swv_modes {} {
    set gs [swd_lay]
    lmap r [wviewer::sw_runs $gs] {
      wviewer::sw_prop_get $gs [lindex $r 0] swmode [wviewer::base_mode __swd]}
  }
  proc swv_grids {} {
    set gs [swd_lay]
    lmap r [wviewer::sw_runs $gs] {
      wviewer::sw_prop_get $gs [lindex $r 0] swgrid [wviewer::grid_base __swd]}
  }
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  set d0 [wviewer::history_depth __swd]
  pcall {wviewer::close_subwin __swd 0}
  set pre [list [wviewer::base_mode __swd] [swm_keys swmode]]
  pcall {wviewer::undo __swd}
  check "SWV1 undo of closing the single subwindow brings it back SINGLE beside the multi survivor" \
    [list $d0 $pre [tags [swd_lay]] [swv_modes]] {{0 0} {multi -} {1 2} {single multi}}
  check "SWV1 ...keys only where they differ from the window's own (multi): the restored one carries single" \
    [list [wviewer::base_mode __swd] [swm_keys swmode]] {multi {single -}}
  pcall {wviewer::redo __swd}
  check "SWV2 redo closes it again: one subwindow, multi, no key" \
    [list [tags [swd_lay]] [wviewer::plot_mode __swd] [swm_keys swmode]] {- multi -}
  pcall {wviewer::undo __swd}
  check "SWV2 ...and undo once more restores both as they were" [swv_modes] {single multi}

  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::grid_toggle_subwin {} __swd}
  pcall {wviewer::close_subwin __swd 0}
  set pre [wviewer::grid_base __swd]
  pcall {wviewer::undo __swd}
  check "SWV3 undo of closing the grid-on subwindow brings it back grid ON beside the grid-off survivor" \
    [list $pre [swv_grids] [pcall {wviewer::strip_grids [swd_lay] [wviewer::grid_base __swd]}] [swm_keys swgrid]] \
    {0 {1 0} {1 0} {1 -}}

  # a setting changed AFTER the snapshot still wins for a subwindow present on
  # both sides (outside undo), over the snapshot's own stamped value
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::set_plot_mode multi __swd}
  pcall {wviewer::add_graph __swd}
  set d1 [wviewer::history_depth __swd]
  pcall {wviewer::set_plot_mode single __swd}
  pcall {wviewer::grid_toggle_subwin {} __swd}
  check "SWV4 a mode or grid change is not an undo step" \
    [list $d1 [wviewer::history_depth __swd]] {{1 0} {1 0}}
  pcall {wviewer::undo __swd}
  check "SWV4 undo of a later edit keeps each subwindow's LIVE mode and grid" \
    [list [tags [swd_lay]] [swv_modes] [swv_grids]] {{1 2} {single single} {1 0}}
  foreach p {capture_live_graph_state wave_hilight_clear_set} {
    rename ::wviewer::$p {}
    rename ::swv_orig_$p ::wviewer::$p
  }

  # ---- SWS*: the one-tab state carries the window's own grid ----------------
  # window_for answers for the model-only window (it asks winfo, absent here);
  # the raw-selection reader wants a real context, and is not what is asserted
  foreach p {window_for selected_rawfile} { rename ::wviewer::$p ::sws_orig_$p }
  proc ::wviewer::window_for {token} {
    if {$token eq {__swd}} { return .__swd }
    return [::sws_orig_window_for $token]
  }
  proc ::wviewer::selected_rawfile {token} {
    if {$token eq {__swd}} { return {} }
    return [::sws_orig_selected_rawfile $token]
  }
  set rcsave [expr {[info exists ::wviewer_grid_show] ? [list $::wviewer_grid_show] : {}}]
  set ::wviewer_grid_show 1
  swd_open [list [G a]] 0 single
  set s1 [pcall {wviewer::snapshot __swd {}}]
  pcall {wviewer::grid_toggle 0 __swd}
  set s0 [pcall {wviewer::snapshot __swd {}}]
  check "SWS1 a one-tab state saves the window's grid when it differs from the rc default, and only then" \
    [list [wviewer::dget $s1 open -] [dict exists $s1 grid] [wviewer::dget $s0 open -] [wviewer::dget $s0 grid -]] \
    {1 0 1 0}
  set ::wviewer_grid_show 0
  swd_open [list [G a]] 0 single
  pcall {wviewer::grid_toggle 1 __swd}
  set s2 [pcall {wviewer::snapshot __swd {}}]
  check "SWS1 ...rc default off, window on: grid 1" [wviewer::dget $s2 grid -] 1
  if {$rcsave eq {}} { unset ::wviewer_grid_show } else { set ::wviewer_grid_show [lindex $rcsave 0] }
  foreach p {window_for selected_rawfile} {
    rename ::wviewer::$p {}
    rename ::sws_orig_$p ::wviewer::$p
  }
  check "SWS2 the restore reader: a saved grid comes back, an absent or garbage one is no key (the rc default)" \
    [lmap v [list [dict create grid 0] [dict create grid 1] [dict create] [dict create grid maybe]] \
       {pcall {wviewer::state_grid $v}}] {0 1 {} {}}

  # ---- SWE*: Ctrl-Shift-4's CIW echo names the target subwindow -------------
  if {[info commands ::ase::plot_mode_for_current] ne {}} {
    rename ::ase::session_for_current ::swe_orig_sfc
    proc ::ase::session_for_current {args} { return [list __swd] }
    set have_echo [expr {[info commands ::ase::echo] ne {}}]
    if {$have_echo} { rename ::ase::echo ::swe_orig_echo }
    proc ::ase::echo {msg args} { lappend ::swe_said $msg }
    set ::swe_said {}
    swd_open [list [G a 1] [G b 2]] 1 single
    pcall {ase::plot_mode_for_current invert}
    swd_open [list [G a]] 0 single
    pcall {ase::plot_mode_for_current invert}
    check "SWE1 Ctrl-Shift-4's echo says target subwindow with two or more, the old line with one" \
      $::swe_said [list {ase: waveform viewer target subwindow plot mode = multi (__swd)} \
                        {ase: waveform viewer plot mode = multi (__swd)}]
    rename ::ase::echo {}
    if {$have_echo} { rename ::swe_orig_echo ::ase::echo }
    rename ::ase::session_for_current {}
    rename ::swe_orig_sfc ::ase::session_for_current
  } else {
    check "SWE1 ase::plot_mode_for_current is loaded" missing present
  }

  # ---- SWK14-SWK16: CAPS LOCK, the case as typed decides (ruling 2026-10-16)
  # Pure, both arms. States: 4 Ctrl, 5 Ctrl+Shift, 6 Ctrl+Lock, 7 all three.
  # Both keysym cases at every state, because whether Shift+Lock arrives as `d`
  # or `D` is the keymap's business; with no Lock bit an upper keysym counts.
  set m14 {}
  foreach st {4 5 6 7} { foreach K {d D} { lappend m14 $K$st [pcall {wviewer::typed_upper $K $st}] } }
  check "SWK14 typed_upper: Shift XOR Lock, either keysym case; no Lock bit -> Shift or an upper keysym" \
    $m14 {d4 0 D4 1 d5 1 D5 1 d6 1 D6 1 d7 0 D7 0}
  set m15 {}
  foreach N {122 90} { foreach st {0 1 4 5 6 7} { lappend m15 [pcall {wviewer::case_keysym $N $st}] } }
  lappend m15 [pcall {wviewer::case_keysym 65361 6}] [pcall {wviewer::case_keysym 49 7}]
  check "SWK15 case_keysym: under Ctrl a letter takes the typed case (z: 4 out, 5/6 in, 7 out); no Ctrl or a non-letter unchanged" \
    $m15 {122 122 122 90 90 122 90 90 90 90 90 122 65361 49}
  set p16 [pcall {wviewer::case_pairs}]
  check "SWK16 case_pairs: every Ctrl-letter pair of the viewer, each with its two base sequences" \
    [lmap {l lo up} $p16 {set l}] {d g n w e u b c q v}

  # ---- SWT1-SWT4: the trace moves on a model-only window (user request
  # 2026-10-16): a strip emptied INTO ANOTHER subwindow goes, in the same undo
  # step and under the same one log line
  rename ::wviewer::capture_live_graph_state ::swt_orig_clgs
  proc ::wviewer::capture_live_graph_state {args} { return 1 }
  set ::swd_log {}
  swd_open [list [G a 1] [G b 1] [G c 2]] 0 single
  set r [pcall {wviewer::move_trace 1 0 2 __swd}]
  check "SWT1 move_trace of a strip's sole trace into another subwindow: the strip goes, the trace lands there, the target follows" \
    [list $r [names [swd_lay]] [tags [swd_lay]] [swd_tr] [wviewer::target_index __swd]] \
    {1 {a c} {1 2} {a {c b}} 1}
  check "SWT1 ...one log line, carrying the PRE-move indices (a replay re-runs it from there)" \
    $::swd_log [list {wviewer::move_trace 1 0 2 __swd}]
  pcall {wviewer::undo __swd}
  check "SWT2 one undo brings the strip and the trace back" \
    [list [names [swd_lay]] [tags [swd_lay]] [swd_tr]] {{a b c} {1 1 2} {a b c}}
  pcall {wviewer::move_trace 1 0 0 __swd}
  check "SWT2 control: within ONE subwindow the emptied strip stays" \
    [list [names [swd_lay]] [swd_tr]] {{a b c} {{a b} {} c}}
  swd_open [list [G a 1] [G c 2]] 1 single
  pcall {wviewer::move_trace 0 0 1 __swd}
  check "SWT3 a subwindow's LAST strip stays, empty (emptied_subwin_keeps_strip)" \
    [list [names [swd_lay]] [tags [swd_lay]] [swd_tr]] {{a c} {1 2} {{} {c a}}}
  set ::swd_log {}
  swd_open [list [G a 1] [G b 1] [G x 1] [G c 2]] 0 single
  set r [pcall {wviewer::move_traces {{0 0} {1 0}} 3 __swd}]
  check "SWT4 move_traces: both emptied source strips go, the target follows, one log line" \
    [list $r [names [swd_lay]] [swd_tr] [wviewer::target_index __swd] $::swd_log] \
    {2 {x c} {x {c a b}} 1 {{wviewer::move_traces {{0 0} {1 0}} 3 __swd}}}
  pcall {wviewer::undo __swd}
  check "SWT4 ...and one undo restores all four strips" [names [swd_lay]] {a b x c}
  # SWT5: the strips a simulation run plots carry `auto 1` (auto_plot_strips);
  # a run's one-trace strip emptied into another subwindow goes like any other
  set ::swd_log {}
  swd_open [list [dict replace [G a 1] auto 1] [dict replace [G b 1] auto 1] [G c 2]] 0 single
  set r [pcall {wviewer::move_trace 1 0 2 __swd}]
  check "SWT5 an auto-plot strip's sole trace moved into another subwindow: the strip goes; the other auto strip keeps its marker" \
    [list $r [names [swd_lay]] [tags [swd_lay]] [swd_tr] [lmap g [swd_lay] {wviewer::dget $g auto 0}]] \
    {1 {a c} {1 2} {a {c b}} {1 0}}
  # SWT6: the bookkeeping. Destination NOT the last strip (target_index clamps a
  # stale last index into a right answer); a highlight below the removed strip
  # and the moved trace's own highlight both shift; a marker left on the removed
  # strip is swept window-wide (the delta link on strip d zeroed) while the
  # moved trace's own marker migrates with it and keeps its link.
  set mb "7 0 0 1 1e-3 0.5 0 0 0\n8 3 0 1 2e-3 0.5 0 0 0"
  set md "9 0 0 1 3e-3 0.5 8 0 0\n10 0 0 1 4e-3 0.5 7 0 0"
  swd_open [list [G a 1] [dict replace [G b 1] markers $mb] [G c 2] \
                 [dict replace [G d 2] markers $md]] 0 single
  set ::wviewer::wavehl(__swd) {{1 0 2} {3 0 1}}
  # item 18 residue R2: a removed strip that carried a marker clears the C
  # marker selection, as delete_empty_strips does (a selected marker there
  # would point at nothing). `xschem` is a recorder for this one call.
  proc swt_spy {script} {
    set ::swt_sel {}
    rename ::xschem ::swt_orig_xschem
    proc ::xschem {args} {
      if {[lrange $args 0 1] eq {graph_marker select}} { lappend ::swt_sel $args ; return {} }
      return [uplevel 1 [list ::swt_orig_xschem {*}$args]]
    }
    set r [pcall [list uplevel 1 $script]]
    rename ::xschem {}
    rename ::swt_orig_xschem ::xschem
    return $r
  }
  set r [swt_spy {wviewer::move_trace 1 0 2 __swd}]
  set swt6_sel $::swt_sel
  check "SWT6 the target is the destination strip, not the stale pre-removal index (destination not last)" \
    [list $r [names [swd_lay]] [swd_tr] [wviewer::target_index __swd]] \
    {1 {a c d} {a {c b} d} 1}
  check "SWT6 ...the highlights follow: the moved trace's onto its new strip, the one below shifted up" \
    [lsort [wviewer::wave_hilights __swd]] {{1 1 2} {2 0 1}}
  check "SWT6 ...markers: the moved trace's migrates with its link; the removed strip's is swept (prev on strip d zeroed)" \
    [list [wviewer::markers_numbers [wviewer::dget [lindex [swd_lay] 1] markers {}]] \
          [lmap rec [wviewer::markers_decode [wviewer::dget [lindex [swd_lay] 2] markers {}]] \
             {list [dict get $rec num] [dict get $rec prev]}]] \
    {7 {{9 0} {10 7}}}
  check "SWT6 ...the removed strip carried a marker: the C marker selection is cleared, once" \
    $swt6_sel {{graph_marker select -none}}
  swd_open [list [G a 1] [G b 1] [G c 2]] 0 single
  swt_spy {wviewer::move_trace 1 0 2 __swd}
  check "SWT6 control: a removed strip with no marker leaves the selection alone" \
    [list [names [swd_lay]] $::swt_sel] {{a c} {}}
  catch {unset ::wviewer::wavehl(__swd)}
  rename ::wviewer::capture_live_graph_state {}
  rename ::swt_orig_clgs ::wviewer::capture_live_graph_state
} swmerr]} { check "SWM* band ran to its end" "ERR:$swmerr" ok }
swd_close
check "SWC3/SWH6 the two key wrappers on a canvas no viewer owns: {} and no throw" \
  [list [pcall {wviewer::clear_target_subwin_at .nosuch}] [pcall {wviewer::grid_toggle_subwin_at .nosuch}]] {{} {}}
foreach p $::swm_stubbed { rename ::wviewer::$p {}; rename ::swm_orig_$p ::wviewer::$p }

# ============================================================================
# SWZ* / SWF* -- THE VIEWER TEXT SIZE (spec SW27-SW31, item 22), both arms.
# SWZ*: the aA reveal gesture's PURE layer (flick_test, flick_state_ok,
# flick_push, the cells and the hot zone) and fsz_motion on a model-only window
# with preset cells (no Tk needed: it answers the sub-window it revealed).
# SWF*: the size model -- the rc default and its admission test, the textpx
# token, per-sub-window isolation, inheritance by new sub-windows, the fold on
# close and Clear All, undo of a close, the saved keys, the CIW wording, the
# replayable door, and the key-carrying helpers deriving from sw_setting_keys.
# ============================================================================
set ::swf_stubbed {regenerate capture_live_view_state log_action switch_ctx move_marker echo}
foreach p $::swf_stubbed { rename ::wviewer::$p ::swf_orig_$p }
proc ::wviewer::move_marker {args} { return 0 }
proc ::wviewer::regenerate {args} { lappend ::swf_trace regenerate ; return {} }
proc ::wviewer::capture_live_view_state {args} { lappend ::swf_trace capture ; return 0 }
proc ::wviewer::log_action {line} { lappend ::swd_log $line }
proc ::wviewer::switch_ctx {args} { return 1 }
proc ::wviewer::echo {msg {tag {}}} { lappend ::swf_said $msg ; return 1 }
proc swsig {p} { if {[catch {info args $p} r]} { return "ERR:$r" } ; return $r }
proc swdef {p a} {
  if {[catch {info default $p $a v} r]} { return "ERR:$r" }
  return [list $r [expr {$r ? $v : {}}]]
}
proc swf_buf {} { if {[info exists ::wviewer::flick(__swd)]} { return $::wviewer::flick(__swd) } ; return NOBUF }
proc swf_fonts {} { pcall {wviewer::strip_fonts [swd_lay] [wviewer::font_base __swd]} }
proc swf_reset {} {
  set ::swd_log {} ; set ::swf_said {} ; set ::swf_trace {}
  catch {unset ::wviewer::textlast(__swd)}
  catch {unset ::wviewer::flick(__swd)}
  catch {unset ::wviewer::fszcells(__swd)}
}
set swf_rc_saved [expr {[info exists ::wviewer_text_size] ? [list $::wviewer_text_size] : {}}]
set swf_cli_saved [expr {[info exists ::cli_opt_script] ? $::cli_opt_script : {}}]
if {[catch {
  # ---- SWZ1-SWZ8: flick_test / flick_state_ok / flick_push, literal args ----
  # flick_test {samples x y t px deg tol ms}: samples {xs ys ts} oldest first;
  # it answers the WINNING START POINT {xs ys}, or {} for no flick.
  set P {100 45 15 400}
  check "SWZ1 a flick up-right: (0,100)@1000 -> (80,20)@1200, 113 px at 45 deg in 200 ms, answers its start" \
    [pcall {wviewer::flick_test {{0 100 1000}} 80 20 1200 {*}$P}] {0 100}
  set pi_ [expr {acos(-1)}]
  set z2 {}
  foreach a {30 60 29.5 60.5} {
    set ex [expr {200 * cos($a * $pi_ / 180)}] ; set ey [expr {-200 * sin($a * $pi_ / 180)}]
    lappend z2 $a [expr {[pcall {wviewer::flick_test {{0 0 0}} $ex $ey 100 {*}$P}] ne {}}]
  }
  check "SWZ2 the angle edges: 30 and 60 deg are inside 45 +- 15, 29.5 and 60.5 are not" \
    $z2 {30 1 60 1 29.5 0 60.5 0}
  set z3 {}
  foreach d {99 100 101} {
    set e [expr {$d / sqrt(2.0)}]
    lappend z3 $d [expr {[pcall {wviewer::flick_test {{0 0 0}} $e [expr {-$e}] 100 {*}$P}] ne {}}]
  }
  # the ruling is "net > 100 px": STRICT, so exactly 100 is no flick
  check "SWZ3 the distance edge is strict: 99 and 100 px are no flick, 101 px is" $z3 {99 0 100 0 101 1}
  check "SWZ4 the time edge: 400 ms is a flick, 401 ms is not" \
    [list [expr {[pcall {wviewer::flick_test {{0 100 1000}} 80 20 1400 {*}$P}] ne {}}] \
          [expr {[pcall {wviewer::flick_test {{0 100 1000}} 80 20 1401 {*}$P}] ne {}}]] {1 0}
  check "SWZ4 a sample from the FUTURE (t before ts) never counts" \
    [pcall {wviewer::flick_test {{0 100 1300}} 80 20 1200 {*}$P}] {}
  check "SWZ5 the state mask: Button1 (256) and Button3 (1024) refuse, Button2 (512), Shift (1), Ctrl (4) and none do not" \
    [lmap s {256 1024 1280 260 512 1 4 0 junk} {pcall {wviewer::flick_state_ok $s}}] {0 0 0 0 1 1 1 1 0}
  check "SWZ6 the y sign: down-right and up-left are no flick (screen y grows DOWN)" \
    [list [pcall {wviewer::flick_test {{0 0 0}} 80 80 100 {*}$P}] \
          [pcall {wviewer::flick_test {{100 100 0}} 20 20 100 {*}$P}]] {{} {}}
  check "SWZ7 net displacement, not path: a zigzag netting 113 px is a flick from its first sample" \
    [pcall {wviewer::flick_test {{0 0 0} {60 -10 50} {10 -50 100} {70 -40 150}} 80 -80 200 {*}$P}] {0 0}
  check "SWZ7 ...and a long path netting 49.5 px is not" \
    [pcall {wviewer::flick_test {{0 0 0} {200 -200 50} {0 -300 100}} 35 -35 150 {*}$P}] {}
  check "SWZ7 the angle is normalised: a tuned direction of 180 deg (left) accepts 175 and -175" \
    [list [expr {[pcall {wviewer::flick_test {{200 0 0}} [expr {200 - 150*cos(5*$pi_/180)}] [expr {-150*sin(5*$pi_/180)}] 100 100 180 15 400}] ne {}}] \
          [expr {[pcall {wviewer::flick_test {{200 0 0}} [expr {200 - 150*cos(5*$pi_/180)}] [expr {150*sin(5*$pi_/180)}] 100 100 180 15 400}] ne {}}]] {1 1}
  # flick_push {buf x y t ms ?cap?}: the ring buffer step
  check "SWZ8 a timestamp running BACKWARDS clears the buffer (32-bit wrap / mixed sources)" \
    [pcall {wviewer::flick_push {{0 0 1000} {5 5 1100}} 9 9 900 400}] {{9 9 900}}
  check "SWZ8 ...entries older than the window are dropped, newer kept, the new one appended" \
    [pcall {wviewer::flick_push {{0 0 1000} {5 5 1500} {6 6 1700}} 9 9 1900 400}] {{5 5 1500} {6 6 1700} {9 9 1900}}
  set big {}
  for {set i 0} {$i < 40} {incr i} { lappend big [list $i 0 [expr {1000 + $i}]] }
  set capd [pcall {wviewer::flick_push $big 99 0 1040 400}]
  check "SWZ8 ...capped at 32 samples, the newest kept" \
    [list [llength $capd] [lindex $capd end] [lindex $capd 0]] {32 {99 0 1040} {9 0 1009}}
  check "SWZ8 the parameters read the rc, a bad value its default (400 ms, user ruling)" \
    [list [pcall {wviewer::flick_params}] \
          [apply {{} { set had [info exists ::wviewer_aa_flick_ms]
                       if {$had} { set s $::wviewer_aa_flick_ms }
                       set ::wviewer_aa_flick_ms junk
                       set r [pcall {wviewer::flick_params}]
                       if {$had} { set ::wviewer_aa_flick_ms $s } else { unset ::wviewer_aa_flick_ms }
                       set r }}]] \
    {{100 45 15 400 3000} {100 45 15 400 3000}}

  # ---- SWZ9-SWZ12: the cells, the zone and fsz_motion on a model-only window
  set gz [list [G a 1] [G b 1] [G c 2]]
  set bandz {{0 0 400 100} {0 100 400 200} {400 0 800 200}}
  check "SWZ9 fsz_cells_px: one cell per sub-window, the union of its strips' bands" \
    [pcall {wviewer::fsz_cells_px $gz $bandz}] {1 {0 0 400 200} 2 {400 0 800 200}}
  check "SWZ9 ...a one-sub-window tab is cell 1 over every strip" \
    [pcall {wviewer::fsz_cells_px [list [G a] [G b]] {{0 0 400 100} {0 100 400 200}}}] {1 {0 0 400 200}}
  set zh {}
  foreach {x y} {400 0 336 0 335 0 400 40 400 41 370 20 401 20} {
    lappend zh [pcall {wviewer::fsz_zone_hit {0 0 400 200} $x $y 64 40}]
  }
  check "SWZ10 the hot zone: the top-right 64 x 40 px of the cell, edges included" $zh {1 1 0 1 0 1 0}
  # the rows above pass the zone as literals; this pins the SHIPPED zone (SWA2b
  # drives it on the real canvas)
  check "SWZ10 the shipped zone is 64 x 40 px (fsz_zone)" [pcall {set ::wviewer::fsz_zone}] {64 40}
  check "SWZ10 ...clipped to the cell (a 30 px tall cell has a 30 px zone)" \
    [list [pcall {wviewer::fsz_zone_hit {0 0 400 30} 390 30 64 40}] [pcall {wviewer::fsz_zone_hit {0 0 400 30} 390 31 64 40}]] {1 0}
  check "SWZ10 fsz_zone_at / fsz_cell_at name the sub-window" \
    [list [pcall {wviewer::fsz_zone_at {1 {0 0 400 200} 2 {400 0 800 200}} 790 10 64 40}] \
          [pcall {wviewer::fsz_zone_at {1 {0 0 400 200} 2 {400 0 800 200}} 300 10 64 40}] \
          [pcall {wviewer::fsz_cell_at {1 {0 0 400 200} 2 {400 0 800 200}} 300 150}] \
          [pcall {wviewer::fsz_cell_at {1 {0 0 400 200} 2 {400 0 800 200}} 900 150}]] {2 {} 1 {}}
  swf_reset
  swd_open [list [G a 1] [G b 2]] 0 single
  # stacked cells so a flick can cross from one into the one above
  set ::wviewer::fszcells(__swd) {1 {0 0 400 200} 2 {0 200 400 400}}
  set r1 [pcall {wviewer::fsz_motion __swd 100 260 0 5000}]
  set r2 [pcall {wviewer::fsz_motion __swd 210 150 0 5100}]
  check "SWZ11 a flick that starts in sub-window 2 and ends in 1 reveals 2 (its START), and the buffer is cleared" \
    [list $r1 $r2 [swf_buf]] {{} 2 {}}
  pcall {wviewer::fsz_motion __swd -50 260 0 6000}
  check "SWZ11 ...a start outside every cell falls back to the END cell" \
    [pcall {wviewer::fsz_motion __swd 60 150 0 6100}] 1
  pcall {wviewer::fsz_motion __swd 100 260 0 7000}
  set nb [llength [swf_buf]]
  pcall {wviewer::fsz_clear __swd}
  check "SWZ12 a canvas Leave / button press / release clears the buffer, so a jump across it is no flick" \
    [list $nb [llength [swf_buf]] [pcall {wviewer::fsz_motion __swd 210 150 0 7100}]] {1 0 {}}
  pcall {wviewer::fsz_motion __swd 100 260 0 8000}
  check "SWZ12 a motion with Button1 held clears the buffer and reveals nothing (a B1 drag up-right is no flick)" \
    [list [pcall {wviewer::fsz_motion __swd 210 150 256 8100}] [llength [swf_buf]] \
          [pcall {wviewer::fsz_motion __swd 215 145 0 8150}]] {{} 0 {}}
  check "SWZ12 a %t that is not a positive integer falls back to the clock (no throw, sample taken)" \
    [list [pcall {wviewer::fsz_motion __swd 5 5 0 {}}] [llength [swf_buf]]] {{} 1}
  check "SWZ12 signatures (info args / info default)" \
    [list [swsig wviewer::flick_test] [swsig wviewer::flick_push] [swdef wviewer::flick_push cap] \
          [swsig wviewer::fsz_motion] [swsig wviewer::fsz_cells_px] [swsig wviewer::fsz_zone_hit]] \
    {{samples x y t px deg tol ms} {buf x y t ms cap} {1 32} {token x y s t} {gs bands} {cell x y zw zh}}

  # ---- SWF1-SWF2: the rc default, its admission test, the token -------------
  swf_reset
  catch {unset ::wviewer::text_size_warned}
  check "SWF1 the range and the admission test: refuses (never clamps), canonicalises" \
    [list [pcall {wviewer::text_limits}] \
          [lmap v {6 20 5 21 14.0 abc { 8 } +8 0x10 {}} {pcall {wviewer::_accept_text_size $v}}]] \
    {{6 20} {6 20 {} {} {} {} 8 8 16 {}}}
  set s1 {}
  foreach v {14 16 6 20} { set ::wviewer_text_size $v ; lappend s1 [pcall {wviewer::default_text_size}] }
  check "SWF1 default_text_size reads wviewer_text_size lazily" $s1 {14 16 6 20}
  set ::wviewer_text_size 30
  set w1 [list [pcall {wviewer::default_text_size}] [llength $::swf_said]]
  set ::wviewer_text_size junk
  lappend w1 [pcall {wviewer::default_text_size}] [llength $::swf_said]
  check "SWF1 a bad value reads 14 with ONE CIW warning per process, naming the variable" \
    [list $w1 [string match {*wviewer_text_size*} [lindex $::swf_said 0]]] {{14 1 14 1} 1}
  unset ::wviewer_text_size
  check "SWF1 ...unset reads 14" [pcall {wviewer::default_text_size}] 14
  set ::wviewer_text_size 14
  check "SWF2 font_props: textpx in device pixels, pt * scaling, exact text" \
    [list [pcall {wviewer::font_props 14 [expr {96.0/72}]}] [pcall {wviewer::font_props 20 1.0}] \
          [pcall {wviewer::font_props 6 2}]] [list "textpx=18.67\n" "textpx=20\n" "textpx=12\n"]
  set sc_want [expr {96.0/72}]
  if {[info commands ::tk] ne {} && ![catch {tk scaling} tks]} { set sc_want $tks }
  check "SWF2 tk_points_scale: tk scaling when Tk is there, else 96/72" [pcall {wviewer::tk_points_scale}] $sc_want

  # ---- SWF3: the per-strip sizes ---------------------------------------------
  check "SWF3 strip_fonts: each strip its sub-window's size (the first strip carrying swfont decides), else the base" \
    [list [pcall {wviewer::strip_fonts [list [G a 1] [dict replace [G b 1] swfont 16] [G c 2]] 14}] \
          [pcall {wviewer::strip_fonts [list [G a] [G b]] 12}] \
          [pcall {wviewer::strip_fonts [list [dict replace [G a 1] swfont 99] [G c 2]] 14}]] \
    {{16 16 14} {12 12} {14 14}}
  swd_open [list [G a] [G b]] 0 single
  check "SWF3 a one-sub-window tab: no swfont key, every strip at the base (the rc default)" \
    [list [swm_keys swfont] [pcall {wviewer::font_base __swd}] [swf_fonts]] {{- -} 14 {14 14}}

  # ---- SWF4: a step changes ONLY its own sub-window ---------------------------
  swf_reset
  swd_open [list [G a 1] [G b 2] [G c 3]] 0 single
  set r [pcall {wviewer::text_step __swd 2 1}]
  check "SWF4 aA in sub-window 2 changes sub-window 2 ONLY; the base and the others stay" \
    [list $r [swf_fonts] [swm_keys swfont] [pcall {wviewer::font_base __swd}] [wviewer::target_index __swd]] \
    {1 {14 15 14} {- 15 -} 14 0}
  pcall {wviewer::text_step __swd 2 -1}
  check "SWF4 ...Ctrl (-1) back to the base removes the key (no key where it says nothing)" \
    [list [swf_fonts] [swm_keys swfont]] {{14 14 14} {- - -}}
  swd_open [list [G a] [G b]] 0 single
  pcall {wviewer::text_step __swd 1 1}
  check "SWF4 one sub-window: the click writes the tab's base (that sub-window IS the base), no swfont key" \
    [list [pcall {wviewer::font_base __swd}] [swm_keys swfont] [swf_fonts]] {15 {- -} {15 15}}
  check "SWF4 a sub-window id the tab does not have does nothing" \
    [list [pcall {wviewer::text_step __swd 7 1}] [pcall {wviewer::text_step __swd 1 2}] [swf_fonts]] {0 0 {15 15}}

  # ---- SWF5-SWF6: inheritance by a new sub-window --------------------------
  swf_reset
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::new_subwin __swd}
  check "SWF5 before any change a new sub-window starts at the rc default: no key AND its size is 14" \
    [list [tags [swd_lay]] [swm_keys swfont] [lindex [swf_fonts] end] \
          [pcall {wviewer::font_props [lindex [swf_fonts] end] [expr {96.0/72}]}]] \
    [list {1 2 3} {- - -} 14 "textpx=18.67\n"]
  pcall {wviewer::text_step __swd 1 1}
  pcall {wviewer::text_step __swd 1 1}
  pcall {wviewer::new_subwin __swd}
  check "SWF5 after a change (16 in sub-window 1) a new sub-window starts at 16, the others unmoved" \
    [list [tags [swd_lay]] [swf_fonts] [pcall {wviewer::text_inherit __swd}]] {{1 2 3 4} {16 14 14 16} 16}
  swd_open [list [G a]] 0 single
  pcall {wviewer::new_subwin __swd}
  check "SWF5 the first split after a change elsewhere in the window: the original keeps the base, the new one starts at the last user size" \
    [list [tags [swd_lay]] [swf_fonts] [swm_keys swfont]] {{1 2} {14 16} {- 16}}
  catch {unset ::wviewer::textlast(__swd)}
  set ::wviewer_text_size 12
  check "SWF6 text_inherit: the window's last user size, else the rc default (read live)" \
    [pcall {wviewer::text_inherit __swd}] 12
  set ::wviewer_text_size 14
  # SWF6b: "in that window". A size changed in viewer A must not reach a fresh
  # viewer B. textlast is emptied first so A's entry is the ONLY one: a reader
  # taking ANY window's last size then answers A's, deterministically.
  set swf6b_saved [array get ::wviewer::textlast]
  array unset ::wviewer::textlast
  swd_open [list [G a]] 0 single
  pcall {wviewer::text_step __swd 1 1}
  pcall {wviewer::text_step __swd 1 1}
  dict set ::wviewer::layouts __swe [dict create sharedx 0 graphs [list [G a]]]
  dict set ::wviewer::windows __swe top .__swe
  set ::wviewer::mode(__swe) single
  set ::wviewer::target(__swe) 0
  set ::wviewer::undo_hist(__swe) {}
  pcall {wviewer::new_subwin __swe}
  set swe_gs [dict get [wviewer::layout_for __swe] graphs]
  check "SWF6b a size changed in window A (16) never reaches a fresh window B: B's new sub-window and inherit are the rc default" \
    [list [pcall {wviewer::text_inherit __swd}] [pcall {wviewer::text_inherit __swe}] \
          [pcall {wviewer::strip_fonts $swe_gs [wviewer::font_base __swe]}] \
          [lmap g $swe_gs {wviewer::dget $g swfont -}]] {16 14 {14 14} {- -}}
  catch {dict unset ::wviewer::layouts __swe}
  catch {dict unset ::wviewer::windows __swe}
  foreach v {mode target undo_hist redo_hist textlast} { catch {unset ::wviewer::${v}(__swe)} }
  array unset ::wviewer::textlast
  array set ::wviewer::textlast $swf6b_saved

  # ---- SWF7: close-to-one and Clear All keep the survivor's size ------------
  swf_reset
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::text_step __swd 2 1}
  pcall {wviewer::text_step __swd 2 1}
  pcall {wviewer::close_subwin __swd 0}
  check "SWF7 closing down to one sub-window folds the survivor's size into the tab's base (no key left)" \
    [list [tags [swd_lay]] [swm_keys swfont] [pcall {wviewer::font_base __swd}] [swf_fonts]] {- - 16 16}
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::text_step __swd 2 -1}
  pcall {wviewer::clear_all __swd}
  check "SWF7 Clear All keeps the TARGET's size (13) as the tab's own" \
    [list [llength [swd_lay]] [pcall {wviewer::font_base __swd}] [pcall {wviewer::font_shown __swd}]] {1 13 13}

  # ---- SWF8: undo of a close brings the closed sub-window's size back -------
  foreach p {capture_live_graph_state wave_hilight_clear_set} {
    rename ::wviewer::$p ::swf8_orig_$p
    proc ::wviewer::$p {args} { return 0 }
  }
  swf_reset
  swd_open [list [G a 1] [G b 2]] 1 single
  pcall {wviewer::text_step __swd 2 1}
  pcall {wviewer::text_step __swd 2 1}
  pcall {wviewer::close_subwin __swd 0}
  set pre [list [pcall {wviewer::font_base __swd}] [swf_fonts]]
  pcall {wviewer::undo __swd}
  check "SWF8 undo of closing the 14 pt sub-window brings it back at 14 beside the 16 pt survivor" \
    [list $pre [tags [swd_lay]] [swf_fonts] [swm_keys swfont]] {{16 16} {1 2} {14 16} {14 -}}
  pcall {wviewer::text_step __swd 1 1}
  check "SWF8 a size change is no undo step" [pcall {wviewer::history_depth __swd}] {0 1}
  foreach p {capture_live_graph_state wave_hilight_clear_set} {
    rename ::wviewer::$p {}
    rename ::swf8_orig_$p ::wviewer::$p
  }

  # ---- SWF9: the saved keys ---------------------------------------------------
  foreach p {window_for selected_rawfile} { rename ::wviewer::$p ::swf9_orig_$p }
  proc ::wviewer::window_for {token} {
    if {$token eq {__swd}} { return .__swd }
    return [::swf9_orig_window_for $token]
  }
  proc ::wviewer::selected_rawfile {token} {
    if {$token eq {__swd}} { return {} }
    return [::swf9_orig_selected_rawfile $token]
  }
  swf_reset
  swd_open [list [G a]] 0 single
  set s0 [pcall {wviewer::snapshot __swd {}}]
  pcall {wviewer::text_step __swd 1 1}
  set s1 [pcall {wviewer::snapshot __swd {}}]
  pcall {wviewer::text_step __swd 1 -1}
  set s2 [pcall {wviewer::snapshot __swd {}}]
  check "SWF9 the default writes no key; a non-default base writes font, a user change writes fontlast" \
    [list [dict exists $s0 font] [dict exists $s0 fontlast] [wviewer::dget $s1 font -] [wviewer::dget $s1 fontlast -] \
          [dict exists $s2 font] [wviewer::dget $s2 fontlast -]] {0 0 15 15 0 14}
  foreach p {window_for selected_rawfile} {
    rename ::wviewer::$p {}
    rename ::swf9_orig_$p ::wviewer::$p
  }
  check "SWF9 the restore reader: a saved size comes back, an absent or out-of-range one is no key" \
    [lmap v [list [dict create font 16] [dict create font 21] [dict create] [dict create font x] \
                  [dict create fontlast 7]] {pcall {wviewer::state_font $v}}] {16 {} {} {} {}}
  check "SWF9 ...and the fontlast key through the same reader" \
    [pcall {wviewer::state_font [dict create fontlast 7] fontlast}] 7

  # ---- SWF10: refusals, the logged line, replay -------------------------------
  swf_reset
  swd_open [list [G a 1] [G b 2]] 0 single
  pcall {wviewer::set_text_size 20 __swd 1}
  set ::swd_log {} ; set ::swf_said {}
  set rr [pcall {wviewer::text_step __swd 2 1}]
  pcall {wviewer::set_text_size 6 __swd 0}
  set ::swd_log {}
  lappend rr [pcall {wviewer::text_step __swd 1 -1}]
  check "SWF10 the range ends refuse with the Calculator's sentences and log nothing" \
    [list $rr $::swf_said $::swd_log [swf_fonts]] \
    [list {0 0} {{Font size: already the largest (20).} {Font size: already the smallest (6).}} {} {6 20}]
  set ::cli_opt_script {}
  set ::swf_said {}
  pcall {wviewer::text_step __swd 1 1}
  check "SWF10 a success echoes the Calculator's sentence with the rc hint, and logs ONE resolved line" \
    [list $::swf_said $::swd_log] \
    [list {{Font size: 7 (xschemrc: set wviewer_text_size 7).}} [list {wviewer::set_text_size 7 __swd 0}]]
  set line [lindex $::swd_log 0]
  swf_reset
  swd_open [list [G a 1] [G b 2]] 0 single
  pcall {wviewer::set_text_size 20 __swd 1}
  catch {uplevel #0 $line}
  check "SWF10 replaying the logged line rebuilds the size" [swf_fonts] {7 20}
  set ::swd_log {}
  check "SWF10 set_text_size: a no-op is no log line; a bad size or strip is refused" \
    [list [pcall {wviewer::set_text_size 7 __swd 0}] $::swd_log [pcall {wviewer::set_text_size 21 __swd 0}] \
          [pcall {wviewer::set_text_size 8 __swd 9}] [pcall {wviewer::set_text_size 8 nosuchtoken}] [swf_fonts]] \
    {7 {} {} {} {} {7 20}}

  # ---- SWF11: the CIW wording; the door itself is silent -----------------------
  set ::cli_opt_script /x/sky130A/cadence_style_rc
  set m11 [list [pcall {wviewer::text_size_msg 15}]]
  set ::cli_opt_script {}
  lappend m11 [pcall {wviewer::text_size_msg 15}]
  check "SWF11 the CIW line names the rc the launch read (the --script rc's name, else xschemrc)" \
    $m11 {{Font size: 15 (cadence_style_rc: set wviewer_text_size 15).} {Font size: 15 (xschemrc: set wviewer_text_size 15).}}
  set ::swf_said {}
  pcall {wviewer::set_text_size 9 __swd 0}
  check "SWF11 set_text_size alone (replay, script, restore) prints nothing" $::swf_said {}

  # ---- SWF12: the tip is the Calculator's sentence, derived -----------------
  set calc_tip {}
  if {[info commands ::calc::_font_tip] ne {}} {
    set calc_tip [calc::_font_tip]
  } else {
    set cf [open [file join $repo src calculator.tcl]] ; set ct [read $cf] ; close $cf
    if {[regexp {proc calc::_font_tip \{\} \{\s*return \{([^\}]*)\}} $ct -> calc_tip]} {
    } else { puts "skip: SWF12 calc::_font_tip not loaded and not found in src/calculator.tcl" }
  }
  check "SWF12 the aA tip is calc::_font_tip's sentence verbatim" [pcall {wviewer::_font_tip}] $calc_tip

  # ---- SWF13: the key-carrying helpers derive from sw_setting_keys ----------
  check "SWF13 sw_setting_keys" [pcall {set ::wviewer::sw_setting_keys}] {swmode swgrid swfont}
  set g13 [pcall {wviewer::sw_props_spread [list [dict replace [G a 1] swfont 16] [G b 1] [G c 2]]}]
  check "SWF13 spread carries swfont onto every strip of its sub-window" \
    [lmap g $g13 {wviewer::dget $g swfont -}] {16 16 -}
  set t13 [list [dict replace [G a 1] swfont 16] [dict replace [G c 2] swfont 14]]
  check "SWF13 trim drops a swfont equal to the base (numerically), and skips swfont when no base is given" \
    [list [lmap g [pcall {wviewer::sw_props_trim $t13 single 1 14.0}] {wviewer::dget $g swfont -}] \
          [lmap g [pcall {wviewer::sw_props_trim $t13 single 1}] {wviewer::dget $g swfont -}]] {{16 -} {16 14}}
  check "SWF13 stamp writes every sub-window's size explicitly (the base where none)" \
    [lmap g [pcall {wviewer::sw_props_stamp [list [G a 1] [dict replace [G c 2] swfont 16]] single 1 14}] \
       {wviewer::dget $g swfont -}] {14 16}
  check "SWF13 carry takes the LIVE size of a sub-window present on both sides" \
    [lmap g [pcall {wviewer::sw_props_carry [list [dict replace [G a 1] swfont 18] [G c 2]] \
                     [list [dict replace [G a 1] swfont 15] [dict replace [G c 2] swfont 16]]}] \
       {wviewer::dget $g swfont -}] {18 -}
  swd_open [list [G a 1] [G b 2]] 0 single
  pcall {wviewer::set_graphs __swd [list [dict replace [G a 1] swfont 14] [dict replace [G b 2] swfont 17]]}
  check "SWF13 set_graphs trims a swfont equal to the tab's base" [swm_keys swfont] {- 17}
  check "SWF13 signatures (info args / info default)" \
    [list [swsig wviewer::sw_props_trim] [swdef wviewer::sw_props_trim bfont] \
          [swsig wviewer::sw_props_stamp] [swdef wviewer::sw_props_stamp bfont] \
          [swsig wviewer::sw_props_carry] [swsig wviewer::set_text_size] \
          [swdef wviewer::set_text_size token] [swdef wviewer::set_text_size gi] \
          [swsig wviewer::text_step] [swsig wviewer::font_props] [swsig wviewer::state_font] \
          [swdef wviewer::state_font key] [swsig wviewer::strip_fonts]] \
    [list {gs bmode bgrid bfont} {1 {}} {gs bmode bgrid bfont} {1 {}} {live snap} {pt token gi} {1 {}} {1 {}} \
          {token k dir} {pt sc} {vdict key} {1 font} {gs base}]

  # ---- SWF14: the step keeps the view state and takes no undo point ----------
  swf_reset
  swd_open [list [G a 1] [G b 2]] 0 single
  set d0 [pcall {wviewer::history_depth __swd}]
  pcall {wviewer::text_step __swd 2 1}
  check "SWF14 a step folds the live view state (selection) BEFORE the write, regenerates once, pushes no undo" \
    [list $::swf_trace [expr {$d0 eq [pcall {wviewer::history_depth __swd}]}] [llength $::wviewer::undo_hist(__swd)]] \
    {{capture regenerate} 1 0}
} swferr]} { check "SWF* band ran to its end" "ERR:$swferr" ok }
swd_close
swf_reset
if {$swf_rc_saved eq {}} { catch {unset ::wviewer_text_size} } else { set ::wviewer_text_size [lindex $swf_rc_saved 0] }
set ::cli_opt_script $swf_cli_saved
foreach p $::swf_stubbed { rename ::wviewer::$p {}; rename ::swf_orig_$p ::wviewer::$p }

# ---- SWE*: `e` (Delete Empty Strips) with subwindows and multi-plot run strips
# User report 2026-10-16: "e key to delete empty strips is not working anymore
# for empty strips. It's only deleting empty sub-windows." Since R-OUT14
# (7cdb6d70) every strip a multi-plot run plots carries `auto 1`, and the rule
# spared EVERY such strip; D-D now spares only the first auto strip of a
# subwindow whose run plot holds no trace (wviewer::empty_strips_to_delete).
proc A {nm sw} { dict replace [G $nm $sw] auto 1 }
proc AE {sw} { dict replace [E $sw] auto 1 }
check "SWE1 a run strip the user emptied, beside run strips still holding traces, is deleted" \
  [pcall {wviewer::empty_strips_to_delete [list [A a 1] [AE 1] [A c 1]] 0}] {1}
check "SWE2 every subwindow: the emptied run strip, a plain empty strip in another subwindow, and an empty subwindow" \
  [pcall {wviewer::empty_strips_to_delete [list [A a 1] [AE 1] [G c 2] [E 2] [E 3]] 0}] {1 3 4}
check "SWE3 D-D: a run plot with no trace left (between runs) keeps its FIRST auto strip, the rest go" \
  [pcall {wviewer::empty_strips_to_delete [list [AE 1] [AE 1] [G c 2]] 0}] {1}
check "SWE4 D-D is per subwindow: a live run plot elsewhere does not unspare this subwindow's empty one" \
  [pcall {wviewer::empty_strips_to_delete [list [A a 1] [AE 2] [G c 2]] 0}] {}
check "SWE5 the FIRST run strip emptied while a later run strip is live is deleted" \
  [pcall {wviewer::empty_strips_to_delete [list [AE 1] [A b 1]] 0}] {0}

# ============================================================================
# SWR* -- REPLAY, both arms: a plot whose destination MAKES something (New
# SubWin) must replay to the window it recorded, exactly one subwindow. Run in a
# CHILD with its own --logdir, because T1's hcases loop passes none and the
# action log only exists when one is open. The child records ONE CIW-typed
# plot line per cell, its destination its fourth argument (the viewer has no
# destination setting since the user ruling of 2026-10-16), through the CIW's own seam (`ciw_log_outcome`, the dedup a typed line
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
  catch {wviewer::unlogged {error swu}}
  foreach i {1 2} { wviewer::unlogged { break } }
  proc swu_ret {} { wviewer::unlogged { return early } ; return late }
  swu_ret
  xschem log_action -noecho "#SWU balanced"
  set out {}
  foreach d {newsubwin replace} {
    swr_open
    set fd [open $lf r]; set before [llength [split [read $fd] \n]]; close $fd
    foreach cmd [list [list wviewer::plot_signals __swr {p} {} $d]] {
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
  # SWR3: the whole matrix, 5 destinations x both plot modes. The tab half
  # needs no Tk here: switch_ctx and the tab bar's widgets are stubbed, the
  # tab records are the model. Each cell answers {rec replayed rc typed}:
  # `typed` is how many recorded lines are the typed plot_signals line --
  # the line an inner self-log would have eaten through the CIW's dedup.
  foreach p {switch_ctx tabbar_refresh retitle status_refresh tab_drop_transients} {
    proc ::wviewer::$p args { return 1 }
  }
  proc swm_open {m} {
    swr_open
    set ::wviewer::mode(__swr) $m
    foreach a {tabstash curtab tabseq} { array unset ::wviewer::$a __swr }
    wviewer::tabs_init __swr
  }
  proc swm_state {} {
    list [wviewer::tab_count __swr] [wviewer::tab_index __swr] [swr_state]
  }
  set out {}
  foreach m {single multi} {
    foreach d {append newstrip replace newsubwin newtab} {
      swm_open $m
      set fd [open $lf r]; set before [llength [split [read $fd] \n]]; close $fd
      foreach cmd [list [list wviewer::plot_signals __swr {p} {} $d]] {
        xschem log_action -reset
        set code [catch {uplevel #0 $cmd} res]
        set ::ciw_out_pending {}
        ciw_log_outcome $code $cmd $res
      }
      set rec [swm_state]
      set fd [open $lf r]; set lines [lrange [split [read $fd] \n] [expr {$before - 1}] end]; close $fd
      set typed [llength [lsearch -all -glob $lines {*wviewer::plot_signals __swr*}]]
      set fx [file join [file dirname $lf] fxm_${m}_$d.tcl]
      set fd [open $fx w]; puts $fd [join $lines \n]; close $fd
      swm_open $m
      set rc [catch {replay_action_log $fx} err]
      lappend out [list $m/$d $rec [swm_state] [expr {$rc ? "ERR:$err" : 0}] $typed]
    }
  }
  xschem log_action -noecho "#SWM [list $out]"
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
set swm {}
if {![catch {set fd [open [file join $swr_dir Xschem.log] r]} ]} {
  foreach l [split [read $fd] \n] {
    if {[string match {#SWM *} $l]} { set swm [lindex [string range $l 5 end] 0] }
  }
  close $fd
}
set swu_bal 0
if {![catch {set fd [open [file join $swr_dir Xschem.log] r]} ]} {
  set swu_bal [expr {[string first "#SWU balanced" [read $fd]] >= 0}]
  close $fd
}
check "SWU4 the suppress depth is balanced after an error, a break and a return through unlogged" \
  $swu_bal 1
check "SWR3 the matrix ran: ten cells, 5 destinations x 2 modes" [llength $swm] 10
foreach cell $swm {
  lassign $cell nm rec rep rc typed
  check "SWR3 $nm: the typed plot line reached the log once, the replay rebuilds the recorded window" \
    [list $typed [expr {$rep eq $rec}] $rc] {1 1 0}
  check "SWR3 $nm: the recorded window holds the plot, in a second tab only under New Tab (non-vacuity)" \
    [list [expr {[lsearch -exact [concat {*}[lindex $rec 2 1]] p] >= 0}] [lindex $rec 0]] \
    [list 1 [expr {[string match */newtab $nm] ? 2 : 1}]]
}

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
  set gs12 [lay]
  pcall {wviewer::move_trace 0 0 4 $tok}
  check "SWG12 a trace dragged from subwindow 1 lands in subwindow 2's strip" \
    [trx 3] [concat $before4 c2]
  check "SWG12 ...and the strip it was alone on is gone (user request 2026-10-16)" \
    [ltags] {1 1 1 3}
  # the rows below were written on the layout a move used to leave (the empty
  # strip kept): put exactly that back, the pure move with no removal
  pcall {wviewer::undo $tok}
  wviewer::set_graphs $tok [wviewer::move_trace_in_graphs $gs12 0 0 4]
  set ::wviewer::target($tok) 4
  wviewer::regenerate $tok
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
  # the mode is the TARGET subwindow's (SW22): target first, then the mode
  wviewer::set_target_strip 0 $tok
  wviewer::set_plot_mode multi $tok
  pcall {wviewer::plot_signals $tok {a1 a2 a3} {} replace}
  check "SWD11 Replace under MULTI empties subwindow 1 (four strips) to one strip per signal, newest on top" \
    [list [ltags] [trx 0] [trx 1] [trx 2] [trx 3]] {{1 1 1 3} a3 a2 a1 {p1 p2}}
  check "SWD11 ...rects follow the model" [nrects] 4
  wviewer::set_plot_mode single $tok
  set ::sw_log {}
  pcall {wviewer::plot_signals $tok {b1} {} newsubwin}
  check "SWD12 New SubWin (passed by the call: the viewer has no setting of its own): a third subwindow, target, holding the batch" \
    [list [ltags] [wviewer::target_index $tok] [trx 4] [rprop 4 xgroup] [nrects]] {{1 1 1 3 4} 4 b1 4 5}
  set bb [wviewer::strip_bands_px $vdrw]
  set H [winfo height $vdrw]
  # pcall'd: under a sabotage strip 4 may not exist, and a bare expr on {}
  # would abort the band and delete every row after it from the verdict
  check "SWD12 ...the grid re-tiled: three subwindows, the new one bottom-LEFT" \
    [pcall {list [expr {[lindex $bb 4 0] < 1.5}] [expr {abs([lindex $bb 4 1] - $H / 2.0) < 1.5}]}] {1 1}
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
  # the dialog's Destination is ONE-SHOT (ruling 2026-10-16: the viewer
  # remembers no destination), so a reopened dialog offers Append again
  set w [pcall {wviewer::add_trace_dialog $tok}]
  set swd13_d [pcall {$w.dest get}]
  catch {destroy $w}
  check "SWD13 ...and the dialog's choice was one-shot: reopened, it offers Append" $swd13_d Append
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

  # ---- SWK*: per-subwindow settings in the real window (SW21-SW25) ----------
  # A fresh tab, two subwindows: strip 0 = a1 in subwindow 1, strip 1 = b1 in
  # subwindow 2, the target.
  proc send_ks {w ks st done} {
    for {set i 0} {$i < 100} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      focus -force [winfo toplevel $w]
      focus -force $w
      update
      if {[focus -displayof $w] eq $w} {
        event generate $w <KeyPress> -keysym $ks -state $st
        event generate $w <KeyRelease> -keysym $ks -state $st
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
      }
      after 50
    }
    return 0
  }
  proc stmode {} { lindex [$::vtop.wvstatus.l cget -text] 1 }
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::plot_signals $tok {a1}}
  pcall {wviewer::new_subwin $tok}
  pcall {wviewer::plot_signals $tok {b1}}
  check "SWK0 fixture: two subwindows, one strip each, the second the target" \
    [list [ltags] [trx 0] [trx 1] [wviewer::target_index $tok]] {{1 2} a1 b1 1}
  set pm $vtop.wvmenubar.options.plotmode
  pcall {$pm invoke 0}
  check "SWK1 Options > Plot Mode changes the TARGET subwindow only; the status bar says so" \
    [list [wviewer::plot_mode $tok] [wviewer::base_mode $tok] [stmode]] {multi single multi}
  lassign [mid 0] px py
  pcall {wviewer::click_target $vdrw $px $py}
  check "SWK2 a click in the other subwindow: the status bar follows the target" \
    [list [wviewer::target_index $tok] [wviewer::plot_mode $tok] [stmode]] {0 single single}
  wviewer::plot_mode_menu_post $tok $pm
  check "SWK2 ...and the Options entry offers the other mode of THIS subwindow" \
    [pcall {$pm entrycget 0 -label}] {Set Multi-plot Mode}
  lassign [mid 1] px py
  pcall {wviewer::click_target $vdrw $px $py}
  check "SWK2 back in subwindow 2: multi" [stmode] multi
  pcall {wviewer::plot_signals $tok {p1 p2}}
  check "SWK3 a plot into the multi subwindow gives each signal its own strip there; subwindow 1 untouched" \
    [list [ltags] [trx 0]] {{1 2 2 2} a1}
  pcall {wviewer::new_subwin $tok}
  check "SWK3 a new subwindow inherits the target's multi" \
    [list [ltags] [stmode]] {{1 2 2 2 3} multi}
  pcall {wviewer::close_subwin $tok}
  # ---- Ctrl-Shift-G / Ctrl-G ----
  check "SWK4 Ctrl-Shift-G is a WaveViewer default, Ctrl-G unchanged" \
    [list [string match {*grid_toggle_subwin_at %W*} [bind WaveViewer <Control-Shift-Key-G>]] \
          [string match {*grid_toggle_at %W*} [bind WaveViewer <Control-Key-g>]]] {1 1}
  set ::sw_log {}
  set ok [send_ks $vdrw G 5 {[wviewer::grid_shown $tok] == 0}]
  check "SWK4 a REAL Ctrl-Shift-G turns the grid off in the target subwindow only (the rect tokens)" \
    [list $ok [lmap i {0 1 2 3} {rprop $i grid}]] {1 {{} 0 0 0}}
  check "SWK4 ...logged once, and the Grid checkbutton shows the target's state" \
    [list [lsearch -all -inline -glob $::sw_log {wviewer::grid_toggle*}] $::wviewer::gridshow($tok)] \
    [list [list [list wviewer::grid_toggle_subwin 0 $tok]] 0]
  set ok [send_ks $vdrw g 4 {[wviewer::grid_shown $tok] == 1}]
  check "SWK5 a REAL Ctrl-G flips every subwindow individually: mixed stays mixed, inverted" \
    [list $ok [lmap i {0 1 2 3} {rprop $i grid}]] {1 {0 {} {} {}}}
  lassign [mid 0] px py
  pcall {wviewer::click_target $vdrw $px $py}
  check "SWK5 the Grid checkbutton follows the target (subwindow 1: off)" \
    $::wviewer::gridshow($tok) 0
  set gm $vtop.wvmenubar.graph
  set ix [pcall {$gm index {SubWin Grid}}]
  check "SWK6 Graph > SubWin Grid, with its accelerator" \
    [pcall {$gm entrycget $ix -accelerator}] Ctrl+Shift+G
  pcall {$gm invoke $ix}
  check "SWK6 ...invoking it turns the TARGET subwindow's grid back on only" \
    [lmap i {0 1 2 3} {rprop $i grid}] {{} {} {} {}}
  # ---- Ctrl-Shift-D ----
  lassign [mid 1] px py
  pcall {wviewer::click_target $vdrw $px $py}
  set ix [pcall {$gm index {Clear SubWin}}]
  check "SWK7 Graph > Clear SubWin, with its accelerator, right above Clear All" \
    [list [pcall {$gm entrycget $ix -accelerator}] [pcall {expr {[$gm index {Clear All}] - $ix}}]] {Ctrl+Shift+D 1}
  check "SWK7 Ctrl-Shift-D is a WaveViewer default" \
    [string match {*clear_target_subwin_at %W*} [bind WaveViewer <Control-Shift-Key-D>]] 1
  # Caps Lock matrix, REAL key events into recorders, for EVERY Ctrl-letter
  # pair of the viewer (ruling 2026-10-16: the case as typed decides). Tk
  # recomputes the keysym from the keycode and the state, so Lock+Ctrl gives
  # `D` and Lock+Shift+Ctrl gives `d` on :99 (the same with real XTest input).
  # Expected: state 4 the lower chord, 5 and 6 the upper, 7 the lower.
  set swk_procs {clear_all_at clear_target_subwin_at grid_toggle_at grid_toggle_subwin_at
    new_tab_at new_subwin_at close_tab_at close_subwin_at delete_all_markers_at
    browser_descend_at undo_at redo_at browser_toggle_at copy_traces_at
    close_window_at paste_traces_at}
  foreach p $swk_procs {
    rename ::wviewer::$p ::swk_orig_$p
    proc ::wviewer::$p {W} [list lappend ::swk_rec $p]
  }
  rename ::wviewer::graph_zoom ::swk_orig_graph_zoom
  proc ::wviewer::graph_zoom {token dir args} { lappend ::swk_rec zoom_$dir }
  proc ks_once {w ks st} {
    for {set i 0} {$i < 100} {incr i} {
      focus -force [winfo toplevel $w]
      focus -force $w
      update
      if {[focus -displayof $w] eq $w} {
        event generate $w <KeyPress> -keysym $ks -state $st
        event generate $w <KeyRelease> -keysym $ks -state $st
        update
        return 1
      }
      after 50
    }
    return 0
  }
  set swk_pairs {
    d clear_all_at clear_target_subwin_at   g grid_toggle_at grid_toggle_subwin_at
    n new_tab_at new_subwin_at              w close_tab_at close_subwin_at
    e delete_all_markers_at browser_descend_at  u undo_at redo_at
    z zoom_out zoom_in                      b browser_toggle_at {}
    c copy_traces_at {}                     q close_window_at {}
    v paste_traces_at {}
  }
  set mx {}; set want {}
  foreach {l lo up} $swk_pairs {
    foreach st {4 5 6 7} {
      set ::swk_rec {}
      set ks [expr {$st == 5 || $st == 6 ? [string toupper $l] : $l}]
      set ok [ks_once $vdrw $ks $st]
      lappend mx $l$st [expr {$ok ? $::swk_rec : {NOFOCUS}}]
      lappend want $l$st [expr {$st == 4 || $st == 7 ? $lo : $up}]
    }
  }
  # the server variant :99 cannot produce: Shift+Lock reported as `D`, Lock as
  # `d`, and Caps Lock with no Lock bit (`D` at state 4) -- the dispatcher itself
  set mv {}
  foreach {K st lo up} {D 7 <Control-Key-d> <Control-Shift-Key-D>
                        d 6 <Control-Key-d> <Control-Shift-Key-D>
                        N 7 <Control-Key-n> <Control-Key-N>
                        w 6 <Control-Key-w> <Control-Key-W>} {
    set ::swk_rec {}
    pcall {wviewer::case_key $vdrw $K $st $lo $up}
    lappend mv $K$st $::swk_rec
  }
  set ::swk_rec {}
  pcall {wviewer::case_key $vdrw D 4 <Control-Key-d> <Control-Shift-Key-D>}
  lappend mv D4 $::swk_rec
  # SWK18 (item 18 residue R3): key_filter's OWN case_keysym call, which the
  # matrix above cannot reach -- :99 already hands key_filter the typed case.
  # The server variant: Caps Lock + Ctrl-z reported as `z` (122) with Lock,
  # and Shift + Caps Lock + Ctrl-z reported as `Z` (90).
  set kf {}
  foreach {N st} {122 6 90 7 122 4 90 5} {
    set ::swk_rec {}
    pcall {wviewer::key_filter $vdrw 2 10 10 $N [format %c $N] $st}
    lappend kf $N/$st $::swk_rec
  }
  # ...and the keysym it FORWARDS to C carries the typed case too (Ctrl-a):
  # `xschem callback` and over_graph are recorders for these four calls only
  set ::swk_fwd {}
  rename ::xschem ::swk_orig_xschem
  proc ::xschem {args} {
    if {[lindex $args 0] eq {callback}} { lappend ::swk_fwd [lindex $args 5] ; return {} }
    return [uplevel 1 [list ::swk_orig_xschem {*}$args]]
  }
  rename ::wviewer::over_graph ::swk_orig_over_graph
  proc ::wviewer::over_graph {W} { return 1 }
  foreach {N st} {97 6 65 7 97 4 65 5} {
    pcall {wviewer::key_filter $vdrw 2 10 10 $N [format %c $N] $st}
  }
  rename ::wviewer::over_graph {}
  rename ::swk_orig_over_graph ::wviewer::over_graph
  rename ::xschem {}
  rename ::swk_orig_xschem ::xschem
  # case_key passes the base script's `break` on: called directly, and then a
  # REAL Caps Lock + Ctrl-g with a recorder on the next bindtag (the toplevel),
  # which only fires if the break was lost
  bind WaveViewer <Control-Key-F20> {lappend ::swk_rec brk ; break}
  set ::swk_rec {}
  set kb [list [catch {wviewer::case_key $vdrw F20 4 <Control-Key-F20> {}} r] $::swk_rec]
  bind WaveViewer <Control-Key-F20> {}
  set swk_tl [winfo toplevel $vdrw]
  set swk_tlb [bind $swk_tl <Control-Lock-Key-G>]
  bind $swk_tl <Control-Lock-Key-G> {+lappend ::swk_rec leak}
  set ::swk_rec {}
  set ok [ks_once $vdrw G 6]
  lappend kb [expr {$ok ? $::swk_rec : {NOFOCUS}}]
  bind $swk_tl <Control-Lock-Key-G> $swk_tlb
  foreach p $swk_procs {
    rename ::wviewer::$p {}
    rename ::swk_orig_$p ::wviewer::$p
  }
  rename ::wviewer::graph_zoom {}
  rename ::swk_orig_graph_zoom ::wviewer::graph_zoom
  check "SWK8 Caps Lock: the case as typed decides every Ctrl-letter pair (d g n w e u z b c q v, state 4 5 6 7)" \
    $mx $want
  check "SWK8 ...and when the server reports the other keysym case (or no Lock bit) the state still decides" \
    $mv {D7 clear_all_at d6 clear_target_subwin_at N7 new_tab_at w6 close_subwin_at D4 clear_target_subwin_at}
  check "SWK18 key_filter: Caps Lock + Ctrl-z zooms IN and Shift + Caps Lock + Ctrl-Z zooms OUT whichever keysym case the server reports" \
    $kf {122/6 zoom_in 90/7 zoom_out 122/4 zoom_out 90/5 zoom_in}
  check "SWK18 ...and Ctrl-a is forwarded to C in the typed case (65 = upper, 97 = lower)" \
    $::swk_fwd {65 97 97 65}
  check "SWK18 case_key passes break on (code 3), and a REAL Caps Lock + Ctrl-g stops at the viewer's tag (no leak to the toplevel)" \
    $kb {3 brk grid_toggle_subwin_at}
  set ub {}
  set cp8 [pcall {wviewer::case_pairs}]
  if {[string match ERR:* $cp8]} { set ub $cp8 ; set cp8 {} }
  foreach {l lo up} $cp8 {
    foreach seq [list <Control-Lock-Key-$l> <Control-Lock-Key-[string toupper $l]> \
                      <Control-Shift-Lock-Key-$l> <Control-Shift-Lock-Key-[string toupper $l]>] {
      if {![string match {wviewer::case_key %W %K %s *} [bind WaveViewer $seq]]} { lappend ub $seq }
    }
  }
  check "SWK8 ...every Lock chord of every pair, both keysym cases, is the dispatcher" $ub {}
  check "SWK8 ...and the recorders left the plots alone" [list [ltags] [trx 0]] {{1 2 2 2} a1}
  set ::sw_log {}
  set ok [send_ks $vdrw D 5 {[llength [lay]] == 2}]
  check "SWK8 a REAL Ctrl-Shift-D empties the TARGET subwindow; subwindow 1 untouched; Clear All did NOT fire" \
    [list $ok [ltags] [trx 0] [trx 1] [wviewer::sw_count [lay]]] {1 {1 2} a1 {} 2}
  check "SWK8 ...one line, Clear SubWin's" \
    [lsearch -all -inline -glob $::sw_log {wviewer::clear*}] [list [list wviewer::clear_target_subwin $tok]]
  check "SWK8 ...the cleared subwindow keeps its mode" [stmode] multi
  pcall {wviewer::undo $tok}
  check "SWK8 u brings the cleared plots back" [ltags] {1 2 2 2}
  # the REAL handlers through the dispatcher (no recorders): Caps Lock +
  # Ctrl-d is Clear SubWin, Caps Lock + Ctrl-Shift-D is Clear All
  set ::sw_log {}
  set ok [send_ks $vdrw D 6 {[llength [lay]] == 2}]
  check "SWK8 a REAL Caps Lock + Ctrl-d (state 6) empties the TARGET subwindow, as Ctrl-Shift-D does" \
    [list $ok [ltags] [trx 0] [trx 1] [wviewer::sw_count [lay]] \
          [lsearch -all -inline -glob $::sw_log {wviewer::clear*}]] \
    [list 1 {1 2} a1 {} 2 [list [list wviewer::clear_target_subwin $tok]]]
  pcall {wviewer::undo $tok}
  check "SWK8 ...and u brings them back" [ltags] {1 2 2 2}
  # SWK12: the menu entry's own -command, run as Tk would run it, with the
  # target in subwindow 2 (which holds three strips)
  lassign [mid 1] px py
  pcall {wviewer::click_target $vdrw $px $py}
  set ::sw_log {}
  set cmd [pcall {$gm entrycget [$gm index {Clear SubWin}] -command}]
  pcall {uplevel #0 $cmd}
  check "SWK12 Graph > Clear SubWin's -command empties the TARGET subwindow only; subwindow 1 keeps a1" \
    [list [ltags] [trx 0] [trx 1] [wviewer::target_index $tok]] {{1 2} a1 {} 1}
  check "SWK12 ...one line, Clear SubWin's, and u brings the plots back" \
    [list [lsearch -all -inline -glob $::sw_log {wviewer::clear*}] [pcall {wviewer::undo $tok}] [ltags]] \
    [list [list [list wviewer::clear_target_subwin $tok]] 1 {1 2 2 2}]
  # ---- tabs and state ----
  # select_tab takes a tab ID, not an index
  set ntab [wviewer::dget [lindex [wviewer::tab_records $tok] [wviewer::tab_index $tok]] id {}]
  pcall {wviewer::new_tab $tok}
  check "SWK9 a new tab starts with the target's mode" [stmode] multi
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::select_tab $ntab $tok}
  check "SWK9 back on the subwindowed tab: its target's mode is in the status bar" \
    [list [stmode] [wviewer::plot_mode $tok]] {multi multi}
  set swtags [ltags]
  set snap [pcall {wviewer::snapshot $tok {}}]
  pcall {wviewer::close $tok}
  pcall {wviewer::restore $tok $snap {} {}}
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  viewer_ready $vtop
  pcall {wviewer::select_tab $ntab $tok}
  set modes {}
  foreach gi {0 1} {
    pcall {wviewer::set_target_strip $gi $tok}
    lappend modes [wviewer::plot_mode $tok]
  }
  check "SWK10 save / close / restore keeps each subwindow's mode and grid" \
    [list [ltags] $modes [lmap i {0 1 2 3} {rprop $i grid}]] [list $swtags {single multi} {{} {} {} {}}]
  # ---- SWK11: the status bar and Grid checkbutton follow a target that moves
  # because its subwindow CLOSED (regenerate's push; neither set_target_strip
  # nor a click is involved)
  pcall {wviewer::set_target_strip 1 $tok}
  pcall {wviewer::grid_toggle_subwin 0 $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  set pre [list [stmode] $::wviewer::gridshow($tok)]
  pcall {wviewer::close_subwin $tok 0}
  check "SWK11 closing the single, grid-on target: the bar and the checkbutton show the survivor (multi, grid off)" \
    [list $pre [stmode] $::wviewer::gridshow($tok) [wviewer::plot_mode $tok] [wviewer::grid_shown $tok]] \
    {{single 1} multi 0 multi 0}

  # ---- SWK13: a ONE-tab state keeps the window's own grid (SW25) ----------
  set rcsave [expr {[info exists ::wviewer_grid_show] ? [list $::wviewer_grid_show] : {}}]
  set ::wviewer_grid_show 1
  pcall {wviewer::close $tok}
  set one [dict create open 1 sharedx 0 graphs [list [G a1]] mode single target 0]
  pcall {wviewer::restore $tok [dict replace $one grid 0] {} {}}
  set g0 [list [llength [wviewer::tab_records $tok]] [wviewer::grid_shown $tok]]
  set snap [pcall {wviewer::snapshot $tok {}}]
  pcall {wviewer::close $tok}
  pcall {wviewer::restore $tok $snap {} {}}
  set g1 [list [wviewer::dget $snap grid -] [wviewer::grid_shown $tok] [rprop 0 grid]]
  pcall {wviewer::close $tok}
  pcall {wviewer::restore $tok $one {} {}}
  set g2 [list [wviewer::grid_shown $tok] [dict exists [pcall {wviewer::snapshot $tok {}}] grid]]
  if {$rcsave eq {}} { unset ::wviewer_grid_show } else { set ::wviewer_grid_show [lindex $rcsave 0] }
  check "SWK13 a one-tab state saved with the grid off restores it off; an old state (no key) reads the rc default" \
    [list $g0 $g1 $g2] {{1 0} {0 0 0} {1 0}}
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  viewer_ready $vtop

  # ---- SWK17: RIGHT-CLICK MENUS ON ONE-TRACE STRIPS (issue 1662) -----------
  # Multi mode gives each signal its own strip, and both menu gates used to
  # refuse a strip with fewer than two traces, so right-click posted nothing
  # anywhere. REAL ButtonPress-3 / ButtonRelease-3 on the canvas and the REAL
  # tk_popup (no spy), on every strip, with two subwindows and then one.
  proc sk_ev {seq args} {
    set ::skt [expr {$::skt + 1000}]
    event generate $::vdrw $seq -time $::skt {*}$args
  }
  set ::skt 500000000
  # {px py} on strip gi's trace (want 1) or on its empty plot body (want 0)
  proc sk_px {gi want} {
    lassign [lindex [wviewer::strip_bands_px $::vdrw] $gi] x1 y1 x2 y2
    if {$x2 eq {}} { return {} }
    foreach fx {0.5 0.4 0.6 0.3 0.7 0.2 0.8} {
      set px [expr {int($x1 + $fx * ($x2 - $x1))}]
      for {set py [expr {int($y1) + 2}]} {$py < $y2 - 1} {incr py 2} {
        if {[wviewer::strip_at_pixel $::vdrw $px $py] != $gi} { continue }
        set on [expr {[wviewer::trace_at $::vdrw $gi $px $py] >= 0}]
        if {$want && $on} { return [list $px $py] }
        if {!$want && !$on && [wviewer::plotbox_at $::vdrw $gi $px $py]} { return [list $px $py] }
      }
    }
    return {}
  }
  # right-click at {px py}; answers {mapped entries} of whichever menu posted,
  # each entry {label state} (a separator reads `-`), then takes it down
  proc sk_rmb {xy} {
    if {![llength $xy]} { return NOPIXEL }
    lassign $xy px py
    foreach n {wvtracemenu wvstripmenu} { catch {destroy $::vtop.$n} }
    sk_ev <Motion> -x $px -y $py
    update
    sk_ev <ButtonPress-3>   -x $px -y $py -button 3
    sk_ev <ButtonRelease-3> -x $px -y $py -button 3 -state 0x400
    update
    set out NOMENU
    foreach n {wvtracemenu wvstripmenu} {
      set m $::vtop.$n
      if {![winfo exists $m]} { continue }
      set ents {}
      for {set i 0} {$i <= [$m index end]} {incr i} {
        if {[$m type $i] eq {separator}} { lappend ents - ; continue }
        lappend ents [list [$m entrycget $i -label] [$m entrycget $i -state]]
      }
      set out [list $n [winfo ismapped $m] [lrange $ents 2 end]]
    }
    catch {wviewer::trace_menu_unpost $::tok}
    catch {wviewer::strip_menu_unpost $::tok}
    update
    return $out
  }
  # SWK13 closed and restored the window, so its context holds no raw: load
  # the fixture's again, or nothing is drawn and no pixel is on a trace
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvsub.raw dc vsweep 0 1.0 0.1}
  foreach v {a1 a2 a3 b1 b2 c1 c2 p1 p2} { pcall {xschem raw add $v "vsweep 1 +"} }
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::plot_signals $tok {a1 a2}}
  pcall {wviewer::new_subwin $tok}
  pcall {wviewer::plot_signals $tok {b1 b2}}
  pcall {wviewer::delete_empty_strips $tok}
  pcall {wviewer::fit $tok}
  update
  set sk_tm {{Move to Separate Strip} disabled} ; set sk_sm {{Split Strip} disabled}
  set sk_twant [list wvtracemenu 1 [list $sk_tm - {{Delete Trace} normal}]]
  check "SWK17 fixture: multi mode, two subwindows, every strip ONE trace" \
    [list [wviewer::sw_count [lay]] [lsort -unique [lmap g [lay] {llength [wviewer::dget $g traces {}]}]]] {2 1}
  set got {}; set want {}
  for {set gi 0} {$gi < [llength [lay]]} {incr gi} {
    lappend got $gi [sk_rmb [sk_px $gi 1]] [sk_rmb [sk_px $gi 0]]
    lappend want $gi $sk_twant [list wvstripmenu 1 [list $sk_sm]]
  }
  check "SWK17 a REAL right-click posts the trace menu on every one-trace strip of both subwindows (Move greyed, Delete live), and the strip menu on its empty space (Split greyed)" \
    $got $want
  check "SWK17 ...and posting changed nothing" \
    [list [wviewer::sw_count [lay]] [lmap g [lay] {llength [wviewer::dget $g traces {}]}]] \
    [list 2 [lrepeat [llength [lay]] 1]]
  pcall {wviewer::close_subwin $tok}
  pcall {wviewer::fit $tok}
  update
  set got {}; set want {}
  for {set gi 0} {$gi < [llength [lay]]} {incr gi} {
    lappend got $gi [sk_rmb [sk_px $gi 1]] [sk_rmb [sk_px $gi 0]]
    lappend want $gi $sk_twant [list wvstripmenu 1 [list $sk_sm]]
  }
  check "SWK17 ...and with ONE subwindow" [list [wviewer::sw_count [lay]] $got] [list 1 $want]
  # the control: a two-trace strip still offers live entries
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::plot_signals $tok {c1}}
  pcall {wviewer::fit $tok}
  update
  check "SWK17 control: on a two-trace strip both entries are live" \
    [list [lindex [sk_rmb [sk_px 0 1]] 2 0] [lindex [sk_rmb [sk_px 0 0]] 2 0]] \
    {{{Move to Separate Strip} normal} {{Split Strip} normal}}

  # Caps Lock + Ctrl-Shift-D through the dispatcher to the REAL Clear All (no
  # recorder). Here because Clear All takes no undo point, and SWG15 opens a
  # fresh tab next.
  set ::sw_log {}
  set ok [send_ks $vdrw d 7 {[llength [lay]] == 1}]
  check "SWK8 a REAL Caps Lock + Ctrl-Shift-D (state 7) is Clear All, as Ctrl-d is" \
    [list $ok [llength [lay]] [trx 0] [lsearch -all -inline -glob $::sw_log {wviewer::clear*}]] \
    [list 1 1 {} [list [list wviewer::clear_all $tok]]]

  # ---- SWG15: dragging a strip's SOLE trace into another subwindow removes
  # the emptied strip (user request 2026-10-16); a REAL LMB drag, one undo step
  proc sk_drag {from to} {
    lassign $from px py
    lassign $to tx ty
    sk_ev <ButtonPress-1> -x $px -y $py -button 1
    sk_ev <B1-Motion> -x [expr {$px + 1}] -y [expr {$py + 1}] -state 0x100
    update
    sk_ev <B1-Motion> -x $tx -y $ty -state 0x100
    update
    sk_ev <ButtonRelease-1> -x $tx -y $ty -button 1 -state 0x100
    update
  }
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::plot_signals $tok {a1 a2}}
  pcall {wviewer::new_subwin $tok}
  pcall {wviewer::plot_signals $tok {b1}}
  pcall {wviewer::delete_empty_strips $tok}
  pcall {wviewer::fit $tok}
  update
  set pre [list [ltags] [lmap gi [lsearch -all [ltags] *] {trx $gi}]]
  check "SWG15 fixture: subwindow 1 two one-trace strips, subwindow 2 one" \
    [list [ltags] [llength [trx 0]] [llength [trx 1]] [trx 2]] {{1 1 2} 1 1 b1}
  set mov [trx 1]
  set ::sw_log {}
  sk_drag [sk_px 1 1] [mid 2]
  check "SWG15 a REAL drag of strip 2's sole trace into subwindow 2: the emptied strip is gone, the trace is there" \
    [list [ltags] [trx 1] [lindex [trx 1] end] [wviewer::target_index $tok]] \
    [list {1 2} [list b1 $mov] $mov 1]
  check "SWG15 ...one log line, the move itself" \
    [lsearch -all -inline -glob $::sw_log {wviewer::move*}] [list [list wviewer::move_trace 1 0 2 $tok]]
  pcall {wviewer::undo $tok}
  check "SWG15 one u restores the strip and the trace" \
    [list [ltags] [lmap gi [lsearch -all [ltags] *] {trx $gi}]] $pre
  # the last strip of its subwindow stays, empty (emptied_subwin_keeps_strip)
  pcall {wviewer::fit $tok}
  update
  sk_drag [sk_px 2 1] [mid 0]
  check "SWG15 a subwindow's LAST strip emptied into another subwindow stays, empty" \
    [list [ltags] [trx 2] [wviewer::sw_count [lay]]] {{1 1 2} {} 2}
  pcall {wviewer::undo $tok}
  # the control: within ONE subwindow an emptied strip stays
  pcall {wviewer::fit $tok}
  update
  sk_drag [sk_px 1 1] [mid 0]
  check "SWG15 control: a drag WITHIN a subwindow keeps the emptied strip" \
    [list [ltags] [trx 1]] {{1 1 2} {}}
  # the user's own path: a run's auto-plot in multi mode (auto_plot_strips +
  # add_trace, what ase::ui::auto_plot does), then a New SubWin; every run
  # strip carries `auto 1`
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode multi $tok}
  set gis [pcall {wviewer::auto_plot_strips $tok 2}]
  pcall {wviewer::regenerate $tok}
  foreach gi $gis ex {a1 a2} { pcall {wviewer::add_trace $tok $gi $ex} }
  pcall {wviewer::new_subwin $tok}
  pcall {wviewer::plot_signals $tok {b1}}
  pcall {wviewer::delete_empty_strips $tok}
  pcall {wviewer::fit $tok}
  update
  set aflags {}
  foreach G [lay] { lappend aflags [wviewer::dget $G auto 0] }
  check "SWG15 auto fixture: subwindow 1 two auto-plot strips of one trace, subwindow 2 one" \
    [list [ltags] [llength [trx 0]] [llength [trx 1]] [trx 2] $aflags] {{1 1 2} 1 1 b1 {1 1 0}}
  set mov [trx 1]
  set ::sw_log {}
  sk_drag [sk_px 1 1] [mid 2]
  check "SWG15 a REAL drag of an auto-plot strip's sole trace into subwindow 2 removes the emptied strip" \
    [list [ltags] [trx 1] [wviewer::target_index $tok] \
          [lsearch -all -inline -glob $::sw_log {wviewer::move*}]] \
    [list {1 2} [list b1 $mov] 1 [list [list wviewer::move_trace 1 0 2 $tok]]]

  # ---- SWG16: a REAL `e` (user report 2026-10-16). The user's path: a
  # multi-plot run (auto_plot_strips + add_trace, as ase::ui::auto_plot does),
  # two New SubWins, a trace dragged onto its neighbour in the TARGET subwindow
  # and another in a NON-target one, the last subwindow left empty. One `e`
  # removes all three empty strips, in every subwindow.
  proc sg16_fixture {} {
    pcall {wviewer::new_tab $::tok}
    pcall {wviewer::set_plot_mode multi $::tok}
    set gis [pcall {wviewer::auto_plot_strips $::tok 3}]
    pcall {wviewer::regenerate $::tok}
    foreach gi $gis ex {a1 a2 a3} { pcall {wviewer::add_trace $::tok $gi $ex} }
    pcall {wviewer::new_subwin $::tok}
    pcall {wviewer::plot_signals $::tok {b1 b2}}
    pcall {wviewer::new_subwin $::tok}
    pcall {wviewer::move_trace 4 0 3 $::tok}
    pcall {wviewer::move_trace 1 0 0 $::tok}
    pcall {wviewer::set_target_strip 0 $::tok}
    pcall {wviewer::fit $::tok}
    update
  }
  proc sg16_state {} {
    list [ltags] [lmap G [lay] {llength [wviewer::dget $G traces {}]}] \
         [lmap G [lay] {wviewer::dget $G auto 0}] [wviewer::target_index $::tok]
  }
  sg16_fixture
  set pre [sg16_state]
  check "SWG16 fixture: an emptied run strip in the target subwindow, an emptied strip in another, an empty subwindow" \
    $pre {{1 1 1 2 2 3} {2 0 1 2 0 0} {1 1 1 0 0 0} 0}
  set ::sw_log {}
  set ok [send_ks $vdrw e 0 {[llength [lay]] == 3}]
  check "SWG16 a REAL `e` (Caps Lock off) deletes all three, the empty subwindow with them" \
    [list $ok [sg16_state] [wviewer::sw_count [lay]]] {1 {{1 1 2} {2 1 2} {1 1 0} 0} 2}
  check "SWG16 ...one log line" \
    [lsearch -all -inline -glob $::sw_log {wviewer::delete_empty*}] [list [list wviewer::delete_empty_strips $tok]]
  pcall {wviewer::undo $tok}
  check "SWG16 one u restores every strip" [sg16_state] $pre
  # Caps Lock on: the letter as typed is upper case, so `e` is `E`, exactly as
  # Shift-e is (the user's case ruling of 2026-10-16) -- it does not delete.
  # The Shift-e twin is the control: both must reach the same binding.
  rename wviewer::browser_descend_at wviewer::__sg16_real_descend
  proc wviewer::browser_descend_at {W} { lappend ::sg16_desc $W }
  foreach {st what} {2 {Caps Lock + e} 1 {Shift-e}} {
    set ::sg16_desc {}
    set ::sw_log {}
    set ok [send_ks $vdrw e $st {[llength $::sg16_desc] > 0}]
    check "SWG16 a REAL $what (state $st) is typed E: Descend runs, no strip is deleted" \
      [list $ok [llength $::sg16_desc] [sg16_state] \
            [lsearch -all -inline -glob $::sw_log {wviewer::delete_empty*}]] [list 1 1 $pre {}]
  }
  rename wviewer::browser_descend_at {}
  rename wviewer::__sg16_real_descend wviewer::browser_descend_at

  # ==========================================================================
  # SWA* -- THE aA BUTTON in the real window (spec SW28-SW31, item 22). Real
  # <Motion> events through the canvas' own bindtags, with `update` BEFORE each
  # `-when now` motion and never between a motion and what reads it (issue
  # 1659), and an explicit `-time` on every one (with none, Tk stamps every
  # event alike and any sequence would pass). Clicks are Enter -> press ->
  # release with coordinates (S29k's lesson). Waits are `vwait` on an `after`.
  # ==========================================================================
  set ::swa_t 900000000
  proc swa_mot {x y {s 0} {dt 50}} {
    set ::swa_t [expr {$::swa_t + $dt}]
    set ::swa_last [list $x $y]
    update
    event generate $::vdrw <Motion> -x $x -y $y -state $s -time $::swa_t -when now
  }
  # a fresh gesture: time moves well past the window, the buffer is emptied
  proc swa_gap {} { set ::swa_t [expr {$::swa_t + 5000}] ; pcall {wviewer::fsz_clear $::tok} }
  proc fszb {k} { return $::vdrw.fsz$k }
  proc placed {k} {
    set b [fszb $k]
    if {![winfo exists $b]} { return NOBUTTON }
    return [expr {[llength [place info $b]] > 0}]
  }
  proc placed_all {} {
    set out {}
    foreach w [lsort [winfo children $::vdrw]] {
      if {[regexp {\.fsz([0-9]+)$} $w -> k]} { lappend out $k [placed $k] }
    }
    return $out
  }
  # every helper answers a sentinel rather than raising, so a missing proc
  # reddens its own rows instead of aborting the band
  proc swa_cells {} {
    return [pcall {wviewer::fsz_cells_px [lay] [wviewer::strip_bands_px $::vdrw]}]
  }
  proc swa_cell {k} {
    set c [swa_cells]
    if {[catch {dict get $c $k} r] || [llength $r] != 4} { return {0 0 0 0} }
    return $r
  }
  # the corner a shown button must sit at, derived from the canvas' own bands
  proc swa_inset {} { return [expr {(int($::graph_active_strip_width) + 1) / 2 + 2}] }
  proc swa_corner {k} {
    set c [swa_cell $k]
    return [list [expr {int(round([lindex $c 2])) - [swa_inset]}] [expr {int(round([lindex $c 1])) + [swa_inset]}]]
  }
  # where the button really is: its top-right, in canvas pixels, from winfo
  proc swa_at {k} {
    update
    set b [fszb $k]
    if {![winfo exists $b]} { return NOBUTTON }
    return [list [expr {[winfo rootx $b] + [winfo width $b] - [winfo rootx $::vdrw]}] \
                 [expr {[winfo rooty $b] - [winfo rooty $::vdrw]}]]
  }
  proc swa_zone_px {k} {
    set c [swa_cell $k]
    return [list [expr {int([lindex $c 2]) - 10}] [expr {int([lindex $c 1]) + 10}]]
  }
  proc swa_mid {k} {
    set c [swa_cell $k]
    return [list [expr {int(([lindex $c 0] + [lindex $c 2]) / 2)}] [expr {int(([lindex $c 1] + [lindex $c 3]) / 2)}]]
  }
  # a flick of n steps of (+d,-d) every 50 ms from {x y}
  proc swa_flick {xy {n 6} {d 20} {s 0}} {
    lassign $xy x y
    swa_mot $x $y $s
    for {set i 1} {$i <= $n} {incr i} { swa_mot [expr {$x + $i * $d}] [expr {$y - $i * $d}] $s }
  }
  proc swa_wait {ms} {
    set ::swa_done 0
    after $ms {set ::swa_done 1}
    vwait ::swa_done
  }
  proc swa_click {k {ctrl 0}} {
    set b [fszb $k]
    if {$ctrl} {
      pcall {event generate $b <Enter> -x 5 -y 5}
      pcall {event generate $b <Control-Button-1> -x 5 -y 5}
      pcall {event generate $b <ButtonRelease-1> -x 5 -y 5 -state 4}
    } else {
      pcall {event generate $b <Enter> -x 5 -y 5}
      pcall {event generate $b <Button-1> -x 5 -y 5}
      pcall {event generate $b <ButtonRelease-1> -x 5 -y 5}
    }
    update
  }
  proc swa_fonts {} { pcall {wviewer::strip_fonts [lay] [wviewer::font_base $::tok]} }
  proc swa_px {pt} { string trim [string map {textpx= {}} [pcall {wviewer::font_props $pt [tk scaling]}]] }
  proc swa_cget {k opt} { pcall [list [fszb $k] cget $opt] }

  set ::wviewer_text_size 14
  catch {unset ::wviewer::textlast($tok)}
  set swa_reveal_saved [expr {[info exists ::wviewer_aa_reveal_ms] ? $::wviewer_aa_reveal_ms : 3000}]
  if {[catch {
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvsub.raw dc vsweep 0 1.0 0.1}
  foreach v {a1 a2 a3 b1 b2 c1 c2 p1 p2} { pcall {xschem raw add $v "vsweep 1 +"} }
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::plot_signals $tok {a1}}
  pcall {wviewer::add_graph $tok}
  update

  # ---- SWF3 (display): the rect tokens ----------------------------------------
  check "SWF3 one sub-window: every viewer strip carries textpx = 14 pt at tk scaling, no swfont key" \
    [list [lmap i {0 1} {rprop $i textpx}] [lmap g [lay] {wviewer::dget $g swfont -}]] \
    [list [list [swa_px 14] [swa_px 14]] {- -}]

  # ---- SWA1: hidden by default ---------------------------------------------------
  check "SWA1 one sub-window: one aA button, built and hidden; the canvas is untouched" \
    [list [placed_all] [winfo exists $vdrw] [winfo ismapped $vdrw]] {{1 0} 1 1}
  check "SWA1 the button mirrors the Calculator's: aA, no focus, padx 3, pady 0, the palette's colours" \
    [lmap o {-text -takefocus -padx -pady -background -activebackground -foreground} {swa_cget 1 $o}] \
    [list aA 0 3 0 [ase::palette panel] [ase::palette header] [ase::palette fieldfg]]
  check "SWA1 ...its bindtags leave out the toplevel (no raise_dialog / retitle on map)" \
    [pcall {bindtags [fszb 1]}] [list [fszb 1] WvFsz Button all]
  check "SWF12 the gesture binding: Ctrl+click steps -1 and breaks; the plain click is -command +1" \
    [list [string match {*text_step*-1*break*} [pcall {bind [fszb 1] <Control-Button-1>}]] [swa_cget 1 -command]] \
    [list 1 [list wviewer::text_step $tok 1 1]]
  pcall {wviewer::new_subwin $tok}
  update
  check "SWA1 a new sub-window gets its own button, hidden" [placed_all] {1 0 2 0}

  # ---- SWA2: hover -----------------------------------------------------------------
  swa_gap
  lassign [swa_zone_px 2] zx zy
  swa_mot $zx $zy
  set mx [xschem get mousex] ; set my [xschem get mousey]
  set wantx [expr {$zx * [xschem get zoom] - [xschem get xorigin]}]
  set wanty [expr {$zy * [xschem get zoom] - [xschem get yorigin]}]
  check "SWA2 the zone pixel round-trips through the canvas (xschem get mousex/mousey)" \
    [list [expr {abs($mx - $wantx) < 1e-6 * max(1.0, abs($wantx))}] [expr {abs($my - $wanty) < 1e-6 * max(1.0, abs($wanty))}]] {1 1}
  check "SWA2 the pointer in sub-window 2's corner zone shows button 2 ONLY" [placed_all] {1 0 2 1}
  check "SWA2 ...at the sub-window's top-right corner, inset clear of the frame (derived, and where winfo puts it)" \
    [list [swa_at 2] [swa_corner 2]] [list [swa_corner 2] [swa_corner 2]]
  lassign [swa_mid 1] cx cy
  swa_mot $cx $cy
  update
  check "SWA2 leaving the zone hides it" [placed_all] {1 0 2 0}
  # SWA2b: the SHIPPED zone's edges on the real canvas. The legs above move far
  # outside any zone, and SWZ10 passes 64/40 as literals, so a zone of any size
  # passed them. Just inside and just outside each edge of 64 x 40, from the
  # cell's own corner.
  set c2 [swa_cell 2]
  set zx2 [expr {int(floor([lindex $c2 2]))}]
  set zy1 [expr {int(ceil([lindex $c2 1]))}]
  set e {}
  foreach {x y} [list [expr {$zx2 - 10}] [expr {$zy1 + 10}] [expr {$zx2 - 66}] [expr {$zy1 + 10}] \
                      [expr {$zx2 - 62}] [expr {$zy1 + 38}] [expr {$zx2 - 10}] [expr {$zy1 + 42}]] {
    swa_gap
    swa_mot $x $y
    lappend e [placed 2]
  }
  check "SWA2b the shipped zone on the real canvas: in 10 px from the corner, out 66 px left, in at 62/38, out 42 px down" \
    $e {1 0 1 0}
  swa_gap
  swa_mot $cx $cy

  # ---- SWA3: a flick reveals for reveal_ms, then hides -------------------------
  set ::wviewer_aa_reveal_ms 300
  swa_gap
  lassign [swa_mid 1] cx cy
  swa_flick [list [expr {$cx - 60}] [expr {$cy + 60}]]
  check "SWA3 a flick up-right (120 px, 45 deg, 300 ms) in sub-window 1 reveals button 1 only, timer armed" \
    [list [placed_all] [info exists ::wviewer::fszafter($tok,1)]] {{1 1 2 0} 1}
  check "SWA3 ...at its corner" [swa_at 1] [swa_corner 1]
  swa_wait 450
  check "SWA3 ...and after reveal_ms it hides by itself" [list [placed_all] [info exists ::wviewer::fszafter($tok,1)]] {{1 0 2 0} 0}
  swa_gap
  swa_flick [list [expr {$cx - 60}] [expr {$cy + 60}]] 3 20
  check "SWA3 control: 85 px is too short, nothing shows" [placed_all] {1 0 2 0}

  # ---- SWA4: a repeat flick re-arms the timer ------------------------------------
  set ::wviewer_aa_reveal_ms 400
  swa_gap
  swa_flick [list [expr {$cx - 60}] [expr {$cy + 60}]]
  swa_wait 250
  swa_gap
  swa_flick [list [expr {$cx - 60}] [expr {$cy + 60}]]
  swa_wait 250
  set mid [placed_all]
  swa_wait 400
  check "SWA4 a second flick re-arms: still shown 250 ms after it (500 ms after the first), gone after" \
    [list $mid [placed_all]] {{1 1 2 0} {1 0 2 0}}

  # ---- SWA5 / SWA12: a held LMB is no flick ---------------------------------------
  if {[info commands wviewer::fsz_motion] eq {}} { proc wviewer::fsz_motion {args} {} }
  rename wviewer::fsz_motion wviewer::__swa_fsz_motion
  proc wviewer::fsz_motion {token x y s t} {
    lappend ::swa_states $s
    return [wviewer::__swa_fsz_motion $token $x $y $s $t]
  }
  set ::swa_states {}
  swa_gap
  swa_flick [list [expr {$cx - 60}] [expr {$cy + 60}]] 6 20 256
  check "SWA5 Button1 held: the up-right drag motion REACHES the gesture (state 256 seen) and reveals nothing" \
    [list [expr {[lsearch -exact $::swa_states 256] >= 0}] [placed_all]] {1 {1 0 2 0}}
  # SWA12: the real press / drag / release, then motion inside the window
  set ::swa_states {}
  swa_gap
  set sx [expr {$cx - 60}] ; set sy [expr {$cy + 60}]
  swa_mot $sx $sy
  set ::swa_t [expr {$::swa_t + 20}]
  event generate $vdrw <ButtonPress-1> -x $sx -y $sy -button 1 -time $::swa_t -when now
  for {set i 1} {$i <= 5} {incr i} { swa_mot [expr {$sx + $i * 20}] [expr {$sy - $i * 20}] 256 }
  set ::swa_t [expr {$::swa_t + 20}]
  event generate $vdrw <ButtonRelease-1> -x [expr {$sx + 100}] -y [expr {$sy - 100}] -button 1 -state 256 -time $::swa_t -when now
  swa_mot [expr {$sx + 110}] [expr {$sy - 110}] 0 20
  check "SWA12 a B1 drag up-right, released, then a motion within 400 ms does not reveal (the drag reached the tag)" \
    [list [expr {[lsearch -exact $::swa_states 256] >= 0}] [placed_all]] {1 {1 0 2 0}}
  rename wviewer::fsz_motion {}
  rename wviewer::__swa_fsz_motion wviewer::fsz_motion
  pcall {wviewer::fit $tok}
  update

  # ---- SWA13: a Leave/Enter jump is no flick -------------------------------------
  lassign [swa_mid 1] cx cy
  swa_gap
  swa_mot [expr {$cx - 60}] [expr {$cy + 60}]
  set ::swa_t [expr {$::swa_t + 20}]
  event generate $vdrw <Leave> -x [expr {$cx - 60}] -y [expr {$cy + 60}] -time $::swa_t -when now
  set ::swa_t [expr {$::swa_t + 20}]
  event generate $vdrw <Enter> -x [expr {$cx + 60}] -y [expr {$cy - 60}] -time $::swa_t -when now
  swa_mot [expr {$cx + 60}] [expr {$cy - 60}]
  update
  set jump [placed_all]
  swa_gap
  swa_mot [expr {$cx - 60}] [expr {$cy + 60}]
  swa_mot [expr {$cx + 60}] [expr {$cy - 60}]
  set ctl [placed_all]
  swa_wait 450
  check "SWA13 leaving and re-entering 170 px up-right is no flick; the same jump with no Leave between is one (control)" \
    [list $jump $ctl] {{1 0 2 0} {1 1 2 0}}

  # ---- SWA6 / SWA11 / SWA7 / SWF4 (display): the click ----------------------------
  pcall {wviewer::set_target_strip 0 $tok}
  update
  focus -force $vdrw
  update
  set foc0 [focus]
  set stk0 [wm stackorder .]
  swa_gap
  lassign [swa_zone_px 2] zx zy
  swa_mot $zx $zy
  set ::sw_echo {}
  set ::sw_log {}
  swa_click 2
  check "SWA6 a REAL click on aA in sub-window 2 raises THAT sub-window by one; the button stays up" \
    [list [swa_fonts] [placed_all] [lmap i [lsearch -all [ltags] 2] {rprop $i textpx}]] \
    [list {14 14 15} {1 0 2 1} [list [swa_px 15]]]
  check "SWA6 ...one resolved log line and the Calculator's sentence with the rc hint" \
    [list [lsearch -all -inline -glob $::sw_log {wviewer::set_text_size*}] [lindex $::sw_echo end]] \
    [list [list [list wviewer::set_text_size 15 $tok 2]] [pcall {wviewer::text_size_msg 15}]]
  swa_click 2
  check "SWA11 a second click without moving finds the button still there and steps again" \
    [list [swa_fonts] [placed_all]] {{14 14 16} {1 0 2 1}}
  swa_click 2 1
  check "SWA6 Ctrl+click lowers by one, and exactly one arm fires" [swa_fonts] {14 14 15}
  check "SWF4 (display) only sub-window 2's rects moved: sub-window 1 still at 14 pt" \
    [lmap i {0 1} {rprop $i textpx}] [list [swa_px 14] [swa_px 14]]
  check "SWA7 the click took no focus and moved no toplevel" [list [focus] [wm stackorder .]] [list $foc0 $stk0]
  pcall {event generate [fszb 2] <Leave>}
  swa_mot [lindex [swa_mid 1] 0] [lindex [swa_mid 1] 1]
  update

  # ---- SWA14: mapping the button restacks no dialog -----------------------------
  catch {destroy .graphdialog}
  toplevel .graphdialog
  # ⚠ NEVER OVER THE VIEWER. Measured: openbox places the viewer differently
  # from run to run (+1+250 on one, over +50+50 on others), and when the dialog
  # overlaps the viewer's canvas, the `lower` below EXPOSES the canvas, whose
  # Visibility binding runs raise_dialog and puts the dialog straight back on
  # top -- so the precondition (below0) failed on every run in one session and
  # passed on every run in another. Stacking order is global, so a dialog that
  # overlaps nothing still answers `isbelow`; the first corner of the screen
  # clear of the viewer's frame (with room for decoration) is used.
  set gx 50 ; set gy 50
  set vx1 [expr {[winfo rootx $vtop] - 40}] ; set vy1 [expr {[winfo rooty $vtop] - 60}]
  set vx2 [expr {[winfo rootx $vtop] + [winfo width $vtop] + 40}]
  set vy2 [expr {[winfo rooty $vtop] + [winfo height $vtop] + 40}]
  set sw [winfo screenwidth .] ; set sh [winfo screenheight .]
  foreach {cx cy} [list 10 10 [expr {$sw - 260}] 10 10 [expr {$sh - 160}] [expr {$sw - 260}] [expr {$sh - 160}]] {
    if {$cx + 240 < $vx1 || $cx > $vx2 || $cy + 140 < $vy1 || $cy > $vy2} { set gx $cx ; set gy $cy ; break }
  }
  wm geometry .graphdialog 200x100+$gx+$gy
  update ; after 300 ; update
  catch {lower .graphdialog $vtop}
  update ; after 300 ; update
  set below0 [pcall {wm stackorder .graphdialog isbelow $vtop}]
  swa_gap
  lassign [swa_zone_px 1] zx zy
  swa_mot $zx $zy
  update ; after 300 ; update
  set mapped14 [placed 1]
  set below1 [pcall {wm stackorder .graphdialog isbelow $vtop}]
  # the control: a SIBLING mapped over the canvas, which is what the plan asked
  # for -- it obscures the canvas, whose Visibility binding runs raise_dialog
  frame $vtop.swactl -width 20 -height 20
  place $vtop.swactl -in $vdrw -x 0 -y 0
  update ; after 300 ; update
  set below2 [pcall {wm stackorder .graphdialog isbelow $vtop}]
  destroy $vtop.swactl
  destroy .graphdialog
  check "SWA14 a .graphdialog behind the viewer stays behind when the button (a CHILD of the canvas) maps; a SIBLING mapped over the canvas raises it (control)" \
    [list $below0 $mapped14 $below1 $below2 [string match *raise_dialog* [bind $vtop <Visibility>]]] {1 1 1 0 1}
  lassign [swa_mid 1] cx cy
  swa_mot $cx $cy
  update

  # ---- SWA9: the canvas bindings -------------------------------------------------
  set bt [bindtags $vdrw]
  set stray {}
  foreach seq [bind $vdrw] { if {[string match *fsz* [bind $vdrw $seq]]} { lappend stray $seq } }
  set brk {}
  foreach seq [bind WvFszCanvas] { if {[string match *break* [bind WvFszCanvas $seq]]} { lappend brk $seq } }
  check "SWA9 the gesture tag is first, the canvas' own bindings carry none of it, and no tag binding breaks" \
    [list [lindex $bt 0] [lindex $bt 1] $stray $brk [lsort [bind WvFszCanvas]]] \
    [list WvFszCanvas $vdrw {} {} [lsort {<Motion> <Button> <ButtonRelease> <Leave> <Enter>}]]
  # a REAL LMB drag along the X axis margin zooms the same with and without it
  proc swa_axis_py {gi} {
    lassign [lindex [wviewer::strip_bands_px $::vdrw] $gi] x1 y1 x2 y2
    set px [expr {int(($x1 + $x2) / 2)}]
    # the MIDDLE of the rows answering x: the outermost rows are the graph
    # rect's 5-pixel inner border, which waves_selected does not route
    set rows {}
    for {set py [expr {int($y2) - 1}]} {$py > $y1} {incr py -1} {
      if {[pcall {xschem get graph_axis_at $gi $px $py}] eq {x}} { lappend rows $py }
    }
    if {![llength $rows]} { return {} }
    return [list $px [lindex $rows [expr {[llength $rows] / 2}]]]
  }
  proc swa_axis_drag {} {
    pcall {wviewer::set_target_strip 0 $::tok}
    xschem new_schematic switch $::vdrw
    set g0 [lindex [lay] 0]
    wviewer::set_graphs $::tok [lreplace [lay] 0 0 [dict replace $g0 x1 0 x2 1]]
    wviewer::regenerate $::tok
    update
    set xy [swa_axis_py 0]
    if {$xy eq {}} { return NOAXIS }
    lassign $xy px py
    lassign [lindex [wviewer::strip_bands_px $::vdrw] 0] bx1 by1 bx2 by2
    set q [expr {int(($bx2 - $bx1) / 4)}]
    # test_wave_axis_zoom's ax_ev cadence: a second between events
    swa_mot $px $py 0 1000
    set ::swa_t [expr {$::swa_t + 1000}]
    event generate $::vdrw <ButtonPress-1> -x $px -y $py -button 1 -time $::swa_t
    update
    swa_mot [expr {$px + $q}] $py 256 1000
    update
    set ::swa_t [expr {$::swa_t + 1000}]
    event generate $::vdrw <ButtonRelease-1> -x [expr {$px + $q}] -y $py -button 1 -state 256 -time $::swa_t
    update
    return [list [rprop 0 x1] [rprop 0 x2]]
  }
  set with [swa_axis_drag]
  bindtags $vdrw [lsearch -all -inline -not -exact $bt WvFszCanvas]
  set without [swa_axis_drag]
  bindtags $vdrw $bt
  check "SWA9 a REAL LMB X-axis-margin drag zooms identically with and without the gesture tag (and does zoom)" \
    [list [expr {$with eq $without}] [expr {$with ne {0 1}}]] {1 1}

  # ---- SWA8: the position tracks Configure, add/close, fit and a tab switch ---
  set ::wviewer_aa_reveal_ms 3000
  proc swa_reveal {k} {
    swa_gap
    lassign [swa_mid $k] cx cy
    swa_flick [list [expr {$cx - 60}] [expr {$cy + 60}]]
  }
  swa_reveal 2
  set geo0 [wm geometry $vtop]
  lassign [split [lindex [split $geo0 +] 0] x] gw gh
  wm geometry $vtop [expr {$gw - 120}]x[expr {$gh - 60}]
  update ; after 200 ; update
  check "SWA8 a <Configure> resize: the revealed button follows its sub-window's corner" \
    [list [placed 2] [swa_at 2]] [list 1 [swa_corner 2]]
  # the ruling's "fixed whatever the window size": the engine's own read-back
  # of strip 0's text height after the resize equals that strip's textpx
  xschem new_schematic switch $vdrw
  set em8 {}
  catch {set em8 [dict get [xschem get graph_text_metrics 0] em_px]}
  set px8 [rprop 0 textpx]
  check "SWA8 ...and after the resize strip 0's text is still its textpx pixels (graph_text_metrics em_px)" \
    [expr {[string is double -strict $em8] && [string is double -strict $px8] &&
           abs($em8 - $px8) <= 1e-9 * max(1.0, abs($px8))}] 1
  wm geometry $vtop $geo0
  update ; after 200 ; update
  pcall {wviewer::new_subwin $tok}
  update
  check "SWA8 a new sub-window (three): button 2 still revealed, at its new corner; button 3 built hidden" \
    [list [placed_all] [swa_at 2]] [list {1 0 2 1 3 0} [swa_corner 2]]
  pcall {wviewer::close_subwin $tok [lindex [lsearch -all [ltags] 3] 0]}
  update
  check "SWA8 closing sub-window 3 destroys its button; 2 stays at its corner" \
    [list [placed_all] [swa_at 2]] [list {1 0 2 1} [swa_corner 2]]
  pcall {wviewer::fit $tok}
  update
  check "SWA8 View > Fit: still at the corner" [swa_at 2] [swa_corner 2]
  # SWA8b: a canvas zoom moves the strips with NO regenerate, so only the
  # hover's re-place (fsz_hover) can move a shown button to the new corner.
  swa_reveal 2
  set c0 [swa_corner 2]
  xschem new_schematic switch $vdrw
  set zrc [catch {xschem zoom_out} ze]
  update
  set c1 [swa_corner 2]
  swa_gap
  lassign [swa_mid 1] cx cy
  swa_mot $cx $cy
  check "SWA8b a canvas zoom (no regenerate) moves the corner, and the next motion re-places the shown button there" \
    [list $zrc [expr {$c1 ne $c0}] [placed 2] [swa_at 2]] [list 0 1 1 $c1]
  pcall {wviewer::fit $tok}
  update

  # ---- SWA10 / SWF6: a 2x2 layout across two tabs ---------------------------------
  pcall {wviewer::new_subwin $tok}
  pcall {wviewer::new_subwin $tok}
  update
  set hov {}
  set pos {}
  foreach k {1 2 3 4} {
    swa_gap
    foreach j {1 2 3 4} { pcall {wviewer::fsz_hide $tok $j} ; catch {unset ::wviewer::fszafter($tok,$j)} }
    lassign [swa_zone_px $k] zx zy
    swa_mot $zx $zy
    lappend hov $k [placed_all]
    lappend pos [expr {[swa_at $k] eq [swa_corner $k]}]
  }
  check "SWA10 a 2x2 tab: each corner zone shows its own button only, at its own corner" \
    [list $hov $pos] [list {1 {1 1 2 0 3 0 4 0} 2 {1 0 2 1 3 0 4 0} 3 {1 0 2 0 3 1 4 0} 4 {1 0 2 0 3 0 4 1}} {1 1 1 1}]
  set tab1 [wviewer::dget [lindex [wviewer::tab_records $tok] [wviewer::tab_index $tok]] id {}]
  set fonts1 [swa_fonts]
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::new_subwin $tok}
  update
  check "SWF6 a new tab starts at the window's last user size (15, from SWA6), the base key written" \
    [list [pcall {wviewer::font_base $tok}] [swa_fonts] [rprop 0 textpx]] [list 15 {15 15} [swa_px 15]]
  check "SWA10 the second tab (two sub-windows): buttons 1 and 2 only, hidden" [placed_all] {1 0 2 0}
  set hov {}
  foreach k {1 2} {
    swa_gap
    lassign [swa_zone_px $k] zx zy
    swa_mot $zx $zy
    lappend hov [placed_all] [expr {[swa_at $k] eq [swa_corner $k]}]
  }
  check "SWA10 ...each corner shows its own" $hov {{1 1 2 0} 1 {1 0 2 1} 1}
  pcall {wviewer::select_tab $tab1 $tok}
  update
  # the pointer has not moved since the second tab's corner 2, which is ALSO
  # the 2x2 tab's corner 2 (both are the canvas' top-right): the hover is
  # re-asked of the NEW cells, so the expected set is derived, not assumed
  set hk [pcall {wviewer::fsz_zone_at [swa_cells] {*}$::swa_last {*}$::wviewer::fsz_zone}]
  check "SWA10 back to the 2x2 tab: four buttons, shown only where the unmoved pointer's zone now is, each sub-window's size kept" \
    [list $hk [placed_all] [swa_fonts]] \
    [list 2 [concat {*}[lmap k {1 2 3 4} {list $k [expr {$k == $hk}]}]] $fonts1]
  lassign [swa_mid 3] cx cy
  swa_mot $cx $cy
  check "SWA10 ...and a motion out of it hides it" [placed_all] {1 0 2 0 3 0 4 0}

  # ---- SWF9 (display): save / close / restore keeps the sizes --------------------
  set snap [pcall {wviewer::snapshot $tok {}}]
  set pre [list [swa_fonts] [pcall {wviewer::text_inherit $tok}]]
  pcall {wviewer::close $tok}
  pcall {wviewer::restore $tok $snap {} {}}
  update
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  check "SWF9 save / close / restore keeps every sub-window's size and the window's last user size" \
    [list [swa_fonts] [pcall {wviewer::text_inherit $tok}] [wviewer::dget $snap fontlast -]] [concat $pre 15]

  # ---- SWF6b / SWF9b (display): a SECOND viewer window ------------------------
  # SWF6b: the ruling's "in that window" -- window A's last user size must not
  # reach a fresh window B's new sub-window or new tab. SWF9b: a ONE-tab,
  # one-sub-window window serialises only the flat `font` key (no `tabs`), which
  # is the path SWF9's multi-tab round trip never takes.
  set inhA [pcall {wviewer::text_inherit $tok}]
  set sstateB [file join $scratch sessionB.state]
  file copy -force $sstate $sstateB
  set ::tokB [ase::session_key sky130_tests test_nfet_final ngspice_stateB]
  ase::session_open $::tokB $sstateB
  set okB [pcall {wviewer::open $::tokB}]
  set ::vdrwB [wviewer::window_for $::tokB].drw
  update
  proc layB {} { wviewer::dget [wviewer::layout_for $::tokB] graphs {} }
  proc fontsB {} { pcall {wviewer::strip_fonts [layB] [wviewer::font_base $::tokB]} }
  proc rpropB {gi k} {
    if {[catch {xschem new_schematic switch $::vdrwB} e]} { return "ERR:$e" }
    return [pcall {xschem getprop rect 2 $gi $k}]
  }
  catch {xschem new_schematic switch $::vdrwB}
  pcall {xschem raw new wvsubB.raw dc vsweep 0 1.0 0.1}
  pcall {xschem raw add a1 "vsweep 1 +"}
  pcall {wviewer::set_plot_mode single $::tokB}
  pcall {wviewer::plot_signals $::tokB {a1}}
  pcall {wviewer::new_subwin $::tokB}
  update
  set subB [list [fontsB] [rpropB [expr {[llength [layB]] - 1}] textpx]]
  pcall {wviewer::new_tab $::tokB}
  update
  set tabB [list [pcall {wviewer::font_base $::tokB}] [rpropB 0 textpx]]
  check "SWF6b precondition: window A's last user size is not the rc default; B is fresh" \
    [list $okB [expr {$inhA ne {14}}] [info exists ::wviewer::textlast($::tokB)]] {1 1 0}
  check "SWF6b a fresh window B ignores A's last size: B's new sub-window and B's new tab start at the rc default" \
    [list $subB $tabB] [list [list {14 14} [swa_px 14]] [list 14 [swa_px 14]]]
  pcall {wviewer::close_tab {} $::tokB}
  pcall {wviewer::close_subwin $::tokB [lindex [lsearch -all [tags [layB]] 2] 0]}
  update
  pcall {wviewer::set_text_size 16 $::tokB}
  update
  set snapB [pcall {wviewer::snapshot $::tokB {}}]
  # sentinel-safe: a snapshot that raised is a red row, never a band abort
  proc swb_key {d k} {
    if {[catch {dict exists $d $k} e]} { return "NOTDICT" }
    if {!$e} { return 0 }
    return [dict get $d $k]
  }
  pcall {wviewer::close $::tokB}
  pcall {wviewer::restore $::tokB $snapB {} {}}
  update
  set ::vdrwB [wviewer::window_for $::tokB].drw
  check "SWF9b a ONE-tab, one-sub-window window: size 16 survives save / close / restore (the flat font key)" \
    [list [swb_key $snapB tabs] [swb_key $snapB font] [llength [layB]] \
          [pcall {wviewer::font_base $::tokB}] [rpropB 0 textpx]] [list 0 16 1 16 [swa_px 16]]
  catch {wviewer::close $::tokB}
  catch {unset ::wviewer::textlast($::tokB)}
  } swaerr]} { check "SWA* band ran to its end" "ERR:$swaerr" ok }

  # ==========================================================================
  # SWL* -- THE SPACE A VIEWER STRIP SPENDS OUTSIDE ITS PLOT BOX (the user's
  # report of 2026-10-21: "a lot of space in the waveform viewer is being
  # wasted ... gives the tool a very amateurish feel", after item 22). Named
  # SWL, not SWS: SWS1/SWS2 are the one-tab-state rows earlier in this file.
  # setup_graph_data reserves the cursor-A read-out row and the second bottom
  # row (sweep names, cursor X tags) ON DEMAND (see its block comment), and
  # thins the Y numbers to a stride that keeps them one em apart and keeps the
  # top one. The fixture is the user's picture: ONE sub-window, five stacked
  # strips in a 1070x700 window, one strip holding TWO traces.
  # Two instruments, never a pixel literal:
  #   * graph_text_metrics: the margins setup_graph_data chose (and its
  #     readout_row / sweep_row decisions);
  #   * graph_drawn: what the last on-screen draw DREW -- every Y number, X
  #     number, sweep name, legend name, read-out and cursor tag as a text_bbox
  #     box in screen px. So a row about the Y numbers is about the labels the
  #     draw placed, not about a helper's opinion of them (D7: deleting the line
  #     in draw_graph_grid that applies the stride left the getter-only row
  #     green).
  # Upper bounds are in Tk linespaces of a pixel-sized Sans at the strip's
  # textpx; collision bounds are the drawn boxes themselves; the on-demand row
  # heights are the em multiples the layout defines (0.96 em, 1.2 em).
  # ==========================================================================
  proc swl_m {gi} {
    xschem new_schematic switch $::vdrw
    return [pcall {xschem get graph_text_metrics $gi}]
  }
  proc swl_d {gi} {
    xschem new_schematic switch $::vdrw
    return [pcall {xschem get graph_drawn $gi}]
  }
  proc swl_get {m k} {
    if {[catch {dict get $m $k} v]} { return "NOKEY:$k" }
    return $v
  }
  proc swl_ls {tp} {
    if {![string is double -strict $tp]} { return "NOTP:$tp" }
    return [pcall {font metrics [list Sans [expr {-int(round($tp))}]] -linespace}]
  }
  proc swl_redraw {} {
    xschem new_schematic switch $::vdrw
    xschem redraw
    update ; after 100 ; update
  }
  proc swl_nstrips {} { llength [lay] }
  # a box list's extreme: which 0..3, op min/max; "" for none
  proc swl_ext {boxes which op} {
    set r {}
    foreach b $boxes {
      if {[llength $b] != 4} { continue }
      set v [lindex $b $which]
      if {$r eq {} || ($op eq {min} && $v < $r) || ($op eq {max} && $v > $r)} { set r $v }
    }
    return $r
  }
  # do boxes a and b come closer than cx sideways AND cy vertically (overlap = 0 0)
  proc swl_hit {a b {cx 0} {cy 0}} {
    lassign $a a1 b1 a2 b2 ; lassign $b c1 d1 c2 d2
    return [expr {!($a2 + $cx <= $c1 || $c2 + $cx <= $a1 || $b2 + $cy <= $d1 || $d2 + $cy <= $b1)}]
  }
  proc swl_desc {tp} {
    if {![string is double -strict $tp]} { return 0 }
    set d [pcall {font metrics [list Sans [expr {-int(round($tp))}]] -descent}]
    return [expr {[string is double -strict $d] ? $d : 0}]
  }
  # every strip whose key k exceeds f x linespace
  proc swl_over {k f} {
    set bad {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set m [swl_m $gi]
      set ls [swl_ls [swl_get $m textpx]]
      set v [swl_get $m $k]
      if {![string is double -strict $v] || ![string is double -strict $ls] ||
          $v > $f * $ls} { lappend bad "$gi:$v>$f*$ls" }
    }
    return $bad
  }
  # SWL3 -- the Y numbers the draw placed, against a label set DERIVED from what
  # the draw drew and NOT from the product's stride code (F1: a row that took
  # the record's ylab_pitch_px / ylab_visible -- the stride function's own inputs
  # -- stayed green when that function was told half the real pitch, and the
  # strips showed one lone "0" again). The inputs here are the Y axis marks the
  # draw RECORDED (n_yline/yline: one per visible major line, graph_line) and the
  # em from graph_text_metrics. The rule is the spec's, re-derived: label every
  # k-th line from the bottom, k the smallest stride that puts labels >= 1 em
  # apart AND divides the span, so the top line is labelled too; the bottom one
  # alone when even that stride does not fit. The row asserts the EXACT label
  # set (each drawn label centred on its derived line, none elsewhere), the gaps,
  # and that a strip whose top and bottom lines clear by an em shows two numbers.
  # Returns the bad strips and the total drawn.
  proc swl_ylabs {} {
    set bad {} ; set tot 0
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set m [swl_m $gi]
      set em [swl_get $m em_px]
      set n [swl_get $d n_ylab] ; set nl [swl_get $d n_yline]
      if {![string is integer -strict $n] || ![string is integer -strict $nl] ||
          ![string is double -strict $em] || $nl < 1} {
        lappend bad "$gi:norecord n=$n lines=$nl" ; continue
      }
      incr tot $n
      # the drawn lines, bottom (largest screen y) first
      set ly [lsort -real -decreasing [lmap b [swl_get $d yline] {lindex $b 1}]]
      set span [expr {[llength $ly] - 1}]
      set want [list 0]
      if {$span >= 1} {
        set q [expr {([lindex $ly 0] - [lindex $ly end]) / double($span)}]
        set k [expr {$q > 0 ? int(ceil($em / $q - 1e-6)) : $span + 1}]
        if {$k < 1} { set k 1 }
        if {$k <= $span} {
          while {$span % $k} { incr k }
          set want {}
          for {set j 0} {$j <= $span} {incr j $k} { lappend want $j }
        }
      }
      set wy [lmap j $want {lindex $ly $j}]
      set cs [lsort -real -decreasing [lmap b [swl_get $d ylab] {expr {([lindex $b 1] + [lindex $b 3]) / 2.0}}]]
      if {[llength $cs] != [llength $wy]} {
        lappend bad "$gi:drew [llength $cs] labels, the drawn lines call for [llength $wy] (lines $ly em $em)"
      } else {
        foreach c $cs y $wy {
          if {abs($c - $y) > 0.5} { lappend bad "$gi:label at $c, derived line at $y" }
        }
      }
      for {set j 1} {$j < [llength $cs]} {incr j} {
        set g [expr {[lindex $cs [expr {$j - 1}]] - [lindex $cs $j]}]
        if {$g < $em - 1e-6} { lappend bad "$gi:gap=$g<em=$em" }
      }
      if {$span >= 1 && [lindex $ly 0] - [lindex $ly end] >= $em - 1e-6 && [llength $cs] < 2} {
        lappend bad "$gi:top and bottom lines clear by an em but [llength $cs] number(s) drawn"
      }
    }
    return [list $bad $tot]
  }
  # SWL16/17 -- the cursor X tags against the numbers: no tag box comes onto an
  # X or Y number box by more than one descent (the line boxes may meet in the
  # numbers' blank descent), every strip draws A, B and A-B; and a tag the
  # layout put INSIDE the plot box (tags_inside) ends at or above the box's
  # bottom edge. Returns {bad n_cursor-list tags_inside-list}.
  proc swl_tags {} {
    set bad {} ; set nc {} ; set ti {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set m [swl_m $gi]
      set desc [swl_desc [swl_get $m textpx]]
      lappend nc [swl_get $d n_cursor] ; lappend ti [swl_get $m tags_inside]
      set box [swl_get $d box]
      foreach a [swl_get $d cursor] {
        foreach o [concat [swl_get $d xlab] [swl_get $d ylab]] {
          if {[swl_hit $a $o 0 [expr {-$desc}]]} { lappend bad "$gi:cursor {$a} on {$o} (descent $desc)" }
        }
        if {[swl_get $m tags_inside] eq 1 && [lindex $a 3] > [lindex $box 3] + 0.5} {
          lappend bad "$gi:inside tag {$a} below the box bottom [lindex $box 3]"
        }
      }
    }
    return [list $bad $nc $ti]
  }
  # SWL14/15 -- the last resort (not even the legend and X-number rows fit):
  # every X number whole inside its strip, and the X-number row keeps at least
  # half of the margins (the legend row is the other half; DEF-1: scaling the
  # UNSQUEEZED margins gave it 45% and cut the numbers HEAD drew whole). Returns
  # {bad bottom_px-list}.
  proc swl_degrade {} {
    set bad {} ; set bots {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set m [swl_m $gi]
      set rect [swl_get $d rect]
      set t [swl_get $m top_px] ; set b [swl_get $m bottom_px] ; set em [swl_get $m em_px]
      lappend bots $b
      if {![string is double -strict $t] || ![string is double -strict $b] || [llength $rect] != 4} {
        lappend bad "$gi:norecord" ; continue
      }
      # fixture: really the last resort -- the margins hold less than the
      # legend row (1.2 em) plus the X-number row (tick + gap + 1.2 em, over
      # 1.4 em)
      if {$t + $b >= 2.6 * $em} { lappend bad "$gi:not degraded: top+bottom=[expr {$t + $b}] >= 2.6 em" }
      if {$b < 0.5 * ($t + $b)} { lappend bad "$gi:X-number row $b < half of [expr {$t + $b}]" }
      if {[swl_get $d n_xlab] < 2} { lappend bad "$gi:n_xlab=[swl_get $d n_xlab]" }
      foreach x [swl_get $d xlab] {
        if {[lindex $x 1] < [lindex $rect 1] - 0.5 || [lindex $x 3] > [lindex $rect 3] + 0.5} {
          lappend bad "$gi:xlab {$x} not inside the strip {$rect}"
        }
      }
    }
    return [list $bad $bots]
  }
  # non-decreasing, per strip, over a list of per-pt lists
  proc swl_monotone {seq} {
    set bad {}
    for {set j 1} {$j < [llength $seq]} {incr j} {
      foreach a [lindex $seq [expr {$j - 1}]] b [lindex $seq $j] {
        if {![string is double -strict $a] || ![string is double -strict $b] || $b < $a - 1e-9} {
          lappend bad "step $j: $a -> $b"
        }
      }
    }
    return $bad
  }
  # SWL23 (R1) -- no cursor tag box the draw drew meets a legend name or a
  # read-out box the draw drew (strict: boxes may touch, not overlap; 0.01 px
  # of rounding). A tag the plot box cannot hold goes back to the strip's
  # bottom edge, or is not drawn, rather than cover a name or a value.
  # Returns {bad tags-drawn-total legend+readout-total}.
  proc swl_tag_text {} {
    set bad {} ; set nt 0 ; set nl 0
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi]
      set tops [concat [swl_get $d legend] [swl_get $d readout]]
      incr nl [llength $tops]
      foreach a [swl_get $d cursor] {
        incr nt
        foreach o $tops {
          if {[swl_hit $a $o -0.01 -0.01]} { lappend bad "$gi:tag {$a} on {$o}" }
        }
      }
    }
    return [list $bad $nt $nl]
  }
  # SWL24 (R2) -- with cursor A on, a Y number yields to a read-out only where
  # a read-out the draw drew is on it: every strip whose drawn Y lines span an
  # em (so the stride labels top and bottom, SWL3's derivation) draws two or
  # more Y numbers, no Y-number box meets a read-out box, and none meets a
  # legend name by more than one descent (the blank under the name meeting
  # the blank above the digits). Returns {bad strips-allowing-two}.
  proc swl_ylab_ro {} {
    set bad {} ; set n2 0
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set m [swl_m $gi]
      set em [swl_get $m em_px] ; set desc [swl_desc [swl_get $m textpx]]
      set ly [lsort -real -decreasing [lmap b [swl_get $d yline] {lindex $b 1}]]
      if {![string is double -strict $em] || [llength $ly] < 1} { lappend bad "$gi:norecord" ; continue }
      if {[llength $ly] >= 2 && [lindex $ly 0] - [lindex $ly end] >= $em - 1e-6} {
        incr n2
        if {[swl_get $d n_ylab] < 2} {
          lappend bad "$gi:lines span [expr {[lindex $ly 0] - [lindex $ly end]}] >= em $em but n_ylab=[swl_get $d n_ylab]"
        }
      }
      foreach o [swl_get $d ylab] {
        foreach a [swl_get $d readout] {
          if {[swl_hit $a $o -0.01 -0.01]} { lappend bad "$gi:ylab {$o} on readout {$a}" }
        }
        foreach a [swl_get $d legend] {
          if {[swl_hit $a $o -0.01 [expr {-$desc}]]} { lappend bad "$gi:ylab {$o} on legend {$a} (descent $desc)" }
        }
      }
    }
    return [list $bad $n2]
  }
  # SWL4 -- above the box: no legend name or read-out reaches a Y number or the
  # plot box, and no read-out sits on a legend name (D1: a value placed after
  # its name ran into the next trace's name); below it: every X number lies
  # between the box and the strip's bottom edge; no sweep name or cursor tag
  # touches an X or Y number.
  proc swl_collide {} {
    set bad {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi]
      set box [swl_get $d box] ; set rect [swl_get $d rect]
      if {[llength $box] != 4 || [llength $rect] != 4} { lappend bad "$gi:norecord" ; continue }
      set ytop [swl_ext [swl_get $d ylab] 1 min]
      foreach k {legend readout} {
        set lb [swl_ext [swl_get $d $k] 3 max]
        if {$lb eq {}} { continue }
        if {$lb > [lindex $box 1]} { lappend bad "$gi:$k.y2=$lb>box.y1=[lindex $box 1]" }
        if {$ytop ne {} && $lb > $ytop} { lappend bad "$gi:$k.y2=$lb>ylab.y1=$ytop" }
      }
      foreach b [swl_get $d xlab] {
        if {[lindex $b 1] < [lindex $box 3] || [lindex $b 3] > [lindex $rect 3] + 0.5} {
          lappend bad "$gi:xlab {$b} outside {[lindex $box 3] [lindex $rect 3]}"
        }
      }
      # a box is the font's whole line (ascent + descent + gap), so two rows of
      # numbers may overlap by up to one descent with no ink touching: the
      # upper line's descent area meets the lower line's blank ascent. That
      # allowance (Tk -descent of the strip's pixel size) is vertical only.
      set desc [swl_desc [swl_get [swl_m $gi] textpx]]
      foreach a [swl_get $d readout] {
        foreach o [swl_get $d legend] {
          if {[swl_hit $a $o 0 [expr {-$desc}]]} { lappend bad "$gi:readout {$a} on legend {$o}" }
        }
      }
      foreach k {sweep cursor} {
        foreach a [swl_get $d $k] {
          foreach o [concat [swl_get $d xlab] [swl_get $d ylab]] {
            if {[swl_hit $a $o 0 [expr {-$desc}]]} { lappend bad "$gi:$k {$a} on {$o}" }
          }
        }
      }
    }
    return $bad
  }
  set sws_geo [wm geometry $vtop]
  if {[catch {
  wm geometry $vtop 1070x700
  update ; after 200 ; update
  xschem new_schematic switch $vdrw
  pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
  pcall {xschem raw new wvsws.raw tran time 0 200e-6 0.5e-6}
  foreach {v e} {TEMPERAT "27 time 1e4 * +" Icc "time 2e5 * sin 50e-6 * 60e-6 +"
                 START "time 25e-6 < 1.8 *" ENN "time 5e3 *" VBG "time 4e3 * 0.9 min"} {
    pcall [list xschem raw add $v $e]
  }
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_text_size 14 $tok}
  pcall {wviewer::plot_signals $tok {TEMPERAT}}
  foreach k {1 2 3 4} sig {{Icc START} ENN VBG TEMPERAT} {
    pcall {wviewer::add_graph $tok}
    pcall {wviewer::set_target_strip $k $tok}
    pcall {wviewer::plot_signals $tok $sig}
  }
  update ; after 200 ; update
  set sws_h [lmap b [pcall {wviewer::strip_bands_px $vdrw}] {expr {int(round([lindex $b 3] - [lindex $b 1]))}}]
  check "SWL0 fixture: one sub-window, five strips (strip 1 two traces), all fixed text, each under 140 px tall" \
    [list [wviewer::sw_count [lay]] [lmap g [lay] {llength [wviewer::dget $g traces {}]}] \
          [lmap gi {0 1 2 3 4} {swl_get [swl_m $gi] fixed}] \
          [llength [lsearch -all -inline -not -regexp $sws_h {^(1[0-3][0-9]|[1-9][0-9])$}]]] \
    {1 {1 2 1 1 1} {1 1 1 1 1} 0}
  foreach pt {14 10 16 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    check "SWL1 $pt pt, cursors off: no strip's band above the plot box is taller than legend + Y-number overhang (1.75 linespace)" \
      [swl_over top_px 1.75] {}
    check "SWL1 $pt pt, cursors off: no strip's band below the plot box is taller than the X-number row (1.5 linespace)" \
      [swl_over bottom_px 1.5] {}
    check "SWL2 $pt pt, cursors off: no strip reserves the read-out row or the second bottom row" \
      [lmap gi {0 1 2 3 4} {list [swl_get [swl_m $gi] readout_row] [swl_get [swl_m $gi] sweep_row]}] \
      [lrepeat 5 {0 0}]
    lassign [swl_ylabs] yb ytot
    check "SWL3 $pt pt: the Y numbers DRAWN are exactly the set derived from the Y lines the draw drew and the em (every k-th from the bottom, k the least stride >= 1 em dividing the span), >= 1 em apart, two wherever top and bottom clear, five strips' worth drawn" \
      [list $yb [expr {$ytot >= 5}]] {{} 1}
    check "SWL4 $pt pt: legend clears the Y numbers and the box; X numbers whole inside the strip; 'time' touches no number" \
      [swl_collide] {}
  }
  # ---- cursors: the rows come with them and go with them ----------------------
  # At 10 pt nothing is squeezed, so the deltas are exactly the rows; at 14 pt
  # cursor-on hits the 80% budget on this layout and the AIR gives way first
  # (setup_graph_data), so there the rows are asserted by flag and by collision.
  pcall {wviewer::set_text_size 10 $tok}
  swl_redraw
  set swl_off [lmap gi {0 1 2 3 4} {set m [swl_m $gi]; list [swl_get $m top_px] [swl_get $m bottom_px]}]
  set swl_tp [swl_get [swl_m 0] em_px]
  pcall {xschem cursor 1 1} ; pcall {xschem set cursor1_x 70e-6}
  swl_redraw
  set swl_bad {}
  foreach gi {0 1 2 3 4} o $swl_off {
    set m [swl_m $gi]
    set dt [expr {[swl_get $m top_px] - [lindex $o 0]}] ; set db [expr {[swl_get $m bottom_px] - [lindex $o 1]}]
    if {abs($dt - 0.96 * $swl_tp) > 1e-6 * $swl_tp || abs($db - 1.2 * $swl_tp) > 1e-6 * $swl_tp ||
        [swl_get $m readout_row] ne 1 || [swl_get $m sweep_row] ne 1} {
      lappend swl_bad "$gi:dtop=$dt dbot=$db rows=[swl_get $m readout_row],[swl_get $m sweep_row]"
    }
  }
  check "SWL5 10 pt, cursor A on: every strip gains exactly the read-out row (0.96 em) above and the tag row (1.2 em) below" \
    $swl_bad {}
  pcall {xschem cursor 1 0}
  swl_redraw
  check "SWL5b 10 pt, cursor A off again: every strip's margins are back to the cursor-off values exactly" \
    [lmap gi {0 1 2 3 4} {set m [swl_m $gi]; list [swl_get $m top_px] [swl_get $m bottom_px]}] $swl_off
  pcall {wviewer::set_text_size 14 $tok}
  swl_redraw
  set swl_off [lmap gi {0 1 2 3 4} {set m [swl_m $gi]; list [swl_get $m top_px] [swl_get $m bottom_px]}]
  set swl_tp [swl_get [swl_m 0] em_px]
  # the drawn width of "time" at 14 pt, for SWL13's non-vacuity leg
  set swl_tw [pcall {set b [lindex [swl_get [swl_d 0] sweep] 0]; expr {[lindex $b 2] - [lindex $b 0]}}]
  pcall {xschem cursor 1 1} ; pcall {xschem set cursor1_x 70e-6}
  swl_redraw
  check "SWL6 14 pt, cursor A on: both rows reserved, a read-out drawn on every strip, nothing collides" \
    [list [lmap gi {0 1 2 3 4} {list [swl_get [swl_m $gi] readout_row] [swl_get [swl_m $gi] sweep_row]}] \
          [lmap gi {0 1 2 3 4} {expr {[swl_get [swl_d $gi] n_readout] >= 1}}] [swl_collide]] \
    [list [lrepeat 5 {1 1}] {1 1 1 1 1} {}]
  # SWL24 (R2): the user's own layout, cursor A on, as the text grows into the
  # squeeze -- the read-out row gives way first and its band reaches the top Y
  # numbers, which yield only where a value is really printed on them (the
  # read-out of slot 0 ends tens of pixels left of the Y numbers here). Non-
  # vacuity: strips allowing two are counted, and a read-out is drawn on each.
  set swl_n2 {}
  foreach pt {14 15 16 17 18 19} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_ylab_ro] rb rn2
    lappend swl_n2 $rn2
    check "SWL24 1070x700, five strips, $pt pt, cursor A on: every strip whose Y lines span an em draws two or more Y numbers, none on a read-out, none on a legend name beyond one descent (fixture: a read-out drawn on every strip)" \
      [list $rb [lmap gi {0 1 2 3 4} {expr {[swl_get [swl_d $gi] n_readout] >= 1}}]] \
      [list {} {1 1 1 1 1}]
  }
  check "SWL24 fixture: at 14..18 pt at least three of the five strips have Y lines spanning an em (so the rows above asserted two numbers somewhere)" \
    [lmap n [lrange $swl_n2 0 4] {expr {[string is integer -strict $n] && $n >= 3}}] {1 1 1 1 1}
  pcall {wviewer::set_text_size 14 $tok}
  swl_redraw
  # D1: five traces in one strip, cursor A on -- each value under its own name
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {wviewer::plot_signals $tok {Icc START ENN VBG}}
  swl_redraw
  check "SWL6b 14 pt, cursor A on, five traces in strip 0: five names, five read-outs, no read-out on a name" \
    [list [llength [wviewer::dget [lindex [lay] 0] traces {}]] [swl_get [swl_d 0] n_legend] \
          [swl_get [swl_d 0] n_readout] [swl_collide]] {5 5 5 {}}
  pcall {xschem cursor 2 1} ; pcall {xschem set cursor2_x 140e-6}
  swl_redraw
  check "SWL7 14 pt, cursors A+B on: three tags per strip (A, B, A-B), none on an X or Y number" \
    [list [lmap gi {0 1 2 3 4} {swl_get [swl_d $gi] n_cursor}] [swl_collide]] [list {3 3 3 3 3} {}]
  pcall {xschem cursor 1 0}
  swl_redraw
  check "SWL8 cursor B alone: the tag row stays, the read-out row goes" \
    [lmap gi {0 1 2 3 4} {list [swl_get [swl_m $gi] readout_row] [swl_get [swl_m $gi] sweep_row]}] \
    [lrepeat 5 {0 1}]
  pcall {xschem cursor 2 0}
  swl_redraw
  check "SWL9 14 pt, both cursors off again: every strip's margins are back to the cursor-off values exactly" \
    [lmap gi {0 1 2 3 4} {set m [swl_m $gi]; list [swl_get $m top_px] [swl_get $m bottom_px]}] $swl_off
  # ---- the cursor tags on the user's layout as the text grows (DEF-2) ----------
  # The tag row is a REQUIRED row once a cursor is on: the air, the overhang
  # and the read-out row give way first. Before, at 17-20 pt it was squeezed
  # with the read-out row and the tags were drawn over the X numbers ("50u" ->
  # "5(69.443u").
  pcall {xschem cursor 1 1} ; pcall {xschem set cursor1_x 70e-6}
  pcall {xschem cursor 2 1} ; pcall {xschem set cursor2_x 140e-6}
  foreach pt {14 17 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_tags] tb tn tti
    check "SWL16 $pt pt, cursors A+B on, five strips: three tags per strip, kept in their own row under the X numbers (not moved inside), none on an X or Y number beyond one descent" \
      [list $tn $tti [lmap gi {0 1 2 3 4} {swl_get [swl_m $gi] sweep_row}] $tb] \
      [list {3 3 3 3 3} {0 0 0 0 0} {1 1 1 1 1} {}]
  }
  pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
  pcall {wviewer::set_text_size 14 $tok}
  swl_redraw
  # ---- a second sweep name (Calculator wave destination's sweep= per trace) ---
  # The viewer canvas is read-only; the prop is written straight onto the rect,
  # which is what wviewer::graph_props would emit for a per-trace sweep list.
  set swl_ro [pcall {xschem get readonly}]
  pcall {xschem set readonly 0}
  set swl_p1 [pcall {xschem getprop rect 2 1 sweep}]
  pcall {xschem setprop rect 2 1 sweep {time time} fast}
  swl_redraw
  set m1 [swl_m 1]
  check "SWL10 strip with two sweep tokens: reserves the second bottom row (+1.2 em), draws both names, neither on a number" \
    [list [swl_get $m1 sweep_row] \
          [expr {abs([swl_get $m1 bottom_px] - [lindex $swl_off 1 1] - 1.2 * $swl_tp) <= 1e-6 * $swl_tp}] \
          [swl_get [swl_d 1] n_sweep] [swl_collide]] {1 1 2 {}}
  pcall {xschem setprop rect 2 1 sweep $swl_p1 fast}
  catch {xschem set readonly $swl_ro}
  swl_redraw
  check "SWL10b fixture: the sweep token is restored and strip 1 drops the row again" \
    [swl_get [swl_m 1] sweep_row] 0
  # ---- the last resort on a short window: 1070x400, five strips (DEF-1) --------
  wm geometry $vtop 1070x400
  update ; after 200 ; update
  set swl_bseq {}
  foreach pt {14 15 17 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_degrade] db dbots
    lappend swl_bseq $dbots
    if {$pt in {17 20}} {
      check "SWL14 1070x400, $pt pt, five strips in the last resort: every X number whole inside its strip, the X-number row at least half the margins" \
        [list [swl_nstrips] $db] {5 {}}
    }
  }
  check "SWL14b 1070x400, five strips: every strip's bottom margin is non-decreasing in the text size across 14, 15, 17 and 20 pt" \
    [swl_monotone $swl_bseq] {}
  wm geometry $vtop 1070x700
  update ; after 200 ; update
  pcall {wviewer::set_text_size 14 $tok}
  swl_redraw
  # ---- the squeeze: ten strips, 14 pt -----------------------------------------
  foreach k {5 6 7 8 9} {
    pcall {wviewer::add_graph $tok}
    pcall {wviewer::set_target_strip $k $tok}
    pcall {wviewer::plot_signals $tok ENN}
  }
  pcall {wviewer::set_text_size 14 $tok}
  swl_redraw
  set swl_sq {}
  for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
    set m [swl_m $gi]
    lappend swl_sq [expr {[swl_get $m top_px] + [swl_get $m bottom_px] > 0.79 * ([swl_get $m top_px] + [swl_get $m bottom_px] + [swl_get $m plot_h_px]) ? 1 : 0}]
  }
  check "SWL11 fixture: ten strips, every one in the squeeze (margins at the 80% budget)" \
    [list [swl_nstrips] [lsort -unique $swl_sq]] {10 1}
  set swl_xb {}
  for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
    set d [swl_d $gi] ; set box [swl_get $d box] ; set rect [swl_get $d rect]
    if {[swl_get $d n_xlab] < 2} { lappend swl_xb "$gi:n_xlab=[swl_get $d n_xlab]" }
    foreach b [swl_get $d xlab] {
      if {[lindex $b 1] < [lindex $box 3] || [lindex $b 3] > [lindex $rect 3] + 0.5} {
        lappend swl_xb "$gi:{$b} not in {[lindex $box 3] [lindex $rect 3]}"
      }
    }
  }
  check "SWL12 squeezed: every X number drawn whole between its plot box and its strip's bottom edge" $swl_xb {}
  # ---- the last resort: ten strips, 15-20 pt (DEF-1) ---------------------------
  # 11-14 pt are the squeeze, 15-20 the last resort, so the sequence crosses
  # from one into the other. graph_fixed_margins' floor on the bottom (its
  # last-resort share) only matters inside the narrow band where the air alone
  # is giving way, which no integer size of this geometry lands in -- deleting
  # that floor leaves this row green; SWL19 fences it on window heights that do.
  set swl_bseq {}
  foreach pt {11 12 13 14} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lappend swl_bseq [lmap gi [lsearch -all [lay] *] {swl_get [swl_m $gi] bottom_px}]
  }
  foreach pt {15 17 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_degrade] db dbots
    lappend swl_bseq $dbots
    check "SWL15 1070x700, $pt pt, ten strips in the last resort: every X number whole inside its strip, the X-number row at least half the margins" \
      [list [swl_nstrips] $db] {10 {}}
  }
  check "SWL15b ten strips: every strip's bottom margin is non-decreasing in the text size across 11, 12, 13, 14, 15, 17 and 20 pt" \
    [swl_monotone $swl_bseq] {}
  # ---- ten strips, 12 pt, cursors on: no room for the tag row (DEF-2) ---------
  pcall {wviewer::set_text_size 12 $tok}
  pcall {xschem cursor 1 1} ; pcall {xschem set cursor1_x 70e-6}
  pcall {xschem cursor 2 1} ; pcall {xschem set cursor2_x 140e-6}
  swl_redraw
  lassign [swl_tags] tb tn tti
  check "SWL17 12 pt, cursors A+B on, ten strips: the tag row does not fit beside the X numbers, so the three tags go INSIDE each plot box along its bottom edge, none on an X or Y number beyond one descent" \
    [list $tn $tti $tb] [list [lrepeat 10 3] [lrepeat 10 1] {}]
  # SWL23 (R1): ten strips, A+B, sizes where the plot box is shorter than a tag
  # and the tags are inside: before, the A-B tag centred under strip 1's
  # second name ran up out of the box and its background hid 'START' and its
  # value. Non-vacuity: tags and top texts are drawn (A and B on every strip).
  foreach pt {14 17 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_tag_text] rb rt rl
    check "SWL23 1070x700, ten strips, $pt pt, cursors A+B: no cursor tag box meets a legend name or a read-out box (fixture: tags inside, 20+ tags and 20+ names/values drawn)" \
      [list $rb [lsort -unique [lmap gi [lsearch -all [lay] *] {swl_get [swl_m $gi] tags_inside}]] [expr {$rt >= 20}] [expr {$rl >= 20}]] [list {} 1 1 1]
  }
  pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
  pcall {wviewer::set_text_size 14 $tok}
  swl_redraw
  # ---- an AC database: 'frequency' in the X-number row ------------------------
  pcall {xschem raw new wvsws_ac.raw ac frequency 1 1e6 100}
  foreach {v e} {TEMPERAT "27 frequency 1e-2 * +" Icc "frequency 1e-6 *" START "frequency 1e-6 *"
                 ENN "frequency 1e-6 *" VBG "frequency 1e-6 *"} {
    pcall [list xschem raw add $v $e]
  }
  swl_redraw
  set swl_ac {}
  for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
    set d [swl_d $gi]
    set sw [swl_get $d sweep]
    if {[llength $sw] < 1} { lappend swl_ac "$gi:nosweep" ; continue }
    # non-vacuity: the name drawn is wider than "time" was, i.e. the AC
    # database really is current and this measures "frequency"
    set w [expr {[lindex $sw 0 2] - [lindex $sw 0 0]}]
    if {![string is double -strict $swl_tw] || $w <= $swl_tw} { lappend swl_ac "$gi:width $w <= time $swl_tw" }
    if {[swl_get $d sweep_row] == 1} { continue }
    foreach o [concat [swl_get $d xlab] [swl_get $d ylab]] {
      if {[swl_hit [lindex $sw 0] $o [expr {0.5 * $swl_tp}] 0]} { lappend swl_ac "$gi:{[lindex $sw 0]} near {$o}" }
    }
  }
  check "SWL13 AC: 'frequency' is drawn on every strip and either has its own row or clears every number by half an em" \
    $swl_ac {}
  pcall {wviewer::set_text_size 14 $tok}
  pcall {wviewer::close_tab {} $tok}
  # ---- SWL18-SWL22: where the cursor tags, the sweep names and the read-out
  # go as the text grows (round 4). Fresh tabs, so the strip counts can start
  # at five again. tags_inside is read from graph_text_metrics (the layout's
  # decision); every position is read from graph_drawn (what the draw drew).
  # tags_inside per strip
  proc swl_ti {} {
    set r {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} { lappend r [swl_get [swl_m $gi] tags_inside] }
    return $r
  }
  # SWL18 -- over a list of per-size tags_inside lists (sizes ascending): no
  # strip's tags come back into the row at a larger size once they went
  # inside (DEF-A: the decision was a rounding coin-flip, row/inside/row at
  # 18/19/20 pt on the user's own layout, the plot box jumping ~25 px).
  proc swl_ti_mono {seq pts} {
    set bad {}
    set n [llength [lindex $seq 0]]
    for {set st 0} {$st < $n} {incr st} {
      set was 0
      foreach row $seq pt $pts {
        set v [lindex $row $st]
        if {$v ni {0 1}} { lappend bad "strip $st at $pt pt: tags_inside=$v" ; continue }
        if {$was && $v == 0} { lappend bad "strip $st: inside, then back in the row at $pt pt" }
        if {$v} { set was 1 }
      }
    }
    return $bad
  }
  # SWL20 -- every cursor tag box the draw drew lies wholly inside its strip
  # (half a pixel of rounding); a strip SHORTER than the box (the box is the
  # font's whole line) gets it centred, each end out by no more than one Tk
  # descent of the strip's size -- blank line space, the digits' ink inside.
  # Returns {bad n_cursor-list tag-height-list}.
  proc swl_tagbox_in {} {
    set bad {} ; set nc {} ; set th {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi]
      lassign [swl_get $d rect] rx1 ry1 rx2 ry2
      set desc [swl_desc [swl_get [swl_m $gi] textpx]]
      lappend nc [swl_get $d n_cursor]
      set h 0
      foreach a [swl_get $d cursor] {
        lassign $a x1 y1 x2 y2
        if {$y2 - $y1 > $h} { set h [expr {$y2 - $y1}] }
        set tol [expr {$y2 - $y1 > $ry2 - $ry1 ? 0.5 + $desc : 0.5}]
        if {$y1 < $ry1 - $tol || $y2 > $ry2 + $tol || $x1 < $rx1 - 0.5 || $x2 > $rx2 + 0.5 ||
            ($y2 - $y1 > $ry2 - $ry1 && abs(($y1 + $y2) - ($ry1 + $ry2)) > 1.0)} {
          lappend bad "$gi:tag {$a} not wholly inside the strip {$rx1 $ry1 $rx2 $ry2} (descent $desc)"
        }
      }
      lappend th $h
    }
    return [list $bad $nc $th]
  }
  set swl_pts {10 11 12 13 14 15 16 17 18 19 20}
  wm geometry $vtop 1070x700
  update ; after 200 ; update
  xschem new_schematic switch $vdrw
  pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
  pcall {xschem raw new wvsws2.raw tran time 0 200e-6 0.5e-6}
  foreach {v e} {TEMPERAT "27 time 1e4 * +" Icc "time 2e5 * sin 50e-6 * 60e-6 +"
                 START "time 25e-6 < 1.8 *" ENN "time 5e3 *" VBG "time 4e3 * 0.9 min"} {
    pcall [list xschem raw add $v $e]
  }
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_text_size 14 $tok}
  pcall {wviewer::plot_signals $tok {TEMPERAT}}
  foreach k {1 2 3 4} sig {{Icc START} ENN VBG TEMPERAT} {
    pcall {wviewer::add_graph $tok}
    pcall {wviewer::set_target_strip $k $tok}
    pcall {wviewer::plot_signals $tok $sig}
  }
  # SWL19 (d7) -- cursors off, five strips, at window heights where some
  # integer size lands in the narrow band where only the AIR is giving way:
  # there the bottom margin would SHRINK as the text grows without
  # graph_fixed_margins' floor on it (measured: 0.02-0.24 px at one size step
  # per height). Non-vacuity: each height's sweep crosses from unsqueezed to
  # squeezed (margins at the 80% budget).
  set swl_d7 {}
  foreach h {360 420 480 540 600} {
    wm geometry $vtop 1070x$h
    update ; after 200 ; update
    set seq {} ; set sq {}
    foreach pt $swl_pts {
      pcall {wviewer::set_text_size $pt $tok}
      swl_redraw
      lappend seq [lmap gi [lsearch -all [lay] *] {swl_get [swl_m $gi] bottom_px}]
      set m [swl_m 0]
      set t [swl_get $m top_px] ; set b [swl_get $m bottom_px] ; set ph [swl_get $m plot_h_px]
      lappend sq [expr {[string is double -strict $t] && [string is double -strict $b] &&
                        [string is double -strict $ph] && $t + $b > 0.79 * ($t + $b + $ph) ? 1 : 0}]
    }
    foreach x [swl_monotone $seq] { lappend swl_d7 "h=$h $x" }
    if {[lsort -unique $sq] ne {0 1}} { lappend swl_d7 "h=$h fixture: squeeze flags $sq do not cross" }
  }
  check "SWL19 cursors off, five strips, window 1070x360..600: every strip's bottom margin is non-decreasing in the text size over every integer size 10..20 pt, each sweep crossing into the squeeze" \
    $swl_d7 {}
  pcall {xschem cursor 1 1} ; pcall {xschem set cursor1_x 70e-6}
  pcall {xschem cursor 2 1} ; pcall {xschem set cursor2_x 140e-6}
  foreach {geo want} {1070x700 {0} 1070x400 {0 1}} {
    wm geometry $vtop $geo
    update ; after 200 ; update
    set seq {}
    foreach pt $swl_pts {
      pcall {wviewer::set_text_size $pt $tok}
      swl_redraw
      lappend seq [swl_ti]
      if {$geo eq {1070x400} && $pt in {16 20}} {
        lassign [swl_tag_text] rb rt rl
        check "SWL23 1070x400, five strips, $pt pt, cursors A+B: no cursor tag box meets a legend name or a read-out box (fixture: tags inside, 10+ tags and 10+ names/values drawn)" \
          [list $rb [lsort -unique [swl_ti]] [expr {$rt >= 10}] [expr {$rl >= 10}]] [list {} 1 1 1]
      }
    }
    check "SWL18 $geo, five strips, cursors A+B, every integer size 10..20 pt: once a strip's tags go inside its plot box they stay inside at every larger size (and the sweep visits [expr {$want eq {0} ? {only the row} : {both the row and inside}}])" \
      [list [swl_ti_mono $seq $swl_pts] [lsort -unique [concat {*}$seq]]] [list {} $want]
  }
  wm geometry $vtop 1070x700
  update ; after 200 ; update
  foreach k {5 6 7 8 9} {
    pcall {wviewer::add_graph $tok}
    pcall {wviewer::set_target_strip $k $tok}
    pcall {wviewer::plot_signals $tok ENN}
  }
  set seq {}
  set swl_pts6 [concat {6 7 8 9} $swl_pts]
  foreach pt $swl_pts6 {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lappend seq [swl_ti]
  }
  check "SWL18 1070x700, ten strips, cursors A+B, every integer size 6..20 pt: once a strip's tags go inside its plot box they stay inside at every larger size (and the sweep visits both the row and inside)" \
    [list [swl_nstrips] [swl_ti_mono $seq $swl_pts6] [lsort -unique [concat {*}$seq]]] [list 10 {} {0 1}]
  # SWL20 (DEF-B) -- twelve strips in a 1070x400 window: each plot box is
  # shorter than a cursor tag, so a tag inside it would stick out above the
  # strip and be cut by the strip's clip. The tags go back to the strip's
  # bottom edge (on their background box) and every one is whole.
  wm geometry $vtop 1070x400
  update ; after 200 ; update
  foreach k {10 11} {
    pcall {wviewer::add_graph $tok}
    pcall {wviewer::set_target_strip $k $tok}
    pcall {wviewer::plot_signals $tok VBG}
  }
  foreach pt {12 16 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_tagbox_in] tb tn th
    set fx {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set ph [swl_get [swl_m $gi] plot_h_px]
      if {![string is double -strict $ph] || [lindex $th $gi] <= $ph} { lappend fx "$gi:plot $ph tag [lindex $th $gi]" }
    }
    check "SWL20 1070x400, twelve strips, $pt pt, cursors A+B: every cursor tag box wholly inside its strip, at least the A and B tags on every strip (fixture: tags_inside on every strip, each plot box shorter than a tag)" \
      [list [swl_nstrips] $tb [lsort -unique [lmap n $tn {expr {[string is integer -strict $n] && $n >= 2}}]] [lsort -unique [swl_ti]] $fx] \
      [list 12 {} 1 1 {}]
  }
  pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
  pcall {wviewer::set_text_size 14 $tok}
  pcall {wviewer::close_tab {} $tok}
  # ---- AC again, a fresh tab: 'frequency' does not fit beside the X numbers --
  wm geometry $vtop 1070x700
  update ; after 200 ; update
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvsws2_ac.raw ac frequency 1 1e6 100}
  foreach {v e} {TEMPERAT "27 frequency 1e-2 * +" Icc "frequency 1e-6 *" START "frequency 1e-6 *"
                 ENN "frequency 1e-6 *" VBG "frequency 1e4 * 27 +"} {
    pcall [list xschem raw add $v $e]
  }
  pcall {wviewer::new_tab $tok}
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_text_size 14 $tok}
  pcall {wviewer::plot_signals $tok {VBG}}
  foreach k {1 2 3 4} sig {{Icc START} ENN VBG TEMPERAT} {
    pcall {wviewer::add_graph $tok}
    pcall {wviewer::set_target_strip $k $tok}
    pcall {wviewer::plot_signals $tok $sig}
  }
  pcall {xschem cursor 1 1} ; pcall {xschem set cursor1_x 333333}
  pcall {xschem cursor 2 1} ; pcall {xschem set cursor2_x 8e5}
  # SWL22 (DEF-D) -- five AC strips, cursor A on, squeezed: the read-out row
  # gives way before the tag row, so a Y number on the box's top edge reaches
  # up into it; a Y number that would is not drawn (the value beats the tick
  # number) and no read-out box meets a Y-number box at all. Non-vacuity: Y
  # numbers are still drawn on these strips (a strip short enough loses all
  # of its own, so the count is over the five).
  foreach pt {16 17 18} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    set bad {} ; set fx {} ; set ny 0
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set m [swl_m $gi]
      if {[string is integer -strict [swl_get $d n_ylab]]} { incr ny [swl_get $d n_ylab] }
      if {[swl_get $m readout_row] ne 1 || ![string is integer -strict [swl_get $d n_readout]] ||
          [swl_get $d n_readout] < 1} {
        lappend fx "$gi:ro=[swl_get $m readout_row] n_readout=[swl_get $d n_readout]"
      }
      foreach a [swl_get $d readout] {
        foreach o [swl_get $d ylab] {
          if {[swl_hit $a $o 0 0]} { lappend bad "$gi:readout {$a} on ylab {$o}" }
        }
      }
    }
    check "SWL22 AC, five strips, $pt pt, cursors A+B: no read-out box meets a Y-number box (fixture: the read-out row on and a read-out drawn on every strip, Y numbers drawn)" \
      [list [swl_nstrips] $bad $fx [expr {$ny >= 3}]] {5 {} {} 1}
  }
  # SWL21 (DEF-C) -- twelve AC strips in 1070x700, cursors A+B, at sizes where
  # the tag row cannot be had and the tags go inside: the sweep name still
  # needs (and gets) the second bottom row, and it is on no X number beyond
  # one descent (an X number squeezed under it yields to it).
  foreach k {5 6 7 8 9 10 11} {
    pcall {wviewer::add_graph $tok}
    pcall {wviewer::set_target_strip $k $tok}
    pcall {wviewer::plot_signals $tok VBG}
  }
  foreach pt {10 11 12} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    set bad {} ; set sr {} ; set nx {}
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set m [swl_m $gi]
      set desc [swl_desc [swl_get $m textpx]]
      lappend sr [swl_get $m sweep_row]
      lappend nx [expr {[string is integer -strict [swl_get $d n_xlab]] && [swl_get $d n_xlab] >= 2 &&
                        [string is integer -strict [swl_get $d n_sweep]] && [swl_get $d n_sweep] >= 1}]
      foreach a [swl_get $d sweep] {
        foreach o [swl_get $d xlab] {
          if {[swl_hit $a $o 0 [expr {-$desc}]]} { lappend bad "$gi:sweep {$a} on xlab {$o} (descent $desc)" }
        }
      }
      # here the read-out row lies inside the plot box: even the bottom Y
      # number yields to it rather than be overprinted
      foreach a [swl_get $d readout] {
        foreach o [swl_get $d ylab] {
          if {[swl_hit $a $o 0 0]} { lappend bad "$gi:readout {$a} on ylab {$o}" }
        }
      }
    }
    check "SWL21 AC, twelve strips, $pt pt, cursors A+B, tags inside: every strip keeps the sweep row, draws its sweep name and two or more X numbers, no sweep name is on an X number beyond one descent, and no read-out box meets a Y-number box" \
      [list [swl_nstrips] [lsort -unique [swl_ti]] [lsort -unique $sr] [lsort -unique $nx] $bad] {12 1 1 1 {}}
    # SWL21m (R3): the row is really RESERVED, not only flagged. With tags
    # inside, the sweep row is always squeezed below its floor (the tag floor
    # is the smaller of the two and already did not fit), so the leg is the
    # room the margin leaves UNDER the drawn X numbers: rect bottom minus the
    # lowest X-number box bottom, at least 0.15 em. Without the row
    # (sweep_row still claimed) the numbers fill the margin to the strip's
    # edge but for the air, which the squeeze takes first. At 12 pt the
    # squeezed row is itself about 0.1 em, so the leg runs at 10 and 11 pt.
    if {$pt in {10 11}} {
      set mb {}
      for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
        set d [swl_d $gi] ; set m [swl_m $gi]
        set desc [swl_desc [swl_get $m textpx]]
        set xb [swl_ext [swl_get $d xlab] 3 max] ; set rect [swl_get $d rect] ; set box [swl_get $d box]
        if {$xb eq {} || [llength $rect] != 4 || [llength $box] != 4} { lappend mb "$gi:norecord" ; continue }
        set room [expr {[lindex $rect 3] - $xb}]
        # the bottom margin is the X-number row (box bottom to the lowest
        # number's bottom) plus that room
        set xrow [expr {$xb - [lindex $box 3]}]
        set em [swl_get $m em_px]
        if {![string is double -strict $em] || $room < 0.15 * $em || abs([swl_get $m bottom_px] - ($xrow + $room)) > 0.5} {
          lappend mb "$gi:room under the X numbers $room < 0.15 em $em (bottom_px [swl_get $m bottom_px], X-number row $xrow)"
        }
      }
      check "SWL21m AC, twelve strips, $pt pt, cursors A+B, tags inside: the sweep row is reserved -- the bottom margin is the drawn X-number row plus at least 0.15 em of room under it" \
        $mb {}
    }
  }
  pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
  # SWL25 (R4): the same twelve AC strips, cursors OFF: 'frequency' squeezed
  # up beside the box sat on the bottom Y number ('0'); the number yields to
  # the axis name as the X numbers do. Non-vacuity: a sweep name is drawn on
  # every strip and Y numbers are still drawn on the strips.
  foreach pt {10 11 12} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    set bad {} ; set ns {} ; set ny 0
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set m [swl_m $gi]
      set desc [swl_desc [swl_get $m textpx]]
      lappend ns [expr {[string is integer -strict [swl_get $d n_sweep]] && [swl_get $d n_sweep] >= 1}]
      if {[string is integer -strict [swl_get $d n_ylab]]} { incr ny [swl_get $d n_ylab] }
      foreach a [swl_get $d sweep] {
        foreach o [swl_get $d ylab] {
          if {[swl_hit $a $o 0 [expr {-$desc}]]} { lappend bad "$gi:sweep {$a} on ylab {$o} (descent $desc)" }
        }
      }
    }
    check "SWL25 AC, twelve strips, $pt pt, cursors off: no sweep name is on a Y number beyond one descent (fixture: a sweep name on every strip, Y numbers drawn)" \
      [list [swl_nstrips] $bad [lsort -unique $ns] [expr {$ny >= 6}]] {12 {} 1 1}
  }
  pcall {wviewer::set_text_size 14 $tok}
  pcall {wviewer::close_tab {} $tok}
  # ---- SWL26-SWL28 (round 9): INK, not line boxes, decides whether a Y number
  # yields to a legend name (F1), and the A-B tag is never dropped (F2). -----
  # A fresh tab per fixture: `geo` window, strip k plotting names[k mod n].
  # The caller closes the tab when done with it.
  proc swl_fix {geo n names} {
    wm geometry $::vtop $geo
    update ; after 200 ; update
    xschem new_schematic switch $::vdrw
    pcall {wviewer::new_tab $::tok}
    pcall {wviewer::set_plot_mode single $::tok}
    pcall {wviewer::set_text_size 14 $::tok}
    pcall {wviewer::plot_signals $::tok [lindex $names 0]}
    for {set k 1} {$k < $n} {incr k} {
      pcall {wviewer::add_graph $::tok}
      pcall {wviewer::set_target_strip $k $::tok}
      pcall {wviewer::plot_signals $::tok [lindex $names [expr {$k % [llength $names]}]]}
    }
    # a new tab starts with its cursors off
    xschem new_schematic switch $::vdrw
    foreach {c x} $::swl_cur {
      if {$x eq {}} { pcall [list xschem cursor $c 0] } else { pcall [list xschem cursor $c 1] ; pcall [list xschem set cursor${c}_x $x] }
    }
  }
  # F1 -- per strip: no Y number's INK meets a legend name's INK (strict, 0.01
  # px of rounding). The ink boxes come from the draw record (ylab_ink,
  # legend_ink); a leg keeps them honest: one per drawn line box, inside it,
  # and no shorter than 0.4 of it (digits and capitals fill most of the
  # ascent; an ink box collapsed to a line would let any overprint through).
  # Also counts the Y numbers the OLD rule -- the line boxes, the number's cut
  # by 0.2 em top and bottom -- would have withheld for meeting a legend name:
  # a kept number of that kind is the ink rule at work. Returns
  # {bad n_ylab-list old-rule-would-drop}.
  proc swl_ink {} {
    set bad {} ; set ny {} ; set olddrop 0
    for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
      set d [swl_d $gi] ; set em [swl_get [swl_m $gi] em_px]
      lappend ny [swl_get $d n_ylab]
      foreach {k ki} {ylab ylab_ink legend legend_ink} {
        set lb [swl_get $d $k] ; set ib [swl_get $d $ki]
        if {[llength $lb] != [llength $ib]} { lappend bad "$gi:[llength $lb] $k boxes, [llength $ib] $ki" ; continue }
        foreach l $lb i $ib {
          lassign $l x1 y1 x2 y2 ; lassign $i a1 b1 a2 b2
          if {$b1 < $y1 - 0.5 || $b2 > $y2 + 0.5 || $b2 - $b1 < 0.4 * ($y2 - $y1)} {
            lappend bad "$gi:$ki {$i} not the ink of {$l}"
          }
        }
      }
      foreach o [swl_get $d ylab_ink] {
        foreach a [swl_get $d legend_ink] {
          if {[swl_hit $a $o -0.01 -0.01]} { lappend bad "$gi:ylab ink {$o} on legend ink {$a}" }
        }
      }
      if {![string is double -strict $em]} { continue }
      foreach o [swl_get $d ylab] {
        lassign $o x1 y1 x2 y2
        foreach a [swl_get $d legend] {
          if {[swl_hit $a [list $x1 [expr {$y1 + 0.2 * $em}] $x2 [expr {$y2 - 0.2 * $em}]] -0.01 -0.01]} { incr olddrop ; break }
        }
      }
    }
    return [list $bad $ny $olddrop]
  }
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvsws3.raw tran time 0 200e-6 0.5e-6}
  foreach {v e} {TEMPERAT "27 time 1e4 * +" Icc "time 2e5 * sin 50e-6 * 60e-6 + -1 *"
                 START "time 25e-6 < 1.8 *" ENN "time 5e3 *" VBG "time 4e3 * 0.9 min"
                 LONGV "time -1.37e5 * 12.3456 +"} {
    pcall [list xschem raw add $v $e]
  }
  set swl_cur {1 80e-6 2 {}}
  # SWL26 (F1, the number stays): ten strips at 1070x700, cursor A on. At
  # these sizes the TEMPERAT strips' '27' sits under the name with the line
  # boxes overlapping but the ink clear; the box rule dropped it, leaving
  # those strips with no Y number at all. Non-vacuity: at least two kept
  # numbers are ones the box rule withholds.
  swl_fix 1070x700 10 {TEMPERAT {Icc START} ENN VBG TEMPERAT ENN VBG ENN VBG ENN}
  foreach pt {9 18 19} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_ink] ib iny iold
    check "SWL26 1070x700, ten strips, $pt pt, cursor A on: every strip draws a Y number, no Y number's ink on a legend name's ink (fixture: 2+ kept numbers the line-box rule would withhold)" \
      [list [swl_nstrips] $ib [lsort -unique [lmap n $iny {expr {[string is integer -strict $n] && $n >= 1}}]] [expr {$iold >= 2}]] \
      {10 {} 1 1}
  }
  # SWL27 (F1, the overprint is still prevented): a long negative-range slot-0
  # trace (LONGV) puts a wide Y number right under its name; at the larger
  # sizes their ink meets and the number yields (with no legend test it is
  # drawn over the name), at 16-17 pt it is clear and stays (the box rule
  # left every strip empty there; non-vacuity: those kept numbers are ones the
  # box rule withholds). Twelve strips at 1070x400: the TEMPERAT name covers
  # its number's ink from 9 pt up; at 8 pt it is clear and stays. Non-
  # vacuity: names with ink drawn on every strip.
  pcall {wviewer::close_tab {} $tok}
  swl_fix 1070x700 10 {{LONGV START}}
  foreach pt {16 17 18 19 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_ink] ib iny iold
    set nl [lmap gi [lsearch -all [lay] *] {expr {[llength [swl_get [swl_d $gi] legend_ink]] >= 2}}]
    check "SWL27 1070x700, ten LONGV strips, $pt pt, cursor A on: no Y number's ink on a legend name's ink[expr {$pt < 18 ? {, and every strip keeps its Y number (10 of them ones the box rule withholds)} : {}}] (fixture: two names' ink on every strip)" \
      [list [swl_nstrips] $ib [lsort -unique $nl] \
            [expr {$pt < 18 ? [list [lsort -unique [lmap n $iny {expr {[string is integer -strict $n] && $n >= 1}}]] [expr {$iold >= 10}]] : {1 1}}]] \
      {10 {} 1 {1 1}}
  }
  pcall {wviewer::close_tab {} $tok}
  swl_fix 1070x400 12 {TEMPERAT {Icc START} ENN VBG TEMPERAT ENN VBG ENN VBG ENN}
  foreach pt {8 9 12 16 20} {
    pcall {wviewer::set_text_size $pt $tok}
    swl_redraw
    lassign [swl_ink] ib iny iold
    set nl [lmap gi [lsearch -all [lay] *] {expr {[llength [swl_get [swl_d $gi] legend_ink]] >= 1}}]
    check "SWL27 1070x400, twelve strips, $pt pt, cursor A on: no Y number's ink on a legend name's ink[expr {$pt == 8 ? {, and every strip keeps its Y number (3 of them ones the box rule withholds)} : {}}] (fixture: a name's ink on every strip)" \
      [list [swl_nstrips] $ib [lsort -unique $nl] \
            [expr {$pt == 8 ? [list [lsort -unique [lmap n $iny {expr {[string is integer -strict $n] && $n >= 1}}]] [expr {$iold >= 3}]] : {1 1}}]] \
      {12 {} 1 {1 1}}
  }
  # SWL28 (F2): every strip {Icc START}, A at 40u and B at 160u, where the
  # tags go inside and the A-B tag's centred places both meet the START name
  # or its read-out: the tag slides along its row to a clear spot instead of
  # being dropped. On every strip: three tags, the A-B tag (drawn last) inside
  # the plot box's x range and on no legend name or read-out box. Non-
  # vacuity: tags inside, and the A-B tag NOT centred between the cursors (it
  # really slid) on every strip.
  set swl_cur {1 40e-6 2 160e-6}
  pcall {wviewer::close_tab {} $tok}
  foreach {geo n pts} {1070x700 10 {14 17 20} 1070x400 5 {16 18 20}} {
    swl_fix $geo $n {{Icc START}}
    foreach pt $pts {
      pcall {wviewer::set_text_size $pt $tok}
      swl_redraw
      set bad {} ; set slid {}
      for {set gi 0} {$gi < [swl_nstrips]} {incr gi} {
        set d [swl_d $gi] ; set c [swl_get $d cursor] ; set box [swl_get $d box]
        if {[llength $c] != 3 || [llength $box] != 4} { lappend bad "$gi:n_cursor=[swl_get $d n_cursor]" ; continue }
        set t [lindex $c 2]
        lassign $box x1 y1 x2 y2
        if {[lindex $t 0] < $x1 - 0.5 || [lindex $t 2] > $x2 + 0.5} { lappend bad "$gi:A-B tag {$t} outside x $x1..$x2" }
        foreach o [concat [swl_get $d legend] [swl_get $d readout]] {
          if {[swl_hit $t $o -0.01 -0.01]} { lappend bad "$gi:A-B tag {$t} on {$o}" }
        }
        set mid [expr {$x1 + 0.5 * ($x2 - $x1)}]
        lappend slid [expr {abs(([lindex $t 0] + [lindex $t 2]) / 2.0 - $mid) > 2.0}]
      }
      check "SWL28 $geo, $n strips of {Icc START}, $pt pt, cursors A+B: the A-B tag is drawn on every strip, inside the plot's x range, on no legend name or read-out (fixture: tags inside, the tag slid off centre on every strip)" \
        [list [swl_nstrips] $bad [lsort -unique [swl_ti]] [lsort -unique $slid]] [list $n {} 1 1]
    }
    pcall {wviewer::close_tab {} $tok}
  }
  pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
  pcall {wviewer::set_text_size 14 $tok}
  } swserr]} { check "SWL* band ran to its end" "ERR:$swserr" ok }
  catch {wm geometry $vtop $sws_geo}
  update

  set ::wviewer_aa_reveal_ms $swa_reveal_saved
  catch {unset ::wviewer::textlast($tok)}

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

if {$::arm eq {nogui}} { set expect 250 } else { set expect 541 }
if {$fail == 0 && $expect > 0 && $npass != $expect} {
  puts "FAIL: SWCNT expected $expect checks on the $::arm arm, ran $npass : FAIL"
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
