# Regression: cross-view copy/paste pin transformation.
# See doc/claude/specs/crossview_copy_paste.md.
#
# Copy in one view type, paste into the other: ipin/opin/iopin INSTANCES (schematic)
# <-> PINLAYER pin RECTS (symbol) transform automatically at paste time; graphics pass
# through; wires / non-pin instances / net labels are skipped (schematic->symbol);
# duplicate pin names paste anyway but are dir-coerced to the existing pin's type.
# Clipboard records its source view in a '#XSCHEM_CLIPBOARD_VIEW=...' comment; a
# clipboard without the marker (old xschem) pastes with legacy behavior (no transform).
#
# Pure headless. Run from the repo ROOT (or tests/, paths normalized):
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_crossview_paste.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name = $got"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc bail {msg} { puts "FATAL: $msg : FAIL"; puts "OVERALL: notok"; exit 1 }

set HERE [file normalize [file dirname [info script]]]
set REPO [file normalize [file join $HERE .. ..]]
cd $REPO   ;# relative symbol paths (devices/...) need repo-root-anchored library path
set work /tmp/crossview_paste_work.[pid]
file delete -force $work; file mkdir $work

# ---------- fixture writers ----------------------------------------------------------
proc wr {path lines} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.8RC file_version=1.3}"
  puts $fd "G {}"; puts $fd "K {}"; puts $fd "V {}"; puts $fd "S {}"; puts $fd "E {}"
  foreach l $lines { puts $fd $l }
  close $fd
}

# source schematic: 3 ports + 1 res + 1 lab_pin + 1 wire + 1 graphics line
wr $work/src_sch.sch {
  {C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=A}}
  {C {devices/opin.sym} 100 0 0 0 {name=p2 lab=B}}
  {C {devices/iopin.sym} 200 50 0 0 {name=p3 lab=C}}
  {C {devices/res.sym} 300 0 0 0 {name=R1 value=1k}}
  {C {devices/lab_pin.sym} 400 0 0 0 {name=l1 lab=NETX}}
  {N 0 100 100 100 {}}
  {L 4 0 200 100 200 {}}
}
# source symbol: 3 pins + 1 graphics line
wr $work/src_sym.sym {
  {B 5 -2.5 -2.5 2.5 2.5 {name=X dir=in}}
  {B 5 97.5 -2.5 102.5 2.5 {name=Y dir=out}}
  {B 5 197.5 47.5 202.5 52.5 {name=Z dir=inout}}
  {L 4 0 -50 100 -50 {}}
}
# destinations
wr $work/dst_a.sym {}
wr $work/dst_b.sch {}
wr $work/dst_coerce.sch {
  {C {devices/opin.sym} -300 -300 0 0 {name=p1 lab=X}}
}
wr $work/dst_coerce.sym {
  {B 5 -302.5 -302.5 -297.5 -297.5 {name=A dir=out}}
}
wr $work/dst_c.sch {}
wr $work/dst_legacy.sym {}

# saved-file record helpers (query by grepping the saved file: API-agnostic, exact)
proc saved {path} {
  xschem saveas $path
  set fd [open $path r]; set b [read $fd]; close $fd
  return $b
}
# fold multiline records (pin props carry embedded newlines: name_rot=... lines) into
# single strings: a new record starts at a "<single-letter> " line, continuations append.
proc records {body} {
  set out {}; set cur {}
  foreach l [split $body \n] {
    if {[regexp {^[A-Za-z#] } $l] || $l eq {}} {
      if {$cur ne {}} { lappend out $cur }
      set cur $l
    } else {
      append cur " " $l
    }
  }
  if {$cur ne {}} { lappend out $cur }
  return $out
}
proc reclines {body tag} {
  set out {}
  foreach l [records $body] { if {[string match "$tag *" $l]} { lappend out $l } }
  return $out
}
# pin rects (B on layer 1 carrying name= and dir=) as sorted {name dir cx cy} tuples
proc pinrects {body} {
  set out {}
  foreach l [reclines $body B] {
    if {![regexp {^B 5 (\S+) (\S+) (\S+) (\S+) \{(.*)\}$} $l -> x1 y1 x2 y2 prop]} continue
    if {![regexp {name=(\S+)} $prop -> nm]} continue
    if {![regexp {dir=(\S+)} $prop -> dr]} continue
    lappend out [list $nm $dr [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]]
  }
  return [lsort -index 0 $out]
}
# instances as sorted {lab basename} tuples (ports only: those carrying lab= + pin syms)
proc pininsts {body} {
  set out {}
  foreach l [reclines $body C] {
    if {![regexp {^C \{([^\}]*)\} (\S+) (\S+) \S+ \S+ \{(.*)\}$} $l -> sym x y prop]} continue
    set base [file tail $sym]
    if {$base ni {ipin.sym opin.sym iopin.sym}} continue
    if {![regexp {lab=(\S+)} $prop -> lab]} continue
    lappend out [list $lab $base]
  }
  return [lsort -index 0 $out]
}

if {[catch {xschem clear force} e]} { bail "no xschem command / clear failed: $e" }

# ======================================================================================
# Case 1: copy in SCHEMATIC -> paste into SYMBOL: 3 pins convert, graphics pass,
#         wire + res + lab_pin skipped, relative pin positions preserved.
# ======================================================================================
xschem load $work/src_sch.sch
xschem select_all
xschem copy
xschem load $work/dst_a.sym
xschem paste 0 0
set body [saved $work/out_a.sym]
set pr [pinrects $body]
check "c1: 3 pin rects in symbol"        [llength $pr] 3
check "c1: names+dirs" [lmap p $pr {list [lindex $p 0] [lindex $p 1]}] \
      {{A in} {B out} {C inout}}
if {[llength $pr] == 3} {
  lassign [lindex $pr 0] - - ax ay
  lassign [lindex $pr 1] - - bx by
  lassign [lindex $pr 2] - - cx cy
  check "c1: B-A relative offset" [list [expr {$bx-$ax}] [expr {$by-$ay}]] {100.0 0.0}
  check "c1: C-A relative offset" [list [expr {$cx-$ax}] [expr {$cy-$ay}]] {200.0 50.0}
}
check "c1: wires skipped"                [llength [reclines $body N]] 0
check "c1: no instances leak into .sym"  [llength [reclines $body C]] 0
check "c1: graphics line passed"         [llength [reclines $body L]] 1
check "c1: no synthesized name views saved" [llength [reclines $body T]] 0

# undo removes the whole paste
xschem undo
set body [saved $work/out_a_undo.sym]
check "c1-undo: pin rects gone"          [llength [pinrects $body]] 0
check "c1-undo: line gone"               [llength [reclines $body L]] 0

# ======================================================================================
# Case 2: copy in SYMBOL -> paste into SCHEMATIC: pins become ipin/opin/iopin instances,
#         graphics pass, no stray pin rects or name texts.
# ======================================================================================
xschem load $work/src_sym.sym
xschem select_all
xschem copy
xschem load $work/dst_b.sch
xschem paste 0 0
set body [saved $work/out_b.sch]
check "c2: 3 pin instances" [pininsts $body] \
      {{X ipin.sym} {Y opin.sym} {Z iopin.sym}}
check "c2: no pin rects leak into .sch"  [llength [pinrects $body]] 0
check "c2: graphics line passed"         [llength [reclines $body L]] 1
check "c2: no stray texts"               [llength [reclines $body T]] 0

# ======================================================================================
# Case 3: dup-name coercion, SCHEMATIC dest: dst has OPIN X; pasted symbol pin X dir=in
#         must land as opin (type forced to existing), Y/Z unaffected.
# ======================================================================================
xschem load $work/src_sym.sym
xschem select_all
xschem copy
xschem load $work/dst_coerce.sch
xschem paste 0 0
set body [saved $work/out_coerce.sch]
set xi {}
foreach p [pininsts $body] { if {[lindex $p 0] eq {X}} { lappend xi [lindex $p 1] } }
check "c3: both X instances are opin (coerced)" [lsort -unique $xi] {opin.sym}
check "c3: X count (existing + pasted)"  [llength $xi] 2

# ======================================================================================
# Case 4: dup-name coercion, SYMBOL dest: dst has pin A dir=out; pasted schematic ipin A
#         must land as dir=out (forced), B/C keep their own dirs.
# ======================================================================================
xschem load $work/src_sch.sch
xschem select_all
xschem copy
xschem load $work/dst_coerce.sym
xschem paste 0 0
set body [saved $work/out_coerce.sym]
set adirs {}
foreach p [pinrects $body] { if {[lindex $p 0] eq {A}} { lappend adirs [lindex $p 1] } }
check "c4: both A pins dir=out (coerced)" [lsort -unique $adirs] {out}
check "c4: A count (existing + pasted)"  [llength $adirs] 2
set others {}
foreach p [pinrects $body] { if {[lindex $p 0] ne {A}} { lappend others [list [lindex $p 0] [lindex $p 1]] } }
check "c4: B/C dirs unchanged" $others {{B out} {C inout}}

# ======================================================================================
# Case 5: same-view paste unchanged (regression): sch -> sch keeps instances + wire.
# ======================================================================================
xschem load $work/src_sch.sch
xschem select_all
xschem copy
xschem load $work/dst_c.sch
xschem paste 0 0
set body [saved $work/out_c.sch]
check "c5: instances stay instances"     [llength [reclines $body C]] 5
check "c5: wire stays wire"              [llength [reclines $body N]] 1
check "c5: no pin rects created"         [llength [pinrects $body]] 0

# ======================================================================================
# Case 6: legacy clipboard (no marker) -> NO transform even cross-view.
# ======================================================================================
xschem load $work/src_sch.sch
xschem select_all
xschem copy
# strip the marker line (simulates a clipboard written by an old xschem)
set clip [file join $::env(HOME) .xschem .clipboard.sch]
if {![file exists $clip]} { bail "clipboard file not found at $clip" }
set fd [open $clip r]; set cb [read $fd]; close $fd
set stripped {}
foreach l [split $cb \n] {
  if {[string match "#XSCHEM_CLIPBOARD_VIEW=*" $l]} continue
  lappend stripped $l
}
set fd [open $clip w]; puts -nonewline $fd [join $stripped \n]; close $fd
xschem load $work/dst_legacy.sym
xschem paste 0 0
set body [saved $work/out_legacy.sym]
check "c6: legacy clipboard not transformed (instances kept)" \
      [llength [reclines $body C]] 5
check "c6: legacy clipboard makes no pin rects" [llength [pinrects $body]] 0

# ======================================================================================
# Case 7: clipboard marker written by copy (both view types).
# ======================================================================================
xschem load $work/src_sch.sch
xschem select_all
xschem copy
set fd [open $clip r]; set cb [read $fd]; close $fd
check "c7: schematic marker present" \
      [regexp -line {^#XSCHEM_CLIPBOARD_VIEW=schematic$} $cb] 1
xschem load $work/src_sym.sym
xschem select_all
xschem copy
set fd [open $clip r]; set cb [read $fd]; close $fd
check "c7: symbol marker present" \
      [regexp -line {^#XSCHEM_CLIPBOARD_VIEW=symbol$} $cb] 1

# ======================================================================================
# Case 8: save_selection never leaks synthesized pin-name views into the clipboard
#         (P1 S3 invariant; the merge P4 comment assumes it). Build a SHOWN pin in a
#         symbol view (create_pin materializes the name view), copy it: clipboard must
#         hold the B record but zero T records.
# ======================================================================================
wr $work/dst_leak.sym {}
xschem load $work/dst_leak.sym
xschem add_symbol_pin 0 0 LEAKPIN in 0 0
xschem select_all
xschem copy
set fd [open $clip r]; set cb [read $fd]; close $fd
check "c8: pin rect in clipboard"        [llength [reclines $cb B]] 1
check "c8: no synthesized name view in clipboard" [llength [reclines $cb T]] 0

# ======================================================================================
file delete -force $work
puts "PASS=$npass FAIL=$fail"
if {$fail == 0} { puts "OVERALL: ok"; exit 0 } else { puts "OVERALL: notok"; exit 1 }
