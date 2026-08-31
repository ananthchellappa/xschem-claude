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
# the clause "did not reach the simulator", and that clause is shared by BOTH
# shapes the sentence now comes in -- see the S4d block below, which is the
# current description. The sentence quoted immediately below is only ONE of the
# two, the accusing one, and it is quoted here because the rows about the advice
# read it; do not take it for the whole of what the tool says.
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
# ============================================================================
# THE S4d REPAIR, 2026-08-30 -- issues 0991, 0992, 0993 AND THE TWO COMMAS
# ============================================================================
# S4d shipped with SEVEN halves of the check that no row could see, and three
# of them put a measurably wrong sentence in the Command window. All seven have
# a row now, and the rows were each proved by rebuilding the tool with that one
# half removed and watching them redden:
#
#   the `short` spelling of a do-not-write mark (0991) -- UF30a, b, c, d.
#     *_ignore takes THREE values, not two. true and open keep the instance out
#     of that netlist; `short` writes it in as a plain wire joining its pins,
#     which carries no settings either. Every fixture written before the repair
#     spelled the mark =true, so all four halves deleted clean.
#
#   an empty format line typed on ONE COPY (0992) -- UF33a and UF33b.
#     The netlisters stop looking the moment the copy NAMES the attribute; they
#     do not ask whether it holds anything. A check that asked the other
#     question read the CELL's format line, which that netlist never parses,
#     and got both shapes wrong in opposite directions -- it told a designer to
#     take off a setting the VHDL netlist really writes, and it named VHDL as
#     the carrier of a setting no netlist held.
#
#   a setting whose value is EMPTY (0993) -- UF32.
#     The two backends that pass template parameters in disagree about what
#     empty means. VHDL strips the quotes as it parses and writes nothing;
#     Verilog keeps them and writes .knob with an empty string in it. Naming
#     both was half a fabricated claim, RULING D5-1.
#
#   the copy's own format line WINS, it is not added to the cell's -- UF31.
#     UF25 reddens when that lookup is deleted outright but NOT when the two
#     are OR'd back together, because until the uaov fixture no copy anywhere
#     carried a format line reading a different setting from the cell's.
#
#   the comma in the joined list -- UF29 and UF30a-d, above.
#
# Two halves stay deliberately invisible and say so where they live: the
# `xctx->format &&` cost condition on GUARD UA-LVSFMT, and the per-token reset
# of reach and carriers. A row written to see either would be pinning a
# comment, not a behaviour.
#
# THAT SENTENCE WAS REWRITTEN BY ITEM S4c, 2026-08-30. It used to open "on this
# sheet," about instances that were not on the sheet the user had open (issue
# 0981), and it used to end "give <inst> a schematic= attribute of its own as
# well", which walked the reader into a silent collision (issue 0982). Rows UF8
# and UF13 assert that both of those old strings are now ABSENT, so do not
# reinstate either one here as a description of what the tool says.
#
# ============================================================================
# THERE ARE TWO SENTENCES NOW, NOT ONE -- ITEM S4d, issues 0987 and 0988
# ============================================================================
# S4c asked one question -- "can ANY netlist of this cell use this setting?" --
# and went silent whenever the answer was yes. The honest question is BOTH:
# can any format use it, AND does the format being written right now use it.
# Measured on the shipped library, S4c turned 43 wrong accusations into 43
# silences one for one, and xschem_library/examples/loading.sch types
# cap=100.0, 30.0, 20.0 and 40.0 on four capacitors that all still simulate at
# the cell default of 10.0 while the tool says nothing whatever.
#
# So a line of this kind now comes in two shapes. BOTH still carry the contract
# clause "did not reach the simulator", which is how ua_lines() finds the whole
# class, and they are told apart by their third clause:
#
#   SENTENCE A -- nothing anywhere reads it. UNCHANGED from S4c, word for word.
#     ... sets <prop>=<value>, but <symbol> never reads <prop> when the netlist
#     is written, so that setting did not reach the simulator and changed
#     nothing. Check the spelling against the settings this cell does read, or
#     take it off. If you meant to change only this one copy of the cell, add a
#     schematic= attribute to <inst> naming a cell name that no other instance
#     asks for, and that copy is written out on its own with your setting in
#     it. Two instances that ask for the same name quietly share one copy, and
#     only the first one's setting is kept.
#
#   SENTENCE B -- NEW with 0987 and 0988. The SPICE deck drops it, but another
#     netlist of the same cell really does carry it.
#     ... sets <prop>=<value>, but a SPICE netlist of <symbol> does not pass
#     <prop> through, so that setting did not reach the simulator and changed
#     nothing. It is not a spelling mistake and you should not remove it: a
#     <formats> netlist of the same cell does carry it, so deleting it would
#     break that. To get it into the SPICE run as well, the <symbol> symbol has
#     to be changed so its SPICE line passes it through.
#
# THE TWO CALL FOR DIFFERENT ACTIONS, so a row that only counts lines is not
# enough and every row below says which shape it expects -- see ua_kind. And
# sentence B must NEVER tell the user to delete anything: that clause is what
# made issue 0980 destructive, and row UF28 holds it out.
#
# The <formats> clause is measured for THAT instance -- RULING D5-1 -- so it
# reads "VHDL", "Verilog", "Spectre", "tEDAx" or a list of them, never a fixed
# phrase. Rows UF4, UF7, UF24a-c, UF25, UF27, UF30a-d, UF31, UF32, UF33a and
# UN4 each demand one exact list, and it is measured for the SETTING as well as
# for the cell: UF27 is a shipped sheet where a Verilog netlist drops a
# time-typed setting a VHDL one keeps.
#
# AND THE LIST IS JOINED INTO SOMETHING A PERSON READS, which is a separate
# thing to hold. ua_carriers() word-matches the four names independently, so it
# scores the same answer whatever separator was used -- or none. Rows UF29 and
# UF30a-d lift the phrase VERBATIM instead, through ua_carrier_phrase(), and
# they are the only rows in this file that can see a missing comma. Until the
# uajoin fixture arrived with the S4d repair no sheet anywhere in this tree,
# shipped or fixture, produced more than TWO carriers, so both commas were
# executed by nothing and "a VHDL, Verilog netlist" could have shipped past
# every check -- against the PLAIN ENGLISH ruling.
#
# TWO ROWS OPEN THE NETLIST THEY NAME rather than taking the sentence's word
# for it. UF32 and UF33a netlist their own fixture sheet to VHDL and to Verilog
# through ua_other_netlist() and read the product, because for those two shapes
# the whole question is whether the named netlist really carries the setting.
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
format="@name @pinlist @symname K=@K M=%M"
verilog_format="assign @V = 1;"
lvs_format="@name @pinlist @symname"
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
puts $uffd "C \{ua/uafmt.sym\} 120 0 0 0 \{name=xT nfin=2 zznone=1 vbb=1 K=3 V=2 M=4\}"
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

# ---------------------------------------------------------------------------
# THE S4d FIXTURE ADDITIONS -- issues 0987, 0988, 0989, and the three halves of
# issue 0986's guards that no fixture in this file could reach.
#
# Each cell below isolates ONE reason a setting can reach a netlist that is not
# the SPICE one being written, so each row has exactly one reason to be red:
#   uaalt  -- four alternate format strings, one token each, so the sentence
#             has to name the right format and cannot fall back on a phrase
#             somebody typed once. Its second instance carries a format string
#             of its OWN, which is the instance-side half of the lookup that
#             today deletes clean with every check green.
#   uasel  -- a subcircuit whose template declares a parameter called select.
#             That name is on the netlister's read-for-itself list, so today it
#             can never be reported however the cell is written -- issue 0989.
#   uatpl  -- a template-declared setting on a cell every backend can emit.
#   uaign  -- the same cell told not to emit in VHDL, Verilog, Spectre or
#             tEDAx. Nothing anywhere can carry the setting, so it is the case
#             the whole diagnostic exists for -- issue 0988 -- and it is the
#             one that gets away today.
#   uaign1 -- the same cell told not to emit in VHDL ONLY, so the sentence has
#             to drop VHDL from the list and keep Verilog.
proc u_cellsym {dir name kbody} {
  u_wr [file join $dir $name.sym] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{$kbody\}
V \{\}
S \{\}
E \{\}
L 4 -20 -20 20 -20 \{\}
B 5 -22.5 -2.5 -17.5 2.5 \{name=A dir=inout\}
T \{@symname\} -20 -34 0 0 0.2 0.2 \{\}"
  u_wr [file join $dir $name.sch] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
C \{devices/iopin\} 200 -300 0 1 \{name=p1 lab=A\}
C \{devices/res\} 400 -300 0 0 \{name=R1 value=1k\}"
}
proc u_topsheet {path body} {
  u_wr $path "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
$body"
}

u_cellsym $UA uaalt {type=subcircuit
format="@name @pinlist @symname"
spectre_format="@name @pinlist @symname SP=@SPTOK"
vhdl_format="-- @name VH=@VHTOK"
tedax_format="conn @name TX=@TXTOK"
verilog_format="assign @VLTOK = 1;"
template="name=x1"}

u_cellsym $UA uasel {type=subcircuit
format="@name @pinlist @symname"
template="name=x1 select=0"}

u_cellsym $UA uatpl {type=subcircuit
format="@name @pinlist @symname"
template="name=x1 knob=1"}

u_cellsym $UA uaign {type=subcircuit
format="@name @pinlist @symname"
template="name=x1 knob=1"
vhdl_ignore=true
verilog_ignore=true
spectre_ignore=true
tedax_ignore=true}

u_cellsym $UA uaign1 {type=subcircuit
format="@name @pinlist @symname"
template="name=x1 knob=1"
vhdl_ignore=true}

set UF_ALT [file join $UA uaalt_top.sch]
u_topsheet $UF_ALT {C {ua/uaalt.sym} 120 0 0 0 {name=xALT SPTOK=1 VHTOK=2 TXTOK=3 VLTOK=4 zzalt=1}
C {ua/uaalt.sym} 320 0 0 0 {name=xIX IXTOK=9 zzix=1 spectre_format="@name @pinlist @symname IX=@IXTOK"}}

set UF_SEL [file join $UA uasel_top.sch]
u_topsheet $UF_SEL {C {ua/uasel.sym} 120 0 0 0 {name=xMUX select=1 zzctl=1}}

set UF_TPL [file join $UA uatpl_top.sch]
u_topsheet $UF_TPL {C {ua/uatpl.sym} 120 0 0 0 {name=xTP knob=99 zzctl=1}}

set UF_IGN [file join $UA uaign_top.sch]
u_topsheet $UF_IGN {C {ua/uaign.sym} 120 0 0 0 {name=xIG knob=99 zzctl=1}}

set UF_IGN1 [file join $UA uaign1_top.sch]
u_topsheet $UF_IGN1 {C {ua/uaign1.sym} 120 0 0 0 {name=xI1 knob=99 zzctl=1}}

## The same do-not-write marks, typed on ONE COPY of the cell instead of on the
## cell itself. uatpl.sym carries none of them, so only the instance can be the
## reason VHDL and Verilog drop out -- and the instance half of that lookup had
## no witness anywhere until this sheet.
set UF_IGNI [file join $UA uaigni_top.sch]
u_topsheet $UF_IGNI {C {ua/uatpl.sym} 120 0 0 0 {name=xII knob=99 zzctl=1 vhdl_ignore=true verilog_ignore=true}}

## THE S4d REPAIR FIXTURES -- issues 0991, 0992, 0993 and the two commas.
## Every one of these was a half of the check that could be deleted with all 57
## checks in this file green, and three of them put a measurably wrong sentence
## in the Command window while doing it.
##   uajoin  -- a cell all FOUR backends really do carry the setting through, so
##              the sentence has to join three and four names and not two.
##              Nothing in this file or in the shipped library produced more
##              than two carriers, so both commas were written by nothing and
##              "a VHDL, Verilog netlist" could have shipped.
##   uaov    -- the SYMBOL's Spectre line reads the setting and the copy on the
##              sheet brings a Spectre line of its OWN that reads something
##              else. The netlisters take the copy's and never parse the
##              symbol's; the older code OR'd the two, and OR and copy-wins give
##              the same answer on every other sheet in this file.
##   uaemptf -- the symbol has VHDL and Verilog lines reading other tokens, its
##              template declares knob, and one copy types vhdl_format="". An
##              empty override is PRESENT to the netlister, which then writes
##              the template parameters after all: the VHDL netlist of that copy
##              really does say knob => 99.
##   uaemptg -- the same shape with the symbol's VHDL line reading knob and the
##              template declaring nothing, so nothing anywhere carries it.
u_cellsym $UA uajoin {type=subcircuit
format="@name @pinlist @symname"
spectre_format="@name @pinlist @symname K=@knob"
tedax_format="conn @name K=@knob"
template="name=x1 knob=1"}

u_cellsym $UA uaov {type=subcircuit
format="@name @pinlist @symname"
spectre_format="@name @pinlist @symname SP=@OVTOK"
template="name=x1"}

u_cellsym $UA uaemptf {type=subcircuit
format="@name @pinlist @symname"
vhdl_format="-- @name VH=@VHOTHER"
verilog_format="assign @VLOTHER = 1;"
template="name=x1 knob=1"}

u_cellsym $UA uaemptg {type=subcircuit
format="@name @pinlist @symname"
vhdl_format="-- @name VH=@knob"
verilog_format="assign @VLOTHER = 1;"
template="name=x1"}

## THE THIRD SPELLING OF A DO-NOT-WRITE MARK, issue 0991. *_ignore takes three
## values, not two: true and open keep the instance out of that netlist
## altogether, and `short` writes it in as a plain WIRE joining its pins, which
## carries no settings either. Every fixture above this line spells the mark
## =true, so the four halves of the mask that read `short` had no witness at
## all. One copy per mark, so each row demands the one list that survives.
set UF_JOIN [file join $UA uajoin_top.sch]
u_topsheet $UF_JOIN {C {ua/uajoin.sym} 120 0 0 0 {name=xJN knob=99 zzjn=1}
C {ua/uajoin.sym} 320 0 0 0 {name=xJH knob=99 zzjh=1 vhdl_ignore=short}
C {ua/uajoin.sym} 520 0 0 0 {name=xJV knob=99 zzjv=1 verilog_ignore=short}
C {ua/uajoin.sym} 720 0 0 0 {name=xJS knob=99 zzjs=1 spectre_ignore=short}
C {ua/uajoin.sym} 920 0 0 0 {name=xJT knob=99 zzjt=1 tedax_ignore=short}}

set UF_OV [file join $UA uaov_top.sch]
u_topsheet $UF_OV {C {ua/uaov.sym} 120 0 0 0 {name=xOV OVTOK=7 zzov=1 spectre_format="@name @pinlist @symname OT=@OTHERTOK"}
C {ua/uaov.sym} 320 0 0 0 {name=xSY OVTOK=8 zzsy=1}}

## A setting with an EMPTY value, issue 0993. The two backends that walk the
## template disagree about what empty means -- VHDL strips the quotes as it
## parses and writes nothing, Verilog keeps them and writes .knob ( "" ) -- so
## naming both would be half a fabricated claim.
set UF_MTV [file join $UA uamtv_top.sch]
u_topsheet $UF_MTV {C {ua/uatpl.sym} 120 0 0 0 {name=xEM knob="" zzem=1}}

set UF_EFMT [file join $UA uaefmt_top.sch]
u_topsheet $UF_EFMT {C {ua/uaemptf.sym} 120 0 0 0 {name=xEA knob=99 zzea=1 vhdl_format=""}
C {ua/uaemptg.sym} 320 0 0 0 {name=xEB knob=99 zzeb=1 vhdl_format=""}}

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
## ISSUE 0987 AND 0988: THERE ARE TWO SENTENCES, AND "THE TOOL SPOKE" IS NO
## LONGER AN ANSWER. A is "nothing anywhere reads this", B is "the SPICE deck
## drops it but another netlist of the same cell carries it". They call for
## opposite actions -- take it off versus do not take it off -- so a row that
## counted lines alone would pass while the tool told a designer the exact
## reverse of the truth. Every row below states the shape it expects.
## AB and ? are deliberate: a sentence that grew both clauses, or neither, is
## not quietly scored as one of them.
proc ua_kind {l} {
  set b [expr {[string first {does not pass} $l] >= 0 &&
               [string first {SPICE netlist of} $l] >= 0}]
  set a [expr {[string first {never reads} $l] >= 0}]
  if {$a && $b} { return AB }
  if {$b} { return B }
  if {$a} { return A }
  return ?
}
proc ua_kinds {ls} { set o {} ; foreach l $ls { lappend o [ua_kind $l] } ; return $o }
## Of a captured list, the ones of one shape.
proc ua_only {ls kind} {
  set o {}
  foreach l $ls { if {[ua_kind $l] eq $kind} { lappend o $l } }
  return $o
}
## RULING D5-1: sentence B names the formats measured for THAT instance, so a
## row can demand the exact list and a phrase somebody hardcoded once reddens.
## Word-boundary matched, so the SPICE the sentence opens with -- which is the
## format that DROPPED the setting -- can never be read as a carrier.
proc ua_carriers {l} {
  set o {}
  foreach f {Spectre VHDL Verilog tEDAx} { if {[u_word $l $f]} { lappend o $f } }
  return $o
}
## RULING PLAIN ENGLISH: the carriers are JOINED into something a person reads
## -- "VHDL or Verilog", "Spectre, VHDL, Verilog or tEDAx". ua_carriers above
## word-matches the four names independently and therefore scores the same
## answer whatever separator was used, or none at all, so it cannot see a
## missing comma. This lifts the phrase verbatim and is the only thing that can.
proc ua_carrier_phrase {l} {
  if {[regexp {should not remove it: a (.+?) netlist of the same cell} $l -> m]} {
    return $m
  }
  return NOPHRASE
}
## RULING D5-1: the sentence names a netlist, so a row can open that netlist and
## look. Call it only AFTER the SPICE lines of the same sheet have been captured
## -- every netlist run clears the info window -- and it puts the type back.
proc ua_other_netlist {sch type ext} {
  catch {xschem load $sch}
  catch {xschem set netlist_type $type}
  catch {xschem netlist}
  catch {xschem set netlist_type spice}
  return [u_slurp [file join $::scratch [file rootname [file tail $sch]].$ext]]
}
## The shape of a list that must hold exactly one line. NOTONE rather than an
## empty answer, so "there was no line" can never be read as "the line was fine".
proc ua_kind1 {ls} {
  if {[llength $ls] != 1} { return NOTONE }
  return [ua_kind [lindex $ls 0]]
}
proc ua_carriers1 {ls} {
  if {[llength $ls] != 1} { return NOTONE }
  return [ua_carriers [lindex $ls 0]]
}
proc ua_phrase1 {ls} {
  if {[llength $ls] != 1} { return NOTONE }
  return [ua_carrier_phrase [lindex $ls 0]]
}
## Of a captured list, the ones naming <inst> as a word of its own. Needed where
## one sheet carries several copies of the same cell each setting the same
## attribute, so filtering by attribute alone cannot tell them apart.
proc uf_inst {lines inst} {
  set o {}
  foreach l $lines { if {[u_word $l $inst]} { lappend o $l } }
  return $o
}
## Every line of this kind the whole run has produced, in order. UF28 is about
## a clause that must not appear in ANY sentence B anywhere, so it cannot be
## asked of one sheet.
set ::UA_ALL {}
proc ua_netlist {sch} {
  catch {xschem load $sch}
  catch {xschem set netlist_type spice}
  catch {xschem netlist}
  set l [ua_lines]
  foreach x $l { lappend ::UA_ALL $x }
  return [llength $l]
}

set UB_N [ua_netlist $UATOP]
set UB_DECK [u_slurp [file join $scratch uatop.spice]]
foreach l [ua_lines] { puts "UA-LINE: $l" }
puts "UA-COUNT fixture: $UB_N"

set UB_X5 [ua_for x5]

check {UB1 issue 0970 netlisting the sheet says once, in plain English, that\
 the setting the user typed on x5 never reached the simulator -- naming the\
 instance they placed, the setting they typed and the cell it sits in, and\
 ending by telling them what they can do about it. And it is the "nothing\
 anywhere reads this" sentence, not the "the SPICE deck drops it but another\
 netlist carries it" one: modelp is a NODE this cell gets wired to, so no\
 netlist of it passes the setting through and telling the user not to remove\
 it would be wrong} \
  [list [llength $UB_X5] \
        [expr {[llength $UB_X5] == 1 ? [u_word [lindex $UB_X5 0] x5] : 0}] \
        [expr {[llength $UB_X5] == 1 ? [u_word [lindex $UB_X5 0] modelp] : 0}] \
        [expr {[llength $UB_X5] == 1 ?
               [expr {[string first {uapass} [lindex $UB_X5 0]] >= 0 ? 1 : 0}] : 0}] \
        [expr {[llength $UB_X5] == 1 ?
               [expr {[string first {schematic=} [lindex $UB_X5 0]] >= 0 ? 1 : 0}] : 0}] \
        [ua_kind1 $UB_X5]] \
  {1 1 1 1 1 A}

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
#
# ⚠ THESE TWO NUMBERS ARE MEASURED, NOT ASSUMED, AND ITEM S4d CHANGES WHAT IS
# MEASURED. They are pinned at zero because that is what the tool prints today,
# and the second sentence issues 0987 and 0988 add will speak about settings
# these benches type that a SPICE deck drops. Whoever adds that sentence must
# RE-RUN these two, read the per-bench breakdown printed below -- which now
# names the shape of every line as well as the count -- and pin the number they
# actually see, per bench. Do NOT weaken either row to "zero or more": the
# noise budget is the whole point of them, and a count nobody looks at is how a
# standing red becomes furniture.
set UB_BENCH [file join $SKY sky130_tests_ase tb_bandgap schematic tb_bandgap.sch]
set UB7N -1
if {[file isfile $UB_BENCH]} { set UB7N [ua_netlist $UB_BENCH] }
foreach l [ua_lines] { puts "UA-BENCH-LINE: [ua_kind $l] $l" }
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
  puts "UA-COUNT [file tail $ubd]: $ubn kinds [ua_kinds [ua_lines]]"
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
## ⚠ RE-ANCHORED AGAIN, issue 0986 gap 4. The third element used to be the
## loose `xctx->tok_size = ` at >= 1, and there are TWO restores in this
## function -- one on the early return an instance carrying schematic= takes,
## one at the end -- so deleting the early one left the loose count at 1 and
## all forty checks stayed green while the netlister's token-found flag carried
## an observer's leftovers into the format-string resolution of every such
## instance. Both restores are pinned by count now.
puts "UA-TOKSIZE restores=[u_count $UB_FN {xctx->tok_size = saved_tok_size}]"
check {UB9 STRUCTURAL GUARD UA-TOKSIZE which no behavioural row can see at\
 today's call site: the new check latches the netlister's token-found flag\
 before its own lookups and puts it back on BOTH ways out -- the early return\
 and the end -- so an observer can never become the reason a real netlist value\
 goes missing if the call site moves} \
  [list [expr {$UB_FN ne {} ? 1 : 0}] \
        [expr {[u_count $UB_FN {saved_tok_size = xctx->tok_size}] >= 1 ? 1 : 0}] \
        [u_count $UB_FN {xctx->tok_size = saved_tok_size}]] \
  {1 1 2}

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
## A list of lines, is every sentence-B one of them naming at least one format
## that carries the setting? An empty list here is a fabricated claim.
proc uf_allcarry {ls} {
  foreach l [ua_only $ls B] { if {![llength [ua_carriers $l]]} { return 0 } }
  return 1
}
set UF_RAMTB [file join $repo xschem_library logic ram_tb.sch]
set UF1N [ua_netlist $UF_RAMTB]
set UF1L [ua_lines]
set UF1D [u_slurp [file join $scratch ram_tb.spice]]
foreach l $UF1L { puts "UA-RAMTB-LINE: [ua_kind $l] $l" }
puts "UA-COUNT ram_tb.sch: $UF1N kinds [ua_kinds $UF1L] (deck [string length $UF1D] bytes)"
check {UF1 issues 0980 AND 0987 SHIPPED netlisting the shipped memory testbench\
 to SPICE accuses nothing of being a mistake -- the data file, the memory size\
 and the access delay are all carried into the Verilog netlist of the same\
 sheet and read by the module body, so telling the user to take them off\
 breaks a working shipped example. But it does not stay silent either: the\
 SPICE deck really does drop all seven, so the sheet says so once per setting,\
 names the netlist that does carry it, and tells the user NOT to remove it.\
 The deck really was written and holds the memory cell, so a sheet that failed\
 to load cannot pass this row by being silent} \
  [list [llength [ua_only $UF1L A]] [llength [ua_only $UF1L B]] \
        [uf_allcarry $UF1L] \
        [uf_yes {[string length $UF1D] > 100}] \
        [uf_yes {[string first {ram} $UF1D] >= 0}]] \
  {0 7 1 1 1}

set UF_LOADING [file join $repo xschem_library examples loading.sch]
set UF2N [ua_netlist $UF_LOADING]
set UF2L [ua_lines]
set UF2D [u_slurp [file join $scratch loading.spice]]
foreach l $UF2L { puts "UA-LOADING-LINE: [ua_kind $l] $l" }
puts "UA-COUNT loading.sch: $UF2N kinds [ua_kinds $UF2L] (deck [string length $UF2D] bytes)"
set UF2CAP [uf_sets $UF2L cap]
set UF2CAPV 0
if {[llength $UF2CAP] == 4} {
  set UF2CAPV 1
  foreach l $UF2CAP {
    if {[ua_kind $l] ne {B} || [lsearch -exact [ua_carriers $l] VHDL] < 0} { set UF2CAPV 0 }
  }
}
check {UF2 issue 0987 SHIPPED THE HEADLINE SHEET. Four capacitors on the\
 shipped loading example are typed 100.0, 30.0, 20.0 and 40.0 and every one of\
 them simulates at the cell default of 10.0, because a SPICE netlist of that\
 cell does not pass the setting through. Today the tool says nothing whatever.\
 It must say so once per capacitor, name VHDL as the netlist that does carry\
 the number, and never suggest deleting it -- the VHDL netlist of the same\
 sheet really does write cap into its generic map. Eleven settings on this\
 sheet are in that position and none of them is a spelling mistake, so not one\
 line may be the accusing shape. The deck really was written and holds both\
 cells} \
  [list [llength [ua_only $UF2L A]] [llength [ua_only $UF2L B]] \
        [llength $UF2CAP] $UF2CAPV \
        [uf_yes {[string first {real_capa} $UF2D] >= 0}] \
        [uf_yes {[string first {pump} $UF2D] >= 0}]] \
  {0 11 4 1 1 1}

## GUARD UA-GENTIME. The same shipped sheet, a different setting on it. Three
## switches on loading.sch are given a delay, and switch_rreal.sym declares that
## setting as a TIME. A Verilog netlist of the cell drops time-typed settings
## from the parameter list it writes for each copy -- VHDL does not -- so naming
## Verilog beside VHDL on those three lines would name a netlist that does not
## in fact carry the number. RULING D5-1.
set UF27L [uf_sets $UF2L del]
set UF27OK 0
if {[llength $UF27L] == 3} {
  set UF27OK 1
  foreach l $UF27L { if {[ua_carriers $l] ne {VHDL}} { set UF27OK 0 } }
}
foreach l $UF27L { puts "UA-GENTIME-LINE: carriers=[ua_carriers $l] $l" }
check {UF27 issue 0987 RULING D5-1 SHIPPED the list of netlists that really do\
 carry the setting is measured for the setting as well as for the cell. Three\
 switches on the shipped loading example are given a delay, and the cell\
 declares that one as a time; a Verilog netlist of it leaves time settings out\
 of the list it writes per copy while a VHDL netlist keeps them. So all three\
 lines name VHDL, and not one of them names Verilog -- a sentence that named a\
 netlist which drops the number would be a claim nobody measured} \
  [list [llength $UF27L] $UF27OK] {3 1}

set UF_ROM8K [file join $repo xschem_library rom8k rom8k.sch]
set UF3N [ua_netlist $UF_ROM8K]
set UF3L [ua_lines]
set UF3V [llength [uf_sets $UF3L VSSBPIN]]
set UF3THIS [llength [uf_with $UF3L {on this sheet}]]
set UF3P1 [llength [uf_with $UF3L rom2_predec1]]
set UF3P3 [llength [uf_with $UF3L rom2_predec3]]
set UF3P4 [llength [uf_with $UF3L rom2_predec4]]
puts "UA-COUNT rom8k.sch: $UF3N (VSSBPIN lines $UF3V, distinct [llength [lsort -unique $UF3L]])"
set UF3VA 0
foreach l [uf_sets $UF3L VSSBPIN] { if {[ua_kind $l] eq {A}} { incr UF3VA } }
puts "UA-ROM8K kinds [ua_kinds $UF3L]"
check {UF3 issue 0980 THE NEGATIVE CONTROL the shipped ROM still gets its real\
 warning: its sheets bind a power pin spelled VSSBPIN while the gate they place\
 spells it VSSPIN, so that binding truly reaches nothing, and the netlister\
 must go on saying so -- IN THE ACCUSING SHAPE, because there is nothing here\
 to keep and the user really should take it off. A repair that merely switches\
 this diagnostic off, or that excuses every setting a symbol happens to name\
 anywhere, or that reclassifies every line as "another netlist carries it",\
 reddens here} \
  [list [uf_yes {$UF3N > 0}] [uf_yes {$UF3V > 0}] \
        [uf_yes {$UF3VA == $UF3V}]] {1 1 1}

# --- UF4 .. UF7: the four ways a cell can consume a setting -------------------
set UF_TN [ua_netlist $UF_TOP]
set UF_TL [ua_lines]
foreach l $UF_TL { puts "UA-FIX-LINE: [ua_kind $l] $l" }
puts "UA-COUNT uafmt_top.sch: $UF_TN kinds [ua_kinds $UF_TL]"
set UF_CTL [llength [uf_sets $UF_TL zznone]]
set UF_TD [u_slurp [file join $scratch uafmt_top.spice]]

set UF4L [uf_sets $UF_TL nfin]
check {UF4 issues 0980 AND 0987 GUARD UA-TMPL a setting the cell declares as\
 one of its own is never called a mistake -- it is in the symbol's template, so\
 a VHDL netlist of that cell passes it straight in as a parameter. But the\
 SPICE deck being written right now still drops it, so the sheet says so once,\
 in the shape that tells the user NOT to remove it. And the list of netlists\
 that do carry it is measured for THIS cell: this one has a Verilog form of its\
 own, and a cell with its own Verilog line does not get the parameter list, so\
 the sentence must name VHDL and only VHDL. The control setting, which no\
 template and no format string anywhere names, is still reported once} \
  [list [llength [ua_only $UF4L A]] [llength [ua_only $UF4L B]] \
        [ua_carriers1 $UF4L] $UF_CTL] {0 1 VHDL 1}

set UF5L [uf_sets $UF_TL vbb]
check {UF5 issue 0980 GUARD UA-EXTRA a name the symbol lists in extra= is a\
 NODE the cell gets wired to, not a setting the cell reads, so it stays\
 reportable even though the template also mentions it -- and in the ACCUSING\
 shape, because no netlist of this cell passes it through and there is nothing\
 for the user to keep. This is the seam that keeps the shipped bandgap passgate\
 reportable, which is the case this whole diagnostic was written for, and it is\
 also the proof that the new sentence did not swallow it} \
  [list [llength $UF5L] [ua_kinds $UF5L] $UF_CTL] {1 A 1}

check {UF6 issue 0980 GUARD UA-FMT a setting the SPICE format string itself\
 reads is silent, and this is now the only place that guard can be seen from --\
 the older row for it uses a name the symbol's template also declares, so the\
 template rule alone would keep that one quiet and the format rule could be\
 deleted without anything going red} \
  [list [llength [uf_sets $UF_TL K]] $UF_CTL] {0 1}

set UF7L [uf_sets $UF_TL V]
check {UF7 issues 0980 AND 0987 GUARD UA-ALTFMT a setting read only by the\
 cell's Verilog form is not a mistake when the sheet is written to SPICE -- but\
 it is not silent either, because the SPICE deck really does drop it. One line,\
 in the shape that tells the user not to remove it, naming Verilog and nothing\
 else. The question the warning has to answer is BOTH: does any netlist of this\
 cell carry the setting, and does the one being written this minute} \
  [list [llength [ua_only $UF7L A]] [llength [ua_only $UF7L B]] \
        [ua_carriers1 $UF7L] $UF_CTL] {0 1 Verilog 1}

check {UF23 issue 0986 gap 6 GUARD UA-FMT reads BOTH sigils. A format string\
 may call a setting up with a percent sign as well as an at sign, and the\
 shipped library uses the at sign everywhere, so the percent half of that test\
 could be deleted with every check in this file still green. The cell here\
 reads M with a percent sign, the sheet sets M=4, the deck really does carry\
 M=4, and the tool says nothing about M -- calling a setting the netlister\
 visibly consumed a lost one would be a lie} \
  [list [llength [uf_sets $UF_TL M]] \
        [uf_yes {[string first {M=4} $UF_TD] >= 0}] $UF_CTL] {0 1 1}

## GUARD UA-LVSFMT. 110 files in this tree carry an lvs_format, and in LVS mode
## that is the string the deck is written from. A setting read by the ordinary
## format string and absent from the LVS one must not become a lost setting the
## moment somebody turns LVS on -- that is issue 0980's harm arriving by a new
## door. The baseline count is captured and put back so a later row cannot
## inherit LVS mode.
set UF26BASE $UF_TN
set ::lvs_netlist 1
set UF26N [ua_netlist $UF_TOP]
set UF26L [ua_lines]
set UF26K [llength [uf_sets $UF26L K]]
foreach l $UF26L { puts "UA-LVS-LINE: [ua_kind $l] $l" }
set ::lvs_netlist 0
set UF26BACK [ua_netlist $UF_TOP]
puts "UA-LVS n=$UF26N K=$UF26K back=$UF26BACK base=$UF26BASE"
check {UF26 GUARD UA-LVSFMT with LVS netlisting turned on the deck is written\
 from the cell's LVS line instead of its ordinary one, and a setting the\
 ordinary line reads must not suddenly be called dead and offered for deletion.\
 Nothing is said about it, and turning LVS back off restores the sheet's own\
 count exactly} \
  [list $UF26K [uf_yes {$UF26BACK == $UF26BASE}]] {0 1}

# --- UF24 / UF25: which netlist, named -- issue 0986 gap 1 and gap 2 ---------
## Four alternate format strings on one cell, one token each, and NOTHING else
## reads any of them. Before this fixture, four of the six format attributes the
## check consults had no witness at all in the whole file: the spectre, VHDL and
## tEDAx rows could each be deleted with every check green. Each row below
## demands ONE format name, so a hardcoded phrase cannot satisfy all four.
set UF24N [ua_netlist $UF_ALT]
set UF24L [ua_lines]
foreach l $UF24L { puts "UA-ALT-LINE: [ua_kind $l] carriers=[ua_carriers $l] $l" }
puts "UA-COUNT uaalt_top.sch: $UF24N kinds [ua_kinds $UF24L]"
set UF24SP [uf_sets $UF24L SPTOK]
set UF24VH [uf_sets $UF24L VHTOK]
set UF24TX [uf_sets $UF24L TXTOK]
set UF24CT [uf_sets $UF24L zzalt]
set UF25L [uf_sets $UF24L IXTOK]

check {UF24a issue 0987 a setting only the cell's Spectre line reads is dropped\
 by the SPICE deck, so the sheet says so once -- and names Spectre, because\
 that is the netlist measured for this instance} \
  [list [llength [ua_only $UF24SP A]] [llength [ua_only $UF24SP B]] \
        [ua_carriers1 $UF24SP]] {0 1 Spectre}

check {UF24b issue 0987 the same for the cell's VHDL line: one sentence, and it\
 names VHDL} \
  [list [llength [ua_only $UF24VH A]] [llength [ua_only $UF24VH B]] \
        [ua_carriers1 $UF24VH]] {0 1 VHDL}

check {UF24c issue 0987 the same for the cell's tEDAx line: one sentence, and\
 it names tEDAx} \
  [list [llength [ua_only $UF24TX A]] [llength [ua_only $UF24TX B]] \
        [ua_carriers1 $UF24TX]] {0 1 tEDAx}

check {UF24d THE CONTROL on the very same instance: a setting no format string\
 and no template anywhere names is still reported once, in the accusing shape,\
 so the three rows above cannot be passing because the whole instance was\
 skipped} \
  [list [llength $UF24CT] [ua_kinds $UF24CT]] {1 A}

check {UF25 issue 0986 gap 1 a format string the INSTANCE carries, not the\
 symbol. A designer may override any of the cell's netlist lines on one copy of\
 it, and the whole loop that looks there could be deleted today with every\
 check green because no fixture carried one. This instance brings its own\
 Spectre line reading a token nothing else mentions, so the instance-side\
 lookup is the only thing that can classify it} \
  [list [llength [ua_only $UF25L A]] [llength [ua_only $UF25L B]] \
        [ua_carriers1 $UF25L]] {0 1 Spectre}

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

## ISSUE 0986 gap 5. The shortener clamps the caller's requested length down to
## what the destination buffer can actually hold, and no behavioural row can
## reach it: all five call sites ask for 120 into 160 bytes or 60 into 80, and
## the clamp only fires above 156 and 76. Shrinking a field the user reads just
## to make the clamp reachable would trade a real deliverable for a test, so
## this half is pinned where it lives. The C comments are stripped first, or
## the guard's own prose would satisfy the row.
set UF21I [string first "unused_attr_elide(char *dest" $UB_TOKC]
set UF21FN {}
if {$UF21I >= 0} {
  set UF21J [string first "\{" $UB_TOKC $UF21I]
  set UF21D 1
  set UF21K [expr {$UF21J + 1}]
  while {$UF21K < [string length $UB_TOKC] && $UF21D > 0} {
    set UF21C [string index $UB_TOKC $UF21K]
    if {$UF21C eq "\{"} { incr UF21D }
    if {$UF21C eq "\}"} { incr UF21D -1 }
    incr UF21K
  }
  set UF21FN [string range $UB_TOKC $UF21J [expr {$UF21K - 1}]]
}
check {UF21 STRUCTURAL issue 0986 gap 5 the shortener never writes past the end\
 of the buffer it was handed, whatever length the caller asks for. Every call\
 site today asks for less than the buffer holds, so this half cannot be seen\
 from any sentence a user can produce, and it deleted clean with every check in\
 this file green} \
  [list [expr {$UF21FN ne {} ? 1 : 0}] \
        [u_count $UF21FN {max_chars > dest_size - 4}]] \
  {1 1}

## ISSUE 0986, THE SAME ARGUMENT AS UF21 ONE FUNCTION ALONG. The list of netlist
## names is joined into a buffer, and the join stops before it can overrun --
## but there are four names at most, the longest join is 31 characters and the
## only caller hands in 64 bytes, so no sentence a user can produce reaches that
## stop. Shrinking the buffer to make it reachable would trade a sentence the
## reader needs for a test, so it is pinned where it lives. Comments stripped
## first, or the guard's own prose satisfies the row.
set UF22I [string first "ua_reach(int inst, const char *format" $UB_TOKC]
set UF22FN {}
if {$UF22I >= 0} {
  set UF22J [string first "\{" $UB_TOKC $UF22I]
  set UF22D 1
  set UF22K [expr {$UF22J + 1}]
  while {$UF22K < [string length $UB_TOKC] && $UF22D > 0} {
    set UF22C [string index $UB_TOKC $UF22K]
    if {$UF22C eq "\{"} { incr UF22D }
    if {$UF22C eq "\}"} { incr UF22D -1 }
    incr UF22K
  }
  set UF22FN [string range $UB_TOKC $UF22J [expr {$UF22K - 1}]]
}
check {UF22 STRUCTURAL issue 0986 the sentence never writes more netlist names\
 into its buffer than the buffer holds, however many formats turn out to carry\
 the setting. Four is the most there can ever be and the buffer is far larger\
 than four names, so this half cannot be seen from any sentence a user can\
 produce, and it would delete clean with every check in this file green} \
  [list [expr {$UF22FN ne {} ? 1 : 0}] \
        [u_count $UF22FN {>= csize) break}]] \
  {1 1}

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
check {UF13 issue 0982 the advice is safe to follow. This row reads the ACCUSING\
 sentence deliberately -- the control setting nothing anywhere reads -- so it\
 can never drift onto the other one and start describing advice it was not\
 written about. It tells the user the cell name has to be one no other instance\
 asks for, and says what goes wrong if it\
 is not -- two copies asking for the same name quietly share one body and only\
 the first one's setting survives, which is what the old wording walked them\
 into. And RULING D5-4: the sentence is still built in exactly one place and\
 handed to the info window exactly once} \
  [list [ua_kind1 $UF13B] \
        [uf_yes {[string first {no other instance asks for} $UF13S] >= 0}] \
        [uf_yes {[string first {share one copy} $UF13S] >= 0}] \
        [uf_yes {[string first {attribute of its own as well} $UF13S] < 0}] \
        [u_count $UB_FN {my_snprintf(str, S(str)}] \
        [u_count $UB_FN {statusmsg(str,}]] \
  {A 1 1 1 1 1}

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
## ⚠ THE COUNT WAS NOT AN ANCHOR, issue 0986 gap 3. The row demanded fifty or
## more names, and there are fifty-five, so a name could be deleted from the
## list -- the door it holds shut swinging open on every sheet in the tree --
## and this row scored fifty-five and passed. The list is written out in full
## and in order now. `select` is deliberately NOT on it any more: issue 0989.
set UF14EXP [list name lab sig_type verilog_type verilog_gate spice_ignore \
  vhdl_ignore verilog_ignore tedax_ignore spectre_ignore lvs_ignore \
  lvs_netlist only_toplevel embed url symversion place hide \
  hide_texts locked lock comment text tclcommand analysis format \
  spice_format vhdl_format verilog_format tedax_format \
  spectre_format extra extra_pinnumber numslots sim_pinnumber \
  pinnumber spiceprefix highlight net_name propag dir global \
  generic_type template device_model spectre_device_model model-name \
  attach program file class savecurrent top_is_subckt hiersep \
  bus_replacement_char]
check {UF14 issues 0984 AND 0986 every name on the netlister's own\
 read-for-itself list is exercised, not three of them, and the list itself is\
 held still name for name and in order -- a count alone let a name be dropped\
 with every check green. Each name is put on an instance next to a control\
 setting nothing reads, and the sheet must say its one thing about the control\
 and nothing about the listed name. And the name a designer is most likely to\
 give a real subcircuit parameter, select, is no longer excused unconditionally\
 here -- issue 0989} \
  [list [uf_yes {[join $UF14NAMES { }] eq [join $UF14EXP { }]}] \
        [uf_yes {[lsearch -exact $UF14NAMES select] < 0}] \
        [uf_yes {[string first {NULL} $UF14BODY] >= 0}] \
        [llength $UF14BAD]] \
  {1 1 1 0}

## ISSUE 0989, the excused half. A handful of names are read by the editor
## rather than by any netlist, so they are excused only while the cell does not
## declare them as one of its own parameters. Shipped
## xschem_library/ngspice/solar_panel.sch is the sheet that needs this: it sets
## select= on two comparators for the property editor, and comp_ngspice.sym's
## template declares no such parameter, so it stays silent -- see UF19.
set UF14CPI [string first "unused_attr_cellparam_stoplist\[\] = \{" $UF14SRC]
set UF14CPJ [expr {$UF14CPI >= 0 ? [string first "\n\};" $UF14SRC $UF14CPI] : -1}]
set UF14CPB [expr {$UF14CPJ > 0 ? [string range $UF14SRC $UF14CPI $UF14CPJ] : {}}]
set UF14CP {}
foreach {uf14cw uf14cg} [regexp -all -inline {"([^"]*)"} $UF14CPB] { lappend UF14CP $uf14cg }
set UF14BSCH [file join $UA uacellparam.sch]
u_topsheet $UF14BSCH {C {ua/uatsub.sym} 320 0 0 0 {name=xS select=1 zzctl=1}}
set UF14BN [ua_netlist $UF14BSCH]
set UF14BL [ua_lines]
puts "UA-CELLPARAM list=$UF14CP n=$UF14BN kinds [ua_kinds $UF14BL]"
check {UF14b issue 0989 the names excused only while the cell does not declare\
 them are a list of their own, and it holds exactly the one name that moved.\
 On a cell whose template declares no such parameter the setting is still\
 excused, so the editing convenience a shipped sheet depends on is untouched,\
 while the control setting beside it is reported once} \
  [list $UF14CP [llength [uf_sets $UF14BL select]] \
        [llength [uf_sets $UF14BL zzctl]]] \
  {select 0 1}

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
# UN. THE SETTING NAMED select, AND THE SETTING NOBODY CAN CARRY
#     issues 0989 and 0988
# ============================================================================
## Four cells that differ from one another by one thing each, so the three
## answers -- silent, "the deck drops it but VHDL carries it", "nothing
## anywhere carries it" -- can be told apart by rows and not by reading.
set UN1N [ua_netlist $UF_SEL]
set UN1L [ua_lines]
foreach l $UN1L { puts "UA-SEL-LINE: [ua_kind $l] carriers=[ua_carriers $l] $l" }
set UN1S [uf_sets $UN1L select]
check {UN1 issue 0989 a subcircuit parameter a designer named select. The cell\
 declares it in its own template, the sheet types select=1 on one copy, and the\
 deck carries the cell default instead -- so the setting really did go nowhere\
 in the SPICE run. Today the tool can never say so, whatever the cell looks\
 like, because that name is on a hand-written list of words the editor reads\
 for itself and the list is consulted by NAME with no regard for the cell. One\
 sentence about it, in the shape that says a VHDL or Verilog netlist of the\
 same cell does carry it, and the control setting beside it still gets the\
 accusing one} \
  [list $UN1N [llength [ua_only $UN1S B]] [ua_carriers1 $UN1S] \
        [ua_kinds [uf_sets $UN1L zzctl]]] \
  {2 1 {VHDL Verilog} A}

set UN2N [ua_netlist $UF_IGN]
set UN2L [ua_lines]
foreach l $UN2L { puts "UA-IGN-LINE: [ua_kind $l] carriers=[ua_carriers $l] $l" }
set UN2K [uf_sets $UN2L knob]
check {UN2 issue 0988 THE CASE THE WHOLE DIAGNOSTIC EXISTS FOR. This cell is\
 marked not to be written out in VHDL, Verilog, Spectre or tEDAx, so there is\
 no netlist anywhere that can carry the setting the sheet typed on it, and the\
 deck holds the cell default instead. Today the tool says nothing at all about\
 it, because the cell happens to name it in its own template. It must say the\
 accusing sentence -- there is genuinely nothing here to keep -- and the\
 control setting beside it must still be reported, so a silence cannot pass by\
 having skipped the instance} \
  [list $UN2N [llength $UN2K] [ua_kinds $UN2K] \
        [ua_kinds [uf_sets $UN2L zzctl]]] \
  {2 1 A A}

set UN3N [ua_netlist $UF_TPL]
set UN3L [ua_lines]
foreach l $UN3L { puts "UA-TPL-LINE: [ua_kind $l] carriers=[ua_carriers $l] $l" }
set UN3K [uf_sets $UN3L knob]
check {UN3 issue 0988 the same cell with the four do-not-write marks taken off,\
 which is the only difference. Now a VHDL or Verilog netlist of it really would\
 carry the setting, so the sentence has to be the other one -- do not remove\
 this, the SPICE deck simply does not pass it through. Paired with UN2 this is\
 the only place the difference between the two answers can be seen} \
  [list $UN3N [llength [ua_only $UN3K B]] [ua_carriers1 $UN3K] \
        [ua_kinds [uf_sets $UN3L zzctl]]] \
  {2 1 {VHDL Verilog} A}

set UN4N [ua_netlist $UF_IGN1]
set UN4L [ua_lines]
foreach l $UN4L { puts "UA-IGN1-LINE: [ua_kind $l] carriers=[ua_carriers $l] $l" }
set UN4K [uf_sets $UN4L knob]
check {UN4 issue 0988 the same cell again, this time marked not to be written\
 out in VHDL ONLY. The sentence must drop VHDL from the list of netlists that\
 carry the setting and keep Verilog -- the marks are read one netlist at a\
 time, not as one blanket, and a sentence that named a netlist this cell is\
 never written in would be a fabricated claim} \
  [list $UN4N [llength [ua_only $UN4K B]] [ua_carriers1 $UN4K] \
        [ua_kinds [uf_sets $UN4L zzctl]]] \
  {2 1 Verilog A}

set UN5N [ua_netlist $UF_IGNI]
set UN5L [ua_lines]
foreach l $UN5L { puts "UA-IGNI-LINE: [ua_kind $l] carriers=[ua_carriers $l] $l" }
set UN5K [uf_sets $UN5L knob]
check {UN5 issue 0988 the do-not-write marks typed on ONE COPY of the cell\
 rather than on the cell itself. The cell here is perfectly ordinary -- the\
 same one UN3 uses, where the setting is carried by VHDL and Verilog -- and the\
 only difference is that this one copy is marked not to be written out in\
 either. So nothing anywhere can carry the setting for this copy and the\
 accusing sentence is the truthful one. Until this sheet the marks were only\
 ever read off the cell, and the half that reads them off the copy the designer\
 clicked would delete clean with every check green} \
  [list $UN5N [llength $UN5K] [ua_kinds $UN5K] \
        [ua_kinds [uf_sets $UN5L zzctl]]] \
  {2 1 A A}

# --- UF29 / UF30: the join, and the third spelling of a do-not-write mark -----
## ISSUE 0991 AND THE PLAIN ENGLISH RULING, on one sheet. Five copies of a cell
## every backend really does carry the setting through. The first is plain, and
## it is the only place in the tree -- shipped or fixture -- where the sentence
## has to name more than two netlists, so it is the only witness the commas have.
## The other four each carry ONE do-not-write mark spelled `short`, the third
## value of *_ignore, which writes the copy into that netlist as a plain wire
## carrying nothing. Every fixture written before this one spelled the mark
## =true, so the four halves of the mask that read `short` had no witness at all
## and each of them deleted clean with every check in this file green.
set UF29N [ua_netlist $UF_JOIN]
set UF29L [ua_lines]
foreach l $UF29L { puts "UA-JOIN-LINE: [ua_kind $l] phrase=[ua_carrier_phrase $l] $l" }
puts "UA-COUNT uajoin_top.sch: $UF29N kinds [ua_kinds $UF29L]"
set UF29K [uf_sets [uf_inst $UF29L xJN] knob]
set UF30HK [uf_sets [uf_inst $UF29L xJH] knob]
set UF30VK [uf_sets [uf_inst $UF29L xJV] knob]
set UF30SK [uf_sets [uf_inst $UF29L xJS] knob]
set UF30TK [uf_sets [uf_inst $UF29L xJT] knob]

check {UF29 PLAIN ENGLISH the list of netlists that carry the setting is joined\
 into something a person reads. Four of them here -- the cell has its own\
 Spectre and tEDAx lines reading the setting and its template declares it, so\
 VHDL and Verilog pass it in as well -- and the sentence must read Spectre,\
 VHDL, Verilog or tEDAx. No sheet anywhere in this tree produced more than two\
 carriers before this one, so the comma between them was written by nothing and\
 a run-together list would have shipped} \
  [list [ua_kind1 $UF29K] [ua_phrase1 $UF29K] \
        [ua_kinds [uf_sets $UF29L zzjn]]] \
  {B {Spectre, VHDL, Verilog or tEDAx} A}

check {UF30a issue 0991 the same copy of the same cell told not to be written in\
 VHDL with the mark spelled short, which writes it into the VHDL netlist as a\
 plain wire joining its pins and carries no setting at all. VHDL must drop out\
 of the list and the other three must stay -- naming a netlist the copy does\
 not appear in as an instance is a claim about the designer's circuit that\
 nobody measured} \
  [list [ua_kind1 $UF30HK] [ua_phrase1 $UF30HK] \
        [ua_kinds [uf_sets $UF29L zzjh]]] \
  {B {Spectre, Verilog or tEDAx} A}

check {UF30b issue 0991 the same mark spelled short for Verilog. Verilog drops\
 out and the other three stay, and the list is still joined for a reader} \
  [list [ua_kind1 $UF30VK] [ua_phrase1 $UF30VK] \
        [ua_kinds [uf_sets $UF29L zzjv]]] \
  {B {Spectre, VHDL or tEDAx} A}

check {UF30c issue 0991 the same mark spelled short for Spectre. Spectre drops\
 out, and this is the one that also proves the mark is read for a backend whose\
 only route to the setting is its own format line} \
  [list [ua_kind1 $UF30SK] [ua_phrase1 $UF30SK] \
        [ua_kinds [uf_sets $UF29L zzjs]]] \
  {B {VHDL, Verilog or tEDAx} A}

check {UF30d issue 0991 the same mark spelled short for tEDAx. tEDAx drops out,\
 which leaves three names and so keeps a comma in the sentence} \
  [list [ua_kind1 $UF30TK] [ua_phrase1 $UF30TK] \
        [ua_kinds [uf_sets $UF29L zzjt]]] \
  {B {Spectre, VHDL or Verilog} A}

# --- UF31: the copy's own format line wins, it is not added to the cell's -----
## ISSUE 0986 GAP 1, THE HALF UF25 CANNOT SEE. UF25 reddens when the lookup on
## the copy is deleted outright. It does NOT redden when the two lookups are OR'd
## back together, because the only copy in this file that carries a format line
## of its own reads the same setting the cell's line reads, and OR and copy-wins
## give the same answer there. Here the cell's Spectre line reads OVTOK and the
## copy's own Spectre line reads something else, so the two disagree: the
## netlisters parse the copy's line and never the cell's, which means OVTOK
## reaches nothing and the accusing sentence is the truthful one. The second
## copy is the control -- no line of its own, so the cell's line governs and
## Spectre really does carry it.
set UF31N [ua_netlist $UF_OV]
set UF31L [ua_lines]
foreach l $UF31L { puts "UA-OV-LINE: [ua_kind $l] phrase=[ua_carrier_phrase $l] $l" }
set UF31OV [uf_sets [uf_inst $UF31L xOV] OVTOK]
set UF31SY [uf_sets [uf_inst $UF31L xSY] OVTOK]
check {UF31 issue 0986 gap 1 a copy that brings its OWN Spectre line is\
 netlisted through that line and the cell's is never parsed, so a setting only\
 the cell's line reads reaches nothing and the sheet must say so in the accusing\
 shape. The copy beside it, which brings no line of its own, must still be told\
 not to remove the same setting because Spectre really does carry it there} \
  [list [ua_kind1 $UF31OV] [ua_kind1 $UF31SY] [ua_phrase1 $UF31SY] \
        [ua_kinds [uf_sets $UF31L zzov]]] \
  {A B Spectre A}

# --- UF32: a setting with an empty value -- issue 0993 -----------------------
## THE ROW OPENS THE NETLISTS IT NAMES. The two backends that pass a template
## parameter in disagree about what an empty value is: the VHDL netlister strips
## the quotes as it parses and then writes nothing at all, the Verilog one keeps
## them and writes .knob with an empty string in it. So on this sheet exactly one
## of the two carries the setting, and a sentence naming both would be half a
## fabricated claim -- RULING D5-1. Measured here rather than reasoned: the row
## netlists the same sheet to VHDL and to Verilog and reads the products.
set UF32N [ua_netlist $UF_MTV]
set UF32L [ua_lines]
foreach l $UF32L { puts "UA-MTV-LINE: [ua_kind $l] phrase=[ua_carrier_phrase $l] $l" }
set UF32K [uf_sets $UF32L knob]
set UF32VH [ua_other_netlist $UF_MTV vhdl vhdl]
set UF32VL [ua_other_netlist $UF_MTV verilog v]
puts "UA-MTV vhdl-has-generic=[u_count $UF32VH {knob =>}] verilog-has-param=[u_count $UF32VL {.knob}]"
check {UF32 issue 0993 a setting typed with nothing in it. The cell's template\
 declares it, so both the VHDL and the Verilog netlist were named as carriers --\
 but the VHDL netlist of this very sheet has no such line in its generic map at\
 all, only the cell's own default, while the Verilog one really does pass the\
 empty value in. The sentence must name Verilog alone, and this row opens both\
 netlists and looks rather than taking the sentence's word for it} \
  [list [ua_kind1 $UF32K] [ua_phrase1 $UF32K] \
        [u_count $UF32VH {knob =>}] \
        [uf_yes {[u_count $UF32VL {.knob}] > 0}] \
        [ua_kinds [uf_sets $UF32L zzem]]] \
  {B Verilog 0 1 A}

# --- UF33: an empty format override on one copy -- issue 0992 ----------------
## THE HARM OF ISSUE 0980 ARRIVING THROUGH A NEW DOOR. The netlisters decide
## whether to look at the cell's format line by asking whether the copy names
## the attribute at all -- not whether it holds anything -- so a copy typing
## vhdl_format with nothing in it stops the search there, finds the string
## empty, and writes the cell's template parameters after all. A check that
## asked the other question fell through to the CELL's line, which that netlist
## never reads, and got both shapes wrong in opposite directions: on xEA it told
## the designer to take off a setting the VHDL netlist really writes, and on xEB
## it named VHDL as a carrier of a setting that appears in no netlist anywhere.
## Both copies are on one sheet so one VHDL netlist settles both.
set UF33N [ua_netlist $UF_EFMT]
set UF33L [ua_lines]
foreach l $UF33L { puts "UA-EFMT-LINE: [ua_kind $l] phrase=[ua_carrier_phrase $l] $l" }
set UF33AK [uf_sets [uf_inst $UF33L xEA] knob]
set UF33BK [uf_sets [uf_inst $UF33L xEB] knob]
set UF33VH [ua_other_netlist $UF_EFMT vhdl vhdl]
puts "UA-EFMT vhdl generic-maps=[u_count $UF33VH {knob =>}] with-99=[u_count $UF33VH {knob => 99}]"
check {UF33a issue 0992 a copy that types an empty VHDL line of its own. The\
 netlister stops looking the moment the copy names the attribute, finds nothing\
 in it, and writes the cell's template parameters -- so the VHDL netlist of this\
 sheet really does carry knob for this copy, and the tool must say do not remove\
 it and name VHDL. Telling the designer to take it off, which is what a check\
 that fell through to the cell's own VHDL line said, deletes a live setting} \
  [list [ua_kind1 $UF33AK] [ua_phrase1 $UF33AK] \
        [u_count $UF33VH {knob => 99}]] \
  {B VHDL 1}

check {UF33b issue 0992 the mirror, on the same sheet. Here the cell's VHDL line\
 is the one that reads the setting and the cell's template declares nothing, so\
 with the copy's empty override in force the VHDL netlist writes no generic map\
 for it and no netlist anywhere carries the setting. The accusing sentence is\
 the truthful one, and the whole file holds exactly one generic map line for\
 this setting -- the OTHER copy's} \
  [list [ua_kind1 $UF33BK] [u_count $UF33VH {knob =>}] \
        [ua_kinds [uf_sets $UF33L zzeb]]] \
  {A 1 A}

# --- UF28: the clause that must never appear in the new sentence -------------
## ISSUE 0980 WAS DESTRUCTIVE BECAUSE OF ONE CLAUSE. The accusing sentence ends
## by offering to take the setting off, which is right when nothing reads it and
## wrong -- it breaks a working shipped example -- when another netlist of the
## same cell carries it. So the new sentence must say the opposite in words, and
## must not carry either half of the old advice. Asked of every line of this
## kind the whole run produced, and the run must have produced some, or this row
## would pass by there being nothing to check.
set UF28B [ua_only $::UA_ALL B]
set UF28KEEP 0
set UF28OFF 0
set UF28SCH 0
## ⚠ MATCHED WITHOUT REGARD TO CAPITALS, and that is not fussiness. Measured
## while mutation-checking this file: appending the accusing sentence's own
## offer back onto the new one as "Or take it off." -- one capital letter --
## slipped past a case-sensitive needle and every check here stayed green. The
## clause is forbidden however it is spelled.
foreach l $UF28B {
  set uf28low [string tolower $l]
  if {[string first {should not remove it} $uf28low] >= 0} { incr UF28KEEP }
  if {[string first {take it off} $uf28low] >= 0} { incr UF28OFF }
  if {[string first {schematic=} $uf28low] >= 0} { incr UF28SCH }
}
puts "UA-ALL total=[llength $::UA_ALL] sentenceB=[llength $UF28B]\
 keep=$UF28KEEP takeoff=$UF28OFF schematic=$UF28SCH"
check {UF28 issue 0980 THE HARD CONSTRAINT, over every line of this kind the\
 whole run produced. The run really does produce lines of the new shape, and\
 every one of them tells the user in words not to remove the setting, and not\
 one of them carries either half of the old advice -- neither the offer to take\
 it off nor the suggestion to give the instance its own copy of the cell.\
 Following the old advice on a setting the VHDL netlist carries is what broke a\
 shipped example} \
  [list [uf_yes {[llength $UF28B] > 0}] \
        [uf_yes {$UF28KEEP == [llength $UF28B]}] $UF28OFF $UF28SCH] \
  {1 1 0 0}

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
