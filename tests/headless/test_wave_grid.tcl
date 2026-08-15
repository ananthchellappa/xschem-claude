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
set gx_must {configure_apply display_raw attach_raw add_trace add_graph
             plot_signals grid_toggle sharedx_toggle apply_range wheel_zoom
             pan_x axes_ok
             select_tab new_tab close_tab paste_traces paste_payload
             rawbar_load}
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
foreach p {grid_toggle sharedx_toggle} {
  check "GX8 $p captures but takes NO undo point" \
    [regexp -all {wviewer::push_undo} [wvproc_body $wsrc wviewer::$p]] 0
}

# THE RULE IS ABOUT regenerate, NOT ABOUT THIS FILE. `wviewer::regenerate` is
# called from src/ase_window.tcl too, with a different token variable, so GX4's
# count cannot see it and neither could an audit that only read wave_viewer.tcl.
set aw [file join $repo src ase_window.tcl]
set fp [open $aw r]; set asrc [read $fp]; close $fp
check "GX9 ase_window.tcl has exactly the two known regenerate sites" \
  [pcall {count_emitters $aw {wviewer::regenerate \$key}}] 2
# auto_plot's no-plottable-rows branch clears the AUTO strip's traces and
# regenerates — every other strip carries forward, so it owes the fold, and it
# must take it BEFORE clear_graph_traces (the model mutation).
set gx_ap [wvproc_body $asrc ase::ui::auto_plot]
check_true "GX9 auto_plot folds before it clears the auto strip" \
  [expr {[string first {wviewer::capture_live_view_state $key} $gx_ap] >= 0 &&
         [string first {wviewer::capture_live_view_state $key} $gx_ap] <
         [string first {wviewer::clear_graph_traces $key $gi} $gx_ap]}]
# the OTHER site (the re-plot path) is safe transitively: attach_raw captured a
# few lines above it. Pin that, or a reordering silently reopens the hole.
check_true "GX9 the re-plot path still regenerates after attach_raw" \
  [expr {[string first {wviewer::attach_raw $key} $gx_ap] <
         [string last {wviewer::regenerate $key} $gx_ap]}]

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
check "GH0 the guide's §9.1 carries the sixteen documented viewer keys" \
  [llength $gh_seqs] 16
check "GH0 ...and eleven documented menu accelerators" [llength $gh_menus] 11

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
# whole reason GH0's `== 16` above still holds: `data-bseq="` does not contain
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
set gs_want {sig_type sig_match sig_split signal_entry signal_list signal_list_all
             rawinfo_parse db_label attach_raw plot_dest rawbar_load rawbar_commit
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
  # find a labelled entry anywhere in the viewer menubar; {} = not there
  proc gh_find_entry {mb lab} {
    foreach sub {file view graph cursors options} {
      set m $mb.$sub
      if {![winfo exists $m]} continue
      set last {}
      catch {set last [$m index end]}
      if {![string is integer -strict $last]} continue
      for {set i 0} {$i <= $last} {incr i} {
        if {[catch {$m entrycget $i -label} l]} continue
        if {$l eq $lab} { return [list $m $i] }
      }
    }
    return {}
  }
  set gh_bar $vtop.wvmenubar
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
