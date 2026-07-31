# Waveform Viewer window shell + working core (items 11+12 of
# doc/claude/ase_l_batch, spec doc/claude/specs/waveform_viewer.md —
# src/wave_viewer.tcl + the ase.tcl raw_file backend hook):
#   V1  render_deck emits exactly one `write <rundir>/<cell>_ase.raw` line
#       inside .control...endc, after the print line (fixture state, op on)
#   V2  no write line when ALL analyses are disabled
#   V3  ase::backend_hook ngspice raw_file resolves -> <rundir>/<cell>_ase.raw
#   V4  real ngspice dc sweep (spec schema shape) through ase::netlist +
#       ase::run_deck -> exit 0 AND the raw artifact exists non-empty
#       (guarded: SKIP without ngspice)
#   V5  xschem raw read of the artifact: sim_type dc, points == 181,
#       vars >= 2, `raw loaded` >= 0 (INDEX semantics — never a boolean)
#   V6  embedded-graph regression: shipped test_ne555.sch loads (readonly),
#       keeps its layer-2 graph rect + flags=graph, redraws rc 0
#   G1-G9 GUI legs (DISPLAY-guarded self-SKIP): open viewer from a session
#       token (toplevel, registry, readonly, untitled buffer); strip SWEEP
#       (G1s, fixup: user-rc binds installed on the main .drw pre-open —
#       cadence_style_rc:109 verbatim <Key-i> + a Windows-arm-shaped
#       <Alt-KeyPress> — are cloned by clone_canvas_bindings onto the viewer
#       canvas and MUST be cleared there, main canvas keeps its own; plus a
#       completeness check: no sequence outside the keep+filter set); editor
#       TOOLBAR stripped per-window (G1t, fixup r2: toolbar_visible defaults
#       1 so pack_widgets shows 37 armed editing/simulator buttons on the
#       viewer — forced to 1 for determinism, widget exists but is not
#       pack-managed/mapped, main-window packedness unchanged, fresh G9
#       reopen stripped too); viewer
#       menubar attached (File/View/Graph/Cursors; since item 12 every
#       Graph+Cursors entry is LIVE — the item-11 "all disabled" assertion
#       flipped with the item-12 core),
#       editor menubar NOT attached; exact title + with_edit clobber
#       regression; window number > 0; strip (i/Insert/w do nothing: no
#       instance, no wire, no modify, no readonly MODAL — recording
#       tk_messageBox stub — no new toplevel; `i` reaches the FILTER, not
#       the cloned create_instance bind); ESC does not close; display_raw
#       (1 graph rect, node prop, raw points in the viewer ctx, redraw,
#       modified 0 + readonly restored, no untitled*~.sch autosave backup);
#       re-open raises the SAME window (number unchanged); Ctrl-W closes
#       with no prompt, registry cleaned, reopen builds a fresh window.
#   H1-H6 item-12 pure model->rect-props procs (BOTH arms, no window, no
#       xschem calls): graph_props template/token/alias/range/log emission,
#       band_geometry viewport tiling (item 18; replaced graph_geometry),
#       next_color palette cycle, validate_rpn token rules (save.c RPN table;
#       D4 pre-validation)
#   item 18 (graph-fills-win): the graph FILLS the viewer window, not a fixed
#       800x400 rect on a grid canvas. RG0 no_grid getter/setter roundtrip;
#       RG1/RG2 normal-window grid+embedded-graph regression (grid-off is
#       VIEWER-ONLY); H-band1..4 pure band tiling (single-fills / equal halves /
#       n=3 contiguous / nonzero-origin verbatim); GF1-GF5 GUI (single graph
#       covers the viewport, grid off here / on elsewhere, resize refits,
#       two graphs each fill a half, regenerate never re-frames the canvas).
#   G10-G17 item-12 viewer core (GUI, self-SKIP): Add Graph stacking +
#       model/rect/graphbb agreement; Add Trace from the raw-vars listbox
#       (count == `raw vars`, palette-head color); expression trace via
#       `xschem raw add` (db20) + bad expression surfaces IN-DIALOG (D4:
#       error label, no phantom vector, model unchanged, no throw); Axes
#       dialog log toggle + exact ranges; Delete dialog (one trace, then a
#       whole graph — remaining graphs re-stack from y 0); cursors A/B via
#       menu checkbuttons + bottom-bar readout showing eng-formatted x and
#       INTERPOLATED per-trace y cross-checked against the engine's
#       cursor-B ground truth (`raw value <var> {}` after `set cursor2_x`)
#       and proven different from the nearest raw sample; View>Fit = engine
#       autozoom + model read-back; no Graph/Cursors entry left disabled.
#   item 19 (graph-interact): wheel / RMB / f / View-zoom act on the GRAPH,
#       never the canvas (IX*, GUI self-SKIP). IX-vpan-up/dn plain wheel =
#       vertical graph pan (y1/y2 shift, opposite signs, x fixed); IX-hpan
#       Shift+wheel = horizontal pan; IX-zoom-in/out Ctrl+wheel = graph zoom in
#       BOTH axes on the pointed strip + IX-zoom-strips X-on-every-strip /
#       Y-on-the-pointed-one-only (issue 0144);
#       IX-menu-zoomin/out the View menu commands zoom the graph the same way
#       (both axes on the pointed strip, issue 0145); IX-fit Fit
#       reframes the graph data range with NO canvas zoom_full; IX-rmb a
#       synthetic Button-3 press+release box narrows the graph rect x-range via
#       btn3_filter -> the C engine. EVERY IX leg also asserts the canvas
#       xorigin/yorigin/zoom == a once-captured baseline (the graph-not-canvas
#       teeth). Pure Tcl; the C engine and binding table are unchanged.
#   WB* (issue 0152): the wave-BOLD toggle (`hilight_wave`) is a plain LMB
#       CLICK on the plot body, not a Button3 press — on the press it also
#       fired at the start of every RMB box-zoom drag. Needs the real raw
#       (find_closest_wave bails without one, so a data-less run would be
#       hollow). Full Tk sequences via the shipped bindings, each event with an
#       explicit increasing -time (two identical presses close together are
#       collapsed by Tk into <Double-Button-N>, which the viewer swallows).
#       Legs: LMB click bolds/un-bolds; RMB click and RMB box-zoom leave it
#       alone (and the zoom still happens); an LMB drag-pan does not bold (and
#       the pan still happens); the per-trace LEGEND RMB is unchanged.
#       ISSUE 0174 made the pick PRECISE: a click bolds a trace only within
#       GRAPH_TRACE_PICK_TOL (10) SCREEN PIXELS of it, and re-clicking the same
#       trace is what un-bolds. So the click pixel is now SCANNED (the engine's
#       own graph_trace_at) instead of being a fixed fraction of the widget —
#       (0.50W, 0.50H) is about 0.30*H from this fixture's only trace, which is
#       precisely how the old leg passed against a pick with no threshold.
#       WB-precise* are the new legs: a plot-body click far from every trace
#       bolds NOTHING and CLEARS whatever was bold, while a click on the
#       already-bold trace KEEPS it (both settled by the user at review — a
#       plain click never deselects what it lands on; that is 0175's Ctrl+click).
#       This fixture has ONE trace, so the
#       multi-trace half — moving the selection from trace A to trace B in one
#       click — lives in test_wave_trace_menu.tcl's TB* block.
#
# Honest assertability (spec D8): headless/GUI legs can assert raw
# points/vars/sim_type, layer-2 rect count/props, redraw rc 0 and
# modified-still-0; the actual PIXEL rendering of the waves is eyeball-only
# and is NOT asserted anywhere.
#
# Runs via full_audit's DEFAULT arm (GUI legs self-SKIP without a usable
# display). Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_viewer.tcl
# (drop --nogui and provide DISPLAY for the GUI legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch wviewer]

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]
set modelsdir [file join $repo sky130A models libs.tech combined]

# model resolution exactly as sky130A/cadence_style_rc sets it
set ::SKYWATER_MODELS $modelsdir

# scratch registry pointing at the REAL committed trees (test_ase_final
# pattern — never the pre-batch-dirty workarea library.defs)
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]
set rawpath [file join $rundir test_nfet_final_ase.raw]

if {[catch {

# --- fixture state: COPY of the committed .state, scratch rundir, dc sweep
# enabled per the spec schema shape (the committed fixture is never written)
set st [ase::state_load $statefile]
dict set st rundir $rundir
set an {}
foreach a [dict get $st analyses] {
  if {[dict get $a type] eq {dc}} {
    set a [dict create type dc enabled 1 source V2 start 0 stop 1.8 step 0.01]
  }
  lappend an $a
}
dict set st analyses $an

# --- V1: write emission (op enabled in the fixture) --------------------------
set render [ase::backend_hook ngspice render_deck]
set netlist_stub {* stub circuit
V1 D GND 1
.end
}
set deck [$render $st $netlist_stub]
set nwrite 0
foreach line [split $deck "\n"] {
  if {$line eq "write $rawpath"} { incr nwrite }
}
check "V1 exactly one write line with the exact raw path" $nwrite 1
set cidx [string first "\n.control\n" $deck]
set pidx [string first "\nprint -i(v1)\n" $deck]
set widx [string first "\nwrite $rawpath\n" $deck]
set eidx [string first "\n.endc\n" $deck]
check_true "V1 write inside .control, after print, before .endc" \
  [expr {$cidx >= 0 && $pidx > $cidx && $widx > $pidx && $eidx > $widx}]

# --- V2: all analyses disabled -> NO write line ------------------------------
set st2 $st
set an2 {}
foreach a [dict get $st2 analyses] { lappend an2 [dict replace $a enabled 0] }
dict set st2 analyses $an2
set deck2 [$render $st2 $netlist_stub]
check_true "V2 no write line while every analysis is disabled" \
  [expr {![regexp -line {^write } $deck2]}]

# --- V3: the raw_file backend hook -------------------------------------------
set rfhook [ase::backend_hook ngspice raw_file]
check_true "V3 raw_file hook resolves to a command" \
  [expr {[info commands $rfhook] ne {}}]
check "V3 raw_file returns <rundir>/<cell>_ase.raw" [$rfhook $st] $rawpath

# --- V4/V5: real ngspice dc sweep -> raw artifact -> raw read (guarded) ------
set have_raw 0
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: V4/V5 run legs (ngspice not found)"
} else {
  # make the design the CURRENT schematic so ase::netlist works both headless
  # and under has_x (its GUI arm refuses when another schematic is current)
  xschem load $schfile
  set nl [ase::netlist $st]
  set id [ase::run_deck $st $nl]
  set ec [ase::wait $id]
  check "V4 ngspice exit code 0" $ec 0
  check_true "V4 raw artifact produced, non-empty" \
    [expr {[file isfile $rawpath] && [file size $rawpath] > 0}]
  if {[file isfile $rawpath] && [file size $rawpath] > 0} { set have_raw 1 }

  # error-guarded query: `xschem raw sim_type/points/...` THROW when nothing
  # is loaded — a missing artifact must FAIL these checks, not abort the test
  proc rawq {script} {
    if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
    return $r
  }
  set rc [rawq {xschem raw read $rawpath dc}]
  check "V5 raw read returns 1" $rc 1
  check "V5 sim_type is dc" [rawq {xschem raw sim_type}] dc
  check "V5 points == 181 (dc 0..1.8 step 0.01)" [rawq {xschem raw points}] 181
  check_true "V5 vars >= 2" \
    [expr {[string is integer -strict [rawq {xschem raw vars}]] &&
           [rawq {xschem raw vars}] >= 2}]
  check_true "V5 raw loaded index >= 0 (INDEX semantics, never boolean)" \
    [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
           [rawq {xschem raw loaded}] >= 0}]
  catch {xschem raw clear}
}

# --- RG0: no_grid getter/setter roundtrip (item 18; per-window flag, default 0)
# Ends at 0 so the RG1 (normal window keeps its grid) assertion below holds.
check "RG0 no_grid defaults 0 on a normal ctx" [xschem get no_grid] 0
xschem set no_grid 1
check "RG0 no_grid reads back 1 after set" [xschem get no_grid] 1
xschem set no_grid 0
check "RG0 no_grid cleared back to 0" [xschem get no_grid] 0

# --- V6: embedded-graph regression (shipped file, readonly) ------------------
xschem load [file join $repo xschem_library examples test_ne555.sch]
xschem set readonly 1
check_true "V6 shipped schematic keeps its layer-2 graph rect(s)" \
  [expr {[xschem get rects 2] > 0}]
check "V6 first layer-2 rect keeps flags=graph" \
  [xschem getprop rect 2 0 flags] graph
check "V6 redraw rc 0 on the readonly graph schematic" [catch {xschem redraw}] 0

# --- RG1/RG2: normal-window grid + embedded-graph regression (item 18, D7) ----
# The grid-off + fill behavior is VIEWER-WINDOW-ONLY: a plain file load never
# enters wviewer::, so no_grid stays 0 (grid draws) and the embedded graph rect
# is geometrically untouched.
check "RG1 normal window keeps no_grid 0 (grid still draws)" \
  [xschem get no_grid] 0
check_true "RG2 embedded graph rect present on the normal window" \
  [expr {[xschem get rects 2] >= 1}]
check "RG2 redraw rc 0 on the normal graph window" [catch {xschem redraw}] 0

# --- H1-H6: item-12 pure model->props procs (both arms; no window) -----------

# H1: single plain trace -> add_graph-template props with node/color filled
set Gh [dict create traces [list [dict create expr {v(d)} name {} vec {v(d)} \
        color 4]] logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
set ph [wviewer::graph_props $Gh]
check_true "H1 props carry flags=graph" \
  [expr {[string first "flags=graph" $ph] >= 0}]
check_true "H1 props carry node=\"v(d)\"" \
  [expr {[string first "node=\"v(d)\"" $ph] >= 0}]
check_true "H1 props carry color=\"4\"" \
  [expr {[string first "color=\"4\"" $ph] >= 0}]
check_true "H1 logx=0 line" [regexp -line {^logx=0$} $ph]
check_true "H1 logy=0 line" [regexp -line {^logy=0$} $ph]

# H2: alias + multi-trace -> quoted "alias;vec" token (backslash-escaped in
# the in-memory prop form) AND the plain token; color count == trace count
set Gh2 [dict create traces [list \
  [dict create expr {v(d)} name drain vec {v(d)} color 4] \
  [dict create expr {v(g)} name {} vec {v(g)} color 5]] \
  logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
set ph2 [wviewer::graph_props $Gh2]
check_true "H2 alias token \\\"drain;v(d)\\\" present" \
  [expr {[string first "\\\"drain;v(d)\\\"" $ph2] >= 0}]
check_true "H2 plain second token v(g) closes the node attr" \
  [expr {[string first "\nv(g)\"" $ph2] >= 0}]
regexp {color="([^"]*)"} $ph2 -> ph2c
check "H2 color has exactly 2 entries" [llength $ph2c] 2

# H3: explicit ranges + logy override the template defaults
set Gh3 [dict create traces [list [dict create expr {v(d)} name {} vec {v(d)} \
        color 4]] logx 0 logy 1 x1 0 x2 1.8 y1 {} y2 {}]
set ph3 [wviewer::graph_props $Gh3]
check_true "H3 x1=0 line" [regexp -line {^x1=0$} $ph3]
check_true "H3 x2=1.8 line" [regexp -line {^x2=1.8$} $ph3]
check_true "H3 logy=1 line" [regexp -line {^logy=1$} $ph3]

# H-band: viewport-relative equal vertical bands (item 18 replaces the old
# fixed 800x400 / i*450 graph_geometry slots — geometry is now viewport-
# relative, so a graph always FILLS its band of the live window).
# H-band1: single graph fills the whole viewport
check "H-band1 single graph fills the whole viewport" \
  [wviewer::band_geometry 0 1 0 0 1000 800] {0 0 1000 800}
# H-band2: two equal full-width bands, top then bottom
check "H-band2 top half" \
  [wviewer::band_geometry 0 2 0 0 1000 800] {0 0 1000 400}
check "H-band2 bottom half" \
  [wviewer::band_geometry 1 2 0 0 1000 800] {0 400 1000 800}
# H-band3: n=3 tiling — contiguous (band i+1 top == band i bottom), the union
# spans [vy1,vy2], all three share the full width [vx1,vx2]
set hb0 [wviewer::band_geometry 0 3 0 0 1000 800]
set hb1 [wviewer::band_geometry 1 3 0 0 1000 800]
set hb2 [wviewer::band_geometry 2 3 0 0 1000 800]
check_true "H-band3 band1 top == band0 bottom (contiguous)" \
  [expr {[lindex $hb1 1] == [lindex $hb0 3]}]
check_true "H-band3 band2 top == band1 bottom (contiguous)" \
  [expr {[lindex $hb2 1] == [lindex $hb1 3]}]
check_true "H-band3 union spans the full viewport height" \
  [expr {[lindex $hb0 1] == 0 && [lindex $hb2 3] == 800}]
check_true "H-band3 all three bands share the full width" \
  [expr {[lindex $hb0 0] == 0 && [lindex $hb0 2] == 1000 &&
         [lindex $hb1 0] == 0 && [lindex $hb1 2] == 1000 &&
         [lindex $hb2 0] == 0 && [lindex $hb2 2] == 1000}]
# H-band4: a nonzero-origin viewport is used VERBATIM (proves the geometry is
# viewport-relative, not hardcoded 0/800)
check "H-band4 nonzero-origin viewport used verbatim" \
  [wviewer::band_geometry 1 2 -100 -50 900 550] {-100 250 900 550}

# H5: color auto-cycle (palette 4 5 7 8 9 12 14 15 10 11)
set Gh5a [dict create traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
check "H5 fresh graph -> palette head 4" [wviewer::next_color $Gh5a] 4
set Gh5b [dict create traces [list [dict create vec a color 4] \
          [dict create vec b color 5]] logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
check "H5 graph using {4 5} -> 7" [wviewer::next_color $Gh5b] 7
set trs {}
foreach c {4 5 7 8 9 12 14 15 10 11} {
  lappend trs [dict create vec v$c color $c]
}
set Gh5c [dict create traces $trs logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
check "H5 full palette wraps deterministically (10 % 10 -> head)" \
  [wviewer::next_color $Gh5c] 4

# H6: RPN pre-validation (D4) against the save.c token table
check "H6 valid expr {v(d) db20()} ok" \
  [wviewer::validate_rpn {v(d) db20()} {v(d)}] {}
set e6a [wviewer::validate_rpn {v(d) bogus()} {v(d)}]
check_true "H6 bogus() rejected + named" [string match {*bogus()*} $e6a]
set e6b [wviewer::validate_rpn {v(nosuch) db20()} {v(d)}]
check_true "H6 v(nosuch) rejected + named" [string match {*v(nosuch)*} $e6b]
check "H6 bare net d accepted via the v() wrap rule" \
  [wviewer::validate_rpn {d db20()} {v(d)}] {}
check "H6 number tokens accepted (1k 2.5 -3)" \
  [wviewer::validate_rpn {1k 2.5 -3 + +} {v(d)}] {}

# --- GUI legs (DISPLAY-guarded self-SKIP) ------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # deliver a REAL generated key event $ev to $w, WSLg-robustly (the
  # send_key helper pattern from test_ase_dialogs.tcl: Tk redirects GENERATED
  # KeyPress events to the display's focus window and the WSLg focus
  # round-trip is asynchronous — gate every generate on Tk reporting $w as
  # the focus owner and retry until $done, an expr evaluated in the CALLER's
  # scope, turns true). Returns 1 on proven delivery, 0 on ~10s timeout.
  proc send_key {w ev done} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w]} {
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
    puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
    return 0
  }

  proc toplevel_count {} {
    set n 0
    foreach c [winfo children .] {
      if {[winfo class $c] eq {Toplevel}} { incr n }
    }
    return $n
  }

  # wait for the viewer canvas to be mapped (WSLg can be slow); 0 -> the
  # key-event legs SKIP rather than FAIL on a never-mapped window
  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  # recording stub for tk_messageBox: a readonly_block MODAL would hang the
  # test — the stub records the request and answers ok (restored at the end)
  rename ::tk_messageBox ::wvtest_real_messageBox
  set ::mb_hits 0
  proc ::tk_messageBox {args} { incr ::mb_hits; return ok }

  # instrument wviewer::key_filter with an invocation counter WITHOUT
  # changing behavior: a swallowed key changes no product state, so the
  # counter is the only honest delivery witness send_key can gate on.
  # The original is renamed WITHIN its namespace — renaming a namespaced
  # proc into :: breaks its `variable` resolution and the filter then
  # errors instead of filtering (a swallow-by-error looks exactly like a
  # swallow-by-design: hollow-green). kf_errs guards that class: the
  # product filter must never throw.
  rename ::wviewer::key_filter ::wviewer::key_filter_orig
  set ::kf_calls 0
  set ::kf_errs 0
  proc ::wviewer::key_filter {W T x y N K s} {
    incr ::kf_calls
    if {[catch {::wviewer::key_filter_orig $W $T $x $y $N $K $s} e]} {
      incr ::kf_errs
      puts "  key_filter ERROR: $e"
    }
  }

  # user-rc canvas binds that clone_canvas_bindings (xinit.c
  # create_new_window) copies onto every new window's canvas BEFORE
  # wviewer::strip_bindings runs — the strip-sweep fixup target.
  # cadence_style_rc:109 VERBATIM + a per-widget bind shaped like
  # set_bindings' Windows-only Alt arm (the latent class). Unbound again
  # after the GUI legs.
  bind .drw <Key-i> {xschem create_instance; break}
  bind .drw <Alt-KeyPress> {wvtest_alt_arm_probe}

  # --- G1: session registered headless -> wviewer::open ----------------------
  check "G1 unknown token -> 0, no throw" [wviewer::open no/such/token] 0
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate
  # toolbar-strip determinism (fixup r2): pack_widgets packs $top.toolbar on
  # every new window while the GLOBAL toolbar_visible is 1 — force the
  # shipping default so the G1t leg is deterministic under any rc profile
  # (without the strip the viewer showed 37 armed editing/simulator buttons,
  # verifier probe). Restored right after G1t; main-window packedness is
  # asserted UNCHANGED, not absolute, so an rc with toolbar off cannot flip
  # that check.
  set save_tbv 1
  if {[info exists ::toolbar_visible]} { set save_tbv $::toolbar_visible }
  set ::toolbar_visible 1
  set main_tb_packed [expr {![catch {pack info .toolbar}]}]
  check "G1 wviewer::open returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  check_true "G1 viewer toplevel exists" \
    [expr {$vtop ne {} && [winfo exists $vtop]}]
  set vdrw $vtop.drw
  check_true "G1 viewer canvas exists" [winfo exists $vdrw]

  # --- G1t: editor toolbar stripped from the viewer, per-window --------------
  # the widget EXISTS (build_widgets made the surface — the strip is not
  # trivially green) but is neither pack-managed nor mapped; pack info is the
  # mapping-independent witness (`pack forget` -> `pack info` throws even
  # before WSLg ever maps the toplevel)
  check "G1t editor toolbar widget exists on the viewer toplevel" \
    [winfo exists $vtop.toolbar] 1
  check "G1t viewer toolbar NOT pack-managed (pack info throws)" \
    [catch {pack info $vtop.toolbar}] 1
  check "G1t viewer toolbar not mapped" [winfo ismapped $vtop.toolbar] 0
  check "G1t main window toolbar packedness UNCHANGED (per-window strip)" \
    [expr {![catch {pack info .toolbar}]}] $main_tb_packed
  set ::toolbar_visible $save_tbv
  xschem new_schematic switch $vdrw
  check "G1 viewer buffer is readonly" [xschem get readonly] 1
  check_true "G1 viewer buffer is untitled-class" \
    [string match {*untitled*} [file tail [xschem get schname]]]

  # --- G1s: strip SWEEP — cloned user-rc / Windows-arm binds cleared ---------
  # (more-specific Tk binds fire INSTEAD of the generic key_filter, so any
  # survivor is a live editing-verb hole)
  check "G1s cloned <Key-i> cleared from the viewer canvas" \
    [bind $vdrw <Key-i>] {}
  check "G1s cloned <Alt-KeyPress> cleared from the viewer canvas" \
    [bind $vdrw <Alt-KeyPress>] {}
  check "G1s main canvas keeps its own <Key-i> bind (per-widget strip)" \
    [bind .drw <Key-i>] {xschem create_instance; break}
  # completeness: NOTHING outside keep-set + installed filters survives.
  # The allowed list is hardcoded (independent witness, canonical Tk
  # spellings) — reading wviewer::keepseqs back would go hollow if a verb
  # sequence ever crept into it.
  set allowed {
    <Expose> <Configure> <Visibility> <Enter> <Leave> <Motion> <Unmap>
    <MouseWheel> <Button> <ButtonRelease>
    <Key> <KeyRelease> <Button-3> <ButtonRelease-3>
    <Double-Button-1> <Double-Button-2> <Double-Button-3>
    <Button-4> <Button-5> <Shift-Button-4> <Shift-Button-5>
    <Control-Button-4> <Control-Button-5>
    <Shift-MouseWheel> <Control-MouseWheel>
    <Button-2> <ButtonRelease-2> <B2-Motion>
    <Shift-Button-1> <Shift-ButtonRelease-1> <Shift-B1-Motion>
    <Alt-Button-1> <Alt-ButtonRelease-1> <Alt-B1-Motion>
    <Button-1> <B1-Motion> <ButtonRelease-1>
  }
  set stray {}
  foreach seq [bind $vdrw] {
    if {[lsearch -exact $allowed $seq] < 0} { lappend stray $seq }
  }
  check "G1s no canvas sequence outside the keep+filter set" $stray {}

  # --- G2: viewer menubar replaces the editor menubar ------------------------
  set mb [$vtop cget -menu]
  check "G2 attached menu is the viewer menubar" $mb $vtop.wvmenubar
  check_true "G2 editor menubar is NOT the attached menu" \
    [expr {$mb ne "$vtop.menubar"}]
  set labels {}
  for {set i 0} {$i <= [$mb index end]} {incr i} {
    lappend labels [$mb entrycget $i -label]
  }
  # Options joined the fixed cascade list with the plot modes (issue 0151);
  # its contents are asserted in tests/headless/test_wave_modes.tcl (MG4)
  check "G2 cascade labels exactly File View Graph Cursors Options" $labels \
    {File View Graph Cursors Options}
  # item 12 flipped this leg: the item-11 placeholders were disabled, the
  # live core must leave NO Graph/Cursors entry disabled (also G17)
  set anydis 0
  foreach m [list $mb.graph $mb.cursors] {
    for {set i 0} {$i <= [$m index end]} {incr i} {
      if {[$m entrycget $i -state] eq {disabled}} { set anydis 1 }
    }
  }
  check "G2 no Graph/Cursors entry disabled (item-12: menus live)" $anydis 0

  # --- G3: exact title + with_edit clobber regression ------------------------
  set exp_title "Waveforms test_nfet_final (ngspice_state1)"
  check "G3 title exact" [wm title $vtop] $exp_title
  wviewer::with_edit $tok {}
  check "G3 title STILL exact after a with_edit cycle" [wm title $vtop] \
    $exp_title

  # --- G4: window number ------------------------------------------------------
  xschem new_schematic switch $vdrw
  set wnum [xschem get window_number]
  check_true "G4 viewer window number > 0" [expr {$wnum > 0}]

  if {![viewer_ready $vtop]} {
    puts "SKIPPED: G5/G6/G9 key-event legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {
    # --- G5: strip — editing keys do NOTHING, silently -----------------------
    set tls_before [toplevel_count]
    set mbh_before $::mb_hits
    xschem new_schematic switch $vdrw
    set ::kf_calls 0
    set d1 [send_key $vdrw <Key-Insert> {$::kf_calls > 0}]
    set ::kf_calls 0
    set d2 [send_key $vdrw <Key-w> {$::kf_calls > 0}]
    check "G5 Insert + w delivered to the viewer filter" [list $d1 $d2] {1 1}
    # `i`: the cloned create_instance bind would fire INSTEAD of the filter
    # (and `break`) — kf_calls can only move if the sweep cleared it, so
    # delivery-to-filter IS the strip witness for the fixed hole
    set ::kf_calls 0
    set d2i [send_key $vdrw <Key-i> {$::kf_calls > 0}]
    check "G5 i reaches the FILTER (cloned bind swept)" $d2i 1
    update
    xschem new_schematic switch $vdrw
    check "G5 instances still 0" [xschem get instances] 0
    check "G5 wires still 0" [xschem get wires] 0
    check "G5 modified still 0" [xschem get modified] 0
    check "G5 no readonly modal (messageBox stub unhit)" \
      [expr {$::mb_hits - $mbh_before}] 0
    check "G5 no new toplevel appeared" [toplevel_count] $tls_before

    # --- G6: ESC never closes the viewer -------------------------------------
    set mbh_before $::mb_hits
    set ::kf_calls 0
    set d3 [send_key $vdrw <Key-Escape> {$::kf_calls > 0}]
    check "G6 Escape delivered" $d3 1
    update
    check_true "G6 viewer toplevel survives ESC" [winfo exists $vtop]
    check "G6 ESC popped no dialog" [expr {$::mb_hits - $mbh_before}] 0

    # --- G7: display_raw sanity leg ------------------------------------------
    set backups_before [lsort [glob -nocomplain *~.sch]]
    if {$have_raw} {
      check "G7 display_raw returns 1" \
        [wviewer::display_raw $tok $rawpath dc {i(v1)}] 1
    } else {
      puts "SKIPPED: G7 raw-load asserts (no rawfile from V4) - rect only"
      check "G7 display_raw (rect only) returns 1" \
        [wviewer::display_raw $tok {} dc {i(v1)}] 1
    }
    xschem new_schematic switch $vdrw
    check "G7 exactly one layer-2 graph rect" [xschem get rects 2] 1
    check "G7 rect carries flags=graph" [xschem getprop rect 2 0 flags] graph
    check_true "G7 rect node attr carries i(v1)" \
      [string match {*i(v1)*} [xschem getprop rect 2 0 node]]
    if {$have_raw} {
      check "G7 raw points 181 in the viewer ctx" [xschem raw points] 181
    }
    check "G7 redraw rc 0" [catch {xschem redraw}] 0
    check "G7 modified still 0 after display_raw" [xschem get modified] 0
    check "G7 readonly restored after display_raw" [xschem get readonly] 1
    check "G7 no untitled autosave backup appeared (D1 bracket)" \
      [lsort [glob -nocomplain *~.sch]] $backups_before

    # --- G8: re-open raises the SAME window ----------------------------------
    set tls_before [toplevel_count]
    check "G8 re-open returns 1" [wviewer::open $tok] 1
    check "G8 same toplevel" [wviewer::window_for $tok] $vtop
    check "G8 no second window" [toplevel_count] $tls_before
    xschem new_schematic switch $vdrw
    check "G8 window number unchanged" [xschem get window_number] $wnum

    # --- G9: Ctrl-W closes with NO prompt; reopen builds fresh ---------------
    set mbh_before $::mb_hits
    set d4 [send_key $vdrw <Control-Key-w> {![winfo exists $vtop]}]
    check "G9 Ctrl-W closed the viewer" $d4 1
    check_true "G9 toplevel destroyed" [expr {![winfo exists $vtop]}]
    check "G9 close popped no dialog/prompt" \
      [expr {$::mb_hits - $mbh_before}] 0
    check "G9 registry cleaned" [wviewer::window_for $tok] {}
    check "G9 reopen after close returns 1" [wviewer::open $tok] 1
    set vtop2 [wviewer::window_for $tok]
    check_true "G9 fresh viewer window created" \
      [expr {$vtop2 ne {} && [winfo exists $vtop2]}]
    check "G9 fresh viewer toolbar also stripped" \
      [catch {pack info $vtop2.toolbar}] 1
    wviewer::close $tok
    update
    check "G9 closed via the API, registry clean" [wviewer::window_for $tok] {}
  }

  # ===== item 12: viewer core (G10-G17, fresh viewer window) =================
  check "G10 core-legs reopen returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  set mb $vtop.wvmenubar
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: G10-G17 core legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {

    # --- G10: Add Graph (menu live; model -> rects -> graphbb agree) ---------
    set gmenu $mb.graph
    check_true "G10 Add Graph entry enabled" \
      [expr {[$gmenu entrycget [$gmenu index {Add Graph}] -state] ne {disabled}}]
    $gmenu invoke [$gmenu index {Add Graph}]
    $gmenu invoke [$gmenu index {Add Graph}]
    update                                 ;# flush any pending <Configure> refit
    check "G10 model has 2 graphs" \
      [llength [dict get [wviewer::layout_for $tok] graphs]] 2
    xschem new_schematic switch $vdrw
    check "G10 two layer-2 graph rects" [xschem get rects 2] 2
    set bbs [dict get $::wviewer::graphbb $vdrw]
    check "G10 graphbb has 2 bands" [llength $bbs] 2
    # item 18: the two graphs split the live viewport into equal full-width
    # halves (viewport-relative, replacing the old fixed i*450 slot). graphbb is
    # built from band_geometry, so each row equals the band of the live viewport;
    # row 1 is the BOTTOM half.
    set vp10 [wviewer::viewport_rect $vdrw]
    lassign $vp10 v10x1 v10y1 v10x2 v10y2
    check "G10 graphbb row 0 == band 0 of 2 (top half)" \
      [lindex $bbs 0] [wviewer::band_geometry 0 2 $v10x1 $v10y1 $v10x2 $v10y2]
    check "G10 graphbb row 1 == band 1 of 2 (bottom half)" \
      [lindex $bbs 1] [wviewer::band_geometry 1 2 $v10x1 $v10y1 $v10x2 $v10y2]
    check_true "G10 rows are contiguous (row1 top == row0 bottom)" \
      [expr {[lindex [lindex $bbs 1] 1] == [lindex [lindex $bbs 0] 3]}]
    check_true "G10 both rows span the full viewport width" \
      [expr {[lindex [lindex $bbs 0] 0] == $v10x1 &&
             [lindex [lindex $bbs 0] 2] == $v10x2 &&
             [lindex [lindex $bbs 1] 0] == $v10x1 &&
             [lindex [lindex $bbs 1] 2] == $v10x2}]

    set names {}
    if {$have_raw} {
      # raw goes into the (fresh) viewer ctx: per-context xctx->raw
      xschem new_schematic switch $vdrw
      check "G11 raw read into the viewer ctx" [rawq {xschem raw read $rawpath dc}] 1
      set names [split [xschem raw list] "\n"]
      set var1 [lindex $names 1]                     ;# first non-sweep var

      # --- G11: Add Trace picked from the raw-vars listbox -------------------
      set w [wviewer::add_trace_dialog $tok]
      check_true "G11 Add Trace dialog exists" [winfo exists $w]
      check "G11 listbox count == raw vars" [$w.vars size] [xschem raw vars]
      $w.vars selection clear 0 end
      $w.vars selection set 1
      $w.expr delete 0 end                           ;# empty -> listbox pick
      wviewer::add_trace_ok $tok
      check_true "G11 dialog closed on OK" [expr {![winfo exists $w]}]
      xschem new_schematic switch $vdrw
      check_true "G11 rect 1 node carries the picked var verbatim" \
        [expr {[string first $var1 [xschem getprop rect 2 1 node]] >= 0}]
      check "G11 rect 1 color == palette head" [xschem getprop rect 2 1 color] 4
      set g1 [lindex [dict get [wviewer::layout_for $tok] graphs] 1]
      check "G11 model records 1 trace on the LAST (default) graph" \
        [llength [dict get $g1 traces]] 1
      set t0 [lindex [dict get $g1 traces] 0]
      check "G11 model trace vec == picked var" [dict get $t0 vec] $var1
      check "G11 model trace color 4" [dict get $t0 color] 4

      # --- G12: expression trace (RPN via `xschem raw add`) ------------------
      set w [wviewer::add_trace_dialog $tok]
      $w.expr delete 0 end
      $w.expr insert 0 "$var1 db20()"
      $w.name delete 0 end
      $w.name insert 0 db1
      wviewer::add_trace_ok $tok
      check_true "G12 dialog closed on OK" [expr {![winfo exists $w]}]
      xschem new_schematic switch $vdrw
      check_true "G12 raw vector db1 exists (raw index >= 0)" \
        [expr {[rawq {xschem raw index db1}] >= 0}]
      check_true "G12 rect 1 node carries db1" \
        [expr {[string first db1 [xschem getprop rect 2 1 node]] >= 0}]
      check "G12 redraw rc 0" [catch {xschem redraw}] 0
      set g1 [lindex [dict get [wviewer::layout_for $tok] graphs] 1]
      set t1 [lindex [dict get $g1 traces] 1]
      check "G12 model stores the original RPN expr" [dict get $t1 expr] \
        "$var1 db20()"
      check "G12 model stores the vector name" [dict get $t1 vec] db1

      # --- G12b: bad expression surfaces in-dialog (D4), no phantom ----------
      set before_g [dict get [wviewer::layout_for $tok] graphs]
      set w [wviewer::add_trace_dialog $tok]
      $w.expr delete 0 end
      $w.expr insert 0 "v(nosuchnet) db20()"
      $w.name delete 0 end
      $w.name insert 0 db2
      check "G12b OK path does not throw" [catch {wviewer::add_trace_ok $tok}] 0
      check_true "G12b dialog still up" [winfo exists $w]
      set errtxt {}
      catch {set errtxt [$w.err cget -text]}
      check_true "G12b error label non-empty" [expr {$errtxt ne {}}]
      xschem new_schematic switch $vdrw
      check "G12b no phantom raw vector db2" [rawq {xschem raw index db2}] -1
      check_true "G12b model unchanged" \
        [expr {[dict get [wviewer::layout_for $tok] graphs] eq $before_g}]
      catch {$w.btns.cancel invoke}                  ;# ESC-equivalent path
      check_true "G12b dialog dismissed via cancel" [expr {![winfo exists $w]}]
    } else {
      puts "SKIPPED: G11/G12 raw-driven legs (no rawfile from V4)"
    }

    # --- G13: Axes dialog log toggle + explicit ranges -----------------------
    set w [wviewer::axes_dialog $tok]
    check_true "G13 Axes dialog exists" [winfo exists $w]
    $w.graph set 0
    wviewer::axes_load $tok
    $w.x1 delete 0 end
    $w.x1 insert 0 0
    $w.x2 delete 0 end
    $w.x2 insert 0 1.8
    set ::wviewer::axl($tok,y) 1
    wviewer::axes_ok $tok
    check_true "G13 dialog closed on OK" [expr {![winfo exists $w]}]
    xschem new_schematic switch $vdrw
    check "G13 rect 0 logy == 1" [xschem getprop rect 2 0 logy] 1
    check_true "G13 rect 0 x1 exact 0" \
      [expr {[xschem getprop rect 2 0 x1] == 0}]
    check_true "G13 rect 0 x2 exact 1.8" \
      [expr {[xschem getprop rect 2 0 x2] == 1.8}]
    set g0 [lindex [dict get [wviewer::layout_for $tok] graphs] 0]
    check "G13 model logy" [dict get $g0 logy] 1
    check "G13 model x1" [dict get $g0 x1] 0
    check "G13 model x2" [dict get $g0 x2] 1.8

    if {$have_raw} {
      # --- G14: Delete dialog — one trace, then a whole graph ----------------
      set var1 [lindex $names 1]
      set w [wviewer::delete_dialog $tok]
      set rows {}
      for {set i 0} {$i < [$w.items size]} {incr i} {
        lappend rows [$w.items get $i]
      }
      # the picked-var trace row is exactly "graph 1: <var> (<var>)" — the
      # db1 row also CONTAINS $var1 (inside its expr), so match the full row
      set want "graph 1: $var1 ($var1)"
      set ri [lsearch -exact $rows $want]
      check_true "G14 trace row found in the Delete listbox" [expr {$ri >= 0}]
      # --- G14b: the dialog is UNDOABLE and REPLAYABLE (issue 0176) ---------
      # It was neither until 0176: `delete_ok` had no push_undo and no
      # log_action, so a dialog delete could not be taken back and could not be
      # replayed. That was a PRE-EXISTING defect, repaired by routing the
      # dialog through `wviewer::delete_items` — the same proc the DEL key
      # uses. These legs are what stop it regressing to a bare model write.
      set ::g14log {}
      rename wviewer::log_action wviewer::__g14_real_log
      proc wviewer::log_action {line} { lappend ::g14log $line }
      wviewer::clear_history $tok
      # the MODEL trace index behind that listbox ROW — the log line names the
      # model, not the widget, which is exactly what makes it replayable
      set g14ent [lindex $wviewer::delmap($tok) $ri]
      set ri1 [lindex $g14ent 2]
      check "G14b the picked row decodes to a trace of graph 1" \
        [lrange $g14ent 0 1] {trace 1}
      $w.items selection clear 0 end
      $w.items selection set $ri
      set g14n [wviewer::delete_ok $tok]
      xschem new_schematic switch $vdrw
      check "G14b OK reports the one thing it deleted" $g14n 1
      check_true "G14 deleted trace gone from the node attr" \
        [expr {[string first $var1 [xschem getprop rect 2 1 node]] < 0}]
      set g1 [lindex [dict get [wviewer::layout_for $tok] graphs] 1]
      check "G14 model graph 1 keeps exactly the surviving trace" \
        [llength [dict get $g1 traces]] 1
      check "G14 surviving trace is db1" \
        [dict get [lindex [dict get $g1 traces] 0] vec] db1
      check "G14b the dialog delete pushed exactly ONE undo point" \
        [wviewer::history_depth $tok] {1 0}
      check "G14b ... and logged exactly one line, with EXPLICIT model indices" \
        [list [llength $::g14log] [lindex $::g14log 0]] \
        [list 1 "wviewer::delete_items {} {{1 $ri1}} {} $tok"]
      check "G14b `u` puts the trace back" \
        [list [wviewer::undo $tok] \
              [llength [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 1] traces]]] \
        {1 2}
      check "G14b ... and `U` takes it away again" \
        [list [wviewer::redo $tok] \
              [llength [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 1] traces]]] \
        {1 1}
      # an OK with nothing selected is a no-op: no undo point, no log line
      set ::g14log {}
      wviewer::clear_history $tok
      set w2 [wviewer::delete_dialog $tok]
      $w2.items selection clear 0 end
      check "G14b OK with an empty selection deletes nothing" \
        [wviewer::delete_ok $tok] 0
      check "G14b ... and pushes no undo point and logs nothing" \
        [list [wviewer::history_depth $tok] [llength $::g14log]] {{0 0} 0}
      rename wviewer::log_action {}
      rename wviewer::__g14_real_log wviewer::log_action
      xschem new_schematic switch $vdrw
      # whole-graph delete: graph 1 disappears, graph 0 re-stacks from y 0
      set w [wviewer::delete_dialog $tok]
      set rows {}
      for {set i 0} {$i < [$w.items size]} {incr i} {
        lappend rows [$w.items get $i]
      }
      set ri [lsearch -exact $rows {graph 1}]
      check_true "G14 graph row found" [expr {$ri >= 0}]
      $w.items selection clear 0 end
      $w.items selection set $ri
      wviewer::delete_ok $tok
      xschem new_schematic switch $vdrw
      check "G14 rects drop to 1" [xschem get rects 2] 1
      check "G14 model drops to 1 graph" \
        [llength [dict get [wviewer::layout_for $tok] graphs]] 1
      # item 18: the sole surviving graph re-FILLS the WHOLE viewport (n=1),
      # not a fixed 800x400 slot — compute the expected full-viewport band
      update
      set vp14 [wviewer::viewport_rect $vdrw]
      lassign $vp14 v14x1 v14y1 v14x2 v14y2
      check "G14 remaining graph fills the whole viewport" \
        [lindex [dict get $::wviewer::graphbb $vdrw] 0] \
        [wviewer::band_geometry 0 1 $v14x1 $v14y1 $v14x2 $v14y2]

      # --- G15: cursors + readout (menu-driven; interpolation honest) --------
      set sweepv [lindex $names 0]
      set cx 0.905                       ;# strictly between two sweep samples
      xschem new_schematic switch $vdrw
      set pos [xschem raw pos_at $sweepv $cx]
      check_true "G15 pos_at finds the bracketing sample" [expr {$pos >= 0}]
      set slopevar {}
      foreach v [lrange $names 1 end] {
        set va [xschem raw value $v $pos]
        set vb [xschem raw value $v [expr {$pos + 1}]]
        if {$va != $vb} { set slopevar $v; break }
      }
      check_true "G15 found a nonzero-slope var" [expr {$slopevar ne {}}]
      check "G15 add slope trace to graph 0" \
        [wviewer::add_trace $tok 0 $slopevar {}] {}
      set cmenu $mb.cursors
      $cmenu invoke [$cmenu index {Cursor A}]
      $cmenu invoke [$cmenu index {Cursor B}]
      check "G15 cursor mirrors both on" \
        [list $::wviewer::cva($tok) $::wviewer::cvb($tok)] {1 1}
      check_true "G15 readout bar auto-shown (pack-managed)" \
        [expr {![catch {pack info $vtop.wvreadout}]}]
      xschem new_schematic switch $vdrw
      xschem redraw                      ;# engine graph ctx follows the rects
      xschem set cursor1_x $cx
      xschem set cursor2_x $cx           ;# fires the engine backannotate (B)
      wviewer::readout_refresh $tok
      set ta [$vtop.wvreadout.a cget -text]
      set tb [$vtop.wvreadout.b cget -text]
      set fx [ase::format_value $cx]
      check_true "G15a A line shows x=$fx" \
        [expr {[string first "x=$fx" $ta] >= 0}]
      check_true "G15a B line shows x=$fx" \
        [expr {[string first "x=$fx" $tb] >= 0}]
      set yh [wviewer::interp_value $slopevar $cx]
      set ye [xschem raw value $slopevar {}]  ;# engine cursor-B ground truth
      set denom [expr {abs($ye) > 1e-30 ? abs($ye) : 1e-30}]
      check_true "G15b Tcl interpolation == engine cursor_b_val (rel 1e-6)" \
        [expr {abs($yh - $ye) / $denom < 1e-6}]
      set ynear [xschem raw value $slopevar $pos]
      check_true "G15c interpolated y differs from the nearest sample" \
        [expr {abs($yh - $ynear) > 0}]
      set fy [ase::format_value $yh]
      check_true "G15d A line carries $slopevar=$fy (same helper, cursor A)" \
        [expr {[string first "$slopevar=$fy" $ta] >= 0}]
      check_true "G15d B line carries $slopevar=$fy" \
        [expr {[string first "$slopevar=$fy" $tb] >= 0}]

      # --- G16: View > Fit = engine autozoom + model read-back ---------------
      set gs [dict get [wviewer::layout_for $tok] graphs]
      set g0 [dict replace [lindex $gs 0] x1 0.5 x2 1.0]
      wviewer::set_graphs $tok [lreplace $gs 0 0 $g0]
      wviewer::regenerate $tok
      xschem new_schematic switch $vdrw
      check_true "G16 rect shows the subrange (x1 0.5)" \
        [expr {[xschem getprop rect 2 0 x1] == 0.5}]
      $mb.view invoke [$mb.view index Fit]
      xschem new_schematic switch $vdrw
      set rx1 [xschem getprop rect 2 0 x1]
      set rx2 [xschem getprop rect 2 0 x2]
      set np   [xschem raw points]
      set smin [xschem raw value $sweepv 0]
      set smax [xschem raw value $sweepv [expr {$np - 1}]]
      if {$smin > $smax} { foreach {smin smax} [list $smax $smin] break }
      set ftol [expr {1e-6 * (abs($smax) + 1.0)}]
      check_true "G16 fit x1 == sweep min ($smin)" \
        [expr {abs($rx1 - $smin) <= $ftol}]
      check_true "G16 fit x2 == sweep max ($smax)" \
        [expr {abs($rx2 - $smax) <= $ftol}]
      set g0 [lindex [dict get [wviewer::layout_for $tok] graphs] 0]
      check "G16 model x1 read back from the rect" [dict get $g0 x1] $rx1
      check "G16 model x2 read back from the rect" [dict get $g0 x2] $rx2
    } else {
      puts "SKIPPED: G14/G15/G16 raw-driven legs (no rawfile from V4)"
    }

    # --- G17: every Graph + Cursors entry live -------------------------------
    set anydis17 0
    foreach m [list $mb.graph $mb.cursors] {
      for {set i 0} {$i <= [$m index end]} {incr i} {
        if {[$m entrycget $i -state] eq {disabled}} { set anydis17 1 }
      }
    }
    check "G17 no Graph/Cursors entry left disabled" $anydis17 0

    wviewer::close $tok
    update
  }

  # ===== item 18: the graph FILLS the viewer window (GF1-GF5) ================
  # A fresh viewer: assert the graph rect covers ~the full canvas viewport,
  # refits on resize, splits into equal bands for multi-graph, and regenerate
  # never re-frames (shrinks) the canvas.
  check "GF item-18 reopen returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  set mb $vtop.wvmenubar
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: GF1-GF5 fill legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {
    # let the map-time <Configure> refit + any pending_fullzoom settle
    for {set i 0} {$i < 60} {incr i} { update; after 20 }

    # the live viewport-covering rect in schematic coords (mirrors
    # wviewer::viewport_rect, computed independently as the test's witness)
    proc gf_viewport {vdrw} {
      xschem new_schematic switch $vdrw
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      set z [xschem get zoom]
      set xo [xschem get xorigin]; set yo [xschem get yorigin]
      return [list [expr {-$xo}] [expr {-$yo}] \
                   [expr {$W * $z - $xo}] [expr {$H * $z - $yo}]]
    }
    proc gf_near {a b tol} { expr {abs($a - $b) <= $tol} }

    # --- GF1: a single graph fills the whole viewport ------------------------
    $mb.graph invoke [$mb.graph index {Add Graph}]
    update
    xschem new_schematic switch $vdrw
    check "GF1 exactly one graph rect" [xschem get rects 2] 1
    set bb0 [lindex [dict get $::wviewer::graphbb $vdrw] 0]
    lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
    set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.02 + 2}]
    check_true "GF1 graph left edge ~ viewport left" \
      [gf_near [lindex $bb0 0] $vx1 $tol]
    check_true "GF1 graph right edge ~ viewport right" \
      [gf_near [lindex $bb0 2] $vx2 $tol]
    check_true "GF1 graph top edge ~ viewport top" \
      [gf_near [lindex $bb0 1] $vy1 $tol]
    check_true "GF1 graph bottom edge ~ viewport bottom" \
      [gf_near [lindex $bb0 3] $vy2 $tol]

    # --- GF2: grid OFF in the viewer, ON in a normal window ------------------
    xschem new_schematic switch $vdrw
    check "GF2 viewer no_grid == 1" [xschem get no_grid] 1
    check "GF2 viewer redraw rc 0 (no_grid draw path runs clean)" \
      [catch {xschem redraw}] 0
    xschem new_schematic switch .drw
    check "GF2 design/main canvas no_grid == 0" [xschem get no_grid] 0
    xschem new_schematic switch $vdrw

    # --- GF3: resize -> refit ran (graph still fills, and it grew) -----------
    xschem new_schematic switch $vdrw
    set bb_before [lindex [dict get $::wviewer::graphbb $vdrw] 0]
    set w_before [winfo width $vdrw]
    set h_before [winfo height $vdrw]
    wm geometry $vtop 1200x900
    update
    for {set i 0} {$i < 120} {incr i} {
      update
      if {[winfo width $vdrw] != $w_before || \
          [winfo height $vdrw] != $h_before} break
      after 20
    }
    update; after 150; update            ;# let on_configure's after-idle fire
    if {[winfo width $vdrw] == $w_before && [winfo height $vdrw] == $h_before} {
      puts "SKIPPED: GF3 resize refit (WM refused the resize)"
    } else {
      xschem new_schematic switch $vdrw
      set bb_after [lindex [dict get $::wviewer::graphbb $vdrw] 0]
      lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
      set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.02 + 2}]
      check_true "GF3 graph still covers the new viewport (right edge)" \
        [gf_near [lindex $bb_after 2] $vx2 $tol]
      check_true "GF3 graph still covers the new viewport (bottom edge)" \
        [gf_near [lindex $bb_after 3] $vy2 $tol]
      set wb [expr {[lindex $bb_before 2] - [lindex $bb_before 0]}]
      set wa [expr {[lindex $bb_after 2] - [lindex $bb_after 0]}]
      set hb [expr {[lindex $bb_before 3] - [lindex $bb_before 1]}]
      set ha [expr {[lindex $bb_after 3] - [lindex $bb_after 1]}]
      check_true "GF3 graph grew vs the pre-resize bbox (refit ran)" \
        [expr {$wa > $wb || $ha > $hb}]
    }

    # --- GF4: two graphs each fill a half ------------------------------------
    $mb.graph invoke [$mb.graph index {Add Graph}]
    update
    xschem new_schematic switch $vdrw
    check "GF4 two graph rects" [xschem get rects 2] 2
    set bbs [dict get $::wviewer::graphbb $vdrw]
    check "GF4 graphbb has 2 entries" [llength $bbs] 2
    set gtop [lindex $bbs 0]; set gbot [lindex $bbs 1]
    lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
    set mid [expr {($vy1 + $vy2) / 2.0}]
    set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.03 + 2}]
    check_true "GF4 top graph starts at the viewport top" \
      [gf_near [lindex $gtop 1] $vy1 $tol]
    check_true "GF4 top graph ends at the midpoint" \
      [gf_near [lindex $gtop 3] $mid $tol]
    check_true "GF4 bottom graph starts at the midpoint" \
      [gf_near [lindex $gbot 1] $mid $tol]
    check_true "GF4 bottom graph ends at the viewport bottom" \
      [gf_near [lindex $gbot 3] $vy2 $tol]
    check_true "GF4 both graphs span the full viewport width" \
      [expr {[gf_near [lindex $gtop 0] $vx1 $tol] &&
             [gf_near [lindex $gtop 2] $vx2 $tol] &&
             [gf_near [lindex $gbot 0] $vx1 $tol] &&
             [gf_near [lindex $gbot 2] $vx2 $tol]}]
    check_true "GF4 bands contiguous (bottom top == top bottom)" \
      [expr {[lindex $gbot 1] == [lindex $gtop 3]}]

    # --- GF5: regenerate does NOT re-frame the canvas (kill the shrink) -------
    xschem new_schematic switch $vdrw
    set zoom0 [xschem get zoom]
    set xo0 [xschem get xorigin]
    set yo0 [xschem get yorigin]
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    check "GF5 zoom unchanged across regenerate" [xschem get zoom] $zoom0
    check "GF5 xorigin unchanged across regenerate" [xschem get xorigin] $xo0
    check "GF5 yorigin unchanged across regenerate" [xschem get yorigin] $yo0
    set bb0 [lindex [dict get $::wviewer::graphbb $vdrw] 0]
    lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
    set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.02 + 2}]
    check_true "GF5 graph still fills after regenerate (full width)" \
      [expr {[gf_near [lindex $bb0 0] $vx1 $tol] &&
             [gf_near [lindex $bb0 2] $vx2 $tol]}]

    rename gf_viewport {}
    rename gf_near {}
    wviewer::close $tok
    update
  }

  # ===== item 19: wheel / RMB / f / View-zoom act on the GRAPH (IX) ==========
  # Deterministic: every leg drives a wviewer:: proc (or a synthetic C callback)
  # and witnesses a SYNCHRONOUS state write (graph rect range tokens) — never a
  # gesture/stacking/timing race (item-17 de-flake lesson). The graph-not-canvas
  # TEETH: after every op the canvas xorigin/yorigin/zoom must equal the baseline
  # captured once (item-18 pinned them; only the graph axes may change).
  check "IX item-19 reopen returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  set mb $vtop.wvmenubar
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: IX interaction legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {
    # let the map-time <Configure> refit settle so the canvas viewport is stable
    for {set i 0} {$i < 40} {incr i} { update; after 20 }

    # ONE graph with KNOWN concrete ranges. No trace / no raw needed: the wheel,
    # zoom and RMB x-box all operate on the graph rect's range tokens, which exist
    # regardless of loaded data — this keeps the whole IX block ngspice-independent
    # and deterministic.
    proc ix_setrange {tok x1 x2 y1 y2} {
      set gs [dict get [wviewer::layout_for $tok] graphs]
      set G [dict replace [lindex $gs 0] x1 $x1 x2 $x2 y1 $y1 y2 $y2]
      wviewer::set_graphs $tok [lreplace $gs 0 0 $G]
      wviewer::regenerate $tok
    }
    proc ix_canvas_ok {vdrw cx0 cy0 cz0} {
      xschem new_schematic switch $vdrw
      expr {[xschem get xorigin] == $cx0 && [xschem get yorigin] == $cy0 &&
            [xschem get zoom] == $cz0}
    }
    wviewer::add_graph $tok                       ;# one empty graph, fills window
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    check_true "IX-setup rect x1/x2/y1/y2 == 0/10/-1/1" \
      [expr {[xschem getprop rect 2 0 x1] == 0 && [xschem getprop rect 2 0 x2] == 10 &&
             [xschem getprop rect 2 0 y1] == -1 && [xschem getprop rect 2 0 y2] == 1}]
    # baseline canvas AFTER the setup regenerate (stable henceforth: regenerate,
    # wheel, zoom and fit all leave the canvas pinned — the invariant under test)
    set cx0 [xschem get xorigin]
    set cy0 [xschem get yorigin]
    set cz0 [xschem get zoom]

    # --- IX-vpan-up / IX-vpan-dn: plain wheel = GRAPH vertical pan ------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set y1a [xschem getprop rect 2 0 y1]; set y2a [xschem getprop rect 2 0 y2]
    set x1a [xschem getprop rect 2 0 x1]; set x2a [xschem getprop rect 2 0 x2]
    wviewer::wheel $tok $vdrw up 0
    xschem new_schematic switch $vdrw
    set dyu1 [expr {[xschem getprop rect 2 0 y1] - $y1a}]
    set dyu2 [expr {[xschem getprop rect 2 0 y2] - $y2a}]
    check_true "IX-vpan-up y1,y2 shift by the same nonzero delta" \
      [expr {abs($dyu1 - $dyu2) < 1e-9 && abs($dyu1) > 1e-9}]
    check_true "IX-vpan-up x range unchanged" \
      [expr {[xschem getprop rect 2 0 x1] == $x1a &&
             [xschem getprop rect 2 0 x2] == $x2a}]
    check_true "IX-vpan-up canvas == baseline (graph-not-canvas)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set y1a [xschem getprop rect 2 0 y1]; set y2a [xschem getprop rect 2 0 y2]
    wviewer::wheel $tok $vdrw down 0
    xschem new_schematic switch $vdrw
    set dyd1 [expr {[xschem getprop rect 2 0 y1] - $y1a}]
    set dyd2 [expr {[xschem getprop rect 2 0 y2] - $y2a}]
    check_true "IX-vpan-dn y1,y2 shift by the same nonzero delta" \
      [expr {abs($dyd1 - $dyd2) < 1e-9 && abs($dyd1) > 1e-9}]
    check_true "IX-vpan-dn is opposite in sign to IX-vpan-up" \
      [expr {$dyd1 * $dyu1 < 0}]
    check_true "IX-vpan-dn canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-hpan: Shift+wheel = GRAPH horizontal pan -------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set x1a [xschem getprop rect 2 0 x1]; set x2a [xschem getprop rect 2 0 x2]
    set y1a [xschem getprop rect 2 0 y1]; set y2a [xschem getprop rect 2 0 y2]
    wviewer::wheel $tok $vdrw up shift
    xschem new_schematic switch $vdrw
    set dxh1 [expr {[xschem getprop rect 2 0 x1] - $x1a}]
    set dxh2 [expr {[xschem getprop rect 2 0 x2] - $x2a}]
    check_true "IX-hpan x1,x2 shift by the same nonzero delta" \
      [expr {abs($dxh1 - $dxh2) < 1e-9 && abs($dxh1) > 1e-9}]
    check_true "IX-hpan y range unchanged" \
      [expr {[xschem getprop rect 2 0 y1] == $y1a &&
             [xschem getprop rect 2 0 y2] == $y2a}]
    check_true "IX-hpan canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-anchor-pure (issue 0146): wviewer::zoom_about keeps the anchor at
    # the same relative position; empty anchor = centre; outside anchor clamps.
    # Pure math, no display needed. --------------------------------------------
    lassign [wviewer::zoom_about 0 10 2 0.8] _zl _zh
    check_true {IX-anchor-pure anchor 2 in 0..10 f=0.8 -> 0.4 8.4} \
      [expr {abs($_zl - 0.4) < 1e-12 && abs($_zh - 8.4) < 1e-12}]
    check {IX-anchor-pure empty anchor == centre -> {1.0 9.0}} \
      [wviewer::zoom_about 0 10 {} 0.8] {1.0 9.0}
    check {IX-anchor-pure anchor past hi clamps to hi -> {2.0 10.0}} \
      [wviewer::zoom_about 0 10 20 0.8] {2.0 10.0}
    set _za [wviewer::zoom_about 0 10 2 0.8]
    check_true "IX-anchor-pure span scales by f (8 == 10*0.8)" \
      [expr {abs(([lindex $_za 1] - [lindex $_za 0]) - 8.0) < 1e-12}]
    check_true "IX-anchor-pure anchor fraction preserved (0.2)" \
      [expr {abs((2.0 - [lindex $_za 0]) / 8.0 - 0.2) < 1e-12}]

    # --- IX-zoom-in / IX-zoom-out: Ctrl+wheel = GRAPH zoom, BOTH axes on the
    # strip under the cursor (issue 0144; the y-span legs are RED pre-fix, when
    # ctrl-wheel was X-only) -------------------------------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    wviewer::wheel $tok $vdrw up ctrl
    xschem new_schematic switch $vdrw
    set spani [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspani [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-zoom-in x-span strictly smaller" [expr {$spani < $span0 - 1e-9}]
    check_true "IX-zoom-in y-span strictly smaller (both axes)" \
      [expr {$yspani < $yspan0 - 1e-9}]
    check_true "IX-zoom-in canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    wviewer::wheel $tok $vdrw down ctrl
    xschem new_schematic switch $vdrw
    set spano [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspano [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-zoom-out x-span strictly larger" [expr {$spano > $span0 + 1e-9}]
    check_true "IX-zoom-out y-span strictly larger (both axes)" \
      [expr {$yspano > $yspan0 + 1e-9}]
    check_true "IX-zoom-out canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-anchor (issue 0146): THE teeth — Ctrl+wheel must zoom AT the mouse
    # pointer, like the schematic's view_zoom. The invariant: the data point under
    # a given canvas pixel is the SAME before and after the zoom. Uses a pixel
    # well OFF-centre (30% of the canvas, inside the plot body: 14%..95% x,
    # 14%..86% y) so a centre-anchored zoom visibly moves it -> RED pre-fix. Also
    # validates the new C verb `xschem graph_coord`. -------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set apx [expr {int(0.30 * [winfo width $vdrw])}]
    set apy [expr {int(0.30 * [winfo height $vdrw])}]
    set a0 [xschem graph_coord 0 $apx $apy]
    check_true "IX-anchor graph_coord returns two numbers" \
      [expr {[llength $a0] == 2 && [string is double -strict [lindex $a0 0]] &&
             [string is double -strict [lindex $a0 1]]}]
    set xs0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ys0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-anchor probe pixel is off-centre in the data window" \
      [expr {abs([lindex $a0 0] - 5.0) > 0.5 && abs([lindex $a0 1] - 0.0) > 0.05}]
    wviewer::wheel $tok $vdrw up ctrl $apx $apy
    xschem new_schematic switch $vdrw
    set a1 [xschem graph_coord 0 $apx $apy]
    set xs1 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ys1 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-anchor it really zoomed in (both spans shrank)" \
      [expr {$xs1 < $xs0 - 1e-9 && $ys1 < $ys0 - 1e-9}]
    check_true "IX-anchor X under the pointer did not move" \
      [expr {abs([lindex $a1 0] - [lindex $a0 0]) < 1e-6 * $xs0}]
    check_true "IX-anchor Y under the pointer did not move" \
      [expr {abs([lindex $a1 1] - [lindex $a0 1]) < 1e-6 * $ys0}]
    # zoom back OUT at the same pixel: still pinned
    wviewer::wheel $tok $vdrw down ctrl $apx $apy
    xschem new_schematic switch $vdrw
    set a2 [xschem graph_coord 0 $apx $apy]
    check_true "IX-anchor zoom-out at the same pixel stays pinned" \
      [expr {abs([lindex $a2 0] - [lindex $a0 0]) < 1e-6 * $xs0 &&
             abs([lindex $a2 1] - [lindex $a0 1]) < 1e-6 * $ys0}]
    check_true "IX-anchor canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-menu-zoomin / IX-menu-zoomout: View menu commands. Like Ctrl+wheel
    # they zoom BOTH axes on the pointed strip (issue 0145; the y-span legs are
    # RED pre-fix, when the menu zoom was X-only) --------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    $mb.view invoke [$mb.view index {Zoom In}]
    xschem new_schematic switch $vdrw
    set spani [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspani [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-menu-zoomin x-span shrinks on the graph" \
      [expr {$spani < $span0 - 1e-9}]
    check_true "IX-menu-zoomin y-span shrinks too (both axes)" \
      [expr {$yspani < $yspan0 - 1e-9}]
    check_true "IX-menu-zoomin canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    $mb.view invoke [$mb.view index {Zoom Out}]
    xschem new_schematic switch $vdrw
    set spano [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspano [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-menu-zoomout x-span grows on the graph" \
      [expr {$spano > $span0 + 1e-9}]
    check_true "IX-menu-zoomout y-span grows too (both axes)" \
      [expr {$yspano > $yspan0 + 1e-9}]
    check_true "IX-menu-zoomout canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-rmb: right-drag = GRAPH x-zoom-to-box via the C engine -----------
    # Drive wviewer::btn3_filter (the forwarder S3 sabotages) with a synthetic
    # ButtonPress then ButtonRelease at two body x pixels (30% / 70% of width,
    # mid-height): well inside the plot body (horizontally 14%..95%, vertically
    # 14%..86% of the full-window graph rect), so graph_left/graph_top are 0 and
    # the C GRAPHPAN x-zoom-to-box path fires (callback.c:1000/:1454). The box
    # narrows the graph rect x-range; the canvas stays pinned. The rect-x state
    # change also proves btn3_filter forwarded (S3's unconditional swallow leaves
    # it unchanged).
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set rx1_0 [xschem getprop rect 2 0 x1]
    set rx2_0 [xschem getprop rect 2 0 x2]
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set px1 [expr {int(0.30 * $W)}]
    set px2 [expr {int(0.70 * $W)}]
    set py  [expr {int(0.50 * $H)}]
    wviewer::btn3_filter $vdrw 4 $px1 $py 3 0        ;# ButtonPress   -> GRAPHPAN
    wviewer::btn3_filter $vdrw 5 $px2 $py 3 0        ;# ButtonRelease -> zoom box
    xschem new_schematic switch $vdrw
    set rx1_1 [xschem getprop rect 2 0 x1]
    set rx2_1 [xschem getprop rect 2 0 x2]
    check_true "IX-rmb graph x1 narrowed inward (x1 grew)" \
      [expr {$rx1_1 > $rx1_0 + 1e-9}]
    check_true "IX-rmb graph x2 narrowed inward (x2 shrank)" \
      [expr {$rx2_1 < $rx2_0 - 1e-9}]
    check_true "IX-rmb graph x-span narrowed toward the box" \
      [expr {($rx2_1 - $rx1_1) < ($rx2_0 - $rx1_0) - 1e-9}]
    check_true "IX-rmb canvas == baseline (graph zoom, not canvas)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-zoom-strips (issue 0144): Ctrl+wheel zooms X on EVERY strip but Y
    # ONLY on the strip under the cursor. Drives the synchronous write seam
    # wviewer::wheel_zoom with an EXPLICIT target index (the gesture path's own
    # pointer resolution, graph_at_pointer, is covered by the single-graph legs
    # above — a 2-strip pointer position is not reproducible headlessly).
    # Restores ONE strip at the end so IX-fit below still sees the 1-graph
    # layout. -----------------------------------------------------------------
    wviewer::add_graph $tok                                  ;# now 2 strips
    set gs2 [dict get [wviewer::layout_for $tok] graphs]
    set sg0 [dict replace [lindex $gs2 0] x1 0 x2 10 y1 -1 y2 1]
    set sg1 [dict replace [lindex $gs2 1] x1 0 x2 10 y1 -2 y2 2]
    wviewer::set_graphs $tok [list $sg0 $sg1]
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    set ax0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ay0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set bx0 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set by0 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    check_true "IX-zoom-strips setup: 2 strips with concrete x+y ranges" \
      [expr {$ax0 > 0 && $ay0 > 0 && $bx0 > 0 && $by0 > 0}]
    wviewer::wheel_zoom $tok up 1                            ;# cursor on strip 1
    xschem new_schematic switch $vdrw
    set ax1 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ay1 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set bx1 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set by1 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    check_true "IX-zoom-strips pointed strip 1 zooms X" [expr {$bx1 < $bx0 - 1e-9}]
    check_true "IX-zoom-strips pointed strip 1 zooms Y" [expr {$by1 < $by0 - 1e-9}]
    check_true "IX-zoom-strips other strip 0 MATCHES the X zoom" \
      [expr {abs($ax1 - $bx1) < 1e-9 && $ax1 < $ax0 - 1e-9}]
    check_true "IX-zoom-strips other strip 0 keeps its Y (X-only)" \
      [expr {abs($ay1 - $ay0) < 1e-9}]
    check_true "IX-zoom-strips canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # same contract through graph_zoom — the View-menu / Z / Ctrl-z path (issue
    # 0145) — here with an EXPLICIT target strip 0 and the opposite direction
    wviewer::set_graphs $tok [list $sg0 $sg1]
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    set mx0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set my0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set nx0 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set ny0 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    wviewer::graph_zoom $tok out 0                           ;# target strip 0
    xschem new_schematic switch $vdrw
    set mx1 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set my1 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set nx1 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set ny1 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    check_true "IX-zoom-strips graph_zoom target strip 0 zooms X out" \
      [expr {$mx1 > $mx0 + 1e-9}]
    check_true "IX-zoom-strips graph_zoom target strip 0 zooms Y out" \
      [expr {$my1 > $my0 + 1e-9}]
    check_true "IX-zoom-strips graph_zoom other strip 1 MATCHES the X zoom" \
      [expr {abs($nx1 - $mx1) < 1e-9 && $nx1 > $nx0 + 1e-9}]
    check_true "IX-zoom-strips graph_zoom other strip 1 keeps its Y (X-only)" \
      [expr {abs($ny1 - $ny0) < 1e-9}]

    wviewer::set_graphs $tok [list $sg0]                     ;# back to 1 strip
    wviewer::regenerate $tok

    # === CG (issue 0149): the graphs OWN the viewer window ====================
    # No gesture in the viewer may scroll/pan the CANVAS — that slides the tiled
    # graph stack around a bigger canvas and exposes blank space. Teeth for both
    # reported holes: the arrow keys (bare = graph pan, modified = swallowed;
    # previously forwarded and reaching view.scroll_* / the hard-coded origin pan
    # / prev_tab-next_tab) and the middle button (the C canvas PAN gesture, which
    # waves_selected explicitly refuses to graph-route). Every leg re-asserts the
    # canvas baseline.

    # CG-arrow-right / -left: bare Left/Right pan the graph X, through the
    # PRODUCTION key_filter (KeyPress, T==2), not a helper shortcut.
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ax1 [xschem getprop rect 2 0 x1]; set ax2 [xschem getprop rect 2 0 x2]
    set ay1 [xschem getprop rect 2 0 y1]; set ay2 [xschem getprop rect 2 0 y2]
    wviewer::key_filter $vdrw 2 10 10 65363 Right 0
    xschem new_schematic switch $vdrw
    set dx1 [expr {[xschem getprop rect 2 0 x1] - $ax1}]
    set dx2 [expr {[xschem getprop rect 2 0 x2] - $ax2}]
    check_true "CG-arrow-right pans graph x by one positive delta" \
      [expr {abs($dx1 - $dx2) < 1e-9 && $dx1 > 1e-9}]
    check_true "CG-arrow-right leaves y alone" \
      [expr {[xschem getprop rect 2 0 y1] == $ay1 &&
             [xschem getprop rect 2 0 y2] == $ay2}]
    check_true "CG-arrow-right canvas == baseline (no canvas scroll)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ax1 [xschem getprop rect 2 0 x1]; set ax2 [xschem getprop rect 2 0 x2]
    wviewer::key_filter $vdrw 2 10 10 65361 Left 0
    xschem new_schematic switch $vdrw
    set dx1 [expr {[xschem getprop rect 2 0 x1] - $ax1}]
    set dx2 [expr {[xschem getprop rect 2 0 x2] - $ax2}]
    check_true "CG-arrow-left pans graph x by one negative delta" \
      [expr {abs($dx1 - $dx2) < 1e-9 && $dx1 < -1e-9}]
    check_true "CG-arrow-left canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # CG-arrow-up / -down: bare Up/Down pan the graph Y
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ay1 [xschem getprop rect 2 0 y1]; set ay2 [xschem getprop rect 2 0 y2]
    set ax1 [xschem getprop rect 2 0 x1]; set ax2 [xschem getprop rect 2 0 x2]
    wviewer::key_filter $vdrw 2 10 10 65362 Up 0
    xschem new_schematic switch $vdrw
    set dy1 [expr {[xschem getprop rect 2 0 y1] - $ay1}]
    set dy2 [expr {[xschem getprop rect 2 0 y2] - $ay2}]
    check_true "CG-arrow-up pans graph y by one positive delta" \
      [expr {abs($dy1 - $dy2) < 1e-9 && $dy1 > 1e-9}]
    check_true "CG-arrow-up leaves x alone" \
      [expr {[xschem getprop rect 2 0 x1] == $ax1 &&
             [xschem getprop rect 2 0 x2] == $ax2}]
    check_true "CG-arrow-up canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ay1 [xschem getprop rect 2 0 y1]; set ay2 [xschem getprop rect 2 0 y2]
    wviewer::key_filter $vdrw 2 10 10 65364 Down 0
    xschem new_schematic switch $vdrw
    set dy1 [expr {[xschem getprop rect 2 0 y1] - $ay1}]
    set dy2 [expr {[xschem getprop rect 2 0 y2] - $ay2}]
    check_true "CG-arrow-down pans graph y by one negative delta" \
      [expr {abs($dy1 - $dy2) < 1e-9 && $dy1 < -1e-9}]
    check_true "CG-arrow-down canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # CG-arrow-mod: Shift(1) / Ctrl(4) / Alt(8) + arrow are SWALLOWED — neither
    # the graph NOR the canvas may move. Ctrl+Left/Right used to switch TABS and
    # Alt+arrow used to pan the canvas origin outright.
    foreach {mname mask} {shift 1 ctrl 4 alt 8} {
      ix_setrange $tok 0 10 -1 1
      xschem new_schematic switch $vdrw
      set bx1 [xschem getprop rect 2 0 x1]; set bx2 [xschem getprop rect 2 0 x2]
      set by1 [xschem getprop rect 2 0 y1]; set by2 [xschem getprop rect 2 0 y2]
      foreach ks {65361 65362 65363 65364} {
        wviewer::key_filter $vdrw 2 10 10 $ks Arrow $mask
      }
      xschem new_schematic switch $vdrw
      check_true "CG-arrow-$mname graph range unchanged (swallowed)" \
        [expr {[xschem getprop rect 2 0 x1] == $bx1 &&
               [xschem getprop rect 2 0 x2] == $bx2 &&
               [xschem getprop rect 2 0 y1] == $by1 &&
               [xschem getprop rect 2 0 y2] == $by2}]
      check_true "CG-arrow-$mname canvas == baseline" \
        [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
    }

    # === CG-panx (issue 0150): X pans the WHOLE stack, Y stays per-strip ======
    # Two strips, SAME x range, DIFFERENT y ranges. Shift+wheel (and the Left/
    # Right arrows, which delegate to it) used to pan x on the pointed strip
    # only, sliding one strip out of time-alignment with the rest. Y must stay
    # independent: a vertical pan moves exactly ONE strip's y.
    wviewer::add_graph $tok                                  ;# 2 strips again
    proc cg_setpair {tok} {
      set gs [dict get [wviewer::layout_for $tok] graphs]
      set a [dict replace [lindex $gs 0] x1 0 x2 10 y1 -1 y2 1]
      set b [dict replace [lindex $gs 1] x1 0 x2 10 y1 -2 y2 2]
      wviewer::set_graphs $tok [list $a $b]
      wviewer::regenerate $tok
    }
    proc cg_ranges {vdrw gi} {
      xschem new_schematic switch $vdrw
      list [xschem getprop rect 2 $gi x1] [xschem getprop rect 2 $gi x2] \
           [xschem getprop rect 2 $gi y1] [xschem getprop rect 2 $gi y2]
    }
    cg_setpair $tok
    lassign [cg_ranges $vdrw 0] p0x1 p0x2 p0y1 p0y2
    lassign [cg_ranges $vdrw 1] p1x1 p1x2 p1y1 p1y2
    check_true "CG-panx setup: 2 strips, same x, different y" \
      [expr {$p0x1 == $p1x1 && $p0x2 == $p1x2 && $p0y2 != $p1y2}]
    wviewer::wheel $tok $vdrw up shift
    lassign [cg_ranges $vdrw 0] q0x1 q0x2 q0y1 q0y2
    lassign [cg_ranges $vdrw 1] q1x1 q1x2 q1y1 q1y2
    check_true "CG-panx shift+wheel moved strip 0 x by a positive delta" \
      [expr {($q0x1 - $p0x1) > 1e-9 && abs(($q0x1 - $p0x1) - ($q0x2 - $p0x2)) < 1e-9}]
    check_true "CG-panx strip 1 moved by the SAME x delta (stack stays aligned)" \
      [expr {abs(($q1x1 - $p1x1) - ($q0x1 - $p0x1)) < 1e-9 &&
             abs(($q1x2 - $p1x2) - ($q0x2 - $p0x2)) < 1e-9}]
    check_true "CG-panx both strips still share one x window" \
      [expr {abs($q0x1 - $q1x1) < 1e-9 && abs($q0x2 - $q1x2) < 1e-9}]
    check_true "CG-panx y untouched on BOTH strips" \
      [expr {$q0y1 == $p0y1 && $q0y2 == $p0y2 &&
             $q1y1 == $p1y1 && $q1y2 == $p1y2}]
    check_true "CG-panx canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # the Left/Right arrows go through the same seam (production key_filter)
    cg_setpair $tok
    lassign [cg_ranges $vdrw 0] p0x1 p0x2 p0y1 p0y2
    lassign [cg_ranges $vdrw 1] p1x1 p1x2 p1y1 p1y2
    wviewer::key_filter $vdrw 2 10 10 65361 Left 0
    lassign [cg_ranges $vdrw 0] q0x1 q0x2 q0y1 q0y2
    lassign [cg_ranges $vdrw 1] q1x1 q1x2 q1y1 q1y2
    check_true "CG-panx Left arrow moved strip 0 x negative" \
      [expr {($q0x1 - $p0x1) < -1e-9}]
    check_true "CG-panx Left arrow moved strip 1 by the SAME delta" \
      [expr {abs(($q1x1 - $p1x1) - ($q0x1 - $p0x1)) < 1e-9 &&
             abs(($q1x2 - $p1x2) - ($q0x2 - $p0x2)) < 1e-9}]

    # Y independence: a vertical pan moves exactly ONE strip's y (whichever the
    # pointer resolves to — the count is what matters), and no strip's x.
    cg_setpair $tok
    lassign [cg_ranges $vdrw 0] p0x1 p0x2 p0y1 p0y2
    lassign [cg_ranges $vdrw 1] p1x1 p1x2 p1y1 p1y2
    wviewer::wheel $tok $vdrw up 0
    lassign [cg_ranges $vdrw 0] q0x1 q0x2 q0y1 q0y2
    lassign [cg_ranges $vdrw 1] q1x1 q1x2 q1y1 q1y2
    set moved 0
    if {$q0y1 != $p0y1 || $q0y2 != $p0y2} { incr moved }
    if {$q1y1 != $p1y1 || $q1y2 != $p1y2} { incr moved }
    check "CG-panx vertical pan moved exactly ONE strip's y" $moved 1
    check_true "CG-panx vertical pan left every x alone" \
      [expr {$q0x1 == $p0x1 && $q0x2 == $p0x2 &&
             $q1x1 == $p1x1 && $q1x2 == $p1x2}]
    check_true "CG-panx vertical pan canvas == baseline" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    rename cg_setpair {}
    rename cg_ranges {}
    set gs1 [dict get [wviewer::layout_for $tok] graphs]
    wviewer::set_graphs $tok [list [lindex $gs1 0]]           ;# back to 1 strip
    wviewer::regenerate $tok

    # CG-binds: the canvas-only mouse gestures are bound to a swallow on THIS
    # canvas (per-widget; other windows keep theirs). Button-2 LEFT this set when
    # the graph pan moved off LMB (strip drag-reorder): it is now forwarded
    # through btn2_filter, which is what CG-mmb2 below exercises. What must still
    # hold for MMB is the OUTCOME, not the swallow — the canvas never moves.
    foreach seq {<Shift-ButtonPress-1> <Shift-ButtonRelease-1> <Shift-B1-Motion>
                 <Alt-ButtonPress-1> <Alt-ButtonRelease-1> <Alt-B1-Motion>} {
      check "CG-binds $seq swallowed" [string trim [bind $vdrw $seq]] break
    }
    foreach seq {<ButtonPress-2> <ButtonRelease-2> <B2-Motion>} {
      check_true "CG-binds $seq routed through btn2_filter" \
        [string match {*wviewer::btn2_filter*} [bind $vdrw $seq]]
    }

    # CG-mmb: a full synthetic MIDDLE-button press -> drag -> release. It must
    # never move the CANVAS: pre-0149 the press reached handle_button_press ->
    # start_pan_logged and the Button2Mask motion panned the canvas origin. It is
    # now the GRAPH pan instead (btn2_filter forwards it, callback.c pans data
    # ranges), so the canvas stays pinned for the opposite reason — assert the
    # canvas invariant here, the data-range effect in CG-mmb2. 0x200 = Button2Mask.
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set mpx1 [expr {int(0.30 * $W)}]; set mpx2 [expr {int(0.70 * $W)}]
    set mpy  [expr {int(0.50 * $H)}]
    event generate $vdrw <ButtonPress-2>   -x $mpx1 -y $mpy
    event generate $vdrw <Motion>          -x $mpx2 -y $mpy -state 0x200
    event generate $vdrw <ButtonRelease-2> -x $mpx2 -y $mpy -state 0x200
    update
    check_true "CG-mmb middle-drag left the canvas at baseline (no pan)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # CG-shift-b1: Shift+drag is the schematic rubber-band/copy gesture and
    # Alt+B1 the unselect-at-pointer click — both canvas-only (waves_selected
    # refuses to graph-route them). The swallow itself is witnessed by the
    # CG-binds checks above; here we only assert the gesture is inert and, in
    # particular, cannot move the canvas. (A selection witness would be HOLLOW:
    # neither a shift rubber-band nor a shift-click inside the full-window graph
    # rect selects it — probe-verified with the binds sabotaged, lastsel stayed
    # 0 — so `lastsel == 0` would pass with the fix reverted.)
    catch {xschem unselect_all}
    event generate $vdrw <Shift-ButtonPress-1>   -x $mpx1 -y $mpy -state 1
    event generate $vdrw <Motion>                -x $mpx2 -y $mpy -state 0x101
    event generate $vdrw <Shift-ButtonRelease-1> -x $mpx2 -y $mpy -state 0x101
    event generate $vdrw <Alt-ButtonPress-1>     -x $mpx1 -y $mpy -state 8
    event generate $vdrw <Alt-ButtonRelease-1>   -x $mpx1 -y $mpy -state 0x108
    update
    xschem new_schematic switch $vdrw
    check_true "CG-shift-b1 canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # === WB (issue 0152): wave bold is an LMB CLICK, never an RMB press ======
    # Reported: RMB near a plotted trace makes it thick, and the RMB press-drag
    # box-zoom (issue 0142) does it too. The bold is the `hilight_wave` prop
    # token (draw.c setup_graph_data / draw_graph); it used to be toggled on
    # Button3 PRESS in waves_callback, so every RMB gesture bolted whatever
    # trace was nearest the press point. It is now the RELEASE of a Button1
    # press that did not travel.
    #
    # Needs REAL data: find_closest_wave() bails on a NULL xctx->raw, so with no
    # raw every click would write hilight_wave=-1 and nothing is witnessable
    # (the green-but-hollow trap). Full Tk event sequences through the
    # PRODUCTION bindings (<ButtonPress-1> forward, kept generic <ButtonRelease>,
    # btn3_filter), never a lone synthetic callback.
    if {$have_raw} {
      xschem new_schematic switch $vdrw
      check "WB raw read into the IX viewer ctx" [rawq {xschem raw read $rawpath dc}] 1
      check "WB add one trace to strip 0" [wviewer::add_trace $tok 0 {i(v1)}] {}
      wviewer::fit $tok                 ;# data inside the plot box -> wcnt >= 0
      proc wb_bold {vdrw} {
        xschem new_schematic switch $vdrw
        set v [xschem getprop rect 2 0 hilight_wave]
        if {$v eq {}} { return -1 }
        return $v
      }
      # the viewer buffer is readonly, so the reset goes through with_edit like
      # every other viewer mutation (landmine 17)
      proc wb_reset {tok} {
        wviewer::with_edit $tok {xschem setprop rect 2 0 hilight_wave -1}
      }
      # Every synthetic event carries an explicitly INCREASING %t. Without it Tk
      # collapses two identical presses that fall inside its double-click window
      # into <Double-Button-N>, which the viewer binds to {break} -- the second
      # press then vanishes entirely (probe-verified: no `xschem callback` at all,
      # and the leg failed for a reason that had nothing to do with the code under
      # test). Explicit times make the pairing independent of the wall clock.
      set ::wbt 100000
      proc wb_ev {w seq args} {
        set ::wbt [expr {$::wbt + 1000}]
        eval [list event generate $w $seq -time $::wbt] $args
      }
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      set bpx  [expr {int(0.50 * $W)}]      ;# well inside the plot body
      set bpx2 [expr {int(0.70 * $W)}]      ;# a drag away from it
      set bpy  [expr {int(0.50 * $H)}]

      # issue 0174: the pick is a real SCREEN-PIXEL distance to the trace
      # (GRAPH_TRACE_PICK_TOL, 10), so the click pixel can no longer be a fixed
      # fraction of the widget. Scan for one the ENGINE agrees is on the trace,
      # and one inside the PLOT BOX that is far from every trace. Both scanned
      # rather than assumed: the strip geometry follows the WM's window size,
      # and a hard-coded fraction is exactly what let the pre-0174 WB-click leg
      # pass against a pick with no threshold at all — measured, (0.50W, 0.50H)
      # on this fixture sits about 0.30*H away from the only trace.
      # plotbox_at keeps the far pixel out of the legend/label margin, which is
      # Button3's territory (WB-legend below).
      proc wb_at {vdrw gi px py {tol 10}} {
        xschem new_schematic switch $vdrw
        set r -1
        catch {set r [xschem get graph_trace_at $gi $px $py $tol]}
        if {![string is integer -strict $r]} { return -1 }
        return $r
      }
      # ⚠ RESCAN, do not reuse: the legs between here and the end of the WB block
      # ZOOM (WB-rmb-drag) and PAN (WB-mmb-drag) the graph, so a row that was
      # trace-free when the block started can have a trace on it later. A stale
      # "far" pixel silently becomes an ON-trace pixel and the leg using it
      # asserts the opposite of what it means to.
      proc wb_far_row {vdrw gi px H} {
        for {set y 2} {$y < $H} {incr y 1} {
          if {![wviewer::plotbox_at $vdrw $gi $px $y]} { continue }
          if {[wb_at $vdrw $gi $px $y] >= 0} { continue }
          if {[wb_at $vdrw $gi $px $y 1e30] >= 0} { return $y }
        }
        return {}
      }
      set wbony {}       ;# a row ON the trace
      set wboffy {}      ;# a row inside the box but > 10 px from every trace
      for {set y 2} {$y < $H} {incr y 1} {
        if {![wviewer::plotbox_at $vdrw 0 $bpx $y]} { continue }
        if {[wb_at $vdrw 0 $bpx $y] >= 0} {
          if {$wbony eq {}} { set wbony $y }
        } elseif {$wboffy eq {} && [wb_at $vdrw 0 $bpx $y 1e30] >= 0} {
          set wboffy $y
        }
      }
      check_true "WB-precise a pixel ON the trace was found" [expr {$wbony ne {}}]
      check_true "WB-precise a plot-box pixel FAR from every trace was found" \
        [expr {$wboffy ne {}}]
      if {$wbony eq {}} { set wbony $bpy }
      if {$wboffy eq {}} { set wboffy $bpy }

      wb_reset $tok
      check "WB-setup nothing bold to start" [wb_bold $vdrw] -1

      # WB-click: press+release at the SAME pixel, ON the trace, bolds it; a
      # second click on the SAME trace leaves it bold (D3, settled at review:
      # a plain click never deselects what it lands on — Cadence behaviour, and
      # de-selecting one trace becomes 0175's Ctrl+click).
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbony
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbony -state 0x100
      update
      check "WB-click LMB click ON a trace bolds it (trace 0)" [wb_bold $vdrw] 0
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbony
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbony -state 0x100
      update
      check "WB-click a second click on the same trace KEEPS it bold" [wb_bold $vdrw] 0
      check_true "WB-click canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
      wb_reset $tok

      # WB-precise (issue 0174): THE leg that fails on the pre-fix code. A click
      # inside the plot body but more than the pick tolerance from every trace
      # must select NOTHING — the old pick had no threshold and bolted the
      # nearest trace however far away, so "in the vicinity of a trace" was
      # really "anywhere in the plot body".
      # Teeth: the same pixel with an enormous tolerance DOES find a trace, so
      # -1 at the shipping tolerance means "far", not "this strip has no data".
      check_true "WB-precise the far pixel is FAR, not data-less (huge tol hits)" \
        [expr {[wb_at $vdrw 0 $bpx $wboffy 1e30] >= 0}]
      check "WB-precise ... and the shipping tolerance calls it empty" \
        [wb_at $vdrw 0 $bpx $wboffy] -1
      wb_reset $tok
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wboffy
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wboffy -state 0x100
      update
      check "WB-precise a click far from every trace bolds NOTHING" [wb_bold $vdrw] -1
      # ... and it CLEARS an existing selection (D2, settled at review). It does
      # not collide with the strip drag-reorder that also owns empty body space:
      # the two are separated by the TRAVEL test, not by this arm — a real
      # reorder drag travels well past GRAPH_CLICK_TOL and its release never
      # reaches the arm at all. WB-lmb-drag below is that half.
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbony
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbony -state 0x100
      update
      check "WB-precise a trace is bold before the far click" [wb_bold $vdrw] 0
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wboffy
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wboffy -state 0x100
      update
      check "WB-precise a far click CLEARS the selection" [wb_bold $vdrw] -1
      wb_reset $tok

      # WB-rmb-click: THE reported defect, minimal form. An RMB press+release in
      # the plot body must leave the bold alone (it is box-zoom only now).
      # RED pre-fix: the press toggled it to 0.
      wb_reset $tok
      wb_ev $vdrw <ButtonPress-3>   -x $bpx -y $bpy
      wb_ev $vdrw <ButtonRelease-3> -x $bpx -y $bpy -state 0x400
      update
      check "WB-rmb-click RMB click leaves the bold alone" [wb_bold $vdrw] -1

      # WB-rmb-drag: the reported defect in its real form — an RMB press-drag
      # box-zoom must not bold. Asserts the zoom STILL happened, so this cannot
      # pass by the gesture silently dying. RED pre-fix.
      wb_reset $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      set wbx1 [xschem getprop rect 2 0 x1]
      set wbx2 [xschem getprop rect 2 0 x2]
      wb_ev $vdrw <ButtonPress-3>   -x [expr {int(0.30 * $W)}] -y $bpy
      wb_ev $vdrw <ButtonRelease-3> -x [expr {int(0.70 * $W)}] -y $bpy -state 0x400
      update
      check "WB-rmb-drag box-zoom leaves the bold alone" [wb_bold $vdrw] -1
      xschem new_schematic switch $vdrw
      check_true "WB-rmb-drag really did zoom (x-span narrowed)" \
        [expr {([xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]) <
               ($wbx2 - $wbx1) - 1e-9}]

      # WB-lmb-drag: the SAME hazard on the new trigger — a Button1 drag must not
      # have its release read as a click. The teeth for using dedicated
      # graph_press_x/y instead of mx/my_double_save (which the pan re-seeded on
      # every motion step, waves_callback save_mouse_at_end).
      # CONTRACT CHANGE (strip drag-reorder): LMB no longer pans the graph — the
      # pan moved to MMB so LMB can own precise interaction and strip reordering.
      # So this leg now asserts the pan did NOT happen, and WB-mmb-drag below
      # asserts that MMB does it instead. Both together are the teeth: without the
      # second one "no pan" would also pass with the gesture silently dead.
      wb_reset $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      set wbp1 [xschem getprop rect 2 0 x1]
      wb_ev $vdrw <ButtonPress-1> -x $bpx -y $bpy
      foreach fx {0.55 0.60 0.65 0.70} {
        wb_ev $vdrw <Motion> -x [expr {int($fx * $W)}] -y $bpy -state 0x100
      }
      wb_ev $vdrw <ButtonRelease-1> -x $bpx2 -y $bpy -state 0x100
      update
      check "WB-lmb-drag LMB drag does NOT bold" [wb_bold $vdrw] -1
      xschem new_schematic switch $vdrw
      check_true "WB-lmb-drag LMB no longer pans the graph range" \
        [expr {abs([xschem getprop rect 2 0 x1] - $wbp1) <= 1e-12}]
      check_true "WB-lmb-drag canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

      # WB-mmb-drag: the pan, on its new button. A plain MMB press-drag-release
      # inside the strip must move the graph's x range and leave the CANVAS put
      # (the issue-0149 invariant: no gesture in this window scrolls the canvas).
      wb_reset $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      set wbp2 [xschem getprop rect 2 0 x1]
      wb_ev $vdrw <ButtonPress-2> -x $bpx -y $bpy
      foreach fx {0.55 0.60 0.65 0.70} {
        wb_ev $vdrw <B2-Motion> -x [expr {int($fx * $W)}] -y $bpy -state 0x200
      }
      wb_ev $vdrw <ButtonRelease-2> -x $bpx2 -y $bpy -state 0x200
      update
      xschem new_schematic switch $vdrw
      check_true "WB-mmb-drag MMB really pans the graph range (x1 moved)" \
        [expr {abs([xschem getprop rect 2 0 x1] - $wbp2) > 1e-12}]
      check_true "WB-mmb-drag canvas == baseline (graph pan, not canvas pan)" \
        [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
      check "WB-mmb-drag MMB drag does not bold" [wb_bold $vdrw] -1

      # WB-legend: what the two buttons do on a legend entry.
      # ⚠ ISSUE 0175 CHANGED THE LMB HALF. The last leg of this block used to
      # assert that an LMB click on the legend does NOTHING ("body-only"); a
      # legend click now SELECTS that trace, which is the feature 0175 was asked
      # for, so the leg asserts the new answer. The 0152 `WB-legend` row is
      # superseded accordingly.
      # ⚠ ISSUE 0178 CHANGED THE RMB HALF, and these two legs asserted the exact
      # behaviour that was REPORTED AS WRONG at the 0177 eyeball: "RMB click on
      # legend name is selecting a trace and RMB click legend of selected trace
      # is deselecting it". Button3 outside the plot body still reaches
      # edit_wave_attributes(2,...) in the C engine — that is how graphs EMBEDDED
      # IN A SCHEMATIC still work — but the ASE viewer no longer forwards such a
      # press: wviewer::btn3_filter swallows it and posts the TRACE CONTEXT MENU
      # on the release instead, so RMB means "context menu" everywhere on this
      # canvas. Selection on the legend is LMB's and Ctrl+LMB's alone.
      # These legs now assert the NEW contract; the menu side of it is covered in
      # test_wave_trace_menu.tcl TR1-TR5, which is where that feature lives.
      wb_reset $tok
      set wbly [expr {int(0.03 * $H)}]      ;# above the plot box (14% top margin)
      wb_ev $vdrw <ButtonPress-3>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-3> -x $bpx -y $wbly -state 0x400
      update
      catch {wviewer::trace_menu_unpost $tok} ; update
      check "WB-legend RMB on the legend does NOT bold (0178)" [wb_bold $vdrw] -1
      # ...and it does not toggle one that IS bold, either: select with LMB (the
      # button that owns selection now), then RMB the same entry twice.
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbly -state 0x100
      update
      check "WB-legend (control) LMB DOES bold it, so the pixel is a legend entry" \
        [wb_bold $vdrw] 0
      foreach _wbi {1 2} {
        wb_ev $vdrw <ButtonPress-3>   -x $bpx -y $wbly
        wb_ev $vdrw <ButtonRelease-3> -x $bpx -y $wbly -state 0x400
        update
        catch {wviewer::trace_menu_unpost $tok} ; update
      }
      check "WB-legend two legend RMBs leave the selection alone (0178)" \
        [wb_bold $vdrw] 0
      wb_reset $tok
      # issue 0175: an LMB click on a legend entry SELECTS that trace. Teeth: the
      # pixel is the same one the RMB legs above just proved is a legend entry, so
      # a leg that passed because "nothing is there" is not available.
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbly -state 0x100
      update
      check "WB-legend LMB on the legend SELECTS that trace (0175)" [wb_bold $vdrw] 0
      # ... and it REPLACES rather than toggles, exactly like a body click (D3):
      # a second plain click on the same entry keeps it selected
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbly -state 0x100
      update
      check "WB-legend a second plain legend click KEEPS it selected" [wb_bold $vdrw] 0
      # ... while a plain click on the plot body FAR from every trace still
      # clears, so the legend arm did not swallow the body arm. The far row is
      # RE-SCANNED here: the RMB zoom and the MMB pan above have moved the data
      # since the block's opening scan.
      set wbfar2 [wb_far_row $vdrw 0 $bpx $H]
      check_true "WB-legend a far body row was re-scanned after the zoom/pan" \
        [expr {$wbfar2 ne {}}]
      if {$wbfar2 ne {}} {
        wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbfar2
        wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbfar2 -state 0x100
        update
        check "WB-legend the body arm still clears after a legend select" [wb_bold $vdrw] -1
      }

      # === SD: the LMB SEAM between the C engine and strip drag-reorder =======
      # doc/claude/specs/waveform_viewer_modes.md §12. Empty waveform space
      # belongs to strip reordering; a fixed screen-pixel band around every trace
      # — and any press that grabbed a cursor — stays with the C engine. These
      # legs need REAL data (the exclusion is answered by the engine off the raw)
      # and a two-strip stack (a reorder needs somewhere to go).
      # each strip carries an INERT identity key, so "which strip is at index k"
      # can be witnessed independently of "which trace is in strip k" — on a
      # two-strip stack a trace move and a strip reorder produce the same
      # sd_order, and only sd_ids tells them apart (the model dict is free-form;
      # regenerate/graph_props read known keys only, so `sdid` changes nothing)
      set sd_save [dict get [wviewer::layout_for $tok] graphs]
      wviewer::set_graphs $tok [list \
        [dict replace [lindex $sd_save 0] sdid A] \
        [dict replace [wviewer::empty_graph] sdid B]]
      wviewer::regenerate $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      proc sd_order {tok} {
        set out {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          set tr [dict get $G traces]
          lappend out [expr {[llength $tr] ? [dict get [lindex $tr 0] vec] : {-}}]
        }
        return $out
      }
      proc sd_ids {tok} {
        set out {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          lappend out [wviewer::dget $G sdid ?]
        }
        return $out
      }
      proc sd_near {vdrw gi px py tol} {
        xschem new_schematic switch $vdrw
        return [xschem get graph_near_wave $gi $px $py $tol]
      }
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      set sdx [expr {int(0.5 * $W)}]
      # scan strip 0's band for a pixel row that sits ON the trace
      set sdy {}
      for {set y 2} {$y < $H / 2} {incr y 2} {
        if {[sd_near $vdrw 0 $sdx $y 3]} { set sdy $y; break }
      }
      check_true "SD1 a pixel ON the trace was found in strip 0" [expr {$sdy ne {}}]
      if {$sdy ne {}} {
        # the query is a real SCREEN-PIXEL distance: a row 12 px away answers 1
        # for a 16 px tolerance and 0 for a 4 px one. That is what makes the
        # exclusion zone independent of canvas zoom and of the data ranges —
        # nothing here is derived from the strip's geometry.
        set sdfar [expr {$sdy + 12}]
        check "SD1 12 px off the trace, tol 16 -> near" [sd_near $vdrw 0 $sdx $sdfar 16] 1
        check "SD1 12 px off the trace, tol 4  -> not near" [sd_near $vdrw 0 $sdx $sdfar 4] 0
        check "SD1 a row far above the trace is empty space" \
          [sd_near $vdrw 0 $sdx 2 10] 0

        # SD2: a near-trace LMB CLICK still reaches C and bolds (the press seam
        # forwards every press verbatim, whatever it decides about arming)
        wb_reset $tok
        wb_ev $vdrw <ButtonPress-1>   -x $sdx -y $sdy
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y $sdy -state 0x100
        update
        check "SD2 near-trace LMB click still bolds (C got press+release)" \
          [wb_bold $vdrw] 0
        wb_reset $tok

        # === TD: dragging a TRACE from one strip to another ==================
        # doc/claude/specs/waveform_viewer_modes.md §13. The seam SD3 used to
        # merely RESERVE ("a near-trace press is not a reorder") now carries a
        # gesture of its own: press ON the trace, drag onto another strip,
        # release -> the trace moves there. Both witnesses are needed and they
        # are independent: sd_order says WHICH TRACE is in each strip, sd_ids
        # says WHICH STRIP is at each index. A trace move changes the first and
        # never the second; a strip reorder does the opposite. On a two-strip
        # stack sd_order alone cannot tell them apart.
        set ::td_log {}
        rename wviewer::log_action wviewer::__td_real_log
        proc wviewer::log_action {line} { lappend ::td_log $line }

        set tdids [sd_ids $tok]
        check "TD fixture: the traced strip is on top, ids A B" \
          [list [sd_order $tok] $tdids] {{i(v1) -} {A B}}
        wviewer::set_target_strip 0 $tok    ;# so the press itself logs nothing
        set ::td_log {}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        check "TD1 the press over a trace shows the GRAB HAND pointer" \
          [$vdrw cget -cursor] hand2
        check_true "TD1 the press armed a TRACE drag and NOT a strip reorder" \
          [expr {$::wviewer::tdrag_gi($tok) == 0 && $::wviewer::tdrag_ti($tok) == 0 &&
                 $::wviewer::drag_from($tok) == -1}]
        foreach fy {0.55 0.65 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        update
        xschem new_schematic switch $vdrw
        check "TD1 the destination strip is framed as the drop target" \
          [xschem getprop rect 2 1 reorder_handle] 4
        check "TD1 the source strip keeps the plain grip" \
          [xschem getprop rect 2 0 reorder_handle] 1
        check "TD1 the model is NOT mutated during the drag" \
          [sd_order $tok] {i(v1) -}
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check "TD1 the trace moved to the strip it was dropped on" \
          [sd_order $tok] {- i(v1)}
        check "TD1 the STRIPS themselves did not reorder" [sd_ids $tok] $tdids
        check "TD1 the drop-target frame is gone" \
          [list [xschem getprop rect 2 0 reorder_handle] \
                [xschem getprop rect 2 1 reorder_handle]] {1 1}
        check "TD1 the pointer is restored on release" [$vdrw cget -cursor] {}
        check "TD1 exactly ONE log line, fully resolved" \
          [list [llength $::td_log] [lindex $::td_log end]] \
          [list 1 "wviewer::move_trace 0 0 1 $tok"]
        check "TD1 the DESTINATION strip became the target" \
          [wviewer::target_strip $tok] 1
        check "TD1 no drag state survived the drop" \
          [list $::wviewer::tdrag_gi($tok) $::wviewer::tdrag_active($tok)] {-1 0}
        check "TD1 viewer buffer still readonly + unmodified" \
          [list [xschem get readonly] [xschem get modified]] {1 0}

        # TD2: the same gesture upward, which also puts the fixture back. The
        # press pixel is found by scanning the LOWER band for the trace, so this
        # leg cannot pass by accident on a stale coordinate.
        set sdy2 {}
        for {set y [expr {int(0.55 * $H)}]} {$y < $H - 2} {incr y 2} {
          if {[sd_near $vdrw 1 $sdx $y 3]} { set sdy2 $y; break }
        }
        check_true "TD2 a pixel ON the moved trace was found in the lower strip" \
          [expr {$sdy2 ne {}}]
        if {$sdy2 ne {}} {
          set ::td_log {}
          wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy2
          foreach fy {0.40 0.25 0.15} {
            wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
          }
          wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.15 * $H)}] -state 0x100
          update
          check "TD2 the trace moved back up" [sd_order $tok] {i(v1) -}
          check "TD2 the strips still did not reorder" [sd_ids $tok] $tdids
          check "TD2 one log line for the upward move" \
            [list [llength $::td_log] [lindex $::td_log end]] \
            [list 1 "wviewer::move_trace 1 0 0 $tok"]
        }

        # TD3: the trace's own attributes ride along. Written into the model
        # first (a name + a non-default color), then dragged for real.
        set tdgs [dict get [wviewer::layout_for $tok] graphs]
        set tdtr [dict replace [lindex [dict get [lindex $tdgs 0] traces] 0] \
                    name plotme color 12]
        wviewer::set_graphs $tok \
          [lreplace $tdgs 0 0 [dict replace [lindex $tdgs 0] traces [list $tdtr]]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        set ::td_log {}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        foreach fy {0.60 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        set tdland [lindex [dict get [lindex [dict get \
          [wviewer::layout_for $tok] graphs] 1] traces] 0]
        check "TD3 the moved trace dict is byte-identical" $tdland $tdtr
        xschem new_schematic switch $vdrw
        check "TD3 the destination RECT carries the alias and the color" \
          [list [string map {\" {}} [xschem getprop rect 2 1 node]] \
                [string map {\" {}} [xschem getprop rect 2 1 color]]] \
          [list "plotme;i(v1)" 12]
        # put it back and drop the decoration again
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] sdid A traces [list \
            [dict replace $tdtr name {} color 4]]] \
          [dict replace [wviewer::empty_graph] sdid B]]
        wviewer::regenerate $tok
        wviewer::fit $tok

        # TD4: a press-release that does NOT travel is still the wave-bold
        # CLICK — the gesture must not steal it (issue 0152 stays intact).
        wviewer::set_target_strip 0 $tok    ;# the press must add no target line
        set ::td_log {}
        wb_reset $tok
        wb_ev $vdrw <ButtonPress-1>   -x $sdx -y $sdy
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y $sdy -state 0x100
        update
        check "TD4 a sub-threshold click still bolds the trace" [wb_bold $vdrw] 0
        check "TD4 ... and moved nothing" [sd_order $tok] {i(v1) -}
        check "TD4 ... and logged nothing" [llength $::td_log] 0
        check "TD4 ... and restored the pointer" [$vdrw cget -cursor] {}
        wb_reset $tok

        # TD5: ESC mid-drag abandons the move and restores everything.
        set ::td_log {}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check_true "TD5 a trace drag is active before ESC" \
          [expr {$::wviewer::tdrag_active($tok) == 1}]
        # focus first: a generated KeyPress goes to the FOCUS window, and under
        # WSLg the viewer can lose focus between legs — without this the ESC leg
        # silently never reaches key_filter (the MG14 lesson)
        focus -force $vdrw
        update
        event generate $vdrw <KeyPress> -keysym Escape
        update
        check "TD5 ESC cleared the drag state" \
          [list $::wviewer::tdrag_gi($tok) $::wviewer::tdrag_to($tok) \
                $::wviewer::tdrag_active($tok)] {-1 -1 0}
        check "TD5 ESC restored the pointer" [$vdrw cget -cursor] {}
        xschem new_schematic switch $vdrw
        check "TD5 ESC cleared the drop-target frame" \
          [xschem getprop rect 2 1 reorder_handle] 1
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check "TD5 the cancelled drag moved nothing" [sd_order $tok] {i(v1) -}
        check "TD5 the cancelled drag logged nothing" [llength $::td_log] 0

        # TD6: the BOLD marker follows its trace across the strips. The engine
        # writes hilight_wave straight into the rect, so this is also the
        # capture_live_graph_state leg of the gesture.
        wb_reset $tok
        wb_ev $vdrw <ButtonPress-1>   -x $sdx -y $sdy
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y $sdy -state 0x100
        update
        check "TD6 the trace is bold before the drag" [wb_bold $vdrw] 0
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        foreach fy {0.60 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        xschem new_schematic switch $vdrw
        check "TD6 the destination strip carries the bold marker" \
          [xschem getprop rect 2 1 hilight_wave] 0
        check "TD6 the emptied source has no bold marker left" \
          [xschem getprop rect 2 0 hilight_wave] {}

        # TD7: the whole user story — drag the trace, then press `u`. The key is
        # on the WaveViewer bindtag and the undo restores the MODEL snapshot the
        # drag pushed, so this is the gesture and the history wired together
        # (MG16 drives the history through the commands, this drives it through
        # the real gesture and the real key).
        # gather the traces from WHEREVER the last leg left them (the strip they
        # sit in depends on how many undos ran) and put the fixture back
        set tdall {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          foreach tr [wviewer::dget $G traces {}] { lappend tdall $tr }
        }
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] sdid A traces $tdall] \
          [dict replace [wviewer::empty_graph] sdid B]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        wviewer::clear_history $tok
        check "TD7 fixture back: the trace is on the top strip" \
          [sd_order $tok] {i(v1) -}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        foreach fy {0.60 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check "TD7 the drag moved the trace" [sd_order $tok] {- i(v1)}
        check "TD7 the drag pushed one undo point" \
          [lindex [wviewer::history_depth $tok] 0] 1
        focus -force $vdrw
        update
        event generate $vdrw <KeyPress> -keysym u
        update
        check "TD7 `u` undid the trace drag" [sd_order $tok] {i(v1) -}
        check "TD7 the strips were never reordered by any of it" [sd_ids $tok] {A B}
        event generate $vdrw <KeyPress> -keysym U -state 1
        update
        check "TD7 Shift-u redid it" [sd_order $tok] {- i(v1)}
        event generate $vdrw <KeyPress> -keysym u
        update
        check "TD7 ... and `u` again undoes it once more" [sd_order $tok] {i(v1) -}

        # back to the SD fixture shape
        # gather the traces from WHEREVER the last leg left them (the strip they
        # sit in depends on how many undos ran) and put the fixture back
        set tdall {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          foreach tr [wviewer::dget $G traces {}] { lappend tdall $tr }
        }
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] sdid A traces $tdall] \
          [dict replace [wviewer::empty_graph] sdid B]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        rename wviewer::log_action {}
        rename wviewer::__td_real_log wviewer::log_action
        unset ::td_log
      } else {
        # loud, because everything from SD2 to TD6 lives inside this guard: a
        # broken hit-test makes SD1 fail and the rest VANISH rather than fail
        puts "SKIPPED: SD2/SD3/TD* (no pixel on the trace was found)"
      }

      # SD4: the SAME gesture from EMPTY waveform space DOES reorder. Strip 1 is
      # traceless, so every pixel in it is empty space. Without this leg SD3
      # would pass with reordering broken outright.
      set sdb [wviewer::strip_bands_px $vdrw]
      set sdm0 [expr {int(([lindex [lindex $sdb 0] 1] + [lindex [lindex $sdb 0] 3]) / 2.0)}]
      set sdm1 [expr {int(([lindex [lindex $sdb 1] 1] + [lindex [lindex $sdb 1] 3]) / 2.0)}]
      check "SD4 fixture: the data strip is on top" [sd_order $tok] {i(v1) -}
      wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdm1
      wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {$sdm0 - 3}] -state 0x100
      wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {$sdm0 - 3}] -state 0x100
      update
      check "SD4 an empty-space drag reordered the stack" [sd_order $tok] {- i(v1)}
      check "SD4 the STRIPS moved (not their traces) — the TD counterpart" \
        [sd_ids $tok] {B A}
      check_true "SD4 canvas == baseline (the drag never scrolled it)" \
        [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
      # put it back
      wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdm0
      wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {$sdm1 + 3}] -state 0x100
      wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {$sdm1 + 3}] -state 0x100
      update
      check "SD4 and back again" [sd_order $tok] {i(v1) -}
      check "SD4 ... strips back in their original order too" [sd_ids $tok] {A B}

      # SD5: a press that GRABBED A CURSOR keeps the whole drag, even though the
      # pointer is nowhere near a trace. A cursor can be parked anywhere in the
      # strip, so the trace-proximity gate alone would steal cursor dragging —
      # the press seam also asks the engine whether it just armed a cursor move
      # (`xschem get graph_flags`). Park cursor A exactly under the press pixel
      # so the grab is certain, then drag DIAGONALLY: enough vertical travel to
      # pass the reorder threshold, enough horizontal travel to move the cursor.
      set sdcx [expr {int(0.35 * $W)}]
      set sdcy [expr {int(0.10 * $H)}]        ;# high in strip 0, off the trace
      check "SD5 the press pixel is empty space as far as traces go" \
        [sd_near $vdrw 0 $sdcx $sdcy 10] 0
      xschem new_schematic switch $vdrw
      set sdc [xschem graph_coord 0 $sdcx $sdcy]
      if {[llength $sdc] == 2} {
        set ::wviewer::cva($tok) 1
        wviewer::cursor_toggle $tok 1
        xschem new_schematic switch $vdrw
        xschem set cursor1_x [lindex $sdc 0]
        xschem redraw
        set sdc0 [xschem get cursor1_x]
        set sdorder [sd_order $tok]
        wb_ev $vdrw <ButtonPress-1> -x $sdcx -y $sdcy
        foreach f {0.2 0.3 0.4} {
          wb_ev $vdrw <B1-Motion> -x [expr {int(($sdcx + $f * $W))}] \
            -y [expr {int($sdcy + $f * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x [expr {int($sdcx + 0.4 * $W)}] \
          -y [expr {int($sdcy + 0.4 * $H)}] -state 0x100
        update
        xschem new_schematic switch $vdrw
        check_true "SD5 the cursor drag moved cursor A" \
          [expr {abs([xschem get cursor1_x] - $sdc0) > 1e-15}]
        check "SD5 a cursor drag never reorders the stack" [sd_order $tok] $sdorder
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
      } else {
        puts "SKIPPED: SD5 (graph_coord unavailable)"
      }

      rename sd_order {}
      rename sd_ids {}
      rename sd_near {}
      wviewer::set_graphs $tok $sd_save
      wviewer::regenerate $tok

      rename wb_bold {}
      rename wb_reset {}
      rename wb_ev {}
      rename wb_at {}
      unset ::wbt
      # leave strip 0 trace-free again so IX-fit sees the same shape as before
      set wbgs [dict get [wviewer::layout_for $tok] graphs]
      wviewer::set_graphs $tok \
        [lreplace $wbgs 0 0 [dict replace [lindex $wbgs 0] traces {}]]
      wviewer::regenerate $tok
    } else {
      puts "SKIPPED: WB wave-bold legs (no raw artifact)"
    }

    # --- IX-fit: Fit reframes the GRAPH data range, never the canvas ---------
    # PRIMARY teeth (the removed zoom_full): perturb the data range, Fit, and the
    # CANVAS must be unchanged. Holds with or without a raw loaded. Runs LAST
    # among the IX legs: the S2 sabotage (re-inserting `xschem zoom_full`) moves
    # the canvas, and running Fit last keeps that drift from leaking a canvas ==
    # baseline failure into a later leg — the real code never moves the canvas,
    # so the single baseline still holds for every leg above.
    ix_setrange $tok 0 10 -1 1
    ix_setrange $tok 0.5 1.0 -1 1
    xschem new_schematic switch $vdrw
    check_true "IX-fit perturbed data range (x1==0.5)" \
      [expr {[xschem getprop rect 2 0 x1] == 0.5}]
    wviewer::fit $tok
    check_true "IX-fit canvas == baseline (no zoom_full reframe)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    rename ix_setrange {}
    rename ix_canvas_ok {}
    wviewer::close $tok
    update
  }

  # the strip filter must never throw: a filter error swallows keys by
  # ACCIDENT and every strip assertion above turns hollow (found live: the
  # instrumentation itself once induced exactly this)
  check "G* key_filter ran error-free" $::kf_errs 0

  # restore the instrumented procs + drop the user-rc probe binds
  rename ::wviewer::key_filter {}
  rename ::wviewer::key_filter_orig ::wviewer::key_filter
  rename ::tk_messageBox {}
  rename ::wvtest_real_messageBox ::tk_messageBox
  bind .drw <Key-i> {}
  bind .drw <Alt-KeyPress> {}
} else {
  puts "SKIPPED: G1-G9 GUI legs (no usable DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
