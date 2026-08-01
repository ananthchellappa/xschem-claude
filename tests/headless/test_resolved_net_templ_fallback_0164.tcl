# resolved_net() ignores the symbol template default for an extra= node (issue 0164).
#
# A symbol declares "hidden pins" -- connections passed as attributes rather than drawn as
# pins -- with `extra=` (doc/xschem_man/symbol_property_syntax.html:284-305). Issue 0163
# scoped resolved_net()'s attribute loop to exactly those. But it reads only the parent
# INSTANCE's property string, while the netlister falls back to the symbol TEMPLATE when
# the instance does not carry the attribute at all -- src/token.c:5206-5209, inside
# translate():
#
#     value = get_tok_value(xctx->inst[inst].prop_ptr, token+1, 0);
#     if(!xctx->tok_size && xctx->inst[inst].ptr >= 0) {
#       value = get_tok_value(xctx->sym[xctx->inst[inst].ptr].templ, token+1, 0);
#     }
#
# Note the guard is `!xctx->tok_size` -- "the token does not EXIST in the instance
# attributes" -- NOT "its value is empty". Measured, and the distinction is real: an
# instance carrying `VCCPIN=""` gets NO node in the netlist, it does not inherit the
# template default. Legs TF6/TF10 below are what tell the two implementations apart.
#
# So resolved_net returned the LOCAL name for a node the simulator got from the template:
#
#     .subckt c A VCCPIN
#     X1 TOP1 VCC c            <- X1 omits VCCPIN, so its node comes from the template
#   descended into X1:
#     xschem resolved_net {VCCPIN}  ->  X1.VCCPIN     (should be VCC)
#
# The trace is then simply not found and the plot comes up empty with no error -- the same
# silent failure mode as 0158 and 0163. xctx->hier_attr[].templ is captured next to
# .prop_ptr at every write site (actions.c:3584, save.c:5590, spice_netlist.c:472,
# spectre_netlist.c:358) for exactly this.
#
# Reachability: xschem's own set_inst_prop() (editprop.c:213) copies the WHOLE template into
# a newly placed instance, so GUI-placed instances carry the attributes and never hit this.
# It bites a hand-edited file, a generator/script-written instance, and -- the realistic
# route -- a symbol whose template GAINS an extra= attribute after its instances were placed.
#
# Legs (TF*):
#   TF0-TF5    fixture witness, taken from the GENERATED NETLIST rather than asserted: the
#              extra= names really are subckt ports, and the four instance shapes really do
#              emit the nodes claimed (template default / explicit / empty / no default).
#   TF6-TF9    the defect and its controls at depth 1.
#   TF10-TF12  present-but-empty and no-default-anywhere must NOT inherit -- these are the
#              legs that fail if the fallback is written as `!ptr[0]` instead of tok_size.
#   TF13-TF15  depth 2: the fallback must compose across levels, exactly as the netlister's
#              chain does (g's template -> c's template / c's instance attribute).
#   TF16-TF17  0163 must not regress: a non-extra attribute stays blocked even when the
#              TEMPLATE carries it.
#   TF18-TF19  a template-sourced value keeps a leading '#' VERBATIM, per element --
#              see issue 0163's Correction section for the ngspice measurement.
#   TF20-TF21  top level untouched; stock-library behaviour unchanged (every shipped
#              extra= instance spells the attribute out, so nothing in-tree may move).
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_resolved_net_templ_fallback_0164.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_resolved_net_templ_fallback_0164.tcl

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
set scratch [test_scratch resolved_net_templ_fallback_0164]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

proc inst_index {want} {
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[xschem getprop instance $i name] eq $want} { return $i }
  }
  return -1
}

if {[catch {

# =============================================================================
# TF21  STOCK LIBRARY control -- run FIRST, before the fixture repoints the
# library defs. Every shipped extra= instance spells its attributes out, so this
# fix must not move anything in-tree.
# =============================================================================
xschem load [file join $repo xschem_library rom8k LD2QHDX4stef.sch]
xschem unselect_all
xschem select instance [inst_index x10]
xschem descend
check "TF21 (control) stock rom8k lvnot: explicit extra= attributes unchanged" \
  [list [xschem resolved_net VCCPIN] [xschem resolved_net VSSPIN]] [list vcc vss]
xschem go_back

# =============================================================================
# synthetic fixture
# =============================================================================
# grandchild g: extra="GX", template default GX=VCCPIN -- so a resolved GX chains
# straight onto c's OWN extra node and the walk has to cross two levels.
wfile [file join $scratch g.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @GX @symname"
template="name=x1 GX=VCCPIN"
extra="GX"}
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

wfile [file join $scratch g.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 100 0 {}
N 200 0 300 0 {}
C {devices/iopin} 0 0 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 0 0 0 {name=lG lab=GX}}

# child c: extra="VCCPIN HASHN", template supplies defaults for both, plus a NON-extra
# parameter `pval` whose name is also a net inside c.sch -- 0163's gate must keep
# blocking that even though the template carries it.
wfile [file join $scratch c.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @VCCPIN @HASHN @symname pval=@pval"
template="name=x1 pval=7k VCCPIN=VCC HASHN=#hfoo"
extra="VCCPIN HASHN"}
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

wfile [file join $scratch c.sch] {v {xschem version=3.4.8RC file_version=1.3}
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
N 400 0 480 0 {}
C {devices/iopin} 0 0 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 0 0 0 {name=lV lab=VCCPIN}
C {devices/lab_pin} 200 100 0 0 {name=lH lab=HASHN}
C {devices/lab_pin} 200 200 0 0 {name=lP lab=pval}
C {devices/lab_pin} 200 300 0 0 {name=lL lab=LOCAL}
C {devices/lab_pin} 400 0 0 0 {name=lY lab=YIN}
C {t0164/g.sym} 500 0 0 0 {name=Y1}}

# n: extra="NX" but the template gives NO default for NX -- neither side supplies it.
wfile [file join $scratch n.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @NX @symname"
template="name=x1"
extra="NX"}
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

wfile [file join $scratch n.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 100 0 {}
N 200 0 300 0 {}
C {devices/iopin} 0 0 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 0 0 0 {name=lN lab=NX}}

# X1 omits the attributes (template default applies), X2 sets one explicitly,
# X5 carries it PRESENT BUT EMPTY (no template inheritance), X3 has no default anywhere.
wfile [file join $scratch p.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N -100 0 -20 0 {}
N -100 300 -20 300 {}
N -100 600 -20 600 {}
N -100 900 -20 900 {}
C {t0164/c.sym} 0 0 0 0 {name=X1}
C {t0164/c.sym} 0 300 0 0 {name=X2 VCCPIN=VDDEXPLICIT}
C {t0164/n.sym} 0 600 0 0 {name=X3}
C {t0164/c.sym} 0 900 0 0 {name=X5 VCCPIN=""}
C {devices/lab_pin} -100 0 0 0 {name=lT1 lab=TOP1}
C {devices/lab_pin} -100 300 0 0 {name=lT2 lab=TOP2}
C {devices/lab_pin} -100 600 0 0 {name=lT3 lab=TOP3}
C {devices/lab_pin} -100 900 0 0 {name=lT5 lab=TOP5}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE t0164 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch

xschem load [file join $scratch p.sch]

# --- TF0-TF5  fixture witness, read back out of the generated netlist ----------
# The netlist IS the specification resolved_net has to match, so take it from there
# rather than asserting it: a fixture typo then fails the witness instead of quietly
# skewing every later leg.
set ::netlist_dir $scratch
xschem set netlist_type spice
xschem netlist
set nl [file join $scratch p.spice]
check "TF0 (fixture witness) the netlist was written" [file exists $nl] 1
set txt ""
if {[file exists $nl]} { set fh [open $nl r]; set txt [read $fh]; close $fh }
# collapse runs of whitespace: the netlister's column padding is not the point of
# these witnesses, and an empty node position legitimately leaves a double space.
proc nlline {txt pfx} {
  foreach ln [split $txt \n] {
    if {[string match "$pfx *" $ln]} { regsub -all {\s+} [string trim $ln] { } ln ; return $ln }
  }
  return {}
}
check "TF1 (fixture witness) extra= names really are subckt ports" \
  [nlline $txt {.subckt c}] {.subckt c A VCCPIN HASHN pval=7k}
check "TF2 (fixture witness) an omitted attribute takes the TEMPLATE default" \
  [nlline $txt X1] {X1 TOP1 VCC #hfoo c pval=7k}
check "TF3 (fixture witness) an explicit attribute wins" \
  [nlline $txt X2] {X2 TOP2 VDDEXPLICIT #hfoo c pval=7k}
check "TF4 (fixture witness) PRESENT BUT EMPTY does NOT inherit the template" \
  [nlline $txt X5] {X5 TOP5 #hfoo c pval=7k}
check "TF5 (fixture witness) no default anywhere emits no node" \
  [nlline $txt X3] {X3 TOP3 n}

# --- TF20  top level -----------------------------------------------------------
check "TF20 (control) at the top level the attribute loop is not entered at all" \
  [xschem resolved_net VCCPIN] {VCCPIN}

# --- TF6-TF9  the defect and its depth-1 controls ------------------------------
xschem unselect_all ; xschem select instance [inst_index X1] ; xschem descend
check "TF6a (control) descend reached X1" \
  [list [xschem get currsch] [xschem get sch_path]] [list 1 {.X1.}]
check "TF6 an omitted extra= attribute must resolve through the TEMPLATE default" \
  [xschem resolved_net VCCPIN] {VCC}
check "TF7 (control) a plain local net still keeps the hierarchy prefix" \
  [xschem resolved_net LOCAL] {X1.LOCAL}
check "TF16 (0163) a NON-extra attribute stays blocked even though the template has it" \
  [xschem resolved_net pval] {X1.pval}
check "TF18 a TEMPLATE-sourced value keeps its '#' verbatim (0163 Correction)" \
  [xschem resolved_net HASHN] {#hfoo}
check "TF19 the verbatim template-sourced value survives per bus element" \
  [xschem resolved_net {LOCAL,HASHN}] {X1.LOCAL,#hfoo}

# --- TF13  depth 2: two template hops compose ----------------------------------
xschem unselect_all ; xschem select instance [inst_index Y1] ; xschem descend
check "TF13a (control) descend reached X1.Y1" \
  [list [xschem get currsch] [xschem get sch_path]] [list 2 {.X1.Y1.}]
check "TF13 two TEMPLATE hops compose across levels (g -> c -> top)" \
  [xschem resolved_net GX] {VCC}
xschem go_back
xschem go_back

# --- TF8, TF14  the explicit instance ------------------------------------------
xschem unselect_all ; xschem select instance [inst_index X2] ; xschem descend
check "TF8 (control) an explicit attribute still wins over the template" \
  [xschem resolved_net VCCPIN] {VDDEXPLICIT}
check "TF17 (0163) the non-extra block holds on the explicit instance too" \
  [xschem resolved_net pval] {X2.pval}
xschem unselect_all ; xschem select instance [inst_index Y1] ; xschem descend
check "TF14 a template hop then an explicit binding" \
  [xschem resolved_net GX] {VDDEXPLICIT}
xschem go_back
xschem go_back

# --- TF10-TF12, TF15  the cases that must NOT inherit --------------------------
# These are what separate a `!xctx->tok_size` fallback from a `!ptr[0]` one.
xschem unselect_all ; xschem select instance [inst_index X5] ; xschem descend
check "TF10 PRESENT BUT EMPTY must not fall back to the template" \
  [xschem resolved_net VCCPIN] {X5.VCCPIN}
check "TF11 (control) the other extra= attribute on the same instance still inherits" \
  [xschem resolved_net HASHN] {#hfoo}
xschem unselect_all ; xschem select instance [inst_index Y1] ; xschem descend
check "TF15 a template hop onto an empty binding stops at that level" \
  [xschem resolved_net GX] {X5.VCCPIN}
xschem go_back
xschem go_back

xschem unselect_all ; xschem select instance [inst_index X3] ; xschem descend
check "TF12 no default anywhere -> the local name, unchanged" \
  [xschem resolved_net NX] {X3.NX}
xschem go_back

} err]} {
  puts "FATAL: $err"
  incr fail
}

puts "----"
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
