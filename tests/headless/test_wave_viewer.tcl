# Waveform Viewer window shell (item 11 of doc/claude/ase_l_batch, spec
# doc/claude/specs/waveform_viewer.md — src/wave_viewer.tcl + the ase.tcl
# raw_file backend hook):
#   V1  render_deck emits exactly one `write <rundir>/<cell>_ase.raw` line
#       inside .control...endc, after the print line (fixture state, op on)
#   V2  no write line when ALL analyses are disabled
#   V3  ase::backend_hook ngspice raw_file resolves -> <rundir>/<cell>_ase.raw
#   V4  real ngspice dc sweep (spec schema shape) through ase::netlist +
#       ase::run_deck -> exit 0 AND the raw artifact exists non-empty
#       (guarded: SKIP without ngspice)
#   V5  xschem raw read of the artifact: sim_type dc, points == 181,
#       vars >= 2, `raw loaded` >= 0 (INDEX semantics — never a boolean)
#   V6  embedded-graph regression: shipped test_ne555.sch loads (readonly),
#       keeps its layer-2 graph rect + flags=graph, redraws rc 0
#   G1-G9 GUI legs (DISPLAY-guarded self-SKIP): open viewer from a session
#       token (toplevel, registry, readonly, untitled buffer); strip SWEEP
#       (G1s, fixup: user-rc binds installed on the main .drw pre-open —
#       cadence_style_rc:109 verbatim <Key-i> + a Windows-arm-shaped
#       <Alt-KeyPress> — are cloned by clone_canvas_bindings onto the viewer
#       canvas and MUST be cleared there, main canvas keeps its own; plus a
#       completeness check: no sequence outside the keep+filter set); viewer
#       menubar attached (File/View/Graph/Cursors, Graph+Cursors disabled),
#       editor menubar NOT attached; exact title + with_edit clobber
#       regression; window number > 0; strip (i/Insert/w do nothing: no
#       instance, no wire, no modify, no readonly MODAL — recording
#       tk_messageBox stub — no new toplevel; `i` reaches the FILTER, not
#       the cloned create_instance bind); ESC does not close; display_raw
#       (1 graph rect, node prop, raw points in the viewer ctx, redraw,
#       modified 0 + readonly restored, no untitled*~.sch autosave backup);
#       re-open raises the SAME window (number unchanged); Ctrl-W closes
#       with no prompt, registry cleaned, reopen builds a fresh window.
#
# Honest assertability (spec D8): headless/GUI legs can assert raw
# points/vars/sim_type, layer-2 rect count/props, redraw rc 0 and
# modified-still-0; the actual PIXEL rendering of the waves is eyeball-only
# and is NOT asserted anywhere.
#
# Runs via full_audit's DEFAULT arm (GUI legs self-SKIP without a usable
# display). Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_viewer.tcl
# (drop --nogui and provide DISPLAY for the GUI legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
set scratch [file normalize [file join [pwd] _wviewer_[pid]]]
file delete -force $scratch
file mkdir $scratch

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]
set modelsdir [file join $repo sky130A models libs.tech combined]

# model resolution exactly as sky130A/cadence_style_rc sets it
set ::SKYWATER_MODELS $modelsdir

# scratch registry pointing at the REAL committed trees (test_ase_final
# pattern — never the pre-batch-dirty workarea library.defs)
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]
set rawpath [file join $rundir test_nfet_final_ase.raw]

if {[catch {

# --- fixture state: COPY of the committed .state, scratch rundir, dc sweep
# enabled per the spec schema shape (the committed fixture is never written)
set st [ase::state_load $statefile]
dict set st rundir $rundir
set an {}
foreach a [dict get $st analyses] {
  if {[dict get $a type] eq {dc}} {
    set a [dict create type dc enabled 1 source V2 start 0 stop 1.8 step 0.01]
  }
  lappend an $a
}
dict set st analyses $an

# --- V1: write emission (op enabled in the fixture) --------------------------
set render [ase::backend_hook ngspice render_deck]
set netlist_stub {* stub circuit
V1 D GND 1
.end
}
set deck [$render $st $netlist_stub]
set nwrite 0
foreach line [split $deck "\n"] {
  if {$line eq "write $rawpath"} { incr nwrite }
}
check "V1 exactly one write line with the exact raw path" $nwrite 1
set cidx [string first "\n.control\n" $deck]
set pidx [string first "\nprint -i(v1)\n" $deck]
set widx [string first "\nwrite $rawpath\n" $deck]
set eidx [string first "\n.endc\n" $deck]
check_true "V1 write inside .control, after print, before .endc" \
  [expr {$cidx >= 0 && $pidx > $cidx && $widx > $pidx && $eidx > $widx}]

# --- V2: all analyses disabled -> NO write line ------------------------------
set st2 $st
set an2 {}
foreach a [dict get $st2 analyses] { lappend an2 [dict replace $a enabled 0] }
dict set st2 analyses $an2
set deck2 [$render $st2 $netlist_stub]
check_true "V2 no write line while every analysis is disabled" \
  [expr {![regexp -line {^write } $deck2]}]

# --- V3: the raw_file backend hook -------------------------------------------
set rfhook [ase::backend_hook ngspice raw_file]
check_true "V3 raw_file hook resolves to a command" \
  [expr {[info commands $rfhook] ne {}}]
check "V3 raw_file returns <rundir>/<cell>_ase.raw" [$rfhook $st] $rawpath

# --- V4/V5: real ngspice dc sweep -> raw artifact -> raw read (guarded) ------
set have_raw 0
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: V4/V5 run legs (ngspice not found)"
} else {
  # make the design the CURRENT schematic so ase::netlist works both headless
  # and under has_x (its GUI arm refuses when another schematic is current)
  xschem load $schfile
  set nl [ase::netlist $st]
  set id [ase::run_deck $st $nl]
  set ec [ase::wait $id]
  check "V4 ngspice exit code 0" $ec 0
  check_true "V4 raw artifact produced, non-empty" \
    [expr {[file isfile $rawpath] && [file size $rawpath] > 0}]
  if {[file isfile $rawpath] && [file size $rawpath] > 0} { set have_raw 1 }

  # error-guarded query: `xschem raw sim_type/points/...` THROW when nothing
  # is loaded — a missing artifact must FAIL these checks, not abort the test
  proc rawq {script} {
    if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
    return $r
  }
  set rc [rawq {xschem raw read $rawpath dc}]
  check "V5 raw read returns 1" $rc 1
  check "V5 sim_type is dc" [rawq {xschem raw sim_type}] dc
  check "V5 points == 181 (dc 0..1.8 step 0.01)" [rawq {xschem raw points}] 181
  check_true "V5 vars >= 2" \
    [expr {[string is integer -strict [rawq {xschem raw vars}]] &&
           [rawq {xschem raw vars}] >= 2}]
  check_true "V5 raw loaded index >= 0 (INDEX semantics, never boolean)" \
    [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
           [rawq {xschem raw loaded}] >= 0}]
  catch {xschem raw clear}
}

# --- V6: embedded-graph regression (shipped file, readonly) ------------------
xschem load [file join $repo xschem_library examples test_ne555.sch]
xschem set readonly 1
check_true "V6 shipped schematic keeps its layer-2 graph rect(s)" \
  [expr {[xschem get rects 2] > 0}]
check "V6 first layer-2 rect keeps flags=graph" \
  [xschem getprop rect 2 0 flags] graph
check "V6 redraw rc 0 on the readonly graph schematic" [catch {xschem redraw}] 0

# --- GUI legs (DISPLAY-guarded self-SKIP) ------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # deliver a REAL generated key event $ev to $w, WSLg-robustly (the
  # send_key helper pattern from test_ase_dialogs.tcl: Tk redirects GENERATED
  # KeyPress events to the display's focus window and the WSLg focus
  # round-trip is asynchronous — gate every generate on Tk reporting $w as
  # the focus owner and retry until $done, an expr evaluated in the CALLER's
  # scope, turns true). Returns 1 on proven delivery, 0 on ~10s timeout.
  proc send_key {w ev done} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w]} {
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

  proc toplevel_count {} {
    set n 0
    foreach c [winfo children .] {
      if {[winfo class $c] eq {Toplevel}} { incr n }
    }
    return $n
  }

  # wait for the viewer canvas to be mapped (WSLg can be slow); 0 -> the
  # key-event legs SKIP rather than FAIL on a never-mapped window
  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  # recording stub for tk_messageBox: a readonly_block MODAL would hang the
  # test — the stub records the request and answers ok (restored at the end)
  rename ::tk_messageBox ::wvtest_real_messageBox
  set ::mb_hits 0
  proc ::tk_messageBox {args} { incr ::mb_hits; return ok }

  # instrument wviewer::key_filter with an invocation counter WITHOUT
  # changing behavior: a swallowed key changes no product state, so the
  # counter is the only honest delivery witness send_key can gate on.
  # The original is renamed WITHIN its namespace — renaming a namespaced
  # proc into :: breaks its `variable` resolution and the filter then
  # errors instead of filtering (a swallow-by-error looks exactly like a
  # swallow-by-design: hollow-green). kf_errs guards that class: the
  # product filter must never throw.
  rename ::wviewer::key_filter ::wviewer::key_filter_orig
  set ::kf_calls 0
  set ::kf_errs 0
  proc ::wviewer::key_filter {W T x y N K s} {
    incr ::kf_calls
    if {[catch {::wviewer::key_filter_orig $W $T $x $y $N $K $s} e]} {
      incr ::kf_errs
      puts "  key_filter ERROR: $e"
    }
  }

  # user-rc canvas binds that clone_canvas_bindings (xinit.c
  # create_new_window) copies onto every new window's canvas BEFORE
  # wviewer::strip_bindings runs — the strip-sweep fixup target.
  # cadence_style_rc:109 VERBATIM + a per-widget bind shaped like
  # set_bindings' Windows-only Alt arm (the latent class). Unbound again
  # after the GUI legs.
  bind .drw <Key-i> {xschem create_instance; break}
  bind .drw <Alt-KeyPress> {wvtest_alt_arm_probe}

  # --- G1: session registered headless -> wviewer::open ----------------------
  check "G1 unknown token -> 0, no throw" [wviewer::open no/such/token] 0
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate
  check "G1 wviewer::open returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  check_true "G1 viewer toplevel exists" \
    [expr {$vtop ne {} && [winfo exists $vtop]}]
  set vdrw $vtop.drw
  check_true "G1 viewer canvas exists" [winfo exists $vdrw]
  xschem new_schematic switch $vdrw
  check "G1 viewer buffer is readonly" [xschem get readonly] 1
  check_true "G1 viewer buffer is untitled-class" \
    [string match {*untitled*} [file tail [xschem get schname]]]

  # --- G1s: strip SWEEP — cloned user-rc / Windows-arm binds cleared ---------
  # (more-specific Tk binds fire INSTEAD of the generic key_filter, so any
  # survivor is a live editing-verb hole)
  check "G1s cloned <Key-i> cleared from the viewer canvas" \
    [bind $vdrw <Key-i>] {}
  check "G1s cloned <Alt-KeyPress> cleared from the viewer canvas" \
    [bind $vdrw <Alt-KeyPress>] {}
  check "G1s main canvas keeps its own <Key-i> bind (per-widget strip)" \
    [bind .drw <Key-i>] {xschem create_instance; break}
  # completeness: NOTHING outside keep-set + installed filters survives.
  # The allowed list is hardcoded (independent witness, canonical Tk
  # spellings) — reading wviewer::keepseqs back would go hollow if a verb
  # sequence ever crept into it.
  set allowed {
    <Expose> <Configure> <Visibility> <Enter> <Leave> <Motion> <Unmap>
    <MouseWheel> <Button> <ButtonRelease>
    <Key> <KeyRelease> <Button-3> <ButtonRelease-3>
    <Double-Button-1> <Double-Button-2> <Double-Button-3>
  }
  set stray {}
  foreach seq [bind $vdrw] {
    if {[lsearch -exact $allowed $seq] < 0} { lappend stray $seq }
  }
  check "G1s no canvas sequence outside the keep+filter set" $stray {}

  # --- G2: viewer menubar replaces the editor menubar ------------------------
  set mb [$vtop cget -menu]
  check "G2 attached menu is the viewer menubar" $mb $vtop.wvmenubar
  check_true "G2 editor menubar is NOT the attached menu" \
    [expr {$mb ne "$vtop.menubar"}]
  set labels {}
  for {set i 0} {$i <= [$mb index end]} {incr i} {
    lappend labels [$mb entrycget $i -label]
  }
  check "G2 cascade labels exactly File View Graph Cursors" $labels \
    {File View Graph Cursors}
  set alldis 1
  foreach m [list $mb.graph $mb.cursors] {
    for {set i 0} {$i <= [$m index end]} {incr i} {
      if {[$m entrycget $i -state] ne {disabled}} { set alldis 0 }
    }
  }
  check "G2 every Graph + Cursors entry disabled (item-12 placeholders)" \
    $alldis 1

  # --- G3: exact title + with_edit clobber regression ------------------------
  set exp_title "Waveforms test_nfet_final (ngspice_state1)"
  check "G3 title exact" [wm title $vtop] $exp_title
  wviewer::with_edit $tok {}
  check "G3 title STILL exact after a with_edit cycle" [wm title $vtop] \
    $exp_title

  # --- G4: window number ------------------------------------------------------
  xschem new_schematic switch $vdrw
  set wnum [xschem get window_number]
  check_true "G4 viewer window number > 0" [expr {$wnum > 0}]

  if {![viewer_ready $vtop]} {
    puts "SKIPPED: G5/G6/G9 key-event legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {
    # --- G5: strip — editing keys do NOTHING, silently -----------------------
    set tls_before [toplevel_count]
    set mbh_before $::mb_hits
    xschem new_schematic switch $vdrw
    set ::kf_calls 0
    set d1 [send_key $vdrw <Key-Insert> {$::kf_calls > 0}]
    set ::kf_calls 0
    set d2 [send_key $vdrw <Key-w> {$::kf_calls > 0}]
    check "G5 Insert + w delivered to the viewer filter" [list $d1 $d2] {1 1}
    # `i`: the cloned create_instance bind would fire INSTEAD of the filter
    # (and `break`) — kf_calls can only move if the sweep cleared it, so
    # delivery-to-filter IS the strip witness for the fixed hole
    set ::kf_calls 0
    set d2i [send_key $vdrw <Key-i> {$::kf_calls > 0}]
    check "G5 i reaches the FILTER (cloned bind swept)" $d2i 1
    update
    xschem new_schematic switch $vdrw
    check "G5 instances still 0" [xschem get instances] 0
    check "G5 wires still 0" [xschem get wires] 0
    check "G5 modified still 0" [xschem get modified] 0
    check "G5 no readonly modal (messageBox stub unhit)" \
      [expr {$::mb_hits - $mbh_before}] 0
    check "G5 no new toplevel appeared" [toplevel_count] $tls_before

    # --- G6: ESC never closes the viewer -------------------------------------
    set mbh_before $::mb_hits
    set ::kf_calls 0
    set d3 [send_key $vdrw <Key-Escape> {$::kf_calls > 0}]
    check "G6 Escape delivered" $d3 1
    update
    check_true "G6 viewer toplevel survives ESC" [winfo exists $vtop]
    check "G6 ESC popped no dialog" [expr {$::mb_hits - $mbh_before}] 0

    # --- G7: display_raw sanity leg ------------------------------------------
    set backups_before [lsort [glob -nocomplain *~.sch]]
    if {$have_raw} {
      check "G7 display_raw returns 1" \
        [wviewer::display_raw $tok $rawpath dc {i(v1)}] 1
    } else {
      puts "SKIPPED: G7 raw-load asserts (no rawfile from V4) - rect only"
      check "G7 display_raw (rect only) returns 1" \
        [wviewer::display_raw $tok {} dc {i(v1)}] 1
    }
    xschem new_schematic switch $vdrw
    check "G7 exactly one layer-2 graph rect" [xschem get rects 2] 1
    check "G7 rect carries flags=graph" [xschem getprop rect 2 0 flags] graph
    check_true "G7 rect node attr carries i(v1)" \
      [string match {*i(v1)*} [xschem getprop rect 2 0 node]]
    if {$have_raw} {
      check "G7 raw points 181 in the viewer ctx" [xschem raw points] 181
    }
    check "G7 redraw rc 0" [catch {xschem redraw}] 0
    check "G7 modified still 0 after display_raw" [xschem get modified] 0
    check "G7 readonly restored after display_raw" [xschem get readonly] 1
    check "G7 no untitled autosave backup appeared (D1 bracket)" \
      [lsort [glob -nocomplain *~.sch]] $backups_before

    # --- G8: re-open raises the SAME window ----------------------------------
    set tls_before [toplevel_count]
    check "G8 re-open returns 1" [wviewer::open $tok] 1
    check "G8 same toplevel" [wviewer::window_for $tok] $vtop
    check "G8 no second window" [toplevel_count] $tls_before
    xschem new_schematic switch $vdrw
    check "G8 window number unchanged" [xschem get window_number] $wnum

    # --- G9: Ctrl-W closes with NO prompt; reopen builds fresh ---------------
    set mbh_before $::mb_hits
    set d4 [send_key $vdrw <Control-Key-w> {![winfo exists $vtop]}]
    check "G9 Ctrl-W closed the viewer" $d4 1
    check_true "G9 toplevel destroyed" [expr {![winfo exists $vtop]}]
    check "G9 close popped no dialog/prompt" \
      [expr {$::mb_hits - $mbh_before}] 0
    check "G9 registry cleaned" [wviewer::window_for $tok] {}
    check "G9 reopen after close returns 1" [wviewer::open $tok] 1
    set vtop2 [wviewer::window_for $tok]
    check_true "G9 fresh viewer window created" \
      [expr {$vtop2 ne {} && [winfo exists $vtop2]}]
    wviewer::close $tok
    update
    check "G9 closed via the API, registry clean" [wviewer::window_for $tok] {}
  }

  # the strip filter must never throw: a filter error swallows keys by
  # ACCIDENT and every strip assertion above turns hollow (found live: the
  # instrumentation itself once induced exactly this)
  check "G* key_filter ran error-free" $::kf_errs 0

  # restore the instrumented procs + drop the user-rc probe binds
  rename ::wviewer::key_filter {}
  rename ::wviewer::key_filter_orig ::wviewer::key_filter
  rename ::tk_messageBox {}
  rename ::wvtest_real_messageBox ::tk_messageBox
  bind .drw <Key-i> {}
  bind .drw <Alt-KeyPress> {}
} else {
  puts "SKIPPED: G1-G9 GUI legs (no usable DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
file delete -force $scratch
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
