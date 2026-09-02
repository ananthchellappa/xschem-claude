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
# `[*]`.
#
# ⚠ THE THIRD ARM IS NOW DEAD, AND IT IS KEPT AS A WITNESS. Before issues 0966
# and 0968 a blanket-tier ASE deck named no device at all and had to be
# recognised by the device-less request `.options saveopparams` instead -- two
# different questions with one capability answer between them, which was the
# defect. Since the emitted shape IS the probed shape, a blanket-tier deck
# carries `[*]` like the probe's own and takes the second arm. Leaving the
# `saveopparams` arm here costs nothing and makes the change visible to a reader
# of this file.
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
# ⚠ THIS ROW CHANGED SHAPE WITH ISSUES 0966 AND 0968, AND THE OLD SHAPE WAS THE
# DEFECT. It used to assert that the blanket deck NAMES NO DEVICE ANYWHERE --
# a device-less `.options` pair sitting above the run. That is not the question
# the capability probe asks (0966), and a dot-card above the run applies to
# every analysis in it, which is how the device numbers rode the transient
# before (0968). What survives unchanged is the property that matters: the
# request is O(devices), not O(devices x parameters), and nothing device-related
# is left sitting above the run.
set E1 NOPROC
if {$DA ne {NOPROC} && ![string match RAISED:* $DA]} {
  set nats 0
  foreach l [split $DA "\n"] { if {[string first {@} $l] >= 0} { incr nats } }
  set nsaveall 0
  set ndeckats 0
  foreach l [o_decklevel $DA] {
    if {[string trim $l] eq {.save all}} { incr nsaveall }
    if {[string first {@} $l] >= 0} { incr ndeckats }
  }
  set E1 [list [regexp -all -line {^\.options} $DA] $nsaveall $nats $ndeckats]
}
check {E1 the blanket form asks for each device's operating-point numbers ONCE\
 -- one request per device rather than one per number -- all of them on a\
 single line inside the run, and it leaves nothing that names a device above\
 the run where it would apply to every analysis} $E1 {0 1 1 0}

ase::op_cards_put $NL $BLK100
set DA100 [o_render [o_state $AN_OP] $NL]
ase::op_cards_put $NL $BLK0
set DA0 [o_render [o_state $AN_OP] $NL]
# ⚠ ALSO RESHAPED BY 0966. The blanket form is no longer O(1) in the deck -- it
# names one device per request -- so the claim "the same size for 100 devices as
# for none" is no longer true and asserting it would be asserting the defect.
# What it IS, and what this row now measures, is O(devices) against the
# per-device form's O(devices x parameters): 100 devices at 6 parameters each
# are 600 cards under form c and 100 names on one line under this one.
set E2 NOPROC
if {$DA100 ne {NOPROC} && ![string match RAISED:* $DA100] &&
    $DA0 ne {NOPROC} && ![string match RAISED:* $DA0]} {
  set gr [expr {[llength [split $DA100 "\n"]] - [llength [split $DA0 "\n"]]}]
  set e2n 0
  foreach l [o_control $DA100] {
    if {![regexp {^\s*save\s} [string trim $l]]} { continue }
    foreach w [split [string trim $l]] { if {[string index $w 0] eq {@}} { incr e2n } }
  }
  set E2 [list [expr {($gr >= 0 && $gr <= 3) ? {within-3-lines} : "grew-by-$gr-lines"}] \
               $e2n [llength [o_deckcards $DA100]]]
}
check {E2 the blanket form asks for a hundred devices in the same three lines it\
 asks for none -- a hundred names, not six hundred cards, and not one of them\
 above the run} $E2 {within-3-lines 100 0}

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
# P. THE PRINTED OUTPUTS READ THE OPERATING POINT (issues 0967, 1243)
# ============================================================================
# The Outputs pane has a Value column, and it is filled in after a run from the
# deck's `print` lines -- see ase::backend::ngspice::result_probe, which accepts
# a scalar `<expr> = <number>` line and nothing else. `print` reads whichever
# plot the simulator is standing in.
#
# ⚠ THE RULING THESE ROWS PIN CHANGED, AND THE USER MADE IT (issue 1243,
# 2026-09-02). 0967 froze the anchor against an unrelated checkbox and said in
# this very comment that WHICH analysis the column reads was "the user's ruling
# to make". They made it, on their own tb_bandgap: with op and tran both
# enabled the pane showed nothing, with op alone it showed values, and they
# called the first one wrong. So the prints now follow the OPERATING POINT
# whenever one is enabled.
#
# WHY THAT IS THE ONLY READABLE ANSWER. On a multi-point plot `print VBG` emits
# a paged `Index time vbg` table -- measured on the user's run log, 20,514 rows
# per printed output and 108,275 log lines for five of them, from which
# result_probe extracts nothing at all. The scalar column had never had a value
# to show for a transient. Nothing displayed therefore changes VALUE here: a
# number appears where the column was empty, which is what keeps this clear of
# ruling D5-1.
#
# The anchor order is the canonical `op dc ac tran` with `op` moved LAST so
# last-enabled-wins picks it. With the operating point off the two orders choose
# the same analysis, so every op-less deck renders byte for byte as it did.
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
 the outputs the user asked to see are printed from the OPERATING POINT -- they\
 sit after its write, which is the last thing the deck does} \
  $P1 [list {tran save op print print} {{print v(out)} {print v(mid)}}]

set DP2 [o_render [o_state $AN_BOTH 0 $OUTS] $NL]
set P2 NOPROC
if {$DP2 ne {NOPROC} && ![string match RAISED:* $DP2]} {
  set P2 [list [o_ctlshape $DP2] [o_prints $DP2]]
}
check {P2 the control: with the tick off nothing is reordered and the operating\
 point runs FIRST, and the prints follow it there -- the anchor is the enabled\
 set, not the emit order, so the transient that runs after them does not take\
 the column} \
  $P2 [list {op print print tran} {{print v(out)} {print v(mid)}}]

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

## P4 -- THE HALF THE USER HAS NOT RULED ON, PINNED SO IT CANNOT DRIFT. With no
## operating point enabled there is no scalar analysis to anchor to, and the
## prints stay exactly where they always sat: after the transient, where
## `print` emits a table and the Value column stays EMPTY. That is unchanged
## behaviour, not a fix -- what a scalar column should show for a waveform (the
## final point? t=0? nothing at all?) is a separate ruling, and it is on the
## owed ledger as one. This row exists so that whoever answers it has to come
## here and say so, rather than discovering afterwards that a transient-only
## bench quietly started reporting a number.
set DP5 [o_render [o_state $AN_TRAN {} $OUTS] $NL]
set P4 NOPROC
if {$DP5 ne {NOPROC} && ![string match RAISED:* $DP5]} {
  set P4 [o_ctlshape $DP5]
}
check {P4 issue 1243 a transient-only run is UNCHANGED -- with no operating\
 point to anchor to the prints stay after the transient, and the Value column\
 stays as empty as it has always been} \
  $P4 {tran print print}

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
  ## RESHAPED WITH 0966: the deck names each device ONCE, wildcarded over that
  ## device's own parameters -- the shape the probe measured. It used to name
  ## none, which is a different question from the one the YES was about.
  set anames {}
  foreach l [split $ADECK "\n"] {
    foreach w [split $l] { if {[string index $w 0] eq {@}} { lappend anames $w } }
  }
  set awild 1
  if {![llength $anames]} { set awild 0 }
  foreach n $anames { if {![string match {*\[\*\]} $n]} { set awild 0 } }
  set A1 [list $ABOP [o_tr $AST] [llength $anames] $awild $ARC [o_plotnames $ARAW]]
}
check {A1 a stand-in that really can save every device at once is given the\
 blanket form: the deck it is handed asks for each of the five devices once and\
 for every one of that device's numbers, the run succeeds, and an operating\
 point comes back with the device numbers in it} \
  $A1 [list 1 {a blanket} 5 1 0 {{Operating Point}}]

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


# ============================================================================
# E-NEW. THE BLANKET FORM IS THE SHAPE THAT WAS MEASURED (0966), AND IT IS
#        SCOPED TO THE ANALYSIS THAT CAN USE IT (0968)
# ============================================================================
# TWO DEFECTS, ONE SHAPE. What the capability probe ASKS is one request per
# device, wildcarded over that device's parameters, inside the control block:
#     save @m.xo1.xi1.m1[*]                             (src/ase.tcl:6332)
# What the deck EMITS when the probe says yes is a device-less pair of
# dot-cards at deck level, above the control block:
#     .save all
#     .options saveopparams                        (as ase.tcl shipped it)
# So a build that answers YES to the question that was asked gets a deck that
# asks a different question (0966), and it gets it at DECK level, where it
# applies to every analysis in the run -- which is exactly how the per-analysis
# scoping was lost before, issue 0928 (0968).
#
# Neither is reachable behaviourally on this box without the stand-in: no
# released ngspice answers yes. Measured by hand on ngspice-46+, the probe's
# own deck B returns 0 device-parameter vectors.

o_prime $CAPS_BLANKET
o_force a
ase::op_cards_put $NL $BLK5
set EA [o_render [o_state $AN_OP] $NL]
set EAB [o_render [o_state $AN_BOTH] $NL]
set EABO [o_render [o_state $AN_BOTH {} $OUTS] $NL]

## The `@` tokens named by the `save` commands inside `.control`, in order.
proc o_ctlats {deck} {
  set n {}
  foreach s [o_ctlsaves $deck] {
    foreach t [o_ats $s] { lappend n $t }
  }
  return $n
}
## Does every one of them carry the wildcard the probe measured with?
proc o_allwild {names} {
  if {![llength $names]} { return 0 }
  foreach n $names { if {![string match {*\[\*\]} $n]} { return 0 } }
  return 1
}
## Where the device requests sit relative to the analysis they belong to:
## the control-block line index of the last device request and of `op`.
proc o_ctlorder {deck} {
  set i -1 ; set lastsave -1 ; set opat -1
  foreach l [o_control $deck] {
    incr i
    set t [string trim $l]
    if {[regexp {^save\s} $t]} { set lastsave $i }
    if {[regexp {^op(\s|$)} $t]} { if {$opat < 0} { set opat $i } }
  }
  return [list $lastsave $opat]
}

set E14 NOPROC
if {$EA ne {NOPROC} && ![string match RAISED:* $EA]} {
  set e14names [o_ctlats $EA]
  lassign [o_ctlorder $EA] e14last e14op
  set E14 [list [regexp -all -line {^\.options} $EA] \
                [llength [o_deckcards $EA]] \
                [llength $e14names] \
                [o_allwild $e14names] \
                [expr {($e14last >= 0 && $e14op == $e14last + 1) ? 1 : 0}]]
}
check {E14 issue 0966 when the simulator can hand back every device's\
 operating-point numbers, the deck asks for them the way the simulator was\
 asked whether it could -- one request per device, right before the operating\
 point, and nothing left sitting above the run} \
  $E14 {0 0 5 1 1}

set E15SRC [o_nocomment [o_slurp $ASETCL]]
set E15 NOPROC
if {$EA ne {NOPROC} && ![string match RAISED:* $EA]} {
  set E15 [list [o_count $E15SRC {\[*\]}] [o_allwild [o_ctlats $EA]]]
}
check {E15 issue 0966 STRUCTURAL the shape the simulator is TESTED with and the\
 shape the deck ASKS with are spelled in one place, so a capability that is\
 measured one way can never be used another} \
  $E15 {1 1}

set E16 NOPROC
if {$EAB ne {NOPROC} && ![string match RAISED:* $EAB]} {
  lassign [o_ctlorder $EAB] e16last e16op
  set E16 [list [o_analines $EAB] \
                [llength [o_ctlats $EAB]] \
                [expr {($e16last >= 0 && $e16op == $e16last + 1) ? 1 : 0}] \
                [regexp -all -line {^\.options} $EAB] \
                [llength [o_deckcards $EAB]]]
}
check {E16 issue 0968 with a transient in the same run the device requests are\
 made for the OPERATING POINT ONLY -- they sit inside the run, right before it,\
 and the operating point goes last so nothing else is recorded at every\
 timepoint} \
  $E16 {{tran op} 5 1 0 0}

## 0967 IS SETTLED NOW, AND NOT BY THIS CHANGE. Which analysis the Outputs Value
## column reads was the user's ruling to make and they made it -- the operating
## point (issue 1243, section P). What this row still says is 0967's own claim,
## which outlives the ruling: the answer comes from the ENABLED SET, so moving
## the device requests cannot move it. Sabotage the emit order and this row does
## not budge; sabotage the anchor order and it does.
set E17 NOPROC
if {$EABO ne {NOPROC} && ![string match RAISED:* $EABO]} {
  set e17 {} ; set e17seen {}
  foreach l [o_control $EABO] {
    set t [string trim $l]
    if {[regexp {^(op|dc|ac|tran)(\s|$)} $t -> k]} { set e17seen $k }
    if {[regexp {^print\s} $t]} { lappend e17 $e17seen }
  }
  set E17 $e17
}
check {E17 issues 0967+1243 the Outputs Value column reads the OPERATING POINT\
 on an op+tran bench -- and it reads it because the operating point is enabled,\
 not because the device requests moved} \
  $E17 {op op}

set RDBODY [o_body ::ase::backend::ngspice::render_deck]
check {E18 issues 0966+0968 STRUCTURAL nothing device-related is written as a\
 setting that applies to the whole run, because a whole-run setting cannot be\
 confined to the operating point} \
  [list [expr {($RDBODY ne {NOPROC}) ? [o_count $RDBODY {saveopparams}] : $RDBODY}] \
        [o_count $E15SRC {saveopparams}]] \
  {0 0}

o_force {}

# ============================================================================
# Q. A NAME THAT CAME BACK WITH NOTHING IS NEVER SILENT AGAIN
# ============================================================================
# MEASURED FIRST-HAND ON ngspice-46+. A `.save` card naming a device that does
# not exist is accepted without one character of complaint: exit 0, a normal
# results file, and the bad name lands in it as a zero-length vector that
# `remzerovec` then strips. In-control `save` behaves the same. So the run
# looks perfect and six rows on the user's schematic are blank.
#
# On the shipped bandgap bench that is 12 blank rows out of 468, and NOTHING
# anywhere says so: op_annot::last_warnings is empty, its counts read
# dropped_by_rule 0 not_found 0 name_failed 0, and the 561-line run log has no
# occurrence of "no such", "x5.xm2" or "x6.xm2". The only count the user is
# ever shown is how many requests went IN. Nothing compares that with what came
# back. Removing that silence is ours to do, not the simulator's.
#
# The rows below drive whole runs against stand-ins that hand back a chosen
# subset of the devices, so the comparison is exercised end to end without a
# PDK or a simulator.

## One canned results file: an Operating Point plot naming the given devices,
## spelled the three ways the parameter kinds wrap them.
proc q_rawdevs {devs} {
  global TITLE
  set params {id gm gds vgs vth vds}
  set vars {}
  foreach dv $devs {
    foreach p $params {
      set d "${dv}\[$p\]"
      switch -- $p {
        id  { lappend vars "i($d)" }
        gm  -
        gds { lappend vars $d }
        default { lappend vars "v($d)" }
      }
    }
  }
  set t "${TITLE}Plotname: Operating Point\nFlags: real\nNo. Variables:\
 [llength $vars]\nNo. Points: 1\nVariables:\n"
  set k 0
  foreach v $vars { append t "\t$k\t$v\tnotype\n" ; incr k }
  append t "Values:\n 0"
  for {set j 0} {$j < [llength $vars]} {incr j} { append t "\t1.000000e-03\n" }
  return $t
}
## The same, for the <ndev> devices ase::op_cards_devices reads out of o_block.
proc q_raw {ndev} {
  set devs {}
  for {set i 1} {$i <= $ndev} {incr i} { lappend devs "@m.xz${i}.mzmod" }
  return [q_rawdevs $devs]
}
## A stand-in that always copies ONE file, or writes nothing at all when the
## source is the word NONE -- which is the measured shape of a run that exits 0
## and produces no results.
set Q_STUBTPL {#!/bin/sh
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
if [ -z "$deck" ]; then exit 0; fi
out=`grep -E '^[ 	]*write[ 	]' "$deck" | head -1 | sed -e 's/^[ 	]*write[ 	][ 	]*//' -e 's/[ 	]*$//'`
if [ -n "$out" ] && [ -f "@SRC@" ]; then cat "@SRC@" > "$out"; fi
exit 0
}
proc q_stub {name src} {
  global Q_STUBTPL BIN
  set p [file join $BIN $name]
  o_wr $p [string map [list @SRC@ $src] $Q_STUBTPL] 0755
  return $p
}
proc q_prime {prog caps} {
  set r [o_useprog $prog]
  if {$r eq {}} { return NORESOLVE }
  if {[catch {ase::cap_stamp $r} st]} { return "RAISED:$st" }
  set ::ase::sim_caps [dict create $r [list stamp $st caps $caps]]
  return $r
}
## Every line the run put in front of the user, and every sentence the one mint
## produced while it ran. Both, because ruling D5-4 is about WHERE a sentence
## comes from, not only about what it says.
proc q_run {script} {
  set ::q_lines {}
  set ::q_minted {}
  set ::q_kinds {}
  if {[info commands ::ase::echo] eq {} ||
      [info commands ::ase::sim_why] eq {}} { return NOPROC }
  rename ::ase::echo ::q_saved_echo
  proc ::ase::echo {msg {tag {}}} {
    lappend ::q_lines $msg
    return [::q_saved_echo $msg $tag]
  }
  rename ::ase::sim_why ::q_saved_why
  proc ::ase::sim_why {kind name path {extra {}}} {
    set s [::q_saved_why $kind $name $path $extra]
    lappend ::q_minted $s
    lappend ::q_kinds $kind
    return $s
  }
  set rc [catch {uplevel 1 $script} r]
  rename ::ase::echo {} ; rename ::q_saved_echo ::ase::echo
  rename ::ase::sim_why {} ; rename ::q_saved_why ::ase::sim_why
  if {$rc} { return "RAISED:$r" }
  return [list $::q_lines $::q_minted $::q_kinds]
}
## Which of <names> a line mentions.
proc q_named {line names} {
  set h {}
  foreach n $names { if {[string first $n $line] >= 0} { lappend h $n } }
  return $h
}
## The lines that mention at least one of <names>.
proc q_hits {lines names} {
  set h {}
  foreach l $lines { if {[llength [q_named $l $names]]} { lappend h $l } }
  return $h
}
## Standalone whole numbers in a sentence -- the counts, not the digits buried
## in a device name.
proc q_ints {line} {
  set out {}
  foreach w [split [string map {, { } . { }} $line]] {
    if {[string is integer -strict $w]} { lappend out $w }
  }
  return [lsort -integer -unique $out]
}
proc q_has {l vals} {
  foreach v $vals { if {[lsearch -exact $l $v] < 0} { return 0 } }
  return 1
}

set Q_ALL5  [file join $scratch q_all5.raw]
set Q_SOME5 [file join $scratch q_some5.raw]
set Q_SOME20 [file join $scratch q_some20.raw]
o_wr $Q_ALL5   [q_raw 5]
o_wr $Q_SOME5  [q_raw 3]
o_wr $Q_SOME20 [q_raw 2]
set Q_S_ALL5   [q_stub sim_q_all5   $Q_ALL5]
set Q_S_SOME5  [q_stub sim_q_some5  $Q_SOME5]
set Q_S_SOME20 [q_stub sim_q_some20 $Q_SOME20]
set Q_S_NONE   [q_stub sim_q_none   NONE]

set BLK20  [o_block 20]
set DEV20  [o_blockdevs 20]
set Q_MISS2  [list @m.xz4.mzmod @m.xz5.mzmod]

o_force {}
ase::op_cards_put $NL $BLK5

## Q1 -- three of the five devices came back.
q_prime $Q_S_SOME5 $CAPS_WRITE
set Q1R [q_run {o_dorun [o_state $AN_OP 1] $NL}]
set Q1 NOPROC
if {$Q1R ne {NOPROC} && ![string match RAISED:* $Q1R]} {
  set q1h [q_hits [lindex $Q1R 0] $Q_MISS2]
  set Q1 [list [llength $q1h] \
               [expr {[llength $q1h] == 1 ? [llength [q_named [lindex $q1h 0] $Q_MISS2]] : 0}] \
               [expr {[llength $q1h] == 1 ? [q_has [q_ints [lindex $q1h 0]] {5 3}] : 0}]]
}
check {Q1 the simulator was asked for five devices and handed back three, so\
 the run says so once, gives both counts, and names the two it did not answer\
 for -- instead of leaving those rows blank on the schematic with no\
 explanation anywhere} \
  $Q1 {1 2 1}

## Q2 -- the control. Every device came back; there is nothing to report and
## saying something anyway would be a claim about a run that went fine.
q_prime $Q_S_ALL5 $CAPS_WRITE
set Q2R [q_run {o_dorun [o_state $AN_OP 1] $NL}]
set Q2 NOPROC
if {$Q2R ne {NOPROC} && ![string match RAISED:* $Q2R]} {
  set Q2 [llength [q_hits [lindex $Q2R 0] [o_blockdevs 5]]]
}
check {Q2 a run every device answered for says nothing about it -- silence is\
 the right answer when nothing went wrong} $Q2 0

## Q3 -- exit 0 and no results file at all. MEASURED: that is what the
## one-line short form does on ngspice-46+ when a single device name cannot be
## matched; it prints three lines to its own log, writes no file, and exits 0.
q_prime $Q_S_NONE $CAPS_WRITE
set Q3R [q_run {o_dorun [o_state $AN_OP 1] $NL}]
set Q3 NOPROC
if {$Q3R ne {NOPROC} && ![string match RAISED:* $Q3R]} {
  set q3h {}
  foreach l [lindex $Q3R 0] { if {[string first zzcell_ase.raw $l] >= 0} { lappend q3h $l } }
  set Q3 [list [llength $q3h] [expr {[llength $q3h] ? [expr {[string length [lindex $q3h 0]] >= 80}] : 0}]]
}
check {Q3 the run finished without complaining and produced no results file at\
 all, so the user is told that -- naming the file that never appeared and what\
 to do instead -- rather than being left with a blank schematic} \
  $Q3 {1 1}

## Q4 -- twenty asked for, two answered. The list is capped so the CIW stays
## readable, and the sentence says how many it did not list.
ase::op_cards_put $NL $BLK20
q_prime $Q_S_SOME20 $CAPS_WRITE
set Q4R [q_run {o_dorun [o_state $AN_OP 1] $NL}]
set Q4 NOPROC
if {$Q4R ne {NOPROC} && ![string match RAISED:* $Q4R]} {
  set q4miss [lrange $DEV20 2 end]
  set q4h [q_hits [lindex $Q4R 0] $q4miss]
  set Q4 [list [llength $q4h] \
               [expr {[llength $q4h] == 1 ? [llength [q_named [lindex $q4h 0] $q4miss]] : -1}] \
               [expr {[llength $q4h] == 1 ? [q_has [q_ints [lindex $q4h 0]] {20 2 13}] : 0}]]
}
check {Q4 when many devices went unanswered the run names the first few and\
 says how many more there were, so one bad run cannot bury the CIW in device\
 names} $Q4 {1 5 1}
ase::op_cards_put $NL $BLK5

## Q5 -- ruling D5-4, measured rather than grepped: the sentence the user read
## is the very string the one mint produced.
set Q5 NOPROC
if {$Q1R ne {NOPROC} && ![string match RAISED:* $Q1R]} {
  set q5h [q_hits [lindex $Q1R 0] $Q_MISS2]
  set q5ok 0
  if {[llength $q5h] == 1} {
    foreach m [lindex $Q1R 1] {
      if {$m ne {} && [string first $m [lindex $q5h 0]] >= 0} { set q5ok 1 }
    }
  }
  set q5n 0
  if {$Q3R ne {NOPROC} && ![string match RAISED:* $Q3R]} {
    foreach l [lindex $Q3R 0] {
      if {[string first zzcell_ase.raw $l] < 0} { continue }
      foreach m [lindex $Q3R 1] {
        if {$m ne {} && [string first $m $l] >= 0} { set q5n 1 }
      }
    }
  }
  set Q5 [list $q5ok $q5n]
}
check {Q5 RULING D5-4 both new sentences are written in the one place sentences\
 about a run are written, and the run only renders them -- so the Simulators\
 dialog can show the user the very words the CIW got} $Q5 {1 1}

## Q6 -- the plain-English ruling. The device names themselves are the deck's
## own spelling and are deliberately NOT on the ban list: they are what the
## user searches their results with.
set Q6 {}
foreach q6r [list $Q1R $Q3R $Q4R] {
  if {$q6r eq {NOPROC} || [string match RAISED:* $q6r]} { lappend Q6 $q6r ; continue }
  foreach s [lindex $q6r 1] {
    if {$s eq {}} continue
    if {[string length $s] < 80} { lappend Q6 [list SHORT $s] }
    foreach w {blanket tier optier saveopparams appendwrite hier_op_names\
               blanket_op_save vector .save .control remzerovec} {
      if {[string first $w [string tolower $s]] >= 0} { lappend Q6 [list $w $s] }
    }
  }
}
set Q6NEW 0
foreach q6r [list $Q1R $Q3R] {
  if {$q6r eq {NOPROC} || [string match RAISED:* $q6r]} { continue }
  incr Q6NEW [llength [lindex $q6r 1]]
}
check {Q6 PLAIN ENGLISH neither new sentence uses a word out of the code, and\
 each is a real explanation rather than a bare state name} \
  [list $Q6 [expr {$Q6NEW >= 2 ? 1 : 0}]] {{} 1}

# ============================================================================
# Q-DIRECT. THE FOUR GUARDS A WHOLE RUN CANNOT REACH
# ============================================================================
# WHY THESE ROWS ARE DRIVEN AND NOT RUN. Q1-Q6 above drive real runs against
# stand-in simulators, and that is the right shape for the everyday case. But
# the stand-ins always exit 0, always resolve their own results path, and are
# always fed a block whose device names are twenty tidy variations on one
# spelling. Four of this report's guards live outside all three of those, and
# sabotaging every one of them left the whole tree green:
#
#   * the whole-name test, which a substring test silently replaces;
#   * the LAST-bracket cut, which a bussed instance needs (issue 0972);
#   * "I could not work out where the file would be is not 'there is no file'";
#   * "a run that already failed loudly is not also told its devices are gone".
#
# A guard nobody can see is a comment. These rows call ase::op_report_missing
# the way ase::run_done calls it -- state, the run's captured block, the exit
# code -- and put those four conditions in front of it.

## The report, driven directly. Answers {kind lines saidkinds}, so a row can
## assert on the ANSWER and on what the user was told, and can tell silence
## (nothing said) from a wrong sentence.
proc q_direct {state blk exitcode} {
  if {[info commands ::ase::op_report_missing] eq {}} { return NOPROC }
  set ::q_st $state
  set ::q_meta [dict create opblock $blk]
  set ::q_rc $exitcode
  set ::q_ret ZZUNSET
  set r [q_run {set ::q_ret [ase::op_report_missing $::q_st $::q_meta $::q_rc]}]
  if {$r eq {NOPROC} || [string match RAISED:* $r]} { return $r }
  return [list $::q_ret [lindex $r 0] [lindex $r 2]]
}
## A captured block naming exactly the given devices, six parameters each --
## the shape op_annot::save_cards produces.
proc q_blkdevs {devs} {
  set b ".save all"
  foreach dv $devs {
    foreach p {id gm gds vgs vth vds} { append b "\n.save ${dv}\[$p\]" }
  }
  return "$b\n"
}

set QD_ST  [o_state $AN_OP 1]
set QD_RAW {}
catch {set QD_RAW [[ase::backend_hook ngspice raw_file] $QD_ST]}

## Q7 -- ONE NAME INSIDE ANOTHER. sky130's own model names nest: every binned
## flavour is the plain name with a suffix glued on, so `..._pfet_01v8` sits
## inside `..._pfet_01v8_lvt` character for character. If the report only asked
## "do these characters appear anywhere in the results file", a longer-named
## device answering would cover for a shorter-named one that produced nothing
## -- which is the exact silence this whole report exists to remove.
set Q7DEVS [list @m.xz1.mzmod @m.xz1.mzmod_lvt]
o_wr $QD_RAW [q_rawdevs [list @m.xz1.mzmod_lvt]]
set Q7R [q_direct $QD_ST [q_blkdevs $Q7DEVS] 0]
set Q7 $Q7R
if {$Q7R ne {NOPROC} && ![string match RAISED:* $Q7R]} {
  set q7h [q_hits [lindex $Q7R 1] [list @m.xz1.mzmod]]
  set Q7 [list [lindex $Q7R 0] \
               [llength $q7h] \
               [expr {[llength $q7h] == 1 ?
                      [string first {_lvt} [lindex $q7h 0]] : -99}] \
               [expr {[llength $q7h] == 1 ?
                      [q_has [q_ints [lindex $q7h 0]] {2 1}] : 0}]]
}
check {Q7 issue 0965 a device whose name is the FRONT of another device's name\
 is still reported when it comes back with nothing -- the longer one answering\
 does not cover for it} \
  $Q7 {op_numbers_missing 1 -1 1}

## Q8 -- ISSUE 0972, A BUS PUTS A BRACKET INSIDE THE DEVICE NAME. Measured on
## the shipped sky130_tests_ase/sky130_mismatch bench, whose ten matched
## transistors are one symbol named M1[9:0] and whose save cards read
## `.save @m.xm1[9:0].msky130_fd_pr__nfet_01v8[id]`. Cutting the parameter off
## at the FIRST bracket answered `@m.xm1` -- not a device, and the same key for
## every member of the bus, so one member answering covered for all the rest.
## Both halves are here: the names the write line would carry, and the report.
set Q8DEVS [list {@m.xz1[3].mzmod} {@m.xz1[7].mzmod}]
o_wr $QD_RAW [q_rawdevs [list {@m.xz1[7].mzmod}]]
set Q8R [q_direct $QD_ST [q_blkdevs $Q8DEVS] 0]
set Q8 $Q8R
if {$Q8R ne {NOPROC} && ![string match RAISED:* $Q8R]} {
  set Q8 [list [o_ans ase::op_cards_devices [q_blkdevs $Q8DEVS]] \
               [lindex $Q8R 0] \
               [llength [q_hits [lindex $Q8R 1] [list {@m.xz1[3].mzmod}]]] \
               [llength [q_hits [lindex $Q8R 1] [list {@m.xz1[7].mzmod}]]]]
}
check {Q8 issue 0972 when the same symbol stands for a whole bus of\
 transistors each member keeps its own full name, so the run asks for names\
 that exist and names the member that came back with nothing instead of\
 letting its neighbour answer for it} \
  $Q8 [list $Q8DEVS op_numbers_missing 1 0]

## Q9 -- "I COULD NOT WORK OUT WHERE THE FILE WOULD BE" IS NOT "THERE IS NO
## FILE". Two ways in: a simulator with no results-file hook at all, and a
## design the hook itself refuses to answer for. Either way nothing was looked
## at, so telling the user their run produced no results would be a confident
## claim about a file nobody opened -- on the one surface built to stop exactly
## that. Silence is the honest answer.
o_wr $QD_RAW [q_rawdevs [list @m.xz1.mzmod]]
set Q9STA [o_state $AN_OP 1]
dict set Q9STA simulator zznosuchsim
set Q9STB [o_state $AN_OP 1]
dict unset Q9STB design
set Q9RA [q_direct $Q9STA [q_blkdevs $Q7DEVS] 0]
set Q9RB [q_direct $Q9STB [q_blkdevs $Q7DEVS] 0]
set Q9 {}
foreach q9r [list $Q9RA $Q9RB] {
  if {$q9r eq {NOPROC} || [string match RAISED:* $q9r]} { lappend Q9 $q9r ; continue }
  lappend Q9 [list [lindex $q9r 0] [llength [lindex $q9r 1]]]
}
check {Q9 issue 0965 when there was no way to tell where the results file would\
 even be, the run says nothing at all -- it never claims a file failed to\
 appear when it never went looking for one} \
  $Q9 {{{} 0} {{} 0}}

## Q10 -- A RUN THAT ALREADY FAILED LOUDLY IS NOT ALSO COUNTED AT. The same
## fixture Q7 reports on, at a nonzero exit: every device is missing by
## construction there, and a second sentence counting them buries the error the
## user actually has to read. The exit-0 half is in the row so the fixture
## cannot go vacuous.
o_wr $QD_RAW [q_rawdevs [list @m.xz1.mzmod_lvt]]
set Q10A [q_direct $QD_ST [q_blkdevs $Q7DEVS] 0]
set Q10B [q_direct $QD_ST [q_blkdevs $Q7DEVS] 1]
set Q10 [list $Q10A $Q10B]
if {$Q10A ne {NOPROC} && ![string match RAISED:* $Q10A] &&
    $Q10B ne {NOPROC} && ![string match RAISED:* $Q10B]} {
  set Q10 [list [lindex $Q10A 0] \
                [lindex $Q10B 0] [llength [lindex $Q10B 1]]]
}
check {Q10 a run that stopped with an error is not ALSO told how many device\
 numbers did not come back -- the error the user has to read stays the one\
 thing in front of them} \
  $Q10 {op_numbers_missing {} 0}

## Q11 -- STRUCTURAL, issue 0972: ONE SPLITTER, BOTH SIDES. The report compares
## the names the deck asked for with the names the results file answered for.
## If those two lists are cut apart at different places the comparison is a
## name against a differently-cut copy of itself, and it can only be right by
## luck. Nothing behavioural can see the two cuts drift while they drift
## together, which is why this row reads the source.
set Q11DEV [o_body ase::op_dev_of]
set Q11CD  [o_body ase::op_cards_devices]
set Q11RM  [o_body ase::op_report_missing]
check {Q11 issue 0972 STRUCTURAL the parameter suffix is cut off a device name\
 in ONE place, that place cuts at the last bracket rather than the first, and\
 both the write line and the run report go through it} \
  [list [expr {$Q11DEV eq {NOPROC} ? $Q11DEV : [o_count $Q11DEV {string last}]}] \
        [expr {$Q11DEV eq {NOPROC} ? $Q11DEV : [o_count $Q11DEV {string first}]}] \
        [expr {$Q11CD  eq {NOPROC} ? $Q11CD  : [o_count $Q11CD {op_dev_of}]}] \
        [expr {$Q11CD  eq {NOPROC} ? $Q11CD  : [o_count $Q11CD {string first}]}] \
        [expr {$Q11RM  eq {NOPROC} ? $Q11RM  : [o_count $Q11RM {op_dev_of}]}]] \
  {1 0 1 0 1}

## ============================================================================
## Q12-Q16 -- ISSUE 0975: THE SENTENCE THAT NAMES A CAUSE IT NEVER ESTABLISHED,
## AND SAYS "OF 1 DEVICES"
## ============================================================================
## WHAT THE USER READS TODAY WHEN NOTHING WHATEVER CAME BACK. The results file
## is there, it holds the transient, and it has no operating point in it at
## all. The run then tells them the deck spells a device differently from the
## way the schematic does -- a cause nothing in the code established, on the one
## surface built to stop exactly that kind of confident claim. Measured in the
## source: ase::sim_why's op_numbers_missing arm reads how many came back and
## interpolates it into the sentence, and the only `if` in the whole body is on
## how many names were left off the end of the list. There is no branch on it.
## So the same clause fires at three-of-five, where it is right, and at
## none-of-any, where nobody knows.
##
## AND THE BRIEF'S COROBBORATING DETAIL DID NOT REPRODUCE, which is itself part
## of the ruling. The bench was rendered and run through the real ngspice for
## the measurement pass: exit 0, a 284,283-byte results file, an Operating Point
## plot complete with 891 vectors, and ZERO singular-matrix or convergence lines
## in the log. So the honest statement is that the code asserts a cause it never
## established -- not that the real cause is a non-converging operating point.
## The replacement sentence therefore names no cause at all and points at the
## log the simulator itself wrote.
##
## THE PLURAL. "of 1 devices" and "These are the ones it did not answer for"
## both render with no singular form. Two clauses, one fix.

## Q12 -- NOTHING CAME BACK. A results file that exists, holds a transient and
## has no operating point in it: the shape the user actually runs, measured on
## the bench with the short form and one unmatchable name.
o_wr $QD_RAW "$TITLE$TRHDR"
set Q12DEVS [list @m.xz1.mzmod]
set Q12R [q_direct $QD_ST [q_blkdevs $Q12DEVS] 0]
set Q12 $Q12R
if {$Q12R ne {NOPROC} && ![string match RAISED:* $Q12R]} {
  set q12l {}
  foreach l [lindex $Q12R 1] {
    if {[string first zzcell_ase.raw $l] >= 0 ||
        [string first {came back} $l] >= 0} { lappend q12l $l }
  }
  set q12s [expr {[llength $q12l] == 1 ? [lindex $q12l 0] : {}}]
  set Q12 [list [lindex $Q12R 0] [llength $q12l] \
                [expr {[string first {spells a device differently} $q12s] >= 0 ? 1 : 0}] \
                [expr {[string first {log} $q12s] >= 0 ? 1 : 0}]]
}
check {Q12 issue 0975 GUARD NB-ZERO when the results file is there and holds no\
 operating point at all, the run says so and stops -- it does not tell the user\
 their deck spells a device differently, which is a cause nothing here\
 established, and it points them at the log their simulator wrote instead} \
  $Q12 {op_numbers_none 1 0 1}

## Q13 -- THE CONTROL, and the reason the cause clause is kept rather than
## deleted. Some came back and some did not, which is issue 0965's own case;
## there a differently-spelled device really is the likely reason and saying so
## is the whole value of the sentence.
set Q13DEVS [list @m.xz1.mzmod @m.xz2.mzmod @m.xz3.mzmod @m.xz4.mzmod @m.xz5.mzmod]
o_wr $QD_RAW [q_rawdevs [lrange $Q13DEVS 0 2]]
set Q13R [q_direct $QD_ST [q_blkdevs $Q13DEVS] 0]
set Q13 $Q13R
if {$Q13R ne {NOPROC} && ![string match RAISED:* $Q13R]} {
  set q13l [q_hits [lindex $Q13R 1] [lrange $Q13DEVS 3 4]]
  set q13s [expr {[llength $q13l] == 1 ? [lindex $q13l 0] : {}}]
  set Q13 [list [lindex $Q13R 0] [llength $q13l] \
                [expr {[string first {spells a device differently} $q13s] >= 0 ? 1 : 0}]]
}
check {Q13 the three-of-five shape still tells the user the likely reason,\
 because there it is the right one -- the fix for the all-or-nothing shape must\
 not throw away the sentence that issue 0965 was closed on} \
  $Q13 {op_numbers_missing 1 1}

## Q14 -- THE PLURAL, both kinds and both clauses. One device is a device.
proc q_said {r} {
  if {$r eq {NOPROC} || [string match RAISED:* $r]} { return {} }
  set out {}
  foreach l [lindex $r 1] {
    if {[string first {operating-point numbers of} $l] >= 0} { lappend out $l }
  }
  return [expr {[llength $out] == 1 ? [lindex $out 0] : {}}]
}
o_wr $QD_RAW "$TITLE$TRHDR"
set Q14A [q_said [q_direct $QD_ST [q_blkdevs [list @m.xz1.mzmod]] 0]]
set Q14B [q_said [q_direct $QD_ST [q_blkdevs [list @m.xz1.mzmod @m.xz2.mzmod]] 0]]
o_wr $QD_RAW [q_rawdevs [list @m.xz1.mzmod]]
set Q14C [q_said [q_direct $QD_ST [q_blkdevs [list @m.xz1.mzmod @m.xz2.mzmod]] 0]]
set Q14D [q_said [q_direct $QD_ST \
  [q_blkdevs [list @m.xz1.mzmod @m.xz2.mzmod @m.xz3.mzmod]] 0]]
puts "MEASURE Q14 one-none>>>$Q14A<<<"
puts "MEASURE Q14 two-of-three>>>$Q14D<<<"
check {Q14 issue 0975 one device is spoken of as one device, not as 1 devices,\
 and the one name it did not answer for is spoken of as one name -- in both\
 kinds of sentence and in both of the clauses that count} \
  [list [expr {$Q14A ne {} && [string first {1 devices} $Q14A] < 0 &&
               [string first {1 device} $Q14A] >= 0 ? 1 : 0}] \
        [expr {$Q14B ne {} && [string first {2 devices} $Q14B] >= 0 ? 1 : 0}] \
        [expr {$Q14C ne {} && [string first {This is the one} $Q14C] >= 0 &&
               [string first {These are the ones} $Q14C] < 0 ? 1 : 0}] \
        [expr {$Q14D ne {} && [string first {These are the ones} $Q14D] >= 0 ? 1 : 0}]] \
  {1 1 1 1}

## Q15 -- STRUCTURAL, ruling D5-4. The new sentence is written where a run's
## sentences are written, and the report only chooses it.
set Q15WHY [o_body ase::sim_why]
set Q15RM  [o_body ase::op_report_missing]
check {Q15 RULING D5-4 STRUCTURAL the nothing-came-back sentence exists exactly\
 once, in the one place a run's sentences are written, and the part of the run\
 that decides which sentence to say holds none of its words} \
  [list [expr {$Q15WHY eq {NOPROC} ? $Q15WHY : [o_count $Q15WHY {op_numbers_none}]}] \
        [expr {$Q15RM  eq {NOPROC} ? $Q15RM  :
               [expr {[o_count $Q15RM {op_numbers_none}] >= 1 ? 1 : 0}]}] \
        [expr {$Q15RM  eq {NOPROC} ? $Q15RM  : [o_count $Q15RM {came back}]}]] \
  {1 1 0}

## Q16 -- PLAIN ENGLISH, the same ban list Q6 applies to this sentence's
## siblings, plus the kind the report decided it was in, so a sentence that is
## merely quiet cannot satisfy the row.
o_wr $QD_RAW "$TITLE$TRHDR"
set Q16R [q_direct $QD_ST [q_blkdevs $Q12DEVS] 0]
set Q16 {}
set Q16K NOPROC
if {$Q16R ne {NOPROC} && ![string match RAISED:* $Q16R]} {
  set Q16K [lindex $Q16R 0]
  foreach s [lindex $Q16R 1] {
    if {$s eq {}} continue
    if {[string length $s] < 80} { lappend Q16 [list SHORT $s] }
    foreach w {blanket tier optier saveopparams appendwrite hier_op_names\
               blanket_op_save vector .save .control remzerovec op_numbers} {
      if {[string first $w [string tolower $s]] >= 0} { lappend Q16 [list $w $s] }
    }
  }
}
check {Q16 PLAIN ENGLISH the nothing-came-back sentence uses no word out of the\
 code and is a real explanation rather than a bare state name} \
  [list $Q16 $Q16K] {{} op_numbers_none}

## Q17 -- ISSUE 0975, THE SHARPER HALF OF GUARD NB-ZERO, caught by the
## verification pass before this ever shipped. "None of the devices I asked
## about came back" and "this results file holds no operating point" are NOT
## the same fact, and the code has the one that tells them apart sitting in a
## local -- the operating-point plot it has just read. A sheet with ONE device
## whose name is misspelled leaves every requested device missing while the
## operating point sits complete in the file. The honest sentence there is the
## one that names the spelling; the all-or-nothing sentence would tell the user
## their operating point never finished and send them to a log with nothing
## wrong in it. Issue 0975's own worked example, a single @m.xz1.mzmod, is
## exactly this shape, so the first fix for 0975 made its own example worse.
o_wr $QD_RAW [q_rawdevs [list @m.xzother.mzmod]]
set Q17R [q_direct $QD_ST [q_blkdevs [list @m.xz1.mzmod]] 0]
set Q17 $Q17R
if {$Q17R ne {NOPROC} && ![string match RAISED:* $Q17R]} {
  set q17s [q_said $Q17R]
  puts "MEASURE Q17>>>$q17s<<<"
  set Q17 [list [lindex $Q17R 0] \
                [expr {[string first {spells a device differently} $q17s] >= 0 ? 1 : 0}] \
                [expr {[string first {no operating point in it} $q17s] >= 0 ? 1 : 0}]]
}
check {Q17 issue 0975 when every device asked about is missing but the results\
 file DOES hold an operating point, the run gives the likely spelling reason\
 and never claims the operating point is absent -- the all-or-nothing sentence\
 belongs to a file with no operating point in it, not to a name nothing\
 matched} \
  $Q17 {op_numbers_missing 1 0}

catch {file delete -- $QD_RAW}
ase::op_cards_put $NL $BLK5

# ============================================================================
# S-NEW. WHERE THE NEW SENTENCES LIVE, AND WHAT THE OLD ONES MAY STILL CLAIM
# ============================================================================
set Q_NEWKINDS {}
foreach q6r [list $Q1R $Q3R] {
  if {$q6r eq {NOPROC} || [string match RAISED:* $q6r]} { continue }
  foreach k [lindex $q6r 2] {
    if {[string match op_tier* $k]} { continue }
    if {[lsearch -exact $Q_NEWKINDS $k] < 0} { lappend Q_NEWKINDS $k }
  }
}
set S11WHY [o_body ase::sim_why]
set S11 {}
foreach k $Q_NEWKINDS { lappend S11 [o_count $S11WHY $k] }
check {S11 RULING D5-4 the asked-for-and-did-not-come-back sentence and the\
 no-results-file sentence each exist exactly once, in the one place a run's\
 sentences are written} \
  [list [llength $Q_NEWKINDS] $S11] {2 {1 1}}

set S12 [o_ans ase::sim_why op_tier_blanket ngspice /usr/bin/zzsim {}]
check {S12 issue 0966 the sentence for the short-and-wide form no longer tells\
 the user their deck names no devices, because after this change it names one\
 per device} \
  [expr {($S12 eq {NOPROC} || [string match RAISED:* $S12]) ? $S12 :
         [expr {[string first {names no devices} $S12] < 0 ? 1 : 0}]}] 1

set S13 [o_ans ase::sim_why op_tier_perdevice ngspice /usr/bin/zzsim unsafe]
check {S13 guard G4 STAYS, and the sentence that explains it still tells the\
 user the risk in the words the measurement supports -- one unmatched device\
 name and the whole operating point is gone, with no complaint} \
  [expr {($S13 eq {NOPROC} || [string match RAISED:* $S13]) ? $S13 :
         [list [expr {[string first {all or nothing} [string tolower $S13]] >= 0 ? 1 : 0}] \
               [expr {[string first {throws the whole operating point away} $S13] >= 0 ? 1 : 0}]]}] \
  {1 1}

# ============================================================================
# N. THE USER'S OWN BENCH -- EVERY DEVICE NAME MUST BE ONE THE DECK CONTAINS
# ============================================================================
# ISSUE 0965, MEASURED ON sky130_tests_ase/tb_bandgap. The tree emitted 468
# requests naming 78 distinct devices, and two of those names were not in the
# deck at all. Both were passgates whose schematic line overrides the
# transistor model with modelp=pfet_01v8_lvt, while passgate.sym's format=
# string never mentions modelp -- so the netlister wrote ONE .subckt passgate
# body from the SYMBOL TEMPLATE default and the override never reached the
# deck. The name builder asked the live design instead and got the override.
# Cost to the user: 12 blank annotation rows out of 468 on their own bench, and
# not one word anywhere.
#
# ISSUE 0970 IS THE OTHER HALF OF THE SAME SENTENCE, AND IT IS WHY ROWS N2, N3
# AND N4 NOW SAY THE OPPOSITE OF WHAT THEY USED TO. Naming the two transistors
# the way the deck spells them stopped the blank rows, but it left the user's
# typed override doing nothing: those two passgates had never been simulated
# with the low-threshold device their schematic line names. The repair is on
# the SHEET -- the two instances ask for a copy of the cell of their own -- so
# the deck now carries a second passgate body built with the model they asked
# for, and the annotation asks for THAT name. The rows below are the pin.
#
# THIS SECTION NEEDS NO SIMULATOR. The deck's own call graph is enough to say
# whether a name it emits can be found, and op_annot already builds that graph
# for its own walk. Section NM of tests/headless/test_op_annot.tcl holds the
# same finding at unit scale on a fixture.

set N_SKY [file join $repo sky130A xschem_libs]
set N_BG  [file join $N_SKY sky130_tests_ase tb_bandgap schematic tb_bandgap.sch]

## Walk one emitted device name through the DECK's own call graph. Answers OK,
## or the plain-English reason it is not there.
proc n_resolve {idx name} {
  if {[string range $name 0 2] ne {@m.}} { return "not a device name: $name" }
  set callee [dict get $idx callee]
  set blocks [dict keys $callee]
  set cur [dict get $idx top]
  set segs [split [string range $name 3 end] .]
  set i 0
  while {$i < [llength $segs]} {
    set s [lindex $segs $i]
    if {![dict exists $callee $cur] || ![dict exists [dict get $callee $cur] $s]} {
      return "there is no part called \"$s\" inside \"$cur\""
    }
    set c [dict get [dict get $callee $cur] $s]
    if {[lsearch -exact $blocks $c] >= 0} { set cur $c ; incr i ; continue }
    set leaf [join [lrange $segs [expr {$i + 1}] end] .]
    if {$leaf eq "m$c"} { return OK }
    return "part \"$s\" inside \"$cur\" uses model \"$c\", so the deck spells it\
 \"m$c\" and not \"$leaf\""
  }
  return "the name ran out before it named a device, inside \"$cur\""
}
proc n_dsc {nm} {
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem getprop instance $i name] eq $nm} {
      xschem unselect_all ; xschem select instance $i ; xschem descend 1 2 ; return 1
    }
  }
  return 0
}

## ISSUE 0979, AND IT IS WHY N4 CANNOT USE n_dsc ABOVE. After the issue 0970
## repair, x5 and x6 carry `schematic=passgate_lvtp`, which names no file on
## disk on purpose -- that is the library author's own idiom, taught on the
## shipped sky130_tests/gain_stage sheet and already used by three shipped
## instances, and it is what makes the netlister write a SECOND cell body with
## the model this copy asked for.
##
## Opening such an instance falls back to the cell's own base sheet. THE PRODUCT
## DOES THAT FOR THE USER: the right-click canvas item has always asked "open
## this cell's own schematic instead?" and landed the person in passgate.sch.
## The `xschem descend` COMMAND could not -- all three of its forms passed
## fallback as a hard 0 -- so a script got a blank sheet, one level down, with no
## word said. That was issue 0979, and this row used to work around it by arming
## the one-shot `hi_descend_view_path` override by hand.
##
## ISSUE 0979 IS NOW FIXED, so the workaround is gone: the row simply asks for the
## fallback, `xschem descend -fallback`, which is the same capability the
## right-click item always had. A workaround left standing behind a fix is how the
## next reader concludes the fix does not work.
## No dialog can hang a GUI suite on this (issue 0803 was the fear): the question
## is only asked when there is a display AND the caller asked for the fallback,
## and it now has two buttons instead of three.
## The assertion below is untouched by any of this; only the way the row reaches
## the sheet the user reaches has changed.
proc n_dsc_base {nm} {
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem getprop instance $i name] ne $nm} { continue }
    xschem unselect_all ; xschem select instance $i
    xschem descend -fallback 1 2
    return [expr {[xschem get instances] > 0 ? 1 : 0}]
  }
  return 0
}

## ISSUE 0970: THESE ARE THE NAMES THE DECK MUST CONTAIN AFTER THE REPAIR, not
## the ones it held before it. The standard-threshold spelling is DERIVED from
## them rather than typed out again, so the two halves of every row below
## cannot drift apart, and section N5's budget on literal device names holds.
set N_X5 {@m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt}
set N_X6 {@m.x1.x6.xm2.msky130_fd_pr__pfet_01v8_lvt}
set N_S5 [string range $N_X5 0 end-4]
set N_S6 [string range $N_X6 0 end-4]
if {![file isfile $N_BG]} {
  foreach nrow {N1 N2 N3 N4} {
    check "$nrow the shipped bandgap bench" BENCH-ABSENT BENCH-PRESENT
  }
} else {
  set XSCHEM_LIBRARY_PATH ":$N_SKY:[file join $repo xschem_library devices]"
  catch {uplevel #0 [list source [file join $repo sky130A sky130_procs.tcl]]}
  catch {xschem raw clear}
  xschem load $N_BG
  set N_BLK [o_ans op_annot::save_cards]
  set N_WARN [o_ans op_annot::last_warnings]
  set N_CNT  [o_ans op_annot::last_counts]
  set N_DEVS {}
  set N_NAMES {}
  if {$N_BLK ne {NOPROC} && ![string match RAISED:* $N_BLK]} {
    set N_DEVS  [o_ans ase::op_cards_devices $N_BLK]
    set N_NAMES [o_ans ase::op_cards_names $N_BLK]
  }
  set N_IDX {}
  catch {set N_IDX [op_annot::_deck_index [op_annot::_oracle_deck]]}
  set N_ABSENT {}
  if {$N_IDX ne {} && [llength $N_DEVS]} {
    foreach nd $N_DEVS {
      set r [n_resolve $N_IDX $nd]
      if {$r ne {OK}} { lappend N_ABSENT [list $nd $r] }
    }
  }
  foreach na $N_ABSENT { puts "N-ABSENT: [lindex $na 0] -> [lindex $na 1]" }

  check {N1 issue 0965 EVERY device the annotation asks the simulator about on\
 the shipped bandgap bench is one the deck that runs actually contains -- all\
 78 of them, not 76} \
    [list [llength $N_NAMES] [llength $N_DEVS] [llength $N_ABSENT]] \
    {468 78 0}

  set N2 {}
  if {[llength $N_DEVS]} {
    set N2 [list [expr {[lsearch -exact $N_DEVS $N_X5] >= 0 ? 1 : 0}] \
                 [expr {[lsearch -exact $N_DEVS $N_X6] >= 0 ? 1 : 0}] \
                 [expr {[lsearch -exact $N_DEVS $N_S5] >= 0 ? 1 : 0}] \
                 [expr {[lsearch -exact $N_DEVS $N_S6] >= 0 ? 1 : 0}]]
  }
  check {N2 issue 0970 the two passgate transistors whose schematic line asks\
 for the low-threshold device are asked for under THAT name, because that is\
 now the device the deck builds them from -- and the ordinary p-device name\
 they used to be simulated as is not asked for at all} \
    $N2 {1 1 0 0}

  set N3 NOPROC
  if {$N_WARN ne {NOPROC} && ![string match RAISED:* $N_WARN] &&
      $N_CNT ne {NOPROC} && ![string match RAISED:* $N_CNT]} {
    set n3x5 0 ; set n3x6 0
    foreach w $N_WARN {
      set hasboth [expr {[string first pfet_01v8_lvt $w] >= 0 &&
                         [regexp {pfet_01v8[^_]} "$w "] }]
      if {[string first x5 $w] >= 0 && $hasboth} { incr n3x5 }
      if {[string first x6 $w] >= 0 && $hasboth} { incr n3x6 }
    }
    set n3extra {}
    catch {
      dict for {k v} $N_CNT {
        if {[lsearch -exact {dropped_by_rule not_found name_failed} $k] < 0} {
          lappend n3extra $k $v
        }
      }
    }
    set N3 [list [llength $N_WARN] $n3x5 $n3x6 [llength $n3extra] [lindex $n3extra 1]]
  }
  check {N3 issue 0970 RULING D5-1 there is nothing left on this bench for the\
 run to report: the model the schematic names and the model the deck builds\
 agree on all five passgates, so the run says nothing and counts no\
 disagreement. The guard that speaks when they DO disagree is still exercised,\
 on a fixture that cannot be repaired away -- rows GC1 to GC5 of\
 tests/headless/test_unused_attr_0970.tcl} \
    $N3 {0 0 0 2 0}

  set N4 NOPROC
  catch {xschem load $N_BG}
  if {[n_dsc x1] && [n_dsc_base x5]} {
    set N4 [list [o_ans op_annot::devpath M2] [o_ans op_annot::devpath M2 deck .]]
  }
  check {N4 issue 0965 and 0970 the name the rows ON THE SCHEMATIC are read\
 under is the same name the request was made under, on both bases, and it is\
 the low-threshold name -- otherwise the numbers would be saved and then\
 looked up under a spelling nothing wrote} \
    $N4 [list $N_X5 $N_X5]
}

set N5SRC [o_nocomment [o_slurp [info script]]]
check {N5 STRUCTURAL the bench rows read the deck's own call graph rather than\
 a list of device names copied into this file, so they keep measuring the tree\
 and not a snapshot of it} \
  [list [expr {[o_count $N5SRC {@m.x1.}] <= 8 ? 1 : 0}] \
        [expr {[o_count $N5SRC {_deck_index}] >= 1 ? 1 : 0}]] \
  {1 1}


# ============================================================================
# X. THE ACCEPTANCE, ON THE USER'S OWN BENCH AND A REAL RUN (issue 0969)
# ============================================================================
# ISSUE 0969 IS THAT THE ACCEPTANCE FOR ALL OF THIS WAS PINNED ON A TOY. The
# rows above measure one level-1 transistor in two nested subcircuits, and the
# defect that costs the user twelve blank rows lives on a PDK bench, four
# levels down, in a cell that is instanced five times with two of them
# overriding a model attribute. So this section runs
# sky130_tests_ase/tb_bandgap for real.
#
# THE TRANSIENT IS SHORTENED, AND ONLY THE TRANSIENT. The committed bench asks
# for `tran 10n 200u`, which is 20,505 points and about 16 s. Every row here is
# about the SHAPE of the deck and the SPELLING of what comes back, and neither
# depends on how long the transient runs. Measured with `tran 1u 2u`: the whole
# thing -- netlist, run, read -- takes about 4 s, the deck is the committed
# bench's own deck, and the operating point is identical.
#
# WHAT THIS SECTION MEASURED BEFORE ANY FIX, so a later reader can tell whether
# it is still measuring: 468 requests naming 78 devices, 456 vectors back, 12
# blank rows, and the two names that came back with nothing were
# x5.xm2 and x6.xm2 in the passgate cell.

set X_ROOT  [file join $repo sky130A xschem_libs sky130_tests_ase tb_bandgap]
set X_STATE [file join $X_ROOT ngspice_state1 tb_bandgap.state]
set X_SCH   [file join $X_ROOT schematic tb_bandgap.sch]
set X_TRAN  {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 2u step 1u}}
set X_OPONLY {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}

proc x_skip {why} {
  foreach r {X1 X2 X3 X4 X5 X7} { check "$r on the shipped bandgap bench" $why RAN }
}

if {[auto_execok ngspice] eq {} || ![file isfile $X_SCH] || ![file isfile $X_STATE]} {
  x_skip [expr {[auto_execok ngspice] eq {} ? {NO-NGSPICE} : {NO-BENCH}}]
} else {

## The bench, opened the way the product opens it, with its own committed
## settings and its own rundir under the scratch area.
set X_RUN [file join $scratch xrun]
file delete -force $X_RUN
file mkdir $X_RUN
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]
set X_DEFS [file join $scratch xlibrary.defs]
set fx [open $X_DEFS w]
foreach xl {sky130_tests_ase sky130_tests sky130_fd_pr} {
  puts $fx "DEFINE $xl [file join $repo sky130A xschem_libs $xl]"
}
puts $fx "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $fx
set ::XSCHEM_LIBRARY_DEFS $X_DEFS
set ::library_registry_defs_only 1
catch {uplevel #0 [list source [file join $repo sky130A sky130_procs.tcl]]}
o_unprime
o_force {}
catch {xschem raw clear}
xschem load $X_SCH
set X_KEY {}
set X_DSG {}
catch {set X_DSG [ase::design_of_path [file normalize $X_SCH]]}
if {[llength $X_DSG] == 3} {
  set X_KEY [ase::session_key {*}$X_DSG]
  catch {ase::session_open $X_KEY $X_STATE}
}

## ONE WHOLE RUN OF THE BENCH. `doctor` is a list of extra requests to smuggle
## into the captured block after the netlist is written and before the deck is
## rendered -- the seam ase::run_deck itself reads. It is how a device name the
## simulator cannot match is produced ON PURPOSE once the two real ones are
## fixed, which is what guard G4's reason has to be measured against.
## ONE WHOLE RUN OF THE BENCH. `doctor` is a list of extra requests smuggled
## into the captured block after the netlist is written and before the deck is
## rendered -- the seam ase::run_deck itself reads. It is how a device name the
## simulator cannot match is produced ON PURPOSE once the two real ones are
## fixed, which is what guard G4's reason has to be measured against. The
## netlist path travels in a global because q_run takes a script, not
## arguments.
proc x_run2 {tier analyses gate doctor} {
  global X_KEY X_RUN
  if {$X_KEY eq {}} { return NOSESSION }
  set st [ase::session_state $X_KEY]
  dict set st rundir $X_RUN
  dict set st save_op_params $gate
  dict set st analyses $analyses
  ase::session_update $X_KEY $st
  o_force $tier
  if {[catch {ase::netlist [ase::session_state $X_KEY]} nl]} { o_force {} ; return "NLRAISED:$nl" }
  set ::x_nl $nl
  set blk [ase::op_cards_block]
  if {[llength $doctor]} {
    set nt [o_slurp $nl]
    set nb [string trimright $blk "\n"]
    foreach dcard $doctor { append nb "\n$dcard" }
    ase::op_cards_put $nt "$nb\n"
    set blk [ase::op_cards_block]
  }
  set decktext [o_render [ase::session_state $X_KEY] [o_slurp $nl]]
  set raw [o_rawhook [ase::session_state $X_KEY]]
  catch {file delete -force -- $raw}
  set t0 [clock milliseconds]
  set said [q_run {
    if {[catch {ase::run_deck [ase::session_state $::X_KEY] $::x_nl} xid]} {
      set ::x_rc "RUNRAISED:$xid"
    } else { set ::x_rc [ase::wait $xid] }
  }]
  set ms [expr {[clock milliseconds] - $t0}]
  o_force {}
  set sz -1
  if {$raw ne {} && [file isfile $raw]} { set sz [file size $raw] }
  return [dict create rc $::x_rc raw $raw rawbytes $sz wall $ms \
    deckbytes [string length $decktext] \
    decklines [llength [split [string trimright $decktext "\n"] "\n"]] \
    names [ase::op_cards_names $blk] devices [ase::op_cards_devices $blk] \
    said [expr {($said eq {NOPROC} || [string match RAISED:* $said]) ? {} : [lindex $said 0]}]]
}
## How many of the requests came back with a vector, and which devices did not.
proc x_backfill {r} {
  if {![string is list $r] || [catch {dict get $r raw} raw]} { return NORUN }
  if {$raw eq {} || ![file isfile $raw]} { return NORAW }
  set vars [o_plotvars $raw {Operating Point}]
  if {$vars eq {NO-FILE} || $vars eq {NO-PLOT}} { return $vars }
  set back 0
  foreach n [dict get $r names] {
    foreach v $vars { if {[string first $n $v] >= 0} { incr back ; break } }
  }
  set miss {}
  foreach d [dict get $r devices] {
    set hit 0
    foreach v $vars { if {[string first $d $v] >= 0} { set hit 1 ; break } }
    if {!$hit} { lappend miss $d }
  }
  return [list [llength [dict get $r names]] $back $miss]
}
proc x_num {r k} {
  if {![string is list $r] || [catch {dict get $r $k} v]} { return NA }
  return $v
}

set XC [x_run2 c $X_TRAN 1 {}]
set XCB [x_backfill $XC]
puts "MEASURE X bench form=c rc=[x_num $XC rc] deck=[x_num $XC deckbytes]bytes/[x_num\
 $XC decklines]lines wall=[x_num $XC wall]ms raw=[x_num $XC rawbytes]bytes\
 asked=[llength [x_num $XC names]] devices=[llength [x_num $XC devices]] back/miss=$XCB"

check {X1 issue 0965 on the user's own bandgap bench every one of the requests\
 this run made comes back with a number -- no transistor on that sheet is left\
 with blank rows and no explanation} \
  [expr {[string is list $XCB] && [llength $XCB] == 3 ?
         [list [expr {[lindex $XCB 0] > 0 ? 1 : 0}] \
               [expr {[lindex $XCB 0] - [lindex $XCB 1]}] [lindex $XCB 2]] : $XCB}] \
  {1 0 {}}

set XB [x_run2 b $X_TRAN 1 {}]
set XBB [x_backfill $XB]
puts "MEASURE X bench form=b rc=[x_num $XB rc] deck=[x_num $XB deckbytes]bytes/[x_num\
 $XB decklines]lines wall=[x_num $XB wall]ms raw=[x_num $XB rawbytes]bytes back/miss=$XBB"

## The per-device per-parameter comparison the acceptance asks for: every value
## the long form saved, read back the way the annotation reads it, against the
## same value out of the short form's own results file.
set X2DIFF ZZNOTRUN
if {[string is list $XCB] && [llength $XCB] == 3 &&
    [string is list $XBB] && [llength $XBB] == 3} {
  set X2DIFF {}
  set cvars [o_devvars [o_plotvars [dict get $XC raw] {Operating Point}]]
  set bvars [o_devvars [o_plotvars [dict get $XB raw] {Operating Point}]]
  if {[string is list $cvars] && [string is list $bvars]} {
    catch {xschem annotate_op [dict get $XC raw] 0 op}
    set cval [dict create]
    foreach v $cvars { dict set cval $v [o_readone $v] }
    catch {xschem annotate_op [dict get $XB raw] 0 op}
    foreach v $cvars {
      set bare $v
      regexp {^[iv]\((.*)\)$} $v -> bare
      if {[lsearch -exact $bvars $bare] < 0} { lappend X2DIFF [list $v ABSENT] ; continue }
      if {[o_readone $bare] ne [dict get $cval $v]} {
        lappend X2DIFF [list $v [dict get $cval $v] [o_readone $bare]]
      }
    }
  } else { set X2DIFF [list $cvars $bvars] }
}
check {X2 issue 0969 the two ways of asking give the SAME numbers on the real\
 bench, device by device and parameter by parameter -- the deck size, the time\
 taken and the results size are printed above, and this row is what says the\
 shorter way is not shorter by losing something} \
  [list [expr {[string is list $XBB] && [llength $XBB] == 3 ? [lindex $XBB 2] : $XBB}] $X2DIFF] \
  {{} {}}

## X3 -- WHY GUARD G4 STAYS. One device name that cannot be matched, put there
## deliberately, so this stays measurable after the two real ones are fixed.
set X_BADCARD {.save @m.x1.xzznosuchdevice.mzznosuchmodel[gm]}
set XBD [x_run2 b $X_OPONLY 1 [list $X_BADCARD]]
set XCD [x_run2 c $X_OPONLY 1 [list $X_BADCARD]]
proc x_saysdev {r dev} {
  if {![string is list $r] || [catch {dict get $r said} ls]} { return NORUN }
  set n 0
  foreach l $ls { if {[string first $dev $l] >= 0} { incr n } }
  return $n
}
proc x_saysfile {r} {
  if {![string is list $r] || [catch {dict get $r said} ls]} { return NORUN }
  set n 0
  foreach l $ls { if {[string first tb_bandgap_ase.raw $l] >= 0} { incr n } }
  return $n
}
set XCDB [x_backfill $XCD]
check {X3 guard G4 STAYS, and here is the measurement it stands on: one device\
 name the simulator cannot match costs the short form the WHOLE operating\
 point and no results file at all, while the safe form keeps every other\
 device -- and the run now says so in both cases instead of leaving the user\
 with a blank schematic} \
  [list [x_num $XBD rc] [expr {[x_num $XBD rawbytes] < 0 ? 1 : 0}] [x_saysfile $XBD] \
        [x_num $XCD rc] \
        [expr {([string is list $XCDB] && [llength $XCDB] == 3) ?
               [lindex $XCDB 2] : $XCDB}] \
        [x_saysdev $XCD {@m.x1.xzznosuchdevice.mzznosuchmodel}]] \
  [list 0 1 1 0 {@m.x1.xzznosuchdevice.mzznosuchmodel} 1]

## X4 -- 0969's second gap, as a RUN and not a grep: the device numbers must
## not ride the transient. Measured before this work: they did, at every one of
## 20,505 timepoints, and the results file was 144 MB instead of 69 MB.
set XG0 [x_run2 c $X_TRAN 0 {}]
proc x_trannodes {r} {
  if {![string is list $r] || [catch {dict get $r raw} raw]} { return NORUN }
  if {$raw eq {} || ![file isfile $raw]} { return NORAW }
  set vars [o_plotvars $raw {Transient Analysis}]
  if {![string is list $vars]} { return $vars }
  set n 0
  foreach v $vars { if {[string first {@} $v] < 0} { incr n } }
  return $n
}
puts "MEASURE X bench tick-off rc=[x_num $XG0 rc] raw=[x_num $XG0 rawbytes]bytes\
 tran-node-vectors=[x_trannodes $XG0] (tick-on [x_trannodes $XC])"
check {X4 issue 0964 asking for device numbers does not change what the\
 transient records: the same node voltages come back with the tick on as with\
 it off, and no device number rides the transient at all} \
  [list [x_trannodes $XC] [expr {[x_trannodes $XC] eq [x_trannodes $XG0] ? 1 : 0}] \
        [expr {[llength [o_devvars [o_plotvars [dict get $XC raw] {Transient Analysis}]]] == 0 ? 1 : 0}]] \
  [list [x_trannodes $XG0] 1 1]

## X5 -- the tier the bench really lands on, with this box's real ngspice and
## no priming at all. G4 must fire HERE, not only on a primed capability.
o_unprime
o_force {}
set X5ST [ase::session_state $X_KEY]
catch {dict set X5ST rundir $X_RUN}
catch {dict set X5ST save_op_params 1}
check {X5 guard G4 on the real bench with the real simulator: the short form is\
 still not chosen for anybody automatically} \
  [o_tr $X5ST] {c unsafe}

## X7 -- ISSUE 0970, AND IT IS THE ONLY ROW IN THE TREE THAT MEASURES A DEVICE
## RATHER THAN A NAME. Two passgates on this bench have a low-threshold
## p-device written on their schematic line. Until 0970 was repaired the deck
## built all five passgates from the same ordinary p-device, so the results file
## held no vector for the low-threshold one at all and those two transistors had
## never been simulated as what their sheet says they are. This row runs the
## bench and asks the results file itself: is the low-threshold device there,
## and did it measure something different from the passgates that did not ask?
## SELF-RELATIVE -- no threshold voltage is typed into this file, because a
## number typed here would stop measuring the tree the day the models move.
## ⚠ ITS OWN RUN, NOT $XC's. Every x_run2 writes to the SAME results path and
## deletes it first, so by the time this row is reached the file $XC named holds
## the tick-OFF run from X4 and carries no device numbers at all. Re-running is
## about four seconds and is the only way this row measures what it says.
set XF [x_run2 c $X_TRAN 1 {}]
set X7L {} ; set X7S {}
set X7V {}
set x7raw {}
if {[string is list $XF] && ![catch {dict get $XF raw} x7raw] &&
    $x7raw ne {} && [file isfile $x7raw]} {
  set X7V [o_plotvars $x7raw {Operating Point}]
}
puts "MEASURE X7 rc=[x_num $XF rc] raw=[x_num $XF rawbytes]bytes\
 op-vectors=[expr {[string is list $X7V] ? [llength $X7V] : $X7V}]"
if {[string is list $X7V]} {
  foreach x7v $X7V {
    if {[string first {[vth]} $x7v] < 0} { continue }
    if {[string first $N_X5 $x7v] >= 0} { set X7L $x7v }
    if {[string first {.x3.xm2.} $x7v] >= 0} { set X7S $x7v }
  }
}
set X7LV ZZNONE ; set X7SV ZZNONE
if {$X7L ne {} && $X7S ne {}} {
  catch {xschem annotate_op $x7raw 0 op}
  set X7LV [o_readone $X7L]
  set X7SV [o_readone $X7S]
}
puts "MEASURE X7 lvt-vector=$X7L value=$X7LV / standard-vector=$X7S value=$X7SV"
check {X7 issue 0970 the bench now really does simulate what its schematic\
 says: the results file holds the two overriding passgates under the\
 low-threshold device's own name -- a vector that did not exist before -- and\
 the threshold voltage it measured for them is not the one it measured for a\
 passgate that did not ask} \
  [list [expr {$X7L ne {} ? 1 : 0}] [expr {$X7S ne {} ? 1 : 0}] \
        [expr {($X7LV ne {ZZNONE} && $X7SV ne {ZZNONE} && $X7LV ne {} &&
                $X7SV ne {} && $X7LV ne $X7SV) ? 1 : 0}]] \
  {1 1 1}

}

## X6 -- the section's own discipline: nothing above is compared with a device
## count typed into this file. The counts come from the walk.
set X6SRC {}
set X6ON 0
foreach x6l [split [o_slurp [info script]] "\n"] {
  if {[string first {# X. THE ACCEPTANCE} $x6l] >= 0} { set X6ON 1 }
  if {[string first {# X6 -- the section} $x6l] >= 0} { set X6ON 0 }
  if {$X6ON && ![regexp {^\s*#} $x6l]} { lappend X6SRC $x6l }
}
set X6HIT {}
foreach x6l $X6SRC {
  foreach x6w {468 78 456 76} {
    if {[regexp -- "(^|\[^0-9\])${x6w}(\$|\[^0-9\])" $x6l]} { lappend X6HIT [list $x6w $x6l] }
  }
}
check {X6 STRUCTURAL no row on the bench is compared with a device count typed\
 into this file -- the counts come from the walk, so the rows keep measuring\
 the tree rather than a snapshot of it} \
  [list [expr {[llength $X6SRC] > 20 ? 1 : 0}] $X6HIT] {1 {}}

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
