# tests/headless/test_unused_attr_0970.tcl -- ISSUE 0970 AND ITS CLASS, PLUS
# 0974 AND 0976: A SETTING THE USER TYPED ON THE SHEET THAT GOES NOWHERE, AND
# THE TWO SURFACES THAT LIE ABOUT IT AFTERWARDS.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# They open sky130_tests/bandgap, click a passgate, and type
# modelp=pfet_01v8_lvt on it because they want that one copy of the cell built
# from the low-threshold p-device. They press netlist. Nothing complains. They
# run. Numbers appear. Every one of those numbers was measured on an ordinary
# p-device, because passgate.sym's format string never mentions modelp, so the
# netlister writes ONE cell body for all five passgates out of the symbol's own
# default and the setting they typed is discarded without a word. Measured on
# the generated deck: one .subckt passgate body, zero occurrences of modelp.
# Two transistors on a tracked bench have never been simulated with the device
# their schematic line names.
#
# Then two more surfaces make it worse. The run does eventually notice the
# disagreement and says so -- but it leads with M2, the name of the transistor
# INSIDE the cell, on a sheet holding five passgates that each contain an M2,
# so the sentence identifies nothing and never says what to do (issue 0974).
# And the shipped SKY130 menu items still ask the SCHEMATIC what model a device
# uses rather than the deck, so "Create FET .save file" writes save lines for a
# device name the results file does not contain and "Add FET param annotator"
# shows blanks where numbers should be (issue 0976).
#
# ============================================================================
# WHAT THIS FILE MEASURES, AND WHAT IT DOES NOT
# ============================================================================
# NO PIXELS, NO SIMULATOR, NO NGSPICE. Everything here is the netlister's own
# output, the info window's own text, and the two shipped Tcl helpers, driven
# on a fixture built in the scratch directory plus the shipped bandgap bench.
# The real-run half of issue 0970 -- that the two transistors now measure a
# genuinely different device -- lives in section X of
# tests/headless/test_ase_optier_0963.tcl, which has a simulator.
#
# THE FIXTURE IS THE BENCH IN MINIATURE and was measured against the real
# netlister before these rows were written. uapass.sym is passgate.sym's shape
# cut down to one pin: a subcircuit whose format string carries W_P and DROPS
# modelp, and whose template supplies modelp=pfet_01v8 on a second line. Its
# body is one shipped sky130 p-device whose model is that parameter. Six
# instances of it stand on uatop.sch, one plain p-device beside them:
#
#   x3   sets nothing of its own            -- the control for GUARD UA-INST
#   x5   sets modelp=pfet_01v8_lvt          -- issue 0970 itself
#   X7   sets modelp=pfet_01v8_lvt          -- and is named with a capital
#   x8   sets modelp AND schematic=         -- the override really does arrive
#   x9   sets W, where the format has W_P   -- one name inside another
#   x10  sets place, sig_type, device_model -- settings the netlister reads
#   M9   a plain p-device with a spare      -- not a cell, so not this check
#
# Measured on that fixture at HEAD 7b08953c, before any repair: the deck holds
# .subckt uapass whose transistor is sky130_fd_pr__pfet_01v8 and .subckt
# uapass_lvtp whose transistor is sky130_fd_pr__pfet_01v8_lvt, and the info
# window says nothing whatever about the setting x5 and X7 lost.
#
# THE CONTRACT PHRASE. A netlist-time line of this kind is recognised here by
# the clause "did not reach the simulator". The whole sentence it belongs to is
#
#   Warning: on sheet <sheet>, instance <inst> (a <symbol>) sets <prop>=<value>,
#   but <symbol> never reads <prop> when the netlist is written, so that
#   setting did not reach the simulator and changed nothing. Check the spelling
#   against the settings this cell does read, or take it off. If you meant to
#   change only this one copy of the cell, add a schematic= attribute to <inst>
#   naming a cell name that no other instance asks for, and that copy is
#   written out on its own with your setting in it. Two instances that ask for
#   the same name quietly share one copy, and only the first one's setting is
#   kept.
#
# and it is minted in exactly one place, src/token.c.
#
# THAT SENTENCE WAS REWRITTEN BY ITEM S4c, 2026-08-30. It used to open "on this
# sheet," about instances that were not on the sheet the user had open (issue
# 0981), and it used to end "give <inst> a schematic= attribute of its own as
# well", which walked the reader into a silent collision (issue 0982). Rows UF8
# and UF13 assert that both of those old strings are now ABSENT, so do not
# reinstate either one here as a description of what the tool says.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_unused_attr_0970.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_unused_attr_0970.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch unused_attr_0970]

proc u_wr {p body} { set f [open $p w]; puts $f $body; close $f }
proc u_slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## An absent proc answers NOPROC and a raise answers RAISED:<text>, so
## "invalid command name ..." can never satisfy a row that expected a value.
proc u_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc u_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## Tcl comments dropped, so a sentence or a call quoted in a comment cannot
## satisfy a row about where it is MADE.
proc u_nocomment_tcl {t} {
  set out {}
  foreach l [split $t "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
## C comments dropped, for the same reason -- and because the guard names this
## file greps for are written in those comments.
proc u_nocomment_c {t} {
  regsub -all {/\*.*?\*/} $t { } t2
  return $t2
}
proc u_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [u_nocomment_tcl $b]
}
## Is <w> in <s> as a word of its own -- not buried inside a device path, where
## every component is glued to its neighbours with dots? This is the whole of
## issue 0974: x5 IS in the sentence today, inside @m.x5.xm2.<model>, and that
## is not the schematic naming the instance the user placed.
proc u_word {s w} {
  return [regexp "(^|\[^A-Za-z0-9_.\])[string map {. \\.} $w](\[^A-Za-z0-9_.\]|$)" $s]
}

if {[catch {

# ============================================================================
# THE FIXTURE
# ============================================================================
set UA [file join $scratch ualib]
file mkdir $UA

u_wr [file join $UA uapass.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"
extra="modelp"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

u_wr [file join $UA uapass.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
C {sky130_fd_pr/pfet_01v8} 400 -300 0 0 {name=M2
L=0.15
W=W_P
nf=1
mult=1
model=@modelp
spiceprefix=X
}}

## x8 names a schematic file that DOES NOT EXIST, and that is the mechanism,
## not an accident. get_additional_symbols makes a separate symbol block whose
## parent property string is that instance's own, and the missing file falls
## back to the symbol's base sheet -- so ONE uapass.sch yields two cell bodies
## and x8's override really does reach the deck. It is the same two tokens that
## repair the shipped bandgap bench.
u_wr [file join $UA uatop.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {ua/uapass.sym} 120 0 0 0 {name=x3 W_P=0.5}
C {ua/uapass.sym} 320 0 0 0 {name=x5 W_P=0.6 modelp=pfet_01v8_lvt}
C {ua/uapass.sym} 520 0 0 0 {name=X7 W_P=0.7 modelp=pfet_01v8_lvt}
C {ua/uapass.sym} 720 0 0 0 {name=x8 W_P=0.8 modelp=pfet_01v8_lvt schematic=uapass_lvtp}
C {ua/uapass.sym} 920 0 0 0 {name=x9 W_P=0.9 W=0.4}
C {ua/uapass.sym} 1120 0 0 0 {name=x10 W_P=1.0 place=end sig_type=std_logic device_model=zz}
C {sky130_fd_pr/pfet_01v8} 1320 0 0 0 {name=M9
L=0.15
W=1
nf=1
mult=1
model=pfet_01v8
zzspare=7
spiceprefix=X
}}


# ---------------------------------------------------------------------------
# THE S4c FIXTURE ADDITIONS -- issues 0980, 0981, 0983, 0982, 0984.
#
# uafmt.sym is the shape that separates the four ways a cell can consume a
# setting the user typed, one per attribute, so each row below has exactly one
# reason to be red:
#   nfin  -- named in the cell's own template= and in no format string. A
#            Verilog or VHDL netlist of this cell passes it in as a parameter,
#            so it is NOT a lost setting even though the SPICE format never
#            mentions it. Issue 0980 in miniature.
#   vbb   -- named in the template AND in extra=. An extra= name is a NODE, not
#            a setting, so it stays reportable. This is the seam that keeps the
#            shipped bandgap passgate reportable.
#   K     -- read by the SPICE format string and absent from the template.
#   V     -- read only by verilog_format and absent from the template.
#   zznone-- read by nothing at all. The control: the sheet must always say its
#            one thing about this one, or a row that expects silence elsewhere
#            is passing because the whole instance was skipped.
u_wr [file join $UA uafmt.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname K=@K"
verilog_format="assign @V = 1;"
template="name=x1
nfin=1
vbb=0"
extra="vbb"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

u_wr [file join $UA uafmt.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
C {devices/res} 400 -300 0 0 {name=R1 value=1k}}

## A cell that reads nothing at all, for the three SHAPE fixtures -- a very long
## value, a value written over two lines, and properties continued with a SPICE
## '+' marker the way the shipped charge pump sheet writes them.
u_wr [file join $UA uatsub.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

u_wr [file join $UA uatsub.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
C {devices/res} 400 -300 0 0 {name=R1 value=2k}}

## Written line by line rather than as one literal, because the three shapes
## this sheet exists to carry are shapes of the FILE: a 1705-character value, a
## quoted value broken across two physical lines exactly as shipped
## examples/tb_symbol_include.sch breaks its comm= value, and a property
## continued onto the next line behind a '+' exactly as shipped
## sky130_tests/charge_pump_phasegen.sch continues its lvtnot instances.
set UF_BIG "note_[string repeat ABCDEFGHIJ 170]"
set UF_TOP [file join $UA uafmt_top.sch]
set uffd [open $UF_TOP w]
puts $uffd "v \{xschem version=3.4.4 file_version=1.2\}"
puts $uffd "G \{\}"
puts $uffd "K \{\}"
puts $uffd "V \{\}"
puts $uffd "S \{\}"
puts $uffd "E \{\}"
puts $uffd "C \{ua/uafmt.sym\} 120 0 0 0 \{name=xT nfin=2 zznone=1 vbb=1 K=3 V=2\}"
puts $uffd "C \{ua/uatsub.sym\} 320 0 0 0 \{name=xLONG bigprop=$UF_BIG\}"
puts $uffd "C \{ua/uatsub.sym\} 520 0 0 0 \{name=xNL nlprop=\"first half of the value"
puts $uffd "      second half of the value\"\}"
puts $uffd "C \{ua/uatsub.sym\} 720 0 0 0 \{name=xPLUS "
puts $uffd "+ zzplus=1\}"
close $uffd

## TWO LEVELS, ONE INSTANCE NAME, ONE PROPERTY NAME -- issue 0981's shipped
## shape reduced to two sheets. The x5 the user placed on uahier.sch and the x5
## inside uamid.sch are different instances on different sheets, and today the
## netlister says the same eleven words about both.
u_wr [file join $UA uamid.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

u_wr [file join $UA uamid.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
C {ua/uatsub.sym} 400 -300 0 0 {name=x5 zzlost=1}}

u_wr [file join $UA uahier.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {ua/uatsub.sym} 120 0 0 0 {name=x5 zzlost=1}
C {ua/uamid.sym} 320 0 0 0 {name=xm1}}
set UF_HIER [file join $UA uahier.sch]

## A SHEET WHOSE PATH IS TOO LONG FOR THE SENTENCE -- issue 0983's third shape,
## and the only witness of the half of GUARD UA-ELIDE that keeps the END of a
## field instead of its beginning. Three directory levels of forty characters
## each put the sheet well past the 120 the sentence allows, and a path is
## identified by its last components, so the reader must still be able to see
## which sheet it is.
set UF_DEEPDIR [file join $UA \
  dddddddddddddddddddddddddddddddddddddddd \
  eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee \
  ffffffffffffffffffffffffffffffffffffffff]
file mkdir $UF_DEEPDIR
u_wr [file join $UF_DEEPDIR uadeep.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {ua/uatsub.sym} 120 0 0 0 {name=xD zzdeep=1}}
set UF_DEEP [file join $UF_DEEPDIR uadeep.sch]

set SKY [file join $repo sky130A xschem_libs]
set DEFS [file join $UA library.defs]
set fd [open $DEFS w]
puts $fd "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $fd "DEFINE sky130_fd_pr [file join $SKY sky130_fd_pr]"
puts $fd "DEFINE sky130_tests [file join $SKY sky130_tests]"
puts $fd "DEFINE sky130_tests_ase [file join $SKY sky130_tests_ase]"
puts $fd "DEFINE sky130_stdcells [file join $SKY sky130_stdcells]"
puts $fd "DEFINE ua $UA"
close $fd
set ::XSCHEM_LIBRARY_DEFS $DEFS
set ::library_registry_defs_only 1
set ::netlist_dir $scratch
catch {uplevel #0 [list source [file join $repo sky130A sky130_procs.tcl]]}

set UATOP [file join $UA uatop.sch]

# ============================================================================
# UB. "YOU TYPED THIS AND IT HAD NO EFFECT" -- THE NETLISTER'S OWN DIAGNOSTIC
# ============================================================================
## Every line of this kind the last netlist put in the info window. Matched on
## the contract clause named in the file header, so an unrelated open-net or
## '#'-node notice in the same transcript cannot be counted as one of these.
proc ua_lines {} {
  set out {}
  foreach ln [split [xschem get infowindow_text] \n] {
    if {[string first {did not reach the simulator} $ln] >= 0} {
      lappend out [string trim $ln]
    }
  }
  return $out
}
## Of those, the ones naming <inst> as a word of its own.
proc ua_for {inst} {
  set out {}
  foreach l [ua_lines] { if {[u_word $l $inst]} { lappend out $l } }
  return $out
}
proc ua_netlist {sch} {
  catch {xschem load $sch}
  catch {xschem set netlist_type spice}
  catch {xschem netlist}
  return [llength [ua_lines]]
}

set UB_N [ua_netlist $UATOP]
set UB_DECK [u_slurp [file join $scratch uatop.spice]]
foreach l [ua_lines] { puts "UA-LINE: $l" }
puts "UA-COUNT fixture: $UB_N"

set UB_X5 [ua_for x5]

check {UB1 issue 0970 netlisting the sheet says once, in plain English, that\
 the setting the user typed on x5 never reached the simulator -- naming the\
 instance they placed, the setting they typed and the cell it sits in, and\
 ending by telling them what they can do about it} \
  [list [llength $UB_X5] \
        [expr {[llength $UB_X5] == 1 ? [u_word [lindex $UB_X5 0] x5] : 0}] \
        [expr {[llength $UB_X5] == 1 ? [u_word [lindex $UB_X5 0] modelp] : 0}] \
        [expr {[llength $UB_X5] == 1 ?
               [expr {[string first {uapass} [lindex $UB_X5 0]] >= 0 ? 1 : 0}] : 0}] \
        [expr {[llength $UB_X5] == 1 ?
               [expr {[string first {schematic=} [lindex $UB_X5 0]] >= 0 ? 1 : 0}] : 0}]] \
  {1 1 1 1 1}

check {UB2 GUARD UA-INST a cell setting the sheet never typed is not a lost\
 setting: x3 takes the cell's own default for the very same setting and is not\
 mentioned at all, while x5 which really did type one still is} \
  [list [llength [ua_for x3]] [llength $UB_X5]] {0 1}

check {UB3 GUARD UA-POLY x8 asked for its own copy of the cell, so its setting\
 really did reach the simulator -- the deck holds a second cell body whose\
 transistor is the low-threshold device -- and x8 is therefore not accused of\
 having typed something that changed nothing} \
  [list [llength [ua_for x8]] \
        [expr {[regexp {(?m)^XM2 .*pfet_01v8_lvt} $UB_DECK] ? 1 : 0}] \
        [llength $UB_X5]] \
  {0 1 1}

set UB_X9 [ua_for x9]
check {UB4 GUARD UA-FMT one name inside another: x9 sets W while the cell reads\
 W_P, and W is reported -- a plain substring test would find W inside W_P and\
 go quiet about exactly the class this check exists to catch} \
  [list [llength $UB_X9] \
        [expr {[llength $UB_X9] == 1 ? [u_word [lindex $UB_X9 0] W] : 0}]] \
  {1 1}

check {UB5 GUARD UA-STOP an instance carrying only settings the netlister reads\
 for itself -- where it goes in the deck, what kind of signal it is, and a\
 device model it hashes out on its own -- is not mentioned} \
  [list [llength [ua_for x10]] [llength $UB_X5]] {0 1}

check {UB6 GUARD UA-TYPE a plain transistor placed straight on the sheet with a\
 spare setting on it is not mentioned: this check is about cells whose insides\
 are written out once from a template, which is why a per-copy setting has\
 nowhere to go} \
  [list [llength [ua_for M9]] [llength $UB_X5]] {0 1}

# --- UB7/UB8: the noise, on shipped data ------------------------------------
# These two are the rows that keep the repair of the bandgap bench honest. The
# shipped bench carries exactly this defect today, so until its two passgates
# are given a copy of the cell to themselves it emits these lines too.
set UB_BENCH [file join $SKY sky130_tests_ase tb_bandgap schematic tb_bandgap.sch]
set UB7N -1
if {[file isfile $UB_BENCH]} { set UB7N [ua_netlist $UB_BENCH] }
foreach l [ua_lines] { puts "UA-BENCH-LINE: $l" }
set UB_BDECK [u_slurp [file join $scratch tb_bandgap.spice]]
puts "UA-COUNT tb_bandgap: $UB7N (deck [string length $UB_BDECK] bytes,\
 passgate bodies [regexp -all {(?m)^\.subckt passgate} $UB_BDECK])"
check {UB7 netlisting the shipped bandgap bench says nothing of this kind at\
 all -- every setting typed on that sheet reaches the simulator -- while the\
 fixture, which cannot be repaired away, still says its one line. The bench\
 really was netlisted: its deck is on disk and holds the passgate cell this\
 whole issue is about, so a silent failure to netlist cannot pass this row} \
  [list $UB7N [llength $UB_X5] \
        [expr {[regexp {(?m)^\.subckt passgate} $UB_BDECK] ? 1 : 0}]] \
  {0 1 1}

set UB8N 0
set UB8SEEN 0
foreach ubd [lsort [glob -nocomplain -directory [file join $SKY sky130_tests_ase] -type d *]] {
  set ubs [file join $ubd schematic [file tail $ubd].sch]
  if {![string match tb_* [file tail $ubd]]} { continue }
  if {![file isfile $ubs]} { continue }
  incr UB8SEEN
  set ubn [ua_netlist $ubs]
  puts "UA-COUNT [file tail $ubd]: $ubn"
  incr UB8N $ubn
}
check {UB8 the noise budget, counted rather than hoped for: netlisting every\
 shipped testbench in the analog simulation library produces not one of these\
 lines, and the count is printed above so a regression shows the number and\
 not merely a red} \
  [list [expr {$UB8SEEN >= 4 ? 1 : 0}] $UB8N [llength $UB_X5]] {1 0 1}

# --- UB9: the guard no behavioural row can see -------------------------------
set UB_TOKC [u_nocomment_c [u_slurp [file join $repo src token.c]]]
set UB_FN {}
if {[regexp {warn_unused_instance_attr\s*\([^)]*\)\s*\{} $UB_TOKC ubm]} {
  set ubi [string first $ubm $UB_TOKC]
  ## From the opening brace to the matching one, counted.
  set ubj [expr {$ubi + [string length $ubm] - 1}]
  set ubdep 1
  set ubk [expr {$ubj + 1}]
  while {$ubk < [string length $UB_TOKC] && $ubdep > 0} {
    set ubc [string index $UB_TOKC $ubk]
    if {$ubc eq "\{"} { incr ubdep }
    if {$ubc eq "\}"} { incr ubdep -1 }
    incr ubk
  }
  set UB_FN [string range $UB_TOKC $ubj [expr {$ubk - 1}]]
}
## ⚠ THE FIRST ANCHOR HERE WAS `= xctx->tok_size` AND IT COULD NOT FAIL. The
## skip test below the latch reads that flag six times as `skip =
## xctx->tok_size ? 1 : 0`, so the loose spelling matched seven times in this
## function body and stayed at seven when the LATCH LINE ALONE was deleted --
## measured, with a built binary, in the sabotage pass: the whole tier stayed
## green while the surviving restore wrote an uninitialised value into the
## netlister's token-found flag on every subcircuit instance. That is precisely
## the failure this guard exists to prevent, so the row is anchored on the
## latch's own variable and both halves are now pinned separately.
check {UB9 STRUCTURAL GUARD UA-TOKSIZE which no behavioural row can see at\
 today's call site: the new check latches the netlister's token-found flag\
 before its own lookups and puts it back afterwards, so an observer can never\
 become the reason a real netlist value goes missing if the call site moves} \
  [list [expr {$UB_FN ne {} ? 1 : 0}] \
        [expr {[u_count $UB_FN {saved_tok_size = xctx->tok_size}] >= 1 ? 1 : 0}] \
        [expr {[u_count $UB_FN {xctx->tok_size = }] >= 1 ? 1 : 0}]] \
  {1 1 1}

# --- UB10/UB11: something has to RUN these -----------------------------------
set UB_REG [u_slurp [file join $repo tests run_regression.tcl]]
set UB_AUD [u_slurp [file join $repo tests headless full_audit.sh]]
set UB_H165 [u_slurp [file join $repo tests headless test_hash_extra_node_warn_0165.tcl]]
check {UB10 STRUCTURAL issue 0977 the only other netlist-time warning suite in\
 the tree covers the very function this new check is added to, and nothing ran\
 it: it is named once in the full regression list and once in the audit list,\
 and it prints both completion banners so the runner can tell it finished} \
  [list [u_count $UB_REG {headless/test_hash_extra_node_warn_0165}] \
        [u_count $UB_AUD {test_hash_extra_node_warn_0165}] \
        [expr {[string first {OVERALL: ok} $UB_H165] >= 0 ? 1 : 0}] \
        [expr {[string first {RESULT: ALL PASS} $UB_H165] >= 0 ? 1 : 0}]] \
  {1 1 1 1}

check {UB11 STRUCTURAL this suite is itself named once in the full regression\
 list and once in the audit list, so it is run by something other than a person\
 remembering to type it} \
  [list [u_count $UB_REG {headless/test_unused_attr_0970}] \
        [u_count $UB_AUD {test_unused_attr_0970}]] \
  {1 1}

# ============================================================================
# UF. THE SAME DIAGNOSTIC, TOLD THE TRUTH -- issues 0980, 0981, 0982, 0983, 0984
# ============================================================================
# S4b shipped this warning ON BY DEFAULT and it is wrong on 43 of the 149 lines
# it prints across the shipped xschem_library, and on SIX of the eighteen sheets
# that speak it is wrong on every single line. A designer who follows the advice
# on xschem_library/logic/ram_tb.sch or xschem_library/examples/loading.sch
# breaks a working shipped example, because the settings it calls dead are
# carried into the Verilog and VHDL netlists of the very same sheet:
# ram_tb.v holds .datafile - "ram.list" - and a module body that runs
# $readmemh on it, loading.vhdl holds cap => 30.0 and conduct => 1.0/20000.0.
#
# The rows below are on SHIPPED sheets wherever a shipped sheet carries the
# shape, and on the fixture only where no shipped sheet does. The fixture rows
# separate the four ways a cell can consume a setting, one attribute each, so a
# repair that silences the warning wholesale cannot pass them -- UF3 is the
# negative control that reddens if somebody simply turns the thing off.

## Every line the info window holds that mentions <needle>, whether or not it is
## the START of one of these paragraphs. UF11 and UF12 need the continuation
## halves that ua_lines cannot see, because a value with a newline in it makes
## one warning arrive as two lines and the second begins mid-sentence.
proc uf_iw_with {needle} {
  set out {}
  foreach ln [split [xschem get infowindow_text] \n] {
    set t [string trim $ln]
    if {$t eq {}} { continue }
    if {[string first $needle $t] >= 0} { lappend out $t }
  }
  return $out
}
## Of a captured list of lines, the ones mentioning <needle>. Captured rather
## than re-read, because the info window also carries a separator line naming
## every sheet it descends into -- searching the whole window for a sheet name
## would find the separator and pass a row about what the SENTENCE says.
proc uf_with {lines needle} {
  set out {}
  foreach l $lines { if {[string first $needle $l] >= 0} { lappend out $l } }
  return $out
}
## Of the warnings the last netlist produced, the ones about attribute <prop>.
proc uf_sets {lines prop} {
  set out {}
  foreach l $lines { if {[string first " sets $prop=" $l] >= 0} { lappend out $l } }
  return $out
}
## Of the warnings the last netlist produced, the ones that do not begin at the
## beginning of the sentence.
proc uf_midsentence {lines} {
  set n 0
  foreach l $lines { if {![string match {Warning:*} $l]} { incr n } }
  return $n
}
## A boolean expression, evaluated in the CALLER's scope, reduced to 1 or 0 so
## a failing row prints a readable list instead of a wall of true/false.
proc uf_yes {c} { return [expr {[uplevel 1 [list expr $c]] ? 1 : 0}] }

# --- UF1 / UF2 / UF3: the shipped sheets, and the control --------------------
set UF_RAMTB [file join $repo xschem_library logic ram_tb.sch]
set UF1N [ua_netlist $UF_RAMTB]
set UF1D [u_slurp [file join $scratch ram_tb.spice]]
puts "UA-COUNT ram_tb.sch: $UF1N (deck [string length $UF1D] bytes)"
check {UF1 issue 0980 SHIPPED netlisting the shipped memory testbench to SPICE\
 says nothing of this kind at all. Every one of the seven settings it used to\
 call dead -- the data file, the memory size, the access delay -- is carried\
 into the Verilog netlist of the same sheet and read by the module body, so\
 telling the user to take them off breaks a working shipped example. The deck\
 really was written and holds the memory cell, so a sheet that failed to load\
 cannot pass this row by being silent} \
  [list $UF1N [uf_yes {[string length $UF1D] > 100}] \
        [uf_yes {[string first {ram} $UF1D] >= 0}]] \
  {0 1 1}

set UF_LOADING [file join $repo xschem_library examples loading.sch]
set UF2N [ua_netlist $UF_LOADING]
set UF2D [u_slurp [file join $scratch loading.spice]]
puts "UA-COUNT loading.sch: $UF2N (deck [string length $UF2D] bytes)"
check {UF2 issue 0980 SHIPPED the shipped loading example says nothing of this\
 kind either. Its eleven accused settings are the capacitances, conductances\
 and delays the VHDL netlist of the same sheet writes into its generic maps.\
 The deck really was written and holds both cells the accusations were about} \
  [list $UF2N [uf_yes {[string first {real_capa} $UF2D] >= 0}] \
        [uf_yes {[string first {pump} $UF2D] >= 0}]] \
  {0 1 1}

set UF_ROM8K [file join $repo xschem_library rom8k rom8k.sch]
set UF3N [ua_netlist $UF_ROM8K]
set UF3L [ua_lines]
set UF3V [llength [uf_sets $UF3L VSSBPIN]]
set UF3THIS [llength [uf_with $UF3L {on this sheet}]]
set UF3P1 [llength [uf_with $UF3L rom2_predec1]]
set UF3P3 [llength [uf_with $UF3L rom2_predec3]]
set UF3P4 [llength [uf_with $UF3L rom2_predec4]]
puts "UA-COUNT rom8k.sch: $UF3N (VSSBPIN lines $UF3V, distinct [llength [lsort -unique $UF3L]])"
check {UF3 issue 0980 THE NEGATIVE CONTROL the shipped ROM still gets its real\
 warning: its sheets bind a power pin spelled VSSBPIN while the gate they place\
 spells it VSSPIN, so that binding truly reaches nothing, and the netlister\
 must go on saying so. A repair that merely switches this diagnostic off, or\
 that excuses every setting a symbol happens to name anywhere, reddens here} \
  [list [uf_yes {$UF3N > 0}] [uf_yes {$UF3V > 0}]] {1 1}

# --- UF4 .. UF7: the four ways a cell can consume a setting -------------------
set UF_TN [ua_netlist $UF_TOP]
set UF_TL [ua_lines]
foreach l $UF_TL { puts "UA-FIX-LINE: $l" }
puts "UA-COUNT uafmt_top.sch: $UF_TN"
set UF_CTL [llength [uf_sets $UF_TL zznone]]

check {UF4 issue 0980 GUARD UA-TMPL a setting the cell declares as one of its\
 own -- it is in the symbol's template, so a Verilog or VHDL netlist of that\
 cell passes it straight in as a parameter -- is never called dead, even though\
 the SPICE format string does not mention it. The control setting, which no\
 template and no format string anywhere names, is still reported once} \
  [list [llength [uf_sets $UF_TL nfin]] $UF_CTL] {0 1}

check {UF5 issue 0980 GUARD UA-EXTRA a name the symbol lists in extra= is a\
 NODE the cell gets wired to, not a setting the cell reads, so it stays\
 reportable even though the template also mentions it. This is the seam that\
 keeps the shipped bandgap passgate reportable, which is the case this whole\
 diagnostic was written for} \
  [list [llength [uf_sets $UF_TL vbb]] $UF_CTL] {1 1}

check {UF6 issue 0980 GUARD UA-FMT a setting the SPICE format string itself\
 reads is silent, and this is now the only place that guard can be seen from --\
 the older row for it uses a name the symbol's template also declares, so the\
 template rule alone would keep that one quiet and the format rule could be\
 deleted without anything going red} \
  [list [llength [uf_sets $UF_TL K]] $UF_CTL] {0 1}

check {UF7 issue 0980 GUARD UA-ALTFMT a setting read only by the cell's Verilog\
 form is silent when the sheet is written to SPICE. The question the warning\
 has to answer is whether the setting reaches ANY netlist this cell can be\
 written in, not whether it reaches the one being written this minute} \
  [list [llength [uf_sets $UF_TL V]] $UF_CTL] {0 1}

# --- UF8 / UF9: which sheet, and which instance ------------------------------
check {UF8 issue 0981 SHIPPED netlisting the shipped ROM never says on this\
 sheet about an instance that is not on the sheet the user opened. Not one of\
 those instances is on rom8k.sch -- they are on three predecoder sheets one\
 level down -- and every line names the sheet it is really about, so no two\
 lines are word-for-word identical. Today four names are each printed three\
 times byte-identically and the user cannot tell which is which} \
  [list $UF3THIS \
        [uf_yes {$UF3P1 > 0}] \
        [uf_yes {$UF3P3 > 0}] \
        [uf_yes {$UF3P4 > 0}] \
        [uf_yes {[llength [lsort -unique $UF3L]] == [llength $UF3L]}]] \
  {0 1 1 1 1}

set UF9N [ua_netlist $UF_HIER]
set UF9L [ua_lines]
foreach l $UF9L { puts "UA-HIER-LINE: $l" }
check {UF9 issue 0981 two sheets, one instance name, one setting name: the x5\
 the user placed and the x5 inside the cell it contains are different\
 instances, and the two sentences differ -- one names the sheet the user opened\
 and the other names the sheet one level down. Both still name x5 itself} \
  [list $UF9N \
        [uf_yes {$UF9N == 2 && [u_word [lindex $UF9L 0] x5] && [u_word [lindex $UF9L 1] x5]}] \
        [uf_yes {[llength [uf_with $UF9L uahier]] > 0}] \
        [uf_yes {[llength [uf_with $UF9L uamid]] > 0}] \
        [uf_yes {[llength [lsort -unique $UF9L]] == $UF9N}]] \
  {2 1 1 1 1}

# --- UF10 / UF11 / UF12: the sentence survives the value ---------------------
set UF10N [ua_netlist $UF_TOP]
set UF10L [ua_lines]
set UF10B [uf_sets $UF10L bigprop]
set UF10S [expr {[llength $UF10B] == 1 ? [lindex $UF10B 0] : {}}]
puts "UA-LONG len=[string length $UF10S]"
check {UF10 issue 0983 a very long value does not cost the user the advice. One\
 line, it still ends with what they can do about it, the shortened value is\
 marked as shortened, and the whole line stays short enough to read -- today it\
 stops dead in the middle of the last sentence with nothing to say it was cut} \
  [list [llength $UF10B] \
        [uf_yes {[string first {no other instance asks for} $UF10S] >= 0}] \
        [uf_yes {[string first {...} $UF10S] >= 0}] \
        [uf_yes {[string length $UF10S] > 0 && [string length $UF10S] < 1000}]] \
  {1 1 1 1}

set UF11L [uf_iw_with nlprop]
check {UF11 issue 0983 a value the user typed on two lines does not split the\
 warning in two. The info window gets ONE line about it, it begins at the\
 beginning of the sentence, and it still carries the spelling advice -- today\
 the second half arrives as its own line starting in the middle of a word} \
  [list [llength $UF11L] [uf_midsentence $UF11L] \
        [uf_yes {[llength $UF11L] == 1 &&
                 [string first {Check the spelling} [lindex $UF11L 0]] >= 0}]] \
  {1 0 1}

set UF20N [ua_netlist $UF_DEEP]
set UF20L [uf_sets [ua_lines] zzdeep]
set UF20S [expr {[llength $UF20L] == 1 ? [lindex $UF20L 0] : {}}]
puts "UA-DEEP len=[string length $UF20S]"
check {UF20 issue 0983 GUARD UA-ELIDE a sheet buried deep enough that its path\
 will not fit in the sentence is still named by the part that identifies it --\
 the file, not the first hundred characters of the directory it lives in -- and\
 the shortening is marked. One line, it names uadeep.sch, it carries the marker,\
 and the whole line stays short enough to read} \
  [list [llength $UF20L] \
        [uf_yes {[string first {uadeep.sch} $UF20S] >= 0}] \
        [uf_yes {[string first {...} $UF20S] >= 0}] \
        [uf_yes {[string length $UF20S] > 0 && [string length $UF20S] < 1000}]] \
  {1 1 1 1}

set UF_TBSI [file join $repo xschem_library examples tb_symbol_include.sch]
set UF12N [ua_netlist $UF_TBSI]
set UF12L [ua_lines]
puts "UA-COUNT tb_symbol_include.sch: $UF12N (mid-sentence [uf_midsentence $UF12L])"
check {UF12 issue 0983 SHIPPED on the one shipped sheet that carries a value\
 typed over two lines, every warning the netlist produces begins at the\
 beginning of the sentence. Today one of them begins with the words symbol\
 reference to use in netlist, which is the tail of the user's own comment and\
 reads as gibberish} \
  [list [uf_yes {$UF12N > 0}] [uf_midsentence $UF12L]] {1 0}

# --- UF13: the advice itself, and where it is written ------------------------
set UF13N [ua_netlist $UF_TOP]
set UF13B [uf_sets [ua_lines] zznone]
set UF13S [expr {[llength $UF13B] == 1 ? [lindex $UF13B 0] : {}}]
check {UF13 issue 0982 the advice is safe to follow. It tells the user the cell\
 name has to be one no other instance asks for, and says what goes wrong if it\
 is not -- two copies asking for the same name quietly share one body and only\
 the first one's setting survives, which is what the old wording walked them\
 into. And RULING D5-4: the sentence is still built in exactly one place and\
 handed to the info window exactly once} \
  [list [uf_yes {[string first {no other instance asks for} $UF13S] >= 0}] \
        [uf_yes {[string first {share one copy} $UF13S] >= 0}] \
        [uf_yes {[string first {attribute of its own as well} $UF13S] < 0}] \
        [u_count $UB_FN {my_snprintf(str, S(str)}] \
        [u_count $UB_FN {statusmsg(str,}]] \
  {1 1 1 1 1}

# --- UF14 / UF15 / UF16: issue 0984, the guards nothing was holding ----------
## The list of attribute names the netlister reads for itself, parsed out of the
## C source, then exercised ONE NAME AT A TIME on a sheet that also carries a
## control setting. The control is what makes this honest: a name that quietly
## skipped the whole instance would otherwise look like a name that was properly
## excused. Before this row, 3 of the 55 names were reached by any fixture.
set UF14SRC [u_slurp [file join $repo src token.c]]
set UF14I [string first "unused_attr_stoplist\[\] = \{" $UF14SRC]
set UF14J [expr {$UF14I >= 0 ? [string first "\n\};" $UF14SRC $UF14I] : -1}]
set UF14BODY [expr {$UF14J > 0 ? [string range $UF14SRC $UF14I $UF14J] : {}}]
set UF14NAMES {}
foreach {uf14w uf14g} [regexp -all -inline {"([^"]*)"} $UF14BODY] { lappend UF14NAMES $uf14g }
set UF14BAD {}
set UF14SCH [file join $UA uastop.sch]
foreach uf14n $UF14NAMES {
  set uf14fd [open $UF14SCH w]
  puts $uf14fd "v \{xschem version=3.4.4 file_version=1.2\}"
  puts $uf14fd "G \{\}"
  puts $uf14fd "K \{\}"
  puts $uf14fd "V \{\}"
  puts $uf14fd "S \{\}"
  puts $uf14fd "E \{\}"
  puts $uf14fd "C \{ua/uatsub.sym\} 320 0 0 0 \{name=xS $uf14n=zz zzctl=1\}"
  close $uf14fd
  ua_netlist $UF14SCH
  set uf14l [ua_lines]
  if {[llength [uf_sets $uf14l zzctl]] != 1 || [llength $uf14l] != 1} {
    lappend UF14BAD "$uf14n:[llength $uf14l]"
  }
}
puts "UA-STOPLIST names=[llength $UF14NAMES] unexcused=[llength $UF14BAD] $UF14BAD"
check {UF14 issue 0984 every name on the netlister's own read-for-itself list\
 is exercised, not three of them. Each name is put on an instance next to a\
 control setting nothing reads, and the sheet must say its one thing about the\
 control and nothing about the listed name -- so a name that silently swallowed\
 the whole instance cannot pass as a name that was properly excused} \
  [list [uf_yes {[llength $UF14NAMES] >= 50}] \
        [uf_yes {[string first {NULL} $UF14BODY] >= 0}] \
        [llength $UF14BAD]] \
  {1 1 0}

set UF15N [ua_netlist $UF_TOP]
set UF15L [ua_lines]
check {UF15 issue 0984 GUARD UA-NAME on a fixture of its own. A sheet that\
 writes an instance's settings over two lines behind a SPICE plus marker -- the\
 way the shipped charge pump sheet writes its inverters -- never produces a\
 sentence about an attribute called plus, and the real lost setting on that\
 instance is still reported. Until now this guard's only witness was one\
 shipped sheet's formatting} \
  [list [llength [uf_sets $UF15L +]] [llength [uf_sets $UF15L zzplus]]] {0 1}

check {UF16 issue 0984 STRUCTURAL how loudly this speaks is a decision, and it\
 is now held still. These notices are added to the end of the info window's\
 text and never force the window open or fail the netlist, which is what the\
 open-net notices on the same sheet do. The user has not yet ruled on that, and\
 until they do it must not drift} \
  [list [u_count $UB_FN {statusmsg(str, 2)}] \
        [u_count $UB_FN {statusmsg(str, 1)}] \
        [u_count $UB_FN {statusmsg(str, 3)}]] \
  {1 0 0}

# --- UF18 / UF19: two more ways a setting reaches something ------------------
## Found by re-running the whole-library sweep against the repaired netlister
## rather than by reasoning about it, which is why they are here and not in the
## plan: 6 lines survived UA-TMPL because the cell that reads the setting is
## chosen BY the setting, and 4 more because the reader is the property editor
## rather than a netlist.
set UF_SYMGEN [file join $repo xschem_library generators test_symbolgen.sch]
set UF18N [ua_netlist $UF_SYMGEN]
set UF18L [ua_lines]
set UF18D [u_slurp [file join $scratch test_symbolgen.spice]]
foreach l $UF18L { puts "UA-SYMGEN-LINE: $l" }
puts "UA-COUNT test_symbolgen.sch: $UF18N"
check {UF18 issue 0980 SHIPPED GUARD UA-SYMNAME a setting that picks WHICH cell\
 the instance is built from is the loudest way a setting can reach the\
 simulator, and it must never be called dead. Two instances on the shipped\
 symbol-generator example write their resistance into the cell name itself and\
 the deck really does contain that cell, spelled with the number they typed;\
 the third instance names a cell that takes no such argument, so its setting\
 truly goes nowhere and is still the one thing the sheet says} \
  [list [llength [ua_for x1]] [llength [ua_for x3]] \
        [uf_yes {[string first {symbolgen_tcl_inv_1200} $UF18D] >= 0}] \
        [llength [uf_sets $UF18L ROUT]]] \
  {0 0 1 1}

set UF_SOLAR [file join $repo xschem_library ngspice solar_panel.sch]
set UF19N [ua_netlist $UF_SOLAR]
set UF19D [u_slurp [file join $scratch solar_panel.spice]]
puts "UA-COUNT solar_panel.sch: $UF19N (deck [string length $UF19D] bytes)"
check {UF19 issue 0980 SHIPPED GUARD UA-STOP the setting that says which box\
 the property editor puts the cursor in is read by the editor, not by any\
 netlist, so telling the user it reached nothing and offering to take it off\
 would cost them an editing convenience on a shipped sheet. The solar panel\
 example sets it on two comparators and the netlist now says nothing about it,\
 while the deck really was written and holds the comparator cell} \
  [list $UF19N [uf_yes {[string first {comp_ngspice} $UF19D] >= 0}]] {0 1}

# ============================================================================
# GC. THE SENTENCE THAT SAYS WHICH TRANSISTOR DISAGREES (issue 0974)
# ============================================================================
# WHY THIS GUARD'S WITNESS LIVES ON A FIXTURE NOW. Until issue 0970 was
# repaired the shipped bandgap bench was the guard's own witness: two passgates
# whose schematic said one model while the deck used another. Repairing the
# bench removes that disagreement -- correctly -- and with it the only place in
# the tree where this sentence was ever produced. The fixture keeps it, and
# cannot be repaired away, because x5 and X7 here are deliberately left without
# a copy of the cell to themselves.
catch {xschem load $UATOP}
set GC_BLK [u_ans op_annot::save_cards]
set GC_W {}
set GC_C {}
if {$GC_BLK ne {NOPROC} && ![string match RAISED:* $GC_BLK]} {
  set GC_W [u_ans op_annot::last_warnings]
  set GC_C [u_ans op_annot::last_counts]
}
if {$GC_W eq {NOPROC} || [string match RAISED:* $GC_W]} { set GC_W {} }
set gci 0
foreach w $GC_W { incr gci ; puts "GC-WARN-$gci: $w" }

## The warnings that name a placed instance as a word of its own, and the ones
## that mention it only inside the results-file device path.
proc gc_named {ws inst} {
  set out {}
  foreach w $ws { if {[u_word $w $inst]} { lappend out $w } }
  return $out
}
set GC_X5 [gc_named $GC_W x5]
check {GC1 issue 0974 walking the sheet reports x5's transistor once and the\
 sentence names the instance the user placed, x5, before it names any\
 results-file path -- five passgates on that sheet each hold a transistor\
 called M2, so leading with M2 identifies nothing} \
  [list [llength $GC_X5] \
        [expr {[llength $GC_X5] == 1 ?
               [expr {[string first {@m.} [lindex $GC_X5 0]] < 0 ? 0 :
                      ([regexp -indices "(^|\[^A-Za-z0-9_.\])x5(\[^A-Za-z0-9_.\]|$)" \
                        [lindex $GC_X5 0] gcm] ?
                       [expr {[lindex $gcm 0] < [string first {@m.} [lindex $GC_X5 0]] ? 1 : 0}] : 0)}] : 0}]] \
  {1 1}

check {GC2 GUARD GC-NAME the instance the schematic calls X7 is called X7 in\
 the sentence -- the lowercased spelling exists for comparing against the deck\
 and must not leak into a sentence whose whole job is naming the thing on the\
 sheet} \
  [llength [gc_named $GC_W X7]] 1

check {GC3 issue 0974 the sentence names both spellings -- the model the\
 schematic asks for and the one the simulator was actually given -- and tells\
 the user what they can do about it, instead of stopping at the diagnosis} \
  [list [expr {[llength $GC_X5] == 1 ?
               [expr {[string first {pfet_01v8_lvt} [lindex $GC_X5 0]] >= 0 ? 1 : 0}] : 0}] \
        [expr {[llength $GC_X5] == 1 ?
               [expr {[regexp {pfet_01v8[^_]} "[lindex $GC_X5 0] "] ? 1 : 0}] : 0}] \
        [expr {[llength $GC_X5] == 1 ?
               [expr {[string first {What you can do} [lindex $GC_X5 0]] >= 0 ? 1 : 0}] : 0}]] \
  {1 1 1}

set GC_WALK [u_body op_annot::_walk]
check {GC4 STRUCTURAL RULING D5-4 the walk holds none of the sentence's words:\
 it calls the one place this sentence is written, once, and renders what comes\
 back} \
  [list [expr {$GC_WALK eq {NOPROC} ? $GC_WALK : [u_count $GC_WALK {_why_model_differs}]}] \
        [expr {$GC_WALK eq {NOPROC} ? $GC_WALK : [u_count $GC_WALK {does not pass that setting}]}] \
        [expr {[llength [info commands ::op_annot::_why_model_differs]] ? 1 : 0}]] \
  {1 0 1}

set GC5 NOCOUNTS
if {$GC_C ne {NOPROC} && ![string match RAISED:* $GC_C] && $GC_C ne {}} {
  catch {set GC5 [list [dict get $GC_C netlist_model_differs] [llength $GC_W]]}
}
check {GC5 the count the run reports and the sentences the user reads cannot\
 drift apart: two transistors on this sheet disagree and there are two\
 sentences} $GC5 {2 2}

# ============================================================================
# PD. THE TWO SHIPPED SKY130 MENU ITEMS (issue 0976)
# ============================================================================
# Both ask `xschem translate <inst> @model`, which answers from the SCHEMATIC.
# The deck answers from the symbol template. On x5 and X7 those differ, so the
# .save file names a device the results file will not contain and the
# annotator reads a name nothing wrote.
catch {xschem load $UATOP}
set PD_SAVE [u_ans sky130_save_fet_params]
if {$PD_SAVE ne {NOPROC} && ![string match RAISED:* $PD_SAVE]} {
  foreach l [split $PD_SAVE "\n"] {
    if {[string first {.save} $l] >= 0} { puts "PD-SAVE: [string trim $l]" }
  }
}
proc pd_savelines {txt frag} {
  set n 0
  if {$txt eq {NOPROC} || [string match RAISED:* $txt]} { return -1 }
  foreach l [split $txt "\n"] { if {[string first $frag $l] >= 0} { incr n } }
  return $n
}
## ⚠ x8 IS DELIBERATELY NOT IN THIS ROW. Measured on this fixture: the shipped
## walk this menu item uses cannot descend into an instance that carries a
## schematic= attribute at all -- it prints "Can not descend into x8" and writes
## no save line for it. That is a separate, pre-existing gap in
## sky130_hier_sch_expand and is nothing to do with which model name it asks
## for, so pinning it here would tie issue 0976 to a defect it did not cause.
check {PD1 issue 0976 site 1 the save file the SKY130 menu's Create FET save\
 file item writes names x5's and X7's transistors the way the deck spells them\
 and never the low-threshold spelling the deck does not contain, while x3\
 which overrides nothing is untouched} \
  [list [pd_savelines $PD_SAVE {@m.x5.xm2.msky130_fd_pr__pfet_01v8_lvt}] \
        [pd_savelines $PD_SAVE {@m.x7.xm2.msky130_fd_pr__pfet_01v8_lvt}] \
        [expr {[pd_savelines $PD_SAVE {@m.x5.xm2.msky130_fd_pr__pfet_01v8[}] > 0 ? 1 : 0}] \
        [expr {[pd_savelines $PD_SAVE {@m.x3.xm2.msky130_fd_pr__pfet_01v8[}] > 0 ? 1 : 0}]] \
  {0 0 1 1}

# --- PD2: the user-visible half ----------------------------------------------
# A results file spelled the way the deck spells it -- which is the only way a
# real one can be spelled -- and the annotator asked for the same transistors.
set PD_DEVS [list @m.x3.xm2.msky130_fd_pr__pfet_01v8 \
                  @m.x5.xm2.msky130_fd_pr__pfet_01v8 \
                  @m.x7.xm2.msky130_fd_pr__pfet_01v8]
set pdvars {}
foreach pdd $PD_DEVS {
  foreach pdp {gm gds cgg cgdo cgso} { lappend pdvars "$pdd\[$pdp\]" }
  foreach pdp {vth vdsat} { lappend pdvars "v($pdd\[$pdp\])" }
}
set PD_RAW [file join $scratch ua_op.raw]
set pdt "Title: * unused attr fixture\nDate: Sat Aug 30 00:00:00  2026\nPlotname:\
 Operating Point\nFlags: real\nNo. Variables: [llength $pdvars]\nNo. Points:\
 1\nVariables:\n"
set pdk 0
foreach pdv $pdvars { append pdt "\t$pdk\t$pdv\tnotype\n" ; incr pdk }
append pdt "Values:\n 0"
foreach pdv $pdvars { append pdt "\t1.000000e-03\n" }
set pdf [open $PD_RAW w] ; puts -nonewline $pdf $pdt ; close $pdf

proc pd_descend {nm} {
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem getprop instance $i name] eq $nm} {
      xschem unselect_all ; xschem select instance $i
      xschem descend 1 2 ; return 1
    }
  }
  return 0
}
## The annotator's text for the one transistor inside <inst>, with a raw loaded.
proc pd_text {inst} {
  global UATOP PD_RAW
  catch {xschem load $UATOP}
  catch {xschem annotate_op $PD_RAW 0}
  if {![pd_descend $inst]} { return NODESCEND }
  if {![llength [info commands ::sky130_display_fet_params]]} { return NOPROC }
  if {[catch {sky130_display_fet_params M2} t]} { return "RAISED:$t" }
  return $t
}
## How many of the annotator's rows carry a number rather than a blank.
proc pd_filled {t} {
  if {$t eq {NOPROC} || $t eq {NODESCEND} || [string match RAISED:* $t]} { return -1 }
  set n 0
  foreach l [split $t "\n"] {
    if {[regexp {=\s*$} $l]} { continue }
    if {[regexp {=\s*\S} $l]} { incr n }
  }
  return $n
}
set PD_T3 [pd_text x3]
set PD_T5 [pd_text x5]
set PD_T7 [pd_text X7]
puts "PD-ANNOT x3 filled=[pd_filled $PD_T3] x5 filled=[pd_filled $PD_T5] X7 filled=[pd_filled $PD_T7]"
check {PD2 issue 0976 site 2 with a results file spelled the only way a real\
 one can be, the SKY130 Add FET param annotator shows x5's and X7's numbers\
 instead of a column of blanks -- x3, which overrides nothing, has always\
 worked and still does} \
  [list [expr {[pd_filled $PD_T3] > 0 ? 1 : 0}] \
        [expr {[pd_filled $PD_T5] > 0 ? 1 : 0}] \
        [expr {[pd_filled $PD_T7] > 0 ? 1 : 0}]] \
  {1 1 1}

# --- PD3: the fallback -------------------------------------------------------
# sky130_procs.tcl is sourced unconditionally by the GUI, but a script or a test
# that sources it on its own is not required to have loaded op_annot first. This
# helper must answer, not raise.
catch {xschem load $UATOP}
pd_descend x5
set PD3 NOPROC
if {[llength [info commands ::sky130_model_netlist]]} {
  set pdsaved 0
  if {[llength [info commands ::op_annot::model_netlist]]} {
    rename ::op_annot::model_netlist ::pd_stashed_model_netlist
    set pdsaved 1
  }
  set PD3 [u_ans sky130_model_netlist M2]
  if {$pdsaved} { rename ::pd_stashed_model_netlist ::op_annot::model_netlist }
}
check {PD3 GUARD PDK-FALLBACK with the shared resolver not loaded the sky130\
 helper still answers, and answers what it answered before this change, rather\
 than raising in the middle of a menu item} \
  $PD3 [u_ans xschem translate M2 @model]

set PD_SKY [u_nocomment_tcl [u_slurp [file join $repo sky130A sky130_procs.tcl]]]
## ⚠ RE-ANCHORED, issue 0984 gap 4. The needle used to stop at `@model`, which
## is a PREFIX of the very rename a sabotage pass would make -- `@modelXX` still
## contains `@model`, so the row scored the same count before and after and
## could not fail. Every one of the four call sites in the two shipped helper
## files ends the command with a closing bracket, so the bracket is part of the
## needle now and a rename really does redden these two rows.
check {PD4 STRUCTURAL the shipped sky130 helper file asks what model a device\
 uses in exactly ONE place, and that place goes through the shared resolver --\
 it asked in two places, and both were wrong the same way} \
  [list [u_count $PD_SKY {translate $instname @model]}] \
        [expr {[u_count $PD_SKY {model_netlist}] >= 3 ? 1 : 0}]] \
  {1 1}

set PD_IHP [u_nocomment_tcl [u_slurp [file join $repo ihp-sg13g2 sg13g2_procs.tcl]]]
check {PD5 STRUCTURAL the three matching places in the IHP helper file are\
 deliberately left alone and recorded as such in issue 0976, pinned here so a\
 later change to them is a decision somebody took and not a drift} \
  [u_count $PD_IHP {translate $instname @model]}] 3

} zzerr]} {
  puts "FATAL: uncaught error: $zzerr"
  puts "$::errorInfo"
  incr fail
}

catch {xschem raw clear}

# --- verdict -----------------------------------------------------------------
# THE DUAL BANNER IS REQUIRED by tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE OVERALL line as
# well as the RESULT line.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
