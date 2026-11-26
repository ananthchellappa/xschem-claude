# tests/headless/test_wave_reload_1766.tcl -- Ctrl-R in the Waveform Viewer
# reads the result again and brings every trace plotted there to it (issue
# 1766).
#
# The user (2026-11-25): "in Waveform Viewer, add support for Ctrl-R (that's
# not Ctrl-Shift-R, just plain Ctrl-R) that will reload (from latest sim, or
# currently selected result in ASE-L - meaning, user could have just selected a
# past saved sim result) the waveforms currently plotted."
#
# Issue    doc/claude/issues/1766-*.md
# Code     src/wave_viewer.tcl wviewer::reload, reload_at, reload_source,
#          install_default_binds; src/ase_window.tcl ase::ui::reload_source
# Fixture  a transient raw written here (rl_tran): v(a) rises 0..amp, v(b)
#          falls amp..0. A "run" is the file written again with another amp
#          and a later time, so v(b)'s first point says which run a trace
#          shows.
#
# Bands (both arms)
#   RLP1 what a session hands the viewer to read again: the result in view,
#        nothing for an operating point, nothing with no results file
#   RLP2 the sentence's count of traces
#   RLP3 a load whose read fails leaves the copy that was loaded, under its
#        own name and current (ase::attach_dbs); a read that works replaces it
# Bands (display arm only)
#   RL1  the key: plain Ctrl-R is bound on the viewer's tag to the reload, and
#        File > Reload shows it
#   RL2  after a run that plotted nothing (the option off): a real Ctrl-R on
#        the viewer canvas brings every trace to the new run; the strips, the
#        target and the undo history are what they were; one sentence, one
#        log line
#   RL3  a trace kept on an earlier run by a finished run's plot shows the
#        result again after Ctrl-R, the kept data is gone, and the sentence
#        counts it
#   RL4  a zoom is kept across the reload
#   RL5  Ctrl-Shift-R is another key: it reloads nothing
#   RL6  File > Reload does the same as the key
#   RL7  a saved result selected in ASE-L: Ctrl-R shows that result; back on
#        the latest run, Ctrl-R shows the run
#   RL8  a session with no results file of its own, a file attached to its
#        viewer by hand: Ctrl-R reads that file again
#   RL9  nothing to read: one sentence, nothing changes
#   RL10 while the session's run is live the key reads nothing and says so
#   RL11 a file that cannot be read as the analysis shown: the viewer is as it
#        was, a kept trace stays kept, the sentence says so, nothing is logged
#   RL12 a kept strip zoomed in X: Ctrl-R keeps the X window and fits Y to the
#        result
#
# REGISTERED IN `hcases` AND `dcases`.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_wave_reload_1766
#   tests/headless/run_suites.sh test_wave_reload_1766

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
set scratch [test_scratch wave_reload_1766]
set GUI [expr {[info commands toplevel] ne {} && [info commands winfo] ne {}}]

## every sentence the viewer and ASE-L say, and every viewer log line
set ::rl_said {}
rename ::ase::echo ::rl_echo_orig
proc ::ase::echo {msg args} { lappend ::rl_said $msg ; return [::rl_echo_orig $msg {*}$args] }
rename ::wviewer::echo ::wviewer::rl_wecho_orig
proc ::wviewer::echo {msg {tag {}}} { lappend ::rl_said $msg ; return [::wviewer::rl_wecho_orig $msg $tag] }
set ::rl_logged {}
rename ::wviewer::log_action ::wviewer::rl_log_orig
proc ::wviewer::log_action {line} { lappend ::rl_logged $line ; return [::wviewer::rl_log_orig $line] }

proc rl_tran {path tend amp {np 41}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: rl fixture\nDate: Wed Nov 25 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 3\nNo. Points: $np\nVariables:\n\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set t [expr {$tend * $i / ($np - 1.0)}]
        set a [expr {$amp * $i / ($np - 1.0)}]
        puts -nonewline $f [binary format q3 [list $t $a [expr {$amp - $a}]]]
    }
    close $f
}
proc rl_session {sub cell outs amp {an {}}} {
    if {$an eq {}} {
        set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 10n step 100p}}
    }
    set d [file join $::scratch $sub]
    file delete -force $d
    file mkdir $d
    set ::rl_raw [file join $d ${cell}_ase.raw]
    if {$amp ne {}} { rl_tran $::rl_raw 10e-9 $amp }
    set sf [file join $d s.state]
    set f [open $sf w]
    puts $f "version 1"
    puts $f "simulator ngspice"
    puts $f "design {lib rl cell $cell view schematic}"
    puts $f "rundir [list $d]"
    puts $f "temperature 27"
    puts $f "analyses [list $an]"
    puts $f "outputs [list $outs]"
    close $f
    set key rl/$cell/$sub
    catch {ase::session_close $key}
    ase::session_open $key $sf
    return $key
}
proc rl_rerun {amp dt} {
    file stat $::rl_raw a0
    rl_tran $::rl_raw 10e-9 $amp
    file mtime $::rl_raw [expr {$a0(mtime) + $dt}]
    return [expr {[file mtime $::rl_raw] != $a0(mtime)}]
}

# =============================================================================
# RLP1 -- WHAT A SESSION HANDS THE VIEWER TO READ AGAIN
# =============================================================================
group RLP1 {
    set key [rl_session rlp1 tbp1 {} 1.0]
    check "RLP1 a session with results: its results file, the analysis the plot shows, no digital files" \
        [pcall ase::ui::reload_source $key] [list $::rl_raw tran {}]
    file delete -force $::rl_raw
    check "RLP1 no results file: nothing" [pcall ase::ui::reload_source $key] {}
    catch {ase::session_close $key}
    set key [rl_session rlp1b tbp1b {} 1.0 {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0 stop 10n step 100p}}]
    check "RLP1 a session that shows an operating point only: nothing (there is no sweep to draw)" \
        [list [pcall ase::plot_sim_type [ase::session_state $key]] [pcall ase::ui::reload_source $key]] {op {}}
    catch {ase::session_close $key}
    check "RLP1 an unknown session: nothing" [pcall ase::ui::reload_source no/such/key] {}
}

# =============================================================================
# RLP2 -- THE SENTENCE'S COUNT
# =============================================================================
group RLP2 {
    check "RLP2 one trace, several traces" \
        [list [pcall wviewer::plural_traces 1] [pcall wviewer::plural_traces 3]] {{1 trace} {3 traces}}
}

# =============================================================================
# RLP3 -- A LOAD WHOSE READ FAILS LEAVES WHAT WAS LOADED
# =============================================================================
## An AC raw of the same vectors (complex, as ngspice writes it): a file that
## holds no transient
proc rl_ac {path {np 21}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: rl fixture\nDate: Wed Nov 25 00:00:00  2026\nPlotname: AC Analysis\nFlags: complex\nNo. Variables: 3\nNo. Points: $np\nVariables:\n\t0\tfrequency\tfrequency\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set fr [expr {pow(10.0, 6.0 * $i / ($np - 1.0))}]
        set m [expr {1.0 / (1.0 + $i)}]
        puts -nonewline $f [binary format q6 [list $fr 0.0 $m 0.0 [expr {2 * $m}] 0.0]]
    }
    close $f
}
group RLP3 {
    set f [file join $::scratch rlp3.raw]
    rl_tran $f 10e-9 1.0
    catch {xschem raw clear}
    set a1 [pcall ase::attach_dbs $f tran]
    check "RLP3 fixture: the file is loaded as its transient, one slot, current" \
        [list [dict get $a1 n] [string trim [pcall xschem raw info]] [format %.4g [pcall xschem raw value v(b) 0]]] \
        [list 1 "0 current\n0 $f tran" 1]
    ## the file now holds no transient (what a read finds while a run writes it)
    rl_ac $f
    set a2 [pcall ase::attach_dbs $f tran]
    check "RLP3 a load whose read fails says it read nothing, and the copy that was loaded is still there: under its own name, current, with its data" \
        [list [dict get $a2 n] [string trim [pcall xschem raw info]] [format %.4g [pcall xschem raw value v(b) 0]]] \
        [list 0 "0 current\n0 $f tran" 1]
    rl_tran $f 10e-9 2.0
    set a3 [pcall ase::attach_dbs $f tran]
    check "RLP3 a read that works replaces the copy: one slot again, the new data" \
        [list [dict get $a3 n] [string trim [pcall xschem raw info]] [format %.4g [pcall xschem raw value v(b) 0]]] \
        [list 1 "0 current\n0 $f tran" 2]
    catch {xschem raw clear}
}

# =============================================================================
# THE DISPLAY ARM
# =============================================================================
proc rl_ready {key} {
    set top [wviewer::window_for $key]
    for {set i 0} {$i < 300} {incr i} {
        update
        if {$top ne {} && [winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
        after 20
    }
    return 0
}
proc rl_drw {key} {
    if {[catch {wviewer::window_for $key} w]} { return {} }
    return $w.drw
}
proc rl_gs {key} {
    if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return {} }
    return $gs
}
proc rl_vecs {key} {
    lmap G [rl_gs $key] { lmap t [wviewer::dget $G traces {}] {wviewer::dget $t vec {}} }
}
proc rl_gi {key vec} {
    set gi 0
    foreach G [rl_gs $key] {
        foreach t [wviewer::dget $G traces {}] { if {[wviewer::dget $t vec {}] eq $vec} { return $gi } }
        incr gi
    }
    return -1
}
## which run trace `vec` shows: v(b)'s first point in the database it names
proc rl_run_of {key vec} {
    set tr {}
    foreach G [rl_gs $key] {
        foreach t [wviewer::dget $G traces {}] { if {[wviewer::dget $t vec {}] eq $vec} { set tr $t } }
    }
    if {$tr eq {}} { return NOTRACE }
    if {[catch {xschem new_schematic switch [rl_drw $key]} e]} { return ERR:$e }
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
proc rl_ndbs {key} {
    if {[catch {xschem new_schematic switch [rl_drw $key]} e]} { return ERR:$e }
    return [llength [dict get [wviewer::rawinfo_parse [xschem raw info]] dbs]]
}
## what the engine fits strip gi's Y to (its largest value)
proc rl_ytop {key gi} {
    if {[catch {
        xschem new_schematic switch [rl_drw $key]
        set o1 [xschem getprop rect 2 $gi y1]
        set o2 [xschem getprop rect 2 $gi y2]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi fullyzoom]
        xschem new_schematic switch [rl_drw $key]
        set top [xschem getprop rect 2 $gi y2]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi y1 $o1]
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi y2 $o2]
    } e]} { return ERR:$e }
    return [format %.4g $top]
}
proc rl_x {key gi} {
    if {[catch {
        xschem new_schematic switch [rl_drw $key]
        set r [list [expr {double([xschem getprop rect 2 $gi x1])}] [expr {double([xschem getprop rect 2 $gi x2])}]]
    } e]} { return ERR:$e }
    return $r
}
## A real key press on the viewer canvas, the keyboard there first. Answers
## whether the canvas had the keyboard when the key went in.
proc rl_key {key seq} {
    set drw [rl_drw $key]
    catch {raise [winfo toplevel $drw]}
    focus -force $drw
    update
    set had [expr {[focus] eq $drw}]
    event generate $drw $seq
    update
    return $had
}

if {$GUI} {
set ::rl_bg {}
interp bgerror {} [list apply {{m o} { lappend ::rl_bg $m }}]

group RL1 {
    set ::rl_key [rl_session rl tbrl {{name A expr v(a) save 1 plot 1}} 1.0]
    set key $::rl_key
    check "RL1 fixture: the viewer opens and maps" [list [pcall wviewer::open $key] [rl_ready $key]] {1 1}
    check "RL1 plain Ctrl-R is bound on the viewer's tag to the reload, and stops there" \
        [string trim [bind WaveViewer <Control-Key-r>]] {wviewer::reload_at %W; break}
    check "RL1 Ctrl-Shift-R is not bound there" [bind WaveViewer <Control-Key-R>] {}
    set m [wviewer::window_for $key].wvmenubar.file
    set at [pcall $m index Reload]
    ## (issue 1780 put Overlay Latest between Reload and the separator)
    check "RL1 File > Reload is in the menu, shows Ctrl+R, and stands with Overlay Latest above the separator before Copy Traces" \
        [list [pcall $m entrycget Reload -accelerator] [pcall $m entrycget [expr {$at + 1}] -label] \
              [pcall $m type [expr {$at + 2}]] [pcall $m entrycget [expr {$at + 3}] -label]] \
        {Ctrl+R {Overlay Latest} separator {Copy Traces}}
}

group RL2 {
    set key $::rl_key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    check "RL2 fixture: the bench run again (amplitude 2); with the option off the finished run plots nothing, so the viewer still shows run 1" \
        [list [rl_rerun 2.0 7] [pcall ase::ui::auto_plot_idle $key] [rl_run_of $key v(a)] [rl_run_of $key v(b)]] {1 {} 1 1}
    set lay0 [rl_vecs $key]
    set tgt0 [wviewer::target_index $key]
    set h0 [wviewer::history_depth $key]
    set ::rl_said {}
    set ::rl_logged {}
    set had [rl_key $key <Control-Key-r>]
    check "RL2 a real Ctrl-R on the viewer canvas (which had the keyboard): every trace shows run 2" \
        [list $had [rl_run_of $key v(a)] [rl_run_of $key v(b)] [rl_ytop $key [rl_gi $key v(a)]]] {1 2 2 2}
    check "RL2 ...the strips, their order, the target and the undo history are what they were" \
        [list [expr {[rl_vecs $key] eq $lay0}] [expr {[wviewer::target_index $key] == $tgt0}] \
              [expr {[wviewer::history_depth $key] eq $h0}]] {1 1 1}
    check "RL2 ...one sentence says what was read, and one line is logged" \
        [list [lsearch -all -inline -glob $::rl_said {wviewer: reloaded*}] $::rl_logged] \
        [list [list {wviewer: reloaded tbrl_ase.raw (tran)}] [list [list wviewer::reload $key]]]
    check "RL2 no background error" $::rl_bg {}
    pcall ase::ui::set_plot_after_sim $key 1
}

group RL3 {
    set key $::rl_key
    rl_rerun 3.0 14
    pcall ase::ui::auto_plot_idle $key
    update
    check "RL3 fixture: a finished run's plot: the row shows run 3, the hand trace is kept on run 2, two databases loaded" \
        [list [rl_run_of $key v(a)] [rl_run_of $key v(b)] [pcall wviewer::held_traces $key] [rl_ndbs $key]] {3 2 1 2}
    set ::rl_said {}
    rl_key $key <Control-Key-r>
    check "RL3 Ctrl-R: the kept trace shows the result again, nothing is kept, the kept data is gone" \
        [list [rl_run_of $key v(a)] [rl_run_of $key v(b)] [pcall wviewer::held_traces $key] [rl_ndbs $key]] {3 3 0 1}
    check "RL3 ...and the sentence counts it" \
        [lsearch -all -inline -glob $::rl_said {wviewer: reloaded*}] \
        [list {wviewer: reloaded tbrl_ase.raw (tran) (1 trace kept on an earlier run shows it again)}]
}

group RL4 {
    set key $::rl_key
    set gb [rl_gi $key v(b)]
    catch {
        xschem new_schematic switch [rl_drw $key]
        xschem graph_axis_zoom $gb x 2e-9 5e-9
    }
    update
    rl_rerun 4.0 21
    rl_key $key <Control-Key-r>
    check "RL4 a zoom is kept across a reload of new data, and the strip shows the new run inside it" \
        [list [rl_x $key [rl_gi $key v(b)]] [rl_run_of $key v(b)] [rl_ytop $key [rl_gi $key v(b)]]] \
        [list [list 2e-9 5e-9] 4 3.2]
}

group RL5 {
    set key $::rl_key
    rl_rerun 5.0 28
    set ::rl_logged {}
    set had [rl_key $key <Control-Shift-Key-R>]
    check "RL5 Ctrl-Shift-R on the viewer canvas reloads nothing: the traces still show run 4, nothing is logged" \
        [list $had [rl_run_of $key v(a)] [rl_run_of $key v(b)] $::rl_logged] {1 4 4 {}}
}

group RL6 {
    set key $::rl_key
    set ::rl_logged {}
    set m [wviewer::window_for $key].wvmenubar.file
    pcall $m invoke Reload
    update
    check "RL6 File > Reload does what the key does: every trace shows run 5, one line logged" \
        [list [rl_run_of $key v(a)] [rl_run_of $key v(b)] $::rl_logged] [list 5 5 [list [list wviewer::reload $key]]]
    check "RL6 no background error" $::rl_bg {}
}

group RL7 {
    set key $::rl_key
    ## save the run in view (amplitude 5) under a name, run again (amplitude 6)
    set saved [pcall ase::saved_save $key five {} {} 0]
    set sraw {}
    foreach e [pcall ase::saved_list $key] {
        if {[ase::state_get [ase::saved_meta [dict get $e dir]] name] eq {five}} {
            set sraw [file join [dict get $e dir] [file tail $::rl_raw]]
        }
    }
    check "RL7 fixture: the result is saved as `five`, with its own copy of the results file" \
        [list [expr {$sraw ne {}}] [file isfile $sraw]] {1 1}
    rl_rerun 6.0 35
    rl_key $key <Control-Key-r>
    check "RL7 fixture: Ctrl-R on the latest run shows run 6" [list [rl_run_of $key v(a)] [rl_run_of $key v(b)]] {6 6}
    ## the user selects the saved result in ASE-L
    pcall ase::result_sel_note $key $sraw
    check "RL7 fixture: ASE-L has the saved result in view" \
        [list [expr {[pcall ase::result_view $key] ne {}}] [pcall ase::last_rawfile $key]] [list 1 $sraw]
    set ::rl_said {}
    rl_key $key <Control-Key-r>
    ## the strips still show 2n..5n (RL4), where run 5's v(a) reaches 2.5
    check "RL7 with a saved result selected in ASE-L, Ctrl-R shows THAT result: every trace reads run 5" \
        [list [rl_run_of $key v(a)] [rl_run_of $key v(b)] [rl_ytop $key [rl_gi $key v(a)]]] {5 5 2.5}
    check "RL7 ...and the sentence names the saved result by its name" \
        [lsearch -all -inline -glob $::rl_said {wviewer: reloaded*}] [list {wviewer: reloaded five (tran)}]
    pcall ase::result_sel_note $key {}
    rl_key $key <Control-Key-r>
    check "RL7 back on the latest run, Ctrl-R shows run 6 again" \
        [list [pcall ase::last_rawfile $key] [rl_run_of $key v(a)] [rl_run_of $key v(b)]] [list $::rl_raw 6 6]
    check "RL7 no background error" $::rl_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RL8 {
    ## a session that has no results file of its own (never run), and a file
    ## the user attached to its viewer by hand
    set tok [rl_session rl8 tbrl8 {} {}]
    set f [file join $::scratch rl8.raw]
    rl_tran $f 10e-9 1.0
    check "RL8 fixture: the session answers nothing to read; a raw is attached to its viewer and v(b) plotted from it" \
        [list [pcall ase::ui::reload_source $tok] [pcall wviewer::open $tok] [rl_ready $tok] \
              [pcall wviewer::attach_raw $tok $f tran] [pcall wviewer::add_trace $tok 0 v(b)]] {{} 1 1 1 {}}
    update
    file stat $f a0
    rl_tran $f 10e-9 7.0
    file mtime $f [expr {$a0(mtime) + 7}]
    set ::rl_said {}
    rl_key $tok <Control-Key-r>
    check "RL8 Ctrl-R reads again the file the window attached: the trace shows the new data" \
        [list [rl_run_of $tok v(b)] [lsearch -all -inline -glob $::rl_said {wviewer: reloaded*}]] \
        [list 7 [list {wviewer: reloaded rl8.raw (tran)}]]
    ## RL9: the file gone
    file delete -force $f
    set lay0 [wviewer::layout_for $tok]
    set ::rl_said {}
    set ::rl_logged {}
    set r [pcall wviewer::reload $tok]
    check "RL9 nothing to read (the file is gone): one sentence, 0, nothing changes, nothing logged" \
        [list $r [lsearch -all -inline -glob $::rl_said {wviewer: nothing to reload*}] \
              [expr {[wviewer::layout_for $tok] eq $lay0}] [rl_run_of $tok v(b)] $::rl_logged] \
        [list 0 [list {wviewer: nothing to reload: no result file is attached to this window}] 1 7 {}]
    check "RL9 a window that does not exist: a sentence and nothing else" \
        [list [pcall wviewer::reload no_such_viewer] [expr {[lsearch -glob $::rl_said {wviewer: no waveform viewer window to reload}] >= 0}]] {{} 1}
    check "RL9 no background error" $::rl_bg {}
    catch {wviewer::close $tok}
    catch {ase::session_close $tok}
}

group RL10 {
    set key [rl_session rl10 tbrl10 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rl_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    check "RL10 fixture: no run of the session is live" [pcall ase::ui::reload_busy $key] 0
    rl_rerun 2.0 7
    ## a run of the session is live (the test the key asks, answered yes)
    rename ::ase::ui::reload_busy ::ase::ui::rl_busy_orig
    proc ::ase::ui::reload_busy {key} { return 1 }
    set ::rl_said {}
    set ::rl_logged {}
    set lay0 [wviewer::layout_for $key]
    rl_key $key <Control-Key-r>
    rename ::ase::ui::reload_busy {}
    rename ::ase::ui::rl_busy_orig ::ase::ui::reload_busy
    check "RL10 while the session's run is live Ctrl-R reads nothing: one sentence says why, the traces show what they showed, nothing is logged" \
        [list [lsearch -all -inline -glob $::rl_said {wviewer: a simulation of this session is running*}] \
              [expr {[wviewer::layout_for $key] eq $lay0}] [rl_run_of $key v(a)] [rl_run_of $key v(b)] $::rl_logged] \
        [list [list {wviewer: a simulation of this session is running; reload when it has finished}] 1 1 1 {}]
    rl_key $key <Control-Key-r>
    check "RL10 control: with no run live the same key reads the new run" [list [rl_run_of $key v(a)] [rl_run_of $key v(b)]] {2 2}
    set ::rl_key10 $key
}

group RL11 {
    set key $::rl_key10
    rl_rerun 3.0 14
    pcall ase::ui::auto_plot_idle $key
    update
    check "RL11 fixture: after a finished run the row shows run 3 and the hand trace is kept on run 2" \
        [list [rl_run_of $key v(a)] [rl_run_of $key v(b)] [pcall wviewer::held_traces $key] [rl_ndbs $key]] {3 2 1 2}
    ## the file now holds no transient
    file stat $::rl_raw a0
    rl_ac $::rl_raw
    file mtime $::rl_raw [expr {$a0(mtime) + 7}]
    set ::rl_said {}
    set ::rl_logged {}
    rl_key $key <Control-Key-r>
    check "RL11 a file that cannot be read as the analysis shown: the viewer is as it was (the row on run 3, the hand trace still kept on run 2, both databases loaded), one sentence says so, nothing is logged" \
        [list [rl_run_of $key v(a)] [rl_run_of $key v(b)] [pcall wviewer::held_traces $key] [rl_ndbs $key] \
              [lsearch -all -inline -glob $::rl_said {wviewer: could not reload*}] $::rl_logged] \
        [list 3 2 1 2 [list "wviewer: could not reload tbrl10_ase.raw: nothing was read as its tran analysis; the viewer shows what it showed"] {}]
    check "RL11 no background error" $::rl_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group RL12 {
    set key [rl_session rl12 tbrl12 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    rl_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    set gb [rl_gi $key v(b)]
    catch {
        xschem new_schematic switch [rl_drw $key]
        xschem graph_axis_zoom $gb x 2e-9 5e-9
    }
    update
    rl_rerun 3.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    set gb [rl_gi $key v(b)]
    set y0 [pcall apply {{key gb} { xschem new_schematic switch [rl_drw $key] ; list [format %.4g [xschem getprop rect 2 $gb y1]] [format %.4g [xschem getprop rect 2 $gb y2]] }} $key $gb]
    rl_key $key <Control-Key-r>
    set gb [rl_gi $key v(b)]
    set y1 [pcall apply {{key gb} { xschem new_schematic switch [rl_drw $key] ; list [format %.4g [xschem getprop rect 2 $gb y1]] [format %.4g [xschem getprop rect 2 $gb y2]] }} $key $gb]
    check "RL12 a hand strip zoomed in X and kept on run 1 (Y 0.5 to 0.8): Ctrl-R keeps the X window and shows run 3 in a Y window fitted to it (1.5 to 2.4)" \
        [list $y0 [rl_x $key $gb] $y1 [rl_run_of $key v(b)]] [list {0.5 0.8} [list 2e-9 5e-9] {1.5 2.4} 3]
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}
} else {
    puts "skip: RL1 RL2 RL3 RL4 RL5 RL6 RL7 RL8 RL9 RL10 RL11 RL12 need a display (no Tk on this arm)"
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
