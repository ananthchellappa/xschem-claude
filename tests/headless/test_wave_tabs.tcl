# tests/headless/test_wave_tabs.tcl — TABS in the ASE Waveform Viewer
# (contract: doc/claude/specs/waveform_viewer_tabs.md)
#
# The feature: one viewer window can hold several independent stacks of strips.
#   Ctrl-N new tab | Ctrl-W close TAB (nothing at all when there is only one)
#   Ctrl-Q close the window | Ctrl-C copy traces | Ctrl-V paste them
# A tab is a MODEL, not a context (D1): one xschem ctx / canvas / raw per
# window, and every per-view-content array keeps its session-token key and
# always describes the ACTIVE tab, with the inactive tabs frozen in `tabstash`
# (D2, THE STASH).
#
# WHAT IS ASSERTED
#   TK*  PURE, both arms — the model layer on literal arguments:
#        clip_groups (grouping IS the separateness), plan_paste in both modes
#        incl. empty-strip reuse and the APPEND-not-front-insert rule,
#        paste_traces_in_graphs (ranges blanked only on a strip that WAS empty),
#        paste_colors (keep unless taken; a same-colour pair separates),
#        tab_index_after_close, tab_index_of_id.
#   TN*  no-window guards, both arms: every tab/clipboard command returns
#        without throwing when no viewer resolves.
#   TG*  DISPLAY — the real window, real Tk keys through the shipped bindings.
#
# FIXTURE DISCIPLINE (probe placement, overnight_batch_2026_08_01/PLAN.md):
#   * THREE tabs, and strips with DIFFERENT trace counts, so no two index
#     spaces coincide;
#   * a VEC-LESS trace planted at a NON-ZERO model index, so MODEL index !=
#     NODE index (landmine 34/49(f)) — a fixture without it lets an
#     identity mapping pass the whole crossing chain;
#   * the selection witness is MULTI-trace, on a NON-ZERO strip, at a NON-ZERO
#     node, planted on the RECT (never through the model — a model-side plant
#     survives a regenerate either way, which is green-but-hollow), and EVERY
#     strip is read back (landmine 50(d));
#   * the inert `tabid` is read back, so "it landed in the tab that was second"
#     is witnessed independently of "the tabs got reordered" (the `sdid`
#     lesson).
#
# SABOTAGE TABLE — each one-token edit must kill EXACTLY its target legs, then
# revert, then green. Re-run the relevant row after touching anything here.
#   S1  wviewer::tab_thaw: drop the `dict set layouts $token $lay` line
#         -> TG3 (per-tab content), TG9/TG10 (paste lands in the wrong model)
#   S2  wviewer::select_tab: delete the capture_live_view_state call
#         -> TG4 only. ⚠ needs the MULTI-trace, non-zero-strip witness: a
#            head-only fold passes every single-selection leg (0194 SAB-3).
#   S3  wviewer::plan_paste: make the multi arm return the single arm's sites
#         -> TG9. Needs >= 2 source strips AND >= 2 traces in one of them, or
#            flatten and preserve give the same answer.
#   S4  wviewer::plan_paste multi: `$ngraphs + $k - $nreuse` -> `$k`
#         (front-insert instead of append) -> TG9's order legs
#   S5  wviewer::paste_colors: return the source colour unconditionally
#         -> TG12 only
#   S6  wviewer::close_tab: replace the `$n <= 1` refusal with a call to
#         wviewer::close (the pre-ruling fall-through) -> TG6a
#   S7  wviewer::select_tab: apply the OUTGOING record's `view`
#         -> TG5. Needs two tabs with DIFFERENT windows on the same strip index.
#   S8  wviewer::tab_drop_transients: delete the trace_drag_clear call -> TG14
#   S9  wviewer::echo: delete the `xschem log_action -result` half
#         -> TG13's FILE legs ONLY; the pane legs stay green, which is the
#            whole point of the pair (and of issue 0207).
#         ⚠ The obvious sabotage -- re-adding a `[info exists ::has_x]` guard,
#         the literal 0207 shape -- was TRIED and is HOLLOW here: under a
#         DISPLAY `::has_x` exists, so the guard never fires, and TG13 only
#         runs under a DISPLAY (a viewer needs has_x to open at all). Measured:
#         the suite stayed at its full count with that guard in place. A
#         sabotage that cannot fire proves nothing.
#
# NOT asserted, stated rather than hidden: PIXELS. That the tab bar looks
# right — button widths, the active tab's colour, where it sits relative to the
# canvas — is eyeball-only, like every other wave rendering
# (memory `pixel-deliverables-need-eyeball`). What IS asserted is that the
# frame is packed/unpacked at the right tab counts and carries one button per
# tab plus the `+`.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_tabs.tcl
#   ./src/xschem --pipe -q --nogui --nolog --script tests/headless/test_wave_tabs.tcl
#   ./src/xschem --pipe -q --logdir /tmp/wt --script tests/headless/test_wave_tabs.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
# error-guarded call: a MISSING proc must make its own leg FAIL, not abort the
# whole file through the outer catch
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}
proc note {s} { puts "  note: $s" }

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvtabs]

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

# which arm are we in? (the AA0 idiom — a suite that cannot say which arm it
# ran in cannot be trusted about what it covered)
set ::arm display
if {[catch {set fd [open /proc/self/cmdline rb]; set cl [read $fd]; close $fd}]} { set cl {} }
if {[string first "--nogui" [string map {\x00 { }} $cl]] >= 0} { set ::arm nogui }

if {[catch {

# ============================================================================
# TK* — PURE model layer. Literal arguments, no window, BOTH arms.
# ============================================================================

# --- clip_groups: the grouping IS the separateness --------------------------
set tk_items {{gi 0 tr {expr a name a vec a color 4}}
              {gi 2 tr {expr b name b vec b color 5}}
              {gi 0 tr {expr c name c vec c color 7}}}
check "TK1 two source strips -> two groups" \
  [llength [pcall {wviewer::clip_groups $tk_items}]] 2
check "TK1 group 0 keeps both of its traces, in order" \
  [lmap t [lindex [pcall {wviewer::clip_groups $tk_items}] 0] \
     {wviewer::dget $t expr {}}] {a c}
check "TK1 group 1 is the other strip" \
  [lmap t [lindex [pcall {wviewer::clip_groups $tk_items}] 1] \
     {wviewer::dget $t expr {}}] {b}
check "TK1 malformed items are dropped, not diagnosed" \
  [llength [pcall {wviewer::clip_groups {{gi x tr {a b}} {gi 1 tr {}}}}]] 0
check "TK1 an empty clipboard yields no groups" \
  [llength [pcall {wviewer::clip_groups {}}]] 0

# --- plan_paste: single -----------------------------------------------------
check "TK2 single: every group lands on the target strip" \
  [dict get [pcall {wviewer::plan_paste single 3 1 3}] sites] {1 1 1}
check "TK2 single: creates nothing" \
  [dict get [pcall {wviewer::plan_paste single 3 1 3}] new] 0
check "TK2 single: an out-of-range target is clamped" \
  [dict get [pcall {wviewer::plan_paste single 3 9 1}] sites] {2}
check "TK2 single: an empty stack creates one strip" \
  [dict get [pcall {wviewer::plan_paste single 0 0 2}] new] 1
check "TK2 single: ...and both groups land in it" \
  [dict get [pcall {wviewer::plan_paste single 0 0 2}] sites] {0 0}
check "TK2 the auto strip is never a landing site (single)" \
  [dict get [pcall {wviewer::plan_paste single 2 1 1 1 {}}] sites] {2}
check "TK2 no groups -> no plan" \
  [pcall {wviewer::plan_paste multi 3 0 0}] {new 0 sites {}}

# --- plan_paste: multi. THE APPEND RULE. ------------------------------------
check "TK3 multi: one strip per group, APPENDED at the bottom" \
  [dict get [pcall {wviewer::plan_paste multi 2 0 2}] sites] {2 3}
check "TK3 multi: ...and it says it created two" \
  [dict get [pcall {wviewer::plan_paste multi 2 0 2}] new] 2
# ⚠ the whole point of S4: plot_signals' multi arm FRONT-inserts (newest on
# top) and owes a +nnew shift of the target and the highlight set. A paste is a
# copy of a layout fragment and must read the way it did in the source, so it
# appends and owes neither. A sites list starting at 0 would be the front
# insert.
check_true "TK3 multi: the first new site is BELOW every existing strip" \
  [expr {[lindex [dict get [pcall {wviewer::plan_paste multi 2 0 2}] sites] 0] >= 2}]
check "TK3 multi: empty strips are reused first, lowest index first" \
  [dict get [pcall {wviewer::plan_paste multi 4 0 2 -1 {3 1}}] sites] {1 3}
check "TK3 multi: ...and then nothing is created" \
  [dict get [pcall {wviewer::plan_paste multi 4 0 2 -1 {3 1}}] new] 0
check "TK3 multi: one empty + one shortfall" \
  [dict get [pcall {wviewer::plan_paste multi 3 0 2 -1 {2}}] sites] {2 3}
check "TK3 multi: ...counted as one new strip" \
  [dict get [pcall {wviewer::plan_paste multi 3 0 2 -1 {2}}] new] 1
check "TK3 multi: the auto strip is refused even when empty" \
  [dict get [pcall {wviewer::plan_paste multi 3 0 1 2 {2}}] sites] {3}
check "TK3 multi: out-of-range and duplicate empties are dropped" \
  [dict get [pcall {wviewer::plan_paste multi 2 0 1 -1 {9 1 1 -3}}] sites] {1}

# --- paste_traces_in_graphs -------------------------------------------------
set TKG0 [dict create traces {{expr z name z vec z color 4}} logx 0 logy 0 \
            x1 0 x2 1 y1 0 y2 2]
set TKG1 [dict create traces {} logx 0 logy 0 x1 5 x2 6 y1 7 y2 8]
set tk_gs [list $TKG0 $TKG1]
set tk_grp {{{expr a name a vec a color 9}}}
set tk_out [pcall {wviewer::paste_traces_in_graphs $tk_gs $tk_grp {1} {{9}}}]
check "TK4 the trace arrived on the landing strip" \
  [llength [dict get [lindex $tk_out 1] traces]] 1
check "TK4 ...as an APPEND (it is last)" \
  [wviewer::dget [lindex [dict get [lindex $tk_out 1] traces] end] expr {}] a
check "TK4 a strip that WAS empty has its x window blanked to auto" \
  [dict get [lindex $tk_out 1] x1] {}
check "TK4 ...and its y window too (landmine 34(a))" \
  [dict get [lindex $tk_out 1] y2] {}
check "TK4 the other strip is untouched" \
  [llength [dict get [lindex $tk_out 0] traces]] 1
set tk_out2 [pcall {wviewer::paste_traces_in_graphs $tk_gs $tk_grp {0} {{9}}}]
check "TK4 a strip that already had traces KEEPS its window" \
  [dict get [lindex $tk_out2 0] x1] 0
check "TK4 ...and gets the trace appended" \
  [llength [dict get [lindex $tk_out2 0] traces]] 2
# two groups onto one site (single mode): only the first can find it empty
set tk_out3 [pcall {wviewer::paste_traces_in_graphs $tk_gs \
  {{{expr a name a vec a color 9}} {{expr b name b vec b color 10}}} {1 1} {{9} {10}}}]
check "TK4 single-mode: both groups land on the one site" \
  [llength [dict get [lindex $tk_out3 1] traces]] 2
check "TK4 single-mode: in source order" \
  [lmap t [dict get [lindex $tk_out3 1] traces] {wviewer::dget $t expr {}}] {a b}
check "TK4 single-mode: the blank happened once, on the first arrival" \
  [dict get [lindex $tk_out3 1] x1] {}
check "TK4 an out-of-range site is skipped, not fatal" \
  [llength [pcall {wviewer::paste_traces_in_graphs $tk_gs $tk_grp {9} {{9}}}]] 2

# --- paste_colors -----------------------------------------------------------
check "TK5 a free colour is KEPT (recognisable across tabs)" \
  [pcall {wviewer::paste_colors $tk_gs {{{expr a name a vec a color 12}}} {1}}] {12}
check_true "TK5 a colour already in the landing strip is re-planned" \
  [expr {[lindex [pcall {wviewer::paste_colors $tk_gs \
     {{{expr a name a vec a color 4}}} {0}}] 0 0] != 4}]
set tk_two [lindex [pcall {wviewer::paste_colors $tk_gs \
  {{{expr a name a vec a color 12} {expr b name b vec b color 12}}} {1}}] 0]
check_true "TK5 two source traces sharing a colour SEPARATE" \
  [expr {[lindex $tk_two 0] != [lindex $tk_two 1]}]
check "TK5 one colour per pasted trace" [llength $tk_two] 2

# --- the tab list rules -----------------------------------------------------
check "TK6 closing a middle tab keeps the index" \
  [pcall {wviewer::tab_index_after_close 1 3}] 1
check "TK6 closing the LAST tab steps left" \
  [pcall {wviewer::tab_index_after_close 2 3}] 1
check "TK6 closing the first of two -> 0" \
  [pcall {wviewer::tab_index_after_close 0 2}] 0
check "TK6 closing the last of two -> 0" \
  [pcall {wviewer::tab_index_after_close 1 2}] 0
set tk_recs {{id 1 name {Tab 1}} {id 5 name {Tab 5}}}
check "TK7 an id resolves to its index" \
  [pcall {wviewer::tab_index_of_id $tk_recs 5}] 1
check "TK7 an unknown id is -1, not an error" \
  [pcall {wviewer::tab_index_of_id $tk_recs 9}] -1
check "TK7 an empty list is -1" [pcall {wviewer::tab_index_of_id {} 1}] -1

# ============================================================================
# TN* — no viewer resolves. Nothing may throw. Both arms.
# ============================================================================
check "TN1 new_tab with no viewer -> {}"      [pcall {wviewer::new_tab no/such/tok}] {}
check "TN1 close_tab with no viewer -> 0"     [pcall {wviewer::close_tab {} no/such/tok}] 0
check "TN1 select_tab with no viewer -> 0"    [pcall {wviewer::select_tab 1 no/such/tok}] 0
check "TN1 copy_traces with no viewer -> 0"   [pcall {wviewer::copy_traces no/such/tok}] 0
check "TN1 paste_traces with no viewer -> 0"  [pcall {wviewer::paste_traces no/such/tok}] 0
check "TN2 tab_count of a non-viewer is 0"    [pcall {wviewer::tab_count no/such/tok}] 0
check "TN2 tab_index of a non-viewer is -1"   [pcall {wviewer::tab_index no/such/tok}] -1
check "TN2 tab_records of a non-viewer is {}" [pcall {wviewer::tab_records no/such/tok}] {}
check "TN3 the %W wrappers survive a non-viewer canvas" \
  [pcall {wviewer::new_tab_at .drw}] {}
check "TN3 ...close_tab_at too"   [pcall {wviewer::close_tab_at .drw}] {}
check "TN3 ...copy_traces_at too" [pcall {wviewer::copy_traces_at .drw}] {}
check "TN3 ...paste_traces_at too" [pcall {wviewer::paste_traces_at .drw}] {}
check "TN3 ...close_window_at too" [pcall {wviewer::close_window_at .drw}] {}

# ============================================================================
# TG* — the real window. Self-SKIPs without a usable DISPLAY.
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
  # A generated KeyPress goes to the display's FOCUS window and the WSLg focus
  # round trip is async, so every generate is gated on Tk reporting $w as the
  # focus owner and retried until $done (an expr in the CALLER's scope) turns
  # true. Returns 0 rather than hanging, so a stall is a FAIL with a note.
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
    puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
    return 0
  }
  proc ngraphs {tok} { llength [dict get [wviewer::layout_for $tok] graphs] }
  proc ntraces {tok gi} {
    set gs [dict get [wviewer::layout_for $tok] graphs]
    if {$gi >= [llength $gs]} { return -1 }
    return [llength [dict get [lindex $gs $gi] traces]]
  }
  proc trexprs {tok gi} {
    set gs [dict get [wviewer::layout_for $tok] graphs]
    if {$gi >= [llength $gs]} { return {} }
    return [lmap t [dict get [lindex $gs $gi] traces] {wviewer::dget $t expr {}}]
  }

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "TG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: TG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  # spy on the replayable-log seam
  set ::wt_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wt_log $line ; wviewer::__real_log_action $line }
  # ...and on the CIW pane half of the echo seam
  set ::wt_ciw {}
  if {[info commands ::ciw_echo] ne {}} {
    rename ::ciw_echo ::wt_real_ciw_echo
    proc ::ciw_echo {msg args} {
      lappend ::wt_ciw $msg
      uplevel 1 [list ::wt_real_ciw_echo $msg {*}$args]
    }
  }
  proc wt_ciw_has {s} {
    foreach l $::wt_ciw { if {[string first $s $l] >= 0} { return 1 } }
    return 0
  }
  proc loglines {} {
    set fn {}
    catch {set fn [xschem get actionlog_filename]}
    if {$fn eq {} || ![file exists $fn]} { return {} }
    set fd [open $fn r]; set body [read $fd]; close $fd
    return [split [string trimright $body \n] \n]
  }
  proc log_has {s} {
    foreach l [loglines] { if {[string first $s $l] >= 0} { return 1 } }
    return 0
  }

  # a synthetic raw, hermetic (no ngspice, no .raw file)
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvtabs.raw dc vsweep 0 1.0 0.1}
  foreach v {a1 a2 a3 b1 b2 c1 c2 c3 c4} {
    pcall {xschem raw add $v "vsweep 1 +"}
  }
  set rawvars [split [pcall {xschem raw list}] "\n"]
  check_true "TG0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $rawvars a1] >= 0 && [lsearch -exact $rawvars c4] >= 0}]

  # ---- TG1: a ONE-TAB viewer is the shipped viewer -------------------------
  check "TG1 a fresh viewer has exactly one tab" [wviewer::tab_count $tok] 1
  check "TG1 ...and it is the active one" [wviewer::tab_index $tok] 0
  check "TG1 ...with a stable id" [wviewer::tab_id $tok] 1
  check_true "TG1 the tab bar widget exists" [winfo exists $vtop.wvtabs]
  # `pack info` on an unpacked widget THROWS; pcall turns that into the ERR:
  # string, so the assertion is "it threw", spelled with the real widget path.
  proc wt_packed {w} { expr {[catch {pack info $w}] ? 0 : 1} }
  check "TG1 ...but is NOT packed at one tab (the issue-0151 rule)" \
    [wt_packed $vtop.wvtabs] 0
  check "TG1 File > Close Tab is disabled at one tab" \
    [pcall {$vtop.wvmenubar.file entrycget {Close Tab} -state}] disabled
  check "TG1 File > Close Window is available" \
    [pcall {$vtop.wvmenubar.file entrycget {Close Window} -state}] normal

  # ---- the fixture: THREE tabs, different shapes ---------------------------
  # tab 1: two strips, 3 traces then 1 -- and a VEC-LESS trace at MODEL index 1
  # of strip 0, so MODEL index != NODE index for everything above it.
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  foreach {gi vec} {0 a1 0 a2 0 a3 1 b1} { pcall {wviewer::add_trace $tok $gi $vec} }
  set gs [dict get [wviewer::layout_for $tok] graphs]
  set G0 [lindex $gs 0]
  set trs [dict get $G0 traces]
  set trs [linsert $trs 1 [dict create expr {} name {} vec {} color 15]]
  dict set G0 traces $trs
  wviewer::set_graphs $tok [lreplace $gs 0 0 $G0]
  wviewer::regenerate $tok
  check "TG2 strip 0 carries 4 MODEL traces" [ntraces $tok 0] 4
  check "TG2 ...but only 3 NODE traces (the vec-less one occupies no node)" \
    [pcall {wviewer::node_count [lindex [dict get [wviewer::layout_for $tok] graphs] 0]}] 3
  check_true "TG2 so MODEL and NODE index spaces DIVERGE (the fixture has teeth)" \
    [expr {[pcall {wviewer::node_index_of_trace \
      [lindex [dict get [wviewer::layout_for $tok] graphs] 0] 2}] != 2}]

  # ---- TG3: a second tab, and per-tab content ------------------------------
  set ::wt_log {}
  set id2 [pcall {wviewer::new_tab $tok}]
  check_true "TG3 new_tab returned an id" [expr {$id2 ne {} && $id2 ne 1}]
  check "TG3 two tabs now" [wviewer::tab_count $tok] 2
  check "TG3 ...and the new one is active" [wviewer::tab_index $tok] 1
  check "TG3 a new tab starts with ONE empty strip" [ngraphs $tok] 1
  check "TG3 ...which is empty" [ntraces $tok 0] 0
  check "TG3 the plot mode was inherited" [wviewer::plot_mode $tok] \
    [wviewer::dget [lindex [wviewer::tab_records $tok] 0] mode single]
  check "TG3 the bar is packed once there is a choice" \
    [pcall {dict get [pack info $vtop.wvtabs] -side}] top
  # `pack info` does not report -before; the SLAVE ORDER is what -before set,
  # and it is the property that matters (the canvas is -fill both -expand true,
  # so anything packed after it would get zero height).
  check_true "TG3 ...above the canvas in the packing order" \
    [expr {[lsearch -exact [pack slaves $vtop] $vtop.wvtabs] >= 0 &&
           [lsearch -exact [pack slaves $vtop] $vtop.wvtabs] <
           [lsearch -exact [pack slaves $vtop] $vdrw]}]
  check "TG3 one button per tab, plus the +" \
    [llength [winfo children $vtop.wvtabs]] 3
  check "TG3 File > Close Tab is enabled at two tabs" \
    [pcall {$vtop.wvmenubar.file entrycget {Close Tab} -state}] normal
  check "TG3 exactly one new_tab log line" \
    [llength [lsearch -all -inline -glob $::wt_log {wviewer::new_tab *}]] 1
  check_true "TG3 the CIW was told" [wt_ciw_has "new tab"]

  # fill tab 2 differently (4 traces on one strip)
  foreach v {c1 c2 c3 c4} { pcall {wviewer::add_trace $tok 0 $v} }
  check "TG3 tab 2 holds its own traces" [ntraces $tok 0] 4
  # ...and back to tab 1: its two strips must be intact
  check "TG4 switch back to tab 1" [pcall {wviewer::select_tab 1 $tok}] 1
  check "TG4 tab 1's strips came back" [ngraphs $tok] 2
  check "TG4 ...with their trace counts" \
    [list [ntraces $tok 0] [ntraces $tok 1]] {4 1}
  check "TG4 ...and their contents" [trexprs $tok 1] {b1}
  check "TG4 switching to tab 2 restores ITS model" \
    [expr {[wviewer::select_tab $id2 $tok] && [ngraphs $tok] == 1 \
           && [ntraces $tok 0] == 4}] 1
  check "TG4 re-selecting the active tab is a no-op" \
    [pcall {wviewer::select_tab $id2 $tok}] 0
  check "TG4 an unknown tab id is refused" \
    [pcall {wviewer::select_tab 999 $tok}] 0

  # ---- TG5: the SELECTION survives a switch (landmine 50) ------------------
  # Witness rules of 50(d), all four: plant on the RECT (a model-side plant
  # survives either way = hollow), MULTI-trace (a head-only fold passes every
  # single-selection leg), a NON-ZERO strip and a NON-ZERO node (atoi("") reads
  # a destroyed token as node 0), and read back EVERY strip.
  pcall {wviewer::select_tab 1 $tok}
  # tab 1 strip 1 has one trace; give it three so a multi-selection at nodes
  # 1 and 2 is possible on a NON-zero strip
  foreach v {b2 a1} { pcall {wviewer::add_trace $tok 1 $v} }
  wviewer::regenerate $tok
  check "TG5 the witness strip has 3 nodes" \
    [pcall {wviewer::node_count [lindex [dict get [wviewer::layout_for $tok] graphs] 1]}] 3
  xschem new_schematic switch $vdrw
  pcall {wviewer::with_edit $tok {
    xschem setprop -fast rect 2 1 hilight_wave 1
    xschem setprop -fast rect 2 1 sel_waves {1 2}
  }}
  check "TG5 the selection is on the RECT before the switch" \
    [pcall {wviewer::selected_waves $vdrw 1}] {1 2}
  check "TG5 ...and strip 0 has none" [pcall {wviewer::selected_waves $vdrw 0}] {}
  pcall {wviewer::select_tab $id2 $tok}
  pcall {wviewer::select_tab 1 $tok}
  check "TG5 the MULTI-trace selection survived the round trip" \
    [pcall {wviewer::selected_waves $vdrw 1}] {1 2}
  check "TG5 ...and did not appear on the neighbour" \
    [pcall {wviewer::selected_waves $vdrw 0}] {}

  # ---- TG6: the per-tab VIEW cache (pan/zoom survives a switch) ------------
  # Two tabs with DIFFERENT windows on the SAME strip index, so applying the
  # outgoing tab's ranges (S7) is visible.
  pcall {wviewer::select_tab 1 $tok}
  pcall {wviewer::with_edit $tok {xschem setprop -fast rect 2 0 x1 0.25}}
  pcall {wviewer::with_edit $tok {xschem setprop -fast rect 2 0 x2 0.75}}
  set wt_t1x [pcall {xschem getprop rect 2 0 x1}]
  pcall {wviewer::select_tab $id2 $tok}
  pcall {wviewer::with_edit $tok {xschem setprop -fast rect 2 0 x1 0.1}}
  set wt_t2x [pcall {xschem getprop rect 2 0 x1}]
  check_true "TG6 the two tabs really carry different windows" \
    [expr {$wt_t1x ne $wt_t2x}]
  pcall {wviewer::select_tab 1 $tok}
  check "TG6 tab 1's pan came back, not tab 2's" \
    [pcall {xschem getprop rect 2 0 x1}] $wt_t1x
  check_true "TG6 ...and it is NOT the model (no auto axis was pinned)" \
    [expr {[wviewer::dget [lindex [dict get [wviewer::layout_for $tok] graphs] 0] x1 {}] eq {}}]

  # ---- TG7: half-armed gestures do not cross a tab boundary ---------------
  set ::wviewer::drag_from($tok) 1
  set ::wviewer::drag_active($tok) 1
  set ::wviewer::tdrag_gi($tok) 1
  pcall {wviewer::select_tab $id2 $tok}
  check "TG7 a half-armed strip drag was disarmed by the switch" \
    [expr {$::wviewer::drag_from($tok)}] -1
  check "TG7 ...and so was the trace drag" [expr {$::wviewer::tdrag_gi($tok)}] -1

  # ---- TG8: window options follow the tab ---------------------------------
  pcall {wviewer::select_tab 1 $tok}
  pcall {wviewer::grid_toggle 0 $tok}
  set wt_g1 [wviewer::grid_shown $tok]
  pcall {wviewer::select_tab $id2 $tok}
  pcall {wviewer::grid_toggle 1 $tok}
  check_true "TG8 the two tabs carry different grid settings" \
    [expr {[wviewer::grid_shown $tok] != $wt_g1}]
  pcall {wviewer::select_tab 1 $tok}
  check "TG8 the grid followed the tab back" [wviewer::grid_shown $tok] $wt_g1
  check "TG8 ...and so did its menu mirror" \
    [expr {$::wviewer::gridshow($tok)}] $wt_g1

  # ---- TG9: COPY / PASTE, multi-plot keeps separateness -------------------
  # source: tab 1, a selection spanning TWO strips with a NON-ADJACENT model
  # pair on strip 0 (models 0 and 2 -- 0 and 1 could not discriminate the
  # index adjustment, landmine 49(a)).
  pcall {wviewer::select_tab 1 $tok}
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  pcall {wviewer::with_edit $tok {
    xschem setprop -fast rect 2 0 hilight_wave 0
    xschem setprop -fast rect 2 0 sel_waves {0 2}
    xschem setprop -fast rect 2 1 hilight_wave 0
    xschem setprop -fast rect 2 1 sel_waves {}
  }}
  set ::wt_ciw {}
  set wt_n [pcall {wviewer::copy_traces $tok}]
  check "TG9 copy took 3 traces (2 from strip 0, 1 from strip 1)" $wt_n 3
  check "TG9 the clipboard groups them by SOURCE STRIP" \
    [llength [wviewer::clip_groups [wviewer::dget [wviewer::clipboard] items {}]]] 2
  check_true "TG9 the CIW reported the copy" [wt_ciw_has "copied 3 trace"]
  check "TG9 a copy writes NO replay line (it mutates nothing)" \
    [llength [lsearch -all -inline -glob $::wt_log {wviewer::copy*}]] 0
  # destination: a THIRD tab, multi-plot
  set id3 [pcall {wviewer::new_tab $tok}]
  check "TG9 three tabs" [wviewer::tab_count $tok] 3
  pcall {wviewer::set_plot_mode multi $tok}
  set ::wt_log {}
  set ::wt_ciw {}
  set wt_p [pcall {wviewer::paste_traces $tok}]
  check "TG9 the paste landed 3 traces" $wt_p 3
  check_true "TG9 multi-plot kept them SEPARATE (2 strips got traces)" \
    [expr {[llength [lsearch -all -inline -glob \
       [lmap g [dict get [wviewer::layout_for $tok] graphs] \
          {llength [dict get $g traces]}] {[1-9]*}]] == 2}]
  check_true "TG9 the pair from ONE source strip stayed together" \
    [expr {2 in [lmap g [dict get [wviewer::layout_for $tok] graphs] \
                   {llength [dict get $g traces]}]}]
  check "TG9 exactly one paste log line for the whole gesture" \
    [llength [lsearch -all -inline -glob $::wt_log {wviewer::paste_payload *}]] 1
  check_true "TG9 the CIW reported the paste" [wt_ciw_has "pasted 3 trace"]
  check "TG9 it landed in the tab it was pasted into" [wviewer::tab_id $tok] $id3

  # ---- TG10: single-plot FLATTENS -----------------------------------------
  set id4 [pcall {wviewer::new_tab $tok}]
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::paste_traces $tok}
  set wt_counts [lmap g [dict get [wviewer::layout_for $tok] graphs] \
                   {llength [dict get $g traces]}]
  check "TG10 single-plot put all 3 on ONE strip" \
    [llength [lsearch -all -inline -glob $wt_counts {[1-9]*}]] 1
  check "TG10 ...all three of them" [lindex [lsort -integer $wt_counts] end] 3

  # ---- TG11: one undo point for the whole paste ---------------------------
  set wt_before [ntraces $tok [expr {[lsearch -glob $wt_counts {[1-9]*}]}]]
  pcall {wviewer::undo $tok}
  set wt_counts2 [lmap g [dict get [wviewer::layout_for $tok] graphs] \
                    {llength [dict get $g traces]}]
  check "TG11 one `u` took the WHOLE paste back" \
    [llength [lsearch -all -inline -glob $wt_counts2 {[1-9]*}]] 0

  # ---- TG12: colours ------------------------------------------------------
  pcall {wviewer::redo $tok}
  set wt_pal {}
  foreach g [dict get [wviewer::layout_for $tok] graphs] {
    set cs [lmap t [dict get $g traces] {wviewer::dget $t color {}}]
    if {[llength $cs]} { set wt_pal $cs }
  }
  check "TG12 every pasted trace on one strip has a DISTINCT colour" \
    [llength [lsort -unique $wt_pal]] [llength $wt_pal]

  # ---- TG13: BOTH channels (R6 / issue 0207) ------------------------------
  # The pane half is asserted above by the wt_ciw spy. The FILE half needs
  # --logdir; when the suite runs --nolog there is no file and the leg says so
  # rather than passing vacuously.
  set ::wt_ciw {}
  pcall {wviewer::new_tab $tok}
  check_true "TG13 the pane got the notice" [wt_ciw_has "new tab"]
  if {[pcall {xschem get actionlog_filename}] ne {} && [llength [loglines]]} {
    check_true "TG13 ...and so did the LOG FILE (the 0207 rule)" \
      [log_has "wviewer: new tab"]
    check_true "TG13 the replay line is in the file too" \
      [log_has "wviewer::new_tab"]
  } else {
    note "TG13 log-FILE legs need --logdir; not run on this invocation"
  }

  # ---- TG14: Ctrl-W REFUSES at one tab (D9a) ------------------------------
  # Get back to exactly one tab.
  while {[wviewer::tab_count $tok] > 1} {
    if {![pcall {wviewer::close_tab {} $tok}]} break
  }
  check "TG14 back to one tab" [wviewer::tab_count $tok] 1
  check "TG14 the bar unpacked again" [wt_packed $vtop.wvtabs] 0
  set ::wt_ciw {}
  set ::wt_log {}
  check "TG14 close_tab on the ONLY tab refuses" [pcall {wviewer::close_tab {} $tok}] 0
  check_true "TG14 ...and says so" [wt_ciw_has "only one tab"]
  check_true "TG14 ...and the window is STILL UP" [winfo exists $vtop]
  check "TG14 ...and the registry still holds it" [wviewer::window_for $tok] $vtop
  check "TG14 a refusal writes NO log line (nothing changed)" [llength $::wt_log] 0

  # ---- TG15: the five chords through the SHIPPED bindings -----------------
  foreach {wt_seq wt_proc} {Control-Key-n new_tab_at Control-Key-w close_tab_at
                            Control-Key-q close_window_at Control-Key-c copy_traces_at
                            Control-Key-v paste_traces_at} {
    check_true "TG15 <$wt_seq> is a WaveViewer default" \
      [expr {[bind WaveViewer <$wt_seq>] ne {}}]
    check_true "TG15 <$wt_seq> calls wviewer::$wt_proc %W" \
      [string match "*wviewer::$wt_proc %W*" [bind WaveViewer <$wt_seq>]]
    check_true "TG15 <$wt_seq> breaks (it may not travel on)" \
      [string match {*break*} [bind WaveViewer <$wt_seq>]]
    check "TG15 <$wt_seq> is NOT bound on the canvas widget" \
      [bind $vdrw <$wt_seq>] {}
  }
  check "TG15 the WaveViewer tag is still at bindtags index 1" \
    [lindex [bindtags $vdrw] 1] WaveViewer
  check "TG15 ...exactly once" \
    [llength [lsearch -all -exact [bindtags $vdrw] WaveViewer]] 1

  # a REAL Ctrl-N through Tk
  set wt_n0 [wviewer::tab_count $tok]
  set wt_d [send_key $vdrw <Control-Key-n> {[wviewer::tab_count $tok] > $wt_n0}]
  check "TG16 a real Ctrl-N opened a tab" $wt_d 1
  check "TG16 two tabs now" [wviewer::tab_count $tok] 2
  # a REAL Ctrl-W closes it again
  set wt_d [send_key $vdrw <Control-Key-w> {[wviewer::tab_count $tok] == 1}]
  check "TG16 a real Ctrl-W closed the tab" $wt_d 1
  check_true "TG16 ...and the window survived it" [winfo exists $vtop]

  # ---- TG17: rc WINS over the default (the CG6 contract) ------------------
  set wt_saved [bind WaveViewer <Control-Key-n>]
  bind WaveViewer <Control-Key-n> {break}
  set ::wviewer::tagbinds 0
  wviewer::install_default_binds
  check "TG17 install_default_binds does not overwrite an rc binding" \
    [bind WaveViewer <Control-Key-n>] {break}
  bind WaveViewer <Control-Key-n> $wt_saved
  check "TG17 the default is restorable" \
    [string match {*new_tab_at*} [bind WaveViewer <Control-Key-n>]] 1

  # ---- TG18: forget leaves NOTHING behind ---------------------------------
  pcall {wviewer::new_tab $tok}
  check_true "TG18 a stash exists while the window does" \
    [expr {[info exists ::wviewer::tabstash($tok)]}]
  set ::wt_ciw {}
  pcall {wviewer::close_window_at $vdrw}
  update
  check_true "TG18 Ctrl-Q's handler closed the window" [expr {![winfo exists $vtop]}]
  check "TG18 the registry is clean" [wviewer::window_for $tok] {}
  foreach wt_a {tabstash curtab tabseq layouts mode target sharedx gridshow
                undo_hist redo_hist wavehl} {
    check "TG18 no $wt_a entry survived the close" \
      [pcall {expr {[info exists ::wviewer::${wt_a}($tok)] ? 1 : 0}}] 0
  }
  check_true "TG18 ...and the process is still alive (Ctrl-Q is not quit_xschem)" \
    [expr {[info commands xschem] ne {}}]

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  if {[info commands ::wt_real_ciw_echo] ne {}} {
    rename ::ciw_echo {}
    rename ::wt_real_ciw_echo ::ciw_echo
  }
  }
} else {
  puts "SKIPPED: TG* GUI legs (no usable DISPLAY)"
  puts "NOTE: every window-level tab behaviour (switching, the bar, the keys,"
  puts "NOTE: copy/paste end to end) is DISPLAY-only -- wviewer::open returns 0"
  puts "NOTE: without has_x and regenerate needs Tk (landmine 41). This arm"
  puts "NOTE: covers the PURE model layer and the no-window guards only."
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts $::errorInfo
  incr fail
}

# The count is part of the contract: silent coverage loss is itself a failure.
# The count is part of the contract: silent coverage loss is itself a failure.
# THREE numbers, not two -- TG13's two log-FILE legs only exist when the run was
# given a --logdir, so a run without one is legitimately two checks shorter and
# must not be scored as coverage loss.
set wt_haslog [expr {[pcall {xschem get actionlog_filename}] ne {}}]
if {$::arm eq {nogui}} {
  set wt_expect 56
} elseif {$wt_haslog} {
  set wt_expect 169
} else {
  set wt_expect 167
}
if {$fail == 0 && $npass != $wt_expect} {
  puts "FAIL: TZ1 expected $wt_expect checks on the $::arm arm\
(log file: $wt_haslog), ran $npass : FAIL"
  incr fail
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
