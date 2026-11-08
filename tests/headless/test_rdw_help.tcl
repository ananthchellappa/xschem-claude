# The Results Display Window's Help button: which keys show OP info.
# rdw::help_text reads the KEYS from live bindings (the design canvas's, bound
# by src/cadence_style_rc, and the window's own) and writes only the sentences.
#   HL1-HL4  the text builder on injected bindings (both arms)
#   HL5-HL7  the live button and window, with the Cadence profile loaded (display arm)
# Run: tests/headless/run_suites.sh [--nogui] test_rdw_help
source [file join [file dirname [info script]] scratch.tcl]

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want})" ; incr fail }
}

# HL1 -- key names: modifiers in Ctrl, Alt, Shift order, letters in capitals,
# a shifted keysym keeps its own name.
check {HL1 key names} \
  [lmap e {<Key-1> <Control-Key-6> <Shift-Alt-Key-6> <Alt-Key-asciicircum> <Control-Key-c> <Key-Escape> <Control-Alt-Key-6> <Key-F7>} \
     {rdw::_help_key $e}] \
  {1 Ctrl+6 Alt+Shift+6 Alt+^ Ctrl+C Esc Ctrl+Alt+6 F7}

# HL2 -- rows come from what the bindings RUN: a remapped key shows as
# remapped, `op` is not mistaken for `opvolt`, a virtual event is not a key,
# this window's `rdw::_digit <kind>` counts as `rdw::key <kind>`, and an action
# nothing runs has no row.
set HL2 [rdw::_help_rows {
  <Key-F7>      {rdw::key all; break}
  <Key-6>       {cadence::annot_mode op;          break}
  <Alt-Key-6>   {cadence::annot_mode opvolt;      break}
  <<Copy>>      {rdw::copy ; break}
  <Control-Key-c> {rdw::copy ; break}
  <Key-1>       {if {[rdw::_digit annotation %s]} break}
}]
check {HL2 rows follow the bindings} $HL2 [list \
  [list 1 {Device's annotation parameters into this window}] \
  [list F7 {All of the device's parameters into this window}] \
  [list 6 {Show OP info on the schematic}] \
  [list Alt+6 {Show OP node voltages on the schematic}] \
  [list Ctrl+C {Copy the selected text}]]

# HL3 -- no profile, no canvas keys: the text says so instead of listing keys.
set HL3 [rdw::help_text {} {<Key-Escape> {rdw::pick_end}}]
check {HL3 an unbound canvas is named, the window's own keys still listed} \
  [list [string match {*(none bound - the Cadence-style profile binds them)*} $HL3] \
        [string match {*Esc*End a device pick*} $HL3] \
        [string match {*Show OP info*} $HL3]] \
  {1 1 0}

# HL4 -- Help is not a list button: rdw::button refuses it with the same
# sentence as the column's other non-list controls (in the status line,
# ::rdw::statusmsg), and changes nothing.
set HL4_B0 [expr {[info exists ::rdw::blocks] ? $::rdw::blocks : {}}]
rdw::button help
set HL4 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
check {HL4 rdw::button help refuses as a non-list control} \
  [list [string match {*'help' is not one of this window's list buttons*} $HL4] \
        [expr {[lsearch -exact [rdw::_buttons] help] < 0}] \
        [expr {([info exists ::rdw::blocks] ? $::rdw::blocks : {}) eq $HL4_B0}]] \
  {1 1 1}

if {[rdw::have_tk]} {
  source [file join [file dirname [info script]] .. .. src cadence_style_rc]
  update
  rdw::open ; update

  # HL5 -- the column: Help packed bottom-side after `aA`, so it sits above
  # `aA`, which sits above Close at the foot.
  set HL5 [lmap c [pack slaves .rdw.b] {winfo name $c}]
  check {HL5 Help sits above aA, Close stays lowest} \
    [lrange $HL5 end-2 end] {close fontsize help}

  # HL6 -- a real press: the help window maps, lists the profile's live keys,
  # and the keyboard goes back to the canvas.
  .rdw.b.help invoke ; update
  set HL6_T [.rdwhelp.t get 1.0 end]
  check {HL6 the press maps the help with the live keys and gives focus back to the canvas} \
    [list [winfo ismapped .rdwhelp] \
          [string match {*Alt+6 * Show OP node voltages on the schematic*} $HL6_T] \
          [string match {*Ctrl+Alt+6 * Declutter toggle*} $HL6_T] \
          [string match {*Esc * End a device pick*} $HL6_T] \
          [string match {*none bound*} $HL6_T] \
          [focus] [.rdwhelp.t cget -state]] \
    {1 1 1 1 0 .drw disabled}

  # HL7 -- a second press reuses the one window; its Close destroys it.
  .rdw.b.help invoke ; update
  set HL7_N [llength [lsearch -all [winfo children .] .rdwhelp*]]
  .rdwhelp.close invoke ; update
  check {HL7 one help window, and its Close closes it} \
    [list $HL7_N [winfo exists .rdwhelp]] {1 0}
  rdw::close
} else {
  puts "SKIP: HL5-HL7 need a display (the live button and window)"
}

# Without a display only HL1-HL4 exist, so the floor is per arm.
set floor [expr {[rdw::have_tk] ? 7 : 4}]
if {$npass + $fail < $floor} {
  puts "FAIL: HLFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
