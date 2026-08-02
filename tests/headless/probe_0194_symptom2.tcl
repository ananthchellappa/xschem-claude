# probe_0194_symptom2.tcl — NOT a suite: a measurement rig for issue 0194's
# second, never-reproduced symptom.
#
#   "Plot signals A, B, C to three strips. Move B from strip 2 to strip 1.
#    Press CTRL-G. The trace that was moved across strips (B) gets bolded /
#    unbolded with each CTRL-G — it alternates."
#
# Prints the rect-side selection of every strip after each of four grid
# toggles, for four starting conditions, so "does it alternate?" is answered by
# a table instead of by reasoning. Run it on the FIX and on a stash of the fix.
#
#   ./tests/headless/gated_xschem.sh --pipe -q --nolog \
#      --script tests/headless/probe_0194_symptom2.tcl

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch p0194]

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

if {![info exists ::has_x] || [info commands winfo] eq {}} {
  puts "SKIPPED: needs a DISPLAY"
  exit 0
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
wviewer::open $tok
set vtop [wviewer::window_for $tok]
set vdrw $vtop.drw
if {![viewer_ready $vtop]} { puts "SKIPPED: viewer never mapped"; exit 0 }

xschem new_schematic switch $vdrw
xschem raw new p0194.raw dc vsweep 0 1.0 0.02
foreach {v ex} {vec_a {vsweep 1 +} vec_b {vsweep 3 +} vec_c {vsweep 5 +}} {
  catch {xschem raw add $v $ex}
}

proc sels {vdrw} {
  xschem new_schematic switch $vdrw
  set o {}
  set n 0; catch {set n [xschem get graph_rects]}
  for {set k 0} {$k < $n} {incr k} {
    set s [wviewer::selected_waves $vdrw $k]
    lappend o [expr {[llength $s] ? $s : "-"}]
  }
  return $o
}
proc msels {tok} {
  set o {}
  foreach G [dict get [wviewer::layout_for $tok] graphs] {
    set s [wviewer::model_sel $G]
    lappend o [expr {[llength $s] ? $s : "-"}]
  }
  return $o
}
# A B C on three strips, one trace each — the user's fixture
proc fixture {tok} {
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph] \
                                 [wviewer::empty_graph]]
  foreach {gi vec} {0 vec_a 1 vec_b 2 vec_c} { wviewer::add_trace $tok $gi $vec }
  wviewer::regenerate $tok
}
# the selection as the C click arm writes it: RECT ONLY
proc plant {tok vdrw gi sel} {
  wviewer::with_edit $tok {
    set n 0; catch {set n [xschem get graph_rects]}
    for {set k 0} {$k < $n} {incr k} { catch {xschem setprop rect 2 $k hilight_wave -1} }
    if {[llength $sel]} { xschem setprop rect 2 $gi hilight_wave [lindex $sel 0] }
  }
}

# `sel` = which strip B is selected on before the move ({} = nothing selected)
foreach {tag presel} {A-nothing-selected {} B-selected-before-move 1 C-other-selected 0} {
  puts "\n=== $tag ==="
  fixture $tok
  plant $tok $vdrw $presel [expr {$presel eq {} ? {} : {0}}]
  puts [format "  %-22s rect=%-14s model=%s" "after plant" [sels $vdrw] [msels $tok]]
  # B lives on strip 1 (0-based) = the user's "strip 2"; move it to strip 0
  # (the user's "strip 1")
  wviewer::move_trace 1 0 0 $tok
  puts [format "  %-22s rect=%-14s model=%s" "after move B 1->0" [sels $vdrw] [msels $tok]]
  for {set i 1} {$i <= 4} {incr i} {
    wviewer::grid_toggle {} $tok
    puts [format "  %-22s rect=%-14s model=%s" "after CTRL-G #$i" [sels $vdrw] [msels $tok]]
  }
}

# The two states where the MODEL and the RECT can disagree after a move — which
# is the only way a toggle can CHANGE what is bold rather than just destroy it.
# `post` = what the user does to the RECT (i.e. clicks) AFTER the move:
#   D  clicks a different trace     -> rect = that trace, model = the moved one
#   E  clicks empty body (deselect) -> rect = nothing,    model = the moved one
foreach {tag post} {D-click-after-move {2 0} E-deselect-after-move {}} {
  puts "\n=== $tag ==="
  fixture $tok
  plant $tok $vdrw 1 {0}                 ;# B selected, then moved across strips
  wviewer::move_trace 1 0 0 $tok
  puts [format "  %-22s rect=%-14s model=%s" "after move B 1->0" [sels $vdrw] [msels $tok]]
  if {[llength $post]} {
    plant $tok $vdrw [lindex $post 0] [list [lindex $post 1]]
  } else {
    plant $tok $vdrw 0 {}
  }
  puts [format "  %-22s rect=%-14s model=%s" "after the click" [sels $vdrw] [msels $tok]]
  for {set i 1} {$i <= 4} {incr i} {
    wviewer::grid_toggle {} $tok
    puts [format "  %-22s rect=%-14s model=%s" "after CTRL-G #$i" [sels $vdrw] [msels $tok]]
  }
}

catch {wviewer::close $tok}
catch {ase::session_close $tok}
puts "\nprobe done"
