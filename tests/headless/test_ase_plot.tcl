# ASE-L -> Waveform Viewer wiring (item 13 of doc/claude/ase_l_batch, spec
# doc/claude/specs/waveform_viewer.md "ASE integration"):
#   PH1  ase::plot_sim_type: last enabled analysis in the fixed emit order
#        op dc ac tran; {} when none (headless, pure)
#   PH2  ase::last_rawfile: {} for an unknown session / a session with no raw
#        artifact; the exact <rundir>/<cell>_ase.raw path once the file
#        exists (headless)
#   PH3  ase::ui::plot_map_expr: -i(v1) -> `i(v1) -1 *` RPN, everything else
#        verbatim after a trim, bare `-` untouched (headless, pure)
#   PH4  wviewer auto-graph model helpers: ensure_auto_graph find-or-append
#        (`auto 1` marker), clear_graph_traces keeps the graph + neighbors,
#        auto_graph_index (headless, pure)
#   P1   op-only run with a Plot-checked row -> auto-plot NOTICE arm: run
#        Ready/Green, NO viewer opened (GUI + ngspice)
#   P2   op-only Results > Direct Plot: menu entry live, mode seizes the
#        design-canvas bindings, click queues, sod_end -> notice arm (no
#        viewer), bindings restored VERBATIM, session outputs UNCHANGED (D2)
#   P3   dc-sweep run, id=-i(v1) + v(d) Plot-checked -> viewer auto-opened,
#        raw attached (loaded INDEX >= 0, sim_type dc, points 181), auto
#        graph 0 carries both traces (id materialized via `raw add` from the
#        D6-mapped RPN), redraw rc 0 (GUI + ngspice)
#   PL   (issue 0153) `xschem hilight_netname/-instname -layer <n>`: highlight
#        in the PLAIN color of a drawing layer (stored as the engine's NEGATIVE
#        hilight value, read back through `list_hilights all`) rather than the
#        next net-hilight STYLE — required because the viewer palette is layer
#        indices and layers 4/5 have no style row. Refusals + the style cursor
#        left alone + the ase::ui::dp_hilight wrapper's arms
#   P4   Direct Plot live: menu invoke -> mode, wire + vsource clicks queue
#        v(d)/i(v1), REAL <Key-Escape> ends -> ONE new stacked graph with
#        exactly those traces, auto graph untouched, outputs unchanged,
#        bindings restored verbatim; and (issue 0153) the wire click paints net
#        D in a plain layer color, the v(d) TRACE color equals that same color,
#        the highlight PERSISTS past ESC, and the two picks differ
#   P5   `~` strip button: not disabled; invoke raises the SAME viewer (no
#        new toplevel, no traces added)
#   P6   re-run -> always-replace: auto graph REBUILT (still 2 traces),
#        Direct-Plot graph untouched, raw re-read (points/sim_type), redraw
#        rc 0 over the stale `raw add` interval
#   P7   session close closes the viewer (D10) + registry cleaned
# Hermetic: the committed sky130_tests/test_nfet_final cell is CLONED into a
# scratch dir (the committed tree is never written); state shaping goes ONLY
# through the public ase::state_load/state_save schema on the CLONE.
#
# Runs via full_audit's DEFAULT arm (GUI legs self-SKIP without a usable
# DISPLAY; run legs additionally self-SKIP without ngspice). Standalone
# repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_plot.tcl
# (headless arm: add --nogui)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# wait for a real, mapped main canvas (WSLg can be slow to map the window);
# returns 0 when it never becomes usable -> the caller SKIPs, not FAILs
proc main_ready {} {
  catch {wm geometry . 1000x800}
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo ismapped .drw] && [winfo width .drw] > 300 && [winfo height .drw] > 300} {
      return 1
    }
  }
  return 0
}

# error-guarded raw query: `xschem raw ...` THROWS when nothing is loaded —
# a missing raw must FAIL its check, not abort the test
proc rawq {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

# traces count of graph $i in graph-list $gs, -1 when the graph is absent —
# a sabotaged/missing graph must FAIL its count check, not abort on
# `dict get {} traces`
proc gtr_n {gs i} {
  if {![string is integer -strict $i] || $i < 0 || $i >= [llength $gs]} {
    return -1
  }
  set G [lindex $gs $i]
  if {![dict exists $G traces]} { return -1 }
  return [llength [dict get $G traces]]
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch ase_plot]

# model resolution exactly as sky130A/cadence_style_rc sets it
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]

# --- fixture: CLONE the committed cell, scratch registry ---------------------
# sky130_tests points at the CLONE (all state writes land there); the device
# libraries point at the real committed trees.
set clonelib [file join $scratch sky130_tests]
file mkdir $clonelib
file copy [file join $repo sky130A xschem_libs sky130_tests test_nfet_final] \
  $clonelib
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests $clonelib"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]
set schpath [file normalize \
  [file join $clonelib test_nfet_final schematic test_nfet_final.sch]]
set clonestate [file join $clonelib test_nfet_final ngspice_state1 \
  test_nfet_final.state]

if {[catch {

# hermetic rundir: rewrite the CLONE's state file through the public schema
# BEFORE any session opens (fixture shaping, not a flow workaround)
set cst [ase::state_load $clonestate]
dict set cst rundir $rundir
ase::state_save $clonestate $cst

# --- PH1: plot_sim_type (pure) -----------------------------------------------
check "PH1 committed-shape op-only -> op" [ase::plot_sim_type $cst] op
set st_dc [dict replace $cst analyses \
  {{type op enabled 1} {type dc enabled 1} {type ac enabled 0} {type tran enabled 0}}]
check "PH1 op+dc enabled -> dc (last in emit order)" \
  [ase::plot_sim_type $st_dc] dc
set st_none [dict replace $cst analyses \
  {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}]
check "PH1 all disabled -> {}" [ase::plot_sim_type $st_none] {}
set st_actran [dict replace $cst analyses \
  {{type op enabled 0} {type dc enabled 0} {type ac enabled 1} {type tran enabled 1}}]
check "PH1 ac+tran enabled -> tran" [ase::plot_sim_type $st_actran] tran

# --- PH2: last_rawfile (headless session) ------------------------------------
check "PH2 unknown session key -> {}" [ase::last_rawfile no/such/session] {}
# a private rundir so this touched raw can never leak into the GUI legs
set ph2run [file normalize [file join $scratch ph2run]]
set ph2state [ase::state_load $clonestate]
dict set ph2state rundir $ph2run
set ph2file [file join $scratch ph2.state]
ase::state_save $ph2file $ph2state
set ph2key [ase::session_key phlib test_nfet_final phview]
ase::session_open $ph2key $ph2file
check "PH2 registered session, no raw artifact yet -> {}" \
  [ase::last_rawfile $ph2key] {}
set ph2raw [file join $ph2run test_nfet_final_ase.raw]
file mkdir $ph2run
close [open $ph2raw w]
check "PH2 raw artifact present -> the exact backend path" \
  [ase::last_rawfile $ph2key] $ph2raw
ase::session_close $ph2key

# --- PH3: plot_map_expr (pure) -----------------------------------------------
check "PH3 v(d) verbatim" [ase::ui::plot_map_expr {v(d)}] {v(d)}
check "PH3 -i(v1) -> RPN i(v1) -1 *" [ase::ui::plot_map_expr {-i(v1)}] {i(v1) -1 *}
check "PH3 ready RPN verbatim" [ase::ui::plot_map_expr {i(v1) -1 *}] {i(v1) -1 *}
check "PH3 whitespace trimmed" [ase::ui::plot_map_expr { v(d) }] {v(d)}
check "PH3 bare - untouched" [ase::ui::plot_map_expr {-}] -
# --- PH4: wviewer auto-graph model helpers (pure) ----------------------------
set phtok ph4/model/tok
check "PH4 auto_graph_index pre-create -> -1" [wviewer::auto_graph_index $phtok] -1
check "PH4 ensure_auto_graph on an empty layout -> 0" \
  [wviewer::ensure_auto_graph $phtok] 0
set gs [dict get [wviewer::layout_for $phtok] graphs]
check "PH4 layout gained exactly 1 graph" [llength $gs] 1
check "PH4 the graph carries the auto 1 marker" \
  [wviewer::dget [lindex $gs 0] auto 0] 1
check "PH4 second ensure_auto_graph -> 0 again" \
  [wviewer::ensure_auto_graph $phtok] 0
check "PH4 still 1 graph (find, not append)" \
  [llength [dict get [wviewer::layout_for $phtok] graphs]] 1
# seed traces on the auto graph + append a plain graph with its own trace
set G0 [lindex [dict get [wviewer::layout_for $phtok] graphs] 0]
set G0 [dict replace $G0 traces \
  {{expr v(a) name {} vec v(a) color 4} {expr v(b) name {} vec v(b) color 5}}]
set G1 [dict replace [wviewer::empty_graph] traces \
  {{expr v(c) name {} vec v(c) color 4}}]
wviewer::set_graphs $phtok [list $G0 $G1]
check "PH4 clear_graph_traces 0 -> 1" [wviewer::clear_graph_traces $phtok 0] 1
set gs [dict get [wviewer::layout_for $phtok] graphs]
check "PH4 graph count unchanged (clear, not remove)" [llength $gs] 2
check "PH4 graph 0 kept with traces emptied" [dict get [lindex $gs 0] traces] {}
check "PH4 graph 0 still auto-marked" [wviewer::dget [lindex $gs 0] auto 0] 1
check "PH4 graph 1 untouched" [dict get [lindex $gs 1] traces] \
  {{expr v(c) name {} vec v(c) color 4}}
check "PH4 auto_graph_index finds graph 0" [wviewer::auto_graph_index $phtok] 0
check "PH4 bad index -> 0, model intact" \
  [list [wviewer::clear_graph_traces $phtok 7] \
        [llength [dict get [wviewer::layout_for $phtok] graphs]]] {0 2}
wviewer::forget $phtok

# --- PH5 (pure): Ctrl-4 entry proc + status-line slot mapping ----------------
# The keyboard entry point ase::direct_plot_for_current and the bottom
# mode-prompt slot resolver ase::ui::sod_statusbar (.drw -> .statusbar.10,
# .x1.drw -> .x1.statusbar.10) are pure and load without a display.
check_true "PH5 ase::direct_plot_for_current defined" \
  [expr {[info commands ::ase::direct_plot_for_current] ne {}}]
check_true "PH5 ase::ui::sod_statusbar defined" \
  [expr {[info commands ::ase::ui::sod_statusbar] ne {}}]
check "PH5 statusbar slot main canvas"   [ase::ui::sod_statusbar .drw]     .statusbar.10
check "PH5 statusbar slot window .x1"     [ase::ui::sod_statusbar .x1.drw] .x1.statusbar.10
check "PH5 statusbar slot window .x2"     [ase::ui::sod_statusbar .x2.drw] .x2.statusbar.10

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  proc toplevel_count {} {
    set n 0
    foreach c [winfo children .] {
      if {[winfo class $c] eq {Toplevel}} { incr n }
    }
    return $n
  }

  # wait for the viewer canvas to be mapped (WSLg can be slow); 0 -> SKIP
  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  # One full Direct-Plot gesture from ASE window $awin on design canvas $cv:
  # arm the mode via the Results menu, click the D-net wire to queue a trace,
  # then end with a REAL <Key-Escape> (focus-gated retry — a lone synthetic
  # ESC is green-but-hollow, gesture-test-full-sequence lesson). Returns 1 once
  # the product's sod_end provably reverted the seized Key-Escape binding.
  proc dp_gesture {awin cv key} {
    set pre_esc [bind $cv <Key-Escape>]
    $awin.mb.results invoke {Direct Plot}
    update
    ase::ui::sod_click $key 550 -330
    update
    set ended 0
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[bind $cv <Key-Escape>] eq $pre_esc} { set ended 1; break }
      focus -force $cv
      update
      if {[focus -displayof $cv] eq $cv} {
        event generate $cv <Key-Escape>
        update
        if {[bind $cv <Key-Escape>] eq $pre_esc} { set ended 1; break }
      }
      after 50
    }
    return $ended
  }

  set key [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  set mainok [main_ready]
  set have_ng [expr {[auto_execok ngspice] ne {}}]

  if {!$mainok} {
    puts "SKIPPED: P1-P7 viewer-wiring legs (WSLg geometry: main window never became usable)"
  } else {

    # --- P1 fixture: op enabled ONLY, id row Plot-checked --------------------
    set cst [ase::state_load $clonestate]
    set an {}
    foreach a [dict get $cst analyses] {
      if {[dict get $a type] eq {op}} { set a [dict replace $a enabled 1] } \
      else { set a [dict replace $a enabled 0] }
      lappend an $a
    }
    dict set cst analyses $an
    set outs {}
    foreach o [dict get $cst outputs] {
      if {[ase::state_get $o name] eq {id}} { dict set o plot 1 }
      lappend outs $o
    }
    dict set cst outputs $outs
    ase::state_save $clonestate $cst

    check "P1 open_state -> 1" \
      [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
    update
    set top [ase::ui::window_for $key]
    check_true "P1 session window exists" \
      [expr {$top ne {} && [winfo exists $top]}]

    if {!$have_ng} {
      puts "SKIPPED: P1 op-only run leg (ngspice not found)"
    } else {
      $top.mb.sim invoke {Netlist and Run}
      set id1 [ase::session_getattr $key run_id]
      check_true "P1 run started (integer execute id)" \
        [string is integer -strict $id1]
      set ec1 [ase::wait $id1]
      update
      check "P1 exit 0" $ec1 0
      check "P1 status Ready" [$top.status.stat cget -text] {Status: Ready}
      check "P1 status light Green" [$top.status.stat cget -background] Green
      check "P1 op-only auto-plot opened NO viewer (notice arm)" \
        [wviewer::window_for $key] {}
    }

    # --- P2: op-only Direct Plot -> notice arm, D2 outputs untouched ---------
    set cv .drw
    check_true "P2 Results Direct Plot entry not disabled" \
      [expr {[$top.mb.results entrycget {Direct Plot} -state] ne {disabled}}]
    set outs_snap [ase::state_get [ase::session_state $key] outputs]
    set pre_press [bind $cv <ButtonPress-1>]
    set pre_rel   [bind $cv <ButtonRelease-1>]
    set pre_esc   [bind $cv <Key-Escape>]
    $top.mb.results invoke {Direct Plot}
    update
    check "P2 design is the current schematic" \
      [file normalize [xschem get schname]] $schpath
    check "P2 mode canvas is the main canvas" [xschem get current_win_path] .drw
    check_true "P2 mode armed (ButtonPress-1 seized)" \
      [expr {[bind $cv <ButtonPress-1>] ne {} && \
             [bind $cv <ButtonPress-1>] ne $pre_press}]
    ase::ui::sod_click $key 550 -330                   ;# the D-net wire
    update
    ase::ui::sod_end $key
    update
    check "P2 op-only Direct Plot opened NO viewer (notice arm)" \
      [wviewer::window_for $key] {}
    check "P2 ButtonPress-1 restored verbatim" [bind $cv <ButtonPress-1>] $pre_press
    check "P2 ButtonRelease-1 restored" [bind $cv <ButtonRelease-1>] $pre_rel
    check "P2 Key-Escape restored" [bind $cv <Key-Escape>] $pre_esc
    check "P2 outputs unchanged (D2: plot mode writes no outputs)" \
      [ase::state_get [ase::session_state $key] outputs] $outs_snap
    ase::ui::close $key
    update
    check_true "P2 session closed for the dc reshape" \
      [expr {![winfo exists $top]}]

    # --- P3 fixture: dc sweep + two Plot-checked rows ------------------------
    set cst [ase::state_load $clonestate]
    set an {}
    foreach a [dict get $cst analyses] {
      if {[dict get $a type] eq {dc}} {
        set a [dict create type dc enabled 1 source V2 start 0 stop 1.8 step 0.01]
      } else {
        set a [dict replace $a enabled 0]
      }
      lappend an $a
    }
    dict set cst analyses $an
    dict set cst outputs {{name id expr -i(v1) save 1 plot 1} \
                          {name {} expr v(d) plot 1 save 1}}
    ase::state_save $clonestate $cst
    check "P3 reopen state -> 1" \
      [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
    update
    set top [ase::ui::window_for $key]
    check_true "P3 session window exists" \
      [expr {$top ne {} && [winfo exists $top]}]

    if {!$have_ng} {
      puts "SKIPPED: P3-P6 dc auto-plot/Direct-Plot/rerun legs (ngspice not found)"
      # the ~ button liveness is still assertable without a run
      check_true "P5 ~ strip button not disabled" \
        [expr {[$top.strip.plot cget -state] ne {disabled}}]
    } else {

      # --- P3: run -> auto-plot opens the viewer, raw attached ---------------
      $top.mb.sim invoke {Netlist and Run}
      set id3 [ase::session_getattr $key run_id]
      check_true "P3 run started (integer execute id)" \
        [string is integer -strict $id3]
      set ec3 [ase::wait $id3]
      update
      check "P3 exit 0" $ec3 0
      set vtop [wviewer::window_for $key]
      check_true "P3 auto-plot opened the viewer" \
        [expr {$vtop ne {} && [winfo exists $vtop]}]
      set vready 0
      if {$vtop ne {}} { set vready [viewer_ready $vtop] }
      check "P3 viewer window mapped" $vready 1
      set vdrw $vtop.drw
      xschem new_schematic switch $vdrw
      check_true "P3 raw loaded index >= 0 (INDEX semantics)" \
        [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
               [rawq {xschem raw loaded}] >= 0}]
      check "P3 raw sim_type dc" [rawq {xschem raw sim_type}] dc
      check "P3 raw points 181 (dc 0..1.8 step 0.01)" \
        [rawq {xschem raw points}] 181
      check "P3 auto graph is graph 0" [wviewer::auto_graph_index $key] 0
      set gs3 [dict get [wviewer::layout_for $key] graphs]
      check "P3 auto graph carries 2 traces" [gtr_n $gs3 0] 2
      set node3 [rawq {xschem getprop rect 2 0 node}]
      check_true "P3 rect 0 node attr carries v(d)" \
        [expr {[string first {v(d)} $node3] >= 0}]
      check_true "P3 rect 0 node attr carries id" \
        [expr {[string first id $node3] >= 0}]
      check_true "P3 raw vector id materialized (D6 RPN via raw add)" \
        [expr {[string is integer -strict [rawq {xschem raw index id}]] &&
               [rawq {xschem raw index id}] >= 0}]
      check "P3 redraw rc 0" [catch {xschem redraw}] 0

      # --- PL: `xschem hilight_netname/-instname -layer N` (issue 0153) ------
      # The picker needs a net highlighted in the PLAIN color of a given drawing
      # LAYER, because the viewer's trace palette is layer indices and two of
      # them (4, 5) have no net-hilight-STYLE entry at all (default styles cover
      # layers >= 7). The engine already had the mechanism — a NEGATIVE hilight
      # value means "layer color, no style" — it just was not reachable from Tcl.
      # `list_hilights all` prints `path token value`, so the negative value is
      # directly witnessable.
      proc hl_val {net} {
        set v {}
        foreach ln [split [xschem list_hilights all] "\n"] {
          set f [regexp -all -inline {\S+} $ln]
          if {[llength $f] >= 3 && [lindex $f 1] eq $net} { set v [lindex $f 2] }
        }
        return $v
      }
      xschem new_schematic switch $cv
      catch {xschem unhilight_all}
      check "PL -layer 4 highlights the net" \
        [catch {xschem hilight_netname -layer 4 D}] 0
      check "PL -layer 4 stores the NEGATIVE layer value (plain layer color)" \
        [hl_val D] -4
      catch {xschem unhilight_all}
      check "PL -layer 5 (no style-table entry exists for layer 5) works too" \
        [catch {xschem hilight_netname -layer 5 D}] 0
      check "PL ... and stores -5" [hl_val D] -5
      catch {xschem unhilight_all}
      check "PL -style 2 still stores a POSITIVE style index (unchanged)" \
        [expr {[catch {xschem hilight_netname -style 2 D}] ? {ERR} : [hl_val D]}] 2
      catch {xschem unhilight_all}
      check_true "PL -layer 0 is refused (layer 0 is the background; -0 == style 0)" \
        [catch {xschem hilight_netname -layer 0 D}]
      check_true "PL -layer out of range is refused" \
        [catch {xschem hilight_netname -layer 9999 D}]
      check_true "PL -style with a negative index is still refused" \
        [catch {xschem hilight_netname -style -1 D}]
      # -layer must not touch the user's style cursor (an explicit color is not
      # a use of the cycle). Set it, highlight with -layer, then step it: the
      # step must land where it would have without the highlight.
      catch {xschem unhilight_all}
      xschem set hilight_color 3
      catch {xschem hilight_netname -layer 7 D}
      check "PL -layer left the style cursor alone (3 -> incr -> 4)" \
        [xschem incr_hilight_color] 4
      catch {xschem unhilight_all}
      # the instance arm (current probes are picked on a source BODY, which has
      # no wire to color). Instance highlights live in a different hash than
      # list_hilights walks, so this is a no-throw + accepted witness only —
      # stated, not hidden.
      check "PL -instname -layer accepted" \
        [catch {xschem hilight_instname -layer 4 V1}] 0
      check_true "PL -instname -layer out of range refused" \
        [catch {xschem hilight_instname -layer 0 V1}]
      check "PL dp_hilight voltage arm reports success" \
        [ase::ui::dp_hilight voltage D 4] 1
      check "PL dp_hilight current arm reports success" \
        [ase::ui::dp_hilight current V1 4] 1
      check "PL dp_hilight refuses a bad color" [ase::ui::dp_hilight voltage D 0] 0
      check "PL dp_hilight refuses an empty color" [ase::ui::dp_hilight voltage D {}] 0
      check "PL dp_hilight refuses an empty target" [ase::ui::dp_hilight voltage {} 4] 0
      catch {xschem unhilight_all}

      # --- P4: Direct Plot -> one new stacked graph with the clicked traces --
      set outs_snap [ase::state_get [ase::session_state $key] outputs]
      set g_before [llength [dict get [wviewer::layout_for $key] graphs]]
      set pre_press [bind $cv <ButtonPress-1>]
      set pre_rel   [bind $cv <ButtonRelease-1>]
      set pre_esc   [bind $cv <Key-Escape>]
      $top.mb.results invoke {Direct Plot}
      update
      check_true "P4 mode armed (ButtonPress-1 seized)" \
        [expr {[bind $cv <ButtonPress-1>] ne $pre_press}]
      ase::ui::sod_click $key 550 -330                 ;# wire -> v(d)
      update
      # issue 0153: the click must have painted net d in the color its trace will
      # get -- a NEGATIVE hilight value (plain layer color). Captured BEFORE ESC
      # so the post-plot comparison is against what the user actually saw.
      xschem new_schematic switch $cv
      set p4hl [hl_val D]
      check_true "P4 the wire click highlighted net D" [expr {$p4hl ne {}}]
      check_true "P4 ... in a plain LAYER color (negative hilight value)" \
        [expr {[string is integer -strict $p4hl] && $p4hl < 0}]
      ase::ui::sod_click $key 600 -300                 ;# vsource -> i(v1)
      update
      # REAL <Key-Escape> ends the mode (gesture-test-full-sequence lesson):
      # generated KeyPress goes to the display's FOCUS window and WSLg
      # confirms focus asynchronously — gate each generate on Tk reporting
      # the canvas as focus owner and retry until the seized Key-Escape
      # binding is provably reverted (restored by the product's sod_end).
      set ended 0
      for {set i 0} {$i < 200} {incr i} {
        update
        if {[bind $cv <Key-Escape>] eq $pre_esc} { set ended 1; break }
        focus -force $cv
        update
        if {[focus -displayof $cv] eq $cv} {
          event generate $cv <Key-Escape>
          update
          if {[bind $cv <Key-Escape>] eq $pre_esc} { set ended 1; break }
        }
        after 50
      }
      check "P4 REAL ESC ended the mode" $ended 1
      check "P4 ButtonPress-1 restored verbatim" \
        [bind $cv <ButtonPress-1>] $pre_press
      check "P4 ButtonRelease-1 restored" [bind $cv <ButtonRelease-1>] $pre_rel
      check "P4 Key-Escape restored" [bind $cv <Key-Escape>] $pre_esc
      set gs4 [dict get [wviewer::layout_for $key] graphs]
      set n4 [llength $gs4]
      check "P4 exactly ONE new graph appended" $n4 [expr {$g_before + 1}]
      set dpgi [expr {$n4 - 1}]
      set dg [lindex $gs4 $dpgi]
      check "P4 new graph is NOT the auto graph" [wviewer::dget $dg auto 0] 0
      set dtr {}
      catch {set dtr [dict get $dg traces]}
      set dvecs {}
      foreach tr $dtr { lappend dvecs [wviewer::dget $tr vec {}] }
      check "P4 new graph traces are exactly v(d) + i(v1)" \
        [lsort $dvecs] [lsort {v(d) i(v1)}]
      # issue 0153 THE teeth: the trace for v(d) must carry EXACTLY the color the
      # wire was painted with, and the wire must still be painted after ESC
      # (highlights persist by decision, so the color map stays readable).
      set p4tc {}
      foreach tr $dtr {
        if {[wviewer::dget $tr vec {}] eq {v(d)}} { set p4tc [wviewer::dget $tr color {}] }
      }
      # $p4hl comes from the wire click above, which is the leg that flakes under
      # WSLg (the click occasionally lands on nothing and hl_val returns {}).
      # `expr {-$p4hl}` on {} THROWS, and the throw escapes to the file-level
      # catch — so one flaked click used to abort the remaining ~56 checks and
      # the suite reported "4 FAILED (85 passed)" instead of "1 FAILED (144)".
      # Fail this leg locally instead; the earlier legs already reported the
      # real problem.
      if {[string is integer -strict $p4hl]} {
        check "P4 v(d) trace color == the color painted on the wire" $p4tc [expr {-$p4hl}]
      } else {
        check "P4 v(d) trace color == the color painted on the wire" \
          "no wire highlight to compare against (p4hl={$p4hl})" {}
      }
      xschem new_schematic switch $cv
      check "P4 the wire highlight PERSISTS past ESC" [hl_val D] $p4hl
      # the two picks must not share a color (they are two different signals)
      set p4cols {}
      foreach tr $dtr { lappend p4cols [wviewer::dget $tr color {}] }
      check "P4 the two picked traces have different colors" \
        [llength [lsort -unique $p4cols]] 2
      xschem new_schematic switch $vdrw
      set agi4 [wviewer::auto_graph_index $key]
      check "P4 auto graph untouched (still 2 traces)" [gtr_n $gs4 $agi4] 2
      check "P4 outputs unchanged (D2: traces queued, no output rows)" \
        [ase::state_get [ase::session_state $key] outputs] $outs_snap
      # D9 stale-but-clean: the dp_finish re-attach (raw clear + re-read)
      # killed the runtime `raw add` vector id — P6's rebuild must bring it
      # back (the honest REBUILT witness)
      xschem new_schematic switch $vdrw
      check "P4 re-attach cleared the raw-add vector id (D9)" \
        [rawq {xschem raw index id}] -1

      # --- P5: `~` raises the SAME viewer, adds nothing ----------------------
      check_true "P5 ~ strip button not disabled" \
        [expr {[$top.strip.plot cget -state] ne {disabled}}]
      set tls5 [toplevel_count]
      set gc5 [llength [dict get [wviewer::layout_for $key] graphs]]
      $top.strip.plot invoke
      update
      check "P5 same viewer toplevel" [wviewer::window_for $key] $vtop
      check "P5 no new toplevel" [toplevel_count] $tls5
      check "P5 model graph count unchanged (no traces added)" \
        [llength [dict get [wviewer::layout_for $key] graphs]] $gc5

      # --- P6: re-run -> always-replace auto graph, Direct-Plot graph intact -
      # make the design current DETERMINISTICALLY first: P5's viewer raise
      # leaves WSLg focus events in flight, and do_run's design-current guard
      # can race them during its own `update` (the guard then honestly
      # refuses with "open its design window first"). A user would click the
      # design window before re-running; replicate that click's ctx switch.
      xschem new_schematic switch .drw
      update
      $top.mb.sim invoke {Netlist and Run}
      set id6 [ase::session_getattr $key run_id]
      check_true "P6 re-run started" [string is integer -strict $id6]
      set ec6 [ase::wait $id6]
      update
      check "P6 exit 0" $ec6 0
      set gs6 [dict get [wviewer::layout_for $key] graphs]
      check "P6 model graphs STILL 2 (replace, not append)" [llength $gs6] 2
      set agi6 [wviewer::auto_graph_index $key]
      check "P6 auto graph still present" $agi6 0
      check "P6 auto graph REBUILT with exactly 2 traces" [gtr_n $gs6 $agi6] 2
      set dtr6 {}
      catch {set dtr6 [dict get [lindex $gs6 $dpgi] traces]}
      set dvecs6 {}
      foreach tr $dtr6 { lappend dvecs6 [wviewer::dget $tr vec {}] }
      check "P6 Direct-Plot graph untouched (v(d) + i(v1))" \
        [lsort $dvecs6] [lsort {v(d) i(v1)}]
      xschem new_schematic switch $vdrw
      check "P6 raw re-read: points 181" [rawq {xschem raw points}] 181
      check "P6 raw re-read: sim_type dc" [rawq {xschem raw sim_type}] dc
      check_true "P6 raw vector id re-materialized (auto graph truly rebuilt)" \
        [expr {[string is integer -strict [rawq {xschem raw index id}]] &&
               [rawq {xschem raw index id}] >= 0}]
      check "P6 redraw rc 0 (stale add-vectors draw clean)" \
        [catch {xschem redraw}] 0

      # --- P6b (issue 0173): a viewer READ driven from the DESIGN window
      #     BORROWS the xschem context and gives it back. This is the suite that
      #     has real raw data attached, so readout_refresh's per-context reads
      #     (`xschem get cursorN_x`, interp_value's `xschem raw` lookups) actually
      #     resolve — which makes this the leg that proves the borrow HANDED THE
      #     CONTEXT OVER, not merely that it put it back afterwards. Before the
      #     fix the bare `new_schematic switch` here left the design window's
      #     clicks going to the viewer and rewrote the viewer's title.
      xschem new_schematic switch $vdrw
      xschem set cursor1_x 0.9
      set ::wviewer::cva($key) 1                 ;# cursor A on -> the bar has content
      set t73 [wviewer::title_for $key]
      wm title $vtop $t73                        ;# known-good starting point
      xschem new_schematic switch .drw
      check "P6b the design owns the context before the read" \
        [xschem get current_win_path] .drw
      # no `update` past here: the viewer's FocusIn retitle and the editor's
      # FocusIn ctx switch would both repair the very damage being asserted about
      wviewer::readout_refresh $key
      check "P6b a viewer readout from the design window RESTORES the context" \
        [xschem get current_win_path] .drw
      check "P6b ... and leaves the viewer's own title intact" [wm title $vtop] $t73
      check_true "P6b ... having really read in the viewer ctx (readout filled)" \
        [regexp {^A: x=} [$vtop.wvreadout.a cget -text]]
      set ::wviewer::cva($key) 0
    }

    # --- P7: session close closes the viewer (D10) ---------------------------
    set vtop7 [wviewer::window_for $key]
    ase::ui::close $key
    update
    check_true "P7 session toplevel gone" [expr {![winfo exists $top]}]
    if {$vtop7 ne {}} {
      check_true "P7 viewer toplevel destroyed with the session" \
        [expr {![winfo exists $vtop7]}]
    } else {
      puts "SKIPPED: P7 viewer-destroy assert (no viewer was open — run legs skipped)"
    }
    check "P7 viewer registry cleaned" [wviewer::window_for $key] {}

    # --- P8: dp-open-race (item 17) — the FIRST Direct Plot of a FRESH session
    # opens EXACTLY ONE viewer that STAYS visible. Placed AFTER P7 so the
    # session's viewer registry is clean and wviewer::open takes its FRESH arm
    # (the arm that pre-fix never raised/focused the new window -> under
    # interactive WSLg it mapped BEHIND the just-raised design window and never
    # came forward: "launch then VANISH", only the 2nd Direct Plot's RE-OPEN
    # arm brought it up — issue 0054 stacking). Gated on mainok ONLY (needs NO
    # ngspice: a dc-enabled analysis makes dp_finish open the viewer regardless
    # of a raw; all outputs plot 0 + NO run keeps Direct Plot the FIRST viewer
    # open). The user's VANISH symptom is an interactive-WSLg stacking race a
    # scripted driver cannot faithfully reproduce; this phase asserts the
    # open-race INVARIANT (exactly one live viewer that STAYS; the 2nd raises
    # the SAME one) and the top-of-stack end-state the raise-fix guarantees.
    set cst [ase::state_load $clonestate]
    set an {}
    foreach a [dict get $cst analyses] {
      if {[dict get $a type] eq {dc}} {
        set a [dict create type dc enabled 1 source V2 start 0 stop 1.8 step 0.01]
      } else {
        set a [dict replace $a enabled 0]
      }
      lappend an $a
    }
    dict set cst analyses $an
    set outs {}
    foreach o [dict get $cst outputs] { dict set o plot 0; lappend outs $o }
    dict set cst outputs $outs
    ase::state_save $clonestate $cst

    check "P8 reopen a FRESH session -> 1" \
      [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
    update
    set top [ase::ui::window_for $key]
    check_true "P8 session window exists" \
      [expr {$top ne {} && [winfo exists $top]}]
    check "P8 fresh session has NO viewer yet" [wviewer::window_for $key] {}
    set N0 [toplevel_count]
    set cv .drw

    # item-17 witness (DETERMINISTIC; does NOT depend on WSLg stacking, and is
    # BYPASS-PROOF). Two earlier attempts were unsound: (a) a `wm stackorder`
    # snapshot was HOLLOW (a freshly-created viewer is naturally last in
    # stackorder in a scripted driver, so it passed even with the fix reverted)
    # and ~30% FLAKY under WSLg (the ASE/main window sometimes ended up on top);
    # (b) a `rename`+wrapper shim on raise_activate_toplevel had real teeth but
    # was itself ~5% FLAKY -- wviewer::open is byte-compiled and already ran in
    # P1-P7, so its "raise_activate_toplevel" literal caches a command
    # resolution that, after the rename, intermittently still points at the
    # renamed real proc and BYPASSES the wrapper (the fresh-arm raise fires but
    # is never logged). An EXECUTION TRACE attaches to the ONE command object
    # itself and fires on every invocation regardless of how the caller resolved
    # the name (verified: fires through a warmed byte-compiled caller) -- no
    # bypass is possible. The production fix is the FRESH arm of wviewer::open
    # calling raise_activate_toplevel on the NEW viewer top; nothing else raises
    # that toplevel during a first Direct Plot (select_on_design raises the
    # DESIGN window `.`; plot-mode sod_end SKIPS the ASE-window raise). Revert
    # the fix -> the viewer top never enters this log -> the witness below FAILS.
    # The trace + spy proc are removed at the end of P8.
    set ::dp_raise_log {}
    proc ::dp_raise_spy {cmd op} { lappend ::dp_raise_log [lindex $cmd 1] }
    catch {trace remove execution raise_activate_toplevel enter ::dp_raise_spy}
    trace add execution raise_activate_toplevel enter ::dp_raise_spy

    # first Direct Plot (whole Tk gesture: menu -> click -> REAL ESC); make the
    # design current first (deterministic, P6 precedent)
    xschem new_schematic switch .drw
    update
    check "P8 first Direct Plot REAL ESC ended the mode" [dp_gesture $top $cv $key] 1
    # settle: let dp_finish's wviewer::open + the fresh-arm raise (withdraw/
    # deiconify remap) run to completion
    for {set i 0} {$i < 20} {incr i} { update; after 25 }
    set vtop [wviewer::window_for $key]
    check_true "P8 first Direct Plot opened a viewer" \
      [expr {$vtop ne {} && [winfo exists $vtop]}]
    set vready 0
    if {$vtop ne {}} { set vready [viewer_ready $vtop] }
    check "P8 first viewer mapped" $vready 1
    check "P8 exactly ONE new toplevel" [toplevel_count] [expr {$N0 + 1}]

    # STAYS: poll across a settle window; a transient unmap during a withdraw/
    # deiconify re-map is tolerated (viewer_ready polls until re-mapped), a
    # persistent gone/unmapped IS the user's VANISH bug -> FAIL
    for {set i 0} {$i < 40} {incr i} { update; after 25 }
    set se 0; set sm 0
    if {$vtop ne {} && [winfo exists $vtop]} {
      set se 1
      set sm [viewer_ready $vtop]
    }
    check "P8 first viewer STAYS" [expr {$se && $sm ? 1 : 0}] 1
    # NOTE: the "fresh open RAISED the viewer" teeth (item-17) + the re-open
    # raise teeth (item-13) are asserted DETERMINISTICALLY below via a direct
    # wviewer::open call, NOT here on the gesture path. Reason: raising a
    # freshly-mapped toplevel through the full WSLg Direct-Plot gesture
    # (menu->click->ESC->dp_finish->wviewer::open, with select_on_design having
    # just raised the design window) is timing-flaky (~1/10) -- the raise fires
    # but the execution trace intermittently observes it out of the settle
    # window. A direct wviewer::open call exercises the SAME production raise
    # (wave_viewer.tcl fresh + re-open arms) with no gesture/design-raise race,
    # so the raise witness is deterministic. The gesture legs above still prove
    # the end-to-end no-vanish behavior (opened + mapped + STAYS + one toplevel).

    # second Direct Plot: the RE-OPEN arm must raise the SAME viewer (item 13),
    # never a duplicate. Make the design current first (the first plot's viewer
    # raise leaves WSLg focus events in flight, P6 precedent).
    set vtop1 $vtop
    set ::dp_raise_log {}
    xschem new_schematic switch .drw
    update
    check "P8 second Direct Plot REAL ESC ended the mode" [dp_gesture $top $cv $key] 1
    for {set i 0} {$i < 20} {incr i} { update; after 25 }
    check_true "P8 second Direct Plot raises the SAME viewer" \
      [expr {$vtop1 ne {} && [wviewer::window_for $key] eq $vtop1}]
    check "P8 second Direct Plot added no new toplevel" \
      [toplevel_count] [expr {$N0 + 1}]
    # the re-open arm's raise (withdraw+deiconify) can be mid-flight -> poll for
    # the re-map (transient unmap tolerated) rather than a bare snapshot
    set se2 0; set sm2 0
    if {$vtop1 ne {} && [winfo exists $vtop1]} {
      set se2 1
      set sm2 [viewer_ready $vtop1]
    }
    check "P8 second viewer still exists+mapped" [expr {$se2 && $sm2 ? 1 : 0}] 1

    # --- DETERMINISTIC raise teeth (gesture-free) ----------------------------
    # The real teeth for the item-17 fix: both arms of wviewer::open end by
    # calling raise_activate_toplevel on the viewer top. Exercise them by
    # calling wviewer::open DIRECTLY (no Direct-Plot gesture, no design-window
    # raise in flight) so the execution-trace observation is deterministic.
    # RE-OPEN arm: the viewer is currently open -> a direct open re-raises it.
    set ::dp_raise_log {}
    wviewer::open $key
    update
    check_true "P8 re-open arm raises the viewer (item-13, deterministic)" \
      [expr {[lsearch -exact $::dp_raise_log $vtop1] >= 0}]
    # FRESH arm: drop the viewer (registry clean, SESSION still alive), then a
    # direct open rebuilds it via the fresh arm and must raise the new top.
    # Reverting the item-17 fix (removing raise_activate_toplevel from the fresh
    # arm) leaves this log empty -> FAIL. This is the item-17 witness.
    wviewer::close $key
    update
    check "P8 viewer dropped before fresh-arm probe" [wviewer::window_for $key] {}
    set ::dp_raise_log {}
    wviewer::open $key
    update
    set vfresh [wviewer::window_for $key]
    check_true "P8 fresh arm opens a viewer" \
      [expr {$vfresh ne {} && [winfo exists $vfresh]}]
    check_true "P8 fresh arm raises the new viewer (item-17, deterministic)" \
      [expr {$vfresh ne {} && [lsearch -exact $::dp_raise_log $vfresh] >= 0}]

    # remove the item-17 raise witness (execution trace + spy proc)
    catch {trace remove execution raise_activate_toplevel enter ::dp_raise_spy}
    catch {rename ::dp_raise_spy {}}

    # cleanup: close the session (closes its viewer, D10) + registry clean
    ase::ui::close $key
    update
    check "P8 session closed, viewer registry cleaned" [wviewer::window_for $key] {}

    # --- P9: Ctrl-4 entry point (ase::direct_plot_for_current) + bottom
    #     status-line prompt. Fresh session, make the design the CURRENT window
    #     (Ctrl-4 fires from it), then drive the same path the bind fires. ------
    check "P9 reopen state -> 1" \
      [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
    update
    set top9 [ase::ui::window_for $key]
    check_true "P9 session window exists" \
      [expr {$top9 ne {} && [winfo exists $top9]}]
    ase::ui::design_window $key                        ;# make the design current
    update
    check "P9 design is the current schematic" \
      [file normalize [xschem get schname]] $schpath
    set cv9  [xschem get current_win_path]
    set sb9  [ase::ui::sod_statusbar $cv9]
    set pre_esc9 [bind $cv9 <Key-Escape>]
    set pre_mot9 [bind $cv9 <Motion>]
    set rk [ase::direct_plot_for_current]              ;# the Ctrl-4 command
    # issue 0173 no-regression, asserted BEFORE the `update` below: Ctrl-4 arms a
    # pick mode ON THE DESIGN and must leave the context there. It is the sibling
    # chord of Ctrl-Shift-4, which did leak the context into the viewer, and the
    # 0173 fix touches procs (in_ctx, readout_refresh) that this path reaches.
    check "P9 Ctrl-4 left the context on the DESIGN window" \
      [xschem get current_win_path] $cv9
    update
    check "P9 entry proc returned the bound session key" $rk $key
    check_true "P9 mode armed (ButtonPress-1 seized, sod active)" \
      [expr {[bind $cv9 <ButtonPress-1>] ne {} \
             && [info exists ::ase::ui::sod(active)] \
             && $::ase::ui::sod(active) eq $key}]
    # design_window's raise focuses the TOPLEVEL; select_on_design must refocus
    # the CANVAS or the seized <Key-Escape> never fires (mode stuck on real ESC).
    # Without the `focus $cv` fix this is the toplevel, not the canvas -> FAIL.
    check "P9 canvas holds keyboard focus (real ESC will fire)" \
      [focus -lastfor $cv9] $cv9
    # the prompt is kept up by sod_prompt_pump (re-asserts within ~80ms after the
    # C engine blanks .statusbar.10), so poll rather than sample synchronously
    proc wait_prompt {w txt} {
      for {set i 0} {$i < 80} {incr i} {
        update
        if {[$w cget -text] eq $txt} { return 1 }
        after 20
      }
      return 0
    }
    check_true "P9 status line shows the prompt" \
      [wait_prompt $sb9 {select signals to plot}]
    check "P9 status line prompt is active (green)" [$sb9 cget -state] active
    # regression guard: a Motion routes through C update_statusbar() which BLANKS
    # .statusbar.10; the pump must bring the prompt back (delete sod_prompt_pump
    # in select_on_design and this leg times out -> FAIL).
    event generate $cv9 <Motion> -x 40 -y 40
    check_true "P9 prompt returns after a Motion blank (pump re-asserts)" \
      [wait_prompt $sb9 {select signals to plot}]
    ase::ui::sod_end $key                              ;# ESC path
    update
    check "P9 prompt cleared on end" [string trim [$sb9 cget -text]] {}
    check "P9 prompt state restored to normal" [$sb9 cget -state] normal
    check "P9 Motion binding restored verbatim" [bind $cv9 <Motion>] $pre_mot9
    check "P9 Key-Escape restored verbatim" [bind $cv9 <Key-Escape>] $pre_esc9

    # --- P10: no ASE session bound to the current design -> honest no-op
    #     (returns {}, does NOT arm the mode, leaves canvas bindings alone). ----
    ase::ui::close $key
    update
    check "P10 session closed" [ase::ui::window_for $key] {}
    set cv10 [xschem get current_win_path]             ;# design still current
    set pre_press10 [bind $cv10 <ButtonPress-1>]
    set r10 [ase::direct_plot_for_current]
    update
    check "P10 no-session entry returns {}" $r10 {}
    check "P10 no-session did NOT arm the mode" \
      [expr {[info exists ::ase::ui::sod(active)] ? $::ase::ui::sod(active) : {}}] {}
    check "P10 ButtonPress-1 untouched (no mode)" [bind $cv10 <ButtonPress-1>] $pre_press10
  }

} else {
  puts "gui legs skipped (no DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
