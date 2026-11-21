# tests/headless/test_ase_probe_deck_1724.tcl -- a terminal-current Outputs row
# (`i(<path>:<tname>)`) becomes a `.probe` card in the ASE-L deck, never a
# `.save` card, and what came of each card is said after the run (issue 1724).
#
# Code     src/ase.tcl ase::probe_split, ase::output_probes, ase::output_is_probe,
#          ase::output_saves_any, ase::saves_all_forced,
#          ase::output_card_sources, ase::saves_unresolved, ase::probe_card,
#          ase::probe_top_card, ase::probe_x_calls, ase::probe_x_ports,
#          ase::subckt_scan, ase::subckt_walk, ase::subckt_lib,
#          ase::subckt_model_cards, ase::meas_probes, ase::probe_asked,
#          ase::probe_plan, ase::probe_terms, ase::probe_netlist_terms,
#          ase::probe_terms_new, ase::probe_marker, ase::probe_mode,
#          ase::probe_refusals, ase::probe_nohdr_note, ase::probe_row_swept,
#          ase::probe_report, ase::probe_marker_answer, ase::probe_needs_hier,
#          ase::probe_plan_hier, ase::sim_run_name, ase::probe_cure,
#          ase::probe_cure_entries, ase::probe_start_report,
#          ase::backend::ngspice::capabilities (its `hier_probes` key),
#          ase::backend::ngspice::render_deck, ase::backend::ngspice::result_probe,
#          ase::backend::ngspice::missing_spoken,
#          ase::backend::ngspice::missing_row_note, ase::run_deck,
#          ase::run_done; and, in band PE only, the pick that writes such a
#          row: src/ase_window.tcl ase::ui::sod_click, ase::ui::sod_queue
# Fixture  hand-written netlists and states, written as text into the suite's
#          scratch; tests/headless/data/probe_1724_op.raw and
#          probe_1724_tran.raw (a real ver_53 run of probe_1724.cir) for the
#          Value rows; and, when a probe-capable ngspice answers, real runs of
#          decks the real `render_deck` hook wrote -- for band PE over the
#          netlist xschem itself makes of a small library of sheets and
#          symbols, also written as text into the scratch.
#
# Bands
#   PD0  fixture: the binary under test is the one the feature was built into,
#        and the key that PL28b, PN13 and PN13b take the other failure lines
#        of a run that did not converge from can be read out of
#        ase::probe_report
#   PS   the predicate, and the terminals a row reads (signals, not row text)
#   PX   no `.save` card, no forced leader and no pre-flight row for a terminal;
#        and no `.save` card for an expression's read of a name the simulator
#        cannot take on one
#   PU   ase::saves_unresolved does not count a terminal row; `disto` is not
#        refused for a terminal-only save list
#   PP   the probe plan: which terminals are asked (Saves rows by their ticks,
#        Measures rows and measurement rows always), each one's card term, and
#        the cards that are withheld (case mode, the E source, the K coupling)
#   PQ   a subcircuit port whose NAME IS A NUMBER: the card carries the port's
#        position, looked up in the `.subckt` header -- in the netlist text,
#        else in the model files the deck names -- and the header reader those
#        lookups go through
#   PR   the rendered deck: where the `.probe` cards and the capability echo go,
#        when a terminal row brings the save-everything leader, the typed rows
#        that are no terminal, the expression that reads a name no `.save`
#        card can carry, and the term a `.probe` card of the netlist's own
#        already asks for
#   PL   ase::probe_report on synthetic logs and results files: both refusal
#        shapes, the withheld card, the missing vector and the plots that can
#        say so, the run whose analyses keep no terminal current at all --
#        with and without a design-variable sweep beside them, and which rows
#        that sweep's own advice already speaks for -- the
#        vector made under another name, the numbered port whose header was
#        not found, the ONE record for the terminals a build without the probe
#        extension cannot save, the run that did not converge --
#        with the simulator's transient-op rung on and switched off
#   PW   the wiring: ase::run_deck carries the plan and ase::run_done reports
#        it, driven through a backend whose run command is a canned script
#   PH   a terminal below the top level (PH, PC, PH-run): which terminals
#        need a simulator that probes there; the capability key the probe's
#        own deck measures (stand-in simulators that answer the probe); the
#        cure -- which registered program can and where it is picked -- in
#        each of its outcomes, the click that starts nothing, the entries
#        the cure does not ask, the bound on what a run may spend asking, the menu
#        entry and the two buttons the cure names; how a sentence names the
#        program of a run;
#        the line before the run and the report after it, also through
#        ase::run_deck on a registered stand-in, where the run's record also
#        carries the session that asked for the run
#   PA   the other readers of an output row, for a terminal row: the Value
#        column, the note about rows with no value, the design-variable
#        sweep's advice, the optimizer export, the rows the viewer is asked to
#        draw
#   PN0  how a candidate simulator is copied (no simulator needed)
#   PN   REAL ngspice with the probe extension (a copy of the binary, taken at
#        suite start): every asked vector is in the results with a non-zero
#        length, the sign on a resistor, a terminal-only save list with and
#        without a `.save` in the netlist, `-i()`, `it()` and unticked `idc()`
#        rows, `disto`, the E guard both ways, `preserve`, numbered subcircuit
#        ports, a measurement over a terminal, a terminal asked under a name
#        the simulator does not give it, a noise-only run through the whole
#        road and the same run with a design-variable sweep beside the noise
#        (rows PA8g and PA8h, which belong to band PA's note and need the
#        simulator), a terminal the netlist already probes, a voltage
#        source's own current against its two terminals, an expression
#        that reads a name no `.save` card can carry, an operating point
#        that cannot be solved once the transient-op rung is switched off,
#        the capability probe's answer about that simulator (PN14) -- and,
#        with a second real program that has NO probe extension, the whole
#        road the user met: the line before the run, the report after it,
#        and the same bench on the registered program that can (PN15, which
#        prints a lowercase skip: line of its own when no such program
#        answers)
#   PE   the same simulator, starting from a CLICK: a session on a sheet,
#        ase::ui::sod_click on a pin (a resistor, a FET wrapper, a resistor
#        wrapper whose port is not its symbol's pin, a block's pin, a bus
#        instance, pins one level down), the rows the real
#        ase::ui::sod_queue puts in the session, xschem's own netlist of the
#        sheet, the real `render_deck`, the run, and each picked current back
#        out of the results -- by the file reader and through the viewer's
#        database -- with the value the circuit gives that pin
#   PN (with rows PA8g and PA8h) and PE are skipped with ONE lowercase skip:
#   line between them when no candidate answers `$?probe_version` = 1.
#
# FOR `hcases`: nothing here needs a display, and every row but those of PN,
# PA8g, PA8h and PE runs with no simulator at all.
#
# NOT FENCED HERE
# * PE clicks with explicit coordinates, on the pin's own point.  The click
#   the canvas binding makes (no coordinates, the raw cursor), the pin radius
#   and every refusal are test_ase_terminal_pick_1724's.
# * What a build WITHOUT the probe extension prints is driven from text copied
#   out of real runs (PL) for every row but PN15, which starts one: there one
#   device inside a subcircuit is refused in such a build's own words.  Its
#   refusal of a subcircuit instance's pin, and a vector that is missing with
#   no refusal line, are text only.
# * Band PH's stand-in simulators answer the capability probe with a file;
#   the real probe's answer is PN14's (a program that can) and PN15's (one
#   that cannot), and test_ase_variant_1470's EX rows for four real builds.
# * The menu entry and the buttons the cure names are read off the builders
#   of the window and of its Simulators dialogs as text (PH17, PH17b).  That the
#   widgets are there under those labels and do what the sentence says is
#   pressed on a display by row WG8 of test_ase_simwin_variant_1471.
# * The time one call of the cure may spend (PH13-PH15) is driven with two
#   or three seconds and a program that sleeps; the shipped figure is pinned as a
#   value (PH13b) and not waited out.
# * `distinguish` is planned and rendered (PP8, PR9, PL10, PR17) but not run
#   on the simulator; `preserve` is (PN6, PN10c).
# * PA1, PA3, PA4, PN1e, PN3b and the database answers of band PE read a
#   terminal through the results database by its `:` spelling.  That is the
#   lookup rung's doing -- in C, get_raw_index_in() (src/save.c), and in its
#   Tcl mirror, wviewer::name_rungs -- and not this file's subject: the
#   rung's own rows are test_pin_at_1724's.  On a binary built before the
#   feature PD0 says so first, and band PE fails there with those rows,
#   because the click it starts from asks `xschem pin_at`.
# * PL3's claim (a refusal printed again at every reload is one refusal) holds
#   by ase::probe_refusals answering a dict; no single line makes it.
# * The note for a run that did not converge is run on the simulator for one
#   failure only: an ac analysis whose operating point cannot be solved once
#   the transient-op rung is switched off (PN13b; PN13 is the same bench
#   with the rung on, which converges).  Every other shape is driven from log
#   text (PL27-PL29b): no row makes a transient stop converging, and none
#   stops a run or makes a later analysis fail.  The lines of PL27-PL29 are
#   in the shape of the simulator's own -- the transient's `Timestep too
#   small` line, the lines of an operating point that could not be solved,
#   the `singular matrix` warning of a run that went on to converge --
#   except the one for `no convergence`, which is the rule's literal in a
#   sentence of the row's own.  Those of PL28b and PL29b are copied out of
#   real runs: an operating point given up with the rung off, the rungs'
#   `stepping failed` warnings of a run that went on to converge, the
#   pole-zero search's warning.  The stock binary is never started: its
#   wording of the failure is text too (PL28b).
# * The note for a run whose analyses keep no terminal current is run on the
#   simulator for `noise`, alone (PA8g) and with a design-variable sweep
#   beside it (PA8h); `tf`, `pz` and `sens` are driven from written files
#   (PL15b, PL15c, PL15e).  A bench whose ONLY enabled analyses are two or
#   more design-variable sweeps still says nothing about an unqualified
#   terminal row: none of the sweeps is the bench's one analysis, so none
#   advises it, and none of the four kinds is there to bring the note (PL15f
#   pins the report's silence).
# * What an expression's Value says for a read of a name no `.save` card can
#   carry is compared with what the same simulator run gives a read of a name
#   the results simply lack (PN12): the sentence itself is the Calculator's
#   and is not pinned here.
# * A term the netlist's own `.probe` card holds is found by comparing TEXT
#   (PR15-PR18, PN10): a card that names the same terminal another way --
#   a pin by its letter against its position -- is not seen and the term is
#   written beside it.  Stock ngspice forms without a pin are not read.
# * A numbered port is followed through subcircuit BODIES in the netlist text
#   only (PQ5's `call` records): a call that stands inside a body kept in a
#   model file is not followed, and no row puts one there.
# * With the operating-point tier's own cards coming, a Save-ticked terminal
#   row adds no second leader: it takes the arm of the deck writer that every
#   `.save` card takes, which stands down for the tier's leader.  Seeing that
#   needs captured operating-point cards, and no row here has any.
# * PU2 and PU3 take their second leg with ase::saves_all_forced made to
#   answer 0: as a bench stands, a Save-ticked terminal row brings the leader
#   and the two preconditions never reach ase::saves_unresolved.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_probe_deck_1724

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
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

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set scratch [test_scratch ase_probe_deck_1724]
test_sim_registry_isolate
set ::sim_case_mode fold

check {PD0 fixture: this binary has `xschem pin_at`, so it is the build the terminal-current feature (and its `:` lookup rung) went into -- a stale binary names itself here} \
    [catch {xschem pin_at 0 0}] 0
check {PD0 fixture: the suite runs against an empty simulator registry, not the one in ~/.xschem} \
    [test_sim_registry_state] {0 {} {} path}

# ---- helpers ---------------------------------------------------------------
proc pd_wr {path text} { set f [open $path w] ; puts -nonewline $f $text ; close $f }
proc pd_rd {path} { set f [open $path r] ; set t [read $f] ; close $f ; return $t }
# The lines of a log, each ended with a newline.
proc pd_text {args} { return "[join $args "\n"]\n" }

# A state whose run directory is <scratch>/<cell>, so its results file is
# <scratch>/<cell>/<cell>_ase.raw and its plot sidecar sits beside it.
proc pd_state {cell outs {analyses {}}} {
    set s [ase::state_default]
    dict set s design [dict create lib pd cell $cell view schematic]
    set d [file join $::scratch $cell]
    file mkdir $d
    dict set s rundir $d
    dict set s outputs $outs
    if {$analyses ne {}} { dict set s analyses $analyses }
    return $s
}
# Rows {expr save plot} ... as output dicts named r0, r1, ...
proc pd_outs {args} {
    set out {}
    set i 0
    foreach {ex save plot} $args {
        lappend out [dict create name r$i expr $ex save $save plot $plot]
        incr i
    }
    return $out
}
proc pd_deck {st {nl {}}} {
    if {$nl eq {}} { set nl $::NLB }
    return [pcall [ase::backend_hook ngspice render_deck] $st $nl]
}
proc pd_lines {deck re} {
    set out {}
    foreach l [split $deck "\n"] {
        if {[regexp $re [string trim $l]]} { lappend out [string trim $l] }
    }
    return $out
}
# The first line of `deck` matching `re`, as a 0-based line number; -1 for none.
proc pd_at {deck re} {
    set i 0
    foreach l [split $deck "\n"] {
        if {[regexp $re [string trim $l]]} { return $i }
        incr i
    }
    return -1
}
# One field of every record of a plan / a report.
proc pd_col {recs key} {
    set out {}
    foreach r $recs { lappend out [ase::state_get $r $key] }
    return $out
}
# One POSITION of every element of a list of lists (a report's records are
# {kind signal sentence}, a spy's are {tag message}).
proc pd_nth {recs i} {
    set out {}
    foreach r $recs { lappend out [lindex $r $i] }
    return $out
}
proc pd_kinds {recs} {
    set out {}
    foreach r $recs { lappend out [list [lindex $r 0] [lindex $r 1]] }
    return $out
}
# Run `script` with ase::echo recording instead of speaking:
# -> {<script's answer> {{tag msg} ...}}.
proc pd_spy {script} {
    set ::pd_said {}
    rename ::ase::echo ::pd_real_echo
    proc ::ase::echo {msg {tag {}}} { lappend ::pd_said [list $tag $msg] ; return 1 }
    set rc [catch {uplevel 1 $script} r]
    rename ::ase::echo {}
    rename ::pd_real_echo ::ase::echo
    if {$rc} { set r "ERR:$r" }
    return [list $r $::pd_said]
}
# A results file of one-point plots, each {name {var ...}}, as ASCII.
proc pd_raw {path plots} {
    set t {}
    foreach p $plots {
        lassign $p name vars
        append t "Title: pd\nDate: none\nPlotname: $name\nFlags: real\n"
        append t "No. Variables: [llength $vars]\nNo. Points: 1\nVariables:\n"
        set i 0
        foreach v $vars {
            set ty current
            if {[string match {v(*} $v]} { set ty voltage }
            append t "\t$i\t$v\t$ty\n"
            incr i
        }
        append t "Values:\n"
        set i 0
        foreach v $vars {
            if {$i == 0} { append t " 0\t0.5\n" } else { append t "\t0.5\n" }
            incr i
        }
    }
    pd_wr $path $t
}
# The plot sidecar for a state: records {type idx name} in write order.
proc pd_map {st recs} {
    set t {}
    foreach r $recs {
        lassign $r type idx name
        append t "[ase::plotmap_record $type $idx $name]\n"
    }
    pd_wr [ase::plotmap_path $st] $t
}
proc pd_rawpath {st} { return [[ase::backend_hook ngspice raw_file] $st] }
# ase::probe_report for `st` over `log`, with the plan the deck would carry:
# -> {{kind signal} ...} and the spoken lines.
# The record also carries the run's own name for its program, as
# ase::run_deck's does: PD_SIM, which no row's machine can resolve to.
set PD_SIM {zzsim (/zz/bin/zz_ngspice)}
proc pd_report {st log {rc 0} {nl {}} {mode fold}} {
    if {$nl eq {}} { set nl $::NLB }
    set meta [dict create probes [ase::probe_plan $st $nl $mode] simname $::PD_SIM]
    return [pd_spy [list ase::probe_report $st $meta $log $rc]]
}
# What the report says of terminals a simulator cannot save, for PD_SIM, with
# no simulator registered: `what` is the words after "cannot save".
set PD_LIMIT {it saves terminal currents only on top-level devices that are not subcircuit instances.}
set PD_CURE0 "Register an ngspice build that saves terminal currents inside subcircuits under Setup > Simulators\u2026 and run again, or place an ammeter (ammeter.sym) in series with the pin."
proc pd_hier {what {sim {}} {cure {}}} {
    if {$sim eq {}} { set sim $::PD_SIM }
    if {$cure eq {}} { set cure $::PD_CURE0 }
    return "ase: $sim, the simulator this run started, cannot save $what: $::PD_LIMIT $cure"
}

# ---- the bench -------------------------------------------------------------
# Top level: a user block X1, a two-bit bus instance of it, a source, a
# resistor to ground whose current is known (V(g) = 1 V across 1 k), and an E
# source in the six-word spelling devices/vsource_arith.sym netlists.  Inside
# `blk`: R, C, V, D, a bare M with its bulk, Q, a FET wrapper, and a resistor
# wrapper whose ports (r0 r1 sub) are not a resistor symbol's pin names.
set NLB {** sch_path: probe bench 1724
x1 g out 0 blk
xb[1] g o1 0 blk
xb[0] g o0 0 blk
V1 g 0 dc 1 ac 1 distof1 1
Rtop g 0 1k
E5 e5 0 VOL=' v(g)*2 '
R6 e5 0 1k
.subckt res_wrap r0 r1 sub
R1 r0 r1 2k
.ends
.subckt nfet_wrap d g s b
M1 d g s b nm W=1u L=1u
.ends
.subckt blk in out vss
XM1 out in vss vss nfet_wrap
R1 out vdd_i 10k
C1 out vss 1p
D1 out nd dm
R2 nd vss 100k
Q1 vdd_i out ne qn
R3 ne vss 10k
M2 out2 in vss vss nm W=1u L=1u
R4 vdd_i out2 20k
XR1 vdd_i mid vss res_wrap
R5 mid vss 5k
V2 vdd_i vss 1.8
.ends
.model nm nmos level=1 vto=0.5 kp=100u
.model dm d
.model qn npn
.end
}
set AN_OPTRAN {{type op enabled 1} {type dc enabled 0} {type ac enabled 0}
               {type tran enabled 1 stop 10n step 1n}}
set AN_OP {{type op enabled 1}}
# The failure lines the note for a run that did not converge is keyed on, bar
# the one that says the operating point could not be simulated: for the rows
# that show a log holds none of them.  They are read out of ase::probe_report
# itself -- the pattern its one case-blind match of the log text is made with
# -- so an alternative added to the key there is one of the other lines here.
# CONVKEYS is what that reading found (one match gives two elements), CONVALTS
# the key's alternatives, CONVREST those of them that are not CONVNEW.  A key
# that cannot be read leaves CONVREST empty, and an empty pattern is found in
# every log: the fixture row below says so first, by name.
set CONVNEW {operating point could not be simulated}
set CONVKEYS {}
catch {set CONVKEYS [regexp -all -inline {regexp -nocase \{([^\}]*)\} \$data} [info body ase::probe_report]]}
set CONVALTS [split [lindex $CONVKEYS 1] |]
set CONVREST [join [lsearch -all -inline -not -exact $CONVALTS $CONVNEW] |]
check {PD0 fixture: the key of the note for a run that did not converge is read from ase::probe_report -- one such match in the proc, the line that says the operating point could not be simulated is one of its alternatives, there are others beside it, and none of them is empty (matches found, that line among them, the rest not empty, an empty alternative)} \
    [list [expr {[llength $CONVKEYS] / 2}] [expr {$CONVNEW in $CONVALTS}] [expr {$CONVREST ne {}}] [expr {{} in $CONVALTS}]] \
    {1 1 1 0}
set FACTS [ase::netlist_facts $NLB]

# =============================================================================
# PS -- THE PREDICATE, AND THE TERMINALS A ROW READS
# =============================================================================
group PS {
    set got {}
    foreach s {i(x1.xm1:d) I(X1.XM1:D) {i("x1.xm1:d")} i(r9:n1) i(x1:in) i(xb[1]:out) i(x1.xm3[1]:d)
               i(v1) i(v.x1.vp) i(a:b:c) i(:d) i(x1:) I(x1.xm1,d) {i( x1.r1:n1 )} v(a:b) x1.xm1:d#branch
               {i("x1.xm1:d)} {i(x1.xm1:d")} -i(x1.xm1:d) it(x1.xm1:d) {i(a:d) 2 *} i(a(b):c)} {
        lappend got [pcall ase::probe_split $s]
    }
    check {PS1 ase::probe_split: {path tname} for one `i(<path>:<tname>)` wrapper in either case, quoted or not, bus bits included; {} for a branch current, two colons, an empty side, the deck's comma form, inner whitespace, a `v()`, a bare name, one quote only, a signed or qualified ROW TEXT, an expression and a nested parenthesis} \
        $got [list {x1.xm1 d} {X1.XM1 D} {x1.xm1 d} {r9 n1} {x1 in} [list {xb[1]} out] [list {x1.xm3[1]} d] \
                   {} {} {} {} {} {} {} {} {} {} {} {} {} {} {}]
    check {PS1b whitespace around a signal is not part of it} \
        [list [ase::probe_split { i(x1.xm1:d) }] [ase::probe_split "\ti(r9:n1)\n"]] {{x1.xm1 d} {r9 n1}}
    check {PS1c a `;` on either side of the colon is no terminal -- on a dot card it starts a comment and would cut the `.probe` card where it stands: ase::probe_split answers {} for a `;` in the terminal and for one in the path, such a row reads no terminal and is not a terminal row; CONTROL the same two names without the `;` are terminals} \
        [list [ase::probe_split {i(x1.xm1:d;x)}] [ase::probe_split {i(x1;y:d)}] \
              [pcall ase::output_probes {i(x1.xm1:d;x)}] [pcall ase::output_is_probe {i(x1;y:d)}] \
              [ase::probe_split {i(x1.xm1:dx)}] [ase::probe_split {i(x1y:d)}]] \
        {{} {} {} 0 {x1.xm1 dx} {x1y d}}
    # Each of the five characters once in the path and once in the terminal,
    # then the five typed shapes measured to cut a card or to stop the run.
    set cut {}
    foreach c [list \$ = ' \{ \}] {
        lappend cut [ase::probe_split "i(r${c}t:n1)"] [ase::probe_split "i(rt:n${c}1)"]
    }
    set typed {}
    foreach s [list {i(rt:$n1)} {i(=rt:n1)} {i(rt:1')} {i(rt:1=)} "i(rt:1\{)"] {
        lappend typed [ase::probe_split $s]
    }
    set real {}
    foreach s {i(xm1[3]:d) i(x1.xm<2>:d) i(x1:in+) i(x1:in-)} {
        lappend real [ase::probe_split $s]
    }
    check {PS1d a dollar sign, an equals sign, a single quote and a brace of either kind are no part of a terminal on EITHER side of the colon -- the first cuts the `.probe` card like a `;`, the next two and the opening brace stop the simulator before any analysis: ase::probe_split answers nothing for each of the five in the path and for each in the terminal (ten names), and for the five typed shapes that were measured doing so; such a row reads no terminal and is not a terminal row; CONTROL the same two names without the character are terminals, and so are real names that carry square brackets, angle brackets, a plus or a minus (the distinct answers of the ten and their count, the five, a row's terminals, is it a terminal row, the two controls, the four real names)} \
        [list [lsort -unique $cut] [llength $cut] $typed \
              [pcall ase::output_probes {i(rt:$n1)}] [pcall ase::output_is_probe {i(=rt:n1)}] \
              [ase::probe_split i(rt:n1)] [ase::probe_split i(rt:1)] $real] \
        [list {{}} 10 {{} {} {} {} {}} {} 0 {rt n1} {rt 1} \
              [list [list {xm1[3]} d] {x1.xm<2> d} {x1 in+} {x1 in-}]]
    set got {}
    foreach ex {i(x1.xm1:d) -i(x1.xm1:d) it(x1.xm1:d) idc(x1.r1:n1) -it(x1.q1:c) {i("x1.xm1:d")} I(X1.R1:N1)
                {i(x1.r1:n1) v(out) *} {db(if(a:d)/if(b:d))} {value(it(a:d),1n)} {i(r1:n1)+i(r2:n1)}
                i(v1) v(out) -i(v1) {v(in) v(out) -} {i(v1) 2 *} {} {i( x1.r1:n1 )}} {
        lappend got [pcall ase::output_probes $ex]
    }
    check {PS2 ase::output_probes reads SIGNALS: a signed plain row and an analysis-qualified one give their terminal, a quoted one gives it unquoted, an expression gives every terminal it reads (postfix, infix, a nested call, a measurement call), each as lower-case-wrapper `i(<path>:<tname>)`; a row that reads none, an empty row and a text the Calculator refuses give none} \
        $got [list i(x1.xm1:d) i(x1.xm1:d) i(x1.xm1:d) i(x1.r1:n1) i(x1.q1:c) i(x1.xm1:d) i(X1.R1:N1) \
                   i(x1.r1:n1) {i(a:d) i(b:d)} i(a:d) {i(r1:n1) i(r2:n1)} \
                   {} {} {} {} {} {} {}]
    check {PS2c a row's text is read without the blanks around it: a signed terminal row typed with leading and trailing spaces still gives its terminal} \
        [pcall ase::output_probes {  -i(x1.xm1:d) }] i(x1.xm1:d)
    rename ::calc::eval_text_signals ::ps_real_ets
    set nc [list [pcall ase::output_probes {i(a:d) 2 *}] [pcall ase::output_probes i(a:d)]]
    rename ::ps_real_ets ::calc::eval_text_signals
    check {PS2b with the Calculator's signal reader absent an expression row reads no terminal and nothing raises; a plain row needs no Calculator and still gives its own} \
        $nc {{} i(a:d)}
    set got {}
    foreach ex {i(x1.xm1:d) -i(x1.xm1:d) it(x1.xm1:d) {i(x1.r1:n1) 2 *} i(v1) v(out)} {
        lappend got [pcall ase::output_is_probe $ex]
    }
    check {PS3 ase::output_is_probe is 1 for a PLAIN row naming one terminal (signed and qualified included) and 0 for an expression that reads one and for a row that reads none} \
        $got {1 1 1 0 0 0}
    check {PS4 the three signatures the deck writer, the run record and the run's completion call with (info args, and info default for the two defaulted formals)} \
        [list [info args ase::probe_split] [info args ase::probe_plan] \
              [info default ase::probe_plan mode d] $d \
              [info args ase::probe_report] [info default ase::probe_report exitcode e] $e] \
        {signal {state netlist_text mode} 1 fold {state meta data exitcode} 1 0}
}

# =============================================================================
# PX -- NO `.save` CARD, NO LEADER, NO PRE-FLIGHT ROW
# =============================================================================
group PX {
    set mixed [pd_outs i(x1.r1:n1) 1 0  -i(x1.m2:b_tj) 1 0  it(x1.q1:c) 1 0  v(out) 1 0  i(v1) 1 0 \
                       {i(x1.xr1:r0) v(out) *} 0 0  {i(x1.d1:a) i(rtop:n1) +} 1 0]
    set st [pd_state px $mixed $::AN_OPTRAN]
    set src [pcall ase::output_card_sources $st]
    set leak {}
    foreach s $src {
        if {[string first : [lindex $s 1]] >= 0} { lappend leak $s }
    }
    check {PX1 ase::output_card_sources gives no card for a terminal in either role: the plain cards are the two non-terminal saves, the read cards are the one node the expressions read, and no card holds a `:` (cards as {row card role}, then the leaks)} \
        [list $src $leak] \
        [list [list {v(out) v(out) plain} {i(v1) i(v1) plain} [list {i(x1.xr1:r0) v(out) *} v(out) read]] {}]
    # DERIVED: the same bench with every terminal row and terminal read taken
    # out by hand must give the same cards.
    set bare [pd_state px_bare [pd_outs v(out) 1 0  i(v1) 1 0  {v(out) 2 *} 0 0] $::AN_OPTRAN]
    check {PX2 the deck's save list for the mixed bench is exactly the list of the same bench with its terminal rows deleted (ase::output_save_cards, both benches)} \
        [list [pcall ase::output_save_cards $st] [pcall ase::output_save_cards $bare]] \
        {{v(out) i(v1)} {v(out) i(v1)}}
    set po [pd_state px_po [pd_outs i(x1.r1:n1) 1 0  -i(rtop:n1) 1 0  it(x1.q1:c) 1 1] $::AN_OPTRAN]
    set pl [pd_state px_pl [pd_outs i(x1.r1:n1) 0 1  it(x1.q1:c) 0 1  {i(x1.d1:a) 2 *} 1 0] $::AN_OPTRAN]
    check {PX3 a bench whose only ticked rows are terminals has NO `.save` card, and its Save ticks force the save-everything leader all the same: a save adds to what the simulator keeps, whichever card it is written as. A bench whose terminal rows are PLOT-only, beside a Save-ticked EXPRESSION over a terminal, forces none (cards, ase::saves_all_forced and ase::output_saves_any, for the two benches in turn)} \
        [list [pcall ase::output_save_cards $po] [pcall ase::saves_all_forced ngspice $po] [pcall ase::output_saves_any $po] \
              [pcall ase::output_save_cards $pl] [pcall ase::saves_all_forced ngspice $pl] [pcall ase::output_saves_any $pl]] \
        {{} 1 1 {} 0 0}
    check {PX3b ase::output_saves_any is the old test wherever no terminal row is ticked: 1 for a bench whose saves are `.save` cards and nothing else -- which forces the leader as it always did -- 0 for an empty bench, for one with no row ticked and for an output row that has no `expr` at all} \
        [list [pcall ase::output_saves_any $bare] [pcall ase::saves_all_forced ngspice $bare] [pcall ase::output_saves_any [ase::state_default]] \
              [pcall ase::output_saves_any [pd_state px_off [pd_outs v(out) 0 1  i(x1.r1:n1) 0 0] $::AN_OPTRAN]] \
              [pcall ase::output_saves_any [dict create outputs {{name x save 1 plot 1}}]]] {1 1 0 0 0}
    set scan [pcall ase::preflight_scan $st $::NLB]
    check {PX4 the pre-flight has no row for a terminal: nothing absent and nothing unknown on the mixed bench, although no terminal is in the netlist map} \
        [list [llength [ase::state_get $scan absent]] [llength [ase::state_get $scan unknown]]] {0 0}
    lassign [pd_spy [list ase::preflight_gate $st $::NLB]] gate said
    check {PX5 ase::preflight_gate passes the mixed bench and the terminal-only bench: no refusal is raised and no line is spoken} \
        [list [string match ERR:* $gate] [llength $said] \
              [string match ERR:* [lindex [pd_spy [list ase::preflight_gate $po $::NLB]] 0]]] {0 0 0}
    # CONTROL: the gate is live on this fixture -- the same bench with one save
    # that names no source IS refused, so PX5's pass is the exclusion's.
    set bad [pd_state px_bad [pd_outs i(x1.r1:n1) 1 0  i(vnosuch) 1 0] $::AN_OPTRAN]
    check {PX6 CONTROL: the gate still refuses a save the netlist lacks on the same fixture, and names only that row -- never the terminal beside it (raised, rows named in the refusal)} \
        [list [string match {ERR:*REFUSED*} [lindex [pd_spy [list ase::preflight_gate $bad $::NLB]] 0]] \
              [pd_col [ase::state_get [ase::preflight_scan $bad $::NLB] absent] expr]] {1 i(vnosuch)}

    # AN EXPRESSION'S READ OF A NAME NO `.save` CARD CAN CARRY.  One plain
    # Save-ticked row, so that the bench has read cards at all; then one
    # expression per name.  UNW are the names that make no card, KEPT the ones
    # that keep theirs: a `;`, a dollar sign, and a name the netlist lacks.
    set UNW [list {v(a=b)} {v(a'b)} "v(a\{b)" "v(a\}b)" {i(=rtop:n1)} {i(rtop:1')} {@m1[g=m]}]
    set KEPT [list {v(a;b)} {v(a$b)} {i(x;y:d)} {i(rtop:$n1)} {v(nosuch)}]
    set a {v(out) 1 0}
    set reads {}
    foreach n [concat $UNW $KEPT] {
        lappend a "$n 2 *" 0 0
        lappend reads [pcall calc::eval_text_signals [ase::output_calc_text "$n 2 *"]]
    }
    set stx [pd_state px_unw [pd_outs {*}$a] $::AN_OPTRAN]
    set want {{v(out) v(out) plain}}
    foreach n $KEPT { lappend want [list "$n 2 *" $n read] }
    set plainrow [pd_state px_unw_plain [pd_outs v(out) 1 0  {v(a=b)} 1 0] $::AN_OPTRAN]
    check {PX7 AN EXPRESSION'S READ MAKES NO CARD WHEN ITS NAME HOLDS AN EQUALS SIGN, A SINGLE QUOTE OR A BRACE of either kind -- a `.save` of such a name stops the simulator before any analysis: beside one plain save, expressions that each read one such name (a node, a terminal-shaped current, a device parameter) add nothing to ase::output_card_sources, while a read of a name holding a `;` or a dollar sign and of a name the netlist lacks keep their cards, in row order. FIXTURE the Calculator does read every one of those names as one signal, so a missing card is the rule's doing. And only the READ role is held to it: a Save-ticked PLAIN row of such a name is still a card (fixture, the card records, the deck's save list, the plain bench's records)} \
        [list $reads [pcall ase::output_card_sources $stx] [pcall ase::output_save_cards $stx] \
              [pcall ase::output_card_sources $plainrow]] \
        [list [lmap n [concat $UNW $KEPT] { list $n }] $want [list v(out) {*}$KEPT] \
              {{v(out) v(out) plain} {v(a=b) v(a=b) plain}}]
}

# =============================================================================
# PU -- A TERMINAL ROW IS NOT A SAVE THAT RESOLVES TO NOTHING
# =============================================================================
group PU {
    # ONE plain terminal row: the shape the adapter takes apart as a current
    # whose name is no source's.  (A signed or qualified row is not taken apart
    # and would count as resolving, which hides the miscount.)
    set po [pd_state pu_po [pd_outs i(x1.r1:n1) 1 0] $::AN_OPTRAN]
    set po3 [pd_state pu_po3 [pd_outs i(x1.r1:n1) 1 0  -i(rtop:n1) 1 0  it(x1.q1:c) 1 0] $::AN_OPTRAN]
    check {PU1 ase::saves_unresolved answers {0 0} for a bench whose only ticked rows are terminals -- one plain terminal, and three with a signed and a qualified one: none is counted as a save} \
        [list [pcall ase::saves_unresolved ngspice $po $::FACTS] [pcall ase::saves_unresolved ngspice $po3 $::FACTS]] {{0 0} {0 0}}
    # A Save-ticked terminal row brings the save-everything leader
    # (ase::saves_all_forced), and the two preconditions built on
    # ase::saves_unresolved stand down for any bench that has the leader.  So
    # each row below is taken twice: as the bench stands, and with the leader's
    # answer taken away for the length of one script, where the preconditions
    # do reach ase::saves_unresolved and its not counting a terminal row is
    # what keeps them quiet.
    proc pu_noleader {script} {
        rename ::ase::saves_all_forced ::pu_real_forced
        proc ::ase::saves_all_forced {sim state} { return 0 }
        set rc [catch {uplevel 1 $script} r]
        rename ::ase::saves_all_forced {}
        rename ::pu_real_forced ::ase::saves_all_forced
        if {$rc} { return "ERR:$r" }
        return $r
    }
    # The preconditions of id `id` that the enabled analyses of `st` raise.
    proc pu_needs {st id} {
        set ids {}
        foreach a [dict get $st analyses] {
            if {[dict get $a enabled] ne {1}} continue
            foreach n [pcall ase::analysis_needs ngspice $a $::FACTS {} $st] {
                lappend ids [lindex $n 0]
            }
        }
        return [lsearch -all -inline -exact $ids $id]
    }
    set bad [pd_state pu_bad [pd_outs i(vnosuch) 1 0] $::AN_OPTRAN]
    check {PU2 neither enabled analysis (op, tran) of the one-terminal bench carries the `saves_resolve` precondition: not as the bench stands, and not with the leader's answer taken away, where the precondition counts the saves itself (ids of every precondition raised, filtered to it, both ways); CONTROL with the leader's answer taken away the bench whose one save names no source does raise it, once per enabled analysis} \
        [list [pu_needs $po saves_resolve] [pu_noleader {pu_needs $po saves_resolve}] \
              [pu_noleader {pu_needs $bad saves_resolve}]] \
        {{} {} {saves_resolve saves_resolve}}
    set dst [pd_state pu_disto [pd_outs i(x1.r1:n1) 1 0] \
               {{type disto enabled 1 sweep dec points 2 start 1k stop 10k}}]
    set dbad [pd_state pu_dbad [pd_outs i(vnosuch) 1 0] \
               {{type disto enabled 1 sweep dec points 2 start 1k stop 10k}}]
    lassign [pd_spy [list ase::preflight_gate $dst $::NLB]] gate said
    check {PU3 a distortion bench whose only saved output is a terminal passes ase::preflight_gate and renders, and its analysis carries no `disto_saves` precondition -- as the bench stands and with the leader's answer taken away (raised by the gate, raised by render_deck, `.probe` cards in the deck, the precondition both ways); CONTROL without that answer the same bench with a save that names no source does carry it} \
        [list [string match ERR:* $gate] [string match ERR:* [pd_deck $dst]] \
              [pd_lines [pd_deck $dst] {^\.probe }] \
              [pu_needs $dst disto_saves] [pu_noleader {pu_needs $dst disto_saves}] \
              [pu_noleader {pu_needs $dbad disto_saves}]] \
        {0 0 {{.probe I(x1.r1,1)}} {} {} disto_saves}
    # CONTROL: the two preconditions are live on this fixture.
    check {PU4 CONTROL: a save that names no source is still counted and unresolved ({1 0}), and still counts beside a terminal row, which adds nothing to either number} \
        [list [pcall ase::saves_unresolved ngspice $bad $::FACTS] \
              [pcall ase::saves_unresolved ngspice \
                 [pd_state pu_bad2 [pd_outs i(vnosuch) 1 0  i(x1.r1:n1) 1 0  v(out) 1 0] $::AN_OPTRAN] $::FACTS]] \
        {{1 0} {2 1}}
}

# =============================================================================
# PP -- THE PROBE PLAN
# =============================================================================
# The E and K fixtures.  The `.subckt` block comes FIRST and holds an `E9` of
# seven words, so a finder that ignored `.subckt` scope would read that card
# for the top-level `E9` of four and give it a term.
set NLE {* e and k
.subckt eblk a b
E9 a b a 0 1 2 3
K2 L1 L2 0.5
.ends
V1 g 0 1
E5 TEMPERAT VSS VOL=' temper '
E9 e9 0 vol='v(g)*2'
E7 e7 0
+ vol='v(g)*2'
E8 e8 0
* a comment between a card and its continuation
+ VOL=' v(g)*2 '
E3 o3 0 g 0 2
E6 e6 0 value={ v(g)*2 }
E4 e4 0 vol=' v(g)*2'
E2 e2 0 vol = 'v(g)*2'
K1 L1 L2 0.5
x1 g o eblk
.end
}
proc pp_plan {rows {mode fold} {nl {}}} {
    if {$nl eq {}} { set nl $::NLB }
    set a {}
    foreach r $rows { lappend a $r 1 0 }
    return [ase::probe_plan [pd_state pp [pd_outs {*}$a] $::AN_OP] $nl $mode]
}
group PP {
    set p [pp_plan {i(x1.r1:n1) i(x1.c1:n2) i(x1.v2:n1) i(x1.d1:a) i(x1.m2:d) i(x1.m2:b_tj) i(x1.q1:c)
                    i(x1.xm1:d) i(x1.xr1:r0) i(x1:out) i(xb[1]:out) i(xb[0].xm1:s) i(rtop:n2)}]
    check {PP1 the card term per device class: a position for `n<k>`, `b` for a MOS bulk, a device's own letter and a subcircuit port as they stand, a bus bit kept (the plan's `card` column, then every `why`)} \
        [list [pd_col $p card] [lsort -unique [pd_col $p why]]] \
        [list [list I(x1.r1,1) I(x1.c1,2) I(x1.v2,1) I(x1.d1,a) I(x1.m2,d) I(x1.m2,b) I(x1.q1,c) I(x1.xm1,d) I(x1.xr1,r0) I(x1,out) {I(xb[1],out)} {I(xb[0].xm1,s)} I(rtop,2)] {{}}]
    check {PP2 each record names its vector as the simulator does, lower-case wrapper, and holds the card's own path and pin; its keys are signal, path, pin, card, why and nohdr, in that order, for every record of the plan (the whole record of the MOS bulk and of the top-level resistor, then the distinct key lists)} \
        [list [lindex $p 5] [lindex $p 12] [lsort -unique [lmap r $p { dict keys $r }]]] \
        [list {signal i(x1.m2:b_tj) path x1.m2 pin b card I(x1.m2,b) why {} nohdr {}} \
              {signal i(rtop:n2) path rtop pin 2 card I(rtop,2) why {} nohdr {}} \
              {{signal path pin card why nohdr}}]
    check {PP3 a subcircuit instance is asked BY PORT NAME even when the port reads like a position word: `n1` and `b_tj` stay as they are behind a leaf that starts with x} \
        [pd_col [pp_plan {i(x1:n1) i(x1.xr1:b_tj)}] card] {I(x1,n1) I(x1.xr1,b_tj)}

    # WHAT IS ASKED.
    set outs [pd_outs i(x1.r1:n1) 1 0  i(rtop:n1) 0 1  i(x1.c1:n1) 0 0  {i(x1.d1:a) 2 *} 0 0 \
                      -i(x1.r1:n1) 1 0  I(X1.R1:N1) 1 0  v(out) 1 0  i(v1) 1 1  it(x1.q1:c) 0 1]
    set st [pd_state pp_ask $outs $::AN_OP]
    check {PP4 ASKED: a Saves-tab row with Save OR Plot ticked and every terminal a Measures-tab row reads; a Saves-tab row with neither box ticked is not asked; a terminal named twice (signed, or in another case) is asked once under fold -- in pane order} \
        [pd_col [ase::probe_plan $st $::NLB fold] signal] {i(x1.r1:n1) i(rtop:n1) i(x1.d1:a) i(x1.q1:c)}
    check {PP5 ...and under `distinguish` the differently-cased spelling is its own terminal} \
        [pd_col [ase::probe_plan $st $::NLB distinguish] signal] \
        {i(x1.r1:n1) i(rtop:n1) i(x1.d1:a) i(X1.R1:N1) i(x1.q1:c)}
    # Every row below has Save and Plot OFF, as the Add Output dialog leaves them.
    set un [pd_outs idc(x1.c1:n1) 0 0  -i(x1.v2:n1) 0 0  it(x1.q1:c) 0 0  i(x1.d1:a) 0 0  {idc(x1.m2:d) 1 *} 0 0  v(out) 0 0]
    check {PP4b A MEASURES-TAB ROW IS ASKED WHETHER OR NOT IT IS TICKED, plain or not: with every box off, the three one-signal Measures rows (`idc()`, a signed one, `it()`) and the expression are asked, and the Saves-tab terminal row is not (the tab of each row, then the plan's signals)} \
        [list [lmap o $un { ase::output_tab [dict get $o expr] }] \
              [pd_col [ase::probe_plan [pd_state pp_un $un $::AN_OP] $::NLB fold] signal]] \
        [list {measures measures measures saves measures saves} {i(x1.c1:n1) i(x1.v2:n1) i(x1.q1:c) i(x1.m2:d)}]

    # WHAT THE MEASUREMENT ROWS ASK.  The signal fields of these kinds are
    # `target`, `trig`, `targ` and `when`; the last row but one is switched off
    # and the last reads an analysis this bench has not enabled, so neither is
    # written into the deck.
    set mrows [list \
        {name ipk analysis tran kind max target i(x1.xm1:d)} \
        {name tdl analysis tran kind trigtarg trig v(g) trigval 0.5 targ i(x1.r1:n1) targval 1u} \
        {name fnd analysis tran kind find target i(x1.q1:c) when i(x1.d1:a) value 1u} \
        {name two analysis tran kind max target i(x1.m2:d)-I(X1.M2:B_TJ)} \
        {name dec analysis tran kind max target vi(x1.r1:n2)} \
        {name vpk analysis tran kind max target v(out)} \
        {name src analysis tran kind max target i(v1)} \
        {name par analysis tran kind param expr i(x1.c1:n2)*2} \
        {name off analysis tran kind max target i(x1.c1:n1) enabled 0} \
        {name nac analysis ac kind max target i(x1.c1:n2)}]
    set stm [pd_state pp_meas {} $::AN_OPTRAN]
    dict set stm measurements $mrows
    check {PP14 EVERY TERMINAL AN ENABLED MEASUREMENT ROW READS IS ASKED, with no Outputs row at all: the target of a statistic, the target of a delay whose trigger is a node, the signal and the `when` signal of a find, and both tokens of a two-signal target, in row order; a function whose name merely ends in i, a node, a source's current, a field that is not a signal field (the expression of a `param` row), a row that is switched off and a row whose analysis is not enabled ask for nothing (fixture: the verdict word and enabled flag of each row; then ase::meas_probes, the plan's signals and its cards)} \
        [list [lmap r $mrows { list [lindex [ase::meas_verdict ngspice $stm $r] 0] [ase::meas_enabled $r] }] \
              [pcall ase::meas_probes $stm] \
              [pd_col [ase::probe_plan $stm $::NLB fold] signal] [pd_col [ase::probe_plan $stm $::NLB fold] card]] \
        [list {{ok 1} {ok 1} {ok 1} {ok 1} {ok 1} {ok 1} {ok 1} {ok 1} {ok 0} {refuse 1}} \
              {i(x1.xm1:d) i(x1.r1:n1) i(x1.q1:c) i(x1.d1:a) i(x1.m2:d) i(X1.M2:B_TJ)} \
              {i(x1.xm1:d) i(x1.r1:n1) i(x1.q1:c) i(x1.d1:a) i(x1.m2:d) i(X1.M2:B_TJ)} \
              {I(x1.xm1,d) I(x1.r1,1) I(x1.q1,c) I(x1.d1,a) I(x1.m2,d) I(X1.M2,b)}]
    set stmo [pd_state pp_measout [pd_outs i(rtop:n1) 1 0  i(x1.xm1:d) 0 1] $::AN_OPTRAN]
    dict set stmo measurements {{name a analysis tran kind max target I(X1.XM1:D)} {name b analysis tran kind avg target i(x1.r4:n1)}}
    check {PP15 the Outputs rows' terminals come first, in pane order, then the measurement rows'; a terminal a measurement reads under another case than an Outputs row is one terminal under fold and its own under `distinguish`} \
        [list [pd_col [ase::probe_plan $stmo $::NLB fold] signal] [pd_col [ase::probe_plan $stmo $::NLB distinguish] signal]] \
        [list {i(rtop:n1) i(x1.xm1:d) i(x1.r4:n1)} {i(rtop:n1) i(x1.xm1:d) i(X1.XM1:D) i(x1.r4:n1)}]
    check {PP6 no state, no outputs, a bench with no terminal row and an output row that has no `expr` at all each plan nothing, and none raises} \
        [list [pcall ase::probe_plan {} $::NLB] [pcall ase::probe_plan [ase::state_default] $::NLB] \
              [pcall ase::probe_plan [pd_state pp_none [pd_outs v(out) 1 1  i(v1) 1 0] $::AN_OP] $::NLB] \
              [pcall ase::probe_plan [dict create outputs {{name x save 1 plot 1}}] $::NLB]] {{} {} {} {}}

    # THE CASE RULE, top-level device against everything else.
    set rows {i(Rtop:n1) i(rlow:n2) i(x1.R1:n1) i(X1:out) i(Mtop:d)}
    check {PP7 a TOP-LEVEL device that is no subcircuit instance has its instance lower-cased in the card under fold and under preserve; a path inside a subcircuit and a subcircuit instance keep the row's spelling} \
        [list [pd_col [pp_plan $rows fold] card] [pd_col [pp_plan $rows preserve] card]] \
        [list {I(rtop,1) I(rlow,2) I(x1.R1,1) I(X1,out) I(mtop,d)} {I(rtop,1) I(rlow,2) I(x1.R1,1) I(X1,out) I(mtop,d)}]
    check {PP7b the position word and the bulk word are read WITHOUT CASE: an upper-case `N1` is the position 1 and an upper-case `B_TJ` is the bulk `b` (cards of the rows I(RTOP:N1) and i(x1.M2:B_TJ))} \
        [pd_col [pp_plan {I(RTOP:N1) i(x1.M2:B_TJ)}] card] {I(rtop,1) I(x1.M2,b)}
    set pd [pp_plan $rows distinguish]
    set whys {}
    foreach r $pd { lappend whys [expr {[dict get $r why] ne {}}] }
    check {PP8 under `distinguish` such a device gets a card only when its name has no capital -- the two that have one are withheld with a reason, and nothing else is touched (cards, then which records carry a reason)} \
        [list [pd_col $pd card] $whys] [list {{} I(rlow,2) I(x1.R1,1) I(X1,out) {}} {1 0 0 0 1}]

    # THE E SOURCE AND THE K COUPLING.
    set rows {i(e5:n1) i(e5:n2) i(e5:n3) i(e9:n1) i(e7:n2) i(e3:n3) i(e6:n1) i(e6:n4) i(enone:n1)
              i(x1.e9:n1) i(k1:n1) i(x1.k2:n1)}
    set pe [pp_plan $rows fold $::NLE]
    check {PP9 the E guard, both ways: the six-word `VOL=` card vsource_arith netlists gets its two terms and loses pin 3; a card of fewer than six words gets none, also when a `+` line carries the expression; a linear E keeps pin 3; a `value=` card of six words keeps pin 1 and loses pin 4; a card the netlist does not hold, and an E inside a subcircuit, get their terms; a K gets none at either depth} \
        [pd_col $pe card] {I(e5,1) I(e5,2) {} {} {} I(e3,3) I(e6,1) {} I(enone,1) I(x1.e9,1) {} {}}
    check {PP9b THE BOUNDARY of that guard is SIX words: the expression source written one blank short of them -- five words -- gets no term, and the spelling of the same source that blanks alone bring to six gets its own (the word count of each card as the plan reads it, then the two cards)} \
        [list [llength [regexp -all -inline {\S+} [ase::probe_top_card $::NLE e4]]] \
              [llength [regexp -all -inline {\S+} [ase::probe_top_card $::NLE e2]]] \
              [pd_col [pp_plan {i(e4:n1) i(e2:n1)} fold $::NLE] card]] {5 6 {{} I(e2,1)}}
    set whys {}
    foreach r $pe { lappend whys [expr {[dict get $r why] ne {}}] }
    check {PP10 every record without a term carries a reason and every record with one carries none (reason present, per record)} \
        $whys {0 0 1 1 1 0 0 1 0 0 1 1}
    check {PP11 the E card is found by name without case, so the upper-case row of a preserve run is withheld like the lower-case one; ase::probe_top_card answers the joined top-level card and never the subcircuit's} \
        [list [pd_col [pp_plan {i(E9:n1) i(E5:n1)} preserve $::NLE] card] \
              [ase::probe_top_card $::NLE e9] [ase::probe_top_card $::NLE E7] [ase::probe_top_card $::NLE k2]] \
        [list {{} I(e5,1)} {E9 e9 0 vol='v(g)*2'} {E7 e7 0 vol='v(g)*2'} {}]
    check {PP13 the card finder skips a comment line between a card and its `+` continuation, so the six-word source joined across one keeps its term, and it is not thrown by an `.ends` with no `.subckt` above it (the joined card, the term, the card found after a stray `.ends`)} \
        [list [ase::probe_top_card $::NLE e8] [pd_col [pp_plan {i(e8:n2)} fold $::NLE] card] \
              [ase::probe_top_card ".ends\nE9 e9 0 vol='1'\n" e9]] \
        [list {E8 e8 0 VOL=' v(g)*2 '} I(e8,2) {E9 e9 0 vol='1'}]
    check {PP12 ase::probe_terms is the plan's written cards in plan order, and ase::probe_mode reads the run's requested case mode (the floor here: fold, then preserve)} \
        [list [ase::probe_terms $pe] [ase::probe_mode [ase::state_default]] \
              [apply {{} { set ::sim_case_mode preserve ; set m [ase::probe_mode [ase::state_default]] ; set ::sim_case_mode fold ; return $m }}]] \
        {{I(e5,1) I(e5,2) I(e3,3) I(e6,1) I(enone,1) I(x1.e9,1)} fold preserve}
    set pa [pp_plan {i(x1.m2:b) i(x1.m2:b_tj) i(x1.m2:d)}]
    check {PP12b TWO NAMES FOR ONE TERMINAL are two records carrying one card, so the report can speak about each row, and the card is written once: ase::probe_terms gives each distinct term once, in plan order (the plan's signals, its cards, then the terms)} \
        [list [pd_col $pa signal] [pd_col $pa card] [ase::probe_terms $pa]] \
        [list {i(x1.m2:b) i(x1.m2:b_tj) i(x1.m2:d)} {I(x1.m2,b) I(x1.m2,b) I(x1.m2,d)} {I(x1.m2,b) I(x1.m2,d)}]
}

# =============================================================================
# PQ -- A SUBCIRCUIT PORT WHOSE NAME IS A NUMBER
# =============================================================================
# The simulator reads a word of digits in a `.probe` card as a POSITION, also
# where a port has that number as its name, so the card of such a port has to
# carry its position in the subcircuit's header.  X1 calls a vendor-style
# macro-model whose ports are numbers out of order; X2 and the instance inside
# `wrap` call `blk`, whose ports 3 2 7 stand at positions 1 2 3; X3 and X6 put
# words behind the callee, X3 splits its card over two lines and X6 stands at
# the top level BELOW the subcircuits; `dup` names one port twice (5 3 3 7);
# `nosuch` and `elsewhere` have no header in this text.
set NLQ {* numbered ports
V1 a 0 1
V2 c 0 2
X1 PLUS OUT VCC VEE OUT LM741
X2 a b c blk
Xw a b2 c wrap
X3 a b
* a comment between a card and its continuation
+ c blk params: k=2
X4 a b b c dup
X5 a b c nosuch
RL b 0 1k
.SUBCKT LM741 1 2 99 50 28
R1 1 2 1k
.ENDS
.subckt blk 3 2 7
Ra 3 2 1k
Rb 2 7 3k
.ends
.subckt wrap p q r
Xi p q r blk
Xq p q r elsewhere
.ends
.subckt dup 5 3 3 7
Ra 3 7 1k
.ends
X6 a b c blk m=2
.end
}
proc pq_plan {rows {nl {}} {st {}}} {
    if {$nl eq {}} { set nl $::NLQ }
    if {$st eq {}} { set st [pd_state pq {} $::AN_OP] }
    set a {}
    foreach r $rows { lappend a $r 1 0 }
    dict set st outputs [pd_outs {*}$a]
    return [ase::probe_plan $st $nl fold]
}
# Run `script` counting the calls of the header lookup and of the model-file
# reader: -> {<script's answer> <ase::probe_x_ports calls> <ase::subckt_lib calls>}.
# (The real procs are parked INSIDE namespace ase: ase::subckt_lib keeps its
# cache in a variable of the namespace it stands in.)
proc pq_counted {script} {
    set ::pq_n {0 0}
    rename ::ase::probe_x_ports ::ase::pq_real_ports
    rename ::ase::subckt_lib ::ase::pq_real_lib
    proc ::ase::probe_x_ports {args} { lset ::pq_n 0 [expr {[lindex $::pq_n 0] + 1}] ; return [::ase::pq_real_ports {*}$args] }
    proc ::ase::subckt_lib {args} { lset ::pq_n 1 [expr {[lindex $::pq_n 1] + 1}] ; return [::ase::pq_real_lib {*}$args] }
    set rc [catch {uplevel 1 $script} r]
    rename ::ase::probe_x_ports {}
    rename ::ase::subckt_lib {}
    rename ::ase::pq_real_ports ::ase::probe_x_ports
    rename ::ase::pq_real_lib ::ase::subckt_lib
    if {$rc} { set r "ERR:$r" }
    return [list $r {*}$::pq_n]
}
group PQ {
    set p [pq_plan {i(x1:99) i(x1:1) i(x1:28) i(x2:3) i(x2:2) i(x2:7) i(xw.xi:7) i(xw.xi:3)}]
    check {PQ1 the card of a NUMBERED port carries the port's 1-based position in the callee's header: `99`, third of `1 2 99 50 28`, is 3 and `28` is 5; over `.subckt blk 3 2 7` the port 3 is position 1, the port 2 its own position and the port 7 position 3; one level down, `xw.xi` is followed through `wrap`'s body to the same header (cards, then the distinct `why` and `nohdr`)} \
        [list [pd_col $p card] [lsort -unique [pd_col $p why]] [lsort -unique [pd_col $p nohdr]]] \
        [list {I(x1,3) I(x1,1) I(x1,5) I(x2,1) I(x2,2) I(x2,3) I(xw.xi,3) I(xw.xi,1)} {{}} {{}}]
    check {PQ2 the record keeps the ROW's name as its signal and holds the card's own pin, so the report looks for the vector the simulator will write and matches a refusal on what the deck asked (the whole record of i(x2:7))} \
        [lindex $p 5] {signal i(x2:7) path x2 pin 3 card I(x2,3) why {} nohdr {}}
    check {PQ3 THE CALLEE IS FOUND on a card split over two lines with a comment between them, in front of `params:` and in front of a `<k>=<v>` word; a card below a subcircuit's `.ends` is at the top level again; names are compared without case (ase::probe_x_calls of the text for the top level and for `wrap`; the cards of the port 7 of X3, of X6 and of an upper-case row)} \
        [list [dict get [ase::probe_x_calls $::NLQ] {}] [dict get [ase::probe_x_calls $::NLQ] wrap] \
              [pd_col [pq_plan {i(x3:7) i(x6:7) i(X2:7)}] card]] \
        [list {x1 lm741 x2 blk xw wrap x3 blk x4 dup x5 nosuch x6 blk} {xi blk xq elsewhere} {I(x3,3) I(x6,3) I(X2,3)}]
    set p [pq_plan {i(x2:1) i(x2:9) i(x4:3) i(x4:7)}]
    set pb [pq_plan {i(x1:2) i(x1:out)} $::NLB]
    check {PQ4 A NUMBER THAT IS NO PORT OF THE HEADER is a position somebody typed and is written as it stands, with nothing flagged: over ports 3 2 7, and over the letter ports `in out vss`; a number a header names TWICE is written as it stands too, while the port beside it that is named once gets its position (cards and `nohdr` over `blk` and `dup`, then over the letter-port block with a named port as control)} \
        [list [pd_col $p card] [pd_col $p nohdr] [pd_col $pb card] [pd_col $pb nohdr]] \
        [list {I(x2,1) I(x2,9) I(x4,3) I(x4,4)} {{} {} {} {}} {I(x1,2) I(x1,out)} {{} {}}]
    set p [pq_plan {i(x5:7) i(x9:5) i(xw.xq:5) i(xw.xq.xz:5) i(xw.xn:5)}]
    check {PQ5 NO HEADER TO BE FOUND: the number is written as it stands, the card is still written, and the record's `nohdr` says what was missing -- `header <subcircuit>` when the call was followed and that subcircuit has no header in the netlist or in a model file, `call <instance path>` when the netlist holds no card for an instance on the way (cards, every `why`, then `nohdr` per record)} \
        [list [pd_col $p card] [lsort -unique [pd_col $p why]] [pd_col $p nohdr]] \
        [list {I(x5,7) I(x9,5) I(xw.xq,5) I(xw.xq.xz,5) I(xw.xn,5)} {{}} \
              {{header nosuch} {call x9} {header elsewhere} {call xw.xq.xz} {call xw.xn}}]

    # ---- the header in a model file ------------------------------------------
    # The run directory holds q_inc.spice, with the header 3 2 7, and
    # q_lib.spice, whose section `ff` gives the same subcircuit the ports 7 2 3
    # and whose section `tt` pulls q_inc.spice in by a name relative to itself.
    set stq [pd_state pq_files {} $::AN_OP]
    set qd [dict get $stq rundir]
    pd_wr [file join $qd q_inc.spice] "* a model file\n.subckt blk 3 2 7\nRa 3 2 1k\nRb 2 7 3k\n.ends\n"
    pd_wr [file join $qd q_lib.spice] ".lib ff\n.subckt blk 7 2 3\nRa 3 2 1k\nRb 2 7 3k\n.ends\n.endl\n.lib tt\n.include q_inc.spice\n.endl\n"
    set NLQF "* header out of the text\nV1 a 0 1\nV2 c 0 2\nX1 a b c blk\nRL b 0 1k\n"
    set by {}
    lappend by [pd_col [pq_plan {i(x1:7)} "$NLQF.include q_inc.spice\n.end\n" $stq] card]
    lappend by [pd_col [pq_plan {i(x1:7)} "$NLQF.include \"[file join $qd q_inc.spice]\"\n.end\n" $stq] card]
    lappend by [pd_col [pq_plan {i(x1:7)} "$NLQF.lib q_lib.spice ff\n.end\n" $stq] card]
    lappend by [pd_col [pq_plan {i(x1:7)} $NLQF [dict replace $stq includes [list [dict create file q_inc.spice]]]] card]
    lappend by [pd_col [pq_plan {i(x1:7)} $NLQF [dict replace $stq includes [list [file join $qd q_inc.spice]]]] card]
    lappend by [pd_col [pq_plan {i(x1:7)} $NLQF [dict replace $stq models [list [dict create file q_lib.spice section ff]]]] card]
    lappend by [pd_col [pq_plan {i(x1:7)} $NLQF [dict replace $stq models [list [dict create file q_lib.spice section tt]]]] card]
    set none [pq_plan {i(x1:7)} $NLQF $stq]
    check {PQ6 THE HEADER IS FOUND IN THE MODEL FILES THE DECK NAMES when the netlist text has none: through the text's own `.include` (a name relative to the run directory, and a quoted absolute one), its `.lib <file> <section>`, the state's `includes` rows (a {file} record and a bare path) and its `models` rows -- where the SECTION decides, `ff` putting the port 7 first and `tt`, which includes the other file, third (the card of the port 7 for each of the seven; CONTROL with no file named the number stands and `nohdr` names the subcircuit)} \
        [list $by [pd_col $none card] [pd_col $none nohdr]] \
        [list {I(x1,3) I(x1,3) I(x1,1) I(x1,3) I(x1,3) I(x1,1) I(x1,3)} I(x1,7) {{header blk}}]
    check {PQ7 THE NETLIST TEXT COMES FIRST: with a header in the text and a different one in a named model file, the text's decides, and no model file is read for it (the card over `blk 3 2 7` in the text with section `ff` named; lookups made, model-file reads made)} \
        [pq_counted {pd_col [pq_plan {i(x2:7)} $::NLQ [dict replace $stq models [list [dict create file q_lib.spice section ff]]]] card}] \
        {I(x2,3) 1 0}
    check {PQ8 NOTHING IS LOOKED UP FOR A NAME THAT IS NOT ALL DIGITS: a plan of letter ports, device terminals and a device's own `n<k>` makes no header lookup and reads no model file, also on a bench that names one; a numbered port whose header is out of the text makes one lookup and one read (answer, lookups, reads -- for the two plans)} \
        [list [pq_counted {pd_col [pq_plan {i(x1:out) i(x1.xm1:d) i(x1.r1:n1) i(rtop:n2) i(x1:n1)} $::NLB \
                                     [dict replace $stq models [list [dict create file q_lib.spice section ff]]]] card}] \
              [pq_counted {pd_col [pq_plan {i(x1:7)} $NLQF [dict replace $stq includes [list q_inc.spice]]] card}]] \
        [list {{I(x1,out) I(x1.xm1,d) I(x1.r1,1) I(rtop,2) I(x1,n1)} 0 0} {I(x1,3) 1 1}]
    check {PQ9 the lookup's own answers (ase::probe_x_ports): the header found in the text, the one found in a file, the subcircuit with no header, the instance with no card, and a subcircuit the text gives TWO DIFFERENT headers, which is no header to go by} \
        [list [ase::probe_x_ports xw.xi $::NLQ {}] [ase::probe_x_ports X1 "$NLQF.include q_inc.spice\n.end\n" $stq] \
              [ase::probe_x_ports x5 $::NLQ {}] [ase::probe_x_ports x2.xz $::NLQ {}] \
              [ase::probe_x_ports x1 "X1 a b two\n.subckt two 1 2\n.ends\n.subckt two 2 1\n.ends\n" {}]] \
        [list {1 blk {3 2 7}} {1 blk {3 2 7}} {0 header nosuch} {0 call x2.xz} {0 header two}]
    check {PQ10 ase::probe_card takes the bench as a fifth, defaulted argument, so a call without it still answers and looks in the netlist text alone (info args, the default, the card with four arguments)} \
        [list [info args ase::probe_card] [info default ase::probe_card state d] $d \
              [dict get [ase::probe_card x2 7 $::NLQ fold] card]] \
        {{path tname netlist_text mode state} 1 {} I(x2,3)}

    # ---- the header reader ----------------------------------------------------
    set txt ".subckt A 1 2 params: w=1\n.ends\n.SUBCKT a 1 2\n.ends\n.subckt A 2 1\n.ends\n.subckt B in out\n+ vss w=2\n.ends\n.include \"inc_one.spice\"\n.inc inc2.spice\n.lib corner.lib tt\n.lib sec\n.subckt C x y\n.ends\n.endl\nR1 a b 1k\n"
    check {PQ11 ase::subckt_scan: headers by lower-case name, each DISTINCT port list once and as spelled, ports ending at `params:` and at the first `<k>=<v>` word, a `+` continuation joined on; the `.include`, `.inc` and three-word `.lib` cards with their section; with no section asked a `.lib <name>` block is read like the rest, and with one asked only what stands between `.lib <name>` and `.endl` is} \
        [list [ase::subckt_scan $txt {}] [ase::subckt_scan $txt sec] [ase::subckt_scan $txt other]] \
        [list [list [dict create a {{1 2} {2 1}} b {{in out vss}} c {{x y}}] {{inc_one.spice {}} {inc2.spice {}} {corner.lib tt}}] \
              [list [dict create c {{x y}}] {}] [list [dict create] {}]]
    set f1 [file join $qd w_top.lib]
    set f2 [file join $qd sub w_in.spice]
    file mkdir [file join $qd sub]
    pd_wr $f1 ".lib tt\n.include sub/w_in.spice\n.endl\n.lib ff\n.subckt blk 7 2 3\n.ends\n.endl\n"
    pd_wr $f2 ".subckt blk 3 2 7\n.ends\n.include w_none.spice\n"
    lassign [ase::subckt_walk [list [list $f1 tt]]] wsub wst
    check {PQ12 ase::subckt_walk follows a file's own `.include` relative to the directory of the file that wrote it, reads only the asked section of the first file, and stamps every file it looked at -- one it could not read with an empty stamp (headers found; the files stamped, by tail; which stamps are empty)} \
        [list $wsub [lmap f [dict keys $wst] { file tail $f }] [lmap v [dict values $wst] { expr {$v eq {}} }]] \
        [list [dict create blk {{3 2 7}}] {w_top.lib w_in.spice w_none.spice} {0 0 1}]
    set ::pq_walks 0
    rename ::ase::subckt_walk ::ase::pq_real_walk
    proc ::ase::subckt_walk {cards} { incr ::pq_walks ; return [::ase::pq_real_walk $cards] }
    set cds [list [list $f1 tt]]
    set a1 [ase::subckt_lib $cds]
    set a2 [ase::subckt_lib $cds]
    set n2 $::pq_walks
    pd_wr $f2 ".subckt blk 9 8 7\n.ends\n"
    file mtime $f2 [expr {[file mtime $f2] + 5}]
    set a3 [ase::subckt_lib $cds]
    set n3 $::pq_walks
    set a4 [ase::subckt_lib [list [list $f1 ff]]]
    set n4 $::pq_walks
    rename ::ase::subckt_walk {}
    rename ::ase::pq_real_walk ::ase::subckt_walk
    check {PQ13 ase::subckt_lib remembers the walk: asked again for the same cards it does not walk again; it walks again when a file it read has a new mtime, and then answers the new header; and again for another set of cards (first answer, second answer, walks after two calls; the answer and the walks after the file changed; the answer and the walks for the other section)} \
        [list $a1 $a2 $n2 $a3 $n3 $a4 $n4] \
        [list [dict create blk {{3 2 7}}] [dict create blk {{3 2 7}}] 1 [dict create blk {{9 8 7}}] 2 [dict create blk {{7 2 3}}] 3]
    set stc [dict replace $stq includes [list [dict create file q_inc.spice] /abs/inc2.spice {$::pq_no_such_variable/x.spice}] \
                               models [list [dict create file q_lib.spice section tt] [dict create file /abs/m.lib section ss]]]
    check {PQ14 ase::subckt_model_cards: the `includes` rows, then the `models` rows with their section, then the netlist text's own cards, each as {<absolute file> <section>}; a relative path is taken from the run directory; a path naming a variable that is not set is left out; a state with no run directory and no model row answers the text's cards alone} \
        [list [ase::subckt_model_cards $stc ".include deck_inc.spice\n.lib /abs/deck.lib tt\n"] \
              [ase::subckt_model_cards {} ".include /abs/only.spice\n"]] \
        [list [list [list [file normalize [file join $qd q_inc.spice]] {}] {/abs/inc2.spice {}} \
                    [list [file normalize [file join $qd q_lib.spice]] tt] {/abs/m.lib ss} \
                    [list [file normalize [file join $qd deck_inc.spice]] {}] {/abs/deck.lib tt}] \
              {{/abs/only.spice {}}}]
}

# =============================================================================
# PR -- THE RENDERED DECK
# =============================================================================
group PR {
    set outs [pd_outs i(x1.r1:n1) 1 0  i(rtop:n1) 1 1  i(x1.xm1:d) 0 1  -i(x1.m2:b_tj) 1 0  it(x1.q1:c) 0 1 \
                      {i(x1.xr1:r0) i(x1.d1:a) +} 0 0  v(out) 1 0  i(v1) 1 0]
    set st [pd_state pr $outs $::AN_OPTRAN]
    dict set st pre_commands {{cmd {echo pre-command-line}}}
    set deck [pd_deck $st]
    check {PR0 fixture: the deck rendered} [string match ERR:* $deck] 0
    check {PR1 the deck asks for every asked terminal on one `.probe` card of space-separated terms, in pane order, and saves the two non-terminal rows -- no `.save` line holds a `:`} \
        [list [pd_lines $deck {^\.probe}] [pd_lines $deck {^\.save}] [pd_lines $deck {^\.save .*:}]] \
        [list {{.probe I(x1.r1,1) I(rtop,1) I(x1.xm1,d) I(x1.m2,b) I(x1.q1,c) I(x1.xr1,r0) I(x1.d1,a)}} \
              {{.save all} {.save v(out)} {.save i(v1)}} {}]
    set psave -1
    set i 0
    foreach l [split $deck "\n"] { if {[string match {.save *} $l]} { set psave $i } ; incr i }
    check {PR2 the card sits at deck level, below the last `.save` and above `.control` (each bound as a line-number comparison, the anchors present)} \
        [list [expr {$psave >= 0}] [expr {[pd_at $deck {^\.control$}] > 0}] \
              [expr {[pd_at $deck {^\.probe }] > $psave}] \
              [expr {[pd_at $deck {^\.probe }] < [pd_at $deck {^\.control$}]}]] {1 1 1 1}
    set mk "echo [ase::probe_marker] \$?probe_version"
    set at -1
    set n 0
    set i 0
    foreach l [split $deck "\n"] { if {$l eq $mk} { incr n ; set at $i } ; incr i }
    check {PR3 the `.control` block asks the simulator ONCE whether it has the probe extension, behind ase::probe_marker's word: below the pre-command, above `set appendwrite` and above the first analysis (count, the word, then four bounds)} \
        [list $n [ase::probe_marker] [expr {$at > [pd_at $deck {^\.control$}]}] \
              [expr {$at > [pd_at $deck {^echo pre-command-line$}]}] \
              [expr {$at < [pd_at $deck {^set appendwrite$}]}] [expr {$at < [pd_at $deck {^op$}]}]] \
        {1 ASE-PROBE-VERSION 1 1 1 1}
    check {PR4 the echo line trips no keyword-case lint of the control block (ase::deck_case_lint)} \
        [pcall ase::deck_case_lint ngspice $deck] {}

    # NOTHING FOR A BENCH THAT ASKS FOR NO TERMINAL.
    set plain [pd_state pr_plain [pd_outs v(out) 1 0  i(v1) 1 0] $::AN_OPTRAN]
    set unasked [pd_state pr_plain [pd_outs v(out) 1 0  i(v1) 1 0  i(x1.r1:n1) 0 0] $::AN_OPTRAN]
    set dp [pd_deck $plain]
    check {PR5 a bench with no terminal row has no `.probe` card and no capability echo, and a Saves-tab terminal row with NEITHER box ticked changes no byte of that deck (cards, echoes, decks equal)} \
        [list [pd_lines $dp {^\.probe}] [pd_lines $dp {ASE-PROBE}] [string equal $dp [pd_deck $unasked]] \
              [string match ERR:* $dp]] {{} {} 1 0}
    set wh [pd_state pr_wh [pd_outs i(k1:n1) 1 0  i(e9:n1) 1 0] $::AN_OPTRAN]
    set dw [pd_deck $wh $::NLE]
    check {PR6 a bench whose every asked terminal is withheld has no `.probe` card and therefore no echo, and no `.save` card names them; their Save ticks still bring the one save-everything leader} \
        [list [pd_lines $dw {^\.probe}] [pd_lines $dw {ASE-PROBE}] [pd_lines $dw {^\.save}] \
              [string match ERR:* $dw]] {{} {} {{.save all}} 0}
    set po [pd_state pr_po [pd_outs i(x1.r1:n1) 0 1] $::AN_OPTRAN]
    set dpo [pd_deck $po]
    check {PR7 a PLOT-ONLY terminal row gets its card, and the deck then carries no `.save` at all -- the simulator keeps everything} \
        [list [pd_lines $dpo {^\.probe}] [pd_lines $dpo {^\.save}]] {{{.probe I(x1.r1,1)}} {}}

    # A LONG LIST IS SEVERAL CARDS.
    set a {}
    set want {}
    for {set k 1} {$k <= 30} {incr k} {
        lappend a "i(x1.xlongname$k.r1:n1)" 1 0
        lappend want "I(x1.xlongname$k.r1,1)"
    }
    set dl [pd_deck [pd_state pr_long [pd_outs {*}$a] $::AN_OPTRAN]]
    set cards [pd_lines $dl {^\.probe}]
    set terms {}
    set over {}
    set shape {}
    foreach c $cards {
        if {![regexp {^\.probe( I\([^ ,]+,[^ ,]+\))+$} $c]} { lappend shape $c }
        if {[string length $c] > 100 && [llength $c] > 2} { lappend over $c }
        foreach t [lrange $c 1 end] { lappend terms $t }
    }
    check {PR8 thirty terminals are written on several `.probe` cards: every term once and in plan order, space-separated with no comma between two terms, and no card of two or more terms longer than a hundred characters (cards > 1, terms equal, bad shapes, long cards)} \
        [list [expr {[llength $cards] > 1}] [expr {$terms eq $want}] [llength $terms] $shape $over] {1 1 30 {} {}}
    # THE RUN'S OWN CASE MODE reaches the plan the deck is written from.
    set ::sim_case_mode distinguish
    set r9 [catch {pd_deck [pd_state pr_dist [pd_outs i(Rtop:n1) 1 0  i(rlow:n1) 1 0] $::AN_OPTRAN]} dd]
    set ::sim_case_mode fold
    check {PR9 the deck writer plans with the case mode the run requests: under `distinguish` the capital-named top-level device gets no term and the lower-case one keeps its own (render raised, the cards)} \
        [list $r9 [pd_lines $dd {^\.probe}]] {0 {{.probe I(rlow,1)}}}

    # THE SAVE-EVERYTHING LEADER.  A netlist can carry a `.save` of its own --
    # a stock ammeter's `.save i(vmeas)` -- and that card alone narrows the
    # results to what it lists.
    set NLA "* ammeter bench\nV1 g 0 1\nRt g m 1k\nVmeas m 0 0\n.save i(vmeas)\nC1 g 0 1p\n.end\n"
    set an_tran {{type op enabled 0} {type tran enabled 1 stop 10n step 1n}}
    set dt [pd_deck [pd_state pr_amm_t [pd_outs i(rt:n1) 1 0] $an_tran] $NLA]
    set de [pd_deck [pd_state pr_amm_e {} $an_tran] $NLA]
    set dq [pd_deck [pd_state pr_amm_p [pd_outs i(rt:n1) 0 1] $an_tran] $NLA]
    check {PR10 A SAVE-TICKED TERMINAL ROW BRINGS THE LEADER: over a netlist that carries a `.save` of its own, the deck of a bench whose only row is a Save-ticked terminal holds exactly one `.save all`, above its `.probe` card; the same bench with the row PLOT-only keeps its card and gets no leader, like a plot-only voltage row; and with no row at all the deck has neither (the `.save` lines of each deck, leader above the card, the cards of the three)} \
        [list [pd_lines $dt {^\.save}] [pd_lines $dq {^\.save}] [pd_lines $de {^\.save}] \
              [expr {[pd_at $dt {^\.save all$}] >= 0 && [pd_at $dt {^\.save all$}] < [pd_at $dt {^\.probe }]}] \
              [pd_lines $dt {^\.probe}] [pd_lines $dq {^\.probe}] [pd_lines $de {^\.probe}]] \
        [list {{.save i(vmeas)} {.save all}} {{.save i(vmeas)}} {{.save i(vmeas)}} 1 \
              {{.probe I(rt,1)}} {{.probe I(rt,1)}} {}]

    # A ROW THAT IS NO TERMINAL BECAUSE OF A `;`.
    set sc [pd_state pr_semi [pd_outs {i(x1.xm1:d;x)} 0 1  i(x1.r1:n1) 0 1  {i(x1;y:d)} 0 1  i(rtop:n1) 0 1] $::AN_OPTRAN]
    set ds [pd_deck $sc]
    check {PR11 a row with a `;` in its name puts nothing on the `.probe` card, so the terms of the rows behind it are all written and no `.probe` line holds a `;` (the cards, the `.probe` lines holding a `;`, render raised)} \
        [list [pd_lines $ds {^\.probe}] [pd_lines $ds {^\.probe.*;}] [string match ERR:* $ds]] \
        {{{.probe I(x1.r1,1) I(rtop,1)}} {} 0}
    # ...AND BECAUSE OF A DOLLAR SIGN, AN EQUALS SIGN, A QUOTE OR A BRACE.
    set typed [list {i(rtop:$n1)} {i(=rtop:n1)} {i(rtop:1')} {i(rtop:1=)} "i(rtop:1\{)"]
    set a {}
    foreach r [linsert $typed 2 i(x1.r1:n1)] { lappend a $r 0 1 }
    set dc [pd_deck [pd_state pr_cut [pd_outs {*}$a i(rtop:n1) 0 1] $::AN_OPTRAN]]
    check {PR11b five typed rows whose name holds one of those characters put nothing on the `.probe` card: the two good terminals among and behind them are both written, and no `.probe` line holds any of the five characters (the cards, the `.probe` lines holding one, render raised)} \
        [list [pd_lines $dc {^\.probe}] [pd_lines $dc {^\.probe.*[$='{}]}] [string match ERR:* $dc]] \
        {{{.probe I(x1.r1,1) I(rtop,1)}} {} 0}
    set a {}
    foreach r $typed { lappend a $r 1 0 }
    set stg [pd_state pr_cutgate [pd_outs {*}$a i(rtop:n2) 1 0] $::AN_OPTRAN]
    set a {}
    foreach r {i(rtop:n1) i(rtop:n2) i(rtop:1)} { lappend a $r 1 0 }
    set stok [pd_state pr_cutok [pd_outs {*}$a] $::AN_OPTRAN]
    check {PR11c ...and such a row, Save-ticked, is a save the pre-flight refuses BY NAME before the run: the gate raises a refusal and its scan names the five typed rows and not the good terminal beside them; CONTROL the same bench with the characters taken out of the names passes the gate with nothing named (raised a refusal, rows named; then raised, rows named)} \
        [list [string match {ERR:*REFUSED*} [lindex [pd_spy [list ase::preflight_gate $stg $::NLB]] 0]] \
              [expr {[pd_col [ase::state_get [ase::preflight_scan $stg $::NLB] absent] expr] eq $typed}] \
              [string match ERR:* [lindex [pd_spy [list ase::preflight_gate $stok $::NLB]] 0]] \
              [pd_col [ase::state_get [ase::preflight_scan $stok $::NLB] absent] expr]] \
        {1 1 0 {}}
    # AN EXPRESSION THAT READS A NAME NO `.save` CARD CAN CARRY: the rows of
    # `unw`, beside one plain save and one plotted terminal.  `dbase` is the
    # deck of the same bench, same cell, without those rows.
    set unw {}
    foreach n [list {vdc(a=b)} {vdc(a'b)} "vdc(a\{b)" "vdc(a\}b)" {idc(=rtop:n1)} {idc(rtop:1')}] { lappend unw "$n 2 *" 0 0 }
    set du [pd_deck [pd_state pr_unw [pd_outs v(out) 1 0  {*}$unw  i(rtop:n1) 0 1] $::AN_OPTRAN]]
    set dbase [pd_deck [pd_state pr_unw [pd_outs v(out) 1 0  i(rtop:n1) 0 1] $::AN_OPTRAN]]
    set dk [pd_deck [pd_state pr_unwk [pd_outs v(out) 1 0  {vdc(a;b) 2 *} 0 0  {vdc(a$b) 2 *} 0 0  {idc(x;y:d) 2 *} 0 0 \
                                               {idc(rtop:$n1) 2 *} 0 0  {vdc(nosuch) 2 *} 0 0] $::AN_OPTRAN]]
    check {PR11d AN EXPRESSION THAT READS A NAME HOLDING AN EQUALS SIGN, A SINGLE QUOTE OR A BRACE puts no card for that read in the deck: such rows beside one plain save and one plotted terminal leave the deck's `.save` lines at the leader and the plain row's, no `.save` or `.probe` line holds any of those characters, and the deck is BYTE FOR BYTE the deck of the same bench without those rows; while a read of a name holding a `;` or a dollar sign, and of a name the netlist lacks, is written as the `.save` card it always was (the `.save` lines, the lines holding one of the characters, equal to the bench without the rows, render raised; then the `.save` lines of the bench of kept reads)} \
        [list [pd_lines $du {^\.save}] [pd_lines $du {^\.(save|probe).*[='{}]}] [string equal $du $dbase] [string match ERR:* $du] \
              [pd_lines $dk {^\.save}]] \
        [list {{.save all} {.save v(out)}} {} 1 0 \
              {{.save all} {.save v(out)} {.save v(a;b)} {.save v(a$b)} {.save i(x;y:d)} {.save i(rtop:$n1)} {.save v(nosuch)}}]
    set d2 [pd_deck [pd_state pr_twice [pd_outs i(x1.m2:b) 1 0  i(x1.m2:b_tj) 1 0  i(x1.m2:d) 1 0] $::AN_OPTRAN]]
    check {PR12 two rows that name one terminal put its term in the deck ONCE} \
        [pd_lines $d2 {^\.probe}] {{.probe I(x1.m2,b) I(x1.m2,d)}}
    set dn [pd_deck [pd_state pr_num [pd_outs i(x1:99) 1 0  i(x2:7) 0 1  i(x5:7) 1 0] $::AN_OPTRAN] $::NLQ]
    check {PR13 the deck of a bench that asks for numbered subcircuit ports carries their POSITIONS, and the number as it stands for the one whose header is nowhere} \
        [pd_lines $dn {^\.probe}] {{.probe I(x1,3) I(x2,3) I(x5,7)}}
    set stmd [pd_state pr_meas {} $::AN_OPTRAN]
    dict set stmd measurements {{name ipk analysis tran kind max target i(x1.r1:n1)} {name off analysis tran kind max target i(x1.c1:n1) enabled 0}}
    set dm [pd_deck $stmd]
    check {PR14 a bench with NO Outputs row and one enabled measurement over a terminal gets the card, the capability echo and the measurement's own line; the switched-off measurement beside it adds nothing, and nothing is saved by name (cards, echoes, `meas` lines naming the terminal, `.save` lines)} \
        [list [pd_lines $dm {^\.probe}] [llength [pd_lines $dm {ASE-PROBE}]] \
              [llength [pd_lines $dm {^meas tran ipk MAX i\(x1\.r1:n1\)}]] [pd_lines $dm {^\.save}]] \
        {{{.probe I(x1.r1,1)}} 1 1 {}}

    # A `.probe` CARD OF THE NETLIST'S OWN.  A schematic written for this
    # simulator by hand can carry one in a code block.  The netlist text is
    # part of the deck, so every card below is spelled `.PROBE`: the lower-case
    # `.probe` lines of a deck are then the deck writer's alone.
    proc pr_nl {cards} { return [string map [list "R6 e5 0 1k\n" "R6 e5 0 1k\n$cards"] $::NLB] }
    proc pr_own {cards {outs {}} {mode fold}} {
        if {$outs eq {}} { set outs [pd_outs i(rtop:n1) 1 0  i(x1.r1:n1) 1 0] }
        set ::sim_case_mode $mode
        set rc [catch {pd_deck [pd_state pr_own $outs $::AN_OPTRAN] [pr_nl $cards]} d]
        set ::sim_case_mode fold
        if {$rc} { return [list "ERR:$d" {}] }
        return [list [pd_lines $d {^\.probe}] [llength [pd_lines $d {ASE-PROBE}]]]
    }
    set sto [pd_state pr_own [pd_outs i(rtop:n1) 1 0  i(x1.r1:n1) 1 0] $::AN_OPTRAN]
    check {PR15 A TERM THE NETLIST TEXT ALREADY ASKS FOR IS NOT WRITTEN A SECOND TIME: over a netlist holding `.PROBE I(RTOP,1)`, the deck of a bench with rows for that terminal and for one inside the block writes one `.probe` line holding the other term alone, and still asks the capability question once; ase::probe_plan keeps both records with their cards, which is what the run's report is handed; CONTROL the same bench over the netlist without that card writes both terms (the cards and the echoes with the card, the plan's cards, the cards and the echoes without it)} \
        [list [pr_own ".PROBE I(RTOP,1)\n"] \
              [pd_col [ase::probe_plan $sto [pr_nl ".PROBE I(RTOP,1)\n"] fold] card] [pr_own {}]] \
        {{{{.probe I(x1.r1,1)}} 1} {I(rtop,1) I(x1.r1,1)} {{{.probe I(rtop,1) I(x1.r1,1)}} 1}}
    check {PR16 how the netlist's cards are read: a card's `+` continuation lines count, across a comment line between them, and with every term already asked for the deck writes no `.probe` line of its own and still the one echo; a card inside a `.subckt` body counts; a term behind a `;`, behind a dollar sign after a blank, on a `*` comment line, or naming ANOTHER pin of the same device hides nothing (cards and echoes per netlist)} \
        [list [pr_own ".PROBE I(X1.R1,1)\n* a comment between a card and its continuation\n+ I(RTOP,1)\n"] \
              [pr_own ".subckt other a b\n.PROBE I(RTOP,1)\n.ends\n"] \
              [pr_own ".PROBE I(X1.R1,1) ; I(RTOP,1)\n"] \
              [pr_own ".PROBE I(X1.R1,1) \$ I(RTOP,1)\n"] \
              [pr_own "*.PROBE I(RTOP,1) I(X1.R1,1)\n"] \
              [pr_own ".PROBE I(RTOP,2) I(X1.R1,2)\n"]] \
        [list {{} 1} {{{.probe I(x1.r1,1)}} 1} {{{.probe I(rtop,1)}} 1} {{{.probe I(rtop,1)}} 1} \
              {{{.probe I(rtop,1) I(x1.r1,1)}} 1} {{{.probe I(rtop,1) I(x1.r1,1)}} 1}]
    set pres [pd_outs i(Rtop:n1) 1 0  i(x1.R1:n1) 1 0]
    check {PR17 CASE decides by the mode the run requests: under fold a card in another case hides the term (PR15); under `preserve` and under `distinguish` only a card spelled as the deck writer would spell the term does -- an upper-case `I(RTOP,1)` and a `I(X1.r1,1)` hide nothing, `I(rtop,1)` and `I(x1.R1,1)` hide their terms (cards under preserve over each of the two netlists, then under distinguish for a lower-case top-level row)} \
        [list [lindex [pr_own ".PROBE I(RTOP,1) I(X1.r1,1)\n" $pres preserve] 0] \
              [lindex [pr_own ".PROBE I(rtop,1) I(x1.R1,1)\n" $pres preserve] 0] \
              [lindex [pr_own ".PROBE I(RLOW,1)\n" [pd_outs i(rlow:n1) 1 0  i(x1.r1:n1) 1 0] distinguish] 0] \
              [lindex [pr_own ".PROBE I(rlow,1)\n" [pd_outs i(rlow:n1) 1 0  i(x1.r1:n1) 1 0] distinguish] 0]] \
        {{{.probe I(rtop,1) I(x1.R1,1)}} {} {{.probe I(rlow,1) I(x1.r1,1)}} {{.probe I(x1.r1,1)}}}
    check {PR18 the two helpers on their own: ase::probe_netlist_terms gives every `I(<path>,<pin>)` term of the text's `.probe` cards as `<path>,<pin>` in the text's spelling, each once, and nothing for a card of another kind, for a probe with no pin, for a term with a blank inside it, or for a text with no such card; ase::probe_terms_new keeps the order of the terms it is handed and answers them all when the text holds none (the terms read; the empty text; the filtered list; the unfiltered one)} \
        [list [ase::probe_netlist_terms ".probe I(a,1) v(x) I(R2) alli I( c , 1 ) I(a,1)\n.save i(v1,2)\n.Probe I(X1.M2,b)\n+ I(d,2)\n"] \
              [ase::probe_netlist_terms $::NLB] \
              [ase::probe_terms_new {I(q,1) I(a,1) I(x1.m2,b) I(d,1)} ".probe I(A,1)\n.probe I(X1.M2,B)\n" fold] \
              [ase::probe_terms_new {I(q,1) I(a,1)} $::NLB fold]] \
        {{a,1 X1.M2,b d,2} {} {I(q,1) I(d,1)} {I(q,1) I(a,1)}}
}

# =============================================================================
# PL -- THE REPORT, FROM SYNTHETIC LOGS AND RESULTS FILES
# =============================================================================
# The simulator's own lines, copied from real runs (ver_53 and apt 45.2).
set LOG53 "Circuit: ** sch_path: probe bench\n\nprobe: I(x1.nope:1) not inserted: no instance named x1.nope\nprobe: I(xb\[1\]:zz) not inserted: xb\[1\] has no terminal named zz (1 to 3, the ports of blk: in out vss)\n[ase::probe_marker] 1\nDoing analysis at TEMP = 27.000000 and TNOM = 27.000000\n"
set LOG2L "Warning: Node zz is not available for device r5,\n   .probe i(r5,3) will be ignored\n[ase::probe_marker] 1\nNo. of Data Rows : 1\n"
set LOGOLD "Warning: Node out is not available for device x1,\n   .probe i(x1,out) will be ignored\nWarning: Could not find the instance line for x1.xm1,\n   .probe i(x1.xm1,d) will be ignored\nWarning: Could not find the instance line for x1.r1,\n   .probe i(x1.r1,1) will be ignored\n\nCircuit: ** sch_path: probe bench\n\n[ase::probe_marker] 0\nNo. of Data Rows : 1\n"
group PL {
    check {PL1 ase::probe_refusals reads both shapes, keyed on the CARD's path and pin in lower case whichever separator the simulator printed, with the simulator's reason -- for the two-line shape the `Warning:` line directly above, its trailing comma dropped} \
        [list [ase::probe_refusals $::LOG53] [ase::probe_refusals $::LOG2L]] \
        [list [dict create x1.nope,1 {no instance named x1.nope} \
                           {xb[1],zz} {xb[1] has no terminal named zz (1 to 3, the ports of blk: in out vss)}] \
              [dict create r5,3 {Node zz is not available for device r5}]]
    set shuffled "No. of Data Rows : 1\nsomething else\n   .probe i(r5,3) will be ignored\nprobe: I(X1.NOPE:1) not inserted: no instance named X1.NOPE\n"
    check {PL2 BY CONTENT: the same lines found below the analysis output, and a two-line refusal whose line above is not a `Warning:` keeps the refusal with no reason; the key is lower-cased} \
        [ase::probe_refusals $shuffled] [dict create r5,3 {} x1.nope,1 {no instance named X1.NOPE}]
    check {PL3 a refusal printed three times, as a deck that reloads the circuit prints it, is one refusal} \
        [dict size [ase::probe_refusals "$::LOG2L$::LOG2L$::LOG2L"]] 1

    # ---- refused -----------------------------------------------------------
    set st [pd_state pl_ref [pd_outs i(x1.nope:n1) 1 0  {i(xb[1]:zz)} 1 0  i(r5:n3) 1 0] $::AN_OP]
    lassign [pd_report $st "$::LOG53$::LOG2L"] recs said
    check {PL4 each refused terminal is reported once, in plan order, matched on the card -- the row `i(r5:n3)` to the simulator's `i(r5,3)`, the row `i(x1.nope:n1)` to its `I(x1.nope:1)` -- and each record is one spoken line (kinds, lines spoken, spoken lines equal the records' sentences, none empty)} \
        [list [pd_kinds $recs] [llength $said] [expr {[pd_nth $said 1] eq [pd_nth $recs 2]}] [expr {[lsearch -exact [pd_nth $said 1] {}] < 0}]] \
        [list {{refused i(x1.nope:n1)} {refused {i(xb[1]:zz)}} {refused i(r5:n3)}} 3 1 1]
    check {PL5 the sentence names the row's vector, the card and the simulator's own reason (the whole line for the two-line shape)} \
        [lindex [lindex $recs 2] 2] \
        {ase: the simulator refused the terminal current i(r5:n3) (.probe I(r5,3)): Node zz is not available for device r5.}
    check {PL5b a refusal with no reason line above it is still one whole sentence} \
        [pd_nth [lindex [pd_report [pd_state pl_ref [pd_outs i(r5:n3) 1 0] $::AN_OP] "No. of Data Rows : 1\n   .probe i(r5,3) will be ignored\n"] 0] 2] \
        [list {ase: the simulator refused the terminal current i(r5:n3) (.probe I(r5,3)): it gave no reason.}]
    lassign [pd_report [pd_state pl_refcase [pd_outs i(X1.XM1:D) 1 0] $::AN_OP] [string map [list "[ase::probe_marker] 0" "[ase::probe_marker] 1"] $::LOGOLD] 0 {} preserve] recs said
    check {PL6 the match folds case: a preserve run's upper-case row finds the lower-case line the simulator printed (the two-line refusals of LOGOLD, behind an answer of 1 so that the refusal keeps its own record)} \
        [pd_kinds $recs] {{refused i(X1.XM1:D)}}
    set ::pl_scans 0
    rename ::ase::probe_refusals ::pl_real_refusals
    proc ::ase::probe_refusals {logtext} { incr ::pl_scans ; return [::pl_real_refusals $logtext] }
    set r7 [catch {pd_report [pd_state pl_none [pd_outs v(out) 1 0] $::AN_OP] "$::LOG53$::LOG2L$::LOGOLD"} got7]
    set none $::pl_scans
    catch {pd_report [pd_state pl_ref [pd_outs i(r5:n3) 1 0] $::AN_OP] $::LOG2L}
    rename ::ase::probe_refusals {}
    rename ::pl_real_refusals ::ase::probe_refusals
    check {PL7 a run that asked for no terminal says nothing, whatever refusals the log holds (a `.probe` of the user's own netlist is not ASE-L's to report), and does not read the log at all -- which a run that asked for one does, once (raised, records and lines, log scans for none, log scans after one asking run)} \
        [list $r7 $got7 $none $::pl_scans] {0 {{} {}} 0 1}

    # ---- withheld ----------------------------------------------------------
    lassign [pd_report [pd_state pl_wh [pd_outs i(k1:n1) 1 0  i(e9:n1) 1 0  i(e5:n3) 1 0] $::AN_OP] {} 0 $::NLE] recs said
    check {PL8 a card ASE-L withheld is reported with its reason and the ammeter alternative, one line each (kinds, then the K line whole, then every line ending in the alternative)} \
        [list [pd_kinds $recs] [lindex [lindex $recs 0] 2] \
              [llength [lsearch -all -glob [pd_nth $recs 2] {*To measure it, place an ammeter (ammeter.sym) in series.}]]] \
        [list {{withheld i(k1:n1)} {withheld i(e9:n1)} {withheld i(e5:n3)}} \
              {ase: no probe was written for the terminal current i(k1:n1): k1 is a coupling between inductors and has no terminal. To measure it, place an ammeter (ammeter.sym) in series.} 3]
    check {PL9 the two E reasons say which rule withheld the card: the short card, and the pin an expression source does not have} \
        [list [string match {*i(e9:n1): e9 is a source written as an expression on a card of fewer than six words*} [lindex [lindex $recs 1] 2]] \
              [string match {*i(e5:n3): e5 is a source written as an expression, which has two terminals*} [lindex [lindex $recs 2] 2]]] {1 1}
    lassign [pd_report [pd_state pl_dist [pd_outs i(Rtop:n1) 1 0] $::AN_OP] {} 0 {} distinguish] recs said
    check {PL10 ...and the `distinguish` withholding says it is the case mode} \
        [list [pd_kinds $recs] [string match {*this run asks the simulator to distinguish case*which Rtop is not.*} [lindex [lindex $recs 0] 2]]] \
        {{{withheld i(Rtop:n1)}} 1}

    # ---- missing: which plots can say so -----------------------------------
    set two [pd_outs i(x1.r1:n1) 1 0  i(rtop:n1) 1 0]
    set st [pd_state pl_op $two $::AN_OP]
    pd_raw [pd_rawpath $st] {{{Operating Point} {v(out) i(v1) i(rtop:n1)}}}
    pd_map $st {{op 0 {Operating Point}}}
    lassign [pd_report $st "[ase::probe_marker] 1\n"] recs said
    check {PL11 a card that was written, drew no refusal and left no vector in the operating-point plot is reported missing; the terminal the plot holds is not (kinds, then the whole line)} \
        [list [pd_kinds $recs] [pd_nth $said 1]] \
        [list {{missing i(x1.r1:n1)}} [list {ase: the terminal current i(x1.r1:n1) is not in this run's results: the deck asked for it (.probe I(x1.r1,1)) and the simulator neither made the vector nor said why.}]]
    pd_raw [pd_rawpath $st] {{{Operating Point} {v(out) I(X1.R1:N1) i(rtop:n1)}}}
    set up [pd_state pl_op [pd_outs i(X1.R1:N1) 1 0  i(x1:out) 1 0] $::AN_OP]
    set lowfile [apply {{st up} {
        pd_raw [pd_rawpath $st] {{{Operating Point} {v(out) i(x1.r1:n1) i(x1:out)}}}
        return [lindex [pd_report $up "[ase::probe_marker] 1\n" 0 {} preserve] 0] }} $st $up]
    pd_raw [pd_rawpath $st] {{{Operating Point} {v(out) I(X1.R1:N1) i(rtop:n1)}}}
    check {PL12 the vector is looked for without case on BOTH sides: an upper-case file satisfies a lower-case row and a lower-case file satisfies a preserve run's upper-case row; a plot that holds every asked vector is silence} \
        [list [lindex [pd_report $st "[ase::probe_marker] 1\n"] 0] $lowfile] {{} {}}
    pd_raw [pd_rawpath $st] {{{Operating Point} {v(out) i(v1)}}}
    check {PL13 the vector test is skipped on a nonzero exit, and when the plot sidecar or the results file is absent: none of the three says a vector is missing (exit 1, no sidecar, no results file)} \
        [list [lindex [pd_report $st {} 1] 0] \
              [apply {{st} { file delete [ase::plotmap_path $st] ; return [lindex [pd_report $st {}] 0] }} $st] \
              [apply {{st} { pd_map $st {{op 0 {Operating Point}}} ; file delete [pd_rawpath $st] ; return [lindex [pd_report $st {}] 0] }} $st]] \
        {{} {} {}}
    check {PL14 ...while a refusal in the log of a failed run is still reported (exit 1)} \
        [pd_kinds [lindex [pd_report [pd_state pl_ref [pd_outs i(r5:n3) 1 0] $::AN_OP] $::LOG2L 1] 0]] \
        {{refused i(r5:n3)}}

    # A noise-only bench: neither of its plots can hold a probe.
    set stn [pd_state pl_noise $two {{type noise enabled 1 source v1}}]
    pd_raw [pd_rawpath $stn] {{{Integrated Noise} {v(onoise_total) v(inoise_total)}} {{Noise Spectral Density Curves} {frequency v(onoise_spectrum)}}}
    pd_map $stn {{noise 0 {Integrated Noise}} {noise 0 {Noise Spectral Density Curves}}}
    lassign [pd_report $stn "[ase::probe_marker] 1\n"] recs said
    check {PL15 A NOISE-ONLY BENCH: a noise plot never holds a probe, so no terminal is called missing -- and the run says ONE note instead, which names both asked terminals, says why they are in no plot and which analyses would keep them (kinds, the note whole, the tags)} \
        [list [pd_kinds $recs] [lindex [lindex $recs 0] 2] [pd_nth $said 0]] \
        [list {{note {}}} \
              {ase: the terminal currents i(x1.r1:n1), i(rtop:n1) are not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.} \
              note]
    # The same file and sidecar under each of the other three kinds of analysis
    # that keep no probed vector, with one row asked: the sidecar's type word is
    # the bench's.
    set kinds {}
    foreach ty {tf pz sens} {
        set s1 [pd_state pl_blind_$ty [pd_outs i(rtop:n1) 0 1  v(out) 1 0] [list [list type $ty enabled 1] {type op enabled 0}]]
        pd_raw [pd_rawpath $s1] {{{Some Plot} {v(a_vector_of_its_own)}}}
        pd_map $s1 [list [list $ty 0 {Some Plot}]]
        lappend kinds [pd_nth [lindex [pd_report $s1 "[ase::probe_marker] 1\n"] 0] 2]
    }
    check {PL15b the same note for a bench whose one enabled analysis is `tf`, `pz` or `sens` (a switched-off `op` beside it does not count), with ONE asked terminal in the singular (the sentences of the three benches)} \
        $kinds [lrepeat 3 [list {ase: the terminal current i(rtop:n1) is not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.}]]
    # WHICH ROWS THE NOTE NAMES.  A terminal whose card the log refused keeps
    # its refusal, one ASE-L withheld keeps that sentence, and one a plot of the
    # file holds under ANY wrapper is left out: a `sens` plot lists the probe's
    # own source as `v(<device>:<pin>)`, and for such a row the note about rows
    # with no single-point value speaks.
    set stm [pd_state pl_noise_mix [pd_outs i(x1.nope:n1) 1 0  i(k1:n1) 1 0  i(rtop:n1) 1 0  i(x1.r1:n1) 1 0  i(x1.r2:n1) 0 1] \
               {{type sens enabled 1 out v(out)} {type noise enabled 1 source v1}}]
    pd_raw [pd_rawpath $stm] {{{Sensitivity Analysis} {v(rtop) v(rtop:n1)}} {{Integrated Noise} {v(onoise_total)}}}
    pd_map $stm {{sens 0 {Sensitivity Analysis}} {noise 1 {Integrated Noise}}}
    lassign [pd_report $stm "probe: I(x1.nope:1) not inserted: no instance named x1.nope\n[ase::probe_marker] 1\n"] recs said
    check {PL15c THE NOTE NAMES ONLY THE ROWS NOTHING ELSE SPEAKS FOR: on a `sens` + `noise` bench the refused terminal keeps its refusal and the withheld one its sentence, the terminal the sensitivity plot holds as a `v()` vector of the same name is left out, and the note names the two that are in no plot, in plan order (kinds; which rows the note names)} \
        [list [pd_kinds $recs] [regexp -inline {currents (.*) are not in} [lindex [lindex $recs end] 2]]] \
        [list {{refused i(x1.nope:n1)} {withheld i(k1:n1)} {note {}}} \
              {{currents i(x1.r1:n1), i(x1.r2:n1) are not in} {i(x1.r1:n1), i(x1.r2:n1)}}]
    # WHEN THE NOTE IS NOT SAID.  Each bench below has the noise-only bench's
    # two rows; the first leg is that bench itself, as the control.
    proc pl_blind {tag analyses plots map {rc 0}} {
        set st [pd_state pl_nb_$tag [pd_outs i(x1.r1:n1) 1 0  i(rtop:n1) 1 0] $analyses]
        if {$plots ne {-}} { pd_raw [pd_rawpath $st] $plots }
        if {$map ne {-}} { pd_map $st $map }
        return [pd_kinds [lindex [pd_report $st "[ase::probe_marker] 1\n" $rc] 0]]
    }
    set NP {{{Integrated Noise} {v(onoise_total) v(inoise_total)}}}
    set NM {{noise 0 {Integrated Noise}}}
    set NA {type noise enabled 1 source v1}
    set SPA {type sp enabled 1 points 3 start 100meg stop 1g}
    check {PL15d ...AND NOTHING ELSE BRINGS IT: CONTROL the noise-only bench says it; the same bench says nothing when the plot sidecar is absent, when the results file is absent, and at a nonzero exit; nothing with an `sp` analysis enabled, alone or beside the noise (an `sp` plot holds a probed vector, so its lacking one is no such evidence); nothing when no analysis is enabled; nothing when every asked terminal is in a plot of the file; and where a plot WAS judged -- a sidecar that calls the noise plot an operating point's -- the two terminals are missing and no note is added (kinds per bench)} \
        [list [pl_blind ctl [list $NA] $NP $NM] \
              [pl_blind nomap [list $NA] $NP -] [pl_blind noraw [list $NA] - $NM] [pl_blind rc1 [list $NA] $NP $NM 1] \
              [pl_blind sp [list $SPA] {{{SP Analysis} {frequency S_1_1 i(v1)}}} {{sp 0 {SP Analysis}}}] \
              [pl_blind spn [list $SPA $NA] [concat $NP {{{SP Analysis} {frequency S_1_1 i(v1)}}}] {{noise 1 {Integrated Noise}} {sp 0 {SP Analysis}}}] \
              [pl_blind off [list {type noise enabled 0 source v1}] $NP $NM] \
              [pl_blind held [list $NA] {{{Integrated Noise} {v(onoise_total) i(x1.r1:n1) I(RTOP:N1)}}} $NM] \
              [pl_blind judged [list $NA] $NP {{op 0 {Integrated Noise}}}]] \
        {{{note {}}} {} {} {} {} {} {} {} {{missing i(x1.r1:n1)} {missing i(rtop:n1)}}}

    # ---- a design-variable sweep beside those analyses ------------------------
    # Such a sweep's plot holds what its loop copies and never a probe, so the
    # bench is still one whose every analysis keeps no terminal current.  Each
    # bench: the state, its results file and sidecar written here, the report.
    # -> {state records said}
    proc pl_swept {tag outs analyses plots map {rc 0}} {
        set st [pd_state pl_sw_$tag $outs $analyses]
        dict set st variables {{name rv value 1k} {name rw value 2k}}
        if {$plots ne {-}} { pd_raw [pd_rawpath $st] $plots }
        if {$map ne {-}} { pd_map $st $map }
        return [list $st {*}[pd_report $st "[ase::probe_marker] 1\n" $rc]]
    }
    # the rows of a report's last record that its sentence names
    proc pl_named {recs} {
        if {![regexp {currents? (.*) (?:is|are) not in this run's results} [lindex [lindex $recs end] 2] -> rows]} { return NONE }
        return $rows
    }
    set DV {type dc enabled 1 swkind variable source rv start 500 stop 1500 step 500}
    set DV2 {type dc enabled 1 swkind variable source rw start 1k stop 3k step 1k}
    set DVP {{DC transfer characteristic} {rv v(in) v(out) i(v1)}}
    set DVP2 {{DC transfer characteristic} {rw v(in) v(out) i(v1)}}
    set OWN {{Some Plot} {v(a_vector_of_its_own)}}
    lassign [pl_swept noise $two [list $DV $NA] [concat [list $DVP] $NP] {{dc 0 {DC transfer characteristic}} {noise 1 {Integrated Noise}}}] stw recs said
    set others {}
    foreach ty {tf pz sens} {
        lappend others [pd_nth [lindex [pl_swept $ty $two [list $DV [list type $ty enabled 1]] [list $DVP $OWN] \
                                           [list {dc 0 {DC transfer characteristic}} [list $ty 1 {Some Plot}]]] 1] 2]
    }
    lappend others [pd_nth [lindex [pl_swept first $two [list $NA $DV] [concat $NP [list $DVP]] {{noise 0 {Integrated Noise}} {dc 1 {DC transfer characteristic}}}] 1] 2]
    check {PL15e A DESIGN-VARIABLE SWEEP BESIDE A NOISE ANALYSIS: the sweep's plot holds no probe either, so the run says the ONE note all the same, in a sentence that names the sweep, for both asked terminals, spoken as a note; and the same sentence beside a `tf`, a `pz` and a `sens` analysis, and with the noise row standing before the sweep's. FIXTURE the `dc` row is a design-variable sweep to the adapter (fixture; kinds, the note whole, the tags; the distinct sentences of the other benches)} \
        [list [expr {[ase::backend::ngspice::dcvar_plan $stw $DV 0] ne {}}] \
              [pd_kinds $recs] [lindex [lindex $recs 0] 2] [pd_nth $said 0] [lsort -unique $others]] \
        [list 1 {{note {}}} \
              {ase: the terminal currents i(x1.r1:n1), i(rtop:n1) are not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses beside a sweep of a design variable, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.} \
              note \
              [list [list {ase: the terminal currents i(x1.r1:n1), i(rtop:n1) are not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses beside a sweep of a design variable, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.}]]]
    lassign [pl_swept two [pd_outs i(rtop:n1) 0 1] [list $DV $DV2 $NA] [concat [list $DVP $DVP2] $NP] \
                 {{dc 0 {DC transfer characteristic}} {dc 1 {DC transfer characteristic}} {noise 2 {Integrated Noise}}}] st2 recs2 said2
    lassign [pl_swept off $two [list [dict replace $DV enabled 0] $NA] $NP $NM] sto recso saido
    check {PL15e2 the sentence counts the sweeps and names none that is switched off: with TWO design-variable sweeps beside the noise it says so in the plural, for one asked terminal in the singular; with the sweep row switched off it is the noise-only sentence, with no word about a sweep (the two-sweep note whole; the kinds and the note of the switched-off bench)} \
        [list [pd_nth $recs2 2] [pd_kinds $recso] [lindex [lindex $recso 0] 2]] \
        [list [list {ase: the terminal current i(rtop:n1) is not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses beside sweeps of design variables, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.}] \
              {{note {}}} \
              {ase: the terminal currents i(x1.r1:n1), i(rtop:n1) are not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.}]

    # WHEN A SWEEP BRINGS NO NOTE.  The same two rows in every bench.
    set DVM {{dc 0 {DC transfer characteristic}}}
    lassign [pl_swept alone $two [list $DV] [list $DVP] $DVM] sta recsa saida
    lassign [pl_swept pair $two [list $DV $DV2] [list $DVP $DVP2] {{dc 0 {DC transfer characteristic}} {dc 1 {DC transfer characteristic}}}] stp recsp saidp
    set COMP {type dc enabled 1 source v1 start 0 stop 1 step 0.5}
    check {PL15f ...AND A SWEEP WITH NONE OF THE FOUR BESIDE IT BRINGS NOTHING: alone, the report is silent and the sweep's OWN advice names both rows (fixture: the adapter's advice for that bench); two design-variable sweeps and nothing else are silent too -- there neither sweep is the bench's one analysis, so the advice names no row either, which leaves those rows without a sentence; nothing with an `sp` analysis beside the sweep; nothing beside the noise at a nonzero exit or without the plot sidecar; with an operating point beside sweep and noise the op plot is judged, and the two terminals it lacks are missing, with no note; and with a sweep of a SOURCE beside them, whose plot holds both terminals, nothing is said; and a sweep of a source is never taken for one of a design variable: beside the noise alone its plot is judged, and the terminals it lacks are missing (the report and the advised rows for the sweep alone; the report and each sweep's advised rows for the pair; then the kinds of the other benches in turn)} \
        [list [list $recsa [pd_nth [pcall ase::backend::ngspice::dcvar_output_refusals $sta $DV] 0]] \
              [list $recsp [pcall ase::backend::ngspice::dcvar_output_refusals $stp $DV] [pcall ase::backend::ngspice::dcvar_output_refusals $stp $DV2]] \
              [pd_kinds [lindex [pl_swept sp $two [list $DV $SPA] [list $DVP {{SP Analysis} {frequency S_1_1 i(v1)}}] {{dc 0 {DC transfer characteristic}} {sp 1 {SP Analysis}}}] 1]] \
              [pd_kinds [lindex [pl_swept rc1 $two [list $DV $NA] [concat [list $DVP] $NP] {{dc 0 {DC transfer characteristic}} {noise 1 {Integrated Noise}}} 1] 1]] \
              [pd_kinds [lindex [pl_swept nomap $two [list $DV $NA] [concat [list $DVP] $NP] -] 1]] \
              [pd_kinds [lindex [pl_swept op $two [list {type op enabled 1} $DV $NA] [concat {{{Operating Point} {v(out) i(v1)}}} [list $DVP] $NP] \
                                    {{op 0 {Operating Point}} {dc 1 {DC transfer characteristic}} {noise 2 {Integrated Noise}}}] 1]] \
              [pd_kinds [lindex [pl_swept comp $two [list $DV $COMP $NA] [concat [list $DVP {{DC transfer characteristic} {v(v-sweep) v(out) i(x1.r1:n1) i(rtop:n1)}}] $NP] \
                                    {{dc 0 {DC transfer characteristic}} {dc 1 {DC transfer characteristic}} {noise 2 {Integrated Noise}}}] 1]] \
              [pd_kinds [lindex [pl_swept src $two [list $COMP $NA] [concat {{{DC transfer characteristic} {v(v-sweep) v(out) i(v1)}}} $NP] \
                                    {{dc 0 {DC transfer characteristic}} {noise 1 {Integrated Noise}}}] 1]]] \
        [list {{} {i(x1.r1:n1) i(rtop:n1)}} {{} {} {}} {} {} {} {{missing i(x1.r1:n1)} {missing i(rtop:n1)}} {} \
              {{missing i(x1.r1:n1)} {missing i(rtop:n1)}}]

    # WHO SPEAKS FOR WHICH ROW.  Beside another analysis the sweep's own advice
    # speaks only for a row that reads the sweep by its qualifier (`is(...)`).
    # Row by row: an unqualified terminal; a qualified one, typed with blanks
    # around it, that no other row asks for; an unqualified one in capitals
    # and, below it, the same terminal read by qualifier; a qualified
    # expression; a node.
    set who [pd_outs i(x1.r1:n1) 1 0  { is(rtop:n1) } 0 0  I(X1.R2:N1) 0 1  is(x1.r2:n1) 0 0  {is(x1.r3:n1) 2 *} 0 0  v(out) 1 0]
    lassign [pl_swept who $who [list $DV $NA] [concat [list $DVP] $NP] {{dc 0 {DC transfer characteristic}} {noise 1 {Integrated Noise}}}] sth recsh saidh
    lassign [pl_swept who_off $who [list [dict replace $DV enabled 0] $NA] $NP $NM] sth0 recsh0 saidh0
    lassign [pl_swept who_sens [pd_outs i(rtop:n1) 1 0  i(x1.r1:n1) 1 0] [list $DV {type sens enabled 1 out v(out)}] \
                 [list $DVP {{Sensitivity Analysis} {v(rtop) v(rtop:n1)}}] {{dc 0 {DC transfer characteristic}} {sens 1 {Sensitivity Analysis}}}] sths recshs saidhs
    set hplan [ase::probe_plan $sth $::NLB fold]
    check {PL15g NO ROW IS SPOKEN FOR TWICE: beside a noise analysis the sweep's own advice speaks for the rows that read the sweep by their qualifier, and the note names exactly the terminals some OTHER row asks for -- the unqualified one, and the one an unqualified row in capitals asks for although a qualified row reads it too, under the spelling asked first -- and leaves those that only qualified rows ask for to that advice. FIXTURE every terminal of the bench is in the plan with a card, so the ones left out were asked for. CONTROL the same bench with the sweep switched off names them all; and with a `sens` analysis beside the sweep the terminal that plot holds as a `v()` vector of the same name is left out as it is with no sweep (the plan's signals and how many have a card; the rows the adapter's advice names; kinds, the terminals the note names; the control's; the sens bench's)} \
        [list [pd_col $hplan signal] [llength [lsearch -all -not -exact [pd_col $hplan card] {}]] \
              [pd_nth [pcall ase::backend::ngspice::dcvar_output_refusals $sth $DV] 0] \
              [pd_kinds $recsh] [pl_named $recsh] [pl_named $recsh0] [pl_named $recshs]] \
        [list {i(x1.r1:n1) i(rtop:n1) i(X1.R2:N1) i(x1.r3:n1)} 4 \
              {is(rtop:n1) is(x1.r2:n1) {is(x1.r3:n1) 2 *}} \
              {{note {}}} {i(x1.r1:n1), i(X1.R2:N1)} {i(x1.r1:n1), i(rtop:n1), i(X1.R2:N1), i(x1.r3:n1)} i(x1.r1:n1)]
    check {PL15h ase::probe_asked on its own: the terminals a bench asks for in asking order with duplicates kept -- a Saves row only with a box ticked, a Measures row always -- and, handed the texts of rows to pass over, the same list without what those rows read; a text that is no row's changes nothing (all rows; without the qualified rows; with a stranger's text; a bench whose Saves row has no box ticked)} \
        [list [pcall ase::probe_asked $sth] \
              [pcall ase::probe_asked $sth [dict create is(rtop:n1) 1 is(x1.r2:n1) 1 {is(x1.r3:n1) 2 *} 1]] \
              [pcall ase::probe_asked $sth [dict create v(nosuch) 1]] \
              [pcall ase::probe_asked [pd_state pl_asked_off [pd_outs i(rtop:n1) 0 0  it(rtop:n2) 0 0] $::AN_OP]]] \
        [list {i(x1.r1:n1) i(rtop:n1) i(X1.R2:N1) i(x1.r2:n1) i(x1.r3:n1)} \
              {i(x1.r1:n1) i(X1.R2:N1)} \
              {i(x1.r1:n1) i(rtop:n1) i(X1.R2:N1) i(x1.r2:n1) i(x1.r3:n1)} \
              i(rtop:n2)]
    # op + noise: the op plot alone is judged.  The noise plot here HOLDS a
    # vector of the asked name, which must not rescue the terminal.
    set ston [pd_state pl_opnoise $two {{type op enabled 1} {type noise enabled 1 source v1}}]
    pd_raw [pd_rawpath $ston] {{{Operating Point} {v(out) i(rtop:n1)}} {{Integrated Noise} {v(onoise_total) i(x1.r1:n1)}}}
    pd_map $ston {{op 0 {Operating Point}} {noise 1 {Integrated Noise}}}
    check {PL16 an OP + NOISE bench is judged on its operating-point plot alone: a terminal absent there is missing even though the noise plot holds a vector of that name, and the terminal the op plot holds is not reported} \
        [pd_kinds [lindex [pd_report $ston "[ase::probe_marker] 1\n"] 0]] {{missing i(x1.r1:n1)}}
    # A design-variable sweep against the same plot written by a component sweep.
    set dvrow {type dc enabled 1 swkind variable source rv start 500 stop 1500 step 500}
    set stv [pd_state pl_dcvar $two [list $dvrow]]
    dict set stv variables {{name rv value 1k}}
    pd_raw [pd_rawpath $stv] {{{DC transfer characteristic} {rv v(in) v(out) i(v1)}}}
    pd_map $stv {{dc 0 {DC transfer characteristic}}}
    set stc [pd_state pl_dccomp $two {{type dc enabled 1 source v1 start 0 stop 1 step 0.5}}]
    pd_raw [pd_rawpath $stc] {{{DC transfer characteristic} {v(v-sweep) v(in) v(out) i(v1)}}}
    pd_map $stc {{dc 0 {DC transfer characteristic}}}
    check {PL17 a DESIGN-VARIABLE SWEEP says nothing about missing vectors (its plot holds only what its loop copies), while the same plot written by a component `dc` sweep reports both terminals -- fixture: the first row IS a design-variable sweep to the adapter and the second is not} \
        [list [lindex [pd_report $stv "[ase::probe_marker] 1\n"] 0] \
              [pd_kinds [lindex [pd_report $stc "[ase::probe_marker] 1\n"] 0]] \
              [expr {[ase::backend::ngspice::dcvar_plan $stv $dvrow 0] ne {}}] \
              [expr {[ase::backend::ngspice::dcvar_plan $stc [lindex [dict get $stc analyses] 0] 0] ne {}}]] \
        {{} {{missing i(x1.r1:n1)} {missing i(rtop:n1)}} 1 0}
    # A plot whose sidecar record names another plot is not judged.
    pd_map $stc {{dc 0 {Some Other Plot}}}
    check {PL18 a plot the sidecar does not name position for position is not judged} \
        [lindex [pd_report $stc "[ase::probe_marker] 1\n"] 0] {}

    # ---- states and backends the lookups cannot be made for -----------------
    set orphan [dict create probes [ase::probe_plan [pd_state pl_op [pd_outs i(x1.r1:n1) 1 0] $::AN_OP] $::NLB fold]]
    check {PL23 a state with no design cell, whose results file cannot be located, gets no raise and no missing-vector sentence} \
        [pcall ase::probe_report [ase::state_default] $orphan {} 0] {}
    set hk [dict get $::ase::backends ngspice]
    ase::register_backend pdmin [dict create render_deck [dict get $hk render_deck] run_cmd [dict get $hk run_cmd] \
        log_file [dict get $hk log_file] result_probe [dict get $hk result_probe] raw_file [dict get $hk raw_file]]
    set stm [pd_state pl_min $two $::AN_OP]
    dict set stm simulator pdmin
    pd_raw [pd_rawpath $stm] {{{Operating Point} {v(out) i(rtop:n1)}}}
    pd_map $stm {{op 0 {Operating Point}}}
    check {PL24 a backend that declares no design-variable-sweep hook is judged like any other: the missing terminal is reported and nothing raises} \
        [pd_kinds [lindex [pd_report $stm "[ase::probe_marker] 1\n"] 0]] {{missing i(x1.r1:n1)}}

    # ---- the build that saves no terminal below the top level -----------------
    # (the report's `hier` record; who can save it instead is band PH's)
    set sto [pd_state pl_old [pd_outs i(x1:out) 1 0  i(x1.xm1:d) 1 0  i(x1.r1:n1) 1 0  i(rtop:n1) 1 0] $::AN_OP]
    pd_raw [pd_rawpath $sto] {{{Operating Point} {v(out) i(v1) i(rtop:n1)}}}
    pd_map $sto {{op 0 {Operating Point}}}
    lassign [pd_report $sto $::LOGOLD] recs said
    set said19 $said
    check {PL19 a build that answers 0: the three terminals it refused -- a pin of a subcircuit instance and two devices inside one -- are ONE record of kind `hier` whose second word is the list of them in plan order, in place of three refusals in the simulator's own words; the top-level device it did probe is not reported; and that one record is one spoken line, which names the program as the run's record does, says what such a build saves and ends with the cure (kinds, the line whole, lines spoken, the spoken line is the record's)} \
        [list [pd_kinds $recs] [lindex [lindex $recs end] 2] [llength $said] [expr {[pd_nth $said 1] eq [pd_nth $recs 2]}]] \
        [list {{hier {i(x1:out) i(x1.xm1:d) i(x1.r1:n1)}}} \
              [pd_hier {the terminal currents i(x1:out), i(x1.xm1:d) and i(x1.r1:n1)}] 1 1]
    set lognomark [string map [list "[ase::probe_marker] 0\n" {}] $::LOGOLD]
    check {PL20 that record is made only for a 0 answer AND a terminal that needs the hierarchy refused or missing: the same refusals behind a 1 keep their three records, a 0 with every asked vector present says nothing, a 0 where the only thing to say is a card ASE-L itself withheld says only that -- and the same refusals in a log that holds NO answer to the question keep their three records too: a program whose log never answered is not told what it cannot do (kinds of each; fixture for the last: the log holds the refusals and no line of the marker's word)} \
        [list [pd_kinds [lindex [pd_report $sto [string map [list "[ase::probe_marker] 0" "[ase::probe_marker] 1"] $::LOGOLD]] 0]] \
              [lindex [pd_report [pd_state pl_old [pd_outs i(rtop:n1) 1 0] $::AN_OP] $::LOGOLD] 0] \
              [pd_kinds [lindex [pd_report [pd_state pl_old [pd_outs i(k1:n1) 1 0  i(rtop:n1) 1 0] $::AN_OP] "[ase::probe_marker] 0\n" 0 $::NLE] 0]] \
              [pd_kinds [lindex [pd_report $sto $lognomark] 0]] \
              [list [regexp -all {will be ignored} $lognomark] [string first [ase::probe_marker] $lognomark]]] \
        [list {{refused i(x1:out)} {refused i(x1.xm1:d)} {refused i(x1.r1:n1)}} {} {{withheld i(k1:n1)}} \
              {{refused i(x1:out)} {refused i(x1.xm1:d)} {refused i(x1.r1:n1)}} {3 -1}]
    pd_raw [pd_rawpath $sto] {{{Operating Point} {v(out) i(v1)}}}
    lassign [pd_report [pd_state pl_old [pd_outs i(rtop:n1) 1 0  i(r5:n3) 1 0] $::AN_OP] "$::LOG2L[ase::probe_marker] 0\n"] recs21 said21
    check {PL21 A TOP-LEVEL DEVICE THAT IS NO SUBCIRCUIT INSTANCE KEEPS ITS OWN SENTENCE ON A BUILD THAT ANSWERS 0, and nothing is added for it: such a build probes it, so the build is not the cause -- one whose vector is missing with no refusal line, and one the simulator refused with a reason of its own (kinds; the refusal's line whole)} \
        [list [pd_kinds $recs21] [lindex [lindex $recs21 1] 2]] \
        [list {{missing i(rtop:n1)} {refused i(r5:n3)}} \
              {ase: the simulator refused the terminal current i(r5:n3) (.probe I(r5,3)): Node zz is not available for device r5.}]
    lassign [pd_report $sto "[ase::probe_marker] 0\n"] recs21b said21b
    check {PL21b ...while a terminal that needs the hierarchy and is MISSING on such a build, with no refusal line in the log, joins the `hier` record like a refused one: here all three are missing, the top-level resistor beside them keeps its `missing` record, and the `hier` record stands where the first of its terminals stood in the plan -- ahead of the resistor's (kinds; the hier line)} \
        [list [pd_kinds $recs21b] [lindex [lindex $recs21b 0] 2]] \
        [list {{hier {i(x1:out) i(x1.xm1:d) i(x1.r1:n1)}} {missing i(rtop:n1)}} \
              [pd_hier {the terminal currents i(x1:out), i(x1.xm1:d) and i(x1.r1:n1)}]]
    lassign [pd_report [pd_state pl_old [pd_outs i(rtop:n1) 1 0  i(k1:n1) 1 0  i(x1.xm1:d) 1 0] $::AN_OP] $::LOGOLD 0 $::NLE] recs21c said21c
    check {PL21c the `hier` record takes the place of the FIRST terminal it speaks for and no other record moves: behind a missing top-level resistor and a withheld coupling, a single refused device inside a subcircuit is the third record, in the singular (kinds; the hier line)} \
        [list [pd_kinds $recs21c] [lindex [lindex $recs21c 2] 2]] \
        [list {{missing i(rtop:n1)} {withheld i(k1:n1)} {hier i(x1.xm1:d)}} \
              [pd_hier {the terminal current i(x1.xm1:d)}]]
    ase::sim_said_clear
    set said22 [lindex [pd_report [pd_state pl_old [pd_outs i(rtop:n1) 1 0  i(k1:n1) 1 0  i(x1.xm1:d) 1 0] $::AN_OP] $::LOGOLD 0 $::NLE] 1]
    check {PL22 every line of the report is spoken as an error, the `hier` record among them -- and that one through ase::sim_say, the recorder of the sentences about a simulator, which holds it and nothing else of the report afterwards (tags of PL19's line and of PL21c's three; what the recorder holds)} \
        [list [pd_nth $said19 0] [pd_nth $said22 0] [ase::sim_said]] \
        [list {error} {error error error} [pd_hier {the terminal current i(x1.xm1:d)}]]
    ase::sim_said_clear

    # ---- what the report keeps for Direct Plot's refusal ----------------------
    # After each report: the terminals of its `hier` record, and the reason it
    # kept for every other terminal it spoke for, as the clause Direct Plot
    # says behind "... is not in this session's results: ".
    proc pl_kept {} {
        return [list [dict keys [ase::state_get $::ase::last_probes hier]] [ase::state_get $::ase::last_probes why]]
    }
    set k {}
    set stk [pd_state pl_keep1 [pd_outs i(x1:out) 1 0  i(X1.XM1:D) 1 0  i(rtop:n1) 1 0] $::AN_OP]
    pd_raw [pd_rawpath $stk] {{{Operating Point} {v(out) i(rtop:n1)}}}
    pd_map $stk {{op 0 {Operating Point}}}
    pd_report $stk $::LOGOLD
    lappend k [pl_kept] [list [expr {[ase::state_get $::ase::last_probes raw] eq [ase::run_lock_key $stk]}] \
                              [ase::state_get $::ase::last_probes sim] [dict keys [ase::state_get $::ase::last_probes asked]]]
    pd_report [pd_state pl_keep2 [pd_outs i(k1:n1) 1 0  i(r5:n3) 1 0] $::AN_OP] $::LOG2L 0 $::NLE
    lappend k [pl_kept]
    set stk [pd_state pl_keep3 [pd_outs i(x1.r1:n1) 1 0  i(x1.m2:b) 1 0  i(rtop:n1) 1 0] $::AN_OP]
    pd_raw [pd_rawpath $stk] {{{Operating Point} {v(out) i(rtop:n1) i(x1.m2:b_tj)}}}
    pd_map $stk {{op 0 {Operating Point}}}
    pd_report $stk "[ase::probe_marker] 1\n"
    lappend k [pl_kept]
    set stk [pd_state pl_keep4 [pd_outs i(rtop:n1) 1 0] {{type noise enabled 1 source v1}}]
    pd_raw [pd_rawpath $stk] {{{Integrated Noise} {v(onoise_total) v(inoise_total)}} {{Noise Spectral Density Curves} {frequency v(onoise_spectrum)}}}
    pd_map $stk {{noise 0 {Integrated Noise}} {noise 0 {Noise Spectral Density Curves}}}
    pd_report $stk "[ase::probe_marker] 1\n"
    lappend k [pl_kept]
    pd_report [pd_state pl_keep5 [pd_outs v(out) 1 0] $::AN_OP] {}
    lappend k [pl_kept]
    check {PL30 WHAT THE REPORT KEEPS FOR DIRECT PLOT, read back after each report: for a build that answers 0, the terminals of its one record under their lower-cased names and no reason of their own, with the results file the report is about, the run's name for its program and every terminal the plan held; for a withheld card and a top-level refusal, each one's reason as a clause that opens `in the last run` and ends as its sentence ends; for a vector that is missing and for one made under another name, the same; for a noise-only run, the run's reason for each terminal; and for a run that asked for no terminal, nothing} \
        $k [list \
          [list {i(x1:out) i(x1.xm1:d)} {}] [list 1 $::PD_SIM {i(x1:out) i(x1.xm1:d) i(rtop:n1)}] \
          [list {} [dict create i(k1:n1) {in the last run no probe was written for it: k1 is a coupling between inductors and has no terminal. To measure it, place an ammeter (ammeter.sym) in series.} \
                                i(r5:n3) {in the last run the simulator refused it (.probe I(r5,3)): Node zz is not available for device r5.}]] \
          [list {} [dict create i(x1.r1:n1) {in the last run the deck asked for it (.probe I(x1.r1,1)) and the simulator neither made the vector nor said why.} \
                                i(x1.m2:b) {in the last run the deck asked for it (.probe I(x1.m2,b)), and for x1.m2 the results hold i(x1.m2:b_tj). Name the row after the one meant.}]] \
          [list {} [dict create i(rtop:n1) {the last run made only noise, transfer-function, pole-zero or sensitivity analyses, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.}]] \
          [list {} {}]]

    # ---- missing under the asked name, made under another ---------------------
    # The card is taken and the simulator calls the vector something else: a
    # MOS bulk asked as `b` comes back as `b_tj`, a bipolar's position 1 as `c`.
    # x1.m20 is there so that a path which merely STARTS like x1.m2 is seen
    # not to count.
    set sta [pd_state pl_alias [pd_outs i(x1.m2:b) 1 0  i(x1.q1:1) 1 0  i(x1.m2:d) 1 0  i(x1.m20:g) 1 0  i(x1.r1:n1) 1 0] $::AN_OP]
    pd_raw [pd_rawpath $sta] {{{Operating Point} {v(out) i(x1.m2:b_tj) i(x1.m2:d) i(x1.q1:c) i(x1.m20:d) i(v.x1.v2)}}}
    pd_map $sta {{op 0 {Operating Point}}}
    lassign [pd_report $sta "[ase::probe_marker] 1\n"] recs said
    check {PL25 A VECTOR MADE UNDER ANOTHER NAME: a terminal that is not in the judged plot while the plot holds other terminal currents of the SAME instance is reported with those names and the advice to name the row after the one meant -- never as a vector the simulator did not make; the terminal the plot holds is not reported, and one whose instance has no vector there keeps the plain sentence (kinds; the first line whole; which lines say the simulator made nothing)} \
        [list [pd_kinds $recs] [lindex [lindex $recs 0] 2] \
              [lmap r $recs { string match {*neither made the vector*} [lindex $r 2] }]] \
        [list {{missing i(x1.m2:b)} {missing i(x1.q1:1)} {missing i(x1.m20:g)} {missing i(x1.r1:n1)}} \
              {ase: the terminal current i(x1.m2:b) is not in this run's results under that name: the deck asked for it (.probe I(x1.m2,b)), and for x1.m2 the results hold i(x1.m2:b_tj), i(x1.m2:d). Name the row after the one meant.} \
              {0 0 0 1}]
    check {PL25b ...the names each of those lines gives are the instance's own and no other's (the `results hold` clause of the three, cut out of the sentence)} \
        [lmap r [lrange $recs 0 2] { regsub {^.* the results hold (.*)\. Name the row.*$} [lindex $r 2] {\1} }] \
        {{i(x1.m2:b_tj), i(x1.m2:d)} i(x1.q1:c) i(x1.m20:d)}
    pd_raw [pd_rawpath $sta] {{{Operating Point} {v(out) I(X1.M2:B_TJ)}}}
    check {PL25c the instance is matched without case, and the name is given as the FILE spells it: an upper-case file answers a lower-case row, and a lower-case file a preserve run's upper-case row} \
        [list [regsub {^.* the results hold (.*)\. Name the row.*$} \
                  [lindex [lindex [lindex [pd_report [pd_state pl_alias [pd_outs i(x1.m2:b) 1 0] $::AN_OP] "[ase::probe_marker] 1\n"] 0] 0] 2] {\1}] \
              [apply {{sta} {
                  pd_raw [pd_rawpath $sta] {{{Operating Point} {v(out) i(x1.m2:b_tj)}}}
                  return [regsub {^.* the results hold (.*)\. Name the row.*$} \
                      [lindex [lindex [lindex [pd_report [pd_state pl_alias [pd_outs i(X1.M2:B) 1 0] $::AN_OP] "[ase::probe_marker] 1\n" 0 {} preserve] 0] 0] 2] {\1}] }} $sta]] \
        {I(X1.M2:B_TJ) i(x1.m2:b_tj)}

    # ---- a numbered port whose header was not found -----------------------------
    # x5 calls `nosuch`, which has no header anywhere, so its numbers went
    # into the card as they stand; xw.xq.xz stands in a body the netlist text
    # does not hold.  The log and the vectors are what the fork gives such
    # cards over a subcircuit whose ports are 3 2 7: `I(x5,3)` is the third
    # port and comes back as i(x5:7), `I(x5,2)` is the second and is i(x5:2),
    # `I(x5,7)` is refused -- and a number that is also a port's name draws a
    # line that is NOT a refusal.
    set stn [pd_state pl_num [pd_outs i(x5:3) 1 0  i(x5:2) 1 0  i(x5:7) 1 0  i(xw.xq.xz:5) 1 0  i(x2:7) 1 0  i(x2:3) 1 0] $::AN_OP]
    pd_raw [pd_rawpath $stn] {{{Operating Point} {v(a) i(x5:2) i(x5:7) i(x2:7) i(x2:3)}}}
    pd_map $stn {{op 0 {Operating Point}}}
    set LOGNUM "probe: I(x5:3): 3 is taken as a position, not as the port named 3\nprobe: I(x5:7) not inserted: x5 has 3 terminals\nprobe: I(x2:3): 3 is taken as a position, not as the port named 3\n[ase::probe_marker] 1\n"
    lassign [pd_report $stn $LOGNUM 0 $::NLQ] recs said
    check {PL26 A NUMBERED PORT WHOSE POSITION COULD NOT BE LOOKED UP and that then has no vector is told why: the sentence says the simulator reads a number as a position and names what ASE-L did not find -- the subcircuit's header, with where to name its model file, or the instance's card. A row that HAS its vector is not reported, also when the log refused the card written for it (another row's card made the vector); and the ports whose position WAS written draw nothing, although the log holds the simulator's `taken as a position` line for one of them (kinds, then the two lines whole)} \
        [list [pd_kinds $recs] [pd_nth $recs 2]] \
        [list {{missing i(x5:3)} {missing i(xw.xq.xz:5)}} [list \
          {ase: the terminal current i(x5:3) is not in this run's results: the deck asked for it as .probe I(x5,3). The simulator reads a number in a .probe card as a position, not as the port of that name, and ASE-L did not find one .subckt header for nosuch, in this run's netlist or in the model files it names, to turn the port named 3 into its position. Name the model file that holds that header under Setup > Model Files and run again.} \
          {ase: the terminal current i(xw.xq.xz:5) is not in this run's results: the deck asked for it as .probe I(xw.xq.xz,5). The simulator reads a number in a .probe card as a position, not as the port of that name, and ASE-L found no card for the instance xw.xq.xz in this run's netlist, so it could not turn the port named 5 into its position. To measure it, place an ammeter (ammeter.sym) in series.}]]
    pd_raw [pd_rawpath $stn] {{{Operating Point} {v(a) i(x5:2)}}}
    lassign [pd_report [pd_state pl_num [pd_outs i(x5:7) 1 0  i(r5:n3) 1 0] $::AN_OP] "$LOGNUM$::LOG2L" 0 $::NLQ] recs said
    check {PL26a ...and the same refused card, with no vector of that name in the results, is reported as refused with the simulator's reason and the same explanation behind it; a refusal that is no numbered port keeps its sentence as it was (kinds, then the two lines whole)} \
        [list [pd_kinds $recs] [pd_nth $recs 2]] \
        [list {{refused i(x5:7)} {refused i(r5:n3)}} [list \
          {ase: the simulator refused the terminal current i(x5:7) (.probe I(x5,7)): x5 has 3 terminals. The simulator reads a number in a .probe card as a position, not as the port of that name, and ASE-L did not find one .subckt header for nosuch, in this run's netlist or in the model files it names, to turn the port named 7 into its position. Name the model file that holds that header under Setup > Model Files and run again.} \
          {ase: the simulator refused the terminal current i(r5:n3) (.probe I(r5,3)): Node zz is not available for device r5.}]]
    check {PL26b the simulator's `is taken as a position` line is no refusal: ase::probe_refusals reads only the `not inserted` one out of that log} \
        [ase::probe_refusals $LOGNUM] [dict create x5,7 {x5 has 3 terminals}]
    check {PL26c ase::probe_nohdr_note is empty for a record with nothing flagged, so every other sentence is what it was (a letter port, a device terminal, a numbered port that was placed)} \
        [lmap r [pq_plan {i(x2:in) i(rtop:n1) i(x2:7)}] { ase::probe_nohdr_note $r }] {{} {} {}}

    # ---- a run that did not converge --------------------------------------------
    # A probe is a zero-volt source in series with its pin.  LOGTS is a failed
    # transient's lines.  LOGOP is what an operating point that cannot be
    # solved prints: the simulator's `singular matrix` warning, then its
    # failure lines.  LOGSM is that warning alone, at a probe's own node, as a
    # run that goes on to converge prints it -- with the line that says the
    # operating point was found.
    set stv [pd_state pl_conv [pd_outs i(x1.r1:n1) 1 0  i(rtop:n1) 1 0  -i(rtop:n1) 0 0  i(k1:n1) 1 0] $::AN_OPTRAN]
    set LOGTS "[ase::probe_marker] 1\ndoAnalyses: TRAN:  Timestep too small; time = 1.2e-09, timestep = 1.25e-19: trouble with node \"x1.out\"\n\ntran simulation(s) aborted\n"
    set LOGSM "[ase::probe_marker] 1\nWarning: singular matrix:  check node x1#probe_int_1\nNote: Transient op finished successfully\n"
    set LOGOP "[ase::probe_marker] 1\nWarning: singular matrix:  check node v1#branch\nError: Transient op failed, timestep too small\ndoAnalyses: OP:  Timestep too small; cause unrecorded.\nop simulation(s) aborted\nDC solution failed -\n"
    lassign [pd_report $stv $LOGTS 1] recs said
    check {PL27 A RUN THAT DID NOT CONVERGE, with probe cards in its deck: a nonzero exit and a `Timestep too small` line add exactly ONE record behind the others, a note that counts the TERMS the deck carried -- two here, for three rows naming two terminals and one withheld -- and it is spoken as a note (kinds, the note whole, the tags)} \
        [list [pd_kinds $recs] [lindex [lindex $recs end] 2] [pd_nth $said 0]] \
        [list {{withheld i(k1:n1)} {note {}}} \
              {ase: this run did not converge, and its deck asked for 2 terminal currents. Each one puts a zero-volt source in series with its pin, and that alone can stop a run that finishes without it. Switching those rows off -- unticking Save and Plot on a Saves row, removing or disabling a Measures or measurement row that reads a terminal -- may let the run finish.} \
              {error note}]
    set one [pd_state pl_conv1 [pd_outs i(rtop:n1) 1 0] $::AN_OPTRAN]
    check {PL28 each failure line of the rule brings the note by itself, in whatever case the simulator prints it, and a deck of one term is counted in the singular (kinds for the whole log of a failed operating point; for `DC solution failed` alone, for a lower-case `timestep too small` alone, for `no convergence`, for the line that says the operating point could not be simulated; then the opening of the one-term note)} \
        [list [pd_kinds [lindex [pd_report $one $LOGOP 1] 0]] \
              [pd_kinds [lindex [pd_report $one "DC solution failed -\n" 1] 0]] \
              [pd_kinds [lindex [pd_report $one "Error: Transient op failed, timestep too small\n" 1] 0]] \
              [pd_kinds [lindex [pd_report $one "Error: No Convergence in the operating point\n" 139] 0]] \
              [pd_kinds [lindex [pd_report $one "Error: The operating point could not be simulated successfully.\n" 1] 0]] \
              [string match {ase: this run did not converge, and its deck asked for 1 terminal current. Each one puts*} \
                  [lindex [lindex [lindex [pd_report $one $LOGOP 1] 0] end] 2]]] \
        {{{note {}}} {{note {}}} {{note {}}} {{note {}}} {{note {}}} 1}
    check {PL29 ...and NOTHING ELSE brings it: not a failed run whose log has no such line (a missing model); not a run that exited 0 with a failure line in its log; not a failed run whose plan wrote no card; not a run that asked for no terminal; and NOT THE SIMULATOR'S `singular matrix` WARNING, which a run that converges prints too -- a nonzero exit with that warning and the line saying the operating point was found (a run that was stopped) says nothing, and neither does that log with the deck's own failure word behind it (a later analysis that failed for another reason) (records of the six)} \
        [list [lindex [pd_report $one "Error: unknown subckt: x1 g out 0 blk\n" 1] 0] \
              [lindex [pd_report $one $LOGTS 0] 0] \
              [pd_kinds [lindex [pd_report [pd_state pl_convk [pd_outs i(k1:n1) 1 0] $::AN_OPTRAN] $LOGTS 1 $::NLE] 0]] \
              [lindex [pd_report [pd_state pl_conv0 [pd_outs v(out) 1 0] $::AN_OPTRAN] $LOGTS 1] 0] \
              [lindex [pd_report $one $LOGSM 1] 0] \
              [lindex [pd_report $one "${LOGSM}ERROR: fatal error in ngspice, exit(1)\nRUN-FAILED\n" 1] 0]] \
        {{} {} {{withheld i(k1:n1)}} {} {} {}}

    # ---- ...with the transient-op rung switched off -----------------------------
    # The Convergence form can switch the simulator's transient-op rung off.
    # An operating point that cannot be solved is then given up by the other
    # rungs: RODOWN is what those print on their way down, and its last line
    # says the operating point could not be simulated.  LOGRO puts behind it
    # what an ac analysis, a transient and a dc sweep print when that
    # operating point was theirs, and -- `stock` -- the same ac failure as the
    # stock binary words it.  LOGUP is a run whose operating point WAS found,
    # on the transient-op rung, after the same warnings from the rungs before
    # it, and LOGTF is that run with a later analysis that failed for a reason
    # of its own.  LOGPZ is the pole-zero search's warning, which a run that
    # goes on prints, with a fatal line of the row's own behind it.  Every
    # other line is copied out of a real run of ver_53 or of apt 45.2.
    set RODOWN [pd_text {Note: Starting dynamic gmin stepping} {Warning: Dynamic gmin stepping failed} \
        {Note: Starting true gmin stepping} {Warning: True gmin stepping failed} \
        {Note: Starting source stepping} {Warning: source stepping failed} {} \
        {Error: The operating point could not be simulated successfully.} {    Any of the following steps may fail.!} {}]
    set ROOUT [pd_text {} "[ase::probe_marker] 1" {Note: Optran is deselected.}]
    set LOGRO [dict create \
        ac    "$RODOWN[pd_text {doAnalyses: iteration limit reached} {} {ac simulation(s) aborted}]$ROOUT[pd_text {} {AC operating point failed -} {} {RUN-FAILED}]" \
        tran  "$RODOWN[pd_text {} {Error: Finding the operating point for transient simulation failed } {} {doAnalyses: iteration limit reached} {} {tran simulation(s) aborted}]$ROOUT[pd_text {RUN-FAILED}]" \
        dc    "$RODOWN[pd_text {doAnalyses: iteration limit reached} {} {dc simulation(s) aborted}]$ROOUT[pd_text {RUN-FAILED}]" \
        stock "$RODOWN[pd_text {doAnalyses: Too many iterations without convergence} {} {ac simulation(s) aborted} {} "[ase::probe_marker] 0" {} {AC operating point failed -} {} {RUN-FAILED}]"]
    set LOGUP [pd_text {Warning: singular matrix:  check node fl} {} \
        {Note: Starting dynamic gmin stepping} {Warning: singular matrix:  check node fl} {} {Warning: Dynamic gmin stepping failed} \
        {Note: Starting true gmin stepping} {Warning: singular matrix:  check node fl} {} {Warning: True gmin stepping failed} \
        {Note: Starting source stepping} {Warning: source stepping failed} \
        {Note: Transient op started} {Note: Transient op finished successfully} {} "[ase::probe_marker] 1"]
    set LOGTF "$LOGUP[pd_text {Internal Error: incomplete CKTunsetup(), this will cause serious problems, please report this issue !} {} {ERROR: fatal error in ngspice, exit(1)}]"
    set LOGPZ [pd_text "[ase::probe_marker] 1" {Warning: Pole-zero iteration limit reached; giving up after 617 trials} {ERROR: fatal error in ngspice, exit(1)}]
    check {PL28b AN OPERATING POINT THAT FAILED WITH THE TRANSIENT-OP RUNG SWITCHED OFF brings the note, whichever analysis asked for it: such a log holds none of the other failure lines, only the one that says the operating point could not be simulated (fixture, per log: one of the other lines found, that line found; then the kinds for an ac analysis, a transient, a dc sweep, and the ac analysis as the stock binary words it)} \
        [list [lmap k {ac tran dc stock} { list [regexp -nocase $::CONVREST [dict get $LOGRO $k]] [regexp {operating point could not be simulated} [dict get $LOGRO $k]] }] \
              [lmap k {ac tran dc stock} { pd_kinds [lindex [pd_report $one [dict get $LOGRO $k] 1] 0] }]] \
        {{{0 1} {0 1} {0 1} {0 1}} {{{note {}}} {{note {}}} {{note {}}} {{note {}}}}}
    check {PL29b ...AND THE LINES THAT STAND BESIDE IT IN SUCH LOGS BRING NOTHING: not the pole-zero search's `iteration limit reached` warning with a fatal line behind it; not a run whose operating point was found on the transient-op rung, after the other rungs' `stepping failed` warnings, and that was then stopped; and not that run with a later analysis that failed for a reason of its own (fixture: the first log holds `iteration limit reached`, the other two hold `stepping failed` and the line saying the transient op finished; then the records of the three)} \
        [list [list [regexp {iteration limit reached} $LOGPZ] \
                    [expr {[regexp {stepping failed} $LOGUP] && [regexp {Transient op finished successfully} $LOGUP]}] \
                    [expr {[regexp {stepping failed} $LOGTF] && [regexp {Transient op finished successfully} $LOGTF]}]] \
              [lindex [pd_report $one $LOGPZ 1] 0] \
              [lindex [pd_report $one $LOGUP 1] 0] \
              [lindex [pd_report $one $LOGTF 1] 0]] \
        {{1 1 1} {} {} {}}
}

# =============================================================================
# PW -- THE WIRING: run_deck CARRIES THE PLAN, run_done REPORTS IT
# =============================================================================
# A backend that is ngspice's in every hook but the command it starts: a shell
# script that puts a canned results file and plot sidecar where the deck would
# have written them and prints a canned log.  So ase::run_deck, the completion
# callback and ase::run_done run for real, with no simulator.
set ::pw_calls {}
proc pw_strip {body} {
    set out {}
    foreach l [split $body "\n"] {
        if {[string index [string trimleft $l] 0] eq "#"} continue
        lappend out $l
    }
    return [join $out "\n"]
}
# ase::wait with a deadline: the run's exit code, or STALLED when its
# completion has not arrived within thirty seconds.  (ase::wait itself waits
# for ever, and a completion callback that raises never wakes it.)
proc pw_wait {id} {
    set n 0
    xschem set semaphore [expr {[xschem get semaphore] + 1}]
    while {[info exists ::execute(pipe,$id)] && $n < 300} {
        after 100 {set ::pw_tick 1}
        vwait ::pw_tick
        incr n
    }
    xschem set semaphore [expr {[xschem get semaphore] - 1}]
    if {[info exists ::execute(pipe,$id)]} { return STALLED }
    if {[info exists ::execute(exitcode,$id)]} { return $::execute(exitcode,$id) }
    return -1
}
group PW {
    set hooks [dict get $::ase::backends ngspice]
    proc pw_run_cmd {state deckpath {quiet 0}} { return [list sh $::pw_stub 2>@1] }
    dict set hooks run_cmd pw_run_cmd
    ase::register_backend pwsim $hooks
    set outs [pd_outs i(x1.nope:n1) 1 0  i(rtop:n1) 1 0  i(k1:n1) 1 0  i(x1.xm1:d) 1 0  v(out) 1 0]
    set st [pd_state pw $outs $::AN_OP]
    dict set st simulator pwsim
    set d [dict get $st rundir]
    set nlf [file join $d pw.spice]
    pd_wr $nlf $::NLB
    set canraw [file join $d canned.raw]
    set canmap [file join $d canned.plotmap]
    set canlog [file join $d canned.log]
    pd_raw $canraw {{{Operating Point} {v(out) i(v1) i(x1.xm1:d)}}}
    pd_wr $canmap "[ase::plotmap_record op 0 {Operating Point}]\n"
    pd_wr $canlog "probe: I(x1.nope:1) not inserted: no instance named x1.nope\n[ase::probe_marker] 0\n"
    set ::pw_stub [file join $d stub.sh]
    pd_wr $::pw_stub "cp '$canraw' '[pd_rawpath $st]'\ncp '$canmap' '[ase::plotmap_path $st]'\ncat '$canlog'\nexit 0\n"
    # the report's own arguments, as run_done hands them over
    rename ::ase::probe_report ::pw_real_report
    proc ::ase::probe_report {args} { lappend ::pw_calls $args ; return [::pw_real_report {*}$args] }
    lassign [pd_spy {
        set id [ase::run_deck $st $nlf]
        pw_wait $id
    }] rc said
    rename ::ase::probe_report {}
    rename ::pw_real_report ::ase::probe_report
    catch {ase::run_lock_clear [ase::run_lock_key $st]}
    set mine {}
    foreach s $said {
        if {[regexp {terminal current} [lindex $s 1]]} { lappend mine [lindex $s 1] }
    }
    check {PW0 fixture: the run started, finished with exit 0, and its deck carried the two cards of the terminals that have one} \
        [list $rc [pd_lines [pd_rd [ase::deck_file $st]] {^\.probe}]] {0 {{.probe I(x1.nope,1) I(rtop,1) I(x1.xm1,d)}}}
    set call [lindex $::pw_calls 0]
    check {PW1 ase::run_done calls the report ONCE, with the run's state, a record whose `probes` is the plan of the deck that ran, the run's log text and its exit code} \
        [list [llength $::pw_calls] [expr {[lindex $call 0] eq $st}] \
              [expr {[ase::state_get [lindex $call 1] probes NOKEY] eq [ase::probe_plan $st $::NLB fold]}] \
              [llength [ase::state_get [lindex $call 1] probes]] \
              [string match {*not inserted: no instance named x1.nope*} [lindex $call 2]] [lindex $call 3]] \
        {1 1 1 4 1 0}
    check {PW2 ...and the run then says, in plan order: for the refused device inside a subcircuit -- the simulator having answered 0 -- that this run's program cannot save it and what to do, the program named by the backend's own word because this backend's run command does not start what the registry holds; the vector the results lack; the card ASE-L withheld; nothing for the terminal that came back} \
        $mine [list \
          [pd_hier {the terminal current i(x1.nope:n1)} pwsim] \
          {ase: the terminal current i(rtop:n1) is not in this run's results: the deck asked for it (.probe I(rtop,1)) and the simulator neither made the vector nor said why.} \
          {ase: no probe was written for the terminal current i(k1:n1): k1 is a coupling between inductors and has no terminal. To measure it, place an ammeter (ammeter.sym) in series.}]
    set rd [pw_strip [info body ase::run_done]]
    set rk [pw_strip [info body ase::run_deck]]
    check {PW3 STRUCTURAL: the report is called inside a catch on the line directly under the operating-point report's, and ase::run_deck appends `probes` as the LAST key of its record, computed by the same call the deck writer makes (three text bounds on the two bodies, whole-line comments dropped)} \
        [list [regexp {catch \{ase::op_report_missing \$state \$meta \$exitcode\}\n\s*catch \{ase::probe_report \$state \$meta \$data \$exitcode\}\n} $rd] \
              [regexp {t0 \[clock milliseconds\] probes \$probes\]\n} $rk] \
              [expr {[string first {[ase::probe_plan $state $netlist_text [ase::probe_mode $state]]} $rk] > [string first {$render_deck $state $netlist_text} $rk]}] \
              [expr {[string first {[ase::probe_plan $state $netlist_text [ase::probe_mode $state]]} \
                        [pw_strip [info body ase::backend::ngspice::render_deck]]] >= 0}]] \
        {1 1 1 1}

    # A DEFECT IN THE RECORD'S PLAN OR IN THE REPORT MUST NOT STOP A RUN.
    proc pw_go {st nlf} {
        set r [pd_spy [list apply {{st nlf} { pw_wait [ase::run_deck $st $nlf] }} $st $nlf]]
        catch {ase::run_lock_clear [ase::run_lock_key $st]}
        return $r
    }
    set ::pw_n 0
    set ::pw_calls {}
    rename ::ase::probe_plan ::pw_real_plan
    proc ::ase::probe_plan {args} {
        if {[incr ::pw_n] == 2} { error "a defect in the plan" }
        return [::pw_real_plan {*}$args]
    }
    rename ::ase::probe_report ::pw_real_report
    proc ::ase::probe_report {args} { lappend ::pw_calls $args ; return [::pw_real_report {*}$args] }
    lassign [pw_go $st $nlf] rc4 said4
    rename ::ase::probe_report {}
    rename ::pw_real_report ::ase::probe_report
    rename ::ase::probe_plan {}
    rename ::pw_real_plan ::ase::probe_plan
    check {PW4 a plan that raises when ase::run_deck asks for the record's copy does not stop the run: the deck was already written from the first answer, the run finishes with exit 0, and the report is handed an empty plan (plan calls, exit, the record's probes, the card of the deck that ran)} \
        [list $::pw_n $rc4 [ase::state_get [lindex [lindex $::pw_calls 0] 1] probes NOKEY] \
              [pd_lines [pd_rd [ase::deck_file $st]] {^\.probe}]] \
        {2 0 {} {{.probe I(x1.nope,1) I(rtop,1) I(x1.xm1,d)}}}
    rename ::ase::probe_report ::pw_real_report
    proc ::ase::probe_report {args} { error "a defect in the report" }
    lassign [pw_go $st $nlf] rc5 said5
    rename ::ase::probe_report {}
    rename ::pw_real_report ::ase::probe_report
    check {PW5 a report that raises does not break the run's completion: the run still ends with exit 0 and says its finish line (exit, finish lines spoken)} \
        [list $rc5 [llength [lsearch -all -glob [pd_nth $said5 1] {ase: simulation finished (exit 0)*}]]] {0 1}
}

# =============================================================================
# PH -- A TERMINAL BELOW THE TOP LEVEL: WHICH PROGRAM CAN SAVE IT, AND WHO IS TOLD
# =============================================================================
# A STAND-IN SIMULATOR FOR THE CAPABILITY PROBE.  It is started as the real one
# is (`<program> -b <deck>` in the probe's own directory), notes every start in
# a file of its own, writes a one-plot results file where the deck's `write`
# line asks for one -- so the probe measures a program that simulates -- and
# answers the terminal-probe question by doing @ANSWER@ with the file name the
# deck's own line carries in $hf.  @FIRST@ runs as soon as the deck is known,
# @LAST@ after the answer is written.
set PH_STUB {#!/bin/sh
echo run >> '@MARK@'
deck=
for a in "$@"; do if [ -f "$a" ]; then deck="$a"; fi; done
[ -n "$deck" ] || exit 0
@FIRST@
out=`sed -n 's/^write  *\([^ ]*\).*/\1/p' "$deck" | head -1`
if [ -n "$out" ]; then
  printf 'Title: ph\nDate: none\nPlotname: Operating Point\nFlags: real\nNo. Variables: 1\nNo. Points: 1\nVariables:\n\t0\tv(dd)\tvoltage\nValues:\n 0\t1.8\n' > "$out"
fi
hf=`sed -n 's/^echo .* > *\(probe_h[^ ]*\) *$/\1/p' "$deck" | head -1`
if [ -n "$hf" ]; then
  @ANSWER@
fi
@LAST@
exit @RC@
}
set PHBIN [file join $scratch ph_bin]
file mkdir $PHBIN
proc ph_mark {name} { return [file join $::PHBIN $name.runs] }
# How often the stand-in `name` has been started since its mark was removed.
proc ph_runs {name} {
    if {![file exists [ph_mark $name]]} { return 0 }
    return [llength [regexp -all -inline {run} [pd_rd [ph_mark $name]]]]
}
proc ph_forget_runs {args} { foreach n $args { file delete -force [ph_mark $n] } }
# `answer` is the whole line the stand-in writes for the question ({} writes
# no file); -first a shell line run once the deck is known, -last one run
# after the answer is written; -rc its exit code.
proc ph_stub {name answer args} {
    array set o {-first : -last : -rc 0}
    array set o $args
    set ans :
    if {$answer ne {}} { set ans "echo '$answer' > \"\$hf\"" }
    set path [file join $::PHBIN $name]
    pd_wr $path [string map [list @MARK@ [ph_mark $name] @FIRST@ $o(-first) @LAST@ $o(-last) @ANSWER@ $ans @RC@ $o(-rc)] $::PH_STUB]
    file attributes $path -permissions 0755
    return $path
}
# The registry holding exactly `names` (stand-ins of PHBIN, in that order),
# none picked, and nothing remembered about any program.
proc ph_registry {args} {
    test_sim_registry_isolate
    foreach n $args { ase::sim_register $n [file join $::PHBIN $n] }
    ase::sim_select {}
}
# `script` with ase::probe_cure_ms set to `ms`, and the wall time it took:
# -> {answer milliseconds}.
proc ph_timed {ms script} {
    set keep $::ase::probe_cure_ms
    set ::ase::probe_cure_ms $ms
    set t0 [clock milliseconds]
    set rc [catch {uplevel 1 $script} r]
    set dt [expr {[clock milliseconds] - $t0}]
    set ::ase::probe_cure_ms $keep
    if {$rc} { set r "ERR:$r" }
    return [list $r $dt]
}
set M1 "[ase::probe_marker] 1"
set M0 "[ase::probe_marker] 0"
set PH_DOOR "Setup > Simulators…"
set PH_REG "Register an ngspice build that saves terminal currents inside subcircuits under $PH_DOOR"
set PH_AMM {or place an ammeter (ammeter.sym) in series with the pin.}
proc ph_can {names {tail {and run again}}} {
    return "$names can — pick [expr {[regexp { and } $names] ? {one} : {it}}] under $::PH_DOOR $tail."
}
# The cure's words where no entry is known able and `names` have not been asked.
proc ph_untried {names} {
    set many [regexp { and } $names]
    return "$names [expr {$many ? {have} : {has}}] not been tried yet — the next run finds out [expr {$many ? {which of them} : {whether it}}] can, or select [expr {$many ? {each} : {it}}] under $::PH_DOOR, press Edit… and then Detect."
}

group PH {
    # ---- the predicate, the plan's share of it, the marker's answer ----------
    set t {}
    foreach p {r1 R1 m1 rx vx1 e5 x1 X1 xm1 XM1 {xb[1]} x1.r1 X1.R1 x1.xm1 a.b {xb[0].xm1} { x1 } {}} { lappend t [pcall ase::probe_needs_hier $p] }
    check {PH1 ase::probe_needs_hier, asked of a terminal's instance path: 0 for a top-level device that is no subcircuit instance (in either case, also one with an x further into its name), 1 for a top-level subcircuit instance in either case and for a bus bit of one, 1 for every path with a dot in it whatever its last word, the blanks around a path taken off, 0 for none} \
        $t {0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1 0}
    set st [pd_state ph_plan [pd_outs i(rtop:n1) 1 0  i(x1:out) 1 0  i(x1.k9:n1) 1 0  i(X1.XM1:D) 1 0  i(e5:n1) 1 0] $::AN_OP]
    set plan [ase::probe_plan $st $::NLB fold]
    check {PH2 ase::probe_plan_hier gives the plan's terminals that need such a program, in plan order and in the rows' own spelling: the pin of the subcircuit instance and the device inside one, not the two top-level devices -- and not the coupling inside the subcircuit, which ASE-L wrote no card for (fixture: the five cards of the plan; then the answer)} \
        [list [pd_col $plan card] [pcall ase::probe_plan_hier $plan]] \
        [list {I(rtop,1) I(x1,out) {} I(X1.XM1,D) I(e5,1)} {i(x1:out) i(X1.XM1:D)}]
    set t {}
    foreach txt [list "$::M1\n" "$::M0\r\n" {} "x $::M1\n" "[ase::probe_marker] 2\n" "$::M1\nnoise\n$::M0\n" "[ase::probe_marker]  \t1  \n" "[ase::probe_marker] 10\n" "[ase::probe_marker]\n"] {
        lappend t [pcall ase::probe_marker_answer $txt]
    }
    check {PH3 ase::probe_marker_answer reads the simulator's answer off a whole line that is the marker's word and a 0 or a 1: 1, 0 (also before a carriage return), nothing for no line, for the word inside a line, for another digit; a 0 anywhere wins over a 1; blanks around the digit are taken; two digits and no digit are no answer} \
        $t {1 0 {} {} {} 0 1 {} {}}

    # ---- A1: the capability key, measured by the probe's own deck ------------
    check {PC1 `hier_probes` is a key of the capability band and of no other (its place in each band, -1 for none)} \
        [list [expr {[lsearch -exact [ase::caps_keys capability] hier_probes] >= 0}] \
              [lsearch -exact [ase::caps_keys identity] hier_probes] [lsearch -exact [ase::caps_keys defect] hier_probes] \
              [lsearch -exact [ase::caps_keys provenance] hier_probes]] {1 -1 -1 -1}
    set keep [file join $::PHBIN decks]
    file mkdir $keep
    test_sim_registry_isolate
    ph_stub zkeep $::M1 -first "cp \"\$deck\" '$keep/'"
    set c [pcall ase::sim_capabilities_path ngspice [file join $::PHBIN zkeep]]
    set dc {} ; set others {}
    catch {set dc [pd_rd [file join $keep probe_c.sp]]}
    foreach f [glob -nocomplain -directory $keep *] {
        if {[file tail $f] ne {probe_c.sp} && [regexp {probe_h|probe_version} [pd_rd $f]]} { lappend others [file tail $f] }
    }
    set ctl [lrange [split [string trim $dc] "\n"] [expr {[pd_at $dc {^\.control$}] + 1}] end]
    check {PC2 THE QUESTION RIDES DECK C AND NO OTHER DECK OF THE PROBE: read out of the decks a stand-in simulator kept, the FIRST line of deck C's control block writes the marker's word and the simulator's own `$?probe_version` into a bare lower-case file of its own, that deck holds the question once, and no other deck the probe ran holds it (decks kept, the first control line, lines of deck C that ask, other decks that ask)} \
        [list [expr {[llength [glob -nocomplain -directory $keep *]] >= 3}] [lindex $ctl 0] \
              [llength [pd_lines $dc {probe_version}]] $others] \
        [list 1 "echo [ase::probe_marker] \$?probe_version > probe_h.txt" 1 {}]
    set t [list [pcall ase::caps_get $c hier_probes] [pcall ase::caps_get $c known]]
    foreach {nm ans rc} [list zzero $::M0 0  znofile {} 0  ztwo "[ase::probe_marker] 2" 0  zother {no answer here} 0  zrc1 $::M1 1  zrc1no {} 1] {
        ph_stub $nm $ans -rc $rc
        set cc [pcall ase::sim_capabilities_path ngspice [file join $::PHBIN $nm]]
        lappend t [list [pcall ase::caps_get $cc hier_probes] [dict exists [pcall ase::caps_unmeasured_keys $cc] hier_probes]]
    }
    check {PC3 THE VERDICT IS THE FILE'S, NEVER THE EXIT CODE'S, AND IT IS PUBLISHED ONLY FOR A 0 OR A 1: a stand-in that writes 1 is measured 1 on an answer that is known; one that writes 0 is measured 0; one that writes no file, another digit or other words publishes no key and no reason for its absence; one that exits 1 after writing 1 is measured 1 all the same, and one that exits 1 without the file publishes nothing (the first: what is known of the key, of `known`; then per stand-in: what is known of the key, a recorded reason)} \
        $t [list {measured 1 value 1} {measured 1 value 1} \
                 {{measured 1 value 0} 0} {{measured 0} 0} {{measured 0} 0} {{measured 0} 0} {{measured 1 value 1} 0} {{measured 0} 0}]
    set wrote [file join $::PHBIN zcutc.wrote]
    ph_stub zcutc $::M1 -last "case \"\$deck\" in *probe_c*) cp \"\$hf\" '$wrote' ; exec sleep 30;; esac"
    set full $::ase::cap_budget_ms
    set ::ase::cap_budget_ms 2000
    set cc [pcall ase::sim_capabilities_path ngspice [file join $::PHBIN zcutc]]
    set ::ase::cap_budget_ms $full
    check {PC4 A RUN OF DECK C THAT THE BUDGET CUT leaves the key unmeasured BY NAME, as it leaves the dump's: the rest of the answer is known, both keys say `timeout`, and neither is published -- although the stand-in had written its 1 into the probe's file before it was cut (fixture: a copy of the file it wrote, taken by the stand-in before it hung; known, the two keys, the keys published)} \
        [list [string trim [pcall pd_rd $wrote]] [pcall ase::caps_get $cc known] [pcall ase::caps_get $cc hier_probes] [pcall ase::caps_get $cc altshow_op_dump] \
              [dict exists $cc hier_probes] [dict exists $cc altshow_op_dump]] \
        [list $::M1 {measured 1 value 1} {measured 0 why timeout} {measured 0 why timeout} 0 0]
    set hand 0 ; set viaNot 0 ; set readers 0
    foreach ns [concat ::ase ::ase::ui [namespace children ::ase::backend]] {
        foreach pr [info procs ${ns}::*] {
            set b [pw_strip [info body $pr]]
            incr hand [regexp -all {dict\s+(exists|get)\s+\$[A-Za-z_]+\s+hier_probes\M} $b]
            incr viaNot [regexp -all {!\s*\[\s*(::)?ase::caps_(is|measured_as)\s+\S+\s+hier_probes\M} $b]
            incr readers [regexp -all {caps_measured_as\s+\$[A-Za-z_]+\s+hier_probes\s+[01]\]} $b]
        }
    }
    check {PC5 STRUCTURAL: over the bodies of every proc of ASE-L, its window and its adapters (whole-line comments dropped), the key is never read by hand out of a capability answer and never through a negated predicate -- an unmeasured program must not be told it cannot -- and the scan is not vacuous: it finds the readers that ask through the vocabulary (hand reads, negated reads, readers found is at least four)} \
        [list $hand $viaNot [expr {$readers >= 4}]] {0 0 1}

    # ---- A2: the cure -----------------------------------------------------------
    foreach n {zcan1 zcan2 zcan3} { ph_stub $n $::M1 }
    ph_stub zno $::M0
    ph_stub zmute {}
    # ...and one that answers 1 while producing no results for the probe's two
    # circuit decks: a program not measured to simulate.
    ph_stub zdead $::M1 -first {case "$deck" in *probe_a*|*probe_b*) exit 0;; esac}
    set st [pd_state ph_cure {} $::AN_OP]
    set t {}
    foreach reg {{zcan1} {zno zcan1 zcan2} {zcan1 zno zcan2 zcan3} {zno} {} {zno zmute} {zmute zcan1} {zdead}} {
        ph_registry {*}$reg
        lappend t [pcall ase::probe_cure $st ask]
    }
    ph_registry zdead
    set dead [pcall ase::sim_capabilities_for zdead]
    check {PH10 THE CURE'S OUTCOMES, each through the real capability probe of registered stand-ins: one that can is named and picked as `it`; two as `A and B`, three as `A, B and C`, picked as `one`, in registry order and without the one that cannot between them; none that can, all measured: `None ... can.` and what to register, with the ammeter; nothing registered: that advice alone; none that can and one whose answer is not known: `is known to`; an entry that is not known beside one that can is simply not named; and a program that answers 1 but was measured NOT to simulate is not known either, never recommended (fixture for the last: what the probe measured of it)} \
        [list $t [pcall ase::caps_get $dead hier_probes] [pcall ase::caps_get $dead usable]] \
        [list [list [ph_can zcan1] [ph_can {zcan1 and zcan2}] [ph_can {zcan1, zcan2 and zcan3}] \
                 "None of the simulators you have registered can. $::PH_REG and run again, $::PH_AMM" \
                 "$::PH_REG and run again, $::PH_AMM" \
                 "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM" \
                 [ph_can zcan1] \
                 "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM"] \
              {measured 1 value 1} {measured 1 value 0}]
    ph_registry zno zcan1
    set a [pcall ase::probe_cure $st ask before]
    ph_registry zno
    check {PH11 at a pick the cure ends `before you run` where a run's ends `and run again`: with one that can, and with none} \
        [list $a [pcall ase::probe_cure $st ask before]] \
        [list [ph_can zcan1 {before you run}] "None of the simulators you have registered can. $::PH_REG before you run, $::PH_AMM"]
    ph_registry zno zcan1
    ph_forget_runs zno zcan1
    set peek0 [pcall ase::probe_cure $st peek]
    set n0 [list [ph_runs zno] [ph_runs zcan1]]
    set ask1 [pcall ase::probe_cure $st ask]
    set n1 [list [ph_runs zno] [ph_runs zcan1]]
    set ask2 [pcall ase::probe_cure $st ask]
    set peek2 [pcall ase::probe_cure $st peek]
    set n2 [list [ph_runs zno] [ph_runs zcan1]]
    check {PH12 `peek` STARTS NOTHING and `ask` starts a program ONCE: with nothing known about either registered program a peek starts neither, calls neither able nor unable, and does NOT send the user to register another build -- it names the two as not tried yet and says what finds out; an ask then starts both and names the one that can; a second ask and a peek after it give the same words and start nothing more (the three texts, the fourth equal to the third; starts of the two programs after the peek, both started by the ask, no start after it)} \
        [list $peek0 $ask1 $ask2 [expr {$peek2 eq $ask2}] $n0 [expr {[lindex $n1 0] > 0 && [lindex $n1 1] > 0}] [expr {$n2 eq $n1}]] \
        [list [ph_untried {zno and zcan1}] \
              [ph_can zcan1] [ph_can zcan1] 1 {0 0} 1 1]
    ph_registry zmute zcan1
    ase::sim_capabilities_for zmute
    set mixed [pcall ase::probe_cure $st peek before]
    ph_registry zcan1
    set one [pcall ase::probe_cure $st peek]
    ph_registry zmute
    ase::sim_capabilities_for zmute
    check {PH12b NOT TRIED YET IS KEPT APART FROM ASKED AND NO ANSWER: beside an entry that was asked and gave no answer to the question, the entry nobody has asked is the one named, in the singular, and the words are the same at a pick as beside a run; one untried entry alone reads the same; and with only the entry that gave no answer registered the advice to register a build stands, `is known to` (the three texts)} \
        [list $mixed $one [pcall ase::probe_cure $st peek]] \
        [list [ph_untried zcan1] [ph_untried zcan1] \
              "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM"]
    # ---- an entry the cure does not ask, read by a peek ---------------------------
    # zno is asked for real and answers that it cannot.  zgone's file is deleted
    # after it was registered; znox is registered on a file that is not
    # executable; zlate likewise, and its file is made executable afterwards
    # without registering it again.  What registering said is kept out of the log.
    # Nothing can start zgone or znox.  zlate is the other kind: its file can be
    # started by then, and the cure still does not ask it, because it reads what
    # registering recorded and not the file as it is now.  The zlate leg holds
    # what the cure does today (issue 1724, Limits), not that nothing could ask.
    foreach n {zgone znox zlate} { ph_stub $n $::M1 }
    file attributes [file join $::PHBIN znox] -permissions 0644
    file attributes [file join $::PHBIN zlate] -permissions 0644
    test_sim_registry_isolate
    lassign [pd_spy {
        set t {}
        foreach n {zno zgone znox zlate} { lappend t [ase::sim_register $n [file join $::PHBIN $n]] }
        ase::sim_select {}
        set t
    }] regok regsaid
    ase::sim_capabilities_for zno
    file delete -force [file join $::PHBIN zgone]
    file attributes [file join $::PHBIN zlate] -permissions 0755
    ph_forget_runs zno zgone znox zlate
    set fx [list $regok [file exists [file join $::PHBIN zgone]] [file executable [file join $::PHBIN znox]] [file executable [file join $::PHBIN zlate]]]
    set ents [pcall ase::probe_cure_entries ngspice peek]
    set pk1 [pcall ase::probe_cure $st peek]
    set pk2 [pcall ase::probe_cure $st peek before]
    set runs [list [ph_runs zno] [ph_runs zgone] [ph_runs znox] [ph_runs zlate]]
    # ...and a session of `pdmin`, the backend band PL registered without a
    # capability probe.
    ph_registry zcan1
    ph_forget_runs zcan1
    set stpk [pd_state ph_peek_min {} $::AN_OP]
    dict set stpk simulator pdmin
    set mn [list [pcall ase::probe_cure_entries pdmin peek] [pcall ase::probe_cure $stpk peek] [ph_runs zcan1]]
    check {PH12c AN ENTRY THE CURE DOES NOT ASK IS `unknown` AT A PEEK, NOT `untried`: read in peek mode beside an entry that was asked and answered that it cannot -- an entry whose file was deleted after it was registered and one registered on a file that is not executable are each `unknown`; so is one registered as not runnable whose file was made executable afterwards without registering it again -- the cure reads what registering recorded, not the file as it is now (issue 1724, Limits: this leg holds what the cure does today, not that nothing could ask such an entry); the sentence then says none is known to and what to register, with the pick's ending as with the run's, and never that they have not been tried yet; and no program is started.  For a session of a backend that has no way to try a program the one registered entry is `unknown` at a peek too, with the same sentence, and is not started (fixture: what registering each of the four answered, the deleted file is gone, the second is not executable, the third is; then the four verdicts, the two texts, starts of the four; the other backend: the verdict, the text, starts)} \
        [list $fx $ents $pk1 $pk2 $runs $mn] \
        [list {{1 1 0 0} 0 0 1} {{zno cannot} {zgone unknown} {znox unknown} {zlate unknown}} \
              "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM" \
              "None of the simulators you have registered is known to. $::PH_REG before you run, $::PH_AMM" \
              {0 0 0 0} \
              [list {{zcan1 unknown}} "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM" 0]]
    ph_stub zsleep {} -first {exec sleep 30}
    ph_registry zsleep zcan1
    ph_forget_runs zsleep zcan1
    set budget $::ase::cap_budget_ms
    lassign [ph_timed 2000 {ase::probe_cure $st ask}] b1 ms1
    set r1 [list [expr {[ph_runs zsleep] > 0}] [expr {[ph_runs zcan1] > 0}] [expr {$::ase::cap_budget_ms == $budget}]]
    set s1 [ph_runs zsleep]
    set c1 [ph_runs zcan1]
    lassign [ph_timed 2000 {ase::probe_cure $st ask}] b2 ms2
    set r2 [list [expr {[ph_runs zsleep] == $s1}] [expr {[ph_runs zcan1] == $c1}]]
    # the sleeper's file is written again, longer: another program under the same name
    ph_stub zsleep {} -first {exec sleep 30 ; : rebuilt}
    lassign [ph_timed 2000 {ase::probe_cure $st ask}] b2c ms2c
    set s2c [ph_runs zsleep]
    lassign [ph_timed 2000 {ase::probe_cure $st ask}] b2d ms2d
    set r2c [list [expr {$s2c > $s1}] [expr {[ph_runs zsleep] == $s2c}]]
    ase::sim_caps_clear
    lassign [ph_timed 2000 {ase::probe_cure $st ask}] b3 ms3
    check {PH13 THE BOUND, with a registered program that sleeps AHEAD of one that can, and two seconds for one call: the sleeper is not given all of the call -- the first ask cuts it after about half, is over in about that time and not in the probe's whole budget, STARTS THE PROGRAM BEHIND IT IN THE SAME CALL AND NAMES IT, and puts the probe's budget back; the second ask starts neither again and gives the same words, quickly; and once what is remembered about programs is cleared the sleeper is asked again (first: text, at least 0.8 s, under 6 s, sleeper started, the other started, budget restored; second: text, under 0.8 s, sleeper not started again, the other not started again; third: the sleeper started again)} \
        [list $b1 [expr {$ms1 >= 800}] [expr {$ms1 < 6000}] $r1 $b2 [expr {$ms2 < 800}] $r2 [expr {[ph_runs zsleep] > $s2c}]] \
        [list [ph_can zcan1] 1 1 {1 1 1} \
              [ph_can zcan1] 1 {1 1} 1]
    check {PH13c A PROGRAM HELD TO BE SLOW IS ASKED AGAIN WHEN ITS FILE CHANGES: what the cure remembers about a program is kept under the file's stamp, so the sleeper written again under the same name and path is started by the next ask, and not by the one after that (started again after the rewrite, not started by the following ask; the two texts)} \
        [list $r2c $b2c $b2d] [list {1 1} [ph_can zcan1] [ph_can zcan1]]
    ph_registry zno zcan1 zcan2
    ph_forget_runs zno zcan1 zcan2
    lassign [ph_timed 1 {ase::probe_cure $st ask}] b4 ms4
    set r4 [list [ph_runs zno] [ph_runs zcan1] [ph_runs zcan2]]
    set b5 [pcall ase::probe_cure $st ask]
    check {PH13d AN ENTRY THE CALL'S TIME DID NOT REACH IS NOT TRIED YET, not `not known`: with no time to start anything the ask starts none of three registered programs, names all three as not tried yet and does not send the user to register a build; the next ask, with its time, starts them and names the two that can (the first text, starts of the three; the second text)} \
        [list $b4 $r4 $b5] \
        [list [ph_untried {zno, zcan1 and zcan2}] {0 0 0} [ph_can {zcan1 and zcan2}]]
    check {PH13b the time one call of the cure may spend starting programs, as shipped: five seconds, and under the capability probe's own budget, which is what an ask would otherwise cost for one program that never answers; one second of it is kept back for each entry still to be asked; a program is started with no less than a fifth of a second; and a program that did not answer in two seconds of the five is held to be slow} \
        [list $::ase::probe_cure_ms [expr {$::ase::probe_cure_ms < $::ase::cap_budget_ms}] $::ase::probe_cure_each_ms $::ase::probe_cure_min_ms [pcall ase::probe_cure_fair]] {5000 1 1000 200 2000}
    ph_stub zsleep {} -first {exec sleep 30}
    ph_stub znap $::M0 -first {case "$deck" in *probe_a*) sleep 2.6;; esac}
    ph_registry znap zsleep
    ph_forget_runs znap zsleep
    lassign [ph_timed 4000 {ase::probe_cure $st ask}] c1 cms1
    set s1 [ph_runs zsleep]
    lassign [ph_timed 4000 {ase::probe_cure $st ask}] c2 cms2
    set s2 [ph_runs zsleep]
    lassign [ph_timed 4000 {ase::probe_cure $st ask}] c3 cms3
    check {PH14 A PROGRAM IS HELD TO BE SLOW ONLY AFTER A FAIR SHARE OF THE TIME: behind a program that takes well over half of a four-second call -- and answers that it cannot -- the sleeper gets what is left, under the fair share, and is cut; it is NOT held to have given no answer: the call names it as not tried yet, and the next call asks it AGAIN, gives it the whole four seconds, cuts it and only then stops asking and says none is known to (the three texts; the sleeper started by the first call, again by the second, not by the third)} \
        [list $c1 $c2 $c3 [expr {$s1 > 0}] [expr {$s2 > $s1}] [expr {[ph_runs zsleep] == $s2}]] \
        [list [ph_untried zsleep] \
              "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM" \
              "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM" 1 1 1]
    ph_stub zpart $::M1 -first {case "$deck" in *probe_d*) exec sleep 30;; esac}
    ph_registry zpart
    ph_forget_runs zpart
    lassign [ph_timed 2000 {ase::probe_cure $st ask}] d1 dms1
    set have1 [pcall ase::sim_caps_have zpart]
    set s1 [ph_runs zpart]
    set d2 [pcall ase::probe_cure $st peek]
    check {PH15 A MEASUREMENT THE CURE CUT SHORT IS NOT LEFT WHERE A RUN READS IT: a program that answers the question and then hangs on a later deck of the probe is cut by the call's two seconds; its answer to the question is used (it can), nothing about it is left in the capability store, and the verdict is still there for a peek, which starts nothing (the ask's text, the store holds it, the peek's text, starts by the peek)} \
        [list $d1 $have1 $d2 [expr {[ph_runs zpart] - $s1}]] \
        [list [ph_can zpart] 0 [ph_can zpart] 0]
    ph_registry zcan1
    ph_forget_runs zcan1
    set stm [pd_state ph_min {} $::AN_OP]
    dict set stm simulator pdmin
    set e1 [pcall ase::probe_cure $stm ask]
    set n1 [ph_runs zcan1]
    test_sim_registry_isolate
    ase::sim_register zforeign [file join $::PHBIN zcan1] -backend pdmin
    ase::sim_select {}
    check {PH16 for a backend that has no way to try a program, every registered entry is not known and none is started (`is known to`); and an entry registered for another backend is not one of this session's at all, so with only that one the advice stands alone (text and starts; text)} \
        [list $e1 $n1 [pcall ase::probe_cure $st ask]] \
        [list "None of the simulators you have registered is known to. $::PH_REG and run again, $::PH_AMM" 0 \
              "$::PH_REG and run again, $::PH_AMM"]
    set bb [pw_strip [pcall info body ase::ui::build]]
    check {PH17 THE DOOR THE CURE NAMES IS THE REAL ONE: the window's own builder puts an entry labelled `Simulators` and an ellipsis in its Setup menu, bound to the Simulators dialog, and the cure spells the entry as that label is spelled (the builder's one command, whole-line comments dropped; the label in the cure)} \
        [list [regexp {\$top\.mb\.setup add command -label "Simulators\\u2026"\s+-command \[list ase::ui::simulators_dialog \$key\]} $bb] \
              [expr {[string first "under Setup > Simulators… " [ph_can zcan1]] > 0 && [string first "under Setup > Simulators… " [pcall ase::probe_cure $st ask]] > 0}]] {1 1}
    # The window that entry opens has no Detect button: Detect is in the row
    # editor its Edit button opens.  The two builders and the button's own proc
    # are read as text here; the real widgets are pressed in that order on the
    # display arm of test_ase_simwin_variant_1471.
    set sdb [pw_strip [pcall info body ase::ui::simulators_dialog]]
    set seb [pw_strip [pcall info body ase::ui::simdlg_editor]]
    set sde [pw_strip [pcall info body ase::ui::simdlg_edit]]
    ph_registry zcan1
    set u1 [pcall ase::probe_cure $st peek]
    ph_registry zno zcan1
    set u2 [pcall ase::probe_cure $st peek before]
    check {PH17b THE WAY TO DETECT THAT THE CURE NAMES IS THE REAL ONE, AND THESE ARE ITS WORDS: the Simulators dialog is built with a button labelled `Edit` and an ellipsis whose proc opens the row editor for the entry selected in the list, and with no button labelled Detect; the row editor is built with the button labelled `Detect`, bound to the probe of the program in its field; and for entries nobody has asked the cure says to select the entry under that menu entry, press the first button and then the second -- spelled out here for one entry, asked for with the run's ending, and for two, asked for with the pick's, and the sentence carries neither ending (the dialog's Edit button, its proc opening the editor for the selected name, buttons labelled Detect in the dialog's builder and -- the same scan -- in the editor's, the editor's Detect button; the three bodies with whole-line comments dropped; then the two sentences)} \
        [list [regexp {button \$w\.btns\.edit -text \{Edit…\} -command \[list ase::ui::simdlg_edit \$key\]} $sdb] \
              [regexp {set n \[ase::ui::simdlg_selected_name \$key\].*ase::ui::simdlg_editor \$key \$n} $sde] \
              [regexp -all {\-text\s+\{?"?Detect} $sdb] [regexp -all {\-text\s+\{?"?Detect} $seb] \
              [regexp {button \$w\.detect -text Detect -command \[list ase::ui::simdlg_detect \$key\]} $seb] \
              $u1 $u2] \
        [list 1 1 0 1 1 \
              "zcan1 has not been tried yet — the next run finds out whether it can, or select it under Setup > Simulators…, press Edit… and then Detect." \
              "zno and zcan1 have not been tried yet — the next run finds out which of them can, or select each under Setup > Simulators…, press Edit… and then Detect."]

    # ---- how a sentence names the program of a run -----------------------------
    ph_stub ngspice $::M0
    set path0 $::env(PATH)
    set empty [file join $::PHBIN none]
    file mkdir $empty
    test_sim_registry_isolate
    set ::env(PATH) "$::PHBIN:$path0" ; auto_reset
    set nm1 [pcall ase::sim_run_name ngspice]
    ph_registry zno zcan1
    set nm2 [pcall ase::sim_run_name ngspice]
    ase::sim_select zcan1
    set nm3 [pcall ase::sim_run_name ngspice]
    set nm4 [pcall ase::sim_run_name pwsim]
    test_sim_registry_isolate
    set ::env(PATH) $empty ; auto_reset
    set nm5 [pcall ase::sim_run_name ngspice]
    set ::env(PATH) $path0 ; auto_reset
    check {PH20 ase::sim_run_name: the FILE the system finds when nothing is registered and when entries are registered and none is picked; `<entry> (<file>)` for a picked entry; the backend's own word for a backend whose run command does not start what the registry holds, whatever is picked there; and the backend's word when no program of that name can be found at all} \
        [list $nm1 $nm2 $nm3 $nm4 $nm5] \
        [list [file join $::PHBIN ngspice] [file join $::PHBIN ngspice] "zcan1 ([file join $::PHBIN zcan1])" pwsim ngspice]

    # ---- A3: the report, with real names and a real cure -------------------------
    set sto [pd_state ph_old [pd_outs i(x1.xm1:d) 1 0  i(rtop:n1) 1 0] $::AN_OP]
    pd_raw [pd_rawpath $sto] {{{Operating Point} {v(out) i(v1) i(rtop:n1)}}}
    pd_map $sto {{op 0 {Operating Point}}}
    set plan [ase::probe_plan $sto $::NLB fold]
    ph_registry zno zcan1 zcan2
    ase::sim_select zno
    ph_forget_runs zno zcan1 zcan2
    lassign [pd_spy [list ase::probe_report $sto [dict create probes $plan] $::LOGOLD 0]] recs said
    set started [list [expr {[ph_runs zcan1] > 0}] [expr {[ph_runs zcan2] > 0}]]
    lassign [pd_spy [list ase::probe_report $sto [dict create probes $plan simname $::PD_SIM] $::LOGOLD 0]] recs2 said2
    ase::sim_select {}
    set ::env(PATH) "$::PHBIN:$path0" ; auto_reset
    lassign [pd_spy [list ase::probe_report $sto [dict create probes $plan] $::LOGOLD 0]] recs3 said3
    set ::env(PATH) $path0 ; auto_reset
    set cure2 [ph_can {zcan1 and zcan2}]
    check {PH21 THE REPORT'S SENTENCE WITH REAL NAMES: a record with no name for its program names the one in force now -- the picked entry with its file -- and ends with the registered programs that can, asked through the real probe, which the report may start; a record that carries the run's name is named by THAT, whatever is in force by then; and with nothing picked it is the file the system finds (the three lines; the two able programs were started by the first report)} \
        [list [pd_nth $said 1] [pd_nth $said2 1] [pd_nth $said3 1] $started] \
        [list [list [pd_hier {the terminal current i(x1.xm1:d)} "zno ([file join $::PHBIN zno])" $cure2]] \
              [list [pd_hier {the terminal current i(x1.xm1:d)} {} $cure2]] \
              [list [pd_hier {the terminal current i(x1.xm1:d)} [file join $::PHBIN ngspice] $cure2]] {1 1}]
    set kinds {}
    foreach {- k} [regexp -all -inline {lappend (?:said|out) \[list ([a-z]+) } [pw_strip [info body ase::probe_report]]] {
        if {[lsearch -exact $kinds $k] < 0} { lappend kinds $k }
    }
    set hk {}
    regexp {linsert \$said \$hier_at\s+\[list ([a-z]+) } [pw_strip [info body ase::probe_report]] -> hk
    check {PH22 THE REPORT'S KINDS, read off the records its own body makes (whole-line comments dropped): `withheld`, `refused`, `missing` and `note` are appended, `pending` is its record for a card still to be judged, the one record it inserts is `hier` -- and no record is of the kind `oldbuild`, the sentence about the build that stood behind the others until this record took its place} \
        [list [lsort $kinds] $hk] {{missing note pending refused withheld} hier}

    # ---- A4: before the run -------------------------------------------------------
    set plan1 [ase::probe_plan [pd_state ph_s1 [pd_outs i(rtop:n1) 1 0  i(x1.xm1:d) 1 0] $::AN_OP] $::NLB fold]
    set plan2 [ase::probe_plan [pd_state ph_s2 [pd_outs i(x1:out) 1 0  i(x1.xm1:d) 1 0] $::AN_OP] $::NLB fold]
    set plan0 [ase::probe_plan [pd_state ph_s0 [pd_outs i(rtop:n1) 1 0  i(x1.k9:n1) 1 0] $::AN_OP] $::NLB fold]
    ph_registry zno zcan1 zmute
    ase::sim_select zno
    set znop [file join $::PHBIN zno]
    ph_forget_runs zno
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan1 "zno ($znop)"]] a0 said0
    set cold [ph_runs zno]
    ase::sim_capabilities ngspice
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan1 "zno ($znop)"]] a1 said1
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan1 "zno ($znop)"]] a1b said1b
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan2 "zno ($znop)"]] a2 said2
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan0 "zno ($znop)"]] a3 said3
    ase::sim_select zcan1
    ase::sim_capabilities ngspice
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan1 x]] a4 said4
    ase::sim_select zmute
    ase::sim_capabilities ngspice
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan1 x]] a5 said5
    set start1 "ase: zno ($znop), the simulator this run is starting, cannot save the terminal current i(x1.xm1:d): $::PD_LIMIT [ph_can zcan1] This run goes on without that current."
    set start2 "ase: zno ($znop), the simulator this run is starting, cannot save the terminal currents i(x1:out) and i(x1.xm1:d): $::PD_LIMIT [ph_can zcan1] This run goes on without those currents."
    check {PH30 BEFORE THE RUN, ase::probe_start_report: with NOTHING yet known about the program in force it says nothing and starts nothing; once that program is measured unable and the plan holds a terminal that needs the hierarchy it says ONE line, as an error -- the run's name for its program, the terminal, what such a build saves, who can, and that the run goes on -- and says it again for the next run; two such terminals are named together and the run goes on without `those currents`; a plan with none (a top-level device, and a terminal inside a subcircuit that ASE-L wrote no card for) says nothing; a program measured able says nothing; and a program whose answer to the question was never measured is not told it cannot (cold: answer, lines, starts; then: line and tag, said again, the plural line; lines for the plan with none, the able program, the unmeasured one)} \
        [list $a0 $said0 $cold [lindex $said1 0] [expr {$said1b eq $said1 && $a1 eq $start1}] [pd_nth $said2 1] \
              [list $a3 $said3] [list $a4 $said4] [list $a5 $said5]] \
        [list {} {} 0 [list error $start1] 1 [list $start2] {{} {}} {{} {}} {{} {}}]

    # ---- a run on a program measured unable asks the entries, whatever its plan ---
    ph_registry zno zcan1 zmute
    ase::sim_select zno
    ase::sim_capabilities ngspice
    ph_forget_runs zno zcan1 zmute
    set peek0 [pcall ase::probe_cure $st peek before]
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan0 "zno ($znop)"]] w1 wsaid1
    set wr1 [list [ph_runs zno] [expr {[ph_runs zcan1] > 0}] [expr {[ph_runs zmute] > 0}]]
    set peek1 [pcall ase::probe_cure $st peek before]
    set wn1 [list [ph_runs zcan1] [ph_runs zmute]]
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan0 "zno ($znop)"]] w2 wsaid2
    set wr2 [expr {[list [ph_runs zcan1] [ph_runs zmute]] eq $wn1}]
    ph_registry zcan1 zno
    ase::sim_select zcan1
    ase::sim_capabilities ngspice
    ph_forget_runs zno
    lassign [pd_spy [list ase::probe_start_report ngspice $st $plan0 x]] w3 wsaid3
    check {PH35 A RUN ON A PROGRAM MEASURED UNABLE ASKS THE REGISTERED ENTRIES EVEN WHEN ITS PLAN HOLDS NO TERMINAL BELOW THE TOP LEVEL, so that a pick, which starts nothing, can name the one that can: before such a run a pick's cure can only say the other two entries are not tried yet; the run says nothing, does not start the program in force again and starts the other two; the cure a pick reads then names the one that can; the next such run starts nothing more; and a run on a program measured ABLE asks nobody (the cure before; what the run answered and said, starts of the three; the cure after; the second run started nothing; the able run: answer, lines, starts of the untried entry)} \
        [list $peek0 [list $w1 $wsaid1] $wr1 $peek1 $wr2 [list $w3 $wsaid3 [ph_runs zno]]] \
        [list [ph_untried {zcan1 and zmute}] {{} {}} {0 1 1} [ph_can zcan1 {before you run}] 1 {{} {} 0}]

    # ---- what an edit of the registry keeps ----------------------------------------
    ph_stub zsleep {} -first {exec sleep 30}
    ph_registry zno zcan1 zsleep
    lassign [ph_timed 1500 {ase::probe_cure $st ask}] k0 kms0
    set kseen0 [lsort [dict values $::ase::probe_cure_seen]]
    ph_forget_runs zno zcan1 zsleep zcan2
    ph_stub zcan2 $::M1
    ase::sim_register zagain [file join $::PHBIN zcan1]
    ase::sim_register zcan2 [file join $::PHBIN zcan2]
    ase::sim_select {}
    set kstore [dict size $::ase::sim_caps]
    set kent [pcall ase::probe_cure_entries ngspice peek]
    set kpeek [pcall ase::probe_cure $st peek]
    set kruns [list [ph_runs zno] [ph_runs zcan1] [ph_runs zsleep] [ph_runs zcan2]]
    ase::sim_unregister zagain
    ase::sim_select {}
    set kent2 [pcall ase::probe_cure_entries ngspice peek]
    ph_stub zcan1 $::M0 -last {: rebuilt, and it cannot any more}
    set kent3 [pcall ase::probe_cure_entries ngspice peek]
    ph_stub zcan1 $::M1
    check {PH36 WHAT AN EDIT OF THE REGISTRY KEEPS: registering an entry and removing one both empty the capability store, as they did, and carry over what the cure knows about which program can and which cannot -- so a click after the edit still names the entry that can, a NEW entry for the same program started with the same words is named with it, the new entry for a program nobody has asked is not tried yet, and nothing is started to say so; the program held to be slow is NOT carried and is to be tried again; and what is carried is kept under the file's stamp, so the able program written again is not tried yet either (fixture: the ask before the edit names the able entry and holds the sleeper slow; then: answers in the store after the edit, the entries a click reads, the cure's words, starts of the four programs; the entries after the removal; the entries after the able program's file changed)} \
        [list [list $k0 $kseen0] $kstore $kent $kpeek $kruns $kent2 $kent3] \
        [list [list [ph_can zcan1] slow] 0 \
              {{zno cannot} {zcan1 can} {zsleep untried} {zagain can} {zcan2 untried}} \
              [ph_can {zcan1 and zagain}] {0 0 0 0} \
              {{zno cannot} {zcan1 can} {zsleep untried} {zcan2 untried}} \
              {{zno cannot} {zcan1 untried} {zsleep untried} {zcan2 untried}}]
}

# ---- A3 and A4 through the real run door, on a registered stand-in -------------
# The stand-in answers the capability probe with 0 and, handed the run's own
# deck, prints what such a build prints: a refusal of the device inside the
# subcircuit and the marker's 0.  So ase::run_deck, ase::cap_report, the
# completion callback and ase::run_done all run for real, through the ngspice
# adapter's own run command, with no simulator.
group PH-run {
    set st [pd_state phrun [pd_outs i(x1.xm1:d) 1 0  i(rtop:n1) 1 0  v(out) 1 0] $::AN_OP]
    set d [dict get $st rundir]
    set nlf [file join $d phrun.spice]
    pd_wr $nlf $::NLB
    set canlog [file join $d canned.log]
    pd_wr $canlog "Warning: Could not find the instance line for x1.xm1,\n   .probe i(x1.xm1,d) will be ignored\n$::M0\n"
    ph_stub zrun $::M0 -first "case \"\$deck\" in *_ase.spice) cat '$canlog'; exit 0;; esac"
    ph_registry zrun zcan1
    ase::sim_select zrun
    set zrunp [file join $::PHBIN zrun]
    proc ph_go {st nlf} {
        set r [pd_spy [list apply {{st nlf} { pw_wait [ase::run_deck $st $nlf] }} $st $nlf]]
        catch {ase::run_lock_clear [ase::run_lock_key $st]}
        return $r
    }
    proc ph_mine {said} {
        set out {}
        foreach s $said {
            if {[regexp {cannot save|simulation finished|REFUSED} [lindex $s 1]]} { lappend out $s }
        }
        return $out
    }
    set ::ph_calls {}
    rename ::ase::probe_report ::ph_real_report
    proc ::ase::probe_report {args} { lappend ::ph_calls $args ; return [::ph_real_report {*}$args] }
    lassign [ph_go $st $nlf] rc1 said1
    rename ::ase::probe_report {}
    rename ::ph_real_report ::ase::probe_report
    lassign [ph_go $st $nlf] rc2 said2
    set who "zrun ($zrunp)"
    set want [list \
        [list error "ase: $who, the simulator this run is starting, cannot save the terminal current i(x1.xm1:d): $::PD_LIMIT [ph_can zcan1] This run goes on without that current."] \
        [list error [pd_hier {the terminal current i(x1.xm1:d)} $who [ph_can zcan1]]]]
    check {PH31 THROUGH ase::run_deck, on a registered program measured unable whose deck asks for a device inside a subcircuit: the run is NOT refused and ends with exit 0; BEFORE it starts the one line says the program this run is starting cannot save that terminal, who can and that the run goes on without it; AFTER it the report says the same of the program this run started, both as errors, both naming the picked entry and its file, in that order and ahead of the finish line; and the next run says both again (first run: exit, the two lines, the last of the three is the finish line; second run: exit, the same two lines)} \
        [list $rc1 [lrange [ph_mine $said1] 0 1] [string match {ase: simulation finished (exit 0)*} [lindex [lindex [ph_mine $said1] 2] 1]] \
              $rc2 [lrange [ph_mine $said2] 0 1]] \
        [list 0 $want 1 0 $want]
    set lines {}
    foreach s $said1 { lappend lines [lindex $s 1] }
    set using [lsearch -glob $lines {This run is starting the simulator you named zrun*}]
    set before [lsearch -glob $lines {*the simulator this run is starting, cannot save*}]
    check {PH32 the line before the run stands directly under the one that says which registered simulator this run is starting, which names the same program (the two places in what the run said, the first found)} \
        [list [expr {$using >= 0}] [expr {$before - $using}]] {1 1}
    # The picked simulator is changed while the report is being made: the
    # record still says what the run started.
    ase::sim_select zcan1
    lassign [pd_spy [list ase::probe_report {*}[lindex $::ph_calls 0]]] recs33 said33
    ase::sim_select zrun
    check {PH33 THE RUN'S RECORD CARRIES THE NAME ITS PROGRAM HAD WHEN THE RUN STARTED, and the report names the program by it: the record ase::run_done handed the report holds that name, and the same record reported again with ANOTHER simulator picked still names the program the run started (the record's name; the line of the second report)} \
        [list [ase::state_get [lindex [lindex $::ph_calls 0] 1] simname NOKEY] [pd_nth $said33 1]] \
        [list $who [list [pd_hier {the terminal current i(x1.xm1:d)} $who [ph_can zcan1]]]]
    # What the last run's report said is kept for Direct Plot; a run that
    # starts on the same results file empties it BEFORE its own report, so a
    # run whose report never comes leaves nothing of the earlier one behind.
    set rawkey [ase::run_lock_key $st]
    set kept1 [list [ase::state_get $::ase::last_probes raw] [dict keys [ase::state_get $::ase::last_probes hier]] [ase::state_get $::ase::last_probes sim]]
    rename ::ase::probe_report ::ph_real_report
    proc ::ase::probe_report {args} { error "a report that never comes" }
    lassign [ph_go $st $nlf] rc34 said34
    rename ::ase::probe_report {}
    rename ::ph_real_report ::ase::probe_report
    set kept2 $::ase::last_probes
    ase::probe_said_keep $st {} {} {i(x1.xm1:d)} {} $who
    set other [pd_state phrun_other {} $::AN_OP]
    ase::probe_said_clear [ase::run_lock_key $other]
    set kept3 [dict keys [ase::state_get $::ase::last_probes hier]]
    check {PH34 WHAT THE LAST REPORT SAID IS KEPT UNDER ITS RESULTS FILE AND EMPTIED WHEN A RUN STARTS ON THAT FILE: after the run above the record names this run's results file, the terminal its simulator cannot save and the program; a further run on the same file whose report raises leaves the record EMPTY -- emptied at the start, not by the report -- and still ends at exit 0; and a clear for another results file leaves a record alone (the record after the run; the failed-report run's exit and the record after it; the record after a clear for another file)} \
        [list $kept1 $rc34 $kept2 $kept3] \
        [list [list $rawkey i(x1.xm1:d) $who] 0 {} i(x1.xm1:d)]
    # A session holds the state the run is started with, and a row is added to
    # that session WHILE THE SIMULATOR IS RUNNING: when the report is made, no
    # session holds the state the run was handed.
    set skey [ase::new_session pd phrun schematic]
    ase::session_update $skey $st
    set held0 [ase::session_holding $st]
    set ::ph_calls {}
    set ::ph_held {}
    rename ::ase::probe_report ::ph_real_report
    proc ::ase::probe_report {args} {
        lappend ::ph_calls $args
        lappend ::ph_held [::ase::session_holding [lindex $args 0]]
        return [::ph_real_report {*}$args]
    }
    lassign [pd_spy [list apply {{st nlf key} {
        set id [ase::run_deck $st $nlf]
        set s2 $st
        dict set s2 outputs [concat [dict get $st outputs] [pd_outs i(x1:out) 1 0]]
        ase::session_update $key $s2
        pw_wait $id
    }} $st $nlf $skey]] rc37 said37
    catch {ase::run_lock_clear [ase::run_lock_key $st]}
    rename ::ase::probe_report {}
    rename ::ph_real_report ::ase::probe_report
    set rec37 [ase::state_get [lindex [lindex $::ph_calls 0] 1] session NOKEY]
    set kept37 [ase::state_get $::ase::last_probes session NOKEY]
    set moved37 [expr {[ase::session_state $skey] ne $st}]
    catch {ase::session_close $skey}
    check {PH37 THE RUN'S RECORD CARRIES THE SESSION THAT ASKED FOR THE RUN, TAKEN WHEN THE RUN STARTS: a session holds the state ase::run_deck is handed; while the simulator is running a row is added to that session, so that when the report is made the session's state is another and no session holds the state the run was started with; the record ase::run_done hands the report names the session all the same, and so does what the report keeps for Direct Plot -- where asking who holds that state at report time answers nobody (fixture: the session holding the state before the run, the run's exit, the session's state moved, who holds the run's state when the report is made; then the record's session, the session the report kept)} \
        [list $held0 $rc37 $moved37 $::ph_held $rec37 $kept37] \
        [list $skey 0 1 {{}} $skey $skey]
}
# The bands below run against the empty registry the suite started with.
test_sim_registry_isolate
check {PH99 fixture: the stand-ins of band PH are out of the simulator registry again, and nothing is remembered about any program} \
    [list [test_sim_registry_state] [dict size $::ase::sim_caps] [dict size $::ase::probe_cure_seen]] {{0 {} {} path} 0 0}

# =============================================================================
# PA -- THE OTHER READERS OF AN OUTPUT ROW, FOR A TERMINAL ROW
# =============================================================================
set FIXOP   [file join $here data probe_1724_op.raw]
set FIXTRAN [file join $here data probe_1724_tran.raw]
group PA {
    check {PA0 fixture: the two committed results files of probe_1724.cir are there} \
        [list [file isfile $::FIXOP] [file isfile $::FIXTRAN]] {1 1}
    # ---- the Value column ---------------------------------------------------
    set outs [pd_outs i(x1.xm1:d) 1 0  -i(x1.xm1:d) 0 0  i(x1.r1:n1) 0 0  {idc(x1.xm1:d) idc(x1.r1:n1) +} 0 0  i(x1:in) 0 0]
    set st [pd_state pa_op $outs $::AN_OP]
    file copy -force $::FIXOP [pd_rawpath $st]
    lassign [pd_spy [list [ase::backend_hook ngspice result_probe] $st {}]] res said
    set fd {}
    foreach pl [ase::raw_scalars [pd_rawpath $st]] {
        foreach {nm v} [lindex $pl 1] { dict set fd $nm $v }
    }
    set d  [dict get $fd i(x1.xm1:d)]
    set r1 [dict get $fd i(x1.r1:n1)]
    check {PA1 VALUE, operating point: a terminal row shows the file's own number, its negation shows the negated number, and an expression over two terminals their sum -- all three computed here from the file's two vectors} \
        [list [ase::state_get $res r0] [ase::state_get $res r1] [ase::state_get $res r2] [ase::state_get $res r3]] \
        [list [format %.6e $d] [format %.6e [expr {-$d}]] [format %.6e $r1] [format %.6e [expr {$d + $r1}]]]
    check {PA2 DISTINCTNESS: the two vectors differ by far more than the six digits shown, and neither is zero, so no row above could pass by reading the other's number or a blank} \
        [list [expr {abs($d - $r1) > 1e-3 * abs($d)}] [expr {$d != 0.0}] [expr {$r1 != 0.0}] \
              [expr {[format %.6e $d] ne [format %.6e $r1]}]] {1 1 1 1}
    set stt [pd_state pa_tran [pd_outs i(x1.xm1:d) 1 1  it(x1.xm1:d) 0 1  {it(x1.xm1:d) 2 *} 0 1] \
               {{type op enabled 0} {type tran enabled 1 stop 10n step 1n}}]
    file copy -force $::FIXTRAN [pd_rawpath $stt]
    lassign [pd_spy [list [ase::backend_hook ngspice result_probe] $stt {}]] rest said
    check {PA3 VALUE, transient only: a terminal row, its `it()` spelling and an expression over it each read `wave` -- the Calculator finds the vector by the row's own `:` spelling} \
        [list [ase::state_get $rest r0] [ase::state_get $rest r1] [ase::state_get $rest r2]] {wave wave wave}
    # ---- the rows the viewer is asked to draw --------------------------------
    set key [ase::new_session pd pa_tran schematic]
    ase::session_update $key $stt
    ase::session_setattr $key results $rest
    set t [pcall ase::ui::plot_targets $key]
    check {PA4 PLOT: all three Plot-ticked terminal rows are among the rows the viewer is asked to draw after a transient run, and none is refused (exprs offered, refusals)} \
        [list [pd_col [ase::state_get $t rows] expr] [ase::state_get $t refused]] \
        [list {i(x1.xm1:d) it(x1.xm1:d) {it(x1.xm1:d) 2 *}} {}]
    catch {ase::session_close $key}
    # ---- a design-variable sweep --------------------------------------------
    set dvrow {type dc enabled 1 swkind variable source rv start 500 stop 1500 step 500}
    set stv [pd_state pa_dcvar [pd_outs i(x1.r1:n1) 1 0  i(rtop:n1) 1 0  v(out) 1 0] [list $dvrow]]
    dict set stv variables {{name rv value 1k}}
    set refs [pcall ase::backend::ngspice::dcvar_output_refusals $stv $dvrow]
    check {PA5 DESIGN-VARIABLE SWEEP: each terminal row gets the sweep's own advice that it cannot carry it -- one inside a subcircuit, one the loop cannot copy -- and the node row gets none (rows named, then the two reasons)} \
        [list [lmap r $refs { lindex $r 0 }] \
              [string match {*a current inside a subcircuit*} [lindex [lindex $refs 0] 1]] \
              [string match {*a current the simulator cannot copy*} [lindex [lindex $refs 1] 1]]] \
        {{i(x1.r1:n1) i(rtop:n1)} 1 1}
    check {PA6 ...and that bench is not refused before the run: the gate passes and the deck renders with its card} \
        [list [string match ERR:* [lindex [pd_spy [list ase::preflight_gate $stv ".param rv=1k\n$::NLB"]] 0]] \
              [pd_lines [pd_deck $stv ".param rv=1k\n$::NLB"] {^\.probe}]] {0 {{.probe I(x1.r1,1) I(rtop,1)}}}
    # ---- the optimizer export -------------------------------------------------
    set m [pcall ase::optexport_measures $st]
    check {PA7 OPTIMIZER EXPORT: every terminal row is a measure, read from the results file when it is one vector and by the Calculator otherwise -- none is dropped or refused (name and reader per row)} \
        [lmap r [lindex $m 0] { list [ase::state_get $r name] [ase::state_get $r reader] }] \
        {{r0 raw} {r1 calc} {r2 raw} {r3 calc} {r4 raw}}

    # ---- the note about rows with no value -------------------------------------
    # After a run the pane says which one-signal rows have no single-point
    # value, and why: `a multi-point vector is not a scalar, and a run that
    # computed nothing writes only the constants plot`.  Neither reason holds
    # for a terminal whose vector is not in the file at all.
    proc pa_notes {st} {
        lassign [pd_spy [list [ase::backend_hook ngspice result_probe] $st {}]] res said
        set out {}
        foreach s $said {
            if {[string match {ase: result -- the results file holds no single-point value*} [lindex $s 1]]} {
                lappend out [lindex $s 1]
            }
        }
        return $out
    }
    set outs [pd_outs i(x1.nope:n1) 1 0  i(x1.c1:n1) 0 0  i(rtop:n1) 1 0  v(out) 1 0  v(nosuch) 1 0  {i("x9.r1:n2")} 1 0]
    set stn [pd_state pa_note $outs $::AN_OP]
    pd_raw [pd_rawpath $stn] {{{Operating Point} {v(out) i(v1) i(rtop:n1)}}}
    check {PA8 THE NOTE ABOUT ROWS WITH NO VALUE LEAVES OUT A TERMINAL WHOSE VECTOR IS NOT IN THE FILE -- a ticked one the run did not make, a quoted one, and a Saves row that is switched off and asked for nothing: what came of a terminal is the probe report's to say. The node that is not in the file is still named, alone (the notes spoken, whole)} \
        [pa_notes $stn] \
        [list {ase: result -- the results file holds no single-point value for v(nosuch), so that row has no value: a multi-point vector is not a scalar, and a run that computed nothing writes only the constants plot.}]
    check {PA8b ...and with no other row lacking a value the note is not spoken at all (a bench of absent terminals and present rows only)} \
        [pa_notes [apply {{} {
            set st [pd_state pa_note2 [pd_outs i(x1.nope:n1) 1 0  i(rtop:n1) 1 0  v(out) 1 0] $::AN_OP]
            pd_raw [pd_rawpath $st] {{{Operating Point} {v(out) i(v1) i(rtop:n1)}}}
            return $st }}]] {}
    lassign [pd_spy [list ase::backend::ngspice::result_probe_raw $stn fold]] rr saidr
    check {PA8d the rawfile reader, asked on its own, speaks the same note with the same rows left out (the lines it speaks)} \
        [pd_nth $saidr 1] \
        [list {ase: result -- the results file holds no single-point value for v(nosuch), so that row has no value: a multi-point vector is not a scalar, and a run that computed nothing writes only the constants plot.}]
    set recs [pcall ase::backend::ngspice::result_answers $stn fold]
    check {PA8e the typed record of each such row (what the optimizer export hands on, with no probe report beside it) carries its own true sentence: the absent terminals say the file holds no vector for them and why a vector would be there, the absent node keeps the note's sentence; all four have no value (status per row; the message of the first terminal, of the switched-off one, of the node; the quoted one's opening)} \
        [list [lmap r $recs { dict get $r status }] \
              [dict get [lindex $recs 0] msg] [dict get [lindex $recs 1] msg] [dict get [lindex $recs 4] msg] \
              [string match {ase: result -- the results file holds no vector for the terminal current i("x9.r1:n2"), *} [dict get [lindex $recs 5] msg]]] \
        [list {novalue novalue number number novalue novalue} \
              {ase: result -- the results file holds no vector for the terminal current i(x1.nope:n1), so that row has no value: the simulator makes that vector only for a .probe card it accepts.} \
              {ase: result -- the results file holds no vector for the terminal current i(x1.c1:n1), so that row has no value: the simulator makes that vector only for a .probe card it accepts.} \
              {ase: result -- the results file holds no single-point value for v(nosuch), so that row has no value: a multi-point vector is not a scalar, and a run that computed nothing writes only the constants plot.} 1]
    file delete [pd_rawpath $stn]
    check {PA8f ...and with NO results file there is nothing known about any row, and the record keeps the note's sentence for a terminal too (the message of the first terminal row)} \
        [dict get [lindex [pcall ase::backend::ngspice::result_answers $stn fold] 0] msg] \
        {ase: result -- the results file holds no single-point value for i(x1.nope:n1), so that row has no value: a multi-point vector is not a scalar, and a run that computed nothing writes only the constants plot.}
    # A terminal the file DOES hold, in two multi-point plots and no operating
    # point: the Calculator will not choose between them, the row has no
    # value, and the note's first reason is exactly why.
    set st2 [pd_state pa_note3 [pd_outs i(rtop:n1) 1 0  i(x1.nope:n1) 1 0  {i("rtop:n1")} 1 0] \
               {{type op enabled 0} {type ac enabled 1 sweep dec points 2 start 1k stop 10k} {type tran enabled 1 stop 10n step 1n}}]
    set two {}
    foreach {pn sw} {{AC Analysis} frequency {Transient Analysis} time} {
        append two "Title: pd\nDate: none\nPlotname: $pn\nFlags: real\nNo. Variables: 2\nNo. Points: 2\nVariables:\n\t0\t$sw\t$sw\n\t1\ti(rtop:n1)\tcurrent\nValues:\n 0\t0\n\t0.5\n 1\t1\n\t0.25\n"
    }
    pd_wr [pd_rawpath $st2] $two
    check {PA8c a terminal the file holds only as multi-point vectors, in two plots, STAYS in the note -- for it the note's first reason is the fact -- under its plain spelling and under the quoted one, while the absent terminal between them is left out (fixture: the file holds the one and not the other; then the notes)} \
        [list [llength [ase::raw_vectors_present [pd_rawpath $st2] {i(rtop:n1)}]] \
              [llength [ase::raw_vectors_present [pd_rawpath $st2] {i(x1.nope:n1)}]] [pa_notes $st2]] \
        [list 1 0 [list {ase: result -- the results file holds no single-point value for i(rtop:n1), i("rtop:n1"), so those rows have no value: a multi-point vector is not a scalar, and a run that computed nothing writes only the constants plot.}]]
}

# =============================================================================
# PN -- THE REAL SIMULATOR, WITH THE PROBE EXTENSION
# =============================================================================
# Candidates, in order: $ASE_PROBE_NGSPICE, every program in the tester's own
# registry (read from the file, never loaded), and the fork's usual place.
# Each candidate is COPIED into the suite's scratch and asked there; the first
# copy that answers 1 is used for every row, so a rebuild of the original
# while the suite runs changes nothing.
#
# THE COPY IS OF THE FILE THE CANDIDATE RESOLVES TO.  `file copy` copies a
# symbolic link as a link: an absolute one would leave a link in the scratch
# and every row would run the original in place, and a relative one would
# point nowhere from there and the candidate would be dropped.  `file
# normalize` follows every link of a path but one in its LAST component, so
# the candidate is normalized with one more component behind it and that
# component is taken off again.
proc pn_copy {src dst} {
    file copy -force [file dirname [file normalize [file join $src __pn_copy__]]] $dst
}
proc pn_exec {deckfile args} {
    set rc [catch {exec env -u DISPLAY HOME=$::pn_home timeout 60 $::NG -b {*}$args $deckfile 2>@1} log]
    return [list $rc $log]
}
# `want` is the answer looked for: 1 for a program with the probe extension
# (the default), 0 for one without -- then the program of that name on the
# PATH and /usr/bin/ngspice are looked at first.
proc pn_find {{want 1}} {
    set cand {}
    if {$want == 1 && [info exists ::env(ASE_PROBE_NGSPICE)] && $::env(ASE_PROBE_NGSPICE) ne {}} {
        lappend cand $::env(ASE_PROBE_NGSPICE)
    }
    if {$want == 0} {
        set onpath [lindex [auto_execok ngspice] 0]
        if {$onpath ne {}} { lappend cand $onpath }
        lappend cand /usr/bin/ngspice
    }
    set rf [file join [test_real_home] .xschem ase_simulators]
    if {[file readable $rf]} {
        foreach ln [split [pd_rd $rf] "\n"] {
            if {[regexp {^\s*ase::sim_reg[i]ster\s+(\S+)\s+(\S+)} $ln -> nm path]} { lappend cand $path }
        }
    }
    if {$want == 1} { lappend cand [file join [test_real_home] dev ngspice-ver_53 build-ver_53 src ngspice] }
    set d [file join $::scratch ng]
    file mkdir $d
    set ::pn_home [file join $::scratch nghome]
    file mkdir $::pn_home
    set cf [file join $d cap.cir]
    pd_wr $cf "* capability\nv1 a 0 1\nr1 a 0 1k\n.control\necho @@probe_version=\$?probe_version\n.endc\n.end\n"
    set looked {}
    set k 0
    foreach b $cand {
        if {[lsearch -exact $looked $b] >= 0} continue
        lappend looked $b
        if {![file isfile $b] || ![file executable $b]} continue
        set copy [file join $d ngspice_${want}_$k]
        incr k
        if {[catch {pn_copy $b $copy}]} continue
        catch {exec env -u DISPLAY HOME=$::pn_home timeout 60 $copy -b $cf 2>@1} out
        if {[regexp -line "^@@probe_version=$want\\s*\$" $out]} { return [list $copy $looked] }
        catch {file delete -force $copy}
    }
    return [list {} $looked]
}
# The variables of one plot of a results file, {} when it has none such.
proc pn_vars {raw plot} {
    return [lindex [ase::cap_plot [ase::cap_raw_plots $raw] $plot] 2]
}
proc pn_np {raw plot} {
    return [lindex [ase::cap_plot [ase::cap_raw_plots $raw] $plot] 1]
}
# Render `st` over `nl`, write the deck, run it: -> {rc log deck rawpath}.
proc pn_bench {st nl args} {
    set deck [pd_deck $st $nl]
    set d [dict get $st rundir]
    set df [file join $d deck.cir]
    pd_wr $df $deck
    lassign [pn_exec $df {*}$args] rc log
    return [list $rc $log $deck [pd_rawpath $st]]
}
proc pn_scalar {raw name} {
    foreach pl [ase::raw_scalars $raw] {
        foreach {nm v} [lindex $pl 1] { if {$nm eq $name} { return $v } }
    }
    return NOVECTOR
}

# =============================================================================
# PE -- FROM A CLICK ON THE SHEET TO THE VECTOR, ON THE SAME SIMULATOR
# =============================================================================
# The whole road, once.  A session is bound to a sheet; the pick mode is armed
# by hand, as Outputs > To Be Saved > Select On Design arms it; each click is
# ase::ui::sod_click on a pin; the row is whatever the real ase::ui::sod_queue
# then wrote into the session; the netlist is the one xschem's own netlister
# makes of the sheet (ase::netlist); the deck is the real `render_deck` hook's
# for that session; it is run on the simulator copy; and each picked current is
# read back out of the results.  The bands above start from a row somebody
# typed and a netlist somebody wrote, and test_ase_terminal_pick_1724 stops at
# the row: only here does the name the PICK built have to be the name the
# SIMULATOR writes.
#
# THE BENCH is a library of its own, written as text into the scratch:
#   pe_top  V1 puts 1 V on net g.  RT is 1 k from g to ground.  RW is a
#           resistor WRAPPER, 2 k from g to ground: its symbol's pins are
#           M P B and the subcircuit it calls names its ports r0 r1 sub.  M9
#           is a FET wrapper of W=2 with its gate on g, under RD (10 k from
#           g).  x1 and the two-bit bus instance xb[1:0] are the block pe_blk
#           with pin A on g.
#   pe_blk  pins A and Y.  R1 from A to Y and R2 from Y to ground, 10 k each,
#           and M1, the same FET wrapper with W=1, gate and drain on A.
# The model file holds the two wrappers' subcircuits and a level-1 MOSFET (vto
# 0.5, kp 100u, W/L = the wrapper's W, no channel-length modulation), which at
# 1 V on its gate carries 12.5 uA per unit of W.  So every picked current is a
# number its row can write down: 1 mA into RT, 0.5 mA into the wrapper's M pin,
# 25 uA into M9's drain, 50 uA into R1 and 12.5 uA into M1's drain inside the
# block, and their sum, 62.5 uA, into pin A of each instance of the block.
#
# The session names the model file in an `includes` row.  That one row is both
# where the pick finds the wrappers' `.subckt` headers (no netlist exists yet
# when the clicks are made) and what puts the file in the deck.
proc pe_fixture {} {
    set lib [file join $::scratch pelib]
    file mkdir $lib
    set symh "v {xschem version=3.4.8RC file_version=1.3}\nG {}"
    set symt "V {}\nS {}\nF {}\nE {}\nL 4 -40 -20 40 -20 {}\nL 4 -40 20 40 20 {}"
    set schh "v {xschem version=3.4.8RC file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nF {}\nE {}"
    pd_wr [file join $lib pe_blk.sym] "$symh
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
$symt
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout}
B 5 37.5 -2.5 42.5 2.5 {name=Y dir=inout}
"
    pd_wr [file join $lib pe_fet.sym] "$symh
K {type=nmos
format=\"@spiceprefix@name @pinlist @model W=@W\"
template=\"name=M1 model=pe_nfet spiceprefix=X W=1\"}
$symt
B 5 17.5 -32.5 22.5 -27.5 {name=D dir=inout}
B 5 -22.5 -2.5 -17.5 2.5 {name=G dir=in}
B 5 17.5 27.5 22.5 32.5 {name=S dir=inout}
B 5 17.5 -2.5 22.5 2.5 {name=B dir=in}
"
    pd_wr [file join $lib pe_rwrap.sym] "$symh
K {type=resistor
format=\"@spiceprefix@name @pinlist @model\"
template=\"name=R1 model=pe_res spiceprefix=X\"}
$symt
B 5 -2.5 -32.5 2.5 -27.5 {name=M dir=inout}
B 5 -2.5 27.5 2.5 32.5 {name=P dir=inout}
B 5 -22.5 -2.5 -17.5 2.5 {name=B dir=inout}
"
    pd_wr [file join $lib pe_blk.sch] "$schh
N 0 0 100 0 {}
N 100 0 150 0 {}
N 150 0 220 0 {}
N 150 0 150 30 {}
N 150 30 180 30 {}
N 100 60 100 80 {}
N 100 80 100 100 {}
N 100 80 300 80 {}
N 100 160 100 190 {}
N 220 60 220 100 {}
N 220 30 260 30 {}
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=A}
C {devices/opin.sym} 300 80 0 0 {name=p2 lab=Y}
C {devices/res.sym} 100 30 0 0 {name=R1 value=10k}
C {devices/res.sym} 100 130 0 0 {name=R2 value=10k}
C {devices/gnd.sym} 100 190 0 0 {name=l1 lab=0}
C {pe_fet.sym} 200 30 0 0 {name=M1 model=pe_nfet spiceprefix=X W=1}
C {devices/gnd.sym} 220 100 0 0 {name=l2 lab=0}
C {devices/gnd.sym} 260 30 0 0 {name=l3 lab=0}
"
    pd_wr [file join $lib pe_top.sch] "$schh
N 0 -30 0 -60 {}
N 0 30 0 60 {}
N 200 -30 200 -60 {}
N 200 30 200 60 {}
N 400 -30 400 -60 {}
N 400 30 400 60 {}
N 380 0 360 0 {}
N 620 -120 620 -150 {}
N 620 -30 620 -60 {}
N 580 0 540 0 {}
N 620 30 620 60 {}
N 620 0 660 0 {}
N 760 0 720 0 {}
N 840 0 880 0 {}
N 960 0 920 0 {}
N 1040 0 1080 0 {}
C {devices/vsource.sym} 0 0 0 0 {name=V1 value=1}
C {devices/lab_pin.sym} 0 -60 0 0 {name=l1 sig_type=std_logic lab=g}
C {devices/gnd.sym} 0 60 0 0 {name=l2 lab=0}
C {devices/res.sym} 200 0 0 0 {name=RT value=1k}
C {devices/lab_pin.sym} 200 -60 0 0 {name=l3 sig_type=std_logic lab=g}
C {devices/gnd.sym} 200 60 0 0 {name=l4 lab=0}
C {pe_rwrap.sym} 400 0 0 0 {name=RW model=pe_res spiceprefix=X}
C {devices/lab_pin.sym} 400 -60 0 0 {name=l5 sig_type=std_logic lab=g}
C {devices/gnd.sym} 400 60 0 0 {name=l6 lab=0}
C {devices/gnd.sym} 360 0 0 0 {name=l7 lab=0}
C {pe_fet.sym} 600 0 0 0 {name=M9 model=pe_nfet spiceprefix=X W=2}
C {devices/res.sym} 620 -90 0 0 {name=RD value=10k}
C {devices/lab_pin.sym} 620 -150 0 0 {name=l8 sig_type=std_logic lab=g}
C {devices/lab_pin.sym} 540 0 0 0 {name=l9 sig_type=std_logic lab=g}
C {devices/gnd.sym} 620 60 0 0 {name=l10 lab=0}
C {devices/gnd.sym} 660 0 0 0 {name=l11 lab=0}
C {pe_blk.sym} 800 0 0 0 {name=x1}
C {devices/lab_pin.sym} 720 0 0 0 {name=l12 sig_type=std_logic lab=g}
C {devices/lab_pin.sym} 880 0 0 0 {name=l13 sig_type=std_logic lab=y1}
C {pe_blk.sym} 1000 0 0 0 {name=xb\[1:0\]}
C {devices/lab_pin.sym} 920 0 0 0 {name=l14 sig_type=std_logic lab=g}
C {devices/lab_pin.sym} 1080 0 0 0 {name=l15 sig_type=std_logic lab=ob\[1:0\]}
"
    set mod [file join $::scratch pe_models.spice]
    pd_wr $mod "* the subcircuits behind the wrapper symbols of the end-to-end bench
.subckt pe_res r0 r1 sub
R1 r0 r1 2k
.ends
.subckt pe_nfet d g s b w=1
M1 d g s b pe_nm W={w*1u} L=1u
.ends
.model pe_nm nmos level=1 vto=0.5 kp=100u
"
    return [list $lib $mod]
}
# The point of a pin, from a door that is not the pick's own:
# instance_pin_coord answers {name x y}.
proc pe_pin {inst pin} { return [lrange [pcall xschem instance_pin_coord $inst name $pin] 1 2] }
# The pin test's radius is 12 * zoom * tk-scaling sheet units, and both factors
# differ between a sheet's opening view on the two arms.  Put it at 6 units, so
# what a click answers does not depend on the view the sheet happened to open
# with.
proc pe_zoom {} {
    set k [expr {[info commands tk] ne {} ? [tk scaling] : 1.0}]
    xschem origin - - [expr {6.0 / (12.0 * $k)}]
}
# One mode click on a pin's own point, through the real sod_click and the real
# sod_queue: -> {<the rows the session's outputs gained> <what the click said
# besides its "queued" lines>}.  A click that raises answers its error in the
# second place.
proc pe_click {key inst pin} {
    set before [pd_col [ase::state_get [ase::session_state $key] outputs] expr]
    lassign [pd_spy [list ase::ui::sod_click $key {*}[pe_pin $inst $pin]]] r said
    set after [pd_col [ase::state_get [ase::session_state $key] outputs] expr]
    set other {}
    if {[string match ERR:* $r]} { lappend other $r }
    foreach s $said {
        if {![string match {ase: queued output *} [lindex $s 1]]} { lappend other [lindex $s 1] }
    }
    return [list [lrange $after [llength $before] end] $other]
}
# Is `sig` a vector of plot `plot` of the results file?  1/0, never a raise.
proc pe_has {raw sig plot} {
    return [expr {![catch {ase::raw_vectors_present $raw [list $sig] $plot} r] && [llength $r] == 1}]
}
# Does the loaded results database resolve `name`?  1 only for an index that
# is an integer and not negative: with no database loaded `xschem raw index`
# raises, and an error text must not read as "found".
proc pe_idx {name} {
    set i [pcall xschem raw index $name]
    return [expr {[string is integer -strict $i] && $i >= 0}]
}
# Is `v` a number within 1e-9 A of `want`?  (Where two picked currents of the
# bench differ at all they differ by 12.5 uA or more, far outside this door;
# the instances of the block draw one and the same current by construction.)
proc pe_near {v want} {
    return [expr {[string is double -strict $v] && abs($v - $want) <= 1e-9}]
}
# What the run's results say of one picked row `sig`, four answers, each 1/0:
# it is a vector of the operating point; of the transient; the file's number
# for it at the operating point is `want`; and the results DATABASE -- loaded
# by the caller -- finds it under the row's own text and holds `want` too.
proc pe_vec {raw sig want} {
    set d NOTFOUND
    if {[pe_idx $sig]} { set d [lindex [pcall xschem raw values $sig] 0] }
    return [list [pe_has $raw $sig {Operating Point}] [pe_has $raw $sig {Transient Analysis}] \
                 [pe_near [pn_scalar $raw $sig] $want] [pe_near $d $want]]
}

# =============================================================================
# PN0 -- HOW A CANDIDATE SIMULATOR IS COPIED (no simulator needed)
# =============================================================================
group PN0 {
    set ld [file join $scratch pn0]
    file mkdir [file join $ld real] [file join $ld links] [file join $ld out]
    set prog [file join $ld real prog.sh]
    pd_wr $prog "#!/bin/sh\necho pn0-answers\n"
    file attributes $prog -permissions 0755
    # an absolute link, a relative one, and a link to that link
    exec ln -s $prog [file join $ld links abs]
    exec ln -s ../real/prog.sh [file join $ld links rel]
    exec ln -s rel [file join $ld links chain]
    set types {}
    set copies {}
    foreach nm {abs rel chain} {
        lappend types [file type [file join $ld links $nm]]
        set c [file join $ld out $nm]
        lappend copies [list [pcall pn_copy [file join $ld links $nm] $c] [pcall file type $c] [file executable $c]]
    }
    pn_copy $prog [file join $ld out plain]
    file delete $prog
    set runs {}
    foreach nm {abs rel chain plain} {
        lappend runs [pcall exec [file join $ld out $nm]]
    }
    check {PN0 pn_copy copies the FILE a candidate resolves to: for an absolute symbolic link, a relative one and a link to a link (fixture: each is a link), the copy is a regular executable file, and all three copies -- and the copy of a plain file -- still answer after the original has been deleted (the three link types; per link: copy raised, the copy's type, executable; then what each copy prints)} \
        [list $types $copies $runs] \
        [list {link link link} {{{} file 1} {{} file 1} {{} file 1}} {pn0-answers pn0-answers pn0-answers pn0-answers}]
}

lassign [pn_find] NG LOOKED
if {$NG eq {}} {
    puts "skip: PN and PE, the real-simulator rows (PN1 the bench, PN2 a terminal-only save list with and without a .save in the netlist, PN3 signed, qualified and unticked rows, PN4 disto, PN5 the E guard, PN6 preserve, PN7 numbered subcircuit ports, PN8 a measurement over a terminal, PN9 a terminal under a name the simulator does not give it, PA8g a noise-only run's one sentence about its terminal row, PA8h the same with a design-variable sweep beside the noise, PN10 a terminal the netlist already probes, PN11 a source's current against its two terminals, PN12 an expression that reads a name no .save card can carry, PN13 an operating point that cannot be solved once the transient-op rung is switched off, PN14 the capability probe's answer about that simulator, PN15 the whole road on a simulator without the probe extension, PE a pick on the sheet through to its vector) -- no ngspice answering probe_version 1 among {$LOOKED}, so they did not run"
} else {
    group PN1 {
        set rows {i(x1.r1:n1) i(x1.c1:n1) i(x1.v2:n1) i(x1.d1:a) i(x1.m2:d) i(x1.m2:b_tj) i(x1.q1:c)
                  i(x1.xm1:d) i(x1.xr1:r0) i(x1:out) i(xb[1]:out) i(xb[0].xm1:d) i(rtop:n1) i(rtop:n2) i(e5:n1)}
        set a {}
        foreach r $rows { lappend a $r 1 0 }
        lappend a v(out) 1 0
        set st [pd_state pn1 [pd_outs {*}$a] $::AN_OPTRAN]
        lassign [pn_bench $st $::NLB] rc log deck raw
        check {PN1 the deck the real hook rendered for the hierarchical bench ran on the probe-capable simulator: exit 0, and the results file holds an operating point and a transient} \
            [list $rc [expr {[pn_np $raw {Operating Point}] > 0}] [expr {[pn_np $raw {Transient Analysis}] > 1}]] {0 1 1}
        set sigs [pd_col [ase::probe_plan $st $::NLB fold] signal]
        set mop {}
        set mtr {}
        foreach s $sigs {
            if {![llength [ase::raw_vectors_present $raw [list $s] {Operating Point}]]} { lappend mop $s }
            if {![llength [ase::raw_vectors_present $raw [list $s] {Transient Analysis}]]} { lappend mtr $s }
        }
        check {PN1b EVERY asked terminal -- R, C, V, D, a bare M's drain and bulk, Q, a FET wrapper, a wrapper whose port is not a symbol's pin name, a block port, both bus bits, a top-level resistor's two pins, an E source -- is a vector of BOTH plots, each of non-zero length (terminals asked, missing from op, missing from tran)} \
            [list [llength $sigs] $mop $mtr] {15 {} {}}
        set n1 [pn_scalar $raw i(rtop:n1)]
        set n2 [pn_scalar $raw i(rtop:n2)]
        check {PN1c SIGN: the terminal current is the current INTO the pin -- 1 V across the 1 k top-level resistor reads +1 mA at the pin on the driven net and -1 mA at the grounded one (each within 1e-9 A of its value; the two differ by 2 mA)} \
            [list [expr {[string is double -strict $n1] && abs($n1 - 1e-3) < 1e-9}] \
                  [expr {[string is double -strict $n2] && abs($n2 + 1e-3) < 1e-9}]] {1 1}
        check {PN1d the log carries the simulator's answer, 1, behind the marker, and the run's report has nothing to say} \
            [list [regexp -line "^[ase::probe_marker] 1\\s*\$" $log] \
                  [lindex [pd_spy [list ase::probe_report $st [dict create probes [ase::probe_plan $st $::NLB fold]] $log $rc]] 0]] {1 {}}
        catch {xschem raw clear}
        set idx [pcall xschem raw read $raw op]
        set ix [list [pe_idx i(x1.r1:n1)] [pe_idx {i(xb[1]:out)}]]
        catch {xschem raw clear}
        check {PN1e the viewer's database finds a probed vector by the row's own `:` spelling (xschem raw index, a subcircuit resistor and a bus bit)} \
            $ix {1 1}
    }
    group PN2 {
        set st [pd_state pn2 [pd_outs i(x1.r1:n1) 1 0] $::AN_OPTRAN]
        dict set st save_all_i 1
        lassign [pn_bench $st $::NLB] rc log deck raw
        set vars [pn_vars $raw {Operating Point}]
        check {PN2 a bench whose ONLY saved row is a terminal: the deck has a `.probe` card and, for its Save tick, the save-everything leader and no other `.save`; it runs at exit 0, and the operating point holds the terminal AND the node voltages nobody ticked -- beside `.options savecurrents`} \
            [list [pd_lines $deck {^\.save}] [pd_lines $deck {^\.probe}] [pd_lines $deck {^\.options savecurrents$}] $rc \
                  [expr {[lsearch -exact $vars i(x1.r1:n1)] >= 0}] [expr {[lsearch -exact $vars v(out)] >= 0}]] \
            {{{.save all}} {{.probe I(x1.r1,1)}} {{.options savecurrents}} 0 1 1}
        # A NETLIST WITH A `.save` OF ITS OWN, as a stock ammeter writes one:
        # that card alone narrows the results to what it lists.  Transient
        # only, so nothing but the cards decides what the plot holds.
        set NLA "* ammeter bench\nV1 g 0 1\nRt g m 1k\nVmeas m 0 0\n.save i(vmeas)\nC1 g 0 1p\n.end\n"
        set an_tran {{type op enabled 0} {type tran enabled 1 stop 10n step 1n}}
        set got {}
        foreach {tag outs} [list term [pd_outs i(rt:n1) 1 0] plot [pd_outs i(rt:n1) 0 1] none {}] {
            lassign [pn_bench [pd_state pn2_$tag $outs $an_tran] $NLA] rc log deck raw
            set vars [pn_vars $raw {Transient Analysis}]
            lappend got [list $rc [llength [pd_lines $deck {^\.save all$}]] \
                           [expr {[lsearch -exact $vars i(rt:n1)] >= 0}] [expr {[lsearch -exact $vars i(vmeas)] >= 0}] \
                           [llength [lsearch -all -glob $vars {v(*}]]]
        }
        check {PN2b OVER A NETLIST THAT SAVES BY NAME ITSELF: with the terminal row Save-ticked the deck carries one leader and the transient holds the terminal, the ammeter's current AND both node voltages; with the row PLOT-only there is no leader and the transient holds the terminal and the ammeter's current and no node voltage; with no row at all it holds the ammeter's current alone (per bench: exit, leaders in the deck, terminal present, ammeter current present, node voltages in the plot)} \
            $got {{0 1 1 1 2} {0 0 1 1 0} {0 0 0 1 0}}
    }
    group PN3 {
        set outs [pd_outs -i(rtop:n1) 1 0  it(x1.q1:c) 0 1  {idc(x1.xr1:r0) idc(rtop:n1) +} 0 0  i(x1.xr1:r0) 0 1 \
                          idc(rtop:n2) 0 0  -i(x1.r5:n1) 0 0]
        set st [pd_state pn3 $outs $::AN_OPTRAN]
        lassign [pn_bench $st $::NLB] rc log deck raw
        lassign [pd_spy [list [ase::backend_hook ngspice result_probe] $st $log]] res said
        set xr [pn_scalar $raw i(x1.xr1:r0)]
        check {PN3 a SIGNED row, an analysis-QUALIFIED row and two Measures rows with NEITHER box ticked get their cards, and no `.save` names any of them (the one Save tick brings the leader); the run is exit 0} \
            [list [pd_lines $deck {^\.probe}] [pd_lines $deck {^\.save}] $rc] \
            {{{.probe I(rtop,1) I(x1.q1,c) I(x1.xr1,r0) I(rtop,2) I(x1.r5,1)}} {{.save all}} 0}
        check {PN3b VALUE after the real run: `-i(rtop:n1)` is minus one milliamp, `it(x1.q1:c)` is a wave, and the expression is the wrapper's current plus one milliamp, computed here from the file} \
            [list [ase::state_get $res r0] [ase::state_get $res r1] [ase::state_get $res r2] \
                  [string is double -strict $xr]] \
            [list -1.000000e-03 wave [format %.6e [expr {$xr + 1e-3}]] 1]
        set r5 [pn_scalar $raw i(x1.r5:n1)]
        set want5 {no such vector in the file}
        if {[string is double -strict $r5]} { set want5 [format %.6e [expr {-$r5}]] }
        check {PN3c VALUE of the two UNTICKED Measures rows after the real run: `idc(rtop:n2)` is the minus one milliamp at the grounded pin of the top-level resistor, and `-i(x1.r5:n1)` is minus the file's own number for that pin, which is not zero -- neither is an unknown-token text (the two values, the file's number is a non-zero number)} \
            [list [ase::state_get $res r4] [ase::state_get $res r5] \
                  [expr {[string is double -strict $r5] && $r5 != 0.0}]] \
            [list -1.000000e-03 $want5 1]
    }
    group PN4 {
        set st [pd_state pn4 [pd_outs i(x1.r1:n1) 1 0] \
                  {{type disto enabled 1 sweep dec points 2 start 1k stop 10k}}]
        set gate [lindex [pd_spy [list ase::preflight_gate $st $::NLB]] 0]
        lassign [pn_bench $st $::NLB] rc log deck raw
        set miss {}
        set n 0
        foreach pl [ase::cap_raw_plots $raw] {
            incr n
            if {[lsearch -exact [lindex $pl 2] i(x1.r1:n1)] < 0 || [lindex $pl 1] < 1} { lappend miss [lindex $pl 0] }
        }
        check {PN4 a DISTORTION bench whose only saved row is a terminal is not refused, runs at exit 0 with the leader as its one `.save` card, and every plot it writes holds the terminal (gate raised, exit, `.save` lines, plots > 0, plots lacking it)} \
            [list [string match ERR:* $gate] $rc [pd_lines $deck {^\.save}] [expr {$n > 0}] $miss] {0 0 {{.save all}} 1 {}}
    }
    group PN5 {
        set nl [string map [list "R6 e5 0 1k\n" "R6 e5 0 1k\nE9 e9 0 vol='v(g)*2'\nR7 e9 0 1k\n"] $::NLB]
        set st [pd_state pn5 [pd_outs i(e5:n1) 1 0  i(e9:n1) 1 0  i(e5:n2) 1 0] $::AN_OP]
        lassign [pn_bench $st $nl] rc log deck raw
        set vars [pn_vars $raw {Operating Point}]
        check {PN5 THE E GUARD, the way that asks: the six-word `VOL=` source is probed on both pins and the run is exit 0 with both vectors; the four-word source gets no term} \
            [list [pd_lines $deck {^\.probe}] $rc [expr {[lsearch -exact $vars i(e5:n1)] >= 0}] \
                  [expr {[lsearch -exact $vars i(e5:n2)] >= 0}]] \
            {{{.probe I(e5,1) I(e5,2)}} 0 1 1}
        check {PN5b ...and the run says which terminal it did not ask for, once} \
            [pd_kinds [lindex [pd_spy [list ase::probe_report $st [dict create probes [ase::probe_plan $st $nl fold]] $log $rc]] 0]] \
            {{withheld i(e9:n1)}}
        # CONTROL: the withheld term, written by hand into the same deck, stops
        # this simulator before any analysis -- the guard is not decoration.
        set df [file join [dict get $st rundir] deck_forced.cir]
        pd_wr $df [string map [list ".probe I(e5,1) I(e5,2)" ".probe I(e5,1) I(e5,2) I(e9,1)"] $deck]
        file delete [pd_rawpath $st]
        lassign [pn_exec $df] rcf logf
        check {PN5c CONTROL: the same deck with the withheld term written in exits nonzero and writes no results file} \
            [list [expr {$rcf != 0}] [file isfile [pd_rawpath $st]]] {1 0}
    }
    group PN6 {
        set ::sim_case_mode preserve
        set st [pd_state pn6 [pd_outs i(Rtop:n1) 1 0  i(Rtop:n2) 1 0  i(x1.R1:n1) 1 0  i(x1:out) 1 0] $::AN_OP]
        set r6 [catch {pn_bench $st $::NLB -D casemode=preserve} got]
        set ::sim_case_mode fold
        if {$r6} { error $got }
        lassign $got rc log deck raw
        set vars [pn_vars $raw {Operating Point}]
        set tops {}
        foreach v $vars { if {[string match -nocase {i(rtop:*} $v]} { lappend tops $v } }
        check {PN6 PRESERVE, on the simulator run with casemode=preserve: the top-level resistor is asked in lower case and comes back under its netlist spelling with its two pins told apart; the path inside the block keeps the row's spelling (the card, exit, the top-level resistor's vectors, the in-block vector present)} \
            [list [pd_lines $deck {^\.probe}] $rc [lsort $tops] [expr {[lsearch -exact $vars i(x1.R1:n1)] >= 0}]] \
            {{{.probe I(rtop,1) I(rtop,2) I(x1.R1,1) I(x1,out)}} 0 {i(Rtop:n1) i(Rtop:n2)} 1}
        # CONTROL: the row's own spelling in the card is what the rule avoids.
        set df [file join [dict get $st rundir] deck_upper.cir]
        pd_wr $df [string map [list "I(rtop,1) I(rtop,2)" "I(Rtop,1) I(Rtop,2)"] $deck]
        file delete [pd_rawpath $st]
        lassign [pn_exec $df -D casemode=preserve] rcu logu
        set topsu {}
        foreach v [pn_vars [pd_rawpath $st] {Operating Point}] { if {[string match -nocase {i(rtop:*} $v]} { lappend topsu $v } }
        check {PN6b CONTROL: with the instance in upper case in the card the same simulator names neither pin -- no `i(Rtop:n1)` and no `i(Rtop:n2)` among the vectors it writes for that resistor} \
            [list $rcu [lsearch -exact $topsu i(Rtop:n1)] [lsearch -exact $topsu i(Rtop:n2)] [expr {[llength $topsu] > 0}]] {0 -1 -1 1}
    }
    group PN7 {
        # V1 puts 1 V on a and V2 2 V on c; inside `blk`, 1 k from port 3 to
        # port 2 and 3 k from port 2 to port 7, and RL takes b to ground through
        # 1 k.  So b sits at 5/7 V and the currents INTO the block are 2/7 mA at
        # the port named 3, 3/7 mA at the port named 7 and minus their sum at
        # the port named 2 -- three different numbers.
        set NLN "* numbered ports\nV1 a 0 1\nV2 c 0 2\nX1 a b c blk\nXw a b2 c wrap\nRL b 0 1k\nRL2 b2 0 1k\n.subckt blk 3 2 7\nRa 3 2 1k\nRb 2 7 3k\n.ends\n.subckt wrap p q r\nXi p q r blk\n.ends\n.end\n"
        set st [pd_state pn7 [pd_outs i(x1:3) 1 0  i(x1:2) 1 0  i(x1:7) 1 0  i(xw.xi:7) 1 0] $::AN_OP]
        lassign [pn_bench $st $NLN] rc log deck raw
        set vars [pn_vars $raw {Operating Point}]
        set i3 [pn_scalar $raw i(x1:3)]
        set i2 [pn_scalar $raw i(x1:2)]
        set i7 [pn_scalar $raw i(x1:7)]
        set w7 [pn_scalar $raw i(xw.xi:7)]
        check {PN7 NUMBERED PORTS on the simulator, ports 3 2 7 at positions 1 2 3: the deck asks by position, the run is exit 0, and the operating point holds a vector under EACH row's own name -- at the top level and one level down (the card, exit, the four present)} \
            [list [pd_lines $deck {^\.probe}] $rc \
                  [lmap s {i(x1:3) i(x1:2) i(x1:7) i(xw.xi:7)} { expr {[lsearch -exact $vars $s] >= 0} }]] \
            {{{.probe I(x1,1) I(x1,2) I(x1,3) I(xw.xi,3)}} 0 {1 1 1 1}}
        check {PN7b ...and each is THE CURRENT INTO THE PORT OF THAT NAME: 2/7 mA into the port named 3, 3/7 mA into the port named 7 -- the same one level down -- and minus their sum into the port named 2 (each within 1e-9 A; the two positive ones differ by more than 0.1 mA, so neither could pass for the other)} \
            [list [pe_near $i3 [expr {2e-3/7}]] [pe_near $i7 [expr {3e-3/7}]] [pe_near $i2 [expr {-5e-3/7}]] [pe_near $w7 [expr {3e-3/7}]] \
                  [expr {[string is double -strict $i3] && [string is double -strict $i7] && abs($i7 - $i3) > 1e-4}]] \
            {1 1 1 1 1}
        check {PN7c the run's report has nothing to say, although the log holds the simulator's line that it took a number as a position (the line is in the log, the report)} \
            [list [regexp -line {^probe: I\(x1:3\): 3 is taken as a position, not as the port named 3\s*$} $log] \
                  [lindex [pd_spy [list ase::probe_report $st [dict create probes [ase::probe_plan $st $NLN fold]] $log $rc]] 0]] {1 {}}
        # CONTROL: the row's own number in the card, which is what the lookup avoids.
        set df [file join [dict get $st rundir] deck_names.cir]
        pd_wr $df [string map [list ".probe I(x1,1) I(x1,2) I(x1,3) I(xw.xi,3)" ".probe I(x1,3) I(x1,2) I(x1,7) I(xw.xi,7)"] $deck]
        file delete [pd_rawpath $st]
        lassign [pn_exec $df] rcn logn
        set varsn [pn_vars [pd_rawpath $st] {Operating Point}]
        check {PN7d CONTROL: the same deck with each port's NAME in its card gives no vector for the port named 3 at either depth, and the simulator refuses the card that names 7 (exit, i(x1:3) present, i(xw.xi:7) present, the refusal line)} \
            [list $rcn [expr {[lsearch -exact $varsn i(x1:3)] >= 0}] [expr {[lsearch -exact $varsn i(xw.xi:7)] >= 0}] \
                  [regexp -line {^probe: I\(x1:7\) not inserted: x1 has 3 terminals\s*$} $logn]] {0 0 0 1}
        # The header in a file the deck includes, and nowhere in the netlist text.
        set inc [file join [dict get $st rundir] blk_inc.spice]
        pd_wr $inc ".subckt blk 3 2 7\nRa 3 2 1k\nRb 2 7 3k\n.ends\n"
        set NLI "* numbered ports, the header in a model file\nV1 a 0 1\nV2 c 0 2\nX1 a b c blk\nRL b 0 1k\n.end\n"
        set sti [pd_state pn7i [pd_outs i(x1:7) 1 0  i(x1:3) 1 0] $::AN_OP]
        dict set sti includes [list $inc]
        lassign [pn_bench $sti $NLI] rci logi decki rawi
        check {PN7e THE HEADER IN A MODEL FILE the session names, and not in the netlist: the deck still asks by position, the run is exit 0, and the vector named 7 is the 3/7 mA into that port (the card, exit, the value)} \
            [list [pd_lines $decki {^\.probe}] $rci [pe_near [pn_scalar $rawi i(x1:7)] [expr {3e-3/7}]]] \
            {{{.probe I(x1,3) I(x1,1)}} 0 1}
    }
    group PN8 {
        # No Outputs row: the terminals are asked for the measurements alone.
        # 1 V across the top-level 1 k resistor is +1 mA into its pin on g.
        set st [pd_state pn8 {} $::AN_OPTRAN]
        dict set st measurements {{name iav analysis tran kind avg target i(rtop:n1)} {name ipk analysis tran kind max target i(x1.r1:n1)}}
        lassign [pn_bench $st $::NLB] rc log deck raw
        set mr [pcall ase::meas_results ngspice $st]
        check {PN8 A MEASUREMENT OVER A TERMINAL, with no Outputs row: the deck carries the card, the run is exit 0, and the simulator reports both measurements as numbers -- the average current into the resistor's driven pin is the +1 mA the circuit gives it (the card, exit, the verdict of each, the average within 1e-9 A, the other a number)} \
            [list [pd_lines $deck {^\.probe}] $rc [lmap e $mr { lindex $e 1 }] \
                  [pe_near [lindex [lindex $mr 0] 2] 1e-3] [string is double -strict [lindex [lindex $mr 1] 2]]] \
            {{{.probe I(rtop,1) I(x1.r1,1)}} 0 {ok ok} 1 1}
        # CONTROL: the same deck without its card.
        set df [file join [dict get $st rundir] deck_nocard.cir]
        pd_wr $df [string map [list ".probe I(rtop,1) I(x1.r1,1)\n" {}] $deck]
        file delete [ase::meas_path $st]
        lassign [pn_exec $df] rcx logx
        check {PN8b CONTROL: without the card the simulator says `no such vector` for each terminal and the same measurements report nothing (the two log lines found, the verdict of each)} \
            [list [regexp {no such vector as 'i\(rtop:n1\)'} $logx] [regexp {no such vector as 'i\(x1\.r1:n1\)'} $logx] \
                  [lmap e [pcall ase::meas_results ngspice $st] { lindex $e 1 }]] {1 1 {failed failed}}
    }
    group PN9 {
        set st [pd_state pn9 [pd_outs i(x1.m2:b) 1 0  i(x1.q1:1) 1 0] $::AN_OP]
        lassign [pn_bench $st $::NLB] rc log deck raw
        set vars [pn_vars $raw {Operating Point}]
        lassign [pd_spy [list ase::probe_report $st [dict create probes [ase::probe_plan $st $::NLB fold]] $log $rc]] recs said
        check {PN9 A TERMINAL ASKED UNDER A NAME THE SIMULATOR DOES NOT GIVE IT: the bulk asked as `b` and the bipolar's first pin asked as `1` get their cards, the run is exit 0, and the vectors come back as `b_tj` and `c`; the report then names those for each row instead of saying the simulator made nothing (the card, exit, the two vectors present, the kinds, the names each line gives)} \
            [list [pd_lines $deck {^\.probe}] $rc \
                  [expr {[lsearch -exact $vars i(x1.m2:b_tj)] >= 0}] [expr {[lsearch -exact $vars i(x1.q1:c)] >= 0}] \
                  [pd_kinds $recs] \
                  [lmap r $recs { regsub {^.* the results hold (.*)\. Name the row.*$} [lindex $r 2] {\1} }]] \
            {{{.probe I(x1.m2,b) I(x1.q1,1)}} 0 1 1 {{missing i(x1.m2:b)} {missing i(x1.q1:1)}} {i(x1.m2:b_tj) i(x1.q1:c)}}
    }
    group PA8g {
        # The whole road on the simulator copy: ase::run_deck, the run, and
        # ase::run_done, which calls the Value reader and then the report --
        # through a backend that is ngspice's in every hook but the program it
        # starts.
        set hooks [dict get $::ase::backends ngspice]
        proc pn_run_cmd {state deckpath {quiet 0}} {
            return [list env -u DISPLAY HOME=$::pn_home timeout 60 $::NG -b $deckpath 2>@1]
        }
        dict set hooks run_cmd pn_run_cmd
        ase::register_backend pnsim $hooks
        set st [pd_state pa8g [pd_outs i(rtop:n1) 1 0  v(out) 1 0] \
                  {{type op enabled 0} {type noise enabled 1 out v(out) insrc V1 sweep dec points 5 start 1k stop 100k}}]
        dict set st simulator pnsim
        set nlf [file join [dict get $st rundir] pa8g.spice]
        pd_wr $nlf $::NLB
        lassign [pd_spy { pw_wait [ase::run_deck $st $nlf] }] rc said
        catch {ase::run_lock_clear [ase::run_lock_key $st]}
        set mine {}
        set novalue {}
        foreach s $said {
            if {[string first i(rtop:n1) [lindex $s 1]] >= 0} { lappend mine $s }
            if {[string match {ase: result -- the results file holds no single-point value for *} [lindex $s 1]]} {
                lappend novalue [regsub {^.* single-point value for (.*), so th.*$} [lindex $s 1] {\1}]
            }
        }
        set held {}
        foreach pl [ase::cap_raw_plots [pd_rawpath $st]] {
            foreach v [lindex $pl 2] { if {[ase::probe_split $v] ne {}} { lappend held $v } }
        }
        check {PA8g A NOISE-ONLY RUN ON THE SIMULATOR, the whole road from ase::run_deck to ase::run_done: the deck carries the terminal's card and the run is exit 0; no plot it wrote holds a terminal current; the note about rows with no single-point value names the node row alone; and EXACTLY ONE sentence of everything the run says names the terminal row -- the report's note, spoken as a note (the card, exit, terminal currents in the file, the rows the other note names, then the one sentence with its tag)} \
            [list [pd_lines [pcall pd_rd [ase::deck_file $st]] {^\.probe}] $rc $held $novalue $mine] \
            [list {{.probe I(rtop,1)}} 0 {} v(out) \
                  [list [list note {ase: the terminal current i(rtop:n1) is not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.}]]]
    }
    group PA8h {
        # The same road with a design-variable sweep beside the noise: a reload
        # of the bench at each point, then the noise analysis.  Two terminal
        # rows: one unqualified, one that reads the sweep by its qualifier.
        set hooks [dict get $::ase::backends ngspice]
        proc pn_run_cmd {state deckpath {quiet 0}} {
            return [list env -u DISPLAY HOME=$::pn_home timeout 60 $::NG -b $deckpath 2>@1]
        }
        dict set hooks run_cmd pn_run_cmd
        ase::register_backend pnsim $hooks
        set st [pd_state pa8h [pd_outs i(rtop:n1) 1 0  is(r6:n1) 0 0  v(out) 1 0] \
                  {{type op enabled 0} {type dc enabled 1 swkind variable source rv start 500 stop 1500 step 500}
                   {type noise enabled 1 out v(out) insrc V1 sweep dec points 5 start 1k stop 100k}}]
        dict set st simulator pnsim
        dict set st variables {{name rv value 1k}}
        set nlf [file join [dict get $st rundir] pa8h.spice]
        pd_wr $nlf ".param rv=1k\n$::NLB"
        lassign [pd_spy { pw_wait [ase::run_deck $st $nlf] }] rc said
        catch {ase::run_lock_clear [ase::run_lock_key $st]}
        set mine {}
        set adv {}
        foreach s $said {
            if {[string first i(rtop:n1) [lindex $s 1]] >= 0} { lappend mine $s }
            if {[string first i(r6:n1) [lindex $s 1]] >= 0} { lappend adv [lindex $s 1] }
        }
        set held {}
        set names {}
        foreach pl [ase::cap_raw_plots [pd_rawpath $st]] {
            lappend names [lindex $pl 0]
            foreach v [lindex $pl 2] { if {[ase::probe_split $v] ne {}} { lappend held $v } }
        }
        check {PA8h A DESIGN-VARIABLE SWEEP BESIDE A NOISE ANALYSIS ON THE SIMULATOR, the whole road from ase::run_deck to ase::run_done: the deck carries both terminals' cards and the run is exit 0; it wrote the sweep's plot and the noise plots, and NO plot holds a terminal current, so what the note says of the row it names is true of the file; EXACTLY ONE sentence of everything the run says names the unqualified row's terminal -- the report's note, in the sentence that names the sweep, spoken as a note -- and EXACTLY ONE names the terminal of the row that reads the sweep by its qualifier: the sweep's own advice, which the note leaves it to (the card, exit, the plots, terminal currents in the file, the one sentence with its tag, how many sentences name the other terminal and whether that one is the sweep's advice)} \
            [list [pd_lines [pcall pd_rd [ase::deck_file $st]] {^\.probe}] $rc $names $held $mine \
                  [llength $adv] [string match {ase: the dc analysis: output 'r1' reads 'i(r6:n1)', *a sweep of a design variable carries only top-level nets and source currents*} [lindex $adv 0]]] \
            [list {{.probe I(rtop,1) I(r6,1)}} 0 {{DC transfer characteristic} {Integrated Noise} {Noise Spectral Density Curves}} {} \
                  [list [list note {ase: the terminal current i(rtop:n1) is not in this run's results: the run made only noise, transfer-function, pole-zero or sensitivity analyses beside a sweep of a design variable, and none of those keeps a terminal current. Enable an operating point, a dc sweep of a source, an ac or a transient analysis and run again.}]] \
                  1 1]
    }
    group PN10 {
        # A netlist with a `.probe` card of its own for a top-level device, and
        # rows for that terminal and for one inside the block.
        proc pn_count {raw plot sig} {
            return [llength [lsearch -all -exact [lmap v [pn_vars $raw $plot] { string tolower $v }] $sig]]
        }
        set nl [string map [list "R6 e5 0 1k\n" "R6 e5 0 1k\n.PROBE I(RTOP,1)\n"] $::NLB]
        set st [pd_state pn10 [pd_outs i(rtop:n1) 1 0  i(x1.r1:n1) 1 0] $::AN_OPTRAN]
        lassign [pn_bench $st $nl] rc log deck raw
        check {PN10 A TERMINAL THE NETLIST ALREADY PROBES, on the simulator: the deck writes only the other term, the run is exit 0, and each plot holds the top-level terminal's vector EXACTLY ONCE, with the 1 mA the circuit gives that pin, and the in-block one once; the run's report has nothing to say (the card, exit, the count in the operating point and in the transient, the in-block count in each, the value, the report)} \
            [list [pd_lines $deck {^\.probe}] $rc \
                  [pn_count $raw {Operating Point} i(rtop:n1)] [pn_count $raw {Transient Analysis} i(rtop:n1)] \
                  [pn_count $raw {Operating Point} i(x1.r1:n1)] [pn_count $raw {Transient Analysis} i(x1.r1:n1)] \
                  [pe_near [pn_scalar $raw i(rtop:n1)] 1e-3] \
                  [lindex [pd_spy [list ase::probe_report $st [dict create probes [ase::probe_plan $st $nl fold]] $log $rc]] 0]] \
            {{{.probe I(x1.r1,1)}} 0 1 1 1 1 1 {}}
        # CONTROL: the term the deck writer left out, written back in by hand.
        set df [file join [dict get $st rundir] deck_twice.cir]
        pd_wr $df [string map [list ".probe I(x1.r1,1)" ".probe I(rtop,1) I(x1.r1,1)"] $deck]
        file delete [pd_rawpath $st]
        lassign [pn_exec $df] rct logt
        check {PN10b CONTROL: the same deck with that term written a second time gives the top-level terminal's vector TWICE in each plot -- what leaving the term out avoids (exit, the count in the operating point and in the transient)} \
            [list $rct [pn_count [pd_rawpath $st] {Operating Point} i(rtop:n1)] [pn_count [pd_rawpath $st] {Transient Analysis} i(rtop:n1)]] \
            {0 2 2}
        # UNDER `preserve` A CARD IN ANOTHER CASE IS NOT THE SAME TERM.
        set nlp [string map [list "R6 e5 0 1k\n" "R6 e5 0 1k\n.PROBE I(Rtop,1)\n"] $::NLB]
        set ::sim_case_mode preserve
        set stp [pd_state pn10p [pd_outs i(Rtop:n1) 1 0] $::AN_OP]
        set rp [catch {pn_bench $stp $nlp -D casemode=preserve} got]
        set ::sim_case_mode fold
        if {$rp} { error $got }
        lassign $got rcp logp deckp rawp
        set varsp [pn_vars $rawp {Operating Point}]
        set dfp [file join [dict get $stp rundir] deck_dropped.cir]
        pd_wr $dfp [string map [list ".probe I(rtop,1)\n" {}] $deckp]
        file delete [pd_rawpath $stp]
        lassign [pn_exec $dfp -D casemode=preserve] rcd logd
        set varsd [pn_vars [pd_rawpath $stp] {Operating Point}]
        check {PN10c PRESERVE, on the simulator run with casemode=preserve: over a netlist whose own card spells the top-level resistor with its capital, the deck still writes the lower-case term, and the operating point holds the row's vector `i(Rtop:n1)` once; CONTROL the same deck with that term taken out runs at exit 0 and holds NO vector of the row's name -- the netlist's card alone makes one the simulator names otherwise -- so a comparison that ignored case there would cost the row its current (the card, exit, the row's vector count; then exit, the count, some other vector of that resistor present)} \
            [list [pd_lines $deckp {^\.probe}] $rcp [llength [lsearch -all -exact $varsp i(Rtop:n1)]] \
                  $rcd [llength [lsearch -all -exact $varsd i(Rtop:n1)]] \
                  [expr {[llength [lsearch -all -glob $varsd {i(Rtop:*}]] > 0}]] \
            {{{.probe I(rtop,1)}} 0 1 0 0 1}
    }
    group PN11 {
        # V1 holds net g at 1 V and the only dc load on that net is the 1 k
        # resistor to ground (the blocks hang gates on it), so V1 DELIVERS 1 mA:
        # the current into its first pin, the one on g, is minus one milliamp.
        set st [pd_state pn11 [pd_outs i(v1) 1 0  i(v1:n1) 1 0  i(v1:n2) 1 0] $::AN_OP]
        lassign [pn_bench $st $::NLB] rc log deck raw
        set iv [pn_scalar $raw i(v1)]
        set i1 [pn_scalar $raw i(v1:n1)]
        set i2 [pn_scalar $raw i(v1:n2)]
        check {PN11 A VOLTAGE SOURCE'S OWN CURRENT AGAINST ITS TWO TERMINALS, on the simulator: the deck probes both pins of the top-level source and saves its branch current, the run is exit 0, and `i(v1)` IS the current into the source's first pin: both it and `i(v1:n1)` are the minus one milliamp of a source that delivers 1 mA, and the current into its second pin, `i(v1:n2)`, is the NEGATIVE of it, plus one milliamp (each within 1e-9 A of its value; the two signs differ by 2 mA, so neither could pass for the other) (the card, the save cards, exit, the source's current, the first pin, the second pin)} \
            [list [pd_lines $deck {^\.probe}] [pd_lines $deck {^\.save}] $rc \
                  [pe_near $iv -1e-3] [pe_near $i1 -1e-3] [pe_near $i2 1e-3]] \
            {{{.probe I(v1,1) I(v1,2)}} {{.save all} {.save i(v1)}} 0 1 1 1}
    }
    group PN12 {
        # One plain Save-ticked row, and expression rows that each read one
        # name: first those no `.save` card can carry, then a name the results
        # simply lack (the CONTROL the Values are compared with), then a `;`
        # and a dollar sign, which a `.save` card carries harmlessly.
        set unw [list {vdc(a=b)} {vdc(a'b)} "vdc(a\{b)" {idc(=rtop:n1)}]
        set a {v(out) 1 0}
        foreach n $unw { lappend a "$n 2 *" 0 0 }
        lappend a {vdc(nosuch) 2 *} 0 0  {vdc(a;b) 2 *} 0 0  {vdc(a$b) 2 *} 0 0
        set st [pd_state pn12 [pd_outs {*}$a] $::AN_OP]
        lassign [pn_bench $st $::NLB] rc log deck raw
        lassign [pd_spy [list [ase::backend_hook ngspice result_probe] $st $log]] res said
        set ctl [ase::state_get $res r5]
        set vals {}
        set want {}
        set i 0
        foreach n $unw {
            incr i
            lappend vals [ase::state_get $res r$i]
            lappend want [string map [list vdc(nosuch) $n] $ctl]
        }
        check {PN12 AN EXPRESSION THAT READS A NAME NO `.save` CARD CAN CARRY, on the simulator: beside one plain Save-ticked row, four rows that read a name holding an equals sign, a single quote or an opening brace put no card in the deck, the run is exit 0, the operating point holds the plain row's node and its Value is a number -- and each of the four rows' Values is, name for name, what the SAME run says of a read the results simply lack; the reads of a name holding a `;` and a dollar sign keep their cards in that same run (the `.save` lines, exit, the node present, the plain row's Value a number, the control's Value names its own read and is no number, the four Values against the control's with the name put in)} \
            [list [pd_lines $deck {^\.save}] $rc [expr {[lsearch -exact [pn_vars $raw {Operating Point}] v(out)] >= 0}] \
                  [string is double -strict [ase::state_get $res r0]] \
                  [expr {[string first vdc(nosuch) $ctl] >= 0 && ![string is double -strict $ctl]}] \
                  [expr {$vals eq $want}] [llength $vals]] \
            [list {{.save all} {.save v(out)} {.save v(nosuch)} {.save v(a;b)} {.save v(a$b)}} 0 1 1 1 1 4]
        # CONTROL: each card the deck writer leaves out, written back in by
        # hand below the plain row's, one deck per character.
        set got {}
        foreach {tag card} [list eq {.save v(a=b)} quote {.save v(a'b)} open ".save v(a\{b)" close ".save v(a\}b)"] {
            set df [file join [dict get $st rundir] deck_$tag.cir]
            pd_wr $df [string map [list ".save v(out)\n" ".save v(out)\n$card\n"] $deck]
            file delete [pd_rawpath $st]
            lassign [pn_exec $df] rcx logx
            lappend got [list [llength [lsearch -all -exact [split [pd_rd $df] "\n"] $card]] \
                           [expr {$rcx != 0}] [file isfile [pd_rawpath $st]]]
        }
        check {PN12b CONTROL: the same deck with one such card written back in stops this simulator before it writes a results file, for the equals sign, for the single quote and for the opening brace -- what leaving the card out avoids; a closing brace alone is carried harmlessly, and leaves the save list only for the opening one's sake (per deck: fixture, the hand-written card is in it once; exit nonzero; a results file written)} \
            $got {{1 1 0} {1 1 0} {1 1 0} {1 0 1}}
    }
    group PN13 {
        # Node `fl` hangs between two capacitors and has no dc path, so the
        # simulator finds this bench's operating point only on its
        # transient-op rung.  The whole road twice, from ase::run_deck to
        # ase::run_done, over one ac analysis and one terminal row: as the
        # bench stands, and with the strategy the Convergence form writes
        # when that rung is unticked.
        set hooks [dict get $::ase::backends ngspice]
        proc pn_run_cmd {state deckpath {quiet 0}} {
            return [list env -u DISPLAY HOME=$::pn_home timeout 60 $::NG -b $deckpath 2>@1]
        }
        dict set hooks run_cmd pn_run_cmd
        ase::register_backend pnsim $hooks
        set nlfl "** sch_path: a node with no dc path\nVs in 0 dc 1 ac 1\nRf in out 1k\nCc out fl 10p\nCl fl 0 10p\n.end\n"
        foreach {cell strat} {pn13on {} pn13off {newton 1 gmin 1 gminsteps 1 src 1 srcsteps 1 tranop 0}} {
            set st [pd_state $cell [pd_outs i(rf:n1) 1 0] {{type ac enabled 1 sweep dec points 5 start 1k stop 1meg}}]
            dict set st simulator pnsim
            if {[llength $strat]} { dict set st opstrategy $strat }
            set nlf [file join [dict get $st rundir] $cell.spice]
            pd_wr $nlf $nlfl
            lassign [pd_spy { pw_wait [ase::run_deck $st $nlf] }] rc said
            catch {ase::run_lock_clear [ase::run_lock_key $st]}
            set deck [pcall pd_rd [ase::deck_file $st]]
            set log [pcall pd_rd [[ase::backend_hook pnsim log_file] $st]]
            set mine {}
            foreach s $said {
                if {[string first {terminal current} [lindex $s 1]] >= 0} { lappend mine $s }
            }
            set pn13($cell) [list [pd_lines $deck {^\.probe}] [pd_lines $deck {^optran}] \
                               [expr {[string is integer -strict $rc] && $rc > 0}] \
                               [regexp {operating point could not be simulated} $log] [regexp -nocase $::CONVREST $log] \
                               [expr {[lsearch -exact [pn_vars [pd_rawpath $st] {AC Analysis}] i(rf:n1)] >= 0}] $mine]
        }
        check {PN13 CONTROL, on the simulator: the bench as it stands, one ac analysis and one terminal row, finishes at exit 0 with the terminal's vector in the ac plot, and nothing the run says is about a terminal current (the card, the strategy line, exit nonzero, the log says an operating point could not be simulated, the log holds one of the other failure lines, the vector present, the sentences)} \
            $pn13(pn13on) {{{.probe I(rf,1)}} {} 0 0 0 1 {}}
        check {PN13b AN OPERATING POINT THAT CANNOT BE SOLVED ONCE THE TRANSIENT-OP RUNG IS SWITCHED OFF, on the simulator, the whole road from ase::run_deck to ase::run_done: the same bench with that rung unticked carries the strategy line beside the terminal's card, the run ends with a nonzero exit, its log says the operating point could not be simulated and holds NONE of the other failure lines -- and EXACTLY ONE sentence of everything the run says is about a terminal current: the note that the run did not converge and what its one probe may have to do with it, spoken as a note (the card, the strategy line, exit nonzero, the line in the log, one of the other lines in the log, the vector present, then the one sentence with its tag)} \
            $pn13(pn13off) [list {{.probe I(rf,1)}} {{optran 1 1 1 0 10u 0}} 1 1 0 0 \
                  [list [list note {ase: this run did not converge, and its deck asked for 1 terminal current. Each one puts a zero-volt source in series with its pin, and that alone can stop a run that finishes without it. Switching those rows off -- unticking Save and Plot on a Saves row, removing or disabling a Measures or measurement row that reads a terminal -- may let the run finish.}]]]
    }
    group PN14 {
        test_sim_registry_isolate
        set c [pcall ase::sim_capabilities_path ngspice $::NG]
        check {PN14 THE REAL CAPABILITY PROBE of the probe-capable simulator: its answer is known, and the key says it saves a terminal current below the top level -- the 1 its own deck wrote into the probe's file (known, the key)} \
            [list [pcall ase::caps_get $c known] [pcall ase::caps_get $c hier_probes]] {{measured 1 value 1} {measured 1 value 1}}
    }
    lassign [pn_find 0] NGOLD OLDLOOKED
    if {$NGOLD eq {}} {
        puts "skip: PN15, the whole road on a simulator WITHOUT the probe extension (the line before the run, the report after it, the top-level terminal it does save, and the same bench on the registered program that can) -- no ngspice answering probe_version 0 among {$OLDLOOKED}, so it did not run"
    } else {
    group PN15 {
        # What the user met: nothing picked, so the program named ngspice on
        # the PATH starts -- here a copy of a build WITHOUT the extension --
        # and the bench asks for a device inside a subcircuit beside a
        # top-level resistor.  The probe-capable copy is registered as `zable`.
        set oldbin [file join $::scratch ng oldbin]
        file mkdir $oldbin
        file copy -force $::NGOLD [file join $oldbin ngspice]
        set path0 $::env(PATH)
        test_sim_registry_isolate
        ase::sim_register zable $::NG
        ase::sim_select {}
        set ::env(PATH) "$oldbin:$path0" ; auto_reset
        # The session's own choice is "the program on the PATH", as a saved
        # simulator list that ends with no pick makes it for every session.
        set st [ase::sim_choice_set [pd_state pn15 [pd_outs i(x1.xm1:d) 1 0  i(rtop:n1) 1 0  v(out) 1 0] $::AN_OP] path]
        set nlf [file join [dict get $st rundir] pn15.spice]
        pd_wr $nlf $::NLB
        proc pn15_go {st nlf} {
            lassign [pd_spy [list apply {{st nlf} { pw_wait [ase::run_deck $st $nlf] }} $st $nlf]] rc said
            catch {ase::run_lock_clear [ase::run_lock_key $st]}
            set mine {}
            foreach s $said { if {[string first {cannot save} [lindex $s 1]] >= 0} { lappend mine $s } }
            set vars [pn_vars [pd_rawpath $st] {Operating Point}]
            return [list $rc $mine [expr {[lsearch -exact $vars i(rtop:n1)] >= 0}] [expr {[lsearch -exact $vars i(x1.xm1:d)] >= 0}]]
        }
        set old [pn15_go $st $nlf]
        set caps0 [pcall ase::caps_get [ase::sim_caps_cached ngspice] hier_probes]
        set able [pn15_go [ase::sim_choice_set $st entry zable] $nlf]
        set ::env(PATH) $path0 ; auto_reset
        test_sim_registry_isolate
        set who [file join $oldbin ngspice]
        set limit {it saves terminal currents only on top-level devices that are not subcircuit instances.}
        set cure "zable can \u2014 pick it under Setup > Simulators\u2026 and run again."
        check {PN15 WHAT THE USER MET, ON TWO REAL SIMULATORS and through the whole road from ase::run_deck to ase::run_done: with nothing picked the program named ngspice on the PATH starts -- a build the capability probe measures unable -- and the bench asks for a device inside a subcircuit; the run is not refused and ends at exit 0; BEFORE it the one line names that file, says it cannot save the terminal and what such a build saves, names the registered program that can and where to pick it, and that the run goes on; AFTER it the report says the same of the program the run started; the top-level resistor's current is in the results and the other is not (the probe's answer about the program; exit; the two lines; the resistor's vector; the device's)} \
            [list $caps0 {*}$old] \
            [list {measured 1 value 0} 0 \
                  [list [list error "ase: $who, the simulator this run is starting, cannot save the terminal current i(x1.xm1:d): $limit $cure This run goes on without that current."] \
                        [list error "ase: $who, the simulator this run started, cannot save the terminal current i(x1.xm1:d): $limit $cure"]] 1 0]
        check {PN15b ...AND THE CURE IS ONE: with `zable` picked, as the lines say, the same bench runs at exit 0, neither line is said, and both currents are in the results} \
            $able {0 {} 1 1}
    }
    }
    group PE {
        lassign [pe_fixture] pelib pemod
        pd_wr [file join $scratch library.defs] \
            "DEFINE pelib $pelib\nDEFINE devices [file join [file dirname [file dirname $here]] xschem_libs_newsym devices]\n"
        set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
        set ::library_registry_defs_only 1
        # assigned UNQUALIFIED: the write trace that rebuilds the search path
        # compares the name it is handed with the bare word
        set XSCHEM_LIBRARY_PATH "$pelib:$XSCHEM_LIBRARY_PATH"
        # the netlister's switches, as a fresh xschem has them
        set ::lvs_netlist 0 ; set ::lvs_ignore 0 ; set ::flat_netlist 0 ; set ::spiceprefix 1
        set petop [file join $pelib pe_top.sch]
        xschem load $petop
        set key [ase::new_session pelib pe_top schematic]
        set st [ase::session_state $key]
        dict set st rundir [file join $scratch pe_run]
        dict set st includes [list $pemod]
        dict set st analyses $::AN_OPTRAN
        ase::session_update $key $st
        set nopins {}
        for {set i 0} {$i < [xschem get instances]} {incr i} {
            if {![llength [pcall xschem instance_pins $i]]} { lappend nopins [pcall xschem getprop instance $i name] }
        }
        check {PE0 fixture: the bench's top sheet is loaded, EVERY instance on it resolved a symbol with pins (those that did not are named), it is the cellview the session is bound to, at level 0 of this window, and the session has no outputs yet} \
            [list [expr {[file normalize [xschem get schname]] eq [file normalize $petop]}] $nopins \
                  [pcall ase::design_of_path [file normalize $petop]] [pcall ase::ui::sod_base_level $key] \
                  [ase::state_get [ase::session_state $key] outputs]] \
            {1 {} {pelib pe_top schematic} 0 {}}

        # ---- the picks: Outputs > To Be Saved > Select On Design, armed by hand
        array unset ase::ui::sod $key,*
        array set ase::ui::sod [list $key,flavor {save 1 plot 0} $key,mode outputs $key,count 0]
        # the bit dialog is a Tk window: stood in for by one that takes every bit
        set ::pe_dlg {}
        rename ::ase::ui::bus_dialog ::ase::ui::pe_real_bus_dialog
        proc ::ase::ui::bus_dialog {key token bits} { lappend ::pe_dlg [list $token $bits] ; return $bits }
        pe_zoom
        set c_res  [pe_click $key RT P]
        set c_fet  [pe_click $key M9 D]
        set c_wrap [pe_click $key RW M]
        set c_blk  [pe_click $key x1 A]
        set c_bus  [pe_click $key {xb[1:0]} A]
        xschem unselect_all
        xschem select instance x1
        xschem descend
        pe_zoom
        set lvl [list [pcall xschem get currsch] [pcall xschem get sch_path]]
        set c_dres [pe_click $key R1 P]
        set c_dfet [pe_click $key M1 D]
        while {[xschem get currsch] > 0} { xschem go_back }
        xschem unselect_all
        rename ::ase::ui::bus_dialog {}
        rename ::ase::ui::pe_real_bus_dialog ::ase::ui::bus_dialog

        # ---- the session the picks left
        set st [ase::session_state $key]
        set rows [pd_col [ase::state_get $st outputs] expr]
        set flags {}
        foreach r [ase::state_get $st outputs] {
            lappend flags [list [ase::state_get $r save] [ase::state_get $r plot] [pcall ase::output_tab [ase::state_get $r expr]]]
        }
        check {PE1 THE ROWS ARE IN THE SESSION, written by the real ase::ui::sod_queue in click order: every one a Saves row, Save ticked and Plot not, and the mode counted each (rows, the distinct {save plot tab} among them, the mode's count)} \
            [list $rows [lsort -unique $flags] $ase::ui::sod($key,count)] \
            [list {i(rt:n1) i(xm9:d) i(xrw:r0) i(x1:a) {i(xb[1]:a)} {i(xb[0]:a)} i(x1.r1:n1) i(x1.xm1:d)} {{1 0 saves}} 8]

        # ---- netlist, deck, run
        # (what the netlister says on the way is not this band's: only its file)
        set nlf [lindex [pd_spy [list ase::netlist $st]] 0]
        set nl [pcall pd_rd $nlf]
        set gate [lindex [pd_spy [list ase::preflight_gate $st $nl]] 0]
        lassign [pn_bench $st $nl] rc log deck raw
        set terms {}
        foreach l [pd_lines $deck {^\.probe}] {
            foreach t [lrange [split $l] 1 end] { lappend terms $t }
        }
        check {PE2 THE DECK OF THAT SESSION over the netlist xschem made of the sheet: the netlist was written and holds the block's own `.subckt pe_blk A Y`, the pre-flight gate does not refuse it, the real `render_deck` asks for every picked terminal in a `.probe` card -- positions for the resistors, port names for the subcircuit calls -- and for none in a `.save` card, the Save ticks bringing the leader alone; the simulator runs it at exit 0 and writes an operating point and a transient; and the run's report has nothing to say (netlist raised, header, gate raised, terms, save cards, exit, op points > 0, tran points > 1, report)} \
            [list [string match ERR:* $nlf] [regexp -line {^\.subckt pe_blk A Y$} $nl] [string match ERR:* $gate] \
                  $terms [pd_lines $deck {^\.save}] $rc \
                  [expr {[pn_np $raw {Operating Point}] > 0}] [expr {[pn_np $raw {Transient Analysis}] > 1}] \
                  [lindex [pd_spy [list ase::probe_report $st [dict create probes [ase::probe_plan $st $nl fold]] $log $rc]] 0]] \
            [list 0 1 0 {I(rt,1) I(xm9,d) I(xrw,r0) I(x1,a) {I(xb[1],a)} {I(xb[0],a)} I(x1.r1,1) I(x1.xm1,d)} {{.save all}} 0 1 1 {}]

        # ---- one row per pick: the click, then its current in the results.
        # Each `pe_vec` answer is {in the operating point, in the transient, the
        # file's number is the pin's current, the database finds the row's own
        # text and holds that number}.
        catch {xschem raw clear}
        set rd [pcall xschem raw read $raw op]
        check {PE3 A RESISTOR, clicked on the pin on the driven net: the click queues the pin's position on the element line, i(rt:n1), and says nothing else; the run's results hold that vector in both plots, and it is the +1 mA flowing INTO that pin, in the file and through the database} \
            [list $c_res [pe_vec $raw i(rt:n1) 1e-3]] {{i(rt:n1) {}} {1 1 1 1}}
        check {PE4 A FET WRAPPER (a symbol of type nmos whose line calls a subcircuit, W=2), clicked on its drain: the click queues the PORT of the subcircuit at that position, i(xm9:d), found in the model file the session includes, and says nothing else; the vector is in both plots and is the 25 uA into that drain} \
            [list $c_fet [pe_vec $raw i(xm9:d) 25e-6]] {{i(xm9:d) {}} {1 1 1 1}}
        check {PE5 A RESISTOR WRAPPER WHOSE PORT IS NOT ITS SYMBOL'S PIN, clicked on pin M: the click queues the subcircuit's port r0 -- never the symbol's own `m` -- and says nothing else; the vector is in both plots and is the +0.5 mA into the pin on the driven net} \
            [list $c_wrap [pe_vec $raw i(xrw:r0) 5e-4]] {{i(xrw:r0) {}} {1 1 1 1}}
        check {PE6 A BLOCK xschem netlists itself, clicked on its pin A: the click queues the pin's own name as the port, i(x1:a), and says nothing else; the vector is in both plots and is the 62.5 uA the block draws through that pin -- the sum of the two currents row PE8 picks inside it} \
            [list $c_blk [pe_vec $raw i(x1:a) 62.5e-6]] {{i(x1:a) {}} {1 1 1 1}}
        check {PE7 A BUS INSTANCE, one click on pin A of the two-bit instance: the bit dialog is opened once and handed the two final tokens, each bit it returns becomes a row and nothing else is said; both vectors are in both plots, each the 62.5 uA of one instance of the block} \
            [list $::pe_dlg $c_bus [pe_vec $raw {i(xb[1]:a)} 62.5e-6] [pe_vec $raw {i(xb[0]:a)} 62.5e-6]] \
            [list [list [list {xb[1:0]:A} [list {xb[1]:A} {xb[0]:A}]]] [list [list {i(xb[1]:a)} {i(xb[0]:a)}] {}] {1 1 1 1} {1 1 1 1}]
        check {PE8 ONE LEVEL DOWN, inside the block instance x1 (level and sheet path asserted first): the same session's clicks on a resistor's pin and on the FET wrapper's drain there queue rows that carry the instance path, i(x1.r1:n1) and i(x1.xm1:d), and say nothing else; both vectors are in both plots, the 50 uA into the resistor and the 12.5 uA into the W=1 FET's drain} \
            [list $lvl $c_dres [pe_vec $raw i(x1.r1:n1) 50e-6] $c_dfet [pe_vec $raw i(x1.xm1:d) 12.5e-6]] \
            {{1 .x1.} {i(x1.r1:n1) {}} {1 1 1 1} {i(x1.xm1:d) {}} {1 1 1 1}}
        set stored [split [pcall xschem raw list] "\n"]
        catch {xschem raw clear}
        check {PE9 ...AND THE DATABASE FOUND THEM THROUGH ITS LOOKUP RUNG, not because it stores the row's text: the results loaded as an operating point, and the name it lists for the last of those rows has a `.` where the row has its `:` (read, the dotted name listed, the colon one not)} \
            [list $rd [expr {[lsearch -exact $stored i(x1.xm1.d)] >= 0}] [lsearch -exact $stored i(x1.xm1:d)]] {1 1 -1}

        # ---- Direct Plot on those results: only what the run probed
        array unset ase::ui::sod $key,*
        array set ase::ui::sod [list $key,flavor {save 0 plot 1} $key,mode plot $key,count 0]
        set ::pe_plotq {}
        rename ::ase::ui::dp_queue ::ase::ui::pe_real_dp_queue
        proc ::ase::ui::dp_queue {key ex {kind {}} {token {}}} { lappend ::pe_plotq [list $ex $kind] }
        lassign [pd_spy [list ase::ui::sod_click $key {*}[pe_pin RT P]]] r1 s1
        set q1 $::pe_plotq
        set ::pe_plotq {}
        lassign [pd_spy [list ase::ui::sod_click $key {*}[pe_pin RT M]]] r2 s2
        rename ::ase::ui::dp_queue {}
        rename ::ase::ui::pe_real_dp_queue ::ase::ui::dp_queue
        array unset ase::ui::sod $key,*
        check {PE10 DIRECT PLOT AFTER THAT RUN, on the session's own results file: the pin whose current the deck probed is queued as a trace of kind `terminal` and nothing is said; the other pin of the same resistor, which no row asked for, is not queued, and the one sentence names it (the session's results are the run's file; queued, said; queued, sentences, the sentence)} \
            [list [expr {[pcall ase::last_rawfile $key] eq $raw}] $q1 [pd_nth $s1 1] $::pe_plotq [llength $s2] \
                  [string match {ase: terminal current 'i(rt:n2)' is not in this session's results*} [lindex [lindex $s2 0] 1]]] \
            {1 {{i(rt:n1) terminal}} {} {} 1 1}
        catch {ase::session_close $key}
    }
}

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
