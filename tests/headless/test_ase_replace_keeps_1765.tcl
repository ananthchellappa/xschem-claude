# tests/headless/test_ase_replace_keeps_1765.tcl -- the plot destination
# Replace takes out ASE-L's own traces only; what the user plotted by hand
# stays, and after a finished run it goes on showing the run it was plotted
# from until `~` (issue 1765).
#
# The user (2026-11-25): "When the plot mode ... says Replace, and simulation
# finishes or user presses the ~ Plot button, plotting should only replace the
# plots that are specified to be plotted in the Saves pane of ASE-L. That is,
# we don't blank the canvas in Waveform Viewer and only draw these waveforms.
# Those plots that the user plotted manually after the sim should be retained.
# Should they continue to show the waveforms from old sim ...? yes AND no - yes
# for the 'auto plot' that happens because sim finished (BTW, we need to insert
# an option item somewhere in the menu like Cadence ADE-L has - saying WHETHER
# ASE-L should automatically plot after simulation completes. Default can be
# yes.) -- and, no for the case of the user intentionally plotting using the ~
# button. In that case ... we also update the existing user-manually-plotted
# waveforms."
#
# Issue    doc/claude/issues/1765-*.md
# Code     src/wave_viewer.tcl wviewer::owned_indices, owned_drop, owned_clear,
#          auto_plot_strips, hold_manual, hold_release, held_pin, held_plain
#          src/ase_window.tcl ase::ui::auto_plot, auto_plot_idle,
#          set_plot_after_sim; src/ase.tcl ase::plot_after_sim_of
#          src/scheduler.c `xschem raw rekey`
# Fixture  a transient raw written here (rk_tran): v(a) rises 0..amp, v(b)
#          falls amp..0, v(c) = amp/2 + v(a)/4. A "run" is the file written
#          again with another amp and a later time, so v(b)'s first point
#          says which run a trace shows.
#
# Bands (both arms)
#   RP1  which traces are ASE-L's: the marked ones, and every trace of an auto
#        strip from before the marks
#   RP2  the kept names: made, parsed, pinned, and taken off again
#   RP3  the strips ASE-L's plot readies: a trace plotted by hand in an auto
#        strip stays; a surplus auto strip holding one stays as an ordinary
#        strip, an empty one goes; an auto strip from before the marks is
#        emptied; one of ASE-L's traces dragged to a hand strip leaves it;
#        another subwindow is untouched; a target on a strip that goes stays
#        in its subwindow; a strip left empty drops its stored Y and keeps X
#   RP4  the option: its default, the rc variable, the state key written only
#        when it is not the default, one log line on a change
#   RP5  a finished run plots only when the option says so and says `run`;
#        `~` says `user`
#   RP6  `xschem raw rekey`
#   RP7  a pasted copy of one of ASE-L's traces is the user's own
#   RP8  nothing of a kept run is saved
# Bands (display arm only)
#   RK1  the fixture: `~` plots the row; its trace is marked, its strip too
#   RK2  `~` again under Replace: the hand strip and the hand trace inside
#        ASE-L's strip stay, the row comes back once; one undo step
#   RK3  a finished run under Replace: the row shows the new run, what was
#        plotted by hand shows the old one (by the database, by the engine's
#        own fit, by the rect); the legend says so; a zoom on the hand strip
#        is kept; the saved state holds no kept name
#   RK4  a second finished run: a trace kept at the first run stays on the
#        first, one plotted by hand since stays on the second
#   RK5  `~`: every trace shows the result, the kept data is gone
#   RK6  a hand expression: kept with its run, evaluated again by `~`
#   RK7  undo back to a model holding a kept trace, after `~`: the trace comes
#        back as a plain one
#   RK8  the option off: a finished run changes nothing in the viewer; `~`
#        then brings everything to the new run
#   RK9  the menu entry: where it is, what a real click does, the tick
#        following a script; the state file
#   RK10 the other destinations after a run: nothing is kept (as before)
#   RK11 nothing ticked: a run changes nothing; `~` takes out ASE-L's traces,
#        keeps the hand strip and brings it to the result
#   RK12 multi-plot: the hand strip keeps its place among ASE-L's strips
#   RK13 a kept strip zoomed in X, then `~`: the X window stays and Y is
#        fitted to the result (it showed the earlier run's Y window)
#   RK14 a row whose net the new run lacks is refused as with nothing kept,
#        never drawn from the kept run; a hand expression that cannot be
#        evaluated is not kept, and the run that brings its net draws it
#   RK15 a run of another analysis keeps nothing, and what was kept follows it
#   RK16 a hand trace that names the result's own database, beside a plain
#        one: both are kept (the database is renamed once)
#   RK17 a finished run whose file cannot be read: the viewer is as it was
#        (the data under its own name, nothing kept), and the saved state
#        names no kept database
#   RK18 a results file read while it held no point is not kept
#   RK19 the time in a kept trace's legend is the time its data was written;
#        when the window does not know it, the legend says `@earlier`
#
# REGISTERED IN `hcases` AND `dcases`.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_replace_keeps_1765
#   tests/headless/run_suites.sh test_ase_replace_keeps_1765

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
proc group {name script} {
    if {[info exists ::env(ONLY)] && $name ni [split $::env(ONLY) ,]} { return }
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch ase_replace_keeps_1765]
set GUI [expr {[info commands toplevel] ne {} && [info commands winfo] ne {}}]

## every ase::echo and every viewer sentence is recorded
set ::rk_echoes {}
rename ::ase::echo ::rk_echo_orig
proc ::ase::echo {msg args} {
    lappend ::rk_echoes $msg
    return [::rk_echo_orig $msg {*}$args]
}

## A transient raw: time 0..tend, v(a) rising 0..amp, v(b) falling amp..0,
## v(c) = amp/2 + v(a)/4. Binary.
proc rk_tran {path tend amp {np 41}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: rk fixture\nDate: Wed Nov 25 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 4\nNo. Points: $np\nVariables:\n\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\n\t3\tv(c)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set t [expr {$tend * $i / ($np - 1.0)}]
        set a [expr {$amp * $i / ($np - 1.0)}]
        puts -nonewline $f [binary format q4 [list $t $a [expr {$amp - $a}] [expr {$amp / 2.0 + $a / 4.0}]]]
    }
    close $f
}
## The same without v(c) (a run that no longer saves that net)
proc rk_tran_noc {path tend amp {np 41}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: rk fixture\nDate: Wed Nov 25 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 3\nNo. Points: $np\nVariables:\n\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set t [expr {$tend * $i / ($np - 1.0)}]
        set a [expr {$amp * $i / ($np - 1.0)}]
        puts -nonewline $f [binary format q3 [list $t $a [expr {$amp - $a}]]]
    }
    close $f
}
## An AC raw of the same vectors over 1 Hz .. 1 MHz (complex, as ngspice writes it)
proc rk_ac {path {np 21}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: rk fixture\nDate: Wed Nov 25 00:00:00  2026\nPlotname: AC Analysis\nFlags: complex\nNo. Variables: 4\nNo. Points: $np\nVariables:\n\t0\tfrequency\tfrequency\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\n\t3\tv(c)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set fr [expr {pow(10.0, 6.0 * $i / ($np - 1.0))}]
        set m [expr {1.0 / (1.0 + $i)}]
        puts -nonewline $f [binary format q8 [list $fr 0.0 $m 0.0 [expr {2 * $m}] 0.0 [expr {3 * $m}] 0.0]]
    }
    close $f
}
## A transient whose header says it holds no point yet: what a results file
## looks like while its run is writing it
proc rk_tran_empty {path} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: rk fixture\nDate: Wed Nov 25 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 4\nNo. Points: 0\nVariables:\n\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\n\t3\tv(c)\tvoltage\nBinary:\n"
    close $f
}
## the file's time moved `dt` seconds on from what it was (after any writer)
proc rk_later {a0mtime dt} { file mtime $::rk_raw [expr {$a0mtime + $dt}] }
## A session on <scratch>/<sub> whose results file is written by rk_tran.
proc rk_session {sub cell outs amp} {
    set d [file join $::scratch $sub]
    file delete -force $d
    file mkdir $d
    set ::rk_raw [file join $d ${cell}_ase.raw]
    rk_tran $::rk_raw 10e-9 $amp
    set sf [file join $d s.state]
    set f [open $sf w]
    puts $f "version 1"
    puts $f "simulator ngspice"
    puts $f "design {lib rk cell $cell view schematic}"
    puts $f "rundir [list $d]"
    puts $f "temperature 27"
    puts $f "analyses [list {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 10n step 100p}}]"
    puts $f "outputs [list $outs]"
    close $f
    set key rk/$cell/$sub
    catch {ase::session_close $key}
    ase::session_open $key $sf
    return $key
}
## The "run": the results file written again with another amplitude, its time
## moved `dt` seconds on, so the move is certain on any file system clock.
proc rk_rerun {amp dt} {
    file stat $::rk_raw a0
    rk_tran $::rk_raw 10e-9 $amp
    file mtime $::rk_raw [expr {$a0(mtime) + $dt}]
    return [expr {[file mtime $::rk_raw] != $a0(mtime)}]
}
proc rk_outs {key outs} {
    set st [ase::session_state $key]
    dict set st outputs $outs
    ase::session_update $key $st
}
proc rk_gs {key} {
    if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return {} }
    return $gs
}
## the strips as {auto {vec[*] ...}}: a `*` after a vector marks ASE-L's own
proc rk_strips {key} {
    lmap G [rk_gs $key] {
        list [wviewer::dget $G auto 0] [lmap t [wviewer::dget $G traces {}] {
            format %s%s [wviewer::dget $t vec [wviewer::dget $t expr ?]] [expr {[wviewer::dget $t byase 0] eq {1} ? {*} : {}}]
        }]
    }
}
## a hand strip / an auto strip of the model bands: one trace each
proc rk_tr {ex {own 0}} {
    set t [dict create expr $ex name {} vec $ex color 4]
    if {$own} { dict set t byase 1 }
    return $t
}
proc rk_strip {traces args} {
    dict merge [dict create traces $traces logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}] $args
}
proc rk_lay {token mode gs tgt} {
    dict set ::wviewer::layouts $token [dict create sharedx 0 graphs $gs]
    dict set ::wviewer::windows $token top .rk_none
    set ::wviewer::mode($token) $mode
    set ::wviewer::target($token) $tgt
    set ::wviewer::wavehl($token) {}
}
proc rk_unlay {token} {
    catch {dict unset ::wviewer::layouts $token}
    catch {dict unset ::wviewer::windows $token}
    catch {unset ::wviewer::mode($token)}
    catch {unset ::wviewer::target($token)}
    catch {unset ::wviewer::wavehl($token)}
}

# =============================================================================
# RP1 -- WHICH TRACES ARE ASE-L'S
# =============================================================================
group RP1 {
    set own  [rk_strip [list [rk_tr v(a) 1] [rk_tr v(h)] [rk_tr v(b) 1]] auto 1 own 1]
    set old  [rk_strip [list [rk_tr v(a)] [rk_tr v(b)]] auto 1]
    set hand [rk_strip [list [rk_tr v(h)] [rk_tr v(a) 1]]]
    check "RP1 a marked auto strip: the marked traces, not the one plotted by hand" \
        [pcall wviewer::owned_indices $own] {0 2}
    check "RP1 an auto strip from before the marks: every trace" \
        [pcall wviewer::owned_indices $old] {0 1}
    check "RP1 a hand strip: only a trace that carries the mark (one dragged there)" \
        [pcall wviewer::owned_indices $hand] {1}
    check "RP1 a strip with no trace, and something that is no strip: none" \
        [list [pcall wviewer::owned_indices [rk_strip {} auto 1]] [pcall wviewer::owned_indices {not a dict at all x}]] {{} {}}
    check "RP1 owned_less hands back the strip without them, and an untouched strip as it is" \
        [list [lmap t [dict get [pcall wviewer::owned_less $own] traces] {dict get $t vec}] \
              [expr {[pcall wviewer::owned_less [rk_strip [list [rk_tr v(h)]]]] eq [rk_strip [list [rk_tr v(h)]]]}]] \
        {v(h) 1}
    check "RP1 owned_in counts them over a range of strips, and nothing outside it" \
        [list [pcall wviewer::owned_in [list $own $old $hand] 0 2] [pcall wviewer::owned_in [list $own $old $hand] 2 2] \
              [pcall wviewer::owned_in [list $own $old $hand] 1 9]] {5 1 3}
    check "RP1 all_graphs with `o<index>` leaves out ASE-L's traces of that strip only" \
        [pcall apply {{own hand} {
            rk_lay rp1 single [list $own $hand] 0
            set r [lmap G [wviewer::all_graphs rp1 {o0}] {lmap t [dict get $G traces] {dict get $t vec}}]
            rk_unlay rp1
            return $r
        }} $own $hand] {v(h) {v(h) v(a)}}
}

# =============================================================================
# RP2 -- THE KEPT NAMES
# =============================================================================
group RP2 {
    check "RP2 a kept name is the path and a number, and parses back" \
        [list [pcall wviewer::held_name /r/tb_ase.raw 3] [pcall wviewer::held_parse /r/tb_ase.raw@held3]] \
        {/r/tb_ase.raw@held3 {/r/tb_ase.raw 0 3}}
    check "RP2 one a trace named itself says so, and gives its path back" \
        [list [pcall wviewer::held_name /r/d.vcd 4 1] [pcall wviewer::held_parse /r/d.vcd@heldx4]] \
        {/r/d.vcd@heldx4 {/r/d.vcd 1 4}}
    check "RP2 a path the node grammar cannot carry is spelled so that it can, and any other name parses to nothing" \
        [list [pcall wviewer::db_path_safe [pcall wviewer::held_name {/r/my dir/x.raw} 1]] \
              [pcall wviewer::held_parse /r/tb_ase.raw] [pcall wviewer::held_parse /r/x@held] [pcall wviewer::held_parse {}]] \
        {1 {} {} {}}
    set gs [list [rk_strip [list [rk_tr v(a) 1] [rk_tr v(h)]] auto 1 own 1] \
                 [rk_strip [list [rk_tr v(g)] [dict merge [rk_tr d1] {rawfile /r/d.vcd sim_type vcd}] \
                                 [dict create expr v(x) name {} vec {} color 4]]]]
    set map [dict create {} {/r/tb.raw@held1 tran} {/r/d.vcd vcd} /r/d.vcd@heldx2]
    set pinned [pcall wviewer::held_pin $gs $map]
    check "RP2 held_pin: a hand trace of the current database takes the kept name and its analysis; ASE-L's own does not" \
        [lmap t [dict get [lindex $pinned 0] traces] {list [wviewer::dget $t rawfile -] [wviewer::dget $t sim_type -]}] \
        {{- -} {/r/tb.raw@held1 tran}}
    check "RP2 ...one that named a database takes that database's kept name; one with no vector is left" \
        [lmap t [dict get [lindex $pinned 1] traces] {list [wviewer::dget $t rawfile -] [wviewer::dget $t sim_type -]}] \
        {{/r/tb.raw@held1 tran} {/r/d.vcd@heldx2 vcd} {- -}}
    check "RP2 held_count counts the pinned traces" [pcall wviewer::held_count $pinned] 3
    check "RP2 with the vectors the kept database holds named, a trace of another vector is not pinned to it (it has nothing to show there); one that names its own database still is" \
        [list [lmap t [dict get [lindex [pcall wviewer::held_pin $gs $map {v(zz)}] 0] traces] {dict exists $t rawfile}] \
              [lmap t [dict get [lindex [pcall wviewer::held_pin $gs $map {v(zz)}] 1] traces] {dict exists $t rawfile}] \
              [lmap t [dict get [lindex [pcall wviewer::held_pin $gs $map {v(h)}] 0] traces] {dict exists $t rawfile}]] \
        {{0 0} {0 1 0} {0 1}}
    check "RP2 held_plain takes every pin off again: the strips are what they were, byte for byte" \
        [expr {[pcall wviewer::held_plain $pinned] eq $gs}] 1
    check "RP2 ...except the ones whose kept database is named as still loaded" \
        [pcall wviewer::held_count [pcall wviewer::held_plain $pinned [list {/r/tb.raw@held1 tran}]]] 2
    check "RP2 with no map for its database a trace is not pinned, and strips with no pin come back as they are" \
        [list [pcall wviewer::held_count [pcall wviewer::held_pin $gs [dict create]]] \
              [expr {[pcall wviewer::held_plain $gs] eq $gs}]] {0 1}
    check "RP2 a kept database is named by its file where a database is named, never by the kept name" \
        [list [regexp {^tb\.raw, earlier run \(tran\)$} [pcall wviewer::db_label /r/tb.raw@held1 tran]] \
              [pcall wviewer::db_label /r/tb.raw tran]] {1 {tb.raw (tran)}}
}

# =============================================================================
# RP3 -- THE STRIPS ASE-L'S PLOT READIES (the model alone)
# =============================================================================
group RP3 {
    ## single-plot: one auto strip holding a row and a trace plotted by hand
    rk_lay rp3 single [list [rk_strip [list [rk_tr v(a) 1] [rk_tr v(h)]] auto 1 own 1] \
                            [rk_strip [list [rk_tr v(g)]]]] 0
    set gis [pcall wviewer::auto_plot_strips rp3 2]
    check "RP3 single-plot: ASE-L's trace leaves its strip, the trace plotted by hand in it stays, the hand strip is untouched, and both rows are handed that strip" \
        [list [rk_strips rp3] $gis] {{{1 v(h)} {0 v(g)}} {0 0}}

    ## multi-plot: three auto strips, the last one also holding a hand trace;
    ## two rows now
    rk_lay rp3 multi [list [rk_strip [list [rk_tr v(c) 1]] auto 1 own 1] \
                           [rk_strip [list [rk_tr v(b) 1]] auto 1 own 1] \
                           [rk_strip [list [rk_tr v(a) 1] [rk_tr v(h)]] auto 1 own 1]] 0
    set gis [pcall wviewer::auto_plot_strips rp3 2]
    check "RP3 multi-plot, a row fewer: the surplus auto strip that holds a trace plotted by hand stays, as an ordinary strip" \
        [list [rk_strips rp3] $gis [lmap G [rk_gs rp3] {wviewer::dget $G own -}]] \
        {{{1 {}} {1 {}} {0 v(h)}} {1 0} {1 1 -}}
    rk_lay rp3 multi [list [rk_strip [list [rk_tr v(c) 1]] auto 1 own 1] \
                           [rk_strip [list [rk_tr v(b) 1]] auto 1 own 1] \
                           [rk_strip [list [rk_tr v(a) 1]] auto 1 own 1]] 0
    set gis [pcall wviewer::auto_plot_strips rp3 2]
    check "RP3 ...and a surplus auto strip left empty is removed (no blank band)" \
        [list [rk_strips rp3] $gis] {{{1 {}} {1 {}}} {1 0}}

    ## an auto strip from before the marks: everything in it was the tool's
    rk_lay rp3 single [list [rk_strip [list [rk_tr v(a)] [rk_tr v(b)]] auto 1] \
                            [rk_strip [list [rk_tr v(g)]]]] 0
    pcall wviewer::auto_plot_strips rp3 1
    check "RP3 an auto strip from before the marks is emptied whole, and carries the marks from then on" \
        [list [rk_strips rp3] [wviewer::dget [lindex [rk_gs rp3] 0] own -]] {{{1 {}} {0 v(g)}} 1}

    ## one of ASE-L's traces dragged to a hand strip
    rk_lay rp3 single [list [rk_strip [list [rk_tr v(b) 1]] auto 1 own 1] \
                            [rk_strip [list [rk_tr v(g)] [rk_tr v(a) 1]]]] 0
    pcall wviewer::auto_plot_strips rp3 1
    check "RP3 one of ASE-L's traces dragged to a hand strip leaves it; the hand trace beside it stays" \
        [rk_strips rp3] {{1 {}} {0 v(g)}}

    ## another subwindow is not this plot's
    rk_lay rp3 single [list [rk_strip [list [rk_tr v(a) 1]] auto 1 own 1 sw 1] \
                            [rk_strip [list [rk_tr v(b) 1]] auto 1 own 1 sw 2]] 0
    pcall wviewer::auto_plot_strips rp3 1
    check "RP3 another subwindow keeps ASE-L's earlier plot, traces and all" \
        [rk_strips rp3] {{1 {}} {1 v(b)*}}

    ## the target on a strip that goes
    rk_lay rp3 multi [list [rk_strip [list [rk_tr v(c) 1]] auto 1 own 1 sw 1] \
                           [rk_strip [list [rk_tr v(b) 1]] auto 1 own 1 sw 1] \
                           [rk_strip [list [rk_tr v(g)]] sw 2]] 1
    pcall wviewer::auto_plot_strips rp3 1
    check "RP3 a target on a surplus strip that goes stays in its subwindow, on the auto strip kept" \
        [list [rk_strips rp3] [wviewer::target_index rp3]] {{{1 {}} {0 v(g)}} 0}

    ## a strip left empty: nothing of its Y, its X kept
    rk_lay rp3 single [list [rk_strip [list [rk_tr v(a) 1]] auto 1 own 1 x1 1n x2 2n y1 0.2 y2 0.4 logy 1 yunit V] \
                            [rk_strip [list [rk_tr v(g)] [rk_tr v(b) 1]] x1 3n x2 4n y1 0.5 y2 0.6]] 0
    pcall wviewer::owned_drop rp3 0 1
    set gs [rk_gs rp3]
    check "RP3 a strip the removal leaves empty keeps its stored X and nothing of its Y; one that still holds a hand trace keeps its whole stored view" \
        [list [lmap k {x1 x2 y1 y2 logy yunit} {wviewer::dget [lindex $gs 0] $k -}] \
              [lmap k {x1 x2 y1 y2} {wviewer::dget [lindex $gs 1] $k -}]] \
        {{1n 2n {} {} 0 -} {3n 4n 0.5 0.6}}
    rk_unlay rp3
}

# =============================================================================
# RP4 -- THE OPTION
# =============================================================================
group RP4 {
    set saved [expr {[info exists ::ase_plot_after_sim] ? [list $::ase_plot_after_sim] : {}}]
    set ::ase_plot_after_sim {}
    check "RP4 the default is yes: an empty rc variable, an unset one" \
        [list [pcall ase::plot_after_sim_default] [pcall apply {{} { unset ::ase_plot_after_sim ; set r [ase::plot_after_sim_default] ; set ::ase_plot_after_sim {} ; return $r }}]] {1 1}
    check "RP4 norm reads any Tcl boolean and nothing else" \
        [lmap v {1 0 yes off true {} maybe 2} {pcall ase::plot_after_sim_norm $v}] {1 0 1 0 1 {} {} {}}
    set ::ase_plot_after_sim 0
    check "RP4 the rc variable sets the default" [pcall ase::plot_after_sim_default] 0
    set ::rk_echoes {}
    set ::ase_plot_after_sim perhaps
    set d1 [pcall ase::plot_after_sim_default]
    set d2 [pcall ase::plot_after_sim_default]
    check "RP4 a bad rc value reads yes and is said once" \
        [list $d1 $d2 [llength [lsearch -all -glob $::rk_echoes {*bad ase_plot_after_sim*}]]] {1 1 1}
    set ::ase_plot_after_sim {}
    check "RP4 a state's own key wins over the default, either way; a garbage one reads the default" \
        [list [pcall ase::plot_after_sim_of {plot_after_sim 0}] [pcall ase::plot_after_sim_of {plot_after_sim 1}] \
              [pcall ase::plot_after_sim_of {plot_after_sim nah}] [pcall ase::plot_after_sim_of {}]] {0 1 1 1}
    check "RP4 the key is a schema key that is omitted when empty" \
        [list [expr {{plot_after_sim} in $::ase::schema_keys}] [expr {{plot_after_sim} in $::ase::omit_if_empty}]] {1 1}

    set key [rk_session rp4 tbrp4 {} 1.0]
    set ::rk_logged {}
    rename ::ase::ui::log_action ::rk_log_orig
    proc ::ase::ui::log_action {line} { lappend ::rk_logged $line }
    set st0 [ase::session_state $key]
    check "RP4 a fresh session reads yes and holds no key" \
        [list [pcall ase::ui::plot_after_sim $key] [dict exists $st0 plot_after_sim]] {1 0}
    check "RP4 set to the value it has: nothing written, nothing logged" \
        [list [pcall ase::ui::set_plot_after_sim $key 1] [expr {[ase::session_state $key] eq $st0}] $::rk_logged] {1 1 {}}
    check "RP4 set off: the state holds the key, and one line is logged" \
        [list [pcall ase::ui::set_plot_after_sim $key 0] [pcall dict get [ase::session_state $key] plot_after_sim] \
              [pcall ase::ui::plot_after_sim $key] $::rk_logged] \
        [list 0 0 0 [list [list ase::ui::set_plot_after_sim $key 0]]]
    check "RP4 ...and it is written as one state line" \
        [lsearch -all -inline [split [ase::state_serialize [ase::session_state $key]] \n] {plot_after_sim*}] {{plot_after_sim 0}}
    check "RP4 set back to the default: the key is gone, so the state is what it was" \
        [list [pcall ase::ui::set_plot_after_sim $key yes] [expr {[ase::session_state $key] eq $st0}] [llength $::rk_logged]] {1 1 2}
    check "RP4 a state at the default writes no line" \
        [lsearch -all -inline [split [ase::state_serialize [ase::session_state $key]] \n] {plot_after_sim*}] {}
    set ::rk_echoes {}
    check "RP4 junk is refused with a sentence, an unknown session answers nothing" \
        [list [pcall ase::ui::set_plot_after_sim $key sometimes] [llength [lsearch -all -glob $::rk_echoes {*bad value 'sometimes'*}]] \
              [pcall ase::ui::set_plot_after_sim no/such/key 0] [pcall ase::ui::plot_after_sim no/such/key]] {{} 1 {} 1}
    ## where the rc default is off, the choice that costs a key is ON
    set ::ase_plot_after_sim 0
    check "RP4 with the rc default off, choosing on is what is written, and choosing off again removes it" \
        [list [pcall ase::ui::set_plot_after_sim $key 1] [pcall dict get [ase::session_state $key] plot_after_sim] \
              [pcall ase::ui::set_plot_after_sim $key 0] [dict exists [ase::session_state $key] plot_after_sim]] {1 1 0 0}
    set ::ase_plot_after_sim {}
    check "RP4 the sentence a user change prints names the rc line" \
        [list [regexp {^ase: auto plot after simulation = off \(.*: set ase_plot_after_sim 0\)$} [pcall ase::ui::plot_after_sim_msg 0]] \
              [regexp {^ase: auto plot after simulation = on \(.*: set ase_plot_after_sim 1\)$} [pcall ase::ui::plot_after_sim_msg 1]]] {1 1}
    rename ::ase::ui::log_action {}
    rename ::rk_log_orig ::ase::ui::log_action
    catch {ase::session_close $key}
    if {[llength $saved]} { set ::ase_plot_after_sim [lindex $saved 0] } else { set ::ase_plot_after_sim {} }
}

# =============================================================================
# RP5 -- WHO ASKS FOR THE PLOT, AND WHEN
# =============================================================================
group RP5 {
    set key [rk_session rp5 tbrp5 {{name A expr v(a) save 1 plot 1}} 1.0]
    set ::rk_ap {}
    rename ::ase::ui::auto_plot ::rk_ap_orig
    proc ::ase::ui::auto_plot {key args} { lappend ::rk_ap $args }
    pcall ase::ui::auto_plot_idle $key
    check "RP5 a finished run asks for the plot once, as a run" $::rk_ap {run}
    set ::rk_ap {}
    pcall ase::ui::set_plot_after_sim $key 0
    pcall ase::ui::auto_plot_idle $key
    check "RP5 with the option off a finished run asks for no plot" $::rk_ap {}
    pcall ase::ui::plot_outputs $key
    check "RP5 ...and ~ still does, as the user" $::rk_ap {user}
    pcall ase::ui::set_plot_after_sim $key 1
    rename ::ase::ui::auto_plot {}
    rename ::rk_ap_orig ::ase::ui::auto_plot
    check "RP5 the plot's second argument defaults to the user's" \
        [list [info args ::ase::ui::auto_plot] [info default ::ase::ui::auto_plot why d] $d] {{key why} 1 user}
    catch {ase::session_close $key}
}

# =============================================================================
# RP6 -- `xschem raw rekey`
# =============================================================================
group RP6 {
    set f [file join $::scratch rp6.raw]
    rk_tran $f 10e-9 1.0
    catch {xschem raw clear}
    check "RP6 fixture: the file is read as slot 0" \
        [list [pcall xschem raw read $f tran] [string trim [pcall xschem raw info]]] [list 1 "0 current\n0 $f tran"]
    check "RP6 a bad index, an empty name: 0, and nothing changes" \
        [list [pcall xschem raw rekey 7 x] [pcall xschem raw rekey 0 {}] [pcall xschem raw rekey zero x] \
              [string trim [pcall xschem raw info]]] [list 0 0 0 "0 current\n0 $f tran"]
    check "RP6 the slot takes the name, and its data stays" \
        [list [pcall xschem raw rekey 0 ${f}@held1] [pcall xschem raw rawfile] [pcall format %.4g [pcall xschem raw value v(b) 0]]] \
        [list 1 ${f}@held1 1]
    rk_tran $f 10e-9 2.0
    check "RP6 the file read again is then a second slot, holding the new data" \
        [list [pcall xschem raw read $f tran] [string trim [pcall xschem raw info]] [pcall format %.4g [pcall xschem raw value v(b) 0]]] \
        [list 1 "1 current\n0 ${f}@held1 tran\n1 $f tran" 2]
    check "RP6 a name another slot of the same analysis has is refused" \
        [list [pcall xschem raw rekey 1 ${f}@held1] [pcall xschem raw rawfile]] [list 0 $f]
    check "RP6 the renamed slot is still switched to by its name, with the data it had" \
        [list [pcall xschem raw switch ${f}@held1 tran] [pcall format %.4g [pcall xschem raw value v(b) 0]]] {1 1}
    catch {xschem raw clear}
}

# =============================================================================
# RP7 -- A PASTED COPY IS THE USER'S OWN
# =============================================================================
group RP7 {
    set gs [list [rk_strip {}]]
    set out [pcall wviewer::paste_traces_in_graphs $gs [list [list [rk_tr v(a) 1] [rk_tr v(h)]]] {0} {{5 6}}]
    check "RP7 a copy of one of ASE-L's traces lands without the mark, in the colour it was given" \
        [lmap t [dict get [lindex $out 0] traces] {list [dict get $t vec] [dict exists $t byase] [dict get $t color]}] \
        {{v(a) 0 5} {v(h) 0 6}}
    set kept [dict merge [rk_tr v(k)] {rawfile /r/tb.raw@held1 sim_type tran}]
    set named [dict merge [rk_tr d1] {rawfile /r/d.vcd@heldx2 sim_type vcd}]
    set out [pcall wviewer::paste_traces_in_graphs $gs [list [list $kept $named]] {0} {{5 6}}]
    check "RP7 a copy of a trace kept on an earlier run lands as the plain trace it was: no kept name, a database it named itself named again" \
        [lmap t [dict get [lindex $out 0] traces] {list [dict get $t vec] [wviewer::dget $t rawfile -] [wviewer::dget $t sim_type -]}] \
        {{v(k) - -} {d1 /r/d.vcd vcd}}
}

# =============================================================================
# RP8 -- NOTHING OF A KEPT RUN IS SAVED
# =============================================================================
group RP8 {
    set lay [dict create sharedx 0 graphs [list [rk_strip [list [dict merge [rk_tr v(h)] {rawfile /r/tb.raw@held1 sim_type tran}] [rk_tr v(a) 1]]]]]
    set plain [pcall wviewer::layout_held_plain $lay]
    check "RP8 a layout is written with a kept trace as the plain trace it was, the rest as it is" \
        [list [string match *@held* $plain] [lmap t [dict get [lindex [dict get $plain graphs] 0] traces] {dict keys $t}]] \
        {0 {{expr name vec color} {expr name vec color byase}}}
    set clean [dict create sharedx 0 graphs [list [rk_strip [list [rk_tr v(h)]]]]]
    check "RP8 a layout with nothing kept is handed back byte for byte" \
        [expr {[pcall wviewer::layout_held_plain $clean] eq $clean}] 1
}

# =============================================================================
# THE DISPLAY ARM: the real viewer
# =============================================================================
proc rk_ready {key} {
    set top [wviewer::window_for $key]
    for {set i 0} {$i < 300} {incr i} {
        update
        if {$top ne {} && [winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
        after 20
    }
    return 0
}
proc rk_drw {key} {
    if {[catch {wviewer::window_for $key} w]} { return {} }
    return $w.drw
}
## the viewer's registry: `{path-tail type}` per loaded database, kept names
## shown as <tail>@held
proc rk_dbs {key} {
    if {[catch {xschem new_schematic switch [rk_drw $key]} e]} { return ERR:$e }
    set o {}
    foreach d [dict get [wviewer::rawinfo_parse [xschem raw info]] dbs] {
        set p [dict get $d path]
        set h [wviewer::held_parse $p]
        lappend o [list [expr {$h eq {} ? [file tail $p] : "[file tail [lindex $h 0]]@held"}] [dict get $d type]]
    }
    return [lsort $o]
}
## Which run trace `vec` of strip `gi` shows: v(b)'s first point (the run's
## amplitude) in the database that trace names, read in the viewer's context
## and the current database put back.
proc rk_run_of {key gi vec} {
    set tr {}
    foreach t [wviewer::dget [lindex [rk_gs $key] $gi] traces {}] {
        if {[wviewer::dget $t vec {}] eq $vec} { set tr $t }
    }
    if {$tr eq {}} { return NOTRACE }
    if {[catch {xschem new_schematic switch [rk_drw $key]} e]} { return ERR:$e }
    set cur [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]
    if {[dict exists $tr rawfile]} {
        if {[catch {xschem raw switch [dict get $tr rawfile] [dict get $tr sim_type]} r] || $r ne {1}} {
            catch {xschem raw switch $cur}
            return NODB
        }
    }
    set v ERR
    catch {set v [format %.4g [xschem raw value v(b) 0]]}
    catch {xschem raw switch $cur}
    return $v
}
## the strip index holding vector `vec` (first), -1 for none
proc rk_gi {key vec} {
    set gi 0
    foreach G [rk_gs $key] {
        foreach t [wviewer::dget $G traces {}] { if {[wviewer::dget $t vec {}] eq $vec} { return $gi } }
        incr gi
    }
    return -1
}
## What the ENGINE fits strip gi's Y to (its largest value, 4 digits), the
## rect put back as it was: the amplitude of the data the strip really draws.
proc rk_ytop {key gi} {
    if {[catch {
        xschem new_schematic switch [rk_drw $key]
        set o1 [xschem getprop rect 2 $gi y1]
        set o2 [xschem getprop rect 2 $gi y2]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi fullyzoom]
        xschem new_schematic switch [rk_drw $key]
        set top [xschem getprop rect 2 $gi y2]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi y1 $o1]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi y2 $o2]
    } e]} { return ERR:$e }
    return [format %.4g $top]
}
proc rk_x {key gi} {
    if {[catch {
        xschem new_schematic switch [rk_drw $key]
        set r [list [expr {double([xschem getprop rect 2 $gi x1])}] [expr {double([xschem getprop rect 2 $gi x2])}]]
    } e]} { return ERR:$e }
    return $r
}
proc rk_node {key gi} {
    if {[catch {
        xschem new_schematic switch [rk_drw $key]
        set r [xschem getprop rect 2 $gi node]
    } e]} { return ERR:$e }
    return $r
}
## the Y window strip gi shows, and what the engine fits it to over the X it shows
proc rk_y {key gi} {
    if {[catch {
        xschem new_schematic switch [rk_drw $key]
        set r [list [format %.4g [xschem getprop rect 2 $gi y1]] [format %.4g [xschem getprop rect 2 $gi y2]]]
    } e]} { return ERR:$e }
    return $r
}
proc rk_yfit {key gi} {
    if {[catch {
        xschem new_schematic switch [rk_drw $key]
        set o1 [xschem getprop rect 2 $gi y1]
        set o2 [xschem getprop rect 2 $gi y2]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi fullyzoom]
        xschem new_schematic switch [rk_drw $key]
        set r [list [format %.4g [xschem getprop rect 2 $gi y1]] [format %.4g [xschem getprop rect 2 $gi y2]]]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi y1 $o1]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi y2 $o2]
    } e]} { return ERR:$e }
    return $r
}
proc rk_zoom {key gi a b} {
    catch {
        xschem new_schematic switch [rk_drw $key]
        xschem graph_axis_zoom $gi x $a $b
    }
    update
}

if {$GUI} {
set ::rk_bg {}
interp bgerror {} [list apply {{m o} { lappend ::rk_bg $m }}]

group RK1 {
    set ::rk_key [rk_session rk tbrk {{name A expr v(a) save 1 plot 1}} 1.0]
    set key $::rk_key
    check "RK1 fixture: the session's results are the transient written here, the destination reads Replace, a finished run plots" \
        [list [pcall ase::last_rawfile $key] [pcall ase::plot_sim_type [ase::session_state $key]] \
              [pcall ase::ui::plot_dest $key] [pcall ase::ui::plot_after_sim $key]] [list $::rk_raw tran replace 1]
    check "RK1 fixture: the viewer opens and maps" [list [pcall wviewer::open $key] [rk_ready $key]] {1 1}
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    check "RK1 ~ plots the row: one auto strip, its trace marked as ASE-L's own, the strip as carrying the marks" \
        [list [pcall ase::ui::plot_outputs $key] [rk_strips $key] [wviewer::dget [lindex [rk_gs $key] 0] own -]] \
        {1 {{1 v(a)*}} 1}
    update
}

group RK2 {
    set key $::rk_key
    ## by hand: a real Direct Plot of v(b) (a strip of its own), and v(c) added
    ## to ASE-L's strip through the Add Trace door
    pcall ase::ui::dp_finish $key {v(b)}
    update
    check "RK2 fixture: a real Direct Plot lands in a strip of its own, unmarked" \
        [rk_strips $key] {{1 v(a)*} {0 v(b)}}
    check "RK2 fixture: a trace added by hand to ASE-L's strip is unmarked too" \
        [list [pcall wviewer::add_trace $key 0 v(c)] [rk_strips $key]] {{} {{1 {v(a)* v(c)}} {0 v(b)}}}
    update
    set u0 [lindex [wviewer::history_depth $key] 0]
    pcall ase::ui::plot_outputs $key
    update
    check "RK2 ~ under Replace: the hand strip stays, the hand trace in ASE-L's strip stays, and the row is there once" \
        [rk_strips $key] {{1 {v(c) v(a)*}} {0 v(b)}}
    check "RK2 ...as ONE undo step, and undo brings the replaced trace back where it was" \
        [list [expr {[lindex [wviewer::history_depth $key] 0] - $u0}] [pcall wviewer::undo $key] [rk_strips $key]] \
        {1 1 {{1 {v(a)* v(c)}} {0 v(b)}}}
    pcall ase::ui::plot_outputs $key
    update
    check "RK2 nothing was kept: `~` is not a run (every trace on the one database)" \
        [list [pcall wviewer::held_traces $key] [rk_dbs $key]] {0 {{tbrk_ase.raw tran}}}
    ## the run-end plot asked for again with the results file as it is: the
    ## data is what every trace already shows, so there is nothing to keep
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK2 the plot a finished run makes, on the data the window already shows, keeps nothing either: no second copy of that data, the strips as they were" \
        [list [pcall wviewer::held_traces $key] [rk_dbs $key] [rk_strips $key]] \
        {0 {{tbrk_ase.raw tran}} {{1 {v(c) v(a)*}} {0 v(b)}}}
    check "RK2 no background error" $::rk_bg {}
}

group RK3 {
    set key $::rk_key
    set hb [rk_gi $key v(b)]
    rk_zoom $key $hb 2e-9 5e-9
    check "RK3 fixture: the hand strip zoomed to 2n..5n; every trace shows run 1 (amplitude 1)" \
        [list [lrange [rk_x $key $hb] 0 1] [rk_run_of $key 0 v(a)] [rk_run_of $key 0 v(c)] [rk_run_of $key $hb v(b)]] \
        [list [list 2e-9 5e-9] 1 1 1]
    check "RK3 fixture: the bench run again (amplitude 2, a later time)" [rk_rerun 2.0 7] 1
    set ::rk_echoes {}
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK3 a finished run under Replace: the same strips, the row once, the hand traces where they were" \
        [rk_strips $key] {{1 {v(c) v(a)*}} {0 v(b)}}
    check "RK3 ...the row shows the NEW run, what was plotted by hand shows the OLD one" \
        [list [rk_run_of $key 0 v(a)] [rk_run_of $key 0 v(c)] [rk_run_of $key $hb v(b)]] {2 1 1}
    check "RK3 ...and two traces are kept on the old run's data, which is loaded beside the new" \
        [list [pcall wviewer::held_traces $key] [rk_dbs $key]] {2 {{tbrk_ase.raw tran} {tbrk_ase.raw@held tran}}}
    ## the engine fits a strip's Y over the X window it shows, 2n..5n here.
    ## The hand strip: v(b) falls from the amplitude, so its largest value is
    ## at 2n: 0.8 on run 1 (1.6 on run 2). ASE-L's strip: v(a) of run 2 is 1.0
    ## at 5n (on run 1 it would be 0.5, under the kept v(c)'s 0.625).
    check "RK3 ...by the engine's own fit too: the hand strip's largest value is run 1's, ASE-L's strip reaches run 2's" \
        [list [rk_ytop $key $hb] [rk_ytop $key 0]] {0.8 1}
    check "RK3 ...the hand strip's rect names the kept database, and its legend says which run it shows; ASE-L's trace names none" \
        [list [regexp {v\(b\)@[0-9][0-9]:[0-9][0-9]:[0-9][0-9];v\(b\)%\S+@held[0-9]+ tran} [rk_node $key $hb]] \
              [regexp {@held} [rk_node $key 0]] [string match {*A;v(a)*} [rk_node $key 0]] \
              [string match {*A;v(a)%*} [rk_node $key 0]]] {1 1 1 0}
    check "RK3 ...the zoom on the hand strip is kept" [lrange [rk_x $key $hb] 0 1] [list 2e-9 5e-9]
    check "RK3 ...and the saved state names no kept database: the hand traces are written as plain ones" \
        [list [string match *@held* [pcall wviewer::snapshot $key {}]] \
              [lmap t [dict get [lindex [dict get [pcall wviewer::snapshot $key {}] graphs] $hb] traces] {dict exists $t rawfile}]] \
        {0 0}
    check "RK3 no sentence of an error, no background error" \
        [list [lsearch -all -inline -glob $::rk_echoes {*cannot*}] $::rk_bg] {{} {}}
}

group RK4 {
    set key $::rk_key
    ## a trace plotted by hand AFTER run 2 shows run 2
    pcall wviewer::set_plot_mode multi $key
    pcall ase::ui::dp_finish $key {v(c)}
    update
    pcall wviewer::set_plot_mode single $key
    set gc -1
    set gi 0
    foreach G [rk_gs $key] {
        if {[lmap t [wviewer::dget $G traces {}] {wviewer::dget $t vec {}}] eq {v(c)}} { set gc $gi }
        incr gi
    }
    set hb [rk_gi $key v(b)]
    check "RK4 fixture: a Direct Plot after run 2 gives v(c) a strip of its own, showing run 2" \
        [list [expr {$gc >= 0}] [pcall apply {{key gc} {
            set tr [lindex [wviewer::dget [lindex [rk_gs $key] $gc] traces {}] 0]
            return [dict exists $tr rawfile]
        }} $key $gc]] {1 0}
    check "RK4 fixture: the bench run a third time (amplitude 3)" [rk_rerun 3.0 14] 1
    pcall ase::ui::auto_plot_idle $key
    update
    set hb [rk_gi $key v(b)]
    check "RK4 a second finished run: the row shows run 3, the trace kept at run 1 still shows run 1" \
        [list [rk_run_of $key [rk_gi $key v(a)] v(a)] [rk_run_of $key $hb v(b)]] {3 1}
    check "RK4 ...and the trace plotted by hand between the runs shows run 2" \
        [pcall apply {{key gc} {
            set tr [lindex [wviewer::dget [lindex [rk_gs $key] $gc] traces {}] 0]
            if {![dict exists $tr rawfile]} { return PLAIN }
            xschem new_schematic switch [rk_drw $key]
            set cur [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]
            xschem raw switch [dict get $tr rawfile] [dict get $tr sim_type]
            set v [format %.4g [xschem raw value v(b) 0]]
            xschem raw switch $cur
            return $v
        }} $key $gc] 2
    check "RK4 ...three databases are loaded: the result and the two runs kept" \
        [rk_dbs $key] {{tbrk_ase.raw tran} {tbrk_ase.raw@held tran} {tbrk_ase.raw@held tran}}
    set ::rk_gc $gc
}

group RK5 {
    set key $::rk_key
    set ::rk_echoes {}
    pcall ase::ui::plot_outputs $key
    update
    set hb [rk_gi $key v(b)]
    set ga [rk_gi $key v(a)]
    ## the hand strip still shows 2n..5n, where run 3's v(b) is 2.4 at most
    check "RK5 ~: every trace shows the result (run 3), ASE-L's and the ones plotted by hand" \
        [list [rk_run_of $key $ga v(a)] [rk_run_of $key $ga v(c)] [rk_run_of $key $hb v(b)] [rk_ytop $key $hb]] {3 3 3 2.4}
    check "RK5 ...no trace is kept any more, and the kept data is gone from memory" \
        [list [pcall wviewer::held_traces $key] [rk_dbs $key]] {0 {{tbrk_ase.raw tran}}}
    check "RK5 ...the strips are the ones that were there, the row once" \
        [lsort [rk_strips $key]] [lsort {{1 {v(c) v(a)*}} {0 v(b)} {0 v(c)}}]
    check "RK5 ...and the hand strip's legend is plain again" \
        [regexp {@} [rk_node $key $hb]] 0
    check "RK5 no background error" $::rk_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK6 {
    set key [rk_session rk6 tbrk6 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    ## an expression by hand: v(a) + v(b) is the run's amplitude at every point
    pcall wviewer::add_graph $key
    set err [pcall wviewer::add_trace $key 1 {v(a) v(b) +} hsum]
    update
    check "RK6 fixture: a hand expression in a strip of its own, its vector computed on run 1" \
        [list $err [rk_strips $key] [pcall apply {{key} { xschem new_schematic switch [rk_drw $key] ; format %.4g [xschem raw value hsum 5] }} $key]] \
        {{} {{1 v(a)*} {0 hsum}} 1}
    rk_rerun 2.0 7
    set ::rk_echoes {}
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK6 a finished run: the expression is kept with the run it was computed on (its vector still reads run 1 there, and the new data holds none of that name)" \
        [pcall apply {{key} {
            set tr [lindex [wviewer::dget [lindex [rk_gs $key] 1] traces {}] 0]
            xschem new_schematic switch [rk_drw $key]
            set cur [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]
            set here [xschem raw index hsum]
            if {![dict exists $tr rawfile]} { return [list PLAIN $here] }
            xschem raw switch [dict get $tr rawfile] [dict get $tr sim_type]
            set v [format %.4g [xschem raw value hsum 5]]
            xschem raw switch $cur
            return [list $v [expr {$here < 0}]]
        }} $key] {1 1}
    check "RK6 ...and nothing is said about a trace that could not be evaluated" \
        [lsearch -all -inline -glob $::rk_echoes {*empty*}] {}
    pcall ase::ui::plot_outputs $key
    update
    check "RK6 ~: the expression is evaluated on the result (run 2) and its trace is plain again" \
        [pcall apply {{key} {
            set tr [lindex [wviewer::dget [lindex [rk_gs $key] [rk_gi $key hsum]] traces {}] 0]
            xschem new_schematic switch [rk_drw $key]
            return [list [dict exists $tr rawfile] [format %.4g [xschem raw value hsum 5]]]
        }} $key] {0 2}
    check "RK6 no background error" $::rk_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK7 {
    set key [rk_session rk7 tbrk7 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    rk_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK7 fixture: after a finished run the hand trace is kept on run 1" \
        [list [pcall wviewer::held_traces $key] [rk_run_of $key [rk_gi $key v(b)] v(b)]] {1 1}
    ## an edit that takes an undo point while the trace is kept
    pcall wviewer::add_graph $key
    update
    pcall ase::ui::plot_outputs $key
    update
    check "RK7 fixture: ~ put it back on the result and dropped the kept data" \
        [list [pcall wviewer::held_traces $key] [rk_dbs $key]] {0 {{tbrk7_ase.raw tran}}}
    ## undo twice: past the Replace of `~`, back to the model before add_graph,
    ## which held the trace pinned to data that is gone now
    pcall wviewer::undo $key
    pcall wviewer::undo $key
    update
    check "RK7 undo back to a model that held the kept trace: it comes back as a plain trace on the result, never pinned to data that is gone" \
        [list [pcall wviewer::held_traces $key] [expr {[rk_gi $key v(b)] >= 0}] [rk_run_of $key [rk_gi $key v(b)] v(b)]] {0 1 2}
    check "RK7 no background error" $::rk_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK8 {
    set key [rk_session rk8 tbrk8 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    set lay0 [wviewer::layout_for $key]
    set rec0 [pcall wviewer::attach_record $key]
    rk_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK8 the option off: a finished run changes nothing in the viewer (the layout, the record of what it read, the data every trace shows)" \
        [list [expr {[wviewer::layout_for $key] eq $lay0}] [expr {[pcall wviewer::attach_record $key] eq $rec0}] \
              [rk_run_of $key [rk_gi $key v(a)] v(a)] [rk_run_of $key [rk_gi $key v(b)] v(b)] [rk_dbs $key]] \
        {1 1 1 1 {{tbrk8_ase.raw tran}}}
    pcall ase::ui::plot_outputs $key
    update
    check "RK8 ~ then brings every trace to the new run" \
        [list [rk_run_of $key [rk_gi $key v(a)] v(a)] [rk_run_of $key [rk_gi $key v(b)] v(b)] [pcall wviewer::held_traces $key]] {2 2 0}
    pcall ase::ui::set_plot_after_sim $key 1
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK9 {
    set saved [expr {[info exists ::ase_plot_after_sim] ? [list $::ase_plot_after_sim] : {}}]
    set ::ase_plot_after_sim {}
    set key [rk_session rk9 tbrk9 {{name A expr v(a) save 1 plot 1}} 1.0]
    set top [pcall ase::ui::open $key rk tbrk9 rk9]
    update
    set m $top.mb.results
    set lab [pcall ase::ui::lbl_plot_after_sim_menu]
    check "RK9 fixture: the session's window is up" [winfo exists $m] 1
    set labels {}
    for {set i 0} {$i <= [$m index end]} {incr i} {
        lappend labels [expr {[$m type $i] eq {separator} ? {--} : [$m entrycget $i -label]}]
    }
    check "RK9 Results holds the entry, a checkbutton below Direct Plot, and the menu is results_menu_labels" \
        [list $lab [expr {$labels eq [ase::ui::results_menu_labels]}] \
              [lindex $labels [expr {[lsearch -exact $labels {Direct Plot}] + 1}]] [pcall $m type $lab]] \
        [list {Auto Plot Outputs After Simulation} 1 $lab checkbutton]
    check "RK9 the tick starts at what the session says: on" \
        [list [set [$m entrycget $lab -variable]] [pcall ase::ui::plot_after_sim $key]] {1 1}
    set ::rk_echoes {}
    $m invoke $lab
    update
    check "RK9 a real click on the entry turns it off: the session says off, the tick is off, one sentence names the rc line" \
        [list [pcall ase::ui::plot_after_sim $key] [set [$m entrycget $lab -variable]] \
              [llength [lsearch -all -glob $::rk_echoes {ase: auto plot after simulation = off (*set ase_plot_after_sim 0)}]]] {0 0 1}
    set sf [file join $::scratch rk9 saved.state]
    pcall ase::state_save $sf [ase::session_state $key]
    set fh [open $sf] ; set txt [read $fh] ; close $fh
    check "RK9 ...and the saved state holds the one line, and reads back off" \
        [list [lsearch -all -inline [split $txt \n] {plot_after_sim*}] [pcall ase::plot_after_sim_of [ase::state_load $sf]]] \
        {{{plot_after_sim 0}} 0}
    set ::rk_echoes {}
    pcall ase::ui::set_plot_after_sim $key 1
    update
    check "RK9 a script's change moves the tick and prints nothing" \
        [list [set [$m entrycget $lab -variable]] [lsearch -all -inline -glob $::rk_echoes {*auto plot after simulation*}]] {1 {}}
    ## the state changed under the window (what Load State and Revert do):
    ## the status refresh moves the tick with it, both ways
    set st9 [ase::session_state $key]
    dict set st9 plot_after_sim 0
    ase::session_update $key $st9
    pcall ase::ui::refresh_status $key
    set t0 [set [$m entrycget $lab -variable]]
    dict unset st9 plot_after_sim
    ase::session_update $key $st9
    pcall ase::ui::refresh_status $key
    check "RK9 a state changed under the window (Load State, Revert) moves the tick at the status refresh, off and back on" \
        [list $t0 [set [$m entrycget $lab -variable]]] {0 1}
    $m invoke $lab
    $m invoke $lab
    update
    check "RK9 two more clicks: off and on again, a sentence each, and the state is back without the key" \
        [list [pcall ase::ui::plot_after_sim $key] [llength [lsearch -all -glob $::rk_echoes {ase: auto plot after simulation = *}]] \
              [dict exists [ase::session_state $key] plot_after_sim]] {1 2 0}
    catch {ase::ui::close $key}
    catch {ase::session_close $key}
    if {[llength $saved]} { set ::ase_plot_after_sim [lindex $saved 0] } else { set ::ase_plot_after_sim {} }
}

group RK10 {
    set key [rk_session rk10 tbrk10 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    set amp 1.0
    set dt 0
    set got {}
    foreach d {append newsubwin newtab} {
        pcall ase::ui::set_plot_dest $key $d
        set amp [expr {$amp + 1.0}]
        incr dt 7
        rk_rerun $amp $dt
        pcall ase::ui::auto_plot_idle $key
        update
        lappend got [list $d [pcall wviewer::held_traces $key] [llength [rk_dbs $key]]]
    }
    check "RK10 a finished run under Append, New SubWin and New Win keeps nothing: every trace follows the run, as before" \
        $got {{append 0 1} {newsubwin 0 1} {newtab 0 1}}
    pcall ase::ui::set_plot_dest $key replace
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK11 {
    set key [rk_session rk11 tbrk11 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    rk_outs $key {{name A expr v(a) save 1 plot 0}}
    set lay0 [wviewer::layout_for $key]
    rk_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK11 nothing ticked, a finished run: ASE-L's trace leaves, the hand strip stays, and nothing is read (the hand trace shows what it showed)" \
        [list [rk_strips $key] [rk_run_of $key [rk_gi $key v(b)] v(b)] [rk_dbs $key]] \
        {{{1 {}} {0 v(b)}} 1 {{tbrk11_ase.raw tran}}}
    pcall ase::ui::plot_outputs $key
    update
    check "RK11 nothing ticked, ~: the hand strip stays and is brought to the result" \
        [list [rk_strips $key] [rk_run_of $key [rk_gi $key v(b)] v(b)] [rk_ytop $key [rk_gi $key v(b)]]] \
        {{{1 {}} {0 v(b)}} 2 2}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK12 {
    set key [rk_session rk12 tbrk12 {{name A expr v(a) save 1 plot 1} {name C expr v(c) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    ## a hand strip moved between ASE-L's two
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall wviewer::move_strip [rk_gi $key v(b)] 1 $key
    update
    check "RK12 fixture: multi-plot, a strip per row, the hand strip between them" \
        [rk_strips $key] {{1 v(c)*} {0 v(b)} {1 v(a)*}}
    rk_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK12 a finished run in multi-plot: each row back in its strip, the hand strip in its place between them, showing the old run" \
        [list [rk_strips $key] [rk_run_of $key 1 v(b)] [rk_run_of $key 0 v(c)] [rk_run_of $key 2 v(a)]] \
        {{{1 v(c)*} {0 v(b)} {1 v(a)*}} 1 2 2}
    rk_outs $key {{name A expr v(a) save 1 plot 1} {name C expr v(c) save 1 plot 0}}
    pcall ase::ui::plot_outputs $key
    update
    ## one row needs one auto strip: the upper one is kept (auto_plot_strips'
    ## order since R-OUT14), the lower one is empty and goes
    check "RK12 a row unticked, ~: one of ASE-L's strips goes, the hand strip and the other row stay, every trace on the result" \
        [list [rk_strips $key] [rk_run_of $key [rk_gi $key v(b)] v(b)] [pcall wviewer::held_traces $key]] \
        {{{1 v(a)*} {0 v(b)}} 2 0}
    check "RK12 no background error" $::rk_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK13 {
    set key [rk_session rk13 tbrk13 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    set hb [rk_gi $key v(b)]
    rk_zoom $key $hb 2e-9 5e-9
    rk_rerun 3.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    set hb [rk_gi $key v(b)]
    check "RK13 fixture: a hand strip zoomed in X only, kept through a finished run: it shows the first run over 2n..5n (0.5 to 0.8)" \
        [list [rk_x $key $hb] [rk_y $key $hb] [rk_run_of $key $hb v(b)]] [list [list 2e-9 5e-9] {0.5 0.8} 1]
    pcall ase::ui::plot_outputs $key
    update
    set hb [rk_gi $key v(b)]
    check "RK13 ~ brings it to the result: the X window stays, and its Y window is the engine's fit of the new data there (1.5 to 2.4), not the earlier run's" \
        [list [rk_x $key $hb] [rk_y $key $hb] [expr {[rk_y $key $hb] eq [rk_yfit $key $hb]}] [rk_run_of $key $hb v(b)]] \
        [list [list 2e-9 5e-9] {1.5 2.4} 1 3]
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK14 {
    set key [rk_session rk14 tbrk14 {{name A expr v(a) save 1 plot 1} {name C expr v(c) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    pcall wviewer::add_graph $key
    set eh [pcall wviewer::add_trace $key [expr {[llength [rk_gs $key]] - 1}] {v(a) v(c) +} hs]
    update
    check "RK14 fixture: ASE-L's two rows in one strip, a hand strip, and a hand expression of v(a) and v(c)" \
        [list $eh [rk_strips $key]] {{} {{1 {v(a)* v(c)*}} {0 v(b)} {0 hs}}}
    ## run 2 no longer holds v(c)
    file stat $::rk_raw a0
    rk_tran_noc $::rk_raw 10e-9 2.0
    rk_later $a0(mtime) 7
    set ::rk_echoes {}
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK14 a finished run that lacks a row's net: the row is refused with its sentence, as with nothing kept, and no trace of ASE-L's is drawn from the kept run" \
        [list [llength [lsearch -all -glob $::rk_echoes {ase: cannot auto-plot 'v(c)':*}]] [rk_strips $key] \
              [lmap G [rk_gs $key] {lmap t [wviewer::dget $G traces {}] {expr {[wviewer::dget $t byase 0] eq {1} && [dict exists $t rawfile]}}}]] \
        {1 {{1 v(a)*} {0 v(b)} {0 hs}} {0 0 0}}
    check "RK14 ...the hand traces are kept on run 1, the expression with its vector" \
        [list [pcall wviewer::held_traces $key] [rk_run_of $key [rk_gi $key v(b)] v(b)]] {2 1}
    set ::rk_echoes {}
    rename ::wviewer::echo ::wviewer::rk_wecho
    proc ::wviewer::echo {msg {tag {}}} { lappend ::rk_echoes $msg ; return [::wviewer::rk_wecho $msg $tag] }
    pcall ase::ui::plot_outputs $key
    update
    check "RK14 ~ on that result: the expression cannot be evaluated (v(c) is gone) and one sentence says so; it is a plain trace again" \
        [list [llength [lsearch -all -glob $::rk_echoes {wviewer: trace 'hs' is empty: v(c) is not in the results*}]] \
              [pcall wviewer::held_traces $key]] {1 0}
    ## run 3 holds v(c) again: the empty expression must follow the load
    rk_rerun 3.0 14
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK14 the run that brings the net back draws the expression from it (it had nothing to show, so it was not kept): hs reads run 3's v(a)+v(c), and v(b), which had data, is kept on run 2" \
        [list [pcall apply {{key} {
                  set tr [lindex [wviewer::dget [lindex [rk_gs $key] [rk_gi $key hs]] traces {}] 0]
                  xschem new_schematic switch [rk_drw $key]
                  return [list [dict exists $tr rawfile] [format %.4g [xschem raw value hs 40]]]
              }} $key] [rk_run_of $key [rk_gi $key v(b)] v(b)] [pcall wviewer::held_traces $key]] \
        {{0 5.25} 2 1}
    rename ::wviewer::echo {}
    rename ::wviewer::rk_wecho ::wviewer::echo
    check "RK14 no background error" $::rk_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK15 {
    set key [rk_session rk15 tbrk15 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    rk_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK15 fixture: a hand trace kept on the first transient run" \
        [list [pcall wviewer::held_traces $key] [rk_dbs $key]] {1 {{tbrk15_ase.raw tran} {tbrk15_ase.raw@held tran}}}
    ## the session now runs an AC analysis
    set st [ase::session_state $key]
    dict set st analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 start 1 stop 1e6 points 10} {type tran enabled 0 stop 10n step 100p}}
    ase::session_update $key $st
    file stat $::rk_raw a0
    rk_ac $::rk_raw
    rk_later $a0(mtime) 14
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK15 a finished run of another analysis: nothing is kept, the trace kept before follows the load, and one database is loaded (no transient beside the AC run on one X window)" \
        [list [pcall ase::plot_sim_type [ase::session_state $key]] [pcall wviewer::held_traces $key] [rk_dbs $key]] \
        {ac 0 {{tbrk15_ase.raw ac}}}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK16 {
    set key [rk_session rk16 tbrk16 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    ## a hand trace that NAMES the result's database (as one picked under that
    ## database's header in the Signal Browser while another file was current)
    set gs [rk_gs $key]
    set hb [rk_gi $key v(b)]
    set G [lindex $gs $hb]
    dict lappend G traces [dict create expr v(c) name {} vec v(c) color 6 rawfile $::rk_raw sim_type tran]
    wviewer::set_graphs $key [lreplace $gs $hb $hb $G]
    wviewer::regenerate $key
    update
    rk_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    set hb [rk_gi $key v(b)]
    check "RK16 a plain hand trace and one that names the result's own database, through a finished run: both show the earlier run (neither is blank), on ONE kept database" \
        [list [rk_run_of $key $hb v(b)] [rk_run_of $key $hb v(c)] [pcall wviewer::held_traces $key] [rk_dbs $key] \
              [rk_run_of $key [rk_gi $key v(a)] v(a)]] \
        {1 1 2 {{tbrk16_ase.raw tran} {tbrk16_ase.raw@held tran}} 2}
    pcall ase::ui::plot_outputs $key
    update
    check "RK16 ~: both show the result" \
        [list [rk_run_of $key [rk_gi $key v(b)] v(b)] [rk_run_of $key [rk_gi $key v(c)] v(c)] [pcall wviewer::held_traces $key]] {2 2 0}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK17 {
    set key [rk_session rk17 tbrk17 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    set lay0 [rk_strips $key]
    ## the "run" leaves a file that holds no transient at all
    file stat $::rk_raw a0
    rk_ac $::rk_raw
    rk_later $a0(mtime) 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK17 a finished run whose file cannot be read as the analysis shown: the viewer is as it was: the same traces, every one on the data it showed, that data under its own name, nothing kept" \
        [list [expr {[rk_strips $key] eq $lay0}] [rk_run_of $key [rk_gi $key v(a)] v(a)] [rk_run_of $key [rk_gi $key v(b)] v(b)] \
              [pcall wviewer::held_traces $key] [rk_dbs $key]] \
        {1 1 1 0 {{tbrk17_ase.raw tran}}}
    check "RK17 ...and a state saved now names no kept database, in its traces or as its result" \
        [string match *@held* [pcall wviewer::snapshot $key {}]] 0
    ## the next good run plots and keeps as usual
    rk_rerun 2.0 14
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK17 the next good run: the row shows it, the hand trace is kept on run 1" \
        [list [rk_run_of $key [rk_gi $key v(a)] v(a)] [rk_run_of $key [rk_gi $key v(b)] v(b)] [pcall wviewer::held_traces $key]] {2 1 1}
    ## the kept database made the viewer's current one (a load that read
    ## nothing used to leave it so): the result a saved state names is the
    ## file that data was read from, never the kept name
    set sel [pcall apply {{key} {
        xschem new_schematic switch [rk_drw $key]
        set info [wviewer::rawinfo_parse [xschem raw info]]
        set cur [dict get $info cur]
        foreach d [dict get $info dbs] {
            if {[wviewer::held_parse [dict get $d path]] ne {}} { xschem raw switch [dict get $d idx] }
        }
        set now [xschem raw rawfile]
        set r [list [expr {[wviewer::held_parse $now] ne {}}] [lindex [wviewer::selected_rawfile $key] 0]]
        xschem new_schematic switch [rk_drw $key]
        xschem raw switch $cur
        return $r
    }} $key]
    check "RK17 with the kept database current, the result a saved state names is the file it was read from, not the kept name" \
        $sel [list 1 $::rk_raw]
    check "RK17 no background error" $::rk_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK18 {
    set key [rk_session rk18 tbrk18 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    ## the file as it is while a run writes it: a header and no point, read
    ## into the viewer (a Direct Plot made at that moment does this)
    file stat $::rk_raw a0
    rk_tran_empty $::rk_raw
    rk_later $a0(mtime) 7
    pcall wviewer::attach_raw $key $::rk_raw tran
    update
    set np [pcall apply {{key} { xschem new_schematic switch [rk_drw $key] ; xschem raw points }} $key]
    rk_rerun 2.0 14
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK18 a results file read while it held no point is not kept at the end of the run: the hand trace follows the run, with one database loaded" \
        [list $np [pcall wviewer::held_traces $key] [rk_run_of $key [rk_gi $key v(b)] v(b)] [rk_dbs $key]] \
        {0 0 2 {{tbrk18_ase.raw tran}}}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RK19 {
    set key [rk_session rk19 tbrk19 {{name A expr v(a) save 1 plot 1}} 1.0]
    ## the first run's file was written at 01:02:03 today
    set t0 [clock scan 01:02:03]
    file mtime $::rk_raw $t0
    pcall wviewer::open $key
    rk_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    rk_tran $::rk_raw 10e-9 2.0
    file mtime $::rk_raw [expr {$t0 + 3600}]
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK19 the time in a kept trace's legend, and in its database's label, is the time its data was written (01:02:03), not the time of the run that followed" \
        [list [regexp {v\(b\)@01:02:03;} [rk_node $key [rk_gi $key v(b)]]] \
              [pcall apply {{key} {
                  set tr [lindex [wviewer::dget [lindex [rk_gs $key] [rk_gi $key v(b)]] traces {}] 0]
                  return [wviewer::db_label [dict get $tr rawfile] tran]
              }} $key]] \
        {1 {tbrk19_ase.raw of 01:02:03 (tran)}}
    ## data of which the window knows nothing carries no time. Since issue 1780
    ## every door that reads a file into the viewer notes the file's state (the
    ## Location bar and Results > Select too), and a kept trace's time is read
    ## from that note; a database the engine loaded by a door that takes none
    ## has neither a note nor a time, which is what is made here.
    pcall ase::ui::plot_outputs $key
    pcall wviewer::attach_forget $key
    catch {unset ::wviewer::dbstamps($key)}
    rk_tran $::rk_raw 10e-9 3.0
    file mtime $::rk_raw [expr {$t0 + 7200}]
    pcall ase::ui::auto_plot_idle $key
    update
    check "RK19 when the window does not know when its data was written (a database loaded by a door that notes nothing), the legend says `@earlier` and the label `earlier run`, never a time" \
        [list [pcall wviewer::held_traces $key] [regexp {v\(b\)@earlier;} [rk_node $key [rk_gi $key v(b)]]] \
              [pcall apply {{key} {
                  set tr [lindex [wviewer::dget [lindex [rk_gs $key] [rk_gi $key v(b)]] traces {}] 0]
                  return [wviewer::db_label [dict get $tr rawfile] tran]
              }} $key]] \
        {1 1 {tbrk19_ase.raw, earlier run (tran)}}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}
} else {
    puts "skip: RK1 RK2 RK3 RK4 RK5 RK6 RK7 RK8 RK9 RK10 RK11 RK12 RK13 RK14 RK15 RK16 RK17 RK18 RK19 need a display (no Tk on this arm)"
}

catch {test_scratch_drop $scratch}
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
