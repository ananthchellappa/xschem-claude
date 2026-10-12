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
# A copy of the committed raw keeping only the plots whose analysis type is in
# `$keep` (walked plot by plot: `Binary:` then nvars * npoints doubles, two per
# value when the plot is complex).
proc et_cut {out keep} {
    set fh [open $::fixture rb] ; set all [read $fh] ; close $fh
    set at 0
    set res {}
    while {[set p [string first "Plotname:" $all $at]] >= 0} {
        set b [string first "Binary:\n" $all $p]
        set hdr [string range $all $p $b]
        if {![regexp {No\. Variables:[ \t]*([0-9]+)} $hdr -> nv]} { return NOHDR }
        if {![regexp {No\. Points:[ \t]*([0-9]+)} $hdr -> np]} { return NOHDR }
        set w [expr {[string first complex $hdr] >= 0 ? 16 : 8}]
        set end [expr {$b + 8 + $nv * $np * $w - 1}]
        set n [string tolower $hdr]
        set ty {}
        foreach {k t} {{transient analysis} tran {ac analysis} ac {operating point} op} {
            if {[string first $k $n] >= 0} { set ty $t }
        }
        if {$ty in $keep} { append res [string range $all $at $end] }
        set at [expr {$end + 1}]
    }
    set fh [open $out wb] ; puts -nonewline $fh $res ; close $fh
    return ok
}

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
    check "ET2 an unqualified MEASUREMENT on a result holding TWO analyses besides the operating point (tran and AC) is REFUSED, naming both and the qualifiers that pick them -- never a silent pick (ADE-L parity, 2026-10-11: it used to answer an AC frequency on an op+AC+tran bench)" \
        [list [fld $mc ok] [fld $mc msg]] \
        {0 {Cannot evaluate: this result has TRAN and AC; write vt(...) or vf(...)}}
    set cut [file join [test_scratch et2] tran_op.raw]
    check "ET2 fixture: a cut of the committed raw holding the transient and the operating point, with no AC" \
        [list [et_cut $cut {tran op}] [calc::raw_analyses $cut]] {ok {tran op}}
    set mc1 [pcall calc::eval_text {cross(v(lp), 0.5, 1, rising)} $cut {}]
    check "ET2 ...with exactly ONE analysis besides the operating point, the same unqualified measurement reads it: the number calc::cross gives on a transient registry the test loaded itself" \
        [list [fld $ref ok] [fld $mc1 ok] [fld $mc1 kind] [near [fld $mc1 value] [fld $ref value]]] \
        {1 1 scalar near}
    set cut2 [file join [test_scratch et2] tran_ac.raw]
    check "ET2 fixture: a cut holding the transient and AC, with no operating point" \
        [list [et_cut $cut2 {tran ac}] [calc::raw_analyses $cut2]] {ok {tran ac}}
    set pl [pcall calc::eval_text {v(lp) 2 *} $cut2 {}]
    check "ET2 ...where an unqualified PLAIN expression is refused the same way (no operating point to default to, two analyses to guess between), while the operating-point default of a plain text stands where there is one (above)" \
        [list [fld $pl ok] [fld $pl msg]] \
        {0 {Cannot evaluate: this result has TRAN and AC; write vt(...) or vf(...)}}
    check "ET2 calc::et_default, the rule itself: plain -> op when present; otherwise the ONE non-op analysis, {} (refuse) when there are two or more" \
        [list [pcall calc::et_default {tran ac op} 0] [pcall calc::et_default {tran ac} 0] \
              [pcall calc::et_default {op tran} 1] [pcall calc::et_default {op} 1] \
              [pcall calc::et_default {tran ac op} 1] [pcall calc::et_default {tran} 0]] \
        {op {} tran op {} tran}
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
    check "ET4 empty, unknown name, two analyses, an analysis the run lacks, wrong arity, a negated current the result lacks (infix -- the sentence names the signal, not the text) and an unclosed quote are each REFUSED with a sentence" \
        $rows [list \
            {0 {Cannot evaluate: the expression is empty}} \
            {0 {Cannot evaluate: unknown token 'nosuch' (not an operator/function, number or raw variable).}} \
            {0 {Cannot evaluate: vt() and vf() read different analyses}} \
            {0 {Cannot evaluate: this result has no DC sweep analysis}} \
            {0 {cross takes 4 arguments.}} \
            {0 {Cannot evaluate: unknown token 'i(v1)' (not an operator/function, number or raw variable).}} \
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
              [pcall calc::eval_text_signals {v(a) i(v1) * abs() 2 / time + v(a) +}] \
              [pcall calc::eval_text_signals {delay(vt(a), 0.5, rising, 1, vt(b), 0.5, rising, 1)}] \
              [pcall calc::eval_text_signals {@m1[gm]}] \
              [pcall calc::eval_text_signals {}]] \
        [list v(lp) {v(a) i(v1)} {v(a) v(b)} [list {@m1[gm]}] {}]
    check "ET9 INFIX reads its operands as the save list needs them: the nine committed bench shapes, a nested measurement, and a measurement with an infix argument" \
        [lmap t {Vcc/I(Vr) (Vcc-Vss)/I(Vsil) db(i(vd)/i(vg)) {bandwidth(vf(out), 3, magnitude, low, 0)*2} {cross(vt(a)-vt(b), 0.5, 1, rising)}} \
             {pcall calc::eval_text_signals $t}] \
        {{Vcc I(Vr)} {Vcc Vss I(Vsil)} {i(vd) i(vg)} v(out) {v(a) v(b)}}
    check "ET9 a text refused before any read reads NOTHING, so it can make no save card: an RPN stack fault, an unknown function, a short measurement call, a trailing operator" \
        [lmap t {{v(a) v(b)} foo(v(a)) {cross(v(a), 0.5)} v(a)*} {pcall calc::eval_text_signals $t}] \
        {{} {} {} {}}
}

# =============================================================================
# ET11 -- A STALE SLOT FOR THE SAME FILE IS NEVER READ IN THE FILE'S PLACE
# =============================================================================
# `xschem raw read <f> <type>` SWITCHES to an existing slot keyed on the same
# path and type instead of reading the file (extra_rawfile() in src/save.c).
# OP annotation or the Calculator can leave such a slot behind; the user then
# re-runs, the file on disk changes, and an Outputs row must show the NEW run.
# So the slot pre-loaded here holds DIFFERENT content from the file on disk:
# the fixture's operating point with v(dcmid) = 3, then the file is overwritten
# by a copy whose v(dcmid) is patched to 5 at its own binary offset.
proc et11_patched {src dst net val} {
    set fh [open $src rb] ; set b [read $fh] ; close $fh
    set at [string last "Plotname: Operating Point" $b]
    set hdr [string range $b $at [expr {[string first "Binary:\n" $b $at] - 1}]]
    set nv {} ; set idx {}
    regexp {No\. Variables:[ \t]*([0-9]+)} $hdr -> nv
    regexp "\t(\[0-9\]+)\t[string map {( \\( ) \\)} $net]\t" $hdr -> idx
    if {$nv eq {} || $idx eq {}} { return "NOPATCH" }
    set off [expr {[string length $b] - 8 * $nv + 8 * $idx}]
    set b [string replace $b $off [expr {$off + 7}] [binary format d $val]]
    set fh [open $dst wb] ; puts -nonewline $fh $b ; close $fh
    return ok
}
group ET11 {
    set d [test_scratch et11]
    set p [file join $d run.raw]
    set q [file join $d new.raw]
    file copy -force $::fixture $p
    check "ET11 fixture: the new run's file was written with v(dcmid) patched" \
        [et11_patched $::fixture $q v(dcmid) 5.0] ok
    catch {xschem raw clear}
    xschem raw read $q op
    set new [lindex [pcall xschem raw values v(dcmid) 0] 0]
    catch {xschem raw clear}
    xschem raw read $p op
    set old [lindex [pcall xschem raw values v(dcmid) 0] 0]
    set i0 [et_info]
    file copy -force $q $p
    xschem raw read $p op
    set i2 [et_info]
    set sw [lindex [pcall xschem raw values v(dcmid) 0] 0]
    check "ET11 DISTINCTNESS, measured: the stale slot's v(dcmid) (3) and the file's (5) differ by more than the row tolerance, and re-reading the overwritten path SWITCHES to the stale slot (registry text unmoved, value still the old one) -- so the hazard is live" \
        [list [far $old $new] [expr {$i0 eq $i2}] [near $sw $old]] {1 1 near}
    set e [pcall calc::eval_text v(dcmid) $p {}]
    set b [pcall calc::eval_texts [list v(dcmid) {v(dcmid) 1 *}] $p op]
    set st [pcall xschem raw values v(dcmid) 0]
    check "ET11 with a stale slot for the same path and type loaded, eval_text and eval_texts read the FILE ON DISK (5), not the slot (3)" \
        [list [near [fld $e value] $new] [near [fld [lindex $b 0] value] $new] \
              [near [fld [lindex $b 1] value] $new]] {near near near}
    check "ET11 ...and the user's stale slot is left EXACTLY as it was: same registry text, still current, still holding its own 3" \
        [list [expr {[et_info] eq $i2}] [near [lindex $st 0] $old]] {1 near}
    check "ET11 ...and the private alias it read through is gone: no xschem_calc_et_<pid>_* left in calc::et_tmpdir" \
        [glob -nocomplain -directory [calc::et_tmpdir] xschem_calc_et_[pid]_*] {}
    catch {xschem raw clear}
    test_scratch_drop $d
}

# =============================================================================
# ET12 -- INFIX (calculator.md R610): ADE-L's algebra, translated to the
# engine's postfix, and RPN still RPN
# =============================================================================
proc et_v {t {an op}} { return [fld [pcall calc::eval_text $t $::fixture $an] value] }
proc et_m {t {an op}} { return [fld [pcall calc::eval_text $t $::fixture $an] msg] }
group ET12 {
    check "ET12 ROUTING, the ambiguous shapes (mode, postfix): a single token, postfix with spaces, infix with none, unary minus, infix WITH spaces, the committed '-1 *' idiom, a bare name with no operator character, and two values side by side" \
        [lmap t {v(lp) {v(lp) 2 *} v(lp)*2 -v(lp) {v(lp) - v(dcmid)} {v(lp) -1 *} a<3> {v(lp) v(dcmid)}} {
            set r [calc::ix_route $t] ; list [dict get $r mode] [dict get $r rpn]}] \
        {{infix v(lp)} {rpn {v(lp) 2 *}} {infix {v(lp) 2 *}} {infix {v(lp) -1 *}} {infix {v(lp) v(dcmid) -}} {rpn {v(lp) -1 *}} {rpn a<3>} {rpn {v(lp) v(dcmid)}}}
    et_load op
    set dc [lindex [pcall xschem raw values v(dcmid) 0] 0]
    set gm [lindex [pcall xschem raw values @m1\[gm\] 0] 0]
    set id [lindex [pcall xschem raw values i(@m1\[id\]) 0] 0]
    set ir [lindex [pcall xschem raw values i(@rdc1\[i\]) 0] 0]
    catch {xschem raw clear}
    check "ET12 fixture: the operating-point operands are nonzero and pairwise distinct (3, 1.339e-3, 8.7e-4, 1e-3), so no value row below can pass by reading another operand" \
        [list [far $dc $gm] [far $gm $id] [far $id $ir] [far $ir $dc] [far $ir 0] [far $id 0]] {1 1 1 1 1 1}
    set rows [list \
        {v(dcmid)/i(@rdc1[i])}        [expr {$dc / $ir}] \
        {(v(dcmid)-1)/2}              [expr {($dc - 1) / 2.0}] \
        {2*v(dcmid)^2}                [expr {2 * $dc ** 2}] \
        {-v(dcmid)^2}                 [expr {-($dc ** 2)}] \
        {2^3^2}                       512.0 \
        {v(dcmid)-1-1}                [expr {$dc - 2}] \
        {v(dcmid)/3/2}                [expr {$dc / 6.0}] \
        {2 * (v(dcmid) + 1)}          [expr {2 * ($dc + 1)}] \
        {db(i(@m1[id])/@m1[gm])}      [expr {20 * log10(abs($id / $gm))}] \
        {db20(-v(dcmid))}             [expr {20 * log10($dc)}] \
        {db(-v(dcmid))}               [expr {20 * log10($dc)}] \
        {-v(dcmid)+1}                 [expr {-$dc + 1}] \
        {db10(v(dcmid))}              [expr {10 * log10($dc)}] \
        {log(v(dcmid))}               [expr {log($dc)}] \
        {LN(v(dcmid))}                [expr {log($dc)}] \
        {log10(v(dcmid))}             [expr {log10($dc)}] \
        {pow(v(dcmid),2)}             [expr {$dc ** 2}] \
        {max(v(dcmid),5)}             5.0 \
        {min(v(dcmid),5)}             $dc \
        {abs(-v(dcmid))}              $dc \
        {mag(-v(dcmid))}              $dc \
        {sqrt(v(dcmid))}              [expr {sqrt($dc)}] \
        {DCMID*1k}                    [expr {$dc * 1000}] \
        {V(DCMID)+100u}               [expr {$dc + 100e-6}] \
        {-i(@m1[id])}                 [expr {-$id}] \
        {v(dcmid) > 2}                1.0 \
        {v(dcmid)+1 == 4}             1.0 \
        {pi()*2}                      [expr {2 * acos(-1)}]]
    set bad {}
    set n 0
    foreach {t want} $rows {
        incr n
        set got [et_v $t]
        if {[near $got $want] ne {near}} { lappend bad "$t=$got/$want" }
    }
    check "ET12 VALUES: every infix row (precedence, associativity, ^ over unary minus, functions, the six ADE/ngspice names db db20 db10 log mag pow, any case, bare names, engineering suffixes, comparisons) equals the value the TEST computes from the raw's own operands (rows driven, then the misses)" \
        [list $n $bad] {28 {}}
    check "ET12 DISCRIMINATION, measured: the wrong precedence or associativity gives a different number for the rows that pin them -- (2*3)^2, (-3)^2, (2^3)^2, 3-(1-1), 3/(3/2)" \
        [list [far [expr {(2 * $dc) ** 2}] [expr {2 * $dc ** 2}]] [far 9.0 -9.0] [far 64.0 512.0] \
              [far [expr {$dc}] [expr {$dc - 2}]] [far [expr {$dc / 1.5}] [expr {$dc / 6.0}]]] {1 1 1 1 1}
    check "ET12 the same RPN text still evaluates as RPN: 'v(dcmid) 2 *' and the committed '-1 *' idiom" \
        [list [near [et_v {v(dcmid) 2 *}] [expr {2 * $dc}]] [near [et_v {i(@m1[id]) -1 *}] [expr {-$id}]]] {near near}
    check "ET12 REFUSALS, each a sentence naming the fault: unknown function, wrong arity (two and zero), a trailing operator, a leading operator, an unclosed and an unopened parenthesis, a bare M, a malformed number, an empty argument" \
        [lmap t {foo(v(dcmid)) max(v(dcmid)) pi(2) v(dcmid)* *v(dcmid) (v(dcmid) v(dcmid)) 2M*v(dcmid) 2x*v(dcmid) max(v(dcmid),)} {et_m $t}] \
        [list "Cannot evaluate: unknown function 'foo'." \
              "Cannot evaluate: max takes 2 arguments." \
              "Cannot evaluate: pi takes no argument." \
              "Cannot evaluate: '*' has no value after it." \
              "Cannot evaluate: a value is missing before '*'." \
              "Cannot evaluate: a parenthesis is not closed." \
              "Cannot evaluate: ')' has no matching '('." \
              "Cannot evaluate: '2M': M is milli in SPICE; type m or meg." \
              "Cannot evaluate: '2x' is not a number." \
              "Cannot evaluate: a value is missing before ')'."]
    # ONE TOKEN IS NEVER TWO POSTFIX VALUES (verifier, 2026-10-11): each of these
    # was handed to the engine, which reads a digit-led token with atof and
    # answered 2, 2, 10000, 1, 0.002 and 1 -- a silent wrong number in a Value
    # cell.  Each is now a sentence; the fixture leg below measures that the
    # number each USED to give is not the right answer, so the refusal is not
    # replacing a correct value.
    set mal {2(v(dcmid)+1) 2(3) 10k(v(dcmid)) 1..2*v(dcmid) 2M 1.5.3 2(V(DCMID)-1)}
    check "ET12 MALFORMED ONE-TOKEN INFIX IS REFUSED, never routed to the postfix engine: a number against a '(' with no operator, a doubled decimal point, and a whole text '2M' (mode, then the sentence)" \
        [lmap t $mal {set r [calc::ix_route $t] ; list [dict get $r mode] [et_m $t]}] \
        [list [list refuse "Cannot evaluate: '(' follows a value with no operator between them."] \
              [list refuse "Cannot evaluate: '(' follows a value with no operator between them."] \
              [list refuse "Cannot evaluate: '(' follows a value with no operator between them."] \
              [list refuse "Cannot evaluate: '1..2' is not a number."] \
              [list refuse "Cannot evaluate: '2M': M is milli in SPICE; type m or meg."] \
              [list refuse "Cannot evaluate: '1.5.3' is not a number."] \
              [list refuse "Cannot evaluate: '(' follows a value with no operator between them."]]
    check "ET12 MALFORMED fixture: what the postfix engine made of those shapes (2, 10000, 2) is NOT what the user meant (2*(v+1), 10k*v), so the refusal replaces a wrong number, not a right one" \
        [list [far 2.0 [expr {2 * ($dc + 1)}]] [far 10000.0 [expr {10000 * $dc}]]] {1 1}
    check "ET12 the multi-token side-by-side shape is STILL handed to RPN (its own sentence follows), and a single bus-style raw name still reads as RPN" \
        [lmap t {{v(lp) v(dcmid)} a<3>} {dict get [calc::ix_route $t] mode}] {rpn rpn}
    # DECLARED LIMIT (calculator.md R610): a division by an operand that is zero
    # answers 0 -- the engine's deliberate DIVIS hold rule, issue 1628 -- not a
    # refusal and not inf.  Measured here so a change to it reddens this row
    # and the declaration is revisited; v(lp) is exactly 0 at the operating
    # point (band ET1's distinctness leg).
    check "ET12 DECLARED LIMIT, measured: v(dcmid)/v(lp) at the operating point, where v(lp) is exactly 0, answers 0 (engine DIVIS rule), and so does a literal 1/0" \
        [list [et_v v(lp)] [et_v {v(dcmid)/v(lp)}] [et_v {1/0}]] {0 0 0}
    set cr [et_v {cross(vt(lp), 0.5, 1, rising)} {}]
    set bw [et_v {bandwidth(vf(lp), 3, magnitude, low, 0)} {}]
    set n2 [pcall calc::eval_text {cross(vt(lp), 0.5, 1, rising)*2} $::fixture {}]
    check "ET12 NESTED: a measurement call as an operand is measured first and its number used -- cross(...)*2, -cross(...), bandwidth(...)/1k -- and the answer is a SCALAR though the transient has 101 points" \
        [list [calc::eval_finite $cr] [near [fld $n2 value] [expr {2 * $cr}]] [fld $n2 kind] \
              [near [et_v {-cross(vt(lp), 0.5, 1, rising)} {}] [expr {-$cr}]] \
              [near [et_v {bandwidth(vf(lp), 3, magnitude, low, 0)/1k} {}] [expr {$bw / 1000.0}]]] \
        {1 near scalar near near}
    check "ET12 NESTED with a signal: v(lp) minus its own crossing time is a WAVE on the transient (an operand still varies)" \
        [fld [pcall calc::eval_text {vt(lp)-cross(vt(lp), 0.5, 1, rising)} $::fixture {}] kind] wave
    set ar [et_v {cross(vt(lp)*2, 1, 1, rising)} {}]
    check "ET12 a measurement's expression argument may be infix: cross(vt(lp)*2, 1, ...) equals cross(vt(lp) 2 *, 1, ...) and, the same edge, cross(vt(lp), 0.5, ...)" \
        [list [calc::eval_finite $ar] [near $ar [et_v {cross(vt(lp) 2 *, 1, 1, rising)} {}]] [near $ar $cr]] \
        {1 near near}
    check "ET12 refused: a wave-valued measurement as an operand, a measurement inside a measurement's argument, and two analyses across a nested call" \
        [list [et_m {riseTime(vt(sq), 0, 1, 10, 90, 0, 0)*2} {}] \
              [et_m {cross(vt(lp)*cross(vt(lp), 0.5, 1, rising), 0.5, 1, rising)} {}] \
              [et_m {cross(vt(lp), 0.5, 1, rising)*vf(lp)} {}]] \
        [list "Cannot evaluate: riseTime gives a waveform here, so it cannot be part of an expression." \
              "Cannot evaluate: a measurement inside cross's argument is not supported." \
              "Cannot evaluate: vt() and vf() read different analyses"]
    check "ET12 a constant expression is a scalar on a many-point analysis too ('2 3 +' on the transient), and the registry is still EMPTY after the band" \
        [list [fld [pcall calc::eval_text {2 3 +} $::fixture tran] kind] [et_info]] {scalar {}}
}

# =============================================================================
# ET13 -- NO TEXT RAISES, AND FIVE PRINT-PATH PARITY SHAPES (fix round
# 2026-10-11, verifier at a21d2cd2)
# =============================================================================
# An Outputs row's text is read BEFORE the run, for the save list, so a raise
# out of the translator stopped the simulator for a row the user had not even
# ticked.  Two raises were measured: a leading-zero integer (`09`: Tcl reads it
# as octal and `double(09)` raises) and a deep nesting (Tcl's own "too many
# nested evaluations").  Each is now a value or a sentence, and `calc::et_check`
# turns anything else that raises into a refusal (the BACKSTOP row sabotages the
# lexer to prove it).
#
# DECLARED LIMIT (calculator.md R610): `ln(0)`, `log10(0)` and `db(0)` answer
# the engine's clamp (a large negative number), not -inf.  Row `DECLARED` below
# measures `ln(0)` so a change to it reddens and the declaration is revisited.
proc et_s {t} { return [pcall calc::eval_text_signals $t] }
group ET13 {
    set z {v(dcmid)*09 09*v(dcmid) -09 -v(dcmid)*08 {- 08} 010*v(dcmid) {0009.5*v(dcmid)}}
    set want [list [expr {9 * $dc}] [expr {9 * $dc}] -9.0 [expr {-8 * $dc}] -8.0 [expr {10 * $dc}] [expr {9.5 * $dc}]]
    check "ET13 LEADING ZEROS read as DECIMAL and never raise: v*09, 09*v, -09, -v*08, '- 08', 010*v (10, not octal 8), 0009.5*v" \
        [lmap t $z w $want {near [et_v $t] $w}] {near near near near near near near}
    check "ET13 LEADING ZEROS fixture: octal 010 (8) and decimal 010 (10) give different answers, so the 010 row discriminates" \
        [far [expr {8 * $dc}] [expr {10 * $dc}]] 1
    check "ET13 ...and the save list reads them without raising (the run is never blocked)" \
        [lmap t $z {et_s $t}] {v(dcmid) v(dcmid) {} v(dcmid) {} v(dcmid) v(dcmid)}
    check "ET13 calc::num_read drops redundant leading zeros (09 010 -08 007u 00 0.5), and calc::eval_finite reads them as decimal instead of raising (09 010 -08 0 0.5 all finite)" \
        [list [lmap v {09 010 -08 007u 00 0.5} {pcall calc::num_read $v}] \
              [lmap v {09 010 -08 0 0.5} {pcall calc::eval_finite $v}]] \
        {{{ok 9} {ok 10} {ok -8} {ok 7e-6} {ok 0} {ok 0.5}} {1 1 1 1 1}}
    set c2 [et_v {cross(vt(lp), 0.5, 2, rising)} {}]
    check "ET13 fixture: the first and second rising edges differ, so the nth legs below discriminate" [far $cr $c2] 1
    check "ET13 an INTEGER argument 010 is TEN, not octal 8, and 09 is nine: each answers exactly what its decimal spelling answers, and the 8th and 10th answers differ (so the 010 leg discriminates)" \
        [list [expr {[et_m {cross(vt(lp), 0.5, 8, rising)} {}] ne [et_m {cross(vt(lp), 0.5, 10, rising)} {}]}] \
              [expr {[et_m {cross(vt(lp), 0.5, 010, rising)} {}] eq [et_m {cross(vt(lp), 0.5, 10, rising)} {}]}] \
              [expr {[et_m {cross(vt(lp), 0.5, 09, rising)} {}] eq [et_m {cross(vt(lp), 0.5, 9, rising)} {}]}]] \
        {1 1 1}
    set deep [list [string repeat ( 400]v(dcmid)[string repeat ) 400] \
                   [string repeat - 3001]v(dcmid) \
                   [string repeat abs( 2000]v(dcmid)[string repeat ) 2000] \
                   2[string repeat ^2 3000]]
    set dsent "Cannot evaluate: the expression is nested more than [calc::ix_maxdepth] deep."
    check "ET13 DEEP NESTING is refused with a sentence, never raised: 400 parentheses, 3001 unary minuses, 2000 nested abs(), 3000 chained ^ (then the save list reads nothing from each)" \
        [list [lmap t $deep {et_m $t}] [lmap t $deep {et_s $t}]] \
        [list [lrepeat 4 $dsent] {{} {} {} {}}]
    check "ET13 ...and the cap is not near ordinary text: 50 parentheses still evaluate to v(dcmid)" \
        [near [et_v [string repeat ( 50]v(dcmid)[string repeat ) 50]] $dc] near
    set b [pcall calc::eval_texts [list [lindex $deep 0] v(dcmid)] $::fixture op]
    check "ET13 ...and a deep text in a batch costs only its own row: its sibling still has its value" \
        [list [fld [lindex $b 0] msg] [near [fld [lindex $b 1] value] $dc]] [list $dsent near]
    check "ET13 a 500-deep nest of measurement calls and of vt( is refused or read, never raised" \
        [lmap t [list [string repeat cross( 500] [string repeat vt( 500]] {
            list [string match ERR:* [pcall calc::eval_text $t $::fixture {}]] [string match ERR:* [et_s $t]]}] \
        {{0 0} {0 0}}
    # BACKSTOP: anything that raises below calc::et_check is a refusal naming it.
    rename ::calc::ix_lex ::calc::ix_lex_saved
    proc ::calc::ix_lex {s} { error "sabotage" }
    set bs [list [fld [pcall calc::eval_text v(dcmid)*2 $::fixture op] msg] [et_s v(dcmid)*2]]
    rename ::calc::ix_lex {}
    rename ::calc::ix_lex_saved ::calc::ix_lex
    check "ET13 BACKSTOP: with the lexer made to raise, eval_text REFUSES with a sentence naming the error and the save list reads nothing -- nothing raises" \
        $bs [list "Cannot evaluate: the expression could not be read (sabotage)" {}]
    check "ET13 BACKSTOP control: with the lexer restored, the same text evaluates" \
        [near [et_v v(dcmid)*2] [expr {2 * $dc}]] near
    check "ET13 PARITY: a space between a function or signal name and its parenthesis is read as the call -- sqrt (v), abs (v-7), v (dcmid)*2, cross (vt(lp),...)" \
        [list [near [et_v {sqrt (v(dcmid))}] [expr {sqrt($dc)}]] [near [et_v {abs (v(dcmid)-7)}] [expr {abs($dc - 7)}]] \
              [near [et_v {v (dcmid)*2}] [expr {2 * $dc}]] [near [et_v {cross (vt(lp), 0.5, 1, rising)} {}] $cr]] \
        {near near near near}
    check "ET13 PARITY: a measurement name in another case is refused naming the right spelling (SKILL is case-sensitive), not reported as an unknown function" \
        [et_m {Cross(vt(lp), 0.5, 1, rising)} {}] "Cannot evaluate: write 'cross', not 'Cross'."
    set tw [pcall calc::eval_text time $::fixture tran]
    check "ET13 PARITY: the sweep scale alone is a WAVE on the transient (101 points), not its last point as a scalar" \
        [list [fld $tw kind] [fld $tw points]] {wave 101}
    et_load op
    set bare [pcall xschem raw index @rdc1\[i\]]
    catch {xschem raw clear}
    check "ET13 PARITY fixture: the raw does NOT know the bare spelling of @rdc1's i parameter (index -1) -- it spells that current inside i(...) -- so the row below measures the resolution" \
        $bare -1
    check "ET13 PARITY: an ngspice device-current parameter typed bare, @rdc1 with its i parameter, times 2, reads the raw's i(...) spelling (as print did), and the save list carries the bare spelling ngspice's .save takes" \
        [list [near [et_v {@rdc1[i]*2}] [expr {2 * $ir}]] [et_s {@rdc1[i]*2}]] [list near [list {@rdc1[i]}]]
    check "ET13 DECLARED LIMIT, measured: ln(0) answers the engine's clamp -35, not -inf" \
        [et_v ln(0)] -35
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
