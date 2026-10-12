# tests/headless/test_ase_outputs_eval.tcl -- ASE-L Outputs are computed AFTER
# the run from the results file, and never reach the netlist (ruling
# 2026-10-11).
#
# The user: "Why would expressions in the outputs pane of ASE-L go to the
# netlist? They are computations made using the result of the simulation! They
# should not influence the input to the simulator."
#
# Spec     doc/claude/specs/ase_l.md R-OUT1..R-OUT6, R-OUT3a, R-OUT3b; calculator.md R609
# Code     src/ase.tcl ase::output_save_cards, ase::output_card_sources,
#          ase::output_is_plain, ase::output_is_signal, ase::preflight_scan,
#          ase::saves_op_phantom_risk,
#          ase::output_calc_text, ase::backend::ngspice::result_probe /
#          result_probe_calc / output_value_text; src/ase_window.tcl
#          ase::ui::results_from_disk; src/calculator.tcl calc::eval_texts
# Fixture  tests/headless/data/calc_fixture.raw (tran x2, AC, op), copied into
#          scratch as a session's `<cell>_ase.raw`; a transient-only cut of it;
#          and, when the registry's ngspice is there, a real run.
#
# Bands
#   OE1  the deck: no `print`, no expression text, the right `.save` cards
#   OE2  an expression's tick never narrows a deck
#   OE3  post-run fill through the registered `result_probe` hook: scalars,
#        `wave`, refusals, a negated current, a measurement
#   OE4  a transient-only run: a plain signal reads `wave`, not a last point
#   OE5  an OLD state file loads unchanged and fills its Value column on open
#        (ase::ui::results_from_disk, the open/Load State path)
#   OE6  the Value cell's text is ase::format_value of the answer
#   OE8  a stale slot of the results file (OP annotation, the Calculator) is
#        not read in place of the new run's file
#   OE9  the pre-flight checks the cards that reach the deck and nothing else
#   OE10 the op phantom guard counts the deck's vectors, not ticked rows
#   OE11 an infix expression is not a plain signal; its text never reaches
#        the deck (derived over every committed bench row)
#   OE12 the no-value note agrees with the cell (a `wave` row is not named)
#   OE13 REAL ngspice: every committed non-plain, non-measurement bench row
#        (derived without the router, FLOOR 9) routes as infix and shows
#        the value the former print path gave, on a synthetic circuit built
#        from the row's own reads with the bench's own analyses
#   OE14 no output text can stop the run: an unticked leading-zero number or
#        deep nesting neither raises nor refuses
#   OE7  REAL ngspice (the registry's): the plain row equals the number the old
#        `print` gave, the expression's signal was saved, and the deck carries
#        no print -- skipped with a lowercase skip: line when absent
#
# REGISTERED IN `hcases`: nothing here needs a display.  The Value CELL is
# painted by ase::ui::refresh_output_values, which only ever writes
# `[ase::format_value $val]` into the tree -- OE6 pins that text headlessly.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_outputs_eval

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
set ::abortnames {}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        lappend ::abortnames $name
        incr ::fail
    }
}
proc val {res k} {
    if {[catch {dict exists $res $k} e] || !$e} { return ABSENT }
    return [dict get $res $k]
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set scratch [test_scratch ase_outputs_eval]
set fixture [file join $here data calc_fixture.raw]

# A state whose results file is <scratch>/<cell>_ase.raw.
proc oe_state {cell outs {analyses {}}} {
    set s [ase::state_default]
    dict set s design [dict create lib oe cell $cell view schematic]
    dict set s rundir $::scratch
    dict set s outputs $outs
    if {$analyses ne {}} { dict set s analyses $analyses }
    return $s
}
set AN_OPTRAN {{type op enabled 1} {type dc enabled 0} {type ac enabled 0}
               {type tran enabled 1 stop 10u step 100n}}
set NL "* oe\nv1 in 0 dc 1\nr1 in mid 1k\nr2 mid out 1k\nr3 out 0 1k\nc1 out 0 1n\n.end\n"
proc oe_deck {st} {
    return [pcall [ase::backend_hook ngspice render_deck] $st $::NL]
}
proc oe_lines {deck re} {
    set out {}
    foreach l [split $deck "\n"] {
        if {[regexp $re [string trim $l]]} { lappend out [string trim $l] }
    }
    return $out
}

# =============================================================================
# OE1 -- THE DECK
# =============================================================================
set EXPRS [list {cross(vt(mid), 0.5, 1, rising)} {v(in) v(out) -} {vf(out)}]
group OE1 {
    set outs [list {name o expr v(out) save 1 plot 0} \
                   [list name x expr [lindex $::EXPRS 0] save 1 plot 0] \
                   [list name d expr [lindex $::EXPRS 1] save 0 plot 0]]
    set deck [oe_deck [oe_state oe1 $outs $::AN_OPTRAN]]
    check "OE1 fixture: the deck rendered" [string match ERR:* $deck] 0
    check "OE1 the deck carries NO print line at all" [oe_lines $deck {^print(\s|$)}] {}
    set leaked {}
    foreach o $outs {
        set ex [dict get $o expr]
        if {[ase::output_is_plain $ex]} continue
        if {[string first $ex $deck] >= 0} { lappend leaked $ex }
        foreach w [regexp -all -inline {[A-Za-z_]+\(} $ex] {
            if {$w in {v( i( vt( vf( vdc( vs(}} continue
            if {[string first $w $deck] >= 0} { lappend leaked $w }
        }
    }
    check "OE1 no expression row's text -- nor its measurement verb -- appears anywhere in the deck (rows derived from the state's own non-plain outputs, count then leaks)" \
        [list [llength [lsearch -all -inline -not [lmap o $outs {ase::output_is_plain [dict get $o expr]}] 1]] $leaked] \
        {2 {}}
    check "OE1 the save list: the ticked plain signal, then every signal the expressions read -- ticked or not -- each once, and nothing else" \
        [oe_lines $deck {^\.save }] {{.save v(out)} {.save v(mid)} {.save v(in)}}
    check "OE1 ase::saves_narrowed agrees: this deck IS narrowed" \
        [ase::saves_narrowed [oe_state oe1 $outs]] 1
    check "OE1 a plain row's R208c qualifier and Cadence quotes are not ngspice's: vt(out) and v(\"mid\") are saved as v(out) and v(mid)" \
        [ase::output_save_cards [oe_state oe1 {{expr vt(out) save 1} {expr v("mid") save 1}}]] \
        {v(out) v(mid)}
}

# =============================================================================
# OE2 -- AN EXPRESSION'S TICK NEVER NARROWS A DECK
# =============================================================================
group OE2 {
    set outs [list [list name x expr [lindex $::EXPRS 0] save 1 plot 0] \
                   [list name y expr [lindex $::EXPRS 1] save 1 plot 0]]
    set deck [oe_deck [oe_state oe2 $outs $::AN_OPTRAN]]
    check "OE2 a bench whose only ticked rows are expressions gets NO .save card, so ngspice keeps every signal (measured: any .save keeps only what is listed)" \
        [list [oe_lines $deck {^\.save }] [ase::saves_narrowed [oe_state oe2 $outs]] \
              [ase::output_save_cards [oe_state oe2 $outs]]] {{} 0 {}}
    check "OE2 control: the same bench plus one ticked plain row IS narrowed, and then carries the expressions' signals too" \
        [ase::output_save_cards [oe_state oe2 [concat $outs {{expr v(out) save 1}}]]] \
        {v(out) v(mid) v(in)}
    check "OE2 an unticked plain row is not saved" \
        [ase::output_save_cards [oe_state oe2 {{expr v(out) save 1} {expr v(in) save 0}}]] v(out)
}

# =============================================================================
# OE3 -- POST-RUN FILL, through the registered hook
# =============================================================================
group OE3 {
    file copy -force $::fixture [file join $::scratch oe3_ase.raw]
    set outs {{name lp expr v(lp) save 1}
              {name dc expr v(dcmid) save 1}
              {name gm expr @m1[gm] save 1}
              {name nid expr -i(@m1[id]) save 1}
              {name w expr vt(lp) save 1}
              {name x expr {cross(vt(lp), 0.5, 1, rising)} save 1}
              {name y expr {v(dcmid) 2 * 1 +} save 1}
              {name bad expr {nosuch 2 *} save 1}
              {name infix expr {v(dcmid)*2} save 1}}
    set res [pcall [ase::backend_hook ngspice result_probe] [oe_state oe3 $outs] {}]
    set xref [calc::eval_text {cross(vt(lp), 0.5, 1, rising)} $::fixture {}]
    check "OE3 plain signals read the OPERATING POINT (0 and 3 -- distinct), a device parameter its op value, and a negated current the negative of its op value" \
        [list [val $res lp] [val $res dc] [val $res gm] [val $res nid]] \
        {0.000000e+00 3.000000e+00 1.339000e-03 -8.703500e-04}
    check "OE3 a waveform answer is the word wave, never a last point" [val $res w] wave
    check "OE3 a measurement call is the Calculator's own number, %.6e" \
        [list [dict get $xref ok] [val $res x]] [list 1 [format %.6e [dict get $xref value]]]
    check "OE3 plain RPN 'v(dcmid) 2 * 1 +' is 7, computed after the run" [val $res y] 7.000000e+00
    check "OE3 a refusal is the Calculator's sentence, naming what is wrong; and INFIX is the Calculator's own syntax too (calculator.md R610), so 'v(dcmid)*2' is 6 -- ADE-L's algebra, computed after the run" \
        [list [val $res bad] [val $res infix]] \
        [list {Cannot evaluate: unknown token 'nosuch' (not an operator/function, number or raw variable).} \
              6.000000e+00]
    catch {xschem raw clear}
    set i0 [pcall xschem raw info]
    pcall [ase::backend_hook ngspice result_probe] [oe_state oe3 $outs] {}
    check "OE3 the probe leaves the raw registry as it found it" [pcall xschem raw info] $i0
    file delete -force [file join $::scratch oe3_ase.raw]
    set res2 [pcall [ase::backend_hook ngspice result_probe] [oe_state oe3 $outs] {}]
    check "OE3 with NO results file nothing is recorded -- no sentence per row either" \
        [pcall dict size $res2] 0
}

# =============================================================================
# OE4 -- A TRANSIENT-ONLY RUN
# =============================================================================
proc oe_tran_only {out} {
    set f [open $::fixture r]
    fconfigure $f -translation binary
    set all [read $f]
    close $f
    set b [string first "Binary:\n" $all]
    regexp {No\. Variables:[ \t]*([0-9]+)} [string range $all 0 $b] -> nv
    regexp {No\. Points:[ \t]*([0-9]+)} [string range $all 0 $b] -> np
    set end [expr {$b + 8 + $nv * $np * 8 - 1}]
    set o [open $out w]
    fconfigure $o -translation binary
    puts -nonewline $o [string range $all 0 $end]
    close $o
}
group OE4 {
    oe_tran_only [file join $::scratch oe4_ase.raw]
    check "OE4 fixture: the cut holds the transient alone" \
        [calc::raw_analyses [file join $::scratch oe4_ase.raw]] tran
    set res [pcall [ase::backend_hook ngspice result_probe] \
                 [oe_state oe4 {{name lp expr v(lp) save 1} {name x expr {cross(v(lp), 0.5, 1, rising)} save 1}
                                {name s expr vdc(lp) save 1}}] {}]
    check "OE4 with no operating point a plain signal reads wave (it was blank under the prints), a measurement still answers, and an op-qualified row says the run has none" \
        [list [val $res lp] [string is double -strict [val $res x]] [val $res s]] \
        {wave 1 {Cannot evaluate: this result has no operating point analysis}}
}

# =============================================================================
# OE5 -- AN OLD STATE FILE, OPENED
# =============================================================================
group OE5 {
    set d [file join $::scratch oe5]
    file mkdir $d
    file copy -force $::fixture [file join $d tb_old_ase.raw]
    set sf [file join $d old.state]
    set f [open $sf w]
    puts $f "version 1"
    puts $f "simulator ngspice"
    puts $f "design {lib oe cell tb_old view schematic}"
    puts $f "rundir [list $d]"
    puts $f "temperature 27"
    puts $f "analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 200u step 10n}}"
    puts $f "outputs {{name DC expr v(dcmid) save 1 plot 1} {name ID expr -i(@m1\[id\]) save 1 plot 1} {name LP expr lp save 1 plot 0}}"
    puts $f "save_all_v 1"
    close $f
    set key oe/tb_old/state5
    ase::session_open $key $sf
    set st [ase::session_state $key]
    check "OE5 the old state loads with its outputs exactly as written -- no field added or lost" \
        [ase::state_get $st outputs] \
        {{name DC expr v(dcmid) save 1 plot 1} {name ID expr -i(@m1[id]) save 1 plot 1} {name LP expr lp save 1 plot 0}}
    check "OE5 ...and fills its Value column on OPEN through ase::ui::results_from_disk, from the results file alone" \
        [pcall ase::ui::results_from_disk $key] \
        {DC 3.000000e+00 LP 0.000000e+00 ID -8.703500e-04}
    set deck [oe_deck $st]
    check "OE5 ...and its deck carries its save cards verbatim and no print" \
        [list [oe_lines $deck {^\.save }] [oe_lines $deck {^print(\s|$)}]] \
        [list {{.save all} {.save v(dcmid)} {.save -i(@m1[id])} {.save lp}} {}]
    catch {ase::session_close $key}
}

# =============================================================================
# OE6 -- WHAT THE CELL SHOWS
# =============================================================================
group OE6 {
    set saved [expr {[info exists ::ase_eng_notation] ? $::ase_eng_notation : {}}]
    set ::ase_eng_notation 1
    check "OE6 the cell text is ase::format_value of the answer: engineering for a number, the word and the sentence verbatim" \
        [list [ase::format_value 7.000000e+00] [ase::format_value -8.703500e-04] \
              [ase::format_value wave] [ase::format_value {Cannot evaluate: x}]] \
        {7 -870.4u wave {Cannot evaluate: x}}
    if {$saved ne {}} { set ::ase_eng_notation $saved }
}

# =============================================================================
# OE8 -- A STALE SLOT FOR THE RESULTS FILE IS NOT READ IN THE NEW RUN'S PLACE
# =============================================================================
# OP annotation or the Calculator can leave the results file loaded; the user
# re-runs and ngspice overwrites the file.  `xschem raw read` of that path
# would SWITCH to the old slot, so the expression row would show the previous
# run's number next to a plain row that parses the new file directly.  The new
# file differs from the loaded one only in v(dcmid): 3 loaded, 5 on disk.
proc oe8_patched {src dst net val} {
    set fh [open $src rb] ; set b [read $fh] ; close $fh
    set at [string last "Plotname: Operating Point" $b]
    set hdr [string range $b $at [expr {[string first "Binary:\n" $b $at] - 1}]]
    set nv {} ; set idx {}
    regexp {No\. Variables:[ \t]*([0-9]+)} $hdr -> nv
    regexp "\t(\[0-9\]+)\t[string map {( \\( ) \\)} $net]\t" $hdr -> idx
    if {$nv eq {} || $idx eq {}} { return NOPATCH }
    set off [expr {[string length $b] - 8 * $nv + 8 * $idx}]
    set b [string replace $b $off [expr {$off + 7}] [binary format d $val]]
    set fh [open $dst wb] ; puts -nonewline $fh $b ; close $fh
    return ok
}
group OE8 {
    set p [file join $::scratch oe8_ase.raw]
    set q [file join $::scratch oe8_new.raw]
    file copy -force $::fixture $p
    check "OE8 fixture: the new run's file was written with v(dcmid) patched to 5" \
        [oe8_patched $::fixture $q v(dcmid) 5.0] ok
    set outs {{name a expr v(dcmid) save 1} {name b expr {v(dcmid) 1 *} save 1}}
    catch {xschem raw clear}
    xschem raw read $p op
    set i0 [pcall xschem raw info]
    file copy -force $q $p
    set res [pcall [ase::backend_hook ngspice result_probe] [oe_state oe8 $outs] {}]
    check "OE8 with the OLD run's results loaded (v(dcmid) = 3), both the plain row and the expression row read the NEW file (5) -- one Value column, one run" \
        [list [val $res a] [val $res b]] {5.000000e+00 5.000000e+00}
    check "OE8 ...and the loaded slot is left as it was (registry text, its own 3)" \
        [list [expr {[pcall xschem raw info] eq $i0}] [lindex [pcall xschem raw values v(dcmid) 0] 0]] {1 3}
    catch {xschem raw clear}
    file delete -force $p $q
}

# =============================================================================
# OE9 -- THE PRE-FLIGHT CHECKS WHAT REACHES THE DECK, AND NOTHING ELSE
# =============================================================================
# ase::preflight_gate refuses a run whose `.save` card names something the
# circuit lacks.  Only a ticked PLAIN row's card is checked: an output
# EXPRESSION, ticked or not, can never block or refuse a run (R-OUT3a, fix
# round 2026-10-11).  The signals an expression reads still become cards on a
# narrowed deck -- measured harmless when absent on the registry ngspice -- and
# a missing one is reported in that row's Value after the run.
proc oe9_gate {outs} {
    set rc [catch {ase::preflight_gate [oe_state oe9 $outs $::AN_OPTRAN] $::NL} e]
    return [list $rc [expr {[string first REFUSED $e] >= 0}]]
}
proc oe9_absent {outs} {
    set sc [ase::preflight_scan [oe_state oe9 $outs $::AN_OPTRAN] $::NL]
    return [lsort -unique [lmap r [dict get $sc absent] {dict get $r ident}]]
}
group OE9 {
    set ::sim_case_mode fold
    check "OE9 a ticked expression in the Calculator's QUOTED form, on a node the circuit has, does not block the run" \
        [oe9_gate {{expr {v("out") 2 *} save 1}}] {0 0}
    check "OE9 a ticked expression naming a node the circuit lacks adds no card (output_save_cards is empty), so it does not block the run either -- its Value says what is wrong after the run" \
        [list [ase::output_save_cards [oe_state oe9 {{expr {v(typo) 2 *} save 1}}]] \
              [oe9_gate {{expr {v(typo) 2 *} save 1}}]] {{} {0 0}}
    check "OE9 an UNTICKED expression whose absent signal DOES become a card (the deck is narrowed by v(out)) does NOT block the run: the card is in the deck, the gate passes" \
        [list [ase::output_save_cards [oe_state oe9 {{expr v(out) save 1} {expr {v(typo) 2 *} save 0}}]] \
              [oe9_gate {{expr v(out) save 1} {expr {v(typo) 2 *} save 0}}]] {{v(out) v(typo)} {0 0}}
    check "OE9 ...nor does a TICKED one, in infix, on the same narrowed deck" \
        [oe9_gate {{expr v(out) save 1} {expr {v(typo)*2} save 1}}] {0 0}
    check "OE9 control: the ticked PLAIN row's own absent card on that deck IS still refused" \
        [oe9_gate {{expr v(typo) save 1} {expr {v(out)*2} save 0}}] {1 1}
    check "OE9 a ticked plain row in R208c's vt() form is checked as the card it becomes, v(typo)" \
        [oe9_gate {{expr vt(typo) save 1}}] {1 1}
    set outs {{expr v(nope1) save 1} {expr {v(nope2) v(nope3) -} save 0}
              {expr {v(nope4) 2 *} save 1} {expr -i(vnope5) save 1}}
    set srcs [ase::output_card_sources [oe_state oe9 $outs]]
    set want {}
    set nplain 0
    foreach sc $srcs {
        if {[lindex $sc 2] ne {plain}} continue
        incr nplain
        foreach id [ase::preflight_idents [lindex $sc 1]] { lappend want [lindex $id 1] }
    }
    check "OE9 DERIVED: on a bench where every name is absent, the scan's absent identifiers are exactly the identifiers of the PLAIN cards (role read off ase::output_card_sources) -- the deck carries more cards than that, and their reads are not checked (cards, plain cards, then the set)" \
        [list [llength $srcs] $nplain [oe9_absent $outs]] [list 5 2 [lsort -unique $want]]
    check "OE9 every card source carries a role, and the roles are exactly plain and read" \
        [lsort -unique [lmap sc $srcs {lindex $sc 2}]] {plain read}
}

# =============================================================================
# OE14 -- NO OUTPUT TEXT CAN STOP THE RUN, HOWEVER IT IS SPELLED (fix round
# 2026-10-11, verifier at a21d2cd2)
# =============================================================================
# An UNTICKED `v(out)*09` used to make the deck render and the pre-flight scan
# RAISE (Tcl's octal reading of `09`), so ase::run_deck never started the
# simulator.  Same for a deep nesting.  Each row is now an ordinary text: it is
# read for the save list without raising, and the run proceeds.
group OE14 {
    set ::sim_case_mode fold
    foreach {nm txt} [list zero {v(out)*09} deep "[string repeat ( 400]v(out)[string repeat ) 400]"] {
        set outs [list {expr v(out) save 1} [list expr $txt save 0]]
        set d [oe_deck [oe_state oe13 $outs $::AN_OPTRAN]]
        set sc [pcall ase::preflight_scan [oe_state oe13 $outs $::AN_OPTRAN] $::NL]
        check "OE14 an UNTICKED $nm row beside a ticked v(out): the deck renders (no raise), the pre-flight scan runs (no raise), and the gate passes" \
            [list [string match ERR:* $d] [string match ERR:* $sc] [oe9_gate $outs]] {0 0 {0 0}}
        check "OE14 ...and the deck carries v(out)'s card" \
            [expr {[llength [oe_lines $d {^\.save .*v\(out\)}]] > 0}] 1
    }
}

# =============================================================================
# OE10 -- THE OP PHANTOM GUARD COUNTS VECTORS IN THE DECK, NOT TICKED ROWS
# =============================================================================
group OE10 {
    set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
    set r1 [ase::saves_op_phantom_risk ngspice [oe_state oe10 {{expr v(out) save 1} {expr {v(out) 2 *} save 1}} $an]]
    set r2 [ase::saves_op_phantom_risk ngspice [oe_state oe10 {{expr v(out) save 1} {expr {v(mid) 2 *} save 0}} $an]]
    set r3 [ase::saves_op_phantom_risk ngspice [oe_state oe10 {{expr v(out) save 1}} $an]]
    check "OE10 one card in the deck is the lone-op-save risk however many rows are ticked; two cards are not; control: a lone ticked plain row is" \
        [list $r1 $r2 $r3] {1 0 1}
}

# =============================================================================
# OE11 -- AN INFIX EXPRESSION IS NOT A PLAIN SIGNAL, AND ITS TEXT NEVER REACHES THE DECK
# =============================================================================
proc oe11_committed_rows {} {
    set root [file normalize [file join $::here .. ..]]
    set rows {}
    if {[catch {exec git -C $root ls-files *.state} lst]} { return ERR }
    foreach fn [split [string trim $lst] "\n"] {
        if {[catch {set fh [open [file join $root $fn] r]}]} continue
        set t [read $fh] ; close $fh
        if {[catch {dict get $t outputs} outs]} continue
        foreach o $outs { if {[dict exists $o expr]} { lappend rows $o } }
    }
    return $rows
}
group OE11 {
    check "OE11 output_is_plain: an infix or nested form is an expression" \
        [lmap e {Vcc/I(Vr) (Vcc-Vss)/I(Vsil) v(dcmid)*2 db(i(vd)/i(vg)) 2*vdb(x)} {ase::output_is_plain $e}] \
        {0 0 0 0 0}
    check "OE11 control: one signal, in every committed spelling, is plain" \
        [lmap e {v(out) i(vdd) -i(v1) @m1[gm] -i(@m1[id]) VBG vt("x") v(a,b) x1.out a[3]} {ase::output_is_plain $e}] \
        {1 1 1 1 1 1 1 1 1 1}
    check "OE11 a narrowed deck carries the infix row's READS, each its own single-signal card (Vcc and I(Vr)), and never its text" \
        [ase::output_save_cards [oe_state oe11 {{expr v(out) save 1} {expr Vcc/I(Vr) save 1}}]] {v(out) Vcc I(Vr)}
    check "OE11 a text the Calculator refuses before any read makes NO card: a postfix stack fault, an unknown function, a short measurement call, a trailing operator" \
        [ase::output_save_cards [oe_state oe11 {{expr v(out) save 1} {expr {v(za) v(zb)} save 0}
                                               {expr foo(v(zc)) save 0} {expr {cross(v(zd), 0.5)} save 0}
                                               {expr v(ze)* save 1}}]] v(out)
    set rows [oe11_committed_rows]
    set ninfix 0
    set bad {}
    foreach o $rows {
        set e [string trim [dict get $o expr]]
        if {[regexp {[*/+]|.-|\)\S} $e] && ![ase::output_is_plain $e]} { incr ninfix }
        foreach c [ase::output_save_cards [oe_state oe11 [list {expr v(anchor) save 1} $o]]] {
            if {[regexp {[*/+]|^\(|.-} $c]} { lappend bad $c }
        }
    }
    check "OE11 DERIVED over every committed bench row (git ls-files *.state): there ARE infix rows, and not one of them yields a card that is not a single signal (count > 0, offenders)" \
        [list [expr {$ninfix > 0}] [lsort -unique $bad]] {1 {}}
}

# =============================================================================
# OE12 -- THE NOTE ON SCREEN AGREES WITH THE CELL
# =============================================================================
proc oe12_said {script} {
    set ::oe12 {}
    set had [expr {[info commands ::ciw_echo] ne {}}]
    if {$had} { rename ::ciw_echo ::oe12_saved }
    proc ::ciw_echo {line {tag {}}} { lappend ::oe12 $line ; return {} }
    catch {uplevel 1 $script} r
    catch {rename ::ciw_echo {}}
    if {$had} { rename ::oe12_saved ::ciw_echo }
    return [list $r $::oe12]
}
group OE12 {
    oe_tran_only [file join $::scratch oe12_ase.raw]
    lassign [oe12_said {[ase::backend_hook ngspice result_probe] \
        [oe_state oe12 {{name lp expr v(lp) save 1} {name ns expr v(nosuch) save 1}}] {}}] res said
    set note {}
    foreach l $said { if {[string match {*no single-point value*} $l]} { set note $l } }
    check "OE12 a transient-only plain row's cell is wave, and the no-value note does NOT name it; a vector the file lacks still has no value and IS named" \
        [list [val $res lp] [val $res ns] [expr {$note ne {}}] \
              [expr {[string first v(lp) $note] >= 0}] [expr {[string first v(nosuch) $note] >= 0}]] \
        {wave ABSENT 1 0 1}
}

# =============================================================================
# OE7 -- THE REAL SIMULATOR (the ASE-L registry's ngspice)
# =============================================================================
proc oe_registry_ngspice {} {
    set f [file join [test_real_home] .xschem ase_simulators]
    if {![file readable $f]} { return {} }
    set fh [open $f r]
    set t [read $fh]
    close $fh
    foreach ln [split $t "\n"] {
        if {[regexp {^\s*ase::sim_reg[i]ster\s+(\S+)\s+(\S+)} $ln -> nm path]} {
            if {[file executable $path]} { return $path }
        }
    }
    return {}
}
set NG [oe_registry_ngspice]
if {$NG eq {}} {
    puts "skip: OE7 -- no executable ngspice registered in [file join [test_real_home] .xschem ase_simulators], so the real-run rows did not run"
} else {
    group OE7 {
        set d [file join $::scratch oe7]
        file mkdir $d
        set home [file join $::scratch oe7home]
        file mkdir $home
        set outs {{name out expr v(out) save 1 plot 0}
                  {name cur expr i(v1) save 1 plot 0}
                  {name dbl expr {v(mid) 2 *} save 0 plot 0}}
        set st [oe_state oe7 $outs $::AN_OPTRAN]
        dict set st rundir $d
        set deck [oe_deck $st]
        set df [file join $d oe7.cir]
        set f [open $df w] ; puts -nonewline $f $deck ; close $f
        set rc [catch {exec env -u DISPLAY HOME=$home timeout 60 $::NG -b $df 2>@1} log]
        set raw [file join $d oe7_ase.raw]
        check "OE7 the registry ngspice ran the rendered deck and wrote the results file" \
            [list [file isfile $raw] [oe_lines $deck {^print(\s|$)}]] {1 {}}
        check "OE7 the results file holds the two analyses the deck asked for, op and tran (calc::raw_analyses)" \
            [lsort [calc::raw_analyses $raw]] {op tran}
        catch {xschem raw clear}
        xschem raw read $raw op
        set have [split [string trim [xschem raw list]] "\n"]
        catch {xschem raw clear}
        check "OE7 its operating point holds exactly three vectors (raw list): the ticked v(out) and i(v1), plus the expression's signal v(mid), which was NOT ticked -- the save list narrowed the deck and carried it" \
            [lsort $have] [lsort {v(out) i(v1) v(mid)}]
        set res [pcall [ase::backend_hook ngspice result_probe] $st $log]
        # THE FORMER PRINT, measured on the same netlist by a deck that still
        # carries one -- the number the Value column used to show.
        set pf [file join $d oe7p.cir]
        set f [open $pf w]
        puts $f "* oe7 print reference"
        puts -nonewline $f [string map [list "* oe\n" ""] [string map [list ".end\n" ""] $::NL]]
        puts $f ".control"
        puts $f "op"
        puts $f "print v(out)"
        puts $f "print i(v1)"
        puts $f "print v(mid)"
        puts $f ".endc"
        puts $f ".end"
        close $f
        catch {exec env -u DISPLAY HOME=$home timeout 60 $::NG -b $pf 2>@1} plog
        set pr {}
        foreach k {v(out) i(v1) v(mid)} {
            set re "^[string map {( \\( ) \\)} $k] = (\\S+)"
            if {[regexp -line $re $plog -> v]} { lappend pr $v } else { lappend pr NOPRINT }
        }
        # ngspice prints a VOLTAGE `%.6e` and a CURRENT with one digit fewer
        # (measured: `i(v1) = -3.33333e-04` beside the file's -3.333333e-04),
        # so the voltage is compared string for string and the current to the
        # precision the print carried.
        set cur [val $res cur]
        set pc [lindex $pr 1]
        set curok [expr {[string is double -strict $cur] && [string is double -strict $pc]
                         && abs($cur - $pc) <= abs($pc) * 1e-5}]
        check "OE7 the plain rows' Values ARE the numbers ngspice's own print gave for the operating point: the voltage string for string, the current to the print's own precision" \
            [list [val $res out] $curok] [list [lindex $pr 0] 1]
        check "OE7 the expression row is computed after the run: 2 x the printed v(mid)" \
            [val $res dbl] [format %.6e [expr {2.0 * [lindex $pr 2]}]]
        check "OE7 DISTINCTNESS: the three printed numbers differ pairwise, so no row could pass by reading another's" \
            [llength [lsort -unique $pr]] 3
    }

    # =========================================================================
    # OE13 -- THE COMMITTED INFIX ROWS, ON THE REAL SIMULATOR
    # =========================================================================
    # Nine committed bench rows are ngspice infix (`Vcc/I(Vr)`,
    # `(Vcc-Vss)/I(Vsil)`, `db(i(vd)/i(vg))`): they showed a printed number,
    # then a refusal once Outputs left the netlist, and show a value again now
    # that the Calculator reads infix (calculator.md R610).  Their benches need
    # PDK models this machine does not have, so each row runs on a SYNTHETIC
    # circuit built from the signals the row itself reads (derived by
    # calc::eval_text_signals: a bare name or v() is a node held by its own
    # source, an i() is a 0 V source fed through its own resistor), with the
    # bench's OWN analyses rendered by ASE-L's own deck.  The reference is the
    # former print path, run on the same circuit: `op` then `print <row>` --
    # where issue 1243 anchored the prints whenever the operating point is on,
    # as it is on all of these benches.
    proc oe13_rows {} {
        set out {}
        if {[catch {exec git -C [file normalize [file join $::here .. ..]] ls-files *.state} lst]} { return ERR }
        foreach fn [split [string trim $lst] "\n"] {
            set fp [file join [file normalize [file join $::here .. ..]] $fn]
            if {[catch {set fh [open $fp r]}]} continue
            set t [read $fh] ; close $fh
            if {[catch {dict get $t outputs} outs]} continue
            set an {}
            catch {set an [dict get $t analyses]}
            foreach o $outs {
                if {![dict exists $o expr]} continue
                set e [string trim [dict get $o expr]]
                if {[ase::output_is_plain $e]} continue
                if {[calc::meas_split $e] ne {}} continue
                lappend out [list $fn $o $an]
            }
        }
        return $out
    }
    # The supply the odd-numbered read currents flow from is the bench's own DC
    # sweep source when it sweeps one (so the sweep moves the reads), steps
    # from 2 to 3 V at 1 ns in a transient, and every such resistor has a
    # temperature coefficient, so a temperature sweep moves them too; the
    # even-numbered ones flow from a fixed 1.5 V, so a RATIO of two currents
    # moves as well.  The reads therefore differ between the operating point
    # and the other analysis, which is what the discrimination row measures.
    proc oe13_circuit {reads an} {
        set sup vsup
        foreach a $an {
            if {[dict exists $a source] && [string tolower [dict get $a source]] ne {temp}} {
                set sup [dict get $a source]
            }
        }
        set nl "* oe13\n$sup nsup 0 dc 2 pwl(0 2 1n 3)\nvnfix nfix 0 dc 1.5\n"
        set k 0
        set j 0
        foreach r $reads {
            incr k
            if {[regexp {^[iI]\((.+)\)$} $r -> src]} {
                incr j
                set from [expr {$j % 2 ? {nsup} : {nfix}}]
                append nl "$src cx$k 0 dc 0\nrx$k $from cx$k [expr {1000 * $k + 137}] tc1=0.01\n"
            } else {
                regexp {^[vV]\((.+)\)$} $r -> r
                append nl "vfix$k $r 0 dc [expr {0.75 + 0.5 * $k}]\n"
            }
        }
        return "$nl.end\n"
    }
    group OE13 {
        set rows [oe13_rows]
        set n 0
        set bad {}
        set far {}
        set said {}
        set notinfix {}
        foreach row $rows {
            lassign $row fn o an
            incr n
            if {[dict get [calc::ix_route [dict get $o expr]] mode] ne {infix}} {
                lappend notinfix "$fn:[dict get $o expr]"
            }
            set ex [dict get $o expr]
            set reads [calc::eval_text_signals $ex]
            set nl [oe13_circuit $reads $an]
            set d [file join $::scratch oe13_$n]
            file mkdir $d
            set st [oe_state oe13_$n [list [dict create name r expr $ex save [dict get $o save] plot 0]] $an]
            dict set st rundir $d
            set deck [pcall [ase::backend_hook ngspice render_deck] $st $nl]
            set df [file join $d oe13.cir]
            set f [open $df w] ; puts -nonewline $f $deck ; close $f
            catch {exec env -u DISPLAY HOME=$::scratch timeout 120 $::NG -b $df 2>@1} log
            set res [pcall [ase::backend_hook ngspice result_probe] $st $log]
            set pf [file join $d oe13p.cir]
            set f [open $pf w]
            puts -nonewline $f [string map [list ".end\n" ""] $nl]
            puts $f ".control\nop\nprint $ex\n.endc\n.end"
            close $f
            catch {exec env -u DISPLAY HOME=$::scratch timeout 60 $::NG -b $pf 2>@1} plog
            set pv NOPRINT
            foreach ln [split $plog "\n"] {
                if {[regexp {^\S.*\s=\s+(\S+)\s*$} $ln -> v] && [string is double -strict $v]} { set pv $v }
            }
            set got [val $res r]
            lappend said "$fn [list $ex] value=$got print=$pv"
            if {![string is double -strict $got] || ![string is double -strict $pv]
                || abs($got - $pv) > abs($pv) * 1e-5} {
                lappend bad "$fn:$ex got=$got print=$pv"
            }
            set other {}
            foreach a $an {
                if {[dict get $a enabled] eq {1} && [dict get $a type] ne {op}} { set other [dict get $a type] }
            }
            if {$other ne {}} {
                set w [calc::eval_text [ase::output_calc_text $ex] [file join $d oe13_${n}_ase.raw] $other]
                if {![dict get $w ok] || ![string is double -strict $got]
                    || abs([dict get $w value] - $got) <= abs($got) * 1e-5} {
                    lappend far "$ex:$other=[dict get $w value]/[dict get $w msg]"
                }
            }
        }
        foreach l $said { puts "note: OE13 $l" }
        check "OE13 DERIVED over every committed bench row (git ls-files *.state): every ngspice-infix row now shows a VALUE, equal (to print's precision) to what the former print path gave on the registry ngspice for the same circuit and the bench's own analyses (population > 0, misses)" \
            [list [expr {$n > 0}] $bad] {1 {}}
        # The population is every committed non-plain, non-measurement row --
        # derived WITHOUT asking the router, so a routing change that stopped
        # reading these as infix cannot shrink it silently (verifier,
        # 2026-10-11: a `> 0` population would have stayed green on one row).
        # FLOOR 9 is a RATCHET over the committed benches, not a baseline: a
        # bench that adds such a row raises it; one that loses a row reddens.
        check "OE13 POPULATION: every committed non-plain, non-measurement Outputs row (derived without the router) ROUTES AS INFIX, and there are at least nine of them (FLOOR: 9; count >= floor, then rows that did not route infix)" \
            [list [expr {$n >= 9}] $notinfix] {1 {}}
        check "OE13 DISCRIMINATION, measured per row: the same text read in the bench's other enabled analysis (its last point) differs, so a value read from the wrong analysis could not pass" \
            $far {}
    }
}

catch {xschem raw clear}
check "EVERY band above this one RAN TO ITS END (names of any abandoned band)" \
    [list [llength $::abortnames] $::abortnames] {0 {}}

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
