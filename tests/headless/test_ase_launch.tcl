# ASE-L "Tools > Launch ASE-L" — item 15 of doc/claude/ase_l_batch (spec
# doc/claude/specs/ase_l.md "Menu tree (v2)" + item-02 view creation). A hosted
# technology (sky130A/gf180mcuD) preloads a DEFAULT MODEL set via
# ::ASE_DEFAULT_MODELS; a schematic window's Tools > Launch ASE-L opens a FRESH
# minimal ASE-L session (empty vars/analyses/outputs, tech default models in
# place) bound to the current schematic — like Cadence Tools > ADE-L. Launching
# twice on the same design RAISES the existing session instead of duplicating.
#
#   L1-L3  ase::design_of_path resolver: .sch -> {lib cell view}; symbol / bogus
#          path -> clean error (schematic-only extension guard)
#   L4-L5  ase::state_default honors ::ASE_DEFAULT_MODELS (set -> present via the
#          info-exists guard; unset -> {} with no throw)
#   L6     ase::launch_for_current registers a fresh untitled session bound to
#          the current schematic (default models, empty vars/outputs, not dirty)
#   L7     a second launch RAISES: same key, no duplicate session
#   L8     a symbol current view -> launch returns {}, registers no session
#   G1-G2  GUI legs (DISPLAY only): the real Tools menu entry opens exactly one
#          .ase toplevel with the sky130 default models + empty panes + the
#          `(unsaved)` title/status; a second menu invoke raises, no duplicate
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_launch.tcl
# (add DISPLAY for the GUI legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

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
source [file join $here scratch.tcl]
set scratch [test_scratch ase_launch]

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
# a real (minimal, valid) symbol view for the L8 "symbol current view" leg
file mkdir [file join $scratch aselib nfet_clean symbol]
set f [open [file join $scratch aselib nfet_clean symbol nfet_clean.sym] w]
puts -nonewline $f "v {xschem version=3.4.7RC file_version=1.2}\nG {}\nK {type=subcircuit}\nV {}\nS {}\nE {}\n"
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set schpath [file normalize [file join $scratch aselib nfet_clean schematic nfet_clean.sch]]
set sympath [file normalize [file join $scratch aselib nfet_clean symbol nfet_clean.sym]]
# the sky130 portable default-model literal the workarea rc installs
set sky130_default [list [list file {$::SKYWATER_MODELS/sky130.lib.spice} section tt]]
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]

if {[catch {

# --- L1: resolver maps a .sch path to {lib cell view} ------------------------
check "L1 design_of_path .sch -> {lib cell view}" \
  [ase::design_of_path $schpath] {aselib nfet_clean schematic}

# --- L2: resolver refuses a symbol path (extension guard, path need not exist)-
check "L2 design_of_path on a .sym throws" \
  [catch {ase::design_of_path $sympath}] 1

# --- L3: resolver refuses a path outside every registered library ------------
check "L3 design_of_path outside any library throws" \
  [catch {ase::design_of_path /nope/foo/bar.sch}] 1

# --- L4: state_default honors ::ASE_DEFAULT_MODELS when set ------------------
set ::ASE_DEFAULT_MODELS $sky130_default
check "L4 state_default models == ::ASE_DEFAULT_MODELS" \
  [dict get [ase::state_default] models] $::ASE_DEFAULT_MODELS

# --- L5: state_default's info-exists guard: unset -> {}, no throw ------------
unset ::ASE_DEFAULT_MODELS
set caught5 [catch {dict get [ase::state_default] models} m5]
check "L5 state_default with the global unset does not throw" $caught5 0
check "L5 state_default models == {} when the global is unset" $m5 {}
set_ne ASE_DEFAULT_MODELS {}

# --- L6: launch registers a fresh untitled session for the current schematic -
# force the pure headless launch path (temporarily hide ::has_x) so L6/L7 test
# the session MODEL identically with or without DISPLAY and build no window here
# (WSLg flake reduction) — G1/G2 cover the real window + menu wiring under X.
set ::ASE_DEFAULT_MODELS $sky130_default
xschem load $schpath
set had_x [info exists ::has_x]
if {$had_x} { set _saved_has_x $::has_x; unset ::has_x }
set k [ase::launch_for_current]
check_true "L6 launch returns a session key" [expr {$k ne {}}]
set st6 [ase::session_state $k]
check "L6 session models == ::ASE_DEFAULT_MODELS" \
  [ase::state_get $st6 models] $::ASE_DEFAULT_MODELS
check "L6 session variables empty" [ase::state_get $st6 variables] {}
check "L6 session outputs empty" [ase::state_get $st6 outputs] {}
check "L6 fresh untitled session is NOT dirty" [ase::session_dirty $k] 0
set d6 [ase::state_get $st6 design]
check "L6 session design bound to the schematic" \
  [list [dict get $d6 lib] [dict get $d6 cell] [dict get $d6 view]] \
  {aselib nfet_clean schematic}

# --- L7: second launch RAISES (same key, no duplicate session) ---------------
set n_before [dict size [set ::ase::sessions]]
set k2 [ase::launch_for_current]
check "L7 second launch returns the SAME key" $k2 $k
check "L7 second launch created no new session" \
  [dict size [set ::ase::sessions]] $n_before
check "L7 session_for_design resolves the single entry" \
  [ase::session_for_design aselib nfet_clean schematic] $k
# the RAISE arm must not RECREATE the session. The untitled key is deterministic,
# so a bare re-new_session would overwrite the SAME key (key identity + session
# count alone cannot tell raise from recreate). Edit the session, relaunch, and
# confirm the edit SURVIVES — a recreate via new_session resets state to the
# default, so this is what actually distinguishes raise from duplicate.
set st_e [ase::session_state $k]
dict set st_e variables {{name Vgs value 1.8}}
ase::session_update $k $st_e
check "L7 session dirty after an edit" [ase::session_dirty $k] 1
set k3 [ase::launch_for_current]
check "L7 relaunch returns the same key" $k3 $k
check "L7 relaunch PRESERVES the edit (raise, not recreate)" \
  [ase::state_get [ase::session_state $k] variables] {{name Vgs value 1.8}}
check "L7 relaunch keeps the session dirty (not reset)" [ase::session_dirty $k] 1
if {$had_x} { set ::has_x $_saved_has_x }
# drop the model-only session before the symbol / GUI legs
ase::session_close $k

# --- L8: a symbol current view -> launch returns {}, registers nothing -------
xschem load $sympath
check_true "L8 current view is a .sym" [string match {*.sym} [xschem get schname]]
set n8 [dict size [set ::ase::sessions]]
set k8 [ase::launch_for_current]
check "L8 launch on a symbol view -> {}" $k8 {}
check "L8 symbol launch registered no session" \
  [dict size [set ::ase::sessions]] $n8

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {} && [winfo exists .menubar.tools]} {

  # G1: the real Tools menu entry launches a fresh session window
  set ::ASE_DEFAULT_MODELS $sky130_default
  xschem load $schpath
  update
  .menubar.tools invoke [.menubar.tools index "Launch ASE-L"]
  update
  check "G1 exactly one ASE toplevel after the menu launch" \
    [llength [ase_toplevels]] 1
  set key [ase::session_for_design aselib nfet_clean schematic]
  check_true "G1 a session is registered for the design" [expr {$key ne {}}]
  set gst [ase::session_state $key]
  check "G1 session models == sky130 default" \
    [ase::state_get $gst models] $sky130_default
  check "G1 session variables empty" [ase::state_get $gst variables] {}
  check "G1 session outputs empty" [ase::state_get $gst outputs] {}
  check "G1 untouched launch is NOT dirty" [ase::session_dirty $key] 0
  set top [ase::ui::window_for $key]
  check_true "G1 window_for returns a live toplevel" \
    [expr {$top ne {} && [winfo exists $top]}]
  check "G1 analyses pane shows the 4 state_default rows" \
    [llength [$top.body.ana.tv children {}]] 4
  check "G1 variables pane empty" [llength [$top.body.vars.tv children {}]] 0
  check "G1 outputs pane empty" [llength [$top.body.outs.tv children {}]] 0
  check_true "G1 status bar shows State: (unsaved)" \
    [string match {*State: (unsaved)*} [ase::ui::status_text $key]]
  check_true "G1 title carries the (unsaved) cue" \
    [string match {*(unsaved)*} [wm title $top]]

  # G2: a second menu invoke RAISES the same window (no duplicate, no new num)
  set g_sessions [dict size [set ::ase::sessions]]
  set g_top [ase::ui::window_for $key]
  .menubar.tools invoke [.menubar.tools index "Launch ASE-L"]
  update
  check "G2 still exactly one ASE toplevel (raise, no duplicate)" \
    [llength [ase_toplevels]] 1
  check "G2 second launch resolves the SAME session key" \
    [ase::session_for_design aselib nfet_clean schematic] $key
  check "G2 no new session created" [dict size [set ::ase::sessions]] $g_sessions
  check "G2 same toplevel (no new window consumed)" \
    [ase::ui::window_for $key] $g_top

  ase::ui::close $key; update

} else {
  puts "gui legs skipped (no DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr\n$::errorInfo"
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
