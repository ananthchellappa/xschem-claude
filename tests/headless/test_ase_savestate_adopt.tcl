# ASE-L untitled-session Save State ADOPT (issue 0141): saving a never-saved
# (Launch ASE-L) session via Session > Save State — with the window KEPT OPEN —
# must make the session adopt its first real identity: not dirty, not untitled,
# path set, the title's " (unsaved)"/" *" cues gone, the status bar showing the
# real "State: <view>". Before the fix, do_save_state_as wrote the state FILE
# but never updated saved/untitled/path/meta, so the still-open window kept
# showing modified — the reported bug.
#
#   AD1-AD9   PART A (headless, runs everywhere; the primary RED signal): drive
#             the worker ase::ui::do_save_state_as directly (== the menu path,
#             no close). Pre: untitled + dirty + no path. Post: adopted (clean,
#             titled, path set, disk carries this session's serialization) and
#             a second same-view save is the clean own-view path (idempotent).
#   AD10-AD18 PART B (DISPLAY-guarded, self-SKIPs under --nogui / no usable main
#             window): the open-window title + status reproduction. Drives the
#             REAL menu "Save State" dialog with the window kept open, asserts
#             the "(unsaved)"/"*" cues clear and "State: <view>" appears, then
#             a clean close still tears the window down (re-key safety).
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_savestate_adopt.tcl
# (add DISPLAY for the Part B GUI legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# wait for a real, mapped main canvas (WSLg can be slow); 0 => caller SKIPs
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

# drain WSLg between window churn (pumps the event loop WHILE yielding real time)
proc settle {{ms 60}} {
  update idletasks
  set ::_settle_done 0
  after $ms [list set ::_settle_done 1]
  vwait ::_settle_done
  update
}

# make a session dirty with a distinct variable set
proc make_dirty {key} {
  set st [ase::session_state $key]
  dict set st variables {{name Vgs value 1.8} {name Vds value 1.0}}
  ase::session_update $key $st
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
set scratch [file normalize [file join [pwd] _ase_adopt_[pid]]]
file delete -force $scratch

# --- scratch lib/cell fixture + registry (NO state view pre-created: the save
#     must hit the missing-view creation arm) ---------------------------------
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

set skipped 0
if {[catch {

  # --- PART A: headless core (primary RED signal; runs with or without X) -----
  set uk [ase::new_session aselib nfet_clean schematic]
  make_dirty $uk

  # pre-state (green today): a fresh untitled launch session is dirty + untitled
  check "AD1 pre: untitled attr set"  [ase::session_getattr $uk untitled 0] 1
  check "AD2 pre: session dirty"       [ase::session_dirty $uk] 1
  check "AD3 pre: no session path yet" [ase::session_path $uk] {}
  check_true "AD4 pre: target view does not exist yet" \
    [expr {[xschem cellview_path aselib/nfet_clean ngspice_state1] eq {}}]

  # drive the worker directly == menu Save State path, window untouched, no close
  set r [ase::ui::do_save_state_as $uk aselib nfet_clean ngspice_state1]
  check "AD5 worker returned success" $r 1

  # resolve the session re-key-agnostically (session_for_design keys on design)
  set nk [ase::session_for_design aselib nfet_clean schematic]
  check_true "AD6 session still resolvable after adopt" [expr {$nk ne {}}]

  # post-adopt (all RED before the fix)
  check "AD7 adopt cleared dirty"     [ase::session_dirty $nk] 0
  check "AD8 adopt cleared untitled"  [ase::session_getattr $nk untitled 0] 0
  check_true "AD9 adopt set the path" [expr {[ase::session_path $nk] ne {}}]
  set created [xschem cellview_path aselib/nfet_clean ngspice_state1]
  check_true "AD9b adopted path == created view file" \
    [expr {[file normalize [ase::session_path $nk]] eq [file normalize $created]}]
  set fh [open [ase::session_path $nk] r]; set disk [read $fh]; close $fh
  check "AD9c created file carries this session's serialization" \
    $disk "[ase::state_serialize [ase::session_state $nk]]\n"

  # idempotence: path is set now, so the NEXT save is the clean own-view arm
  set r2 [ase::ui::do_save_state_as $nk aselib nfet_clean ngspice_state1]
  check "AD9d second same-view save ok"   $r2 1
  check "AD9e still clean after re-save"   [ase::session_dirty $nk] 0

  # tidy up the headless session before the GUI block
  ase::session_close $nk

  # --- PART B: open-window GUI reproduction (DISPLAY-guarded) ------------------
  if {[info exists ::has_x] && [info commands winfo] ne {}} {
   if {![main_ready]} {
    puts "SKIPPED: AD10-AD18 (WSLg geometry: main window never became usable)"
    set skipped 1
   } else {
    set uk2 [ase::new_session aselib nfet_clean schematic]
    ase::ui::open $uk2 aselib nfet_clean [set ::ase::untitled_view]
    update
    set top [ase::ui::window_for $uk2]
    check_true "AD10 untitled window up" [expr {$top ne {} && [winfo exists $top]}]
    make_dirty $uk2
    ase::ui::refresh_title $uk2
    ase::ui::refresh_status $uk2
    update

    # pre-cues on the still-open window (green today)
    check_true "AD11 pre: title carries (unsaved)" \
      [string match {*(unsaved)*} [wm title $top]]
    check_true "AD12 pre: title carries the * dirty marker" \
      [expr {[string range [wm title $top] end-1 end] eq { *}}]
    check_true "AD13 pre: status shows State: (unsaved)" \
      [string match {*State: (unsaved)*} [ase::ui::status_text $uk2]]

    # drive the REAL menu Save State dialog; window KEPT OPEN (no close_request)
    $top.mb.session invoke {Save State}
    set saw 0
    for {set i 0} {$i < 100} {incr i} {
      update
      if {[winfo exists $top.saveas]} { set saw 1; break }
      settle 20
    }
    check_true "AD14 Save State dialog appeared" $saw
    if {$saw} {
      $top.saveas.view delete 0 end
      $top.saveas.view insert 0 ngspice_state1
      $top.saveas.btns.proceed invoke
      for {set i 0} {$i < 100} {incr i} {
        update
        if {![winfo exists $top.saveas]} break
        settle 20
      }
    }

    set nk2 [ase::session_for_design aselib nfet_clean schematic]
    check_true "AD15 window still open after menu Save State" [winfo exists $top]
    check "AD15b session clean after menu Save State" [ase::session_dirty $nk2] 0
    check "AD15c session no longer untitled" [ase::session_getattr $nk2 untitled 0] 0
    check_true "AD16 title dropped (unsaved)" \
      [expr {![string match {*(unsaved)*} [wm title $top]]}]
    check_true "AD16b title dropped the * marker" \
      [expr {[string range [wm title $top] end-1 end] ne { *}}]
    check_true "AD17 status shows real State: ngspice_state1" \
      [string match {*State: ngspice_state1*} [ase::ui::status_text $nk2]]
    check_true "AD17b status no longer (unsaved)" \
      [expr {![string match {*(unsaved)*} [ase::ui::status_text $nk2]]}]

    # re-key safety: session is clean, so close is a straight teardown — the
    # window must still be reachable/destroyable (a re-keying fix that left
    # close_request wired to the stale key would fail this)
    ase::ui::close_request $nk2
    update
    check_true "AD18 clean close after adopt tears the window down" \
      [expr {![winfo exists $top]}]
   }
  } else {
    puts "gui legs skipped (no DISPLAY)"
  }

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "  $::errorInfo"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
catch {file delete -force $scratch}
if {$fail == 0 && $skipped} {
  puts "RESULT: SKIP (ASE adopt GUI legs need a usable display; headless core passed)"
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
