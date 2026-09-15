# tests/headless/test_ase_trnoise_gui_1467.tcl -- ISSUE 1467: THE TRANSIENT
# NOISE TABLE HAD A DECK AND NO FORM. doc/claude/ase_analyses_batch/PLAN.md
# Stage 13, the GUI half (task 2 of 2; the deck half is issue 1466).
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# Issue 1466 made a transient able to carry noise with no schematic edit -- a
# `noise` table on the `tran` row, emitted padded and put back after its own
# transient -- and drew nothing. The only way to put a table on a bench was to
# hand-edit the `.state` file; the density, the point estimate, the seed
# sentence and every refusal existed as data and reached no screen.
#
# ============================================================================
# ⚠ THE MEASUREMENTS THAT DECIDE THE SHAPE (2026-09-15)
# ============================================================================
#  1. ⚠ `facts nodes` IS NOT A NET LIST. `ase::netlist_map` files every token
#     after a device's name, so on `vdd vdd 0 dc 1.8 / vsig in 0 dc 0 sin(0 1 1k)
#     / r1 vdd out 1k / m1 out in 0 0 nch W=1u` the top scope held
#     `0 1 1.8 1k 1k) bias dc in nch out rts sin(0 vdd y`, and
#     `ase::facts_net_status` called `dc`, `1k`, `sin(0` and `nch` PRESENT.
#     Issue 1466's receipt told this task to offer nets from that map; it would
#     have offered `dc` as a net. The adapter reads nets from the netlist TEXT
#     by device letter instead (row NQ4 pins both halves).
#  2. The offer and the refusal are ONE body: the adapter's target rules were
#     split out of `noise_entry_check` and both call them (NQ2, NQ3, NR1).
#
# ============================================================================
# ⚠ NO ROW PINS A NUMBER THE SIMULATOR DRAWS OR A POINT COUNT IT PRODUCES
# ============================================================================
# The readouts are checked against the ARITHMETIC (GL1-GL4), and section EE
# checks the estimate against a real run only to within a factor of two: the two
# binaries disagree about a noisy transient's point count (4415 vs 5008).
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#   headless, both arms:
#     NQ  the targets the Add control may offer
#     NK  the kill-switch sentences
#     NN  the last run's vector count (the file-size estimate's input)
#     NO  the `notrnoise` Options-sheet row
#     NS  the schema and a backend with no contract
#     NR  the target/value split keeps the finding order
#     NZ  the window names no simulator word (a lint over ase_window.tcl)
#     NC  the committed .state corpus
#   DISPLAY only, self-skipping:
#     GD  the section: on the Tran form only, folded, destroyed on a type switch
#     GO  opening it starts nothing
#     GB  byte identity: untouched, hand-written, added-then-deleted
#     GA  the Add control offers only legal targets; a cold bench is no dead end
#     GE  the editor: positional fields, units, distribution, Enable, switches
#     GL  the live readouts against the arithmetic
#     GV  per-entry verdicts, and OK refusing a table the run would refuse
#     GS  the seed and kill-switch sentences, verbatim
#     GK  dialog memory: type switch, Cancel, two transient rows
#     EE  values typed into the widgets -> the deck -> a real run, BOTH binaries
#
# THE HISTORY:
#   see the RESULT line of the first commit that carries this file -- issue
#   1467 ships it; raise the number here when rows are added, never lower it.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_trnoise_gui_1467.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_trnoise_gui_1467.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name got} { check $name [expr {$got ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch nzgui1467]
catch {test_sim_registry_isolate}

## A call that never blows the suite up: an absent proc is NOPROC and a raise is
## RAISED:<message>. `--nogui --pipe` exits 0 on an uncaught error, so a raise
## would otherwise end the suite silently at rc 0 with no RESULT line.
proc s_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc s_dget {d k} {
  if {[catch {dict get $d $k} v]} { return MISSING }
  return $v
}
proc s_broken {v} {
  return [expr {[string match {NOPROC*} $v] || [string match {RAISED:*} $v]}]
}

proc q_netlist {} {
  return "* nzbench\nvdd vdd 0 dc 1.8\nvsig in 0 dc 0 sin(0 1 1k)\nvrts rts 0 dc 0\niref 0 bias dc 0\nr1 vdd out 1k\nr2 out 0 1k\nrin in 0 1k\nrrts rts 0 1k\nrb bias 0 1k\nm1 out in 0 0 nch W=1u\nxinv out y inv\n.subckt inv a b\nr9 a b 1k\nv9 a b dc 1\n.ends\n.control\nlet zz = 1\n.endc\n.end\n"
}
## The worst verdict of a one-entry table, or {} -- BROKEN when the reader is.
proc q_worst {entry {facts {}}} {
  set row [dict create type tran enabled 1 step 1u stop 2m noise [list $entry]]
  set v [s_ans ase::stimuli_verdicts ngspice $row $facts {}]
  if {[s_broken $v]} { return BROKEN }
  set w [s_ans ase::stimuli_worst $v]
  return [lindex $w 0]
}

if {[catch {

# ===========================================================================
# NQ -- THE TARGETS THE ADD CONTROL MAY OFFER
# ===========================================================================
set QNL [q_netlist]
set QF [ase::netlist_facts $QNL]
## ⚠ PER FUNCTION: a current source carries noise and not a random value
## (issue 1466's measured freeze), so the offer differs by function.
check {NQ1 the offer is per function -- top-level sources with no waveform, the\
 random value never onto a current source, the nets of top-level cards -- and a\
 cold bench or an unknown function is offered nothing} \
  [list [s_ans ase::stimuli_candidates ngspice tran trnoise $QF $QNL {}] \
        [s_ans ase::stimuli_candidates ngspice tran trrandom $QF $QNL {}] \
        [s_ans ase::stimuli_candidates ngspice tran pinknoise $QF $QNL {}] \
        [s_ans ase::stimuli_candidates ngspice tran trnoise {} {} {}]] \
  [list {src {iref vdd vrts} net {bias in out rts vdd y}} \
        {src {vdd vrts} net {bias in out rts vdd y}} \
        {src {} net {}} {src {} net {}}]

## ⚠ NOTHING OFFERED IS REFUSED, asked through the reader the RUN uses
## (`ase::stimuli_verdicts`) with clean values, so a candidate filter that
## drifted from the check leg reds here by the name it offered wrongly.
set QBAD {} ; set QN 0
foreach qfn {trnoise trrandom} {
  set qc [s_ans ase::stimuli_candidates ngspice tran $qfn $QF $QNL {}]
  if {[s_broken $qc]} { lappend QBAD $qc ; continue }
  foreach qtf {src net} {
    foreach qnm [s_dget $qc $qtf] {
      incr QN
      set qrow [dict create type tran enabled 1 step 1u stop 2m noise \
        [list [dict create $qtf $qnm func $qfn na 1m ts 1u dist 1 td 1n param1 1m]]]
      foreach qf [s_ans ase::stimuli_verdicts ngspice $qrow $QF {}] {
        if {[lindex $qf 1] ne {caution}} { lappend QBAD [list $qfn $qtf $qnm $qf] }
      }
    }
  }
}
check {NQ2 every target offered is accepted by the check the run applies} \
  [list $QBAD [expr {$QN >= 15}]] {{} 1}

check {NQ3 and the names left out that a user could still type are refused by that\
 same check: a source with a waveform, a random value on a current source, ground} \
  [list [q_worst {src vsig func trnoise na 1m ts 1u} $QF] \
        [q_worst {src iref func trrandom dist 1 ts 1u td 1n param1 1m} $QF] \
        [q_worst {net 0 func trnoise na 1m ts 1u} $QF] \
        [q_worst {net vdd func trnoise na 1m ts 1u} $QF]] \
  {fatal fatal fatal {}}

## ⚠ THE MEASURED REASON THE OFFER READS THE TEXT. Both halves: the facts' node map
## calls these tokens present, and the adapter's net reader does not carry them.
set Q4P {}
foreach qt {dc 1k nch sin(0} { lappend Q4P [s_ans ase::facts_net_status $QF $qt] }
check {NQ4 the nets come from the cards' node positions: no value, keyword, model\
 name, subcircuit node or control-block word -- which the facts' own node map\
 does carry, and calls present} \
  [list [s_ans ase::backend::ngspice::noise_net_tokens $QNL] $Q4P] \
  {{vdd 0 in rts bias out y} {present present present present}}

set Q5F [dict replace $QF evtinv {known 1 nodes {out 1}}]
set Q5NL [string map [list ".endc\n.end\n" ".endc\niase_noise_9_9 0 out dc 0\n.end\n"] $QNL]
set Q5R [ase::netlist_facts $Q5NL]
set Q5A [s_ans ase::stimuli_candidates ngspice tran trnoise $Q5F $QNL {}]
check {NQ5 a node a measured event inventory names is not offered, and no net at\
 all is offered into a netlist already using a carrier name} \
  [list [expr {[lsearch -exact [s_dget $Q5A net] out] < 0}] \
        [expr {[lsearch -exact [s_dget $Q5A net] bias] >= 0}] \
        [s_dget [s_ans ase::stimuli_candidates ngspice tran trnoise $Q5R $Q5NL {}] net]] \
  {1 1 {}}

# ===========================================================================
# NS -- THE SCHEMA, AND A BACKEND WITH NO CONTRACT OR NO LEG
# ===========================================================================
proc q_types {mode} {
  set e [dict get [ase::analysis_types ngspice] tran]
  set s [dict get $e stimuli]
  switch -exact -- $mode {
    none {
      dict unset e stimuli
      dict set e needs [lsearch -all -inline -not -exact [dict get $e needs] stimuli_check]
      return [dict create tran $e]
    }
    noleg { dict unset s candidates ; dict unset s kill_sentences }
    badleg {
      dict set s candidates ::no::such::proc
      dict set s kill_sentences ::no::such::too
    }
  }
  dict set e stimuli $s
  return [dict create tran $e]
}
set ::QMODE none
proc q_hook {} { return [q_types $::QMODE] }
proc q_probe {mode script} {
  set save $::ase::backends
  set ::QMODE $mode
  ase::register_backend zzq [dict create render_deck x run_cmd x log_file x \
    result_probe x raw_file x analysis_types q_hook \
    si_suffixes ::ase::backend::ngspice::si_suffixes]
  ase::analysis_cache_clear zzq
  set r [uplevel 1 $script]
  set ::ase::backends $save
  ase::analysis_cache_clear zzq
  return $r
}
check {NS1 the registry is clean, and a contract naming a candidates or\
 kill-sentence leg that is not a command is named by the schema} \
  [list [s_ans ase::analysis_schema_errors ngspice] \
        [q_probe badleg {s_ans ase::analysis_schema_errors zzq}]] \
  {{} {{tran badstimulihook ::no::such::proc} {tran badstimulihook ::no::such::too}}}

set NSROW {type tran enabled 1 step 1u stop 2m noise {{src vdd func trnoise na 1m ts 10u}}}
set NSST [dict create simulator zzq analyses [list $NSROW] options {{name notrnoise}}]
check {NS2 a backend with no contract gets no candidates, no noun and no quantity --\
 and it is really read (its transient line renders)} \
  [q_probe none {list [s_ans ase::analysis_line zzq {type tran enabled 1 step 1u stop 2m}] \
                      [s_ans ase::stimuli_candidates zzq tran trnoise $QF $QNL {}] \
                      [s_ans ase::stimuli_noun zzq tran 2] \
                      [s_ans ase::stimuli_quantity zzq tran {src vdd}]}] \
  {{tran 1u 2m} {} {} {}}
check {NS3 a contract with no candidates or kill-sentence leg offers nothing and says\
 nothing -- no core fallback of either -- while its key and kill switch still read} \
  [q_probe noleg {list [s_ans ase::analysis_setup_key zzq tran] \
                       [s_ans ase::stimuli_candidates zzq tran trnoise $QF $QNL {}] \
                       [s_dget [s_ans ase::stimuli_kill_report zzq $NSST $NSROW] armed] \
                       [s_dget [s_ans ase::stimuli_kill_report zzq $NSST $NSROW] sentences]}] \
  {noise {} 1 {}}

## ⚠ A LITERAL, AND SABOTAGE IS WHY. GD1 and GB3 compose their expected header and
## Arguments text through `ase::stimuli_noun` itself, so a noun that never
## pluralised made both agree with it and SURVIVED (S08). This row knows the word.
check {NS4 the noun is the contract's, singular for one and plural otherwise} \
  [list [s_ans ase::stimuli_noun ngspice tran 1] [s_ans ase::stimuli_noun ngspice tran 2] \
        [s_ans ase::stimuli_noun ngspice tran 0]] \
  {{noise source} {noise sources} {noise sources}}

# ===========================================================================
# NK -- WHAT THE KILL SWITCH DOES, IN WORDS
# ===========================================================================
proc k_state {row opts} {
  set st [ase::state_default]
  dict set st simulator ngspice
  dict set st analyses [list $row]
  dict set st options $opts
  return $st
}
set KROW {type tran enabled 1 step 1u stop 2m noise {{src vdd func trnoise na 1m ts 10u} {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u} {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u ts 10u} {net bias func trrandom dist 2 ts 100u td 1n param1 1m}}}
check {NK1 armed, the kill report carries the adapter's sentences, per entry: what\
 is switched off and what keeps running} \
  [s_dget [s_ans ase::stimuli_kill_report ngspice [k_state $KROW {{name notrnoise}}] $KROW] sentences] \
  [list {With notrnoise set, noise source 1 loses its white noise and noise source 3 loses its RTS noise.} \
        {Noise source 2 keeps its RTS noise and noise source 4 keeps its random value: notrnoise does not switch them off.}]
check {NK2 not armed -- no row, or a row set to 0 -- there are no sentences} \
  [list [s_dget [s_ans ase::stimuli_kill_report ngspice [k_state $KROW {}] $KROW] sentences] \
        [s_dget [s_ans ase::stimuli_kill_report ngspice [k_state $KROW {{name notrnoise value 0}}] $KROW] sentences]] \
  {{} {}}
set K3ROW {type tran enabled 1 step 1u stop 2m noise {{src vdd func trnoise na 1m namp 1m nalpha 1 ts 10u rtsam 1m rtscapt 1u rtsemt 1u} {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}}
check {NK3 one entry losing three kinds is one clause, and a single survivor is "it"} \
  [s_dget [s_ans ase::stimuli_kill_report ngspice [k_state $K3ROW {{name notrnoise}}] $K3ROW] sentences] \
  [list {With notrnoise set, noise source 1 loses its white noise, 1/f noise and RTS noise.} \
        {Noise source 2 keeps its RTS noise: notrnoise does not switch it off.}]

# ===========================================================================
# NN -- THE LAST RUN's VECTOR COUNT, READ FROM A HEADER AND NEVER GUESSED
# ===========================================================================
set NNDIR [file join $scratch nn]
file delete -force $NNDIR
file mkdir $NNDIR
proc nn_state {rows} {
  global NNDIR
  set st [ase::state_default]
  dict set st simulator ngspice
  dict set st design [dict create cell nnbench lib $NNDIR]
  dict set st rundir $NNDIR
  dict set st analyses $rows
  return $st
}
proc nn_plot {name vars} {
  set s "Title: nn\nDate: now\nPlotname: $name\nFlags: real\nNo. Variables: [llength $vars]\nNo. Points: 1\nVariables:\n"
  set i 0
  foreach v $vars { append s "\t$i\t$v\tvoltage\n" ; incr i }
  append s "Values:\n 0"
  foreach v $vars { append s "\t0\n" }
  return $s
}
proc nn_write {path text} { set f [open $path w] ; puts -nonewline $f $text ; close $f }
set NNST [nn_state {{type op enabled 1} {type tran enabled 1 step 1u stop 1m}}]
set NNRAW [ase::backend::ngspice::raw_file $NNST]
set NNMAP [ase::plotmap_path $NNST]
nn_write $NNRAW "[nn_plot {Operating Point} {v(a) v(b)}][nn_plot {Transient Analysis} {time v(a) v(b)}]"
nn_write $NNMAP "PLOT op 0 |Operating Point|\nPLOT tran 1 |Transient Analysis|\n"
check {NN1 each row's count is the variable count of the plot its plotmap record\
 names} \
  [list [s_ans ase::stimuli_nvec ngspice $NNST 1] [s_ans ase::stimuli_nvec ngspice $NNST 0]] \
  {3 2}
check {NN2 a bench changed since the run, a row the run never wrote, an index out of\
 range, or no results file at all answers nothing} \
  [list [s_ans ase::stimuli_nvec ngspice [nn_state {{type op enabled 1} {type dc enabled 1}}] 1] \
        [s_ans ase::stimuli_nvec ngspice [nn_state {{type op enabled 1} {type tran enabled 1} {type tran enabled 1}}] 2] \
        [s_ans ase::stimuli_nvec ngspice $NNST 5] \
        [s_ans ase::stimuli_nvec ngspice [dict replace $NNST design [dict create cell nosuch lib $NNDIR]] 1]] \
  {{} {} {} {}}
set NN3ST [nn_state {{type tran enabled 1 step 1u stop 1m} {type tran enabled 1 step 1u stop 2m}}]
nn_write [ase::backend::ngspice::raw_file $NN3ST] "[nn_plot {Transient Analysis} {time v(a) v(b)}][nn_plot {Transient Analysis} {time v(a) v(b) v(c) v(d)}]"
nn_write [ase::plotmap_path $NN3ST] "PLOT tran 0 |Transient Analysis|\nPLOT tran 1 |Transient Analysis|\n"
set NN3ROW [dict replace [lindex [dict get $NN3ST analyses] 1] noise {{src vdd func trnoise na 1m ts 100n}}]
check {NN3 two plots of one name are told apart by position, and the file-size\
 estimate is points x that count x 8} \
  [list [s_ans ase::stimuli_nvec ngspice $NN3ST 0] [s_ans ase::stimuli_nvec ngspice $NN3ST 1] \
        [s_dget [s_ans ase::stimuli_readout ngspice $NN3ST $NN3ROW 1 \
                   [s_ans ase::stimuli_nvec ngspice $NN3ST 1]] bytes]] \
  [list 3 5 [expr {100000 * 5 * 8}]]

# ===========================================================================
# NO -- THE `notrnoise` OPTIONS-SHEET ROW NAMES THE SPLIT
# ===========================================================================
set NOH [s_ans ase::opt_help ngspice notrnoise]
set NOW [s_ans ase::opt_results_why ngspice notrnoise]
check {NO1 the row's help names what the switch kills and what it spares, its\
 measurement keeps the first run and adds the per-kind one, and search finds it} \
  [list [regexp {white and 1/f noise always} $NOH] \
        [regexp {RTS noise only where its noise timestep is above 0} $NOH] \
        [regexp {random sources keep running} $NOH] \
        [string match {MEASURED 2026-09-13 on both binaries*} $NOW] \
        [regexp {RTS noise only on a source whose noise timestep is above 0} $NOW] \
        [regexp {trrandom source runs on} $NOW] \
        [s_ans ase::opt_match ngspice notrnoise random]] \
  {1 1 1 1 1 1 1}

# ===========================================================================
# NR -- THE TARGET/VALUE SPLIT KEEPS THE ORDER
# ===========================================================================
set RE {src vsig func trnoise na 1m ts -1u}
set RROW [dict create type tran enabled 1 step 1u stop 2m noise [list $RE]]
set RT [s_ans ase::backend::ngspice::noise_target_check $QF {} 1 $RE trnoise]
set RV [s_ans ase::backend::ngspice::noise_value_check $RROW {} 1 $RE 2e-3 trnoise {}]
set RA [s_ans ase::backend::ngspice::noise_entry_check $RROW $QF {} 1 $RE 2e-3]
check {NR1 the entry check is the target half followed by the value half} \
  [list [llength $RT] [llength $RV] [expr {$RA eq [concat $RT $RV]}] \
        [string match {*already carries a sin waveform*} [lindex [lindex $RT 0] 1]] \
        [string match {*negative noise timestep*} [lindex [lindex $RV 0] 1]]] \
  {1 1 1 1 1}

# ===========================================================================
# NZ -- THE WINDOW NAMES NO SIMULATOR WORD (D34-D37)
# ===========================================================================
## ⚠ THE POSITIVE CONTROL IS src/ase.tcl, which must match, so a lint whose
## pattern matched nothing could not pass.
proc nz_lint {path} {
  set n 0
  set fh [::open $path r] ; set src [read $fh] ; ::close $fh
  foreach l [split $src "\n"] {
    if {[string index [string trimleft $l] 0] eq {#}} { continue }
    if {[regexp {\m(trnoise|trrandom|notrnoise)\M} $l]} { incr n }
  }
  return $n
}
check {NZ1 no command line of ase_window.tcl spells a noise function or the kill\
 switch -- they arrive as data -- while the adapter's file does} \
  [list [nz_lint [file join $repo src ase_window.tcl]] \
        [expr {[nz_lint [file join $repo src ase.tcl]] > 10}]] \
  {0 1}

# ===========================================================================
# NC -- THE COMMITTED CORPUS
# ===========================================================================
source [file join $repo tests headless state_roundtrip.tcl]
set NC1 [ase_state_roundtrip $repo]
puts "  NC1 tracked [s_dget $NC1 tracked] bad {[s_dget $NC1 bad]} control_disagrees\
 [s_dget $NC1 control_disagrees] control_agrees [s_dget $NC1 control_agrees]"
check {NC1 the committed .state files round-trip byte-identically, both controls\
 disagreeing and agreeing} \
  [list [expr {[s_dget $NC1 tracked] >= 104}] [s_dget $NC1 bad] \
        [s_dget $NC1 control_disagrees] [s_dget $NC1 control_agrees]] \
  {1 {} 1 1}

} herr]} { check {N0 the headless sections ran to the end} "RAISED:$herr" {} }

# ============================================================================
# THE WIDGET LEGS (DISPLAY only, self-skipping)
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {
if {[catch {

set GSCH "v {xschem version=3.4.8 file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {devices/vsource} 600 -300 0 0 {name=V1 value=1}\n"
file mkdir [file join $scratch glib bench schematic]
set f [::open [file join $scratch glib bench schematic bench.sch] w]
puts -nonewline $f $GSCH
::close $f
set f [::open [file join $scratch library.defs] w]
puts $f "DEFINE glib [file join $scratch glib]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
::close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
library_new_view glib bench ngspice_state1 ngspice_state1
set gpath [xschem cellview_path glib/bench ngspice_state1]
if {$gpath eq {}} { error "fixture: state view did not resolve" }
set gkey [ase::session_key glib bench ngspice_state1]
ase::session_open $gkey [file normalize $gpath]
set GRUN [file join $scratch run]
file mkdir $GRUN
set gst [ase::session_state $gkey]
dict set gst rundir $GRUN
dict set gst analyses {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
ase::session_update $gkey $gst
check "GD0 open_state -> 1" [ase::open_state glib bench ngspice_state1] 1
update
set gtop [ase::ui::window_for $gkey]
check_true "GD0 session window up" [expr {$gtop ne {} && [winfo exists $gtop]}]

## THE CIRCUIT THE FACTS ARE TAKEN FROM: a netlist file primed through the product's
## own seam (`ase::facts_capture`), so the slot is warm with no `xschem netlist`.
set GNL "* nzbench\nvdd vdd 0 dc 1.8\nvsig in 0 dc 0 sin(0 1 1k)\nvrts rts 0 dc 0\niref 0 bias dc 0\nr1 vdd out 1k\nr2 out 0 1k\nrin in 0 1k\nrrts rts 0 1k\nrb bias 0 1k\n.end\n"
set GNLP [file join $GRUN bench_nl.spice]
set f [::open $GNLP w] ; puts -nonewline $f $GNL ; ::close $f
proc g_warm {} {
  global gkey GNLP
  ase::facts_capture [ase::session_state $gkey] $GNLP
  return [dict get [ase::facts_status [ase::session_state $gkey]] state]
}
check "GD0 the fixture's facts are warm" [g_warm] warm

proc g_bench {rows {opts {}}} {
  global gkey
  catch {ase::ui::chana_cancel $gkey}
  set st [ase::session_state $gkey]
  dict set st analyses $rows
  dict set st options $opts
  ase::session_update $gkey $st
  ase::ui::populate $gkey
  update
}
proc g_chana {{idx {}}} {
  global gkey gtop
  catch {ase::ui::chana_cancel $gkey}
  if {$idx eq {}} {
    ase::ui::choose_analyses $gkey tran
  } else {
    ase::ui::choose_analyses $gkey {} $idx
  }
  update
  return $gtop.chana
}
proc g_unfold {cw} {
  if {[winfo exists $cw.noise.hdr] && ![winfo exists $cw.noise.tv]} {
    $cw.noise.hdr invoke
    update
  }
  return [winfo exists $cw.noise.tv]
}
proc g_type {w v} {
  if {![winfo exists $w]} { return 0 }
  $w delete 0 end
  if {$v ne {}} { $w insert 0 $v }
  update
  return 1
}
proc g_set {w v} {
  if {![winfo exists $w]} { return 0 }
  $w set $v
  update
  return 1
}
proc g_text {w} {
  if {![winfo exists $w]} { return NOWIDGET }
  return [$w cget -text]
}
proc g_ent {} { global gkey ; return [s_ans ase::ui::nz_entries $gkey tran] }
proc g_bytes {} { global gkey ; return [ase::state_serialize [ase::session_state $gkey]] }
## Choose a function on the Add row, then a target, then press Add.
proc g_add {cw fnlabel target} {
  if {![winfo exists $cw.noise.bar.func]} { return 0 }
  $cw.noise.bar.func set $fnlabel
  event generate $cw.noise.bar.func <<ComboboxSelected>>
  update
  $cw.noise.bar.target set $target
  $cw.noise.bar.add invoke
  update
  return 1
}
proc g_tvrows {cw} {
  if {![winfo exists $cw.noise.tv]} { return NOTABLE }
  set out {}
  foreach it [$cw.noise.tv children {}] { lappend out [$cw.noise.tv item $it -values] }
  return $out
}
set TNLBL [ase::ui::nz_fn_label ngspice tran trnoise]
set TRLBL [ase::ui::nz_fn_label ngspice tran trrandom]

# ---------------------------------------------------------------------------
# GD -- THE SECTION: TRAN ONLY, FOLDED, DESTROYED ON A TYPE SWITCH
# ---------------------------------------------------------------------------
set cw [g_chana]
check "GD1 the Tran form carries the section, folded shut, its header composed from\
 the contract's noun and counting the entries" \
  [list [winfo exists $cw.noise] [g_text $cw.noise.hdr] [winfo exists $cw.noise.tv]] \
  [list 1 "▸ [string totitle [ase::stimuli_noun ngspice tran 2]] (0)" 0]
set GD2 {}
foreach gt [ase::analysis_offered ngspice] {
  if {$gt eq {tran} || ![winfo exists $cw.types.$gt]} { continue }
  $cw.types.$gt invoke
  update
  if {[winfo exists $cw.noise]} { lappend GD2 $gt }
}
$cw.types.tran invoke
update
check "GD2 no other analysis form keeps the section -- the destroy-list trap -- and\
 the Tran form gets it back" \
  [list $GD2 [winfo exists $cw.noise] [expr {[llength [ase::analysis_offered ngspice]] > 4}]] {{} 1 1}
check "GD3 unfolding shows the caption, the table, the Add row and the three text\
 lines, and the header turns" \
  [list [g_unfold $cw] [g_text $cw.noise.cap] [winfo exists $cw.noise.bar.add] \
        [winfo exists $cw.noise.readout] [winfo exists $cw.noise.note] \
        [winfo exists $cw.noise.seed] [string index [g_text $cw.noise.hdr] 0]] \
  [list 1 [ase::ui::lbl_nz_caption ngspice tran] 1 1 1 1 ▾]
if {[winfo exists $cw.form.advbtn]} { $cw.form.advbtn invoke ; update }
set GD4A [winfo exists $cw.noise.tv]
if {[winfo exists $cw.form.advbtn]} { $cw.form.advbtn invoke ; update }
check "GD4 a form rebuild (Advanced) keeps the section unfolded" \
  [list $GD4A [winfo exists $cw.noise.tv]] {1 1}

# ---------------------------------------------------------------------------
# GO -- OPENING IT STARTS NOTHING
# ---------------------------------------------------------------------------
set ::GOCALLS {}
set GODOORS {::ase::netlist ::ase::netlist_in_place ::ase::run_deck ::ase::event_nodes \
             ::ase::event_probe ::ase::analysis_detect ::ase::sim_capabilities}
foreach gp $GODOORS {
  rename $gp ${gp}__go1467
  proc $gp {args} "lappend ::GOCALLS [list $gp] ; return -code error {GO: $gp called}"
}
if {[catch {
  set cw [g_chana]
  g_unfold $cw
  g_add $cw $TNLBL {Source vdd}
  g_type $cw.noise.ed.args.na 1m
  g_type $cw.noise.ed.args.ts 10u
  g_add $cw $TRLBL {Net bias}
  $cw.types.dc invoke ; update
  $cw.types.tran invoke ; update
  catch {ase::ui::chana_cancel $gkey}
} goerr]} { lappend ::GOCALLS "RAISED:$goerr" }
set GOBEFORE $::GOCALLS
catch {::ase::netlist {}}
set GOCTRL [llength $::GOCALLS]
foreach gp $GODOORS {
  rename $gp {}
  rename ${gp}__go1467 $gp
}
check "GO1 opening the section, adding, typing and switching types reaches no netlist,\
 probe or simulator door -- and a stubbed door does count" \
  [list $GOBEFORE $GOCTRL] {{} 1}

# ---------------------------------------------------------------------------
# GB -- BYTE IDENTITY
# ---------------------------------------------------------------------------
g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set GB1B [g_bytes]
set cw [g_chana]
g_unfold $cw
$cw.btns.proceed invoke ; update
set GB1R [lindex [ase::state_get [ase::session_state $gkey] analyses] 1]
check "GB1 an untouched bench opened, unfolded and OKed closes, writes the same bytes\
 and gains no table key" \
  [list [winfo exists $cw] [expr {[g_bytes] eq $GB1B}] [dict exists $GB1R noise]] {0 1 0}

## ⚠ A HAND-WRITTEN TABLE: an entry's keys out of the order the form writes, a
## switched-off entry, and a third kind -- every one of which must show, and none
## of which may move a byte by being looked at.
set GBTBL {{func trnoise src vdd ts 10u na 1m} {net bias func trrandom dist 2 ts 100u td 1n param1 1m enabled 0} {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}
g_bench [list {type op enabled 1} [list type tran enabled 1 step 1u stop 2m noise $GBTBL]]
set GB2B [g_bytes]
set cw [g_chana]
g_unfold $cw
set GB2EXP {}
set gk 0
foreach ge $GBTBL {
  incr gk
  lappend GB2EXP [join [ase::stimuli_values ngspice tran $ge] { }]
}
set GB2TV [g_tvrows $cw]
set GB2VALS {} ; set GB2ON {}
foreach gr $GB2TV { lappend GB2VALS [lindex $gr 3] ; lappend GB2ON [lindex $gr 0] }
foreach gi {n2 n3 n1} {
  if {[$cw.noise.tv exists $gi]} { $cw.noise.tv selection set [list $gi] ; update }
}
$cw.types.dc invoke ; update
$cw.types.tran invoke ; update
$cw.btns.proceed invoke ; update
check "GB2 every entry of a hand-written table is listed with the values the deck\
 writes, positionally and padded, its switch shown -- and looking at each writes\
 the same bytes" \
  [list [llength $GB2TV] [expr {$GB2VALS eq $GB2EXP}] $GB2ON [expr {[g_bytes] eq $GB2B}]] \
  [list 3 1 [list ☑ ☐ ☑] 1]
check "GB3 the Arguments column counts the entries that reach the deck, and a row with\
 no table reads exactly as before" \
  [list [lindex [$gtop.body.ana.tv item 1 -values] 3] [lindex [$gtop.body.ana.tv item 0 -values] 3]] \
  [list "tran 1u 2m  + 2 [ase::stimuli_noun ngspice tran 2]" op]

g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set GB4B [g_bytes]
set cw [g_chana]
g_unfold $cw
g_add $cw $TNLBL {Source vdd}
set GB4MID [llength [g_ent]]
$cw.noise.bar.del invoke ; update
$cw.btns.proceed invoke ; update
check "GB4 an entry added and deleted again leaves the bench's bytes as they were" \
  [list $GB4MID [expr {[g_bytes] eq $GB4B}]] {1 1}

g_bench [list {type op enabled 1} {type tran enabled 1 step 1u stop 2m noise {{src vdd func trnoise na 1m ts 10u}}}]
set cw [g_chana]
g_unfold $cw
$cw.noise.bar.del invoke ; update
$cw.btns.proceed invoke ; update
set GB5R [lindex [ase::state_get [ase::session_state $gkey] analyses] 1]
check "GB5 deleting every entry of a stored table and pressing OK removes the key --\
 an empty table is written as no table" \
  [list [winfo exists $cw] [dict exists $GB5R noise] $GB5R] \
  {0 0 {type tran enabled 1 step 1u stop 2m}}

## ⚠ RETYPING PASSES THROUGH AN EMPTY FIELD, and an emptied argument loses its key.
## Measured while writing this row: without the editor remembering the entry's key
## order, deleting and re-entering `10u` moved `ts` to the end of a hand-written
## entry and changed the bench's bytes for a value that had not changed.
## ⚠ ONE FIELD, NOT TWO. Retyping `ts` and then `na` puts `na` back last, which is
## where this entry already had it -- the second retype repaired the first by
## coincidence, and the no-reorder mutation W13 SURVIVED this row. `ts` alone
## cannot repair itself.
g_bench [list {type op enabled 1} [list type tran enabled 1 step 1u stop 2m noise $GBTBL]]
set GB6B [g_bytes]
set cw [g_chana]
g_unfold $cw
g_type $cw.noise.ed.args.ts 10u
$cw.btns.proceed invoke ; update
check "GB6 retyping an entry's own values into it moves no byte, whatever order its\
 keys were written in" \
  [list [winfo exists $cw] [expr {[g_bytes] eq $GB6B}]] {0 1}

# ---------------------------------------------------------------------------
# GA -- THE ADD CONTROL OFFERS ONLY LEGAL TARGETS
# ---------------------------------------------------------------------------
proc g_offer {fn} {
  global gkey GNL
  set c [ase::stimuli_candidates ngspice tran $fn [ase::netlist_facts_cached [ase::session_state $gkey]] $GNL [ase::session_state $gkey]]
  set out {}
  foreach t [ase::ui::nz_targets ngspice tran] {
    foreach nm [dict get $c [lindex $t 0]] { lappend out "[lindex $t 1] $nm" }
  }
  return $out
}
## A bench with no table, so each Add below is the only entry (GB6 leaves one).
g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set cw [g_chana]
g_unfold $cw
check "GA1 the Add row offers the contract's functions, in order, by label" \
  [$cw.noise.bar.func cget -values] [ase::ui::nz_fn_labels ngspice tran]
$cw.noise.bar.func set $TNLBL ; event generate $cw.noise.bar.func <<ComboboxSelected>> ; update
set GA2N [$cw.noise.bar.target cget -values]
$cw.noise.bar.func set $TRLBL ; event generate $cw.noise.bar.func <<ComboboxSelected>> ; update
set GA2R [$cw.noise.bar.target cget -values]
check "GA2 its targets are the adapter's candidates for the function shown -- the\
 waveform-carrying source never, the current source only for noise" \
  [list [expr {$GA2N eq [g_offer trnoise]}] [expr {$GA2R eq [g_offer trrandom]}] \
        [lsearch -exact $GA2N {Source vsig}] [expr {[lsearch -exact $GA2N {Source iref}] >= 0}] \
        [lsearch -exact $GA2R {Source iref}] [expr {[llength $GA2N] >= 7}]] \
  {1 1 -1 1 -1 1}
catch {ase::ui::chana_cancel $gkey}
ase::facts_clear
set cw [g_chana]
g_unfold $cw
set GA3T [$cw.noise.bar.target cget -values]
$cw.noise.bar.add invoke ; update
set GA3E [g_ent]
set GA3N [g_text $cw.noise.note]
catch {ase::ui::chana_cancel $gkey}
g_warm
check "GA3 on a bench with no facts nothing is offered, and Add still makes an entry\
 whose verdict says it names nothing -- the name can be typed, so it is no dead end" \
  [list $GA3T $GA3E [string match {*names no source and no net*} $GA3N]] \
  [list {} [list [dict create [ase::stimuli_get ngspice tran selector] trnoise]] 1]

# ---------------------------------------------------------------------------
# GE -- THE EDITOR
# ---------------------------------------------------------------------------
g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set cw [g_chana]
g_unfold $cw
g_add $cw $TNLBL {Source vdd}
proc g_argorder {cw} {
  set out {}
  if {![winfo exists $cw.noise.ed.args]} { return NOARGS }
  foreach c [winfo children $cw.noise.ed.args] {
    set t [winfo name $c]
    if {[string index $t 0] ne {l}} { lappend out $t }
  }
  return $out
}
proc g_explabels {fn quantity {e {}}} {
  set out {}
  foreach d [ase::stimuli_args ngspice tran $fn] {
    set l [dict get $d label]
    if {[dict exists $d labels] && [dict exists $e dist] \
        && [dict exists [dict get $d labels] [dict get $e dist]]} {
      set l [dict get [dict get $d labels] [dict get $e dist]]
    }
    if {[dict exists $d unit]} {
      set u [dict get $d unit]
      if {$u eq {source}} { set u $quantity }
      append l " ($u)"
    }
    lappend out "$l:"
  }
  return $out
}
proc g_labels {cw} {
  set out {}
  if {![winfo exists $cw.noise.ed.args]} { return NOARGS }
  foreach c [winfo children $cw.noise.ed.args] {
    if {[string index [winfo name $c] 0] eq {l}} { lappend out [$c cget -text] }
  }
  return $out
}
check "GE1 the editor's fields are the function's arguments in positional order,\
 labelled from the contract, amplitudes in volts on a voltage source" \
  [list [g_argorder $cw] [expr {[g_labels $cw] eq [g_explabels trnoise V]}] \
        [g_text $cw.noise.ed.ltarget] [$cw.noise.ed.route get] [$cw.noise.ed.name get] \
        [$cw.noise.ed.func get]] \
  [list [ase::stimuli_arg_names ngspice tran trnoise] 1 [ase::ui::lbl_nz_target] \
        [ase::ui::nz_target_label ngspice tran src] vdd $TNLBL]
g_type $cw.noise.ed.args.na 1m
g_type $cw.noise.ed.args.ts 10u
g_set $cw.noise.ed.route [ase::ui::nz_target_label ngspice tran net]
check "GE2 typing writes the entry as it is typed, and moving it to a net carries the\
 name across and turns every amplitude into amperes" \
  [list [g_ent] [expr {[g_labels $cw] eq [g_explabels trnoise A]}]] \
  [list [list {func trnoise na 1m ts 10u net vdd}] 1]
g_set $cw.noise.ed.route [ase::ui::nz_target_label ngspice tran src]
g_set $cw.noise.ed.func $TRLBL
## ⚠ `src` IS BACK IN FIRST PLACE, where the entry had it when the editor loaded it:
## the move to a net and back passed through an entry with no `src` key at all.
check "GE3 switching the function drops the arguments it does not have, keeps the one\
 it shares, and rebuilds the fields in its own order" \
  [list [g_ent] [g_argorder $cw]] \
  [list [list {src vdd func trrandom ts 10u}] [ase::stimuli_arg_names ngspice tran trrandom]]
set GE4D [lindex [ase::stimuli_args ngspice tran trrandom] 0]
check "GE4 the distribution is chosen by name from the declared values" \
  [$cw.noise.ed.args.dist cget -values] [ase::ui::nz_value_labels $GE4D]
g_set $cw.noise.ed.args.dist [ase::ui::nz_value_label $GE4D 3]
g_type $cw.noise.ed.args.param1 1m
check "GE5 picking one writes its value, and the parameters are relabelled for it" \
  [list [s_dget [lindex [g_ent] 0] dist] [expr {[g_labels $cw] eq [g_explabels trrandom V [lindex [g_ent] 0]]}]] \
  {3 1}
$cw.noise.ed.on invoke ; update
set GE6OFF [list [s_dget [lindex [g_ent] 0] enabled] [lindex [lindex [g_tvrows $cw] 0] 0]]
$cw.noise.ed.on invoke ; update
check "GE6 Enable off writes the entry's switch and the table shows it; on again takes\
 the key away rather than writing 1" \
  [list $GE6OFF [dict exists [lindex [g_ent] 0] enabled] [lindex [lindex [g_tvrows $cw] 0] 0]] \
  [list {0 ☐} 0 ☑]
catch {ase::ui::chana_cancel $gkey}

# ---------------------------------------------------------------------------
# GL -- THE LIVE READOUTS, AGAINST THE ARITHMETIC
# ---------------------------------------------------------------------------
## ⚠ THE EXPECTED TEXT IS COMPUTED HERE FROM THE FORMULAS, NOT FROM ase:: --
## density A*sqrt(2*TS), flat to 1/(2*TS), points max(stop/step, 5*stop/TS).
proc g_group {n} {
  set s [format %.0f $n]
  while {[regsub {^([0-9]+)([0-9]{3})} $s {\1,\2} s]} {}
  return $s
}
set cw [g_chana]
g_unfold $cw
g_add $cw $TNLBL {Source vdd}
g_type $cw.noise.ed.args.na 1m
g_type $cw.noise.ed.args.ts 10u
set GLD [format %.3g [expr {1e-3 * sqrt(2 * 10e-6)}]]
set GLF [format %.3g [expr {1.0 / (2 * 10e-6) / 1e3}]]
set GLP [g_group [expr {max(2e-3 / 1e-6, 5 * 2e-3 / 10e-6)}]]
check "GL1 the readout under the entry is the arithmetic, every number worded as an\
 estimate, and no file size before a run has been made" \
  [g_text $cw.noise.readout] \
  "Estimates: density ≈ $GLD V/√Hz, flat to ≈ $GLF kHz · ≈ $GLP points"
g_type $cw.noise.ed.args.ts 100n
check "GL2 a smaller noise timestep raises the point estimate past the card's own" \
  [regexp -inline {≈ [0-9,]+ points} [g_text $cw.noise.readout]] \
  [list "≈ [g_group [expr {max(2e-3 / 1e-6, 5 * 2e-3 / 100e-9)}]] points"]
g_type $cw.noise.ed.args.ts 10u
g_type $cw.form.stop 20m
## ⚠ FOCUS FIRST: Tk delivers a generated key event to the window holding the
## focus, not to the one named -- measured, without this the binding never ran
## and the row read the old estimate. A user typing there has the focus.
focus -force $cw.form.stop
update
event generate $cw.form.stop <KeyRelease>
update
check "GL3 typing a new stop time into the form moves the estimate with it" \
  [regexp -inline {≈ [0-9,]+ points} [g_text $cw.noise.readout]] \
  [list "≈ [g_group [expr {max(20e-3 / 1e-6, 5 * 20e-3 / 10e-6)}]] points"]
check "GL4 every number on the line carries the estimate mark" \
  [expr {[regexp -all {[0-9]} [g_text $cw.noise.readout]] > 0 \
         && [llength [regexp -all -inline {≈ [0-9.,e+-]+} [g_text $cw.noise.readout]]] == 3}] 1
catch {ase::ui::chana_cancel $gkey}

# ---------------------------------------------------------------------------
# GV -- PER-ENTRY VERDICTS, AND OK
# ---------------------------------------------------------------------------
g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set GVB [g_bytes]
set cw [g_chana]
g_unfold $cw
g_add $cw $TNLBL {Source vdd}
g_type $cw.noise.ed.args.na 1m
g_type $cw.noise.ed.args.ts -1u
set GVROW [ase::ui::chana_merged_row $gkey tran]
set GVL {}
foreach gf [ase::stimuli_verdicts ngspice $GVROW [ase::netlist_facts_cached [ase::session_state $gkey]] [ase::session_state $gkey]] {
  if {[lindex $gf 0] == 1} { lappend GVL [linsert [lrange $gf 1 3] 0 stimuli_check] }
}
check "GV1 an entry the run would refuse is marked in the table, and its verdict is\
 said under it in the precondition banner's own shape" \
  [list [lindex [lindex [g_tvrows $cw] 0] 4] \
        [expr {[g_text $cw.noise.note] eq [ase::precheck_banner_text [list state fatal lines $GVL]]}] \
        [string match {*negative noise timestep*} [g_text $cw.noise.note]] \
        [string match {*negative noise timestep*} [g_text $cw.note]]] \
  {⊘ 1 1 1}
$cw.btns.proceed invoke ; update
check "GV2 OK refuses the changed table: the dialog stays, says why, and the bench is\
 untouched" \
  [list [winfo exists $cw] [string match {*negative noise timestep*} [g_text $cw.status]] \
        [expr {[g_bytes] eq $GVB}]] {1 1 1}
g_type $cw.noise.ed.args.ts 10u
set GV3M [lindex [lindex [g_tvrows $cw] 0] 4]
$cw.btns.proceed invoke ; update
check "GV3 put right, the mark clears and OK writes the table" \
  [list $GV3M [winfo exists $cw] \
        [s_dget [lindex [ase::state_get [ase::session_state $gkey] analyses] 1] noise]] \
  [list {} 0 [list {src vdd func trnoise na 1m ts 10u}]]

## ⚠ ONLY A CHANGED TABLE IS REFUSED. A hand-edited `.state` can carry a table the
## run refuses; the dialog says so, and still lets the user change anything else
## on the form -- the run's own gate refuses the table when it matters.
g_bench [list {type op enabled 1} {type tran enabled 1 step 1u stop 2m noise {{src vdd func trnoise na 1m ts -1u}}}]
set cw [g_chana]
g_unfold $cw
set GV4N [string match {*negative noise timestep*} [g_text $cw.noise.note]]
g_type $cw.form.stop 3m
$cw.btns.proceed invoke ; update
set GV4R [lindex [ase::state_get [ase::session_state $gkey] analyses] 1]
check "GV4 an untouched table the run would refuse does not trap the dialog: its\
 verdict shows, and OK writes the form's own change and leaves the table as it was" \
  [list $GV4N [winfo exists $cw] [s_dget $GV4R stop] [s_dget $GV4R noise]] \
  [list 1 0 3m {{src vdd func trnoise na 1m ts -1u}}]

g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set cw [g_chana]
g_unfold $cw
g_add $cw $TNLBL {Source vdd}
g_type $cw.noise.ed.args.ts 10u
set GV5M [lindex [lindex [g_tvrows $cw] 0] 4]
$cw.btns.proceed invoke ; update
check "GV5 a table carrying only a caution is marked and still commits" \
  [list $GV5M [winfo exists $cw] \
        [s_dget [lindex [ase::state_get [ase::session_state $gkey] analyses] 1] noise]] \
  [list ⚠ 0 {{src vdd func trnoise ts 10u}}]

g_bench [list {type op enabled 1} {type tran enabled 1 step 1u stop 2m noise {{src vdd func trnoise na 1m ts 10u} {src vrts func trnoise na 1m ts -1u}}}]
set cw [g_chana]
g_unfold $cw
set GV6A [g_text $cw.noise.note]
$cw.noise.tv selection set [list n2] ; update
set GV6B [g_text $cw.noise.note]
set GV6M [list [lindex [lindex [g_tvrows $cw] 0] 4] [lindex [lindex [g_tvrows $cw] 1] 4]]
catch {ase::ui::chana_cancel $gkey}
check "GV6 the verdict line speaks for the entry selected -- nothing under a clean one,\
 the refusal under the one that earns it -- and only that one's line is marked" \
  [list $GV6A [string match {*negative noise timestep*} $GV6B] $GV6M] \
  [list {} 1 [list {} ⊘]]

# ---------------------------------------------------------------------------
# GS -- THE SEED AND KILL-SWITCH SENTENCES, VERBATIM
# ---------------------------------------------------------------------------
set GSTBL {{src vdd func trnoise na 1m ts 10u} {net bias func trrandom dist 2 ts 100u td 1n param1 1m} {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}
set GSROW [list type tran enabled 1 step 1u stop 2m noise $GSTBL]
proc g_foot {opts} {
  global gkey GSROW
  g_bench [list {type op enabled 1} $GSROW] $opts
  set cw [g_chana]
  g_unfold $cw
  set st [ase::session_state $gkey]
  set exp [concat [dict get [ase::stimuli_seed_report ngspice $st $GSROW] sentences] \
                  [dict get [ase::stimuli_kill_report ngspice $st $GSROW] sentences]]
  set got [g_text $cw.noise.seed]
  catch {ase::ui::chana_cancel $gkey}
  return [list $got [join $exp "\n"]]
}
set GS1 [g_foot {}]
check "GS1 the seed sentences are core's report, verbatim, split by kind" \
  [list [expr {[lindex $GS1 0] eq [lindex $GS1 1]}] \
        [string match {White noise does not repeat*} [lindex $GS1 0]] \
        [string match {*repeat only when a seed is set.} [lindex $GS1 0]]] {1 1 1}
set GS2 [g_foot {{name seed value 5}}]
check "GS2 with a seed on the bench they say what repeats exactly" \
  [list [expr {[lindex $GS2 0] eq [lindex $GS2 1]}] \
        [string match {*repeat exactly under the seed.} [lindex $GS2 0]]] {1 1}
set GS3 [g_foot {{name notrnoise}}]
check "GS3 with the kill switch armed its sentences follow, verbatim" \
  [list [expr {[lindex $GS3 0] eq [lindex $GS3 1]}] \
        [string match {*With notrnoise set, noise source 1 loses its white noise*} [lindex $GS3 0]] \
        [string match {*does not switch them off.} [lindex $GS3 0]]] {1 1 1}

g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set cw [g_chana]
g_unfold $cw
set GS4A [g_text $cw.noise.seed]
g_add $cw $TRLBL {Net bias}
g_type $cw.noise.ed.args.ts 100u
g_type $cw.noise.ed.args.param1 1m
set GS4B [g_text $cw.noise.seed]
set GS4X [join [dict get [ase::stimuli_seed_report ngspice [ase::session_state $gkey] \
                  [ase::ui::chana_merged_row $gkey tran]] sentences] "\n"]
catch {ase::ui::chana_cancel $gkey}
check "GS4 the footer follows the table as it is edited, before OK: an empty table says\
 nothing, and a random source once added says what it repeats" \
  [list $GS4A [expr {$GS4B eq $GS4X}] [expr {$GS4B eq {Random sources repeat only when a seed is set.}}]] \
  {{} 1 1}

# ---------------------------------------------------------------------------
# GK -- DIALOG MEMORY
# ---------------------------------------------------------------------------
g_bench {{type op enabled 1} {type tran enabled 1 step 1u stop 2m}}
set GKB [g_bytes]
set cw [g_chana]
g_unfold $cw
g_add $cw $TNLBL {Source vdd}
g_type $cw.noise.ed.args.na 1m
$cw.types.ac invoke ; update
$cw.types.tran invoke ; update
set GK1 [list [g_ent] [llength [g_tvrows $cw]]]
$cw.btns.cancel invoke ; update
set cw [g_chana]
g_unfold $cw
check "GK1 a type switch keeps what was added; Cancel throws it away and a reopened\
 dialog starts from the bench" \
  [list $GK1 [llength [g_tvrows $cw]] [expr {[g_bytes] eq $GKB}]] \
  [list [list [list {src vdd func trnoise na 1m}] 1] 0 1]
catch {ase::ui::chana_cancel $gkey}

g_bench {{type tran enabled 1 step 1u stop 2m} {type tran enabled 0 step 1u stop 4m}}
set cw [g_chana 1]
g_unfold $cw
g_add $cw $TNLBL {Source vrts}
g_type $cw.noise.ed.args.rtsam 5m
g_type $cw.noise.ed.args.rtscapt 18u
g_type $cw.noise.ed.args.rtsemt 30u
$cw.rows selection set [list 0] ; update
set GK2A [llength [g_tvrows $cw]]
$cw.rows selection set [list 1] ; update
set GK2B [g_ent]
$cw.btns.proceed invoke ; update
set GK2ROWS [ase::state_get [ase::session_state $gkey] analyses]
check "GK2 two transient rows keep two tables: picking the first shows its own, the\
 second's edit survives, and OK writes the addressed row alone" \
  [list $GK2A $GK2B [winfo exists $cw] [dict exists [lindex $GK2ROWS 0] noise] \
        [s_dget [lindex $GK2ROWS 1] noise]] \
  [list 0 [list {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}] 0 0 \
        [list {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}]]

## ============================================================================
## EE -- VALUES TYPED INTO THE WIDGETS, THE DECK, AND A REAL RUN ON BOTH BINARIES
## ============================================================================
## ⚠ ISSUE 1449's LESSON, THE THIRD TIME: two halves of a feature tested in
## different suites never meet. Stage 9's SP14 went from a port typed into the
## table to a run; this goes from noise typed into the Tran form to a run, and
## back to the form, which then estimates the results file from that run.
set EERUN $GRUN
proc ee_binaries {} {
  if {[info exists ::env(ASE_NZ_NGSPICE)] && $::env(ASE_NZ_NGSPICE) ne {}} {
    set out {} ; set i 0
    foreach b [split $::env(ASE_NZ_NGSPICE) :] { incr i ; lappend out [list env$i $b] }
    return $out
  }
  return [list [list apt /usr/bin/ngspice] \
               [list fork /home/analog/dev/ngspice/build-ver_50/src/ngspice]]
}
g_bench {{type tran enabled 1 step 10u stop 2m}}
g_warm
set cw [g_chana]
g_unfold $cw
g_add $cw $TNLBL {Source vdd}
g_type $cw.noise.ed.args.na 1m
g_type $cw.noise.ed.args.ts 10u
g_add $cw $TRLBL {Net bias}
g_set $cw.noise.ed.args.dist [ase::ui::nz_value_label [lindex [ase::stimuli_args ngspice tran trrandom] 0] 2]
g_type $cw.noise.ed.args.ts 100u
g_type $cw.noise.ed.args.td 1n
g_type $cw.noise.ed.args.param1 1m
set EEPTS {}
regexp {≈ ([0-9,]+) points} [g_text $cw.noise.readout] -> EEPTS
set EEPTS [string map {, {}} $EEPTS]
$cw.btns.proceed invoke ; update
set EEST [ase::session_state $gkey]
set EEDECK [s_ans ase::backend::ngspice::render_deck $EEST $GNL]
set EEL [split $EEDECK "\n"]
check "EE1 the entries typed into the form reach the deck: the carrier after the\
 netlist, every argument positionally and padded above the card, the restores" \
  [list [lsearch -all -inline -glob $EEL {alter *}] \
        [expr {[lsearch -exact $EEL {vase_noise_1_2 ase_noise_1_2 0 dc 0}] >= 0}] \
        [expr {[lsearch -exact $EEL {gase_noise_1_2 0 bias ase_noise_1_2 0 1}] >= 0}] \
        [string is integer -strict $EEPTS]] \
  [list [list {alter vdd trnoise = [ 1m 10u 0 0 0 0 0 ]} {alter vase_noise_1_2 trrandom = [ 2 100u 1n 1m 0 ]} \
              {alter vdd trnoise = [ 0 0 0 0 0 0 0 ]} {alter vase_noise_1_2 trnoise = [ 0 0 0 0 0 0 0 ]}] 1 1 1]
set EERAW [ase::backend::ngspice::raw_file $EEST]
set EEMAP [ase::plotmap_path $EEST]
set EEDF [file join $EERUN bench_ase_ee.spice]
set f [::open $EEDF w] ; puts -nonewline $f $EEDECK ; ::close $f
set EESEEN {}
foreach eepair [ee_binaries] {
  lassign $eepair eetag eebin
  if {$eebin eq {} || ![file executable $eebin]} {
    puts "SKIPPED: EE $eetag end-to-end leg (no executable at '$eebin')"
    continue
  }
  lappend EESEEN $eetag
  file delete -force $EERAW $EEMAP
  set eerc [catch {exec env HOME=$scratch timeout 120 $eebin -b $EEDF 2>@1} eeout]
  set rd [file join $EERUN ee_reader.cir]
  set f [::open $rd w]
  puts $f "* reader\nrdummy a 0 1\n.control\nload $EERAW"
  puts $f "let s1 = stddev(v(vdd))\nlet s2 = stddev(v(bias))\nlet n0 = length(time)"
  puts $f "echo NZ \$&s1 \$&s2 \$&n0\n.endc\n.end"
  ::close $f
  catch {exec env HOME=$scratch timeout 60 $eebin -b $rd 2>@1} rdout
  set s1 {} ; set s2 {} ; set n0 {}
  regexp -line {^NZ (\S+) (\S+) (\S+)} $rdout -> s1 s2 n0
  check "EE2/$eetag that deck runs, the supply the form named is noisy, the net it\
 named carries a random current, and the point count is within a factor of two of\
 the form's estimate ($EEPTS)" \
    [list $eerc [expr {[string is double -strict $s1] && $s1 > 0}] \
          [expr {[string is double -strict $s2] && $s2 > 0}] \
          [expr {[string is double -strict $n0] && [string is integer -strict $EEPTS] \
                 && $n0 >= $EEPTS / 2.0 && $n0 <= $EEPTS * 2.0}]] \
    {0 1 1 1}
  if {$eerc} { puts "  EE2/$eetag output: $eeout" }
  puts "  EE2/$eetag stddev v(vdd)=$s1 v(bias)=$s2 points=$n0 estimate=$EEPTS"
  ## ⚠ AND BACK TO THE FORM: the run's results file is now there, so the section
  ## has a vector count and estimates the file -- which is checked against the
  ## file this run just wrote.
  set cw [g_chana]
  g_unfold $cw
  set EEB {}
  set eeu {}
  regexp {results file ≈ ([0-9.]+) (bytes|kB|MB|GB)} [g_text $cw.noise.readout] -> EEB eeu
  set eemul [expr {$eeu eq {kB} ? 1e3 : ($eeu eq {MB} ? 1e6 : ($eeu eq {GB} ? 1e9 : 1))}]
  set eesz -1
  catch {set eesz [file size $EERAW]}
  check "EE3/$eetag after the run the form estimates the results file, from that run's\
 own vector count, within a factor of two of the file it wrote" \
    [list [string is double -strict $EEB] \
          [expr {[string is double -strict $EEB] && $eesz > 0 \
                 && $EEB * $eemul >= $eesz / 2.0 && $EEB * $eemul <= $eesz * 2.0}]] {1 1}
  puts "  EE3/$eetag readout [g_text $cw.noise.readout] ; file $eesz bytes"
  catch {ase::ui::chana_cancel $gkey}
}
if {![llength $EESEEN]} { puts "SKIPPED: EE -- no ngspice binary found on this machine" }

} gerr]} { check {G0 the widget legs ran to the end} "RAISED:$gerr $::errorInfo" {} }
} else {
  puts "gui legs skipped (no DISPLAY)"
}

puts "RESULT: [expr {$fail ? "$fail FAILED ($npass passed)" : "ALL PASS ($npass checks)"}]"
# ⚠ THE WHOLE-LINE SENTINEL `tests/banner_rule.tcl` REQUIRES, and an explicit exit:
# the display arm drives the Choose Analyses OK door, and without one the suite
# falls through to xschem's own exit status, which is rc 10 there.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
exit [expr {$fail ? 1 : 0}]
