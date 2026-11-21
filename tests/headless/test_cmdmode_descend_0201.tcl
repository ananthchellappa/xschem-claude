# A command interrupted to descend is SUSPENDED, not ended — and comes back.
# doc/claude/issues/0201-no-command-suspend-resume-contract.md
#
# The contract's own unit test is the pure-Tcl sibling, tests/headless/test_cmdmode_0201.tcl.
# THIS file is the real thing: a live ASE Select-On-Design mode (the Ctrl-4 Direct Plot
# flavour) seized on a real canvas, put down and picked back up around a real verb-noun
# descend driven through `xschem callback`.
#
# What it is defending. Before 0201, `ase::ui::sod_end` was the ONLY exit from the mode
# and it FINISHES — in plot flavour it hands the queue to dp_finish and plots. So the
# descend that issue 0200 made reachable could not put the interrupted command back, and
# an ESC during the pick had no Tcl continuation at all (abort_operation dropped the arm
# silently), which would have left the mode down forever with its traces unreachable.
#
# Legs:
#   FX0       the fixture's own precondition: the canvas is MAPPED and sized. Every leg
#             below is silently vacuous without it -- see the wait loop under the SKIP
#             guard, and doc/claude/merge5_loose_ends/receipts/02-merge5-gui-zero-run.md
#   CS1-CS2   select_on_design really seizes the canvas; suspend_all releases it
#   CS3       every binding the mode took goes back to its EXACT predecessor
#             (string-identical: the trailing `break` is what keeps the C dispatcher
#             out, 0202)
#   CS4-CS5   the records survive a suspend — queue, qcolors, count, mode, prompt
#   CS6       THE POINT: a suspend does not plot. dp_finish is not called.
#   CS7-CS8   resume re-seizes and the queue is still there
#   CS9       ending after the round trip still plots the ORIGINAL queue, unshortened
#   DS1       `e` with nothing selected, mode live: the pick arms AND the seize lets go,
#             so the pick can actually receive the click it is waiting for
#   DS2       ESC during the pick: arm dropped, mode BACK, queue intact  (the new C arm)
#   DS3       click on empty space during the pick: same terminal, mode back
#   DS4       click on the instance, dialog bails: mode back
#   DS5       a REAL descend: mode live on the descended canvas, queue intact
#   DS7       THE USER'S GESTURE, through real Tk events: press E on the canvas, then
#             click. Everything above enters below the keyboard; this group does not.
#             DS7e records the canvas-focus limitation as a fact, not a bug.
#   DS6       the hard case: descend into a NEW WINDOW, mode re-homes there
#   MS1-MS11  the armed pick against the other owners of the left button (issue 0257)
#   DS8       a STACK of two modes across that descend: the Results window's pick mode
#             seized over Select On Design. Both come up in the new window in the order
#             they were in, real ESC ends them from the top down, and both canvases are
#             left as the editor has them. A second pass (DS8j on) takes the same stack
#             through a descend in the SAME window, where both modes come back up on
#             the one canvas
#   DS9       a mode ENDED while the descend has the stack paused: its end writes
#             nothing on the canvas, the click the descend waits for still reaches it,
#             and the mode that is left comes back alone
#
# MUST run under X (no --nogui; `xschem callback` needs Tk):
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_cmdmode_descend_0201.tcl
# or, gated:
#   tests/headless/run_suites.sh test_cmdmode_descend_0201
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; xschem callback dispatch)"; flush stdout; exit 0 }

# The per-process scratch directory used further down, and the watchdog that ends the
# process if a wait in the event loop never returns.
source [file join [file dirname [file normalize [info script]]] scratch.tcl]

# ⚠ WAIT FOR THE CANVAS TO BE MAPPED, and assert it (FX0) — do not merely hope.
# `update idletasks` runs idle handlers and processes NO X EVENTS AT ALL, so the
# MapNotify/ConfigureNotify that give .drw its real size are still sitting in the
# queue when it returns. Under Xvfb the map has always already happened by the
# time a --script runs; under WSLg it frequently has NOT, and .drw is still 1x1
# with ismapped 0 when the script starts.
#
# ⚠ THE RATE IS NOT FIXED -- do not read a single number here and call the race
# fiction when you fail to reproduce it. It tracks the state of the WSLg
# compositor, and three independent measurements on :0 on 2026-08-15 disagree by
# more than an order of magnitude, all of them correct: 1 red run in 31 on a
# quiet, freshly-started display; 1 cold launch in 4 (the first xschem after the
# compositor had been idle, 85 iterations / ~3.9 s to settle, the other three 0);
# and 6 launches in 8 needing 22-34 iterations (~0.6-0.9 s) after a session of
# heavy GUI testing had restarted Xwayland a few times. Concurrent GUI work on :0
# pushes it up hard. On a warm, quiet display the loop below is a 0-iteration
# no-op, which is exactly what it should cost when the canvas is already there.
#
# Everything downstream of an unmapped canvas is nonsense: `xschem zoom_full` fits the
# drawing into one pixel (zoom 1834 against 1.83 on a mapped canvas), so sx/sy
# compute (0,0) for every point and every click lands on the corner instead of on
# the instance, and `focus -force .drw` cannot take on an unmapped window, so
# DS7's REAL <Key-e> goes nowhere. Measured cost of one such launch: 9 red checks
# — and, far worse, 80 checks that still printed `ok:` against a canvas that was
# never there, which is red-but-hollow's mirror image.
#
# So the map is WAITED for with real `update`s, and then ASSERTED at FX0 below: a
# launch whose canvas never maps must go red at one named check rather than green
# 80 times. This is the class-(a) WSLg-traffic pattern of test_calc_skeleton S12 —
# force the race in the test; do not chase window managers, and do not let an
# environment decide whether the file measures anything.
for {set _i 0} {$_i < 200} {incr _i} {
  if {[winfo ismapped .drw] && [winfo width .drw] > 1 && [winfo height .drw] > 1} break
  update ; after 25
}
update idletasks
focus -force .drw
update idletasks

set ::fails 0
set ::npass 0
# A failing line ends in the shape the regression driver counts, so a red names its
# row in the verdict and not only in the case log.
proc check {name got want} {
  if {$got eq $want} {
    incr ::npass
    puts "ok:   $name (got $got want $want)"
  } else {
    incr ::fails
    puts "FAIL: $name (got $got want $want) : FAIL"
  }
  flush stdout
}

# FX0 — the fixture's own precondition, stated as a check because every row below
# is silently vacuous without it (see the wait loop above).
check "FX0 the canvas is mapped and really sized before anything is measured" \
  [list [winfo ismapped .drw] [expr {[winfo width .drw] > 1 && [winfo height .drw] > 1}]] \
  [list 1 1]

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set BP 4 ; set BR 5 ; set KEY 2
set Button1Mask 256
set MENUSTART      65536
set MENUSTARTDESC  32768
set XK_Escape      65307

proc sx {u} { expr {int(($u + [xschem get xorigin]) / [xschem get zoom])} }
proc sy {v} { expr {int(($v + [xschem get yorigin]) / [xschem get zoom])} }
proc press   {ux uy} { xschem callback .drw $::BP [sx $ux] [sy $uy] 0 1 0 0; update idletasks }
proc release {ux uy} { xschem callback .drw $::BR [sx $ux] [sy $uy] 0 1 0 $::Button1Mask; update idletasks }
proc click   {ux uy} { press $ux $uy; release $ux $uy; update idletasks }
proc esc     {} { xschem callback .drw $::KEY 0 0 $::XK_Escape 0 0 0; update idletasks }
proc armed   {} { expr {([xschem get ui_state] & $::MENUSTART) && ([xschem get ui_state2] & $::MENUSTARTDESC) ? 1 : 0} }

proc seized {} { expr {[string match "*ase::ui::sod_click*" [bind .drw <ButtonPress-1>]] ? 1 : 0} }
# Every sod() reader is absence-tolerant on purpose: under sabotage (or a real regression)
# the records are GONE, and a leg that throws would abort the file before the RESULT
# banner -- turning a precise red leg into an unreadable NORESULT.
proc qval  {f} { if {[info exists ::ase::ui::sod(K,$f)]} { return $::ase::ui::sod(K,$f) } ; return {} }
proc sod_active   {} { if {[info exists ::ase::ui::sod(active)]} { return $::ase::ui::sod(active) } ; return {} }
proc suspended_flag {} { expr {[info exists ::ase::ui::sod(K,suspended)] ? 1 : 0} }
# What the mode reports it holds (the list cmdmode reads), absence-tolerant like the
# readers above: a build without the proc answers one word saying so.
proc held_now {} { if {[catch {ase::ui::sod_held} h]} { return [list RAISED:$h] } ; return $h }

# Observe the descend resolution, and choose per-leg whether the dialog can be built.
#
# With ::use_real_views 0 the enum returns no rows, so hi_descend_dialog_body takes its
# "no views" bail -- a terminal, therefore a RESUME site (R2), which is the path DS4 and
# DS7 check. Legs that need a REAL descend (DS5, DS6) set the flag; they address the
# instance with `hi_descend inst=...`, which routes to hi_descend_do and never opens the
# chooser. A flag rather than renaming back and forth: the rename dance is what made an
# earlier draft of DS7 hang forever on the modal's `grab` + `tkwait`.
rename hi_descend_enum_views hi_descend_enum_views_real
set ::use_real_views 0
proc hi_descend_enum_views {instname} {
  set ::resolved $instname
  if {$::use_real_views} { return [hi_descend_enum_views_real $instname] }
  return {}
}

# dp_finish is the FINISH half of sod_end. Stub it so a suspend that wrongly plotted is
# visible (CS6) and so the real end at CS9 needs no simulation results, no viewer and no
# session behind it.
rename ase::ui::dp_finish ase::ui::dp_finish_real
proc ase::ui::dp_finish {key queue {qcolors {}}} { set ::plotted $queue; incr ::nplot }
set ::plotted {} ; set ::nplot 0 ; set ::resolved {}

set ::TOPSCH [file normalize [file join [file dirname [info script]] .. .. xschem_library examples 0_examples_top.sch]]
xschem load $::TOPSCH
xschem zoom_full; update idletasks

set INST {}
foreach {i s t} [xschem instance_list] { if {$t eq {subcircuit}} { set INST $i; break } }
if {$INST eq {}} { puts "RESULT: SKIP (no subcircuit instance in the fixture)"; flush stdout; exit 0 }
lassign [lindex [split [xschem instance_bbox $INST] "\n"] 0] _ bx1 by1 bx2 by2
set CX [expr {($bx1+$bx2)/2.0}] ; set CY [expr {($by1+$by2)/2.0}]

# The predecessors the seize must hand back, captured before anything arms.
set PRE_P [bind .drw <ButtonPress-1>]
set PRE_R [bind .drw <ButtonRelease-1>]
set PRE_E [bind .drw <Key-Escape>]
# ... and the further slots the mode takes: the double click, which the canvas
# binds itself (set_bindings: the editor's double click) and which Tk would otherwise
# hand the second press of a double click to; the canvas's destruction; and the motion
# with the left button held, which would otherwise start the editor's selection
# rectangle under a pick.
set PRE_D [bind .drw <Double-Button-1>]
set PRE_X [bind .drw <Destroy>]
set PRE_M [bind .drw <B1-Motion>]

# Arm a real Direct-Plot-flavour mode with two traces already queued. do_raise 0 skips
# ase::ui::design_window, so no ASE session window has to exist -- the mode under test is
# the CANVAS seize, and that part is session-free.
proc arm_sod {} {
  catch {ase::ui::sod_end K}
  array unset ::ase::ui::sod K,*
  unset -nocomplain ::ase::ui::sod(active)
  ase::ui::select_on_design K {save 0 plot 1} plot 0
  set ::ase::ui::sod(K,queue)   {v(alpha) v(beta)}
  set ::ase::ui::sod(K,qcolors) {4 5}
  set ::ase::ui::sod(K,count)   2
  set ::plotted {} ; set ::nplot 0 ; set ::resolved {}
  update idletasks
}

# --- CS1..CS9: the ASE arms, on their own -------------------------------------
arm_sod
check "CS1a select_on_design seized Button-1"        [seized] 1
check "CS1b and it is the active mode"               [sod_active] K
check "CS1c the double click is seized with the press's own script, over the editor's" \
  [list [string match {xschem callback %W -3 *} $PRE_D] [expr {[bind .drw <Double-Button-1>] eq [bind .drw <ButtonPress-1>]}]] [list 1 1]
check "CS1d and the canvas carries the mode's hook for its own destruction" \
  [bind .drw <Destroy>] [list ase::ui::sod_canvas_gone K %W]
check "CS1e and swallows the motion with the left button held" \
  [bind .drw <B1-Motion>] break
check "CS1f the mode reports every slot it holds on this canvas to cmdmode: one group per slot, each naming .drw and the script that slot holds" \
  [lmap {c s o p} [held_now] { expr {$c eq {.drw} && $s ne {} && [bind .drw $s] eq $o ? $s : "WRONG:$c $s"} }] \
  {<ButtonPress-1> <Double-Button-1> <ButtonRelease-1> <B1-Motion> <Key-Escape> <Destroy>}
check "CS2 suspend_all released exactly one mode"    [cmdmode::suspend_all] 1
check "CS2b and a suspended mode reports that it holds nothing" [held_now] {}

check "CS3a ButtonPress-1 handed back verbatim"      [bind .drw <ButtonPress-1>]   $PRE_P
check "CS3b ButtonRelease-1 handed back verbatim"    [bind .drw <ButtonRelease-1>] $PRE_R
check "CS3c Key-Escape handed back verbatim"         [bind .drw <Key-Escape>]      $PRE_E
check "CS3e Double-Button-1 handed back verbatim"    [bind .drw <Double-Button-1>] $PRE_D
check "CS3f Destroy handed back verbatim"            [bind .drw <Destroy>]         $PRE_X
check "CS3g B1-Motion handed back verbatim"          [bind .drw <B1-Motion>]       $PRE_M
check "CS3d so nothing is seized"                    [seized] 0

check "CS4a the queue survived"                      [qval queue]   {v(alpha) v(beta)}
check "CS4b the colours survived"                    [qval qcolors] {4 5}
check "CS4c the count survived"                      [qval count]   2
check "CS4d the flavour/mode survived"               [qval mode]    plot
check "CS5a still the active mode while suspended"   [sod_active] K
check "CS5b and marked suspended"                    [suspended_flag] 1
check "CS6 THE POINT: a suspend does not plot"       $::nplot 0

check "CS7a resume_all put it back"                  [cmdmode::resume_all .drw] 1
check "CS7b Button-1 is seized again"                [seized] 1
check "CS7c and the double click with it"            [expr {[bind .drw <Double-Button-1>] eq [bind .drw <ButtonPress-1>]}] 1
check "CS7d and the motion with the button held"     [bind .drw <B1-Motion>] break
check "CS8a the queue is still there after resume"   [qval queue] {v(alpha) v(beta)}
check "CS8b the count is unreset"                    [qval count] 2
check "CS8c the suspended mark is gone"              [suspended_flag] 0

ase::ui::sod_end K
update idletasks
check "CS9a ending after the round trip plots once"  $::nplot 1
check "CS9b and plots the WHOLE original queue"      $::plotted {v(alpha) v(beta)}
check "CS9c the canvas is clean afterwards"          [bind .drw <ButtonPress-1>] $PRE_P
check "CS9d the double click is the editor's again, no destroy hook is left, and the held motion is as it was" \
  [list [bind .drw <Double-Button-1>] [bind .drw <Destroy>] [bind .drw <B1-Motion>]] [list $PRE_D $PRE_X $PRE_M]

# --- DS1: the verb-noun descend has to make room for its own click ------------
arm_sod
xschem unselect_all
set r [hi_descend]
check "DS1a hi_descend armed the pick"               [list $r [armed]] [list 1 1]
check "DS1b THE POINT: the seize let go, so the pick can receive the click" [seized] 0
check "DS1c the interrupted command is suspended"    [cmdmode::is_suspended] 1
check "DS1d suspended, not ended -- nothing plotted" $::nplot 0
check "DS1e and its queue is untouched"              [qval queue] {v(alpha) v(beta)}

# --- DS2: ESC during the pick (the arm that had NO Tcl continuation) ----------
esc
check "DS2a ESC dropped the pick"                    [armed] 0
check "DS2b the suspension is over"                  [cmdmode::is_suspended] 0
check "DS2c the mode is seized again"                [seized] 1
check "DS2d with its queue intact"                   [qval queue] {v(alpha) v(beta)}
check "DS2e and it still has not plotted"            $::nplot 0
check "DS2f no stale MENUSTARTDESCEND left behind"   [expr {[xschem get ui_state2] & $::MENUSTARTDESC}] 0

# --- DS3: the armed click lands on empty space -------------------------------
arm_sod
xschem unselect_all
hi_descend
check "DS3a armed and suspended"                     [list [armed] [cmdmode::is_suspended]] [list 1 1]
click -99999 -99999
check "DS3b the pick cancelled"                      [armed] 0
check "DS3c the mode came back"                      [list [cmdmode::is_suspended] [seized]] [list 0 1]
check "DS3d queue intact"                            [qval queue] {v(alpha) v(beta)}
check "DS3e nothing plotted"                         $::nplot 0

# --- DS4: the armed click lands on the instance, and the dialog then bails ----
arm_sod
xschem unselect_all
hi_descend
click $CX $CY
update idletasks ; update            ;# let hi_descend_pick_done's `after idle` run
check "DS4a the click resolved the instance"         $::resolved $INST
check "DS4b the dialog bail resumed the command"     [cmdmode::is_suspended] 0
check "DS4c the mode is live again"                  [seized] 1
check "DS4d queue intact across the whole round trip" [qval queue] {v(alpha) v(beta)}
check "DS4e the pick never selected anything"        [list [xschem selected_set] [xschem get lastsel]] [list {} 0]
check "DS4f still not plotted"                       $::nplot 0

# --- DS5: a REAL descend, with the mode live ---------------------------------
set ::use_real_views 1
arm_sod
xschem unselect_all
set ok [hi_descend inst=$INST target=current mode=readonly]
update idletasks
check "DS5a the descend happened"                    [list $ok [expr {[xschem get currsch] > 0}]] [list 1 1]
check "DS5b the command is live again, not suspended" [cmdmode::is_suspended] 0
check "DS5c and re-seized on the descended canvas"   [seized] 1
check "DS5d D2: on the canvas that is current NOW"   [qval canvas] [xschem get current_win_path]
check "DS5e the queue crossed the descend intact"    [qval queue] {v(alpha) v(beta)}
check "DS5f nothing was plotted on the way"          $::nplot 0

# a click while descended still queues, and 0161 qualifies its name -- the mode is not
# merely re-bound, it is functional in the new context
set before [llength [qval queue]]
check "DS5g the resumed seize is a working binding"  [expr {[string match "*sod_click K*" [bind .drw <ButtonPress-1>]] ? 1 : 0}] 1
check "DS5h count untouched by the descend"          [qval count] 2

ase::ui::sod_end K
update idletasks
check "DS5i the end after a descend still plots all of it" $::plotted {v(alpha) v(beta)}

# --- DS7: the user's actual gesture, through REAL Tk events -------------------
# Every leg above calls `hi_descend` as a proc and delivers clicks with `xschem callback`,
# i.e. it enters the chain BELOW the keyboard. That leaves the thing the user actually
# does untested: press the E key on the canvas, then click. This group uses
# `event generate`, so it goes through the real Tk binding installed by set_bindings
# (`bind .drw <Key-e>`) and through the real <ButtonPress-1> slot -- which is exactly the
# slot the interrupted mode was holding. If the suspend did not happen, DS7c's click is
# eaten by sod_click and nothing is ever resolved.
#
# DS7e records a real limitation rather than a bug: the E binding lives on the CANVAS, so
# it only fires while the canvas holds keyboard focus. select_on_design does `focus $cv`
# at arm time for this reason; clicking away into another window after arming parks the
# focus elsewhere and E goes nowhere. Pre-existing, not introduced here.
set ::use_real_views 0
while {[xschem get currsch] > 0} { xschem go_back }
update idletasks
arm_sod
xschem unselect_all
check "DS7a the mode is seized before the keypress"  [seized] 1
event generate .drw <Key-e>
update idletasks
check "DS7b a REAL E keypress armed the pick"        [armed] 1
check "DS7b2 and suspended the command"              [cmdmode::is_suspended] 1
check "DS7b3 so Button-1 is free for the pick"       [seized] 0
event generate .drw <ButtonPress-1>   -x [sx $CX] -y [sy $CY]
event generate .drw <ButtonRelease-1> -x [sx $CX] -y [sy $CY]
update idletasks ; update
check "DS7c a REAL click named the instance"         $::resolved $INST
check "DS7d the mode came back, queue intact"        [list [seized] [qval queue]] [list 1 {v(alpha) v(beta)}]
check "DS7d2 and the pick selected nothing"          [list [xschem selected_set] [xschem get lastsel]] [list {} 0]
check "DS7d3 nothing was plotted"                    $::nplot 0

focus -force .
update idletasks
set ::resolved {}
event generate .drw <Key-e>
update idletasks
check "DS7e KNOWN LIMIT: E does nothing without canvas focus" [armed] 0
focus -force .drw
update idletasks

# --- DS6: the hard case -- descend into a NEW WINDOW --------------------------
# This is the leg the issue called "a genuinely different operation from leave it alone":
# the mode was seized on the PARENT canvas, and the context the user is now looking at is
# a different Tk widget entirely. D2 says resume there, which means resume_all must read
# current_win_path AFTER the navigation and sod_resume must re-capture its predecessors
# on the canvas it is landing on.
#
# DS6d is the load-bearing one, and it is why suspending BEFORE the window is created
# matters: xinit.c runs clone_canvas_bindings .drw <new> at creation, which copies `.drw`'s
# bindings verbatim. Had the seize still been up, the child would have inherited a COPY of
# it -- with the parent's key already substituted -- and its sod_end would restore
# bindings on the parent only, leaving the child permanently seized with dead scripts.
proc seized_on {cv} { expr {[string match "*ase::ui::sod_click*" [bind $cv <ButtonPress-1>]] ? 1 : 0} }
set ::use_real_views 1
while {[xschem get currsch] > 0} { xschem go_back }
update idletasks
arm_sod
xschem unselect_all
set nwok [hi_descend inst=$INST target=new_window mode=readonly]
update idletasks ; update
set NEW [xschem get current_win_path]
check "DS6a the new-window descend succeeded"        $nwok 1
check "DS6b a different canvas is current now"       [expr {$NEW ne {.drw}}] 1
check "DS6c D2: the mode re-homed onto the NEW canvas" [qval canvas] $NEW
check "DS6d THE POINT: seized there, and NOT left seized on the parent" \
  [list [seized_on $NEW] [seized_on .drw]] [list 1 0]
check "DS6e the queue crossed the window hop"        [qval queue] {v(alpha) v(beta)}
check "DS6f the count crossed it too"                [qval count] 2
check "DS6g nothing was plotted on the way"          $::nplot 0
check "DS6h the suspension is over"                  [cmdmode::is_suspended] 0
# The predecessors are read from the canvas the mode LANDS on. For the double click that
# matters twice: the new canvas has its own editor binding (set_bindings ran on it), and
# the parent must have the editor's back -- a second press of a double click on either
# window must not go to a mode that is not there, nor to the editor where the mode is.
check "DS6i the double click is seized on the NEW canvas, and is the editor's again on the parent" \
  [list [expr {[bind $NEW <Double-Button-1>] eq [bind $NEW <ButtonPress-1>]}] [bind .drw <Double-Button-1>]] [list 1 $PRE_D]
check "DS6k the held motion is swallowed on the NEW canvas, and is as it was on the parent" \
  [list [bind $NEW <B1-Motion>] [bind .drw <B1-Motion>]] [list break $PRE_M]
ase::ui::sod_end K
update idletasks
check "DS6j ending the mode there hands the NEW canvas its own bindings back: nothing on the press, the editor's double click, no destroy hook, nothing on the held motion" \
  [list [seized_on $NEW] [bind $NEW <ButtonPress-1>] [string match {xschem callback %W -3 *} [bind $NEW <Double-Button-1>]] [bind $NEW <Destroy>] [bind $NEW <B1-Motion>]] \
  [list 0 {} 1 {} {}]
# That window is closed by its name. `xschem new_schematic destroy_all`, with the tabbed
# interface on, takes a real window's schematic away and leaves its toplevel standing,
# and the next window made would be built over the old one (leg DS8 needs a new one).
if {$NEW ne {.drw}} { catch {xschem new_schematic destroy $NEW {}} ; update }

# --- MS1..MS11: the armed pick vs. whoever else owns Button-1 (issue 0257) ----
# Everything above interrupts an ASE mode, which SUSPENDS its binding and hands
# Button-1 back. Three OTHER Button-1 owners cannot be suspended, because they are
# not Tcl bindings at all -- they are resting ui_state bits that handle_button_press()
# dispatches with a `return` BEFORE the single check_menu_start_commands() call site:
# NET_HILIGHT, NET_UNHILIGHT and DESEL_MODE. A fourth is `last_command` under
# `persistent_command`, which is tested one step earlier still.
#
# Measured under xvfb 2026-08-10, BEFORE the fix: arming the pick inside net-highlight
# mode left the press resolving NOTHING; the matching ButtonRelease then cleared
# MENUSTART while leaving MENUSTARTDESCEND set -- a combination no reader tests, since
# both the pick arm and the ESC continuation were guarded on the conjunction -- so ESC
# fell through to the blanket `ui_state = 0`, hi_descend_pick_cancel never fired and
# cmdmode::is_suspended stayed 1 for the rest of the session. With a resting wire
# command it was worse than swallowed: callback.c called start_wire(), so the press
# meant as "descend into this instance" BEGAN A WIRE DRAW on it.
#
# The fix gates at the VERB (`xschem descend_pick`, scheduler.c), per the ratified
# rules: "whatever you just pressed is what you meant" and "gates live at the VERBS,
# never at the shared per-click primitive". It abandons the competing owner and NAMES
# it in the prompt (issue 0241). ESC's continuation now reads MENUSTARTDESCEND ALONE,
# so a STRANDED arm (MENUSTART already burned by a release) can still be redeemed.
#
# Own fixture copy: MS9 starts a wire draw on the sheet, and a set_modify(1) on the
# COMMITTED example would write 0_examples_top~.sch into the repo.
# A directory of this process alone (tests/headless/scratch.tcl), so two runs at
# once never share the copy; it is removed when the suite exits.
set MSWORK [test_scratch ms_descend_gate]
file copy -force $::TOPSCH $MSWORK/ms_top.sch

set ::use_real_views 0
catch {ase::ui::sod_end K}
catch {xschem new_schematic destroy_all force}
catch {xschem new_schematic switch .drw}
while {[xschem get currsch] > 0} { xschem go_back }
proc ms_reload {} {
  global MSWORK
  xschem load $MSWORK/ms_top.sch
  xschem zoom_full
  xschem unselect_all
  set ::resolved {}
  update idletasks
}
proc modebits {} { expr {[xschem get ui_state] & (1048576 | 2097152 | 4194304)} }
proc descarm {} { expr {[xschem get ui_state2] & $::MENUSTARTDESC} }

ms_reload
lassign [lindex [split [xschem instance_bbox $INST] "\n"] 0] _ bx1 by1 bx2 by2
set CX [expr {($bx1+$bx2)/2.0}] ; set CY [expr {($by1+$by2)/2.0}]

# MS1-MS6: the NET_HILIGHT leg, end to end.
ms_reload
xschem hilight_net_interactive
check "MS1 net-highlight mode is really live before the verb" [expr {[xschem get ui_state] & 1048576}] 1048576
set r [hi_descend]
check "MS2 hi_descend armed the pick AND ended the mode"  [list $r [armed] [modebits]] [list 1 1 0]
check "MS3 the arm NAMES what it tore down, held"         [list [xschem get statusmsg] [xschem get statusmsg_hold]] \
  [list {Descend: net-highlight mode ended -- click the instance to descend into (ESC to cancel)} 1]
click $CX $CY
update idletasks ; update
check "MS4 THE POINT: the armed click resolves the instance instead of being swallowed" \
  [list $::resolved [armed]] [list $INST 0]
check "MS5 no MENUSTARTDESCEND residue after the click"   [descarm] 0
check "MS6 command mode came back (it used to stay suspended forever)" [cmdmode::is_suspended] 0

# MS7: deselect-one-at-a-time. It is entered ON a selection, and hi_descend only arms a
# pick when nothing is selected -- so the mode's own click empties the selection first,
# which is exactly the state a user is in mid-deselect.
ms_reload
xschem select instance $INST fast
xschem deselect_mode
check "MS7a deselect mode is live"                        [expr {[xschem get ui_state] & 4194304}] 4194304
click $CX $CY
set ::resolved {}
set r [hi_descend]
check "MS7b the arm ended deselect mode and named it"     [list $r [armed] [modebits] [xschem get statusmsg]] \
  [list 1 1 0 {Descend: deselect mode ended -- click the instance to descend into (ESC to cancel)}]
click $CX $CY
update idletasks ; update
check "MS7c and the pick resolved"                        [list $::resolved [armed] [cmdmode::is_suspended]] [list $INST 0 0]

# MS8: net-UNhighlight, the third door.
ms_reload
xschem unhilight_net_interactive
check "MS8a net-unhighlight mode is live"                 [expr {[xschem get ui_state] & 2097152}] 2097152
set r [hi_descend]
check "MS8b the arm ended it and named it"                [list $r [armed] [modebits] [xschem get statusmsg]] \
  [list 1 1 0 {Descend: net-unhighlight mode ended -- click the instance to descend into (ESC to cancel)}]
click $CX $CY
update idletasks ; update
check "MS8c and the pick resolved"                        [list $::resolved [armed]] [list $INST 0]

# MS9: THE MUTATING SWALLOW. A resting wire command under persistent_command: ui_state
# has no STARTWIRE, no band is up, but last_command still owns the next click and the
# press handler calls start_wire() before anything else is offered it.
ms_reload
set persistent_command 1
xschem wire gui
click 3000 3000                      ;# first point: the draw is now live
esc                                  ;# two-stage ESC: band gone, last_command still armed
check "MS9a setup: a RESTING wire command owns the next click" \
  [list [expr {[xschem get ui_state] & 1}] [xschem get last_command]] [list 0 1]
set w0 [xschem get wires]
set ::resolved {}
set r [hi_descend]
check "MS9b the arm abandoned the wire command and said so" \
  [list $r [armed] [xschem get last_command] [expr {[xschem get ui_state] & 1}] [xschem get statusmsg]] \
  [list 1 1 0 0 {Descend: in-progress wire abandoned -- click the instance to descend into (ESC to cancel)}]
click $CX $CY
update idletasks ; update
check "MS9c the press DESCENDS instead of starting a wire, and commits no copper" \
  [list $::resolved [xschem get wires]] [list $INST $w0]
set persistent_command 0

# MS10: the no-teardown regression guard. With nothing to tear down the prompt must be
# byte-identical to the sentence this verb has always spoken.
ms_reload
set r [hi_descend]
check "MS10 nothing torn down -> the shipped prompt, unchanged" \
  [list $r [xschem get statusmsg] [xschem get statusmsg_hold]] \
  [list 1 {Descend: click the instance to descend into (ESC to cancel)} 1]

# MS11: ESC redeems a STRANDED arm. A bare ButtonRelease (the tail of a press some other
# owner swallowed) burns MENUSTART and leaves MENUSTARTDESCEND set with MENUSTART clear.
# The ESC continuation reads the discriminator alone, so it can still fire.
check "MS11a setup: the arm from MS10 is live (both words set)" \
  [list [expr {[xschem get ui_state] & $::MENUSTART}] [descarm]] [list $::MENUSTART $::MENUSTARTDESC]
release $CX $CY
check "MS11b MENUSTART burned, MENUSTARTDESCEND stranded" \
  [list [expr {[xschem get ui_state] & $::MENUSTART}] [descarm] [cmdmode::is_suspended]] \
  [list 0 $::MENUSTARTDESC 1]
esc
check "MS11c ESC redeems it: arm dropped and command mode resumed" \
  [list [descarm] [cmdmode::is_suspended]] [list 0 0]

# --- DS8: a STACK of two modes across a descend into a new window ---------------
# The Results window's pick mode (its key 1 with nothing selected; `rdw::key annotation`
# is what that key runs) is seized OVER Select On Design: it keeps Select On Design's
# scripts as what the canvas held before. Each mode hands back what it took, so the
# descend has to release the upper mode first (cmdmode::release_order, src/cmdmode.tcl).
# Released the other way round, the first canvas is left on Select On Design's scripts
# with every mode paused, the new window is cloned from it in that state, and the two
# modes come back in the new window upside down over those scripts: after both are ended
# neither window takes a left click.
#
# Read here from the canvases themselves: the whole binding table of each, against the
# table it had with no mode up (for the new window: the table a descend made with no
# mode up gave it), the order two REAL Escape presses end the modes in, and one REAL
# left click on a device in each window afterwards. The sheet in the first window is
# this suite's scratch copy; the sheet descended into is opened read-only.
proc btable {cv} {
  set o {}
  foreach q [lsort [bind $cv]] { lappend o [list $q [bind $cv $q]] }
  return [string map [list [winfo toplevel $cv] .TOP] $o]
}
proc rdw_up {} { if {[catch {rdw::pick_running} r]} { return "RAISED:$r" } ; return $r }
proc rdw_val {f} { if {[info exists ::rdw::pick($f)]} { return $::rdw::pick($f) } ; return {} }
# whose press script canvas `cv` holds: the Results window's, Select On Design's, or neither
proc press_of {cv} {
  set p [bind $cv <ButtonPress-1>]
  if {[string match {*rdw::pick_click*} $p]} { return rdw }
  if {[string match {*ase::ui::sod_click*} $p]} { return sod }
  return [expr {$p eq {} ? {none} : {other}}]
}
# A device of the current sheet whose middle the engine reads as that device (and not as
# a wire or a text lying across it), with that middle; empty when there is none.
proc dev_pick {} {
  foreach {name sym type} [xschem instance_list] {
    if {[catch {lassign [lindex [split [xschem instance_bbox $name] "\n"] 0] _ x1 y1 x2 y2}]} { continue }
    if {$x2 eq {}} { continue }
    set u [expr {($x1 + $x2) / 2.0}] ; set v [expr {($y1 + $y2) / 2.0}]
    set o [xschem object_at $u $v]
    if {[lindex $o 0] eq {instance} && [xschem getprop instance [lindex $o 1] name] eq $name} {
      return [list $name $u $v]
    }
  }
  return {}
}
# One REAL left click at schematic point (u,v) of the window whose canvas is `cv`.
# Answers the device the engine reads under the pointer once it has been moved there,
# and what is selected after the click; the selection is cleared again. The event queue
# is drained before the motion: a layout event still waiting would put its own position
# into the engine's pointer pair after it (issue 1659).
set ::ds8_t 900000
proc dev_click {cv u v} {
  xschem new_schematic switch $cv
  update
  xschem unselect_all
  set px [sx $u] ; set py [sy $v]
  update
  event generate $cv <Motion> -x $px -y $py
  update
  set o [xschem object_at [xschem get mousex] [xschem get mousey]]
  set under {}
  if {[lindex $o 0] eq {instance}} { set under [xschem getprop instance [lindex $o 1] name] }
  incr ::ds8_t 5000
  event generate $cv <ButtonPress-1>   -x $px -y $py -time $::ds8_t
  event generate $cv <ButtonRelease-1> -x $px -y $py -time [expr {$::ds8_t + 60}] -state $::Button1Mask
  update
  set sel [lrange [xschem selected_set] 0 end]
  xschem unselect_all
  return [list $under $sel]
}
# One REAL Escape on canvas `cv`, which is given the keyboard first (a key goes to the
# window that has it).
proc real_esc {cv} {
  for {set i 0} {$i < 40} {incr i} {
    focus -force $cv ; update
    if {[focus -displayof $cv] eq $cv} { break }
    after 25
  }
  event generate $cv <Key-Escape>
  update
}
# Wait until the canvas of a new window is mapped and sized, then fit the sheet in it:
# the window's own first zoom is put off until then.
proc settle_canvas {cv} {
  for {set i 0} {$i < 200} {incr i} {
    update
    if {[winfo ismapped $cv] && [winfo width $cv] > 1 && [winfo height $cv] > 1} { break }
    after 25
  }
  xschem new_schematic switch $cv
  xschem zoom_full
  update
}

# the toplevels beside the main window that carry a schematic canvas
proc extra_tops {} {
  set o {}
  foreach w [winfo children .] { if {[winfo exists $w.drw]} { lappend o $w } }
  return $o
}

set ::use_real_views 1
catch {ase::ui::sod_end K}
catch {rdw::pick_end}
catch {xschem new_schematic switch .drw}
ms_reload
set LEFT [extra_tops]
set T_FIRST [btable .drw]
set D_FIRST [dev_pick]

# the control: the same descend with no mode up
set ctl_ok [hi_descend inst=$INST target=new_window mode=readonly]
update idletasks ; update
set CTL [xschem get current_win_path]
set T_CTL {} ; set D_NEW {}
if {$CTL ne {.drw}} {
  settle_canvas $CTL
  set T_CTL [btable $CTL]
  set D_NEW [dev_pick]
  xschem new_schematic destroy $CTL {}
  update
}
xschem new_schematic switch .drw
update
check "DS8a fixture: no window of an earlier leg is left, a descend with no mode up makes a new canvas with bindings of its own, each sheet has a device to click, and closing that window leaves the first canvas as it was" \
  [list $LEFT $ctl_ok [expr {$CTL ne {.drw}}] [expr {[llength $T_CTL] > 0}] [expr {[llength $D_FIRST] == 3}] \
        [expr {[llength $D_NEW] == 3}] [expr {[btable .drw] eq $T_FIRST}] [extra_tops]] [list {} 1 1 1 1 1 1 {}]

arm_sod
xschem unselect_all
catch {rdw::key annotation}
update idletasks
check "DS8b both modes are up on the first canvas, the Results window's seized over Select On Design" \
  [list [sod_active] [rdw_up] [press_of .drw] [expr {[rdw_val prevpress] ne {} && [rdw_val prevpress] eq [lindex [held_now] 2]}]] \
  [list K 1 rdw 1]

set nwok [hi_descend inst=$INST target=new_window mode=readonly]
update idletasks ; update
set NEW [xschem get current_win_path]
check "DS8c the descend made a new window, both modes are on its canvas and nothing is left suspended" \
  [list $nwok [expr {$NEW ne {.drw}}] [expr {[qval canvas] eq $NEW}] [expr {[rdw_val canvas] eq $NEW}] [cmdmode::is_suspended]] \
  [list 1 1 1 1 0]
check "DS8d THE POINT: the first canvas is left exactly as it was with no mode up" \
  [expr {[btable .drw] eq $T_FIRST}] 1
check "DS8e and in the new window the two are stacked as they were: the Results window's mode over Select On Design, over what that canvas has of its own" \
  [list [press_of $NEW] [expr {[rdw_val prevpress] ne {} && [rdw_val prevpress] eq [lindex [held_now] 2]}] [qval prevpress]] \
  [list rdw 1 {}]

if {$NEW ne {.drw}} { settle_canvas $NEW }
real_esc $NEW
check "DS8f the first real Escape there ends the mode on top, the Results window's, and leaves Select On Design up with its queue" \
  [list [rdw_up] [sod_active] [press_of $NEW] [qval queue] $::nplot] [list 0 K sod {v(alpha) v(beta)} 0]
real_esc $NEW
check "DS8g the second ends Select On Design, which plots what it had queued" \
  [list [sod_active] $::nplot $::plotted] [list {} 1 {v(alpha) v(beta)}]
check "DS8h after both, the new canvas has the bindings a window made with no mode up has, and the first canvas the ones it started with" \
  [list [expr {[btable $NEW] eq $T_CTL}] [expr {[btable .drw] eq $T_FIRST}]] [list 1 1]
set c_new {} ; set c_first {}
if {[llength $D_NEW] == 3 && $NEW ne {.drw}}  { set c_new   [dev_click $NEW {*}[lrange $D_NEW 1 2]] }
if {[llength $D_FIRST] == 3}                  { set c_first [dev_click .drw {*}[lrange $D_FIRST 1 2]] }
check "DS8i and a real left click on a device selects it, in the new window and in the first" \
  [list $c_new $c_first] \
  [list [list [lindex $D_NEW 0] [list [lindex $D_NEW 0]]] [list [lindex $D_FIRST 0] [list [lindex $D_FIRST 0]]]]

catch {rdw::pick_end}
catch {ase::ui::sod_end K}
if {$NEW ne {.drw}} { catch {xschem new_schematic destroy $NEW {}} ; update }
catch {xschem new_schematic switch .drw}

# --- DS8, second pass: the same stack across a descend in the SAME window --------
# No window is made here and nothing is cloned: the two modes are put down on the first
# canvas and come back up on it, with the sheet changed underneath. The order they are
# released in decides what that one canvas holds afterwards. Released lower mode first,
# Select On Design comes back on top of the Results window's mode, which keeps Select
# On Design's old scripts as what the canvas had before; the first Escape then ends
# Select On Design, the second leaves the canvas on those old scripts, and it takes no
# left click.
#
# The control comes first: the same descend with no mode up, for the binding table the
# canvas has on the sheet landed on and for a device of that sheet to click.
ms_reload
set ctl2_ok [hi_descend inst=$INST target=current mode=readonly]
update idletasks ; update
set ctl2_down [expr {[xschem get currsch] > 0}]
settle_canvas .drw
set T_DOWN [btable .drw]
set D_DOWN [dev_pick]
for {set i 0} {$i < 8 && [xschem get currsch] > 0} {incr i} { xschem go_back }
update
set P_FREE [bind .drw <ButtonPress-1>]
check "DS8j fixture: a descend in the same window with no mode up makes no window and leaves the canvas's bindings as they were, the sheet landed on has a device to click, and back on the first sheet no mode is up and nothing is suspended" \
  [list $ctl2_ok $ctl2_down [expr {$T_DOWN eq $T_FIRST}] [expr {[llength $D_DOWN] == 3}] [expr {[btable .drw] eq $T_FIRST}] \
        [extra_tops] [xschem get currsch] [sod_active] [rdw_up] [cmdmode::is_suspended]] [list 1 1 1 1 1 {} 0 {} 0 0]

arm_sod
xschem unselect_all
catch {rdw::key annotation}
update idletasks
check "DS8k both modes are up on the first canvas again, the Results window's seized over Select On Design" \
  [list [sod_active] [rdw_up] [press_of .drw] [expr {[rdw_val prevpress] ne {} && [rdw_val prevpress] eq [lindex [held_now] 2]}]] \
  [list K 1 rdw 1]

set swok [hi_descend inst=$INST target=current mode=readonly]
update idletasks ; update
check "DS8l the descend happened in the same window: no window was made, both modes are on the first canvas and nothing is left suspended" \
  [list $swok [expr {[xschem get currsch] > 0}] [xschem get current_win_path] [extra_tops] [qval canvas] [rdw_val canvas] [cmdmode::is_suspended]] \
  [list 1 1 .drw {} .drw .drw 0]
check "DS8m THE POINT: on that canvas the two are stacked as they were: the Results window's mode over Select On Design, and Select On Design, which has a press script on record as what was there before, over the one the canvas has with no mode up" \
  [list [press_of .drw] [expr {[rdw_val prevpress] ne {} && [rdw_val prevpress] eq [lindex [held_now] 2]}] \
        [info exists ::ase::ui::sod(K,prevpress)] [expr {[qval prevpress] eq $P_FREE}]] \
  [list rdw 1 1 1]

settle_canvas .drw
real_esc .drw
check "DS8n the first real Escape ends the mode on top, the Results window's, and leaves Select On Design up with its queue" \
  [list [rdw_up] [sod_active] [press_of .drw] [qval queue] $::nplot] [list 0 K sod {v(alpha) v(beta)} 0]
real_esc .drw
check "DS8o the second ends Select On Design, which plots what it had queued" \
  [list [sod_active] $::nplot $::plotted] [list {} 1 {v(alpha) v(beta)}]
check "DS8p after both, the canvas has the bindings it has with no mode up" \
  [expr {[btable .drw] eq $T_FIRST}] 1
set c_down {}
if {[llength $D_DOWN] == 3} { set c_down [dev_click .drw {*}[lrange $D_DOWN 1 2]] }
check "DS8q and a real left click on a device of the sheet landed on selects it" \
  $c_down [list [lindex $D_DOWN 0] [list [lindex $D_DOWN 0]]]

catch {rdw::pick_end}
catch {ase::ui::sod_end K}
for {set i 0} {$i < 8 && [xschem get currsch] > 0} {incr i} { xschem go_back }

# --- DS9: a mode ENDED while the descend has the stack paused --------------------
# The bare descend (the E key with nothing selected) pauses every mode and waits in the
# event loop for a click on an instance. Each paused mode has handed the canvas back by
# then, and still has on record what the canvas held when it took it: for the upper mode
# of a stack that is the lower mode's scripts. A mode can be ended during that wait -- the
# Results window's by Escape in its own window, Select On Design by being entered again
# -- and an end that wrote that record back a second time would put the scripts of the
# OTHER mode, which is paused, on the canvas: the click the descend waits for would be
# that mode's, and nothing would descend. The release of a paused mode writes nothing
# (rdw::pick_release, ase::ui::sod_release).
#
# Two orders, each ended from the top of its stack, where the record is the other mode's
# scripts. Everything the hand does is a real event: the E key, Escape in the Results
# window, the click on the instance, Escape on the canvas. The chooser the click leads to
# finds no views here (the suite's stand-in for the view list), which is one of the
# descend's own ends: it resumes the modes in place.
#
# One REAL key press on window `w`, which is given the keyboard first.
proc real_key {w key} {
  for {set i 0} {$i < 40} {incr i} {
    focus -force $w ; update
    if {[focus -displayof $w] eq $w} { break }
    after 25
  }
  event generate $w $key
  update
}
# One REAL left click on the instance the suite descends into, with nothing moved first:
# the press carries its own position.
proc inst_click {} {
  event generate .drw <ButtonPress-1>   -x [sx $::CX] -y [sy $::CY]
  event generate .drw <ButtonRelease-1> -x [sx $::CX] -y [sy $::CY]
  update idletasks ; update
}
proc rdw_paused {} { expr {[info exists ::rdw::pick(suspended)] ? 1 : 0} }
# the timers waiting to write the Results window's sentence on the status slot
proc hint_timers {} {
  set n 0
  foreach id [after info] { if {[string match *rdw::_hint_pump* [after info $id]]} { incr n } }
  return $n
}
# what the status slot of the first window says, without the blanks around it
proc slot_says {} { if {[catch {.statusbar.10 cget -text} t]} { return "RAISED:$t" } ; return [string trim $t] }
# the canvas's bindings against the ones it has with no mode up: that phrase, or whose
# press script it holds
proc canvas_now {} { expr {[btable .drw] eq $::T_FIRST ? {as with no mode up} : "press is [press_of .drw]"} }

# Put everything back by hand, whatever a leg left: an armed descend is dropped (which
# resumes what it paused), both modes are ended, and every binding of the canvas is
# written as it was when this band began. Run between the two orders and after the
# second, so that each order's rows are red for what that order did and nothing else.
proc ds9_clean {} {
  catch {esc}
  catch {cmdmode::resume_all}
  catch {rdw::pick_end}
  catch {ase::ui::sod_end K}
  foreach q [bind .drw] { if {![dict exists $::RAW9 $q]} { catch {bind .drw $q {}} } }
  dict for {q scr} $::RAW9 { catch {bind .drw $q $scr} }
  catch {xschem unselect_all}
  update
}

set ::use_real_views 0
ms_reload
set ::RAW9 [dict create]
foreach q [bind .drw] { dict set ::RAW9 $q [bind .drw $q] }
catch {rdw::open}
update
set RDW_PANE .rdw
foreach c {.rdw.p.t .rdw.t} { if {[winfo exists $c]} { set RDW_PANE $c ; break } }

# the Results window's mode over Select On Design, and that mode ended
arm_sod
xschem unselect_all
catch {rdw::key annotation}
update idletasks
set up9 [list [sod_active] [rdw_up] [press_of .drw]]
real_key .drw <Key-e>
update idletasks
check "DS9a fixture: with the Results window's mode seized over Select On Design, a REAL E key with nothing selected arms the descend's pick and pauses both: both are still on record and marked paused, cmdmode holds both to put back, Select On Design first, and the canvas has the bindings it has with no mode up; the Results window is open, so its Escape can be pressed" \
  [list $up9 [armed] [cmdmode::is_suspended] [cmdmode::pending] [sod_active] [suspended_flag] [rdw_up] [rdw_paused] [canvas_now] [winfo exists .rdw]] \
  [list {K 1 rdw} 1 1 {ase_sod rdw_pick} K 1 1 1 {as with no mode up} 1]
real_key $RDW_PANE <Key-Escape>
check "DS9b THE POINT: a REAL Escape in the Results window during that wait ends its mode and writes nothing on the canvas: the canvas still has the bindings it has with no mode up, not Select On Design's scripts; Select On Design is still paused with its queue, the descend still waits, cmdmode still holds both names, no timer of the Results window's sentence is left and the status slot does not show it" \
  [list [rdw_up] [canvas_now] [sod_active] [suspended_flag] [qval queue] [armed] [cmdmode::is_suspended] [cmdmode::pending] [hint_timers] [slot_says] $::nplot] \
  [list 0 {as with no mode up} K 1 {v(alpha) v(beta)} 1 1 {ase_sod rdw_pick} 0 {} 0]
set ::resolved {}
inst_click
check "DS9c so the REAL click on the instance is the descend's: it names the instance, the chooser finds no views and the descend ends there, which puts back what was paused -- Select On Design alone, on the canvas, over what the canvas has with no mode up, its queue intact and nothing plotted; the mode that was ended stays ended and nothing is left paused" \
  [list $::resolved [armed] [cmdmode::is_suspended] [cmdmode::pending] [sod_active] [suspended_flag] [press_of .drw] \
        [expr {[qval prevpress] eq $PRE_P}] [qval queue] $::nplot [rdw_up]] \
  [list $INST 0 0 {} K 0 sod 1 {v(alpha) v(beta)} 0 0]
real_esc .drw
set c9 {}
if {[llength $D_FIRST] == 3} { set c9 [dev_click .drw {*}[lrange $D_FIRST 1 2]] }
check "DS9d and ONE real Escape on the canvas ends Select On Design, which plots what it had queued: the canvas has the bindings it has with no mode up, and a real left click on a device selects it" \
  [list [sod_active] $::nplot $::plotted [canvas_now] $c9] \
  [list {} 1 {v(alpha) v(beta)} {as with no mode up} [list [lindex $D_FIRST 0] [list [lindex $D_FIRST 0]]]]

# Select On Design over the Results window's mode, and Select On Design entered again
ds9_clean
catch {rdw::key annotation}
update idletasks
arm_sod
set rdwpress9 {}
catch {set rdwpress9 [lindex [rdw::pick_held] 2]}
set under9 [expr {$rdwpress9 ne {} && [qval prevpress] eq $rdwpress9 ? {the Results window's} : [qval prevpress]}]
set up9 [list [sod_active] [rdw_up] [press_of .drw] $under9]
xschem unselect_all
real_key .drw <Key-e>
update idletasks
check "DS9e fixture, the other order: Select On Design seized over the Results window's mode, whose press script it has on record as what the canvas held, and a REAL E key pauses both: cmdmode holds both to put back, the Results window's mode first, and the canvas has the bindings it has with no mode up" \
  [list $up9 [armed] [cmdmode::is_suspended] [cmdmode::pending] [suspended_flag] [rdw_paused] [canvas_now]] \
  [list {K 1 sod {the Results window's}} 1 1 {rdw_pick ase_sod} 1 1 {as with no mode up}]
set ::plotted {} ; set ::nplot 0
ase::ui::select_on_design K {save 0 plot 1} plot 0
update idletasks
check "DS9f Select On Design ENTERED AGAIN during that wait, by the call its key makes: the paused one is ended, which plots what it had queued, and the new one takes the canvas -- up, not paused, the press script its own, and what it has on record as the canvas's own is what the canvas has with no mode up, not the Results window's scripts; that mode is still paused and the descend still waits" \
  [list $::nplot $::plotted [sod_active] [suspended_flag] [press_of .drw] \
        [list [expr {[qval prevpress] eq $PRE_P}] [expr {[qval prevrel] eq $PRE_R}] [expr {[qval prevesc] eq $PRE_E}] \
              [expr {[qval prevdbl] eq $PRE_D}] [expr {[qval prevmotion] eq $PRE_M}] [expr {[qval prevdestroy] eq $PRE_X}]] \
        [rdw_up] [rdw_paused] [armed] [cmdmode::is_suspended]] \
  [list 1 {v(alpha) v(beta)} K 0 sod {1 1 1 1 1 1} 1 1 1 1]
real_esc .drw
check "DS9g a REAL Escape on the canvas ends the new one and leaves the canvas with the bindings it has with no mode up, not the scripts of the paused mode; the descend still waits" \
  [list [sod_active] [canvas_now] [rdw_up] [rdw_paused] [armed] [cmdmode::is_suspended]] \
  [list {} {as with no mode up} 1 1 1 1]
set ::resolved {}
inst_click
check "DS9h the REAL click on the instance is then the descend's, and its end puts the Results window's mode back alone: on the canvas, over what the canvas has with no mode up, nothing left paused and no Select On Design" \
  [list $::resolved [armed] [cmdmode::is_suspended] [rdw_up] [rdw_paused] [press_of .drw] [expr {[rdw_val prevpress] eq $PRE_P}] [sod_active]] \
  [list $INST 0 0 1 0 rdw 1 {}]
real_esc .drw
set c9 {}
if {[llength $D_FIRST] == 3} { set c9 [dev_click .drw {*}[lrange $D_FIRST 1 2]] }
check "DS9i ONE real Escape ends it: no mode is up, the canvas has the bindings it has with no mode up, and a real left click on a device selects it" \
  [list [rdw_up] [sod_active] [canvas_now] $c9] \
  [list 0 {} {as with no mode up} [list [lindex $D_FIRST 0] [list [lindex $D_FIRST 0]]]]

ds9_clean
catch {rdw::close}
catch {destroy .rdw}
update

file delete -force $MSWORK

# The completion sentinel tests/banner_rule.tcl's banner_complete requires of a
# registered case, printed only when every check passed. The verdict line stays
# last: the regression driver carries a case's last verdict line into its block.
if {!$::fails} { puts "OVERALL: ok ($::npass checks)" }
puts [expr {$::fails ? "RESULT: $::fails FAILED ($::npass passed)" : "RESULT: ALL PASS ($::npass checks)"}]
flush stdout
exit 0
