# schpins_to_sympins(): `lab` and `dir` carry over from the previous pin (issue 0185).
#
# schpins_to_sympins (src/xschem.tcl) turns the selected schematic pins into symbol
# pin boxes: it copies the selection to the clipboard file, rewrites every
# `C {...ipin.sym} ...` line into a `B 5 ... {name=<lab> dir=<dir>}` box, and pastes
# the result. Both `lab` and `dir` are assigned only INSIDE a regexp guard, in a loop
# over every clipboard line -- so a pin line that carries no `lab=` token leaves them
# holding the values of the PREVIOUS pin:
#
#     C {devices/ipin.sym} 0   0 0 0 {name=p1 lab=GOOD}
#     C {devices/ipin.sym} 0 -20 0 0 {name=p2}            <- no lab=
#
#   pre-fix   B 5 ... {name=GOOD dir=in}     <- p1's box
#             B 5 ... {name=GOOD dir=in}     <- p2's box, SAME NAME
#
# Two symbol pins with one name is a silent connectivity bug: they are no longer
# distinguishable to the netlister, and the second pin has lost its identity.
#
# The first-pin case is worse. With no earlier pin to inherit from, `lab` has never
# been set at all and the proc dies with
#
#     can't read "lab": no such variable
#
# AFTER `[open $USER_CONF_DIR/.clipboard.sch w]` has already truncated the clipboard
# file. So the user's copy is destroyed, nothing is generated, `$fd` is left open, and
# the subsequent `xschem paste` never runs.
#
# Third shape: the line filter is `regexp {^C \{.*(i|o|io)pin} $i`, which matches
# anywhere in the LINE, not just in the symbol name. A lab_pin whose label happens to
# be `ipin` passes the filter, fails all three `[lindex $ii 1]` direction tests, and
# used to be emitted as a phantom pin box carrying the previous pin's direction.
#
# Fix: reset `lab` and `dir` per line, and skip a line that produced no direction.
#
# Found while fixing issue 0183 (an empty attribute value swallows the next token) --
# this is the same proc and the 0183 fix quotes the empty name, but the carry-over is a
# separate defect and is what makes the empty case reachable in the first place.
#
# THE CLIPBOARD FILE IS THE REAL ONE. `xschem copy` writes $USER_CONF_DIR/.clipboard.sch
# from the C side, and USER_CONF_DIR is fixed at init, so a test cannot redirect it.
# This test saves the developer's clipboard first and puts it back at the end.
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_schpins_stale_lab_0185.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_schpins_stale_lab_0185.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch schpins_stale_lab_0185]

set clipboard [file join $USER_CONF_DIR .clipboard.sch]
set clipbak   [file join $scratch clipboard.bak]
set had_clip  [file exists $clipboard]
if {$had_clip} { file copy -force $clipboard $clipbak }

proc write_file {path body} { set f [open $path w]; puts $f $body; close $f }

# Build a schematic out of `C {...}` instance lines, select everything, run the
# generator, and hand back the boxes it produced. Returns a list of the property
# strings of the generated `B 5` pin boxes, in order, plus the `T {}` label texts.
proc generate {lines} {
  global scratch clipboard
  write_file [file join $scratch d.sch] "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
[join $lines \n]
"
  xschem load [file join $scratch d.sch]
  xschem select_all
  set err {}
  if {[catch {schpins_to_sympins} e]} { set err $e }
  set boxes {}
  set texts {}
  if {[file exists $clipboard]} {
    set f [open $clipboard r]; set data [read $f]; close $f
    foreach l [split $data \n] {
      if {[regexp {^B 5 .* \{(.*)\}$} $l -> props]} { lappend boxes $props }
      if {[regexp {^T \{(.*)\} } $l -> t]}          { lappend texts $t }
    }
  }
  return [list $err $boxes $texts]
}

set XSCHEM_LIBRARY_PATH [file join $repo xschem_library]

if {[catch {

# --- SL: a LATER pin with no lab= inherits the previous pin's name --------------
lassign [generate {
  {C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=GOOD}}
  {C {devices/ipin.sym} 0 -20 0 0 {name=p2}}
  {C {devices/ipin.sym} 0 -40 0 0 {name=p3 lab=THIRD}}
}] err boxes texts

check "SL1 the generator does not raise" $err {}
check "SL2 one box per pin" [llength $boxes] 3
# Pre-fix this was {name=GOOD dir=in} -- p1's label on p2's box.
check "SL3 an unlabelled pin does NOT inherit the previous pin's name" \
  [lindex $boxes 1] {name="" dir=in}
check "SL4 the labelled pins either side are untouched" \
  [list [lindex $boxes 0] [lindex $boxes 2]] {{name=GOOD dir=in} {name=THIRD dir=in}}
# The drawn text is the same variable, so it carried over too.
check "SL5 ...and neither does its drawn label" [lindex $texts 1] {}
check "SL6 the labelled texts are untouched" \
  [list [lindex $texts 0] [lindex $texts 2]] {GOOD THIRD}

# --- SF: the FIRST pin has no lab= at all --------------------------------------
# Pre-fix: `can't read "lab": no such variable`, thrown after the clipboard file
# had been truncated -- so both the copy and the generated symbol were lost.
lassign [generate {
  {C {devices/ipin.sym} 0 0 0 0 {name=p1}}
  {C {devices/ipin.sym} 0 -20 0 0 {name=p2 lab=SECOND}}
}] err boxes texts

check "SF1 an unlabelled FIRST pin does not abort the generator" $err {}
check "SF2 ...and does not destroy the clipboard: both pins are generated" \
  [llength $boxes] 2
check "SF3 the unlabelled first pin gets the quoted-empty name (issue 0183)" \
  [lindex $boxes 0] {name="" dir=in}
check "SF4 the labelled second pin is correct" [lindex $boxes 1] {name=SECOND dir=in}

# --- SD: direction carry-over, and the line filter that matches too much --------
# `regexp {^C \{.*(i|o|io)pin}` matches ANYWHERE in the line, so a lab_pin labelled
# `ipin` passes it, matches none of the three direction tests, and pre-fix was emitted
# as a phantom pin box holding the PREVIOUS pin's direction.
lassign [generate {
  {C {devices/opin.sym} 0 0 0 0 {name=p1 lab=OUT1}}
  {C {devices/lab_pin.sym} 0 -20 0 0 {name=l1 lab=ipin}}
}] err boxes texts

check "SD1 a non-pin instance mentioning a pin name does not abort" $err {}
check "SD2 ...and produces no phantom pin box" [llength $boxes] 1
check "SD3 the real pin keeps its own direction" [lindex $boxes 0] {name=OUT1 dir=out}

# --- SM: mixed directions, to pin that `dir` itself is per-line -----------------
lassign [generate {
  {C {devices/iopin.sym} 0 0 0 0 {name=p1 lab=IO1}}
  {C {devices/ipin.sym} 0 -20 0 0 {name=p2}}
  {C {devices/opin.sym} 0 -40 0 0 {name=p3 lab=O1}}
}] err boxes texts

check "SM1 the unlabelled pin between two others keeps its OWN direction" \
  [lindex $boxes 1] {name="" dir=in}
check "SM2 the iopin and opin either side are untouched" \
  [list [lindex $boxes 0] [lindex $boxes 2]] {{name=IO1 dir=inout} {name=O1 dir=out}}

} err]} { puts "FATAL: $err" ; incr fail }

if {$had_clip} { file copy -force $clipbak $clipboard }

# House banner form: full_audit.sh is_pass() scores on "RESULT: ALL PASS".
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
