# tests/headless/test_calc_plot.tcl — the Calculator's PLOT (W11, W13).
#
# Spec   doc/claude/specs/calculator.md §9 R601/R602 (Plot and its destination),
#        §4 W11/W13 (the button and the destination combobox), §9 R607 (name the
#        failing token), §8.1 R506/R508, §11.3 (this file's row in the GUI test
#        table -- the spec names `test_calc_plot.tcl` by name)
# Plan   doc/claude/calculator_batch/PLAN.md phase 3 step 3.3, whose acceptance
#        line is "Typing `v(out) v(in) / db20()` and pressing Plot draws the
#        gain curve"
# Fixture tests/headless/data/calc_fixture.raw + .cir, contract and HAND
#        DERIVATIONS in tests/headless/data/README.md
#
# WHAT THIS FILE IS.  PLAN 3.3's fence, driven against a REAL waveform viewer
# window, a REAL ASE-L session and the REAL engine.  It opens a viewer, reads
# the committed fixture into that viewer's own context, opens the Calculator,
# types into W15 and presses W11 -- and then reads the TRACE DATA back out of
# the raw and compares it with a hand-derived decibel number.
#
# ⚠⚠ THREE PRODUCT PROCS ARE RENAMED ASIDE, AND AN EARLIER REVISION OF THIS
# PARAGRAPH SAID "Nothing here is reached by renaming a product proc aside".
# THAT WAS FALSE, AND IT WAS FALSE IN THE SAME CHANGE THAT WROTE THE THREE
# RENAMES.  It is worth the space because band CE4 of
# tests/headless/test_calc_engine.tcl reached its target the same way and a
# false comment about `annot_p` shipped behind it for a whole stage
# (doc/claude/calculator_batch/receipts/C2-evaluate-blockers.md §2).  Each
# rename, what its stub stands in for, and what drives the REAL proc:
#
#   `wviewer::plot_signals` (band PL5c) -- stubbed to return one forced failure,
#       because once R607's pre-flight has approved an expression this file has
#       no way left to make the seam fail.  THE REAL PROC IS DRIVEN by PL3, PL4,
#       PL5, PL5b, PL5d, PL5e, PL7 and PL7b, and by PL5c's own CONTROL leg,
#       which presses again after the rename is undone.
#   `wviewer::log_action` (band PL6) -- stubbed to CAPTURE the replay line,
#       which is that row's whole subject.  ⚠ NO ROW IN THIS FILE DRIVES THE
#       REAL ONE, and that is a coverage gap named rather than papered over: it
#       is a one-line `catch` around the `xschem log_action` verb, the verb has
#       its own fence in tests/headless/test_replay_door_1619.tcl, and what PL6
#       measures is the line's CONTENT, not its delivery.
#   `wviewer::current_token` (band PL8) -- stubbed to answer empty, so that
#       emptying the viewer registry really leaves the Calculator with no
#       result.  THE REAL PROC IS DRIVEN by PL0, whose `calc::require_result`
#       row resolves the live viewer through `calc::viewer_tokens`, which calls
#       it; PL8 restores it and its last row re-checks the live layout.
#
# Band PL7b renames NOTHING: it reaches the cross-database case by loading a
# SECOND REAL DATABASE, which is the shape that found the defect it fences.
#
# WARN WHY THIS IS A `dcases` ENTRY AND NOT AN `hcases` ONE.  Plot needs a
# waveform viewer, which is a Tk toplevel with a canvas, so there is no headless
# arm that measures anything: the whole file self-skips under --nogui.  Row RB6
# of tests/headless/test_registered_banner_1626.tcl is the reason that matters
# -- an `hcases` entry taking a whole-file no-X exit with no banner is scored
# `HARNESS: ... did not complete cleanly` with every one of its own checks
# passing, which is issue 1615's incident.  So: `dcases` ALONE, the same shape
# as test_calc_buffer, and the gate below deliberately prints NO completion
# banner.  R607's own mechanism has no window in it and is fenced headless in
# band CE13 of test_calc_engine; what this file adds for R607 is the PLOT path.
#
#   PL0  The setup, asserted rather than assumed: a real session, a real viewer
#        window, the fixture read INSIDE that viewer's context, `results::current`
#        answering for real, and `calc::require_result` naming that viewer's
#        token.  Every later band is vacuous without this one, so it is checked.
#   PL1  The context LOAN.  `xschem get semaphore` inside a real button press
#        (the measurement `calc::plot_in_token`'s "no borrow" decision rests on),
#        and the context put BACK after the press -- U8: a Calculator gesture
#        does not drag the waveform viewer with it.
#   PL2  W13: the three labels it offers are three DISTINCT codes to
#        `wviewer::dest_norm`, and `calc::plot_dest_req` reads the widget
#        verbatim rather than translating it.
#   PL3  PLAN 3.3's ACCEPTANCE, as TRACE DATA.  Type the gain expression, press
#        Plot, and read the materialised column back at three ac points against
#        the hand-derived dB values -- including the -3 dB point at exactly
#        1 kHz, sample index 9, which is `-10*log10(2)`.
#   PL4  The model: one trace, its `expr` is the buffer BYTE FOR BYTE, its `vec`
#        is a raw vector that really exists, and the buffer is unchanged (R603's
#        "it does not modify the buffer", which Plot owes as much as Evaluate).
#   PL4b A DECLARED LIMIT: the raw column `wviewer::add_trace` materialises for
#        an expression OUTLIVES the trace.  A Replace throws the trace away and
#        the column stays in the in-memory raw for the session.  The viewer's
#        behaviour, not the Calculator's, and R402's delete is not the answer.
#   PL5  The three destinations, through the real combobox and the real button:
#        Append accumulates, Replace empties the landing strip first, New Strip
#        makes one.  Counts only -- the POLICY is `wviewer::plan_plot`'s and is
#        fenced in test_wave_modes; what is asserted here is that the
#        Calculator's control reaches it.
#   PL5b The press-time push, which PL5 does NOT measure: the combobox is set
#        DIRECTLY, with no `<<ComboboxSelected>>` event, so `calc::plot_rpn`'s
#        own `wviewer::set_plot_dest` is the only thing that can make the choice
#        take effect.  Added because deleting that push reddened nothing.
#   PL5c The viewer seam's own error path: a `wviewer::plot_signals` failure is
#        reported with the viewer's message and never as "Plotted".  Added for
#        the same reason -- discarding the failure list reddened nothing, because
#        R607's pre-flight catches every refusal this file can otherwise reach.
#   PL5d ⚠ RULING 24, WHICH THE CALCULATOR USED TO ASSERT AWAY.  Under MULTI
#        plot mode `wviewer::plan_plot` emits no clear key, so a Replace really
#        is an Append -- the VIEWER is right and the Calculator's claim was
#        wrong.  Drives the mode, asserts the behaviour AND that the sentence
#        says so, with a single-mode control beside it.
#   PL5e ⚠ W13 CANNOT EXPRESS THE VIEWER'S FOURTH DESTINATION, so a press
#        overwrites a `New Tab` the user set from the viewer's own Options menu.
#        Declared, not closed -- what is fenced here is that the press SAYS so
#        instead of taking the choice away in silence.
#   PL6  `calc::dest_changed` PUSHES: changing W13 moves `wviewer::plot_dest` on
#        the viewer holding the result, and logs one replayable line.
#   PL7  R607 on the PLOT path: an unresolvable token is NAMED, an over-long
#        expression is refused by COUNT (which `wviewer::add_trace` alone does
#        NOT catch -- it returns success while the engine writes nothing), and
#        neither refusal plots anything.
#   PL7b ⚠ R607 MUST NOT NAME AN INNOCENT TOKEN.  A single name living in a
#        LOADED-BUT-NOT-CURRENT database is one `wviewer::add_trace` plots
#        correctly (spec §D1), and the pre-flight refused it.  Loads a second
#        real database and asserts the trace LANDS -- plus Evaluate's refusal of
#        the same name, which is TRUE and must stay.
#   PL8  R602 DECLINED, pinned as a row.  With no viewer there is no result, so
#        Plot refuses in U7's ruled sentence instead of opening a window, and
#        `calc::plot_click`'s own code names no viewer-opening verb.  A later
#        stage that reverses the ruling reds this band and has to correct the
#        declaration in `calc::plot_rpn`'s header.
#   PL10 ⚠ THE MEASURED WAVE APPEARS, AGAINST ITS OWN X (stage J unit J1b), and
#        this is the ONLY registered suite that can witness it:
#        `wviewer::signal_list_all` answers `{}` without a viewer window, so
#        `db_by_index` answers `{}` and `add_trace`'s named-database arm is
#        unreachable headless.  Builds TWO destinations whose column names are
#        IDENTICAL -- which is the normal case, because unit J1 never drops one
#        -- hands the SECOND to the viewer, and reads the REAL trace dict: its
#        vector, its `sweep` key, and the `rawfile`/`sim_type` pair that says
#        WHICH database it came from.  An unarmed `add_trace` resolves a bare
#        column name through `resolve_signal_db`, the first slot in
#        `signal_list_all` order that has it, so without the database channel
#        every measurement after the first draws the first one's curve.  Also
#        asserts the destination got its OWN strip (`graph_fullxzoom` frames a
#        whole rect from ONE x quantity, so a measured wave on a mixed strip is
#        drawn off-window -- measured on the bare verbs in band WD12 of
#        test_calc_wave_dest.tcl), that the generated rect text carries one
#        `sweep=` token for it, that NEITHER one-shot channel is left armed, and
#        that the NEXT ordinary press is unaffected.
#        ⚠ THREE ROWS IN IT PASS TODAY AND ARE DECLARED: the no-arm-left leg
#        reads empty on a tree where nothing arms anything, the next-press row
#        is measuring a press that nothing preceded, and the hygiene row is a
#        claim about this band's own cleanup.  The row beside them that would
#        catch a leaked arm is band WD12's instrument row, which drives the two
#        channels directly to show they really do persist when nobody takes them.
#   PL9  R508: with the window closed, both Plot entry points are silent no-ops
#        on BOTH axes.  Runs last, because it closes the window.
#
# NOT asserted, stated rather than hidden: PIXELS.  That the curve is DRAWN is
# eyeball-only, exactly as every other wave rendering is
# (tests/headless/test_wave_viewer.tcl's header says the same).  What is
# asserted is the model, the materialised column's NUMBERS, and that the
# regenerate inside `wviewer::plot_signals` returned without error.
#
# Standalone from the repo ROOT, which is NOT the armed spelling:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_calc_plot.tcl
# the armed one, which gives it a throwaway HOME and the dev display:
#   tests/headless/run_suites.sh test_calc_plot

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# WARN takes the predicate as a SCRIPT, not an evaluated boolean, so a command
# that does not exist on an unfixed tree fails the ROW instead of aborting the
# file.  CREW_BRIEF.md records issue 1616: one throwing row aborted a suite at
# 62 of 402 checks and hid 340 unrelated ones.
proc check_expr {name cond} {
    if {[catch {uplevel 1 [list expr $cond]} v]} { set v "ERR:$v" }
    check $name [expr {$v eq {1} ? 1 : 0}] 1
}
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}
# WARN THE LINE ENDS IN `: FAIL` SO THAT A READER COUNTS IT.  A background error
# raised out of an event handler increments the failure count here, but a bare
# `BGERROR:` line is invisible to BOTH readers -- run_suites.sh echoes only
# `^(FAIL|FATAL)` and summarize_all counts lines ENDING in FAIL.
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

# agreement with a HAND-DERIVED value.  NEVER equality: `xschem raw value`
# prints through `dtoa()` -- "%.8g", src/util.c -- so eight significant digits
# is the ceiling here and the fixture README's own 1e-12 figures are reachable
# only through `xschem raw values` ("%.16g").  Row CE0 of
# tests/headless/test_calc_engine.tcl pins that format string.
proc near {got exp tol} {
    if {![string is double -strict $got]} { return "NOTANUMBER:{$got}" }
    if {$exp == 0.0} {
        if {abs($got) <= $tol} { return ok }
        return "off:{$got} abs=[expr {abs($got)}]"
    }
    set r [expr {abs(($got - $exp) / double($exp))}]
    if {$r <= $tol} { return ok }
    return "off:{$got} rel=$r"
}
proc dg {d k} {
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}

# --- the decommenter, LIFTED rather than copied ------------------------------
# WARN A STRUCTURAL ROW THAT SCANS A RAW `info body` COUNTS COMMENTS, and that
# has false-reddened a registered fence twice in this batch alone -- RB5 of
# test_registered_banner_1626 on a tail comment, and CE12 of test_calc_engine on
# an in-body prose mention.  Band PL9's R508 scan has the same shape: a future
# COMMENT inside a Plot proc naming a `.calc` widget path would move that proc
# into the "unguarded" half on an edit that changed no behaviour.
#
# WARN SO IT IS LIFTED OUT OF tests/headless/test_calc_engine.tcl's OWN TEXT,
# not copied.  A third copy of the same twelve lines is a third thing to keep in
# step, and the whole point of the rule is that a scan must read CODE.  The lift
# is a line scan from `^proc <name>` to the first line that is exactly a close
# brace -- the method tests/headless/test_scratch_home_note.tcl uses on
# run_regression.tcl's `summarize_all` -- and it takes BOTH procs, because
# `ce_code` calls `ce_decomment`: lifting a named subset is the same defect one
# level up (CLAUDE.md limit L9).
#
# Its own non-vacuity is a ROW, not a claim: see the first two rows of PL9.
# `pl_lift_status` carries why it failed, so a broken lift reddens legibly
# instead of raising `invalid command name`.
set pl_lift_status NOTRUN
proc pl_lift_procs {file names} {
    if {![file isfile $file]} { return "no such file: $file" }
    set fh {}
    if {[catch {open $file r} fh]} { return "cannot open: $fh" }
    set txt [read $fh]
    close $fh
    set got {}
    foreach n $names {
        set body {}
        set inside 0
        foreach ln [split $txt \n] {
            if {!$inside} {
                if {[regexp "^proc +$n +" $ln]} { set inside 1 ; lappend body $ln }
                continue
            }
            lappend body $ln
            if {$ln eq [format %c 125]} { break }
        }
        if {![llength $body]} { return "not found: $n" }
        if {[catch {uplevel #0 [join $body \n]} e]} { return "eval failed for $n: $e" }
        lappend got $n
    }
    if {[llength $got] != [llength $names]} { return "lifted [llength $got] of [llength $names]" }
    return ok
}

# WARN WHOLE-FILE gate, and it gets NO completion banner, deliberately.  It ran
# no checks, and a path that announced completion when nothing ran would be a
# worse defect than the one issue 1626 names.  The spelling is
# test_calc_buffer.tcl's `RESULT: SKIP (...)`, which full_audit.sh's is_skip
# matches and which its is_pass therefore refuses.  The consequence is intended:
# this suite is a `dcases` entry and nothing else, so T1 never takes this path,
# and an `hcases` entry would be scored a HARNESS failure -- the correct answer
# for a case that measures nothing.  Row RB6 of
# tests/headless/test_registered_banner_1626.tcl re-measures that.
if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "RESULT: SKIP (no X: Plot needs a real waveform viewer window)"
    flush stdout
    exit 0
}

# recent-files gate (issue 0119): this script loads a real cell
set no_recent_files 1

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch calcplot]

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

# --- helpers over the viewer MODEL -------------------------------------------
proc ngraphs {tok} {
    if {[catch {dict get [wviewer::layout_for $tok] graphs} gs]} { return -1 }
    return [llength $gs]
}
proc alltraces {tok} {
    set out {}
    if {[catch {dict get [wviewer::layout_for $tok] graphs} gs]} { return {} }
    foreach G $gs {
        if {[catch {dict get $G traces} trs]} continue
        foreach tr $trs { lappend out $tr }
    }
    return $out
}
# read ONE value of a materialised column, inside the viewer's own context --
# the column lives in THAT context's raw and nowhere else.
proc tracevecs {tok} {
    set out {}
    foreach tr [alltraces $tok] {
        if {[catch {dict get $tr vec} v]} continue
        lappend out $v
    }
    return $out
}
proc vecval {tok vec point} {
    set t {}
    if {[catch {wviewer::enter_ctx $tok} t]} { return "ERR:$t" }
    if {![lindex $t 0]} { return REFUSED }
    set v {}
    catch {set v [xschem raw value $vec $point 0]}
    catch {wviewer::leave_ctx $tok $t}
    return $v
}
proc vecidx {tok vec} {
    set t {}
    if {[catch {wviewer::enter_ctx $tok} t]} { return "ERR:$t" }
    if {![lindex $t 0]} { return REFUSED }
    set i -1
    catch {set i [xschem raw index $vec]}
    catch {wviewer::leave_ctx $tok $t}
    return $i
}
proc bufset {s} {
    if {![winfo exists .calc.buf]} { return MISSING }
    catch {.calc.buf delete 1.0 end}
    catch {.calc.buf insert 1.0 $s}
    catch {.calc.buf edit reset}
    update idletasks
    return [pcall .calc.buf get 1.0 end-1c]
}
proc press {w} { pcall $w invoke ; update idletasks ; return [pcall .calc.status.msg get] }
proc destset {label} {
    pcall .calc.mode.dest set $label
    pcall event generate .calc.mode.dest <<ComboboxSelected>>
    update idletasks
    return [pcall .calc.status.msg get]
}
proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
        update
        if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
        after 20
    }
    return 0
}
# the whole `calc` namespace's state, enumerated FROM THE NAMESPACE (CLAUDE.md's
# limit L9: a hand-kept list of state to watch is the same defect one level up).
proc ns_state {} {
    set d {}
    foreach v [lsort [info vars ::calc::*]] {
        if {[array exists $v]} {
            lappend d $v [list ARRAY [lsort [array get $v]]]
        } elseif {[info exists $v]} {
            lappend d $v [set $v]
        } else {
            lappend d $v UNSET
        }
    }
    return $d
}
proc ns_diff {before after} {
    array set b $before
    array set a $after
    set out {}
    foreach k [lsort [array names a]] {
        if {![info exists b($k)]} { lappend out "+[namespace tail $k]" ; continue }
        if {$a($k) ne $b($k)} { lappend out [namespace tail $k] }
    }
    foreach k [lsort [array names b]] {
        if {![info exists a($k)]} { lappend out "-[namespace tail $k]" }
    }
    return $out
}

# THE HAND-DERIVED NUMBERS, from tests/headless/data/README.md's ac table, each
# with the arithmetic beside it so a disagreeing row is a product or fixture
# change and never "the number drifted".  `v(sq)` is the deck's `AC 1` drive, so
# `H = v(lp)/v(sq) = 1/(1 + j f/1000)` with the pole at EXACTLY 1 kHz by
# construction (clp = 1/(2*pi*rac*fp), rac = 1k, fp = 1k), and `ac lin 20 100 2k`
# steps by exactly 100 Hz so index 9 really is 1000.0.
#   index  0 ->  f =  100: |H| = 1/sqrt(1.01), db20 = -20*log10(sqrt(1.01))
#   index  9 ->  f = 1000: |H| = 1/sqrt(2),    db20 = -10*log10(2)   <- the -3 dB point
#   index 19 ->  f = 2000: |H| = 1/sqrt(5),    db20 = -10*log10(5)
set GAIN   {v(lp) v(sq) / db20()}
set DB_0   -0.04321373782642570
set DB_9   -3.010299956639812
set DB_19  -6.989700043360187

if {[catch {

# =============================================================================
# PL0 — the setup is a MEASUREMENT, not an assumption
# =============================================================================
set tok {}
group PL0 {
    check_expr "PL0 fixture: the committed .raw was located" {[file isfile $::fixture]}
    set st [pcall ase::state_load $::statefile]
    check_expr "PL0 fixture: the session state loaded" {![string match ERR:* $st]}
    dict set st rundir [file join $::scratch run]
    set sstate [file join $::scratch session.state]
    pcall ase::state_save $sstate $st
    set ::tok [pcall ase::session_key sky130_tests test_nfet_final ngspice_state1]
    check "PL0 fixture: the session opened under its own key" \
        [pcall ase::session_open $::tok $sstate] $::tok
    check "PL0 fixture: wviewer::open returns 1" [pcall wviewer::open $::tok] 1
    set vtop [pcall wviewer::window_for $::tok]
    check_expr "PL0 fixture: the viewer canvas is mapped" {[viewer_ready $vtop]}
    # the fixture read goes INSIDE the viewer's context, because that is the
    # context `results::current` is asked about and the one Plot will plot into.
    set t [pcall wviewer::enter_ctx $::tok]
    set rd {} ; set cur {}
    if {[lindex $t 0]} {
        catch {set rd [xschem raw read $::fixture ac]}
        catch {set cur [results::current]}
        catch {wviewer::leave_ctx $::tok $t}
    }
    check "PL0 fixture: the ac plot is read into the VIEWER's context and is the current result there" \
        [list $rd [pcall dict get $cur type] [pcall dict get $cur cur]] {1 ac 1}
    check "PL0 calc::open builds the window" [pcall calc::open] {.calc}
    update idletasks
    # ...and the Calculator's own resolver finds THAT viewer.  Without this row
    # every behavioural band below could pass against a refusal.
    set g [pcall calc::require_result]
    check "PL0 calc::require_result names the viewer holding the fixture, by SLOT and by TOKEN" \
        [list [dg $g ok] [dg $g type] [dg $g idx] [dg $g token]] [list 1 ac 0 $::tok]
    check "PL0 ...and the Results Dir row names the same file (U3: the row PICKS)" \
        [pcall .calc.res.path get] $::fixture
}

# =============================================================================
# PL1 — the context loan: no borrow needed, and the context goes BACK
# =============================================================================
# WARN THE FIRST ROW IS THE MEASUREMENT `calc::plot_in_token`'s DESIGN RESTS ON.
# `wviewer::enter_ctx`'s issue-0314 borrow door is documented as open only for
# callers that "only READ", and Plot writes the layout and redraws -- so Plot
# must get by on the PLAIN switch.  That is only true if a Calculator button
# press is not inside xschem's `callback()` frame, which raises the semaphore
# and makes `switch_window` refuse outright.  Measured here, from inside a real
# `-command`, rather than reasoned about.
# =============================================================================
group PL1 {
    set ::pl1_sem UNSET
    set ::pl1_saved [pcall .calc.mode.plot cget -command]
    proc ::pl1_probe {} { catch {xschem get semaphore} ::pl1_sem }
    pcall .calc.mode.plot configure -command ::pl1_probe
    pcall .calc.mode.plot invoke
    update idletasks
    pcall .calc.mode.plot configure -command $::pl1_saved
    check "PL1 a Calculator button -command runs OUTSIDE xschem's callback() frame, so the semaphore is 0 and an unborrowed context switch succeeds" \
        $::pl1_sem 0
    check "PL1 ...and the button's own command is back" \
        [pcall .calc.mode.plot cget -command] $::pl1_saved
    # ⚠⚠ THIS BAND PRESSES PLOT FROM ANOTHER WINDOW'S CONTEXT, AND THAT IS WHAT
    # MAKES IT MEASURE THE LOAN AT ALL.  Measured in Stage D2: `wviewer::open`
    # leaves the xschem context standing IN the viewer, and `wviewer::enter_ctx`
    # then takes its "already there" fast path for the fixture read, so
    # `leave_ctx` restores nothing while the context is the viewer's.
    #
    # ⚠ THE TWO SENTENCES THAT USED TO STAND HERE ARE WITHDRAWN, MEASURED 2026-10-03
    # BY THE CREW THAT ADDED PL10's OWN GIVE-BACK LEG.  They said this was "the
    # ONLY band that presses Plot from another window's context" and that "every
    # band after PL0 is already in the viewer's context and the loan is redundant
    # there".  Both are false now and the second was made false by THIS band: PL1
    # switches to `.drw` and never switches back, so every later band runs from a
    # FOREIGN context and every hand-off there takes a REAL loan.  PL10's leg
    # relies on exactly that, and asserts it rather than assuming it -- it carries
    # a non-vacuity leg proving `.drw` cannot see the fixture at all, plus its own
    # explicit context switch, so a reorder of this band cannot silently stop it
    # measuring the loan.  A comment claiming to be the only site of something is
    # a claim about the whole file that nothing re-checks: see CLAUDE.md on a row
    # name describing its coverage rather than its method.
    # A sabotage that removed the bracket from `calc::plot_in_token` ALTOGETHER
    # therefore reddened ZERO rows, because the one band standing somewhere else
    # asserted only `current_win_path` and never that the press had worked.
    # That is CLAUDE.md's "a fence keyed to a symptom dies quietly when
    # something else cures the symptom", with the symptom being the context and
    # not the plot.
    #
    # So the row below asserts BOTH halves in one place: the press SUCCEEDS from
    # a foreign context (which it can only do by taking the loan) and the
    # context comes BACK (U8 -- a Calculator gesture does not drag the waveform
    # viewer with it).  The non-vacuity leg is the third one: `.drw` genuinely
    # cannot see the fixture, so a press that plotted must have switched.
    pcall xschem new_schematic switch .drw
    set was [pcall xschem get current_win_path]
    set drwraw [pcall xschem raw loaded]
    pcall bufset $::GAIN
    set said1 [press .calc.mode.plot]
    check "PL1 ⚠ U8 a press from ANOTHER window's context PLOTS -- so the loan is TAKEN and not merely attempted -- and the context comes BACK, with the gesture's own window unable to see the fixture at all" \
        [list $was [string match {Plotted*} $said1] [pcall xschem get current_win_path] \
              [expr {[string is integer -strict $drwraw] && $drwraw < 0}]] {.drw 1 .drw 1}
}

# =============================================================================
# PL2 — W13: three labels, three codes, read verbatim
# =============================================================================
group PL2 {
    check "PL2 W13 offers exactly the three labels spec §4 names" \
        [pcall .calc.mode.dest cget -values] {Append Replace {New Strip}}
    set codes {}
    foreach L [pcall .calc.mode.dest cget -values] {
        lappend codes [pcall wviewer::dest_norm $L]
    }
    # WARN THE ROW NAME USED TO GO ON "...so the control is not offering a
    # choice the viewer collapses", AND THAT WAS FALSE.  `dest_norm` is pure and
    # the three labels really are three codes, which is all this row measures;
    # what the viewer does with `replace` afterwards depends on the PLOT MODE,
    # and under multi it collapses to an append (ruling 24).  Band PL5d measures
    # that, and the Calculator now says it.
    check "PL2 ...and wviewer::dest_norm reads them as THREE DISTINCT codes, so the control is not offering one code under three labels" \
        [list $codes [llength [lsort -unique $codes]]] {{append replace newstrip} 3}
    check "PL2 ...and the viewer's own label table has a FOURTH the Calculator deliberately omits" \
        [pcall wviewer::dest_labels] {Append Replace {New Strip} {New Tab}}
    pcall .calc.mode.dest set {Replace}
    check "PL2 calc::plot_dest_req returns the LABEL verbatim -- no second label-to-code table in src/calculator.tcl" \
        [pcall calc::plot_dest_req] {Replace}
    pcall .calc.mode.dest set {Append}
    pcall event generate .calc.mode.dest <<ComboboxSelected>>
    update idletasks
}

# =============================================================================
# PL2b — THE ANSWER DICT'S `dest` KEY MEANS ONE THING
# =============================================================================
# WARN IT MEANT TWO.  The refusing paths were handed W13's LABEL while the
# success and seam-failure paths carried `wviewer::set_plot_dest`'s CODE, so a
# phase-6 reader switching on `dest` would have got `New Strip` from one branch
# and `newstrip` from another.  Normalised in `calc::plot_refusal`, which is the
# one place the refusing dict is built.  Every answering path is driven here,
# including the one that resolves nothing.
# =============================================================================
group PL2b {
    set pl2b {}
    lappend pl2b noctx    [dg [pcall calc::plot_in_token {} {v(lp)} {New Strip}] dest]
    lappend pl2b badtoken [dg [pcall calc::plot_in_token $::tok {v(nosuch)} {New Strip}] dest]
    set d [pcall calc::plot_in_token $::tok {v(lp)} {New Strip}]
    lappend pl2b ok [dg $d dest]
    check "PL2b the answer dict's `dest` is the resolved CODE on the noctx, badtoken and success paths alike, never W13's label" \
        $pl2b {noctx newstrip badtoken newstrip ok newstrip}
    check "PL2b ...and the success path really did plot, so the row above is not three refusals agreeing" \
        [dg $d ok] 1
    check "PL2b ...and a destination nothing resolved stays EMPTY rather than being folded to `append`, which would invent a choice the user never made" \
        [dg [pcall calc::plot_refusal {x}] dest] {}
    pcall .calc.mode.dest set {Append}
    pcall event generate .calc.mode.dest <<ComboboxSelected>>
    update idletasks
}

# =============================================================================
# PL3 — PLAN 3.3's ACCEPTANCE, ASSERTED AS TRACE DATA
# =============================================================================
# "Typing `v(out) v(in) / db20()` and pressing Plot draws the gain curve."  On
# this fixture `out` is `v(lp)` and `in` is `v(sq)`.  What is checked is not that
# a call returned without error: the materialised column is READ BACK at three
# ac points and compared with the hand-derived decibel values above.
# =============================================================================
set PL3_VEC {}
group PL3 {
    set t {}
    if {[catch {wviewer::enter_ctx $::tok} t]} { set t {0 {}} }
    if {[lindex $t 0]} {
        catch {wviewer::clear_all $::tok}
        catch {wviewer::leave_ctx $::tok $t}
    }
    update idletasks
    check "PL3 fixture: a cleared viewer holds one empty strip and no traces" \
        [list [ngraphs $::tok] [llength [alltraces $::tok]]] {1 0}
    check "PL3 fixture: the buffer holds the gain expression, byte for byte" \
        [bufset $::GAIN] $::GAIN
    destset {Append}
    set said [press .calc.mode.plot]
    set trs [alltraces $::tok]
    check "PL3 the press landed exactly ONE trace" [llength $trs] 1
    set ::PL3_VEC [pcall dict get [lindex $trs 0] vec]
    check "PL3 ...and the status line says what was plotted and where" \
        [list [string match {Plotted*} $said] [string match "*$::PL3_VEC*" $said] \
              [string match {*Append*} $said]] {1 1 1}
    # THE NUMBERS.  Three points, each hand-derived, read out of the raw the
    # viewer now holds.
    check "PL3 ⚠ THE -3 dB POINT: the trace's own column at index 9 (f = 1 kHz exactly) is -10*log10(2)" \
        [near [vecval $::tok $::PL3_VEC 9] $::DB_9 1e-7] ok
    check "PL3 ...and at index 0 (f = 100 Hz) it is -20*log10(sqrt(1.01))" \
        [near [vecval $::tok $::PL3_VEC 0] $::DB_0 1e-7] ok
    check "PL3 ...and at index 19 (f = 2 kHz) it is -10*log10(5)" \
        [near [vecval $::tok $::PL3_VEC 19] $::DB_19 1e-7] ok
    # ...and the three are genuinely different numbers, so a column of constants
    # could not satisfy the three rows above.  THIS IS THE CURVE.
    check "PL3 ...and the three are a falling CURVE, not one number read three times" \
        [list [expr {[vecval $::tok $::PL3_VEC 0] > [vecval $::tok $::PL3_VEC 9]}] \
              [expr {[vecval $::tok $::PL3_VEC 9] > [vecval $::tok $::PL3_VEC 19]}]] {1 1}
}

# =============================================================================
# PL4 — the model, and what Plot must NOT touch
# =============================================================================
group PL4 {
    set tr [lindex [alltraces $::tok] 0]
    check "PL4 the trace records the EXPRESSION the user typed, byte for byte" \
        [pcall dict get $tr expr] $::GAIN
    check "PL4 ...and its `vec` is a raw vector that really exists in the viewer's context, so the trace is not a dangling name" \
        [expr {[vecidx $::tok $::PL3_VEC] >= 0}] 1
    check "PL4 ...and that vector is NOT a `__calc_tmp` one: R402's delete discipline belongs to Evaluate's scratch column, not to a trace that has to keep reading its own" \
        [string match __calc_tmp* $::PL3_VEC] 0
    check "PL4 ...and the name is wviewer::auto_expr_name's, which is why nothing here mints one" \
        [string match expr* $::PL3_VEC] 1
    check "PL4 R603 Plot does not modify the buffer" \
        [pcall .calc.buf get 1.0 end-1c] $::GAIN
    check "PL4 R506 the press is recorded in the status history, newest first" \
        [string match {Plotted*} [lindex [pcall calc::status_history] 0]] 1
}

# =============================================================================
# PL4b — A DECLARED LIMIT: THE MATERIALISED COLUMN OUTLIVES ITS TRACE
# =============================================================================
# WARN DECLARED, NOT FIXED, AND IT IS THE VIEWER'S BEHAVIOUR RATHER THAN THE
# CALCULATOR'S.  `wviewer::add_trace` materialises a multi-token RPN as a
# PERSISTENT raw vector (`wviewer::auto_expr_name` -> `expr1`, `expr2`, ...)
# because the trace has to keep reading it while it is on the canvas.  Nothing
# un-materialises it when the trace goes: `wviewer::clear_graph_traces` drops
# the MODEL entry, and the column stays in the in-memory raw for the rest of the
# session.  So every Plot press of an expression leaves one, including presses
# whose trace a later Replace has just thrown away.
#
# WARN AND R402's DELETE IS NOT THE ANSWER.  Applying Evaluate's `raw del`
# discipline to this column blanks live traces -- that is sabotage `P14` of
# doc/claude/calculator_batch/receipts/D-plot.md, which reddens rows in this
# band and in PL3 and PL5.  (⚠ This sentence quoted a red COUNT and the count
# was wrong: it said 26 where that receipt's own table says 7.  A sabotage red
# count is a measurement that lives in the receipt which took it, and nothing
# re-measures a copy of it here -- so the citation stays and the number goes.
# This is the sixth such figure removed from these files.)
# A correct fix would have to know that no trace in any tab still reads
# the column, which is `wviewer::add_trace`'s knowledge and not this file's.
# Recorded here so that a later stage closing it reds this band.
# =============================================================================
group PL4b {
    set gone $::PL3_VEC
    check "PL4b fixture: the expression's materialised column is on the canvas and resolves in the raw" \
        [list [expr {[lsearch -exact [tracevecs $::tok] $gone] >= 0}] \
              [expr {[vecidx $::tok $gone] >= 0}]] {1 1}
    destset {Replace}
    pcall bufset {v(lp)}
    press .calc.mode.plot
    check "PL4b the Replace threw the expression's TRACE away" \
        [list [lsearch -exact [tracevecs $::tok] $gone] [llength [alltraces $::tok]]] {-1 1}
    check "PL4b ⚠ DECLARED LIMIT: ...and its materialised column is STILL in the raw, because nothing un-materialises one -- every expression press leaks one for the session" \
        [expr {[vecidx $::tok $gone] >= 0}] 1
    destset {Append}
}

# =============================================================================
# PL5 — the three destinations, through the real control
# =============================================================================
# The POLICY is `wviewer::plan_plot`'s and is fenced by test_wave_modes; what is
# asserted here is that W13 REACHES it, which is R601's actual requirement.
# =============================================================================
group PL5 {
    # Append: a second press accumulates in the same strip.
    destset {Append}
    pcall bufset {v(lp)}
    press .calc.mode.plot
    check "PL5 Append accumulates: two presses, one strip, two traces" \
        [list [ngraphs $::tok] [llength [alltraces $::tok]]] {1 2}
    # New Strip: forces a fresh one and lands there.
    destset {New Strip}
    pcall bufset {v(sq)}
    press .calc.mode.plot
    check "PL5 New Strip forces a fresh strip and lands the trace in it" \
        [list [ngraphs $::tok] [llength [alltraces $::tok]]] {2 3}
    # Replace: empties the landing strip before adding.  The target is the strip
    # the last single-mode plot landed in, which New Strip just moved.
    destset {Replace}
    pcall bufset {v(ramp)}
    press .calc.mode.plot
    check "PL5 Replace empties the landing strip first: the strip count holds and the TOTAL trace count falls back" \
        [list [ngraphs $::tok] [llength [alltraces $::tok]]] {2 3}
    # ⚠ THE PER-STRIP COUNTS, not just the last trace's expression.  An earlier
    # revision of this row was named "the strip it landed in holds exactly the
    # one new trace" and asserted only `[lindex [alltraces] end] expr`, which
    # says nothing about how many traces that strip holds -- the row name
    # claimed more than the assertion measured.
    set pl5_counts {}
    foreach G [pcall dict get [pcall wviewer::layout_for $::tok] graphs] {
        lappend pl5_counts [llength [pcall dict get $G traces]]
    }
    check "PL5 ...and the strip it landed in holds exactly the ONE new trace, with the other strip untouched" \
        [list $pl5_counts [pcall dict get [lindex [alltraces $::tok] end] expr]] \
        {{2 1} v(ramp)}
    destset {Append}
}

# =============================================================================
# PL5b ⚠ THE PUSH AT PRESS TIME, WHICH NOTHING ABOVE MEASURED
# =============================================================================
# ⚠⚠ THIS BAND EXISTS BECAUSE A SABOTAGE WENT GREEN.  Deleting
# `wviewer::set_plot_dest` from `calc::plot_rpn` altogether -- so that W13
# decides nothing at press time -- reddened ZERO rows: every band above reaches
# the combobox through `destset`, which fires `<<ComboboxSelected>>` and so runs
# `calc::dest_changed`, whose own push had already put the destination in place.
# The two pushes are redundant on that path and the press-time one was therefore
# untested.
#
# It is NOT redundant on the path it exists for: a destination chosen while no
# viewer was open, or any route that changes the widget without firing the
# virtual event.  So this band sets the widget DIRECTLY, with no event, which is
# the only way to make the press-time push the sole thing that can work.
# =============================================================================
group PL5b {
    # start from a known-Append window, pushed the ordinary way
    destset {Append}
    pcall bufset {v(dcmid)}
    press .calc.mode.plot
    set pl5b_before {}
    foreach G [pcall dict get [pcall wviewer::layout_for $::tok] graphs] {
        lappend pl5b_before [llength [pcall dict get $G traces]]
    }
    check "PL5b fixture: the window is on Append and the target strip holds more than one trace, so a Replace is observable" \
        [list [pcall wviewer::plot_dest $::tok] \
              [expr {[lindex $pl5b_before [pcall wviewer::target_strip $::tok]] > 1}]] {append 1}
    # ...and now the widget alone, with NO <<ComboboxSelected>>
    pcall .calc.mode.dest set {Replace}
    update idletasks
    check "PL5b the viewer's destination is still Append, because nothing has pushed yet -- the premise of the row below" \
        [pcall wviewer::plot_dest $::tok] append
    pcall bufset {v(lp)}
    press .calc.mode.plot
    set pl5b_after {}
    foreach G [pcall dict get [pcall wviewer::layout_for $::tok] graphs] {
        lappend pl5b_after [llength [pcall dict get $G traces]]
    }
    set gi [pcall wviewer::target_strip $::tok]
    check "PL5b ⚠ the PRESS pushes W13's value: the destination moves to replace and the landing strip is EMPTIED first, with no ComboboxSelected event anywhere" \
        [list [pcall wviewer::plot_dest $::tok] [lindex $pl5b_after $gi]] {replace 1}
    check "PL5b ...and it is the expression just typed that survived in it, so the clear ran BEFORE the add" \
        [pcall dict get [lindex [pcall dict get [lindex [pcall dict get [pcall wviewer::layout_for $::tok] graphs] $gi] traces] 0] expr] \
        {v(lp)}
    destset {Append}
}

# =============================================================================
# PL5c ⚠ A VIEWER FAILURE MUST NOT READ AS A SUCCESS
# =============================================================================
# ⚠⚠ ALSO HERE BECAUSE A SABOTAGE WENT GREEN.  Discarding
# `wviewer::plot_signals`' per-signal failure list -- so a refused add reports
# "Plotted ..." -- reddened ZERO rows, because every refusal this file drives is
# caught by R607's PRE-flight and never reaches the seam at all.  Nothing was
# measuring the seam's own error path.
#
# ⚠ THE VIEWER SEAM IS SHIMMED, AND THAT IS THE POINT RATHER THAN A SHORTCUT:
# the product proc under test (`calc::plot_rpn`) is the REAL one and runs its
# real error branch; what is replaced is the VIEWER verb, because
# `wviewer::add_trace` has no failure this file can reach once the pre-flight
# has approved the expression (its own validation is the same validator).  A
# control leg proves the shim is what made the difference.
# =============================================================================
group PL5c {
    destset {Append}
    pcall bufset $::GAIN
    set n0 [llength [alltraces $::tok]]
    pcall rename wviewer::plot_signals wviewer::__pl5c_real
    proc wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
        return [list [list [lindex $exprs 0] {forced viewer failure}]]
    }
    set said [press .calc.mode.plot]
    pcall rename wviewer::plot_signals {}
    pcall rename wviewer::__pl5c_real wviewer::plot_signals
    check "PL5c a seam failure is REPORTED, carrying the viewer's own message, and never as 'Plotted'" \
        [list $said [string match {Plotted*} $said]] \
        [list {Plot failed: forced viewer failure.} 0]
    check "PL5c ...and nothing was added to the model" [llength [alltraces $::tok]] $n0
    set said2 [press .calc.mode.plot]
    check "PL5c CONTROL: with the real seam back the same press succeeds, so the row above measured the shim and not a broken button" \
        [string match {Plotted*} $said2] 1
}

# =============================================================================
# PL5d ⚠ RULING 24: UNDER MULTI PLOT MODE, REPLACE IS AN APPEND
# =============================================================================
# WARN THE VIEWER IS NOT WRONG HERE AND NOTHING BELOW ASKS IT TO CHANGE.
# `wviewer::plan_plot`'s own banner declares it: the multi arm lands every
# signal either in a strip it CREATES or in a reused EMPTY one, so there is by
# construction nothing for `replace` to clear, and `wviewer::plan_replace_clear`
# returns empty there for every input.  The viewer SURFACES that, in exactly one
# place -- `wviewer::dest_menu_label`, which its Options cascade reads.
#
# WARN WHAT WAS WRONG WAS THE CALCULATOR'S CLAIM.  It named the destination
# through `wviewer::dest_label`, so a press in multi mode said "Plotted expr1
# (Replace)" over an append, and `calc::build_mode`'s own comment asserted the
# viewer could not collapse the choice.  Both rows below have to hold: the
# SENTENCE says it appends, and the BEHAVIOUR really is an append.  A fix that
# only changed the sentence would pass the first and fail the second, and one
# that changed the viewer would redden test_wave_modes instead.
# =============================================================================
group PL5d {
    destset {Append}
    pcall bufset {v(lp)}
    press .calc.mode.plot
    pcall bufset {v(sq)}
    press .calc.mode.plot
    set gi0 [pcall wviewer::target_strip $::tok]
    set pre {}
    foreach G [pcall dict get [pcall wviewer::layout_for $::tok] graphs] {
        lappend pre [llength [pcall dict get $G traces]]
    }
    check "PL5d fixture: single mode, and the target strip holds more than one trace -- so a real Replace would be visible" \
        [list [pcall wviewer::plot_mode $::tok] [expr {[lindex $pre $gi0] > 1}]] {single 1}
    # ...the single-mode CONTROL: Replace here really does clear.
    destset {Replace}
    pcall bufset {v(ramp)}
    press .calc.mode.plot
    set gi1 [pcall wviewer::target_strip $::tok]
    set mid {}
    foreach G [pcall dict get [pcall wviewer::layout_for $::tok] graphs] {
        lappend mid [llength [pcall dict get $G traces]]
    }
    check "PL5d CONTROL in SINGLE mode: Replace empties the landing strip, so the strip really can be cleared on this fixture" \
        [lindex $mid $gi1] 1
    # ...and now MULTI.
    check "PL5d the viewer is in multi plot mode" \
        [pcall wviewer::set_plot_mode multi $::tok] multi
    destset {Append}
    set saidd2 [destset {Replace}]
    check "PL5d ⚠ R506: choosing Replace in multi mode SAYS it appends, instead of naming a policy the mode does not run" \
        [list [string match {*Replace*} $saidd2] [string match {*append*} $saidd2]] {1 1}
    # WARN THE TOTAL IS THE WHOLE TEST, and that is not a weaker assertion than
    # a per-strip one: a Replace that cleared its landing strip of k traces
    # before adding one would leave the total at most where it started, for any
    # k of 1 or more.  Growing by exactly one is only possible if nothing was
    # cleared.  The single-mode leg above is the differential that proves the
    # fixture can be cleared at all.
    set n0 [llength [alltraces $::tok]]
    check "PL5d fixture: there are traces on the canvas for a Replace to have destroyed" \
        [expr {$n0 > 0}] 1
    pcall bufset {v(dcmid)}
    set saidp [press .calc.mode.plot]
    check "PL5d ⚠ AND IT REALLY APPENDS: the total trace count GROWS by exactly one, which a Replace that cleared its landing strip could not do" \
        [expr {[llength [alltraces $::tok]] - $n0}] 1
    check "PL5d ⚠ ...and the press SAYS so: the Plotted sentence names Replace AND that it appends, so the status line is not asserting a Replace that did not happen" \
        [list [string match {Plotted*} $saidp] [string match {*Replace*} $saidp] \
              [string match {*append*} $saidp]] {1 1 1}
    # ...and the NON-VACUITY of the sentence rows: Append in multi mode says
    # nothing extra, so the clause above tracks the destination and not the mode.
    set saida [destset {Append}]
    pcall bufset {v(div)}
    set saidq [press .calc.mode.plot]
    check "PL5d non-vacuity: Append in the same mode carries NO extra clause, so the clause belongs to Replace and not to multi mode as such" \
        [list [string match {*append*} $saida] [string match {*Append*} $saida] \
              [string match {*Append*} $saidq]] {0 1 1}
    # back to the mode every other band assumes, and to a known layout
    check "PL5d the viewer is back in single plot mode" \
        [pcall wviewer::set_plot_mode single $::tok] single
    set t {}
    if {[catch {wviewer::enter_ctx $::tok} t]} { set t {0 {}} }
    if {[lindex $t 0]} {
        catch {wviewer::clear_all $::tok}
        catch {wviewer::leave_ctx $::tok $t}
    }
    update idletasks
    destset {Append}
}

# =============================================================================
# PL5e ⚠ A PRESS THAT TAKES A CHOICE AWAY SAYS SO
# =============================================================================
# WARN W13 OFFERS THREE DESTINATIONS AND `wviewer::dest_labels` HAS FOUR, so a
# user who picked `New Tab` from the viewer's own Options menu loses it to the
# next Calculator press: `calc::plot_rpn` pushes W13's value at
# `wviewer::set_plot_dest` on every press, which is R601's requirement, and W13
# has no spelling that can mean `newtab`.
#
# WARN THE LIMIT IS DECLARED, NOT CLOSED.  W13 still offers three (spec §4), so
# the choice is still taken away; what is fenced here is that the press SAYS so
# (R506) instead of doing it in silence.  A later phase that adds the fourth
# entry makes `calc::plot_dest_dropped` answer empty for every press, and the
# second row below reddens and has to be restated.
# =============================================================================
group PL5e {
    destset {Append}
    check "PL5e fixture: the viewer takes the FOURTH destination from its own Options menu, which W13 cannot express" \
        [list [pcall wviewer::set_plot_dest {New Tab} $::tok] \
              [pcall wviewer::plot_dest $::tok]] {newtab newtab}
    pcall bufset {v(lp)}
    set saide [press .calc.mode.plot]
    check "PL5e ⚠ the press SAYS the New Tab choice is gone, naming it, instead of cancelling it in silence" \
        [list [string match {Plotted*} $saide] [string match {*New Tab*} $saide]] {1 1}
    check "PL5e ...and the measurement behind that sentence: the push really did overwrite the viewer's destination with W13's" \
        [pcall wviewer::plot_dest $::tok] append
    # ...and the non-vacuity: an ordinary press, from a destination W13 CAN
    # express, carries no such clause.
    pcall bufset {v(sq)}
    set saidf [press .calc.mode.plot]
    check "PL5e non-vacuity: a press from a destination W13 DOES offer carries no such clause" \
        [list [string match {Plotted*} $saidf] [string match {*New Tab*} $saidf] \
              [string match {*which W13*} $saidf]] {1 0 0}
    # ...and the proc answers purely, which is what makes it testable at all
    check "PL5e calc::plot_dest_dropped answers the clause for a destination W13 lacks and nothing for the three it has" \
        [list [expr {[pcall calc::plot_dest_dropped newtab append] ne {}}] \
              [pcall calc::plot_dest_dropped append replace] \
              [pcall calc::plot_dest_dropped replace newstrip] \
              [pcall calc::plot_dest_dropped newstrip append] \
              [pcall calc::plot_dest_dropped newtab newtab] \
              [pcall calc::plot_dest_dropped {} append]] {1 {} {} {} {} {}}
    # ⚠ AND "W13 DOES NOT OFFER IT" IS READ OFF THE WIDGET, NOT OFF A LIST IN
    # THE CODE, which the row above cannot tell apart -- a sabotage replacing
    # `calc::plot_dest_offered` with the three labels written out reddened ZERO.
    # The difference is what makes the declaration above honest: a later phase
    # that widens W13 must make this proc answer EMPTY without being edited.  So
    # the widget is widened HERE, in place, and the proc re-asked; it is put
    # back and the restore is asserted, because this band is not the one that
    # owns W13's value list (PL2 is).
    set pl5e_vals [pcall .calc.mode.dest cget -values]
    pcall .calc.mode.dest configure -values [concat $pl5e_vals [list {New Tab}]]
    set widened [pcall calc::plot_dest_dropped newtab append]
    pcall .calc.mode.dest configure -values $pl5e_vals
    set narrowed [pcall calc::plot_dest_dropped newtab append]
    check "PL5e ⚠ ...and it asks the WIDGET: with `New Tab` added to W13's own -values the clause goes away, and comes back when it is removed again -- so a later phase that widens W13 needs no edit here" \
        [list $widened [expr {$narrowed ne {}}]] {{} 1}
    check "PL5e ...and W13's value list was put back exactly as PL2 found it" \
        [pcall .calc.mode.dest cget -values] {Append Replace {New Strip}}
    set t {}
    if {[catch {wviewer::enter_ctx $::tok} t]} { set t {0 {}} }
    if {[lindex $t 0]} {
        catch {wviewer::clear_all $::tok}
        catch {wviewer::leave_ctx $::tok $t}
    }
    update idletasks
    destset {Append}
}

# =============================================================================
# PL6 — calc::dest_changed PUSHES to the viewer
# =============================================================================
group PL6 {
    set ::pl6_log {}
    pcall rename wviewer::log_action wviewer::__pl6_real_log
    proc wviewer::log_action {line} { lappend ::pl6_log $line }
    destset {Append}
    set ::pl6_log {}
    set said [destset {Replace}]
    set got [pcall wviewer::plot_dest $::tok]
    pcall rename wviewer::log_action {}
    pcall rename wviewer::__pl6_real_log wviewer::log_action
    check "PL6 choosing a destination PUSHES it: wviewer::plot_dest on the result's own viewer moves to the chosen code" \
        $got replace
    check "PL6 ...and says so, naming the destination rather than a phase" \
        $said {Plot destination: Replace.}
    check "PL6 ...and logs exactly one replayable line, with the resolved CODE and an explicit token" \
        $::pl6_log [list [list wviewer::set_plot_dest replace $::tok]]
    destset {Append}
}

# =============================================================================
# PL7 — R607 on the PLOT path
# =============================================================================
group PL7 {
    set n0 [llength [alltraces $::tok]]
    pcall bufset {v(nosuch) v(sq) /}
    set said [press .calc.mode.plot]
    check "PL7 R607 an unresolvable token is NAMED, and it is the name the user typed" \
        [list [string match {*v(nosuch)*} $said] [string match {*expression error*} $said]] {1 0}
    check "PL7 ...and nothing was plotted" [llength [alltraces $::tok]] $n0
    # L1: the one class `wviewer::add_trace` does NOT catch.  MEASURED: handed a
    # 199-token expression it returns {} (success) while the engine wrote
    # nothing, so without `calc::rpn_maxtokens` Plot would report a trace it had
    # just filled with issue 0325's zeros.
    set long [string trim [string repeat {v(sq) } 199]]
    pcall bufset $long
    set said2 [press .calc.mode.plot]
    set mx [pcall calc::rpn_maxtokens]
    check "PL7 R607/L1 an over-long expression is refused by COUNT, naming the count and the limit, because that class has no failing token to name" \
        [list [string match {*199*} $said2] [string match "*$mx*" $said2]] {1 1}
    check "PL7 ...and nothing was plotted for it either" [llength [alltraces $::tok]] $n0
    # ...and the CONTROL: `wviewer::add_trace` really does accept it, so the
    # guard is measured against the gap it exists for and not against a
    # hypothetical one.
    set t {}
    set addsaid NORUN
    if {[catch {wviewer::enter_ctx $::tok} t]} { set t {0 {}} }
    if {[lindex $t 0]} {
        catch {set addsaid [wviewer::add_trace $::tok 0 $long]}
        catch {wviewer::leave_ctx $::tok $t}
    }
    check "PL7 ...and the CONTROL for that guard: wviewer::add_trace ACCEPTS the 199-token expression, which is exactly why calc::rpn_maxtokens has to exist" \
        $addsaid {}
    # the empty buffer, which is a different sentence from a bad token
    pcall bufset {}
    set said3 [press .calc.mode.plot]
    check "PL7 an EMPTY buffer gets its own sentence, not a token one" \
        [list $said3 [string match {*token*} $said3]] {{Nothing to plot: the buffer is empty.} 0}
    # non-vacuity: the same control still plots a good expression
    pcall bufset $::GAIN
    set said4 [press .calc.mode.plot]
    check "PL7 non-vacuity: the button still plots a GOOD expression, so the band is not green on a Plot that refuses everything" \
        [string match {Plotted*} $said4] 1
}

# =============================================================================
# PL7b ⚠⚠ R607 MUST NOT NAME A TOKEN THAT IS FINE
# =============================================================================
# WARN THE WORST SHAPE R607 CAN TAKE IS NOT A BARE MESSAGE -- IT IS A WRONG
# NAME.  "Expression error" wastes a user's time; "unknown token 'v(xdbonly)'"
# over a name that resolves perfectly well sends them to EDIT something that was
# never broken.  So the pre-flight must ask the same question the seam asks, and
# fail open wherever it cannot be sure.
#
# WARN WHAT THE SEAM ASKS.  `wviewer::add_trace`'s SINGLE-NAME arm validates
# against the current database and then, on a failure, falls back to
# `wviewer::resolve_signal_db` -- spec §D1: "validation is against EVERY loaded
# database, not just the current one".  The Calculator's pre-flight stopped at
# `xschem raw list`, which is the CURRENT database alone, so a name living in a
# loaded-but-not-current one was refused BY NAME while the one seam the press
# would have used plots it correctly.
#
# WARN THIS BAND LOADS A SECOND REAL DATABASE RATHER THAN SHIMMING ANYTHING.
# The defect was found by driving the real viewer, and a stub for
# `resolve_signal_db` would have measured the stub.  The second raw is a THREE
# POINT ascii file written into this suite's own scratch directory, with one
# uniquely named signal, so nothing it says can come from the committed fixture.
#
# WARN AND EVALUATE'S REFUSAL OF THE SAME NAME IS CORRECT AND MUST STAY.
# Evaluate reaches the engine through `xschem raw add`, which resolves names
# against the CURRENT database only, so that name genuinely cannot be evaluated.
# The last rows measure both halves of that asymmetry, so a later stage cannot
# "fix" Evaluate by making it fail open too.
# =============================================================================
group PL7b {
    set second [file join $::scratch second.raw]
    set fh {}
    if {[catch {open $second w} fh]} {
        check "PL7b fixture: the second ascii raw could be written" "ERR:$fh" ok
    } else {
        puts $fh "Title: * a SECOND database for band PL7b -- one uniquely named signal"
        puts $fh "Date: Thu Oct  1 00:00:00  2026"
        puts $fh "Plotname: Transient Analysis"
        puts $fh "Flags: real"
        puts $fh "No. Variables: 2"
        puts $fh "No. Points: 3"
        puts $fh "Variables:"
        puts $fh "\t0\ttime\ttime"
        puts $fh "\t1\tv(xdbonly)\tvoltage"
        puts $fh "Values:"
        foreach {p tv vv} {0 0.0 11.0 1 1.0e-09 22.0 2 2.0e-09 33.0} {
            puts $fh "$p\t$tv"
            puts $fh "\t$vv"
            puts $fh ""
        }
        close $fh
        check "PL7b fixture: the second ascii raw was written" [file isfile $second] 1
    }
    # read it INSIDE the viewer's context, then put the fixture back as current:
    # the whole point is a database that is LOADED and NOT current.
    set t {}
    set rd2 {} ; set curnames {} ; set curidx NORUN
    if {[catch {wviewer::enter_ctx $::tok} t]} { set t {0 {}} }
    if {[lindex $t 0]} {
        catch {set rd2 [xschem raw read $second tran]}
        catch {set rd2 "$rd2 [xschem raw switch $::fixture ac]"}
        catch {set curnames [split [string trim [xschem raw list]] "\n"]}
        catch {set curidx [xschem raw index {v(xdbonly)}]}
        catch {wviewer::leave_ctx $::tok $t}
    }
    check "PL7b fixture: the second database READ, and the committed fixture is CURRENT again" \
        $rd2 {1 1}
    check "PL7b fixture: and the uniquely named signal is NOT in the current database -- `xschem raw index` cannot see it and it is not in `xschem raw list`" \
        [list $curidx [lsearch -exact $curnames {v(xdbonly)}]] {-1 -1}
    # ...and the viewer CAN see it, through the proc the seam falls back to
    set hit [pcall wviewer::resolve_signal_db $::tok {v(xdbonly)}]
    check "PL7b fixture: the viewer resolves it in a NON-current slot, which is the fact the pre-flight has to ask about" \
        [list [expr {$hit ne {}}] [pcall dict get $hit cur]] {1 0}
    # --- THE ROW THE DEFECT WAS FOUND BY: the trace LANDS ------------------
    destset {Append}
    set n0 [llength [alltraces $::tok]]
    pcall bufset {v(xdbonly)}
    set said [press .calc.mode.plot]
    check "PL7b ⚠⚠ THE TRACE LANDS: a single token naming a signal in a LOADED-BUT-NOT-CURRENT database is PLOTTED, not refused by name" \
        [list [expr {[llength [alltraces $::tok]] - $n0}] [string match {Plotted*} $said]] {1 1}
    # ⚠ THE SECOND LEG OF THIS ROW WAS WRONG AS FIRST WRITTEN and the fixed
    # product caught it: it asserted the sentence does not contain
    # `v(xdbonly)` at all, and a successful press says "Plotted v(xdbonly)
    # (Append)." because that IS the vector that landed.  What must be absent is
    # the REFUSAL -- the token named as unknown -- not the name.
    check "PL7b ⚠ ...and the sentence names it as what was PLOTTED, never as an unknown token, which is the wrong-name failure this band exists for" \
        [list [string match {*unknown token*} $said] [string match {Cannot plot:*} $said] \
              [string match {*v(xdbonly)*} $said]] {0 0 1}
    # ...and the trace really carries the foreign database, which is what makes
    # it a §D1 trace and not a name that happened to resolve somewhere.
    set tr [lindex [alltraces $::tok] end]
    check "PL7b ...and the landed trace carries the FOREIGN database's path and type, so it reads from that slot and not from the current one" \
        [list [pcall dict get $tr expr] \
              [expr {[pcall dict get $tr rawfile] eq $second}] \
              [pcall dict get $tr sim_type]] [list {v(xdbonly)} 1 tran]
    # --- and the pre-flight's own answer, directly -------------------------
    set t2 {}
    set bt_tok NORUN ; set bt_notok NORUN ; set bt_bad NORUN
    if {[catch {wviewer::enter_ctx $::tok} t2]} { set t2 {0 {}} }
    if {[lindex $t2 0]} {
        catch {set bt_tok [calc::rpn_bad_token {v(xdbonly)} $::tok]}
        catch {set bt_notok [calc::rpn_bad_token {v(xdbonly)}]}
        catch {set bt_bad [calc::rpn_bad_token {v(reallynosuch)} $::tok]}
        catch {wviewer::leave_ctx $::tok $t2}
    }
    check "PL7b calc::rpn_bad_token APPROVES it when a viewer token is given -- it asks the seam's second question through the viewer's own proc" \
        $bt_tok {}
    check "PL7b ...and still REFUSES a name no loaded database has, so the pre-flight did not simply stop rejecting things" \
        [list [expr {$bt_bad ne {}}] [string match {*v(reallynosuch)*} $bt_bad]] {1 1}
    check "PL7b ...and WITHOUT a token it still answers for the current database alone, which is the question Evaluate's engine call really asks" \
        [list [expr {$bt_notok ne {}}] [string match {*v(xdbonly)*} $bt_notok]] {1 1}
    # ⚠ THE NAME HANDED OVER IS `string trim`'s, WHICH IS THE ARGUMENT THE SEAM
    # PASSES, and the first draft of this band measured no such thing -- a
    # sabotage that dropped the trim reddened ZERO rows.  `wviewer::add_trace`
    # trims its `rpn` before anything else, so a trailing carriage return --
    # which W15 is a text widget and a paste really can carry -- reaches
    # `resolve_signal_db` trimmed on the seam's path.  A pre-flight handing over
    # the untrimmed string refuses a name the seam then plots, which is this
    # band's whole defect in miniature.  The seam's own answer is the control,
    # so what is asserted is AGREEMENT and not a guess about either.
    set t2b {}
    set bt_cr NORUN ; set seam_cr NORUN
    if {[catch {wviewer::enter_ctx $::tok} t2b]} { set t2b {0 {}} }
    if {[lindex $t2b 0]} {
        catch {set bt_cr [calc::rpn_bad_token "v(xdbonly)\r" $::tok]}
        catch {set seam_cr [wviewer::add_trace $::tok 0 "v(xdbonly)\r"]}
        catch {wviewer::leave_ctx $::tok $t2b}
    }
    check "PL7b ...and the name handed to the viewer is TRIMMED, exactly as add_trace trims its own -- so on a pasted trailing carriage return the pre-flight and the seam agree instead of one refusing what the other plots" \
        [list $bt_cr $seam_cr] {{} {}}
    # --- the asymmetry, through the two real presses ------------------------
    # Evaluate's refusal is TRUE: `xschem raw add` resolves against the current
    # database only, measured by the `raw index` row above.
    set saide [press .calc.mode.eval]
    check "PL7b ⚠ AND EVALUATE STILL REFUSES THE SAME NAME, which is correct rather than a leftover: the engine resolves names against the CURRENT database only" \
        [list [string match {Cannot evaluate:*} $saide] [string match {*v(xdbonly)*} $saide]] {1 1}
    # ...and a bad token is still refused on the PLOT path too, by name
    pcall bufset {v(reallynosuch)}
    set saidr [press .calc.mode.plot]
    check "PL7b ...and the PLOT path still refuses a genuinely unknown name BY NAME, before the seam can clear a strip for it" \
        [list [string match {Cannot plot:*} $saidr] [string match {*v(reallynosuch)*} $saidr]] {1 1}
    # ...and the multi-token case is unaffected: the seam validates an
    # expression against the current database and nothing else, so a foreign
    # name inside one is refused by both, which is agreement and not a gap.
    pcall bufset {v(xdbonly) v(lp) /}
    set saidx [press .calc.mode.plot]
    check "PL7b ...and an EXPRESSION naming it is refused by both, because `add_trace`'s expression arm never asks the second question either -- the two now agree in both directions" \
        [list [string match {Cannot plot:*} $saidx] [string match {*v(xdbonly)*} $saidx]] {1 1}
    pcall bufset {}
    set t3 {}
    if {[catch {wviewer::enter_ctx $::tok} t3]} { set t3 {0 {}} }
    if {[lindex $t3 0]} {
        catch {wviewer::clear_all $::tok}
        catch {wviewer::leave_ctx $::tok $t3}
    }
    update idletasks
}

# =============================================================================
# PL10 — ⚠ THE MEASURED WAVE APPEARS, AGAINST ITS OWN X (stage J unit J1b)
# =============================================================================
# WARN THIS IS THE ONLY REGISTERED SUITE THAT CAN WITNESS IT, and that is
# structural rather than a preference.  `wviewer::signal_list_all` returns `{}`
# unless `dict exists $windows $token`, so `wviewer::db_by_index` answers `{}`
# and `wviewer::add_trace`'s NAMED-DATABASE arm is unreachable without a real
# viewer window.  The counted arm can see what the hand-off ARMED -- band WD12
# of tests/headless/test_calc_wave_dest.tcl records `wviewer::plot_signals` aside
# and reads the two channels out of the recorder -- and it cannot see a trace.
# This file has a real window (fixture PL0), so this band reads the REAL trace
# dict and the REAL strip layout.  It is a `dcases` entry ALONE and self-skips
# whole under `--nogui`, so only a gate's display arm runs any of it.
#
# WARN AND THE DEFECT IT EXISTS FOR IS THE ONE NOBODY HAD NAMED.  Unit J1 never
# drops a destination, so several coexist, and two of them carry the IDENTICAL
# two column names -- measured.  An UNARMED `add_trace` resolves a bare column
# name through `wviewer::resolve_signal_db`, which answers the FIRST slot in
# `signal_list_all` order that has the name, so every measurement after the first
# silently draws the first one's curve.  A hand-off that armed only the sweep
# channel passes any single-measurement row and is wrong on the second click, so
# the keystone below builds TWO destinations and asserts the SECOND one's trace
# names the SECOND one's database.
#
# WARN AND THE STRIP IS NOT DECORATION.  Measured on the bare verbs in band WD12:
# `graph_fullxzoom` fixes ONE x quantity for the whole rect -- the target rect's
# first `sweep=` token -- and `graph_x_extent` contributes nothing for a database
# that lacks it, so on a MIXED strip a measured wave is drawn off-window.  That
# is why the hand-off must go through `wviewer::plot_signals`, which runs
# `plan_plot` and CREATES strips, and not straight to `wviewer::add_trace`, which
# creates nothing and clamps an out-of-range strip index to the LAST strip.
# =============================================================================
group PL10 {
    proc pl_dest {xs ys} {
        set t {}
        if {[catch {wviewer::enter_ctx $::tok} t]} { return "ERR:$t" }
        if {![lindex $t 0]} { return REFUSED }
        set d {}
        if {[catch {calc::wave_dest $xs $ys} d]} { set d "ERR:$d" }
        catch {wviewer::leave_ctx $::tok $t}
        return $d
    }
    proc pl_trkeys {tr} {
        set out {}
        foreach k {vec sweep rawfile sim_type} { lappend out [dg $tr $k] }
        return $out
    }
    # every strip's trace count, so "its own strip" is a measured shape and not a
    # total.
    proc pl_shape {tok} {
        set out {}
        if {[catch {dict get [wviewer::layout_for $tok] graphs} gs]} { return -1 }
        foreach G $gs {
            if {[catch {dict get $G traces} trs]} { lappend out ERR ; continue }
            lappend out [llength $trs]
        }
        return $out
    }
    # the `sweep=` tokens `wviewer::graph_props` emits for a REAL strip, read the
    # way `draw_graph` reads them.
    # ⚠ INSIDE THE VIEWER'S OWN CONTEXT, and that is a correction a dry run
    # against a conforming reference forced rather than a precaution.
    # `wviewer::graph_props` resolves an ordinary trace's token through
    # `wviewer::sweep_default`, which is `xschem raw list`'s FIRST line in the
    # database that is CURRENT RIGHT NOW -- and the Calculator's own context has
    # no raw loaded, so called from here it answered the empty string, every
    # ordinary trace took an empty token, and the generator's own
    # all-or-nothing rule then emitted NO `sweep=` token at all.  Read from
    # outside the context this row measured the wrong thing and said so.
    proc pl_sweeptoks {tok gi} {
        set gs {}
        if {[catch {dict get [wviewer::layout_for $tok] graphs} gs]} { return ERR }
        if {$gi < 0 || $gi >= [llength $gs]} { return "NOSTRIP:$gi" }
        set t {}
        if {[catch {wviewer::enter_ctx $tok} t]} { return "ERR:$t" }
        if {![lindex $t 0]} { return REFUSED }
        set p {}
        set rc [catch {wviewer::graph_props [lindex $gs $gi] 0 1} p]
        catch {wviewer::leave_ctx $tok $t}
        if {$rc} { return "ERR:$p" }
        if {![regexp -line {^sweep="([^"]*)"$} $p -> v]} { return {} }
        return [regexp -all -inline {\S+} $v]
    }
    proc pl_armleft {tok} {
        set out {}
        if {[info exists ::wviewer::plotdbs($tok)]}    { lappend out dbs }
        if {[info exists ::wviewer::plotsweeps($tok)]} { lappend out sweeps }
        return [lsort $out]
    }
    # --- the fixture, asserted -------------------------------------------
    set t0 {}
    if {[catch {wviewer::enter_ctx $::tok} t0]} { set t0 {0 {}} }
    if {[lindex $t0 0]} {
        catch {wviewer::clear_all $::tok}
        catch {wviewer::leave_ctx $::tok $t0}
    }
    update idletasks
    pcall bufset {v(lp)}
    set pl_said0 [press .calc.mode.plot]
    pcall bufset {v(sq)}
    set pl_said1 [press .calc.mode.plot]
    check "PL10 fixture: two ORDINARY traces are on the canvas first, through the real Plot button, so the strip the hand-off lands on is a populated one and `its own strip` is a claim about a layout rather than about an empty window" \
        [list [string match {Plotted*} $pl_said0] [string match {Plotted*} $pl_said1] \
              [expr {[llength [alltraces $::tok]] >= 2 ? {two} : "n=[llength [alltraces $::tok]]"}]] \
        {1 1 two}
    set pl_shape0 [pl_shape $::tok]
    set pl_n0 [llength [alltraces $::tok]]
    # --- TWO destinations, and the SECOND one is the one plotted ----------
    set pl_xs {1.0 2.0 3.0 4.0 5.0}
    set pl_ysA {0.11 0.22 0.33 0.44 0.55}
    set pl_ysB {0.91 0.82 0.73 0.64 0.55}
    set pl_A [pl_dest $pl_xs $pl_ysA]
    set pl_B [pl_dest $pl_xs $pl_ysB]
    set pl_Adb [dg $pl_A db]
    set pl_Bdb [dg $pl_B db]
    # --- the CONTEXT LOAN around the hand-off, measured the way PL1 measures
    # --- Plot's.
    # ⚠ WITHOUT THE THREE LINES BELOW AND THE ROW THEY FEED, NOTHING IN THE TREE
    # ASSERTED THAT `calc::wave_in_token` GIVES THE CONTEXT BACK.  Its bracket is
    # `calc::plot_in_token`'s -- `wviewer::enter_ctx`, the body under `catch`,
    # `wviewer::leave_ctx` unconditionally on the way out -- and row PL1 fences
    # exactly that property for the Plot one, with the SAME discriminant.  A
    # dropped `leave_ctx` here leaves xschem's current-window pointer standing in
    # the WAVEFORM VIEWER, so the user's next gesture lands in the wrong window,
    # and every row in this band still passes: each one reads the viewer's model
    # through `wviewer::layout_for`, which asks nothing about where the context
    # is.  That is CLAUDE.md's "a fence keyed to a symptom dies quietly" in its
    # other direction -- the band measures the PLOT and the loan is the symptom
    # nobody asked about.
    #
    # The switch is EXPLICIT rather than inherited, so the row does not depend on
    # which window an earlier band happened to leave current.  It is a no-op
    # today -- measured: the context at this point is already `.drw`, because
    # PL1's own foreign-context press leaves it there -- and it is written anyway,
    # because a row whose foreign context arrives from four bands away stops
    # measuring the loan the moment PL1 is reordered.
    pcall xschem new_schematic switch .drw
    set pl_ctx_was [pcall xschem get current_win_path]
    set pl_drwraw  [pcall xschem raw loaded]
    set pl_hand [pcall calc::wave_in_token $::tok $pl_B]
    set pl_ctx_back [pcall xschem get current_win_path]
    update idletasks
    set pl_tr {}
    foreach tr [alltraces $::tok] {
        if {[dg $tr vec] eq [dg $pl_B yname]} { set pl_tr $tr }
    }
    check "PL10 ⚠ the measured wave APPEARS, and it appears against ITS OWN X and out of ITS OWN database -- the claim unit J1 could not make at all, because `wviewer::plot_sweeps_arm` had zero callers and the user was left to find the database in the Results picker.  Read off the REAL trace dict: the trace's vector is the destination's Y column, its `sweep` key is the destination's X column, and its `rawfile`/`sim_type` pair is the destination's own registry entry -- so a hand-off that plotted the column name and let the viewer resolve it reddens here" \
        [list [expr {[string match ERR:* $pl_hand] ? "RAISED:$pl_hand" : [dg $pl_hand ok]}] \
              [expr {$pl_tr eq {} ? {NOTRACE} : {found}}] \
              [pl_trkeys $pl_tr]] \
        [list 1 found [list [dg $pl_B yname] [dg $pl_B xname] $pl_Bdb table]]
    check "PL10 ⚠ U8 ...and the hand-off GIVES THE CONTEXT BACK: it ran from ANOTHER window's context, it plotted -- so the loan was TAKEN and not merely attempted -- and `xschem get current_win_path` is the gesture's own window again afterwards, not the viewer's.  PL1 asserts this for `calc::plot_in_token` with the same discriminant; `calc::wave_in_token`'s `wviewer::leave_ctx` had no assertion anywhere, and dropping it leaves the user's next action landing in the waveform viewer while every model row in this band stays green.  The non-vacuity leg is the third one: `.drw` has no raw loaded at all, so a hand-off that plotted must have switched" \
        [list $pl_ctx_was \
              [expr {[string match ERR:* $pl_hand] ? "RAISED:$pl_hand" : [dg $pl_hand ok]}] \
              [expr {[string is integer -strict $pl_drwraw] && $pl_drwraw < 0}] \
              $pl_ctx_back] \
        {.drw 1 1 .drw}
    check "PL10 ⚠⚠ ...and it is the SECOND destination's curve and not the FIRST's, which is the defect this band exists for: two coexisting destinations answer the IDENTICAL two column names, and an unarmed `add_trace` resolves a bare name through `resolve_signal_db` -- the first slot in `signal_list_all` order that has it -- so a hand-off that armed only the sweep channel draws the first measurement for ever after and passes every single-measurement row.  The two databases are asserted to be different names first, or the row would be comparing one thing with itself" \
        [list [expr {$pl_Adb ne $pl_Bdb ? {differ} : "SAME:$pl_Adb"}] \
              [dg $pl_tr rawfile] \
              [expr {[dg $pl_tr rawfile] eq $pl_Adb ? {FIRST} : {notfirst}}]] \
        [list differ $pl_Bdb notfirst]
    check "PL10 ...and the destination got its OWN strip: the layout gained exactly one strip, that strip holds exactly the one measured trace, and the strips that were already there are untouched -- which is what `graph_fullxzoom` needs, because it frames a whole rect from ONE x quantity and a measured wave stacked with ordinary ones is drawn off-window (measured on the bare verbs in band WD12 of test_calc_wave_dest.tcl).  A hand-off that reached `wviewer::add_trace` directly creates no strip and clamps to the LAST one, which is exactly that mixed strip" \
        [list [expr {[llength [pl_shape $::tok]] - [llength $pl_shape0]}] \
              [expr {[llength [alltraces $::tok]] - $pl_n0}] \
              [expr {[lsearch -exact [pl_shape $::tok] 1] >= 0 ? {hasown} : {NOOWNSTRIP}}]] \
        {1 1 hasown}
    # the strip the measured trace landed on, found rather than assumed
    set pl_gi -1
    set pl_gs {}
    catch {set pl_gs [dict get [wviewer::layout_for $::tok] graphs]}
    for {set i 0} {$i < [llength $pl_gs]} {incr i} {
        foreach tr [pcall dict get [lindex $pl_gs $i] traces] {
            if {[dg $tr vec] eq [dg $pl_B yname]} { set pl_gi $i }
        }
    }
    check "PL10 ...and the rect text the strip generates carries ONE `sweep=` token for its one trace, naming the destination's own X column -- which is the POSITIVE SHAPE band WD4 of test_calc_wave_dest.tcl asserts over a model dict, asserted here over the layout the product actually built.  A SHORT list would carry its last token forward and silently re-axe every later trace, and an ABSENT one would drop every trace to column 0: both are measured behaviourally in band WD12" \
        [list [expr {$pl_gi >= 0 ? {found} : {NOSTRIP}}] \
              [pl_sweeptoks $::tok $pl_gi]] \
        [list found [list [dg $pl_B xname]]]
    check "PL10 ...and NEITHER one-shot channel is left armed on this window, read without consuming them: an arm whose caller refuses before reaching `plot_signals` persists for that token and silently re-axes the NEXT plot in that window, and the hand-off has at least as many refusal returns as `calc::plot_rpn`'s three" \
        [pl_armleft $::tok] {}
    # ...and an ordinary Plot press AFTER the measured one is unaffected, which is
    # the consequence a leaked arm would have and the one a user would meet.
    pcall bufset {v(ramp)}
    set pl_said2 [press .calc.mode.plot]
    update idletasks
    set pl_last {}
    foreach tr [alltraces $::tok] { if {[dg $tr vec] eq {v(ramp)}} { set pl_last $tr } }
    check "PL10 ...and the NEXT ordinary Plot press is unaffected: its trace carries NO sweep key, NO rawfile and NO sim_type, so it is on the loaded database's own X exactly as it was before the measured wave arrived -- which is the user-visible consequence a leaked arm would have had, asserted positively rather than as the absence of a symptom" \
        [list [string match {Plotted*} $pl_said2] \
              [expr {$pl_last eq {} ? {NOTRACE} : {found}}] [pl_trkeys $pl_last]] \
        {1 found {v(ramp) NOKEY:sweep NOKEY:rawfile NOKEY:sim_type}}
    # --- hygiene: the destinations are this band's, not the session's -------
    set pl_dropA [pcall calc::wave_dest_drop $pl_A]
    set pl_dropB [pcall calc::wave_dest_drop $pl_B]
    set t1 {}
    if {[catch {wviewer::enter_ctx $::tok} t1]} { set t1 {0 {}} }
    if {[lindex $t1 0]} {
        catch {wviewer::clear_all $::tok}
        catch {wviewer::leave_ctx $::tok $t1}
    }
    pcall bufset {}
    update idletasks
    check "PL10 hygiene: both destinations this band built are dropped and the canvas is empty again, so PL8 and PL9 below measure the session rather than this band's leftovers" \
        [list $pl_dropA $pl_dropB [llength [alltraces $::tok]] [pl_armleft $::tok]] \
        {1 1 0 {}}
}

# =============================================================================
# PL8 — R602 DECLINED, pinned as a row
# =============================================================================
# WARN THIS BAND PINS A DECLARED DEVIATION FROM THE SPEC, which is why it is a
# row and not a paragraph: R602 says "Plot with no viewer open opens one, then
# plots", and the Calculator refuses instead, because U7 / R503f (results batch
# item 10, ruled 2026-08-20 and LATER than R602) settled that this window never
# opens one.  A later stage that reverses the ruling reds this band and has to
# come back and correct `calc::plot_rpn`'s header.  Filed as a `rule` debt.
# =============================================================================
# WARN THE SENTENCE IS R503f'S CHOICE, NOT U7'S VERBATIM ONE, AND THE FIRST
# DRAFT OF THIS BAND GOT THAT WRONG.  It expected `calc::no_result_msg` -- "No
# simulation results are loaded..." -- and the product answered
# `calc::no_viewer_msg`, because emptying the viewer registry leaves the ASE-L
# SESSION open and `calc::no_result_advice` then takes issue 0516's arm: the
# session has a selection the Calculator cannot read, which is a different fact
# from having no results.  That is correct, and it is the better sentence; the
# row was wrong.  So the band drives BOTH worlds and asserts each against the
# RESOLVER rather than against one hard-coded string -- which is also the claim
# worth making, since R503f's whole point is that a new action must not grow a
# SECOND spelling of either sentence.
#
# WARN THE MENU SEPARATOR IS WRITTEN `\u25b8` RATHER THAN TYPED, which is the rule
# `calc::no_result_msg` states for itself: the exactness of a ruled sentence
# must not depend on this file's encoding surviving an editor.  An earlier
# revision of this row carried the character and it reached the file as one.
group PL8 {
    set saved {}
    catch {set saved $::wviewer::windows}
    set savedsess {}
    catch {set savedsess $::ase::sessions}
    set hadcur [expr {[info commands ::wviewer::current_token] ne {}}]
    if {$hadcur} { pcall rename ::wviewer::current_token ::pl8_real_curtok }
    proc ::wviewer::current_token {} { return {} }
    pcall bufset $::GAIN
    # world A: the session is still open, so its selection exists somewhere the
    # Calculator cannot read -- issue 0516's arm.
    set ::wviewer::windows [dict create]
    set saidA [press .calc.mode.plot]
    set adviceA [pcall calc::no_result_advice]
    set nA [llength [pcall dict keys $::wviewer::windows]]
    # world B: no session either -- U7's own world, and its ruled sentence.
    set ::ase::sessions [dict create]
    set saidB [press .calc.mode.plot]
    set nB [llength [pcall dict keys $::wviewer::windows]]
    catch {rename ::wviewer::current_token {}}
    if {$hadcur} { catch {rename ::pl8_real_curtok ::wviewer::current_token} }
    catch {set ::ase::sessions $savedsess}
    catch {set ::wviewer::windows $saved}
    check "PL8 with no viewer there is no result either, so Plot refuses in the RULED sentence this world earns (R503f) rather than opening a window" \
        [list [expr {$saidA ne {}}] $saidA [string match {*not implemented*} $saidA]] \
        [list 1 $adviceA 0]
    check "PL8 ...and it really is issue 0516's arm, naming the OBSTACLE and the two-step door, not U7's 'no results' fact" \
        [list [string match {*has no waveform viewer*} $saidA] \
              [string match {*open the session's waveforms*} $saidA] \
              [expr {$saidA eq [pcall calc::no_result_msg]}]] {1 1 0}
    check "PL8 ...and with no session either it is U7's RULED sentence, verbatim, with no second spelling built on the Plot path" \
        $saidB "No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L \u25b8 Results \u25b8 Select."
    check "PL8 ...and no viewer window was created by either refusal (R503f: a refusal that opens a window is a second gesture the user did not ask for)" \
        [list $nA $nB] {0 0}
    # ...and the structural half, so the declaration cannot go false silently:
    # neither Plot proc names a viewer-opening verb.
    set opens {}
    foreach pr {plot_click plot_in_token plot_rpn plot_dest_req} {
        set b [pcall info body ::calc::$pr]
        if {[string match ERR:* $b]} { lappend opens "$pr:NO-BODY" ; continue }
        foreach ln [split $b \n] {
            if {[regexp {^[ \t]*#} $ln]} continue
            if {[regexp {wviewer::(open|new_tab|load_new_window)} $ln]} { lappend opens $pr }
        }
    }
    check "PL8 ...and no Plot proc's CODE names a viewer-opening verb (comments dropped, so the paragraph explaining the decision does not satisfy the row)" \
        [lsort -unique $opens] {}
    check "PL8 ...and the scan is not vacuous: those four bodies were readable and one of them does name wviewer::plot_signals" \
        [regexp {wviewer::plot_signals} [pcall info body ::calc::plot_rpn]] 1
    # back to a working world for PL9's snapshot
    check "PL8 the viewer registry is restored" [expr {[ngraphs $::tok] >= 1}] 1
}

# =============================================================================
# PL9 — R508, BOTH AXES.  Runs last: it closes the window.
# =============================================================================
group PL9 {
    set ::pl_lift_status [pl_lift_procs \
        [file join $::here test_calc_engine.tcl] {ce_decomment ce_code}]
    check "PL9 the decommenter was LIFTED out of test_calc_engine.tcl rather than copied a third time" \
        $::pl_lift_status ok
    # ...and it is the real thing: whole-line and tail comments go, code stays.
    # A `#` opens a comment only in command position, so a hash inside a string
    # must survive.
    check "PL9 ...and the lifted decommenter drops whole-line and tail comments while keeping code and a hash inside a string" \
        [list [regexp {\.calc} [pcall ce_code "# a .calc mention\nset x 1\n"]] \
              [regexp {\.calc} [pcall ce_code "set x 1 ;# a .calc mention\n"]] \
              [regexp {\.calc} [pcall ce_code "set x .calc.buf\n"]] \
              [regexp {\.calc} [pcall ce_code "set x \"a # .calc\"\n"]]] {0 0 1 1}
    check_expr "PL9 the namespace enumeration is not vacuous" {[llength [info vars ::calc::*]] >= 17}
    pcall calc::close
    update idletasks
    check "PL9 the window is gone" [expr {[winfo exists .calc] ? 1 : 0}] 0
    set before [ns_state]
    set raised {}
    foreach step {{calc::plot_click} {calc::dest_changed} {calc::plot_dest_req}} {
        if {[catch {eval $step} e]} { lappend raised "[lindex $step 0]:$e" }
    }
    set after [ns_state]
    check "PL9 R508 none of Plot's three window-reading entry points raises with no window" $raised {}
    check "PL9 R508 ...and none of them WRITES a calc:: namespace variable -- 'records nothing' is about state, not only about raising" \
        [ns_diff $before $after] {}
    check "PL9 R508 ...and none of them built a window to refuse" \
        [expr {[winfo exists .calc] ? 1 : 0}] 0
    check "PL9 R508 ...and calc::plot_dest_req answers {} rather than guessing a destination" \
        [pcall calc::plot_dest_req] {}
    # ...and the structural half: every Plot proc whose CODE names a .calc
    # widget path also names calc::has_win.  Derived from the namespace, not
    # listed here (CLAUDE.md limit L9).
    #
    # WARN THE BODIES ARE DECOMMENTED FIRST, with the helper lifted above.  A
    # scan over a raw `info body` would move a proc into the "unguarded" half
    # the moment a COMMENT inside it named a widget path, which is a false red
    # on an edit that changed no behaviour.
    set pl {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        set t [namespace tail $p]
        if {[string match plot_* $t] || [string match dest_* $t]} { lappend pl $t }
    }
    check_expr "PL9 the Plot proc set was derived from the namespace, not listed" {[llength $pl] >= 6}
    set unguarded {} ; set pure {}
    foreach p $pl {
        set b [pcall info body ::calc::$p]
        if {[string match ERR:* $b]} { lappend unguarded "$p:NO-BODY" ; continue }
        set b [pcall ce_code $b]
        if {[string match ERR:* $b]} { lappend unguarded "$p:NO-DECOMMENT" ; continue }
        if {![regexp {\.calc} $b]} { lappend pure $p ; continue }
        if {![regexp {calc::has_win} $b]} { lappend unguarded $p }
    }
    check "PL9 every Plot proc whose CODE names a .calc widget path also names calc::has_win" $unguarded {}
    # WARN THE NAME DESCRIBES THE METHOD, NOT A COUNT.  An earlier revision was
    # named "...exactly the THREE that take their inputs as arguments" while the
    # expected list beside it held FOUR -- the row's own next line contradicted
    # its name, which is CLAUDE.md's rule about a row name claiming more than
    # the assertion measures.  The exact list is what makes the row non-vacuous
    # (if the `.calc` regexp ever matched nothing, every proc would land here);
    # the count is the list's and not the name's.
    check "PL9 ...and the ones whose CODE names no widget path are exactly the procs that take their inputs as arguments" \
        [lsort $pure] {plot_dest_dropped plot_in_token plot_msg plot_refusal plot_rpn}
}

# teardown: the viewer and the session go away, the dev display is left as found
catch {wviewer::close $::tok}
catch {ase::session_close $::tok}
update idletasks

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

## WARN THE `OVERALL: ok` SENTINEL IS WHAT T1 CAN SCORE.  `banner_complete` in
## tests/banner_rule.tcl -- the ONLY Tcl reader of the rule, and the one
## tests/run_regression.tcl sources -- is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`
## and accepts NO `RESULT: ALL PASS` spelling, while run_suites.sh and
## full_audit.sh carry their own EREs which DO accept it.  Passing standalone is
## therefore no evidence a suite can be registered: that is how both sibling
## calculator suites gated nothing for a month (issue 1626).
##
## WARN `RESULT:` IS LAST, because summarize_all publishes a case's last
## `^RESULT:` line into the verdict; a SECOND `RESULT:` line would silently
## rewrite the published check count (issue 1627, open).  The no-X gate above is
## the file's OTHER exit path and prints its verdict INSTEAD of this one, never
## as well -- and prints NO banner, which is what makes a `dcases`-only entry
## correct and an `hcases` one a HARNESS failure (row RB6 of
## tests/headless/test_registered_banner_1626.tcl).
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
