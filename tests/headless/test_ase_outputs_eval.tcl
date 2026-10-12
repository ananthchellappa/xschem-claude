# tests/headless/test_ase_outputs_eval.tcl -- ASE-L Outputs are computed AFTER
# the run from the results file, and never reach the netlist (ruling
# 2026-10-11).
#
# The user: "Why would expressions in the outputs pane of ASE-L go to the
# netlist? They are computations made using the result of the simulation! They
# should not influence the input to the simulator."
#
# Spec     doc/claude/specs/ase_l.md R-OUT1..R-OUT6; calculator.md R609
# Code     src/ase.tcl ase::output_save_cards, ase::output_is_plain,
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
    check "OE3 a refusal is the Calculator's sentence, naming what is wrong -- including ngspice's infix syntax, which is not the Calculator's" \
        [list [val $res bad] [val $res infix]] \
        [list {Cannot evaluate: unknown token 'nosuch' (not an operator/function, number or raw variable).} \
              {Cannot evaluate: unknown token 'v(dcmid)*2' (not an operator/function, number or raw variable).}]
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
        check "OE7 the expression's signal v(mid) is in the file although only v(out) and i(v1) were ticked -- the save list narrowed the deck and carried it" \
            [lsort [calc::raw_analyses $raw]] {op tran}
        catch {xschem raw clear}
        xschem raw read $raw op
        set have [split [string trim [xschem raw list]] "\n"]
        catch {xschem raw clear}
        check "OE7 ...its operating point holds exactly the three saved vectors" \
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
