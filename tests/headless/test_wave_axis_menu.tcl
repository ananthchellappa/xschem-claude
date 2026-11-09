# tests/headless/test_wave_axis_menu.tcl -- ASE Waveform Viewer: a right-click
# on a strip's AXIS MARGIN switches that axis between linear and log.
#
# The user (2026-11-09): "We need a context menu on both axes (right click)
# that lets user easily switch between linear and logarithmic scale for the
# axes."
#
# Code  src/wave_viewer.tcl wviewer::axis_scale_targets, axis_scale_graphs (the
#       decision, pure), axis_at / axis_menu_pick (the margin gate, the
#       engine's `xschem get graph_axis_at`), set_axis_scale (the act),
#       axis_menu_build / axis_menu_post / axis_menu_unpost (the menu),
#       ctx_menu_post (the dispatcher btn3_filter calls on a no-travel release),
#       graph_props (logy -> subdivy=8)
#
# Bands (both arms; pure, no Tk)
#   AP1  axis_scale_targets: Y is the strip; X is the strip, or its whole
#        subwindow under sharedx; a bad index is {}
#   AP2  axis_scale_graphs: a flip sets the key and blanks that axis's range,
#        leaves the other axis and every other key alone; a strip already at
#        that scale is byte-identical; sharedx flips the subwindow, not the
#        other subwindow; Log Y on a digital strip and bad input are refused
#   AP3  graph_props writes logy and the Y decade minor lines (subdivy 8) only
#        when log; a linear strip is subdivy=1
#   AN*  no-window legs never throw
# Bands (display arm only)
#   AG1  the gate: a pixel the engine calls the X margin picks {gi x}, the Y
#        margin {gi y}, the plot body and the legend pick nothing
#   AG2  the menu: two radiobuttons, Axes-dialog wording, reflecting the scale
#   AG3  the GESTURE: a no-travel RMB on the X margin posts the axis menu;
#        invoking Log X sets the model and the rect (logx=1 subdivx=8) on that
#        strip only, and its X range is in decades
#   AG4  the same on the Y margin: Log Y, then the menu again reflects it, and
#        Linear Y puts logy=0 subdivy=1 back
#   AG5  nothing else moved: a body RMB still gets the strip menu, a travelled
#        RMB on the Y margin still zooms Y and posts nothing, a modified RMB
#        posts nothing
#   AG6  a later plot into a strip whose Y the user set to log keeps it log
#   AG7  log of data <= 0: a log Y auto-ranges over the positive samples, a
#        log X over a sweep from 0 starts at its first positive value
#   AG8  a REAL tk_popup post of the menu, an invoke, and an unpost
#
# REGISTERED IN `hcases` AND `dcases`.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_wave_axis_menu
#   tests/headless/run_suites.sh test_wave_axis_menu

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} {
  if {[catch {expr {$cond ? 1 : 0}} v]} { check $name "NOT-A-BOOLEAN {$cond}" 1; return }
  check $name $v 1
}
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

set no_recent_files 1
set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvaxmenu]

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

proc am_G {args} {
  set G [dict create traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
  foreach {k v} $args { dict set G $k $v }
  return $G
}
proc am_tok {props k} {
  if {[regexp -line "^${k}=(.*)\$" $props -> v]} { return $v }
  return ABSENT
}

if {[catch {

# ============================================================================
# AP* -- the decision (both arms)
# ============================================================================
set G0 [am_G x1 0 x2 1 y1 -2 y2 2 tag A]
set G1 [am_G x1 0 x2 1 y1 -3 y2 3 tag B]
set G2 [am_G x1 5 x2 9 y1 -4 y2 4 tag C]
set lay [dict create sharedx 0 graphs [list $G0 $G1 $G2]]
check "AP1 Y acts on the strip alone" \
  [pcall {wviewer::axis_scale_targets $lay 1 y}] 1
check "AP1 X without sharedx acts on the strip alone" \
  [pcall {wviewer::axis_scale_targets $lay 1 x}] 1
check "AP1 X with sharedx acts on every strip of the subwindow" \
  [pcall {wviewer::axis_scale_targets [dict replace $lay sharedx 1] 1 x}] {0 1 2}
check "AP1 Y with sharedx is still the strip alone" \
  [pcall {wviewer::axis_scale_targets [dict replace $lay sharedx 1] 1 y}] 1
set G0s [dict replace $G0 sw 1]; set G1s [dict replace $G1 sw 1]
set G2s [dict replace $G2 sw 2]
set lays [dict create sharedx 1 graphs [list $G0s $G1s $G2s]]
check "AP1 X with sharedx stops at the subwindow edge" \
  [list [pcall {wviewer::axis_scale_targets $lays 0 x}] \
        [pcall {wviewer::axis_scale_targets $lays 2 x}]] {{0 1} 2}
foreach bad {-1 3 x {}} {
  check "AP1 a bad index [list $bad] targets nothing" \
    [pcall {wviewer::axis_scale_targets $lay $bad x}] {}
}

set gs [pcall {wviewer::axis_scale_graphs $lay 1 x 1}]
check "AP2 Log X on strip 1: logx 1, X range blanked to auto" \
  [lmap k {logx x1 x2} {wviewer::dget [lindex $gs 1] $k ABSENT}] {1 {} {}}
check "AP2 ...its Y, its logy and its other keys are untouched" \
  [lmap k {logy y1 y2 tag} {wviewer::dget [lindex $gs 1] $k ABSENT}] {0 -3 3 B}
check "AP2 ...the other strips are byte-identical" \
  [list [expr {[lindex $gs 0] eq $G0}] [expr {[lindex $gs 2] eq $G2}]] {1 1}
set gs [pcall {wviewer::axis_scale_graphs $lay 2 y 1}]
check "AP2 Log Y on strip 2: logy 1, Y range blanked, X kept" \
  [lmap k {logy y1 y2 logx x1 x2} {wviewer::dget [lindex $gs 2] $k ABSENT}] {1 {} {} 0 5 9}
set lay1 [dict create sharedx 0 graphs [list $G0 [dict replace $G1 logy 1 y1 -1 y2 1] $G2]]
check "AP2 Log Y on a strip already log Y is the identity (its range is kept)" \
  [pcall {wviewer::axis_scale_graphs $lay1 1 y 1}] [dict get $lay1 graphs]
set gs [pcall {wviewer::axis_scale_graphs $lay1 1 y 0}]
check "AP2 Linear Y on a log Y strip: logy 0, range blanked" \
  [lmap k {logy y1 y2} {wviewer::dget [lindex $gs 1] $k ABSENT}] {0 {} {}}
check "AP2 any true value means log" \
  [wviewer::dget [lindex [pcall {wviewer::axis_scale_graphs $lay 0 y 7}] 0] logy ABSENT] 1
set gs [pcall {wviewer::axis_scale_graphs $lays 1 x 1}]
check "AP2 sharedx: Log X flips both strips of the subwindow, blanking both" \
  [lmap i {0 1} {lmap k {logx x1 x2} {wviewer::dget [lindex $gs $i] $k ABSENT}}] \
  {{1 {} {}} {1 {} {}}}
check "AP2 sharedx: the other subwindow is byte-identical" \
  [expr {[lindex $gs 2] eq $G2s}] 1
set layd [dict create sharedx 0 graphs [list [dict replace $G0 digital 1]]]
check "AP2 Log Y on a digital strip is refused" \
  [pcall {wviewer::axis_scale_graphs $layd 0 y 1}] [dict get $layd graphs]
check "AP2 ...Log X on it is not" \
  [wviewer::dget [lindex [pcall {wviewer::axis_scale_graphs $layd 0 x 1}] 0] logx ABSENT] 1
check "AP2 a bad axis is refused" \
  [pcall {wviewer::axis_scale_graphs $lay 0 z 1}] [dict get $lay graphs]
check "AP2 a bad index is refused" \
  [pcall {wviewer::axis_scale_graphs $lay 9 x 1}] [dict get $lay graphs]

set lin [pcall {wviewer::graph_props [am_G]}]
set lgy [pcall {wviewer::graph_props [am_G logy 1]}]
check "AP3 a linear strip: logy=0 subdivy=1" \
  [list [am_tok $lin logy] [am_tok $lin subdivy]] {0 1}
check "AP3 a log Y strip: logy=1 subdivy=8 (decade minor lines), X untouched" \
  [list [am_tok $lgy logy] [am_tok $lgy subdivy] [am_tok $lgy logx] [am_tok $lgy subdivx]] \
  {1 8 0 1}

# ============================================================================
# AN* -- no window
# ============================================================================
check "AN1 the gate on a non-viewer canvas" [pcall {wviewer::axis_menu_pick .drw 10 10}] {-1 {}}
check "AN2 posting on a non-viewer canvas" [pcall {wviewer::axis_menu_post .drw 10 10}] 0
check "AN3 unposting an unknown token" [pcall {wviewer::axis_menu_unpost no/such}] 0
check "AN4 building for an unknown token" [pcall {wviewer::axis_menu_build no/such 0 x}] {}
check "AN5 setting a scale for an unknown token" [pcall {wviewer::set_axis_scale no/such 0 x 1}] 0

# ============================================================================
# AG* -- the real viewer (display arm)
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
  set ::amt 100000
  proc am_ev {w seq args} {
    set ::amt [expr {$::amt + 1000}]
    eval [list event generate $w $seq -time $::amt] $args
  }
  proc am_click {w px py {s 0}} {
    am_ev $w <ButtonPress-3>   -x $px -y $py -state $s
    am_ev $w <ButtonRelease-3> -x $px -y $py -state [expr {$s | 0x400}]
    update
  }
  proc am_rect {vdrw gi k} {
    xschem new_schematic switch $vdrw
    return [pcall {xschem getprop rect 2 $gi $k}]
  }
  proc am_model {tok gi k} {
    wviewer::dget [lindex [dict get [wviewer::layout_for $tok] graphs] $gi] $k ABSENT
  }
  # A canvas pixel of strip `gi` the ENGINE calls axis margin `ax`, scanning a
  # column (X margin) or a row (Y margin) through the plot box's middle. Every
  # pixel is the engine's answer, never a predicted margin width.
  proc am_axis_px {vdrw gi ax} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set hits {}
    for {set py 1} {$py < $H} {incr py} {
      for {set px 1} {$px < $W} {incr px 3} {
        if {[wviewer::strip_at_pixel $vdrw $px $py] != $gi} { continue }
        if {[wviewer::axis_at $vdrw $gi $px $py] eq $ax} { lappend hits [list $px $py] }
      }
      incr py 2
    }
    if {![llength $hits]} { return {} }
    return [lindex $hits [expr {[llength $hits] / 2}]]
  }
  proc am_body_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60 0.70} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 2} {
        if {[wviewer::strip_at_pixel $vdrw $px $py] != $gi} { continue }
        if {![wviewer::plotbox_at $vdrw $gi $px $py]} { continue }
        if {[wviewer::trace_at $vdrw $gi $px $py] < 0} { return [list $px $py] }
      }
    }
    return {}
  }
  proc am_legend_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    for {set py 1} {$py < $H} {incr py} {
      for {set px 1} {$px < $W} {incr px 2} {
        if {[wviewer::legend_at $vdrw $gi $px $py] >= 0} { return [list $px $py] }
      }
    }
    return {}
  }

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate
  check "AG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: AG* (viewer canvas never mapped)"
  } else {
  catch {wm geometry $vtop 900x700}
  for {set i 0} {$i < 10} {incr i} { update; after 20 }

  # a hermetic raw: sweep 0.01 .. 1 so a log X has no non-positive sample;
  # vec_p is positive everywhere, vec_z runs through zero, vec_n is negative
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvaxm.raw dc vsweep 0.01 1.0 0.01}
  foreach {v ex} {vec_p {vsweep 1 +} vec_q {vsweep 3 +}
                  vec_z {vsweep 0.5 -} vec_n {vsweep 2 -}} {
    pcall {xschem raw add $v $ex}
  }
  set rawvars [split [pcall {xschem raw list}] "\n"]
  check "AG0 the fixture raw knows its vectors" \
    [lmap v {vec_p vec_q vec_z vec_n} {expr {[lsearch -exact $rawvars $v] >= 0}}] {1 1 1 1}
  proc am_fill {tok} {
    wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
    foreach {gi vec} {0 vec_p 1 vec_q} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  am_fill: add_trace $vec -> $e" }
    }
    wviewer::regenerate $tok
    for {set i 0} {$i < 5} {incr i} { update; after 10 }
  }
  am_fill $tok

  # tk_popup is SPIED for the gesture legs: a live popup takes a global grab
  # that would swallow every later leg's events (AG8 posts one for real).
  rename ::tk_popup ::__am_real_tk_popup
  proc ::tk_popup {m x y args} { set ::am_popped [list $m $x $y] }

  set xm [am_axis_px $vdrw 1 x]
  set ym [am_axis_px $vdrw 1 y]
  set bp [am_body_px $vdrw 1]
  set lp [am_legend_px $vdrw 1]
  check_true "AG0 the engine names an X margin, a Y margin and a body pixel of strip 1" \
    [expr {[llength $xm] == 2 && [llength $ym] == 2 && [llength $bp] == 2}]
  if {[llength $xm] == 2 && [llength $ym] == 2 && [llength $bp] == 2} {

  # --- AG1 the gate ---------------------------------------------------------
  check "AG1 the X margin picks {1 x}" [pcall {wviewer::axis_menu_pick $vdrw {*}$xm}] {1 x}
  check "AG1 the Y margin picks {1 y}" [pcall {wviewer::axis_menu_pick $vdrw {*}$ym}] {1 y}
  check "AG1 the plot body picks nothing" [pcall {wviewer::axis_menu_pick $vdrw {*}$bp}] {-1 {}}
  if {[llength $lp] == 2} {
    check "AG1 a legend pixel picks nothing (it is the trace menu's)" \
      [pcall {wviewer::axis_menu_pick $vdrw {*}$lp}] {-1 {}}
  } else {
    puts "skip: AG1 legend leg (no legend pixel found)"
  }

  # --- AG2 the menu ---------------------------------------------------------
  set m [pcall {wviewer::axis_menu_build $tok 1 x}]
  check "AG2 the X menu: two radiobuttons, Axes-dialog wording" \
    [pcall {list [$m index end] [$m type 0] [$m entrycget 0 -label] \
                 [$m type 1] [$m entrycget 1 -label]}] \
    {1 radiobutton {Linear X} radiobutton {Log X}}
  check "AG2 ...reflecting a linear X" [pcall {set [$m entrycget 0 -variable]}] 0
  set m [pcall {wviewer::axis_menu_build $tok 1 y}]
  check "AG2 the Y menu" [pcall {list [$m entrycget 0 -label] [$m entrycget 1 -label]}] \
    {{Linear Y} {Log Y}}
  wviewer::axis_menu_unpost $tok

  # --- AG3 X margin gesture -------------------------------------------------
  set gs0 [dict get [wviewer::layout_for $tok] graphs]
  set ::am_popped {}
  am_click $vdrw {*}$xm
  check "AG3 a no-travel RMB on the X margin posts the AXIS menu" \
    [lindex $::am_popped 0] $vtop.wvaxismenu
  check "AG3 ...and the click itself changed nothing" \
    [expr {[dict get [wviewer::layout_for $tok] graphs] eq $gs0}] 1
  set m $vtop.wvaxismenu
  check "AG3 it is the X menu" [pcall {$m entrycget 1 -label}] {Log X}
  pcall {$m invoke 1}
  update
  check "AG3 Log X: the model's strip 1 is logx 1" [am_model $tok 1 logx] 1
  check "AG3 ...strip 0 is untouched (sharedx is off)" [am_model $tok 0 logx] 0
  check "AG3 ...the rect says logx=1 subdivx=8" \
    [list [am_rect $vdrw 1 logx] [am_rect $vdrw 1 subdivx]] {1 8}
  set x1 [am_rect $vdrw 1 x1]; set x2 [am_rect $vdrw 1 x2]
  check_true "AG3 ...and its X range is in decades (log10 0.01 = -2, log10 1 = 0)" \
    [expr {abs($x1 + 2) < 0.01 && abs($x2) < 0.01}]
  check "AG3 strip 0's rect is still linear" [am_rect $vdrw 0 logx] 0
  wviewer::axis_menu_unpost $tok

  # --- AG4 Y margin gesture -------------------------------------------------
  set ym [am_axis_px $vdrw 1 y]
  set ::am_popped {}
  am_click $vdrw {*}$ym
  check "AG4 a no-travel RMB on the Y margin posts the axis menu" \
    [lindex $::am_popped 0] $vtop.wvaxismenu
  check "AG4 it is the Y menu, reflecting a linear Y" \
    [pcall {list [$m entrycget 1 -label] [set [$m entrycget 1 -variable]]}] {{Log Y} 0}
  pcall {$m invoke 1}
  update
  check "AG4 Log Y: model logy 1, rect logy=1 subdivy=8" \
    [list [am_model $tok 1 logy] [am_rect $vdrw 1 logy] [am_rect $vdrw 1 subdivy]] {1 1 8}
  set y1 [am_rect $vdrw 1 y1]; set y2 [am_rect $vdrw 1 y2]
  # vec_q runs 3.01 .. 4: in decades about 0.479 .. 0.602
  check_true "AG4 ...its Y range is in decades" \
    [expr {abs($y1 - log10(3.01)) < 0.02 && abs($y2 - log10(4)) < 0.02}]
  check "AG4 ...strip 1 stays log X" [am_model $tok 1 logx] 1
  wviewer::axis_menu_unpost $tok
  set ym [am_axis_px $vdrw 1 y]
  set ::am_popped {}
  am_click $vdrw {*}$ym
  check "AG4 the menu posted again reflects Log Y" \
    [pcall {set [$m entrycget 0 -variable]}] 1
  pcall {$m invoke 0}
  update
  check "AG4 Linear Y: logy=0 subdivy=1 again" \
    [list [am_model $tok 1 logy] [am_rect $vdrw 1 logy] [am_rect $vdrw 1 subdivy]] {0 0 1}
  set y1 [am_rect $vdrw 1 y1]; set y2 [am_rect $vdrw 1 y2]
  check_true "AG4 ...and Y is back in data units" \
    [expr {abs($y1 - 3.01) < 0.05 && abs($y2 - 4) < 0.05}]
  wviewer::axis_menu_unpost $tok

  # --- AG5 nothing else moved -----------------------------------------------
  set bp [am_body_px $vdrw 1]
  set ::am_popped {}
  am_click $vdrw {*}$bp
  check "AG5 a body RMB still gets the STRIP menu" [lindex $::am_popped 0] $vtop.wvstripmenu
  catch {wviewer::strip_menu_unpost $tok}
  set ym [am_axis_px $vdrw 1 y]
  lassign $ym yx yy
  set ya [am_rect $vdrw 1 y1]; set yb [am_rect $vdrw 1 y2]
  set ::am_popped {}
  set yy2 [expr {$yy - 15}]
  am_ev $vdrw <ButtonPress-3>   -x $yx -y $yy -state 0
  am_ev $vdrw <Motion>          -x $yx -y $yy2 -state 0x400
  am_ev $vdrw <ButtonRelease-3> -x $yx -y $yy2 -state 0x400
  update
  check "AG5 a travelled RMB on the Y margin posts no menu" [llength $::am_popped] 0
  check_true "AG5 ...and still zooms Y" \
    [expr {abs(([am_rect $vdrw 1 y2] - [am_rect $vdrw 1 y1]) - ($yb - $ya)) > 1e-6}]
  wviewer::regenerate $tok
  update
  set xm [am_axis_px $vdrw 1 x]
  set ::am_popped {}
  am_click $vdrw {*}$xm 4
  check "AG5 a Control-modified RMB on the X margin posts no menu" [llength $::am_popped] 0

  # --- AG6 a manual Log Y sticks through a later plot -----------------------
  pcall {wviewer::set_axis_scale $tok 0 y 1}
  pcall {wviewer::add_trace $tok 0 vec_q}
  wviewer::regenerate $tok
  update
  check "AG6 a trace added to a log Y strip leaves it log Y" \
    [list [am_model $tok 0 logy] [am_rect $vdrw 0 logy]] {1 1}
  check "AG6 set_axis_scale to the scale it already has is a no-op" \
    [pcall {wviewer::set_axis_scale $tok 0 y 1}] 0

  # --- AG7 log of data <= 0 -------------------------------------------------
  # draw.c maps a value <= 0 through mylog10() (editprop.c) to -35, i.e. 1e-35.
  # MEASURED before the guard: Log Y over vec_z (-0.49 .. 0.5) auto-ranged to
  # y1=-35 y2=-0.3, squeezing the positive half into the top of the strip. The
  # guard (graph_fullyzoom, draw.c) auto-ranges a log Y over the POSITIVE
  # samples only; the non-positive ones are still drawn on the bottom rail.
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  pcall {wviewer::add_trace $tok 0 vec_z}
  pcall {wviewer::set_axis_scale $tok 0 y 1}
  update
  set z1 [am_rect $vdrw 0 y1]; set z2 [am_rect $vdrw 0 y2]
  puts "  note: AG7 Log Y over vec_z (-0.49 .. 0.5): y1=$z1 y2=$z2"
  # smallest positive sample of vec_z = vsweep - 0.5 is 0.01 (vsweep 0.51),
  # within the sweep's float steps
  check_true "AG7 Log Y over data through zero auto-ranges over the positive samples (about -2 .. -0.3)" \
    [expr {[string is double -strict $z1] && $z1 > -2.5 && $z1 < -1.5 && abs($z2 - log10(0.5)) < 0.02}]
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  pcall {wviewer::add_trace $tok 0 vec_n}
  pcall {wviewer::set_axis_scale $tok 0 y 1}
  update
  set n1 [am_rect $vdrw 0 y1]; set n2 [am_rect $vdrw 0 y2]
  puts "  note: AG7 Log Y over vec_n (all < 0): y1=$n1 y2=$n2"
  check_true "AG7 Log Y over all-negative data keeps a finite range (nothing to show, no error)" \
    [expr {[string is double -strict $n1] && [string is double -strict $n2] && $n1 < $n2}]

  # Log X over a sweep that starts at 0 (a transient's time axis): MEASURED
  # before the guard as x1=-35 x2=0. graph_fullxzoom (draw.c) now starts a log
  # window at the sweep's smallest positive value, here 0.01.
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvaxm0.raw dc vs0 0 1.0 0.01}
  pcall {xschem raw add vec_s {vs0 1 +}}
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  pcall {wviewer::add_trace $tok 0 vec_s}
  pcall {wviewer::set_axis_scale $tok 0 x 1}
  update
  set s1 [am_rect $vdrw 0 x1]; set s2 [am_rect $vdrw 0 x2]
  puts "  note: AG7 Log X over a sweep from 0: x1=$s1 x2=$s2"
  check_true "AG7 Log X over a sweep from 0 starts at its first positive sample (log10 0.01 = -2)" \
    [expr {[string is double -strict $s1] && abs($s1 + 2) < 0.01 && abs($s2) < 0.01}]
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvaxm.raw dc vsweep 0.01 1.0 0.01}
  foreach {v ex} {vec_p {vsweep 1 +} vec_q {vsweep 3 +}} { pcall {xschem raw add $v $ex} }

  # --- AG8 a real post ------------------------------------------------------
  rename ::tk_popup {}
  rename ::__am_real_tk_popup ::tk_popup
  am_fill $tok
  set xm [am_axis_px $vdrw 0 x]
  set safety [after 5000 [list wviewer::axis_menu_unpost $tok]]
  check "AG8 axis_menu_post really posts" [pcall {wviewer::axis_menu_post $vdrw {*}$xm}] 1
  update
  check "AG8 ...the menu is mapped" [pcall {winfo ismapped $vtop.wvaxismenu}] 1
  pcall {$vtop.wvaxismenu invoke 1}
  update
  check "AG8 invoking Log X on the posted menu sets strip 0 log X" \
    [list [am_model $tok 0 logx] [am_rect $vdrw 0 logx]] {1 1}
  check "AG8 axis_menu_unpost removes it" [wviewer::axis_menu_unpost $tok] 1
  after cancel $safety
  check "AG8 ...and no grab is left" [grab current] {}
  } else {
    puts "skip: AG1-AG8 (no margin pixel found)"
    rename ::tk_popup {}
    rename ::__am_real_tk_popup ::tk_popup
  }
  }
  catch {unset ::wviewer::b3x0($vdrw) ::wviewer::b3y0($vdrw) ::wviewer::b3mk($vdrw)}
  catch {wviewer::close $tok}
} else {
  puts "SKIPPED: AG* GUI legs (no DISPLAY)"
}

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_axis_menu: $npass passed, $fail failed"
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
