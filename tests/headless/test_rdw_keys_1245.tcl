# ############################################################################
# ITEM B4-2 — WHAT THIS FILE IS, AND WHAT IT COST TO GET HERE
# ############################################################################
# This suite is item B4's, restored by item B4-2 together with the production
# half of doc/claude/op_param_batch/B4_working_tree_REVERTED.patch, and grown
# by eight rows for the five things B4's adversary refuted. THE WHOLE PATCH IS
# NOW IN THE TREE and the five fixes sit on top of it; the handoff notice that
# used to stand here (the src half reverted, the test half applied) described a
# state that no longer exists.
#
# THE EIGHT ROWS, AND WHAT EACH ONE MEASURED AGAINST B4's OWN UNFIXED CODE:
#   F1  the focus race, first-of-session   -> focus landed on .rdw and a real
#       ESC never reached the canvas: got {0 0 1 1 1 1 1} exp {0 0 1 1 1 0 0}
#   F2  the invisible dump (hole 4)        -> GREEN against B4's code, because
#       B4's rdw::show does open first. It is the missing FENCE, and it reds
#       under the hole: with `rdw::open` replaced by a no-op inside rdw::show
#       it gave {0 1 0 0 0 1} exp {0 1 1 1 1 1} -- .rdw absent, no pane, the
#       device named nowhere on screen, and the STORE still holding its block.
#       Every other dump row in both suites reads the store, which is why
#       deleting the open used to red nothing.
#   C1  the filed 1303 pair, literally     -> GREEN against B4's code. It is
#       the control that makes C2 non-vacuous, not a red.
#   C2  the pick's DEFAULT path (1303)     -> named the SNAPPED device:
#       got {1 0 1 0 1} exp {1 0 1 1 0}
#   V2b the 1304 drag                      -> selection changed, lastsel 2,
#       rubber band still alive after the release AND after a real ESC:
#       got {0 1 0 2 1 0 1 1 0 1 0} exp {0 1 1 0 0 1 0 1 0 1 0}
#   V6  the fourth slot, taken             -> got 0 for "the seize took
#       <B1-Motion>" (leg 2)
#   D1  the fourth slot, re-latched on the canvas the descend LANDS on -> 0
#   S1  the fourth slot, handed back       -> green before the fix, vacuously:
#       the predecessor is the empty string and B4 never took the slot at all.
#
# ⚠ THE LESSON THIS FILE EXISTS TO CARRY: a suite fences the questions its
# author thought of. B4's OWN row V8 was written for the focus race and PASSED
# while the race was live, because the rows before it had already mapped .rdw
# and a window manager grants map-time focus ONCE. Ordering inside a suite is
# part of the fixture. Sections F and C therefore run BEFORE every other row in
# this file and each asserts its own precondition as a LEG.
#
# ⚠ NEVER `git checkout --` / `git restore` / `git stash` / `git clean` this
# file or its sibling to make some patch apply: they hold work that is in no
# patch, and destroying uncommitted work that way cost an earlier agent in this
# batch ~99 verified lines. Reverse a src-half apply with
#     git apply -R --include='src/*' doc/claude/op_param_batch/B4_working_tree_REVERTED.patch
# ############################################################################

# tests/headless/test_rdw_keys_1245.tcl — item B4 of
# doc/claude/op_param_batch/PLAN.md (feature 1245, the Results Display Window):
# THE KEYS AND THE TWO GRAMMARS.
#
# Ruling D-2, the user's own choice: the RDW takes bare 1 / 2 / 3 / 4 IN THE
# CADENCE PROFILE ONLY. Stock xschem keeps logic_set. Rulings DD-1 and DD-5 (as
# corrected) reach this item through rdw::dump, which already renders both.
#
# ============================================================================
# WHY THIS IS A SEPARATE FILE FROM test_rdw_window_1245.tcl
# ============================================================================
# src/cadence_style_rc CANNOT BE SOURCED UNDER --nogui. It dies at its first
# `bind` (line 129) with `invalid command name "bind"`, so every binding row,
# every command-mode row and every `event generate` row is :99-only. B3's suite
# runs its majority on BOTH arms and PLAN records that split as load-bearing —
# measured, each arm catches a defect the other passes. Putting the keys in
# there would have killed the headless arm. So: the noun-verb grammar's pure
# and context halves, and every new proc that needs no Tk, went into B3's suite
# as section K on BOTH arms; the BINDINGS, the COMMAND MODE, the PICK and the
# DESCEND live here, on :99 only.
#
#   display :  GUI_GATE=0 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_rdw_keys_1245.tcl
# ⚠ Never a bare `./src/xschem --script` (it inherits $DISPLAY, the user's real
# Windows X server) and never a bare `xschem` on PATH (3.4.6, issue 0924).
# full_audit.sh selects by GLOB and is NOT edited; this file joins none of its
# three named lists, so it runs on the display arm. The denominator moves
# 381 -> 382: diff the baseline BY NAME, never by count.
#
# ============================================================================
# THE CONTRACT THIS FILE FENCES — the procs item B4 must add to src/rdw.tcl
# ============================================================================
#   rdw::key <kind>          kind is annotation | summary | all | refresh.
#                            The first three drive rdw::set_list (B3's ONE
#                            list-identity setter) and then branch on the
#                            selection; `refresh` leaves the list alone and
#                            trims the store to the newest block.
#   rdw::_selected_instance  -> a two element list, one of
#                              `none {}` / `one <name>` / `many {}` /
#                              `notinst {}`
#   rdw::show <instname>     open the window, rdw::dump, hand focus back
#   rdw::pick_start          arm the command mode; 1 if armed, 0 if it could not
#   rdw::pick_click ?x? ?y?  resolve ONE click, coordinates defaulting to
#                            mousex_snap / mousey_snap; the mode STAYS LIVE
#   rdw::pick_release        hand the three bindings back; 1 if it released one
#   rdw::pick_end            leave the mode
#   rdw::pick_suspend        cmdmode arm; 1 only if it released a LIVE mode
#   rdw::pick_resume <cv>    cmdmode arm; re-latch on the canvas it LANDS on
#   rdw::_refresh_pick_gate  the ONE named wrapper for update_all_sym_bboxes
#   rdw::_pick_at <x> <y>    the ONE named wrapper for `xschem instance_at`
#   rdw::keep_latest         key 4: trim ::rdw::blocks to the newest block
#   rdw::_ciw <msg>          the ONE refusal channel
#   and, at SOURCE time (safe: cmdmode.tcl is pure Tcl and is sourced BEFORE
#   rdw.tcl, exactly as ase_window.tcl:2055 already does),
#     cmdmode::register rdw_pick rdw::pick_suspend rdw::pick_resume
#
# ============================================================================
# THE FOUR MEASUREMENTS THIS FILE IS BUILT ON. ALL RE-RUN 2026-09-04, AT HEAD
# 735ea26e, ON THIS BINARY. NONE IS TRANSCRIBED FROM A PLAN.
# ============================================================================
# 1. THE DISPLACED VERB IS OBSERVABLE, AND WITHOUT A SPY IT IS NOT.
#    callback.c:7440 runs logic_set() for a bare 0-4 and hilight.c:2505 is its
#    FIRST statement: tclsetvar("tclstop", "0"). So setting ::tclstop to a
#    sentinel, pressing the key and reading it back says whether the C verb ran.
#    Measured with cadence_style_rc sourced and no bind in the way: bare 1, 2, 3
#    and 4 each set ::tclstop to 0. `logic_set` is C and is NOT reachable by a
#    Tcl rename, so this is the only spy there is.
# 2. THE ALT-CHORD VACUITY TRAP. `event generate .drw <Alt-Key-2>` produces
#    Tk's VIRTUAL Alt bit (131072), not Mod1Mask, and never reaches the C
#    dispatcher: measured, it scored ZERO hits on a renamed alt2_toggle_view
#    with NOTHING bound in its way. `-state 8` scored one. A guard row written
#    the first way passes while the guard is absent.
# 3. THE CTRL COLLATERAL IS ONLY REAL FOR 1 AND 3. From rectcolor 7: Ctrl-1
#    -> 1, Ctrl-2 -> unchanged, Ctrl-3 -> 3, Ctrl-4 -> unchanged. Ctrl-2 and
#    Ctrl-4 never reach C because cadence_style_rc:256 and :268 already own
#    them (make_editable, ase::direct_plot_for_current).
# 4. THE PICK GATE REALLY GOES STALE, and this file reproduces it rather than
#    citing it. On the fixture below, with the OP annotated and mask 9 set
#    THROUGH `xschem set annot_show`: refresh -> M1's box is 277.5 -340
#    354.587 -280; `xschem raw clear` leaves that box UNCHANGED while the text
#    comes back on screen, so a click at 213.75 -310 answers the EMPTY STRING
#    over visible text; ONE `xschem update_all_sym_bboxes` widens the box to
#    150 -380 496.5 -232.869 and the same click answers M1. That is issue 1266
#    driven in reverse, live at HEAD, and it is row P1.
#    ⚠ The point is COMPUTED from `xschem instance_bbox` at run time, never
#    transcribed: item A3's own numbers moved once already.
#
# ============================================================================
# WHAT IS RED BEFORE B4, AND WHY EACH ONE IS RED
# ============================================================================
# Measured against the unmodified tree: `bind .drw <Key-1>` .. `<Key-4>` are
# the EMPTY STRING both before AND after sourcing src/cadence_style_rc, while
# <Key-6> and <Key-9> in the same file are not — so the file loads and it is
# exactly these four keys that are unbound. src/rdw.tcl contains zero `bind`,
# zero `cmdmode`, zero `instance_at` and zero `update_all_sym_bboxes`, and
# `cmdmode::registered` answers `ase_sod` alone.
#   GREEN BEFORE THE CHANGE — controls and today's-behaviour rows, evidence
#   for NOTHING about B4; each says only that B4 broke nothing:
#     FX0   the canvas is mapped (without it every row below is vacuous)
#     B1    the CONTROL half: the four binds are empty BEFORE the source
#     B3    Ctrl-1 / Ctrl-3 still select a drawing layer
#     B4    Ctrl-2 still makes the view editable, Ctrl-4 still enters ASE
#     B5    Alt-2 still runs view.toggle_view_type
#     S1    hygiene, and the event-delivery control
#   B3, B4 and B5 are the rows a GREEDY bind kills, so they are green now and
#   must STAY green: they are the fence around the collateral, not the feature.
#   EVERYTHING ELSE IS RED: the four binds, the mode, the pick, the refresh
#   and the descend round trip do not exist.

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; canvas bindings and real key events)"; flush stdout; exit 0 }

# ⚠ WAIT FOR THE CANVAS TO BE MAPPED, and assert it at FX0 — do not merely hope.
# Copied from test_cmdmode_descend_0201.tcl:76. `update idletasks` processes NO
# X events at all, so the MapNotify that gives .drw its real size can still be
# in the queue when a --script starts. Everything downstream of an unmapped
# canvas is nonsense: zoom_full fits the drawing into one pixel, every sx/sy
# computes 0 and every synthesised click lands on the corner.
for {set _kx 0} {$_kx < 200} {incr _kx} {
  if {[winfo ismapped .drw] && [winfo width .drw] > 1 && [winfo height .drw] > 1} break
  update ; after 25
}
update idletasks
focus -force .drw
update idletasks

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch rdw_keys_1245]
set ::netlist_dir $scratch
set KX_RC [file join $repo src cadence_style_rc]

## Taken BEFORE anything can write a file (hygiene row S1).
set S1_ROOT0 [lsort [glob -nocomplain -directory $repo -tails untitled*]]

check {FX0 the canvas is mapped and really sized before anything is measured - every row below is silently vacuous without it} \
  [list [winfo ismapped .drw] [expr {[winfo width .drw] > 1 && [winfo height .drw] > 1 ? 1 : 0}]] \
  {1 1}

# ============================================================================
# THE ANSWER DISCIPLINE — AN ABSENT MODE MUST NEVER SATISFY A ROW
# ============================================================================
# Same two rules as B3's suite. A bare call to a proc that does not exist
# raises, and a raise at global level under --pipe stops Tcl_AppInit DEAD: the
# file dies mid-run with `ok` lines and NO verdict. Every call below goes
# through a wrapper, and "invalid command name ..." must not be able to satisfy
# a row expecting the empty string.
proc kx_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc kx_bad {v} { return [expr {$v eq {NOPROC} || [string match {RAISED:*} $v] ? 1 : 0}] }
proc kx_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return $b
}
proc kx_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd ; return $d
}
proc kx_has {hay needle} { return [expr {[string first $needle $hay] >= 0 ? 1 : 0}] }
proc kx_oneline {s} { return [expr {[string first "\n" $s] < 0 && [string trim $s] ne {} ? 1 : 0}] }

## Screen coordinates from user coordinates. THERE ARE TWO MOUSE PAIRS on this
## binary and the difference is issue 1303's whole subject: `xschem get mousex`
## / `mousey` answer the UN-SNAPPED point the cursor is on (scheduler.c:5047,
## :5051) and the `_snap` pair answers it rounded to the grid (:5055, :5059).
## The pick must read the first; section C measures what the second costs.
proc sx {u} { expr {int(($u + [xschem get xorigin]) / [xschem get zoom])} }
proc sy {v} { expr {int(($v + [xschem get yorigin]) / [xschem get zoom])} }
## The pick's own seize, as a predicate. `.drw` is a FRAME whose shipped
## bindings are the GENERIC <Button> and <Key>, so <ButtonPress-1> is the empty
## string until something takes it — measured.
proc seized {{cv .drw}} { expr {[string match {*rdw::pick_click*} [bind $cv <ButtonPress-1>]] ? 1 : 0} }
## The two things the user's own requirement is read through. `xschem selection`
## and not `selected_set`: selected_set filters to instances, so a wire, a text
## or a pin the pick wrongly selected would be INVISIBLE to it — and it is
## hand-brace-wrapped, so `llength` on it throws for a name holding an
## unbalanced brace (issue 0388).
proc kx_sel {} { return [xschem selection] }
## The Instance: half of `xschem instance_bbox`, as four numbers.
proc kx_ibox {n} {
  set r {} ; catch {set r [xschem instance_bbox $n]}
  if {[regexp {Instance:\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $r -> a b c d]} { return [list $a $b $c $d] }
  return NO-BBOX
}
proc kx_centre {n} {
  set b [kx_ibox $n]
  if {$b eq {NO-BBOX}} { return {0 0} }
  return [list [expr {([lindex $b 0]+[lindex $b 2])/2.0}] [expr {([lindex $b 1]+[lindex $b 3])/2.0}]]
}
## A real mouse click through the seized binding, the way the user's hand does
## it. <Motion> FIRST so mousex_snap updates before the press — without it the
## pick reads the previous point and every "the click picked X" leg is a lie
## about a click that landed somewhere else (test_sod_pick_no_select_0204 SO11).
proc kx_click {ux uy {cv .drw}} {
  event generate $cv <Motion>          -x [sx $ux] -y [sy $uy] -when now
  update
  event generate $cv <ButtonPress-1>   -x [sx $ux] -y [sy $uy] -when now
  event generate $cv <ButtonRelease-1> -x [sx $ux] -y [sy $uy] -when now
  update
}


# ============================================================================
# THE SHARED HELPERS SECTIONS F AND C NEED — MOVED UP, MECHANICALLY
# ============================================================================
# ⚠ THESE FIVE USED TO SIT BELOW THE FIXTURE, WHICH IS BELOW SECTION B, AND
# NOTHING ABOUT THEM CHANGED. Sections F and C must run before the fixture
# region (it sets library_registry_defs_only 1 and a restricted library.defs,
# under which cmos_inv.sch's bare nmos4.sym / res.sym stop resolving) and
# before ANYTHING maps .rdw (row F1's entire subject is the FIRST map of a
# session). So the helpers they share came up with them.

## THE REFUSAL CHANNEL, OBSERVED. ciw_echo is DEFINED headless and on a
## widget-less display and silently does nothing, so a row that did not stub it
## would assert nothing at all (the rename idiom is
## test_sod_pick_no_select_0204.tcl:139).
set ::KX_CIW {}
if {[llength [info commands ciw_echo]]} { rename ciw_echo kx_ciw_echo_real }
proc ciw_echo {msg args} { lappend ::KX_CIW $msg }

## The store, emptied between rows, and the newest block's header line.
proc kx_reset {} {
  set ::rdw::blocks {}
  set ::KX_CIW {}
  catch {xschem unselect_all}
}
proc kx_top_hdr {} {
  if {![info exists ::rdw::blocks] || ![llength $::rdw::blocks]} { return NO-BLOCK }
  return [lindex [lindex [lindex $::rdw::blocks 0] 0] 1]
}
proc kx_nblocks {} {
  if {![info exists ::rdw::blocks]} { return -1 }
  return [llength $::rdw::blocks]
}
## ⚠ NOT `expr {[info exists v] ? $v : {NO-VAR}}`. The list identity is a WORD,
## and expr evaluates a bare word as an operand: `annotation` raises
## "invalid bareword". Measured while writing this file.
proc kx_listkind {} {
  if {![info exists ::rdw::listkind]} { return NO-VAR }
  return $::rdw::listkind
}

# ---------------------------------------------------------------------------
# THE SCREEN-PIXEL TWINS, AND THE DRAG
# ---------------------------------------------------------------------------
# ⚠ ROW C2 CANNOT USE kx_click, AND THAT IS THE MEASUREMENT, NOT A PREFERENCE.
# `sx`/`sy` round to an integer pixel, so driving the filed point 175.175
# -199.612 through them lands at 175.17526 -200.82845 -- a DIFFERENT point,
# which happens to resolve to the same device. The straddling pixel C2 needs is
# therefore searched for in SCREEN space and clicked in SCREEN space, and the
# two user-space answers are read back from `xschem get` afterwards.
proc ux {p} { expr {$p * [xschem get zoom] - [xschem get xorigin]} }
proc uy {p} { expr {$p * [xschem get zoom] - [xschem get yorigin]} }
proc kx_click_px {px py {cv .drw}} {
  event generate $cv <Motion>          -x $px -y $py -when now
  update
  event generate $cv <ButtonPress-1>   -x $px -y $py -when now
  event generate $cv <ButtonRelease-1> -x $px -y $py -when now
  update
}
## A PRESS, EIGHT MOTIONS WITH BUTTON 1 HELD, A RELEASE. `-state 256` is
## Button1Mask and is what makes C's motion handler take the rubber-band arm
## (callback.c:7250-7260); a motion without it is an ordinary hover. This is
## the gesture issue 1304 is about and no other row in either suite makes it.
proc kx_drag_px {px0 py0 px1 py1 {steps 8} {cv .drw}} {
  event generate $cv <Motion>        -x $px0 -y $py0 -when now
  update
  event generate $cv <ButtonPress-1> -x $px0 -y $py0 -when now
  update
  for {set i 1} {$i <= $steps} {incr i} {
    event generate $cv <Motion> -state 256 \
      -x [expr {int($px0 + ($px1 - $px0) * $i / double($steps))}] \
      -y [expr {int($py0 + ($py1 - $py0) * $i / double($steps))}] -when now
    update
  }
  event generate $cv <ButtonRelease-1> -x $px1 -y $py1 -when now
  update
}

# ============================================================================
# THE SHIPPED-SHEET FIXTURE FOR SECTIONS F AND C
# ============================================================================
# ⚠ THE SHIPPED cmos_inv.sch, ON THE DEFAULT LIBRARY PATH, AND BEFORE THE
# SUITE'S OWN FIXTURE. Issue 1303's measurement was taken on this sheet and no
# other, and it is carried here LITERALLY (row C1) rather than paraphrased onto
# a private fixture: the two numbers are one pixel apart and a rebuilt sheet
# would not reproduce them. It also cannot be loaded later -- the fixture
# region below sets library_registry_defs_only 1, under which this sheet's bare
# `nmos4.sym` and `res.sym` do not resolve at all.
set FC_SCH [file join $repo xschem_library examples cmos_inv.sch]
xschem load $FC_SCH
xschem zoom_full
update idletasks
## The pick gate is a CACHE (issues 1260, 1266 and item A3). Refresh it once
## here so section C's own numbers are about snapping and not about staleness;
## rdw::_refresh_pick_gate is what does it per pick, and section P is that row.
catch {xschem update_all_sym_bboxes}
xschem unselect_all

# ============================================================================
# SECTION F — THE FIRST DUMP OF A SESSION, AND THE DUMP THAT IS INVISIBLE
# ============================================================================
# TWO HOLES B4 SHIPPED, NEITHER OF WHICH ANY ROW IN EITHER SUITE COULD SEE.
#
# F1, THE FOCUS RACE. rdw::open ends its raise branch in `focus .rdw` and the
# command mode's Escape lives on the CANVAS, so a dump that leaves the keyboard
# on the results toplevel leaves a mode the user cannot escape. B4's row V8 was
# written for exactly this and PASSED, because V2 .. V7 had already mapped .rdw
# several times over and the WM's map-time focus grant -- the thing that
# actually wins the race -- only happens on the FIRST map. Ordering inside a
# suite is part of the fixture: this row therefore runs BEFORE any other row in
# this file can open the window, and it asserts that state as its own first leg
# rather than inheriting it.
#
# F2, THE INVISIBLE DUMP. Deleting `rdw::open` from `rdw::show` reds NOTHING in
# either suite, while making the first press of a session put a block in the
# store and NOTHING on screen. It reds nothing because every existing dump row
# reads the STORE (::rdw::blocks, via kx_top_hdr / k_top_hdr) and rdw::render_pane
# early-returns when .rdw.p.t does not exist. So F2 reads the PANE.

kx_reset
catch {destroy .rdw}
update idletasks
set F1_PRE0 [expr {[winfo exists .rdw] ? 1 : 0}]
set F1_ARM [kx_ans ::rdw::key annotation]
update idletasks
set F1_SEIZED [seized]
## The first click of the session, and therefore the first map of .rdw.
lassign [kx_centre M1] F1X F1Y
kx_click $F1X $F1Y
## A BOUNDED PUMP, NOT A BARE `update`. The WM's focus grant arrives on a
## MapNotify round trip, which `update idletasks` does not process at all --
## measured: [focus] reads .drw at that instant and .rdw one `update` later.
for {set _f 0} {$_f < 20} {incr _f} { update ; after 25 }
set F1_MAPPED [expr {[winfo exists .rdw] ? 1 : 0}]
set F1_NB [expr {[kx_nblocks] >= 1 ? 1 : 0}]
set F1_FOCUS [focus]
set F1_ONRDW [expr {[string match {.rdw*} $F1_FOCUS] ? 1 : 0}]
## ESC delivered to WHATEVER HOLDS FOCUS -- the only delivery that can tell the
## two states apart. Sending it to .drw would pass with the race live.
set F1_TARGET [expr {$F1_FOCUS eq {} ? {.} : $F1_FOCUS}]
catch {event generate $F1_TARGET <Key-Escape> -when now}
update
check {F1 THE FIRST DUMP OF A SESSION: with .rdw never yet mapped - asserted, not assumed - a click that opens it must leave the keyboard on the CANVAS, so a real ESC delivered to whatever holds focus still ends the mode. B4's V8 tested this and passed because the window was already mapped by the time it ran} \
  [list $F1_PRE0 [kx_bad $F1_ARM] $F1_SEIZED $F1_MAPPED $F1_NB $F1_ONRDW [seized]] \
  {0 0 1 1 1 0 0}

kx_ans ::rdw::pick_end
kx_reset
catch {destroy .rdw}
update idletasks
set F2_PRE0 [expr {[winfo exists .rdw] ? 1 : 0}]
xschem unselect_all
xschem select instance M1
set F2_LASTSEL [xschem get lastsel]
kx_ans ::rdw::key annotation
update idletasks
set F2_PANE [expr {[winfo exists .rdw.p.t] ? [.rdw.p.t get 1.0 end] : {NO-PANE}}]
xschem unselect_all
check {F2 THE DUMP MUST REACH THE PANE, NOT ONLY THE STORE: with .rdw destroyed first, one instance selected and the key pressed, the window exists, the text pane exists, and the pane's own text names the device - every other dump row in both suites reads ::rdw::blocks, which is why deleting rdw::open from rdw::show reds nothing} \
  [list $F2_PRE0 $F2_LASTSEL [expr {[winfo exists .rdw] ? 1 : 0}] \
        [expr {[winfo exists .rdw.p.t] ? 1 : 0}] \
        [expr {[string first {M1:} $F2_PANE] >= 0 ? 1 : 0}] \
        [expr {[kx_nblocks] == 1 ? 1 : 0}]] \
  {0 1 1 1 1 1}

# ---------------------------------------------------------------------------
# F3 / F4 — ISSUE 1306: THE PANE MUST KEEP THE KEYBOARD IT WAS JUST GIVEN
# ---------------------------------------------------------------------------
# THE USER'S HEADLINE REQUIREMENT. This window exists so a dump can be SELECTED
# AND COPIED into a design-review document; a pane that cannot hold the
# keyboard cannot be copied from with the keyboard, so a window that takes the
# keyboard away from its own text at the moment you click into it is worse than
# one that never focuses at all.
#
# THE DEFECT. rdw::_focus_handback guards on %W -- `$w ne {.rdw}` -- and its
# comment reasons from BINDTAGS. That is half the mechanism. When focus crosses
# in from OUTSIDE the window (.drw -> .rdw.p.t, which is exactly the deliberate
# click) X ALSO delivers a separate FocusIn to the ANCESTOR .rdw with detail
# NotifyNonlinearVirtual, so %W is literally `.rdw`, the guard passes, and the
# one-shot bounces the keyboard back to the canvas. Measured here, defect
# present, on this display:
#     after real dump : focus='.drw'       pending=0
#     after text click: focus='.drw'       pending=0   -> BOUNCED
# and against the fixed code, same fixture:
#     after text click: focus='.rdw.p.t'   pending=1   -> KEPT
#
# ⚠ AND THE FIXTURE IS THE WHOLE ROW. THIS IS V8's FAILURE IN A THIRD COSTUME.
# The one-shot only bounces if it is still ARMED when the click lands, and on
# a display with a window manager the map-time grant SPENDS IT during the dump
# -- measured, `pending=0` immediately after a real first-of-session dump. A
# row that then clicked the pane would pass whether the guard is fixed or not:
# vacuous, exactly like B4's row V8. On a WM-LESS server it is worse than
# vacuous, it is a coin flip -- the same script on the same unmodified tree
# gave 5/5 KEPT and, twenty minutes later, 5/5 BOUNCED, because whether the
# consuming FocusIn arrives inside the dump's own `update` is a race. Parking
# the pointer does not cure it (tested at two positions).
# SO THE ROW READS THE POST-DUMP VALUE AND THEN RE-ARMS THE ONE-SHOT BY HAND.
# That state -- armed, window mapped, user clicks the text -- is precisely the
# one issue 1306 filed, it is reachable in the field (no WM, focus-follows-
# mouse with the pointer still on the canvas, a deiconify onto another
# workspace), and re-arming it deliberately is the only way to make it
# DETERMINISTIC: measured BOUNCED 5/5 defect-present and KEPT 4/4 fixed, on
# both a WM-less arm and this one.
#
# ⚠ THE POINTER IS PARKED FIRST, AND PARKED NEUTRALLY. A GUI check that reads
# a focus-dependent property after a window is mapped inherits the pointer
# position: with the pointer inside a window the map's own event pump delivers
# an <Enter> and the context moves before the read (issue 1269, measured
# 2026-09-04). Root (2,2) is BX42's measured-neutral point -- off every window
# this suite maps -- and it must never be parked ONTO .rdw, which would make
# this row assert itself.

## ⚠ AN `if`, NOT AN `expr` TERNARY. The one-shot's absent value is a WORD and
## expr evaluates a bare word as an operand -- `NO-VAR` raises "invalid
## bareword", which is the trap kx_listkind above already records.
proc kx_pending {} {
  if {![info exists ::rdw::focus_pending]} { return NO-VAR }
  return $::rdw::focus_pending
}

catch {
  event generate . <Motion> -warp 1 \
    -x [expr {2 - [winfo rootx .]}] -y [expr {2 - [winfo rooty .]}]
  update idletasks
}
set F3_PARK [winfo containing 2 2]
kx_ans ::rdw::pick_end
kx_reset
catch {destroy .rdw}
update idletasks
set F3_PRE0 [expr {[winfo exists .rdw] ? 1 : 0}]
xschem unselect_all
xschem select instance M1
kx_ans ::rdw::key annotation
## THE SAME BOUNDED PUMP ROW F1 USES, AND FOR THE SAME REASON: the window
## manager's grant rides a MapNotify round trip, which `update idletasks` does
## not process at all.
for {set _f 0} {$_f < 20} {incr _f} { update ; after 25 }
set F3_PANE [expr {[winfo exists .rdw.p.t] ? 1 : 0}]
set F3_FOCUS0 [focus]
set F3_PEND0 [kx_pending]
## RE-ARM ON PURPOSE. Asserted as its own leg, so the row cannot silently
## degrade into the vacuous version if the variable is ever renamed.
catch {set ::rdw::focus_pending 1}
set F3_REARM [kx_pending]
## A REAL CLICK, not `focus -force`. Tk 8.6's tk::TextButton1 calls `focus $w`
## unconditionally (/usr/share/tcltk/tk8.6/text.tcl:579), so a real press is
## the faithful gesture even on a `-state disabled` pane -- which this one is,
## deliberately, so nobody can type into a record of a simulation.
event generate .rdw.p.t <ButtonPress-1>   -x 4 -y 4 -when now
event generate .rdw.p.t <ButtonRelease-1> -x 4 -y 4 -when now
for {set _f 0} {$_f < 20} {incr _f} { update ; after 25 }
set F3_FOCUS1 [focus]
set F3_PEND1 [kx_pending]
check {F3 ISSUE 1306, THE USER'S HEADLINE REQUIREMENT: with the pointer parked off every window, a real first-of-session dump made, its post-dump focus read back on the CANVAS and the one-shot RE-ARMED ON PURPOSE - so the state the row names is guaranteed to exist rather than inherited - a real click into the text pane leaves the keyboard ON THE PANE and does not spend the one-shot. The %W guard cannot tell that click from the window manager's own grant, because X delivers a FocusIn to .rdw for both} \
  [list [expr {![string match {.drw*} $F3_PARK] && ![string match {.rdw*} $F3_PARK] ? 1 : 0}] \
        $F3_PRE0 $F3_PANE $F3_FOCUS0 $F3_REARM $F3_FOCUS1 $F3_PEND1] \
  {1 0 1 .drw 1 .rdw.p.t 1}

## F4 RUNS ON THE STATE F3 LEFT, DELIBERATELY: this is the user's requirement
## stated as the gesture they actually make. <<Copy>> is delivered to WHATEVER
## HOLDS FOCUS -- the same discriminating delivery rows F1 and V8 use for ESC
## -- so with the bounce live it lands on .drw, a FRAME with no Copy binding,
## and the clipboard stays empty. The expected line is READ FROM THE PANE, not
## transcribed, and leg 2 says it really is this device's block, so the row
## cannot pass by copying an empty string out of an empty pane.
set F4_L1 [expr {[winfo exists .rdw.p.t] ? [.rdw.p.t get 1.0 {1.0 lineend}] : {NO-PANE}}]
catch {.rdw.p.t tag remove sel 1.0 end}
catch {.rdw.p.t tag add sel 1.0 {1.0 lineend}}
set F4_SEL {}
catch {set F4_SEL [.rdw.p.t tag ranges sel]}
catch {clipboard clear}
set F4_TGT [focus]
if {$F4_TGT eq {}} { set F4_TGT . }
catch {event generate $F4_TGT <<Copy>> -when now}
update
set F4_CLIP {}
catch {set F4_CLIP [clipboard get]}
check {F4 ISSUE 1306, THE GESTURE THE FEATURE EXISTS FOR: with the pane holding the keyboard and its first line selected, a real <<Copy>> delivered to whatever holds focus puts THAT LINE on the clipboard and leaves the keyboard on the pane - the select-and-paste-into-a-design-review-document the user asked for. Under the bounce the virtual event lands on .drw, which has no Copy binding, and the clipboard stays empty} \
  [list [expr {$F4_L1 ne {} && $F4_L1 ne {NO-PANE} ? 1 : 0}] \
        [expr {[string first {M1} $F4_L1] >= 0 ? 1 : 0}] \
        [expr {$F4_SEL ne {} ? 1 : 0}] \
        $F4_TGT \
        [expr {$F4_CLIP eq $F4_L1 ? 1 : 0}] \
        [focus]] \
  {1 1 1 .rdw.p.t 1 .rdw.p.t}

## LEAVE NOTHING BEHIND. The one-shot was re-armed by hand and a deliberate
## landing does not spend it, so it is cleared explicitly here rather than left
## for the next row to inherit.
catch {set ::rdw::focus_pending 0}
kx_ans ::rdw::pick_end
kx_ans ::rdw::close
catch {destroy .rdw}
kx_reset
xschem unselect_all
focus -force .drw
update idletasks

# ============================================================================
# SECTION C — ISSUE 1303: THE PICK MUST RESOLVE THE POINT THE USER CLICKED
# ============================================================================
# MEASURED on this shipped sheet, one pixel apart:
#     exact   175.175 -199.612  ->  M1
#     snapped 180     -200      ->  R1
# Swept over every instance bbox on cmos_inv.sch: 23725 points, 1513 (6.4%)
# miss the device entirely and 129 (0.5%) resolve to a DIFFERENT device --
# silently, with nothing on screen saying which happened. That is invariant
# I3's plausible-wrong-answer one object out: a results window headed R1 for a
# click on M1.
#
# THE TWO ROWS DO DIFFERENT JOBS AND NEITHER ALONE IS ENOUGH.
#   C1 carries the FILED PAIR literally, through rdw::_pick_at, in USER
#      coordinates. It is screen-independent and it is the control: without it
#      C2 could pass on a sheet that had stopped discriminating.
#   C2 drives rdw::pick_click's DEFAULTS -- which is where the defect lives --
#      through a real mouse event at a straddling pixel FOUND AT RUN TIME. A
#      row that passed explicit coordinates would never touch the defaulting
#      code at all and would pass against the broken pick.

check {C1 CONTROL and the filed 1303 measurement, literally: the read-only pick answers M1 for the point the user's cursor is on and R1 for that point snapped to the grid, one pixel apart on the shipped cmos_inv.sch - the two answers DIFFER, which is what makes row C2 non-vacuous} \
  [list [kx_ans ::rdw::_pick_at 175.175 -199.612] \
        [kx_ans ::rdw::_pick_at 180 -200] \
        [expr {[kx_ans ::rdw::_pick_at 175.175 -199.612] ne \
               [kx_ans ::rdw::_pick_at 180 -200] ? 1 : 0}]] \
  {M1 R1 1}

## THE STRADDLING PIXEL, SEARCHED FOR RATHER THAN TRANSCRIBED. This click
## target has already moved three times under this feature (A3, 1260, 1266), so
## the row computes it; "such a pixel exists" is leg 1, so the row REDS if the
## fixture ever stops discriminating instead of passing vacuously.
kx_ans ::rdw::pick_end
kx_reset
catch {destroy .rdw}
update idletasks
set C2_FOUND 0 ; set C2_PX 0 ; set C2_PY 0 ; set C2_UNS {} ; set C2_SNAP {}
set C2_CX [sx 175.175] ; set C2_CY [sy -199.612]
for {set _d 0} {$_d <= 12 && !$C2_FOUND} {incr _d} {
  foreach _dx [list $_d [expr {-$_d}]] {
    foreach _dy {0 1 -1 2 -2 3 -3 4 -4 5 -5 6 -6 7 -7 8 -8} {
      set _px [expr {$C2_CX + $_dx}] ; set _py [expr {$C2_CY + $_dy}]
      event generate .drw <Motion> -x $_px -y $_py -when now
      update
      set _a [xschem instance_at [xschem get mousex] [xschem get mousey]]
      set _b [xschem instance_at [xschem get mousex_snap] [xschem get mousey_snap]]
      if {$_a ne $_b && $_a ne {}} {
        set C2_FOUND 1 ; set C2_PX $_px ; set C2_PY $_py
        set C2_UNS $_a ; set C2_SNAP $_b
        break
      }
    }
    if {$C2_FOUND} break
  }
}
set C2_ARM [kx_ans ::rdw::key annotation]
update idletasks
kx_click_px $C2_PX $C2_PY
set C2_HDR [kx_top_hdr]
check {C2 THE DEFAULT PATH, at a straddling pixel found at run time: a real click through the seized binding pushes a block whose header names the device UNDER THE CURSOR and not the device the snapped point lands on. rdw::pick_click's defaults are where issue 1303 lives, so a row that passed coordinates in would pass against the broken pick} \
  [list $C2_FOUND [kx_bad $C2_ARM] [expr {$C2_UNS ne $C2_SNAP ? 1 : 0}] \
        [expr {$C2_HDR eq "$C2_UNS:/" ? 1 : 0}] \
        [expr {$C2_HDR eq "$C2_SNAP:/" ? 1 : 0}]] \
  {1 0 1 1 0}

## Sections F and C leave the process exactly as they found it: no mode, no
## window, no selection, nothing in the store, the keyboard back on the canvas
## and the list identity where the suite's later rows expect it. The predecessor
## bindings section V hands back are captured BELOW, after the profile is
## sourced, so a seize left live here would poison every row in the file.
kx_ans ::rdw::pick_end
kx_ans ::rdw::close
kx_reset
catch {xschem unselect_all}
catch {rdw::set_list annotation}
catch {focus -force .drw}
update idletasks
# ============================================================================
# SECTION B — THE FOUR BINDS, AND EVERY CHORD THEY COULD HAVE EATEN
# ============================================================================
# B1's first half is the CONTROL that makes all of section B non-vacuous: the
# four binds must be EMPTY before the profile is sourced. If they were already
# bound by something else, "after sourcing they are bound" would say nothing.
set B1_PRE {}
foreach k {1 2 3 4} { lappend B1_PRE [bind .drw <Key-$k>] }

set KX_SRC [catch {source $KX_RC} KX_SRCERR]
update idletasks

# ============================================================================
# THE PREDECESSORS, TAKEN AFTER THE PROFILE IS SOURCED AND BEFORE ANYTHING ARMS
# ============================================================================
# ⚠ AFTER, not before: src/cadence_style_rc adds a dozen bindings to `.drw`, so
# a sequence list captured before it can never come back. The predecessors the
# seize must hand back are whatever is on the canvas at the moment the mode
# arms, which is here.
#
# The restore assertion has TWO legs on purpose. `bind w seq {}` DESTROYS a
# binding, so when the predecessor was the empty string a correct restore
# removes the sequence from `[bind .drw]` entirely - while a restore that
# writes an empty script back leaves an empty-but-PRESENT binding, which
# satisfies a string comparison and fails the sequence-list comparison. Row V6
# holds both. Measured on this tree: `.drw` is a FRAME whose shipped bindings
# are the GENERIC <Button> and <Key>, so all FOUR predecessors really are the
# empty string and the destroy-versus-empty distinction is live.
set PRE_P [bind .drw <ButtonPress-1>]
set PRE_R [bind .drw <ButtonRelease-1>]
set PRE_E [bind .drw <Key-Escape>]
## ⚠ THE FOURTH SLOT (issue 1304). The seize must take <B1-Motion> too, so
## the predecessor list is FOUR long, not three: `.drw` is a FRAME and this
## one is the empty string like the other three, so the destroy-versus-empty
## distinction applies to it identically.
set PRE_M [bind .drw <B1-Motion>]
set PRE_SEQ [lsort [bind .drw]]

set B1_POST {} ; set B1_BRK {}
foreach k {1 2 3 4} {
  set s [bind .drw <Key-$k>]
  lappend B1_POST [expr {$s ne {} ? 1 : 0}]
  lappend B1_BRK  [expr {[string match {*break*} $s] ? 1 : 0}]
}
check {B1 CONTROL before src/cadence_style_rc is sourced the four bare digit binds are the empty string, after it all four are bound and every one ends in break - the control that makes every row below non-vacuous} \
  [list $KX_SRC $B1_PRE $B1_POST $B1_BRK] \
  [list 0 {{} {} {} {}} {1 1 1 1} {1 1 1 1}]

## THE SPY ON THE NEW DOOR. rdw::key is renamed aside for section B so a press
## can be observed without running the whole round trip; the real proc is put
## back before section V.
proc kx_spy_key {} {
  set ::B_KEYHITS {}
  if {[llength [info commands ::rdw::key]] && ![llength [info commands ::rdw::key_kxreal]]} {
    rename ::rdw::key ::rdw::key_kxreal
  }
  proc ::rdw::key {kind} { lappend ::B_KEYHITS $kind ; return {} }
}
proc kx_unspy_key {} {
  catch {rename ::rdw::key {}}
  if {[llength [info commands ::rdw::key_kxreal]]} { rename ::rdw::key_kxreal ::rdw::key }
}
kx_spy_key

## THE SPY ON THE DISPLACED VERB. logic_set is C and cannot be renamed; its
## first statement sets the Tcl variable ::tclstop to 0 (hilight.c:2505), so a
## sentinel says whether it ran. Measured today: with no bind in the way all
## four bare digits set it.
proc kx_logic_ran {k} {
  set ::tclstop KX_SPY_SENTINEL
  event generate .drw <Key-$k> -state 0 -when now
  update
  return [expr {$::tclstop eq {KX_SPY_SENTINEL} ? 0 : 1}]
}
set B2_HITS {} ; set B2_LOGIC {}
foreach k {1 2 3 4} {
  set ::B_KEYHITS {}
  lappend B2_LOGIC [kx_logic_ran $k]
  lappend B2_HITS $::B_KEYHITS
}
check {B2 a bare 1/2/3/4 reaches rdw::key with the right list and the displaced C verb does NOT run - logic_set spied through its own first statement, measured not assumed} \
  [list $B2_HITS $B2_LOGIC] \
  [list {annotation summary all refresh} {0 0 0 0}]

## Ctrl-1 and Ctrl-3 are the only two Ctrl-digit chords in 1..4 that reach C at
## all: cadence_style_rc:256 and :268 already own Ctrl-2 and Ctrl-4. Measured
## from rectcolor 7 with nothing bound: 1 -> 1, 2 -> unchanged, 3 -> 3,
## 4 -> unchanged. A greedy bare bind eats both of the two that do reach.
xschem set rectcolor 7
event generate .drw <Key-1> -state 4 -when now ; update
set B3_C1 [xschem get rectcolor]
event generate .drw <Key-3> -state 4 -when now ; update
set B3_C3 [xschem get rectcolor]
check {B3 Ctrl-1 and Ctrl-3 still move rectcolor to 1 and 3 - select drawing layer survives, because the guard forwards any Control/Alt/Super press verbatim into the C dispatcher} \
  [list $B3_C1 $B3_C3] {1 3}

## Ctrl-2 and Ctrl-4 belong to the profile's OWN more-specific chords. They are
## rename-stubbed rather than run: direct_plot_for_current would arm a REAL ASE
## command mode on the canvas this suite is about to seize, and make_editable
## would flip the view under the rows below.
set ::B4_EDIT 0 ; set ::B4_PLOT 0
rename cadence::make_editable cadence::make_editable_kxreal
proc cadence::make_editable {} { incr ::B4_EDIT }
rename ase::direct_plot_for_current ase::direct_plot_for_current_kxreal
proc ase::direct_plot_for_current {} { incr ::B4_PLOT }
event generate .drw <Key-2> -state 4 -when now ; update
event generate .drw <Key-4> -state 4 -when now ; update
set B4_GOT [list $::B4_EDIT $::B4_PLOT]
rename cadence::make_editable {} ; rename cadence::make_editable_kxreal cadence::make_editable
rename ase::direct_plot_for_current {} ; rename ase::direct_plot_for_current_kxreal ase::direct_plot_for_current
check {B4 Ctrl-2 still makes the view editable and Ctrl-4 still enters ASE Direct Plot - the file's own more-specific chords win by Tk specificity and the new bare binds neither overwrite nor shadow them} \
  $B4_GOT {1 1}

## THE VACUITY TRAP, NAMED IN THE ROW. `event generate .drw <Alt-Key-2>`
## produces Tk's virtual ALT bit 131072, never reaches C, and scores ZERO even
## with NOTHING bound in its way - measured both ways today. Mod1Mask is 8 and
## must be passed explicitly, or this row passes while the guard is absent.
set ::B5_ALT 0
rename alt2_toggle_view alt2_toggle_view_kxreal
proc alt2_toggle_view {} { incr ::B5_ALT }
event generate .drw <Key-2> -state 8 -when now ; update
set B5_REAL $::B5_ALT
event generate .drw <Alt-Key-2> -when now ; update
set B5_VIRT [expr {$::B5_ALT - $B5_REAL}]
rename alt2_toggle_view {} ; rename alt2_toggle_view_kxreal alt2_toggle_view
check {B5 Alt-2 still runs the shipped view.toggle_view_type action, driven with -state 8 because the literal Alt-Key-2 form produces Tk's virtual ALT bit and would score zero with NO bind in the way} \
  [list $B5_REAL $B5_VIRT] {1 0}

## The source grep sees what no behavioural row can: that the guard is spelled
## on every one of the four, and that B4 added no <Control-Key-2> or
## <Control-Key-4> line, which would OVERWRITE a chord the file already owns.
set B6_RC [kx_slurp $KX_RC]
set B6_G {} ; set B6_B {}
foreach k {1 2 3 4} {
  set ln {}
  foreach l [split $B6_RC "\n"] {
    if {[regexp "^\\s*bind\\s+\\.drw\\s+<Key-$k>" $l]} { set ln $l ; break }
  }
  lappend B6_G [expr {[kx_has $ln {%s & 0x4c}] ? 1 : 0}]
  lappend B6_B [expr {[string match {*break*} $ln] ? 1 : 0}]
}
proc kx_countlines {hay pat} {
  set n 0
  foreach l [split $hay "\n"] { if {[regexp $pat $l]} { incr n } }
  return $n
}
check {B6 SOURCE GREP cadence_style_rc binds Key-1..Key-4, each carrying the modifier guard and a trailing break, and adds no second Control-Key-2 or Control-Key-4 line that would overwrite a chord the file already owns} \
  [list $B6_G $B6_B \
        [kx_countlines $B6_RC {^\s*bind\s+\.drw\s+<Control-Key-2>}] \
        [kx_countlines $B6_RC {^\s*bind\s+\.drw\s+<Control-Key-4>}]] \
  [list {1 1 1 1} {1 1 1 1} 1 1]

kx_unspy_key

# ============================================================================
# THE FIXTURE — A PRIVATE SYMBOL, A PRIVATE SHEET, AND A RAW BUILT BY THE ONE
# NAME BUILDER
# ============================================================================
# ⚠ THE DEVPATH TEMPLATE IS ESCAPED, AND THAT IS NOT A TYPO. Registering
# `devpath {@m.@path@name}` looks healthy and is measurably wrong: `xschem
# translate` swallows the leading `@m.` and yields `m1`, so ase::op_param_split
# returns the empty list, the seam answers `state ok` with an EMPTY union and
# the window prints the fifth silence over a device that has numbers. The
# escaped spelling `{\@m.@path@name}` yields `@m.m1` and is what
# gf180_procs.tcl:129 itself ships. test_annot_declutter_1244.tcl:1560
# registers the UNESCAPED form; do not copy that line.
#
# The symbol carries the declutter's whole text set on purpose: with only
# `@name` on it, mask 9 hides nothing extra and the with-text bbox does not
# move, so row P1's staleness cannot be reproduced at all. Measured — the same
# fixture with one text answered the same box in every phase.
set KX_SYM [file join $scratch b4dev.sym]
set fd [open $KX_SYM w]
puts $fd {v {xschem version=3.4.5 file_version=1.2}
G {}
K {type=b4dev
format="@spiceprefix@name @pinlist @model w=@w l=@l"
template="name=M1 model=b4n w=1u l=0.15u spiceprefix=X"
}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}
B 5 -22.5 7.5 -17.5 12.5 {name=g dir=inout}
T {@name} 0 -40 0 0 0.2 0.2 {}
T {@symname} 0 -25 0 0 0.2 0.2 {}
T {@spiceprefix@name} 0 -10 0 0 0.2 0.2 {}
T {B4OPTEXT} 0 5 0 0 0.2 0.2 {hide=op}
T {B4VOLTTEXT} 0 20 0 0 0.2 0.2 {hide=voltage}
T {B4TRUETEXT} 0 35 0 0 0.2 0.2 {hide=true}
T {B4W=@w} 150 55 0 0 0.2 0.2 {}
T {B4GATE} -150 -80 0 0 0.2 0.2 {}}
close $fd

set KX_SUBSCH [file join $scratch b4sub.sch]
set fd [open $KX_SUBSCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$KX_SYM\} 100 -100 0 0 \{name=M3\}"
close $fd

set KX_SUBSYM [file join $scratch b4sub.sym]
set fd [open $KX_SUBSYM w]
puts $fd {v {xschem version=3.4.5 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=X1"
}
V {}
S {}
E {}
L 4 -40 -40 40 -40 {}
L 4 40 -40 40 40 {}
L 4 40 40 -40 40 {}
L 4 -40 40 -40 -40 {}
T {@name} 0 -55 0 0 0.2 0.2 {}}
close $fd

set KX_SCH [file join $scratch b4top.sch]
set fd [open $KX_SCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
N 600 -400 800 -400 {}
C \{$KX_SYM\} 300 -300 0 0 \{name=M1\}
C \{$KX_SYM\} 300 -120 0 0 \{name=M2\}
C \{devices/res\} 700 -100 0 0 \{name=R1
value=10\}
C \{$KX_SUBSYM\} 700 -250 0 0 \{name=X1\}"
close $fd

set fd [open [file join $scratch library.defs] w]
puts $fd "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $fd
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

xschem load $KX_SCH
xschem zoom_full ; update idletasks
catch {op_annot::register b4dev \
  [list devpath {\@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}

## M3's vector names come from op_annot::vector while DESCENDED, so the raw
## cannot drift from the descriptor (invariant I1, one name builder) and the
## descended dump at row D1 renders real numbers rather than the fifth silence.
xschem unselect_all
xschem select instance X1
catch {xschem descend}
update idletasks
set KX_M3V {}
catch {set KX_M3V [list [op_annot::vector M3 zid] [op_annot::vector M3 zgm]]}
catch {xschem go_back}
update idletasks
xschem unselect_all

set KX_PAIRS {}
foreach d {M1 M2} vi {1.11e-05 2.22e-05} vg {3.33e-04 4.44e-04} {
  catch {lappend KX_PAIRS [op_annot::vector $d zid] $vi [op_annot::vector $d zgm] $vg}
}
if {[llength $KX_M3V] == 2} {
  lappend KX_PAIRS [lindex $KX_M3V 0] 5.55e-05 [lindex $KX_M3V 1] 6.66e-04
}
set KX_RAW [file join $scratch b4.raw]
proc kx_mkraw {path pairs} {
  set f [open $path w]
  puts -nonewline $f "Title: B4 keys fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  puts -nonewline $f "Plotname: Operating Point\nFlags: real\n"
  puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: 1\nVariables:\n"
  set k 0
  foreach {v val} $pairs { puts -nonewline $f "\t$k\t$v\tvoltage\n" ; incr k }
  puts -nonewline $f "Values:\n"
  set k 0
  foreach {v val} $pairs {
    if {$k == 0} { puts -nonewline $f "0\t$val\n" } else { puts -nonewline $f "\t$val\n" }
    incr k
  }
  close $f
}
kx_mkraw $KX_RAW $KX_PAIRS
proc kx_annot {} {
  catch {xschem raw clear}
  catch {xschem annotate_op $::KX_RAW 0}
  update idletasks
}
kx_annot
catch {xschem update_all_sym_bboxes}

## Counting wrappers on the three arms whose ABSENCE is the interesting event.
## `rdw::key summary` while the mode is live must not release and retake the
## seize (row V7), a descend must call the suspend arm (row D1), and the resume
## arm must be handed the canvas that is current NOW (row D1's D2-of-0201 leg).
set ::KX_REL 0 ; set ::KX_SUSP 0 ; set ::KX_RESUME_CV {}
if {[llength [info commands ::rdw::pick_release]]} {
  rename ::rdw::pick_release ::rdw::pick_release_kxreal
  proc ::rdw::pick_release {args} {
    incr ::KX_REL
    return [uplevel 1 [linsert $args 0 ::rdw::pick_release_kxreal]]
  }
}
if {[llength [info commands ::rdw::pick_suspend]]} {
  rename ::rdw::pick_suspend ::rdw::pick_suspend_kxreal
  proc ::rdw::pick_suspend {args} {
    incr ::KX_SUSP
    return [uplevel 1 [linsert $args 0 ::rdw::pick_suspend_kxreal]]
  }
}
if {[llength [info commands ::rdw::pick_resume]]} {
  rename ::rdw::pick_resume ::rdw::pick_resume_kxreal
  proc ::rdw::pick_resume {cv} {
    set ::KX_RESUME_CV $cv
    return [uplevel 1 [list ::rdw::pick_resume_kxreal $cv]]
  }
}


# ============================================================================
# SECTION V — THE VERB-NOUN COMMAND MODE. THE USER'S OWN REQUIREMENT LIVES HERE.
# ============================================================================
# "This is a command mode, so clicking will not change selected set." Every row
# below that clicks carries the selection oracle beside it, and row V2 carries
# the leg that stops the oracle passing on a click that did nothing.

## V0 IS SECTION V's OWN PRECONDITION. Every row below claims a click
## "answered M1" or "hit nothing"; without this the whole section could be
## measuring a hit-test that moved under it (item A3 moved it once already).
## The four points are COMPUTED from `xschem instance_bbox` at the annotation
## state the rows actually run at, never transcribed.
catch {xschem update_all_sym_bboxes}
lassign [kx_centre M1] V0_M1X V0_M1Y
lassign [kx_centre M2] V0_M2X V0_M2Y
lassign [kx_centre R1] V0_R1X V0_R1Y
check {V0 CONTROL the fixture's four click points really are what section V says they are: two devices with a descriptor, one without, a bare wire and empty canvas - measured through the read-only pick itself, so no row below can be vacuous} \
  [list [xschem instance_at $V0_M1X $V0_M1Y] [xschem instance_at $V0_M2X $V0_M2Y] \
        [xschem instance_at $V0_R1X $V0_R1Y] [xschem instance_at 700 -400] \
        [xschem instance_at 9000 9000] \
        [lindex [xschem select_at 700 -400] 0]] \
  {M1 M2 R1 {} {} wire}
xschem unselect_all

kx_reset
set V1_ARM [kx_ans ::rdw::key annotation]
update idletasks
check {V1 nothing selected plus key 1 arms the mode: ButtonPress-1 is seized by rdw::pick_click, ButtonRelease-1 is taken so a lone release cannot reach C, Key-Escape is seized, and ONE CIW line says how to pick and how to leave} \
  [list [kx_bad $V1_ARM] [seized] \
        [expr {[bind .drw <ButtonRelease-1>] ne $PRE_R ? 1 : 0}] \
        [expr {[bind .drw <Key-Escape>] ne $PRE_E ? 1 : 0}] \
        [llength $::KX_CIW] [kx_oneline [lindex $::KX_CIW 0]]] \
  {0 1 1 1 1 1}

## THE SHARPEST ROW IN THE SUITE. Three legs, and the second and third are what
## stop the first being a statement about a click that never happened.
lassign [kx_centre M1] V2X V2Y
set V2_SEL0 [kx_sel]
set ::KX_CIW {}
kx_click $V2X $V2Y
set V2_SEL1 [kx_sel]
set V2_H1 [kx_top_hdr]
## and again with a NON-EMPTY selection standing, so the oracle is not merely
## "empty stayed empty": a wire is selected by hand, a second device is clicked,
## and the selection must come back byte-identical including the wire.
xschem select wire 0
set V2_SEL2 [kx_sel]
lassign [kx_centre M2] V2X2 V2Y2
kx_click $V2X2 $V2Y2
set V2_SEL3 [kx_sel]
set V2_H2 [kx_top_hdr]
xschem unselect_all
check {V2 THE USER'S OWN REQUIREMENT: a real Motion+ButtonPress+ButtonRelease over a device leaves xschem selection BYTE-IDENTICAL - empty and non-empty alike - AND the block's header names the device under the cursor, without which the first leg passes on a click that did nothing} \
  [list [expr {$V2_SEL1 eq $V2_SEL0 ? 1 : 0}] $V2_H1 \
        [expr {$V2_SEL2 ne {} ? 1 : 0}] \
        [expr {$V2_SEL3 eq $V2_SEL2 ? 1 : 0}] $V2_H2] \
  {1 M1:/ 1 1 M2:/}

## ---------------------------------------------------------------------------
## V2b — ISSUE 1304. THE ROW THE USER'S OWN SENTENCE OWES, AND THE ONE GESTURE
## NEITHER SUITE MAKES: A DRAG.
## ---------------------------------------------------------------------------
## The seize was copied from ase::ui::select_on_design, which takes the press,
## the release and Escape and NOT <B1-Motion>. So C's rubber band STARTS -- a
## motion with Button1Mask calls select_rect(START,1) + unselect_all(1) and sets
## STARTSELECT (callback.c:7250-7260) -- and NEVER TERMINATES, because the only
## terminator is ButtonRelease's select_rect(...,END,-1) (callback.c:9748) and
## the seize eats the release. Measured on the shipped three-bind shape: an
## 8-step drag left ui_state 24, lastsel 20 and TWENTY objects in `xschem
## selection`, and those survived a real ESC. That is a direct violation of the
## user's own requirement, "This is a command mode, so clicking will not change
## selected set."
##
## ⚠ THE FIXTURE STATE IS THIS ROW'S OWN, FOR A MEASURED REASON. A seized press
## that follows an earlier drag which MOVED an instance hangs inside
## `event generate <ButtonPress-1> -when now` and the run dies on the timeout.
## So the drag starts on EMPTY CANVAS -- asserted as leg 1, not assumed -- and
## the no-mode CONTROL runs AFTER the seized one, never before.
kx_ans ::rdw::pick_end
kx_reset
xschem unselect_all
set V2B_ARM [kx_ans ::rdw::key annotation]
update idletasks
## Corner to corner of the canvas widget in SCREEN pixels: zoom_full leaves a
## margin, so the start point is empty canvas and the band sweeps the sheet.
set V2B_PX0 6 ; set V2B_PY0 6
set V2B_PX1 [expr {[winfo width .drw] - 6}]
set V2B_PY1 [expr {[winfo height .drw] - 6}]
set V2B_EMPTY [expr {[xschem instance_at [ux $V2B_PX0] [uy $V2B_PY0]] eq {} ? 1 : 0}]
set V2B_SEL0 [kx_sel]
kx_drag_px $V2B_PX0 $V2B_PY0 $V2B_PX1 $V2B_PY1
set V2B_SEL1 [kx_sel]
set V2B_LASTSEL [xschem get lastsel]
set V2B_BAND1 [expr {([xschem get ui_state] & 16) ? 1 : 0}]
## And after a real ESC, because the filed measurement survived one.
focus -force .drw ; update idletasks
event generate .drw <Key-Escape> -when now
update
set V2B_SEL2 [kx_sel]
set V2B_BAND2 [expr {([xschem get ui_state] & 16) ? 1 : 0}]
## THE NARROWNESS LEG. Breaking <B1-Motion> must blind C to a drag and to
## nothing else: a plain hover with no button still has to move the pointer, or
## the crosshair and the status line die with it and the mode looks broken.
kx_ans ::rdw::pick_end
kx_reset
kx_ans ::rdw::key annotation
event generate .drw <Motion> -x 40 -y 40 -when now
update
set V2B_HOVER0 [xschem get mousex]
event generate .drw <Motion> -x 400 -y 300 -when now
update
set V2B_HOVER [expr {[xschem get mousex] != $V2B_HOVER0 ? 1 : 0}]
## THE CONTROL, WITH NO MODE ARMED, on the same coordinates and the same
## gesture: C's rubber band must still work, or the row above is a statement
## about a drag that never happened.
kx_ans ::rdw::pick_end
xschem unselect_all
update idletasks
set V2B_CTL_SEIZED [seized]
kx_drag_px $V2B_PX0 $V2B_PY0 $V2B_PX1 $V2B_PY1
set V2B_CTL_SEL [expr {[kx_sel] ne {} ? 1 : 0}]
set V2B_CTL_BAND [expr {([xschem get ui_state] & 16) ? 1 : 0}]
xschem unselect_all
update idletasks
check {V2b THE USER'S OWN REQUIREMENT UNDER A DRAG (issue 1304): with the mode live, a press plus eight Button1 motions plus a release must leave the selection EMPTY, lastsel 0 and C's rubber band terminated - before and after a real ESC - while a plain hover still moves the pointer and the same gesture with NO mode armed still selects. Without the fourth seized sequence a 1-pixel drift selects the whole sheet} \
  [list [kx_bad $V2B_ARM] $V2B_EMPTY \
        [expr {$V2B_SEL1 eq $V2B_SEL0 ? 1 : 0}] $V2B_LASTSEL $V2B_BAND1 \
        [expr {$V2B_SEL2 eq $V2B_SEL0 ? 1 : 0}] $V2B_BAND2 \
        $V2B_HOVER $V2B_CTL_SEIZED $V2B_CTL_SEL $V2B_CTL_BAND] \
  {0 1 1 0 0 1 0 1 0 1 0}

## Back to the state row V3 inherits: the mode live, the store empty, nothing
## selected. V3 asks whether a click leaves the mode alive, so it must start
## from an armed one.
kx_reset
set V2B_REARM [kx_ans ::rdw::key annotation]
update idletasks
check {V2b-r the mode re-arms after the control drag, so row V3 measures what it says it measures rather than inheriting a dead mode from the row above} \
  [list [kx_bad $V2B_REARM] [seized] [kx_nblocks]] {0 1 0}

set V3_N0 [kx_nblocks]
lassign [kx_centre M1] V3X V3Y
kx_click $V3X $V3Y
check {V3 the mode stays live across a click: a second click on a second device pushes a second block with the seize still in place - ESC is the only exit, which is what "this is a command mode" means} \
  [list [seized] [expr {[kx_nblocks] == $V3_N0 + 1 ? 1 : 0}] [kx_top_hdr]] \
  {1 1 M1:/}

## The four inputs most likely to break this change, driven rather than
## reasoned about: empty canvas, a wire, a subcircuit with no descriptor, and a
## device with no descriptor at all.
set ::KX_CIW {} ; set V4_N0 [kx_nblocks] ; set V4_SEL0 [kx_sel]
kx_click 9000 9000
set V4_EMPTY [list [llength $::KX_CIW] [kx_oneline [lindex $::KX_CIW 0]] \
                   [expr {[kx_nblocks] == $V4_N0 ? 1 : 0}] \
                   [expr {[kx_sel] eq $V4_SEL0 ? 1 : 0}] [seized]]
set ::KX_CIW {}
kx_click 700 -400
set V4_WIRE [list [llength $::KX_CIW] [kx_oneline [lindex $::KX_CIW 0]] \
                  [expr {[kx_nblocks] == $V4_N0 ? 1 : 0}] \
                  [expr {[kx_sel] eq $V4_SEL0 ? 1 : 0}] [seized]]
check {V4 a click on EMPTY canvas and a click on a WIRE each produce ONE CIW line, NO block, an unchanged selection and a still-live mode - a miss is not a reason to end a command} \
  [list $V4_EMPTY $V4_WIRE] [list {1 1 1 1 1} {1 1 1 1 1}]

## A device the seam has nothing for still gets a BLOCK: the window's own
## locked no_devpath sentence. The refusal channel and the window are NOT
## double-booked - a device that resolved is the window's to answer.
set ::KX_CIW {} ; set V5_N0 [kx_nblocks]
lassign [kx_centre R1] V5X V5Y
kx_click $V5X $V5Y
set V5_TXT [kx_ans ::rdw::block_text [lindex $::rdw::blocks 0]]
check {V5 a click on an instance with NO descriptor pushes a BLOCK carrying the window's locked sentence and emits NO CIW line - the device resolved even though the seam had nothing to say about it} \
  [list [expr {[kx_nblocks] == $V5_N0 + 1 ? 1 : 0}] [kx_top_hdr] \
        [kx_has $V5_TXT {has no operating-point descriptor}] [llength $::KX_CIW]] \
  {1 R1:/ 1 0}

## ESC, delivered as a real key event on the canvas.
## ⚠ THE FIRST LEG IS THE ONE THAT STOPS THIS ROW PASSING VACUOUSLY. With no
## mode ever armed the bindings are trivially at their predecessors and every
## other leg is green while nothing was tested - measured, this row was ALL
## PASS against the unmodified tree until the seized-before leg was added.
set V6_PRE [seized]
## ⚠ THE FOURTH SLOT, CAPTURED WHILE THE MODE IS STILL LIVE (issue 1304). Read
## after the ESC it would be at its predecessor either way, so the leg would be
## green whether the seize ever took <B1-Motion> or not - which is exactly how
## the hole shipped. This leg says the seize TOOK it; the leg below says the
## release GAVE IT BACK.
set V6_MSEIZE [expr {[bind .drw <B1-Motion>] ne $PRE_M ? 1 : 0}]
focus -force .drw ; update idletasks
event generate .drw <Key-Escape> -when now
update
check {V6 a real Key-Escape on the canvas ends the mode and hands ALL FOUR bindings back BYTE-IDENTICALLY, and returns the whole sequence list of .drw to its pre-entry value - an empty-but-present binding passes the first leg and fails the second, and the <B1-Motion> slot is asserted taken while the mode was live and given back after it} \
  [list $V6_PRE $V6_MSEIZE [seized] \
        [bind .drw <ButtonPress-1>] [bind .drw <ButtonRelease-1>] \
        [bind .drw <Key-Escape>] [bind .drw <B1-Motion>] \
        [expr {[lsort [bind .drw]] eq $PRE_SEQ ? 1 : 0}]] \
  [list 1 1 0 $PRE_P $PRE_R $PRE_E $PRE_M 1]

## A list key pressed while the mode is live must RE-ARM IN PLACE. ASE's own
## select_on_design self-serialises by ENDING the previous mode first
## (ase_window.tcl:1879); copying that here would drop the pick on a list
## switch, releasing and retaking the seize for nothing. The release counter is
## how that is observed - a re-take is string-identical and invisible without it.
kx_reset
kx_ans ::rdw::key annotation
update idletasks
set V7_REL0 $::KX_REL
kx_ans ::rdw::key summary
update idletasks
set V7_LK [kx_listkind]
set V7_SEIZED [seized]
lassign [kx_centre M1] V7X V7Y
kx_click $V7X $V7Y
set V7_N [kx_nblocks]
kx_ans ::rdw::key refresh
check {V7 key 2 pressed while the mode is live re-arms IN PLACE - listkind moves to summary, the seize is the SAME one and was never released and retaken - and key 4 then trims the store to one block without dropping the mode} \
  [list $V7_LK $V7_SEIZED [expr {$::KX_REL - $V7_REL0}] \
        [expr {$V7_N >= 1 ? 1 : 0}] [kx_nblocks] [seized]] \
  {summary 1 0 1 1 1}

## The mode's Escape lives on the CANVAS, so a dump that does not hand keyboard
## focus back leaves a mode that can never be escaped - measured in ASE and
## recorded at ase_window.tcl:1905-1911. ESC is delivered to WHATEVER HAS
## FOCUS, which is the only delivery that can tell the two states apart.
## ⚠ THIS ROW RUNS WITH .rdw LONG SINCE MAPPED, so it cannot see the window
## manager's map-time grant at all - which is exactly why it passed while the
## race was live. Row F1 is the one that constructs the first-of-session state.
set V8_PRE [seized]
set V8_FOCUS [focus]
set V8_WIN [expr {[winfo exists .rdw] ? 1 : 0}]
set V8_TARGET [expr {$V8_FOCUS eq {} ? {.} : $V8_FOCUS}]
catch {event generate $V8_TARGET <Key-Escape> -when now}
update
check {V8 after every dump the keyboard focus is back on the CANVAS and not on .rdw - proved by a real ESC delivered to whatever holds focus still ending the mode with the window open} \
  [list $V8_PRE $V8_WIN [expr {[string match {.rdw*} $V8_FOCUS] ? 1 : 0}] [seized]] \
  {1 1 0 0}

# ============================================================================
# SECTION P — THE CLICK TARGET, WHICH MOVED UNDER THIS ITEM THREE TIMES
# ============================================================================
# A3 (the with-text bbox shrinks under the declutter and find_closest_element
# gates on exactly that box), A5 / issue 1260 (setprop and move_instance write
# the click box from a stale gate), A6 / issue 1266 (annotate_op and raw clear
# move the gate's answer while calling symbol_bbox not at all). The cure is one
# named callee, rdw::_refresh_pick_gate, run before EVERY pick.
#
# ⚠ THE MASK IS WRITTEN THROUGH `xschem set annot_show`, NEVER A BARE SET.
# Measured today: after `set ::annot_show 9`, `xschem get annot_show` still
# reads 0 and `xschem get annot_root` is EMPTY - unstamped, so the 0688 root
# backstop can clear it. `xschem set annot_show 9` moves the C field, the Tcl
# mirror and the stamp together.

kx_ans ::rdw::pick_end
kx_reset
kx_annot
xschem set annot_show 9
catch {xschem update_all_sym_bboxes}
set P_NARROW [kx_ibox M1]
## What the box WOULD be with the raw gone and the gate refreshed. Measured
## first, so the probe point can be computed rather than transcribed, and then
## the stale state is built again from scratch.
catch {xschem raw clear} ; update idletasks
catch {xschem update_all_sym_bboxes}
set P_WIDE [kx_ibox M1]
set P_PX [expr {([lindex $P_WIDE 0] + [lindex $P_NARROW 0])/2.0}]
set P_PY [expr {([lindex $P_NARROW 1] + [lindex $P_NARROW 3])/2.0}]

kx_annot
xschem set annot_show 9
catch {xschem update_all_sym_bboxes}
catch {xschem raw clear} ; update idletasks
## The staleness itself, asserted as a leg: without it the row would pass on a
## gate that never went stale, which is the whole failure this row exists for.
set P1_STALE [xschem instance_at $P_PX $P_PY]
kx_reset
set P1_ARM [kx_ans ::rdw::key annotation]
set P1_HIT [kx_ans ::rdw::pick_click $P_PX $P_PY]
check {P1 THE REFRESH ROW: raw clear moves the gate's answer while calling symbol_bbox not at all, so a click over now-visible text answers EMPTY - and one pick through rdw::pick_click answers the device, because the refresh runs first. The point is computed from instance_bbox, never transcribed from A3} \
  [list [expr {$P_NARROW ne $P_WIDE ? 1 : 0}] $P1_STALE [kx_bad $P1_ARM] [kx_top_hdr]] \
  {1 {} 0 M1:/}

## THE SECOND PICK. A first-pick-only refresh passes P1 and fails here: the
## mode seizes only Button-1 and Escape, so 6 / Ctrl-6 / Ctrl-Alt-6 and any
## annotate_op still move the gate WHILE the mode is live.
kx_annot
xschem set annot_show 9
catch {xschem update_all_sym_bboxes}
set P2_MASK [xschem get annot_show]
set P2_ROOT [expr {[xschem get annot_root] ne {} ? 1 : 0}]
## ⚠ THE TWO PICKS NAME DIFFERENT DEVICES ON PURPOSE. With both aimed at M1
## the second leg is satisfied by the FIRST pick's block still sitting on top
## of the store, and the row would pass while the second pick did nothing at
## all. M2 first, M1 second, and the header has to move.
lassign [kx_centre M2] P2X P2Y
set P2_FIRST [kx_ans ::rdw::pick_click $P2X $P2Y]
set P2_H1 [kx_top_hdr]
set P2_N1 [kx_nblocks]
catch {xschem raw clear} ; update idletasks
set P2_STALE [xschem instance_at $P_PX $P_PY]
set P2_SECOND [kx_ans ::rdw::pick_click $P_PX $P_PY]
check {P2 the refresh is PER CLICK and not once at mode entry: a first pick lands on one device, then raw clear moves the gate under the LIVE mode, and the SECOND pick still answers the OTHER device - and the mask reads back set and stamped, proving it went through xschem set annot_show and not a bare set} \
  [list $P2_MASK $P2_ROOT [kx_bad $P2_FIRST] $P2_H1 $P2_STALE [kx_bad $P2_SECOND] \
        [kx_top_hdr] [expr {[kx_nblocks] == $P2_N1 + 1 ? 1 : 0}]] \
  {9 1 0 M2:/ {} 0 M1:/ 1}

kx_ans ::rdw::pick_end
xschem set annot_show 0
kx_annot
catch {xschem update_all_sym_bboxes}

# ============================================================================
# SECTION D — THE DESCEND ROUND TRIP, AND THE GAP THE CADENCE CHORD LEAVES
# ============================================================================
kx_reset
set D1_ARM [kx_ans ::rdw::key annotation]
set D1_LK [kx_listkind]
lassign [kx_centre M1] D1X D1Y
kx_click $D1X $D1Y
set D1_N0 [kx_nblocks]
set ::KX_SUSP 0 ; set ::KX_RESUME_CV {}
set D1_OK [catch {hi_descend inst=X1 target=current mode=readonly} D1_R]
update idletasks
set D1_CV [xschem get current_win_path]
## ⚠ CAPTURED HERE, NOT IN THE `check` LINE. Every leg written as a bare
## command inside the argument list is evaluated when `check` runs - i.e.
## AFTER the ESC below - so "still seized after the resume" would read the
## post-ESC state and be false by construction.
set D1_DESC   [expr {[xschem get currsch] > 0 ? 1 : 0}]
set D1_SUSP   [expr {$::KX_SUSP >= 1 ? 1 : 0}]
set D1_RESCV  $::KX_RESUME_CV
set D1_UNSUSP [kx_ans ::cmdmode::is_suspended]
set D1_SEIZED [seized $D1_CV]
## ⚠ THE RESUME ARM RE-LATCHES FOUR SEQUENCES NOW, NOT THREE, AND IT RE-LATCHES
## THEM FROM THE CANVAS IT LANDS ON. Captured here for the same reason as the
## rest of this block: a leg written bare inside the `check` argument list is
## evaluated AFTER the ESC below and would read the released state.
set D1_MSEIZE [expr {[bind $D1_CV <B1-Motion>] ne $PRE_M ? 1 : 0}]
set D1_LK2    [kx_listkind]
set D1_SEL0 [kx_sel]
lassign [kx_centre M3] D1MX D1MY
kx_click $D1MX $D1MY $D1_CV
set D1_H [kx_top_hdr]
set D1_N1 [kx_nblocks]
set D1_SEL1 [kx_sel]
focus -force $D1_CV ; update idletasks
event generate $D1_CV <Key-Escape> -when now
update
check {D1 the descend round trip: a descend with the mode live SUSPENDS and RESUMES it on the canvas that is current NOW, the store and the list survive untouched, a click on the DESCENDED canvas dumps the descended device with the selection still byte-identical, and ESC then restores ALL FOUR of that canvas's own predecessors} \
  [list $D1_OK $D1_DESC $D1_SUSP $D1_RESCV $D1_UNSUSP $D1_SEIZED $D1_MSEIZE \
        $D1_LK $D1_LK2 [expr {$D1_N1 > $D1_N0 ? 1 : 0}] $D1_H \
        [expr {$D1_SEL1 eq $D1_SEL0 ? 1 : 0}] [seized $D1_CV] \
        [bind $D1_CV <ButtonPress-1>] [bind $D1_CV <Key-Escape>] \
        [bind $D1_CV <B1-Motion>]] \
  [list 0 1 1 $D1_CV 0 1 1 annotation annotation 1 M3:/X1 1 0 $PRE_P $PRE_E $PRE_M]

## TODAY'S BEHAVIOUR, PINNED SO THE FIX WILL RED IT. The cadence profile's OWN
## descend - Ctrl-x, cadence::descend_into_inst, utils/cadence_nav.tcl:260 -
## calls `xschem descend -fallback` directly and NEVER cmdmode::suspend_all.
## Only hi_descend_do and hi_descend_pick_arm suspend. So cmdmode::register
## buys item B4 the E-key descend and NOT the chord the cadence user actually
## presses, and the same gap affects ASE Direct Plot identically today. Filed
## as issue 1301; utils/cadence_nav.tcl is outside B4's Files cell.
catch {xschem go_back} ; update idletasks
kx_reset
kx_ans ::rdw::key annotation
update idletasks
xschem select instance X1
set ::KX_SUSP 0
catch {cadence::descend_into_inst}
update idletasks
set D2_CV [xschem get current_win_path]
check {D2 MEASURED GAP PINNED (issue 1301): the cadence profile's own Ctrl-x descend never calls cmdmode::suspend_all, so the mode stays seized straight across it - today's behaviour asserted so that fixing it reds this row rather than passing in silence} \
  [list [expr {[xschem get currsch] > 0 ? 1 : 0}] $::KX_SUSP \
        [kx_ans ::cmdmode::is_suspended] [seized $D2_CV]] \
  {1 0 0 1}

kx_ans ::rdw::pick_end
catch {xschem go_back} ; update idletasks
xschem unselect_all

# ---------------------------------------------------------------------------
# D3 — ISSUE 1305: A KEY PRESSED DURING A SUSPENDED DESCEND MUST NOT SEIZE
#      THE CANVAS FOR THE REST OF THE SESSION
# ---------------------------------------------------------------------------
# THE GESTURE IS ORDINARY. hi_descend_pick_arm (xschem.tcl:7707) calls
# cmdmode::suspend_all and then WAITS IN THE EVENT LOOP for the user to pick an
# instance -- cmdmode's own ruling D6 calls that multi-frame wait load-bearing.
# Pressing 1/2/3/4 during that wait is a thing a user does, and ruling D-2's
# whole premise is that those four keys are always live on the canvas.
#
# THE DEFECT. rdw::pick_start's "already armed" guard is
#     if {[info exists pick(canvas)] && ![info exists pick(suspended)]} { return 1 }
# so a SUSPENDED mode falls through and re-seizes -- correctly, that is the
# point -- but WITHOUT clearing pick(suspended). The descend's own
# cmdmode::resume_all therefore still believes the mode is suspended, calls
# rdw::pick_resume, and _pick_seize runs a SECOND time on a canvas that is
# already seized, latching THE SEIZE'S OWN SCRIPTS as the predecessors.
# rdw::pick_end then faithfully restores them. MEASURED here, defect present:
#     after ESC   P='rdw::pick_click; break'  R='break'
#                 E='rdw::pick_end; break'    M='break'
#     second ESC  returns 0 and restores nothing
# For the rest of the session, on that canvas: every click opens a dump instead
# of selecting, nothing can be selected by clicking ever again, <B1-Motion> is
# `break` so issue 1304's fourth sequence makes the rubber band permanently
# dead too, and the mode's own advice -- "press ESC to leave" -- cannot work.
# That is the exact inverse of the user's ruling sentence, "This is a command
# mode, so clicking will not change selected set": clicking can now NEVER
# change the selected set again.
#
# ⚠ NO ROW IN EITHER B4-2 SUITE SET OR OBSERVED pick(suspended) BEFORE CALLING
# pick_start. That is why 27 green checks and an eight-variant sabotage matrix
# did not see this, and it is why the drive below is written out in full rather
# than folded into row D1.
#
# ⚠ THIS ROW MUST NOT ASSERT cmdmode::resume_all's RETURN COUNT.
# cmdmode.tcl:130 does `incr n` for every callback that does not THROW,
# regardless of what it returns, so the count reads 1 before AND after the fix
# -- measured. The four .drw BINDING SLOTS after a real ESC are the only honest
# discriminator, and they are what this row reads.
#
# ⚠ THE KEY PRESSED IS <Key-2>, NOT <Key-1>, ON PURPOSE. The mode is armed on
# the `annotation` list, so a bare 1 would leave the list identity where it
# already was and the row could not tell a key that ARRIVED from one that was
# swallowed. A bare 2 moves ::rdw::listkind to `summary`, which is a positive
# receipt that the cadence bind delivered and rdw::key ran -- without it every
# leg below would still be red under the defect, but for a reason the row could
# not name.

kx_ans ::rdw::pick_end
kx_reset
xschem unselect_all
update idletasks
set D3_CV [xschem get current_win_path]
set D3_BIND2 [expr {[bind .drw <Key-2>] ne {} ? 1 : 0}]
set D3_LK0 [kx_ans ::rdw::key annotation]
update idletasks
set D3_ARMED [seized]
set D3_LKA [kx_listkind]
## SUSPEND, the way a descend does it, and assert the release really happened:
## if it did not, every leg below would be about a mode that was never paused.
set D3_NSUS [kx_ans ::cmdmode::suspend_all]
update idletasks
set D3_FLAG0 [expr {[info exists ::rdw::pick(suspended)] ? 1 : 0}]
set D3_SUSP_P [bind .drw <ButtonPress-1>]
set D3_SUSP_E [bind .drw <Key-Escape>]
set D3_SUSP_M [bind .drw <B1-Motion>]
## THE USER'S KEY PRESS, DURING THE WAIT. %s is 0, so cadence_style_rc's
## `%s & 0x4c` modifier guard routes it to rdw::key rather than forwarding it.
focus -force .drw ; update idletasks
event generate .drw <Key-2> -when now
update
set D3_LKB [kx_listkind]
set D3_FLAG1 [expr {[info exists ::rdw::pick(suspended)] ? 1 : 0}]
set D3_SEIZED1 [seized]
## THE DESCEND LANDS AND RESUMES. With the flag cleared by pick_start this is a
## no-op that returns 0 from rdw::pick_resume; with the flag still set it is
## the second seize, and the damage is done here.
kx_ans ::cmdmode::resume_all
update idletasks
set D3_SEIZED2 [seized]
## A REAL ESC ON THE CANVAS -- the mode's own documented exit.
focus -force .drw ; update idletasks
event generate .drw <Key-Escape> -when now
update
set D3_SEIZED3 [seized]
set D3_END_P [bind .drw <ButtonPress-1>]
set D3_END_R [bind .drw <ButtonRelease-1>]
set D3_END_E [bind .drw <Key-Escape>]
set D3_END_M [bind .drw <B1-Motion>]
set D3_SEQOK [expr {[lsort [bind .drw]] eq $PRE_SEQ ? 1 : 0}]
check {D3 ISSUE 1305: with the mode live and a descend's suspend outstanding, a real bare 2 on the canvas re-arms the pick AND clears the suspend, so the later resume finds nothing to resume and a real ESC hands ALL FOUR of the canvas's own predecessors back. Without the clear the resume seizes a canvas that is already seized, latches the seize's own scripts as the predecessors, and ESC restores them - a PERMANENT seize with no key left that ends it} \
  [list $D3_CV $D3_BIND2 [kx_bad $D3_LK0] $D3_ARMED $D3_LKA \
        $D3_NSUS $D3_FLAG0 $D3_SUSP_P $D3_SUSP_E $D3_SUSP_M \
        $D3_LKB $D3_FLAG1 $D3_SEIZED1 $D3_SEIZED2 \
        $D3_SEIZED3 $D3_END_P $D3_END_R $D3_END_E $D3_END_M $D3_SEQOK] \
  [list .drw 1 0 1 annotation \
        1 1 $PRE_P $PRE_E $PRE_M \
        summary 0 1 1 \
        0 $PRE_P $PRE_R $PRE_E $PRE_M 1]

## ⚠ REPAIR THE CANVAS BY HAND, AND THAT IS PART OF THE MEASUREMENT. With the
## defect present the state this row just drove is UNRECOVERABLE within the
## session -- ESC restored the seize and a second ESC returns 0 -- so without
## this block every row after D3 would inherit a dead canvas and section S
## would red for D3's reason instead of its own. The repair is deliberately
## brute force (write the captured predecessors straight back) so that it
## cannot accidentally paper over a defect in pick_release itself: rows V6 and
## S1 are what test that, and they run on a canvas this block never touches.
kx_ans ::rdw::pick_end
array unset ::rdw::pick
foreach {_sq _vv} [list <ButtonPress-1> $PRE_P <ButtonRelease-1> $PRE_R \
                        <Key-Escape> $PRE_E <B1-Motion> $PRE_M] {
  catch {bind .drw $_sq $_vv}
}
kx_ans ::rdw::set_list annotation
kx_reset
xschem unselect_all
update idletasks

# ============================================================================
# SECTION S — HYGIENE, AND THE CONTROL THAT STOPS SECTION B PASSING VACUOUSLY
# ============================================================================
## An untracked untitled*.sch in the repo root turns THREE tests red. ⚠ The
## repo root ALREADY holds untitled~.sch and untitled~.sym and they are
## DELIBERATELY LEFT THERE (the known cause of test_ase_core's C11 baseline
## red, a phantom nothing in this batch may "fix"), so the row compares the
## glob against itself rather than asserting it is empty.
kx_ans ::rdw::pick_end
kx_ans ::rdw::close
catch {xschem raw clear}
update idletasks

catch {destroy .kxctl}
toplevel .kxctl
text .kxctl.t -width 24 -height 3
pack .kxctl.t
update idletasks
set S1_TRIES 0
while {$S1_TRIES < 12 && [string trim [.kxctl.t get 1.0 end]] eq {}} {
  incr S1_TRIES
  catch {focus -force .kxctl.t}
  catch {event generate .kxctl.t <Key-x> -when now}
  catch {update}
}
set S1_CTL [string trim [.kxctl.t get 1.0 end]]
catch {destroy .kxctl}
update idletasks

check {S1 HYGIENE and the CONTROL in one row: the suite creates no untitled* anywhere, leaves no window and no seize behind on any of the FOUR sequences, ends unsuspended - and the event-generate mechanism every binding row above depends on really does deliver, so B2..B5 cannot pass by delivering nothing} \
  [list [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S1_ROOT0 ? 1 : 0}] \
        [llength [glob -nocomplain -directory $scratch -tails untitled*]] \
        [llength [glob -nocomplain -directory $here -tails untitled*]] \
        [expr {[winfo exists .rdw] ? 1 : 0}] \
        [seized] \
        [bind .drw <B1-Motion>] \
        [expr {[lsort [bind .drw]] eq $PRE_SEQ ? 1 : 0}] \
        [kx_ans ::cmdmode::is_suspended] \
        $S1_CTL] \
  [list 1 0 0 0 0 $PRE_M 1 0 x]

# --- clean up ---------------------------------------------------------------
catch {rename ciw_echo {}}
# ============================================================================
# SECTION ESC — ISSUE 1308 / RULING DD-12: ESCAPE WORKS FROM THE TEXT PANE
# ============================================================================
# Issue 1306's fix let this window KEEP the keyboard when the user clicks the
# text pane -- which is the whole point of the feature, because the dumps exist
# to be selected and pasted into a design-review document. The consequence,
# measured immediately after: the mode's `1`/`2`/`3`/`4` and `<Key-Escape>` are
# bound on the CANVAS, so once the pane had the keyboard the mode's documented
# exit was DEAD.
#
# ⚠ ESCAPE ENDS THE MODE AND DOES NOT CLOSE THE WINDOW, and E4 is the row that
# holds that apart. Escape closes a dialog in many applications; this is not a
# dialog. It holds the artifact the feature exists to produce, and rdw::close's
# own comment records that losing those to a stray click is the worse failure.
# A stray Escape is the same accident with a different finger, so Escape does
# NOTHING when no mode is running -- never a destructive default.
# RED before the 1308 fix: E2, E3.

if {[rdw::have_tk]} {
  rdw::open ; update
  set E_START [rdw::pick_start]
  set E_RUN0  [rdw::pick_running]
  focus -force .rdw.p.t ; update
  set E_FOCUS [focus]
  set E_BOUND [expr {[bind .rdw <Key-Escape>] ne {} ? 1 : 0}]

  check {E1 the mode is live and the KEYBOARD IS IN THE TEXT PANE - the state the whole window exists to reach} \
    [list $E_START $E_RUN0 $E_FOCUS] {1 1 .rdw.p.t}

  check {E2 Escape is bound on the WINDOW, not only on the canvas the keyboard has left} \
    $E_BOUND 1

  event generate .rdw.p.t <Key-Escape> ; update
  check {E3 and pressing it THERE ends the mode, so the documented exit is reachable from the pane} \
    [rdw::pick_running] 0

  check {E4 ...and the window is STILL OPEN: Escape ends a mode, it does not throw away the dumps} \
    [expr {[winfo exists .rdw] ? 1 : 0}] 1

  event generate .rdw.p.t <Key-Escape> ; update
  check {E5 a STRAY Escape with no mode running does nothing at all - never a destructive default} \
    [list [rdw::pick_running] [expr {[winfo exists .rdw] ? 1 : 0}]] {0 1}
}

if {[llength [info commands kx_ciw_echo_real]]} { rename kx_ciw_echo_real ciw_echo }
catch {xschem raw clear}

# ============================================================================
# THE COUNT FLOOR — A SUITE THAT RUNS FEWER CHECKS MUST NOT STILL SAY ALL PASS
# ============================================================================
# ⚠ MEASURED 2026-09-04: item B2e's adversary saw this suite report
# **35 / 33 / 32 checks over five runs, every one of them "ALL PASS"**. A
# varying COUNT means rows were SKIPPED, not failed — several blocks here are
# guarded by `rdw::have_tk` or by `info commands`, and a guard that does not
# fire takes its rows with it silently.
#
# That is the worst shape a green result can have, and it is this batch's
# recurring lesson in its purest form: a green count is a statement about the
# FENCE, not about the code. The batch's whole acceptance discipline is a
# name-and-status diff, and a suite whose denominator moves underneath it
# cannot support one — B2e could not use this suite's number as evidence and
# said so.
#
# The driver could NOT reproduce the skid afterwards (5 runs at 35, and 5 more
# with the pointer parked at each of the positions that decide issue 1269, all
# 35), so the cause is still unnamed. THE FLOOR DOES NOT NEED THE CAUSE: it
# turns "silently ran fewer" into a red, whatever the reason.
#
# ⚠ IT IS A FLOOR, NOT AN EQUALITY, on purpose. Adding rows must not red the
# suite — item B5-2 will add several. Raise the floor when you add them; never
# lower it to make a run pass, which is the one move that would put the defect
# straight back.
set KX_FLOOR 35
set KX_RAN [expr {$npass + $fail}]
if {$KX_RAN < $KX_FLOOR} {
  puts "FAIL: KXFLOOR the suite ran only $KX_RAN checks, below its floor of\
$KX_FLOOR — rows were SKIPPED, and a skipped row is not a passing one : FAIL"
  incr fail
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
