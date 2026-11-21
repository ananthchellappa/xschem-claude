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
# ⚠ A CANVAS CLICK IS SENT AS A HAND MAKES IT: A `<Motion>` FIRST.  The pick's
# press hands its own position to the engine before it resolves the click, so
# the pick itself does not need the motion (band PG24 presses with none, after
# the engine's pointer pair has been overwritten).  The EDITOR's own clicks,
# which the restore rows make to see that the canvas selects again, are read by
# the engine from the pair as well, and a hand always moves onto the object
# before pressing; `pg_click` generates that motion and reads the pair back.
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
# R208f (band PG19): a resistor and a voltage source named as the committed
# result with terminal vectors names them (tests/headless/data/probe_1724_tran.raw
# holds `i(r9:n1)` and `i(v1)`), and a second resistor whose upper pin is the
# point of R9's lower one.  They are written LAST, so the instance indexes the
# bands above read (`M1` is asked for by index in band PG4) do not move.
puts $f {C {res.sym} -200 0 0 0 {name=R9 value=1k m=1}}
puts $f {C {vsource.sym} -200 300 0 0 {name=V1 value=1}}
puts $f {C {res.sym} -200 60 0 0 {name=R8 value=1k m=1}}
close $f

# A SECOND SHEET, FOR THE ROW THAT DESCENDS (band PG27): a block `xpg` with a
# schematic of its own, which holds a resistor.  It is a sheet of its own
# and not one more instance on the sheet above, so that nothing the other
# bands measure on that sheet -- its full-zoom box, what a rubber band covers,
# what the pointer is over at a bare point -- moves for it.  The block's symbol
# is named by its full path; its schematic is the file of the same name beside
# it, which is where a descend looks.
set pg27_blocksym [file join $scratch pgblk.sym]
set f [open $pg27_blocksym w]
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
set f [open [file join $scratch pgblk.sch] w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
puts $f {N 0 -30 0 -120 {}}
puts $f {N 0 30 0 110 {}}
puts $f {C {ipin.sym} 0 -120 0 0 {name=q1 lab=T}}
puts $f {C {opin.sym} 0 110 0 0 {name=q2 lab=U}}
puts $f {C {res.sym} 0 0 0 0 {name=R5 value=1k m=1}}
close $f
set pg27_design [file join $scratch pickdescend.sch]
set f [open $pg27_design w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
puts $f {N 0 -40 0 -120 {}}
puts $f {N 0 40 0 120 {}}
puts $f {C {lab_pin.sym} 0 -120 0 0 {name=l1 sig_type=std_logic lab=lp}}
puts $f {C {lab_pin.sym} 0 120 0 0 {name=l2 sig_type=std_logic lab=sq}}
puts $f "C {$pg27_blocksym} 0 0 0 0 {name=xpg}"
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
# the five seized slots of a canvas, as a snapshot -- and the EMPTY-vs-ABSENT
# distinction is kept, because `bind w seq {}` DESTROYS a binding and a restore
# that wrote an empty script back would pass a string compare and fail the
# sequence-list one (the RDW's row V6).
#
# ⚠ THE PRESS IS LISTED UNDER ANOTHER SPELLING.  `bind w` lists what was bound
# as `<ButtonPress-1>` as `<Button-1>`, so a presence test that looked for the
# spelling it was bound with answered 0 for that slot whatever it held, and the
# EMPTY-vs-ABSENT leg was blind on the one slot that matters most.  Both
# spellings are looked for; band PG23 reads a press slot that IS bound.
proc pg_binds {cv} {
    set out {}
    set listed [pcall bind $cv]
    foreach seq {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion> <Double-Button-1>} {
        set s [pcall bind $cv $seq]
        set present [expr {[lsearch -exact $listed $seq] >= 0 ? 1 : 0}]
        if {$seq eq {<ButtonPress-1>} && [lsearch -exact $listed <Button-1>] >= 0} { set present 1 }
        lappend out [list $seq $present $s]
    }
    return $out
}
# ...and what an UNSEIZED design canvas holds in them, as `pg_binds` reads it:
# nothing in the press, the release, Escape and the held motion, and the
# editor's own double-click script in the fifth (`set_bindings` in
# src/xschem.tcl binds it on every design canvas).  Written out, so that every
# restore row compares against a fixed text; the first fixture row of band PG1
# reads the real canvas against it before anything is armed.
proc pg_free {} {
    return [list [list <ButtonPress-1> 0 {}] [list <ButtonRelease-1> 0 {}] \
                 [list <Key-Escape> 0 {}] [list <B1-Motion> 0 {}] \
                 [list <Double-Button-1> 1 {xschem callback %W -3 %x %y 0 %b 0 %s}]]
}
# THE PRESS SCRIPTS OF THE TWO MODES THIS FILE SEIZES WITH, written out so
# every slot row compares against a fixed text: the pick's, which the double
# click's slot holds as well, and the results window's pick mode's.  Each hands
# the press's own position to the engine as a pointer motion and then runs the
# click (band PG24 is why).
set ::PG_PRESS    {xschem callback %W 6 %x %y 0 0 0 %s; calc::pick_click; break}
set ::PG_RDWPRESS {xschem callback %W 6 %x %y 0 0 0 %s; rdw::pick_click; break}
# ...and the five slots as `pg_binds` reads them while the results window's
# pick mode holds the canvas: its second press of a double click is swallowed.
proc pg_rdwslots {} {
    return [list [list <ButtonPress-1> 1 $::PG_RDWPRESS] [list <ButtonRelease-1> 1 break] \
                 [list <Key-Escape> 1 {rdw::pick_end; break}] [list <B1-Motion> 1 break] \
                 [list <Double-Button-1> 1 break]]
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
# RDW HELPERS GOT.  Issue 1659: the editor binds `<Configure>` on the design
# canvas and hands the event's %x %y -- the canvas's position inside its window
# -- to `callback()`, which writes `xctx->mousex/mousey` UNCONDITIONALLY, above
# its `switch(event)`.  Any `update` that processes a pending Configure of the
# canvas therefore overwrites the pair this helper just set, and a click the
# ENGINE resolves from that pair lands on a point nobody clicked.  Measured in
# the sibling suite as 136.2803 -> 1260.7161 across one `update`.  (The pick's
# own press no longer reads a pair it did not write: band PG24.)
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
#
# ⚠ EVERY CLICK IS STAMPED FAR FROM THE ONE BEFORE IT IN EVENT TIME.  Tk tells a
# double click by the two presses' times and pixels, so two clicks of this
# helper on one pixel must stay two clicks whatever time the generated events
# would otherwise carry.  The one helper that MEANS a double click is
# `pg_dblclick`, below.
set ::PG_CLOBBER 0
set ::PG_CLOBBER_AT {}
set ::PG_T 700000
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
    incr ::PG_T 5000
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] -time $::PG_T
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 80}]
    update
}
# ONE DOUBLE CLICK AT A SCHEMATIC POINT: a motion, then press, release, press,
# release on one pixel well inside Tk's double-click time.
#
# ⚠ IT IS BOUNDED, because the editor's own answer to a double click in the
# stock profile is a property dialog that WAITS: a second press that reaches the
# editor would block the generating script for good.  A timer that runs inside
# that wait takes down whatever window came up and `::PG_POPPED` names it, so a
# press that got through is a named red and not a stalled suite.
set ::PG_POPPED {}
proc pg_tops {} {
    set out {}
    foreach w [winfo children .] {
        if {[winfo toplevel $w] eq $w && [winfo ismapped $w]} { lappend out $w }
    }
    return [lsort $out]
}
proc pg_dismiss {before} {
    foreach w [pg_tops] {
        if {[lsearch -exact $before $w] >= 0} continue
        lappend ::PG_POPPED "$w '[wm title $w]'"
        catch {destroy $w}
    }
}
proc pg_dblclick {cv x y} {
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
    incr ::PG_T 5000
    set ::PG_POPPED {}
    set before [pg_tops]
    set deadman [after 1500 [list pg_dismiss $before]]
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] -time $::PG_T
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 70}]
    update
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 180}]
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 250}]
    update
    after cancel $deadman
    pg_dismiss $before
    update
}
# what the EDITOR saw of a gesture: the event type of every `xschem callback`
# a canvas binding made while the trace was on, kept to presses (4), releases
# (5) and the double click (-3).  Read off the interpreter's own record of the
# calls, never off a binding's text.
set ::PG_CB {}
proc pg_cbtrace {cmd op} {
    if {[lindex $cmd 1] ne {callback}} return
    set ev [lindex $cmd 3]
    if {$ev eq {4} || $ev eq {5} || $ev eq {-3}} { lappend ::PG_CB $ev }
}
# a real Escape on the canvas, with the keyboard put there first as a hand's
# click on the window would have put it
proc pg_esc {cv} {
    for {set i 0} {$i < 40} {incr i} {
        focus -force $cv ; update
        if {[focus -displayof $cv] eq $cv || [focus -displayof $cv] eq [winfo toplevel $cv]} break
        after 25
    }
    event generate $cv <Key-Escape>
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
    check "PG1 fixture: before anything is armed the design canvas is the editor's own, and what `pg_free` writes out is what it really holds: NOTHING in the press, the release, Escape and the held-motion slots, and the editor's own double-click script in the fifth -- so every restore row below compares against a canvas that was measured, and the fifth slot's predecessor is seen to be a real script and not an empty one" \
        [pg_binds .drw] [pg_free]
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
    check "PG2 all FIVE gesture slots are taken -- the fourth, `<B1-Motion>`, is issue 1304: without it a motion with Button1Mask starts C's rubber band and the seized release eats the only thing that ends it, so a one-pixel drift of the hand leaves objects selected, which is the exact inverse of `a pick does not change the selection`.  The fifth is the double click, which takes the press's own script: the editor binds that sequence on every design canvas, so left alone the second press of a double click goes past the pick to the editor (band PG21 presses it)" \
        [list [pcall bind $cv <ButtonPress-1>] [pcall bind $cv <ButtonRelease-1>] \
              [pcall bind $cv <Key-Escape>] [pcall bind $cv <B1-Motion>] \
              [pcall bind $cv <Double-Button-1>]] \
        [list $::PG_PRESS {break} {calc::pick_end cancel; break} {break} \
              $::PG_PRESS]
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
    # itself and hands the five slots back byte-identically.  The fence is the
    # gesture the user makes next: a second click on the canvas, which must reach
    # xschem as an ordinary click -- it SELECTS the wire and inserts nothing.
    check "PG3 R208b: a pick that RESOLVED a net is ONE-SHOT -- the mode ends by itself on the click, `::calc::selmode` is cleared so the selector grid shows nothing armed, and no ESC is needed" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode] \
              [expr {[info exists ::calc::pick] ? 1 : 0}]] \
        [list 0 {} {} 0]
    check "PG3 R208b ...and all five gesture slots are handed back BYTE-IDENTICALLY, the EMPTY-vs-ABSENT distinction included and the editor's own double-click script back in its slot, so the canvas is xschem's own again" \
        [pg_binds $cv3] \
        [pg_free]
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
        [pcall bind $cv <ButtonPress-1>] $::PG_PRESS
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
    check "PG4 R208b: after two refusals the mode is still the SAME pick, and the first click that resolves a net inserts it and ends the mode with the five slots handed back" \
        [list [pg_buf] [pcall calc::pick_running] [set ::calc::selmode] [pg_binds $cv]] \
        [list {vt(lp)} 0 {} [pg_free]]
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
    set prev [pg_free]
    event generate $cv <Key-Escape>
    update
    check "PG6 R306: a real Escape leaves the buffer untouched, clears `::calc::selmode`, ends the mode and says so" \
        [list [pg_buf] [set ::calc::selmode] [pcall calc::pick_running] \
              [pcall calc::pick_id] [lindex [pcall calc::status_history] 0]] \
        [list untouched {} 0 {} {selector vt: pick cancelled}]
    check "PG6 ...and all five slots are handed back BYTE-IDENTICALLY, including the EMPTY-vs-ABSENT distinction: `.drw` is a Frame whose shipped bindings are the generic <Button>/<Key>, so the predecessors of the first four are ABSENT -- and `bind w seq {}` DESTROYS a binding, so a restore that wrote an empty script back would pass a string compare and fail this sequence-list one -- while the fifth, the double click, gets the editor's own script back" \
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
    # R610 PARITY: a SCALAR that divides by zero or logs a value <= 0 is refused
    # with Outputs' own sentence, a WAVE is not, and a constant answer does not
    # claim "(at the last point)".  Literal sentences, so the window and Outputs
    # cannot drift together.
    set dz {Cannot evaluate: division by zero}
    set lz {Cannot evaluate: log of zero or a negative value}
    set got [list [pg17_eval {1/0}] [pg17_eval {db(0)}] [pg17_eval {value(vt(lp), 1m)/0}] \
                  [pg17_eval {vt(lp)/0}]]
    check "PG17 R610 parity in real Eval presses: 1/0, db(0) and a measured number over zero are REFUSED with Outputs' sentences, while vt(lp)/0 -- a wave -- still answers" \
        $got [list $dz $lz $dz {= 0  (at the last point)}]
    set one [pg17_eval {value(vt(lp), 1m)*1}]
    set two [pg17_eval {value(vt(lp), 1m)*2}]
    set v1 NOVAL ; regexp {^= (\S+)$} $one -> v1
    set v2 NOVAL ; regexp {^= (\S+)$} $two -> v2
    check "PG17 a CONSTANT answer carries no `(at the last point)`: value(vt(lp), 1m)*2 says just its number, which is exactly twice value(vt(lp), 1m)*1, and 2*3 says `= 6`" \
        [list [pg17_eval {2*3}] \
              [pg_word [expr {[string is double -strict $v1] && [string is double -strict $v2] && $v1 != 0
                              && abs($v2 - 2.0 * $v1) <= abs($v1) * 1e-6}] twice "$one / $two"]] \
        {{= 6} twice}
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
    # ⚠ THE EXPECTED SENTENCES ARE LITERALS.  This row used to compare the
    # translator's refusal against `calc::ix_plot_say` applied to the same
    # message -- the very proc under test -- so a Plot press that stopped
    # translating stayed green here (only ET17, on the counted arm, saw it).
    check "PG17 Plot refuses in its OWN verb: an unknown signal named as typed, the translator's sentence as Plot's, and a measurement operand as a number that is not a waveform" \
        [list [pg_word [expr {[string match {Cannot plot:*vt(nosuch)*} [lindex $pls 0]] && [string first {'v(nosuch)} [lindex $pls 0]] < 0}] named [lindex $pls 0]] \
              [lindex $pls 1] [lindex $pls 2]] \
        [list named {Cannot plot: '*' has no value after it.} \
              {Cannot plot: cross() answers a number, not a waveform.}]
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG18 — R208e: THE CURRENT SELECTORS PICK A VOLTAGE SOURCE OR AN AMMETER
# =============================================================================
# `it`/`if`/`idc`/`is` arm exactly as the voltage selectors do -- the press, the
# raise, the five seized slots, the prompt on the design window, ESC, one-shot
# on success, a miss leaves the mode armed -- and a click anywhere on a source's
# BODY inserts `it(<inst>)`, by the rule ASE-L Select-On-Design uses
# (`ase::ui::sod_source_at`).  A click on a device PIN is band PG19's (R208f);
# anything that is neither is refused saying what can be picked.  The committed
# fixture holds no source branch current, so this band reads a small ASCII raw
# of its own into the VIEWER's context and puts the committed one back at its
# foot, which a row checks.
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
    check "PG18 a real press on `it` arms a pick exactly as `vt` does -- the design is raised, the canvas seized, the press and the held-motion slots taken as `vt` takes them -- and the sentence and the design window's prompt say what THIS pick wants: a device pin, a voltage source or an ammeter" \
        [list [lindex [pcall calc::status_history] 0] [pcall calc::pick_running] [pcall calc::pick_id] \
              [set ::calc::selmode] \
              [pg_word [expr {$cv ne {} && [winfo exists $cv]}] live DEAD] \
              [pcall bind $cv <ButtonPress-1>] [pcall bind $cv <B1-Motion>] \
              [pcall [pcall ase::ui::sod_statusbar $cv] cget -text]] \
        [list {selector it: click a device pin, voltage source or ammeter; ESC cancels} 1 it it live \
              $::PG_PRESS break \
              {Calculator it: click a device pin, voltage source or ammeter; ESC cancels}]
    # --- the misses: each refuses, leaves the buffer alone, keeps the mode ------
    pcall xschem zoom_full
    update
    .calc.buf delete 1.0 end
    .calc.buf insert end {keepme}
    .calc.buf mark set insert end-1c
    # the BODY point of M1 is its own origin: on the device and on no pin, which
    # the fixture row reads back.  (The point this row clicked before R208f stood
    # within the pin rule's reach of the bulk pin, so it is now that terminal.)
    check "PG18 fixture: the empty point the miss row clicks really is empty canvas, read back from `object_at`; the device point is M1's body and is on NO pin by the pin rule the click asks; and the point this row clicked before R208f is, by that same rule, M1's bulk pin" \
        [list [pcall xschem object_at 150 250] \
              [lindex [pcall xschem object_at 300 0] 0] \
              [pcall xschem getprop instance [lindex [pcall xschem object_at 300 0] 1] name] \
              [pcall ase::ui::sod_terminal_at $::tok 300 0] \
              [dg [pcall ase::ui::sod_terminal_at $::tok 310 0] instname] \
              [dg [pcall ase::ui::sod_terminal_at $::tok 310 0] pinname]] \
        {{} instance M1 {} M1 b}
    set res {}
    foreach pt {{300 0} {50 0} {150 250}} {
        pg_click $cv {*}$pt
        lappend res [lindex [pcall calc::status_history] 0] [pg_buf] [pcall calc::pick_running]
    }
    check "PG18 a current selector REFUSES the body of a device that is not a source, and a wire, saying what does have a current to pick -- and empty canvas with its own sentence; after each the buffer is byte-identical and the mode still live, as a voltage miss leaves it" \
        $res [list \
            {selector it: no current there; click a device pin, voltage source or ammeter} keepme 1 \
            {selector it: no current there; click a device pin, voltage source or ammeter} keepme 1 \
            {selector it: nothing there; click a device pin, voltage source or ammeter} keepme 1]
    # --- the hit --------------------------------------------------------------
    pg_click $cv {*}[pg18_mid Vsq]
    check "PG18 a click on the voltage source's BODY inserts `it(vsq)` -- the raw's own spelling with the selector's id where its `i` was -- at the cursor after the typing, and the status line names the analysis and the Cadence path of the instance" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0]] \
        [list {keepme it(vsq)} {selector it: it(vsq) (transient) from /Vsq}]
    check "PG18 ...and the pick is ONE-SHOT (R208b): the mode ended, the grid shows nothing armed, the five slots are handed back byte-identically, and nothing was selected" \
        [list [pcall calc::pick_running] [set ::calc::selmode] [pg_binds $cv] \
              [pcall xschem selection]] \
        [list 0 {} [pg_free] {}]
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
              [pg_free]]
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
# PG19 — R208f: A CURRENT SELECTOR'S CLICK ON A DEVICE PIN (issue 1724)
# =============================================================================
# The DECISION is band PK13 of tests/headless/test_calc_selector_names.tcl, on
# the counted arm.  Here is the ACT: a real press on the selector, a real motion
# and press on the seized canvas at a pin's own point, and what reaches the
# buffer and the two status lines.
#
# The Calculator writes no deck, so a terminal resolves only when the result
# already holds its vector.  This band reads the committed results that do
# (tests/headless/data/probe_1724_tran.raw, then probe_1724_op.raw) into the
# VIEWER's context and puts the committed calc fixture back at its foot, which a
# row checks.  The sheet's `R9` and `V1` are named as that result names them;
# `M1`, `R8` and `Vsq` are in the sheet and not in it.
#
# Not driven here: a bus pin, a pin the naming rule refuses, and the naming
# rule's caution.  This sheet has none of them; band PK13 has all three.
proc pg19_pin {nm pin} {
    return [lrange [pcall xschem instance_pin_coord [pg18_inst $nm] name $pin] 1 2]
}
group PG19 {
    pcall calc::pick_end cancel
    pcall calc::stk_set {}
    set info0 [pg15_viewer {xschem raw info}]
    set ::pg19tran [file join $::repo tests headless data probe_1724_tran.raw]
    set ::pg19op   [file join $::repo tests headless data probe_1724_op.raw]
    set rd [pg15_viewer {xschem raw read $::pg19tran tran}]
    set ref [pg15_viewer {
        list [lindex [xschem raw values i(r9.n1) 0] end] \
             [lindex [xschem raw values i(v1) 0] end] \
             [lindex [xschem raw values v(out) 0] end]
    }]
    lassign $ref r9ref v1ref outref
    check "PG19 fixture: the committed transient result with terminal vectors is what the Calculator now resolves against, and the resistor's terminal reads a number clearly apart from the two columns beside it -- so an Eval that read another column cannot pass" \
        [list [file isfile $::pg19tran] $rd [dg [pcall calc::require_result] path] \
              [dg [pcall calc::require_result] type] \
              [pg_word [expr {[string is double -strict $r9ref] && $r9ref != 0
                              && abs($r9ref - $v1ref) > 1e-3 * abs($r9ref)
                              && abs($r9ref - $outref) > 1e-3 * abs($r9ref)}] apart "ref=$ref"]] \
        [list 1 1 [file normalize $::pg19tran] tran apart]
    pg_press .calc.sel.it
    set cv {}
    catch {set cv $::calc::pick(canvas)}
    pcall xschem zoom_full
    update
    set slot [pcall ase::ui::sod_statusbar $cv]
    set pR [pg19_pin R9 P] ; set pV [pg19_pin V1 p]
    set pM [pg19_pin M1 d] ; set pS [pg19_pin Vsq p]
    check "PG19 fixture: the pick is armed and each point clicked below IS a device pin by the rule the click asks -- read back from ASE-L's own pin rule at the pin's own coordinate, so a row cannot be about a miss" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] \
              [dg [pcall ase::ui::sod_terminal_at $::tok {*}$pR] instname] \
              [dg [pcall ase::ui::sod_terminal_at $::tok {*}$pV] instname] \
              [dg [pcall ase::ui::sod_terminal_at $::tok {*}$pM] instname] \
              [dg [pcall ase::ui::sod_terminal_at $::tok {*}$pS] instname]] \
        {1 it R9 V1 M1 Vsq}
    # --- the misses first: each says its sentence and leaves the mode armed -----
    .calc.buf delete 1.0 end
    .calc.buf insert end {keepme}
    .calc.buf mark set insert end-1c
    set res {}
    pg_click $cv {*}$pM
    lappend res [lindex [pcall calc::status_history] 0] [pcall $slot cget -text] [pg_buf] [pcall calc::pick_running]
    pg_click $cv {*}$pS
    lappend res [lindex [pcall calc::status_history] 0] [pg_buf] [pcall calc::pick_running]
    check "PG19 a pin whose terminal the result does NOT hold inserts nothing, says so naming the vector and where to ask for it -- on the Calculator's line and on the design window's own slot, where the sentence is followed by the pin the pointer is still on -- and leaves the mode armed; the pin of a voltage source with NEITHER its terminal nor its branch current in the result is refused as the source is" \
        $res [list \
            {selector it: i(M1:d) is not in this result; ASE-L Outputs: To Be Plotted, rerun} \
            {selector it: i(M1:d) is not in this result; ASE-L Outputs: To Be Plotted, rerun — pin M1:d} keepme 1 \
            {selector it: i(Vsq) is not in this result; nothing inserted} keepme 1]
    # --- two devices on one point: the click says which one it took ---------------
    # R9's lower pin and R8's upper pin are one point.  The click is three units up
    # R9's own lead, so the pin rule takes R9 whichever way the pixel rounds.
    set pR2 [pg19_pin R9 M]
    pg_click $cv [lindex $pR2 0] [expr {[lindex $pR2 1] - 3}]
    check "PG19 where two devices have a pin on ONE point a real click takes the device whose lead it is on, and says which other pin shares the point BEFORE its last sentence -- so the history holds both and the last word is still what came of the click" \
        [list [expr {$pR2 eq [pg19_pin R8 P] ? {onepoint} : {APART}}] \
              [lindex [pcall calc::status_history] 0] [lindex [pcall calc::status_history] 1] \
              [pg_buf] [pcall calc::pick_running]] \
        [list onepoint \
              {selector it: i(R9:n2) is not in this result; ASE-L Outputs: To Be Plotted, rerun} \
              {selector it: that point is also R8 pin P; the click took R9 pin M} keepme 1]
    # --- the hit --------------------------------------------------------------------
    # ⚠ THE CLICK IS NEAR THE PIN AND OFF THE GRID, so the un-snapped cursor and
    # the snapped one differ, and the pin rule is RECORDED for this one click: the
    # row reads back the key and the point the click really handed it.  The point
    # is compared with the one ASKED FOR, within a unit, as `pg_click` itself
    # compares -- never with a second read of the mouse pair, which issue 1659's
    # clobber can move after the click.
    rename ase::ui::sod_terminal_at pg19_real_tat
    set ::pg19_at {}
    proc ase::ui::sod_terminal_at {key x y} {
        lappend ::pg19_at [list $key $x $y]
        return [pg19_real_tat $key $x $y]
    }
    set want19 [list [expr {[lindex $pR 0] + 3}] [expr {[lindex $pR 1] + 2}]]
    pg_click $cv {*}$want19
    rename ase::ui::sod_terminal_at {}
    rename pg19_real_tat ase::ui::sod_terminal_at
    set at19 [lindex $::pg19_at 0]
    set near19 0 ; set offpin19 0
    if {[llength $at19] == 3 && [string is double -strict [lindex $at19 1]]
        && [string is double -strict [lindex $at19 2]]} {
        set near19 [expr {abs([lindex $at19 1] - [lindex $want19 0]) <= 1
                          && abs([lindex $at19 2] - [lindex $want19 1]) <= 1}]
        set offpin19 [expr {abs([lindex $at19 1] - [lindex $pR 0]) > 1
                            || abs([lindex $at19 2] - [lindex $pR 1]) > 1}]
    }
    check "PG19 a REAL click on the resistor's pin, through the seized canvas binding, inserts `it(r9.n1)` at the cursor after the typing -- the raw's own stored spelling of the terminal vector, with the selector's id -- and the status line names the analysis and the instance's path with the pin as the symbol spells it" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0]] \
        [list {keepme it(r9.n1)} {selector it: it(r9.n1) (transient) from /R9:P}]
    check "PG19 ...and that click asked ASE-L's pin rule with the SESSION the pick was armed for and the UN-SNAPPED cursor -- twice, once for the click itself and once for the words the prompt ends with, and both times the same question: the point it was handed is the one clicked, to a unit, and that point is NOT the pin's own grid point, which is where the snapped cursor stands -- so the leg can tell the two apart; the recorder was handed back" \
        [list [pg_sized [llength $::pg19_at] 2] \
              [pg_word [expr {[llength [lsort -unique $::pg19_at]] == 1}] samequestion "asked=$::pg19_at"] \
              [expr {[lindex $at19 0] eq $::tok ? {session} : "key=[lindex $at19 0]"}] \
              [pg_word $near19 raw "at=$at19 want=$want19"] \
              [pg_word $offpin19 offpin "at=$at19 pin=$pR"] \
              [expr {[info procs ::pg19_real_tat] eq {} ? {restored} : {LEAKED}}]] \
        {n2 samequestion session raw offpin restored}
    check "PG19 ...and the pick is ONE-SHOT as every resolved pick is (R208b): the mode ended, the grid shows nothing armed, the five slots are handed back byte-identically, and nothing was selected" \
        [list [pcall calc::pick_running] [set ::calc::selmode] [pg_binds $cv] \
              [pcall xschem selection]] \
        [list 0 {} [pg_free] {}]
    .calc.buf delete 1.0 end
    .calc.buf insert end {it(r9.n1)}
    pg_press .calc.mode.eval
    check "PG19 Eval of the inserted token answers the resistor's terminal current -- the raw reader's own last sample of that column, taken by the test in the viewer's context" \
        [lindex [pcall calc::status_history] 0] "= [format %.8g $r9ref]  (at the last point)"
    # --- K2b: a source's pin whose terminal the result does not hold ---------------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    pg_click $cv {*}$pV
    check "PG19 the PIN of a voltage source whose terminal this result does not hold inserts the source's own current, which it does hold, and says it as a source pick -- the Calculator cannot add a probe, so the click is the one it was before pins were picked" \
        [list [pg_buf] [lindex [pcall calc::status_history] 0] [pcall calc::pick_running]] \
        [list {it(v1)} {selector it: it(v1) (transient) from /V1} 0]
    # what that click said, newest first, back to its own arming sentence: on the
    # source's FIRST terminal the stand-in is the pin's own current
    set h19p [lrange [pcall calc::status_history] 0 1]
    # --- the source's LOWER pin: the same stand-in, with its sign said -------------
    # The source's current is the current into its first terminal, so here the
    # token inserted is the negative of the current into the pin that was clicked.
    set pVm [pg19_pin V1 m]
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    pg_click $cv {*}$pVm
    set h19m [lrange [pcall calc::status_history] 0 2]
    check "PG19 a REAL click on the voltage source's LOWER pin inserts the source's own current as the upper pin does, and says BEFORE its last sentence that the token is the source's current and the negative of the clicked pin's -- so the history holds the note between the arming sentence and the last word, and the pick is one-shot all the same; the click on the UPPER pin, which is the source's first terminal, said nothing between the two.  The point clicked is the lower pin by the rule the click asks" \
        [list [dg [pcall ase::ui::sod_terminal_at $::tok {*}$pVm] instname] \
              [dg [pcall ase::ui::sod_terminal_at $::tok {*}$pVm] pinname] \
              [pg_buf] $h19m [pcall calc::pick_running] $h19p] \
        [list V1 m {it(v1)} \
              [list {selector it: it(v1) (transient) from /V1} \
                    {selector it: V1 pin m: inserted the source's current, the negative of this pin's} \
                    {selector it: click a device pin, voltage source or ammeter; ESC cancels}] \
              0 \
              [list {selector it: it(v1) (transient) from /V1} \
                    {selector it: click a device pin, voltage source or ammeter; ESC cancels}]]
    # --- the same pick under `idc`, against the operating-point result -------------
    pg15_viewer {xschem raw clear $::pg19tran tran}
    set rdo [pg15_viewer {xschem raw read $::pg19op op}]
    set r9op [pg15_viewer {lindex [xschem raw values i(r9.n1) 0] end}]
    .calc.buf delete 1.0 end
    pg_press .calc.sel.idc
    set idcsaid [lindex [pcall calc::status_history] 0]
    pg_click $cv {*}$pR
    check "PG19 `idc` arms against the committed operating-point result and the same pin inserts `idc(r9.n1)`, read back from THAT analysis" \
        [list $rdo [dg [pcall calc::require_result] type] $idcsaid [pg_buf] \
              [lindex [pcall calc::status_history] 0] [pcall calc::pick_running]] \
        [list 1 op {selector idc: click a device pin, voltage source or ammeter; ESC cancels} \
              {idc(r9.n1)} {selector idc: idc(r9.n1) (operating point) from /R9:P} 0]
    pg_press .calc.mode.eval
    check "PG19 ...and Eval of it answers the operating-point value of that terminal, a non-zero number" \
        [list [lindex [pcall calc::status_history] 0] \
              [pg_word [expr {[string is double -strict $r9op] && $r9op != 0}] nonzero "r9op=$r9op"]] \
        [list "= [format %.8g $r9op]" nonzero]
    pcall calc::pick_end cancel
    set ::calc::selmode {}
    pcall calc::stk_set {}
    pcall xschem unselect_all
    # --- put the committed raw back ----------------------------------------------
    pg15_viewer {xschem raw clear $::pg19op op}
    pg15_viewer {xschem raw read $::fixture tran}
    check "PG19 the band put the viewer's registry back exactly as it found it, so every band below reads the committed calc fixture" \
        [list [expr {[pg15_viewer {xschem raw info}] eq $info0 ? {same} : [pg15_viewer {xschem raw info}]}] \
              [dg [pcall calc::require_result] path]] \
        [list same [file normalize $::fixture]]
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG20 — ONE CLICK MODE ON THE CANVAS AT A TIME
# =============================================================================
# This pick and ASE-L's Select On Design seize the same canvas slots, and each
# keeps ONE set of predecessors.  Stacked, the one that ends first hands the
# other's scripts back to the canvas, and the schematic then takes no left
# click at all (open issue 0202 has the mechanism).  So each ends the other
# before it seizes: `ase::ui::select_on_design` ends a live pick, and
# `calc::pick_arm` ends a live Select On Design through `calc::pick_end_sod`.
#
# The drives are the user's: a real press on the selector, real motions,
# presses and Escapes on the canvas.  Select On Design is entered by the call
# its menu entries make.  Every sequence ends on the same three questions: do
# the five slots hold what an unseized canvas holds, is any pin marker left,
# and does an ORDINARY click select.
proc pg20_sodup {} { return [expr {[info exists ::ase::ui::sod(active)] ? 1 : 0}] }
proc pg20_sod {} {
    set r [pcall ase::ui::select_on_design $::tok {save 1 plot 0}]
    update
    return $r
}
# the predecessors Select On Design has on record that are scripts of THIS
# pick, and how many predecessors it has on record at all
proc pg20_sodlatched {} {
    set ours {}
    set n 0
    foreach {k v} [array get ::ase::ui::sod "$::tok,prev*"] {
        incr n
        if {[string match *calc::pick_* $v]} { lappend ours $k }
    }
    return [list [pg_word [expr {$n >= 3}] recorded "n=$n"] $ours]
}
proc pg20_calcprev {} {
    set out {}
    foreach k {prevpress prevrel prevesc prevmotion prevdbl} {
        set v NOKEY ; catch {set v $::calc::pick($k)} ; lappend out $v
    }
    return $out
}
# an ORDINARY click on R9's body: what the editor selected, as kind and index
proc pg20_sel {cv} {
    pcall xschem unselect_all
    pg_click $cv {*}[pg18_mid R9]
    set s [pcall xschem selection]
    pcall xschem unselect_all
    return [lrange [lindex $s 0] 0 1]
}
# the markers on the sheet, as the instances they are on
proc pg20_marked {} {
    set out {}
    foreach m [pcall xschem pin_marker list] { lappend out [lindex $m 1] }
    return $out
}
proc pg20_note {what args} { lappend ::pg20_order $what }
# WHOSE press script a canvas holds: `sod` for Select On Design's click of this
# file's session, `calc` for this pick's, otherwise the script itself.  Select
# On Design's is known by its tail -- the click for this session, then `break`
# -- so the row does not pin what that mode runs in front of its click.
proc pg20_press {cv} {
    set s [pcall bind $cv <ButtonPress-1>]
    if {[string match "*[list ase::ui::sod_click $::tok]; break" $s]} { return sod }
    if {$s eq $::PG_PRESS} { return calc }
    return $s
}
group PG20 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    pcall xschem zoom_full
    update
    set cv [pcall calc::pick_canvas]
    set r9 [list instance [pg18_inst R9]]
    set absent {selector it: i(M1:d) is not in this result; ASE-L Outputs: To Be Plotted, rerun}
    check "PG20 fixture: before anything is armed the canvas is the editor's own -- the five slots as an unseized design canvas holds them, no pin marker, neither mode up -- and an ORDINARY click on R9's body selects R9, so `a click selects` in the rows below is a measurement and not a constant" \
        [list [pg_word [expr {$cv ne {} && [winfo exists $cv]}] live "cv=$cv"] [pg_binds $cv] \
              [pg20_marked] [pcall calc::pick_running] [pg20_sodup] [pg20_sel $cv]] \
        [list live [pg_free] {} 0 0 $r9]
    # --- A: the Calculator's pick is up, and Select On Design is entered --------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    pg_click $cv {*}[pg19_pin M1 d]
    set a0 [list [pcall calc::pick_running] [lindex [pcall calc::status_history] 0] \
                 [pg_word [expr {[info exists ::calc::pick(canvas)] && $::calc::pick(canvas) eq $cv}] samecanvas OTHER]]
    set sodr [pg20_sod]
    check "PG20 A: with `it` armed and a real click on a pin the result does not hold -- the miss that leaves the pick armed and sends the user to ASE-L -- entering Select On Design ENDS the pick first: nothing is armed, the selector grid shows nothing, the press slot is Select On Design's, and not one predecessor it has on record is a script of this pick" \
        [list $a0 $sodr [pcall calc::pick_running] [set ::calc::selmode] [pg20_sodup] \
              [pg20_press $cv] [pg20_sodlatched]] \
        [list [list 1 $absent samecanvas] 1 0 {} 1 sod {recorded {}}]
    pg_click $cv {*}[pg19_pin R9 P]
    set amark [pg20_marked]
    pg_esc $cv
    check "PG20 A ...and after a real click on a pin, which Select On Design marks, and a real Escape, the canvas is the editor's again: the five slots as an unseized canvas holds them, no marker, neither mode up, and an ordinary click on R9's body selects it" \
        [list $amark [pg_binds $cv] [pg20_marked] [pg20_sodup] [pcall calc::pick_running] [pg20_sel $cv]] \
        [list R9 [pg_free] {} 0 0 $r9]
    # --- B: Select On Design is up, and a selector is pressed ---------------------
    set sodr [pg20_sod]
    pg_click $cv {*}[pg19_pin R8 M]
    set b0 [list $sodr [pg20_sodup] [pg20_marked] [pg20_press $cv]]
    # a selector that REFUSES to arm has not decided to take the canvas, so it
    # must leave the mode that holds it alone: `vs` refuses here, because this
    # result's run wrote no DC sweep
    pg_press .calc.sel.vs
    check "PG20 B fixture: Select On Design is up with R8's pin marked, and a selector that REFUSES to arm -- `vs`, this run wrote no DC sweep -- leaves it exactly so: still active, its marker still on the sheet, the press slot still its own, and nothing armed here.  Only an arm that is going ahead ends the other mode" \
        [list $b0 [lindex [pcall calc::status_history] 0] [pcall calc::pick_running] \
              [pg20_sodup] [pg20_marked] [pg20_press $cv]] \
        [list [list 1 1 R8 sod] {selector vs: this result has no DC sweep analysis} 0 \
              1 R8 sod]
    set ::pg20_order {}
    trace add execution ::calc::pick_end_sod enter {pg20_note sod}
    trace add execution ::ase::ui::design_window enter {pg20_note window}
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    trace remove execution ::calc::pick_end_sod enter {pg20_note sod}
    trace remove execution ::ase::ui::design_window enter {pg20_note window}
    check "PG20 B, the reverse: with Select On Design up and a pin marked, a real press on `it` ENDS that mode first -- it is no longer active and its marker is gone -- and then arms: the press slot is this pick's, and the predecessors it has on record are the editor's own (nothing in the first four, the editor's script for the double click), not Select On Design's.  The mode is ended BEFORE the design window is raised, read off the recorded calls: ending it raises ASE-L's own window, and the pick needs the design window on top" \
        [list [pg20_sodup] [pg20_marked] [pcall calc::pick_running] [pcall calc::pick_id] \
              [pcall bind $cv <ButtonPress-1>] [pg20_calcprev] $::pg20_order] \
        [list 0 {} 1 it $::PG_PRESS \
              [list {} {} {} {} {xschem callback %W -3 %x %y 0 %b 0 %s}] {sod window}]
    pg_esc $cv
    check "PG20 B ...and after a real Escape the canvas is the editor's again: five slots, no marker, neither mode, and an ordinary click selects" \
        [list [pg_binds $cv] [pg20_marked] [pg20_sodup] [pcall calc::pick_running] [pg20_sel $cv]] \
        [list [pg_free] {} 0 0 $r9]
    # --- J: the pick, a miss, Select On Design and a pin, then the selector again --
    # Before the two ended each other, pressing the selector here un-armed a pick
    # that had Select On Design's scripts on top of its own, and the next Select
    # On Design and Escape left the Calculator's dead press script on the canvas.
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    pg_click $cv {*}[pg19_pin M1 d]
    pg20_sod
    pg_click $cv {*}[pg19_pin Vsq p]
    set jmark [pg20_marked]
    pg_press .calc.sel.it
    set j1 [list [pcall calc::pick_running] [pg20_sodup] [pg20_marked]]
    pg_click $cv {*}[pg19_pin M1 s]
    pg_esc $cv
    pg20_sod
    pg_esc $cv
    check "PG20 J, the sequence the miss sentence invites: `it`, a miss, Select On Design, a pin picked there, then `it` pressed again -- which now ARMS, because entering Select On Design had ended the pick, and ends Select On Design with its marker -- a miss, Escape, Select On Design once more and Escape.  At the end the five slots are an unseized canvas's, no marker is left, neither mode is up, nothing is armed in the grid, and an ordinary click selects" \
        [list $jmark $j1 [pg_binds $cv] [pg20_marked] [pg20_sodup] [pcall calc::pick_running] \
              [set ::calc::selmode] [pg20_sel $cv]] \
        [list Vsq {1 0 {}} [pg_free] {} 0 0 {} $r9]
    # --- W: Select On Design first ---------------------------------------------
    # Before, this order ended on Select On Design's dead press script, and
    # nothing in the session took it off the canvas again.
    pg20_sod
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    pg_click $cv {*}[pg19_pin M1 d]
    pg20_sod
    pg_click $cv {*}[pg19_pin V1 p]
    set wmark [pg20_marked]
    pg_esc $cv
    set w1 [list [pg_binds $cv] [pg20_sodup] [pcall calc::pick_running]]
    pg_press .calc.sel.it
    pg_press .calc.sel.it
    check "PG20 W, the other order: Select On Design, then `it` and a miss, Select On Design again from its menu, a pin picked, Escape -- which already leaves the canvas free -- then `it` pressed and pressed again.  At the end the five slots are an unseized canvas's, no marker is left, neither mode is up, nothing is armed in the grid, and an ordinary click selects" \
        [list $wmark $w1 [pg_binds $cv] [pg20_marked] [pg20_sodup] [pcall calc::pick_running] \
              [set ::calc::selmode] [pg20_sel $cv]] \
        [list V1 [list [pg_free] 0 0] [pg_free] {} 0 0 {} $r9]
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG21 — THE SECOND PRESS OF A DOUBLE CLICK IS THE PICK'S TOO
# =============================================================================
# Tk gives the second press of a double click to the most specific binding that
# matches, and the editor binds the double click on every design canvas.  With
# only the press seized that second press went past an armed pick to the
# editor: its property dialog in the stock profile, which waits, and its
# connected-select in the Cadence one, which selects.  The seize takes the slot
# with the press's own script.
#
# ⚠ THAT THE GESTURE IS A DOUBLE CLICK IS MEASURED, not assumed: a binding tag
# of the band's own, put in FRONT of the canvas's, counts the double clicks Tk
# itself recognised.  Without that leg two presses Tk took for two single clicks
# would pass every other leg.
#
# Not here: the second press after a pick that RESOLVED.  That pick is one-shot
# and ended on the first release, so the canvas is the editor's again by then.
group PG21 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    pcall xschem zoom_full
    update
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    set cv $::calc::pick(canvas)
    set tags0 [bindtags $cv]
    set ::pg21_dbl 0
    bind PgDblProbe <Double-Button-1> {incr ::pg21_dbl}
    bindtags $cv [linsert $tags0 0 PgDblProbe]
    trace add execution xschem enter pg_cbtrace
    set res {}
    foreach {id pt} [list vt {300 0} it [pg19_pin M1 d]] {
        if {[pcall calc::pick_id] ne $id} { pg_press .calc.sel.$id }
        set ::PG_CB {}
        set ::pg21_dbl 0
        pg_dblclick $cv {*}$pt
        lappend res [list $::pg21_dbl $::PG_CB $::PG_POPPED [pcall xschem selection] \
                         [pcall xschem get lastsel] [pcall calc::pick_running] [pcall calc::pick_id] \
                         [lrange [pcall calc::status_history] 0 2] [pg_buf]]
    }
    trace remove execution xschem enter pg_cbtrace
    bindtags $cv $tags0
    bind PgDblProbe <Double-Button-1> {}
    set absent {selector it: i(M1:d) is not in this result; ASE-L Outputs: To Be Plotted, rerun}
    check "PG21 a real DOUBLE click that misses, under `vt` on a device body and under `it` on a pin the result does not hold: Tk recognised one double click each time, and BOTH presses were the pick's -- the miss is said twice over the arming sentence -- while the editor saw no press, no release and no double click, no window came up, nothing was selected, the buffer is untouched and the pick is still armed" \
        $res [list \
            [list 1 {} {} {} 0 1 vt [list {selector vt: M1 is not a net} {selector vt: M1 is not a net} \
                                          {selector vt: click a net on the schematic; ESC cancels}] {}] \
            [list 1 {} {} {} 0 1 it [list $absent $absent \
                                          {selector it: click a device pin, voltage source or ammeter; ESC cancels}] {}]]
    check "PG21 fixture: the band took its own binding tag off the canvas again" \
        [expr {[bindtags $cv] eq $tags0 ? {restored} : [bindtags $cv]}] restored
    pg_esc $cv
    check "PG21 ...and a real Escape hands all five slots back, the editor's own double-click script in its slot byte for byte, so the editor's double click is the editor's again; an ordinary click selects" \
        [list [pg_binds $cv] [pcall calc::pick_running] [pg20_sel $cv]] \
        [list [pg_free] 0 [list instance [pg18_inst R9]]]
    # --- a seize that finds its own scripts and no record ----------------------
    # The record is dropped while the canvas stays seized, and a new arm then
    # finds its own script in every slot.  It must not take those as the
    # predecessors, and it has none on record: the first four slots fall back to
    # nothing and the double click to the editor's script, which the canvas
    # still holds for the middle button.
    pg_press .calc.sel.vt
    set seized [pcall bind $cv <Double-Button-1>]
    array unset ::calc::pick
    set ::calc::selmode {}
    pcall calc::pick_arm vt
    set rearmed [list [pcall calc::pick_running] [pg20_calcprev]]
    pg_esc $cv
    check "PG21 a seize that finds its OWN scripts in the slots and has no predecessor on record (the record was lost while the canvas stayed seized) does not take them as the predecessors: the first four fall back to nothing and the double click to the editor's own script, so Escape still leaves an unseized canvas -- with nothing handed back for the fifth slot the editor's double click would be gone from this window for the rest of the session" \
        [list $seized $rearmed [pg_binds $cv] [pcall calc::pick_running]] \
        [list $::PG_PRESS \
              [list 1 [list {} {} {} {} {xschem callback %W -3 %x %y 0 %b 0 %s}]] [pg_free] 0]
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG22 — THE PROMPT NAMES THE PIN A CLICK WOULD TAKE
# =============================================================================
# With a CURRENT selector armed the design window's prompt ends with the pin
# the pointer is on, by the rule the click itself asks (`calc::pick_hover`).
# The editor's hover outline cannot say it: on a pin with a wire on it the
# outline is the wire.  The slot is read after the pump has had its turn, as
# band PG10 reads it.
proc pg22_slot {cv x y want} {
    pg_mouse $cv $x $y
    set slot [ase::ui::sod_statusbar $cv]
    for {set i 0} {$i < 150} {incr i} {
        update ; after 10
        if {[pcall $slot cget -text] eq $want} break
    }
    return [pcall $slot cget -text]
}
proc pg22_wait {ms} { set ::pg22_w 0 ; after $ms {set ::pg22_w 1} ; vwait ::pg22_w ; update }
proc pg22_tick {args} { incr ::pg22_ticks }
group PG22 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    pcall xschem zoom_full
    update
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    set cv $::calc::pick(canvas)
    set base {Calculator it: click a device pin, voltage source or ammeter; ESC cancels}
    set pR [pg19_pin R9 P] ; set pVm [pg19_pin V1 m] ; set pVp [pg19_pin V1 p]
    set got {}
    lappend got [pg22_slot $cv {*}$pR "$base — pin R9:P"]
    lappend got [pg22_slot $cv 150 250 $base]
    lappend got [pg22_slot $cv {*}$pVm "$base — pin V1:m"]
    lappend got [pg22_slot $cv 50 0 $base]
    check "PG22 with `it` armed the design window's prompt names the pin the pointer is on -- R9's upper pin, then V1's lower one -- and is the plain prompt again over empty canvas and over a wire, so the words follow the pointer and do not stay behind" \
        $got [list "$base — pin R9:P" $base "$base — pin V1:m" $base]
    # --- a pointer that rests is asked about once ----------------------------------
    rename ase::ui::sod_terminal_at pg22_real_tat
    set ::pg22_n 0
    proc ase::ui::sod_terminal_at {key x y} { incr ::pg22_n ; return [pg22_real_tat $key $x $y] }
    set ::pg22_ticks 0
    trace add execution ::calc::pick_pump enter pg22_tick
    set shown [pg22_slot $cv {*}$pVp "$base — pin V1:p"]
    pg22_wait 500
    trace remove execution ::calc::pick_pump enter pg22_tick
    set asked $::pg22_n
    check "PG22 the pin rule is asked when the pointer has MOVED and not on every tick: over half a second with the pointer resting on V1's upper pin the pump ran several times and the rule was asked once or twice, the prompt naming the pin throughout -- the rule walks the sheet's wires near a pin, which is too much to repeat every tick for a pointer that has not moved" \
        [list $shown [pg_word [expr {$::pg22_ticks >= 4}] ticked "ticks=$::pg22_ticks"] \
              [pg_word [expr {$asked >= 1 && $asked <= 2}] kept "asked=$asked ticks=$::pg22_ticks"] \
              [pcall [ase::ui::sod_statusbar $cv] cget -text]] \
        [list "$base — pin V1:p" ticked kept "$base — pin V1:p"]
    # --- a pin rule that raises costs the words, never the prompt ----------------
    proc ase::ui::sod_terminal_at {key x y} { incr ::pg22_n ; error {the pin rule is down} }
    set ::pg22_n 0
    set down [pg22_slot $cv {*}$pR $base]
    pg22_wait 250
    set after [list [pcall [ase::ui::sod_statusbar $cv] cget -text] [pcall calc::pick_running] \
                    [expr {[info exists ::calc::pick(pump)] ? 1 : 0}] \
                    [pg_word [expr {$::pg22_n >= 1}] asked "asked=$::pg22_n"]]
    rename ase::ui::sod_terminal_at {}
    rename pg22_real_tat ase::ui::sod_terminal_at
    check "PG22 a pin rule that RAISES costs the words and nothing else: with the pointer on R9's pin the prompt is the plain one, the pick is still armed and the pump still running -- it re-arms itself, so an error escaping it would take the prompt away for the rest of the pick; the recorder was handed back" \
        [list $down $after [expr {[info procs ::pg22_real_tat] eq {} ? {restored} : {LEAKED}}]] \
        [list $base [list $base 1 1 asked] restored]
    # --- only on the sheet the pick is on -------------------------------------------
    # The click itself refuses a sheet that is not the armed design's
    # (`calc::pick_base`), and the canvas the pick holds is the only one whose
    # pointer it reads.  The words follow both: asked directly, with the record
    # pointing at another design and then at another widget, there are none.
    pg22_slot $cv {*}$pVp "$base — pin V1:p"
    set keepd $::calc::pick(design) ; set keepc $::calc::pick(canvas)
    set sheet {}
    unset -nocomplain ::calc::pick(hoverat)
    lappend sheet [pcall calc::pick_hover]
    set ::calc::pick(design) [file join $::scratch not_this_design.sch]
    unset -nocomplain ::calc::pick(hoverat)
    lappend sheet [pcall calc::pick_hover]
    set ::calc::pick(design) $keepd
    set ::calc::pick(canvas) .calc
    unset -nocomplain ::calc::pick(hoverat)
    lappend sheet [pcall calc::pick_hover]
    set ::calc::pick(canvas) $keepc
    unset -nocomplain ::calc::pick(hoverat)
    lappend sheet [pcall calc::pick_hover]
    check "PG22 the words are asked only of the sheet the pick is on: with the pointer on V1's upper pin they name it; with the pick's record pointing at ANOTHER design, or at a canvas that is not the window's current one, there are none -- the same two tests the click makes before it resolves anything -- and with the record put back they name the pin again" \
        $sheet [list { — pin V1:p} {} {} { — pin V1:p}]
    # --- and the click takes the pin the prompt named ------------------------------
    pg22_slot $cv {*}$pVp "$base — pin V1:p"
    set named [pg22_slot $cv {*}$pR "$base — pin R9:P"]
    pg_click $cv {*}$pR
    set r9abs {selector it: i(R9:n1) is not in this result; ASE-L Outputs: To Be Plotted, rerun}
    check "PG22 ...and the click then takes the pin the prompt named: with the prompt saying R9's upper pin a real press there is answered about that pin's current, and the design window's slot holds that answer followed by the pin the pointer is still on" \
        [list $named [lindex [pcall calc::status_history] 0] \
              [pcall [ase::ui::sod_statusbar $cv] cget -text] [pcall calc::pick_running]] \
        [list "$base — pin R9:P" $r9abs "$r9abs — pin R9:P" 1]
    # --- a voltage selector's prompt names no pin ----------------------------------
    pg_press .calc.sel.vt
    rename ase::ui::sod_terminal_at pg22_real_tat
    set ::pg22_n 0
    proc ase::ui::sod_terminal_at {key x y} { incr ::pg22_n ; return [pg22_real_tat $key $x $y] }
    set vbase {Calculator vt: click a net to insert its name; ESC cancels}
    set vgot [pg22_slot $cv {*}$pVm $vbase]
    pg22_wait 250
    set vgot2 [pcall [ase::ui::sod_statusbar $cv] cget -text]
    rename ase::ui::sod_terminal_at {}
    rename pg22_real_tat ase::ui::sod_terminal_at
    check "PG22 a VOLTAGE selector's prompt names no pin and does not ask the pin rule at all: with `vt` armed and the pointer resting on V1's lower pin the prompt is the plain one, and the rule was not called" \
        [list $vgot $vgot2 $::pg22_n [pcall calc::pick_id] \
              [expr {[info procs ::pg22_real_tat] eq {} ? {restored} : {LEAKED}}]] \
        [list $vbase $vbase 0 vt restored]
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG23 — ON TOP OF THE RESULTS WINDOW'S PICK MODE, ENDED IN ORDER
# =============================================================================
# The results window's click mode (`rdw::pick_start`; keys 1 to 3 of the
# Cadence profile) is NOT ended by an arm: it nests, by its own rulings, with
# Escape as its only exit.  This pick's predecessors are then that mode's
# scripts, and ending the pick must hand exactly those back -- the double
# click's among them, which there is that mode's own script and not the
# editor's.  Ended in order the two unwind to a free canvas.  Ended the other
# way round, the mode that is left takes the canvas again: band PG27.
group PG23 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    set cv [pcall calc::pick_canvas]
    set armed [pcall rdw::pick_start]
    update
    set rdwslots [pg_binds $cv]
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    set on [list [pcall calc::pick_running] [pcall rdw::pick_running] \
                 [pcall bind $cv <ButtonPress-1>] [pcall bind $cv <Double-Button-1>] \
                 [pg20_calcprev]]
    # what a window made NOW would copy for each of the five slots: both modes
    # tell `cmdmode` what they hold, and the copy steps down through the two
    set under {} ; set free {}
    foreach b [pg_free] {
        lappend under [pcall cmdmode::pristine $cv [pcall bind_seq_spelling [lindex $b 0]] \
                           [pcall bind $cv [lindex $b 0]] bind_seq_spelling]
        lappend free [lindex $b 2]
    }
    pg_esc $cv
    set back [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg_binds $cv]]
    pg_esc $cv
    check "PG23 a pick armed ON TOP of the results window's pick mode records that mode's five scripts as its predecessors and hands exactly those back when it ends -- the double-click slot too, which under that mode is the mode's own swallowing script and not the editor's -- so the mode underneath is whole again; its own Escape then leaves the canvas as an unseized one holds it, and an ordinary click selects" \
        [list $armed $rdwslots $on $back [pcall rdw::pick_running] [pg_binds $cv] [pg20_sel $cv]] \
        [list 1 [pg_rdwslots] \
              [list 1 1 $::PG_PRESS $::PG_PRESS \
                    [list $::PG_RDWPRESS break {rdw::pick_end; break} break break]] \
              [list 0 1 [pg_rdwslots]] \
              0 [pg_free] [list instance [pg18_inst R9]]]
    check "PG23 ...and while the two were stacked, what a new window would have copied for each of the five slots is what an UNSEIZED canvas holds there -- nothing for the first four, the editor's script for the double click: `cmdmode::pristine` steps down through this pick's scripts and then through the results window's, because each of the two modes tells it what it holds" \
        $under $free
    pcall rdw::pick_end
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG24 — THE CLICK IS RESOLVED AT THE PIXEL THAT WAS PRESSED
# =============================================================================
# `calc::pick_click` reads the engine's un-snapped pointer pair, and the engine
# overwrites that pair on every event it is handed.  The editor binds
# `<Configure>` on every design canvas, and that event carries the canvas's
# position inside its window: each time the canvas is laid out again, that
# position goes into the pair (issue 1659).  So the press's script hands the
# press's own position to the engine before it runs the click.
#
# The drive is the one a hand cannot make on purpose and a layout pass makes
# for it: a real motion onto the target, the canvas's own `<Configure>` as a
# layout pass sends it, and then a real press WITH NO MOTION IN BETWEEN.
#
# ⚠ THAT THE PAIR REALLY WAS OVERWRITTEN IS A LEG OF EVERY ROW, read back
# immediately before the press, so no row here can pass on a pair that was
# never moved.
proc pg_pair {} {
    return [list [expr {round([xschem get mousex])}] [expr {round([xschem get mousey])}]]
}
# is that pair more than a schematic unit away from the point (x,y)?
proc pg_away {pair x y} {
    return [expr {abs([lindex $pair 0] - $x) > 1 || abs([lindex $pair 1] - $y) > 1 ? 1 : 0}]
}
# the canvas's own <Configure>, with the geometry the canvas really has;
# answers the pair it left
proc pg_clobber {cv} {
    event generate $cv <Configure> -x [winfo x $cv] -y [winfo y $cv] \
        -width [winfo width $cv] -height [winfo height $cv] -when now
    return [pg_pair]
}
# ONE press and release at a schematic point with NO motion first
proc pg_pressonly {cv x y} {
    set p [pg_px $x $y]
    incr ::PG_T 5000
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] -time $::PG_T
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 80}]
    update
}
# ONE double click at a schematic point with no motion and the pair overwritten
# before EACH press; answers the two pairs as they stood before the presses.
# Bounded as `pg_dblclick` is, and for the same reason.
proc pg_dblclick_clobbered {cv x y} {
    set p [pg_px $x $y]
    incr ::PG_T 5000
    set ::PG_POPPED {}
    set before [pg_tops]
    set deadman [after 1500 [list pg_dismiss $before]]
    set pairs [list [pg_clobber $cv]]
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] -time $::PG_T
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 70}]
    update
    lappend pairs [pg_clobber $cv]
    event generate $cv <ButtonPress-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 180}]
    event generate $cv <ButtonRelease-1> -x [lindex $p 0] -y [lindex $p 1] \
        -time [expr {$::PG_T + 250}]
    update
    after cancel $deadman
    pg_dismiss $before
    update
    return $pairs
}
group PG24 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    pcall xschem zoom_full
    update
    .calc.buf delete 1.0 end
    pg_press .calc.sel.it
    set cv $::calc::pick(canvas)
    set pR [pg19_pin R9 P] ; set pM [pg19_pin M1 d]
    set r9abs {selector it: i(R9:n1) is not in this result; ASE-L Outputs: To Be Plotted, rerun}
    set m1abs {selector it: i(M1:d) is not in this result; ASE-L Outputs: To Be Plotted, rerun}
    # --- the fixture: the overwrite is real, and it moves nothing but the pair ---
    set view0 [list [xschem get zoom] [xschem get xorigin] [xschem get yorigin]]
    set m0 [pg_mouse $cv {*}$pR]
    set c0 [pg_clobber $cv]
    check "PG24 fixture: the engine's pointer pair really is overwritten by the canvas's own layout event -- after a real motion onto R9's upper pin the pair is that pin's point, and after the canvas's `<Configure>`, sent with the geometry the canvas has, it is a point more than a unit away from the pin, with the zoom and the origin unmoved.  The editor binds that event on the canvas, so the script that did it is the editor's own" \
        [list [pg_word [expr {![pg_away $m0 {*}$pR]}] onpin "pair=$m0 pin=$pR"] \
              [pg_word [pg_away $c0 {*}$pR] moved "pair=$c0 pin=$pR"] \
              [pg_word [expr {[list [xschem get zoom] [xschem get xorigin] [xschem get yorigin]] eq $view0}] sameview MOVED] \
              [pg_word [string match {xschem callback *} [pcall bind $cv <Configure>]] editors [pcall bind $cv <Configure>]] \
              [pcall calc::pick_running]] \
        {onpin moved sameview editors 1}
    # --- a pin: motion, the overwrite, then a press with no motion ---------------
    pg_mouse $cv {*}$pR
    set c1 [pg_clobber $cv]
    pg_pressonly $cv {*}$pR
    set a1 [pg_pair]
    check "PG24 a real press on a device PIN with the pair overwritten since the last motion is answered about THAT PIN: the sentence names R9's terminal, which this result does not hold, and not `nothing there`, which is what the overwritten point holds -- and the engine's pair after the press is the pixel that was pressed, because the press handed it over" \
        [list [pg_word [pg_away $c1 {*}$pR] moved "pair=$c1"] \
              [lindex [pcall calc::status_history] 0] [pcall calc::pick_running] \
              [pg_word [expr {![pg_away $a1 {*}$pR]}] onpin "pair=$a1 pin=$pR"]] \
        [list moved $r9abs 1 onpin]
    # --- the second press of a double click, the pair overwritten before each ----
    set tags0 [bindtags $cv]
    set ::pg21_dbl 0
    bind PgDblProbe <Double-Button-1> {incr ::pg21_dbl}
    bindtags $cv [linsert $tags0 0 PgDblProbe]
    trace add execution xschem enter pg_cbtrace
    set ::PG_CB {}
    pg_mouse $cv {*}$pM
    set c2 [pg_dblclick_clobbered $cv {*}$pM]
    trace remove execution xschem enter pg_cbtrace
    bindtags $cv $tags0
    bind PgDblProbe <Double-Button-1> {}
    check "PG24 BOTH presses of a real double click on a pin are answered about that pin although the pair was overwritten before each of them and no motion came in between: Tk recognised one double click, the sentence naming M1's drain terminal was said twice, the editor saw no press, no release and no double click, no window came up, and the pick is still armed -- the double click's slot holds the press's own script, so its second press hands its position over as the first does" \
        [list $::pg21_dbl \
              [pg_word [expr {[pg_away [lindex $c2 0] {*}$pM] && [pg_away [lindex $c2 1] {*}$pM]}] movedtwice "pairs=$c2"] \
              [lrange [pcall calc::status_history] 0 1] $::PG_CB $::PG_POPPED \
              [pcall calc::pick_running] [expr {[bindtags $cv] eq $tags0 ? {restored} : [bindtags $cv]}]] \
        [list 1 movedtwice [list $m1abs $m1abs] {} {} 1 restored]
    # --- a wire, under a voltage selector ----------------------------------------
    pg_press .calc.sel.vt
    .calc.buf delete 1.0 end
    set m3 [pg_mouse $cv 50 0]
    set c3 [pg_clobber $cv]
    pg_pressonly $cv 50 0
    check "PG24 ...and a real press on a WIRE under `vt`, the pair overwritten since the last motion: the click inserts the net the press was on and ends the one-shot mode with the five slots handed back -- resolved at the overwritten point it would have said there is nothing under the click and stayed armed" \
        [list $m3 [pg_word [pg_away $c3 50 0] moved "pair=$c3"] [pg_buf] \
              [lindex [pcall calc::status_history] 0] [pcall calc::pick_running] [pg_binds $cv]] \
        [list {50 0} moved {vt(lp)} {selector vt: vt(lp) (transient) from /lp} 0 [pg_free]]
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG25 — A WINDOW CREATED WHILE A PICK IS ARMED GETS NONE OF ITS SCRIPTS
# =============================================================================
# A new schematic window copies the bindings of the main canvas
# (`clone_canvas_bindings`).  A descend suspends the click modes before it
# makes one; `xschem new_schematic create_window` and a profile's new-window
# key do not, and the copy then carried the pick's own scripts onto a canvas
# the pick is not armed on: no click there selected again, and nothing ever
# took them off.  The pick now tells `cmdmode` what it holds
# (`calc::pick_held`), and the copy takes what the canvas holds underneath.
#
# The control is a window made the same way with NO mode up: the window made
# while the pick is armed must carry exactly its bindings.
#
# `pg_allbinds` reads every binding of a canvas as {sequence script}, with the
# canvas's own path and its window's written out of each script: the editor's
# scripts name both, and two windows made one after the other need not be
# given the same name.
proc pg_allbinds {cv} {
    set out {}
    set names [list $cv @CV@]
    catch {lappend names [winfo toplevel $cv] @TOP@}
    foreach q [lsort [pcall bind $cv]] {
        lappend out [list $q [string map $names [pcall bind $cv $q]]]
    }
    return $out
}
proc pg25_open {file} {
    pcall xschem new_schematic create_window {} $file
    update
    set w [pcall xschem get current_win_path]
    for {set i 0} {$i < 200} {incr i} {
        if {[winfo exists $w] && [winfo ismapped $w] && [winfo width $w] > 100} break
        update ; after 10
    }
    pcall xschem zoom_full
    update
    return $w
}
proc pg25_close {w first} {
    pcall xschem new_schematic switch $w
    pcall xschem unselect_all
    pcall xschem set modified 0
    pcall xschem new_schematic destroy $w {}
    pcall xschem new_schematic switch $first
    update
}
# an ordinary click in window `w` at a schematic point: the kind of object the
# editor selected, or nothing
proc pg25_sel {w x y} {
    pcall xschem new_schematic switch $w
    update
    pcall xschem unselect_all
    pg_click $w $x $y
    set k [lindex [lindex [pcall xschem selection] 0] 0]
    pcall xschem unselect_all
    return $k
}
group PG25 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    set cv [pcall calc::pick_canvas]
    set first [pcall xschem get current_win_path]
    set copy [file join $::scratch picknets_second.sch]
    file copy -force $::design $copy
    # --- the control: a second window with no mode up ----------------------------
    set w0 [pg25_open $copy]
    set ctl [pg_allbinds $w0]
    set ctlsel [pg25_sel $w0 50 0]
    set ctlown {}
    foreach b $ctl { if {[string match *pick_click* [lindex $b 1]]} { lappend ctlown [lindex $b 0] } }
    pg25_close $w0 $first
    check "PG25 fixture, the control: a second schematic window made with NO mode up is a live canvas of its own, it carries the editor's bindings -- its double click among them -- and none of a pick's, and an ordinary click on the wire there selects the wire; closed again, the first window is current" \
        [list [pg_word [expr {$w0 ne $cv && $w0 ne {}}] second "w=$w0"] \
              [pg_word [expr {[lsearch -exact $ctl [list <Double-Button-1> {xschem callback %W -3 %x %y 0 %b 0 %s}]] >= 0}] editors $ctl] \
              $ctlown $ctlsel [expr {[winfo exists $w0] ? {STILLTHERE} : {closed}}] \
              [expr {[pcall xschem get current_win_path] eq $first ? {first} : [pcall xschem get current_win_path]}]] \
        {second editors {} wire closed first}
    # --- the pick armed: what it says it holds ----------------------------------------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    set seized [pg_binds $cv]
    set held [pcall calc::pick_held]
    set agree {} ; set prist {}
    foreach {hc hq hs hp} $held {
        if {$hc ne $cv || [pcall bind $cv $hq] ne $hs} { lappend agree $hq }
        lappend prist [pcall cmdmode::pristine $cv [pcall bind_seq_spelling $hq] [pcall bind $cv $hq] bind_seq_spelling]
    }
    set free {}
    foreach b [pg_free] { lappend free [lindex $b 2] }
    check "PG25 with the pick armed, what it tells `cmdmode` it holds is what the canvas holds: one group for each of the five slots, each naming this canvas and the very script `bind` reads back from that slot -- and asked under Tk's own spelling of each sequence, as the window copy asks, `cmdmode::pristine` answers for every slot what an unseized canvas holds there: nothing for the first four and the editor's script for the double click" \
        [list [pcall calc::pick_running] [pg_sized [expr {[llength $held] / 4}] 5] \
              [pg_sized [llength $held] 20] $agree $prist] \
        [list 1 n5 n20 {} $free]
    # --- a window made now --------------------------------------------------------------
    set w1 [pg25_open $copy]
    set got [pg_allbinds $w1]
    set during [pg25_sel $w1 50 0]
    set still [list [pcall calc::pick_running] [pcall calc::pick_id] \
                   [expr {[pg_binds $cv] eq $seized ? {seized} : [pg_binds $cv]}] [pg_buf]]
    check "PG25 a window made with `xschem new_schematic create_window` WHILE THE PICK IS ARMED carries exactly the bindings the control window had -- none of the pick's scripts -- and an ordinary click on the wire there SELECTS the wire; the pick is still armed on its own canvas with its five slots as they were, and nothing reached the buffer" \
        [list [pg_word [expr {$w1 ne $cv && [winfo exists $w1]}] second "w=$w1"] \
              [expr {$got eq $ctl ? {ascontrol} : $got}] $during $still \
              [expr {$seized eq [pg_free] ? {NOTSEIZED} : {wasseized}}]] \
        [list second ascontrol wire [list 1 vt seized {}] wasseized]
    pcall xschem new_schematic switch $first
    update
    pg_esc $cv
    set ended [list [pcall calc::pick_running] [pg_binds $cv]]
    set aftersel [pg25_sel $w1 50 0]
    set gotafter [pg_allbinds $w1]
    pg25_close $w1 $first
    check "PG25 ...and after a real Escape on the pick's own canvas that canvas is the editor's again, the second window's bindings are still the control's, a click on the wire there still selects, and the first window still selects once the second is closed" \
        [list $ended [expr {$gotafter eq $ctl ? {ascontrol} : $gotafter}] $aftersel \
              [expr {[winfo exists $w1] ? {STILLTHERE} : {closed}}] [pg20_sel $cv]] \
        [list [list 0 [pg_free]] ascontrol wire closed [list instance [pg18_inst R9]]]
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG26 — THE RESULTS WINDOW'S OWN SCRIPTS, LEFT ON A CANVAS NO MODE HOLDS
# =============================================================================
# The results window's pick mode nests with this pick and with Select On
# Design (band PG23).  Whichever of two stacked modes is ended first, the other
# takes the canvas again (band PG27), so the doors of these three modes do not
# leave one mode's scripts on a canvas after that mode has gone.  A click mode
# that takes no part in that still can (open issue 0202), and so can a record
# that is lost.  What takes the results window's scripts off again is its own
# key and Escape: its seize does not keep its own scripts as the predecessors,
# so the Escape leaves an unseized canvas.
#
# The state is made by hand -- the five scripts written onto the canvas with
# no mode up -- and the row's first leg reads that the canvas really is in that
# state before the recovery is tried.
group PG26 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    set cv [pcall calc::pick_canvas]
    set r9 [list instance [pg18_inst R9]]
    foreach b [pg_rdwslots] { pcall bind $cv [lindex $b 0] [lindex $b 2] }
    set dead [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg20_sodup] [pg_binds $cv]]
    set again [pcall rdw::pick_start]
    update
    set rec {}
    foreach k {prevpress prevrel prevesc prevmotion prevdbl} {
        set v NOKEY ; catch {set v $::rdw::pick($k)} ; lappend rec $v
    }
    pg_esc $cv
    check "PG26 the results window's five scripts on a canvas no mode holds, written there by hand, with no mode up to end.  The results window's key takes the canvas WITHOUT keeping those scripts as its predecessors -- nothing for the first four and the editor's script for the double click -- so its Escape leaves the five slots as an unseized canvas holds them, and an ordinary click selects" \
        [list $dead $again $rec [pcall rdw::pick_running] [pg_binds $cv] [pg20_sel $cv]] \
        [list [list 0 0 0 [pg_rdwslots]] 1 \
              [list {} {} {} {} {xschem callback %W -3 %x %y 0 %b 0 %s}] 0 [pg_free] $r9]
    pcall rdw::pick_end
    # Put back by hand, AFTER the row has read it: with a seize that kept its
    # own scripts the state could not be left from inside the session, and the
    # bands below are to redden for their own reasons only.
    catch {array unset ::rdw::pick}
    foreach b [pg_free] { catch {bind $cv [lindex $b 0] [lindex $b 2]} }
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG27 — A THIRD MODE ENTERED OVER THE RESULTS WINDOW'S MODE UNWINDS IN ORDER
# =============================================================================
# This pick and Select On Design never hold the canvas together: starting one
# ends the other (band PG20).  The results window's pick mode nests with both
# (band PG23).  So when that mode was entered ON TOP of the one that is then
# ended -- a selector is pressed over a Select On Design, Select On Design is
# entered over a pick or over itself -- the mode underneath is released, and
# its release writes what IT held before, the editor's scripts, over the
# results window's live ones.  Left so, the results window's mode stays
# recorded as up with nothing bound: its sentence on the status bar, clicks
# selecting, and its key, which re-arms in place, taking nothing.  It takes the
# canvas again instead (`rdw::pick_reseat`), the mode being entered stacks on
# it, and one Escape for each of the two unwinds them to a free canvas.
#
# THE PICK'S OWN DOORS END IT UNDERNEATH THAT MODE TOO, with nothing started in
# its place: another selector pressed (which switches to it), the armed
# selector pressed again (which disarms it), and the Calculator window closed.
# Each of them comes through the pick's one end, which asks the results
# window's mode to take the canvas again as well.  The rows after the orders
# press those doors, one each.
#
# AND A DESCEND PAUSES THE WHOLE STACK AND PUTS IT BACK.  A descend made while
# both modes are up releases them and brings them up again on the canvas it
# lands on (`cmdmode`).  The release has to take the top of the stack first:
# each mode hands back what the canvas held when it took it, so released
# bottom first the canvas is left holding the lower mode's scripts while both
# are paused, the two come back the other way up, and the last Escape hands a
# mode's dead scripts to a canvas no mode holds.  The row before the control
# descends into a block in the same window with the pick under the results
# window's mode, and reads the stack where it landed.
#
# AND THE RESULTS WINDOW'S MODE CAN ITSELF BE ENDED FIRST, from underneath the
# mode on top of it: Escape pressed in the results window reaches that mode's
# end while the canvas's own Escape is the other mode's.  Its release writes
# the editor's scripts over the live ones of the mode on top, and that mode --
# this pick, or Select On Design -- takes the canvas again
# (`calc::pick_reseat`, `ase::ui::sod_reseat`): it holds its scripts with the
# editor's own on record, and ONE Escape on the canvas ends it and leaves the
# canvas as it was before any mode.  The rows before the control that end the
# results window's mode first do it by the command its Escape binding runs
# (`rdw::pick_end`); the row that presses that binding for real is E6 of
# test_rdw_keys_1245, which has the window.
#
# Every order goes through the product's own doors: Select On Design by the
# call its menu entries make, the results window's mode by its key's own proc
# with nothing selected, a selector by a real press, the Calculator window by
# the script its close button runs, the descend by its scripted command, which
# lands in the proc the descend key's dialog lands in (`hi_descend_do`), and
# real Escapes on the canvas.  Each row reads the stack after the last mode is
# in, and after each Escape.  The last row is the control, with the results
# window's mode at the bottom of the stack.
#
# the predecessors the results window's mode has on record, slot by slot, as
# it tells `cmdmode`: the fourth word of each group of `rdw::pick_held`
proc pg27_rdwprev {} {
    set out {}
    foreach {c q s p} [pcall rdw::pick_held] { lappend out $p }
    return $out
}
# the results window's key, as the profile's binding runs it, with nothing
# selected: it arms the click mode
proc pg27_key {} {
    pcall xschem unselect_all
    pcall rdw::key annotation
    update
}
# whose press script the canvas holds: `pg20_press`'s words, and `rdw` for the
# results window's
proc pg27_press {cv} {
    set w [pg20_press $cv]
    if {$w eq $::PG_RDWPRESS} { return rdw }
    return $w
}
# the stack as it stands: is the results window's mode up, is the pick, is
# Select On Design, whose press script the canvas holds, and what the results
# window's mode would hand back
proc pg27_stack {cv} {
    return [list [pcall rdw::pick_running] [pcall calc::pick_running] [pg20_sodup] \
                 [pg27_press $cv] [pg27_rdwprev]]
}
# Put the canvas back by hand: every mode ended, every record dropped, the five
# slots as an unseized canvas holds them.  Run AFTER a row has read what its
# order left, so that the next order starts from a free canvas whatever the
# one before it found, and each row reddens for its own reason only.
proc pg27_clean {cv} {
    pcall rdw::pick_end
    catch {array unset ::rdw::pick}
    pcall rdw::_hint_sync
    catch {ase::ui::sod_end $::tok}
    pcall calc::pick_end cancel
    foreach b [pg_free] { catch {bind $cv [lindex $b 0] [lindex $b 2]} }
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
    update
}
# the five slots as `pg_binds` reads them while this pick holds the canvas:
# the double click's slot holds the press's own script
proc pg27_calcslots {} {
    return [list [list <ButtonPress-1> 1 $::PG_PRESS] [list <ButtonRelease-1> 1 break] \
                 [list <Key-Escape> 1 {calc::pick_end cancel; break}] [list <B1-Motion> 1 break] \
                 [list <Double-Button-1> 1 $::PG_PRESS]]
}
# the Calculator window again after a row has closed it, with its selector
# grid on screen for the presses of the rows below: 1 when it is
proc pg27_reopen {} {
    pcall calc::open
    for {set i 0} {$i < 200} {incr i} {
        update
        if {[winfo exists .calc.sel.vt] && [winfo ismapped .calc.sel.vt]} { return 1 }
        after 10
    }
    return 0
}
# an ORDINARY click on the body of the device named `nm` on the sheet that is
# shown: what the editor selected, as kind and index
proc pg27_sel {cv nm} {
    pcall xschem unselect_all
    pg_click $cv {*}[pg18_mid $nm]
    set s [pcall xschem selection]
    pcall xschem unselect_all
    return [lrange [lindex $s 0] 0 1]
}
# the sheet `file` shown in the design window at the top level, full zoom, and
# named as this session's design: the stand-in resolver of band PG1 answers
# `::design`.  Answers the level and the file that is shown.
proc pg27_show {file} {
    pcall xschem set modified 0
    pcall xschem load $file
    set ::design $file
    update
    pcall xschem zoom_full
    update
    return [list [pcall xschem get currsch] [file tail [pcall xschem get schname]]]
}
# the predecessors Select On Design has on record for this file's session, in
# the order press, release, Escape, held motion, double click, and then the
# canvas's own handler for its destruction; NOKEY where it has none
proc pg27_sodprev {} {
    set out {}
    foreach k {prevpress prevrel prevesc prevmotion prevdbl prevdestroy} {
        set v NOKEY ; catch {set v $::ase::ui::sod($::tok,$k)} ; lappend out $v
    }
    return $out
}
# how many timers are waiting to run the proc `name`
proc pg27_timers {name} {
    set n 0
    foreach id [after info] {
        if {[lindex [lindex [pcall after info $id] 0] 0] eq $name} { incr n }
    }
    return $n
}
# where the keyboard is once it has come to rest: the window that has it when
# it is `cv`, or after a bounded wait whichever window has it
proc pg27_focus {cv} {
    for {set i 0} {$i < 40} {incr i} {
        update
        if {[focus] eq $cv} break
        after 25
    }
    return [focus]
}
group PG27 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    set cv [pcall calc::pick_canvas]
    set r9 [list instance [pg18_inst R9]]
    set editors [list {} {} {} {} {xschem callback %W -3 %x %y 0 %b 0 %s}]
    set rdwfive [list $::PG_RDWPRESS break {rdw::pick_end; break} break break]
    set calcfive [list $::PG_PRESS break {calc::pick_end cancel; break} break $::PG_PRESS]
    # every binding of the canvas before any mode of this band, and its own
    # handler for its destruction: what `as before any mode` is read against
    set base27 [pg_allbinds $cv]
    set destroy27 [pcall bind $cv <Destroy>]
    check "PG27 fixture: nothing is up and the canvas is the editor's own before the first order, the results window's mode among the modes `cmdmode` knows -- so `up` in the rows below is something each row did" \
        [list [pg_binds $cv] [pcall rdw::pick_running] [pcall calc::pick_running] [pg20_sodup] \
              [expr {[lsearch -exact [pcall cmdmode::registered] rdw_pick] >= 0 ? {known} : {UNKNOWN}}]] \
        [list [pg_free] 0 0 0 known]
    # --- Select On Design, the results window's key, a selector ---------------------
    pg20_sod
    pg27_key
    set mid1 [list [pg20_sodup] [pcall rdw::pick_running] [pg27_press $cv]]
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    set top1 [pg27_stack $cv]
    set under1 [pg20_calcprev]
    pg_esc $cv
    set esc1 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg_binds $cv]]
    pg_esc $cv
    check "PG27 Select On Design, the results window's key with nothing selected, then a real press on `vt`: the arm ends Select On Design UNDERNEATH the results window's mode, and that mode takes the canvas again -- it is still up, what it would hand back is the editor's own (nothing for the first four slots, the editor's script for the double click) and no longer Select On Design's scripts -- and the pick stacks on it: the press slot is the pick's and the pick's predecessors are the results window's five scripts.  A real Escape ends the pick and the canvas holds the results window's five scripts again; a second real Escape ends that mode and leaves the five slots as an unseized canvas holds them, no marker, nothing up, and an ordinary click selects" \
        [list $mid1 $top1 $under1 $esc1 [pcall rdw::pick_running] [pg20_sodup] [pg_binds $cv] \
              [pg20_marked] [pg20_sel $cv]] \
        [list {1 1 rdw} [list 1 1 0 calc $editors] $rdwfive [list 0 1 [pg_rdwslots]] 0 0 [pg_free] {} $r9]
    pg27_clean $cv
    # --- a selector, the results window's key, Select On Design ---------------------
    pg_press .calc.sel.vt
    pg27_key
    set mid2 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg27_press $cv]]
    pg20_sod
    set top2 [pg27_stack $cv]
    pg_esc $cv
    set esc2 [list [pg20_sodup] [pcall rdw::pick_running] [pg_binds $cv]]
    pg_esc $cv
    check "PG27 the mirror: a real press on `vt`, the results window's key, then Select On Design entered: entering it ends the pick UNDERNEATH the results window's mode, which takes the canvas again -- still up, what it would hand back the editor's own and no longer the pick's scripts -- and Select On Design stacks on it with the press slot its own.  A real Escape ends Select On Design and hands the canvas the results window's five scripts; a second ends that mode: five slots as an unseized canvas holds them, no marker, nothing up, nothing armed in the grid, and an ordinary click selects" \
        [list $mid2 $top2 $esc2 [pcall rdw::pick_running] [pcall calc::pick_running] [pg_binds $cv] \
              [pg20_marked] [set ::calc::selmode] [pg20_sel $cv]] \
        [list {1 1 rdw} [list 1 0 1 sod $editors] [list 0 1 [pg_rdwslots]] 0 0 [pg_free] {} {} $r9]
    pg27_clean $cv
    # --- Select On Design, the results window's key, Select On Design again ---------
    pg20_sod
    pg27_key
    set mid3 [list [pg20_sodup] [pcall rdw::pick_running] [pg27_press $cv]]
    pg20_sod
    set top3 [pg27_stack $cv]
    pg_esc $cv
    set esc3 [list [pg20_sodup] [pcall rdw::pick_running] [pg_binds $cv]]
    pg_esc $cv
    check "PG27 Select On Design, the results window's key, then Select On Design entered AGAIN, which ends the one that was up before it starts: the same unwinding -- the results window's mode is still up with the editor's own on record, Select On Design is on top of it, the first real Escape leaves the results window's five scripts on the canvas and the second leaves an unseized canvas, no marker, nothing up, and an ordinary click selects" \
        [list $mid3 $top3 $esc3 [pcall rdw::pick_running] [pg20_sodup] [pg_binds $cv] \
              [pg20_marked] [pg20_sel $cv]] \
        [list {1 1 rdw} [list 1 0 1 sod $editors] [list 0 1 [pg_rdwslots]] 0 0 [pg_free] {} $r9]
    pg27_clean $cv
    # --- a selector, the results window's key, ANOTHER selector ---------------------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    pg27_key
    set mid5 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg27_press $cv]]
    pg_press .calc.sel.vf
    set top5 [list [pcall calc::pick_id] [pg27_stack $cv] [pg20_calcprev]]
    pg_esc $cv
    set esc5 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg_binds $cv]]
    pg_esc $cv
    check "PG27 a real press on `vt`, the results window's key, then a real press on ANOTHER selector, `vf`: the switch ends the first pick UNDERNEATH the results window's mode, which takes the canvas again -- what it would hand back is the editor's own and no longer the first pick's scripts -- and the new pick stacks on it, with the results window's five scripts as what it took the canvas with.  One real Escape ends the pick and leaves the results window's five scripts on the canvas; the second leaves an unseized canvas, nothing up, nothing armed in the grid, and an ordinary click selects" \
        [list $mid5 $top5 $esc5 [pcall rdw::pick_running] [pcall calc::pick_running] [pg_binds $cv] \
              [set ::calc::selmode] [pg20_sel $cv]] \
        [list {1 1 rdw} [list vf [list 1 1 0 calc $editors] $rdwfive] [list 0 1 [pg_rdwslots]] 0 0 [pg_free] {} $r9]
    pg27_clean $cv
    # --- a selector, the results window's key, the SAME selector again --------------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    pg27_key
    set mid6 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg27_press $cv]]
    pg_press .calc.sel.vt
    set top6 [list [pg27_stack $cv] [pg_binds $cv] [set ::calc::selmode]]
    pg_esc $cv
    check "PG27 ...and the SAME selector pressed again, which disarms it: the pick is ended underneath the results window's mode, which takes the canvas again and holds it alone -- its five scripts on the canvas, the editor's own on record, nothing armed in the grid.  One real Escape then leaves an unseized canvas, nothing up, and an ordinary click selects" \
        [list $mid6 $top6 [pcall rdw::pick_running] [pg_binds $cv] [pg20_sel $cv]] \
        [list {1 1 rdw} [list [list 1 0 0 rdw $editors] [pg_rdwslots] {}] 0 [pg_free] $r9]
    pg27_clean $cv
    # --- a selector, the results window's key, the Calculator window closed ---------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    pg27_key
    set mid7 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg27_press $cv]]
    set door7 [wm protocol .calc WM_DELETE_WINDOW]
    pcall uplevel #0 $door7
    update
    set top7 [list [winfo exists .calc] [pg27_stack $cv] [pg_binds $cv] [set ::calc::selmode]]
    pg_esc $cv
    set end7 [list [pcall rdw::pick_running] [pg_binds $cv] [pg20_sel $cv]]
    check "PG27 ...and the Calculator window CLOSED, by the script its close button runs: the window is gone and the pick with it, ended underneath the results window's mode, which takes the canvas again and holds it alone -- its five scripts on the canvas, the editor's own on record, nothing armed.  One real Escape then leaves an unseized canvas, nothing up, and an ordinary click selects; and the window opens again, with its selector grid on screen, for the rows below" \
        [list $mid7 [pg_word [expr {$door7 ne {}}] hasdoor NODOOR] $top7 $end7 [pg27_reopen]] \
        [list {1 1 rdw} hasdoor [list 0 [list 1 0 0 rdw $editors] [pg_rdwslots] {}] [list 0 [pg_free] $r9] 1]
    pg27_clean $cv
    # --- a selector, the results window's key, a descend in the same window ---------
    # The sheet with the block is shown for this row and the first one put
    # back at its foot.  The descend is bounded: a dialog that waits would
    # stall the suite, so a timer takes down any window that comes up and the
    # row names it.
    set first8 $::design
    set shown8 [pg27_show $::pg27_design]
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    pg27_key
    set mid8 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg27_press $cv]]
    set ::PG_POPPED {}
    set before8 [pg_tops]
    set deadman8 [after 3000 [list pg_dismiss $before8]]
    set went8 [pcall hi_descend inst=xpg target=current mode=edit]
    after cancel $deadman8
    update
    set down8 [list $went8 [pcall xschem get currsch] [file tail [pcall xschem get schname]] \
                    [pcall calc::pick_canvas] $::PG_POPPED]
    set top8 [list [pg27_stack $cv] [pg20_calcprev] [pcall cmdmode::is_suspended]]
    pcall xschem zoom_full
    update
    pg_esc $cv
    set esc8 [list [pcall rdw::pick_running] [pcall calc::pick_running] [pg_binds $cv]]
    pg_esc $cv
    set r5 [list instance [pg18_inst R5]]
    set end8 [list [pcall rdw::pick_running] [pcall calc::pick_running] [pg_binds $cv] \
                   [set ::calc::selmode] [pg27_sel $cv R5]]
    pcall xschem set modified 0
    pcall xschem go_back
    update
    set back8 [pg27_show $first8]
    check "PG27 a real press on `vt`, the results window's key, then a DESCEND into a block in the same window: both modes are paused for the descend and come back on the canvas it lands on in the order they were in -- one level down, on the block's own sheet, no dialog, nothing left paused; the results window's mode on top with the pick's five scripts as what it would hand back, the pick under it with the editor's own.  The first real Escape ends the results window's mode and leaves the pick's five scripts on the canvas; the second ends the pick and leaves the five slots as an unseized canvas holds them, nothing up, nothing armed in the grid, and an ordinary click on the block's resistor selects it.  The first sheet is then shown again at the top level" \
        [list $shown8 $mid8 $down8 $top8 $esc8 $end8 $back8] \
        [list {0 pickdescend.sch} {1 1 rdw} [list 1 1 pgblk.sch $cv {}] \
              [list [list 1 1 0 rdw $calcfive] $editors 0] \
              [list 0 1 [pg27_calcslots]] [list 0 0 [pg_free] {} $r5] {0 picknets.sch}]
    pg27_clean $cv
    # --- the results window's key, a selector over it, that mode ended FIRST --------
    # The keyboard is put into the Calculator's buffer before the end, where a
    # hand that has just pressed a selector may have it, so that the row reads
    # where the pick's seize puts it.
    .calc.buf delete 1.0 end
    pg27_key
    pg_press .calc.sel.vt
    set top9 [list [pg27_stack $cv] [pg20_calcprev]]
    catch {focus -force .calc.buf}
    update
    set kb9 [focus]
    pcall rdw::pick_end
    update
    set mid9 [list [pcall rdw::pick_running] [pcall calc::pick_running] [pcall calc::pick_id] \
                   [expr {[pg_binds $cv] eq [pg27_calcslots] ? {its five} : [pg_binds $cv]}] \
                   [pg20_calcprev] [set ::calc::selmode] [pg27_timers calc::pick_pump] [pg27_focus $cv]]
    pg_esc $cv
    set end9 [list [pcall calc::pick_running] [pcall rdw::pick_running] \
                   [expr {[pg_allbinds $cv] eq $base27 ? {as before any mode} : [pg_allbinds $cv]}] \
                   [set ::calc::selmode] [pg20_sel $cv]]
    check "PG27 the results window's key, a real press on `vt` over it, and THE RESULTS WINDOW'S MODE ENDED FIRST, by the command its own Escape binding runs: its release writes the editor's scripts over the pick's, and the pick takes the canvas again -- still armed for `vt` in the grid, its five scripts on the canvas, what it would hand back the editor's own and no longer the results window's scripts, ONE prompt timer waiting, and the keyboard on the canvas although it was in the Calculator's buffer before.  ONE real Escape on the canvas then ends the pick: nothing is up, every binding of the canvas is as before any mode, nothing is armed in the grid, and an ordinary click selects (fixture legs: the stack with the pick on top, and the pick's predecessors there; where the keyboard was before the end)" \
        [list $top9 $kb9 $mid9 $end9] \
        [list [list [list 1 1 0 calc $editors] $rdwfive] .calc.buf \
              [list 0 1 vt {its five} $editors vt 1 $cv] \
              [list 0 0 {as before any mode} {} $r9]]
    pg27_clean $cv
    # --- the results window's end with that mode NOT up -----------------------------
    # The pick is armed and its five slots are then written back to what an
    # unseized canvas holds, by hand: armed in the grid with nothing bound,
    # which is the state the row above passes through.  The results window's
    # end, called with its mode not up, has ended nothing and asks nothing;
    # the pick's own question, put directly, takes the canvas.
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    foreach b [pg_free] { pcall bind $cv [lindex $b 0] [lindex $b 2] }
    set r11 [pcall rdw::pick_end]
    set idle11 [list $r11 [pcall calc::pick_running] [pg_binds $cv]]
    set direct11 [list [pcall calc::pick_reseat] \
                       [expr {[pg_binds $cv] eq [pg27_calcslots] ? {its five} : [pg_binds $cv]}] [pg20_calcprev]]
    pg_esc $cv
    check "PG27 ...and the results window's end asks the pick NOTHING when it ended no mode: with the pick armed and its five slots written back by hand to what an unseized canvas holds, that end, called with the results window's mode not up, answers 0 and leaves the canvas as it is; asked directly, the pick takes the canvas -- its five scripts, the editor's own on record -- and one real Escape then leaves an unseized canvas with nothing up" \
        [list $idle11 $direct11 [pcall calc::pick_running] [pg_binds $cv]] \
        [list [list 0 1 [pg_free]] [list 1 {its five} $editors] 0 [pg_free]]
    pg27_clean $cv
    # --- when the pick takes the canvas again, and when it leaves it alone ----------
    # The cases it must leave alone, each asked directly: nothing armed; the
    # pick holding the canvas itself, also with `cmdmode`'s reader of what the
    # modes hold taken away for the length of the leg (this file loads without
    # `cmdmode` too, and there the pick's own script in the press slot is all
    # there is to go by); the results window's mode seized OVER the pick and
    # up; that mode ended in order; the pick paused, as a descend pauses it;
    # and its record naming a canvas that has been destroyed.
    set g_none [pcall calc::pick_reseat]
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    set g_rec [pg20_calcprev]
    set g_alone [list [pcall calc::pick_reseat] \
                      [expr {[pg_binds $cv] eq [pg27_calcslots] ? {its five} : [pg_binds $cv]}] \
                      [expr {[pg20_calcprev] eq $g_rec ? {record kept} : [pg20_calcprev]}]]
    set g_bare NOREADER
    if {[llength [info commands ::cmdmode::pristine]]} {
        rename ::cmdmode::pristine ::cmdmode::pg27_pristine_kept
        set g_bare [list [pcall calc::pick_reseat] \
                         [expr {[pg20_calcprev] eq $g_rec ? {record kept} : [pg20_calcprev]}]]
        rename ::cmdmode::pg27_pristine_kept ::cmdmode::pristine
    }
    pg27_key
    set g_under [list [pcall calc::pick_reseat] [pg27_press $cv] \
                      [expr {[pg20_calcprev] eq $g_rec ? {record kept} : [pg20_calcprev]}]]
    pg_esc $cv
    set g_back [list [pcall rdw::pick_running] [pcall calc::pick_reseat] \
                     [expr {[pg_binds $cv] eq [pg27_calcslots] ? {its five} : [pg_binds $cv]}]]
    pcall calc::pick_suspend
    set g_paused [list [pcall calc::pick_reseat] [info exists ::calc::pick(suspended)] [pg_binds $cv]]
    pcall calc::pick_resume $cv
    set g_gone NOTUP
    set g_cv0 {} ; catch {set g_cv0 $::calc::pick(canvas)}
    if {$g_cv0 ne {}} {
        catch {frame .pg27gone}
        catch {destroy .pg27gone}
        set ::calc::pick(canvas) .pg27gone
        set g_gone [list [winfo exists .pg27gone] [catch {calc::pick_reseat} g_r] $g_r]
        set ::calc::pick(canvas) $g_cv0
    }
    pg_esc $cv
    if {[llength [info commands ::cmdmode::pg27_pristine_kept]]} { catch {rename ::cmdmode::pg27_pristine_kept ::cmdmode::pristine} }
    check "PG27 `calc::pick_reseat` TAKES THE CANVAS AGAIN ONLY WHEN THE PICK WAS LEFT WITH NOTHING BOUND (the row above is the case it acts in).  It does nothing with no pick armed; nothing while the pick holds the canvas itself -- its five scripts stay, its record stays -- also with `cmdmode`'s reader of what the modes hold taken away, where the pick's own script in the press slot is all there is to go by; nothing with the results window's mode seized over the pick and up -- the press slot stays that mode's and the pick's record stays; nothing once that mode has ended in order and handed the pick's scripts back; nothing while the pick is paused -- it stays paused and the canvas stays released; and with its record naming a canvas that has been destroyed it asks nothing of that window: it answers 0 and raises nothing.  One real Escape then ends the pick and leaves an unseized canvas" \
        [list $g_none $g_alone $g_bare $g_under $g_back $g_paused $g_gone [pcall calc::pick_running] [pg_binds $cv]] \
        [list 0 {0 {its five} {record kept}} {0 {record kept}} {0 rdw {record kept}} {0 0 {its five}} \
              [list 0 1 [pg_free]] {0 0 0} 0 [pg_free]]
    pg27_clean $cv
    # --- a pick whose click has resolved, its release still to come ------------------
    # A pick that resolved a net ends on the RELEASE of that click: until then
    # the release slot holds the pick's end.  The results window's mode is
    # ended underneath between the press and the release here, and the pick,
    # taking the canvas again, must put that end back on the release slot.
    .calc.buf delete 1.0 end
    pg27_key
    pg_press .calc.sel.vt
    set p12 [pg_px 50 0]
    update
    event generate $cv <Motion> -x [lindex $p12 0] -y [lindex $p12 1]
    update
    incr ::PG_T 5000
    event generate $cv <ButtonPress-1> -x [lindex $p12 0] -y [lindex $p12 1] -time $::PG_T
    update
    set held12 [list [pg_buf] [info exists ::calc::pick(done)] [pcall bind $cv <ButtonRelease-1>]]
    pcall rdw::pick_end
    update
    set mid12 [list [pcall calc::pick_running] [pg27_press $cv] [pcall bind $cv <ButtonRelease-1>] [pg20_calcprev]]
    event generate $cv <ButtonRelease-1> -x [lindex $p12 0] -y [lindex $p12 1] -time [expr {$::PG_T + 80}]
    update
    check "PG27 ...and a pick whose click has RESOLVED and is waiting for its release keeps its end on the release slot: the results window's key, a real press on `vt`, a real press on the wire -- the net's name is in the buffer and the release slot holds the pick's end -- then the results window's mode ended, with the button still down: the pick takes the canvas again with the editor's own on record and the release slot holds its end again, so the real release ends the one-shot pick: nothing is up, the five slots are as an unseized canvas holds them, nothing is armed in the grid, and the name is still in the buffer" \
        [list $held12 $mid12 [pcall calc::pick_running] [pcall rdw::pick_running] [pg_binds $cv] \
              [set ::calc::selmode] [pg_buf]] \
        [list [list {vt(lp)} 1 {calc::pick_end picked; break}] \
              [list 1 calc {calc::pick_end picked; break} $editors] 0 0 [pg_free] {} {vt(lp)}]
    pg27_clean $cv
    # --- the results window's key, Select On Design over it, that mode ended FIRST --
    pg27_key
    pg20_sod
    set top10 [list [pg27_stack $cv] [pg27_sodprev]]
    pcall rdw::pick_end
    update
    # what the destroy slot holds while Select On Design is up: the canvas's
    # own handler, when it has one, and the mode's hook behind it
    set hook27 [list ase::ui::sod_canvas_gone $::tok %W]
    if {$destroy27 ne {}} { set hook27 "$destroy27\n$hook27" }
    set mid10 [list [pcall rdw::pick_running] [pg20_sodup] [pg27_press $cv] [pg27_sodprev] \
                    [pg27_timers ase::ui::sod_prompt_pump] \
                    [expr {[pcall bind $cv <Destroy>] eq $hook27 ? {its hook, once} : [pcall bind $cv <Destroy>]}]]
    pg_esc $cv
    set end10 [list [pg20_sodup] [pcall rdw::pick_running] \
                    [expr {[pg_allbinds $cv] eq $base27 ? {as before any mode} : [pg_allbinds $cv]}] \
                    [pg20_marked] [pg20_sel $cv]]
    check "PG27 the same with Select On Design on top: the results window's key, Select On Design entered over it, and the results window's mode ended FIRST.  Select On Design takes the canvas again -- still up, the press slot its own, what it has on record the editor's own for the five slots and the canvas's own handler for its destruction, no longer the results window's scripts, ONE prompt timer waiting, and its hook for the canvas going away on that slot once.  ONE real Escape on the canvas then ends it: nothing is up, every binding of the canvas is as before any mode, no marker, and an ordinary click selects (fixture leg: the stack with Select On Design on top, and its predecessors there)" \
        [list $top10 $mid10 $end10] \
        [list [list [list 1 0 1 sod $editors] [concat $rdwfive [list $destroy27]]] \
              [list 0 1 sod [concat $editors [list $destroy27]] 1 {its hook, once}] \
              [list 0 0 {as before any mode} {} $r9]]
    pg27_clean $cv
    # --- the control: the results window's mode at the BOTTOM -----------------------
    # Here nothing was ended underneath it.  Select On Design sits on top of the
    # results window's mode and holds the canvas, so that mode must leave the
    # canvas alone when Select On Design is entered again: taking it then would
    # be a seize OVER a mode that is up, with that mode's scripts kept as the
    # predecessors, and the last Escape would hand those dead scripts back to a
    # canvas no mode holds.
    pg27_key
    pg20_sod
    set mid4 [list [pcall rdw::pick_running] [pg20_sodup] [pg27_press $cv] [pg27_rdwprev]]
    pg20_sod
    set top4 [pg27_stack $cv]
    pg_esc $cv
    set esc4 [list [pg20_sodup] [pcall rdw::pick_running] [pg_binds $cv]]
    pg_esc $cv
    check "PG27 the control, with the results window's mode at the BOTTOM: its key, Select On Design entered over it, and Select On Design entered AGAIN.  Nothing was ended underneath the results window's mode, and it does not take a canvas another mode holds: what it would hand back is still the editor's own, after the second Select On Design as after the first.  The first real Escape ends Select On Design and leaves the results window's five scripts on the canvas, the second leaves an unseized canvas -- not Select On Design's scripts with no mode up to end -- no marker, nothing up, and an ordinary click selects" \
        [list $mid4 $top4 $esc4 [pcall rdw::pick_running] [pg20_sodup] [pg_binds $cv] \
              [pg20_marked] [pg20_sel $cv]] \
        [list [list 1 1 sod $editors] [list 1 0 1 sod $editors] [list 0 1 [pg_rdwslots]] 0 0 [pg_free] {} $r9]
    pg27_clean $cv
}

# =============================================================================
# PG28 — TWO MODES STACKED: ONE SENTENCE ON THE STATUS BAR, THE TOP MODE'S
# =============================================================================
# Each of the three click modes keeps its own sentence on the design window's
# status slot with a timer of its own.  With two of them stacked, both timers
# wrote and the slot changed text every tick.  A mode now writes only while no
# other mode that is up holds the canvas over it (`calc::pick_covered`,
# `ase::ui::sod_covered`, `rdw::_pick_covered`): the clicks are the top mode's,
# and so is the sentence.  The timers go on running, so when the top mode ends
# the sentence of the mode under it is back within a tick or two.
#
# One row for each stack: Select On Design with the results window's mode in
# both orders, this pick with it in both orders.  The pointer is rested on
# empty canvas first, where no prompt names a pin.
#
# the design window's status slot read every 20 ms for `ms` milliseconds with
# no event sent in between: the different sentences it held, in the order they
# first appeared.  The editor blanks the slot on every canvas event it is
# handed and the mode's timer then writes its sentence again; such a blank is
# nobody's sentence and is left out.
proc pg28_bar {cv ms} {
    set seen {}
    for {set t 0} {$t < $ms} {incr t 20} {
        pg22_wait 20
        set b [pcall [ase::ui::sod_statusbar $cv] cget -text]
        if {[string trim $b] eq {}} continue
        if {[lsearch -exact $seen $b] < 0} { lappend seen $b }
    }
    return $seen
}
# is the slot's text `want` within 400 ms, read every 20 ms: `back`, else what
# the slot holds then
proc pg28_back {cv want} {
    for {set t 0} {$t < 400} {incr t 20} {
        if {[pcall [ase::ui::sod_statusbar $cv] cget -text] eq $want} { return back }
        pg22_wait 20
    }
    return [pcall [ase::ui::sod_statusbar $cv] cget -text]
}
# enter the modes of `order` one over the other -- S Select On Design, R the
# results window's key, C a real press on `vt` -- rest the pointer on empty
# canvas, and answer: what is up and whose press script the canvas holds; the
# sentences the slot held over 1.2 s; what the slot holds straight after the
# writer of the mode on top and then the writer of the mode under it were each
# run once by hand (`pg28_tick`); then, after ONE real Escape, which ends the
# mode on top: whether the slot holds `lower` within 400 ms, and the sentences
# it held over the next 0.6 s.
#
# The sampled leg alone would not always tell a mode under another that still
# writes: timers that come due together run one after the other, and when the
# top mode's runs last the slot never shows the other sentence to a sampler.
# The leg run by hand does not depend on when the timers fall.
proc pg28_run {cv order lower} {
    foreach m $order {
        switch -- $m {
            S { pg20_sod }
            R { pg27_key }
            C { .calc.buf delete 1.0 end ; pg_press .calc.sel.vt }
        }
    }
    pg_mouse $cv 100 250
    pg22_wait 300
    set stack [list [pg20_sodup] [pcall calc::pick_running] [pcall rdw::pick_running] [pg27_press $cv]]
    set both [pg28_bar $cv 1200]
    pg28_tick [lindex $order end]
    pg28_tick [lindex $order 0]
    set ticked [pcall [ase::ui::sod_statusbar $cv] cget -text]
    pg_esc $cv
    set back [pg28_back $cv $lower]
    set after [pg28_bar $cv 600]
    return [list $stack $both $ticked $back $after]
}
# run the status-slot writer of mode `m` once, now: Select On Design's and the
# pick's are their timers' own procs, so the tick that is waiting is cancelled
# first and the one run here arms the next -- each mode keeps ONE timer; the
# results window's is the proc its timer and its canvas tag both call
proc pg28_tick {m} {
    switch -- $m {
        S { catch {after cancel $::ase::ui::sod($::tok,pump)} ; pcall ase::ui::sod_prompt_pump $::tok }
        C { catch {after cancel $::calc::pick(pump)} ; pcall calc::pick_pump }
        R { pcall rdw::_hint_sync }
    }
}
group PG28 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    pcall xschem zoom_full
    update
    set cv [pcall calc::pick_canvas]
    set sod_says  {select outputs on design}
    set rdw_says  {Click on instance for annotation OP info in Results Display Window}
    set calc_says {Calculator vt: click a net to insert its name; ESC cancels}
    pg27_clean $cv
    check "PG28 fixture: nothing is up, the canvas is the editor's own, and the point the pointer is rested on in the rows below is empty canvas: no object there and no device pin in reach" \
        [list [pg_binds $cv] [pcall rdw::pick_running] [pcall calc::pick_running] [pg20_sodup] \
              [pcall xschem object_at 100 250] [pcall ase::ui::sod_terminal_at $::tok 100 250]] \
        [list [pg_free] 0 0 0 {} {}]
    set got [pg28_run $cv {S R} $sod_says]
    pg_esc $cv
    check "PG28 Select On Design, then the results window's key over it: with both up the slot holds ONE sentence for 1.2 s with no event sent, the results window's, whose mode is on top, and it still holds that sentence straight after the writer of each mode was run once by hand, the top mode's first; one real Escape ends that mode and Select On Design's sentence is back within 400 ms and is the only one for the next 0.6 s (what is up, as Select On Design, the pick, the results window's mode, and whose press script the canvas holds; the sentences; the slot after the two writers; back; the sentences after)" \
        $got [list {1 0 1 rdw} [list $rdw_says] $rdw_says back [list $sod_says]]
    pg27_clean $cv
    set got [pg28_run $cv {R S} $rdw_says]
    pg_esc $cv
    check "PG28 the results window's key, then Select On Design over it: ONE sentence, Select On Design's, which is on top, also straight after both writers were run by hand; its Escape ends it and the results window's sentence is back and is the only one" \
        $got [list {1 0 1 sod} [list $sod_says] $sod_says back [list $rdw_says]]
    pg27_clean $cv
    set got [pg28_run $cv {C R} $calc_says]
    pg_esc $cv
    check "PG28 a real press on `vt`, then the results window's key over the pick: ONE sentence, the results window's, also straight after both writers were run by hand; its Escape ends that mode and the pick's prompt is back and is the only one" \
        $got [list {0 1 1 rdw} [list $rdw_says] $rdw_says back [list $calc_says]]
    pg27_clean $cv
    set got [pg28_run $cv {R C} $rdw_says]
    pg_esc $cv
    check "PG28 the results window's key, then a real press on `vt` over it: ONE sentence, the pick's prompt, also straight after both writers were run by hand; its Escape ends the pick and the results window's sentence is back and is the only one" \
        $got [list {0 1 1 calc} [list $calc_says] $calc_says back [list $rdw_says]]
    pg27_clean $cv
    check "PG28 ...and after the four stacks nothing is up, the five slots are as an unseized canvas holds them, and an ordinary click selects" \
        [list [pcall rdw::pick_running] [pcall calc::pick_running] [pg20_sodup] [pg_binds $cv] [pg20_sel $cv]] \
        [list 0 0 0 [pg_free] [list instance [pg18_inst R9]]]
    pcall xschem unselect_all
    .calc.buf delete 1.0 end
}

# =============================================================================
# PG29 — A MODE ENDED WHILE A DESCEND HAS THE STACK PAUSED WRITES NOTHING
# =============================================================================
# The descend command given with nothing selected pauses every click mode and
# waits in the event loop for a click on an instance (band PG27 has the descend
# that goes through).  Each paused mode has handed the canvas back by then and
# still has on record what the canvas held when it took it: for the upper mode
# of a stack, the lower mode's scripts.  A mode can be ended during that wait
# -- the results window's by Escape in its own window, this pick by its
# selector pressed again or the Calculator window closed, Select On Design by
# a selector being pressed -- and an end that wrote its record back a second
# time would put the scripts of the OTHER mode, which is paused, on the canvas:
# the click the descend waits for would be that mode's, and its Escape would
# not be the editor's.  The release of a paused mode writes nothing
# (`calc::pick_release`, `rdw::pick_release`, `ase::ui::sod_release`).
#
# Each row ends the mode that sits ON TOP of the other, where the record is the
# other mode's scripts, and reads every binding of the canvas straight after.
# The wait is then ended by a real Escape on the canvas, which is the editor's
# while everything is paused: it drops the descend, and that puts back what was
# paused.  The descend is armed by the command its key runs; the results
# window's mode is ended by the command its Escape binding runs (the binding is
# pressed for real in band DS9 of test_cmdmode_descend_0201, which has the two
# other orders); the selector and the Escapes are real presses, and the
# Calculator window is closed by the script its close button runs.
#
# the descend command with nothing selected: what it answered, whether the
# modes are paused now, and the names `cmdmode` holds to put back
proc pg29_wait {} {
    pcall xschem unselect_all
    set r [pcall hi_descend]
    update
    return [list $r [pcall cmdmode::is_suspended] [pcall cmdmode::pending]]
}
# is the pick marked paused, is the results window's mode, is Select On Design
proc pg29_paused {} {
    return [list [info exists ::calc::pick(suspended)] [info exists ::rdw::pick(suspended)] \
                 [info exists ::ase::ui::sod($::tok,suspended)]]
}
# Put everything back by hand, whatever a row left: a descend that still waits
# is dropped, which resumes what it paused, and then `pg27_clean`.
proc pg29_clean {cv} {
    catch {xschem callback $cv 2 0 0 65307 0 0 0}
    pcall cmdmode::resume_all
    pg27_clean $cv
}
# every binding of the canvas against the table band PG29 took with nothing
# up: that phrase, or the five slots as they are
proc pg29_canvas {cv} {
    return [expr {[pg_allbinds $cv] eq $::PG29_BASE ? {as before any mode} : [pg_binds $cv]}]
}
group PG29 {
    pcall calc::pick_end cancel
    pcall xschem unselect_all
    set cv [pcall calc::pick_canvas]
    set r9 [list instance [pg18_inst R9]]
    set editors [list {} {} {} {} {xschem callback %W -3 %x %y 0 %b 0 %s}]
    set rdwfive [list $::PG_RDWPRESS break {rdw::pick_end; break} break break]
    set calcfive [list $::PG_PRESS break {calc::pick_end cancel; break} break $::PG_PRESS]
    pg29_clean $cv
    # every binding of the canvas with nothing up: what `as before any mode`
    # is read against (`pg29_canvas`)
    set ::PG29_BASE [pg_allbinds $cv]
    check "PG29 fixture: nothing is up, nothing is paused, the five slots are as an unseized canvas holds them, and the three modes are among those `cmdmode` pauses for a descend" \
        [list [pg_binds $cv] [pcall rdw::pick_running] [pcall calc::pick_running] [pg20_sodup] [pcall cmdmode::is_suspended] \
              [lmap m {calc_pick rdw_pick ase_sod} { expr {[lsearch -exact [pcall cmdmode::registered] $m] >= 0 ? {known} : "UNKNOWN:$m"} }]] \
        [list [pg_free] 0 0 0 0 {known known known}]
    # --- the pick, the results window's mode over it, and that mode ended -----------
    .calc.buf delete 1.0 end
    pg_press .calc.sel.vt
    pg27_key
    set built1 [list [pcall calc::pick_running] [pcall rdw::pick_running] [pg27_press $cv] \
                     [expr {[pg27_rdwprev] eq $calcfive ? {the pick's five} : [pg27_rdwprev]}]]
    set wait1 [list [pg29_wait] [pg29_paused] [pg29_canvas $cv]]
    pcall rdw::pick_end
    update
    set mid1 [list [pcall rdw::pick_running] [pg29_canvas $cv] [pcall calc::pick_running] [pg29_paused] \
                   [set ::calc::selmode] [pg27_timers calc::pick_pump] [pg27_timers rdw::_hint_pump] \
                   [pcall cmdmode::is_suspended] [pcall cmdmode::pending]]
    pg_esc $cv
    set back1 [list [pcall cmdmode::is_suspended] [pcall calc::pick_running] [pg29_paused] [pg27_press $cv] \
                    [pg20_calcprev] [pcall rdw::pick_running] [pg27_timers calc::pick_pump]]
    pg_esc $cv
    check "PG29 a real press on `vt`, the results window's key over it, the descend command with nothing selected, and THE RESULTS WINDOW'S MODE ENDED DURING THE WAIT: the descend pauses both and the canvas is as before any mode; that mode's end leaves it so -- not the pick's five scripts, which that mode had on record -- with the pick still armed in the grid and paused, no timer of either mode waiting, and the descend still waiting with both names held.  A real Escape on the canvas drops the descend and puts the pick back alone: its press script on the canvas, the editor's own on record, one prompt timer, the results window's mode still gone.  ONE more real Escape ends the pick: nothing is up, the canvas is as before any mode, nothing is armed in the grid, and an ordinary click selects (fixture legs: the stack, with what the results window's mode has on record; the wait as the descend's answer, paused, the names held -- which of the three is marked paused -- the canvas)" \
        [list $built1 $wait1 $mid1 $back1 [pcall calc::pick_running] [pg29_canvas $cv] [set ::calc::selmode] [pg20_sel $cv]] \
        [list {1 1 rdw {the pick's five}} [list {1 1 {calc_pick rdw_pick}} {1 1 0} {as before any mode}] \
              [list 0 {as before any mode} 1 {1 0 0} vt 0 0 1 {calc_pick rdw_pick}] \
              [list 0 1 {0 0 0} calc $editors 0 1] 0 {as before any mode} {} $r9]
    pg29_clean $cv
    # --- the results window's mode, the pick over it, and its selector pressed again -
    .calc.buf delete 1.0 end
    pg27_key
    pg_press .calc.sel.vt
    set built2 [list [pcall rdw::pick_running] [pcall calc::pick_running] [pg27_press $cv] \
                     [expr {[pg20_calcprev] eq $rdwfive ? {the results window's five} : [pg20_calcprev]}]]
    set wait2 [list [pg29_wait] [pg29_paused] [pg29_canvas $cv]]
    pg_press .calc.sel.vt
    set mid2 [list [pcall calc::pick_running] [set ::calc::selmode] [pg29_canvas $cv] [pcall rdw::pick_running] \
                   [pg29_paused] [pg27_timers calc::pick_pump] [pcall cmdmode::is_suspended]]
    pg_esc $cv
    set back2 [list [pcall cmdmode::is_suspended] [pcall rdw::pick_running] [pg29_paused] [pg27_press $cv] \
                    [pg27_rdwprev] [pcall calc::pick_running]]
    pg_esc $cv
    check "PG29 the other order, and THE PICK ENDED DURING THE WAIT BY ITS OWN SELECTOR: the results window's key, a real press on `vt` over it, the descend command, and a real press on `vt` again, which disarms the pick.  Nothing is armed in the grid and no prompt timer is waiting, and the canvas is still as before any mode -- not the results window's five scripts, which the pick had on record -- with that mode still paused and the descend still waiting.  A real Escape on the canvas drops the descend and puts that mode back alone, its press script on the canvas and the editor's own on record; ONE more real Escape ends it: nothing is up, the canvas is as before any mode, and an ordinary click selects (fixture legs: the stack, with what the pick has on record; the wait)" \
        [list $built2 $wait2 $mid2 $back2 [pcall rdw::pick_running] [pg29_canvas $cv] [pg20_sel $cv]] \
        [list {1 1 calc {the results window's five}} [list {1 1 {rdw_pick calc_pick}} {1 1 0} {as before any mode}] \
              [list 0 {} {as before any mode} 1 {0 1 0} 0 1] \
              [list 0 1 {0 0 0} rdw $editors 0] 0 {as before any mode} $r9]
    pg29_clean $cv
    # --- ...and the Calculator window closed during the wait -------------------------
    .calc.buf delete 1.0 end
    pg27_key
    pg_press .calc.sel.vt
    set wait3 [list [pg29_wait] [pg29_paused] [pg29_canvas $cv]]
    set door3 [wm protocol .calc WM_DELETE_WINDOW]
    pcall uplevel #0 $door3
    update
    set mid3 [list [winfo exists .calc] [pcall calc::pick_running] [set ::calc::selmode] [pg29_canvas $cv] \
                   [pcall rdw::pick_running] [pg29_paused] [pcall cmdmode::is_suspended]]
    pg_esc $cv
    set back3 [list [pcall cmdmode::is_suspended] [pcall rdw::pick_running] [pg29_paused] [pg27_press $cv] [pg27_rdwprev]]
    pg_esc $cv
    set end3 [list [pcall rdw::pick_running] [pg29_canvas $cv] [pg20_sel $cv]]
    check "PG29 ...and THE CALCULATOR WINDOW CLOSED DURING THE WAIT, by the script its close button runs, with the pick over the results window's mode and both paused: the window is gone and the pick with it, nothing armed, and the canvas is still as before any mode -- not the results window's five scripts -- with that mode still paused and the descend still waiting.  A real Escape on the canvas drops the descend and puts that mode back alone with the editor's own on record; ONE more ends it and leaves the canvas as before any mode, where an ordinary click selects; and the window opens again, with its selector grid on screen, for the rows below (fixture legs: the wait; the close script is there)" \
        [list $wait3 [pg_word [expr {$door3 ne {}}] hasdoor NODOOR] $mid3 $back3 $end3 [pg27_reopen]] \
        [list [list {1 1 {rdw_pick calc_pick}} {1 1 0} {as before any mode}] hasdoor \
              [list 0 0 {} {as before any mode} 1 {0 1 0} 1] [list 0 1 {0 0 0} rdw $editors] \
              [list 0 {as before any mode} $r9] 1]
    pg29_clean $cv
    # --- Select On Design over the results window's mode, and a selector pressed -----
    # Arming a pick ends a Select On Design that is up (band PG20), a paused one
    # as well.  The pick then takes the canvas, live, in the middle of the wait:
    # what it has on record must be the editor's own.
    .calc.buf delete 1.0 end
    pg27_key
    pg20_sod
    set built4 [list [pcall rdw::pick_running] [pg20_sodup] [pg27_press $cv] \
                     [expr {[lrange [pg27_sodprev] 0 4] eq $rdwfive ? {the results window's five} : [pg27_sodprev]}]]
    set wait4 [list [pg29_wait] [pg29_paused] [pg29_canvas $cv]]
    pg_press .calc.sel.vt
    set mid4 [list [pg20_sodup] [pcall calc::pick_running] [pcall calc::pick_id] [pg27_press $cv] [pg20_calcprev] \
                   [pcall rdw::pick_running] [pg29_paused] [pg20_marked] [pcall cmdmode::is_suspended]]
    pg_esc $cv
    set esc4 [list [pcall calc::pick_running] [pg29_canvas $cv] [pg29_paused] [pcall cmdmode::is_suspended]]
    pg_esc $cv
    set back4 [list [pcall cmdmode::is_suspended] [pcall rdw::pick_running] [pg29_paused] [pg27_press $cv] [pg27_rdwprev]]
    pg_esc $cv
    check "PG29 Select On Design ended during the wait BY A SELECTOR: the results window's key, Select On Design entered over it, the descend command, and a real press on `vt`.  The arm ends the paused Select On Design, which writes nothing, and the pick takes the canvas with the editor's own on record -- not the results window's five scripts, which Select On Design had on record -- while that mode stays paused and the descend still waits.  A real Escape ends the pick and leaves the canvas as before any mode; the next drops the descend and puts the results window's mode back alone with the editor's own on record; the third ends it: nothing is up, the canvas is as before any mode, nothing is armed in the grid, no marker, and an ordinary click selects (fixture legs: the stack, with what Select On Design has on record; the wait)" \
        [list $built4 $wait4 $mid4 $esc4 $back4 [pcall rdw::pick_running] [pcall calc::pick_running] [pg20_sodup] \
              [pg29_canvas $cv] [set ::calc::selmode] [pg20_marked] [pg20_sel $cv]] \
        [list {1 1 sod {the results window's five}} [list {1 1 {rdw_pick ase_sod}} {0 1 1} {as before any mode}] \
              [list 0 1 vt calc $editors 1 {0 1 0} {} 1] [list 0 {as before any mode} {0 1 0} 1] \
              [list 0 1 {0 0 0} rdw $editors] 0 0 0 {as before any mode} {} {} $r9]
    pg29_clean $cv
    check "PG29 ...and after the four orders nothing is up, nothing is paused, the five slots are as an unseized canvas holds them, and an ordinary click selects" \
        [list [pcall rdw::pick_running] [pcall calc::pick_running] [pg20_sodup] [pcall cmdmode::is_suspended] [pg_binds $cv] [pg20_sel $cv]] \
        [list 0 0 0 0 [pg_free] $r9]
    pcall xschem unselect_all
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
    check "PG8 ...and NO canvas is left seized after the switch: the end path ran, so the five slots are back at their predecessors rather than carrying a dead mode's scripts -- issue 1305's permanent seize is what this forecloses" \
        [list [expr {[info exists ::calc::pick] ? 1 : 0}] [pg_binds $cv8]] \
        [list 0 [pg_free]]
    pg_press .calc.sel.vt
    pg_press .calc.sel.vf
    check "PG8 R208c: pressing `vf` while `vt` is armed SWITCHES to it -- the run wrote AC too, so the new id arms on the same canvas" \
        [list [pcall calc::pick_running] [pcall calc::pick_id] [set ::calc::selmode] \
              [lindex [pcall calc::status_history] 0]] \
        [list 1 vf vf {selector vf: click a net on the schematic; ESC cancels}]
    set pg8prev {}
    foreach k {prevpress prevrel prevesc prevmotion prevdbl} {
        set v NOKEY ; catch {set v $::calc::pick($k)} ; lappend pg8prev $v
    }
    pcall calc::pick_end cancel
    check "PG8 ...and the switched-to mode recorded the canvas's ORIGINAL predecessors, not `vt`'s seize scripts -- nothing for the first four slots and the editor's own script for the double click -- so ending it hands the five slots back as an unseized canvas holds them: issue 1305's permanent seize, foreclosed on the arming path too" \
        [list $pg8prev [pg_binds $cv8]] \
        [list [list {} {} {} {} {xschem callback %W -3 %x %y 0 %b 0 %s}] [pg_free]]
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
        [list 1 1 $::PG_PRESS break 0]
    # ⚠ A RESUME HANDED A DEAD CANVAS FALLS BACK TO THE ONE IT WAS SEIZED ON, and
    # the first version of this band expected it to drop the mode.  It should not:
    # `rdw::pick_resume` does the same, and the fallback is what keeps a resume
    # from throwing a live mode away just because the caller named a window that
    # has since gone.  The DROP needs BOTH to be dead, which is the next leg.
    pcall cmdmode::suspend_all
    set k [pcall calc::pick_resume .nosuch.drw]
    check "PG11 a resume handed a DEAD canvas falls back to the one the mode was seized on rather than throwing a live mode away, which is `rdw::pick_resume`'s own behaviour and ruling D2's cautious half" \
        [list $k [pcall calc::pick_running] [pcall bind $cv <ButtonPress-1>]] \
        [list 1 1 $::PG_PRESS]
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
        [list [pg_free] 0]
}

# =============================================================================
# PG7 — R307: TWO DOORS, BECAUSE `calc::close` IS ONLY THE TITLE-BAR X
# =============================================================================
group PG7 {
    pcall calc::pick_arm vt
    set cv $::calc::pick(canvas)
    check "PG7 fixture: a pick is live and the canvas is seized" \
        [list [pcall calc::pick_running] [pcall bind $cv <ButtonPress-1>]] \
        [list 1 $::PG_PRESS]
    pcall calc::close
    check "PG7 R307, door one: `calc::close` releases the pick BEFORE the widgets go away -- `destroy .calc` could not do it, because the bindings live on the design window's `.drw`, which is not a descendant of `.calc`" \
        [list [winfo exists .calc] [pcall calc::pick_running] [set ::calc::selmode] \
              [pg_binds $cv]] \
        [list 0 0 {} [pg_free]]
    pcall calc::open
    update idletasks
    pcall calc::pick_arm vt
    check "PG7 fixture: a pick is live again, on a freshly opened window" \
        [list [pcall calc::pick_running] [pcall bind $cv <ButtonPress-1>]] \
        [list 1 $::PG_PRESS]
    pcall destroy .calc
    update
    check "PG7 R307, door TWO, and it is not optional: a bare `destroy .calc` never runs the `WM_DELETE_WINDOW` handler, so without the `<Destroy>` bind this path would leave the design canvas PERMANENTLY seized -- issue 1305 measured exactly that in the RDW: every click dumping into a dead mode and nothing selectable again, unrecoverable inside the session" \
        [list [winfo exists .calc] [pcall calc::pick_running] [pg_binds $cv]] \
        [list 0 0 [pg_free]]
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
# the clobber did not fire during this run, never that it cannot.  The engine
# still overwrites the pair (issue 1659); the pick's own press no longer
# depends on it (band PG24), the editor's clicks this file makes still do.
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
