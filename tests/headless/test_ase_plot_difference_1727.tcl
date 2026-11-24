# tests/headless/test_ase_plot_difference_1727.tcl -- "plot the difference of
# two nets", driven from the schematic window (issue 1727; spec
# doc/claude/specs/ase_l.md, "Plot the difference of two nets").
#
# In the Cadence profile Alt-Shift-D runs `ase::plot_difference_for_current
# tran`: a click mode on the design canvas that asks for a first net and then a
# second, each with a prompt on the bottom status line, and at the second net
# plots SECOND MINUS FIRST in the session's waveform viewer and ends.
#
# THE FIXTURE NEEDS NO SIMULATOR. The sheets are written here (a top sheet with
# named nets, a bus, an unlabelled wire, a wire the netlist skips, a resistor
# with bare pins, a voltage source with one pin on a wire and one bare, a net
# label that is clicked on its own text, and a block with a wire on one pin
# and a sheet of its own), and so is the results file: an ASCII raw whose
# numbers this file chooses, so every expected value below is computed from
# those numbers and never through the product's expression path.
#
# BANDS, both arms (the decision):
#   PA  the analyses a difference is plotted from, and the choice of one, as a
#       table over every combination of the three present or absent, with and
#       without an operating point beside them, and every word
#   PT  the Calculator text of the difference, its translation, and the numbers
#       the engine answers for it on the raw written here (AC: the complex
#       difference's magnitude)
#   PN  the names an analysis of the results file holds
#   PC  what one click is: the net, or the refusal, read on the loaded sheet
#   PE  the command's own refusals: no session, no results, no analysis
#   PR  src/cadence_style_rc read as text: the key's line and the two examples;
#       and every file of src/ read as text: nothing else there runs the command
#   PX  the rows the spec names are rows of this file
# BANDS, display arm only (the act; under --nogui each prints one `skip:`):
#   GN  with no profile the chord is bound nowhere and does nothing
#   GK  the real chord, real clicks: prompts, one new trace, its values, the
#       sign; a net label clicked on its text, a wire clicked where it meets a pin
#   GQ  in a window nobody sized, with the red field beside the slot holding a
#       line, the slot itself shows what to click and that the plot is the
#       second minus the first
#   GH  the pointer resting on a device pin adds nothing to the prompt
#   GO  one shot: the mode ends on the second net's release, with no ESC
#   GX  ESC cancels and plots nothing
#   GR  every refusal leaves the mode armed on the same step
#   GS  a second difference from the same analysis of the same results leaves
#       the first one drawing; after the results changed it does not; the plot
#       is appended
#   GL  what the mode says reaches the action log (needs --logdir; one `skip:`
#       without it; the display arm of the full regression and full_audit.sh
#       both run this suite with one, row PX2)
#   GD  the second net picked after a descend
#   GU  the two example lines, uncommented into a scratch rc: AC and DC sweep;
#       a difference read from another analysis blanks the one before it
#   GV  the viewer showing another analysis plays no part
#   GM  the analyses the session has enabled now play no part
#   GT  what stops the plot after the second click, each with what to do
#   GF  the fall-back, and the refusal that names what the result holds
#   GC  Caps Lock: the case of the letter as typed decides
#   GP  the prompt whole where the window has room, cut where it has not
#   GE  no session, and no results, through the real chord
#   GW  a canvas made later carries the key, as it carries Ctrl-4
#
# Run it (never a bare ./src/xschem, which would use your screen and HOME):
#   tests/headless/run_suites.sh [--nogui] test_ase_plot_difference_1727

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
    flush stdout
}
# call something that may not exist yet, or may raise, without ending the file
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} ) \" '] $r]" }
    return $r
}
proc dg {d k} {
    if {[string match ERR:* $d]} { return $d }
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
    flush stdout
}
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail; flush stdout }

set no_recent_files 1

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_plot_difference_1727]
test_sim_registry_isolate

set HASX [expr {[info exists ::has_x] && [info commands winfo] ne {} && ![catch {winfo exists .drw} e_] && $e_}]
set RC [file join $repo src cadence_style_rc]

# ---------------------------------------------------------------------------
# the notices, captured at the one spy point every ASE suite uses
# ---------------------------------------------------------------------------
set ::notices {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo pd_real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg }
proc said {pat} {
    foreach m $::notices { if {[string match $pat $m]} { return 1 } }
    return 0
}
proc last_said {} { return [lindex $::notices end] }
# was exactly this sentence said (no pattern: a sentence may hold brackets)
proc said_just {s} { return [expr {[lsearch -exact $::notices $s] >= 0 ? 1 : 0}] }
# run `script` with the command `name` standing in as a proc of body `body`,
# and put the real one back whatever happens
proc with_stub {name body script} {
    rename $name ${name}__pd_real
    proc $name args $body
    set code [catch {uplevel 1 $script} r]
    rename $name {}
    rename ${name}__pd_real $name
    if {$code} { return -code error $r }
    return $r
}
# end whatever click mode a row left up, so one band's red does not become the next's
proc no_mode {} {
    if {[info exists ::ase::ui::sod(active)]} { catch {ase::ui::sod_end $::ase::ui::sod(active)} }
    catch {update}
}
# ...and put the design window back on its top sheet, whatever a band left
proc at_top {} {
    no_mode
    catch {xschem new_schematic switch .drw}
    set moved 0
    while {![catch {xschem get currsch} l] && $l > 0} { xschem go_back ; set moved 1 }
    catch {xschem unselect_all}
    if {$moved} { catch {xschem zoom_full} }
    catch {update}
}

# ---------------------------------------------------------------------------
# the numbers of the results file, chosen here
# ---------------------------------------------------------------------------
set ::T_TIME {0 1e-9 2e-9 3e-9 4e-9}
set ::T(a)      {1.0 1.5 2.0 0.25 0.5}
set ::T(b)      {3.0 2.0 0.5 4.0 1.0}
set ::T(e)      {0.1 0.2 0.3 0.4 0.5}
set ::T(x1.mid) {0.6 0.7 0.9 1.3 2.1}
# AC: {magnitude degrees} per point; a and b differ in phase at every point
set ::F_FREQ {1e3 1e4 1e5}
set ::F(a)      {{1.0 0} {2.0 30} {0.5 170}}
set ::F(b)      {{1.0 90} {3.0 -60} {0.5 -170}}
set ::F(e)      {{0.25 10} {0.5 20} {0.75 45}}
set ::F(x1.mid) {{1.5 -30} {0.2 60} {2.5 120}}
set ::S_SWEEP {0 1 2}
set ::S(a)      {0.0 0.5 1.0}
set ::S(b)      {1.0 0.75 0.5}
set ::S(e)      {0.3 0.2 0.1}
set ::S(x1.mid) {2.0 2.5 3.5}
set ::NETS {a b e x1.mid}

# WHAT THE STATUS SLOT MUST STILL SHOW of each sentence but the first prompt
# when it has no room for all of it: the request, which is why the request
# comes straight after the head. Row PM2 holds the sentences to that order and
# band GQ reads the words off the slot of a window nobody sized.
set ::NEED {
    second   {click second net (second minus first)}
    nothing  {click a wire or a net label}
    terminal {click a wire or a net label}
    body     {click a wire or a net label}
    unnamed  {click another wire or net label}
    bus      {click a one-bit wire or net label}
    same     {click another net for the second}
    absent   {click a net the run saved}
}

proc pd_cx {m d} {
    set r [expr {acos(-1) / 180.0}]
    return [format %.15e,%.15e [expr {$m * cos($d * $r)}] [expr {$m * sin($d * $r)}]]
}
proc pd_plot {f name flags vars rows} {
    puts $f "Title: plot difference fixture"
    puts $f "Date: Mon Nov 23 00:00:00  2026"
    puts $f "Plotname: $name"
    puts $f "Flags: $flags"
    puts $f "No. Variables: [llength $vars]"
    puts $f "No. Points: [llength $rows]"
    puts $f "Variables:"
    set i 0
    foreach v $vars { puts $f "\t$i\t[lindex $v 0]\t[lindex $v 1]" ; incr i }
    puts $f "Values:"
    set p 0
    foreach r $rows {
        set first 1
        foreach v $r {
            if {$first} { puts $f " $p\t$v" ; set first 0 } else { puts $f "\t$v" }
        }
        puts $f ""
        incr p
    }
}
# write the session's results file with the analyses named, in that order; the
# file's time is moved forward at every write so no two writes look the same
set ::RAWCLOCK [clock seconds]
proc pd_raw {path analyses} {
    file mkdir [file dirname $path]
    set f [open $path w]
    foreach an $analyses {
        set vars {}
        set rows {}
        switch -exact -- $an {
            tran {
                lappend vars {time time}
                foreach n $::NETS { lappend vars [list v($n) voltage] }
                set i 0
                foreach t $::T_TIME {
                    set r [list $t]
                    foreach n $::NETS { lappend r [lindex $::T($n) $i] }
                    lappend rows $r
                    incr i
                }
                pd_plot $f {Transient Analysis} real $vars $rows
            }
            ac {
                lappend vars {frequency frequency}
                foreach n $::NETS { lappend vars [list v($n) voltage] }
                set i 0
                foreach t $::F_FREQ {
                    set r [list "$t,0"]
                    foreach n $::NETS { lappend r [pd_cx {*}[lindex $::F($n) $i]] }
                    lappend rows $r
                    incr i
                }
                pd_plot $f {AC Analysis} complex $vars $rows
            }
            dc {
                lappend vars {v-sweep voltage}
                foreach n $::NETS { lappend vars [list v($n) voltage] }
                set i 0
                foreach t $::S_SWEEP {
                    set r [list $t]
                    foreach n $::NETS { lappend r [lindex $::S($n) $i] }
                    lappend rows $r
                    incr i
                }
                pd_plot $f {DC transfer characteristic} real $vars $rows
            }
            op {
                foreach n $::NETS { lappend vars [list v($n) voltage] }
                set r {}
                foreach n $::NETS { lappend r [lindex $::T($n) 0] }
                pd_plot $f {Operating Point} real $vars [list $r]
            }
        }
    }
    close $f
    incr ::RAWCLOCK 7
    file mtime $path $::RAWCLOCK
    return $path
}
# the row's own arithmetic, from the numbers above
proc pd_sub {l2 l1} {
    set out {}
    foreach y $l2 x $l1 { lappend out [expr {$y - $x}] }
    return $out
}
proc pd_cmag {l2 l1} {
    set r [expr {acos(-1) / 180.0}]
    set out {}
    foreach y $l2 x $l1 {
        lassign $y my dy ; lassign $x mx dx
        set re [expr {$my * cos($dy * $r) - $mx * cos($dx * $r)}]
        set im [expr {$my * sin($dy * $r) - $mx * sin($dx * $r)}]
        lappend out [expr {sqrt($re * $re + $im * $im)}]
    }
    return $out
}
proc pd_mags {l} { return [lmap p $l {lindex $p 0}] }
# `ok`, or what differs: two lists of numbers, element by element
proc near {got want {tol 1e-5}} {
    if {[catch {llength $got} n] || $n != [llength $want]} { return "LEN:$got" }
    foreach g $got w $want {
        if {![string is double -strict $g]} { return "NAN:$got" }
        if {abs($g - $w) > $tol * (1.0 + abs($w))} { return "DIFF:$got" }
    }
    return ok
}
# the smallest distance between two lists, element by element
proc apart {l1 l2} {
    set m {}
    foreach x $l1 y $l2 {
        set d [expr {abs($x - $y)}]
        if {$m eq {} || $d < $m} { set m $d }
    }
    return $m
}

# ---------------------------------------------------------------------------
# src/cadence_style_rc as text, for band PR and for the chords bands GN and GU press
# ---------------------------------------------------------------------------
set ::RCTEXT {}
catch { set fh [open $::RC] ; set ::RCTEXT [read $fh] ; close $fh }
# every line of the profile that binds a key to the command, as {commented
# sequence word}; `commented` is 1 for a line behind one `# `
proc pr_lines {} {
    set out {}
    foreach ln [split $::RCTEXT "\n"] {
        if {[regexp {^(# )?bind \.drw <([^>]+)>\s+\{ase::plot_difference_for_current(?:\s+(\S+))?;\s*break\}\s*$} $ln -> c seq word]} {
            lappend out [list [expr {$c ne {}}] $seq $word]
        }
    }
    return $out
}
# ---------------------------------------------------------------------------
# GN -- with no profile the chord does nothing (before the profile is sourced)
# ---------------------------------------------------------------------------
set ::SHIFT 1 ; set ::LOCK 2 ; set ::CTRL 4 ; set ::ALT 8
if {$HASX} {
    for {set i 0} {$i < 200} {incr i} {
        if {[winfo ismapped .drw] && [winfo width .drw] > 300 && [winfo height .drw] > 300} break
        update ; after 25
    }
    group GN {
        check "GN0 fixture: the design canvas is mapped and sized before anything is measured" \
            [list [winfo ismapped .drw] [expr {[winfo width .drw] > 300 && [winfo height .drw] > 300}]] {1 1}
        focus -force .drw ; update
        # the letters of the profile's line and of its two examples, from the file
        set letters {}
        foreach l [pr_lines] { if {[regexp {^Alt-Key-([A-Z])$} [lindex $l 1] -> c]} { lappend letters $c } }
        # what a native action would move: the editor's state and selection, the
        # sheet and what is on it, the view, the windows, the canvas's bindings
        proc gn_state {} {
            return [list [xschem get ui_state] [xschem get ui_state2] [xschem get lastsel] [xschem get modified] \
                         [xschem get schname] [xschem get instances] [xschem get wires] \
                         [xschem get zoom] [xschem get xorigin] [xschem get yorigin] \
                         [llength [xschem windows]] [lsort [winfo children .]] [lsort [bind .drw]]]
        }
        # every binding tag the canvas answers to, the canvas itself among them
        set tags [bindtags .drw]
        set bound {}
        foreach c $letters {
            foreach tag $tags {
                if {![catch {bind $tag <Alt-Key-$c>} scr] && $scr ne {}} { lappend bound [list $tag $c] }
            }
        }
        set before [gn_state]
        set moved {}
        set ::notices {}
        foreach c $letters {
            event generate .drw <KeyPress> -keysym $c -state [expr {$::SHIFT | $::ALT}] -x 200 -y 200 -when now
            update
            if {[gn_state] ne $before || [grab current] ne {} || [info exists ::ase::ui::sod(active)]} { lappend moved $c }
        }
        check "GN1 with no profile sourced, the letter of the profile's line and of each of its two examples is bound with Alt on none of the canvas's binding tags, and a real Alt-Shift press of each changes no editor state, sheet, view or window, leaves no mode, grab or binding behind and says nothing: the key exists in the profile only, and displaces no native action" \
            [list [llength $letters] [expr {[lsearch -exact $tags .drw] >= 0}] $bound $moved $::notices] {3 1 {} {} {}}
        set srcrc [catch {source $::RC} srcerr]
        check "GN2 fixture: src/cadence_style_rc sources on this arm" [list $srcrc] {0}
        update
    }
}

# ---------------------------------------------------------------------------
# the sheets, the library, the session
# ---------------------------------------------------------------------------
set lib [file join $scratch pdlib]
file mkdir $lib
set blk [file join $lib pdblk.sym]
set f [open $blk w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
puts $f {G {}}
puts $f "K {type=subcircuit\nformat=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"}"
foreach k {V S F E} { puts $f "$k {}" }
puts $f {L 4 0 -40 0 -25 {}}
puts $f {L 4 0 25 0 40 {}}
puts $f {B 5 -2.5 -42.5 2.5 -37.5 {name=T dir=in}}
puts $f {B 5 -2.5 37.5 2.5 42.5 {name=U dir=out}}
puts $f {P 4 5 -50 -25 50 -25 50 25 -50 25 -50 -25 {}}
close $f
set f [open [file join $lib pdblk.sch] w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
puts $f {N 0 -30 0 -120 {}}
puts $f {N 0 30 0 110 {}}
puts $f {N 200 0 400 0 {}}
puts $f {C {devices/ipin} 0 -120 0 0 {name=q1 lab=T}}
puts $f {C {devices/opin} 0 110 0 0 {name=q2 lab=U}}
puts $f {C {devices/res} 0 0 0 0 {name=R5 value=1k m=1}}
puts $f {C {devices/lab_pin} 200 0 0 0 {name=l9 sig_type=std_logic lab=mid}}
close $f
set top [file normalize [file join $lib pd_top.sch]]
set f [open $top w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
puts $f {N 0 0 200 0 {}}
puts $f {N 0 100 200 100 {}}
puts $f {N 0 200 200 200 {}}
puts $f {N 0 300 200 300 {}}
puts $f {N 0 400 200 400 {}}
puts $f {N 0 500 200 500 {spice_ignore=true}}
puts $f {N 800 60 800 -40 {}}
puts $f {N 500 370 500 320 {}}
puts $f {C {devices/lab_pin} 500 320 0 0 {name=l6 sig_type=std_logic lab=a}}
puts $f {C {devices/vsource} 500 400 0 0 {name=V1 value=1}}
puts $f {C {devices/lab_pin} 0 0 0 0 {name=l1 sig_type=std_logic lab=a}}
puts $f {C {devices/lab_pin} 0 100 0 0 {name=l2 sig_type=std_logic lab=b}}
puts $f {C {devices/lab_pin} 0 200 0 0 {name=l3 sig_type=std_logic lab=c}}
puts $f {C {devices/lab_pin} 0 300 0 0 {name=l4 sig_type=std_logic lab=d[1:0]}}
puts $f {C {devices/lab_pin} 800 -40 0 0 {name=l5 sig_type=std_logic lab=e}}
puts $f {C {devices/res} 500 100 0 0 {name=R1 value=1k m=1}}
puts $f "C {$blk} 800 100 0 0 {name=x1}"
close $f
# where to click, in schematic units: the middle of each wire, the resistor's
# body and its upper pin (bare), a point with nothing near it, the block's
# body, and inside the block's own sheet the labelled wire and the wire of its
# input port. And the points that are not the middle of a wire: `label` is on
# the text of the net label of net a that sits on the source's wire, off that
# wire; `blockpin` is the end of net e's wire on the block's pin T; `srcbody`
# is the source's body, `srcpin` its upper pin, where the wire of net a ends,
# and `srcbare` its lower pin, which has nothing on it.
array set ::AT {
    a {100 0}  b {100 100}  c {100 200}  bus {100 300}  auto {100 400}
    skipped {100 500}  body {500 100}  pin {500 70}  empty {350 250}
    block {800 100}  e {800 10}
    label {489 317}  blockpin {800 60}
    srcbody {500 400}  srcpin {500 370}  srcbare {500 430}
    mid {300 0}  port {0 -80}
}
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE pdlib $lib"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir [file normalize [file join $scratch run]]
set rawpath [file join $rundir pd_top_ase.raw]
set key {}

if {[catch {

group FX {
    check "FX1 fixture: the top sheet loads and resolves to a registered cellview" \
        [list [catch {xschem load $::top}] [pcall ase::design_of_path $::top]] {0 {pdlib pd_top schematic}}
    set ::key [pcall ase::new_session pdlib pd_top schematic]
    set st [pcall ase::session_state $::key]
    dict set st rundir $::rundir
    pcall ase::session_update $::key $st
    check "FX2 fixture: a session is bound to the sheet, is the one found from it, and names the results file this suite writes" \
        [list [lindex [pcall ase::session_for_current] 0] [pcall ase::last_rawfile $::key] \
              [file isfile [pd_raw $::rawpath {tran ac dc op}]] [pcall ase::last_rawfile $::key]] \
        [list $::key {} 1 $::rawpath]
    check "FX3 fixture: the numbers chosen tell second-minus-first from first-minus-second and from zero at every point, and the AC pair tells the complex difference from the difference of the magnitudes" \
        [list [expr {[apart [pd_sub $::T(b) $::T(a)] [pd_sub $::T(a) $::T(b)]] > 0.5}] \
              [expr {[apart [pd_sub $::S(b) $::S(a)] [pd_sub $::S(a) $::S(b)]] > 0.4}] \
              [expr {[apart [pd_cmag $::F(b) $::F(a)] [pd_sub [pd_mags $::F(b)] [pd_mags $::F(a)]]] > 0.1}]] {1 1 1}
}

# ===========================================================================
# PA -- the analyses, and the choice of one (pure)
# ===========================================================================
group PA {
    set fns [pcall ase::diff_functions]
    check "PA1 the analyses a difference is plotted from, each with the Calculator's own voltage function for it, are the Calculator's voltage selectors less the operating point" \
        $fns {tran vt ac vf dc vs}
    set words [list]
    catch {set words [dict keys $fns]}
    check "PA1 ...and the population the table below walks is not empty" [expr {[llength $words] >= 3}] 1
    check "PA2 the command takes one optional word and with none it reads the transient" \
        [list [pcall info args ::ase::plot_difference_for_current] \
              [pcall apply {{} { list [info default ::ase::plot_difference_for_current analysis d] $d }}]] \
        {analysis {1 tran}}
    # the table, written out: what is present of the three -> for each word
    # the analysis read, a trailing `*` where it is read INSTEAD of the word's,
    # or `-` for a refusal
    set table {
        {}            {tran -      ac -      dc -}
        {tran}        {tran tran   ac tran*  dc tran*}
        {ac}          {tran ac*    ac ac     dc ac*}
        {dc}          {tran dc*    ac dc*    dc dc}
        {tran ac}     {tran tran   ac ac     dc -}
        {tran dc}     {tran tran   ac -      dc dc}
        {ac dc}       {tran -      ac ac     dc dc}
        {tran ac dc}  {tran tran   ac ac     dc dc}
    }
    set nrow 0
    set bad {}
    foreach {present row} $table {
        foreach extra {{} op {op noise}} {
            foreach {word want} $row {
                set d [pcall ase::diff_analysis [concat $extra $present] $word]
                set got -
                if {[dg $d ok] eq {1}} {
                    set got [dg $d analysis]
                    if {[dg $d fallback] eq {1}} { append got * }
                } elseif {[dg $d ok] ne {0}} {
                    set got $d
                }
                incr nrow
                if {$got ne $want} { lappend bad "[list [concat $extra $present] $word] -> $got (want $want)" }
            }
        }
    }
    check "PA3 the choice, over every combination of transient, AC and DC sweep present or absent, alone, beside an operating point and beside an operating point and a noise analysis, and every word: the word's analysis when the result holds it, the one analysis with a wave when it holds exactly one, a refusal otherwise" \
        [list $nrow $bad] {72 {}}
    set d [pcall ase::diff_analysis {op ac} tran]
    check "PA4 an analysis read instead of the word's is said in one sentence naming the word's analysis, what the result holds and the analysis read" \
        [dg $d msg] {ase: Plot Difference — the loaded result has no transient analysis (it holds operating point and AC); reading its AC analysis instead}
    set d [pcall ase::diff_analysis {tran op} tran]
    check "PA4 ...and the word's own analysis says nothing" [list [dg $d fallback] [dg $d msg]] {0 {}}
    set d [pcall ase::diff_analysis {ac dc op} tran]
    check "PA5 two analyses with a wave and neither the word's: refused in one sentence naming what the result holds and the words to bind" \
        [list [dg $d ok] [dg $d msg]] \
        {0 {ase: Plot Difference — the loaded result has no transient analysis (it holds AC, DC sweep and operating point); name the analysis to read on the key's bind line: ase::plot_difference_for_current ac or dc}}
    set d [pcall ase::diff_analysis {op} tran]
    check "PA6 a result with nothing to take: refused naming what it holds and what a difference needs" \
        [list [dg $d ok] [dg $d msg]] \
        {0 {ase: Plot Difference — nothing to plot a difference from: the loaded result holds operating point, and a difference needs a transient, AC or DC sweep analysis; enable one in ASE-L and run again}}
    set d [pcall ase::diff_analysis {} dc]
    check "PA6 ...and a result no analysis could be read from says that" \
        [list [dg $d ok] [string match {*the loaded result holds no analysis that can be read, and a difference needs*} [dg $d msg]]] {0 1}
    set d [pcall ase::diff_analysis {tran ac dc} op]
    check "PA7 a word that is none of the three is refused naming the three, whatever the result holds: the operating point has no wave, and a mistyped word is not read as another analysis" \
        [list [dg $d ok] [dg $d msg] [dg [pcall ase::diff_analysis {tran} trann] ok]] \
        {0 {ase: Plot Difference — 'op' names no analysis a difference is plotted from; write tran, ac or dc after ase::plot_difference_for_current} 0}
    check "PA8 the word is read in any letter case" \
        [list [dg [pcall ase::diff_analysis {tran ac} AC] analysis] [dg [pcall ase::diff_analysis {tran ac} Tran] analysis]] {ac tran}
}

# ===========================================================================
# PT -- the text, its translation, and the engine's numbers for it
# ===========================================================================
group PT {
    check "PT1 the text of a transient and of a DC sweep difference is the second net's function minus the first's, in the Calculator's own spelling" \
        [list [pcall ase::diff_text tran v(a) v(b)] [pcall ase::diff_text dc v(x1.mid) v(a)]] \
        {{vt(b) - vt(a)} {vs(a) - vs(x1.mid)}}
    set act [pcall ase::diff_text ac v(a) v(b)]
    check "PT2 the AC text is postfix over vf() and the phase columns: the magnitude of the complex difference" \
        $act {vf(b) ph(b) re() vf(a) ph(a) re() - dup() * vf(b) ph(b) im() vf(a) ph(a) im() - dup() * + sqrt()}
    set routed {}
    foreach an {tran dc ac} {
        set r [pcall calc::ix_route [pcall ase::diff_text $an v(a) v(b)]]
        lappend routed [list [dg $r mode] [pcall calc::aq_strip [dg $r rpn]]]
    }
    check "PT3 each text goes through the Calculator's translator and comes out as the engine's postfix" \
        $routed [list {infix {v(b) v(a) -}} {infix {v(b) v(a) -}} \
                      {rpn {v(b) ph(b) re() v(a) ph(a) re() - dup() * v(b) ph(b) im() v(a) ph(a) im() - dup() * + sqrt()}}]
    # the engine, on the raw written here, with no viewer: read each analysis,
    # add the translated text as a vector, read it back
    set got {}
    foreach an {tran dc ac} {
        set r [pcall calc::ix_route [pcall ase::diff_text $an v(a) v(b)]]
        set rpn [pcall calc::aq_strip [dg $r rpn]]
        set v ERR
        if {![catch {xschem raw read $::rawpath $an} rd] && $rd eq {1}} {
            catch {xschem raw add pdt_$an $rpn ; set v [string trim [xschem raw values pdt_$an]]}
            if {$an eq {ac}} { set ::PT_NAIVE [pcall xschem raw add pdt_naive {v(b) v(a) -}] ; set ::PT_NAIVEV [string trim [pcall xschem raw values pdt_naive]] }
        }
        catch {xschem raw clear}
        lappend got $v
    }
    check "PT4 the engine's answer for the transient and DC sweep texts is b minus a, from the numbers this file chose" \
        [list [near [lindex $got 0] [pd_sub $::T(b) $::T(a)]] [near [lindex $got 1] [pd_sub $::S(b) $::S(a)]]] {ok ok}
    check "PT5 the engine's answer for the AC text is the magnitude of the complex difference" \
        [near [lindex $got 2] [pd_cmag $::F(b) $::F(a)]] ok
    check "PT5 ...which the plain difference of the two AC columns is not: that one answers the difference of the magnitudes, which is why the AC text is not `vf(b) - vf(a)`" \
        [list [near $::PT_NAIVEV [pd_sub [pd_mags $::F(b)] [pd_mags $::F(a)]]] \
              [expr {[near $::PT_NAIVEV [pd_cmag $::F(b) $::F(a)]] eq {ok} ? {SAME} : {differs}}]] {ok differs}
}

# ===========================================================================
# PN -- the names an analysis of the file holds
# ===========================================================================
group PN {
    set want [list time]
    foreach n $::NETS { lappend want v($n) }
    check "PN1 the names of the transient analysis are read from the file's own header, and an analysis the file does not hold has none" \
        [list [pcall ase::diff_names $::rawpath tran] [pcall ase::diff_names $::rawpath noise] \
              [pcall ase::diff_names [file join $::scratch nosuch.raw] tran]] [list $want {} {}]
    check "PN2 a Plotname record is one analysis, by the Calculator's reading" \
        [lmap p {{Transient Analysis} {AC Analysis} {DC transfer characteristic} {Operating Point} {Something Else}} {pcall calc::analysis_of_plot $p}] \
        {tran ac dc op {}}
    check "PN3 the Calculator still reads the file's analyses as it did" [pcall calc::raw_analyses $::rawpath] {tran ac dc op}
}

# ===========================================================================
# PC -- what one click is, read on the loaded sheet (no canvas needed)
# ===========================================================================
group PC {
    catch {xschem load $::top}
    set idx [pcall wviewer::name_index [pcall ase::diff_names $::rawpath tran]]
    # what the points that are not a wire's middle are, asked of the engine and
    # of Direct Plot's own rules: the object under `label` is a net label and no
    # copper is there; Direct Plot's source rule takes the source's body; and
    # Direct Plot's pin rule takes a pin at each of the four pin points
    set lhit [pcall xschem object_at {*}$::AT(label)]
    set pins {}
    foreach w {blockpin srcpin srcbare pin} {
        set t [pcall ase::ui::sod_terminal_at $::key {*}$::AT($w)]
        lappend pins "[dg $t instname]:[dg $t pinname]"
    }
    check "PC0 fixture: the label point is on a net label's symbol and off every wire, the source's body is a source by Direct Plot's source rule, and each pin point is a device pin by Direct Plot's pin rule (two with a wire ending on them, two bare)" \
        [list [lindex $lhit 0] [pcall xschem getprop instance [lindex $lhit 1] cell::type] [pcall xschem net_at {*}$::AT(label)] \
              [pcall ase::ui::sod_source_at [pcall xschem object_at {*}$::AT(srcbody)]] $pins \
              [lmap w {blockpin srcpin srcbare pin} {lindex [pcall xschem object_at {*}$::AT($w)] 0}]] \
        {instance label 0 V1 {x1:T V1:p V1:m R1:P} {wire wire instance instance}}
    set got {}
    foreach w {a b e auto} {
        set p [pcall ase::ui::pd_pick $::key {*}$::AT($w) {} $idx]
        lappend got [list [dg $p kind] [dg $p ex]]
    }
    check "PC1 a click on a wire of a named net is that net, as the simulator's vector for it; an unlabelled wire is a net as well, and is refused here only because this result does not hold it" \
        $got {{net v(a)} {net v(b)} {net v(e)} {absent NOKEY:ex}}
    set got {}
    foreach w {label blockpin srcpin} {
        set p [pcall ase::ui::pd_pick $::key {*}$::AT($w) {} $idx]
        lappend got [list $w [dg $p kind] [dg $p ex]]
    }
    check "PC1 ...a click on a net label's own text is the label's net, and a click on the end of a wire where it meets a block's pin or a source's pin is the wire's net: never the pin's current" \
        $got {{label net v(a)} {blockpin net v(e)} {srcpin net v(a)}}
    set kinds {}
    foreach w {empty body pin skipped bus block c} {
        set p [pcall ase::ui::pd_pick $::key {*}$::AT($w) {} $idx]
        lappend kinds [list $w [dg $p kind] [dg $p a] [dg $p b]]
    }
    check "PC2 every click that is not one named net of the result is its own refusal, with what was clicked: empty space, a device body, a bare pin, a wire the netlist skips, a bus and its width, the block, and a net the result does not hold" \
        $kinds {{empty nothing {} {}} {body body R1 {}} {pin terminal {} {}} {skipped unnamed {} {}} {bus bus {d[1:0]} 2} {block body x1 {}} {c absent c {}}}
    set kinds {}
    foreach w {srcbody srcbare} {
        set p [pcall ase::ui::pd_pick $::key {*}$::AT($w) {} $idx]
        lappend kinds [list $w [dg $p kind] [dg $p a] [dg $p ex]]
    }
    check "PC2 ...a voltage source's body is a device body like any other, named, and its bare pin a bare pin: no current is taken, where Direct Plot would take the source's" \
        $kinds {{srcbody body V1 NOKEY:ex} {srcbare terminal {} NOKEY:ex}}
    set p [pcall ase::ui::pd_pick $::key {*}$::AT(a) v(a) $idx]
    check "PC3 the first net clicked again is refused as the same net, and another net is not" \
        [list [dg $p kind] [dg $p a] [dg [pcall ase::ui::pd_pick $::key {*}$::AT(b) v(a) $idx] kind]] {same a net}
    check "PC4 with no names to ask (a results file whose header could not be read) the click is not refused for absence: the plot decides" \
        [dg [pcall ase::ui::pd_pick $::key {*}$::AT(c) {} [pcall wviewer::name_index {}]] kind] net
    # descended: the pick is qualified as Direct Plot's
    xschem unselect_all ; xschem select instance x1 ; xschem descend
    set p [pcall ase::ui::pd_pick $::key {*}$::AT(mid) {} $idx]
    set q [pcall ase::ui::pd_pick $::key {*}$::AT(port) v(e) $idx]
    check "PC5 after a descend the click names the node as the session's deck does: an inner net by its path, and a port's wire by the parent's net, which is the first net again when that was the first" \
        [list [xschem get currsch] [dg $p kind] [dg $p ex] [dg $q kind] [dg $q a]] {1 net v(x1.mid) same e}
    xschem go_back
    check "PC5 fixture: back on the top sheet" [list [xschem get currsch] [file normalize [xschem get schname]]] [list 0 $::top]
}

# ===========================================================================
# the sentences (pure)
# ===========================================================================
group PM {
    set h {Plot Difference (transient)}
    check "PM1 the two prompts name the analysis and the step; the second says that the plot is the second minus the first before it names the first net, whose name has no bound" \
        [list [pcall ase::ui::pd_msg first tran] [pcall ase::ui::pd_msg second ac {} out]] \
        [list "$h: click the first net; ESC cancels" \
              "Plot Difference (AC): click second net (second minus first); first net out; ESC cancels"]
    check "PM2 each refusal says what to click instead, for the step the mode is on, and then what was clicked" \
        [list [pcall ase::ui::pd_msg nothing tran first] [pcall ase::ui::pd_msg terminal tran second] \
              [pcall ase::ui::pd_msg body tran first R1] [pcall ase::ui::pd_msg unnamed tran first] \
              [pcall ase::ui::pd_msg bus tran second {d[1:0]} 2] [pcall ase::ui::pd_msg same tran second a] \
              [pcall ase::ui::pd_msg absent dc first c]] \
        [list "$h: click a wire or a net label for the first net (nothing under that click)" \
              "$h: click a wire or a net label for the second net (that was a device pin with no wire or net label on it)" \
              "$h: click a wire or a net label for the first net (R1 is not a net)" \
              "$h: click another wire or net label for the first net (that wire has no net name in the netlist)" \
              "$h: click a one-bit wire or net label for the second net (d\[1:0\] is a bus of 2 bits)" \
              "$h: click another net for the second (a is the first net already)" \
              "Plot Difference (DC sweep): click a net the run saved for the first net (c is not in the DC sweep analysis of the loaded result), or save it (ASE-L Outputs > To Be Saved) and run again"]
    # what must be on the slot in a window nobody sized: every sentence begins
    # with its head and, straight after it, the words band GQ looks for there
    set heads {}
    foreach {k words} $::NEED {
        lappend heads [list $k [string first "$h: $words" [pcall ase::ui::pd_msg $k tran second x 2]]]
    }
    check "PM2 ...the request comes first in every sentence but the first prompt: straight after the head, in the words the display band reads off the slot" \
        $heads [lmap {k words} $::NEED {list $k 0}]
    # every kind the builder has answers a sentence: the kinds are read off the
    # builder's own switch, so a kind added there is walked here
    set body [pcall info body ::ase::ui::pd_msg]
    set kinds [regexp -all -inline -line {^\s*([a-z]+)\s+\{\s*return } $body]
    set names {}
    foreach {- k} $kinds { lappend names $k }
    set empty {}
    foreach k $names { if {[string trim [pcall ase::ui::pd_msg $k tran first x 2]] eq {}} { lappend empty $k } }
    check "PM3 every kind of the sentence builder answers a sentence, and a kind it does not have answers none" \
        [list [expr {[llength $names] >= 9}] $empty [pcall ase::ui::pd_msg nosuchkind tran]] {1 {} {}}
    set unlisted {}
    foreach k $names { if {$k ne {first} && ![dict exists $::NEED $k]} { lappend unlisted $k } }
    check "PM3 ...and every kind but the first prompt is one whose opening words rows PM2 and GQ hold it to" \
        [list $unlisted [expr {[llength $names] > 1 && [dict size $::NEED] > 0}]] {{} 1}
}

# ===========================================================================
# PE -- the command's own refusals (no canvas needed)
# ===========================================================================
group PE {
    catch {xschem load $::top}
    pd_raw $::rawpath {ac dc op}
    set ::notices {}
    set r [pcall ase::plot_difference_for_current]
    check "PE1 a result with two wave analyses and no transient: the key's own form answers the session it found, arms nothing and says which analyses the result holds" \
        [list $r [info exists ::ase::ui::sod(active)] [said {ase: Plot Difference — the loaded result has no transient analysis (it holds AC, DC sweep and operating point); name the analysis to read*}]] \
        [list $::key 0 1]
    no_mode
    pd_raw $::rawpath {op}
    set ::notices {}
    pcall ase::plot_difference_for_current ac
    check "PE2 an operating point alone: nothing to plot a difference from, for any word" \
        [list [info exists ::ase::ui::sod(active)] [said {ase: Plot Difference — nothing to plot a difference from: the loaded result holds operating point,*}]] {0 1}
    no_mode
    file delete -force $::rawpath
    set ::notices {}
    pcall ase::plot_difference_for_current
    check "PE3 no results file: refused in Direct Plot's words for it, with what to do" \
        [list [info exists ::ase::ui::sod(active)] [last_said]] \
        {0 {ase: Plot Difference — no simulation results yet — run first, then press the key again}}
    no_mode
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    pcall ase::plot_difference_for_current bogus
    check "PE4 a word that names no such analysis is refused before anything is armed" \
        [list [info exists ::ase::ui::sod(active)] [said {ase: Plot Difference — 'bogus' names no analysis a difference is plotted from; write tran, ac or dc after*}]] {0 1}
    no_mode
    pcall ase::session_close $::key
    set ::notices {}
    set r [pcall ase::plot_difference_for_current]
    check "PE5 no session for the design: the command answers nothing and says so in the words Direct Plot uses" \
        [list $r [last_said]] \
        {{} {ase: no ASE-L session for this design -- Launch ASE-L (Tools menu) or open its ngspice_state view first}}
    set ::key [pcall ase::new_session pdlib pd_top schematic]
    set st [pcall ase::session_state $::key]
    dict set st rundir $::rundir
    pcall ase::session_update $::key $st
    check "PE5 fixture: the session is back" [lindex [pcall ase::session_for_current] 0] $::key
    no_mode
    # an xschem whose Calculator did not load: one of its procs taken away for
    # the length of the call
    set ::notices {}
    set r {}
    set gone [catch {rename ::calc::pick_classify ::calc::pick_classify__pd_away}]
    if {!$gone} {
        set r [pcall ase::ui::plot_difference $::key tran]
        rename ::calc::pick_classify__pd_away ::calc::pick_classify
    }
    check "PE6 without the Calculator nothing is armed, and the sentence says which part is missing, where its file is looked for and to restart" \
        [list $gone $r [info exists ::ase::ui::sod(active)] [last_said]] \
        [list 0 0 0 "ase: Plot Difference — nothing armed: the trace is made by the Calculator, and this xschem has not loaded it (::calc::pick_classify is missing); check that calculator.tcl is in $::XSCHEM_SHAREDIR, then restart xschem"]
    no_mode
}

# ===========================================================================
# PR -- src/cadence_style_rc, read as text
# ===========================================================================
group PR {
    set lines [pr_lines]
    set live {} ; set examples {}
    foreach l $lines { if {[lindex $l 0]} { lappend examples $l } else { lappend live $l } }
    check "PR1 the profile binds one key to the command, on the capital D with Alt and no Shift named, carrying the transient's word, and the line ends in break" \
        $live {{0 Alt-Key-D tran}}
    set fns [pcall ase::diff_functions]
    set others {}
    catch { foreach w [dict keys $fns] { if {$w ne [lindex [lindex $live 0] 2]} { lappend others $w } } }
    check "PR2 under it are two commented lines, one for each other analysis a difference is plotted from, each the same line with another chord and another word" \
        [list [llength $examples] [lsort [lmap l $examples {lindex $l 2}]] [expr {[llength $others] > 0}]] \
        [list 2 [lsort $others] 1]
    # no other uncommented line of the profile binds any of the three chords
    set clash {}
    foreach l $lines {
        set seq [lindex $l 1]
        set n 0
        foreach ln [split $::RCTEXT "\n"] {
            if {[regexp {^\s*bind\s+\S+\s+<([^>]+)>} $ln -> s] && $s eq $seq} { incr n }
        }
        set wantn [expr {[lindex $l 0] ? 0 : 1}]
        if {$n != $wantn} { lappend clash "$seq bound $n times" }
    }
    check "PR3 the three chords are different, and no other uncommented line of the profile binds one of them" \
        [list [llength [lsort -unique [lmap l $lines {lindex $l 1}]]] $clash] {3 {}}
    # every text file of src/ and of the folders in it, every line that is not
    # a comment, searched for the name of the command and of the proc that
    # enters the mode. What may
    # name them is the two definitions, the command's own call of the mode, the
    # name inside the refusal that tells the user what to write, and the
    # profile's line. Anything else -- a menu entry, a toolbar button, a row of
    # the key table, a bind in the stock bindings -- shows as one more line.
    # Blind to: a call spelled through a variable, and Select On Design entered
    # in this flavour by its own proc.
    set scanned {}
    set found {}
    set files {}
    set dirs [list [file join $::repo src]]
    while {[llength $dirs]} {
        set d [lindex $dirs 0]
        set dirs [lrange $dirs 1 end]
        foreach f [glob -nocomplain -types f -directory $d *] { lappend files $f }
        foreach sub [glob -nocomplain -types d -directory $d *] { lappend dirs $sub }
    }
    foreach f [lsort $files] {
        set fh [open $f]
        fconfigure $fh -translation binary
        set raw [read $fh]
        close $fh
        if {[string first "\0" $raw] >= 0} { continue }
        lappend scanned [file tail $f]
        set cfile [expr {[file extension $f] in {.c .h .y .l}}]
        foreach ln [split $raw "\n"] {
            if {[string first plot_difference $ln] < 0} { continue }
            set t [string trim $ln]
            if {!$cfile && [string index $t 0] eq {#}} { continue }
            lappend found [list [file tail $f] [string map [list \{ ( \} )] [regsub -all {\s+} $t { }]]]
        }
    }
    set carriers {}
    foreach n {xschem.tcl keybindings.csv actions.csv action_registry.tcl mouse_bindings.tcl callback.c scheduler.c ase_window.tcl cadence_style_rc xschemrc} {
        if {[lsearch -exact $scanned $n] < 0} { lappend carriers $n }
    }
    check "PR4 over the text files of src/ and its folders, the menus, the key table, the action registry, the stock bindings and the C sources among them, the only lines that are not comments and name the command or the mode's entry are their two definitions, the command's call of the mode, the name in its refusal, and the profile's one line: no menu entry, toolbar button or key outside the profile runs it" \
        [list [expr {[llength $scanned] > 60}] $carriers [lsort $found]] \
        [list 1 {} [lsort [list \
            [list ase.tcl {proc ase::plot_difference_for_current ((analysis tran)) (}] \
            [list ase.tcl {set cmd ase::plot_difference_for_current}] \
            [list ase.tcl {ase::ui::plot_difference $key $analysis}] \
            [list ase_window.tcl {proc ase::ui::plot_difference (key (word tran)) (}] \
            [list cadence_style_rc {bind .drw <Alt-Key-D> (ase::plot_difference_for_current tran; break)}]]]]
}

# ===========================================================================
# PX -- the rows the spec names are rows of this file
# ===========================================================================
group PX {
    set fh [open [file join $::repo doc claude specs ase_l.md]]
    fconfigure $fh -encoding utf-8
    set spec [read $fh]
    close $fh
    set a [string first {**Plot the difference of two nets**} $spec]
    set b [string first {### Menu tree (v2)} $spec]
    set sec {}
    if {$a >= 0 && $b > $a} { set sec [string range $spec $a $b] }
    set named {}
    foreach {- items} [regexp -all -inline {Rows[ \n]+([A-Za-z0-9, \n]+)\.} $sec] {
        foreach it [split [string map [list "\n" { }] $items] ,] {
            set it [string trim $it]
            if {[regexp {^([A-Z]+)([0-9]+) to ([A-Z]+)([0-9]+)$} $it -> p1 n1 p2 n2] && $p1 eq $p2} {
                for {set n $n1} {$n <= $n2} {incr n} { lappend named $p1$n }
            } elseif {$it ne {}} {
                lappend named $it
            }
        }
    }
    set fh [open [info script]]
    fconfigure $fh -encoding utf-8
    set me [read $fh]
    close $fh
    set own {}
    foreach {- id} [regexp -all -inline -line {^\s*check "([A-Z]+[0-9]+)[ "]} $me] { lappend own $id }
    set own [lsort -unique $own]
    set missing {}
    foreach id [lsort -unique $named] { if {[lsearch -exact $own $id] < 0} { lappend missing $id } }
    check "PX1 the spec's section on the difference of two nets names rows, and every row it names is a row of this file" \
        [list [expr {[llength $named] > 20}] [expr {[llength $own] > 20}] $missing] {1 1 {}}
    # band GL needs an action log, and prints a `skip:` without one: the audit
    # must run this suite as it runs Direct Plot's log suite, with --logdir
    set fh [open [file join $::here full_audit.sh]]
    set audit [read $fh]
    close $fh
    set listed {}
    regexp {\nlogdir_tests="([^"]*)"} $audit -> listed
    set words [regexp -all -inline {[A-Za-z0-9_]+} $listed]
    set myname [file rootname [file tail [info script]]]
    check "PX2 full_audit.sh has this suite on its list of suites it runs with an action log, beside Direct Plot's log suite, so band GL runs under the audit" \
        [list [expr {[llength $words] > 10}] [expr {[lsearch -exact $words test_ase_log_seam_0207] >= 0}] [expr {[lsearch -exact $words $myname] >= 0}]] {1 1 1}
}

# ===========================================================================
# the display arm
# ===========================================================================
if {!$HASX} {
    foreach b {GN GK GQ GH GO GX GR GS GL GD GU GV GM GT GF GC GP GE GW} {
        puts "skip: $b -- needs a display: the real chord and real clicks on the design canvas"
    }
} else {

# pixels of a schematic point (X_TO_SCREEN in src/xschem.h)
proc px {x y} {
    set xo [xschem get xorigin] ; set yo [xschem get yorigin]
    set z  [xschem get zoom]
    if {$z == 0} { return {0 0} }
    return [list [expr {int(round(($x + $xo) / $z))}] [expr {int(round(($y + $yo) / $z))}]]
}
# make the design window the current one, as the pointer coming back onto it does
proc to_design {} {
    catch {xschem new_schematic switch .drw}
    update
    return [xschem get current_win_path]
}
set ::ET 900000
set ::MISSED {}
# one real click at a schematic point: a motion (read back), a press, a release
proc mouse_to {x y} {
    set p [px $x $y]
    update
    event generate .drw <Motion> -x [lindex $p 0] -y [lindex $p 1]
    update
    set gx [xschem get mousex] ; set gy [xschem get mousey]
    if {abs($gx - $x) > 2 || abs($gy - $y) > 2} { lappend ::MISSED "wanted $x,$y got $gx,$gy" }
    return $p
}
proc press_at {x y} {
    set p [mouse_to $x $y]
    incr ::ET 5000
    event generate .drw <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] -time $::ET
    update
}
proc release_at {x y} {
    set p [px $x $y]
    event generate .drw <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] -state 256 -time [expr {$::ET + 80}]
    update
}
proc click {w} {
    lassign $::AT($w) x y
    press_at $x $y
    release_at $x $y
}
# a real key on the canvas, with the keyboard put there first
proc key {ks {st 0}} {
    to_design
    for {set i 0} {$i < 40} {incr i} {
        focus -force .drw ; update
        if {[focus -displayof .drw] eq {.drw}} break
        after 25
    }
    event generate .drw <KeyPress> -keysym $ks -state $st -x 300 -y 300 -when now
    update
}
proc chord_d {} { key D [expr {$::SHIFT | $::ALT}] }
# what the mode has on record, absence-tolerant
proc rec {k} { if {[info exists ::ase::ui::sod($::key,$k)]} { return $::ase::ui::sod($::key,$k) } ; return {} }
proc armed {} { return [expr {[info exists ::ase::ui::sod(active)] && $::ase::ui::sod(active) eq $::key ? [rec mode] : {}}] }
proc step {} { return [list [armed] [rec diffan] [rec difffirst]] }
proc prompt {} { return [.statusbar.10 cget -text] }
# is `t` the sentence `full`, or a head of it of some length with the cut mark?
proc shows {t full} {
    if {$t eq $full} { return whole }
    if {[string length $t] > 12 && [string index $t end] eq "\u2026"
        && [string first [string range $t 0 end-1] $full] == 0} { return cut }
    return {}
}
# THE PROMPT: 1 when the mode has `full` on record as its prompt, the status
# slot shows it -- whole, or its head with the cut mark where the window has no
# room for all of it -- and is still showing it several turns of the event loop
# later (a prompt the slot has no room for must not be blanked by the resize it
# would cause). Otherwise what was found.
proc prompt_is {full} {
    if {[rec prompt] ne $full} { return "RECORD:[rec prompt]" }
    set seen {}
    for {set i 0} {$i < 60} {incr i} {
        update
        if {[shows [prompt] $full] ne {}} { set seen 1 ; break }
        after 25
    }
    if {$seen eq {}} { return "SLOT:[prompt]" }
    for {set i 0} {$i < 8} {incr i} { update ; after 30 }
    update
    if {[shows [prompt] $full] eq {}} { return "GONE:[prompt]" }
    return 1
}
# the viewer's traces as {vec expr}
proc traces {} {
    set out {}
    catch {
        foreach G [dict get [wviewer::layout_for $::key] graphs] {
            foreach t [dict get $G traces] { lappend out [list [dict get $t vec] [dict get $t expr]] }
        }
    }
    return $out
}
proc newtraces {before} {
    set out {}
    foreach t [traces] { if {[lsearch -exact $before $t] < 0} { lappend out $t } }
    return $out
}
# a vector of the viewer's data, and the analysis it shows
proc vvals {name} {
    if {[catch {wviewer::enter_ctx $::key} t] || ![lindex $t 0]} { return NOCTX }
    set v NOVEC
    catch {set v [string trim [xschem raw values $name]]}
    catch {wviewer::leave_ctx $::key $t}
    return $v
}
proc vtype {} {
    if {[catch {wviewer::enter_ctx $::key} t] || ![lindex $t 0]} { return NOCTX }
    set v NONE
    catch {set v [xschem raw sim_type]}
    catch {wviewer::leave_ctx $::key $t}
    return $v
}
proc slots {} {
    set out {}
    foreach s {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion> <Double-Button-1>} { lappend out [bind .drw $s] }
    return $out
}
proc end_mode {} { catch {ase::ui::sod_end $::key} ; update }
set H {Plot Difference (transient)}
set P1 "$H: click the first net; ESC cancels"
proc p2 {name {h {}}} {
    if {$h eq {}} { set h $::H }
    return "$h: click second net (second minus first); first net $name; ESC cancels"
}
# THE SLOT WITH THE LEAST ROOM IT HAS IN A GIVEN WINDOW. The red field beside
# the prompt slot takes the short form of every notice whenever the CIW is not
# in front of the user, and the slot's room is what that leaves. With the CIW
# up (a run with an action log) the red field stays empty and the slot has
# room to spare, so the short form of the mode's last notice is put there the
# way the notice channel itself puts it; then the prompt timer is given time
# to fit the prompt to the room, and the slot is read. The engine blanks the
# slot on any event of the canvas until the timer's next turn, so a blank read
# is read again.
proc slot_tight {} {
    catch {xschem::notify_statusbar [xschem::notify_short {} [last_said]] {}}
    for {set i 0} {$i < 12} {incr i} { update ; after 30 }
    update
    for {set i 0} {$i < 20 && [string trim [prompt]] eq {}} {incr i} { after 30 ; update }
    return [prompt]
}
# does the text on the slot hold `words`, and is it a sentence of this mode
# (it starts with `head`)? 1, or what the slot held
proc slot_has {text head words} {
    if {[string first "$head: " $text] == 0 && [string first $words $text] > 0} { return 1 }
    return "SLOT:$text"
}

group GK {
    at_top
    catch {xschem load $::top}
    xschem zoom_full ; update
    pd_raw $::rawpath {tran ac dc op}
    to_design
    set ::FREE [slots]
    set before [traces]
    set ::notices {}
    chord_d
    check "GK1 a real Alt-Shift-D on the design canvas, through the profile's own line, arms the mode for the session of the sheet, reading the transient" \
        [step] {diff tran {}}
    check "GK1 ...the canvas is the mode's and holds the keyboard, so ESC will reach it" \
        [list [expr {[lindex [slots] 0] ne [lindex $::FREE 0]}] [focus -lastfor .drw]] {1 .drw}
    check "GK2 the first prompt is on the status line Direct Plot's prompt uses, lit, and names the analysis" \
        [list [prompt_is $::P1] [.statusbar.10 cget -state]] {1 active}
    check "GK2 ...and the CIW is told what the mode takes" \
        [said "ase: $::H — click the first net, then the second (wires or net labels); the second minus the first is plotted; ESC cancels"] 1
    click a
    check "GK3 a real click on net a makes it the first net: nothing is plotted, the mode is on its second step, and the prompt names the first net, asks for the second and says the plot is the second minus the first" \
        [list [step] [newtraces $before] [prompt_is [p2 a]]] [list {diff tran v(a)} {} 1]
    click b
    set new [newtraces $before]
    check "GK4 a real click on net b plots at once: exactly one new trace in the session's viewer, the Calculator's translation of second minus first, and the mode is over" \
        [list [llength $new] [lindex [lindex $new 0] 1] [armed]] {1 {v(b) v(a) -} {}}
    set vec [lindex [lindex $new 0] 0]
    check "GK5 the two raw vectors the viewer holds are the numbers this file wrote" \
        [list [near [vvals v(a)] $::T(a)] [near [vvals v(b)] $::T(b)]] {ok ok}
    check "GK5 ...and the new trace's values are the second net's minus the first's, computed here from those numbers" \
        [near [vvals $vec] [pd_sub $::T(b) $::T(a)]] ok
    check "GK6 the sign: the trace is b minus a and is not a minus b" \
        [list [expr {[near [vvals $vec] [pd_sub $::T(a) $::T(b)]] eq {ok} ? {REVERSED} : {b-a}}]] {b-a}
    check "GK7 the CIW says what was plotted, second minus first, and under which trace name" \
        [said "ase: $::H — plotted b minus a as trace '$vec'"] 1
    check "GK8 the canvas is the editor's again, slot for slot, and the prompt is gone" \
        [list [expr {[slots] eq $::FREE}] [string trim [prompt]] [.statusbar.10 cget -state]] {1 {} normal}
    check "GK9 the viewer shows the analysis that was read" [vtype] tran
    # the other order, for the sign
    set before [traces]
    chord_d
    click b
    click a
    set new [newtraces $before]
    check "GK10 picked the other way round, the new trace is a minus b" \
        [list [llength $new] [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(a) $::T(b)]]] {1 ok}
    # the clicks that are not the middle of a wire: a net label's own text, and
    # the end of a wire on a device's pin
    set before [traces]
    chord_d
    click label
    set s1 [step]
    click blockpin
    set new [newtraces $before]
    check "GK12 a real click on the text of a net label takes the label's net, and one on the end of a wire where it meets a block's pin takes the wire's net: the trace is e minus a" \
        [list $s1 [llength $new] [lindex [lindex $new 0] 1] [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(e) $::T(a)]] [armed]] \
        {{diff tran v(a)} 1 {v(e) v(a) -} ok {}}
    set before [traces]
    chord_d
    click b
    click srcpin
    set new [newtraces $before]
    check "GK13 a real click on the pin of a voltage source where a wire ends takes the wire's net, not the pin's current: the trace is a minus b" \
        [list [llength $new] [lindex [lindex $new 0] 1] [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(a) $::T(b)]] [armed]] \
        {1 {v(a) v(b) -} ok {}}
    check "GK11 no click of this band landed off the point it was sent to" $::MISSED {}
}

# ---------------------------------------------------------------------------
# GQ -- the slot itself, in a window nobody sized. The record of the mode holds
# the whole sentence whatever the window; what the user reads is the slot, and
# with the red field beside it holding a line the slot has room for a part of
# most sentences only. That part has to be the request.
# ---------------------------------------------------------------------------
group GQ {
    at_top
    to_design
    wm geometry . {}
    for {set i 0} {$i < 12} {incr i} { update ; after 25 }
    xschem zoom_full ; update
    check "GQ0 fixture: the design window has the size its widgets ask for, set by nobody" \
        [expr {[winfo width .] == [winfo reqwidth .] && [winfo height .] == [winfo reqheight .]}] 1
    set ::notices {}
    chord_d
    set t1 [slot_tight]
    check "GQ1 the first prompt is on the slot whole, with the red field beside it holding the short form of the entry notice" \
        [list $t1 [expr {[string trim [.statusbar.12 cget -text]] ne {}}]] [list $::P1 1]
    click a
    set t2 [slot_tight]
    check "GQ2 the second prompt does not fit that slot, and what the slot shows of it names the analysis, asks for the second net and says the plot is the second minus the first" \
        [list [shows $t2 [p2 a]] [slot_has $t2 $::H [dict get $::NEED second]]] {cut 1}
    # every refusal, on the second step: what was clicked, the sentence's kind,
    # and what the slot must still show
    set rows {}
    set want {}
    foreach {w kind} {empty nothing  body body  srcbody body  pin terminal  srcbare terminal  skipped unnamed  bus bus  a same  c absent} {
        click $w
        set t [slot_tight]
        lappend rows [list $w [slot_has $t $::H [dict get $::NEED $kind]] [step]]
        lappend want [list $w 1 {diff tran v(a)}]
    }
    check "GQ3 after each refusal -- empty space, a device body, a source's body, a bare pin of each, a wire the netlist skips, a bus, the first net again, a net the result does not hold -- what the slot shows names the analysis and says what to click instead, and the mode is still on its second step" \
        $rows $want
    key Escape
    # the analysis with the longest name, entered by the command itself: the
    # chord is rows GK1 and GU2's, the room is this row's
    to_design
    set ::notices {}
    pcall ase::plot_difference_for_current dc
    update
    set hd {Plot Difference (DC sweep)}
    click a
    set t3 [slot_tight]
    click empty
    set t4 [slot_tight]
    check "GQ4 the same holds where the analysis has the longest name of the three" \
        [list [step] [shows $t3 [p2 a $hd]] [slot_has $t3 $hd [dict get $::NEED second]] [slot_has $t4 $hd [dict get $::NEED nothing]]] \
        {{diff dc v(a)} cut 1 1}
    end_mode
    check "GQ5 no click of this band landed off the point it was sent to" $::MISSED {}
}

# ---------------------------------------------------------------------------
# GH -- the pointer resting on a device pin. Direct Plot's prompt names the
# pin a click would take there; this mode takes no pin, so its prompt must not.
# The slot is read over several turns of the prompt timer after each motion;
# the engine blanks it on the motion itself, so blank reads are left out and
# at least one read must not be blank.
# ---------------------------------------------------------------------------
group GH {
    at_top
    to_design
    chord_d
    set rows {}
    set want {}
    foreach {w pin} {pin R1:P  blockpin x1:T  srcpin V1:p  srcbare V1:m} {
        mouse_to {*}$::AT($w)
        set seen {}
        for {set i 0} {$i < 12} {incr i} {
            update ; after 30
            if {[string trim [prompt]] ne {}} { lappend seen [prompt] }
        }
        set t [pcall ase::ui::sod_terminal_at $::key {*}$::AT($w)]
        lappend rows [list $w "[dg $t instname]:[dg $t pinname]" [lsort -unique $seen]]
        lappend want [list $w $pin [list $::P1]]
    }
    check "GH1 armed on the first step, with the pointer moved onto a bare pin and onto a pin where a wire ends -- each one a pin Direct Plot's pin rule would take -- the slot shows the first prompt and nothing after it" \
        $rows $want
    check "GH2 ...and the mode is still on its first step, and no motion landed off its point" [list [step] $::MISSED] {{diff tran {}} {}}
    key Escape
}

group GO {
    at_top
    to_design
    set before [traces]
    chord_d
    click e
    lassign $::AT(a) x y
    press_at $x $y
    check "GO1 the second net's press alone plots nothing yet and leaves the canvas the mode's: the mode ends on the release, so the rest of the click cannot reach the editor" \
        [list [llength [newtraces $before]] [armed] [expr {[lindex [slots] 0] ne [lindex $::FREE 0]}]] {0 diff 1}
    # the hand drifts with the button down
    foreach d {3 9 15} {
        set p [px [expr {$x + $d}] $y]
        event generate .drw <Motion> -x [lindex $p 0] -y [lindex $p 1] -state 256
        update
    }
    release_at [expr {$x + 15}] $y
    set new [newtraces $before]
    check "GO2 the release ends the mode and plots the one trace, with no ESC: the canvas is the editor's again and the drift selected nothing" \
        [list [llength $new] [armed] [expr {[slots] eq $::FREE}] [xschem get lastsel]] {1 {} 1 0}
    check "GO3 ...a minus e" [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(a) $::T(e)]] ok
    set before [traces]
    to_design
    click a
    check "GO4 a click after the mode has ended is the editor's and plots nothing" \
        [list [llength [newtraces $before]] [armed]] {0 {}}
    xschem unselect_all
}

group GX {
    at_top
    to_design
    set before [traces]
    chord_d
    click a
    set ::notices {}
    key Escape
    check "GX1 ESC after the first net cancels: nothing is plotted, the canvas is the editor's, and the CIW says so" \
        [list [llength [newtraces $before]] [armed] [expr {[slots] eq $::FREE}] [last_said]] \
        {0 {} 1 {ase: Plot Difference cancelled — nothing plotted}}
    chord_d
    set ::notices {}
    key Escape
    check "GX2 ESC before any net cancels the same way" \
        [list [llength [newtraces $before]] [armed] [last_said]] {0 {} {ase: Plot Difference cancelled — nothing plotted}}
}

group GR {
    at_top
    to_design
    set before [traces]
    chord_d
    set rows {}
    foreach {w sentence} [list \
        empty   "$::H: click a wire or a net label for the first net (nothing under that click)" \
        body    "$::H: click a wire or a net label for the first net (R1 is not a net)" \
        srcbody "$::H: click a wire or a net label for the first net (V1 is not a net)" \
        pin     "$::H: click a wire or a net label for the first net (that was a device pin with no wire or net label on it)" \
        srcbare "$::H: click a wire or a net label for the first net (that was a device pin with no wire or net label on it)" \
        skipped "$::H: click another wire or net label for the first net (that wire has no net name in the netlist)" \
        bus     "$::H: click a one-bit wire or net label for the first net (d\[1:0\] is a bus of 2 bits)" \
        c       "$::H: click a net the run saved for the first net (c is not in the transient analysis of the loaded result), or save it (ASE-L Outputs > To Be Saved) and run again"] {
        set ::notices {}
        click $w
        lappend rows [list $w [expr {[last_said] eq "ase: $sentence"}] [prompt_is $sentence] [step] [llength [newtraces $before]]]
    }
    check "GR1 on the first step, a click on empty space, a device body, the body of a voltage source, a bare pin of each, a wire the netlist skips, a bus, and a net the result does not hold each say what to click and what was clicked, in the CIW and on the status line, plot nothing and leave the mode on the first step" \
        $rows [lmap w {empty body srcbody pin srcbare skipped bus c} {list $w 1 1 {diff tran {}} 0}]
    check "GR1 ...and no bus dialog came up" [winfo exists .asebusbits] 0
    click a
    set rows {}
    foreach {w sentence} [list \
        a       "$::H: click another net for the second (a is the first net already)" \
        label   "$::H: click another net for the second (a is the first net already)" \
        empty   "$::H: click a wire or a net label for the second net (nothing under that click)" \
        srcbody "$::H: click a wire or a net label for the second net (V1 is not a net)" \
        c       "$::H: click a net the run saved for the second net (c is not in the transient analysis of the loaded result), or save it (ASE-L Outputs > To Be Saved) and run again"] {
        set ::notices {}
        click $w
        lappend rows [list $w [expr {[last_said] eq "ase: $sentence"}] [prompt_is $sentence] [step] [llength [newtraces $before]]]
    }
    check "GR2 on the second step, the first net again -- on its wire, and on the text of another label of the same net -- empty space, a source's body and a net the result does not hold are refused at their click: the first net is kept, nothing is plotted, the mode stays on the second step" \
        $rows [lmap w {a label empty srcbody c} {list $w 1 1 {diff tran v(a)} 0}]
    click b
    check "GR3 and after all of them the next good click still plots the one trace, b minus a" \
        [list [llength [newtraces $before]] [near [vvals [lindex [lindex [newtraces $before] 0] 0]] [pd_sub $::T(b) $::T(a)]] [armed]] {1 ok {}}
    check "GR4 no click of this band landed off the point it was sent to" $::MISSED {}
}

group GS {
    at_top
    to_design
    # the session's own destination is Replace, and so is the Calculator's
    set ::calc_plot_dest replace
    check "GS0 fixture: the session's plot destination is its default, Replace" [pcall ase::ui::plot_dest $::key] replace
    set before [traces]
    chord_d ; click a ; click b
    set first [lindex [lindex [newtraces $before] 0] 0]
    set v1 [vvals $first]
    set mid [traces]
    chord_d ; click a ; click e
    set second [lindex [lindex [newtraces $mid] 0] 0]
    check "GS1 a second difference is appended, as Direct Plot appends: every trace that was there is still there" \
        [list [llength [newtraces $mid]] [expr {[llength [traces]] == [llength $mid] + 1}]] {1 1}
    check "GS2 ...and the first difference still has its data: the same result, read as the same analysis, is not loaded again under it" \
        [list [near [vvals $first] [pd_sub $::T(b) $::T(a)]] [expr {[vvals $first] eq $v1}] [near [vvals $second] [pd_sub $::T(e) $::T(a)]]] {ok 1 ok}
    # the results file written again, as a run writes it: same analyses, a new time
    pd_raw $::rawpath {tran ac dc op}
    set mid [traces]
    chord_d ; click b ; click e
    set third [lindex [lindex [newtraces $mid] 0] 0]
    set kept {}
    foreach v [list $first $second] { lappend kept [expr {[lsearch -exact [lmap t [traces] {lindex $t 0}] $v] >= 0}] }
    check "GS3 after the results file changed, the next difference loads it: that one has its data, the two plotted before it have none, and their traces are still in their strips" \
        [list [near [vvals $third] [pd_sub $::T(e) $::T(b)]] [vvals $first] [vvals $second] $kept] {ok {} {} {1 1}}
    unset -nocomplain ::calc_plot_dest
}

group GL {
    at_top
    set logf [xschem get actionlog_filename]
    if {$logf eq {} || ![file exists $logf]} {
        puts "skip: GL -- needs an action log: run with --logdir, as the display arm of the full regression does"
    } else {
        proc loglines {f} {
            set fd [open $f r] ; set body [read $fd] ; close $fd
            return [split [string trimright $body \n] \n]
        }
        proc has {lines str} {
            foreach l $lines { if {[string first $str $l] >= 0} { return 1 } }
            return 0
        }
        to_design
        set n0 [llength [loglines $logf]]
        chord_d ; click empty ; click a ; click b
        set new [lrange [loglines $logf] $n0 end]
        check "GL1 what the mode says reaches the action log as comment lines, as Direct Plot's notices do: the entry, the first net and the plot as results, a refusal as an error" \
            [list [expr {[llength $new] > 0}] \
                  [has $new "#= ase: $::H \u2014 click the first net, then the second"] \
                  [has $new "#= ase: $::H \u2014 first net a"] \
                  [has $new "#= ase: $::H \u2014 plotted b minus a as trace"] \
                  [has $new "#! ase: $::H: click a wire or a net label for the first net (nothing under that click)"]] {1 1 1 1 1}
        set comments 0
        set commands {}
        foreach l $new {
            if {[string index [string trimleft $l] 0] eq {#}} { incr comments } elseif {[string trim $l] ne {}} { lappend commands $l }
        }
        check "GL2 ...and of the lines the key, the refused click and the two nets added, every one is a comment: the gesture writes no command line of its own, so a replay runs nothing for it" \
            [list [expr {$comments > 3}] $commands] {1 {}}
    }
}

group GD {
    at_top
    to_design
    set before [traces]
    chord_d
    click a
    xschem unselect_all
    set ok [pcall hi_descend inst=x1 target=current mode=readonly]
    update
    xschem zoom_full ; update
    check "GD1 a descend between the two clicks keeps the mode: it is armed on the sheet descended into, on its second step, with the first net kept and the prompt back" \
        [list $ok [xschem get currsch] [step] [prompt_is [p2 a]]] {1 1 {diff tran v(a)} 1}
    click mid
    set new [newtraces $before]
    check "GD2 the second net, picked below, is named by its path as Direct Plot names it: one trace, x1.mid minus a, from the numbers of this file, and the mode is over" \
        [list [llength $new] [lindex [lindex $new 0] 1] [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(x1.mid) $::T(a)]] [armed]] \
        {1 {v(x1.mid) v(a) -} ok {}}
    # the key on the descended sheet; the wire of the block's port is the parent's net
    set before [traces]
    chord_d
    check "GD3 the key works on the descended sheet and finds the session of the sheet above" \
        [list [xschem get currsch] [step]] {1 {diff tran {}}}
    click port
    check "GD4 the wire of the block's input port is the parent's net e, and is taken as that" [step] {diff tran v(e)}
    set ::notices {}
    click port
    check "GD5 ...so the same wire clicked again is the first net again, and is refused" \
        [list [step] [said "ase: $::H: click another net for the second (e is the first net already)"] [llength [newtraces $before]]] \
        {{diff tran v(e)} 1 0}
    xschem go_back ; update
    xschem zoom_full ; update
    check "GD6 the first net picked below is kept across the return to the top sheet, and the slot still holds the last sentence the mode said" \
        [list [xschem get currsch] [step] [prompt_is "$::H: click another net for the second (e is the first net already)"]] {0 {diff tran v(e)} 1}
    click a
    set new [newtraces $before]
    check "GD7 the two nets picked at different levels plot one trace, a minus e" \
        [list [llength $new] [lindex [lindex $new 0] 1] [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(a) $::T(e)]]] \
        {1 {v(a) v(e) -} ok}
    no_mode
    to_design
    while {[xschem get currsch] > 0} { xschem go_back }
    xschem zoom_full ; update
    check "GD8 no click of this band landed off the point it was sent to" $::MISSED {}
}

group GU {
    at_top
    to_design
    # the two example lines, uncommented into a rc of their own
    set urc [file join $::scratch user_rc]
    set fh [open $urc w]
    set n 0
    foreach ln [split $::RCTEXT "\n"] {
        if {[regexp {^# (bind \.drw <[^>]+>\s+\{ase::plot_difference_for_current\s.*)$} $ln -> body]} { puts $fh $body ; incr n }
    }
    close $fh
    set ex {}
    foreach l [pr_lines] { if {[lindex $l 0]} { lappend ex $l } }
    check "GU0 fixture: the profile holds the two example lines, and before they are uncommented their chords do nothing here" \
        [list $n [lmap l $ex {bind .drw <[lindex $l 1]>}]] {2 {{} {}}}
    check "GU1 the scratch rc made of the two lines sources" [catch {source $urc}] 0
    # a difference from the transient first, read again after each example key
    set tb [traces]
    chord_d ; click a ; click b
    set tvec [lindex [lindex [newtraces $tb] 0] 0]
    set tv0 [near [vvals $tvec] [pd_sub $::T(b) $::T(a)]]
    set blanked {}
    set got {}
    set ::GU_AC {}
    foreach l $ex {
        lassign $l - seq word
        regexp {Key-(.)$} $seq -> ks
        set before [traces]
        key $ks [expr {$::SHIFT | $::ALT}]
        set h "Plot Difference ([pcall ase::diff_word $word])"
        set s1 [list [step] [prompt_is "$h: click the first net; ESC cancels"]]
        click a
        set s2 [prompt_is [p2 a $h]]
        click b
        set new [newtraces $before]
        set vec [lindex [lindex $new 0] 0]
        if {$word eq {ac}} {
            set want [pd_cmag $::F(b) $::F(a)]
            set ::GU_AC [list [near [vvals v(a)] [pd_mags $::F(a)]] [near [vvals v(b)] [pd_mags $::F(b)]] \
                              [expr {[near [vvals $vec] [pd_sub [pd_mags $::F(b)] [pd_mags $::F(a)]]] eq {ok} ? {MAGDIFF} : {complex}}]]
        } else {
            set want [pd_sub $::S(b) $::S(a)]
        }
        lappend got [list $word $s1 $s2 [llength $new] [near [vvals $vec] $want] [vtype] [armed]]
        lappend blanked [list $word [vvals $tvec] [expr {[lsearch -exact [lmap t [traces] {lindex $t 0}] $tvec] >= 0}]]
    }
    check "GU2 each example line, driven by its real chord and real clicks, reads its own analysis: the prompts name it, one trace is plotted, its values are this file's b minus a for that analysis (AC: the magnitude of the complex difference), and the viewer shows that analysis" \
        [lsort $got] [lsort [list \
            [list ac [list {diff ac {}} 1] 1 1 ok ac {}] \
            [list dc [list {diff dc {}} 1] 1 1 ok dc {}]]]
    check "GU3 AC: what the viewer holds for one AC net is its magnitude, and the difference trace is the magnitude of the complex difference, not the difference of those two magnitudes" \
        $::GU_AC {ok ok complex}
    check "GU4 a difference read from another analysis switches the viewer to that analysis, and the difference plotted before it from the transient then has no data: it had its values, and after the AC key and after the DC-sweep key it has none, while its trace is still in its strip" \
        [list $tv0 [lsort $blanked]] [list ok [lsort [list {ac {} 1} {dc {} 1}]]]
    foreach l $ex { bind .drw <[lindex $l 1]> {} }
}

group GV {
    at_top
    to_design
    # the viewer is left showing the DC sweep or AC by the band above
    set shown [vtype]
    set before [traces]
    chord_d ; click a ; click b
    set new [newtraces $before]
    check "GV1 with the viewer showing another analysis, Alt-Shift-D still reads the transient: the trace is the transient's b minus a and the viewer shows the transient" \
        [list [expr {$shown ne {tran}}] [llength $new] [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(b) $::T(a)]] [vtype]] {1 1 ok tran}
}

# ---------------------------------------------------------------------------
# GM -- the analyses the session has ENABLED NOW play no part. The loaded
# result holds a transient, AC and a DC sweep; the session is set to run AC
# alone, then the DC sweep alone, which is what its viewer would be shown as.
# ---------------------------------------------------------------------------
group GM {
    at_top
    to_design
    pd_raw $::rawpath {tran ac dc op}
    set st0 [pcall ase::session_state $::key]
    set got {}
    foreach only {ac dc} {
        set st [pcall ase::session_state $::key]
        set rows {}
        catch { foreach a [dict get $st analyses] { lappend rows [dict replace $a enabled [expr {[dict get $a type] eq $only ? 1 : 0}]] } }
        catch { dict set st analyses $rows }
        pcall ase::session_update $::key $st
        to_design
        set before [traces]
        chord_d
        set s [step]
        set p [prompt_is $::P1]
        click a ; click b
        set new [newtraces $before]
        lappend got [list $only [pcall ase::plot_sim_type [pcall ase::session_state $::key]] $s $p [llength $new] \
                          [near [vvals [lindex [lindex $new 0] 0]] [pd_sub $::T(b) $::T(a)]] [vtype]]
    }
    pcall ase::session_update $::key $st0
    check "GM1 with the session set to run AC alone, and then the DC sweep alone, on a loaded result that holds a transient as well, the real chord still reads the transient: the mode and its prompt name it, the trace is the transient's b minus a, and the viewer shows the transient" \
        $got [list [list ac ac {diff tran {}} 1 1 ok tran] [list dc dc {diff tran {}} 1 1 ok tran]]
    check "GM2 fixture: the session's analyses are back as they were" \
        [expr {[pcall ase::session_state $::key] eq $st0}] 1
}

# ---------------------------------------------------------------------------
# GT -- what stops the plot AFTER the second click. Each is said in one
# sentence that names the two nets, what happened and what to do; nothing is
# plotted and the mode is over. The first three happen by themselves: the
# results file deleted, or written again without the analysis, between the two
# clicks, and a net the analysis does not hold when the file's header gave no
# names to refuse it by at its click. The rest are arms nothing in this
# fixture reaches by itself, so one callee is made to answer what the arm is
# there for (with_stub), for the length of the click.
# ---------------------------------------------------------------------------
group GT {
    at_top
    to_design
    pd_raw $::rawpath {tran ac dc op}
    set h "ase: $::H"
    # what one refused plot leaves: the sentence said, no new trace, no mode,
    # the canvas the editor's
    proc gt_after {before sentence} {
        return [list [said_just $sentence] [llength [newtraces $before]] [armed] [expr {[slots] eq $::FREE}]]
    }
    set before [traces]
    set ::notices {}
    chord_d ; click a
    file delete -force $::rawpath
    click b
    check "GT1 the results file deleted between the two clicks: said with the cure, run again and press the key again" \
        [gt_after $before "$h — b minus a not plotted: the session's results file is gone; run again, then press the key again"] {1 0 {} 1}
    pd_raw $::rawpath {tran ac dc op}
    # a plot first, so the viewer holds the transient and the next row can see it kept
    to_design
    chord_d ; click a ; click b
    set shown [list [vtype] [near [vvals v(a)] $::T(a)]]
    set before [traces]
    set ::notices {}
    chord_d ; click a
    pd_raw $::rawpath {op ac}
    click b
    check "GT2 the results file written again without the analysis between the two clicks: the sentence says which analysis the results no longer hold, which they hold, and to press the key again; and the viewer still holds what it showed" \
        [list [gt_after $before "$h — b minus a not plotted: the session's results no longer hold the transient analysis (they hold operating point and AC); press the key again"] \
              $shown [list [vtype] [near [vvals v(a)] $::T(a)]]] \
        {{1 0 {} 1} {tran ok} {tran ok}}
    pd_raw $::rawpath {tran ac dc op}
    # no names to ask at the click (row PC4's case), then a net the analysis lacks
    to_design
    set before [traces]
    set ::notices {}
    chord_d
    set ::ase::ui::sod($::key,diffindex) [pcall wviewer::name_index {}]
    click a ; click c
    set own {}
    catch {
        set r [calc::ix_route [ase::diff_text tran v(a) v(c)]]
        set own [dict get [calc::plot_in_token $::key [dict get $r rpn] append] msg]
    }
    check "GT3 a net the analysis does not hold, clicked when the file's header gave no names to refuse it by: the plot refuses it in the Calculator's own sentence for that text, which names the net" \
        [list [expr {$own ne {} && [string first {vt(c)} $own] >= 0}] [gt_after $before "$h — c minus a not plotted: $own"]] {1 {1 0 {} 1}}
    # the arms reached through a stand-in
    foreach {row name body sentence} [list \
        GT4 ::wviewer::open {return 0} \
            "$h — b minus a not plotted: cannot open the waveform viewer for $::key; open it from the session's ASE-L window (the ~ button), then press the key again" \
        GT5 ::wviewer::attach_raw {return 0} \
            "$h — b minus a not plotted: the waveform viewer could not be switched to the results in $::rawpath, as happens while a run or another command is in progress; when it has finished, press the key and click the two nets again" \
        GT6 ::calc::plot_in_token {error {stand-in failure}} \
            "ase: Plot Difference — the plot failed (stand-in failure); nothing plotted. Press the key and click the two nets again, and report this line if it fails the same way" \
        GT8 ::calc::ix_route {return [dict create mode refuse rpn {} msg {stand-in refusal of the text}]} \
            "$h — b minus a not plotted: stand-in refusal of the text"] {
        to_design
        pd_raw $::rawpath {tran ac dc op}
        set before [traces]
        set ::notices {}
        chord_d ; click a
        with_stub $name $body { click b }
        set ::GTROW($row) [gt_after $before $sentence]
    }
    check "GT4 the viewer cannot be opened (wviewer::open made to answer 0): said with where to open it" $::GTROW(GT4) {1 0 {} 1}
    check "GT5 the viewer cannot be switched to the results (wviewer::attach_raw made to answer 0, on a file newer than the one it shows): said with when to try again" $::GTROW(GT5) {1 0 {} 1}
    check "GT6 the plot raises (calc::plot_in_token made to raise): the error is said, with what to do, and goes no further" $::GTROW(GT6) {1 0 {} 1}
    check "GT8 the Calculator's translator refuses the text (calc::ix_route made to refuse): its sentence is said after the two nets, and nothing is plotted" $::GTROW(GT8) {1 0 {} 1}
    # a click that cannot be read: the mode stays, on the same step
    to_design
    set before [traces]
    chord_d ; click a
    set ::notices {}
    with_stub ::calc::pick_classify {error {stand-in failure}} { click b }
    check "GT7 a click whose reading raises (calc::pick_classify made to raise) is said, with what to do, plots nothing and leaves the mode on the step it was on; the next click is read as usual" \
        [list [said_just "ase: Plot Difference — this click could not be read (stand-in failure); click again, or press ESC to leave the mode"] \
              [step] [llength [newtraces $before]]] {1 {diff tran v(a)} 0}
    click b
    check "GT7 ...and plots" [list [llength [newtraces $before]] [armed]] {1 {}}
    check "GT9 no click of this band landed off the point it was sent to" $::MISSED {}
}

group GF {
    at_top
    to_design
    pd_raw $::rawpath {op ac}
    set before [traces]
    set ::notices {}
    chord_d
    set h {Plot Difference (AC)}
    check "GF1 a result with no transient and one analysis with a wave: Alt-Shift-D reads that one, says at entry which analysis is read instead, and the prompt names it" \
        [list [step] [said {ase: Plot Difference — the loaded result has no transient analysis (it holds operating point and AC); reading its AC analysis instead}] \
              [prompt_is "$h: click the first net; ESC cancels"]] {{diff ac {}} 1 1}
    click a ; click b
    set new [newtraces $before]
    check "GF2 ...and plots that analysis's difference" \
        [list [llength $new] [near [vvals [lindex [lindex $new 0] 0]] [pd_cmag $::F(b) $::F(a)]] [vtype]] {1 ok ac}
    pd_raw $::rawpath {ac dc}
    to_design
    set before [traces]
    set ::notices {}
    chord_d
    check "GF3 a result with AC and a DC sweep and no transient: the key arms nothing, plots nothing, and names the analyses the result holds and the words to bind" \
        [list [armed] [expr {[slots] eq $::FREE}] [llength [newtraces $before]] \
              [last_said]] \
        {{} 1 0 {ase: Plot Difference — the loaded result has no transient analysis (it holds AC and DC sweep); name the analysis to read on the key's bind line: ase::plot_difference_for_current ac or dc}}
    pd_raw $::rawpath {tran ac dc op}
}

group GC {
    at_top
    to_design
    set got {}
    foreach {ks st} [list D [expr {$::LOCK | $::ALT}]  d $::ALT  d [expr {$::LOCK | $::SHIFT | $::ALT}]  D [expr {$::SHIFT | $::ALT | $::CTRL}]] {
        end_mode
        key $ks $st
        lappend got [armed]
    }
    end_mode
    check "GC1 the case of the letter as typed decides: Caps Lock with Alt types the capital and runs the key, a small d with Alt does not, Caps Lock with Shift and Alt types the small letter and does not, and a further modifier does not stop the key" \
        $got {diff {} {} diff}
    xschem unselect_all
}

group GP {
    at_top
    to_design
    set full [p2 a]
    # a window with room for the whole sentence
    wm geometry . 1800x900+10+10
    for {set i 0} {$i < 40} {incr i} { update ; if {[winfo width .drw] > 1500} break ; after 25 }
    xschem zoom_full ; update
    chord_d ; click a
    set wide [list [prompt_is $full] [shows [prompt] $full]]
    # ...and one with room for a part of it only
    wm geometry . 920x620+10+10
    for {set i 0} {$i < 40} {incr i} { update ; if {[winfo width .drw] < 1000} break ; after 25 }
    for {set i 0} {$i < 8} {incr i} { update ; after 30 }
    set t [prompt]
    set narrow [list [shows $t $full] [expr {[font measure [.statusbar.10 cget -font] $t] <= [winfo width .statusbar.10]}]]
    check "GP1 the prompt slot shows the whole sentence where the window has room for it, and where it has not, the head of it with a cut mark, at a width the slot really has" \
        [list $wide $narrow] {{1 whole} {cut 1}}
    end_mode
    wm geometry . {}
    for {set i 0} {$i < 12} {incr i} { update ; after 25 }
    xschem zoom_full ; update
}

group GE {
    at_top
    to_design
    file delete -force $::rawpath
    set ::notices {}
    chord_d
    check "GE1 no results file: the real chord arms nothing and says what to do" \
        [list [armed] [expr {[slots] eq $::FREE}] [last_said]] \
        {{} 1 {ase: Plot Difference — no simulation results yet — run first, then press the key again}}
    pd_raw $::rawpath {tran ac dc op}
    catch {wviewer::close $::key}
    pcall ase::session_close $::key
    update
    to_design
    set ::notices {}
    chord_d
    check "GE2 no session: the real chord arms nothing and says so in Direct Plot's words" \
        [list [armed] [expr {[slots] eq $::FREE}] [last_said]] \
        {{} 1 {ase: no ASE-L session for this design -- Launch ASE-L (Tools menu) or open its ngspice_state view first}}
}

group GW {
    at_top
    to_design
    set w {}
    foreach n {1 2 3 4 5 6 7 8} { if {![winfo exists .x$n]} { set w .x$n ; break } }
    catch {xschem new_schematic create_window $w [file join $::lib pdblk.sch]}
    update
    set same {}
    if {[winfo exists $w.drw]} {
        foreach seq {<Alt-Key-D> <Control-Key-4>} {
            lappend same [expr {[bind $w.drw $seq] eq [bind .drw $seq] && [bind .drw $seq] ne {}}]
        }
    }
    check "GW1 a design canvas made after the profile was sourced carries the key's binding, copied as Ctrl-4's is" \
        [list [winfo exists $w.drw] $same] {1 {1 1}}
    catch {xschem new_schematic destroy $w.drw {}}
    update
    to_design
}

}

} bigerr]} {
    puts "FAIL: UNEXPECTED ERROR -> $bigerr : FAIL"
    puts $::errorInfo
    incr fail
}

catch {rename ciw_echo {}}
if {[info commands pd_real_ciw_echo] ne {}} { catch {rename pd_real_ciw_echo ciw_echo} }

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
