# tests/headless/test_ase_save_browse_1763.tcl -- Session > Save State has a
# Browse button, and a state is never written over a schematic (issue 1763).
#
# The request (2026-11-25): "The Session > Save State gives a dialog. That
# dialog pop-up SHOULD have a Browse button so user doesn't have to type
# everything."
#
# Code   src/ase_window.tcl   ase::ui::save_state_dialog (the button),
#                             ase::ui::saveas_browse and its saveas_browse_*
#                             procs (the browser),
#                             ase::ui::save_as_not_a_state (the guard), asked
#                             by ase::ui::save_state_ok and
#                             ase::ui::do_save_state_as
#
# FOUND ON THE WAY, in the same form: a View name that already is the cell's
# schematic passed the "State ... exists. Overwrite?" confirm and the state's
# text was written over the schematic file. Bands SN and SB9.
#
# BANDS
#   SN     the guard, with no window: both arms
#   SB0    the fixture
#   SB1    the button, and what the browser shows when it opens
#   SB2    Library and Cell picked, the View name kept
#   SB3    all three picked; the double click
#   SB4    Cancel and Escape
#   SB5    the browser goes with the form
#   SB6    OK with no Library picked
#   SB7    the whole trip ends in a saved state
#   SB8    the same through the blocking Save State of a close
#   SB9    the form refuses a View name that is the schematic
#
# REGISTERED IN `hcases` AND `dcases`.  Standalone from the repo ROOT, armed
# (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh [--nogui] test_ase_save_browse_1763

source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch asesavebr1763]
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
## One wire and one label pin: a sheet with no instance is loaded in symbol
## mode (doc/claude/TEST_LESSONS.md, section 4).
proc sch_text {lab} {
  set t "v {xschem version=3.4.7RC file_version=1.2}\n"
  foreach r {G K V S E} { append t "$r {}\n" }
  append t "N 0 0 100 0 {lab=$lab}\n"
  append t "C {devices/lab_pin} 0 0 0 0 {name=p1 lab=$lab}\n"
  return $t
}
## What ase::echo was asked to say, instead of the Command window.
set ::SAID {}
proc echo_on {} {
  set ::SAID {}
  if {[info commands ::sb_saved_echo] eq {}} {
    rename ::ase::echo ::sb_saved_echo
    proc ::ase::echo {msg {tag {}}} { lappend ::SAID [list $tag $msg]; return 1 }
  }
}
proc echo_off {} {
  if {[info commands ::sb_saved_echo] ne {}} {
    catch {rename ::ase::echo {}}
    rename ::sb_saved_echo ::ase::echo
  }
}
proc said_n {pat} {
  set n 0
  foreach e $::SAID { if {[string match $pat [lindex $e 1]]} { incr n } }
  return $n
}
set HASX [expr {[info exists ::has_x] && [info commands winfo] ne {}}]

# --- fixture ------------------------------------------------------------------
## alib/tb     schematic + two saved states (ngspice_state1, debug_st1)
## alib/amp    schematic, no saved state
## blib/other  schematic + one saved state (st_x)
file mkdir [file join $scratch alib] [file join $scratch blib]
wr [file join $scratch library.defs] \
  "DEFINE alib [file join $scratch alib]\nDEFINE blib [file join $scratch blib]\n"
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1

if {[catch {

library_new_cell alib tb schematic
library_new_cell alib amp schematic
library_new_cell blib other schematic
library_new_view alib tb ngspice_state1 ngspice_state1
library_new_view alib tb debug_st1 ngspice_state1
library_new_view blib other st_x ngspice_state1
set SCH_TB [file normalize [xschem cellview_path alib/tb schematic]]
wr $SCH_TB [sch_text NETA]
wr [file normalize [xschem cellview_path alib/amp schematic]] [sch_text NETB]
wr [file normalize [xschem cellview_path blib/other schematic]] [sch_text NETC]
set SCH_TB0 [slurp $SCH_TB]
set P_ST1 [file normalize [xschem cellview_path alib/tb ngspice_state1]]
set P_DBG [file normalize [xschem cellview_path alib/tb debug_st1]]
set DBG0 [slurp $P_DBG]
set KEY [ase::session_key alib tb ngspice_state1]

# =============================================================================
# SN -- the guard, no window needed
# =============================================================================
if {[info commands ase::ui::save_as_not_a_state] eq {}} {
  puts "skip: SN1 SN2 need the session window's file (ase::ui::save_as_not_a_state is absent)"
} else {
  check {SN1 the guard names the file a view of another kind holds, and answers nothing for a saved state, for a free name and for a cell that is not there} \
    [list [pcall ase::ui::save_as_not_a_state alib tb schematic] \
          [pcall ase::ui::save_as_not_a_state alib tb ngspice_state1] \
          [pcall ase::ui::save_as_not_a_state alib tb st_free] \
          [pcall ase::ui::save_as_not_a_state alib nocell schematic] \
          [pcall ase::ui::save_as_not_a_state blib other schematic]] \
    [list tb.sch {} {} {} other.sch]

  ## The writer, called the way a script calls it, on a session with no
  ## window. THE DEFECT: it answered 1 and the schematic held the state.
  if {!$HASX} {
    pcall ase::session_open $KEY $P_ST1
    echo_on
    set SN2R [pcall ase::ui::do_save_state_as $KEY alib tb schematic]
    set SN2N [list [said_n {*tb.sch*not a simulation state*NOT saved*}] [llength $::SAID]]
    echo_off
    check {SN2 THE DEFECT the writer refuses a View name that is the cell's schematic: it answers 0, says one sentence that names the file, and the schematic is byte for byte what it was} \
      [list $SN2R $SN2N [expr {[slurp $SCH_TB] eq $SCH_TB0 ? 1 : 0}]] \
      [list 0 {1 1} 1]
    pcall ase::session_close $KEY
  } else {
    puts "skip: SN2 is the no-display leg of the writer's guard; with a display band SB9 presses it"
  }
}

if {$HASX} {
  set ::SBALERTS {}
  rename alert_ sb_saved_alert
  proc alert_ {args} { lappend ::SBALERTS [lindex $args 0]; return {} }
  ## An error raised inside a binding is a background error, and Tk's window
  ## for it blocks. Recorded instead, and rows SB3 and SB9 ask for none.
  set ::BGERR {}
  proc sb_bgerror {msg opts} { lappend ::BGERR $msg }
  interp bgerror {} sb_bgerror

  set SB0OPEN [pcall ase::open_state alib tb ngspice_state1]
  update
  set TOP [ase::ui::window_for $KEY]
  set D $TOP.saveas
  set BR $D.br
  ## The Session menu entry the user presses, by its label.
  proc press_save_state {} {
    set m $::TOP.mb.session
    if {[catch {$m index {Save State}} i]} { return NOENTRY }
    if {[catch {$m invoke $i} e]} { return "ERR:$e" }
    update
    return OK
  }
  proc form {} {
    if {![winfo exists $::D]} { return NOFORM }
    return [list [$::D.lib get] [$::D.cell get] [$::D.view get]]
  }
  proc form_set {l c v} {
    if {![winfo exists $::D]} { return NOFORM }
    $::D.lib set $l
    $::D.cell delete 0 end; $::D.cell insert 0 $c
    $::D.view delete 0 end; $::D.view insert 0 $v
  }
  ## NOBROWSER rather than an error: a row that asks about a browser that is
  ## not there has to be red by its own name, not end the suite.
  proc col {c} {
    if {![winfo exists $::BR]} { return NOBROWSER }
    return [$::BR.pw.$c.lb get 0 end]
  }
  proc sel {c} {
    if {![winfo exists $::BR]} { return NOBROWSER }
    set s [$::BR.pw.$c.lb curselection]
    if {$s eq {}} { return {} }
    return [$::BR.pw.$c.lb get [lindex $s 0]]
  }
  ## A user's click on a row: the selection, then the event Tk raises for it.
  proc lbpick {c val} {
    set lb $::BR.pw.$c.lb
    if {![winfo exists $lb]} { return NOBROWSER }
    set i [lsearch -exact [$lb get 0 end] $val]
    if {$i < 0} { return NOTLISTED }
    $lb selection clear 0 end
    $lb selection set $i
    event generate $lb <<ListboxSelect>>
    update
    return OK
  }
  ## Two real clicks on a row, close together, as a double click arrives.
  proc lbdouble {c val} {
    set lb $::BR.pw.$c.lb
    if {![winfo exists $lb]} { return NOBROWSER }
    set i [lsearch -exact [$lb get 0 end] $val]
    if {$i < 0} { return NOTLISTED }
    $lb see $i
    update
    set bb [$lb bbox $i]
    if {[llength $bb] != 4} { return NOBBOX }
    lassign $bb x y w h
    set cx [expr {$x + 4}]; set cy [expr {$y + $h / 2}]
    foreach ev {ButtonPress-1 ButtonRelease-1 ButtonPress-1 ButtonRelease-1} {
      if {![winfo exists $lb]} { break }
      catch {event generate $lb <$ev> -x $cx -y $cy}
    }
    update
    return OK
  }
  proc browse {} {
    if {![winfo exists $::D]} { return NOFORM }
    if {![winfo exists $::D.browse]} { return NOBUTTON }
    if {[catch {$::D.browse invoke} e]} { return "ERR:$e" }
    update
    return [expr {[winfo exists $::BR] ? {OK} : {NOBROWSER}}]
  }
  proc br_ok {} { catch {$::BR.b.ok invoke}; update }
  proc br_status {} {
    if {![winfo exists $::BR]} { return NOBROWSER }
    return [$::BR.status cget -text]
  }

  # --- SB0 --------------------------------------------------------------------
  set SB0P [press_save_state]
  check {SB0 the fixture: the session window is up, Session > Save State opens the form on the session's own library, cell and view, and no browser is open yet} \
    [list $SB0OPEN $SB0P [form] [winfo exists $BR]] \
    [list 1 OK {alib tb ngspice_state1} 0]

  # --- SB1: THE REQUEST -------------------------------------------------------
  set SB1B [list [winfo exists $D.browse] \
                 [expr {[winfo exists $D.browse] ? [winfo manager $D.browse] : {}}] \
                 [expr {[winfo exists $D.browse] ? [$D.browse cget -text] : {}}]]
  set SB1P [browse]
  check {SB1 THE REQUEST the form has a Browse button, and pressing it opens a browser that stands where the form stands: the library, the cell and the state selected, the cell's saved states listed and its schematic not among them} \
    [list $SB1B $SB1P [sel lib] [sel cell] [sel view] [lsort [col view]] \
          [expr {{alib} in [col lib] && {blib} in [col lib] ? 1 : 0}] \
          [lsort [col cell]]] \
    [list [list 1 grid "Browse…"] OK alib tb ngspice_state1 \
          {debug_st1 ngspice_state1} 1 {amp tb}]

  # --- SB2: LIBRARY AND CELL, THE NAME KEPT -------------------------------------
  form_set alib tb my_new_state
  browse
  set SB2SEED [list [sel lib] [sel cell] [sel view]]
  set SB2P [lbpick cell amp]
  set SB2HINT [expr {[string match {alib/amp has no saved state yet*} [br_status]] ? 1 : 0}]
  set SB2V [col view]
  br_ok
  check {SB2 with a name typed that is no saved state, the browser opens on the library and the cell with no View picked; picking a cell that has no state says so, and OK takes the Library and the Cell and leaves the typed View name alone} \
    [list $SB2SEED $SB2P $SB2HINT $SB2V [form] [winfo exists $BR]] \
    [list {alib tb {}} OK 1 {} {alib amp my_new_state} 0]

  # --- SB3: ALL THREE, AND THE DOUBLE CLICK -------------------------------------
  browse
  set SB3A [list [lbpick lib blib] [col cell] [col view] [form]]
  set SB3B [list [lbpick cell other] [col view] [lbpick view st_x]]
  br_ok
  set SB3F [form]
  ## the double click, from a form put back on the session's own names
  form_set alib tb ngspice_state1
  browse
  set SB3C [lbdouble cell amp]
  set SB3CUP [list [winfo exists $BR] [form]]
  lbpick cell tb
  set SB3D [lbdouble view debug_st1]
  check {SB3 a pick changes nothing in the form until OK; with Library, Cell and View picked OK takes all three. A double click on a state is the pick and the OK in one, and raises no error in the window it closes; the CONTROL is a double click on a cell, which leaves the browser up and the form as it was} \
    [list $SB3A $SB3B $SB3F $SB3C $SB3CUP $SB3D [winfo exists $BR] [form] $::BGERR] \
    [list {OK other {} {alib amp my_new_state}} {OK st_x OK} {blib other st_x} \
          OK {1 {alib tb ngspice_state1}} OK 0 {alib tb debug_st1} {}]

  # --- SB4: CANCEL AND ESCAPE ---------------------------------------------------
  form_set alib tb ngspice_state1
  browse
  lbpick lib blib ; lbpick cell other ; lbpick view st_x
  catch {$BR.b.cancel invoke} ; update
  set SB4A [list [winfo exists $BR] [form] [winfo exists $D]]
  browse
  lbpick lib blib
  set SB4ESC {} ; set SB4SAME 0
  if {[winfo exists $BR]} {
    set SB4ESC [bind $BR <Key-Escape>]
    set SB4SAME [expr {$SB4ESC ne {} && $SB4ESC eq [$BR.b.cancel cget -command] ? 1 : 0}]
  }
  catch {uplevel #0 $SB4ESC} ; update
  check {SB4 Cancel closes the browser and leaves the form as it was, with a pick made in all three columns; Escape in the browser is the same command, and the form behind it stays up} \
    [list $SB4A $SB4SAME [winfo exists $BR] [form] [winfo exists $D]] \
    [list {0 {alib tb ngspice_state1} 1} 1 0 {alib tb ngspice_state1} 1]

  # --- SB5: THE BROWSER GOES WITH THE FORM --------------------------------------
  browse
  set SB5UP [winfo exists $BR]
  catch {$D.btns.cancel invoke} ; update
  check {SB5 cancelling the form with the browser open takes both down} \
    [list $SB5UP [winfo exists $D] [winfo exists $BR]] \
    [list 1 0 0]

  # --- SB6: OK WITH NO LIBRARY --------------------------------------------------
  press_save_state
  form_set nosuchlib tb ngspice_state1
  browse
  set SB6SEED [list [sel lib] [col cell]]
  br_ok
  set SB6A [list [winfo exists $BR] [form] [br_status]]
  ## the CONTROL: the same OK once a library is picked
  lbpick lib blib
  br_ok
  check {SB6 a Library the lists do not hold opens the browser with nothing picked; OK there copies nothing and the browser stays, asking for a Library. The CONTROL: the same OK with a library picked takes the Library alone} \
    [list $SB6SEED $SB6A [winfo exists $BR] [form]] \
    [list {{} {}} [list 1 {nosuchlib tb ngspice_state1} {pick a Library, then a Cell}] \
          0 {blib tb ngspice_state1}]
  catch {$D.btns.cancel invoke} ; update

  # --- SB7: THE WHOLE TRIP ------------------------------------------------------
  ## Browse to the other library's cell, type a new state name, OK.
  press_save_state
  browse
  lbpick lib blib ; lbpick cell other
  br_ok
  catch {$D.view delete 0 end ; $D.view insert 0 st_browsed}
  set SB7F [form]
  echo_on
  catch {$D.btns.proceed invoke} ; update
  set SB7SAID [said_n {*state saved to blib/other/st_browsed*}]
  echo_off
  set SB7P [pcall xschem cellview_path blib/other st_browsed]
  check {SB7 the whole trip: Browse to another library's cell, type a new View name, OK. The state is saved there with no question asked, and the form is gone} \
    [list $SB7F $SB7SAID [expr {[string match {*.state} $SB7P] && [file exists $SB7P] ? 1 : 0}] \
          [winfo exists $D] [winfo exists $TOP.confirm]] \
    [list {blib other st_browsed} 1 1 0 0]
  ## and a browsed state that exists still asks before it is replaced
  press_save_state
  browse
  lbpick view debug_st1
  br_ok
  set SB7BF [form]
  catch {$D.btns.proceed invoke} ; update
  set SB7BC [list [winfo exists $TOP.confirm] [expr {[slurp $P_DBG] eq $DBG0 ? 1 : 0}]]
  catch {$TOP.confirm.btns.cancel invoke} ; update
  check {SB7b a state picked in the browser is still asked about before it is replaced: OK in the form brings the Overwrite question, and the state is untouched until it is answered} \
    [list $SB7BF $SB7BC [expr {[slurp $P_DBG] eq $DBG0 ? 1 : 0}]] \
    [list {alib tb debug_st1} {1 1} 1]
  catch {$D.btns.cancel invoke} ; update

  # --- SB8: THE BLOCKING SAVE STATE OF A CLOSE ----------------------------------
  ## ase::ui::save_state_modal waits for the form; the browser has to be
  ## usable while it waits. The steps are queued and run inside that wait.
  set ::SB8LOG {}
  after 150 {
    lappend ::SB8LOG [browse]
    lappend ::SB8LOG [lbpick lib blib] [lbpick cell other]
    br_ok
    lappend ::SB8LOG [form]
    catch {$::D.view delete 0 end ; $::D.view insert 0 st_modal}
    catch {$::D.btns.proceed invoke}
  }
  ## the way out if a step above did not end the wait
  set SB8GUARD [after 8000 { lappend ::SB8LOG GUARD ; catch {destroy $::D} }]
  set SB8R [pcall ase::ui::save_state_modal $KEY]
  after cancel $SB8GUARD
  update
  set SB8P [pcall xschem cellview_path blib/other st_modal]
  check {SB8 the Save State a close asks for waits for the form, and the browser works inside that wait: the pick lands in the form, OK saves there, and the wait ends saying the save was made} \
    [list $SB8R $::SB8LOG [expr {[string match {*.state} $SB8P] && [file exists $SB8P] ? 1 : 0}]] \
    [list 1 [list OK OK OK {blib other ngspice_state1}] 1]

  # --- SB9: THE FORM REFUSES THE SCHEMATIC --------------------------------------
  press_save_state
  form_set alib tb schematic
  echo_on
  catch {$D.btns.proceed invoke} ; update
  set SB9A [list [winfo exists $TOP.confirm] [winfo exists $D] \
                 [said_n {*tb.sch*not a simulation state*NOT saved*}] \
                 [expr {[slurp $SCH_TB] eq $SCH_TB0 ? 1 : 0}]]
  ## the writer itself, as a script or the Command window calls it
  set SB9W [pcall ase::ui::do_save_state_as $KEY alib tb schematic]
  set SB9B [list $SB9W [said_n {*tb.sch*not a simulation state*NOT saved*}] \
                 [expr {[slurp $SCH_TB] eq $SCH_TB0 ? 1 : 0}] [winfo exists $D]]
  echo_off
  ## the CONTROL: the same press on a name that IS another state asks
  form_set alib tb debug_st1
  catch {$D.btns.proceed invoke} ; update
  set SB9C [winfo exists $TOP.confirm]
  catch {$TOP.confirm.btns.cancel invoke} ; update
  check {SB9 THE DEFECT a View name that is the cell's schematic is refused before any question: no Overwrite window, one sentence naming the file, the form still up, the schematic byte for byte what it was. The writer called directly refuses too. The CONTROL: a name that is another saved state does bring the question} \
    [list $SB9A $SB9B $SB9C $::BGERR] \
    [list {0 1 1 1} {0 2 1 1} 1 {}]
  catch {$D.btns.cancel invoke} ; update

  catch {ase::ui::close $KEY}
  catch {rename alert_ {}}
  catch {rename sb_saved_alert alert_}
  catch {interp bgerror {} {}}
  update
} else {
  foreach r {SB0 SB1 SB2 SB3 SB4 SB5 SB6 SB7 SB7b SB8 SB9} {
    puts "skip: $r needs a display (the Save State form and its browser)"
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
