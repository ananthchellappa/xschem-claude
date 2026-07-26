# resolved_net() leaks '#' on every bus element after the first (issue 0158).
#
# An unlabeled net is `#netN` in the schematic and `netN` in the netlist/.raw, so
# resolved_net() -- whose whole job is to produce the simulator-side name -- strips a
# leading '#'. It did that ONCE, on the WHOLE incoming token, BEFORE expandlabel()
# split it into bus elements (src/hilight.c:2602), so only element 0 was ever
# stripped:
#
#   xschem resolved_net {#net1,TOP} -> net1,TOP   (correct)
#   xschem resolved_net {TOP,#net1} -> TOP,#net1  (leaked)
#   xschem resolved_net {#a,#b}     -> a,#b
#
# Descended it is worse, because the leaked '#' lands in the MIDDLE of the answer,
# after the hierarchy prefix: {LOC,#x} -> X1.LOC,X1.#x.
#
# The strip is LOOSE (any leading '#', not the strict `is_auto_net_name()` added by
# 0156) and stays loose: measured, a user-authored `lab=#foo` netlists as plain `foo`
# (`R1 foo net1 1k`), so the loose strip is exactly what the netlist does. 0156's rule
# was that output-strip sites stay loose; this is one.
#
# Legs (HS*):
#   HS0-HS1    fixture witness: the engine really does produce a `#netN` name here,
#              and it is picked up from `xschem nets` rather than hardcoded, so a
#              renumbering fails the witness instead of silently skewing a leg.
#   HS2-HS7    the defect, on a real auto-named net and on synthetic tokens.
#   HS8-HS11   controls the fix must NOT move: leading '#', bracket bus (the '#'
#              distributes over the bits inside expandlabel), and `##a` losing
#              exactly one '#'.
#   HS12-HS13  the degenerate lone "#" element: it must NOT be stripped to the empty
#              string, which would emit a stray "," (see `my_strcat(&rnet, ",")`).
#   HS14-HS15  interaction with issue 0157's global-append fix.
#   HS16-HS19  descended: prefix and strip both applied, per element.
#
# Has teeth in BOTH arms. Run either of:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_resolved_net_hash_bus_0158.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_resolved_net_hash_bus_0158.tcl

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
set scratch [test_scratch resolved_net_hash_0158]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

if {[catch {

# --- fixture -----------------------------------------------------------------
# parent: X1's pin A wired to the named net TOP (the wire must reach the pin rect
# centre at -20,0), a ground GND, and R1 with a free wire stub so the engine mints
# at least one real auto-named `#netN`.
# child:  port A, a purely local net LOC (no port -> keeps the X1. prefix), GND.
wfile [file join $scratch h0158_child.sym] {v {xschem version=3.4.8RC file_version=1.3}
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

wfile [file join $scratch h0158_child.sch] {v {xschem version=3.4.8RC file_version=1.3}
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

wfile [file join $scratch h0158_parent.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 -20 0 {}
N 400 0 500 0 {}
N 600 0 700 0 {}
N 600 -200 600 -140 {}
N 900 0 1000 0 {}
C {h0158/h0158_child.sym} 0 0 0 0 {name=X1}
C {devices/lab_pin} -100 0 0 0 {name=lTOP lab=TOP}
C {devices/gnd} 500 0 0 0 {name=gG2 lab=GND}
C {devices/res} 600 -100 0 0 {name=R1 value=1k}
C {devices/lab_pin} 900 0 0 0 {name=lBUS lab="D,#net9"}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE h0158 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch

xschem load [file join $scratch h0158_parent.sch]

# --- HS0-HS1  fixture witness -------------------------------------------------
# Take the auto-named net from the engine instead of hardcoding `#net1`: if the
# numbering ever shifts, HS0 fails loudly rather than HS2 asserting an accident.
set auto {}
foreach d [xschem nets] {
  set n [lindex $d 1]
  if {[string index $n 0] eq {#}} { set auto $n ; break }
}
check "HS0 the fixture really mints an auto-named #netN" \
  [expr {[regexp {^#net[0-9]+$} $auto] ? 1 : 0}] 1
set bare [string range $auto 1 end]

check "HS1 (control) the auto net alone is stripped (it is element 0)" \
  [xschem resolved_net $auto] $bare

# --- HS2-HS7  the defect ------------------------------------------------------
check "HS2 a real auto net in the SECOND position keeps its #" \
  [xschem resolved_net "TOP,$auto"] "TOP,$bare"
check "HS3 both elements stripped" [xschem resolved_net {#a,#b}] {a,b}
check "HS4 trailing element stripped" [xschem resolved_net {a,#b}] {a,b}
check "HS5 middle element stripped"  [xschem resolved_net {a,#b,c}] {a,b,c}
check "HS6 element after a bracket-bus expansion" \
  [xschem resolved_net {a[1:0],#b}] {a[1],a[0],b}
check "HS7 two auto-shaped names in a row" \
  [xschem resolved_net {#net1,#net2}] {net1,net2}

# --- HS8-HS11  controls the fix must not move ---------------------------------
check "HS8 (control) leading element, the case that already worked" \
  [xschem resolved_net {#a,b}] {a,b}
check "HS9 (control) a plain bus is untouched" \
  [xschem resolved_net {a,b}] {a,b}
check "HS10 (control) '#' distributes over bracket bits inside expandlabel" \
  [xschem resolved_net {#a[1:0]}] {a[1],a[0]}
check "HS11 (control) exactly ONE '#' comes off" \
  [xschem resolved_net {##a}] {#a}

# --- HS12-HS13  the lone "#" element ------------------------------------------
# Stripping "#" to "" would make my_mstrcat append nothing while the separator is
# still written, i.e. "a,". Refuse to strip when nothing would be left.
check "HS12 a lone '#' element is left alone, no stray comma" \
  [xschem resolved_net {a,#}] {a,#}
check "HS13 a lone '#' as the whole net stays '#' (was silently EMPTY before)" \
  [xschem resolved_net {#}] {#}

# --- HS14-HS15  interaction with issue 0157 -----------------------------------
check "HS14 strip after a global element (0157 append + 0158 strip)" \
  [xschem resolved_net {GND,#a}] {GND,a}
check "HS15 (control) strip before a global element" \
  [xschem resolved_net {#a,GND}] {a,GND}

# --- HS15a  downstream witness: translate() @#<pin>:resolved_net ---------------
# token.c expands this attribute during netlisting, so the leak was not confined to
# the Tcl verb -- it reached netlist cards naming a net that does not exist.
check "HS15a translate @#0:resolved_net does not emit a leaked '#'" \
  [xschem translate lBUS {@#0:resolved_net}] {D,net9}

# --- HS16-HS19  descended ------------------------------------------------------
xschem unselect_all
xschem select instance 0
xschem descend
check "HS16 (control) descend reached X1" \
  [list [xschem get currsch] [xschem get sch_path]] {1 .X1.}
check "HS17 (control) leading element gets stripped then prefixed" \
  [xschem resolved_net {#x,LOC}] {X1.x,X1.LOC}
check "HS18 a later element must not carry '#' into the middle of the name" \
  [xschem resolved_net {LOC,#x}] {X1.LOC,X1.x}
check "HS19 prefix, leak and global all in one bus" \
  [xschem resolved_net {LOC,#x,GND}] {X1.LOC,X1.x,GND}

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
