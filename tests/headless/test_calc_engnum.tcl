## test_calc_engnum.tcl -- a measurement argument typed in ENGINEERING notation
## (100u, 1.5m, 1meg) is accepted exactly as its scientific spelling is
## (calc_feedback_batch item 4).
##
## The user's words, verbatim (doc/claude/calc_feedback_batch/BATCH.md):
##   "For the settlingTime dialog, if I choose time for the initial and final
##    value, pressing OK on the dialog does nothing - if the time value is in
##    engineering notation - 100u for 100e-6. If I use scientific notation, then
##    it works. We need to support engineering notation as well!"
##
## WHERE THE FIX LIVES, AND WHY THAT IS EVERY DIALOG AT ONCE.  Every `real`
## field of every measurement verb is judged by ONE predicate,
## `calc::arg_field_bad`, reached from the argument dialog's OK
## (`calc::arg_trouble`) and from Eval on a composed call typed or edited in the
## buffer (`calc::meas_trouble`).  Before this change its `real` arm was
## `calc::eval_finite`, a plain-decimal pattern, so `100u` was refused in every
## one of them.  It now asks `calc::num_read`, which accepts the SPICE scale
## factors and answers the SAME double the scientific spelling gives (the
## suffix is rewritten as a power-of-ten exponent, never multiplied).  The
## user's own spelling is what lands in the buffer and in the provenance
## sentence; `calc::meas_numeric` hands the verb the scientific form just before
## it is invoked, so no verb learns a second number syntax.
##
## THE POPULATION IS DERIVED: band E1 walks `calc::catalogue` x
## `calc::fn_argspec` for every `real` field of every verb that opens a dialog,
## and band E6 checks the Calculator's alphabet against the ngspice adapter's own
## `si_suffixes` table so the two cannot drift.
##
## DECIDED HERE (owed rule calc_eng_capital_M): a bare uppercase `M` is REFUSED
## with a sentence naming `m` and `meg`.  ngspice reads `1M` as milli with no
## warning; a user who wrote it almost always meant mega.  `MEG`/`Meg` and every
## other uppercase factor are accepted.
##
## DECLARED LIMITS: only letters may follow a scale factor (`100us` is
## accepted, as ngspice accepts it; `5x`, `5%` and `1 u` are refused, where
## ngspice would ignore the tail); a leading `+` is refused, as it already is
## for a plain number.  The plain-RPN Eval path is untouched: `100u` inside an
## RPN expression is the engine's business, not this file's.
##
## Arms: band E runs on both; band D (the dialog's OK, the Eval press, and the
## refusal reaching the status line and the CIW) needs Tk and announces itself
## SKIPPED under --nogui.  Registered in BOTH hcases and dcases.

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} ) \" '] $r]" }
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
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }
proc atleast {n k} { if {[string is integer -strict $n] && $n >= $k} { return "atleast$k" } ; return "only:$n" }

source [file join [file dirname [info script]] scratch.tcl]

set fixture {}
foreach cand [list tests/headless/data/calc_fixture.raw \
                   [file join [file dirname [info script]] data calc_fixture.raw]] {
    if {$fixture eq {} && [file exists $cand]} { set fixture [file normalize $cand] }
}
proc load_tran {} {
    if {$::fixture eq {}} { return NOFIXTURE }
    catch {xschem raw clear}
    if {[catch {xschem raw read $::fixture tran} r]} { return "ERR:$r" }
    return ok
}

# The verbs that open a dialog, and their `real` fields, DERIVED.
proc real_pairs {} {
    set out {}
    foreach r [calc::catalogue] {
        set n [lindex $r 0]
        foreach f [calc::fn_argspec $n] {
            if {[lindex $f 2] eq {real}} { lappend out [list $n [lindex $f 0] [lindex $f 1]] }
        }
    }
    return $out
}

# spelling -> the scientific text the user would otherwise have typed
set EN {
    100u 100e-6   1.5m 1.5e-3   10n 10e-9    2k 2e3        1meg 1e6
    3MEG 3e6      2.5Meg 2.5e6  4G 4e9       5T 5e12       6f 6e-15
    7p 7e-12      8U 8e-6       1e-3u 1e-9   -2k -2e3      .5n .5e-9
    100us 100e-6  3a 3e-18      1.5mV 1.5e-3 2K 2e3        1e+02k 1e5
    1e-07u 1e-13
}
set PLAIN {0.5 -3 1e-4 .25 7 1.5e-3 100e-6}
set CAPM {1M 2Ms 2.5M}
set BAD {abc 1x {1 u} 5% 1e999k u nan Inf 1.2.3m +3u {1.5 m} 100x}

# --- band E1: every `real` field of every dialog accepts the spellings -------
group E1 {
    set pairs [real_pairs]
    set bad {}
    set n 0
    foreach p $pairs {
        lassign $p verb key label
        foreach {s sci} $::EN {
            incr n
            set m [pcall calc::arg_field_bad $label real $s]
            if {$m ne {}} { lappend bad "$verb/$key/$s" }
        }
    }
    check "E1a every `real` field of every verb that opens a dialog (derived from calc::catalogue x calc::fn_argspec) ACCEPTS every engineering spelling through calc::arg_field_bad, the one predicate the dialog's OK and Eval's composed-call path both use; the pair and probe counts ride along so an empty population cannot pass" \
        [list [lrange $bad 0 7] [llength $bad] [atleast [llength $pairs] 20] [atleast $n 400]] \
        [list {} 0 atleast20 atleast400]
    set verbs {}
    foreach p $pairs { if {[lsearch -exact $verbs [lindex $p 0]] < 0} { lappend verbs [lindex $p 0] } }
    check "E1b ...and the set of verbs that population covers includes settlingTime, the dialog the user reported, and at least ten others -- so the fix is the shared path's and not settlingTime's" \
        [list [expr {[lsearch -exact $verbs settlingTime] >= 0}] [atleast [llength $verbs] 11]] \
        {1 atleast11}
    set tbad {}
    foreach v $verbs {
        set vals {}
        foreach f [calc::fn_argspec $v] {
            set k [lindex $f 0]
            switch -exact -- [lindex $f 2] {
                real { lappend vals $k 100u }
                int  { lappend vals $k 0 }
                rpn  { lappend vals $k {v(lp)} }
                default { lappend vals $k [lindex [lindex $f 2] 1] }
            }
        }
        set t [pcall calc::meas_trouble $v $vals]
        if {$t ne {}} { lappend tbad "$v=$t" }
    }
    check "E1c Eval's validator for a call typed in the buffer (calc::meas_trouble) accepts 100u in every real field of every verb at once" \
        [list [lrange $tbad 0 3] [llength $tbad]] {{} 0}
}

# --- band E2: the value is the scientific spelling's value, bit for bit -----
group E2 {
    check "E2a calc::num_eng takes exactly {v} and calc::num_read exactly {v}" \
        [list [pcall info args ::calc::num_eng] [pcall info args ::calc::num_read]] {v v}
    set wrong {}
    foreach {s sci} $::EN {
        set g [pcall calc::num_eng $s]
        if {$g ne $sci} { lappend wrong "$s=>$g want=$sci" ; continue }
        if {![string is double -strict $g] || double($g) != double($sci)} { lappend wrong "$s=>notequal" }
    }
    check "E2b every engineering spelling is rewritten to EXACTLY the scientific text a user would have typed (suffix folded into the exponent, never multiplied, so 100u is the same double as 100e-6 and not 9.999999999999999e-5)" \
        $wrong {}
    set moved {}
    foreach s $::PLAIN {
        set g [pcall calc::num_eng $s]
        if {$g ne $s} { lappend moved "$s=>$g" }
    }
    check "E2c a plain number passes through BYTE-IDENTICAL, so no existing call changes" $moved {}
    check "E2d non-vacuity: 100u and 100e-6 are different TEXT and 100u is not what a multiply gives -- the identity above is a rewrite, measured" \
        [list [expr {{100u} ne {100e-6}}] [expr {100*1e-6 == 100e-6 ? {same} : {differ}}]] {1 differ}
    check "E2e mil is ngspice's 25.4e-6, the one factor that is not a power of ten" \
        [list [expr {abs(double([pcall calc::num_eng 1mil]) - 25.4e-6) < 1e-21}]] 1
}

# --- band E3: refusals are sentences, and the capital-M one is its own -------
group E3 {
    set L {Initial (value or time)}
    set wrong {}
    foreach s $::CAPM {
        set g [pcall calc::arg_field_bad $L real $s]
        set w [pcall calc::arg_msg capM $L $s]
        if {$w eq {} || $g ne $w} { lappend wrong "$s=$g" }
        if {[pcall calc::num_eng $s] ne {}} { lappend wrong "$s=ACCEPTED" }
    }
    check "E3a a bare uppercase M (ngspice's silent milli) is REFUSED with calc::arg_msg capM's own sentence, asserted by identity, never accepted as either milli or mega" \
        $wrong {}
    set wrong {}
    foreach s $::BAD {
        set g [pcall calc::arg_field_bad $L real $s]
        set w [pcall calc::arg_msg real $L $s]
        if {$g ne $w} { lappend wrong "$s=$g" }
    }
    check "E3b everything else that is not a number is refused with calc::arg_msg real's sentence, unchanged, naming the text typed" \
        $wrong {}
    set cm [pcall calc::arg_msg capM $L 1M]
    check "E3c non-vacuity: the capM sentence exists, names the field and the text, says m and meg, and is a DIFFERENT sentence from the plain refusal" \
        [list [expr {$cm ne {} && ![string match ERR:* $cm]}] \
              [string match "*$L*" $cm] [string match {*1M*} $cm] \
              [string match {*meg*} $cm] \
              [expr {$cm ne [pcall calc::arg_msg real $L 1M]}]] \
        {1 1 1 1 1}
}

# --- band E4: end to end through Eval's measurement layer, headless ----------
# `calc::meas_in_token` is the context loan, which needs a viewer token this arm
# does not have; it is replaced by a RECORDER that runs the verb in the current
# context (the raw is loaded right here) and records what reached the verb.
group E4 {
    check "E4 fixture: the tran fixture loads" [load_tran] ok
    rename ::calc::meas_in_token ::e4_keep_mit
    set ::E4REC {}
    proc ::calc::meas_in_token {tok name vals} {
        lappend ::E4REC $vals
        set d [calc::arg_invoke $name $vals]
        lappend ::E4REC [dict get $d value]
        return $d
    }
    set g [dict create ok 1 token E4]
    proc e4_run {txt} {
        set ::E4REC {}
        set m [pcall calc::meas_split $txt]
        set say [pcall calc::meas_eval $m [dict create ok 1 token E4] $txt]
        return [list say $say rec $::E4REC]
    }
    set eng [e4_run {settlingTime(v(lp), 1.5m, 10, 0, 0, 100u, time, time)}]
    set sci [e4_run {settlingTime(v(lp), 1.5e-3, 10, 0, 0, 1e-4, time, time)}]
    set ctl [e4_run {settlingTime(v(lp), 1.4e-3, 10, 0, 0, 1e-4, time, time)}]
    set ev [lindex [dict get $eng rec] 1]
    set sv [lindex [dict get $sci rec] 1]
    set cv [lindex [dict get $ctl rec] 1]
    check "E4a THE USER'S CASE: settlingTime with BOTH references given as TIMES in engineering notation evaluates, and to the very number the scientific spelling gives -- compared as doubles, with the answer itself a finite number" \
        [list [string is double -strict $ev] [expr {$ev ne {} && $ev eq $sv}]] {1 1}
    check "E4b non-vacuity: the answer DEPENDS on the time typed -- a final time of 1.4e-3 instead of 1.5e-3 gives a different number, so the identity above could not hold with the suffix misread" \
        [list [string is double -strict $cv] [expr {$cv ne $ev ? {differ} : {SAME}}]] {1 differ}
    set rv [lindex [dict get $eng rec] 0]
    if {[catch {dict size $rv}]} { set rv {} }
    foreach k {final initial initfrom rpn} { if {![dict exists $rv $k]} { dict set rv $k MISSING } }
    check "E4c the verb is handed the SCIENTIFIC text (calc::meas_numeric), so no verb learns a second syntax -- while the provenance sentence quotes what the USER typed (final=1.5m; the line is middle-elided to the status width, so the early field is the one asserted)" \
        [list [dict get $rv final] [dict get $rv initial] [dict get $rv initfrom] [dict get $rv rpn] \
              [string match {*final=1.5m,*} [dict get $eng say]] [string match {*1.5e-3*} [dict get $eng say]]] \
        {1.5e-3 100e-6 time v(lp) 1 0}
    set capm [e4_run {settlingTime(v(lp), 1.5M, 10, 0, 0, 100u, time, time)}]
    check "E4d 1.5M typed in the buffer is REFUSED at Eval with capM's own sentence inside the call's refusal, and the verb is NOT reached" \
        [list [dict get $capm rec] \
              [string match "*[pcall calc::arg_msg capM {Final (value or time)} 1.5M]*" [dict get $capm say]]] \
        {{} 1}
    rename ::calc::meas_in_token {}
    rename ::e4_keep_mit ::calc::meas_in_token
}

# --- band E5: which paths share the predicate, derived ------------------------
group E5 {
    set callers {}
    foreach p [lsort [info procs ::calc::*]] {
        if {[regexp {calc::arg_field_bad} [info body $p]]} { lappend callers [namespace tail $p] }
    }
    check "E5a the procs that judge a measurement argument, derived from the namespace: the dialog's validator and Eval's composed-call validator, and nothing else -- so a third entry door would redden this row instead of quietly keeping the old syntax" \
        $callers {arg_trouble meas_trouble}
    check "E5b ...and the dialog's OK reaches the dialog's validator, and Eval's measurement arm hands the verb the normalised values" \
        [list [regexp {calc::arg_trouble} [info body ::calc::arg_dialog_done]] \
              [regexp {calc::meas_numeric} [info body ::calc::meas_apply]]] {1 1}
}

# --- band E6: the alphabet is ngspice's ---------------------------------------
group E6 {
    set tbl {}
    catch {set tbl [::ase::backend::ngspice::si_suffixes]}
    if {$tbl eq {}} {
        puts "SKIPPED: E6 (the ngspice adapter's si_suffixes table is not loaded on this arm)"
    } else {
        set wrong {}
        dict for {suf mul} $tbl {
            foreach sp [list $suf [string toupper $suf]] {
                if {$sp eq {M}} continue
                set g [pcall calc::num_eng "1$sp"]
                if {![string is double -strict $g] || abs(double($g) - double($mul)) > 1e-15 * abs(double($mul))} {
                    lappend wrong "1$sp=$g"
                }
            }
        }
        check "E6 every scale factor in the ngspice adapter's own si_suffixes table, both cases (bar the refused bare M), is read by the Calculator as that table's multiplier, with the table size riding along" \
            [list $wrong [atleast [dict size $tbl] 11]] {{} atleast11}
    }
}

# --- band D: the dialog's OK and the Eval press, on the real window -----------
if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "SKIPPED: band D (no X: the dialog, the buffer and the status line are Tk-only)"
} else {
    group D {
        if {![winfo exists .ciw.l.t]} { catch {ciw_create} }
        check "D0 fixture: the Calculator opens and the tran fixture loads" \
            [list [pcall calc::open] [load_tran]] {.calc ok}
        update
        rename ::calc::require_result ::d_keep_rr
        proc ::calc::require_result {} { return [dict create ok 1 origin stub path x type tran idx 0 token D msg {}] }
        rename ::calc::meas_in_token ::d_keep_mit
        set ::DREC {}
        # R208d (2026-10-12): Eval refuses an unqualified v(), so the composed
        # call carries R208c's `vt()` and the recorder takes the analysis the
        # press passes, running the verb through its guarded door.
        proc ::calc::meas_in_token {tok name vals {an {}}} {
            lappend ::DREC $vals
            return [calc::aq_arg_invoke $name $vals]
        }
        proc d_fill {initial final} {
            array unset ::calc::argval
            set ::calc::argfor settlingTime
            array set ::calc::argval [list initial $initial initfrom time final $final \
                finalfrom time tol 10 start 0 dataset 0]
        }
        # the dialog's OK, accepting
        d_fill 100u 1.5m
        set ok [pcall calc::arg_dialog_done .calc.arg ok]
        set res $::calc::arg_result
        check "D1 the settlingTime dialog's OK ACCEPTS 100u and 1.5m as times: no refusal, and the answer carries what the user typed" \
            [list $ok $::calc::argmsg [dict get $res initial] [dict get $res final]] \
            {{} {} 100u 1.5m}
        set vals [pcall calc::arg_values settlingTime {vt(lp)} $res]
        set txt [pcall calc::meas_compose settlingTime $vals]
        pcall calc::buf_set_expr $txt
        pcall calc::stk_clear
        set ::DREC {}
        set said [pcall calc::eval_click]
        update
        set buf [string trim [.calc.buf get 1.0 end]]
        set want [dict get [calc::settlingTime {v(lp)} 1.5e-3 10 0 0 1e-4 time time] value]
        check "D2 ...and Eval on the composed call replaces the buffer with the SAME number the scientific spelling measures, pushes the user's text, and says so on the status line" \
            [list $txt [expr {$buf eq $want}] [lindex [calc::stk_get] 0] \
                  [expr {[lindex [calc::status_history] 0] eq $said && $said ne {}}]] \
            [list {settlingTime(vt(lp), 1.5m, 10, 0, 0, 100u, time, time)} 1 \
                  {settlingTime(vt(lp), 1.5m, 10, 0, 0, 100u, time, time)} 1]
        # the dialog's OK, refusing a bare M -- never silently
        d_fill 100u 1.5M
        set ::calc::statushist {}
        set ref [pcall calc::arg_dialog_done .calc.arg ok]
        set want [pcall calc::arg_msg capM {Final (value or time)} 1.5M]
        set last [calc::ciw_last]
        check "D3 the dialog's OK on 1.5M REFUSES with capM's sentence, in the dialog's own slot, on the Calculator's status line AND through the CIW tee" \
            [list [expr {$ref eq $want && $want ne {}}] [expr {$::calc::argmsg eq $want}] \
                  [expr {[lindex [calc::status_history] 0] eq $want}] \
                  [expr {[dict get $last msg] eq $want}] \
                  [expr {[lsearch -exact [dict get $last sinks] ciw] >= 0}]] \
            {1 1 1 1 1}
        # Eval refusing a malformed value typed into the buffer
        pcall calc::buf_set_expr {settlingTime(vt(lp), 1.5m, 10, 0, 0, 100x, time, time)}
        set ::DREC {}
        set said [pcall calc::eval_click]
        update
        set last [calc::ciw_last]
        check "D4 Eval on a call carrying 100x REFUSES in a sentence on the status line and the CIW, the verb is not reached and the buffer is left alone" \
            [list $::DREC [string trim [.calc.buf get 1.0 end]] \
                  [expr {$said ne {} && [lindex [calc::status_history] 0] eq $said}] \
                  [expr {[dict get $last msg] eq $said}] [string match {*100x*} $said]] \
            [list {} {settlingTime(vt(lp), 1.5m, 10, 0, 0, 100x, time, time)} 1 1 1]
        rename ::calc::require_result {}
        rename ::d_keep_rr ::calc::require_result
        rename ::calc::meas_in_token {}
        rename ::d_keep_mit ::calc::meas_in_token
        catch {calc::close}
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
