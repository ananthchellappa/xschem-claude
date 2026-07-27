# resolved_net() trusts any instance attribute whose name matches a net name (issue 0163).
#
# resolved_net() walks up the hierarchy and, at each level, first asks "was this net
# passed down by an ATTRIBUTE rather than through a port?" by doing
#
#   get_tok_value(xctx->hier_attr[level - 1].prop_ptr, resolved_net, 0)
#
# hier_attr[].prop_ptr is the parent instance's ENTIRE property string, so that reaches
# every attribute on the instance -- `value`, `spice_ignore`, `name`, `m`, `wn`, ... --
# and whichever one happens to be spelled like the net REPLACES the net name:
#
#   resolved_net {value}        -> 1k        (should be X1.value)
#   resolved_net {spice_ignore} -> false     (should be X1.spice_ignore)
#   resolved_net {name}         -> X1        (should be X1.name)
#
# The issue doc's second symptom -- a '#' in such a value coming back out with the '#'
# still attached -- turned out NOT to be a defect. MEASURED, ngspice-42: an extra= value
# reaches the subckt call line VERBATIM (`X1 topn #hfoo c`) and ngspice names that node
# `#hfoo`, while a wire LABELLED `#hfoo` netlists as plain `hfoo` -- two different,
# unconnected nodes in one deck (hfoo 0.0V, #hfoo 1.0V). So verbatim is the right answer
# here; the portmap path strips only because a pin-passed `#net1` really is `net1`
# downstream. A strip was shipped and reverted once measured. AS1b/AS13/AS18 pin it.
#
# The lookup is NOT junk: it implements the `extra=` idiom. A symbol's extra= attribute
# is the list of attributes the netlister treats as NODES rather than instance parameters
# (src/token.c "extra is the list of attributes NOT to consider as instance parameters";
# print_spice_subckt_nodes() emits them as subckt ports). Measured on the stock library:
#
#   xschem_library/rom8k/lvnot.sym: extra="VCCPIN VSSPIN"
#   -> .subckt lvnot y a VCCPIN VSSPIN ...   /   x10 FN DDN vcc vss lvnot ...
#
# so descending into that instance, VCCPIN really must resolve to vcc. The fix keeps that
# and blocks everything else, by gating the lookup on hier_attr[].sym_extra -- which was
# already captured next to prop_ptr at all four write sites (actions.c, save.c,
# spice_netlist.c, spectre_netlist.c) and, before this fix, read nowhere.
#
# Legs (AS*):
#   AS0-AS2    fixture witness: the fixture's extra= really produces subckt PORTS, taken
#              from the generated netlist rather than asserted, so a format/extra typo
#              fails the witness instead of skewing every later leg.
#   AS3-AS7    the defect: value / spice_ignore / name / a stray attr / a substring of an
#              extra entry must all stop hijacking.
#   AS8-AS12   controls the fix must NOT move: the extra-listed binding still resolves,
#              the port path, the global, and a plain local net.
#   AS13-AS15  the '#' on the attribute VALUE (problem 2). It is kept VERBATIM -- the
#              netlist witness AS1b is why.
#   AS16-AS18  bus elements: hijack, legit binding and '#' strip, each per element.
#   AS19-AS20  a symbol with NO extra= at all blocks every attribute.
#   AS21-AS23  depth 2: the level walk, both the hijack and the legit chain.
#   AS24       not descended -> the loop is not entered at all.
#   AS25-AS28  STOCK LIBRARY witnesses, no synthetic fixture: rom8k/rom2_predec1's
#              x9[15:0] carries a stray VSSBPIN=VSS that lvnor2.sym's extra does not
#              list, while lvnor2.sch really does have wires labelled VSSBPIN; and
#              LD2QHDX4stef's x10 has m=1 wn=8.4u. These are the real-world hits.
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_resolved_net_attr_scope_0163.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_resolved_net_attr_scope_0163.tcl

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
set scratch [test_scratch resolved_net_attr_scope_0163]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

# `xschem select instance` wants an index; addressing by instname keeps the legs
# readable and fails loudly if the fixture is renamed.
proc inst_index {want} {
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[xschem getprop instance $i name] eq $want} { return $i }
  }
  return -1
}

if {[catch {

# =============================================================================
# AS25-AS28  STOCK LIBRARY witnesses -- run FIRST, before the fixture below
# repoints XSCHEM_LIBRARY_DEFS/PATH at the scratch dir.
# =============================================================================
xschem load [file join $repo xschem_library rom8k rom2_predec1.sch]
set idx [inst_index {x9[15:0]}]
check "AS25 (fixture witness) the stock vector instance x9\[15:0\] was found" \
  [expr {$idx >= 0 ? 1 : 0}] 1
xschem unselect_all
xschem select instance $idx
xschem descend 1                            ;# instance number, so no interactive prompt
check "AS26 (control) descended into lvnor2 via x9\[15\]" \
  [list [xschem get sch_path] [file tail [xschem get schname]]] [list {.x9[15].} lvnor2.sch]
# lvnor2.sym has extra="VCCPIN VSSPIN": VCCPIN is a real subckt port and must resolve up.
check "AS27 (control) an extra=-listed attribute still rebinds the net" \
  [xschem resolved_net VCCPIN] {vcc}
# VSSBPIN is NOT in lvnor2.sym's extra= and NOT in its format string, so `.subckt lvnor2
# y a b VCCPIN VSSPIN` has no VSSBPIN port -- the VSSBPIN wires in lvnor2.sch are LOCAL.
# The stray VSSBPIN=VSS on the x9 instance must not rename them.
check "AS28 a stray attribute not listed in extra= must not hijack a local net" \
  [xschem resolved_net VSSBPIN] {x9[15].VSSBPIN}
xschem go_back

xschem load [file join $repo xschem_library rom8k LD2QHDX4stef.sch]
xschem unselect_all
xschem select instance [inst_index x10]
xschem descend
check "AS29 (control) descended into lvnot via x10" \
  [list [xschem get sch_path] [file tail [xschem get schname]]] [list {.x10.} lvnot.sch]
check "AS30 (control) lvnot's extra= nodes still resolve" \
  [list [xschem resolved_net VCCPIN] [xschem resolved_net VSSPIN]] [list vcc vss]
check "AS31 a plain instance PARAMETER must not be readable as a net" \
  [list [xschem resolved_net m] [xschem resolved_net wn]] [list x10.m x10.wn]
xschem go_back

# =============================================================================
# synthetic fixture
# =============================================================================
# child: extra="EXTRANET EXTRA2 EXTRA3" -> those three are subckt PORTS. It also owns
# nets deliberately named like ordinary instance attributes (value, spice_ignore, name),
# a purely local net LOC, a global GND, a port A, and EXTRA -- a strict PREFIX of the
# extra entry EXTRANET, which a strstr()-based membership test would wrongly let through.
wfile [file join $scratch a0163_child.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @EXTRANET @EXTRA2 @EXTRA3 @symname value=@value"
template="name=x1 value=1k EXTRANET=VDD EXTRA2=VDD EXTRA3=VDD"
extra="EXTRANET EXTRA2 EXTRA3"}
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

wfile [file join $scratch a0163_child.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 100 0 {}
N 200 0 300 0 {}
N 200 100 300 100 {}
N 200 200 300 200 {}
N 200 300 300 300 {}
N 200 400 300 400 {}
N 200 500 300 500 {}
N 200 600 300 600 {}
N 200 700 300 700 {}
N 200 800 300 800 {}
N 300 0 300 60 {}
C {devices/iopin} 0 0 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 0 0 0 {name=lLOC lab=LOC}
C {devices/lab_pin} 200 100 0 0 {name=lVAL lab=value}
C {devices/lab_pin} 200 200 0 0 {name=lSI lab=spice_ignore}
C {devices/lab_pin} 200 300 0 0 {name=lNM lab=name}
C {devices/lab_pin} 200 400 0 0 {name=lEN lab=EXTRANET}
C {devices/lab_pin} 200 500 0 0 {name=lE2 lab=EXTRA2}
C {devices/lab_pin} 200 600 0 0 {name=lE3 lab=EXTRA3}
C {devices/lab_pin} 200 700 0 0 {name=lEX lab=EXTRA}
C {devices/lab_pin} 200 800 0 0 {name=lER lab=EXTR}
C {a0163/a0163_gchild.sym} 600 0 0 0 {name=X2 gvalue=7k GEXTRA=EXTRANET}
C {devices/gnd} 300 60 0 0 {name=gG1 lab=GND}}

# grandchild: one extra= node (GEXTRA) and one net named like its own parameter (gvalue),
# so the depth-2 legs exercise the level walk in both directions.
wfile [file join $scratch a0163_gchild.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @GEXTRA @symname gvalue=@gvalue"
template="name=x1 gvalue=1k GEXTRA=VDD"
extra="GEXTRA"}
V {}
S {}
F {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

wfile [file join $scratch a0163_gchild.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 200 0 300 0 {}
N 200 100 300 100 {}
C {devices/lab_pin} 200 0 0 0 {name=lGV lab=gvalue}
C {devices/lab_pin} 200 100 0 0 {name=lGE lab=GEXTRA}}

# plain child: NO extra= at all, and a net named `value`.
wfile [file join $scratch a0163_plain.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @symname value=@value"
template="name=x1 value=1k"}
V {}
S {}
F {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

wfile [file join $scratch a0163_plain.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 200 0 300 0 {}
C {devices/lab_pin} 200 0 0 0 {name=lPV lab=value}}

wfile [file join $scratch a0163_parent.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 -20 0 {}
N 400 0 500 0 {}
C {a0163/a0163_child.sym} 0 0 0 0 {name=X1 value=1k spice_ignore=false EXTRANET=TOPN EXTRA2=#foo EXTRA3=# EXTRA=zzz EXTR=yyy}
C {a0163/a0163_plain.sym} 0 400 0 0 {name=X3 value=2k}
C {devices/lab_pin} -100 0 0 0 {name=lTOP lab=TOP}
C {devices/gnd} 500 0 0 0 {name=gG2 lab=GND}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE a0163 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch

xschem load [file join $scratch a0163_parent.sch]

# --- AS0-AS2  fixture witness -------------------------------------------------
# Prove from the GENERATED NETLIST that this fixture's extra= really creates subckt
# PORTS. If it does not, the "control" legs below would be asserting nothing.
set ::netlist_dir $scratch
xschem set netlist_type spice
xschem netlist
set nl [file join $scratch a0163_parent.spice]
check "AS0 (fixture witness) the netlist was written" [file exists $nl] 1
set txt ""
if {[file exists $nl]} { set fh [open $nl r]; set txt [read $fh]; close $fh }
set subline ""
foreach ln [split $txt \n] {
  if {[string match ".subckt a0163_child *" $ln]} { set subline $ln ; break }
}
check "AS1 (fixture witness) extra= names really are subckt PORTS" \
  [expr {[regexp {^\.subckt a0163_child A EXTRANET EXTRA2 EXTRA3\M} $subline] ? 1 : 0}] 1
check "AS2 (fixture witness) a NON-extra attribute is a parameter, not a port" \
  [expr {[regexp {\mvalue=} $subline] ? 1 : 0}] 1
# AS1b is the whole justification for keeping the '#': the netlister passes an extra=
# value onto the CALL LINE verbatim, and ngspice-42 then names that node `#foo`. A wire
# labelled `#foo` netlists as plain `foo` -- a DIFFERENT node.
set callline ""
foreach ln [split $txt \n] {
  if {[string match "X1 *" $ln]} { set callline $ln ; break }
}
check "AS1b (fixture witness) an extra= value reaches the call line VERBATIM, '#' and all" \
  [expr {[string match {*#foo*} $callline] ? 1 : 0}] 1

# --- AS24  not descended ------------------------------------------------------
check "AS24 (control) at the top level the attribute loop is not entered at all" \
  [xschem resolved_net value] {value}

xschem unselect_all
xschem select instance 0
xschem descend
check "AS3a (control) descend reached X1" \
  [list [xschem get currsch] [xschem get sch_path]] [list 1 {.X1.}]

# --- AS3-AS7  the defect ------------------------------------------------------
check "AS3 a net named `value` must not become the instance's value attribute" \
  [xschem resolved_net value] {X1.value}
check "AS4 a net named `spice_ignore` must not become that attribute's value" \
  [xschem resolved_net spice_ignore] {X1.spice_ignore}
check "AS5 a net named `name` must not become the instance name" \
  [xschem resolved_net name] {X1.name}
check "AS6 an arbitrary stray attribute must not hijack a net" \
  [xschem resolved_net EXTRA] {X1.EXTRA}
check "AS7 membership in extra= is an EXACT token match, not a substring" \
  [xschem resolved_net EXTR] {X1.EXTR}

# --- AS8-AS12  controls the fix must not move ---------------------------------
check "AS8 (control) an extra=-listed attribute still rebinds the net" \
  [xschem resolved_net EXTRANET] {TOPN}
check "AS9 (control) a port still resolves up through the portmap" \
  [xschem resolved_net A] {TOP}
check "AS10 (control) a global stays flat" [xschem resolved_net GND] {GND}
check "AS11 (control) a plain local net keeps the hierarchy prefix" \
  [xschem resolved_net LOC] {X1.LOC}
check "AS12 (control) an auto-named net still gets stripped and prefixed" \
  [xschem resolved_net {#x}] {X1.x}

# --- AS13-AS15  the '#' on the attribute VALUE (problem 2) --------------------
check "AS13 a '#' in an extra= attribute value is kept VERBATIM" \
  [xschem resolved_net EXTRA2] {#foo}
check "AS14 (control) a lone '#' value is passed through untouched" \
  [xschem resolved_net EXTRA3] {#}
check "AS15 (control) exactly one '#' comes off" \
  [xschem resolved_net EXTRANET] {TOPN}

# --- AS16-AS18  bus elements ---------------------------------------------------
check "AS16 a hijacked element inside a bus" \
  [xschem resolved_net {value,LOC}] {X1.value,X1.LOC}
check "AS17 a legit binding inside a bus" \
  [xschem resolved_net {EXTRANET,LOC}] {TOPN,X1.LOC}
check "AS18 the verbatim value survives per element, after a global" \
  [xschem resolved_net {GND,EXTRA2}] {GND,#foo}

# --- AS21-AS23  depth 2 --------------------------------------------------------
xschem unselect_all
xschem select instance [inst_index X2]
xschem descend
check "AS21 (control) descend reached X1.X2" \
  [list [xschem get currsch] [xschem get sch_path]] [list 2 {.X1.X2.}]
check "AS22 a hijack two levels down" [xschem resolved_net gvalue] {X1.X2.gvalue}
# GEXTRA is bound on X2 to EXTRANET, which is itself extra-bound on X1 to TOPN:
# the level walk must follow the whole chain.
check "AS23 a legit extra= chain resolves through BOTH levels" \
  [xschem resolved_net GEXTRA] {TOPN}
xschem go_back
xschem go_back

# --- AS19-AS20  a symbol with no extra= at all ---------------------------------
xschem unselect_all
xschem select instance [inst_index X3]
xschem descend
check "AS19 (control) descend reached X3" \
  [list [xschem get currsch] [xschem get sch_path]] [list 1 {.X3.}]
check "AS20 with no extra= on the symbol, no attribute may rebind a net" \
  [xschem resolved_net value] {X3.value}
xschem go_back

} err]} {
  puts "FATAL: $err"
  incr fail
}

puts "----"
# House banner form: full_audit.sh is_pass() scores on "RESULT: ALL PASS".
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
