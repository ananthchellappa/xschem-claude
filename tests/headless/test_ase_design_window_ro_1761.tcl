# tests/headless/test_ase_design_window_ro_1761.tcl -- a design that ASE-L
# opens is opened read-only (issue 1761).
#
# The request (2026-11-25): "When user does Session > Design Window in ASE-L,
# the schematic should NOT open in Edit mode. It should open Read Only."
#
# Code   src/ase_window.tcl   ase::ui::design_window,
#                             ase::ui::design_is_current_ro
#        src/scheduler.c      the `load` command's `-readonly` flag: the mode
#                             is set only when a file was really loaded
#
# FOUND ON THE WAY, in the door this goes through: `xschem load -gui
# -readonly <file>` from a window that already holds a schematic opens the
# file in a new window; when the file could not be opened, the window the
# user was in was made read-only and announced as opened. Band DW5.
#
# BANDS
#   DWH    the load flag with no display: both arms
#   DW1    the menu entry, into the empty window xschem starts with
#   DW2    Make Editable, and a second press of the menu entry
#   DW3    what the user does next on a read-only design: netlist, highlight
#   DW4    the menu entry while another schematic fills the window
#   DW5    a read-only open that loads nothing
#   DW6    the action log (needs --logdir, which the display arm of the
#          regression passes; a `skip:` line without it)
#
# REGISTERED IN `hcases` AND `dcases`.  Standalone from the repo ROOT, armed
# (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh [--nogui|--logdir] test_ase_design_window_ro_1761

source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch asedwro1761]
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
## One wire and one label pin on it. The instance is load-bearing: a sheet
## with no instance at all is loaded in symbol mode, and netlisting it then
## stops on a question about the netlisting mode.
proc sch_text {lab} {
  set t "v {xschem version=3.4.7RC file_version=1.2}\n"
  foreach r {G K V S E} { append t "$r {}\n" }
  append t "N 0 0 100 0 {lab=$lab}\n"
  append t "C {devices/lab_pin} 0 0 0 0 {name=p1 lab=$lab}\n"
  return $t
}
proc cur {} { return [file normalize [xschem get schname]] }
proc ro {} { return [pcall xschem get readonly] }
set HASX [expr {[info exists ::has_x] && [info commands winfo] ne {}}]

# --- fixture ------------------------------------------------------------------
file mkdir [file join $scratch dlib]
wr [file join $scratch library.defs] "DEFINE dlib [file join $scratch dlib]\n"
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set OTHER [file join $scratch other.sch]
set THIRD [file join $scratch third.sch]
set MISSING [file join $scratch nosuch.sch]
wr $OTHER [sch_text OTHERNET]
wr $THIRD [sch_text THIRDNET]

if {[catch {

library_new_cell dlib tb schematic
library_new_view dlib tb ngspice_state1 ngspice_state1
set DPATH [file normalize [xschem cellview_path dlib/tb schematic]]
wr $DPATH [sch_text NETA]
## The state runs in a folder of this suite's own.
set SPATH [xschem cellview_path dlib/tb ngspice_state1]
set ST0 [ase::state_load $SPATH]
dict set ST0 rundir [file join $scratch run]
file mkdir [file join $scratch run]
ase::state_save $SPATH $ST0

# =============================================================================
# DWH -- the load flag, no display needed
# =============================================================================
if {!$HASX} {
  xschem load -readonly $OTHER
  set DWH1 [list [expr {[cur] eq [file normalize $OTHER] ? 1 : 0}] [ro]]
  xschem load $THIRD
  check {DWH a scripted load with the read-only flag ends read-only, and the next plain load in the same window is editable again: the flag belongs to the load, not to the window} \
    [list $DWH1 [expr {[cur] eq [file normalize $THIRD] ? 1 : 0}] [ro]] \
    [list {1 1} 1 0]
}

if {$HASX} {
  ## How often the "Opened Read-Only" notice was said: the real proc still
  ## runs, this only counts its calls.
  set ::DWNOTES 0
  rename reopen_readonly_notice dw_saved_notice
  proc reopen_readonly_notice {args} { incr ::DWNOTES; catch {dw_saved_notice {*}$args} }
  ## What the "cannot open" alert was asked to say, instead of a window
  ## nobody is there to close.
  set ::DWALERTS {}
  rename alert_ dw_saved_alert
  proc alert_ {args} { lappend ::DWALERTS [lindex $args 0]; return {} }

  set KEY [ase::session_key dlib tb ngspice_state1]
  set DW0OPEN [pcall ase::open_state dlib tb ngspice_state1]
  update
  set TOP [ase::ui::window_for $KEY]
  ## The menu entry the user presses, by its label.
  proc press_design_window {} {
    set m $::TOP.mb.session
    if {[catch {$m index {Design Window}} i]} { return NOENTRY }
    if {[catch {$m invoke $i} e]} { return "ERR:$e" }
    update
    return OK
  }
  set LOG0 {}
  set LOGFN [pcall xschem get actionlog_filename]
  proc logtext {} {
    if {$::LOGFN eq {} || ![file exists $::LOGFN]} { return {} }
    set fp [open $::LOGFN r]; set t [read $fp]; close $fp
    return $t
  }
  set LOG0 [string length [logtext]]

  check {DW0 the fixture: the session window is up, the design is not open, and the window xschem started with is editable} \
    [list $DW0OPEN [expr {$TOP ne {} && [winfo exists $TOP] ? 1 : 0}] \
          [expr {[cur] eq $DPATH ? 1 : 0}] [ro]] \
    [list 1 1 0 0]

  # --- DW1: THE REQUEST ---------------------------------------------------
  set DW1P [press_design_window]
  check {DW1 THE REQUEST Session > Design Window opens the design read-only, the title says so, and the notice that names the way to edit is said once} \
    [list $DW1P [expr {[cur] eq $DPATH ? 1 : 0}] [ro] \
          [expr {[string first {(read-only)} [wm title [xschem get topwindow]]] >= 0 ? 1 : 0}] \
          $::DWNOTES] \
    [list OK 1 1 1 1]
  set LOG1 [string range [logtext] $LOG0 end]

  # --- DW2: THE USER CAN EDIT WHEN THEY MEAN TO -----------------------------
  pcall toggle_readonly
  set DW2A [ro]
  set DW2P [press_design_window]
  check {DW2 Make Editable makes it editable, and pressing Design Window again on the design that is already open raises it as it is: still editable, nothing announced} \
    [list $DW2A $DW2P [expr {[cur] eq $DPATH ? 1 : 0}] [ro] $::DWNOTES] \
    [list 0 OK 1 0 1]

  # --- DW3: WHAT THE USER DOES NEXT ON A READ-ONLY DESIGN -------------------
  pcall toggle_readonly
  ## The net is highlighted by the name the netlister gave the sheet's one
  ## wire, read off the wire: the label symbol is not in this suite's library
  ## list, so the name is not the fixture's to predict.
  set DW3NL [pcall ase::netlist [ase::session_state $KEY]]
  set DW3NET [pcall xschem getprop wire 0 lab]
  set DW3HL [pcall xschem hilight_netname $DW3NET]
  set DW3NO [pcall xschem hilight_netname zz_no_such_net_1761]
  pcall xschem unhilight_all
  check {DW3 the read-only design still netlists for a run and still takes a highlight; the CONTROL is a net that is not there, which is not found} \
    [list [ro] [expr {[file exists $DW3NL] && [file size $DW3NL] > 0 ? 1 : 0}] \
          [expr {$DW3NET ne {} ? 1 : 0}] $DW3HL $DW3NO] \
    [list 1 1 1 1 0]

  # --- DW4: WITH ANOTHER SCHEMATIC IN THE WINDOW ----------------------------
  ## A plain load puts another schematic where the design was, editable. The
  ## design is then open nowhere, and the window is not an empty one to reuse.
  xschem load $OTHER
  update
  set W0 [xschem get current_win_path]
  set DW4A [list [expr {[cur] eq [file normalize $OTHER] ? 1 : 0}] [ro]]
  set DW4P [press_design_window]
  set W1 [xschem get current_win_path]
  set DW4B [list [expr {[cur] eq $DPATH ? 1 : 0}] [ro] [expr {$W1 ne $W0 ? 1 : 0}]]
  catch {xschem new_schematic switch $W0} ; update
  set DW4C [list [expr {[cur] eq [file normalize $OTHER] ? 1 : 0}] [ro]]
  check {DW4 with another schematic filling the window, the design opens read-only in a window of its own and the schematic the user had open stays editable} \
    [list $DW4A $DW4P $DW4B $DW4C $::DWNOTES] \
    [list {1 0} OK {1 1 1} {1 0} 2]

  # --- DW5: A READ-ONLY OPEN THAT LOADS NOTHING -----------------------------
  ## Standing in the editable window that holds OTHER. The file does not
  ## exist, so nothing opens: nothing may become read-only and nothing may be
  ## announced as opened. The CONTROL is the same call on a file that exists.
  set ::DWALERTS {}
  pcall xschem load -gui -readonly $MISSING
  update
  set DW5A [list [expr {[cur] eq [file normalize $OTHER] ? 1 : 0}] [ro] \
                 [llength $::DWALERTS] $::DWNOTES]
  pcall xschem load -gui -readonly $THIRD
  update
  set DW5B [list [expr {[cur] eq [file normalize $THIRD] ? 1 : 0}] [ro] $::DWNOTES]
  catch {xschem new_schematic switch $W0} ; update
  check {DW5 a read-only open of a file that cannot be opened says so and leaves the window the user is in editable, with nothing announced as opened; the CONTROL, a file that exists, opens read-only in its own window and is announced} \
    [list $DW5A $DW5B [list [expr {[cur] eq [file normalize $OTHER] ? 1 : 0}] [ro]]] \
    [list {1 0 1 2} {1 1 3} {1 0}]

  # --- DW6: THE ACTION LOG ---------------------------------------------------
  if {$LOGFN ne {} && ![string match ERR:* $LOGFN]} {
    set iload [string first $DPATH $LOG1]
    set iro [string first {xschem set readonly 1} $LOG1]
    check {DW6 the action log of that first press holds the load of the design and, after it, the line that makes the window read-only, so a replay ends in the same mode} \
      [list [expr {$iload >= 0 ? 1 : 0}] [expr {$iro > $iload ? 1 : 0}] \
            [regexp -all -- {xschem set readonly 1} $LOG1]] \
      [list 1 1 1]
  } else {
    puts "skip: DW6 needs the action log (run with --logdir)"
  }

  catch {ase::ui::close $KEY}
  catch {rename reopen_readonly_notice {}}
  catch {rename dw_saved_notice reopen_readonly_notice}
  catch {rename alert_ {}}
  catch {rename dw_saved_alert alert_}
  update
} else {
  foreach r {DW0 DW1 DW2 DW3 DW4 DW5 DW6} {
    puts "skip: $r needs a display (the session window and its menu)"
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
