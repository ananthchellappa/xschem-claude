# tests/headless/test_ase_outputs_tabs.tcl -- the ASE-L Outputs pane's two
# tabs, Measures and Saves (user rulings 2026-10-13).
#
# The user: "A 'save' will always be v("netname") - because 'save' of a net
# would apply to any analysis."  "vt(netname) is NOT a save! It's a fetch of
# the time-domain waveform."  "an expression, created by user, can be in the
# Measures tab. But, make it easy (click on the 'Value' header to push the
# 'waves' to the bottom - since user really only wants to SEE the values -
# real numbers)".
#
# Spec     doc/claude/specs/ase_l.md R-OUT7..R-OUT10
# Code     src/ase.tcl ase::output_tab, ase::output_admit,
#          ase::saves_narrowed, ase::saves_all_forced;
#          src/ase_window.tcl ase::ui::value_rank, ase::ui::measures_order,
#          ase::ui::outputs_tab, ase::ui::value_sort_toggle, ase::ui::populate,
#          ase::ui::refresh_output_values, ase::ui::output_editor_ok
#
# Bands (counted arm -- pure procs, no Tk):
#   TC  the classifier: a tab is a pure function of the row's text
#   TA  each tab's door: a save typed into Measures and a non-save typed into
#       Saves are refused with a sentence naming the other tab; a bare node
#       typed into Saves is admitted as v(<node>)
#   TD  a Saves row never narrows the deck: the deck saves everything first
#
# REGISTERED IN `hcases`: nothing here needs a display yet.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_outputs_tabs

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

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch ase_outputs_tabs]

# =============================================================================
# TC -- THE CLASSIFIER
# =============================================================================
group TC {
    set saves {v(out) V(OUT) i(v1) I(Vmda) v(a,b) {v("x")} { v(out) } i(vd1)}
    set meas  {vt(out) vf(out) vdc(out) vs(out) it(v1) if(v1) idc(v1) is(v1)
               -idc(v1) -i(v1) -v(out) {db(vf(out))} {vt(a)-vt(b)}
               {value(vt("net"),120u)} {cross(vt(lp), 0.5, 1, rising)}
               {vdc(Vcc)/idc(Vr)} out VBG @m1[gm] {@m.xm1.msky130_fd_pr__nfet_01v8[id]}
               ph(out) {v(in) v(out) -} {v(out)*2} {v(out) 2 *} 42 {}}
    set bad {}
    foreach e $saves { if {[pcall ase::output_tab $e] ne {saves}} { lappend bad [list $e [pcall ase::output_tab $e]] } }
    check "TC every plain v()/i() spelling -- either case, a difference pair, Cadence quotes, padded -- is a save (misfiled)" $bad {}
    set bad {}
    foreach e $meas { if {[pcall ase::output_tab $e] ne {measures}} { lappend bad [list $e [pcall ase::output_tab $e]] } }
    check "TC a qualified fetch, a signed signal, a bare name, a device quantity, a measurement call, an expression in either syntax and a number are measures (misfiled)" $bad {}
    check "TC the classifier is TEXT ONLY: the same text answers the same tab whatever the row's flags" \
        [list [ase::output_tab v(out)] [ase::output_tab v(out)]] {saves saves}
}

# =============================================================================
# TA -- EACH TAB'S DOOR
# =============================================================================
group TA {
    check "TA Measures admits a qualified fetch, a wave expression and a number-valued call verbatim" \
        [list [ase::output_admit measures vt(out)] [ase::output_admit measures {db(vf(out))}] \
              [ase::output_admit measures {value(vt("net"),120u)}]] \
        [list {ok vt(out)} {ok db(vf(out))} [list ok {value(vt("net"),120u)}]]
    lassign [ase::output_admit measures v(out)] verdict msg
    check "TA Measures refuses a save, and the sentence names the text and the Saves tab" \
        [list $verdict [string match *v(out)* $msg] [string match *Saves* $msg]] {refuse 1 1}
    lassign [ase::output_admit measures {I(Vd)}] verdict msg
    check "TA ...a current save too" [list $verdict [string match *Saves* $msg]] {refuse 1}
    check "TA Saves admits v(x), i(x) and v(a,b) verbatim" \
        [list [ase::output_admit saves v(out)] [ase::output_admit saves I(Vmda)] [ase::output_admit saves v(a,b)]] \
        {{ok v(out)} {ok I(Vmda)} {ok v(a,b)}}
    check "TA Saves admits a bare node as v(<node>) -- the save the user meant, in the form the tab holds" \
        [list [ase::output_admit saves out] [ase::output_admit saves x1.vbg]] {{ok v(out)} {ok v(x1.vbg)}}
    foreach e {vt(out) -i(v1) {db(vf(out))} @m1[gm] {v(out)*2}} {
        lassign [ase::output_admit saves $e] verdict msg
        check "TA Saves refuses [list $e], and the sentence names the Measures tab" \
            [list $verdict [string match *Measures* $msg] [expr {[string first $e $msg] >= 0}]] {refuse 1 1}
    }
    check "TA an admitted text always classifies into the tab that admitted it" \
        [list [ase::output_tab [lindex [ase::output_admit saves out] 1]] \
              [ase::output_tab [lindex [ase::output_admit measures vt(out)] 1]]] {saves measures}
}

# =============================================================================
# TD -- A SAVES ROW NEVER NARROWS THE DECK
# =============================================================================
set NL "* td\nv1 in 0 dc 1\nr1 in mid 1k\nr2 mid out 1k\nr3 out 0 1k\nc1 out 0 1n\n.end\n"
proc td_state {outs {sav 0}} {
    set s [ase::state_default]
    dict set s design [dict create lib td cell td view schematic]
    dict set s rundir $::scratch
    dict set s outputs $outs
    dict set s save_all_v $sav
    dict set s analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0}
                         {type tran enabled 1 stop 10u step 100n}}
    return $s
}
proc td_saves {deck} {
    set out {}
    foreach l [split $deck "\n"] {
        if {[string match -nocase {.save*} [string trim $l]]} { lappend out [string trim $l] }
    }
    return $out
}
group TD {
    set st [td_state {{expr v(out) save 1 plot 0} {name w expr {cross(vt(mid),0.5,1,rising)} save 0 plot 0}}]
    set deck [pcall [ase::backend_hook ngspice render_deck] $st $::NL]
    check "TD fixture: the deck rendered" [string match ERR:* $deck] 0
    check "TD a ticked save with Save All voltages OFF: the deck saves everything FIRST, then the save -- one plain .save line would otherwise keep only what is listed" \
        [lrange [td_saves $deck] 0 1] {{.save all} {.save v(out)}}
    check "TD ...exactly one save-everything line" [llength [lsearch -all -exact [td_saves $deck] {.save all}]] 1
    check "TD ase::saves_narrowed: no bench is narrowed any more" [ase::saves_narrowed $st] 0
    check "TD a device quantity's card rides behind the same leader" \
        [lrange [td_saves [pcall [ase::backend_hook ngspice render_deck] \
            [td_state {{expr @m1[gm] save 1 plot 0}}] $::NL]] 0 1] {{.save all} {.save @m1[gm]}}
    check "TD control: a bench with no ticked save gets no save line at all (ngspice keeps everything by default)" \
        [td_saves [pcall [ase::backend_hook ngspice render_deck] \
            [td_state {{expr v(out) save 0 plot 1} {expr vt(mid) save 0 plot 1}}] $::NL]] {}
    check "TD control: Save All voltages ON still gives exactly one leader" \
        [td_saves [pcall [ase::backend_hook ngspice render_deck] [td_state {{expr v(out) save 1}} 1] $::NL]] \
        {{.save all} {.save v(out)}}
}

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
