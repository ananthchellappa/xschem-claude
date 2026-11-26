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
# no C->Tcl getter for the grid's dash and no way to read back an X GC's dash
# list, so "the grid looks lighter" is EYEBALL-ONLY. (Item 22 added one getter,
# `xschem get graph_text_metrics`, for the text sizes and margins only: the GF
# band below.) Asserted here is everything
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
# GX* — issue 0194: WHICH regenerate sites owe capture_live_graph_state
#
# regenerate does `xschem clear_drawing` and re-places every rect from the Tcl
# model, so C-written rect state (the 0175 selection, an MMB pan, an RMB box
# zoom) dies unless it was folded back first. Ctrl-G was one of 15 sites that
# did not fold. These are SOURCE-level legs because the rule is about code
# SHAPE — the behavioural half is GS* below, and neither can replace the other:
# a behavioural leg cannot see the eleven sibling sites, and these cannot see
# whether the fold actually preserves anything.
# ============================================================================
set wv [file join $repo src wave_viewer.tcl]
set fp [open $wv r]; set wsrc [read $fp]; close $fp

# body of a named proc up to the closing brace in column 0, CODE LINES ONLY
# — the bodies here carry comments naming the very calls being counted, and a
# leg that counts prose is a leg that goes green on a deleted call.
proc wvproc_body {src name} {
  set i [string first "\nproc $name \{" $src]
  if {$i < 0} { return {} }
  set j [string first "\n\}\n" $src $i]
  if {$j < 0} { set j end }
  set out {}
  foreach line [split [string range $src $i $j] "\n"] {
    if {[regexp {^\s*#} $line]} { continue }
    lappend out $line
  }
  return [join $out "\n"]
}

# THE RULE: a regenerate that carries the current strips forward must capture
# first. The gx_must list does; the three exemptions below replace the model
# wholesale and must not. gx_must + gx_exempt + the gx_pre sites that already
# captured pre-0194 = every call site, and GX4 asserts exactly that sum, so the
# three lists have to be kept in step with the source rather than approximated.
#
# ⚠ `rawbar_load` ADDED BY SIGNAL_BROWSER_BATCH ITEM 13 (the Location bar). It
# is a textbook gx_must: a Location-bar load swaps the DATA under a plot the
# user built, carrying the strips, the traces and the selection forward, which
# is attach_raw's documented 0194 case reached by a different gesture. Adding it
# is what keeps GX4's count claim true AND puts the new site under GX1's
# capture-before-regenerate order check.
# ⚠ `new_subwin` / `close_subwin` ADDED BY THE SUBWINDOWS STAGE 1: ordinary
# content mutations that carry every other strip forward, so gx_must.
# ⚠ `clear_subwin` ADDED BY STAGE 3 (the Replace destination): it empties ONE
# subwindow and carries every other strip forward, so gx_must too.
# ⚠ `grid_toggle` became `grid_apply` (SW23, 2026-10-15): Ctrl-G and
# Ctrl-Shift-G share one body, which is where the capture and the regenerate
# now are.
# ⚠ `set_text_size` ADDED BY ITEM 22 (the aA button): a window option like the
# grid, so no undo point, but it regenerates every strip from the model, so the
# selection must be folded first -- grid_apply's issue-0194 case exactly.
# ⚠ `set_axis_scale` ADDED BY THE AXIS CONTEXT MENU (2026-11-09): the RMB
# Linear/Log menu's act, axes_ok's write path for one axis, so gx_must like it.
# ⚠ `sw_stored_settle` ADDED WITH ISSUE 1736 (2026-11-24): the rebuild after a
# viewer door's Replace handed stored views back to the strips that took their
# traces again. It writes windows into the model and carries every other strip
# forward, so gx_must.
# ⚠ `owned_clear` ADDED WITH ISSUE 1765 (2026-11-25): the Replace of ASE-L's
# plot takes ASE-L's own traces out of the target subwindow and carries every
# other strip, and every trace plotted by hand, forward, so gx_must.
# ⚠ `hold_settle` ADDED WITH THE SAME ISSUE: after a load that read nothing it
# puts back what was done to the traces plotted by hand before the load (their
# pins, the names of the kept data) and rebuilds once, carrying every strip.
# ⚠ `overlay_latest` ADDED WITH ISSUE 1780 (2026-11-26): Alt-Shift-P appends a
# later version to the strips whose waveforms show earlier data and carries
# every strip forward, so gx_must.
# ⚠ `unpin_and_tidy` ADDED WITH THE SAME ISSUE (hold_release's and
# hold_manual's step): when it takes the later versions of a waveform out it
# rebuilds at once, so that the strips and the model number the traces alike
# before the load that follows folds the strips again.
set gx_must {configure_apply display_raw attach_raw add_trace add_graph
             plot_signals grid_apply sharedx_toggle apply_range wheel_zoom
             pan_x axes_ok set_axis_scale
             select_tab new_tab close_tab paste_traces paste_payload
             rawbar_load new_subwin close_subwin clear_subwin set_text_size
             sw_stored_settle owned_clear hold_settle overlay_latest unpin_and_tidy}
set gx_pre  {move_strip move_trace move_traces move_trace_to_new_strip
             split_strip delete_empty_strips delete_items}
set gx_exempt {restore state_apply clear_all}
# TABS (doc/claude/specs/waveform_viewer_tabs.md). All five carry the fold and
# then regenerate, so they are gx_must, not exemptions -- and the reason is NOT
# the one the exemptions give. `restore`/`state_apply`/`clear_all` replace the
# model wholesale from a source that owes the outgoing rects nothing; a tab
# switch replaces it from a source (the stash) that is ABOUT TO BE WRITTEN with
# those very rects, so the fold is what carries the outgoing tab's selection
# into the record being frozen. `paste_*` are ordinary content mutations.

foreach p $gx_must {
  set b [wvproc_body $wsrc wviewer::$p]
  set ci [string first {wviewer::capture_live_view_state $token} $b]
  set ri [string first {wviewer::regenerate $token} $b]
  # ORDER, not presence: a capture placed after the regenerate (or after a
  # structural mutation, where the 1:1 guard silently refuses it) reads as
  # installed and folds nothing.
  check_true "GX1 $p folds the live rect state BEFORE it regenerates" \
    [expr {$ci >= 0 && $ri >= 0 && $ci < $ri}]
}
foreach p $gx_exempt {
  # the body must actually have been FOUND: wvproc_body returns {} on a rename
  # or a reformatted signature, and `regexp -all` over {} is 0 — this leg is the
  # only one of the three that a miss would make vacuously green
  check_true "GX2 $p was found in the source" \
    [expr {[wvproc_body $wsrc wviewer::$p] ne {}}]
  check "GX2 $p is exempt — it replaces the model wholesale" \
    [regexp -all {capture_live_(view|graph)_state} [wvproc_body $wsrc wviewer::$p]] 0
}
foreach p $gx_pre {
  # the seven pre-0194 sites keep the FULL capture (a content edit means to
  # freeze the view it is editing); 0194 must not have converted them. ANCHORED:
  # `capture_live_graph_state $token` is a strict PREFIX of the auto-safe
  # `... $token 0 1`, so a `string first` would report green on exactly the
  # conversion this leg exists to forbid.
  check "GX3 $p still takes the full capture, not the selection-only one" \
    [regexp -all {capture_live_graph_state \$token *(;#[^\n]*)?\n} \
       [wvproc_body $wsrc wviewer::$p]] 1
}
# no unclassified site: 18 + 7 + 3 accounts for every `regenerate $token` call
# (18 since item 13 added rawbar_load; the sum is computed below, not hardcoded)
check "GX4 every regenerate call site is classified by the rule" \
  [pcall {count_emitters $wv {wviewer::regenerate \$token}}] \
  [expr {[llength $gx_must] + [llength $gx_pre] + [llength $gx_exempt]}]

check "GX5 the selection-only wrapper is the ONLY new capture flavour" \
  [count_emitters $wv {proc wviewer::capture_live_view_state}] 1
check_true "GX5 ...and it asks for skip_ranges" \
  [regexp {capture_live_graph_state \$token 0 1} \
     [wvproc_body $wsrc wviewer::capture_live_view_state]]
check "GX6 skip_ranges is the third arg" \
  [info args wviewer::capture_live_graph_state] {token skip_markers skip_ranges}
# ...defaulting OFF, so the seven content sites and marker_changed are unchanged.
# pcall'd: `info default` THROWS on a missing argument, and a throw here would
# abort the whole script — including the behavioural legs that are the point.
check "GX6 ...and defaults to 0" \
  [pcall {lindex [info default wviewer::capture_live_graph_state skip_ranges gxd; \
                  set gxd] 0}] 0
# THE TWO hazards skip_ranges exists for, and it must not write the ranges at
# ALL: (1) graph_props always emits a concrete x1/x2/y1/y2, so folding an axis
# the model left on `{}` would PIN it — autozoom lost on every resize; (2) under
# `sharedx 1` regenerate puts graph 0's x on every other strip's RECT while the
# model keeps each strip's own, so folding a PINNED axis back would overwrite
# every strip's stored window with graph 0's, permanently and with no undo
# point. Hence a plain `continue`, not a cleverer test.
check_true "GX7 skip_ranges skips the range fold outright" \
  [regexp {if \{\$skip_ranges\} \{ continue \}} \
     [wvproc_body $wsrc wviewer::capture_live_graph_state]]
# ...and it gates the RANGES ONLY. The selection and the markers are
# absent-means-absent and must be folded at all twelve sites, so exactly two
# mentions may exist in the body: the argument and that one guard. A third
# would mean someone gated the selection with it, which reads identical in a
# single-strip fixture and would silently reinstate the whole bug.
check "GX7 skip_ranges gates the ranges and nothing else" \
  [regexp -all {skip_ranges} \
     [wvproc_body $wsrc wviewer::capture_live_graph_state]] 2
# a window OPTION captures but must NEVER push undo (spec waveform_viewer_modes
# §14: window options are outside the snapshot). The fix is "capture, not push".
foreach p {grid_toggle grid_toggle_subwin grid_apply sharedx_toggle} {
  check "GX8 $p captures but takes NO undo point" \
    [regexp -all {wviewer::push_undo} [wvproc_body $wsrc wviewer::$p]] 0
}

# GZP* — the view a rebuild carries across itself (user report 2026-11-16:
# Ctrl-G also zoom-fitted the window; then the user's ruling the same day that a
# resize, the aA text size and the Shared X toggle keep the view too). The
# behaviour is band GZ below, display arm only; these are the parts a counted
# arm can see.
check "GZP1 regenerate takes the carried view as its second argument" \
  [info args wviewer::regenerate] {token keep}
check "GZP1 ...defaulting to none, so every other call site rebuilds as before" \
  [pcall {info default wviewer::regenerate keep gzd; set gzd}] {}
check "GZP2 the carried tokens: both axis windows, the digital Y band, the dataset" \
  [pcall {wviewer::live_axis_tokens}] {x1 x2 y1 y2 ypos1 ypos2 dataset}
check "GZP3 live_axes on an unknown window answers nothing (no throw)" \
  [pcall {wviewer::live_axes no_such_viewer}] {}
# ORDER: the rects must be read while they are still the ones on screen, and
# the answer handed to the one regenerate.
foreach {gzp_p gzp_pat} {
  grid_apply      {wviewer::regenerate $token $keep}
  set_text_size   {wviewer::regenerate $token $keep}
  configure_apply {wviewer::regenerate $token $keep}
  sharedx_toggle  {[wviewer::sharedx_keep [dict get $lay graphs] $keep $was $now]}
} {
  set gzp_b [wvproc_body $wsrc wviewer::$gzp_p]
  set gzp_r [string first {set keep [wviewer::live_axes $token]} $gzp_b]
  set gzp_g [string first $gzp_pat $gzp_b]
  check_true "GZP4 $gzp_p reads the live axes, then regenerates with them" \
    [expr {$gzp_r >= 0 && $gzp_g > $gzp_r}]
}

# wviewer::sharedx_keep, PURE: what a Shared X toggle does to the carried view.
# a/b: two strips' live entries with DIFFERENT X and Y, so no leg can pass by
# two entries happening to be equal.
set gzk_a  {x1 0.2 x2 0.4 y1 1 y2 6 ypos1 0 ypos2 2 dataset -1}
set gzk_b  {x1 0.3 x2 0.5 y1 7.5 y2 8.5 ypos1 0 ypos2 2 dataset 0}
set gzk_bm {x1 0.2 x2 0.4 y1 7.5 y2 8.5 ypos1 0 ypos2 2 dataset 0}
set gzk_by {y1 7.5 y2 8.5 ypos1 0 ypos2 2 dataset 0}
set gzg_auto [list [wviewer::empty_graph] [wviewer::empty_graph]]
set gzg_own  [list [dict replace [wviewer::empty_graph] x1 0.0 x2 1e-3] \
                   [dict replace [wviewer::empty_graph] x1 0.0 x2 1e-6]]
set gzg_same [list [dict replace [wviewer::empty_graph] x1 0 x2 1e-3] \
                   [dict replace [wviewer::empty_graph] x1 0.0 x2 0.001]]
set gzk_ab [list $gzk_a $gzk_b]
check "GZP6 no change of state: the carried view as it is" \
  [list [pcall {wviewer::sharedx_keep $gzg_own $gzk_ab 1 1}] \
        [pcall {wviewer::sharedx_keep $gzg_own $gzk_ab 0 0}]] [list $gzk_ab $gzk_ab]
check "GZP7 turned ON: the other strip takes the first strip's X as shown, Y its own" \
  [list [pcall {wviewer::sharedx_keep $gzg_own $gzk_ab 0 1}] \
        [pcall {wviewer::sharedx_keep $gzg_auto $gzk_ab 0 1}]] \
  [list [list $gzk_a $gzk_bm] [list $gzk_a $gzk_bm]]
check "GZP8 turned OFF, no window of its own (both auto): keeps the X it shows" \
  [pcall {wviewer::sharedx_keep $gzg_auto $gzk_ab 1 0}] $gzk_ab
check "GZP8 turned OFF, the same window spelled differently: keeps it too" \
  [pcall {wviewer::sharedx_keep $gzg_same $gzk_ab 1 0}] $gzk_ab
check "GZP9 turned OFF, a stored window of its own: X goes back to the model, Y stays" \
  [pcall {wviewer::sharedx_keep $gzg_own $gzk_ab 1 0}] [list $gzk_a $gzk_by]
check "GZP9 ...and so does a strip that is auto beside a pinned first strip" \
  [pcall {wviewer::sharedx_keep [list [lindex $gzg_own 0] [wviewer::empty_graph]] $gzk_ab 1 0}] \
  [list $gzk_a $gzk_by]
check "GZP10 turned ON with nothing read off the first strip: X is left to the model" \
  [pcall {wviewer::sharedx_keep $gzg_auto [list {} $gzk_b] 0 1}] [list {} $gzk_by]
# two subwindows: each follows ITS OWN first strip (spec SW13/SW14)
set gzk_c {x1 5 x2 6 y1 0 y2 1 ypos1 0 ypos2 2 dataset -1}
set gzk_d {x1 7 x2 8 y1 2 y2 3 ypos1 0 ypos2 2 dataset -1}
set gzk_dm {x1 5 x2 6 y1 2 y2 3 ypos1 0 ypos2 2 dataset -1}
set gzg_sw {}
foreach gzp_t {1 1 2 2} { lappend gzg_sw [dict replace [wviewer::empty_graph] sw $gzp_t] }
check "GZP11 the fixture really is two subwindows of two strips" \
  [pcall {wviewer::sw_runs $gzg_sw}] {{0 1} {2 3}}
check "GZP11 turned ON: each subwindow's strips follow their own first strip" \
  [pcall {wviewer::sharedx_keep $gzg_sw [list $gzk_a $gzk_b $gzk_c $gzk_d] 0 1}] \
  [list $gzk_a $gzk_bm $gzk_c $gzk_dm]
check "GZP12 a carried view that is not one entry per strip is handed back as is" \
  [pcall {wviewer::sharedx_keep $gzg_own [list $gzk_a] 0 1}] [list $gzk_a]
check "GZP10 turned ON, nothing carried for the other strip: it still takes the first strip's X" \
  [pcall {wviewer::sharedx_keep $gzg_auto [list $gzk_a {}] 0 1}] \
  [list $gzk_a {x1 0.2 x2 0.4}]
# wviewer::axes_same / axis_sigs / shared_graphs, PURE: an axis is carried only
# while the model still says about its range and scale what the last rebuild
# drew. The strip's traces are view_entries' business (GZP17), not axes_same's.
set gzs_g  [dict replace [wviewer::empty_graph] traces {{vec a}} x1 0 x2 1]
set gzs_0  [lindex [wviewer::axis_sigs [list $gzs_g]] 0]
set gzs_x  [lindex [wviewer::axis_sigs [list [dict replace $gzs_g x2 2]]] 0]
set gzs_y  [lindex [wviewer::axis_sigs [list [dict replace $gzs_g y1 -1 y2 1]]] 0]
set gzs_lx [lindex [wviewer::axis_sigs [list [dict replace $gzs_g logx 1]]] 0]
set gzs_tr [lindex [wviewer::axis_sigs [list [dict replace $gzs_g traces {{vec a} {vec b}}]]] 0]
check "GZP14 the model unchanged: every token is carried" \
  [pcall {wviewer::axes_same $gzk_b $gzs_0 $gzs_0}] $gzk_b
check "GZP14 the model's X range changed: X is left to the model, the rest carried" \
  [pcall {wviewer::axes_same $gzk_b $gzs_0 $gzs_x}] $gzk_by
check "GZP14 ...and so for a change of X scale" \
  [pcall {wviewer::axes_same $gzk_b $gzs_0 $gzs_lx}] $gzk_by
check "GZP14 the model's Y range changed: Y and its digital band go, X and the dataset stay" \
  [pcall {wviewer::axes_same $gzk_b $gzs_0 $gzs_y}] {x1 0.3 x2 0.5 dataset 0}
check "GZP14 the strip's traces changed and nothing else: axes_same drops nothing" \
  [pcall {wviewer::axes_same $gzk_b $gzs_0 $gzs_tr}] $gzk_b
check "GZP14 ...the traces are in the signature all the same, as the strip's identity" \
  [list [dict get $gzs_0 tr] [dict get $gzs_tr tr]] {{{vec a}} {{vec a} {vec b}}}
check "GZP14 no record of the last rebuild, or nothing read off the rect: nothing carried" \
  [list [pcall {wviewer::axes_same $gzk_b {} $gzs_0}] [pcall {wviewer::axes_same {} $gzs_0 $gzs_0}]] {{} {}}
check_true "GZP14 the five signatures really differ where the legs say they do" \
  [expr {[dict get $gzs_0 x] ne [dict get $gzs_x x] && [dict get $gzs_0 y] eq [dict get $gzs_x y]
         && [dict get $gzs_0 y] ne [dict get $gzs_y y] && [dict get $gzs_0 x] eq [dict get $gzs_y x]
         && [dict get $gzs_0 x] ne [dict get $gzs_lx x] && [dict get $gzs_0 y] eq [dict get $gzs_lx y]
         && [dict get $gzs_0 x] eq [dict get $gzs_tr x] && [dict get $gzs_0 y] eq [dict get $gzs_tr y]
         && [dict get $gzs_0 tr] ne [dict get $gzs_tr tr]}]
proc gzs_xs {gs} { lmap G $gs {list [wviewer::dget $G x1 {}] [wviewer::dget $G x2 {}]} }
check "GZP15 shared_graphs: Shared X off draws every strip's own X" \
  [gzs_xs [pcall {wviewer::shared_graphs [dict create sharedx 0 graphs $gzg_own]}]] \
  {{0.0 1e-3} {0.0 1e-6}}
check "GZP15 ...on, the other strip is drawn with the first strip's" \
  [gzs_xs [pcall {wviewer::shared_graphs [dict create sharedx 1 graphs $gzg_own]}]] \
  {{0.0 1e-3} {0.0 1e-3}}
set gzg_sw4 {}
foreach {gzp_t gzp_x} {1 1 1 2 2 3 2 4} {
  lappend gzg_sw4 [dict replace [wviewer::empty_graph] sw $gzp_t x1 0 x2 $gzp_x]
}
check "GZP15 ...and within each subwindow only" \
  [gzs_xs [pcall {wviewer::shared_graphs [dict create sharedx 1 graphs $gzg_sw4]}]] \
  {{0 1} {0 1} {0 3} {0 3}}
check "GZP13 same_xwin: numbers compare as numbers, auto only equals auto" \
  [list [pcall {wviewer::same_xwin {x1 0 x2 1e-3} {x1 0.0 x2 0.001}}] \
        [pcall {wviewer::same_xwin {x1 {} x2 {}} {x1 {} x2 {}}}] \
        [pcall {wviewer::same_xwin {x1 {} x2 {}} {x1 0 x2 1}}] \
        [pcall {wviewer::same_xwin {x1 0 x2 1} {x1 0 x2 2}}]] {1 1 0 0}

# GZP16.. — the view carried across a rebuild that CHANGES the strips (user
# ruling 2026-11-16: Graph > Axes..., adding a trace and adding a strip keep the
# view too). The behaviour is band GV below, display arm only.
#
# wviewer::view_map, PURE: which strip on screen each new strip takes from.
# Traces are spelled as the model spells them; A..D are four different ones.
set gvm_A {expr va name {} vec va color 4}
set gvm_B {expr vb name {} vec vb color 5}
set gvm_C {expr vc name {} vec vc color 6}
set gvm_D {expr vd name {} vec vd color 7}
set gvm_o [list [list $gvm_A $gvm_B] [list $gvm_C]]
check "GZP16 nothing changed: every strip is itself" \
  [pcall {wviewer::view_map $gvm_o $gvm_o}] {{0 same} {1 same}}
check "GZP16 a strip appended: the old ones are themselves, the new one takes nothing" \
  [pcall {wviewer::view_map $gvm_o [list [list $gvm_A $gvm_B] [list $gvm_C] {}]}] \
  {{0 same} {1 same} {-1 {}}}
check "GZP16 a strip inserted in the middle: the ones after it are found by their traces" \
  [pcall {wviewer::view_map $gvm_o [list [list $gvm_A $gvm_B] {} [list $gvm_C]]}] \
  {{0 same} {-1 {}} {1 same}}
check "GZP16 a strip removed: the survivor is found, not taken by position" \
  [pcall {wviewer::view_map $gvm_o [list [list $gvm_C]]}] {{1 same}}
check "GZP16 a trace added: that strip is 'changed', the other 'same'" \
  [pcall {wviewer::view_map $gvm_o [list [list $gvm_A $gvm_B $gvm_D] [list $gvm_C]]}] \
  {{0 changed} {1 same}}
check "GZP16 a trace removed: 'changed' as well" \
  [pcall {wviewer::view_map $gvm_o [list [list $gvm_A] [list $gvm_C]]}] \
  {{0 changed} {1 same}}
check "GZP16 the first trace into an empty strip: nothing to take" \
  [pcall {wviewer::view_map [list [list $gvm_A] {}] [list [list $gvm_A] [list $gvm_D]]}] \
  {{0 same} {-1 {}}}
check "GZP16 every trace replaced: nothing in common, nothing taken" \
  [pcall {wviewer::view_map $gvm_o [list [list $gvm_D] [list $gvm_C]]}] \
  {{-1 {}} {1 same}}
# TWO STRIPS WITH THE SAME TRACES (one signal looked at in two places): a trace
# added to the FIRST must not hand the first strip's view to the second.
set gvm_dup [list [list $gvm_A] [list $gvm_A]]
check "GZP16 twin strips, a trace added to the first: each stays itself" \
  [pcall {wviewer::view_map $gvm_dup [list [list $gvm_A $gvm_D] [list $gvm_A]]}] \
  {{0 changed} {1 same}}
check "GZP16 twin strips, one inserted between them: order decides" \
  [pcall {wviewer::view_map $gvm_dup [list [list $gvm_A] {} [list $gvm_A]]}] \
  {{0 same} {-1 {}} {1 same}}
check "GZP16 twin strips, the first removed and SAID so: the survivor is the second" \
  [list [pcall {wviewer::view_map $gvm_dup [list [list $gvm_A]] {0}}] \
        [pcall {wviewer::view_map $gvm_dup [list [list $gvm_A]]}]] {{{1 same}} {{0 same}}}
check "GZP16 no strip on screen serves two: a second strip of the same trace takes nothing" \
  [pcall {wviewer::view_map [list [list $gvm_A $gvm_B]] [list [list $gvm_A $gvm_B] [list $gvm_A]]}] \
  {{0 same} {-1 {}}}
check "GZP16 of two candidates the one sharing more traces is taken" \
  [pcall {wviewer::view_map [list [list $gvm_A] [list $gvm_A $gvm_B $gvm_C]] \
            [list [list $gvm_A $gvm_B $gvm_D]]}] {{1 changed}}
check "GZP16 a removed strip serves nobody, even one sharing its traces" \
  [pcall {wviewer::view_map $gvm_o [list [list $gvm_A $gvm_D]] {0}}] {{-1 {}}}
check "GZP16 no strips either side" \
  [list [pcall {wviewer::view_map {} {}}] [pcall {wviewer::view_map $gvm_o {}}] \
        [pcall {wviewer::view_map {} [list [list $gvm_A]]}]] {{} {} {{-1 {}}}}
check "GZP16 trace_key: the color and the display name do not make another trace" \
  [list [expr {[wviewer::trace_key $gvm_A] eq [wviewer::trace_key [dict replace $gvm_A color 9 name zz]]}] \
        [expr {[wviewer::trace_key $gvm_A] eq [wviewer::trace_key $gvm_B]}] \
        [expr {[wviewer::trace_key $gvm_A] eq [wviewer::trace_key [dict replace $gvm_A rawfile /x.raw]]}] \
        [expr {[wviewer::trace_key $gvm_A] eq [wviewer::trace_key [dict replace $gvm_A sweep vx]]}]] \
  {1 0 0 0}
check "GZP16 ...so a recolored trace is still the strip's own ('changed', not lost)" \
  [pcall {wviewer::view_map [list [list $gvm_A]] [list [list [dict replace $gvm_A color 9]]]}] \
  {{0 changed}}

# wviewer::view_zoomed / view_drop, PURE
set gvz_left {x1 0 x2 1 y1 1 y2 6 ypos1 0 ypos2 2}
check "GZP17 view_zoomed: nothing moved since the fit" \
  [pcall {wviewer::view_zoomed {x1 0.0 x2 1.0 y1 1 y2 6.0 ypos1 0 ypos2 2 dataset -1} $gvz_left}] {}
check "GZP17 ...X moved, Y moved, both, and the digital band counts as Y" \
  [list [pcall {wviewer::view_zoomed {x1 0.2 x2 1 y1 1 y2 6 ypos1 0 ypos2 2} $gvz_left}] \
        [pcall {wviewer::view_zoomed {x1 0 x2 1 y1 1 y2 5 ypos1 0 ypos2 2} $gvz_left}] \
        [pcall {wviewer::view_zoomed {x1 0 x2 0.4 y1 2 y2 6 ypos1 0 ypos2 2} $gvz_left}] \
        [pcall {wviewer::view_zoomed {x1 0 x2 1 y1 1 y2 6 ypos1 0.5 ypos2 2} $gvz_left}]] \
  {x y {x y} y}
check "GZP17 ...no record of the fit, or nothing read: not a zoom" \
  [list [pcall {wviewer::view_zoomed {x1 0.2 x2 0.4 y1 1 y2 6} {}}] \
        [pcall {wviewer::view_zoomed {} $gvz_left}] \
        [pcall {wviewer::view_zoomed {x1 0.2 x2} $gvz_left}]] {{} {} {}}
check "GZP17 view_drop: X's two ends, Y's two ends with its band, both, neither" \
  [list [pcall {wviewer::view_drop $gzk_b x}] [pcall {wviewer::view_drop $gzk_b y}] \
        [pcall {wviewer::view_drop $gzk_b xy}] [pcall {wviewer::view_drop $gzk_b {}}]] \
  [list $gzk_by {x1 0.3 x2 0.5 dataset 0} {dataset 0} $gzk_b]

# wviewer::view_entries, PURE: the keep list out of a view. One strip on screen
# with traces A B, auto on both axes, fitted to gvz_left; `cur` is what the
# rect holds now.
proc gve_view {cur {left {}} {tr {}}} {
  global gvm_A gvm_B gvz_left
  if {$left eq {}} { set left $gvz_left }
  if {$tr eq {}} { set tr [list $gvm_A $gvm_B] }
  return [list [dict create x {{} {} 0} y {{} {} 0} tr $tr left $left cur $cur]]
}
proc gve_sig {tr {x {{} {} 0}} {y {{} {} 0}}} { return [list [dict create x $x y $y tr $tr]] }
set gve_fit  {x1 0 x2 1 y1 1 y2 6 ypos1 0 ypos2 2 dataset -1}
set gve_zx   {x1 0.2 x2 0.4 y1 1 y2 6 ypos1 0 ypos2 2 dataset -1}
set gve_zxy  {x1 0.2 x2 0.4 y1 2 y2 3 ypos1 0 ypos2 2 dataset -1}
set gve_same [list $gvm_A $gvm_B]
set gve_more [list $gvm_A $gvm_B $gvm_D]
check "GZP18 the strip as it was, NOTHING moved: no axis is carried (the rebuild it always got)" \
  [pcall {wviewer::view_entries [gve_view $gve_fit] [gve_sig $gve_same]}] {{dataset -1}}
check "GZP18 the strip as it was, zoomed: every token carried, with what it was fitted to" \
  [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig $gve_same]}] \
  [list [dict replace $gve_zxy left $gvz_left]]
check "GZP18 ...zoomed in X only: the Y nobody moved is carried too (not fitted over the zoom)" \
  [pcall {wviewer::view_entries [gve_view $gve_zx] [gve_sig $gve_same]}] \
  [list [dict replace $gve_zx left $gvz_left]]
check "GZP18 a trace added to an UNZOOMED strip: both axes are fitted again, the dataset stays" \
  [pcall {wviewer::view_entries [gve_view $gve_fit] [gve_sig $gve_more]}] {{dataset -1}}
check "GZP18 a trace added, X zoomed and Y untouched: X is kept, Y fitted again" \
  [pcall {wviewer::view_entries [gve_view $gve_zx] [gve_sig $gve_more]}] \
  [list [dict create x1 0.2 x2 0.4 dataset -1 left $gvz_left]]
check "GZP18 a trace added, both axes zoomed: both kept" \
  [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig $gve_more]}] \
  [list [dict replace $gve_zxy left $gvz_left]]
check "GZP18 the model gave X a range since: X is the model's, on a 'same' strip too" \
  [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig $gve_same {0 5 0}]}] \
  [list [dict create y1 2 y2 3 ypos1 0 ypos2 2 dataset -1 left $gvz_left]]
check "GZP18 `drop` takes the named axes of the named strip out, whatever the rules say" \
  [list [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig $gve_same] {0 x}}] \
        [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig $gve_same] {0 xy}}] \
        [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig $gve_same] {1 xy}}]] \
  [list [list [dict create y1 2 y2 3 ypos1 0 ypos2 2 dataset -1 left $gvz_left]] \
        {{dataset -1}} \
        [list [dict replace $gve_zxy left $gvz_left]]]
check "GZP18 `gone`: a removed strip's view goes to nobody" \
  [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig $gve_same] {} {0}}] {{}}
check "GZP18 a strip sharing no trace with the screen, and a rect that answered nothing: nothing" \
  [list [pcall {wviewer::view_entries [gve_view $gve_zxy] [gve_sig [list $gvm_C]]}] \
        [pcall {wviewer::view_entries [gve_view {}] [gve_sig $gve_same]}]] {{{}} {{}}}
check "GZP18 one entry per strip of the NEW model, however many were on screen" \
  [lmap gve_e [pcall {wviewer::view_entries [gve_view $gve_zxy] \
     [concat [gve_sig {}] [gve_sig $gve_same] [gve_sig {}]]}] {dict exists $gve_e x1}] {0 1 0}
check "GZP18 an empty view is the plain rebuild" \
  [list [pcall {wviewer::view_entries {} [gve_sig $gve_same]}] \
        [pcall {wviewer::view_keep no_such_viewer [gve_view $gve_zxy]}]] {{{}} {}}

# wviewer::drawn_records, PURE: what regenerate remembers of each axis.
set gvd_sig  [gve_sig $gve_same]
set gvd_read {x1 0.2 x2 0.4 y1 1.1 y2 3.4 ypos1 0 ypos2 2}
check "GZP19 nothing carried: each axis is remembered as it reads off the fresh rect" \
  [dict get [lindex [pcall {wviewer::drawn_records $gvd_sig [list $gvd_read] {}}] 0] left] $gvd_read
check "GZP19 X carried: X is remembered as it was last FITTED, so the zoom is still one" \
  [dict get [lindex [pcall {wviewer::drawn_records $gvd_sig [list $gvd_read] \
     [list [dict create x1 0.2 x2 0.4 dataset -1 left $gvz_left]]}] 0] left] \
  {x1 0 x2 1 y1 1.1 y2 3.4 ypos1 0 ypos2 2}
check "GZP19 both carried: both as last fitted; an entry with no `left`: as read" \
  [list [dict get [lindex [pcall {wviewer::drawn_records $gvd_sig [list $gvd_read] \
           [list [dict replace $gve_zxy left $gvz_left]]}] 0] left] \
        [dict get [lindex [pcall {wviewer::drawn_records $gvd_sig [list $gvd_read] \
           [list $gve_zxy]}] 0] left]] [list $gvz_left $gvd_read]
check "GZP19 the record holds the strip's signature too" \
  [dict remove [lindex [pcall {wviewer::drawn_records $gvd_sig [list $gvd_read] {}}] 0] left] \
  [lindex $gvd_sig 0]
check "GZP19 pinned_axes: an axis is pinned only with BOTH ends given" \
  [pcall {wviewer::pinned_axes [list \
     [dict replace [wviewer::empty_graph] x1 0 x2 1] \
     [wviewer::empty_graph] \
     [dict replace [wviewer::empty_graph] x1 0 y1 1 y2 2] \
     [dict replace [wviewer::empty_graph] x1 0 x2 1 y1 1 y2 2]]}] {0 x 2 y 3 xy}

# THE CALL SITES. Every proc that rebuilds the strips either carries the view or
# is named here with the reason it does not. The population is gx_must + gx_pre
# + gx_exempt, which GX4 holds equal to every call site, so a new rebuild
# arrives as a red naming it.
#   new data loaded by hand (the windows fitted the old data): display_raw rawbar_load
#   the layout replaced or emptied: restore clear_all
#   another tab's strips (the tab stash holds each tab's view): select_tab new_tab close_tab
#   gx_pre: the view is frozen into the MODEL first (GX3), so the plain rebuild shows it
# attach_raw is NOT in the list since issue 1733 (user report and ruling
# 2026-11-22: a Direct Plot, and a re-run that plots in Replace mode, keep the
# zoom). It carries: the same data by add_trace's rule, new data by
# view_new_data's (GZP27-GZP31 here, band PV of test_ase_plot_outputs on the
# real path).
set gvc_plain [concat {display_raw rawbar_load restore clear_all
                       select_tab new_tab close_tab} $gx_pre]
set gvc_bad {}
set gvc_carry {}
foreach p [concat $gx_must $gx_pre $gx_exempt] {
  set gvc_plainn 0
  set gvc_keepn 0
  foreach {gvc_m gvc_rest} [regexp -all -inline -line {wviewer::regenerate \$token(.*)$} \
                              [wvproc_body $wsrc wviewer::$p]] {
    if {[regexp {^\s*(;.*)?$} $gvc_rest]} { incr gvc_plainn } else { incr gvc_keepn }
  }
  if {$p in $gvc_plain} {
    if {$gvc_keepn != 0 || $gvc_plainn == 0} { lappend gvc_bad $p }
  } else {
    if {$gvc_plainn != 0 || $gvc_keepn == 0} { lappend gvc_bad $p }
    lappend gvc_carry $p
  }
}
check "GZP20 every rebuild carries the view, or is named with why it does not" $gvc_bad {}
check_true "GZP20 ...and the scan found both kinds (add_trace carries, restore does not)" \
  [expr {{add_trace} in $gvc_carry && {state_apply} in $gvc_carry && {apply_range} in $gvc_carry
         && {restore} ni $gvc_carry && [llength $gvc_carry] + [llength $gvc_plain]
            == [llength $gx_must] + [llength $gx_pre] + [llength $gx_exempt]}]
check_true "GZP20 attach_raw is one that carries (issue 1733), and the hand loads are not" \
  [expr {{attach_raw} in $gvc_carry && {rawbar_load} ni $gvc_carry && {display_raw} ni $gvc_carry}]
# attach_raw's own ORDER, which GZP21's model-write patterns cannot see: it
# writes no model, it replaces the DATA. The view and the data the view was
# drawn on are read before ase::attach_dbs moves the registry, the data it
# brings after, and the rebuild is handed what the verdict picked.
set gvc_ab [wvproc_body $wsrc wviewer::attach_raw]
set gvc_ai [string first {ase::attach_dbs $rawfile} $gvc_ab]
check_true "GZP21 attach_raw reads the view, the old data and the files BEFORE attach_dbs, the new data after" \
  [expr {$gvc_ai > 0
         && [string first {set view [wviewer::view_take $token]} $gvc_ab] >= 0
         && [string first {set view [wviewer::view_take $token]} $gvc_ab] < $gvc_ai
         && [string first {set was [wviewer::attach_db]} $gvc_ab] < $gvc_ai
         && [string first {set rec [wviewer::attach_stamp } $gvc_ab] < $gvc_ai
         && [string first {wviewer::attach_is_same $prev $rec} $gvc_ab] < $gvc_ai
         && [string first {set now [wviewer::attach_db]} $gvc_ab] > $gvc_ai}]
check_true "GZP21 ...same data: view_keep as add_trace hands it; new data: view_keep over view_new_data" \
  [expr {[regexp {if \{\$same\} \{\s*set keep \[wviewer::view_keep \$token \$view\]\s*\} else \{\s*set keep \[wviewer::view_keep \$token \[wviewer::view_new_data \$view \$was \$now\]\]\s*\}\s*wviewer::regenerate \$token \$keep} $gvc_ab]}]
# ORDER: the view is read off the rects BEFORE the proc writes the model.
foreach p $gvc_carry {
  set gvc_b [wvproc_body $wsrc wviewer::$p]
  set gvc_t [string first {wviewer::view_take $token} $gvc_b]
  if {$gvc_t < 0} { set gvc_t [string first {wviewer::live_axes $token} $gvc_b] }
  set gvc_w -1
  foreach gvc_pat {{wviewer::set_graphs $token} {wviewer::sw_splice_apply $token}
                   {dict set layouts $token}} {
    set gvc_i [string first $gvc_pat $gvc_b]
    if {$gvc_i >= 0 && ($gvc_w < 0 || $gvc_i < $gvc_w)} { set gvc_w $gvc_i }
  }
  if {$p eq {state_apply}} {
    # the snapshot goes in here; the view is its caller's, taken before the call
    set gvc_h [wvproc_body $wsrc wviewer::history_step]
    check_true "GZP21 history_step reads the view, then hands it to state_apply" \
      [expr {[string first {set view [wviewer::view_take $token]} $gvc_h] >= 0
             && [string first {set view [wviewer::view_take $token]} $gvc_h]
                < [string first {wviewer::state_apply $token $snap $view} $gvc_h]}]
    continue
  }
  check_true "GZP21 $p reads the view before it writes the model" \
    [expr {$gvc_t >= 0 && ($gvc_w < 0 || $gvc_t < $gvc_w)}]
}
# wviewer::view_align, PURE: a fresh strip joins the X window its subwindow
# shows. Three strips of one subwindow; strip 0 is the fresh one unless said.
set gva_sigA [lindex [gve_sig [list $gvm_A]] 0]
set gva_sigB [lindex [gve_sig [list $gvm_B]] 0]
set gva_sigC [lindex [gve_sig [list $gvm_C]] 0]
set gva_sigs [list $gva_sigA $gva_sigB $gva_sigC]
set gva_e1 [dict replace $gve_zxy left $gvz_left]
set gva_run {{0 2}}
check "GZP25 a fresh strip takes the X window its neighbour carries, with what that was fitted to" \
  [pcall {wviewer::view_align [list {} $gva_e1 {dataset -1}] $gva_sigs $gva_run {0}}] \
  [list {x1 0.2 x2 0.4 left {x1 0 x2 1}} $gva_e1 {dataset -1}]
check "GZP25 ...Y is not given: the rebuild fits it over that window" \
  [dict exists [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] $gva_sigs $gva_run {0}}] 0] y1] 0
check "GZP25 a neighbour whose MODEL pins X gives that window, with blank ends to be measured against" \
  [lindex [pcall {wviewer::view_align [list {} {dataset -1} {}] \
     [list $gva_sigA [lindex [gve_sig [list $gvm_B] {0.3 0.5 0}] 0] $gva_sigC] $gva_run {0}}] 0] \
  {x1 0.3 x2 0.5 left {x1 {} x2 {}}}
check "GZP25 ...and blank ends read as moved, so the window is carried again next time" \
  [pcall {wviewer::view_zoomed {x1 0.3 x2 0.5 y1 1 y2 2} {x1 {} x2 {} y1 1 y2 2}}] x
check "GZP25 no neighbour's X is known (all to be fitted): the fresh strip is left to the fit" \
  [pcall {wviewer::view_align [list {} {dataset -1} {}] $gva_sigs $gva_run {0}}] [list {} {dataset -1} {}]
check "GZP25 a fresh strip whose own model pins X keeps the model's" \
  [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] \
     [list [lindex [gve_sig [list $gvm_A] {0 9 0}] 0] $gva_sigB $gva_sigC] $gva_run {0}}] 0] {}
check "GZP25 a fresh strip with no trace is given nothing" \
  [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] \
     [list [lindex [gve_sig {}] 0] $gva_sigB $gva_sigC] $gva_run {0}}] 0] {}
check "GZP25 a strip that is not fresh is never given a window" \
  [pcall {wviewer::view_align [list {dataset -1} $gva_e1 {}] $gva_sigs $gva_run {}}] \
  [list {dataset -1} $gva_e1 {}]
check "GZP25 another subwindow's window is not given" \
  [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] $gva_sigs {{0 0} {1 2}} {0}}] 0] {}
check "GZP25 a neighbour on another database, another X column or another X scale gives nothing" \
  [list [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] \
           [list $gva_sigA [lindex [gve_sig [list [dict replace $gvm_B rawfile /x.raw sim_type ac]]] 0] $gva_sigC] \
           $gva_run {0}}] 0] \
        [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] \
           [list $gva_sigA [lindex [gve_sig [list [dict replace $gvm_B sweep vx]]] 0] $gva_sigC] \
           $gva_run {0}}] 0] \
        [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] \
           [list [lindex [gve_sig [list $gvm_A] {{} {} 1}] 0] $gva_sigB $gva_sigC] $gva_run {0}}] 0]] \
  {{} {} {}}
check "GZP25 of two neighbours showing different windows the NEARER gives" \
  [list [lindex [pcall {wviewer::view_align [list $gva_e1 {x1 5 x2 6} {}] $gva_sigs $gva_run {2}}] 2] \
        [lindex [pcall {wviewer::view_align [list {} {x1 5 x2 6} $gva_e1] $gva_sigs $gva_run {0}}] 0]] \
  {{x1 5 x2 6 left {x1 {} x2 {}}} {x1 5 x2 6 left {x1 {} x2 {}}}}
check "GZP25 a strip in `skip` neither gives nor takes" \
  [list [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] $gva_sigs $gva_run {0} {1}}] 0] \
        [lindex [pcall {wviewer::view_align [list {} $gva_e1 {}] $gva_sigs $gva_run {0} {0}}] 0]] {{} {}}
check "GZP25 a keep list that is not one entry per strip is handed back as is" \
  [pcall {wviewer::view_align [list {} $gva_e1] $gva_sigs $gva_run {0}}] [list {} $gva_e1]
check "GZP25 view_fresh: the strips with nothing on screen to take from" \
  [list [pcall {wviewer::view_fresh [gve_view $gve_zxy] \
                  [concat [gve_sig [list $gvm_C]] [gve_sig $gve_same] [gve_sig {}]]}] \
        [pcall {wviewer::view_fresh [gve_view $gve_zxy] [gve_sig $gve_more]}] \
        [pcall {wviewer::view_fresh [gve_view $gve_zxy] [gve_sig $gve_same] {0}}]] {{0 2} {} 0}
check "GZP25 x_source: traces on the loaded sweep are one source; a database or an X column makes another" \
  [list [expr {[wviewer::x_source [list $gvm_A $gvm_B]] eq [wviewer::x_source [list $gvm_C]]}] \
        [expr {[wviewer::x_source [list $gvm_A]] eq [wviewer::x_source [list [dict replace $gvm_A rawfile /x.raw]]]}] \
        [expr {[wviewer::x_source [list $gvm_A]] eq [wviewer::x_source [list [dict replace $gvm_A sweep vx]]]}]] \
  {1 0 0}
# ============================================================================
# GZP27.. — NEW DATA UNDER A KEPT VIEW (issue 1733; user report 2026-11-22: a
# Direct Plot after a zoom snapped every strip back to the full sweep; ruling the
# same day: "yes, re-run which then plots in Replace mode should retain zoom
# level, not reset it"). The pure half; the real path (dp_finish, plot_outputs,
# a rewritten raw, a hand load in between) is band PV of
# tests/headless/test_ase_plot_outputs.tcl, display arm.
# ============================================================================
# the data a view was drawn on, as wviewer::attach_db answers it
set gzn_tran  {type tran x0 time cur {/r/a.raw tran}}
set gzn_tran2 {type tran x0 time cur {/r/b.raw tran}}
set gzn_ac    {type ac x0 frequency cur {/r/a.raw ac}}
set gzn_dc1   {type dc x0 v-sweep cur {/r/a.raw dc}}
set gzn_dc2   {type dc x0 i-sweep cur {/r/a.raw dc}}
set gzn_s     [lindex [gve_sig [list $gvm_A $gvm_B]] 0]
# Every answer of a verb issue 1733 added is read through one of these, which
# answer a VALUE (ABSENT, NOPROC) on any failure, never raise: on a tree without
# the verb (the pre-fix sources swapped in) these bands ASSERT red, and every
# row after them still runs, instead of the suite dying on a bare `dict get`.
proc gzn_dg {d args} {
  if {[catch {dict get $d {*}$args} v]} { return ABSENT }
  return $v
}
# dget with a default for an absent key, ABSENT for an answer that is no dict
proc gzn_dd {d k def} {
  if {[catch {dict exists $d $k} e]} { return ABSENT }
  if {$e} { return [dict get $d $k] }
  return $def
}
proc gzn_ex {d k} {
  if {[catch {dict exists $d $k} e]} { return ABSENT }
  return $e
}
proc gzn_args {p} {
  if {[catch {info args $p} v]} { return NOPROC }
  return $v
}
check "GZP27 x_resolve: a trace on the current database takes its analysis and its X; the path does not enter" \
  [lmap gzn_t [gzn_dg [pcall {wviewer::x_resolve $gzn_s $gzn_tran}] tr] {
     list [gzn_dg $gzn_t sim_type] [gzn_dg $gzn_t sweep] [gzn_ex $gzn_t rawfile]}] \
  {{tran time 0} {tran time 0}}
check "GZP27 ...a trace on a database of its own, or with an X column of its own, keeps it" \
  [lmap gzn_t [gzn_dg [pcall {wviewer::x_resolve [lindex [gve_sig [list \
       [dict replace $gvm_A rawfile /v.vcd sim_type vcd] [dict replace $gvm_B sweep vx]]] 0] $gzn_tran}] tr] {
     list [gzn_dd $gzn_t sim_type {}] [gzn_dd $gzn_t sweep {}]}] \
  {{vcd {}} {tran vx}}
check "GZP27 x_same over x_resolve: a tran re-run, and another tran file, are the same X" \
  [list [pcall {wviewer::x_same [wviewer::x_resolve $gzn_s $gzn_tran] [wviewer::x_resolve $gzn_s $gzn_tran]}] \
        [pcall {wviewer::x_same [wviewer::x_resolve $gzn_s $gzn_tran] [wviewer::x_resolve $gzn_s $gzn_tran2]}]] {1 1}
check "GZP27 ...another analysis, another X column, another X scale, or no data before, are not" \
  [list [pcall {wviewer::x_same [wviewer::x_resolve $gzn_s $gzn_tran] [wviewer::x_resolve $gzn_s $gzn_ac]}] \
        [pcall {wviewer::x_same [wviewer::x_resolve $gzn_s $gzn_dc1] [wviewer::x_resolve $gzn_s $gzn_dc2]}] \
        [pcall {wviewer::x_same [wviewer::x_resolve $gzn_s $gzn_tran] \
                  [wviewer::x_resolve [dict replace $gzn_s x {{} {} 1}] $gzn_tran]}] \
        [pcall {wviewer::x_same [wviewer::x_resolve $gzn_s {}] [wviewer::x_resolve $gzn_s $gzn_tran]}]] {0 0 0 0}
check "GZP27 view_align asks x_same, the one notion of the same X (no second copy of it)" \
  [list [regexp -all {wviewer::x_same } [wvproc_body $wsrc wviewer::view_align]] \
        [regexp -all {wviewer::x_source } [wvproc_body $wsrc wviewer::view_align]]] {1 0}

# wviewer::view_new_data, PURE: the view a rebuild on new data may carry
proc gzn_view {cur {left {}}} {
  global gvz_left gzn_s
  if {$left eq {}} { set left $gvz_left }
  return [list [dict replace $gzn_s left $left cur $cur]]
}
proc gzn_cur {v} {
  if {[catch {dict get [lindex $v 0] cur} c]} { return ABSENT }
  return $c
}
# the first record of a view without its `cur`, ABSENT for an answer that is no view
proc gzn_rest {v} {
  if {[catch {dict remove [lindex $v 0] cur} r]} { return ABSENT }
  return $r
}
check "GZP28 nothing moved: nothing kept, so the strip is rebuilt as a plain regenerate rebuilds it" \
  [gzn_cur [pcall {wviewer::view_new_data [gzn_view $gve_fit] $gzn_tran $gzn_tran}]] {}
check "GZP28 X moved: X kept with xnew, the Y nobody moved is NOT, nor the dataset" \
  [gzn_cur [pcall {wviewer::view_new_data [gzn_view $gve_zx] $gzn_tran $gzn_tran2}]] {x1 0.2 x2 0.4 xnew 1}
check "GZP28 both moved: both kept" \
  [gzn_cur [pcall {wviewer::view_new_data [gzn_view $gve_zxy] $gzn_tran $gzn_tran}]] \
  {x1 0.2 x2 0.4 xnew 1 y1 2 y2 3 ypos1 0 ypos2 2}
check "GZP28 Y moved alone: Y kept, X fitted" \
  [gzn_cur [pcall {wviewer::view_new_data [gzn_view {x1 0 x2 1 y1 2 y2 3 ypos1 0 ypos2 2 dataset -1}] \
                     $gzn_tran $gzn_tran}]] {y1 2 y2 3 ypos1 0 ypos2 2}
# (issue 1733 review: a moved Y kept over another analysis left the curve off
# screen, a tran window over AC magnitudes)
check "GZP28 no longer the same X (an ac file where a tran was): another plot, nothing kept, a moved Y neither" \
  [list [gzn_cur [pcall {wviewer::view_new_data [gzn_view $gve_zx] $gzn_tran $gzn_ac}]] \
        [gzn_cur [pcall {wviewer::view_new_data [gzn_view $gve_zxy] $gzn_tran $gzn_ac}]] \
        [gzn_cur [pcall {wviewer::view_new_data [gzn_view {x1 0 x2 1 y1 2 y2 3 ypos1 0 ypos2 2 dataset -1}] \
                           $gzn_tran $gzn_ac}]] \
        [gzn_cur [pcall {wviewer::view_new_data [gzn_view $gve_zxy] $gzn_dc1 $gzn_dc2}]]] \
  {{} {} {} {}}
check "GZP28 a tracked dataset is never kept (it numbers the old data's datasets)" \
  [gzn_ex [gzn_cur [pcall {wviewer::view_new_data \
     [gzn_view {x1 0.2 x2 0.4 y1 2 y2 3 ypos1 0 ypos2 2 dataset 3}] $gzn_tran $gzn_tran}]] dataset] 0
check "GZP28 every other key of the record is handed on; a record that is not a dict is handed back" \
  [list [gzn_rest [pcall {wviewer::view_new_data [gzn_view $gve_zx] $gzn_tran $gzn_tran}]] \
        [pcall {wviewer::view_new_data [list {a b c}] $gzn_tran $gzn_tran}]] \
  [list [dict replace $gzn_s left $gvz_left] {{a b c}}]
# ...and what view_entries (view_keep's first half) makes of it: the entries
# regenerate gets, through the very rules every other rebuild uses
check "GZP29 view_entries over view_new_data: X zoomed, Y not -- X with xnew and left, no Y, no dataset" \
  [pcall {wviewer::view_entries [wviewer::view_new_data [gzn_view $gve_zx] $gzn_tran $gzn_tran2] \
            [list $gzn_s]}] [list [dict create x1 0.2 x2 0.4 xnew 1 left $gvz_left]]
check "GZP29 ...the same strip, the SAME data (view_keep alone): both axes and the dataset, as add_trace" \
  [pcall {wviewer::view_entries [gzn_view $gve_zx] [list $gzn_s]}] \
  [list [dict replace $gve_zx left $gvz_left]]
check "GZP29 ...nothing zoomed on new data: the plain rebuild's empty entry" \
  [pcall {wviewer::view_entries [wviewer::view_new_data [gzn_view $gve_fit] $gzn_tran $gzn_tran2] \
            [list $gzn_s]}] {{}}

# wviewer::attach_is_same, PURE: the same data, or new data
set gzn_rec  {path /r/a.raw sim_type tran vcds {} stamp {{100 4636}}}
set gzn_prev [dict replace $gzn_rec cur {/r/a.raw tran} same 0]
check "GZP30 the same file, analysis and VCDs, unchanged on disk, its database still current: the same data" \
  [pcall {wviewer::attach_is_same $gzn_prev $gzn_rec {/r/a.raw tran}}] 1
check "GZP30 ...the mtime moved (a same-size rewrite), or the size moved: new data" \
  [list [pcall {wviewer::attach_is_same $gzn_prev [dict replace $gzn_rec stamp {{101 4636}}] {/r/a.raw tran}}] \
        [pcall {wviewer::attach_is_same $gzn_prev [dict replace $gzn_rec stamp {{100 4637}}] {/r/a.raw tran}}]] {0 0}
check "GZP30 ...another file, analysis or VCD list: new data" \
  [list [pcall {wviewer::attach_is_same $gzn_prev [dict replace $gzn_rec path /r/b.raw] {/r/a.raw tran}}] \
        [pcall {wviewer::attach_is_same $gzn_prev [dict replace $gzn_rec sim_type ac] {/r/a.raw tran}}] \
        [pcall {wviewer::attach_is_same $gzn_prev [dict replace $gzn_rec vcds {/r/d.vcd} \
                  stamp {{100 4636} {100 9}}] {/r/a.raw tran}}]] {0 0 0}
check "GZP30 ...a VCD rewritten under an unchanged raw: new data" \
  [pcall {wviewer::attach_is_same [dict replace $gzn_prev vcds {/r/d.vcd} stamp {{100 4636} {100 9}}] \
            [dict replace $gzn_rec vcds {/r/d.vcd} stamp {{100 4636} {102 9}}] {/r/a.raw tran}}] 0
check "GZP30 ...another database current now (something loaded or switched since): new data" \
  [list [pcall {wviewer::attach_is_same $gzn_prev $gzn_rec {/r/x.raw tran}}] \
        [pcall {wviewer::attach_is_same $gzn_prev $gzn_rec {}}]] {0 0}
check "GZP30 ...no record, a record with no current database, or a file that could not be read: new data" \
  [list [pcall {wviewer::attach_is_same {} $gzn_rec {/r/a.raw tran}}] \
        [pcall {wviewer::attach_is_same [dict replace $gzn_prev cur {}] $gzn_rec {}}] \
        [pcall {wviewer::attach_is_same [dict replace $gzn_prev stamp {{}}] \
                  [dict replace $gzn_rec stamp {{}}] {/r/a.raw tran}}]] {0 0 0}
# the stamp itself, on a real file: both halves are read, and they are the file system's
set gzn_f [file join $scratch gzn_stamp.raw]
set fp [open $gzn_f w]; puts -nonewline $fp [string repeat x 37]; close $fp
file mtime $gzn_f 1000000
set gzn_st [pcall {wviewer::attach_stamp $gzn_f tran}]
check "GZP30 attach_stamp: the normalized path, the analysis, and the raw's {mtime size}" \
  [list [gzn_dd $gzn_st path {}] [gzn_dd $gzn_st sim_type {}] \
        [gzn_dd $gzn_st vcds {}] [gzn_dd $gzn_st stamp {}]] \
  [list [file normalize $gzn_f] tran {} {{1000000 37}}]
file mtime $gzn_f 1000007
check "GZP30 ...an mtime moved with the size kept moves the stamp, and the verdict" \
  [list [gzn_dd [pcall {wviewer::attach_stamp $gzn_f tran}] stamp {}] \
        [pcall {wviewer::attach_is_same [dict replace $gzn_st cur {p t}] \
                  [wviewer::attach_stamp $gzn_f tran] {p t}}]] {{{1000007 37}} 0}
file delete $gzn_f

# wviewer::x_overlaps, PURE
check "GZP31 x_overlaps: inside, across an end, beyond, touching at a point" \
  [list [pcall {wviewer::x_overlaps 2 4 0 10}] [pcall {wviewer::x_overlaps 8 12 0 10}] \
        [pcall {wviewer::x_overlaps 12 14 0 10}] [pcall {wviewer::x_overlaps 10 14 0 10}]] {1 1 0 0}
check "GZP31 ...a side that is not two numbers keeps the window" \
  [list [pcall {wviewer::x_overlaps 2 4 {} 10}] [pcall {wviewer::x_overlaps 2 x 0 10}]] {1 1}
# regenerate's `xnew` arm: the window is checked against a fit of the strip,
# put back when they overlap, and on a miss dropped from the entry the record
# is written from (so the X reads as fitted at the next rebuild)
set gzn_rg [wvproc_body $wsrc wviewer::regenerate]
check_true "GZP31 regenerate fits an xnew strip's X, keeps the window on an overlap, drops it from the record on a miss" \
  [expr {[string first {[dict exists $k_ xnew]} $gzn_rg] >= 0
         && [string first {wviewer::x_overlaps} $gzn_rg] > [string first {[dict exists $k_ xnew]} $gzn_rg]
         && [string first {lset keep $gi_ $k_} $gzn_rg] > [string first {wviewer::x_overlaps} $gzn_rg]
         && [string first {lset keep $gi_ $k_} $gzn_rg]
            < [string first {set lefts_ [wviewer::rect_axes} $gzn_rg]}]
check "GZP32 the signatures of the new-data procs" \
  [list [gzn_args wviewer::view_new_data] [gzn_args wviewer::x_resolve] [gzn_args wviewer::x_same] \
        [gzn_args wviewer::attach_is_same] [gzn_args wviewer::attach_stamp] \
        [pcall {info default wviewer::attach_stamp vcdfiles gzn_d; set gzn_d}] \
        [gzn_args wviewer::attach_forget] [gzn_args wviewer::attach_record] \
        [gzn_args wviewer::x_overlaps] [gzn_args wviewer::attach_raw]] \
  [list {view was now} {s db} {sa sb} {prev rec cur} {rawfile sim_type vcdfiles} {} token token \
        {a1 a2 b1 b2} {token rawfile sim_type vcdfiles leave quiet}]
check "GZP32 attach_forget / attach_record on a window with no record: nothing, no throw" \
  [list [pcall {wviewer::attach_forget no_such_viewer}] [pcall {wviewer::attach_record no_such_viewer}]] {0 {}}

# R4: WHO MAY CHANGE A VIEWER'S DATA. Every proc that changes the raw registry
# or the current database (or calls the door that does) is classified, so a new
# loader arrives as a red naming it. The verdict that same data is the same also
# asks the CURRENT database to be the one attach_raw left (attach_is_same's
# `cur`), which catches every loader that leaves another database current; the
# explicit drops are the hand loads, which can end on the attached file again.
#
# THE VERBS are derived from the C side, not listed by hand (review round 3: a
# hand-kept prefix filter over the scheduler's names missed `xschem
# annotate_op`, whose branch clears the registry and reads a file into it). A
# LOADER is a top-level verb of src/scheduler.c, or a sub-verb of its `raw`
# (alias `raw_query`) branch, whose branch text calls a REGISTRY FUNCTION. The
# registry functions are extra_rawfile in any mode but 4 (mode 4 only prints
# the registry; a mode that is no literal counts) and free_rawfile; every
# function of src/save.c, src/vcd_read.c and src/scheduler.c whose body writes
# the registry (xctx->raw, xctx->extra_idx, xctx->extra_prev_idx,
# xctx->extra_raw_n, an extra_raw_arr[] slot); and, to a fixpoint, every
# function of those three files that calls one of them (among them raw_read,
# read_rawfile_by_type, raw_read_from_attr, table_read, vcd_read, new_rawfile,
# raw_select and scheduler.c's raw_case_reread, the names a row below requires
# the derived set to include; it holds others besides). A
# function that compares argv[1] is a dispatcher, never a registry function.
# The text is read with every comment and the inside of every string blanked,
# so a name in a comment or a message is no call. A branch runs from its
# `strcmp(argv[1], "...")` to the next one or to its function's closing brace
# in column 0; a name whose stretch holds no statement is an alias of the next
# (`raw` of `raw_query`). The `raw` branch's own two names carry the
# sub-verbs, which are split the same way on `strcmp(argv[2], "...")`. So
# `raw case` is a loader (raw_case_reread drops the current database and reads
# it again); its bare form, which the C answers from a field, is the one query
# form the scan knows (gzr_vbare, pinned on the C below).
# BLIND on the C side, declared: a branch that reaches the registry through a
# function of another file (src/draw.c's graph walkers, a schematic load), a
# function whose body is not closed by a brace in column 0, and a registry
# write through a pointer alias.
proc gzr_cblank {src} {
  set out {}
  set i 0
  set n [string length $src]
  while {[regexp -start $i -indices {/\*|//|"|'} $src m]} {
    set a [lindex $m 0]
    append out [string range $src $i [expr {$a - 1}]]
    set tok [string range $src $a [lindex $m 1]]
    if {$tok eq {/*}} {
      set e [string first {*/} $src [expr {$a + 2}]]
      set e [expr {$e < 0 ? $n - 1 : $e + 1}]
      append out [regsub -all {[^\n]} [string range $src $a $e] { }]
    } elseif {$tok eq {//}} {
      set e [string first "\n" $src $a]
      set e [expr {$e < 0 ? $n - 1 : $e - 1}]
      append out [regsub -all {[^\n]} [string range $src $a $e] { }]
    } else {
      # a string or character literal: its closing quote, a backslash escaping
      # the next character; an unclosed one is the quote alone
      set e $a
      if {[regexp -start [expr {$a + 1}] -indices "(?:\[^$tok\\\\\\n\]|\\\\.)*$tok" $src mm]
          && [lindex $mm 0] == $a + 1} {
        set e [lindex $mm 1]
      }
      if {$e > $a} {
        append out $tok [regsub -all {[^\n]} [string range $src [expr {$a + 1}] [expr {$e - 1}]] { }] $tok
      } else {
        append out $tok
      }
    }
    set i [expr {$e + 1}]
  }
  append out [string range $src $i end]
  return $out
}
# {name -> body} of every function defined in a blanked text whose name line
# starts in column 0 and whose body closes with a brace in column 0
proc gzr_cfuncs {bl} {
  set out [dict create]
  foreach {m nm} [regexp -all -inline -indices \
                    {\n(?:[A-Za-z_][^\n;{}()=]*[ \t*])?([A-Za-z_]\w*)\s*\([^;{}]*\)\s*\{} $bl] {
    set st [lindex $m 1]
    set e [string first "\n\}" $bl $st]
    if {$e < 0} { set e [string length $bl] }
    dict set out [string range $bl {*}$nm] [string range $bl $st $e]
  }
  return $out
}
# a write to the registry's fields
proc gzr_cwr {} {
  return {xctx->(?:raw|extra_idx|extra_prev_idx|extra_raw_n)\s*(?:=[^=]|\+\+|--|[-+]=)|extra_raw_arr\[[^\]]*\]\s*=[^=]}
}
# does a blanked text call a function of `k`, or write the registry?
# (extra_rawfile only in a mode that is not the literal 4)
proc gzr_ccalls {body k} {
  if {[regexp [gzr_cwr] $body]} { return 1 }
  foreach f $k {
    if {$f eq {extra_rawfile}} {
      foreach {- a} [regexp -all -inline {\mextra_rawfile\s*\(\s*([^,)]*)} $body] {
        if {[string trim $a] ne {4}} { return 1 }
      }
    } elseif {[regexp "\\m$f\\s*\\(" $body]} {
      return 1
    }
  }
  return 0
}
# the registry functions of a {name -> body} dict, by the rule above
proc gzr_kset {funcs} {
  set k {extra_rawfile free_rawfile}
  dict for {f b} $funcs {
    if {[regexp {strcmp\(argv\[1\]} $b]} { dict unset funcs $f }
  }
  while 1 {
    set grew 0
    dict for {f b} $funcs {
      if {$f ni $k && [gzr_ccalls $b $k]} { lappend k $f ; set grew 1 }
    }
    if {!$grew} { return $k }
  }
}
# {name -> 1 loader / 0 not} for the branches `strcmp(argv[<w>], "name")` of
# the blanked text `bl` (its source `src`, same offsets) between offsets
# `from` and `to`
proc gzr_cbranches {src bl w from to k} {
  set at {}
  foreach m [regexp -all -inline -indices -start $from "strcmp\\(argv\\\[$w\\\],\\s*\"" $bl] {
    set a [lindex $m 0]
    if {$a >= $to} { break }
    regexp -start $a "strcmp\\(argv\\\[$w\\\],\\s*\"(\[^\"\]*)\"" $src -> nm
    lappend at [list $a $nm [lindex $m 1]]
  }
  set out [dict create]
  set next {}
  for {set j [expr {[llength $at] - 1}]} {$j >= 0} {incr j -1} {
    lassign [lindex $at $j] a nm b
    set e [expr {$j + 1 < [llength $at] ? [lindex $at [expr {$j + 1}] 0] : $to}]
    set fe [string first "\n\}" $bl $a]
    if {$fe >= 0 && $fe < $e} { set e $fe }
    set body [string range $bl [expr {$b + 1}] [expr {$e - 1}]]
    if {$fe != $e && ![regexp {[;\{]} $body] && $next ne {}} {
      set v $next
    } else {
      set v [gzr_ccalls $body $k]
    }
    if {![dict exists $out $nm] || $v} { dict set out $nm $v }
    set next $v
  }
  return $out
}
# the names a {name -> verdict} dict answers `v` for
proc gzr_cwith {d v} { lsort [dict keys [dict filter $d value $v]] }
# the method on a C text written here: a helper reaching free_rawfile, an
# alias head, a registry write, a mode in a variable, mode 4 with the names in
# a comment and a string, and a branch followed by a function the scan must
# not give to it
set gzr_cfx {
static int qhelper(void)
{
  free_rawfile(&xctx->raw, 1, 0);
  return 1;
}
static int qquiet(void)
{
  /* extra_rawfile(1, f, NULL, -1.0, -1.0); */
  Tcl_SetResult(interp, "free_rawfile(): none", TCL_STATIC);
  return extra_rawfile(4, NULL, NULL, -1.0, -1.0);
}
static int xschem_cmds_q(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
  if(!strcmp(argv[1], "qload")) {
    qhelper();
  }
  else if(!strcmp(argv[1], "qalias") || !strcmp(argv[1], "qread")) {
    extra_rawfile(1, argv[2], NULL, -1.0, -1.0);
  }
  else if(!strcmp(argv[1], "qinfo")) {
    qquiet();
  }
  else if(!strcmp(argv[1], "qwrite")) {
    xctx->extra_idx = 0;
  }
  else if(!strcmp(argv[1], "qmode")) {
    extra_rawfile(what, NULL, NULL, -1.0, -1.0);
  }
  else if(!strcmp(argv[1], "qlast")) {
    return 0;
  }
  return 1;
}
static int qafter(void)
{
  extra_rawfile(3, NULL, NULL, -1.0, -1.0);
  return 0;
}
}
set gzr_cfxb [gzr_cblank $gzr_cfx]
set gzr_cfxk [gzr_kset [gzr_cfuncs $gzr_cfxb]]
set gzr_cfxd [gzr_cbranches $gzr_cfx $gzr_cfxb 1 0 [string length $gzr_cfx] $gzr_cfxk]
check "GZP33 the C derivation, on a text written here: a helper's call, an alias, a registry write and a variable mode load; mode 4, a comment, a string and the function after the dispatcher do not" \
  [list [lsort $gzr_cfxk] [gzr_cwith $gzr_cfxd 1] [gzr_cwith $gzr_cfxd 0] \
        [string length $gzr_cfxb] [string first {free_rawfile(): none} $gzr_cfxb]] \
  [list {extra_rawfile free_rawfile qafter qhelper} {qalias qload qmode qread qwrite} {qinfo qlast} \
        [string length $gzr_cfx] -1]
set gzr_cb [dict create]
set gzr_cf [dict create]
foreach gzr_c {scheduler.c save.c vcd_read.c} {
  set fp [open [file join $repo src $gzr_c] r]; set gzr_t [read $fp]; close $fp
  dict set gzr_cb $gzr_c [gzr_cblank $gzr_t]
  if {$gzr_c eq {scheduler.c}} { set gzr_csrc $gzr_t }
  set gzr_cf [dict merge $gzr_cf [gzr_cfuncs [dict get $gzr_cb $gzr_c]]]
}
set gzr_k [gzr_kset $gzr_cf]
set gzr_kmiss {}
foreach gzr_v {raw_read read_rawfile_by_type raw_read_from_attr table_read vcd_read new_rawfile
               raw_select raw_case_reread} {
  if {$gzr_v ni $gzr_k} { lappend gzr_kmiss $gzr_v }
}
check "GZP33 the registry functions, by writes and calls to a fixpoint, include the readers, raw_select and raw_case_reread (non-vacuity)" \
  $gzr_kmiss {}
set gzr_cbl [dict get $gzr_cb scheduler.c]
set gzr_top [gzr_cbranches $gzr_csrc $gzr_cbl 1 0 [string length $gzr_cbl] $gzr_k]
# the `raw` branch: its head names the carriers; it ends where the next
# top-level verb starts or its function closes
set gzr_a [string first {!strcmp(argv[1], "raw") || !strcmp(argv[1], "raw_query")} $gzr_csrc]
set gzr_tcarry {}
set gzr_b [string length $gzr_cbl]
if {$gzr_a >= 0} {
  set gzr_h [string range $gzr_csrc $gzr_a [expr {[string first "\n" $gzr_csrc $gzr_a] - 1}]]
  foreach {- gzr_v} [regexp -all -inline {strcmp\(argv\[1\], "([a-z_]+)"\)} $gzr_h] { lappend gzr_tcarry $gzr_v }
  if {[regexp -start [expr {$gzr_a + [string length $gzr_h]}] -indices {strcmp\(argv\[1\],\s*"} $gzr_cbl gzr_m]} {
    set gzr_b [lindex $gzr_m 0]
  }
  set gzr_fe [string first "\n\}" $gzr_cbl $gzr_a]
  if {$gzr_fe >= 0 && $gzr_fe < $gzr_b} { set gzr_b $gzr_fe }
}
set gzr_sub [gzr_cbranches $gzr_csrc $gzr_cbl 2 [expr {max($gzr_a, 0)}] $gzr_b $gzr_k]
set gzr_vload [gzr_cwith $gzr_sub 1]
set gzr_vother [gzr_cwith $gzr_sub 0]
set gzr_tload {}
foreach gzr_v [gzr_cwith $gzr_top 1] { if {$gzr_v ni $gzr_tcarry} { lappend gzr_tload $gzr_v } }
set gzr_sw {}
foreach gzr_v {read clear switch switch_back select new case table_read vcd_read} {
  if {$gzr_v ni $gzr_vload} { lappend gzr_sw +$gzr_v }
}
foreach gzr_v {info list value values index add vars} {
  if {$gzr_v ni $gzr_vother} { lappend gzr_sw -$gzr_v }
}
check "GZP33 the raw sub-verbs whose C branch calls a registry function are the loaders: read, clear, the switches, select, new and case among them; info, list, value and add not (non-vacuity both ways)" \
  [list $gzr_tcarry $gzr_sw] {{raw raw_query} {}}
set gzr_tw {}
foreach gzr_v {annotate_op raw_clear raw_read raw_read_from_attr table_read vcd_read} {
  if {$gzr_v ni $gzr_tload} { lappend gzr_tw +$gzr_v }
}
foreach gzr_v {get set getprop redraw netlist} {
  if {$gzr_v ni [gzr_cwith $gzr_top 0]} { lappend gzr_tw -$gzr_v }
}
check "GZP33 ...and the top-level verbs whose C branch calls one: annotate_op, raw_clear, raw_read, raw_read_from_attr, table_read and vcd_read among them; get, set, getprop, redraw and netlist not" \
  $gzr_tw {}
# the one query form: `raw case` with no mode answers the database's flag. Its
# registry call must sit inside the `if(argc > 3)` block its branch opens with,
# and the rest of the branch must call none, or the bare form is a loader too
set gzr_vbare {case}
proc gzr_cbody_split {bl from to} {
  # {inside outside} of the block that the first `if(argc > 3)` in from..to opens
  if {![regexp -start $from -indices {if\s*\(\s*argc\s*>\s*3\s*\)\s*\{} $bl m] || [lindex $m 1] >= $to} {
    return [list {} [string range $bl $from $to]]
  }
  set o [lindex $m 1]
  set d 0
  for {set i $o} {$i < $to} {incr i} {
    set c [string index $bl $i]
    if {$c eq "\{"} { incr d } elseif {$c eq "\}"} { incr d -1 ; if {$d == 0} { break } }
  }
  return [list [string range $bl $o $i] [string cat [string range $bl $from [expr {$o - 1}]] [string range $bl [expr {$i + 1}] $to]]]
}
set gzr_bare {}
foreach gzr_v $gzr_vbare {
  set gzr_p [string first "strcmp(argv\[2\], \"$gzr_v\")" $gzr_csrc $gzr_a]
  set gzr_q -1
  if {$gzr_p >= 0 && [regexp -start [expr {$gzr_p + 10}] -indices {strcmp\(argv\[2\],\s*"} $gzr_cbl gzr_m]} {
    set gzr_q [lindex $gzr_m 0]
  }
  if {$gzr_q < 0 || $gzr_q > $gzr_b} { set gzr_q $gzr_b }
  lassign [gzr_cbody_split $gzr_cbl [expr {max($gzr_p, 0)}] $gzr_q] gzr_in gzr_out
  lappend gzr_bare [list $gzr_v [expr {$gzr_p >= 0}] [gzr_ccalls $gzr_in $gzr_k] [gzr_ccalls $gzr_out $gzr_k]]
}
check "GZP33 the bare-form query (raw case): its branch calls a registry function only inside its if(argc > 3) block" \
  $gzr_bare {{case 1 1 0}}
# THE PROCS: a code line is a loader's when it names a loader verb, the door
# procs (ase::attach_dbs, results::select), or `xschem raw` with a verb that is
# no plain word (a variable, a substitution, nothing on the line), which is
# taken for a loader, fail closed; `xschem raw case` with nothing after it in
# its command is the query form above. Lines are given to the proc whose body
# holds them (gzr_walk: Tcl's brace rule over each file, a proc nested in a
# `namespace eval` or another body qualified by the namespaces around it); a
# line outside every proc -- a string in a quiz bank, a top-level comment -- is
# no loader.
# BLIND on the Tcl side, declared: a loader in a callback script registered at
# the top level (a `trace`, `bind` or `after` outside every proc: its lines
# belong to no proc); a call whose words are not spelt out on the line, such as
# `xschem {*}$cmd` (no `raw` word, no loader verb), a verb assembled from
# pieces (`xschem $v read`) or a script handed to eval/uplevel in a string
# built elsewhere; a verb word that is quoted or braced (`xschem "raw" read $f
# tran`, `xschem {annotate_op} $f`), which Tcl hands on as the plain word but
# the scan's patterns never match; an `xschem` whose line ends in a
# backslash, its verb continued onto the next line; a proc whose `proc` line
# ends in a backslash, its body opening on the next line (the walk closes it at
# the end of its own line, so the body's lines belong to no proc, and the depth
# row stays green); a renamed or aliased `xschem`; scripts outside src/*.tcl (an
# xschemrc, a plugin, a schematic's tclcommand); a proc made by anything but a
# `proc` line whose name is on that line; and a top-level quoted string that
# carries an unbalanced brace, which shifts the walk (the depth row below sees
# a shift that does not balance out by the end of the file, never one that
# does). The `cur` leg of attach_is_same is what stands behind these.
# {proc -> its lines} for every proc of `src`, and the brace depth at its end
proc gzr_walk {src} {
  set stack {}
  set out [dict create]
  set depth 0
  foreach line [split $src "\n"] {
    set code [regsub -all {\\.} $line {}]
    if {[regexp {^\s*proc\s+(\S+)\s} $code -> nm]} {
      set ns {}
      foreach e $stack { if {[lindex $e 0] eq {ns}} { lappend ns [lindex $e 1] } }
      if {[string match ::* $nm]} {
        set q [string range $nm 2 end]
      } elseif {[llength $ns]} {
        set q [join [concat $ns [list $nm]] ::]
      } else {
        set q $nm
      }
      lappend stack [list proc $q $depth]
    } elseif {[regexp {^\s*namespace\s+eval\s+(\S+)\s+\{} $code -> nm]} {
      lappend stack [list ns [string trim $nm :] $depth]
    }
    set p {}
    for {set i [expr {[llength $stack] - 1}]} {$i >= 0} {incr i -1} {
      if {[lindex $stack $i 0] eq {proc}} { set p [lindex $stack $i 1]; break }
    }
    if {$p ne {}} { dict lappend out $p $line }
    # a comment at the top level ends at its newline (Tcl's rule); inside a
    # braced body its braces count, as Tcl counts them
    if {!($depth == 0 && [regexp {^\s*#} $code])} {
      incr depth [expr {[regexp -all {\{} $code] - [regexp -all {\}} $code]}]
    }
    while {[llength $stack] && $depth <= [lindex $stack end 2]} {
      set stack [lrange $stack 0 end-1]
    }
  }
  return [list $out $depth]
}
# the loader procs of `src`, by the verbs above (`vbare`: the loader sub-verbs
# whose bare form, nothing after the verb in its command, is a query)
proc gzr_scan {src vload tload vbare} {
  set pat {(?:^|[^A-Za-z0-9_:])(?:::)?xschem\s+raw(?:_query)?(?:\s+(\S*)|\s*$)}
  set tpat "(?:^|\[^A-Za-z0-9_:\])(?:::)?xschem\\s+(?:[join $tload |])\\M"
  set seen {}
  lassign [gzr_walk $src] procs depth
  dict for {p lines} $procs {
    foreach l $lines {
      if {[regexp {^\s*#} $l]} { continue }
      set hit [expr {[regexp $tpat $l] || [regexp {ase::attach_dbs |results::select } $l]}]
      foreach {m vi} [regexp -all -inline -indices $pat $l] {
        set v [expr {[lindex $vi 0] < 0 ? {} : [string range $l {*}$vi]}]
        set w [string trimright $v "\]\};"]
        if {$w in $vbare} {
          set rest [string range $l [expr {[lindex $m 1] + 1}] end]
          if {$w ne $v || [regexp {^\s*(?:$|[\]\};])} $rest]} { continue }
          set hit 1
        } elseif {$w in $vload || ![regexp {^[a-z_]+$} $w]} {
          set hit 1
        }
      }
      if {$hit} { lappend seen $p; break }
    }
  }
  return [list [lsort -unique $seen] $depth]
}
# the method on a text written here: a proc in a namespace eval, the variable
# verb, a top-level loader verb, an in-place edit (no loader), a line after a
# proc's close and a top-level comment holding a brace (neither in any proc)
# (LB is a brace, put in after: a braced literal cannot hold an unbalanced one)
set gzr_fx [string map [list LB "\{"] {
namespace eval nsx {
  proc inner {} {
    xschem raw read /a.raw tran
  }
}
proc ::varverb {v} { set r [xschem raw $v /a.raw tran] }
proc topclear {} {
  # xschem raw read, in a comment, is no code
  xschem raw_clear
}
proc goback {} {
  set n [xschem raw add w {v(a) 2 *}]; xschem raw switch_back
}
proc quiet {} { xschem raw add w {v(a) 2 *} }
proc casebare {} { set c [xschem raw case]; catch { set c [xschem raw case] } }
proc casefold {} { xschem raw case fold }
proc opannot {f} { xschem annotate_op $f }
# a top-level comment holding a brace LB
set after_proc [list xschem raw read /b.raw tran]
}]
check "GZP33 the scan, on a text written here: nested, variable-verb, top-level, switch_back, raw case with a mode and annotate_op loaders; no edit, bare raw case, comment or line outside a proc" \
  [gzr_scan $gzr_fx $gzr_vload $gzr_tload $gzr_vbare] {{casefold goback nsx::inner opannot topclear varverb} 0}
set gzr_seen {}
set gzr_deep {}
foreach gzr_f [lsort [glob [file join $repo src *.tcl]]] {
  set fp [open $gzr_f r]; set gzr_src [read $fp]; close $fp
  lassign [gzr_scan $gzr_src $gzr_vload $gzr_tload $gzr_vbare] gzr_s gzr_d
  if {$gzr_d != 0} { lappend gzr_deep [file tail $gzr_f] $gzr_d }
  set gzr_seen [concat $gzr_seen $gzr_s]
}
set gzr_seen [lsort -unique $gzr_seen]
check "GZP33 the brace walk's running depth is back to 0 at the end of every src/*.tcl file (an unbalanced shift is seen, one that balances out is not)" $gzr_deep {}
# the hand loads: they drop the record themselves
set gzr_drop {wviewer::rawbar_load wviewer::display_raw wviewer::restore ase::ui::rsel_commit}
# the attach itself, its registry sequence, and the door the hand loads go through
set gzr_attach {wviewer::attach_raw ase::attach_dbs results::select}
# borrow a database and put the current one back as they found it (the Graph
# dialog's signal list reads the strip's file, by a verb held in a variable,
# then switches back; raw_prev_idx switches back and back again). One member
# also has a third arm: calc::aq_run, for an op expression over noise totals
# stored as op (issue 1657), reads the current file again as the operating
# point INTO THE SAME SLOT and puts nothing back. The slot keeps its path and
# type, so attach_is_same's cur leg does not see it; it is harmless to the
# view because the next attach clears that file and reads it again itself
# (ase::attach_dbs). Spec R4 says the same.
set gzr_borrow {wviewer::signal_list_all wviewer::trace_cursor_value wviewer::raw_cursor_restore
                wviewer::raw_prev_idx graph_fill_listbox
                ase::cosim_db_inventory ase::optexport_datasets
                calc::wave_dest calc::wave_dest_drop calc::wave_dest_restore
                calc::aq_run calc::aq_restore calc::et_run
                wviewer::held_sweep}
# (wviewer::held_sweep, issue 1780: it unloads the kept copies of earlier
# results that no trace names any more and puts the current database back when
# the unload moved it)
# may leave another database current in a viewer (attach_is_same's `cur` leg
# sees it), or act on a schematic window's context, not a viewer's
set gzr_cur {ase::saved_registry_drop op_annot::db_attach op_annot::db_detach
             create_graph load_raw hi_descend_newwin open_sub_schematic build_widgets}
set gzr_known [concat $gzr_drop $gzr_attach $gzr_borrow $gzr_cur]
set gzr_new {}
foreach gzr_p $gzr_seen { if {$gzr_p ni $gzr_known} { lappend gzr_new $gzr_p } }
set gzr_gone {}
foreach gzr_p $gzr_known { if {$gzr_p ni $gzr_seen} { lappend gzr_gone $gzr_p } }
check "GZP33 every proc that loads or switches data is classified (new: none; stale: none)" \
  [list $gzr_new $gzr_gone] {{} {}}
check_true "GZP33 ...and the scan found loaders of each kind (non-vacuity), a variable verb's and switch_back's among them" \
  [expr {{wviewer::rawbar_load} in $gzr_seen && {wviewer::attach_raw} in $gzr_seen
         && {calc::wave_dest} in $gzr_seen && {op_annot::db_attach} in $gzr_seen
         && {graph_fill_listbox} in $gzr_seen && {wviewer::raw_prev_idx} in $gzr_seen}]
set fp [open [file join $repo src ase_window.tcl] r]; set gzr_asrc [read $fp]; close $fp
set gzr_nodrop {}
foreach gzr_p $gzr_drop {
  set gzr_b [wvproc_body $wsrc $gzr_p]
  if {$gzr_b eq {}} { set gzr_b [wvproc_body $gzr_asrc $gzr_p] }
  if {[string first {wviewer::attach_forget } $gzr_b] < 0} { lappend gzr_nodrop $gzr_p }
}
check "GZP33 each hand load drops the record (wviewer::attach_forget in its code)" $gzr_nodrop {}
check_true "GZP33 forget drops it with the window's other per-token state" \
  [expr {[regexp {catch \{unset attached\(\$token\)\}} [wvproc_body $wsrc wviewer::forget]]
         && [regexp {variable attached\M} [wvproc_body $wsrc wviewer::forget]]}]

# wviewer::view_within, PURE (issue 1733 review): after one subwindow's strips
# were replaced (auto_plot under Replace or Append), those strips take their
# view from THAT subwindow's old strips only, matched by traces, and every other
# strip from the live rects. The fixtures hold the same traces in two
# subwindows, which is what made a match across subwindows go wrong. Each
# scenario has a control: the whole old view against the new strips, the way
# the first cut handed it to view_keep, answers differently.
proc gzw_rec {tr cur} {
  global gvz_left
  return [dict create x {{} {} 0} y {{} {} 0} tr $tr left $gvz_left cur $cur]
}
set gzw_A  [list $gvm_A]
set gzw_B  [list $gvm_B]
set gzw_AB [list $gvm_A $gvm_B]
set gzw_C  [list $gvm_C]
proc gzw_sigs {args} { lmap t $args {lindex [gve_sig $t] 0} }
set gzw_zxL [dict replace $gve_zx left $gvz_left]
# (1) [A][B] | [A][B], the second subwindow zoomed; Replace into the first
#     with one row: [A] | [B][A]
set gzw_pre1  [list [gzw_rec $gzw_A $gve_fit] [gzw_rec $gzw_B $gve_fit] \
                    [gzw_rec $gzw_A $gve_zx] [gzw_rec $gzw_B $gve_zx]]
set gzw_sig1  [gzw_sigs $gzw_A $gzw_B $gzw_A]
set gzw_live1 [list [gzw_rec $gzw_A $gve_fit] [gzw_rec $gzw_B $gve_zx] [gzw_rec $gzw_A $gve_zx]]
check "GZP34 a row unticked: the subwindow it never touched keeps its own zoom, the re-plotted strip its own" \
  [pcall {wviewer::view_within $gzw_live1 $gzw_pre1 $gzw_sig1 {0 1} {0 0} {{0 0} {1 2}}}] \
  [list {dataset -1} $gzw_zxL $gzw_zxL]
check "GZP34 ...control: the whole old view across subwindows gives the second subwindow's B the first's" \
  [lindex [pcall {wviewer::view_entries $gzw_pre1 $gzw_sig1}] 1] {dataset -1}
# (2) [AB] | [B][A] zoomed; Replace into the first in multi-plot: [B][A] | [B][A]
set gzw_pre2  [list [gzw_rec $gzw_AB $gve_fit] [gzw_rec $gzw_B $gve_zx] [gzw_rec $gzw_A $gve_zx]]
set gzw_sig2  [gzw_sigs $gzw_B $gzw_A $gzw_B $gzw_A]
set gzw_live2 [list [gzw_rec $gzw_B $gve_fit] [gzw_rec $gzw_A $gve_fit] \
                    [gzw_rec $gzw_B $gve_zx] [gzw_rec $gzw_A $gve_zx]]
check "GZP34 a strip split per row: the new strips take nothing of the other subwindow's zoom, which keeps it" \
  [pcall {wviewer::view_within $gzw_live2 $gzw_pre2 $gzw_sig2 {0 0} {0 1} {{0 1} {2 3}}}] \
  [list {dataset -1} {} $gzw_zxL $gzw_zxL]
check "GZP34 ...control: the whole old view across subwindows hands the first subwindow the second's zoom" \
  [lrange [pcall {wviewer::view_entries $gzw_pre2 $gzw_sig2}] 0 1] [list $gzw_zxL $gzw_zxL]
# (3) [AB] zoomed in X | [C]; Replace in multi-plot: [B][A] | [C]. The strip that
#     takes from nobody joins its OWN subwindow's X window, never another's
set gzw_pre3  [list [gzw_rec $gzw_AB $gve_zx] [gzw_rec $gzw_C $gve_fit]]
set gzw_sig3  [gzw_sigs $gzw_B $gzw_A $gzw_C]
set gzw_live3 [list [gzw_rec $gzw_B $gve_fit] [gzw_rec $gzw_A $gve_fit] [gzw_rec $gzw_C $gve_fit]]
check "GZP34 a fresh strip of the subwindow joins that subwindow's X window; the other subwindow is left alone" \
  [pcall {wviewer::view_within $gzw_live3 $gzw_pre3 $gzw_sig3 {0 0} {0 1} {{0 1} {2 2}}}] \
  [list [dict create x1 0.2 x2 0.4 dataset -1 left $gvz_left] {x1 0.2 x2 0.4 left {x1 0 x2 1}} {dataset -1}]
# (4) the fallbacks
check "GZP34 a range that does not fit takes nothing from the old view: every strip is judged by the live one" \
  [list [pcall {wviewer::view_within $gzw_live1 $gzw_pre1 $gzw_sig1 {0 9} {0 0} {{0 0} {1 2}}}] \
        [pcall {wviewer::view_within $gzw_live1 $gzw_pre1 $gzw_sig1 {0 1} {2 1} {{0 0} {1 2}}}] \
        [pcall {wviewer::view_within $gzw_live1 $gzw_pre1 $gzw_sig1 {} {0 0} {{0 0} {1 2}}}]] \
  [lrepeat 3 [list {dataset -1} $gzw_zxL $gzw_zxL]]
check "GZP34 ...a live view that is not one record per strip gives the strips outside the subwindow nothing" \
  [pcall {wviewer::view_within {} $gzw_pre1 $gzw_sig1 {0 1} {0 0} {{0 0} {1 2}}}] \
  [list {dataset -1} {} {}]
check "GZP34 the signatures, and view_keep_subwin on an unknown window or an empty view: the plain rebuild" \
  [list [gzn_args wviewer::view_within] [pcall {info default wviewer::view_within skip gzw_d; set gzw_d}] \
        [gzn_args wviewer::view_keep_subwin] \
        [pcall {wviewer::view_keep_subwin no_such_viewer $gzw_pre1 {0 1} {0 0}}]] \
  [list {live view sigs old new runs skip} {} {token view old new} {}]

check "GZP22 the signatures: view_take, view_keep, state_apply's optional view" \
  [list [info args wviewer::view_take] [info args wviewer::view_keep] \
        [pcall {info default wviewer::view_keep drop gvd_d; set gvd_d}] \
        [pcall {info default wviewer::view_keep gone gvd_g; set gvd_g}] \
        [info args wviewer::state_apply] \
        [pcall {info default wviewer::state_apply view gvd_v; set gvd_v}]] \
  {token {token view drop gone} {} {} {token snap view} {}}
check "GZP22 view_take on an unknown window answers nothing (no throw)" \
  [pcall {wviewer::view_take no_such_viewer}] {}
check "GZP23 drawn_refresh: its signature, and nothing done for an unknown window" \
  [list [info args wviewer::drawn_refresh] \
        [pcall {info default wviewer::drawn_refresh only gvd_o; set gvd_o}] \
        [pcall {wviewer::drawn_refresh no_such_viewer}]] {{token only} {} 0}
# Every rect token the engine writes on its own account is either carried here,
# folded into the model by capture_live_graph_state, or named below with the
# reason it needs neither. Derived from the C source every run, so a new
# engine-written token arrives as a red naming it.
set gzp_seen {}
foreach gzp_f {callback.c draw.c} {
  set fp [open [file join $repo src $gzp_f] r]; set gzp_src [read $fp]; close $fp
  foreach {gzp_m gzp_t} [regexp -all -inline \
      {subst_token\([a-z]+->prop_ptr, *"([a-z_0-9]+)"} $gzp_src] {
    lappend gzp_seen $gzp_t
  }
}
set gzp_seen [lsort -unique $gzp_seen]
set gzp_folded {hilight_wave sel_waves markers}
# cursors: the viewer's graphs are not `private_cursor`, so the positions are
# global and no rect holds them. image_data / spice_data: not graph rects.
set gzp_exempt {cursor1_x cursor2_x hcursor1_y hcursor2_y image_data spice_data}
set gzp_left {}
foreach gzp_t $gzp_seen {
  if {$gzp_t ni [wviewer::live_axis_tokens] && $gzp_t ni $gzp_folded
      && $gzp_t ni $gzp_exempt} { lappend gzp_left $gzp_t }
}
check "GZP5 no engine-written rect token is left to a rebuild to discard" $gzp_left {}
check_true "GZP5 ...and the scan found the writers (x1, dataset and markers among them)" \
  [expr {{x1} in $gzp_seen && {dataset} in $gzp_seen && {markers} in $gzp_seen}]
set gzp_cap [wvproc_body $wsrc wviewer::capture_live_graph_state]
foreach gzp_t $gzp_folded {
  check_true "GZP5 the fold really reads '$gzp_t' off the rect" \
    [expr {[string first "getprop rect 2 \$gi $gzp_t\]" $gzp_cap] >= 0}]
}

# THE RULE IS ABOUT regenerate, NOT ABOUT THIS FILE. `wviewer::regenerate` is
# called from src/ase_window.tcl too, with a different token variable, so GX4's
# count cannot see it and neither could an audit that only read wave_viewer.tcl.
set aw [file join $repo src ase_window.tcl]
set fp [open $aw r]; set asrc [read $fp]; close $fp
# ⚠ RESTATED 2026-08-20 (results batch item 7), from TWO sites to THREE. The
# expectation genuinely changed: `ase::ui::rsel_commit` -- the `Results >
# Select…` dialog's one commit path -- replaces the DATA of the session's
# viewer, so it is a regenerate site of exactly the kind this check exists to
# police, and it owes the same 0194 fold. The check keeps its subject (every
# regenerate site in this file is a KNOWN one) and gains the new site's own
# fold-order leg below, so raising the count cannot be a way of getting a third
# unaudited site past it.
# ⚠ RESTATED 2026-11-22 (issue 1733), from THREE to FOUR, by the same rule:
# auto_plot's re-plot path ends in a regenerate that hands every strip the view
# attach_raw left (user ruling 2026-11-22: "yes, re-run which then plots in
# Replace mode should retain zoom level, not reset it"). It needs no fold of
# its own -- nothing reaches the rects between the add_trace loop, whose every
# call folds, and it -- and gains its own order leg below. The count did not
# move in the review round: the site that reflects the destination's window
# half was already counted; it now carries the live view (its own leg below).
# Nor in the second review round: the zero-rows branch's site was counted from
# the start; it now carries the live view too (its own leg below).
# ⚠ RESTATED 2026-11-24 (issue 1734's review), from FOUR to FIVE, by the same
# rule: after its rows are in, auto_plot says which expression traces are still
# empty and evaluates one that names a vector a row has just made
# (wviewer::expr_settle); when that computed a vector the strips are rebuilt as
# they show, to draw it. Like the last site it needs no fold of its own (it
# follows the add_trace loop, whose every call folds), carries the live view,
# and has its own order leg below.
check "GX9 ase_window.tcl has exactly the five known regenerate sites" \
  [pcall {count_emitters $aw {wviewer::regenerate \$key}}] 5
# auto_plot's no-plottable-rows branch clears the AUTO strip's traces and
# regenerates — every other strip carries forward, so it owes the fold, and it
# must take it BEFORE the model mutation. Since ase_l.md R-OUT14 that mutation is
# wviewer::auto_plot_strips with no signals (it clears the one auto strip and
# removes any further ones a multi-plot batch made).
set gx_ap [wvproc_body $asrc ase::ui::auto_plot]
check_true "GX9 auto_plot folds before it clears the auto strip" \
  [expr {[string first {wviewer::capture_live_view_state $key} $gx_ap] >= 0 &&
         [string first {wviewer::capture_live_view_state $key} $gx_ap] <
         [string first {wviewer::auto_plot_strips $key 0} $gx_ap]}]
# the OTHER site (the re-plot path) is safe transitively: attach_raw captured a
# few lines above it. Pin that, or a reordering silently reopens the hole.
check_true "GX9 the re-plot path still regenerates after attach_raw" \
  [expr {[string first {wviewer::attach_raw $key} $gx_ap] <
         [string last {wviewer::regenerate $key} $gx_ap]}]
# issue 1733: the view is read AFTER attach_raw kept it (same data or new) and
# BEFORE Replace empties the subwindow or Append plans its strips, only for
# those two destinations, together with the target subwindow's strips in it,
# and handed to the LAST regenerate, after the rows are in, matched inside that
# subwindow only (view_keep_subwin; the review measured a match across
# subwindows moving one subwindow's zoom onto another)
set gx_av [string first {set view [wviewer::view_take $key]} $gx_ap]
set gx_aw [string first {set vsw [wviewer::sw_range } $gx_ap]
# (issue 1765: the destination's window half under Replace is owned_clear,
# which takes out ASE-L's own traces, where clear_subwin emptied the subwindow;
# and the plot's own load is the attach_raw that is handed `$rf`, since the
# zero-rows branch now reads the result too)
check_true "GX9 auto_plot reads the view, and its target subwindow, between attach_raw and the destination's window half" \
  [expr {$gx_av > [string first {wviewer::attach_raw $key $rf} $gx_ap]
         && [string first {wviewer::attach_raw $key $rf} $gx_ap] > 0
         && $gx_av < [string last {wviewer::owned_clear $key} $gx_ap]
         && $gx_av < [string first {wviewer::plot_sites $key} $gx_ap]
         && $gx_aw > $gx_av && $gx_aw < [string last {wviewer::owned_clear $key} $gx_ap]
         && [regexp {if \{\$dest in \{replace append\}\} \{\s*set view \[wviewer::view_take \$key\]\s*set vsw \[wviewer::sw_range \[dict get \[wviewer::layout_for \$key\] graphs\]\s*\\\s*\[wviewer::target_index \$key\]\]\s*\}} $gx_ap]}]
check_true "GX9 ...and its last regenerate, after the add_trace loop, hands that view to view_keep_subwin" \
  [expr {[string last {wviewer::regenerate $key [wviewer::view_keep_subwin $key $view $vsw $nsw]} $gx_ap]
           == [string last {wviewer::regenerate $key} $gx_ap]
         && [string last {wviewer::regenerate $key} $gx_ap]
            > [string last {wviewer::add_trace $key} $gx_ap]
         && [string last {set nsw [wviewer::sw_range } $gx_ap]
            > [string last {wviewer::add_trace $key} $gx_ap]}]
# the rebuild between the destination's window half and the add_trace loop
# CARRIES every strip as it shows (issue 1733 review: a plain one there threw
# away what attach_raw, clear_subwin and new_subwin had kept, so `~` under New
# SubWin reset every subwindow already on screen). It is the first carrying
# rebuild AFTER attach_raw (the zero-rows branch's own comes before it).
set gx_ar [string first {wviewer::attach_raw $key $rf} $gx_ap]
set gx_al [string first {wviewer::regenerate $key [wviewer::live_axes $key]} $gx_ap $gx_ar]
check_true "GX9 auto_plot's rebuild after the destination's window half carries the live view, before the rows" \
  [expr {$gx_ar > 0 && $gx_al > $gx_ar
         && $gx_al > [string last {wviewer::auto_plot_strips $key [llength $rows]} $gx_ap]
         && $gx_al > [string first {wviewer::plot_sites $key} $gx_ap]
         && $gx_al < [string first {wviewer::add_trace $key} $gx_ap]}]
# the zero-rows branch (Replace with nothing ticked) takes ASE-L's own traces
# out of the target subwindow and rebuilds; that rebuild CARRIES every strip as
# it shows too (issue 1733, second review round: a plain one there fitted every
# OTHER subwindow again, measured on band PV6 of test_ase_plot_outputs). Its
# order: the fold, the removal (issue 1765: owned_clear, where clear_subwin
# emptied the subwindow), the one empty auto strip, then the carrying rebuild,
# all before the branch's own return and before the plot's load. The branch
# ends at its own `return` line; the early return for a viewer that is not up
# stands on its `if` line.
set gx_z0 [string first {if {![llength $rows]} } $gx_ap]
set gx_zr [string first "\n    return\n" $gx_ap $gx_z0]
set gx_zb [string range $gx_ap $gx_z0 $gx_zr]
set gx_zl [string first {wviewer::regenerate $key [wviewer::live_axes $key]} $gx_zb]
check_true "GX9 auto_plot's zero-rows rebuild, after ASE-L's traces leave and the empty auto strip, carries the live view" \
  [expr {$gx_z0 > 0 && $gx_zr > $gx_z0 && $gx_zr < $gx_ar && $gx_zl > 0
         && [string first {wviewer::capture_live_view_state $key} $gx_zb] >= 0
         && [string first {wviewer::capture_live_view_state $key} $gx_zb]
            < [string first {wviewer::owned_clear $key} $gx_zb]
         && [string first {wviewer::owned_clear $key} $gx_zb]
            < [string first {wviewer::auto_plot_strips $key 0} $gx_zb]
         && [string first {wviewer::auto_plot_strips $key 0} $gx_zb] < $gx_zl}]
# issue 1765: the same branch then reads the result for `~`, never after a run,
# so what the user plotted by hand follows the result: the kept traces put
# back first, the load after its own rebuild
set gx_zh [string first {wviewer::hold_release $key} $gx_zb]
check_true "GX9 auto_plot's zero-rows branch reads the result for ~ only: guarded by !\$run, the kept traces put back, then the load, after its rebuild" \
  [expr {$gx_zh > $gx_zl
         && [string first {wviewer::attach_raw $key [ase::last_rawfile $key]} $gx_zb] > $gx_zh
         && [regexp {if \{!\$run && \$sim_t ni \{op \{\}\} && \[ase::last_rawfile \$key\] ne \{\}\} \{\s*wviewer::hold_release \$key} $gx_zb]}]
# ...so no plain rebuild is left anywhere in auto_plot: each of its sites
# hands regenerate a view
check "GX9 auto_plot has no plain rebuild left (every site it has carries a view)" \
  [list [regexp -all -line {wviewer::regenerate \$key\s*(;.*)?$} $gx_ap] \
        [regexp -all {wviewer::regenerate \$key \[} $gx_ap]] {0 4}
# the rebuild after the settling of the expression traces (issue 1734's
# review): only when that computed a vector, carrying the live view, after the
# add_trace loop and before the last rebuild, which stays the last
set gx_st [string first {if {[wviewer::expr_settle $key]} { wviewer::regenerate $key [wviewer::live_axes $key] }} $gx_ap]
check_true "GX9 auto_plot's rebuild after it settles the expression traces is conditional on a vector computed, carries the live view, and stands between the add_trace loop and the last rebuild" \
  [expr {$gx_st > [string last {wviewer::add_trace $key} $gx_ap]
         && $gx_st < [string last {wviewer::regenerate $key [wviewer::view_keep_subwin } $gx_ap]}]
# THE THIRD SITE (results batch item 7): the Select dialog's commit replaces the
# viewer's data, so it takes the fold BEFORE the door (`results::select`) and
# regenerates AFTER it -- same order, same reason, and additionally inside the
# context loan (spec results_selection.md R407f), which is why the regenerate
# sits before the release rather than after it.
set gx_rs [wvproc_body $asrc ase::ui::rsel_commit]
check_true "GX9 the Select dialog folds before the door and regenerates after" \
  [expr {[string first {wviewer::capture_live_view_state $key} $gx_rs] >= 0 &&
         [string first {wviewer::capture_live_view_state $key} $gx_rs] <
         [string first {results::select $path} $gx_rs] &&
         [string first {results::select $path} $gx_rs] <
         [string first {wviewer::regenerate $key} $gx_rs] &&
         [string first {wviewer::regenerate $key} $gx_rs] <
         [string last {ase::ui::rsel_release $key $b} $gx_rs]}]

# ============================================================================
# GH* — the USER GUIDE's shortcut table must match the shipped bindings
#
# doc/waveform_viewer_guide.html §9 is an inventory of every key and gesture the
# viewer answers. A doc table that silently rots is worse than no table, so the
# table itself is the INPUT here: each row of §9.1 carries machine-readable
# attributes (`data-seq` = the Tk sequence, `data-menu`/`data-accel` = the menu
# twin and the accelerator it advertises), and these legs assert both directions
# — every documented binding exists, and every shipped binding is documented.
# The second direction is the one that catches a NEW key added without a doc
# row, which is how the tables in ase_l_tutorial.html went stale in the first
# place.
#
# Source-level, so they run in BOTH arms: `bind WaveViewer` needs Tk, and under
# --nogui there is none. The live-widget half is GH5/GH6 inside the GG block.
# ============================================================================
set guide [file join $repo doc waveform_viewer_guide.html]
check_true "GH0 the guide exists where doc/Makefile's *.html glob will ship it" \
  [file isfile $guide]
set fp [open $guide r]; set gsrc [read $fp]; close $fp
set fp [open [file join $repo doc Makefile] r]; set gmk [read $fp]; close $fp
check_true "GH0 doc/Makefile installs *.html (the guide is not a special case)" \
  [regexp {install -f -d \*\.svg \*\.html} $gmk]

# the documented WaveViewer sequences, in the order the guide lists them
set gh_seqs {}
foreach {gh_all gh_s} [regexp -all -inline {data-seq="([^"]+)"} $gsrc] {
  lappend gh_seqs $gh_s
}
# ...and the documented (menu label, accelerator) pairs
set gh_menus {}
foreach {gh_all gh_m gh_a} \
    [regexp -all -inline {data-menu="([^"]+)" data-accel="([^"]+)"} $gsrc] {
  lappend gh_menus [list $gh_m $gh_a]
}
# a guide whose attributes were stripped by an edit would make every loop below
# vacuously green — assert the extraction FOUND something first
check "GH0 the guide's §9.1 carries the twenty-three documented viewer keys" \
  [llength $gh_seqs] 23
check "GH0 ...and eighteen documented menu accelerators" [llength $gh_menus] 18

set gh_idb [wvproc_body $wsrc wviewer::install_default_binds]
check_true "GH1 install_default_binds was found in the source" [expr {$gh_idb ne {}}]
foreach gh_s $gh_seqs {
  check_true "GH1 the guide's <$gh_s> really is a WaveViewer default" \
    [expr {[string first "bind WaveViewer <$gh_s>" $gh_idb] >= 0}]
}
# THE OTHER DIRECTION. Count only the bind STATEMENTS: the `if {[bind WaveViewer
# <seq>] eq {}}` rc-wins guard above each one mentions the same words.
set gh_nb 0
foreach gh_line [split $gh_idb "\n"] {
  if {[regexp {^\s*bind WaveViewer <} $gh_line]} { incr gh_nb }
}
check "GH2 every shipped WaveViewer default has a guide row" $gh_nb [llength $gh_seqs]
# GH2b (issue 1780, found by its review). GH2 counts the statements spelled
# `bind WaveViewer <`, so a default bound through a variable is not seen by it.
# There are two such places and they are named here, so that a third does not
# arrive unseen: the editor's dimming toggle with its Caps Lock forms (issue
# 1769: the editor's key, which the viewer hands on and the editor's own pages
# document), and the Caps Lock form of Alt-Shift-P, a key that has its row.
set gh_var {}
foreach gh_line [split $gh_idb "\n"] {
  if {[regexp {^\s*bind WaveViewer \$(\w+)} $gh_line -> gh_v]} { lappend gh_var $gh_v }
}
check "GH2b the defaults bound through a variable are the two named: the editor's dimming toggle, and the Caps Lock form of a key that has its guide row" \
  [list $gh_var \
        [regexp {foreach wv_seq \{<Control-Alt-Shift-Key-D> <Control-Alt-Lock-Key-D> <Control-Alt-Lock-Key-d>\}} $gh_idb] \
        [regexp {set wv_ovl <Alt-Shift-Key-p>} $gh_idb] \
        [expr {{Alt-Shift-Key-P} in $gh_seqs}]] \
  {{wv_ovl wv_seq} 1 1 1}

# the menu twins: label + accelerator, spelled exactly as the guide claims. The
# source writes the label braced or bare depending on whether it has a space, so
# both spellings are accepted — the ACCELERATOR string is the part under test.
set gh_mb [wvproc_body $wsrc wviewer::build_menubar]
check_true "GH3 build_menubar was found in the source" [expr {$gh_mb ne {}}]
foreach gh_p $gh_menus {
  lassign $gh_p gh_lab gh_acc
  check_true "GH3 the menu entry '$gh_lab' advertises $gh_acc, as documented" \
    [expr {[string first "-label \{$gh_lab\} -accelerator $gh_acc" $gh_mb] >= 0 ||
           [string first "-label $gh_lab -accelerator $gh_acc" $gh_mb] >= 0}]
}
set gh_nacc 0
foreach gh_line [split $gh_mb "\n"] { incr gh_nacc [regexp -all {\-accelerator } $gh_line] }
check "GH4 every menu accelerator in the viewer menubar is documented" \
  $gh_nacc [llength $gh_menus]

# dead-link guard: the guide cross-links the tutorial and the embedded-graph
# manual page, and doc/index.html must reach the guide (both were unlinked
# before this guide was written)
foreach {gh_tag gh_rel} {GH7 ase_l_tutorial.html GH7 xschem_man/graphs.html} {
  check_true "$gh_tag the guide's link to $gh_rel resolves" \
    [expr {[string first "href=\"$gh_rel\"" $gsrc] >= 0 &&
           [file isfile [file join $repo doc $gh_rel]]}]
}
set fp [open [file join $repo doc index.html] r]; set gh_idx [read $fp]; close $fp
foreach gh_rel {waveform_viewer_guide.html ase_l_tutorial.html} {
  check_true "GH7 doc/index.html links $gh_rel" \
    [expr {[string first "href=\"$gh_rel\"" $gh_idx] >= 0}]
}

# --- GH8/GH9 — the SIGNAL BROWSER's own widget gestures (SINGLE-PANE item 16) -
# The direct analogue of GH1/GH2 one layer over. The §9.1 table documents the
# `bind WaveViewer` defaults; the browser's gestures are bound on the SIDEBAR's
# widgets inside `browser_build` and are NOT on that tag, so they need their own
# attribute and their own pair of legs.
#
# ⚠ THE COUNT IS A LEDGER AND IT HAS MOVED THREE TIMES. SINGLE-PANE item 16
# shipped six; TWO-PANE item 10 added the tree's <<TreeviewSelect>> (seven);
# TWO-PANE item 11 added the LOWER pane's seven canvas gestures (fourteen); and
# the hover TOOLTIP -- item 11's own scope, shipped late beside two-pane item 20
# -- adds the sea's <Motion> (fifteen). Bump this literal in the SAME commit as
# the binds and the guide rows, never separately -- GH9 compares the two
# directions against each other and would stay green on a half-done edit if both
# sides moved together but the ledger below did not.
#
# ⚠⚠ EVERY "item N" ABOVE IS PREFIXED, AND THAT IS NOT PEDANTRY. There are TWO
# plans with overlapping numbering — doc/claude/signal_browser_batch/PLAN.md
# (single-pane) and doc/claude/signal_browser_2pane_batch/PLAN.md (two-pane) —
# and "item 16" meant three different pieces of work until the two-pane batch's
# driver-raised label filter was renumbered to 20. A bare "item N" anywhere near
# the browser is ambiguous; write which plan. Both PLAN headers carry the rule.
#
# ⚠ THE ATTRIBUTE IS `data-bseq`, NOT `data-seq`, and the distinction is the
# whole reason GH0's count of key rows above still holds: `data-bseq="` does not contain
# the substring `data-seq="`, so GH0's unanchored extractor cannot see these
# rows. GH0 is itself the standing guard on that — pick a colliding name and
# GH0 goes red, not silently wrong.
set gh_bb [wvproc_body $wsrc wviewer::browser_build]
check_true "GH8 browser_build was found in the source" [expr {$gh_bb ne {}}]
set gh_bseqs {}
foreach {gh_all gh_v} [regexp -all -inline {data-bseq="([^"]+)"} $gsrc] {
  lappend gh_bseqs [string map {&lt; < &gt; >} $gh_v]
}
# THE POSITIVE-EXTRACTION CONTROL, same job GH0 does for §9.1: without it every
# per-row leg below is vacuously green on a guide whose attributes were stripped
# or whose table was deleted outright. It also distinguishes "one row was
# removed" (5) from "nothing parsed" (0).
# ⚠ 15 -> 16, TWO-PANE ITEM 14: the sash's <ButtonRelease-1> is the sixteenth,
# and the literal moves in the SAME commit as the bind and the guide row. GH9
# below compares the two directions and is the standing guard on that lockstep —
# but GH9 stays GREEN on a half-done edit where both sides moved and only this
# literal did not, which is exactly why this number is asserted separately.
check "GH8 the guide's browser table carries the sixteen browser gestures" \
  [llength $gh_bseqs] 16
foreach gh_v $gh_bseqs {                                  ;# doc -> source
  check_true "GH8 the guide's browser bind \$f.$gh_v really is in browser_build" \
    [expr {[string first "bind \$f.$gh_v" $gh_bb] >= 0}]
}
# THE OTHER DIRECTION. Count only the first line of each bind STATEMENT — most
# of them are `\`-continued, and the bodies mention the same widgets.
set gh_nbb 0
foreach gh_line [split $gh_bb "\n"] {
  if {[regexp {^\s*bind \$f\.} $gh_line]} { incr gh_nbb }
}
check "GH9 every gesture browser_build binds has a guide row" \
  $gh_nbb [llength $gh_bseqs]

# --- GH11 — THE HOLE NEITHER GH8 NOR GH9 CAN SEE (TWO-PANE item 19) ----------
# Both of the legs above are anchored on the literal `bind $f.`: GH8 walks
# doc -> source asking only about rows the guide ALREADY has, and GH9 counts
# source -> doc with the same pattern. A gesture bound through a widget ALIAS
#     set c $f.pw.sea.c ; bind $c <Button-1> …
# is invisible to BOTH — GH8 never asks about it, and GH9 compares two numbers
# that are each one short. So a shipped, undocumented gesture is a state the
# pair reports as green, and the guide's ledger could be quietly wrong.
#
# THE CLAIM: inside `browser_build` every statement-initial `bind` binds a path
# spelled from `$f`, so GH9's counter is COMPLETE and not merely consistent.
# `^\s*bind \$[a-z]` catches `$f.`, `$c`, `$tv`, `$w` and `$top` alike; equality
# with $gh_nbb is what says no alias slipped in. A commented-out bind cannot
# match either pattern (`#` precedes `bind`), so prose is safe.
#
# ⚠ THE LIMIT, STATED EXACTLY. The pattern needs a `$` AND a LOWERCASE initial,
# so it cannot see a bind on a LITERAL path (`bind .foo.bar <…>`) NOR one
# spelled from an uppercase-initial variable (`bind $Foo <…>`). Neither form
# exists in `browser_build` today (measured) and neither matches the file's
# lower-case-local convention, but the claim is "every bind spelled from a
# lower-case-initial variable is counted", not "every bind is counted".
check "GH11 browser_build binds nothing through a widget ALIAS" \
  [regexp -all -line {^\s*bind \$[a-z]} $gh_bb] $gh_nbb
# ⚠ THE CONTROL, AND ITS FLOOR IS 16 RATHER THAN THE 14 THE PLAN NAMED.
# Without it the leg above is `0 == 0` on a renamed or deleted proc. MEASURED 16
# at TWO-PANE item 19; a floor of 14 stays green after two binds are deleted,
# which is exactly the drift GH8/GH9/GH11 exist together to catch.
check "GH11 (CONTROL) the counter sees the binds that ARE there" \
  [expr {$gh_nbb >= 16}] 1

# --- GH10 — every prose §N names a real heading IN THIS FILE ------------------
# Item 16 inserted a whole section, which renumbers the two below it. This leg
# is the self-defence for that edit and for every later one.
#
# ⚠ NARROWED CLAIM (ruling 17): this pins prose<->heading CONSISTENCY inside one
# file. It does NOT pin that the numbering is the one a reader wants, and it
# cannot see a §-ref that points at a real heading about the wrong topic.
set gh_heads {}
foreach {gh_a gh_n} [regexp -all -inline {<h[23][^>]*>([0-9]+(?:\.[0-9]+)?)\.?\s} $gsrc] {
  lappend gh_heads $gh_n
}
check_true "GH10 the guide's numbered headings were found" \
  [expr {[llength $gh_heads] >= 12}]
set gh_refs {}
foreach {gh_a gh_n} [regexp -all -inline {§([0-9]+(?:\.[0-9]+)?)} $gsrc] {
  lappend gh_refs $gh_n
}
check_true "GH10 the guide's prose section references were found" \
  [expr {[llength $gh_refs] >= 8}]
foreach gh_n [lsort -unique $gh_refs] {
  check_true "GH10 the guide's §$gh_n names a real heading" \
    [expr {[lsearch -exact $gh_heads $gh_n] >= 0}]
}

# ============================================================================
# GS* — the SIGNAL BROWSER SPEC's contract list vs the source (SINGLE-PANE 16)
# ============================================================================
# Same justification as the GH block's own: a doc table that silently rots is
# worse than none, and this one is now the batch's ONLY durable record of what
# 15 items measured. The spec names its procs in a machine-checkable list, so
# the list is checked — in BOTH directions, because a one-way check would go
# green on a spec that simply stopped naming things.
set gs_p [file join $repo doc claude specs waveform_signal_browser.md]
check_true "GS0 the signal-browser spec exists" [file isfile $gs_p]
set gs_src {}
if {[file isfile $gs_p]} {
  set fp [open $gs_p r]; set gs_src [read $fp]; close $fp
}
# ONLY the contract-list lines (`- `wviewer::name` — ...`), never a prose
# mention: a namespace VARIABLE or a proc named mid-sentence must not be
# mistaken for an entry in the contract list.
set gs_names {}
foreach gs_ln [split $gs_src "\n"] {
  if {[regexp {^- `wviewer::([a-z0-9_]+)`} $gs_ln -> gs_n]} { lappend gs_names $gs_n }
}
# ⚠ 20 -> 48, TWO-PANE ITEM 19. The floor is a LEDGER as well as an extraction
# control: the two-pane batch minted seventeen procs the parent spec never named
# and the reconcile takes the list 38 -> 57. Moving this literal in the same
# commit as the spec lines is what stops the list rotting back down again.
# GS23 below carries the exact count; this stays the "the extraction found
# something at all" leg, one step above the level where GS1 goes vacuous.
check_true "GS0 the spec's contract list was found" [expr {[llength $gs_names] >= 48}]
foreach gs_n $gs_names {                                  ;# spec -> source
  check_true "GS1 the spec's wviewer::$gs_n exists in src/wave_viewer.tcl" \
    [expr {[regexp "\nproc wviewer::${gs_n}\\s" $wsrc]}]
}
# ⚠ 23 -> 29, TWO-PANE ITEM 19. This is the SOURCE -> SPEC direction and it is
# hard-coded on purpose: a derived list would shrink silently with the spec.
# The six added are the two-pane rebuild's load-bearing shapes — the class
# strip, the tree's row filter, the sea's per-level selector, its two label
# forms' entry point and the flow layout — chosen so that a rebuild that
# deleted any of them could not ship with a green suite.
# `plot_signals` replaced `plot_dest` (2026-10-16): the per-window destination
# was retired and the destination is resolved from plot_signals' own argument.
set gs_want {sig_type sig_match sig_split signal_entry signal_list signal_list_all
             rawinfo_parse db_label attach_raw plot_signals rawbar_load rawbar_commit
             browser_build browser_show browser_toggle browser_state
             browser_state_apply hier_split hier_common hier_same hier_now
             searchbar_build searchbar_get
             sig_declass browser_tree_rows browser_class_filter
             browser_level_names browser_label browser_flow_layout}
foreach gs_n $gs_want {                                   ;# source -> spec
  check_true "GS2 the spec's contract list names wviewer::$gs_n" \
    [expr {[lsearch -exact $gs_names $gs_n] >= 0}]
}
# Every issue the spec cites must be a file. The batch filed six and cited them
# by path; a renamed or never-created issue file is exactly the rot this catches.
set gs_iss {}
foreach {gs_a gs_i} [regexp -all -inline {doc/claude/issues/(0[0-9]{3})-} $gs_src] {
  lappend gs_iss $gs_i
}
check_true "GS3 the spec cites at least the batch's six issues" \
  [expr {[llength [lsort -unique $gs_iss]] >= 6}]
foreach gs_i [lsort -unique $gs_iss] {
  check_true "GS3 the spec's issue $gs_i resolves to exactly one file" \
    [expr {[llength [glob -nocomplain \
       [file join $repo doc claude issues ${gs_i}-*.md]]] == 1}]
}

# ============================================================================
# GS22-GS29 — the TWO-PANE batch's own doc oracles (TWO-PANE item 19)
# ============================================================================
# ⚠⚠ WHY THESE ARE NOT THE PLAN'S GS10-GS15. `GS` is used for TWO unrelated
# blocks inside this one file — the spec oracles above and the grid-selection
# survival block below — and the latter is spent to GS14 with no gaps. GS is
# ALSO owned by `test_wave_sigsearch.tcl` (GS01-GS21). GS22-GS27 is the first
# run that collides with nothing in either owning file. MEASURED, not assumed.
#
# ⚠ TWO OF THE SIX WERE GREEN BEFORE THE ITEM'S DOCS EXISTED (GS25 and the
# GH11 pair above), and that is recorded rather than hidden: they are
# regression GUARDS on work TWO-PANE items 14/16 already did, and their only
# positive evidence is the item's sabotage run. GS22, GS23, GS24, GS26 and
# GS27 were all RED on the red run.
#
# Helpers. Both answer a VALUE for every input — a missing or unreadable file
# makes them answer "everything is missing" / 0, never throw.
proc bs_missing {have want} {
  set out {}
  foreach n $want { if {[lsearch -exact $have $n] < 0} { lappend out $n } }
  return $out
}
proc bs_all_in {hay args} {
  foreach s $args { if {[string first $s $hay] < 0} { return 0 } }
  return 1
}
# ⚠ WHOLE-FILE SUBSTRING ORACLES CANNOT SEE A SECTION-SHAPED REGRESSION, AND
# `GS28` BELOW IS THE FIX-UP THAT PROVES IT. `bs_all_in $gsrc {…}` (GS24) is
# green as long as a phrase survives ANYWHERE in the guide, so §11.7 could be
# reverted wholesale to its pre-two-pane single-pane wording with all four
# suites that read the guide still ALL PASS — measured, by the item's own
# verifier. These two helpers scope a claim to ONE section.
#
# bs_section: everything after $anchor up to the next heading tag. `</h3>` does
# not match `<h[1-6][ >]` (a `/` follows the `<`), so the section's own closing
# tag cannot truncate it at zero length. A missing anchor answers {} — a VALUE,
# never a throw — which reds the control leg rather than aborting the file.
proc bs_section {hay anchor} {
  set i [string first $anchor $hay]
  if {$i < 0} { return {} }
  set rest [string range $hay [expr {$i + [string length $anchor]}] end]
  set j [regexp -indices -inline {<h[1-6][ >]} $rest]
  if {[llength $j]} {
    set rest [string range $rest 0 [expr {[lindex [lindex $j 0] 0] - 1}]]
  }
  return $rest
}
# bs_flat: tags -> spaces, runs of whitespace -> one space. REQUIRED, not
# cosmetic: the guide hard-wraps its prose, so `<b>Show device\ninternals</b>`
# carries the string "Show device internals" nowhere in the raw bytes. A
# section-scoped check written without this reds on correct text.
proc bs_flat {s} {
  set s [regsub -all {<[^>]*>} $s { }]
  set s [regsub -all {\s+} $s { }]
  return [string trim $s]
}

# ⚠ THIS ROSTER IS SEVENTEEN HAND-PICKED NAMES, NOT "EVERY PROC THE BATCH
# MINTED", and the check TITLE now says so — a title is what a later reader
# trusts, and this one used to overclaim. The two-pane batch also minted
# `browser_sash_pref`, `browser_sash_drop`, `browser_tree_state`,
# `browser_tree_apply`, `browser_device_paths`, `browser_sea_layout` and
# `browser_sea_names`; those are covered only INDIRECTLY, by GS23's exact 57.
# The roster is hard-coded on purpose (a derived list would shrink with the
# spec); GS23's length is what makes the omissions unable to grow silently.
#
# ⚠ SEVENTEEN NAMES, AND `browser_tree` / `browser_sea` ARE DELIBERATELY ABSENT.
# The PLAN's list named them; MEASURED, neither proc exists — two-pane item 1
# (the accessor) never landed, and 09_receipt.md:26-27 says so outright. Naming
# them in the spec would red exactly two GS1 legs above, so the fix is to keep
# them off the list, not to invent the procs.
# THE SECOND ELEMENT IS THE SOURCE-SIDE CONTROL, in the SAME tuple on purpose:
# without it this check goes green on a spec that names seventeen ghosts.
set gs_2pane {browser_class_filter browser_tree_rows browser_level_names
              browser_label browser_label_full browser_root_label
              browser_root_id browser_flow_layout browser_flow_cell
              browser_flow_hit browser_flow_scrollregion browser_sea_build
              browser_sea_refresh browser_sea_selection browser_devint
              browser_srccur browser_sash}
set gs_2have 0
foreach gs_n $gs_2pane {
  if {[regexp "\nproc wviewer::${gs_n}\\s" $wsrc]} { incr gs_2have }
}
check {GS22 the parent spec's contract list names the two-pane batch's SEVENTEEN
       load-bearing procs (a hard-coded roster, NOT every proc the batch minted
       — GS23's exact 57 is what covers the rest), and every name on that list
       is a REAL proc} \
  [list [bs_missing $gs_names $gs_2pane] $gs_2have] [list {} 17]

# ⚠ AN EXACT LEDGER, NOT A FLOOR, and that is the point: GS0's `>= 48` above is
# the floor, this is the count. A file that loses half its contract list prints
# a plausible fail count while silently dropping GS1 legs — the LENGTH is the
# only witness to that, and a floor cannot be it.
check {GS23 the contract list is duplicate-free, and its length is the ledger} \
  [list [expr {[llength $gs_names] - [llength [lsort -unique $gs_names]]}] \
        [llength $gs_names]] [list 0 57]

check {GS24 the guide's browser section names BOTH panes and BOTH class checkboxes} \
  [bs_all_in $gsrc {instance tree} {sea of names} \
                   {Show device internals} {Show source currents}] 1

# ⚠ GREEN BEFORE THE ITEM — a GUARD on two-pane items 16/17b, declared as one.
# The negative and its positive control ride in ONE tuple so they cannot drift
# apart: a guide whose attributes were stripped answers {0 0 0 0}, not {0 0 1 1}.
check {GS25 the guide documents the browser on Ctrl-B, with no row left for the
       renamed chord and none for the schematic chord} \
  [list [regexp -all {data-seq="Control-Key-l"} $gsrc] \
        [regexp -all {data-seq="[^"]*Alt-Key-v"} $gsrc] \
        [regexp -all {data-seq="Control-Key-b"} $gsrc] \
        [regexp -all {data-seq="Key-E"} $gsrc]] {0 0 1 1}

# GS25 pins the TABLE; the PROSE is a separate surface and it was still on the
# old chord after two-pane item 16 renamed the key. Second leg is the control.
check {GS26 the guide's §11 PROSE moved off Ctrl-L and onto Ctrl-B} \
  [list [regexp -all {<kbd>Ctrl</kbd>\+<kbd>L</kbd>} $gsrc] \
        [regexp -all {<kbd>Ctrl</kbd>\+<kbd>B</kbd>} $gsrc]] {0 1}

# The per-issue GS3 legs above prove each cited number RESOLVES; this proves the
# two the two-pane batch owes are CITED at all, and pins the total so a citation
# cannot be dropped in exchange for a new one.
check {GS27 the parent spec cites the two issues the two-pane batch owes} \
  [list [expr {[lsearch -exact $gs_iss 0217] >= 0}] \
        [expr {[lsearch -exact $gs_iss 0225] >= 0}] \
        [llength [lsort -unique $gs_iss]]] {1 1 8}

# --- GS28 — §11.7 IS THE ONLY DOC OF TWO-PANE ITEM 14, AND IT HAD NO ORACLE ---
#
# ⚠⚠ THIS IS A FIX-UP CHECK AND THE HOLE IT CLOSES WAS MEASURED, NOT FEARED.
# TWO-PANE item 19's verifier reverted `doc/waveform_viewer_guide.html` §11.7
# "What is remembered" wholesale to its PRE-two-pane single-pane wording —
# dropping the sash split, BOTH class-box names and the entire
# fraction-vs-pixels paragraph — and every suite that reads the guide stayed
# ALL PASS with EVERY count unchanged: grid 267, sigbrowser 135, i12 40,
# keys 25. Zero reds, zero dropped legs.
#
# WHY THE EXISTING ORACLES CANNOT SEE IT. GS24 above asks `bs_all_in $gsrc`,
# i.e. the WHOLE FILE — and all four of its phrases also occur in §11.0/§11.2,
# so deleting §11.7 changes none of them. GS26 pins the Ctrl-B prose only.
# GH10 counts §-references and headings, and §11.7's heading survives a body
# rewrite. So the guide could silently go back to describing a single-pane
# browser that forgets everything, in both arms, fully green.
#
# WHAT THIS PINS. §11.7 is the ONLY user-facing description of TWO-PANE item
# 14's whole feature — the persisted sash and the two persisted class boxes —
# and it is the exact text item 14's still-unticked eyeball row asks a human to
# confirm. The four phrase legs are named individually so a red says WHICH
# sentence went missing; a per-leg name is worth more here than a tuple.
set gs_117 [bs_flat [bs_section $gsrc {<h3 id="browser-state">}]]
# THE EXTRACTION CONTROL, and its floor is deliberately LOW. Its job is "a real
# section was read, so the four legs below are meaningful reds" — not to be the
# discriminator. MEASURED: the shipped §11.7 flattens to 936 chars and the
# pre-two-pane wording to ~350, so `>= 300` stays GREEN under the verifier's
# revert while all four legs go RED. A floor set high enough to catch the
# revert would collapse the control into the claim and hide which is which.
check {GS28 (CONTROL) the guide's §11.7 was found and is not a stub} \
  [expr {[string length $gs_117] >= 300}] 1
foreach gs_ph {{split between the two panes}
               {Show device internals} {Show source currents}
               {fraction of the sidebar's height}} {
  check_true "GS28 the guide's §11.7 still says \"$gs_ph\"" \
    [expr {[string first $gs_ph $gs_117] >= 0}]
}

# --- GS29 — A CORRECTED NUMBER MUST NOT SURVIVE AS A STALE COPY -------------
#
# ⚠⚠ ALSO A FIX-UP CHECK, AND ALSO A MEASURED DEFECT RATHER THAN A FEAR.
# TWO-PANE item 19 re-measured `tb_charge_pump` (the shipped triple was wrong
# by exactly 9 in every term) and corrected TWO of the THREE places it lived —
# the source comment above `browser_class_filter` and §5.4 of the two-pane
# spec. The third, §0's opening motivation table in that SAME file, kept the
# stale `110` under the column header "of which are design nets". Nothing was
# red. The item's own new paragraph asserted "corrected both files in one
# commit", which was false as written.
#
# THE ORACLE IS WITHIN-FILE AGREEMENT, which is what the defect actually was:
# §0's table row and §5.4's stated nets-only figure are the SAME metric — the
# `tb_bandgap` row reads `424 | 139` and §5.4 says "Design nets only would be
# 139" — so they must carry the same number or one of them has rotted.
#
# ⚠ ASCII-ONLY PATTERNS ON PURPOSE. §5.4's sentence is written with `→`; a
# pattern containing it would depend on the encoding this file is read under.
# `nets-only \*\*N\*\*` is the same anchor with no non-ASCII byte in it.
set gs_2p [file join $repo doc claude specs waveform_signal_browser_two_pane.md]
set gs_2src {}
if {[file isfile $gs_2p]} {
  set fp [open $gs_2p r]; set gs_2src [read $fp]; close $fp
}
check_true "GS29 (CONTROL) the two-pane spec was read" \
  [expr {[string length $gs_2src] >= 20000}]
proc bs_rows {src nm} {
  set out {}
  foreach {a n m} [regexp -all -inline \
      "\\|\\s*`$nm`\\s*\\|\\s*(\[0-9\]+)\\s*\\|\\s*(\[0-9\]+)\\s*\\|" $src] {
    lappend out [list $n $m]
  }
  return $out
}
set gs_nets {}
foreach {gs_a gs_v} [regexp -all -inline {nets-only \*\*([0-9]+)\*\*} $gs_2src] {
  lappend gs_nets $gs_v
}
# ONE TUPLE, FOUR TERMS, AND THE `tb_bandgap` ROW IS THE POSITIVE CONTROL: it
# re-measures CORRECT and unchanged, so a green here is "the two surfaces agree
# on BOTH designs", not "the extractor found nothing". A dropped table row
# answers {} and reds; it cannot masquerade as agreement.
check {GS29 the two-pane spec's §0 motivation table agrees with §5.4's measured
       nets-only figure — a corrected number must not survive as a stale copy
       elsewhere in the same file} \
  [list [bs_rows $gs_2src tb_bandgap] [bs_rows $gs_2src tb_charge_pump] \
        $gs_nets] {{{424 139}} {{1191 119}} 119}

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

  # ==========================================================================
  # GS* — issue 0194: a window option must not eat the trace SELECTION
  #
  # THE FIXTURE RULE, and it is the whole point: the selection is planted on
  # the RECTS ONLY, never through the model. That is what the C click arm does
  # (callback.c graph_sel_waves_set writes the prop and nothing else), and a
  # selection that is already in the model survives a regenerate whether or not
  # the bug is fixed — a model-side plant would be a green-but-hollow leg.
  #
  # PROBE PLACEMENT: every leg selects on strip 1, NOT strip 0, and on node 2,
  # NOT node 0 — `atoi("")` reads an absent token as node 0, so a strip-0 /
  # node-0 witness passes on a destroyed token. Every leg reads back EVERY
  # strip, because hilight_wave is per-RECT and a one-rect witness cannot see a
  # selection wrongly surviving, or wrongly appearing, on its neighbour.
  # ==========================================================================
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvgrid.raw dc vsweep 0 1.0 0.02}
  foreach {v ex} {vec_a {vsweep 1 +} vec_b {vsweep 3 +} vec_c {vsweep 5 +}
                  vec_d {vsweep 7 +} vec_e {vsweep 9 +} vec_f {vsweep 11 +}} {
    pcall {xschem raw add $v $ex}
  }
  set gs_vars [split [pcall {xschem raw list}] "\n"]
  check_true "GS0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $gs_vars vec_a] >= 0 && [lsearch -exact $gs_vars vec_f] >= 0}]

  # every strip's selection SET, off the RECTS. `-` = nothing (never node 0).
  proc gs_sels {vdrw} {
    xschem new_schematic switch $vdrw
    set o {}
    set n 0; catch {set n [xschem get graph_rects]}
    for {set k 0} {$k < $n} {incr k} {
      set s [wviewer::selected_waves $vdrw $k]
      lappend o [expr {[llength $s] ? $s : "-"}]
    }
    return $o
  }
  # ...and the same question asked of the MODEL, so a fix that updates one
  # store and not the other cannot pass
  proc gs_msels {tok} {
    set o {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      set s [wviewer::model_sel $G]
      lappend o [expr {[llength $s] ? $s : "-"}]
    }
    return $o
  }
  # the RAW token pair of one strip — the third witness: `hilight_wave` is the
  # HEAD and `sel_waves` carries the rest, and a fix that folded only the head
  # would leave a multi-select silently collapsed to one trace
  proc gs_tokens {vdrw gi} {
    xschem new_schematic switch $vdrw
    set h {}; catch {set h [xschem getprop rect 2 $gi hilight_wave]}
    set s {}; catch {set s [xschem getprop rect 2 $gi sel_waves]}
    return [list $h $s]
  }
  proc gs_fill {tok} {
    wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
    foreach {gi vec} {0 vec_a 0 vec_b 0 vec_c 1 vec_d 1 vec_e 1 vec_f} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  gs_fill: add_trace $vec -> $e" }
    }
    wviewer::regenerate $tok
  }
  # wipe both stores, then write the selection onto the RECT alone
  proc gs_plant {tok vdrw gi sel} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [wviewer::model_sel_set $G {}]
    }
    wviewer::set_graphs $tok $out
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    wviewer::with_edit $tok {
      set n 0; catch {set n [xschem get graph_rects]}
      for {set k 0} {$k < $n} {incr k} {
        catch {xschem setprop rect 2 $k hilight_wave -1}
      }
      if {[llength $sel]} {
        xschem setprop rect 2 $gi hilight_wave [lindex $sel 0]
        if {[llength $sel] >= 2} { xschem setprop rect 2 $gi sel_waves $sel }
      }
    }
  }

  gs_fill $tok
  gs_plant $tok $vdrw 1 {0 2}
  # the fixture itself is asserted, or every leg below rests on an assumption:
  # the rect really carries the pair, and the model really does NOT.
  check "GS1 the plant put the SET on strip 1's rect" [gs_sels $vdrw] {- {0 2}}
  check "GS1 head + companion, as the C click arm writes them" \
    [gs_tokens $vdrw 1] {0 {0 2}}
  check "GS1 ...and the MODEL has not heard of it (else the leg is hollow)" \
    [gs_msels $tok] {- -}

  set nlog [llength $::wvg_log]
  check "GS2 Ctrl-G turned the grid off" [pcall {wviewer::grid_toggle {} $tok}] 0
  check "GS2 ...it really regenerated (grid=0 reached every rect)" \
    [list [pcall {xschem getprop rect 2 0 grid}] \
          [pcall {xschem getprop rect 2 1 grid}]] {0 0}
  # THE BUG (issue 0194): before the fix this came back `- -`
  check "GS2 the multi-trace selection SURVIVED the grid toggle" \
    [gs_sels $vdrw] {- {0 2}}
  check "GS2 both tokens survived, not just the head" [gs_tokens $vdrw 1] {0 {0 2}}
  check "GS2 the fold reached the model too" [gs_msels $tok] {- {0 2}}
  check "GS2 still exactly one replayable line (capture, do not log twice)" \
    [expr {[llength $::wvg_log] - $nlog}] 1
  # capture, do NOT push: a window option stays outside the undo stack (spec
  # waveform_viewer_modes.md §14), so Ctrl-G must not become undoable
  check "GS2 and still NOT an undo point" [pcall {wviewer::history_depth $tok}] {0 0}
  check "GS2 the viewer buffer is still unmodified" [xschem get modified] 0
  pcall {wviewer::grid_toggle 1 $tok}

  # a SINGLE selection on a non-zero strip at a NON-ZERO node: `sel_waves` is
  # absent here, so this is the leg that a head-only fold would still pass and
  # a fold that promoted a single selection into a set would fail
  gs_plant $tok $vdrw 1 {2}
  check "GS3 a single selection is head-only" [gs_tokens $vdrw 1] {2 {}}
  pcall {wviewer::grid_toggle {} $tok}
  check "GS3 it survives Ctrl-G" [gs_sels $vdrw] {- 2}
  check "GS3 ...still head-only, never promoted to a set" [gs_tokens $vdrw 1] {2 {}}
  check "GS3 ...and strip 0 did NOT acquire one" [gs_tokens $vdrw 0] {{} {}}
  pcall {wviewer::grid_toggle 1 $tok}

  # THE PREDICTION (issue 0194): Shared X is the sibling window option and had
  # the identical shape — regenerate with no fold. Nobody reported it because
  # nobody toggles it as often.
  gs_plant $tok $vdrw 1 {0 2}
  set gs_sx [expr {[info exists ::wviewer::sharedx($tok)] && $::wviewer::sharedx($tok) ? 1 : 0}]
  set ::wviewer::sharedx($tok) [expr {!$gs_sx}]
  pcall {wviewer::sharedx_toggle $tok}
  check "GS4 Shared X really flipped in the model" \
    [wviewer::dget [wviewer::layout_for $tok] sharedx 0] [expr {!$gs_sx}]
  check "GS4 the selection survived the Shared-X toggle" [gs_sels $vdrw] {- {0 2}}
  set ::wviewer::sharedx($tok) $gs_sx
  pcall {wviewer::sharedx_toggle $tok}
  check "GS4 ...and the toggle back" [gs_sels $vdrw] {- {0 2}}

  # the same defect on the view gestures: they froze the RANGES by hand and
  # nothing else, so a wheel zoom / an X pan deselected too
  gs_plant $tok $vdrw 1 {0 2}
  check "GS5 a wheel zoom reports it changed something" \
    [pcall {wviewer::wheel_zoom $tok in 1}] 1
  check "GS5 the selection survived the zoom" [gs_sels $vdrw] {- {0 2}}
  gs_plant $tok $vdrw 1 {0 2}
  check "GS5 an X pan reports it changed something" [pcall {wviewer::pan_x $tok right}] 1
  check "GS5 the selection survived the pan" [gs_sels $vdrw] {- {0 2}}

  # ...and on a plain window RESIZE, which is the widest exposure of the class
  # (spec §15.5 names this path). Driven through configure_apply with the
  # fillwh no-change gate defeated, since the canvas is not really resized here.
  gs_plant $tok $vdrw 1 {0 2}
  set ::wviewer::fillwh($tok) {1 1}
  pcall {wviewer::configure_apply $tok}
  check "GS6 the selection survived a resize refit" [gs_sels $vdrw] {- {0 2}}

  # adding a trace must not deselect either — and this is the structural site,
  # where the capture has to run BEFORE the model grows or its 1:1 rect/model
  # guard refuses it and folds nothing
  gs_plant $tok $vdrw 1 {0 2}
  check "GS7 add_trace succeeded" [pcall {wviewer::add_trace $tok 0 vec_e}] {}
  check "GS7 the selection survived a new trace on the OTHER strip" \
    [gs_sels $vdrw] {- {0 2}}
  # RE-PLANT, or this leg is inert: GS7's fold has already put the selection in
  # the model, and a regenerate re-emits it from there whether or not add_graph
  # captured. Every site needs its own rect-only plant to be under test.
  gs_plant $tok $vdrw 1 {0 2}
  check "GS8 add_graph succeeded" [pcall {wviewer::add_graph $tok}] 1
  check "GS8 the selection survived a new strip" [lrange [gs_sels $vdrw] 0 1] {- {0 2}}

  # the Axes dialog's apply path (apply_range is the seam wheel/menu/dialog all
  # reach) — a range edit must not deselect either
  gs_fill $tok
  gs_plant $tok $vdrw 1 {0 2}
  check "GS11 apply_range wrote the range" [pcall {wviewer::apply_range $tok 0 0.0 0.5 {} {}}] 1
  check "GS11 the selection survived a range edit" [gs_sels $vdrw] {- {0 2}}
  # ...and a refused apply is still the pure no-op it was before the fold was
  # added: nothing written, nothing folded
  gs_plant $tok $vdrw 1 {0 2}
  check "GS11 a bad graph index is refused" [pcall {wviewer::apply_range $tok 99 0 1 {} {}}] 0
  check "GS11 ...and the refusal folded nothing into the model" [gs_msels $tok] {- -}

  # display_raw with no rawfile — the trace-recording half of the ASE plot seam
  # (`attach_raw` needs a real .raw on disk, which needs a simulator run, so it
  # stays pinned by GX1 alone; see the issue doc's "what no check can see")
  gs_fill $tok
  gs_plant $tok $vdrw 1 {0 2}
  check "GS12 display_raw recorded the trace" \
    [pcall {wviewer::display_raw $tok {} {} vec_f 6}] 1
  check "GS12 the selection survived it" [gs_sels $vdrw] {- {0 2}}
  # ...and the Direct-Plot batch seam, which owns its own capture precisely
  # because add_trace's is refused mid-batch once the strips have grown
  gs_fill $tok
  gs_plant $tok $vdrw 1 {0 2}
  check "GS12 plot_signals landed the batch" [pcall {wviewer::plot_signals $tok {vec_e}}] {}
  check "GS12 the selection survived a Direct Plot" \
    [lrange [gs_sels $vdrw] 0 1] {- {0 2}}

  # THE REGRESSION REVIEW CAUGHT (see the issue doc §7). regenerate forces
  # graph 0's x onto every other strip's RECT under Shared X, while the MODEL
  # deliberately keeps each strip's own — that is what makes un-sharing
  # non-destructive. So the fold must not write ranges AT ALL: a version that
  # merely "refreshed an already-pinned axis" copied graph 0's window into
  # every strip's model, permanently and with no undo point.
  gs_fill $tok
  pcall {wviewer::apply_range $tok 0 0.0 1e-3 {} {}}
  pcall {wviewer::apply_range $tok 1 0.0 1e-6 {} {}}
  set gs_sx0 [expr {[info exists ::wviewer::sharedx($tok)] && $::wviewer::sharedx($tok) ? 1 : 0}]
  # NUMERIC, not textual: the model stores what the caller wrote, verbatim
  # ("1e-3"), and Tcl's own formatting of the same number is "0.001".
  proc gs_modelx {tok gi} {
    set G [lindex [dict get [wviewer::layout_for $tok] graphs] $gi]
    set o {}
    foreach k {x1 x2} {
      set v [wviewer::dget $G $k {}]
      lappend o [expr {[string is double -strict $v] ? double($v) : $v}]
    }
    return $o
  }
  check "GS13 the two strips start with their OWN x windows" \
    [list [gs_modelx $tok 0] [gs_modelx $tok 1]] {{0.0 0.001} {0.0 1e-6}}
  set ::wviewer::sharedx($tok) 1
  pcall {wviewer::sharedx_toggle $tok}
  check "GS13 Shared X does not touch the stored per-strip x" \
    [gs_modelx $tok 1] {0.0 1e-6}
  # ...and neither does any other fold while sharing is in force
  gs_plant $tok $vdrw 1 {0}
  pcall {wviewer::grid_toggle {} $tok}
  pcall {wviewer::grid_toggle 1 $tok}
  set ::wviewer::fillwh($tok) {1 1}
  pcall {wviewer::configure_apply $tok}
  check "GS13 Ctrl-G and a resize under Shared X leave strip 1's x alone" \
    [gs_modelx $tok 1] {0.0 1e-6}
  set ::wviewer::sharedx($tok) 0
  pcall {wviewer::sharedx_toggle $tok}
  set gs_rx2 [pcall {xschem getprop rect 2 1 x2}]
  if {[string is double -strict $gs_rx2]} { set gs_rx2 [expr {double($gs_rx2)}] }
  check "GS13 un-sharing brings strip 1's own window back" \
    [list [gs_modelx $tok 1] $gs_rx2] {{0.0 1e-6} 1e-6}
  set ::wviewer::sharedx($tok) $gs_sx0
  pcall {wviewer::sharedx_toggle $tok}

  # THE REGRESSION GUARD for skip_ranges, on a FRESH fixture: a strip is
  # created with `{}` ranges (= autozoom on every regenerate) and a fold that
  # does not mean to change the view must not pin them — a bare capture would
  # freeze the whole window on the first resize and the next Direct Plot into
  # an auto strip would then land off-screen. Deliberately excludes wheel_zoom
  # and pan_x: those PIN by their own D7 contract, which predates 0194.
  gs_fill $tok
  gs_plant $tok $vdrw 1 {0 2}
  pcall {wviewer::grid_toggle {} $tok}
  pcall {wviewer::grid_toggle 1 $tok}
  set ::wviewer::sharedx($tok) [expr {!$gs_sx}]
  pcall {wviewer::sharedx_toggle $tok}
  set ::wviewer::sharedx($tok) $gs_sx
  pcall {wviewer::sharedx_toggle $tok}
  set ::wviewer::fillwh($tok) {1 1}
  pcall {wviewer::configure_apply $tok}
  pcall {wviewer::add_trace $tok 0 vec_e}
  pcall {wviewer::add_graph $tok}
  set gs_auto 1
  foreach G [dict get [wviewer::layout_for $tok] graphs] {
    foreach k {x1 x2 y1 y2} {
      if {[string is double -strict [wviewer::dget $G $k {}]]} { set gs_auto 0 }
    }
  }
  check_true "GS9 every auto axis is STILL auto after the non-view folds" $gs_auto
  # ⚠ this half is a CHAIN, and a chain only tests its FIRST link: the first
  # fold puts the selection in the model and every later regenerate re-emits it
  # from there. So it is stated as what it is — an end-to-end sanity check —
  # and the per-site teeth are GS2/GS4/GS6/GS7/GS8, each with its own plant.
  check "GS9 ...and the selection came through the chain (end-to-end only)" \
    [lrange [gs_sels $vdrw] 0 1] {- {0 2}}
  # ...while a pinned axis is refreshed from the live rect rather than left stale
  gs_fill $tok
  pcall {wviewer::apply_range $tok 1 0.0 0.5 -1.0 1.0}
  set gs_G1 [lindex [dict get [wviewer::layout_for $tok] graphs] 1]
  check "GS9 an explicitly pinned range stays pinned" \
    [list [wviewer::dget $gs_G1 x1 {}] [wviewer::dget $gs_G1 x2 {}]] {0.0 0.5}

  # SYMPTOM 2 (issue 0194): "the trace that was moved across strips gets bolded /
  # unbolded with each CTRL-G". A cross-strip move CAPTURES, so the moved trace
  # is the one trace whose selectedness is in the MODEL — and a non-capturing
  # regenerate therefore RESURRECTS it instead of destroying it. Deselect it and
  # press Ctrl-G and the bold comes back; deselect again, and again. Measured
  # both ways in tests/headless/probe_0194_symptom2.tcl.
  gs_fill $tok
  gs_plant $tok $vdrw 1 {0}
  # strip 0 already holds three traces, so the moved one lands at node 3
  check "GS14 move_trace folds the selection into the model" \
    [pcall {wviewer::move_trace 1 0 0 $tok}] 3
  check "GS14 ...so the model now knows about the moved trace" \
    [lindex [gs_msels $tok] 0] 3
  # the user deselects it — a click writes the RECT only
  wviewer::with_edit $tok {
    set gs_n 0; catch {set gs_n [xschem get graph_rects]}
    for {set k 0} {$k < $gs_n} {incr k} { catch {xschem setprop rect 2 $k hilight_wave -1} }
  }
  check "GS14 the deselect took on the rect" [lindex [gs_sels $vdrw] 0] {-}
  pcall {wviewer::grid_toggle {} $tok}
  check "GS14 Ctrl-G does NOT resurrect the deselected trace" \
    [lindex [gs_sels $vdrw] 0] {-}
  pcall {wviewer::grid_toggle 1 $tok}
  check "GS14 ...and not on the toggle back either" [lindex [gs_sels $vdrw] 0] {-}
  check "GS14 the stale model entry was corrected, not just overridden" \
    [lindex [gs_msels $tok] 0] {-}

  # end-to-end through the REAL key, not the command behind it
  gs_fill $tok
  gs_plant $tok $vdrw 1 {0 2}
  set gs_del [send_key $vdrw <Control-Key-g> {[wviewer::grid_shown $tok] == 0}]
  if {!$gs_del} {
    puts "SKIPPED: GS10 real-key leg (focus never confirmed)"
  } else {
    check "GS10 a REAL Ctrl-G keeps the selection" [gs_sels $vdrw] {- {0 2}}
    check "GS10 ...both tokens" [gs_tokens $vdrw 1] {0 {0 2}}
    send_key $vdrw <Control-Key-g> {[wviewer::grid_shown $tok] == 1}
  }

  # ==========================================================================
  # GZ* — a grid toggle keeps the view (user report 2026-11-16: "When I use
  # Ctrl-G in Waveform Viewer to toggle grid, it also causes the window to
  # zoom-fit").
  #
  # THE FIXTURE RULE is GS*'s: the zoom is written onto the RECTS ONLY, through
  # the engine's own verb (what a box zoom, an axis drag and the axis wheel end
  # in), and the model is left on `{}` = auto. A zoom the model already holds
  # survives a rebuild whether or not the view is carried.
  # Every leg zooms strip 1 and reads back EVERY strip: X propagates to every
  # strip of the same analysis, Y does not.
  # ==========================================================================
  proc gz_axes {vdrw} {
    xschem new_schematic switch $vdrw
    set o {}
    set n 0; catch {set n [xschem get graph_rects]}
    for {set k 0} {$k < $n} {incr k} {
      set r {}
      foreach t {x1 x2 y1 y2} {
        set v {}; catch {set v [xschem getprop rect 2 $k $t]}
        lappend r [expr {[string is double -strict $v] ? double($v) : $v}]
      }
      lappend o $r
    }
    return $o
  }
  proc gz_model {tok} {
    set o {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      set r {}
      foreach t {x1 x2 y1 y2} {
        set v [wviewer::dget $G $t {}]
        lappend r [expr {[string is double -strict $v] ? double($v) : $v}]
      }
      lappend o $r
    }
    return $o
  }
  proc gz_zoom {vdrw} {
    xschem new_schematic switch $vdrw
    xschem graph_axis_zoom 1 x 0.2 0.4
    xschem graph_axis_zoom 1 y 7.5 8.5
  }
  set gz_auto {{{} {} {} {}} {{} {} {} {}}}
  set gz_want {{0.2 0.4 1.0 6.0} {0.2 0.4 7.5 8.5}}

  gs_fill $tok
  set gz_fit [gz_axes $vdrw]
  check "GZ0 the fixture: both strips fitted to their data" \
    $gz_fit {{0.0 1.0 1.0 6.0} {0.0 1.0 7.0 12.0}}
  gz_zoom $vdrw
  check "GZ0 the engine's zoom is on the rects (X on both strips, Y on strip 1)" \
    [gz_axes $vdrw] $gz_want
  check "GZ0 ...and the MODEL has not heard of it (else every leg is hollow)" \
    [gz_model $tok] $gz_auto

  # THE BUG: before the fix this came back as $gz_fit
  check "GZ1 Ctrl-G turned the grid off" [pcall {wviewer::grid_toggle {} $tok}] 0
  check "GZ1 ...it really rebuilt the strips (grid=0 reached every rect)" \
    [list [pcall {xschem getprop rect 2 0 grid}] \
          [pcall {xschem getprop rect 2 1 grid}]] {0 0}
  check "GZ1 the zoom SURVIVED the grid toggle, on every strip" [gz_axes $vdrw] $gz_want
  check "GZ1 the model was not written: every axis is still auto" [gz_model $tok] $gz_auto
  check "GZ2 Ctrl-G back on" [pcall {wviewer::grid_toggle {} $tok}] 1
  check "GZ2 the zoom survived that too" [gz_axes $vdrw] $gz_want
  check "GZ3 Ctrl-Shift-G (the target subwindow's grid) keeps it as well" \
    [list [pcall {wviewer::grid_toggle_subwin {} $tok}] [gz_axes $vdrw]] [list 0 $gz_want]
  # the Graph > Grid checkbutton: Tk has written the mirror before the command
  set ::wviewer::gridshow($tok) 1
  check "GZ4 the menu checkbutton keeps it" \
    [list [pcall {wviewer::grid_toggle_from_menu $tok}] [gz_axes $vdrw]] [list 1 $gz_want]
  # NOTHING IS PINNED: the axis lifetime is what it was. A rebuild that does not
  # carry the view fits the auto axes again.
  pcall {wviewer::regenerate $tok}
  check "GZ5 a plain rebuild still re-fits: the carry pinned nothing" \
    [gz_axes $vdrw] $gz_fit

  # a PINNED axis the engine zoomed afterwards: the strip keeps what it shows,
  # and the model keeps the window it was given
  gs_fill $tok
  pcall {wviewer::apply_range $tok 1 0.1 0.9 7.0 12.0}
  gz_zoom $vdrw
  pcall {wviewer::grid_toggle {} $tok}
  check "GZ6 a pinned strip keeps the engine's later zoom across Ctrl-G" \
    [lindex [gz_axes $vdrw] 1] {0.2 0.4 7.5 8.5}
  check "GZ6 ...and its model window is the one it was given" \
    [lindex [gz_model $tok] 1] {0.1 0.9 7.0 12.0}
  pcall {wviewer::grid_toggle 1 $tok}

  # the dataset the `t` key tracks is engine-written too, and per rect
  gs_fill $tok
  wviewer::with_edit $tok { xschem setprop -fast rect 2 1 dataset 0 }
  pcall {wviewer::grid_toggle {} $tok}
  check "GZ7 a tracked dataset survives Ctrl-G on its own strip only" \
    [list [pcall {xschem getprop rect 2 0 dataset}] \
          [pcall {xschem getprop rect 2 1 dataset}]] {-1 0}
  pcall {wviewer::grid_toggle 1 $tok}

  # regenerate's `keep` contract, driven directly
  gs_fill $tok
  set gz_k {x1 0.2 x2 0.4 y1 7.5 y2 8.5 ypos1 0 ypos2 2 dataset -1}
  pcall {wviewer::regenerate $tok [list {} $gz_k]}
  check "GZ8 an empty entry is fitted, a full one is written" \
    [gz_axes $vdrw] [list [lindex $gz_fit 0] {0.2 0.4 7.5 8.5}]
  pcall {wviewer::regenerate $tok [list $gz_k]}
  check "GZ8 a keep list of the wrong length is ignored: the plain rebuild" \
    [gz_axes $vdrw] $gz_fit
  pcall {wviewer::regenerate $tok [list {} {y1 7.5 y2 8.5}]}
  check "GZ8 an entry naming Y only keeps Y and fits X" \
    [gz_axes $vdrw] [list [lindex $gz_fit 0] {0.0 1.0 7.5 8.5}]
  pcall {wviewer::regenerate $tok [list {} {x1 0.2 x2}]}
  check "GZ8 a malformed entry is ignored: the plain rebuild" [gz_axes $vdrw] $gz_fit
  check "GZ9 live_axes on fitted strips carries no axis: they are rebuilt as they always were" \
    [lmap gz_e [pcall {wviewer::live_axes $tok}] {dict keys $gz_e}] {dataset dataset}
  gz_zoom $vdrw
  check "GZ9 ...on zoomed strips: one full token list each, with what it was fitted to" \
    [lmap gz_e [pcall {wviewer::live_axes $tok}] {dict keys $gz_e}] \
    [list [concat [wviewer::live_axis_tokens] left] [concat [wviewer::live_axis_tokens] left]]

  # end-to-end through the REAL key
  gs_fill $tok
  gz_zoom $vdrw
  set gz_del [send_key $vdrw <Control-Key-g> {[wviewer::grid_shown $tok] == 0}]
  if {!$gz_del} {
    puts "SKIPPED: GZ10 real-key leg (focus never confirmed)"
  } else {
    check "GZ10 a REAL Ctrl-G keeps the zoom" [gz_axes $vdrw] $gz_want
    send_key $vdrw <Control-Key-g> {[wviewer::grid_shown $tok] == 1}
    check "GZ10 ...and so does the one that turns the grid back on" [gz_axes $vdrw] $gz_want
  }
  # --- a RESIZE keeps the view (user ruling 2026-11-16) ------------------------
  # through configure_apply with the no-change gate defeated, as GS6 does
  pcall {wviewer::grid_toggle 1 $tok}
  gs_fill $tok
  gz_zoom $vdrw
  set ::wviewer::fillwh($tok) {1 1}
  pcall {wviewer::configure_apply $tok}
  check "GZ11 the zoom survived a resize refit" [gz_axes $vdrw] $gz_want
  check "GZ11 ...and the model is still auto" [gz_model $tok] $gz_auto
  # ...and through a REAL resize of the toplevel: the <Configure> path, with the
  # strips really re-placed into a canvas of another size
  set gz_wh0 $::wviewer::fillwh($tok)
  lassign [split [winfo geometry $vtop] x+] gz_w gz_h
  wm geometry $vtop [expr {$gz_w + 120}]x[expr {$gz_h + 80}]
  set gz_resized 0
  for {set gz_i 0} {$gz_i < 150} {incr gz_i} {
    update
    if {[info exists ::wviewer::fillwh($tok)] && $::wviewer::fillwh($tok) ne $gz_wh0} {
      set gz_resized 1; break
    }
    after 20
  }
  if {!$gz_resized} {
    puts "SKIPPED: GZ12 real-resize leg (the canvas never changed size)"
  } else {
    check "GZ12 a REAL window resize keeps the zoom" [gz_axes $vdrw] $gz_want
  }

  # --- the aA text size keeps the view ----------------------------------------
  gs_fill $tok
  gz_zoom $vdrw
  set gz_pt0 [wviewer::font_shown $tok]
  set gz_pt1 [expr {$gz_pt0 + 2}]
  check "GZ13 the text size really changed" \
    [list [pcall {wviewer::set_text_size $gz_pt1 $tok}] [wviewer::font_shown $tok]] \
    [list $gz_pt1 $gz_pt1]
  check "GZ13 the zoom survived the text-size change" [gz_axes $vdrw] $gz_want
  check "GZ13 ...and the model is still auto" [gz_model $tok] $gz_auto
  pcall {wviewer::set_text_size $gz_pt0 $tok}
  check "GZ13 ...and the change back" [gz_axes $vdrw] $gz_want

  # --- Shared X keeps the view, except the X windows the toggle is about -----
  set gz_sx0 [expr {[info exists ::wviewer::sharedx($tok)] && $::wviewer::sharedx($tok) ? 1 : 0}]
  proc gz_share {tok v} {
    set ::wviewer::sharedx($tok) $v
    wviewer::sharedx_toggle $tok
  }
  gz_share $tok 0
  # (a) every strip auto: nothing to hide or reveal, so nothing moves either way
  gs_fill $tok
  gz_zoom $vdrw
  gz_share $tok 1
  check "GZ14 Shared X really turned on" \
    [wviewer::dget [wviewer::layout_for $tok] sharedx 0] 1
  check "GZ14 the zoom survived turning Shared X on" [gz_axes $vdrw] $gz_want
  gz_share $tok 0
  check "GZ14 ...and turning it off" [gz_axes $vdrw] $gz_want
  check "GZ14 the model is still auto throughout" [gz_model $tok] $gz_auto
  # (b) strip 1 stores an X window of its own; Y is engine-zoomed on strip 1
  gs_fill $tok
  pcall {wviewer::apply_range $tok 0 0.0 1.0 {} {}}
  pcall {wviewer::apply_range $tok 1 0.0 0.5 {} {}}
  xschem new_schematic switch $vdrw
  xschem graph_axis_zoom 1 y 7.5 8.5
  check "GZ15 the fixture: two stored X windows, strip 1's Y zoomed on the rect only" \
    [list [gz_axes $vdrw] [lindex [gz_model $tok] 1]] \
    [list {{0.0 1.0 1.0 6.0} {0.0 0.5 7.5 8.5}} {0.0 0.5 {} {}}]
  gz_share $tok 1
  check "GZ15 ON: strip 1 takes strip 0's X and keeps its zoomed Y" \
    [gz_axes $vdrw] {{0.0 1.0 1.0 6.0} {0.0 1.0 7.5 8.5}}
  check "GZ15 ...its stored window is untouched" [lindex [gz_model $tok] 1] {0.0 0.5 {} {}}
  # the engine zooms X while shared: every strip follows on the rects
  xschem new_schematic switch $vdrw
  xschem graph_axis_zoom 0 x 0.2 0.4
  gz_share $tok 0
  check "GZ15 OFF: strip 1 gets its own X back with its Y kept; strip 0 keeps what it shows" \
    [gz_axes $vdrw] {{0.2 0.4 1.0 6.0} {0.0 0.5 7.5 8.5}}
  check "GZ15 ...and neither stored window was written" \
    [list [lindex [gz_model $tok] 0] [lindex [gz_model $tok] 1]] \
    {{0.0 1.0 {} {}} {0.0 0.5 {} {}}}
  gz_share $tok $gz_sx0

  # --- a model change is not masked by the carry -------------------------------
  # A range written to the model with no rebuild of its own must reach the
  # screen at the next rebuild, carry or not (row SWG10 of test_wave_subwindows
  # relies on it). Y, which the model did not touch, is still kept as shown.
  gs_fill $tok
  xschem new_schematic switch $vdrw
  xschem graph_axis_zoom 1 y 7.5 8.5
  set gz_gs [dict get [wviewer::layout_for $tok] graphs]
  lset gz_gs 1 [dict replace [lindex $gz_gs 1] x1 0.25 x2 0.75]
  wviewer::set_graphs $tok $gz_gs
  check "GZ16 the fixture: the model's new X is not on the rect yet" \
    [lindex [gz_axes $vdrw] 1] {0.0 1.0 7.5 8.5}
  pcall {wviewer::grid_toggle {} $tok}
  check "GZ16 Ctrl-G shows the model's new X and keeps the Y that was on screen" \
    [gz_axes $vdrw] {{0.0 1.0 1.0 6.0} {0.25 0.75 7.5 8.5}}
  pcall {wviewer::grid_toggle 1 $tok}

  # --- the whole chain, one zoom carried through every site -------------------
  gs_fill $tok
  gz_zoom $vdrw
  pcall {wviewer::grid_toggle {} $tok}
  set ::wviewer::fillwh($tok) {1 1}
  pcall {wviewer::configure_apply $tok}
  pcall {wviewer::set_text_size $gz_pt1 $tok}
  gz_share $tok 1
  gz_share $tok 0
  pcall {wviewer::set_text_size $gz_pt0 $tok}
  pcall {wviewer::grid_toggle 1 $tok}
  check "GZ17 one zoom survives grid, resize, text size and Shared X in a row" \
    [gz_axes $vdrw] $gz_want
  check "GZ17 ...with the model still auto at the end" [gz_model $tok] $gz_auto
  gz_share $tok $gz_sx0

  # ==========================================================================
  # GV — the view survives a rebuild that CHANGES the strips (user ruling
  # 2026-11-16: Graph > Axes..., adding a trace and adding a strip keep the view
  # too). Same fixture and the same engine zoom as GZ: X 0.2..0.4 on both
  # strips, Y 7.5..8.5 on strip 1 only, and the model has heard of none of it.
  # So strip 0 has a zoomed X and an UNTOUCHED Y, strip 1 has both zoomed: the
  # two cases the rule tells apart.
  # ==========================================================================
  proc gv_vecs {tok} {
    lmap G [dict get [wviewer::layout_for $tok] graphs] {
      lmap t [dict get $G traces] {dict get $t vec}}
  }
  # per strip, the axes the engine moved since they were fitted or set
  proc gv_zoomed {tok} {
    lmap r [wviewer::view_take $tok] {
      wviewer::view_zoomed [wviewer::dget $r cur {}] [wviewer::dget $r left {}]}
  }
  proc gv_fresh {tok vdrw} { gs_fill $tok ; gz_zoom $vdrw }
  set gv_s0 {0.2 0.4 1.0 6.0}
  set gv_s1 {0.2 0.4 7.5 8.5}

  # THE PREMISE of "zoomed": the engine leaves a fitted axis alone, so a token
  # that differs from the fit is the user's doing.
  gs_fill $tok
  update
  check "GV0 fitted strips read as not zoomed" [gv_zoomed $tok] {{} {}}
  gz_zoom $vdrw
  check "GV0 the engine's zoom reads as one: X on strip 0, X and Y on strip 1" \
    [gv_zoomed $tok] {x {x y}}
  pcall {wviewer::grid_toggle {} $tok}
  check "GV0 ...and still does after a rebuild that carried it" [gv_zoomed $tok] {x {x y}}
  pcall {wviewer::grid_toggle 1 $tok}

  # --- Graph > Axes... ---------------------------------------------------------
  gv_fresh $tok $vdrw
  check "GV1 a Y range given to strip 0: its X and all of strip 1 stay as shown" \
    [list [pcall {wviewer::apply_range $tok 0 {} {} 0 10}] [gz_axes $vdrw]] \
    [list 1 [list {0.2 0.4 0.0 10.0} $gv_s1]]
  check "GV1 ...strip 1 is still auto in the model" [lindex [gz_model $tok] 1] {{} {} {} {}}
  gv_fresh $tok $vdrw
  check "GV2 all four given to strip 1: strip 0 keeps its zoom" \
    [list [pcall {wviewer::apply_range $tok 1 0.1 0.9 7 12}] [gz_axes $vdrw]] \
    [list 1 [list $gv_s0 {0.1 0.9 7.0 12.0}]]
  # the SAME range given again after the engine zoomed away from it: the model
  # does not change, and the strip must show the range all the same
  gz_zoom $vdrw
  check "GV2 the fixture: strip 1 zoomed away from its stored range" \
    [lindex [gz_axes $vdrw] 1] $gv_s1
  pcall {wviewer::apply_range $tok 1 0.1 0.9 7 12}
  check "GV2 a range given again is shown, though the model already held it" \
    [gz_axes $vdrw] [list $gv_s0 {0.1 0.9 7.0 12.0}]
  # the dialog itself
  gv_fresh $tok $vdrw
  set gv_w [pcall {wviewer::axes_dialog $tok}]
  if {![winfo exists $gv_w]} {
    check "GV3 the Axes dialog opened" $gv_w {a window}
  } else {
    $gv_w.graph set 0
    wviewer::axes_load $tok
    check "GV3 the dialog shows the MODEL's blanks for a zoomed auto strip" \
      [lmap gv_e {x1 x2 y1 y2} {$gv_w.$gv_e get}] {{} {} {} {}}
    $gv_w.y1 insert 0 -2
    $gv_w.y2 insert 0 9
    pcall {wviewer::axes_ok $tok}
    check "GV3 OK: the named strip shows what the dialog says (X blank = fitted), strip 1 its zoom" \
      [gz_axes $vdrw] [list {0.0 1.0 -2.0 9.0} $gv_s1]
    check "GV3 ...strip 1 is still auto in the model" [lindex [gz_model $tok] 1] {{} {} {} {}}
    gv_fresh $tok $vdrw
    set gv_w [pcall {wviewer::axes_dialog $tok}]
    $gv_w.graph set 1
    wviewer::axes_load $tok
    pcall {wviewer::axes_ok $tok}
    check "GV3 OK with every field blank fits the named strip; strip 0 keeps its zoom" \
      [gz_axes $vdrw] [list $gv_s0 [lindex $gz_fit 1]]
  }
  gv_fresh $tok $vdrw
  check "GV4 Log Y on strip 0: its X and all of strip 1 stay as shown" \
    [list [pcall {wviewer::set_axis_scale $tok 0 y 1}] \
          [lrange [lindex [gz_axes $vdrw] 0] 0 1] [lindex [gz_axes $vdrw] 1]] \
    [list 1 {0.2 0.4} $gv_s1]
  check_true "GV4 ...and its Y really was fitted in the new unit" \
    [expr {[lrange [lindex [gz_axes $vdrw] 0] 2 3] ne {1.0 6.0}}]

  # --- adding a trace ----------------------------------------------------------
  # vec_f (11..12) into strip 0 (1..6): X zoomed, Y untouched
  gv_fresh $tok $vdrw
  check "GV5 a trace added to strip 0" \
    [list [pcall {wviewer::add_trace $tok 0 vec_f}] [lindex [gv_vecs $tok] 0]] \
    {{} {vec_a vec_b vec_c vec_f}}
  check "GV5 strip 1 keeps its zoom, strip 0 its zoomed X" \
    [list [lindex [gz_axes $vdrw] 1] [lrange [lindex [gz_axes $vdrw] 0] 0 1]] \
    [list $gv_s1 {0.2 0.4}]
  lassign [lindex [gz_axes $vdrw] 0] gv_x1 gv_x2 gv_y1 gv_y2
  check_true "GV5 strip 0's untouched Y was fitted again: the new trace is in view" \
    [expr {$gv_y1 <= 1.2 && $gv_y2 >= 11.4}]
  check "GV5 the model is still auto" [gz_model $tok] $gz_auto
  # vec_a (1..2) into strip 1, zoomed on both axes to 7.5..8.5
  gv_fresh $tok $vdrw
  check "GV6 a trace added to a strip zoomed on both axes: the zoom is kept on both" \
    [list [pcall {wviewer::add_trace $tok 1 vec_a}] [lindex [gv_vecs $tok] 1] [gz_axes $vdrw]] \
    [list {} {vec_d vec_e vec_f vec_a} [list $gv_s0 $gv_s1]]
  # nothing zoomed: the trace comes into view as it always did
  gs_fill $tok
  pcall {wviewer::add_trace $tok 0 vec_f}
  lassign [lindex [gz_axes $vdrw] 0] gv_x1 gv_x2 gv_y1 gv_y2
  check_true "GV7 a trace added to an UNZOOMED strip is fitted into view (X 0..1, Y to 12)" \
    [expr {$gv_x1 == 0.0 && $gv_x2 == 1.0 && $gv_y1 <= 1.0 && $gv_y2 >= 12.0}]
  check "GV7 ...the other strip is where it was" [lindex [gz_axes $vdrw] 1] [lindex $gz_fit 1]
  # a zoom carried by another rebuild first is still a zoom, and an axis carried
  # UNZOOMED is still not one
  gv_fresh $tok $vdrw
  pcall {wviewer::grid_toggle {} $tok}
  pcall {wviewer::add_trace $tok 1 vec_a}
  check "GV8 zoom, Ctrl-G, then a trace into strip 1: the zoom is still kept" \
    [gz_axes $vdrw] [list $gv_s0 $gv_s1]
  pcall {wviewer::add_trace $tok 0 vec_f}
  lassign [lindex [gz_axes $vdrw] 0] gv_x1 gv_x2 gv_y1 gv_y2
  check_true "GV8 ...and into strip 0: X kept, the Y nobody moved fitted again" \
    [expr {$gv_x1 == 0.2 && $gv_x2 == 0.4 && $gv_y1 <= 1.2 && $gv_y2 >= 11.4}]
  check "GV8 ...strip 1 through both" [lindex [gz_axes $vdrw] 1] $gv_s1
  pcall {wviewer::grid_toggle 1 $tok}

  # --- adding a strip ----------------------------------------------------------
  gv_fresh $tok $vdrw
  check "GV9 a strip added: the strips there keep their zoom" \
    [list [pcall {wviewer::add_graph $tok}] [lrange [gz_axes $vdrw] 0 1]] \
    [list 1 [list $gv_s0 $gv_s1]]
  check "GV9 ...and the model is still auto" [lrange [gz_model $tok] 0 1] $gz_auto
  pcall {wviewer::add_trace $tok 2 vec_f}
  check "GV9 the first trace into the new strip comes up at the X window the others show" \
    [list [lrange [gz_axes $vdrw] 0 1] [lrange [lindex [gz_axes $vdrw] 2] 0 1]] \
    [list [list $gv_s0 $gv_s1] {0.2 0.4}]
  lassign [lindex [gz_axes $vdrw] 2] gv_x1 gv_x2 gv_y1 gv_y2
  check_true "GV9 ...with its Y fitted to ITS data over that window (vec_f is 11.2..11.4 there)" \
    [expr {$gv_y1 > 8.5 && $gv_y1 <= 11.2 && $gv_y2 >= 11.4}]
  check "GV9 ...and the model was not written: the new strip is auto" \
    [lindex [gz_model $tok] 2] {{} {} {} {}}
  pcall {wviewer::grid_toggle {} $tok}
  check "GV9 ...and it still shows that window after the next rebuild" \
    [lrange [lindex [gz_axes $vdrw] 2] 0 1] {0.2 0.4}
  pcall {wviewer::grid_toggle 1 $tok}
  # `u` after it
  gv_fresh $tok $vdrw
  pcall {wviewer::add_graph $tok}
  check "GV10 undo of the added strip keeps the zoom" \
    [list [pcall {wviewer::undo $tok}] [gz_axes $vdrw] [gz_model $tok]] \
    [list 1 [list $gv_s0 $gv_s1] $gz_auto]
  check "GV10 ...and so does the redo" \
    [list [pcall {wviewer::redo $tok}] [lrange [gz_axes $vdrw] 0 1]] \
    [list 1 [list $gv_s0 $gv_s1]]
  # a snapshot that PINS a window still restores it: move_strip freezes the view
  # into its undo point, the engine then zooms further, `u` goes back
  gv_fresh $tok $vdrw
  pcall {wviewer::move_strip 0 1 $tok}
  xschem new_schematic switch $vdrw
  xschem graph_axis_zoom 0 x 0.3 0.35
  check "GV11 the fixture: zoomed further after a strip move" \
    [lmap gv_r [gz_axes $vdrw] {lrange $gv_r 0 1}] {{0.3 0.35} {0.3 0.35}}
  check "GV11 undo of the move puts back the windows its snapshot holds" \
    [list [pcall {wviewer::undo $tok}] [gz_axes $vdrw]] [list 1 [list $gv_s0 $gv_s1]]

  # --- plotting from another window (Direct Plot, the browser's Plot) ----------
  gv_fresh $tok $vdrw
  check "GV12 a signal plotted into a NEW strip: the strips there keep their zoom, and it joins it" \
    [list [pcall {wviewer::plot_signals $tok {vec_f} {} newstrip}] [gv_vecs $tok] \
          [lrange [gz_axes $vdrw] 0 1] [lrange [lindex [gz_axes $vdrw] 2] 0 1]] \
    [list {} {{vec_a vec_b vec_c} {vec_d vec_e vec_f} vec_f} [list $gv_s0 $gv_s1] {0.2 0.4}]
  # THE REPORTED CASE (user 2026-11-16, a Direct Plot in multi-plot mode: "the
  # zoom level when the Ctrl-4 sends a plot does not match the prevailing zoom
  # level", the new strip on top at 0..20u over strips at 1.2u..3.9u). Direct
  # Plot lands through plot_signals with `append`; in multi-plot that is a new
  # strip on top.
  gv_fresh $tok $vdrw
  set gv_mode0 [wviewer::plot_mode $tok]
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  check "GV19 multi-plot, a signal appended: the new strip is on top, at the X window of the strips under it" \
    [list [pcall {wviewer::plot_signals $tok {vec_f} {} append}] [gv_vecs $tok] \
          [lrange [lindex [gz_axes $vdrw] 0] 0 1] [lrange [gz_axes $vdrw] 1 2]] \
    [list {} {vec_f {vec_a vec_b vec_c} {vec_d vec_e vec_f}} {0.2 0.4} [list $gv_s0 $gv_s1]]
  pcall {wviewer::set_plot_mode $gv_mode0 $tok}
  # the same when the window was zoomed with the WHEEL, which stores the window
  # in the model: the new strip takes it off the model's word, without being
  # given a stored window of its own
  gs_fill $tok
  pcall {wviewer::wheel_zoom $tok in 0}
  set gv_wz [lrange [lindex [gz_axes $vdrw] 0] 0 1]
  check_true "GV20 the fixture: a wheel zoom stored a narrower X window on both strips" \
    [expr {$gv_wz ne {0.0 1.0} && [lrange [lindex [gz_axes $vdrw] 1] 0 1] eq $gv_wz
           && [lrange [lindex [gz_model $tok] 0] 0 1] eq $gv_wz}]
  pcall {wviewer::plot_signals $tok {vec_f} {} newstrip}
  check "GV20 a signal plotted into a new strip after a WHEEL zoom joins that window too" \
    [list [lrange [lindex [gz_axes $vdrw] 2] 0 1] [lrange [lindex [gz_model $tok] 2] 0 1]] \
    [list $gv_wz {{} {}}]
  pcall {wviewer::grid_toggle {} $tok}
  check "GV20 ...and keeps it through the next rebuild" \
    [lrange [lindex [gz_axes $vdrw] 2] 0 1] $gv_wz
  pcall {wviewer::grid_toggle 1 $tok}
  # nothing zoomed: the new strip is fitted, like the others
  gs_fill $tok
  pcall {wviewer::plot_signals $tok {vec_f} {} newstrip}
  check "GV21 nothing zoomed: a new strip is fitted to its sweep, as before" \
    [lmap gv_r [gz_axes $vdrw] {lrange $gv_r 0 1}] {{0.0 1.0} {0.0 1.0} {0.0 1.0}}
  # a paste, and its undo
  gv_fresh $tok $vdrw
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {wviewer::paste_payload [list [list [dict create expr vec_f name {} vec vec_f color 4]]] {0} {4} $tok}
  check "GV13 a paste into strip 0: its zoomed X and all of strip 1 stay as shown" \
    [list [lindex [gv_vecs $tok] 0] [lrange [lindex [gz_axes $vdrw] 0] 0 1] [lindex [gz_axes $vdrw] 1]] \
    [list {vec_a vec_b vec_c vec_f} {0.2 0.4} $gv_s1]
  check "GV13 ...and through the undo of the paste" \
    [list [pcall {wviewer::undo $tok}] [lindex [gv_vecs $tok] 0] \
          [lrange [lindex [gz_axes $vdrw] 0] 0 1] [lindex [gz_axes $vdrw] 1]] \
    [list 1 {vec_a vec_b vec_c} {0.2 0.4} $gv_s1]

  # --- subwindows --------------------------------------------------------------
  gv_fresh $tok $vdrw
  set gv_n [pcall {wviewer::new_subwin $tok}]
  check "GV14 a subwindow added: the strips there keep their zoom" \
    [list $gv_n [lrange [gz_axes $vdrw] 0 1]] [list 2 [list $gv_s0 $gv_s1]]
  pcall {wviewer::add_trace $tok 2 vec_f}
  check "GV14 a strip in a NEW subwindow is fitted: the other subwindow's window is not its own" \
    [lrange [lindex [gz_axes $vdrw] 2] 0 1] {0.0 1.0}
  check "GV14 a wheel zoom in the new subwindow leaves the first one's zoom alone" \
    [list [pcall {wviewer::wheel_zoom $tok in 2}] [lrange [gz_axes $vdrw] 0 1]] \
    [list 1 [list $gv_s0 $gv_s1]]
  check_true "GV14 ...and really zoomed its own strip" \
    [expr {[lrange [lindex [gz_axes $vdrw] 2] 0 1] ne {0.0 1.0}}]
  check "GV14 a pan there leaves it alone too" \
    [list [pcall {wviewer::pan_x $tok right 2}] [lrange [gz_axes $vdrw] 0 1]] \
    [list 1 [list $gv_s0 $gv_s1]]
  # View > Fit is the TARGET subwindow's (strip 2 here): it must leave the first
  # subwindow's zoom known as a zoom, or the next rebuild fits it away
  pcall {wviewer::fit $tok}
  pcall {wviewer::grid_toggle {} $tok}
  check "GV14 a Fit in the new subwindow, then Ctrl-G: the first one's zoom is still kept" \
    [lrange [gz_axes $vdrw] 0 1] [list $gv_s0 $gv_s1]
  pcall {wviewer::grid_toggle 1 $tok}
  # Replace keeps the emptied strip's STORED X window (sw_clear_graphs' rule, and
  # the wheel zoom above stored one); the other subwindow is not its business
  set gv_sw2 [lrange [lindex [gz_axes $vdrw] 2] 0 1]
  check "GV14 a signal plotted with Replace empties that subwindow only" \
    [list [pcall {wviewer::plot_signals $tok {vec_a} {} replace}] [gv_vecs $tok] \
          [lrange [gz_axes $vdrw] 0 1] [lrange [lindex [gz_axes $vdrw] 2] 0 1]] \
    [list {} {{vec_a vec_b vec_c} {vec_d vec_e vec_f} vec_a} [list $gv_s0 $gv_s1] $gv_sw2]
  check "GV14 the subwindow closed: the survivors keep their zoom" \
    [list [pcall {wviewer::close_subwin $tok 2}] [gz_axes $vdrw]] \
    [list 1 [list $gv_s0 $gv_s1]]
  check "GV14 the model is still auto after all of it" [gz_model $tok] $gz_auto

  # --- a fit is still a fit ----------------------------------------------------
  gv_fresh $tok $vdrw
  pcall {wviewer::grid_toggle {} $tok}
  pcall {wviewer::add_graph $tok}
  check "GV15 View > Fit after carried rebuilds fits" \
    [list [pcall {wviewer::fit $tok}] [lrange [gz_axes $vdrw] 0 1]] [list 1 $gz_fit]
  pcall {wviewer::grid_toggle 1 $tok}
  pcall {wviewer::set_target_strip 0 $tok}

  # --- a zoom made AFTER the model was told what the rects show -----------------
  # View > Fit and wviewer::marker_changed (every marker gesture) write the live
  # windows into the model with no rebuild. The next carrying rebuild must not
  # take that for a range the screen has not shown yet and go back to it.
  gv_fresh $tok $vdrw
  pcall {wviewer::fit $tok}
  check "GV17 the fixture: fitted, and the model holds the fit" \
    [list [gz_axes $vdrw] [gz_model $tok]] [list $gz_fit $gz_fit]
  gz_zoom $vdrw
  pcall {wviewer::grid_toggle {} $tok}
  check "GV17 a zoom made after View > Fit survives Ctrl-G" [gz_axes $vdrw] [list $gv_s0 $gv_s1]
  check "GV17 ...and the model still holds the fit" [gz_model $tok] $gz_fit
  pcall {wviewer::grid_toggle 1 $tok}
  gv_fresh $tok $vdrw
  xschem new_schematic switch $vdrw
  check "GV18 the hook every marker gesture calls: the model takes the windows on screen" \
    [list [pcall {wviewer::marker_changed}] [gz_model $tok]] \
    [list 1 [list $gv_s0 $gv_s1]]
  xschem new_schematic switch $vdrw
  xschem graph_axis_zoom 1 x 0.3 0.35
  check "GV18 the fixture: zoomed further after the fold" \
    [lmap gv_r [gz_axes $vdrw] {lrange $gv_r 0 1}] {{0.3 0.35} {0.3 0.35}}
  pcall {wviewer::grid_toggle {} $tok}
  check "GV18 that later zoom survives Ctrl-G" \
    [gz_axes $vdrw] {{0.3 0.35 1.0 6.0} {0.3 0.35 7.5 8.5}}
  pcall {wviewer::add_graph $tok}
  check "GV18 ...and a strip added after it" \
    [lrange [gz_axes $vdrw] 0 1] {{0.3 0.35 1.0 6.0} {0.3 0.35 7.5 8.5}}
  pcall {wviewer::grid_toggle 1 $tok}

  # --- a strip nobody zoomed is rebuilt as it always was -----------------------
  # vec_a recomputed in place (as a re-evaluated expression vector is) while
  # strip 0 is fitted and strip 1 is zoomed in Y: the next rebuild fits strip 0
  # to the data it now has, and leaves strip 1's zoom alone
  gs_fill $tok
  xschem new_schematic switch $vdrw
  xschem graph_axis_zoom 1 y 7.5 8.5
  pcall {xschem raw add vec_a {vsweep 30 +}}
  pcall {wviewer::grid_toggle {} $tok}
  lassign [lindex [gz_axes $vdrw] 0] gv_x1 gv_x2 gv_y1 gv_y2
  check_true "GV16 an unzoomed strip is fitted to its data again by a carrying rebuild" \
    [expr {$gv_x1 == 0.0 && $gv_x2 == 1.0 && $gv_y2 >= 31.0}]
  check "GV16 ...while the zoomed strip beside it keeps its zoom" \
    [lindex [gz_axes $vdrw] 1] {0.0 1.0 7.5 8.5}
  pcall {xschem raw add vec_a {vsweep 1 +}}
  pcall {wviewer::grid_toggle 1 $tok}

  # leave the window as the rows below expect it: grid on, axes auto
  pcall {wviewer::grid_toggle 1 $tok}
  gs_fill $tok

  # ==========================================================================
  # GH5/GH6 — the guide's table against the LIVE window (the widget half of GH*)
  #
  # GH1..GH4 read the source; these read the running viewer, so a default that
  # is installed but never reaches the tag (a swept bindtag, a menubar rebuilt
  # without an accelerator) still fails. The tag defaults are installed at the
  # first viewer open, which this block has already done.
  # ==========================================================================
  foreach gh_s $gh_seqs {
    check_true "GH5 <$gh_s> is bound on the live WaveViewer tag" \
      [expr {[bind WaveViewer <$gh_s>] ne {}}]
  }
  # find a labelled entry anywhere in the viewer menubar, the submenus a
  # cascade entry opens included; {} = not there. A menu whose entries are
  # relabelled when it is posted (Options > Plot Mode names the mode it would
  # switch to) is asked for its labels of the moment: its -postcommand runs
  # first, as it does when the menu opens.
  proc gh_find_entry {mb lab} {
    set todo {}
    foreach sub {file view graph cursors options} { lappend todo $mb.$sub }
    while {[llength $todo]} {
      set m [lindex $todo 0]
      set todo [lrange $todo 1 end]
      if {![winfo exists $m]} continue
      catch {uplevel #0 [$m cget -postcommand]}
      set last {}
      catch {set last [$m index end]}
      if {![string is integer -strict $last]} continue
      for {set i 0} {$i <= $last} {incr i} {
        if {![catch {$m entrycget $i -menu} sm] && $sm ne {}} { lappend todo $sm }
        if {[catch {$m entrycget $i -label} l]} continue
        if {$l eq $lab} { return [list $m $i] }
      }
    }
    return {}
  }
  set gh_bar $vtop.wvmenubar
  # the guide names the Plot Mode entry by the label it shows in single mode,
  # so the lookup runs with the target subwindow in single mode
  set gh_mode [pcall {wviewer::plot_mode $tok}]
  pcall {wviewer::set_plot_mode single $tok}
  if {[winfo exists $gh_bar]} {
    foreach gh_p $gh_menus {
      lassign $gh_p gh_lab gh_acc
      set gh_hit [gh_find_entry $gh_bar $gh_lab]
      check_true "GH6 the menubar really has a '$gh_lab' entry" \
        [expr {$gh_hit ne {}}]
      if {$gh_hit ne {}} {
        lassign $gh_hit gh_m gh_i
        check "GH6 '$gh_lab' shows the accelerator the guide documents" \
          [$gh_m entrycget $gh_i -accelerator] $gh_acc
      }
    }
  } else {
    puts "SKIPPED: GH6 (viewer menubar not found)"
  }
  # The helper really descends. The Plot Mode entry sits one cascade below
  # Options, and it is found under both of its labels: the one the guide
  # documents in single mode, the other one after a switch to multi.
  set gh_c1 [gh_find_entry $gh_bar {Set Multi-plot Mode}]
  set gh_a1 [pcall {[lindex $gh_c1 0] entrycget [lindex $gh_c1 1] -accelerator}]
  pcall {wviewer::set_plot_mode multi $tok}
  set gh_c2 [gh_find_entry $gh_bar {Set Single-plot Mode}]
  set gh_a2 [pcall {[lindex $gh_c2 0] entrycget [lindex $gh_c2 1] -accelerator}]
  set gh_c3 [gh_find_entry $gh_bar {Set Multi-plot Mode}]
  check "GH6 the lookup reaches an entry below a cascade and follows its relabel: the Plot Mode entry under its single-mode label, then under its multi-mode label only" \
    [list [lindex $gh_c1 0] [lindex $gh_c2 0] $gh_c3] \
    [list $gh_bar.options.plotmode $gh_bar.options.plotmode {}]
  # the relabel keeps the accelerator: the entry reads it under the label of
  # either mode (the loop above reads it under the single-mode label only,
  # which is the one the guide names). Measured: with a relabel that drops the
  # accelerator under the single-plot label this check is red, alone.
  check "GH6 the Plot Mode entry shows the guide's accelerator under both of its labels, the single-mode one and the multi-mode one" \
    [list $gh_a1 $gh_a2] {Ctrl+Shift+M Ctrl+Shift+M}
  if {$gh_mode eq {single} || $gh_mode eq {multi}} { pcall {wviewer::set_plot_mode $gh_mode $tok} }

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action

  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: GG* GUI legs (no DISPLAY)"
}

# ============================================================================
# GF* — item 22, the C half: a FIXED text size per viewer strip (`textpx`)
# ============================================================================
# The token is the viewer's (doc/claude/calc_feedback_batch item 22; the Tcl
# writer is wviewer::font_props). These rows drive the ENGINE directly, on
# sheets of graph rects this band writes itself, so they do not depend on the
# viewer writing the token. Read back through `xschem get
# graph_text_metrics <gi>` (scheduler.c; draw.c graph_text_metrics).
# ⚠ GF3/GF4 are the D-G fence: every graph rect in every committed
# xschem_library schematic must answer what the HEAD binary answered. The gold
# file names how it was captured; GF_CAPTURE=<file> re-captures it from
# whatever binary runs this suite.
# There is no GF7 here: whether the cursor-A read-out row clears the legend and
# the Y numbers needs real text extents, which only a display arm draws; rows
# SWL4/SWL6 of test_wave_subwindows.tcl assert it there, from the boxes the draw
# recorded (`xschem get graph_drawn`).
# Verify round (2026-10-16): four C sabotages left every GF row green and now
# each reddens its own row, measured: dropping the export freeze in
# save_restore_zoom, or ignoring graph_txt_mooz in setup_graph_data -> GF5c
# (display arm only; png export writes nothing under --nogui); no width floor
# -> GF2h (x2); no left recompute after the height floor -> GF2i (x2).
set gf_dir [file join $scratch gf]
file mkdir $gf_dir
proc gf_props {extra} {
  set p "flags=graph\ny1=-1\ny2=1\ndivy=5\nx1=0\nx2=1e-3\ndivx=5\nnode=\"\""
  foreach {k v} $extra { append p "\n$k=$v" }
  return $p
}
# n stacked strips filling 0..W x 0..Ht, each with the extra tokens
proc gf_sheet {path n extra {W 1000} {Ht 1200}} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
  puts $fp "G {}\nK {}\nV {}\nS {}\nE {}"
  set h [expr {double($Ht)/$n}]
  for {set i 0} {$i < $n} {incr i} {
    puts $fp "B 2 0 [expr {$i*$h}] $W [expr {($i+1)*$h}] {[gf_props $extra]}"
  }
  close $fp
  return $path
}
proc gf_load {path {box {0 0 1000 1200}}} {
  xschem load -nohist $path
  xschem zoom_box {*}$box 1.0
}
proc gf_m {gi} { return [pcall {xschem get graph_text_metrics $gi}] }
proc gf_get {m k} {
  if {[catch {dict get $m $k} v]} { return "NOKEY:$k" }
  return $v
}
# relative closeness, sentinel-safe: answers 1/0, never raises
proc gf_near {a b {rel 1e-9}} {
  if {![string is double -strict $a] || ![string is double -strict $b]} { return 0 }
  set s [expr {max(abs($a), abs($b), 1e-300)}]
  return [expr {abs($a - $b) <= $rel * $s}]
}
# a < b - d, sentinel-safe: answers 1/0, never raises (a band that aborts
# deletes its rows from the verdict instead of reddening them)
proc gf_lt {a b {d 0.0}} {
  if {![string is double -strict $a] || ![string is double -strict $b]} { return 0 }
  return [expr {$a < $b - $d}]
}
proc gf_ratio_bt {m} {
  set t [gf_get $m top_px]; set b [gf_get $m bottom_px]; set p [gf_get $m plot_h_px]
  if {![string is double -strict $t] || ![string is double -strict $b] ||
      ![string is double -strict $p]} { return -1 }
  return [expr {($t + $b) / ($t + $b + $p)}]
}
# metrics minus the parsed textpx field (the only field a refused value may move)
proc gf_strip_tp {m} {
  if {[catch {dict remove $m textpx} r]} { return $m }
  return $r
}
set gf_tp 18.6667

# ---- GF1: the text is textpx screen pixels at any strip count and any zoom --
set gf1_bad {}
set gf1_n 0
foreach {n box} {1 {0 0 1000 1200} 6 {0 0 1000 1200} 1 {0 0 500 600} 1 {-500 -600 1500 1800}} {
  gf_load [gf_sheet [file join $gf_dir gf1_$n.sch] $n [list textpx $gf_tp]] $box
  for {set gi 0} {$gi < $n} {incr gi} {
    set m [gf_m $gi]
    incr gf1_n
    if {[gf_get $m fixed] ne "1" || ![gf_near [gf_get $m em_px] $gf_tp]} {
      lappend gf1_bad "n=$n box=$box gi=$gi fixed=[gf_get $m fixed] em=[gf_get $m em_px]"
    }
  }
}
check "GF1 every fixed strip draws its text at textpx px, n=1/6 and zoomed in/out (none differ)" \
  [list $gf1_n $gf1_bad] [list 9 {}]
# distinctness control: the SAME sheets without the token move with n, so the
# instrument can see a size change at all
gf_load [gf_sheet [file join $gf_dir gf1p_1.sch] 1 {}]
set gf1p1 [gf_get [gf_m 0] em_px]
gf_load [gf_sheet [file join $gf_dir gf1p_6.sch] 6 {}]
set gf1p6 [gf_get [gf_m 0] em_px]
check "GF1b control: without textpx em_px at n=1 and n=6 differ (proportional) and fixed=0" \
  [list [expr {[string is double -strict $gf1p1] && [string is double -strict $gf1p6] &&
               ![gf_near $gf1p1 $gf1p6 1e-3]}] [gf_get [gf_m 0] fixed]] {1 0}
# D3: one size for every text, and xlabmag/ylabmag/legendmag ignored for size
set gf_mags {xlabmag 2 ylabmag 3 legendmag 1.63}
gf_load [gf_sheet [file join $gf_dir gf1m.sch] 1 [concat [list textpx $gf_tp] $gf_mags]]
set gf1m [gf_m 0]
gf_load [gf_sheet [file join $gf_dir gf1_1.sch] 1 [list textpx $gf_tp]]
set gf1f [gf_m 0]
check "GF1c fixed: txtsizelab = txtsizex = txtsizey = txtsizelegend" \
  [llength [lsort -unique [list [gf_get $gf1f txtsizelab] [gf_get $gf1f txtsizex] \
     [gf_get $gf1f txtsizey] [gf_get $gf1f txtsizelegend]]]] 1
check "GF1d fixed: the three mag tokens change nothing at all" \
  [expr {$gf1m eq $gf1f && [string match "fixed 1 *" $gf1f]}] 1
gf_load [gf_sheet [file join $gf_dir gf1pm.sch] 1 $gf_mags]
set gf1pm [gf_m 0]
gf_load [file join $gf_dir gf1p_1.sch]
check "GF1e control: the same mags DO move a proportional strip" \
  [expr {[gf_get $gf1pm txtsizex] ne [gf_get [gf_m 0] txtsizex]}] 1

# ---- GF2: margins are fixed pixels; the floor keeps text size, not margins --
set gf2 {}
foreach {tag n box} {a 1 {0 0 1000 1200} b 2 {0 0 1000 1200} c 1 {0 0 500 600} d 1 {-500 -600 1500 1800}} {
  gf_load [gf_sheet [file join $gf_dir gf2_$n.sch] $n [list textpx $gf_tp]] $box
  dict set gf2 $tag [gf_m 0]
}
set gf2_pre {}
foreach tag {a b c d} {
  set r [gf_ratio_bt [dict get $gf2 $tag]]
  if {!($r > 0 && $r < 0.79)} { lappend gf2_pre "$tag:$r" }
}
check "GF2a precondition: none of n=1, n=2, zoom-in, zoom-out reaches the 80% floor" $gf2_pre {}
set gf2_bad {}
foreach tag {b c d} {
  foreach k {top_px bottom_px left_px right_px} {
    if {![gf_near [gf_get [dict get $gf2 a] $k] [gf_get [dict get $gf2 $tag] $k]]} {
      lappend gf2_bad "$tag.$k=[gf_get [dict get $gf2 $tag] $k] vs [gf_get [dict get $gf2 a] $k]"
    }
  }
}
check "GF2b top/bottom/left/right pixel margins are equal across n=1, n=2, zoom-in, zoom-out" \
  $gf2_bad {}
gf_load [gf_sheet [file join $gf_dir gf2_12.sch] 12 [list textpx $gf_tp]]
set gf2f [gf_m 0]
check "GF2c n=12: top+bottom is exactly 80% of the strip (the floor engaged)" \
  [gf_near [gf_ratio_bt $gf2f] 0.8] 1
check "GF2d n=12: the plot box keeps a height and the text keeps its size" \
  [list [gf_lt 0 [gf_get $gf2f plot_h_px]] [gf_near [gf_get $gf2f em_px] $gf_tp]] {1 1}
check "GF2e n=12: the floor really shrank the margins (non-vacuity)" \
  [gf_lt [gf_get $gf2f top_px] [gf_get [dict get $gf2 a] top_px] 1.0] 1
# right margin: 2 em, never narrower than the reorder grip column + 4 px. The
# grip width is READ from xschem.h, not restated.
set fp [open [file join $repo src xschem.h] r]; set gf_hdr [read $fp]; close $fp
set gf_gripw [expr {[regexp {#define GRAPH_REORDER_HANDLE_W\s+(\d+)} $gf_hdr -> w] ? $w : "NOGRIP"}]
check "GF2f right margin at textpx=$gf_tp is 2 em" \
  [gf_near [gf_get [dict get $gf2 a] right_px] [expr {2.0 * $gf_tp}]] 1
gf_load [gf_sheet [file join $gf_dir gf2_6px.sch] 1 {textpx 6}]
check "GF2g right margin at textpx=6 is the grip column + 4 px ($gf_gripw + 4), not 2 em" \
  [gf_near [gf_get [gf_m 0] right_px] [expr {$gf_gripw + 4.0}]] 1
# GF2h: the WIDTH floor. Every other GF sheet is 1000 wide, where left+right is
# far under 80% of the strip, so `if(left + right > 0.8 * gr->rw)` was reached by
# no row. A 100-unit-wide strip at the same zoom is narrower than the natural
# left+right (measured as GF2's own n=1 margins, not restated), so without the
# floor the plot width goes <= 0 and the transforms divide by it. rw in pixels
# is the sheet's 100 units times the live mooz (1/zoom).
gf_load [gf_sheet [file join $gf_dir gf2_narrow.sch] 1 [list textpx $gf_tp] 100 1200]
set gf2n [gf_m 0]
set gf2n_rw [expr {[catch {xschem get zoom} z] || ![string is double -strict $z] || $z <= 0
                   ? "NOZOOM" : 100.0 / $z}]
proc gf_sum {m a b} {
  set x [gf_get $m $a]; set y [gf_get $m $b]
  if {![string is double -strict $x] || ![string is double -strict $y]} { return "NAN" }
  return [expr {$x + $y}]
}
proc gf_div {a b} {
  if {![string is double -strict $a] || ![string is double -strict $b] || $b == 0} { return "NAN" }
  return [expr {double($a) / $b}]
}
set gf2n_nat [gf_sum [dict get $gf2 a] left_px right_px]
set gf2n_lr [gf_sum $gf2n left_px right_px]
set gf2n_pw [expr {[string is double -strict [gf_get $gf2n box_x1]] &&
                   [string is double -strict [gf_get $gf2n box_x2]]
                   ? [gf_get $gf2n box_x2] - [gf_get $gf2n box_x1] : "NAN"}]
check "GF2h precondition: the narrow strip's natural left+right exceeds 80% of its width" \
  [gf_lt [expr {[string is double -strict $gf2n_rw] ? 0.8 * $gf2n_rw : "NAN"}] $gf2n_nat] 1
check "GF2h narrow strip: (left+right)/rw is exactly 0.8, the plot keeps a width, text keeps textpx" \
  [list [gf_near [gf_div $gf2n_lr $gf2n_rw] 0.8] [gf_lt 0 $gf2n_pw] \
     [gf_near [gf_get $gf2n em_px] $gf_tp]] {1 1 1}
check "GF2h non-vacuity: the width floor really shrank the left margin" \
  [gf_lt [gf_get $gf2n left_px] [gf_get [dict get $gf2 a] left_px] 1.0] 1
# GF2i: after the HEIGHT floor the left margin is recomputed from the shrunken
# bottom (its tick-mark term is bottom/10), so left - bottom/10 is the same on
# the floored strip as on the unfloored n=1 one, while left itself moved.
# n=20, not n=12: since 2026-10-21 the last resort scales only the legend and
# X-number rows (the air and overhang are gone first), so the X-number row keeps
# more of a short strip than it did and n=12's left moved by under the 0.5 px
# the distinctness leg asks; twenty strips floor it well past that.
gf_load [gf_sheet [file join $gf_dir gf2_20.sch] 20 [list textpx $gf_tp]]
set gf2t [gf_m 0]
proc gf_lmb {m} {
  set l [gf_get $m left_px]; set b [gf_get $m bottom_px]
  if {![string is double -strict $l] || ![string is double -strict $b]} { return "NAN" }
  return [expr {$l - $b / 10.0}]
}
check "GF2i n=20: left is recomputed from the floored bottom (left - bottom/10 unchanged)" \
  [gf_near [gf_lmb $gf2t] [gf_lmb [dict get $gf2 a]]] 1
check "GF2i distinctness: the n=20 left margin really differs from n=1's (by > 0.5 px)" \
  [gf_lt [gf_get $gf2t left_px] [gf_get [dict get $gf2 a] left_px] 0.5] 1

# ---- GF3: every committed schematic graph answers what HEAD answered --------
# The population is DERIVED each run (every *.sch under xschem_library holding
# flags=graph, editor backups *~.sch excluded) and must equal the gold file's.
proc gf_find_sch {dir} {
  set out {}
  foreach f [glob -nocomplain -directory $dir -types f *.sch] {
    if {[string match {*~.sch} $f]} continue
    set fp [open $f r]; set t [read $fp]; close $fp
    if {[string first "flags=graph" $t] >= 0} { lappend out $f }
  }
  foreach d [glob -nocomplain -directory $dir -types d *] { lappend out {*}[gf_find_sch $d] }
  return $out
}
proc gf_rel {repo f} { return [string range $f [expr {[string length $repo] + 1}] end] }
proc gf_view_box {f} {
  set fp [open $f r]; set t [read $fp]; close $fp
  set bx {}
  foreach {- a b c d} [regexp -all -inline -line {^B 2 (\S+) (\S+) (\S+) (\S+) } $t] {
    if {$bx eq {}} { set bx [list $a $b $c $d]; continue }
    lassign $bx p q r s
    set bx [list [expr {min($p,$a)}] [expr {min($q,$b)}] [expr {max($r,$c)}] [expr {max($s,$d)}]]
  }
  return $bx
}
set gf_keys {fixed txtsizelab txtsizex txtsizey txtsizelegend digtxtsizelab box_x1 box_y1 box_x2 box_y2}
proc gf_gold_of {m keys} {
  set o {}
  foreach k $keys { lappend o $k [gf_get $m $k] }
  return $o
}
set gf_files [lsort [lmap f [gf_find_sch [file join $repo xschem_library]] {gf_rel $repo $f}]]
set gf_live {}
foreach f $gf_files {
  set bx [gf_view_box [file join $repo $f]]
  gf_load [file join $repo $f] $bx
  set n [xschem get rects 2]
  for {set gi 0} {$gi < $n} {incr gi} {
    set m [gf_m $gi]
    if {$m eq {}} continue
    dict set gf_live "$f $gi" [gf_gold_of $m $gf_keys]
  }
}
if {[info exists ::env(GF_CAPTURE)]} {
  set fp [open $::env(GF_CAPTURE) w]
  dict for {k v} $gf_live { puts $fp "$k $v" }
  close $fp
  puts "note: GF3 gold captured to $::env(GF_CAPTURE)"
}
set gf_gold {}
set gf_goldf [file join $here fixtures graph_text_metrics gold.txt]
if {![catch {open $gf_goldf r} fp]} {
  while {[gets $fp line] >= 0} {
    if {$line eq {} || [string index $line 0] eq "#"} continue
    dict set gf_gold "[lindex $line 0] [lindex $line 1]" [lrange $line 2 end]
  }
  close $fp
}
set gf_gfiles [lsort -unique [lmap k [dict keys $gf_gold] {lindex $k 0}]]
check "GF3a the derived graph-schematic population equals the gold file's" \
  [list [llength $gf_files] [expr {$gf_files eq $gf_gfiles}]] [list [llength $gf_gfiles] 1]
check_true "GF3b non-vacuity: the gold holds over 100 graph rects, a digital one among them" \
  [expr {[dict size $gf_gold] > 100 &&
         [llength [lsearch -all -glob [dict keys $gf_gold] {xschem_library/rom8k/*}]] > 0}]
set gf3_bad {}
dict for {k want} $gf_gold {
  if {![dict exists $gf_live $k]} { lappend gf3_bad "$k MISSING"; continue }
  set got [dict get $gf_live $k]
  foreach kk $gf_keys {
    set a [gf_get $got $kk]; set b [gf_get $want $kk]
    if {$a ne $b && ![gf_near $a $b 1e-12]} { lappend gf3_bad "$k $kk=$a want $b" }
  }
}
check "GF3c every schematic graph's text sizes and plot box equal HEAD's, fixed=0 (none differ)" \
  [list [dict size $gf_live] [lrange $gf3_bad 0 4]] [list [dict size $gf_gold] {}]

# ---- GF4: refused or inapplicable textpx values are exactly "absent" --------
set gf4_bad {}; set gf4_n 0; set gf4_dig 0; set gf4_live 0
foreach f $gf_files {
  gf_load [file join $repo $f] [gf_view_box [file join $repo $f]]
  set n [xschem get rects 2]
  for {set gi 0} {$gi < $n} {incr gi} {
    set base [gf_m $gi]
    if {$base eq {}} continue
    set vals {0 -1 1e9 nan junk 2.99 400.01}
    set dig [xschem getprop rect 2 $gi digital]
    if {$dig eq "1"} { lappend vals $gf_tp; incr gf4_dig }
    foreach v $vals {
      xschem setprop -fast rect 2 $gi textpx $v
      set m [gf_m $gi]
      xschem setprop -fast rect 2 $gi textpx
      incr gf4_n
      if {[gf_strip_tp $m] ne [gf_strip_tp $base]} { lappend gf4_bad "$f $gi textpx=$v" }
    }
    # the instrument CAN see a honoured token on an analog rect
    if {$dig ne "1" && $gf4_live == 0} {
      xschem setprop -fast rect 2 $gi textpx $gf_tp
      if {[string match "fixed 1 *" [gf_m $gi]]} { incr gf4_live }
      xschem setprop -fast rect 2 $gi textpx
    }
  }
  xschem set_modify 0
}
check "GF4a refused textpx (0 -1 1e9 nan junk 2.99 400.01) and textpx on a digital rect change no metric" \
  [list [expr {$gf4_n > 800}] [expr {$gf4_dig > 0}] [lrange $gf4_bad 0 4]] {1 1 {}}
check "GF4b control: a valid textpx on an analog schematic rect IS honoured" $gf4_live 1
# vlegend: no committed schematic has one, so a sheet is written here
gf_load [gf_sheet [file join $gf_dir gf4v.sch] 1 {vlegend 1}]
set gf4v0 [gf_m 0]
gf_load [gf_sheet [file join $gf_dir gf4vt.sch] 1 [list vlegend 1 textpx $gf_tp]]
check "GF4c textpx on a vlegend strip changes no metric (fixed=0)" \
  [list [string match "fixed 0 *" $gf4v0] [expr {[gf_strip_tp [gf_m 0]] eq [gf_strip_tp $gf4v0]}]] {1 1}

# ---- GF5: an export freezes the text scale and the restore thaws it ---------
gf_load [gf_sheet [file join $gf_dir gf5.sch] 1 [list textpx $gf_tp]]
set gf5a [gf_m 0]
set gf5_rc {}
foreach fmt {svg png} {
  lappend gf5_rc $fmt [catch {xschem print $fmt [file join $gf_dir gf5.$fmt] 640 480 0 0 1000 1200} e]
}
set gf5b [gf_m 0]
xschem zoom_box 0 0 500 600 1.0
set gf5c [gf_m 0]
check "GF5a metrics after print svg/png equal those before (a fixed strip)" \
  [expr {$gf5a eq $gf5b && [string match "fixed 1 *" $gf5a]}] 1
check "GF5b after the exports a zoom still gives textpx px (the freeze was released)" \
  [list [gf_get $gf5c fixed] [gf_near [gf_get $gf5c em_px] $gf_tp] \
     [expr {[gf_get $gf5c txtsizex] ne [gf_get $gf5a txtsizex]}]] {1 1 1}
# GF5c: DURING an export the text scale is the SCREEN's, so a raster twice the
# size draws every margin twice as many pixels deep. GF5a/b only read state
# after the export, so dropping the freeze (save_restore_zoom) or ignoring
# graph_txt_mooz (setup_graph_data) left them green. The instrument: the first
# and last LONG horizontal line (a row lit across more than half the sampled
# columns -- the plot box edges; the 1-on/3-off grid never reaches half) in a
# png at 520x220 and at 1040x440 of the same export box (the `note:` line
# prints them each run). With the freeze dropped the 1x top edge moves DOWN and
# the 2x one barely moves, far outside the 2 px slack. The proportional sheet is
# the control that the instrument scales at all. Display arm only:
# `xschem print png` writes nothing under --nogui.
proc gf_hlines {f} {
  if {[catch {image create photo -file $f} img]} { return "NOIMG" }
  set w [image width $img]; set h [image height $img]
  set bg [$img get 1 1]
  set cols {}
  for {set x 2} {$x < $w - 2} {incr x 3} { lappend cols $x }
  set need [expr {[llength $cols] / 2}]
  set rows {}
  for {set y 0} {$y < $h} {incr y} {
    set n 0
    foreach x $cols { if {[$img get $x $y] ne $bg} { incr n } }
    if {$n > $need} { lappend rows $y }
  }
  image delete $img
  if {[llength $rows] < 2} { return "NOLINES:$rows" }
  return [list [lindex $rows 0] [lindex $rows end]]
}
if {[info commands image] ne {} && [info commands winfo] ne {}} {
  set gf5c_got {}
  foreach {tag extra} [list fixed [list textpx $gf_tp] prop {}] {
    gf_load [gf_sheet [file join $gf_dir gf5c_$tag.sch] 1 $extra 1000 400] {-20 -20 1020 420}
    set ln {}
    foreach s {1 2} {
      set f [file join $gf_dir gf5c_${tag}_$s.png]
      file delete $f
      catch {xschem print png $f [expr {520*$s}] [expr {220*$s}] -20 -20 1020 420}
      lappend ln [gf_hlines $f]
    }
    set ok [expr {[llength [lindex $ln 0]] == 2 && [llength [lindex $ln 1]] == 2}]
    if {$ok} {
      foreach i {0 1} {
        set a [lindex $ln 0 $i]; set b [lindex $ln 1 $i]
        if {![string is integer -strict $a] || ![string is integer -strict $b] ||
            abs($b - 2*$a) > 2} { set ok 0 }
      }
    }
    lappend gf5c_got $tag $ok
    puts "note: GF5c $tag lines 1x/2x = $ln"
  }
  check "GF5c a fixed strip exported at 2x raster draws its plot-box edges at 2x the pixels (the freeze)" \
    [dict get $gf5c_got fixed] 1
  check "GF5c control: a proportional strip's edges scale 2x as well (the instrument scales)" \
    [dict get $gf5c_got prop] 1
} else {
  puts "SKIPPED: GF5c (png export needs a display)"
}

# ---- GF6: a fixed strip's pixel margins are the same on every arm ----------
# The left margin's Y-number width is ANALYTIC (8 chars at 0.62 em), not a
# text_bbox measurement, so the plot box cannot depend on which text path or
# cairo face is live: the --nogui arm (no cairo text) and a display arm must
# give the same pixels. The literals were MEASURED at this commit on both arms
# (--nogui and :99, 1920x1080, openbox) and are pinned on purpose: a
# measured-width margin gave left_px 103.883 on :99 against 105.470 here, and
# no query-vs-draw comparison could see it, because the face live at query time
# never changed in any state this tree reaches (measured across bold-legend
# draws and four cairo_font_name values). A deliberate change to the fixed
# margins re-measures these four numbers.
# Re-measured 2026-10-21 on both arms when the cursor read-out row and the
# second bottom row became ON-DEMAND rows (the user's "a lot of space is being
# wasted" report): with no cursor and no second sweep name neither is reserved,
# and the tick basis no longer grows with the bottom row, which moved left_px.
# GF6b below and rows SWL* of test_wave_subwindows.tcl fence the rows.
gf_load [gf_sheet [file join $gf_dir gf6.sch] 1 [list textpx $gf_tp]]
set gf6 [gf_m 0]
set gf6_bad {}
foreach {k want} {top_px 36.400064999999991 bottom_px 29.994355555555579
                  left_px 102.98115255555554 right_px 37.333400000000005} {
  if {![gf_near [gf_get $gf6 $k] $want]} { lappend gf6_bad "$k=[gf_get $gf6 $k] want $want" }
}
check "GF6 the 18.6667 px strip's pixel margins equal the values measured on both arms" $gf6_bad {}
# GF6b: a cursor brings the second bottom row (cursor X tags), exactly 1.2 em,
# and leaves top / left alone -- no raw is loaded here, so cursor A's read-out
# row (which needs waves, as show_node_measures does) is NOT reserved. Same on
# both arms: no text extent is involved.
pcall {xschem cursor 1 1} ; pcall {xschem cursor 2 1}
set gf6c [gf_m 0]
pcall {xschem cursor 1 0} ; pcall {xschem cursor 2 0}
set gf6o [gf_m 0]
check "GF6b cursors on: sweep_row 1, readout_row 0 (no waves), bottom +1.2 em, top and left unchanged; off restores" \
  [list [gf_get $gf6c sweep_row] [gf_get $gf6c readout_row] \
        [gf_near [expr {[gf_get $gf6c bottom_px] - [gf_get $gf6 bottom_px]}] [expr {1.2 * [gf_get $gf6 em_px]}] 1e-9] \
        [gf_near [gf_get $gf6c top_px] [gf_get $gf6 top_px]] [gf_near [gf_get $gf6c left_px] [gf_get $gf6 left_px]] \
        [expr {$gf6o eq $gf6}]] {1 0 1 1 1 1}

if {$save_gd ne {}} { set ::wviewer_grid_dash_off $save_gd }

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_grid: $npass passed, $fail failed"
# ⚠ THE `OVERALL: ok` LINE IS WHAT MAKES THIS SUITE REGISTERABLE IN
# tests/run_regression.tcl, and it is ADDITIVE -- issue 1645, the same fix
# issue 1615 applied to `wvbs_finish`. `banner_complete` in
# tests/banner_rule.tcl is the ONLY Tcl reader of a case's output, it is the one
# run_regression.tcl sources, and it implements no `RESULT: ALL PASS` spelling
# at all: a suite printing only the RESULT line scores
# `HARNESS: ... (exit=0, OVERALL_ok=0, died=0) ... : FAIL` in the verdict with
# every one of its own checks passing. Measured over this file's real captured
# output on both arms before the line went in: banner_complete answered 0.
# `run_suites.sh` and `full_audit.sh` keep their own EREs and both accept
# `RESULT:`, so the two readers that COULD see this suite were the two that are
# not the gate. RESULT: stays LAST, because `summarize_all` publishes a case's
# last RESULT: line.
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
