# tests/headless/test_ase_run_key_1764.tcl -- Ctrl-Alt-Shift-R in the design of
# an ASE-L session is that session's Netlist and Run (issue 1764).
#
# The request (2026-11-25): "in a linked schematic (i.e., the schematic that
# would be opened from ASE-L : Session > Design Window) ensure that
# Ctrl-Alt-Shift-R runs the simulation - i.e., - same as pressing the Netlist
# and Run button in ASE-L. This should work even if user has descended in the
# schematic down from the test-bench (top) level".
#
# Code   src/callback.c       action `ase.netlist_and_run` and its key row
#        src/keybindings.csv, src/actions.csv   the mirrors of both
#        src/ase_window.tcl   ase::ui::run_for_current, ase::ui::touch,
#                             ase::ui::last_used
#        src/ase.tcl          ase::sessions_for_current
#        src/xschem.tcl       Tools > Netlist and Run (ASE-L)
#
# HOW A RUN IS SEEN. `ase::run` is replaced by a recorder that makes the real
# netlist (`ase::netlist`, the call the real one makes first) and starts no
# simulator. So a row can say which session ran, from which level, and what
# deck came out, and nothing is left running.
#
# BANDS
#   RKT    the key row and the action, in the table and in the shipped files:
#          both arms
#   RKS    which sessions a window answers for, with no window: both arms
#   RKR    a real run from two levels down, with a stand-in simulator program
#   RK0    the fixture
#   RK1    THE REQUEST at the top level; it is the button's own command
#   RK2    two levels down; RK2b while the editor is busy
#   RK3    in a design opened read-only
#   RK4    a schematic no session is on; RK4b a session with no window
#   RK5    two sessions on one design: the one used last
#   RK6    after the one used last is closed
#   RK7    the chord moved to another key
#   RK8    the Tools menu entry; RK8b the window the key was pressed in
#   RK9    the key as Tk delivers it
#   RK10   the action log (needs --logdir; a `skip:` line without it)
#
# REGISTERED IN `hcases` AND `dcases`.  Standalone from the repo ROOT, armed
# (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh [--nogui|--logdir] test_ase_run_key_1764

source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch aserunkey1764]
test_sim_registry_isolate

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} ) \" '] $r]" }
  return $r
}
proc wr {path text} {
  file mkdir [file dirname $path]
  set fp [open $path w]; puts -nonewline $fp $text; close $fp
}
proc slurp {path} { set fp [open $path r]; set t [read $fp]; close $fp; return $t }
set HASX [expr {[info exists ::has_x] && [info commands winfo] ne {}}]
set REPO [file normalize [file join [file dirname [info script]] .. ..]]

# --- fixture: top -x1-> mid -x1-> leaf, and a cell nobody simulates ------------
set SYM {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"
}
V {}
S {}
E {}
B 5 -82.5 -2.5 -77.5 2.5 {name=A dir=inout}
L 4 -80 0 -40 0 {}
L 4 -40 -20 40 -20 {}
L 4 40 -20 40 20 {}
L 4 40 20 -40 20 {}
L 4 -40 20 -40 -20 {}
T {@symname} -38 -6 0 0 0.3 0.3 {}
T {@name} -5 -32 0 0 0.2 0.2 {}
}
proc sch_head {} {
  set t "v {xschem version=3.4.7RC file_version=1.2}\n"
  foreach r {G K V S E} { append t "$r {}\n" }
  return $t
}
set KL [file join $scratch klib]
file mkdir $KL
wr [file join $scratch library.defs] "DEFINE klib $KL\n"
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1

if {[catch {

foreach c {top mid leaf other} { library_new_cell klib $c schematic }
wr [file join $KL mid  symbol mid.sym]  $SYM
wr [file join $KL leaf symbol leaf.sym] $SYM
set P_TOP   [file normalize [xschem cellview_path klib/top schematic]]
set P_MID   [file normalize [xschem cellview_path klib/mid schematic]]
set P_LEAF  [file normalize [xschem cellview_path klib/leaf schematic]]
set P_OTHER [file normalize [xschem cellview_path klib/other schematic]]
wr $P_TOP "[sch_head]N 200 -100 280 -100 {}\nC {klib/mid} 360 -100 0 0 {name=x1}\nC {devices/lab_wire} 220 -100 0 0 {name=lT lab=TOPNET_1764}\n"
wr $P_MID "[sch_head]N 200 -100 280 -100 {}\nC {klib/leaf} 360 -100 0 0 {name=x1}\nC {devices/ipin} 200 -100 0 0 {name=pA lab=A}\n"
wr $P_LEAF "[sch_head]N 200 -100 280 -100 {}\nC {devices/ipin} 200 -100 0 0 {name=pA lab=A}\nC {devices/lab_wire} 240 -100 0 0 {name=lL lab=A}\n"
wr $P_OTHER "[sch_head]N 0 0 100 0 {lab=ONET}\nC {devices/lab_pin} 0 0 0 0 {name=p1 lab=ONET}\n"
## two saved states of the one bench, each running in a folder of its own
foreach v {ngspice_state1 ngspice_state2} {
  library_new_view klib top $v ngspice_state1
  set sp [xschem cellview_path klib/top $v]
  set st [ase::state_load $sp]
  dict set st rundir [file join $scratch run_$v]
  file mkdir [file join $scratch run_$v]
  ase::state_save $sp $st
}
set KEY1 [ase::session_key klib top ngspice_state1]
set KEY2 [ase::session_key klib top ngspice_state2]
set SP1 [file normalize [xschem cellview_path klib/top ngspice_state1]]
set SP2 [file normalize [xschem cellview_path klib/top ngspice_state2]]
## a saved state of the cell nobody opens a window for (row RK4b)
library_new_view klib other ngspice_state1 ngspice_state1
set KEYO [ase::session_key klib other ngspice_state1]
set SPO [file normalize [xschem cellview_path klib/other ngspice_state1]]

# =============================================================================
# RKT -- the table and the shipped files
# =============================================================================
set dump [pcall xschem bindings dump]
## the dump is a list of rows: device, code, modifiers, context, action and,
## for a row that is skipped while the editor is busy, the word idle
set drows {}
foreach l $dump {
  if {[lindex $l 4] eq {ase.netlist_and_run}} { lappend drows $l }
}
set kbcsv [slurp [file join $REPO src keybindings.csv]]
set accsv [slurp [file join $REPO src actions.csv]]
set csrc  [slurp [file join $REPO src callback.c]]
set acrows {}
foreach l [split $accsv \n] {
  if {[string match {ase.netlist_and_run,*} $l]} { lappend acrows $l }
}
check {RKT1 the live table binds the action once: key 82 (capital R, the shift is in the key) with Control and Alt, on the canvas, skipped while the editor is busy} \
  [list [llength $drows] [lindex $drows 0]] \
  [list 1 {key 82 ctrl+alt canvas ase.netlist_and_run idle}]
set a0 [lindex $acrows 0]
## The live table is the built-in one with keybindings.csv laid over it, so a
## row of the file hides a built-in row that is missing or not the same. The
## built-in one is read where it is written (last leg): it is what a user
## with a key file of their own, made before this action, gets.
check {RKT2 the shipped files agree with it: one row of keybindings.csv, one row of actions.csv whose command is the proc the action runs and whose accelerator text is the chord, the C table names that same proc, and the built-in table seeds the same chord, skipped while busy} \
  [list [regexp -all -line {^key,82,ctrl\+alt,canvas,ase\.netlist_and_run,1$} $kbcsv] \
        [llength $acrows] [lindex [split $a0 ,] 4] [lindex [split $a0 ,] 5] \
        [regexp {\{ "ase\.netlist_and_run", NULL, "ase::ui::run_for_current",} $csrc] \
        [regexp {set_input_binding_idle\(DEV_KEY, 'R', ControlMask\|Mod1Mask, ACTX_CANVAS,\s+"ase\.netlist_and_run"\);} $csrc]] \
  [list 1 1 {Ctrl+Alt+Shift+R} ase::ui::run_for_current 1 1]
## The row beside it is the CONTROL for the read-only claim of RK3: an action
## the table marks as changing the schematic. `xschem bindings` has no door
## for that flag, so it is read where it is written.
check {RKT3 the action is not one of those the table marks as changing the schematic (a fifth field of 1 in its row), which a read-only window refuses; the CONTROL is edit.undo, which is} \
  [list [regexp {\{ "ase\.netlist_and_run", NULL, "ase::ui::run_for_current",\s+"[^"]*" \},} $csrc] \
        [regexp {\{ "edit\.undo",\s+NULL, "[^"]*", "Undo", 1 \},} $csrc]] \
  [list 1 1]

# =============================================================================
# RKS -- which sessions a window answers for
# =============================================================================
xschem load $P_TOP
set RKS0 [pcall ase::sessions_for_current]
pcall ase::session_open $KEY1 $SP1
set RKS1 [pcall ase::sessions_for_current]
pcall ase::session_open $KEY2 $SP2
set RKS2 [pcall ase::sessions_for_current]
xschem descend -fallback -inst x1
xschem descend -fallback -inst x1
set RKS3 [list [xschem get sch_path] [pcall ase::sessions_for_current] \
               [lindex [pcall ase::session_for_current] 0]]
xschem load $P_OTHER
set RKS4 [pcall ase::sessions_for_current]
check {RKS1 a window answers for every session on its design, in the order they were opened: none, then one, then two; two levels down it still answers for the bench at level 0, and its first key is the one the single lookup gives. A schematic no session is on answers for none} \
  [list $RKS0 $RKS1 $RKS2 $RKS3 $RKS4] \
  [list {} [list 0 klib top schematic $KEY1] [list 0 klib top schematic $KEY1 $KEY2] \
        [list {.x1.x1.} [list 0 klib top schematic $KEY1 $KEY2] $KEY1] {}]
pcall ase::session_close $KEY1
pcall ase::session_close $KEY2

if {$HASX} {
  set ::RKALERTS {}
  rename alert_ rk_saved_alert
  proc alert_ {args} { lappend ::RKALERTS [lindex $args 0]; return {} }
  ## an error inside a binding or a timer is a background error, whose window
  ## blocks: recorded, and the row that runs for real asks for none
  set ::RKBG {}
  proc rk_bgerror {msg opts} { lappend ::RKBG $msg }
  interp bgerror {} rk_bgerror

  # --- RKR: THE REAL THING, ONCE ----------------------------------------------
  ## No recorder yet: the real run, from two levels down, with a stand-in for
  ## the simulator program that prints one line and ends.
  set STUB [file join $scratch bin ngstub]
  wr $STUB "#!/bin/sh\necho ZZ_STUB_RAN_1764 \"\$@\"\nexit 0\n"
  file attributes $STUB -permissions 0755
  ase::sim_clear
  set RKRREG [pcall ase::sim_register stub $STUB]
  xschem load $P_TOP
  update
  set RKROPEN [pcall ase::open_state klib top ngspice_state1]
  update
  xschem descend -fallback -inst x1
  xschem descend -fallback -inst x1
  update
  xschem callback [xschem get current_win_path] 2 400 300 82 0 0 13
  update
  ## the run ends by itself; a status still saying Running after the wait is
  ## the row's red, not a stall
  set t0 [clock milliseconds]
  set RKRST {}
  while {[clock milliseconds] - $t0 < 15000} {
    update
    set RKRST [pcall ase::ui::status_text $KEY1]
    if {![string match -nocase {*running*} $RKRST]} { break }
    after 100
  }
  set RKRLOG {}
  catch {set RKRLOG [[ase::ui::window_for $KEY1].logwin.t get 1.0 end]}
  set RKRDECK [file join $scratch run_ngspice_state1 top_ase.spice]
  check {RKR THE REQUEST, whole: two levels down, the key starts a real run of the session. The deck is written in the session's run folder, the simulator program is started on it and its output is in the session's log, the run ends, and the user is still two levels down. No error is raised on the way} \
    [list $RKRREG $RKROPEN [xschem get sch_path] [file exists $RKRDECK] \
          [expr {[string first "ZZ_STUB_RAN_1764 -b $RKRDECK" $RKRLOG] >= 0 ? 1 : 0}] \
          [string match -nocase {*running*} $RKRST] $::RKBG $::RKALERTS] \
    [list 1 1 .x1.x1. 1 1 0 {} {}]

  # --- the recorders ----------------------------------------------------------
  ## ::RAN  one entry per run a door asked for:
  ##        {view-of-the-state  sch_path-when-asked  sch_path-after-the-netlist  netlist-file}
  set ::RAN {}
  rename ::ase::run ::rk_saved_run
  proc ::ase::run {state {callback {}}} {
    set who {}
    foreach k [ase::sessions_for_state $state] { lappend who [lindex [split $k /] end] }
    set before [xschem get sch_path]
    if {[catch {ase::netlist $state} nl]} { set nl "ERR:$nl" }
    lappend ::RAN [list $who $before [xschem get sch_path] $nl]
    return [expr {4242 + [llength $::RAN]}]
  }
  ## how often the button's own command was run, and for which session
  set ::DORUN {}
  rename ::ase::ui::do_run ::rk_saved_do_run
  proc ::ase::ui::do_run {key} { lappend ::DORUN $key; ::rk_saved_do_run $key }
  set ::SAID {}
  rename ::ase::echo ::rk_saved_echo
  proc ::ase::echo {msg {tag {}}} { lappend ::SAID [list $tag $msg]; return 1 }
  proc said_n {pat} {
    set n 0
    foreach e $::SAID { if {[string match $pat [lindex $e 1]]} { incr n } }
    return $n
  }
  ## A read-only window answers a key that changes the schematic with a box
  ## that waits for a click. Recorded instead, so RK3 is a red row and not a
  ## stall on a product that marks the action as one of those.
  set ::RKBOXES {}
  rename tk_messageBox rk_saved_box
  proc tk_messageBox {args} { lappend ::RKBOXES $args; return ok }
  proc reset {} { set ::RAN {}; set ::DORUN {}; set ::SAID {}; set ::RKBOXES {} }
  ## The chord, through the C callback of the window that is current: a key
  ## press of keysym 82 with Shift, Control and Mod1 (Alt) down.
  proc press {{ks 82} {st 13}} {
    xschem callback [xschem get current_win_path] 2 400 300 $ks 0 0 $st
    update
  }
  proc ran_views {} { set o {}; foreach r $::RAN { lappend o [lindex $r 0] }; return $o }
  ## The schematic the deck of run `i` was made from (the first line of an
  ## xschem deck names it), and whether the deck holds the level below it.
  proc deck_top {i} {
    set nl [lindex $::RAN $i 3]
    if {$nl eq {} || [string match ERR:* $nl] || ![file exists $nl]} { return "NODECK:$nl" }
    set d [slurp $nl]
    if {![regexp -line {^\*\* sch_path: (.*)$} $d -> p]} { return NOHEAD }
    return [list [file normalize $p] [regexp -line {^x1 \S+ mid$} $d]]
  }
  proc where {} { return [list [xschem get sch_path] [file normalize [xschem get schname]]] }

  # --- RK0 --------------------------------------------------------------------
  xschem load $P_TOP
  update
  set RK0OPEN [pcall ase::open_state klib top ngspice_state1]
  update
  set TOP1 [ase::ui::window_for $KEY1]
  check {RK0 the fixture: one session window is up on the bench, the bench is the schematic on screen at its top level, and nothing has run} \
    [list $RK0OPEN [expr {$TOP1 ne {} && [winfo exists $TOP1] ? 1 : 0}] [where] $::RAN] \
    [list 1 1 [list . $P_TOP] {}]

  # --- RK1: THE REQUEST -------------------------------------------------------
  set m $TOP1.mb.sim
  set RK1CMD [pcall $m entrycget [$m index [ase::ui::lbl_netlist_and_run]] -command]
  ## The key, then the session window's own entry, in the same place: what
  ## ran, the deck and every sentence said have to be the same for both. (The
  ## netlister has two remarks about this bare fixture; they are its, and both
  ## doors get them.)
  proc press_button {} {
    set m $::TOP1.mb.sim
    catch {$m invoke [$m index [ase::ui::lbl_netlist_and_run]]}
    update
  }
  proc snap {} { return [list $::DORUN [ran_views] [deck_top 0] [where]] }
  reset ; press
  set RK1K [snap] ; set RK1KS $::SAID
  reset ; press_button
  set RK1B [snap] ; set RK1BS $::SAID
  check {RK1 THE REQUEST Ctrl-Alt-Shift-R on the bench runs the session: the command of the session window's own Netlist and Run entry is called once for it, one run is asked for, and the deck is made from the bench and holds the block under it. Pressing that entry itself gives the same run, the same deck and the same sentences, and none of them speaks of a busy editor} \
    [list [expr {$RK1CMD eq [list ase::ui::do_run $KEY1] ? 1 : 0}] $RK1K \
          [expr {$RK1K eq $RK1B ? 1 : 0}] [expr {$RK1KS eq $RK1BS ? 1 : 0}] \
          [said_n {*busy*}] [said_n {*could not descend*}]] \
    [list 1 [list [list $KEY1] ngspice_state1 [list $P_TOP 1] [list . $P_TOP]] 1 1 0 0]

  # --- RK2: TWO LEVELS DOWN ---------------------------------------------------
  xschem descend -fallback -inst x1
  xschem descend -fallback -inst x1
  update
  set RK2AT [where]
  reset ; press
  set RK2K [snap] ; set RK2KS $::SAID ; set RK2LV [list [lindex $::RAN 0 1] [lindex $::RAN 0 2]]
  reset ; press_button
  set RK2B [snap] ; set RK2BS $::SAID
  check {RK2 two levels down inside the bench the same key runs the same session: the deck is still made from the bench at the top, and the user is left standing where they were. The session window's own entry, pressed from there, gives the same run, deck and sentences, and none speaks of a busy editor} \
    [list $RK2AT $RK2K $RK2LV [expr {$RK2K eq $RK2B ? 1 : 0}] \
          [expr {$RK2KS eq $RK2BS ? 1 : 0}] [said_n {*busy*}] [said_n {*could not descend*}]] \
    [list [list .x1.x1. $P_LEAF] \
          [list [list $KEY1] ngspice_state1 [list $P_TOP 1] [list .x1.x1. $P_LEAF]] \
          {.x1.x1. .x1.x1.} 1 1 0 0]
  ## While the editor is in the middle of something a move through the
  ## hierarchy does nothing, so the run is not started and that is said.
  reset
  set sem0 [xschem get semaphore]
  xschem set semaphore [expr {$sem0 + 1}]
  set RK2BR [pcall ase::ui::run_for_window [xschem get current_win_path]]
  xschem set semaphore $sem0
  check {RK2b asked while the editor is busy, it starts nothing and says so once} \
    [list $sem0 $RK2BR $::DORUN $::RAN [said_n {*editor is busy*not*started*}] [llength $::SAID]] \
    [list 0 {} {} {} 1 1]

  # --- RK3: READ-ONLY ---------------------------------------------------------
  ## ASE-L opens the design read-only (issue 1761), so this is where the key
  ## is pressed most. The CONTROL is a key the table marks as changing the
  ## schematic, which the same window refuses: Ctrl-Z, with something to undo.
  xschem load $P_TOP
  update
  pcall xschem set readonly 1
  reset
  press
  set RK3A [list [pcall xschem get readonly] $::DORUN [ran_views] [llength $::RKBOXES]]
  pcall xschem set readonly 0
  check {RK3 in a design that is read-only the key still runs the session, and no "View is Read Only" box comes up} \
    $RK3A [list 1 [list $KEY1] ngspice_state1 0]

  # --- RK4: NO SESSION ON THIS SCHEMATIC --------------------------------------
  xschem load $P_OTHER
  update
  reset
  press
  check {RK4 on a schematic no session is on, the key runs nothing and says once that there is no session for this design and how to get one} \
    [list $::DORUN $::RAN [said_n {*no ASE-L session for this design*Launch ASE-L*}] [llength $::SAID]] \
    [list {} {} 1 1]
  ## A session a script opened has no window, so no button to press.
  pcall ase::session_open $KEYO $SPO
  set RK4BS [lrange [pcall ase::sessions_for_current] 4 end]
  reset
  press
  check {RK4b a session that has no window (a script opened it) has no button for the key to press: the window answers for it, nothing runs, and the same sentence is said once} \
    [list $RK4BS $::DORUN $::RAN [said_n {*no ASE-L session for this design*Launch ASE-L*}] [llength $::SAID]] \
    [list [list $KEYO] {} {} 1 1]
  pcall ase::session_close $KEYO

  # --- RK5: TWO SESSIONS ON ONE DESIGN ----------------------------------------
  xschem load $P_TOP
  update
  set RK5OPEN [pcall ase::open_state klib top ngspice_state2]
  ## asked before the event loop turns: the new window has not been given the
  ## keyboard yet, so only the opening itself can have marked it
  set RK5NEW [expr {[pcall ase::ui::last_used [list $KEY1 $KEY2]] eq $KEY2 ? 1 : 0}]
  update
  set TOP2 [ase::ui::window_for $KEY2]
  ## state2 was opened last
  reset ; press
  set RK5A [list [ran_views] [said_n {*2 ASE-L sessions are open on klib/top*used last, klib/top/ngspice_state2}]]
  ## the first window is given the keyboard: the binding a click in it runs
  event generate $TOP1 <FocusIn> ; update
  reset ; press
  set RK5B [list [ran_views] [said_n {*2 ASE-L sessions*used last, klib/top/ngspice_state1}]]
  ## the second runs from its own menu entry, then the key
  set m2 $TOP2.mb.sim
  catch {$m2 invoke [$m2 index [ase::ui::lbl_netlist_and_run]]} ; update
  reset ; press
  set RK5C [ran_views]
  ## the first is launched again, which raises its window. A raised window is
  ## also given the keyboard, which would mark it by itself: that binding is
  ## taken off this window first, so the launch has to be what marks it.
  bind $TOP1 <FocusIn> {}
  pcall ase::open_state klib top ngspice_state1 ; update
  reset ; press
  set RK5D [ran_views]
  check {RK5 with two sessions open on the bench the key runs the one used last and says which: the one opened last (marked by the opening, before it has the keyboard); then the one whose window was given the keyboard; then the one that ran from its own menu; then the one a launch raised. Each press runs one session} \
    [list $RK5OPEN $RK5NEW $RK5A $RK5B $RK5C $RK5D] \
    [list 1 1 {ngspice_state2 1} {ngspice_state1 1} ngspice_state2 ngspice_state1]

  # --- RK6: THE ONE USED LAST IS CLOSED ---------------------------------------
  pcall ase::ui::close $KEY1 ; update
  reset ; press
  ## the mark is read where it is kept: the window that is left gets the
  ## keyboard when the other closes, which would hide a mark left behind
  check {RK6 with the session used last closed, the key runs the one that is left and no longer speaks of two, and the closed session's mark is gone while the open one's is there} \
    [list [ran_views] [said_n {*ASE-L sessions are open*}] \
          [dict exists [set ::ase::ui::used] $KEY1] [dict exists [set ::ase::ui::used] $KEY2]] \
    [list ngspice_state2 0 0 1]

  # --- RK7: THE CHORD MOVED ---------------------------------------------------
  pcall xschem unbind key 82 ctrl+alt canvas
  reset ; press
  set RK7A [list $::DORUN $::RAN]
  ## F9 (keysym 65478), with nothing held
  pcall xschem bind key 65478 0 canvas ase.netlist_and_run
  reset ; press 65478 0
  set RK7B [ran_views]
  pcall xschem unbind key 65478 0 canvas
  pcall xschem bind key 82 ctrl+alt canvas ase.netlist_and_run
  reset ; press
  check {RK7 the chord is a row of the key table: unbound, the key runs nothing; bound to F9, F9 runs the session; bound back, Ctrl-Alt-Shift-R runs it again} \
    [list $RK7A $RK7B [ran_views]] \
    [list {{} {}} ngspice_state2 ngspice_state2]

  # --- RK8: THE TOOLS MENU ENTRY ----------------------------------------------
  set tm .menubar.tools
  set RK8I [pcall $tm index {Netlist and Run (ASE-L)}]
  set RK8ACC [pcall $tm entrycget $RK8I -accelerator]
  reset
  catch {$tm invoke $RK8I} ; update
  check {RK8 Tools > Netlist and Run (ASE-L) of the schematic window shows the chord and runs the session of that window} \
    [list [string is integer -strict $RK8I] $RK8ACC [ran_views]] \
    [list 1 {Ctrl+Alt+Shift+R} ngspice_state2]

  # --- RK8b: THE WINDOW THE KEY WAS PRESSED IN --------------------------------
  ## The work starts after the key press has returned. If another window has
  ## become the current one by then, it is still the pressed window's session.
  set W0 [xschem get current_win_path]
  pcall xschem load -gui $P_OTHER
  update
  set W1 [xschem get current_win_path]
  set RK8B0 [list [expr {$W1 ne $W0 ? 1 : 0}] [file normalize [xschem get schname]]]
  pcall xschem new_schematic switch $W0 ; update
  reset
  xschem callback $W0 2 400 300 82 0 0 13
  pcall xschem new_schematic switch $W1
  set RK8B1 [expr {[xschem get current_win_path] eq $W1 ? 1 : 0}]
  update
  check {RK8b the key pressed in the bench's window runs its session though another window, on a schematic no session is on, became the current one before the work started; nothing is said about a missing session} \
    [list $RK8B0 $RK8B1 [ran_views] [said_n {*no ASE-L session*}] \
          [expr {[xschem get current_win_path] eq $W0 ? 1 : 0}]] \
    [list [list 1 $P_OTHER] 1 ngspice_state2 0 1]
  pcall xschem new_schematic switch $W0 ; update

  # --- RK9: THE KEY AS TK DELIVERS IT -----------------------------------------
  ## Tk hands a generated key to the window that has the focus, so the canvas
  ## is given it and asked; a display that will not give it is a `skip:`.
  set cv [xschem get current_win_path]
  catch {focus -force $cv} ; update
  if {[focus -displayof $cv] eq $cv} {
    reset
    event generate $cv <Control-Mod1-Shift-KeyPress-R> ; update
    check {RK9 the chord typed on the canvas, through the binding that feeds every key to the editor, runs the session} \
      [ran_views] ngspice_state2
  } else {
    puts "skip: RK9 the canvas did not get the keyboard focus on this display"
  }

  # --- RK10: THE ACTION LOG ---------------------------------------------------
  set LOGFN [pcall xschem get actionlog_filename]
  if {$LOGFN ne {} && ![string match ERR:* $LOGFN] && [file exists $LOGFN]} {
    set l0 [string length [slurp $LOGFN]]
    reset ; press
    set tail [string range [slurp $LOGFN] $l0 end]
    check {RK10 a press is written to the action log as the action's own command, once} \
      [list [ran_views] [regexp -all -line {^ase::ui::run_for_current$} $tail]] \
      [list ngspice_state2 1]
  } else {
    puts "skip: RK10 needs the action log (run with --logdir)"
  }

  catch {ase::ui::close $KEY2}
  catch {ase::ui::close $KEY1}
  foreach {cur saved} {::ase::run ::rk_saved_run ::ase::ui::do_run ::rk_saved_do_run
                       ::ase::echo ::rk_saved_echo alert_ rk_saved_alert
                       tk_messageBox rk_saved_box} {
    catch {rename $cur {}}
    catch {rename $saved $cur}
  }
  catch {interp bgerror {} {}}
  update
} else {
  foreach r {RKR RK0 RK1 RK2 RK2b RK3 RK4 RK4b RK5 RK6 RK7 RK8 RK8b RK9 RK10} {
    puts "skip: $r needs a display (the session window and a key press on the canvas)"
  }
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr : FAIL"
  puts $::errorInfo
  incr fail
}

catch {test_scratch_drop $scratch}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
