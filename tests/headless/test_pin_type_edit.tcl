# Regression: easy pin-type editing (doc/claude/specs/pin_type_editing.md).
#
# `xschem set_pin_type <in|out|inout|-cycle> [<inst>]` — view-aware core verb:
# schematic view swaps devices/ipin|opin|iopin.sym on port instances (selection or
# named), symbol view rewrites dir= on selected PINLAYER pin rects; ONE undo slot
# per call; returns the number changed. Plus the addpin::cycle_type placed-pin
# fallback (Ctrl+MMB gesture core; form/GUI arm exercised manually).
#
# Pure headless. Run from the repo ROOT (or tests/, paths normalized):
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_pin_type_edit.tcl
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
cd $REPO
set work /tmp/pin_type_edit_work.[pid]
file delete -force $work; file mkdir $work

proc wr {path lines} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.8RC file_version=1.3}"
  puts $fd "G {}"; puts $fd "K {}"; puts $fd "V {}"; puts $fd "S {}"; puts $fd "E {}"
  foreach l $lines { puts $fd $l }
  close $fd
}
proc saved {path} {
  xschem saveas $path
  set fd [open $path r]; set b [read $fd]; close $fd
  return $b
}
proc records {body} {
  set out {}; set cur {}
  foreach l [split $body \n] {
    if {[regexp {^[A-Za-z#] } $l] || $l eq {}} {
      if {$cur ne {}} { lappend out $cur }
      set cur $l
    } else { append cur " " $l }
  }
  if {$cur ne {}} { lappend out $cur }
  return $out
}
# {instname basename lab x y} rows for port instances, sorted by instname
proc ports {body} {
  set out {}
  foreach l [records $body] {
    if {![regexp {^C \{([^\}]*)\} (\S+) (\S+) \S+ \S+ \{(.*)\}$} $l -> sym x y prop]} continue
    set base [file tail $sym]
    if {$base ni {ipin.sym opin.sym iopin.sym}} continue
    regexp {name=(\S+)} $prop -> nm
    regexp {lab=(\S+)} $prop -> lab
    lappend out [list $nm $base $lab $x $y]
  }
  return [lsort -index 0 $out]
}
# {name dir} rows for PINLAYER pin rects, sorted by name
proc pins {body} {
  set out {}
  foreach l [records $body] {
    if {![regexp {^B 5 \S+ \S+ \S+ \S+ \{(.*)\}$} $l -> prop]} continue
    if {![regexp {name=(\S+)} $prop -> nm]} continue
    if {![regexp {dir=(\S+)} $prop -> dr]} continue
    lappend out [list $nm $dr]
  }
  return [lsort -index 0 $out]
}
# select one instance by name via its current index
proc sel_inst {nm} {
  xschem unselect_all
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem getprop instance $i name] eq $nm} { xschem select instance $i; return $i }
  }
  bail "instance $nm not found"
}

wr $work/s.sch {
  {C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=A}}
  {C {devices/opin.sym} 100 0 1 0 {name=p2 lab=B}}
  {C {devices/res.sym} 300 0 0 0 {name=R1 value=1k}}
}
wr $work/s.sym {
  {B 5 -2.5 -2.5 2.5 2.5 {name=X dir=in}}
  {B 5 97.5 -2.5 102.5 2.5 {name=Y dir=out}}
}

if {[catch {xschem clear force} e]} { bail "no xschem command / clear failed: $e" }

# ======================================================================================
# V1: schematic, selection target: ipin A -> out; lab/pos/rot preserved; count returned.
# ======================================================================================
xschem load $work/s.sch
sel_inst p1
set n [xschem set_pin_type out]
check "v1: returns changed count" $n 1
set body [saved $work/o1.sch]
check "v1: A became opin, lab/pos kept" [ports $body] \
      {{p1 opin.sym A 0 0} {p2 opin.sym B 100 0}}
# rot preserved on the other one when IT changes:
sel_inst p2
xschem set_pin_type inout
set body [saved $work/o1b.sch]
check "v1: B became iopin" [lindex [ports $body] 1] {p2 iopin.sym B 100 0}
check "v1: B rot preserved" [regexp -line {^C \{devices/iopin\.sym\} 100 0 1 0} $body] 1

# ======================================================================================
# V2: named target (no selection needed) + -cycle stepping in->out->inout->in.
# ======================================================================================
xschem load $work/s.sch
xschem unselect_all
xschem set_pin_type -cycle p1     ;# in -> out
xschem set_pin_type -cycle p1     ;# out -> inout
set body [saved $work/o2.sch]
check "v2: two cycles in->inout" [lindex [ports $body] 0] {p1 iopin.sym A 0 0}
xschem set_pin_type -cycle p1     ;# inout -> in (wraps)
set body [saved $work/o2b.sch]
check "v2: third cycle wraps to in" [lindex [ports $body] 0] {p1 ipin.sym A 0 0}

# ======================================================================================
# V3: one undo slot for a multi-pin call; no-op call pushes nothing.
# ======================================================================================
xschem load $work/s.sch
xschem select_all                  ;# selects both ports + res; res must be ignored
set n [xschem set_pin_type inout]
check "v3: both ports changed, res ignored" $n 2
xschem undo
set body [saved $work/o3.sch]
check "v3: ONE undo restores both" [ports $body] \
      {{p1 ipin.sym A 0 0} {p2 opin.sym B 100 0}}
# no-op: already ipin -> ask for in again
sel_inst p1
set n [xschem set_pin_type in]
check "v3: no-op returns 0" $n 0
xschem undo   ;# must NOT revert past the load state weirdly: types unchanged either way
set body [saved $work/o3b.sch]
check "v3: no-op burnt no undo slot (types still original)" [ports $body] \
      {{p1 ipin.sym A 0 0} {p2 opin.sym B 100 0}}

# ======================================================================================
# V4: errors — bad type; named non-pin instance; empty selection returns 0.
# ======================================================================================
xschem load $work/s.sch
check "v4: bad type errors" [catch {xschem set_pin_type sideways}] 1
check "v4: non-pin named instance errors" [catch {xschem set_pin_type out R1}] 1
xschem unselect_all
check "v4: empty selection returns 0" [xschem set_pin_type out] 0

# ======================================================================================
# V5: symbol view — dir rewrite on selected pin rects, one undo, -cycle.
# ======================================================================================
xschem load $work/s.sym
xschem select_all
set n [xschem set_pin_type inout]
check "v5: both pin rects changed" $n 2
set body [saved $work/o5.sym]
check "v5: dirs rewritten" [pins $body] {{X inout} {Y inout}}
xschem undo
set body [saved $work/o5b.sym]
check "v5: ONE undo restores both dirs" [pins $body] {{X in} {Y out}}
xschem select_all
xschem set_pin_type -cycle
set body [saved $work/o5c.sym]
check "v5: cycle advances each independently" [pins $body] {{X out} {Y inout}}

# ======================================================================================
# V6: readonly rejected.
# ======================================================================================
xschem load $work/s.sch
xschem set readonly 1
sel_inst p1
check "v6: readonly rejects" [catch {xschem set_pin_type out}] 1
xschem set readonly 0

# ======================================================================================
# V7: gesture core — addpin::cycle_type falls back to placed-pin cycling when the
#     Add-Pin form is not placing (headless: no Tk, form branch self-guards).
# ======================================================================================
xschem load $work/s.sch
sel_inst p1
addpin::cycle_type
set body [saved $work/o7.sch]
check "v7: Ctrl+MMB core cycles selected placed pin" [lindex [ports $body] 0] \
      {p1 opin.sym A 0 0}

file delete -force $work
puts "PASS=$npass FAIL=$fail"
if {$fail == 0} { puts "OVERALL: ok"; exit 0 } else { puts "OVERALL: notok"; exit 1 }
