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
# R208e (band PG18): a voltage source and an ammeter, well clear of everything
# above, whose names are the CURRENT columns of the raw band PG18 writes.
puts $f {C {vsource.sym} -400 0 0 0 {name=Vsq value=1}}
puts $f {C {ammeter.sym} -400 300 0 0 {name=Vam}}
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
#
# ⚠⚠ THE LEADING `update` DRAINS THE SETTLE BURST, AND IT IS NOT THE SAME FIX THE
# RDW HELPERS GOT.  Issue 1659: `bind $topwin <Configure>` is bound on a TOPLEVEL,
# so it fires for every descendant (`.statusbar.1` included, on an ordinary
# status-text reflow) and hands that widget's position inside its parent to
# `callback()` as %x %y -- which writes `xctx->mousex/mousey` UNCONDITIONALLY,
# above its `switch(event)`.  Any `update` that processes a pending Configure
# therefore overwrites the pair this helper just set, `xschem instance_at`
# answers empty, and `calc::pick_click` takes its "nothing under the click" arm:
# rc 0, no error, no insert.  Measured in the sibling suite as 136.2803 ->
# 1260.7161 across one `update`.
#
# ⚠ BUT UNLIKE `kx_click`, THE PUMP HERE CANNOT SIMPLY MOVE.  Those helpers pass
# `-when now`, which delivers synchronously, so their post-motion `update` was
# pure exposure.  These events go through the QUEUE, so the `update` after the
# motion is what DELIVERS it -- removing it would stop the pair being set at all.
# The drain goes in FRONT instead, so the burst is gone before the motion is sent
# and the delivering pump has nothing left to process.
#
# ⚠ AND THE DRAIN IS NOT TRUSTED: the pair is read back and a divergence is
# COUNTED, because this exact shape produced a T1 red (six rows of this suite's
# display arm, five of them reading "nothing under the click") that did not
# reproduce standalone, in the Calculator `dcases` chain, or in a full re-gate.
# A race that corrupts other rows silently is worse than one that names itself;
# row PGC below fails on a nonzero count, so the next occurrence is legible
# instead of arriving as six unrelated-looking failures.
set ::PG_CLOBBER 0
set ::PG_CLOBBER_AT {}
proc pg_click {cv x y} {
    set p [pg_px $x $y]
    update
    event generate $cv <Motion> -x [lindex $p 0] -y [lindex $p 1]
    update
    set gx [expr {round([xschem get mousex])}]
    set gy [expr {round([xschem get mousey])}]
    if {abs($gx - $x) > 1 || abs($gy - $y) > 1} {
        incr ::PG_CLOBBER
        lappend ::PG_CLOBBER_AT "wanted=$x,$y got=$gx,$gy"
    }
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1]
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1]
    update
}
# the resolving click WITH THE HAND DRIFTING while the button is down: press at
# one schematic point, a Button1-held motion to another, release there.  It is
# the drive that tells an end ON THE RELEASE from an end INSIDE THE PRESS --
# with the slots handed back mid-click, the held motion reaches C as a rubber
# band (select_rect START + unselect_all) and the release closes it over
# whatever the rectangle covers.  `-state 256` is Button1Mask.  The drift is
# SEVERAL motions, as a hand's is: C starts the band on the first held motion
# past its stickiness threshold and grows it on the later ones, so a single
# motion would open and close a zero-size band and select nothing either way.
proc pg_drift_click {cv x y x2 y2} {
    set p [pg_px $x $y] ; set q [pg_px $x2 $y2]
    update
    event generate $cv <Motion> -x [lindex $p 0] -y [lindex $p 1]
    update
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1]
    update
    foreach f {0.1 0.4 0.7 1.0} {
        set mx [expr {int(round([lindex $p 0] + $f * ([lindex $q 0] - [lindex $p 0])))}]
        set my [expr {int(round([lindex $p 1] + $f * ([lindex $q 1] - [lindex $p 1])))}]
        event generate $cv <Motion> -x $mx -y $my -state 256
        update
    }
    event generate $cv <ButtonRelease-1> -x [lindex $q 0] -y [lindex $q 1] -state 256
    update
}
# where C thinks the pointer is, in schematic units, after a motion
proc pg_mouse {cv x y} {
    set p [pg_px $x $y]
    update
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
    set cv3 $::calc::pick(canvas)
    pg_click $cv3 50 0
    set after [pg_buf]
    check "PG3 the user's own example, end to end: with `an_expression+` typed, a click on the wire labelled `lp` leaves the buffer holding that text plus the vector name, separated by exactly ONE space -- and the space is FORCED, not chosen, because §3.1's lexer splits on whitespace and would read `an_expression+v(lp)` as one unknown token" \
        [list $typed $after [pcall calc::rpn_bad_token an_expression+v(lp)]] \
        [list {an_expression+} {an_expression+ vt(lp)} {unknown token 'an_expression+v(lp)' (not an operator/function, number or raw variable)}]
    # R208c: the buffer gets the ANALYSIS-QUALIFIED token (`vt(lp)`, which reads
    # v(lp) from the transient analysis of the result whatever is current) and the
    # sentence names the analysis -- read from the selector's own table, where the
    # earlier sentence asked `xschem raw sim_type` in the DESIGN window's context,
    # which holds no raw, so the analysis never actually appeared on this arm.
    check "PG3 ...and the status line names the vector, its analysis AND the Cadence path, which is R208's whole arrangement: the half the engine resolves beside the half the user recognises" \
        [lindex [pcall calc::status_history] 0] {selector vt: vt(lp) (transient) from /lp}
    check "PG3 ONE undo removes exactly the name and leaves the typing, and a second removes the typing -- which is what the two `edit separator` calls in `calc::buf_insert_token` buy and the only thing that measures them" \
        [list [pcall .calc.buf edit undo] [pg_buf] \
              [pcall .calc.buf edit undo] [pg_buf]] \
        [list {} {an_expression+} {} {}]
    # ⚠⚠ R208b, THE USER'S OWN CORRECTION OF R208's STICKY MODE (2026-10-08,
    # doc/claude/calc_feedback_batch/BATCH.md item 9): *"Clicking on one of the
    # Selectors (such as vt or vf) is a one-time thing ... ESC should not be
    # required to exit that mode"*.  A pick that RESOLVED a net ends the mode by
    # itself and hands the four slots back byte-identically.  The fence is the
    # gesture the user makes next: a second click on the canvas, which must reach
    # xschem as an ordinary click -- it SELECTS the wire and inserts nothing.
    check "PG3 R208b: a pick that RESOLVED a net is ONE-SHOT -- the mode ends by itself on the click, `::calc::selmode` is cleared so the selector grid shows nothing armed, and no ESC is needed" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode] \
              [expr {[info exists ::calc::pick] ? 1 : 0}]] \
        [list 0 {} {} 0]
    check "PG3 R208b ...and all four gesture slots are handed back BYTE-IDENTICALLY, the EMPTY-vs-ABSENT distinction included, so the canvas is xschem's own again" \
        [pg_binds $cv3] \
        [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
              [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]
    check "PG3 R208b ...and the success sentence is still the last thing the Calculator said: ending the mode does not overwrite it with a `cancelled`" \
        [lindex [pcall calc::status_history] 0] {selector vt: vt(lp) (transient) from /lp}
    check "PG3 R208: a pick SELECTS NOTHING on the schematic (issue 0204) -- the probe is read-only and the user's own ruling is that a command mode must not change the selected set" \
        [list [pcall xschem selection] [pcall xschem get lastsel]] {{} 0}
    .calc.buf delete 1.0 end
    pg_click $cv3 50 100
    set sel3 [pcall xschem get lastsel]
    check "PG3 R208b measured by doing it: a SECOND click on the canvas is ordinary xschem -- it inserts nothing into the buffer, leaves the mode off, and SELECTS the wire under it, which is what xschem does with a click when no mode holds the canvas" \
        [list [pg_buf] [pcall calc::pick_running] [pg_word [expr {$sel3 >= 1}] selected "lastsel=$sel3"]] \
        [list {} 0 selected]
    pcall xschem unselect_all
    pcall xschem unhilight_all
}

# =============================================================================
# PG4 — R203's REFUSALS, WITH REAL CLICKS
# =============================================================================
group PG4 {
    # PG3's success ended the mode (R208b), so this band arms its own.
    pcall calc::pick_arm vt
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
    check "PG4 nothing was selected by any of it (issue 0204), after two refusals" \
        [list [pcall xschem selection] [pcall xschem get lastsel]] {{} 0}
    # R208b's other half: the mode a miss left armed ends on the FIRST click that
    # resolves, so a mis-click costs the user nothing but the second try.
    .calc.buf delete 1.0 end
    # the user's own selection is IN PLACE before the gesture, so the row below
    # can see it survive -- an empty selection cannot be cleared, and C's band
    # clears whatever is selected the moment a held motion passes its threshold.
    pcall xschem select instance M1
    set sel0 [pcall xschem selection]
    pg_drift_click $cv 50 0 600 300
    check "PG4 R208b: after two refusals the mode is still the SAME pick, and the first click that resolves a net inserts it and ends the mode with the four slots handed back" \
        [list [pg_buf] [pcall calc::pick_running] [set ::calc::selmode] [pg_binds $cv]] \
        [list {vt(lp)} 0 {} [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                                 [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]]
    check "PG4 ...and that resolving click LEFT THE USER'S SELECTION EXACTLY AS IT WAS, although the hand DRIFTED across the sheet with the button down: the mode ends on the RELEASE, so the held motion and the release are still eaten by the seize -- ended inside the press instead, the held motion reaches C as a rubber band whose first act is unselect_all" \
        [list [pg_word [expr {$sel0 ne {}}] seeded EMPTY] [pcall xschem selection] [pcall xschem get lastsel]] \
        [list seeded $sel0 1]
    pcall xschem unselect_all
    pcall calc::pick_arm vt
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
    check "PG13 a SUCCESSFUL pick's sentence reaches the DESIGN window's own status slot and not only the Calculator's -- which matters precisely because the pick now raises the schematic OVER the Calculator, so `.calc.status.msg` is behind another window for the whole gesture.  Under R208b the mode has ENDED by then, so the slot holds the sentence in its neutral state rather than as a live prompt" \
        [list [pcall $slot cget -text] [pcall $slot cget -state] \
              [lindex [pcall calc::status_history] 0] [pg_buf] [pcall calc::pick_running]] \
        [list {selector vt: vt(lp) (transient) from /lp} normal {selector vt: vt(lp) (transient) from /lp} {vt(lp)} 0]
    pcall calc::pick_arm vt
    pg_click $cv 310 0
    check "PG13 ...and so does a REFUSAL, with its own instruction, so a mis-click is answered where the eye already is" \
        [list [pcall $slot cget -text] [pg_buf]] \
        [list {selector vt: M1 is not a net} {vt(lp)}]
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
    # --- R208c with a REAL window and a REAL database -------------------------
    # ⚠⚠ THIS ROW USED TO ASSERT THE OPPOSITE and was restated by the user's own
    # ruling, 2026-10-11: *"A simulation could have both AC and TRAN simulations.
    # The vt or vf need to intelligently pick FROM the loaded results."*  Under
    # R208a `vf` against this TRANSIENT-current result refused; the committed
    # fixture's run also wrote an AC plot, so `vf` now ARMS, and the click inserts
    # `vf(lp)` -- a token that reads the AC analysis whatever is current -- with
    # the AC spelling read back from the AC database itself.  The refusal half
    # (a run with NO AC plot) is fenced on the counted arm, row PK1 of
    # test_calc_selector_names and band AT5 of test_calc_analysis_tokens.
    .calc.buf delete 1.0 end
    set vfsaid [pcall calc::pick_arm vf]
    check "PG13 R208c end to end: `vf` against a TRANSIENT-current result whose run also wrote AC ARMS, on the same canvas" \
        [list $vfsaid [pcall calc::pick_running] [pcall calc::pick_id]] \
        [list {selector vf: click a net on the schematic; ESC cancels} 1 vf]
    pg_click $cv 50 0
    check "PG13 ...and a click on the lp wire inserts vf(lp) and says AC in the head of the sentence, and the one-shot mode ends" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0] [pcall calc::pick_running]] \
        [list {vf(lp)} {selector vf: vf(lp) (AC) from /lp} 0]
    .calc.buf delete 1.0 end
    rename ase::ui::design_path {}
    rename pg_real_dp2 ase::ui::design_path
}


# =============================================================================
# PG14 — EVAL AFTER A PICK: THE MEASUREMENT RUNS IN THE RESULT'S OWN CONTEXT
# =============================================================================
# The user's report, verbatim in doc/claude/calc_feedback_batch/BATCH.md item 1:
# Eval "does nothing" on `cross(v(vbg), 0.5, 1, rising)` just after a `vt` pick,
# and the SAME text typed works.  Measured on this arm: the pick ends with the
# DESIGN window's context current (`ase::ui::design_window` raised and activated
# it), and `calc::meas_apply` invoked the verb in WHATEVER context was current --
# so `calc::series_of` asked the schematic's context for a raw it never had and
# the press answered `Cross: that result has no simulation data loaded.` with the
# buffer and the stack untouched.  The typed press worked only because the
# viewer's context happened to be current.  The plain-RPN arm never had this
# defect: `calc::eval_in_token` has taken the issue-0173 loan since phase 3.
#
# ⚠ THE DRIVE IS THE USER'S OWN: a real press on `.calc.sel.vt`, a real canvas
# click on the `sq` wire, the composed call in the buffer, then a real press on
# `.calc.mode.eval`.  The composition goes through `calc::buf_set_expr`, which is
# what the argument dialog's OK writes with -- the dialog itself is band S28's.
group PG14 {
    pcall calc::pick_end cancel
    pcall calc::stk_set {}
    set vwp {}
    catch {set vwp [dict get $::wviewer::windows $::tok win_path]}
    pg_press .calc.sel.vt
    set cv $::calc::pick(canvas)
    pcall xschem zoom_full
    update
    .calc.buf delete 1.0 end
    pg_click $cv 50 100
    set picked [pg_buf]
    set expr "cross($picked, 0.5, 1, rising)"
    pcall calc::buf_set_expr $expr
    set cwp0 [pcall xschem get current_win_path]
    # the reference, taken INSIDE the viewer's context by the test itself, so the
    # row compares the press against the verb's own answer and not a constant
    set ref NOREF
    if {![catch {wviewer::enter_ctx $::tok} t] && [lindex $t 0]} {
        set m [pcall calc::meas_split $expr]
        # R208c: the operand is the pick's qualified token, so the reference
        # goes through the verb door's own guard-and-rewrite, in the viewer's
        # (transient) context where `vt()` is the current analysis.
        set d [pcall calc::aq_arg_invoke cross [pcall calc::meas_vals cross [dg $m args]]]
        set ref [dg $d value]
        catch {wviewer::leave_ctx $::tok $t}
    }
    check "PG14 fixture: the pick inserted `vt(sq)`, the mode ENDED by itself (R208b), the reference is a real finite crossing, and the context current at the press is the DESIGN window's and NOT the viewer's -- the exact state the user pressed Eval in, so the row below cannot pass by the viewer happening to be current" \
        [list $picked [pcall calc::pick_running] \
              [pg_word [string is double -strict $ref] finite $ref] \
              [pg_word [expr {$vwp ne {} && $cwp0 ne $vwp}] designctx "cwp=$cwp0 viewer=$vwp"]] \
        {vt(sq) 0 finite designctx}
    pg_press .calc.mode.eval
    set got [pg_buf]
    check "PG14 Eval after a pick REPLACES the buffer with the measured value and PUSHES the expression onto the stack, exactly as it does for the same text typed -- the user's item 1" \
        [list [pg_word [expr {[string is double -strict $got] && [string is double -strict $ref] && $got == $ref}] value "buf=$got ref=$ref"] \
              [pcall calc::stk_get]] \
        [list value [list $expr]]
    check "PG14 ...and the status line is the provenance sentence, not a refusal" \
        [pg_word [string match {cross(*) = *} [lindex [pcall calc::status_history] 0]] provenance \
             [lindex [pcall calc::status_history] 0]] provenance
    check "PG14 ...and the press PUT THE CONTEXT BACK: the design window is still current and nothing was re-armed, so the loan the measurement took is invisible to the gesture around it" \
        [list [pcall xschem get current_win_path] [pcall calc::pick_running]] \
        [list $cwp0 0]
    pcall calc::pick_end cancel
    pcall calc::stk_set {}
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG15 — R208c THROUGH THE REAL LOAN: Eval and Plot on analysis-qualified tokens
# =============================================================================
# The user, 2026-10-11: "A simulation could have both AC and TRAN simulations.
# The vt or vf need to intelligently pick FROM the loaded results."  The counted
# arm (tests/headless/test_calc_analysis_tokens.tcl) drives the bracket in the
# current context; this band drives the PRESSES, which take the viewer's
# context loan, with the viewer's database TRANSIENT throughout.  The viewer's
# registry is snapshotted INSIDE its own context before and after, because that
# is the registry an on-demand read would leak into.
proc pg15_viewer {script} {
    set out ERR:noloan
    if {![catch {wviewer::enter_ctx $::tok} t] && [lindex $t 0]} {
        set out [pcall uplevel #0 $script]
        catch {wviewer::leave_ctx $::tok $t}
    }
    return $out
}
group PG15 {
    pcall calc::pick_end cancel
    pcall calc::stk_set {}
    # the references, measured by the test in the viewer's own context and
    # undone before the snapshot: read AC, take v(lp)'s last sample, drop it
    set ref [pg15_viewer {
        set r {}
        set ::PG15CUR [calc::wave_dest_cur]
        xschem raw read $::fixture ac
        lappend r [lindex [xschem raw values v(lp) 0] end]
        xschem raw clear $::fixture ac
        xschem raw read $::fixture tran
        lappend r [lindex [xschem raw values v(lp) 0] end]
        set r
    }]
    set info0 [pg15_viewer {list [xschem raw info] [calc::wave_dest_cur]}]
    check "PG15 fixture: the viewer's database is TRANSIENT, and v(lp) reads two numbers far apart in AC and in transient -- so a press that read the wrong analysis cannot pass" \
        [list [lindex [lindex $info0 1] 1] [expr {abs([lindex $ref 0] - [lindex $ref 1]) > 0.1}]] \
        {tran 1}
    set wantac "= [format %.8g [lindex $ref 0]]  (at the last point)"
    set wanttr "= [format %.8g [lindex $ref 1]]  (at the last point)"
    set got {}
    foreach txt {vf(lp) vt(lp) {vf("lp")}} {
        .calc.buf delete 1.0 end
        .calc.buf insert end $txt
        pg_press .calc.mode.eval
        lappend got [lindex [pcall calc::status_history] 0] [pg_buf]
    }
    check "PG15 a real Eval press on vf(lp) answers the AC value, on vt(lp) the transient one, and on the Cadence-quoted vf(\"lp\") the AC one again -- with the viewer showing transient throughout -- and the buffer keeps what was typed" \
        $got [list $wantac vf(lp) $wanttr vt(lp) $wantac {vf("lp")}]
    check "PG15 ...and the viewer's registry and current slot are byte-identical after the three presses: the AC slot read on demand was cleared and transient restored" \
        [pg15_viewer {list [xschem raw info] [calc::wave_dest_cur]}] $info0
    .calc.buf delete 1.0 end
    .calc.buf insert end {bandwidth(vf(lp), 3, magnitude, low, 0)}
    pg_press .calc.mode.eval
    set bw [pg_buf]
    check "PG15 a measurement call on vf(lp) through Eval -- bandwidth, which refuses anything but an AC sweep -- replaces the buffer with a finite frequency and pushes what was typed, with the viewer on transient" \
        [list [string is double -strict $bw] [expr {[string is double -strict $bw] && $bw > 1.0}] [pcall calc::stk_get]] \
        [list 1 1 [list {bandwidth(vf(lp), 3, magnitude, low, 0)}]]
    pcall calc::stk_set {}
    set typed {vt(lp) vf(lp) +}
    .calc.buf delete 1.0 end
    .calc.buf insert end $typed
    pg_press .calc.mode.eval
    check "PG15 two analyses in one expression are REFUSED through calc::status, which tees the CIW, and the buffer keeps the text" \
        [list [lindex [pcall calc::status_history] 0] [pg_buf]] \
        [list {Cannot evaluate: vt() and vf() read different analyses} $typed]
    .calc.buf delete 1.0 end
    .calc.buf insert end vf(lp)
    pg_press .calc.mode.plot
    check "PG15 Plot of vf(lp) while the viewer shows transient is REFUSED naming both -- never plotted from the transient column" \
        [list [lindex [pcall calc::status_history] 0] [pg_buf]] \
        [list {Cannot plot vf(): the waveform viewer shows transient} vf(lp)]
    check "PG15 ...and after all of it the viewer's registry is still byte-identical" \
        [pg15_viewer {list [xschem raw info] [calc::wave_dest_cur]}] $info0
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG15w — R208c: A WAVE-SHAPED VERB ON vt() WITH THE VIEWER ON AC
# =============================================================================
# `riseTime` with nth 0 answers a wave, so the verb builds a `__calc_destN`
# destination INSIDE the bracket's on-demand transient slot.  The press must
# hand that destination to the viewer -- not refuse with "could not return",
# and not leave it as a stray slot the hand-off never drew.  The viewer is put
# on AC for the band and back on transient after it.
group PG15w {
    pcall calc::stk_set {}
    set setup [pg15_viewer {
        xschem raw read $::fixture ac
        list [xschem raw info] [calc::wave_dest_cur]
    }]
    check "PG15w fixture: the viewer's database is now AC" [lindex [lindex $setup 1] 1] ac
    set typed {riseTime(vt(sq), 0, 1, 10, 90, 0, 0)}
    .calc.buf delete 1.0 end
    .calc.buf insert end $typed
    pg_press .calc.mode.eval
    set st [lindex [pcall calc::status_history] 0]
    set after [pg15_viewer {list [xschem raw info] [calc::wave_dest_cur]}]
    set dests {}
    foreach ln [split [lindex $after 0] "\n"] {
        if {[regexp {^[0-9]+ (__calc_dest[0-9]+) table$} $ln -> n]} { lappend dests $n }
    }
    set olddests {}
    foreach ln [split [lindex $setup 0] "\n"] {
        if {[regexp {^[0-9]+ (__calc_dest[0-9]+) table$} $ln -> n]} { lappend olddests $n }
    }
    set new {}
    foreach n $dests { if {[lsearch -exact $olddests $n] < 0} { lappend new $n } }
    check "PG15w a real Eval press on riseTime(vt(sq), ...) with nth 0 and the viewer on AC hands ONE new destination to the viewer, saying so -- not 'could not return to the AC analysis'" \
        [list [llength $new] $st] \
        [list 1 [calc::arg_msg destination riseTime [lindex $new 0]]]
    check "PG15w ...the viewer is still on AC, and its registry is what it was plus that destination, appended" \
        [list [lindex [lindex $after 1] 1] \
              [expr {[lindex $after 0] eq "[lindex $setup 0][expr {[llength [split [string trim [lindex $setup 0]] \n]] - 1}] [lindex $new 0] table\n"}]] \
        {ac 1}
    pg15_viewer {
        foreach ln [split [xschem raw info] "\n"] {
            if {[regexp {^[0-9]+ (__calc_dest[0-9]+) table$} $ln -> n]} {
                calc::wave_dest_drop [dict create db $n type table]
            }
        }
        xschem raw clear $::fixture ac
        xschem raw switch $::fixture tran
    }
    check "PG15w ...and once the band's own AC slot and the destination are dropped the viewer is back on transient" \
        [lindex [lindex [pg15_viewer {list [xschem raw info] [calc::wave_dest_cur]}] 1] 1] tran
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG16 — AN UNQUALIFIED SIGNAL IS REFUSED BY EVERY PRESS THAT EVALUATES THE
# BUFFER (the user, 2026-10-12: "I said waveform viewer ok. How would it be ok
# for Calculator?").  Eval, Plot and a measurement's click each refuse
# v(lp), a bare node and an unqualified current with one sentence offering the
# qualified spellings this result holds (tran, AC, op), and touch nothing: the
# buffer keeps what was typed, the stack is not pushed, no dialog opens, and
# the viewer's registry is byte-identical.  The decision is band AT17 of
# tests/headless/test_calc_analysis_tokens.tcl.
# =============================================================================
group PG16 {
    pcall calc::pick_end cancel
    pcall calc::stk_set {}
    set info0 [pg15_viewer {list [xschem raw info] [calc::wave_dest_cur]}]
    set got {}
    foreach txt {v(lp) {lp 2 *} {cross(v(lp), 0.5, 1, rising)} {vt(lp) i(@rtop[i]) /}} {
        .calc.buf delete 1.0 end
        .calc.buf insert end $txt
        pg_press .calc.mode.eval
        lappend got [list [lindex [pcall calc::status_history] 0] [expr {[pg_buf] eq $txt}] [pcall calc::stk_get]]
    }
    set wv {Cannot evaluate: v(lp) names no analysis; write vt(lp), vf(lp) or vdc(lp)}
    check "PG16 a real Eval press on v(lp), on a bare node in postfix, on a measurement call over v(lp) and on an unqualified current beside a qualified voltage is REFUSED naming the first unqualified read and offering this result's spellings -- the buffer keeps the text and nothing is pushed" \
        $got [list [list $wv 1 {}] \
                   [list {Cannot evaluate: lp names no analysis; write vt(lp), vf(lp) or vdc(lp)} 1 {}] \
                   [list $wv 1 {}] \
                   [list {Cannot evaluate: i(@rtop[i]) names no analysis; write it(@rtop[i]), if(@rtop[i]) or idc(@rtop[i])} 1 {}]]
    .calc.buf delete 1.0 end
    .calc.buf insert end v(lp)
    pg_press .calc.mode.plot
    check "PG16 a real Plot press on v(lp) is REFUSED the same way, in Plot's verb, and the buffer keeps the text" \
        [list [lindex [pcall calc::status_history] 0] [pg_buf]] \
        [list {Cannot plot: v(lp) names no analysis; write vt(lp), vf(lp) or vdc(lp)} v(lp)]
    set deadman [after 4000 {catch {.calc.arg.btns.cancel invoke}}]
    set fm [pcall calc::fn_measure cross]
    after cancel $deadman
    set opened [expr {[winfo exists .calc.arg] ? 1 : 0}]
    catch {destroy .calc.arg}
    check "PG16 a measurement click (cross) on a buffer holding v(lp) is refused BEFORE its dialog opens, in the measurement's verb, and the buffer keeps the text" \
        [list $fm $opened [pg_buf]] \
        [list {Cannot measure: v(lp) names no analysis; write vt(lp), vf(lp) or vdc(lp)} 0 v(lp)]
    check "PG16 ...and after every refusal the viewer's registry and current slot are byte-identical" \
        [pg15_viewer {list [xschem raw info] [calc::wave_dest_cur]}] $info0
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG17 — ADE-STYLE INFIX IN THE BUFFER: Eval and Plot read it as Outputs does
# =============================================================================
# The dead end the verifier found: Eval of `v(lp)*2` is refused offering
# `vt(lp)`, and `vt(lp)*2` was then refused as `unknown token 'v(lp)*2'` --
# one token, in a spelling the user never typed.  Eval and Plot now hand the
# buffer to `calc::buf_route`, i.e. `calc::ix_route`, the translator ASE-L
# Outputs uses (R610); postfix passes through it unchanged.  References are
# the POSTFIX of the same text evaluated by the same door, so a press that
# read the infix any other way -- or did not translate it -- cannot pass.
# =============================================================================
group PG17 {
    pcall calc::pick_end cancel
    pcall calc::stk_set {}
    proc pg17_eval {txt} {
        .calc.buf delete 1.0 end
        .calc.buf insert end $txt
        pg_press .calc.mode.eval
        return [lindex [pcall calc::status_history] 0]
    }
    set ref2 [pcall calc::eval_fmt [calc::eval_in_token $::tok {vt(lp) 2 *} 0 tran]]
    set ref1 [pcall calc::eval_fmt [calc::eval_in_token $::tok {vt(lp)} 0 tran]]
    set rpn2 [pg17_eval {vt(lp) 2 *}]
    check "PG17 fixture: the postfix reference answers a number, differs from vt(lp) alone, and a real Eval press on the postfix gives exactly it -- so the rows below compare against a real, discriminating answer" \
        [list [pg_word [string match {= *} $ref2] number $ref2] [pg_word [expr {$ref1 ne $ref2}] distinct "$ref1 / $ref2"] \
              [expr {$rpn2 eq $ref2}]] \
        {number distinct 1}
    set got [list [pg17_eval {v(lp)*2}] [pg17_eval {vt(lp)*2}] [pg_buf]]
    check "PG17 the dead end is closed: Eval of v(lp)*2 is refused offering vt(lp), and Eval of vt(lp)*2 then answers EXACTLY what the postfix vt(lp) 2 * answers -- the buffer keeps the text" \
        $got [list {Cannot evaluate: v(lp) names no analysis; write vt(lp), vf(lp) or vdc(lp)} $ref2 {vt(lp)*2}]
    set refp [pcall calc::eval_fmt [calc::eval_in_token $::tok {vt(lp) vt(sq) - 2 *} 0 tran]]
    check "PG17 precedence and parentheses are ADE's: (vt(lp)-vt(sq))*2 answers the postfix vt(lp) vt(sq) - 2 *" \
        [list [pg17_eval {(vt(lp)-vt(sq))*2}] [pg_word [string match {= *} $refp] number $refp]] [list $refp number]
    set cx NOREF
    set c [pg15_viewer {calc::aq_arg_invoke cross [calc::meas_vals cross [dict get [calc::meas_split {cross(vt(lp), 0.5, 1, rising)}] args]]}]
    catch {set cx [dict get $c value]}
    set said [pg17_eval {cross(vt(lp), 0.5, 1, rising)*2}]
    set v NOVAL
    regexp {^= (\S+)} $said -> v
    check "PG17 a measurement call as an OPERAND is measured in the same loan and its number used: cross(vt(lp), 0.5, 1, rising)*2 answers twice the crossing (a real finite crossing)" \
        [list [pg_word [string is double -strict $cx] finite $cx] \
              [pg_word [expr {[string is double -strict $v] && [string is double -strict $cx] && abs($v - 2.0 * $cx) <= abs($cx) * 1e-6}] twice "said=$said cross=$cx"]] \
        {finite twice}
    set bad [pg17_eval {vt(nosuch)*2}]
    check "PG17 a refusal NEVER quotes a rewritten internal spelling: vt(nosuch)*2 is refused naming vt(nosuch) as typed, and neither v(nosuch) nor the infix as one token appears" \
        [list [pg_word [string match {*vt(nosuch)*} $bad] named $bad] \
              [pg_word [expr {[string first {'v(nosuch)} $bad] < 0 && [string first {*2'} $bad] < 0}] clean $bad]] \
        {named clean}
    check "PG17 an infix syntax error is the translator's own sentence, the one Outputs shows" \
        [pg17_eval {vt(lp)*}] [pcall calc::ix_msg noright *]
    pcall calc::stk_set {}
    # PLOT: the same translation, Plot's verb.
    .calc.buf delete 1.0 end
    .calc.buf insert end {vt(lp)*2}
    pg_press .calc.mode.plot
    set pl [lindex [pcall calc::status_history] 0]
    check "PG17 a real Plot press on vt(lp)*2 PLOTS (the viewer reads the postfix) and the buffer keeps the text" \
        [list [pg_word [string match {Plotted *} $pl] plotted $pl] [pg_buf]] [list plotted {vt(lp)*2}]
    set pls {}
    foreach txt {{vt(nosuch)*2} {vt(lp)*} {cross(vt(lp), 0.5, 1, rising)*2}} {
        .calc.buf delete 1.0 end
        .calc.buf insert end $txt
        pg_press .calc.mode.plot
        lappend pls [lindex [pcall calc::status_history] 0]
    }
    check "PG17 Plot refuses in its OWN verb: an unknown signal named as typed, the translator's sentence as Plot's, and a measurement operand as a number that is not a waveform" \
        [list [pg_word [expr {[string match {Cannot plot:*vt(nosuch)*} [lindex $pls 0]] && [string first {'v(nosuch)} [lindex $pls 0]] < 0}] named [lindex $pls 0]] \
              [lindex $pls 1] [lindex $pls 2]] \
        [list named [pcall calc::ix_plot_say [calc::ix_msg noright *]] \
              {Cannot plot: cross() answers a number, not a waveform.}]
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG18 — R208e: THE CURRENT SELECTORS PICK A VOLTAGE SOURCE OR AN AMMETER
# =============================================================================
# `it`/`if`/`idc`/`is` arm exactly as the voltage selectors do -- the press, the
# raise, the four seized slots, the prompt on the design window, ESC, one-shot
# on success, a miss leaves the mode armed -- and a click anywhere on a source's
# BODY inserts `it(<inst>)`, by the rule ASE-L Select-On-Design uses
# (`ase::ui::sod_source_at`).  Anything else is refused naming terminal
# currents as not supported.  The committed fixture holds no source branch
# current, so this band reads a small ASCII raw of its own into the VIEWER's
# context and puts the committed one back at its foot, which a row checks.
proc pg18_inst {nm} {
    set n [pcall xschem get instances]
    if {![string is integer -strict $n]} { return -1 }
    for {set i 0} {$i < $n} {incr i} {
        if {[pcall xschem getprop instance $i name] eq $nm} { return $i }
    }
    return -1
}
proc pg18_mid {nm} {
    set b [pcall xschem instance_bbox [pg18_inst $nm]]
    if {![regexp {Instance:\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $b -> x1 y1 x2 y2]} { return {0 0} }
    return [list [expr {round(($x1 + $x2) / 2.0)}] [expr {round(($y1 + $y2) / 2.0)}]]
}
group PG18 {
    pcall calc::pick_end cancel
    pcall calc::stk_set {}
    set info0 [pg15_viewer {xschem raw info}]
    set ::pg18raw [file join $::scratch pg18.raw]
    set fh [open $::pg18raw w]
    puts $fh "Title: pg18\nDate: pg18\nPlotname: Transient Analysis\nFlags: real"
    puts $fh "No. Variables: 4\nNo. Points: 3\nVariables:"
    puts $fh "\t0\ttime\ttime\n\t1\tv(lp)\tvoltage\n\t2\ti(vsq)\tcurrent\n\t3\ti(vam)\tcurrent"
    puts $fh "Values:"
    puts $fh " 0\t0.0\n\t0.25\n\t-0.125\n\t0.0625\n"
    puts $fh " 1\t1e-3\n\t0.5\n\t-0.25\n\t0.03125\n"
    puts $fh " 2\t2e-3\n\t0.75\n\t-0.375\n\t0.015625\n"
    close $fh
    set rd [pg15_viewer {xschem raw read $::pg18raw tran}]
    check "PG18 fixture: the band's raw -- one transient holding both sources' branch currents -- is what the Calculator now resolves against" \
        [list $rd [dg [pcall calc::require_result] path] [dg [pcall calc::require_result] type]] \
        [list 1 [file normalize $::pg18raw] tran]
    # --- the arm, by a real press on the real radiobutton -------------------
    pg_press .calc.sel.it
    set cv {}
    catch {set cv $::calc::pick(canvas)}
    # the prompt is kept up by the 80 ms pump against C blanking the slot on
    # the press's own events, so it is read after two pump periods
    after 200 {set ::pg18w 1} ; vwait ::pg18w
    check "PG18 fixture: the raised design's two sources carry the cell types the shared rule reads" \
        [list [pcall xschem getprop instance [pg18_inst Vsq] cell::type] \
              [pcall xschem getprop instance [pg18_inst Vam] cell::type]] \
        {vsource ammeter}
    check "PG18 a real press on `it` arms a pick exactly as `vt` does -- the design is raised, the canvas seized, all four slots taken -- and the sentence and the design window's prompt say what THIS pick wants: a voltage source or an ammeter" \
        [list [lindex [pcall calc::status_history] 0] [pcall calc::pick_running] [pcall calc::pick_id] \
              [set ::calc::selmode] \
              [pg_word [expr {$cv ne {} && [winfo exists $cv]}] live DEAD] \
              [pcall bind $cv <ButtonPress-1>] [pcall bind $cv <B1-Motion>] \
              [pcall [pcall ase::ui::sod_statusbar $cv] cget -text]] \
        [list {selector it: click a voltage source or ammeter; ESC cancels} 1 it it live \
              {calc::pick_click; break} break \
              {Calculator it: click a voltage source or ammeter for its current; ESC cancels}]
    # --- the misses: each refuses, leaves the buffer alone, keeps the mode ------
    pcall xschem zoom_full
    update
    .calc.buf delete 1.0 end
    .calc.buf insert end {keepme}
    .calc.buf mark set insert end-1c
    check "PG18 fixture: the empty point the miss row clicks really is empty canvas, read back from `object_at`" \
        [pcall xschem object_at 150 250] {}
    set res {}
    foreach pt {{310 0} {50 0} {150 250}} {
        pg_click $cv {*}$pt
        lappend res [lindex [pcall calc::status_history] 0] [pg_buf] [pcall calc::pick_running]
    }
    check "PG18 a current selector REFUSES a device that is not a source, and a wire, naming terminal currents as not supported -- and empty canvas with its own sentence; after each the buffer is byte-identical and the mode still live, as a voltage miss leaves it" \
        $res [list \
            {selector it: pick a voltage source or ammeter; terminal currents not supported} keepme 1 \
            {selector it: pick a voltage source or ammeter; terminal currents not supported} keepme 1 \
            {selector it: nothing under the click; click a voltage source or ammeter} keepme 1]
    # --- the hit --------------------------------------------------------------
    pg_click $cv {*}[pg18_mid Vsq]
    check "PG18 a click on the voltage source's BODY inserts `it(vsq)` -- the raw's own spelling with the selector's id where its `i` was -- at the cursor after the typing, and the status line names the analysis and the Cadence path of the instance" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0]] \
        [list {keepme it(vsq)} {selector it: it(vsq) (transient) from /Vsq}]
    check "PG18 ...and the pick is ONE-SHOT (R208b): the mode ended, the grid shows nothing armed, the four slots are handed back byte-identically, and nothing was selected" \
        [list [pcall calc::pick_running] [set ::calc::selmode] [pg_binds $cv] \
              [pcall xschem selection]] \
        [list 0 {} [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                         [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]] {}]
    # Eval of what was inserted reads the source's current, not some other column
    .calc.buf delete 1.0 end
    .calc.buf insert end {it(vsq)}
    pg_press .calc.mode.eval
    set ev [lindex [pcall calc::status_history] 0]
    check "PG18 Eval of the inserted token answers the source's branch current at the last point -- the column the pick named, distinct from the voltage beside it in the same raw" \
        [list $ev [pcall calc::eval_fmt [calc::eval_in_token $::tok {vt(lp)} 0 tran]]] \
        [list {= -0.375  (at the last point)} {= 0.75  (at the last point)}]
    # --- the ammeter, through `it` again, a press after a miss ------------------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    pg_click $cv {*}[pg18_mid Vam]
    check "PG18 an AMMETER body is a source too, by the same rule" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0] [pcall calc::pick_running]] \
        [list {it(vam)} {selector it: it(vam) (transient) from /Vam} 0]
    # --- R204: a source the result does not hold inserts nothing ----------------
    .calc.buf delete 1.0 end
    .calc.buf insert end {keepme}
    pcall xschem setprop instance Vam name Vgone fast
    pg_press .calc.sel.it
    pg_click $cv {*}[pg18_mid Vgone]
    check "PG18 R204 for a source: a source the RESULT does not hold inserts NOTHING, names the current it looked for, and keeps the mode live" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0] [pcall calc::pick_running]] \
        [list keepme {selector it: i(Vgone) is not in this result; nothing inserted} 1]
    pcall xschem setprop instance Vgone name Vam fast
    # --- ESC -----------------------------------------------------------------------
    event generate $cv <Key-Escape>
    update
    check "PG18 a real Escape ends a current pick exactly as it ends a voltage one, slots handed back" \
        [list [pg_buf] [set ::calc::selmode] [pcall calc::pick_running] \
              [lindex [pcall calc::status_history] 0] [pg_binds $cv]] \
        [list keepme {} 0 {selector it: pick cancelled} \
              [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                    [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]]
    # --- the analysis gate applies to a current id as to a voltage one ----------
    pg_press .calc.sel.idc
    check "PG18 `idc` reads the operating point and this result has none, so it REFUSES to arm, naming the analysis" \
        [list [lindex [pcall calc::status_history] 0] [pcall calc::pick_running]] \
        [list {selector idc: this result has no operating point analysis} 0]
    pcall calc::pick_end cancel
    set ::calc::selmode {}
    pcall xschem unselect_all
    # --- put the committed raw back ------------------------------------------
    pg15_viewer {xschem raw clear $::pg18raw tran}
    pg15_viewer {xschem raw read $::fixture tran}
    check "PG18 the band put the viewer's registry back exactly as it found it, so every band below reads the committed fixture" \
        [list [expr {[pg15_viewer {xschem raw info}] eq $info0 ? {same} : [pg15_viewer {xschem raw info}]}] \
              [dg [pcall calc::require_result] path]] \
        [list same [file normalize $::fixture]]
    .calc.buf delete 1.0 end
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
    pg_press .calc.sel.vs
    # ⚠⚠ RESTATED TWICE.  R208a made the second selector refuse because only one
    # analysis could be read; R208c (the user, 2026-10-11) lets every analysis the
    # RUN wrote be read, so `vf` now arms here.  What this row was always about --
    # pressing another selector ENDS the live pick and releases the canvas BEFORE
    # the new id is judged -- is driven with `vs`, which still refuses because the
    # committed fixture's run wrote no DC sweep, so a refusal can still not leave a
    # seize behind.  The arming half is the next two rows.
    check "PG8 pressing ANOTHER voltage selector ENDS the live pick and releases the canvas before the new id is judged -- `vs` then refuses because this run wrote no DC sweep (R208c).  `::calc::selmode` follows the pressed id either way, which is Tk's own write and the grid showing the user what they clicked" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode] \
              [lindex [pcall calc::status_history] 0]] \
        [list 0 {} vs {selector vs: this result has no DC sweep analysis}]
    check "PG8 ...and NO canvas is left seized after the switch: the end path ran, so the four slots are back at their predecessors rather than carrying a dead mode's scripts -- issue 1305's permanent seize is what this forecloses" \
        [list [expr {[info exists ::calc::pick] ? 1 : 0}] [pg_binds $cv8]] \
        [list 0 [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                      [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}]]]
    pg_press .calc.sel.vt
    pg_press .calc.sel.vf
    check "PG8 R208c: pressing `vf` while `vt` is armed SWITCHES to it -- the run wrote AC too, so the new id arms on the same canvas" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode] \
              [lindex [pcall calc::status_history] 0]] \
        [list 1 vf vf {selector vf: click a net on the schematic; ESC cancels}]
    set pg8prev {}
    foreach k {prevpress prevrel prevesc prevmotion} {
        set v NOKEY ; catch {set v $::calc::pick($k)} ; lappend pg8prev $v
    }
    pcall calc::pick_end cancel
    check "PG8 ...and the switched-to mode recorded the canvas's ORIGINAL predecessors, not `vt`'s seize scripts, so ending it hands the four slots back empty -- issue 1305's permanent seize, foreclosed on the arming path too" \
        [list $pg8prev [pg_binds $cv8]] \
        [list {{} {} {} {}} [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
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

# ⚠⚠ THE RACE NAMES ITSELF.  Issue 1659's clobber is what turned this suite's
# display arm red inside one full T1 (`counted_failures=7`, run
# `~/gc26/tests/results.2892484.log` at `8fdc98ed`) while a re-gate at the SAME
# commit in the SAME clone came back clean -- six rows, five of them reading
# "nothing under the click", which is what a pick resolving a clobbered
# `mousex`/`mousey` looks like.  `pg_click` now drains the settle burst before
# the motion AND READS THE PAIR BACK; this row fails on any divergence, so a
# recurrence arrives as ONE row that says what happened rather than as six
# unrelated-looking failures in bands that were not at fault.
# ⚠ It is a RACE DETECTOR and not a fence on the product: a green run here says
# the clobber did not fire during this run, never that it cannot.  The product
# half is issue 1659 and is deliberately unfixed.
check "PGC NO CLICK IN THIS SUITE RESOLVED A CLOBBERED MOUSE PAIR: every `pg_click` read its own point back out of C after the delivering pump, within one schematic unit" \
    [list $::PG_CLOBBER $::PG_CLOBBER_AT] {0 {}}
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
