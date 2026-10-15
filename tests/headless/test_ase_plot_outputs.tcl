# tests/headless/test_ase_plot_outputs.tcl -- the ASE-L `~` strip button
# evaluates every output against the current results and plots the ticked
# waveforms (ase_l.md R-OUT12).
#
# The user (2026-10-14): "What needs to happen with this button is that, if
# there are outputs that are waveforms that are chosen to be plotted, then, if
# Waveform Viewer is not already up, it will be launched and those signals will
# be plotted. More importantly, measures will be calculated and updated values
# displayed in the Outputs pane (Measures tab)."
#
# Spec     doc/claude/specs/ase_l.md R-OUT12
# Code     src/ase_window.tcl ase::ui::plot_outputs, ase::ui::plot_targets,
#          ase::ui::auto_plot, ase::ui::strip_tips, ase::ui::lbl_plot_outputs
# Fixture  tests/headless/data/calc_fixture.raw, copied into scratch as a
#          session's `<cell>_ase.raw`; on the display arm, the bundled bench
#          sky130A/xschem_libs/sky130_tests_ase/tb_bandgap run for real on the
#          registry ngspice
#
# Bands (both arms; pure, no Tk)
#   PO1  the strip's tip says what the button does, not the viewer's menu path
#   PO2  a row added AFTER the run gets its Value from the button: the Value
#        is evaluated before the plot is asked for
#   PO3  which ticked rows are plotted: a signal and a wave expression are, a
#        scalar measure and an unticked row are not; a row with no value yet
#        is not judged scalar
#   PO4  no results: the button says so and changes nothing
#   PO5  the Value and the Calculator window's own measurement arm agree at
#        full precision on the committed fixture
# Bands (display arm only)
#   PR1  the real bench runs on the registry ngspice
#   PR2  a row added BEFORE the run has its number after the run
#   PR3  a row added AFTER the run is blank until `~`, then shows its number
#   PR4  the Calculator window's Eval of the same text gives the same number,
#        full precision
#   PR5  with the viewer closed, `~` opens it and plots the ticked signals,
#        never the scalar measure, and says nothing about it
#   PR6  the live strip button runs plot_outputs and carries the new tip
#
# REGISTERED IN `hcases` AND `dcases`.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_plot_outputs
#   tests/headless/run_suites.sh test_ase_plot_outputs

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
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch ase_plot_outputs]
set fixture [file join $here data calc_fixture.raw]
set GUI [expr {[info commands toplevel] ne {} && [info commands winfo] ne {}}]

## Every ase::echo is recorded, so a sentence the button says (or must not
## say) is measured rather than assumed.
set ::po_echoes {}
rename ::ase::echo ::po_echo_orig
proc ::ase::echo {msg args} {
    lappend ::po_echoes $msg
    return [::po_echo_orig $msg {*}$args]
}

set FX_EX {settlingTime(vt(lp), 2m, 1, 0, 0, 0, time, time)}

# A session on <scratch>/<sub>, results file <cell>_ase.raw copied from the
# fixture when `raw` is 1.
proc po_session {sub cell outs raw} {
    set d [file join $::scratch $sub]
    file delete -force $d
    file mkdir $d
    if {$raw} { file copy -force $::fixture [file join $d ${cell}_ase.raw] }
    set sf [file join $d s.state]
    set f [open $sf w]
    puts $f "version 1"
    puts $f "simulator ngspice"
    puts $f "design {lib po cell $cell view schematic}"
    puts $f "rundir [list $d]"
    puts $f "temperature 27"
    puts $f "analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 10m step 100u}}"
    puts $f "outputs [list $outs]"
    close $f
    set key po/$cell/$sub
    catch {ase::session_close $key}
    ase::session_open $key $sf
    return $key
}

set PO_OUTS [list {name W expr vt(lp) save 0 plot 1} \
                  {name P expr v(sq) save 1 plot 1} \
                  {name U expr vt(sq) save 0 plot 0} \
                  [list name T expr $FX_EX save 0 plot 1]]

## auto_plot is stood in for on the pure bands: what it is handed, and when,
## is the claim; the viewer itself is the display arm's.
## The names of a plot_targets answer's rows, or a sentinel naming why not.
proc po_names {t} {
    if {[catch {dict get $t rows} rows]} { return ERR:$t }
    if {[catch {lmap o $rows {dict get $o name}} n]} { return ERR:$n }
    return $n
}
proc po_nref {t} {
    if {[catch {llength [dict get $t refused]} n]} { return ERR:$t }
    return $n
}

proc po_stub_autoplot {} {
    set ::po_ap {}
    rename ::ase::ui::auto_plot ::po_ap_orig
    proc ::ase::ui::auto_plot {key} {
        lappend ::po_ap [list $key [ase::session_getattr $key results]]
    }
}
proc po_unstub_autoplot {} {
    rename ::ase::ui::auto_plot {}
    rename ::po_ap_orig ::ase::ui::auto_plot
}

# =============================================================================
# PO1 -- THE TIP
# =============================================================================
group PO1 {
    set tip [pcall dict get [ase::ui::strip_tips] plot]
    check "PO1 the ~ tip says what the button does" $tip {Plot outputs and update values}
    check "PO1 ...and is the shared label, not the viewer's menu path" \
        [list [expr {$tip eq [pcall ase::ui::lbl_plot_outputs]}] \
              [expr {$tip eq [ase::ui::menu_path_waveform_viewer]}]] {1 0}
}

# =============================================================================
# PO2 -- A ROW ADDED AFTER THE RUN
# =============================================================================
group PO2 {
    set key [po_session po2 tbpo $::PO_OUTS 1]
    ## the run's own answers, made before T existed
    set early [list W old P old U old]
    ase::session_setattr $key results $early
    set ref [calc::eval_text $::FX_EX $::fixture {}]
    check "PO2 fixture: the Calculator's evaluator answers T on the fixture" \
        [list [dict get $ref ok] [dict get $ref kind]] {1 scalar}
    po_stub_autoplot
    set ::po_echoes {}
    set rc [pcall ase::ui::plot_outputs $key]
    po_unstub_autoplot
    set res [ase::session_getattr $key results]
    check "PO2 the button answers 1 and T now has its number, %.6e of the Calculator's" \
        [list $rc [val $res T]] [list 1 [format %.6e [dict get $ref value]]]
    check "PO2 every other row is re-read too: the Values are exactly what opening the session reads" \
        $res [ase::ui::results_from_disk $key]
    check "PO2 ...which is not the stale answer it replaced" \
        [list [val $res W] [val $res U]] {wave wave}
    check "PO2 the plot is asked for once, AFTER the values are in (it sees T's number)" \
        [list [llength $::po_ap] [val [lindex [lindex $::po_ap 0] 1] T]] \
        [list 1 [format %.6e [dict get $ref value]]]
    check "PO2 nothing is refused or reported as an error" \
        [lsearch -all -inline -glob $::po_echoes {*cannot*}] {}
    catch {ase::session_close $key}
}

# =============================================================================
# PO3 -- WHICH TICKED ROWS ARE PLOTTED
# =============================================================================
group PO3 {
    set key [po_session po3 tbpo $::PO_OUTS 1]
    ase::session_setattr $key results [ase::ui::results_from_disk $key]
    set t [pcall ase::ui::plot_targets $key]
    check "PO3 a wave expression and a signal are plotted; the scalar measure and the unticked row are not" \
        [po_names $t] {W P}
    check "PO3 ...and nothing is refused" [po_nref $t] 0
    ase::session_setattr $key results {}
    set t [pcall ase::ui::plot_targets $key]
    check "PO3 a row with no value yet is not judged scalar (it is offered to the viewer)" \
        [po_names $t] {W P T}
    set k2 [po_session po3b tbpo {{name VBG expr VBG save 1 plot 1}} 1]
    ase::session_setattr $k2 results {VBG 1.188279e+00}
    set t [pcall ase::ui::plot_targets $k2]
    check "PO3 a plain signal row is plotted even when its Value is the operating-point number" \
        [po_names $t] {VBG}
    set k3 [po_session po3c tbpo {{name A expr vf(lp) save 0 plot 1}} 1]
    set t [pcall ase::ui::plot_targets $k3]
    check "PO3 a row qualified for another analysis is refused with the sentence, not plotted" \
        [list [po_names $t] [po_nref $t]] {{} 1}
    foreach k [list $key $k2 $k3] { catch {ase::session_close $k} }
}

# =============================================================================
# PO4 -- NO RESULTS
# =============================================================================
group PO4 {
    set key [po_session po4 tbpo $::PO_OUTS 0]
    ase::session_setattr $key results {W old}
    po_stub_autoplot
    set ::po_echoes {}
    set rc [pcall ase::ui::plot_outputs $key]
    po_unstub_autoplot
    check "PO4 with no results the button answers 0, says so tersely, plots nothing and leaves the Values" \
        [list $rc $::po_echoes [llength $::po_ap] [ase::session_getattr $key results]] \
        [list 0 [list [ase::ui::lbl_plot_outputs_none]] 0 {W old}]
    check "PO4 the sentence" [ase::ui::lbl_plot_outputs_none] {ase: no results; run a simulation first}
    catch {ase::session_close $key}
    check "PO4 an unknown session answers 0 and raises nothing" \
        [pcall ase::ui::plot_outputs po/none/none] 0
}

# =============================================================================
# PO5 -- THE VALUE AND THE CALCULATOR WINDOW'S ARM AGREE, FULL PRECISION
# =============================================================================
## The window's Eval routes a measurement call to calc::meas_in_token, which
## borrows the viewer's context and calls calc::meas_in_ctx on the loaded
## results; the Outputs Value comes from calc::eval_texts reading the file.
## Two doors to one number: both are driven here on the committed fixture.
group PO5 {
    set m [calc::meas_split $::FX_EX]
    set p [calc::meas_prepare $m]
    catch {xschem raw clear}
    xschem raw read $::fixture tran
    set w [calc::meas_in_ctx [dict get $m verb] \
             [calc::meas_numeric [dict get $m verb] [dict get $p vals]] tran]
    catch {xschem raw clear}
    set o [lindex [calc::eval_texts [list $::FX_EX] $::fixture {}] 0]
    check "PO5 both doors answer" [list [dict get $w ok] [dict get $o ok]] {1 1}
    check "PO5 the window's number and the Outputs number are the same double, as strings" \
        [dict get $w value] [dict get $o value]
    set o2 [calc::eval_text {settlingTime(vt(lp), 2m, 10, 0, 0, 0, time, time)} $::fixture {}]
    check "PO5 control: the arguments reach the verb (a 10% band answers a different number)" \
        [expr {[dict get $o2 value] != [dict get $o value]}] 1
    set key [po_session po5 tbpo $::PO_OUTS 1]
    set res [ase::ui::results_from_disk $key]
    check "PO5 the Value cell's text is %.6e of that same double" \
        [val $res T] [format %.6e [dict get $w value]]
    catch {ase::session_close $key}
}

# =============================================================================
# THE DISPLAY ARM: the real bench
# =============================================================================
set NG /home/analog/dev/ngspice/build-ver_50/src/ngspice
if {!$GUI} {
    puts "SKIP: display-only bands PR1-PR6 (no Tk on this arm)"
} elseif {![file executable $NG]} {
    puts "skip: PR1-PR6 the registry ngspice is not at $NG"
} else {
    source [file join $repo tools migrate op_measures_bench.tcl]
    opm::setup $repo $NG
    set EX {settlingTime(vt(vbg), 100u, 1, 0, 0, 0, time, time)}
    set staterel sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state
    set sch [opm::schematic $repo $staterel]
    set key {}
    group PR1 {
        xschem load $sch
        set key [ase::session_key {*}[ase::design_of_path [file normalize $sch]]]
        catch {ase::session_close $key}
        ase::session_open $key [file join $repo $staterel]
        set st [ase::session_state $key]
        set rd [file join $::scratch bench]
        file mkdir $rd
        dict set st rundir $rd
        set outs [ase::state_get $st outputs]
        lappend outs [dict create name T_before expr $EX save 0 plot 1]
        dict set st outputs $outs
        ase::session_update $key $st
        set top [ase::ui::open $key sky130_tests_ase tb_bandgap ngspice_state1]
        update
        ase::ui::do_run $key
        set id [ase::session_getattr $key run_id]
        set rc [ase::wait $id]
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
        check "PR1 tb_bandgap runs on the registry ngspice" $rc 0
    }
    proc pr_cell {key name} {
        set top [ase::ui::window_for $key]
        set rows [ase::state_get [ase::session_state $key] outputs]
        set i 0
        foreach o $rows {
            if {[ase::state_get $o name] eq $name} {
                if {[catch {$top.body.outs.tv set $i value} v]} { return ERR:$v }
                return $v
            }
            incr i
        }
        return NOROW
    }
    group PR2 {
        set raw [ase::last_rawfile $key]
        set ref [calc::eval_text $EX $raw {}]
        set ::pr_ref $ref
        check "PR2 fixture: the Calculator's evaluator answers on the bench's results" \
            [list [dict get $ref ok] [dict get $ref kind]] {1 scalar}
        check "PR2 a row added BEFORE the run shows its number after the run" \
            [pr_cell $key T_before] [ase::format_value [format %.6e [dict get $ref value]]]
    }
    group PR3 {
        set top [ase::ui::window_for $key]
        ase::ui::outputs_tab $key measures
        ase::ui::output_editor $key -1
        update
        set w $top.edout
        $w.name insert 0 T_1pc_setl_BG
        $w.expr insert 0 $EX
        set ::ase::ui::edchk($key,plot) 1
        ase::ui::output_editor_ok $key
        update
        set rows [ase::state_get [ase::session_state $key] outputs]
        check "PR3 the row the user added lands in the Measures tree" \
            [expr {[llength $rows] - 1 in [ase::ui::measures_order $rows {} 0]}] 1
        check "PR3 added AFTER the run, it is blank until ~ is pressed (the reported symptom)" \
            [pr_cell $key T_1pc_setl_BG] {}
        catch {wviewer::close $key}
        update
        check "PR3 fixture: the viewer is down before the press" [wviewer::window_for $key] {}
        set ::po_echoes {}
        $top.strip.plot invoke
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
        check "PR3 after ~ it shows the Calculator's number" \
            [pr_cell $key T_1pc_setl_BG] [ase::format_value [format %.6e [dict get $::pr_ref value]]]
    }
    group PR4 {
        calc::open
        update
        .calc.buf delete 1.0 end
        .calc.buf insert end $EX
        calc::eval_click
        update
        set got [string trim [.calc.buf get 1.0 end]]
        puts "note: PR4 tb_bandgap calculator=$got outputs=[dict get $::pr_ref value] cell=[pr_cell $key T_1pc_setl_BG]"
        check "PR4 the Calculator window's Eval gives the Outputs path's double, full precision" \
            $got [dict get $::pr_ref value]
        set want NOTANUMBER:$got
        if {[string is double -strict $got]} { set want [format %.6e $got] }
        check "PR4 ...and the Value is %.6e of it" \
            [val [ase::session_getattr $key results] T_1pc_setl_BG] $want
        catch {calc::close}
    }
    group PR5 {
        check "PR5 ~ opened the viewer it found closed" \
            [expr {[wviewer::window_for $key] ne {}}] 1
        set gi [wviewer::auto_graph_index $key]
        set g [lindex [pcall dict get [wviewer::layout_for $key] graphs] $gi]
        if {[catch {dict get $g traces}]} { set g {traces {}} }
        set want {}
        foreach o [ase::state_get [ase::session_state $key] outputs] {
            if {[ase::state_get $o plot 0] eq {1} && [ase::output_is_plain [ase::state_get $o expr]]} {
                lappend want [ase::state_get $o expr]
            }
        }
        check "PR5 the auto graph holds exactly the ticked signal rows (derived from the state), and no measure" \
            [lmap tr [dict get $g traces] {dict get $tr expr}] $want
        check "PR5 fixture: the bench has ticked signal rows to plot" [expr {[llength $want] > 0}] 1
        check "PR5 nothing was said about plotting the scalar measures" \
            [lsearch -all -inline -glob $::po_echoes {*cannot auto-plot*}] {}
    }
    group PR6 {
        set top [ase::ui::window_for $key]
        check "PR6 the live ~ button runs plot_outputs for this session" \
            [$top.strip.plot cget -command] [list ase::ui::plot_outputs $key]
        set scr [bind $top.strip.plot <Enter>]
        set i [lsearch -exact $scr balloon_show]
        set tip [expr {$i < 0 ? {NO-TIP} : [lindex [lindex $scr [expr {$i + 2}]] 0]}]
        check "PR6 the live tip is the new label" $tip {Plot outputs and update values}
    }
    catch {wviewer::close $key}
    catch {ase::ui::close $key}
    catch {ase::session_close $key}
}

foreach a $::abortnames { puts "ABORTED band: $a" }
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
exit [expr {$fail ? 1 : 0}]
