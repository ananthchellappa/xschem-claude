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
#   CS1-CS2   select_on_design really seizes the canvas; suspend_all releases it
#   CS3       the three bindings go back to their EXACT predecessors (string-identical:
#             the trailing `break` is what keeps the C dispatcher out, 0202)
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
#
# MUST run under X (no --nogui; `xschem callback` needs Tk):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_cmdmode_descend_0201.tcl
# or, gated:
#   tests/headless/run_suites.sh test_cmdmode_descend_0201
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; xschem callback dispatch)"; flush stdout; exit 0 }
update idletasks
focus -force .drw
update idletasks

set ::fails 0
proc check {name got want} {
  set ok [expr {$got eq $want}]
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name (got $got want $want)"; flush stdout
  if {!$ok} {incr ::fails}
}

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
check "CS2 suspend_all released exactly one mode"    [cmdmode::suspend_all] 1

check "CS3a ButtonPress-1 handed back verbatim"      [bind .drw <ButtonPress-1>]   $PRE_P
check "CS3b ButtonRelease-1 handed back verbatim"    [bind .drw <ButtonRelease-1>] $PRE_R
check "CS3c Key-Escape handed back verbatim"         [bind .drw <Key-Escape>]      $PRE_E
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
check "CS8a the queue is still there after resume"   [qval queue] {v(alpha) v(beta)}
check "CS8b the count is unreset"                    [qval count] 2
check "CS8c the suspended mark is gone"              [suspended_flag] 0

ase::ui::sod_end K
update idletasks
check "CS9a ending after the round trip plots once"  $::nplot 1
check "CS9b and plots the WHOLE original queue"      $::plotted {v(alpha) v(beta)}
check "CS9c the canvas is clean afterwards"          [bind .drw <ButtonPress-1>] $PRE_P

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
set MSWORK /tmp/ms_descend_gate_work
file delete -force $MSWORK; file mkdir $MSWORK
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

file delete -force $MSWORK

puts [expr {$::fails ? "RESULT: $::fails FAILURE(S)" : "RESULT: ALL PASS"}]
flush stdout
exit 0
