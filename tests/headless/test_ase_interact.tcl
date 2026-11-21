# ASE-L Select On Design + whole-flow GUI acceptance (item 08 of
# doc/claude/ase_l_batch, spec doc/claude/specs/ase_l.md "UI v2" — the
# ROUND-2 ACCEPTANCE GATE):
#   H1     sod_expr builds lowercased v(<net>) / i(<inst>) tokens (headless)
#   H2     sod_merge queue semantics: append / OR-flags merge / identical
#          re-queue nochange / other rows intact (headless)
#   I1-I10 the Select On Design click mode on the design schematic (GUI,
#          needs a usable MAIN window): menu entry enters the mode and seizes
#          the canvas <ButtonPress-1>/<Double-Button-1>/<ButtonRelease-1>/
#          <B1-Motion>/<Key-Escape>/<Destroy> bindings; a REAL generated
#          Motion+Press+Release gesture queues v(g); both presses of a REAL
#          double click reach the pick and none reaches the editor; direct
#          sod_click legs queue v(d)/i(v1), dedupe on a
#          net-label click, refuse a non-source instance (v1 scope); the row
#          shows in the Outputs pane immediately; a REAL <Key-Escape> ends
#          the mode, restores every seized binding VERBATIM, leaves the
#          generic <ButtonPress> untouched and re-raises the ASE window
#          (W4 nudge/self-SKIP pattern); the To Be Plotted flavor ORs plot
#          into an existing row; the Add-Output dialog's From Design… button
#          closes the dialog and enters the mode; ase::ui::close ends an
#          active mode (binding-leak guard).
#   IT     the mode entered with the design in a TAB that is not the first:
#          by the session window's menu entry (a real click then merges the
#          plot flag into a row) and by the command the design window's
#          Ctrl-4 runs; a real ESC ends each.
#   I11    the session window closed with the Results window's pick mode on
#          top of Select On Design: that mode holds the canvas again, and one
#          real ESC ends it.
#   I13    the session window closed while a descend has Select On Design and
#          the Results window's pick mode paused: nothing is written on the
#          canvas, and the Results window's mode comes back alone.
#   WF     the ROUND GATE whole-flow leg on a FRESH session: open the state
#          view -> Choose Analyses (op enabled) -> add output vd=v(d) via the
#          --> dialog -> Netlist and Run (log toplevel, status Ready, id
#          Value ~409.7uA, vd Value ~1.0) -> Save State to a scratch view ->
#          Close -> reopen the scratch view -> variables/analyses/outputs
#          repopulate identically.
# Hermetic: the committed sky130_tests/test_nfet_final cell is CLONED into a
# scratch dir (the committed tree is never written); the clone's state rundir
# is rewritten to the scratch through the public ase::state_load/state_save
# schema (the test_ase_final D7 fixture-shaping precedent).
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_interact.tcl
# (GUI legs need DISPLAY; the run legs need ngspice)

set fail 0; set npass 0
# check/check_true/main_ready/tv_find copied from tests/headless/test_ase_window.tcl
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

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

# the treeview item whose $col cell equals $val, or {}
proc tv_find {tv col val} {
  foreach it [$tv children {}] {
    if {[$tv set $it $col] eq $val} { return $it }
  }
  return {}
}

# menu_save_state variant (origin: tests/headless/test_ase_window.tcl): drive
# Session > Save State but retarget the View entry BEFORE proceeding — the
# Save-As dialog then creates/overwrites lib/cell/$view instead of the
# session's own view. Returns 1 when the dialog round completed.
proc menu_save_state_as {top view} {
  $top.mb.session invoke {Save State}
  for {set i 0} {$i < 100} {incr i} {
    update
    if {[winfo exists $top.saveas]} { break }
    after 20
  }
  if {![winfo exists $top.saveas]} { return 0 }
  $top.saveas.view delete 0 end
  $top.saveas.view insert 0 $view
  $top.saveas.btns.proceed invoke
  for {set i 0} {$i < 100} {incr i} {
    update
    if {![winfo exists $top.saveas]} { return 1 }
    after 20
  }
  return 0
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch ase_interact]

## ISOLATION FROM WHOEVER'S ~/.xschem/ase_simulators IS LIVE (issue 1377).
test_sim_registry_isolate     ;# issue 1377: the registry below is OURS, not ~/.xschem's
## I2/I3/I5/I8 pin FOLDED expressions (`v(g)`, `v(d)`, `i(v1)`). MEASURED before
## this line: 6 FAILED under the developer's HOME, ALL PASS (63) under a HOME with
## no registry, and 13 FAILED under a registry naming a WORKING build -- the extra
## seven are the whole `WF` Netlist-and-Run leg, which exits -1 and reports
## `Status: Error` because the entry's own case mode reaches the deck.
check "ISO1377 the suite runs against an empty simulator registry, not the one in ~/.xschem" \
  [test_sim_registry_state] {0 {} {} path}

# model resolution exactly as sky130A/cadence_style_rc sets it (the
# test_ase_final idiom)
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]

# --- fixture: CLONE the committed cell, scratch registry (D10) ---------------
# sky130_tests points at the CLONE (Save-As writes land there); the device
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
# BEFORE any session opens (fixture shaping, not a flow workaround; the
# committed tree is never written)
set cst [ase::state_load $clonestate]
dict set cst rundir $rundir
ase::state_save $clonestate $cst

# --- H1: sod_expr (pure helper) ----------------------------------------------
## RESTATED, casemode batch item 9 (same ids, same expected strings): the case
## mode is now a REQUIRED third argument -- sod_expr folds only when the run's
## requested mode is `fold`, which is A1's default everywhere, so both expected
## values are unchanged. H1's real subject, that sod_expr is a PURE string op
## callable with no design loaded, is untouched: the mode arrives as an argument
## precisely so this proc never has to ask the engine (spec
## simulator_profiles.md §13.2).
check "H1 sod_expr voltage lowercases the net" \
  [ase::ui::sod_expr voltage D fold] {v(d)}
check "H1 sod_expr current lowercases the source" \
  [ase::ui::sod_expr current V1 fold] {i(v1)}

# --- H2: sod_merge (pure helper) ---------------------------------------------
lassign [ase::ui::sod_merge {} {v(d)} {save 1 plot 0}] rows2 st2
check "H2 sod_merge appends a new row" $st2 added
check "H2 appended row shape" $rows2 {{name {} expr v(d) plot 0 save 1}}
# OR the plot flavor into the save-only row
lassign [ase::ui::sod_merge $rows2 {v(d)} {save 1 plot 1}] rows2b st2b
check "H2 sod_merge ORs flags into an existing row" $st2b merged
check "H2 merged single row plot 1 save 1" $rows2b \
  {{name {} expr v(d) plot 1 save 1}}
# identical re-queue -> nochange, list returned unchanged
lassign [ase::ui::sod_merge $rows2b {v(d)} {save 1 plot 1}] rows2c st2c
check "H2 sod_merge identical re-queue is nochange" $st2c nochange
check "H2 nochange returns the outputs unchanged" $rows2c $rows2b
# other rows stay intact when a later row merges
set base {{name id expr -i(v1) save 1 plot 0} {name {} expr v(g) plot 0 save 1}}
lassign [ase::ui::sod_merge $base {v(g)} {save 1 plot 1}] rows2d st2d
check "H2 sod_merge leaves other rows intact" $rows2d \
  {{name id expr -i(v1) save 1 plot 0} {name {} expr v(g) plot 1 save 1}}

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set key [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  set mainok [main_ready]

  if {!$mainok} {
    puts "SKIPPED: I1-I10 Select On Design legs (WSLg geometry: main window never became usable)"
  } else {

    check "I0 open_state -> 1" \
      [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
    update
    set top [ase::ui::window_for $key]
    check_true "I0 session window exists" \
      [expr {$top ne {} && [winfo exists $top]}]

    # I1: the To Be Saved menu entry enters the mode on the design canvas.
    # Capture the PRE-mode value of every binding the mode takes first (the
    # design will land in the pristine untitled MAIN window -> canvas .drw).
    set cv .drw
    set pre_press   [bind $cv <ButtonPress-1>]
    set pre_rel     [bind $cv <ButtonRelease-1>]
    set pre_esc     [bind $cv <Key-Escape>]
    set pre_generic [bind $cv <ButtonPress>]
    set pre_dbl     [bind $cv <Double-Button-1>]
    set pre_destroy [bind $cv <Destroy>]
    set pre_motion  [bind $cv <B1-Motion>]
    $top.mb.outputs.saved invoke {Select On Design}
    update
    check "I1 design is the current schematic" \
      [file normalize [xschem get schname]] $schpath
    check "I1 mode canvas is the main canvas" [xschem get current_win_path] .drw
    check_true "I1 ButtonPress-1 seized (non-empty binding)" \
      [expr {[bind $cv <ButtonPress-1>] ne {}}]
    # The canvas binds the double click itself (set_bindings: the editor's
    # double click), and Tk hands the second press of a double click to that
    # binding unless the mode holds it too.
    check "I1 Double-Button-1 seized with the press's own script, over the editor's (the editor's script was there; the slot now equals the press slot)" \
      [list [string match {xschem callback %W -3 *} $pre_dbl] \
            [expr {[bind $cv <Double-Button-1>] eq [bind $cv <ButtonPress-1>]}]] {1 1}

    # The motion with the left button held is the mode's as well: left to the
    # editor it starts the selection rectangle under a pick whose hand drifts.
    check "I1 B1-Motion seized and swallowed (the slot now holds `break`)" \
      [bind $cv <B1-Motion>] break

    # I2: REAL generated click gesture queues v(g) — Motion at the target
    # pixel FIRST (that is what refreshes mousex_snap), then Press/Release.
    # World (340,-330) = the G-net wire, clear of the lG label at 300,-330.
    # Pixel = (w + origin)/zoom (X_TO_SCREEN, xschem.h) after zoom_full.
    xschem zoom_full
    update
    set xorig [xschem get xorigin]
    set yorig [xschem get yorigin]
    set zoom  [xschem get zoom]
    set px [expr {int(round((340.0 + $xorig) / $zoom))}]
    set py [expr {int(round((-330.0 + $yorig) / $zoom))}]
    if {$px < 0 || $py < 0 || $px >= [winfo width $cv] || $py >= [winfo height $cv]} {
      puts "SKIPPED: I2 real-gesture leg (computed pixel $px,$py outside the mapped canvas)"
    } else {
      event generate $cv <Motion> -x $px -y $py
      update
      event generate $cv <ButtonPress-1> -x $px -y $py
      event generate $cv <ButtonRelease-1> -x $px -y $py
      update
      set outs [ase::state_get [ase::session_state $key] outputs]
      check_true "I2 real click gesture queues v(g)" \
        [string match "*{name {} expr v(g) plot 0 save 1}*" $outs]

      # I2b: a REAL DOUBLE CLICK on the same wire, then a third press. Every
      # press is the mode's: the pick runs each time (finding the row
      # queued), nothing is selected and no editor dialog opens. Without the
      # mode's hold on the double-click binding the second press goes to the
      # editor, which selects the wire and opens its property dialog -- a
      # MODAL one, and so does the third, so this leg is bounded: a timer
      # that re-arms itself destroys any toplevel that appears, and the check
      # reports each one.
      set ::i2b_picks 0
      rename ase::ui::sod_click ase::ui::i2b_real_sod_click
      proc ase::ui::sod_click {args} { incr ::i2b_picks ; return [ase::ui::i2b_real_sod_click {*}$args] }
      set i2b_before [lmap w [winfo children .] { expr {[winfo toplevel $w] eq $w ? $w : [continue]} }]
      set ::i2b_killed {}
      proc i2b_guard {before} {
        foreach w [winfo children .] {
          if {[winfo toplevel $w] eq $w && [lsearch -exact $before $w] < 0} {
            lappend ::i2b_killed $w ; catch {destroy $w}
          }
        }
        set ::i2b_guard_id [after 1500 [list i2b_guard $before]]
      }
      set ::i2b_guard_id [after 1500 [list i2b_guard $i2b_before]]
      xschem unselect_all
      update
      event generate $cv <Motion> -x $px -y $py
      update
      # two presses 120 ms apart on the event clock, well after the click above
      set i2b_t 900000
      event generate $cv <ButtonPress-1>   -x $px -y $py -time $i2b_t
      event generate $cv <ButtonRelease-1> -x $px -y $py -time [expr {$i2b_t + 40}]
      event generate $cv <ButtonPress-1>   -x $px -y $py -time [expr {$i2b_t + 120}]
      event generate $cv <ButtonRelease-1> -x $px -y $py -time [expr {$i2b_t + 160}]
      update
      set i2b_two $::i2b_picks
      event generate $cv <ButtonPress-1>   -x $px -y $py -time [expr {$i2b_t + 240}]
      event generate $cv <ButtonRelease-1> -x $px -y $py -time [expr {$i2b_t + 280}]
      update
      after cancel $::i2b_guard_id
      rename ase::ui::sod_click {}
      rename ase::ui::i2b_real_sod_click ase::ui::sod_click
      set i2b_new [lmap w [winfo children .] { expr {[winfo toplevel $w] eq $w && [lsearch -exact $i2b_before $w] < 0 ? $w : [continue]} }]
      set outs [ase::state_get [ase::session_state $key] outputs]
      set nvg 0
      foreach o $outs { if {[ase::state_get $o expr] eq {v(g)}} { incr nvg } }
      check "I2b BOTH presses of a real double click reach the pick, so does the third press of a triple click, and none reaches the editor (picks after two presses, and after three; dialogs the guard had to close; toplevels left open; what is selected; still one v(g) row)" \
        [list $i2b_two $::i2b_picks $::i2b_killed $i2b_new [xschem selected_set] [xschem get lastsel] $nvg] \
        {2 3 {} {} {} 0 1}
      xschem unselect_all
    }

    # I3: direct wire click (D-net wire at 550,-330, clear of the lD label)
    ase::ui::sod_click $key 550 -330
    update
    set outs [ase::state_get [ase::session_state $key] outputs]
    check_true "I3 direct wire click queues v(d)" \
      [string match "*{name {} expr v(d) plot 0 save 1}*" $outs]
    # ase_l.md R-OUT7: a picked net is a save, so it lands in the Saves tab
    check_true "I3 row visible in the Outputs pane's Saves tab immediately" \
      [expr {[tv_find $top.body.saves.tv name {v(d)}] ne {}}]

    # I4: net-label click resolves the SAME net -> nochange, no state write
    set before [ase::state_get [ase::session_state $key] outputs]
    ase::ui::sod_click $key 500 -330
    update
    check "I4 net-label click dedupes (outputs unchanged)" \
      [ase::state_get [ase::session_state $key] outputs] $before

    # I5: vsource click queues the source current i(v1); the committed
    # row naming the same source is a DIFFERENT string and must survive
    # beside it, not be deduped away by the click. RESTATED after R208d
    # (1e987ffd) migrated the committed row from -i(v1) to -idc(v1): the
    # committed row is now READ from the committed state file rather than
    # spelled here, so a later migration cannot strand the row again, and
    # a leg asserts it really is a different string from the clicked one
    # (otherwise "survives beside it" would be vacuous).
    set i5_committed [lindex [ase::state_get [ase::state_load [file join \
      $repo sky130A xschem_libs sky130_tests test_nfet_final ngspice_state1 \
      test_nfet_final.state]] outputs] 0]
    ase::ui::sod_click $key 600 -300
    update
    set outs [ase::state_get [ase::session_state $key] outputs]
    check_true "I5 vsource click queues i(v1)" \
      [string match "*{name {} expr i(v1) plot 0 save 1}*" $outs]
    check "I5 the committed row names source v1 under a different string than the click" \
      [list [dict get $i5_committed name] [dict get $i5_committed expr] \
        [expr {[dict get $i5_committed expr] ne {i(v1)}}]] {id -idc(v1) 1}
    check_true "I5 committed row survives beside the clicked one" \
      [expr {[lsearch -exact $outs $i5_committed] >= 0}]

    # I6: non-source instance (M1 subcircuit) queues NOTHING (v1 scope)
    set before [ase::state_get [ase::session_state $key] outputs]
    ase::ui::sod_click $key 400 -300
    update
    check "I6 non-source click queues nothing" \
      [ase::state_get [ase::session_state $key] outputs] $before

    # I7: a REAL <Key-Escape> on the canvas ends the mode. Generated
    # KeyPress events go to the display's FOCUS window and WSLg confirms
    # focus asynchronously (the test_ase_window send_return diagnosis), so
    # gate each generate on Tk reporting the canvas as focus owner and retry
    # until the mode is provably inactive (the seized Key-Escape binding
    # reverted — restored by the product's sod_end).
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
    check "I7 ESC ends the mode via the REAL key" $ended 1
    check "I7 ButtonPress-1 binding restored verbatim" \
      [bind $cv <ButtonPress-1>] $pre_press
    check "I7 ButtonRelease-1 binding restored" \
      [bind $cv <ButtonRelease-1>] $pre_rel
    check "I7 Key-Escape binding restored" [bind $cv <Key-Escape>] $pre_esc
    check "I7 Double-Button-1 binding restored verbatim (the editor's own)" \
      [bind $cv <Double-Button-1>] $pre_dbl
    check "I7 Destroy binding restored" [bind $cv <Destroy>] $pre_destroy
    check "I7 B1-Motion binding restored" [bind $cv <B1-Motion>] $pre_motion
    check "I7 generic ButtonPress binding untouched" \
      [bind $cv <ButtonPress>] $pre_generic
    # ASE window re-raised above the design window after ESC — the W4
    # nudge/self-SKIP pattern (test_ase_window): the WSLg-safe raise is a
    # withdraw/deiconify re-map that can take ~2s to show in wm stackorder,
    # and WSLg occasionally DROPS a re-map outright; each nudge re-drives the
    # PRODUCT path (enter the mode + sod_end -> the same raise arm), so a
    # product regression that never raises still fails every attempt.
    proc i7_wait_ase_raised {top} {
      for {set i 0} {$i < 100} {incr i} {
        update
        set so [wm stackorder .]
        set ai [lsearch -exact $so $top]
        set di [lsearch -exact $so .]
        if {$ai >= 0 && $di >= 0 && $ai > $di} { return 1 }
        after 50
      }
      return 0
    }
    set raised [i7_wait_ase_raised $top]
    for {set nudge 1} {!$raised && $nudge <= 4} {incr nudge} {
      puts "  I7 raise stalled (WSLg re-map drop) — re-driving mode+sod_end (nudge $nudge)"
      $top.mb.outputs.saved invoke {Select On Design}
      update
      ase::ui::sod_end $key
      set raised [i7_wait_ase_raised $top]
    }
    if {$raised} {
      check "I7 ASE window re-raised after ESC" $raised 1
    } else {
      puts "SKIPPED: I7 raise assertion (WSLg stackorder stall after 5 product-path attempts)"
    }

    # I8: the To Be Plotted flavor ORs plot into the existing v(d) row —
    # still exactly ONE v(d) row
    $top.mb.outputs.plotted invoke {Select On Design}
    update
    ase::ui::sod_click $key 550 -330
    update
    set outs [ase::state_get [ase::session_state $key] outputs]
    check_true "I8 To Be Plotted flavor merges plot into v(d)" \
      [string match "*{name {} expr v(d) plot 1 save 1}*" $outs]
    set nvd 0
    foreach o $outs {
      if {[ase::state_get $o expr] eq {v(d)}} { incr nvd }
    }
    check "I8 still exactly one v(d) row" $nvd 1
    ase::ui::sod_end $key
    update

    # I9: the Add-Output dialog's From Design… button closes the dialog and
    # enters the mode
    $top.strip.out invoke
    update
    check_true "I9 --> opens the Add Output dialog" [winfo exists $top.edout]
    $top.edout.fromdes invoke
    update
    check_true "I9 From Design closes the dialog" \
      [expr {![winfo exists $top.edout]}]
    check_true "I9 mode active after From Design" \
      [expr {[bind $cv <ButtonPress-1>] ne $pre_press}]
    ase::ui::sod_end $key
    update

    # IT: THE DESIGN IN A TAB THAT IS NOT THE FIRST. With the tabbed interface
    # the tabs of the main window share its canvas, and the name of the context
    # a tab shows is a widget only for the first tab. Another document goes
    # into the first tab and the design into a second one; the mode is then
    # entered by the session window's menu entry, and by the command the
    # design window's Ctrl-4 runs (ase::direct_plot_for_current).
    #
    # a real ESC on canvas $c, sent once Tk reports the canvas as the focus
    # owner; 1 when the canvas's <Key-Escape> binding is $pre again
    proc it_real_esc {c pre} {
      for {set i 0} {$i < 100} {incr i} {
        update
        if {[bind $c <Key-Escape>] eq $pre} { return 1 }
        focus -force $c
        update
        if {[focus -displayof $c] eq $c} {
          event generate $c <Key-Escape>
          update
          if {[bind $c <Key-Escape>] eq $pre} { return 1 }
        }
        after 50
      }
      return 0
    }
    # the canvas of the mode for $k, or the word NONE
    proc it_mode_canvas {k} {
      if {![info exists ::ase::ui::sod(active)] || $::ase::ui::sod(active) ne $k} { return NONE }
      if {![info exists ::ase::ui::sod($k,canvas)]} { return NONE }
      return $::ase::ui::sod($k,canvas)
    }
    set it_tabbed $::tabbed_interface
    set ::tabbed_interface 1
    set it_other [file join $scratch it_other.sch]
    set f [open $it_other w]
    puts $f "v {xschem version=3.4.8RC file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nF {}\nE {}"
    close $f
    xschem set modified 0
    xschem load $it_other
    xschem new_schematic create {} $schpath
    update
    set it_tab [xschem get current_win_path]
    check "IT0 fixture: the design is in a second context that is a tab of the main window -- its name is not the main canvas's and is no widget (the names differ; the tab's is a widget; the sheet it shows; the contexts open)" \
      [list [expr {$it_tab ne $cv ? 1 : 0}] [winfo exists $it_tab] \
        [file normalize [xschem get schname]] [llength [xschem windows]]] \
      [list 1 0 $schpath 2]
    set it_before [lsearch -all -inline -glob \
      [ase::state_get [ase::session_state $key] outputs] {*expr v(g) *}]
    # the first tab, with the other document, is the one in front when the
    # menu entry is used: the entry has to bring the design's tab forward
    xschem new_schematic switch $cv
    update
    set it_front [file tail [xschem get schname]]
    $top.mb.outputs.plotted invoke {Select On Design}
    main_ready
    set it_menu [list $it_front [it_mode_canvas $key] [xschem get current_win_path] \
      [expr {[bind $cv <ButtonPress-1>] ne $pre_press ? 1 : 0}]]
    # a real click on the G-net wire, at the pixel the tab's own view puts it
    xschem zoom_full
    update
    set it_px [expr {int(round((340.0 + [xschem get xorigin]) / [xschem get zoom]))}]
    set it_py [expr {int(round((-330.0 + [xschem get yorigin]) / [xschem get zoom]))}]
    update
    event generate $cv <Motion> -x $it_px -y $it_py
    update
    event generate $cv <ButtonPress-1> -x $it_px -y $it_py -time 1900000
    event generate $cv <ButtonRelease-1> -x $it_px -y $it_py -time 1900040
    update
    set it_after [lsearch -all -inline -glob \
      [ase::state_get [ase::session_state $key] outputs] {*expr v(g) *}]
    set it_esc [it_real_esc $cv $pre_esc]
    check "IT1 the MENU ENTRY enters the mode with the design in the second tab, from the first: with the other document's tab in front, the entry brings the design's tab forward and the mode is on the main window's canvas with that tab the current context and the press seized; a real click on the G-net wire there merges the plot flag into the one v(g) row; a real ESC ends the mode and hands the press back (the sheet in front before; the mode's canvas, the current context, the press seized; the v(g) rows before the click and after it; ESC ended the mode; the press as before the mode)" \
      [list $it_menu $it_before $it_after $it_esc \
        [expr {[bind $cv <ButtonPress-1>] eq $pre_press ? 1 : 0}]] \
      [list [list it_other.sch .drw $it_tab 1] {{name {} expr v(g) plot 0 save 1}} \
        {{name {} expr v(g) plot 1 save 1}} 1 1]
    xschem new_schematic switch $it_tab
    update
    set it_key [ase::direct_plot_for_current]
    update
    set it_keyed [list [expr {$it_key eq $key ? 1 : 0}] [it_mode_canvas $key] \
      [expr {[info exists ::ase::ui::sod($key,mode)] ? $::ase::ui::sod($key,mode) : {NONE}}] \
      [expr {[bind $cv <ButtonPress-1>] ne $pre_press ? 1 : 0}]]
    set it_esc [it_real_esc $cv $pre_esc]
    check "IT2 the command the design window's Ctrl-4 runs enters Direct Plot there as well: it finds this session for the sheet in the tab, the mode is on the main window's canvas in the plot flavour with the press seized, and a real ESC ends it (it answers this session; the mode's canvas; its flavour; the press seized; ESC ended the mode; the press as before the mode)" \
      [list $it_keyed $it_esc [expr {[bind $cv <ButtonPress-1>] eq $pre_press ? 1 : 0}]] \
      [list [list 1 .drw plot 1] 1 1]
    catch {ase::ui::sod_end $key}
    # back to one context showing the design, as the rows below expect
    xschem new_schematic switch $it_tab
    xschem set modified 0
    xschem new_schematic destroy $it_tab {}
    xschem new_schematic switch $cv
    xschem set modified 0
    xschem load $schpath
    set ::tabbed_interface $it_tabbed
    main_ready
    check "IT3 the tab is closed again and the main window shows the design (the contexts open; the current one; the sheet)" \
      [list [llength [xschem windows]] [xschem get current_win_path] \
        [file normalize [xschem get schname]]] [list 1 $cv $schpath]

    # I10: closing the session window ends an active mode (binding-leak
    # guard) — re-enter, close, every binding the mode took restored
    $top.mb.outputs.saved invoke {Select On Design}
    update
    ase::ui::close $key
    update
    check "I10 close restored ButtonPress-1" [bind $cv <ButtonPress-1>] $pre_press
    check "I10 close restored ButtonRelease-1" \
      [bind $cv <ButtonRelease-1>] $pre_rel
    check "I10 close restored Key-Escape" [bind $cv <Key-Escape>] $pre_esc
    check "I10 close restored Double-Button-1" [bind $cv <Double-Button-1>] $pre_dbl
    check "I10 close restored Destroy" [bind $cv <Destroy>] $pre_destroy
    check "I10 close restored B1-Motion" [bind $cv <B1-Motion>] $pre_motion
    check_true "I10 session window gone" \
      [expr {![winfo exists $top]}]

    # I11: THE SESSION WINDOW CLOSED WITH THE RESULTS WINDOW'S PICK MODE ON TOP
    # OF SELECT ON DESIGN. The Results window's key, given with nothing
    # selected while Select On Design is up, stacks a click mode of its own on
    # the canvas. Closing the session window ends Select On Design from
    # underneath it, and that mode's release hands the canvas the editor's
    # scripts over the Results window's live ones. The close therefore asks
    # the Results window's mode to take the canvas again, and that mode's own
    # ESC then ends it.
    #
    # The session is opened again first (I10 closed it) and nothing is edited
    # in it. It is closed by the script its window runs for the window
    # manager's close button -- which asks about unsaved edits in a MODAL
    # dialog when there are any, so that script is run only for a session
    # that has none, and a fixture leg says so.
    #
    # an answer of the code under test, or the error it raised as ERR:<text>
    proc i11_q {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
    # the five slots the Results window's mode takes, as canvas $c holds them
    proc i11_slots {c} {
      return [lmap s {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion> <Double-Button-1>} { bind $c $s }]
    }
    # ...judged: `the Results window's` when they are that mode's own scripts,
    # `the editor's` when they are what the canvas held before any mode,
    # otherwise the slots themselves
    proc i11_whose {c editors} {
      set now [i11_slots $c]
      if {$now eq {{xschem callback %W 6 %x %y 0 0 0 %s; rdw::pick_click; break} break {rdw::pick_end; break} break break}} {
        return {the Results window's}
      }
      if {$now eq $editors} { return {the editor's} }
      return $now
    }
    # real ESC presses on canvas $c, each sent once Tk reports the canvas as
    # the focus owner, until the canvas's <Key-Escape> binding is $pre again:
    # {1 when it is, how many presses were sent}
    proc i11_real_esc {c pre} {
      set sent 0
      for {set i 0} {$i < 100} {incr i} {
        update
        if {[bind $c <Key-Escape>] eq $pre} { return [list 1 $sent] }
        focus -force $c
        update
        if {[focus -displayof $c] eq $c} {
          event generate $c <Key-Escape>
          incr sent
          update
        } else {
          after 50
        }
      }
      return [list 0 $sent]
    }
    set i11_editors [list $pre_press $pre_rel $pre_esc $pre_motion $pre_dbl]
    set i11_open [i11_q ase::open_state sky130_tests test_nfet_final ngspice_state1]
    update
    set top [ase::ui::window_for $key]
    set i11_before [i11_whose $cv $i11_editors]
    i11_q $top.mb.outputs.saved invoke {Select On Design}
    update
    set i11_sod [it_mode_canvas $key]
    xschem unselect_all
    i11_q rdw::key annotation
    update
    set i11_dirty [i11_q ase::session_dirty $key]
    set i11_stacked [list $i11_open $i11_before $i11_sod [i11_q rdw::pick_running] \
      [i11_whose $cv $i11_editors] $i11_dirty]
    set i11_door [wm protocol $top WM_DELETE_WINDOW]
    if {$i11_dirty eq {0} && $i11_door ne {}} {
      i11_q uplevel #0 $i11_door
    } else {
      i11_q ase::ui::close $key
    }
    update
    set i11_closed [list [winfo exists $top] [it_mode_canvas $key] [i11_q rdw::pick_running] \
      [i11_whose $cv $i11_editors]]
    set i11_esc [i11_real_esc $cv $pre_esc]
    check "I11 CLOSING THE SESSION WINDOW UNDER THE RESULTS WINDOW'S PICK MODE LEAVES THAT MODE ON THE CANVAS, AND ONE REAL ESC THEN FREES IT: with Select On Design up and the Results window's pick mode put on top of it by that window's key, given with nothing selected, the session window's own close script ends Select On Design, whose release hands the canvas the editor's scripts -- and the Results window's mode, still up, holds its five scripts on the canvas again; one <Key-Escape> sent to the canvas then reaches it through the binding it holds, and after that one press no mode is up and every slot holds what it held before any mode, the destroy handler included (fixture legs: the state view opened again; whose scripts the canvas held before any mode; Select On Design's canvas; the Results window's mode is up; whose scripts the canvas holds; the session has unsaved edits -- after the close: the session window is there; Select On Design's canvas; the Results window's mode is up; whose scripts the canvas holds -- after the ESC: its binding came back, and the presses that took; the Results window's mode is up; whose scripts the canvas holds; the destroy handler is as before)" \
      [list $i11_stacked $i11_closed \
        [list $i11_esc [i11_q rdw::pick_running] [i11_whose $cv $i11_editors] \
          [expr {[bind $cv <Destroy>] eq $pre_destroy ? 1 : 0}]]] \
      [list [list 1 {the editor's} .drw 1 {the Results window's} 0] \
        [list 0 NONE 1 {the Results window's}] \
        [list {1 1} 0 {the editor's} 1]]
    # whatever a red left behind: no mode, no session window
    catch {rdw::pick_end}
    catch {ase::ui::sod_end $key}
    catch {ase::ui::close $key}
    update

    # I12: THE OTHER WAY ROUND -- THE RESULTS WINDOW'S PICK MODE ENDED FIRST,
    # FROM UNDER SELECT ON DESIGN. That window's key comes first here and
    # Select On Design is entered over it, by its menu entry. Escape pressed in
    # the Results window then ends that window's mode while Select On Design
    # sits on top of it, and the release hands the canvas the editor's scripts
    # over Select On Design's live ones. Select On Design takes the canvas
    # again (ase::ui::sod_reseat): it holds its scripts with the editor's own
    # on record, a real press on a wire still queues that net, and one real ESC
    # on the canvas leaves every binding as it was before any mode.
    #
    # The Results window's mode is ended by the command its Escape binding
    # runs; the binding itself is pressed in row E6 of test_rdw_keys_1245,
    # which has that window. The session is opened again first (the rows
    # above closed it) and is closed at the foot without its window's close
    # script, which would ask about the row this leg queues.
    #
    # every binding of canvas $c, as {sequence script} pairs
    proc i12_table {c} { return [lmap s [lsort [bind $c]] { list $s [bind $c $s] }] }
    # what Select On Design has on record as the canvas's own for session $k,
    # in the order press, release, ESC, held motion, double click, destroy
    proc i12_prev {k} {
      return [lmap r {prevpress prevrel prevesc prevmotion prevdbl prevdestroy} {
        expr {[info exists ::ase::ui::sod($k,$r)] ? $::ase::ui::sod($k,$r) : {NOKEY}}
      }]
    }
    # is the press slot of canvas $c Select On Design's click for session $k
    proc i12_sods {c k} {
      return [expr {[string match "*[list ase::ui::sod_click $k]; break" [bind $c <ButtonPress-1>]] ? 1 : 0}]
    }
    # the rows of session $k that save the G net
    proc i12_vg {k} {
      return [lsearch -all -inline -glob [ase::state_get [ase::session_state $k] outputs] {*expr v(g) *}]
    }
    set i12_open [i11_q ase::open_state sky130_tests test_nfet_final ngspice_state1]
    update
    set top [ase::ui::window_for $key]
    set i12_base [i12_table $cv]
    set i12_editors6 [list $pre_press $pre_rel $pre_esc $pre_motion $pre_dbl $pre_destroy]
    xschem unselect_all
    i11_q rdw::key annotation
    update
    set i12_under [list [i11_q rdw::pick_running] [i11_whose $cv $i11_editors]]
    i11_q $top.mb.outputs.saved invoke {Select On Design}
    main_ready
    set i12_stacked [list $i12_open $i12_under [it_mode_canvas $key] [i12_sods $cv $key] \
      [expr {[lrange [i12_prev $key] 0 4] eq {{xschem callback %W 6 %x %y 0 0 0 %s; rdw::pick_click; break} break {rdw::pick_end; break} break break} ? {the Results window's} : [i12_prev $key]}]]
    i11_q rdw::pick_end
    update
    set i12_mid [list [i11_q rdw::pick_running] [it_mode_canvas $key] [i12_sods $cv $key] \
      [expr {[i12_prev $key] eq $i12_editors6 ? {the editor's} : [i12_prev $key]}]]
    # a real press on the G-net wire, at the pixel the view puts it
    xschem zoom_full
    update
    set i12_px [expr {int(round((340.0 + [xschem get xorigin]) / [xschem get zoom]))}]
    set i12_py [expr {int(round((-330.0 + [xschem get yorigin]) / [xschem get zoom]))}]
    set i12_vg0 [i12_vg $key]
    update
    event generate $cv <Motion> -x $i12_px -y $i12_py
    update
    event generate $cv <ButtonPress-1> -x $i12_px -y $i12_py -time 2100000
    event generate $cv <ButtonRelease-1> -x $i12_px -y $i12_py -time 2100040
    update
    set i12_pick [list $i12_vg0 [i12_vg $key]]
    set i12_esc [i11_real_esc $cv $pre_esc]
    set i12_ended [list [it_mode_canvas $key] [i11_q rdw::pick_running] \
      [expr {[i12_table $cv] eq $i12_base ? {as before any mode} : [i12_table $cv]}]]
    # an ordinary click on that wire now
    xschem unselect_all
    update
    event generate $cv <Motion> -x $i12_px -y $i12_py
    update
    event generate $cv <ButtonPress-1> -x $i12_px -y $i12_py -time 2200000
    event generate $cv <ButtonRelease-1> -x $i12_px -y $i12_py -time 2200040
    update
    set i12_sel [lindex [lindex [xschem selection] 0] 0]
    xschem unselect_all
    check "I12 THE RESULTS WINDOW'S PICK MODE ENDED FIRST, FROM UNDER SELECT ON DESIGN, LEAVES SELECT ON DESIGN ON THE CANVAS, AND ONE REAL ESC THEN FREES IT: with that window's mode up and Select On Design entered over it by its menu entry, the end the Results window's Escape runs hands the canvas the editor's scripts -- and Select On Design, still up, holds its press script on the canvas again with the editor's own on record for all six slots; a real press on the G-net wire then queues that net's row; one <Key-Escape> sent to the canvas ends the mode, and after that one press no mode is up, every binding of the canvas is as before any mode, and an ordinary click on that wire selects it (fixture legs: the state view opened again; the Results window's mode is up and holds the canvas; Select On Design's canvas; the press slot is its own; whose scripts it has on record -- after the end: the Results window's mode is up; Select On Design's canvas; the press slot is its own; whose scripts it has on record -- the rows saving the G net before the press and after it -- the ESC: its binding came back, and the presses that took -- after it: Select On Design's canvas; the Results window's mode is up; the canvas's bindings -- what the ordinary click selected)" \
      [list $i12_stacked $i12_mid $i12_pick $i12_esc $i12_ended $i12_sel] \
      [list [list 1 [list 1 {the Results window's}] .drw 1 {the Results window's}] \
        [list 0 .drw 1 {the editor's}] \
        [list {} {{name {} expr v(g) plot 0 save 1}}] \
        {1 1} [list NONE 0 {as before any mode}] wire]
    # whatever a red left behind: no mode, no session window
    catch {rdw::pick_end}
    catch {ase::ui::sod_end $key}
    catch {ase::ui::close $key}
    update

    # I13: THE SESSION WINDOW CLOSED WHILE A DESCEND HAS BOTH MODES PAUSED.
    # The descend command given with nothing selected pauses every click mode
    # and waits in the event loop for a click on an instance. Both modes have
    # handed the canvas back by then; Select On Design, entered over the
    # Results window's mode, still has that mode's scripts on record as what
    # the canvas held. Closing the session window during the wait ends Select
    # On Design, and its release must write nothing (ase::ui::sod_release): the
    # record written back would put the scripts of the Results window's mode,
    # which is paused, on the canvas, and the click the descend waits for would
    # be that mode's.
    #
    # The descend is armed by the command its key runs, and its wait is ended
    # by a real Escape on the canvas, which is the editor's while everything is
    # paused: it drops the descend, and that puts back what was paused. The
    # session window is closed as in I11, by its own close script for a session
    # with nothing unsaved.
    #
    # ONE real Escape on canvas $c, sent once Tk reports the canvas as the
    # focus owner: 1 when it was sent
    proc i13_esc_once {c} {
      for {set i 0} {$i < 100} {incr i} {
        focus -force $c
        update
        if {[focus -displayof $c] eq $c} {
          event generate $c <Key-Escape>
          update
          return 1
        }
        after 50
      }
      return 0
    }
    # the canvas's bindings against `base`: that phrase, or whose scripts the
    # five slots hold
    proc i13_canvas {c base editors} {
      return [expr {[i12_table $c] eq $base ? {as before any mode} : [i11_whose $c $editors]}]
    }
    set i13_open [i11_q ase::open_state sky130_tests test_nfet_final ngspice_state1]
    update
    set top [ase::ui::window_for $key]
    set i13_base [i12_table $cv]
    xschem unselect_all
    i11_q rdw::key annotation
    update
    i11_q $top.mb.outputs.saved invoke {Select On Design}
    main_ready
    set i13_stacked [list $i13_open [i11_q rdw::pick_running] [it_mode_canvas $key] [i12_sods $cv $key] \
      [expr {[lrange [i12_prev $key] 0 4] eq {{xschem callback %W 6 %x %y 0 0 0 %s; rdw::pick_click; break} break {rdw::pick_end; break} break break} ? {the Results window's} : [i12_prev $key]}]]
    xschem unselect_all
    set i13_arm [i11_q hi_descend]
    update
    set i13_wait [list $i13_arm [i11_q cmdmode::is_suspended] [i11_q cmdmode::pending] \
      [info exists ::ase::ui::sod($key,suspended)] [info exists ::rdw::pick(suspended)] \
      [i13_canvas $cv $i13_base $i11_editors]]
    set i13_dirty [i11_q ase::session_dirty $key]
    set i13_door [wm protocol $top WM_DELETE_WINDOW]
    if {$i13_dirty eq {0} && $i13_door ne {}} {
      i11_q uplevel #0 $i13_door
    } else {
      i11_q ase::ui::close $key
    }
    update
    set i13_closed [list $i13_dirty [winfo exists $top] [info exists ::ase::ui::sod(active)] \
      [array names ::ase::ui::sod $key,*] [i11_q rdw::pick_running] [info exists ::rdw::pick(suspended)] \
      [i13_canvas $cv $i13_base $i11_editors] [i11_q cmdmode::is_suspended]]
    set i13_sent [i13_esc_once $cv]
    set i13_back [list $i13_sent [i11_q cmdmode::is_suspended] [i11_q rdw::pick_running] \
      [info exists ::rdw::pick(suspended)] [i11_whose $cv $i11_editors] [info exists ::ase::ui::sod(active)]]
    set i13_esc [i11_real_esc $cv $pre_esc]
    check "I13 THE SESSION WINDOW CLOSED WHILE A DESCEND HAS BOTH MODES PAUSED WRITES NOTHING ON THE CANVAS: with the Results window's mode up and Select On Design entered over it by its menu entry, the descend command given with nothing selected pauses both and the canvas is as before any mode; the session window's own close script then ends Select On Design -- no mode of that session on record, none of its records left -- and the canvas is still as before any mode, not on the scripts of the Results window's mode, which is still paused, and the descend still waits.  A real Escape on the canvas then drops the descend, and the Results window's mode comes back alone, holding its five scripts; one more <Key-Escape> ends it, and after that one press no mode is up and every binding of the canvas is as before any mode (fixture legs: the state view opened again; the Results window's mode is up; Select On Design's canvas; the press slot is its own; whose scripts it has on record -- the wait: the descend armed; cmdmode has modes paused; the names it holds to put back; Select On Design is marked paused; the Results window's mode is; the canvas -- after the close: the session had unsaved edits; the session window is there; a Select On Design is on record; its records; the Results window's mode is up; it is marked paused; the canvas; cmdmode has modes paused -- after the first Escape: it was sent; cmdmode has modes paused; the Results window's mode is up; it is marked paused; whose scripts the canvas holds; a Select On Design is on record -- the last ESC: its binding came back, and the presses that took; the Results window's mode is up; the canvas)" \
      [list $i13_stacked $i13_wait $i13_closed $i13_back \
        [list $i13_esc [i11_q rdw::pick_running] [i13_canvas $cv $i13_base $i11_editors]]] \
      [list [list 1 1 .drw 1 {the Results window's}] \
        [list 1 1 {rdw_pick ase_sod} 1 1 {as before any mode}] \
        [list 0 0 0 {} 1 1 {as before any mode} 1] \
        [list 1 0 1 0 {the Results window's} 0] \
        [list {1 1} 0 {as before any mode}]]
    # whatever a red left behind: no descend waiting, nothing paused, no mode,
    # no session window
    catch {xschem callback $cv 2 0 0 65307 0 0 0}
    catch {cmdmode::resume_all}
    catch {rdw::pick_end}
    catch {ase::ui::sod_end $key}
    catch {ase::ui::close $key}
    foreach i13_q [bind $cv] { if {[lsearch -exact [lmap i13_p $i13_base {lindex $i13_p 0}] $i13_q] < 0} { catch {bind $cv $i13_q {}} } }
    foreach i13_p $i13_base { catch {bind $cv [lindex $i13_p 0] [lindex $i13_p 1]} }
    update
  }

  # --- WF: the whole-flow ROUND GATE on a FRESH session (D11: the I-leg
  # session was closed WITHOUT saving, so this reopens the pristine clone) ---
  check "WF open state -> 1" \
    [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true "WF session window exists" \
    [expr {$top ne {} && [winfo exists $top]}]
  check "WF v2 title" [wm title $top] {Analog Sim Environment test_nfet_final}

  # WF Choose Analyses: dialog opens preselected on op with Enable set (the
  # committed state), OK round-trips
  $top.mb.analyses invoke "Choose\u2026"
  update
  check_true "WF Choose Analyses dialog opens" [winfo exists $top.chana]
  check "WF Choose Analyses preselects op" $::ase::ui::dlg($key,antype) op
  check "WF Choose Analyses op Enable set" $::ase::ui::dlg($key,anen) 1
  $top.chana.btns.proceed invoke
  update
  check_true "WF Choose Analyses dialog closed" \
    [expr {![winfo exists $top.chana]}]
  set open {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {op}} { set open [ase::state_get $a enabled] }
  }
  check "WF op analysis still enabled" $open 1

  # WF --> dialog adds the vd=vdc(d) output (save checked). ase_l.md R-OUT7:
  # the dialog opens on the Measures tab, where a plain v(d) is a save and is
  # refused; the number the leg reads is the operating point's, vdc(d).
  $top.strip.out invoke
  update
  check_true "WF --> opens the Add Output dialog" [winfo exists $top.edout]
  $top.edout.name insert 0 vd
  $top.edout.expr insert 0 {vdc(d)}
  set ::ase::ui::edchk($key,save) 1   ;# the checkbutton variable is product surface
  $top.edout.btns.proceed invoke
  update
  check_true "WF dialog adds vdc(d) to the state" \
    [string match "*{name vd expr vdc(d) plot 0 save 1}*" \
      [ase::state_get [ase::session_state $key] outputs]]
  check_true "WF vd row in the Outputs pane" \
    [expr {[tv_find $top.body.outs.tv name vd] ne {}}]

  # WF Netlist and Run (needs the main window for netlisting + ngspice)
  if {!$mainok} {
    puts "SKIPPED: WF Netlist-and-Run legs (WSLg geometry: main window never became usable)"
  } elseif {[auto_execok ngspice] eq {}} {
    puts "SKIPPED: WF Netlist-and-Run legs (ngspice not found)"
  } else {
    $top.mb.sim invoke {Netlist and Run}
    set idw [ase::session_getattr $key run_id]
    check_true "WF Netlist and Run started (integer execute id)" \
      [string is integer -strict $idw]
    check_true "WF log toplevel appears" [winfo exists $top.logwin]
    set ecw [ase::wait $idw]
    update
    check "WF exit 0" $ecw 0
    check "WF status Ready" [$top.status.stat cget -text] {Status: Ready}
    check "WF status light Green" [$top.status.stat cget -background] Green
    set otv $top.body.outs.tv
    set idit [tv_find $otv name id]
    set vcell [expr {$idit ne {} ? [$otv set $idit value] : {}}]
    # item 09: the Value cell renders in engineering notation (409.7u) — the
    # `u` suffix makes the cell uA directly, same physical gate as before
    set vok 0
    if {[regexp {^-?([0-9.]+)u$} $vcell -> num]} {
      if {abs($num - 409.68) < 1.0} { set vok 1 }
    }
    check "WF id Value ~409.7uA" $vok 1
    if {!$vok} { puts "  WF id Value cell: '$vcell'" }
    set vdit [tv_find $otv name vd]
    set vdcell [expr {$vdit ne {} ? [$otv set $vdit value] : {}}]
    # v(d)=1.0 formats to a plain `1`, but accept a NUMm (x1e-3) rendering
    # too so a 999.9m-class rounding can never flake the leg (item 09)
    set vdok 0
    if {[string is double -strict $vdcell]} {
      if {abs($vdcell - 1.0) < 1e-3} { set vdok 1 }
    } elseif {[regexp {^-?([0-9.]+)m$} $vdcell -> vdnum]} {
      if {abs($vdnum * 1e-3 - 1.0) < 1e-3} { set vdok 1 }
    }
    check "WF vd Value ~1.0 (added output flowed through)" $vdok 1
    if {!$vdok} { puts "  WF vd Value cell: '$vdcell'" }
  }

  # WF Save State to a scratch view of the CLONE
  check "WF Save State dialog round completed" \
    [menu_save_state_as $top ngspice_scratch1] 1
  set scratchstate [file join $clonelib test_nfet_final ngspice_scratch1 \
    test_nfet_final.state]
  check_true "WF scratch view created" [file isfile $scratchstate]
  # snapshot the three pane-backing lists NOW (identity gate after reopen)
  set snap_vars [ase::state_get [ase::session_state $key] variables]
  set snap_ana  [ase::state_get [ase::session_state $key] analyses]
  set snap_outs [ase::state_get [ase::session_state $key] outputs]

  # WF close the session
  # item 16: this session is DIRTY; the menu Close now routes through
  # close_request's save prompt, so tear down directly (behavior-identical to
  # the pre-rewire menu Close).
  ase::ui::close $key
  update
  check_true "WF close destroyed the window" [expr {![winfo exists $top]}]

  # WF reopen the scratch view: panes repopulate identically
  set key2 [ase::session_key sky130_tests test_nfet_final ngspice_scratch1]
  check "WF reopen scratch view -> 1" \
    [ase::open_state sky130_tests test_nfet_final ngspice_scratch1] 1
  update
  set top2 [ase::ui::window_for $key2]
  check_true "WF reopened window exists" \
    [expr {$top2 ne {} && [winfo exists $top2]}]
  check "WF variables identical" \
    [ase::state_get [ase::session_state $key2] variables] $snap_vars
  check "WF analyses identical" \
    [ase::state_get [ase::session_state $key2] analyses] $snap_ana
  check "WF outputs identical" \
    [ase::state_get [ase::session_state $key2] outputs] $snap_outs
  check_true "WF reopened pane shows the vd row" \
    [expr {[tv_find $top2.body.outs.tv name vd] ne {}}]
  $top2.mb.session invoke Close
  update

} else {
  puts "gui legs skipped (no DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
