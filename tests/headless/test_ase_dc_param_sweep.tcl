# tests/headless/test_ase_dc_param_sweep.tcl -- ASE-L's DC analysis sweeps a
# DESIGN VARIABLE.
#
# ngspice sweeps only a V source, an I source, a resistor or `temp`
# (dctrcurv.c), and a `.param` is fixed when the circuit is parsed, so the
# ngspice adapter writes a sweep of a design variable as a LOOP of reloads and
# builds one `DC transfer characteristic` plot.
#
# ⚖ AND THE ROW SAYS WHAT IT SWEEPS. Real benches name a source after the
# variable that sets it (a current source `ILOAD` whose DC value and pulse
# levels both read a variable `iload`), so "is this a variable sweep" cannot
# be decided by the name. The DC form asks what to sweep, as ADE-L does
# (Temperature / Design variable / Component), and nothing is inferred from a
# name matching a variable: a design-variable sweep is a row carrying
# `swkind variable`, and a row without the key means what ngspice's `.dc NAME`
# means. Band K is that rule; band I is that common bench shape, PDK-free.
#
# Code     src/ase.tcl ase::dc_sweep_kind, ase::dc_name_kind, ase::dc_sweep_vals;
#          ase::backend::ngspice::dc_swkind, dcvar_plan, dcvar_msg, dcvar_collect,
#          dcvar_body, dcvar_output_refusals, dc_sweep_candidates, analysis_body,
#          render_deck, result_answers; ase::analysis_emit_check,
#          ase::analysis_schema_errors, ase::field_caption_for_row,
#          ase::needs_eval (sweep_target), ase::preflight_gate;
#          src/ase_window.tcl ase::ui::chana_ok, ase::ui::chana_field_row,
#          ase::ui::chana_mode_changed, ase::ui::chana_label_column,
#          ase::ui::form_get, ase::ui::form_is_absent
#
# Bands
#   K   the sweep kind is the row's own statement: `swkind`, else the name's
#       own meaning; the field, its signature and the corpus
#   I   the ILOAD shape: a source named after its variable is a component
#       sweep, `swkind variable` is the loop, a variable the bench lacks is
#       refused, a legacy `source NSEG` row gets the advice, a kind its name
#       contradicts is refused
#   P   the plan: the point count by ngspice's own rule and every refusal
#   E   the one reader of "can this row reach a deck": the commit door, the gate
#   D   the plain deck (render_deck): the loop, the copies, the plot, the restore
#   C   the collected vectors: top-level nodes and source branches, nothing else
#   O   an output the sweep cannot carry: advice before, the reason after
#   X   REAL ngspice, a plain run: read back as dc with the variable as X,
#       the same silicon at every point, a failing point stops the run; and the
#       ILOAD shape runs as ngspice's own dc with its measurement
#   G   the DC form (display arm only): the three radio buttons, the name's
#       relabel and per-kind list, the hidden name row for Temperature, a
#       legacy row opening on Component, OK writing `swkind variable` only for
#       a variable sweep and an untouched legacy row byte-identically; no input
#       moving when the kind does (G13), and no other form's label column
#       widened by the rule that holds dc's still (G14)
# X prints one `skip:` per row without an ngspice that runs (ASE_DCVAR_NGSPICE,
# else ~/dev/ngspice/build-ver_51/src/ngspice under XSCHEM_TEST_REAL_HOME);
# G prints one `skip:` line for the band under --nogui.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_dc_param_sweep
#   tests/headless/run_suites.sh test_ase_dc_param_sweep          (adds band G)

source [file join [file dirname [info script]] scratch.tcl]

set fail 0 ; set npass 0 ; set nskip 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL" ; incr fail }
}
proc check_true {name cond {detail {}}} {
  global fail npass
  if {$cond} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> [string range $detail 0 600] : FAIL" ; incr fail }
}
proc skiprow {name why} { global nskip ; puts "skip: $name -- $why" ; incr nskip }
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} )] $r]" }
  return $r
}
proc group {name script} {
  if {[catch {uplevel 1 $script} e]} {
    puts "FAIL: group $name ABORTED -> $e : FAIL"
    puts $::errorInfo
    incr ::fail
  }
}
proc dg {d args} { if {[catch {dict get $d {*}$args} v]} { return ABSENT } ; return $v }
proc slurp {f} {
  if {![file exists $f]} { return {} }
  set h [open $f] ; set t [read $h] ; close $h ; return $t
}
proc spit {f t} {
  file mkdir [file dirname $f]
  set h [open $f w] ; puts -nonewline $h $t ; close $h
}
proc dlines {deck re} {
  set out {}
  foreach l [split $deck \n] { if {[regexp $re [string trim $l]]} { lappend out [string trim $l] } }
  return $out
}

set no_recent_files 1
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set t_start [clock milliseconds]
set sd [test_scratch ase_dc_param_sweep]
set NS ase::backend::ngspice

## THE FIXTURE: a segment whose length a design variable sets, with a
## per-instance mismatch draw, two top-level nets and a source, PDK-free.
## xschem spells an instance parameter as a QUOTED expression with spaces.
set NL "** dcvar fixture\n.subckt seg a b L=10\n.param dr=agauss(0,0.05,1)\nR1 a b r='1k*L*(1+MMSW*dr)'\n.ends\nV1 vdd 0 1\nX1 vdd vout seg L='16.62 + (NSEG-16)*0.6'\nX2 vout 0 seg L=10\n.end\n"
## the same, with an operating point that cannot be solved at NSEG 3 only
set NLF "** dcvar failing fixture\n.subckt seg a b L=10\n.param dr=agauss(0,0.05,1)\nR1 a b r='1k*L*(1+MMSW*dr)'\n.ends\nV1 vdd 0 1\nX1 vdd vout seg L='16.62 + (NSEG-16)*0.6'\nX2 vout 0 seg L=10\n.if (NSEG == 3)\nV9 vout 0 2\nV8 vout 0 3\n.endif\n.end\n"
## a design-variable sweep is the row's own statement, `swkind variable` (band K)
set DCV {type dc enabled 1 swkind variable source NSEG start 0 stop 31 step 1}
proc mkst {cell rundir analyses args} {
  set s [ase::state_default]
  dict set s simulator ngspice
  dict set s design [dict create lib dcv cell $cell view schematic]
  dict set s rundir $rundir
  dict set s variables {{name NSEG value 16} {name MMSW value 1}}
  dict set s analyses $analyses
  foreach {k v} $args { dict set s $k $v }
  return $s
}
set ALONE [list {type op enabled 0} $DCV {type ac enabled 0} {type tran enabled 0}]
set S0 [mkst dcv [file join $sd plain] $ALONE]

# ===========================================================================
# K -- THE SWEEP KIND IS THE ROW'S OWN STATEMENT
# ===========================================================================
## ⚖ Nothing is inferred from a name matching a variable. ase::dc_sweep_kind is the one reader; every row below asks it.
proc k_five {} {
  set h {}
  foreach k {render_deck run_cmd log_file result_probe raw_file} {
    dict set h $k [ase::backend_hook ngspice $k]
  }
  return $h
}
## three stand-in registries: the sweep kind spent by nothing, by a hook the
## backend does not register, and by one it does
proc k_dc_entry {extra} {
  return [dict create dc [dict create label dc registered 1 emitorder 10 \
    fields [list [concat {name swkind kind sweepkind values {temp variable component}} $extra] \
                 {name source kind source required 1}] \
    emit {{role analysis tmpl {dc @source}}} results {viewer {kind sweep}} \
    plots {{select {DC transfer characteristic} role sweep results viewer label dc}}]]
}
proc k_types_none {} { return [k_dc_entry {}] }
proc k_types_bad {} { return [k_dc_entry {spentby nosuchhook}] }
proc k_types_good {} { return [k_dc_entry {spentby dcvar_plan}] }
group K {
  check {K1 a row that says what it sweeps is read as it says, in any case and spacing} \
    [list [ase::dc_sweep_kind {type dc swkind variable source NSEG}] \
          [ase::dc_sweep_kind {type dc swkind { Variable } source iload}] \
          [ase::dc_sweep_kind {type dc swkind temp source temp}] \
          [ase::dc_sweep_kind {type dc swkind component source ILOAD}]] \
    {variable variable temp component}
  ## A ROW WITHOUT THE KEY MEANS WHAT ngspice's OWN `.dc NAME` MEANS, which is
  ## every row written before the key existed; any other value states nothing
  check {K2 a row without swkind is the temperature for temp in any case and a component for any other name, device or not; an unknown swkind states nothing; a non-dc row has no kind} \
    [list [ase::dc_sweep_kind {type dc source temp}] [ase::dc_sweep_kind {type dc source TEMP}] \
          [ase::dc_sweep_kind {type dc source { Temp }}] [ase::dc_sweep_kind {type dc source ILOAD}] \
          [ase::dc_sweep_kind {type dc source V1}] [ase::dc_sweep_kind {type dc source NSEG}] \
          [ase::dc_sweep_kind {type dc}] [ase::dc_sweep_kind {type dc swkind bogus source temp}] \
          [ase::dc_sweep_kind {type ac points 10 start 1 stop 1k}]] \
    {temp temp temp component component component component temp {}}
  ## THE DEFECT THIS BAND EXISTS FOR: real benches name a source after the
  ## variable that sets it, so a name matching a variable must NOT be a
  ## variable sweep. Distinctness: the same bench's swkind row IS one.
  set kst [dict replace $S0 variables {{name iload value 0} {name NSEG value 16} {name MMSW value 1}}]
  check {K3 a name matching one of the bench's design variables, in any case, is not a variable sweep -- no plan, so no loop -- while the same bench's swkind variable row is one} \
    [list [ase::dc_sweep_kind {type dc enabled 1 source ILOAD start 1m stop 0 step -1u}] \
          [${NS}::dcvar_plan $kst {type dc enabled 1 source ILOAD start 1m stop 0 step -1u} 1] \
          [${NS}::dcvar_plan $kst {type dc enabled 1 source NSEG start 0 stop 31 step 1} 1] \
          [dg [${NS}::dcvar_plan $kst $DCV 1] name]] {component {} {} NSEG}
  check {K4 the adapter classifies a name by itself again, and the core asks it what a name means} \
    [list [${NS}::dc_swkind NSEG] [${NS}::dc_swkind temp] [${NS}::dc_swkind ILOAD] \
          [${NS}::dc_swkind R7] [ase::dc_name_kind TEMP ngspice] \
          [ase::dc_name_kind ILOAD ngspice] [ase::dc_name_kind {} ngspice]] \
    {source temp isource resistor temp component component}
  check {K5 the signatures, read with info args and info default: the classifier lost its variables, the picker gained the kind} \
    [list [info args ase::dc_sweep_kind] [info default ase::dc_sweep_kind sim d1] $d1 \
          [info args ${NS}::dc_swkind] \
          [info args ${NS}::dc_sweep_candidates] \
          [info default ${NS}::dc_sweep_candidates facts d2] $d2 \
          [info args ${NS}::dcvar_plan] [info default ${NS}::dcvar_plan ai d3] $d3 \
          [info args ase::dc_sweep_vals] [info default ase::dc_sweep_vals state d4] $d4] \
    {{row sim} 1 {} name {state kind facts} 1 {} {state row ai} 1 {} {sim type vals state} 1 {}}
  check {K5b the three hooks are registered for ngspice} \
    [list [expr {[ase::backend_hook ngspice dcvar_plan] ne {}}] \
          [expr {[ase::backend_hook ngspice dcvar_output_refusals] ne {}}] \
          [expr {[ase::backend_hook ngspice dc_sweep_candidates] ne {}}]] {1 1 1}
  set kfd [ase::field_descriptor ngspice dc swkind]
  check {K6 dc declares the sweep kind first: radio words with their labels, relabelling the name, spent by dcvar_plan, no default; the name's caption follows the kind, a row with no key taking its name's kind} \
    [list [lindex [ase::analysis_field_names ngspice dc] 0] [dg $kfd kind] [dg $kfd values] \
          [lrange [dg $kfd valuelabels] 0 end] [dg $kfd label] [dg $kfd relabels] [dg $kfd spentby] \
          [dict exists $kfd default] \
          [ase::field_caption_for_row ngspice dc {type dc} source] \
          [ase::field_caption_for_row ngspice dc {type dc swkind variable} source] \
          [ase::field_caption_for_row ngspice dc {type dc swkind component} source]] \
    {swkind sweepkind {temp variable component} {temp Temperature variable {Design variable} component Component} {Sweep variable} source dcvar_plan 0 {Component name} {Variable name} {Component name}}
  ## NON-VACUITY: the same field spent by nothing, or by a hook the backend
  ## lacks, IS a registry error; spent by a registered one it is not
  ase::register_backend kzero [dict merge [k_five] {analysis_types k_types_none}]
  ase::register_backend kbad  [dict merge [k_five] {analysis_types k_types_bad}]
  ase::register_backend kgood [dict merge [k_five] \
    [list analysis_types k_types_good dcvar_plan [ase::backend_hook ngspice dcvar_plan]]]
  check {K7 a field no template spends is consumed only through a spentby hook that resolves: the shipped registry is clean, nothing spends it, an unregistered hook is named} \
    [list [ase::analysis_schema_errors ngspice] [ase::analysis_schema_errors kzero] \
          [lsort [ase::analysis_schema_errors kbad]] [ase::analysis_schema_errors kgood]] \
    {{} {{dc fieldunused swkind}} {{dc badspentby nosuchhook} {dc fieldunused swkind}} {}}
  ## THE CORPUS, as a row so it cannot rot: the only value ever written is
  ## `variable`, every row read as a variable sweep says so itself, and the
  ## rows that name one of their own variables WITHOUT saying so (the IHP
  ## benches sweep `temp` and carry a variable called temp) are read by their
  ## name. Non-vacuous on the named count. ⚠ No committed state writes `swkind`
  ## yet, so the written legs only say that whatever is written is `variable`
  ## and is the only thing read as a variable sweep; they cannot go vacuous
  ## silently because they assert no count.
  set kc [test_corpus_files $::repo *.state]
  test_corpus_note $kc "the committed .state corpus"
  set kwrit {} ; set kvar 0 ; set kinfer {} ; set knamed {}
  foreach kf [dict get $kc files] {
    if {[catch {open $kf r} kh]} { continue }
    set kt [read $kh] ; close $kh
    set kv {} ; set ka {}
    foreach kl [split $kt \n] {
      if {[string first {variables } $kl] == 0} { catch {set kv [lindex $kl 1]} }
      if {[string first {analyses } $kl] == 0} { catch {set ka [lindex $kl 1]} }
    }
    set kn {}
    foreach v $kv { catch {lappend kn [string tolower [dict get $v name]]} }
    foreach a $ka {
      if {[catch {dict get $a type} ty] || $ty ne {dc}} { continue }
      if {[dict exists $a swkind]} { lappend kwrit [dict get $a swkind] }
      set k [ase::dc_sweep_kind $a ngspice]
      if {$k eq {variable}} {
        incr kvar
        if {[dg $a swkind] ne {variable}} { lappend kinfer $kf }
      }
      if {![dict exists $a swkind] && [dict exists $a source]
          && [string tolower [string trim [dict get $a source]]] in $kn} {
        lappend knamed $k
      }
    }
  }
  check "K8 the committed corpus: any swkind written is variable ([llength $kwrit] rows), every row read as a variable sweep says so itself, and the [llength $knamed] rows naming one of their own variables without it are read by the name" \
    [list [lsearch -all -inline -not -exact $kwrit variable] \
          [expr {$kvar == [llength $kwrit]}] $kinfer [expr {[llength $knamed] > 0}] \
          [expr {{variable} ni $knamed}]] \
    {{} 1 {} 1 1}
}

# ===========================================================================
# I -- THE ILOAD SHAPE: A SOURCE NAMED AFTER THE VARIABLE THAT SETS IT
# ===========================================================================
## The common bench shape, PDK-free: a source named after the variable that
## sets it -- current source ILOAD whose DC value and pulse both read a design
## variable iload -- a dc row `source ILOAD` and a dc measurement row. `.dc ILOAD` moves only the source's DC value; a sweep of
## the VARIABLE moves the pulse levels too -- which is why the row must say.
set NLI "** iload fixture\nVDD vdd 0 3.3\nRL vdd out 1k\nILOAD out 0 dc {iload} pulse({iload} {iload+500u} 1u 1n 1n 5u 10u)\n.end\n"
set DCI {type dc enabled 1 source ILOAD start 1.01m stop -70u step -10u}
set MI {{name o0 analysis dc kind find target v(out) at 0}}
proc mkist {cell rundir analyses args} {
  set s [ase::state_default]
  dict set s simulator ngspice
  dict set s design [dict create lib dcv cell $cell view schematic]
  dict set s rundir $rundir
  dict set s variables {{name vsup value 3.3} {name iload value 0}}
  dict set s analyses $analyses
  foreach {k v} $args { dict set s $k $v }
  return $s
}
set SI [mkist dci [file join $sd iload] [list {type op enabled 1} $DCI {type ac enabled 0} {type tran enabled 0}] \
          measurements $MI]
proc toks {offs} { return [lmap o $offs {lindex $o 0}] }
group I {
  set ineeds [ase::analysis_needs ngspice $DCI [ase::netlist_facts $NLI] {} $SI]
  check {I1 that shape is a component sweep: no plan, nothing refused by the reader or the gate, no sweep-target advice} \
    [list [ase::dc_sweep_kind $DCI ngspice] [${NS}::dcvar_plan $SI $DCI 1] \
          [ase::analysis_emit_check ngspice $DCI $SI 1] [pcall ase::preflight_gate $SI $NLI] \
          [lsearch -index 0 $ineeds sweep_target]] {component {} {} {} -1}
  set idk [pcall [ase::backend_hook ngspice render_deck] $SI $NLI]
  check_true {I2a the deck renders} [expr {![string match ERR:* $idk]}] $idk
  check {I2 its deck is ngspice's own dc of the source, with the measurement, and no loop} \
    [list [dlines $idk {^dc\s}] [llength [dlines $idk {^foreach asedvi }]] \
          [llength [dlines $idk {^alterparam }]] [llength [dlines $idk {^meas dc o0 }]]] \
    {{{dc ILOAD 1.01m -70u -10u}} 0 0 1}
  ## the same bench, saying it sweeps the VARIABLE (no measurement row: a
  ## simulator measurement on such a sweep is refused, which is I3b)
  set DCIV {type dc enabled 1 swkind variable source iload start 1.01m stop -70u step -10u}
  set SIV [dict replace $SI analyses [list {type op enabled 1} $DCIV {type ac enabled 0} {type tran enabled 0}] \
             measurements {}]
  set ivp [${NS}::dcvar_plan $SIV $DCIV 1]
  set ivd [pcall [ase::backend_hook ngspice render_deck] $SIV $NLI]
  check {I3 swkind variable naming iload is the loop: the plan is iload over 109 points from its value 0, the deck steps it and carries no dc line} \
    [list [dg $ivp name] [dg $ivp n] [dg $ivp value] [dg $ivp offences] \
          [llength [dlines $ivd {^foreach asedvi }]] [llength [dlines $ivd {^alterparam iload=}]] \
          [llength [dlines $ivd {^dc\s}]]] {iload 109 0 {} 1 2 0}
  check {I3b and with the bench's dc measurement row that sweep is refused} \
    [toks [ase::analysis_emit_check ngspice $DCIV [dict replace $SIV measurements $MI] 1]] dcvar_meas
  ## (a): the row says variable and the bench has no such variable
  set DCIN [dict replace $DCIV source inope]
  set SIN [dict replace $SIV analyses [list {type op enabled 1} $DCIN {type ac enabled 0} {type tran enabled 0}]]
  set ion [ase::analysis_emit_check ngspice $DCIN $SIN 1]
  set ing [pcall ase::preflight_gate $SIN $NLI]
  set inr [pcall [ase::backend_hook ngspice render_deck] $SIN $NLI]
  check {I4 a design-variable sweep naming a variable the bench lacks is refused by the reader, the gate and the render, in one clause} \
    [list $ion [lindex $ing 0] \
          [expr {[string first {which this bench does not have; add it under Design Variables or choose another} [lindex [lindex [lindex $ing 1] 0] 1]] >= 0}] \
          [string match ERR:* $inr] [expr {[string first {'inope', which this bench does not have} $inr] >= 0}]] \
    [list {{dcvar_novar source {sweeps the design variable 'inope', which this bench does not have; add it under Design Variables or choose another}}} \
          emit_incomplete 1 1 1]
  ## (c): a hand-written `source NSEG` row with no swkind is a component
  ## sweep; the advice says how to sweep the variable.
  ## Distinctness: a component name that is no variable gets no such clause.
  set DCL {type dc enabled 1 source NSEG start 0 stop 31 step 1}
  set SL [dict replace $S0 analyses [list {type op enabled 0} $DCL]]
  set lnd [ase::analysis_needs ngspice $DCL [ase::netlist_facts $NL] {} $SL]
  set lnx [ase::analysis_needs ngspice [dict replace $DCL source Vnope] [ase::netlist_facts $NL] {} $SL]
  set ldk [pcall [ase::backend_hook ngspice render_deck] $SL $NL]
  check {I5 a legacy source NSEG row is a component sweep: no plan, deck dc NSEG, a caution only, whose fix says to choose Design variable; a name that is no variable gets no such fix} \
    [list [ase::dc_sweep_kind $DCL ngspice] [${NS}::dcvar_plan $SL $DCL 1] \
          [dlines $ldk {^dc\s}] [llength [dlines $ldk {^foreach asedvi }]] \
          [lindex [lindex $lnd 0] 0] [lindex [lindex $lnd 0] 1] \
          [expr {[string first {this circuit has no 'NSEG' to sweep} [lindex [lindex $lnd 0] 2]] >= 0}] \
          [lindex [lindex $lnd 0] 3] [lindex [lindex $lnx 0] 3] [pcall ase::preflight_gate $SL $NL]] \
    [list component {} {{dc NSEG 0 31 1}} 0 sweep_target caution 1 \
          {name a voltage source, a current source or a resistor, or choose Temperature; to sweep the design variable, choose Design variable in the DC form} \
          {name a voltage source, a current source or a resistor, or choose Temperature} {}]
  ## a kind its own name contradicts would run something other than what the
  ## row says: the deck is `dc <name>` either way
  set ic1 [ase::analysis_emit_check ngspice {type dc enabled 1 swkind component source temp start 0 stop 1 step 1}]
  set ic2 [ase::analysis_emit_check ngspice {type dc enabled 1 swkind temp source ILOAD start 0 stop 1 step 1}]
  set igc [pcall ase::preflight_gate [dict replace $SI analyses [list {type op enabled 0} \
             {type dc enabled 1 swkind component source temp start 0 stop 100 step 10} \
             {type ac enabled 0} {type tran enabled 0}] measurements {}] $NLI]
  check {I6 a component named the temperature, or a temperature sweep naming a device, is refused, the gate too; agreeing pairs are not} \
    [list $ic1 $ic2 [lindex $igc 0] \
          [ase::analysis_emit_check ngspice {type dc enabled 1 swkind temp source TEMP start 0 stop 1 step 1}] \
          [ase::analysis_emit_check ngspice {type dc enabled 1 swkind component source ILOAD start 0 stop 1 step 1}]] \
    [list {{sweepcomp source {sweeps a component, but 'temp' names the temperature; choose Temperature}}} \
          {{sweeptemp source {sweeps the temperature but names 'ILOAD'; to sweep 'ILOAD', choose Component}}} \
          emit_incomplete {} {}]
  check {I7 a Temperature choice names the temperature for the commit door: the adapter's word, or the row's own when it already is one; nothing else moves} \
    [list [ase::dc_sweep_vals ngspice dc {swkind temp source ILOAD start 0}] \
          [ase::dc_sweep_vals ngspice dc {swkind temp source TEMP start 0}] \
          [ase::dc_sweep_vals ngspice dc {swkind temp start 0}] \
          [ase::dc_sweep_vals ngspice dc {swkind component source temp}] \
          [ase::dc_sweep_vals ngspice dc {swkind variable source iload}] \
          [ase::dc_sweep_vals ngspice ac {swkind temp source ILOAD}]] \
    {{swkind temp source temp start 0} {swkind temp source TEMP start 0} {swkind temp start 0 source temp} {swkind component source temp} {swkind variable source iload} {swkind temp source ILOAD}}
  set ifx [ase::netlist_facts $NLI]
  check {I8 the name picker lists one kind: the bench's variables, the netlist's top-level V I R devices, the temperature's own name; nothing for another word} \
    [list [${NS}::dc_sweep_candidates $SI variable $ifx] \
          [lsort [${NS}::dc_sweep_candidates $SI component $ifx]] \
          [${NS}::dc_sweep_candidates $SI component {}] \
          [${NS}::dc_sweep_candidates $SI temp $ifx] [${NS}::dc_sweep_candidates $SI bogus $ifx]] \
    {{vsup iload} {ILOAD RL VDD} {} temp {}}
}

# ===========================================================================
# P -- THE PLAN AND ITS REFUSALS
# ===========================================================================
proc tokens {plan} {
  set t {}
  foreach o [dg $plan offences] { lappend t [lindex $o 0] [lindex $o 1] }
  return $t
}
proc row1 {analyses} { return [list {type op enabled 0} $analyses] }
group P {
  set p [${NS}::dcvar_plan $S0 $DCV 1]
  check {P1 dc NSEG 0 31 1 is 32 points of NSEG from base 16, alone, with nothing to refuse} \
    [list [dg $p name] [dg $p n] [expr {[dg $p base] == 16}] [dg $p others] [dg $p offences]] \
    {NSEG 32 1 0 {}}
  check {P2 a source, a temperature and a non-dc row are not variable sweeps} \
    [list [${NS}::dcvar_plan $S0 {type dc enabled 1 source V1 start 0 stop 1 step 0.1} 1] \
          [${NS}::dcvar_plan $S0 {type dc enabled 1 source temp start 0 stop 1 step 1} 1] \
          [${NS}::dcvar_plan $S0 {type ac enabled 1 points 10 start 1 stop 1k} 1]] {{} {} {}}
  set r [dict replace $DCV source2 V1 start2 0 stop2 1 step2 0.5]
  check {P3 a second sweep with a variable sweep is refused, the field is source2} \
    [tokens [${NS}::dcvar_plan $S0 $r 1]] {dcvar_second source2}
  check {P4 a zero step and a step that never reaches stop are refused} \
    [list [tokens [${NS}::dcvar_plan $S0 [dict replace $DCV step 0] 1]] \
          [tokens [${NS}::dcvar_plan $S0 [dict replace $DCV step -1] 1]]] \
    {{dcvar_step step} {dcvar_empty step}}
  set cap [${NS}::dcvar_max_points]
  check {P5 the cap is 1024 points: 0..1023 by 1 passes, 0..1024 by 1 and 0..31 by 0.01 are refused} \
    [list $cap [tokens [${NS}::dcvar_plan $S0 [dict replace $DCV stop 1023] 1]] \
          [dg [${NS}::dcvar_plan $S0 [dict replace $DCV stop 1023] 1] n] \
          [tokens [${NS}::dcvar_plan $S0 [dict replace $DCV stop 1024] 1]] \
          [tokens [${NS}::dcvar_plan $S0 [dict replace $DCV step 0.01] 1]]] \
    {1024 {} 1024 {dcvar_cap step} {dcvar_cap step}}
  check {P5b a downward sweep counts by ngspice's rule too: 31 to 0 by -1 is 32 points} \
    [dg [${NS}::dcvar_plan $S0 [dict replace $DCV start 31 stop 0 step -1] 1] n] 32
  set sx [dict replace $S0 variables {{name NSEG value {MMSW*16}} {name MMSW value 1}}]
  set with_op [list {type op enabled 1} $DCV]
  check {P7 a value that is not a number is refused only when another analysis needs it put back} \
    [list [tokens [${NS}::dcvar_plan $sx $DCV 1]] \
          [tokens [${NS}::dcvar_plan [dict replace $sx analyses $with_op] $DCV 1]]] \
    {{} {dcvar_restore source}}
  set sm [dict replace $S0 measurements {{name vmax analysis dc kind max target v(vout)}}]
  check {P8 a simulator measurement bound to the sweep is refused, one on another row is not} \
    [list [tokens [${NS}::dcvar_plan $sm $DCV 1]] \
          [tokens [${NS}::dcvar_plan [dict replace $S0 measurements \
             {{name vmax analysis tran kind max target v(vout)}}] $DCV 1]]] \
    {{dcvar_meas source} {}}
  set pb [${NS}::dcvar_plan $S0 [dict replace $DCV start abc] 1]
  check {P9 a start that is not a number is left to the generic fill offence, never counted twice} \
    [list [dg $pb start] [dg $pb offences] \
          [lsearch -all -inline [lmap o [ase::analysis_emit_check ngspice [dict replace $DCV start abc] $S0 1] {lindex $o 0}] *]] \
    {{} {} fill}
}

# ===========================================================================
# E -- THE ONE READER: ase::analysis_emit_check, AND THE DOORS THAT ASK IT
# ===========================================================================
group E {
  set big [dict replace $DCV step 0.01]
  check {E1 without the bench the reader answers what it always did; with it the sweep's own offence} \
    [list [ase::analysis_emit_check ngspice $big] \
          [lmap o [ase::analysis_emit_check ngspice $big $S0 1] {lindex $o 0}]] {{} dcvar_cap}
  check {E2 the reader's signature, read with info args and info default} \
    [list [info args ase::analysis_emit_check] \
          [info default ase::analysis_emit_check state d1] $d1 \
          [info default ase::analysis_emit_check ai d2] $d2] {{sim row state ai} 1 {} 1 {}}
  set sg [dict replace $S0 analyses [row1 [dict replace $DCV source2 V1 start2 0 stop2 1 step2 0.5]]]
  set gr [pcall ase::preflight_gate $sg $::NL]
  check {E3 the gate refuses an enabled sweep the reader refuses, with the reader's clause} \
    [list [lindex $gr 0] [expr {[string first {second sweep} [lindex [lindex [lindex $gr 1] 0] 1]] >= 0}]] \
    {emit_incomplete 1}
  check {E4 the gate lets a renderable variable sweep through} \
    [pcall ase::preflight_gate $S0 $::NL] {}
  ## ⚠ A CALL-SITE TEXT SCAN, AND ITS LIMIT: it proves the commit door's call
  ## passes FOUR words, not that they are the bench and the index (band G does).
  set wt [slurp [file join $::repo src ase_window.tcl]]
  check {E5 the commit door asks the reader with the bench and the row index} \
    [regexp {set bad \[ase::analysis_emit_check \$sim \$probe \$_bst \\\s*\n\s*\[ase::ui::chana_row_idx \$key \$type\]\]} $wt] 1
}

# ===========================================================================
# D -- THE PLAIN DECK
# ===========================================================================
group D {
  set deck [pcall [ase::backend_hook ngspice render_deck] $S0 $NL]
  check_true {D0 the plain deck renders} [expr {![string match ERR:* $deck]}] $deck
  check {D1 no dc line reaches ngspice, the Analyses pane still reads dc NSEG 0 31 1} \
    [list [llength [dlines $deck {^dc\s}]] [ase::analysis_line ngspice $DCV] \
          [llength [dlines $deck {^\* ASE-L: dc NSEG 0 31 1 sweeps the design variable NSEG}]]] \
    {0 {dc NSEG 0 31 1} 1}
  set fe [dlines $deck {^foreach asedvi }]
  check {D2 one loop over the 32 point indices} \
    [list [llength $fe] [lrange [lindex $fe 0] 2 end] ] \
    [list 1 [lmap i [lsearch -all [lrepeat 32 x] x] {set i}]]
  set dl [lmap l [split $deck \n] {string trim $l}]
  set i0 [lsearch -exact $dl [lindex $fe 0]]
  check {D3 each point sets NSEG, re-seeds from the start-up seed, reloads, solves and guards} \
    [lrange $dl [expr {$i0 + 1}] [expr {$i0 + 12}]] \
    [list {alterparam NSEG=0+1*$asedvi} setseed reset op \
          {if $?sim_status = 0} {echo NO-SIM-STATUS} end \
          {if $sim_status ne 0} {echo RUN-FAILED} {quit 1} end \
          {let const.asedv1_x[$asedvi] = 0+1*$asedvi}]
  check {D4 the copies are the top-level nets and the source branch, then destroy all} \
    [dlines $deck {^let const\.asedv1_[0-9]+\[\$asedvi\] = |^destroy all$}] \
    {{let const.asedv1_0[$asedvi] = v(vdd)} {let const.asedv1_1[$asedvi] = v(vout)} {let const.asedv1_2[$asedvi] = i(V1)} {destroy all}}
  check {D5 one plot is built after the loop, scale NSEG, named as a dc sweep} \
    [dlines $deck {^setplot new$|^let (NSEG|vdd|vout|V1#branch) = |^setscale |^setcs curplotname}] \
    [list {setplot new} {let NSEG = const.asedv1_x} {let vdd = const.asedv1_0} \
          {let vout = const.asedv1_1} {let V1#branch = const.asedv1_2} {setscale NSEG} \
          {setcs curplotname = "DC transfer characteristic"}]
  ## the plot map record and the write, by POSITION after the name: a path
  ## that needs ngspice's escape brings its own setcs line, so not by text
  set is [lsearch -exact $dl {setcs curplotname = "DC transfer characteristic"}]
  set ie [lsearch -start $is -regexp $dl {^echo "PLOT dc 1 \|\$curplotname\|" >> }]
  set iw [lsearch -start $is -regexp $dl {^write }]
  check {D5b then remzerovec, the plot map record and the one write, last in the block} \
    [list [lindex $dl [expr {$is + 1}]] [expr {$ie > $is}] [expr {$iw > $ie}] \
          [llength [lsearch -all -regexp $dl {^write }]] [lindex $dl [expr {$iw + 1}]]] \
    {remzerovec 1 1 1 .endc}
  check {D6 alone, nothing is put back and the only reset is the loop's own} \
    [llength [dlines $deck {^alterparam NSEG=16$|^reset$}]] 1
  ## with an op (rank 0, before) and a tran (rank 30, after): the value is put
  ## back AND the circuit re-loaded on it, with the run's own seed
  set s2 [dict replace $S0 analyses [list {type op enabled 1} $DCV {type ac enabled 0} \
                                           {type tran enabled 1 step 1u stop 10u}]]
  set d2 [pcall [ase::backend_hook ngspice render_deck] $s2 $NL]
  set l2 [lmap l [split $d2 \n] {string trim $l}]
  set aw [lsearch -all -exact $l2 {alterparam NSEG=16}]
  set i2 [lsearch -exact $l2 {setcs curplotname = "DC transfer characteristic"}]
  set w2 [lsearch -start $i2 -regexp $l2 {^write }]
  check {D7 with other analyses the value is put back after the loop, and a following tran re-loads first} \
    [list [llength $aw] [expr {[lindex $aw 0] < [lsearch -exact $l2 {setplot new}]}] \
          [lrange $l2 [expr {$w2 + 1}] [expr {$w2 + 3}]]] \
    [list 1 1 {setseed reset {tran 1u 10u}}]
  ## the replay and the verbatim hatch, driven through dcvar_body itself
  set a3 [dict replace $DCV x {{alter v1 dc=1.1}}]
  set s3 [dict replace $S0 analyses [row1 $a3]]
  set b3 [pcall ${NS}::dcvar_body $s3 $a3 1 [${NS}::dcvar_plan $s3 $a3 1] [dict create] quit \
            [dict create seen [split $NL \n] replay {{optran 1 0 0 100 10n 0} {alter r9 1}}]]
  set b3t [lmap l $b3 {string trim $l}]
  set ir [lsearch -exact $b3t reset]
  check {D8 after each reset the caller's replay lines, then the row's own verbatim line, then op} \
    [lrange $b3t $ir [expr {$ir + 4}]] {reset {optran 1 0 0 100 10n 0} {alter r9 1} {alter v1 dc=1.1} op}
  set bad [pcall [ase::backend_hook ngspice render_deck] [dict replace $S0 analyses [row1 [dict replace $DCV step 0.01]]] $NL]
  check {D9 render_deck refuses a hand-edited row the reader refuses, in the reader's words} \
    [list [string match ERR:* $bad] [expr {[string first {more than 1024 points} $bad] >= 0}]] {1 1}
  set sc [dict replace $S0 variables {{name c value 1} {name NSEG value 16} {name MMSW value 1}}]
  set dc [pcall [ase::backend_hook ngspice render_deck] [dict replace $sc analyses [row1 [dict replace $DCV source c]]] $NL]
  set sv [dict replace $S0 variables {{name vout value 1} {name NSEG value 16} {name MMSW value 1}}]
  set dv [pcall [ase::backend_hook ngspice render_deck] [dict replace $sv analyses [row1 [dict replace $DCV source vout]]] $NL]
  check {D10 a scale that a const name or a collected net already holds is spelled name-sweep} \
    [list [dlines $dc {^setscale }] [dlines $dv {^setscale }]] {{{setscale c-sweep}} {{setscale vout-sweep}}}
}

# ===========================================================================
# C -- THE COLLECTED VECTORS
# ===========================================================================
group C {
  set cl [${NS}::dcvar_collect [split $NL \n]]
  check {C1 the fixture: two top-level nets and the source branch, never the master seg} \
    $cl {{vdd v(vdd) voltage} {vout v(vout) voltage} {V1#branch i(V1) current}}
  set n2 "* c2\nV1 VDD GND 'VDD' pwl 0us 0 5us 'VDD'\nXQ2 GND GND Veb sky130_fd_pr__pnp_05v5_W3p40L3p40 m=1 mult=1\nM1 d g s b nch W=1 L=1\nE1 out 0 d 0 2\nL1 d s 1u\nR9 x.y c 1k\nXn net<3> e pi foo\n.global VG\n.control\nlet notanode = 1\n.endc\n"
  check {C2 the device grammar: V and L two nodes, M and E four, X all but its master; no value, model or ground} \
    [lmap c [${NS}::dcvar_collect [split $n2 \n]] {lindex $c 0}] \
    {VDD Veb d g s b out VG V1#branch E1#branch L1#branch}
  check {C3 a narrowed deck carries only what it saves} \
    [${NS}::dcvar_collect [concat [split $NL \n] {{.save v(vout) i(v1)}}]] \
    {{vout v(vout) voltage} {V1#branch i(V1) current}}
  check {C4 an event node is not copied} \
    [lmap c [${NS}::dcvar_collect [split $NL \n] {vout}] {lindex $c 0}] {vdd V1#branch}
}

# ===========================================================================
# O -- AN OUTPUT THE SWEEP CANNOT CARRY
# ===========================================================================
set SO [dict replace $S0 outputs {{name v16 expr {value(vs(vout),16)} save 0 plot 0}
                                  {name inner expr {vs(x1.a)} save 0 plot 0}
                                  {name par expr {@r.x1.r1[resistance]} save 0 plot 0}
                                  {name ir expr {is(r9)} save 0 plot 0}
                                  {name iv expr {is(V1)} save 0 plot 0}}]
group O {
  set orf [${NS}::dcvar_output_refusals $SO $DCV]
  check {O1 a subcircuit net, a device parameter and a non-source current are named; a top-level net and a source current are not} \
    [lmap r $orf {lindex $r 0}] {vs(x1.a) {@r.x1.r1[resistance]} is(r9)}
  check {O2 the sentence says which output, which signal and why} \
    [lindex [lindex $orf 0] 1] \
    {output 'inner' reads 'v(x1.a)', a node inside a subcircuit, and a sweep of a design variable carries only top-level nets and source currents, so that output has no value}
  set pc [ase::analysis_precheck ngspice $SO [ase::netlist_facts $NL]]
  check {O3 before the run it is advice on the dc analysis, never a refusal} \
    [list [lindex [lindex [dg $pc dc] 0] 0] [lindex [lindex [dg $pc dc] 0] 1] \
          [expr {[string first {(and 2 more outputs like it)} [lindex [lindex [dg $pc dc] 0] 2]] >= 0}] \
          [pcall ase::preflight_gate $SO $NL]] {sweep_target caution 1 {}}
}

# ===========================================================================
# THE ngspice BAND X RUNS: ASE_DCVAR_NGSPICE, else the fork build under the
# real HOME. Any ngspice that runs a plain `op` will do; nothing here needs a
# fork-only command. ⚠ ONE ROW NEEDS A BEHAVIOUR, NOT A COMMAND: X4 says the
# sweep is the very silicon of the unswept op, which holds only where a bare
# `setseed` + `reset` reproduces the START-UP draws. MEASURED: build-ver_51
# does; apt ngspice-45.2 gives every reseeded point the same draws but not the
# start-up ones. So the probe measures that too, and X4 prints `skip:` where
# it does not hold rather than failing a correct sweep.
# ===========================================================================
set NG {}
if {[info exists env(ASE_DCVAR_NGSPICE)] && $env(ASE_DCVAR_NGSPICE) ne {}} { set NG $env(ASE_DCVAR_NGSPICE) }
if {$NG eq {}} { set NG [file join [test_real_home] dev ngspice build-ver_51 src ngspice] }
set HAVE 0 ; set REPRO 0
if {[file executable $NG]} {
  set pd [file join $sd probe]
  spit [file join $pd p.cir] "* p\n.param dr=agauss(0,0.05,1)\nR1 a 0 r='1k*(1+dr)'\nR2 b 0 1k\nV1 a 0 1\nV2 b 0 1\n.control\nop\nprint i(v2)\nprint i(v1)\nsetseed\nreset\nop\nprint i(v1)\nquit\n.endc\n.end\n"
  spit [file join $pd .spiceinit] {}
  set back [pwd] ; cd $pd
  set prc [catch {exec env -u DISPLAY timeout 60 $NG -b -o p.log p.cir < /dev/null}]
  cd $back
  set plog [slurp [file join $pd p.log]]
  set HAVE [expr {!$prc && [regexp {i\(v2\)\s*=\s*-1\.0+e-0?3} $plog]}]
  set pv [regexp -all -inline {i\(v1\)\s*=\s*\S+} $plog]
  set REPRO [expr {$HAVE && [llength $pv] == 2 && [lindex $pv 0] eq [lindex $pv 1]}]
}
proc ngrun {dir deck} {
  spit [file join $dir deck.cir] $deck
  spit [file join $dir .spiceinit] {}
  set back [pwd] ; cd $dir
  set rc [catch {exec env -u DISPLAY timeout 120 $::NG -b -o run.log deck.cir < /dev/null} m]
  set code 0
  if {$rc} { set code [lindex $::errorCode 2] ; if {$code eq {}} { set code 1 } }
  cd $back
  return $code
}
# ===========================================================================
# X -- REAL ngspice, A PLAIN RUN
# ===========================================================================
if {!$HAVE} {
  foreach r {X1 X2 X3 X4 X5 X6 X7} { skiprow "$r real ngspice run" "no runnable ngspice at $NG" }
} else {
  group X {
    set sx [mkst dcv [file join $sd x1] [list {type op enabled 1} $DCV] \
              outputs [dg $SO outputs]]
    set dk [${NS}::render_deck $sx $NL]
    file mkdir [file join $sd x1]
    set rc [ngrun [file join $sd x1] $dk]
    set raw [${NS}::raw_file $sx]
    check {X1 the run exits 0 and its results read back as an operating point and a dc sweep} \
      [list $rc [calc::raw_analyses $raw]] {0 {op dc}}
    set rr [xschem raw read $raw dc]
    set first [lindex [split [xschem raw list] \n] 0]
    set np [xschem raw points]
    xschem raw clear
    check {X2 the dc plot has 32 points and its X is the variable, named as the variable} \
      [list $rr $np [string tolower $first]] {1 32 nseg}
    set w [calc::eval_text {vs(vout)} $raw dc]
    set v16 [calc::eval_text {value(vs(vout),16)} $raw dc]
    set op16 [calc::eval_text {vdc(vout)} $raw op]
    check {X3 vs() is the 32-point curve and value() reads it at the variable} \
      [list [dg $w ok] [dg $w kind] [dg $w points] [dg $v16 ok] [dg $v16 kind]] {1 wave 32 1 scalar}
    ## the operating point ran on the start-up draws at the bench's own NSEG 16;
    ## the sweep re-seeds from the start-up seed at every point
    if {$REPRO} {
      check {X4 the sweep at NSEG 16 is the very silicon of the unswept operating point} \
        [expr {abs([dg $v16 value] - [dg $op16 value]) <= 1e-12 * abs([dg $op16 value])}] 1
    } else {
      skiprow {X4 the sweep at NSEG 16 is the very silicon of the unswept operating point} \
        "$NG: a bare setseed + reset does not reproduce the start-up draws"
    }
    set ans [${NS}::result_answers $sx fold]
    set by [dict create]
    foreach a $ans { dict set by [dg $a key] [list [dg $a status] [dg $a msg]] }
    check {X5 after the run the refused outputs carry the reason and the others their values} \
      [list [lindex [dg $by inner] 0] [expr {[string first {a node inside a subcircuit} [lindex [dg $by inner] 1]] >= 0}] \
            [lindex [dg $by ir] 0] [lindex [dg $by v16] 0] [lindex [dg $by iv] 0]] \
      {refused 1 refused number wave}
    set sf [mkst dcvf [file join $sd x2] $ALONE]
    set rcf [ngrun [file join $sd x2] [${NS}::render_deck $sf $NLF]]
    check {X6 a point that cannot be solved stops the run, as ngspice's own dc does, and nothing is written} \
      [list $rcf [regexp {RUN-FAILED} [slurp [file join $sd x2 run.log]]] [file exists [${NS}::raw_file $sf]]] \
      {1 1 0}
    ## THE ILOAD SHAPE, RUN: ngspice's own `dc ILOAD`, and the dc
    ## measurement row reads it back. v(out) = 3.3 V - 1k * ILOAD, so the
    ## find at ILOAD = 0 is 3.3 V; at the sweep's ends it is 2.29 V and 3.37 V,
    ## which a measurement read at the wrong point would answer instead.
    ## ⚠ THE RENDER GOES THROUGH pcall: a refused render (the name-match defect
    ## would be one) is this row's FAIL, not an abort that takes band X with it.
    set sxi [mkist dcxi [file join $sd xi] [list {type op enabled 1} $DCI {type ac enabled 0} \
                                                 {type tran enabled 0}] measurements $MI]
    file mkdir [file join $sd xi]
    set dki [pcall ${NS}::render_deck $sxi $NLI]
    set rci $dki
    if {![string match ERR:* $dki]} { set rci [ngrun [file join $sd xi] $dki] }
    set o0 [ase::meas_result ngspice $sxi o0]
    check {X7 the ILOAD shape runs as ngspice's own dc sweep of the source, and its dc measurement reads 3.3 V at ILOAD = 0} \
      [list $rci [pcall calc::raw_analyses [${NS}::raw_file $sxi]] \
            [expr {[string is double -strict $o0] && abs($o0 - 3.3) < 1e-6}]] {0 {op dc} 1}
  }
}

# ===========================================================================
# G -- THE DC FORM (display arm only)
# ===========================================================================
set GROWS {G1 G2 G3 G4 G5 G13 G14 G6 G7 G8 G9 G10 G11 G12}
if {[info commands winfo] eq {} || ![info exists ::has_x]} {
  skiprow "G the dc form ($GROWS)" "no display (--nogui)"
} else {
  ## THE FACTS THE NAME PICKER READS. The dialog only PEEKS (it never
  ## netlists), so the peek is stubbed with each bench's own fixture facts and
  ## put back after the band, whatever the band did.
  rename ::ase::netlist_facts_cached ::g_facts_real
  proc ::ase::netlist_facts_cached {state} { return $::GFACTS }
  ## the form's widgets, read back
  proc gw {top} { return $top.chana.form }
  proc gradios {top} {
    set out {}
    foreach b [winfo children [gw $top].swkind] {
      lappend out [list [winfo class $b] [$b cget -value] [$b cget -text]]
    }
    return $out
  }
  proc gkind {key} { return [ase::ui::form_get $key swkind] }
  proc gopen {key} { ase::ui::choose_analyses $key dc ; update }
  proc gok {top} { $top.chana.btns.proceed invoke ; update }
  proc gdc {key} { return [lindex [ase::state_get [ase::session_state $key] analyses] 1] }
  proc gser {key} { return [ase::state_serialize [ase::session_state $key]] }
  group G {
    ## --- bench 1: the NSEG fixture, its dc row a design-variable sweep -----
    set ::GFACTS [ase::netlist_facts $::NL]
    set gdir [file join $sd gui]
    file mkdir $gdir
    set gst [mkst dcvg $gdir $ALONE]
    set gpath [file join $gdir dcvg.state]
    ase::state_save $gpath $gst
    set key dcv/dcvg/gui_state
    ase::session_open $key $gpath
    ase::ui::open $key dcv dcvg gui_state
    update
    set top [ase::ui::window_for $key]
    gopen $key
    set f [gw $top]
    check {G1 the first row is Sweep variable with three radio buttons, worded in sentence case, the row's own kind selected} \
      [list [$f.lswkind cget -text] [winfo class $f.swkind] [gradios $top] [gkind $key]] \
      [list {Sweep variable:} Frame \
            {{Radiobutton temp Temperature} {Radiobutton variable {Design variable}} {Radiobutton component Component}} \
            variable]
    check {G2 for a design variable the name is captioned Variable name and its editable picker lists the bench's variables} \
      [list [$f.lsource cget -text] [winfo class $f.source] [$f.source cget -state] \
            [$f.source cget -values] [$f.source get]] \
      {{Variable name:} TCombobox normal {NSEG MMSW} NSEG}
    $f.swkind.component invoke
    update
    check {G3 choosing Component relabels the name Component name and lists the netlist's top-level V and I sources and resistors} \
      [list [gkind $key] [$f.lsource cget -text] [$f.source cget -values] [$f.source get]] \
      {component {Component name:} V1 NSEG}
    set gri [list [grid info $f.lsource] [grid info $f.source]]
    $f.swkind.temp invoke
    update
    check {G4 choosing Temperature hides the name row, label and picker, and keeps what was typed there} \
      [list [gkind $key] [grid info $f.lsource] [grid info $f.source] \
            [winfo ismapped $f.source] [winfo exists $f.source] [$f.source get]] \
      {temp {} {} 0 1 NSEG}
    $f.swkind.variable invoke
    update
    check {G5 choosing Design variable again restores the name row where it was, relabelled and re-listed} \
      [list [list [grid info $f.lsource] [grid info $f.source]] [winfo ismapped $f.source] \
            [$f.lsource cget -text] [$f.source cget -values]] \
      [list $gri 1 {Variable name:} {NSEG MMSW}]
    ## G13 -- NO INPUT MOVES WHEN THE KIND DOES. The label column was as wide as
    ## its widest label, and "Variable name:" / "Component name:" differ, so
    ## every input jumped about 20 px on a pick (and again for Temperature,
    ## whose widest label is "Sweep variable:"). Positions come from the live
    ## widgets after each pick. DISTINCTNESS: the name label really is a
    ## different width in the two kinds, measured on the same picks.
    set gxs {} ; set grx {} ; set gsx {} ; set glw {}
    foreach k {variable component temp variable component} {
      $f.swkind.$k invoke
      update idletasks
      lappend gxs [winfo x $f.start]
      lappend grx [winfo rootx $f.start]
      if {$k ne {temp}} {
        lappend gsx [winfo x $f.source]
        lappend glw [winfo reqwidth $f.lsource]
      }
    }
    $f.swkind.variable invoke
    update idletasks
    check_true {G13 the Start field and the name field keep their x through Design variable, Component and Temperature, while the name label's own width differs between the two names} \
      [expr {[llength [lsort -unique $gxs]] == 1 && [llength [lsort -unique $grx]] == 1
             && [llength [lsort -unique $gsx]] == 1 && [lindex $gsx 0] == [lindex $gxs 0]
             && [lindex $glw 0] != [lindex $glw 1]}] \
      "start x=$gxs rootx=$grx name x=$gsx name label widths=$glw"
    ## G14 -- AND NO OTHER FORM MOVES. The minsize is the widest caption a
    ## RELABELLED label can wear; on every other form that is no wider than
    ## the column already is (ac's `Points per ...` sit beside `Start
    ## frequency (Hz)`), and a form with no relabelling field gets none. The
    ## column's natural width is the widest gridded label plus its padx, read
    ## from the live widgets. NON-VACUITY: some other form does carry a
    ## minsize, and on dc in Temperature it is what holds the column open.
    proc gcolnat {f} {
      set nat 0
      foreach s [grid slaves $f -column 0] {
        set gi [grid info $s]
        if {[dict get $gi -columnspan] != 1} { continue }
        set px [dict get $gi -padx]
        if {[llength $px] == 1} { set pad [expr {2 * $px}] } \
        else { set pad [expr {[lindex $px 0] + [lindex $px 1]}] }
        if {[winfo reqwidth $s] + $pad > $nat} { set nat [expr {[winfo reqwidth $s] + $pad}] }
      }
      return $nat
    }
    set gwide {} ; set gzero {} ; set gnonzero 0
    foreach gt [lsort [winfo children $top.chana.types]] {
      set gty [winfo name $gt]
      if {$gty eq {dc}} { continue }
      $gt invoke
      update idletasks
      set gf [gw $top]
      if {![winfo exists $gf]} { continue }
      set gmin [grid columnconfigure $gf 0 -minsize]
      set grel 0
      foreach gfn [ase::ui::chana_fields $gty ngspice] {
        if {[dict exists [ase::field_descriptor ngspice $gty $gfn] relabels]} { set grel 1 }
      }
      if {$gmin > [gcolnat $gf]} { lappend gwide "$gty:$gmin>[gcolnat $gf]" }
      if {!$grel && $gmin != 0} { lappend gzero "$gty:$gmin" }
      if {$gmin > 0} { incr gnonzero }
    }
    $top.chana.types.dc invoke
    update
    set f [gw $top]
    $f.swkind.temp invoke
    update idletasks
    set gdct [list [grid columnconfigure $f 0 -minsize] [gcolnat $f]]
    $f.swkind.variable invoke
    update idletasks
    check {G14 no other form's label column is widened by it and a form with no relabelling field has no minsize at all, while some other form does carry one and dc's holds its column open in Temperature} \
      [list $gwide $gzero [expr {$gnonzero > 0}] [expr {[lindex $gdct 0] > [lindex $gdct 1]}]] \
      {{} {} 1 1}
    set ::ase::ui::dlg($key,anen) 1
    $f.step delete 0 end
    $f.step insert 0 0.01
    set before [ase::state_get [ase::session_state $key] analyses]
    gok $top
    check {G6 OK refuses a design-variable sweep over the cap with the clause in the dialog, the bench untouched} \
      [list [winfo exists $top.chana] \
            [expr {[string first {more than 1024 points} [$top.chana.status cget -text]] >= 0}] \
            [expr {[ase::state_get [ase::session_state $key] analyses] eq $before}]] {1 1 1}
    catch {$top.chana.btns.cancel invoke}
    catch {ase::ui::close $key}
    update
    ## --- bench 2: the ILOAD shape, a legacy `source ILOAD` row -------------
    set ::GFACTS [ase::netlist_facts $::NLI]
    set gdir2 [file join $sd gui2]
    file mkdir $gdir2
    set gst2 [mkist dcig $gdir2 [list {type op enabled 0} $DCI {type ac enabled 0} {type tran enabled 0}]]
    set gpath2 [file join $gdir2 dcig.state]
    ase::state_save $gpath2 $gst2
    set key dcv/dcig/gui_state
    ase::session_open $key $gpath2
    ase::ui::open $key dcv dcig gui_state
    update
    set top [ase::ui::window_for $key]
    gopen $key
    set f [gw $top]
    check {G7 a legacy row naming a source after its variable opens on Component: Component name, the netlist's devices, the name as stored} \
      [list [gkind $key] [$f.lsource cget -text] [lsort [$f.source cget -values]] [$f.source get]] \
      {component {Component name:} {ILOAD RL VDD} ILOAD}
    set g0 [gser $key]
    gok $top
    check {G8 OK on the untouched legacy row writes the bench byte-identically, and the row carries no swkind} \
      [list [winfo exists $top.chana] [expr {[gser $key] eq $g0}] [dict exists [gdc $key] swkind]] {0 1 0}
    gopen $key
    set f [gw $top]
    $f.swkind.variable invoke
    update
    set gvl [list [$f.lsource cget -text] [$f.source cget -values]]
    $f.source delete 0 end
    $f.source insert 0 iload
    gok $top
    set gr [gdc $key]
    check {G9 Design variable lists the bench's variables, and OK writes swkind variable with the name and nothing else changed -- a row the adapter plans as the loop} \
      [list $gvl [winfo exists $top.chana] [dg $gr swkind] [dg $gr source] \
            [expr {[dict remove $gr swkind source] eq [dict remove $DCI source]}] \
            [dg [${NS}::dcvar_plan [ase::session_state $key] $gr 1] name]] \
      [list {{Variable name:} {vsup iload}} 0 variable iload 1 iload]
    gopen $key
    set f [gw $top]
    set gk9 [list [gkind $key] [$f.lsource cget -text] [$f.source get]]
    $f.swkind.component invoke
    update
    $f.source delete 0 end
    $f.source insert 0 ILOAD
    gok $top
    check {G10 the variable row opens on Design variable; back to Component with the source name, OK writes the original row byte for byte, swkind gone} \
      [list $gk9 [winfo exists $top.chana] [expr {[gdc $key] eq $DCI}] [expr {[gser $key] eq $g0}]] \
      {{variable {Variable name:} iload} 0 1 1}
    gopen $key
    set f [gw $top]
    $f.swkind.temp invoke
    update
    gok $top
    set gt [gdc $key]
    gopen $key
    set f [gw $top]
    set gtopen [list [gkind $key] [grid info $f.source] [winfo ismapped $f.source]]
    ## Component with the temperature's name in it, enabled: refused at the door
    $f.swkind.component invoke
    update
    set gbefore [ase::state_get [ase::session_state $key] analyses]
    gok $top
    check {G11 Temperature writes source temp and no swkind; the row reopens on Temperature with its name row hidden; Component naming temp is refused in the dialog, the bench untouched} \
      [list [dg $gt source] [dict exists $gt swkind] \
            [expr {[dict remove $gt source] eq [dict remove $DCI source]}] $gtopen \
            [winfo exists $top.chana] [$top.chana.status cget -text] \
            [expr {[ase::state_get [ase::session_state $key] analyses] eq $gbefore}]] \
      [list temp 0 1 {temp {} 0} 1 \
            {This dc analysis sweeps a component, but 'temp' names the temperature; choose Temperature.} 1]
    catch {$top.chana.btns.cancel invoke}
    update
    ## a legacy uppercase TEMP row: Temperature, and OK keeps its own spelling
    set gs [ase::session_state $key]
    set gtr {type dc enabled 1 source TEMP start -40 stop 125 step 5}
    dict set gs analyses [list {type op enabled 0} $gtr {type ac enabled 0} {type tran enabled 0}]
    ase::session_update $key $gs
    gopen $key
    set gku [gkind $key]
    set gu0 [gser $key]
    gok $top
    gopen $key
    $top.chana.types.noise invoke
    update
    check {G12 a legacy TEMP row opens on Temperature and OK keeps it byte-identical; another analysis's source field keeps its entry} \
      [list $gku [expr {[gser $key] eq $gu0}] [gdc $key] [winfo class [gw $top].insrc]] \
      [list temp 1 $gtr Entry]
    catch {$top.chana.btns.cancel invoke}
    catch {ase::ui::close $key}
    update
  }
  rename ::ase::netlist_facts_cached {}
  rename ::g_facts_real ::ase::netlist_facts_cached
}

puts "TIMING: test_ase_dc_param_sweep wall=[expr {[clock milliseconds] - $t_start}]ms"
test_scratch_drop $sd
if {$fail == 0} { puts "OVERALL: ok ($npass checks)" } else { puts "OVERALL: notok" }
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks, $nskip skipped)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
