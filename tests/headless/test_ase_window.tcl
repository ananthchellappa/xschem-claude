# ASE-L session window (item 03 of doc/claude/ase_l_batch, P3 of
# doc/claude/specs/ase_l.md) — the real ase::open_state window:
#   H1-H3  session model: open/state/update/dirty/save/load/revert (headless)
#   H4     ase::open_state contract (1 / 0, never an error; session registered)
#   H5     `xschem allocate_window_number` C seam (monotonic, starts >= 3)
#   H6     ase::backend_names offers ngspice
#   W1-W8  GUI legs (DISPLAY only, else a partial skip): open -> .ase<N>
#          toplevel + title + populated panes; re-open raises (no new number);
#          widget edit -> dirty marker -> real-menu Save State; Design Window;
#          Netlist viewer; live-log Run (status Green); Stop (status red);
#          Close. Legs needing the MAIN window (W4-W7) self-SKIP when WSLg
#          never maps it to a usable size; W6/W7 self-SKIP without ngspice.
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_window.tcl
# (add DISPLAY for the GUI legs)

set fail 0; set npass 0
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

# first toplevel whose title is exactly $title (textwindow viewers), or {}
proc find_titled_toplevel {title} {
  foreach w [winfo children .] {
    if {[winfo class $w] ne {Toplevel}} continue
    if {![catch {wm title $w} t] && $t eq $title} { return $w }
  }
  return {}
}

# all .ase* session toplevels
proc ase_toplevels {} {
  set out {}
  foreach w [winfo children .] {
    if {[string match .ase* $w] && [winfo class $w] eq {Toplevel}} { lappend out $w }
  }
  return $out
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
set models  [file join $repo sky130A models libs.tech combined sky130.lib.spice]
set scratch [file normalize [file join [pwd] _ase_window_[pid]]]
file delete -force $scratch

# --- scratch lib/cell/view fixture + registry --------------------------------
# clean nfet schematic (the test_ase_core fixture: nfet_test_claude minus its
# corner + simulator_commands_shown instances)
set sch_text {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/vsource} 250 -300 0 0 {name=V2 value=1.8}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
}
file mkdir [file join $scratch aselib nfet_clean schematic]
set f [open [file join $scratch aselib nfet_clean schematic nfet_clean.sch] w]
puts -nonewline $f $sch_text
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]
set schpath [file normalize [file join $scratch aselib nfet_clean schematic nfet_clean.sch]]

if {[catch {

# seed the state view through the REAL creation backend, then shape the nfet
# fixture state (models/variables/outputs/options, rundir -> scratch) through
# the session procs + session_save — itself code under test
library_new_view aselib nfet_clean ngspice_state1 ngspice_state1
set spath [xschem cellview_path aselib/nfet_clean ngspice_state1]
if {$spath eq {}} { error "fixture: state view did not resolve" }
set spath [file normalize $spath]
set key [ase::session_key aselib nfet_clean ngspice_state1]

ase::session_open $key $spath
set st [ase::session_state $key]
dict set st rundir $rundir
dict set st models [list [list file $models section tt]]
dict set st variables {{name Vgs value 1.8} {name Vds value 1.0}}
dict set st outputs {{name id expr -i(v1) save 1 plot 0}}
dict set st options {{name savecurrents value 1}}
ase::session_update $key $st
ase::session_save $key
ase::session_close $key

# --- H1: session_open loads the seeded state ---------------------------------
ase::session_open $key $spath
set d [ase::state_get [ase::session_state $key] design]
check "H1 design lib"  [expr {[dict exists $d lib]  ? [dict get $d lib]  : {}}] aselib
check "H1 design cell" [expr {[dict exists $d cell] ? [dict get $d cell] : {}}] nfet_clean
check "H1 design view points at the schematic" \
  [expr {[dict exists $d view] ? [dict get $d view] : {}}] schematic
check "H1 fresh session not dirty" [ase::session_dirty $key] 0

# --- H2: update -> dirty; save -> file has the new value, clean --------------
set st [ase::session_state $key]
dict set st variables {{name Vgs value 2.5} {name Vds value 1.0}}
ase::session_update $key $st
check "H2 dirty after update" [ase::session_dirty $key] 1
ase::session_save $key
set f [open $spath r]; set sdata [read $f]; close $f
check_true "H2 saved file contains the new Vgs value" \
  [string match "*{name Vgs value 2.5}*" $sdata]
check "H2 clean after save" [ase::session_dirty $key] 0

# --- H3: revert restores saved; session_load re-reads disk -------------------
set st [ase::session_state $key]
dict set st variables {{name Vgs value 0.7} {name Vds value 1.0}}
ase::session_update $key $st
check "H3 dirty after second update" [ase::session_dirty $key] 1
ase::session_revert $key
check "H3 revert restores the saved variables" \
  [ase::state_get [ase::session_state $key] variables] \
  {{name Vgs value 2.5} {name Vds value 1.0}}
check "H3 clean after revert" [ase::session_dirty $key] 0
# write a different value straight to DISK (bypassing the session), then load
set st3 [ase::session_state $key]
dict set st3 variables {{name Vgs value 3.0} {name Vds value 1.0}}
ase::state_save $spath $st3
ase::session_load $key
check "H3 session_load re-reads the file from disk" \
  [ase::state_get [ase::session_state $key] variables] \
  {{name Vgs value 3.0} {name Vds value 1.0}}

# restore the fixture value for the GUI legs, save, drop the session
set st [ase::session_state $key]
dict set st variables {{name Vgs value 1.8} {name Vds value 1.0}}
ase::session_update $key $st
ase::session_save $key
ase::session_close $key

# --- H4: open_state contract -------------------------------------------------
check "H4 existing view -> 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
check_true "H4 session registered by open_state" \
  [expr {[ase::session_state $key] ne {}}]
set caught [catch {ase::open_state aselib nfet_clean nosuchview} r4]
check "H4 missing view throws no error" $caught 0
check "H4 missing view -> 0" $r4 0
# drop the H4 open so W1 exercises a fresh window build (GUI) / a fresh
# registration (headless)
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  ase::ui::close $key; update
} else {
  ase::session_close $key
}

# --- H5: allocate_window_number seam -----------------------------------------
set n1 [xschem allocate_window_number]
set n2 [xschem allocate_window_number]
check_true "H5 allocator returns integers" \
  [expr {[string is integer -strict $n1] && [string is integer -strict $n2]}]
check "H5 second call == first+1 (counter advances)" [expr {$n2 - $n1}] 1
check_true "H5 numbers start at/after the editor floor (>= 3)" [expr {$n1 >= 3}]

# --- H6: backend_names -------------------------------------------------------
check_true "H6 backend_names contains ngspice" \
  [expr {[lsearch -exact [ase::backend_names] ngspice] >= 0}]

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # W1: open -> one .ase<N> toplevel, titled, panes populated from the dict
  check "W1 open_state -> 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true "W1 window_for returns a live toplevel" \
    [expr {$top ne {} && [winfo exists $top]}]
  set wn -1
  check_true "W1 toplevel named .ase<N>" [regexp {^\.ase([0-9]+)$} $top -> wn]
  check "W1 title carries number, cell and view" [wm title $top] \
    "ASE-L ($wn) \u2014 aselib/nfet_clean \[ngspice_state1\]"
  set ve [ase::ui::variable_entry $key Vgs]
  check_true "W1 variables pane has a Vgs row" [expr {$ve ne {}}]
  check "W1 Vgs value entry shows the seeded value" \
    [expr {$ve ne {} ? [$ve get] : {}}] 1.8

  # W2: re-open raises the SAME window, consumes NO window number
  set p1 [xschem allocate_window_number]
  check "W2 re-open returns 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  check "W2 same toplevel" [ase::ui::window_for $key] $top
  check "W2 still exactly one .ase* toplevel" [llength [ase_toplevels]] 1
  set p2 [xschem allocate_window_number]
  check "W2 no number consumed by the re-open (delta == the probe only)" \
    [expr {$p2 - $p1}] 1

  # W3: edit through the widget (REAL Return commit), dirty marker, REAL menu
  # Save State
  set ve [ase::ui::variable_entry $key Vgs]
  # real sequence: focus enters the entry (a click would do this), the text is
  # replaced, Return commits. Key events are only dispatched to the focus
  # window, so focus first (keybind-test lesson).
  focus -force $ve
  update
  $ve delete 0 end
  $ve insert 0 2.2
  event generate $ve <Return>
  update
  check "W3 title gained the dirty marker" [string range [wm title $top] end-1 end] { *}
  check "W3 session dirty after widget commit" [ase::session_dirty $key] 1
  $top.mb.session invoke {Save State}
  update
  set f [open $spath r]; set sdata [read $f]; close $f
  check_true "W3 saved file contains the widget's value" \
    [string match "*{name Vgs value 2.2}*" $sdata]
  check_true "W3 dirty marker gone after save" \
    [expr {[string range [wm title $top] end-1 end] ne { *}}]
  check "W3 session clean after save" [ase::session_dirty $key] 0

  # W4-W7 need a usable MAIN window (design load / netlist / run)
  if {![main_ready]} {
    puts "SKIPPED: W4-W7 legs (WSLg geometry: main window never became usable)"
  } else {

    # W4: Design Window opens (or raises) the schematic
    $top.mb.session invoke {Design Window}
    update
    check "W4 design is now the current schematic" \
      [file normalize [xschem get schname]] $schpath
    set found 0
    foreach e [xschem windows] {
      if {[file normalize [lindex $e 4]] eq $schpath} { set found 1 }
    }
    check "W4 window list has the design schematic" $found 1

    # W5: Netlist button -> read-only textwindow on the netlist
    $top.bar.netlist invoke
    update
    set nlpath [file join $rundir nfet_clean.spice]
    set w5 [find_titled_toplevel $nlpath]
    check_true "W5 netlist textwindow opened (titled with the path)" \
      [expr {$w5 ne {}}]
    check_true "W5 netlist viewer shows the device line (XM1)" \
      [expr {$w5 ne {} && [string match "*XM1*" [$w5.text get 1.0 end]]}]
    if {$w5 ne {}} { destroy $w5; update }

    if {[auto_execok ngspice] eq {}} {
      puts "SKIPPED: W6/W7 run legs (ngspice not found)"
    } else {

      # W6: Run streams the log live into the pane, status Green on success
      $top.bar.run invoke
      set id6 [ase::session_getattr $key run_id]
      check_true "W6 run started (integer execute id)" \
        [string is integer -strict $id6]
      check "W6 status orange while running" \
        [$top.bar.status cget -background] orange
      ase::wait $id6
      update
      set wtxt [$top.log.t get 1.0 end]
      check_true "W6 log widget non-empty" [expr {[string trim $wtxt] ne {}}]
      check_true "W6 log widget has the Data Rows banner" \
        [string match "*No. of Data Rows*" $wtxt]
      check_true "W6 log widget has the -i(v1) result line" \
        [regexp -- {-i\(v1\)\s*=\s*[-+0-9.eE]+} $wtxt]
      check "W6 status light Green on success" \
        [$top.bar.status cget -background] Green
      set logf [file join $rundir nfet_clean_ase.log]
      check_true "W6 log file written in the scratch rundir" \
        [expr {[file isfile $logf] && [file size $logf] > 0}]

      # W7: Stop kills a long tran run -> nonzero exit, red status, clean pipe
      set st7 [ase::session_state $key]
      dict set st7 analyses {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 10s}}
      ase::session_update $key $st7
      $top.bar.run invoke
      set id7 [ase::session_getattr $key run_id]
      check_true "W7 long tran started" [string is integer -strict $id7]
      set got 0
      for {set i 0} {$i < 50} {incr i} {
        update
        if {[info exists ::execute(data,$id7)] && [string length $::execute(data,$id7)] > 0} {
          set got 1; break
        }
        after 100
      }
      check "W7 simulator produced output before Stop" $got 1
      $top.bar.stop invoke
      set ec7 [ase::wait $id7]
      update
      check_true "W7 nonzero exit after Stop" [expr {$ec7 != 0}]
      check "W7 status light red after Stop" \
        [$top.bar.status cget -background] red
      check_true "W7 execute pipe cleaned up" \
        [expr {![info exists ::execute(pipe,$id7)]}]
      # back to the op-only saved state
      ase::ui::revert_state $key
      check "W7 revert leaves the session clean" [ase::session_dirty $key] 0
    }
  }

  # W8: Session > Close destroys the window and unregisters the session
  $top.mb.session invoke Close
  update
  check_true "W8 toplevel destroyed" [expr {![winfo exists $top]}]
  check "W8 window_for now empty" [ase::ui::window_for $key] {}

} else {
  puts "gui legs skipped (no DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
catch {file delete -force $scratch}
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
