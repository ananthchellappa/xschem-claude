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
#   PO1  the strip's tip says what the button does, not the viewer's menu path,
#        and names the Ctrl-click (R-OUT16)
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
#   PO12 a failed run says one line, the failure, and no 'finished (exit'
#        line; a Stop, a clean run, a callback that does not take the line and
#        a run with no callback each say today's finish line once
#   PO13 a run started after a Stop clears the mark: its failure is said, and
#        every Value says the run failed
#   PO14 `~` and the run-end auto-plot follow the viewer's plot mode
#        (R-OUT14): single-plot puts every row in one auto strip as before;
#        multi-plot gives each row its own auto strip, newest on top; a second
#        press replaces; surplus auto strips are removed and missing ones
#        inserted, a hand-built strip is untouched and the target follows it;
#        with the viewer closed the viewer's default mode decides; a Direct
#        Plot never reuses any auto strip
#   PO15 the auto strips' bookkeeping: when auto strips are removed or
#        inserted, the target strip and the trace highlights on hand-built
#        strips move with their strips (never clamped onto a neighbour); with
#        no auto strip, multi-plot inserts the new ones at the top; a Direct
#        Plot whose target is ANY auto strip, not only the first, lands
#        elsewhere
#   PO16 the plot destination drop-down (R-OUT15): the four labels are the
#        viewer's codes; set_plot_dest writes the state, dirties, logs once on
#        a change, stores Replace as the empty default, refuses junk; the key
#        saves and loads and is never written at its default (every committed
#        .state file, with a control); Replace empties the target subwindow
#        (hand strip included) keeping the run's zoom, as one undo step;
#        Append adds without clearing (single: into the target strip, auto
#        included; multi: new strips on top); New SubWin adds a targeted
#        subwindow and keeps the old plot; New Win a tab; a viewer the press
#        opens is already new; zero rows empty only a Replace target holding an
#        auto strip; a failed run plots nothing under any choice
#   PO17 the evaluate-only half (R-OUT16): ase::ui::evaluate_outputs
#        re-evaluates every Value exactly as `~` does and never asks for a
#        plot; no results, a failed run and an unknown session answer 0 with
#        `~`'s own sentences
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
#   PR11 R-OUT14 on the real viewer: in multi-plot a real click on `~` gives
#        each ticked signal its own strip, newest on top; the run-end
#        auto-plot of a real run replaces them; back in single-plot `~` puts
#        them in one strip again and the extra strips go
#   PR12 R-OUT15 on the real bench: each choice picked by a real
#        <<ComboboxSelected>> on the status-bar drop-down, `~` pressed by a real
#        click, the viewer's tabs / subwindows / strips read back (and the
#        canvas rects); the run-end auto-plot of a real run under New SubWin
#   PR13 R-OUT16 on the real button: a real Ctrl-click (Enter, press and
#        release carrying the Control bit) with the viewer UP brings the
#        blanked Value back and leaves the viewer's whole layout and tab list
#        byte-identical; with the viewer CLOSED it opens none; a plain click
#        afterwards still plots (the control)
#   PV1  issue 1733, R1 (the same data): a zoomed X survives a real Direct Plot
#        of the session's unchanged raw, single-plot (the strip it did not
#        touch shows exactly what it showed) and multi-plot (a new strip joins
#        the zoomed X window)
#   PV2  R2 (new data): the raw rewritten (a same-size rewrite, the mtime
#        moved), the axes the user moved are kept and the others fitted to the
#        new data; a new sweep that does not reach the kept window fits X (and
#        its control that does); an ac file where the tran was drops the X and
#        a moved Y with it (another analysis is another plot); a dc file whose
#        sweep runs over the kept window's own numbers drops them too, where
#        only x_same (not the overlap rule) can drop the X
#   PV3  R3: `~` under Replace, same data and after a re-run, single- and
#        multi-plot, gives the strips the run's rows with the view kept; Append
#        likewise
#   PV4  R4: a Location-bar load drops the record, so the next Direct Plot on
#        the attached file again is new data; a raw read straight into the
#        viewer moves the current database and the verdict sees it; closing the
#        viewer drops the record
#   PV5  R3 across subwindows (the issue 1733 review): `~` under Replace into
#        one subwindow leaves a subwindow it did not touch exactly as shown,
#        and the strips it re-plots take their view from their own
#        subwindow's old strips only (a row unticked; single-plot strip
#        replaced in multi-plot); `~` under New SubWin keeps every subwindow
#        already there, the same data and after a re-run; a re-run of another
#        analysis under Replace fits the strip in X and Y
#   PV6  R3 with nothing ticked: `~` under Replace empties the target
#        subwindow (auto_plot's zero-rows branch, no attach) and the other
#        subwindow shows exactly what it showed, both axes
#        (PV is not under the ngspice gate: its raws are written by the suite)
#   PF1  the SHIPPED bench and Monte Carlo draw (seed 35) with `reltol=1e-12`,
#        which stops the transient ("Timestep too small", rc 1) after the op
#        point was written: the user is told the run failed and
#        where the log is, the status reads Error, every Value says the run
#        failed (never "has no transient analysis"), and `~` says it again
#
# RED PROOFS for PO14 (reworked) / PO16 / PR12, measured 2026-10-15, each
# reverted to green:
#   V4  sw_clear_graphs clears the whole tab -> PO14 (x6), PO16i
#   V5  auto_plot_strips unscoped (whole tab) -> PO14 (x6), PO16g (x3), PO16i (x2)
#   V6  ase::plot_dest_of always Replace -> PO16b (x2), c, e (x2), g (x3), i (x2), h (x2)
#   V7  New SubWin even when the press opened the viewer -> PO16j ONLY
#   V8  Replace stored as `replace`, not {} -> PO16b clean-session row ONLY
#   V9  set_plot_dest logs on every call -> PO16b (x2)
#   V10 plot_dest not in ase::omit_if_empty -> PO16c, PO16f
#   V13 plot_sites ignores `autook` -> PO16e (x2), g (x3), i
#   V15 the survivor loses its view -> PO16d zoom row ONLY
#   V16 clear_subwin pushes no undo point -> PO16d undo row ONLY
#   V18 zero rows: Replace empties a subwindow with no auto strip -> PO16i ONLY
#   V19 auto_plot ignores the destination (display arm) -> PO16 (x8), PR12 (x5)
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
    check "PO1 the ~ tip says what the button does" $tip {Plot outputs and update values (Ctrl-click: values only)}
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
# PO17 -- CTRL-CLICK: EVALUATE ONLY (R-OUT16)
# =============================================================================
group PO17 {
    check "PO17 signature (info args)" [pcall info args ase::ui::evaluate_outputs] key
    set key [po_session po17 tbpo $::PO_OUTS 1]
    ase::session_setattr $key results [list W old P old U old]
    set ref [calc::eval_text $::FX_EX $::fixture {}]
    po_stub_autoplot
    set ::po_echoes {}
    set rc [pcall ase::ui::evaluate_outputs $key]
    po_unstub_autoplot
    set res [ase::session_getattr $key results]
    check "PO17 evaluate-only answers 1 and the Values are exactly what ~ and opening the session read" \
        [list $rc [expr {$res eq [ase::ui::results_from_disk $key]}] [val $res T]] \
        [list 1 1 [format %.6e [dict get $ref value]]]
    check "PO17 ...and it never asks for a plot, and says nothing about plotting" \
        [list [llength $::po_ap] [lsearch -all -inline -regexp $::po_echoes {plot|viewer}]] {0 {}}
    ## the control: the same session, the same stub, the plain button does ask
    ase::session_setattr $key results [list W old]
    po_stub_autoplot
    pcall ase::ui::plot_outputs $key
    po_unstub_autoplot
    check "PO17 (control) the plain ~ on the same session does ask for the plot, once" \
        [llength $::po_ap] 1
    catch {ase::session_close $key}
    set key [po_session po17b tbpo $::PO_OUTS 0]
    ase::session_setattr $key results {W old}
    po_stub_autoplot
    set ::po_echoes {}
    set rc [pcall ase::ui::evaluate_outputs $key]
    po_unstub_autoplot
    check "PO17 no results: 0, ~'s own sentence, the Values left alone, no plot" \
        [list $rc $::po_echoes [ase::session_getattr $key results] [llength $::po_ap]] \
        [list 0 [list [ase::ui::lbl_plot_outputs_none]] {W old} 0]
    catch {ase::session_close $key}
    check "PO17 an unknown session answers 0 and raises nothing" \
        [pcall ase::ui::evaluate_outputs po/none/none] 0
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
# PO12 -- A FAILED RUN SAYS ONE LINE (R-OUT13)
# =============================================================================
## Driven through ase::run_done itself, the completion hook a real run fires,
## with the window's own after-run callback: what the CIW receives is counted.
proc po_done {key ec callback} {
    set st [ase::session_state $key]
    set lf [[ase::backend_hook ngspice log_file] $st]
    set meta [dict create cell [dict get $st design cell] simulator ngspice \
                  t0 [clock milliseconds] started [clock seconds]]
    set ::execute(exitcode,last) $ec
    set ::execute(data,last) "doAnalyses: TRAN:  Timestep too small\nRUN-FAILED\n"
    set ::po_echoes {}
    set ::po_done_rc [pcall ase::run_done $lf $st $callback $meta]
    catch {unset ::execute(exitcode,last)}
    catch {unset ::execute(data,last)}
    return $lf
}
proc po_count {pat} { llength [lsearch -all -glob $::po_echoes $pat] }
proc po_cb {} { lappend ::po_echoes CALLBACK }
group PO12 {
    set key [po_session po12 tbpo $::PO_OUTS 1]
    set cb [list ase::ui::run_finished $key]
    po_done $key 1 $cb
    check "PO12 a failed run: exactly one failure line, and no 'finished (exit' line" \
        [list [po_count {ase: simulation failed (exit 1); log: *}] [po_count {*finished (exit*}]] {1 0}
    ase::session_setattr $key stopped 1
    po_done $key 137 $cb
    check "PO12 a Stopped run: today's finish line once, and no failure line" \
        [list [po_count {ase: simulation finished (exit 137), log: *}] [po_count {*failed*}]] {1 0}
    ase::session_setattr $key stopped 0
    set lf [po_done $key 0 po_cb]
    check "PO12 control: a clean run says today's finish line once, before its callback" \
        [lsearch -all -inline -regexp $::po_echoes {finished \(exit|failed|CALLBACK}] \
        [list "ase: simulation finished (exit 0), log: $lf" CALLBACK]
    po_done $key 1 po_cb
    check "PO12 control: a callback that does not take the line still gets it said, once" \
        [list [po_count {ase: simulation finished (exit 1), log: *}] [po_count {*failed*}]] {1 0}
    po_done $key 1 {}
    check "PO12 control: a run with no callback says today's finish line once" \
        [list [po_count {ase: simulation finished (exit 1), log: *}] [po_count {*failed*}]] {1 0}
    check "PO12 nothing is left pending after a run" [ase::run_finish_note_take] {}
    catch {ase::session_close $key}
}

# =============================================================================
# PO13 -- A NEW RUN CLEARS THE PREVIOUS RUN'S STOP (R-OUT13)
# =============================================================================
## Stop marks the session; the next run must not inherit the mark, or its
## failure would read as a Stop and say nothing. The kill is stood in for.
group PO13 {
    set key [po_session po13 tbpo $::PO_OUTS 1]
    set ::execute(pipe,9077) po-fake
    ase::session_setattr $key run_id 9077
    rename ::kill_running_cmds ::po_krc_orig
    proc ::kill_running_cmds {args} {}
    pcall ase::ui::do_stop $key
    rename ::kill_running_cmds {}
    rename ::po_krc_orig ::kill_running_cmds
    unset ::execute(pipe,9077)
    check "PO13 fixture: Stop left the session marked stopped" \
        [ase::session_getattr $key stopped 0] 1
    pcall ase::ui::run_started $key 9078
    ase::session_setattr $key results {W old}
    po_done $key 1 [list ase::ui::run_finished $key]
    check "PO13 the next run fails: run_failed names exit 1" \
        [pcall dict get [ase::run_failed $key] exit] 1
    check "PO13 ...and the failure notice is said, once" \
        [po_count {ase: simulation failed (exit 1); log: *}] 1
    set want [dict create]
    foreach o $::PO_OUTS {
        dict set want [ase::ui::output_result_key $o] {Run failed (exit 1); see the log}
    }
    check "PO13 ...and every Value reads 'Run failed (exit 1); see the log'" \
        [ase::session_getattr $key results] $want
    ase::session_setattr $key run_id {}
    catch {ase::session_close $key}
}

# =============================================================================
# PO14 -- `~` AND THE RUN-END AUTO-PLOT FOLLOW THE VIEWER'S PLOT MODE (R-OUT14)
# =============================================================================
## The user (2026-10-15): "The plot button (~) functionality ignores the
## multi/single plot mode of the already-up Waveform Viewer and does a single
## plot mode - dumping all signals onto a single strip."
## The real ase::ui::auto_plot and the real wviewer model procs run here; only
## the viewer's Tk doors (open, attach_raw, regenerate, the fold, the trace
## add) are stood in for, and the add records which strip each signal was
## handed to and puts it in the model, as the real one does.
proc po14_stub {} {
    set ::po14_up 0
    set ::po14_adds {}
    foreach p {open window_for attach_raw regenerate capture_live_view_state
               add_trace repair_currents} {
        rename ::wviewer::$p ::po14_orig_$p
    }
    proc ::wviewer::open {token} {
        if {!$::po14_up} {
            dict set ::wviewer::layouts $token \
                [dict create sharedx 0 graphs [list [wviewer::empty_graph]]]
            dict set ::wviewer::windows $token top .po14
            set ::wviewer::mode($token) [wviewer::default_plot_mode]
            set ::wviewer::target($token) 0
            set ::po14_up 1
        }
        return 1
    }
    proc ::wviewer::window_for {token} { expr {$::po14_up ? {.po14} : {}} }
    proc ::wviewer::attach_raw {args} { return {} }
    proc ::wviewer::regenerate {args} { return {} }
    proc ::wviewer::capture_live_view_state {args} { return 0 }
    proc ::wviewer::repair_currents {token exprs} { list $exprs {} }
    proc ::wviewer::add_trace {token gi rpn args} {
        lappend ::po14_adds [list $gi $rpn]
        set gs [dict get [wviewer::layout_for $token] graphs]
        set G [lindex $gs $gi]
        dict lappend G traces [dict create expr $rpn]
        wviewer::set_graphs $token [lreplace $gs $gi $gi $G]
        return {}
    }
}
proc po14_unstub {key} {
    foreach p {open window_for attach_raw regenerate capture_live_view_state
               add_trace repair_currents} {
        rename ::wviewer::$p {}
        rename ::po14_orig_$p ::wviewer::$p
    }
    catch {dict unset ::wviewer::layouts $key}
    catch {dict unset ::wviewer::windows $key}
    catch {unset ::wviewer::mode($key)}
    catch {unset ::wviewer::target($key)}
}
## The viewer's strips as {auto {trace exprs}} pairs, top first, or a sentinel.
proc po14_strips {key} {
    if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return ERR:$gs }
    set out {}
    foreach G $gs {
        if {[catch {lmap t [wviewer::dget $G traces {}] {dict get $t expr}} ex]} {
            return ERR:$ex
        }
        lappend out [list [wviewer::dget $G auto 0] $ex]
    }
    return $out
}
## Tick exactly the named rows' Plot box.
proc po14_plot {key args} {
    set st [ase::session_state $key]
    set outs {}
    foreach o [ase::state_get $st outputs] {
        dict set o plot [expr {[ase::state_get $o name] in $args}]
        lappend outs $o
    }
    dict set st outputs $outs
    ase::session_update $key $st
}
group PO14 {
    set outs {{name A expr v(sq) save 1 plot 1} {name B expr v(lp) save 1 plot 1}
              {name C expr v(ramp) save 1 plot 1}}
    set key [po_session po14 tbpo $outs 1]
    po14_stub
    set saved_default [expr {[info exists ::wviewer_plot_mode] ? $::wviewer_plot_mode : {}}]
    set ::wviewer_plot_mode single
    set ::po_echoes {}
    pcall ase::ui::plot_outputs $key
    check "PO14 fixture: ~ handed all three ticked rows to the viewer and nothing was refused" \
        [list [llength $::po14_adds] [lsearch -all -inline -glob $::po_echoes {*cannot*}]] {3 {}}
    check "PO14 single-plot (the viewer's default): every row in ONE strip, as before" \
        [po14_strips $key] {{1 {v(sq) v(lp) v(ramp)}}}

    ## the viewer is UP and the user switches it to multi-plot
    set ::wviewer::mode($key) multi
    set ::po14_adds {}
    pcall ase::ui::plot_outputs $key
    check "PO14 multi-plot: ~ gives each row its own strip, newest on top (the reported defect)" \
        [po14_strips $key] {{1 v(ramp)} {1 v(lp)} {1 v(sq)}}
    check "PO14 ...each signal handed to a different strip" \
        [llength [lsort -unique [lmap a $::po14_adds {lindex $a 0}]]] 3
    pcall ase::ui::plot_outputs $key
    check "PO14 a second ~ in multi-plot REPLACES: the same three strips, no second copy" \
        [po14_strips $key] {{1 v(ramp)} {1 v(lp)} {1 v(sq)}}

    ## a strip the user built by hand, in a SECOND subwindow (R-OUT15: under
    ## the default Replace `~` empties the TARGET subwindow, so a strip it must
    ## not touch lives in another one). The target stays on subwindow 1.
    set gs [lmap g [dict get [wviewer::layout_for $key] graphs] {dict replace $g sw 1}]
    lappend gs [dict create traces [list [dict create expr v(hand)]] logx 0 logy 0 \
                    x1 {} x2 {} y1 {} y2 {} sw 2]
    wviewer::set_graphs $key $gs
    set ::wviewer::target($key) 0
    po14_plot $key A B
    pcall ase::ui::plot_outputs $key
    check "PO14 one row fewer: the surplus auto strip is REMOVED, the hand strip in the other subwindow is untouched" \
        [po14_strips $key] {{1 v(lp)} {1 v(sq)} {0 v(hand)}}
    check "PO14 ...the two subwindows survive, and the target is still in the replotted one" \
        [list [lmap g [dict get [wviewer::layout_for $key] graphs] {wviewer::dget $g sw -}] \
              [wviewer::sw_index [dict get [wviewer::layout_for $key] graphs] [wviewer::target_index $key]]] \
        {{1 1 2} 0}
    po14_plot $key A B C
    pcall ase::ui::plot_outputs $key
    check "PO14 one row more: a strip is inserted above the auto strips, the other subwindow untouched" \
        [po14_strips $key] {{1 v(ramp)} {1 v(lp)} {1 v(sq)} {0 v(hand)}}

    ## the run-end path (run_finished -> after idle -> auto_plot_idle)
    set ::po14_adds {}
    pcall ase::ui::auto_plot_idle $key
    check "PO14 the run-end auto-plot follows the mode too: one strip per row, replaced" \
        [list [po14_strips $key] [llength [lsort -unique [lmap a $::po14_adds {lindex $a 0}]]]] \
        [list {{1 v(ramp)} {1 v(lp)} {1 v(sq)} {0 v(hand)}} 3]

    ## nothing ticked: ONE cleared auto strip is left, the rest go
    po14_plot $key
    pcall ase::ui::plot_outputs $key
    check "PO14 nothing ticked in multi-plot: one empty auto strip remains, the hand strip is untouched" \
        [po14_strips $key] {{1 {}} {0 v(hand)}}

    ## back to single-plot
    po14_plot $key A B C
    set ::wviewer::mode($key) multi
    pcall ase::ui::plot_outputs $key
    set ::wviewer::mode($key) single
    pcall ase::ui::plot_outputs $key
    check "PO14 switched back to single-plot: the rows share ONE auto strip again, no blank bands" \
        [po14_strips $key] {{1 {v(sq) v(lp) v(ramp)}} {0 v(hand)}}

    ## the viewer NOT up: the viewer's own default mode decides
    po14_unstub $key
    po14_stub
    set ::wviewer_plot_mode multi
    pcall ase::ui::plot_outputs $key
    check "PO14 viewer closed, default mode multi: ~ opens it with one strip per row" \
        [po14_strips $key] {{1 v(ramp)} {1 v(lp)} {1 v(sq)}}
    po14_unstub $key
    po14_stub
    set ::wviewer_plot_mode single
    pcall ase::ui::plot_outputs $key
    check "PO14 viewer closed, default mode single: ~ opens it with one strip" \
        [po14_strips $key] {{1 {v(sq) v(lp) v(ramp)}}}
    po14_unstub $key
    if {$saved_default eq {}} { unset -nocomplain ::wviewer_plot_mode } \
    else { set ::wviewer_plot_mode $saved_default }
    catch {ase::session_close $key}

    ## a Direct Plot never reuses ANY auto strip, not only the first
    check "PO14 empty_graph_indices offers no strip carrying the auto marker" \
        [wviewer::empty_graph_indices [list {traces {} auto 1} {traces {}} {traces {} auto 1}] 0] {1}
}

# =============================================================================
# PO15 -- THE AUTO STRIPS' BOOKKEEPING (R-OUT14)
# =============================================================================
## PO14 drives the whole `~` gesture; these rows drive wviewer::auto_plot_strips
## and wviewer::plot_signals directly on layouts chosen so that each piece of
## bookkeeping has an answer only it gives. PO14's "the target followed the hand
## strip" row cannot tell a target that moved from one that was clamped there,
## because its hand strip is the LAST strip; here the target sits on a hand
## strip with another one below it.
## A hand-built strip holding one trace, and an auto strip holding one.
proc po15_hand {ex} {
    dict create traces [list [dict create expr $ex]] logx 0 logy 0 \
        x1 {} x2 {} y1 {} y2 {}
}
proc po15_auto {ex} { dict merge [po15_hand $ex] [dict create auto 1] }
## Install a layout under `token` with the window's mode, target strip and
## trace-highlight set, as wviewer::open would leave them.
proc po15_lay {token mode gs tgt hl} {
    dict set ::wviewer::layouts $token [dict create sharedx 0 graphs $gs]
    dict set ::wviewer::windows $token top .po15
    set ::wviewer::mode($token) $mode
    set ::wviewer::target($token) $tgt
    set ::wviewer::wavehl($token) $hl
}
proc po15_drop {token} {
    catch {dict unset ::wviewer::layouts $token}
    catch {dict unset ::wviewer::windows $token}
    foreach v {mode target wavehl} { catch {unset ::wviewer::${v}($token)} }
}
## The layout as one letter per strip: A = auto, H = hand, top first.
proc po15_shape {token} {
    if {[catch {dict get [wviewer::layout_for $token] graphs} gs]} { return ERR:$gs }
    join [lmap G $gs {expr {[wviewer::dget $G auto 0] eq {1} ? {A} : {H}}}] {}
}
group PO15 {
    set tk po15tok
    ## {h0, auto, auto, auto, h4, h5} with the target on h4: one signal in
    ## multi-plot keeps the first auto strip and removes the other two, so h4
    ## becomes strip 2. A target left at 4 would clamp to 3 (h5), not 2.
    po15_lay $tk multi [list [po15_hand v(h0)] [po15_auto v(x)] [po15_auto v(y)] \
                            [po15_auto v(z)] [po15_hand v(h4)] [po15_hand v(h5)]] 4 {}
    set r [pcall wviewer::auto_plot_strips $tk 1]
    check "PO15 removal: one signal lands in the one auto strip kept" \
        [list $r [po15_shape $tk]] {1 HAHH}
    check "PO15 removal: the target strip moves from h4 to its new index 2, not clamped onto h5" \
        [list [pcall wviewer::target_index $tk] \
             [pcall dict get [lindex [dict get [wviewer::layout_for $tk] graphs] 2] traces]] \
        [list 2 [list [dict create expr v(h4)]]]

    ## the same removal, with a highlight on h4: it follows h4 to strip 2
    po15_lay $tk multi [list [po15_hand v(h0)] [po15_auto v(x)] [po15_auto v(y)] \
                            [po15_auto v(z)] [po15_hand v(h4)] [po15_hand v(h5)]] 0 \
        {{4 0 2} {0 0 1}}
    pcall wviewer::auto_plot_strips $tk 1
    check "PO15 removal: a trace highlight on h4 moves with h4 to strip 2; one on h0 stays" \
        [pcall wviewer::wave_hilights $tk] {{2 0 2} {0 0 1}}

    ## {h0, h1}, no auto strip, multi-plot, two signals: the two new auto
    ## strips go at the TOP (multi-plot puts new strips at the top), so the
    ## target on h0 moves to 2 and a highlight on h1 moves to 3
    po15_lay $tk multi [list [po15_hand v(h0)] [po15_hand v(h1)]] 0 {{1 0 3}}
    set r [pcall wviewer::auto_plot_strips $tk 2]
    check "PO15 insert with no auto strip: the new auto strips are 0 and 1, newest signal on top" \
        [list $r [po15_shape $tk] [pcall wviewer::auto_graph_indices $tk]] \
        {{1 0} AAHH {0 1}}
    check "PO15 insert with no auto strip: the target follows h0 to strip 2" \
        [pcall wviewer::target_index $tk] 2
    check "PO15 insert with no auto strip: a trace highlight on h1 follows it to strip 3" \
        [pcall wviewer::wave_hilights $tk] {{3 0 3}}

    ## {h0, auto, h2}, multi-plot, three signals: two auto strips are inserted
    ## above the existing one, so h2 becomes strip 4 and h0 stays at 0
    po15_lay $tk multi [list [po15_hand v(h0)] [po15_auto v(x)] [po15_hand v(h2)]] 2 \
        {{2 0 1} {0 0 2}}
    set r [pcall wviewer::auto_plot_strips $tk 3]
    check "PO15 insert above the auto strip: HAAAH, and the target follows h2 to strip 4" \
        [list $r [po15_shape $tk] [pcall wviewer::target_index $tk]] {{3 2 1} HAAAH 4}
    check "PO15 insert above the auto strip: a highlight on h2 follows it to 4; one on h0 stays" \
        [pcall wviewer::wave_hilights $tk] {{4 0 1} {0 0 2}}
    po15_drop $tk

    ## A Direct Plot whose target is the SECOND auto strip (single-plot, left
    ## behind by a multi-plot `~` before the user switched back): that strip is
    ## the tool's and is rebuilt every run, so the signal lands in a new strip
    ## at the bottom, not in it.
    po14_stub
    po15_lay $tk single [list [po15_hand v(h0)] [po15_auto v(x)] [po15_auto v(y)]] 2 {}
    set ::po14_adds {}
    set e [pcall wviewer::plot_signals $tk {v(new)}]
    check "PO15 Direct Plot with the target on the second auto strip: it lands in a new strip, not the auto one" \
        [list $e $::po14_adds [po15_shape $tk]] {{} {{3 v(new)}} HAAH}
    check "PO15 ...and the auto strips keep only their own traces" \
        [lmap G [lrange [dict get [wviewer::layout_for $tk] graphs] 1 2] \
             {lmap t [dict get $G traces] {dict get $t expr}}] {v(x) v(y)}
    po14_unstub $tk
    po15_drop $tk
}

# =============================================================================
# PO16 -- THE PLOT DESTINATION DROP-DOWN (R-OUT15)
# =============================================================================
## doc/claude/specs/waveform_viewer_subwindows.md SW18 and §8. The session's
## `plot_dest` decides where `~` and the run-end auto-plot go, in the viewer's
## ACTIVE tab and TARGET subwindow. The real ase::ui::auto_plot and the real
## wviewer model procs run (clear_subwin, new_subwin, auto_plot_strips,
## plot_sites); PO14's stand-ins cover only the Tk doors, and wviewer::new_tab
## -- whose tab machinery switches xschem contexts -- is stood in for by one
## that records the call and starts a fresh one-strip layout, keeping the old
## one in ::po16_oldtabs. The real new_tab is the display arm's (PR12).
proc po16_tabstub {} {
    set ::po16_oldtabs {}
    rename ::wviewer::new_tab ::po16_orig_new_tab
    proc ::wviewer::new_tab {{token {}}} {
        lappend ::po16_oldtabs [dict get [wviewer::layout_for $token] graphs]
        dict set ::wviewer::layouts $token \
            [dict create sharedx 0 graphs [list [wviewer::empty_graph]]]
        set ::wviewer::target($token) 0
        return [llength $::po16_oldtabs]
    }
}
proc po16_tabunstub {} {
    rename ::wviewer::new_tab {}
    rename ::po16_orig_new_tab ::wviewer::new_tab
}
## the subwindow tag of every strip, `-` for untagged
proc po16_tags {key} {
    if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return ERR:$gs }
    lmap g $gs {wviewer::dget $g sw -}
}
proc po16_tsw {key} {
    set gs [dict get [wviewer::layout_for $key] graphs]
    wviewer::sw_index $gs [wviewer::target_index $key]
}
group PO16 {
    ## --- the codes, the labels and the state key --------------------------
    check "PO16a the drop-down offers exactly the user's four, in order" \
        [ase::ui::plot_dest_labels] {Append Replace {New SubWin} {New Win}}
    check "PO16a each label is the viewer's own code (New Win is a viewer tab)" \
        [lmap l [ase::ui::plot_dest_labels] {ase::ui::plot_dest_code $l}] \
        [lmap l [ase::ui::plot_dest_labels] {wviewer::dest_norm $l}]
    check "PO16a ...and those codes are append replace newsubwin newtab, each labelled back" \
        [lmap c {append replace newsubwin newtab} {ase::ui::plot_dest_label $c}] \
        [ase::ui::plot_dest_labels]
    check "PO16a the default, an empty and an unknown value all read Replace" \
        [list [ase::plot_dest_of [ase::state_default]] [ase::plot_dest_of {plot_dest {}}] \
              [ase::plot_dest_of {plot_dest newstrip}] [ase::plot_dest_of {}]] \
        {replace replace replace replace}

    set key [po_session po16 tbpo {{name A expr v(sq) save 1 plot 1} {name B expr v(lp) save 1 plot 1}} 1]
    set ::po16_log {}
    rename ::ase::ui::log_action ::po16_log_orig
    proc ::ase::ui::log_action {line} { lappend ::po16_log $line }
    check "PO16b fixture: a fresh session is clean and reads Replace" \
        [list [ase::session_dirty $key] [ase::ui::plot_dest $key]] {0 replace}
    check "PO16b choosing New SubWin answers its code, writes the state and dirties the session" \
        [list [pcall ase::ui::set_plot_dest $key {New SubWin}] \
              [dict get [ase::session_state $key] plot_dest] [ase::session_dirty $key]] \
        {newsubwin newsubwin 1}
    check "PO16b ...logged as ONE replayable line with the code" \
        $::po16_log [list [list ase::ui::set_plot_dest $key newsubwin]]
    pcall ase::ui::set_plot_dest $key newsubwin
    check "PO16b the same choice again logs nothing" [llength $::po16_log] 1
    check "PO16b Replace is stored as the empty default, so choosing it back leaves the session clean" \
        [list [pcall ase::ui::set_plot_dest $key Replace] \
              [dict get [ase::session_state $key] plot_dest] [ase::session_dirty $key]] \
        {replace {} 0}
    set ::po_echoes {}
    check "PO16b a bad request is refused, said, and changes nothing" \
        [list [pcall ase::ui::set_plot_dest $key sideways] [ase::ui::plot_dest $key] \
              [llength [lsearch -all -glob $::po_echoes {*bad plot destination*}]] \
              [llength $::po16_log]] \
        {{} replace 1 2}
    rename ::ase::ui::log_action {}
    rename ::po16_log_orig ::ase::ui::log_action

    ## --- saved and restored with the state --------------------------------
    set sst [dict replace [ase::state_default] plot_dest newtab]
    set ser [ase::state_serialize $sst]
    check "PO16c a non-default choice is written as one state line" \
        [lsearch -all -inline [split $ser \n] {plot_dest *}] {{plot_dest newtab}}
    check "PO16c the default is not written at all (ase::omit_if_empty)" \
        [lsearch -all -inline [split [ase::state_serialize [ase::state_default]] \n] {plot_dest*}] {}
    set sf [file join $::scratch po16 saved.state]
    ase::state_save $sf $sst
    check "PO16c ...and reads back from the file" [ase::plot_dest_of [ase::state_load $sf]] newtab

    ## --- Replace (the default): the TARGET subwindow is emptied first -----
    set saved_default [expr {[info exists ::wviewer_plot_mode] ? $::wviewer_plot_mode : {}}]
    po14_stub
    set ::wviewer_plot_mode single
    pcall ase::ui::plot_outputs $key
    ## a hand strip in the SAME subwindow as the run's plot, and a zoom the
    ## user set on the run's strip
    set gs [dict get [wviewer::layout_for $key] graphs]
    lset gs 0 [dict replace [lindex $gs 0] x1 0.001 x2 0.002]
    lappend gs [dict create traces [list [dict create expr v(hand)]] logx 0 logy 0 \
                    x1 {} x2 {} y1 {} y2 {}]
    wviewer::set_graphs $key $gs
    set ::wviewer::target($key) 1
    set u0 [lindex [wviewer::history_depth $key] 0]
    pcall ase::ui::plot_outputs $key
    check "PO16d Replace empties the target subwindow: the hand strip there is gone (Cadence's Replace)" \
        [po14_strips $key] {{1 {v(sq) v(lp)}}}
    check "PO16d ...the run's strip keeps the zoom the user set on it" \
        [list [wviewer::dget [lindex [dict get [wviewer::layout_for $key] graphs] 0] x1 {}] \
              [wviewer::dget [lindex [dict get [wviewer::layout_for $key] graphs] 0] x2 {}]] {0.001 0.002}
    check "PO16d ...and the clear is ONE undo step" \
        [expr {[lindex [wviewer::history_depth $key] 0] - $u0}] 1

    ## --- Append: the target subwindow keeps everything --------------------
    ase::ui::set_plot_dest $key append
    pcall ase::ui::plot_outputs $key
    check "PO16e Append in single-plot adds to the target strip (an auto strip may take it): no clear" \
        [po14_strips $key] {{1 {v(sq) v(lp) v(sq) v(lp)}}}
    set ::wviewer::mode($key) multi
    pcall ase::ui::plot_outputs $key
    check "PO16e Append in multi-plot: new strips on top, newest first, the old plot kept" \
        [po14_strips $key] {{0 v(lp)} {0 v(sq)} {1 {v(sq) v(lp) v(sq) v(lp)}}}
    set ::wviewer::mode($key) single

    ## --- New SubWin: a new subwindow holds the run; the old plot stays -----
    ase::ui::set_plot_dest $key newsubwin
    set before [po14_strips $key]
    pcall ase::ui::plot_outputs $key
    check "PO16g New SubWin: a second subwindow, made the target, holds the run in an auto strip" \
        [list [po16_tags $key] [po16_tsw $key] [lindex [po14_strips $key] end]] \
        {{1 1 1 2} 1 {1 {v(sq) v(lp)}}}
    check "PO16g ...and the first subwindow is untouched, traces and auto marker included" \
        [lrange [po14_strips $key] 0 2] $before
    set ::wviewer::mode($key) multi
    pcall ase::ui::plot_outputs $key
    check "PO16g a second press in multi-plot: a THIRD subwindow, one auto strip per row, newest on top" \
        [list [po16_tags $key] [po16_tsw $key] [lrange [po14_strips $key] end-1 end]] \
        {{1 1 1 2 3 3} 2 {{1 v(lp)} {1 v(sq)}}}
    set ::wviewer::mode($key) single

    ## --- zero rows: only Replace empties anything ---------------------------
    set snap [dict get [wviewer::layout_for $key] graphs]
    po14_plot $key
    foreach d {append newsubwin newtab} {
        ase::ui::set_plot_dest $key $d
        pcall ase::ui::plot_outputs $key
    }
    check "PO16i nothing ticked under Append, New SubWin and New Win changes nothing" \
        [expr {[dict get [wviewer::layout_for $key] graphs] eq $snap}] 1
    ase::ui::set_plot_dest $key replace
    pcall ase::ui::plot_outputs $key
    check "PO16i ...under Replace the target subwindow is left one empty auto strip, the others kept" \
        [list [po16_tags $key] [lindex [po14_strips $key] end] \
              [expr {[lrange [dict get [wviewer::layout_for $key] graphs] 0 3] eq [lrange $snap 0 3]}]] \
        {{1 1 1 2 3} {1 {}} 1}
    set ::wviewer::target($key) 0
    set snap [dict get [wviewer::layout_for $key] graphs]
    set gs $snap
    for {set i 0} {$i < 3} {incr i} { lset gs $i [dict remove [lindex $gs $i] auto] }
    wviewer::set_graphs $key $gs
    set snap [dict get [wviewer::layout_for $key] graphs]
    pcall ase::ui::plot_outputs $key
    check "PO16i ...but a target subwindow `~` never plotted into (no auto strip) is not emptied by a press that plots nothing" \
        [expr {[dict get [wviewer::layout_for $key] graphs] eq $snap}] 1
    po14_plot $key A B

    ## --- New Win: a new viewer tab holds the run ----------------------------
    po16_tabstub
    ase::ui::set_plot_dest $key newtab
    set before [dict get [wviewer::layout_for $key] graphs]
    pcall ase::ui::plot_outputs $key
    check "PO16h New Win: one new tab, holding the run in one auto strip" \
        [list [llength $::po16_oldtabs] [po14_strips $key]] {1 {{1 {v(sq) v(lp)}}}}
    check "PO16h ...the previous tab kept its plot" \
        [expr {[lindex $::po16_oldtabs 0] eq $before}] 1
    po16_tabunstub

    ## --- a viewer the press OPENS is already the new window/subwindow ------
    po14_unstub $key
    po14_stub
    po16_tabstub
    ase::ui::set_plot_dest $key newsubwin
    pcall ase::ui::plot_outputs $key
    check "PO16j New SubWin with the viewer closed: it opens with ONE subwindow holding the run" \
        [list [po16_tags $key] [po14_strips $key]] {- {{1 {v(sq) v(lp)}}}}
    po14_unstub $key
    po14_stub
    ase::ui::set_plot_dest $key newtab
    pcall ase::ui::plot_outputs $key
    check "PO16j New Win with the viewer closed: no second tab is made" \
        [list [llength $::po16_oldtabs] [po14_strips $key]] {0 {{1 {v(sq) v(lp)}}}}
    po16_tabunstub

    ## --- a failed run plots nothing under any choice (R-OUT13 kept) -------
    po_log $key 1
    set n0 [llength [dict get [wviewer::layout_for $key] graphs]]
    set ::po14_adds {}
    foreach d {append replace newsubwin newtab} {
        ase::ui::set_plot_dest $key $d
        pcall ase::ui::plot_outputs $key
    }
    check "PO16k after a failed run no choice plots or makes anything" \
        [list $::po14_adds [llength [dict get [wviewer::layout_for $key] graphs]] [po16_tags $key]] \
        [list {} $n0 -]
    po14_unstub $key
    catch {ase::session_close $key}
    unset -nocomplain ::wviewer_plot_mode
    if {$saved_default ne {}} { set ::wviewer_plot_mode $saved_default }

    ## --- every committed state still serialises without the key -----------
    set nst 0; set bad {}
    foreach f [split [exec git -C $::repo ls-files *.state] \n] {
        if {$f eq {}} { continue }
        if {[catch {ase::state_load [file join $::repo $f]} s0]} { continue }
        incr nst
        if {[string first plot_dest [ase::state_serialize $s0]] >= 0} { lappend bad $f }
    }
    check "PO16f no committed .state file gains a plot_dest line on load -> save ($nst files)" \
        [list [expr {$nst > 50}] $bad] {1 {}}
    check "PO16f control: the same file with a choice made DOES serialise differently" \
        [expr {[ase::state_serialize [dict replace $s0 plot_dest append]] ne [ase::state_serialize $s0]}] 1
}

# =============================================================================
# PO16k -- DIRECT PLOT ALWAYS APPENDS; THE DROP-DOWN IS NOT ITS BUSINESS (R-OUT15)
# =============================================================================
## User ruling 2026-11-16, reversing issue 1663's of 2026-10-16: "The Direct
## Plot, which is same as Ctrl-4 should always Append to the destination. The
## destination drop down is only for the ~ plot button and automatic plot of
## results when simulation finishes."
## Two halves. The hand-off: ase::ui::dp_finish hands wviewer::plot_signals
## `append` whatever the session's drop-down says (the viewer doors stood in
## for; plot_signals records what it was handed). The landing: the real
## wviewer::plot_signals chain on the model, under every choice of the
## drop-down -- nothing emptied, no subwindow and no tab made.
## The first half's stand-ins say nothing about what attach_raw does to the
## VIEW (issue 1733: a Direct Plot keeps the zoom): that is band PV below, on
## the real dp_finish, attach_raw and regenerate, with nothing stood in for.
group PO16k {
    set key [po_session po16k tbpk {{name A expr v(sq) save 1 plot 1}} 1]
    set ::po16k_calls {}
    foreach p {open attach_raw plot_signals} { rename ::wviewer::$p ::po16k_orig_$p }
    proc ::wviewer::open {args} { return 1 }
    proc ::wviewer::attach_raw {args} { return 1 }
    proc ::wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
        lappend ::po16k_calls [list $token $exprs $destover]
        return {}
    }
    set got {}
    foreach d {{} append newsubwin newtab replace} {
        if {$d ne {}} { pcall ase::ui::set_plot_dest $key $d }
        set ::po16k_calls {}
        pcall ase::ui::dp_finish $key {v(sq) v(lp)}
        lappend got [list [ase::ui::plot_dest $key] [lindex $::po16k_calls 0 2] [llength $::po16k_calls]]
    }
    foreach p {open attach_raw plot_signals} {
        rename ::wviewer::$p {}
        rename ::po16k_orig_$p ::wviewer::$p
    }
    check "PO16k Direct Plot hands plot_signals `append` under every choice of the drop-down, once per batch" \
        $got {{replace append 1} {append append 1} {newsubwin append 1} {newtab append 1} {replace append 1}}
    check "PO16k ...and the drop-down's tooltip names what it governs: ~ and the run-end plot" \
        [ase::ui::lbl_plot_dest_tip] {Where ~ and the run-end plot go}
    catch {ase::session_close $key}

    ## THE LANDING. `~` plots the run's row first (under the default Replace),
    ## then one Direct Plot batch per choice of the drop-down: each is ADDED to
    ## what is there.
    set key [po_session po16k2 tbpk2 {{name A expr v(sq) save 1 plot 1}} 1]
    po14_stub
    po16_tabstub
    proc ::wviewer::attach_raw {args} { return 0 }
    set ::wviewer_plot_mode single
    pcall ase::ui::plot_outputs $key
    check "PO16k fixture: ~ put the run's row in one strip, and the drop-down reads the default Replace" \
        [list [po14_strips $key] [ase::ui::plot_dest $key]] {{{1 v(sq)}} replace}
    set got {}
    foreach {d sig} {{} v(lp) append v(ramp) newsubwin v(a) newtab v(b) replace v(c)} {
        if {$d ne {}} { pcall ase::ui::set_plot_dest $key $d }
        pcall ase::ui::dp_finish $key [list $sig]
        lappend got [list [ase::ui::plot_dest $key] [po14_strips $key] [po16_tags $key] \
                          [llength $::po16_oldtabs]]
    }
    ## (the viewer's append rule for a hand plot: the run's auto strip is left
    ## as it is, the first pick opens a strip beside it and the later ones join
    ## that strip; one subwindow and one tab throughout)
    check "PO16k each Direct Plot batch is ADDED beside the run's plot, whatever the drop-down says" \
        $got [list \
          {replace {{1 v(sq)} {0 v(lp)}} {- -} 0} \
          {append {{1 v(sq)} {0 {v(lp) v(ramp)}}} {- -} 0} \
          {newsubwin {{1 v(sq)} {0 {v(lp) v(ramp) v(a)}}} {- -} 0} \
          {newtab {{1 v(sq)} {0 {v(lp) v(ramp) v(a) v(b)}}} {- -} 0} \
          {replace {{1 v(sq)} {0 {v(lp) v(ramp) v(a) v(b) v(c)}}} {- -} 0}]
    ## ...and the drop-down still governs `~`: under Replace it empties first
    pcall ase::ui::plot_outputs $key
    check "PO16k control: ~ under the same Replace DOES empty the subwindow first" \
        [po14_strips $key] {{1 v(sq)}}
    po16_tabunstub
    po14_unstub $key
    catch {ase::session_close $key}
}

# =============================================================================
# PV -- A DIRECT PLOT AND A RE-RUN KEEP THE ZOOM (issue 1733), display arm
# =============================================================================
## User report 2026-11-22: after a run, a strip zoomed, then another signal
## plotted with Direct Plot: every strip snapped back to the full sweep. Ruling
## the same day: "yes, re-run which then plots in Replace mode should retain
## zoom level, not reset it".
## Everything here is the REAL path, with no stand-in for any viewer door: the
## real ase::ui::dp_finish (a pick list of {} is a Direct Plot with nothing
## picked: it attaches and plots nothing), the real ase::ui::plot_outputs under
## Replace and Append, the real wviewer::attach_raw, rawbar_load and regenerate.
## The session's results are raws written HERE, so every window is known; the
## zoom goes onto the RECTS ONLY through the engine's own verb, and the model is
## left auto (test_wave_grid's GZ fixture rule). Each check reads every strip.
## A Y that is "the fit over the X the strip shows" is measured, not computed:
## the engine is asked to fit that rect again (pv_yfit) and must answer what it
## shows.
set ::pv_disp {}
foreach {- b} [regexp -all -inline -line {^\s*group\s+(PV[0-9]+)\s} $::po_src] {
    lappend ::pv_disp $b
}
## A transient raw: time 0..tend, v(a) rising 0..amp, v(b) falling amp..0,
## v(c) = amp/2 + v(a)/4. Binary, so two writes with the same point count are
## the same size to the byte.
proc pv_tran {path tend amp {np 41}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: pv fixture\nDate: Sun Nov 22 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 4\nNo. Points: $np\nVariables:\n\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\n\t3\tv(c)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set t [expr {$tend * $i / ($np - 1.0)}]
        set a [expr {$amp * $i / ($np - 1.0)}]
        puts -nonewline $f [binary format q4 [list $t $a [expr {$amp - $a}] [expr {$amp / 2.0 + $a / 4.0}]]]
    }
    close $f
}
## An ac raw of the same vectors over frequency f1..f2 (complex, as ngspice writes it)
proc pv_ac {path f1 f2 {np 21}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: pv fixture\nDate: Sun Nov 22 00:00:00  2026\nPlotname: AC Analysis\nFlags: complex\nNo. Variables: 4\nNo. Points: $np\nVariables:\n\t0\tfrequency\tfrequency\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\n\t3\tv(c)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set fr [expr {$f1 + ($f2 - $f1) * $i / ($np - 1.0)}]
        set m [expr {1.0 / (1.0 + $i)}]
        puts -nonewline $f [binary format q8 [list $fr 0.0 $m 0.0 [expr {2 * $m}] 0.0 [expr {3 * $m}] 0.0]]
    }
    close $f
}
## The session: po_session with no fixture copied, its results raw written by pv_tran
proc pv_session {sub cell outs tend amp} {
    set key [po_session $sub $cell $outs 0]
    set ::pv_raw [file join $::scratch $sub ${cell}_ase.raw]
    pv_tran $::pv_raw $tend $amp
    return $key
}
## Rewrite the session's raw and move its mtime by `dt` seconds past what it
## was, so the move is certain whatever the file system's clock resolution.
## Answers {mtime_moved size_moved}.
proc pv_rewrite {tend amp dt} {
    file stat $::pv_raw a0
    pv_tran $::pv_raw $tend $amp
    file mtime $::pv_raw [expr {$a0(mtime) + $dt}]
    file stat $::pv_raw a1
    return [list [expr {$a1(mtime) != $a0(mtime)}] [expr {$a1(size) != $a0(size)}]]
}
proc pv_ready {key} {
    set top [wviewer::window_for $key]
    for {set i 0} {$i < 300} {incr i} {
        update
        if {$top ne {} && [winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
        after 20
    }
    return 0
}
proc pv_drw {key} {
    if {[catch {wviewer::window_for $key} w]} { return {} }
    return $w.drw
}
## an error message as a value that cannot be taken for a list of answers
proc pv_err {e} { return ERR:[string map {\{ ( \} ) " " _} $e] }
## Every strip's {x1 x2 y1 y2}, as doubles, off the rects
proc pv_axes {key} {
    if {[catch {xschem new_schematic switch [pv_drw $key]} e]} { return [pv_err $e] }
    set o {}
    set n 0 ; catch {set n [xschem get graph_rects]}
    for {set k 0} {$k < $n} {incr k} {
        set r {}
        foreach t {x1 x2 y1 y2} {
            set v {} ; catch {set v [xschem getprop rect 2 $k $t]}
            lappend r [expr {[string is double -strict $v] ? double($v) : $v}]
        }
        lappend o $r
    }
    return $o
}
## Every strip's trace vectors, top first
proc pv_vecs {key} {
    set gs [pv_gs $key]
    if {[string match ERR:* $gs]} { return $gs }
    if {[catch {lmap G $gs { lmap t [wviewer::dget $G traces {}] {wviewer::dget $t vec {}} }} v]} {
        return [pv_err $v]
    }
    return $v
}
## {strip traces -> axes}, so strips are matched by what they hold, not by index
proc pv_byvecs {key} {
    set o {}
    if {[catch {
        foreach v [pv_vecs $key] a [pv_axes $key] { dict set o $v $a }
    } e]} { return [pv_err $e] }
    return $o
}
## the layout's strips, and each strip's auto flag, as values on any failure
proc pv_gs {key} {
    if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return [pv_err $gs] }
    return $gs
}
proc pv_auto {key} {
    set gs [pv_gs $key]
    if {[string match ERR:* $gs]} { return $gs }
    if {[catch {lmap G $gs {wviewer::dget $G auto 0}} v]} { return [pv_err $v] }
    return $v
}
## `dict get` that answers ABSENT instead of raising (a band asserts, never aborts)
proc pv_at {d args} {
    if {[catch {dict get $d {*}$args} v]} { return ABSENT }
    return $v
}
## the distinct X windows of the strips of subwindow `s` in a pv_bysw answer
proc pv_swx {d s} {
    if {[catch {lsort -unique [lmap r [dict values [dict get $d $s]] {lrange $r 0 1}]} v]} { return ABSENT }
    return $v
}
## the engine's own zoom on the rect only; a raise is answered, never thrown
proc pv_zoom {key gi ax a b} {
    if {[catch {
        xschem new_schematic switch [pv_drw $key]
        xschem graph_axis_zoom $gi $ax $a $b
    } e]} { update ; return [pv_err $e] }
    update
}
## What the engine fits axis `ax` (x or y) of strip gi to, over what the rect
## shows; the rect is put back as it was.
proc pv_fit {key gi ax} {
    if {[catch {
        xschem new_schematic switch [pv_drw $key]
        set t1 ${ax}1 ; set t2 ${ax}2
        set o1 [xschem getprop rect 2 $gi $t1]
        set o2 [xschem getprop rect 2 $gi $t2]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi full${ax}zoom]
        xschem new_schematic switch [pv_drw $key]
        set f [list [expr {double([xschem getprop rect 2 $gi $t1])}] \
                    [expr {double([xschem getprop rect 2 $gi $t2])}]]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi $t1 $o1]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi $t2 $o2]
    } e]} { return [pv_err $e] }
    return $f
}
proc pv_yfit {key gi} { pv_fit $key $gi y }
## an expected window, spelled as pv_axes spells a double (whatever this Tcl's
## shortest form is), so a literal in a check cannot disagree by formatting
proc pv_n {args} { lmap v $args {expr {double($v)}} }
proc pv_xfit {key gi} { pv_fit $key $gi x }
## the verdict of the last attach: 1 same data, 0 new data, NOREC. Every
## answer of a verb this fix added goes through an accessor that answers a
## VALUE on any failure (ERR:...), so on a tree without the verb the band
## ASSERTS red instead of aborting and dropping its rows from the verdict.
proc pv_same {key} {
    if {[catch {wviewer::attach_record $key} r]} { return ERR:[string map {\{ ( \} )} $r] }
    if {[catch {dict get $r same} s]} { return NOREC }
    return $s
}
## the whole record of the last attach ({} for none), the same way
proc pv_record {key} {
    if {[catch {wviewer::attach_record $key} r]} { return ERR:[string map {\{ ( \} )} $r] }
    return $r
}
## the path of the database the viewer's context draws from now (`cur` of
## wviewer::attach_db), the same way
proc pv_curdb {} {
    if {[catch {wviewer::attach_db} d]} { return ERR:[string map {\{ ( \} )} $d] }
    if {[catch {dict get $d cur} c]} { return NOCUR }
    return [lindex $c 0]
}
## A dc raw of the same vectors: a sweep v-sweep running x1..x2 (the X column
## is not `time`, and the analysis is another), real, as ngspice writes it
proc pv_dc {path x1 x2 {np 41}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: pv fixture\nDate: Sun Nov 22 00:00:00  2026\nPlotname: DC transfer characteristic\nFlags: real\nNo. Variables: 4\nNo. Points: $np\nVariables:\n\t0\tv-sweep\tvoltage\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\n\t3\tv(c)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set x [expr {$x1 + ($x2 - $x1) * $i / ($np - 1.0)}]
        set a [expr {3.0 + 4.0 * $i / ($np - 1.0)}]
        puts -nonewline $f [binary format q4 [list $x $a [expr {10.0 - $a}] [expr {$a / 2.0}]]]
    }
    close $f
}

if {$GUI} {
## (a) R1: the same raw, a REAL Direct Plot, single and multi mode
group PV1 {
    set key [pv_session pv1 tbpv1 {} 10e-9 1.0]
    check "PV1 fixture: the session's results are the raw written here, a tran" \
        [list [pcall ase::last_rawfile $key] [pcall ase::plot_sim_type [ase::session_state $key]]] [list $::pv_raw tran]
    check "PV1 fixture: the viewer opens and maps" [list [pcall wviewer::open $key] [pv_ready $key]] {1 1}
    foreach mode {single multi} {
        pcall wviewer::set_plot_mode multi $key
        pcall wviewer::clear_all $key
        pcall ase::ui::dp_finish $key {v(a)}
        pcall ase::ui::dp_finish $key {v(b)}
        update
        check "PV1 $mode fixture: two strips, and the second Direct Plot was the same data" \
            [list [lsort [pv_vecs $key]] [pv_same $key]] {{v(a) v(b)} 1}
        pcall wviewer::set_plot_mode $mode $key
        update
        set fit [pv_byvecs $key]
        pv_zoom $key 0 x 2e-9 4e-9
        set z [pv_byvecs $key]
        check "PV1 $mode fixture: X zoomed on both strips, Y as fitted, on the rects only" \
            [list [lrange [pv_at $z v(a)] 0 1] [lrange [pv_at $z v(b)] 0 1] \
                  [lrange [pv_at $z v(a)] 2 3] [lrange [pv_at $z v(b)] 2 3]] \
            [list [pv_n 2e-9 4e-9] [pv_n 2e-9 4e-9] [lrange [pv_at $fit v(a)] 2 3] [lrange [pv_at $fit v(b)] 2 3]]
        pcall ase::ui::dp_finish $key {v(c)}
        update
        set after [pv_byvecs $key]
        check "PV1 $mode the Direct Plot was the same data (R1)" [pv_same $key] 1
        if {$mode eq {single}} {
            ## v(c) went into one of the two strips; the other is untouched
            set into [lsearch -inline -glob [dict keys $after] {*v(c)*}]
            set other [expr {$into eq {v(a) v(c)} ? {v(b)} : {v(a)}}]
            check "PV1 single the pick landed in a strip already there (no third strip)" \
                [list [llength [dict keys $after]] [expr {$into in {{v(a) v(c)} {v(b) v(c)}}}]] {2 1}
            check "PV1 single the strip it did not touch shows EXACTLY what it showed (both axes)" \
                [pv_at $after $other] [pv_at $z $other]
            check "PV1 single the strip it landed in keeps the zoomed X" \
                [lrange [pv_at $after $into] 0 1] [pv_n 2e-9 4e-9]
        } else {
            check "PV1 multi a new strip, the two old ones show EXACTLY what they showed" \
                [list [llength [dict keys $after]] [pv_at $after v(a)] [pv_at $after v(b)]] \
                [list 3 [pv_at $z v(a)] [pv_at $z v(b)]]
            check "PV1 multi the new strip joins the zoomed X window" \
                [lrange [pv_at $after v(c)] 0 1] [pv_n 2e-9 4e-9]
        }
    }
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

## (b) R2: the raw REWRITTEN with other data; the overlap and the analysis controls
group PV2 {
    set key [pv_session pv2 tbpv2 {} 10e-9 1.0]
    pcall wviewer::open $key
    pv_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::dp_finish $key {v(a)}
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pv_zoom $key 0 x 2e-9 4e-9
    set z [pv_byvecs $key]
    ## the same size, the data doubled: only the mtime can tell the rewrite
    check "PV2 fixture: a same-size rewrite really moved the mtime and not the size" \
        [pv_rewrite 10e-9 2.0 7] {1 0}
    pcall ase::ui::dp_finish $key {}
    update
    set a [pv_byvecs $key]
    check "PV2 the rewrite is new data (R2)" [pv_same $key] 0
    check "PV2 the X the user moved is kept, on every strip" \
        [list [lrange [pv_at $a v(a)] 0 1] [lrange [pv_at $a v(b)] 0 1]] [list [pv_n 2e-9 4e-9] [pv_n 2e-9 4e-9]]
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    set gi_b [lsearch -exact [pv_vecs $key] v(b)]
    check "PV2 the Y nobody moved is fitted again to the NEW data, over the kept window" \
        [list [lrange [pv_at $a v(a)] 2 3] [lrange [pv_at $a v(b)] 2 3]] \
        [list [pv_yfit $key $gi_a] [pv_yfit $key $gi_b]]
    check "PV2 ...which is not what it showed (the data did change under it)" \
        [expr {[lrange [pv_at $a v(a)] 2 3] ne [lrange [pv_at $z v(a)] 2 3]}] 1

    ## Y moved, X not: Y kept, X fitted to the new (longer) sweep. The strips
    ## are built afresh, so the X nobody moved is the fit.
    pcall wviewer::clear_all $key
    pcall ase::ui::dp_finish $key {v(a)}
    pcall ase::ui::dp_finish $key {v(b)}
    update
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    set gi_b [lsearch -exact [pv_vecs $key] v(b)]
    pv_zoom $key $gi_a y 0.25 0.5
    set z [pv_byvecs $key]
    check "PV2 fixture: Y zoomed on one strip, X as fitted" \
        [list [lrange [pv_at $z v(a)] 2 3] [lrange [pv_at $z v(a)] 0 1]] [list {0.25 0.5} [pv_xfit $key $gi_a]]
    check "PV2 fixture: a same-size rewrite to a longer sweep" [pv_rewrite 15e-9 3.0 14] {1 0}
    pcall ase::ui::dp_finish $key {}
    update
    set a [pv_byvecs $key]
    check "PV2 Y moved: the Y is kept exactly, and the X nobody moved is fitted to the new sweep" \
        [list [lrange [pv_at $a v(a)] 2 3] [lrange [pv_at $a v(a)] 0 1] [pv_same $key]] \
        [list {0.25 0.5} [pv_xfit $key $gi_a] 0]
    check "PV2 ...that new sweep is the longer one (the X really was refitted)" \
        [lrange [pv_at $a v(a)] 0 1] [pv_n 0 15e-9]

    ## the new sweep does not reach the kept window: X fits
    pv_zoom $key 0 x 6e-9 8e-9
    check "PV2 fixture: X zoomed to 6n..8n on every strip" \
        [lsort -unique [lmap r [pv_axes $key] {lrange $r 0 1}]] [list [pv_n 6e-9 8e-9]]
    pv_rewrite 3e-9 1.0 21
    pcall ase::ui::dp_finish $key {}
    update
    check "PV2 a new sweep (0..3n) that does not overlap the kept window (6n..8n): X is fitted" \
        [lsort -unique [lmap r [pv_axes $key] {lrange $r 0 1}]] [list [pv_n 0 3e-9]]
    check "PV2 ...which is the engine's fit of that strip, and the Y nobody moved fits with it" \
        [list [lrange [lindex [pv_axes $key] $gi_b] 0 1] [lrange [lindex [pv_axes $key] $gi_b] 2 3]] \
        [list [pv_xfit $key $gi_b] [pv_yfit $key $gi_b]]
    check "PV2 ...while the Y that was moved stays as it was moved" \
        [lrange [lindex [pv_axes $key] $gi_a] 2 3] {0.25 0.5}
    check "PV2 control: a window that DOES overlap (1n..2n) on the same new sweep is kept" \
        [list [pv_zoom $key 0 x 1e-9 2e-9] [pv_rewrite 3e-9 1.5 28] [pcall ase::ui::dp_finish $key {}] \
              [lsort -unique [lmap r [pv_axes $key] {lrange $r 0 1}]]] [list {} {1 0} {} [list [pv_n 1e-9 2e-9]]]

    ## another analysis through the real attach: the X is not the same thing
    set acf [file join $::scratch pv2 tbpv2_ac.raw]
    pv_ac $acf 1e3 1e6
    pv_zoom $key 0 x 1.2e-9 1.8e-9
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    check "PV2 fixture: before the ac attach the Y of v(a) is still the one the user moved" \
        [lrange [lindex [pv_axes $key] $gi_a] 2 3] {0.25 0.5}
    check "PV2 an ac file attached where the tran was" [pcall wviewer::attach_raw $key $acf ac] 1
    update
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    set ax [lrange [lindex [pv_axes $key] $gi_a] 0 1]
    ## the frequencies (1e3..1e6) never reach a window of nanoseconds, so this
    ## X is dropped by the overlap rule (regenerate's xnew arm) as much as by
    ## x_same: the dc leg below is the one where only x_same can drop it
    check "PV2 ...is new data, and the zoomed X is dropped on a sweep that misses the window: X is the engine's fit of the frequencies" \
        [list [pv_same $key] [expr {$ax eq [pv_xfit $key $gi_a]}] [expr {$ax ne [pv_n 1.2e-9 1.8e-9]}]] {0 1 1}
    ## issue 1733 review: another analysis is another plot, so the Y the user
    ## moved on the transient is not kept over the frequencies either
    set ay [lrange [lindex [pv_axes $key] $gi_a] 2 3]
    check "PV2 ...and the Y moved on the tran is dropped too: Y is the engine's fit over the frequencies" \
        [list [expr {$ay eq [pv_yfit $key $gi_a]}] [expr {$ay ne {0.25 0.5}}]] {1 1}

    ## another analysis whose X column (v-sweep, not time) runs over the SAME
    ## numbers as the kept window: regenerate's overlap rule keeps a window
    ## that meets the new sweep, so only view_new_data's x_same can drop it.
    ## The tran is attached back first (another analysis again: it fits), then
    ## zoomed on both axes.
    set dcf [file join $::scratch pv2 tbpv2_dc.raw]
    pv_dc $dcf 0 1e-8
    check "PV2 fixture: the tran attached back after the ac" [pcall wviewer::attach_raw $key $::pv_raw tran] 1
    update
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    pv_zoom $key $gi_a x 1.2e-9 1.8e-9
    pv_zoom $key $gi_a y 0.25 0.5
    check "PV2 fixture: v(a) zoomed to 1.2n..1.8n in X and 0.25..0.5 in Y, on the rects" \
        [lindex [pv_axes $key] $gi_a] [pv_n 1.2e-9 1.8e-9 0.25 0.5]
    check "PV2 a dc file (X column v-sweep) attached where the tran was" [pcall wviewer::attach_raw $key $dcf dc] 1
    update
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    set ax [lrange [lindex [pv_axes $key] $gi_a] 0 1]
    set dfit [pv_xfit $key $gi_a]
    ## distinctness, by plain arithmetic on the sweep this suite wrote: the
    ## engine's fit of the dc X is the written 0..10n, it is not the kept
    ## window, and the two overlap by far more than a point
    check "PV2 distinctness: the dc sweep's fit is the written 0..10n, overlaps the kept 1.2n..1.8n, and is not it" \
        [list [expr {$dfit eq [pv_n 0 1e-8]}] \
              [expr {[llength $dfit] == 2 && [string is double -strict [lindex $dfit 0]]
                     && max(1.2e-9, [lindex $dfit 0]) < min(1.8e-9, [lindex $dfit 1])}] \
              [expr {$dfit ne [pv_n 1.2e-9 1.8e-9]}]] {1 1 1}
    check "PV2 ...is new data, and the zoomed X is dropped on a sweep that DOES overlap it (x_same, not the overlap): X is the sweep's fit" \
        [list [pv_same $key] [expr {$ax eq $dfit}] [expr {$ax ne [pv_n 1.2e-9 1.8e-9]}]] {0 1 1}
    set ay [lrange [lindex [pv_axes $key] $gi_a] 2 3]
    check "PV2 ...and the Y moved on the tran is dropped with it: Y is the engine's fit over the dc sweep" \
        [list [expr {$ay eq [pv_yfit $key $gi_a]}] [expr {$ay ne {0.25 0.5}}]] {1 1}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

## (c) R3: `~` under Replace (and Append) after a rewrite keeps a zoomed strip's view
group PV3 {
    set outs {{name A expr v(a) save 1 plot 1} {name B expr v(b) save 1 plot 1}}
    set key [pv_session pv3 tbpv3 $outs 10e-9 1.0]
    pcall wviewer::open $key
    pv_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    check "PV3 fixture: the drop-down reads Replace, and ~ plots the run's rows into one auto strip" \
        [list [pcall ase::ui::plot_dest $key] [pcall ase::ui::plot_outputs $key] [pv_vecs $key] \
              [pv_auto $key]] \
        {replace 1 {{v(a) v(b)}} 1}
    update
    pv_zoom $key 0 x 2e-9 4e-9
    set z [pv_axes $key]
    ## no rewrite: the same data, and the strip comes back with the traces it had
    pcall ase::ui::plot_outputs $key
    update
    check "PV3 Replace, the same data: the re-plotted strip shows EXACTLY what it showed" \
        [list [pv_same $key] [pv_vecs $key] [pv_axes $key]] [list 1 {{v(a) v(b)}} $z]
    check "PV3 fixture: a same-size rewrite (the re-run)" [pv_rewrite 10e-9 2.0 7] {1 0}
    pcall ase::ui::plot_outputs $key
    update
    set a [pv_axes $key]
    check "PV3 Replace after the re-run: the run's rows, in one auto strip, with the zoomed X kept" \
        [list [pv_same $key] [pv_vecs $key] \
              [pv_auto $key] \
              [lrange [lindex $a 0] 0 1]] [list 0 {{v(a) v(b)}} 1 [pv_n 2e-9 4e-9]]
    check "PV3 ...and its Y fitted to the new data over that window" \
        [lrange [lindex $a 0] 2 3] [pv_yfit $key 0]

    ## multi-plot Replace: one auto strip per row, each matched by its traces
    pcall wviewer::set_plot_mode multi $key
    pcall ase::ui::plot_outputs $key
    update
    check "PV3 fixture: multi-plot ~ gives each row its own auto strip" \
        [lsort [pv_vecs $key]] {v(a) v(b)}
    pv_zoom $key 0 x 5e-9 7e-9
    pv_rewrite 10e-9 1.0 14
    pcall ase::ui::plot_outputs $key
    update
    check "PV3 multi Replace after a re-run: both strips come back with their rows and the zoomed X" \
        [list [lsort [pv_vecs $key]] [lsort -unique [lmap r [pv_axes $key] {lrange $r 0 1}]]] \
        [list {v(a) v(b)} [list [pv_n 5e-9 7e-9]]]
    check "PV3 ...each Y fitted over that window" \
        [list [lrange [lindex [pv_axes $key] 0] 2 3] [lrange [lindex [pv_axes $key] 1] 2 3]] \
        [list [pv_yfit $key 0] [pv_yfit $key 1]]

    ## Append: the strips already there keep theirs
    check "PV3 fixture: Append picked" [pcall ase::ui::set_plot_dest $key append] append
    pv_zoom $key 0 x 3e-9 4e-9
    pv_rewrite 10e-9 2.5 21
    pcall ase::ui::plot_outputs $key
    update
    set gs [pv_gs $key]
    check "PV3 Append after a re-run: every strip, old and new, shows the zoomed X" \
        [list [expr {[llength $gs] >= 2}] [lsort -unique [lmap r [pv_axes $key] {lrange $r 0 1}]] [pv_same $key]] \
        [list 1 [list [pv_n 3e-9 4e-9]] 0]
    catch {ase::ui::set_plot_dest $key replace}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

## (d) R4: a hand load in between: the next attach is never the same data
group PV4 {
    set key [pv_session pv4 tbpv4 {} 10e-9 1.0]
    pcall wviewer::open $key
    pv_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::dp_finish $key {v(a)}
    pcall ase::ui::dp_finish $key {v(b)}
    update
    check "PV4 fixture: the second Direct Plot was the same data" [pv_same $key] 1
    set other [file join $::scratch pv4 other.raw]
    pv_tran $other 20e-9 5.0
    pv_zoom $key 0 x 2e-9 4e-9
    ## the Location bar loads another file: today's rebuild, unchanged
    check "PV4 the Location bar loads another raw" [pcall wviewer::rawbar_load $key $other] 1
    update
    check "PV4 ...and fits it, as it always did, and drops the record" \
        [list [lsort -unique [lmap r [pv_axes $key] {lrange $r 0 1}]] [pv_same $key]] [list [list [pv_n 0 20e-9]] NOREC]
    ## ...then the session's own file again, by hand: the data is the session's
    ## once more and its database is the current one, so only the dropped record
    ## stops the next attach from claiming the same data
    check "PV4 the Location bar loads the session's raw back" [pcall wviewer::rawbar_load $key $::pv_raw] 1
    update
    pv_zoom $key 0 x 2e-9 4e-9
    set z [pv_byvecs $key]
    pcall ase::ui::dp_finish $key {}
    update
    set a [pv_byvecs $key]
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    check "PV4 a Direct Plot after a hand load is NEW data, even on the attached file (R1 not claimed)" \
        [pv_same $key] 0
    check "PV4 ...the moved X kept, the Y nobody moved fitted over it (not kept as shown)" \
        [list [lrange [pv_at $a v(a)] 0 1] [lrange [pv_at $a v(a)] 2 3] \
              [expr {[lrange [pv_at $a v(a)] 2 3] ne [lrange [pv_at $z v(a)] 2 3]}]] \
        [list [pv_n 2e-9 4e-9] [pv_yfit $key $gi_a] 1]
    ## a load through no door that drops the record (standing for every other
    ## loader): the current database moved, and the verdict sees it
    pcall ase::ui::dp_finish $key {}
    update
    check "PV4 fixture: an attach with nothing in between is the same data again" [pv_same $key] 1
    ## a window where the Y shown is NOT the fit over it, so a refit shows
    pv_zoom $key 0 x 6e-9 8e-9
    set z [pv_byvecs $key]
    pcall wviewer::switch_ctx $key
    pcall xschem raw read $other tran
    check "PV4 a raw read straight into the viewer's context makes it the current one" \
        [pv_curdb] [file normalize $other]
    pcall ase::ui::dp_finish $key {}
    update
    set a [pv_byvecs $key]
    set gi_a [lsearch -exact [pv_vecs $key] v(a)]
    check "PV4 ...so the next Direct Plot is new data: the moved X kept, Y fitted over it" \
        [list [pv_same $key] [lrange [pv_at $a v(a)] 0 1] [lrange [pv_at $a v(a)] 2 3] \
              [expr {[lrange [pv_at $a v(a)] 2 3] ne [lrange [pv_at $z v(a)] 2 3]}]] \
        [list 0 [pv_n 6e-9 8e-9] [pv_yfit $key $gi_a] 1]
    ## the record goes with the window
    catch {wviewer::close $key}
    update
    check "PV4 closing the viewer drops the record with the rest of its per-window state" \
        [list [pv_record $key] [info exists ::wviewer::attached($key)]] {{} 0}
    catch {ase::session_close $key}
}

## (e) R3 ACROSS SUBWINDOWS (issue 1733 review). The run-end plot and `~`
## rebuild the whole tab, so a strip in a subwindow the plot did not touch must
## show exactly what it showed, whatever the destination. The strips of the
## subwindow Replace empties take their view from THAT subwindow's old strips
## only, matched by traces, never from a strip elsewhere that holds the same
## traces. New SubWin keeps every subwindow already there. Another analysis on
## the re-run is another plot, so nothing the user moved on the old one is kept.
proc pv_sw {key} {
    set gs [pv_gs $key]
    if {[string match ERR:* $gs]} { return $gs }
    if {[catch {lmap G $gs { wviewer::gsw $G }} v]} { return [pv_err $v] }
    return $v
}
## {subwindow tag -> {strip traces -> axes}}: every strip, by where it is and
## what it holds
proc pv_bysw {key} {
    set o {}
    if {[catch {
        foreach s [pv_sw $key] v [pv_vecs $key] a [pv_axes $key] { dict set o $s $v $a }
    } e]} { return [pv_err $e] }
    return $o
}
proc pv_outs {key outs} {
    set st [ase::session_state $key]
    dict set st outputs $outs
    ase::session_update $key $st
}
group PV5 {
    set outs {{name A expr v(a) save 1 plot 1} {name B expr v(b) save 1 plot 1}}
    set key [pv_session pv5 tbpv5 $outs 10e-9 1.0]
    pcall wviewer::open $key
    pv_ready $key
    ## (1) the same rows in two subwindows; the second zoomed; a row unticked;
    ## Replace into the first
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::set_plot_dest $key newsubwin
    pcall ase::ui::plot_outputs $key
    update
    check "PV5 fixture: two subwindows, each holding the run's two rows in strips of their own" \
        [list [pv_sw $key] [pv_vecs $key]] {{1 1 2 2} {v(b) v(a) v(b) v(a)}}
    pv_zoom $key 2 x 6e-9 8e-9
    set z [pv_bysw $key]
    check "PV5 fixture: the second subwindow zoomed to 6n..8n, the first as fitted" \
        [list [pv_swx $z 2] [pv_swx $z 1]] [list [list [pv_n 6e-9 8e-9]] [list [pv_n 0 1e-8]]]
    pv_outs $key {{name A expr v(a) save 1 plot 1} {name B expr v(b) save 1 plot 0}}
    pcall ase::ui::set_plot_dest $key replace
    pcall wviewer::set_target_strip 0 $key
    pcall ase::ui::plot_outputs $key
    update
    set a [pv_bysw $key]
    check "PV5 fixture: Replace put the one ticked row into the first subwindow, the same data" \
        [list [pv_same $key] [pv_sw $key] [pv_vecs $key]] {1 {1 2 2} {v(a) v(b) v(a)}}
    check "PV5 Replace: the subwindow it did not touch shows EXACTLY what it showed, strip by strip" \
        [pv_at $a 2] [pv_at $z 2]
    check "PV5 ...and the strip it put back takes its OWN subwindow's old view, not the other's zoom" \
        [pv_at $a 1 v(a)] [pv_at $z 1 v(a)]

    ## (2) one strip of both rows in the first subwindow, one strip per row in
    ## the second (zoomed); Replace into the first in multi-plot
    pv_outs $key $outs
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::set_plot_dest $key newsubwin
    pcall wviewer::set_plot_mode multi $key
    pcall ase::ui::plot_outputs $key
    update
    check "PV5 fixture: one strip of both rows, then a subwindow of one strip per row" \
        [list [pv_sw $key] [pv_vecs $key]] {{1 2 2} {{v(a) v(b)} v(b) v(a)}}
    pv_zoom $key 1 x 6e-9 8e-9
    set z [pv_bysw $key]
    check "PV5 fixture: the second subwindow zoomed to 6n..8n" [pv_swx $z 2] [list [pv_n 6e-9 8e-9]]
    pcall ase::ui::set_plot_dest $key replace
    pcall wviewer::set_target_strip 0 $key
    pcall ase::ui::plot_outputs $key
    update
    set a [pv_bysw $key]
    check "PV5 fixture: Replace in multi-plot gave the first subwindow a strip per row" \
        [list [pv_same $key] [pv_sw $key] [pv_vecs $key]] {1 {1 1 2 2} {v(b) v(a) v(b) v(a)}}
    check "PV5 Replace: the second subwindow shows EXACTLY what it showed" [pv_at $a 2] [pv_at $z 2]
    check "PV5 ...and the first subwindow's new strips are not given the second's zoom (they fit)" \
        [pv_swx $a 1] [list [pv_n 0 1e-8]]

    ## (3) New SubWin: every subwindow already there keeps its view, on the same
    ## data and after a re-run
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pv_zoom $key 0 x 2e-9 4e-9
    set z [pv_axes $key]
    check "PV5 fixture: one strip, zoomed to 2n..4n" [lrange [lindex $z 0] 0 1] [pv_n 2e-9 4e-9]
    pcall ase::ui::set_plot_dest $key newsubwin
    pcall ase::ui::plot_outputs $key
    update
    set a [pv_axes $key]
    check "PV5 New SubWin, the same data: the first subwindow's strip shows EXACTLY what it showed" \
        [list [pv_same $key] [pv_sw $key] [lindex $a 0]] [list 1 {1 2} [lindex $z 0]]
    check "PV5 ...and the new subwindow's strip fits (nothing of its own to take from)" \
        [lrange [lindex $a 1] 0 1] [pv_n 0 1e-8]
    ## zoomed again, so the re-run row below does not lean on the row above
    pv_zoom $key 0 x 2e-9 4e-9
    set z [pv_axes $key]
    check "PV5 fixture: a same-size rewrite (the re-run)" [pv_rewrite 10e-9 2.0 7] {1 0}
    pcall ase::ui::plot_outputs $key
    update
    set a [pv_axes $key]
    check "PV5 New SubWin after the re-run: the zoomed strip keeps its X, its Y fitted to the new data" \
        [list [pv_same $key] [pv_sw $key] [lrange [lindex $a 0] 0 1] [lrange [lindex $a 0] 2 3]] \
        [list 0 {1 2 3} [pv_n 2e-9 4e-9] [pv_yfit $key 0]]
    check "PV5 ...a Y that really moved with the data (not what it showed)" \
        [expr {[lrange [lindex $a 0] 2 3] ne [lrange [lindex $z 0] 2 3]}] 1
    check "PV5 ...the strip nobody zoomed, and the new one, fit the new data" \
        [list [lrange [lindex $a 1] 0 1] [lrange [lindex $a 2] 0 1] [lrange [lindex $a 1] 2 3]] \
        [list [pv_n 0 1e-8] [pv_n 0 1e-8] [pv_yfit $key 1]]

    ## (4) the re-run is another analysis: another plot, nothing kept
    pcall ase::ui::set_plot_dest $key replace
    pv_outs $key {{name A expr v(a) save 1 plot 1}}
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pv_zoom $key 0 y 0.25 0.5
    pv_zoom $key 0 x 2e-9 4e-9
    check "PV5 fixture: a tran strip zoomed in X and in Y" [pv_axes $key] [list [pv_n 2e-9 4e-9 0.25 0.5]]
    set st [ase::session_state $key]
    dict set st analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 start 1e3 stop 1e6 points 10} {type tran enabled 0 stop 10m step 100u}}
    ase::session_update $key $st
    file stat $::pv_raw pv5a
    pv_ac $::pv_raw 1e3 1e6
    file mtime $::pv_raw [expr {$pv5a(mtime) + 9}]
    check "PV5 fixture: the re-run is an ac analysis, written where the tran was" \
        [list [pcall ase::plot_sim_type [ase::session_state $key]] [pcall ase::last_rawfile $key]] [list ac $::pv_raw]
    pcall ase::ui::plot_outputs $key
    update
    set a [lindex [pv_axes $key] 0]
    check "PV5 another analysis under Replace: the strip is the engine's fit of the new data, X and Y" \
        [list [pv_same $key] [pv_vecs $key] [lrange $a 0 1] [lrange $a 2 3]] \
        [list 0 v(a) [pv_xfit $key 0] [pv_yfit $key 0]]
    check "PV5 ...which is not the transient's Y window (the fit really differs from it)" \
        [expr {[lrange $a 2 3] ne {0.25 0.5}}] 1
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

## (f) R3 WITH NOTHING TICKED. `~` under Replace with no row ticked empties the
## target subwindow down to one empty auto strip (R-OUT14) and never reaches
## attach_raw (auto_plot's zero-rows branch); every OTHER subwindow must still
## show exactly what it showed, on both axes. The zoom is put on the rects only,
## and is measured to differ from what a refit would show. "Never reaches
## attach_raw" is seen by a spy on the real proc, not read off the attach
## record: an attach of the same data leaves the record as it was.
##
## The spy: every call of wviewer::attach_raw while `script` runs is recorded
## in ::pv_attached and handed on to the real proc, put back afterwards
## whatever happens. It takes the real proc's arguments, pinned by a row: a
## narrower stand-in would turn every call into an error the caller's catch
## swallows. The spy sees only what runs inside `script`, so the guarded press
## takes the band's `update` in with it: an attach the press defers to idle
## time or to a timer already due by then (`after idle`, `after 0`) is seen.
## A timer that falls due after that one `update` escapes the spy (declared).
proc pv_spy_attach {script} {
    set ::pv_attached {}
    if {[info commands ::wviewer::pv_attach_real] ne {}} { return ERR:spy_nested }
    rename ::wviewer::attach_raw ::wviewer::pv_attach_real
    proc ::wviewer::attach_raw {token rawfile sim_type {vcdfiles {}}} {
        lappend ::pv_attached [list $token $rawfile $sim_type $vcdfiles]
        return [::wviewer::pv_attach_real $token $rawfile $sim_type $vcdfiles]
    }
    set rc [catch {uplevel 1 $script} r]
    rename ::wviewer::attach_raw {}
    rename ::wviewer::pv_attach_real ::wviewer::attach_raw
    if {$rc} { return [pv_err $r] }
    return $r
}
## a proc's arguments, each with its default when it has one (info args,
## info default)
proc pv_sig {p} {
    if {[catch {info args $p} as]} { return [pv_err $as] }
    lmap a $as { if {[info default $p $a d]} { list $a $d } else { list $a } }
}
group PV6 {
    set outs {{name A expr v(a) save 1 plot 1} {name B expr v(b) save 1 plot 1}}
    set key [pv_session pv6 tbpv6 $outs 10e-9 1.0]
    pcall wviewer::open $key
    pv_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::set_plot_dest $key newsubwin
    check "PV6 the attach_raw spy takes the real attach_raw's arguments (info args, info default)" \
        [pv_spy_attach { pv_sig ::wviewer::attach_raw }] [pv_sig ::wviewer::attach_raw]
    pv_spy_attach { pcall ase::ui::plot_outputs $key }
    set ctl $::pv_attached
    update
    check "PV6 control: the spy sees the attach a press with rows ticked makes (one call, the session's raw)" \
        [list [llength $ctl] [lindex $ctl 0 1] [info commands ::wviewer::pv_attach_real]] [list 1 $::pv_raw {}]
    check "PV6 fixture: two subwindows, each holding the run's two rows in auto strips of their own" \
        [list [pv_sw $key] [pv_vecs $key] \
              [pv_auto $key]] \
        {{1 1 2 2} {v(b) v(a) v(b) v(a)} {1 1 1 1}}
    pv_zoom $key 2 x 6e-9 8e-9
    pv_zoom $key 3 y 0.25 0.5
    set z [pv_bysw $key]
    check "PV6 fixture: the second subwindow zoomed to 6n..8n, its v(a) strip to 0.25..0.5 in Y" \
        [list [pv_swx $z 2] [lrange [pv_at $z 2 v(a)] 2 3]] [list [list [pv_n 6e-9 8e-9]] {0.25 0.5}]
    check "PV6 distinctness: what a refit of those strips would show is not what they show" \
        [list [expr {[pv_xfit $key 2] ne [pv_n 6e-9 8e-9]}] [expr {[pv_yfit $key 3] ne {0.25 0.5}}] \
              [expr {[pv_xfit $key 3] ne [pv_n 6e-9 8e-9]}]] {1 1 1}
    pv_outs $key {{name A expr v(a) save 1 plot 0} {name B expr v(b) save 1 plot 0}}
    pcall ase::ui::set_plot_dest $key replace
    pcall wviewer::set_target_strip 0 $key
    set rec0 [pv_record $key]
    pv_spy_attach { pcall ase::ui::plot_outputs $key ; update }
    set att $::pv_attached
    set a [pv_bysw $key]
    check "PV6 fixture: nothing ticked under Replace left the first subwindow one empty auto strip" \
        [list [pv_sw $key] [pv_vecs $key] [pv_auto $key]] {{1 2 2} {{} v(b) v(a)} {1 1 1}}
    check "PV6 ...and called attach_raw not once (the spy), the attach record left as it was" \
        [list $att [expr {[pv_record $key] eq $rec0}]] {{} 1}
    check "PV6 Replace with nothing ticked: the subwindow it did not touch shows EXACTLY what it showed, strip by strip" \
        [pv_at $a 2] [pv_at $z 2]
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}
} else {
    puts "SKIP: display-only bands [join $::pv_disp ,] (no Tk on this arm)"
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
        check "PR6 the live tip is the new label" $tip {Plot outputs and update values (Ctrl-click: values only)}
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
    ## A real Ctrl-click: the press and release carry the Control bit.
    proc pr_ctrl_click {b} {
        event generate $b <Enter> -x 5 -y 5
        event generate $b <ButtonPress-1> -x 5 -y 5 -state 4
        event generate $b <ButtonRelease-1> -x 5 -y 5 -state 4
        event generate $b <Leave>
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
    }
    proc pr_blank {key} {
        set res [ase::session_getattr $key results]
        dict unset res T_1pc_setl_BG
        ase::session_setattr $key results $res
        ase::ui::refresh_output_values $key
    }
    group PR13 {
        set top [ase::ui::window_for $key]
        check "PR13 the live ~ carries the Ctrl-click binding, which evaluates and breaks" \
            [bind $top.strip.plot <Control-Button-1>] \
            "[list ase::ui::evaluate_outputs $key] ; break"
        check "PR13 fixture: the viewer is UP and holds the plot" \
            [list [expr {[wviewer::window_for $key] ne {}}] [lindex [pr_auto $key] 0]] \
            [list 1 $::pr_want]
        ## a spy on the one plotting door: it still plots, it also counts
        set ::pr13_ap 0
        rename ::ase::ui::auto_plot ::pr13_ap_orig
        proc ::ase::ui::auto_plot {key} { incr ::pr13_ap ; return [::pr13_ap_orig $key] }
        set lay0 [wviewer::layout_for $key]
        set tabs0 [wviewer::tab_records $key]
        set tgt0 [wviewer::target_index $key]
        pr_blank $key
        check "PR13 fixture: the row is blank before the Ctrl-click" [pr_cell $key T_1pc_setl_BG] {}
        pr_ctrl_click $top.strip.plot
        set want [ase::format_value [format %.6e [dict get $::pr_ref value]]]
        check "PR13 a real Ctrl-click brings the Value back" [pr_cell $key T_1pc_setl_BG] $want
        check "PR13 ...never reaches the plot door, and leaves the viewer's layout, tabs and target byte-identical" \
            [list $::pr13_ap [expr {[wviewer::layout_for $key] eq $lay0}] \
                  [expr {[wviewer::tab_records $key] eq $tabs0}] \
                  [expr {[wviewer::target_index $key] == $tgt0}]] {0 1 1 1}
        catch {wviewer::close $key}
        update
        pr_blank $key
        pr_ctrl_click $top.strip.plot
        check "PR13 with the viewer CLOSED a Ctrl-click opens none, and still evaluates" \
            [list [wviewer::window_for $key] [pr_cell $key T_1pc_setl_BG]] [list {} $want]
        pr_click $top.strip.plot
        check "PR13 (control) a plain click then reaches the plot door once, opens the viewer and plots" \
            [list $::pr13_ap [expr {[wviewer::window_for $key] ne {}}] [lindex [pr_auto $key] 0]] \
            [list 1 1 $::pr_want]
        rename ::ase::ui::auto_plot {}
        rename ::pr13_ap_orig ::ase::ui::auto_plot
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
    ## R-OUT14 on the real viewer: the auto strips' trace lists, top first.
    proc pr_autos {key} {
        if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return [list ERR:$gs] }
        ## the marker is read straight off the model, so this reader does not
        ## depend on the code under test
        set out {}
        foreach g $gs {
            if {[wviewer::dget $g auto 0] ne {1}} { continue }
            if {[catch {lmap tr [wviewer::dget $g traces {}] {dict get $tr expr}} ex]} { set ex ERR:$ex }
            lappend out $ex
        }
        return $out
    }
    group PR11 {
        set top [ase::ui::window_for $key]
        check "PR11 fixture: the viewer is UP in single-plot with several ticked signals" \
            [list [expr {[wviewer::window_for $key] ne {}}] [wviewer::plot_mode $key] \
                  [expr {[llength $::pr_want] > 1}]] {1 single 1}
        set n0 [llength [dict get [wviewer::layout_for $key] graphs]]
        wviewer::set_plot_mode multi $key
        pr_click $top.strip.plot
        set per {}
        foreach e [lreverse $::pr_want] { lappend per [list $e] }
        check "PR11 multi-plot: a real click on ~ gives each ticked signal its own strip, newest on top" \
            [pr_autos $key] $per
        set n1 [llength [dict get [wviewer::layout_for $key] graphs]]
        check "PR11 ...the viewer grew by exactly the strips the signals needed" \
            [expr {$n1 - $n0}] [expr {[llength $::pr_want] - 1}]
        ase::ui::do_run $key
        set rc [ase::wait [ase::session_getattr $key run_id]]
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
        check "PR11 the run-end auto-plot in multi-plot replaces them: same strips, one signal each" \
            [list $rc [pr_autos $key] [llength [dict get [wviewer::layout_for $key] graphs]]] \
            [list 0 $per $n1]
        wviewer::set_plot_mode single $key
        pr_click $top.strip.plot
        check "PR11 back in single-plot, ~ puts them in ONE strip again and the extra strips go" \
            [list [pr_autos $key] [llength [dict get [wviewer::layout_for $key] graphs]]] \
            [list [list $::pr_want] $n0]
    }
    ## R-OUT15 on the real bench: the status bar's drop-down, chosen by a real
    ## <<ComboboxSelected>>, decides where a real click on `~` (and the run-end
    ## auto-plot) puts the ticked signals: the viewer's tabs, subwindows and
    ## strips are read back after each press.
    proc pr_dest {top lab} {
        $top.status.dest set $lab
        event generate $top.status.dest <<ComboboxSelected>>
        update
    }
    ## {tabs subwindows target-subwindow {per-strip {auto traces}}} of the active tab
    proc pr_view {key} {
        if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return ERR:$gs }
        set strips {}
        foreach g $gs {
            if {[catch {lmap tr [wviewer::dget $g traces {}] {dict get $tr expr}} ex]} { set ex ERR }
            lappend strips [list [wviewer::dget $g auto 0] $ex]
        }
        return [list [llength [wviewer::tab_records $key]] [wviewer::sw_count $gs] \
                     [wviewer::sw_index $gs [wviewer::target_index $key]] $strips]
    }
    proc pr_rects {key} {
        xschem new_schematic switch [wviewer::window_for $key].drw
        return [list [pcall xschem get graph_rects] \
                     [llength [dict get [wviewer::layout_for $key] graphs]]]
    }
    group PR12 {
        set top [ase::ui::window_for $key]
        check "PR12 fixture: the viewer is up in single-plot, the drop-down reads Replace" \
            [list [expr {[wviewer::window_for $key] ne {}}] [wviewer::plot_mode $key] \
                  [$top.status.dest get]] {1 single Replace}
        set t0 [llength [wviewer::tab_records $key]]
        pr_dest $top Replace
        pr_click $top.strip.plot
        set one [list 1 $::pr_want]
        check "PR12 Replace: one subwindow, the run's signals in ONE auto strip" \
            [pr_view $key] [list $t0 1 0 [list $one]]
        pr_dest $top {New SubWin}
        check "PR12 the drop-down wrote the session state" [ase::ui::plot_dest $key] newsubwin
        pr_click $top.strip.plot
        check "PR12 New SubWin: a second subwindow, made the target, holds the run; the first keeps its plot" \
            [pr_view $key] [list $t0 2 1 [list $one $one]]
        check "PR12 ...on the canvas: one graph rect per strip, the two in different X groups" \
            [list [pr_rects $key] [expr {[pcall xschem getprop rect 2 0 xgroup] ne [pcall xschem getprop rect 2 1 xgroup]}]] \
            {{2 2} 1}
        pr_dest $top Append
        pr_click $top.strip.plot
        check "PR12 Append: the target subwindow's strip gains the signals again, the first subwindow untouched" \
            [pr_view $key] [list $t0 2 1 [list $one [list 1 [concat $::pr_want $::pr_want]]]]
        pr_dest $top {New Win}
        pr_click $top.strip.plot
        set recs [wviewer::tab_records $key]
        check "PR12 New Win: a new viewer tab holding the run in one subwindow" \
            [pr_view $key] [list [expr {$t0 + 1}] 1 0 [list $one]]
        if {[catch {wviewer::sw_count [dict get [lindex $recs end-1] layout graphs]} pr_n2]} {
            set pr_n2 ERR:$pr_n2
        }
        check "PR12 ...and the tab it left still holds its two subwindows" $pr_n2 2
        pr_dest $top {New SubWin}
        ase::ui::do_run $key
        set rc [ase::wait [ase::session_getattr $key run_id]]
        for {set i 0} {$i < 40} {incr i} { update ; after 50 }
        check "PR12 the run-end auto-plot honours it too: a real run under New SubWin adds a subwindow" \
            [list $rc [pr_view $key]] [list 0 [list [expr {$t0 + 1}] 2 1 [list $one $one]]]
        pr_dest $top Replace
        check "PR12 back on Replace the state holds the default, empty" \
            [list [ase::ui::plot_dest $key] [dict get [ase::session_state $key] plot_dest]] {replace {}}
        pr_click $top.strip.plot
        check "PR12 Replace empties only the TARGET subwindow" \
            [pr_view $key] [list [expr {$t0 + 1}] 2 1 [list $one $one]]
    }
    ## THE SHIPPED DRAW, SEEDED, AND A TOLERANCE NO SOLVER MEETS.  The
    ## committed state's own variables and models (ABSVAR 0.03, VCC by agauss,
    ## section tt_mm), `.options seed=35`, and `.options reltol=1e-12`.
    ##
    ## ⚠ UNTIL 2026-10-26 SEED 35 ALONE STOPPED THIS TRANSIENT, AND THE CAUSE WAS
    ## A SIMULATOR DEFECT, NOT THE DRAW. Measured 2026-10-27 on the deck this
    ## group renders, with binaries built at each ver_51 commit: 45.2 and the
    ## fork at ae2223e41 stop with "Timestep too small" (rc 1) at ~60-80 ns on a
    ## `sky130_fd_pr__pnp` node; from fork commit 4e614b4da ("Carry the R model
    ## through the R->B rewrite", which names sky130 xhigh_po resistors) on, the
    ## same deck runs to 200 us with rc 0. The draw itself did not move (VCC
    ## reads 1.81022 at the op point on 45.2, ae2223e41, 4e614b4da and the
    ## registry fork), and seeds 1-60 ALL run clean on the registry fork, so no
    ## re-chosen seed is a fixture. What this group fences is the product's
    ## answer to a transient that stops after the op point was written, so the
    ## stop is now asked for by name: `reltol=1e-12` stops it at the 25 us START
    ## edge ("Timestep too small; ... trouble with node vcc#branch") on the
    ## registry fork, on 45.2 and on ae2223e41 alike -- independent of the draw
    ## and of the defect. The first fixture row still asserts the stop, so a
    ## simulator that one day meets the tolerance reddens HERE, by name.
    group PF1 {
        set fh [open [file join $repo $staterel]]
        set shipped [read $fh]
        close $fh
        set st [ase::session_state $key]
        dict set st variables [dict get $shipped variables]
        dict set st models [dict get $shipped models]
        set op [ase::state_get $st options]
        lappend op [dict create name seed value 35]
        lappend op [dict create name reltol value 1e-12]
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
        check "PF1 fixture: the shipped draw at seed 35 under reltol=1e-12 stops the transient (rc 1, Timestep too small)" \
            [list $rc [expr {[llength $why] > 0}]] {1 1}
        check "PF1 fixture: the raw is still newer than the deck, so has_results answers 1" \
            [ase::has_results $key] 1
        set f [ase::run_failed $key]
        check "PF1 run_failed names the exit code and the log" $f [dict create exit 1 log $lf]
        set said [ase::ui::lbl_run_failed $f]
        check "PF1 the user is told the run failed, and where the log is" \
            [expr {$said in $::po_echoes}] 1
        check "PF1 ...once, and with no 'simulation finished (exit' line beside it" \
            [list [po_count $said] [po_count {*finished (exit*}]] {1 0}
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
