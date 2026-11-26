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
#       the first one drawing, and so does one plotted after the results
#       changed: each is evaluated again on the new numbers; the plot is appended
#   GA  a real Direct Plot (Ctrl-4, a click, ESC) after a difference: the
#       difference still reads second minus first on the readout bar, in the
#       tab shown and in a tab that is not
#   GB  the same difference plotted twice: two traces, one label
#   GJ  the bench run again: the differences follow the new numbers; a net
#       the new result lacks leaves its trace in the strip, empty, with one
#       sentence, and the trace draws again when the net is back
#   GI  the label: v(<second>)-v(<first>) in the viewer's model, on the strip's
#       node token, on the readout bar and in the CIW, for the transient, the
#       DC sweep and AC (mag(...)), on a net inside a block spelled with capitals
#   GY  a viewer state with a difference in each of two tabs, saved and
#       restored, and the session closed and opened again
#   GL  what the mode says reaches the action log (needs --logdir; one `skip:`
#       without it; the display arm of the full regression and full_audit.sh
#       both run this suite with one, row PX2)
#   GD  the second net picked after a descend
#   GU  the two example lines, uncommented into a scratch rc: AC and DC sweep;
#       a difference read from another analysis leaves the one before it
#       empty, with one sentence, while the viewer shows that analysis
#   GV  the viewer showing another analysis plays no part; back on the
#       transient, the transient's earlier difference draws again
#   GM  the analyses the session has enabled now play no part
#   GT  what stops the plot after the second click, each with what to do
#   GF  the fall-back, and the refusal that names what the result holds
#   GC  Caps Lock: the case of the letter as typed decides
#   GP  the prompt whole where the window has room, cut where it has not
#   GE  no session, and no results, through the real chord
#   GW  a canvas made later carries the key, as it carries Ctrl-4
#   GZ  the X axis of the difference's strip: after the viewer's own zoom and
#       the ~ button (or a run) under Replace in multi-plot, every strip is on
#       one X window and on its own Y window, and the difference's new strip
#       has the X extent the other strips have
#   GG  the plot ~ or a finished run makes under Replace after a difference:
#       nothing is said of a trace that plot removes, the undo key brings it
#       back drawing, a difference in another subwindow or tab is still told
#       of, and so is one under Append; an expression that names another
#       expression's trace is told of that trace; a second difference
#       computed into the vector name of one the plot removed, and undo and
#       redo: each reads its own two nets under its own label, or is empty
#   GYA a difference of the AC analysis restored into a viewer that shows the
#       transient says it is an AC trace; a state loaded over an open viewer
#       is evaluated without what that viewer had on record
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
set ::T(x1.plus) {0.2 0.9 1.7 2.6 3.6}
# THE BENCH RUN AGAIN: a second run's transient, for the rows that ask whether
# a trace follows the new result (pd_raw writes it while ::RUNSEL is 2)
set ::T2(a)      {2.0 0.5 1.0 3.0 1.5}
set ::T2(b)      {0.5 4.0 2.5 1.0 3.5}
set ::T2(e)      {0.9 0.8 0.7 0.6 0.4}
set ::T2(x1.mid) {1.6 1.7 1.9 2.3 3.1}
set ::T2(x1.plus) {3.2 2.9 2.7 1.6 0.6}
set ::RUNSEL 1
# nets pd_raw leaves out of every analysis: a run that no longer saves them
set ::OMIT {}
# AC: {magnitude degrees} per point; a and b differ in phase at every point
set ::F_FREQ {1e3 1e4 1e5}
set ::F(a)      {{1.0 0} {2.0 30} {0.5 170}}
set ::F(b)      {{1.0 90} {3.0 -60} {0.5 -170}}
set ::F(e)      {{0.25 10} {0.5 20} {0.75 45}}
set ::F(x1.mid) {{1.5 -30} {0.2 60} {2.5 120}}
set ::F(x1.plus) {{0.8 45} {1.2 -20} {0.3 100}}
set ::S_SWEEP {0 1 2}
set ::S(a)      {0.0 0.5 1.0}
set ::S(b)      {1.0 0.75 0.5}
set ::S(e)      {0.3 0.2 0.1}
set ::S(x1.mid) {2.0 2.5 3.5}
set ::S(x1.plus) {1.5 1.25 0.75}
set ::NETS {a b e x1.mid x1.plus}

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
# the nets a write holds, and the transient's numbers of the run being written
proc pd_nets {} {
    set out {}
    foreach n $::NETS { if {[lsearch -exact $::OMIT $n] < 0} { lappend out $n } }
    return $out
}
proc pd_tv {n} {
    if {$::RUNSEL == 2} { return $::T2($n) }
    return $::T($n)
}
# write the session's results file with the analyses named, in that order; the
# file's time is moved forward at every write so no two writes look the same
set ::RAWCLOCK [clock seconds]
proc pd_raw {path analyses} {
    file mkdir [file dirname $path]
    set f [open $path w]
    set nets [pd_nets]
    foreach an $analyses {
        set vars {}
        set rows {}
        switch -exact -- $an {
            tran {
                lappend vars {time time}
                foreach n $nets { lappend vars [list v($n) voltage] }
                set i 0
                foreach t $::T_TIME {
                    set r [list $t]
                    foreach n $nets { lappend r [lindex [pd_tv $n] $i] }
                    lappend rows $r
                    incr i
                }
                pd_plot $f {Transient Analysis} real $vars $rows
            }
            ac {
                lappend vars {frequency frequency}
                foreach n $nets { lappend vars [list v($n) voltage] }
                set i 0
                foreach t $::F_FREQ {
                    set r [list "$t,0"]
                    foreach n $nets { lappend r [pd_cx {*}[lindex $::F($n) $i]] }
                    lappend rows $r
                    incr i
                }
                pd_plot $f {AC Analysis} complex $vars $rows
            }
            dc {
                lappend vars {v-sweep voltage}
                foreach n $nets { lappend vars [list v($n) voltage] }
                set i 0
                foreach t $::S_SWEEP {
                    set r [list $t]
                    foreach n $nets { lappend r [lindex $::S($n) $i] }
                    lappend rows $r
                    incr i
                }
                pd_plot $f {DC transfer characteristic} real $vars $rows
            }
            op {
                foreach n $nets { lappend vars [list v($n) voltage] }
                set r {}
                foreach n $nets { lappend r [lindex [pd_tv $n] 0] }
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
puts $f {N 200 100 400 100 {}}
puts $f {C {devices/lab_pin} 200 100 0 0 {name=l10 sig_type=std_logic lab=PLUS}}
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
# and `srcbare` its lower pin, which has nothing on it. `plus` is, inside the
# block's sheet, the wire of the net the sheet spells PLUS.
array set ::AT {
    a {100 0}  b {100 100}  c {100 200}  bus {100 300}  auto {100 400}
    skipped {100 500}  body {500 100}  pin {500 70}  empty {350 250}
    block {800 100}  e {800 10}
    label {489 317}  blockpin {800 60}
    srcbody {500 400}  srcpin {500 370}  srcbare {500 430}
    mid {300 0}  port {0 -80}  plus {300 100}
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
    check "FX4 fixture: the second run's transient differs from the first's: each difference the rows take is apart from the same difference of the first run at every point" \
        [list [expr {[apart [pd_sub $::T2(b) $::T2(a)] [pd_sub $::T(b) $::T(a)]] > 0.5}] \
              [expr {[apart [pd_sub $::T2(e) $::T2(a)] [pd_sub $::T(e) $::T(a)]] > 0.1}] \
              [expr {[apart [pd_sub $::T2(e) $::T2(b)] [pd_sub $::T(e) $::T(b)]] > 0.5}]] {1 1 1}
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
    check "PT6 the label a difference is shown under is the second pick, a minus sign and the first pick, each as it was picked and with no space; the transient and the DC sweep take that form, and AC wraps it in mag()" \
        [list [pcall ase::diff_label tran v(a) v(x1.PLUS)] [pcall ase::diff_label dc v(x1.mid) v(a)] \
              [pcall ase::diff_label ac v(a) v(b)]] \
        {v(x1.PLUS)-v(a) v(a)-v(x1.mid) mag(v(b)-v(a))}
    set labs {}
    catch { foreach an [dict keys [ase::diff_functions]] { lappend labs [pcall ase::diff_label $an v(a) v(b)] } }
    check "PT6 ...every analysis a difference is plotted from has a label, each names both picks, and none holds a space or a character the strip's node token cannot carry" \
        [list [expr {[llength $labs] >= 3}] \
              [lmap l $labs {expr {[string first {v(b)-v(a)} $l] >= 0 && ![regexp {[\s";\\]} $l]}}]] \
        [list 1 [lmap l $labs {expr 1}]]
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
    # The tip-of-the-day bank proves what its questions say by naming what
    # they are about. A clause of a question's proof (the word proof and an
    # opening brace, or `&&`, then `[P_...]`) is text that tests/headless/test_startup_quiz.tcl alone
    # evaluates, never a key, a menu entry or a button, so it is no door and
    # is passed over. Any other line of that file shows like any file's.
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
            if {[file tail $f] eq {startup_quiz_bank.tcl} && [regexp {^(proof \{|&& )\[P_[a-z]+ } $t]} { continue }
            lappend found [list [file tail $f] [string map [list \{ ( \} )] [regsub -all {\s+} $t { }]]]
        }
    }
    set carriers {}
    foreach n {xschem.tcl keybindings.csv actions.csv action_registry.tcl mouse_bindings.tcl callback.c scheduler.c ase_window.tcl cadence_style_rc xschemrc} {
        if {[lsearch -exact $scanned $n] < 0} { lappend carriers $n }
    }
    check "PR4 over the text files of src/ and its folders, the menus, the key table, the action registry, the stock bindings and the C sources among them, the only lines that are not comments and name the command or the mode's entry are their two definitions, the command's call of the mode, the name in its refusal, and the profile's one line: no menu entry, toolbar button or key outside the profile runs it (a clause of a tip-of-the-day proof is no door)" \
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
    foreach b {GN GK GQ GH GO GX GR GS GA GB GJ GI GY GL GD GU GV GM GT GF GC GP GE GW GZ GG GYA} {
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
# ---------------------------------------------------------------------------
# WHAT THE VIEWER SHOWS OF A TRACE: its label and its values.
# ---------------------------------------------------------------------------
# the viewer's model trace drawn from vector `vec`, and the name it is shown
# under there
proc tr_of {vec} {
    set hit {}
    catch {
        foreach G [dict get [wviewer::layout_for $::key] graphs] {
            foreach t [dict get $G traces] { if {$hit eq {} && [dict get $t vec] eq $vec} { set hit $t } }
        }
    }
    return $hit
}
proc label_of {vec} {
    set t [tr_of $vec]
    if {$t eq {}} { return NOTRACE }
    return [pcall wviewer::trace_label $t]
}
# the name the strip's own node token gives the trace drawn from `vec`: the
# engine draws a legend from that token, taking what stands in front of a `;`
# and else the token itself. Read off the graph rects of the viewer.
proc legend_of {vec} {
    if {[catch {wviewer::enter_ctx $::key} t] || ![lindex $t 0]} { return NOCTX }
    set out NOTOKEN
    catch {
        set n [xschem get graph_rects]
        for {set gi 0} {$gi < $n} {incr gi} {
            foreach tok [split [xschem getprop rect 2 $gi node] "\n"] {
                set tok [string trim [string map [list \" {} \\ {}] $tok]]
                set al $tok ; set v $tok
                regexp {^(.*);\s*(\S+)$} $tok -> al v
                if {$v eq $vec} { set out $al }
            }
        }
    }
    catch {wviewer::leave_ctx $::key $t}
    return $out
}
# is `name` a vector of the data the viewer shows (its index there, -1 for none)
proc vidx {name} {
    if {[catch {wviewer::enter_ctx $::key} t] || ![lindex $t 0]} { return NOCTX }
    set i -1
    catch {set i [xschem raw index $name]}
    catch {wviewer::leave_ctx $::key $t}
    return $i
}
# a number as the readout bar writes one (a mantissa and an engineering
# suffix), read back as a number; the text itself for anything else
proc eng_num {s} {
    if {[string is double -strict $s]} { return [expr {double($s)}] }
    if {![regexp {^([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)(f|p|n|u|m|k|Meg|G|T)$} $s -> m sfx]} { return $s }
    if {![string is double -strict $m]} { return $s }
    return [expr {$m * [dict get {f 1e-15 p 1e-12 n 1e-9 u 1e-6 m 1e-3 k 1e3 Meg 1e6 G 1e9 T 1e12} $sfx]}]
}
# THE READOUT BAR: cursor A put at `x` in the session's viewer, the bar filled
# by the viewer's own proc, and its line read off the widget: one {label
# number} pair per trace the bar names, in the bar's order. This is where a
# user reads a trace's value, and a trace with no data has no entry.
proc readout {x} {
    set top [pcall wviewer::window_for $::key]
    if {$top eq {} || [string match ERR:* $top] || ![winfo exists $top.wvreadout.a]} { return {} }
    if {[catch {wviewer::enter_ctx $::key} t] || ![lindex $t 0]} { return {} }
    catch { xschem cursor 1 1 ; xschem set cursor1_x $x }
    catch {wviewer::leave_ctx $::key $t}
    set ::wviewer::cva($::key) 1
    catch {wviewer::readout_auto_show $::key}
    update
    set out {}
    foreach item [lrange [regexp -all -inline {\S+} [$top.wvreadout.a cget -text]] 2 end] {
        set at [string last = $item]
        if {$at < 1} { continue }
        lappend out [list [string range $item 0 [expr {$at - 1}]] [eng_num [string range $item [expr {$at + 1}] end]]]
    }
    return $out
}
# A name on the bar without the cue of a trace kept on an earlier run. Since
# issue 1780 the bar names such a trace as its legend does (`v(b)-v(a)@01:02:03`),
# so that the versions of a waveform are told apart there too; the rows here
# ask for a trace by its label, and rd_cue for the cue itself.
proc rd_plain {name} {
    regsub {@(([A-Z][a-z][a-z][0-9][0-9]_)?[0-9][0-9]:[0-9][0-9]:[0-9][0-9]|earlier)$} $name {} name
    return $name
}
# what the bar reads under `label` at each of `times` (the first entry of that
# label; MISSING where the bar has none)
proc rd_at {label times} {
    set out {}
    foreach x $times {
        set v MISSING
        foreach p [readout $x] { if {[rd_plain [lindex $p 0]] eq $label} { set v [lindex $p 1] ; break } }
        lappend out $v
    }
    return $out
}
# every value the bar reads under `label` at time `x`
proc rd_all {label x} {
    set out {}
    foreach p [readout $x] { if {[rd_plain [lindex $p 0]] eq $label} { lappend out [lindex $p 1] } }
    return $out
}
# the names on the bar at time `x` that carry a kept trace's cue, cue and all
proc rd_cue {x} {
    set out {}
    foreach p [readout $x] { if {[rd_plain [lindex $p 0]] ne [lindex $p 0]} { lappend out [lindex $p 0] } }
    return $out
}
# the three times the bar is read at: two sample times of the results file and
# one halfway between two samples; and what a vector of the file reads there
set ::RT {1e-9 2.5e-9 3e-9}
proc at_rt {vals} {
    return [list [lindex $vals 1] [expr {([lindex $vals 2] + [lindex $vals 3]) / 2.0}] [lindex $vals 3]]
}
# how many times exactly this sentence was said
proc nsaid {s} {
    set n 0
    foreach m $::notices { if {$m eq $s} { incr n } }
    return $n
}
# A REAL DIRECT PLOT: the profile's Ctrl-4 on the design canvas, a real click
# on each point named, and ESC, which plots what was clicked. Answers the mode
# the key armed.
proc dplot {args} {
    key 4 $::CTRL
    set m [armed]
    foreach w $args { click $w }
    key Escape
    return $m
}
# every load of results into a viewer, counted where the load is made
set ::NATT 0
proc att_seen {args} { incr ::NATT }
catch {trace add execution ::ase::attach_dbs enter att_seen}
# the session set to run these analyses and no other, as the ticks of its
# ASE-L window set it; answers the analysis its viewer is then shown as
proc run_only {types} {
    set st [pcall ase::session_state $::key]
    set rows {}
    catch { foreach a [dict get $st analyses] { lappend rows [dict replace $a enabled [expr {[dict get $a type] in $types ? 1 : 0}]] } }
    catch { dict set st analyses $rows }
    pcall ase::session_update $::key $st
    return [pcall ase::plot_sim_type [pcall ase::session_state $::key]]
}
# into the block's sheet from the top one, and what the level then is
proc into_block {} {
    xschem unselect_all
    pcall hi_descend inst=x1 target=current mode=readonly
    update
    xschem zoom_full ; update
    return [xschem get currsch]
}
# a viewer with no trace in it, on the results it has
proc clean_viewer {} {
    catch {wviewer::clear_all $::key}
    update
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
    check "GK7 the CIW says what was plotted, second minus first, and the label the trace is shown under" \
        [said_just "ase: $::H — plotted b minus a as trace 'v(b)-v(a)'"] 1
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
    # the bench run again: the results file written again, as a run writes it,
    # with a second run's numbers
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    set mid [traces]
    chord_d ; click b ; click e
    set third [lindex [lindex [newtraces $mid] 0] 0]
    set kept {}
    foreach v [list $first $second] { lappend kept [expr {[lsearch -exact [lmap t [traces] {lindex $t 0}] $v] >= 0}] }
    check "GS3 after the bench was run again, the next difference loads the new result: that one reads the second run's numbers, and the two plotted before it, still in their strips, are evaluated again on them: each is the second run's second minus first and neither is what it was" \
        [list [near [vvals $third] [pd_sub $::T2(e) $::T2(b)]] [near [vvals $first] [pd_sub $::T2(b) $::T2(a)]] \
              [near [vvals $second] [pd_sub $::T2(e) $::T2(a)]] $kept [expr {[vvals $first] eq $v1 ? {OLD} : {new}}]] {ok ok ok {1 1} new}
    set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    unset -nocomplain ::calc_plot_dest
}

# ---------------------------------------------------------------------------
# GA -- A REAL DIRECT PLOT AFTER A DIFFERENCE (issue 1734). Direct Plot attaches
# the session's results to the viewer again, and an attach reads the file anew:
# the vector a difference was computed into goes with the old read. The trace
# has to be evaluated again, in the tab shown and in every other tab. What is
# read is the readout bar, where a user reads a value: a trace with no data has
# no entry there.
# ---------------------------------------------------------------------------
group GA {
    at_top
    to_design
    clean_viewer
    set ::RUNSEL 1 ; set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set st0 [pcall ase::session_state $::key]
    check "GA0 fixture: the session is set to run the operating point and the transient, so a Direct Plot shows its viewer the transient" \
        [run_only {op tran}] tran
    set before [traces]
    chord_d ; click a ; click b
    set dvec [lindex [lindex [newtraces $before] 0] 0]
    set dlab [label_of $dvec]
    set want [at_rt [pd_sub $::T(b) $::T(a)]]
    check "GA0 fixture: before any Direct Plot the readout bar, its cursor put at two sample times and at one time halfway between two samples, reads the difference as b minus a from the numbers of this file" \
        [near [rd_at $dlab $::RT] $want 2e-3] ok
    set mid [traces]
    set n0 $::NATT
    set m [dplot e]
    set new [newtraces $mid]
    check "GA1 a real Direct Plot -- the profile's Ctrl-4 on the design canvas, a real click on net e, ESC -- arms Direct Plot's mode, plots the one net as a plain trace, and loads the session's results into the viewer once more" \
        [list $m [llength $new] [lindex [lindex $new 0] 0] [expr {$::NATT - $n0}]] {plot 1 v(e) 1}
    check "GA2 after it the difference still draws: the bar reads b minus a at the same three times, and every point of its vector is b minus a" \
        [list [near [rd_at $dlab $::RT] $want 2e-3] [near [vvals $dvec] [pd_sub $::T(b) $::T(a)]]] {ok ok}
    check "GA2 ...beside the net just plotted, which the bar reads from this file's numbers" \
        [near [rd_at v(e) $::RT] [at_rt $::T(e)] 2e-3] ok
    set n0 $::NATT
    set nt [llength [traces]]
    set m [dplot a b]
    check "GA3 a second Direct Plot, of two nets in one press, loads the results once more and the difference still reads b minus a" \
        [list $m [expr {[llength [traces]] - $nt}] [expr {$::NATT - $n0}] [near [rd_at $dlab $::RT] $want 2e-3]] {plot 2 1 ok}
    # a tab that is not shown: the difference stays in the first tab, a second
    # tab is opened and takes a Direct Plot, and the first tab is shown again
    set id1 [pcall wviewer::tab_id $::key]
    set id2 [pcall wviewer::new_tab $::key]
    update
    set n0 $::NATT
    set m [dplot e]
    set in2 [lmap t [traces] {lindex $t 0}]
    pcall wviewer::select_tab $id1 $::key
    update
    check "GA4 with the difference in a tab that is not shown, a Direct Plot into another tab loads the results once more; shown again, the first tab's difference still reads b minus a" \
        [list [expr {$id2 ne {} && $id2 ne $id1}] $m $in2 [expr {$::NATT - $n0}] \
              [near [rd_at $dlab $::RT] $want 2e-3] [near [vvals $dvec] [pd_sub $::T(b) $::T(a)]]] {1 plot v(e) 1 ok ok}
    pcall wviewer::close_tab $id2 $::key
    update
    pcall ase::session_update $::key $st0
    check "GA5 fixture: the second tab is closed, the session's analyses are back as they were, and no click of this band landed off its point" \
        [list [pcall wviewer::tab_count $::key] [expr {[pcall ase::session_state $::key] eq $st0}] $::MISSED] {1 1 {}}
}

# ---------------------------------------------------------------------------
# GB -- the same difference plotted twice: two traces, each with a vector of
# its own, under the one label; the viewer needs no label to be unique.
# ---------------------------------------------------------------------------
group GB {
    at_top
    to_design
    clean_viewer
    pd_raw $::rawpath {tran ac dc op}
    set before [traces]
    chord_d ; click a ; click b
    chord_d ; click a ; click b
    set vecs [lmap t [newtraces $before] {lindex $t 0}]
    check "GB1 the same difference plotted twice is two traces, each computed into a vector of its own, and both are shown under the one label" \
        [list [llength $vecs] [llength [lsort -unique $vecs]] [lmap v $vecs {label_of $v}]] {2 2 {v(b)-v(a) v(b)-v(a)}}
    check "GB2 ...the readout bar names the label twice, and reads b minus a under each" \
        [lmap x {1e-9 3e-9} w [list [lindex [pd_sub $::T(b) $::T(a)] 1] [lindex [pd_sub $::T(b) $::T(a)] 3]] {near [rd_all {v(b)-v(a)} $x] [list $w $w] 2e-3}] {ok ok}
}

# ---------------------------------------------------------------------------
# GJ -- THE BENCH RUN AGAIN. A new result of the same bench: every difference
# is evaluated again on it, as a plain trace shows the new data. When a net of
# the expression is not in the new result the trace stays in its strip, empty,
# and one sentence says which trace, what is missing and what to do; it is not
# said again while nothing changes, and the trace draws again when the net is
# back. Two doors load a new result: a Direct Plot after the run, and the plot
# a finished run makes itself.
# ---------------------------------------------------------------------------
group GJ {
    at_top
    to_design
    clean_viewer
    set ::RUNSEL 1 ; set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set st0 [pcall ase::session_state $::key]
    set shown [run_only {op tran}]
    set before [traces]
    chord_d ; click a ; click b
    chord_d ; click a ; click e
    lassign [lmap t [newtraces $before] {lindex $t 0}] d1 d2
    set l1 [label_of $d1] ; set l2 [label_of $d2]
    check "GJ0 fixture: two differences read the first run, b minus a and e minus a, and the second run's two differences are apart from the first run's by far more than the bar's rounding at each of the three times" \
        [list $shown [near [rd_at $l1 $::RT] [at_rt [pd_sub $::T(b) $::T(a)]] 2e-3] [near [rd_at $l2 $::RT] [at_rt [pd_sub $::T(e) $::T(a)]] 2e-3] \
              [expr {[apart [at_rt [pd_sub $::T2(b) $::T2(a)]] [at_rt [pd_sub $::T(b) $::T(a)]]] > 0.5}] \
              [expr {[apart [at_rt [pd_sub $::T2(e) $::T2(a)]] [at_rt [pd_sub $::T(e) $::T(a)]]] > 0.5}]] {tran ok ok 1 1}
    # the bench run again, then a Direct Plot
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    set m [dplot e]
    check "GJ1 the bench run again -- the results file written again with a second run's numbers -- and a real Direct Plot after it: each difference is evaluated again on the new result: the bar and every point of its vector read the second run's second minus first" \
        [list $m [near [rd_at $l1 $::RT] [at_rt [pd_sub $::T2(b) $::T2(a)]] 2e-3] [near [vvals $d1] [pd_sub $::T2(b) $::T2(a)]] \
              [near [rd_at $l2 $::RT] [at_rt [pd_sub $::T2(e) $::T2(a)]] 2e-3] [near [vvals $d2] [pd_sub $::T2(e) $::T2(a)]]] {plot ok ok ok ok}
    # ...and the plot a finished run makes itself: the session's Outputs hold
    # one row to plot, net b, and the destination is Append
    set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    set st [pcall ase::session_state $::key]
    catch { dict set st outputs [list [dict create name B expr b save 1 plot 1]] }
    catch { dict set st plot_dest append }
    pcall ase::session_update $::key $st
    set n0 $::NATT
    set nt [llength [traces]]
    pcall ase::ui::auto_plot $::key
    update
    check "GJ2 run again with the first run's numbers, and the plot a finished run makes by itself (one Outputs row, destination Append): it loads the results once, adds its trace, and both differences follow the result back" \
        [list [expr {$::NATT - $n0}] [expr {[llength [traces]] - $nt}] \
              [near [rd_at $l1 $::RT] [at_rt [pd_sub $::T(b) $::T(a)]] 2e-3] [near [rd_at $l2 $::RT] [at_rt [pd_sub $::T(e) $::T(a)]] 2e-3]] {1 1 ok ok}
    # a net of one expression is gone from the new result
    set gone "wviewer: trace 'v(b)-v(a)' is empty: v(b) is not in the results the viewer now shows (the transient analysis of [file tail $::rawpath]); save it in ASE-L (Outputs > To Be Saved) and run again, and the trace draws again"
    set ::OMIT {b}
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    set m [dplot e]
    check "GJ3 run again with net b no longer in the result, then a real Direct Plot: the difference b minus a stays in its strip and is empty -- no entry on the readout bar, no vector in the viewer's data -- and one sentence, said once, names the trace, the net the result lacks and what to do" \
        [list $m [expr {[lsearch -exact [lmap t [traces] {lindex $t 0}] $d1] >= 0}] [rd_at $l1 {1e-9}] [vidx $d1] [nsaid $gone]] {plot 1 MISSING -1 1}
    check "GJ3 ...while the difference e minus a, whose two nets the result holds, still reads" \
        [near [rd_at $l2 $::RT] [at_rt [pd_sub $::T(e) $::T(a)]] 2e-3] ok
    set ::notices {}
    set m [dplot a]
    check "GJ4 a further Direct Plot on the same result leaves it so and does not say the sentence again" \
        [list $m [rd_at $l1 {1e-9}] [nsaid $gone] [llength [lsearch -all -glob $::notices {wviewer: trace * is empty*}]]] {plot MISSING 0 0}
    # a second tab while the first tab's difference has no vector in the data:
    # a difference plotted there must not be handed that trace's vector name
    set idA [pcall wviewer::tab_id $::key]
    set idB [pcall wviewer::new_tab $::key]
    update
    set bt [traces]
    chord_d ; click a ; click e
    set nv [lindex [lindex [newtraces $bt] 0] 0]
    pcall wviewer::select_tab $idA $::key
    update
    pcall wviewer::close_tab $idB $::key
    update
    check "GJ7 a difference plotted in a second tab while the first tab's empty difference has no vector is computed into a vector of another name than either trace of the first tab" \
        [list [expr {$idB ne {} && $idB ne $idA}] [expr {$nv ne {}}] [expr {$nv ne $d1 && $nv ne $d2}] [pcall wviewer::tab_count $::key]] {1 1 1 1}
    set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    set m [dplot e]
    check "GJ5 run again with net b back, then a real Direct Plot: the difference b minus a draws again, with the numbers of that result, and nothing is said about an empty trace" \
        [list $m [near [rd_at $l1 $::RT] [at_rt [pd_sub $::T(b) $::T(a)]] 2e-3] [near [vvals $d1] [pd_sub $::T(b) $::T(a)]] \
              [llength [lsearch -all -glob $::notices {wviewer: trace * is empty*}]]] {plot ok ok 0}
    pcall ase::session_update $::key $st0
    check "GJ6 fixture: the session is back as it was, and no click of this band landed off its point" \
        [list [expr {[pcall ase::session_state $::key] eq $st0}] $::MISSED] {1 {}}
}

# ---------------------------------------------------------------------------
# GI -- THE LABEL (the user, 2026-11-23: "the waveform name needs to be
# v(x1.PLUS)-v(x1.MINUS) and not expr1. expr1 is meaningless to the user").
# The second pick, a minus sign, the first pick; each net spelled as Direct
# Plot names that net in that result. Read where the viewer keeps it (the
# model), where the legend is drawn from (the strip's node token), where a
# value is read (the readout bar) and in the CIW. The net is inside a block
# and the sheet spells it with capitals; the results file, as a simulator
# writes one, spells it with small letters.
# ---------------------------------------------------------------------------
group GI {
    at_top
    to_design
    clean_viewer
    set ::RUNSEL 1 ; set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set st0 [pcall ase::session_state $::key]
    set shown [run_only {op tran}]
    set had [info exists ::sim_case_mode]
    if {$had} { set mode0 $::sim_case_mode }
    set ::sim_case_mode preserve
    set held [pcall ase::diff_names $::rawpath tran]
    check "GI0 fixture: the session writes a picked net in the sheet's own letter case, and the results file spells the block's inner net with small letters only" \
        [list $shown [pcall ase::ui::sod_case_mode $::key] [expr {[lsearch -exact $held v(x1.plus)] >= 0}] [expr {[lsearch -exact $held v(x1.PLUS)] >= 0}]] {tran preserve 1 0}
    set L {v(x1.PLUS)-v(a)}
    # the transient, by the real chord: first net a on the top sheet, second
    # the net PLUS inside the block
    set before [traces]
    set ::notices {}
    chord_d ; click a
    set lvl [into_block]
    click plus
    set new [newtraces $before]
    set vec [lindex [lindex $new 0] 0]
    at_top
    check "GI1 the transient difference of a net inside a block minus a net of the top sheet is one trace, and its label in the viewer's model is v(<second>)-v(<first>): the block's path, the sheet's capitals, no space" \
        [list $lvl [llength $new] [label_of $vec]] [list 1 1 $L]
    check "GI2 the strip's node token, which the legend is drawn from, carries that label in front of the vector; the vector behind it has a legal vector name and is in the viewer's data" \
        [list [legend_of $vec] [regexp {^[A-Za-z_][A-Za-z0-9_]*$} $vec] [expr {[vidx $vec] >= 0}]] [list $L 1 1]
    check "GI3 the readout bar names the trace by that label and reads x1.plus minus a under it" \
        [near [rd_at $L $::RT] [at_rt [pd_sub $::T(x1.plus) $::T(a)]] 2e-3] ok
    check "GI4 the CIW says what was plotted, second minus first, as the trace of that label" \
        [said_just "ase: $::H — plotted x1.PLUS minus a as trace '$L'"] 1
    # the signal browser, whose lower pane lists the vectors of the result by
    # name: opened, read again, and its pairs of {label, vector} looked through
    # for the difference's vector
    pcall wviewer::browser_toggle 1 $::key
    update
    pcall wviewer::browser_refresh $::key 1
    update
    set listed {}
    set plain {}
    catch {
        foreach p $::wviewer::browsersea($::key) {
            if {[lindex $p 1] eq $vec} { lappend listed [lindex $p 0] }
            if {[lindex $p 1] eq {v(a)}} { lappend plain [lindex $p 0] }
        }
    }
    check "GI8 the signal browser's lower pane lists the difference's vector once, under that label, beside the nets of the result under theirs" \
        [list $listed $plain] [list [list $L] a]
    pcall wviewer::browser_toggle 0 $::key
    update
    # Direct Plot's own name for the same net of the same result
    to_design
    set mid [traces]
    set lvl [into_block]
    set m [dplot plus]
    at_top
    set dpl {}
    foreach t [newtraces $mid] { lappend dpl [label_of [lindex $t 0]] }
    check "GI5 a real Direct Plot of the same net, from inside the block, names its trace v(x1.PLUS), and the difference's label opens with that very name and a minus sign: the net is spelled as Direct Plot spells it in this result" \
        [list $m $dpl [expr {[llength $dpl] == 1 && [string first "[lindex $dpl 0]-" [label_of $vec]] == 0}]] {plot v(x1.PLUS) 1}
    # the DC sweep and AC, entered by the command's word
    set got {}
    foreach {word wlab wantv} [list dc $L [pd_sub $::S(x1.plus) $::S(a)]  ac "mag($L)" [pd_cmag $::F(x1.plus) $::F(a)]] {
        to_design
        set before [traces]
        set ::notices {}
        pcall ase::plot_difference_for_current $word
        update
        click a
        into_block
        click plus
        set new [newtraces $before]
        set vec [lindex [lindex $new 0] 0]
        at_top
        lappend got [list $word [llength $new] [label_of $vec] [legend_of $vec] [regexp {^[A-Za-z_][A-Za-z0-9_]*$} $vec] \
                          [said_just "ase: Plot Difference ([pcall ase::diff_word $word]) — plotted x1.PLUS minus a as trace '$wlab'"] \
                          [near [vvals $vec] $wantv] [vtype]]
    }
    check "GI6 the DC sweep's difference takes the same form and AC's, which is the magnitude of the complex difference, is that form inside mag(): in the model, on the node token and in the CIW, each over a legal vector name and with its analysis's values" \
        $got [list [list dc 1 $L $L 1 1 ok dc] [list ac 1 "mag($L)" "mag($L)" 1 1 ok ac]]
    if {$had} { set ::sim_case_mode $mode0 } else { unset -nocomplain ::sim_case_mode }
    pcall ase::session_update $::key $st0
    check "GI7 fixture: the case mode and the session are back as they were, and no click of this band landed off its point" \
        [list [pcall ase::ui::sod_case_mode $::key] [expr {[pcall ase::session_state $::key] eq $st0}] $::MISSED] {fold 1 {}}
}

# ---------------------------------------------------------------------------
# GY -- SAVED AND RESTORED. A viewer state with a difference in each of two
# tabs: closed and restored, and then the session saved to a file, closed and
# opened again. Each difference is drawn again under its label, with its
# values; the tab that was not the active one too, once it is shown.
# ---------------------------------------------------------------------------
group GY {
    at_top
    to_design
    clean_viewer
    set ::RUNSEL 1 ; set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set st0 [pcall ase::session_state $::key]
    set shown [run_only {op tran}]
    set before [traces]
    chord_d ; click a ; click b
    set v1 [lindex [lindex [newtraces $before] 0] 0]
    set id1 [pcall wviewer::tab_id $::key]
    set id2 [pcall wviewer::new_tab $::key]
    update
    set before [traces]
    chord_d ; click a ; click e
    set v2 [lindex [lindex [newtraces $before] 0] 0]
    set w1 [at_rt [pd_sub $::T(b) $::T(a)]]
    set w2 [at_rt [pd_sub $::T(e) $::T(a)]]
    check "GY0 fixture: a difference b minus a in the first tab and e minus a in a second one, which is the tab shown; the session's viewer shows the transient" \
        [list $shown [expr {$id2 ne {} && $id2 ne $id1}] [pcall wviewer::tab_count $::key] [near [rd_at [label_of $v2] $::RT] $w2 2e-3]] {tran 1 2 ok}
    # what the tab shown holds of the difference whose postfix is `rpn`: its
    # label in the model and on the node token, and the bar's reading under
    # the label the model gives it
    proc gy_shows {rpn want} {
        set vec {}
        foreach t [traces] { if {[lindex $t 1] eq $rpn} { set vec [lindex $t 0] } }
        if {$vec eq {}} { return NOTRACE }
        return [list [label_of $vec] [legend_of $vec] [near [rd_at [label_of $vec] $::RT] $want 2e-3]]
    }
    proc gy_tab {i} {
        set id {}
        catch {set id [dict get [lindex [wviewer::tab_records $::key] $i] id]}
        pcall wviewer::select_tab $id $::key
        update
    }
    pcall ase::ui::viewer_snapshot $::key
    pcall wviewer::close $::key
    update
    set closed [pcall wviewer::window_for $::key]
    set rc [pcall ase::ui::viewer_restore $::key]
    update
    check "GY1 the viewer's state taken, its window closed and the state restored: the tab that was shown draws its difference again under the same label, with its values" \
        [list $closed $rc [pcall wviewer::tab_count $::key] [gy_shows {v(e) v(a) -} $w2]] [list {} 1 2 [list {v(e)-v(a)} {v(e)-v(a)} ok]]
    gy_tab 0
    check "GY2 ...and so does the tab that was not shown, once it is" \
        [gy_shows {v(b) v(a) -} $w1] [list {v(b)-v(a)} {v(b)-v(a)} ok]
    # the session saved to a file, closed with its viewer, and opened again
    set sf [file join $::scratch gy.state]
    pcall ase::ui::viewer_snapshot $::key
    set saved [pcall ase::state_save $sf [pcall ase::session_state $::key]]
    pcall wviewer::close $::key
    pcall ase::session_close $::key
    update
    set gone [list [pcall wviewer::window_for $::key] [pcall ase::session_exists $::key]]
    set k2 [pcall ase::session_open $::key $sf]
    set rc [pcall ase::ui::viewer_restore $::key]
    update
    check "GY3 the session saved to a state file, closed with its viewer, opened again from the file and its viewer restored: the tab that was shown when it was saved draws its difference under its label, with its values" \
        [list [file isfile $sf] $gone [expr {$k2 eq $::key}] $rc [gy_shows {v(b) v(a) -} $w1]] [list 1 {{} 0} 1 1 [list {v(b)-v(a)} {v(b)-v(a)} ok]]
    gy_tab 1
    check "GY4 ...and the other tab its own" [gy_shows {v(e) v(a) -} $w2] [list {v(e)-v(a)} {v(e)-v(a)} ok]
    # leave what the bands after this one start from: one tab, and the session
    # this suite made for the sheet
    catch {wviewer::close $::key}
    pcall ase::session_close $::key
    update
    set ::key [pcall ase::new_session pdlib pd_top schematic]
    set st [pcall ase::session_state $::key]
    catch { dict set st rundir $::rundir }
    pcall ase::session_update $::key $st
    at_top
    to_design
    check "GY5 fixture: the session is the one found from the sheet again, with the results file this suite writes, and no click of this band landed off its point" \
        [list [lindex [pcall ase::session_for_current] 0] [pcall ase::last_rawfile $::key] $::MISSED] [list $::key $::rawpath {}]
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
    clean_viewer
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
    set ::GU_TVEC $tvec
    set told {}
    set wtold {}
    foreach l $ex {
        lassign $l - seq word
        regexp {Key-(.)$} $seq -> ks
        set before [traces]
        set ::notices {}
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
        lappend told [list $word [nsaid "wviewer: trace 'v(b)-v(a)' is empty: it was computed on the transient analysis and the viewer now shows the [pcall ase::diff_word $word] analysis of [file tail $::rawpath]; it draws again when the viewer shows the transient analysis"]]
        lappend wtold [list $word [expr {[llength $told] == 1 ? 1 : 0}]]
    }
    check "GU2 each example line, driven by its real chord and real clicks, reads its own analysis: the prompts name it, one trace is plotted, its values are this file's b minus a for that analysis (AC: the magnitude of the complex difference), and the viewer shows that analysis" \
        [lsort $got] [lsort [list \
            [list ac [list {diff ac {}} 1] 1 1 ok ac {}] \
            [list dc [list {diff dc {}} 1] 1 1 ok dc {}]]]
    check "GU3 AC: what the viewer holds for one AC net is its magnitude, and the difference trace is the magnitude of the complex difference, not the difference of those two magnitudes" \
        $::GU_AC {ok ok complex}
    check "GU4 a difference read from another analysis switches the viewer to that analysis, and the difference plotted before it from the transient then has no data: it had its values, and after the AC key and after the DC-sweep key it has none, while its trace is still in its strip" \
        [list $tv0 [lsort $blanked]] [list ok [lsort [list {ac {} 1} {dc {} 1}]]]
    check "GU5 ...and one sentence says so when it stops drawing: which trace, the analysis it was computed on, the analysis the viewer now shows and of which file, and that it draws again when the viewer shows its own; the sentence is not said a second time while the trace stays empty" \
        [list [llength $told] $told] [list 2 $wtold]
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
    check "GV2 ...and with the viewer back on the transient, the transient difference that the other analyses left empty draws again: b minus a" \
        [list [expr {[info exists ::GU_TVEC] && $::GU_TVEC ne {}}] [near [vvals $::GU_TVEC] [pd_sub $::T(b) $::T(a)]]] {1 ok}
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
    # a plot that was refused after its label was handed to the viewer must
    # not leave the label waiting for the next expression trace of that window
    set before [traces]
    set err [pcall wviewer::add_trace $::key 0 {v(a) 2 *}]
    update
    set nv [lindex [lindex [newtraces $before] 0] 0]
    check "GT10 after the refused plots above, one of them refused when the label was already armed, an expression added through the Add Trace door with no name is named by the viewer: its label is its vector's name, not a difference's" \
        [list $err [regexp {^expr[0-9]+$} $nv] [expr {[label_of $nv] eq $nv}]] {{} 1 1}
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
    ## 64 is Super (Mod4). Control is the one further modifier that is spoken for: issue 1769
    ## made Ctrl-Alt-Shift-D the selection dim's toggle, and the profile carries a
    ## <Control-Alt-Key-D> line that hands that chord to the canvas (the last leg).
    set ::selection_dim 0
    foreach {ks st} [list D [expr {$::LOCK | $::ALT}]  d $::ALT  d [expr {$::LOCK | $::SHIFT | $::ALT}]  D [expr {$::SHIFT | $::ALT | 64}]  D [expr {$::SHIFT | $::ALT | $::CTRL}]] {
        end_mode
        key $ks $st
        lappend got [armed]
    }
    lappend got $::selection_dim
    set ::selection_dim 0
    end_mode
    check "GC1 the case of the letter as typed decides: Caps Lock with Alt types the capital and runs the key, a small d with Alt does not, Caps Lock with Shift and Alt types the small letter and does not, and a further modifier (Super) does not stop the key; with Control it is another key, the selection dim's toggle, and arms nothing" \
        $got {diff {} {} diff {} 1}
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

# ---------------------------------------------------------------------------
# GZ -- THE X AXIS OF THE DIFFERENCE'S STRIP (the user, 2026-11-23, on the
# bundled bench: "the x-axis extent for this new strip ... is wrong - it's from
# something negative to more than 400 us while the rest of the strips are
# using 0 to 200 us"; in the screenshot the bottom strip had that X window too,
# and the Y scale of the top strip's signal).
#
# What gives it: the viewer's own zoom (Ctrl-z, the wheel) stores a window on
# every strip; `~` or a re-run under Replace, in multi-plot, then handed the
# bottom strip -- the first Outputs row -- the window stored on the old top
# strip, the other rows came back fitted, and the difference's new strip
# joined the one stored window. Every door here is the real one: a real click
# on the `~` button of the session's ASE-L window, Ctrl-z and f as key events
# on the viewer canvas, the chord and two clicks for the difference, and for
# the re-run the results file written again and the entry a finished run
# schedules. Every strip's window is read off its rect. The three Outputs rows
# are nets whose numbers this file wrote, the last row the smallest, so a
# strip drawn in another's Y window does not hold its own trace.
#
# Red on the product before the repair: GZ2 to GZ4 and GZ6 to GZ8. Measured
# 2026-11-24, each break reverted to green: ase::ui::auto_plot with no
# wviewer::sw_stored_give reddens GZ2, GZ3, GZ4, GZ6 and GZ7; stored views
# given by place and not by traces (wviewer::sw_stored_apply) redden GZ6 and
# GZ7. GZ8 is red only with that hand-back gone AND the strip a clear leaves
# keeping its whole view (wviewer::sw_clear_graphs), which is the product
# before the repair: either half alone repairs the View > Fit case.
# ---------------------------------------------------------------------------
# every strip of the viewer, top first: {x1 x2 y1 y2} off its rect
proc gz_axes {} {
    if {[catch {wviewer::enter_ctx $::key} t] || ![lindex $t 0]} { return NOCTX }
    set out {}
    catch {
        set n [xschem get graph_rects]
        for {set gi 0} {$gi < $n} {incr gi} {
            set r {}
            foreach k {x1 x2 y1 y2} {
                set v [xschem getprop rect 2 $gi $k]
                lappend r [expr {[string is double -strict $v] ? double($v) : $v}]
            }
            lappend out $r
        }
    }
    catch {wviewer::leave_ctx $::key $t}
    return $out
}
# the distinct X windows among strips' axes
proc gz_xs {axes} { return [lsort -unique [lmap r $axes {lrange $r 0 1}]] }
# each strip's vectors, top first
proc gz_vecs {} {
    set out {}
    catch { foreach G [dict get [wviewer::layout_for $::key] graphs] { lappend out [lmap t [dict get $G traces] {dict get $t vec}] } }
    return $out
}
# does the Y window of one strip's axes reach from the smallest to the largest of `vals`
proc gz_holds {ax vals} {
    if {[catch {
        set s [lsort -real $vals]
        set r [expr {[lindex $ax 2] <= [lindex $s 0] && [lindex $s end] <= [lindex $ax 3]}]
    } e]} { return "ERR:$e" }
    return $r
}
# `n` real presses of a key on the viewer canvas, the pointer in the middle of strip gi
proc gz_vkeys {gi n ks st} {
    if {[catch {
        set w [wviewer::window_for $::key].drw
        lassign [lindex [wviewer::strip_bands_px $w] $gi] x1 y1 x2 y2
        set px [expr {int(($x1 + $x2) / 2)}]
        set py [expr {int(($y1 + $y2) / 2)}]
        update
        for {set i 0} {$i < 40} {incr i} {
            focus -force $w ; update
            if {[focus -displayof $w] eq $w} break
            after 25
        }
        event generate $w <Motion> -x $px -y $py -when now
        for {set i 0} {$i < $n} {incr i} {
            event generate $w <KeyPress> -keysym $ks -state $st -x $px -y $py -when now
            event generate $w <KeyRelease> -keysym $ks -state $st -x $px -y $py -when now
        }
        update
    } e]} { return "ERR:$e" }
    return {}
}
# a real click on the `~` button of the session's ASE-L window
proc gz_tilde {} {
    set b [pcall ase::ui::window_for $::key].strip.plot
    if {![winfo exists $b]} { return NOBUTTON }
    event generate $b <Enter> -x 5 -y 5
    event generate $b <ButtonPress-1> -x 5 -y 5
    event generate $b <ButtonRelease-1> -x 5 -y 5
    event generate $b <Leave>
    for {set i 0} {$i < 20} {incr i} { update ; after 25 }
    return {}
}
group GZ {
    at_top
    catch {xschem load $::top}
    xschem zoom_full ; update
    set ::RUNSEL 1 ; set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    # band GE closed the session and its viewer: a new session on the same
    # sheet, bound to it and to the results file as the first one was (FX2)
    catch {wviewer::close $::key}
    pcall ase::session_close $::key
    set ::key [pcall ase::new_session pdlib pd_top schematic]
    set st [pcall ase::session_state $::key]
    catch { dict set st rundir $::rundir }
    pcall ase::session_update $::key $st
    to_design
    check "GZ0 fixture: a session is bound to the sheet again, is the one found from it, and names the results file this suite writes" \
        [list [lindex [pcall ase::session_for_current] 0] [pcall ase::last_rawfile $::key]] [list $::key $::rawpath]
    set shown [run_only {op tran}]
    set st [pcall ase::session_state $::key]
    catch { dict set st outputs [list [dict create name B expr b save 1 plot 1] \
                                      [dict create name A expr a save 1 plot 1] \
                                      [dict create name E expr e save 1 plot 1]] }
    pcall ase::session_update $::key $st
    if {[pcall ase::ui::window_for $::key] eq {}} { pcall ase::ui::open $::key pdlib pd_top schematic }
    update
    pcall wviewer::open $::key
    update
    pcall wviewer::set_plot_mode multi $::key
    set tl [gz_tilde]
    set fit [gz_axes]
    set vecs [gz_vecs]
    check "GZ0 fixture: with the session's plot destination Replace and its viewer in multi-plot, a real click on the ~ button of its ASE-L window plots the three Outputs rows a strip each, the last row on top, every strip on the sweep and holding its own trace" \
        [list $shown [pcall ase::ui::plot_dest $::key] $tl [llength $vecs] [lindex $vecs 2] [llength [gz_xs $fit]] \
              [lmap ax $fit n {e a b} {gz_holds $ax $::T($n)}]] \
        {tran replace {} 3 b 1 {1 1 1}}
    check "GZ0 fixture: net b, the first row, reaches far above the largest value of net e, the last row" \
        [expr {[lindex [lsort -real $::T(b)] end] > 4 * [lindex [lsort -real $::T(e)] end]}] 1
    set kz [gz_vkeys 0 4 z $::CTRL]
    set z [gz_axes]
    check "GZ1 fixture: four real Ctrl-z presses on the viewer canvas leave every strip on one X window, wider than the sweep" \
        [list $kz [llength [gz_xs $z]] \
              [pcall expr {[lindex [gz_xs $z] 0 1] - [lindex [gz_xs $z] 0 0] > 1.5 * ([lindex [gz_xs $fit] 0 1] - [lindex [gz_xs $fit] 0 0])}]] \
        {{} 1 1}
    gz_tilde
    set a [gz_axes]
    check "GZ2 the ~ button pressed again after the viewer's own zoom: the rows come back a strip each, and every strip is on one X window, the zoomed one" \
        [list [gz_vecs] [gz_xs $a]] [list $vecs [gz_xs $z]]
    check "GZ3 ...each strip on the Y window it showed, so the first row's strip, at the bottom, holds its own trace: its Y window reaches from the smallest to the largest value of net b in the results file" \
        [list [expr {$a eq $z}] [gz_holds [lindex $a 2] $::T(b)]] {1 1}
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set dvec [lindex [lindex [newtraces $before] 0] 0]
    set dlab [label_of $dvec]
    set d [gz_axes]
    check "GZ4 a difference plotted next (the real chord, two real clicks) gets a strip of its own, and that strip has the X extent every other strip has" \
        [list $dlab [llength $d] [gz_xs $d]] [list {v(b)-v(a)} 4 [gz_xs $z]]
    check "GZ5 ...and the bar reads b minus a under its label" \
        [near [rd_at $dlab $::RT] [at_rt [pd_sub $::T(b) $::T(a)]] 2e-3] ok
    # the bench run again: a new result, and the plot a finished run makes
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    pcall ase::ui::auto_plot_idle $::key
    update
    set r [gz_axes]
    ## issue 1765: the difference was plotted by hand, so the run's plot leaves
    ## it in its strip, on top of the three rows
    check "GZ6 the bench run again (the results file written again with a second run's numbers) and the plot a finished run makes under Replace: the three rows are back a strip each, every strip on the zoomed X window and on the Y window it showed, and the difference plotted by hand stays in its strip above them" \
        [list [gz_vecs] [expr {[lrange $r 1 end] eq $z}] [llength $r]] [list [linsert $vecs 0 $dvec] 1 4]
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set dvec [lindex [lindex [newtraces $before] 0] 0]
    set dlab [label_of $dvec]
    set d [gz_axes]
    check "GZ7 a difference plotted after that run: its strip has the X extent every other strip has, and the bar reads the second run's b minus a" \
        [list [llength $d] [gz_xs $d] [near [rd_at $dlab $::RT] [at_rt [pd_sub $::T2(b) $::T2(a)]] 2e-3]] [list 5 [gz_xs $z] ok]
    # View > Fit stores a window on every strip as well, with no zoom at all
    clean_viewer
    pcall wviewer::set_plot_mode multi $::key
    gz_tilde
    set kf [gz_vkeys 0 1 f 0]
    set z [gz_axes]
    gz_tilde
    set a [gz_axes]
    check "GZ8 View > Fit (a real f on the viewer canvas) and then the ~ button, with no zoom: every strip shows what it showed, and the first row's strip holds its own trace" \
        [list $kf [gz_vecs] [expr {$a eq $z}] [gz_holds [lindex $a 2] $::T2(b)]] [list {} $vecs 1 1]
    set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    check "GZ9 fixture: no click of this band landed off its point" $::MISSED {}
}

# ---------------------------------------------------------------------------
# GG -- THE PLOT A FINISHED RUN MAKES, UNDER REPLACE, AFTER A DIFFERENCE.
#
# SINCE ISSUE 1765 Replace takes out ASE-L's own traces and leaves what the
# user plotted by hand, a difference included: rows GG1 and GG18 to GG20 say
# what a difference then shows. The rest of the band is about a difference
# that LEAVES the strips with a load of results in between and comes back by
# undo, which the emptying Replace of before used to bring about in one
# press. The user can still bring it about, and the rows now do it that way:
# Graph > Clear SubWin (the viewer's own command, one undo step), then the
# press (gg_clear_tilde, gg_clear_runend). Where a row below says "the plot
# removes", read "the subwindow was cleared before the plot".
#
# Replace was the session's default destination: the ~ button and a finished
# run emptied the target subwindow and plotted the Outputs rows there. That plot
# loads the results first, and a load evaluates the viewer's expression traces
# again and says so when one cannot be evaluated. The traces of the subwindow
# the same press is about to empty are neither evaluated nor spoken of: a
# sentence that a trace "is empty" and when it "draws again" would be said of
# a trace that is gone a moment later. A trace in another subwindow, or in a
# tab that is not shown, stays, and is told of. Under Append nothing is
# emptied, and the sentence is said, once; but not of a row's earlier trace
# that the same press plots again into the same vector. So the load of that
# plot says nothing, and what is still empty is told of once the rows are in.
#
# The doors: a real click on the ~ button of the session's ASE-L window, the
# entry a finished run schedules, the real chord and clicks for a difference,
# a real Direct Plot, and the real undo key on the viewer's canvas. The
# session's one Outputs row is an expression with no analysis in its text, so
# it is plotted from whichever analysis the viewer shows.
#
# Red on the product before the repair of the review round: GG2 to GG5 and GG7
# to GG9. GG10, GG12 and GG13 were written during it. GG14 to GG16 are the
# second review's, red before its repair. Measured 2026-11-24 on the display
# arm with all of them in, each break reverted to green:
#   the plot's load neither quiet nor leaving strips out       GG3, GG5, GG7, GG12, GG14
#   the plot's load not quiet (strips still left out)          GG12, GG13
#   no settling after the rows (wviewer::expr_settle)          GG6, GG7, GG12, GG13
#   wviewer::state_apply not evaluating again                  GG2, GG4, GG10, GG14 to GG16
#   ...evaluating every vector in place, as after a load       GG15, GG16
#   wviewer::expr_remake keeping its record of a trace that
#   left the strips                                            GG10
#   ...not telling a vector that is another trace's, or
#   reading no record of what a vector was computed from       GG14 to GG16
#   ...leaving such a vector in the data                       GG15, GG16
#   ...the analysis on record for the vector, not for the
#   trace's own expression                                     GG16
#   wviewer::state_apply not giving a trace that is back a
#   vector of its own while another tab's trace has its name   GG17
#   wviewer::expr_lost_why with no arm for a trace's vector    GG8, GG9
#   ...telling a bare name to be saved                         GG9
# Leaving no strips out, with the load quiet, reddens GG14 (the removed
# difference's vector is then made, its name stays taken, and the second
# difference is not computed into it) and RD3 of test_wave_expr_reattach_1734
# (the name a row keeps from run to run). Not evaluating what is computed
# from another trace's vector reddens no row of this band: its rows are RS3,
# RS4 and RU7 of that suite. The rebuild that follows the settling is held by
# the GX9 rows of test_wave_grid, which read ase::ui::auto_plot's text; no row
# reads what it draws.
# ---------------------------------------------------------------------------
proc gg_lost {} { return [lsearch -all -inline -glob $::notices {wviewer: trace * is empty*}] }
# Graph > Clear SubWin on the viewer's target subwindow, then a real click on
# the ~ button; and the same before the plot a finished run makes
proc gg_clear_tilde {} {
    pcall wviewer::clear_target_subwin $::key
    update
    return [gz_tilde]
}
proc gg_clear_runend {} {
    pcall wviewer::clear_target_subwin $::key
    update
    pcall ase::ui::auto_plot_idle $::key
    update
}
proc gg_neg {l} { return [lmap v $l {expr {-1.0 * $v}}] }
proc gg_labels {} { return [lsort [lmap t [traces] {label_of [lindex $t 0]}]] }
# real presses of the undo key on the viewer until the trace of `vec` is back
# in the shown tab, four at most; how many it took
proc gg_undo_until {vec} {
    set n 0
    while {$n < 4 && [label_of $vec] eq {NOTRACE}} { gz_vkeys 0 1 u 0 ; incr n }
    return $n
}
group GG {
    at_top
    to_design
    clean_viewer
    pcall wviewer::set_plot_mode single $::key
    set ::RUNSEL 1 ; set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set st0 [pcall ase::session_state $::key]
    set shown [run_only {op tran}]
    set st [pcall ase::session_state $::key]
    catch { dict set st outputs [list [dict create name NEG expr -v(e) save 0 plot 1]] }
    catch { dict set st plot_dest replace }
    pcall ase::session_update $::key $st
    set tl [gz_tilde]
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set dvec [lindex [lindex [newtraces $before] 0] 0]
    set dlab [label_of $dvec]
    check "GG0 fixture: under the destination Replace a real click on the ~ button plots the session's one Outputs row, an expression, and a difference plotted after it stands in the same subwindow; the bar reads minus e and b minus a" \
        [list $shown [pcall ase::ui::plot_dest $::key] $tl [gg_labels] [llength [lsort -unique [lmap G [dict get [wviewer::layout_for $::key] graphs] {wviewer::gsw $G}]]] \
              [near [rd_at NEG $::RT] [at_rt [gg_neg $::T(e)]] 2e-3] [near [rd_at $dlab $::RT] [at_rt [pd_sub $::T(b) $::T(a)]] 2e-3]] \
        {tran replace {} {NEG v(b)-v(a)} 1 ok ok}
    # the bench run again, every net there. Issue 1765: the ~ button under
    # Replace puts the row back once and leaves the difference, and both read
    # the new run
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    gz_tilde
    check "GG1 the bench run again and the ~ button under Replace: the row's trace is there once and the difference plotted by hand stays; both read the new run's numbers, and nothing is said about an empty trace" \
        [list [gg_labels] [gg_lost] [near [rd_at NEG $::RT] [at_rt [gg_neg $::T2(e)]] 2e-3] \
              [near [rd_at $dlab $::RT] [at_rt [pd_sub $::T2(b) $::T2(a)]] 2e-3]] [list [list NEG $dlab] {} ok ok]
    # the subwindow cleared, then the press: the difference is gone
    set ::notices {}
    gg_clear_tilde
    check "GG1b the subwindow cleared (Graph > Clear SubWin) and the ~ button: the target subwindow holds the row's trace alone, which reads the new run's numbers, and nothing is said about an empty trace" \
        [list [gg_labels] [gg_lost] [near [rd_at NEG $::RT] [at_rt [gg_neg $::T2(e)]] 2e-3]] {NEG {} ok}
    set ::notices {}
    set n [gg_undo_until $dvec]
    check "GG2 one press of the real undo key on the viewer brings the emptied plots back, the difference among them, and the bar reads the new run's b minus a under its label; nothing is said about an empty trace" \
        [list $n [label_of $dvec] [near [rd_at $dlab $::RT] [at_rt [pd_sub $::T2(b) $::T2(a)]] 2e-3] [gg_lost]] \
        [list 1 $dlab ok {}]
    # run again with net b no longer saved: the plot removes the difference,
    # and nothing is to be said of it
    set gone "wviewer: trace 'v(b)-v(a)' is empty: v(b) is not in the results the viewer now shows (the transient analysis of [file tail $::rawpath]); save it in ASE-L (Outputs > To Be Saved) and run again, and the trace draws again"
    set ::OMIT {b}
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    gg_clear_tilde
    check "GG3 run again with net b no longer in the result, the subwindow cleared and the ~ button under Replace: the difference is gone with the subwindow's other traces and no sentence says it is empty or when it draws again; the row's trace reads" \
        [list [gg_labels] [gg_lost] [near [rd_at NEG $::RT] [at_rt [gg_neg $::T2(e)]] 2e-3]] {NEG {} ok}
    set ::notices {}
    set n [gg_undo_until $dvec]
    check "GG4 one press of the real undo key then brings the difference back into its strip, where it is empty (net b is not in the result): the bar has no entry for it, and the sentence that names the trace, the net and what to do is said now, once" \
        [list $n [label_of $dvec] [rd_at $dlab {1e-9}] [nsaid $gone] [llength [gg_lost]]] [list 1 $dlab MISSING 1 1]
    # the next run is of another analysis: the difference was computed on the
    # transient and the plot of the DC sweep's run removes it
    set ::OMIT {}
    set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    gg_clear_tilde
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set dvec [lindex [lindex [newtraces $before] 0] 0]
    set had [gg_labels]
    set shown [run_only {op dc}]
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    gg_clear_runend
    check "GG5 with a difference of the transient in the target subwindow, the session set to run the DC sweep, the subwindow cleared and the plot a finished run makes under Replace: the viewer shows the DC sweep, the difference is gone, no sentence says it is empty or when it draws again, and the row's trace reads minus e of the sweep" \
        [list $had $shown [vtype] [gg_labels] [gg_lost] [near [rd_at NEG {0.5 1 1.5}] {-0.25 -0.2 -0.15} 2e-3]] \
        {{NEG v(b)-v(a)} dc dc NEG {} ok}
    # Append: nothing is emptied, so the difference stays and is told of, once
    set shown [run_only {op tran}]
    clean_viewer
    set st [pcall ase::session_state $::key]
    catch { dict set st plot_dest append }
    pcall ase::session_update $::key $st
    gz_tilde
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set dvec [lindex [lindex [newtraces $before] 0] 0]
    set ::OMIT {b}
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    gz_tilde
    set once [list [nsaid $gone] [llength [gg_lost]] [label_of $dvec] [rd_at $dlab {1e-9}]]
    set ::notices {}
    gz_tilde
    check "GG6 under the destination Append the same run leaves the difference in its strip, empty, and the sentence is said once; a second press of ~ on the same result does not say it again" \
        [list $shown [pcall ase::ui::plot_dest $::key] $once [llength [gg_lost]]] [list tran append [list 1 1 $dlab MISSING] 0]
    # that difference, which was told of, is now removed by a plot under
    # Replace and brought back by undo: it is empty still, and is told of again
    set st [pcall ase::session_state $::key]
    catch { dict set st plot_dest replace }
    pcall ase::session_update $::key $st
    set ::notices {}
    gg_clear_tilde
    set mid [list [gg_labels] [llength [gg_lost]]]
    set n [gg_undo_until $dvec]
    check "GG10 a difference that was already told of as empty, then removed (the subwindow cleared, then the ~ button under Replace; nothing is said) and brought back by one press of the undo key, is told of once more: what was on record about it went when it left the strips" \
        [list $mid $n [label_of $dvec] [rd_at $dlab {1e-9}] [nsaid $gone] [llength [gg_lost]]] [list {NEG 0} 1 $dlab MISSING 1 1]
    # Append, and a run of another analysis: the row's trace of the run before
    # stays, and the row is plotted again into the same vector, on the DC
    # sweep. Of that trace nothing is to be said. The difference, computed on
    # the transient, stays empty and is told of.
    set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    set st [pcall ase::session_state $::key]
    catch { dict set st plot_dest append }
    pcall ase::session_update $::key $st
    gz_tilde
    to_design
    chord_d ; click a ; click b
    set had [gg_labels]
    set shown [run_only {op dc}]
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    pcall ase::ui::auto_plot_idle $::key
    update
    set lost [gg_lost]
    check "GG12 under Append, with the row's trace of the transient run and a difference in the viewer, a run of the DC sweep and the plot it makes: the row is plotted again into the vector its earlier trace draws from, both read minus e of the sweep, and no sentence says the row's trace is empty; the difference, which stays and is of the transient, is told of once" \
        [list $had $shown [vtype] [gg_labels] [near [rd_at NEG {0.5 1 1.5}] {-0.25 -0.2 -0.15} 2e-3] [llength $lost] \
              [llength [lsearch -all -glob $lost "wviewer: trace 'NEG' is empty*"]] \
              [nsaid "wviewer: trace 'v(b)-v(a)' is empty: it was computed on the transient analysis and the viewer now shows the DC sweep analysis of [file tail $::rawpath]; it draws again when the viewer shows the transient analysis"]] \
        {{NEG v(b)-v(a)} dc dc {NEG NEG v(b)-v(a)} ok 1 0 1}
    set shown [run_only {op tran}]
    # Replace again, with a difference in a tab that is not shown, one in
    # another subwindow of the tab shown, and one in the target subwindow
    set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set st [pcall ase::session_state $::key]
    catch { dict set st plot_dest replace }
    pcall ase::session_update $::key $st
    clean_viewer
    to_design
    chord_d ; click a ; click b
    set idA [pcall wviewer::tab_id $::key]
    set idB [pcall wviewer::new_tab $::key]
    update
    chord_d ; click b ; click e
    set sw1 [pcall wviewer::new_subwin $::key]
    update
    gz_tilde
    to_design
    chord_d ; click e ; click b
    set inB [gg_labels]
    set nsw [llength [lsort -unique [lmap G [dict get [wviewer::layout_for $::key] graphs] {wviewer::gsw $G}]]]
    set ::OMIT {b}
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    gg_clear_tilde
    set lost [lsort [gg_lost]]
    check "GG7 with one difference in a tab that is not shown, one in another subwindow of the tab shown and one in the target subwindow, a run without net b, the target subwindow cleared and the ~ button under Replace: the two that stay are each told of once, by label, and nothing is said of the one that was cleared" \
        [list [expr {$idB ne {} && $idB ne $idA}] $inB $nsw [gg_labels] [llength $lost] \
              [lmap l {v(b)-v(a) v(e)-v(b) v(b)-v(e)} {llength [lsearch -all -glob $lost "wviewer: trace '$l' is empty: v(b) is not in the results*"]}]] \
        {1 {NEG v(b)-v(e) v(e)-v(b)} 2 {NEG v(e)-v(b)} 2 {1 1 0}}
    pcall wviewer::select_tab $idA $::key
    update
    pcall wviewer::close_tab $idB $::key
    update
    # an expression in another subwindow that is computed from the row's own
    # vector: the load cannot evaluate it (the row's trace is in the strips
    # about to be emptied, so its vector is not made), and it is evaluated
    # once the row is in
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    gz_tilde
    set t0 [pcall wviewer::target_index $::key]
    pcall wviewer::new_subwin $::key
    update
    set t1 [pcall wviewer::target_index $::key]
    set e1 [pcall wviewer::add_trace $::key $t1 {NEG 2 *} dep]
    update
    pcall wviewer::set_target_strip $t0 $::key
    update
    set r0 [near [rd_at dep $::RT] [at_rt [lmap v $::T(e) {expr {-2.0 * $v}}]] 2e-3]
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    gz_tilde
    set ax [gz_axes]
    set di -1
    set i 0
    foreach vs [gz_vecs] { if {[lsearch -exact $vs dep] >= 0} { set di $i } ; incr i }
    check "GG13 an expression in another subwindow that is computed from the row's vector, across a run and the ~ button under Replace: it reads twice the row's new numbers on the bar, its strip's Y window holds them, and nothing is said about an empty trace" \
        [list $e1 [expr {$t1 != $t0}] $r0 [gg_labels] [near [rd_at dep $::RT] [at_rt [lmap v $::T2(e) {expr {-2.0 * $v}}]] 2e-3] \
              [gz_holds [lindex $ax $di] [lmap v $::T2(e) {expr {-2.0 * $v}}]] [gg_lost]] \
        {{} 1 ok {NEG dep} ok 1 {}}
    # A LATER DIFFERENCE TAKES THE NAME OF THE FIRST ONE'S VECTOR. The plot
    # under Replace removes the first difference and its load makes no vector
    # for it, so that vector's name is free and the next difference is computed
    # into it. Undo then brings the first difference back while the data holds,
    # under that name, what the later one was computed from: the trace that is
    # back has to read its own two nets, and after redo the later one its own.
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    gz_tilde
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set v1 [lindex [lindex [newtraces $before] 0] 0]
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    gg_clear_tilde
    to_design
    set before [traces]
    chord_d ; click a ; click e
    set v2 [lindex [lindex [newtraces $before] 0] 0]
    set had [gg_labels]
    set wb [at_rt [pd_sub $::T2(b) $::T2(a)]]
    set we [at_rt [pd_sub $::T2(e) $::T2(a)]]
    set r2 [near [rd_at {v(e)-v(a)} $::RT] $we 2e-3]
    set ::notices {}
    gz_vkeys 0 1 u 0
    set undone [list [gg_labels] [near [rd_at {v(b)-v(a)} $::RT] $wb 2e-3]]
    gz_vkeys 0 1 U $::SHIFT
    check "GG14 a difference removed (the subwindow cleared, then the ~ button under Replace) after a run, a second difference of two other nets computed into the vector name the first one left free, and one press of the real undo key: the first difference is back under its label and the bar reads the new run's b minus a there, which the row's own numbers put well apart from e minus a; one press of the real redo key then puts the later difference back, and the bar reads e minus a under that label; nothing is said about an empty trace" \
        [list [expr {$v1 ne {} && $v1 eq $v2}] $had $r2 [expr {[apart $wb $we] > 0.3}] $undone [gg_labels] [near [rd_at {v(e)-v(a)} $::RT] $we 2e-3] [gg_lost]] \
        {1 {NEG v(e)-v(a)} ok 1 {{NEG v(b)-v(a)} ok} {NEG v(e)-v(a)} ok {}}
    # the same with net b gone from the result: the first difference, brought
    # back, cannot be evaluated, and the later trace's numbers are not its own
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    gz_tilde
    to_design
    chord_d ; click a ; click b
    set ::OMIT {b} ; set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    gg_clear_tilde
    to_design
    chord_d ; click a ; click e
    set had [gg_labels]
    set ::notices {}
    gz_vkeys 0 1 u 0
    set undone [list [gg_labels] [rd_at {v(b)-v(a)} $::RT] [nsaid $gone] [llength [gg_lost]]]
    set ::notices {}
    gz_vkeys 0 1 U $::SHIFT
    check "GG15 the same with net b not in the new result: the first difference, back by one press of the undo key, is empty -- the bar has no entry under its label, where the later difference's numbers would stand -- and the sentence that names it, the net and what to do is said once; after one press of the redo key the later difference reads e minus a again, with nothing said" \
        [list $had $undone [gg_labels] [near [rd_at {v(e)-v(a)} $::RT] $we 2e-3] [gg_lost]] \
        [list {NEG v(e)-v(a)} [list {NEG v(b)-v(a)} {MISSING MISSING MISSING} 1 1] {NEG v(e)-v(a)} ok {}]
    # the same across analyses: the first difference is of the transient, the
    # run that follows is the DC sweep's, and an expression added while the
    # viewer shows the sweep takes the vector's name. Brought back, the first
    # difference is held to the analysis it was itself computed on, whatever
    # was computed into that name since.
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    gz_tilde
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set v1 [lindex [lindex [newtraces $before] 0] 0]
    set shown [run_only {op dc}]
    pd_raw $::rawpath {tran ac dc op}
    gg_clear_runend
    set before [traces]
    set e1 [pcall wviewer::add_trace $::key [pcall wviewer::target_index $::key] {v(e) v(a) -}]
    update
    set v2 [lindex [lindex [newtraces $before] 0] 0]
    set r2 [near [rd_at $v2 {0.5 1 1.5}] {0.0 -0.3 -0.6} 2e-3]
    set ::notices {}
    gz_vkeys 0 1 u 0
    check "GG16 a difference of the transient removed (the subwindow cleared) before the plot of a DC sweep run under Replace, an expression added while the viewer shows the sweep and computed into the vector name the difference left free, and one press of the undo key: the difference is back in its strip and empty -- the bar has no entry under its label -- and one sentence says it was computed on the transient analysis and when it draws again" \
        [list $shown [vtype] $e1 [expr {$v1 ne {} && $v1 eq $v2}] $r2 [gg_labels] [rd_at {v(b)-v(a)} {0.5 1 1.5}] [llength [gg_lost]] \
              [nsaid "wviewer: trace 'v(b)-v(a)' is empty: it was computed on the transient analysis and the viewer now shows the DC sweep analysis of [file tail $::rawpath]; it draws again when the viewer shows the transient analysis"]] \
        {dc dc {} 1 ok {NEG v(b)-v(a)} {MISSING MISSING MISSING} 1 1}
    set shown [run_only {op tran}]
    # THE LATER DIFFERENCE IS IN ANOTHER TAB. Undo history is kept per tab, so
    # the undo that brings the first difference back leaves the later one
    # where it is: both are in the model, and the first one's vector has the
    # later one's name. The one that is back is given a vector of its own:
    # each reads its own two nets under its own label, and a load of results
    # after it leaves them so.
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    gz_tilde
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set v1 [lindex [lindex [newtraces $before] 0] 0]
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    gg_clear_tilde
    set idA [pcall wviewer::tab_id $::key]
    set idB [pcall wviewer::new_tab $::key]
    update
    to_design
    set before [traces]
    chord_d ; click a ; click e
    set v2 [lindex [lindex [newtraces $before] 0] 0]
    set wb [at_rt [pd_sub $::T2(b) $::T2(a)]]
    set we [at_rt [pd_sub $::T2(e) $::T2(a)]]
    set r2 [near [rd_at {v(e)-v(a)} $::RT] $we 2e-3]
    pcall wviewer::select_tab $idA $::key
    update
    set ::notices {}
    gz_vkeys 0 1 u 0
    set nv {}
    foreach t [traces] { if {[label_of [lindex $t 0]] eq {v(b)-v(a)}} { set nv [lindex $t 0] } }
    set undone [list [gg_labels] [near [rd_at {v(b)-v(a)} $::RT] $wb 2e-3]]
    to_design
    set m [dplot a]
    set loaded [near [rd_at {v(b)-v(a)} $::RT] $wb 2e-3]
    pcall wviewer::select_tab $idB $::key
    update
    set inB [list [gg_labels] [near [rd_at {v(e)-v(a)} $::RT] $we 2e-3]]
    check "GG17 the same with the later difference plotted in a second tab, so that it is still there after the undo: back on the first tab, one press of the real undo key brings the first difference back under its label with a vector of its own, and the bar reads the new run's b minus a there, not e minus a; a real Direct Plot after it leaves that so; and the second tab's difference still reads e minus a; nothing is said about an empty trace" \
        [list [expr {$v1 ne {} && $v1 eq $v2}] [expr {$idB ne {} && $idB ne $idA}] $r2 [expr {[apart $wb $we] > 0.3}] $undone [expr {$nv ne {} && $nv ne $v2}] $m $loaded $inB [gg_lost]] \
        {1 1 ok 1 {{NEG v(b)-v(a)} ok} 1 plot ok {v(e)-v(a) ok} {}}
    pcall wviewer::select_tab $idA $::key
    update
    pcall wviewer::close_tab $idB $::key
    update
    # ISSUE 1765: A DIFFERENCE THROUGH A FINISHED RUN UNDER REPLACE. It was
    # plotted by hand, so the plot a finished run makes leaves it, and it goes
    # on showing the run it was plotted from; the ~ button then brings it to
    # the result.
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    gz_tilde
    to_design
    chord_d ; click a ; click b
    set w1 [at_rt [pd_sub $::T(b) $::T(a)]]
    set w2 [at_rt [pd_sub $::T2(b) $::T2(a)]]
    set ::RUNSEL 2
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    pcall ase::ui::auto_plot_idle $::key
    update
    check "GG18 a difference in the target subwindow, the bench run again and the plot a finished run makes under Replace: the difference stays and the bar still reads the FIRST run's b minus a under its label (which that run's numbers put well apart from the second's), the row's trace reads the second run's, and nothing is said about an empty trace" \
        [list [gg_labels] [expr {[apart $w1 $w2] > 0.05}] [near [rd_at {v(b)-v(a)} $::RT] $w1 2e-3] \
              [near [rd_at NEG $::RT] [at_rt [gg_neg $::T2(e)]] 2e-3] [gg_lost] [pcall wviewer::held_traces $::key]] \
        {{NEG v(b)-v(a)} 1 ok ok {} 1}
    ## issue 1780: the bar names the kept difference as its legend does
    set gg_cue [rd_cue 1e-9]
    check "GG18 ...and the bar names the kept difference with the time of the run it shows, as its legend does; the row's trace, which shows the result, has the plain name" \
        [list [llength $gg_cue] [regexp {^v\(b\)-v\(a\)@} [lindex $gg_cue 0]]] {1 1}
    set ::notices {}
    gz_tilde
    check "GG19 the ~ button then brings the difference to the result: the bar reads the second run's b minus a under its label, no trace is kept on the earlier run, and nothing is said" \
        [list [gg_labels] [near [rd_at {v(b)-v(a)} $::RT] $w2 2e-3] [pcall wviewer::held_traces $::key] [gg_lost]] \
        {{NEG v(b)-v(a)} ok 0 {}}
    # ...and with net b gone from the new result: the difference kept on the
    # earlier run still draws, and nothing is said of it until ~ asks for the
    # result, where it is empty and told of once
    set ::OMIT {b}
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    pcall ase::ui::auto_plot_idle $::key
    update
    set kept [list [near [rd_at {v(b)-v(a)} $::RT] $w2 2e-3] [gg_lost]]
    set ::notices {}
    gz_tilde
    check "GG20 a finished run without net b under Replace: the difference kept on the run before still reads that run's b minus a and nothing is said; the ~ button then puts it on the result, where it is empty, and the sentence that names the trace, the net and what to do is said once" \
        [list $kept [gg_labels] [rd_at {v(b)-v(a)} {1e-9}] [nsaid $gone] [llength [gg_lost]]] \
        [list {ok {}} {NEG v(b)-v(a)} MISSING 1 1]
    # an expression that names another expression's trace
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    clean_viewer
    to_design
    dplot e
    set e1 [pcall wviewer::add_trace $::key 0 {v(b) 2 *} twice]
    set e2 [pcall wviewer::add_trace $::key 0 {twice 1 +} more]
    update
    set r0 [near [rd_at more $::RT] [at_rt [lmap v $::T(b) {expr {2.0 * $v + 1.0}}]] 2e-3]
    set ::OMIT {b}
    pd_raw $::rawpath {tran ac dc op}
    set ::notices {}
    set m [dplot a]
    check "GG8 an expression that names another expression's trace, after a run without the net that one needs and a real Direct Plot: the first is told to save the net, and the second is told that it is computed from the first, which is empty, and is not told to save anything" \
        [list $e1 $e2 $r0 $m [nsaid "wviewer: trace 'twice' is empty: v(b) is not in the results the viewer now shows (the transient analysis of [file tail $::rawpath]); save it in ASE-L (Outputs > To Be Saved) and run again, and the trace draws again"] \
              [nsaid "wviewer: trace 'more' is empty: it is computed from trace 'twice', which is empty; it draws again when that trace does"] [llength [gg_lost]]] \
        {{} {} ok plot 1 1 2}
    # ...and with that trace deleted (the Delete key's command)
    set gi -1 ; set ti -1
    catch {
        set g 0
        foreach G [dict get [wviewer::layout_for $::key] graphs] {
            set t 0
            foreach tr [dict get $G traces] { if {[dict get $tr vec] eq {twice}} { set gi $g ; set ti $t } ; incr t }
            incr g
        }
    }
    set nd [pcall wviewer::delete_items {} [list [list $gi $ti]] {} $::key]
    update
    set ::notices {}
    set m [dplot e]
    check "GG9 with the trace it names deleted, the next Direct Plot tells the second expression that the name is neither in the results nor a trace of the viewer, with the cure for each" \
        [list $nd [label_of twice] $m [nsaid "wviewer: trace 'more' is empty: twice is neither in the results the viewer now shows (the transient analysis of [file tail $::rawpath]) nor a trace of this viewer; if it is a net, save it in ASE-L (Outputs > To Be Saved) and run again, and if it was a trace, plot that trace again"] [llength [gg_lost]]] \
        {1 NOTRACE plot 1 1}
    set ::OMIT {} ; set ::RUNSEL 1
    pd_raw $::rawpath {tran ac dc op}
    pcall ase::session_update $::key $st0
    check "GG11 fixture: the session is back as it was, and no click of this band landed off its point" \
        [list [expr {[pcall ase::session_state $::key] eq $st0}] $::MISSED] {1 {}}
}

# ---------------------------------------------------------------------------
# GYA -- A STATE AND THE ANALYSIS ITS DIFFERENCE WAS READ FROM. A saved viewer
# state does not hold which analysis an expression was computed on. Two things
# follow, each with its row:
#   * A difference read from the AC analysis, saved, and restored into a
#     session whose viewer shows the transient: its expression is over phase
#     columns, which only an AC analysis holds. The sentence has to say that it
#     is an AC trace and draws again when the viewer shows AC, never that the
#     user should save a net and run again.
#   * A state loaded over an OPEN viewer whose own trace was computed, under
#     the same vector name and from the same text, on another analysis: the
#     restored trace is another trace, and what the window had on record about
#     that name is dropped before the restored traces are evaluated. The text
#     is the same on purpose (the two nets' difference of the DC sweep and of
#     the transient): the window keeps the analysis per text as well, so a
#     trace of another text is told apart from the window's own without the
#     records being dropped, and only the same text shows that they were.
#
# Red on the product before the repair of the review round: GYA1. GYA4 fences
# a line that was there. Measured 2026-11-24, each break reverted to green:
# wviewer::expr_lost_why not treating a phase column as an AC analysis's
# reddens GYA1; wviewer::restore keeping the window's records reddens GYA4.
# ---------------------------------------------------------------------------
group GYA {
    at_top
    to_design
    clean_viewer
    set ::RUNSEL 1 ; set ::OMIT {}
    pd_raw $::rawpath {tran ac dc op}
    set st0 [pcall ase::session_state $::key]
    set shown [run_only {op tran}]
    # a transient difference, then an AC one beside it (the command's word)
    set before [traces]
    chord_d ; click a ; click e
    set vt [lindex [lindex [newtraces $before] 0] 0]
    to_design
    set before [traces]
    pcall ase::plot_difference_for_current ac
    update
    click a ; click b
    set va [lindex [lindex [newtraces $before] 0] 0]
    set alab [label_of $va]
    check "GYA0 fixture: a transient difference e minus a and, read through the AC word, the difference b minus a of the AC analysis stand in one viewer, which shows AC; the AC one holds the magnitude of the complex difference" \
        [list $shown $alab [vtype] [near [vvals $va] [pd_cmag $::F(b) $::F(a)]]] {tran mag(v(b)-v(a)) ac ok}
    pcall ase::ui::viewer_snapshot $::key
    pcall wviewer::close $::key
    update
    set ::notices {}
    set rc [pcall ase::ui::viewer_restore $::key]
    update
    set acline "wviewer: trace 'mag(v(b)-v(a))' is empty: it was computed on the AC analysis and the viewer now shows the transient analysis of [file tail $::rawpath]; it draws again when the viewer shows the AC analysis"
    set rvec {}
    foreach t [traces] { if {[string first {ph(} [lindex $t 1]] >= 0} { set rvec [lindex $t 0] } }
    set tvec {}
    foreach t [traces] { if {[lindex $t 1] eq {v(e) v(a) -}} { set tvec [lindex $t 0] } }
    check "GYA1 the state taken, the viewer closed and the state restored into the session, whose viewer shows the transient: the AC difference is in its strip under its label with no entry on the bar, and the one sentence about it says it is a trace of the AC analysis and draws again when the viewer shows AC; no sentence tells the user to save a net" \
        [list $rc [vtype] [label_of $rvec] [rd_at $alab {1e-9}] [nsaid $acline] [llength [gg_lost]] \
              [llength [lsearch -all -glob $::notices {*save * in ASE-L*}]]] \
        {1 tran mag(v(b)-v(a)) MISSING 1 1 0}
    check "GYA2 ...beside the transient difference, which reads e minus a" \
        [near [rd_at [label_of $tvec] $::RT] [at_rt [pd_sub $::T(e) $::T(a)]] 2e-3] ok
    set ::notices {}
    set a [pcall wviewer::attach_raw $::key $::rawpath ac]
    update
    check "GYA3 with the viewer shown the AC analysis again, the restored AC difference draws: every point is the magnitude of the complex difference" \
        [list $a [vtype] [near [vvals $rvec] [pd_cmag $::F(b) $::F(a)]]] {1 ac ok}
    # A STATE LOADED OVER AN OPEN VIEWER
    clean_viewer
    set shown [run_only {op tran}]
    to_design
    set before [traces]
    chord_d ; click a ; click b
    set v1 [lindex [lindex [newtraces $before] 0] 0]
    pcall ase::ui::viewer_snapshot $::key
    set kept [pcall ase::session_state $::key]
    clean_viewer
    run_only {op dc}
    to_design
    set before [traces]
    pcall ase::plot_difference_for_current dc
    update
    click a ; click b
    set v2 [lindex [lindex [newtraces $before] 0] 0]
    set ondc [list [vtype] [lindex [lindex [newtraces $before] 0] 1]]
    pcall ase::session_update $::key $kept
    set ::notices {}
    set rc [pcall ase::ui::viewer_restore $::key]
    update
    set rv {}
    foreach t [traces] { if {[lindex $t 1] eq {v(b) v(a) -}} { set rv [lindex $t 0] } }
    check "GYA4 a state holding a transient difference, loaded over the open viewer after that viewer computed the same two nets' difference of the DC sweep, from the same text, into a vector of the same name: the restored difference reads the transient's b minus a on the bar, and nothing is said about an empty trace" \
        [list $shown [expr {$v1 ne {} && $v1 eq $v2}] $ondc $rc [vtype] [label_of $rv] \
              [near [rd_at {v(b)-v(a)} $::RT] [at_rt [pd_sub $::T(b) $::T(a)]] 2e-3] [gg_lost]] \
        {tran 1 {dc {v(b) v(a) -}} 1 tran v(b)-v(a) ok {}}
    clean_viewer
    pcall ase::session_update $::key $st0
    check "GYA5 fixture: the session is back as it was, and no click of this band landed off its point" \
        [list [expr {[pcall ase::session_state $::key] eq $st0}] $::MISSED] {1 {}}
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
