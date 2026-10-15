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
#   PO6  nothing waveform ticked: the button says so; something ticked: it
#        does not
#   PO7  a ticked row refused for its analysis: the button SAYS the sentence
#   PO8  a FAILED last run (R-OUT13): ase::run_failed reads the log's footer;
#        every Value says the run failed; `~` says so and plots nothing; the
#        after-run callback says so; a Stop, a clean run and a run in flight
#        are not failures
#   PO9  a ticked row whose Value is a refusal sentence is not offered to the
#        viewer; a ticked row with no Value yet still is
#   PO10 an operating-point-only view filters nothing: a ticked scalar measure
#        is handed on, and auto_plot says the view has no sweep
#   PO11 an edit that renames a row and changes its expression together drops
#        the OLD name's Value as well as the new one's
# Bands (display arm only)
#   PR1  the real bench runs on the registry ngspice, pinned to its nominal
#        corner (ABSVAR 0, section tt) so the run converges every time
#   PR2  a row added BEFORE the run has its number after the run
#   PR3  a row added AFTER the run is blank until `~`, then shows its number
#   PR4  the Calculator window's Eval of the same text gives the same number,
#        full precision
#   PR5  with the viewer closed, `~` opens it and plots the ticked signals,
#        never the scalar measure, and says nothing about it
#   PR6  the live strip button runs plot_outputs and carries the new tip
#   PR7  a second `~`, pressed by a real Enter/press/release on the button with
#        the viewer UP, replaces the auto graph's traces rather than adding a
#        second copy
#   PR8  editing a row's expression blanks its Value (never the old
#        expression's number); `~` then shows the new expression's number
#   PR9  a ticked row whose Value is a refusal is not handed to the viewer by
#        `~`: no "cannot auto-plot" sentence repeats the Value cell
#   PR10 renaming a row and changing its expression in the dialog drops the
#        old name's Value
#   PF1  the SHIPPED Monte Carlo draw, seeded to one that stops the transient
#        ("Timestep too small", rc 1): the user is told the run failed and
#        where the log is, the status reads Error, every Value says the run
#        failed (never "has no transient analysis"), and `~` says it again
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
## The display-only bands, derived from this file's own `group` lines, so the
## skip line names every band it skips.
set fh [open [file normalize [info script]]]
set ::po_src [read $fh]
close $fh
set ::po_disp {}
foreach {- b} [regexp -all -inline -line {^\s*group\s+(P[RF][0-9]+)\s} $::po_src] {
    lappend ::po_disp $b
}

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
proc po_session {sub cell outs raw {an {}}} {
    if {$an eq {}} {
        set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 10m step 100u}}
    }
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
    puts $f "analyses [list $an]"
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
# PO6 -- NOTHING WAVEFORM TICKED
# =============================================================================
group PO6 {
    set key [po_session po6 tbpo {{name U expr vt(sq) save 0 plot 0}} 1]
    po_stub_autoplot
    set ::po_echoes {}
    set rc [pcall ase::ui::plot_outputs $key]
    po_unstub_autoplot
    check "PO6 nothing ticked: the button evaluates (1) and says no waveform output has Plot ticked" \
        [list $rc [expr {[ase::ui::lbl_plot_outputs_nowave] in $::po_echoes}]] {1 1}
    check "PO6 the sentence" [ase::ui::lbl_plot_outputs_nowave] {ase: no waveform output has Plot ticked}
    catch {ase::session_close $key}
    set key [po_session po6b tbpo $::PO_OUTS 1]
    po_stub_autoplot
    set ::po_echoes {}
    pcall ase::ui::plot_outputs $key
    po_unstub_autoplot
    check "PO6 control: with ticked waveforms the note is not said" \
        [expr {[ase::ui::lbl_plot_outputs_nowave] in $::po_echoes}] 0
    catch {ase::session_close $key}
}

# =============================================================================
# PO7 -- A REFUSED ROW'S SENTENCE IS SAID
# =============================================================================
## auto_plot runs for real here: its refusal sentence is said before any
## viewer is opened, and with every ticked row refused it opens none.
group PO7 {
    set key [po_session po7 tbpo {{name A expr vf(lp) save 0 plot 1}} 1]
    set why [ase::ui::plot_row_refusal vf(lp) [ase::plot_sim_type [ase::session_state $key]]]
    check "PO7 fixture: vf(lp) is refused on a transient view" [expr {$why ne {}}] 1
    set ::po_echoes {}
    set rc [pcall ase::ui::plot_outputs $key]
    set said "ase: cannot auto-plot 'vf(lp)': $why"
    check "PO7 the button says the refusal sentence, and not the nothing-ticked note" \
        [list $rc [expr {$said in $::po_echoes}] \
              [expr {[ase::ui::lbl_plot_outputs_nowave] in $::po_echoes}]] {1 1 0}
    check "PO7 ...and it is said exactly once" \
        [llength [lsearch -all -exact $::po_echoes $said]] 1
    catch {ase::session_close $key}
}

# =============================================================================
# PO8 -- A FAILED LAST RUN (R-OUT13)
# =============================================================================
## The log is written by the run's own producer (ase::run_log_write), so the
## footer read here is the one a real run leaves.
proc po_log {key exitcode} {
    set st [ase::session_state $key]
    set lf [[ase::backend_hook ngspice log_file] $st]
    set meta [dict create cell [dict get $st design cell] simulator ngspice \
                  t0 [clock milliseconds] started [clock seconds]]
    ase::run_log_write $lf $meta "doAnalyses: TRAN:  Timestep too small\nRUN-FAILED\n" $exitcode
    return $lf
}
group PO8 {
    set key [po_session po8 tbpo $::PO_OUTS 1]
    set lf [po_log $key 1]
    set f [pcall ase::run_failed $key]
    check "PO8 a footer reading exit 1 is a failed run, named with its log" \
        $f [dict create exit 1 log $lf]
    check "PO8 fixture: the raw is still there and has_results answers 1 (the reported shape)" \
        [ase::has_results $key] 1
    set res [ase::ui::results_from_disk $key]
    set want [dict create]
    foreach o $::PO_OUTS {
        dict set want [ase::ui::output_result_key $o] [ase::ui::lbl_run_failed_value $f]
    }
    check "PO8 every row's Value says the run failed" $res $want
    check "PO8 ...and none reads as though the circuit had no transient" \
        [lsearch -all -inline -glob [dict values $res] {*has no*}] {}
    check "PO8 the Value sentence" [ase::ui::lbl_run_failed_value $f] \
        {Run failed (exit 1); see the log}
    check "PO8 the notice names the exit code and the log" [ase::ui::lbl_run_failed $f] \
        "ase: simulation failed (exit 1); log: $lf"
    ase::session_setattr $key results {W old}
    po_stub_autoplot
    set ::po_echoes {}
    set rc [pcall ase::ui::plot_outputs $key]
    po_unstub_autoplot
    check "PO8 ~ answers 0, says the run failed (only that), and plots nothing" \
        [list $rc $::po_echoes [llength $::po_ap]] \
        [list 0 [list [ase::ui::lbl_run_failed $f]] 0]
    check "PO8 ...and the Values it leaves say the run failed" \
        [ase::session_getattr $key results] $want
    ## the after-run callback, on the exit code the run left
    ase::session_setattr $key results {W old}
    set ::execute(exitcode,last) 1
    set ::execute(data,last) {}
    set ::po_echoes {}
    pcall ase::ui::run_finished $key
    check "PO8 the after-run callback says the run failed" \
        [expr {[ase::ui::lbl_run_failed $f] in $::po_echoes}] 1
    check "PO8 ...and replaces the previous run's Values with the sentence" \
        [ase::session_getattr $key results] $want
    ## a Stop is not a failure
    ase::session_setattr $key stopped 1
    ase::session_setattr $key results {W old}
    set ::po_echoes {}
    pcall ase::ui::run_finished $key
    check "PO8 a Stopped run: run_failed answers {}, nothing says it failed, Values untouched" \
        [list [ase::run_failed $key] \
              [lsearch -all -inline -glob $::po_echoes {*failed*}] \
              [ase::session_getattr $key results]] {{} {} {W old}}
    ## the mark is set by Stop itself, BEFORE the kill whose EOF fires the
    ## callback: the kill is stood in for, and records what it saw
    ase::session_setattr $key stopped 0
    set ::execute(pipe,9077) po-fake
    ase::session_setattr $key run_id 9077
    rename ::kill_running_cmds ::po_krc_orig
    proc ::kill_running_cmds {args} {
        set ::po_kill [list $args [ase::session_getattr $::po_stopkey stopped 0]]
    }
    set ::po_stopkey $key
    set ::po_kill {}
    pcall ase::ui::do_stop $key
    rename ::kill_running_cmds {}
    rename ::po_krc_orig ::kill_running_cmds
    unset ::execute(pipe,9077)
    check "PO8 Stop marks the session stopped before it kills" $::po_kill {{9077 -9} 1}
    ase::session_setattr $key run_id {}
    ase::session_setattr $key stopped 0
    po_log $key 0
    check "PO8 control: a footer reading exit 0 is not a failure" [ase::run_failed $key] {}
    check "PO8 control: a clean run's Values are the results file's, not the sentence" \
        [val [ase::ui::results_from_disk $key] W] wave
    ## a run in flight: the header only, no footer yet
    ase::run_log_write $lf [dict create cell tbpo simulator ngspice] {} {}
    check "PO8 control: a run in flight (no footer yet) is not a failure" [ase::run_failed $key] {}
    file delete $lf
    check "PO8 control: no log at all is not a failure" [ase::run_failed $key] {}
    check "PO8 an unknown session answers {}" [pcall ase::run_failed po/none/none] {}
    catch {unset ::execute(exitcode,last)}
    catch {ase::session_close $key}
}

# =============================================================================
# PO9 -- A REFUSAL-VALUED TICKED ROW IS NOT OFFERED TO THE VIEWER
# =============================================================================
group PO9 {
    set outs [list {name W expr vt(lp) save 0 plot 1} \
                   {name P expr v(sq) save 1 plot 1} \
                   {name R expr {settlingTime(vt(nosuch), 2m, 1, 0, 0, 0, time, time)} save 0 plot 1} \
                   {name N expr vt(nosuch) save 0 plot 1} \
                   {name E expr {average(vt(lp))} save 0 plot 1}]
    set key [po_session po9 tbpo $outs 1]
    set res [ase::ui::results_from_disk $key]
    check "PO9 fixture: the results file answers R and N with a refusal sentence, W with wave" \
        [list [ase::ui::value_rank [val $res R]] [expr {[string trim [val $res R]] ne {}}] \
              [ase::ui::value_rank [val $res N]] [expr {[string trim [val $res N]] ne {}}] \
              [val $res W]] {1 1 1 1 wave}
    ase::session_setattr $key results $res
    set t [pcall ase::ui::plot_targets $key]
    check "PO9 the refusal-valued rows are not offered; the signal and the wave expression are" \
        [list [po_names $t] [po_nref $t]] {{W P} 0}
    set res2 [dict remove $res R N]
    ase::session_setattr $key results $res2
    check "PO9 control: with no Value yet the same rows ARE offered" \
        [po_names [pcall ase::ui::plot_targets $key]] {W P R N}
    ase::session_setattr $key results $res
    set ::po_echoes {}
    pcall ase::ui::plot_outputs $key
    check "PO9 ~ says nothing about the refused rows: the Value cell is the one place" \
        [lsearch -all -inline -regexp $::po_echoes {nosuch|unknown token}] {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

# =============================================================================
# PO10 -- AN OPERATING-POINT-ONLY VIEW FILTERS NOTHING
# =============================================================================
group PO10 {
    set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
    set outs [list {name P expr v(sq) save 1 plot 1} \
                   [list name T expr $::FX_EX save 0 plot 1]]
    set key [po_session po10 tbpo $outs 1 $an]
    check "PO10 fixture: the view is the operating point" \
        [ase::plot_sim_type [ase::session_state $key]] op
    ase::session_setattr $key results {P 1.0 T 2.5e-03}
    set t [pcall ase::ui::plot_targets $key]
    check "PO10 every ticked row is handed on, the scalar measure too, and nothing is refused" \
        [list [po_names $t] [po_nref $t]] {{P T} 0}
    set ::po_echoes {}
    pcall ase::ui::auto_plot $key
    check "PO10 ...and auto_plot says the view has no sweep" \
        [expr {{ase: op results have no sweep — nothing to auto-plot} in $::po_echoes}] 1
    catch {ase::session_close $key}
}

# =============================================================================
# PO11 -- A RENAME AND A NEW EXPRESSION TOGETHER
# =============================================================================
group PO11 {
    set res {A 1.0 B 2.0 X 3.0}
    check "PO11 renamed AND re-expressed: the old name's Value and the new name's both go" \
        [pcall ase::ui::results_drop_edited $res {name A expr e1} {name B expr e2}] {X 3.0}
    check "PO11 re-expressed under the same name: that Value goes" \
        [pcall ase::ui::results_drop_edited $res {name A expr e1} {name A expr e2}] {B 2.0 X 3.0}
    check "PO11 control: the same expression keeps every Value" \
        [pcall ase::ui::results_drop_edited $res {name A expr e1} {name B expr e1}] $res
    check "PO11 an unnamed row's key is its expression" \
        [pcall ase::ui::results_drop_edited {e1 1.0 X 3.0} {expr e1} {expr e2}] {X 3.0}
}

# =============================================================================
# THE DISPLAY ARM: the real bench
# =============================================================================
set NG /home/analog/dev/ngspice/build-ver_50/src/ngspice
if {!$GUI} {
    puts "SKIP: display-only bands [join $::po_disp ,] (no Tk on this arm)"
} elseif {![file executable $NG]} {
    puts "skip: [join $::po_disp ,] the registry ngspice is not at $NG"
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
        ## THE NOMINAL CORNER. The bench as shipped draws VCC with agauss and
        ## reads the mismatch section, and some draws stop its transient with
        ## "Timestep too small" (rc 1), which would make this arm a coin flip.
        ## The claims here are about the button and the two evaluators agreeing
        ## within one run, not about any draw, so the run is pinned: ABSVAR 0
        ## and section tt, which converges and repeats bit-exactly.
        set vs {}
        foreach v [ase::state_get $st variables] {
            if {[dict get $v name] eq {ABSVAR}} { dict set v value 0 }
            lappend vs $v
        }
        dict set st variables $vs
        set ms {}
        foreach m [ase::state_get $st models] {
            if {[dict get $m section] eq {tt_mm}} { dict set m section tt }
            lappend ms $m
        }
        dict set st models $ms
        ase::session_update $key $st
        set top [ase::ui::open $key sky130_tests_ase tb_bandgap ngspice_state1]
        update
        ase::ui::do_run $key
        set id [ase::session_getattr $key run_id]
        set rc [ase::wait $id]
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
        check "PR1 fixture: the run is pinned to the nominal corner" \
            [list [lsearch -all -inline -glob [ase::state_get [ase::session_state $key] variables] {name ABSVAR value 0}] \
                  [lmap m [ase::state_get [ase::session_state $key] models] {dict get $m section}]] \
            [list {{name ABSVAR value 0}} tt]
        set why {}
        if {$rc != 0} {
            set lf [file join $rd tb_bandgap_ase.log]
            if {![catch {open $lf} fh]} {
                set why [lsearch -all -inline -regexp [split [read $fh] \n] {(?i)too small|aborted|error}]
                close $fh
            }
        }
        check "PR1 tb_bandgap runs on the registry ngspice" [list $rc $why] {0 {}}
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
        set ::pr_want $want
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
    ## The auto graph's trace exprs and the viewer's graph count, or sentinels.
    proc pr_auto {key} {
        set gi [wviewer::auto_graph_index $key]
        if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return [list ERR:$gs ERR] }
        set g [lindex $gs $gi]
        if {[catch {dict get $g traces} trs]} { set trs {} }
        return [list [lmap tr $trs {dict get $tr expr}] [llength $gs]]
    }
    ## A real click on a Tk button: Enter, press and release with coordinates,
    ## then Leave to cancel the tooltip the Enter armed.
    proc pr_click {b} {
        event generate $b <Enter> -x 5 -y 5
        event generate $b <ButtonPress-1> -x 5 -y 5
        event generate $b <ButtonRelease-1> -x 5 -y 5
        event generate $b <Leave>
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
    }
    group PR7 {
        set top [ase::ui::window_for $key]
        check "PR7 fixture: the viewer is UP before the second press" \
            [expr {[wviewer::window_for $key] ne {}}] 1
        set before [pr_auto $key]
        check "PR7 fixture: the auto graph already holds the ticked signals" \
            [lindex $before 0] $::pr_want
        ## the row's Value is taken away first, so only a press that really
        ## ran the button can bring it back
        set res [ase::session_getattr $key results]
        dict unset res T_1pc_setl_BG
        ase::session_setattr $key results $res
        ase::ui::refresh_output_values $key
        check "PR7 fixture: the row is blank before the click" [pr_cell $key T_1pc_setl_BG] {}
        set ::po_echoes {}
        pr_click $top.strip.plot
        set after [pr_auto $key]
        check "PR7 a second ~ with the viewer up replaces the traces: no second copy, no new graph" \
            $after [list $::pr_want [lindex $before 1]]
        check "PR7 ...the click really ran the button (the Value is back) and nothing was refused" \
            [list [pr_cell $key T_1pc_setl_BG] \
                  [lsearch -all -inline -glob $::po_echoes {*cannot auto-plot*}]] \
            [list [ase::format_value [format %.6e [dict get $::pr_ref value]]] {}]
    }
    group PR8 {
        set top [ase::ui::window_for $key]
        set rows [ase::state_get [ase::session_state $key] outputs]
        set idx -1
        set i 0
        foreach o $rows {
            if {[ase::state_get $o name] eq {T_1pc_setl_BG}} { set idx $i }
            incr i
        }
        set ex10 {settlingTime(vt(vbg), 100u, 10, 0, 0, 0, time, time)}
        set ref10 [calc::eval_text $ex10 [ase::last_rawfile $key] {}]
        check "PR8 fixture: the 10% band answers a different number from the 1% band" \
            [expr {[dict get $ref10 value] != [dict get $::pr_ref value]}] 1
        set old [pr_cell $key T_1pc_setl_BG]
        check "PR8 fixture: the row shows the 1% number before the edit" \
            [expr {$old ne {}}] 1
        ase::ui::output_editor $key $idx
        update
        set w $top.edout
        $w.expr delete 0 end
        $w.expr insert 0 $ex10
        ase::ui::output_editor_ok $key
        update
        check "PR8 an edited expression's Value is blank, never the old expression's number" \
            [list [pr_cell $key T_1pc_setl_BG] [val [ase::session_getattr $key results] T_1pc_setl_BG]] \
            {{} ABSENT}
        pr_click $top.strip.plot
        check "PR8 after ~ it shows the new expression's number" \
            [pr_cell $key T_1pc_setl_BG] [ase::format_value [format %.6e [dict get $ref10 value]]]
    }
    group PR9 {
        set top [ase::ui::window_for $key]
        set st [ase::session_state $key]
        set rex {settlingTime(vt(nosuch), 100u, 1, 0, 0, 0, time, time)}
        set outs [ase::state_get $st outputs]
        lappend outs [dict create name R_refused expr $rex save 0 plot 1]
        dict set st outputs $outs
        ase::session_update $key $st
        ase::ui::populate $key
        set ::po_echoes {}
        pr_click $top.strip.plot
        set v [pr_cell $key R_refused]
        check "PR9 fixture: the row's Value is a refusal sentence" \
            [list [ase::ui::value_rank $v] [expr {[string trim $v] ne {}}]] {1 1}
        check "PR9 ~ hands it to no viewer: nothing repeats the Value cell as an error" \
            [lsearch -all -inline -regexp $::po_echoes {nosuch|unknown token|cannot auto-plot}] {}
        check "PR9 ...and the ticked signals are still plotted" [lindex [pr_auto $key] 0] $::pr_want
    }
    group PR10 {
        set top [ase::ui::window_for $key]
        set rows [ase::state_get [ase::session_state $key] outputs]
        set idx -1
        set i 0
        foreach o $rows {
            if {[ase::state_get $o name] eq {T_1pc_setl_BG}} { set idx $i }
            incr i
        }
        check "PR10 fixture: the row has a Value before the edit" \
            [expr {[val [ase::session_getattr $key results] T_1pc_setl_BG] ne {ABSENT}}] 1
        ase::ui::output_editor $key $idx
        update
        set w $top.edout
        $w.name delete 0 end
        $w.name insert 0 T_renamed
        $w.expr delete 0 end
        $w.expr insert 0 $EX
        ase::ui::output_editor_ok $key
        update
        set res [ase::session_getattr $key results]
        check "PR10 renamed and re-expressed together: neither the old name nor the new holds a Value" \
            [list [val $res T_1pc_setl_BG] [val $res T_renamed] [pr_cell $key T_renamed]] {ABSENT ABSENT {}}
    }
    ## THE SHIPPED DRAW, SEEDED.  The committed state's own variables and
    ## models (ABSVAR 0.03, VCC by agauss, section tt_mm), plus `.options
    ## seed=35`, a draw that stops this transient with "Timestep too small".
    group PF1 {
        set fh [open [file join $repo $staterel]]
        set shipped [read $fh]
        close $fh
        set st [ase::session_state $key]
        dict set st variables [dict get $shipped variables]
        dict set st models [dict get $shipped models]
        set op [ase::state_get $st options]
        lappend op [dict create name seed value 35]
        dict set st options $op
        ase::session_update $key $st
        set top [ase::ui::window_for $key]
        set ::po_echoes {}
        ase::ui::do_run $key
        set rc [ase::wait [ase::session_getattr $key run_id]]
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
        set lf [file join $rd tb_bandgap_ase.log]
        set why {}
        if {![catch {open $lf} fh]} {
            set why [lsearch -all -inline -glob [split [read $fh] \n] {*Timestep too small*}]
            close $fh
        }
        check "PF1 fixture: the shipped draw at seed 35 stops the transient (rc 1, Timestep too small)" \
            [list $rc [expr {[llength $why] > 0}]] {1 1}
        check "PF1 fixture: the raw is still newer than the deck, so has_results answers 1" \
            [ase::has_results $key] 1
        set f [ase::run_failed $key]
        check "PF1 run_failed names the exit code and the log" $f [dict create exit 1 log $lf]
        set said [ase::ui::lbl_run_failed $f]
        check "PF1 the user is told the run failed, and where the log is" \
            [expr {$said in $::po_echoes}] 1
        set stat {}
        catch {set stat [$top.status.stat cget -text]}
        check "PF1 the status segment reads Error" $stat {Status: Error}
        set rows [ase::state_get [ase::session_state $key] outputs]
        set cells {}
        foreach i [ase::ui::measures_order $rows {} 0] {
            lappend cells [$top.body.outs.tv set $i value]
        }
        set one [ase::ui::lbl_run_failed_value $f]
        check "PF1 every Measures Value says the run failed" \
            [lsort -unique $cells] [list $one]
        puts "note: PF1 the user sees: [list $said] status=[list $stat] value=[list $one]"
        set ::po_echoes {}
        pr_click $top.strip.plot
        set cells2 {}
        foreach i [ase::ui::measures_order $rows {} 0] {
            lappend cells2 [$top.body.outs.tv set $i value]
        }
        check "PF1 ~ after the failed run says it failed, never that the result has no transient" \
            [list [expr {$said in $::po_echoes}] \
                  [lsearch -all -inline -regexp [concat $::po_echoes $cells2] {has no|cannot auto-plot}]] {1 {}}
        check "PF1 ...and the Values still say the run failed" [lsort -unique $cells2] [list $one]
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
