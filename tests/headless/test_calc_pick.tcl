# tests/headless/test_calc_pick.tcl — the Calculator's NET PICK, the half that
# only a real display can measure: the seize, the gesture, the undo, the prompt,
# and the three ways the mode has to be able to end.
#
# The DECISION layer is fenced on the counted arm by
# tests/headless/test_calc_selector_names.tcl, which is an `hcases` entry.  This
# file is a `dcases` entry and NOTHING ELSE: its subject is a Tcl seize of a real
# design canvas, so its headless arm would self-skip to zero rows and an `hcases`
# entry would be scored a HARNESS failure for a case that measured nothing (issue
# 1641's incident, and issue 1626's).
#
# Spec     doc/claude/specs/calculator.md §5.1 (R201-R208), §6 (R301-R307)
# Issues   0173 (the viewer context loan), 0201 (the cmdmode contract),
#          0204 (a probe selects nothing, and the canvas needs the focus),
#          1303 (the un-snapped pair), 1304 (the FOURTH seized sequence),
#          1305 (a permanently seized canvas), 1308 (suspended counts as running)
#
# ⚠ THE GESTURE IS GENERATED, AND THE SPELLING IS NOT NEGOTIABLE.  A Tk button
# runs its `-command` on RELEASE, and press+release still fires NOTHING without a
# preceding `<Enter>` and explicit `-x`/`-y`, because the Button class bindings
# track which window the pointer entered and refuse a release that did not begin
# on the widget.  The working gesture is Enter -> press -> release WITH
# coordinates, plus a `<Leave>` to cancel the tooltip timer the Enter armed.
#
# ⚠ AND A CANVAS CLICK NEEDS A `<Motion>` FIRST.  The seize `break`s the press
# before C sees it, and C updates its mouse pair only on events it DOES see -- so
# a press with no preceding motion reads a stale pair.  A real hand always moves
# the pointer onto the net before pressing; this file generates that motion for
# exactly that reason.
#
# Standalone, on the DEV DISPLAY and never on $DISPLAY, which is the user's own
# screen:
#   tests/headless/run_suites.sh test_calc_pick

if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "RESULT: SKIP (no X: the pick seizes a real design canvas)"
    flush stdout
    exit 0
}

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch calcpick]

set fixture [file join $repo tests headless data calc_fixture.raw]
set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

# ⚠⚠ THE DESIGN SHEET IS WRITTEN HERE AND ITS NET NAMES ARE CHOSEN TO MATCH THE
# COMMITTED RAW, and that pairing is the whole reason an end-to-end SUCCESS is
# measurable at all.  The committed session's own cell (`test_nfet_final`) shares
# no net name with `calc_fixture.raw`, so every click on it would refuse with
# R204's `unresolved` -- a perfectly good refusal row and no insertion row
# anywhere.  This sheet carries wires labelled `lp` and `sq`, which ARE columns of
# that raw, plus one `nmos4` with nothing on it for the body and terminal classes.
#
# ⚠ THE LABEL MUST BE A `lab_pin.sym` INSTANCE AND NOT `lab=` ON THE WIRE.  Both
# spellings load without complaint; only the instance names the net.  Measured: a
# wire written `N 0 0 100 0 {lab=lp}` resolves to `#net1`, i.e. the auto-named
# token, so a sheet built that way would have measured the unlabelled path while
# reading as though it measured the labelled one.
set design [file join $scratch picknets.sch]
set f [open $design w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
puts $f {N 0 0 100 0 {}}
puts $f {N 0 100 100 100 {}}
puts $f {C {lab_pin.sym} 0 0 0 0 {name=l1 sig_type=std_logic lab=lp}}
puts $f {C {lab_pin.sym} 0 100 0 0 {name=l2 sig_type=std_logic lab=sq}}
puts $f {C {nmos4.sym} 300 0 0 0 {name=M1 model=nmos w=5u l=0.18u del=0 m=1}}
close $f

# ⚠⚠ THE DESIGN SHEET IS LOADED *BEFORE* ANYTHING ELSE, AND THAT IS A HYGIENE
# REQUIREMENT, NOT A CONVENIENCE.  xschem starts on a dirty `untitled` schematic,
# and when `ase::ui::design_window` has to `xschem load -gui` a sheet it is not
# already showing, xschem first writes a BACKUP of that untitled sheet --
# `untitled~.sch`, next to where it thinks `untitled.sch` lives, which is the
# process's STARTUP directory and therefore THE REPO ROOT.  Measured: the suite
# left that file behind on every run, it is gitignored (`*~.sch`) so `git status`
# never showed it, and it reddened the hygiene rows `S1`/`S2` of
# `test_rdw_window_1245` and `test_rdw_keys_1245`, which exist to police exactly
# this.  ⚠ A `cd` into the scratch dir does NOT move it -- also measured -- because
# the path is anchored to the untitled sheet's own directory and not to the cwd.
# Loading the real sheet here replaces the untitled one, so `design_window` finds
# it already open, `raise_design_editor` succeeds, no `load -gui` runs and no
# backup is written.  The hygiene row at the foot of this file re-measures that.
set pg_untitled_pre [glob -nocomplain [file join $repo untitled*]]
catch {xschem load $design}

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[pcall_listable $r]" }
    return $r
}
proc pcall_listable {s} {
    if {![catch {llength $s}]} { return $s }
    set m [string map [list \{ ( \} ) \" '] $s]
    if {![catch {llength $m}]} { return $m }
    return [regsub -all {[^A-Za-z0-9 ._:,/()=+*<>?!-]} $s ?]
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
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

proc dg {d k} {
    if {[string match ERR:* $d]} { return $d }
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
proc pg_sized {got want} { return [expr {$got == $want ? "n$want" : "n$got"}] }
proc pg_word {v yes no} { return [expr {$v ? $yes : $no}] }
# the four seized slots of a canvas, as a snapshot -- and the EMPTY-vs-ABSENT
# distinction is kept, because `bind w seq {}` DESTROYS a binding and a restore
# that wrote an empty script back would pass a string compare and fail the
# sequence-list one (the RDW's row V6).
proc pg_binds {cv} {
    set out {}
    foreach seq {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion>} {
        set s [pcall bind $cv $seq]
        set present [expr {[lsearch -exact [pcall bind $cv] $seq] >= 0 ? 1 : 0}]
        lappend out [list $seq $present $s]
    }
    return $out
}
proc pg_buf {} {
    if {![winfo exists .calc.buf]} { return MISSING }
    return [.calc.buf get 1.0 end-1c]
}
# ⚠⚠ AN EVENT'S `-x`/`-y` ARE SCREEN PIXELS AND THE PICK'S COORDINATES ARE
# SCHEMATIC UNITS, AND CONFLATING THEM MAKES EVERY CLICK MISS.  `calc::pick_click`
# reads `xschem get mousex`/`mousey`, which C fills in by transforming the event's
# pixel pair -- so a row that generates `<Motion> -x 50 -y 0` to click schematic
# (50,0) lands wherever pixel (50,0) happens to be, and the first run of band PG3
# reported `nothing under the click` for a net that was certainly there.  The
# transform is xschem's own (`X_TO_SCREEN` in src/xschem.h):
#   pixel = (schematic + origin) / zoom
# and it is ROUND-TRIPPED in a fixture row below rather than trusted, by reading
# `mousex`/`mousey` back after the motion.
proc pg_px {x y} {
    set xo [xschem get xorigin] ; set yo [xschem get yorigin]
    set z  [xschem get zoom]
    if {$z == 0} { return {0 0} }
    return [list [expr {int(round(($x + $xo) / $z))}] \
                 [expr {int(round(($y + $yo) / $z))}]]
}
# one real canvas click AT A SCHEMATIC POINT: motion first (C updates its mouse
# pair only on events it SEES, and the seize eats the press), then press, then
# release.
proc pg_click {cv x y} {
    set p [pg_px $x $y]
    event generate $cv <Motion> -x [lindex $p 0] -y [lindex $p 1]
    update
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1]
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1]
    update
}
# where C thinks the pointer is, in schematic units, after a motion
proc pg_mouse {cv x y} {
    set p [pg_px $x $y]
    event generate $cv <Motion> -x [lindex $p 0] -y [lindex $p 1]
    update
    return [list [expr {round([xschem get mousex])}] [expr {round([xschem get mousey])}]]
}
# one real button press, the gesture measured in band S29k of test_calc_skeleton
proc pg_press {w} {
    event generate $w <Enter> -x 5 -y 5
    event generate $w <ButtonPress-1> -x 5 -y 5
    event generate $w <ButtonRelease-1> -x 5 -y 5
    event generate $w <Leave>
    update
}
proc viewer_ready {top} {
    if {$top eq {}} { return 0 }
    for {set i 0} {$i < 200} {incr i} {
        if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
        update ; after 10
    }
    return 0
}

if {[catch {

# =============================================================================
# PG1 — THE FIXTURE IS A MEASUREMENT, NOT AN ASSUMPTION
# =============================================================================
set tok {}
group PG1 {
    check "PG1 fixture: the committed raw and the session state were located" \
        [list [file isfile $::fixture] [file isfile $::statefile]] {1 1}
    set st [pcall ase::state_load $::statefile]
    dict set st rundir [file join $::scratch run]
    set sstate [file join $::scratch session.state]
    pcall ase::state_save $sstate $st
    set ::tok [pcall ase::session_key sky130_tests test_nfet_final ngspice_state1]
    check "PG1 fixture: the session opened under its own key and the viewer window came up" \
        [list [pcall ase::session_open $::tok $sstate] [pcall wviewer::open $::tok] \
              [pg_word [viewer_ready [pcall wviewer::window_for $::tok]] mapped NOTMAPPED]] \
        [list $::tok 1 mapped]
    # the raw goes INSIDE the viewer's context, because that is the context the
    # Calculator asks about and the one R204's lookup will be answered from.
    if {[catch {wviewer::enter_ctx $::tok} t]} { set t {0 {}} }
    set rd {}
    if {[lindex $t 0]} {
        catch {set rd [xschem raw read $::fixture tran]}
        catch {wviewer::leave_ctx $::tok $t}
    }
    # ⚠ READ AS `tran`, AND THE ANALYSIS NOW MATTERS.  R208a gates each voltage
    # selector on the loaded analysis, so a fixture read as `ac` makes every `vt`
    # row in this file refuse -- which is exactly what happened when the gate
    # landed, and the gate was right.  `vt` is the id these bands drive, so the
    # database must be the transient one; the MISMATCH is driven on purpose by its
    # own band below.
    check "PG1 fixture: the transient raw is read into the VIEWER's context, which is the analysis `vt` needs -- R208a refuses a voltage selector against another analysis, so this pairing is load-bearing and not incidental" \
        [list $rd [dict get [pcall calc::require_result] type]] {1 tran}
    check "PG1 fixture: `calc::open` builds the window and the Calculator's own resolver finds THAT viewer -- without this row every band below could pass against a refusal" \
        [list [pcall calc::open] [dg [pcall calc::require_result] ok] \
              [dg [pcall calc::require_result] token]] \
        [list .calc 1 $::tok]
    update idletasks
    # ⚠ ONE STUB, AND IT IS THE STEP THAT BELONGS TO ASE.  `ase::ui::design_path`
    # resolves a SESSION KEY to a cellview through ASE's own state; what this file
    # measures is everything downstream of that.  Pointing it at the sheet written
    # above is what lets `ase::ui::design_window` open a REAL window, the pick
    # seize a REAL canvas, and the click resolve a net that is REALLY in the raw.
    # Restored in band PG12, which checks the restore rather than assuming it.
    rename ase::ui::design_path pg_real_designpath
    proc ase::ui::design_path {key} { return $::design }
    check "PG1 fixture: the design sheet resolves and the net names it carries are REALLY columns of the committed raw, which is what makes an end-to-end success measurable rather than only a refusal" \
        [list [file isfile $::design] [pcall ase::ui::design_path $::tok] \
              [dg [pcall calc::pick_in_token $::tok v(lp)] ok] \
              [dg [pcall calc::pick_in_token $::tok v(lp)] name]] \
        [list 1 $::design 1 v(lp)]
}

# =============================================================================
# PG2 — THE ARM
# =============================================================================
group PG2 {
    check "PG2 fixture: nothing is armed before the gesture" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode]] \
        {0 {} {}}
    set pre {}
    set said [pcall calc::pick_arm vt]
    set cv {}
    catch {set cv $::calc::pick(canvas)}
    check "PG2 arming focuses the session's design, seizes the canvas it really landed on, and SAYS SO (R506) -- and the canvas is a live widget, which is the Landmine-17 read-back `ase::ui::design_window`'s own answer cannot give, because `switch_window()` and `switch_tab()` both open `if(xctx->semaphore) return 1` and `raise_window_entry` returns 1 unconditionally" \
        [list $said [pcall calc::pick_running] [pcall calc::pick_id] \
              [pg_word [expr {$cv ne {} && [winfo exists $cv]}] live DEAD] \
              [pg_word [expr {[pcall calc::pick_base $::design] >= 0}] landed MISSED]] \
        [list {selector vt: click a net on the schematic; ESC cancels} 1 vt live landed]
    check "PG2 all FOUR gesture slots are taken -- the fourth, `<B1-Motion>`, is issue 1304: without it a motion with Button1Mask starts C's rubber band and the seized release eats the only thing that ends it, so a one-pixel drift of the hand leaves objects selected, which is the exact inverse of `a pick does not change the selection`" \
        [list [pcall bind $cv <ButtonPress-1>] [pcall bind $cv <ButtonRelease-1>] \
              [pcall bind $cv <Key-Escape>] [pcall bind $cv <B1-Motion>]] \
        [list {calc::pick_click; break} {break} {calc::pick_end cancel; break} {break}]
    # ⚠ THE CLAIM IS "A REAL ESCAPE ARRIVES", AND THE FOCUS IS ONLY THE MEANS.
    # `focus -displayof` answers the focus window for the whole DISPLAY, and under
    # the tabbed interface the design canvas and its toplevel are the same focus
    # target, so it reports `.` for a seize on `.drw` -- which the first version of
    # this row read as a failure.  What matters is that the keyboard reaches the
    # design window's side rather than staying on `.calc`, and that a real Escape
    # is delivered at all, which band PG6 measures end to end.
    check "PG2 the keyboard goes to the DESIGN window and not to the Calculator: `design_window`'s raise moves focus there and the seized Button-1 `break`s before the generic <ButtonPress> that would hand it back, so without `focus -force` on the canvas a real ESC would never arrive and the mode could not be left with the key its own prompt names (band PG6 presses it)" \
        [list [pg_word [expr {[focus -displayof $cv] eq [winfo toplevel $cv] \
                              || [focus -displayof $cv] eq $cv}] designside \
                   [focus -displayof $cv]] \
              [pg_word [regexp {focus -force} [info body ::calc::_pick_seize]] forces NOFORCE]] \
        {designside forces}
    check "PG2 the design window's own mode line carries the prompt, on the green `.statusbar.10` slot xschem uses for every other mode" \
        [list [pcall [pcall ase::ui::sod_statusbar $cv] cget -text] \
              [pcall [pcall ase::ui::sod_statusbar $cv] cget -state]] \
        [list {Calculator vt: click a net to insert its name; ESC cancels} active]
}

# =============================================================================
# PG3 — THE GESTURE, THE INSERTION POINT, AND THE UNDO
# =============================================================================
group PG3 {
    # ⚠ NO `edit reset` ANYWHERE HERE.  A fixture that empties Tk's undo stack
    # before the click makes a one-step-undo row pass with BOTH `edit separator`
    # calls deleted -- measured in this tree.  The drive is "the user typed, THEN
    # clicked", which is the only drive under which the separators matter.
    pcall xschem zoom_full
    update
    check "PG3 fixture: the pixel/schematic transform is ROUND-TRIPPED and not trusted -- a generated motion at the computed pixel really does put C's own un-snapped mouse pair back on the schematic point asked for, which is the only thing that makes every click below land where its row says" \
        [list [pg_mouse $::calc::pick(canvas) 50 0] [pg_mouse $::calc::pick(canvas) 50 100]] \
        {{50 0} {50 100}}
    # ⚠⚠ THE TYPING IS DRIVEN WITH `insert` AND NOT WITH REAL KEY EVENTS, AND FOR
    # THIS CLAIM THAT IS THE STRONGER DRIVE RATHER THAN A CONCESSION.
    #
    # Two measurements, and the second is why the first is moot.  (a) `event
    # generate .calc.buf <KeyPress>` HANGS on this arm -- measured with no pick
    # armed at all and the Calculator alone in the process, and a `focus -force`
    # first does not fix it -- so it is a property of the harness here and not of
    # anything this stage wrote.  The suite is then killed by its driver's timeout
    # and takes the emergency-save path, printing `FATAL: signal 15`, which
    # `banner_died` scores as a DEATH and not as a timeout; that is worth knowing
    # before diagnosing one.  (b) Row CB2 of tests/headless/test_calc_buffer.tcl
    # establishes that `.calc.buf insert` leaves the edit UNSEPARATED -- its own
    # name is *"a press after an UNSEPARATED edit still undoes alone (`edit
    # separator`)"*.  So an `insert`-driven prior edit is exactly the case in which
    # the product's own two `edit separator` calls are the ONLY thing separating
    # the user's text from the inserted name.  With real typing, Tk's
    # autoseparators (`-autoseparators 1` on this widget, measured) could do that
    # job instead and the undo row would pass with BOTH separators deleted -- the
    # vacuity this tree has already been bitten by once, when a fixture's
    # `edit reset` made a one-step-undo row pass against its own sabotage.
    #
    # ⚠ `mark set insert end-1c` IS REQUIRED, not tidy: after `insert end` the
    # insert mark sits past the Text widget's own trailing newline, and the pick
    # inserts AT THE CURSOR (§7.4) -- so without it the name would land on a
    # second line and the row would be measuring something nobody can type.
    .calc.buf delete 1.0 end
    .calc.buf insert end {an_expression+}
    .calc.buf mark set insert end-1c
    set typed [pg_buf]
    pg_click $::calc::pick(canvas) 50 0
    set after [pg_buf]
    check "PG3 the user's own example, end to end: with `an_expression+` typed, a click on the wire labelled `lp` leaves the buffer holding that text plus the vector name, separated by exactly ONE space -- and the space is FORCED, not chosen, because §3.1's lexer splits on whitespace and would read `an_expression+v(lp)` as one unknown token" \
        [list $typed $after [pcall calc::rpn_bad_token an_expression+v(lp)]] \
        [list {an_expression+} {an_expression+ v(lp)} {unknown token 'an_expression+v(lp)' (not an operator/function, number or raw variable)}]
    check "PG3 ...and the status line names the vector AND the Cadence path, which is R208's whole arrangement: the half the engine resolves beside the half the user recognises" \
        [lindex [pcall calc::status_history] 0] {selector vt: v(lp) from /lp} 
    check "PG3 ONE undo removes exactly the name and leaves the typing, and a second removes the typing -- which is what the two `edit separator` calls in `calc::buf_insert_token` buy and the only thing that measures them" \
        [list [pcall .calc.buf edit undo] [pg_buf] \
              [pcall .calc.buf edit undo] [pg_buf]] \
        [list {} {an_expression+} {} {}]
    check "PG3 the mode is STILL LIVE after a successful pick (R208's sticky mode), so a second net can be picked without re-clicking the selector" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] \
              [pcall bind $::calc::pick(canvas) <ButtonPress-1>]] \
        [list 1 vt {calc::pick_click; break}]
    .calc.buf delete 1.0 end
    pg_click $::calc::pick(canvas) 50 100
    check "PG3 ...measured by doing it: a second click on a different net inserts that net's name, so the mode really is reusable" \
        [pg_buf] {v(sq)}
    check "PG3 R208: a pick SELECTS NOTHING on the schematic (issue 0204) -- the probe is read-only and the user's own ruling is that a command mode must not change the selected set" \
        [list [pcall xschem selection] [pcall xschem get lastsel]] {{} 0}
}

# =============================================================================
# PG4 — R203's REFUSALS, WITH REAL CLICKS
# =============================================================================
group PG4 {
    .calc.buf delete 1.0 end
    .calc.buf insert end {keepme}
    set cv $::calc::pick(canvas)
    set g [pcall xschem instance_pin_coord 2 name g]
    set res {}
    # a device BODY, a device TERMINAL, and empty canvas
    pg_click $cv 310 0
    lappend res [lindex [pcall calc::status_history] 0] [pg_buf] [pcall calc::pick_running]
    if {[llength $g] == 3} {
        pg_click $cv [lindex $g 1] [lindex $g 2]
        lappend res [lindex [pcall calc::status_history] 0] [pg_buf] [pcall calc::pick_running]
    }
    check "PG4 R203 with real clicks: a device BODY names the instance and refuses, a device TERMINAL is refused as the CURRENT selectors' pick and not this one, and after each the buffer is BYTE-IDENTICAL and the mode is STILL LIVE -- because a mode that ended on a mis-click would be unusable" \
        $res [list {selector vt: M1 is not a net} keepme 1 \
                   {selector vt: that is a device terminal, not a net} keepme 1]
    check "PG4 ...and the seize is still in place after both refusals, which is the claim `still live` actually rests on" \
        [pcall bind $cv <ButtonPress-1>] {calc::pick_click; break}
    check "PG4 nothing was selected by any of it (issue 0204), after a success and two refusals" \
        [list [pcall xschem selection] [pcall xschem get lastsel]] {{} 0}
}

# =============================================================================
# PG5 — R204 END TO END: NOTHING IS INSERTED WHEN THE NAME DOES NOT RESOLVE
# =============================================================================
# ⚠ VERIFY-THEN-INSERT, never insert-then-undo: the row asserts the buffer's
# EDIT-HISTORY hints are unmoved as well as its text, because an implementation
# that inserted and then undid would leave the text right and the history wrong.
group PG5 {
    .calc.buf delete 1.0 end
    .calc.buf insert end {keepme}
    pcall calc::buf_sync
    set u0 [pcall calc::buf_can undo] ; set r0 [pcall calc::buf_can redo]
    # a net the sheet has and the raw does not: relabel one on the fly
    pcall xschem setprop instance l2 lab nosuchnet fast
    pcall xschem unhilight_all
    pg_click $::calc::pick(canvas) 50 100
    check "PG5 R204: a net the design has and the RESULT does not inserts NOTHING, names the failing vector, and leaves the buffer byte-identical -- the guard against §3.1/L3 producing a whole-expression -1 three steps later where it is undebuggable" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0] [pcall calc::pick_running]] \
        [list keepme {selector vt: v(nosuchnet) is not in this result; nothing inserted} 1]
    check "PG5 ...and it is VERIFY-THEN-INSERT and not insert-then-undo: the buffer's own edit-history hints did not move either, which an implementation that inserted and then undid would get wrong while leaving the text right" \
        [list [pcall calc::buf_can undo] [pcall calc::buf_can redo]] [list $u0 $r0]
    pcall xschem setprop instance l2 lab sq fast
    pcall xschem unhilight_all
}

# =============================================================================
# PG6 — R306: ESCAPE, AND A BYTE-IDENTICAL RESTORE
# =============================================================================
group PG6 {
    set cv $::calc::pick(canvas)
    .calc.buf delete 1.0 end
    .calc.buf insert end {untouched}
    # the predecessors, as the seize recorded them
    set prev [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                   [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]
    event generate $cv <Key-Escape>
    update
    check "PG6 R306: a real Escape leaves the buffer untouched, clears `::calc::selmode`, ends the mode and says so" \
        [list [pg_buf] [set ::calc::selmode] [pcall calc::pick_running] \
              [pcall calc::pick_id] [lindex [pcall calc::status_history] 0]] \
        [list untouched {} 0 {} {selector vt: pick cancelled}]
    check "PG6 ...and all four slots are handed back BYTE-IDENTICALLY, including the EMPTY-vs-ABSENT distinction: `.drw` is a Frame whose shipped bindings are the generic <Button>/<Key>, so all four predecessors are ABSENT -- and `bind w seq {}` DESTROYS a binding, so a restore that wrote an empty script back would pass a string compare and fail this sequence-list one" \
        [pg_binds $cv] $prev
    check "PG6 the design window's prompt slot is cleared and back to its neutral state, so the next mode's sentence is not competing with a stale one" \
        [list [pcall [pcall ase::ui::sod_statusbar $cv] cget -text] \
              [pcall [pcall ase::ui::sod_statusbar $cv] cget -state]] \
        [list { } normal]
}

# =============================================================================
# PG13 — THE RAISE, AND WHERE THE PICK SAYS THINGS NOW
# =============================================================================
# ⚠ THE RAISE MODE IS ASSERTED THROUGH THE INTERPRETER'S OWN VIEW OF THE CALL,
# never a text scan over `calculator.tcl`: `ase::ui::design_window` is renamed to a
# recorder, which is the method `test_ase_window.tcl` already uses, and the row
# reads back the argument list it was really handed.  Issue 1646's lesson — every
# text-scanning leg was eventually evaded; no `info args`-class leg ever was.
group PG13 {
    rename ase::ui::design_path pg_real_dp2
    proc ase::ui::design_path {key} { return $::design }
    rename ase::ui::design_window pg_real_dw
    # ⚠ THE SENTINEL IS NOT THE EMPTY STRING.  Passing NO raise mode is exactly
    # what this row asserts, and `{}` is what `args` then holds -- so initialising
    # the recorder to `{}` would make "called with no argument" and "never called
    # at all" the same reading, and the first version of this row passed its own
    # expectation while `calc::pick_arm` had bailed before the call.
    set ::pg_dw_args NOTCALLED
    proc ase::ui::design_window {key args} {
        set ::pg_dw_args $args
        return [uplevel 1 [list pg_real_dw $key {*}$args]]
    }
    pcall calc::pick_end cancel
    check "PG13 fixture: the Calculator window and the design window are BOTH still up, so this band is not measuring a closed window -- a band that assumed what the band above it left behind is this file's own recorded trap" \
        [list [expr {[winfo exists .calc] ? 1 : 0}] [pcall calc::has_win .calc.buf]] {1 1}
    set said [pcall calc::pick_arm vt]
    check "PG13 the pick asks for the DEFAULT raise mode and passes NO argument at all, which is what sends it down `raise_activate_toplevel` -- withdraw + deiconify + raise, then `xschem activate_window` -- byte-for-byte what `libmgr::raise_to_front` does and what the user named as correct.  Read off the recorded CALL, never off the source text" \
        [list $::pg_dw_args [pcall calc::pick_running] $said] \
        [list {} 1 {selector vt: click a net on the schematic; ESC cancels}]
    # ⚠ WHY `ifhidden` WAS WRONG, recorded as a row rather than as prose: its
    # predicate is `winfo ismapped`, which is TRUE of a window merely COVERED by
    # the Calculator -- so it took the cheap bare-`raise` arm, which is inert on a
    # server advertising no window-manager protocol.  This leg measures that the
    # design window really is mapped while the Calculator is up, which is the whole
    # premise.
    check "PG13 the premise of that fix, measured: the design window IS mapped while the Calculator is also up, so a raise mode whose test is `winfo ismapped` could never fire for a merely covered window" \
        [list [winfo ismapped [winfo toplevel $::calc::pick(canvas)]] \
              [winfo ismapped .calc]] {1 1}
    rename ase::ui::design_window {}
    rename pg_real_dw ase::ui::design_window
    check "PG13 the recorder is handed back, which the band CHECKS rather than assumes" \
        [list [expr {[info procs ::pg_real_dw] eq {} ? 1 : 0}] \
              [expr {[info procs ::ase::ui::design_window] ne {} ? 1 : 0}]] {1 1}
    # --- the sentence lands where the user is now looking ----------------------
    set cv $::calc::pick(canvas)
    set slot [pcall ase::ui::sod_statusbar $cv]
    pcall xschem zoom_full
    update
    .calc.buf delete 1.0 end
    pg_click $cv 50 0
    check "PG13 a SUCCESSFUL pick's sentence reaches the DESIGN window's own status slot and not only the Calculator's -- which matters precisely because the pick now raises the schematic OVER the Calculator, so `.calc.status.msg` is behind another window for the whole gesture" \
        [list [pcall $slot cget -text] [lindex [pcall calc::status_history] 0] [pg_buf]] \
        [list {selector vt: v(lp) from /lp} {selector vt: v(lp) from /lp} {v(lp)}]
    pg_click $cv 310 0
    check "PG13 ...and so does a REFUSAL, with its own instruction, so a mis-click is answered where the eye already is" \
        [list [pcall $slot cget -text] [pg_buf]] \
        [list {selector vt: M1 is not a net} {v(lp)}]
    # ⚠ THE PUMP MUST KEEP THE NEW SENTENCE UP, not revert to the arming prompt:
    # C's `update_statusbar()` blanks this slot on every canvas event, so a direct
    # write would survive less than one frame.  That is why `calc::pick_echo` goes
    # through `pick(prompt)`.
    catch {$slot configure -state normal -text {}}
    for {set i 0} {$i < 100} {incr i} {
        update ; after 10
        if {[pcall $slot cget -text] ne {}} break
    }
    check "PG13 the pump keeps the LATEST sentence up rather than reverting to the arming prompt, which is what `calc::pick_echo` writing through `pick(prompt)` buys -- a direct write to the slot would be blanked by C within a frame" \
        [pcall $slot cget -text] {selector vt: M1 is not a net}
    pcall calc::pick_end cancel
    # --- R208a with a REAL window and a REAL database -------------------------
    # ⚠ `vf` IS THE AC SELECTOR AND THIS RESULT IS TRANSIENT, so arming it must
    # refuse, seize nothing, and say which analysis is loaded.  This is the user's
    # own complaint driven end to end: before R208a, `vf` here would have armed and
    # a click would have inserted `v(lp)` reading a TRANSIENT number under an AC
    # selector, with nothing anywhere able to say so.
    set vfsaid [pcall calc::pick_arm vf]
    check "PG13 R208a end to end: `vf` against a TRANSIENT result refuses, seizes NOTHING and names both analyses -- before this, it armed and a click inserted a transient number under an AC selector with nothing able to say so.  The canvas is read from the id captured above, because a refusal leaves no record to read it from, which is itself the claim" \
        [list $vfsaid [pcall calc::pick_running] [pcall calc::pick_id] \
              [expr {[info exists ::calc::pick] ? 1 : 0}] [pg_binds $cv]] \
        [list {selector vf: needs an AC result; this one is transient} 0 {} 0 \
              [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                    [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]]
    rename ase::ui::design_path {}
    rename pg_real_dp2 ase::ui::design_path
}


# =============================================================================
# PG8 — R201: RE-CLICK DISARMS, ANOTHER SELECTOR SWITCHES
# =============================================================================
# The gesture is the real one, on the real radiobutton.
group PG8 {
    pg_press .calc.sel.vt
    check "PG8 a real press on an enabled voltage selector arms the pick and Tk's own -variable holds the id -- which is why R201's disarm cannot be a -command diff: the variable is ALREADY the clicked id by the time -command runs" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode]] \
        {1 vt vt}
    pg_press .calc.sel.vt
    check "PG8 R201: re-clicking the ARMED selector disarms it, returns `::calc::selmode` to empty and says so -- keyed on `calc::pick_id`, the remembered value `calc::build_sel`'s own comment asked for" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode] \
              [lindex [pcall calc::status_history] 0]] \
        [list 0 {} {} {selector vt: pick cancelled}]
    pg_press .calc.sel.vt
    set cv8 $::calc::pick(canvas)
    pg_press .calc.sel.vf
    # ⚠⚠ THIS ROW WAS RESTATED BY R208a AND THE REASON IS A REAL CONSEQUENCE OF THE
    # GATE, NOT A TEST ARTEFACT: each voltage id names ONE analysis and the
    # Calculator can hold only ONE database at a time (`ase::attach_dbs` drops the
    # others), so AT MOST ONE OF THE FOUR CAN EVER ARM against a given result.
    # Its old form pressed `vt` then `vf` and expected both to arm, which is now
    # impossible by construction.  What still matters -- and is what it was really
    # about -- is that pressing another selector ENDS the live pick and releases the
    # canvas BEFORE the new id is judged, so no seize can be left behind.
    check "PG8 pressing ANOTHER voltage selector ENDS the live pick and releases the canvas before the new id is judged -- and under R208a the new id then refuses, because each voltage selector names one analysis and only one of the four can arm against a given result.  `::calc::selmode` follows the pressed id either way, which is Tk's own write and the grid showing the user what they clicked" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode] \
              [lindex [pcall calc::status_history] 0]] \
        [list 0 {} vf {selector vf: needs an AC result; this one is transient}]
    check "PG8 ...and NO canvas is left seized after the switch: the end path ran, so the four slots are back at their predecessors rather than carrying a dead mode's scripts -- issue 1305's permanent seize is what this forecloses" \
        [list [expr {[info exists ::calc::pick] ? 1 : 0}] [pg_binds $cv8]] \
        [list 0 [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                      [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]]
    pcall calc::pick_end cancel
    check "PG8 a NON-voltage selector is still inert and arms nothing, which is R208's scope boundary with a real press behind it" \
        [list [pg_word [expr {[pcall calc::sel_click op] ne {}}] speaks SILENT] \
              [pcall calc::pick_running] \
              [lindex [pcall calc::status_history] 0]] \
        [list speaks 0 {selector op: signal picking: not implemented (phase 6)}]
}

# =============================================================================
# PG10 — THE PUMP: THE PROMPT COMES BACK, AND A DEAD CANVAS ENDS THE MODE
# =============================================================================
group PG10 {
    pcall calc::pick_arm vt
    set cv $::calc::pick(canvas)
    set slot [pcall ase::ui::sod_statusbar $cv]
    catch {$slot configure -state normal -text {}}
    check "PG10 fixture: the prompt really was blanked, so the row below measures the pump and not a slot that never changed" \
        [pcall $slot cget -text] {}
    # ⚠ WAIT FOR THE PROMPT, NOT FOR "NON-EMPTY".  C's own `update_statusbar()`
    # writes a SINGLE SPACE into this slot, so a loop that broke on `ne {}` broke
    # on C's space before the pump's 80 ms had elapsed and then reported the space
    # as the pump's failure.  Measured; it is the first version of this row.
    set pgwant [pcall calc::pick_msg prompt vt]
    for {set i 0} {$i < 100} {incr i} {
        update ; after 10
        if {[pcall $slot cget -text] eq $pgwant} break
    }
    check "PG10 the prompt COMES BACK on its own, which it has to: every generic canvas event forwards to C's `update_statusbar()`, which BLANKS this slot whenever no C `ui_state` mode bit is set -- and a pure-Tcl mode sets none, so without the pump the prompt would vanish on the first mouse move.  The mode's own liveness rides in the value, so a failure says whether the pump stopped or the mode ended under it" \
        [list [pcall $slot cget -text] [pcall calc::pick_running] \
              [lindex [pcall calc::status_history] 0]] \
        [list {Calculator vt: click a net to insert its name; ESC cancels} 1 \
              {selector vt: click a net on the schematic; ESC cancels}]
}

# =============================================================================
# PG11 — THE cmdmode CONTRACT (issue 0201)
# =============================================================================
group PG11 {
    set cv $::calc::pick(canvas)
    check "PG11 fixture: a pick is live and the registry knows this mode" \
        [list [pcall calc::pick_running] \
              [expr {[lsearch -exact [pcall cmdmode::registered] calc_pick] >= 0 ? 1 : 0}]] \
        {1 1}
    set n [pcall cmdmode::suspend_all]
    check "PG11 a suspend RELEASES the canvas and KEEPS the record, and SUSPENDED STILL COUNTS AS RUNNING (issue 1308) -- a mode paused by a descend is still one the user has to be able to leave, and `pick(canvas)` is what the end path releases" \
        [list [expr {$n >= 1 ? 1 : 0}] [pcall calc::pick_running] [pcall calc::pick_id] \
              [pcall bind $cv <ButtonPress-1>] \
              [expr {[info exists ::calc::pick(suspended)] ? 1 : 0}]] \
        {1 1 vt {} 1}
    set m [pcall cmdmode::resume_all $cv]
    check "PG11 ...and the resume re-latches on the canvas it is handed, by CALLING the seize so the sequence count cannot drift from it" \
        [list [expr {$m >= 1 ? 1 : 0}] [pcall calc::pick_running] \
              [pcall bind $cv <ButtonPress-1>] [pcall bind $cv <B1-Motion>] \
              [expr {[info exists ::calc::pick(suspended)] ? 1 : 0}]] \
        [list 1 1 {calc::pick_click; break} break 0]
    # ⚠ A RESUME HANDED A DEAD CANVAS FALLS BACK TO THE ONE IT WAS SEIZED ON, and
    # the first version of this band expected it to drop the mode.  It should not:
    # `rdw::pick_resume` does the same, and the fallback is what keeps a resume
    # from throwing a live mode away just because the caller named a window that
    # has since gone.  The DROP needs BOTH to be dead, which is the next leg.
    pcall cmdmode::suspend_all
    set k [pcall calc::pick_resume .nosuch.drw]
    check "PG11 a resume handed a DEAD canvas falls back to the one the mode was seized on rather than throwing a live mode away, which is `rdw::pick_resume`'s own behaviour and ruling D2's cautious half" \
        [list $k [pcall calc::pick_running] [pcall bind $cv <ButtonPress-1>]] \
        [list 1 1 {calc::pick_click; break}]
    # ...and now the real drop: nowhere to land at all.
    # ⚠ `cmdmode::suspend_all` A SECOND TIME IS A NO-OP (ruling D6: one suspended
    # set at a time, and `active` is still 1 because the resume above consumed the
    # first one), so `pick(suspended)` would never be set and `calc::pick_resume`
    # would return 0 with the mode still live -- which is what the first version of
    # this leg measured and misread as the drop failing.  Suspend THIS mode
    # directly instead.
    pcall calc::pick_suspend
    set ::calc::pick(canvas) .nosuch.drw
    set k2 [pcall calc::pick_resume .alsonosuch.drw]
    check "PG11 a resume with NOWHERE to land AT ALL drops the mode rather than leaving an unreachable record behind, clears the selector and says so -- the window was closed while the pick was paused" \
        [list $k2 [pcall calc::pick_running] [set ::calc::selmode] \
              [lindex [pcall calc::status_history] 0]] \
        [list 0 0 {} {selector vt: the design window closed; pick cancelled}]
    # ⚠ THE POKE ABOVE FALSIFIED THE RECORD ON PURPOSE, SO THIS BAND HAS TO HAND
    # THE REAL CANVAS BACK ITSELF: the drop released `.nosuch.drw` and left the
    # real one still carrying the seize, and the next band to arm would then latch
    # those scripts as its own predecessors -- issue 1305's permanent seize, which
    # band PG7 duly caught.  `calc::_pick_seize` now refuses to latch its own
    # scripts, and this leg asserts the canvas really is clean again either way.
    catch {cmdmode::resume_all $cv}
    foreach seq {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion>} {
        catch {bind $cv $seq {}}
    }
    catch {array unset ::calc::pick}
    check "PG11 the band hands the real canvas back clean, so the bands after it arm on an UNSEIZED one -- and `calc::_pick_seize` refuses to latch its own scripts as the predecessors in any case, which is issue 1305's permanent seize foreclosed one level below the RDW's own guard" \
        [list [pg_binds $cv] [pcall calc::pick_running]] \
        [list [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                    [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]] 0]
}

# =============================================================================
# PG7 — R307: TWO DOORS, BECAUSE `calc::close` IS ONLY THE TITLE-BAR X
# =============================================================================
group PG7 {
    pcall calc::pick_arm vt
    set cv $::calc::pick(canvas)
    check "PG7 fixture: a pick is live and the canvas is seized" \
        [list [pcall calc::pick_running] [pcall bind $cv <ButtonPress-1>]] \
        [list 1 {calc::pick_click; break}]
    pcall calc::close
    check "PG7 R307, door one: `calc::close` releases the pick BEFORE the widgets go away -- `destroy .calc` could not do it, because the bindings live on the design window's `.drw`, which is not a descendant of `.calc`" \
        [list [winfo exists .calc] [pcall calc::pick_running] [set ::calc::selmode] \
              [pg_binds $cv]] \
        [list 0 0 {} [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                           [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]]
    pcall calc::open
    update idletasks
    pcall calc::pick_arm vt
    check "PG7 fixture: a pick is live again, on a freshly opened window" \
        [list [pcall calc::pick_running] [pcall bind $cv <ButtonPress-1>]] \
        [list 1 {calc::pick_click; break}]
    pcall destroy .calc
    update
    check "PG7 R307, door TWO, and it is not optional: a bare `destroy .calc` never runs the `WM_DELETE_WINDOW` handler, so without the `<Destroy>` bind this path would leave the design canvas PERMANENTLY seized -- issue 1305 measured exactly that in the RDW: every click dumping into a dead mode and nothing selectable again, unrecoverable inside the session" \
        [list [winfo exists .calc] [pcall calc::pick_running] [pg_binds $cv]] \
        [list 0 0 [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                        [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]]
}

# =============================================================================
# PG12 — THE BAND AT THE FOOT PUTS BACK WHAT IT BORROWED
# =============================================================================
# ⚠ A BAND AT THE FOOT OF A FILE MUST OPEN WHAT THE BAND ABOVE CLOSED, and the
# fixture row is what catches it: band PG7 ends with `.calc` destroyed, so a row
# here that compared two snapshots would be comparing two failures and passing
# VACUOUSLY.  This band reopens, and then asserts the stub is gone.
group PG12 {
    check "PG12 the ONE stub this file took is handed back, which the band CHECKS rather than assumes: a leaked rename would make every later reader of this namespace see a fake resolver" \
        [list [expr {[info procs ::pg_real_designpath] ne {} ? 1 : 0}]] {1}
    rename ase::ui::design_path {}
    rename pg_real_designpath ase::ui::design_path
    check "PG12 ...and the product's own resolver is back and answering for a key it cannot resolve, rather than the stub's constant" \
        [list [pcall ase::ui::design_path __pg_nosuch__] \
              [expr {[info procs ::pg_real_designpath] eq {} ? 1 : 0}]] \
        {{} 1}
    check "PG12 nothing is left armed and no canvas is left seized after every band above" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] \
              [expr {[info exists ::calc::pick] ? 1 : 0}]] \
        {0 {} 0}
}

} err]} {
    puts "FATAL: $err"
    puts $::errorInfo
    incr fail
}

check "PGH HYGIENE: the suite creates no `untitled*` file in the repo -- xschem backs the dirty untitled sheet up next to itself when `design_window` has to load a sheet, the path is the STARTUP directory and not the cwd, the file is gitignored so nothing else would show it, and the hygiene rows of both `test_rdw_*` suites redden on it" \
    [list [glob -nocomplain [file join $repo untitled*]] $pg_untitled_pre] \
    [list $pg_untitled_pre $pg_untitled_pre]

check "EVERY band above this one RAN TO ITS END: no band was abandoned through `group`'s catch, which is the failure mode that DELETES a band's remaining rows from the verdict instead of reddening them.  Derived from `group`'s own record rather than a list kept here" [list [llength $::abortnames] $::abortnames] {0 {}}

catch {test_scratch_drop $scratch}
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
