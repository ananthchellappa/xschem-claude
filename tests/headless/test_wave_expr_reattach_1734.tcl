# tests/headless/test_wave_expr_reattach_1734.tcl -- an expression trace and a
# Calculator wave keep drawing when the viewer's results are loaded again
# (issue 1734; specs doc/claude/specs/waveform_viewer.md, "Expression traces
# and Calculator waves across a load of results").
#
# A Direct Plot, a difference read from results the viewer does not show yet,
# and the plot a finished run makes each load the session's results into the
# viewer again (wviewer::attach_raw -> ase::attach_dbs). A load reads the file
# anew. Two things used to go with the old read: the vector every expression
# trace was computed into, and the database of every Calculator wave. Now the
# viewer evaluates its expression traces again after a load, and a load keeps
# the databases it is told to keep.
#
# THE RESULTS FILE IS ONE A REAL NGSPICE WROTE: tests/headless/data/
# calc_fixture.raw (its README names the simulator and the deck), copied to
# where the session of a sheet written here looks for its results. The sheet's
# nets carry the names of that file's nodes, so the real keys and real clicks
# pick them. Every expected value is computed here from the file's own vectors,
# read sample by sample, and never through the product's expression path.
#
# BANDS, both arms:
#   RK  ase::attach_dbs keeps a database it is told to keep (a table made by
#       the Calculator's own calc::wave_dest), leaves the result it read
#       current and says which slot that is; told nothing, it drops the table.
#       Which databases the viewer tells it to keep: the Calculator's own
#       tables, by what the Calculator says it made, and no database read
#       from a file, whether the file is still there or not
#   RM  the sentences for a trace that cannot be evaluated, and which of them
#       an expression earns on a given list of vectors
#   RS  the pass undo and redo run, on a model given here and the real file's
#       transient: a vector the data holds as computed from another trace's
#       expression is evaluated again from the trace of the model, what is
#       computed from it after it; one that cannot be evaluated is taken out
#       of the data; a trace is held to the analysis of its own expression;
#       a vector on record as the trace's own is not computed again
#   RX  the rows the spec names are rows of this file
# BANDS, display arm only (under --nogui each prints one `skip:`):
#   RA  a difference of two nets (the real chord and clicks), then a real
#       Direct Plot (Ctrl-4, a click, ESC)
#   RB  the Calculator's Plot button on an expression, then a real Direct Plot
#   RC  Graph > Add Trace's door on an expression (wviewer::add_trace), then a
#       real Direct Plot; two traces computed into one vector read the
#       expression computed last, wherever that trace stands in the strips
#   RD  an ASE-L Outputs row holding an expression, plotted by the plot a
#       finished run makes, then a real Direct Plot
#   RW  a Calculator wave (calc::wave_dest, calc::wave_in_token), then a real
#       Direct Plot, then the results file written again; a wave in a tab
#       that is not shown
#   RV  a trace on a database read from a file, the file deleted, then a real
#       Direct Plot: that database is not kept, the Calculator's table is
#   RU  an expression trace cleared, a real Direct Plot, and the clear undone
#       by the real key on the viewer: the trace reads again; a difference
#       deleted, a Direct Plot, a second difference computed into the vector
#       name the first left free, and undo: the first reads its own nets, and
#       so does a trace computed from such a vector
#   RP  an expression trace copied and pasted into another viewer window is
#       on record there with the analysis it was computed on
#   RL  an expression computed on one analysis while the viewer is made to
#       show another: the trace stays, empty, one sentence says so, and it
#       draws again when the viewer shows its analysis (a net the results
#       lack is band GJ of test_ase_plot_difference_1727, on a file written
#       there)
#
# SABOTAGES of the review round, each built in the product, run on the display
# arm, and put back (measured 2026-11-24, and again the same day with the rows
# of the second review in; the rows named went red in this suite and no other
# row of it did; the rows of the difference's suite that went red with each
# are in that suite's header):
#   ase::ui::auto_plot handing the load no strips to leave out, and
#   wviewer::expr_remake ignoring the strips it is handed          RD3
#   wviewer::mem_dbs keeping every database a trace names          RK6, RV1
#   calc::wave_dest_made answering yes for every table             RK6, RK7
#   wviewer::mem_dbs walking the shown tab only                    RW5
#   wviewer::expr_remake making a vector from its first trace,
#   with no record read of what was computed last                  RC4, RS1 to RS5, RU5 to RU7
#   ...from its last trace in the strips, with no record read      RC5, RS1 to RS5, RU5 to RU7
#   wviewer::state_apply not evaluating again                      RU1 to RU3, RU5 to RU7
#   ...evaluating every vector in place, as after a load           RU3
#   wviewer::paste_traces not recording the analysis               RP2
#   wviewer::expr_lost_why not treating a phase column as AC's     RM11
#   ...with no arm for another trace's vector                      RM12, RM14, RS4
#   ...telling a bare name to be saved                             RM12, RM13
#   ...with no arm for a name two vectors answer to                RM13
# SABOTAGES of the second review, of the pass undo and redo run
# (wviewer::expr_remake told to evaluate what the data lacks), measured the
# same way; the RS rows went red on both arms:
#   not telling a vector that is another trace's                   RS1 to RS5, RU5 to RU7
#   ...taking every vector the data holds for one                  RS1, RS2, RU3
#   ...asking only the trace that stands last in the strips        RS2
#   not evaluating what is computed from such a vector             RS3, RS4, RU7
#   leaving such a vector in the data                              RS3, RS4, RS5
#   the analysis on record for the vector, not for the trace's
#   own expression                                                 RS5
# AND of the later trace standing in another tab (wviewer::expr_unshare, what
# undo and redo run before that pass), measured 2026-11-24 on both arms:
#   wviewer::state_apply not calling it                            GG17 of the difference's suite
#   ...renaming nothing                                            RS6, RS7
#   ...renaming a name the user gave, or a trace of one postfix    RS7
#   ...not taking the analysis on record to the new vector         RS7
#   ...leaving a trace named by its vector under the old name      RS8
# AND of a paste into the window the trace was copied from, after its vector's
# name was taken (wviewer::paste_traces), display arm:
#   computing into the name as it stands                           RP3
#   ...leaving the pasted trace under the old name                 RP3
#
# Run it (never a bare ./src/xschem, which would use your screen and HOME):
#   tests/headless/run_suites.sh [--nogui] test_wave_expr_reattach_1734

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
# `ok`, or what differs: two lists of numbers, element by element
proc near {got want {tol 1e-5}} {
    if {[catch {llength $got} n] || $n != [llength $want]} { return "LEN:$got" }
    foreach g $got w $want {
        if {![string is double -strict $g]} { return "NAN:$got" }
        if {![string is double -strict $w]} { return "NOWANT:$want" }
        if {abs($g - $w) > $tol * (1.0 + abs($w))} { return "DIFF:$got" }
    }
    return ok
}

set no_recent_files 1

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wave_expr_reattach_1734]
test_sim_registry_isolate

set HASX [expr {[info exists ::has_x] && [info commands winfo] ne {} && ![catch {winfo exists .drw} e_] && $e_}]
set RC [file join $repo src cadence_style_rc]
set RAWFIX [file join $here data calc_fixture.raw]

# the notices, captured at the one spy point every ASE suite uses
set ::notices {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo re_real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg }
proc nsaid {s} {
    set n 0
    foreach m $::notices { if {$m eq $s} { incr n } }
    return $n
}

# the registry of the context that is current: its slots as {path type} in
# slot order, and the one that is current, each read off `xschem raw info`
proc reg_slots {} {
    set out {}
    if {[catch {xschem raw info} t]} { return $out }
    foreach ln [split $t "\n"] {
        if {[regexp {^[ \t]*([0-9]+)[ \t]+(.+)[ \t]+(\S+)[ \t]*$} $ln -> i nm ty]} { lappend out [list [string trim $nm] $ty] }
    }
    return $out
}
proc reg_cur {} {
    if {[catch {xschem raw info} t]} { return -1 }
    foreach ln [split $t "\n"] { if {[regexp {^[ \t]*([0-9]+)[ \t]+current[ \t]*$} $ln -> i]} { return $i } }
    return -1
}

# The Cadence profile, which binds the two keys the display bands press. It is
# sourced before the library of this suite is named, as a user's rc is read
# before a session exists: the profile names libraries of its own.
set ::RCRC NOTSOURCED
if {$HASX} { set ::RCRC [catch {source $::RC} ::RCERR] }

# ---------------------------------------------------------------------------
# the sheet, the library, the session, the results
# ---------------------------------------------------------------------------
set lib [file join $scratch relib]
file mkdir $lib
set top [file normalize [file join $lib re_top.sch]]
set f [open $top w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
set y 0
foreach n {lp sq ramp div dcmid} {
    puts $f "N 0 $y 200 $y {}"
    puts $f "C {devices/lab_pin} 0 $y 0 0 {name=l$y sig_type=std_logic lab=$n}"
    set ::AT($n) [list 100 $y]
    incr y 100
}
close $f
# a second sheet, for a second session with a viewer window of its own (band RP)
set two [file normalize [file join $lib re_two.sch]]
set f [open $two w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
puts $f "N 0 0 200 0 {}"
puts $f "C {devices/lab_pin} 0 0 0 0 {name=l0 sig_type=std_logic lab=lp}"
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE relib $lib"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
set rundir [file normalize [file join $scratch run]]
file mkdir $rundir
set rawpath [file join $rundir re_top_ase.raw]
set key {}
set ::RAWCLOCK [clock seconds]
# the real file put where the session looks for its results, as a run that
# ends writes it: the same bytes, a later time
proc re_run {} {
    file copy -force $::RAWFIX $::rawpath
    incr ::RAWCLOCK 7
    file mtime $::rawpath $::RAWCLOCK
}

if {[catch {

group FX {
    set fh [open $::RAWFIX]
    set head [read $fh 400]
    close $fh
    check "FX1 fixture: the results file is the committed one, and its own header says an ngspice wrote it" \
        [list [file isfile $::RAWFIX] [regexp {Command: ngspice-[0-9]} $head]] {1 1}
}

# ===========================================================================
# RK -- ase::attach_dbs and the databases it keeps (no window needed)
# ===========================================================================
group RK {
    catch {xschem raw clear}
    set rd [pcall xschem raw read $::RAWFIX tran]
    set lp0 [pcall xschem raw value v(lp) 13]
    # a Calculator destination, by the Calculator's own producer
    set d [pcall calc::wave_dest {0 1 2 3} {10 11 12 13} kx ky]
    set db [dg $d db]
    check "RK0 fixture: the real file is read as its transient and the Calculator's own producer registers a table beside it, leaving the result current" \
        [list $rd [dg $d ok] [reg_slots] [reg_cur]] [list 1 1 [list [list $::RAWFIX tran] [list $db table]] 0]
    check "RK1 ase::attach_dbs takes the databases to keep as its last argument, which a call may leave out" \
        [list [pcall info args ::ase::attach_dbs] \
              [pcall apply {{} { list [info default ::ase::attach_dbs keep d] $d }}]] {{rawfile sim_type vcdfiles keep} {1 {}}}
    # told nothing, a load drops every other database
    set a [pcall ase::attach_dbs $::RAWFIX tran]
    check "RK2 told to keep nothing, a load of the results leaves the result it read and nothing else, current, in the slot it answers" \
        [list [dg $a n] [reg_slots] [reg_cur] [dg $a current]] [list 1 [list [list $::RAWFIX tran]] 0 0]
    # told to keep the table, it keeps it
    set d [pcall calc::wave_dest {0 1 2 3} {10 11 12 13} kx ky]
    set db [dg $d db]
    set d2 [pcall calc::wave_dest {0 1} {7 8} kx ky]
    set db2 [dg $d2 db]
    set a [pcall ase::attach_dbs $::RAWFIX tran {} [list [list $db table]]]
    set slots [reg_slots]
    set cur [reg_cur]
    check "RK3 told to keep one table of two, a load keeps that one and drops the other; the result it read is the current database, in the slot the answer names, and its vectors read as before" \
        [list [dg $a n] [lsort $slots] [lindex $slots $cur] [expr {[dg $a current] eq $cur}] \
              [expr {[pcall xschem raw value v(lp) 13] eq $lp0}] [expr {[lsearch -exact $slots [list $db2 table]] >= 0}]] \
        [list 1 [lsort [list [list $::RAWFIX tran] [list $db table]]] [list $::RAWFIX tran] 1 1 0]
    set kept {}
    if {![catch {xschem raw switch $db table} sw] && $sw eq {1}} {
        catch {set kept [string trim [xschem raw values ky]]}
    }
    catch {xschem raw switch $::RAWFIX tran}
    check "RK4 ...and the kept table still holds the samples it was made with" \
        [list [near $kept {10 11 12 13}] [lindex [reg_slots] [reg_cur]]] [list ok [list $::RAWFIX tran]]
    # a second load, the table still kept, and a name that is no database
    set a [pcall ase::attach_dbs $::RAWFIX tran {} [list [list $db table] [list nosuch_db table]]]
    check "RK5 a second load keeps it again, a name to keep that is no database changes nothing, and the result is current once more" \
        [list [dg $a n] [lsort [reg_slots]] [lindex [reg_slots] [reg_cur]] [expr {[dg $a current] eq [reg_cur]}]] \
        [list 1 [lsort [list [list $::RAWFIX tran] [list $db table]]] [list $::RAWFIX tran] 1]
    # WHICH DATABASES THE VIEWER NAMES TO KEEP. A model of one strip, held
    # under a token no window has: a trace on the table the Calculator has
    # just made, one on a table name the Calculator did not make, one on a
    # results file that is on disk, one on a file that is not (a VCD a run
    # deleted), and a plain trace of the current database
    set gone [file join $::scratch rk_no_such.vcd]
    set gs [list [dict create traces [list \
        [dict create expr ky name ky vec ky color 4 rawfile $db sim_type table sweep kx] \
        [dict create expr ky name ky vec ky color 5 rawfile __calc_dest_not_made sim_type table sweep kx] \
        [dict create expr v(lp) name v(lp) vec v(lp) color 6 rawfile $::RAWFIX sim_type ac] \
        [dict create expr clk name clk vec clk color 7 rawfile $gone sim_type vcd] \
        [dict create expr v(sq) name v(sq) vec v(sq) color 8]]]]
    dict set ::wviewer::layouts __rk [dict create sharedx 0 graphs $gs]
    check "RK6 of the databases a window's traces name, the viewer tells a load to keep the table the Calculator made and no other: not a table of a name the Calculator did not make, not a results file on disk, and not a file that is gone from disk" \
        [list [file exists $::RAWFIX] [file exists $gone] [llength [pcall wviewer::trace_dbs $gs]] [pcall wviewer::mem_dbs __rk]] \
        [list 1 0 4 [list [list $db table]]]
    catch {dict unset ::wviewer::layouts __rk}
    check "RK7 the Calculator answers which databases it made: the table it has just registered, under that name as a table, and not that name as another kind, a name it never made, or a results file" \
        [list [pcall calc::wave_dest_made $db table] [pcall calc::wave_dest_made $db tran] \
              [pcall calc::wave_dest_made __calc_dest_not_made table] [pcall calc::wave_dest_made $::RAWFIX tran]] {1 0 0 0}
    check "RK8 wviewer::attach_raw takes, as its last two arguments, the strips whose traces the load leaves unevaluated and whether it says nothing of a trace it could not evaluate, and a call may leave both out: no strips, and not quiet" \
        [list [pcall info args ::wviewer::attach_raw] \
              [pcall apply {{} { list [info default ::wviewer::attach_raw vcdfiles d] $d [info default ::wviewer::attach_raw leave e] $e [info default ::wviewer::attach_raw quiet q] $q }}]] \
        {{token rawfile sim_type vcdfiles leave quiet} {1 {} 1 {} 1 0}}
    catch {xschem raw clear}
}

# ===========================================================================
# RM -- the sentences for a trace that cannot be evaluated (pure)
# ===========================================================================
group RM {
    check "RM1 a trace whose expression names a vector the results lack: the sentence names the trace, the vector, the analysis and file the viewer shows, and says to save it and run again" \
        [pcall wviewer::expr_lost_msg missing {v(b)-v(a)} {v(b)} tran /some/dir/top_ase.raw] \
        {wviewer: trace 'v(b)-v(a)' is empty: v(b) is not in the results the viewer now shows (the transient analysis of top_ase.raw); save it in ASE-L (Outputs > To Be Saved) and run again, and the trace draws again}
    check "RM2 ...two vectors are both named, and the words agree in number" \
        [pcall wviewer::expr_lost_msg missing gain {v(b) v(c)} ac top_ase.raw] \
        {wviewer: trace 'gain' is empty: v(b) and v(c) are not in the results the viewer now shows (the AC analysis of top_ase.raw); save them in ASE-L (Outputs > To Be Saved) and run again, and the trace draws again}
    check "RM3 a trace computed on one analysis while the viewer shows another: the sentence names the trace, both analyses and the file, and says when it draws again" \
        [pcall wviewer::expr_lost_msg analysis {mag(v(b)-v(a))} ac tran /some/dir/top_ase.raw] \
        {wviewer: trace 'mag(v(b)-v(a))' is empty: it was computed on the AC analysis and the viewer now shows the transient analysis of top_ase.raw; it draws again when the viewer shows the AC analysis}
    check "RM4 a kind the builder does not have answers nothing" [pcall wviewer::expr_lost_msg nosuchkind x y z w] {}
    check "RM5 a trace computed from another trace that is itself empty: the sentence names both traces and says when it draws again, and does not tell the user to save anything" \
        [pcall wviewer::expr_lost_msg trace more {twice} tran /some/dir/top_ase.raw] \
        {wviewer: trace 'more' is empty: it is computed from trace 'twice', which is empty; it draws again when that trace does}
    check "RM6 ...two such traces are both named, and the words agree in number" \
        [pcall wviewer::expr_lost_msg trace more {twice {v(b)-v(a)}} tran top_ase.raw] \
        {wviewer: trace 'more' is empty: it is computed from traces 'twice' and 'v(b)-v(a)', which are empty; it draws again when those traces do}
    check "RM7 a name that is neither in the results nor a trace of the viewer: the sentence says both, and gives the cure for a net and the cure for a trace that was deleted" \
        [pcall wviewer::expr_lost_msg unknown more {twice} tran /some/dir/top_ase.raw] \
        {wviewer: trace 'more' is empty: twice is neither in the results the viewer now shows (the transient analysis of top_ase.raw) nor a trace of this viewer; if it is a net, save it in ASE-L (Outputs > To Be Saved) and run again, and if it was a trace, plot that trace again}
    check "RM8 a name two vectors of the results answer to: the sentence says so and says to plot the trace again with an exact spelling" \
        [pcall wviewer::expr_lost_msg ambiguous gain {COUNT} tran top_ase.raw] \
        {wviewer: trace 'gain' is empty: COUNT answers to two vectors of the results the viewer now shows (the transient analysis of top_ase.raw) that differ only in letter case; plot the trace again with the exact spelling of one}
    check "RM9 an expression whose every name the results hold and which was still not evaluated: the sentence says that and names no vector" \
        [pcall wviewer::expr_lost_msg failed gain {} dc top_ase.raw] \
        {wviewer: trace 'gain' is empty: it could not be evaluated on the results the viewer now shows (the DC sweep analysis of top_ase.raw); plot the trace again}
    # WHICH SENTENCE AN EXPRESSION EARNS, on a list of vectors given here: a
    # transient's (no phase column) and an AC analysis's, which lacks net b
    set tl {time v(a) v(b) i(v1)}
    set al {frequency v(a) ph(a) v(e) ph(e)}
    set acdiff {v(b) ph(b) re() v(a) ph(a) re() - dup() * v(b) ph(b) im() v(a) ph(a) im() - dup() * + sqrt()}
    check "RM10 names of the form a run saves that the results lack earn the save-and-run sentence, each named once: a node voltage, a source current, a device parameter, a branch current" \
        [list [pcall wviewer::expr_lost_why {v(b) v(c) -} $tl tran {} 1] [pcall wviewer::expr_lost_why {v(c) v(d) - v(c) +} $tl tran {} 1] \
              [pcall wviewer::expr_lost_why {i(v9) 2 *} $tl tran {} 1] [pcall wviewer::expr_lost_why {@m1[gm] 2 *} $tl tran {} 1] \
              [pcall wviewer::expr_lost_why {l1#branch 2 *} $tl tran {} 1]] \
        [list {missing v(c)} {missing {v(c) v(d)}} {missing i(v9)} [list missing [list {@m1[gm]}]] {missing l1#branch}]
    check "RM11 an expression over phase columns, which only an AC analysis holds, earns the analysis sentence for AC while the viewer shows another analysis, whatever else it lacks; while the viewer shows AC a phase column that is missing is its net's, and the net is what is named to save, unless the net itself is there, when the column is named" \
        [list [pcall wviewer::expr_lost_why $acdiff $tl tran {} 1] [pcall wviewer::expr_lost_why $acdiff {time v(a)} tran {} 1] \
              [pcall wviewer::expr_lost_why $acdiff $al ac {} 1] [pcall wviewer::expr_lost_why $acdiff {frequency v(a) ph(a) v(b)} ac {} 1]] \
        [list {analysis ac} {analysis ac} {missing v(b)} {missing ph(b)}]
    check "RM12 a name that is the vector of another expression trace of the window earns the sentence that names that trace by its label; the same name with no such trace is neither a result nor a trace" \
        [list [pcall wviewer::expr_lost_why {twice 1 +} $tl tran {twice TW} 1] [pcall wviewer::expr_lost_why {twice 1 +} $tl tran {other TW} 1]] \
        [list {trace TW} {unknown twice}]
    check "RM13 a name that two vectors differing only in letter case answer to is said as that, where the data folds case; where it does not, the name is simply not there" \
        [list [pcall wviewer::expr_lost_why {COUNT 2 *} {time Count count} tran {} 1] [pcall wviewer::expr_lost_why {COUNT 2 *} {time Count count} tran {} 0]] \
        [list {ambiguous COUNT} {unknown COUNT}]
    check "RM15 the sentences for several names agree in number: two names that are neither results nor traces, and two names that two vectors each answer to" \
        [list [pcall wviewer::expr_lost_msg unknown more {twice thrice} tran top_ase.raw] [pcall wviewer::expr_lost_msg ambiguous gain {COUNT EN} tran top_ase.raw]] \
        [list {wviewer: trace 'more' is empty: twice and thrice are neither in the results the viewer now shows (the transient analysis of top_ase.raw) nor traces of this viewer; if they are nets, save them in ASE-L (Outputs > To Be Saved) and run again, and if they were traces, plot those traces again} \
              {wviewer: trace 'gain' is empty: COUNT and EN each answer to two vectors of the results the viewer now shows (the transient analysis of top_ase.raw) that differ only in letter case; plot the trace again with the exact spelling of one}]
    check "RM14 an expression the list answers in full earns the could-not-be-evaluated sentence, and one that lacks a net and names an empty trace is told of the trace first" \
        [list [pcall wviewer::expr_lost_why {v(b) v(a) -} $tl tran {} 1] [pcall wviewer::expr_lost_why {twice v(c) +} $tl tran {twice TW} 1]] \
        [list {failed {}} {trace TW}]
}

# ===========================================================================
# RS -- THE PASS THAT UNDO AND REDO RUN, on a model given here (no window
# needed). wviewer::state_apply puts a model back without reading any data, so
# its pass (wviewer::expr_remake told to evaluate what the data lacks) leaves a
# vector the data holds as it is. Such a vector is not the trace's own when a
# later trace was computed into its name: the trace left, a load made no
# vector for it, and the name was free. The pass has to see that from the
# window's record of what each vector was computed from, evaluate the vector
# again from the trace that is back, and after it every trace computed from
# it; and where the trace that is back cannot be evaluated, the vector must
# not stay in the data to be drawn under that trace's label.
#
# The data is the real file's transient, read into the context that is
# current; the model is one strip held under a token no window has; a vector
# is computed and recorded as wviewer::add_trace computes and records one.
# Every expected value is computed here from the file's columns.
# ===========================================================================
proc rs_tr {vec ex} { return [dict create expr $ex name $vec vec $vec color 4] }
proc rs_model {args} {
    dict set ::wviewer::layouts __rs [dict create sharedx 0 graphs [list [dict create traces $args]]]
}
# a vector computed into the data and recorded, as wviewer::add_trace does both
proc rs_add {vec ex {type tran}} {
    set r [pcall xschem raw add $vec $ex]
    pcall wviewer::expr_note __rs $vec $type $ex
    return $r
}
set ::RSK {13 47 88}
proc rs_at {name} { return [lmap k $::RSK {pcall xschem raw value $name $k}] }
proc rs_col {name {m 1.0} {c 0.0}} { return [lmap k $::RSK {expr {$m * [xschem raw value $name $k] + $c}}] }
# the pass, and every evaluation of an expression into the data while it runs,
# by the vector it was computed into
proc rs_seen {cmd args} { if {[string match {xschem raw add *} $cmd]} { lappend ::RSADD [lindex $cmd 3] } }
proc rs_pass {} {
    set ::RSADD {}
    catch {trace add execution ::xschem enter rs_seen}
    set a [pcall wviewer::expr_remake __rs {} 1]
    catch {trace remove execution ::xschem enter rs_seen}
    return $a
}
group RS {
    catch {xschem raw clear}
    catch {wviewer::expr_forget __rs}
    set rd [pcall xschem raw read $::RAWFIX tran]
    set r2 [pcall rs_col v(ramp) 2.0]
    set d5 [pcall rs_col v(div) 5.0]
    set far 1
    foreach a $r2 b $d5 { if {![string is double -strict $a] || ![string is double -strict $b] || abs($a - $b) < 0.01} { set far 0 } }
    # the trace that left: `nm`, twice ramp. The later trace: `nm` again, five
    # times div, which is what the data holds and the record says
    set a1 [rs_add nm {v(ramp) 2 *}]
    set a2 [rs_add nm {v(div) 5 *}]
    check "RS0 fixture: the real file is read as its transient; a vector computed from twice one column and then, under the same name and in place, from five times another reads the second, and at the samples the rows read the two are far apart" \
        [list $rd $a1 $a2 $far [near [rs_at nm] $d5]] {1 1 0 1 ok}
    rs_model [rs_tr nm {v(ramp) 2 *}]
    set a [rs_pass]
    set first [list [dg $a made] [dg $a said] $::RSADD [near [rs_at nm] $r2]]
    set a [rs_pass]
    check "RS1 the pass undo runs, on a model whose one trace is of a vector the data holds as computed from another expression: the vector is evaluated again from the trace of the model and reads twice the column, with nothing said; run once more, the vector now being on record as that trace's, the pass evaluates nothing" \
        [list $first [dg $a made] $::RSADD [near [rs_at nm] $r2]] {{1 {} nm ok} 0 {} ok}
    # two traces of one vector; the one on record as computed last stands
    # first in the strips, then last
    rs_model [rs_tr nm {v(ramp) 2 *}] [rs_tr nm {v(div) 5 *}]
    set a [rs_pass]
    set kept [list [dg $a made] $::RSADD [near [rs_at nm] $r2]]
    rs_model [rs_tr nm {v(div) 5 *}] [rs_tr nm {v(ramp) 2 *}]
    set a [rs_pass]
    lappend kept [dg $a made] $::RSADD [near [rs_at nm] $r2]
    rs_model [rs_tr nm {v(div) 5 *}] [rs_tr nm {v(div) 3 *}]
    set a [rs_pass]
    check "RS2 two traces of one vector: while one of them is the expression on record as computed last, standing first in the strips or last, nothing is evaluated and the vector reads that one; when neither is, the vector is evaluated again from the one standing last in the strips" \
        [list $kept [dg $a made] $::RSADD [near [rs_at nm] [pcall rs_col v(div) 3.0]]] {{0 {} ok 0 {} ok} 1 nm ok}
    # a trace computed from the vector, which the data holds too and which
    # stands before it in the strips
    set a3 [rs_add dep {nm 1 +}]
    rs_model [rs_tr dep {nm 1 +}] [rs_tr nm {v(ramp) 2 *}]
    set a [rs_pass]
    check "RS3 a trace computed from that vector, held by the data and standing before it in the strips: when the vector is evaluated again from another expression the trace computed from it is evaluated after it, and reads that expression plus one" \
        [list $a3 [dg $a made] $::RSADD [near [rs_at nm] $r2] [near [rs_at dep] [pcall rs_col v(ramp) 2.0 1.0]]] {1 2 {nm dep} ok ok}
    # the trace that is back names a net the results lack
    rs_add nm {v(div) 5 *}
    rs_add dep {nm 1 +}
    rs_model [rs_tr dep {nm 1 +}] [rs_tr nm {v(nosuch) 2 *}]
    set a [rs_pass]
    set said [lsort [dg $a said]]
    set a [rs_pass]
    check "RS4 when the trace of the model names a net the results lack, the vector the data held under its name is dropped from the data and so is the vector of the trace computed from it, so neither reads the other expression's numbers; each is told of once, by its own cause, and a second pass says nothing" \
        [list [pcall xschem raw index nm] [pcall xschem raw index dep] $said [dg $a said]] \
        [list -1 -1 [lsort [list \
            "wviewer: trace 'nm' is empty: v(nosuch) is not in the results the viewer now shows (the transient analysis of [file tail $::RAWFIX]); save it in ASE-L (Outputs > To Be Saved) and run again, and the trace draws again" \
            "wviewer: trace 'dep' is empty: it is computed from trace 'nm', which is empty; it draws again when that trace does"]] {}]
    # the trace that is back was computed on another analysis than the data
    # shows, and a trace of this analysis has taken its vector's name since
    rs_model
    pcall wviewer::expr_note __rs nm ac {v(ramp) 2 *}
    rs_add nm {v(div) 5 *}
    rs_model [rs_tr nm {v(ramp) 2 *}]
    set a [rs_pass]
    check "RS5 a trace on record as computed on the AC analysis, whose vector's name a trace of the transient has taken since: on a model that holds it, the pass holds it to its own analysis -- the vector is dropped from the data, not evaluated from transient columns, and one sentence says which analysis the trace was computed on and when it draws again" \
        [list [dg $a made] $::RSADD [pcall xschem raw index nm] [dg $a said]] \
        [list 0 {} -1 [list "wviewer: trace 'nm' is empty: it was computed on the AC analysis and the viewer now shows the transient analysis of [file tail $::RAWFIX]; it draws again when the viewer shows the AC analysis"]]
    # THE LATER TRACE IS IN ANOTHER TAB, so it is still in the model when undo
    # brings the first one back: the tab shown holds the trace that is back,
    # the tab that is not shown holds the later one, and the data holds the
    # later one's numbers under the name both have. What undo and redo run
    # first (wviewer::expr_unshare) gives the trace that is back a vector of
    # its own; the pass then evaluates it.
    catch {wviewer::expr_forget __rs}
    catch {xschem raw del nm}
    catch {xschem raw del dep}
    set a1 [rs_add expr1 {v(ramp) 2 *}]
    set a2 [rs_add expr1 {v(div) 5 *}]
    set other [dict create layout [dict create sharedx 0 graphs [list [dict create traces [list [rs_tr expr1 {v(div) 5 *}]]]]]]
    set ::wviewer::tabstash(__rs) [list {} $other]
    set ::wviewer::curtab(__rs) 0
    rs_model [dict create expr {v(ramp) 2 *} name first vec expr1 color 4]
    set n [pcall wviewer::expr_unshare __rs]
    set tr [lindex [dict get [lindex [dict get [wviewer::layout_for __rs] graphs] 0] traces] 0]
    set nv [dict get $tr vec]
    set a [rs_pass]
    set again [pcall wviewer::expr_unshare __rs]
    check "RS6 the later trace stands in a tab that is not shown, with the name of the vector of the trace that is back: that trace is given a vector name of its own and keeps the label it is shown under; the pass computes that vector alone, it reads twice the one column, and the vector of the other tab still reads five times the other; asked again, nothing is renamed" \
        [list $a1 $a2 $n [expr {$nv ne {expr1} && [regexp {^expr[0-9]+$} $nv]}] [dict get $tr name] [dg $a made] [expr {$::RSADD eq [list $nv]}] [near [rs_at $nv] $r2] [near [rs_at expr1] $d5] $again] \
        {1 0 1 1 first 1 1 ok ok 0}
    # what is NOT renamed: a name the user gave (one vector by the user's
    # choice) and a trace of the same postfix as the other tab's (one vector
    # serves both). And the analysis on record for the trace goes with it.
    rs_add nm {v(div) 5 *}
    set other [dict create layout [dict create sharedx 0 graphs [list [dict create traces [list [rs_tr nm {v(div) 5 *}] [rs_tr expr1 {v(div) 5 *}]]]]]]
    set ::wviewer::tabstash(__rs) [list {} $other]
    rs_model [rs_tr nm {v(ramp) 2 *}] [rs_tr expr1 {v(div) 5 *}]
    set kept [list [pcall wviewer::expr_unshare __rs] [lmap t [dict get [lindex [dict get [wviewer::layout_for __rs] graphs] 0] traces] {dict get $t vec}]]
    pcall wviewer::expr_note __rs expr1 ac {v(ramp) 2 *}
    rs_add expr1 {v(div) 5 *}
    rs_model [dict create expr {v(ramp) 2 *} name first vec expr1 color 4]
    set n [pcall wviewer::expr_unshare __rs]
    set nv2 [dict get [lindex [dict get [lindex [dict get [wviewer::layout_for __rs] graphs] 0] traces] 0] vec]
    set a [rs_pass]
    check "RS7 a vector the user named, held by a trace of each tab with two expressions, and a trace of the same expression as the other tab's, keep the vector they share; and a trace on record as computed on the AC analysis takes that record to its new vector: the pass does not evaluate it from transient columns, and one sentence says which analysis it was computed on" \
        [list $kept $n [expr {$nv2 ne {expr1}}] [dg $a made] $::RSADD [pcall xschem raw index $nv2] [near [rs_at expr1] $d5] [dg $a said]] \
        [list {0 {nm expr1}} 1 1 0 {} -1 ok [list "wviewer: trace 'first' is empty: it was computed on the AC analysis and the viewer now shows the transient analysis of [file tail $::RAWFIX]; it draws again when the viewer shows the AC analysis"]]
    # a trace that is shown by its vector's name
    catch {wviewer::expr_forget __rs}
    rs_add expr1 {v(div) 5 *}
    set other [dict create layout [dict create sharedx 0 graphs [list [dict create traces [list [rs_tr expr1 {v(div) 5 *}]]]]]]
    set ::wviewer::tabstash(__rs) [list {} $other]
    rs_model [rs_tr expr1 {v(ramp) 2 *}]
    set n [pcall wviewer::expr_unshare __rs]
    set tr [lindex [dict get [lindex [dict get [wviewer::layout_for __rs] graphs] 0] traces] 0]
    check "RS8 a trace that is shown by its vector's name, given a vector of its own, is shown by the new name: no two legends of one name stand over two vectors" \
        [list $n [expr {[dict get $tr vec] ne {expr1}}] [expr {[dict get $tr name] eq [dict get $tr vec]}]] {1 1 1}
    catch {unset ::wviewer::tabstash(__rs)}
    catch {unset ::wviewer::curtab(__rs)}
    catch {dict unset ::wviewer::layouts __rs}
    catch {wviewer::expr_forget __rs}
    catch {xschem raw clear}
}

# ===========================================================================
# RX -- the rows the spec names are rows of this file
# ===========================================================================
group RX {
    set fh [open [file join $::repo doc claude specs waveform_viewer.md]]
    fconfigure $fh -encoding utf-8
    set spec [read $fh]
    close $fh
    set a [string first {### Expression traces and Calculator waves across a load of results} $spec]
    set sec {}
    if {$a >= 0} {
        set b [string first "\n## " $spec [expr {$a + 10}]]
        set c [string first "\n### " $spec [expr {$a + 10}]]
        if {$b < 0 || ($c >= 0 && $c < $b)} { set b $c }
        if {$b < 0} { set b [string length $spec] }
        set sec [string range $spec $a $b]
    }
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
    # the rows of this file's own bands: the difference's rows are the other suite's
    set mine {}
    foreach id [lsort -unique $named] { if {[regexp {^R[A-Z][0-9]+$} $id]} { lappend mine $id } }
    set missing {}
    foreach id $mine { if {[lsearch -exact $own $id] < 0} { lappend missing $id } }
    check "RX1 the spec's section on expression traces and Calculator waves across a load names rows of this suite, and every one it names is a row of this file" \
        [list [expr {[llength $mine] > 10}] [expr {[llength $own] > 10}] $missing] {1 1 {}}
}

# ===========================================================================
# the display arm
# ===========================================================================
if {!$HASX} {
    foreach b {RA RB RC RD RW RV RU RP RL} {
        puts "skip: $b -- needs a display: a viewer window, the real keys and real clicks on the design canvas"
    }
} else {

for {set i 0} {$i < 200} {incr i} {
    if {[winfo ismapped .drw] && [winfo width .drw] > 300 && [winfo height .drw] > 300} break
    update ; after 25
}
set ::SHIFT 1 ; set ::CTRL 4 ; set ::ALT 8

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
proc no_mode {} {
    if {[info exists ::ase::ui::sod(active)]} { catch {ase::ui::sod_end $::ase::ui::sod(active)} }
    catch {update}
}
set ::ET 900000
set ::MISSED {}
# one real click at a schematic point: a motion (read back), a press, a release
proc click {w} {
    lassign $::AT($w) x y
    set p [px $x $y]
    update
    event generate .drw <Motion> -x [lindex $p 0] -y [lindex $p 1]
    update
    set gx [xschem get mousex] ; set gy [xschem get mousey]
    if {abs($gx - $x) > 2 || abs($gy - $y) > 2} { lappend ::MISSED "wanted $x,$y got $gx,$gy" }
    incr ::ET 5000
    event generate .drw <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] -time $::ET
    update
    event generate .drw <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] -state 256 -time [expr {$::ET + 80}]
    update
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
proc armed {} {
    if {![info exists ::ase::ui::sod(active)] || $::ase::ui::sod(active) ne $::key} { return {} }
    if {[info exists ::ase::ui::sod($::key,mode)]} { return $::ase::ui::sod($::key,mode) }
    return {}
}
# THE DIFFERENCE, by the profile's real chord and two real clicks
proc diff {first second} {
    key D [expr {$::SHIFT | $::ALT}]
    set m [armed]
    click $first
    click $second
    return $m
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
# the viewer's traces as {vec expr}, and the new ones
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
proc label_of {vec} {
    set hit NOTRACE
    catch {
        foreach G [dict get [wviewer::layout_for $::key] graphs] {
            foreach t [dict get $G traces] { if {[dict get $t vec] eq $vec} { set hit [wviewer::trace_label $t] } }
        }
    }
    return $hit
}
# the expressions of the traces drawn from vector `vec`, in the order of the strips
proc exprs_of {vec} {
    set out {}
    foreach t [traces] { if {[lindex $t 0] eq $vec} { lappend out [lindex $t 1] } }
    return $out
}
# where the first trace drawn from vector `vec` stands: {strip trace}, as the
# Delete key's command takes it
proc where_is {vec} {
    set at {-1 -1}
    catch {
        set g 0
        foreach G [dict get [wviewer::layout_for $::key] graphs] {
            set t 0
            foreach tr [dict get $G traces] {
                if {[lindex $at 0] < 0 && [dict get $tr vec] eq $vec} { set at [list $g $t] }
                incr t
            }
            incr g
        }
    }
    return $at
}
# 1 when two lists of numbers differ, at every place, by far more than the
# bar's rounding
proc far_apart {l1 l2} {
    if {[llength $l1] != [llength $l2] || ![llength $l1]} { return 0 }
    foreach a $l1 b $l2 {
        if {![string is double -strict $a] || ![string is double -strict $b] || abs($a - $b) < 0.01} { return 0 }
    }
    return 1
}
# `n` real presses of a key on the viewer's canvas, the keyboard put there first
proc vkey {ks {n 1} {st 0}} {
    if {[catch {
        set w [wviewer::window_for $::key].drw
        update
        for {set i 0} {$i < 40} {incr i} {
            focus -force $w ; update
            if {[focus -displayof $w] eq $w} break
            after 25
        }
        set px [expr {[winfo width $w] / 2}]
        set py [expr {[winfo height $w] / 2}]
        event generate $w <Motion> -x $px -y $py -when now
        for {set i 0} {$i < $n} {incr i} {
            event generate $w <KeyPress> -keysym $ks -state $st -x $px -y $py -when now
            event generate $w <KeyRelease> -keysym $ks -state $st -x $px -y $py -when now
        }
        update
    } e]} { return "ERR:$e" }
    return {}
}
# run `script` with the viewer's data current, and put the context back
proc in_viewer {script} {
    if {[catch {wviewer::enter_ctx $::key} t] || ![lindex $t 0]} { return NOCTX }
    set code [catch {uplevel 1 $script} r]
    catch {wviewer::leave_ctx $::key $t}
    if {$code} { return "ERR:$r" }
    return $r
}
# sample `k` of a vector of the result the viewer shows, read from the file's
# own column
proc smp {name k} { return [in_viewer [list xschem raw value $name $k]] }
# a number as the readout bar writes one, read back as a number
proc eng_num {s} {
    if {[string is double -strict $s]} { return [expr {double($s)}] }
    if {![regexp {^([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)(f|p|n|u|m|k|Meg|G|T)$} $s -> m sfx]} { return $s }
    if {![string is double -strict $m]} { return $s }
    return [expr {$m * [dict get {f 1e-15 p 1e-12 n 1e-9 u 1e-6 m 1e-3 k 1e3 Meg 1e6 G 1e9 T 1e12} $sfx]}]
}
# THE READOUT BAR: cursor A put at `x` in the session's viewer, the bar filled
# by the viewer's own proc, and its line read off the widget: one {label
# number} pair per trace the bar names. A trace with no data has no entry.
proc readout {x} {
    set top [pcall wviewer::window_for $::key]
    if {$top eq {} || [string match ERR:* $top] || ![winfo exists $top.wvreadout.a]} { return {} }
    in_viewer [list apply {{x} { xschem cursor 1 1 ; xschem set cursor1_x $x }} $x]
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
proc rd_at {label times} {
    set out {}
    foreach x $times {
        set v MISSING
        foreach p [readout $x] { if {[lindex $p 0] eq $label} { set v [lindex $p 1] ; break } }
        lappend out $v
    }
    return $out
}
# THE SAMPLES THE ROWS READ AT, of the first sweep of the file's transient, and
# the times of those samples
set ::KS {13 47 88}
proc times {} { return [lmap k $::KS {smp time $k}] }
# what a two-vector arithmetic of the file reads at those samples, done here;
# a sample that could not be read (the viewer's data is not the result) makes
# its entry NOSAMPLE, which no reading equals, and does not end the band
proc at_ks {script} {
    set out {}
    foreach k $::KS {
        if {[catch {uplevel 1 [list apply [list k $script] $k]} v]} { set v NOSAMPLE }
        lappend out $v
    }
    return $out
}
# every load of results into a viewer, counted where the load is made
set ::NATT 0
proc att_seen {args} { incr ::NATT }
catch {trace add execution ::ase::attach_dbs enter att_seen}
proc clean_viewer {} {
    catch {wviewer::clear_all $::key}
    update
}
proc lost_said {} { return [llength [lsearch -all -glob $::notices {wviewer: trace * is empty*}]] }

group FS {
    check "FS1 fixture: src/cadence_style_rc sourced, and binds the difference and Direct Plot on the design canvas" \
        [list $::RCRC [expr {[bind .drw <Alt-Key-D>] ne {}}] [expr {[bind .drw <Control-Key-4>] ne {}}]] {0 1 1}
    update
    check "FS2 fixture: the sheet loads and resolves to a registered cellview" \
        [list [catch {xschem load $::top}] [pcall ase::design_of_path $::top]] {0 {relib re_top schematic}}
    xschem zoom_full ; update
    set ::key [pcall ase::new_session relib re_top schematic]
    set st [pcall ase::session_state $::key]
    catch {
        dict set st rundir $::rundir
        set rows {}
        foreach a [dict get $st analyses] { lappend rows [dict replace $a enabled [expr {[dict get $a type] in {op tran} ? 1 : 0}]] }
        dict set st analyses $rows
    }
    pcall ase::session_update $::key $st
    re_run
    check "FS3 fixture: a session is bound to the sheet, shows its viewer the transient, and finds the real results file where a run leaves it" \
        [list [lindex [pcall ase::session_for_current] 0] [pcall ase::plot_sim_type [pcall ase::session_state $::key]] [pcall ase::last_rawfile $::key]] \
        [list $::key tran $::rawpath]
}

# ---------------------------------------------------------------------------
# RA -- the difference of two nets on the real file, then a real Direct Plot
# ---------------------------------------------------------------------------
group RA {
    to_design
    set before [traces]
    set m [diff div ramp]
    set vec [lindex [lindex [newtraces $before] 0] 0]
    set lab [label_of $vec]
    set T [times]
    set want [at_ks {expr {[smp v(ramp) $k] - [smp v(div) $k]}}]
    set far 1
    foreach w $want { if {abs($w) < 0.01} { set far 0 } }
    check "RA0 fixture: the real chord and two real clicks plot one difference; at the samples the rows read, the file's own two columns differ by far more than the bar's rounding, so second minus first is neither zero nor first minus second there" \
        [list $m [llength [newtraces $before]] $far [llength $T]] {diff 1 1 3}
    check "RA1 before any Direct Plot the readout bar, its cursor put at three sample times of the file, reads the difference as ramp minus div computed here from the file's two columns" \
        [near [rd_at $lab $T] $want 2e-3] ok
    set n0 $::NATT
    set mid [traces]
    set m [dplot lp]
    check "RA2 a real Direct Plot -- Ctrl-4, a real click on net lp, ESC -- plots that net and loads the results into the viewer once more" \
        [list $m [lmap t [newtraces $mid] {lindex $t 0}] [expr {$::NATT - $n0}]] {plot v(lp) 1}
    check "RA3 after it the difference still reads ramp minus div at the same three times, beside the net just plotted" \
        [list [near [rd_at $lab $T] $want 2e-3] [near [rd_at v(lp) $T] [at_ks {smp v(lp) $k}] 2e-3]] {ok ok}
    check "RA4 ...under the label of a difference: v(<second>)-v(<first>)" $lab {v(ramp)-v(div)}
}

# ---------------------------------------------------------------------------
# RB -- the Calculator's Plot button, then a real Direct Plot
# ---------------------------------------------------------------------------
group RB {
    to_design
    clean_viewer
    dplot dcmid
    check "RB0 fixture: the Calculator opens and finds the session's viewer as the holder of the selected result" \
        [list [pcall calc::open] [dg [pcall calc::require_result] token]] [list .calc $::key]
    update idletasks
    set before [traces]
    catch {.calc.buf delete 1.0 end}
    catch {.calc.buf insert 1.0 {vt(ramp) * vt(div)}}
    update idletasks
    pcall .calc.mode.plot invoke
    update
    set new [newtraces $before]
    set vec [lindex [lindex $new 0] 0]
    set lab [label_of $vec]
    set T [times]
    set want [at_ks {expr {[smp v(ramp) $k] * [smp v(div) $k]}}]
    check "RB1 the Plot button plots the buffer's expression as one trace, named as the viewer names an expression it is not given a name for, and the bar reads the product of the file's two columns" \
        [list [llength $new] [lindex [lindex $new 0] 1] [regexp {^expr[0-9]+$} $lab] [expr {$lab eq $vec}] [near [rd_at $lab $T] $want 2e-3]] \
        {1 {v(ramp) v(div) *} 1 1 ok}
    set n0 $::NATT
    set m [dplot sq]
    check "RB2 after a real Direct Plot, which loads the results once more, the Calculator's trace still reads the product, under the name it had" \
        [list $m [expr {$::NATT - $n0}] [label_of $vec] [near [rd_at $lab $T] $want 2e-3]] [list plot 1 $lab ok]
    pcall calc::close
    update
}

# ---------------------------------------------------------------------------
# RC -- Graph > Add Trace's door on an expression, then a real Direct Plot
# ---------------------------------------------------------------------------
group RC {
    to_design
    clean_viewer
    dplot div
    set before [traces]
    set err [pcall wviewer::add_trace $::key 0 {v(ramp) 2 *} twice]
    update
    set new [newtraces $before]
    set T [times]
    set want [at_ks {expr {2.0 * [smp v(ramp) $k]}}]
    check "RC1 an expression added through the Add Trace door, with a name of the user's, is one trace under that name and reads twice the file's column" \
        [list $err [llength $new] [label_of twice] [near [rd_at twice $T] $want 2e-3]] {{} 1 twice ok}
    set n0 $::NATT
    set m [dplot sq]
    check "RC2 after a real Direct Plot it still reads twice the column, under the user's name" \
        [list $m [expr {$::NATT - $n0}] [label_of twice] [near [rd_at twice $T] $want 2e-3]] {plot 1 twice ok}
    # an expression over another expression's trace
    set err [pcall wviewer::add_trace $::key 0 {twice 1 +} more]
    update
    set want2 [at_ks {expr {2.0 * [smp v(ramp) $k] + 1.0}}]
    set m [dplot lp]
    check "RC3 an expression that names another expression's trace is evaluated after the one it names: both read after a Direct Plot" \
        [list $err $m [near [rd_at twice $T] $want 2e-3] [near [rd_at more $T] $want2 2e-3]] {{} plot ok ok}
    # TWO TRACES COMPUTED INTO ONE VECTOR. The second add of a name computes
    # the vector again, so both traces show the expression added last. A load
    # has to leave them so. Once with the trace added last standing after the
    # other in the strips, once with it standing before the other.
    clean_viewer
    dplot div
    set e1 [pcall wviewer::add_trace $::key 0 {v(ramp) 2 *} dup]
    set e2 [pcall wviewer::add_trace $::key 0 {v(ramp) 3 *} dup]
    update
    set w3 [at_ks {expr {3.0 * [smp v(ramp) $k]}}]
    set w2 [at_ks {expr {2.0 * [smp v(ramp) $k]}}]
    set order [exprs_of dup]
    set live [near [rd_at dup $T] $w3 2e-3]
    set m [dplot sq]
    check "RC4 two expressions added under one name, the second standing after the first in the strips: before a Direct Plot the bar reads the second one, three times the column, and after it the bar still does" \
        [list $e1 $e2 $order $live $m [near [rd_at dup $T] $w3 2e-3] [expr {[near [rd_at dup $T] $w2 2e-3] eq {ok} ? {FIRST} : {not-first}}]] \
        {{} {} {{v(ramp) 2 *} {v(ramp) 3 *}} ok plot ok not-first}
    clean_viewer
    dplot div
    pcall wviewer::add_graph $::key
    update
    set ng [llength [dict get [wviewer::layout_for $::key] graphs]]
    set e1 [pcall wviewer::add_trace $::key [expr {$ng - 1}] {v(ramp) 2 *} dup]
    set e2 [pcall wviewer::add_trace $::key 0 {v(ramp) 3 *} dup]
    update
    set order [exprs_of dup]
    set live [near [rd_at dup $T] $w3 2e-3]
    set m [dplot sq]
    check "RC5 ...and with the second one standing before the first in the strips (it was added to a strip above): the bar reads the second one before a Direct Plot and after it" \
        [list $e1 $e2 [expr {$ng > 1}] $order $live $m [near [rd_at dup $T] $w3 2e-3]] \
        {{} {} 1 {{v(ramp) 3 *} {v(ramp) 2 *}} ok plot ok}
}

# ---------------------------------------------------------------------------
# RD -- an ASE-L Outputs row holding an expression, plotted by the plot a
# finished run makes, then a real Direct Plot
# ---------------------------------------------------------------------------
group RD {
    to_design
    clean_viewer
    set st0 [pcall ase::session_state $::key]
    set st $st0
    catch { dict set st outputs [list [dict create name HALF expr {vt(ramp) / 2} save 0 plot 1]] }
    catch { dict set st plot_dest append }
    pcall ase::session_update $::key $st
    set before [traces]
    set n0 $::NATT
    pcall ase::ui::auto_plot $::key
    update
    set new [newtraces $before]
    set T [times]
    set want [at_ks {expr {[smp v(ramp) $k] / 2.0}}]
    check "RD1 the plot a finished run makes plots the Outputs row's expression as one trace under the row's name, and the bar reads half the file's column" \
        [list [expr {$::NATT - $n0}] [llength $new] [lindex [lindex $new 0] 1] [label_of HALF] [near [rd_at HALF $T] $want 2e-3]] \
        {1 1 {v(ramp) 2 /} HALF ok}
    set m [dplot sq]
    check "RD2 after a real Direct Plot it still reads half the column, under the row's name" \
        [list $m [label_of HALF] [near [rd_at HALF $T] $want 2e-3]] {plot HALF ok}
    # a row with no name of its own, under the destination Replace, over three
    # runs: the viewer names its trace, and the name must be the one it had
    clean_viewer
    set st $st0
    catch { dict set st outputs [list [dict create name {} expr {-vt(ramp)} save 0 plot 1]] }
    catch { dict set st plot_dest replace }
    pcall ase::session_update $::key $st
    set names {}
    set reads {}
    set wantn [at_ks {expr {-1.0 * [smp v(ramp) $k]}}]
    foreach run {1 2 3} {
        re_run
        pcall ase::ui::auto_plot $::key
        update
        set vecs [lmap t [traces] {lindex $t 0}]
        lappend names $vecs
        lappend reads [near [rd_at [lindex $vecs 0] $T] $wantn 2e-3]
    }
    check "RD3 an Outputs row with no name of its own, plotted by three runs in a row under the destination Replace, is one trace each time, under the same name the viewer gave it at the first run, and reads minus the column each time" \
        [list [lsort -unique $names] [regexp {^expr[0-9]+$} [lindex $names 0]] $reads] [list [list [lindex $names 0]] 1 {ok ok ok}]
    pcall ase::session_update $::key $st0
}

# ---------------------------------------------------------------------------
# RW -- a Calculator wave: a table of its own in the viewer's data, drawn
# against its own X. A load must keep that table, and a result written again
# leaves the wave as the user made it.
# ---------------------------------------------------------------------------
group RW {
    to_design
    clean_viewer
    dplot div
    set T [times]
    set xs [list 0 [lindex $T 0] [lindex $T 1] [lindex $T 2] 0.02]
    set ys {1.5 2.5 0.5 3.5 4.5}
    set d [in_viewer {calc::wave_dest $xs $ys cx cy}]
    set db [dg $d db]
    set h [pcall calc::wave_in_token $::key $d]
    update
    set want [lrange $ys 1 3]
    check "RW0 fixture: the Calculator's own producer and hand-off put a wave in the viewer: a table in the viewer's data and a trace that the bar reads the wave's own samples from" \
        [list [dg $d ok] [dg $h ok] [expr {[lsearch -exact [in_viewer reg_slots] [list $db table]] >= 0}] [near [rd_at cy $T] $want 2e-3]] {1 1 1 ok}
    set n0 $::NATT
    set m [dplot sq]
    set slots [in_viewer reg_slots]
    check "RW1 after a real Direct Plot, which loads the results once more, the wave's table is still in the viewer's data, the result is the current database there, and the bar still reads the wave's samples" \
        [list $m [expr {$::NATT - $n0}] [expr {[lsearch -exact $slots [list $db table]] >= 0}] \
              [lindex $slots [in_viewer reg_cur]] [near [rd_at cy $T] $want 2e-3]] [list plot 1 1 [list $::rawpath tran] ok]
    check "RW2 ...beside the nets of the result, which still read the file's columns" \
        [near [rd_at v(sq) $T] [at_ks {smp v(sq) $k}] 2e-3] ok
    # the bench run again: the same file written again, a later time
    re_run
    set n0 $::NATT
    set m [dplot ramp]
    check "RW3 after the results file was written again and loaded by a real Direct Plot, the wave is as the user made it: its table is still there and the bar reads the same samples" \
        [list $m [expr {$::NATT - $n0}] [expr {[lsearch -exact [in_viewer reg_slots] [list $db table]] >= 0}] [near [rd_at cy $T] $want 2e-3]] {plot 1 1 ok}
    # a wave whose trace is gone is not kept
    set d2 [in_viewer {calc::wave_dest {0 1} {5 6} cx cy}]
    set db2 [dg $d2 db]
    set had [expr {[lsearch -exact [in_viewer reg_slots] [list $db2 table]] >= 0}]
    set m [dplot lp]
    set slots [in_viewer reg_slots]
    check "RW4 a table no trace of the viewer draws from is dropped by the next load, as every database a load did not read was; the wave's table stays, the result is still the current database with a table kept below it and one dropped, and the net just plotted reads the file's column" \
        [list [dg $d2 ok] $had $m [expr {[lsearch -exact $slots [list $db2 table]] >= 0}] \
              [expr {[lsearch -exact $slots [list $db table]] >= 0}] [lindex $slots [in_viewer reg_cur]] \
              [near [rd_at v(lp) $T] [at_ks {smp v(lp) $k}] 2e-3] [near [rd_at cy $T] $want 2e-3]] \
        [list 1 1 plot 0 1 [list $::rawpath tran] ok ok]
    # the wave in a tab that is not shown: a second tab is opened and takes a
    # Direct Plot, which loads the results once, and the first tab is shown again
    set id1 [pcall wviewer::tab_id $::key]
    set id2 [pcall wviewer::new_tab $::key]
    update
    set n0 $::NATT
    set m [dplot sq]
    set in2 [lmap t [traces] {lindex $t 0}]
    pcall wviewer::select_tab $id1 $::key
    update
    set slots [in_viewer reg_slots]
    check "RW5 with the wave in a tab that is not shown, a real Direct Plot into another tab loads the results once and keeps the wave's table; with the first tab shown again the bar reads the wave's samples" \
        [list [expr {$id2 ne {} && $id2 ne $id1}] $m $in2 [expr {$::NATT - $n0}] \
              [expr {[lsearch -exact $slots [list $db table]] >= 0}] [near [rd_at cy $T] $want 2e-3]] {1 plot v(sq) 1 1 ok}
    pcall wviewer::close_tab $id2 $::key
    update
}

# ---------------------------------------------------------------------------
# RV -- A DATABASE READ FROM A FILE IS NOT KEPT, whether its file is still on
# disk or not. A run deletes the digital results of the run before it, so that
# a trace cannot go on showing them beside the new analog result; a load that
# kept every database whose file is gone would bring exactly that back. Here
# the second database is a copy of the results file, read into the viewer's
# data beside the session's and plotted from; then the copy is deleted, as a
# run deletes a file, and a real Direct Plot loads the results. A Calculator
# wave stands beside it through the same load: that one is kept.
# ---------------------------------------------------------------------------
group RV {
    to_design
    clean_viewer
    dplot div
    set T [times]
    set other [file join $::rundir re_other.raw]
    file copy -force $::RAWFIX $other
    set rd [in_viewer {
        set r [xschem raw read $other tran]
        xschem raw switch $::rawpath tran
        set r
    }]
    set at [lsearch -exact [in_viewer reg_slots] [list $other tran]]
    set err [pcall wviewer::add_trace $::key 0 v(lp) {} {} $at]
    update
    set tr {}
    catch { foreach G [dict get [wviewer::layout_for $::key] graphs] { foreach t [dict get $G traces] { if {[dict get $t vec] eq {v(lp)}} { set tr $t } } } }
    set xs [list 0 [lindex $T 0] [lindex $T 1] [lindex $T 2] 0.02]
    set ys {1.5 2.5 0.5 3.5 4.5}
    set d [in_viewer {calc::wave_dest $xs $ys cx cy}]
    set db [dg $d db]
    set h [pcall calc::wave_in_token $::key $d]
    update
    check "RV0 fixture: a copy of the results file is read into the viewer's data beside the session's result, a net is plotted from that database (its trace names the copy), and a Calculator wave stands beside it; the bar reads both" \
        [list $rd [expr {$at >= 0}] $err [pcall wviewer::dget $tr rawfile {}] [lindex [in_viewer reg_slots] [in_viewer reg_cur]] \
              [near [rd_at v(lp) $T] [at_ks {smp v(lp) $k}] 2e-3] [dg $h ok] [near [rd_at cy $T] [lrange $ys 1 3] 2e-3]] \
        [list 1 1 {} $other [list $::rawpath tran] ok 1 ok]
    file delete -force $other
    set m [dplot sq]
    set slots [in_viewer reg_slots]
    check "RV1 with the copy deleted from disk, a real Direct Plot loads the results: the database read from the copy is gone from the viewer's data and the bar has no entry for its trace, while the Calculator's table is kept and its wave still reads" \
        [list [file exists $other] $m [expr {[lsearch -exact $slots [list $other tran]] >= 0}] [rd_at v(lp) [list [lindex $T 0]]] \
              [expr {[lsearch -exact $slots [list $db table]] >= 0}] [near [rd_at cy $T] [lrange $ys 1 3] 2e-3] [lindex $slots [in_viewer reg_cur]]] \
        [list 0 plot 0 MISSING 1 ok [list $::rawpath tran]]
}

# ---------------------------------------------------------------------------
# RU -- UNDO BRINGS A TRACE BACK AFTER A LOAD. An expression trace is cleared
# (Graph > Clear SubWin's command), a real Direct Plot loads the results, which
# makes no vector for a trace that is not there, and the real undo key on the
# viewer's canvas brings the cleared strip back: its trace has to read.
# ---------------------------------------------------------------------------
group RU {
    to_design
    clean_viewer
    dplot div
    set T [times]
    # an expression trace in a first tab, which stays through everything below
    set e0 [pcall wviewer::add_trace $::key 0 {v(div) 3 *} stay]
    set id1 [pcall wviewer::tab_id $::key]
    set id2 [pcall wviewer::new_tab $::key]
    update
    dplot div
    set err [pcall wviewer::add_trace $::key 0 {v(ramp) 2 *} twice]
    update
    set want [at_ks {expr {2.0 * [smp v(ramp) $k]}}]
    set r0 [near [rd_at twice $T] $want 2e-3]
    set cl [pcall wviewer::clear_target_subwin $::key]
    update
    set gone [label_of twice]
    set m [dplot sq]
    # every evaluation of an expression into the data, counted where it is made
    set ::NADD {}
    proc add_seen {cmd args} { if {[string match {xschem raw add *} $cmd]} { lappend ::NADD [lindex $cmd 3] } }
    catch {trace add execution ::xschem enter add_seen}
    set presses 0
    set kerr {}
    while {$presses < 4 && [label_of twice] eq {NOTRACE}} {
        append kerr [vkey u]
        incr presses
    }
    catch {trace remove execution ::xschem enter add_seen}
    check "RU1 an expression trace cleared with its subwindow, a real Direct Plot, and the real undo key on the viewer until the cleared strip is back: the trace is in its strip again and the bar reads twice the file's column" \
        [list $e0 $err $r0 [expr {$cl ne {}}] $gone $m $kerr [expr {$presses >= 1 && $presses < 4}] [label_of twice] [near [rd_at twice $T] $want 2e-3]] \
        {{} {} ok 1 NOTRACE plot {} 1 twice ok}
    check "RU3 the undo evaluated the one vector the data lacked and no other: the expression trace of the first tab, whose vector the Direct Plot's load had made, was not computed again" \
        [list [expr {$id2 ne {} && $id2 ne $id1}] $::NADD] {1 twice}
    set d0 [pcall wviewer::history_depth $::key]
    vkey U 1 $::SHIFT
    set back [label_of twice]
    set d1 [pcall wviewer::history_depth $::key]
    vkey u
    check "RU2 ...and after the real redo key (one step moves from the redo side to the undo side) takes the strip away and undo brings it back once more, it reads again" \
        [list [expr {[lindex $d1 0] - [lindex $d0 0]}] [expr {[lindex $d1 1] - [lindex $d0 1]}] $back [label_of twice] [near [rd_at twice $T] $want 2e-3]] {1 -1 NOTRACE twice ok}
    pcall wviewer::select_tab $id1 $::key
    update
    check "RU4 ...and the first tab's expression trace, shown again, reads three times its column" \
        [near [rd_at stay $T] [at_ks {expr {3.0 * [smp v(div) $k]}}] 2e-3] ok
    pcall wviewer::close_tab $id2 $::key
    update
    # THE NAME OF A VECTOR TAKEN BY A LATER TRACE, with no run between. A
    # difference is deleted (the Delete key's command), a real Direct Plot
    # loads the results, which makes no vector for a trace that is gone, and a
    # second difference, of other nets, is computed into the name that is then
    # free. Undo brings the first one back while the data holds the second
    # one's numbers under that name.
    clean_viewer
    dplot dcmid
    set before [traces]
    diff div ramp
    set v1 [lindex [lindex [newtraces $before] 0] 0]
    set nd [pcall wviewer::delete_items {} [list [where_is $v1]] {} $::key]
    update
    set m [dplot sq]
    set before [traces]
    diff div lp
    set v2 [lindex [lindex [newtraces $before] 0] 0]
    set w1 [at_ks {expr {[smp v(ramp) $k] - [smp v(div) $k]}}]
    set w2 [at_ks {expr {[smp v(lp) $k] - [smp v(div) $k]}}]
    set r2 [near [rd_at {v(lp)-v(div)} $T] $w2 2e-3]
    set presses 0
    while {$presses < 4 && [label_of $v1] ne {v(ramp)-v(div)}} { vkey u ; incr presses }
    check "RU5 a difference deleted, a real Direct Plot, a second difference of another net computed into the vector name the first one left free, and the real undo key until the first is back: under its own label the bar reads ramp minus div of the file, which at these samples is far from the second one's lp minus div" \
        [list $nd $m [expr {$v1 ne {} && $v1 eq $v2}] [far_apart $w1 $w2] $r2 [expr {$presses >= 1 && $presses < 4}] [label_of $v1] [near [rd_at {v(ramp)-v(div)} $T] $w1 2e-3]] \
        {1 plot 1 1 ok 1 v(ramp)-v(div) ok}
    # ...AND A TRACE COMPUTED FROM THAT VECTOR. `over` names `base`. `base` is
    # deleted and the results are loaded; a second `base`, of another
    # expression, takes the name, and a second load computes `over` from it.
    # Undo brings the first `base` back: the data holds both vectors, and both
    # were computed from the second one.
    clean_viewer
    dplot dcmid
    set e1 [pcall wviewer::add_trace $::key 0 {v(ramp) 2 *} base]
    set e2 [pcall wviewer::add_trace $::key 0 {base 1 +} over]
    update
    set nd [pcall wviewer::delete_items {} [list [where_is base]] {} $::key]
    update
    dplot sq
    set e3 [pcall wviewer::add_trace $::key 0 {v(div) 5 *} base]
    update
    set m [dplot lp]
    set wb1 [at_ks {expr {2.0 * [smp v(ramp) $k]}}]
    set wo1 [at_ks {expr {2.0 * [smp v(ramp) $k] + 1.0}}]
    set wo2 [at_ks {expr {5.0 * [smp v(div) $k] + 1.0}}]
    set mid [list [exprs_of base] [near [rd_at over $T] $wo2 2e-3]]
    set presses 0
    while {$presses < 4 && [exprs_of base] ne {{v(ramp) 2 *}}} { vkey u ; incr presses }
    check "RU6 an expression trace deleted while another trace is computed from its vector, a real Direct Plot, a second expression added under the same name, a second Direct Plot (the other trace then reads the second expression plus one), and the real undo key until the first is back: the bar reads the first expression, twice the file's column, under the name" \
        [list $e1 $e2 $nd $e3 $m $mid [far_apart $wo1 $wo2] [expr {$presses >= 1 && $presses < 4}] [exprs_of base] [near [rd_at base $T] $wb1 2e-3]] \
        {{} {} 1 {} plot {{{v(div) 5 *}} ok} 1 1 {{v(ramp) 2 *}} ok}
    check "RU7 ...and the trace computed from it, whose vector the data still held, reads the first expression plus one and not the second" \
        [near [rd_at over $T] $wo1 2e-3] ok
}

# ---------------------------------------------------------------------------
# RP -- A PASTE INTO ANOTHER WINDOW IS ON RECORD THERE. An expression trace
# copied from one viewer and pasted into a second one (the real copy and paste
# commands; the selection is set on the strip as a click sets it) is computed
# in the second window's data. That window has to know which analysis it was
# computed on, as it knows of a trace added there: made to show the AC
# analysis, it must not draw the transient's expression from AC columns.
# ---------------------------------------------------------------------------
# run `script` with the helpers of this file aimed at another session's viewer
proc as_key {k script} {
    set k0 $::key
    set ::key $k
    set code [catch {uplevel 1 $script} r]
    set ::key $k0
    if {$code} { return "ERR:$r" }
    return $r
}
# the vector of the shown tab's trace of postfix `ex` ({}: none), and where a
# vector's trace stands: `{strip trace node}`
proc rp_vec {ex} {
    foreach t [traces] { if {[lindex $t 1] eq $ex} { return [lindex $t 0] } }
    return {}
}
proc rp_where {vec} {
    set out {-1 -1 -1}
    catch {
        set g 0
        foreach G [dict get [wviewer::layout_for $::key] graphs] {
            set t 0
            foreach tr [dict get $G traces] {
                if {[dict get $tr vec] eq $vec} { set out [list $g $t [wviewer::node_index_of_trace $G $t]] }
                incr t
            }
            incr g
        }
    }
    return $out
}
group RP {
    to_design
    clean_viewer
    dplot div
    set T [times]
    set err [pcall wviewer::add_trace $::key 0 {v(ramp) v(div) +} sum]
    update
    set want [at_ks {expr {[smp v(ramp) $k] + [smp v(div) $k]}}]
    # select the trace on its strip, as a click on it does, and copy
    set gi -1 ; set ni -1
    catch {
        set g 0
        foreach G [dict get [wviewer::layout_for $::key] graphs] {
            set t 0
            foreach tr [dict get $G traces] {
                if {[dict get $tr vec] eq {sum}} { set gi $g ; set ni [wviewer::node_index_of_trace $G $t] }
                incr t
            }
            incr g
        }
    }
    pcall wviewer::regenerate $::key
    in_viewer [list apply {{key gi ni} {
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi sel_waves [list $ni]]
    }} $::key $gi $ni]
    set nc [pcall wviewer::copy_traces $::key]
    # a second session with a viewer of its own, shown the same result
    set k2 [pcall ase::new_session relib re_two schematic]
    set st [pcall ase::session_state $k2]
    catch { dict set st rundir $::rundir }
    pcall ase::session_update $k2 $st
    set op [pcall wviewer::open $k2]
    update
    set at [pcall wviewer::attach_raw $k2 $::rawpath tran]
    update
    set np [pcall wviewer::paste_traces $k2]
    update
    set lab2 [as_key $k2 {label_of sum}]
    check "RP1 an expression trace selected and copied in one viewer and pasted into a second viewer that shows the same result: the paste lands one trace, and the second window's bar reads the sum of the file's two columns under its name" \
        [list $err [expr {$gi >= 0 && $ni >= 0}] $nc [expr {$k2 ne $::key && ![string match ERR:* $k2]}] $op $at $np $lab2 \
              [as_key $k2 {near [rd_at sum $T] $want 2e-3}]] \
        {{} 1 1 1 1 1 1 sum ok}
    set ::notices {}
    set a [pcall wviewer::attach_raw $k2 $::rawpath ac]
    update
    check "RP2 with the second viewer made to show the file's AC analysis, the pasted trace is not drawn from AC columns: it stays in its strip, the bar has no entry for it, and one sentence says it was computed on the transient analysis" \
        [list $a [as_key $k2 {label_of sum}] [as_key $k2 {rd_at sum [list [lindex $T 0]]}] \
              [nsaid "wviewer: trace 'sum' is empty: it was computed on the transient analysis and the viewer now shows the AC analysis of [file tail $::rawpath]; it draws again when the viewer shows the transient analysis"] [lost_said]] \
        {1 sum MISSING 1 1}
    catch {wviewer::close $k2}
    pcall ase::session_close $k2
    update
    to_design
    # THE WINDOW THE TRACE WAS COPIED FROM, after the name of its vector was
    # taken. An expression the viewer names is copied and deleted; a real
    # Direct Plot loads the results, which makes no vector for a trace that is
    # gone, so the name is free; a second expression is computed into it; the
    # paste then has to compute into a name of its own, or the second trace
    # would draw the pasted expression under its own label.
    clean_viewer
    dplot div
    set e1 [pcall wviewer::add_trace $::key 0 {v(ramp) v(div) +}]
    update
    set v1 [rp_vec {v(ramp) v(div) +}]
    lassign [rp_where $v1] gi ti ni
    pcall wviewer::regenerate $::key
    in_viewer [list apply {{key gi ni} {
        wviewer::with_edit $key [list xschem setprop -fast rect 2 $gi sel_waves [list $ni]]
    }} $::key $gi $ni]
    set nc [pcall wviewer::copy_traces $::key]
    set nd [pcall wviewer::delete_items {} [list [list $gi $ti]] {} $::key]
    update
    to_design
    set m [dplot ramp]
    set e2 [pcall wviewer::add_trace $::key 0 {v(ramp) v(div) -}]
    update
    set v2 [rp_vec {v(ramp) v(div) -}]
    set np [pcall wviewer::paste_traces $::key]
    update
    set v3 [rp_vec {v(ramp) v(div) +}]
    check "RP3 an expression the viewer named, copied and deleted, a real Direct Plot, a second expression computed into the name the first one's vector left free, and the paste into that same window: the pasted trace is computed into a vector of its own and shown by that name, it reads the sum of the file's two columns, and the second expression still reads their difference" \
        [list $e1 $nc $nd $m $e2 [expr {$v1 ne {} && $v1 eq $v2}] $np [expr {$v3 ne {} && $v3 ne $v2}] [label_of $v3] [label_of $v2] \
              [near [lmap k $::KS {smp $v3 $k}] [at_ks {expr {[smp v(ramp) $k] + [smp v(div) $k]}}] 2e-3] \
              [near [lmap k $::KS {smp $v2 $k}] [at_ks {expr {[smp v(ramp) $k] - [smp v(div) $k]}}] 2e-3]] \
        [list {} 1 1 plot {} 1 1 1 $v3 $v2 ok ok]
    clean_viewer
    to_design
}

# ---------------------------------------------------------------------------
# RL -- an expression and the analysis it was computed on
# ---------------------------------------------------------------------------
group RL {
    to_design
    clean_viewer
    dplot div
    set before [traces]
    set err [pcall wviewer::add_trace $::key 0 {v(ramp) v(div) +} sum]
    update
    set T [times]
    check "RL0 fixture: an expression over two columns of the file reads" \
        [list $err [near [rd_at sum $T] [at_ks {expr {[smp v(ramp) $k] + [smp v(div) $k]}}] 2e-3]] {{} ok}
    # the viewer made to show the file's AC analysis, by the viewer's own load.
    # That analysis holds both vectors the expression names, so nothing is
    # missing: it is the analysis that differs from the one the trace was
    # computed on
    set ::notices {}
    set a [pcall wviewer::attach_raw $::key $::rawpath ac]
    update
    check "RL1 with the viewer made to show the file's AC analysis, the trace computed on the transient stays in its strip, is empty, and one sentence says which trace, both analyses and when it draws again" \
        [list $a [label_of sum] [rd_at sum [list [lindex $T 0]]] \
              [nsaid "wviewer: trace 'sum' is empty: it was computed on the transient analysis and the viewer now shows the AC analysis of [file tail $::rawpath]; it draws again when the viewer shows the transient analysis"] [lost_said]] \
        {1 sum MISSING 1 1}
    set ::notices {}
    set m [dplot sq]
    check "RL2 a real Direct Plot shows the viewer the transient again: the trace reads again and nothing is said about an empty trace" \
        [list $m [near [rd_at sum $T] [at_ks {expr {[smp v(ramp) $k] + [smp v(div) $k]}}] 2e-3] [lost_said]] {plot ok 0}
    check "RL3 no click of this suite landed off the point it was sent to" $::MISSED {}
}

}

} bigerr]} {
    puts "FAIL: UNEXPECTED ERROR -> $bigerr : FAIL"
    puts $::errorInfo
    incr fail
}

catch {rename ciw_echo {}}
if {[info commands re_real_ciw_echo] ne {}} { catch {rename re_real_ciw_echo ciw_echo} }

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
