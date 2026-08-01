# Build the issues 0165 / 0179 EYEBALL fixture -- two small designs a human can
# open and look at, plus the xschemrc that makes them loadable in one command.
#
# This is NOT a regression test. The automated coverage is
# tests/headless/test_hash_extra_node_warn_0165.tcl and
# tests/headless/test_tedax_extra_pinnumber_0179.tcl. This exists because those
# two issues are about something a human has to SEE: an ERC warning in the Info
# window, and xschem not dying.
#
# Usage (from anywhere):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/eyeball/make_0165_0179_fixture.tcl
#
# Writes to $EYEBALL_DIR, default /tmp/xschem_0165_eyeball, and then netlists both
# designs headless so the hand-over is verified rather than asserted. Read
# doc/claude/suggestions/eyeball_0165_0179.md for what to look at and why.

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set d [expr {[info exists ::env(EYEBALL_DIR)] ? $::env(EYEBALL_DIR) : {/tmp/xschem_0165_eyeball}}]
file delete -force $d
file mkdir $d
proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

# --- hidden_supply: a cell whose VCC comes in as an ATTRIBUTE, not a drawn pin.
# This is upstream's documented "extra=" idiom -- a hidden pin. The symbol has
# ONE visible pin (A); VCCPIN is invisible and is supplied per instance.
wfile [file join $d hidden_supply.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @VCCPIN @symname"
spectre_format="@name ( @pinlist @VCCPIN ) @symname"
template="name=x1 VCCPIN=VCC"
extra="VCCPIN"}
V {}
S {}
F {}
E {}
L 4 -40 -30 40 -30 {}
L 4 40 -30 40 30 {}
L 4 40 30 -40 30 {}
L 4 -40 30 -40 -30 {}
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout}
T {@symname} -40 -48 0 0 0.3 0.3 {}
T {VCCPIN=@VCCPIN} -40 34 0 0 0.25 0.25 {}}

wfile [file join $d hidden_supply.sch] {v {xschem version=3.4.8RC file_version=1.3}
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
C {devices/lab_pin} 200 100 0 0 {name=lV lab=VCCPIN}
T {the hidden supply arrives here as the net VCCPIN} 260 100 0 0 0.3 0.3 {}}

# --- the top cell. X1's hidden supply is bound to "#vdd_typo"; the WIRE below
# is labelled with the very same spelling. They are NOT the same node.
wfile [file join $d eyeball_0165.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -30 0 -100 {}
N 0 30 0 100 {}
N 200 0 360 0 {}
N 700 -30 700 -100 {}
N 700 30 700 100 {}
C {devices/vsource} 0 0 0 0 {name=V1 value=1}
C {devices/lab_pin} 0 -100 0 0 {name=lT lab=topn}
C {devices/gnd} 0 100 0 0 {name=g1 lab=GND}
C {devices/lab_pin} 200 0 0 0 {name=lT2 lab=topn}
C {eyeball/hidden_supply.sym} 400 0 0 0 {name=X1 VCCPIN=#vdd_typo}
C {devices/res} 700 0 0 0 {name=R9 value=1k}
C {devices/lab_pin} 700 -100 0 0 {name=lH lab=#vdd_typo}
C {devices/gnd} 700 100 0 0 {name=g2 lab=GND}
T {ISSUE 0165 EYEBALL} -100 -260 0 0 0.6 0.6 {}
T {X1's hidden supply is bound to  #vdd_typo  (see VCCPIN= under the box).} -100 -210 0 0 0.35 0.35 {}
T {The wire on the right is LABELLED  #vdd_typo  -- the same spelling.} -100 -180 0 0 0.35 0.35 {}
T {They are DIFFERENT nodes in the netlist. That is the bug this warns about.} -100 -150 0 0 0.35 0.35 {}
T {Netlist (the "Netlist" button), then read the ERC Info window.} -100 -110 0 0 0.35 0.35 {}
T {the BINDING: emitted verbatim as  #vdd_typo} 380 -70 0 0 0.3 0.3 {}
T {the LABEL: emitted as  vdd_typo  ('#' stripped)} 620 -140 0 0 0.3 0.3 {}}

# --- the 0179 fixture: extra= with NO extra_pinnumber=, plus a tedax_format.
# Netlisting THIS to tEDAx used to segfault xschem outright.
wfile [file join $d crashy.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @HN @symname"
tedax_format="footprint @name dip8"
template="name=x1 HN=VDD"
extra="HN"}
V {}
S {}
F {}
E {}
L 4 -40 -30 40 -30 {}
L 4 40 -30 40 30 {}
L 4 40 30 -40 30 {}
L 4 -40 30 -40 -30 {}
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout pinnumber=1}
T {@symname} -40 -48 0 0 0.3 0.3 {}}

wfile [file join $d crashy.sch] {v {xschem version=3.4.8RC file_version=1.3}
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

wfile [file join $d eyeball_0179.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -30 0 -100 {}
N 0 30 0 100 {}
N 200 0 360 0 {}
C {devices/vsource} 0 0 0 0 {name=V1 value=1}
C {devices/lab_pin} 0 -100 0 0 {name=lT lab=topn}
C {devices/gnd} 0 100 0 0 {name=g1 lab=GND}
C {devices/lab_pin} 200 0 0 0 {name=lT2 lab=topn}
C {eyeball/crashy.sym} 400 0 0 0 {name=X1}
T {ISSUE 0179 EYEBALL} -100 -220 0 0 0.6 0.6 {}
T {crashy.sym has  extra="HN"  and a tedax_format, but NO extra_pinnumber=.} -100 -170 0 0 0.35 0.35 {}
T {Set Options > Netlist format > tedax, then press Netlist.} -100 -140 0 0 0.35 0.35 {}
T {BEFORE the fix this killed xschem outright (SIGSEGV).} -100 -110 0 0 0.35 0.35 {}
T {Now it emits  conn <net> X1 --UNDEF--  and survives.} -100 -80 0 0 0.35 0.35 {}}

set f [open [file join $d library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE eyeball $d"
close $f

# An `xschemrc` in the CURRENT DIRECTORY is sourced at startup (xinit.c ~3208),
# so `cd` here and launch: no env vars, no --script, nothing to remember.
# show_infowindow_after_netlist=always is a fixture convenience: the default is
# `onerror`, and an ERC WARNING is not an error, so the window would otherwise
# only update rather than pop. That default is unchanged by 0165 -- the existing
# label-side warning at netlist.c:1491 has always behaved the same way.
set f [open [file join $d xschemrc] w]
puts $f "set XSCHEM_LIBRARY_DEFS [list [file join $d library.defs]]"
puts $f "set library_registry_defs_only 1"
puts $f "set XSCHEM_LIBRARY_PATH [list $d]"
puts $f "set netlist_dir [list $d]"
puts $f "set show_infowindow_after_netlist always"
close $f

set ::XSCHEM_LIBRARY_DEFS [file join $d library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $d
set ::netlist_dir $d

proc show {p} {
  puts "\n---------- [file tail $p] ----------"
  if {[file exists $p]} { set f [open $p r]; puts [read $f]; close $f } else { puts "(MISSING)" }
}

puts "\n================ 0165: SPICE ================"
xschem load [file join $d eyeball_0165.sch]
xschem set netlist_type spice
xschem netlist
puts "ERC Info window would show:"
puts [xschem get infowindow_text]
show [file join $d eyeball_0165.spice]

puts "\n================ 0179: tEDAx (used to SIGSEGV) ================"
xschem load [file join $d eyeball_0179.sch]
xschem set netlist_type tedax
xschem netlist
show [file join $d eyeball_0179.tdx]

puts "\nFIXTURE READY: $d"
puts "open it with:"
puts "  [file join $repo src xschem] --rcfile [file join $d xschemrc] [file join $d eyeball_0165.sch]"
