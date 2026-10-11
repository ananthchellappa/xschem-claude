# tests/headless/test_calc_analysis_tokens.tcl -- R208c: `vt(net)`, `vf(net)`,
# `vdc(net)` and `vs(net)` read `v(net)` from ONE analysis of the CURRENT
# result's raw file, whatever analysis is current.
#
# The user, 2026-10-11: "A simulation could have both AC and TRAN simulations.
# The vt or vf need to intelligently pick FROM the loaded results."
#
# Spec     doc/claude/specs/calculator.md §5 and R208c
# Code     src/calculator.tcl, the R208c block above `calc::eval_in_token`
# Fixture  tests/headless/data/calc_fixture.raw: one file, four plots (two
#          transient datasets, AC, operating point).  A SINGLE-analysis file is
#          cut from it at run time (its first transient plot) so the absent
#          analysis refusal is driven on a real file with nothing else in it.
#
# Everything here runs in the CURRENT context, with no viewer: the procs under
# test are the bodies of the three loans (`calc::eval_in_ctx`,
# `calc::meas_in_ctx`, `calc::pick_lookup_in`) and the bracket they share
# (`calc::aq_run`).  The loans themselves, the Eval and Plot presses and the
# selector gesture are driven on the display arm by band PG15 of
# tests/headless/test_calc_pick.tcl.
#
# ⚠ EVERY VALUE ROW IS DISCRIMINATING BY CONSTRUCTION AND SAYS SO: `v(lp)` on
# the fixture is ~0.998 read as tran, ~0.447 read as AC and exactly 0 read as
# op, and band AT2 carries the distinctness leg that measures that every run.
#
# REGISTERED IN BOTH LISTS.  Every band but AT12 runs on the counted arm; AT12
# (the design window's Waves menu cue after an on-demand read and its clear) can
# only be seen with a display, and announces an uppercase SKIP without one.
#
# DECLARED LIMIT (AT12): `xschem raw clear` makes slot 0 current and now repaints
# the cue from it (src/save.c, extra_rawfile what == 3); `raw switch` and a
# dedupe `raw read` repaint nothing.  So when the user's slot is NOT slot 0 and
# slot 0 is bound to a different schematic, the cue after a bracket describes
# slot 0.  ASE-L never reaches that state (ase::attach_dbs keeps one slot); the
# row drives the one-slot shape ASE-L leaves.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_calc_analysis_tokens
#   tests/headless/run_suites.sh test_calc_analysis_tokens

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

# a dict field, with a sentinel rather than a raise
proc fld {d k} {
    if {[string match ERR:* $d]} { return $d }
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
# 'near' as a WORD, relative 1e-7 against a nonzero reference, absolute 1e-12
# against zero -- the engine's `raw value` answers through %.8g
proc near {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} { return "NAN:$a/$b" }
    set tol [expr {$b == 0 ? 1e-12 : abs($b) * 1e-7}]
    return [expr {abs($a - $b) <= $tol ? {near} : "FAR:$a/$b"}]
}

set fixture {}
foreach cand [list tests/headless/data/calc_fixture.raw \
                   [file join [file dirname [info script]] data calc_fixture.raw]] {
    if {$fixture eq {} && [file exists $cand]} { set fixture [file normalize $cand] }
}
set scratch [test_scratch calc_at]

# Start from exactly one slot, `$type`, current.
proc at_load {type} {
    if {$::fixture eq {}} { return NOFIXTURE }
    catch {xschem raw clear}
    if {[catch {xschem raw read $::fixture $type} r]} { return "ERR:$r" }
    return $r
}
# The last sample of `v(lp)` in analysis `$type`, read by the test itself on a
# registry of its own -- the reference the product's number is compared with.
proc at_ref {type {net v(lp)}} {
    if {[at_load $type] ne {1}} { return NOREF }
    return [lindex [pcall xschem raw values $net 0] end]
}
proc at_info {} { return [pcall xschem raw info] }

# THE SINGLE-ANALYSIS FILE: the fixture's first plot, cut at its own `Binary:`
# payload.  Its size is derived from the header's own counts, so a regenerated
# fixture re-derives it.
proc at_single {} {
    set out [file join $::scratch tran_only.raw]
    set f [open $::fixture r]
    fconfigure $f -translation binary
    set all [read $f]
    close $f
    set b [string first "Binary:\n" $all]
    if {$b < 0} { return NOBINARY }
    set hdr [string range $all 0 [expr {$b + 7}]]
    if {![regexp {No\. Variables:[ \t]*([0-9]+)} $hdr -> nv]} { return NONV }
    if {![regexp {No\. Points:[ \t]*([0-9]+)} $hdr -> np]} { return NONP }
    set end [expr {$b + 8 + $nv * $np * 8 - 1}]
    set o [open $out w]
    fconfigure $o -translation binary
    puts -nonewline $o [string range $all 0 $end]
    close $o
    return $out
}

# =============================================================================
# AT1 -- THE TOKEN: which ids, what it is rewritten to, and the mixed refusal
# =============================================================================
group AT1 {
    check "AT1 the four ids are the selectors' own table, read through calc::pick_analysis" \
        [list [pcall calc::pick_analysis vt] [pcall calc::pick_analysis vf] \
              [pcall calc::pick_analysis vdc] [pcall calc::pick_analysis vs]] \
        {tran ac op dc}
    check "AT1 calc::aq_ids finds every qualified token, bare or quoted, any case, in order -- and nothing inside a longer name or a leading-slash path" \
        [pcall calc::aq_ids {vf(lp) vT("sq") + VDC(x.y) xvt(a) vt("/lp") v(a) vs(b)}] \
        {vf vt vdc vs}
    check "AT1 calc::aq_strip rewrites each one to v(net), quotes removed, and leaves everything else byte-identical" \
        [pcall calc::aq_strip {vf(lp) vT("sq") + VDC(x.y[1]) xvt(a) vt("/lp") v(a)}] \
        {v(lp) v(sq) + v(x.y[1]) xvt(a) vt("/lp") v(a)}
    set plain [list {v(lp)} "v(lp)\n v(sq) -" {cross(v("lp"), 0.5, 1, "rising")} {i(@m1[id]) 2 *}]
    set moved {}
    foreach p $plain { if {[calc::aq_strip $p] ne $p} { lappend moved $p } }
    check "AT1 text with no qualified token comes back BYTE-IDENTICAL, whitespace and Cadence quotes included -- plain v() is untouched" \
        $moved {}
    check "AT1 calc::aq_plan: no qualifier -> empty type; one analysis, even repeated -> that type; two analyses -> refused with the sentence naming both ids" \
        [list [fld [pcall calc::aq_plan {v(lp)}] type] \
              [fld [pcall calc::aq_plan {vf(lp) vf(sq) +}] type] \
              [fld [pcall calc::aq_plan {vt(lp) vf(lp) +}] ok] \
              [fld [pcall calc::aq_plan {vt(lp) vf(lp) +}] msg]] \
        [list {} ac 0 {Cannot evaluate: vt() and vf() read different analyses}]
    check "AT1 calc::aq_qualify puts the selector id where the read-back's v is, and wraps a bare name whole" \
        [list [pcall calc::aq_qualify vf v(lp)] [pcall calc::aq_qualify vdc V(x1.n)] \
              [pcall calc::aq_qualify vt lp]] \
        {vf(lp) vdc(x1.n) vt(lp)}
}

# =============================================================================
# AT2 -- PRESENCE, from the file's own Plotname records
# =============================================================================
set single {}
group AT2 {
    check "AT2 fixture: the committed raw was located" [expr {$::fixture ne {}}] 1
    set ::single [at_single]
    check "AT2 calc::raw_analyses reads the committed fixture as tran, AC and op (no DC sweep), and the single-analysis cut as tran alone -- and a missing file as nothing" \
        [list [pcall calc::raw_analyses $::fixture] [pcall calc::raw_analyses $::single] \
              [pcall calc::raw_analyses [file join $::scratch nosuch.raw]]] \
        {{tran ac op} tran {}}
    catch {xschem raw clear}
    check "AT2 fixture: the single-analysis cut really reads as tran and really has no AC to read" \
        [list [pcall xschem raw read $::single tran] \
              [lindex [pcall xschem raw values v(lp) 0] end] \
              [pcall xschem raw read $::single ac]] \
        [list 1 [at_ref tran] 0]
    set rt [at_ref tran] ; set ra [at_ref ac] ; set ro [at_ref op]
    set ::REF [dict create tran $rt ac $ra op $ro]
    check "AT2 DISTINCTNESS, measured: v(lp) reads three different numbers in the three analyses, far apart relative to the 1e-7 the value rows use -- so a row that read the wrong analysis cannot pass" \
        [list [expr {abs($rt - $ra) > 0.1}] [expr {abs($ra - $ro) > 0.1}] [expr {abs($rt - $ro) > 0.1}]] \
        {1 1 1}
}

# =============================================================================
# AT3 -- PLAIN EVAL: the qualified token reads ITS analysis, from any current one
# =============================================================================
group AT3 {
    set wrong {}
    set same {}
    foreach start {tran ac op} {
        at_load $start
        set i0 [at_info]
        set c0 [calc::wave_dest_cur]
        foreach {tokn an} {vt(lp) tran vf(lp) ac vdc(lp) op {vf("lp")} ac} {
            set d [pcall calc::eval_in_ctx $tokn 0 [fld [calc::aq_plan $tokn] type]]
            set n [near [fld $d value] [dict get $::REF $an]]
            if {$n ne {near}} { lappend wrong "$start:$tokn:$n:[fld $d msg]" }
            if {[at_info] ne $i0 || [calc::wave_dest_cur] ne $c0} { lappend same "$start:$tokn" }
        }
    }
    check "AT3 from EACH current analysis (tran, AC, op), vt(lp), vf(lp), vdc(lp) and vf(\"lp\") answer the reference value of THEIR OWN analysis -- twelve evaluations" \
        $wrong {}
    check "AT3 ...and after every one of them 'raw info' and the current slot are byte-identical to what they were before: the on-demand slot was cleared and the user's slot restored" \
        $same {}
    at_load tran
    check "AT3 a plain v(lp) is unchanged: it reads the CURRENT analysis (tran here), exactly as before R208c" \
        [near [fld [pcall calc::eval_in_ctx {v(lp)} 0 {}] value] [dict get $::REF tran]] near
    check "AT3 and a plain v() inside a qualified expression is read in the qualifier's analysis -- one expression, one database: vf(lp) v(lp) - is 0 in AC" \
        [near [fld [pcall calc::eval_in_ctx {vf(lp) v(lp) -} 0 ac] value] 0] near
}

# =============================================================================
# AT4 -- A SLOT THE USER ALREADY HAD is used and KEPT, not cleared
# =============================================================================
group AT4 {
    at_load ac
    pcall xschem raw read $::fixture tran
    set i0 [at_info]
    set c0 [calc::wave_dest_cur]
    set d [pcall calc::eval_in_ctx {vf(lp)} 0 ac]
    check "AT4 fixture: two slots, tran current" \
        [list [regexp -all -line {^[0-9]+ /} $i0] [lindex $c0 1]] {2 tran}
    check "AT4 with the AC slot already registered, vf(lp) reads it and the registry -- BOTH slots, and tran current -- is byte-identical afterwards" \
        [list [near [fld $d value] [dict get $::REF ac]] [expr {[at_info] eq $i0}] \
              [expr {[calc::wave_dest_cur] eq $c0}]] \
        {near 1 1}
}

# =============================================================================
# AT5 -- REFUSALS: absent analysis, mixed, no data, and the guard
# =============================================================================
group AT5 {
    pcall xschem raw clear
    pcall xschem raw read $::single tran
    set i0 [at_info]
    set d [pcall calc::eval_in_ctx {vf(lp)} 0 ac]
    check "AT5 on a run that wrote no AC plot, vf(lp) is REFUSED naming the missing analysis, and nothing was read or left behind" \
        [list [fld $d ok] [fld $d msg] [expr {[at_info] eq $i0}]] \
        {0 {Cannot evaluate: this result has no AC analysis} 1}
    at_load tran
    check "AT5 ...and vs(lp) on the committed fixture (no DC sweep) likewise" \
        [fld [pcall calc::eval_in_ctx {vs(lp)} 0 dc] msg] \
        {Cannot evaluate: this result has no DC sweep analysis}
    pcall xschem raw clear
    check "AT5 with nothing loaded the plain no-data sentence answers, not an analysis one" \
        [fld [pcall calc::eval_in_ctx {vf(lp)} 0 ac] msg] [pcall calc::eval_msg nodata]
    at_load tran
    check "AT5 THE GUARD: calc::eval_rpn handed vf(lp) with a TRANSIENT database current refuses rather than reading the transient column -- so a door that forgets the bracket cannot serve the wrong analysis's number" \
        [list [fld [pcall calc::eval_rpn {vf(lp)}] ok] [fld [pcall calc::eval_rpn {vf(lp)}] msg]] \
        {0 {Cannot evaluate vf(): the loaded analysis is transient}}
    check "AT5 ...and the guard is not a blanket refusal: vt(lp) with tran current evaluates in place" \
        [near [fld [pcall calc::eval_rpn {vt(lp)}] value] [dict get $::REF tran]] near
    check "AT5 a mixed expression reaching eval_rpn directly is refused with the mixed sentence" \
        [fld [pcall calc::eval_rpn {vt(lp) vf(lp) +}] msg] \
        {Cannot evaluate: vt() and vf() read different analyses}
}

# =============================================================================
# AT6 -- A RAISE INSIDE THE BRACKET still restores the slot
# =============================================================================
group AT6 {
    at_load tran
    set i0 [at_info]
    set c0 [calc::wave_dest_cur]
    set ::AT6SEEN {}
    proc ::at6_boom {} { set ::AT6SEEN [calc::wave_dest_cur] ; error at6-boom }
    set r [pcall calc::aq_run ac ::at6_boom]
    check "AT6 a command that RAISES inside the AC slot comes back as rc 1 with its message, having run IN the AC slot, and the registry and the current slot are restored exactly" \
        [list [fld $r ok] [fld $r rc] [fld $r value] [lindex $::AT6SEEN 1] \
              [expr {[at_info] eq $i0}] [expr {[calc::wave_dest_cur] eq $c0}]] \
        {1 1 at6-boom ac 1 1}
    rename ::at6_boom {}
}

# =============================================================================
# AT7 -- MEASUREMENT VERBS read the qualifier's analysis
# =============================================================================
group AT7 {
    at_load tran
    set i0 [at_info]
    proc at_meas {txt} {
        set m [calc::meas_split $txt]
        set vals [calc::meas_vals [dict get $m verb] [dict get $m args]]
        set an [dict get [calc::aq_plan $txt] type]
        return [pcall calc::meas_in_ctx [dict get $m verb] \
                    [calc::meas_numeric [dict get $m verb] $vals] $an]
    }
    set bwf [at_meas {bandwidth(vf(lp), 3, magnitude, low, 0)}]
    set bwv [at_meas {bandwidth(v(lp), 3, magnitude, low, 0)}]
    check "AT7 bandwidth -- an AC-only verb -- on vf(lp) with a TRANSIENT current answers a finite frequency, while the same call on plain v(lp) is refused by the verb's own AC gate: the qualifier really put the AC database under the verb" \
        [list [fld $bwf ok] [string is double -strict [fld $bwf value]] \
              [fld $bwv ok] [string match {*needs an AC sweep*} [fld $bwv msg]]] \
        {1 1 0 1}
    set cf [at_meas {cross(vf("lp"), 0.5, 1, "falling")}]
    set ct [at_meas {cross(vt(lp), 0.5, 1, rising)}]
    check "AT7 cross on vf(\"lp\") answers a FREQUENCY and cross on vt(lp) a TIME, from one transient-current registry -- different by orders of magnitude, so neither could be the other analysis's answer" \
        [list [fld $cf ok] [fld $ct ok] [expr {[fld $cf value] > 100.0}] [expr {[fld $ct value] < 0.1}]] \
        {1 1 1 1}
    check "AT7 ...and the registry is byte-identical after all four calls" [expr {[at_info] eq $i0}] 1
    set g [pcall calc::aq_arg_invoke cross [list rpn vf(lp) level 0.5 nth 1 edge falling]]
    check "AT7 THE GUARD on the verb door: calc::aq_arg_invoke with vf(lp) and a TRANSIENT database current refuses, in the verbs' own answer shape" \
        [list [fld $g ok] [fld $g msg]] {0 {Cannot evaluate vf(): the loaded analysis is transient}}
}

# =============================================================================
# AT8 -- THE SELECTOR'S LOOKUP and PLOT
# =============================================================================
group AT8 {
    at_load tran
    set i0 [at_info]
    set lk [pcall calc::pick_lookup_in v(lp) ac]
    check "AT8 calc::pick_lookup_in resolves the candidate IN the AC database with a transient current, answers that database's own spelling, and leaves the registry as it found it" \
        [list [fld $lk ok] [fld $lk name] [expr {[at_info] eq $i0}]] {1 v(lp) 1}
    check "AT8 ...and a selector whose analysis the run lacks resolves nothing (noraw), rather than reading the current one" \
        [fld [pcall calc::pick_lookup_in v(lp) dc] why] noraw
    set p [pcall calc::plot_rpn __at_notoken__ {vf(lp)} replace]
    check "AT8 Plot of vf(lp) while the viewer's database is TRANSIENT is refused naming both -- never plotted from the transient column" \
        [list [fld $p ok] [fld $p msg]] \
        {0 {Cannot plot vf(): the waveform viewer shows transient}}
    at_load ac
    set pa [pcall calc::plot_rpn __at_notoken__ {vf(lp)} replace]
    at_load tran
    check "AT8 ...while with the AC database shown the same vf(lp) gets PAST that gate (this token has no viewer, so it fails later, for a reason that is not the analysis)" \
        [list [string match {Cannot plot vf()*} [fld $pa msg]] [string match {Cannot evaluate*} [fld $pa msg]] \
              [string match {Plot failed*} [fld $pa msg]]] \
        {0 0 1}
    check "AT8 ...and a mixed expression is refused by Plot with the mixed sentence" \
        [fld [pcall calc::plot_rpn __at_notoken__ {vt(lp) vf(lp) +} replace] msg] \
        {Cannot evaluate: vt() and vf() read different analyses}
}

# =============================================================================
# AT9 -- THE SENTENCES: every arm of calc::aq_msg, derived from its own switch
# =============================================================================
group AT9 {
    set arms {}
    foreach ln [split [info body ::calc::aq_msg] "\n"] {
        if {[regexp {^[ \t]*([a-zA-Z_][a-zA-Z0-9_]*)[ \t]+\{[ \t]*return} $ln -> k]} { lappend arms $k }
    }
    set bad {}
    foreach k $arms {
        set m [pcall calc::aq_msg $k vf tran]
        if {$m eq {} || [string match ERR:* $m] || [string length $m] > 80} { lappend bad "$k:$m" }
    }
    check "AT9 every arm of calc::aq_msg, derived from its own switch, answers a non-empty sentence of at most 80 characters without raising -- and there are at least six" \
        [list $bad [expr {[llength $arms] >= 6}]] {{} 1}
}

# THE MULTI-POINT OPERATING POINT FILE: the single-analysis cut followed by the
# fixture's own `Operating Point` plot with its point count doubled and its one
# point repeated.  read_dataset() stores such a plot as sim type `dc`, not `op`
# (save.c: "multi-point OP is equivalent to a DC sweep"), which is the shape
# that made `calc::aq_run` re-match its added slot by the WRONG type.
proc at_mop {} {
    set out [file join $::scratch mop.raw]
    if {$::single eq {} || ![file exists $::single]} { return NOSINGLE }
    set f [open $::fixture r]
    fconfigure $f -translation binary
    set all [read $f]
    close $f
    set p [string first "Plotname: Operating Point" $all]
    if {$p < 0} { return NOOP }
    set t [string last "Title:" $all $p]
    if {$t < 0} { return NOTITLE }
    set seg [string range $all $t end]
    set b [string first "Binary:\n" $seg]
    if {$b < 0} { return NOBINARY }
    set hdr [string range $seg 0 [expr {$b + 7}]]
    if {![regexp {No\. Variables:[ \t]*([0-9]+)} $hdr -> nv]} { return NONV }
    if {![regsub {No\. Points:[ \t]*1\n} $hdr "No. Points: 2\n" hdr2]} { return NOPOINTS }
    set pay [string range $seg [expr {$b + 8}] [expr {$b + 8 + $nv * 8 - 1}]]
    if {[string length $pay] != $nv * 8} { return SHORT }
    set g [open $::single r]
    fconfigure $g -translation binary
    set head [read $g]
    close $g
    set o [open $out w]
    fconfigure $o -translation binary
    puts -nonewline $o "$head$hdr2$pay$pay"
    close $o
    return $out
}

# =============================================================================
# AT10 -- A MULTI-POINT OPERATING POINT: the added slot is found by the registry
# DIFF, not re-matched by type, so it is entered, evaluated and cleared
# =============================================================================
group AT10 {
    set mop [at_mop]
    check "AT10 fixture: the multi-point-OP file was built, holds tran and op, and its op plot really is stored as sim type dc (the shape under test)" \
        [list [file exists $mop] [pcall calc::raw_analyses $mop] \
              [pcall xschem raw clear] [pcall xschem raw read $mop op] \
              [lindex [calc::wave_dest_cur] 1]] \
        {1 {tran op} 1 1 dc}
    set rop [lindex [pcall xschem raw values v(lp) 0] end]
    pcall xschem raw clear
    pcall xschem raw read $mop tran
    set rtr [lindex [pcall xschem raw values v(lp) 0] end]
    check "AT10 DISTINCTNESS, measured: v(lp) in that file's tran and op plots differ far beyond 1e-7" \
        [expr {[string is double -strict $rop] && [string is double -strict $rtr] && abs($rtr - $rop) > 0.1}] 1
    set i0 [at_info]
    set c0 [calc::wave_dest_cur]
    set bad {}
    set moved {}
    for {set k 1} {$k <= 3} {incr k} {
        set d [pcall calc::eval_in_ctx {vdc(lp)} 0 op]
        set n [near [fld $d value] $rop]
        if {$n ne {near}} { lappend bad "press$k:$n:[fld $d msg]" }
        if {[at_info] ne $i0 || [calc::wave_dest_cur] ne $c0} { lappend moved "press$k:[at_info]" }
    }
    check "AT10 three vdc(lp) presses with tran current each answer the op plot's value -- not a 'could not read' refusal" \
        $bad {}
    check "AT10 ...and after EVERY press 'raw info' and the current slot are byte-identical: no stray '<f> dc' slot accumulates" \
        $moved {}
    set lk [pcall calc::pick_lookup_in v(lp) op]
    check "AT10 the vdc selector's lookup in that file resolves v(lp) and leaves 'raw info' byte-identical" \
        [list [fld $lk ok] [fld $lk name] [expr {[at_info] eq $i0}]] {1 v(lp) 1}
    check "AT10 THE GUARD inside the bracket accepts the entered slot although it is stored as dc: vdc(lp) through calc::aq_run to calc::eval_rpn is not refused" \
        [near [fld [fld [pcall calc::aq_run op [list calc::eval_rpn {vdc(lp)} 0]] value] value] $rop] near
    check "AT10 ...and the bracket's own state is back to empty after it (a later bracket-less door is guarded again)" \
        [fld [pcall calc::eval_rpn {vdc(lp)}] msg] {Cannot evaluate vdc(): the loaded analysis is transient}
}

# =============================================================================
# AT11 -- THE FINAL-SLOT COMPARISON: a restore that does not land is a refusal
# =============================================================================
group AT11 {
    at_load ac
    pcall xschem raw read $::fixture tran
    set c0 [calc::wave_dest_cur]
    set i0 [at_info]
    rename ::calc::aq_restore ::calc::aq_restore__at11
    proc ::calc::aq_restore {name type bound} { return }
    set r [pcall calc::aq_run ac [list calc::eval_rpn {vf(lp)} 0]]
    rename ::calc::aq_restore {}
    rename ::calc::aq_restore__at11 ::calc::aq_restore
    set landed [calc::wave_dest_cur]
    check "AT11 fixture: the user's slot is tran at index 1 with AC at index 0, so a restore that does nothing really leaves AC current" \
        [list [lindex $c0 1] [lindex $landed 1]] {tran ac}
    check "AT11 with calc::aq_restore stubbed to a no-op, calc::aq_run REFUSES with the restore sentence naming the user's analysis -- it does not report the AC value as a success" \
        [list [fld $r ok] [fld $r msg]] \
        [list 0 [calc::aq_msg restore tran]]
    pcall xschem raw switch [lindex $c0 0] [lindex $c0 1]
    check "AT11 ...and the real restore is back in place: the same press now answers ok with the registry unchanged" \
        [list [fld [pcall calc::aq_run ac [list calc::eval_rpn {vf(lp)} 0]] ok] [expr {[at_info] eq $i0}]] \
        {1 1}
}

# =============================================================================
# AT12 -- THE WAVES MENU CUE (display arm): an on-demand read and its clear
# leave the design window's cue as the user's database says, not grey
# =============================================================================
group AT12 {
    if {[info commands winfo] eq {} || ![winfo exists .drw]} {
        puts "SKIP (no X): AT12 the Waves menu cue is painted only with a display"
    } else {
        set wp [xschem get current_win_path]
        proc at_cue {wp} {
            set v NOVAR
            catch {set v [set ::tctx::${wp}_waves]}
            set m NOMENU
            catch {set m [.menubar entrycget Waves -background]}
            return [list $v $m]
        }
        at_load tran
        set c0 [at_cue $wp]
        set l0 [pcall xschem raw loaded]
        check "AT12 fixture: with the transient database read the cue is Green on the variable and the menu, and it is loaded" \
            [list $c0 [expr {$l0 >= 0}]] {{Green Green} 1}
        set got {}
        foreach {tokn an} {vf(lp) ac vdc(lp) op vf(lp) ac} {
            pcall calc::eval_in_ctx $tokn 0 $an
            lappend got "$tokn:[at_cue $wp]:[pcall xschem raw loaded]"
        }
        check "AT12 after vf(lp), vdc(lp) and vf(lp) again -- each an on-demand read and clear -- the cue is still Green on both and the database still loaded" \
            $got [list "vf(lp):Green Green:$l0" "vdc(lp):Green Green:$l0" "vf(lp):Green Green:$l0"]
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
