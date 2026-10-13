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
#   TO  the Value-header order: numbers, then blank/refusal, then waves, each
#       group in the user's own order; unsorted is the user's own order
#   TD  a Saves row never narrows the deck: the deck saves everything first
#   TN  the Measures door refuses a bare name the design's netlist knows as a
#       node (ase::output_known_nodes, from the cached netlist facts); with no
#       netlist in hand a bare name is admitted (text cannot tell a node from a
#       .meas/let result)
#   TM  no committed bench row is a bare analysis-qualified single signal
#       (R208d's migration put back as saves), derived over every state
#   TR  every row the revert put back holds the save tools/migrate's table
#       says, the table is internally consistent, and its `pre` column is
#       re-derived from git (1e987ffd^) where the history is present
# Bands (display arm -- self-skip with SKIPPED: under --nogui):
#   TW1 two tabs, Measures shown on open; each tree holds its own rows
#   TW2 the Value header sorts the VIEW and a second click restores it; the
#       heading says so; the state's order is untouched
#   TW3 delete and edit on a sorted view hit the right state row
#   TW4 the editor's doors refuse across tabs and normalise a bare node
#   TW5 a state load shows Measures again (Load State, the Load State
#       dialog's commit, Revert); a run's new values re-sort, keeping the
#       selection
#   TW6 the strip's delete acts on the SHOWN tab only; switching tabs drops
#       the hidden tree's selection
#   TW7 a refused text reaches the CIW as an error line; a bare node the
#       netlist knows is refused under Measures in the editor too
#   TW8 a row added by another door (Select On Design) shows its own tab
#
# REGISTERED IN BOTH LISTS: the TW bands need a display.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_outputs_tabs
#   tests/headless/run_suites.sh test_ase_outputs_tabs

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
# TN -- THE MEASURES DOOR KNOWS THE DESIGN'S NODES WHEN THE NETLIST DOES
# =============================================================================
group TN {
    check "TN Measures refuses a bare name the netlist knows as a node, naming Saves" \
        [list [lindex [ase::output_admit measures out {in out}] 0] \
              [string match *Saves* [lindex [ase::output_admit measures out {in out}] 1]] \
              [string match *out* [lindex [ase::output_admit measures out {in out}] 1]]] {refuse 1 1}
    check "TN ...in either case (ngspice folds node names)" \
        [lindex [ase::output_admit measures OUT {in out}] 0] refuse
    check "TN a bare name the netlist does NOT know (a .meas/let result: GBW) is admitted under Measures" \
        [ase::output_admit measures GBW {in out}] {ok GBW}
    check "TN with no netlist in hand a bare name is admitted (text alone cannot tell a node from a let)" \
        [ase::output_admit measures out {}] {ok out}
    check "TN a qualified fetch of a known node is still a measure" \
        [ase::output_admit measures vt(out) {in out}] {ok vt(out)}
    # ase::output_known_nodes reads the cached facts and never netlists
    rename ::ase::netlist_facts_cached ::tn_facts_real
    proc ::ase::netlist_facts_cached {state} { return $::tn_facts }
    set ::tn_facts [dict create nodes [dict create {} [dict create nodes {out 1 in 1} devs {} insts {}] \
                                         xsub [dict create nodes {deep 1} devs {} insts {}]] \
                        globals [dict create 0 1 vdd 1]]
    check "TN ase::output_known_nodes: the top level's nodes and the globals, not ground, not a subcircuit's own" \
        [lsort [pcall ase::output_known_nodes [ase::state_default]]] {in out vdd}
    set ::tn_facts {}
    check "TN ...and nothing when the netlist is cold" [pcall ase::output_known_nodes [ase::state_default]] {}
    rename ::ase::netlist_facts_cached {}
    rename ::tn_facts_real ::ase::netlist_facts_cached
}

# =============================================================================
# TO -- THE VALUE-HEADER ORDER (a VIEW order; pure)
# =============================================================================
group TO {
    set rows {{name a expr vt(a)} {expr v(s1)} {name n1 expr {vdc(x)}}
              {name r expr {vdc(z)/0}} {name w2 expr vt(b)} {name n2 expr {cross(vt(a),0.5,1,rising)}}
              {name blank expr vdc(q)} {expr i(s2)} {name n3 expr {vdc(y)}}}
    set res [dict create a wave n1 1.000000e+00 r {Cannot evaluate: division by zero} \
                 w2 wave n2 {2.0e-6 4.0e-6} n3 -3.000000e+00 v(s1) 2.0 i(s2) wave]
    check "TO unsorted: the Measures rows in the user's own order, Saves rows not among them (state indices)" \
        [ase::ui::measures_order $rows $res 0] {0 2 3 4 5 6 8}
    check "TO sorted: numbers first (a list of numbers is numbers), then refusals and blanks, then waves -- each group in the user's own order" \
        [ase::ui::measures_order $rows $res 1] {2 5 8 3 6 0 4}
    check "TO value_rank: number 0, blank or sentence 1, wave 2" \
        [lmap v {1.0 {-3e-6} {} {Cannot evaluate: x} wave {1 2 3} {1 x}} {ase::ui::value_rank $v}] \
        {0 0 1 1 2 0 1}
    check "TO with no results at all, sorted equals unsorted" \
        [ase::ui::measures_order $rows {} 1] [ase::ui::measures_order $rows {} 0]
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

# =============================================================================
# TM -- NO COMMITTED ROW IS A BARE QUALIFIED SINGLE SIGNAL
# =============================================================================
group TM {
    set corpus [test_corpus_files $repo *.state]
    test_corpus_note $corpus
    set files [dict get $corpus files]
    set nst 0 ; set nrows 0 ; set nsave 0 ; set bare {} ; set neg 0
    foreach f $files {
        if {[catch {set fh [open $f r]; set t [read $fh]; close $fh}]} continue
        set outs {}
        foreach ln [split $t "\n"] { if {[string match {outputs *} $ln]} { set outs [lindex $ln 1] } }
        incr nst
        foreach o $outs {
            if {![dict exists $o expr]} continue
            incr nrows
            set e [string trim [dict get $o expr]]
            if {[ase::output_tab $e] eq {saves}} { incr nsave }
            if {[regexp -nocase {^(vt|vf|vdc|vs|it|if|idc|is)\([^()]*\)$} $e]} {
                lappend bare "[file tail $f]: $e"
            }
            if {[regexp -nocase {^-(vt|vf|vdc|vs|it|if|idc|is)\([^()]*\)$} $e]} { incr neg }
        }
    }
    check "TM no committed Outputs row is a bare analysis-qualified single signal -- R208d's migration of those rows is put back as saves (rows)" \
        [lrange $bare 0 9] {}
    check "TM ...and the scan is not vacuous: states and rows were read, saves exist, and the signed qualified rows (a measure: a save has no sign) are still there (states > 0, saves > 0, signed > 0)" \
        [list [expr {$nst > 0}] [expr {$nsave > 0}] [expr {$neg > 0}]] {1 1 1}
}

# =============================================================================
# TR -- THE REVERT PUT BACK THE RIGHT TEXT (not only "no bare qualified row")
# =============================================================================
proc tr_fam {migrated} {
    regexp -nocase {^(vt|vf|vdc|vs|it|if|idc|is)\(([^()]*)\)$} $migrated -> q inner
    return "[string tolower [string index $q 0]]($inner)"
}
proc tr_outputs {text} {
    foreach ln [split $text "\n"] { if {[string match {outputs *} $ln]} { return [lindex $ln 1] } }
    return {}
}
group TR {
    set tf [file join $here data r208d_saves_revert.txt]
    set fh [open $tf r]; set t [read $fh]; close $fh
    set rows {}
    foreach ln [split $t "\n"] {
        if {[string trim $ln] eq {} || [string index $ln 0] eq {#}} continue
        lappend rows $ln
    }
    set cache [dict create]
    set wrong {} ; set incons {} ; set nfam 0 ; set npre 0
    foreach r $rows {
        lassign $r rel idx name pre migrated reverted
        if {![dict exists $cache $rel]} {
            set outs {}
            catch {set fh [open [file join $repo $rel] r]; set outs [tr_outputs [read $fh]]; close $fh}
            dict set cache $rel $outs
        }
        set o [lindex [dict get $cache $rel] $idx]
        set got [list [ase::state_get $o name] [ase::state_get $o expr]]
        if {$got ne [list $name $reverted]} { lappend wrong "$rel#$idx: $got != [list $name $reverted]" }
        if {[ase::output_is_save $pre]} {
            incr npre
            if {$reverted ne $pre} { lappend incons "$rel#$idx: pre $pre was a save, reverted $reverted" }
        } else {
            incr nfam
            if {$reverted ne [tr_fam $migrated]} { lappend incons "$rel#$idx: $migrated -> $reverted, family says [tr_fam $migrated]" }
        }
    }
    check "TR the table is not vacuous: rows put back to the author's own save and rows put back by family both exist (rows>1000, pre>0, family>0)" \
        [list [expr {[llength $rows] > 1000}] [expr {$npre > 0}] [expr {$nfam > 0}]] {1 1 1}
    check "TR every committed row the revert touched holds the table's {name save} (first mismatches)" \
        [list [llength $wrong] [lrange $wrong 0 4]] {0 {}}
    check "TR the table is consistent with its rule: the author's text when it was a save, else v()/i() by the qualifier's family" \
        [list [llength $incons] [lrange $incons 0 4]] {0 {}}
    # `pre` re-derived from git -- the history is the authority, the table its copy
    set havegit [expr {![catch {exec git -C $repo cat-file -e 1e987ffd^{commit}}]}]
    if {!$havegit} {
        puts "skip: TR pre-from-git (no git history for 1e987ffd^ in this checkout)"
    } else {
        set gcache [dict create] ; set gwrong {}
        foreach r $rows {
            lassign $r rel idx name pre
            if {![dict exists $gcache $rel]} {
                set outs {}
                catch {set outs [tr_outputs [exec git -C $repo show 1e987ffd^:$rel]]}
                dict set gcache $rel $outs
            }
            set po [lindex [dict get $gcache $rel] $idx]
            if {[list [ase::state_get $po name] [string trim [ase::state_get $po expr]]] ne [list $name $pre]} {
                lappend gwrong "$rel#$idx: git [list [ase::state_get $po name] [ase::state_get $po expr]] != [list $name $pre]"
            }
        }
        check "TR every table row's `pre` is the row's text at 1e987ffd^, read from git (first mismatches)" \
            [list [llength $gwrong] [lrange $gwrong 0 4]] {0 {}}
    }
}

# =============================================================================
# TW -- THE WINDOW (display arm)
# =============================================================================
proc tw_ids {tv} { return [$tv children {}] }
proc tw_exprs {key ids} {
    set rows [ase::state_get [ase::session_state $key] outputs]
    return [lmap i $ids {ase::state_get [lindex $rows $i] expr}]
}
if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "SKIPPED: TW1-TW8 window bands (no X)"
} else {
    set key {}
    group TW1 {
        set sp [file join $::scratch tw.state]
        set st [ase::state_default]
        dict set st design [dict create lib twlib cell twcell view schematic]
        dict set st rundir $::scratch
        dict set st outputs {{name w1 expr vt(a) save 0 plot 1} {expr v(s1) save 1 plot 1}
                             {name n1 expr vdc(x) save 0 plot 0} {name r expr {vdc(z)/0} save 0 plot 0}
                             {name n2 expr vdc(y) save 0 plot 0} {expr i(s2) save 1 plot 0}}
        ase::state_save $sp $st
        set key [ase::session_key twlib twcell tw_state]
        ase::session_open $key $sp
        set top [ase::ui::open $key twlib twcell tw_state]
        update
        set mtv $top.body.outs.tv
        set stv $top.body.saves.tv
        check "TW1 both trees exist; Measures is the shown tab on open" \
            [list [winfo exists $mtv] [winfo exists $stv] [ase::ui::outputs_tab $key] \
                  [winfo ismapped $mtv] [winfo ismapped $stv]] {1 1 measures 1 0}
        check "TW1 the Measures tree holds the measures, the Saves tree the saves, by state index" \
            [list [tw_ids $mtv] [tw_ids $stv]] {{0 2 3 4} {1 5}}
        check "TW1 the Saves tree shows no Value column" [$stv cget -columns] {name plot save saveopts}
        check "TW1 the Measures tree keeps its columns" [$mtv cget -columns] {name value plot save saveopts}
        $top.body.outs.tabs.s invoke
        update
        check "TW1 the Saves tab button shows the saves and hides the measures" \
            [list [ase::ui::outputs_tab $key] [winfo ismapped $stv] [winfo ismapped $mtv]] {saves 1 0}
        $top.body.outs.tabs.m invoke
        update
        check "TW1 ...and Measures brings them back" \
            [list [ase::ui::outputs_tab $key] [winfo ismapped $mtv] [winfo ismapped $stv]] {measures 1 0}
    }
    group TW2 {
        set top [ase::ui::window_for $key]
        set mtv $top.body.outs.tv
        ase::session_setattr $key results [dict create w1 wave n1 1.0 r {Cannot evaluate: division by zero} n2 2.0]
        ase::ui::populate $key
        set before [ase::state_get [ase::session_state $key] outputs]
        set h0 [$mtv heading value -text]
        uplevel #0 [$mtv heading value -command]
        update
        check "TW2 one click on Value: numbers first, then the refusal, then the wave (state indices)" \
            [tw_ids $mtv] {2 4 3 0}
        check "TW2 the heading says it is sorted, and differs from the plain heading" \
            [list [expr {[$mtv heading value -text] ne $h0}] [string match Value* [$mtv heading value -text]]] {1 1}
        check "TW2 the state's own order is untouched (a VIEW order)" \
            [ase::state_get [ase::session_state $key] outputs] $before
        check "TW2 the value cells moved with their rows" \
            [lmap i [tw_ids $mtv] {$mtv set $i value}] \
            [list [ase::format_value 1.0] [ase::format_value 2.0] {Cannot evaluate: division by zero} wave]
        uplevel #0 [$mtv heading value -command]
        update
        check "TW2 a second click restores the user's own order and the plain heading" \
            [list [tw_ids $mtv] [$mtv heading value -text]] [list {0 2 3 4} $h0]
    }
    group TW3 {
        set top [ase::ui::window_for $key]
        set mtv $top.body.outs.tv
        uplevel #0 [$mtv heading value -command]
        update
        # sorted view {2 4 3 0}: the SECOND row shown is state row 4 (n2)
        set shown [lindex [tw_ids $mtv] 1]
        $mtv selection set $shown
        ase::ui::delete_selection $key
        update
        set outs [ase::state_get [ase::session_state $key] outputs]
        check "TW3 delete on the sorted view removes the row the user selected (n2) and no other" \
            [lmap o $outs {ase::state_get $o expr}] {vt(a) v(s1) vdc(x) vdc(z)/0 i(s2)}
        check "TW3 ...and the view stays sorted" [tw_exprs $key [tw_ids $mtv]] {vdc(x) vdc(z)/0 vt(a)}
        set shown [lindex [tw_ids $mtv] 0]
        ase::ui::output_editor $key $shown
        update
        set w $top.edout
        check "TW3 edit on the sorted view opens the row the user picked (n1)" [$w.expr get] vdc(x)
        $w.expr delete 0 end
        $w.expr insert 0 vdc(xx)
        ase::ui::output_editor_ok $key
        update
        check "TW3 ...and OK writes that row" \
            [lmap o [ase::state_get [ase::session_state $key] outputs] {ase::state_get $o expr}] \
            {vt(a) v(s1) vdc(xx) vdc(z)/0 i(s2)}
        uplevel #0 [$mtv heading value -command]
        update
    }
    group TW4 {
        set top [ase::ui::window_for $key]
        set n0 [llength [ase::state_get [ase::session_state $key] outputs]]
        ase::ui::outputs_tab $key measures
        ase::ui::output_editor $key -1
        update
        set w $top.edout
        $w.expr insert 0 v(out)
        ase::ui::output_editor_ok $key
        update
        check "TW4 v(out) typed under Measures is refused: no row, the dialog stays open" \
            [list [llength [ase::state_get [ase::session_state $key] outputs]] [winfo exists $w]] [list $n0 1]
        ase::ui::output_editor_cancel $key
        ase::ui::outputs_tab $key saves
        ase::ui::output_editor $key -1
        update
        $w.expr insert 0 vt(out)
        ase::ui::output_editor_ok $key
        update
        check "TW4 vt(out) typed under Saves is refused the same way" \
            [list [llength [ase::state_get [ase::session_state $key] outputs]] [winfo exists $w]] [list $n0 1]
        $w.expr delete 0 end
        $w.expr insert 0 nodeq
        ase::ui::output_editor_ok $key
        update
        set outs [ase::state_get [ase::session_state $key] outputs]
        check "TW4 a bare node under Saves is admitted as v(<node>) and lands in the Saves tree" \
            [list [llength $outs] [ase::state_get [lindex $outs end] expr] \
                  [expr {[lsearch -exact [tw_ids $top.body.saves.tv] $n0] >= 0}] [winfo exists $w]] \
            [list [expr {$n0 + 1}] v(nodeq) 1 0]
        ase::ui::outputs_tab $key measures
        ase::ui::output_editor $key -1
        update
        $w.expr insert 0 {db(vf(out))}
        ase::ui::output_editor_ok $key
        update
        set outs [ase::state_get [ase::session_state $key] outputs]
        check "TW4 a wave expression under Measures is admitted and lands in the Measures tree" \
            [list [ase::state_get [lindex $outs end] expr] \
                  [expr {[lsearch -exact [tw_ids $top.body.outs.tv] [expr {$n0 + 1}]] >= 0}]] {db(vf(out)) 1}
        ase::ui::outputs_tab $key saves
        set tvs $top.body.saves.tv
        $tvs selection set [lindex [tw_ids $tvs] 0]
        set target [lindex [tw_ids $tvs] 0]
        ase::ui::edit_output_first $key
        update
        check "TW4 context Edit on the Saves tab edits the Saves selection" \
            [list [winfo exists $w] [$w.expr get]] \
            [list 1 [ase::state_get [lindex $outs $target] expr]]
        ase::ui::output_editor_cancel $key
    }
    group TW5 {
        set top [ase::ui::window_for $key]
        set mtv $top.body.outs.tv
        ase::session_save $key
        ase::ui::outputs_tab $key saves
        ase::ui::load_state $key
        update
        check "TW5 a state load shows Measures again" \
            [list [ase::ui::outputs_tab $key] [winfo ismapped $mtv]] {measures 1}
        ase::ui::outputs_tab $key saves
        update
        ase::ui::load_state_commit $key [ase::session_state $key]
        update
        check "TW5 ...the Load State dialog's commit (load_state_commit) too" \
            [list [ase::ui::outputs_tab $key] [winfo ismapped $mtv]] {measures 1}
        ase::ui::outputs_tab $key saves
        update
        ase::ui::revert_state $key
        update
        check "TW5 ...and Revert" \
            [list [ase::ui::outputs_tab $key] [winfo ismapped $mtv]] {measures 1}
        set outs [ase::state_get [ase::session_state $key] outputs]
        set mids [ase::ui::measures_order $outs {} 0]
        uplevel #0 [$mtv heading value -command]
        update
        set res [dict create]
        set k 0
        foreach i $mids {
            set o [lindex $outs $i]
            dict set res [ase::ui::output_result_key $o] [expr {$k % 2 ? {wave} : "[expr {$k + 1}].0"}]
            incr k
        }
        set picked [lindex [tw_ids $mtv] 0]
        $mtv selection set $picked
        ase::session_setattr $key results $res
        ase::ui::refresh_output_values $key
        update
        check "TW5 new values from a run re-sort a sorted view (refresh, not only populate)" \
            [tw_ids $mtv] [ase::ui::measures_order $outs $res 1]
        check "TW5 ...without dropping the user's selection" [$mtv selection] $picked
        uplevel #0 [$mtv heading value -command]
        update
    }
    group TW6 {
        set top [ase::ui::window_for $key]
        set mtv $top.body.outs.tv
        set stv $top.body.saves.tv
        ase::ui::outputs_tab $key measures
        update
        set before [ase::state_get [ase::session_state $key] outputs]
        $mtv selection set [lindex [tw_ids $mtv] 0]
        ase::ui::outputs_tab $key saves
        update
        check "TW6 switching to Saves drops the hidden Measures tree's selection" [$mtv selection] {}
        $mtv selection set [lindex [tw_ids $mtv] 0]
        $stv selection set {}
        ase::ui::delete_selection $key
        update
        check "TW6 the strip's delete with Saves shown and nothing selected there deletes NO row (not the hidden Measures one)" \
            [ase::state_get [ase::session_state $key] outputs] $before
        $stv selection set [lindex [tw_ids $stv] 0]
        set gone [lindex [tw_ids $stv] 0]
        ase::ui::delete_selection $key
        update
        set after [ase::state_get [ase::session_state $key] outputs]
        check "TW6 ...and with a Saves row selected it deletes that row" \
            [list [llength $after] [expr {[lindex $before $gone] ni $after}]] \
            [list [expr {[llength $before] - 1}] 1]
        ase::ui::outputs_tab $key measures
        update
        check "TW6 switching back to Measures drops the hidden Saves tree's selection" [$stv selection] {}
    }
    group TW7 {
        set top [ase::ui::window_for $key]
        set w $top.edout
        rename ::ase::echo ::tw7_echo_real
        set ::tw7_said {}
        proc ::ase::echo {msg {tag {}}} { lappend ::tw7_said [list $msg $tag] }
        set n0 [llength [ase::state_get [ase::session_state $key] outputs]]
        ase::ui::outputs_tab $key measures
        ase::ui::output_editor $key -1
        update
        $w.expr insert 0 v(out)
        ase::ui::output_editor_ok $key
        update
        check "TW7 the refusal reaches the CIW as an error line naming Saves" \
            [list [llength $::tw7_said] [string match *Saves* [lindex $::tw7_said end 0]] [lindex $::tw7_said end 1]] \
            {1 1 error}
        ase::ui::output_editor_cancel $key
        rename ::ase::output_known_nodes ::tw7_known_real
        proc ::ase::output_known_nodes {state} { return {nodeq7 in} }
        ase::ui::output_editor $key -1
        update
        $w.expr insert 0 nodeq7
        ase::ui::output_editor_ok $key
        update
        check "TW7 a bare node the netlist knows, typed under Measures, is refused in the editor (no row, dialog open)" \
            [list [llength [ase::state_get [ase::session_state $key] outputs]] [winfo exists $w] \
                  [string match *Saves* [lindex $::tw7_said end 0]]] [list $n0 1 1]
        ase::ui::output_editor_cancel $key
        rename ::ase::output_known_nodes {}
        rename ::tw7_known_real ::ase::output_known_nodes
        rename ::ase::echo {}
        rename ::tw7_echo_real ::ase::echo
    }
    group TW8 {
        set top [ase::ui::window_for $key]
        ase::ui::outputs_tab $key measures
        update
        set ::ase::ui::sod($key,flavor) {plot 1 save 1}
        set ::ase::ui::sod($key,count) 0
        ase::ui::sod_queue $key v(picked8)
        update
        set outs [ase::state_get [ase::session_state $key] outputs]
        check "TW8 a net picked on the design (Select On Design) shows the Saves tab, where its row is" \
            [list [ase::state_get [lindex $outs end] expr] [ase::ui::outputs_tab $key] \
                  [winfo ismapped $top.body.saves.tv]] {v(picked8) saves 1}
        catch {unset ::ase::ui::sod($key,flavor)}
        catch {unset ::ase::ui::sod($key,count)}
        ase::ui::outputs_tab $key measures
    }
    group TWclose {
        ase::ui::close $key
        update
    }
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
