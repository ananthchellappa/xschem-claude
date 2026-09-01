# tests/headless/test_auto_specialize_1201.tcl -- ISSUE 1201: THE NETLISTER HAS
# TO HONOUR A SETTING TYPED ON ONE COPY OF A CELL, BY ITSELF.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# A designer opens the shipped sky130 bandgap sheet, clicks two of the five
# passgates and types modelp=pfet_01v8_lvt on them, because those two copies
# have to be built from the low-threshold p-device. They press netlist. The
# deck that comes out builds all five copies out of the ordinary device. The
# setting they typed reached the simulator nowhere. Measured on the deck: one
# cell body, zero occurrences of the device they asked for.
#
# The tool CAN do it. If the same designer also types a second attribute,
# schematic=<a name nobody else uses>, on those same two copies, the netlister
# writes a second cell body out of the very same sheet, feeds that copy's own
# settings into it, and the deck is right. That is what the shipped bandgap
# sheet carries today, typed on by hand.
#
# So the user is being asked to invent a unique name for something the tool
# could name itself. In Cadence there is no such token: the netlister
# unique-ifies a specialised cell body on its own. That is the whole of this
# issue.
#
# ============================================================================
# WHAT THIS FILE MEASURES
# ============================================================================
# NO PIXELS, NO SIMULATOR. Everything here is the netlister's own deck and the
# info window's own text, on a scratch COPY of the shipped bandgap sheet -- the
# committed sheets are never written to -- plus a fixture library in the
# scratch directory that separates each guard onto its own instance.
#
# THE SCRATCH COPY IS THE ACCEPTANCE FIXTURE. It is the shipped sheet with the
# two hand-typed ' schematic=passgate_lvtp' tokens stripped off x5 and x6 and
# NOTHING else changed, so what it asks is exactly "does the tool do this by
# itself" and not "does some other sheet behave".
#
# TWO MEASUREMENT TRAPS, both of which produce a FALSE GREEN and both of which
# were hit and corrected while this file was written:
#
#  1. THE TOP BLOCK. Keying results by instance name collapses the top sheet's
#     x3 with a DIFFERENT x3 one level down inside passgate_nlvt, which carries
#     its own schematic= attribute. A run keyed that way reported the headline
#     criterion as already satisfied. Every row below reads the TOP-LEVEL block
#     only, via as_topblock.
#
#  2. THE NETLIST TYPE. 'xschem setprop netlist_type spectre' SILENTLY DOES
#     NOTHING -- it reads back spice. The working spelling is 'xschem set
#     netlist_type'. A row that used setprop would quietly measure SPICE and
#     report a Spectre result. AS22 uses set, and asserts the type took.
#
# WHICH ROWS ARE RED BEFORE THE FIX AND WHICH ARE CONTROLS
# The acceptance rows AS1, AS2, AS4, AS8-AS12, AS23-AS25 and AS28-AS31 are RED
# until the tool does this by itself; that is what they are for. The guard rows
# AS13-AS22 and the no-other-deck-moves rows AS3, AS6, AS7, AS26, AS27 pass
# today and must still pass afterwards -- they are the controls that catch a
# fix which reaches decks it was never meant to touch, and they are proved by
# the sabotage pass, not by being red now.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_auto_specialize_1201.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_auto_specialize_1201.tcl

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
set scratch [test_scratch auto_specialize_1201]

proc as_wr {p body} { set f [open $p w]; puts $f $body; close $f }
proc as_slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
proc as_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## Tcl comments dropped, so a sentence quoted in a comment cannot satisfy a row
## about what the tool SAYS.
proc as_nocomment_tcl {t} {
  set out {}
  foreach l [split $t "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
## C comments dropped, for the same reason -- the guard names this file greps
## for are written in those comments.
proc as_nocomment_c {t} {
  regsub -all {/\*.*?\*/} $t { } t2
  return $t2
}
## The body of a Tcl proc, comments stripped. NOPROC rather than an empty
## answer, so a renamed proc can never satisfy a row expecting silence.
proc as_procbody {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [as_nocomment_tcl $b]
}
## The body of ONE C function, from its signature line to the next closing
## brace at column 0, with C comments already stripped by the caller. NOFUNC
## rather than an empty answer, so a renamed or deleted function can never
## satisfy a row that asks what is inside it.
##
## WHY A ROW WOULD WANT THIS AT ALL. A guard that a second guard already covers
## behaviourally is invisible to every deck a test can write -- disable it and
## the suite stays green while the line that protects the user is gone. The
## sabotage pass measured nine such lines in this feature. Grepping the whole
## file cannot see them either, because the same call appears in the sibling
## that masks it; the question has to be asked of ONE function body.
proc as_cfunc {src sig} {
  set lines [split $src "\n"]
  set n [llength $lines]
  set i 0
  while {$i < $n} {
    if {[string first $sig [lindex $lines $i]] >= 0} { break }
    incr i
  }
  if {$i >= $n} { return NOFUNC }
  set out {}
  for {set j $i} {$j < $n} {incr j} {
    set l [lindex $lines $j]
    lappend out $l
    if {$j > $i && [regexp {^\}} $l]} { break }
  }
  return [join $out "\n"]
}
## How many times <w> appears as a WHOLE name, not butted against another name
## character. as_count would answer 1 for `foo` in `foo_UNREG`, which is how a
## registration row can pass while the suite it names is unregistered.
proc as_wordcount {hay w} {
  return [regexp -all "(^|\[^A-Za-z0-9_\])[string map {. \\.} $w](\[^A-Za-z0-9_\]|$)" $hay]
}
## A stable content fingerprint with no external command behind it -- FNV-1a,
## so a row can pin a whole deck and say "this did not move" without shelling
## out to md5sum.
proc as_fnv {s} {
  set h 2166136261
  foreach c [split $s {}] {
    set h [expr {($h ^ [scan $c %c]) & 0xffffffff}]
    set h [expr {($h * 16777619) & 0xffffffff}]
  }
  return [format %08x $h]
}
## ISSUE 1208. A DECK THIS SUITE PINS BY FINGERPRINT CARRIES THIS CHECKOUT'S
## OWN ABSOLUTE PATH. The netlister writes a `** sch_path:` header per sheet and
## a `** sym_path:` header per symbol (src/spice_netlist.c), each holding the
## full path the file was read from -- 15 of them in the shipped bandgap deck
## alone. Rows AS6 and AS26 fingerprint whole decks to say "nothing else moved",
## and with those lines in the text the fingerprint is a property of WHERE the
## repository happens to sit, so the two rows pass in this checkout and in no
## other. Clone the tree one directory across and they go red having found no
## defect at all.
##
## THE TWO HEADER SHAPES ARE THE WHOLE OF IT, AND THAT WAS MEASURED, NOT
## ASSUMED: of the 15 lines in the shipped bandgap deck that carry this
## checkout's root, all 15 are `** sch_path:` or `** sym_path:` headers. No
## .include line and no other line in any deck this suite fingerprints carries
## the root, so nothing else is dropped -- a wider strip would start hiding
## circuit from the very rows whose job is to notice it moving.
proc as_stripsym {deck} {
  set out {}
  foreach l [split $deck "\n"] {
    if {[regexp {^\*\* (sch|sym)_path: } $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
## Is <w> in <s> as a word of its own, not buried inside a longer name?
proc as_word {s w} {
  return [regexp "(^|\[^A-Za-z0-9_.\])[string map {. \\.} $w](\[^A-Za-z0-9_.\]|$)" $s]
}

# --- reading a deck ---------------------------------------------------------
## MEASUREMENT TRAP 1. The TOP sheet's own block only: everything between the
## '**.subckt' marker the netlister writes for the sheet the user opened and
## its '**.ends'. Sub-cell bodies further down hold instances with the SAME
## names, and one of them -- passgate_nlvt's own x3 -- carries a schematic=
## attribute of its own, so a whole-deck grep answers the headline question
## with somebody else's instance.
proc as_topblock {deck} {
  set out {}
  set inblk 0
  foreach l [split $deck "\n"] {
    if {[regexp {^\*\*\.subckt } $l]} { set inblk 1 ; continue }
    if {$inblk && [regexp {^\*\*\.ends} $l]} { break }
    if {$inblk} { lappend out $l }
  }
  return $out
}
## The cell name a call line names: the last bare word before the first
## name=value setting. 'x5 ADJ2 net3 F2N F2 VCC VSS passgate W_N=0.5' answers
## passgate.
proc as_cellof {line} {
  set c {}
  foreach w [split [string trim $line]] {
    if {$w eq {}} continue
    if {[string first = $w] >= 0} break
    set c $w
  }
  return $c
}
## The cell body a named instance of the TOP sheet calls. NOCALL rather than an
## empty answer, so "the instance was not in the deck at all" can never be read
## as "it called the right thing".
proc as_bodyfor {deck inst} {
  foreach l [as_topblock $deck] {
    set t [string trim $l]
    if {$t eq {}} continue
    if {[lindex [split $t] 0] ne $inst} continue
    return [as_cellof $t]
  }
  return NOCALL
}
## Every cell body the deck defines, in order.
proc as_bodies {deck} {
  set out {}
  foreach l [split $deck "\n"] {
    if {[regexp {^\.subckt[ \t]+(\S+)} $l -> n]} { lappend out $n }
  }
  return $out
}
## The text of one named cell body. NOBODY rather than empty.
proc as_body {deck name} {
  set out {}
  set inblk 0
  foreach l [split $deck "\n"] {
    if {[regexp {^\.subckt[ \t]+(\S+)} $l -> n]} {
      set inblk [expr {$n eq $name}]
      if {$inblk} { continue }
    }
    if {$inblk && [regexp {^\.ends} $l]} { return [join $out "\n"] }
    if {$inblk} { lappend out $l }
  }
  if {[llength $out]} { return [join $out "\n"] }
  return NOBODY
}
## Which p-device the transistor inside a named cell body is built from.
## NOMODEL rather than empty, so a missing body cannot pass a model row.
proc as_pmodel {deck name} {
  set b [as_body $deck $name]
  if {$b eq {NOBODY}} { return NOBODY }
  foreach l [split $b "\n"] {
    if {[regexp {(sky130_fd_pr__pfet\S*)} $l -> m]} { return $m }
  }
  return NOMODEL
}
proc as_nmodel {deck name} {
  set b [as_body $deck $name]
  if {$b eq {NOBODY}} { return NOBODY }
  foreach l [split $b "\n"] {
    if {[regexp {(sky130_fd_pr__nfet\S*)} $l -> m]} { return $m }
  }
  return NOMODEL
}
proc as_uniq {l} {
  set o {}
  foreach x $l { if {[lsearch -exact $o $x] < 0} { lappend o $x } }
  return $o
}

## Every "you typed this and it went nowhere" line the last netlist produced.
## Recognised on the contract clause test_unused_attr_0970.tcl minted, so an
## open-net notice in the same transcript cannot be counted as one.
set ::AS_ALL {}
proc as_lost {} {
  set out {}
  foreach ln [split [xschem get infowindow_text] "\n"] {
    if {[string first {did not reach the simulator} $ln] >= 0} {
      lappend out [string trim $ln]
    }
  }
  return $out
}
## Every line in which the tool says it wrote a separate copy of a cell by
## itself. This is the ONE clause the new note is recognised by, and it is
## deliberately plain English rather than an identifier.
proc as_notes {} {
  set out {}
  foreach ln [split [xschem get infowindow_text] "\n"] {
    if {[string first {wrote a separate copy} $ln] >= 0} {
      lappend out [string trim $ln]
    }
  }
  return $out
}
proc as_for {lines inst} {
  set o {}
  foreach l $lines { if {[as_word $l $inst]} { lappend o $l } }
  return $o
}

if {[catch {

# ============================================================================
# THE FIXTURE LIBRARY
# ============================================================================
# aspass is the shipped passgate cut down: a subcircuit whose SPICE line reads
# W_P and drops modelp and modeln, whose template supplies both, and whose own
# sheet builds its two transistors out of them. That pair -- the cell's SPICE
# line never reads the setting, the cell's own sheet does -- is exactly the
# trigger this issue is about.
set AS [file join $scratch aslib]
file mkdir $AS

as_wr [file join $AS aspass.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modeln=nfet_01v8 modelp=pfet_01v8"
extra="modeln modelp"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}

as_wr [file join $AS aspass.sch] {v {xschem version=3.4.4 file_version=1.2}
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
}
C {sky130_fd_pr/nfet_01v8} 600 -300 0 0 {name=M3
L=0.15
W=W_P
nf=1
mult=1
model=@modeln
spiceprefix=X
}}

## THE MAIN FIXTURE SHEET, one instance per question.
##   x1  sets nothing of its own                     -- the control
##   x2  modelp=pfet_01v8_lvt                        -- the defect itself
##   x3  the SAME setting as x2                      -- must SHARE one body
##   x4  modelp=pfet_01v8_hvt                        -- a DIFFERENT value
##   x5  zzspare=7, which the cell sheet never uses  -- must NOT specialise
##   x6  only W_P, which the SPICE line reads        -- must NOT specialise
##   x7  modelp and modeln                           -- two settings
##   x8  the same two, typed in the other order      -- must SHARE with x7
##   x9  modelp AND schematic= typed by hand         -- today's behaviour kept
##   x10 modelp AND its own format line reading it   -- must NOT specialise
##   M9  a transistor placed straight on the sheet   -- not a cell at all
##
## M9 HAS A SECOND JOB AND IT MUST STAY LAST. Working out a new cell name walks
## every symbol the design has loaded asking each its cell name, and that answer
## comes back in a buffer the next asking overwrites. With aspass the only
## symbol here the walk would end on aspass and row AS23's sentence would read
## correctly whether the code holds on to a copy of the name or not. M9 brings a
## second symbol in, so the walk ends somewhere else. Do not reorder this sheet.
as_wr [file join $AS astop.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/aspass.sym} 120 0 0 0 {name=x1 W_P=0.5}
C {as/aspass.sym} 320 0 0 0 {name=x2 W_P=0.6 modelp=pfet_01v8_lvt}
C {as/aspass.sym} 520 0 0 0 {name=x3 W_P=0.6 modelp=pfet_01v8_lvt}
C {as/aspass.sym} 720 0 0 0 {name=x4 W_P=0.6 modelp=pfet_01v8_hvt}
C {as/aspass.sym} 920 0 0 0 {name=x5 W_P=0.8 zzspare=7}
C {as/aspass.sym} 1120 0 0 0 {name=x6 W_P=0.9}
C {as/aspass.sym} 1320 0 0 0 {name=x7 W_P=0.7 modelp=pfet_01v8_lvt modeln=nfet_01v8_lvt}
C {as/aspass.sym} 1520 0 0 0 {name=x8 W_P=0.7 modeln=nfet_01v8_lvt modelp=pfet_01v8_lvt}
C {as/aspass.sym} 1720 0 0 0 {name=x9 W_P=0.5 modelp=pfet_01v8_lvt schematic=aspass_lvtp}
C {as/aspass.sym} 1920 0 0 0 {name=x10 W_P=0.5 modelp=pfet_01v8_lvt format="@name @pinlist @symname W_P=@W_P MP=@modelp"}
C {sky130_fd_pr/pfet_01v8} 2120 0 0 0 {name=M9
L=0.15
W=1
nf=1
mult=1
model=pfet_01v8
zzspare=7
spiceprefix=X
}}

# --- the four symbols that already have an opinion about their own body ------
## assym names its own sheet. get_additional_symbols' missing-file fallback
## would silently replace that with <cellname>.sch -- a DIFFERENT body -- so a
## specialised copy of this one would be built out of the wrong sheet.
as_wr [file join $AS asbody.sch] {v {xschem version=3.4.4 file_version=1.2}
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

as_wr [file join $AS assym.sym] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{type=subcircuit
format=\"@name @pinlist @symname W_P=@W_P\"
template=\"name=x1 W_P=1
modelp=pfet_01v8\"
extra=\"modelp\"
schematic=\"[file join $AS asbody.sch]\"\}
V \{\}
S \{\}
E \{\}
B 5 -22.5 -2.5 -17.5 2.5 \{name=A dir=inout\}"

## asign suppresses its body entirely.
as_wr [file join $AS asign.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"
extra="modelp"
default_schematic=ignore}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

## asgens builds its body from a generator script.
set ASGEN [file join $AS asgen.sh]
as_wr $ASGEN {#!/bin/sh
cat <<'GENEOF'
v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
GENEOF
}
catch {file attributes $ASGEN -permissions 0755}

as_wr [file join $AS asgens.sym] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{type=subcircuit
format=\"@name @pinlist @symname W_P=@W_P\"
template=\"name=x1 W_P=1
modelp=pfet_01v8\"
extra=\"modelp\"
schematic=\"${ASGEN}(gg)\"\}
V \{\}
S \{\}
E \{\}
B 5 -22.5 -2.5 -17.5 2.5 \{name=A dir=inout\}"

## astm's template names the cell body itself, so the netlister takes the
## .subckt name from there. Two specialised copies would put two bodies in the
## deck under ONE name.
as_wr [file join $AS astm.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @model W_P=@W_P"
template="name=x1 W_P=1
model=astmcell
modelp=pfet_01v8"
extra="modelp"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS astm.sch] {v {xschem version=3.4.4 file_version=1.2}
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

# --- the five fixtures the sabotage pass showed nothing could see -----------
# Each exists because a load-bearing line was switched off, this whole suite
# stayed green, and something the designer would see was wrong.

## ascp is aspass again under a name of its own. It has to be a separate cell:
## row AS11 plants a real decoy file under an aspass-derived name and that file
## stays on disk for the rest of the run, which would answer the collision
## question below for the wrong reason.
as_wr [file join $AS ascp.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"
extra="modelp"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS ascp.sch] {v {xschem version=3.4.4 file_version=1.2}
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

## TWO COPIES WHOSE SETTINGS ARE DIFFERENT BUT WHOSE NAMES SPELL THE SAME.
## `pfet_01v8_lvt` and `pfet_01v8-lvt` are two different devices, and once the
## punctuation in a name is folded to an underscore both copies want to be
## called ascp__modelp_pfet_01v8_lvt. Handing that one name to both puts two
## different cell bodies in the deck under it -- a deck no simulator can read.
as_wr [file join $AS ascoll.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/ascp.sym} 120 0 0 0 {name=xT1 W_P=0.5 modelp=pfet_01v8_lvt}
C {as/ascp.sym} 320 0 0 0 {name=xT2 W_P=0.5 modelp=pfet_01v8-lvt}}

## A CELL WHOSE OWN NAME IS NOT A NAME A SIMULATOR TAKES: it starts with a
## digit and it holds a dash, and the setting value on the copy holds a dash
## too. The fixture the naming row used before this one was `aspass` set to
## `pfet_01v8_lvt`, which is already a legal name before any of the code that
## makes it one has run -- the row held whether that code was there or not.
as_wr [file join $AS 9as-p.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"
extra="modelp"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS 9as-p.sch] {v {xschem version=3.4.4 file_version=1.2}
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

as_wr [file join $AS aspunct.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/9as-p.sym} 120 0 0 0 {name=xP W_P=0.5 modelp=pfet_01v8-lvt}}

## A CELL WHOSE OWN DRAWING IS EDITED BETWEEN TWO NETLIST RUNS OF ONE SESSION.
## What the netlister remembers about a drawing it read off disk is only true
## until somebody saves that drawing. The two versions are held here; the row
## writes the second one over the first, mid-run.
set AS_EDIT_SCH [file join $AS asedit.sch]
set AS_EDIT_USES {v {xschem version=3.4.4 file_version=1.2}
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
set AS_EDIT_DROPS {v {xschem version=3.4.4 file_version=1.2}
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
model=pfet_01v8
spiceprefix=X
}}

as_wr [file join $AS asedit.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"
extra="modelp"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr $AS_EDIT_SCH $AS_EDIT_USES

as_wr [file join $AS asedtop.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/asedit.sym} 120 0 0 0 {name=xE1 W_P=0.5 modelp=pfet_01v8_lvt}}

## A SYMBOL THAT SAYS DO NOT WRITE MY INSIDES OUT AT ALL -- and which, unlike
## asign above, DOES have a drawing of its own sitting beside it that uses the
## setting. asign has no such file, so the classification refuses it for a
## second reason and the row about it holds with the guard gone.
as_wr [file join $AS asig2.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"
extra="modelp"
default_schematic=ignore}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS asig2.sch] {v {xschem version=3.4.4 file_version=1.2}
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

as_wr [file join $AS asdefs.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/asig2.sym} 120 0 0 0 {name=xJ W_P=0.5 modelp=pfet_01v8_lvt}}

## TWO COPIES, ONE SHEET: one whose setting the tool honours, and one that also
## types a setting nothing can use. The first must not be told its setting went
## nowhere; the second must be told, and told the right cell name.
##
## THE TWO PARTS AFTER THEM ARE LOAD-BEARING AND WERE ADDED AFTER MEASUREMENT.
## Working out a new cell name walks every symbol the design has loaded, asking
## each one its cell name -- and the answer to that question comes back in a
## buffer the next asking overwrites. With aspass the ONLY symbol on the sheet
## the walk happens to end on aspass, so the sentence reads correctly whether
## the code holds on to a copy of the name or not, and the row is blind. A pin
## and a transistor placed after the two copies make the walk end somewhere
## else, which is the ordinary case on any real sheet.
as_wr [file join $AS asua.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/aspass.sym} 120 0 0 0 {name=xH1 W_P=0.5 modelp=pfet_01v8_lvt}
C {as/aspass.sym} 320 0 0 0 {name=xH2 W_P=0.5 modelp=pfet_01v8_hvt zzspare=7}
C {devices/iopin} 520 0 0 1 {name=p1 lab=AA}
C {sky130_fd_pr/pfet_01v8} 720 0 0 0 {name=M8
L=0.15
W=1
nf=1
mult=1
model=pfet_01v8
spiceprefix=X
}}

## The second fixture sheet: one copy of each of those, all typing the same
## setting, plus one copy of aspass marked do-not-write.
as_wr [file join $AS asguard.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/assym.sym} 120 0 0 0 {name=xA W_P=0.5 modelp=pfet_01v8_lvt}
C {as/asign.sym} 320 0 0 0 {name=xB W_P=0.5 modelp=pfet_01v8_lvt}
C {as/asgens.sym} 520 0 0 0 {name=xC W_P=0.5 modelp=pfet_01v8_lvt}
C {as/astm.sym} 720 0 0 0 {name=xD W_P=0.5 modelp=pfet_01v8_lvt}
C {as/astm.sym} 920 0 0 0 {name=xE W_P=0.5 modelp=pfet_01v8_hvt}
C {as/aspass.sym} 1120 0 0 0 {name=xF W_P=0.5 modelp=pfet_01v8_lvt spice_ignore=true}}

# --- the registry -----------------------------------------------------------
set SKY [file join $repo sky130A xschem_libs]
set DEFS [file join $AS library.defs]
set fd [open $DEFS w]
puts $fd "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $fd "DEFINE sky130_fd_pr [file join $SKY sky130_fd_pr]"
puts $fd "DEFINE sky130_tests [file join $SKY sky130_tests]"
puts $fd "DEFINE sky130_tests_ase [file join $SKY sky130_tests_ase]"
puts $fd "DEFINE sky130_stdcells [file join $SKY sky130_stdcells]"
puts $fd "DEFINE as $AS"
close $fd
set ::XSCHEM_LIBRARY_DEFS $DEFS
set ::library_registry_defs_only 1
set ::netlist_dir $scratch
catch {uplevel #0 [list source [file join $repo sky130A sky130_procs.tcl]]}

## One netlist run: load, write, and hand back the deck. Every lost-setting
## line the whole run produces is accumulated, because AS24 asks a question no
## single sheet can answer.
set ::AS_LASTTYPE {}
proc as_netlist {sch {type spice} {ext spice}} {
  catch {xschem load $sch}
  catch {xschem set netlist_type $type}
  ## MEASUREMENT TRAP 2, recorded rather than assumed: read the type back and
  ## keep it, so a row that says "as a Spectre netlist" can prove the tool
  ## really was writing one.
  set ::AS_LASTTYPE ZZUNKNOWN
  catch {set ::AS_LASTTYPE [xschem get netlist_type]}
  catch {xschem netlist}
  foreach x [as_lost] { lappend ::AS_ALL $x }
  catch {xschem set netlist_type spice}
  return [as_slurp [file join $::scratch [file rootname [file tail $sch]].$ext]]
}

## ISSUE 1204. THE SAME RUN THROUGH THE OTHER DOOR: a netlist of just the sheet
## on screen -- Shift-N, or `xschem netlist -nohier`. It writes the sheet the
## user is looking at and nothing below it. (Issue 1218: this used to name a
## checkbutton with a particular label. This build has no such box.) THE OUTPUT FILE IS DELETED FIRST: without that, a run that wrote
## nothing at all would hand back the PREVIOUS run's deck and every row below
## would pass on it.
proc as_netlist_nh {sch {type spice} {ext spice}} {
  set out [file join $::scratch [file rootname [file tail $sch]].$ext]
  catch {file delete -force $out}
  catch {xschem load $sch}
  catch {xschem set netlist_type $type}
  set ::AS_LASTTYPE ZZUNKNOWN
  catch {set ::AS_LASTTYPE [xschem get netlist_type]}
  catch {xschem netlist -nohier}
  catch {xschem set netlist_type spice}
  return [as_slurp $out]
}

# ============================================================================
# AS1-AS7. THE ACCEPTANCE ROWS, ON THE SHIPPED BANDGAP SHEET
# ============================================================================
# The committed sheet is COPIED and the copy has the two hand-typed
# ' schematic=passgate_lvtp' tokens stripped off x5 and x6. Nothing else
# changes and the committed sheets are never written to -- the user's bench has
# been churned once already and this file does not do it again.
set BG_SHIPPED [file join $SKY sky130_tests bandgap schematic bandgap.sch]
set BG_TXT [as_slurp $BG_SHIPPED]
set BG_STRIP $BG_TXT
regsub -all { schematic=passgate_lvtp} $BG_STRIP {} BG_STRIP
set BG_NOFIX [file join $AS bandgap_nofix.sch]
as_wr $BG_NOFIX $BG_STRIP

set BG_D [as_netlist $BG_NOFIX]
foreach bgi {x3 x4 x5 x6 x7} { set BG_B($bgi) [as_bodyfor $BG_D $bgi] }
puts "AS-BANDGAP top-sheet passgate calls:"
foreach bgi {x3 x4 x5 x6 x7} { puts "   $bgi -> $BG_B($bgi)" }
puts "AS-BANDGAP bodies: [as_bodies $BG_D]"

check {AS1 THE ACCEPTANCE ROW, issue 1201. The designer typed\
 modelp=pfet_01v8_lvt on two of the five passgates on the shipped bandgap\
 sheet and typed nothing else. Those two copies must be built from a cell body\
 of their own -- not the one the other three share} \
  [list [expr {$BG_B(x5) ne {NOCALL} && $BG_B(x5) ne $BG_B(x3) ? 1 : 0}] \
        [expr {$BG_B(x6) ne {NOCALL} && $BG_B(x6) ne $BG_B(x3) ? 1 : 0}] \
        [expr {$BG_B(x3) eq $BG_B(x4) && $BG_B(x3) eq $BG_B(x7) ? 1 : 0}]] \
  {1 1 1}

check {AS2 and the setting really did reach the simulator: the transistor\
 inside the body those two copies call is the low-threshold p-device they\
 asked for} \
  [as_pmodel $BG_D $BG_B(x5)] sky130_fd_pr__pfet_01v8_lvt

check {AS3 NOTHING ELSE MOVED on that sheet: the other three copies still call\
 the plain passgate cell and its transistor is still the ordinary p-device} \
  [list $BG_B(x3) $BG_B(x4) $BG_B(x7) [as_pmodel $BG_D passgate]] \
  {passgate passgate passgate sky130_fd_pr__pfet_01v8}

check {AS4 SHARING IS CORRECT: the two copies asked for the same thing, so they\
 share ONE cell body -- the five passgates on that sheet are built from exactly\
 two bodies between them, not from one each} \
  [list [expr {$BG_B(x5) eq $BG_B(x6) ? 1 : 0}] \
        [llength [as_uniq [list $BG_B(x3) $BG_B(x4) $BG_B(x5) $BG_B(x6) $BG_B(x7)]]]] \
  {1 2}

check {AS5 THE FIX IS IN THE TOOL, NOT ON THE SHEET: the sheet that produced\
 the deck above carries no schematic= attribute anywhere, and it does carry the\
 setting the designer typed} \
  [list [as_count $BG_STRIP {schematic=}] \
        [as_count $BG_STRIP {modelp=pfet_01v8_lvt}]] \
  {0 2}

## EXPLICIT BEATS IMPLICIT. The COMMITTED sheet, untouched, must netlist
## byte-for-byte as it does today. The fingerprint is pinned, not merely the
## two call lines, because "did any other deck move" is the whole risk of this
## change and a call-line row would not see a body that grew.
set BG_NOW [as_netlist $BG_SHIPPED]
puts "AS-BANDGAP committed fingerprint raw [as_fnv $BG_NOW] stripped\
 [as_fnv [as_stripsym $BG_NOW]] bodies [as_bodies $BG_NOW]"
check {AS6 EXPLICIT BEATS IMPLICIT: the committed bandgap sheet, whose two\
 copies still carry the schematic= attribute somebody typed by hand, netlists\
 to exactly the deck it does today -- same two copies pointed at the same\
 hand-named cell, same deck to the byte} \
  [list [as_bodyfor $BG_NOW x5] [as_bodyfor $BG_NOW x6] \
        [as_fnv [as_stripsym $BG_NOW]]] \
  {passgate_lvtp passgate_lvtp ef8229a9}

set BG_D2 [as_netlist $BG_NOFIX]
check {AS7 DETERMINISTIC: netlisting the same sheet twice in one session gives\
 the same deck to the byte, so a cell name the tool invents cannot drift\
 between two runs of the same design} \
  [expr {$BG_D eq $BG_D2 ? 1 : 0}] 1

# ============================================================================
# AS8-AS12. NAMING, SHARING AND COLLISION, ON THE FIXTURE
# ============================================================================
set A_D [as_netlist [file join $AS astop.sch]]
foreach ai {x1 x2 x3 x4 x5 x6 x7 x8 x9 x10} { set A_B($ai) [as_bodyfor $A_D $ai] }
puts "AS-FIXTURE calls:"
foreach ai {x1 x2 x3 x4 x5 x6 x7 x8 x9 x10} { puts "   $ai -> $A_B($ai)" }
puts "AS-FIXTURE bodies: [as_bodies $A_D]"
puts "AS-FIXTURE notes: [llength [as_notes]]  lost: [llength [as_lost]]"
foreach al [as_notes] { puts "AS-NOTE: $al" }

check {AS8 SHARING IS CORRECT, on the fixture: two copies that ask for exactly\
 the same setting are built from ONE cell body, and it is not the plain one\
 the copy that asked for nothing uses} \
  [list [expr {$A_B(x2) eq $A_B(x3) ? 1 : 0}] \
        [expr {$A_B(x2) ne {NOCALL} && $A_B(x2) ne $A_B(x1) ? 1 : 0}]] \
  {1 1}

check {AS9 DISTINCTNESS -- the trap issue 0982 recorded and nothing has ever\
 tested. Two copies asking for DIFFERENT devices must not quietly share one\
 body with only the first one's setting in it: they get a body each, and BOTH\
 devices are in the deck} \
  [list [expr {$A_B(x2) ne $A_B(x4) ? 1 : 0}] \
        [as_pmodel $A_D $A_B(x2)] \
        [as_pmodel $A_D $A_B(x4)]] \
  {1 sky130_fd_pr__pfet_01v8_lvt sky130_fd_pr__pfet_01v8_hvt}

check {AS10 THE ORDER THE USER TYPED THEM IN IS NOT PART OF THE ANSWER: two\
 copies that set the same two settings, typed in opposite order, are the same\
 request and share one cell body -- and that body really does carry both\
 devices} \
  [list [expr {$A_B(x7) eq $A_B(x8) ? 1 : 0}] \
        [as_pmodel $A_D $A_B(x7)] \
        [as_nmodel $A_D $A_B(x7)]] \
  {1 sky130_fd_pr__pfet_01v8_lvt sky130_fd_pr__nfet_01v8_lvt}

## The decoy is planted under the name the tool INVENTED on the run above, so
## the row cannot be satisfied by a naming scheme nobody collides with; it
## collides with whatever this build chose.
set A_NAME $A_B(x2)
set A_DECOYOK 0
if {$A_NAME ne {NOCALL} && $A_NAME ne $A_B(x1)} {
  as_wr [file join $AS $A_NAME.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}
  as_wr [file join $AS $A_NAME.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=MZZDECOY
L=0.15
W=W_P
nf=1
mult=1
model=nfet_01v8
spiceprefix=X
}}
  set A_DECOYOK 1
}
set A_D3 [expr {$A_DECOYOK ? [as_netlist [file join $AS astop.sch]] : {}}]
set A_B2 [expr {$A_DECOYOK ? [as_bodyfor $A_D3 x2] : {NODECOY}}]
puts "AS-COLLIDE planted=$A_DECOYOK name=$A_NAME second-run body=$A_B2"

check {AS11 A NAME THE TOOL INVENTS MUST NEVER LAND ON A CELL THE DESIGN\
 ALREADY HAS. With a different cell sitting in the library under exactly the\
 name the tool chose, the copy still gets its own body with its own device in\
 it, under some other name, and the cell that was already there is not dragged\
 into the deck} \
  [list $A_DECOYOK \
        [expr {$A_DECOYOK && $A_B2 ne $A_NAME && $A_B2 ne {NOCALL} ? 1 : 0}] \
        [expr {$A_DECOYOK ? [as_pmodel $A_D3 $A_B2] : {NODECOY}}] \
        [expr {$A_DECOYOK ? [as_count $A_D3 {ZZDECOY}] : -1}]] \
  {1 1 sky130_fd_pr__pfet_01v8_lvt 0}

check {AS12 THE INVENTED NAME IS A NAME A SIMULATOR ACCEPTS -- it starts with a\
 letter and holds only letters, digits and underscores -- and the name on the\
 call line is the same string as the name on the cell body it calls. The first\
 element is the one that stops this row passing on the plain cell name: until\
 the tool invents one there is no name to judge} \
  [list [expr {$A_NAME ne {NOCALL} && $A_NAME ne $A_B(x1) ? 1 : 0}] \
        [expr {[regexp {^[A-Za-z][A-Za-z0-9_]*$} $A_NAME] ? 1 : 0}] \
        [expr {[lsearch -exact [as_bodies $A_D] $A_NAME] >= 0 ? 1 : 0}]] \
  {1 1 1}

# ============================================================================
# AS13-AS22. THE GUARDS. These pass TODAY and must still pass afterwards.
# ============================================================================
check {AS13 A COPY THAT ALREADY NAMES ITS OWN CELL KEEPS TODAY'S BEHAVIOUR\
 EXACTLY: it is built from the cell name the designer typed, not from one the\
 tool invented} \
  [list $A_B(x9) [as_pmodel $A_D aspass_lvtp]] \
  {aspass_lvtp sky130_fd_pr__pfet_01v8_lvt}

check {AS14 A TRANSISTOR PLACED STRAIGHT ON THE SHEET IS NOT A CELL: it keeps\
 its own line in the deck and the deck grows no body for it, however many\
 spare settings are typed on it} \
  [list [expr {[regexp {(?m)^XM9 } $A_D] ? 1 : 0}] \
        [as_count $A_D {.subckt M9}]] \
  {1 0}

check {AS15 A SETTING THE CELL'S OWN SHEET NEVER USES BUYS NOTHING, so no\
 separate copy is written for it -- and the tool still says plainly that the\
 setting went nowhere, because it did} \
  [list $A_B(x5) [llength [as_for [as_lost] x5]]] \
  [list $A_B(x1) 1]

check {AS16 A COPY THAT ONLY SETS THINGS THE CELL'S OWN SPICE LINE ALREADY\
 CARRIES gets no separate body and no complaint: its setting is on the call\
 line where it belongs} \
  [list $A_B(x6) [llength [as_for [as_lost] x6]]] \
  [list $A_B(x1) 0]

check {AS16b THE DECISION IS MADE AGAINST THE SPICE LINE THIS COPY IS ACTUALLY\
 WRITTEN THROUGH: a copy carrying its own SPICE line that does read the setting\
 gets no separate body, because its setting already reaches the deck} \
  [list $A_B(x10) [expr {[as_count $A_D {MP=pfet_01v8_lvt}] >= 1 ? 1 : 0}]] \
  [list $A_B(x1) 1]

set G_D [as_netlist [file join $AS asguard.sch]]
foreach gi {xA xB xC xD xE xF} { set G_B($gi) [as_bodyfor $G_D $gi] }
puts "AS-GUARD calls:"
foreach gi {xA xB xC xD xE xF} { puts "   $gi -> $G_B($gi)" }
puts "AS-GUARD bodies: [as_bodies $G_D]"

check {AS17 A CELL WHOSE SYMBOL ALREADY NAMES THE SHEET IT IS BUILT FROM has an\
 opinion about its own body: no separate copy is written, and the deck still\
 holds the sheet the symbol names} \
  [list $G_B(xA) [as_pmodel $G_D assym]] \
  {assym sky130_fd_pr__pfet_01v8}

check {AS18 A CELL WHOSE SYMBOL SAYS DO NOT WRITE MY INSIDES OUT AT ALL keeps\
 saying it: no separate copy, and no cell body of that name anywhere in the\
 deck} \
  [list $G_B(xB) [as_count $G_D {.subckt asign}]] \
  {asign 0}

check {AS19 A CELL WHOSE BODY IS BUILT BY A SCRIPT is left alone: no separate\
 copy, and the body in the deck is still the one the script produced} \
  [list $G_B(xC) [expr {[lsearch -exact [as_bodies $G_D] asgens] >= 0 ? 1 : 0}]] \
  {asgens 1}

check {AS20 A CELL WHOSE TEMPLATE NAMES ITS OWN CELL BODY: two copies of it\
 asking for different devices must not put two bodies in the deck under ONE\
 name, which is a deck no simulator can read. They share the one body} \
  [list $G_B(xD) $G_B(xE) [llength [as_bodies $G_D]] \
        [as_count $G_D {.subckt astmcell}]] \
  {astmcell astmcell 4 1}

check {AS21 A COPY MARKED DO-NOT-WRITE stays out of the deck completely: it is\
 not called anywhere, and no separate copy of the cell is written for it. The\
 last two elements are the whole guard sheet's verdict and they are blind to\
 whatever the new cell names look like: not one of the six copies on it asked\
 for a device that is allowed to reach this deck, so the low- and\
 high-threshold devices must appear in it exactly zero times} \
  [list $G_B(xF) [as_count $G_D {.subckt aspass}] \
        [as_count $G_D {sky130_fd_pr__pfet_01v8_lvt}] \
        [as_count $G_D {sky130_fd_pr__pfet_01v8_hvt}]] \
  {NOCALL 1 0 0}

## MEASUREMENT TRAP 2: 'xschem set', never 'xschem setprop' -- setprop silently
## does nothing and the row would measure SPICE while reporting Spectre.
set SP_D [as_netlist [file join $AS astop.sch] spectre spectre]
set SP_T $::AS_LASTTYPE
set VL_D [as_netlist [file join $AS astop.sch] verilog v]
set VL_T $::AS_LASTTYPE
catch {xschem set netlist_type spice}
puts "AS-MODE spectre bodies: [regexp -all {(?m)^subckt } $SP_D] verilog modules:\
 [regexp -all {(?m)^module } $VL_D]"
check {AS22 THE OTHER NETLIST FORMATS ARE UNTOUCHED: writing the same sheet as\
 a Spectre or a Verilog netlist produces exactly the cell bodies it does today\
 -- this change is for the SPICE deck only, and the netlist type really did\
 change, which 'setprop' would silently not have done} \
  [list [regexp -all {(?m)^subckt } $SP_D] \
        [as_count $SP_D {subckt aspass }] \
        [as_count $SP_D {subckt aspass_lvtp }] \
        [regexp -all {(?m)^module } $VL_D] \
        $SP_T $VL_T \
        [as_count $SP_D {ZZNOFILE}] [as_count $VL_D {ZZNOFILE}]] \
  {2 1 1 3 spectre verilog 0 0}

# ============================================================================
# AS23-AS25. WHAT THE TOOL SAYS, IN PLAIN ENGLISH
# ============================================================================
set A_D4 [as_netlist [file join $AS astop.sch]]
set A_NOTES [as_notes]
set A_N2 [as_for $A_NOTES x2]
check {AS23 THE USER GETS A CELL NAME IN THEIR DECK THAT NOBODY TYPED, so the\
 tool says so once, in plain English: it names the sheet, the copy they placed,\
 the setting they typed, the cell it is a copy of and the new name, it tells\
 them they do not have to add anything to the sheet, and it does not tell them\
 to type an attribute. THE CELL NAME IS ASSERTED AS A WHOLE CLAUSE, not as a\
 word that happens to appear: working out the new name walks every symbol in\
 the design, and before that walk was made safe the sentence described a\
 passgate as "a 130_fd_pr/pfet_01v8" -- while a row looking only for the word\
 aspass passed, because the invented name in the same sentence still had it} \
  [list [llength $A_N2] \
        [expr {[llength $A_N2] == 1 ? [as_word [lindex $A_N2 0] x2] : 0}] \
        [expr {[llength $A_N2] == 1 ? [as_word [lindex $A_N2 0] modelp] : 0}] \
        [expr {[llength $A_N2] == 1 ?
               [expr {[string first {x2 (a aspass) sets modelp=pfet_01v8_lvt} \
                       [lindex $A_N2 0]] >= 0 ? 1 : 0}] : 0}] \
        [expr {[llength $A_N2] == 1 ?
               [expr {[string first {separate copy of aspass called aspass__} \
                       [lindex $A_N2 0]] >= 0 ? 1 : 0}] : 0}] \
        [expr {[llength $A_N2] == 1 ?
               [expr {[string first {do not have to add} [lindex $A_N2 0]] >= 0 ? 1 : 0}] : 0}] \
        [expr {[llength $A_N2] == 1 ?
               [expr {[string first {schematic=} [lindex $A_N2 0]] >= 0 ? 1 : 0}] : 0}]] \
  {1 1 1 1 1 1 0}

## Every lost-setting sentence the whole run has produced, fixture and shipped
## sheets alike. A tool that now does this by itself must stop telling the user
## to do it by hand -- on every sheet, not only on the fixture.
foreach ash {logic/ram_tb.sch examples/loading.sch rom8k/rom8k.sch} {
  set asp [file join $repo xschem_library $ash]
  if {[file isfile $asp]} { as_netlist $asp }
}
set AS_TYPED 0
foreach l $::AS_ALL { if {[string first {schematic=} $l] >= 0} { incr AS_TYPED } }
puts "AS-ADVICE lost lines seen: [llength $::AS_ALL], of which telling the user\
 to type an attribute: $AS_TYPED"
check {AS24 A TOOL THAT FIXES IT MUST NOT STILL TELL YOU TO FIX IT YOURSELF:\
 across every "that setting did not reach the simulator" sentence this whole\
 run produced -- the fixture and three shipped example sheets -- not one tells\
 the designer to go and type a schematic= attribute} \
  [list [expr {[llength $::AS_ALL] > 0 ? 1 : 0}] $AS_TYPED] {1 0}

set AS_TOKC [as_nocomment_c [as_slurp [file join $repo src token.c]]]
set AS_TOKADV {}
foreach l [split $AS_TOKC "\n"] {
  if {[string first {schematic= attribute} $l] >= 0} { lappend AS_TOKADV [string trim $l] }
}
catch {uplevel #0 [list source [file join $repo src op_annot.tcl]]}
set AS_WHY [as_procbody op_annot::_why_model_differs]
puts "AS-SURFACES token.c advice lines: [llength $AS_TOKADV];\
 _why_model_differs: [expr {$AS_WHY eq {NOPROC} ? {absent} : {present}}]"
check {AS25 STRUCTURAL, AND IT IS THE SECOND SURFACE NOBODY NAMED: the\
 annotation surface tells the designer the same thing -- give this copy a\
 schematic= attribute of its own -- and so does the netlister's own warning.\
 Both sentences have to stop saying it, or the tool fixes the problem and still\
 tells you to fix it yourself, in two places} \
  [list [llength $AS_TOKADV] \
        [expr {$AS_WHY eq {NOPROC} ? {NOPROC} :
               [as_count $AS_WHY {schematic=}]}]] \
  {0 0}

# ============================================================================
# AS26-AS27. NO OTHER DECK MAY MOVE
# ============================================================================
# Every shipped sheet that COULD enter the new path -- the two bandgap sheets
# and the four benches above them -- netlisted and fingerprinted. Every copy on
# them that would qualify already carries a schematic= attribute somebody
# typed, so not one of these decks may move by a single byte.
set AS_SHIPPED [list \
  [file join $SKY sky130_tests bandgap schematic bandgap.sch] \
  [file join $SKY sky130_tests_ase bandgap schematic bandgap.sch] \
  [file join $SKY sky130_tests tb_bandgap schematic tb_bandgap.sch] \
  [file join $SKY sky130_tests_ase tb_bandgap schematic tb_bandgap.sch] \
  [file join $SKY sky130_tests tb_bandgap_opamp schematic tb_bandgap_opamp.sch] \
  [file join $SKY sky130_tests_ase tb_bandgap_opamp schematic tb_bandgap_opamp.sch]]
set AS_FP {}
set AS_SEEN 0
foreach s $AS_SHIPPED {
  if {![file isfile $s]} { lappend AS_FP MISSING ; continue }
  incr AS_SEEN
  set d [as_netlist $s]
  lappend AS_FP [as_fnv [as_stripsym $d]]
  puts "AS-SHIPPED [file tail $s]: raw [as_fnv $d] stripped\
 [as_fnv [as_stripsym $d]] bodies [llength [as_bodies $d]]"
}
check {AS26 NO OTHER DECK MOVES: every shipped sheet this change could possibly\
 reach -- both copies of the bandgap and the four benches above them -- writes\
 the same deck it writes today, to the byte. A single one of these moving is a\
 stop, not a detail} \
  [list $AS_SEEN $AS_FP] \
  {6 {ef8229a9 6d587df9 ac4eacfe 63ff78b7 561e2e30 64c14554}}

set AS_TB 0
set AS_TBLOST 0
set AS_TBBODY 0
foreach ubd [lsort [glob -nocomplain -directory [file join $SKY sky130_tests_ase] -type d *]] {
  set ubs [file join $ubd schematic [file tail $ubd].sch]
  if {![string match tb_* [file tail $ubd]]} { continue }
  if {![file isfile $ubs]} { continue }
  incr AS_TB
  set d [as_netlist $ubs]
  incr AS_TBLOST [llength [as_lost]]
  incr AS_TBBODY [llength [as_bodies $d]]
  puts "AS-BENCH [file tail $ubd]: lost [llength [as_lost]] bodies [llength [as_bodies $d]]"
}
check {AS27 THE NOISE BUDGET AND THE BODY COUNT, both counted rather than\
 hoped for: netlisting every shipped bench in the analog simulation library\
 still produces not one "that setting did not reach the simulator" line, and\
 the decks hold exactly the cell bodies they hold today -- the tool did not\
 quietly start inventing cells on somebody else's design} \
  [list [expr {$AS_TB >= 4 ? 1 : 0}] $AS_TBLOST $AS_TBBODY] \
  {1 0 21}

# ============================================================================
# AS34-AS39. SIX GUARDS NOTHING COULD SEE, EACH NOW DRIVEN
# ============================================================================
# A sabotage pass switched off one load-bearing line at a time, rebuilt, and
# re-ran everything. Nine lines could be deleted with every suite still green.
# Six of them can be reached by a deck or a sentence, and those six are here;
# the rest are structural and sit with AS40-AS43 below. None of these rows
# describes the code -- each drives the defect the missing line lets through.

## AS34 AND AS35. ONE SHEET, TWO COPIES, TWO SENTENCES.
set U_D [as_netlist [file join $AS asua.sch]]
set U_N1 [as_for [as_notes] xH1]
set U_L1 [as_for [as_lost] xH1]
set U_L2 [as_for [as_lost] xH2]
puts "AS-UA xH1 -> [as_bodyfor $U_D xH1]  xH2 -> [as_bodyfor $U_D xH2]"
puts "AS-UA notes for xH1: $U_N1"
puts "AS-UA lost for xH1: $U_L1"
puts "AS-UA lost for xH2: $U_L2"

check {AS34 THE TOOL MAY NOT ACCUSE A COPY IT HAS JUST REPAIRED. xH1 types a\
 setting the cell's own drawing uses, so the netlister gives that copy its own\
 version of the cell -- and having done it, in the same run one step earlier,\
 it may not also tell the designer that setting went nowhere. Exactly one\
 sentence about xH1, and it is the one that is true} \
  [list [llength $U_N1] [llength $U_L1]] {1 0}

check {AS35 AND THE SENTENCE THAT DOES GET PRINTED NAMES THE RIGHT CELL. xH2\
 types one setting the tool can honour and one nothing can use, so it gets both\
 a new cell AND a complaint -- and working out the new cell name walks every\
 symbol in the design, which is what used to leave some other cell's name in\
 the complaint. Measured before the fix: a passgate described as "a\
 130_fd_pr/pfet_01v8"} \
  [list [llength $U_L2] \
        [expr {[llength $U_L2] == 1 ?
               [expr {[string first {instance xH2 (a aspass) sets zzspare=7} \
                       [lindex $U_L2 0]] >= 0 ? 1 : 0}] : 0}]] \
  {1 1}

## AS36. THE ANSWER GOES STALE THE MOMENT SOMEBODY SAVES THE DRAWING.
## Netlist, then edit the cell's own drawing so it stops using the setting,
## then netlist again -- all in one session, which is what a designer does all
## day. The second deck must be built from the file as it now reads.
set E_D1 [as_netlist [file join $AS asedtop.sch]]
set E_B1 [as_bodyfor $E_D1 xE1]
as_wr $AS_EDIT_SCH $AS_EDIT_DROPS
set E_D2 [as_netlist [file join $AS asedtop.sch]]
set E_B2 [as_bodyfor $E_D2 xE1]
as_wr $AS_EDIT_SCH $AS_EDIT_USES
puts "AS-EDIT before edit xE1 -> $E_B1 ; after edit xE1 -> $E_B2"

check {AS36 WHAT THE NETLISTER REMEMBERS ABOUT A DRAWING IS ONLY TRUE UNTIL\
 SOMEBODY SAVES THAT DRAWING. The designer netlists, opens the cell, takes the\
 setting out of it, saves, and netlists again -- in one session. The first deck\
 gives the copy its own version of the cell; the second must not, because the\
 drawing it was reading no longer says that. An answer kept past the end of a\
 run is an answer about a file that has changed underneath it} \
  [list [expr {$E_B1 ne {NOCALL} && $E_B1 ne {asedit} ? 1 : 0}] $E_B2] \
  {1 asedit}

## AS37. TWO SETTINGS THAT SPELL THE SAME ONCE PUNCTUATION IS FOLDED.
set C_D [as_netlist [file join $AS ascoll.sch]]
set C_B1 [as_bodyfor $C_D xT1]
set C_B2 [as_bodyfor $C_D xT2]
puts "AS-FOLD xT1 -> $C_B1 ; xT2 -> $C_B2 ; bodies [as_bodies $C_D]"

check {AS37 TWO COPIES ASKING FOR TWO DIFFERENT DEVICES MUST NEVER END UP\
 SHARING ONE NAME. pfet_01v8_lvt and pfet_01v8-lvt are different devices whose\
 invented names spell the same once the punctuation is folded to an\
 underscore. Each copy gets a name of its own, each name defines exactly one\
 cell body in the deck, and each body holds the device that copy asked for.\
 Handing one name to both writes two different cell bodies under it, which is a\
 deck no simulator can read} \
  [list [expr {$C_B1 ne {NOCALL} && $C_B1 ne {ascp} ? 1 : 0}] \
        [expr {$C_B2 ne {NOCALL} && $C_B2 ne {ascp} ? 1 : 0}] \
        [expr {$C_B1 ne $C_B2 ? 1 : 0}] \
        [as_count $C_D ".subckt $C_B1 "] \
        [as_count $C_D ".subckt $C_B2 "] \
        [as_pmodel $C_D $C_B1] [as_pmodel $C_D $C_B2]] \
  {1 1 1 1 1 sky130_fd_pr__pfet_01v8_lvt sky130_fd_pr__pfet_01v8-lvt}

## AS38. THE NAME THE TOOL INVENTS, ON A CELL AND A VALUE THAT ARE NOT ALREADY
## LEGAL. AS12 asks the same question of a cell called `aspass` set to
## `pfet_01v8_lvt`, which a simulator would accept before any of the code that
## makes it acceptable has run.
set P_D [as_netlist [file join $AS aspunct.sch]]
set P_B [as_bodyfor $P_D xP]
puts "AS-NAME xP -> $P_B"

check {AS38 A CELL WHOSE OWN NAME A SIMULATOR WOULD REFUSE -- it starts with a\
 digit and it holds a dash -- asking for a device value that also holds a dash.\
 The name the tool invents for it still starts with a letter and still holds\
 nothing but letters, digits and underscores, and it is still readable: a\
 designer looking at it can see which cell it came from and which setting made\
 it} \
  [list [expr {$P_B ne {NOCALL} ? 1 : 0}] \
        [expr {[regexp {^[A-Za-z][A-Za-z0-9_]*$} $P_B] ? 1 : 0}] \
        $P_B \
        [expr {[lsearch -exact [as_bodies $P_D] $P_B] >= 0 ? 1 : 0}]] \
  {1 1 x9as_p__modelp_pfet_01v8_lvt 1}

## AS39. A SYMBOL THAT SAYS DO NOT WRITE MY INSIDES OUT, WITH A DRAWING BESIDE
## IT THAT DOES USE THE SETTING.
set F_D [as_netlist [file join $AS asdefs.sch]]
set F_B [as_bodyfor $F_D xJ]
puts "AS-IGN xJ -> $F_B ; bodies [as_bodies $F_D]"

check {AS39 A SYMBOL WHOSE AUTHOR SAID DO NOT WRITE MY INSIDES OUT KEEPS SAYING\
 IT, even when a drawing that does use the setting is sitting right beside it.\
 The copy is still built from the plain cell, no cell body of it appears in the\
 deck, and the device the copy asked for is nowhere in the deck either --\
 because writing that copy out at all would overrule the symbol author} \
  [list $F_B [as_count $F_D {.subckt asig2}] \
        [as_count $F_D {sky130_fd_pr__pfet_01v8_lvt}]] \
  {asig2 0 0}

# ============================================================================
# AS28-AS31. STRUCTURAL. Invisible to every behavioural row above.
# ============================================================================
set AS_ACTC [as_nocomment_c [as_slurp [file join $repo src actions.c]]]
set AS_SPIC [as_nocomment_c [as_slurp [file join $repo src spice_netlist.c]]]

check {AS28 ONE CLASSIFICATION, NOT TWO. The rule that decides whether a\
 setting a designer typed goes nowhere is written once and asked twice -- by\
 the warning and by the new automatic copy. Two copies of it would agree on\
 the day they were written and drift silently afterwards, and nothing a user\
 does could show it. Issues 1212 and 1215 added a THIRD asker, the one that\
 compares two copies' requests, and it needs the one test that decides "this\
 copy named its own cell body" turned off. That is a flag on the same function,\
 not a second function: the body is written once as ua_instance_eligible_ex and\
 the name every older caller uses is a one-line wrapper over it} \
  [list [as_count $AS_TOKC {static int ua_token_lost(}] \
        [as_count $AS_TOKC {static int ua_instance_eligible(}] \
        [as_count $AS_TOKC {static int ua_instance_eligible_ex(}] \
        [expr {[as_count $AS_TOKC {ua_token_lost(}] >= 3 ? 1 : 0}] \
        [expr {[as_count $AS_TOKC {ua_instance_eligible}] >= 3 ? 1 : 0}]] \
  {1 1 1 1 1}

check {AS29 THE SPICE LINE IS RESOLVED IN ONE PLACE TOO, and both the warning\
 and the automatic copy ask about the same one -- otherwise the two can decide\
 against different SPICE lines for the same copy and disagree about whether\
 the setting was lost} \
  [list [as_count $AS_TOKC {static int resolve_netlist_format(}] \
        [expr {[as_count $AS_TOKC {resolve_netlist_format(}] >= 3 ? 1 : 0}]] \
  {1 1}

check {AS30 THE AUTOMATIC COPY IS SWITCHED ON FOR THE LENGTH OF ONE SPICE\
 NETLIST RUN AND SWITCHED OFF AGAIN. Left on, the answers it remembered about\
 one design would be handed to the next one -- which no behavioural row inside\
 a single run can ever see, and which is exactly the class of defect this\
 branch has shipped past a green suite before} \
  [list [as_count $AS_SPIC {auto_spec_begin(}] \
        [as_count $AS_SPIC {auto_spec_end(}] \
        [as_count $AS_ACTC {void auto_spec_begin(}] \
        [as_count $AS_ACTC {void auto_spec_end(}]] \
  {1 1 1 1}

set AS_OTHER 0
foreach f {spectre_netlist.c vhdl_netlist.c verilog_netlist.c tedax_netlist.c} {
  incr AS_OTHER [as_count [as_nocomment_c [as_slurp [file join $repo src $f]]] {auto_spec_begin(}]
}
check {AS31 AND IT IS SWITCHED ON NOWHERE ELSE: none of the other four netlist\
 formats turn it on, so a Spectre, VHDL, Verilog or tEDAx netlist keeps exactly\
 today's behaviour} \
  $AS_OTHER 0

# ============================================================================
# AS40-AS43. THE REST OF WHAT THE SABOTAGE PASS FOUND BLIND
# ============================================================================
# Four more lines could be deleted with every suite still green. Unlike the six
# above, no deck and no sentence can reach these: each is either covered a
# second time by a sibling that hides it, or it only shows itself on a machine
# with a screen. So they are asked of ONE function body at a time -- grepping
# the whole file would find the sibling and pass while the line was gone.

check {AS40 EXPLICIT BEATS IMPLICIT IS WRITTEN IN TWO PLACES AND EACH ONE HIDES\
 THE OTHER. A designer who named a copy's cell by hand must keep exactly\
 today's deck, and that is enforced both by the classification refusing such a\
 copy and, separately, by the two places that pick a cell name asking the hand\
 typed one FIRST. Either one alone makes the shipped bandgap deck come out\
 byte-identical, so deleting either alone is invisible -- and the first of them\
 reads exactly like dead code. Both are counted here, and so is the rule that\
 the two places which name a cell body both ask the same one function} \
  [list [expr {[as_cfunc $AS_TOKC {static int ua_instance_eligible_ex(int inst, int allow_explicit)}] eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count [as_cfunc $AS_TOKC {static int ua_instance_eligible_ex(int inst, int allow_explicit)}] {"schematic"}] \
        [as_count [as_cfunc $AS_TOKC {static int ua_instance_eligible_ex(int inst, int allow_explicit)}] {"spice_sym_def"}] \
        [as_count [as_cfunc $AS_TOKC {static int ua_instance_eligible_ex(int inst, int allow_explicit)}] {"spectre_sym_def"}] \
        [as_count [as_cfunc $AS_TOKC {static int ua_instance_eligible_ex(int inst, int allow_explicit)}] {"vhdl_sym_def"}] \
        [as_count [as_cfunc $AS_TOKC {static int ua_instance_eligible_ex(int inst, int allow_explicit)}] {"verilog_sym_def"}] \
        [as_count [as_cfunc $AS_TOKC {static int ua_instance_eligible_ex(int inst, int allow_explicit)}] {"tedax_sym_def"}] \
        [as_count $AS_ACTC {if(!schematic_token_found)}] \
        [as_count $AS_ACTC {auto_spec_name(}]] \
  {1 1 1 1 1 1 1 2 3}

set AS_COLL [as_cfunc $AS_ACTC {static int auto_spec_collides(int inst, const char *nm, const char *mykey)}]
check {AS41 A NAME THE TOOL INVENTS IS CHECKED AGAINST FIVE PLACES A NAME CAN\
 ALREADY BE SPOKEN FOR -- THE FIFTH IS ISSUE 1202, a name a designer has typed\
 by hand on ANOTHER copy on the same sheet, which none of the other four can\
 see because the top sheet's call lines are written before the hand-named cell\
 is ever loaded as a symbol. Row AS51 drives that one. and only one of the four can be reached from a deck --\
 the other three are covered by each other, so deleting any one of them alone\
 leaves every suite green. The one that matters most is the list of names this\
 same run has already handed out: without it two copies whose settings spell\
 the same once folded both get one name, and the deck holds two different cell\
 bodies under it. Row AS37 drives that one; this row is what keeps the other\
 three from quietly going away} \
  [list [expr {$AS_COLL eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_COLL {str_hash_lookup(&auto_spec_taken}] \
        [as_count $AS_COLL {get_cell(xctx->sym[i].name, 0)}] \
        [as_count $AS_COLL {abs_sym_path(nm, ".sym")}] \
        [as_count $AS_COLL {abs_sym_path(nm, ".sch")}] \
        [as_count $AS_COLL {abs_sym_path(dirref, ".sym")}] \
        [as_count $AS_COLL {abs_sym_path(dirref, ".sch")}] \
        [as_count $AS_COLL {xctx->instances}] \
        [as_count $AS_COLL {"schematic"}]] \
  {1 1 1 1 1 1 1 1 1}

set AS_CBRT [as_cfunc $AS_TOKC {static int cell_body_reads_token(int inst, const char *tok)}]
check {AS42 ASKING WHETHER THE CELL'S DRAWING USES A SETTING MUST NOT COST THE\
 USER THEIR NEXT DESCEND, AND MUST NOT STOP A NETLIST TO ASK A QUESTION IN A\
 DIALOG BOX. The question is asked about the SYMBOL and with the fallback\
 switched off: asked about the instance it would swallow the one-shot "descend\
 into this named view just this once" choice the user had already made, and\
 with the fallback on, a netlist run on a machine with a screen would stop and\
 put a box up. Neither can be seen from a headless deck, and passing the\
 instance instead leaves every suite green} \
  [list [expr {$AS_CBRT eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_CBRT {get_sch_from_sym(fn, xctx->inst[inst].ptr + xctx->sym, -1, 0)}] \
        [as_count $AS_CBRT {get_sch_from_sym(}]] \
  {1 1 1}

set AS_WSPEC [as_cfunc $AS_ACTC {int auto_spec_would_specialize(int inst)}]
set AS_AEND [as_cfunc $AS_ACTC {void auto_spec_end(void)}]
check {AS43 AND THE SAME QUESTION ASKED FROM THE ANNOTATION SURFACE, WHICH NO\
 NETLIST RUN OWNS, HAS TO DROP WHAT IT READ ON THE WAY OUT. Inside a netlist\
 run the end of the run throws it away; outside one nothing else ever would,\
 and the drawing may be saved a moment later. Row AS36 drives the netlist-run\
 half; this half is only reachable by annotating, editing the cell and\
 annotating again, which no headless deck can stage. The tables and the\
 body-read note the run itself keeps are counted too, because AS30 counts only\
 that the two functions exist and never asks whether either frees anything.\
 There are FOUR of them since issue 1212: the fourth holds the cell names typed\
 on the design's OTHER sheets, read off those files, and it is exactly as\
 perishable as the other three} \
  [list [expr {$AS_WSPEC eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_WSPEC {if(!auto_spec_on) lost_attrs_cache_clear();}] \
        [expr {$AS_AEND eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_AEND {str_hash_free(}] \
        [as_count $AS_AEND {lost_attrs_cache_clear();}] \
        [as_count $AS_AEND {auto_spec_on = 0;}]] \
  {1 1 1 4 1 1}

# ============================================================================
# AS57/AS58. TWO GUARDS THIS ITEM ADDED THAT NO ROW COULD SEE
# ============================================================================
# Both were found by the sabotage pass, not by a reader: each was BUILT, the
# binary rebuilt, and the whole tier re-run, and every suite stayed green while
# the line that protects the user was gone. Issues 1210 and 1211.
#
# Neither can be reached from a deck, and grepping the whole file cannot see
# either, because the call each one is about appears in a sibling that masks it.
# So the question is asked of ONE function body, the way AS41, AS42 and AS43
# already ask theirs.

## The text strictly BETWEEN two anchors in one function body. Used to ask the
## question a plain count cannot: is there a way OUT of the latched region that
## does not put the flag back. The sentinel carries the word it is counted for,
## so a missing anchor reds the row instead of silently answering zero.
proc as_between {body a b} {
  set i [string first $a $body]
  if {$i < 0} { return {ZZNOANCHOR return} }
  incr i [string length $a]
  set j [string first $b $body $i]
  if {$j < 0} { return {ZZNOANCHOR return} }
  return [string range $body $i [expr {$j - 1}]]
}

set AS_ABEG [as_cfunc $AS_ACTC {void auto_spec_begin(int whole)}]
puts "AS-TWOFLAG begin body: on=[as_count $AS_ABEG {auto_spec_on}]\
 on1=[as_count $AS_ABEG {auto_spec_on = 1;}]\
 whole=[as_count $AS_ABEG {auto_spec_whole = whole ? 1 : 0;}]"
check {AS57 STRUCTURAL, ISSUE 1210. THE FLAG THAT SAYS "A NETLIST RUN OWNS\
 THESE TABLES" IS SET ON BOTH ARMS, AND ONLY THE SECOND FLAG CARRIES THE MODE.\
 A reader arrives at two flags and simplifies them to one -- just do not open\
 the window when only the sheet on screen is being written out. That costs the\
 user real time and nothing anywhere would say so: auto_spec_would_specialize\
 drops the body-read note whenever no run owns it, which AS43 pins, so with the\
 window shut on the single-sheet arm every question the warning asks re-reads\
 the cell's drawing off the disk, once per token. Measured in the sabotage\
 pass: 295 opens of the fixture cell drawings against 286, one fixture going\
 from 102 to 111. And the warning HAS to ask on that arm -- it is the arm where\
 the setting really did go nowhere. So the flag is set to 1 unconditionally and\
 mentioned nowhere else in this function; writing it as a conditional, in\
 either spelling, reds this row. Whether the MODE flag is told the truth by its\
 caller is a different question and rows AS44 AS45 AS46 already measure it from\
 a deck} \
  [list [expr {$AS_ABEG eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_ABEG {auto_spec_on = 1;}] \
        [as_count $AS_ABEG {auto_spec_on}] \
        [as_count $AS_ABEG {auto_spec_whole = whole ? 1 : 0;}]] \
  {1 1 1 1}

set AS_QUAL [as_cfunc $AS_ACTC \
  {static int auto_spec_qualifies(int inst, char **canon, char **settings, char **key)}]
puts "AS-TOKSIZE collides: latch=[as_count $AS_COLL {saved_tok_size = xctx->tok_size}]\
 restore=[as_count $AS_COLL {xctx->tok_size = saved_tok_size}]\
 escapes=[as_count [as_between $AS_COLL {saved_tok_size = xctx->tok_size} {xctx->tok_size = saved_tok_size}] {return}]"
puts "AS-TOKSIZE qualifies: latch=[as_count $AS_QUAL {saved_tok_size = xctx->tok_size}]\
 restore=[as_count $AS_QUAL {xctx->tok_size = saved_tok_size}]\
 escapes=[as_count [as_between $AS_QUAL {saved_tok_size = xctx->tok_size} {xctx->tok_size = saved_tok_size}] {return}]"
check {AS58 STRUCTURAL, ISSUE 1211. NEITHER OF THE TWO NEW QUESTIONS MAY BECOME\
 THE REASON A REAL NETLIST VALUE GOES MISSING. Both of them ask the property\
 reader things of their own -- does any copy on this sheet already name this\
 cell body, does this symbol name its own drawing -- and the property reader\
 leaves the length of what it found in one place every caller shares. Whoever\
 called us was in the middle of reading a token of their own, so each function\
 latches that length before its first lookup and puts it back before it hands\
 an answer out. Deleting either restore leaves every suite in the tree green,\
 measured. The sibling guard this pair cites in token.c IS pinned, by row UB9\
 of test_unused_attr_0970; these two copies got the citation and not the row.\
 THE THIRD ELEMENT OF EACH PAIR IS THE LESSON OF ISSUE 0986 GAP 4: counting\
 restores alone still passes when a new way out is added between the latch and\
 the restore, so the region between them is required to contain no return at\
 all} \
  [list [expr {$AS_COLL eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_COLL {saved_tok_size = xctx->tok_size}] \
        [as_count $AS_COLL {xctx->tok_size = saved_tok_size}] \
        [as_count [as_between $AS_COLL {saved_tok_size = xctx->tok_size} \
                                       {xctx->tok_size = saved_tok_size}] {return}] \
        [expr {$AS_QUAL eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_QUAL {saved_tok_size = xctx->tok_size}] \
        [as_count $AS_QUAL {xctx->tok_size = saved_tok_size}] \
        [as_count [as_between $AS_QUAL {saved_tok_size = xctx->tok_size} \
                                       {xctx->tok_size = saved_tok_size}] {return}]] \
  {1 1 1 0 1 1 1 0}

# ============================================================================
# AS33. THE THIRD SURFACE, AND NOBODY NAMED THIS ONE EITHER
# ============================================================================
# The annotation surface has to ask the results file for a device BY THE NAME
# THE SIMULATOR GAVE IT. op_annot::model_netlist works that name out, and its
# GUARD GB used to test for one thing: does this copy carry a schematic=
# attribute? That was the only way a copy's own setting could reach the deck.
# It is not any more -- a copy with no attribute on it at all now gets its own
# version of the cell -- so a surface still testing for the attribute would ask
# for a device under a name the deck never contained, and the user's schematic
# would get no numbers, or numbers measured for a different transistor. RULING
# D5-1.
#
# THE ANSWER MUST BE THE NETLISTER'S OWN, NOT A SECOND OPINION ASSEMBLED IN Tcl,
# for the same reason AS28 gives about the classification. So: one C function,
# asked by descend_schematic at the one moment the parent copy and its symbol
# both still exist, published on the hierarchy level, and read back by name.
# Row NM9 of tests/headless/test_op_annot.tcl is the behavioural witness -- it
# measures the device name the annotation builds against the deck the netlister
# really wrote. This row is the structural half of it, which no behavioural row
# can see: a second implementation in Tcl would agree today and drift later.
set AS_SCHC [as_nocomment_c [as_slurp [file join $repo src scheduler.c]]]
set AS_OPA [as_nocomment_tcl [as_slurp [file join $repo src op_annot.tcl]]]
check {AS33 THE ANNOTATION SURFACE ASKS THE NETLISTER, IT DOES NOT GUESS: the question "did this copy get its own version of the cell" is answered in ONE place in C, asked while descending -- the only moment the copy and its symbol both still exist -- published on the hierarchy level, and read back by the annotation surface, which holds no second copy of the rule}   [list [as_count $AS_ACTC {int auto_spec_would_specialize(}]         [expr {[as_count $AS_ACTC {auto_spec_would_specialize(}] >= 2 ? 1 : 0}]         [as_count $AS_SCHC {lcc[%d].auto_spec=%d}]         [as_count $AS_OPA {_lcc_attr auto_spec}]]   {1 1 1 1}

# ============================================================================
# AS32. SOMETHING HAS TO RUN THIS
# ============================================================================
set AS_REG [as_slurp [file join $repo tests run_regression.tcl]]
set AS_AUD [as_slurp [file join $repo tests headless full_audit.sh]]
check {AS32 STRUCTURAL this suite is named once in the full regression list and\
 once in the audit list, so it is run by something other than a person\
 remembering to type it. THE NAME IS MATCHED AS A WHOLE NAME: a plain substring\
 count still finds it inside a longer one, so renaming the entry to\
 test_auto_specialize_1201_UNREG unregisters the suite and leaves this row\
 green} \
  [list [as_wordcount $AS_REG {headless/test_auto_specialize_1201}] \
        [as_wordcount $AS_AUD {test_auto_specialize_1201}]] \
  {1 1}

# ============================================================================
# AS44-AS56. THE SIX DEFECTS S6's OWN VERIFY PASS FILED INSIDE THE NEW
# BEHAVIOUR AND SHIPPED ANYWAY -- issues 1202, 1203, 1204, 1205, 1206, 1208.
# ============================================================================
# THE FIXTURES BELOW ARE WRITTEN HERE, NOT WITH THE REST, on purpose: every row
# above this line was measured against a fixture library that did not contain
# them, and one of those rows plants a real file under a name the tool invents
# and leaves it on disk for the rest of the run. New cells, new sheets, nothing
# above is disturbed.

## asnh -- a cell whose own drawing uses both settings its template supplies,
## and which is written into no netlist but the SPICE one. THE FOUR IGNORES ARE
## LOAD-BEARING AND WERE ADDED AFTER MEASUREMENT. A setting the SPICE line drops
## but a VHDL or Verilog netlist of the same cell carries produces the OTHER
## warning shape -- "you should not remove it" -- which issue 1205 does not
## touch. aspass is of that shape, so a row about the new sentence written on
## aspass would be measuring a sentence nobody changed. With the four ignores
## nothing anywhere reads the setting, which is the population the false
## sentence is printed to.
as_wr [file join $AS asnh.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
spectre_ignore=true
vhdl_ignore=true
verilog_ignore=true
tedax_ignore=true
template="name=x1 W_P=1
modeln=nfet_01v8 modelp=pfet_01v8"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS asnh.sch] {v {xschem version=3.4.4 file_version=1.2}
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
}
C {sky130_fd_pr/nfet_01v8} 600 -300 0 0 {name=M3
L=0.15
W=W_P
nf=1
mult=1
model=@modeln
spiceprefix=X
}}

## The single-sheet fixture: one copy that sets nothing, one that types a
## setting the drawing uses, and one that also names its own cell by hand.
as_wr [file join $AS asnhtop.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/asnh.sym} 120 0 0 0 {name=xN1 W_P=0.5}
C {as/asnh.sym} 320 0 0 0 {name=xN2 W_P=0.6 modelp=pfet_01v8_lvt}
C {as/asnh.sym} 520 0 0 0 {name=xN9 W_P=0.5 modelp=pfet_01v8_lvt schematic=asnh_lvtp}}

## ISSUE 1205's population: a cell whose TEMPLATE names its own cell body, so
## the netlister may not give it a version of its own -- while the cell's own
## drawing does read the setting the copy typed.
as_wr [file join $AS aslook.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @model W_P=@W_P"
spectre_ignore=true
vhdl_ignore=true
verilog_ignore=true
tedax_ignore=true
template="name=x1 W_P=1
model=aslookcell
modelp=pfet_01v8"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS aslook.sch] {v {xschem version=3.4.4 file_version=1.2}
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

as_wr [file join $AS aslk.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/aslook.sym} 120 0 0 0 {name=xL W_P=0.5 modelp=pfet_01v8_lvt}
C {devices/iopin} 520 0 0 1 {name=p1 lab=AA}}

## ISSUE 1202. as51 is aspass again under a name of its own, because row AS11
## planted a real file under an aspass-derived name and left it there.
as_wr [file join $AS as51.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS as51.sch] {v {xschem version=3.4.4 file_version=1.2}
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

as_wr [file join $AS as51one.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/as51.sym} 120 0 0 0 {name=xP W_P=0.5 modelp=pfet_01v8_lvt}}

## ISSUE 1203. asp2 supplies two settings. xD types ONE of them with a value
## that itself holds the pair separator; xE types BOTH. Joined the way the cell
## name is spelled, the two spell one string.
as_wr [file join $AS asp2.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modeln=nfet_01v8 modelp=pfet_01v8"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS asp2.sch] {v {xschem version=3.4.4 file_version=1.2}
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
}
C {sky130_fd_pr/nfet_01v8} 600 -300 0 0 {name=M3
L=0.15
W=W_P
nf=1
mult=1
model=@modeln
spiceprefix=X
}}

as_wr [file join $AS askey.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/asp2.sym} 120 0 0 0 {name=xD W_P=0.5 modeln=nfetA__modelp_pfetB}
C {as/asp2.sym} 320 0 0 0 {name=xE W_P=0.5 modeln=nfetA modelp=pfetB}}

## ISSUE 1206. A setting typed with nothing after the equals sign, alone on one
## copy and beside a real setting on another.
as_wr [file join $AS asblank.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/asnh.sym} 120 0 0 0 {name=xN W_P=0.5 modelp=}
C {devices/iopin} 520 0 0 1 {name=p1 lab=AA}}

as_wr [file join $AS asmix.sch] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {as/asnh.sym} 120 0 0 0 {name=xR W_P=0.5 modeln=nfet_01v8_lvt modelp=}
C {devices/iopin} 520 0 0 1 {name=p1 lab=AA}}

# ----------------------------------------------------------------------------
# AS44-AS48. ISSUE 1204: "NETLIST CURRENT SCHEMATIC ONLY" CALLS A CELL BODY IT
# NEVER WRITES. A REGRESSION -- before this feature the same tick box wrote a
# deck whose call line named a real cell the designer's other netlist files
# define. It now names a cell that is defined in that file, in no other netlist
# file, and in no library on disk, and the simulator refuses the deck.
# ----------------------------------------------------------------------------
set NH_D [as_netlist_nh [file join $AS astop.sch]]
set NH_NOTES [as_notes]
puts "AS-NOHIER astop single-sheet: x1 -> [as_bodyfor $NH_D x1] x2 ->\
 [as_bodyfor $NH_D x2] x9 -> [as_bodyfor $NH_D x9]"
puts "AS-NOHIER bodies defined in that file: [as_bodies $NH_D]"
puts "AS-NOHIER notes: [llength $NH_NOTES]"
foreach nl $NH_NOTES { puts "AS-NOHIER NOTE: $nl" }

check {AS44 THE REGRESSION, issue 1204. The designer asks for a netlist of just\
 the sheet on screen -- Shift-N -- and gets ONE file holding this sheet and\
 nothing below it. A\
 call line in it may only name a cell that file defines, or one the designer's\
 other netlist files define -- so it must name the plain cell, exactly as it\
 did before this feature. Measured before the fix: that file defined NO cell\
 bodies at all and five of its call lines named invented cells, one of them for\
 the copy read here, and no netlist file and no library on disk defines any of\
 them. The copy that named its own cell by hand is untouched on this arm,\
 because that name IS in the designer's own library} \
  [list [as_bodyfor $NH_D x1] [as_bodyfor $NH_D x2] [as_bodyfor $NH_D x9] \
        [as_count $NH_D {aspass__}]] \
  {aspass aspass aspass_lvtp 0}

check {AS45 AND THE TOOL MAY NOT SAY IT WROTE SOMETHING IT DID NOT WRITE,\
 RULING D5-1. On the single-sheet run the info window carried the whole note --\
 XSCHEM wrote a separate copy, any other copy asking for the same settings\
 shares it, you do not have to add anything to the sheet -- about a cell body\
 that is in no file. Not one such sentence may appear on this arm} \
  [llength $NH_NOTES] 0

set NH_D2 [as_netlist_nh [file join $AS asnhtop.sch]]
set NH_L2 [as_for [as_lost] xN2]
puts "AS-NOHIER asnhtop: xN2 -> [as_bodyfor $NH_D2 xN2] ; lost for xN2:\
 [llength $NH_L2]"
foreach nl $NH_L2 { puts "AS-NOHIER SAYS: $nl" }

check {AS46 AND WHAT THE DESIGNER IS TOLD INSTEAD, issues 1204 and 1205. The\
 setting really did go nowhere on this arm, so the tool has to say so -- once,\
 for that copy, and in words that are true. It may NOT say the cell's drawing\
 does not use the setting, because it does; it must say this is not a spelling\
 mistake, and it must tell the designer the one thing that would fix it, which\
 is to netlist the whole design} \
  [list [llength $NH_L2] \
        [expr {[llength $NH_L2] == 1 ?
               [expr {[string first {does not use} [lindex $NH_L2 0]] >= 0 ? 1 : 0}] : -1}] \
        [expr {[llength $NH_L2] == 1 ?
               [expr {[string first {spelling mistake} [lindex $NH_L2 0]] >= 0 ? 1 : 0}] : -1}] \
        [expr {[llength $NH_L2] == 1 ?
               [expr {[string first {whole design} [lindex $NH_L2 0]] >= 0 ? 1 : 0}] : -1}]] \
  {1 0 1 1}

set NH_H [as_netlist [file join $AS astop.sch]]
puts "AS-NOHIER control, whole design: x2 -> [as_bodyfor $NH_H x2]"
check {AS47 CONTROL, GREEN BEFORE AND AFTER. Netlisting the WHOLE design still\
 gives that copy its own version of the cell with the device the designer asked\
 for. This is the row that stops a repair which simply switches the feature off} \
  [list [expr {[as_bodyfor $NH_H x2] ne {aspass} &&
               [as_bodyfor $NH_H x2] ne {NOCALL} ? 1 : 0}] \
        [as_pmodel $NH_H [as_bodyfor $NH_H x2]]] \
  {1 sky130_fd_pr__pfet_01v8_lvt}

set NH_OTHER {}
foreach nhp {{spectre spectre} {vhdl vhdl} {verilog v} {tedax tdx}} {
  set nht [lindex $nhp 0]
  set nhe [lindex $nhp 1]
  set nhd [as_netlist_nh [file join $AS astop.sch] $nht $nhe]
  lappend NH_OTHER [expr {$nhd eq {ZZNOFILE} ? {NOFILE} : [as_count $nhd {aspass__}]}]
}
catch {xschem set netlist_type spice}
puts "AS-NOHIER other formats, invented-name count: $NH_OTHER"
check {AS48 FENCE, GREEN BEFORE AND AFTER, issue 1204. The same sheet written\
 single-sheet as a Spectre, VHDL, Verilog or tEDAx netlist names the plain cell\
 in all four -- measured, not assumed. Only the SPICE deck was ever broken, and\
 this row is what keeps a later hand from wiring this behaviour into a second\
 backend and breaking it there too} \
  $NH_OTHER {0 0 0 0}

# ----------------------------------------------------------------------------
# AS49-AS50. ISSUE 1205: A SENTENCE THAT ASSERTS A FACT IT NEVER ESTABLISHED.
# ----------------------------------------------------------------------------
set LK_D [as_netlist [file join $AS aslk.sch]]
set LK_L [as_for [as_lost] xL]
puts "AS-LOOK xL -> [as_bodyfor $LK_D xL] ; lost [llength $LK_L]"
foreach ll $LK_L { puts "AS-LOOK SAYS: $ll" }

check {AS49 THE TOOL MUST LOOK BEFORE IT SAYS WHAT IT SAW, issue 1205. This\
 cell may not be given a version of its own -- its template names its own cell\
 body, so two versions would land in the deck under one name -- and the tool\
 rightly tells the designer their setting went nowhere. But the sentence goes\
 on to tell them the cell's drawing does not use the setting anywhere, without\
 having opened the drawing: the very next line of aslook.sch reads model=@modelp} \
  [list [llength $LK_L] \
        [expr {[llength $LK_L] == 1 ?
               [expr {[string first {does not use} [lindex $LK_L 0]] >= 0 ? 1 : 0}] : -1}] \
        [expr {[llength $LK_L] == 1 ?
               [expr {[string first {drawing does use} [lindex $LK_L 0]] >= 0 ? 1 : 0}] : -1}]] \
  {1 0 1}

set AS_WARN [as_cfunc $AS_TOKC {static void warn_unused_instance_attr(int inst, const char *format)}]
puts "AS-WARN body found: [expr {$AS_WARN eq {NOFUNC} ? {no} : {yes}}]"
check {AS50 STRUCTURAL, AND IT IS ASKED OF ONE FUNCTION BODY. The short-circuit\
 that causes issue 1205 is a single && in the skip test: the second half is the\
 question "does the cell's drawing use this setting", and C never evaluates it\
 once the first half is false. The same call appears two hundred lines up in\
 the sibling that classifies, so grepping the file finds it and passes while\
 the sentence below is still guessing. The answer has to be worked out once and\
 held, and the clause that claims the drawing does not use the setting stays\
 exactly one sentence in the file} \
  [list [expr {$AS_WARN eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_WARN {auto_spec_name(inst) && cell_body_reads_token(}] \
        [expr {[as_count $AS_WARN {body_reads}] >= 3 ? 1 : 0}] \
        [as_count $AS_WARN {does not use}]] \
  {1 0 1 1}

# ----------------------------------------------------------------------------
# AS51. ISSUE 1202: A COPY THAT HAND-TYPES THE NAME THE TOOL WOULD INVENT
# SILENTLY LOSES ITS OWN SETTING.
# ----------------------------------------------------------------------------
# Built in two steps, like row AS11's decoy, so the row cannot be satisfied by a
# naming scheme nobody collides with: the first run LEARNS the name this build
# invents, and the second sheet hand-types exactly that name on a copy asking
# for a different device.
set K_D1 [as_netlist [file join $AS as51one.sch]]
set K_NAME [as_bodyfor $K_D1 xP]
set K_OK [expr {$K_NAME ne {NOCALL} && $K_NAME ne {as51} ? 1 : 0}]
if {$K_OK} {
  as_wr [file join $AS as51two.sch] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
C \{as/as51.sym\} 120 0 0 0 \{name=xP W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/as51.sym\} 320 0 0 0 \{name=xQ W_P=0.5 modelp=pfet_01v8_hvt schematic=$K_NAME\}"
}
set K_D2 [expr {$K_OK ? [as_netlist [file join $AS as51two.sch]] : {}}]
set K_BP [expr {$K_OK ? [as_bodyfor $K_D2 xP] : {NOSTEP1}}]
set K_BQ [expr {$K_OK ? [as_bodyfor $K_D2 xQ] : {NOSTEP1}}]
puts "AS-TYPED learned name $K_NAME ; xP -> $K_BP ; xQ -> $K_BQ ; bodies\
 [expr {$K_OK ? [as_bodies $K_D2] : {}}]"

check {AS51 A NAME A DESIGNER TYPED BY HAND ON ANOTHER COPY IS ALREADY SPOKEN\
 FOR, issue 1202. One copy types nothing and the tool invents a name for it;\
 the copy beside it hand-types that very name and asks for a DIFFERENT device.\
 Measured before the fix: both copies called one cell, the only body in the\
 deck was built from the first copy's device, and the designer who typed the\
 name was told nothing at all -- the same silent loss of a typed setting this\
 whole feature exists to end. Each copy must get the device it asked for} \
  [list $K_OK \
        [expr {$K_OK && $K_BP ne {NOCALL} && $K_BQ ne {NOCALL} &&
               $K_BP ne $K_BQ ? 1 : 0}] \
        [expr {$K_OK ? [as_pmodel $K_D2 $K_BP] : {NOSTEP1}}] \
        [expr {$K_OK ? [as_pmodel $K_D2 $K_BQ] : {NOSTEP1}}]] \
  {1 1 sky130_fd_pr__pfet_01v8_lvt sky130_fd_pr__pfet_01v8_hvt}

# ----------------------------------------------------------------------------
# AS52-AS53. ISSUE 1203: TWO DIFFERENT SETTING LISTS SPELL ONE CELL NAME.
# ----------------------------------------------------------------------------
# The cell name joins each setting to its value with one underscore and the
# pairs to each other with two. A value that itself holds two underscores
# therefore spells the same string as two separate settings do. Row AS37 is the
# other half of this and it does NOT cover this case: there the two names spell
# the same and the tool separates them, because the two copies reach the naming
# step with different canonical keys. Here the KEY itself is the same, so the
# second copy is handed the first copy's cell body and never reaches AS37's
# separator at all.
set Y_D [as_netlist [file join $AS askey.sch]]
set Y_BD [as_bodyfor $Y_D xD]
set Y_BE [as_bodyfor $Y_D xE]
puts "AS-KEY xD -> $Y_BD ; xE -> $Y_BE ; bodies [as_bodies $Y_D]"

check {AS52 TWO COPIES ASKING FOR TWO DIFFERENT THINGS MUST GET TWO CELL\
 BODIES, issue 1203. xD sets one setting whose value happens to hold the\
 separator; xE sets two settings. Spelled into a cell name the two are one\
 string, so the second copy silently gets the first copy's body and BOTH of its\
 own settings are thrown away -- the p-device it asked for is not in the deck\
 anywhere. Each copy gets its own body and each body holds what that copy asked\
 for} \
  [list [expr {$Y_BD ne {NOCALL} && $Y_BE ne {NOCALL} && $Y_BD ne $Y_BE ? 1 : 0}] \
        [as_word [as_body $Y_D $Y_BE] sky130_fd_pr__nfetA] \
        [as_word [as_body $Y_D $Y_BE] sky130_fd_pr__pfetB] \
        [as_word [as_body $Y_D $Y_BD] sky130_fd_pr__nfetA__modelp_pfetB]] \
  {1 1 1 1}

set AS_NAMEF [as_cfunc $AS_ACTC {const char *auto_spec_name(int inst)}]
check {AS53 STRUCTURAL, issue 1203, and no deck can see it. WHICH COPIES SHARE\
 A BODY is decided by one lookup key, and that key has to be a faithful\
 encoding of the SET of settings -- not the readable spelling, which is for a\
 person to look at and is allowed to be ambiguous, because two readable names\
 that collide are separated a step later. Keying the sharing on the readable\
 spelling is what makes two different requests one cell. The readable name is\
 still built from the readable spelling} \
  [list [expr {$AS_NAMEF eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_NAMEF {&setkey, key}] \
        [as_count $AS_NAMEF {&setkey, canon}] \
        [as_count $AS_NAMEF {s = canon;}]] \
  {1 1 0 1}

# ----------------------------------------------------------------------------
# AS54-AS55. ISSUE 1206: AN EMPTY SETTING VALUE WRITES A SECOND IDENTICAL COPY.
# ----------------------------------------------------------------------------
set Z_D [as_netlist [file join $AS asblank.sch]]
set Z_B [as_bodyfor $Z_D xN]
set Z_N [as_for [as_notes] xN]
set Z_L [as_for [as_lost] xN]
puts "AS-BLANK xN -> $Z_B ; bodies [as_bodies $Z_D] ; notes [llength $Z_N] ;\
 lost [llength $Z_L]"
foreach zl $Z_L { puts "AS-BLANK SAYS: $zl" }

check {AS54 A COPY THAT DIFFERS IN NOTHING IS NOT A COPY, issue 1206. The\
 designer typed the setting name and never got round to the value. The deck got\
 a second cell body whose text is byte-identical to the first, under a name\
 ending in an underscore, and the info window announced it as work done on the\
 designer's behalf. There must be one body, the copy must call the plain cell,\
 nothing may be announced -- and the designer should be told what they left\
 unfinished and what to put there} \
  [list $Z_B [llength [as_bodies $Z_D]] [llength $Z_N] [llength $Z_L] \
        [expr {[llength $Z_L] == 1 ?
               [expr {[string first {left the value empty} [lindex $Z_L 0]] >= 0 ? 1 : 0}] : -1}]] \
  {asnh 1 0 1 1}

set X_D [as_netlist [file join $AS asmix.sch]]
set X_N [as_for [as_notes] xR]
set X_L [as_for [as_lost] xR]
puts "AS-MIX xR -> [as_bodyfor $X_D xR] ; notes [llength $X_N] ; lost\
 [llength $X_L]"
foreach xl $X_N { puts "AS-MIX NOTE: $xl" }
foreach xl $X_L { puts "AS-MIX SAYS: $xl" }

check {AS55 ONE BLANK SETTING BESIDE ONE REAL ONE, issue 1206. The copy is\
 given its own version of the cell for the setting it really did fill in, and\
 the blank one must take no part in it: not in the cell name, not in the\
 sentence that announces it -- and the designer still has to be told about the\
 one they left unfinished. This is the only row that can see the difference\
 between skipping the whole copy and skipping the settings that were honoured} \
  [list [llength $X_N] \
        [expr {[llength $X_N] == 1 ?
               [expr {[string first {called asnh__modeln_nfet_01v8_lvt and} \
                       [lindex $X_N 0]] >= 0 ? 1 : 0}] : -1}] \
        [expr {[llength $X_N] == 1 ? [as_word [lindex $X_N 0] modelp] : -1}] \
        [llength $X_L] \
        [expr {[llength $X_L] == 1 ? [as_word [lindex $X_L 0] modelp] : -1}]] \
  {1 1 0 1 1}

# ----------------------------------------------------------------------------
# AS56. ISSUE 1208: THE ROWS THAT SAY "NOTHING ELSE MOVED" ONLY WORK HERE.
# ----------------------------------------------------------------------------
# AS6 and AS26 pin whole decks by fingerprint. The netlister writes the full
# path of every sheet and every symbol it read into the deck as a comment
# header, so those fingerprints are a property of where this repository sits on
# this disk. This row proves the strip is doing something rather than that two
# decks happened to agree: the SAME deck under a different repository root must
# fingerprint the same once the headers are dropped, and must fingerprint
# DIFFERENTLY while they are still in.
set HD_RAW $BG_NOW
set HD_MOVED {}
set HD_LINES 0
foreach hl [split $HD_RAW "\n"] {
  if {[regexp {^\*\* (sch|sym)_path: } $hl]} {
    incr HD_LINES
    lappend HD_MOVED [string map [list $repo /opt/pdk/xschem] $hl]
  } else {
    lappend HD_MOVED $hl
  }
}
set HD_MOVED [join $HD_MOVED "\n"]
set HD_ALL 0
foreach hl [split $HD_RAW "\n"] {
  if {[string first $repo $hl] >= 0} { incr HD_ALL }
}
puts "AS-HDR lines carrying the checkout root: $HD_ALL of which headers\
 $HD_LINES ; raw here [as_fnv $HD_RAW]\
 raw moved [as_fnv $HD_MOVED] ; stripped here [as_fnv [as_stripsym $HD_RAW]]\
 stripped moved [as_fnv [as_stripsym $HD_MOVED]]"

check {AS56 A ROW THAT SAYS "THIS DECK DID NOT MOVE" MUST NOT ALSO SAY "AND THE\
 REPOSITORY IS STILL IN THE SAME FOLDER", issue 1208. The shipped bandgap deck\
 carries fifteen comment headers holding this checkout's own absolute path.\
 Take the same deck, move the repository, and the fingerprint AS6 and AS26 pin\
 changes without one byte of circuit having moved -- so the suite passes in\
 this checkout and nowhere else. The header lines are dropped before the\
 fingerprint is taken; the raw halves are compared too, so this row cannot pass\
 by the two decks simply being equal. THE FOURTH ELEMENT IS ISSUE 1217: the row\
 already counted every line carrying the checkout root and every line that is\
 one of the two header shapes, printed both, and compared neither to the other\
 -- so the claim its own prose makes, that the two header shapes are the whole\
 of it, was measured and then thrown away} \
  [list [expr {$HD_LINES >= 1 ? 1 : 0}] \
        [expr {[as_fnv $HD_RAW] ne [as_fnv $HD_MOVED] ? 1 : 0}] \
        [expr {[as_fnv [as_stripsym $HD_RAW]] eq
               [as_fnv [as_stripsym $HD_MOVED]] ? 1 : 0}] \
        [expr {$HD_ALL == $HD_LINES ? 1 : 0}]] \
  {1 1 1 1}


# ============================================================================
# AS59-AS77. THE FOUR PRODUCT DEFECTS S6a FILED INSIDE THE NEW BEHAVIOUR --
# issues 1213, 1212, 1214, 1215 -- plus the three cheap ones beside them.
# ============================================================================
# WHAT GOES WRONG FOR THE USER, in the order the damage matters.
#
# 1213 THE DECK IS INVALID. A designer types a setting whose value is just a
# space, or a tab, or a line break, or nothing but punctuation. XSCHEM writes a
# whole second copy of the cell for them, tells them it did it, and puts a
# transistor in the deck with NO DEVICE NAME AT ALL -- 'sky130_fd_pr__' and
# then whatever the value was. With a line break the device line is cut in two
# and a made-up second element appears. No simulator will read either deck.
# The genuinely empty value was already handled, so the guard added for it
# misses by exactly one character. Fixing shapes one at a time is what put us
# here twice, so this pass fixes it by deciding what a value HAS to look like
# and letting everything else alone.
#
# 1212 A SETTING TYPED ON ANOTHER SHEET DISAPPEARS. On a two-level design a
# copy one level down hand-types a cell name, and the top sheet's copy invents
# the very same name. The check that is supposed to notice only ever looks at
# the sheet being written, so both copies end up calling one cell built out of
# the wrong device, and the designer is told nothing at all.
#
# 1214 A value that is already the symbol's own default writes a SECOND cell
# body byte-identical to the first. 1215 Two copies asking for the same thing,
# one of them hand-typing the name, get two byte-identical bodies -- while the
# note in that very run tells the designer any other copy asking for the same
# settings shares the one cell.
#
# EVERY ROW BELOW WAS WRITTEN BEFORE THE FIX AND WATCHED FAIL. The controls
# that must stay green either way say so in their own prose.

## The 1213 fixture cell. One setting the SPICE line drops and the drawing
## reads, and the four ignores so nothing but the SPICE netlist writes it --
## the same shape asnh has, under a name of its own so nothing above is
## disturbed.
as_wr [file join $AS aswv.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
spectre_ignore=true
vhdl_ignore=true
verilog_ignore=true
tedax_ignore=true
template="name=x1 W_P=1
modelp=pfet_01v8"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS aswv.sch] {v {xschem version=3.4.4 file_version=1.2}
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

proc as_sheet {name body} {
  global AS
  as_wr [file join $AS $name.sch] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
$body
C \{devices/iopin\} 1520 0 0 1 \{name=p1 lab=AA\}"
}

## The call line a named instance makes INSIDE a named cell body. as_bodyfor
## reads the top sheet's block only, and every 1212 row is about a copy one
## level down. NOBODY and NOCALL rather than an empty answer, so a sub-sheet
## that never made it into the deck cannot be read as a right answer.
proc as_bodyfor_in {deck cell inst} {
  set b [as_body $deck $cell]
  if {$b eq {NOBODY}} { return NOBODY }
  foreach l [split $b "\n"] {
    set t [string trim $l]
    if {$t eq {}} continue
    if {[lindex [split $t] 0] ne $inst} continue
    return [as_cellof $t]
  }
  return NOCALL
}

## How many cell bodies in this deck are named with a trailing <suffix>.
proc as_endswith {deck suf} {
  set n 0
  foreach b [as_bodies $deck] {
    if {[string length $b] >= [string length $suf] &&
        [string range $b end-[expr {[string length $suf] - 1}] end] eq $suf} { incr n }
  }
  return $n
}

# ----------------------------------------------------------------------------
# AS59-AS67. ISSUE 1213: A VALUE MADE OF BLANK SPACE PUTS A DEVICE THAT DOES
# NOT EXIST IN THE DECK.
# ----------------------------------------------------------------------------
as_sheet asvsp "C \{as/aswv.sym\} 120 0 0 0 \{name=xS W_P=0.5 modelp=\" \"\}"
as_sheet asvtb "C \{as/aswv.sym\} 120 0 0 0 \{name=xT W_P=0.5 modelp=\"\t\"\}"
as_sheet asvnl "C \{as/aswv.sym\} 120 0 0 0 \{name=xNL W_P=0.5 modelp=\"\n\"\}"
as_sheet asvpn "C \{as/aswv.sym\} 120 0 0 0 \{name=xPU W_P=0.5 modelp=\"---\"\}"
as_sheet asvtr "C \{as/aswv.sym\} 120 0 0 0 \{name=xC W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/aswv.sym\} 320 0 0 0 \{name=xD W_P=0.5 modelp=\"pfet_01v8_lvt \"\}"
as_sheet asvqt "C \{as/aswv.sym\} 120 0 0 0 \{name=xQ W_P=0.5 modelp=\"\\\"pfet_01v8_lvt\\\"\"\}
C \{as/aswv.sym\} 320 0 0 0 \{name=xR W_P=0.5 modelp=pfet_01v8_lvt\}"
as_sheet asvmx "C \{as/asnh.sym\} 120 0 0 0 \{name=xM W_P=0.5 modeln=nfet_01v8_lvt modelp=\" \"\}"
as_sheet asdoor "C \{as/aswv.sym\} 120 0 0 0 \{name=xS W_P=0.5 modelp=\" \"\}
C \{as/aswv.sym\} 320 0 0 0 \{name=xR W_P=0.5 modelp=pfet_01v8_lvt\}"

## One blank-shaped value, measured the same way every time: what cell does the
## copy call, how many bodies are in the deck, what device is inside the body it
## calls, does a bare 'sky130_fd_pr__' with no device after it appear, did the
## tool announce a copy it should not have written, and was the designer told.
proc as_shape {sheet inst} {
  global AS
  set d [as_netlist [file join $AS $sheet.sch]]
  set b [as_bodyfor $d $inst]
  set n [as_for [as_notes] $inst]
  set l [as_for [as_lost] $inst]
  set said -1
  if {[llength $l] == 1} {
    set said [expr {[string first {one word} [lindex $l 0]] >= 0 ? 1 : 0}]
  }
  puts "AS-SHAPE $sheet: $inst -> $b ; bodies [as_bodies $d] ; device\
 [as_pmodel $d $b] ; bare-prefix [as_count $d {sky130_fd_pr__ }] ; notes\
 [llength $n] ; told [llength $l]"
  foreach x $n { puts "AS-SHAPE $sheet NOTE: $x" }
  foreach x $l { puts "AS-SHAPE $sheet SAYS: $x" }
  return [list $d [list $b [llength [as_bodies $d]] [as_pmodel $d $b] \
                        [as_count $d {sky130_fd_pr__ }] [llength $n] \
                        [llength $l] $said]]
}

set SP_R [as_shape asvsp xS]
check {AS59 A SETTING WHOSE VALUE IS ONE SPACE, issue 1213. The designer typed\
 a space and nothing else. Measured before the fix: XSCHEM wrote a second copy\
 of the cell called aswv__modelp__, pointed the copy at it, announced that it\
 had done so, and put a transistor in the deck reading "sky130_fd_pr__" with no\
 device name after it -- a deck no simulator will read, under a note telling\
 the designer there is nothing for them to do. RULING D5-1. The copy has to\
 call the plain cell, there must be exactly one cell body, the device in it is\
 the one the symbol supplies, nothing may be announced, and the designer has to\
 be told plainly that a value has to be one word} \
  [lindex $SP_R 1] \
  {aswv 1 sky130_fd_pr__pfet_01v8 0 0 1 1}

set TB_R [as_shape asvtb xT]
check {AS60 THE SAME VALUE TYPED AS A TAB, issue 1213. A tab is not a space and\
 it is not empty, so it walks past a guard written for either of them one at a\
 time. Same deck damage, same measurement} \
  [lindex $TB_R 1] \
  {aswv 1 sky130_fd_pr__pfet_01v8 0 0 1 1}

set NL_R [as_shape asvnl xNL]
set NL_D [lindex $NL_R 0]
set NL_SPLIT 0
foreach nll [split $NL_D "\n"] { if {[string range $nll 0 2] eq {XL=}} { incr NL_SPLIT } }
puts "AS-SHAPE asvnl: element lines beginning XL= : $NL_SPLIT"
check {AS61 THE SAME VALUE TYPED AS A LINE BREAK, AND IT IS WORSE THAN THE\
 OTHERS, issue 1213. The value goes into the deck as written, so the line break\
 CUTS THE TRANSISTOR LINE IN HALF: the first half ends at "sky130_fd_pr__" and\
 the second half starts a whole new element line beginning "XL=", which is a\
 subcircuit call to a cell nobody has ever heard of. Measured on the raw deck\
 bytes, two genuine lines. So this row asks the ordinary six questions AND that\
 no line of the deck begins that way} \
  [concat [lindex $NL_R 1] [list $NL_SPLIT]] \
  {aswv 1 sky130_fd_pr__pfet_01v8 0 0 1 1 0}

set PN_R [as_shape asvpn xPU]
set PN_D [lindex $PN_R 0]
puts "AS-SHAPE asvpn: occurrences of the punctuation device name:\
 [as_count $PN_D {sky130_fd_pr__---}]"
check {AS62 A VALUE THAT IS NOTHING BUT PUNCTUATION, issue 1213. This one is\
 not blank at all, which is why a rule written about blankness would still miss\
 it. Measured before the fix: the deck named the device "sky130_fd_pr__---".\
 The rule this pass adds is about what a value MUST look like -- one word with\
 at least one letter or digit in it -- so a shape nobody thought of is safe\
 without anybody having thought of it} \
  [concat [lindex $PN_R 1] [list [as_count $PN_D {sky130_fd_pr__---}]]] \
  {aswv 1 sky130_fd_pr__pfet_01v8 0 0 1 1 0}

set TR_D [as_netlist [file join $AS asvtr.sch]]
set TR_C [as_bodyfor $TR_D xC]
set TR_D2 [as_bodyfor $TR_D xD]
set TR_LD [as_for [as_lost] xD]
puts "AS-TRAIL xC -> $TR_C ; xD -> $TR_D2 ; bodies [as_bodies $TR_D] ; bodies\
 ending in an underscore [as_endswith $TR_D _] ; told about xD [llength $TR_LD]"
foreach tl $TR_LD { puts "AS-TRAIL SAYS: $tl" }
check {AS63 A REAL VALUE WITH A SPACE ON THE END OF IT, issue 1213, AND IT IS A\
 THIRD DUPLICATE-BODY SHAPE NOBODY FILED. Two copies on one sheet ask for the\
 same device; one of them has an invisible space after the value. Measured\
 before the fix: TWO cell bodies, both 314 bytes and byte-identical, one of\
 them named with a trailing underscore -- and the note in that run told the\
 designer that any other copy asking for the same settings shares the one cell.\
 The copy whose value is one clean word gets the separate cell; the copy with\
 the space falls through to the plain cell and its designer is told why} \
  [list [expr {$TR_C ne {aswv} && $TR_C ne {NOCALL} ? 1 : 0}] \
        $TR_D2 \
        [llength [as_bodies $TR_D]] \
        [as_pmodel $TR_D $TR_C] \
        [as_endswith $TR_D _] \
        [llength $TR_LD]] \
  {1 aswv 2 sky130_fd_pr__pfet_01v8_lvt 0 1}

set QT_D [as_netlist [file join $AS asvqt.sch]]
set QT_Q [as_bodyfor $QT_D xQ]
set QT_R [as_bodyfor $QT_D xR]
puts "AS-QUOTE xQ -> $QT_Q ; xR -> $QT_R ; bodies [as_bodies $QT_D]"
check {AS64 QUOTES ROUND A REAL VALUE ARE FINE AND MUST STAY FINE, issue 1213.\
 This row pins a fact rather than a defect and it is green before and after.\
 The file reader takes the quotes off before this feature sees anything, so a\
 value typed in quotes is already the plain value: one shared cell, the right\
 device, and a cell name with no quote debris in it. Without this row the next\
 hand to read the new rule would "fix" quotes into it and break a spelling that\
 works today} \
  [list [expr {$QT_Q eq $QT_R ? 1 : 0}] $QT_Q [llength [as_bodies $QT_D]] \
        [as_pmodel $QT_D $QT_Q]] \
  {1 aswv__modelp_pfet_01v8_lvt 2 sky130_fd_pr__pfet_01v8_lvt}

set MX_D [as_netlist [file join $AS asvmx.sch]]
set MX_N [as_for [as_notes] xM]
set MX_L [as_for [as_lost] xM]
puts "AS-BLANKMIX xM -> [as_bodyfor $MX_D xM] ; bodies [as_bodies $MX_D] ;\
 notes [llength $MX_N] ; told [llength $MX_L]"
foreach ml $MX_N { puts "AS-BLANKMIX NOTE: $ml" }
foreach ml $MX_L { puts "AS-BLANKMIX SAYS: $ml" }
check {AS65 ONE BLANK-SHAPED SETTING BESIDE ONE REAL ONE, issue 1213. This is\
 the twin of row AS55 and it is the ONLY row that can tell the difference\
 between throwing the whole copy away and throwing away just the setting that\
 was not usable. The copy still gets its own version of the cell for the\
 setting it really did fill in; the space-valued one takes no part in the cell\
 name and no part in the sentence that announces it; and the designer is still\
 told about the one they left unusable. A repair that only fixes the classifier\
 and not the sentence is invisible to every other row here. THE LAST TWO\
 ELEMENTS ARE ISSUE 1227 AND THEY ARE THE POINT OF THE ROW: until this pass\
 the row asked only what the tool SAID, and the refused setting walked into the\
 new cell body anyway through the copy's property string -- the very transistor\
 reading "sky130_fd_pr__" with no device name after it that rows AS59-AS62 are\
 about, rebuilt one line further on, under a warning saying that setting\
 changed nothing. So the device inside the body this copy really calls is\
 asked for here, and it has to be the one the symbol supplies} \
  [list [llength $MX_N] \
        [expr {[llength $MX_N] == 1 ?
               [expr {[string first {called asnh__modeln_nfet_01v8_lvt and} \
                       [lindex $MX_N 0]] >= 0 ? 1 : 0}] : -1}] \
        [expr {[llength $MX_N] == 1 ? [as_word [lindex $MX_N 0] modelp] : -1}] \
        [llength $MX_L] \
        [expr {[llength $MX_L] == 1 ? [as_word [lindex $MX_L 0] modelp] : -1}] \
        [as_pmodel $MX_D [as_bodyfor $MX_D xM]] \
        [as_count $MX_D {sky130_fd_pr__ }]] \
  {1 1 0 1 1 sky130_fd_pr__pfet_01v8 0}

## The OTHER door. The schematic surface asks the netlister "did this copy get
## its own version of the cell" while descending into it, and the answer is
## published on the hierarchy level. Read it back the way the annotation
## surface does.
proc as_door {sch inst} {
  catch {xschem clear force}
  if {[catch {xschem load $sch}]} { return LOADFAIL }
  set n -1
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[xschem getprop instance $i name] eq $inst} { set n $i ; break }
  }
  if {$n < 0} { return NOINST }
  catch {xschem unselect_all}
  catch {xschem select instance $n}
  if {[catch {xschem descend}]} { return NODESCEND }
  set g [xschem globals]
  set cur 0
  set flag NOFLAG
  foreach ln [split $g "\n"] {
    if {[regexp {^currsch=(\d+)} $ln -> c]} { set cur $c }
  }
  foreach ln [split $g "\n"] {
    if {[regexp {^lcc\[(\d+)\]\.auto_spec=(\d+)} $ln -> lev v]} {
      if {$lev == $cur - 1} { set flag $v }
    }
  }
  catch {xschem go_back}
  return $flag
}
set DOOR_SP [as_door [file join $AS asdoor.sch] xS]
set DOOR_RE [as_door [file join $AS asdoor.sch] xR]
puts "AS-DOOR space-valued copy answers $DOOR_SP ; real-valued copy answers\
 $DOOR_RE"
check {AS66 THE DECK IS NOT THE ONLY PLACE THIS GOES WRONG, issue 1213. The\
 schematic surface asks the same question when the designer walks down into a\
 copy -- "did the netlister give this copy a cell of its own" -- and the answer\
 is what the annotation surface later uses to look device numbers up by name.\
 Measured before the fix: the space-valued copy answered YES, so the schematic\
 would go looking for numbers under the garbage cell name too, not just the\
 deck. Both doors read one rule in one place, so both move together: the\
 space-valued copy answers no, the real-valued one beside it still answers yes} \
  [list $DOOR_SP $DOOR_RE] {0 1}

set AS_SCAN [as_cfunc $AS_TOKC {static int lost_attrs_scan(int inst, int allow_explicit}]
set AS_STRIP [as_cfunc $AS_TOKC {int lost_attrs_strip_unusable(int inst, char **out)}]
puts "AS-RULE scan body found: [expr {$AS_SCAN eq {NOFUNC} ? {no} : {yes}}] ;\
 strip body found: [expr {$AS_STRIP eq {NOFUNC} ? {no} : {yes}}] ;\
 rule called [as_count $AS_TOKC {ua_value_specialisable(}] times in the file"
check {AS67 STRUCTURAL, ISSUE 1213, AND NO DECK CAN SEE IT. What a usable value\
 IS gets decided in ONE place and BOTH halves of this feature ask it: the half\
 that decides whether a copy gets its own cell, and the half that writes the\
 sentence the designer reads. A repair that moves only the first leaves the\
 tool doing the right thing silently, and a repair that moves only the second\
 leaves it explaining a deck it still wrote wrong. This row also requires the\
 one-byte test that shipped with the empty-value guard to be GONE from the\
 classifier rather than sitting beside the new rule, because two rules in one\
 condition is how the next shape gets missed. THERE IS NOW A THIRD ASKER,\
 issue 1227: the half that keeps a refused setting OUT of the new cell body,\
 without which the tool said the setting went nowhere while the setting sat in\
 the deck. THE FILE-WIDE COUNT IS FOUR AND NOT THREE: the rule is written down\
 once and asked three times, and the line that writes it down spells its own\
 name too. Row AS40 counts auto_spec_name the same way} \
  [list [expr {$AS_SCAN eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_TOKC {ua_value_specialisable(}] \
        [as_count $AS_SCAN {ua_value_specialisable(tval)}] \
        [as_count $AS_SCAN {tval[0]}] \
        [as_count $AS_SCAN {ua_value_is_template_default(}] \
        [expr {$AS_STRIP eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_STRIP {ua_value_specialisable(tval)}]] \
  {1 4 1 0 1 1 1}

# ----------------------------------------------------------------------------
# AS68-AS69. ISSUE 1214: A VALUE THAT IS ALREADY THE SYMBOL'S OWN DEFAULT
# WRITES A SECOND, IDENTICAL CELL BODY.
# ----------------------------------------------------------------------------
as_sheet asdfl "C \{as/aswv.sym\} 120 0 0 0 \{name=xU W_P=0.5 modelp=pfet_01v8\}"
as_sheet asdf2 "C \{as/aswv.sym\} 120 0 0 0 \{name=xU2 W_P=0.5 modelp=pfet_01v8\}
C \{as/aswv.sym\} 320 0 0 0 \{name=xV W_P=0.5 modelp=pfet_01v8_lvt\}"

set DF_D [as_netlist [file join $AS asdfl.sch]]
set DF_B [as_bodyfor $DF_D xU]
set DF_N [as_for [as_notes] xU]
set DF_L [as_for [as_lost] xU]
puts "AS-DEFAULT xU -> $DF_B ; bodies [as_bodies $DF_D] ; notes [llength $DF_N]\
 ; told [llength $DF_L]"
foreach dl $DF_N { puts "AS-DEFAULT NOTE: $dl" }
foreach dl $DF_L { puts "AS-DEFAULT SAYS: $dl" }
check {AS68 A COPY THAT ASKS FOR WHAT THE SYMBOL ALREADY SUPPLIES IS NOT A\
 SPECIAL COPY, issue 1214, AND THE DESIGNER SHOULD HEAR NOTHING ABOUT IT. The\
 symbol's own template already says modelp=pfet_01v8 and the copy types exactly\
 that. Measured before the fix: a second cell body, 310 bytes and byte-identical\
 to the first, plus a note announcing it as work done for the designer. The\
 setting had precisely the effect they wanted, so there is nothing lost and\
 nothing to do -- one body, the plain cell name on the call line, no note, and\
 NO warning either. Both halves are in this one row on purpose: a repair that\
 stops writing the body but starts accusing the designer of losing a setting is\
 not a repair} \
  [list $DF_B [llength [as_bodies $DF_D]] [llength $DF_N] [llength $DF_L]] \
  {aswv 1 0 0}

set D2_D [as_netlist [file join $AS asdf2.sch]]
set D2_U [as_bodyfor $D2_D xU2]
set D2_V [as_bodyfor $D2_D xV]
puts "AS-DEFAULT2 xU2 -> $D2_U ; xV -> $D2_V ; bodies [as_bodies $D2_D]"
check {AS69 ONE DEFAULT-VALUED COPY BESIDE ONE REAL ONE, issue 1214. The copy\
 that really did ask for a different device still gets its own version of the\
 cell, so the repair cannot be "stop making copies". The copy that asked for\
 the default calls the plain cell, and the name spelled out of the default\
 value is nowhere in the deck at all} \
  [list $D2_U $D2_V [llength [as_bodies $D2_D]] \
        [expr {[lsearch -exact [as_bodies $D2_D] aswv__modelp_pfet_01v8] < 0 ? 1 : 0}]] \
  {aswv aswv__modelp_pfet_01v8_lvt 2 1}

# ----------------------------------------------------------------------------
# AS70-AS73. ISSUE 1215 AND ISSUE 1212: TWO COPIES THAT WANT THE SAME THING,
# AND A NAME TYPED ON A SHEET ONE LEVEL DOWN.
# ----------------------------------------------------------------------------
# Built in two steps like row AS51, so no row here depends on guessing the name
# this build invents: the first run LEARNS it, and every fixture below hand-types
# exactly that.
as_sheet asdup1 "C \{as/aswv.sym\} 120 0 0 0 \{name=xA W_P=0.5 modelp=pfet_01v8_lvt\}"
set DP_D1 [as_netlist [file join $AS asdup1.sch]]
set DP_NAME [as_bodyfor $DP_D1 xA]
set DP_OK [expr {$DP_NAME ne {NOCALL} && $DP_NAME ne {aswv} ? 1 : 0}]
puts "AS-DUP learned invented name: $DP_NAME"

if {$DP_OK} {
  as_sheet asdup2 "C \{as/aswv.sym\} 120 0 0 0 \{name=xA W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/aswv.sym\} 320 0 0 0 \{name=xB W_P=0.5 modelp=pfet_01v8_lvt schematic=$DP_NAME\}"
  as_sheet asdif2 "C \{as/aswv.sym\} 120 0 0 0 \{name=xA W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/aswv.sym\} 320 0 0 0 \{name=xB W_P=0.5 modelp=pfet_01v8_hvt schematic=$DP_NAME\}"
}

set DP_D2 [expr {$DP_OK ? [as_netlist [file join $AS asdup2.sch]] : {}}]
set DP_A [expr {$DP_OK ? [as_bodyfor $DP_D2 xA] : {NOSTEP1}}]
set DP_B [expr {$DP_OK ? [as_bodyfor $DP_D2 xB] : {NOSTEP1}}]
set DP_NOTES [as_notes]
set DP_SHARE 0
foreach dn $DP_NOTES {
  if {[string first {asks for the same settings shares that one} $dn] >= 0} { set DP_SHARE 1 }
}
puts "AS-DUP xA -> $DP_A ; xB -> $DP_B ; bodies\
 [expr {$DP_OK ? [as_bodies $DP_D2] : {}}] ; bodies ending _1\
 [expr {$DP_OK ? [as_endswith $DP_D2 _1] : -1}] ; sharing sentence $DP_SHARE"
foreach dn $DP_NOTES { puts "AS-DUP NOTE: $dn" }
check {AS70 TWO COPIES ASKING FOR THE SAME THING MUST SHARE ONE CELL, AND THE\
 SENTENCE THAT SAYS SO HAS TO BE TRUE, issue 1215. One copy lets XSCHEM name\
 the cell; the copy beside it asks for exactly the same device and hand-types\
 that same name. Measured before the fix: TWO cell bodies, 314 bytes each and\
 byte-identical, one of them with a "_1" stuck on the end -- while the note\
 printed in that same run ended "Any other copy of aswv on this design that\
 asks for the same settings shares that one". The tool has to adopt the name\
 the designer typed for both of them: one body, both call lines naming it,\
 nothing carrying a "_1", and that sentence finally true} \
  [list $DP_OK \
        [expr {$DP_A eq $DP_NAME ? 1 : 0}] \
        [expr {$DP_B eq $DP_NAME ? 1 : 0}] \
        [expr {$DP_OK ? [llength [as_bodies $DP_D2]] : -1}] \
        [expr {$DP_OK ? [as_endswith $DP_D2 _1] : -1}] \
        $DP_SHARE] \
  {1 1 1 2 0 1}

set DF_D2 [expr {$DP_OK ? [as_netlist [file join $AS asdif2.sch]] : {}}]
set DFA [expr {$DP_OK ? [as_bodyfor $DF_D2 xA] : {NOSTEP1}}]
set DFB [expr {$DP_OK ? [as_bodyfor $DF_D2 xB] : {NOSTEP1}}]
puts "AS-DIFF xA -> $DFA ; xB -> $DFB ; bodies\
 [expr {$DP_OK ? [as_bodies $DF_D2] : {}}]"
check {AS71 CONTROL FOR AS70, AND IT MUST STAY GREEN BOTH SIDES. The same shape\
 with the two copies asking for DIFFERENT devices still has to give them\
 different cells, with the invented name stepping aside for the typed one --\
 that is issue 1202, closed one item ago. Without this row, "make copies that\
 want the same thing share" could be written as "stop separating copies", which\
 puts 1202 straight back} \
  [list [expr {$DP_OK && $DFA ne {NOCALL} && $DFB ne {NOCALL} && $DFA ne $DFB ? 1 : 0}] \
        $DFB \
        [expr {$DP_OK ? [as_endswith $DF_D2 _1] : -1}] \
        [expr {$DP_OK ? [as_pmodel $DF_D2 $DFA] : {NOSTEP1}}] \
        [expr {$DP_OK ? [as_pmodel $DF_D2 $DFB] : {NOSTEP1}}]] \
  [list 1 $DP_NAME 1 sky130_fd_pr__pfet_01v8_lvt sky130_fd_pr__pfet_01v8_hvt]

## THE TWO-LEVEL FIXTURES. A middle cell holding one copy of aswv that
## hand-types the cell name -- once written plainly, once written through an @
## substitution the file scan is meant to leave alone.
as_wr [file join $AS aswmid.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
spectre_ignore=true
vhdl_ignore=true
verilog_ignore=true
tedax_ignore=true
template="name=x1"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

as_wr [file join $AS aswmat.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
spectre_ignore=true
vhdl_ignore=true
verilog_ignore=true
tedax_ignore=true
template="name=x1"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

if {$DP_OK} {
  as_wr [file join $AS aswmid.sch] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
C \{devices/iopin\} 200 -300 0 1 \{name=p1 lab=A\}
C \{as/aswv.sym\} 400 -300 0 0 \{name=xW W_P=0.5 modelp=pfet_01v8_hvt schematic=$DP_NAME\}"
  as_wr [file join $AS aswmat.sch] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
C \{devices/iopin\} 200 -300 0 1 \{name=p1 lab=A\}
C \{as/aswv.sym\} 400 -300 0 0 \{name=xW W_P=0.5 modelp=pfet_01v8_hvt myname=$DP_NAME schematic=@myname\}"
  as_sheet ashtop "C \{as/aswv.sym\} 120 0 0 0 \{name=xY W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/aswmid.sym\} 320 0 0 0 \{name=xMID\}"
  as_sheet ashtop2 "C \{as/aswv.sym\} 120 0 0 0 \{name=xY W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/aswmat.sym\} 320 0 0 0 \{name=xMID\}"
}

set HR_D [expr {$DP_OK ? [as_netlist [file join $AS ashtop.sch]] : {}}]
set HR_W [expr {$DP_OK ? [as_bodyfor_in $HR_D aswmid xW] : {NOSTEP1}}]
set HR_Y [expr {$DP_OK ? [as_bodyfor $HR_D xY] : {NOSTEP1}}]
puts "AS-HIER xY -> $HR_Y ; xW one level down -> $HR_W ; bodies\
 [expr {$DP_OK ? [as_bodies $HR_D] : {}}]"
puts "AS-HIER low-Vt device in the deck [as_word $HR_D sky130_fd_pr__pfet_01v8_lvt]\
 ; high-Vt device in the deck [as_word $HR_D sky130_fd_pr__pfet_01v8_hvt]"
check {AS72 A CELL NAME TYPED ON A SHEET ONE LEVEL DOWN IS ALREADY SPOKEN FOR,\
 issue 1212. The check that stops XSCHEM inventing a name somebody already used\
 only ever looks at the sheet being written, so on a design of more than one\
 sheet it protects nothing. Measured before the fix: the copy one level down\
 typed modelp=pfet_01v8_hvt and hand-typed its cell name; the top sheet's copy\
 invented that same name; both call lines pointed at one cell built from the\
 low-threshold device, and the string pfet_01v8_hvt appeared ZERO times in the\
 whole deck. A setting the designer typed, gone without a word -- inside the\
 fix meant to end exactly that. Both devices have to be in the deck, the copy\
 that typed the name keeps it, and the invented one steps aside} \
  [list [expr {$DP_OK ? [as_word $HR_D sky130_fd_pr__pfet_01v8_lvt] : -1}] \
        [expr {$DP_OK ? [as_word $HR_D sky130_fd_pr__pfet_01v8_hvt] : -1}] \
        $HR_W \
        [expr {$DP_OK && $HR_W ne $HR_Y && $HR_W ne {NOCALL} &&
               $HR_W ne {NOBODY} ? 1 : 0}]] \
  [list 1 1 $DP_NAME 1]

set CL_D [expr {$DP_OK ? [as_netlist [file join $AS ashtop2.sch]] : {}}]
set CL_L [as_for [as_lost] xW]
set CL_SAYS -1
set CL_NAME -1
set CL_SET -1
set CL_JARGON -1
if {[llength $CL_L] == 1} {
  set CL_SAYS [expr {[string first {already made a cell of that name} \
                      [lindex $CL_L 0]] >= 0 ? 1 : 0}]
  set CL_NAME [as_word [lindex $CL_L 0] $DP_NAME]
  set CL_SET [as_word [lindex $CL_L 0] modelp]
  set CL_JARGON 0
  foreach cw {prop_ptr auto_spec subckt tok} {
    incr CL_JARGON [as_word [lindex $CL_L 0] $cw]
  }
}
puts "AS-CLASH lines about xW: [llength $CL_L]"
foreach cl $CL_L { puts "AS-CLASH SAYS: $cl" }
check {AS73 AND WHEN XSCHEM CANNOT WORK OUT WHERE A SHEET LIVES, IT SAYS SO\
 RATHER THAN GOING QUIET, issue 1212. Reading the design's files to find names\
 already in use can only be done for the sheets XSCHEM can resolve for certain;\
 here the copy one level down writes its cell name through an @ substitution,\
 which is worked out while the netlist runs and cannot be read off the file\
 beforehand. That copy's typed setting still goes nowhere -- but the designer\
 now gets one plain-English line naming the copy, the cell name it asked for\
 and the setting that did not reach the simulator, instead of the silence\
 measured before the fix. And it is written for a first-time reader: none of\
 the tool's own internal words appear in it} \
  [list [llength $CL_L] $CL_SAYS $CL_NAME $CL_SET $CL_JARGON] \
  {1 1 1 1 0}

set AS_SCANF [as_cfunc $AS_ACTC {static void auto_spec_scan_file(}]
set AS_SCAND [as_cfunc $AS_ACTC {static void auto_spec_scan_design(void)}]
puts "AS-SCAN design-walk called [as_count $AS_ACTC {auto_spec_scan_design();}]\
 times ; per-file helper found\
 [expr {$AS_SCANF eq {NOFUNC} ? {no} : {yes}}] ; visited-set lookups\
 [as_count $AS_SCANF {str_hash_lookup(seen,}] ; once-per-run latch mentions\
 [as_count $AS_SCAND {auto_spec_scanned}]"
check {AS74 STRUCTURAL, ISSUE 1212, AND IT IS DELIBERATELY NOT A BEHAVIOURAL\
 ROW. Reading a design's sheets to find the names already in use walks from one\
 sheet to the next, and two sheets that refer to each other would walk for\
 ever. A missing depth limit or a missing memory of where it has already been\
 does not make a test fail -- it makes the suite HANG, and a hang is not a test\
 result. So the limit and the visited set are required to be there by reading\
 the code, and the walk is required to happen once per netlist run and not once\
 per copy.\
 ISSUE 1221 -- THE MEMORY HALF OF THIS ROW USED TO BE HOLLOW, and the sabotage\
 pass proved it: the element asked whether the word "seen" occurred at all, and\
 the walk's own PARAMETER is called seen, so the entire memory could be deleted\
 with this row still green. What a memory of where it has been actually is, is\
 the pair of table calls -- the one that asks whether this sheet has been read\
 and the one that records that it has -- so both are counted. Without them a\
 design where two sheets both place the same cell, which is the ordinary shape\
 of any reused cell, is re-read once per path down to a depth of CADMAXHIER,\
 and what the designer sees is a netlist that never finishes.\
 ISSUE 1224 -- THE ONCE-PER-RUN HALF WAS HOLLOW TOO, for the same reason: the\
 elements counted the CALL SITES and never the calls. The latch that makes the\
 walk happen once per netlist run rather than once per copy is now counted\
 inside the walk's own entry point, where deleting it shows} \
  [list [as_count $AS_ACTC {auto_spec_scan_design();}] \
        [as_count $AS_ACTC {static void auto_spec_scan_design(void)}] \
        [expr {$AS_SCANF eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_SCANF {CADMAXHIER}] \
        [as_count $AS_SCANF {str_hash_lookup(seen,}] \
        [expr {$AS_SCAND eq {NOFUNC} ? {NOFUNC} : 1}] \
        [as_count $AS_SCAND {auto_spec_scanned}] \
        [expr {[as_count $AS_ABEG {auto_spec_typed}] >= 1 ? 1 : 0}] \
        [expr {[as_count $AS_AEND {auto_spec_typed}] >= 1 ? 1 : 0}]] \
  {1 1 1 1 2 1 2 1 1}

# ----------------------------------------------------------------------------
# AS75 AND AS77. THE TWO CHEAP ONES BESIDE THEM -- issues 1216 and 1218.
# ----------------------------------------------------------------------------
puts "AS-ONESENTENCE copies of the shared clause in token.c:\
 [as_count $AS_TOKC {never reads %s when the netlist is written}]"
check {AS75 STRUCTURAL, ISSUE 1216. One sentence the designer reads is written\
 out FOUR times in one function, once per branch, and today all four agree. A\
 fifth branch is being added in this very pass. RULING D5-4 says a sentence the\
 user reads is minted in one place and rendered by whoever needs it, and the\
 reason is not tidiness: four copies drift, and the drift shows up on a\
 stranger's screen. Exactly one copy} \
  [as_count $AS_TOKC {never reads %s when the netlist is written}] 1

## Assembled from pieces so that this row's own file cannot satisfy it. The
## phrase is a tick box that does not exist anywhere in this build.
set AS_WIDG [string map {Z { }} {netlistZcurrentZschematicZonly}]
## FLATTENED FIRST, AND THAT IS NOT COSMETIC. Every one of the three places
## this phrase lives wraps it across two lines -- a C comment continuing, a
## Tcl row title continuing with a backslash, a comment line starting with a
## hash. Counted on the raw bytes the phrase is contiguous NOWHERE and the row
## passes having found nothing, which is what it did when first written.
## Comment markers and line breaks are dropped and runs of blank space become
## one space, so a sentence is counted as the reader reads it.
proc as_flat {t} {
  set out {}
  foreach l [split $t "\n"] {
    regsub {^\s*#+} $l { } l
    ## ISSUE 1222. A C BLOCK COMMENT CONTINUES WITH ` * ` AND THAT IS THE SHAPE
    ## ALL THREE ORIGINAL SITES WERE WRITTEN IN. Dropping only the Tcl hash left
    ## two flattened lines joined as "...netlist current * schematic only...",
    ## so the phrase was still not contiguous and the row passed with the
    ## invented widget name sitting in the file. Measured by putting it back
    ## wrapped: green at 77 checks. The opening `/*` goes too, for the line the
    ## comment starts on.
    regsub {^\s*/\*+} $l { } l
    regsub {^\s*\*+} $l { } l
    regsub {\\$} $l { } l
    lappend out [string trim $l]
  }
  set j [join $out { }]
  while {[regsub -all {  } $j { } j]} {}
  return $j
}
set AS_SPNRAW [as_flat [as_slurp [file join $repo src spice_netlist.c]]]
set AS_ACTRAW [as_flat [as_slurp [file join $repo src actions.c]]]
set AS_SELF [as_flat [as_slurp [file join $repo tests headless test_auto_specialize_1201.tcl]]]
puts "AS-WIDGET invented tick box: spice_netlist.c [as_count $AS_SPNRAW $AS_WIDG]\
 ; actions.c [as_count $AS_ACTRAW $AS_WIDG] ; this suite [as_count $AS_SELF $AS_WIDG]"
check {AS77 ISSUE 1218. The comments describing the single-sheet netlist tell\
 the next reader that the designer TICKS a box with a particular label. There\
 is no such box anywhere in this build -- the real doors are the Shift-N key\
 and the netlist command's own no-hierarchy option. The house rule is to name\
 things the user can actually see, and an invented widget sends the next reader\
 hunting for something that is not there. Counted in the raw files, comments\
 included, because that is the only place it lives -- and in this suite's own\
 row prose too, where it has already spread. Counted on the flattened text,\
 because all three sites wrap the phrase across a line break and counting raw\
 bytes finds none of them} \
  [list [as_count $AS_SPNRAW $AS_WIDG] [as_count $AS_ACTRAW $AS_WIDG] \
        [as_count $AS_SELF $AS_WIDG]] \
  {0 0 0}



# ----------------------------------------------------------------------------
# AS78-AS85. ISSUE 1227: A SETTING XSCHEM SAYS IT COULD NOT USE STILL WALKED
# INTO THE CELL BODY IT WROTE -- plus the guards the sabotage pass found that
# no row could see (issues 1221-1226) and the recorded residual of 1220.
# ----------------------------------------------------------------------------

## One good setting beside one whose value is a LINE BREAK. Rows AS59-AS62 use
## a copy whose ONLY setting is unusable, so the copy falls back to the plain
## cell and there is no new body for the refused value to leak into. Add a
## second, usable setting and the copy IS given a cell of its own -- and until
## issue 1227 the refused value was fed to it anyway.
as_sheet asmxnl "C \{as/asnh.sym\} 120 0 0 0 \{name=xL W_P=0.5 modeln=nfet_01v8_lvt modelp=\"\n\"\}"
## Two copies asking for the SAME usable setting whose REFUSED values differ.
as_sheet asmxtw "C \{as/asnh.sym\} 120 0 0 0 \{name=xE1 W_P=0.5 modeln=nfet_01v8_lvt modelp=\"pfet_01v8_lvt \"\}
C \{as/asnh.sym\} 320 0 0 0 \{name=xE2 W_P=0.5 modeln=nfet_01v8_lvt modelp=\"pfet_01v8_hvt \"\}"
## A value carrying an '@'.
as_sheet asvat "C \{as/aswv.sym\} 120 0 0 0 \{name=xAT W_P=0.5 modelp=pfet@01v8_lvt\}"

set NX_D [as_netlist [file join $AS asmxnl.sch]]
set NX_B [as_bodyfor $NX_D xL]
set NX_SPLIT 0
foreach nxl [split $NX_D "\n"] { if {[string range $nxl 0 2] eq {XL=}} { incr NX_SPLIT } }
set NX_L [as_for [as_lost] xL]
puts "AS-LEAK asmxnl: xL -> $NX_B ; bodies [as_bodies $NX_D] ; pfet in that body\
 [as_pmodel $NX_D $NX_B] ; nfet in it [as_nmodel $NX_D $NX_B] ; bare-prefix\
 [as_count $NX_D {sky130_fd_pr__ }] ; element lines beginning XL= $NX_SPLIT ;\
 told [llength $NX_L]"
foreach nxl $NX_L { puts "AS-LEAK SAYS: $nxl" }
check {AS78 A REFUSED SETTING MUST NOT REACH THE CELL BODY XSCHEM WRITES FOR\
 THE COPY, issue 1227, AND THIS IS THE SHAPE THAT BROKE THE DECK. The copy\
 types one setting XSCHEM can use and one whose value is a line break. It is\
 given a version of the cell for the usable one -- that is right, and rows AS55\
 and AS65 are about it -- but the copy's whole property string was then handed\
 to that new cell, so the line break went in as well. Measured before the fix:\
 the transistor line inside the new cell was CUT IN HALF, ending at\
 "sky130_fd_pr__" with no device name, and the rest of it started a second\
 element line beginning "XL=", a call to a cell nobody has ever heard of --\
 exactly the damage row AS61 measures, rebuilt one level in, and printed under\
 a warning telling the designer that setting "did not reach the simulator and\
 changed nothing". It had reached it. RULING D5-1. The refused setting now\
 falls back to the value the symbol itself supplies, the usable one still\
 counts, and the sentence is true} \
  [list [expr {$NX_B ne {asnh} && $NX_B ne {NOCALL} ? 1 : 0}] \
        [as_nmodel $NX_D $NX_B] \
        [as_pmodel $NX_D $NX_B] \
        [as_count $NX_D {sky130_fd_pr__ }] \
        $NX_SPLIT \
        [llength $NX_L]] \
  {1 sky130_fd_pr__nfet_01v8_lvt sky130_fd_pr__pfet_01v8 0 0 1}

set TW_D [as_netlist [file join $AS asmxtw.sch]]
set TW_1 [as_bodyfor $TW_D xE1]
set TW_2 [as_bodyfor $TW_D xE2]
set TW_L [concat [as_for [as_lost] xE1] [as_for [as_lost] xE2]]
puts "AS-SHARED asmxtw: xE1 -> $TW_1 ; xE2 -> $TW_2 ; bodies [as_bodies $TW_D] ;\
 low-Vt pfet in the deck [as_word $TW_D sky130_fd_pr__pfet_01v8_lvt] ; high-Vt\
 pfet in the deck [as_word $TW_D sky130_fd_pr__pfet_01v8_hvt] ; told [llength $TW_L]"
foreach twl $TW_L { puts "AS-SHARED SAYS: $twl" }
check {AS79 AND THE SAME LEAK MADE TWO COPIES SIMULATE ONE ANOTHER'S DEVICE\
 WITH NOTHING SAID, issue 1227. Two copies ask for the same usable setting, and\
 each also carries a different device name with an invisible space on the end\
 of it. Because a refused setting takes no part in deciding which copies share\
 a cell, the two copies share ONE cell body -- and until this pass that one\
 body was built from whichever copy was written first, so the second copy\
 silently simulated the FIRST copy's transistor. Neither designer was told\
 anything except that their own setting "changed nothing", which was true for\
 one of them and false for the other. Both copies now get the value the symbol\
 supplies, so the shared body really does match what both of them asked for,\
 and NEITHER hand-typed device may appear anywhere in the deck} \
  [list [expr {$TW_1 eq $TW_2 ? 1 : 0}] \
        [expr {$TW_1 ne {asnh} && $TW_1 ne {NOCALL} ? 1 : 0}] \
        [as_pmodel $TW_D $TW_1] \
        [as_word $TW_D sky130_fd_pr__pfet_01v8_lvt] \
        [as_word $TW_D sky130_fd_pr__pfet_01v8_hvt] \
        [llength $TW_L]] \
  {1 1 sky130_fd_pr__pfet_01v8 0 0 2}

set AT_R [as_shape asvat xAT]
set AT_D [lindex $AT_R 0]
puts "AS-ATSIGN occurrences of the at-sign device name:\
 [as_count $AT_D {sky130_fd_pr__pfet@01v8_lvt}]"
check {AS80 A VALUE WITH AN AT-SIGN IN IT IS NOT A VALUE XSCHEM CAN PASS DOWN,\
 issue 1227. The at-sign and the per-cent sign are the two marks XSCHEM itself\
 reads as "fill something in here later", and the netlister really does resolve\
 them again while it writes the device line. Measured before the fix:\
 modelp=pfet@01v8_lvt minted a cell called aswv__modelp_pfet_01v8_lvt -- the\
 very name a copy that typed the clean pfet_01v8_lvt gets -- while the deck\
 inside it named a device sky130_fd_pr__pfet@01v8_lvt that exists in no PDK,\
 under a note telling the designer the copy had been written for them. The\
 design walk two files away already refuses every at-sign value because it\
 cannot be resolved from a file; this is that same refusal in the half that\
 writes the deck. The copy calls the plain cell, the device is the one the\
 symbol supplies, and the designer is told} \
  [concat [lindex $AT_R 1] [list [as_count $AT_D {sky130_fd_pr__pfet@01v8_lvt}]]] \
  {aswv 1 sky130_fd_pr__pfet_01v8 0 0 1 1 0}

## THE OTHER DOOR AGAIN, and this time what it PUBLISHES rather than its yes or
## no. When the designer walks down into a copy, the level they are standing on
## carries the copy's settings, and the annotation surface resolves a device's
## model=@setting through them. That string has to be the one the deck was
## written from or the annotation asks the results file for a device under a
## name the simulator never used.
proc as_doorprop {sch inst} {
  catch {xschem clear force}
  if {[catch {xschem load $sch}]} { return LOADFAIL }
  set n -1
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[xschem getprop instance $i name] eq $inst} { set n $i ; break }
  }
  if {$n < 0} { return NOINST }
  catch {xschem unselect_all}
  catch {xschem select instance $n}
  if {[catch {xschem descend}]} { return NODESCEND }
  set g [xschem globals]
  set cur 0
  foreach ln [split $g "\n"] {
    if {[regexp {^currsch=(\d+)} $ln -> c]} { set cur $c }
  }
  set key "lcc\[[expr {$cur - 1}]\].prop_ptr="
  set out NOKEY
  set on 0
  foreach ln [split $g "\n"] {
    if {$on} {
      if {[regexp {^(lcc\[[0-9]+\]\.|previous_instance\[|sch_path\[|sch\[|modified=)} $ln]} { break }
      append out "\n" $ln
      continue
    }
    if {[string first $key $ln] == 0} {
      set on 1
      set out [string range $ln [string length $key] end]
    }
  }
  catch {xschem go_back}
  return $out
}
set DPR [as_doorprop [file join $AS asvmx.sch] xM]
puts "AS-DOORPROP the level the designer stands on publishes: |$DPR|"
check {AS81 THE SCHEMATIC SURFACE HAS TO BE READ THE SAME WAY THE DECK WAS\
 WRITTEN, issue 1227. Walking down into a copy records that copy's settings on\
 the level the designer is now standing on, and the annotation surface resolves\
 a transistor's model=@setting through them to work out what to call it in the\
 results file. The netlister now keeps a refused setting out of the cell body\
 it writes; if this level still carried it, the schematic would ask for numbers\
 measured for a device the simulator never had -- which is the case the\
 annotation code names in its own words. RULING D5-1. So the setting XSCHEM\
 could not use is gone from here too, and the one it could use is still here} \
  [list [expr {$DPR eq {NOKEY} || $DPR eq {NOINST} || $DPR eq {LOADFAIL} ||
               $DPR eq {NODESCEND} ? 0 : 1}] \
        [as_word $DPR modeln] \
        [as_word $DPR modelp]] \
  {1 1 0}

## ISSUE 1223. The sentence quotes the value THE DESIGNER TYPED. Reading the
## symbol's template to answer "is this already the default" overwrites the one
## buffer the property reader hands every answer back in, so the value has to be
## read again afterwards. Delete that re-read and the warning quotes the
## template's value back at the designer as though they had typed it -- and
## picks the wrong explanation to go with it.
## Read from the RUNNING TALLY every netlist in this file appends to, not from
## the info window, which by now holds the last sheet's run only.
set Q1 [as_uniq [as_for $::AS_ALL xPU]]
set Q2 [as_uniq [as_for $::AS_ALL xAT]]
set Q1S [expr {[llength $Q1] == 1 ? [expr {[string first "sets modelp=---," [lindex $Q1 0]] >= 0 ? 1 : 0}] : -1}]
set Q1T [expr {[llength $Q1] == 1 ? [expr {[string first "sets modelp=pfet_01v8," [lindex $Q1 0]] >= 0 ? 1 : 0}] : -1}]
set Q2S [expr {[llength $Q2] == 1 ? [expr {[string first "sets modelp=pfet@01v8_lvt," [lindex $Q2 0]] >= 0 ? 1 : 0}] : -1}]
puts "AS-QUOTED punctuation copy quotes its own value $Q1S ; quotes the\
 template's instead $Q1T ; at-sign copy quotes its own value $Q2S"
check {AS82 THE WARNING QUOTES THE VALUE THE DESIGNER TYPED, NOT THE ONE THE\
 SYMBOL SUPPLIES, issue 1223. Every answer the property reader gives comes back\
 in one shared buffer, so asking the symbol's template whether the copy simply\
 re-typed the default overwrites the copy's own value in place. The code reads\
 it again afterwards for that reason; delete that one line and every suite\
 stays green while a designer who typed a single space is told "sets\
 modelp=pfet_01v8 ... but the value you typed has no letters or digits in it"\
 -- two halves that are both wrong and that contradict each other in one\
 breath. RULING D5-1 on the sentence the designer reads. No other row anywhere\
 asserts the printed VALUE for a setting the cell's own drawing reads} \
  [list $Q1S $Q1T $Q2S] {1 0 1}

## ISSUE 1226. The four explanations of WHY a value cannot be used are four
## different sentences, and until this row nothing read any of them.
## The explanation clause out of every line about one copy -- a copy name can
## appear on more than one fixture sheet, and only the shape this row is about
## carries the clause at all, so the answer is the DISTINCT clauses found and
## there has to be exactly one.
proc as_fault {lines} {
  set o {}
  foreach l $lines {
    if {[regexp {the value you typed (.*?), and XSCHEM can only} $l -> f]} {
      if {[lsearch -exact $o $f] < 0} { lappend o $f }
    }
  }
  if {[llength $o] != 1} { return "NOTONE:[llength $o]" }
  return [lindex $o 0]
}
set F_SP [as_fault [as_uniq [as_for $::AS_ALL xS]]]
set F_TR [as_fault [as_uniq [as_for $::AS_ALL xD]]]
set F_PN [as_fault [as_uniq [as_for $::AS_ALL xPU]]]
set F_AT [as_fault [as_uniq [as_for $::AS_ALL xAT]]]
puts "AS-FAULT blank -> |$F_SP| ; trailing space -> |$F_TR| ; punctuation ->\
 |$F_PN| ; at-sign -> |$F_AT|"
check {AS83 FOUR DIFFERENT REASONS, FOUR DIFFERENT SENTENCES, issue 1226. A\
 value can be unusable in four ways and the designer is told which one it was.\
 Nothing anywhere read those words: collapsing all four to one string leaves\
 every suite green while a designer who typed "---" is told their value is\
 nothing but blank space, on the one surface the plain-English ruling governs.\
 Each shape has to get its own explanation, and the four have to be four} \
  [list [expr {[string first {blank space} $F_SP] >= 0 ? 1 : 0}] \
        [expr {[string first {space, a tab or a line break} $F_TR] >= 0 ? 1 : 0}] \
        [expr {[string first {letters or digits} $F_PN] >= 0 ? 1 : 0}] \
        [expr {[string first {instruction to fill something in later} $F_AT] >= 0 ? 1 : 0}] \
        [llength [as_uniq [list $F_SP $F_TR $F_PN $F_AT]]]] \
  {1 1 1 1 4}

## ISSUE 1225. THE BRANCH OF THE DESIGN WALK FOR A CELL WHOSE DRAWING IS NOT
## SITTING NEXT TO ITS SYMBOL -- which is how vendor PDK libraries are laid out.
## The walk's ordinary branch looks for a drawing of the same name beside the
## symbol; when there is none, it has to open the symbol and read the drawing
## name out of it. Every fixture above is written the ordinary way, so that
## whole branch was run by nothing and grepped by nothing.
as_wr [file join $AS assb.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
schematic=as/assbdraw
spectre_ignore=true
vhdl_ignore=true
verilog_ignore=true
tedax_ignore=true
template="name=x1"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}

if {$DP_OK} {
  as_wr [file join $AS assbdraw.sch] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
C \{devices/iopin\} 200 -300 0 1 \{name=p1 lab=A\}
C \{as/aswv.sym\} 400 -300 0 0 \{name=xW W_P=0.5 modelp=pfet_01v8_hvt schematic=$DP_NAME\}"
  as_sheet ashsb "C \{as/aswv.sym\} 120 0 0 0 \{name=xY W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/assb.sym\} 320 0 0 0 \{name=xMID\}"
}
set SB_D [expr {$DP_OK ? [as_netlist [file join $AS ashsb.sch]] : {}}]
set SB_W [expr {$DP_OK ? [as_bodyfor_in $SB_D assb xW] : {NOSTEP1}}]
set SB_Y [expr {$DP_OK ? [as_bodyfor $SB_D xY] : {NOSTEP1}}]
puts "AS-SYMDRAW xY -> $SB_Y ; xW one level down -> $SB_W ; bodies\
 [expr {$DP_OK ? [as_bodies $SB_D] : {}}] ; low-Vt\
 [as_word $SB_D sky130_fd_pr__pfet_01v8_lvt] ; high-Vt\
 [as_word $SB_D sky130_fd_pr__pfet_01v8_hvt]"
check {AS84 THE SAME PROTECTION, FOR A CELL WHOSE DRAWING IS NOT BESIDE ITS\
 SYMBOL, issue 1225. Row AS72 gives the design walk a middle cell laid out the\
 easy way -- a drawing of the same name next to the symbol. Vendor PDK\
 libraries are not laid out that way: the symbol names the drawing it is built\
 from, and the walk has a whole second branch that opens the symbol to find it.\
 Nothing ran that branch and nothing read it, so it could be emptied outright\
 with every suite still green -- on the one path that decides whether a cell\
 name a designer typed one level down is noticed at all. Same measurement as\
 AS72: both devices in the deck, the copy that typed the name keeps it, the\
 invented one steps aside} \
  [list [expr {$DP_OK ? [as_word $SB_D sky130_fd_pr__pfet_01v8_lvt] : -1}] \
        [expr {$DP_OK ? [as_word $SB_D sky130_fd_pr__pfet_01v8_hvt] : -1}] \
        $SB_W \
        [expr {$DP_OK && $SB_W ne $SB_Y && $SB_W ne {NOCALL} &&
               $SB_W ne {NOBODY} ? 1 : 0}]] \
  [list 1 1 $DP_NAME 1]

## ISSUE 1220, THE RECORDED RESIDUAL OF 1215 AND 1212, AND IT HAD NO ROW.
as_wr [file join $AS aswsam.sym] {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
spectre_ignore=true
vhdl_ignore=true
verilog_ignore=true
tedax_ignore=true
template="name=x1"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}}
if {$DP_OK} {
  as_wr [file join $AS aswsam.sch] "v \{xschem version=3.4.4 file_version=1.2\}
G \{\}
K \{\}
V \{\}
S \{\}
E \{\}
C \{devices/iopin\} 200 -300 0 1 \{name=p1 lab=A\}
C \{as/aswv.sym\} 400 -300 0 0 \{name=xW W_P=0.5 modelp=pfet_01v8_lvt schematic=$DP_NAME\}"
  as_sheet ashsam "C \{as/aswv.sym\} 120 0 0 0 \{name=xY W_P=0.5 modelp=pfet_01v8_lvt\}
C \{as/aswsam.sym\} 320 0 0 0 \{name=xMID\}"
}
set SM_D [expr {$DP_OK ? [as_netlist [file join $AS ashsam.sch]] : {}}]
set SM_W [expr {$DP_OK ? [as_bodyfor_in $SM_D aswsam xW] : {NOSTEP1}}]
set SM_Y [expr {$DP_OK ? [as_bodyfor $SM_D xY] : {NOSTEP1}}]
set SM_CL [as_for [as_lost] xW]
puts "AS-SAMESET xY -> $SM_Y ; xW one level down -> $SM_W ; bodies\
 [expr {$DP_OK ? [as_bodies $SM_D] : {}}] ; low-Vt\
 [as_word $SM_D sky130_fd_pr__pfet_01v8_lvt] ; anything said about xW\
 [llength $SM_CL]"
check {AS85 THE KNOWN RESIDUAL OF ISSUE 1215, PINNED SO IT CANNOT GET WORSE,\
 issue 1220. The note a designer reads ends "Any other copy of this cell on\
 this design that asks for the same settings shares that one". On ONE sheet\
 that is now true -- row AS70. Across sheets it is not, and it cannot be made\
 true the same way: the copy one level down is not loaded when the name is\
 minted, and the design walk that finds its hand-typed name reads the file as\
 TEXT, so it cannot work out whether that copy asked for the same settings or\
 different ones. It has to assume different, because assuming the same is how a\
 setting disappears. WHAT THAT COSTS THE DESIGNER IS A WASTED CELL BODY AND\
 NOTHING ELSE, and that is what this row holds: both copies are built with the\
 device they asked for, nothing is silently shared, and the designer is not\
 accused of a clash that is not one. The wasted body is recorded here as a\
 measurement so that a later hand that closes 1220 sees this row and updates\
 it, rather than closing it by accident} \
  [list [expr {$DP_OK ? [as_word $SM_D sky130_fd_pr__pfet_01v8_lvt] : -1}] \
        [expr {$DP_OK ? [as_word $SM_D sky130_fd_pr__pfet_01v8_hvt] : -1}] \
        $SM_W \
        [expr {$DP_OK && $SM_W ne $SM_Y ? 1 : 0}] \
        [llength $SM_CL]] \
  [list 1 0 $DP_NAME 1 0]


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
