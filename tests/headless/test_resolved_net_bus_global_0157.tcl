# resolved_net() truncates a bus at a global element (issue 0157).
#
# resolved_net() (src/hilight.c) expands a possibly-bussed net name and walks the
# hierarchy for each bus element, accumulating the per-element answers into `rnet`
# separated by ",". A global net (devices/gnd's `global=ground`, or any symbol with
# `global=true`) must NOT get the hierarchy path prefix -- globals are flat -- so the
# loop has a dedicated branch for them.
#
# That branch used my_strdup2(&rnet, ...) which REPLACES the accumulator, where the
# normal branch uses my_mstrcat(&rnet, path2, ...) which APPENDS. So ANY bus element
# that is a global discarded every element resolved before it, along with the comma
# already appended for it:
#
#   xschem resolved_net {TOP,GND}     -> GND        (should be TOP,GND)
#   xschem resolved_net {TOP,GND,VSS} -> VSS        (should be TOP,GND,VSS)
#   xschem resolved_net {GND,TOP}     -> GND,TOP    (correct -- order hides the bug)
#
# It is not only the `xschem resolved_net` verb: the same string feeds
# send_net_to_graph() (src/hilight.c:1595, which fans it out per bit into the
# waveform graph) and translate()'s `@#<pin>:resolved_net` attribute
# (src/token.c:4253), so a truncated bus reaches netlists and plots too. RB8 pins
# the translate() consumer so the fix is witnessed downstream of the verb.
#
# Legs (RB*):
#   RB0        fixture witness: which names the engine considers global.
#   RB1-RB4    top level, the defect: a global at k>0 must APPEND, not replace.
#   RB5-RB7    top level controls that already passed (leading global, scalars).
#   RB8-RB9    downstream witness through translate() `@#0:resolved_net`.
#   RB10       bracket-bus expansion is untouched by the fix.
#   RB11-RB15  descended (currsch=1): path prefix on locals, NO prefix on globals,
#              and both still accumulate.
#   RB16       after go_back the top-level answer is stable again.
#
# Has teeth in BOTH arms (nothing here is has_x gated). Run either of:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_resolved_net_bus_global_0157.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_resolved_net_bus_global_0157.tcl

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
set scratch [test_scratch resolved_net_bus_0157]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

if {[catch {

# --- fixture -----------------------------------------------------------------
# parent: X1 (a subcircuit) whose pin A is WIRED to the named net TOP (the wire must
# land on the pin rect centre at -20,0 -- leave it short and the pin dangles onto an
# auto-named #netN instead, which would make RB15 assert an accident), two grounds
# (GND and VSS, both registered global by devices/gnd's `global=ground`), and a
# lab_pin carrying the 2-element bus label "D,GND" so translate() has a bussed pin.
# child:  port A (-> resolves up to TOP), a purely local net LOC (no port, so it
# keeps the X1. prefix), and GND.
wfile [file join $scratch rn0157_child.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
F {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

wfile [file join $scratch rn0157_child.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 100 0 {}
N 200 0 300 0 {}
N 300 0 300 60 {}
C {devices/iopin} 0 0 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 0 0 0 {name=lLOC lab=LOC}
C {devices/gnd} 300 60 0 0 {name=gG1 lab=GND}}

wfile [file join $scratch rn0157_parent.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 -20 0 {}
N 400 0 500 0 {}
N 400 100 500 100 {}
N 600 0 700 0 {}
C {rn0157/rn0157_child.sym} 0 0 0 0 {name=X1}
C {devices/lab_pin} -100 0 0 0 {name=lTOP lab=TOP}
C {devices/gnd} 500 0 0 0 {name=gG2 lab=GND}
C {devices/gnd} 500 100 0 0 {name=gV1 lab=VSS}
C {devices/lab_pin} 600 0 0 0 {name=lBUS lab="D,GND"}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE rn0157 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch

xschem load [file join $scratch rn0157_parent.sch]
xschem nets     ;# runs prepare_netlist_structs, which is what registers the globals

# --- RB0  fixture witness ----------------------------------------------------
# record_global_node(3,..) is a read-only lookup: non-zero => the engine treats the
# name as a flat global. If this leg ever goes red the rest of the file is vacuous.
check "RB0 GND and VSS are global, TOP is not" \
  [list [expr {[xschem record_global_node 3 GND] != 0}] \
        [expr {[xschem record_global_node 3 VSS] != 0}] \
        [expr {[xschem record_global_node 3 TOP] != 0}]] {1 1 0}

# --- RB1-RB4  the defect: a global at k>0 must not eat the accumulator ---------
check "RB1 trailing global keeps the earlier element" \
  [xschem resolved_net {TOP,GND}] {TOP,GND}
check "RB2 global in the middle keeps both neighbours" \
  [xschem resolved_net {TOP,GND,VSS}] {TOP,GND,VSS}
check "RB3 two adjacent globals both survive" \
  [xschem resolved_net {GND,VSS}] {GND,VSS}
check "RB4 the reported repro {D,GND}" \
  [xschem resolved_net {D,GND}] {D,GND}

# --- RB5-RB7  controls that already passed before the fix ---------------------
check "RB5 (control) leading global, order hid the bug" \
  [xschem resolved_net {GND,TOP}] {GND,TOP}
check "RB6 (control) scalar non-global" [xschem resolved_net {TOP}] {TOP}
check "RB7 (control) scalar global (whole-net early return)" \
  [xschem resolved_net {GND}] {GND}

# --- RB8-RB9  downstream witness: translate() @#<pin>:resolved_net -------------
# token.c expands this attribute during netlisting, so the truncation was not
# confined to the Tcl verb.
check "RB8 translate @#0:resolved_net on the bussed pin is not truncated" \
  [xschem translate lBUS {@#0:resolved_net}] {D,GND}
check "RB9 (control) translate @#0:resolved_net on a scalar pin" \
  [xschem translate lTOP {@#0:resolved_net}] {TOP}

# --- RB10  bracket bus expansion is untouched --------------------------------
check "RB10 (control) bracket bus still expands per bit" \
  [xschem resolved_net {D[1:0]}] {D[1],D[0]}

# --- RB11-RB15  descended into X1 --------------------------------------------
xschem unselect_all
xschem select instance 0
xschem descend
check "RB11 (control) descend reached X1" \
  [list [xschem get currsch] [xschem get sch_path]] {1 .X1.}
check "RB12 (control) a local net gets the hierarchy prefix" \
  [xschem resolved_net {LOC}] {X1.LOC}
check "RB13 (control) a global stays flat, no X1. prefix" \
  [xschem resolved_net {GND}] {GND}
check "RB14 prefixed local + flat global accumulate together" \
  [xschem resolved_net {LOC,GND}] {X1.LOC,GND}
check "RB15 local + global + port-mapped net, all three survive" \
  [xschem resolved_net {LOC,GND,A}] {X1.LOC,GND,TOP}
check "RB15a (control) the port alone resolves up to the parent net" \
  [xschem resolved_net {A}] {TOP}
check "RB15b (control) leading global at depth" \
  [xschem resolved_net {GND,LOC}] {GND,X1.LOC}

# --- RB16  back at the top level ---------------------------------------------
xschem go_back
check "RB16 top-level answer stable after go_back" \
  [list [xschem get currsch] [xschem resolved_net {TOP,GND}]] {0 TOP,GND}

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
