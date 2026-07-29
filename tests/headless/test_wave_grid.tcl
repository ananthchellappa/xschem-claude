# tests/headless/test_wave_grid.tcl — ASE Waveform Viewer graph-grid density
# (viewer plan item 2, decision D-B; contract in
# doc/claude/specs/waveform_viewer.md)
#
# The feature: the graph grid inside each viewer strip keeps every line and
# every colour, but half its pixels are lit — the dash DUTY CYCLE goes from
# 2-on/2-off to 1-on/3-off. Driven by `wviewer_grid_dash_off` (default 3) ->
# the per-rect prop token `griddash`, so schematics with embedded graphs are
# untouched.
#
# ⚠ WHAT THIS SUITE CANNOT SEE, stated rather than hidden: the PIXELS. There is
# no C->Tcl getter for a Graph_ctx field and no way to read back an X GC's dash
# list, so "the grid looks lighter" is EYEBALL-ONLY. Asserted here is everything
# up to the renderer's door — the clamp, the token, that it reaches the rects
# and survives a round trip, and the blast radius.
#
# The OTHER half of item 2's risk is the drawline refactor it needed: getting a
# 1-on/3-off pattern requires a two-element dash list, and `drawline` took a
# single `dash` int. It was split into a `drawline_duty` core plus a `drawline`
# wrapper passing (dash, dash). X11 treats a 1-element list {d} and a 2-element
# {d,d} identically, so every one of the ~86 existing call sites is unchanged —
# GD3 pins the wrapper's shape, and the rest of the wave suites staying green is
# the behavioural evidence.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_grid.tcl

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
proc tokof {props tok} {
  foreach line [split $props "\n"] {
    if {[regexp "^$tok=(.*)\$" $line -> v]} { return $v }
  }
  return {}
}
# non-comment occurrences only: the token name appears in prose too, and a naive
# [regexp -all] over the file counts the explanation as an emitter
proc count_emitters {path pat} {
  set fp [open $path r]; set src [read $fp]; close $fp
  set n 0
  foreach line [split $src "\n"] {
    if {[regexp {^\s*#} $line]} { continue }
    incr n [regexp -all $pat $line]
  }
  return $n
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvgrid]

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

if {[catch {

# ============================================================================
# GP* — pure: the clamped accessor and the emitted token
# ============================================================================
set save_gd [expr {[info exists ::wviewer_grid_dash_off] ? $::wviewer_grid_dash_off : {}}]

check "GP1 the shipped default is 3 (1-on/3-off = half the lit pixels)" \
  [pcall {wviewer::grid_dash_off}] 3
# the arithmetic the value encodes, asserted so a future edit is caught: the
# shipped pattern is d-on/d-off (50% duty); 1-on/3-off has the same period at
# d=2 and half the duty
check_true "GP1 1-on/3-off really is half the duty of 2-on/2-off" \
  [expr {1.0/(1+3) == 0.5 * (2.0/(2+2))}]
check_true "GP1 ... and the same 4-pixel period" [expr {1+3 == 2+2}]

check "GP2 0 is legal — it restores the shipped grid exactly" \
  [pcall {set ::wviewer_grid_dash_off 0; wviewer::grid_dash_off}] 0
check "GP3 a legal override is taken verbatim" \
  [pcall {set ::wviewer_grid_dash_off 8; wviewer::grid_dash_off}] 8
check "GP4 the upper clamp is inclusive" \
  [pcall {set ::wviewer_grid_dash_off 32; wviewer::grid_dash_off}] 32
foreach {tag bad} {GP5 33 GP6 -1 GP7 abc GP8 {} GP9 { } GP10 2.5 GP11 1e3} {
  set ::wviewer_grid_dash_off $bad
  # falls back to the DEFAULT, not to 0: a typo must not silently restore the
  # heavy grid the user asked to be rid of
  check "$tag out-of-range/garbage '$bad' falls back to the default 3" \
    [pcall {wviewer::grid_dash_off}] 3
}
set ::wviewer_grid_dash_off 3

set G [wviewer::empty_graph]
set props [pcall {wviewer::graph_props $G}]
check "GP12 graph_props emits griddash from the var" [tokof $props griddash] 3
set ::wviewer_grid_dash_off 5
check "GP13 the token TRACKS the var (not a second hard-coded constant)" \
  [tokof [pcall {wviewer::graph_props $G}] griddash] 5
set ::wviewer_grid_dash_off 0
set props [pcall {wviewer::graph_props $G}]
check "GP14 griddash=0 is EMITTED, not omitted" [tokof $props griddash] 0
check_true "GP14 the token is really in the string" \
  [expr {[string first "griddash=0" $props] >= 0}]
set ::wviewer_grid_dash_off 3
# the density knob must not have disturbed the line COUNT — D-B chose the duty
# cycle precisely so that no grid line disappears
set props [pcall {wviewer::graph_props $G}]
check "GP15 divx/divy untouched (no line was removed)" \
  [list [tokof $props divx] [tokof $props divy]] {5 5}
check "GP16 subdivx/subdivy untouched either" \
  [list [tokof $props subdivx] [tokof $props subdivy]] {1 1}

# ============================================================================
# GD* — the drawline split that item 2 needed
# ============================================================================
set dc [file join $repo src draw.c]
set fp [open $dc r]; set csrc [read $fp]; close $fp
check_true "GD1 drawline_duty exists and takes an independent off-run" \
  [regexp {void drawline_duty\(int c, int what,[^)]*int dash, int dash_off, void \*ct\)} $csrc]
check_true "GD2 the grid asks for the reduced duty" \
  [regexp {drawline_duty\(GRIDLAYER, ADD,[^;]*dash_on, dash_off, ct\)} $csrc]
# THE equivalence claim: drawline must be a pure delegate passing dash twice, so
# that all ~86 existing call sites are byte-identical. If someone later teaches
# drawline its own off-run, this leg is the tripwire.
check_true "GD3 drawline is a pure delegate passing (dash, dash)" \
  [regexp {drawline_duty\(c, what, linex1, liney1, linex2, liney2, bus, dash, dash, ct\);} $csrc]
check "GD4 no 1-element XSetDashes left inside the split core" \
  [regexp -all {dash_arr\[0\] = dash_arr\[1\] = \(char\) ?dash;} \
     [string range $csrc [string first "void drawline_duty" $csrc] \
        [expr {[string first "void drawline_duty" $csrc] + 4000}]]] 0

# ============================================================================
# GB* — blast radius: embedded schematic graphs must not move
# ============================================================================
set sc [file join $repo src scheduler.c]
set fp [open $sc r]; set ssrc [read $fp]; close $fp
check "GB1 the C add_graph template has NO griddash token" \
  [regexp -all {"griddash} $ssrc] 0
check "GB2 exactly one emitter of griddash= in the Tcl" \
  [pcall {count_emitters [file join $repo src wave_viewer.tcl] {griddash=}}] 1
# and the grid gate itself is per-rect, never a global
check_true "GB3 the grid duty comes from the per-rect gr->griddash" \
  [regexp {gr->griddash > 0 && dash_on > 0} $csrc]
check_true "GB4 griddash is defaulted BEFORE the RECT_OUTSIDE early return" \
  [expr {[string first "gr->griddash = 0;" $csrc] <
         [string first "if(RECT_OUTSIDE(gr->sx1, gr->sy1, gr->sx2, gr->sy2," $csrc]}]

# ============================================================================
# GT* — item 3: Ctrl-G toggles the grid (pure + source legs)
# ============================================================================
set save_gs [expr {[info exists ::wviewer_grid_show] ? $::wviewer_grid_show : {}}]

check "GT1 the shipped default shows the grid" [pcall {wviewer::default_grid_show}] 1
check "GT2 an rc can start a window grid-OFF" \
  [pcall {set ::wviewer_grid_show 0; wviewer::default_grid_show}] 0
foreach {tag v} {GT3 bogus GT4 {} GT5 2.5} {
  set ::wviewer_grid_show $v
  check "$tag garbage '$v' falls back to grid ON" [pcall {wviewer::default_grid_show}] 1
}
set ::wviewer_grid_show 1

# The token is emitted ONLY when the grid is OFF -- an absent `grid` token means
# "draw it", which is what every non-viewer graph in the tree relies on, and it
# keeps a grid-on window's rects byte-identical to pre-item-3.
set Gg [wviewer::empty_graph]
check_true "GT6 grid ON emits NO grid token at all" \
  [expr {[string first "grid=" [pcall {wviewer::graph_props $Gg 0 1}]] < 0}]
check_true "GT7 grid OFF emits grid=0" \
  [expr {[string first "grid=0" [pcall {wviewer::graph_props $Gg 0 0}]] >= 0}]
# ...and the flag arrives as an ARGUMENT, not from a namespace global: the same
# objection that shaped item 2's drawline split. If someone later reaches for a
# global here, the two legs above still pass but this one goes red.
check_true "GT8 graph_props takes the grid flag as a parameter" \
  [expr {[llength [info args wviewer::graph_props]] == 3
         && [lindex [info args wviewer::graph_props] 2] eq {grid}}]
check "GT9 ...and it defaults to ON, so old call sites are unchanged" \
  [lindex [info default wviewer::graph_props grid dflt; set dflt] 0] 1

check "GT10 grid_shown on no token is ON (never a mystery-off)" \
  [pcall {wviewer::grid_shown {}}] 1
check "GT11 grid_toggle with no viewer -> {} (no throw)" \
  [pcall {wviewer::grid_toggle}] {}
check "GT12 grid_toggle_at on a non-viewer canvas -> {} (no throw)" \
  [pcall {wviewer::grid_toggle_at .drw}] {}

# the C half: gated lines, and the default that keeps every other graph's grid
check "GT13 exactly the four DASHED grid lines are gated" \
  [regexp -all {if\(gr->grid\)} $csrc] 4
check_true "GT14 grid defaults to 1 (an absent token draws the grid)" \
  [regexp {gr->grid = 1;} $csrc]
check_true "GT15 grid is defaulted BEFORE the RECT_OUTSIDE early return" \
  [expr {[string first "gr->grid = 1;" $csrc] <
         [string first "if(RECT_OUTSIDE(gr->sx1, gr->sy1, gr->sx2, gr->sy2," $csrc]}]
# the axis numbers must NOT be gated -- "gate draw_graph_grid's body" would have
# taken them with it, leaving an unreadable plot
check_true "GT16 the axis NUMBERS are drawn outside the grid gate" \
  [regexp {if\(gr->grid\)\s*\n\s*drawline_duty} $csrc]
check "GT17 no draw_string call sits behind the grid gate" \
  [regexp -all {if\(gr->grid\)\s*\n\s*draw_string} $csrc] 0

if {$save_gs ne {}} { set ::wviewer_grid_show $save_gs }

# ============================================================================
# GG* — GUI legs (self-SKIP without a usable DISPLAY)
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # WSLg-robust key delivery: a bare `event generate` loses the key when the
  # focus round-trip has not completed (measured ~1 run in 5, see
  # test_wave_modes MG16). Gate on Tk reporting the canvas as focus owner and
  # retry until the effect shows.
  proc send_key {w ev done} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {![winfo exists $w]} { return 0 }
      focus -force $w
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[focus -displayof $w] eq $w} {
        event generate $w $ev
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
      }
      after 50
    }
    puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
    return 0
  }

  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "GG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: GG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw

  check "GG1 strip 0 carries griddash" [pcall {xschem getprop rect 2 0 griddash}] 3
  check "GG1 EVERY strip carries it" \
    [list [pcall {xschem getprop rect 2 0 griddash}] \
          [pcall {xschem getprop rect 2 1 griddash}]] {3 3}

  set ::wviewer_grid_dash_off 0
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "GG2 an rc-set 0 (shipped grid) reaches the rect" \
    [pcall {xschem getprop rect 2 0 griddash}] 0
  set ::wviewer_grid_dash_off 7
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "GG2 and an rc-set 7 does too" [pcall {xschem getprop rect 2 0 griddash}] 7
  set ::wviewer_grid_dash_off 3
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "GG2 back to the default" [pcall {xschem getprop rect 2 0 griddash}] 3

  # capture re-reads the rects into the model and regenerate rebuilds them FROM
  # the model; griddash is generated, not captured, so it must survive both
  pcall {wviewer::capture_live_graph_state $tok}
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "GG3 griddash survives capture + regenerate" \
    [pcall {xschem getprop rect 2 0 griddash}] 3
  check "GG3 the viewer buffer is still not modified" [xschem get modified] 0
  # a redraw with the reduced duty must not throw (the pixels are eyeball-only,
  # but a crash or a bad GC would surface here)
  check "GG4 a redraw with the reduced grid returns clean" \
    [pcall {wviewer::in_ctx $tok {xschem redraw}}] {}

  # --- item 3: Ctrl-G toggles the grid ---------------------------------------
  set ::wvg_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wvg_log $line }

  check "GT20 the window starts with the grid ON" [pcall {wviewer::grid_shown $tok}] 1
  check "GT20 ...and its rects carry NO grid token" \
    [pcall {xschem getprop rect 2 0 grid}] {}
  set nlog [llength $::wvg_log]
  check "GT21 toggle returns the NEW state" [pcall {wviewer::grid_toggle {} $tok}] 0
  xschem new_schematic switch $vdrw
  check "GT21 every rect gained grid=0" \
    [list [pcall {xschem getprop rect 2 0 grid}] \
          [pcall {xschem getprop rect 2 1 grid}]] {0 0}
  check "GT21 exactly one replayable line logged" \
    [expr {[llength $::wvg_log] - $nlog}] 1
  check "GT21 the line carries the explicit state and token" \
    [lindex $::wvg_log end] "wviewer::grid_toggle 0 $tok"
  check "GT22 toggling back returns 1" [pcall {wviewer::grid_toggle {} $tok}] 1
  xschem new_schematic switch $vdrw
  check "GT22 the token is REMOVED again, not left as grid=1" \
    [pcall {xschem getprop rect 2 0 grid}] {}
  # a window option, not model content: no undo point, buffer untouched
  check "GT23 the toggle is NOT an undo point (window option, not content)" \
    [pcall {wviewer::history_depth $tok}] {0 0}
  check "GT23 the buffer is not modified" [xschem get modified] 0
  # change-only rule: a redundant set logs nothing
  set nlog [llength $::wvg_log]
  check "GT24 setting the state it already has is a no-op" \
    [pcall {wviewer::grid_toggle 1 $tok}] 1
  check "GT24 ...and logs nothing" [expr {[llength $::wvg_log] - $nlog}] 0
  check "GT25 a bad want value is refused" [pcall {wviewer::grid_toggle bogus $tok}] {}
  # the menu mirror must track the model however the state changed
  check "GT26 the menu mirror follows the model" \
    [expr {$::wviewer::gridshow($tok)}] 1
  pcall {wviewer::grid_toggle {} $tok}
  check "GT26 ...after a toggle too" [expr {$::wviewer::gridshow($tok)}] 0
  pcall {wviewer::grid_toggle 1 $tok}

  # the binding seam + a REAL Ctrl-G
  check "GT27 Ctrl-G is on the WaveViewer tag by default" \
    [expr {[bind WaveViewer <Control-Key-g>] ne {}}] 1
  check_true "GT27 it calls grid_toggle_at with the event's canvas" \
    [string match {*wviewer::grid_toggle_at %W*} [bind WaveViewer <Control-Key-g>]]
  wviewer::strip_bindings $vdrw
  check_true "GT27 it survives the strip_bindings sweep" \
    [expr {[bind WaveViewer <Control-Key-g>] ne {}}]
  check "GT27 Ctrl-G is NOT on the canvas widget itself" \
    [bind $vdrw <Control-Key-g>] {}
  set gdelivered [send_key $vdrw <Control-Key-g> {[wviewer::grid_shown $tok] == 0}]
  if {!$gdelivered} {
    puts "SKIPPED: GT28 real-key leg (focus never confirmed)"
  } else {
    check "GT28 a REAL Ctrl-G turned the grid off" [pcall {wviewer::grid_shown $tok}] 0
    check "GT28 the key gesture logs like the command" \
      [lindex $::wvg_log end] "wviewer::grid_toggle 0 $tok"
    send_key $vdrw <Control-Key-g> {[wviewer::grid_shown $tok] == 1}
    check "GT28 and back on" [pcall {wviewer::grid_shown $tok}] 1
  }

  # the Graph-menu checkbutton twin
  set gm $vtop.wvmenubar.graph
  if {[winfo exists $gm]} {
    set gidx -1
    for {set i 0} {$i <= [$gm index end]} {incr i} {
      if {[catch {$gm entrycget $i -label} lb]} continue
      if {$lb eq {Grid}} { set gidx $i; break }
    }
    check_true "GT29 the Graph menu has a Grid entry" [expr {$gidx >= 0}]
    if {$gidx >= 0} {
      check "GT29 it is a checkbutton, not a command" [$gm type $gidx] checkbutton
      check "GT29 it advertises Ctrl+G" [$gm entrycget $gidx -accelerator] Ctrl+G
      $gm invoke $gidx
      check "GT29 invoking it turned the grid off" [pcall {wviewer::grid_shown $tok}] 0
      $gm invoke $gidx
      check "GT29 ...and back on (the mirror did not invert twice)" \
        [pcall {wviewer::grid_shown $tok}] 1
    }
  } else {
    puts "SKIPPED: GT29 (viewer menubar not found)"
  }

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action

  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: GG* GUI legs (no DISPLAY)"
}

if {$save_gd ne {}} { set ::wviewer_grid_dash_off $save_gd }

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_grid: $npass passed, $fail failed"
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
