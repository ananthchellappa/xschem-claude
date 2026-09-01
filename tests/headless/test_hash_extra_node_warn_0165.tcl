# ERC warning for an `extra=` binding that names a '#'-leading node (issue 0165).
#
# '#' is the engine's PRIVATE marker for an auto-named net. Every wire/instance
# connection goes through net_name() (token.c ~4016), which strips it -- so a wire
# LABELLED `#hfoo` netlists as plain `hfoo`. But an `extra=` binding is a "hidden
# pin" passed as an instance ATTRIBUTE, and print_spice_element()'s generic @token
# branch writes its resolved value onto the call line VERBATIM. Measured,
# ngspice-42: `X1 topn #hfoo c` + `R9 hfoo 0 1k` gives TWO unconnected nodes in one
# deck (hfoo 0.0V, #hfoo 1.0V) from one name the user wrote once.
#
# DECIDED (0165 D1-D4): WARN, do not rewrite.
#   D1 warn   -- a strip would not even fix the shape: the child's .subckt PORT
#                list keeps its own '#' (token.c:2098) and so does the top-level
#                one (spice_netlist.c:375), so the port would stay split from its
#                body. Stripping properly means ~15 emission sites in 5 backends.
#   D2 loose  -- warn on any leading '#' that is NOT the engine's "#net<N>",
#                exactly the shape of the existing label-side warning at
#                netlist.c:1491. The two are complements: that one fires on the
#                LABEL half of this trap and structurally cannot reach the binding
#                half (it sits behind an IS_LABEL_OR_PIN gate on inst[i].node[0]).
#   D3 no backend changes -- the warning is output-neutral; HW0 pins that.
#   D4 resolved_net unchanged -- its contract is "the name the simulator actually
#                has", and that is still the unstripped one. 0163/0164's legs stay
#                green, which is the point of running them alongside this file.
#
# The check takes the RESOLVED value, never get_tok_value(prop_ptr, tok, 0): the
# value comes out of up to four translate3() rounds and may arrive by @-forwarding
# (HW10), from the symbol template (HW9), or from an expr(). It is gated on the
# symbol's extra= list via the shared attr_is_extra_node(), so an ordinary
# parameter (HW6) and a strict PREFIX of an extra entry (HW7) stay silent.
#
# Legs:
#   HW0        output neutrality: the call line still carries #hfoo verbatim
#   HW1-HW2    the warning fires, exactly once, naming instance/attribute/value
#   HW3        the LABEL half still warns -- both warnings in one run
#   HW4-HW5    D2's boundary: #net1 silent (engine auto-name), #net warns
#   HW6-HW7    the extra= gate: an ordinary parameter and an EXTRA/EXTRANET
#              prefix collision must both stay silent
#   HW8        a lone '#' warns
#   HW9        a TEMPLATE-sourced value warns (never appears on the instance)
#   HW10       an @-forwarded value warns, naming the RESOLVED name
#   HW11       a bus binding warns per element, naming only the offending one
#   HW12       spectre warns too (the other backend that silently mis-nodes)
#   HW13       a design with engine-auto-named nets and no bindings is silent
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_hash_extra_node_warn_0165.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_hash_extra_node_warn_0165.tcl

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
set scratch [test_scratch hash_extra_node_warn_0165]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

if {[catch {

# --- fixture ------------------------------------------------------------------
# child: extra="HN EXTRANET" declares TWO node attributes. The format string also
# names @EXTRA -- a strict PREFIX of the extra entry EXTRANET, which a strstr()
# membership test would wrongly let through -- and @MODEL, an ordinary parameter.
wfile [file join $scratch w0165_child.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @HN @EXTRANET @symname EXTRA=@EXTRA MODEL=@MODEL"
spectre_format="@name ( @pinlist @HN @EXTRANET ) @symname EXTRA=@EXTRA MODEL=@MODEL"
template="name=x1 HN=VDD EXTRANET=VDD EXTRA=zzz MODEL=nch"
extra="HN EXTRANET"}
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

wfile [file join $scratch w0165_child.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 200 -30 200 -100 {}
N 200 30 200 100 {}
N 400 0 500 0 {}
C {devices/res} 200 0 0 0 {name=R1 value=1k}
C {devices/iopin} 200 -100 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 100 0 0 {name=lHN lab=HN}
C {devices/lab_pin} 400 0 0 0 {name=lEN lab=EXTRANET}
C {devices/lab_pin} 500 0 0 0 {name=lEN2 lab=EXTRANET}}

# tchild: identical, except its TEMPLATE carries the '#' value. No instance in
# the top sets HN at all, so HW9 can only pass if the check reads the RESOLVED
# value rather than the instance's own property string.
wfile [file join $scratch w0165_tchild.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @HN @symname"
template="name=x1 HN=#tmplhash"
extra="HN"}
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

wfile [file join $scratch w0165_tchild.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 200 -30 200 -100 {}
N 200 30 200 100 {}
C {devices/res} 200 0 0 0 {name=R1 value=1k}
C {devices/iopin} 200 -100 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 100 0 0 {name=lHN lab=HN}}

# top: one instance per case, plus a wire LABELLED #hfoo so HW3 can see the
# label-side warning and the binding-side one in the same transcript.
wfile [file join $scratch w0165_top.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -30 0 -100 {}
N 0 30 0 100 {}
N 200 0 380 0 {}
N 700 -30 700 -100 {}
N 700 30 700 100 {}
C {devices/vsource} 0 0 0 0 {name=V1 value=1}
C {devices/lab_pin} 0 -100 0 0 {name=lT lab=topn}
C {devices/gnd} 0 100 0 0 {name=g1 lab=GND}
C {devices/lab_pin} 200 0 0 0 {name=lT2 lab=topn}
C {devices/res} 700 0 0 0 {name=R9 value=1k}
C {devices/lab_pin} 700 -100 0 0 {name=lH lab=#hfoo}
C {devices/gnd} 700 100 0 0 {name=g2 lab=GND}
C {w0165/w0165_child.sym} 400 0 0 0 {name=X1 HN=#hfoo}
C {w0165/w0165_child.sym} 400 200 0 0 {name=X2 HN=#net1}
C {w0165/w0165_child.sym} 400 400 0 0 {name=X3 HN=#net}
C {w0165/w0165_child.sym} 400 600 0 0 {name=X4 HN=#}
C {w0165/w0165_child.sym} 400 800 0 0 {name=X6 MODEL=#modelhash}
C {w0165/w0165_child.sym} 400 1000 0 0 {name=X7 EXTRA=#prefixhash}
C {w0165/w0165_child.sym} 400 1200 0 0 {name=X10 FWD=#fwdhash HN=@FWD}
C {w0165/w0165_child.sym} 400 1400 0 0 {name=X11 HN=aaa,#bushash}
C {w0165/w0165_tchild.sym} 400 1600 0 0 {name=X9}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE w0165 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch
set ::netlist_dir $scratch

# --- helpers ------------------------------------------------------------------
# Every 0165 warning line, i.e. the ones this file added. The transcript also
# carries unrelated "open net:" notices and the label-side warning, so match on
# the distinctive phrase rather than counting lines.
proc warnlines {} {
  set out {}
  foreach ln [split [xschem get infowindow_text] \n] {
    if {[string match {*binds a node whose name starts with*} $ln]} { lappend out [string trim $ln] }
  }
  return $out
}
# How many 0165 warnings name instance <inst>?
proc nwarn {inst} {
  set n 0
  foreach ln [warnlines] { if {[string match "*instance: $inst:*" $ln]} { incr n } }
  return $n
}
# The value quoted in <inst>'s warning, i.e. the text after "<tok>=" up to the
# next space. {} if <inst> was not warned about.
proc warnval {inst tok} {
  foreach ln [warnlines] {
    if {![string match "*instance: $inst:*" $ln]} continue
    if {[regexp "attribute ${tok}=(\\S+) " $ln -> v]} { return $v }
  }
  return {}
}
proc nlfile {ext} {
  global scratch
  set p [file join $scratch w0165_top$ext]
  if {![file exists $p]} { return {} }
  set f [open $p r]; set t [read $f]; close $f; return $t
}
proc nlline {txt pfx} {
  foreach ln [split $txt \n] {
    if {[string match "$pfx *" [string trim $ln]]} { return [string trim $ln] }
  }
  return {}
}

xschem load [file join $scratch w0165_top.sch]
xschem set netlist_type spice
xschem netlist
set spice_txt [nlfile .spice]

# --- HW0  output neutrality ---------------------------------------------------
# The whole point of D1 is that nothing in the deck moves. If this leg ever goes
# red the warning has become a rewrite.
check "HW0 (output neutrality) the binding still reaches the call line VERBATIM" \
  [expr {[string match {*#hfoo*} [nlline $spice_txt X1]] ? 1 : 0}] 1

# --- HW1-HW2  the warning fires, once, and names all three parts ---------------
check "HW1 an extra= binding to a '#' name warns exactly once" [nwarn X1] 1
check "HW2 the warning names the attribute and the offending value" \
  [warnval X1 HN] {#hfoo}

# --- HW3  the label half still warns ------------------------------------------
# netlist.c:1491's warning and this one are complements, and a user hitting the
# trap for real sees BOTH. If the label one ever stops firing, "the label half is
# already covered" (the argument for not widening this check) has quietly expired.
check "HW3 the LABEL half of the same trap still warns, in the same transcript" \
  [expr {[string match {*net name '#hfoo' starts with '#'*} [xschem get infowindow_text]] ? 1 : 0}] 1

# --- HW4-HW5  D2's boundary: loose, but not against the engine's own names -----
check "HW4 the engine's own auto-name #net1 must NOT warn" [nwarn X2] 0
check "HW5 '#net' with no index is NOT an auto-name and warns" \
  [list [nwarn X3] [warnval X3 HN]] [list 1 {#net}]

# --- HW6-HW7  the extra= gate --------------------------------------------------
check "HW6 an ordinary instance PARAMETER with a '#' value must NOT warn" [nwarn X6] 0
check "HW7 EXTRA must not ride in on the extra= entry EXTRANET" [nwarn X7] 0

# --- HW8  a lone '#' -----------------------------------------------------------
check "HW8 a lone '#' binding warns" [list [nwarn X4] [warnval X4 HN]] [list 1 {#}]

# --- HW9  a TEMPLATE-sourced value ---------------------------------------------
# X9 sets nothing; the '#' lives only in w0165_tchild.sym's template. This is the
# leg that fails if the check reads the instance's raw property string.
check "HW9 a value supplied only by the symbol TEMPLATE warns" \
  [list [nwarn X9] [warnval X9 HN]] [list 1 {#tmplhash}]

# --- HW10  @-forwarding --------------------------------------------------------
# HN=@FWD, FWD=#fwdhash. The raw attribute value is "@FWD" and contains no '#'.
check "HW10 an @-forwarded value warns, naming the RESOLVED name" \
  [list [nwarn X10] [warnval X10 HN]] [list 1 {#fwdhash}]

# --- HW11  bus elements --------------------------------------------------------
check "HW11 a bus binding warns per element, naming only the offending one" \
  [list [nwarn X11] [warnval X11 HN]] [list 1 {#bushash}]

# --- HW12  spectre -------------------------------------------------------------
# The other backend whose extra= value reaches the netlist verbatim and silently
# becomes a second node. Verilog and VHDL are deliberately NOT wired: verilog's
# leak is a hard syntax error ('#' is the delay operator) and VHDL turns extra
# tokens into generics, not nodes -- see 0165's "Which backends".
xschem set netlist_type spectre
xschem netlist
check "HW12 the spectre backend warns on the same binding" \
  [list [nwarn X1] [warnval X1 HN]] [list 1 {#hfoo}]
check "HW12b (output neutrality) spectre's call line is untouched" \
  [expr {[string match {*#hfoo*} [nlline [nlfile .spectre] X1]] ? 1 : 0}] 1

# --- HW13  a design with engine auto-names and no bindings is silent ------------
# The warning must fire on ZERO stock designs; this is the shape almost all of
# them have -- unnamed nets that the engine names #netN itself.
wfile [file join $scratch w0165_quiet.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -30 0 -100 {}
N 0 30 0 100 {}
N 0 -100 300 -100 {}
N 300 -100 300 -30 {}
N 300 30 300 100 {}
N 0 100 300 100 {}
C {devices/vsource} 0 0 0 0 {name=V1 value=1}
C {devices/res} 300 0 0 0 {name=R1 value=1k}
C {devices/gnd} 0 100 0 0 {name=g1 lab=GND}}
xschem set netlist_type spice
xschem load [file join $scratch w0165_quiet.sch]
xschem netlist
check "HW13 a design of engine-auto-named nets produces NO 0165 warning" \
  [llength [warnlines]] 0

} err]} { puts "FATAL: $err" ; incr fail }

# ISSUE 0977: THE DUAL BANNER, because this suite is now RUN by something.
#
# It was registered nowhere -- not in tests/run_regression.tcl's hcases, not in
# tests/headless/full_audit.sh's nogui_tests -- so nothing had ever run it, and
# it could not have been run by the regression runner even if it had been
# listed: banner_complete needs a whole-line "OVERALL:" as well as the RESULT
# line, and this file printed only the RESULT one. Both are here now, and the
# suite is registered in both places. It covers the netlist-time warning emitted
# from print_spice_element() in src/token.c, which is the very function issue
# 0970's "you typed this and it had no effect" check was added to; leaving it
# unrun meant a change in one could silently break the other.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
