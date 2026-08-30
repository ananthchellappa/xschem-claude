# tests/headless/test_ase_optier_0963.tcl -- ISSUE 0963: A RUN NEVER SAYS HOW IT
# ASKED FOR DEVICE NUMBERS, AND THERE IS NO WAY TO CHOOSE.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# They tick Outputs > Save All > save device operating-point parameters on
# their own bandgap bench and press Run. The deck grows by 468 lines -- six
# separate requests for each of 78 transistors -- and the results file grows
# by 74.9 MB, because those same 468 device numbers are also recorded at every
# one of the transient's 20,505 time points, where nothing reads them. The run
# takes 4.08 s longer than the identical deck without them. Nothing anywhere
# tells the user which of the three possible ways of asking was used, or why,
# or that a shorter way exists, or that their simulator was asked what it can
# do and the answer was then thrown away.
#
# ============================================================================
# THE BEFORE-STATE, MEASURED AT HEAD c42c5c9e ON THE USER'S OWN BENCH
# ============================================================================
#   sky130A/xschem_libs/sky130_tests_ase/tb_bandgap, op AND tran both enabled:
#     468 .save cards, 78 distinct devices, 6 cards per device
#     deck 328 -> 796 lines, 14,390 -> 37,936 bytes
#     ONE sentence to the user: "ASE: 468 device OP save card(s) added to the deck."
#     wall clock 20.21 s, results file 144,455,860 bytes
#     the identical deck with only the 468 cards removed: 16.13 s, 69,595,016 bytes
#     the Transient Analysis plot carries 456 device-parameter vectors at
#     20,505 points -- issue 0928 section 7, live
#   ase::sim_capabilities ngspice answers
#     known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
#   and that answer has exactly ONE production reader, ase::cap_report, which
#   warns about three unrelated things and never touches the deck.
#   grep over src for a tier selection or an override: nothing exists.
#
# ============================================================================
# THREE MEASURED FACTS THIS FILE IS BUILT ON -- read them before editing a row
# ============================================================================
#  1. NAMING A DEVICE ON THE OPERATING-POINT WRITE LINE IS ALL-OR-NOTHING.
#     Two of the 78 device names this tree emits for tb_bandgap cannot be
#     resolved by ngspice, and ONE unresolvable name aborts the WHOLE write:
#     "Error during 'write': no writable vector found.", no results file at
#     all, exit 0. The same two names cost the per-device form 12 blank rows
#     out of 468 and it keeps the other 456. That is why the short form is
#     built, exercised and reachable through the override, and chosen for
#     nobody automatically.
#  2. THE WRITE LINE HOLDS AT MOST 998 DEVICE NAMES. 999 prints
#     "write: too many args.", writes no file, and exits 0. The save command
#     holds 999. A SPLIT save accumulates correctly; a split write does not --
#     it produces TWO plots both called "Operating Point" and half the devices
#     become silently unreadable.
#  3. NAMING A BARE DEVICE ON A MULTI-POINT WRITE IS SILENTLY WRONG. Under
#     .tran every device vector arrives dims=1 with ONE non-zero sample parked
#     at index 0 holding the end-of-run value and 0.0 everywhere else, no
#     warning, well-formed file. It round-trips exactly under .op only.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE
# ============================================================================
# * NO PIXELS. No dialog, no menu, no waveform viewer. Which plot the viewer
#   opens on after the analysis order changes is a look debt, not a row here.
# * NO WALL-CLOCK ASSERTION. Section ACC PRINTS deck size, wall clock and
#   results size; a timing assert flakes and would say nothing true.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_optier_0963.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_optier_0963.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations, cwd-independent ---------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch optier0963]
set ASETCL [file join $repo src ase.tcl]
set OPTCL  [file join $repo src op_annot.tcl]

# --- the answer discipline ---------------------------------------------------
# Borrowed verbatim from tests/headless/test_ase_simcaps_0948.tcl. An absent
# proc answers NOPROC and a raise answers RAISED:<text>, so
# "invalid command name ase::op_save_tier" can never satisfy a row that
# expected an empty string or a c.
proc o_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc o_wr {path body {mode 0644}} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
  catch {file attributes $path -permissions $mode}
}
proc o_slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## Tcl comments dropped, so a sentence quoted in a comment cannot satisfy a row
## about where the sentence is MINTED.
proc o_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc o_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
proc o_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [o_nocomment $b]
}

# ============================================================================
# THE STAND-IN SIMULATORS
# ============================================================================
# A few-line /bin/sh script that reads the deck it was handed, takes the
# results path off the deck's own `write` line, copies a canned results file
# there and exits. Three arms, chosen by what the deck asks for, because
# section A needs a stand-in that answers the CAPABILITY probe's blanket deck
# AND the real ASE deck a blanket tier renders -- and those two decks look
# nothing alike. The probe's blanket deck carries the wildcard save card
# `[*]`; a blanket-tier ASE deck names no device at all and is recognised by
# the device-less request `.options saveopparams` instead. The existing
# stand-in in test_ase_simcaps_0948.tcl keys only off `[*]`, which is why this
# file cannot reuse it.
set OPHDR "Plotname: Operating Point\nFlags: real\nNo. Variables: 3\nNo. Points: 1\nVariables:\n\t0\ti(@m.xo1.xi1.m1\[id\])\tcurrent\n\t1\t@m.xo1.xi1.m1\[gm\]\tadmittance\n\t2\tv(@m.xo1.xi1.m1\[vdsat\])\tvoltage\nValues:\n 0\t1.2500002e-05\n\t5e-05\n\t5.000000e-01\n"
set TRHDR "Plotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n\t0\ttime\ttime\n\t1\tv(dd)\tvoltage\nValues:\n 0\t0.000000e+00\n\t1.800000e+00\n 1\t1.000000e-09\n\t1.800000e+00\n 2\t2.000000e-09\n\t1.800000e+00\n"
set TITLE "Title: * ase tier stand-in\nDate: Sat Aug 30 00:00:00  2026\n"
set CONSTHDR "Title: Constant values\nDate: Sat Aug 30 00:00:00  2026\nPlotname: constants\nFlags: complex\nNo. Variables: 2\nNo. Points: 1\nVariables:\n\t0\tyes\tnotype\n\t1\tpi\tnotype\nValues:\n 0\t1.000000e+00,0.000000e+00\n\t3.141593e+00,0.000000e+00\n"

set RAW_BOTH  [file join $scratch raw_both.raw]
set RAW_OP    [file join $scratch raw_op.raw]
set RAW_CONST [file join $scratch raw_const.raw]
o_wr $RAW_BOTH  "$TITLE$OPHDR$TITLE$TRHDR"
o_wr $RAW_OP    "$TITLE$OPHDR"
o_wr $RAW_CONST "$CONSTHDR"

# @BLANKET@ answers the probe's wildcard deck; @SAVEOPP@ answers a deck that
# carries the device-less blanket request; @NORMAL@ answers everything else.
set STUBTPL {#!/bin/sh
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
if [ -z "$deck" ]; then exit 0; fi
out=`grep -E '^[ 	]*write[ 	]' "$deck" | head -1 | sed -e 's/^[ 	]*write[ 	][ 	]*//' -e 's/[ 	]*$//'`
src=@NORMAL@
if grep -q '\[\*\]' "$deck"; then src=@BLANKET@; fi
if grep -q 'saveopparams' "$deck"; then src=@SAVEOPP@; fi
if [ -n "$out" ] && [ "$src" != NONE ] && [ -f "$src" ]; then cat "$src" > "$out"; fi
exit 0
}
proc o_stub {path normal blanket saveopp} {
  global STUBTPL
  o_wr $path [string map [list @NORMAL@ $normal @BLANKET@ $blanket \
                               @SAVEOPP@ $saveopp] $STUBTPL] 0755
  return $path
}
set BIN [file join $scratch bin]
file mkdir $BIN
## The plain stand-in: two plots on an ordinary deck, a constants-only file on
## either blanket question. Its measured capability answer is therefore
## appendwrite 1, hier_op_names 1, blanket_op_save 0 -- the local ngspice's own
## shape, with no ngspice needed.
set S_PLAIN [o_stub [file join $BIN sim_plain] $RAW_BOTH $RAW_CONST $RAW_CONST]
## The blanket stand-in: it CLAIMS the blanket capability by answering the
## probe's wildcard deck with a real Operating Point plot carrying the device
## vectors, and it answers a device-less blanket ASE deck the same way. This is
# the only reason tier A can be exercised at all on this box: no released
## ngspice answers yes.
set S_BLANKET [o_stub [file join $BIN sim_blanket] $RAW_BOTH $RAW_OP $RAW_OP]

# ============================================================================
# PRIMING WHAT THE SIMULATOR CAN DO, WITHOUT RUNNING ONE
# ============================================================================
# ase::op_save_tier reads ase::sim_capabilities, which serves a remembered
# answer whenever the file it was measured from has not changed. So a row can
# state the capability answer outright -- point the tree at a program that
# certainly exists, then write the answer into the remembered store with a
# stamp taken from that same file. No program is started.
proc o_useprog {path} {
  catch {ase::sim_caps_clear}
  catch {ase::sim_clear}
  o_ans ase::sim_register optier $path
  o_ans ase::sim_select optier
  set s [o_ans ase::sim_status ngspice]
  if {[catch {dict get $s resolved} r]} { return {} }
  return $r
}
proc o_prime {caps} {
  global S_PLAIN
  set r [o_useprog $S_PLAIN]
  if {$r eq {}} { return NORESOLVE }
  if {[catch {ase::cap_stamp $r} st]} { return "RAISED:$st" }
  set ::ase::sim_caps [dict create $r [list stamp $st caps $caps]]
  return $r
}
proc o_unprime {} { catch {ase::sim_caps_clear} ; catch {ase::sim_clear} }

# ============================================================================
# THE SURFACE UNDER TEST
# ============================================================================
## tier and reason as one two-element list, so a row that drops the reason
## cannot pass. NOKEY-<key> when the answer is a dict without it.
proc o_tr {state} {
  set d [o_ans ase::op_save_tier $state]
  if {$d eq {NOPROC} || [string match RAISED:* $d]} { return $d }
  if {[catch {dict exists $d tier} h]} { return "NOTADICT:$d" }
  set out {}
  foreach k {tier reason} {
    if {[dict exists $d $k]} { lappend out [dict get $d $k] } else { lappend out "NOKEY-$k" }
  }
  return $out
}
proc o_force {t} { return [o_ans ase::op_tier_force_set $t] }

# ============================================================================
# THE STATES AND THE CARD BLOCKS
# ============================================================================
set AN_OP   {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
set AN_BOTH {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 5n}}
set AN_TRAN {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 5n}}
proc o_state {an {gate {}} {outs {}}} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create lib zzlib cell zzcell view schematic]
  dict set st rundir [file join $scratch orun]
  dict set st analyses $an
  dict set st save_op_params $gate
  dict set st outputs $outs
  return $st
}
## A synthetic captured block, in exactly the shape op_annot::save_cards
## produces: the load-bearing `.save all` leader, then one BARE card per
## device per parameter. Section E10 and E6/E7 need device counts no committed
## bench reaches, so they must be synthetic or the rows would be vacuous.
proc o_block {ndev {params {id gm gds vgs vth vds}}} {
  set b ".save all"
  for {set i 1} {$i <= $ndev} {incr i} {
    foreach p $params { append b "\n.save @m.xz${i}.mzmod\[$p\]" }
  }
  return "$b\n"
}
proc o_blockdevs {ndev} {
  set d {}
  for {set i 1} {$i <= $ndev} {incr i} { lappend d "@m.xz${i}.mzmod" }
  return $d
}
set NL "** sch_path: /zz.sch\n**.subckt zzcell\nV1 a 0 1\n**.ends\n.end\n"

# ============================================================================
# READING A RENDERED DECK
# ============================================================================
set RENDER [o_ans ase::backend_hook ngspice render_deck]
proc o_render {state nl} {
  global RENDER
  if {$RENDER eq {NOPROC} || [string match RAISED:* $RENDER]} { return NOPROC }
  if {[catch {$RENDER $state $nl} d]} { return "RAISED:$d" }
  return $d
}
## Everything above `.control`, and everything between `.control` and `.endc`.
proc o_decklevel {deck} {
  set out {}
  foreach l [split $deck "\n"] {
    if {[string trim $l] eq {.control}} { break }
    lappend out $l
  }
  return $out
}
proc o_control {deck} {
  set out {} ; set inb 0
  foreach l [split $deck "\n"] {
    set t [string trim $l]
    if {$t eq {.control}} { set inb 1 ; continue }
    if {$t eq {.endc}} { break }
    if {$inb} { lappend out $l }
  }
  return $out
}
## The `.save @dev[param]` dot-cards sitting at DECK level, bare.
proc o_deckcards {deck} {
  set c {}
  foreach l [o_decklevel $deck] {
    if {[regexp {^\.save\s+(@\S+)$} $l -> nm]} { lappend c $nm }
  }
  return $c
}
## The `save ...` command lines inside `.control`, whole.
proc o_ctlsaves {deck} {
  set s {}
  foreach l [o_control $deck] {
    if {[regexp {^\s*save\s} $l]} { lappend s [string trim $l] }
  }
  return $s
}
## The `write ...` command lines inside `.control`, whole, in order.
proc o_writes {deck} {
  set w {}
  foreach l [o_control $deck] {
    if {[regexp {^\s*write\s} $l]} { lappend w [string trim $l] }
  }
  return $w
}
## The analysis commands inside `.control`, in the order they will run.
proc o_analines {deck} {
  set a {}
  foreach l [o_control $deck] {
    set t [string trim $l]
    if {[regexp {^(op|dc|ac|tran)(\s|$)} $t -> k]} { lappend a $k }
  }
  return $a
}
## Every `@...` token on one line -- what the write line names.
proc o_ats {line} {
  set n {}
  foreach w [split $line] {
    if {[string index $w 0] eq {@}} { lappend n $w }
  }
  return $n
}
## Which write lines carry device names at all, as a list of 0/1 in deck order.
proc o_writeats {deck} {
  set r {}
  foreach w [o_writes $deck] { lappend r [expr {[llength [o_ats $w]] ? 1 : 0}] }
  return $r
}

## The character offset at which <text> READS capability <key> out of the
## measured answer -- `$caps <key>`, which is the spelling of both
## `dict exists $caps <key>` and `dict get $caps <key>` -- or -1.
##
## ⚠ IT MATCHES THE READ, NOT THE BARE WORD, AND THAT IS THE WHOLE ROW. An
## earlier version of row T11 looked for the whole word `known` anywhere in the
## body. The proc's OWN not-measured fallback is `set caps [dict create known
## 0]`, which sits above every capability read and contains that word, so T11
## passed unconditionally: the S4 sabotage pass moved the blanket test ABOVE the
## known test -- precisely the optimistic guess T11's text forbids -- and not one
## check in twelve suites went red. `$caps known` appears only where the guard
## actually asks the question.
proc o_capidx {text key} { return [string first "\$caps $key" $text] }

if {[catch {

# ============================================================================
# T. WHICH TIER A RUN USES, AND WHY -- no simulator is started for any of this
# ============================================================================
# The capability answer is stated outright, so every arm is exercised on every
# box whatever ngspice happens to be installed. That is not a convenience: the
# blanket arm is COLD CODE by construction on this box, and cold code behind a
# green suite is exactly what shipped issues 0928 and 0929.

set CAPS_UNKNOWN [dict create known 0]
set CAPS_EMPTY   [dict create]
set CAPS_BLANKET [dict create known 1 usable 1 appendwrite 1 hier_op_names 1 blanket_op_save 1]
set CAPS_WRITE   [dict create known 1 usable 1 appendwrite 1 hier_op_names 1 blanket_op_save 0]
set CAPS_NOHIER  [dict create known 1 usable 1 appendwrite 1 hier_op_names 0 blanket_op_save 0]
set CAPS_NOAPP   [dict create known 1 usable 1 appendwrite 0 hier_op_names 1 blanket_op_save 0]

o_force {}
o_prime $CAPS_UNKNOWN
check {T1 a simulator whose capability is NOT KNOWN lands on the per-device form,\
 and says so by name -- never an optimistic guess} \
  [o_tr [o_state $AN_OP]] {c unknown}

o_prime $CAPS_EMPTY
check {T2 a capability answer carrying NO keys at all is treated as not known,\
 and does not raise -- absent is not the same as 0} \
  [o_tr [o_state $AN_OP]] {c unknown}

o_prime $CAPS_BLANKET
check {T3 a simulator that can save every device's operating-point numbers in\
 one request gets the blanket form} \
  [o_tr [o_state $AN_OP]] {a blanket}

o_prime $CAPS_WRITE
check {T4 a simulator that CAN take the one-line short form is still given the\
 per-device form, because one unresolvable device name throws the whole\
 operating point away -- and the reason token says which guard did it} \
  [o_tr [o_state $AN_OP]] {c unsafe}

o_prime $CAPS_NOHIER
check {T5 a simulator that cannot spell a device inside a subcircuit gets the\
 per-device form} [o_tr [o_state $AN_OP]] {c nocap}

o_prime $CAPS_NOAPP
check {T6 a simulator that keeps only the last analysis gets the per-device form} \
  [o_tr [o_state $AN_OP]] {c nocap}

# --- the override, which is the ONLY way either fallback arm is reachable ----
o_prime $CAPS_UNKNOWN
o_force a
check {T7 the blanket form can be forced even against a simulator nothing is\
 known about} [o_tr [o_state $AN_OP]] {a forced}

o_prime $CAPS_WRITE
o_force b
check {T8 the one-line short form can be forced regardless of what the probe\
 said -- the item's non-negotiable, and the only door the suites have} \
  [o_tr [o_state $AN_OP]] {b forced}

o_prime $CAPS_BLANKET
o_force c
check {T9 the per-device form can be forced over a simulator that offered the\
 blanket form} [o_tr [o_state $AN_OP]] {c forced}

o_force {}
check {T10 clearing the override gives the probe's own answer back -- the\
 override is not a latch} [o_tr [o_state $AN_OP]] {a blanket}

# --- T11/T12 STRUCTURAL: two guards whose OUTPUT no behavioural row can tell
# apart from another guard's
set TB [o_body ase::op_save_tier]
if {$TB eq {NOPROC} || [string match RAISED:* $TB]} {
  set T11 $TB ; set T12 $TB
} else {
  set ik [o_capidx $TB known]
  set ia [o_capidx $TB appendwrite]
  set ih [o_capidx $TB hier_op_names]
  set ib [o_capidx $TB blanket_op_save]
  if {$ik < 0} {
    set T11 NO-known-TEST
  } elseif {$ia >= 0 && $ia < $ik} {
    set T11 appendwrite-READ-FIRST
  } elseif {$ih >= 0 && $ih < $ik} {
    set T11 hier_op_names-READ-FIRST
  } elseif {$ib >= 0 && $ib < $ik} {
    set T11 blanket_op_save-READ-FIRST
  } else {
    set T11 known-FIRST
  }
  set T12 [list [expr {$ia >= 0 ? 1 : 0}] [expr {$ih >= 0 ? 1 : 0}]]
}
check {T11 STRUCTURAL: the tier decision asks whether anything is KNOWN about\
 the simulator BEFORE it reads any single capability -- a missing key must\
 never be read as a no} $T11 known-FIRST
check {T12 STRUCTURAL: the demotion guard really exists -- it tests both the\
 add-each-analysis capability and the subcircuit-device-name capability. It\
 returns the same tier as the no-capability guard, so nothing behavioural can\
 see it at all} $T12 {1 1}

# --- T13: the same ordering property, BEHAVIOURALLY. T11 reads the source;
# this one drives the proc. Between them, moving the blanket test above the
# known test cannot be done quietly -- the sabotage pass did exactly that and
# nothing in twelve suites noticed.
o_force {}
o_prime [dict create known 0 usable 1 appendwrite 1 hier_op_names 1 blanket_op_save 1]
check {T13 an answer that says nothing was measured is believed even when the\
 rest of it looks like a yes -- a leftover capability beside `known 0` must\
 never be read as permission to use the short forms} \
  [o_tr [o_state $AN_OP]] {c unknown}

# --- T14: the probe blows up. ase::sim_capabilities RE-RAISES a backend
# probe's own error on purpose (issues 0949-0954) and this caller is on the
# deck-rendering path of an OPT-IN annotation extra, so a raise here would break
# Netlist and Run for a user who only ticked a box about device numbers. Every
# other row in this file states the capability answer outright and never starts
# the probe, so without this row the catch is a guard nothing can see.
set T14 NOPROC
if {[info commands ::ase::sim_capabilities] ne {}} {
  o_force {}
  o_prime $CAPS_BLANKET
  rename ::ase::sim_capabilities ::o_saved_caps
  proc ::ase::sim_capabilities {args} { return -code error "zz probe blew up" }
  set T14 [o_tr [o_state $AN_OP]]
  rename ::ase::sim_capabilities {}
  rename ::o_saved_caps ::ase::sim_capabilities
}
check {T14 a capability probe that blows up leaves the run standing: the form\
 that always works is used, the reason says nothing was measured, and pressing\
 Run still works} $T14 {c unknown}

# ============================================================================
# E. WHAT THE DECK ACTUALLY CARRIES
# ============================================================================
# The two gates that decide WHETHER device numbers are asked for at all -- the
# user's tick and an enabled operating point -- are not under test here and do
# not move. The tier decides only the SHAPE of the request.
#
# The captured card block is primed directly, which is the seam ase::netlist
# itself uses. Sections E6, E7 and E10 need device counts no committed bench
# reaches -- 998, 999 and 1000 -- so a bench-driven row could not see the
# measured bounds at all and would be vacuous.

set BLK5   [o_block 5]
set BLK100 [o_block 100]
set BLK0   ""
set DEV5   [o_blockdevs 5]

o_prime $CAPS_BLANKET
o_force a
ase::op_cards_put $NL $BLK5
set DA [o_render [o_state $AN_OP] $NL]
set E1 NOPROC
if {$DA ne {NOPROC} && ![string match RAISED:* $DA]} {
  set nats 0
  foreach l [split $DA "\n"] { if {[string first {@} $l] >= 0} { incr nats } }
  set nsaveall 0
  foreach l [o_decklevel $DA] { if {[string trim $l] eq {.save all}} { incr nsaveall } }
  set E1 [list [regexp -all -line {^\.options saveopparams$} $DA] $nsaveall $nats]
}
check {E1 the blanket form asks for every device's operating-point numbers in\
 one request and NAMES NO DEVICE ANYWHERE IN THE DECK} $E1 {1 1 0}

ase::op_cards_put $NL $BLK100
set DA100 [o_render [o_state $AN_OP] $NL]
ase::op_cards_put $NL $BLK0
set DA0 [o_render [o_state $AN_OP] $NL]
set E2 NOPROC
if {$DA100 ne {NOPROC} && ![string match RAISED:* $DA100] &&
    $DA0 ne {NOPROC} && ![string match RAISED:* $DA0]} {
  set gr [expr {[llength [split $DA100 "\n"]] - [llength [split $DA0 "\n"]]}]
  set E2 [expr {($gr >= 0 && $gr <= 3) ? {within-3} : "grew-by-$gr-lines"}]
}
check {E2 the blanket form costs the same whether the bench has 100 devices in\
 it or none -- that is the whole point of it} $E2 within-3

# --- the one-line short form, reachable only through the override -----------
o_prime $CAPS_WRITE
o_force b
ase::op_cards_put $NL $BLK5
set DB [o_render [o_state $AN_OP] $NL]
set E3 NOPROC ; set E4 NOPROC
if {$DB ne {NOPROC} && ![string match RAISED:* $DB]} {
  set ws [o_writes $DB]
  set nm {}
  if {[llength $ws]} { set nm [o_ats [lindex $ws 0]] }
  set withparam 0
  foreach n $nm { if {[string first {[} $n] >= 0} { incr withparam } }
  set E3 [list [llength [o_deckcards $DB]] [llength $ws] [llength $nm] $withparam]
  set E4 [list $nm [o_ans ase::op_cards_devices $BLK5]]
}
check {E3 the short form drops all 30 per-device requests and names each of the\
 5 devices ONCE on the operating-point write, with no parameter on any name} \
  $E3 {0 1 5 0}
check {E4 the names on that line are EXACTLY the devices of the captured block,\
 same order, none dropped and none repeated -- one name builder, two consumers} \
  $E4 [list $DEV5 $DEV5]

set DBB [o_render [o_state $AN_BOTH] $NL]
check {E5 TRAP 1 -- device names ride the OPERATING-POINT write and nothing\
 else. A bare device name on a transient write is silently wrong: every vector\
 comes back with one non-zero sample parked at index 0 and 0.0 everywhere else} \
  [expr {($DBB eq {NOPROC} || [string match RAISED:* $DBB]) ? $DBB : [o_writeats $DBB]}] \
  {1 0}

# --- TRAP 2, the measured line-length wall ----------------------------------
set BLK999 [o_block 999 {id}]
set BLK998 [o_block 998 {id}]
ase::op_cards_put $NL $BLK999
set ST999 [o_state $AN_OP]
set D999 [o_render $ST999 $NL]
set E6 NOPROC
if {$D999 ne {NOPROC} && ![string match RAISED:* $D999]} {
  set E6 [list [o_tr $ST999] [llength [o_deckcards $D999]] [o_writeats $D999]]
}
check {E6 TRAP 2 -- 999 devices will not fit on one write line, so the short\
 form is refused even when it was forced, and the per-device form is emitted\
 instead. Splitting is not an option: two write lines produce two plots BOTH\
 called Operating Point and half the devices become unreadable} \
  $E6 [list {c toomany} 999 {0}]

ase::op_cards_put $NL $BLK998
set ST998 [o_state $AN_OP]
set D998 [o_render $ST998 $NL]
set E7 NOPROC
if {$D998 ne {NOPROC} && ![string match RAISED:* $D998]} {
  set ws [o_writes $D998]
  set nm {}
  if {[llength $ws]} { set nm [o_ats [lindex $ws 0]] }
  set E7 [list [o_tr $ST998] [llength $ws] [llength $nm] [llength [o_deckcards $D998]]]
}
check {E7 the measured bound is 998 and not one fewer -- at 998 devices the\
 short form still stands. Without this row a refusal that simply switched the\
 whole short form off would satisfy E6} \
  $E7 [list {b forced} 1 998 0]

# --- the per-device form, which is what nearly every run gets ---------------
o_force {}
o_prime $CAPS_WRITE
ase::op_cards_put $NL $BLK5
set DC [o_render [o_state $AN_OP] $NL]
set E8 NOPROC
if {$DC ne {NOPROC} && ![string match RAISED:* $DC]} {
  set E8 [list [llength [o_deckcards $DC]] [llength [o_ctlsaves $DC]] [o_analines $DC]]
}
check {E8 an operating-point-only run is completely unchanged: 30 dot-cards\
 above the control block, nothing added inside it, the operating point first} \
  $E8 {30 0 op}

set DCB [o_render [o_state $AN_BOTH] $NL]
set E9 NOPROC ; set E11 NOPROC
if {$DCB ne {NOPROC} && ![string match RAISED:* $DCB]} {
  set cs [o_ctlsaves $DCB]
  set lead 0
  if {[llength $cs] && [string match {save all @*} [lindex $cs 0]]} { set lead 1 }
  set E9 [list [llength [o_deckcards $DCB]] [llength $cs] $lead [o_analines $DCB]]
  set wrapped 0 ; set bare 0
  foreach s $cs {
    foreach n [o_ats $s] { if {[string first {[} $n] >= 0} { incr bare } }
    if {[string first {i(@} $s] >= 0 || [string first {v(@} $s] >= 0} { incr wrapped }
  }
  set E11 [list $wrapped $bare]
}
check {E9 with a transient in the same run the device requests move INSIDE the\
 control block, immediately before an operating point that now runs LAST --\
 that is the 74.9 MB and the 4.08 s the user is paying today} \
  $E9 {0 1 1 {tran op}}
check {E11 the moved requests still spell the device bare, never wrapped in a\
 current or a voltage -- a wrapped request produces no vector and no complaint} \
  $E11 {0 30}

set BLK1000 [o_block 1000 {id}]
ase::op_cards_put $NL $BLK1000
set D1000 [o_render [o_state $AN_BOTH] $NL]
set E10 NOPROC
if {$D1000 ne {NOPROC} && ![string match RAISED:* $D1000]} {
  set cs [o_ctlsaves $D1000]
  set maxn 0 ; set nall 0 ; set all {}
  foreach s $cs {
    set n [o_ats $s]
    if {[llength $n] > $maxn} { set maxn [llength $n] }
    if {[regexp {^save\s+all(\s|$)} $s]} { incr nall }
    foreach x $n { lappend all $x }
  }
  set E10 [list $maxn $nall [llength $all] [llength [lsort -unique $all]]]
}
check {E10 a thousand devices do not fit on one line either, so the request is\
 split -- at most 999 names on any line, the save-everything word on the first\
 line only, and every device named exactly once across them} \
  $E10 {999 1 1000 1000}

# --- the control: with nothing to emit, nothing moves -----------------------
ase::op_cards_clear
set DZ1 [o_render [o_state $AN_OP 0] $NL]
set DZ2 [o_render [o_state $AN_BOTH 0] $NL]
set E12 NOPROC
if {$DZ1 ne {NOPROC} && ![string match RAISED:* $DZ1] &&
    $DZ2 ne {NOPROC} && ![string match RAISED:* $DZ2]} {
  set E12 [list [llength [o_deckcards $DZ1]] [llength [o_ctlsaves $DZ1]] [o_analines $DZ1] \
                [llength [o_deckcards $DZ2]] [llength [o_ctlsaves $DZ2]] [o_analines $DZ2]]
}
check {E12 with the tick off and nothing captured there is nothing to move, so\
 neither deck changes at all and the operating point still runs first} \
  $E12 {0 0 op 0 0 {op tran}}

# --- E13: only a request that names a PARAMETER is a device request ---------
# The captured block carries the save-everything leader and can carry a plain
# node request too. Neither names a device parameter, and a bare `@dev` handed
# on to the moved request line means something else entirely -- it asks for
# EVERY parameter of that device, which is the one-line short form's meaning and
# not the per-device form's. So the reader that pulls names back out of the
# block keeps only the ones that carry a parameter.
set BLKMIX ".save all\n.save @m.xz1.mzmod\n.save @m.xz1.mzmod\[id\]\n.save v(out)\n.save @m.xz2.mzmod\[gm\]\n"
check {E13 a request that names no parameter is not a device request, whatever\
 else the captured block happens to carry} \
  [list [o_ans ase::op_cards_names $BLKMIX] [o_ans ase::op_cards_devices $BLKMIX]] \
  [list [list {@m.xz1.mzmod[id]} {@m.xz2.mzmod[gm]}] {@m.xz1.mzmod @m.xz2.mzmod}]

# --- G-LEADER: the save-everything word must stay at deck level -------------
# MEASURED HAZARD. Move the block's save-everything leader inside the control
# block along with the device requests and a bench that saves named outputs
# loses every OTHER node voltage from its transient: the transient plot fell
# from 6 vectors to 2, time and the one named output, silently. Nothing else in
# this file can see that.
set OUTS {{expr v(out) save 1} {expr v(mid) save 1}}
ase::op_cards_put $NL $BLK5
set DL [o_render [o_state $AN_BOTH {} $OUTS] $NL]
set GL NOPROC
if {$DL ne {NOPROC} && ![string match RAISED:* $DL]} {
  set nsa 0 ; set nout 0
  foreach l [o_decklevel $DL] {
    if {[string trim $l] eq {.save all}} { incr nsa }
    if {[string trim $l] eq {.save v(out)}} { incr nout }
  }
  set GL [list $nsa $nout]
}
check {G-LEADER the save-everything word and the named outputs stay ABOVE the\
 control block even when the device requests move into it -- otherwise a bench\
 with named outputs loses every other node voltage from its transient} \
  $GL {1 1}

# ============================================================================
# P. THE PRINTED OUTPUTS STILL READ THE PLOT THEY ALWAYS READ (issue 0967)
# ============================================================================
# The Outputs pane has a Value column, and it is filled in after a run from the
# deck's `print` lines -- see ase::backend::ngspice::result_probe, which accepts
# a scalar `<expr> = <number>` line and nothing else. `print` reads whichever
# plot the simulator is standing in, and these lines have always sat after every
# analysis, so they read the LAST analysis.
#
# MEASURED CONSEQUENCE OF THE REORDER, on an op+tran bench with one saved
# output: with the device-numbers tick OFF the Value column was empty, because a
# transient print is a table the reader cannot parse; with it ON the very same
# bench answered 1.800000e+00, the DC operating point, and the run log held one
# scalar line where it had held a table. A number appearing beside an output row
# because of a checkbox about something else, unlabelled -- ruling D5-1's class.
#
# So the prints go with the analysis that is last in the CANONICAL order, and
# the reorder cannot move them. With nothing reordered the two are the same
# analysis and the deck renders byte for byte as it always did.
proc o_ctlshape {deck} {
  set out {}
  foreach l [o_control $deck] {
    set t [string trim $l]
    if {[regexp {^(op|dc|ac|tran)(\s|$)} $t -> k]} { lappend out $k ; continue }
    if {[regexp {^print(\s|$)} $t]} { lappend out print ; continue }
    if {[regexp {^save(\s|$)} $t]} { lappend out save ; continue }
  }
  return $out
}
proc o_prints {deck} {
  set out {}
  foreach l [o_control $deck] {
    set t [string trim $l]
    if {[regexp {^print(\s|$)} $t]} { lappend out $t }
  }
  return $out
}
set AN_NONE {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}

set DP1 [o_render [o_state $AN_BOTH {} $OUTS] $NL]
set P1 NOPROC
if {$DP1 ne {NOPROC} && ![string match RAISED:* $DP1]} {
  set P1 [list [o_ctlshape $DP1] [o_prints $DP1]]
}
check {P1 with the device requests moved and the operating point running last,\
 the outputs the user asked to see are still printed from the transient -- the\
 analysis they were printed from before anything moved} \
  $P1 [list {tran print print save op} {{print v(out)} {print v(mid)}}]

set DP2 [o_render [o_state $AN_BOTH 0 $OUTS] $NL]
set P2 NOPROC
if {$DP2 ne {NOPROC} && ![string match RAISED:* $DP2]} {
  set P2 [list [o_ctlshape $DP2] [o_prints $DP2]]
}
check {P2 the control: with the tick off nothing is reordered, so the printed\
 outputs sit exactly where they always have -- after the last analysis, which\
 is still the transient} \
  $P2 [list {op tran print print} {{print v(out)} {print v(mid)}}]

set DP3 [o_render [o_state $AN_OP {} $OUTS] $NL]
set DP4 [o_render [o_state $AN_NONE {} $OUTS] $NL]
set P3 NOPROC
if {$DP3 ne {NOPROC} && ![string match RAISED:* $DP3] &&
    $DP4 ne {NOPROC} && ![string match RAISED:* $DP4]} {
  set P3 [list [o_ctlshape $DP3] [o_ctlshape $DP4]]
}
check {P3 an operating-point-only run prints from the operating point, and a\
 run with no analysis at all still carries its print lines -- neither shape is\
 reordered, so neither moves} \
  $P3 {{op print print} {print print}}

# ============================================================================
# S. WHAT THE USER IS TOLD
# ============================================================================
# Today a run says exactly one thing about any of this -- how many requests
# were added -- and nothing at all about which of the three forms was used or
# why. Ruling D5-4: the sentence is minted in ONE place and rendered by
# callers. The plain-English ruling: 9th grade, say what happened AND what the
# user can do, no internal vocabulary and no name out of the code.

set TIERKINDS {op_tier_blanket op_tier_perdevice op_tier_writeline op_tier_forced}

## Every kind of sentence a run said, in order, filtered to the tier ones. The
## recorder is intercepted rather than the CIW, so a row can tell WHICH
## sentence was said and not merely that words appeared.
proc o_saykinds {script} {
  set ::o_kinds {}
  if {[info commands ::ase::sim_say] eq {}} { return NOPROC }
  rename ::ase::sim_say ::o_saved_say
  proc ::ase::sim_say {kind name path {extra {}} {tag error}} {
    lappend ::o_kinds $kind
    return [::o_saved_say $kind $name $path $extra $tag]
  }
  set rc [catch {uplevel 1 $script} r]
  rename ::ase::sim_say {}
  rename ::o_saved_say ::ase::sim_say
  if {$rc} { return "RAISED:$r" }
  set out {}
  foreach k $::o_kinds { if {[string match op_tier* $k]} { lappend out $k } }
  return $out
}
## One whole run, from a rendered deck to the program's exit code.
proc o_dorun {state nl} {
  set rd [ase::rundir $state]
  file mkdir $rd
  set nlf [file join $rd zzcell.spice]
  o_wr $nlf $nl
  if {[catch {ase::run_deck $state $nlf} id]} { return "RUNRAISED:$id" }
  if {[catch {ase::wait $id} rc]} { return "WAITRAISED:$rc" }
  return $rc
}

o_force {}
ase::op_cards_put $NL $BLK5
o_prime $CAPS_BLANKET
catch {ase::sim_said_clear}
set S1A [o_saykinds {o_dorun [o_state $AN_OP] $NL}]
set S1SAID [o_ans ase::sim_said]
o_prime $CAPS_WRITE
catch {ase::sim_said_clear}
set S1C [o_saykinds {o_dorun [o_state $AN_OP] $NL}]
check {S1 every run says which of the three forms it used, once, through the\
 one recorder -- and the record can be read back, so a dialog can show the very\
 words the CIW got} \
  [list $S1A $S1C [expr {($S1SAID ne {NOPROC} && $S1SAID ne {}) ? 1 : 0}]] \
  [list op_tier_blanket op_tier_perdevice 1]

o_prime $CAPS_WRITE
o_force b
catch {ase::sim_said_clear}
set S3 [o_saykinds {o_dorun [o_state $AN_OP] $NL}]
check {S3 when the form was chosen by hand rather than by what the simulator\
 can do, the run says that too -- the user is never left wondering why} \
  [expr {[string match RAISED:* $S3] ? $S3 : [lsort $S3]}] \
  {op_tier_forced op_tier_writeline}
o_force {}

# --- S2: the plain-English ruling, and nothing behavioural can see it -------
#
# ⚠ EVERY TAIL, NOT JUST THE DEFAULT ONE. The per-device sentence is a shared
# head plus one of five tails chosen by the reason token, and four of the five
# are reachable ONLY by passing that token. An earlier version of this row
# called ase::sim_why with three arguments, so the token was always empty and
# only the default tail was ever minted -- the S4 sabotage pass put the code
# word `appendwrite` into the `unsafe` tail, which is the sentence this box's
# own ngspice produces on every real run, and not one check in twelve suites
# went red. The list below is every sentence this surface can say.
set TIERSAYS {}
foreach k $TIERKINDS {
  if {$k eq {op_tier_perdevice}} {
    foreach x {unknown unsafe toomany forced zzNOSUCHREASON} {
      lappend TIERSAYS [list $k $x]
    }
  } else {
    lappend TIERSAYS [list $k {}]
  }
}
set S2 {}
foreach ke $TIERSAYS {
  set k [lindex $ke 0]
  set x [lindex $ke 1]
  set s [o_ans ase::sim_why $k ngspice /usr/bin/zzsim $x]
  if {$s eq {NOPROC} || [string match RAISED:* $s]} { lappend S2 [list $k $x $s] ; continue }
  if {$s eq "Something is wrong with the simulator named ngspice."} {
    lappend S2 [list $k $x NO-SENTENCE-MINTED] ; continue
  }
  foreach w {appendwrite hier_op_names blanket_op_save known tier} {
    if {[string first $w [string tolower $s]] >= 0} { lappend S2 [list $k $x $w] }
  }
}
check {S2 not one of the sentences this surface can say uses a word out of the\
 code or a name for the forms -- and that includes the four the reason token\
 chooses, one of which is what every run on this machine actually prints} \
  $S2 {}

# --- S6: the five tails are five different sentences, off one head ----------
# SEEN BY NOTHING ELSE. G4's and G5's reason tokens return the SAME tier, so no
# behavioural row can tell them apart; delete a tail and its reason simply falls
# through to the last one, which says "Your simulator cannot do either of the
# shorter ways" about a simulator that CAN do one and was refused it on purpose.
# That is a claim not measured for the thing it sits next to -- ruling D5-1 --
# and the sabotage pass deleted exactly that arm with nothing going red.
set S6SENT {}
foreach x {unknown unsafe toomany forced zzNOSUCHREASON} {
  lappend S6SENT [o_ans ase::sim_why op_tier_perdevice ngspice /usr/bin/zzsim $x]
}
## the longest opening every one of them shares -- the head, which ruling D5-4
## says is written once. Measured in characters, so no wording is typed here.
proc o_cprefix {a b} {
  set n [string length $a]
  if {[string length $b] < $n} { set n [string length $b] }
  for {set i 0} {$i < $n} {incr i} {
    if {[string index $a $i] ne [string index $b $i]} { return $i }
  }
  return $n
}
set S6BAD {}
set S6HEAD -1
foreach s $S6SENT {
  if {$s eq {NOPROC} || [string match RAISED:* $s]} { lappend S6BAD $s ; continue }
  if {$s eq "Something is wrong with the simulator named ngspice."} {
    lappend S6BAD NO-SENTENCE-MINTED ; continue
  }
  if {$S6HEAD < 0} {
    set S6HEAD [string length $s]
  } else {
    set S6HEAD [o_cprefix [lindex $S6SENT 0] $s]
  }
}
check {S6 each reason a run can have for using the per-device form gets its own\
 sentence -- five reasons, five different sentences, all off one shared opening,\
 and none of them the catch-all} \
  [list $S6BAD [llength [lsort -unique $S6SENT]] [expr {$S6HEAD >= 100 ? 1 : 0}]] \
  {{} 5 1}

# --- S7/S8/S9: the three reasons the run says NOTHING about the form --------
# A sentence about how the device numbers were asked for is a claim about the
# deck that ran. A run that asked for none has no shape to report, and saying
# one anyway would tell a user who never ticked the box -- or whose run has no
# operating point in it, or whose deck was rendered from a netlist this session
# never captured -- that their run asked one device at a time. It did not.
# All three gates were deleted in the sabotage pass with nothing going red.
proc o_report {state nl} {
  set ::o_repret ZZNOTRUN
  set k [o_saykinds {set ::o_repret [o_ans ase::op_tier_report ngspice $state $nl]}]
  return [list $::o_repret $k]
}
set NL_OTHER "** sch_path: /zz.sch\n**.subckt zzother\nV9 b 0 2\n**.ends\n.end\n"
o_force {}
o_prime $CAPS_WRITE
ase::op_cards_put $NL $BLK5
check {S7 a run the user never ticked the box on says nothing about how device\
 numbers were asked for, because none were} \
  [o_report [o_state $AN_OP 0] $NL] {{} {}}
check {S8 a run with no operating point in it says nothing about it either} \
  [o_report [o_state $AN_TRAN] $NL] {{} {}}
check {S9 and neither does a run whose deck came from a netlist this session\
 never captured any device requests for -- that deck carries none} \
  [o_report [o_state $AN_OP] $NL_OTHER] {{} {}}
check {S10 the control for those three: when device numbers really were asked\
 for, the run says so, once} \
  [o_report [o_state $AN_OP] $NL] {op_tier_perdevice op_tier_perdevice}

# --- S4: ruling D5-4, and nothing behavioural can see this either -----------
set S4SRC [o_nocomment [o_slurp $ASETCL]]
set WHYB [o_body ase::sim_why]
set S4MINT {}
foreach k $TIERKINDS {
  if {$WHYB eq {NOPROC} || [string match RAISED:* $WHYB]} { lappend S4MINT $WHYB ; continue }
  lappend S4MINT [o_count $WHYB $k]
}
check {S4 STRUCTURAL, ruling D5-4: each of the four sentences exists exactly\
 once, in the one place sentences are minted, and no say-site renders words of\
 its own into the CIW} \
  [list [o_count $S4SRC {ase::echo [ase::sim_why}] $S4MINT] \
  [list 0 {1 1 1 1}]

set RDB [o_body ase::run_deck]
set RCB [o_body ::ase::backend::ngspice::run_cmd]
check {S5 STRUCTURAL: the sentence belongs to the RUN and is said from there --\
 never from the command builder, whose every echo is pinned byte for byte by\
 test_ase_simreg_0931 row D4} \
  [list [expr {($RDB ne {NOPROC} && [string first op_tier $RDB] >= 0) ? 1 : 0}] \
        [expr {($RCB ne {NOPROC} && [string first op_tier $RCB] >= 0) ? 1 : 0}]] \
  {1 0}

# ============================================================================
# READING A RESULTS FILE -- plot by plot, stepping OVER the numbers
# ============================================================================
# A results file's numbers can spell a plot header inside themselves, so a
# reader that merely scanned for lines would report plots that do not exist.
# This one walks each plot's header, then steps over exactly that plot's block
# of numbers. Returns a list of plotname / points / vector-names triples.
proc o_rawplots {raw} {
  if {[catch {open $raw rb} fh]} { return NO-FILE }
  fconfigure $fh -translation binary
  set data [read $fh] ; close $fh
  set out {} ; set pos 0 ; set len [string length $data]
  while {$pos < $len} {
    set name {} ; set np 0 ; set nv 0 ; set vars {} ; set invars 0
    set cplx 0 ; set mode none ; set binstart -1
    while {$pos < $len} {
      set nl [string first "\n" $data $pos]
      if {$nl < 0} { set nl $len }
      set line [string range $data $pos [expr {$nl - 1}]]
      set nxt [expr {$nl + 1}]
      if {[string match {Plotname:*} $line]} {
        set pos $nxt ; set name [string trim [string range $line 9 end]] ; continue
      }
      if {[string match {Flags:*} $line]} {
        set pos $nxt
        if {[string first complex $line] >= 0} { set cplx 1 }
        continue
      }
      if {[string match {No. Variables:*} $line]} {
        set pos $nxt ; set nv [string trim [string range $line 14 end]] ; continue
      }
      if {[string match {No. Points:*} $line]} {
        set pos $nxt ; set np [string trim [string range $line 11 end]] ; continue
      }
      if {[string match {Variables:*} $line]} { set pos $nxt ; set invars 1 ; continue }
      if {[string match {Binary:*} $line]} { set pos $nxt ; set mode bin ; set binstart $pos ; break }
      if {[string match {Values:*} $line]} { set pos $nxt ; set mode txt ; break }
      set pos $nxt
      if {$invars && [regexp {^\s*\d+\s+(\S+)} $line -> nm]} { lappend vars $nm }
    }
    if {$name eq {}} break
    lappend out [list $name $np $vars]
    if {$mode eq {bin}} {
      if {![string is integer -strict $np] || ![string is integer -strict $nv]} break
      set pos [expr {$binstart + $np * $nv * ($cplx ? 16 : 8)}]
    } elseif {$mode eq {txt}} {
      ## text numbers: read on until the next file or plot header begins
      while {$pos < $len} {
        set nl [string first "\n" $data $pos]
        if {$nl < 0} { set nl $len }
        set line [string range $data $pos [expr {$nl - 1}]]
        if {[string match {Plotname:*} $line] || [string match {Title:*} $line]} { break }
        set pos [expr {$nl + 1}]
      }
    } else break
  }
  return $out
}
proc o_plotnames {raw} {
  set p [o_rawplots $raw]
  if {$p eq {NO-FILE}} { return NO-FILE }
  set out {} ; foreach x $p { lappend out [lindex $x 0] }
  return $out
}
## The vector names of the named plot, and only that plot.
proc o_plotvars {raw plot} {
  set p [o_rawplots $raw]
  if {$p eq {NO-FILE}} { return NO-FILE }
  foreach x $p { if {[lindex $x 0] eq $plot} { return [lindex $x 2] } }
  return NO-PLOT
}
## Of those, the ones that name a device parameter.
proc o_devvars {names} {
  if {![string is list $names]} { return $names }
  set d {}
  foreach n $names {
    if {[string first {@} $n] >= 0 && [string first {[} $n] >= 0} { lappend d $n }
  }
  return [lsort $d]
}

# ============================================================================
# A. THE BLANKET FORM, EXERCISED BY A STAND-IN THAT REALLY CLAIMS IT
# ============================================================================
# No released ngspice can do this, so without a stand-in the whole arm is code
# nobody has ever run -- which is exactly what shipped issues 0928 and 0929
# past a green suite. The stand-in answers the capability question with a real
# operating point carrying device numbers, so the probe measures the claim
# rather than being told it.
o_force {}
catch {ase::sim_caps_clear}
catch {ase::sim_clear}
o_ans ase::sim_register optier-blanket $S_BLANKET
o_ans ase::sim_select optier-blanket
set ACAPS [o_ans ase::sim_capabilities ngspice]
set ABOP NOKEY
if {![catch {dict get $ACAPS blanket_op_save} v]} { set ABOP $v }
ase::op_cards_put $NL $BLK5
set ADIR [file join $scratch arun]
file delete -force $ADIR
set AST [o_state $AN_OP]
dict set AST rundir $ADIR
set ADECK [o_render $AST $NL]
set ARC [o_dorun $AST $NL]
set ARAW [[o_ans ase::backend_hook ngspice raw_file] $AST]
set A1 NOPROC
if {$ADECK ne {NOPROC} && ![string match RAISED:* $ADECK]} {
  set nats 0
  foreach l [split $ADECK "\n"] { if {[string first {@} $l] >= 0} { incr nats } }
  set A1 [list $ABOP [o_tr $AST] $nats $ARC [o_plotnames $ARAW]]
}
check {A1 a stand-in that really can save every device at once is given the\
 blanket form: the deck it is handed names no device anywhere, the run\
 succeeds, and an operating point comes back with the device numbers in it} \
  $A1 [list 1 {a blanket} 0 0 {{Operating Point}}]

o_force c
set A2DIR [file join $scratch a2run]
file delete -force $A2DIR
set A2ST [o_state $AN_OP]
dict set A2ST rundir $A2DIR
set A2RC [o_dorun $A2ST $NL]
set A2RAW [[o_ans ase::backend_hook ngspice raw_file] $A2ST]
check {A2 the same stand-in handed a deck WITHOUT the blanket request takes its\
 other arm -- so A1 is not a stub that answers everything the same way} \
  [list [o_tr $A2ST] $A2RC [o_plotnames $A2RAW]] \
  [list {c forced} 0 {{Operating Point} {Transient Analysis}}]
o_force {}

# ============================================================================
# THE REAL SIMULATOR -- one transistor, two subcircuits deep
# ============================================================================
# Small on purpose: every row below is about the SHAPE of the request and the
# spelling of what comes back, and both are the same on one device as on 78.
# The bandgap bench's own numbers are in section ACC's printout.
set RDEV {@m.xi1.m1}
set RPAR {{id 0} {gm 1} {gds 1} {vgs 2} {vds 2}}
set RNL "** sch_path: /zz.sch\n**.subckt zzcell\n.model zmod nmos level=1 vto=0.7\
 kp=100u\n.subckt zinner d g s b\nM1 d g s b zmod w=10u l=1u\n.ends\nXI1 zd zg 0 0\
 zinner\nV1 zd 0 1.8\nV2 zg 0 1.8\n**.ends\n.end\n"
set RBLK ".save all"
foreach p $RPAR { append RBLK "\n.save ${RDEV}\[[lindex $p 0]\]" }
append RBLK "\n"
set RWRAPPED {}
foreach p $RPAR { lappend RWRAPPED [op_annot::_wrap $RDEV [lindex $p 0] [lindex $p 1]] }

## The value the tree's own annotation reader gives for one vector name.
proc o_readone {v} { return [o_ans op_annot::raw_or_blank $v] }
## The value the tree gives when it is allowed to try every spelling a results
## file may use -- which is what a one-line short-form results file needs,
## because it spells every device number bare and untyped.
proc o_readalt {dev param kind} {
  set alts [o_ans op_annot::_wrap_alts $dev $param $kind]
  if {$alts eq {NOPROC} || [string match RAISED:* $alts]} { return $alts }
  foreach v $alts {
    set x [o_readone $v]
    if {$x eq {NOPROC} || [string match RAISED:* $x]} { return $x }
    if {[o_ans op_annot::_finite $x] eq {1}} { return $x }
  }
  return {}
}
proc o_rawhook {st} { return [[o_ans ase::backend_hook ngspice raw_file] $st] }

if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: sections B/M/R/ACC run legs (ngspice not found)"
} else {
o_force {}
catch {ase::sim_caps_clear}
catch {ase::sim_clear}

# --- B. THE ONE-LINE SHORT FORM, AGAINST THE REAL SIMULATOR -----------------
# MEASURED: a results file written by naming devices on the write line spells
# every device number BARE and untyped -- @dev[id], not i(@dev[id]) -- so the
# reader that annotates the schematic, which asks for the typed spelling, finds
# nothing for four of the six numbers this tree shows for a sky130 transistor
# and paints them blank. The short form is unusable without this.
o_force b
ase::op_cards_put $RNL $RBLK
set BDIR [file join $scratch brun]
file delete -force $BDIR
set BST [o_state $AN_OP]
dict set BST rundir $BDIR
set BRC [o_dorun $BST $RNL]
set BRAW [o_rawhook $BST]
set B1 NOPROC
if {[file isfile $BRAW]} {
  catch {xschem annotate_op $BRAW 0 op}
  set miss {}
  foreach p $RPAR {
    set v [o_readalt $RDEV [lindex $p 0] [lindex $p 1]]
    if {$v eq {} || $v eq {NOPROC} || [string match RAISED:* $v] || ![regexp {[0-9]} $v]} {
      lappend miss [list [lindex $p 0] $v]
    }
  }
  set B1 [list [o_tr $BST] $BRC [o_plotnames $BRAW] $miss]
} else {
  set B1 [list [o_tr $BST] $BRC NO-RAW NO-RAW]
}
check {B1 a run forced onto the one-line short form comes back with an\
 operating point AND every one of the five numbers reads as a real number --\
 the results file spells them bare, so the reader has to try both spellings} \
  $B1 [list {b forced} 0 {{Operating Point}} {}]

set B3 NOPROC
set W1 [o_ans op_annot::_wrap $RDEV id 1]
set A0 [o_ans op_annot::_wrap_alts $RDEV id 0]
set A1L [o_ans op_annot::_wrap_alts $RDEV id 1]
set A2L [o_ans op_annot::_wrap_alts $RDEV id 2]
if {$A0 ne {NOPROC} && ![string match RAISED:* $A0]} {
  set B3 [list [llength $A1L] [llength $A0] [llength $A2L] [lindex $A0 1] [lindex $A2L 1] \
               [lindex $A0 0] [lindex $A2L 0]]
}
check {B3 STRUCTURAL: the bare spelling is offered as a SECOND try for the two\
 wrapped kinds and not at all for the kind that is already bare -- and it comes\
 from the one wrapper builder, never from a string typed out again here} \
  $B3 [list 1 2 2 $W1 $W1 [o_ans op_annot::_wrap $RDEV id 0] \
            [o_ans op_annot::_wrap $RDEV id 2]]

# --- B4: the control. On an ordinary results file nothing changes -----------
o_force c
set B4DIR [file join $scratch b4run]
file delete -force $B4DIR
set B4ST [o_state $AN_OP]
dict set B4ST rundir $B4DIR
set B4RC [o_dorun $B4ST $RNL]
set B4RAW [o_rawhook $B4ST]
set B4 NOPROC
if {[file isfile $B4RAW]} {
  catch {xschem annotate_op $B4RAW 0 op}
  set same 1 ; set detail {}
  foreach p $RPAR {
    set one [o_readone [op_annot::_wrap $RDEV [lindex $p 0] [lindex $p 1]]]
    set alt [o_readalt $RDEV [lindex $p 0] [lindex $p 1]]
    if {$one ne $alt} { set same 0 ; lappend detail [list [lindex $p 0] $one $alt] }
  }
  set B4 [list $B4RC $same $detail]
}
check {B4 the control: on a per-device results file the second spelling is\
 never reached and every number is exactly what it always was -- the fallback\
 is a fallback, not a replacement} \
  $B4 {0 1 {}}

# --- M. THE MULTI-POINT TRAP, BOTH HALVES ----------------------------------
# MEASURED: naming a bare device on a write line under .tran gives every vector
# one non-zero sample parked at index 0 and 0.0 at all 208 remaining points, no
# warning, well-formed file. The structural half stops the line being moved;
# the behavioural half proves what the file really contains.
o_force b
set M1S [list [o_writeats [o_render [o_state $AN_OP] $RNL]] \
              [o_writeats [o_render [o_state $AN_BOTH] $RNL]] \
              [o_writeats [o_render [o_state $AN_TRAN] $RNL]]]
set MDIR [file join $scratch mrun]
file delete -force $MDIR
set MST [o_state $AN_BOTH]
dict set MST rundir $MDIR
set MRC [o_dorun $MST $RNL]
set MRAW [o_rawhook $MST]
check {M1 device names never reach a transient write line, and a real run of a\
 forced short-form deck proves it: the transient plot of the results file holds\
 NO device numbers at all, rather than a column of zeroes nobody would notice} \
  [list $M1S $MRC [o_plotnames $MRAW] [o_devvars [o_plotvars $MRAW {Transient Analysis}]]] \
  [list [list [list 1] [list 1 0] [list 0]] 0 \
        [list {Operating Point} {Transient Analysis}] {}]
o_force {}

# --- R. ISSUE 0964: THE DEVICE REQUESTS STOP RIDING THE TRANSIENT -----------
# MEASURED on the user's own bandgap bench: the same 456 device numbers are
# recorded at every one of the transient's 20,505 time points, where nothing
# reads them -- 74.9 MB of results file and 4.08 s of the user's time. This is
# where the whole win of this item lives.
ase::op_cards_put $RNL $RBLK
set RDIR [file join $scratch rrun]
file delete -force $RDIR
set RST [o_state $AN_BOTH]
dict set RST rundir $RDIR
set RRC [o_dorun $RST $RNL]
set RRAW [o_rawhook $RST]
set R1 NOPROC
if {[file isfile $RRAW]} {
  ## CLEARED BEFORE EVERY READ, and the verdict taken from the reader
  ## afterwards. `xschem raw read <file> <type>` does NOT report failure through
  ## its return code -- on a file with no such plot it prints
  ## `raw_read(): no useful data found`, returns 0 and LEAVES THE PREVIOUS FILE
  ## LOADED, so a row that skipped the clear would read the plot the row above
  ## it loaded and pass on a tree with the change reverted.
  catch {xschem raw clear}
  if {[catch {xschem raw read $RRAW op}]} {
    set okop READ-RAISED
  } else {
    set okop [o_ans xschem raw sim_type]
  }
  catch {xschem raw clear}
  if {[catch {xschem raw read $RRAW tran}]} {
    set oktr READ-RAISED
  } else {
    set oktr [o_ans xschem raw sim_type]
  }
  set R1 [list [o_plotnames $RRAW] $okop $oktr]
}
check {R1 both results are still in the one file and each is still found by\
 name, whichever order they were computed in} \
  $R1 [list {{Transient Analysis} {Operating Point}} op tran]

check {R2 the transient holds NO device numbers any more -- this is the 74.9 MB\
 and the 4.08 s the user is paying today} \
  [o_devvars [o_plotvars $RRAW {Transient Analysis}]] {}

check {R3 and the operating point holds every one of them, spelled the way the\
 schematic annotation asks for them -- a current as a current, a voltage as a\
 voltage} \
  [o_devvars [o_plotvars $RRAW {Operating Point}]] [lsort $RWRAPPED]

set RDIR2 [file join $scratch rrun2]
file delete -force $RDIR2
set RST2 [o_state $AN_OP]
dict set RST2 rundir $RDIR2
set RRC2 [o_dorun $RST2 $RNL]
set RRAW2 [o_rawhook $RST2]
set R4 NOPROC
if {[file isfile $RRAW] && [file isfile $RRAW2]} {
  catch {xschem annotate_op $RRAW 0 op}
  set va {}
  foreach v $RWRAPPED { lappend va [o_readone $v] }
  catch {xschem annotate_op $RRAW2 0 op}
  set vb {}
  foreach v $RWRAPPED { lappend vb [o_readone $v] }
  set blank 0
  foreach x $va { if {$x eq {} || ![regexp {[0-9]} $x]} { incr blank } }
  set R4 [list [expr {$va eq $vb ? 1 : 0}] $blank]
}
check {R4 the numbers annotated onto the schematic are exactly the same numbers\
 they were before anything moved -- the change must move the cost and nothing\
 else} $R4 {1 0}

check {R5 an operating-point-only run is untouched: nothing moves into the\
 control block and the operating point still runs first} \
  [list [llength [o_deckcards [o_render $RST2 $RNL]]] \
        [llength [o_ctlsaves [o_render $RST2 $RNL]]] \
        [o_analines [o_render $RST2 $RNL]]] \
  [list [llength $RPAR] 0 op]

check {R6 the waveform viewer still opens on the transient -- the analysis that\
 runs last is no longer the one the viewer should show, and the seam that\
 chooses it must stop mirroring the deck's emit order} \
  [list [o_ans ase::plot_sim_type $RST] [o_ans ase::plot_sim_type $RST2]] \
  {tran op}

# ============================================================================
# ACC. THE ACCEPTANCE -- do the two forms give the SAME numbers
# ============================================================================
# RESPECIFIED, AND THE RESPECIFICATION IS MEASURED. The item asks for two runs
# compared. Two runs cannot answer it: three runs of the BYTE-IDENTICAL
# per-device deck on the user's bandgap bench put the output at 1.18680738 /
# 1.19115242 / 1.19121891 and disagree across the 456 device numbers by a
# median of 1.7% and a maximum of 1256%, which swamps the difference between
# the two forms entirely. Written from ONE simulator run and ONE operating
# point, both spellings of the same numbers are BIT-IDENTICAL, maximum
# relative difference 0.000e+00. So: one run, two results files, compared.
#
# The two spellings are built from the tree's OWN two helpers, so this row is
# about the tree's forms and not about a deck a test typed out by hand.
set ACCC [file join $scratch acc_c.raw]
set ACCB [file join $scratch acc_b.raw]
set ACCNAMES [o_ans ase::op_cards_names $RBLK]
set ACCDEVS  [o_ans ase::op_cards_devices $RBLK]
set ACC1 NOPROC ; set ACC2 NOPROC
if {$ACCNAMES ne {NOPROC} && ![string match RAISED:* $ACCNAMES] &&
    $ACCDEVS ne {NOPROC} && ![string match RAISED:* $ACCDEVS]} {
  ## ⚠ THE NETLISTER'S OWN MARKER LINES COME OUT, AND THE TEST FOR THEM IS NOT
  ## A GLOB. `string match {**} $l` is TWO wildcards and matches EVERY line, so
  ## the deck built from it held no circuit at all -- `op` then answered
  ## "no useful data found" and this whole section measured nothing while
  ## looking like it ran.
  set body {}
  foreach l [split [string trimright $RNL "\n"] "\n"] {
    if {[string range $l 0 1] eq {**} || [string trim $l] eq {.end}} { continue }
    lappend body $l
  }
  set d "* acceptance\n[join $body "\n"]\n.save all\n"
  foreach n $ACCNAMES { append d ".save $n\n" }
  append d ".control\nop\nremzerovec\nwrite $ACCC\n"
  append d "write $ACCB all [join $ACCDEVS { }]\n.endc\n.end\n"
  set accdeck [file join $scratch acc.sp]
  o_wr $accdeck $d
  file delete -force $ACCC $ACCB
  catch {exec ngspice -b $accdeck} accout
  ## every device-parameter vector the per-device form saved, compared with the
  ## same number as the short form spells it, one run, one operating point
  set cvars [o_devvars [o_plotvars $ACCC {Operating Point}]]
  set bvars [o_devvars [o_plotvars $ACCB {Operating Point}]]
  set diff {} ; set n 0
  if {[string is list $cvars] && [string is list $bvars]} {
    catch {xschem annotate_op $ACCC 0 op}
    set cval [dict create]
    foreach v $cvars { dict set cval $v [o_readone $v] }
    catch {xschem annotate_op $ACCB 0 op}
    foreach v $cvars {
      ## the short form spells everything bare: strip the current/voltage wrapper
      set bare $v
      regexp {^[iv]\((.*)\)$} $v -> bare
      if {[lsearch -exact $bvars $bare] < 0} { lappend diff [list $v ABSENT] ; continue }
      set bv [o_readone $bare]
      incr n
      if {$bv ne [dict get $cval $v]} { lappend diff [list $v [dict get $cval $v] $bv] }
    }
  }
  set ACC1 [list [llength $cvars] $n $diff]
}
check {ACC1 from ONE simulator run and ONE operating point, every device number\
 the per-device form saved is bit-for-bit the number the short form gives for\
 the same device and the same parameter} \
  $ACC1 [list [llength $RPAR] [llength $RPAR] {}]

if {[file isfile $ACCC] && [file isfile $ACCB]} {
  catch {xschem annotate_op $ACCC 0 op}
  set rc {}
  foreach p $RPAR { lappend rc [o_readone [op_annot::_wrap $RDEV [lindex $p 0] [lindex $p 1]]] }
  catch {xschem annotate_op $ACCB 0 op}
  set rb {}
  foreach p $RPAR { lappend rb [o_readalt $RDEV [lindex $p 0] [lindex $p 1]] }
  set blank 0
  foreach x $rc { if {$x eq {} || ![regexp {[0-9]} $x]} { incr blank } }
  set ACC2 [list [expr {$rc eq $rb ? 1 : 0}] $blank]
}
check {ACC2 and the numbers that would be PAINTED ON THE SCHEMATIC are the same\
 through both forms, read the way the annotation reads them -- not merely the\
 same numbers somewhere in the file} \
  $ACC2 {1 0}

# --- ACC3: the win, as a measurement rather than a story --------------------
# PRINTED, NEVER ASSERTED: a wall-clock assert flakes and would say nothing
# true. 20 devices and a 200 ns transient, which is the shape of the user's
# bench in miniature -- the same device numbers recorded at every time point.
set ABODY ".model zmod nmos level=1 vto=0.7 kp=100u\n.subckt zinner d g s b\nM1 d g\
 s b zmod w=10u l=1u\n.ends\n"
set ABLK ".save all"
for {set i 1} {$i <= 20} {incr i} {
  append ABODY "XI$i zd zg 0 0 zinner\n"
  foreach p $RPAR { append ABLK "\n.save @m.xi$i.m1\[[lindex $p 0]\]" }
}
append ABODY "V1 zd 0 1.8\nV2 zg 0 1.8\n"
append ABLK "\n"
set ANL "** sch_path: /zz.sch\n**.subckt zzcell\n$ABODY**.ends\n.end\n"
set AAN {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 200n}}
ase::op_cards_put $ANL $ABLK
set ACC3 {}
foreach arm {c b off} {
  if {$arm eq {off}} { o_force c } else { o_force $arm }
  set adir [file join $scratch acc3$arm]
  file delete -force $adir
  set ast [o_state $AAN [expr {$arm eq {off} ? 0 : {}}]]
  dict set ast rundir $adir
  set adeck [o_render $ast $ANL]
  set t0 [clock milliseconds]
  set arc [o_dorun $ast $ANL]
  set ms [expr {[clock milliseconds] - $t0}]
  set araw [o_rawhook $ast]
  set asz 0
  if {[file isfile $araw]} { set asz [file size $araw] }
  set atier [o_tr $ast]
  puts "MEASURE $arm: tier=[join $atier /] deck=[expr {($adeck eq {NOPROC} ||\
 [string match RAISED:* $adeck]) ? {NA} : [string length $adeck]}]bytes\
 wall=${ms}ms raw=${asz}bytes rc=$arc"
  lappend ACC3 [list $atier $arc]
}
o_force {}
check {ACC3 deck size, wall clock and results size are measured for both forms\
 and for the control with no device numbers at all -- the numbers are PRINTED\
 above this row, and the row itself only proves all three were really run} \
  $ACC3 [list [list {c forced} 0] [list {b forced} 0] [list {c forced} 0]]

}

} zzerr]} {
  puts "FATAL: uncaught error: $zzerr"
  puts "$::errorInfo"
  incr fail
}

# --- teardown ----------------------------------------------------------------
catch {ase::op_tier_force_set {}}
catch {ase::op_cards_clear}
catch {ase::sim_caps_clear}
catch {ase::sim_clear}
catch {xschem raw clear}

# --- verdict -----------------------------------------------------------------
# THE DUAL BANNER IS REQUIRED by tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE OVERALL line as
# well as the RESULT line; registering a suite there without one reproduces the
# completion-sentinel false red filed four times as 0420 / 0492 / 0629 / 0689.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
