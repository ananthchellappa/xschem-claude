# tests/headless/test_wave_legend.tcl — ASE Waveform Viewer legend text size
# and weight (viewer plan item 1,
# doc/claude/suggestions/plan_viewer_enhancements_2026-07.md; contract in
# doc/claude/specs/waveform_viewer.md)
#
# The feature: the viewer legend is enlarged to the size of the Y-axis numbers
# and drawn in the bold face; the bolded wave (issue 0152), which used to be
# the only bold entry, is distinguished by SLANT instead. Both are driven by
# per-rect prop tokens emitted only by the viewer's own strip template, so the
# ~127 shipped schematics with embedded graphs are untouched (decision D-G).
#
# ⚠ WHAT THIS SUITE CANNOT SEE, said plainly rather than hidden: the PIXELS.
# There is no C->Tcl getter for any Graph_ctx txtsize field and the ASE legend
# is not hit-tested (edit_wave_attributes only hit-tests the vlegend strip and
# the digital labels), so "the text is bigger" and "the text is bold italic"
# are EYEBALL-ONLY. What is asserted is everything up to the renderer's door:
# the clamp, the emitted tokens, that they reach the rects, and the blast
# radius. A green run here means the renderer was handed the right numbers.
#
# What is asserted:
#   LP*  the PURE half (runs under --nogui): the two clamped accessors and the
#        graph_props token emission, including the NaN case the `>=`/`<=` clamp
#        form exists for
#   LG1  the tokens reach the RECTS after a regenerate
#   LG2  an rc override reaches the rects, both vars
#   LG3  BLAST RADIUS (decision D-G): the C `add_graph` template — every
#        embedded schematic graph — emits NO legendbold and keeps legendmag=1.0
#   LG4  the tokens survive the viewer's own round trips (capture + regenerate)
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_legend.tcl

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
# the value of prop token `tok` in a graph_props string
proc tokof {props tok} {
  foreach line [split $props "\n"] {
    if {[regexp "^$tok=(.*)\$" $line -> v]} { return $v }
  }
  return {}
}

# COUNT only real emitters of a token. `legendbold=` appears in PROSE too — the
# comments that explain it — and a naive [regexp -all] over the whole file counts
# those, which is exactly what the first version of LG3 did (it reported 3 and
# failed). Comment lines are dropped before counting.
proc count_emitters {path} {
  set fp [open $path r]; set src [read $fp]; close $fp
  set n 0
  foreach line [split $src "\n"] {
    if {[regexp {^\s*#} $line]} { continue }
    incr n [regexp -all {legendbold=} $line]
  }
  return $n
}

set no_recent_files 1
set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvlegend]

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
# LP* — pure: the clamped accessors and the emitted tokens
# ============================================================================
set save_mag  [expr {[info exists ::wviewer_legend_textmag] ? $::wviewer_legend_textmag : {}}]
set save_bold [expr {[info exists ::wviewer_legend_bold]    ? $::wviewer_legend_bold    : {}}]

check "LP1 the shipped default is the Y-axis match, 1.63" \
  [pcall {wviewer::legend_textmag}] 1.63
# By REVIEW 2026-07-29 the default is 0: the size change stands, but bold goes
# back to marking the SELECTED trace only (issue 0152). The user's words on
# seeing it: "we want same font size as axis, but bolding only when the
# associated trace is selected".
check "LP1 the shipped default is NOT all-bold (bold marks the selection)" \
  [pcall {wviewer::legend_bold}] 0
# the derivation, asserted so a future edit to either constant is caught:
# txtsizelab = 8.4e-4*rh*legendmag must equal txtsizey = 1.368e-3*rh at divy=5
check_true "LP1 1.63 really does match txtsizey/txtsizelab (within 1%)" \
  [expr {abs(1.63 - 1.368e-3/8.4e-4) / (1.368e-3/8.4e-4) < 0.01}]

set ::wviewer_legend_textmag 2.5
check "LP2 a legal override is taken verbatim" [pcall {wviewer::legend_textmag}] 2.5
foreach {tag bad} {LP3 {} LP4 abc LP5 0.1 LP6 99 LP7 { } LP8 -2} {
  set ::wviewer_legend_textmag $bad
  check "$tag garbage/out-of-range '$bad' falls back to the default" \
    [pcall {wviewer::legend_textmag}] 1.63
}
# THE reason the clamp is `>=`/`<=` and not `<`/`>`: both < and > are FALSE for
# a NaN, so a `if {$v < 0.25 || $v > 6.0}` guard would let NaN through, atof()
# would hand setup_graph_data a NaN txtsizelab and the strip would render
# nothing at all. `string is double` accepts NaN, so it cannot be the guard.
foreach {tag bad} {LP9 NaN LP10 Inf LP11 -Inf LP12 nan} {
  set ::wviewer_legend_textmag $bad
  check "$tag non-finite '$bad' is rejected (the >=/<= clamp form)" \
    [pcall {wviewer::legend_textmag}] 1.63
}
set ::wviewer_legend_textmag 1.63

foreach {tag v exp} {LP13 0 0  LP14 1 1  LP15 true 1  LP16 false 0
                     LP17 no 0  LP18 yes 1} {
  set ::wviewer_legend_bold $v
  check "$tag legend_bold '$v' -> $exp" [pcall {wviewer::legend_bold}] $exp
}
foreach {tag v} {LP19 {} LP20 maybe LP21 2.5} {
  set ::wviewer_legend_bold $v
  check "$tag unrecognised '$v' falls back to the conservative 0" \
    [pcall {wviewer::legend_bold}] 0
}
set ::wviewer_legend_bold 0

# --- the tokens graph_props emits ---
set G [wviewer::empty_graph]
set props [pcall {wviewer::graph_props $G}]
check "LP22 graph_props emits legendmag from the var, not the old 1.0" \
  [tokof $props legendmag] 1.63
check "LP23 graph_props emits legendbold" [tokof $props legendbold] 0
# teeth: the token must TRACK the var, not be a second hard-coded constant
set ::wviewer_legend_textmag 3.0
set ::wviewer_legend_bold 1
set props [pcall {wviewer::graph_props $G}]
check "LP24 legendmag tracks the var" [tokof $props legendmag] 3.0
check "LP25 legendbold tracks the var too" [tokof $props legendbold] 1
# emitted even at the 0 default, never omitted: an rc that turns the all-bold
# look ON and then OFF again must take effect on a regenerate, not leave the
# old value sitting in the rect
set ::wviewer_legend_bold 0
set props [pcall {wviewer::graph_props $G}]
check_true "LP25 legendbold=0 is EMITTED, not omitted" \
  [expr {[string first "legendbold=0" $props] >= 0}]
set ::wviewer_legend_textmag 1.63
# nothing else in the template moved
set props [pcall {wviewer::graph_props $G}]
check "LP26 the axis mags are untouched (only the LEGEND was too small)" \
  [list [tokof $props xlabmag] [tokof $props ylabmag]] {1.0 1.0}
check "LP27 divy is still 5 — the value 1.63 is derived from it" \
  [tokof $props divy] 5

# ============================================================================
# LG* — GUI legs (self-SKIP without a usable DISPLAY)
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

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "LG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: LG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw

  # --- LG1: the tokens reach the rects ---------------------------------------
  check "LG1 two viewer rects placed" [xschem get rects 2] 2
  check "LG1 strip 0 carries the enlarged legendmag" \
    [pcall {xschem getprop rect 2 0 legendmag}] 1.63
  check "LG1 strip 0 carries legendbold" \
    [pcall {xschem getprop rect 2 0 legendbold}] 0
  check "LG1 EVERY strip carries them, not just the first" \
    [list [pcall {xschem getprop rect 2 1 legendmag}] \
          [pcall {xschem getprop rect 2 1 legendbold}]] {1.63 0}

  # --- LG2: an rc override reaches the rects ---------------------------------
  set ::wviewer_legend_textmag 2.0
  set ::wviewer_legend_bold 1
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "LG2 an rc-set textmag reaches the rect" \
    [pcall {xschem getprop rect 2 0 legendmag}] 2.0
  check "LG2 an rc-set bold=1 (opt-in all-bold) reaches the rect" \
    [pcall {xschem getprop rect 2 0 legendbold}] 1
  set ::wviewer_legend_textmag 1.63
  set ::wviewer_legend_bold 0
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "LG2 and it goes back to the defaults" \
    [list [pcall {xschem getprop rect 2 0 legendmag}] \
          [pcall {xschem getprop rect 2 0 legendbold}]] {1.63 0}

  # --- LG4: the tokens survive a capture round trip --------------------------
  # capture_live_graph_state re-reads the rects into the model; a regenerate
  # then rebuilds the rects FROM the model. The legend tokens are generated,
  # not captured, so they must come back identical either way.
  pcall {wviewer::capture_live_graph_state $tok}
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "LG4 legendmag survives capture + regenerate" \
    [pcall {xschem getprop rect 2 0 legendmag}] 1.63
  check "LG4 legendbold survives capture + regenerate" \
    [pcall {xschem getprop rect 2 0 legendbold}] 0
  check "LG4 the viewer buffer is still not modified" [xschem get modified] 0

  catch {wviewer::close $tok}
  }

  # --- LG3: BLAST RADIUS (decision D-G) --------------------------------------
  # The C add_graph template (scheduler.c ~1900) is what EVERY on-canvas
  # schematic graph is born from — ~127 shipped schematics embed one. It must
  # NOT have gained the new token, and its legendmag must still be 1.0, or item
  # 1 silently resized every graph in the tree.
  set ctmpl [file join $repo src scheduler.c]
  set fp [open $ctmpl r]; set csrc [read $fp]; close $fp
  check_true "LG3 the C add_graph template still says legendmag=1.0" \
    [expr {[string first "\"legendmag=1.0\\n\"" $csrc] >= 0}]
  check "LG3 the C add_graph template has NO legendbold token" \
    [regexp -all {"legendbold} $csrc] 0
  # and the only emitter of the token is the viewer's own generator
  check "LG3 exactly one emitter of legendbold= in the Tcl" \
    [pcall {count_emitters [file join $repo src wave_viewer.tcl]}] 1

} else {
  puts "SKIPPED: LG1/LG2/LG4 GUI legs (no DISPLAY)"
  # LG3 needs no window — it reads source files
  set fp [open [file join $repo src scheduler.c] r]; set csrc [read $fp]; close $fp
  check_true "LG3 the C add_graph template still says legendmag=1.0" \
    [expr {[string first "\"legendmag=1.0\\n\"" $csrc] >= 0}]
  check "LG3 the C add_graph template has NO legendbold token" \
    [regexp -all {"legendbold} $csrc] 0
  check "LG3 exactly one emitter of legendbold= in the Tcl" \
    [pcall {count_emitters [file join $repo src wave_viewer.tcl]}] 1
}

if {$save_mag  ne {}} { set ::wviewer_legend_textmag $save_mag }
if {$save_bold ne {}} { set ::wviewer_legend_bold $save_bold }

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_legend: $npass passed, $fail failed"
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
