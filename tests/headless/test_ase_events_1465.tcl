# tests/headless/test_ase_events_1465.tcl -- ISSUE 1465: A MIXED-SIGNAL RUN'S
# DIGITAL HALF NEVER REACHED THE WINDOW. PLAN.md Stage 12, event-driven results.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# XSPICE is compiled into every ngspice this batch supports, so a deck with a
# digital gate in it is an ordinary deck. Until this stage an ASE-L run of one
# produced a rawfile holding `time i(adac) v(aout) v(in) i(vin)` and NOT `din` or
# `dout` -- `write <f> all` omits every event node, silently -- and nothing else.
# The digital half was computed and thrown away.
#
# ============================================================================
# ⚠ THE FOUR MEASUREMENTS THIS SUITE IS BUILT ON (2026-09-15, apt 45.2 AND the
#   ngspice-46+ fork, identical unless a line says otherwise)
# ============================================================================
#  1. `edisplay` names the event nodes BEFORE a run, counts 0 -- so the names are
#     known before the deck that exports them is written (section CI).
#  2. `eprvcd` handed a word that is not an event node ABORTS 45.2 (`*** buffer
#     overflow detected ***`, rc 134, no VCD) while the fork writes a `real`
#     variable for it. So the export line carries the inventory's names and
#     nothing else, and a name the control-language lexer would split never
#     reaches it (sections EM and IP, and EE on the REAL 45.2).
#  3. `eprvcd` ends its file on the last VALUE CHANGE, never the end of the run,
#     so a held value was drawn as a trace that stops early. The attach now
#     extends every VCD of a transient to the analog database's own end
#     (sections AT and EE).
#  4. `.probe alli` beside a DIGITAL node exits 1 before anything is simulated;
#     beside an analog-only `a` card it runs at rc 0. So the refusal is read from
#     the simulator, never guessed from the netlist text (section RF).
#
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
#    sections IP PD CI EM CA RF LV AT -- pure Tcl and the C reader, through a
#                                         stand-in simulator; identical on both arms
#    section  EE -- starts the REAL simulators, BOTH of them, ten rows each;
#                   self-skips with the path printed when one is absent
#
# Runs headless (T1's `hcases`):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_events_1465.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch events1465]
catch {test_sim_registry_isolate}

## ⚠ EVERY READER IS TOTAL AND ANSWERS A COMPARABLE VALUE. `--nogui --pipe`
## exits 0 on an uncaught mid-script error, so a reader that raises would turn a
## defect into a suite that simply stops talking.
proc e_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {uplevel #0 [linsert $args 0 $cmd]} r]} { return "RAISED:$r" }
  return $r
}
proc e_dg {d args} {
  if {[catch {dict get $d {*}$args} v]} { return "NOKEY:[join $args /]" }
  return $v
}
proc e_wr {path text {mode {}}} {
  file mkdir [file dirname $path]
  set f [::open $path w]
  puts -nonewline $f $text
  ::close $f
  if {$mode ne {}} { file attributes $path -permissions $mode }
  return $path
}
proc e_slurp {path} {
  if {![file isfile $path]} { return "NOFILE:[file tail $path]" }
  set f [::open $path r]
  set t [read $f]
  ::close $f
  return $t
}
proc e_lines {text pat} {
  set out {}
  foreach l [split $text "\n"] { if {[regexp $pat $l]} { lappend out $l } }
  return $out
}
proc e_idx {text pat {from 0}} {
  set i 0
  foreach l [split $text "\n"] {
    if {$i >= $from && [regexp $pat $l]} { return $i }
    incr i
  }
  return -1
}
proc e_echoed {script} {
  set ::e_said {}
  set had [expr {[info commands ::ase::echo] ne {}}]
  if {$had} { rename ::ase::echo ::e_saved_echo }
  proc ::ase::echo {msg {tag {}}} { lappend ::e_said $msg ; return 1 }
  set ::e_echo_rc [catch {uplevel #0 $script} ::e_echo_res]
  catch {rename ::ase::echo {}}
  if {$had} { rename ::e_saved_echo ::ase::echo }
  return $::e_said
}

## THE SENTENCES, copied from the adapter so a row compares against the words the
## user reads rather than against a proc's return value.
set S_TRTOL {this circuit has XSPICE devices, so the simulator lowers trtol to 1 and takes smaller time steps than the options ask for}
set F_TRTOL {add `set xtrtol=<n>` to this analysis's verbatim lines to choose the value yourself}
set S_DC {a DC sweep does not always reach digital nodes through the bridges the simulator inserts on its own}
set F_DC {write the bridge devices into the netlist yourself, ahead of the digital devices}
set S_ALLI {this circuit has digital nodes, and with `.probe alli` the simulator exits before it simulates anything}
set F_ALLI {remove `.probe alli` from the netlist}

## The debt-M9 chain: adc_bridge -> d_inverter -> dac_bridge. The title line
## carries a MODE the stand-in simulator reads, so one netlist per answer.
proc e_net {mode {extra {}}} {
  return "* EVT:$mode
vin in 0 pulse(0 1 1n 0.1n 0.1n 4n 10n)
aadc \[in\] \[din\] adc1
.model adc1 adc_bridge(in_low=0.4 in_high=0.6)
ainv din dout inv1
.model inv1 d_inverter(rise_delay=1e-10 fall_delay=1e-10)
adac \[dout\] \[aout\] dac1
.model dac1 dac_bridge(out_low=0 out_high=1)
rload aout 0 1k
$extra.end
"
}
proc e_analog {} { return "* EVT:analog\nv1 in 0 1\nr1 in out 1k\nc1 out 0 1n\n.end\n" }

# ============================================================================
# THE FIXTURES -- captured VERBATIM from real runs, 2026-09-15. The fatal and the
# analog-only outputs are byte-identical on both binaries; the other two differ
# only in counts and dates, which no row reads.
# ============================================================================

## After `tran 0.05n 30n` on the M9 chain (apt 45.2).
set FX_AFTER {
Note: No compatibility mode selected!


Circuit: * m1

Reducing trtol to 1 for xspice 'A' devices
Doing analysis at TEMP = 27.000000 and TNOM = 27.000000

Using SPARSE 1.3 as Direct Linear Solver

Initial Transient Solution
--------------------------

Node                                   Voltage
----                                   -------
in                                           0
aout                                         1
vin#branch                                   0
adac#branch_1_0                         -0.001


No. of Data Rows : 656
binary raw file "mx.raw"

List of event nodes in plot tran1
    node name           : type , number of events

    din                 : d    ,     7
    dout                : d    ,     7
Note: Simulation executed from .control section
}

## ⚠ THE PROBE'S OWN SHAPE: no analysis, so it ENDS in an error at rc 1 -- and the
## table is still there. `n:1` is a legal event node, and a name of 20 characters
## or more pushes its `:` against it because `%-20s` does not truncate.
set FX_PRE {Error: incomplete or empty netlist
       or no ".plot", ".print", or ".fourier" lines in batch mode;
no simulations run!

Note: No compatibility mode selected!


Circuit: * fixture names


List of event nodes
    node name           : type , number of events

    n:1                 : d    ,     0
    a_really_long_digital_node_name_x: d    ,     0
}

## An analog-only XSPICE block (`gain`): a MEASURED no.
set FX_NONE {
Note: No compatibility mode selected!


Circuit: * m4 analog-only a card

Reducing trtol to 1 for xspice 'A' devices
Doing analysis at TEMP = 27.000000 and TNOM = 27.000000

No. of Data Rows : 208
No event node available!
binary raw file "m4.raw"
Note: Simulation executed from .control section
}

set FX_FATAL {
Error: Dot command '.probe alli' and digital nodes are not compatible.
    Simulation will fail!


ERROR: fatal error in ngspice, exit(1)

Note: No compatibility mode selected!


Circuit: * m3 probe alli digital

}

## A circuit that did not parse never reaches `.control`, so it says NOTHING
## about event nodes -- which must read as unknown, not as none.
set FX_BROKEN {
Note: No compatibility mode selected!


Circuit: * n1 names

ERROR - Unexpected [ - Arrays of arrays not allowed. Returning . . .Error on line 3 or its substitute:
  aadc [in] [d[0]] adc1
ERROR - Unexpected [ - Arrays of arrays not allowed
    Simulation interrupted due to error!

Error: incomplete or empty netlist
       or no ".plot", ".print", or ".fourier" lines in batch mode;
no simulations run!
}

## The M9 VCD, apt 45.2, verbatim: last timestamp #26275000 at 1 fs.
set FX_VCD {$date September 15, 2026 08:27:55 $end
$version ngspice 45.2 $end
$timescale 1 fs $end
$var wire 1 ! din $end
$var wire 1 " dout $end
$enddefinitions $end
$dumpvars
0!
1"
$end
#2075000
1!
#2175000
0"
#6174999
0!
#6274999
1"
#12075000
1!
#12175000
0"
#16175000
0!
#16275000
1"
#22075000
1!
#22175000
0"
#26174999
0!
#26275000
1"


}

# ============================================================================
# THE STAND-IN SIMULATOR -- answers the probe by the netlist's MODE, and logs
# every probe it is handed with the directory it was started in.
# ============================================================================
set EBIN [file join $scratch bin]
set ECALLS [file join $scratch calls.txt]
set ESTUB {#!/bin/sh
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
echo "$(pwd)|$deck" >> @CALLS@
mode=
if [ -n "$deck" ]; then
  mode=$(sed -n 's/^\* EVT:\([a-z0-9]*\).*/\1/p' "$deck" | head -n 1)
fi
case "$mode" in
  nodes2)
    printf '\nList of event nodes\n    node name           : type , number of events\n\n    din                 : d    ,     0\n    dout                : d    ,     0\n' ;;
  bad)
    printf '\nList of event nodes\n    node name           : type , number of events\n\n    din                 : d    ,     0\n    n$1                 : d    ,     0\n' ;;
  none)
    printf 'No event node available!\n' ;;
  fatal)
    printf "\nError: Dot command '.probe alli' and digital nodes are not compatible.\n    Simulation will fail!\n\nERROR: fatal error in ngspice, exit(1)\n" ;;
  many)
    printf '\nList of event nodes\n    node name           : type , number of events\n\n'
    i=1
    while [ $i -le 94 ]; do printf '    q%d                  : d    ,     0\n' $i; i=$((i+1)); done ;;
  *)
    printf 'Error: no circuit loaded.\n' ;;
esac
exit 1
}
e_wr [file join $EBIN evsim] [string map [list @CALLS@ $ECALLS] $ESTUB] 0755
catch {ase::sim_register evstub [file join $EBIN evsim]}
catch {ase::sim_select evstub}

proc e_state {cell args} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell $cell lib $scratch]
  dict set st rundir [file join $scratch run_$cell]
  dict set st simulator ngspice
  dict set st sim_entry {name evstub}
  dict set st save_all_v 1
  dict set st analyses {{type tran enabled 1 step 0.05n stop 30n}}
  foreach {k v} $args { dict set st $k $v }
  return $st
}
catch {ase::sim_apply_choice [e_state applycell]}

## Probes the stand-in was handed (a registration probe carries no event deck).
proc e_calls {} {
  global ECALLS
  if {![file isfile $ECALLS]} { return 0 }
  return [llength [e_lines [e_slurp $ECALLS] {_ase_evtprobe\.spice$}]]
}

## A backend with the five required hooks and NOTHING else -- the no-fallback row.
foreach p {rd rc lf rp rf} { proc ::evbare_$p {args} { return {} } }
catch {ase::register_backend evbare [dict create render_deck ::evbare_rd \
  run_cmd ::evbare_rc log_file ::evbare_lf result_probe ::evbare_rp raw_file ::evbare_rf]}

# ============================================================================
# SECTION PR -- the seams exist (a missing proc is a NAMED red, not a raise)
# ============================================================================
check {PR1 the schema procs and the adapter's hooks exist} \
  [list [llength [info commands ::ase::event_nodes]] \
        [llength [info commands ::ase::event_nodes_peek]] \
        [llength [info commands ::ase::event_refusals]] \
        [llength [info commands ::ase::event_vcd_path]] \
        [e_ans ase::backend_hook ngspice event_probe] \
        [e_ans ase::backend_hook ngspice event_inventory] \
        [e_ans ase::backend_hook ngspice xspice_caveat]] \
  {1 1 1 1 ::ase::backend::ngspice::event_probe ::ase::backend::ngspice::event_inventory ::ase::backend::ngspice::xspice_caveat}

# ============================================================================
# SECTION IP -- reading the simulator's answer
# ============================================================================
if {[catch {
set EP ::ase::backend::ngspice::event_parse

check {IP1 after a run: the two nodes, by the simulator's names} \
  [e_ans $EP $FX_AFTER] {known 1 nodes {din d dout d} fatal {} unexportable {}}

check {IP2 before a run, from the probe's own rc-1 output: `n:1` and a 33-character name read WHOLE} \
  [e_ans $EP $FX_PRE] \
  {known 1 nodes {n:1 d a_really_long_digital_node_name_x d} fatal {} unexportable {}}

check {IP3 an analog-only XSPICE block is a MEASURED no, not an unknown} \
  [e_ans $EP $FX_NONE] {known 1 nodes {} fatal {} unexportable {}}

set IP4 [e_ans $EP $FX_FATAL]
check {IP4 `.probe alli` beside a digital node is the simulator's refusal, and no node list} \
  [list [e_dg $IP4 known] [e_dg $IP4 nodes] [lindex [lindex [e_dg $IP4 fatal] 0] 0]] \
  {1 {} probe_alli}
check {IP4b the refusal carries the adapter's sentence and its fix} \
  [lrange [lindex [e_dg $IP4 fatal] 0] 1 2] [list $S_ALLI $F_ALLI]

check {IP5 a circuit that did not parse says nothing, which is UNKNOWN} \
  [e_ans $EP $FX_BROKEN] {known 0 why unparsed}

## ⚠ THE GUARD AGAINST ABSENCE, FED ABSENCE.
check {IP6 an empty answer is unknown, never "no event nodes"} \
  [e_ans $EP {}] {known 0 why unparsed}

check {IP7 a node whose name `eprvcd` cannot take is still a node, and is listed as unexportable} \
  [e_ans $EP "\nList of event nodes\n    node name           : type , number of events\n\n    din                 : d    ,     0\n    n\$1                 : d    ,     0\n"] \
  [list known 1 nodes [list din d {n$1} d] fatal {} unexportable [list {n$1}]]

check {IP8 the exportable set is the measured one: `_ - + : # @ / .` survive, `$` and the splitting characters do not} \
  [apply {{} {
    set o {}
    foreach n {din x1.dint n:1 n-1 n+1 n#1 n@1 n/1 mixed_case 9n} {
      lappend o [e_ans ::ase::backend::ngspice::event_exportable $n]
    }
    foreach n {n$1 {a b} n<1> n;1 n'1 n(1) {} #lead n\"1} {
      lappend o [e_ans ::ase::backend::ngspice::event_exportable $n]
    }
    return $o
  }}] {1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0}
} err]} { check {IP0 section IP ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION PD -- the question the adapter asks
# ============================================================================
if {[catch {
set SPD [e_state pdcell \
  includes {{file /tmp/evt1465/inc.spice}} \
  models {{file /tmp/evt1465/lib.spice section tt}} \
  variables {{name vcc value 1.8}} \
  pre_commands {{cmd {pre_codemodel /tmp/evt1465/my.cm}}}]

check {PD1 a circuit with no `a` card is not asked at all} \
  [e_ans ase::event_probe ngspice $SPD [e_analog]] {}

set PD2 [e_ans ase::event_probe ngspice $SPD [e_net nodes2]]
check {PD2 the probe deck reads the circuit the run reads -- netlist, includes, libraries, parameters, pre_ commands -- and WRITES NOTHING} \
  [e_dg $PD2 deck] \
  "[string range [e_net nodes2] 0 end-5].include /tmp/evt1465/inc.spice
.lib /tmp/evt1465/lib.spice tt
.param vcc=1.8
.control
pre_codemodel /tmp/evt1465/my.cm
edisplay
.endc
.end
"

check {PD3 the probe starts the RUN's program with the RUN's words -- exactly run_cmd's, minus the deck} \
  [expr {[concat [e_dg $PD2 argv] [list DECK 2>@1]] eq \
         [e_ans ::ase::backend::ngspice::run_cmd $SPD DECK]}] 1

check {PD4 a backend with no event hooks gets no question, no inventory and no fallback} \
  [list [e_ans ase::event_probe evbare $SPD [e_net nodes2]] \
        [e_ans ase::event_nodes evbare $SPD [e_net nodes2]] \
        [e_ans ase::event_nodes_peek evbare $SPD [e_net nodes2]]] \
  {{} {known 0 why noprobe} {}}
## ⚠ THE PROBE SAYS NOTHING. run_cmd's stale-entry sentence belongs to the RUN,
## once; a probe asking run_cmd for its words must not say it a second time. The
## last column is the control: the same stand-in makes run_cmd itself say it.
set PD5 NORAN
if {[catch {
  ## ⚠ RENAMED WITHIN `ase::`, NOT OUT OF IT: a proc moved to the global namespace
  ## loses its `variable` bindings, and this row's first cut answered {0 0 0} --
  ## the real resolver raising inside the stand-in -- for exactly that reason.
  rename ::ase::sim_status ::ase::e_real_sim_status
  proc ::ase::sim_status {args} {
    set s [::ase::e_real_sim_status {*}$args]
    dict set s why {the entry you chose is stale}
    return $s
  }
  set pd5p [llength [e_echoed [list ase::event_probe ngspice $SPD [e_net nodes2]]]]
  set pd5a [expr {$::e_echo_res ne {}}]
  set pd5r [llength [e_echoed [list ::ase::backend::ngspice::run_cmd $SPD DECK]]]
  set PD5 [list $pd5p $pd5a $pd5r]
} pd5err]} { set PD5 "RAISED:$pd5err" }
catch {rename ::ase::sim_status {}}
catch {rename ::ase::e_real_sim_status ::ase::sim_status}
check {PD5 the probe borrows the run's words without saying the run's sentence} $PD5 {0 1 1}
} err]} { check {PD0 section PD ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION CI -- the cold door, the peek and the cache
# ============================================================================
if {[catch {
ase::event_inv_clear
set SCI [e_state cicell]
set NCI [e_net nodes2]
set c0 [e_calls]
check {CI1 the peek never starts a program, and cold it knows nothing} \
  [list [e_ans ase::event_nodes_peek ngspice $SCI $NCI] [expr {[e_calls] - $c0}]] {{} 0}

set CI2 [e_ans ase::event_nodes ngspice $SCI $NCI]
check {CI2 the cold door asks once and reads the answer} \
  [list [e_dg $CI2 known] [e_dg $CI2 nodes] [expr {[e_calls] - $c0}]] {1 {din d dout d} 1}

e_ans ase::event_nodes ngspice $SCI $NCI
check {CI3 the same circuit is not asked twice} [expr {[e_calls] - $c0}] 1

check {CI4 and the peek now answers what was measured} \
  [e_dg [e_ans ase::event_nodes_peek ngspice $SCI $NCI] nodes] {din d dout d}

check {CI5 a changed netlist is a different question} \
  [e_ans ase::event_nodes_peek ngspice $SCI [e_net nodes2 "rx aout 0 2k\n"]] {}

set c1 [e_calls]
set CI6 [e_ans ase::event_nodes ngspice $SCI [e_net garbage]]
e_ans ase::event_nodes ngspice $SCI [e_net garbage]
check {CI6 an answer nobody could read is NOT remembered -- it is asked again} \
  [list [e_dg $CI6 known] [expr {[e_calls] - $c1}] \
        [e_ans ase::event_nodes_peek ngspice $SCI [e_net garbage]]] {0 2 {}}

check {CI7 the probe deck is gone the moment the answer is in} \
  [file exists [e_ans ase::event_probe_path $SCI]] 0

check {CI8 the simulator was started in the run directory, where the run itself is started} \
  [lindex [split [lindex [e_lines [e_slurp $ECALLS] {_ase_evtprobe\.spice$}] end] |] 0] \
  [file normalize [e_ans ase::rundir $SCI]]
e_ans ase::event_nodes ngspice $SCI $NCI
set ci9a [e_ans ase::event_nodes_peek ngspice $SCI $NCI]
catch {ase::register_backend ngspice [dict get $::ase::backends ngspice]}
check {CI9 re-registering a simulator drops what its old hooks measured} \
  [list [expr {$ci9a ne {}}] [e_ans ase::event_nodes_peek ngspice $SCI $NCI]] {1 {}}
} err]} { check {CI0 section CI ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION EM -- the export line
# ============================================================================
if {[catch {
proc e_deck {st nl} { return [e_ans ::ase::backend::ngspice::render_deck $st $nl] }
## A TRANSFER FUNCTION AFTER THE TRANSIENT: `tf` sorts at 50 and `tran` at 30,
## so it is the analysis the export line must come before. (`op` sorts FIRST --
## this row's first cut assumed otherwise and its own sabotage-free run said so.)
set SEM [e_state emcell analyses {{type tran enabled 1 step 0.05n stop 30n}
  {type tf enabled 1 out v(aout) insrc vin}}]
set NEM [e_net nodes2]
ase::event_inv_clear
set DCOLD [e_deck $SEM $NEM]
e_ans ase::event_nodes ngspice $SEM $NEM
set DWARM [e_deck $SEM $NEM]
set EMVCD [file join [e_ans ase::rundir $SEM] emcell_ase_evt.vcd]

check {EM1 an unmeasured circuit exports nothing} [e_lines $DCOLD {^eprvcd}] {}

check {EM1b the measured deck is the unmeasured deck plus the export line and NOTHING else} \
  [expr {[join [e_lines $DWARM {^(?!eprvcd)}] "\n"] eq [join [e_lines $DCOLD {^(?!eprvcd)}] "\n"]}] 1

check {EM2 exactly one line, the inventory's names, to the run's own VCD} \
  [e_lines $DWARM {^eprvcd}] [list "eprvcd din dout > $EMVCD"]

set it [e_idx $DWARM {^tran }]
set ig [e_idx $DWARM {quit 1} $it]
set iw [e_idx $DWARM {^write } $it]
set ie [e_idx $DWARM {^eprvcd }]
set io [e_idx $DWARM {^tf }]
check {EM3 below the transient's guard and its write, above the next analysis} \
  [list [expr {$it >= 0 && $ig > $it}] [expr {$ig >= 0 && $ie > $ig}] \
        [expr {$iw >= 0 && $ie > $iw}] [expr {$ie >= 0 && $io > $ie}]] {1 1 1 1}

check {EM4 only a transient carries it: an op-only and a dc-only bench export nothing, all four export once, after tran} \
  [apply {{nl} {
    set o {}
    foreach an {{{type op enabled 1}}
                {{type dc enabled 1 source vin start 0 stop 1 step 0.1}}} {
      set st [e_state emcell analyses $an]
      e_ans ase::event_nodes ngspice $st $nl
      lappend o [llength [e_lines [e_deck $st $nl] {^eprvcd}]]
    }
    set st [e_state emcell analyses {{type op enabled 1}
      {type dc enabled 1 source vin start 0 stop 1 step 0.1}
      {type ac enabled 1 points 10 start 1 stop 1k}
      {type tran enabled 1 step 0.05n stop 30n}}]
    e_ans ase::event_nodes ngspice $st $nl
    set d [e_deck $st $nl]
    lappend o [llength [e_lines $d {^eprvcd}]]
    set ie [e_idx $d {^eprvcd}]
    lappend o [expr {$ie > [e_idx $d {^tran }] && [e_idx $d {^tran }] >= 0}]
    return $o
  }} $NEM] {0 0 1 1}

set NMANY [e_net many]
e_ans ase::event_nodes ngspice $SEM $NMANY
set EM5 [e_lines [e_deck $SEM $NMANY] {^eprvcd}]
check {EM5 94 nodes are two exports -- 93 names, then 1 -- to two files, because 94 empties the file on both binaries} \
  [list [llength $EM5] \
        [expr {[llength [lindex $EM5 0]] - 3}] [expr {[llength [lindex $EM5 1]] - 3}] \
        [file tail [lindex [lindex $EM5 0] end]] [file tail [lindex [lindex $EM5 1] end]] \
        [lindex [lindex $EM5 1] 1]] \
  {2 93 1 emcell_ase_evt.vcd emcell_ase_evt_2.vcd q94}

set NBAD [e_net bad]
e_ans ase::event_nodes ngspice $SEM $NBAD
check {EM6 a name the export command cannot take is kept OFF the line -- on 45.2 it would abort the run} \
  [e_lines [e_deck $SEM $NBAD] {^eprvcd}] [list "eprvcd din > $EMVCD"]

set NNONE [e_net none]
e_ans ase::event_nodes ngspice $SEM $NNONE
check {EM7 a measured "no event nodes" exports nothing} \
  [e_lines [e_deck $SEM $NNONE] {^eprvcd}] {}

set NFAT [e_net fatal]
e_ans ase::event_nodes ngspice $SEM $NFAT
check {EM8 a circuit the simulator refuses outright renders no deck at all} \
  [e_deck $SEM $NFAT] "RAISED:ase: $S_ALLI; nothing was rendered"
## THE OTHER RENDER THAT RUNS: a campaign's nominal deck. Without the inventory
## step there, `diff campaign/deck.spice shard-N/deck.spice` would show the export
## line as a difference no point of the campaign made.
ase::event_inv_clear
set SCP [e_state cpcell]
e_ans ase::campaign_prepare ngspice $SCP [e_net nodes2]
check {EM9 a campaign's nominal deck exports what its shards export -- campaign_prepare asks before it renders} \
  [e_lines [e_slurp [e_ans ase::campaign_deck_path $SCP]] {^eprvcd}] \
  [list "eprvcd din dout > [file join [e_ans ase::rundir $SCP] cpcell_ase_evt.vcd]"]
} err]} { check {EM0 section EM ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION CA -- the two cautions
# ============================================================================
if {[catch {
check {CA1 the registry asks the question of dc and tran, and of nothing else} \
  [apply {{} {
    set o {}
    foreach t {op dc ac tran} {
      set n [e_dg [e_ans ase::analysis_entry ngspice $t] needs]
      lappend o [expr {[lsearch -exact $n xspice] >= 0}]
    }
    return $o
  }}] {0 1 0 1}

proc e_xs {type facts} {
  set row [list type $type enabled 1]
  set out {}
  foreach r [e_ans ase::analysis_needs ngspice $row $facts {} {}] {
    if {[lindex $r 0] eq {xspice}} { lappend out $r }
  }
  return $out
}
set FA [ase::netlist_facts [e_net nodes2]]
set FN [ase::netlist_facts [e_analog]]
set MEAS_NONE  {known 1 nodes {} fatal {} unexportable {}}
set MEAS_NODES {known 1 nodes {din d} fatal {} unexportable {}}

check {CA2 a transient over an XSPICE device is told trtol is lowered, and how to choose it} \
  [e_xs tran $FA] [list [list xspice caution $S_TRTOL $F_TRTOL]]
check {CA3 a transient over a purely analog circuit is told nothing} [e_xs tran $FN] {}
check {CA4 a DC sweep over an `a` card nobody has measured is cautioned} \
  [e_xs dc $FA] [list [list xspice caution $S_DC $F_DC]]
check {CA5 a DC sweep MEASURED to have no event node is not} \
  [e_xs dc [dict replace $FA evtinv $MEAS_NONE]] {}
check {CA6 measured event nodes caution a DC sweep even when the netlist text shows no `a` card (it lives in an include)} \
  [e_xs dc [dict replace $FN evtinv $MEAS_NODES]] [list [list xspice caution $S_DC $F_DC]]
check {CA7 and they caution a transient the same way: an event node is an XSPICE device} \
  [e_xs tran [dict replace $FN evtinv $MEAS_NODES]] [list [list xspice caution $S_TRTOL $F_TRTOL]]
check {CA8 an operating point is cautioned about neither} [e_xs op $FA] {}
check {CA9 a backend with no `xspice_caveat` hook is cautioned about nothing -- no fallback} \
  [e_ans ase::needs_eval evbare tran xspice {type tran enabled 1} $FA {} {}] {}

set SCA [e_state cacell analyses {{type tran enabled 1 step 0.05n stop 30n}}]
ase::event_inv_clear
set CA10 [e_echoed [list ase::preflight_gate $SCA [e_net nodes2]]]
check {CA10 the gate says the caution before the run, and does not refuse} \
  [list $::e_echo_rc [expr {[lsearch -exact $CA10 "ase: the tran analysis: $S_TRTOL. Fix: $F_TRTOL"] >= 0}]] \
  {0 1}
## ⚠ AND THE GATE READS THE MEASUREMENT, NOT ONLY THE TEXT. The same DC bench is
## cautioned while unmeasured, and is not once it is MEASURED to have no event node.
set SCB [e_state cbcell analyses {{type dc enabled 1 source vin start 0 stop 1 step 0.1}}]
set NCB [e_net none]
ase::event_inv_clear
set cb1 [e_echoed [list ase::preflight_gate $SCB $NCB]]
e_ans ase::event_nodes ngspice $SCB $NCB
set cb2 [e_echoed [list ase::preflight_gate $SCB $NCB]]
check {CA11 the gate's DC caution follows the measurement: said while unmeasured, silent once measured to have none} \
  [list [expr {[lsearch -exact $cb1 "ase: the dc analysis: $S_DC. Fix: $F_DC"] >= 0}] \
        [expr {[lsearch -exact $cb2 "ase: the dc analysis: $S_DC. Fix: $F_DC"] >= 0}]] {1 0}
} err]} { check {CA0 section CA ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION RF -- the one refusal
# ============================================================================
if {[catch {
set SRF [e_state rfcell]
set NRF [e_net fatal]
ase::event_inv_clear

check {RF1 unmeasured, nothing is refused -- a refusal is never a guess} \
  [list [e_ans ase::event_refusals ngspice $SRF $NRF] [catch {ase::preflight_gate $SRF $NRF}]] {{} 0}

e_ans ase::event_nodes ngspice $SRF $NRF
check {RF2 measured, the circuit carries the simulator's refusal in the precheck's own row shape} \
  [e_ans ase::event_refusals ngspice $SRF $NRF] [list [list probe_alli fatal $S_ALLI $F_ALLI]]

set RF3 [e_echoed [list ase::preflight_gate $SRF $NRF]]
check {RF3 the gate refuses it, in ASE-L's frame, with the fix, and says nothing was generated} \
  [list $::e_echo_rc \
        [lindex [split $::e_echo_res "\n"] 0] \
        [lindex [split $::e_echo_res "\n"] 1] \
        [string match {ase: Nothing was generated*} [lindex [split $::e_echo_res "\n"] 2]]] \
  [list 1 "ase: this circuit cannot run: $S_ALLI" "ase:   fix: $F_ALLI" 1]

e_ans ase::event_nodes ngspice $SRF [e_net nodes2]
check {RF4 the same bench with digital nodes and no `.probe alli` is refused by nothing} \
  [list [e_ans ase::event_refusals ngspice $SRF [e_net nodes2]] \
        [catch {ase::preflight_gate $SRF [e_net nodes2]}]] {{} 0}

## THROUGH THE RUN DOOR. A refused run deletes nothing when the refusal was
## already known, and writes no deck when it is measured for the first time.
set RFNL [e_wr [file join $scratch rfcell.spice] $NRF]
set RFRAW [e_ans ::ase::backend::ngspice::raw_file $SRF]
e_wr $RFRAW "previous run's results\n"
set rf5 [catch {ase::run_deck $SRF $RFNL} rf5m]
check {RF5 a circuit already measured is refused at the gate, and the previous run's results survive} \
  [list $rf5 [string first $S_ALLI $rf5m] [file exists $RFRAW]] [list 1 [string first $S_ALLI $rf5m] 1]
check {RF5b ... and the refusal really is the simulator's sentence} [expr {[string first $S_ALLI $rf5m] >= 0}] 1

ase::event_inv_clear
catch {file delete -- [ase::deck_file $SRF]}
set rf6 [catch {ase::run_deck $SRF $RFNL} rf6m]
check {RF6 measured for the first time by the run itself, it is refused before a deck is written} \
  [list $rf6 [expr {[string first "$S_ALLI; nothing was rendered" $rf6m] >= 0}] \
        [file exists [ase::deck_file $SRF]]] {1 1 0}
} err]} { check {RF0 section RF ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION LV -- the files a run promises, and the ones the viewer is handed
# ============================================================================
if {[catch {
set SLV [e_state lvcell]
set LVKEY [ase::session_key $scratch lvcell ngspice_state1]
ase::session_open $LVKEY [ase::state_save [file join $scratch lv.state] $SLV]
set p1 [e_ans ase::event_vcd_path $SLV 1]
set p2 [e_ans ase::event_vcd_path $SLV 2]
set p3 [e_ans ase::event_vcd_path $SLV 3]
foreach p [list $p1 $p2 $p3] { catch {file delete -- $p} }

check {LV1 the paths are <rundir>/<cell>_ase_evt.vcd, then _2, _3} \
  [list [file tail $p1] [file tail $p2] [file tail $p3] \
        [expr {[file dirname $p1] eq [file normalize [e_ans ase::rundir $SLV]]}]] \
  {lvcell_ase_evt.vcd lvcell_ase_evt_2.vcd lvcell_ase_evt_3.vcd 1}
check {LV2 no VCD on disk, none served} [e_ans ase::last_vcdfiles $LVKEY] {}
e_wr $p1 "x\n"
check {LV3 the run's VCD is served beside the raw} [e_ans ase::last_vcdfiles $LVKEY] [list $p1]
e_wr $p3 "x\n"
check {LV4 a gap ends the set -- a file after it belongs to some other run} \
  [e_ans ase::last_vcdfiles $LVKEY] [list $p1]
e_wr $p2 "x\n"
check {LV5 contiguous files are all served, in order} \
  [e_ans ase::last_vcdfiles $LVKEY] [list $p1 $p2 $p3]
check {LV6 a run clears exactly those before it starts} \
  [list [e_ans ase::event_vcd_clear $SLV] [file exists $p1] [file exists $p2] [file exists $p3]] \
  [list [list $p1 $p2 $p3] 0 0 0]
## THROUGH THE RUN DOOR: the deletion is ase::run_deck's, and a row that only
## calls ase::event_vcd_clear cannot see it go missing from there.
set SLC [e_state lccell]
set LCNL [e_wr [file join $scratch lccell.spice] [e_analog]]
set lc1 [e_wr [e_ans ase::event_vcd_path $SLC 1] "stale\n"]
set lc2 [e_wr [e_ans ase::event_vcd_path $SLC 2] "stale\n"]
set lcrc [catch {ase::run_deck $SLC $LCNL} lcid]
if {!$lcrc} { ase::wait $lcid }
check {LV7 a run deletes the previous run's event VCDs before it starts, so none is served beside this run's raw} \
  [list $lcrc [file exists $lc1] [file exists $lc2]] {0 0 0}

set SUN [e_state uncell]
set UNNL [e_wr [file join $scratch uncell.spice] [e_net bad]]
ase::event_inv_clear
set UN [e_echoed [list apply {{st nl} { set id [ase::run_deck $st $nl]; ase::wait $id }} $SUN $UNNL]]
check {UN1 a node left off the export line is NAMED to the user, never dropped in silence} \
  [expr {[lsearch -exact $UN {ase: left out of the VCD, because the export command cannot take these digital node names: n$1}] >= 0}] 1
} err]} { check {LV0 section LV ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION AT -- the reader's run end (C: `xschem raw read <f> vcd -end <s>`)
# ============================================================================
if {[catch {
set ATV [e_wr [file join $scratch at m9.vcd] $FX_VCD]
proc e_vread {args} {
  catch {xschem raw clear}
  if {[catch {xschem raw read {*}$args} r]} { return "RAISED:$r" }
  set np [xschem raw points]
  set t [xschem raw value time [expr {$np - 1}]]
  catch {xschem raw clear}
  return [list $r $np $t]
}
check {AT1 without a run end the traces stop at the last value change} \
  [e_vread $ATV vcd] {1 25 2.6275e-08}
check {AT2 with the run's end they reach it, one column later} \
  [e_vread $ATV vcd -end 3e-08] {1 26 3e-08}
check {AT3 an end before the last change changes nothing -- it only ever extends} \
  [e_vread $ATV vcd -end 1e-08] {1 25 2.6275e-08}
check {AT4 an unreadable end changes nothing} \
  [e_vread $ATV vcd -end junk] {1 25 2.6275e-08}
check {AT5 an end with no value is refused by name} \
  [e_vread $ATV vcd -end] {RAISED:xschem raw read: -end needs a time in seconds}
## ⚠ BY THE OTHER VERB. Every `raw read` sets its own end before it reads, so a
## plain `raw read` after an `-end` read cannot see a missing reset; `raw vcd_read`
## sets none, which is the case the reset exists for.
proc e_vread_other {f} {
  catch {xschem raw clear}
  if {[catch {xschem raw vcd_read $f} r]} { return "RAISED:$r" }
  set np [xschem raw points]
  set t [xschem raw value time [expr {$np - 1}]]
  catch {xschem raw clear}
  return [list $r $np $t]
}
e_vread $ATV vcd -end 3e-08
check {AT6 the end is spent by the read that asked for it: a later read that names no end is plain} \
  [e_vread_other $ATV] {1 25 2.6275e-08}
## ⚠ 0.4 fs PAST THE LAST TICK, NOT ON IT. An end written as exactly the last
## timestamp divides by the timescale to a float a ulp either side of the tick,
## so it cannot tell a half-tick slack from none -- this row's first cut did not,
## and the sabotage that removed the slack walked straight past it.
check {AT7 an end within half a tick of the file's own last timestamp adds no second column there} \
  [e_vread $ATV vcd -end 2.62750004e-08] {1 25 2.6275e-08}
} err]} { check {AT0 section AT ran to the end} "RAISED:$err" {} }

# ============================================================================
# SECTION EE -- THE REAL SIMULATORS, BOTH OF THEM
# ============================================================================
# ⚠ 45.2 IS THE POINT. The export line is safe on the fork whatever it names;
# on 45.2 a single analog word on it aborts the run. The chain has analog nodes
# (`in`, `aout`) right beside the digital ones, and a transfer function AFTER the
# transient, so a run that died on the export line cannot hide: its tf plot is
# missing.
proc e_vcd_end {path} {
  set t [e_slurp $path]
  if {![regexp {\$timescale\s+(\d+)\s*(s|ms|us|ns|ps|fs)\s+\$end} $t -> n u]} { return NOTS }
  set mult [dict get {s 1 ms 1e-3 us 1e-6 ns 1e-9 ps 1e-12 fs 1e-15} $u]
  set last {}
  foreach {- tk} [regexp -all -inline -line {^#(\d+)$} $t] { set last $tk }
  if {$last eq {}} { return NOTICK }
  return [expr {$last * $n * $mult}]
}
if {[catch {
set EEBINS [list apt /usr/bin/ngspice \
                 fork /home/analog/dev/ngspice/build-ver_50/src/ngspice]
foreach {tag bin} $EEBINS {
  if {![file executable $bin]} {
    puts "ok:   EE0/$tag SKIPPED -- no binary at $bin"
    incr npass
    continue
  }
  catch {ase::sim_register ee$tag $bin}
  set eed [file join $scratch ee$tag]
  file delete -force $eed
  file mkdir $eed
  set est [ase::state_default]
  dict set est design [dict create cell MixEvt lib $eed]
  dict set est rundir $eed
  dict set est simulator ngspice
  dict set est sim_entry [list name ee$tag]
  dict set est save_all_v 1
  dict set est analyses {{type dc enabled 1 source vin start 0 stop 1 step 0.5}
    {type tran enabled 1 step 0.05n stop 30n}
    {type tf enabled 1 out v(aout) insrc vin}}
  set enl [e_wr [file join $eed MixEvt.spice] [e_net real]]
  ase::event_inv_clear
  set erc [catch {ase::run_deck $est $enl} eid]
  set ecode [expr {$erc ? "RAISED:$eid" : [ase::wait $eid]}]
  check "EE1/$tag the mixed-signal run completes" $ecode 0

  set edeck [e_slurp [ase::deck_file $est]]
  set evcd [ase::event_vcd_path $est]
  set eit [e_idx $edeck {^tran }]
  set eiw [e_idx $edeck {^write } $eit]
  set eie [e_idx $edeck {^eprvcd }]
  check "EE2/$tag the deck it ran exports the two digital nodes, after the transient's write" \
    [list [e_lines $edeck {^eprvcd}] [expr {$eiw >= 0 && $eie > $eiw}]] \
    [list [list "eprvcd din dout > $evcd"] 1]

  check "EE3/$tag the VCD on disk declares both nodes under their ngspice names" \
    [apply {{p} {
      set o {}
      foreach {- nm} [regexp -all -inline -line {^\$var wire 1 \S+ (\S+) \$end$} [e_slurp $p]] {
        lappend o $nm
      }
      return $o
    }} $evcd] {din dout}

  check "EE4/$tag the run went on past the export: the transfer function AFTER it is in the results" \
    [apply {{p} {
      set o {}
      foreach {- ty} [regexp -all -inline -line {^PLOT (\S+) } [e_slurp $p]] { lappend o $ty }
      return $o
    }} [ase::plotmap_path $est]] {dc tran tf}

  set ekey [ase::session_key $eed MixEvt ngspice_state1]
  ase::session_open $ekey [ase::state_save [file join $eed MixEvt.state] $est]
  check "EE5/$tag the viewer is handed the VCD beside the raw" \
    [e_ans ase::last_vcdfiles $ekey] [list $evcd]

  set eraw [::ase::backend::ngspice::raw_file $est]
  set eatt [e_ans ase::attach_dbs $eraw tran [list $evcd]]
  set rend NORAW ; set vend NOVCD ; set vty {}
  catch {
    xschem raw switch 0
    set rend [xschem raw value time [expr {[xschem raw points] - 1}]]
    xschem raw switch 1
    set vty [xschem raw sim_type]
    set vend [xschem raw value time [expr {[xschem raw points] - 1}]]
    xschem raw switch 0
  }
  set fend [e_vcd_end $evcd]
  check "EE6/$tag attached, the digital database reaches the run's end -- and the file alone does not" \
    [list [e_dg $eatt n] $vty \
          [expr {[string is double -strict $vend] && [string is double -strict $rend] &&
                 abs($vend - $rend) <= 1e-15}] \
          [expr {[string is double -strict $fend] && [string is double -strict $rend] &&
                 $fend < $rend - 1e-12}]] \
    {2 vcd 1 1}
  catch {xschem raw clear}

  ## ⚠ ONLY A TIME AXIS HAS AN END A VCD SHARES. Beside a DC sweep -- whose scale
  ## ENDS AT 1, so an attach that did not ask would stretch the VCD to one second --
  ## the same VCD must keep its own last timestamp.
  set eatt2 [e_ans ase::attach_dbs $eraw dc [list $evcd]]
  set vend2 NOVCD
  catch {
    xschem raw switch 1
    set vend2 [xschem raw value time [expr {[xschem raw points] - 1}]]
    xschem raw switch 0
  }
  check "EE10/$tag beside a DC sweep there is no shared time axis, so the VCD keeps its own end" \
    [list [e_dg $eatt2 n] \
          [expr {[string is double -strict $vend2] && [string is double -strict $fend] &&
                 abs($vend2 - $fend) <= 1e-15}]] {2 1}
  catch {xschem raw clear}

  check "EE7/$tag the probe left nothing in the run directory" \
    [file exists [ase::event_probe_path $est]] 0

  ## `.probe alli` on the same chain: refused, by the real simulator's own answer.
  set ped [file join $scratch ee${tag}p]
  file delete -force $ped
  file mkdir $ped
  set pst $est
  dict set pst design [dict create cell MixAlli lib $ped]
  dict set pst rundir $ped
  set pnl [e_wr [file join $ped MixAlli.spice] [e_net real ".probe alli\n"]]
  set prc [catch {ase::run_deck $pst $pnl} pmsg]
  check "EE8/$tag with `.probe alli` the run is refused with the simulator's reason, and no deck is written" \
    [list $prc [expr {[string first $S_ALLI $pmsg] >= 0}] [file exists [ase::deck_file $pst]]] {1 1 0}

  set praw [::ase::backend::ngspice::raw_file $pst]
  e_wr $praw "previous run's results\n"
  set prc2 [catch {ase::run_deck $pst $pnl} pmsg2]
  check "EE9/$tag asked again, it is refused at the gate, before a single file is deleted" \
    [list $prc2 [string match "*ase: this circuit cannot run: $S_ALLI*" $pmsg2] [file exists $praw]] \
    {1 1 1}
}
} err]} { check {EE0 section EE ran to the end} "RAISED:$err" {} }

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456) and an EXPLICIT exit (receipt 39, C13): T1
# counts a non-zero child exit as a failure however green the checks.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
exit [expr {$fail ? 1 : 0}]
