# tests/headless/test_wave_modes.tcl — ASE Waveform Viewer PLOT MODES (issue 0151)
#
# Spec: doc/claude/specs/waveform_viewer_modes.md
#
# What is asserted here (and why it is honest):
#   PURE legs (M*) need no DISPLAY — they drive the policy/validation procs
#   directly with hand-built arguments:
#     M1 wviewer::resolve_mode      single|multi|invert + garbage rejection
#     M2 wviewer::default_plot_mode config var -> initial mode, invalid -> single
#     M3 wviewer::plan_plot         THE landing policy: single = all signals into
#                                   the (clamped) target, no new strip unless the
#                                   stack is empty; multi = one strip per signal,
#                                   reusing empty strips, new ones on TOP, batch
#                                   newest-first (last pick topmost)
#     M4 wviewer::target_clamp      stale/negative target never escapes range
#     M5 wviewer::graph_props       emits `active=1` ONLY when asked (the C
#                                   indicator's only Tcl-side witness)
#     M6 the trace-COLOR policy     (issue 0153) first_unused_color /
#                                   graph_colors / colors_in_graphs /
#                                   next_color / plan_colors: single = per
#                                   landing strip (unchanged), multi = unique
#                                   across the WHOLE window (the "all yellow"
#                                   fix), prefix-stable for the picker
#   GUI legs (MG*) open a real viewer window (self-SKIP without a usable
#   DISPLAY) and assert per-window state, the menu, the click re-target, the
#   prop-token plumbing of the marker, persistence and the schematic-side
#   entry points. MG6c/MG6d (issue 0153) drive plot_signals for real and read
#   the trace colors back out of the MODEL: multi-plot must assign DIFFERENT
#   colors (pre-fix all three were 4), single-plot must still cycle, explicit
#   colors must win, and predict_colors must equal what plot_signals assigns.
#
# NOT asserted (stated, not hidden): the PIXELS of the dull-yellow active-strip
# marker. The C draw is gated behind draw_graph's new flags bit 16 and is
# eyeball-only, exactly like the wave rendering itself (test_wave_viewer.tcl
# header). What IS asserted is which rect carries `active=1`, when the token is
# absent, and that a redraw with the token present returns rc 0.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_modes.tcl
# (add --nogui to run only the pure legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# error-guarded call: a MISSING proc must make its own leg FAIL, not abort the
# whole file through the outer catch (this file is written RED-first, so every
# leg has to be able to report independently)
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch wvmodes]

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]

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
# PURE legs — policy + validation, no window
# ============================================================================

# --- M1: mode word resolution ------------------------------------------------
check "M1 invert flips single -> multi"  [pcall {wviewer::resolve_mode single invert}] multi
check "M1 invert flips multi -> single"  [pcall {wviewer::resolve_mode multi invert}]  single
check "M1 explicit multi"                [pcall {wviewer::resolve_mode single multi}]  multi
check "M1 explicit single"               [pcall {wviewer::resolve_mode multi single}]  single
check "M1 idempotent set"                [pcall {wviewer::resolve_mode multi multi}]   multi
check "M1 garbage rejected as {}"        [pcall {wviewer::resolve_mode single bogus}]  {}
check "M1 empty request rejected as {}"  [pcall {wviewer::resolve_mode single {}}]     {}
check "M1 case-insensitive request"      [pcall {wviewer::resolve_mode single MULTI}]  multi

# --- M2: config var -> initial mode ------------------------------------------
set save_cfg {}
if {[info exists ::wviewer_plot_mode]} { set save_cfg $::wviewer_plot_mode }
check "M2 shipped default is single" [pcall {set ::wviewer_plot_mode}] single
set ::wviewer_plot_mode multi
check "M2 config multi -> multi"     [pcall {wviewer::default_plot_mode}] multi
set ::wviewer_plot_mode MULTI
check "M2 config MULTI -> multi"     [pcall {wviewer::default_plot_mode}] multi
set ::wviewer_plot_mode nonsense
check "M2 invalid config -> single"  [pcall {wviewer::default_plot_mode}] single
set ::wviewer_plot_mode {}
check "M2 empty config -> single"    [pcall {wviewer::default_plot_mode}] single
set ::wviewer_plot_mode $save_cfg

# --- M3: THE landing policy --------------------------------------------------
# single: no new strip while one exists, everything into the target
check "M3 single/2 strips/target 1/3 signals" \
  [pcall {wviewer::plan_plot single 2 1 3}] {new 0 targets {1 1 1}}
check "M3 single/1 strip/target 0/1 signal" \
  [pcall {wviewer::plan_plot single 1 0 1}] {new 0 targets 0}
# single into an EMPTY stack: exactly one strip is created and used
check "M3 single/0 strips creates exactly one" \
  [pcall {wviewer::plan_plot single 0 0 2}] {new 1 targets {0 0}}
# a stale target (strip deleted since) can never escape the range
check "M3 single clamps a stale high target" \
  [pcall {wviewer::plan_plot single 2 7 1}] {new 0 targets 1}
check "M3 single clamps a negative target" \
  [pcall {wviewer::plan_plot single 3 -2 1}] {new 0 targets 0}
# multi: one strip per signal, NEW strips inserted at the TOP, and the batch
# reads newest-first (last pick topmost). Targets are POST-insert indices: the
# new strips take 0..new-1 and everything already up slides down by `new`.
check "M3 multi/2 strips/3 signals inserts 3 on top, last pick topmost" \
  [pcall {wviewer::plan_plot multi 2 0 3}] {new 3 targets {2 1 0}}
check "M3 multi/0 strips/1 signal" \
  [pcall {wviewer::plan_plot multi 0 0 1}] {new 1 targets 0}
check "M3 multi ignores the target" \
  [pcall {wviewer::plan_plot multi 2 1 2}] {new 2 targets {1 0}}
# empty gesture creates nothing in either mode
check "M3 single/0 signals is a no-op"  [pcall {wviewer::plan_plot single 2 1 0}] {new 0 targets {}}
check "M3 multi/0 signals is a no-op"   [pcall {wviewer::plan_plot multi 2 1 0}]  {new 0 targets {}}
# the ASE auto-plot strip is NEVER a Direct-Plot landing site: it is cleared
# and rebuilt after every run, so traces put there would vanish (and item 13's
# "Direct-Plot graphs and the auto graph never touch each other" would break)
check "M3 single refuses to land in the auto strip -> appends one" \
  [pcall {wviewer::plan_plot single 1 0 2 0}] {new 1 targets {1 1}}
check "M3 single lands normally when the target is NOT the auto strip" \
  [pcall {wviewer::plan_plot single 2 1 1 0}] {new 0 targets 1}
check "M3 auto strip elsewhere in the stack does not disturb the plan" \
  [pcall {wviewer::plan_plot single 3 2 1 0}] {new 0 targets 2}
check "M3 multi ignores the auto strip too (never lands there)" \
  [pcall {wviewer::plan_plot multi 1 0 2 0}] {new 2 targets {1 0}}
# EMPTY-STRIP REUSE (issue 0171 follow-up): a strip with no traces is a place to
# plot, so a batch fills the empty ones (in index order) before appending. The
# 6th argument is that list (wviewer::empty_graph_indices); omitted = none, which
# is why every leg above still describes the pre-change behavior.
check "M3 multi reuses one empty strip, the rest go on top" \
  [pcall {wviewer::plan_plot multi 2 0 3 -1 {1}}] {new 2 targets {3 1 0}}
check "M3 multi fills empties too, still newest-first" \
  [pcall {wviewer::plan_plot multi 4 0 2 -1 {3 1}}] {new 0 targets {3 1}}
check "M3 multi with more empties than signals creates nothing" \
  [pcall {wviewer::plan_plot multi 3 0 1 -1 {0 2}}] {new 0 targets 0}
check "M3 multi: the Clear All shape (1 empty strip, 3 signals) - v3 on top" \
  [pcall {wviewer::plan_plot multi 1 0 3 -1 {0}}] {new 2 targets {2 1 0}}
check "M3 single reuses an empty strip instead of appending past the auto one" \
  [pcall {wviewer::plan_plot single 2 0 2 0 {1}}] {new 0 targets {1 1}}
check "M3 single still appends when the only free strip IS the auto one" \
  [pcall {wviewer::plan_plot single 1 0 2 0 {}}] {new 1 targets {1 1}}
check "M3 an explicit, usable target beats an empty strip elsewhere" \
  [pcall {wviewer::plan_plot single 3 2 1 -1 {0}}] {new 0 targets 2}
# the reusable set is sanitized: out-of-range, negative, non-integer, the auto
# strip and duplicates can never become landing sites
check "M3 out-of-range / bogus empties are ignored" \
  [pcall {wviewer::plan_plot multi 2 0 1 -1 {9 -1 x}}] {new 1 targets 0}
check "M3 the auto strip is never reusable even if listed" \
  [pcall {wviewer::plan_plot multi 2 0 1 1 {1}}] {new 1 targets 0}
check "M3 duplicate empties are deduped" \
  [pcall {wviewer::plan_plot multi 2 0 2 -1 {1 1}}] {new 1 targets {2 0}}

# --- M3b: which strips are reusable (wviewer::empty_graph_indices) -----------
proc m3_g {ntr} {
  set trs {}
  for {set i 0} {$i < $ntr} {incr i} { lappend trs [dict create expr v($i) color 4] }
  return [dict replace [wviewer::empty_graph] traces $trs]
}
check "M3b every strip empty" \
  [pcall {wviewer::empty_graph_indices [list [m3_g 0] [m3_g 0]]}] {0 1}
check "M3b strips with traces are not reusable" \
  [pcall {wviewer::empty_graph_indices [list [m3_g 1] [m3_g 0] [m3_g 2]]}] 1
check "M3b the auto strip is excluded even when empty" \
  [pcall {wviewer::empty_graph_indices [list [m3_g 0] [m3_g 0]] 0}] 1
check "M3b no strips at all" [pcall {wviewer::empty_graph_indices {}}] {}
rename m3_g {}

# --- M4: target clamp --------------------------------------------------------
check "M4 in-range target kept"        [pcall {wviewer::target_clamp 1 3}]  1
check "M4 too-high target clamped"     [pcall {wviewer::target_clamp 5 3}]  2
check "M4 negative target clamped"     [pcall {wviewer::target_clamp -1 3}] 0
check "M4 empty layout -> 0"           [pcall {wviewer::target_clamp 2 0}]  0
check "M4 non-integer target -> 0"     [pcall {wviewer::target_clamp x 3}]  0

# --- M5: the marker's prop token --------------------------------------------
set Gm [dict create traces [list [dict create expr {v(d)} name {} vec {v(d)} \
          color 4]] logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
set p_off [pcall {wviewer::graph_props $Gm}]
set p_on  [pcall {wviewer::graph_props $Gm 1}]
check_true "M5 default props carry NO active token" \
  [expr {![string match {*active=*} $p_off]}]
check_true "M5 active arg emits active=1" \
  [expr {[string match {*active=1*} $p_on]}]
check_true "M5 active props still carry flags=graph" \
  [expr {[string match {flags=graph*} $p_on]}]
check_true "M5 explicit 0 emits no active token" \
  [expr {![string match {*active=*} [pcall {wviewer::graph_props $Gm 0}]]}]

# --- M6: trace-color policy (issue 0153) ------------------------------------
# The reported defect: in MULTI-plot mode every trace came out the same
# yellow-green. Cause: the color cycle looked only at the LANDING graph's
# traces, and multi-plot gives each signal a brand-new EMPTY strip, so every
# signal got palette head 4. Single-plot stacks into one strip, so it cycled
# correctly — hence "different colors in single, all yellow in multi".
proc m6_g {colors} {
  set trs {}
  foreach c $colors {
    lappend trs [dict create expr {v(x)} name {} vec {v(x)} color $c]
  }
  return [dict create traces $trs logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
}
check "M6 palette head when nothing is used" [pcall {wviewer::first_unused_color {}}] 4
check "M6 first gap is taken, not the next index" \
  [pcall {wviewer::first_unused_color {4 7}}] 5
check "M6 exhausted palette falls back to count mod length (D10, unchanged)" \
  [pcall {wviewer::first_unused_color {4 5 7 8 9 12 14 15 10 11}}] 4
check "M6 graph_colors reads trace colors in order" \
  [pcall {wviewer::graph_colors [m6_g {7 4}]}] {7 4}
check "M6 graph_colors of an empty graph" [pcall {wviewer::graph_colors [m6_g {}]}] {}
check "M6 colors_in_graphs unions across strips and dedupes" \
  [pcall {wviewer::colors_in_graphs [list [m6_g {4 7}] [m6_g {7 5}]]}] {4 7 5}
check "M6 next_color is still per-graph (unchanged contract)" \
  [pcall {wviewer::next_color [m6_g {4 5}]}] 7

# single-plot: `used` is the LANDING strip only — unchanged behavior. Three
# signals into strip 0 of a 1-strip stack get three consecutive palette entries.
check "M6 plan_colors single: consecutive palette entries in one strip" \
  [pcall {wviewer::plan_colors [list [m6_g {}]] single {0 0 0}}] {4 5 7}
check "M6 plan_colors single: continues past what the strip already uses" \
  [pcall {wviewer::plan_colors [list [m6_g {4 5}]] single {0 0}}] {7 8}
check "M6 plan_colors single ignores OTHER strips (per-strip, as shipped)" \
  [pcall {wviewer::plan_colors [list [m6_g {}] [m6_g {4 5 7}]] single {0 0}}] {4 5}

# multi-plot: THE FIX. Each signal lands in its own new strip (indices past the
# end of the list), so per-strip `used` is empty for all of them; the window-wide
# seed is what makes them differ. Pre-fix this was {4 4 4}.
check "M6 plan_colors multi: distinct colors across new strips" \
  [pcall {wviewer::plan_colors [list [m6_g {}]] multi {1 2 3}}] {4 5 7}
check "M6 plan_colors multi: avoids colors already on screen" \
  [pcall {wviewer::plan_colors [list [m6_g {4}] [m6_g {5}]] multi {2 3}}] {7 8}
check "M6 plan_colors multi: colorless existing traces do not block the palette" \
  [pcall {wviewer::plan_colors [list [m6_g {{}}]] multi {1 2}}] {4 5}
check "M6 plan_colors of an empty batch" \
  [pcall {wviewer::plan_colors [list [m6_g {}]] multi {}}] {}
# prefix stability — what lets the picker resolve click k's color before click
# k+1 exists (dp_queue asks for the colors of the queue-so-far and takes the last)
set m6full [pcall {wviewer::plan_colors [list [m6_g {}]] multi {1 2 3 4}}]
check "M6 plan_colors multi is prefix-stable" \
  [pcall {wviewer::plan_colors [list [m6_g {}]] multi {1 2}}] [lrange $m6full 0 1]
set m6fs [pcall {wviewer::plan_colors [list [m6_g {}]] single {0 0 0 0}}]
check "M6 plan_colors single is prefix-stable" \
  [pcall {wviewer::plan_colors [list [m6_g {}]] single {0 0}}] [lrange $m6fs 0 1]
rename m6_g {}

# --- M7: strip drag reordering, the PURE half -------------------------------
# doc/claude/specs/waveform_viewer_modes.md §12. `to` is the FINAL index the
# moved strip occupies, which is NOT an insertion slot whenever the move goes
# downward — every caller and the replay log read it the first way, so it is
# pinned here with the spec's own worked example first.
check "M7 the spec example: A B C D, 1 -> 3" \
  [pcall {wviewer::reorder_graphs {A B C D} 1 3}] {A C D B}

# every meaningful from/to permutation of a four-element list, by construction:
# the moved element must land AT `to`, and the others must keep their relative
# order. Computing the expectation independently (filter + insert) keeps this
# from being a restatement of the implementation.
proc m7_expect {lst from to} {
  set el [lindex $lst $from]
  set rest {}
  set i 0
  foreach e $lst { if {$i != $from} { lappend rest $e }; incr i }
  return [linsert $rest $to $el]
}
set m7bad 0
set m7n 0
for {set f 0} {$f < 4} {incr f} {
  for {set t 0} {$t < 4} {incr t} {
    incr m7n
    set got [pcall {}]
    set got [wviewer::reorder_graphs {A B C D} $f $t]
    set exp [expr {$f == $t ? {A B C D} : [m7_expect {A B C D} $f $t]}]
    if {$got ne $exp} { incr m7bad; puts "  M7 mismatch $f->$t: {$got} != {$exp}" }
    # and the moved element really is at index `to`
    if {[lindex $got $t] ne [lindex {A B C D} $f]} { incr m7bad }
  }
}
check "M7 all 16 from/to permutations of a 4-strip list" [list $m7n $m7bad] {16 0}
rename m7_expect {}

check "M7 up by one"          [pcall {wviewer::reorder_graphs {A B C D} 2 1}] {A C B D}
check "M7 down by one"        [pcall {wviewer::reorder_graphs {A B C D} 1 2}] {A C B D}
check "M7 up by several"      [pcall {wviewer::reorder_graphs {A B C D} 3 1}] {A D B C}
check "M7 down by several"    [pcall {wviewer::reorder_graphs {A B C D} 0 3}] {B C D A}
check "M7 first to last"      [pcall {wviewer::reorder_graphs {A B C D} 0 3}] {B C D A}
check "M7 last to first"      [pcall {wviewer::reorder_graphs {A B C D} 3 0}] {D A B C}
check "M7 from == to is identity" [pcall {wviewer::reorder_graphs {A B C D} 2 2}] {A B C D}
check "M7 out-of-range from -> unchanged" \
  [pcall {wviewer::reorder_graphs {A B C D} 4 0}] {A B C D}
check "M7 out-of-range to -> unchanged" \
  [pcall {wviewer::reorder_graphs {A B C D} 0 9}] {A B C D}
check "M7 negative index -> unchanged" \
  [pcall {wviewer::reorder_graphs {A B C D} -1 2}] {A B C D}
check "M7 non-integer index -> unchanged" \
  [pcall {wviewer::reorder_graphs {A B C D} x 2}] {A B C D}
check "M7 empty list -> unchanged" [pcall {wviewer::reorder_graphs {} 0 0}] {}

# reordered_index: an index that named a graph BEFORE the move must name the
# SAME graph after it. Checked against the lists themselves, so it cannot drift
# from reorder_graphs.
set m7ri {}
foreach i {0 1 2 3} { lappend m7ri [pcall {wviewer::reordered_index $i 1 3}] }
check "M7 reordered_index for the moved graph (1 -> 3)" [lindex $m7ri 1] 3
check "M7 reordered_index for the graphs crossed by the move" \
  [list [lindex $m7ri 2] [lindex $m7ri 3]] {1 2}
check "M7 reordered_index for an unaffected graph" [lindex $m7ri 0] 0
set m7ri2 {}
foreach i {0 1 2 3} { lappend m7ri2 [pcall {wviewer::reordered_index $i 3 0}] }
check "M7 reordered_index, upward move (3 -> 0)" $m7ri2 {1 2 3 0}
check "M7 reordered_index is identity for from == to" \
  [pcall {wviewer::reordered_index 2 1 1}] 2
check "M7 reordered_index passes a non-integer through" \
  [pcall {wviewer::reordered_index x 1 3}] x
# exhaustive identity check: for every permutation, reordered_index must point
# at the element it pointed at before
set m7bad2 0
for {set f 0} {$f < 4} {incr f} {
  for {set t 0} {$t < 4} {incr t} {
    set moved [wviewer::reorder_graphs {A B C D} $f $t]
    for {set i 0} {$i < 4} {incr i} {
      set ni [wviewer::reordered_index $i $f $t]
      if {[lindex $moved $ni] ne [lindex {A B C D} $i]} { incr m7bad2 }
    }
  }
}
check "M7 reordered_index tracks IDENTITY across all permutations" $m7bad2 0

# the dictionary moves WHOLE: traces, their order, colors and the `auto 1`
# marker ride along untouched (the "do not reconstruct the graph field by
# field" contract)
set m7ga [dict merge [wviewer::empty_graph] [dict create auto 1]]
set m7gb [dict replace [wviewer::empty_graph] traces [list \
  [dict create expr {v(a)} name {} vec {v(a)} color 4] \
  [dict create expr {v(b)} name bee vec {v(b)} color 9]]]
set m7gc [wviewer::empty_graph]
set m7moved [pcall {wviewer::reorder_graphs [list $m7ga $m7gb $m7gc] 1 0}]
check "M7 the moved strip's dict is byte-identical" [lindex $m7moved 0] $m7gb
check "M7 trace order inside the moved strip is unchanged" \
  [list [dict get [lindex [dict get [lindex $m7moved 0] traces] 0] expr] \
        [dict get [lindex [dict get [lindex $m7moved 0] traces] 1] expr]] {v(a) v(b)}
check "M7 trace colors inside the moved strip are unchanged" \
  [pcall {wviewer::graph_colors [lindex $m7moved 0]}] {4 9}
proc m7_auto_at {gs} {
  set gi 0
  foreach G $gs {
    if {[wviewer::dget $G auto 0] eq {1}} { return $gi }
    incr gi
  }
  return -1
}
check "M7 `auto 1` stays on the SAME dict (now at index 1)" \
  [pcall {m7_auto_at $m7moved}] 1
check "M7 the auto strip's dict is byte-identical too" [lindex $m7moved 1] $m7ga
rename m7_auto_at {}

# the reorder handle: graph_props marks every viewer strip
set m7p [pcall {wviewer::graph_props [wviewer::empty_graph]}]
check_true "M7 graph_props emits reorder_handle=1" \
  [regexp -line {^reorder_handle=1$} $m7p]
# hilight_wave round-trips only when the model carries it (absent stays absent)
check_true "M7 graph_props omits hilight_wave when the model has none" \
  [expr {![string match {*hilight_wave*} $m7p]}]
check_true "M7 graph_props emits a captured hilight_wave" \
  [regexp -line {^hilight_wave=2$} \
    [pcall {wviewer::graph_props [dict replace [wviewer::empty_graph] hilight_wave 2]}]]

# --- M8: dragging a TRACE between strips, the PURE half ----------------------
# doc/claude/specs/waveform_viewer_modes.md §13. The model op is "remove the
# trace dict from the source, append it to the destination" — the strip list and
# the strip order never change. The subtle half is `hilight_wave`: it is stored
# per graph in the C engine's NODE index space (position in the `node` prop
# token), so BOTH graphs' values shift when a trace crosses.
proc m8_tr {vec {color 4} {name {}}} {
  return [dict create expr $vec name $name vec $vec color $color]
}
proc m8_g {args} {
  set trs {}
  foreach v $args { lappend trs [m8_tr $v] }
  return [dict replace [wviewer::empty_graph] traces $trs]
}
# vec list per strip, the compact witness used below
proc m8_vecs {gs} {
  set out {}
  foreach G $gs {
    set v {}
    foreach tr [wviewer::dget $G traces {}] { lappend v [wviewer::dget $tr vec {}] }
    lappend out $v
  }
  return $out
}

set m8base [list [m8_g v(a) v(b) v(c)] [m8_g v(x)]]
check "M8 first trace of the source moves" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 0 1]}] {{v(b) v(c)} {v(x) v(a)}}
check "M8 middle trace of the source moves" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 1 1]}] {{v(a) v(c)} {v(x) v(b)}}
check "M8 last trace of the source moves" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 2 1]}] {{v(a) v(b)} {v(x) v(c)}}
check "M8 the destination always APPENDS (never inserts)" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs \
     [wviewer::move_trace_in_graphs $m8base 0 0 1] 0 0 1]}] {v(c) {v(x) v(a) v(b)}}
check "M8 upward move (strip 1 -> strip 0) works the same" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 1 0 0]}] {{v(a) v(b) v(c) v(x)} {}}
check "M8 a single-trace source is left EMPTY, never deleted" \
  [pcall {llength [wviewer::move_trace_in_graphs $m8base 1 0 0]}] 2
check "M8 three strips: the untouched one is not disturbed" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs \
     [list [m8_g v(a)] [m8_g v(m)] [m8_g v(z)]] 0 0 2]}] {{} v(m) {v(z) v(a)}}

# the trace DICTIONARY is carried whole — expression, alias, vector and color
set m8rich [list [dict replace [wviewer::empty_graph] traces [list \
    [m8_tr {v(a)} 4] \
    [dict create expr {v(out) 2 *} name doubled vec expr1 color 12]]] \
  [wviewer::empty_graph]]
set m8moved [pcall {wviewer::move_trace_in_graphs $m8rich 0 1 1}]
check "M8 the moved trace dict is byte-identical" \
  [lindex [dict get [lindex $m8moved 1] traces] 0] \
  [lindex [dict get [lindex $m8rich 0] traces] 1]
check "M8 ... which means expr/name/vec/color all survived" \
  [list [dict get [lindex [dict get [lindex $m8moved 1] traces] 0] expr] \
        [dict get [lindex [dict get [lindex $m8moved 1] traces] 0] name] \
        [dict get [lindex [dict get [lindex $m8moved 1] traces] 0] vec] \
        [dict get [lindex [dict get [lindex $m8moved 1] traces] 0] color]] \
  {{v(out) 2 *} doubled expr1 12}
check "M8 the destination's OTHER keys (axes, logx) are untouched" \
  [dict get [lindex $m8moved 1] logx] [dict get [lindex $m8rich 1] logx]
# an EMPTY destination goes back to `auto` ranges, so the dropped trace is
# actually visible (regenerate re-autozooms a blank range); a destination that
# already holds traces keeps the ranges the user is looking at
set m8rng [list [m8_g v(a)] [dict replace [m8_g] x1 0 x2 1 y1 -1 y2 5]]
set m8rngd [lindex [pcall {wviewer::move_trace_in_graphs $m8rng 0 0 1}] 1]
check "M8 an empty destination's ranges are blanked (auto-zoom on drop)" \
  [list [dict get $m8rngd x1] [dict get $m8rngd x2] \
        [dict get $m8rngd y1] [dict get $m8rngd y2]] {{} {} {} {}}
set m8rng2 [list [m8_g v(a)] [dict replace [m8_g v(k)] x1 0 x2 1 y1 -1 y2 5]]
set m8rngd2 [lindex [pcall {wviewer::move_trace_in_graphs $m8rng2 0 0 1}] 1]
check "M8 a destination that already has traces keeps its ranges" \
  [list [dict get $m8rngd2 x1] [dict get $m8rngd2 x2] \
        [dict get $m8rngd2 y1] [dict get $m8rngd2 y2]] {0 1 -1 5}
check "M8 the SOURCE's ranges are never touched" \
  [dict get [lindex [pcall {wviewer::move_trace_in_graphs \
     [list [dict replace [m8_g v(a) v(b)] y2 9] [m8_g]] 0 0 1}] 0] y2] 9

check "M8 a duplicate landing in the destination is allowed" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs \
     [list [m8_g v(a)] [m8_g v(a)]] 0 0 1]}] {{} {v(a) v(a)}}

# refusals (a pure list op has no error channel: refuse == return unchanged)
check "M8 same-strip move is a no-op" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 1 0]}] [m8_vecs $m8base]
check "M8 out-of-range source strip -> unchanged" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 5 0 1]}] [m8_vecs $m8base]
check "M8 out-of-range destination strip -> unchanged" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 0 7]}] [m8_vecs $m8base]
check "M8 out-of-range trace index -> unchanged" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 9 1]}] [m8_vecs $m8base]
check "M8 negative trace index -> unchanged" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 -1 1]}] [m8_vecs $m8base]
check "M8 non-integer index -> unchanged" \
  [pcall {m8_vecs [wviewer::move_trace_in_graphs $m8base 0 x 1]}] [m8_vecs $m8base]
check "M8 empty strip list -> unchanged" \
  [pcall {wviewer::move_trace_in_graphs {} 0 0 1}] {}

# model index <-> NODE index. They differ only for a trace with an empty `vec`,
# which graph_props SKIPS when it writes the `node` token — so such a trace
# occupies a model slot and no node slot.
set m8gap [dict replace [wviewer::empty_graph] traces [list \
  [m8_tr {v(a)}] [dict create expr {} name {} vec {} color 4] [m8_tr {v(c)}]]]
check "M8 node_count ignores vec-less traces" [pcall {wviewer::node_count $m8gap}] 2
check "M8 node_index_of_trace skips the vec-less trace" \
  [list [pcall {wviewer::node_index_of_trace $m8gap 0}] \
        [pcall {wviewer::node_index_of_trace $m8gap 2}]] {0 1}
check "M8 node_index_of_trace of a vec-less trace is -1" \
  [pcall {wviewer::node_index_of_trace $m8gap 1}] -1
check "M8 node_index_of_trace out of range is -1" \
  [pcall {wviewer::node_index_of_trace $m8gap 9}] -1
check "M8 trace_index_of_node is the exact inverse" \
  [list [pcall {wviewer::trace_index_of_node $m8gap 0}] \
        [pcall {wviewer::trace_index_of_node $m8gap 1}]] {0 2}
check "M8 trace_index_of_node past the end is -1" \
  [pcall {wviewer::trace_index_of_node $m8gap 2}] -1
check "M8 trace_index_of_node of garbage is -1" \
  [pcall {wviewer::trace_index_of_node $m8gap x}] -1
# round trip on a plain graph: node index == model index
set m8rt 0
for {set i 0} {$i < 3} {incr i} {
  set G [m8_g v(a) v(b) v(c)]
  if {[wviewer::trace_index_of_node $G [wviewer::node_index_of_trace $G $i]] != $i} {
    incr m8rt
  }
}
check "M8 index round-trip on a gap-free strip" $m8rt 0

# hilight_wave (the C-written BOLD marker) remapping
check "M8 a bold trace BELOW the moved one keeps its index" \
  [pcall {wviewer::remap_hilight_after_trace_move 0 2}] 0
check "M8 a bold trace ABOVE the moved one shifts down by one" \
  [pcall {wviewer::remap_hilight_after_trace_move 2 0}] 1
check "M8 the bold trace itself moving clears the source highlight" \
  [pcall {wviewer::remap_hilight_after_trace_move 1 1}] {}
check "M8 no highlight stays no highlight" \
  [pcall {wviewer::remap_hilight_after_trace_move {} 1}] {}
check "M8 a vec-less move (-1) leaves the highlight alone" \
  [pcall {wviewer::remap_hilight_after_trace_move 2 -1}] 2

set m8hl [list [dict replace [m8_g v(a) v(b) v(c)] hilight_wave 2] \
               [dict replace [m8_g v(x)] hilight_wave 0]]
set m8r [pcall {wviewer::move_trace_in_graphs $m8hl 0 0 1}]
check "M8 moving a trace above the bold one decrements the source's marker" \
  [dict get [lindex $m8r 0] hilight_wave] 1
check "M8 ... and the destination's unrelated highlight is preserved" \
  [dict get [lindex $m8r 1] hilight_wave] 0
set m8r2 [pcall {wviewer::move_trace_in_graphs $m8hl 0 2 1}]
check "M8 moving the BOLD trace clears the source marker" \
  [dict exists [lindex $m8r2 0] hilight_wave] 0
# ⚠ ISSUE 0175 CHANGED THIS. The selection is a SET now, so the migrating trace
# is ADDED to whatever the destination already had selected instead of replacing
# it — this fixture's destination carries an unrelated highlight at node 0, and
# the leg above ("the destination's unrelated highlight is preserved") already
# says that highlight has no reason to die. It survives here too, and the
# migrating trace joins it at node 1. `hilight_wave` is the HEAD of the set.
check "M8 ... and the destination picks it up at its new node index (0175: as a SET)" \
  [wviewer::model_sel [lindex $m8r2 1]] {0 1}
check "M8 ... with hilight_wave as the head, so an older build still bolds one" \
  [dict get [lindex $m8r2 1] hilight_wave] 0
check "M8 ... and sel_waves carries the pair" \
  [dict get [lindex $m8r2 1] sel_waves] {0 1}
# teeth: a destination with NO highlight of its own gets exactly the one trace,
# and no sel_waves key at all — so "always adds a second entry" cannot pass
set m8r2b [pcall {wviewer::move_trace_in_graphs \
  [list [dict replace [m8_g v(a) v(b) v(c)] hilight_wave 2] [m8_g v(x)]] 0 2 1}]
check "M8 ... a destination with nothing selected gets just the migrant" \
  [list [dict get [lindex $m8r2b 1] hilight_wave] \
        [dict exists [lindex $m8r2b 1] sel_waves]] {1 0}
set m8r3 [pcall {wviewer::move_trace_in_graphs \
  [list [m8_g v(a) v(b)] [m8_g v(x)]] 0 0 1}]
check "M8 a source with no marker never gains one, and neither does the dest" \
  [list [dict exists [lindex $m8r3 0] hilight_wave] \
        [dict exists [lindex $m8r3 1] hilight_wave]] {0 0}

rename m8_tr {}
rename m8_g {}
rename m8_vecs {}

# --- DT: deleting traces and strips, the PURE half (issue 0176) --------------
# doc/claude/issues/0176-del-deletes-selection.md. `wviewer::delete_in_graphs`
# is the body lifted out of the Delete dialog's OK button so the DEL key can
# reach it too. It is the whole index story of a trace delete, and it is the
# half that CAN be asserted in BOTH arms — the command layer on top of it
# (`delete_items`) ends in a `regenerate`, i.e. `winfo`, so it is DISPLAY-only
# and lives in test_wave_markers.tcl's MQ group (landmine 41's split, applied to
# Tk rather than to has_x). A leg written the other way round would assert the
# pre-mutation state and pass for the wrong reason.
#
# Three consequences per deleted trace, and every one of them has a leg:
#   1. a marker ON the doomed trace is DROPPED
#   2. markers and SELECTED nodes above the hole shift DOWN
#   3. the dropped NUMBERS come back in `gone` for the caller's window-wide sweep
proc dt_tr {v} { return [dict create expr $v name {} vec $v color 4] }
proc dt_g {args} {
  set trs {}
  foreach v $args { lappend trs [dt_tr $v] }
  return [dict replace [wviewer::empty_graph] traces $trs]
}
proc dt_vecs {G} {
  set out {}
  foreach tr [wviewer::dget $G traces {}] { lappend out [wviewer::dget $tr vec ?] }
  return $out
}
proc dt_rec {num wave {prev 0}} { return "$num $wave 0 3 0.3 1.3 $prev 0.06 -0.09" }

# strip 0: a b c (nodes 0 1 2) with markers 1@node1 and 3@node2;
# strip 1: x     (node 0)      with marker  2@node0, prev = 1 (a cross-strip delta)
set dtbase [list \
  [dict replace [dt_g v(a) v(b) v(c)] markers "[dt_rec 1 1]\n[dt_rec 3 2]"] \
  [dict replace [dt_g v(x)] markers [dt_rec 2 0 1]]]

check "DT1 nothing to delete returns the list UNCHANGED and no gone numbers" \
  [pcall {wviewer::delete_in_graphs $dtbase {} [dict create]}] [list $dtbase {}]

set dt2 [pcall {wviewer::delete_in_graphs $dtbase {} [dict create 0 {1}]}]
check "DT2 the doomed trace leaves, its neighbours do not" \
  [pcall {dt_vecs [lindex [lindex $dt2 0] 0]}] {v(a) v(c)}
check "DT2 CASCADE: the marker ON it is dropped, the one above it survives" \
  [pcall {wviewer::markers_numbers [dict get [lindex [lindex $dt2 0] 0] markers]}] 3
check "DT2 SURVIVOR REMAP: that marker's wave shifted 2 -> 1" \
  [pcall {lindex [split [dict get [lindex [lindex $dt2 0] 0] markers] { }] 1}] 1
check "DT2 the dropped NUMBER comes back for the window-wide sweep" \
  [lindex $dt2 1] 1
check "DT2 the OTHER strip is untouched by this proc (the sweep is the caller's)" \
  [pcall {list [dt_vecs [lindex [lindex $dt2 0] 1]] \
               [dict get [lindex [lindex $dt2 0] 1] markers]}] \
  [list {v(x)} [dt_rec 2 0 1]]
check "DT2 ... and markers_sweep_numbers is what zeroes the dangling prev" \
  [pcall {dict get [lindex [wviewer::markers_sweep_numbers \
            [lindex $dt2 0] [lindex $dt2 1]] 1] markers}] [dt_rec 2 0 0]

# deleting the LAST marker-carrying trace must remove the key, not leave ""
set dt3 [pcall {wviewer::delete_in_graphs $dtbase {} [dict create 0 {1 2}]}]
check "DT3 two traces go in one call, highest index first (no off-by-one)" \
  [pcall {dt_vecs [lindex [lindex $dt3 0] 0]}] {v(a)}
check "DT3 absent-means-absent: an emptied token drops the KEY" \
  [pcall {dict exists [lindex [lindex $dt3 0] 0] markers}] 0
check "DT3 both numbers are reported gone" [lsort -integer [lindex $dt3 1]] {1 3}

# a WHOLE strip: its markers are all `gone`, and it leaves the list
set dt4 [pcall {wviewer::delete_in_graphs $dtbase {1} [dict create]}]
check "DT4 the strip is removed" [llength [lindex $dt4 0]] 1
check "DT4 ... and its marker number is reported gone" [lindex $dt4 1] 2

# the SELECTION (issue 0175) is a SET and is remapped per element
set dtsel [list [wviewer::model_sel_set [dt_g v(a) v(b) v(c)] {0 2}] [dt_g v(x)]]
set dt5 [pcall {wviewer::delete_in_graphs $dtsel {} [dict create 0 {1}]}]
check "DT5 a selected node ABOVE the hole shifts down, the one below does not" \
  [pcall {wviewer::model_sel [lindex [lindex $dt5 0] 0]}] {0 1}
set dt6 [pcall {wviewer::delete_in_graphs $dtsel {} [dict create 0 {0}]}]
check "DT6 a SELECTED trace that dies simply leaves the set" \
  [pcall {wviewer::model_sel [lindex [lindex $dt6 0] 0]}] 1
check "DT6 ... and a one-element set drops sel_waves (pre-0175 byte identity)" \
  [pcall {dict exists [lindex [lindex $dt6 0] 0] sel_waves}] 0
set dt7 [pcall {wviewer::delete_in_graphs $dtsel {} [dict create 0 {0 2}]}]
check "DT7 an emptied selection drops BOTH keys rather than storing -1" \
  [pcall {list [dict exists [lindex [lindex $dt7 0] 0] hilight_wave] \
               [dict exists [lindex [lindex $dt7 0] 0] sel_waves]}] {0 0}

# landmine 34: a vec-less trace occupies a MODEL slot and NO node slot, so the
# two index spaces differ and the marker remap must use the node one
set dtnv [list [dict replace [wviewer::empty_graph] traces \
            [list [dt_tr v(a)] [dict create expr {} name {} vec {} color 4] \
                  [dt_tr v(b)]] markers [dt_rec 1 1]]]
check "DT8 a vec-less trace occupies no node slot (v(b) is node 1, model 2)" \
  [pcall {list [wviewer::node_index_of_trace [lindex $dtnv 0] 2] \
               [wviewer::node_index_of_trace [lindex $dtnv 0] 0]}] {1 0}
set dt8 [pcall {wviewer::delete_in_graphs $dtnv {} [dict create 0 {1}]}]
check "DT8 deleting the VEC-LESS trace shifts no marker (it was never a node)" \
  [pcall {dict get [lindex [lindex $dt8 0] 0] markers}] [dt_rec 1 1]
set dt9 [pcall {wviewer::delete_in_graphs $dtnv {} [dict create 0 {2}]}]
check "DT9 deleting MODEL trace 2 drops the marker on NODE 1, not on node 2" \
  [pcall {dict exists [lindex [lindex $dt9 0] 0] markers}] 0

# a graph with no markers must never GAIN the key
set dt10 [pcall {wviewer::delete_in_graphs [list [dt_g v(a) v(b)]] {} [dict create 0 {0}]}]
check "DT10 a marker-free graph never gains a markers key" \
  [pcall {list [dict exists [lindex [lindex $dt10 0] 0] markers] [lindex $dt10 1]}] {0 {}}

foreach dtp {dt_tr dt_g dt_vecs dt_rec} { rename $dtp {} }

# --- M9: the context-loan TICKET (issue 0173) --------------------------------
# wviewer::enter_ctx / wviewer::leave_ctx are the save/restore bracket every
# viewer-side READ goes through so that switching INTO a viewer stops being a
# one-way move. These shapes need no window and no DISPLAY; the legs that need a
# real switch (and a real title to clobber) are MG17, and they are DISPLAY-only
# on purpose — set_modify's title rewrite is `has_x`-gated.
check "M9 an unknown token yields a REFUSED ticket, with nothing to restore" \
  [pcall {wviewer::enter_ctx no/such/token}] {0 {}}
check "M9 a nothing-to-restore ticket makes leave_ctx a successful no-op" \
  [pcall {wviewer::leave_ctx no/such/token {1 {}}}] 1
# ... and specifically it must not "helpfully" retitle: on that path no switch
# happened, so no title was clobbered, and a repair would hide a real leak from
# the MG17 spy.
set ::m9_retitle 0
rename wviewer::retitle wviewer::__m9_real_retitle
proc wviewer::retitle {token} { incr ::m9_retitle }
pcall {wviewer::leave_ctx no/such/token {1 {}}}
check "M9 a no-op restore does not touch the title either" $::m9_retitle 0
rename wviewer::retitle {}
rename wviewer::__m9_real_retitle wviewer::retitle

# ============================================================================
# GUI legs
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

  # session registration (headless-style: no ASE window needed for the viewer).
  # dc is enabled so ase::plot_sim_type is `dc`, not `op` — dp_finish aborts on
  # op-only results, and MG12 drives the REAL dp_finish path.
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set an {}
  foreach a [dict get $st analyses] {
    if {[dict get $a type] eq {dc}} {
      set a [dict create type dc enabled 1 source V2 start 0 stop 1.8 step 0.01]
    }
    lappend an $a
  }
  dict set st analyses $an
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  # --- MG1: fresh window -> config default, target 0 -------------------------
  check "MG1 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: MG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {
  check "MG1 fresh viewer is in the shipped default mode" \
    [pcall {wviewer::plot_mode $tok}] single
  check "MG1 fresh viewer targets strip 0" [pcall {wviewer::target_strip $tok}] 0
  xschem new_schematic switch $vdrw
  check "MG1 current_token resolves the active viewer window" \
    [pcall {wviewer::current_token}] $tok
  check "MG1 omitted-token get uses the active window" \
    [pcall {wviewer::plot_mode}] single
  check "MG1 unknown token -> {} (no throw)" \
    [pcall {wviewer::plot_mode no/such/token}] {}

  # --- MG2: the config var seeds a NEW window only ---------------------------
  catch {wviewer::close $tok}; update
  set save_cfg2 $::wviewer_plot_mode
  set ::wviewer_plot_mode multi
  check "MG2 reopen returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG2 new window inherits the config var" [pcall {wviewer::plot_mode $tok}] multi
  set ::wviewer_plot_mode $save_cfg2
  check "MG2 changing the config var does NOT touch the open window" \
    [pcall {wviewer::plot_mode $tok}] multi

  # --- MG3: set/invert + replayable logging ----------------------------------
  # spy on the log seam (the slickprop::log_apply pattern)
  set ::wvm_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wvm_log $line }

  check "MG3 explicit set returns the resolved mode" \
    [pcall {wviewer::set_plot_mode single $tok}] single
  check "MG3 mode actually changed" [pcall {wviewer::plot_mode $tok}] single
  check "MG3 the change is logged replayably (resolved, explicit token)" \
    [lindex $::wvm_log end] "wviewer::set_plot_mode single $tok"
  set nlog [llength $::wvm_log]
  check "MG3 setting the SAME mode is a no-op" \
    [pcall {wviewer::set_plot_mode single $tok}] single
  check "MG3 no log line for a no-op" [llength $::wvm_log] $nlog
  check "MG3 invert flips it" [pcall {wviewer::set_plot_mode invert $tok}] multi
  check "MG3 invert logs the RESOLVED word, never 'invert'" \
    [lindex $::wvm_log end] "wviewer::set_plot_mode multi $tok"
  check "MG3 garbage is refused" [pcall {wviewer::set_plot_mode bogus $tok}] {}
  check "MG3 garbage left the mode alone" [pcall {wviewer::plot_mode $tok}] multi
  xschem new_schematic switch $vdrw
  check "MG3 omitted token targets the active window" \
    [pcall {wviewer::set_plot_mode single}] single

  # --- MG4: Options > Plot Mode menu -----------------------------------------
  set mb $vtop.wvmenubar
  set labels {}
  for {set i 0} {$i <= [$mb index end]} {incr i} {
    catch {lappend labels [$mb entrycget $i -label]}
  }
  check_true "MG4 menubar carries an Options cascade" \
    [expr {[lsearch -exact $labels Options] >= 0}]
  check_true "MG4 Plot Mode submenu exists" [winfo exists $mb.options.plotmode]
  # dynamic label: single -> offers Multi
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::plot_mode_menu_post $tok $mb.options.plotmode}
  check "MG4 label offers the OTHER mode (single -> Multi)" \
    [$mb.options.plotmode entrycget 0 -label] {Set Multi-plot Mode}
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::plot_mode_menu_post $tok $mb.options.plotmode}
  check "MG4 label flips with the mode (multi -> Single)" \
    [$mb.options.plotmode entrycget 0 -label] {Set Single-plot Mode}
  # invoking the entry performs the change AND logs it
  set nlog [llength $::wvm_log]
  $mb.options.plotmode invoke 0
  check "MG4 invoking the entry flips the mode" [pcall {wviewer::plot_mode $tok}] single
  check "MG4 the menu change is logged replayably" \
    [lindex $::wvm_log end] "wviewer::set_plot_mode single $tok"
  check_true "MG4 exactly one line logged per menu use" \
    [expr {[llength $::wvm_log] == $nlog + 1}]

  # --- MG5: single-plot landing ----------------------------------------------
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_target_strip 1 $tok}
  set errs [pcall {wviewer::plot_signals $tok {v(a) v(b) v(c)}}]
  check "MG5 no per-signal errors" $errs {}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5 single-plot created NO new strip" [llength $gs] 2
  check "MG5 all three traces landed in the target strip" \
    [llength [dict get [lindex $gs 1] traces]] 3
  check "MG5 the non-target strip is untouched" \
    [llength [dict get [lindex $gs 0] traces]] 0
  check "MG5 target strip unchanged by the plot" [pcall {wviewer::target_strip $tok}] 1
  # append, never replace (D1)
  pcall {wviewer::plot_signals $tok {v(d)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5 a second gesture APPENDS (never replaces)" \
    [llength [dict get [lindex $gs 1] traces]] 4

  # --- MG5b: single-plot never lands in the ASE auto-plot strip --------------
  # (the auto graph is rebuilt after every run — landing there loses the picks)
  wviewer::set_graphs $tok [list [dict merge [wviewer::empty_graph] {auto 1}]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  check "MG5b the only strip IS the auto strip" [pcall {wviewer::auto_graph_index $tok}] 0
  pcall {wviewer::plot_signals $tok {v(p) v(q)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5b a NEW strip was appended instead" [llength $gs] 2
  check "MG5b the auto strip is untouched" \
    [llength [dict get [lindex $gs 0] traces]] 0
  check "MG5b both signals landed in the new strip" \
    [llength [dict get [lindex $gs 1] traces]] 2
  check "MG5b the created strip became the target" [pcall {wviewer::target_strip $tok}] 1
  check "MG5b a follow-up gesture reuses it (no second strip)" \
    [llength [lindex [pcall {wviewer::plot_signals $tok {v(r)}}] 0]] 0
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5b still exactly two strips" [llength $gs] 2
  check "MG5b follow-up appended into the same strip" \
    [llength [dict get [lindex $gs 1] traces]] 3

  # --- MG6: multi-plot landing -----------------------------------------------
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::add_trace $tok 0 {v(keep)}}
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  set errs [pcall {wviewer::plot_signals $tok {v(x) v(y)}}]
  check "MG6 no per-signal errors" $errs {}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  # CONTRACT (issue 0171 follow-up + the 2026-07-27 order request): multi-plot
  # REUSES empty strips, puts the strips it must create at the TOP, and lays the
  # batch out newest-first. Fixture: strip 0 holds v(keep), strip 1 is empty. So
  # v(x) reuses the empty strip and v(y) gets a new TOP strip:
  #   0 = v(y) (last pick, newest)   1 = v(keep) (pushed down)   2 = v(x)
  check "MG6 one strip per signal: 1 reused + 1 created" [llength $gs] 3
  check "MG6 the LAST pick is on top" \
    [dict get [lindex [dict get [lindex $gs 0] traces] 0] expr] {v(y)}
  check "MG6 the pre-existing strip slid down, untouched" \
    [dict get [lindex [dict get [lindex $gs 1] traces] 0] expr] {v(keep)}
  check "MG6 the first pick sits in the reused empty strip, at the bottom" \
    [dict get [lindex [dict get [lindex $gs 2] traces] 0] expr] {v(x)}
  check "MG6 every landing strip holds exactly one trace" \
    [list [llength [dict get [lindex $gs 0] traces]] \
          [llength [dict get [lindex $gs 2] traces]]] {1 1}
  # the target still names the SAME strip it named before the insert (it was
  # strip 0 = v(keep), which is now strip 1) — multi-plot never RE-targets, but
  # inserting on top renumbers, and the marker must not drift to another strip
  check "MG6 the target follows its strip through the insert" \
    [pcall {wviewer::target_strip $tok}] 1
  # with no empty strip left, a further pick creates its strip on top
  pcall {wviewer::plot_signals $tok {v(z)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG6 nothing empty left -> a new TOP strip" [llength $gs] 4
  check "MG6 the new strip is strip 0" \
    [dict get [lindex [dict get [lindex $gs 0] traces] 0] expr] {v(z)}
  check "MG6 and the target followed again" [pcall {wviewer::target_strip $tok}] 2

  # --- MG6c: the reported defect, end to end (issue 0153) --------------------
  # Drive plot_signals in MULTI mode with no explicit colors and read the colors
  # back out of the MODEL. Pre-fix every one of them was 4 (each signal gets a
  # fresh empty strip, and the cycle only looked at that strip) — this is the
  # leg with teeth for the multi-plot half of the issue.
  proc mg_colors {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      foreach tr [dict get $G traces] { lappend out [dict get $tr color] }
    }
    return $out
  }
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::plot_signals $tok {v(m1) v(m2) v(m3)}}
  set mgc [pcall {mg_colors $tok}]
  check "MG6c multi-plot assigned 3 colors" [llength $mgc] 3
  check "MG6c multi-plot colors are all DIFFERENT" \
    [llength [lsort -unique $mgc]] 3
  # colors are handed out in PICK order (4 5 7); the strips read newest-first
  # since 2026-07-27, so walking the model top-down yields them reversed
  check "MG6c palette head onwards, in pick order (model reads newest-first)" \
    $mgc {7 5 4}

  # a SECOND multi gesture must not restart the cycle over colors already up
  pcall {wviewer::plot_signals $tok {v(m4)}}
  set mgc2 [pcall {mg_colors $tok}]
  check "MG6c a later gesture keeps going, no reuse" [llength [lsort -unique $mgc2]] 4

  # single-plot stays as shipped: one strip, cycling within it
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {wviewer::plot_signals $tok {v(s1) v(s2) v(s3)}}
  check "MG6c single-plot still cycles (unchanged)" [pcall {mg_colors $tok}] {4 5 7}

  # explicit colors win over the cycle (the picker's channel)
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::plot_signals $tok {v(e1) v(e2)} {12 9}}
  check "MG6c explicit colors are honored verbatim" [pcall {mg_colors $tok}] {12 9}
  check "MG6c add_trace honors an explicit color too" \
    [pcall {wviewer::add_trace $tok 0 {v(e3)} {} 14}] {}
  check "MG6c ... and stored it" [lindex [pcall {mg_colors $tok}] end] 14

  # --- MG6d: predict_colors == what plot_signals then assigns ---------------
  # The picker paints the schematic from predict_colors BEFORE the plot happens;
  # if the two ever diverged the wire and its trace would disagree. Asserted for
  # both modes, against the live window state.
  # the color of signal k must be compared BY SIGNAL, not by walking the model:
  # multi-plot lays a batch out newest-first, so model order != pick order
  proc mg_color_of {tok ex} {
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      foreach tr [dict get $G traces] {
        if {[dict get $tr expr] eq $ex} { return [dict get $tr color] }
      }
    }
    return {}
  }
  foreach m {single multi} {
    wviewer::set_graphs $tok [list [wviewer::empty_graph]]
    wviewer::regenerate $tok
    pcall {wviewer::set_plot_mode $m $tok}
    pcall {wviewer::set_target_strip 0 $tok}
    set pre [pcall {wviewer::predict_colors $tok 3}]
    pcall {wviewer::plot_signals $tok {v(p1) v(p2) v(p3)}}
    set got {}
    foreach ex {v(p1) v(p2) v(p3)} { lappend got [pcall {mg_color_of $tok $ex}] }
    check "MG6d $m predicted colors == assigned colors (per signal)" $pre $got
    check_true "MG6d $m predicted 3 distinct colors" \
      [expr {[llength [lsort -unique $pre]] == 3}]
  }
  rename mg_color_of {}
  check "MG6d predict_colors 0 signals -> {}" [pcall {wviewer::predict_colors $tok 0}] {}
  check "MG6d predict_colors rejects a non-number" \
    [pcall {wviewer::predict_colors $tok x}] {}
  rename mg_colors {}

  # --- MG7: click re-targets the strip ---------------------------------------
  check_true "MG7 <ButtonPress-1> is bound on the viewer canvas" \
    [expr {[string trim [bind $vdrw <ButtonPress-1>]] ne {}}]
  check_true "MG7 the click bind still forwards the press to the C engine" \
    [string match {*xschem callback*} [bind $vdrw <ButtonPress-1>]]
  check_true "MG7 the click bind calls the re-target seam" \
    [string match {*wviewer::click_target*} [bind $vdrw <ButtonPress-1>]]
  # explicit 4-strip fixture: the click math below needs a KNOWN band count, and
  # what the preceding legs leave standing depends on the landing policy (the
  # 0171 follow-up made multi-plot reuse empty strips, which changed the count
  # this used to inherit).
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph] \
                                 [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_target_strip 0 $tok}
  # band 2 spans the 3rd quarter of the canvas
  set H [winfo height $vdrw]
  set W [winfo width $vdrw]
  set y2 [expr {int($H * 5 / 8.0)}]     ;# inside band 2 of 4
  set y0 [expr {int($H * 1 / 8.0)}]     ;# inside band 0 of 4
  pcall {wviewer::click_target $vdrw [expr {$W/2}] $y2}
  check "MG7 clicking band 2 makes it the target" [pcall {wviewer::target_strip $tok}] 2
  pcall {wviewer::click_target $vdrw [expr {$W/2}] $y0}
  check "MG7 clicking band 0 moves the target back" [pcall {wviewer::target_strip $tok}] 0
  # the real Tk event, through the shipped binding
  event generate $vdrw <ButtonPress-1> -x [expr {$W/2}] -y $y2
  update
  check "MG7 a real ButtonPress-1 re-targets through the binding" \
    [pcall {wviewer::target_strip $tok}] 2
  event generate $vdrw <ButtonRelease-1> -x [expr {$W/2}] -y $y2
  update
  # target moves are replayable too
  set nlog [llength $::wvm_log]
  pcall {wviewer::set_target_strip 3 $tok}
  check "MG7 an explicit target move is logged" \
    [lindex $::wvm_log end] "wviewer::set_target_strip 3 $tok"
  pcall {wviewer::set_target_strip 3 $tok}
  check "MG7 no log line when the target does not move" \
    [llength $::wvm_log] [expr {$nlog + 1}]
  check "MG7 a stale target is clamped on read" \
    [pcall {wviewer::set_target_strip 99 $tok}] 3

  # --- MG7b: a re-target must NOT discard C-engine-written graph state --------
  # The C engine writes RMB box-zoom / graph-pan ranges STRAIGHT into the rect
  # prop; the Tcl model never sees them. Moving the marker by regenerate (which
  # re-places every rect from the model) would silently undo the zoom the user
  # just made with the mouse. Simulated here by writing the rect directly,
  # exactly as waves_callback does, then re-targeting.
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_target_strip 0 $tok}
  wviewer::with_edit $tok {
    xschem setprop -fast rect 2 0 x1 3
    xschem setprop -fast rect 2 0 x2 4
  }
  xschem new_schematic switch $vdrw
  check "MG7b engine-written range is on the rect" \
    [list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]] {3 4}
  pcall {wviewer::set_target_strip 1 $tok}
  xschem new_schematic switch $vdrw
  check "MG7b the re-target PRESERVED it (no model-only regenerate)" \
    [list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]] {3 4}
  check "MG7b the marker still moved to the new target" \
    [xschem getprop rect 2 1 active] 1
  check "MG7b the old target's marker token was cleared" \
    [xschem getprop rect 2 0 active] {}

  # --- MG8: the active-strip marker's prop token -----------------------------
  # owns its setup (no reliance on the layout an earlier phase happened to leave)
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph] \
                                 [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_target_strip 2 $tok}
  xschem new_schematic switch $vdrw
  check "MG8 four graph rects on the viewer canvas" [xschem get rects 2] 4
  check "MG8 only the TARGET rect carries active=1" \
    [xschem getprop rect 2 2 active] 1
  check "MG8 non-target rect 0 has no active token" [xschem getprop rect 2 0 active] {}
  check "MG8 non-target rect 1 has no active token" [xschem getprop rect 2 1 active] {}
  check "MG8 non-target rect 3 has no active token" [xschem getprop rect 2 3 active] {}
  check "MG8 redraw rc 0 with the marker present" [catch {xschem redraw}] 0
  check "MG8 viewer buffer still readonly after the marker write" \
    [xschem get readonly] 1
  check "MG8 viewer buffer still unmodified" [xschem get modified] 0
  # a single strip has nothing to disambiguate -> no marker at all
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "MG8 one strip -> exactly one rect" [xschem get rects 2] 1
  check "MG8 one strip -> NO marker token" [xschem getprop rect 2 0 active] {}

  # --- MG9: persistence round trip -------------------------------------------
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::set_target_strip 1 $tok}
  set snap [pcall {wviewer::snapshot $tok {}}]
  check "MG9 snapshot carries the mode" [pcall {dict get $snap mode}] multi
  check "MG9 snapshot carries the target" [pcall {dict get $snap target}] 1
  check "MG9 fixed build order keeps mode/target LAST" \
    [dict keys $snap] {open sharedx rawfile graphs mode target}
  # restore into a fresh window
  catch {wviewer::close $tok}; update
  check "MG9 restore returns 1" [pcall {wviewer::restore $tok $snap {} {}}] 1
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG9 mode restored (config default overridden)" [pcall {wviewer::plot_mode $tok}] multi
  check "MG9 target restored" [pcall {wviewer::target_strip $tok}] 1
  # a pre-0151 dict (no mode/target keys) must still load
  set old [dict create open 1 sharedx 0 rawfile {} graphs [list [wviewer::empty_graph]]]
  catch {wviewer::close $tok}; update
  check "MG9 pre-0151 dict still restores" [pcall {wviewer::restore $tok $old {} {}}] 1
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG9 missing mode key falls back to the config default" \
    [pcall {wviewer::plot_mode $tok}] single
  check "MG9 missing target key falls back to 0" [pcall {wviewer::target_strip $tok}] 0

  # --- MG14: strip drag-to-reorder -------------------------------------------
  # doc/claude/specs/waveform_viewer_modes.md §12. Two halves, both with teeth:
  # the MODEL mutation (wviewer::move_strip) and the real Tk press/motion/release
  # GESTURE through the shipped bindings.
  #
  # Every synthetic button event carries an explicitly increasing -time: two
  # presses inside Tk's double-click window collapse into <Double-Button-1>,
  # which the viewer binds to {break}, and the second press then never happens
  # (the issue-0152 lesson, `wb_ev` in test_wave_viewer.tcl).
  set ::mg14t 400000
  proc mg14_ev {w seq args} {
    set ::mg14t [expr {$::mg14t + 1000}]
    eval [list event generate $w $seq -time $::mg14t] $args
  }
  # a 4-strip fixture where every strip is identifiable by its single trace
  proc mg14_fixture {tok} {
    set gs {}
    foreach s {0 1 2 3} {
      lappend gs [dict replace [wviewer::empty_graph] traces \
        [list [dict create expr "v(s$s)" name {} vec "v(s$s)" color 4]]]
    }
    wviewer::set_graphs $tok $gs
    wviewer::regenerate $tok
  }
  # the model's trace names, top to bottom
  proc mg14_order {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [wviewer::dget [lindex [dict get $G traces] 0] vec {}]
    }
    return $out
  }
  # the same thing read back off the CANVAS RECTS, so model and rects cannot
  # silently disagree (the reorder is only real if the rects moved too)
  proc mg14_rect_order {vdrw n} {
    xschem new_schematic switch $vdrw
    set out {}
    for {set i 0} {$i < $n} {incr i} {
      lappend out [string trim [xschem getprop rect 2 $i node] {"}]
    }
    return $out
  }

  catch {wviewer::close $tok}; update
  pcall {wviewer::open $tok}
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  pcall {wviewer::set_plot_mode single $tok}
  mg14_fixture $tok
  set H [winfo height $vdrw]
  set W [winfo width $vdrw]

  check "MG14 fixture: four strips, top to bottom" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  check "MG14 the rects agree with the model" [mg14_rect_order $vdrw 4] \
    {v(s0) v(s1) v(s2) v(s3)}
  check_true "MG14 every viewer rect carries the reorder handle token" \
    [expr {[xschem getprop rect 2 0 reorder_handle] == 1 &&
           [xschem getprop rect 2 3 reorder_handle] == 1}]

  # -- the model mutation ------------------------------------------------------
  pcall {wviewer::set_target_strip 1 $tok}
  set nlog [llength $::wvm_log]
  check "MG14 move_strip returns the final index" [pcall {wviewer::move_strip 3 0 $tok}] 0
  check "MG14 bottom strip moved to the top" \
    [mg14_order $tok] {v(s3) v(s0) v(s1) v(s2)}
  check "MG14 the rects moved with it" [mg14_rect_order $vdrw 4] \
    {v(s3) v(s0) v(s1) v(s2)}
  check "MG14 graphbb has one band per strip, in order" \
    [llength [dict get $::wviewer::graphbb $vdrw]] 4
  check "MG14 a DIFFERENT target strip keeps its identity (1 -> 2)" \
    [pcall {wviewer::target_strip $tok}] 2
  check "MG14 exactly ONE log line, fully resolved" \
    [list [expr {[llength $::wvm_log] - $nlog}] [lindex $::wvm_log end]] \
    [list 1 "wviewer::move_strip 3 0 $tok"]

  # the target FOLLOWS the strip it names when that strip is the one moved
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {wviewer::move_strip 0 3 $tok}
  check "MG14 top strip moved to the bottom" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  check "MG14 the target followed the MOVED strip" [pcall {wviewer::target_strip $tok}] 3

  # middle strip, both directions
  pcall {wviewer::move_strip 1 2 $tok}
  check "MG14 middle strip down by one" [mg14_order $tok] {v(s0) v(s2) v(s1) v(s3)}
  pcall {wviewer::move_strip 2 1 $tok}
  check "MG14 middle strip back up by one" [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}

  # refusals: no mutation, no log
  set nlog [llength $::wvm_log]
  check "MG14 from == to returns the index" [pcall {wviewer::move_strip 2 2 $tok}] 2
  check "MG14 out-of-range index is refused" [pcall {wviewer::move_strip 0 9 $tok}] {}
  check "MG14 non-integer index is refused" [pcall {wviewer::move_strip x 0 $tok}] {}
  check "MG14 unknown token is refused" [pcall {wviewer::move_strip 0 1 no/such/tok}] {}
  check "MG14 none of the refusals logged" [llength $::wvm_log] $nlog
  check "MG14 none of the refusals reordered" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}

  # -- live C-written state survives the move ----------------------------------
  # The engine writes pan/zoom ranges and the bold-trace index STRAIGHT into the
  # rect prop where the model never sees them; move_strip regenerates, so
  # without capture_live_graph_state it would throw them away. Written here
  # exactly as waves_callback does (the MG7b idiom).
  wviewer::with_edit $tok {
    xschem setprop -fast rect 2 3 x1 3
    xschem setprop -fast rect 2 3 x2 4
    xschem setprop -fast rect 2 3 y1 -2
    xschem setprop -fast rect 2 3 y2 7
    xschem setprop -fast rect 2 3 hilight_wave 0
  }
  pcall {wviewer::move_strip 3 0 $tok}
  xschem new_schematic switch $vdrw
  check "MG14 the moved strip is on top" [lindex [mg14_order $tok] 0] {v(s3)}
  check "MG14 live x1/x2 survived the reorder" \
    [list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]] {3 4}
  check "MG14 live y1/y2 survived the reorder" \
    [list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]] {-2 7}
  check "MG14 live hilight_wave survived the reorder" \
    [xschem getprop rect 2 0 hilight_wave] 0
  check "MG14 a strip that was never bolded gets NO hilight_wave token" \
    [xschem getprop rect 2 1 hilight_wave] {}

  # -- auto-plot identity ------------------------------------------------------
  set gsa [dict get [wviewer::layout_for $tok] graphs]
  wviewer::set_graphs $tok \
    [lreplace $gsa 2 2 [dict merge [lindex $gsa 2] [dict create auto 1]]]
  wviewer::regenerate $tok
  check "MG14 auto strip is at index 2" [pcall {wviewer::auto_graph_index $tok}] 2
  pcall {wviewer::move_strip 2 0 $tok}
  check "MG14 the `auto 1` marker rode along with its dict" \
    [pcall {wviewer::auto_graph_index $tok}] 0
  pcall {wviewer::move_strip 0 3 $tok}
  check "MG14 ... and again, downward" [pcall {wviewer::auto_graph_index $tok}] 3

  # -- persistence -------------------------------------------------------------
  mg14_fixture $tok
  pcall {wviewer::move_strip 3 0 $tok}
  set snap14 [pcall {wviewer::snapshot $tok {}}]
  catch {wviewer::close $tok}; update
  pcall {wviewer::restore $tok $snap14 {} {}}
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG14 the reordered order survived save/restore" \
    [mg14_order $tok] {v(s3) v(s0) v(s1) v(s2)}

  # -- the GESTURE, through the shipped bindings -------------------------------
  check_true "MG14 <B1-Motion> is bound on the viewer canvas" \
    [string match {*wviewer::strip_drag_motion*} [bind $vdrw <B1-Motion>]]
  check_true "MG14 <ButtonRelease-1> is bound on the viewer canvas" \
    [string match {*wviewer::strip_drag_release*} [bind $vdrw <ButtonRelease-1>]]
  check_true "MG14 the press bind runs the drag seam first" \
    [string match {*wviewer::strip_drag_press*} [bind $vdrw <ButtonPress-1>]]

  mg14_fixture $tok
  set H [winfo height $vdrw]
  set W [winfo width $vdrw]
  # Band midpoints are the drop boundaries, so the gesture legs must aim at a
  # pixel unambiguously PAST the destination's midpoint — landing exactly ON it
  # is the boundary case and rounding decides it. `d` is that few-pixel overshoot
  # in the direction of travel (+ dragging down, - dragging up); d 0 = "somewhere
  # inside band k", which is all a press needs. Read from the SAME source the
  # hit-test uses, so canvas geometry cannot make the leg lie.
  proc mg14_mid {vdrw k {d 0}} {
    set bb [lindex [wviewer::strip_bands_px $vdrw] $k]
    return [expr {int(([lindex $bb 1] + [lindex $bb 3]) / 2.0) + $d}]
  }
  set hx [expr {$W - 7}]                  ;# inside the 14 px handle zone
  set bx [expr {int($W * 0.4)}]           ;# empty waveform body, far from it

  check "MG14 strip_handle_at_pixel finds the handle of band 2" \
    [pcall {wviewer::strip_handle_at_pixel $vdrw $hx [mg14_mid $vdrw 2]}] 2
  check "MG14 strip_handle_at_pixel says -1 in the body" \
    [pcall {wviewer::strip_handle_at_pixel $vdrw $bx [mg14_mid $vdrw 2]}] -1
  check "MG14 strip_drop_index: dragging 3 up past band 1's midpoint" \
    [pcall {wviewer::strip_drop_index $vdrw [mg14_mid $vdrw 1 -3] 3}] 1
  check "MG14 strip_drop_index: dragging 0 down past band 2's midpoint" \
    [pcall {wviewer::strip_drop_index $vdrw [mg14_mid $vdrw 2 3] 0}] 2
  check "MG14 strip_drop_index: short of the midpoint does NOT select it" \
    [pcall {wviewer::strip_drop_index $vdrw [mg14_mid $vdrw 2 -3] 0}] 1
  check "MG14 strip_drop_index clamps above the stack" \
    [pcall {wviewer::strip_drop_index $vdrw -500 3}] 0
  check "MG14 strip_drop_index clamps below the stack" \
    [pcall {wviewer::strip_drop_index $vdrw [expr {$H + 500}] 0}] 3

  # HANDLE drag: bottom strip to the top
  pcall {wviewer::set_target_strip 3 $tok}   ;# already the target -> no target log
  set nlog [llength $::wvm_log]
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 3]
  foreach k {2 1 0} {
    mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw $k -3] -state 0x100
  }
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [mg14_mid $vdrw 0 -3] -state 0x100
  update
  check "MG14 handle drag moved the bottom strip to the top" \
    [mg14_order $tok] {v(s3) v(s0) v(s1) v(s2)}
  check "MG14 the rects followed" [mg14_rect_order $vdrw 4] \
    {v(s3) v(s0) v(s1) v(s2)}
  check "MG14 the target followed the dragged strip" \
    [pcall {wviewer::target_strip $tok}] 0
  check "MG14 the drag logged exactly one resolved move_strip" \
    [list [expr {[llength $::wvm_log] - $nlog}] [lindex $::wvm_log end]] \
    [list 1 "wviewer::move_strip 3 0 $tok"]
  check "MG14 no drop-bar feedback is left behind" \
    [xschem getprop rect 2 0 reorder_handle] 1

  # EMPTY-BODY drag (no handle involved): top strip to the bottom. This is the
  # leg that would stay green if only the handle worked.
  mg14_fixture $tok
  pcall {wviewer::set_target_strip 2 $tok}   ;# NOT the strip about to be dragged
  set nlog [llength $::wvm_log]
  mg14_ev $vdrw <ButtonPress-1> -x $bx -y [mg14_mid $vdrw 0]
  foreach k {1 2 3} {
    mg14_ev $vdrw <B1-Motion> -x $bx -y [mg14_mid $vdrw $k 3] -state 0x100
  }
  mg14_ev $vdrw <ButtonRelease-1> -x $bx -y [mg14_mid $vdrw 3 3] -state 0x100
  update
  check "MG14 empty-body drag moved the top strip to the bottom" \
    [mg14_order $tok] {v(s1) v(s2) v(s3) v(s0)}
  # the press re-targeted (strip 0), so replay needs that line BEFORE the move
  check "MG14 a target change is logged before the move" \
    [lrange $::wvm_log $nlog end] \
    [list "wviewer::set_target_strip 0 $tok" "wviewer::move_strip 0 3 $tok"]
  check "MG14 the target ended up on the moved strip" \
    [pcall {wviewer::target_strip $tok}] 3

  # middle strip, both directions, through the gesture
  mg14_fixture $tok
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 1]
  mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw 2 3] -state 0x100
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [mg14_mid $vdrw 2 3] -state 0x100
  update
  check "MG14 gesture: middle strip DOWN by one" \
    [mg14_order $tok] {v(s0) v(s2) v(s1) v(s3)}
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 2]
  mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw 1 -3] -state 0x100
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [mg14_mid $vdrw 1 -3] -state 0x100
  update
  check "MG14 gesture: middle strip UP by one" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}

  # clamp: drag well past the top / bottom of the stack
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 2]
  mg14_ev $vdrw <B1-Motion> -x $hx -y -400 -state 0x100
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y -400 -state 0x100
  update
  check "MG14 dragging above the stack clamps to first" \
    [mg14_order $tok] {v(s2) v(s0) v(s1) v(s3)}
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 0]
  mg14_ev $vdrw <B1-Motion> -x $hx -y [expr {$H + 400}] -state 0x100
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [expr {$H + 400}] -state 0x100
  update
  check "MG14 dragging below the stack clamps to last" \
    [mg14_order $tok] {v(s0) v(s1) v(s3) v(s2)}

  # -- the NON-moves: sub-threshold, same-position, cancelled ------------------
  # target parked on the strip these legs grab, so a press cannot add a
  # set_target_strip line and blur the "logs nothing" assertions
  mg14_fixture $tok
  pcall {wviewer::set_target_strip 1 $tok}
  set nlog [llength $::wvm_log]
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 1]
  mg14_ev $vdrw <B1-Motion> -x $hx -y [expr {[mg14_mid $vdrw 1] + 2}] -state 0x100
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [expr {[mg14_mid $vdrw 1] + 2}] -state 0x100
  update
  check "MG14 sub-threshold motion does not reorder" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  check "MG14 sub-threshold motion logs nothing" [llength $::wvm_log] $nlog

  # a real drag that comes back to where it started
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 1]
  mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw 2 3] -state 0x100
  mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw 1] -state 0x100
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [mg14_mid $vdrw 1] -state 0x100
  update
  check "MG14 a drop at the original position is a no-op" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  check "MG14 a no-op drop logs nothing" [llength $::wvm_log] $nlog

  # ESC mid-drag
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 1]
  mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw 3 3] -state 0x100
  check_true "MG14 a drag is armed and active before ESC" \
    [expr {$::wviewer::drag_active($tok) == 1}]
  # focus the canvas first: a generated KeyPress is delivered to the FOCUS
  # window, and under WSLg the viewer can lose focus between legs — without
  # this the ESC leg is flaky (it silently never reaches key_filter)
  focus -force $vdrw
  update
  event generate $vdrw <KeyPress> -keysym Escape
  update
  check "MG14 ESC cancelled the drag (state reset)" \
    [list $::wviewer::drag_from($tok) $::wviewer::drag_to($tok) \
          $::wviewer::drag_active($tok)] {-1 -1 0}
  check "MG14 ESC restored the pointer" [$vdrw cget -cursor] {}
  check "MG14 ESC cleared the drop-bar feedback" \
    [xschem getprop rect 2 3 reorder_handle] 1
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [mg14_mid $vdrw 3 3] -state 0x100
  update
  check "MG14 the cancelled drag changed nothing" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  check "MG14 the cancelled drag logged nothing" [llength $::wvm_log] $nlog

  # -- drop feedback is painted, and never regenerates the stack ---------------
  mg14_ev $vdrw <ButtonPress-1> -x $hx -y [mg14_mid $vdrw 1]
  mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw 2 3] -state 0x100
  update
  xschem new_schematic switch $vdrw
  check "MG14 the destination strip carries the drop bar (3 = bottom edge)" \
    [xschem getprop rect 2 2 reorder_handle] 3
  check "MG14 non-destination strips keep the plain grip" \
    [list [xschem getprop rect 2 1 reorder_handle] \
          [xschem getprop rect 2 3 reorder_handle]] {1 1}
  check "MG14 the model is NOT mutated during the drag" \
    [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  mg14_ev $vdrw <B1-Motion> -x $hx -y [mg14_mid $vdrw 0 -3] -state 0x100
  update
  xschem new_schematic switch $vdrw
  check "MG14 the bar moves with the destination (2 = top edge, moving up)" \
    [list [xschem getprop rect 2 0 reorder_handle] \
          [xschem getprop rect 2 2 reorder_handle]] {2 1}
  mg14_ev $vdrw <ButtonRelease-1> -x $hx -y [mg14_mid $vdrw 0 -3] -state 0x100
  update
  check "MG14 the drag committed after the feedback legs" \
    [mg14_order $tok] {v(s1) v(s0) v(s2) v(s3)}
  check "MG14 viewer buffer still readonly + unmodified" \
    [list [xschem get readonly] [xschem get modified]] {1 0}

  # --- MG15: move a TRACE between strips, the MODEL mutation ------------------
  # doc/claude/specs/waveform_viewer_modes.md §13. The gesture half needs REAL
  # raw data (the pick is a C hit-test against the drawn polyline) and lives in
  # test_wave_viewer.tcl `TD*`; wviewer::move_trace itself does not, so its
  # contract is pinned here next to move_strip's.
  proc mg15_traces {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      set v {}
      foreach tr [wviewer::dget $G traces {}] { lappend v [wviewer::dget $tr vec {}] }
      lappend out $v
    }
    return $out
  }
  mg14_fixture $tok
  pcall {wviewer::set_target_strip 1 $tok}
  set nlog [llength $::wvm_log]
  check "MG15 move_trace returns the DESTINATION trace index" \
    [pcall {wviewer::move_trace 3 0 0 $tok}] 1
  check "MG15 the trace left strip 3 and landed at the end of strip 0" \
    [pcall {mg15_traces $tok}] {{v(s0) v(s3)} v(s1) v(s2) {}}
  check "MG15 the strip COUNT is unchanged (an emptied strip stays)" \
    [llength [dict get [wviewer::layout_for $tok] graphs]] 4
  xschem new_schematic switch $vdrw
  check "MG15 the rects agree: strip 0 now carries both nodes" \
    [split [string map {\" {}} [xschem getprop rect 2 0 node]] "\n"] {v(s0) v(s3)}
  check "MG15 ... and the emptied strip has an empty node token" \
    [string map {\" {}} [xschem getprop rect 2 3 node]] {}
  check "MG15 exactly ONE log line, fully resolved" \
    [list [expr {[llength $::wvm_log] - $nlog}] [lindex $::wvm_log end]] \
    [list 1 "wviewer::move_trace 3 0 0 $tok"]
  check "MG15 the DESTINATION strip became the target" \
    [pcall {wviewer::target_strip $tok}] 0

  # refusals: no mutation, no log
  mg14_fixture $tok
  set nlog [llength $::wvm_log]
  check "MG15 same-strip drop returns the trace index" \
    [pcall {wviewer::move_trace 1 0 1 $tok}] 0
  check "MG15 out-of-range strip is refused" [pcall {wviewer::move_trace 0 0 9 $tok}] {}
  check "MG15 out-of-range trace is refused" [pcall {wviewer::move_trace 0 5 1 $tok}] {}
  check "MG15 non-integer trace index is refused" [pcall {wviewer::move_trace 0 x 1 $tok}] {}
  check "MG15 unknown token is refused" [pcall {wviewer::move_trace 0 0 1 no/such/tok}] {}
  check "MG15 none of the refusals logged" [llength $::wvm_log] $nlog
  check "MG15 none of the refusals moved anything" \
    [pcall {mg15_traces $tok}] {v(s0) v(s1) v(s2) v(s3)}

  # live C-written state survives (the capture_live_graph_state contract, the
  # same one move_strip has: the engine writes pan/zoom/bold into the RECT)
  mg14_fixture $tok
  wviewer::with_edit $tok {
    xschem setprop -fast rect 2 1 x1 3
    xschem setprop -fast rect 2 1 x2 4
    xschem setprop -fast rect 2 1 y1 -2
    xschem setprop -fast rect 2 1 y2 7
    xschem setprop -fast rect 2 0 hilight_wave 0
  }
  pcall {wviewer::move_trace 2 0 1 $tok}
  xschem new_schematic switch $vdrw
  check "MG15 live x1/x2 of the destination survived the move" \
    [list [xschem getprop rect 2 1 x1] [xschem getprop rect 2 1 x2]] {3 4}
  check "MG15 live y1/y2 survived too" \
    [list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]] {-2 7}
  check "MG15 an unrelated strip's bold survived" \
    [xschem getprop rect 2 0 hilight_wave] 0
  # the BOLD trace itself moving: the highlight follows it to the destination
  mg14_fixture $tok
  wviewer::with_edit $tok {xschem setprop -fast rect 2 2 hilight_wave 0}
  pcall {wviewer::move_trace 2 0 0 $tok}
  xschem new_schematic switch $vdrw
  check "MG15 the bold trace kept its bold at its new node index" \
    [xschem getprop rect 2 0 hilight_wave] 1
  check "MG15 the emptied source lost its bold marker" \
    [xschem getprop rect 2 2 hilight_wave] {}
  check "MG15 viewer buffer still readonly + unmodified" \
    [list [xschem get readonly] [xschem get modified]] {1 0}
  # --- MG16: undo / redo of viewer model edits (`u` / Shift-u) ---------------
  # doc/claude/specs/waveform_viewer_modes.md §14. A viewer edit is a change to
  # the TCL MODEL, so the history is a stack of model snapshots — not the C undo
  # stack, which is about schematic objects and cannot run on a readonly buffer.
  mg14_fixture $tok
  wviewer::clear_history $tok
  pcall {wviewer::set_target_strip 1 $tok}
  check "MG16 a fresh fixture has no history" [pcall {wviewer::history_depth $tok}] {0 0}
  check "MG16 nothing to undo -> {}" [pcall {wviewer::undo $tok}] {}
  check "MG16 nothing to redo -> {}" [pcall {wviewer::redo $tok}] {}
  set nlog [llength $::wvm_log]
  check "MG16 a refused undo logs nothing" [llength $::wvm_log] $nlog

  # a strip reorder, undone and redone
  pcall {wviewer::move_strip 3 0 $tok}
  check "MG16 the reorder happened" [mg14_order $tok] {v(s3) v(s0) v(s1) v(s2)}
  check "MG16 the edit pushed exactly one undo point" \
    [pcall {wviewer::history_depth $tok}] {1 0}
  check "MG16 undo returns 1" [pcall {wviewer::undo $tok}] 1
  check "MG16 undo put the strip order back" [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  check "MG16 undo restored the TARGET too" [pcall {wviewer::target_strip $tok}] 1
  check "MG16 the undone edit is now redoable" \
    [pcall {wviewer::history_depth $tok}] {0 1}
  check "MG16 undo is logged replayably" [lindex $::wvm_log end] "wviewer::undo $tok"
  check "MG16 redo returns 1" [pcall {wviewer::redo $tok}] 1
  check "MG16 redo re-applied the reorder" [mg14_order $tok] {v(s3) v(s0) v(s1) v(s2)}
  check "MG16 redo restored the target the edit left" \
    [pcall {wviewer::target_strip $tok}] 2
  check "MG16 redo is logged replayably" [lindex $::wvm_log end] "wviewer::redo $tok"
  check "MG16 the redone edit is undoable again" \
    [pcall {wviewer::history_depth $tok}] {1 0}
  # the RECTS follow, not just the model
  check "MG16 undo/redo moved the rects too" [mg14_rect_order $vdrw 4] \
    {v(s3) v(s0) v(s1) v(s2)}

  # a trace move, undone
  mg14_fixture $tok
  wviewer::clear_history $tok
  proc mg16_traces {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      set v {}
      foreach tr [wviewer::dget $G traces {}] { lappend v [wviewer::dget $tr vec {}] }
      lappend out $v
    }
    return $out
  }
  set mg16before [pcall {mg16_traces $tok}]
  pcall {wviewer::move_trace 3 0 0 $tok}
  check "MG16 the trace move happened" \
    [pcall {mg16_traces $tok}] {{v(s0) v(s3)} v(s1) v(s2) {}}
  pcall {wviewer::undo $tok}
  check "MG16 undo put the trace back on its own strip" \
    [pcall {mg16_traces $tok}] $mg16before
  xschem new_schematic switch $vdrw
  check "MG16 ... and the rect node tokens agree" \
    [string map {\" {}} [xschem getprop rect 2 3 node]] {v(s3)}
  pcall {wviewer::redo $tok}
  check "MG16 redo moved it again" \
    [pcall {mg16_traces $tok}] {{v(s0) v(s3)} v(s1) v(s2) {}}

  # LIFO across mixed edits, all the way back
  mg14_fixture $tok
  wviewer::clear_history $tok
  pcall {wviewer::move_strip 0 1 $tok}
  pcall {wviewer::move_trace 2 0 3 $tok}
  pcall {wviewer::move_strip 3 0 $tok}
  check "MG16 three edits, three undo points" \
    [lindex [pcall {wviewer::history_depth $tok}] 0] 3
  pcall {wviewer::undo $tok}
  pcall {wviewer::undo $tok}
  pcall {wviewer::undo $tok}
  check "MG16 undoing every edit returns the original layout" \
    [list [mg14_order $tok] [pcall {mg16_traces $tok}]] \
    [list {v(s0) v(s1) v(s2) v(s3)} {v(s0) v(s1) v(s2) v(s3)}]
  check "MG16 the stack is empty and everything is redoable" \
    [pcall {wviewer::history_depth $tok}] {0 3}

  # a NEW edit drops the redo branch (linear history)
  pcall {wviewer::move_strip 1 2 $tok}
  check "MG16 a new edit cleared the redo branch" \
    [pcall {wviewer::history_depth $tok}] {1 0}
  check "MG16 redo after that is refused" [pcall {wviewer::redo $tok}] {}

  # the live C-written state comes back with the undo (the capture contract:
  # push_undo runs AFTER capture_live_graph_state)
  mg14_fixture $tok
  wviewer::clear_history $tok
  wviewer::with_edit $tok {
    xschem setprop -fast rect 2 0 x1 3
    xschem setprop -fast rect 2 0 x2 4
    xschem setprop -fast rect 2 0 hilight_wave 0
  }
  pcall {wviewer::move_strip 0 3 $tok}
  pcall {wviewer::undo $tok}
  xschem new_schematic switch $vdrw
  check "MG16 the mouse-made zoom survived the undo" \
    [list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]] {3 4}
  check "MG16 the mouse-made bold survived the undo" \
    [xschem getprop rect 2 0 hilight_wave] 0

  # depth cap
  set mg16d $::wviewer::undo_depth
  set ::wviewer::undo_depth 3
  mg14_fixture $tok
  wviewer::clear_history $tok
  foreach p {{0 1} {1 2} {2 3} {3 0} {0 1}} {
    pcall {wviewer::move_strip [lindex $p 0] [lindex $p 1] $tok}
  }
  check "MG16 the undo stack is capped at undo_depth" \
    [lindex [pcall {wviewer::history_depth $tok}] 0] 3
  set ::wviewer::undo_depth $mg16d

  # a restore replaces the model wholesale, so the history must go
  mg14_fixture $tok
  pcall {wviewer::move_strip 0 1 $tok}
  set mg16snap [pcall {wviewer::snapshot $tok {}}]
  pcall {wviewer::restore $tok $mg16snap {} {}}
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG16 restore cleared the history" [pcall {wviewer::history_depth $tok}] {0 0}

  # the KEYS, on the shared WaveViewer bindtag (issue 0171's mechanism)
  check_true "MG16 `u` is bound on the WaveViewer bindtag" \
    [string match {*wviewer::undo_at*} [bind WaveViewer <Key-u>]]
  check_true "MG16 Shift-u is bound to redo" \
    [string match {*wviewer::redo_at*} [bind WaveViewer <Key-U>]]
  check_true "MG16 the tag is on the viewer canvas" \
    [expr {[lsearch -exact [bindtags $vdrw] WaveViewer] >= 0}]
  # ⚠ These legs used a BARE `event generate` + one `update`, and they flaked
  # about 1 run in 5 — measured, in isolation, on an idle machine, and worse
  # under load (a full-suite batch turned two of them red). Generated KeyPress
  # events go to the DISPLAY's focus window and the WSLg focus round-trip is
  # ASYNCHRONOUS, so a key delivered before Tk owns the focus is simply lost.
  # The repo already has the answer (test_wave_clear_all.tcl's send_key,
  # test_ase_plot.tcl's ESC loop): gate every generate on Tk reporting the
  # canvas as focus owner, and retry until the effect is observed.
  proc mg16_key {w keysym state done} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {![winfo exists $w]} { return 0 }
      focus -force $w
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[focus -displayof $w] eq $w} {
        if {$state eq {}} {
          event generate $w <KeyPress> -keysym $keysym
        } else {
          event generate $w <KeyPress> -keysym $keysym -state $state
        }
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
      }
      after 50
    }
    return 0
  }
  # The NEGATIVE leg has no effect to wait for, so retry-until-effect cannot
  # apply. Confirm the focus — which is the part that flakes — then deliver
  # once. Without this the leg passes for the wrong reason whenever the key was
  # never delivered at all.
  proc mg16_key_once {w keysym} {
    for {set i 0} {$i < 100} {incr i} {
      update
      if {[winfo exists $w] && [focus -displayof $w] eq $w} {
        event generate $w <KeyPress> -keysym $keysym
        update
        return 1
      }
      focus -force $w
      update
      after 20
    }
    return 0
  }

  mg14_fixture $tok
  wviewer::clear_history $tok
  pcall {wviewer::move_strip 3 0 $tok}
  mg16_key $vdrw u {} {[mg14_order $tok] eq {v(s0) v(s1) v(s2) v(s3)}}
  check "MG16 the `u` KEY undid the reorder" [mg14_order $tok] {v(s0) v(s1) v(s2) v(s3)}
  mg16_key $vdrw U 1 {[mg14_order $tok] eq {v(s3) v(s0) v(s1) v(s2)}}
  check "MG16 the Shift-u KEY redid it" [mg14_order $tok] {v(s3) v(s0) v(s1) v(s2)}
  # an rc that rebinds the key must win, and `{break}` must disable it
  set mg16u [bind WaveViewer <Key-u>]
  bind WaveViewer <Key-u> {break}
  wviewer::install_default_binds
  check "MG16 an rc remap of `u` survives install_default_binds" \
    [bind WaveViewer <Key-u>] {break}
  check_true "MG16 the disabled-key probe was actually delivered" \
    [pcall {mg16_key_once $vdrw u}]
  check "MG16 the disabled key does nothing" [mg14_order $tok] {v(s3) v(s0) v(s1) v(s2)}
  bind WaveViewer <Key-u> $mg16u
  rename mg16_traces {}
  rename mg15_traces {}

  rename mg14_ev {}
  rename mg14_fixture {}
  rename mg14_order {}
  rename mg14_rect_order {}
  rename mg14_mid {}
  unset ::mg14t

  # --- MG12: the REAL Direct Plot finish path honours the mode ----------------
  # (teeth for the ONE production wiring: ase::ui::dp_finish. Driving only
  # wviewer::plot_signals would leave the pre-0151 dp_finish body passing.)
  check "MG12 fixture plots as dc, so dp_finish does not abort on op" \
    [pcall {ase::plot_sim_type [ase::session_state $tok]}] dc
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {ase::ui::dp_finish $tok {v(m1) v(m2)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  # one signal per strip is the multi contract; the two EMPTY strips of this
  # fixture ARE those strips (0171 follow-up), and the batch reads newest-first
  check "MG12 multi mode: dp_finish put ONE SIGNAL PER STRIP" [llength $gs] 2
  check "MG12 the LAST pick is on top" \
    [dict get [lindex [dict get [lindex $gs 0] traces] 0] expr] {v(m2)}
  check "MG12 the first pick is below it" \
    [dict get [lindex [dict get [lindex $gs 1] traces] 0] expr] {v(m1)}
  # with nothing empty left, the next gesture creates its strips ON TOP
  pcall {ase::ui::dp_finish $tok {v(m3) v(m4)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG12 multi mode creates one strip per signal when none is free" \
    [llength $gs] 4
  check "MG12 the newest gesture is on top, newest-first" \
    [list [dict get [lindex [dict get [lindex $gs 0] traces] 0] expr] \
          [dict get [lindex [dict get [lindex $gs 1] traces] 0] expr]] {v(m4) v(m3)}
  check "MG12 the earlier strips were pushed down, intact" \
    [list [dict get [lindex [dict get [lindex $gs 2] traces] 0] expr] \
          [dict get [lindex [dict get [lindex $gs 3] traces] 0] expr]] {v(m2) v(m1)}
  # same call, single mode -> everything into the target, no new strip
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_target_strip 1 $tok}
  pcall {ase::ui::dp_finish $tok {v(s1) v(s2)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG12 single mode: dp_finish created NO strip" [llength $gs] 2
  check "MG12 both signals landed in the target strip" \
    [llength [dict get [lindex $gs 1] traces]] 2
  check "MG12 the other strip stayed empty" \
    [llength [dict get [lindex $gs 0] traces]] 0
  check "MG12 an empty queue still creates nothing" \
    [llength [dict get [wviewer::layout_for $tok] graphs]] 2

  # --- MG13: the shipped chord SPELLING actually fires ------------------------
  # A physical Ctrl+Shift+4 arrives as keysym `dollar` on a US layout, so
  # <Control-Shift-Key-4> alone never matches (this is why cadence_style_rc
  # binds <Control-Key-at> for Ctrl-Shift-2). Bind the rc's own script shape on
  # a scratch widget and fire the real event — no rc sourcing, no C keybinding.
  set ::wvm_chord {}
  toplevel .wvmchord
  wm geometry .wvmchord 120x60+0+0
  bind .wvmchord <Control-Key-dollar>  {lappend ::wvm_chord dollar; break}
  bind .wvmchord <Control-Shift-Key-4> {lappend ::wvm_chord shift4; break}
  update
  focus -force .wvmchord
  event generate .wvmchord <KeyPress> -keysym 4 -state 5 -when now
  update
  check "MG13 Ctrl+Shift+4 resolves to the <Control-Key-dollar> form" \
    $::wvm_chord dollar
  destroy .wvmchord
  check_true "MG13 cadence_style_rc binds the form that actually fires" \
    [regexp {bind \.drw <Control-Key-dollar>\s+\{ase::plot_mode_for_current} \
       [read [set fh [open [file join $repo src cadence_style_rc] r]]][close $fh]]

  # --- MG17: the chord must not LEAK the xschem context (issue 0173) ----------
  # Reported: pressing Ctrl-Shift-4 in the SCHEMATIC window (a) rewrote the
  # VIEWER's title to `xschem [N] - untitled.sch (read-only)` and (b) made the
  # next click in the schematic act on the viewer. Both are one defect —
  # wviewer::status_refresh read `graph_snap` through wviewer::in_ctx, which
  # switched the C context to the viewer and never switched back; the C
  # switch_window ends in set_modify(-1), whose whole job is to rewrite the
  # target window's wm title.
  #
  # ⚠ NO `update` BETWEEN THE TOGGLE AND THE ASSERTIONS, and the omission is
  # LOAD-BEARING. The viewer carries `bind $top <FocusIn> +wviewer::retitle`
  # (wave_viewer.tcl, in `open`) and the editor carries the Tcl `switch_window` FocusIn
  # handler (xschem.tcl ~13757) — BOTH repair exactly this damage. An `update`
  # here would let a queued FocusIn run first and the leg would then pass on a
  # defect that was repaired rather than on one that never happened. Everything
  # that needs settling is settled BEFORE the toggle.
  #
  # ⚠ DISPLAY-arm only, and not by accident: set_modify's title rewrite is
  # `has_x`-gated (actions.c ~242) and there is no viewer window under --nogui.
  # The headless half of this fix is M9.
  #
  # ⚠ MG10 below is the green-but-hollow leg this bug hid behind for two weeks:
  # it already drives `ase::plot_mode_for_current invert` and asserts the
  # returned mode, and it never looked at the context or the title.
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  # the SCHEMATIC owns the context, exactly as in the repro (explicit, so this
  # group does not inherit whatever window the previous group left current)
  catch {xschem new_schematic switch .drw}
  xschem load $schfile
  update
  set mg17_win   [xschem get current_win_path]
  set mg17_title [wviewer::title_for $tok]
  wm title $vtop $mg17_title            ;# known-good starting point
  check "MG17 the schematic owns the context before the chord" $mg17_win .drw
  # The retitle SPY is what makes the title leg honest: it proves the title was
  # NEVER CORRUPTED, instead of corrupted-and-repaired. A leg that only compares
  # the final string passes either way.
  set ::mg17_retitle 0
  rename wviewer::retitle wviewer::__mg17_real_retitle
  proc wviewer::retitle {token} {
    incr ::mg17_retitle
    wviewer::__mg17_real_retitle $token
  }

  set mg17_nlog [llength $::wvm_log]
  set mg17_mode [pcall {ase::plot_mode_for_current invert}]
  # ---- assertions. Do not insert `update` above this line. ----
  # one gesture, one log line: the fix must not have added a second (a
  # notify_window_active or a bookkeeping line would show up right here)
  check "MG17 the chord still logs exactly one line" \
    [expr {[llength $::wvm_log] - $mg17_nlog}] 1
  check "MG17 ... and it is the plot-mode line, with the resolved word" \
    [lindex $::wvm_log end] "wviewer::set_plot_mode $mg17_mode $tok"
  check_true "MG17 the chord still resolves a mode (the flip is untouched)" \
    [expr {$mg17_mode eq {single} || $mg17_mode eq {multi}}]
  check "MG17 the chord LEFT THE CONTEXT ON THE SCHEMATIC" \
    [xschem get current_win_path] $mg17_win
  check "MG17 the viewer still has its own title" [wm title $vtop] $mg17_title
  check "MG17 ... and that title was never corrupted (no repair ran)" \
    $::mg17_retitle 0
  check "MG17 the mode really did change on the VIEWER" \
    [pcall {wviewer::plot_mode $tok}] $mg17_mode
  # the status bar is still PUSHED from the one mutation site (item 10), and the
  # mode half of it needs no context at all
  check_true "MG17 the status bar shows the new mode after a cross-window flip" \
    [string match "*$mg17_mode*" [$vtop.wvstatus.l cget -text]]

  # in_ctx BORROWS the context and gives it back (D4). Called with the SCHEMATIC
  # current it does switch — so here the title IS clobbered and the spy must see
  # exactly ONE repair. That asymmetry with the chord above is the whole point of
  # D1(a): the chord path no longer switches at all, so it has nothing to repair.
  set ::mg17_retitle 0
  check "MG17 in_ctx runs its script in the VIEWER's context" \
    [pcall {wviewer::in_ctx $tok {xschem get current_win_path}}] $vdrw
  check "MG17 in_ctx put the context back where it found it" \
    [xschem get current_win_path] $mg17_win
  check "MG17 in_ctx re-asserted the viewer title it clobbered, once" \
    $::mg17_retitle 1
  check "MG17 ... so the title is right without any FocusIn repair" \
    [wm title $vtop] $mg17_title

  # readout_refresh has the same defect and the same fix (D5): it genuinely needs
  # the viewer ctx (cursorN_x and interp_value's raw reads are per-context), so it
  # borrows instead of declining.
  set ::mg17_retitle 0
  pcall {wviewer::readout_refresh $tok}
  check "MG17 readout_refresh put the context back too" \
    [xschem get current_win_path] $mg17_win
  check "MG17 readout_refresh left the viewer title correct" \
    [wm title $vtop] $mg17_title

  # A REFUSED switch (landmine 17: `new_schematic switch` silently no-ops while
  # the current context's semaphore is raised) must run NOTHING — pre-0173 in_ctx
  # would have run the script against whatever foreign window was current.
  rename wviewer::switch_ctx wviewer::__mg17_real_switch
  proc wviewer::switch_ctx {token} { return 0 }
  set ::mg17_ran 0
  check "MG17 a refused switch makes in_ctx return {}" \
    [pcall {wviewer::in_ctx $tok {set ::mg17_ran 1; expr 42}}] {}
  check "MG17 ... having run nothing at all" $::mg17_ran 0
  check "MG17 ... and left the context exactly where it was" \
    [xschem get current_win_path] $mg17_win
  rename wviewer::switch_ctx {}
  rename wviewer::__mg17_real_switch wviewer::switch_ctx

  # A refused RESTORE is the same landmine in reverse. It is counted for
  # diagnosis, never retried and never thrown (every caller rides a keystroke or
  # the motion pump, where a throw pops bgerror). A win_path no window owns is a
  # switch the C side must refuse.
  set mg17_refused $::wviewer::ctx_restore_refused
  check "MG17 a refused restore reports failure instead of pretending" \
    [pcall {wviewer::leave_ctx $tok {1 .no.such.drw}}] 0
  check "MG17 ... and is recorded once, for diagnosis" \
    [expr {$::wviewer::ctx_restore_refused - $mg17_refused}] 1
  check "MG17 ... and leaves the context alone rather than looping on it" \
    [xschem get current_win_path] $mg17_win
  check "MG17 ... while still repairing the title the entry clobbered" \
    [wm title $vtop] $mg17_title

  rename wviewer::retitle {}
  rename wviewer::__mg17_real_retitle wviewer::retitle

  # --- MG10: schematic-side entry points --------------------------------------
  xschem load $schfile
  check "MG10 design is current" \
    [file tail [xschem get schname]] test_nfet_final.sch
  # session_for_design matches the STATE's `design` dict (view = schematic),
  # not the state view the session key is named after
  check "MG10 the design resolves to the bound session" \
    [pcall {ase::session_for_design sky130_tests test_nfet_final schematic}] $tok
  # flip the viewer's mode from the DESIGN window
  pcall {wviewer::set_plot_mode single $tok}
  check "MG10 chord proc returns the resolved mode" \
    [pcall {ase::plot_mode_for_current invert}] multi
  check "MG10 the VIEWER's mode changed" [pcall {wviewer::plot_mode $tok}] multi
  check "MG10 explicit mode word accepted" \
    [pcall {ase::plot_mode_for_current single}] single
  # no ASE-L window has been built for this session -> honest {}
  check "MG10 ASE window number is {} while no ASE window exists" \
    [pcall {ase::ui::number_for $tok}] {}
  check "MG10 window_number_for_current is honest about it" \
    [pcall {ase::window_number_for_current}] {}
  # ... and with a real ASE-L window it is the Cadence number of .aseN
  set asetop {}
  catch {ase::open_state sky130_tests test_nfet_final ngspice_state1}
  set asetop [ase::ui::window_for $tok]
  if {$asetop eq {} || ![winfo exists $asetop]} {
    puts "SKIPPED: MG10 ASE-window legs (session window never opened)"
  } else {
    update
    set n [pcall {ase::ui::number_for $tok}]
    check_true "MG10 ASE window number is an editor-range number (>=3)" \
      [expr {[string is integer -strict $n] && $n >= 3}]
    check "MG10 the number matches the .aseN toplevel path" $asetop ".ase$n"
    xschem load $schfile
    check "MG10 window_number_for_current returns the ASE-L number" \
      [pcall {ase::window_number_for_current}] $n
    catch {ase::ui::close $tok}
    update
  }
  # session bound, but the viewer WINDOW closed -> honest {} (the mode is
  # per-window state; there is nothing to flip until the window exists)
  xschem load $schfile
  catch {wviewer::close $tok}
  update
  check "MG10 viewer closed -> the chord proc reports {} and changes nothing" \
    [pcall {ase::plot_mode_for_current invert}] {}
  check "MG10 viewer closed -> plot_mode is {} too" [pcall {wviewer::plot_mode $tok}] {}
  # a RESOLVABLE design with NO session at all -> the no-session branch proper
  # (a design outside the registry would stop earlier, at the design gate, and
  # never reach it)
  ase::session_close $tok
  xschem load $schfile
  check "MG10 design still resolves after closing the session" \
    [pcall {ase::design_of_current}] {sky130_tests test_nfet_final schematic}
  check "MG10 no session bound -> {} from the chord proc" \
    [pcall {ase::plot_mode_for_current invert}] {}
  check "MG10 no session bound -> {} from the number query" \
    [pcall {ase::window_number_for_current}] {}
  # and a design the registry does not know at all: the design gate, still no throw
  xschem load [file join $repo xschem_library examples test_ne555.sch]
  check "MG10 unregistered design -> {} from the chord proc" \
    [pcall {ase::plot_mode_for_current invert}] {}
  check "MG10 unregistered design -> {} from the number query" \
    [pcall {ase::window_number_for_current}] {}

  # --- MG11: the shipped chord is bound --------------------------------------
  # (cadence_style_rc is not sourced by this test; assert the LINE exists so a
  # silent removal is caught, the same way the Ctrl-4 entry is documented)
  set rcf [file join $repo src cadence_style_rc]
  set fh [open $rcf r]; set rctext [read $fh]; close $fh
  check_true "MG11 Ctrl-Shift-4 is bound to the mode flip in cadence_style_rc" \
    [regexp {bind \.drw <Control-Shift-Key-4>.*ase::plot_mode_for_current} $rctext]

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  catch {wviewer::close $tok}
  update
  }
} else {
  puts "SKIPPED: MG* GUI legs (no usable DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts $::errorInfo
  incr fail
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
