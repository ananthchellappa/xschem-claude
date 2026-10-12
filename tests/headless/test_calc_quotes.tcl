## test_calc_quotes.tcl -- Cadence-style quoting in the Calculator: text pasted
## from Cadence works, so `cross(v("vbg"), 0.5, 1, "rising")` is the same call
## as `cross(v(vbg), 0.5, 1, rising)` (calc_feedback_batch, the user,
## 2026-10-10).
##
## MEASURED BEFORE THE CHANGE, on the committed tran fixture: the quoted enum
## was refused as `cross: Edge must be one of rising, falling, either.`, and a
## quoted net reached the verb verbatim and was refused as an unknown token
## `v("lp")` -- in plain Eval too.
##
## WHAT IS FENCED: one matching pair of double quotes comes off a word (enum)
## argument (`calc::word_unquote`, judged by `calc::arg_field_bad` and handed
## to the verb by `calc::meas_numeric`); a quoted name inside v(...)/i(...)
## becomes the bare one wherever the buffer's text is evaluated
## (`calc::rpn_unquote`, applied by `calc::meas_numeric` and `calc::eval_rpn`);
## a comma or paren inside quotes does not split or unbalance a call; an odd
## quote count is refused with a sentence through `calc::status`.  The buffer
## and the stack keep what the user typed (band D).
##
## DECLARED LIMIT, measured and pinned by row Q6: Cadence's leading-slash net
## paths (`v("/lp")`, `VT("/lp")`) are NOT translated and are refused naming
## the token.
##
## Arms: bands Q run on both; band D (the Eval press, the buffer, the stack,
## the status line and the CIW) needs Tk and announces itself SKIPPED under
## --nogui.  Registered in BOTH hcases and dcases.

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
# An answer dict without `dest` and `db`: every call mints its own names.
proc nodest {d} { catch {dict unset d dest} ; catch {dict unset d db} ; return $d }
proc dget {d k} { if {[catch {dict get $d $k} v]} { return MISSING } ; return $v }

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

# The kind of one formal of a verb: `rpn` for the buffer's own operand, else
# the spec's kind word.
proc fkind {verb key} {
    if {$key eq {rpn}} { return rpn }
    foreach f [calc::fn_argspec $verb] {
        if {[lindex $f 0] eq $key} { return [lindex [lindex $f 2] 0] }
    }
    return {}
}
proc fenum {verb key} {
    foreach f [calc::fn_argspec $verb] {
        if {[lindex $f 0] eq $key} { return [lrange [lindex $f 2] 1 end] }
    }
    return {}
}
# A call to <verb> in formal order.  `quoted` puts Cadence quotes round every
# word argument and every v(...) name; `net` and `net2` are the first and the
# second rpn operand; `alt` takes the SECOND word of every enum.
proc mkcall {verb quoted net net2 {alt 0}} {
    set a {}
    set nrpn 0
    foreach k [calc::meas_formals $verb] {
        set kind [fkind $verb $k]
        switch -exact -- $kind {
            rpn {
                set n [expr {$nrpn == 0 ? $net : $net2}]
                incr nrpn
                if {$quoted} { lappend a "v(\"$n\")" } else { lappend a "v($n)" }
            }
            enum {
                set w [lindex [fenum $verb $k] [expr {$alt ? 1 : 0}]]
                if {$quoted} { lappend a "\"$w\"" } else { lappend a $w }
            }
            int { lappend a [expr {$k eq {nth} || [string match nth* $k] ? 1 : 0}] }
            default {
                set v 0.5
                switch -glob -- $k {
                    hi - final { set v 0.9 }
                    lo - initial { set v 0.1 }
                    tol { set v 10 }
                    start { set v 0 }
                    pctlo { set v 10 }
                    pcthi { set v 90 }
                }
                lappend a $v
            }
        }
    }
    return "$verb\([join $a {, }]\)"
}

# --- band Q1: quoted and bare calls are the SAME call, every verb, derived ----
# `calc::meas_in_token` (the context loan) is replaced by a recorder that runs
# the verb in the current context and records what reached it.
group Q1 {
    check "Q1 fixture: the tran fixture loads" [load_tran] ok
    rename ::calc::meas_in_token ::q1_keep_mit
    proc ::calc::meas_in_token {tok name vals} {
        set d [calc::arg_invoke $name $vals]
        set ::Q1REC [list $vals $d]
        return $d
    }
    proc q1_run {txt} {
        set ::Q1REC {}
        set m [pcall calc::meas_split $txt]
        set say [pcall calc::meas_eval $m [dict create ok 1 token Q1] $txt]
        return [list say $say vals [lindex $::Q1REC 0] ans [lindex $::Q1REC 1]]
    }
    set verbs {}
    foreach r [calc::catalogue] {
        set n [lindex $r 0]
        if {![calc::meas_verb $n]} { continue }
        set has 0
        foreach k [calc::meas_formals $n] {
            if {[fkind $n $k] in {rpn enum}} { set has 1 }
        }
        if {$has} { lappend verbs $n }
    }
    set wrong {}
    set nok 0
    set ndiff 0
    set diffverbs {}
    foreach v $verbs {
        set b [q1_run [mkcall $v 0 lp sq]]
        set q [q1_run [mkcall $v 1 lp sq]]
        set c [q1_run [mkcall $v 0 sq lp]]
        if {[dget $b vals] eq {} || [dget $b vals] ne [dget $q vals]} {
            lappend wrong "$v:vals"
        }
        if {[nodest [dget $b ans]] ne [nodest [dget $q ans]]} {
            lappend wrong "$v:answer"
        }
        set bv [dget [dget $b ans] value]
        set qv [dget [dget $q ans] value]
        set cv [dget [dget $c ans] value]
        if {[dget [dget $b ans] ok] eq {1} && $bv ne {} && $bv eq $qv} { incr nok }
        if {[dget [dget $b ans] ok] eq {1} && [dget [dget $c ans] ok] eq {1} && $cv ne $bv} {
            incr ndiff
            lappend diffverbs $v
        }
    }
    check "Q1a every measurement verb carrying an rpn operand or a word argument (derived from calc::catalogue x calc::meas_formals): the call with every word and every v(...) name in Cadence quotes hands the verb EXACTLY the values the bare call hands it, and answers the same dict (bar the minted temporary and destination names); the population rides along" \
        [list $wrong [atleast [llength $verbs] 12]] {{} atleast12}
    check "Q1b ...and that identity is not between two refusals: at least five verbs answer a number on the tran fixture, bit-identical quoted and bare" \
        [atleast $nok 5] atleast5
    check "Q1c distinctness: swapping the operands (v(sq) for v(lp)) changes the answer of at least four of those verbs, cross among them -- so an identity that ignored the net could not pass Q1a/Q1b" \
        [list [atleast $ndiff 4] [expr {[lsearch -exact $diffverbs cross] >= 0}]] {atleast4 1}
    set r1 [q1_run {cross(v("lp"), 0.5, 1, "rising")}]
    set r2 [q1_run {cross(v(lp), 0.5, 1, rising)}]
    set r3 [q1_run {cross(v(lp), 0.5, 1, falling)}]
    set r4 [q1_run {cross(V("LP"), 0.5, 1, "rising")}]
    set v1 [dget [dget $r1 ans] value]
    check "Q1d THE USER'S CASE: cross(v(\"lp\"), 0.5, 1, \"rising\") answers a finite number bit-identical to cross(v(lp), 0.5, 1, rising) and to the upper-case V(\"LP\"); a falling edge answers a different one" \
        [list [string is double -strict $v1] [expr {$v1 eq [dget [dget $r2 ans] value]}] \
              [expr {$v1 eq [dget [dget $r4 ans] value]}] \
              [expr {$v1 ne [dget [dget $r3 ans] value] ? {differ} : {SAME}}]] \
        {1 1 1 differ}
    check "Q1e the provenance sentence quotes what the USER typed, quotes included" \
        [string match {*v("lp")*} [dget $r1 say]] 1
    rename ::calc::meas_in_token {}
    rename ::q1_keep_mit ::calc::meas_in_token
}

# --- band Q2: a word argument loses ONE matching pair of quotes ---------------
group Q2 {
    check "Q2a calc::word_unquote, calc::rpn_unquote and calc::quote_bad each take exactly one argument" \
        [list [pcall info args ::calc::word_unquote] [pcall info args ::calc::rpn_unquote] \
              [pcall info args ::calc::quote_bad]] {v rpn s}
    set got {}
    foreach w {{"rising"} rising {"rising} {rising"} {""rising""} {"ris"ing"} {""}} {
        lappend got [pcall calc::word_unquote $w]
    }
    check "Q2b one matching pair comes off; a lone, doubled or embedded quote leaves the word untouched" \
        $got [list rising rising {"rising} {rising"} {""rising""} {"ris"ing"} {}]
    set L Edge
    set K {enum rising falling either}
    set want [pcall calc::arg_msg enum $L {rising, falling, either}]
    set acc {}
    foreach w {{"rising"} rising {"either"} {  "falling"  }} {
        lappend acc [pcall calc::arg_field_bad $L $K $w]
    }
    set ref {}
    foreach w {{"rising} {rising"} {""rising""} {'rising'} {"Rising"}} {
        lappend ref [expr {[pcall calc::arg_field_bad $L $K $w] eq $want}]
    }
    check "Q2c calc::arg_field_bad -- the one predicate the dialog and Eval share -- accepts a quoted enum word and refuses every other quoting with the enum sentence, which exists" \
        [list $acc $ref [expr {$want ne {} && ![string match ERR:* $want]}]] \
        [list {{} {} {} {}} {1 1 1 1 1} 1]
}

# --- band Q3: quotes protect commas and parens --------------------------------
group Q3 {
    check "Q3a a comma inside quotes does not split an argument, inside a paren or at the top level" \
        [pcall calc::meas_args {v("a,b"), 0.5, 1, "x,y"}] [list {v("a,b")} 0.5 1 {"x,y"}]
    check "Q3b ...a paren inside quotes does not count toward the depth" \
        [list [pcall calc::meas_paren_bad {v("a)"), 1}] [pcall calc::meas_paren_bad {v("a"), 1)}]] {0 1}
    set m [pcall calc::meas_split {cross(v("a,b"), 0.5, 1, "rising")}]
    check "Q3c ...so the whole call splits into the verb's four arguments" \
        [list [dget $m verb] [llength [dget $m args]]] {cross 4}
    check "Q3d control: unquoted, the same comma DOES split" \
        [llength [pcall calc::meas_args {v(a), b, 0.5, 1, rising}]] 5
}

# --- band Q4: an odd quote count is a refusal with a sentence -----------------
group Q4 {
    set got {}
    foreach s {{v("lp")} {v(lp)} {v("lp)} {cross(v(lp), 0.5, 1, "rising)} {"} {""}} {
        lappend got [pcall calc::quote_bad $s]
    }
    check "Q4a calc::quote_bad answers 1 exactly for an odd number of double quotes" $got {0 0 1 1 1 0}
    set m [pcall calc::eval_msg quote]
    check "Q4b the refusal is a sentence of calc::eval_msg's own, terse and naming the quote" \
        [list [expr {$m ne {} && ![string match ERR:* $m]}] [string match -nocase {*quote*} $m] \
              [expr {[string length $m] <= 60}]] {1 1 1}
}

# --- band Q5: plain RPN Eval reads a quoted name too ---------------------------
group Q5 {
    check "Q5 fixture: the tran fixture loads" [load_tran] ok
    set pairs {
        {v("lp")}               {v(lp)}
        {V("LP")}               {V(LP)}
        {v("lp") v("sq") +}     {v(lp) v(sq) +}
        {i("@rtop[i]")}         {i(@rtop[i])}
        {v("sq") 2 *}           {v(sq) 2 *}
    }
    set wrong {}
    set vals {}
    foreach {q b} $pairs {
        set dq [pcall calc::eval_rpn $q]
        set db [pcall calc::eval_rpn $b]
        if {[dget $dq ok] ne {1} || [dget $db ok] ne {1}} { lappend wrong "$q:notok" ; continue }
        if {[dget $dq value] ne [dget $db value]} { lappend wrong "$q:[dget $dq value]/[dget $db value]" }
        lappend vals [dget $db value]
    }
    check "Q5a calc::eval_rpn (plain Eval) answers bit-identically for the quoted and the bare spelling of every pair" \
        $wrong {}
    check "Q5b distinctness: the five pairs' answers are not all one number" \
        [expr {[llength [lsort -unique $vals]] >= 3}] 1
    set plain {{v(lp)} {v(lp) v(sq) +} {  v(sq)  2 * } "v(lp)\nv(sq) -" {i(@m1[id]) 1e3 *} {vv("x")}}
    set moved {}
    foreach p $plain {
        if {[calc::rpn_unquote $p] ne $p} { lappend moved $p }
    }
    check "Q5c calc::rpn_unquote leaves text with no quoted v(...)/i(...) BYTE-IDENTICAL, whitespace and newlines included" \
        $moved {}
}

# --- band Q6: declared limit -- leading-slash paths are not translated --------
group Q6 {
    check "Q6 fixture: the tran fixture loads" [load_tran] ok
    set got {}
    foreach s {{v("/lp")} {VT("/lp")}} {
        set d [pcall calc::eval_rpn $s]
        lappend got [dget $d ok]
    }
    check "Q6 DECLARED LIMIT: Cadence's leading-slash paths v(\"/lp\") and VT(\"/lp\") are refused, not translated -- this row reds if a later change makes them work, so the limit is re-measured rather than remembered" \
        $got {0 0}
}

# --- band D: the Eval press, on the real window --------------------------------
if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "SKIPPED: band D (no X: the buffer, the stack and the status line are Tk-only)"
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
        # R208d (2026-10-12): Eval refuses an unqualified v(), so the band's texts
        # carry R208c's `vt()` and the recorders take the analysis the press
        # passes, running the verb through its guarded door (the fixture's
        # transient is current, so `vt()` reads in place).
        proc ::calc::meas_in_token {tok name vals {an {}}} {
            lappend ::DREC $vals
            return [calc::aq_arg_invoke $name $vals]
        }
        rename ::calc::eval_in_token ::d_keep_eit
        proc ::calc::eval_in_token {tok rpn {dataset 0} {an {}}} {
            lappend ::DREC $rpn
            return [calc::eval_rpn $rpn $dataset]
        }
        set typed {cross(vt("lp"), 0.5, 1, "rising")}
        pcall calc::buf_set_expr $typed
        pcall calc::stk_clear
        set ::DREC {}
        set said [pcall calc::eval_click]
        update
        set buf [string trim [.calc.buf get 1.0 end]]
        set want [dget [calc::cross {v(lp)} 0.5 1 rising] value]
        check "D1 Eval on the pasted Cadence call replaces the buffer with the number the bare call measures, pushes EXACTLY what was typed (quotes kept), and says so on the status line" \
            [list [expr {$buf eq $want && $want ne {}}] [lindex [calc::stk_get] 0] \
                  [expr {[lindex [calc::status_history] 0] eq $said && $said ne {}}]] \
            [list 1 $typed 1]
        set typed {vt("lp") vt("sq") +}
        pcall calc::buf_set_expr $typed
        set ::DREC {}
        set said [pcall calc::eval_click]
        update
        set want [dget [calc::eval_rpn {v(lp) v(sq) +}] value]
        check "D2 plain Eval on a quoted RPN expression answers the bare expression's number, and the buffer keeps what was typed" \
            [list [string match "*$want*" $said] [expr {$want ne {}}] [string trim [.calc.buf get 1.0 end]]] \
            [list 1 1 $typed]
        set qm [pcall calc::eval_msg quote]
        foreach typed {{cross(v("lp), 0.5, 1, rising)} {v("lp) 2 *}} tag {D3 D4} {
            pcall calc::buf_set_expr $typed
            set ::DREC {}
            set said [pcall calc::eval_click]
            update
            set last [calc::ciw_last]
            check "$tag an unclosed quote ($typed) is REFUSED with eval_msg quote's sentence on the status line AND through the CIW, nothing is evaluated, and the buffer is left alone" \
                [list [expr {$said eq $qm && $qm ne {}}] [expr {[lindex [calc::status_history] 0] eq $qm}] \
                      [expr {[dget $last msg] eq $qm}] [expr {[lsearch -exact [dget $last sinks] ciw] >= 0}] \
                      $::DREC [string trim [.calc.buf get 1.0 end]]] \
                [list 1 1 1 1 {} $typed]
        }
        rename ::calc::require_result {}
        rename ::d_keep_rr ::calc::require_result
        rename ::calc::meas_in_token {}
        rename ::d_keep_mit ::calc::meas_in_token
        rename ::calc::eval_in_token {}
        rename ::d_keep_eit ::calc::eval_in_token
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
