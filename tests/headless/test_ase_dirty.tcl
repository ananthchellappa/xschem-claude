# ASE-L save-on-close prompt (item 16 of doc/claude/ase_l_batch, spec
# doc/claude/specs/ase_l.md "Menu tree (v2)" > Session > Close/Save State):
# opening a state view, editing it, then closing the ASE window (or quitting
# xschem) must offer a Cadence/ask_save-style Yes/No/Cancel "save changes?"
# prompt for any DIRTY session.
#
#   DR1-DR3  wiring: the two user close entry points (menu Close, WM_DELETE)
#            and Ctrl-W all route through ase::ui::close_request.
#   DR4      the REAL yes/no/cancel prompt appears on a dirty close (best-effort
#            under WSLg; self-SKIPs this ONE leg on a dialog stall).
#   DR5-DR11 decision flow with ask_save_close STUBBED (the sanctioned modal
#            idiom, cf. test_hier_walkup.tcl:45 stubbing ask_save): unedited ->
#            no prompt; Cancel keeps window+state; No discards+closes; Yes ->
#            REAL Save-As (own view / untitled new view / RO -> different view);
#            a cancelled Save-As aborts the close.
#   DR12-14  the xschem-quit sweep (prompt_all_on_quit): Cancel aborts the quit,
#            No proceeds, and it is a no-op (returns 1) with no ASE window open.
#
# The prompt behavior is entirely GUI (windows/dialogs), so the whole DR block
# is DISPLAY-guarded and self-SKIPs (RESULT: SKIP) under --nogui / no usable
# main window. Every dialog is driven by INVOKING buttons directly (no
# generated key events), so it is WSLg-robust without send_return.
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dirty.tcl
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

# --- DR-leg helpers ----------------------------------------------------------
# A distinct dirty state EVERY call: Vgs 9.9 (DR8's on-disk witness) plus a
# UNIQUE second variable name, so the session is reliably dirty even after an
# earlier leg saved a make_dirty state to the same view's disk (strengthens the
# prompt's fixed make_dirty; see receipt deviation note).
set ::dirtyctr 0
proc make_dirty {key} {
  set st [ase::session_state $key]
  dict set st variables [list [list name Vgs value 9.9] \
                              [list name Vd$::dirtyctr value 1]]
  incr ::dirtyctr
  ase::session_update $key $st
}

# after-poller that drives the modeless Save-As during save_state_modal's
# tkwait: proceed (optionally retargeting the View field) or cancel.
proc drive_saveas {top view action} {
  if {[winfo exists $top.saveas]} {
    set ::saveas_seen 1
    if {$action eq {proceed}} {
      if {$view ne {}} {
        $top.saveas.view delete 0 end; $top.saveas.view insert 0 $view
      }
      $top.saveas.btns.proceed invoke
    } else {
      $top.saveas.btns.cancel invoke
    }
    return
  }
  after 30 [list drive_saveas $top $view $action]
}

# DR4 after-poller for the REAL yes/no/cancel prompt: record the dialog facts
# then Cancel it (so the close aborts). Bounded so a WSLg dialog stall cannot
# hang the close's tkwait — on timeout it force-destroys and reports dr4_seen 0.
proc dr4_poll {top n} {
  if {[winfo exists $top.askclose]} {
    set ::dr4_seen 1
    set ::dr4_yes    [winfo exists $top.askclose.btns.yes]
    set ::dr4_no     [winfo exists $top.askclose.btns.no]
    set ::dr4_cancel [winfo exists $top.askclose.btns.cancel]
    catch {set ::dr4_bg [$top.askclose cget -background]}
    # Cancel in a LATER event cycle: this poller can fire during
    # ask_save_close's own build-time `update` (before it reaches tkwait), so
    # invoking Cancel synchronously here would destroy the dialog mid-build and
    # break its raise/grab/focus. A fresh timer fires only once tkwait is
    # looping.
    after 30 [list dr4_cancel $top]
    return
  }
  if {$n <= 0} { set ::dr4_seen 0; catch {destroy $top.askclose}; return }
  after 30 [list dr4_poll $top [expr {$n - 1}]]
}
proc dr4_cancel {top} {
  if {[winfo exists $top.askclose.btns.cancel]} {
    $top.askclose.btns.cancel invoke
  } elseif {[winfo exists $top.askclose]} {
    catch {destroy $top.askclose}
  }
}

# Tear down any open ngspice_state1 session window, then re-open it fresh from
# disk (the reloaded saved-state is the new clean baseline). Returns the key.
proc fresh {{ro 0}} {
  set k [ase::session_key aselib nfet_clean ngspice_state1]
  if {[ase::ui::window_for $k] ne {}} { ase::ui::close $k }
  update
  ase::open_state aselib nfet_clean ngspice_state1 $ro
  update
  return $k
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
set models  [file join $repo sky130A models libs.tech combined sky130.lib.spice]
set scratch [file normalize [file join [pwd] _ase_dirty_[pid]]]
file delete -force $scratch

# --- scratch lib/cell/view fixture + registry --------------------------------
# clean nfet schematic (the test_ase_window fixture)
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

set skipped 0
if {[catch {

# seed the state view through the REAL creation backend, then shape + save it
library_new_view aselib nfet_clean ngspice_state1 ngspice_state1
set spath [xschem cellview_path aselib/nfet_clean ngspice_state1]
if {$spath eq {}} { error "fixture: state view did not resolve" }
set spath [file normalize $spath]
set key0 [ase::session_key aselib nfet_clean ngspice_state1]
ase::session_open $key0 $spath
set st [ase::session_state $key0]
dict set st rundir $rundir
dict set st models [list [list file $models section tt]]
dict set st variables {{name Vgs value 1.8} {name Vds value 1.0}}
dict set st outputs {{name id expr -i(v1) save 1 plot 0}}
dict set st options {{name savecurrents value 1}}
ase::session_update $key0 $st
ase::session_save $key0
ase::session_close $key0

# --- GUI legs (DISPLAY-guarded; whole block SKIPs when no usable display) -----
if {[info exists ::has_x] && [info commands winfo] ne {}} {
 if {![main_ready]} {
  puts "SKIPPED: all DR legs (WSLg geometry: main window never became usable)"
  set skipped 1
 } else {

  # --- DR1-DR3: the user close entry points route through close_request ------
  check "DR0 open_state -> 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set key [ase::session_key aselib nfet_clean ngspice_state1]
  set top [ase::ui::window_for $key]
  check_true "DR0 session window up" [expr {$top ne {} && [winfo exists $top]}]
  check "DR1 menu Close wired to close_request" \
    [$top.mb.session entrycget Close -command] [list ase::ui::close_request $key]
  check "DR2 WM_DELETE wired to close_request" \
    [wm protocol $top WM_DELETE_WINDOW] [list ase::ui::close_request $key]
  check_true "DR3 Ctrl-W bound to close_request" \
    [string match *close_request* [bind $top <Control-w>]]

  # --- DR4: the REAL prompt appears (best-effort; BEFORE the stub) -----------
  make_dirty $key
  set ::dr4_seen -1; set ::dr4_yes 0; set ::dr4_no 0; set ::dr4_cancel 0
  set ::dr4_bg {}
  after 30 [list dr4_poll $top 200]
  ase::ui::close_request $key
  update
  if {$::dr4_seen == 1} {
    check_true "DR4 real prompt dialog appeared" $::dr4_seen
    check_true "DR4 prompt has Yes/No/Cancel buttons" \
      [expr {$::dr4_yes && $::dr4_no && $::dr4_cancel}]
    check "DR4 prompt wears the ASE panel background" $::dr4_bg [ase::theme panel]
    check_true "DR4 Cancel kept the session window (survived)" [winfo exists $top]
  } else {
    puts "SKIPPED: DR4 (WSLg dialog stall)"
  }

  # stub the modal prompt for the decision-flow legs (keep save_state_modal /
  # save_state_dialog / prompt_all_on_quit REAL). askc counts invocations.
  proc ase::ui::ask_save_close {key} { incr ::askc; return $::askans }

  # --- DR5: unedited (clean) close -> NO prompt ------------------------------
  set key [fresh 0]
  set top [ase::ui::window_for $key]
  set ::askc 0; set ::askans {}
  ase::ui::close_request $key
  update
  check "DR5 clean close: no prompt (askc 0)" $::askc 0
  check_true "DR5 clean session closed" [expr {![winfo exists $top]}]
  check "DR5 clean session unregistered" [ase::session_state $key] {}

  # --- DR6: Cancel keeps window + state intact -------------------------------
  set key [fresh 0]
  set top [ase::ui::window_for $key]
  make_dirty $key
  set snap [ase::state_serialize [ase::session_state $key]]
  set ::askc 0; set ::askans {}
  ase::ui::close_request $key
  update
  check "DR6 Cancel: prompt shown (askc 1)" $::askc 1
  check_true "DR6 Cancel: window survives" [winfo exists $top]
  check_true "DR6 Cancel: session still registered" \
    [expr {[ase::session_state $key] ne {}}]
  check "DR6 Cancel: still dirty" [ase::session_dirty $key] 1
  check "DR6 Cancel: state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # --- DR7: No -> discard + close (continue the DR6 dirty session) -----------
  set ::askans no
  ase::ui::close_request $key
  update
  check_true "DR7 No: window gone" [expr {![winfo exists $top]}]
  check "DR7 No: session unregistered" [ase::session_state $key] {}

  # --- DR8: Yes + save completes -> saved + closed (own view) ----------------
  set key [fresh 0]
  set top [ase::ui::window_for $key]
  make_dirty $key
  set ::askans yes; set ::saveas_seen 0
  after 30 [list drive_saveas $top {} proceed]
  ase::ui::close_request $key
  update
  check "DR8 Yes: real Save-As ran" $::saveas_seen 1
  check_true "DR8 Yes: window closed after a completed save" \
    [expr {![winfo exists $top]}]
  set fh [open $spath r]; set disk [read $fh]; close $fh
  check_true "DR8 Yes: saved state file now carries Vgs 9.9" \
    [string match "*{name Vgs value 9.9}*" $disk]

  # --- DR9: Yes on an UNTITLED session -> Save-As creates the view -----------
  set uk [ase::new_session aselib nfet_clean schematic]
  ase::ui::open $uk aselib nfet_clean [set ::ase::untitled_view]
  update
  set utop [ase::ui::window_for $uk]
  check_true "DR9 untitled window up" [expr {$utop ne {} && [winfo exists $utop]}]
  make_dirty $uk
  set ::askans yes; set ::saveas_seen 0
  after 30 [list drive_saveas $utop ngspice_dirty1 proceed]
  ase::ui::close_request $uk
  update
  set dirtyview [file join $scratch aselib nfet_clean ngspice_dirty1 nfet_clean.state]
  check "DR9 Yes: real Save-As ran" $::saveas_seen 1
  check_true "DR9 Yes: Save-As created the new view file" [file exists $dirtyview]
  check_true "DR9 Yes: untitled window gone" [expr {![winfo exists $utop]}]

  # --- DR10: Yes on a READ-ONLY session -> Save-As, RO file untouched --------
  set key [fresh 1]
  set top [ase::ui::window_for $key]
  make_dirty $key
  set ro_mtime [file mtime $spath]
  set ::askans yes; set ::saveas_seen 0
  after 30 [list drive_saveas $top ngspice_ro1 proceed]
  ase::ui::close_request $key
  update
  set roview [file join $scratch aselib nfet_clean ngspice_ro1 nfet_clean.state]
  check "DR10 RO Yes: real Save-As ran" $::saveas_seen 1
  check_true "DR10 RO Yes: the NEW view was created" [file exists $roview]
  check "DR10 RO Yes: the read-only source file was never written (mtime)" \
    [file mtime $spath] $ro_mtime

  # --- DR11: Yes + Save-As cancelled -> abort the close ----------------------
  set key [fresh 0]
  set top [ase::ui::window_for $key]
  make_dirty $key
  set ::askans yes; set ::saveas_seen 0
  after 30 [list drive_saveas $top {} cancel]
  ase::ui::close_request $key
  update
  check "DR11 Yes+cancel: Save-As was shown" $::saveas_seen 1
  check_true "DR11 Yes+cancel: window SURVIVES (abort)" [winfo exists $top]
  check "DR11 Yes+cancel: still dirty" [ase::session_dirty $key] 1

  # --- DR12: quit sweep, Cancel aborts the whole quit ------------------------
  set key [fresh 0]
  set top [ase::ui::window_for $key]
  make_dirty $key
  set ::askans {}
  set r [ase::ui::prompt_all_on_quit]
  update
  check "DR12 quit Cancel returns 0" $r 0
  check_true "DR12 quit Cancel: session window survives" [winfo exists $top]
  check "DR12 quit Cancel: still dirty" [ase::session_dirty $key] 1

  # --- DR13: quit sweep, No proceeds + closes (same session) -----------------
  set ::askans no
  set r [ase::ui::prompt_all_on_quit]
  update
  check "DR13 quit No returns 1" $r 1
  check_true "DR13 quit No: session window gone" [expr {![winfo exists $top]}]
  check "DR13 quit No: session unregistered" [ase::session_state $key] {}

  # --- DR14: quit sweep is a no-op with no ASE window open -------------------
  check "DR14 no ASE windows remain" [dict size [set ::ase::ui::wins]] 0
  set ::askc 0
  check "DR14 quit no-op with no ASE windows -> 1" [ase::ui::prompt_all_on_quit] 1
  check "DR14 no prompt fired (askc unchanged)" $::askc 0

 }
} else {
  puts "gui legs skipped (no DISPLAY)"
  set skipped 1
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "  $::errorInfo"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
catch {file delete -force $scratch}
if {$fail == 0 && $skipped} {
  puts "RESULT: SKIP (ASE dirty-prompt GUI legs need a usable display)"
  flush stdout
  exit 0
}
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
