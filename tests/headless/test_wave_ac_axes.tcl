# tests/headless/test_wave_ac_axes.tcl -- an AC result sent to the waveform
# viewer gets a log frequency axis, and a trace in dB (or in degrees) says so on
# its Y numbers.
#
# The user (2026-11-09): "When AC analysis result plots are sent by ASE-L to
# Waveform Viewer, the axes should be set appropriately ... For a waveform that
# is obviously in dB for the measure, the Y axis should be in units of dB, and
# likewise, the X-axis should be logarithmic frequency."
#
# Code     src/wave_viewer.tcl wviewer::trace_yunit, wviewer::axis_hint,
#          wviewer::axis_apply (the decision, pure), wviewer::trace_simtype and
#          wviewer::add_trace (the act), wviewer::graph_props (the rect text);
#          src/draw.c setup_graph_data / draw_graph_grid / graph_fixed_margins
#          (the `yunit` rect token)
# Fixture  on the display arm, the bundled bench
#          sky130A/xschem_libs/sky130_tests_ase/tb_ft_test_2 run for real on the
#          registry ngspice, AC only; tests/headless/data/calc_fixture.raw (tran)
#
# Bands (both arms; pure, no Tk)
#   AX1  trace_yunit: every dB spelling the plot paths hand add_trace (the
#        Calculator's dB20/dB10 translations, ASE-L rows through
#        ase::ui::plot_map_expr), every phase spelling, and linear controls
#   AX2  axis_hint: AC gives log X; a unit only when every trace shares it; a
#        trace on its own X column gets no log X; non-AC is never touched
#   AX3  axis_apply: a fresh strip takes the hint outright and blanks a range
#        kept from the other axis kind; a strip with traces keeps the user's
#        logx and loses a unit the new trace does not share
#   AX4  graph_props writes logx, the decade minor lines and `yunit` only when
#        set; a linear strip's rect text has no `yunit` and subdivx=1
# Bands (display arm only)
#   AR1  tb_ft_test_2 runs AC on the registry ngspice
#   AR2  multi-plot `~`: the dB row's strip is log X with yunit=dB; the current
#        rows' strips are log X with no unit; X spans the analysis in decades
#   AR3  the C engine takes the token: the dB strip's plot box starts further
#        right than the same strip with the token removed, and its Y numbers'
#        ink is wider
#   AR4  single-plot `~`: one strip, log X, no unit (the rows are mixed)
#   AR5  a phase column plotted through wviewer::plot_signals (the Calculator's
#        entry) lands as yunit=deg; a dB RPN as yunit=dB
#   AR6  a transient result is unchanged: linear X, no unit, subdivx=1
#
# REGISTERED IN `hcases` AND `dcases`.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_wave_ac_axes
#   tests/headless/run_suites.sh test_wave_ac_axes

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
proc dg {d k} {
    if {[catch {dict exists $d $k} e] || !$e} { return ABSENT }
    return [dict get $d $k]
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch wave_ac_axes]
set GUI [expr {[info commands toplevel] ne {} && [info commands winfo] ne {}}]
set fh [open [file normalize [info script]]]
set ::ax_src [read $fh]
close $fh
set ::ax_disp {}
foreach {- b} [regexp -all -inline -line {^\s*group\s+(AR[0-9]+)\s} $::ax_src] {
    lappend ::ax_disp $b
}

# =============================================================================
# THE DECISION (both arms)
# =============================================================================
group AX1 {
    foreach {ex want} {
        {i(vd) i(vg) / abs() db20()}   dB
        {v(out) abs() db20()}          dB
        {v(out) db20()}                dB
        {v(out) abs() log10() 10 *}    dB
        {v(out) abs() log10() 20 *}    dB
        {dB20(v(out))}                 dB
        {db(v(out))}                   dB
        {vdb(out)}                     dB
        {ph(out)}                      deg
        {ph(i(vd))}                    deg
        {v(out) cph()}                 deg
        {phase(v(out))}                deg
        {phaseDeg(v(out))}             deg
        {vp(out)}                      deg
        {v(out)}                       {}
        {i(vd)}                        {}
        {out}                          {}
        {v(out) abs()}                 {}
        {v(out) abs() log10()}         {}
        {v(out) abs() log10() 3 *}     {}
        {phaseRad(v(out))}             {}
        {dbname}                       {}
        {}                             {}
    } {
        check "AX1 trace_yunit [list $ex]" [pcall wviewer::trace_yunit $ex] $want
    }
    ## the ASE-L rows the bundled benches really carry, through the same mapping
    ## auto_plot applies before add_trace sees them
    foreach {row want} {
        {db(if(vd)/if(vg))}  dB
        {dB20(vf(out))}      dB
        {dB10(vf(out))}      dB
        {ph(out)}            deg
        {out}                {}
        {mag(vf(out))}       {}
    } {
        set m [pcall ase::ui::plot_map_expr $row]
        check "AX1 ASE-L row [list $row] -> [list $m] reads $want" \
            [pcall wviewer::trace_yunit $m] $want
    }
}

group AX2 {
    check "AX2 AC, one dB trace: log X, dB" \
        [pcall wviewer::axis_hint ac {{v(o) db20()}}] {logx 1 yunit dB}
    check "AX2 AC, one phase trace: log X, deg" \
        [pcall wviewer::axis_hint ac {ph(o)}] {logx 1 yunit deg}
    check "AX2 AC, a linear magnitude keeps a linear Y" \
        [pcall wviewer::axis_hint ac {v(o)}] {logx 1 yunit {}}
    check "AX2 AC, two dB traces share the unit" \
        [pcall wviewer::axis_hint ac {{v(a) db20()} {v(b) abs() db20()}}] {logx 1 yunit dB}
    check "AX2 AC, dB with phase: no single unit" \
        [pcall wviewer::axis_hint ac {{v(a) db20()} ph(a)}] {logx 1 yunit {}}
    check "AX2 AC, dB with a linear magnitude: no single unit" \
        [pcall wviewer::axis_hint ac {{v(a) db20()} v(a)}] {logx 1 yunit {}}
    check "AX2 AC, a trace on its own X column gets no log X" \
        [pcall wviewer::axis_hint ac {{v(o) db20()}} {calcx}] {logx 0 yunit dB}
    foreach t {tran dc op noise {}} {
        check "AX2 [list $t] is unchanged, even for a dB expression" \
            [pcall wviewer::axis_hint $t {{v(o) db20()} ph(o)}] {logx 0 yunit {}}
    }
    check "AX2 AC with no trace answers linear" [pcall wviewer::axis_hint ac {}] {logx 0 yunit {}}
}

proc ax_G {args} {
    set G [dict create traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
    foreach {k v} $args { dict set G $k $v }
    return $G
}
proc ax_tr {ex} { dict create expr $ex name {} vec $ex color 4 }

group AX3 {
    set G [pcall wviewer::axis_apply [ax_G traces [list [ax_tr {v(o) db20()}]]] 1 ac]
    check "AX3 fresh AC dB strip: logx 1, yunit dB" \
        [list [dg $G logx] [dg $G yunit]] {1 dB}
    set G [pcall wviewer::axis_apply [ax_G traces [list [ax_tr {v(o) db20()}]] \
                                      x1 0 x2 1e-3 y1 -1 y2 1] 1 ac]
    check "AX3 ...a range kept from a linear X and a unitless Y goes back to auto" \
        [lmap k {x1 x2 y1 y2} {dg $G $k}] {{} {} {} {}}
    set G [pcall wviewer::axis_apply [ax_G traces [list [ax_tr {v(o) db20()}]] \
                                      logx 1 yunit dB x1 3 x2 9 y1 -40 y2 0] 1 ac]
    check "AX3 ...a reused AC dB strip keeps its zoom" \
        [lmap k {logx yunit x1 x2 y1 y2} {dg $G $k}] {1 dB 3 9 -40 0}
    set G [pcall wviewer::axis_apply [ax_G traces [list [ax_tr v(o)]] \
                                      logx 1 yunit dB x1 3 x2 9 y1 -40 y2 0] 1 tran]
    check "AX3 an AC strip reused by a transient run is linear again, unit and range gone" \
        [lmap k {logx yunit x1 x2 y1 y2} {dg $G $k}] {0 ABSENT {} {} {} {}}
    set G [pcall wviewer::axis_apply [ax_G traces [list [ax_tr v(o)]]] 1 tran]
    check "AX3 a fresh transient strip is untouched" $G [ax_G traces [list [ax_tr v(o)]]]
    ## a strip that already held a trace
    set G [pcall wviewer::axis_apply [ax_G logx 0 yunit dB traces \
              [list [ax_tr {v(a) db20()}] [ax_tr {v(b) db20()}]]] 0 ac]
    check "AX3 a second dB trace keeps the unit, and the user's linear X stays" \
        [list [dg $G logx] [dg $G yunit]] {0 dB}
    set G [pcall wviewer::axis_apply [ax_G logx 1 yunit dB traces \
              [list [ax_tr {v(a) db20()}] [ax_tr ph(a)]]] 0 ac]
    check "AX3 a phase trace added to a dB strip drops the unit, log X stays" \
        [list [dg $G logx] [dg $G yunit]] {1 ABSENT}
    set G [pcall wviewer::axis_apply [ax_G logx 1 traces \
              [list [ax_tr v(a)] [ax_tr {v(a) db20()}]]] 0 ac]
    check "AX3 a dB trace added to a unitless strip adds no unit" [dg $G yunit] ABSENT
}

group AX4 {
    set lin [pcall wviewer::graph_props [ax_G traces [list [ax_tr v(o)]]]]
    check "AX4 a linear strip: logx=0, subdivx=1, no yunit token" \
        [list [regexp -line {^logx=0$} $lin] [regexp -line {^subdivx=1$} $lin] \
              [regexp {yunit} $lin]] {1 1 0}
    set ac [pcall wviewer::graph_props [ax_G logx 1 yunit dB traces [list [ax_tr {v(o) db20()}]]]]
    check "AX4 an AC dB strip: logx=1, subdivx=8, yunit=dB" \
        [list [regexp -line {^logx=1$} $ac] [regexp -line {^subdivx=8$} $ac] \
              [regexp -line {^yunit=dB$} $ac]] {1 1 1}
    set ph [pcall wviewer::graph_props [ax_G logx 1 yunit deg traces [list [ax_tr ph(o)]]]]
    check "AX4 a phase strip: yunit=deg" [regexp -line {^yunit=deg$} $ph] 1
    set bad [pcall wviewer::graph_props [ax_G yunit {d"B x} traces [list [ax_tr v(o)]]]]
    check "AX4 a unit that is not a short word is never written" [regexp {yunit} $bad] 0
}

# =============================================================================
# THE ACT, on the real graph (display arm)
# =============================================================================
set NG /home/analog/dev/ngspice/build-ver_51/src/ngspice
if {!$GUI} {
    puts "SKIP: display-only bands [join $::ax_disp ,] (no Tk on this arm)"
} elseif {![file executable $NG]} {
    puts "skip: [join $::ax_disp ,] the registry ngspice is not at $NG"
} else {
    proc ::ase::echo {msg args} { return }
    source [file join $repo tools migrate op_measures_bench.tcl]
    opm::setup $repo $NG
    set staterel sky130A/xschem_libs/sky130_tests_ase/tb_ft_test_2/ngspice_state1/tb_ft_test_2.state
    set sch [opm::schematic $repo $staterel]
    set key {}
    proc ax_settle {} { for {set i 0} {$i < 20} {incr i} { update ; after 25 } }
    proc ax_strips {key} {
        set out {}
        foreach G [dict get [wviewer::layout_for $key] graphs] {
            lappend out [list [lmap t [dict get $G traces] {dict get $t expr}] \
                              [wviewer::dget $G logx 0] [wviewer::dget $G yunit {}]]
        }
        return $out
    }
    proc ax_rect {key gi tok} {
        wviewer::switch_ctx $key
        return [pcall xschem getprop rect 2 $gi $tok]
    }
    proc ax_strip_of {key ex} {
        set gi 0
        foreach G [dict get [wviewer::layout_for $key] graphs] {
            foreach t [dict get $G traces] { if {[dict get $t expr] eq $ex} { return $gi } }
            incr gi
        }
        return -1
    }
    set DBX {i(vd) i(vg) / abs() db20()}
    group AR1 {
        xschem load $sch
        set key [ase::session_key {*}[ase::design_of_path [file normalize $sch]]]
        catch {ase::session_close $key}
        ase::session_open $key [file join $repo $staterel]
        set st [ase::session_state $key]
        set rd [file join $::scratch bench]
        file mkdir $rd
        dict set st rundir $rd
        ## AC alone, so the viewer shows the AC result (tran would outrank it)
        set an {}
        foreach a [ase::state_get $st analyses] {
            if {[dict get $a type] ne {ac}} { dict set a enabled 0 }
            lappend an $a
        }
        dict set st analyses $an
        ase::session_update $key $st
        set top [ase::ui::open $key sky130_tests_ase tb_ft_test_2 ngspice_state1]
        update
        ase::ui::do_run $key
        set rc [ase::wait [ase::session_getattr $key run_id]]
        ax_settle
        check "AR1 tb_ft_test_2 runs AC on the registry ngspice" \
            [list $rc [ase::plot_sim_type [ase::session_state $key]]] {0 ac}
    }
    group AR2 {
        wviewer::set_plot_mode multi $key
        ase::ui::plot_outputs $key
        ax_settle
        set s [ax_strips $key]
        check "AR2 multi-plot: three strips, the dB row's in dB, all log X" \
            [lsort $s] [lsort [list [list [list $DBX] 1 dB] {i(vd) 1 {}} {i(vg) 1 {}}]]
        set gi [ax_strip_of $key $DBX]
        check "AR2 ...the dB strip's rect carries logx=1 yunit=dB subdivx=8" \
            [lmap t {logx yunit subdivx} {ax_rect $key $gi $t}] {1 dB 8}
        set gc [ax_strip_of $key i(vd)]
        check "AR2 ...a current strip's rect: logx=1, no yunit" \
            [lmap t {logx yunit} {ax_rect $key $gc $t}] {1 {}}
        ## the analysis is 1 kHz .. 1000 GHz: X in decades spans it
        set x1 [ax_rect $key $gi x1]
        set x2 [ax_rect $key $gi x2]
        check "AR2 ...X spans the sweep in decades (log10 1k = 3, log10 1T = 12)" \
            [list [expr {abs($x1 - 3) < 0.01}] [expr {abs($x2 - 12) < 0.01}]] {1 1}
    }
    group AR3 {
        ## the same strip drawn with and without the model's unit (the viewer
        ## is read-only, so the comparison goes through the model and regenerate)
        set gi [ax_strip_of $key $DBX]
        set gs0 [dict get [wviewer::layout_for $key] graphs]
        wviewer::regenerate $key
        ax_settle
        wviewer::switch_ctx $key
        set d1 [pcall xschem get graph_drawn $gi]
        set G [lindex $gs0 $gi]
        wviewer::set_graphs $key [lreplace $gs0 $gi $gi [dict remove $G yunit]]
        wviewer::regenerate $key
        ax_settle
        wviewer::switch_ctx $key
        set d0 [pcall xschem get graph_drawn $gi]
        wviewer::set_graphs $key $gs0
        wviewer::regenerate $key
        ax_settle
        proc ax_inkw {d} {
            set w 0
            foreach b [dg $d ylab_ink] { set v [expr {[lindex $b 2] - [lindex $b 0]}] ; if {$v > $w} { set w $v } }
            return $w
        }
        check "AR3 the record exists both ways" \
            [list [expr {[dg $d1 box] ne {ABSENT}}] [expr {[dg $d0 box] ne {ABSENT}}]] {1 1}
        check "AR3 the dB strip's plot box starts further right (room for the unit)" \
            [expr {[lindex [dg $d1 box] 0] > [lindex [dg $d0 box] 0] + 4}] 1
        check "AR3 ...and its widest Y number is wider" \
            [expr {[ax_inkw $d1] > [ax_inkw $d0] + 4}] 1
        check "AR3 the model's unit is the token: back with the model" \
            [ax_rect $key $gi yunit] dB
    }
    group AR4 {
        wviewer::set_plot_mode single $key
        ase::ui::plot_outputs $key
        ax_settle
        set s [ax_strips $key]
        set mine [lsearch -all -inline -glob $s "*db20()*"]
        check "AR4 single-plot: the rows share one log X strip with no unit" \
            [lmap e $mine {lrange $e 1 2}] {{1 {}}}
    }
    group AR5 {
        set errs [pcall wviewer::plot_signals $key [list {ph(i(vd))}] {} newsubwin]
        ax_settle
        set gp [ax_strip_of $key ph(i(vd))]
        check "AR5 a phase column through plot_signals: yunit=deg, log X" \
            [list $errs [lmap t {logx yunit} {ax_rect $key $gp $t}]] {{} {1 deg}}
        set errs [pcall wviewer::plot_signals $key [list {i(vd) abs() db20()}] {} newsubwin]
        ax_settle
        set gd [ax_strip_of $key {i(vd) abs() db20()}]
        check "AR5 a dB RPN through plot_signals: yunit=dB" \
            [list $errs [ax_rect $key $gd yunit]] {{} dB}
    }
    group AR6 {
        set fx [file join $here data calc_fixture.raw]
        wviewer::attach_raw $key $fx tran
        set errs [pcall wviewer::plot_signals $key [list v(sq)] {} newsubwin]
        ax_settle
        set gt [ax_strip_of $key v(sq)]
        check "AR6 a transient trace: linear X, no unit, subdivx=1" \
            [list $errs [lmap t {logx yunit subdivx} {ax_rect $key $gt $t}]] {{} {0 {} 1}}
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
