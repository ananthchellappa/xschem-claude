# tests/headless/test_wave_overlay_latest_1780.tcl -- Alt-Shift-P in the
# Waveform Viewer draws the result in view beside what each waveform shows,
# and Results > Select plots nothing (issue 1780).
#
# The user (2026-11-26): "add support for Alt-Shift-P in Waveform Viewer which
# will plot the latest waveforms from currently loaded [result] ... in OVERLAY
# mode ... Overlay means that, in each strip, the new version of the waveform
# will be plotted in a slightly different color." Asked: pressed again after
# another run, every version stays; only the waveforms shown get a version;
# and "Selecting a simulation result using Results > Select should NOT
# automatically plot waveforms ... Alt-Shift-P then overlays the saved result
# on it, and Ctrl-R replaces with it".
#
# Issue    doc/claude/issues/1780-*.md
# Spec     doc/claude/specs/waveform_viewer.md, "Overlay Latest"
# Code     src/wave_viewer.tcl wviewer::overlay_latest, ovl_versions, ovl_tidy,
#          select_keep_pre, select_keep_post, graph_props; src/ase_window.tcl
#          ase::ui::rsel_commit; src/draw.c draw_graph(); src/xinit.c
#          graph_shade()
# Fixture  a transient raw written here (ov_tran): v(a) rises 0..amp, v(b)
#          falls amp..0. A "run" is the file written again with another amp
#          and a later time, so v(b)'s first point says which run a trace
#          shows.
#
# Bands (both arms)
#   OP1  the shades: the default list, an rc list, a list that is no list
#   OP2  a trace's shade rides its colour token on the strip, and only then
#   OP3  which waveforms get a later version (wviewer::ovl_versions)
#   OP4  the later versions go when every version shows the same data
#        (wviewer::ovl_tidy), and what is saved holds none
#   OP5  the legend cue: a saved result by its name, another day by its date
# Bands (display arm only)
#   OV1  the key and the menu entry
#   OV2  after a run that plotted nothing: a real Alt-Shift-P adds the new run
#        beside the old one in every strip, in a shade
#   OV3  pressed again with nothing new: a small window says so, nothing
#        changes, nothing is logged
#   OV4  another run and the key again: three versions
#   OV5  the screen: the later version is painted in the shade
#   OV6  `u` takes the versions of the last press out
#   OV7  Ctrl-R goes back to one version of each, in its own colour
#   OV8  after a finished run that plotted: ASE-L's row is on the run, the
#        trace made by hand gets the version; with nothing left to add the
#        window names ASE-L's menu entry
#   OV9  ASE-L's plot button after an overlay: one version of each
#   OV10 Results > Select plots nothing; Alt-Shift-P then overlays the saved
#        result; Ctrl-R replaces with it
#   OV11 selecting the result the plots show again takes the pins off
#   OV12 another analysis, a live run, no result, no waveform, no window
#   OV13 a zoom is kept; an expression gets its version; a net the result
#        lacks is left
#   OV14 a second tab gets its versions too; a saved state holds one version
#   OV15 the doors that read a file into the viewer by hand: the key knows
#        what they read
#   OV16 a trace highlight and the bold trace follow their trace when a later
#        version before it goes
#   OV17 another file with the result's time and size is not the result
# The rows of the review (the issue file's section "The review")
#   OV18 back and forth between a saved result and the last run adds no
#        duplicate, and no copy of a result is left in memory
#   OV19 a file picked by path in the dialog is what the keys read
#   OV20 the analysis the waveforms show decides how the result is read
#   OV21 a later version left alone is an ordinary trace again; a pasted one;
#        a finished run of another analysis
#   OV22 a load made by another door leaves the versions on their data
#   OV23 the legend cue after a failed read; the read-out and the Delete
#        dialog; a press that only read; the undo point; the scripting door
#   OV24 a colour with no room towards white or black
#   OV25 what the small window blames; its keyboard; a trace with no data at
#        a select
# The rows of the second review
#   OP6  what the dialog chose last: while it is the session's selection
#   OV26 `u` after a select round trip; the dialog's Loaded list; the Signal
#        Browser; the viewer's Location bar after a select
#   OV27 Ctrl-R, the key and the plot button read one analysis; a window that
#        shows two; a saved result of another analysis
#   OV28 a version in a tab that is not shown at a finished run; who is blamed
#        after a Direct Plot; a saved copy of the kept run
#
# REGISTERED IN `hcases` AND `dcases`.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_wave_overlay_latest_1780
#   tests/headless/run_suites.sh test_wave_overlay_latest_1780

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
set scratch [test_scratch wave_overlay_1780]
set GUI [expr {[info commands toplevel] ne {} && [info commands winfo] ne {}}]

## every sentence the viewer and ASE-L say, and every viewer log line
set ::ov_said {}
rename ::ase::echo ::ov_echo_orig
proc ::ase::echo {msg args} { lappend ::ov_said $msg ; return [::ov_echo_orig $msg {*}$args] }
rename ::wviewer::echo ::wviewer::ov_wecho_orig
proc ::wviewer::echo {msg {tag {}}} { lappend ::ov_said $msg ; return [::wviewer::ov_wecho_orig $msg $tag] }
set ::ov_logged {}
rename ::wviewer::log_action ::wviewer::ov_log_orig
proc ::wviewer::log_action {line} { lappend ::ov_logged $line ; return [::wviewer::ov_log_orig $line] }

proc ov_tran {path tend amp {np 41} {extra 0}} {
    set f [open $path w]
    fconfigure $f -translation binary
    set nv [expr {3 + ($extra ? 1 : 0)}]
    set hdr "Title: ov fixture\nDate: Thu Nov 26 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: $nv\nNo. Points: $np\nVariables:\n\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\n"
    if {$extra} { append hdr "\t3\tv(c)\tvoltage\n" }
    append hdr "Binary:\n"
    puts -nonewline $f $hdr
    for {set i 0} {$i < $np} {incr i} {
        set t [expr {$tend * $i / ($np - 1.0)}]
        set a [expr {$amp * $i / ($np - 1.0)}]
        set row [list $t $a [expr {$amp - $a}]]
        if {$extra} { lappend row [expr {0.5 * $amp}] }
        puts -nonewline $f [binary format q$nv $row]
    }
    close $f
}
proc ov_ac {path {np 21}} {
    set f [open $path w]
    fconfigure $f -translation binary
    puts -nonewline $f "Title: ov fixture\nDate: Thu Nov 26 00:00:00  2026\nPlotname: AC Analysis\nFlags: complex\nNo. Variables: 3\nNo. Points: $np\nVariables:\n\t0\tfrequency\tfrequency\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set fr [expr {pow(10.0, 6.0 * $i / ($np - 1.0))}]
        set m [expr {1.0 / (1.0 + $i)}]
        puts -nonewline $f [binary format q6 [list $fr 0.0 $m 0.0 [expr {2 * $m}] 0.0]]
    }
    close $f
}
proc ov_session {sub cell outs amp {an {}} {extra 0}} {
    if {$an eq {}} {
        set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 10n step 100p}}
    }
    set d [file join $::scratch $sub]
    file delete -force $d
    file mkdir $d
    set ::ov_raw [file join $d ${cell}_ase.raw]
    if {$amp ne {}} { ov_tran $::ov_raw 10e-9 $amp 41 $extra }
    set sf [file join $d s.state]
    set f [open $sf w]
    puts $f "version 1"
    puts $f "simulator ngspice"
    puts $f "design {lib ov cell $cell view schematic}"
    puts $f "rundir [list $d]"
    puts $f "temperature 27"
    puts $f "analyses [list $an]"
    puts $f "outputs [list $outs]"
    close $f
    set key ov/$cell/$sub
    catch {ase::session_close $key}
    ase::session_open $key $sf
    return $key
}
## the file written again: another amplitude, a later time
proc ov_rerun {amp dt {extra 0}} {
    file stat $::ov_raw a0
    ov_tran $::ov_raw 10e-9 $amp 41 $extra
    file mtime $::ov_raw [expr {$a0(mtime) + $dt}]
    return [expr {[file mtime $::ov_raw] != $a0(mtime)}]
}
proc ov_read {path} {
    set f [open $path r]
    set d [read $f]
    close $f
    return $d
}
## a trace dict of the model, by its fields
proc tr {vec args} { return [dict create expr $vec name {} vec $vec color 4 {*}$args] }
proc strip {args} { return [dict create traces $args] }
## the fields of every trace of strips `gs` that the overlay is about
proc ov_marks {gs} {
    lmap G $gs {
        lmap t [wviewer::dget $G traces {}] {
            list [wviewer::dget $t vec {}] [wviewer::dget $t rawfile {}] [wviewer::dget $t ovl {}] \
                 [wviewer::dget $t ogen {}] [wviewer::dget $t shade {}]
        }
    }
}

# =============================================================================
# OP1 -- THE SHADES
# =============================================================================
group OP1 {
    catch {unset ::wviewer_overlay_shades}
    check "OP1 with no rc line: the first later version 40 towards white, the next 35 towards black, then 65 and 60" \
        [pcall wviewer::overlay_shades] {40 -35 65 -60}
    check "OP1 ...as the tokens a trace carries; past the end the list starts again; version 0 has none" \
        [lmap g {1 2 3 4 5 0} {pcall wviewer::overlay_shade $g}] {+40 -35 +65 -60 +40 {}}
    set ::wviewer_overlay_shades {25 -50}
    check "OP1 an rc list is read" [list [pcall wviewer::overlay_shades] [pcall wviewer::overlay_shade 2] [pcall wviewer::overlay_shade 3]] \
        {{25 -50} -50 +25}
    foreach {what bad} {{a word} {40 lighter} {a zero} {40 0} {a percent past 95} {40 96} {an empty list} {} {a fraction} {40 12.5} {an open brace} "\{40"} {
        set ::wviewer_overlay_shades $bad
        check "OP1 a list with $what reads as the default" [pcall wviewer::overlay_shades] {40 -35 65 -60}
    }
    set ::wviewer_overlay_shades {+30 -9}
    check "OP1 a sign and a single digit are read" [pcall wviewer::overlay_shades] {30 -9}
    catch {unset ::wviewer_overlay_shades}
    check "OP1 the default the viewer declares is the one the reader falls back to" \
        [regexp {\nset_ne wviewer_overlay_shades \{40 -35 65 -60\}\n} [ov_read [file join $repo src wave_viewer.tcl]]] 1
}

# =============================================================================
# OP2 -- THE SHADE RIDES THE COLOUR TOKEN
# =============================================================================
proc ov_color_prop {G} {
    if {![regexp {color="([^"]*)"} [wviewer::graph_props $G] -> c]} {
        if {![regexp {color=(\S+)} [wviewer::graph_props $G] -> c]} { return NOCOLOR }
    }
    return $c
}
group OP2 {
    set plainG [strip [tr v(a)] [tr v(b) color 5]]
    check "OP2 traces without a shade: the colour token is the layer alone" [ov_color_prop $plainG] {4 5}
    set G [strip [tr v(a)] [tr v(a) color 4 shade +40 ovl 1 ogen 1] [tr v(b) color 5 shade -35 ovl 2 ogen 1]]
    check "OP2 a shade follows its trace's layer in the same token" [ov_color_prop $G] {4 4+40 5-35}
    foreach {what s} {{no sign} 40 {three digits} +400 {a word} light {a zero} +0 {a blank} { }} {
        check "OP2 a shade with $what is not written: the layer alone" \
            [ov_color_prop [strip [tr v(a) shade $s]]] 4
    }
    check "OP2 the marks ovl and ogen change nothing on the strip" \
        [expr {[wviewer::graph_props [strip [tr v(a) ovl 3 ogen 2]]] eq [wviewer::graph_props [strip [tr v(a)]]]}] 1
}

# =============================================================================
# OP3 -- WHICH WAVEFORMS GET A LATER VERSION
# =============================================================================
proc ov_run {info gs} {
    array unset ::wviewer::ovldone
    array set ::wviewer::ovldone {added 0 same 0 other 0 absent 0}
    set out [wviewer::ovl_versions $info $gs]
    set c [list $::wviewer::ovldone(added) $::wviewer::ovldone(same) $::wviewer::ovldone(other) $::wviewer::ovldone(absent)]
    array unset ::wviewer::ovldone
    return [list $out $c]
}
group OP3 {
    set R /x/r.raw
    set K1 [wviewer::held_name $R 1]
    set K2 [wviewer::held_name $R 2]
    set info [dict create cur [list $R tran] loaded [dict create [list $R tran] 0 [list $K1 tran] 1 [list $K2 tran] 2] \
                stamps [dict create [list $R tran] {200 10} [list $K1 tran] {100 10} [list $K2 tran] {150 10}] \
                have {v(a) v(b)} maxid 0 shades {40 -35}]
    ## a first press: both traces are kept on the earlier run
    set gs [list [strip [tr v(a) rawfile $K1 sim_type tran] [tr v(b) color 5 rawfile $K1 sim_type tran]]]
    lassign [ov_run $info $gs] out c
    check "OP3 two waveforms kept on an earlier run: each gets one later version, appended, on the result, in the first shade and its own layer; the first traces take a family mark and stay where they are" \
        [list $c [ov_marks $out] [lmap t [dict get [lindex $out 0] traces] {dict get $t color}]] \
        [list {2 0 0 0} [list [list [list v(a) $K1 1 {} {}] [list v(b) $K1 2 {} {}] {v(a) {} 1 1 +40} {v(b) {} 2 1 +40}]] {4 5 4 5}]
    ## a second press after another run: the first later versions are kept on run 2
    set gs2 [list [strip [tr v(a) rawfile $K1 sim_type tran ovl 1] [tr v(a) rawfile $K2 sim_type tran ovl 1 ogen 1 shade +40]]]
    lassign [ov_run [dict replace $info maxid 1] $gs2] out c
    check "OP3 a waveform with two versions, the later one kept: a third, in the second shade; the two earlier ones as they were" \
        [list $c [ov_marks $out]] \
        [list {1 0 0 0} [list [list [list v(a) $K1 1 {} {}] [list v(a) $K2 1 1 +40] {v(a) {} 1 2 -35}]]]
    ## nothing to add: the latest version follows the result already
    set gs3 [list [strip [tr v(a) rawfile $K1 sim_type tran ovl 1] [tr v(a) ovl 1 ogen 1 shade +40] [tr v(b) color 5]]]
    lassign [ov_run $info $gs3] out c
    check "OP3 a waveform whose latest version follows the result, and a trace that follows it: nothing is added and the strips are the ones handed in" \
        [list $c [expr {$out eq $gs3}]] {{0 0 0 0} 1}
    ## D1 of the review: an EARLIER version follows the result, the later one is kept
    set gs3b [list [strip [tr v(a) ovl 1] [tr v(a) rawfile $K2 sim_type tran ovl 1 ogen 1 shade +40]]]
    lassign [ov_run $info $gs3b] out c
    check "OP3 a waveform whose FIRST trace follows the result while its later version is kept (a select went back to the data the first trace showed): nothing is added" \
        [list $c [expr {$out eq $gs3b}]] {{0 0 0 0} 1}
    ## every version kept, an earlier one on the very data that is loaded again
    set infoS2 [dict replace $info stamps [dict create [list $R tran] {100 10} [list $K1 tran] {100 10} [list $K2 tran] {150 10}]]
    lassign [ov_run $infoS2 $gs2] out c
    check "OP3 every version kept, the FIRST one on the very data that is loaded again: its pin comes off and nothing is added" \
        [list $c [ov_marks $out]] [list {0 1 0 0} [list [list {v(a) {} 1 {} {}} [list v(a) $K2 1 1 +40]]]]
    ## the same data: the pin comes off
    set infoS [dict replace $info stamps [dict create [list $R tran] {100 10} [list $K1 tran] {100 10}]]
    lassign [ov_run $infoS $gs] out c
    check "OP3 traces kept on the very data that is loaded again under its name: the pins come off, nothing is added" \
        [list $c [ov_marks $out]] [list {0 2 0 0} [list [list {v(a) {} {} {} {}} {v(b) {} {} {} {}}]]]
    lassign [ov_run [dict replace $info stamps {}] $gs] out c
    check "OP3 with nothing known of either data they count as different: a version each" [lindex $c 0] 2
    ## another analysis, and a net the result lacks
    set gsO [list [strip [tr v(a) rawfile $K1 sim_type ac] [tr v(c) rawfile $K1 sim_type tran] [tr v(b) color 5 rawfile $K1 sim_type tran]]]
    lassign [ov_run $info $gsO] out c
    check "OP3 a trace kept on another analysis and one of a net the result lacks are left as they are, and counted; the third gets its version" \
        [list $c [ov_marks $out]] \
        [list {1 0 1 1} [list [list [list v(a) $K1 {} {} {}] [list v(c) $K1 {} {} {}] [list v(b) $K1 1 {} {}] {v(b) {} 1 1 +40}]]]
    ## an expression is computed by the load, so it is not held to the vector list
    set gsE [list [strip [dict create expr {v(a) v(b) -} name diff vec expr1 color 4 rawfile $K1 sim_type tran]]]
    lassign [ov_run $info $gsE] out c
    check "OP3 an expression whose vector the result does not hold yet gets its version all the same" \
        [list $c [lindex [ov_marks $out] 0 1]] [list {1 0 0 0} {expr1 {} 1 1 +40}]
    ## a trace that named a file of its own (a digital database)
    set V /x/d.vcd
    set KV [wviewer::held_name $V 3 1]
    set infoV [dict replace $info loaded [dict create [list $R tran] 0 [list $KV vcd] 1 [list $V vcd] 2] \
                 stamps [dict create [list $KV vcd] {100 5} [list $V vcd] {200 5}]]
    set gsV [list [strip [tr TOP.q rawfile $KV sim_type vcd]]]
    lassign [ov_run $infoV $gsV] out c
    check "OP3 a trace of a file of its own, kept: its later version names that file again" \
        [list $c [ov_marks $out]] [list {1 0 0 0} [list [list [list TOP.q $KV 1 {} {}] [list TOP.q $V 1 1 +40]]]]
    lassign [ov_run [dict replace $infoV loaded [dict create [list $R tran] 0 [list $KV vcd] 1]] $gsV] out c
    check "OP3 ...and none when that file is not loaded any more" [list $c [expr {$out eq $gsV}]] {{0 0 0 0} 1}
    ## ASE-L's own trace keeps its mark on the version
    set gsB [list [strip [tr v(a) rawfile $K1 sim_type tran byase 1]]]
    lassign [ov_run $info $gsB] out c
    check "OP3 the version of a trace of ASE-L's is ASE-L's too" \
        [lmap t [dict get [lindex $out 0] traces] {wviewer::dget $t byase 0}] {1 1}
    ## the family numbers go on from the largest in the window
    lassign [ov_run [dict replace $info maxid 7] $gs] out c
    check "OP3 a new family takes the number after the largest in use" \
        [lmap t [dict get [lindex $out 0] traces] {dict get $t ovl}] {8 9 8 9}
    check "OP3 the largest in use is read over the strips (none: 0)" \
        [list [pcall wviewer::ovl_gen [tr v(a) ogen 2]] [pcall wviewer::ovl_gen [tr v(a)]] [pcall wviewer::ovl_gen [tr v(a) ogen x]]] {2 0 0}
}

# =============================================================================
# OP4 -- THE LATER VERSIONS GO WHEN EVERY VERSION SHOWS THE SAME DATA
# =============================================================================
group OP4 {
    set K1 [wviewer::held_name /x/r.raw 1]
    set gs [list [strip [tr v(a) ovl 1] [tr v(b) color 5 ovl 2] [tr v(c) color 7] [tr v(a) ovl 1 ogen 1 shade +40] [tr v(b) color 5 ovl 2 ogen 1 shade +40] [tr v(a) ovl 1 ogen 2 shade -35]]]
    lassign [wviewer::ovl_tidy $gs] out gone n delt
    check "OP4 every version on the result: the later ones go, the first traces stay in place with no mark left, a trace with no version is untouched" \
        [list $n [ov_marks $out] [dict get $delt 0]] \
        [list 3 [list [list {v(a) {} {} {} {}} {v(b) {} {} {} {}} {v(c) {} {} {} {}}]] {3 5 4}]
    set gsH [list [strip [tr v(a) rawfile $K1 sim_type tran ovl 1] [tr v(a) ovl 1 ogen 1 shade +40]]]
    lassign [wviewer::ovl_tidy $gsH] out gone n
    check "OP4 a first trace still kept on an earlier result, one later version on the result: nothing goes, and the strips are the ones handed in" \
        [list $n [expr {$out eq $gsH}]] {0 1}
    set gsL [list [strip [tr v(a) ovl 1 ogen 1 shade +40] [tr v(a) ovl 1 ogen 2 shade -35]]]
    lassign [wviewer::ovl_tidy $gsL] out gone n
    check "OP4 the first trace deleted by hand, two later versions on the result: the earlier of the two stays, as an ordinary trace with no mark and no shade" \
        [list $n [ov_marks $out]] [list 1 [list [list {v(a) {} {} {} {}}]]]
    set gsM [list [strip [tr v(a) ovl 1 ogen 1 shade +40] [tr v(b) color 5]]]
    lassign [wviewer::ovl_tidy $gsM] out gone n
    check "OP4 a later version that stands alone and follows the result (its first trace deleted, or it was moved to this strip): nothing goes, and it loses its marks and its shade" \
        [list $n [ov_marks $out]] [list 0 [list [list {v(a) {} {} {} {}} {v(b) {} {} {} {}}]]]
    set gsK [list [strip [tr v(a) rawfile $K1 sim_type tran ovl 1 ogen 1 shade +40]]]
    lassign [wviewer::ovl_tidy $gsK] out gone n
    check "OP4 a later version that stands alone and is kept on earlier data keeps its marks: the next version counts on from it" \
        [list $n [expr {$out eq $gsK}]] {0 1}
    check "OP4 a trace with a shade and no family loses it" \
        [ov_marks [lindex [wviewer::ovl_tidy [list [strip [tr v(a) ogen 1 shade +40]]]] 0]] [list [list {v(a) {} {} {} {}}]]
    set gsN [list [strip [tr v(a)] [tr v(b) color 5]]]
    lassign [wviewer::ovl_tidy $gsN] out gone n
    check "OP4 strips with no version at all are handed back as they are" [list $n [expr {$out eq $gsN}]] {0 1}
    ## the selection and the bold trace follow the traces that stay
    set G [dict create traces [list [tr v(a) ovl 1] [tr v(a) ovl 1 ogen 1 shade +40] [tr v(b) color 5]] hilight_wave 2]
    lassign [wviewer::ovl_tidy [list $G]] out gone n
    check "OP4 a bold trace that stood after a version that went is still the bold one" \
        [list $n [wviewer::dget [lindex $out 0] hilight_wave {}]] {1 1}
    ## what a state file holds
    set gsS [list [strip [tr v(a) rawfile $K1 sim_type tran ovl 1] [tr v(a) ovl 1 ogen 1 shade +40] [tr v(b) color 5]]]
    check "OP4 what is saved holds one version of each waveform, kept on nothing, with no mark" \
        [ov_marks [pcall wviewer::saved_graphs $gsS]] [list [list {v(a) {} {} {} {}} {v(b) {} {} {} {}}]]
    check "OP4 ...and strips with nothing of this are saved as they are" [expr {[pcall wviewer::saved_graphs $gsN] eq $gsN}] 1
    check "OP4 the snapshot and the tab records are written through it" \
        [list [regexp {graphs  \[wviewer::saved_graphs \[wviewer::dget \$lay graphs \{\}\]\]} [info body wviewer::snapshot]] \
              [regexp {wviewer::saved_graphs \$gs} [info body wviewer::layout_held_plain]]] {1 1}
}

# =============================================================================
# OP5 -- THE LEGEND CUE
# =============================================================================
group OP5 {
    set now [clock scan {2026-11-26 15:00:00} -format {%Y-%m-%d %H:%M:%S}]
    set t1 [clock scan {2026-11-26 14:02:11} -format {%Y-%m-%d %H:%M:%S}]
    set t2 [clock scan {2026-11-25 09:30:00} -format {%Y-%m-%d %H:%M:%S}]
    check "OP5 data written today says its time of day; data of another day its day and its time" \
        [list [pcall wviewer::when_text $t1 $now] [pcall wviewer::when_text $t2 $now]] {14:02:11 Nov25_09:30:00}
    check "OP5 two runs of an earlier day within one minute are told apart" \
        [expr {[pcall wviewer::when_text $t2 $now] ne [pcall wviewer::when_text [expr {$t2 + 29}] $now]}] 1
    set tok ov_cue_token
    set K1 [wviewer::held_name /x/r.raw 1]
    set K2 [wviewer::held_name /x/s/r.raw 2]
    set K3 [wviewer::held_name /x/t/r.raw 3]
    set ::wviewer::held($tok) [dict create \
        $K1 [dict create path /x/r.raw type tran when $t2 saved {}] \
        $K2 [dict create path /x/s/r.raw type tran when $t2 saved golden] \
        $K3 [dict create path /x/t/r.raw type tran when {} saved {a "quoted" name}]]
    check "OP5 a trace kept on a saved result says the name it was saved under; one kept on a run says when; a saved name the strip cannot carry falls back; a trace kept on nothing says nothing" \
        [list [pcall wviewer::held_cue [tr v(a) rawfile $K2 sim_type tran]] \
              [regexp {^@([A-Z][a-z][a-z][0-9][0-9]_)?09:30:00$} [pcall wviewer::held_cue [tr v(a) rawfile $K1 sim_type tran]]] \
              [pcall wviewer::held_cue [tr v(a) rawfile $K3 sim_type tran]] \
              [pcall wviewer::held_cue [tr v(a)]]] {@golden 1 @earlier {}}
    unset ::wviewer::held($tok)
}

# =============================================================================
# OP6 -- WHAT THE DIALOG CHOSE LAST
# =============================================================================
group OP6 {
    set key [ov_session op6 tbop6 {} 1.0]
    set other [file join $::scratch op6_other.raw]
    ov_tran $other 10e-9 5.0
    check "OP6 a session whose dialog chose nothing: no note, and the keys read the session's own result as the analysis it plots" \
        [list [pcall ase::ui::rsel_noted $key] [pcall ase::ui::reload_noted $key] [pcall ase::ui::reload_source $key]] \
        [list {} 0 [list $::ov_raw tran {}]]
    ## a file picked by path: the dialog's own two records, as its commit writes them
    pcall ase::result_sel_note $key $other
    pcall ase::ui::rsel_note $key $other tran path
    check "OP6 a file picked by path: it is the note, and what the keys read" \
        [list [pcall ase::ui::rsel_noted $key] [pcall ase::ui::reload_noted $key] [pcall ase::ui::reload_source $key]] \
        [list [list $other tran path] 1 [list $other tran {}]]
    pcall ase::result_sel_note $key [file join $::scratch op6_elsewhere.raw]
    check "OP6 the session's selection moved by another door: the note is not its selection any more" \
        [list [pcall ase::ui::rsel_noted $key] [lindex [pcall ase::ui::reload_source $key] 0]] [list {} $::ov_raw]
    ## the last run with a row's analysis
    pcall ase::result_sel_note $key {}
    pcall ase::ui::rsel_note $key $::ov_raw ac lastrun
    check "OP6 the AC row of the last run: the keys read the last run as that analysis" \
        [list [pcall ase::ui::rsel_noted $key] [pcall ase::ui::reload_source $key]] \
        [list [list $::ov_raw ac lastrun] [list $::ov_raw ac {}]]
    pcall ase::result_sel_note $key $other
    check "OP6 ...until another selection is made: a last-run note under a selection that names a file is over" \
        [pcall ase::ui::rsel_noted $key] {}
    pcall ase::result_sel_note $key {}
    pcall ase::result_view_reset $key
    check "OP6 a new run forgets the note" [list [pcall ase::ui::rsel_noted $key] [pcall ase::ui::reload_source $key]] \
        [list {} [list $::ov_raw tran {}]]
    pcall ase::result_sel_note $key $other
    pcall ase::ui::rsel_note $key $other tran path
    file delete -force $other
    check "OP6 a noted file that is gone is no note" [pcall ase::ui::rsel_noted $key] {}
    pcall ase::ui::rsel_note $key $::ov_raw op lastrun
    pcall ase::result_sel_note $key {}
    check "OP6 an operating-point row is no analysis to plot: the session's own is read" \
        [list [pcall ase::ui::reload_noted $key] [lindex [pcall ase::ui::reload_source $key] 1]] {0 tran}
    pcall ase::result_sel_forget $key
    check "OP6 a state loaded or a session closed forgets both records" \
        [list [pcall ase::result_sel_get $key] [pcall ase::ui::rsel_noted $key]] {{0 {}} {}}
    check "OP6 which gestures the dialog names: all three for a saved result or the last run of the analysis the session plots; the two keys for a file by path, and for a saved result of another analysis than the session's; Ctrl-R alone when the waveforms show another analysis" \
        [list [pcall ase::ui::rsel_kept_how $key saved tran {tran}] [pcall ase::ui::rsel_kept_how $key lastrun tran {}] \
              [pcall ase::ui::rsel_kept_how $key path tran {tran}] [pcall ase::ui::rsel_kept_how $key saved ac {ac}] \
              [pcall ase::ui::rsel_kept_how $key saved ac {tran}] [pcall ase::ui::rsel_kept_how $key lastrun ac {tran ac}]] \
        {all all keys keys reload keys}
    catch {ase::session_close $key}
}

# =============================================================================
# OP7 -- TWO PURE HELPERS OF THE LAST CHECK'S REPAIRS
# =============================================================================
group OP7 {
    check "OP7 a modifier or a lock key pressed alone: either Shift, Control, Alt, Meta, Super and Hyper, the lock keys, AltGr and its kin, the group keys, Mode_switch, the compose key" \
        [lmap k {Shift_L Shift_R Control_L Control_R Alt_L Alt_R Meta_L Meta_R Super_L Super_R Hyper_L Hyper_R
                 Caps_Lock Num_Lock Scroll_Lock Shift_Lock ISO_Level3_Shift ISO_Level5_Shift ISO_Level3_Latch
                 ISO_Group_Shift ISO_Next_Group ISO_Prev_Group_Lock ISO_Lock Mode_switch Multi_key} {wviewer::key_is_modifier $k}] \
        {1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1}
    check "OP7 ...and what is none: what Shift-Tab sends, Tab, a letter, Return, Escape, a function key, a key the keymap does not name" \
        [lmap k {ISO_Left_Tab Tab a Return Escape F5 ?? Shift Lock ISO_Enter Super} {wviewer::key_is_modifier $k}] \
        {0 0 0 0 0 0 0 0 0 0 0}
    ## the strip records of a view, for the strip ASE-L's row comes back to
    set kept [tr v(a) byase 1 rawfile /r/x.raw@held2 sim_type tran ovl 1]
    set keptv [tr v(a) byase 1 rawfile /r/x.raw@held3 sim_type tran ovl 1 ogen 1 shade +40]
    set hand [tr v(b) rawfile /r/x.raw@held2 sim_type tran]
    set own [tr v(c) byase 1]
    set file [tr v(d) byase 1 rawfile /r/other.raw sim_type tran]
    set recs [list [dict create x {1 2 0} tr [list $kept $keptv $hand]] [dict create x {3 4 0} tr [list $own $file]] \
                   [dict create x {5 6 0} tr [list $kept]]]
    set got [wviewer::recs_owned_plain $recs]
    check "OP7 ASE-L's own traces that are kept are named as before the pin, and marked; a kept trace made by hand, ASE-L's trace that is not kept and one on a file of its own are left" \
        [list [lmap t [dict get [lindex $got 0] tr] {list [dict exists $t rawfile] [dict exists $t sim_type] [wviewer::dget $t waskept {}]}] \
              [expr {[dict get [lindex $got 1] tr] eq [list $own $file]}] [dict get [lindex $got 0] x]] \
        {{{0 0 1} {0 0 1} {1 1 {}}} 1 {1 2 0}}
    check "OP7 ...so the row that comes back is the same trace to the view's matching, and its strip one whose traces changed, never the same strip" \
        [list [expr {[wviewer::trace_key [lindex [dict get [lindex $got 0] tr] 0]] eq [wviewer::trace_key [tr v(a) byase 1]]}] \
              [wviewer::view_map [list [dict get [lindex $got 2] tr]] [list [list [tr v(a) byase 1]]]] \
              [wviewer::view_map [list [dict get [lindex $recs 2] tr]] [list [list [tr v(a) byase 1]]]]] \
        {1 {{0 changed}} {{-1 {}}}}
    check "OP7 a range of records: the others are left; a range that is no two integers leaves all" \
        [list [expr {[lindex [wviewer::recs_owned_plain $recs 2 2] 0] eq [lindex $recs 0]}] \
              [expr {[lindex [wviewer::recs_owned_plain $recs 2 2] 2] ne [lindex $recs 2]}] \
              [expr {[wviewer::recs_owned_plain $recs x 2] eq $recs}] [wviewer::recs_owned_plain {}] \
              [expr {[wviewer::recs_owned_plain [list {} notadict(] 0 1] eq [list {} notadict(]}]] \
        {1 1 1 {} 1}
}

# =============================================================================
# THE DISPLAY ARM
# =============================================================================
proc ov_ready {key} {
    set top [wviewer::window_for $key]
    for {set i 0} {$i < 300} {incr i} {
        update
        if {$top ne {} && [winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
        after 20
    }
    return 0
}
proc ov_drw {key} {
    if {[catch {wviewer::window_for $key} w]} { return {} }
    return $w.drw
}
proc ov_gs {key} {
    if {[catch {dict get [wviewer::layout_for $key] graphs} gs]} { return {} }
    return $gs
}
## which run a trace dict shows: v(b)'s first point in the database it names
proc ov_run_of_tr {key tr} {
    if {[catch {xschem new_schematic switch [ov_drw $key]} e]} { return ERR:$e }
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
## per strip, per trace: `vec:run` and, for a later version, `:gen shade`
proc ov_shows {key} {
    lmap G [ov_gs $key] {
        lmap t [wviewer::dget $G traces {}] {
            set s "[wviewer::dget $t vec {}]:[ov_run_of_tr $key $t]"
            if {[wviewer::dget $t ogen {}] ne {}} { append s ":[dict get $t ogen][wviewer::dget $t shade {}]" }
            set s
        }
    }
}
proc ov_ndbs {key} {
    if {[catch {xschem new_schematic switch [ov_drw $key]} e]} { return ERR:$e }
    return [llength [dict get [wviewer::rawinfo_parse [xschem raw info]] dbs]]
}
## the legend names strip gi is drawn with (the alias half of each node token)
proc ov_legend {key gi} {
    if {[catch {
        xschem new_schematic switch [ov_drw $key]
        set node [xschem getprop rect 2 $gi node]
    } e]} { return ERR:$e }
    set out {}
    foreach tok [split $node "\n"] {
        set tok [string trim $tok "\" "]
        if {$tok eq {}} { continue }
        lappend out [lindex [split $tok {;}] 0]
    }
    return $out
}
proc ov_x {key gi} {
    if {[catch {
        xschem new_schematic switch [ov_drw $key]
        set r [list [expr {double([xschem getprop rect 2 $gi x1])}] [expr {double([xschem getprop rect 2 $gi x2])}]]
    } e]} { return ERR:$e }
    return $r
}
proc ov_y {key gi} {
    if {[catch {
        xschem new_schematic switch [ov_drw $key]
        set r [list [format %.4g [xschem getprop rect 2 $gi y1]] [format %.4g [xschem getprop rect 2 $gi y2]]]
    } e]} { return ERR:$e }
    return $r
}
## A real key press on the viewer canvas, the keyboard there first. Answers
## whether the canvas had the keyboard when the key went in.
proc ov_key {key seq} {
    set drw [ov_drw $key]
    catch {raise [winfo toplevel $drw]}
    focus -force $drw
    update
    set had [expr {[focus] eq $drw}]
    event generate $drw $seq
    update
    return $had
}
## a legend cue that says when: the time of day, with the day before it when
## the fixture's later "run" falls on tomorrow (a suite started before midnight)
set ::ov_when {([A-Z][a-z][a-z][0-9][0-9]_)?[0-9][0-9]:[0-9][0-9]:[0-9][0-9]}
## the small window that says there is nothing to overlay: its two sentences,
## {} when it is not up
proc ov_notice {key} {
    set w [wviewer::window_for $key].wvnotice
    if {![winfo exists $w]} { return {} }
    set out [list [$w.msg cget -text]]
    if {[winfo exists $w.detail]} { lappend out [$w.detail cget -text] }
    return $out
}
proc ov_notice_close {key} {
    set w [wviewer::window_for $key].wvnotice
    if {![winfo exists $w]} { return 0 }
    $w.btns.ok invoke
    update
    return [expr {![winfo exists $w]}]
}
## the colours on the viewer canvas after a fresh redraw: a dict #rrggbb -> how
## many pixels
proc ov_colors {key} {
    if {[catch {
        xschem new_schematic switch [ov_drw $key]
        xschem redraw
        update
        lassign [xschem window_snapshot take 6] w h
        set c [dict create]
        foreach p [string tolower [xschem window_snapshot pixels 6 0 0 $w $h]] { dict incr c $p }
        xschem window_snapshot free
    } e]} { return ERR:$e }
    return $c
}
proc ov_layer_col {l} { return [string tolower [lindex $tctx::colors $l]] }
## Is a CURVE painted in colour c? A curve across a strip is some hundreds of
## pixels. The edge of an antialiased legend letter blends the layer's colour
## with the background, and a few such pixels can land on a shade towards
## black, so the test is a count and not a presence.
proc ov_has {cols c} {
    set n 0
    catch {set n [dict get $cols [string tolower $c]]}
    if {[info exists ::env(OV_SHOW)]} { puts "note: $c x$n" }
    return [expr {$n >= 150}]
}

if {$GUI} {
set ::ov_bg {}
interp bgerror {} [list apply {{m o} { lappend ::ov_bg $m }}]

group OV1 {
    set ::ov_key [ov_session ov tbov {{name A expr v(a) save 1 plot 1}} 1.0]
    set key $::ov_key
    check "OV1 fixture: the viewer opens and maps" [list [pcall wviewer::open $key] [ov_ready $key]] {1 1}
    check "OV1 Alt-Shift-P is bound on the viewer's tag to the overlay, and stops there" \
        [string trim [bind WaveViewer <Alt-Shift-Key-P>]] {wviewer::overlay_latest_at %W; break}
    check "OV1 ...and so is the same chord as Caps Lock hands it over" \
        [string trim [bind WaveViewer <Alt-Shift-Key-p>]] {wviewer::overlay_latest_at %W; break}
    ## an rc that gave the key another job does not find the chord on the
    ## overlay under Caps Lock
    set k0 [bind WaveViewer <Alt-Shift-Key-P>]
    set k1 [bind WaveViewer <Alt-Shift-Key-p>]
    bind WaveViewer <Alt-Shift-Key-P> {set ::ov_other 1; break}
    bind WaveViewer <Alt-Shift-Key-p> {}
    ## (the defaults are installed once per process; the flag is put back so
    ## that they are installed again as at a start)
    set ::wviewer::tagbinds 0
    pcall wviewer::install_default_binds
    set got [list [string trim [bind WaveViewer <Alt-Shift-Key-P>]] [bind WaveViewer <Alt-Shift-Key-p>]]
    bind WaveViewer <Alt-Shift-Key-P> {}
    set ::wviewer::tagbinds 0
    pcall wviewer::install_default_binds
    lappend got [expr {[bind WaveViewer <Alt-Shift-Key-P>] eq $k0}] [expr {[bind WaveViewer <Alt-Shift-Key-p>] eq $k1}]
    ## whatever the row found, the rest of the suite needs the two lines
    bind WaveViewer <Alt-Shift-Key-P> $k0
    bind WaveViewer <Alt-Shift-Key-p> $k1
    check "OV1 with the key given another job by an rc, the defaults leave that job alone and do not bind the Caps Lock form; with the key free both are the overlay's again" \
        $got {{set ::ov_other 1; break} {} 1 1}
    check "OV1 Alt-P and plain Shift-P are not bound there" \
        [list [bind WaveViewer <Alt-Key-p>] [bind WaveViewer <Key-P>] [bind WaveViewer <Shift-Key-P>]] {{} {} {}}
    set m [wviewer::window_for $key].wvmenubar.file
    set at [pcall $m index {Overlay Latest}]
    check "OV1 File > Overlay Latest is in the menu, shows Alt+Shift+P, and stands between Reload and the separator" \
        [list [pcall $m entrycget {Overlay Latest} -accelerator] [pcall $m entrycget [expr {$at - 1}] -label] \
              [pcall $m type [expr {$at + 1}]]] {Alt+Shift+P Reload separator}
}

group OV2 {
    set key $::ov_key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    check "OV2 fixture: the bench run again (amplitude 2); with the option off the finished run plots nothing, so both strips still show run 1 (the net picked in the schematic on top, ASE-L's row under it)" \
        [list [ov_rerun 2.0 7] [pcall ase::ui::auto_plot_idle $key] [ov_shows $key]] {1 {} {v(b):1 v(a):1}}
    set ng0 [llength [ov_gs $key]]
    set tgt0 [wviewer::target_index $key]
    set h0 [lindex [wviewer::history_depth $key] 0]
    set ::ov_said {}
    set ::ov_logged {}
    set had [ov_key $key <Alt-Shift-Key-P>]
    check "OV2 a real Alt-Shift-P on the viewer canvas (which had the keyboard): each strip holds its waveform twice, the first trace still on run 1 and a later version on run 2, in the first shade" \
        [list $had [ov_shows $key]] {1 {{v(b):1 v(b):2:1+40} {v(a):1 v(a):2:1+40}}}
    check "OV2 ...in the layer of the first trace" \
        [lmap G [ov_gs $key] { lsort -unique [lmap t [dict get $G traces] {dict get $t color}] }] \
        [lmap G [ov_gs $key] { list [dict get [lindex [dict get $G traces] 0] color] }]
    check "OV2 ...the strips, the target and ASE-L's mark on its row are what they were, and the versions are one undo step" \
        [list [llength [ov_gs $key]] [expr {[wviewer::target_index $key] == $tgt0}] \
              [lmap G [ov_gs $key] { lmap t [dict get $G traces] {wviewer::dget $t byase 0} }] \
              [expr {[lindex [wviewer::history_depth $key] 0] - $h0}]] [list $ng0 1 {{0 0} {1 1}} 1]
    set lg [ov_legend $key 1]
    check "OV2 ...the earlier version's legend name ends in the time of its run, the later one's is the plain name" \
        [list [llength $lg] [regexp "^A@$::ov_when\$" [lindex $lg 0]] [lindex $lg 1]] {2 1 A}
    check "OV2 ...one sentence says what was overlaid and how to go back, and one line is logged" \
        [list [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}] $::ov_logged] \
        [list [list {wviewer: overlaid tbov_ase.raw (tran): 2 traces added beside the earlier versions. Ctrl-R goes back to one version of each.}] \
              [list [list wviewer::overlay_latest $key]]]
    check "OV2 ...the earlier run's data is kept beside the result, and no window came up" [list [ov_ndbs $key] [ov_notice $key]] {2 {}}
    check "OV2 no background error" $::ov_bg {}
}

group OV3 {
    set key $::ov_key
    set lay0 [wviewer::layout_for $key]
    set h0 [wviewer::history_depth $key]
    set ::ov_said {}
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV3 pressed again with no new run: the model and the undo history are what they were and nothing is logged" \
        [list [expr {[wviewer::layout_for $key] eq $lay0}] [expr {[wviewer::history_depth $key] eq $h0}] $::ov_logged] {1 1 {}}
    check "OV3 ...a small window says every waveform shows the latest result already; with ASE-L's option off it blames nothing" \
        [ov_notice $key] [list {Every waveform in this window already shows the latest result (tbov_ase.raw (tran)).} {There is nothing newer to overlay.}]
    check "OV3 ...the sentence is in the CIW too, the window takes no grab, and OK closes it" \
        [list [expr {[lsearch -glob $::ov_said {wviewer: Every waveform in this window already shows the latest result*}] >= 0}] \
              [grab current] [ov_notice_close $key]] {1 {} 1}
    ## the same chord as Caps Lock hands it over: the lower-case keysym
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-p>
    check "OV3 the chord with Caps Lock on does the same: the window comes up again, one of it" \
        [list [llength [lsearch -all -glob [winfo children [wviewer::window_for $key]] *.wvnotice]] \
              [expr {[lsearch -glob $::ov_said {wviewer: Every waveform in this window already shows the latest result*}] >= 0}] \
              [ov_notice_close $key]] {1 1 1}
    check "OV3 no background error" $::ov_bg {}
}

group OV4 {
    set key $::ov_key
    ov_rerun 3.0 14
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV4 another run and the key again: three versions of each waveform, on runs 1, 2 and 3, the third in the second shade" \
        [ov_shows $key] {{v(b):1 v(b):2:1+40 v(b):3:2-35} {v(a):1 v(a):2:1+40 v(a):3:2-35}}
    check "OV4 ...the two earlier runs are kept beside the result, and the sentence counts the two new traces" \
        [list [ov_ndbs $key] [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}]] \
        [list 3 [list {wviewer: overlaid tbov_ase.raw (tran): 2 traces added beside the earlier versions. Ctrl-R goes back to one version of each.}]]
    set lg [ov_legend $key 0]
    check "OV4 ...each earlier version says its own run's time, and the two times differ" \
        [list [llength $lg] [expr {[lindex $lg 0] ne [lindex $lg 1]}] [regexp {^v\(b\)@} [lindex $lg 0]] [regexp {^v\(b\)@} [lindex $lg 1]] [lindex $lg 2]] \
        {3 1 1 1 v(b)}
}

group OV5 {
    set key $::ov_key
    set gs [ov_gs $key]
    set layer [dict get [lindex [dict get [lindex $gs 0] traces] 0] color]
    set own [ov_layer_col $layer]
    set s1 [pcall xschem get graph_shade_color $layer 40]
    set s2 [pcall xschem get graph_shade_color $layer -35]
    check "OV5 a shade is another colour than the layer's own, and the two shades differ" \
        [list [expr {$s1 ne $own}] [expr {$s2 ne $own}] [expr {$s1 ne $s2}] [regexp {^#[0-9a-f]{6}$} $s1]] {1 1 1 1}
    lassign [scan $own "#%2x%2x%2x"] r g b
    check "OV5 40 is that far towards white, -35 that far towards black, channel by channel" \
        [list $s1 $s2] \
        [list [format "#%02x%02x%02x" [expr {($r*60+255*40+50)/100}] [expr {($g*60+255*40+50)/100}] [expr {($b*60+255*40+50)/100}]] \
              [format "#%02x%02x%02x" [expr {($r*65+50)/100}] [expr {($g*65+50)/100}] [expr {($b*65+50)/100}]]]
    ## (no query between here and the screen: a shade the query left in the
    ## layer would paint the first trace, which the next row counts)
    set cols [ov_colors $key]
    check "OV5 on the screen: the layer's own colour and both shades are painted" \
        [list [ov_has $cols $own] [ov_has $cols $s1] [ov_has $cols $s2]] {1 1 1}
}

group OV6 {
    set key $::ov_key
    set before [ov_shows $key]
    ov_key $key <Key-u>
    check "OV6 u takes the versions of the last press out: two versions of each again, the earlier ones still on their runs" \
        [ov_shows $key] {{v(b):1 v(b):2:1+40} {v(a):1 v(a):2:1+40}}
    set cols [ov_colors $key]
    set layer [dict get [lindex [dict get [lindex [ov_gs $key] 0] traces] 0] color]
    check "OV6 ...and the second shade is gone from the screen while the first is still there" \
        [list [ov_has $cols [pcall xschem get graph_shade_color $layer -35]] \
              [ov_has $cols [pcall xschem get graph_shade_color $layer 40]]] {0 1}
    ov_key $key <Key-U>
    check "OV6 U puts them back" [ov_shows $key] $before
}

group OV7 {
    set key $::ov_key
    set ::ov_said {}
    set ::ov_logged {}
    ov_key $key <Control-Key-r>
    check "OV7 Ctrl-R: one version of each waveform, the first trace, on the result, with no mark and no shade" \
        [list [ov_shows $key] [ov_marks [ov_gs $key]]] \
        [list {v(b):3 v(a):3} [list [list {v(b) {} {} {} {}}] [list {v(a) {} {} {} {}}]]]
    check "OV7 ...the kept data is gone, and the sentence counts what was put back and what was taken out" \
        [list [ov_ndbs $key] [pcall wviewer::held_traces $key] [lsearch -all -inline -glob $::ov_said {wviewer: reloaded*}]] \
        [list 1 0 [list {wviewer: reloaded tbov_ase.raw (tran) (2 traces kept on an earlier run show it again) (4 later versions of waveforms taken out)}]]
    ## every strip, so a shade left in a layer by the frame before would show
    set cols [ov_colors $key]
    set got {}
    foreach G [ov_gs $key] {
        set layer [dict get [lindex [dict get $G traces] 0] color]
        lappend got [list [ov_has $cols [pcall xschem get graph_shade_color $layer -35]] \
                          [ov_has $cols [pcall xschem get graph_shade_color $layer 40]] [ov_has $cols [ov_layer_col $layer]]]
    }
    check "OV7 ...and in each strip no shade is left on the screen, while the layer's own colour is" $got {{0 0 1} {0 0 1}}
    ## the undo history still holds the model of the second press, whose
    ## versions were kept on data that is gone now
    ov_key $key <Key-u>
    check "OV7 u after that: the model of an earlier press comes back with its kept data gone, so one version of each on the result, not two that show the same" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key]] {{v(b):3 v(a):3} 0}
    check "OV7 no background error" $::ov_bg {}
}

group OV8 {
    catch {wviewer::close $::ov_key}
    catch {ase::session_close $::ov_key}
    set key [ov_session ov8 tbov8 {{name A expr v(a) save 1 plot 1}} 1.0]
    set ::ov_key8 $key
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    ov_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "OV8 fixture: ASE-L's option on (the default). A finished run's plot: ASE-L's row shows run 2, the net picked by hand is kept on run 1" \
        [list [pcall ase::ui::plot_after_sim $key] [ov_shows $key] [pcall wviewer::held_traces $key]] {1 {v(b):1 v(a):2} 1}
    set ::ov_said {}
    set ::ov_logged {}
    set m [wviewer::window_for $key].wvmenubar.file
    pcall $m invoke {Overlay Latest}
    update
    check "OV8 File > Overlay Latest: the trace made by hand gets its version on run 2; ASE-L's row, which is on run 2, gets none" \
        [list [ov_shows $key] $::ov_logged [ov_notice $key]] \
        [list {{v(b):1 v(b):2:1+40} v(a):2} [list [list wviewer::overlay_latest $key]] {}]
    check "OV8 ...and the sentence counts the one trace" \
        [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}] \
        [list {wviewer: overlaid tbov8_ase.raw (tran): 1 trace added beside the earlier version. Ctrl-R goes back to one version of each.}]
    set lay0 [wviewer::layout_for $key]
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV8 the key again, with ASE-L plotting every finished run: nothing changes, nothing is logged, and the window says where that is set" \
        [list [expr {[wviewer::layout_for $key] eq $lay0}] $::ov_logged [ov_notice $key]] \
        [list 1 {} [list {Every waveform in this window already shows the latest result (tbov8_ase.raw (tran)).} \
                         {ASE-L plotted it when the simulation finished: Results > Auto Plot Outputs After Simulation is ticked in the ASE-L window. Untick it to keep the earlier waveforms until you ask for the new ones here.}]]
    check "OV8 the menu entry the window names is the one ASE-L's Results menu carries" \
        [list [pcall ase::ui::lbl_plot_after_sim_menu] \
              [expr {[string first "Results > [pcall ase::ui::lbl_plot_after_sim_menu] is ticked" [lindex [ov_notice $key] 1]] >= 0}]] \
        {{Auto Plot Outputs After Simulation} 1}
    check "OV8 Return closes the window" \
        [list [pcall event generate [wviewer::window_for $key].wvnotice <Return>] [update] [ov_notice $key]] {{} {} {}}
    ## a second window replaces the first: never two
    ov_key $key <Alt-Shift-Key-P>
    ov_key $key <Alt-Shift-Key-P>
    check "OV8 pressed twice: one window, and Escape closes it" \
        [list [llength [lsearch -all -glob [winfo children [wviewer::window_for $key]] *.wvnotice]] \
              [pcall event generate [wviewer::window_for $key].wvnotice <Escape>] [update] [ov_notice $key]] {1 {} {} {}}
    ## another finished run: its plot keeps the later version too
    ov_rerun 3.0 14
    pcall ase::ui::auto_plot_idle $key
    update
    check "OV8 another finished run: ASE-L's row moves to run 3, both versions of the hand trace stay on their runs" \
        [ov_shows $key] {{v(b):1 v(b):2:1+40} v(a):3}
    ov_key $key <Alt-Shift-Key-P>
    check "OV8 ...and the key gives the hand trace its third version, on run 3" \
        [ov_shows $key] {{v(b):1 v(b):2:1+40 v(b):3:2-35} v(a):3}
    check "OV8 no background error" $::ov_bg {}
}

group OV9 {
    set key $::ov_key8
    pcall ase::ui::plot_outputs $key
    update
    check "OV9 ASE-L's plot button after an overlay: one version of each waveform, on the result, no mark, no kept data" \
        [list [ov_shows $key] [ov_marks [ov_gs $key]] [pcall wviewer::held_traces $key] [ov_ndbs $key]] \
        [list {v(b):3 v(a):3} [list [list {v(b) {} {} {} {}}] [list {v(a) {} {} {} {}}]] 0 1]
    check "OV9 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV10 {
    set key [ov_session ov10 tbov10 {{name A expr v(a) save 1 plot 1}} 1.0]
    set ::ov_key10 $key
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    ## run 1 is saved as `gold`; then the bench is run again and reloaded
    pcall ase::saved_save $key gold {} {} 0
    set sraw {}
    foreach e [pcall ase::saved_list $key] {
        if {[ase::state_get [ase::saved_meta [dict get $e dir]] name] eq {gold}} {
            set sraw [file join [dict get $e dir] [file tail $::ov_raw]]
        }
    }
    set ::ov_sraw $sraw
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Control-Key-r>
    check "OV10 fixture: run 1 saved as gold with its own results file; the viewer shows run 2, nothing kept" \
        [list [file isfile $sraw] [ov_shows $key] [pcall wviewer::held_traces $key]] {1 {v(b):2 v(a):2} 0}
    set gb 0
    catch {
        xschem new_schematic switch [ov_drw $key]
        xschem graph_axis_zoom $gb x 2e-9 5e-9
    }
    update
    set y0 [ov_y $key 0]
    set ::ov_said {}
    pcall ase::ui::rsel_arm $key $sraw tran saved
    set r [pcall ase::ui::rsel_commit $key]
    update
    check "OV10 Results > Select of the saved result goes through: ASE-L has it in view" \
        [list $r [pcall ase::last_rawfile $key]] [list 1 $sraw]
    check "OV10 ...and plots nothing: every waveform still shows run 2, kept on it, in the window it showed" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] [ov_x $key 0] [ov_y $key 0]] \
        [list {v(b):2 v(a):2} 2 [list 2e-9 5e-9] $y0]
    set lg [list [ov_legend $key 0] [ov_legend $key 1]]
    check "OV10 ...each legend name says which data it still shows" \
        [list [regexp "^v\\(b\\)@$::ov_when\$" [lindex $lg 0 0]] [regexp "^A@$::ov_when\$" [lindex $lg 1 0]]] {1 1}
    check "OV10 ...the dialog's status and the CIW say the waveforms did not move, and which keys move them" \
        [list [expr {[string first [pcall ase::ui::lbl_rsel_plots_kept] $::ase::ui::dlg($key,rselstatus)] > 0}] \
              [expr {[lsearch -exact $::ov_said [pcall ase::ui::lbl_rsel_plots_kept]] >= 0}] \
              [regexp {plot button \(~\) here, or Ctrl-R in the viewer.*Alt-Shift-P in the viewer} [pcall ase::ui::lbl_rsel_plots_kept]]] {1 1 1}
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV10 Alt-Shift-P then draws the saved result beside them: each waveform on run 2 and, in the shade, on the saved run 1" \
        [ov_shows $key] {{v(b):2 v(b):1:1+40} {v(a):2 v(a):1:1+40}}
    check "OV10 ...and the sentence names the saved result by its name" \
        [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}] \
        [list {wviewer: overlaid gold (tran): 2 traces added beside the earlier versions. Ctrl-R goes back to one version of each.}]
    ov_key $key <Control-Key-r>
    check "OV10 Ctrl-R replaces with it: one version of each, on the saved result" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key]] {{v(b):1 v(a):1} 0}
    check "OV10 no background error" $::ov_bg {}
}

group OV11 {
    set key $::ov_key10
    set sraw $::ov_sraw
    ## back to the latest run in the dialog: the plots stay on the saved result
    pcall ase::ui::rsel_arm $key $::ov_raw tran lastrun
    set r [pcall ase::ui::rsel_commit $key]
    update
    check "OV11 Results > Select of the latest run: the plots stay on the saved result, and their legend names say its name" \
        [list $r [pcall ase::last_rawfile $key] [ov_shows $key] [lindex [ov_legend $key 1] 0]] \
        [list 1 $::ov_raw {v(b):1 v(a):1} A@gold]
    ## and the saved result again: the plots show the result in view, so nothing is kept
    pcall ase::ui::rsel_arm $key $sraw tran saved
    set ::ov_said {}
    set r [pcall ase::ui::rsel_commit $key]
    update
    check "OV11 the saved result selected again: the plots show the result in view, so their pins and their legend cue come off, and the dialog has nothing to add" \
        [list $r [ov_shows $key] [pcall wviewer::held_traces $key] [lindex [ov_legend $key 1] 0] \
              [expr {[string first [pcall ase::ui::lbl_rsel_plots_kept] $::ase::ui::dlg($key,rselstatus)] >= 0}]] \
        {1 {v(b):1 v(a):1} 0 A 0}
    ## and once more, with nothing kept: the data in view does not move
    set r [pcall ase::ui::rsel_commit $key]
    update
    check "OV11 the same result selected once more: the data in view did not move, so nothing is kept, one database stays current under its own name, and the dialog has nothing to add" \
        [list $r [ov_shows $key] [pcall wviewer::held_traces $key] [lindex [ov_legend $key 1] 0] \
              [expr {[string first [pcall ase::ui::lbl_rsel_plots_kept] $::ase::ui::dlg($key,rselstatus)] >= 0}]] \
        {1 {v(b):1 v(a):1} 0 A 0}
    set lay0 [wviewer::layout_for $key]
    ov_key $key <Alt-Shift-Key-P>
    check "OV11 ...and Alt-Shift-P finds nothing to overlay: the model is what it was and the window names the saved result" \
        [list [expr {[wviewer::layout_for $key] eq $lay0}] [lindex [ov_notice $key] 0]] \
        [list 1 {Every waveform in this window already shows the result in view (gold (tran)).}]
    ov_notice_close $key
    check "OV11 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV12 {
    ## another analysis: a session that shows its AC analysis, a transient
    ## attached to its viewer by hand
    set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 points 10 start 1 stop 1e6} {type tran enabled 0 stop 10n step 100p}}
    set key [ov_session ov12 tbov12 {} {} $an]
    ov_ac $::ov_raw
    set f [file join $::scratch ov12_tran.raw]
    ov_tran $f 10e-9 1.0
    check "OV12 fixture: the session's result in view is its AC analysis; a transient is attached to its viewer by hand and v(b) plotted" \
        [list [pcall ase::ui::reload_source $key] [pcall wviewer::open $key] [ov_ready $key] \
              [pcall wviewer::attach_raw $key $f tran] [pcall wviewer::add_trace $key 0 v(b)]] \
        [list [list $::ov_raw ac {}] 1 1 1 {}]
    update
    set lay0 [wviewer::layout_for $key]
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV12 waveforms of an analysis the result's file does not hold: nothing is overlaid, the viewer's data is what it was, nothing logged, and the window says which analysis is missing and what replaces" \
        [list [expr {[wviewer::layout_for $key] eq $lay0}] [ov_ndbs $key] $::ov_logged [ov_notice $key]] \
        [list 1 1 {} [list {The waveforms in this window are of the tran analysis, and tbov12_ase.raw (ac), which ASE-L has in view, holds none of it to draw beside them: nothing is overlaid.} \
                           {Ctrl-R replaces the waveforms with that result.}]]
    ov_notice_close $key
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## a live run, a file that cannot be read, no file, no waveform, no window
    set key [ov_session ov12b tbov12b {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    set lay00 [wviewer::layout_for $key]
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV12 no waveform in the window: nothing is read, and the window says to plot first" \
        [list [expr {[wviewer::layout_for $key] eq $lay00}] $::ov_logged [ov_notice $key]] \
        [list 1 {} [list {No waveform is plotted in this window, so there is nothing to overlay tbov12b_ase.raw (tran) on.} \
                         {Plot the waveforms first: the plot button (~) in ASE-L, or pick nets in the schematic.}]]
    ov_notice_close $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    set ::ov_m0 [file mtime $::ov_raw]
    ov_rerun 2.0 7
    rename ::ase::ui::reload_busy ::ase::ui::ov_busy_orig
    proc ::ase::ui::reload_busy {key} { return 1 }
    set ::ov_said {}
    set ::ov_logged {}
    set lay0 [wviewer::layout_for $key]
    ov_key $key <Alt-Shift-Key-P>
    rename ::ase::ui::reload_busy {}
    rename ::ase::ui::ov_busy_orig ::ase::ui::reload_busy
    check "OV12 while the session's run is live the key reads nothing: one sentence says why, nothing changes, nothing is logged" \
        [list [lsearch -all -inline -glob $::ov_said {wviewer: a simulation of this session is running*}] \
              [expr {[wviewer::layout_for $key] eq $lay0}] [ov_shows $key] $::ov_logged] \
        [list [list {wviewer: a simulation of this session is running; overlay its result when it has finished}] 1 {v(b):1 v(a):1} {}]
    ## the file now holds no transient (what a read finds while a run writes it)
    file stat $::ov_raw a0
    ov_ac $::ov_raw
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    set ::ov_said {}
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV12 a file that cannot be read as the analysis shown: the viewer is as it was (run 1 on every trace, nothing kept, one database), one sentence says so, nothing is logged" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] [ov_ndbs $key] \
              [lsearch -all -inline -glob $::ov_said {wviewer: could not overlay*}] $::ov_logged] \
        [list {v(b):1 v(a):1} 0 1 [list "wviewer: could not overlay tbov12b_ase.raw: nothing was read as its tran analysis; the viewer shows what it showed"] {}]
    ## the file as the viewer read it: the same numbers, the same time
    ov_tran $::ov_raw 10e-9 1.0
    file mtime $::ov_raw $::ov_m0
    set lay0 [wviewer::layout_for $key]
    ov_key $key <Alt-Shift-Key-P>
    check "OV12 ...and with the file as it was read, the key knows the viewer shows it: nothing is read or added" \
        [list [expr {[wviewer::layout_for $key] eq $lay0}] [ov_ndbs $key] [lindex [ov_notice $key] 0]] \
        [list 1 1 {Every waveform in this window already shows the latest result (tbov12b_ase.raw (tran)).}]
    ov_notice_close $key
    file delete -force $::ov_raw
    set ::ov_said {}
    set r [pcall wviewer::overlay_latest $key]
    check "OV12 no result file: one sentence, 0, nothing changes" \
        [list $r [lsearch -all -inline -glob $::ov_said {wviewer: nothing to overlay*}] [ov_shows $key]] \
        [list 0 [list {wviewer: nothing to overlay: no result file is attached to this window}] {v(b):1 v(a):1}]
    check "OV12 a window that does not exist: a sentence and nothing else" \
        [list [pcall wviewer::overlay_latest no_such_viewer] [expr {[lsearch -glob $::ov_said {wviewer: no waveform viewer window to overlay a result in}] >= 0}]] {{} 1}
    check "OV12 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

## the value of vector `vec` at point 0 in the database trace `tr` names
proc ov_val_of_tr {key tr vec} {
    if {[catch {xschem new_schematic switch [ov_drw $key]} e]} { return ERR:$e }
    set cur [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]
    if {[dict exists $tr rawfile]} {
        if {[catch {xschem raw switch [dict get $tr rawfile] [dict get $tr sim_type]} r] || $r ne {1}} {
            catch {xschem raw switch $cur}
            return NODB
        }
    }
    set v NOVEC
    catch {set v [format %.4g [xschem raw value $vec 0]]}
    catch {xschem raw switch $cur}
    return $v
}

group OV13 {
    ## the first result holds a third net, v(c); the later one does not
    set key [ov_session ov13 tbov13 {{name A expr v(a) save 1 plot 1}} 1.0 {} 1]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    pcall ase::ui::dp_finish $key {v(c)}
    update
    ## a difference of two nets, in a strip of its own
    pcall wviewer::add_graph $key
    set gd [expr {[llength [ov_gs $key]] - 1}]
    check "OV13 fixture: a difference v(a) - v(b) is plotted as an expression" \
        [pcall wviewer::add_trace $key $gd {v(a) v(b) -} dif] {}
    update
    set gb -1
    set gi 0
    foreach G [ov_gs $key] {
        foreach t [dict get $G traces] { if {[dict get $t vec] eq {v(b)}} { set gb $gi } }
        incr gi
    }
    catch {
        xschem new_schematic switch [ov_drw $key]
        xschem graph_axis_zoom $gb x 2e-9 5e-9
    }
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7 0
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-P>
    set byvec [dict create]
    set gi 0
    foreach G [ov_gs $key] {
        foreach t [dict get $G traces] {
            dict lappend byvec [dict get $t vec] [list $gi [wviewer::dget $t ogen 0] [ov_val_of_tr $key $t [dict get $t vec]]]
        }
        incr gi
    }
    check "OV13 the strip zoomed in X keeps its X window, and its Y is fitted over both versions (run 2 reaches 1.6 there)" \
        [list [ov_x $key $gb] [ov_y $key $gb]] [list [list 2e-9 5e-9] {0.5 1.6}]
    check "OV13 the difference gets its version, computed on the new result: -1 on run 1, -2 on run 2" \
        [lmap e [dict get $byvec dif] {lrange $e 1 2}] {{0 -1} {1 -2}}
    check "OV13 a net the new result lacks is left on the run it shows, with no version" \
        [lmap e [dict get $byvec v(c)] {lrange $e 1 2}] {{0 0.5}}
    check "OV13 ...and the sentence counts it" \
        [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}] \
        [list {wviewer: overlaid tbov13_ase.raw (tran): 3 traces added beside the earlier versions (1 trace with no data in this result left as it is). Ctrl-R goes back to one version of each.}]
    check "OV13 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV14 {
    set key [ov_session ov14 tbov14 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    set id0 [pcall wviewer::tab_id $key]
    pcall wviewer::new_tab $key
    update
    pcall ase::ui::dp_finish $key {v(b)}
    update
    set id1 [pcall wviewer::tab_id $key]
    pcall wviewer::select_tab $id0 $key
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    check "OV14 fixture: two tabs, ASE-L's row in the first (shown), a net picked by hand in the second; both on run 1" \
        [list [pcall wviewer::tab_count $key] [expr {$id0 ne $id1}] [ov_shows $key]] {2 1 v(a):1}
    ov_key $key <Alt-Shift-Key-P>
    check "OV14 the key in the first tab: its waveform has two versions" [ov_shows $key] {{v(a):1 v(a):2:1+40}}
    pcall wviewer::select_tab $id1 $key
    update
    check "OV14 ...and so has the waveform of the tab that was not shown" [ov_shows $key] {{v(b):1 v(b):2:1+40}}
    ## what a saved state holds
    set snap [pcall wviewer::snapshot $key {}]
    set tabs [wviewer::dget $snap tabs {}]
    check "OV14 a saved state holds one version of each waveform in every tab, kept on nothing, with no mark" \
        [list [ov_marks [wviewer::dget $snap graphs {}]] \
              [lmap t $tabs {ov_marks [wviewer::dget [wviewer::dget $t layout {}] graphs {}]}]] \
        [list [list [list {v(b) {} {} {} {}}]] [list [list [list {v(a) {} {} {} {}}]] [list [list {v(b) {} {} {} {}}]]]]
    check "OV14 ...while the window still shows both versions" [ov_shows $key] {{v(b):1 v(b):2:1+40}}
    ## Ctrl-R in the first tab takes the later versions out of both
    pcall wviewer::select_tab $id0 $key
    update
    ov_key $key <Control-Key-r>
    set a [ov_shows $key]
    pcall wviewer::select_tab $id1 $key
    update
    check "OV14 Ctrl-R in the first tab: one version of each waveform there and in the tab that was not shown" \
        [list $a [ov_shows $key] [ov_marks [ov_gs $key]]] [list v(a):2 v(b):2 [list [list {v(b) {} {} {} {}}]]]
    check "OV14 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV16 {
    ## one strip, a waveform with a later version, and a trace added after it
    set key [ov_session ov16 tbov16 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode single $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Alt-Shift-Key-P>
    pcall wviewer::add_trace $key 0 v(b)
    update
    check "OV16 fixture: one strip holds v(a), its later version, and v(b) plotted after the overlay" \
        [ov_shows $key] {{v(a):1 v(a):2:1+40 v(b):2}}
    ## the third trace is highlighted, and bold. The bold mark is written into
    ## the STRIP, as a click on the trace writes it: the model does not hold it
    ## until something folds the strips
    set ::wviewer::wavehl($key) {{0 2 1}}
    pcall wviewer::with_edit $key [list xschem setprop -fast rect 2 0 hilight_wave 2]
    check "OV16 fixture: the bold mark is on the strip and not in the model yet" \
        [list [pcall apply {{key} { xschem new_schematic switch [ov_drw $key] ; xschem getprop rect 2 0 hilight_wave }} $key] \
              [wviewer::dget [lindex [ov_gs $key] 0] hilight_wave {}]] {2 {}}
    ov_key $key <Control-Key-r>
    check "OV16 Ctrl-R takes the later version out from before it: the highlight and the bold mark follow v(b) to its new place" \
        [list [ov_shows $key] [pcall wviewer::wave_hilights $key] [wviewer::dget [lindex [ov_gs $key] 0] hilight_wave {}]] \
        {{{v(a):2 v(b):2}} {{0 1 1}} 1}
    ## the same with NOTHING kept: two versions of v(a) that both follow the
    ## result (what a finished run of another analysis leaves), then v(b)
    set G [dict remove [lindex [ov_gs $key] 0] hilight_wave sel_waves]
    set t0 [lindex [dict get $G traces] 0]
    set t1 [lindex [dict get $G traces] 1]
    pcall wviewer::set_graphs $key [list [dict replace $G traces \
        [list [dict replace $t0 ovl 1] [dict replace $t0 ovl 1 ogen 1 shade +40] $t1]]]
    pcall wviewer::regenerate $key [wviewer::live_axes $key]
    update
    set ::wviewer::wavehl($key) {{0 2 1}}
    pcall wviewer::with_edit $key [list xschem setprop -fast rect 2 0 hilight_wave 2]
    check "OV16 fixture: two versions of v(a) that both follow the result, nothing kept, v(b) after them bold on the strip" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] [wviewer::dget [lindex [ov_gs $key] 0] hilight_wave {}]] \
        {{{v(a):2 v(a):2:1+40 v(b):2}} 0 {}}
    ov_key $key <Control-Key-r>
    check "OV16 Ctrl-R with nothing kept: the later version goes all the same, and the highlight and the bold mark follow v(b)" \
        [list [ov_shows $key] [ov_marks [ov_gs $key]] [pcall wviewer::wave_hilights $key] [wviewer::dget [lindex [ov_gs $key] 0] hilight_wave {}]] \
        [list {{v(a):2 v(b):2}} [list [list {v(a) {} {} {} {}} {v(b) {} {} {} {}}]] {{0 1 1}} 1]
    check "OV16 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

## --- the rows of the review (issue 1780, "The review") ------------------------
## the saved result named `name` of session `key`: its results file
proc ov_saved_raw {key name} {
    foreach e [pcall ase::saved_list $key] {
        if {[ase::state_get [ase::saved_meta [dict get $e dir]] name] eq $name} {
            return [file join [dict get $e dir] [file tail $::ov_raw]]
        }
    }
    return {}
}
## the dialog's select of a row: the kind is saved, lastrun, path or loaded
proc ov_select {key path type kind} {
    pcall ase::ui::rsel_arm $key $path $type $kind
    set r [pcall ase::ui::rsel_commit $key]
    update
    return $r
}
## does the dialog's status carry the sentence that the waveforms stayed, and which
proc ov_status_how {key} {
    set st $::ase::ui::dlg($key,rselstatus)
    foreach how {all keys reload} {
        if {[string first [ase::ui::lbl_rsel_plots_kept $how] $st] >= 0} { return $how }
    }
    return none
}
## the file the viewer's context has current, and its analysis
proc ov_cur {key} {
    if {[catch {
        xschem new_schematic switch [ov_drw $key]
        set r [list [file tail [xschem raw rawfile]] [xschem raw sim_type]]
    } e]} { return ERR:$e }
    return $r
}
## a results file that holds a transient and an AC analysis, as a run of a bench
## with both writes it. v(b)'s first transient point is amp
proc ov_both {path amp} {
    ov_tran $path 10e-9 $amp
    set f [open $path a]
    fconfigure $f -translation binary
    set np 21
    puts -nonewline $f "Title: ov fixture\nDate: Thu Nov 26 00:00:00  2026\nPlotname: AC Analysis\nFlags: complex\nNo. Variables: 3\nNo. Points: $np\nVariables:\n\t0\tfrequency\tfrequency\n\t1\tv(a)\tvoltage\n\t2\tv(b)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set fr [expr {pow(10.0, 6.0 * $i / ($np - 1.0))}]
        set m [expr {$amp / (1.0 + $i)}]
        puts -nonewline $f [binary format q6 [list $fr 0.0 $m 0.0 [expr {2 * $m}] 0.0]]
    }
    close $f
}

group OV18 {
    ## D1/U2/D6: back and forth between a saved result and the last run
    set key [ov_session ov18 tbov18 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Control-Key-r>
    ov_select $key $sraw tran saved
    ov_key $key <Alt-Shift-Key-P>
    check "OV18 fixture: the viewer on run 2, the saved run 1 selected and overlaid" \
        [list [ov_shows $key] [ov_status_how $key]] {{{v(b):2 v(b):1:1+40} {v(a):2 v(a):1:1+40}} all}
    set r [ov_select $key $::ov_raw tran lastrun]
    check "OV18 the last run selected again: the first traces show it, so their pins come off; the dialog does not say the waveforms stayed, for every waveform has a trace on that result" \
        [list $r [ov_shows $key] [lindex [ov_legend $key 0] 0] [lindex [ov_legend $key 0] 1] [ov_status_how $key]] \
        {1 {{v(b):2 v(b):1:1+40} {v(a):2 v(a):1:1+40}} v(b) v(b)@gold none}
    set lay0 [wviewer::layout_for $key]
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV18 Alt-Shift-P then adds nothing (it used to add the last run a second time): the model is what it was, nothing is logged, and the window says the result in view is shown" \
        [list [expr {[wviewer::layout_for $key] eq $lay0}] $::ov_logged [ov_notice $key]] \
        [list 1 {} [list {Every waveform in this window already shows the result in view (tbov18_ase.raw (tran)).} {There is nothing else to overlay.}]]
    ov_notice_close $key
    ov_select $key $sraw tran saved
    ov_key $key <Alt-Shift-Key-P>
    check "OV18 the saved result again, and the key: still two versions of each, and the window names the saved result" \
        [list [ov_shows $key] [ov_status_how $key] [lindex [ov_notice $key] 0]] \
        [list {{v(b):2 v(b):1:1+40} {v(a):2 v(a):1:1+40}} none {Every waveform in this window already shows the result in view (gold (tran)).}]
    ov_notice_close $key
    ## five more round trips: the databases in memory do not pile up
    set n0 [ov_ndbs $key]
    for {set i 0} {$i < 5} {incr i} {
        ov_select $key $::ov_raw tran lastrun
        ov_select $key $sraw tran saved
    }
    check "OV18 five more round trips: the databases in memory do not grow, the selected result is current and the waveforms show what they showed" \
        [list [expr {[ov_ndbs $key] <= $n0}] [ov_cur $key] [ov_shows $key]] \
        [list 1 [list [file tail $sraw] tran] {{v(b):2 v(b):1:1+40} {v(a):2 v(a):1:1+40}}]
    ## what the undo history is pinned to stays loaded for `u`; with no history
    ## nothing is left but the result in view and the copy the first traces are kept on
    pcall wviewer::clear_history $key
    ov_select $key $::ov_raw tran lastrun
    ov_select $key $sraw tran saved
    check "OV18 ...and with no undo history a round trip leaves two databases: the selected result and the run the first traces are kept on" \
        [list [ov_ndbs $key] [ov_shows $key]] {2 {{v(b):2 v(b):1:1+40} {v(a):2 v(a):1:1+40}}}
    check "OV18 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV19 {
    ## D2: a file picked by path in the dialog
    set key [ov_session ov19 tbov19 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    set other [file join $::scratch ov19_other.raw]
    ov_tran $other 10e-9 5.0
    set r [ov_select $key $other tran path]
    check "OV19 a file picked by path in Results > Select: the waveform stays, and the dialog names the two keys that reach that file, not the plot button (which plots the session's own result)" \
        [list $r [ov_shows $key] [ov_status_how $key] [ov_cur $key]] [list 1 v(a):1 keys {ov19_other.raw tran}]
    check "OV19 ...and that file is what the viewer's keys read" [pcall ase::ui::reload_source $key] [list $other tran {}]
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV19 Alt-Shift-P draws it beside the waveform" \
        [list [ov_shows $key] [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}]] \
        [list {{v(a):1 v(a):5:1+40}} [list {wviewer: overlaid ov19_other.raw (tran): 1 trace added beside the earlier version. Ctrl-R goes back to one version of each.}]]
    ov_key $key <Control-Key-r>
    check "OV19 Ctrl-R brings the waveform to it" [ov_shows $key] v(a):5
    ## the next launch puts the session's own run in view again
    pcall ase::result_view_reset $key
    check "OV19 a new run of the session: its own result is what the keys read again" \
        [pcall ase::ui::reload_source $key] [list $::ov_raw tran {}]
    check "OV19 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV20 {
    ## D5/P3/U5: a bench with AC and transient; the waveforms are AC, ASE-L plots the transient
    set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 points 10 start 1 stop 1e6} {type tran enabled 1 stop 10n step 100p}}
    set key [ov_session ov20 tbov20 {} {} $an]
    ov_both $::ov_raw 1.0
    pcall wviewer::open $key
    ov_ready $key
    check "OV20 fixture: the result's file holds a transient and an AC analysis, ASE-L plots the transient, and the viewer shows v(b) of the AC analysis" \
        [list [lindex [pcall ase::ui::reload_source $key] 1] [pcall wviewer::attach_raw $key $::ov_raw ac] \
              [pcall wviewer::add_trace $key 0 v(b)] [lindex [ov_cur $key] 1]] {tran 1 {} ac}
    update
    set v1 [ov_val_of_tr $key [lindex [dict get [lindex [ov_gs $key] 0] traces] 0] v(b)]
    file stat $::ov_raw a0
    ov_both $::ov_raw 3.0
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-P>
    set trs [dict get [lindex [ov_gs $key] 0] traces]
    check "OV20 the bench run again, Alt-Shift-P: the new run's AC analysis is drawn beside the AC waveform (the key used to refuse, saying the result held the transient)" \
        [list [llength $trs] [expr {[ov_val_of_tr $key [lindex $trs 0] v(b)] eq $v1}] \
              [expr {[ov_val_of_tr $key [lindex $trs 1] v(b)] ne $v1}] [wviewer::dget [lindex $trs 1] shade {}] [lindex [ov_cur $key] 1] \
              [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}] [ov_notice $key]] \
        [list 2 1 1 +40 ac [list {wviewer: overlaid tbov20_ase.raw (ac): 1 trace added beside the earlier version. Ctrl-R goes back to one version of each.}] {}]
    ## P3/D5: the dialog makes the transient of that file current; the waveforms are AC
    set r [ov_select $key $::ov_raw tran lastrun]
    check "OV20 Results > Select of the transient row of that file: the AC waveforms stay, and the dialog says they are of another analysis and names Ctrl-R alone" \
        [list $r [llength [dict get [lindex [ov_gs $key] 0] traces]] [ov_status_how $key] [lindex [ov_cur $key] 1]] {1 2 reload tran}
    set lay0 [wviewer::layout_for $key]
    ov_key $key <Alt-Shift-Key-P>
    check "OV20 ...and Alt-Shift-P judges by the waveforms: they are AC, the file's AC analysis is what they show, so nothing is added and no sentence about hertz and seconds is said" \
        [list [llength [dict get [lindex [ov_gs $key] 0] traces]] [pcall wviewer::held_traces $key] \
              [expr {[lsearch -glob $::ov_said {*do not share an X axis*}] >= 0}] [ov_notice $key]] {2 1 0 {}}
    ## the AC row of the last run chosen in the dialog, then a new run
    ov_select $key $::ov_raw ac lastrun
    set a [pcall ase::ui::reload_source $key]
    pcall ase::result_view_reset $key
    check "OV20 the AC row of the last run chosen in the dialog is what the keys read; a new run puts the analysis the session plots back" \
        [list $a [pcall ase::ui::reload_source $key]] [list [list $::ov_raw ac {}] [list $::ov_raw tran {}]]
    check "OV20 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## U1: a saved transient under a session that plots its AC analysis now
    set key [ov_session ov20b tbov20b {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    set st [ase::session_state $key]
    dict set st analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 points 10 start 1 stop 1e6} {type tran enabled 0 stop 10n step 100p}}
    pcall ase::session_update $key $st
    ov_ac $::ov_raw
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    check "OV20 fixture: the session plots its AC analysis now, the viewer shows it, and a transient of an earlier day is saved as gold" \
        [list [pcall ase::plot_sim_type [ase::session_state $key]] [lindex [ov_cur $key] 1] [file isfile $sraw]] {ac ac 1}
    set r [ov_select $key $sraw tran saved]
    check "OV20 the saved transient selected: the AC waveform stays and the dialog names Ctrl-R alone" \
        [list $r [ov_status_how $key] [pcall ase::ui::reload_source $key]] [list 1 reload [list $sraw tran {}]]
    set ::ov_said {}
    ov_key $key <Control-Key-r>
    check "OV20 Ctrl-R brings the waveform to the saved transient, read as the transient it holds (it used to say nothing was read as its ac analysis)" \
        [list [lindex [ov_cur $key] 1] [ov_shows $key] [lsearch -all -inline -glob $::ov_said {wviewer: *reload*}]] \
        [list tran v(a):1 [list {wviewer: reloaded gold (tran) (1 trace kept on an earlier run shows it again)}]]
    check "OV20 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV21 {
    ## D8/P4/U6: a later version left alone; D7: a pasted version; D3: a run of another analysis
    set key [ov_session ov21 tbov21 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Alt-Shift-Key-P>
    ## the first trace of the top strip is deleted by hand
    pcall wviewer::delete_items {} {{0 0}} {} $key
    update
    check "OV21 fixture: the first trace of v(b) deleted by hand: its later version stands alone, in its shade" \
        [list [ov_shows $key] [ov_color_prop [lindex [ov_gs $key] 0]]] {{v(b):2:1+40 {v(a):1 v(a):2:1+40}} 5+40}
    ov_key $key <Control-Key-r>
    set layer [dict get [lindex [dict get [lindex [ov_gs $key] 0] traces] 0] color]
    set cols [ov_colors $key]
    check "OV21 Ctrl-R: that trace is an ordinary one again: no mark, the layer alone on the strip, the layer's own colour on the screen and no shade" \
        [list [ov_marks [ov_gs $key]] [ov_color_prop [lindex [ov_gs $key] 0]] [ov_has $cols [ov_layer_col $layer]] \
              [ov_has $cols [pcall xschem get graph_shade_color $layer 40]]] \
        [list [list [list {v(b) {} {} {} {}}] [list {v(a) {} {} {} {}}]] 5 1 0]
    check "OV21 ...and a saved state holds no mark of it" \
        [ov_marks [wviewer::dget [pcall wviewer::snapshot $key {}] graphs {}]] [list [list {v(b) {} {} {} {}}] [list {v(a) {} {} {} {}}]]
    ## D7: a later version copied and pasted is a trace of its own
    ov_rerun 3.0 14
    ov_key $key <Alt-Shift-Key-P>
    pcall wviewer::with_edit $key [list xschem setprop -fast rect 2 0 hilight_wave 1]
    set c [pcall wviewer::copy_traces $key]
    set p [pcall wviewer::paste_traces $key]
    update
    set pasted {}
    foreach G [ov_gs $key] {
        foreach t [dict get $G traces] { lappend pasted [list [dict get $t vec] [wviewer::dget $t ovl {}] [wviewer::dget $t ogen {}] [wviewer::dget $t shade {}] [expr {[dict exists $t rawfile]}]] }
    }
    check "OV21 a later version copied and pasted: the copy carries no family, no version number and no shade" \
        [list [expr {$c > 0}] [expr {$p > 0}] [lsearch -all -inline -exact $pasted {v(b) {} {} {} 0}]] {1 1 {{v(b) {} {} {} 0}}}
    check "OV21 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## D3: Auto Plot on; a version; then a finished run of another analysis
    set key [ov_session ov21b tbov21b {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    ov_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    ov_key $key <Alt-Shift-Key-P>
    check "OV21 fixture: Auto Plot on; the hand trace has two versions, on runs 1 and 2" [lindex [ov_shows $key] 0] {v(b):1 v(b):2:1+40}
    set st [ase::session_state $key]
    dict set st analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 points 10 start 1 stop 1e6} {type tran enabled 0 stop 10n step 100p}}
    pcall ase::session_update $key $st
    file stat $::ov_raw a0
    ov_ac $::ov_raw
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    pcall ase::ui::auto_plot_idle $key
    update
    set vb {}
    foreach G [ov_gs $key] { foreach t [dict get $G traces] { if {[dict get $t vec] eq {v(b)}} { lappend vb [list [wviewer::dget $t ogen {}] [wviewer::dget $t shade {}] [dict exists $t rawfile]] } } }
    check "OV21 a finished run of another analysis: every trace follows it, so the two versions of the hand trace would be one curve drawn twice: the later one goes, the first stays with no mark" \
        [list [lindex [ov_cur $key] 1] $vb [pcall wviewer::held_traces $key]] {ac {{{} {} 0}} 0}
    check "OV21 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV22 {
    ## D4: a load made by another door leaves the versions on their data
    set key [ov_session ov22 tbov22 {} 1.0 {} 1]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7 1
    ov_key $key <Alt-Shift-Key-P>
    ## a net plotted after the overlay has one version, on run 2
    pcall ase::ui::dp_finish $key {v(a)}
    update
    ov_rerun 3.0 14 1
    ## another run, and a net picked in the schematic reads it
    pcall ase::ui::dp_finish $key {v(c)}
    update
    proc ov_by {key} {
        set by [dict create]
        foreach G [ov_gs $key] { foreach t [dict get $G traces] { dict lappend by [dict get $t vec] "[ov_run_of_tr $key $t][expr {[wviewer::dget $t ogen {}] ne {} ? ":[dict get $t ogen]" : {}}]" } }
        return $by
    }
    set by [ov_by $key]
    check "OV22 v(b) has two versions (runs 1 and 2), v(a) one; another run; a net picked in the schematic reads run 3: the versions stay on runs 1 and 2 (the one that followed the result used to move to run 3, and run 2 was gone), the waveform with one version follows the load as it always did" \
        [list [dict get $by v(b)] [dict get $by v(a)] [dict get $by v(c)] [pcall wviewer::held_traces $key]] {{1 2:1} 3 3 2}
    ov_key $key <Alt-Shift-Key-P>
    set by [ov_by $key]
    check "OV22 ...and Alt-Shift-P then adds run 3 as the third version; the nets that read run 3 already get none" \
        [list [dict get $by v(b)] [dict get $by v(a)] [dict get $by v(c)]] {{1 2:1 3:2} 3 3}
    ## a read that fails at that door: the versions are as they were
    ov_rerun 4.0 21 1
    ov_key $key <Alt-Shift-Key-P>
    file stat $::ov_raw a0
    ov_ac $::ov_raw
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    set before [ov_by $key]
    set held0 [pcall wviewer::held_traces $key]
    set nd [ov_ndbs $key]
    pcall wviewer::attach_raw $key $::ov_raw tran
    update
    check "OV22 a load by that door that reads nothing: the versions, their pins and the data in memory are what they were" \
        [list [expr {[ov_by $key] eq $before}] [expr {[pcall wviewer::held_traces $key] == $held0}] [expr {[ov_ndbs $key] == $nd}]] {1 1 1}
    ## and the door still keeps the versions the next time it reads
    ov_tran $::ov_raw 10e-9 5.0 41 1
    file mtime $::ov_raw [expr {$a0(mtime) + 14}]
    pcall wviewer::attach_raw $key $::ov_raw tran
    update
    set by [ov_by $key]
    check "OV22 ...and the next load by that door keeps them again: every waveform has versions by now, and none of them moved to run 5" \
        [list [dict get $by v(b)] [dict get $by v(a)] [dict get $by v(c)]] {{1 2:1 3:2 4:3} {3 4:1} {3 4:1}}
    check "OV22 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV23 {
    ## D9: each kept version says when ITS data was written, a failed read in between or not
    set key [ov_session ov23 tbov23 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Alt-Shift-Key-P>
    ## the file cannot be read as a transient; Ctrl-R fails; then the next run
    file stat $::ov_raw a0
    ov_ac $::ov_raw
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    ov_key $key <Control-Key-r>
    ov_rerun 3.0 7
    ov_key $key <Alt-Shift-Key-P>
    set lg [ov_legend $key 0]
    check "OV23 a Ctrl-R that read nothing between two presses: the three versions still show runs 1, 2 and 3, and both earlier ones say the time of their own run (the second used to say @earlier)" \
        [list [ov_shows $key] [llength $lg] [regexp "^A@$::ov_when\$" [lindex $lg 0]] [regexp "^A@$::ov_when\$" [lindex $lg 1]] \
              [expr {[lindex $lg 0] ne [lindex $lg 1]}] [lindex $lg 2]] {{{v(a):1 v(a):2:1+40 v(a):3:2-35}} 3 1 1 1 A}
    ## P2: the cursor read-out and the Delete dialog name the versions as the legend does
    set names [lmap e [pcall wviewer::readout_entries [ov_gs $key]] {lindex $e 1}]
    check "OV23 the cursor read-out names each version as its legend does" $names $lg
    pcall wviewer::delete_dialog $key
    update
    set dl {}
    catch {set dl [[wviewer::window_for $key].wvdel.items get 0 end]}
    catch {destroy [wviewer::window_for $key].wvdel}
    check "OV23 ...and so do the rows of the Delete dialog" \
        [lmap r [lsearch -all -inline -glob $dl {graph 0: *}] {lindex [split [string range $r 9 end] { }] 0}] $lg
    ## D11: a failed Ctrl-R with versions: the highlight and the bold trace are where they were
    set ::wviewer::wavehl($key) {{0 2 1}}
    pcall wviewer::with_edit $key [list xschem setprop -fast rect 2 0 hilight_wave 2]
    file stat $::ov_raw a0
    ov_ac $::ov_raw
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    set before [ov_shows $key]
    ov_key $key <Control-Key-r>
    check "OV23 a Ctrl-R that reads nothing, with versions: they are all still there, the trace highlight is on its trace and the bold mark on its own" \
        [list [expr {[ov_shows $key] eq $before}] [pcall wviewer::wave_hilights $key] \
              [pcall apply {{key} { xschem new_schematic switch [ov_drw $key] ; xschem getprop rect 2 0 hilight_wave }} $key]] {1 {{0 2 1}} 2}
    check "OV23 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## D11: nothing to add but the result was read: it is logged; and the undo point
    set key [ov_session ov23b tbov23b {} 1.0 {} 1]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::dp_finish $key {v(c)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7 0
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV23 the only waveform is of a net the new result lacks: the window says nothing was overlaid and why; the result was read, so the press is logged" \
        [list [ov_notice $key] $::ov_logged [pcall wviewer::held_traces $key]] \
        [list [list {Nothing was overlaid from tbov23b_ase.raw (tran): 1 trace with no data in it left as it is.} \
                    {Ctrl-R, or the plot button (~) in ASE-L, replaces every waveform with the result.}] \
              [list [list wviewer::overlay_latest $key]] 1]
    ov_notice_close $key
    catch {wviewer::close $key}
    catch {ase::session_close $key}
    set key [ov_session ov23c tbov23c {} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    set id0 [pcall wviewer::tab_id $key]
    pcall wviewer::new_tab $key
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    set h0 [wviewer::history_depth $key]
    ov_key $key <Alt-Shift-Key-P>
    set h1 [wviewer::history_depth $key]
    pcall wviewer::select_tab $id0 $key
    update
    check "OV23 the key in an empty tab while the waveform is in the tab that is not shown: that tab gets its version, and the tab shown takes no undo point for a change it did not see" \
        [list [expr {$h1 eq $h0}] [ov_shows $key]] {1 {{v(b):1 v(b):2:1+40}}}
    check "OV23 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## D9: a file loaded beside the result keeps its own time, not the result's
    set key [ov_session ov23e tbov23e {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    set side [file join $::scratch ov23e_side.raw]
    ov_tran $side 10e-9 9.0
    set sidx {}
    catch {
        xschem new_schematic switch [ov_drw $key]
        xschem raw read $side tran
        set sidx [dict get [wviewer::loaded_dbs] [list $side tran]]
        xschem raw switch $::ov_raw tran
    }
    pcall wviewer::add_graph $key
    set e [pcall wviewer::add_trace $key [expr {[llength [ov_gs $key]] - 1}] v(b) {} {} $sidx]
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Alt-Shift-Key-P>
    set lgA {}
    set lgS {}
    set gi 0
    foreach G [ov_gs $key] {
        foreach t [dict get $G traces] {
            if {[dict get $t vec] eq {v(a)}} { set lgA [ov_legend $key $gi] }
            if {[dict get $t vec] eq {v(b)}} { set lgS [ov_legend $key $gi] }
        }
        incr gi
    }
    check "OV23 a trace of a file loaded beside the result: the result's own waveform gets its version and its earlier trace says the run's time; the other file's trace, of whose data the window noted nothing, says `@earlier` and never the result's time" \
        [list $e [llength $lgA] [regexp "^A@$::ov_when\$" [lindex $lgA 0]] $lgS] {{} 2 1 v(b)@earlier}
    check "OV23 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## D10: the scripting door notes a file only when the engine read it
    set tok [ov_session ov23d tbov23d {} {}]
    set f [file join $::scratch ov23d.raw]
    ov_tran $f 10e-9 1.0
    pcall wviewer::open $tok
    ov_ready $tok
    pcall wviewer::display_raw $tok $f tran v(b)
    update
    file stat $f a0
    ov_tran $f 10e-9 4.0
    file mtime $f [expr {$a0(mtime) + 7}]
    pcall wviewer::display_raw $tok $f tran v(a)
    update
    ov_key $tok <Alt-Shift-Key-P>
    check "OV23 that door called again after the file was written: the engine switched to the copy in memory, so the key still knows the file is newer and draws it beside both traces" \
        [list [ov_shows $tok] [ov_notice $tok]] {{{v(b):1 v(a):1 v(b):4:1+40 v(a):4:1+40}} {}}
    check "OV23 no background error" $::ov_bg {}
    catch {wviewer::close $tok}
    catch {ase::session_close $tok}
}

group OV24 {
    ## P1: a colour with no room towards white or black
    set white -1
    set black -1
    for {set l 4} {$l < [llength $tctx::colors]} {incr l} {
        if {$white < 0 && [ov_layer_col $l] eq {#ffffff}} { set white $l }
        if {$black < 0 && [ov_layer_col $l] eq {#000000}} { set black $l }
    }
    if {$white >= 0} {
        set sh [lmap p {40 -35 65 -60} {pcall xschem get graph_shade_color $white $p}]
        check "OV24 a white layer: its four shades are four colours and none is white (a shade towards white used to be the trace's own colour)" \
            [list [llength [lsort -unique $sh]] [expr {{#ffffff} in $sh}] [join $sh ,]] {4 0 #cccccc,#a6a6a6,#8c8c8c,#666666}
    } else {
        puts "skip: OV24 the colour scheme has no white layer among the trace layers"
    }
    ## a black layer: no shipped scheme has one among the trace layers, so the
    ## suite makes layer 9 black for the row and puts its colour back
    set c0 $tctx::colors
    set d0 $::dark_colors
    set l0 $::light_colors
    set got {}
    if {[catch {
        lset ::dark_colors 9 #000000
        lset ::light_colors 9 #000000
        xschem build_colors
        set own [pcall xschem get graph_shade_color 9 0]
        set sh [lmap p {40 -35 65 -60} {pcall xschem get graph_shade_color 9 $p}]
        set got "$own [llength [lsort -unique $sh]] [expr {{#000000} in $sh}] [join $sh ,]"
    } e]} { set got ERR:$e }
    set ::dark_colors $d0
    set ::light_colors $l0
    set tctx::colors $c0
    catch {xschem build_colors}
    check "OV24 a black layer: its four shades are four colours and none is black (the fourth used to be the first one's grey)" \
        $got "#000000 4 0 #666666,#8c8c8c,#a6a6a6,#cccccc"
    check "OV24 ...and the layer has its own colour back" [pcall xschem get graph_shade_color 9 0] [ov_layer_col 9]
    check "OV24 a shade past 95 is held to 95, and a colour with room keeps its side" \
        [list [expr {[pcall xschem get graph_shade_color 5 400] eq [pcall xschem get graph_shade_color 5 95]}] \
              [expr {[pcall xschem get graph_shade_color 5 40] ne [pcall xschem get graph_shade_color 5 -40]}]] {1 1}
}

group OV25 {
    ## U3: the small window blames Auto Plot only when a finished run's plot is why
    set key [ov_session ov25 tbov25 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    ov_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    ov_key $key <Alt-Shift-Key-P>
    check "OV25 Auto Plot on, a finished run plotted: the window blames the option" \
        [regexp {^ASE-L plotted it when the simulation finished: Results > Auto Plot Outputs After Simulation is ticked} [lindex [ov_notice $key] 1]] 1
    ov_notice_close $key
    pcall ase::ui::set_plot_after_sim $key 0
    ov_key $key <Alt-Shift-Key-P>
    check "OV25 the option unticked since: the window does not say it is ticked" \
        [lindex [ov_notice $key] 1] {There is nothing newer to overlay.}
    ov_notice_close $key
    pcall ase::ui::set_plot_after_sim $key 1
    ov_key $key <Control-Key-r>
    ov_key $key <Alt-Shift-Key-P>
    check "OV25 the same, after a Ctrl-R: the reload is why the waveforms are on the latest result, and the window blames nothing" \
        [ov_notice $key] [list {Every waveform in this window already shows the latest result (tbov25_ase.raw (tran)).} {There is nothing newer to overlay.}]
    ov_notice_close $key
    ov_select $key $sraw tran saved
    pcall ase::ui::plot_outputs $key
    update
    ov_key $key <Alt-Shift-Key-P>
    check "OV25 a saved result selected and plotted with the plot button, Auto Plot still on: the window calls it the result in view, not the latest, and blames nothing" \
        [list [ov_shows $key] [ov_notice $key]] \
        [list v(a):1 [list {Every waveform in this window already shows the result in view (gold (tran)).} {There is nothing else to overlay.}]]
    ## U4: the keyboard. The window is up; the keys it recommends work on it
    set w [wviewer::window_for $key].wvnotice
    ov_rerun 3.0 14
    pcall ase::result_view_reset $key
    set ::ov_said {}
    event generate $w <Control-Key-r>
    update
    check "OV25 Ctrl-R typed while the small window has the keyboard: the window closes and the viewer reloads" \
        [list [winfo exists $w] [ov_shows $key] [llength [lsearch -all -glob $::ov_said {wviewer: reloaded*}]]] {0 v(a):3 1}
    ov_key $key <Alt-Shift-Key-P>
    set w [wviewer::window_for $key].wvnotice
    ## (whether the window manager hands the new window the keyboard is its
    ## own choice: openbox does. The rows type on the window for that case.)
    ov_rerun 4.0 21
    event generate $w <Alt-Shift-Key-P>
    update
    check "OV25 Alt-Shift-P typed on the window: it closes and the viewer overlays" \
        [list [winfo exists $w] [ov_shows $key]] {0 {{v(a):3 v(a):4:1+40}}}
    ov_key $key <Alt-Shift-Key-P>
    set w [wviewer::window_for $key].wvnotice
    event generate $w <Key-Shift_L>
    update
    set up [winfo exists $w]
    event generate $w <Key-a>
    update
    check "OV25 a modifier alone leaves the window up; any other key closes it and the keyboard is the viewer's" \
        [list $up [winfo exists $w] [expr {[focus] eq [ov_drw $key]}]] {1 0 1}
    ## Tab typed on the window: Tk's own Tab binding must not run on a window that is gone
    ov_key $key <Alt-Shift-Key-P>
    set w [wviewer::window_for $key].wvnotice
    set bg0 [llength $::ov_bg]
    event generate $w <Key-Tab>
    update
    check "OV25 Tab typed on the small window closes it like any other key, with no background error" \
        [list [winfo exists $w] [expr {[llength $::ov_bg] - $bg0}]] {0 0}
    ## the window of one press does not outlive the next
    ov_key $key <Alt-Shift-Key-P>
    set up [winfo exists [wviewer::window_for $key].wvnotice]
    ov_rerun 5.0 28
    ov_key $key <Alt-Shift-Key-P>
    check "OV25 the window is up; another run, the key on the viewer: the versions are added and the window of the press before is gone" \
        [list $up [winfo exists [wviewer::window_for $key].wvnotice] [ov_shows $key]] {1 0 {{v(a):3 v(a):4:1+40 v(a):5:2-35}}}
    check "OV25 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## U8: a select plots nothing, a trace that had no data included
    set key [ov_session ov25b tbov25b {{name A expr v(a) save 1 plot 1}} 1.0 {} 1]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(c)}
    update
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7 0
    ov_key $key <Control-Key-r>
    set tc {}
    foreach G [ov_gs $key] { foreach t [dict get $G traces] { if {[dict get $t vec] eq {v(c)}} { set tc $t } } }
    check "OV25 fixture: the latest run lacks v(c), so its trace draws nothing; the saved result holds it" \
        [ov_val_of_tr $key $tc v(c)] NOVEC
    ov_select $key $sraw tran saved
    set tc {}
    foreach G [ov_gs $key] { foreach t [dict get $G traces] { if {[dict get $t vec] eq {v(c)}} { set tc $t } } }
    check "OV25 the saved result selected: that trace still draws nothing (it used to be drawn from the saved result at once, under a sentence that said nothing moved)" \
        [list [ov_val_of_tr $key $tc v(c)] [wviewer::trace_held $tc] [ov_status_how $key]] {NOVEC 1 all}
    check "OV25 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

## --- the rows of the second review --------------------------------------------
## a session with row A and a net by hand, both plotted from run 1 (amplitude 1)
proc ov_two {sub cell {an {}} {extra 0}} {
    set key [ov_session $sub $cell {{name A expr v(a) save 1 plot 1}} 1.0 $an $extra]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    return $key
}

group OV26 {
    ## R2: `u` after a select round trip brings a trace back on the data it showed
    set key [ov_two ov26 tbov26]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Control-Key-r>
    ov_select $key $sraw tran saved
    ## an edit while the waveforms are kept on run 2: the hand trace is deleted
    pcall wviewer::delete_items {} {{0 0}} {} $key
    update
    ov_select $key $::ov_raw tran lastrun
    ov_select $key $sraw tran saved
    ov_key $key <Key-u>
    check "OV26 the waveforms kept on run 2 by a select, one of them deleted, the last run and the saved result selected again, then u: the trace comes back on run 2, kept, with its time (the copy it was kept on had been unloaded and kept again under another name, and the trace came back on the saved result)" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] [regexp "^v\\(b\\)@$::ov_when\$" [lindex [ov_legend $key 0] 0]]] \
        {{v(b):2 v(a):2} 2 1}
    ## R4: the dialog's Loaded list holds no row for a kept copy
    set rows [pcall ase::ui::rsel_rows $key]
    set lab [lmap r [ase::state_get $rows loaded] {ase::state_get $r label}]
    set pth [lmap r [ase::state_get $rows loaded] {ase::state_get $r path}]
    check "OV26 the dialog's Loaded list offers the selected result and no row for the copy the waveforms are kept on (a row that named no file)" \
        [list [expr {[llength $lab] >= 1}] [llength [lsearch -all -glob $pth *@held*]] [expr {[ov_ndbs $key] > [llength $lab]}]] {1 0 1}
    check "OV26 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## X4: a kept trace deleted by hand, selects, then u
    set key [ov_two ov26b tbov26b]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    ov_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    pcall wviewer::delete_items {} {{0 0}} {} $key
    update
    ov_select $key $sraw tran saved
    ov_select $key $::ov_raw tran lastrun
    ov_key $key <Key-u>
    check "OV26 a hand trace kept on run 1 by a finished run, deleted, a select and back, then u: the trace is back on run 1, kept (the select used to unload the copy it was kept on)" \
        [list [lindex [ov_shows $key] 0] [regexp "^v\\(b\\)@$::ov_when\$" [lindex [ov_legend $key 0] 0]]] {v(b):1 1}
    check "OV26 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## X1: the Signal Browser reads its databases again after the keep
    set key [ov_two ov26c tbov26c]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Control-Key-r>
    set ::ov_br {}
    rename ::wviewer::browser_refresh ::wviewer::ov_br_orig
    proc ::wviewer::browser_refresh {token {reload 0}} {
        set names {}
        catch { foreach d [dict get [wviewer::rawinfo_parse [xschem raw info]] dbs] { lappend names [file tail [dict get $d path]] } }
        lappend ::ov_br [list $reload $names]
        return [::wviewer::ov_br_orig $token $reload]
    }
    ov_select $key $sraw tran saved
    set first [lindex $::ov_br end]
    set ::ov_br {}
    ov_select $key $::ov_raw tran lastrun
    set second [lindex $::ov_br end]
    rename ::wviewer::browser_refresh {}
    rename ::wviewer::ov_br_orig ::wviewer::browser_refresh
    check "OV26 a select that kept the waveforms: the Signal Browser reads its databases again AFTER the kept copy got its name; the select back, which unloads that copy: again after it went" \
        [list [lindex $first 0] [llength [lsearch -all -glob [lindex $first 1] *@held*]] \
              [lindex $second 0] [llength [lsearch -all -glob [lindex $second 1] *@held*]] [llength [lindex $second 1]]] {1 1 1 0 2}
    ## R3/X7: the viewer's own Location bar loads its file into the plots, after a select too
    ov_select $key $sraw tran saved
    set other [file join $::scratch ov26_other.raw]
    ov_tran $other 10e-9 5.0
    set held0 [pcall wviewer::held_traces $key]
    set bad [file join $::scratch ov26_not_a_raw.txt]
    set f [open $bad w] ; puts $f "not a results file" ; close $f
    set r0 [pcall wviewer::rawbar_load $key $bad]
    check "OV26 after a select the waveforms are kept on run 2; a file the engine cannot read, typed into the viewer's Location bar: they stay kept on it" \
        [list $held0 $r0 [ov_shows $key] [pcall wviewer::held_traces $key]] {2 0 {v(b):2 v(a):2} 2}
    set r1 [pcall wviewer::rawbar_load $key $other]
    update
    check "OV26 a results file typed there is loaded into the plots: every waveform shows it and nothing is kept (after a select it used to move no waveform)" \
        [list $r1 [ov_shows $key] [pcall wviewer::held_traces $key] [lindex [ov_legend $key 0] 0]] {1 {v(b):5 v(a):5} 0 v(b)}
    check "OV26 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV27 {
    ## R5: Ctrl-R reads the analysis the waveforms show, as the key does
    set an {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 points 10 start 1 stop 1e6} {type tran enabled 1 stop 10n step 100p}}
    set key [ov_session ov27 tbov27 {{name A expr v(a) save 1 plot 1}} {} $an]
    ov_both $::ov_raw 1.0
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::attach_raw $key $::ov_raw ac
    pcall wviewer::add_trace $key 0 v(b)
    update
    file stat $::ov_raw a0
    ov_both $::ov_raw 3.0
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    ov_key $key <Alt-Shift-Key-P>
    set ::ov_said {}
    ov_key $key <Control-Key-r>
    check "OV27 an AC waveform with a later version from the new run, under a session that plots its transient: Ctrl-R goes back to one AC trace on the new run (it used to put the transient on that strip)" \
        [list [lindex [ov_cur $key] 1] [llength [dict get [lindex [ov_gs $key] 0] traces]] \
              [lsearch -all -inline -glob $::ov_said {wviewer: reloaded*}]] \
        [list ac 1 [list {wviewer: reloaded tbov27_ase.raw (ac) (1 trace kept on an earlier run shows it again) (1 later version of a waveform taken out)}]]
    ## X5: the row the dialog chose is what all three gestures read
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    check "OV27 fixture: the plot button plots the session's transient" [list [lindex [ov_cur $key] 1] [ov_shows $key]] {tran v(a):3}
    set va_t [ov_val_of_tr $key [lindex [dict get [lindex [ov_gs $key] 0] traces] 0] v(b)]
    ov_select $key $::ov_raw ac lastrun
    pcall ase::ui::plot_outputs $key
    update
    set va_a [ov_val_of_tr $key [lindex [dict get [lindex [ov_gs $key] 0] traces] 0] v(b)]
    check "OV27 the AC row of the last run chosen in the dialog, then the plot button: it plots that row's analysis" \
        [list [lindex [ov_cur $key] 1] [pcall wviewer::held_traces $key] [expr {$va_a ne $va_t}]] {ac 0 1}
    ov_key $key <Alt-Shift-Key-P>
    set n [lindex [ov_notice $key] 0]
    ov_notice_close $key
    set ::ov_said {}
    ov_key $key <Control-Key-r>
    check "OV27 ...and the key and Ctrl-R agree with it: the window says the AC analysis is shown, and Ctrl-R reads it again (the key used to say the transient was shown, and Ctrl-R then turned every waveform to AC)" \
        [list $n [lindex [ov_cur $key] 1] [lsearch -all -inline -glob $::ov_said {wviewer: reloaded*}]] \
        [list {Every waveform in this window already shows the result in view (tbov27_ase.raw (ac)).} ac [list {wviewer: reloaded tbov27_ase.raw (ac)}]]
    ## ...and Ctrl-R alone, while the waveforms still show the transient of a
    ## file that holds both analyses: the row the dialog chose rules
    pcall ase::result_view_reset $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    ov_select $key $::ov_raw ac lastrun
    set was [list [pcall wviewer::held_traces $key]]
    set ::ov_said {}
    ov_key $key <Control-Key-r>
    check "OV27 the AC row chosen while the waveform is kept on the transient: Ctrl-R reads the row the dialog chose, not the analysis shown" \
        [list [lindex $was 0] [lindex [ov_cur $key] 1] [pcall wviewer::held_traces $key] \
              [llength [lsearch -all -glob $::ov_said {wviewer: reloaded tbov27_ase.raw (ac)*}]]] {1 ac 0 1}
    ## R6: a window that shows two analyses
    pcall ase::result_view_reset $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    ov_select $key $::ov_raw ac lastrun
    pcall wviewer::add_graph $key
    pcall wviewer::add_trace $key [expr {[llength [ov_gs $key]] - 1}] v(b)
    update
    set ::ov_logged {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV27 a window with a waveform kept on the transient and one that follows the AC analysis in view, nothing new: the window says nothing was overlaid and that one trace is of another analysis; nothing is logged" \
        [list [ov_notice $key] $::ov_logged] \
        [list [list {Nothing was overlaid from tbov27_ase.raw (ac): 1 trace of another analysis left as it is.} \
                    {Ctrl-R, or the plot button (~) in ASE-L, replaces every waveform with the result.}] {}]
    ov_notice_close $key
    file stat $::ov_raw a0
    ov_both $::ov_raw 5.0
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV27 the bench run again: the AC waveform gets its version, the transient one is left, and the sentence counts it" \
        [lsearch -all -inline -glob $::ov_said {wviewer: overlaid*}] \
        [list {wviewer: overlaid tbov27_ase.raw (ac): 1 trace added beside the earlier version (1 trace of another analysis left as it is). Ctrl-R goes back to one version of each.}]
    check "OV27 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## R1: a saved transient under a session that plots its AC analysis: the plot button
    set key [ov_session ov27b tbov27b {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    set st [ase::session_state $key]
    dict set st analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 points 10 start 1 stop 1e6} {type tran enabled 0 stop 10n step 100p}}
    pcall ase::session_update $key $st
    ov_ac $::ov_raw
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    ov_select $key $sraw tran saved
    ov_key $key <Alt-Shift-Key-P>
    check "OV27 an AC window, the saved transient selected, Alt-Shift-P: the window names the saved result, says it holds none of the analysis shown, and promises Ctrl-R alone" \
        [ov_notice $key] [list {The waveforms in this window are of the ac analysis, and gold (tran), which ASE-L has in view, holds none of it to draw beside them: nothing is overlaid.} \
                               {Ctrl-R replaces the waveforms with that result.}]
    ov_notice_close $key
    pcall ase::ui::plot_outputs $key
    update
    check "OV27 the plot button then plots the saved result as the transient it holds: ASE-L's row and the net plotted by hand both show it, nothing is kept, and the strips are on its ten nanoseconds (the row used to be a sliver on the AC axis beside a hand trace left on the AC run)" \
        [list [lindex [ov_cur $key] 1] [ov_shows $key] [pcall wviewer::held_traces $key] \
              [expr {[lindex [ov_x $key 0] 1] < 1e-6}] [expr {[lindex [ov_x $key 1] 1] < 1e-6}]] {tran {v(b):1 v(a):1} 0 1 1}
    check "OV27 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV28 {
    ## X3: a later version of ASE-L's row in a tab that is not shown, a hand trace beside it, a finished run under Replace
    set key [ov_two ov28 tbov28]
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Alt-Shift-Key-P>
    set id0 [pcall wviewer::tab_id $key]
    pcall wviewer::new_tab $key
    update
    pcall ase::ui::set_plot_after_sim $key 1
    ov_rerun 3.0 14
    pcall ase::ui::auto_plot_idle $key
    update
    pcall wviewer::select_tab $id0 $key
    update
    check "OV28 two versions of ASE-L's row and of a hand trace in one tab; a new tab; a finished run under Replace plots there: in the first tab every version is still on its run (the row's later version used to move to run 3 when a hand trace stood beside it)" \
        [ov_shows $key] {{v(b):1 v(b):2:1+40} {v(a):1 v(a):2:1+40}}
    check "OV28 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## X8: a Direct Plot is why the waveforms are on the latest run
    set key [ov_session ov28b tbov28b {{name A expr v(a) save 1 plot 1}} 1.0 {} 1]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    ov_rerun 2.0 7 1
    pcall ase::ui::auto_plot_idle $key
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 3.0 14 1
    pcall ase::ui::dp_finish $key {v(c)}
    update
    pcall ase::ui::set_plot_after_sim $key 1
    ov_key $key <Alt-Shift-Key-P>
    check "OV28 a run that plotted; the option off, another run that plotted nothing, a net picked in the schematic moves ASE-L's row to it; the option on again: the Direct Plot is why the waveforms are on the latest run, and the window does not blame the option" \
        [list [ov_shows $key] [lindex [ov_notice $key] 1]] {{v(c):3 v(a):3} {There is nothing newer to overlay.}}
    ov_notice_close $key
    check "OV28 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## X9: a saved copy of the run a trace is kept on is that run's data
    set key [ov_two ov28c tbov28c]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    catch {file mtime $sraw [file mtime $::ov_raw]}
    ov_rerun 2.0 7
    pcall ase::ui::auto_plot_idle $key
    update
    check "OV28 fixture: run 1 saved as gold; a finished run leaves the hand trace kept on run 1 and puts ASE-L's row on run 2" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key]] {{v(b):1 v(a):2} 1}
    ov_select $key $sraw tran saved
    ov_key $key <Alt-Shift-Key-P>
    check "OV28 the saved result selected and overlaid: the hand trace shows that very data already and gets no second curve of it; ASE-L's row, which is on run 2, gets its version" \
        [ov_shows $key] {v(b):1 {v(a):2 v(a):1:1+40}}
    check "OV28 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV29 {
    ## the last check's findings. 1: the session's analyses were changed and it
    ## ran again; Ctrl-R reads the result as the analysis ASE-L names
    set an_ac {{type op enabled 1} {type dc enabled 0} {type ac enabled 1 points 10 start 1 stop 1e6} {type tran enabled 0 stop 10n step 100p}}
    set an_tr {{type op enabled 1} {type dc enabled 0} {type ac enabled 0 points 10 start 1 stop 1e6} {type tran enabled 1 stop 10n step 100p}}
    set key [ov_session ov29 tbov29 {{name A expr v(a) save 1 plot 1}} {} $an_ac]
    ov_ac $::ov_raw
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    pcall ase::ui::dp_finish $key {v(b)}
    update
    pcall ase::ui::set_plot_after_sim $key 0
    set st [ase::session_state $key]
    dict set st analyses $an_tr
    pcall ase::session_update $key $st
    file stat $::ov_raw a0
    ov_tran $::ov_raw 10e-9 2.0
    file mtime $::ov_raw [expr {$a0(mtime) + 7}]
    pcall ase::result_view_reset $key
    check "OV29 fixture: two AC waveforms; the session now runs a transient alone and its file holds no AC analysis" \
        [list [ov_cur $key] [pcall ase::ui::reload_source $key] [pcall wviewer::held_traces $key]] \
        [list {tbov29_ase.raw ac} [list $::ov_raw tran {}] 0]
    ov_key $key <Alt-Shift-Key-P>
    check "OV29 the key: nothing of the analysis shown to draw beside the waveforms, and the window names Ctrl-R" \
        [list [ov_cur $key] [lindex [ov_notice $key] 1]] \
        {{tbov29_ase.raw ac} {Ctrl-R replaces the waveforms with that result.}}
    ov_notice_close $key
    ## as a finished run's plot leaves the window: the reload has to say that it loaded
    pcall wviewer::data_from $key run
    set ::ov_said {}
    ov_key $key <Control-Key-r>
    check "OV29 ...and Ctrl-R does: the file holds none of the analysis shown, so it is read as the analysis ASE-L names (the read used to be refused and nothing moved)" \
        [list [ov_shows $key] [ov_cur $key] [lsearch -all -inline -glob $::ov_said {wviewer: *reload*}] [pcall wviewer::held_traces $key]] \
        {{v(b):2 v(a):2} {tbov29_ase.raw tran} {{wviewer: reloaded tbov29_ase.raw (tran)}} 0}
    pcall ase::ui::set_plot_after_sim $key 1
    ov_key $key <Alt-Shift-Key-P>
    check "OV29 ...and the key after it: nothing is newer, and the window does not name the Auto Plot option, for Ctrl-R loaded and not a finished run's plot" \
        [list [pcall wviewer::data_from $key] [lindex [ov_notice $key] 1]] {reload {There is nothing newer to overlay.}}
    ov_notice_close $key
    check "OV29 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## 2: the zoom of ASE-L's strip across a finished run under Replace, when
    ## its row had versions (issue 1733's ruling)
    foreach hand {1 0} zoom {engine model} {
        set key [ov_session ov29z$hand tbov29z$hand {{name A expr v(a) save 1 plot 1}} 1.0 {} 1]
        pcall wviewer::open $key
        ov_ready $key
        pcall wviewer::set_plot_mode multi $key
        pcall wviewer::clear_all $key
        pcall ase::ui::plot_outputs $key
        if {$hand} { pcall ase::ui::dp_finish $key {v(b)} }
        update
        pcall ase::ui::set_plot_after_sim $key 0
        ov_rerun 2.0 7 1
        ov_key $key <Alt-Shift-Key-P>
        set n [llength [ov_gs $key]]
        if {$zoom eq {engine}} {
            ## a zoom made on the strip itself: it lives in the rect
            catch {
                xschem new_schematic switch [ov_drw $key]
                for {set i 0} {$i < $n} {incr i} { xschem graph_axis_zoom $i x 2e-9 5e-9 }
            }
        } else {
            ## a range the viewer wrote: it lives in the model
            for {set i 0} {$i < $n} {incr i} { pcall wviewer::apply_range $key $i 2e-9 5e-9 {} {} }
        }
        update
        set before [lmap i [lrange {0 1} 0 [expr {$n - 1}]] {ov_x $key $i}]
        ov_rerun 3.0 14 1
        pcall ase::result_view_reset $key
        pcall ase::ui::set_plot_after_sim $key 1
        pcall ase::ui::auto_plot_idle $key
        update
        set ai [expr {$n - 1}]
        check "OV29 two versions of ASE-L's row[expr {$hand ? { and of a hand trace} : {}}], every strip zoomed in X ($zoom); a finished run under Replace: the row is alone on run 3, and its strip keeps the X window (it was fitted again), with Y fitted to the new run over it" \
            [list $before [ov_shows $key] [ov_x $key $ai] [ov_y $key $ai]] \
            [list [lrepeat $n {2e-9 5e-9}] [expr {$hand ? {{v(b):1 v(b):2:1+40} v(a):3} : {v(a):3}}] {2e-9 5e-9} {0.6 1.5}]
        catch {wviewer::close $key}
        catch {ase::session_close $key}
    }
    ## ...and the ranges the viewer wrote, one per strip, with two rows: each
    ## row's strip takes back the range that was set for it
    set key [ov_session ov29m tbov29m {{name A expr v(a) save 1 plot 1} {name B expr v(b) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Alt-Shift-Key-P>
    set gi 0
    foreach G [ov_gs $key] {
        set v [dict get [lindex [dict get $G traces] 0] vec]
        pcall wviewer::apply_range $key $gi 2e-9 5e-9 0 [expr {$v eq {v(a)} ? 5 : 7}]
        incr gi
    }
    update
    ov_rerun 3.0 14
    pcall ase::result_view_reset $key
    pcall ase::ui::set_plot_after_sim $key 1
    pcall ase::ui::auto_plot_idle $key
    update
    set got {}
    set gi 0
    foreach G [ov_gs $key] {
        lappend got [list [lmap t [dict get $G traces] {dict get $t vec}] [ov_x $key $gi] [ov_y $key $gi]]
        incr gi
    }
    check "OV29 two rows with versions, an X and a Y range written on each strip; a finished run under Replace: each row is alone on run 3 and its strip has the range that was set for it" \
        [list [ov_shows $key] [lsort $got]] [list {v(b):3 v(a):3} [lsort {{v(a) {2e-9 5e-9} {0 5}} {v(b) {2e-9 5e-9} {0 7}}}]]
    check "OV29 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## ...and when the row was kept by Results > Select
    set key [ov_session ov29s tbov29s {{name A expr v(a) save 1 plot 1}} 1.0 {} 1]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7 1
    ov_key $key <Control-Key-r>
    ov_select $key $sraw tran saved
    catch {
        xschem new_schematic switch [ov_drw $key]
        xschem graph_axis_zoom 0 x 2e-9 5e-9
    }
    update
    check "OV29 fixture: ASE-L's row kept on run 2 by a select of a saved result, its strip zoomed in X" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] [ov_x $key 0]] {v(a):2 1 {2e-9 5e-9}}
    ov_rerun 3.0 14 1
    pcall ase::result_view_reset $key
    pcall ase::ui::set_plot_after_sim $key 1
    pcall ase::ui::auto_plot_idle $key
    update
    check "OV29 a finished run under Replace: the row is on run 3, nothing kept, and its strip keeps the X window" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] [ov_x $key 0] [ov_y $key 0]] {v(a):3 0 {2e-9 5e-9} {0.6 1.5}}
    check "OV29 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## 3: `u` after a reload between two selects. The load of Ctrl-R drops the
    ## kept copy the undo history names; kept again at the next select, the
    ## same data answers to the name the history knows
    set key [ov_two ov29u tbov29u]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    pcall ase::ui::set_plot_after_sim $key 0
    ov_rerun 2.0 7
    ov_key $key <Control-Key-r>
    ov_select $key $sraw tran saved
    pcall wviewer::delete_items {} {{0 0}} {} $key
    update
    ov_select $key $::ov_raw tran lastrun
    ov_key $key <Control-Key-r>
    check "OV29 fixture: both waveforms kept on run 2 by a select of the saved run 1, the hand trace deleted, the last run selected again, Ctrl-R: one copy of the data is loaded" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] [ov_ndbs $key]] {{{} v(a):2} 0 1}
    ov_select $key $sraw tran saved
    check "OV29 fixture: the saved result selected once more: the row is kept on run 2 again" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key]] {{{} v(a):2} 1}
    ov_key $key <Key-u>
    check "OV29 `u` brings the deleted trace back on the data it showed, and leaves the row on its own (both used to come back plain, drawing the saved result, with no cue)" \
        [list [ov_shows $key] [pcall wviewer::held_traces $key] \
              [regexp "^v\\(b\\)@$::ov_when\$" [lindex [ov_legend $key 0] 0]] [regexp "^A@$::ov_when\$" [lindex [ov_legend $key 1] 0]]] \
        {{v(b):2 v(a):2} 2 1 1}
    ov_key $key <Alt-Shift-Key-P>
    check "OV29 ...and the key then draws the saved result beside each" [ov_shows $key] {{v(b):2 v(b):1:1+40} {v(a):2 v(a):1:1+40}}
    check "OV29 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## ...and at the overlay's own keep: a saved result that the viewer shows
    ## is kept, dropped by a load, shown and kept again
    set key [ov_two ov29n tbov29n]
    pcall ase::saved_save $key gold {} {} 0
    set sraw [ov_saved_raw $key gold]
    pcall ase::ui::set_plot_after_sim $key 0
    set names {}
    foreach {amp dt} {2.0 7 3.0 14} {
        ov_rerun $amp $dt
        pcall ase::result_view_reset $key
        ov_key $key <Control-Key-r>
        ov_select $key $sraw tran saved
        ov_key $key <Control-Key-r>
        lappend names [list [ov_shows $key] [pcall wviewer::held_traces $key] [ov_ndbs $key]]
        ov_rerun [expr {$amp + 0.5}] [expr {$dt + 3}]
        pcall ase::result_view_reset $key
        ov_key $key <Alt-Shift-Key-P>
        lappend names [ov_shows $key] [wviewer::dget [lindex [dict get [lindex [ov_gs $key] 0] traces] 0] rawfile {}]
    }
    lassign $names f1 s1 n1 f2 s2 n2
    check "OV29 fixture: the saved result shown alone (selected, then Ctrl-R), twice, with a new run and the key after each" \
        [list $f1 $s1 $f2 $s2] \
        {{{v(b):1 v(a):1} 0 1} {{v(b):1 v(b):2.5:1+40} {v(a):1 v(a):2.5:1+40}} {{v(b):1 v(a):1} 0 1} {{v(b):1 v(b):3.5:1+40} {v(a):1 v(a):3.5:1+40}}}
    check "OV29 the saved result kept by the key the second time answers to the kept name it had the first time: the name the undo history knows" \
        [list [expr {$n1 eq $n2}] [regexp {@held[0-9]+$} $n1] [string match [file dirname $sraw]* $n1]] {1 1 1}
    check "OV29 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}

    ## 4: a modifier the first list did not name
    set key [ov_session ov29k tbov29k {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    ov_key $key <Alt-Shift-Key-P>
    set w [wviewer::window_for $key].wvnotice
    set ups {}
    foreach k {Super_L ISO_Level3_Shift ISO_Level5_Shift Control_L Alt_L} {
        if {[catch {event generate $w <Key-$k>} e]} { lappend ups ERR:$e ; continue }
        update
        lappend ups [winfo exists $w]
    }
    event generate $w <Key-ISO_Left_Tab>
    update
    check "OV29 the Super key, AltGr and its kin typed alone on the small window leave it up, as Control and Alt do; Shift-Tab closes it" \
        [list $ups [winfo exists $w]] {{1 1 1 1 1} 0}
    check "OV29 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV17 {
    ## a saved copy of the run in view has the run file's size and, here, its
    ## time: the two files are told apart by their names
    set key [ov_session ov17 tbov17 {{name A expr v(a) save 1 plot 1}} 1.0]
    pcall wviewer::open $key
    ov_ready $key
    pcall wviewer::set_plot_mode multi $key
    pcall wviewer::clear_all $key
    pcall ase::ui::plot_outputs $key
    update
    pcall ase::saved_save $key twin {} {} 0
    set sraw {}
    foreach e [pcall ase::saved_list $key] {
        if {[ase::state_get [ase::saved_meta [dict get $e dir]] name] eq {twin}} {
            set sraw [file join [dict get $e dir] [file tail $::ov_raw]]
        }
    }
    catch {file mtime $sraw [file mtime $::ov_raw]}
    check "OV17 fixture: the saved copy has the run file's time and size" \
        [expr {[wviewer::file_stamp $sraw] eq [wviewer::file_stamp $::ov_raw] && [llength [wviewer::file_stamp $sraw]] == 2}] 1
    pcall ase::ui::rsel_arm $key $sraw tran saved
    pcall ase::ui::rsel_commit $key
    update
    ## ASE-L goes back to the latest run, and the viewer is not told
    pcall ase::result_sel_note $key {}
    check "OV17 fixture: the viewer's data is the saved copy, ASE-L has the latest run in view; the copy is the run's own data, so the select kept nothing" \
        [list [file tail [file dirname [pcall apply {{key} { xschem new_schematic switch [ov_drw $key] ; xschem raw rawfile }} $key]]] \
              [pcall ase::last_rawfile $key] [pcall wviewer::held_traces $key]] [list twin $::ov_raw 0]
    set ::ov_said {}
    ov_key $key <Alt-Shift-Key-P>
    check "OV17 the key reads the run's own file, though the copy in the viewer has its time and size: the viewer's data is the run again, the trace shows it with no pin and no second version" \
        [list [pcall apply {{key} { xschem new_schematic switch [ov_drw $key] ; xschem raw rawfile }} $key] \
              [ov_shows $key] [pcall wviewer::held_traces $key] [ov_notice $key]] \
        [list $::ov_raw v(a):1 0 {}]
    check "OV17 ...and the sentence says the result is shown and that nothing had an earlier version" \
        [lsearch -all -inline -glob $::ov_said {wviewer: *is shown; no waveform*}] \
        [list {wviewer: tbov17_ase.raw (tran) is shown; no waveform had an earlier version to keep beside it}]
    check "OV17 no background error" $::ov_bg {}
    catch {wviewer::close $key}
    catch {ase::session_close $key}
}

group OV15 {
    ## a session with no results file of its own; a file typed into the
    ## viewer's Location bar is the result the key reads
    set tok [ov_session ov15 tbov15 {} {}]
    set f [file join $::scratch ov15.raw]
    ov_tran $f 10e-9 1.0
    check "OV15 fixture: the session answers nothing; a file is loaded through the viewer's Location bar and v(b) plotted from it" \
        [list [pcall ase::ui::reload_source $tok] [pcall wviewer::open $tok] [ov_ready $tok] \
              [pcall wviewer::rawbar_load $tok $f] [pcall wviewer::add_trace $tok 0 v(b)]] {{} 1 1 1 {}}
    update
    set lay0 [wviewer::layout_for $tok]
    ov_key $tok <Alt-Shift-Key-P>
    check "OV15 the key right after: the window shows that very file, so nothing changes and the small window says so" \
        [list [expr {[wviewer::layout_for $tok] eq $lay0}] [ov_ndbs $tok] [lindex [ov_notice $tok] 0]] \
        [list 1 1 {Every waveform in this window already shows the latest result (ov15.raw (tran)).}]
    ov_notice_close $tok
    file stat $f a0
    ov_tran $f 10e-9 4.0
    file mtime $f [expr {$a0(mtime) + 7}]
    ov_key $tok <Alt-Shift-Key-P>
    check "OV15 the file written again: the key draws it beside what was shown" [ov_shows $tok] {{v(b):1 v(b):4:1+40}}
    ## a state restored into a window that has read nothing yet
    set snap [pcall wviewer::snapshot $tok {}]
    dict set snap graphs [list [dict create traces [list [tr v(b)]]]]
    catch {wviewer::close $tok}
    catch {ase::session_close $tok}
    set tok [ov_session ov15r tbov15r {} {}]
    pcall wviewer::open $tok
    ov_ready $tok
    check "OV15 fixture: a saved state is restored into a fresh window on that file" \
        [list [pcall wviewer::restore $tok $snap $f tran] [ov_shows $tok]] {1 v(b):4}
    update
    ov_key $tok <Alt-Shift-Key-P>
    check "OV15 the key after a restore: the window shows the file as it stands, nothing is read or added" \
        [list [ov_shows $tok] [ov_ndbs $tok] [lindex [ov_notice $tok] 0]] \
        [list v(b):4 1 {Every waveform in this window already shows the latest result (ov15.raw (tran)).}]
    ov_notice_close $tok
    catch {wviewer::close $tok}
    catch {ase::session_close $tok}
    set tok [ov_session ov15b tbov15b {} {}]
    pcall wviewer::open $tok
    ov_ready $tok
    check "OV15 fixture: a file attached with its trace by the scripting door" [pcall wviewer::display_raw $tok $f tran v(b)] 1
    update
    ov_key $tok <Alt-Shift-Key-P>
    check "OV15 the key after that door: nothing is read or added either" \
        [list [ov_shows $tok] [ov_ndbs $tok] [lindex [ov_notice $tok] 0]] \
        [list v(b):4 1 {Every waveform in this window already shows the latest result (ov15.raw (tran)).}]
    check "OV15 no background error" $::ov_bg {}
    catch {wviewer::close $tok}
    catch {ase::session_close $tok}
}
} else {
    puts "skip: OV1 to OV29 need a display (no Tk on this arm)"
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
