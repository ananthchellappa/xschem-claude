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
# --- issues 0688 + 0683 fixture: two cells in ONE lib, plus an annotator ------
# Rows L20-L25 drive issue 0688's five-step sequence through SANCTIONED doors
# only, so they need a design to open, a DIFFERENT design to open on top of it,
# and something that visibly annotates. `annotlib` is a flat library (like
# `devices`) so the probe symbol resolves under `library_registry_defs_only 1`.
file mkdir [file join $scratch annotlib]
set f [open [file join $scratch annotlib y_probe.sym] w]
puts $f "v {xschem version=3.4.7RC file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzs7probe\ntemplate=\"name=zp1\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 0 0 0 10 {}"
puts $f "T \{ZZL0688TEXT\} 5 5 0 0 0.2 0.2 \{layer=15\nhide=op\}"
close $f
foreach {cell inst} {y_dut YD1 y_other YO1} {
  file mkdir [file join $scratch aselib $cell schematic]
  set f [open [file join $scratch aselib $cell schematic $cell.sch] w]
  puts $f "v {xschem version=3.4.7RC file_version=1.2}"
  puts $f "G {}"
  puts $f "K {}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "N 250 -330 420 -330 {}"
  puts $f "C \{annotlib/y_probe\} 0 0 0 0 \{name=$inst\}"
  puts $f "C \{devices/lab_wire\} 330 -330 0 0 \{name=la lab=a\}"
  close $f
}
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE annotlib [file join $scratch annotlib]"
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

# ============================================================================
# L20-L25 — ISSUES 0688 + 0683: THE ORPHAN SEQUENCE, SANCTIONED DOORS ONLY
# ============================================================================
# The user's 2026-08-25 ruling on issue 0683 is "both stock items refuse without
# a bound session". A first attempt at it was reverted the same day because 0683
# is a LIFETIME problem, not an entry problem: `annot_show` is per-WINDOW while a
# session's only handle on its design is a CELLVIEW PATH, so an ordinary
# `File > Open` in the design window leaves the mask at 3 while every
# session-side reader answers 0 — the session-close clear and the ASE-L untick
# then BOTH no-op in exactly the state they exist for (issue 0688 §2/§3).
#
# These six rows are that transcript, run as a test. Every door is one a user
# actually has: `Tools > Launch ASE-L`, ASE-L's `Results > Annotate` (whose push
# half is `ase::ui::annot_apply`), `File > Open` (which is a bare `xschem load`
# — actions.csv:41 carries no -gui wrapper), and `Session > Close`.
#
#   L20  STEP 1  the sanctioned road WORKS         <- POSITIVE, green before
#   L21  STEP 1  the mask carries a root stamp     <- red before
#   L22  STEP 2  File > Open drops the annotation  <- red before
#   L23  STEP 3+4 untick, then Session > Close     <- red before
#   L24  STEP 5  reopen the cell: NO ORPHAN        <- red before
#   L25  the whole road still works afterwards     <- POSITIVE, green before
#
# ⚠ L20 AND L25 ARE NOT DECORATION. Every red row here is a NEGATIVE claim, and
# a patch that simply broke annotation would satisfy all four of them perfectly.
# That is the failure mode the 0682 crew's counterweight rule was written about,
# and the pair is the only thing that can tell "fixed" from "deleted".
#
# ⚠ `ase::ui::close` IS A NO-OP HEADLESS — it early-returns on
# `![dict exists $wins $key]` and --nogui never runs `ase::ui::open`. So
# `Session > Close` is driven through `ase::session_close`, which is the door
# that really tears the session down in both arms. A headless row that called
# only `ase::ui::close` and saw the mask unchanged would have measured nothing.

## Instance bbox WIDTH, or a marker. The `hide=op` probe measures 0 wide when
## bit0 is clear and ~57 when it is set; the number is a font metric and moves
## between --nogui and a display (test_op_annot section L measured the identical
## symbol at 63 headless and 64 on :99, because text_bbox goes through cairo's
## font metrics when a display exists), so no row here hardcodes it — they all
## ask "did it paint at all".
proc ase_annot_w {inst} {
  if {[catch {xschem instance_bbox $inst} r]} { return RAISED }
  if {![regexp {Instance: (\S+) (\S+) (\S+) (\S+)} $r -> a b c d]} { return NO-BBOX }
  return [expr {int($c - $a)}]
}
proc ase_paints {inst} {
  set w [ase_annot_w $inst]
  if {![string is integer -strict $w]} { return $w }
  return [expr {$w > 40 ? 1 : 0}]
}
proc ase_try {script} { if {[catch {uplevel #0 $script} r]} { return "<ERR:$r>" } ; return $r }

# a 1-point Operating Point raw carrying v(a) = 3.14 — the value issue 0688 §2's
# transcript names, so a reader can line the two up
set Y_RAW [file join $scratch y_op.raw]
set f [open $Y_RAW w]
puts -nonewline $f "Title: 0688 orphan fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(a)\tvoltage
\t1\tv(gnd)\tvoltage
Values:
0\t3.14
\t0.0
"
close $f
set Y_DUT   [file normalize [file join $scratch aselib y_dut   schematic y_dut.sch]]
set Y_OTHER [file normalize [file join $scratch aselib y_other schematic y_other.sch]]

# a clean slate: the L6-L8 and G1-G2 legs above must not leak a session in here
foreach _k [dict keys [set ::ase::sessions]] {
  catch {ase::ui::close $_k} ; catch {ase::session_close $_k}
}
catch {xschem set annot_show 0}

# --- L20: STEP 1 — annotate from ASE-L. THE SANCTIONED ROAD -----------------
set ::ASE_DEFAULT_MODELS $sky130_default
xschem load $Y_DUT
set yk [ase::launch_for_current]
set ::ase::ui::annot($yk,op)   1
set ::ase::ui::annot($yk,volt) 1
xschem set annot_show 3
catch {xschem annotate_op $Y_RAW}
xschem update_all_sym_bboxes
check "L20 POSITIVE the sanctioned road annotates: session + mask + numbers + paint" \
  [list [expr {$yk ne {} ? 1 : 0}] [dict size [set ::ase::sessions]] \
        [xschem get annot_show] [ase_try {ase::ui::annot_mask $yk}] \
        [ase_try {xschem raw value v(a) -1}] [ase_try {op_annot::_annotated}] \
        [ase_paints YD1]] \
  {1 1 3 3 3.14 1 1}

# --- L21: STEP 1 — the mask is stamped with the ROOT it was armed for -------
# Without a stamp there is nothing a later load can compare against, which is
# why the reverted attempt had to resolve session -> window and why `File > Open`
# defeated it. Both elements are needed: the second alone is satisfied by an
# accessor that always answers empty.
set yroot [ase_try {xschem get annot_root}]
check "L21 the armed mask carries the root sheet it was armed for" \
  [list [expr {$yroot eq [xschem get schname 0] ? 1 : 0}] \
        [expr {[string match {*y_dut.sch} $yroot] ? 1 : 0}]] \
  {1 1}

# --- L22: STEP 2 — File > Open another cell in the design window ------------
# `xschem load` IS File > Open (actions.csv:41 `file.open`, no -gui wrapper, so
# it loads in place). This is the exact step the previous crew measured at 3.
xschem load $Y_OTHER
xschem update_all_sym_bboxes
check "L22 0688 File > Open of another cell drops the annotation with it" \
  [list [xschem get annot_show] [ase_paints YO1]] {0 0}

# --- L23: STEP 3+4 — the ASE-L off switch, then Session > Close -------------
# In the measured BEFORE state annot_apply reaches `annot_goto_design`, gets {},
# echoes "cannot reach this session's design window" and the mask stays 3. After
# the fix there is nothing left for either door to clear, and that is the point:
# the mask went out with the sheet, not with the session.
set ::ase::ui::annot($yk,op)   0
set ::ase::ui::annot($yk,volt) 0
catch {ase::ui::annot_apply $yk op}
catch {ase::ui::annot_apply $yk volt}
catch {ase::ui::close $yk}
catch {ase::session_close $yk}
check "L23 untick + Session > Close leave nothing armed" \
  [list [dict size [set ::ase::sessions]] [xschem get annot_show]] {0 0}

# --- L24: STEP 5 — reopen the original cell. THE ORPHAN, INVERTED -----------
# ⚠ `op_annot::_annotated` IS DELIBERATELY NOT AN ELEMENT HERE, and that is a
# correction to the plan rather than an omission. Measured (src/op_annot.tcl:781)
# it reads `live_cursor2_backannotate`, `xschem raw loaded` and `xschem raw
# annot` — it never looks at the mask. The raw legitimately stays in the
# registry across a `File > Open` (a `xschem load` of the first sheet again
# re-associates it and answers 3.14), so `_annotated` is 1 here whatever the mask
# says. What the user complained about is NUMBERS ON THE SHEET, so the row reads
# the annotator's own bbox: 0 wide is nothing painting.
xschem load $Y_DUT
xschem update_all_sym_bboxes
check "L24 0688 reopening the cell finds no annotation, no session and nothing painting" \
  [list [xschem get annot_show] [ase_paints YD1] \
        [ase::session_for_current] [dict size [set ::ase::sessions]]] \
  {0 0 {} 0}

# --- L25: THE POSITIVE TWIN, AFTER THE WHOLE SEQUENCE -----------------------
# "Broke the feature and called it fixed" passes L22, L23 and L24 with full
# marks. It cannot pass this.
set yk2 [ase::launch_for_current]
set ::ase::ui::annot($yk2,op)   1
set ::ase::ui::annot($yk2,volt) 1
xschem set annot_show 3
catch {xschem annotate_op $Y_RAW}
xschem update_all_sym_bboxes
check "L25 POSITIVE relaunching ASE-L on the same cell annotates it again" \
  [list [expr {$yk2 ne {} ? 1 : 0}] [xschem get annot_show] \
        [ase_try {xschem raw value v(a) -1}] [ase_paints YD1]] \
  {1 3 3.14 1}

catch {ase::ui::close $yk2} ; catch {ase::session_close $yk2}
catch {xschem raw clear}
catch {xschem set annot_show 0}

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
