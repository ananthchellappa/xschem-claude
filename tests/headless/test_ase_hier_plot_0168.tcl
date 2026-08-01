# Direct Plot (Ctrl-4 / Results > Direct Plot) did not work from a DESCENDED
# schematic (issue 0168).
#
# Issue 0161 taught the PICK to name a descended node the way the simulator does
# (`v(x1.x2.mid)`), but the entry points never got there: `ase::direct_plot_for_current`
# resolves the session with `design_of_current` + `session_for_design`, and
# `design_of_current` reads `xschem get schname` -- the CHILD once descended. The
# child cell has no ASE-L session, so every descended Ctrl-4 died on
#     ase: no ASE-L session for this design -- Launch ASE-L (Tools menu) or ...
# even though the parent's session (the one that ran the simulation) was right there
# one level up. Results > Direct Plot from the ASE window had the mirror-image bug:
# `raise_design_editor` matches a window by its CURRENT schematic name only, so a
# window descended into the design was invisible to it and `design_window` re-opened
# the top elsewhere, throwing away the hierarchy the user had navigated to.
#
# The fix walks the hierarchy stack:
#   ase::session_for_current      -- current level UP to the top, first ancestor
#                                    whose {lib cell view} has a session wins;
#                                    returns {key level lib cell view}
#   ase::ui::sod_base_level       -- where THAT session's design sits in the stack
#   ase::ui::sod_qualify ... base -- names are measured from the session's level,
#                                    not blindly from the window's top
#   xschem resolved_net net ?lvl? -- the C half of the above (new optional arg)
#   xschem windows                -- new 7th field: the window's hierarchy stack
#
# Legs (HL*):
#   HL1-HL6    ase::session_for_current: top (control), depth 1, depth 2, no
#              session at all, non-schematic view, nearest-ancestor preference.
#   HL7-HL12   the four entry points reach the ancestor session while descended.
#   HL13-HL18  base-level-relative qualification (Tcl side).
#   HL19-HL22  `xschem resolved_net net ?level?` (C side) + `xschem windows` stack.
#   HL23-HL25  raise_design_editor / design_window see a DESCENDED window.
#   HL26-HL27  a real descended pick queues the ancestor-relative expression.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_hier_plot_0168.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## call a possibly-missing proc without aborting the file (RED-first)
proc pcall {script} {
  if {[catch {uplevel #0 $script} r]} { return "ERR: $r" }
  return $r
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set fixdir  [file join $here fixtures ase_hier]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_hier_plot_0168]

# --- fixture: the 0161 3-level hierarchy (top -> x1:mid -> x2:leaf). The top and
# the mid are copied into a REGISTERED (flat-layout) library so `ase::design_of_path`
# resolves them to a {lib cell view} and a session can be bound to either. The LEAF
# is deliberately left in the plain fixture dir, OUTSIDE every registered library:
# the deepest level of the stack then resolves to nothing, which is what proves the
# ancestor walk skips an unregistered level instead of giving up on it.
set hierlib [file join $scratch hierlib]
file mkdir $hierlib
foreach n {ase_hier_top.sch ase_hier_mid.sch ase_hier_mid.sym} {
  file copy -force -- [file join $fixdir $n] $hierlib
}
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE hierlib $hierlib"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
## NOTE: assign XSCHEM_LIBRARY_PATH **unqualified**. The write trace that rebuilds
## `pathlist` (trace_set_vars, src/xschem.tcl) compares the name it is handed
## against the bare string "XSCHEM_LIBRARY_PATH", and a `set ::XSCHEM_LIBRARY_PATH`
## hands it "::XSCHEM_LIBRARY_PATH" -- the trace then silently does nothing and the
## bare-name symbol refs in this fixture never resolve.
set XSCHEM_LIBRARY_PATH "$hierlib:$fixdir:$XSCHEM_LIBRARY_PATH"

set toppath [file normalize [file join $hierlib ase_hier_top.sch]]
set midpath [file normalize [file join $hierlib ase_hier_mid.sch]]

# capture the CIW notices the entry points emit
set ::notices {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg }
proc notices_match {pat} {
  foreach m $::notices { if {[string match $pat $m]} { return 1 } }
  return 0
}

if {[catch {

xschem load $toppath
check "HL0 fixture: the top resolves to a registered cellview" \
  [pcall {ase::design_of_path $toppath}] {hierlib ase_hier_top schematic}

# --- HL1-HL6  ase::session_for_current ----------------------------------------
set topkey [ase::new_session hierlib ase_hier_top schematic]

check "HL1 (control) at the top the session resolves at level 0" \
  [pcall {ase::session_for_current}] [list $topkey 0 hierlib ase_hier_top schematic]

xschem unselect_all; xschem select instance x1; xschem descend
check_true "HL2 fixture: descended one level" \
  [expr {[xschem get currsch] == 1}]
check "HL3 descended one level, the PARENT's session is found (at level 0)" \
  [pcall {ase::session_for_current}] [list $topkey 0 hierlib ase_hier_top schematic]

xschem unselect_all; xschem select instance x2; xschem descend
check_true "HL4 fixture: descended two levels" \
  [expr {[xschem get currsch] == 2}]
## teeth for the "skip, don't give up" rule: the leaf is outside every registered
## library, so the FIRST level the walk looks at resolves to nothing.
check "HL4b fixture: the deepest level is not a registered cellview" \
  [catch {ase::design_of_path [file normalize [xschem get schname]]}] 1
check "HL5 descended two levels, the top session is still found" \
  [pcall {ase::session_for_current}] [list $topkey 0 hierlib ase_hier_top schematic]

## nearest ancestor wins: a session on the MID cell shadows the top one for a pick
## made below it -- its deck is what those node names must be relative to.
set midkey [ase::new_session hierlib ase_hier_mid schematic]
check "HL6 the NEAREST ancestor session wins over the top one" \
  [pcall {ase::session_for_current}] [list $midkey 1 hierlib ase_hier_mid schematic]

# --- HL7-HL12  the entry points ------------------------------------------------
## still at depth 2, with both sessions registered
check "HL7 direct_plot_for_current reaches the nearest ancestor session" \
  [pcall {ase::direct_plot_for_current}] $midkey
check "HL8 window_number_for_current resolves the session (honest 'no window')" \
  [pcall {ase::window_number_for_current}] {}
check_true "HL8b ... and says so about the WINDOW, not about the session" \
  [notices_match {*has no ASE-L window open*}]
set ::notices {}
check "HL9 plot_mode_for_current resolves the session (honest 'no viewer')" \
  [pcall {ase::plot_mode_for_current invert}] {}
check_true "HL9b ... and says so about the VIEWER, not about the session" \
  [notices_match {*no waveform viewer open*}]

## with NO session anywhere the message must still be honest -- and mention that
## the parents were searched too
ase::session_close $midkey
ase::session_close $topkey
set ::notices {}
check "HL10 no session anywhere -> {} " [pcall {ase::direct_plot_for_current}] {}
check_true "HL11 ... with a notice that names the hierarchy search" \
  [notices_match {*parent*}]

## re-register only the TOP session: the walk must cross the unregistered leaf
## level AND the session-less mid level to reach it
set topkey [ase::new_session hierlib ase_hier_top schematic]
check "HL12 the walk crosses an unregistered level and a session-less one" \
  [pcall {ase::direct_plot_for_current}] $topkey

# --- HL13-HL18  base-level-relative qualification -------------------------------
check "HL13 sod_base_level: the top session is at level 0 of this stack" \
  [pcall {ase::ui::sod_base_level $topkey}] 0
set midkey [ase::new_session hierlib ase_hier_mid schematic]
check "HL14 sod_base_level: the mid session is at level 1" \
  [pcall {ase::ui::sod_base_level $midkey}] 1
check "HL15 (control) base 0 keeps the shipped whole-path name" \
  [pcall {ase::ui::sod_qualify voltage mid 0}] {x1.x2.mid}
check "HL16 base 1 measures the name from the MID deck" \
  [pcall {ase::ui::sod_qualify voltage mid 1}] {x2.mid}
check "HL17 a current is base-relative too" \
  [pcall {ase::ui::sod_qualify current V1 1}] {v.x2.V1}
check "HL18 identity once the pick is AT the session's own level" \
  [pcall {ase::ui::sod_qualify voltage {a[1:0]} 2}] {a[1:0]}

# --- HL19-HL22  the C half ------------------------------------------------------
check "HL19 (control) resolved_net with no level is unchanged" \
  [pcall {xschem resolved_net mid}] {x1.x2.mid}
check "HL20 resolved_net accepts an explicit start level" \
  [pcall {xschem resolved_net mid 1}] {x2.mid}
check "HL21 resolved_net level 0 == the shipped answer" \
  [pcall {xschem resolved_net mid 0}] {x1.x2.mid}
set went [lindex [xschem windows] 0]
check "HL22 `xschem windows` carries the window's hierarchy stack" \
  [list [llength [lindex $went 6]] [file normalize [lindex [lindex $went 6] 0]]] \
  [list 3 $toppath]

# --- HL23-HL25  a DESCENDED window is not invisible ------------------------------
check "HL23 raise_design_editor finds the design one level up the stack" \
  [pcall {ase::ui::raise_design_editor $toppath}] 1
check "HL24 ... and does not disturb the descended level" \
  [xschem get currsch] 2
check "HL25 an unrelated path is still not found" \
  [pcall {ase::ui::raise_design_editor /nope/nothing.sch}] 0

# --- HL26-HL27  a real descended pick, through sod_click -------------------------
set ::queued {}
proc ase::ui::dp_queue {key ex {kind {}} {token {}}} { lappend ::queued $ex }
proc ase::ui::sod_queue {key ex} { lappend ::queued $ex }
proc pick {key x y} {
  array set ase::ui::sod [list $key,flavor {save 0 plot 1} $key,mode plot $key,count 0]
  xschem unselect_all
  set ::queued {}
  ase::ui::sod_click $key $x $y
  return $::queued
}
check "HL26 (control) a pick for the TOP session keeps the whole path" \
  [pick $topkey 250 60] {v(x1.x2.mid)}
check "HL27 a pick for the MID session is relative to the MID deck" \
  [pick $midkey 250 60] {v(x2.mid)}

} err]} { puts "FATAL: $err" ; incr fail }

## restore the real ciw_echo OUTSIDE the catch
if {[info commands real_ciw_echo] ne {}} {
  catch {rename ciw_echo {}}
  catch {rename real_ciw_echo ciw_echo}
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
