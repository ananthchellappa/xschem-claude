# tests/headless/test_ase_meas_in_measures_1768.tcl -- the simulator's
# measurements in the ASE-L Measures tab, and which kind of measure a row is
# (issue 1768).
#
# The user: "ensure that measurements set up in Outputs > Measurements, which
# generate numeric values, are visible in the Measures pane of ASE-L. What's
# the point of having these measures if the values are not visible to the
# user? There needs to be a way for the user to distinguish (when
# creating/editing) between a simulator (ngspice .meas) measure and a measure
# (output) that is based on a Calculator function."
#
# Spec     doc/claude/specs/ase_l.md R-OUT18
# Issue    doc/claude/issues/1768-*.md
# Code     src/ase.tcl ase::meas_row_canon, ase::meas_was_run, ase::meas_shown,
#          ase::meas_number_rows, ase::runstate_read, ase::result_runstate;
#          src/ase_window.tcl ase::ui::meas_item_index, ase::ui::meas_tab_value,
#          ase::ui::meas_tab_rows, ase::ui::measures_by, ase::ui::measures_items,
#          ase::ui::selection_split, ase::ui::rows_without,
#          ase::ui::edit_measures_item, ase::ui::populate,
#          ase::ui::refresh_output_values, ase::ui::delete_selection,
#          ase::ui::pane_click, ase::ui::measurements_dialog,
#          ase::ui::output_editor, ase::ui::meas_results_list
#
# Bands (counted arm -- no Tk):
#   MC  a measurement row as a comparable value
#   MR  did the run measure this row as it stands (the run-state snapshot)
#   MS  what a surface shows per row: a number only for a row the run measured
#   MN  which rows answer with one number (a plot or a working vector does not)
#   MV  one Value cell of the Measures tab, by verdict and by the run's state
#   MI  the item ids of the Measures tree and their order, plain and sorted
#   MD  a selection split over the two lists, and rows removed by index
#   MK  a session's measurements as the tab shows them: never ran, ran, edited
#       after the run, added after the run, a failed run, results older than
#       the deck, a run with no snapshot, a saved result in view
#   ML  the sentences that say which kind of measure a dialog makes
#   MX  the real simulator through a real launch (ase::run_deck): the numbers,
#       the simulator's silence, a measurement edited after the run, the next
#       run -- skipped with a lowercase skip: line when no ngspice is on PATH
# Bands (display arm -- self-skip with SKIPPED: under --nogui):
#   MW1 the Measures tree holds both kinds, in order, with Value and By
#   MW2 the Value header sorts both kinds together
#   MW3 a double click opens each row's own editor, on that row
#   MW4 a click on a measurement's Plot or Save cell flips nothing
#   MW5 the dialog's OK repaints the tab; an edited row loses its number in
#       both places until a run measures it
#   MW6 a finished run's refresh updates the measurements and keeps the
#       selection
#   MW7 Delete removes each selected row from its own list
#   MW8 both dialogs say which kind of measure they make; the Saves door does
#       not
#   MW9 the context menu's Edit opens a measurement in the Measurements dialog
#   MW10 a failure while the measurements are read costs only the measurement rows
#
# REGISTERED IN BOTH LISTS: the MW bands need a display.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_meas_in_measures_1768
#   tests/headless/run_suites.sh test_ase_meas_in_measures_1768

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
set scratch [test_scratch ase_meas_in_measures_1768]

proc wr {path text} {
    file mkdir [file dirname $path]
    set f [open $path w]
    puts -nonewline $f $text
    close $f
    return $path
}

# =============================================================================
# THE FIXTURE
# =============================================================================
set SIM ngspice
set AN [list {type ac enabled 1 sweep dec points 100 start 1 stop 1g} \
             {type tran enabled 1 step 2u stop 3m} \
             {type op enabled 1}]
set H_AC   [lindex [ase::analysis_handles [dict create analyses $AN]] 0]
set H_TRAN [lindex [ase::analysis_handles [dict create analyses $AN]] 1]

# index: 0 ugf, 1 pmph, 2 pm, 3 ph (a working vector), 4 sp (a plot),
#        5 tr, 6 off1 (switched off), 7 bad (reads an analysis that is not there)
set M_UGF  [list name ugf kind when target vdb(out) value 0 dir fall analysis ac id $H_AC]
set M_PMPH [list name pmph kind find target vp(out) when vdb(out) value 0 analysis ac id $H_AC]
set M_PM   [list name pm kind param expr {180 + pmph} analysis ac id $H_AC]
set M_PH   [list name ph kind cphase target v(out) analysis ac id $H_AC]
set M_SP   [list name sp kind fft target v(out) analysis tran id $H_TRAN]
set M_TR   [list name tr kind max target v(out) analysis tran id $H_TRAN]
set M_OFF  [list name off1 kind min target v(out) analysis tran id $H_TRAN enabled 0]
set M_BAD  [list name bad kind max target v(out) analysis dc id dc9]
set MEAS   [list $M_UGF $M_PMPH $M_PM $M_PH $M_SP $M_TR $M_OFF $M_BAD]
set SIDECAR "ASE-MEAS\nugf                 =  9.149274e+05\npmph                =  -1.238583e+02\npm = 5.614170e+01\n"

set OUTS {{name gain expr {db(vf(out))} save 0 plot 0} {expr v(out) save 1 plot 0}
          {name vo expr vdc(out) save 0 plot 0}}

proc fx_state {dir cell {meas -}} {
    set st [ase::state_default]
    dict set st design [dict create lib L1768 cell $cell view schematic]
    dict set st rundir $dir
    dict set st analyses $::AN
    dict set st outputs $::OUTS
    dict set st measurements [expr {$meas eq {-} ? $::MEAS : $meas}]
    return $st
}

## an ASCII raw: a transient and an operating point of one node
proc mkraw {path} {
    set b "Title: 1768 fixture\nDate: Thu Jan  1 00:00:00 2026\n"
    append b "Plotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 3\n"
    append b "Variables:\n\t0\ttime\ttime\n\t1\tv(out)\tvoltage\nValues:\n"
    for {set i 0} {$i < 3} {incr i} {
        append b "$i\t[expr {$i * 1e-9}]\n\t[expr {1.0 + $i}]\n\n"
    }
    append b "Plotname: Operating Point\nFlags: real\nNo. Variables: 1\nNo. Points: 1\n"
    append b "Variables:\n\t0\tv(out)\tvoltage\nValues:\n0\t1.25\n\n"
    wr $path $b
}

## A run directory as a finished run leaves it.  `ranmeas`: the measurement
## rows of the run-state snapshot, or `-` for a run that left no snapshot.
## `sidecar`: the measurement file's text, or `-` for none.  `exit`: the log
## footer's code.  `stale` 1 makes the deck newer than the results.
set T0 [expr {[clock seconds] - 7200}]
proc mkrun {dir cell ranmeas sidecar {exit 0} {stale 0}} {
    global T0
    # the run's own files only: a saved result lives under this directory
    foreach f [glob -nocomplain -directory $dir ${cell}_ase.*] { file delete -force $f }
    file mkdir $dir
    set deck [wr [file join $dir ${cell}_ase.spice] "* deck\n.end\n"]
    file mtime $deck [expr {$stale ? $T0 + 600 : $T0}]
    set raw [file join $dir ${cell}_ase.raw]
    mkraw $raw
    file mtime $raw [expr {$T0 + 20}]
    set log [wr [file join $dir ${cell}_ase.log] "run\n\n=== exit $exit after 1.00 s ===\n"]
    file mtime $log [expr {$T0 + 21}]
    if {$sidecar ne {-}} {
        file mtime [wr [file join $dir ${cell}_ase.meas] $sidecar] [expr {$T0 + 15}]
    }
    if {$ranmeas ne {-}} {
        set rs [fx_state $dir $cell $ranmeas]
        file mtime [wr [file join $dir ${cell}_ase.runstate] [ase::state_serialize $rs]] \
            [expr {$T0 + 1}]
    }
    return $dir
}

## a session on <scratch>/<sub>; returns its key
proc mksession {sub cell {meas -}} {
    set d [file normalize [file join $::scratch $sub]]
    set sp [file join $::scratch $sub.state]
    ase::state_save $sp [fx_state $d $cell $meas]
    set key L1768/$cell/$sub
    catch {ase::session_close $key}
    ase::session_open $key $sp
    return $key
}
proc sess_meas {key rows} {
    set st [ase::session_state $key]
    dict set st measurements $rows
    ase::session_update $key $st
}
proc vals {rows} { return [lmap r $rows {lindex $r 2}] }

# =============================================================================
# MC -- A ROW AS A COMPARABLE VALUE
# =============================================================================
proc same {a b} { return [expr {[ase::meas_row_canon $::SIM $a] eq [ase::meas_row_canon $::SIM $b]}] }
group MC {
    check "MC fixture: the two analyses have handles to name" \
        [list [expr {$H_AC ne {}}] [expr {$H_TRAN ne {}}] [expr {$H_AC ne $H_TRAN}]] {1 1 1}
    check "MC the order of a row's keys does not matter" \
        [same {name a kind max target v(o)} {target v(o) kind max name a}] 1
    check "MC white space around a value does not matter" \
        [same {name a kind max target { v(o) }} {name a kind max target v(o)}] 1
    check "MC `enabled 1` is the absent value: the two rows are one" \
        [same {name a kind max target v(o) enabled 1} {name a kind max target v(o)}] 1
    check "MC a row switched off is not the row switched on" \
        [same {name a kind max target v(o) enabled 0} {name a kind max target v(o)}] 0
    check "MC another value, another name, another kind, a field more: each is another row" \
        [list [same {name a kind max target v(o)} {name a kind max target v(p)}] \
              [same {name a kind max target v(o)} {name b kind max target v(o)}] \
              [same {name a kind max target v(o)} {name a kind min target v(o)}] \
              [same {name a kind max target v(o)} {name a kind max target v(o) from 1}]] {0 0 0 0}
    # what the Measurements dialog does to a row when it reads its form: a key
    # holding the field's default, or nothing, is dropped (a template writes them)
    set tt {name d kind trigtarg trig v(a) trigval 0.5 trigdir rise trign 1 targ v(b) targval 0.5 targdir rise}
    check "MC fixture: `rise` and `1` ARE the defaults of those fields" \
        [list [ase::meas_field_value $SIM trigtarg {name d kind trigtarg} trigdir] \
              [ase::meas_field_value $SIM trigtarg {name d kind trigtarg} trign] \
              [ase::meas_field_value $SIM trigtarg {name d kind trigtarg} targdir]] {rise 1 rise}
    check "MC a key that holds its field's default is the row without the key" \
        [same $tt {name d kind trigtarg trig v(a) trigval 0.5 targ v(b) targval 0.5}] 1
    check "MC ...control: the same key holding another value is another row" \
        [same $tt {name d kind trigtarg trig v(a) trigval 0.5 trigdir fall targ v(b) targval 0.5}] 0
    set nd 0 ; set bad {}
    dict for {k e} [ase::meas_kinds $SIM] {
        foreach f [ase::meas_kind_fields $SIM $k] {
            if {![dict exists $f default] || [dict get $f default] eq {}} { continue }
            incr nd
            set fn [dict get $f name]
            if {![same [list name a kind $k $fn [dict get $f default]] [list name a kind $k]]} { lappend bad $k/$fn }
        }
    }
    check "MC ...for every field of every kind the simulator describes that declares a default (fields that do; kind/field where it fails)" \
        [list [expr {$nd > 3}] $bad] {1 {}}
    check "MC a key that holds nothing is the row without the key" \
        [same {name a kind max target v(o) from {} to {}} {name a kind max target v(o)}] 1
    check "MC a key that is no field of the row's kind reaches no deck and is not compared" \
        [same {name a kind max target v(o) trigval 9 note {mine}} {name a kind max target v(o)}] 1
    check "MC a row that is no dict at all compares as itself and raises nothing" \
        [list [pcall same {name a kind} {name a kind}] [pcall same {odd} {odd}] [pcall same {odd} {even}]] {1 1 0}
}

# =============================================================================
# MR -- DID THE RUN MEASURE THIS ROW AS IT STANDS
# =============================================================================
# Was `row`, one of the measurements `now` of the state on screen, measured as
# it stands by a run launched with the measurements `ran`?  Both lists sit in
# whole states, so every verdict is asked of a state that holds the row.
proc wasrun {row now ran {an_now {}} {an_ran {}}} {
    set d [file join $::scratch mr]
    set sn [fx_state $d tb $now]
    set sr [fx_state $d tb $ran]
    if {$an_now ne {}} { dict set sn analyses $an_now }
    if {$an_ran ne {}} { dict set sr analyses $an_ran }
    return [ase::meas_was_run $::SIM $sn $sr $row]
}
# `list` with element `i` replaced by `row`
proc with {list i row} { lset list $i $row ; return $list }
group MR {
    set d [file join $scratch mr]
    set rst [fx_state $d tb]
    check "MR fixture: the run's own state measures ugf, pmph, pm and tr (verdicts)" \
        [lmap r [list $M_UGF $M_PMPH $M_PM $M_TR] {lindex [ase::meas_verdict $SIM $rst $r] 0}] \
        {ok ok ok ok}
    check "MR a row the run carried, unchanged: measured" [wasrun $M_UGF $MEAS $MEAS] 1
    set shuf [list id $H_AC analysis ac dir fall value 0 target vdb(out) kind when name ugf]
    check "MR ...whatever order its keys are stored in" [wasrun $shuf [with $MEAS 0 $shuf] $MEAS] 1
    set edited $M_UGF ; dict set edited value -3
    check "MR one field changed since the run: not measured as it stands" \
        [list [lindex [ase::meas_verdict $SIM [fx_state $d tb [with $MEAS 0 $edited]] $edited] 0] \
              [wasrun $edited [with $MEAS 0 $edited] $MEAS]] {ok 0}
    set renamed $M_UGF ; dict set renamed name ugf2
    check "MR renamed since the run: not measured as it stands" [wasrun $renamed [with $MEAS 0 $renamed] $MEAS] 0
    set new1 [list name new1 kind max target v(out) analysis tran id $H_TRAN]
    check "MR a row the run never held: not measured" [wasrun $new1 [linsert $MEAS end $new1] $MEAS] 0
    set on [dict remove $M_OFF enabled]
    check "MR switched off in the run, on now: not measured" [wasrun $on [with $MEAS 6 $on] $MEAS] 0
    check "MR switched off now: not measured, whatever the run did" \
        [list [wasrun $M_OFF $MEAS $MEAS] [wasrun $M_OFF $MEAS [with $MEAS 6 $on]]] {0 0}
    # the run refused the row: its analysis was switched off THEN
    set an_off [list {type ac enabled 0 sweep dec points 100 start 1 stop 1g} \
                     {type tran enabled 1 step 2u stop 3m} {type op enabled 1}]
    set rst2 $rst ; dict set rst2 analyses $an_off
    check "MR fixture: with its analysis off, the run's state refuses ugf" \
        [lindex [ase::meas_verdict $SIM $rst2 $M_UGF] 0] refuse
    check "MR a row the run held but refused (its analysis was off then, and is on now): not measured" \
        [wasrun $M_UGF $MEAS $MEAS {} $an_off] 0
    check "MR ...and a row of the other analysis in that same run: measured" \
        [wasrun $M_TR $MEAS $MEAS {} $an_off] 1
    # ---- what a row is computed from ----------------------------------------
    check "MR the words of a row that may name another measurement, lower case: an expression's own, the row it is measured on; a node inside v() or vdb() is not one" \
        [list [ase::meas_ref_words $SIM $M_PM] [ase::meas_ref_words $SIM $M_PMPH] \
              [ase::meas_ref_words $SIM [list name gm kind find target PH when vdb(out) value 0 analysis ac id $H_AC]] \
              [ase::meas_ref_words $SIM [list name pk kind max target v(out) on sp analysis tran id $H_TRAN]]] \
        {pmph {} ph sp}
    check "MR ...a function's name is not a word; its argument is; a device quantity and v(a,b) give nothing; `\$&name` counts in any field" \
        [list [ase::meas_ref_words $SIM {name x kind param expr {db(pm) + mag(v(out)) * Gain}}] \
              [ase::meas_ref_words $SIM {name x kind max target {@m.xm1.m0[gm] + v(a,b) + i(v1)}}] \
              [ase::meas_ref_words $SIM {name x kind find target v(out) at {$&ugf}}] \
              [ase::meas_ref_words $SIM {name x kind find target v(out) at 1k}]] \
        {{pm gain} {} ugf {}}
    set e1 $M_PMPH ; dict set e1 value -6
    check "MR pm = 180 + pmph, and pmph was edited after the run: pm is not measured as it stands either; ugf, which reads neither, is" \
        [list [wasrun $e1 [with $MEAS 1 $e1] $MEAS] [wasrun $M_PM [with $MEAS 1 $e1] $MEAS] \
              [wasrun $M_UGF [with $MEAS 1 $e1] $MEAS]] {0 0 1}
    check "MR ...control: with pmph as the run held it, pm is measured" [wasrun $M_PM $MEAS $MEAS] 1
    set off1 $M_PMPH ; dict set off1 enabled 0
    check "MR the measure it reads was switched off after the run: not measured as it stands" \
        [wasrun $M_PM [with $MEAS 1 $off1] $MEAS] 0
    check "MR the measure it reads was ALREADY off in the run and still is: the row stands as it stood, so the run's own answer is shown -- a run from this very state must not read as if something had changed" \
        [list [wasrun $M_PM [with $MEAS 1 $off1] [with $MEAS 1 $off1]] \
              [lindex [lindex [ase::meas_shown $SIM [fx_state $d tb [with $MEAS 1 $off1]] \
                                  [fx_state $d tb [with $MEAS 1 $off1]] "ASE-MEAS\n"] 2] 1]] {1 failed}
    check "MR the measure it reads was deleted after the run: nothing to read, not measured as it stands" \
        [wasrun $M_PM [lreplace $MEAS 1 1] $MEAS] 0
    set rn $M_PMPH ; dict set rn name phx
    check "MR the measure it reads was renamed after the run (its own text untouched): not measured as it stands" \
        [wasrun $M_PM [with $MEAS 1 $rn] $MEAS] 0
    # three deep: c2 reads c1 reads c0
    set c0 [list name c0 kind max target v(out) analysis tran id $H_TRAN]
    set c1 [list name c1 kind param expr {c0 * 2} analysis tran id $H_TRAN]
    set c2 [list name c2 kind param expr {c1 + 1} analysis tran id $H_TRAN]
    set c0e $c0 ; dict set c0e target v(in)
    check "MR a measure computed from a measure computed from an edited one: not measured as it stands, two steps away" \
        [list [wasrun $c2 [list $c0 $c1 $c2] [list $c0 $c1 $c2]] [wasrun $c2 [list $c0e $c1 $c2] [list $c0 $c1 $c2]] \
              [wasrun $c1 [list $c0e $c1 $c2] [list $c0 $c1 $c2]]] {1 0 0}
    # a measurement named like a node is not read by the rows that measure the node
    set nout [list name out kind avg target v(out) analysis tran id $H_TRAN enabled 0]
    set npp  [list name opp kind pp target v(out) analysis tran id $H_TRAN]
    check "MR a measurement called `out`, switched off, beside one that measures the node out: that one is measured" \
        [list [ase::meas_ref_words $SIM $npp] [wasrun $npp [list $nout $npp] [list $nout $npp]]] {{} 1}
    set dgm [list name g1 kind max target {@m.x1.m1[gm]} analysis tran id $H_TRAN]
    set mgm [list name gm kind max target v(out) analysis tran id $H_TRAN]
    check "MR a row that measures a device's gm, after a measurement called `gm` was added beside it: still measured" \
        [wasrun $dgm [list $dgm $mgm] [list $dgm]] 1
    # a result substituted into a field
    set at1 [list name pat kind find target vp(out) at {$&ugf} analysis ac id $H_AC]
    check "MR a row whose At is another measure's result: measured with that measure as run, not measured once it was edited" \
        [list [wasrun $at1 [list $M_UGF $at1] [list $M_UGF $at1]] \
              [wasrun $at1 [list $edited $at1] [list $M_UGF $at1]]] {1 0}
    # ---- the dialog read its form: keys at their defaults are gone ----------
    set tt [list name dly kind trigtarg trig v(in) trigval 0.5 trigdir rise trign 1 targ v(out) targval 0.5 targdir rise analysis tran id $H_TRAN]
    set tt2 [dict remove $tt trigdir trign targdir]
    check "MR the run held a row with keys at their defaults (a template's); the stored row lost them when the dialog read its form: measured" \
        [list [expr {$tt ne $tt2}] [wasrun $tt2 [list $tt2] [list $tt]]] {1 1}
    # ---- rows that make a plot feed the ones behind them --------------------
    set rs  [list name rs kind linearize np 1024 analysis tran id $H_TRAN]
    set sp1 [list name sp1 kind fft target v(out) analysis tran id $H_TRAN]
    set pk  [list name pk kind max target {mag(v(out))} on sp1 analysis tran id $H_TRAN]
    set P [list $rs $sp1 $pk]
    check "MR fixture: the run's state takes the three rows (resample, transform, a peak on the transform)" \
        [lmap r $P {lindex [ase::meas_verdict $SIM [fx_state $d tb $P] $r] 0}] {ok ok ok}
    check "MR ...and as the run held them, the peak is measured" [wasrun $pk $P $P] 1
    set rs2 $rs ; dict set rs2 np 64
    set rs3 $rs ; dict set rs3 enabled 0
    check "MR fixture: the transform is still taken without its resample row, so its verdict alone would not say" \
        [lmap n [list [list $rs2 $sp1 $pk] [list $rs3 $sp1 $pk] [list $sp1 $pk]] \
             {lindex [ase::meas_verdict $SIM [fx_state $d tb $n] $pk] 0}] {ok ok ok}
    check "MR the resample row edited, switched off, or deleted after the run: the peak on the transform behind it is not measured as it stands" \
        [list [wasrun $pk [list $rs2 $sp1 $pk] $P] [wasrun $pk [list $rs3 $sp1 $pk] $P] \
              [wasrun $pk [list $sp1 $pk] $P]] {0 0 0}
    check "MR ...control: a plot row added BEHIND the transform changes nothing for the peak" \
        [wasrun $pk [list $rs $sp1 $pk [list name sp2 kind fft target v(in) analysis tran id $H_TRAN]] $P] 1
    # ---- the analysis a row reads -------------------------------------------
    set an2 [list {type ac enabled 1 sweep dec points 10 start 1 stop 1meg} \
                  {type ac enabled 1 sweep dec points 10 start 1g stop 10g} \
                  {type tran enabled 1 step 2u stop 3m}]
    set h2 [lindex [ase::analysis_handles [dict create analyses $an2]] 0]
    set g  [list name g kind max target vdb(out) analysis ac id $h2]
    set gt [list name g kind max target vdb(out) analysis ac]
    set an2del [lrange $an2 1 end]
    set delst [fx_state $d tb [list $g]] ; dict set delst analyses $an2del
    check "MR fixture: with the first of two ac rows deleted, the same handle names the other sweep, and the row is not refused" \
        [list [lindex [ase::analysis_handles $delst] 0] [lindex [ase::meas_verdict $SIM $delst $g] 0]] [list $h2 ok]
    check "MR two analyses of one type, the first deleted after the run: the row now reads the other sweep, so it is not measured as it stands" \
        [list [wasrun $g [list $g] [list $g] $an2 $an2] [wasrun $g [list $g] [list $g] $an2del $an2]] {1 0}
    set an2unt [lreplace $an2 0 0 {type ac enabled 0 sweep dec points 10 start 1 stop 1meg}]
    check "MR ...and a row that names the type alone, after the first of the two was switched off" \
        [list [wasrun $gt [list $gt] [list $gt] $an2 $an2] [wasrun $gt [list $gt] [list $gt] $an2unt $an2]] {1 0}
    set an1 [lreplace $AN 1 1 {type tran enabled 1 step 1u stop 9m}]
    check "MR control: ONE analysis of the type, its stop time changed after the run: the row reads the same analysis and keeps its number, as an Outputs row keeps its Value" \
        [wasrun $M_TR $MEAS $MEAS $an1 $AN] 1
    # ---- a list of rows that read the rows above them is walked once --------
    set chain [list [list name c0 kind max target v(out) analysis tran id $H_TRAN] \
                    [list name c1 kind param expr {c0 * 2} analysis tran id $H_TRAN]]
    for {set i 2} {$i < 40} {incr i} {
        lappend chain [list name c$i kind param expr "c[expr {$i - 1}] + c[expr {$i - 2}]" analysis tran id $H_TRAN]
    }
    set cst0 [fx_state $d tb $chain]
    set t0 [clock milliseconds]
    set sh [ase::meas_shown $SIM $cst0 $cst0 "ASE-MEAS\nc0 = 1\n"]
    set ms [expr {[clock milliseconds] - $t0}]
    check "MR forty rows that each read the two above: one answer per row, none withheld, in well under the three seconds allowed" \
        [list [llength $sh] [lsearch -exact [lmap e $sh {lindex $e 1}] notrun] [expr {$ms < 3000}]] {40 -1 1}
    # two rows that read each other end, and answer
    set ca [list name ca kind param expr {cb + 1} analysis ac id $H_AC]
    set cb [list name cb kind param expr {ca + 1} analysis ac id $H_AC]
    check "MR two rows that read each other: the question ends, with an answer" \
        [pcall wasrun $ca [list $ca $cb] [list $ca $cb]] 1
}

# =============================================================================
# MS -- WHAT A SURFACE SHOWS PER ROW
# =============================================================================
group MS {
    set d [file join $scratch ms]
    set st [fx_state $d tb]
    set plain [ase::meas_results $SIM $st $SIDECAR]
    check "MS fixture: by name alone -- three numbers, a vector row and a plot row with nothing to report, tr unreported, one off, one refused" \
        [lmap e $plain {lindex $e 1}] {ok ok ok produced produced failed off refused}
    check "MS with no snapshot the answer is ase::meas_results' own" \
        [expr {[ase::meas_shown $SIM $st {} $SIDECAR] eq $plain}] 1
    check "MS with the snapshot of a run that held these very rows: the same answer" \
        [expr {[ase::meas_shown $SIM $st $st $SIDECAR] eq $plain}] 1
    # ugf edited after the run: the sidecar still holds a number under its name
    set em $MEAS
    set e0 $M_UGF ; dict set e0 value -3
    lset em 0 $e0
    set est [fx_state $d tb $em]
    check "MS fixture: by name alone the edited row is handed the old definition's number" \
        [lrange [lindex [ase::meas_results $SIM $est $SIDECAR] 0] 0 2] {ugf ok 9.149274e+05}
    set sh [ase::meas_shown $SIM $est $st $SIDECAR]
    check "MS a row edited after the run: `notrun`, and NO value" [lindex $sh 0] {ugf notrun {} {}}
    check "MS ...the rows beside it keep their answers" \
        [expr {[lrange $sh 1 end] eq [lrange $plain 1 end]}] 1
    # a row added after the run, and one the simulator reported nothing for
    set am [linsert $MEAS end [list name late kind max target v(out) analysis tran id $H_TRAN]]
    set ash [ase::meas_shown $SIM [fx_state $d tb $am] $st $SIDECAR]
    check "MS a row added after the run: `notrun`" [lindex $ash 8] {late notrun {} {}}
    check "MS a row the run measured and the simulator reported nothing for stays `failed`, with its sentence" \
        [list [lindex [lindex $ash 5] 1] [expr {[lindex [lindex $ash 5] 3] ne {}}]] {failed 1}
    check "MS `off` and `refused` are the state's own and outrank the run" \
        [lmap e [lrange $ash 6 7] {lindex $e 1}] {off refused}
    # a plot row added after the run says so too
    set pm2 [linsert $MEAS end [list name sp2 kind fft target v(out) analysis tran id $H_TRAN]]
    check "MS a plot row added after the run: `notrun`, where one the run made is `produced`" \
        [list [lindex [lindex [ase::meas_shown $SIM [fx_state $d tb $pm2] $st $SIDECAR] 8] 1] \
              [lindex [lindex $plain 4] 1]] {notrun produced}
}

# =============================================================================
# MN -- WHICH ROWS ANSWER WITH ONE NUMBER
# =============================================================================
group MN {
    set st [fx_state [file join $scratch mn] tb]
    check "MN the number rows by index: the working vector (3) and the plot (4) are left out; off and refused rows stay" \
        [ase::meas_number_rows $SIM $st] {0 1 2 5 6 7}
    check "MN a Fourier row answers with one number (its THD) and is in" \
        [ase::meas_number_rows $SIM [fx_state x tb [list [list name thd kind fourier fund 1k target v(out) analysis tran id $H_TRAN]]]] {0}
    check "MN no measurements: nothing" [ase::meas_number_rows $SIM [fx_state x tb {}]] {}
}

# =============================================================================
# MV -- ONE VALUE CELL
# =============================================================================
group MV {
    set F [dict create exit 1 log /x/tb_ase.log]
    set FS [ase::ui::lbl_run_failed_value $F]
    set NR [ase::ui::lbl_meas_notrun]
    set t {}
    #        record                         failed has ran   expected
    foreach {e failed has ran exp} [list \
        {a ok 1.5 {}}                       {}  1 1  1.5 \
        {a caution 1.5 {phase is wrapped}}  {}  1 1  1.5 \
        {a ok 1.5 {}}                       {}  0 1  {} \
        {a ok 1.5 {}}                       $F  1 1  $FS \
        {a failed {} {said nothing}}        {}  1 1  {said nothing} \
        {a failed {} {said nothing}}        {}  1 0  {} \
        {a failed {} {said nothing}}        {}  0 1  {} \
        {a notrun {} {}}                    {}  1 1  $NR \
        {a notrun {} {}}                    {}  0 1  {} \
        {a notrun {} {}}                    $F  1 1  $FS \
        {a off {} {}}                       {}  1 1  [ase::ui::lbl_meas_off] \
        {a off {} {}}                       $F  0 0  [ase::ui::lbl_meas_off] \
        {a refused {} {no such analysis}}   {}  0 0  {no such analysis} \
        {a refused {} {no such analysis}}   $F  1 1  {no such analysis} \
        {a fatal {} {would crash}}          {}  0 0  {would crash} \
        {a ok 1.5 {}}                       $F  0 0  $FS \
        {a failed {} {said nothing}}        $F  0 0  $FS \
        {a notrun {} {}}                    $F  0 0  $FS \
        {a produced {} {}}                  {}  1 1  {}] {
        set got [ase::ui::meas_tab_value $e $failed $has $ran]
        if {$got ne $exp} { lappend t [list $e $failed $has $ran -> $got] }
    }
    set ST [ase::ui::lbl_meas_stopped]
    check "MV after a run the user stopped: a measure the simulator said nothing about reads that the run was stopped, with a measurement file or without; a number stays a number" \
        [list [ase::ui::meas_tab_value {a failed {} {said nothing}} {} 1 1 1] \
              [ase::ui::meas_tab_value {a failed {} {said nothing}} {} 1 0 1] \
              [ase::ui::meas_tab_value {a ok 1.5 {}} {} 1 1 1] \
              [ase::ui::meas_value_cell {a failed {} {said nothing}} 1 1] \
              [ase::ui::meas_value_cell {a failed {} {said nothing}} 1]] \
        [list $ST $ST 1.5 $ST {said nothing}]
    check "MV the table: a number only with results that are current; the failed run's sentence; the row's own refusal first; `disabled`; `not measured in this run`; nothing for a plot row (mismatches)" $t {}
    check "MV the two words are not empty and differ from each other" \
        [list [expr {[ase::ui::lbl_meas_off] ne {}}] [expr {$NR ne {}}] [expr {$NR ne [ase::ui::lbl_meas_off]}]] {1 1 1}
    check "MV the sorted view ranks them: a number 0, either sentence 1" \
        [list [ase::ui::value_rank 5.614170e+01] [ase::ui::value_rank $NR] [ase::ui::value_rank [ase::ui::lbl_meas_off]]] {0 1 1}
}

# =============================================================================
# MI -- ITEM IDS AND ORDER
# =============================================================================
group MI {
    check "MI m<index> names a measurement; an integer, a bare m, a padded or signed index do not" \
        [lmap it {m0 m7 m12 0 7 m m01 m-1 mx {} 1m} {ase::ui::meas_item_index $it}] \
        {0 7 12 -1 -1 -1 -1 -1 -1 -1 -1}
    check "MI the id of an index reads back" \
        [lmap i {0 3 11} {ase::ui::meas_item_index [ase::ui::meas_item_id $i]}] {0 3 11}
    set rows {{name w expr vt(a)} {expr v(s)} {name n expr vdc(x)} {name r expr {vdc(z)/0}}}
    set res [dict create w wave n 2.0 r {Cannot evaluate: division by zero}]
    set mrows {{0 ugf 9.1e5} {2 pm {}} {5 tr {said nothing}}}
    check "MI plain: the Outputs rows in their own order (the save left to its tab), then the measurements in theirs" \
        [ase::ui::measures_items $rows $res 0 $mrows] {0 2 3 m0 m2 m5}
    check "MI sorted: the numbers of both kinds first, then blank and sentences, then the wave -- each group in the plain order" \
        [ase::ui::measures_items $rows $res 1 $mrows] {2 m0 3 m2 m5 0}
    check "MI no measurements: the Outputs rows' own order, either way (ase::ui::measures_order's)" \
        [list [ase::ui::measures_items $rows $res 0 {}] [ase::ui::measures_items $rows $res 1 {}]] \
        [list [ase::ui::measures_order $rows $res 0] [ase::ui::measures_order $rows $res 1]]
    check "MI no Outputs rows: the measurements alone" [ase::ui::measures_items {} {} 0 $mrows] {m0 m2 m5}
}

# =============================================================================
# MD -- A SELECTION OVER TWO LISTS
# =============================================================================
group MD {
    check "MD a mixed selection splits into Outputs indices and measurement indices" \
        [ase::ui::selection_split {2 m1 0 m5 bogus m}] {{2 0} {1 5}}
    check "MD an empty selection: two empty lists" [ase::ui::selection_split {}] {{} {}}
    check "MD rows removed by index, whatever order the indices come in; one outside the list is ignored" \
        [list [ase::ui::rows_without {a b c d e} {3 0}] [ase::ui::rows_without {a b c} {7 1 1}] \
              [ase::ui::rows_without {a b c} {}]] {{b c e} {a c} {a b c}}
}

# =============================================================================
# MK -- A SESSION'S MEASUREMENTS AS THE TAB SHOWS THEM
# =============================================================================
group MK {
    set NR [ase::ui::lbl_meas_notrun]
    set OFF [ase::ui::lbl_meas_off]
    # --- never ran -----------------------------------------------------------
    set key [mksession mk0 tb]
    set rows [ase::ui::meas_tab_rows $key]
    check "MK never ran: the six number rows by index and name" \
        [lmap r $rows {lrange $r 0 1}] {{0 ugf} {1 pmph} {2 pm} {5 tr} {6 off1} {7 bad}}
    check "MK never ran: no number and no complaint; the row that is off says so, the row that cannot be measured says why" \
        [list [lrange [vals $rows] 0 4] [string match "*dc9*" [lindex [vals $rows] 5]]] \
        [list [list {} {} {} {} $OFF] 1]
    check "MK fixture: that session has no results" [ase::has_results $key] 0
    # --- ran -----------------------------------------------------------------
    set d [file normalize [file join $scratch mk1]]
    mkrun $d tb $MEAS $SIDECAR
    set key [mksession mk1 tb]
    check "MK fixture: results, no failure, a snapshot" \
        [list [ase::has_results $key] [ase::run_failed $key] [expr {[ase::result_runstate $key] ne {}}]] {1 {} 1}
    set rows [ase::ui::meas_tab_rows $key]
    set trwhy [lindex [lindex [ase::meas_results $SIM [ase::session_state $key]] 5] 3]
    check "MK ran: the simulator's three numbers as it printed them; the measure it reported nothing for says so; off; refused" \
        [list [lrange [vals $rows] 0 4] [string match "*dc9*" [lindex [vals $rows] 5]]] \
        [list [list 9.149274e+05 -1.238583e+02 5.614170e+01 $trwhy $OFF] 1]
    check "MK fixture: that sentence is not empty" [expr {$trwhy ne {}}] 1
    # --- edited after the run ------------------------------------------------
    set em $MEAS
    set e0 $M_UGF ; dict set e0 value -3
    lset em 0 $e0
    sess_meas $key $em
    check "MK one measurement edited after the run: `not measured in this run` in its cell, the others keep their numbers" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 2] [list $NR -1.238583e+02 5.614170e+01]
    # --- added after the run -------------------------------------------------
    sess_meas $key [linsert $MEAS end [list name late kind max target v(out) analysis tran id $H_TRAN]]
    check "MK one measurement added after the run: `not measured in this run`; the one the simulator reported nothing for still says THAT" \
        [list [lindex [vals [ase::ui::meas_tab_rows $key]] 6] [lindex [vals [ase::ui::meas_tab_rows $key]] 3]] \
        [list $NR $trwhy]
    # --- a measure that reads an edited measure ------------------------------
    set e1 $M_PMPH ; dict set e1 value -6
    set dm $MEAS ; lset dm 1 $e1
    sess_meas $key $dm
    check "MK pmph edited after the run: pm, computed from it, reads `not measured in this run` too; ugf keeps its number" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 2] [list 9.149274e+05 $NR $NR]
    sess_meas $key $MEAS
    # --- the Measurements dialog's working copy is not the tab's ---------------
    set ::ase::ui::dlg($key,mrows) [list $e0]
    check "MK a Measurements dialog standing with unsaved edits does not change what the tab shows" \
        [lmap r [ase::ui::meas_tab_rows $key] {lindex $r 1}] {ugf pmph pm tr off1 bad}
    unset ::ase::ui::dlg($key,mrows)
    # --- another state of the same cell, in the same run directory -----------
    # (a state with no run directory of its own shares one with its cell's
    # other states: the results it reads may be another state's)
    set o1 $M_TR ; dict set o1 target v(in)
    set om [list $M_UGF $o1 [list name only2 kind max target v(out) analysis tran id $H_TRAN]]
    set sp2 [file join $scratch mk1b.state]
    ase::state_save $sp2 [fx_state $d tb $om]
    set key2 L1768/tb/mk1b
    catch {ase::session_close $key2}
    ase::session_open $key2 $sp2
    check "MK fixture: the second state reads the first state's run" \
        [list [ase::has_results $key2] [expr {[ase::result_runstate $key2] ne {}}]] {1 1}
    check "MK a second state of the cell on the first state's results: the measurement both hold in the same words shows that run's number; the one it holds differently and the one only it holds read `not measured in this run`" \
        [vals [ase::ui::meas_tab_rows $key2]] [list 9.149274e+05 $NR $NR]
    catch {ase::session_close $key2}
    # --- a failed run --------------------------------------------------------
    mkrun $d tb $MEAS $SIDECAR 1
    set f [ase::run_failed $key]
    check "MK fixture: the run failed, and its results file is still there" \
        [list [dict get $f exit] [ase::has_results $key]] {1 1}
    set v [vals [ase::ui::meas_tab_rows $key]]
    check "MK a failed run: every measurement the run would have answered says the run failed -- never the number it left; off and refused say their own" \
        [list [lrange $v 0 3] [lindex $v 4] [string match "*dc9*" [lindex $v 5]]] \
        [list [lrepeat 4 [ase::ui::lbl_run_failed_value $f]] $OFF 1]
    # --- a failed run that left no results file (a launch deletes the old one) --
    file delete [file join $d tb_ase.raw]
    check "MK fixture: the run failed and there is no results file" \
        [list [dict get [ase::run_failed $key] exit] [ase::has_results $key]] {1 0}
    check "MK a failed run with no results file: the measurements still say the run failed, as every Outputs row does -- not an empty cell" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 3] [lrepeat 4 [ase::ui::lbl_run_failed_value [ase::run_failed $key]]]
    # --- results older than the deck ----------------------------------------
    mkrun $d tb $MEAS $SIDECAR 0 1
    check "MK fixture: the results are older than the deck" [ase::has_results $key] 0
    check "MK results older than the deck: no number, as every other Value cell" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 3] {{} {} {} {}}
    # --- a run with no snapshot ----------------------------------------------
    mkrun $d tb - $SIDECAR
    check "MK fixture: no snapshot" [ase::result_runstate $key] {}
    check "MK a run that left no snapshot: the numbers by name, as before" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 3] [list 9.149274e+05 -1.238583e+02 5.614170e+01 $trwhy]
    # --- results, and neither a snapshot nor a measurement file ----------------
    mkrun $d tb - -
    check "MK fixture: results, no snapshot, no measurement file" \
        [list [ase::has_results $key] [ase::result_runstate $key] [ase::ui::meas_ran $key]] {1 {} 0}
    check "MK results with no measurement file and nothing to say what the run measured: empty cells, not the simulator's complaint about a run that was asked nothing" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 3] {{} {} {} {}}
    # --- a run that measured nothing: no measurement file ---------------------
    mkrun $d tb {} -
    check "MK a run that carried no measurement: each row was added since, and says so" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 3] [lrepeat 4 $NR]
    # --- a session with no measurement at all --------------------------------
    set key0 [mksession mk2 tb {}]
    check "MK a session with no measurement: nothing to show" [ase::ui::meas_tab_rows $key0] {}
    check "MK an unknown session: nothing, and no error" [pcall ase::ui::meas_tab_rows L1768/none/none] {}
    # --- a saved result in view (R913) ----------------------------------------
    mkrun $d tb $MEAS $SIDECAR
    set r [pcall ase::saved_save $key keep1 {} {} 0]
    set sv [pcall dict get $r dir]
    check "MK fixture: the result was saved, with its measurement file and its snapshot" \
        [list [file isfile [file join $sv tb_ase.meas]] [file isfile [file join $sv tb_ase.runstate]]] {1 1}
    # the live run moves on: other numbers, and ugf edited before it
    mkrun $d tb $em "ASE-MEAS\nugf = 1.000000e+00\npmph = 2.000000e+00\npm = 3.000000e+00\n"
    sess_meas $key $em
    check "MK the live run: its own numbers" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 2] {1.000000e+00 2.000000e+00 3.000000e+00}
    ase::result_sel_note $key [file join $sv tb_ase.raw]
    check "MK fixture: the saved result is in view" [expr {[ase::result_view $key] ne {}}] 1
    check "MK the saved result in view: ITS numbers; the measurement edited since that run is `not measured in this run`" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 2] [list $NR -1.238583e+02 5.614170e+01]
    ase::result_sel_note $key {}
    check "MK back to the live run: its numbers again" \
        [lrange [vals [ase::ui::meas_tab_rows $key]] 0 2] {1.000000e+00 2.000000e+00 3.000000e+00}
    # --- a saved result whose snapshot Save made from the CURRENT state -------
    # (the run left none): nothing says what that run measured
    mkrun $d tb - $SIDECAR
    sess_meas $key $MEAS
    set r2 [pcall ase::saved_save $key keep2 {} {} 0]
    set sv2 [pcall dict get $r2 dir]
    check "MK fixture: saved, and the meta says its snapshot was made from the current state" \
        [list [file isfile [file join $sv2 tb_ase.runstate]] [ase::state_get [ase::saved_meta $sv2] state_source]] {1 current}
    sess_meas $key $em
    ase::result_sel_note $key [file join $sv2 tb_ase.raw]
    check "MK that saved result in view: its snapshot is not taken for the run's, so the numbers are shown by name as before -- the edited measurement's too" \
        [list [ase::result_runstate $key] [lrange [vals [ase::ui::meas_tab_rows $key]] 0 2]] \
        [list {} {9.149274e+05 -1.238583e+02 5.614170e+01}]
    ase::result_sel_note $key {}
    sess_meas $key $MEAS
}

# =============================================================================
# ML -- THE SENTENCES THAT SAY WHICH KIND OF MEASURE
# =============================================================================
group ML {
    set mw [ase::ui::lbl_meas_what ngspice]
    set ow [ase::ui::lbl_output_what ngspice]
    check "ML the Measurements dialog's line names the simulator, the Calculator, and the door to the other kind" \
        [list [string match "*simulator (ngspice)*" $mw] [string match "*[ase::ui::lbl_by_calc]*" $mw] \
              [string match "*Output*" $mw]] {1 1 1}
    check "ML the output editor's line names the Calculator, the simulator, and the menu path to the other kind" \
        [list [string match "*[ase::ui::lbl_by_calc]*" $ow] [string match "*simulator (ngspice)*" $ow] \
              [expr {[string first [ase::ui::menu_path_measurements] $ow] >= 0}]] {1 1 1}
    check "ML the simulator's name is the argument's, not a typed one" \
        [list [string match "*(spectre)*" [ase::ui::lbl_meas_what spectre]] \
              [string match "*ngspice*" [ase::ui::lbl_meas_what spectre]] \
              [string match "*(spectre)*" [ase::ui::lbl_output_what spectre]] \
              [string match "*ngspice*" [ase::ui::lbl_output_what spectre]]] {1 0 1 0}
    check "ML the menu path is composed of the two labels the menu is built from" \
        [ase::ui::menu_path_measurements] "[ase::ui::lbl_outputs] > [ase::ui::lbl_measurements_menu]"
    check "ML who computes a row: the session's simulator for a measurement, the Calculator for an Outputs row" \
        [list [ase::ui::measures_by [mksession ml tb] m0] [ase::ui::measures_by L1768/tb/ml 0] \
              [ase::ui::lbl_by_calc]] {ngspice Calculator Calculator}
    set stx [ase::session_state L1768/tb/ml]
    dict set stx simulator simx
    ase::session_update L1768/tb/ml $stx
    check "ML ...by the name the SESSION gives its simulator, whatever that is" \
        [list [ase::ui::measures_by L1768/tb/ml m0] [ase::ui::measures_by L1768/tb/ml 0]] {simx Calculator}
    check "ML the Measurements dialog's line names a door that is there: the first entry of the pane's right-click menu" \
        [list [expr {[string first [ase::ui::lbl_ctx_add] $mw] >= 0}] [string match "*right-click*Measures*" $mw]] {1 1}
}

# =============================================================================
# MX -- THE REAL SIMULATOR, THROUGH A REAL LAUNCH
# =============================================================================
# Everything above writes the measurement file and the snapshot itself.  Here
# ase::run_deck launches the simulator found on PATH, so the two files are the
# ones a run leaves, and the rule that they describe one run is measured.
set NG [lindex [auto_execok ngspice] 0]
if {$NG eq {}} {
    puts "skip: MX -- no ngspice on PATH, so the real-run rows did not run"
} else {
    group MX {
        set d [file normalize [file join $scratch mx]]
        file mkdir $d
        set an {{type tran enabled 1 step 10n stop 20u}}
        set h [lindex [ase::analysis_handles [dict create analyses $an]] 0]
        set m_max   [list name vmax kind max target v(out) analysis tran id $h]
        set m_cross [list name tcross kind when target v(out) value 0.5 dir rise analysis tran id $h]
        set m_never [list name never kind when target v(out) value 5 analysis tran id $h]
        set st [ase::state_default]
        dict set st design [dict create lib L1768 cell tbx view schematic]
        dict set st rundir $d
        dict set st analyses $an
        dict set st outputs {{name vo expr vt(out) save 0 plot 0}}
        dict set st measurements [list $m_max $m_cross $m_never]
        set sp [file join $scratch mx.state]
        ase::state_save $sp $st
        set key L1768/tbx/mx
        catch {ase::session_close $key}
        ase::session_open $key $sp
        set nl [wr [file join $d tbx.spice] \
            "* 1768 mx\nv1 in 0 pulse(0 1 1u 10n 10n 5u 20u)\nr1 in out 1k\nc1 out 0 1n\n.end\n"]
        proc mx_run {key nl} {
            set rc [catch {ase::run_deck [ase::session_state $key] $nl} id]
            if {!$rc} { catch {ase::wait $id} }
            return $rc
        }
        check "MX fixture: before any run the three cells are empty" [vals [ase::ui::meas_tab_rows $key]] {{} {} {}}
        check "MX the launch was accepted" [mx_run $key $nl] 0
        check "MX the run left results, a measurement file and a snapshot, and did not fail" \
            [list [ase::has_results $key] [file isfile [ase::meas_path [ase::session_state $key]]] \
                  [expr {[ase::result_runstate $key] ne {}}] [ase::run_failed $key]] {1 1 1 {}}
        set v [vals [ase::ui::meas_tab_rows $key]]
        set t1 [lindex $v 1]
        check "MX the two measures the run answers are numbers: the peak near 1 V, the crossing after the pulse starts" \
            [list [expr {[string is double -strict [lindex $v 0]] && [lindex $v 0] > 0.9 && [lindex $v 0] < 1.1}] \
                  [expr {[string is double -strict $t1] && $t1 > 1e-6 && $t1 < 5e-6}]] {1 1}
        check "MX the measure whose level is never reached: the simulator's silence is said, and it is not the edited-row sentence" \
            [list [expr {[lindex $v 2] ne {}}] [expr {[lindex $v 2] ne [ase::ui::lbl_meas_notrun]}] \
                  [string is double -strict [lindex $v 2]]] {1 1 0}
        # the crossing level is changed after the run
        set e $m_cross ; dict set e value 0.2
        sess_meas $key [list $m_max $e $m_never]
        set v2 [vals [ase::ui::meas_tab_rows $key]]
        check "MX a measurement edited after that run: `not measured in this run`, while the measurement file still holds the old number under its name" \
            [list [lindex $v2 1] [ase::meas_result $SIM [ase::session_state $key] tcross] [lindex $v2 0]] \
            [list [ase::ui::lbl_meas_notrun] $t1 [lindex $v 0]]
        check "MX the next launch was accepted" [mx_run $key $nl] 0
        set v3 [vals [ase::ui::meas_tab_rows $key]]
        check "MX after the next run the edited measurement has its own number: an earlier crossing than the first" \
            [list [string is double -strict [lindex $v3 1]] \
                  [expr {[string is double -strict [lindex $v3 1]] && [lindex $v3 1] < $t1}]] {1 1}
        catch {ase::session_close $key}
    }
}

# =============================================================================
# MW -- THE WINDOW (display arm)
# =============================================================================
proc tv_bbox {tv item {col {}}} {
    for {set i 0} {$i < 100} {incr i} {
        update
        if {$col ne {}} { set bb [$tv bbox $item $col] } else { set bb [$tv bbox $item] }
        if {[llength $bb] == 4} { return $bb }
        after 50
    }
    return {}
}
# two press/release pairs: Tk refuses to generate <Double-1> itself
proc tv_dblclick {tv item} {
    set bb [tv_bbox $tv $item name]
    if {[llength $bb] != 4} { return 0 }
    lassign $bb x y wdt hgt
    set cx [expr {$x + $wdt/2}]; set cy [expr {$y + $hgt/2}]
    foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
        event generate $tv $ev -x $cx -y $cy
    }
    update
    return 1
}
proc tv_cell_click {tv item col} {
    set bb [tv_bbox $tv $item $col]
    if {[llength $bb] != 4} { return 0 }
    lassign $bb x y wdt hgt
    set cx [expr {$x + $wdt/2}]; set cy [expr {$y + $hgt/2}]
    event generate $tv <ButtonPress-1> -x $cx -y $cy
    event generate $tv <ButtonRelease-1> -x $cx -y $cy
    update
    return 1
}
proc col {tv c} { return [lmap i [$tv children {}] {$tv set $i $c}] }
proc meas_names {key} { return [lmap r [ase::meas_rows [ase::session_state $key]] {ase::meas_name $r}] }
proc out_exprs {key} { return [lmap o [ase::state_get [ase::session_state $key] outputs] {ase::state_get $o expr}] }

if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "SKIPPED: MW1-MW10 window bands (no X)"
} else {
    set key {}
    set top {}
    group MW1 {
        set d [file normalize [file join $scratch mw]]
        mkrun $d tb $MEAS $SIDECAR
        set key [mksession mw tb]
        set top [ase::ui::open $key L1768 tb mw]
        update
        set mtv $top.body.outs.tv
        set trwhy [lindex [lindex [ase::meas_results $SIM [ase::session_state $key]] 5] 3]
        check "MW1 the Measures tree: the Outputs rows by state index, then the measurements that answer with a number as m<index>; the vector row (3) and the plot row (4) are not there" \
            [$mtv children {}] {0 2 m0 m1 m2 m5 m6 m7}
        check "MW1 the Saves tree is the saves' alone" [$top.body.saves.tv children {}] {1}
        check "MW1 the columns, and the new one's heading" \
            [list [$mtv cget -columns] [$mtv heading by -text]] \
            [list {name value by plot save saveopts} [ase::ui::lbl_out_by]]
        check "MW1 Name: the Outputs rows' names, then the measurements' names" \
            [col $mtv name] {gain vo ugf pmph pm tr off1 bad}
        check "MW1 By: the Calculator for an Outputs row, the simulator for a measurement" \
            [col $mtv by] {Calculator Calculator ngspice ngspice ngspice ngspice ngspice ngspice}
        check "MW1 Value: the simulator's numbers in the column's own format; the unreported measure's sentence; `disabled`" \
            [lrange [col $mtv value] 2 6] \
            [list [ase::format_value 9.149274e+05] [ase::format_value -1.238583e+02] \
                  [ase::format_value 5.614170e+01] $trwhy [ase::ui::lbl_meas_off]]
        check "MW1 ...and the refusal's own sentence for the row that cannot be measured" \
            [string match "*dc9*" [$mtv set m7 value]] 1
        # the pane's own test of a cell too narrow for its text (issue 1499)
        set clipped {}
        foreach it {0 m0} {
            lassign [tv_bbox $mtv $it by] bx by bw bh
            lappend clipped [ase::ui::cell_tip_text $mtv [expr {$bx + $bw/2}] [expr {$by + $bh/2}]]
        }
        check "MW1 the By column opens wide enough for both of its words: neither cell is cut" $clipped {{} {}}
        lassign [tv_bbox $mtv m7 value] bx by bw bh
        check "MW1 control: that test does answer for a cell that IS cut (the long refusal in Value)" \
            [expr {[ase::ui::cell_tip_text $mtv [expr {$bx + $bw/2}] [expr {$by + $bh/2}]] ne {}}] 1
        check "MW1 a measurement has no Plot, no Save and no Save Options: the cells are empty, where an Outputs row has its boxes" \
            [list [lmap c {plot save saveopts} {$mtv set m0 $c}] \
                  [expr {[$mtv set 0 plot] ne {}}] [expr {[$mtv set 0 save] ne {}}]] {{{} {} {}} 1 1}
    }
    group MW2 {
        set mtv $top.body.outs.tv
        set before [list [out_exprs $key] [meas_names $key]]
        uplevel #0 [$mtv heading value -command]
        update
        set ids [$mtv children {}]
        set ranks [lmap i $ids {ase::ui::value_rank [expr {[ase::ui::meas_item_index $i] >= 0
            ? [lindex [lindex [ase::ui::meas_tab_rows $key] [lsearch -exact {0 1 2 5 6 7} [ase::ui::meas_item_index $i]]] 2]
            : [ase::ui::output_value [lindex [ase::state_get [ase::session_state $key] outputs] $i] [ase::session_getattr $key results]]}]}]
        check "MW2 one click on Value: the ranks never fall down the view, and the three measured numbers are in its first group" \
            [list [expr {$ranks eq [lsort -integer $ranks]}] \
                  [expr {[lsearch -exact $ids m0] < [lsearch -exact $ids m5]}] \
                  [expr {[lsearch -exact $ids m2] < [lsearch -exact $ids m6]}]] {1 1 1}
        check "MW2 ...the same items, none lost and none made" [lsort $ids] [lsort {0 2 m0 m1 m2 m5 m6 m7}]
        check "MW2 neither state list is reordered (a VIEW order)" [list [out_exprs $key] [meas_names $key]] $before
        uplevel #0 [$mtv heading value -command]
        update
        check "MW2 a second click restores the plain order" [$mtv children {}] {0 2 m0 m1 m2 m5 m6 m7}
    }
    group MW3 {
        set mtv $top.body.outs.tv
        catch {destroy $top.meas} ; catch {destroy $top.edout}
        check "MW3 fixture: the double click was sent" [tv_dblclick $mtv m2] 1
        check "MW3 a double click on a measurement opens the Measurements dialog -- not the output editor" \
            [list [winfo exists $top.meas] [winfo exists $top.edout]] {1 0}
        check "MW3 ...on THAT row: the dialog's selection, and the form's Name" \
            [list [$top.meas.rows selection] [pcall $top.meas.form.name get]] {2 pm}
        check "MW3 ...and the dialog lists the whole measurement list, the plot and vector rows included" \
            [llength [$top.meas.rows children {}]] [llength $MEAS]
        ase::ui::meas_cancel $key
        update
        check "MW3 fixture: the second double click was sent" [tv_dblclick $mtv 2] 1
        check "MW3 a double click on an Outputs row opens the output editor on it -- not the Measurements dialog" \
            [list [winfo exists $top.edout] [winfo exists $top.meas] [pcall $top.edout.expr get]] {1 0 vdc(out)}
        ase::ui::output_editor_cancel $key
        update
        # the dialog is standing with something typed into it
        ase::ui::measurements_dialog $key 0
        update
        set wid [winfo id $top.meas]
        $top.meas.form.fvalue delete 0 end
        $top.meas.form.fvalue insert 0 -9
        set st0 [ase::session_state $key]
        check "MW3 fixture: the double click with the dialog standing was sent" [tv_dblclick $mtv m5] 1
        check "MW3 a double click on another measurement while the dialog stands: the same window goes to that row" \
            [list [expr {[winfo exists $top.meas] && [winfo id $top.meas] == $wid}] [$top.meas.rows selection] \
                  [pcall $top.meas.form.name get]] {1 5 tr}
        check "MW3 ...and what was typed into the row it left is kept in the dialog, not written to the state" \
            [list [ase::state_get [lindex [ase::ui::meas_rows $key] 0] value] \
                  [expr {[ase::session_state $key] eq $st0}]] {-9 1}
        ase::ui::meas_cancel $key
        update
        check "MW3 the dialog opened with no row named starts on the first, as before" \
            [list [winfo exists [ase::ui::measurements_dialog $key]] [$top.meas.rows selection]] {1 0}
        ase::ui::meas_cancel $key
        check "MW3 a row index outside the list is ignored" \
            [list [winfo exists [ase::ui::measurements_dialog $key 99]] [$top.meas.rows selection]] {1 0}
        ase::ui::meas_cancel $key
        update
    }
    group MW4 {
        set mtv $top.body.outs.tv
        $mtv selection set {}
        set st0 [ase::session_state $key]
        check "MW4 fixture: the click on the measurement's Plot cell was sent" [tv_cell_click $mtv m1 plot] 1
        check "MW4 a click on a measurement's Plot cell changes no state and selects the row" \
            [list [expr {[ase::session_state $key] eq $st0}] [$mtv selection]] {1 m1}
        check "MW4 ...the handler leaves that click to the selection, and takes the one on an Outputs row" \
            [list [ase::ui::pane_click $key outs {*}[lrange [tv_bbox $mtv m1 save] 0 1]] \
                  [expr {[ase::session_state $key] eq $st0}]] {0 1}
        set p0 [ase::state_get [lindex [ase::state_get $st0 outputs] 0] plot 0]
        tv_cell_click $mtv 0 plot
        check "MW4 control: the same click on an Outputs row flips its Plot" \
            [expr {[ase::state_get [lindex [ase::state_get [ase::session_state $key] outputs] 0] plot 0] ne $p0}] 1
        tv_cell_click $mtv 0 plot
        update
    }
    group MW5 {
        set mtv $top.body.outs.tv
        ase::ui::measurements_dialog $key 0
        update
        set mw $top.meas
        check "MW5 fixture: the dialog shows the run's number for ugf" [$mw.rows set 0 value] 9.149274e+05
        $mw.form.fvalue delete 0 end
        $mw.form.fvalue insert 0 -3
        ase::ui::meas_harvest $key
        ase::ui::meas_fill $key
        check "MW5 a measurement edited in the form: its Value in the dialog is `not measured in this run`, not the old definition's number" \
            [$mw.rows set 0 value] [ase::ui::lbl_meas_notrun]
        check "MW5 ...the tab still shows the stored row and its number until OK" \
            [$mtv set m0 value] [ase::format_value 9.149274e+05]
        ase::ui::meas_ok $key
        update
        check "MW5 OK: the dialog is gone, the state holds the edit, and the tab's cell reads `not measured in this run`" \
            [list [winfo exists $mw] [ase::state_get [lindex [ase::meas_rows [ase::session_state $key]] 0] value] \
                  [$mtv set m0 value]] [list 0 -3 [ase::ui::lbl_meas_notrun]]
        check "MW5 ...the measurements beside it keep their numbers" \
            [list [$mtv set m1 value] [$mtv set m2 value]] \
            [list [ase::format_value -1.238583e+02] [ase::format_value 5.614170e+01]]
        # a look at a row and OK, with nothing typed, on a row stored with keys at
        # their defaults (a template writes such rows; the dialog drops the keys)
        set tt [list name dly kind trigtarg trig v(out) trigval 0.5 trigdir rise trign 1 \
                     targ v(out) targval 0.9 targdir rise analysis tran id $H_TRAN]
        set rows5 [linsert [ase::meas_rows [ase::session_state $key]] end $tt]
        sess_meas $key $rows5
        set d5 [ase::state_get [ase::session_state $key] rundir]
        mkrun $d5 tb $rows5 "ASE-MEAS\npmph = -1.238583e+02\npm = 5.614170e+01\ndly = 2.500000e-06\n"
        ase::ui::populate $key
        update
        set mid m[expr {[llength $rows5] - 1}]
        check "MW5 fixture: the template-shaped row shows the run's number" \
            [$mtv set $mid value] [ase::format_value 2.500000e-06]
        tv_dblclick $mtv $mid
        update
        $top.meas.btns.proceed invoke
        update
        set stored [lindex [ase::meas_rows [ase::session_state $key]] end]
        check "MW5 fixture: the dialog's OK did rewrite that row -- the keys at their defaults are gone from the state" \
            [list [dict exists $stored trigdir] [dict exists $stored trign] [dict exists $stored targdir] \
                  [ase::state_get $stored trigval]] {0 0 0 0.5}
        check "MW5 a look and OK with nothing typed keeps the number: the row gives the simulator what it gave it in the run" \
            [list [$mtv set $mid value] [$mtv set m2 value]] \
            [list [ase::format_value 2.500000e-06] [ase::format_value 5.614170e+01]]
        sess_meas $key [lrange [ase::meas_rows [ase::session_state $key]] 0 end-1]
        ase::ui::populate $key
        update
        # a row that names its analysis by TYPE alone, with no handle
        set ty [list name tonly analysis tran kind max target v(out)]
        set rows6 [linsert [ase::meas_rows [ase::session_state $key]] end $ty]
        sess_meas $key $rows6
        mkrun $d5 tb $rows6 "ASE-MEAS\npmph = -1.238583e+02\npm = 5.614170e+01\ntonly = 1.750000e+00\n"
        ase::ui::populate $key
        update
        set mid m[expr {[llength $rows6] - 1}]
        check "MW5 fixture: the type-only row is measured and shows its number" \
            [list [lindex [ase::meas_verdict $SIM [ase::session_state $key] $ty] 0] [$mtv set $mid value]] \
            [list ok [ase::format_value 1.750000e+00]]
        tv_dblclick $mtv $mid
        update
        check "MW5 a row that names its analysis by type alone: the dialog's Analysis box shows the analysis it reads, not an empty box" \
            [list [pcall $top.meas.form.name get] [expr {[pcall $top.meas.form.analysis get] ne {}}] \
                  [string match "*tran*" [pcall $top.meas.form.analysis get]]] {tonly 1 1}
        $top.meas.btns.proceed invoke
        update
        set stored [lindex [ase::meas_rows [ase::session_state $key]] end]
        check "MW5 ...and a look and OK leaves the row its words: it still names its analysis, gained no handle, is still measured, and keeps its number" \
            [list [ase::state_get $stored analysis] [dict exists $stored id] \
                  [lindex [ase::meas_verdict $SIM [ase::session_state $key] $stored] 0] [$mtv set $mid value]] \
            [list tran 0 ok [ase::format_value 1.750000e+00]]
        # the menu door with the dialog standing keeps what was typed, too
        ase::ui::measurements_dialog $key 0
        update
        $top.meas.form.fvalue delete 0 end
        $top.meas.form.fvalue insert 0 -7
        [ase::ui::window_for $key].mb.outputs invoke [ase::ui::lbl_measurements_menu]
        update
        ase::ui::meas_harvest $key
        check "MW5 Outputs > Measurements with the dialog already standing: the same dialog, with what was typed still in it" \
            [list [winfo exists $top.meas] [ase::state_get [lindex [ase::ui::meas_rows $key] 0] value]] {1 -7}
        ase::ui::meas_cancel $key
        sess_meas $key [lrange [ase::meas_rows [ase::session_state $key]] 0 end-1]
        ase::ui::populate $key
        update
        # a measurement added in the dialog reaches the tab on OK
        ase::ui::measurements_dialog $key
        update
        ase::ui::meas_add $key
        $top.meas.form.name insert 0 late
        ase::ui::meas_ok $key
        update
        check "MW5 a measurement added in the dialog is in the tab after OK, By the simulator" \
            [list [lindex [$mtv children {}] end] [$mtv set m8 name] [$mtv set m8 by]] {m8 late ngspice}
    }
    group MW6 {
        set mtv $top.body.outs.tv
        # the next run: the edited ugf and the new row are in it
        set d [ase::state_get [ase::session_state $key] rundir]
        mkrun $d tb [ase::meas_rows [ase::session_state $key]] \
            "ASE-MEAS\nugf = 7.500000e+05\npmph = -1.200000e+02\npm = 6.000000e+01\n"
        $mtv selection set m2
        ase::ui::results_refill $key
        update
        check "MW6 the refresh a finished run makes: the new numbers, the edited row's among them" \
            [list [$mtv set m0 value] [$mtv set m1 value] [$mtv set m2 value]] \
            [list [ase::format_value 7.500000e+05] [ase::format_value -1.200000e+02] [ase::format_value 6.000000e+01]]
        check "MW6 ...the selection is kept, and no item was made or lost" \
            [list [$mtv selection] [$mtv children {}]] {m2 {0 2 m0 m1 m2 m5 m6 m7 m8}}
        uplevel #0 [$mtv heading value -command]
        update
        $mtv selection set m0
        mkrun $d tb [ase::meas_rows [ase::session_state $key]] "ASE-MEAS\npm = 6.100000e+01\n"
        ase::ui::results_refill $key
        update
        set ids [$mtv children {}]
        check "MW6 on a sorted view the refresh re-sorts: the one number left leads the measurements, and the selection is kept" \
            [list [expr {[lsearch -exact $ids m2] < [lsearch -exact $ids m0]}] [$mtv selection] [$mtv set m2 value]] \
            [list 1 m0 [ase::format_value 6.100000e+01]]
        uplevel #0 [$mtv heading value -command]
        update
    }
    group MW7 {
        set mtv $top.body.outs.tv
        set o0 [out_exprs $key]
        set m0 [meas_names $key]
        $mtv selection set {2 m1 m5}
        ase::ui::delete_selection $key
        update
        check "MW7 Delete on a mixed selection: the Outputs row leaves `outputs`, the two measurements leave `measurements`, nothing else moves" \
            [list [out_exprs $key] [meas_names $key]] \
            [list {db(vf(out)) v(out)} {ugf pm ph sp off1 bad late}]
        check "MW7 fixture: that was one row of three and two of nine" [list [llength $o0] [llength $m0]] {3 9}
        check "MW7 ...the tree follows: the plot and vector rows (now 2 and 3) stay out of it" \
            [list [$mtv children {}] [col $mtv name]] {{0 m0 m1 m4 m5 m6} {gain ugf pm off1 bad late}}
        $mtv selection set m6
        ase::ui::delete_selection $key
        update
        check "MW7 Delete on a measurement alone leaves `outputs` as it was" \
            [list [out_exprs $key] [meas_names $key]] [list {db(vf(out)) v(out)} {ugf pm ph sp off1 bad}]
        # the Measurements dialog is standing, with something typed into it
        ase::ui::measurements_dialog $key 1
        update
        $top.meas.form.fexpr delete 0 end
        $top.meas.form.fexpr insert 0 {170 + ugf}
        $mtv selection set m0
        ase::ui::delete_selection $key
        update
        check "MW7 Delete in the tab with the dialog standing: the measurement leaves the dialog's list too, the row that was selected there stays selected, and what was typed into it is kept" \
            [list [meas_names $key] [lmap r [ase::ui::meas_rows $key] {ase::meas_name $r}] \
                  [$top.meas.rows selection] [pcall $top.meas.form.name get] [pcall $top.meas.form.fexpr get]] \
            [list {pm ph sp off1 bad} {pm ph sp off1 bad} 0 pm {170 + ugf}]
        ase::ui::meas_ok $key
        update
        check "MW7 ...so the dialog's OK does not bring the deleted measurement back, and writes the edit" \
            [list [meas_names $key] [ase::state_get [lindex [ase::meas_rows [ase::session_state $key]] 0] expr]] \
            [list {pm ph sp off1 bad} {170 + ugf}]
    }
    group MW8 {
        catch {destroy $top.meas} ; catch {destroy $top.edout}
        ase::ui::measurements_dialog $key
        update
        check "MW8 the Measurements dialog says its rows are the simulator's, and names the door to the other kind" \
            [list [winfo exists $top.meas.what] [$top.meas.what cget -text]] \
            [list 1 [ase::ui::lbl_meas_what ngspice]]
        check "MW8 ...above the list" \
            [expr {[dict get [grid info $top.meas.what] -row] < [dict get [grid info $top.meas.rows] -row]}] 1
        ase::ui::meas_cancel $key
        ase::ui::outputs_tab $key measures
        ase::ui::output_editor $key -1
        update
        check "MW8 the output editor under the Measures door says its row is the Calculator's, and names the menu path to the other kind" \
            [list [winfo exists $top.edout.what] [pcall $top.edout.what cget -text]] \
            [list 1 [ase::ui::lbl_output_what ngspice]]
        check "MW8 ...above its buttons" \
            [expr {[dict get [grid info $top.edout.what] -row] < [dict get [grid info $top.edout.btns] -row]}] 1
        $top.edout.name insert 0 two
        $top.edout.expr insert 0 {vdc(out)*2}
        ase::ui::output_editor_ok $key
        update
        check "MW8 ...and its OK still adds the row, shown By the Calculator" \
            [list [lindex [out_exprs $key] end] [$top.body.outs.tv set 2 by]] {vdc(out)*2 Calculator}
        ase::ui::output_editor $key 0
        update
        check "MW8 editing an Outputs row of the Measures tab says it too" [winfo exists $top.edout.what] 1
        ase::ui::output_editor_cancel $key
        ase::ui::output_editor $key -1 saves
        update
        check "MW8 the Saves door says nothing of the kind: a save computes nothing" \
            [list [winfo exists $top.edout] [winfo exists $top.edout.what]] {1 0}
        ase::ui::output_editor_cancel $key
        update
        # the door the Measurements dialog names: the pane's right-click Add
        ase::ui::outputs_tab $key saves
        $top.body.outs.ctx invoke [ase::ui::lbl_ctx_add]
        update
        check "MW8 the door the Measurements dialog names is there, and opens the Measures door whichever tab is in front" \
            [list [winfo exists $top.edout] [winfo exists $top.edout.what]] {1 1}
        ase::ui::output_editor_cancel $key
        ase::ui::outputs_tab $key measures
        update
        # a session whose simulator goes by another name
        set st8 [ase::session_state $key]
        set stx $st8 ; dict set stx simulator simx
        ase::session_update $key $stx
        ase::ui::populate $key
        ase::ui::measurements_dialog $key
        update
        set mwx [pcall $top.meas.what cget -text]
        ase::ui::meas_cancel $key
        ase::ui::output_editor $key -1 measures
        update
        set owx [pcall $top.edout.what cget -text]
        ase::ui::output_editor_cancel $key
        check "MW8 with the session's simulator called `simx`: both dialogs' lines and the By cell of a measurement say simx, and nothing says ngspice" \
            [list [string match "*(simx)*" $mwx] [string match "*ngspice*" $mwx] [string match "*(simx)*" $owx] \
                  [string match "*ngspice*" $owx] [$top.body.outs.tv set m0 by] [$top.body.outs.tv set 0 by]] \
            {1 0 1 0 simx Calculator}
        ase::session_update $key $st8
        ase::ui::populate $key
        update
        check "MW8 the Outputs menu's entry is the path the editor names" \
            [expr {[pcall $top.mb.outputs index [ase::ui::lbl_measurements_menu]] ne {}
                   && ![string match ERR:* [pcall $top.mb.outputs index [ase::ui::lbl_measurements_menu]]]}] 1
    }
    group MW9 {
        set mtv $top.body.outs.tv
        catch {destroy $top.meas} ; catch {destroy $top.edout}
        check "MW9 fixture: the measurements at this point, and the tree's items" \
            [list [meas_names $key] [$mtv children {}]] {{pm ph sp off1 bad} {0 2 m0 m3 m4}}
        $mtv selection set m3
        $top.body.outs.ctx invoke "Edit…"
        update
        check "MW9 the context menu's Edit on a measurement opens the Measurements dialog on it" \
            [list [winfo exists $top.meas] [winfo exists $top.edout] [pcall $top.meas.rows selection] \
                  [pcall $top.meas.form.name get]] {1 0 3 off1}
        ase::ui::meas_cancel $key
        $mtv selection set 0
        $top.body.outs.ctx invoke "Edit…"
        update
        check "MW9 ...and on an Outputs row the output editor, as before" \
            [list [winfo exists $top.edout] [winfo exists $top.meas]] {1 0}
        ase::ui::output_editor_cancel $key
        update
    }
    group MW10 {
        set mtv $top.body.outs.tv
        set st10 [ase::session_state $key]
        # a row that is no dict at all (a state edited by hand)
        set bad10 $st10
        dict set bad10 measurements [list {name only kind} [list name ok1 kind max target v(out) analysis tran id $H_TRAN]]
        ase::session_update $key $bad10
        set r [pcall ase::ui::populate $key]
        update
        check "MW10 a row that is no dict is listed with what is wrong with it, beside a good one, and nothing is raised" \
            [list [string match ERR:* $r] [$mtv children {}] [expr {[$mtv set m0 value] ne {}}] [$mtv set m1 name]] \
            {0 {0 2 m0 m1} 1 ok1}
        # whatever goes wrong while the measurements are read
        rename ::ase::ui::meas_tab_rows ::ase::ui::meas_tab_rows_real
        proc ::ase::ui::meas_tab_rows {key} { error "the measurements cannot be read" }
        set r [pcall ase::ui::populate $key]
        update
        set kids [$mtv children {}]
        set r2 [pcall ase::ui::refresh_output_values $key]
        rename ::ase::ui::meas_tab_rows {}
        rename ::ase::ui::meas_tab_rows_real ::ase::ui::meas_tab_rows
        check "MW10 a failure while the measurements are read costs the pane its measurement rows and nothing else: the Outputs rows are painted, and neither the repaint nor the refresh after a run raises" \
            [list [string match ERR:* $r] $kids [string match ERR:* $r2]] {0 {0 2} 0}
        ase::session_update $key $st10
        ase::ui::populate $key
        update
        check "MW10 afterwards the measurements are back" \
            [expr {[lsearch -glob [$mtv children {}] m*] >= 0}] 1
    }
    group MWclose {
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
