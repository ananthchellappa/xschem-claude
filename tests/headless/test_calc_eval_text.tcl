# tests/headless/test_calc_eval_text.tcl -- the PURE evaluator,
# `calc::eval_text` / `calc::eval_texts` (calculator.md R609).
#
# The user, 2026-10-11: "Why would expressions in the outputs pane of ASE-L go
# to the netlist?  They are computations made using the result of the
# simulation!"  So an ASE-L Outputs row is evaluated after the run, from the
# run's results file, through this door -- which needs no Calculator window, no
# buffer, no stack, no status line and no waveform viewer.
#
# Spec     doc/claude/specs/calculator.md R609; doc/claude/specs/ase_l.md R-OUT2
# Code     src/calculator.tcl, the block headed "THE PURE EVALUATOR"
# Fixture  tests/headless/data/calc_fixture.raw: one file, four plots (two
#          transient datasets, AC, operating point).
#
# ⚠ EVERY VALUE ROW IS DISCRIMINATING AND SAYS SO: `v(lp)` reads ~0.998 as tran,
# ~0.447 as AC and exactly 0 as op, and band ET1 carries the distinctness leg
# that measures that every run.
#
# REGISTERED IN `hcases`.  Nothing here needs a display.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_calc_eval_text

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[pcall_listable $r]" }
    return $r
}
proc pcall_listable {s} {
    if {![catch {llength $s}]} { return $s }
    set m [string map [list \{ ( \} ) \" '] $s]
    if {![catch {llength $m}]} { return $m }
    return [regsub -all {[^A-Za-z0-9 ._:,/()=+*<>?!-]} $s ?]
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
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

proc fld {d k} {
    if {[string match ERR:* $d]} { return $d }
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
# 'near' as a WORD: relative 1e-7 against a nonzero reference, absolute 1e-12
# against zero -- `raw value` answers through %.8g
proc near {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} { return "NAN:$a/$b" }
    set tol [expr {$b == 0 ? 1e-12 : abs($b) * 1e-7}]
    return [expr {abs($a - $b) <= $tol ? {near} : "FAR:$a/$b"}]
}
proc far {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} { return 0 }
    set tol [expr {$b == 0 ? 1e-12 : abs($b) * 1e-7}]
    return [expr {abs($a - $b) > $tol}]
}

set fixture {}
foreach cand [list tests/headless/data/calc_fixture.raw \
                   [file join [file dirname [info script]] data calc_fixture.raw]] {
    if {$fixture eq {} && [file exists $cand]} { set fixture [file normalize $cand] }
}
proc et_load {type} {
    catch {xschem raw clear}
    if {[catch {xschem raw read $::fixture $type} r]} { return "ERR:$r" }
    return $r
}
# The last sample of `$net` in analysis `$type`, read by the test itself.
proc et_ref {type {net v(lp)} {ds 0}} {
    if {[et_load $type] ne {1}} { return NOREF }
    set v [lindex [pcall xschem raw values $net $ds] end]
    catch {xschem raw clear}
    return $v
}
proc et_info {} { return [pcall xschem raw info] }

# =============================================================================
# ET0 -- THE DOOR EXISTS, and it is the one this suite drives
# =============================================================================
group ET0 {
    check "ET0 fixture: the committed raw was located" [expr {$::fixture ne {}}] 1
    check "ET0 calc::eval_text and calc::eval_texts take {text rawpath analysis ?dataset?} and {texts rawpath analysis ?dataset?} (info args), with dataset defaulting to 0 (info default)" \
        [list [pcall info args ::calc::eval_text] [pcall info args ::calc::eval_texts] \
              [expr {[info default ::calc::eval_text dataset d] ? $d : {NODEFAULT}}]] \
        {{text rawpath analysis dataset} {texts rawpath analysis dataset} 0}
    catch {xschem raw clear}
    check "ET0 fixture: the registry starts EMPTY, so the bands below measure a cold read" [et_info] {}
}

# =============================================================================
# ET1 -- VALUES: each qualifier reads its own analysis, from a cold registry
# =============================================================================
set REF {}
group ET1 {
    set rt [et_ref tran] ; set ra [et_ref ac] ; set ro [et_ref op]
    set ::REF [dict create tran $rt ac $ra op $ro]
    check "ET1 DISTINCTNESS, measured: v(lp)'s last point differs pairwise across tran, AC and op by more than the row tolerance -- so a value row that read the wrong analysis cannot pass" \
        [list [far $rt $ra] [far $ra $ro] [far $rt $ro]] {1 1 1}
    set f [pcall calc::eval_text vf(lp) $::fixture {}]
    set t [pcall calc::eval_text vt(lp) $::fixture {}]
    set o [pcall calc::eval_text vdc(lp) $::fixture {}]
    check "ET1 vf(lp) is a WAVE whose last point is the AC reference (0.4472136 magnitude), vt(lp) a WAVE ending at the transient reference (0.99830244), vdc(lp) a SCALAR equal to the operating point (0)" \
        [list [fld $f ok] [fld $f kind] [near [fld $f value] $ra] \
              [fld $t ok] [fld $t kind] [near [fld $t value] $rt] \
              [fld $o ok] [fld $o kind] [near [fld $o value] $ro]] \
        {1 wave near 1 wave near 1 scalar near}
    check "ET1 the literal values the brief named: 0.4472136, 0.99830244, 0" \
        [list [fld $f value] [fld $t value] [fld $o value]] {0.4472136 0.99830244 0}
    et_load ac
    set pa [pcall xschem raw points 0]
    et_load tran
    set ptr [pcall xschem raw points 0]
    check "ET1 a wave answer carries its point count, read off the file by the test (AC, then transient dataset 0), and a scalar carries 1" \
        [list [fld $f points] [fld $t points] [fld $o points]] [list $pa $ptr 1]
    catch {xschem raw clear}
    check "ET1 ...and the registry is still EMPTY after all three" [et_info] {}
}

# =============================================================================
# ET2 -- WHICH ANALYSIS an unqualified text reads
# =============================================================================
group ET2 {
    set p [pcall calc::eval_text v(lp) $::fixture {}]
    check "ET2 plain v(lp) with no analysis given reads the OPERATING POINT -- the scalar issue 1243 gave the Value column" \
        [list [fld $p kind] [near [fld $p value] [dict get $::REF op]]] {scalar near}
    set pt [pcall calc::eval_text v(lp) $::fixture tran]
    check "ET2 ...and with analysis tran given it reads the transient: a wave ending at the transient reference" \
        [list [fld $pt kind] [near [fld $pt value] [dict get $::REF tran]]] {wave near}
    set q [pcall calc::eval_text {vt(lp)} $::fixture ac]
    check "ET2 a qualifier OVERRIDES the analysis argument: vt(lp) asked with analysis ac still reads the transient" \
        [near [fld $q value] [dict get $::REF tran]] near
    et_load tran
    set ref [pcall calc::aq_arg_invoke cross [list rpn v(lp) level 0.5 nth 1 edge rising]]
    catch {xschem raw clear}
    set mc [pcall calc::eval_text {cross(v(lp), 0.5, 1, rising)} $::fixture {}]
    check "ET2 an unqualified MEASUREMENT reads the first non-operating-point analysis (here tran): the same number calc::cross gives on a transient registry the test loaded itself" \
        [list [fld $ref ok] [fld $mc ok] [fld $mc kind] [near [fld $mc value] [fld $ref value]]] \
        {1 1 scalar near}
    check "ET2 calc::et_default, the rule itself: plain -> op when present else first; measurement -> first non-op else op" \
        [list [pcall calc::et_default {tran ac op} 0] [pcall calc::et_default {tran ac} 0] \
              [pcall calc::et_default {op tran} 1] [pcall calc::et_default {op} 1]] \
        {op tran tran op}
}

# =============================================================================
# ET3 -- MEASUREMENTS, quoted forms, RPN
# =============================================================================
group ET3 {
    et_load tran
    set ref [pcall calc::aq_arg_invoke cross [list rpn v(lp) level 0.5 nth 1 edge falling]]
    catch {xschem raw clear}
    set q [pcall calc::eval_text {cross(vt("lp"), 0.5, 1, "falling")} $::fixture {}]
    check "ET3 Cadence-quoted cross(vt(\"lp\"), 0.5, 1, \"falling\") answers the reference falling crossing" \
        [list [fld $q ok] [fld $q kind] [near [fld $q value] [fld $ref value]]] {1 scalar near}
    set rising [pcall calc::eval_text {cross(vt(lp), 0.5, 1, rising)} $::fixture {}]
    check "ET3 DISTINCTNESS: the rising and falling crossings differ, so the edge argument really reached the verb" \
        [far [fld $rising value] [fld $q value]] 1
    set bw [pcall calc::eval_text {bandwidth(vf(lp), 3, magnitude, low, 0)} $::fixture {}]
    check "ET3 bandwidth(vf(lp), ...) -- an AC-only verb -- answers a finite frequency" \
        [list [fld $bw ok] [fld $bw kind] [calc::eval_finite [fld $bw value]]] {1 scalar 1}
    set rw [pcall calc::eval_text {riseTime(vt(sq), 0, 1, 10, 90, 0, 0)} $::fixture {}]
    set i0 [et_info]
    check "ET3 riseTime with nth 0 answers a WAVE (the per-edge series) and leaves no destination slot behind" \
        [list [fld $rw ok] [fld $rw kind] $i0] {1 wave {}}
    et_load op
    set mr [pcall xschem raw value v(lp) 0]
    catch {xschem raw clear}
    set r [pcall calc::eval_text {v(lp) 2 * 1 +} $::fixture op]
    check "ET3 plain RPN 'v(lp) 2 * 1 +' on the operating point is 2*v(lp)+1" \
        [list [fld $r kind] [near [fld $r value] [expr {2.0 * $mr + 1}]]] {scalar near}
    set g [pcall calc::eval_text {@m1[gm]} $::fixture {}]
    check "ET3 an ngspice device parameter vector @m1\[gm\] -- held by the operating point -- is a scalar" \
        [list [fld $g ok] [fld $g kind] [calc::eval_finite [fld $g value]] [far [fld $g value] 0]] {1 scalar 1 1}
}

# =============================================================================
# ET4 -- REFUSALS, each the sentence a user would read
# =============================================================================
group ET4 {
    set rows {}
    foreach t [list {} nosuch {vt(lp) vf(lp) +} {vs(lp)} {cross(vt(lp), 0.5)} {-i(v1)} {v("lp}] {
        set d [pcall calc::eval_text $t $::fixture {}]
        lappend rows [list [fld $d ok] [fld $d msg]]
    }
    check "ET4 empty, unknown name, two analyses, an analysis the run lacks, wrong arity, ngspice infix syntax and an unclosed quote are each REFUSED with a sentence" \
        $rows [list \
            {0 {Cannot evaluate: the expression is empty}} \
            {0 {Cannot evaluate: unknown token 'nosuch' (not an operator/function, number or raw variable).}} \
            {0 {Cannot evaluate: vt() and vf() read different analyses}} \
            {0 {Cannot evaluate: this result has no DC sweep analysis}} \
            {0 {cross takes 4 arguments.}} \
            {0 {Cannot evaluate: unknown token '-i(v1)' (not an operator/function, number or raw variable).}} \
            {0 {Cannot evaluate: a double quote is not closed.}}]
    check "ET4 a missing results file and an empty path are refused without touching the registry" \
        [list [fld [pcall calc::eval_text v(lp) /nonexistent/x.raw {}] msg] \
              [fld [pcall calc::eval_text v(lp) {} {}] msg] [et_info]] \
        {{Cannot evaluate: no results file} {Cannot evaluate: no results file} {}}
    check "ET4 an analysis argument the file lacks is refused naming it" \
        [fld [pcall calc::eval_text v(lp) $::fixture dc] msg] \
        {Cannot evaluate: this result has no DC sweep analysis}
}

# =============================================================================
# ET5 -- THE REGISTRY IS PUT BACK EXACTLY, from every starting shape
# =============================================================================
group ET5 {
    set bad {}
    set texts [list vf(lp) vt(lp) vdc(lp) v(lp) nosuch {cross(vt(lp), 0.5, 1, rising)} \
                    {riseTime(vt(sq), 0, 1, 10, 90, 0, 0)} {dutyCycle(vt(sq), 0.5, start, 0, 0)}]
    set shapes 0
    foreach start {empty tran ac op two} {
        catch {xschem raw clear}
        switch -exact -- $start {
            empty {}
            two { xschem raw read $::fixture op ; xschem raw read $::fixture ac }
            default { xschem raw read $::fixture $start }
        }
        set i0 [et_info]
        incr shapes
        foreach t $texts {
            pcall calc::eval_text $t $::fixture {}
            if {[et_info] ne $i0} { lappend bad "$start:$t" }
        }
    }
    check "ET5 from an empty registry, from each analysis current, and from two slots, every text -- values, waves, a wave-valued verb, a refusal -- leaves `xschem raw info` BYTE-IDENTICAL (shapes driven, then the leaks)" \
        [list $shapes $bad] {5 {}}
    et_load tran
    set i0 [et_info]
    xschem raw read $::fixture ac
    set i1 [et_info]
    check "ET5 fixture: the two-slot snapshot really differs from the one-slot one, so the comparison above can fail" \
        [expr {$i0 ne $i1}] 1
    catch {xschem raw clear}
}

# =============================================================================
# ET6 -- THE CURSOR IS NOT READ, and the dataset argument is
# =============================================================================
group ET6 {
    et_load tran
    set c5 [pcall xschem raw value v(lp) 5]
    catch {xschem raw clear}
    rename ::calc::eval_cursor_point ::et6_real_cursor
    proc ::calc::eval_cursor_point {} { return 5 }
    set e [pcall calc::eval_text vt(lp) $::fixture {}]
    et_load tran
    set r [pcall calc::eval_rpn v(lp) 0]
    catch {xschem raw clear}
    rename ::calc::eval_cursor_point {}
    rename ::et6_real_cursor ::calc::eval_cursor_point
    check "ET6 with a cursor published at point 5, the Calculator's Eval reads point 5 while eval_text reads the LAST point -- and the two numbers differ" \
        [list [near [fld $r value] $c5] [near [fld $e value] [dict get $::REF tran]] \
              [far $c5 [dict get $::REF tran]]] {near near 1}
    set d0 [pcall calc::eval_text v(div) $::fixture tran 0]
    set d1 [pcall calc::eval_text v(div) $::fixture tran 1]
    check "ET6 dataset 0 and dataset 1 of v(div) answer their own datasets' last points (5 and 2.5), which differ" \
        [list [near [fld $d0 value] [et_ref tran v(div) 0]] [near [fld $d1 value] [et_ref tran v(div) 1]] \
              [far [fld $d0 value] [fld $d1 value]]] {near near 1}
}

# =============================================================================
# ET7 -- THE BATCH is the singles, in order, with one read per analysis
# =============================================================================
group ET7 {
    set texts [list vdc(lp) vt(lp) nosuch vf(lp) {cross(vt(lp), 0.5, 1, rising)} v(lp)]
    set singles {}
    foreach t $texts { lappend singles [pcall calc::eval_text $t $::fixture {}] }
    set batch [pcall calc::eval_texts $texts $::fixture {}]
    check "ET7 calc::eval_texts answers exactly what calc::eval_text answers for each text, in order" \
        [expr {$batch eq $singles}] 1
    set reads 0
    rename ::xschem ::et7_xschem
    proc ::xschem {args} {
        if {[lrange $args 0 1] eq {raw read}} { incr ::reads }
        return [uplevel 1 [list ::et7_xschem {*}$args]]
    }
    set ::reads 0
    pcall calc::eval_texts $texts $::fixture {}
    rename ::xschem {}
    rename ::et7_xschem ::xschem
    check "ET7 ...with ONE `raw read` per analysis the texts need (op, tran, AC = 3) for six texts" \
        $::reads 3
}

# =============================================================================
# ET8 -- NO WINDOW, NO BUFFER, NO STACK, NO VIEWER
# =============================================================================
group ET8 {
    set fam [lsort [concat [info procs ::calc::et_*] ::calc::eval_text ::calc::eval_texts]]
    set hits {}
    foreach p $fam {
        set body {}
        foreach ln [split [info body $p] "\n"] {
            if {[regexp {^\s*#} $ln]} continue
            append body $ln "\n"
        }
        foreach w {calc::status calc::buf_ calc::stk_ wviewer:: .calc winfo require_result results_publish eval_cursor_point} {
            if {[string first $w $body] >= 0} { lappend hits "[namespace tail $p]:$w" }
        }
    }
    check "ET8 the evaluator's procs (derived: calc::et_* plus the two doors) name no status line, buffer, stack, viewer, Tk window, result gate or cursor reader -- count, then the hits" \
        [list [expr {[llength $fam] >= 8}] $hits] {1 {}}
}

# =============================================================================
# ET9 -- THE SIGNALS AN EXPRESSION READS (the save list's input)
# =============================================================================
group ET9 {
    check "ET9 calc::eval_text_signals: qualifiers rewritten to v(), quotes removed, operators/functions/numbers/scale dropped, duplicates once, both RPN arguments of a two-signal verb" \
        [list [pcall calc::eval_text_signals {cross(vt("lp"), 0.5, 1, rising)}] \
              [pcall calc::eval_text_signals {v(a) i(v1) * abs() 2 / time v(a) +}] \
              [pcall calc::eval_text_signals {delay(vt(a), 0.5, rising, 1, vt(b), 0.5, rising, 1)}] \
              [pcall calc::eval_text_signals {@m1[gm]}] \
              [pcall calc::eval_text_signals {}]] \
        [list v(lp) {v(a) i(v1)} {v(a) v(b)} [list {@m1[gm]}] {}]
}

# =============================================================================
# ET10 -- THE CALCULATOR'S EVAL SHARES THE CHECK (a pure refactor)
# =============================================================================
group ET10 {
    set m [calc::meas_split {cross(v(lp), 0.5)}]
    check "ET10 calc::meas_eval's arity sentence is calc::meas_prepare's, unchanged by the factoring" \
        [list [pcall calc::meas_eval $m [dict create ok 1 token X]] [fld [pcall calc::meas_prepare $m] msg]] \
        {{cross takes 4 arguments.} {cross takes 4 arguments.}}
    set m2 [calc::meas_split {cross(v(lp), x, 1, rising)}]
    check "ET10 ...and its malformed-field sentence too" \
        [expr {[pcall calc::meas_eval $m2 [dict create ok 1 token X]] eq [fld [pcall calc::meas_prepare $m2] msg]}] 1
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
