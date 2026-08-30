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
#   Warning: on this sheet, instance <inst> (a <symbol>) sets <prop>=<value>,
#   but <symbol> never reads <prop> when the netlist is written, so that
#   setting did not reach the simulator and changed nothing. Check the spelling
#   against the settings this cell does read, or take it off. If you meant to
#   change only this one copy of the cell, give <inst> a schematic= attribute of
#   its own as well, and the cell will be written out separately with your
#   setting in it.
#
# and it is minted in exactly one place, src/token.c.
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
check {PD4 STRUCTURAL the shipped sky130 helper file asks what model a device\
 uses in exactly ONE place, and that place goes through the shared resolver --\
 it asked in two places, and both were wrong the same way} \
  [list [u_count $PD_SKY {translate $instname @model}] \
        [expr {[u_count $PD_SKY {model_netlist}] >= 3 ? 1 : 0}]] \
  {1 1}

set PD_IHP [u_nocomment_tcl [u_slurp [file join $repo ihp-sg13g2 sg13g2_procs.tcl]]]
check {PD5 STRUCTURAL the three matching places in the IHP helper file are\
 deliberately left alone and recorded as such in issue 0976, pinned here so a\
 later change to them is a decision somebody took and not a drift} \
  [u_count $PD_IHP {translate $instname @model}] 3

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
