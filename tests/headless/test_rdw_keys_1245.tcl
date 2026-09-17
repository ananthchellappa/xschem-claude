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

## ⚠ THE PROJECT SETTINGS FILE IS A SNAPSHOT, NOT AN ABSENCE (issue 1381).
## These rows used to assert that `<repo>/.xschem/op_param_lists.conf` did not
## exist, which was true only for as long as nothing ever SAVED one.  It is a
## legitimate user artifact -- `rdw::button save` with project scope writes
## exactly there, by design -- so a developer who has used the feature in their
## own tree redded this suite for having used it, and (worse) the obvious way
## to green it again is to delete their file.  That happened: a real saved list
## was destroyed because a red row read as litter.  What the row actually means
## is "SECTION SD WROTE NOTHING HERE", so take the file's identity up front and
## compare, the way the `untitled*` leg beside this one already does.
proc kx_conf_stamp {} {
  global repo
  set f [file join $repo .xschem op_param_lists.conf]
  if {![file exists $f]} { return {ABSENT} }
  if {[catch {list [file size $f] [file mtime $f]} st]} { return {UNREADABLE} }
  return $st
}
set S1_CONF0 [kx_conf_stamp]

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
##
## ⚠ AND THE LAST LEG MOVED 1 -> 0 WITH ISSUE 1369's FIX, DELIBERATELY. The
## hand-back's landing test now asks whether the keyboard is IN this window
## rather than ON its toplevel -- it has to, because after a click like this
## one Tk resolves every later grant to the child, so the old equality
## declined the window manager's grant for ever. That widened test can no
## longer tell this click from a grant, so the discriminator moved to the
## gesture: `rdw::_focus_click`, bound to <ButtonPress> on the toplevel tag,
## SPENDS the one-shot here. THE BEHAVIOUR THIS ROW EXISTS FOR IS UNCHANGED
## and is legs 6 and (through F4) the clipboard: the keyboard is still on the
## pane after the click. What moved is the flag, and it moved from "left armed
## for ever" to "spent by the gesture that made it ambiguous".
event generate .rdw.p.t <ButtonPress-1>   -x 4 -y 4 -when now
event generate .rdw.p.t <ButtonRelease-1> -x 4 -y 4 -when now
for {set _f 0} {$_f < 20} {incr _f} { update ; after 25 }
set F3_FOCUS1 [focus]
set F3_PEND1 [kx_pending]
check {F3 ISSUE 1306, THE USER'S HEADLINE REQUIREMENT: with the pointer parked off every window, a real first-of-session dump made, its post-dump focus read back on the CANVAS and the one-shot RE-ARMED ON PURPOSE - so the state the row names is guaranteed to exist rather than inherited - a real click into the text pane leaves the keyboard ON THE PANE, and (issue 1369) SPENDS the one-shot rather than leaving it armed, because a landing test that can see the whole window can no longer tell this click from the window manager's grant and the press is what tells them apart. The %W guard can tell neither, because X delivers a FocusIn to .rdw for both} \
  [list [expr {![string match {.drw*} $F3_PARK] && ![string match {.rdw*} $F3_PARK] ? 1 : 0}] \
        $F3_PRE0 $F3_PANE $F3_FOCUS0 $F3_REARM $F3_FOCUS1 $F3_PEND1] \
  {1 0 1 .drw 1 .rdw.p.t 0}

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

## LEAVE NOTHING BEHIND. The one-shot is cleared explicitly rather than left
## for the next row to inherit -- F3's own click spends it since issue 1369,
## but a row that depends on a previous row's side effect is the ordering trap
## this file's header is about.
catch {set ::rdw::focus_pending 0}

# ---------------------------------------------------------------------------
# F5 / F6 — ISSUE 1369: ONE CLICK IN THIS WINDOW USED TO STOP EVERY LATER DUMP
# HANDING THE KEYBOARD BACK
# ---------------------------------------------------------------------------
# THE USER'S WORDS: "When user is in print to RDW mode (1,2,3 key) and then
# clicks on an instance, RDW needs to be raised, but focus should return to the
# schematic window. Else, another click to look at another device's OP info
# does not have intended effect - it just focuses the schematic window and
# doesn't send the OP info for that device to RDW".
#
# WHAT IS REALLY WRONG, AND IT IS NOT THE MACHINERY -- IT IS ITS DECISION. Tk
# keeps a focus record PER TOPLEVEL. Once any window INSIDE .rdw has held the
# Tk focus, every later grant to .rdw is resolved by Tk to THAT CHILD: the
# toplevel receives a FocusIn with detail NotifyVirtual while [focus] already
# reads the child. rdw::_focus_handback decided on EXACT equality against
# `.rdw`, so from the first click in this window onwards it declined every
# grant, the one-shot stayed armed for ever, and the window kept the keyboard
# after every dump. MEASURED on :99 under openbox in a minimal two-toplevel Tk
# program, keyboard parked in the other window before each re-map:
#     record clean           re-map -> FocusIn .t d=NotifyAncestor [focus] .t
#     after one pane click   re-map -> FocusIn .t d=NotifyVirtual  [focus] .t.p
# and with the shipped decision in that program the dump left the keyboard on
# .t.p, which is the user's sentence.
#
# ⚠ ONE ORDINARY GESTURE WRITES THAT RECORD, and it is the gesture the Add and
# Delete buttons ask for -- "I put cursor on cgs and the clicked Add button"
# (item 1372) IS this click. tk::TextButton1 calls `focus $w` UNCONDITIONALLY
# (/usr/share/tcltk/tk8.6/text.tcl:579), unlike tk::EntryButton1, which skips a
# `disabled` widget (entry.tcl:356), so `-state disabled` keeps the keyboard
# out of NEITHER text widget in this window. F5 uses the pane and F6 the status
# surface, because both pollute and only one of them is obvious: .rdw.s.msg is
# `-takefocus 0` as well and still takes the keyboard on a press.
#
# ⚠ THE GRANT IS SYNTHESISED, AND HERE IS WHY IT HAS TO BE. On :99 the dump
# path's own `focus -force` BEATS the window manager's map-time grant -- also
# measured in that minimal program: a bare re-map moves the keyboard to the
# re-mapped toplevel, the same re-map followed at once by the client's own
# `focus -force` leaves it where it was and no FocusIn ever arrives at all. So
# the grant cannot be provoked end to end on this display, and a row that
# waited for one would pass while the defect is live. What CAN be reproduced
# exactly is the DECISION, and these rows reproduce all three of its inputs
# verbatim: %W is `.rdw`, [focus] is the child the user's own click left the
# keyboard on, and the one-shot is armed. The detail is NotifyVirtual because
# that is the one Tk itself delivers to the toplevel when a grant is re-routed
# to the record.
#
# RED AT HEAD, MEASURED, both rows: focus stays on the child and pending stays
# 1 -- the window keeps the keyboard and the flag is never spent again.

kx_reset
catch {destroy .rdw}
update idletasks
xschem unselect_all
xschem select instance M1
kx_ans ::rdw::key annotation
for {set _f 0} {$_f < 20} {incr _f} { update ; after 25 }
set F5_PANE [expr {[winfo exists .rdw.p.t] ? 1 : 0}]
focus -force .drw
for {set _f 0} {$_f < 6} {incr _f} { update ; after 25 }
## THE USER'S OWN GESTURE, and what it does to the keyboard is leg 2 rather
## than an assumption: a real press in a `-state disabled` text pane takes it.
event generate .rdw.p.t <ButtonPress-1>   -x 4 -y 4 -when now
event generate .rdw.p.t <ButtonRelease-1> -x 4 -y 4 -when now
for {set _f 0} {$_f < 20} {incr _f} { update ; after 25 }
set F5_LAND [focus]
## AND NOW THE DUMP: the one-shot armed exactly as rdw::_raise arms it, then
## the grant, delivered as the toplevel FocusIn Tk itself delivers.
catch {set ::rdw::focus_pending 1}
set F5_ARM [kx_pending]
event generate .rdw <FocusIn> -detail NotifyVirtual -when now
for {set _f 0} {$_f < 8} {incr _f} { update ; after 25 }
set F5_FOCUS [focus]
set F5_PEND [kx_pending]
check {F5 ISSUE 1369, THE USER'S OWN SEQUENCE: after ONE real Button-1 in the results pane - the click the Add and Delete buttons require - a dump's focus grant must still hand the keyboard back to the CANVAS and spend the one-shot. Tk resolves that grant to the child the click focused, so a hand-back that compares the landing against the exact toplevel declines it for ever and the window keeps the keyboard, which is why the user's next canvas click only re-focuses the schematic and sends no dump} \
  [list $F5_PANE $F5_LAND $F5_ARM $F5_FOCUS $F5_PEND] \
  {1 .rdw.p.t 1 .drw 0}

## F6 RUNS ON THE WINDOW F5 LEFT, and clicks the OTHER text widget. The status
## surface is `-takefocus 0` and `-state disabled`, which is exactly why it
## reads as harmless and is not: it writes the same record.
focus -force .drw
for {set _f 0} {$_f < 6} {incr _f} { update ; after 25 }
set F6_MSG [expr {[winfo exists .rdw.s.msg] ? 1 : 0}]
event generate .rdw.s.msg <ButtonPress-1>   -x 4 -y 4 -when now
event generate .rdw.s.msg <ButtonRelease-1> -x 4 -y 4 -when now
for {set _f 0} {$_f < 20} {incr _f} { update ; after 25 }
set F6_LAND [focus]
catch {set ::rdw::focus_pending 1}
set F6_ARM [kx_pending]
event generate .rdw <FocusIn> -detail NotifyVirtual -when now
for {set _f 0} {$_f < 8} {incr _f} { update ; after 25 }
set F6_FOCUS [focus]
set F6_PEND [kx_pending]
check {F6 ISSUE 1369, THE SURFACE NOBODY SUSPECTS: a real Button-1 on the status line - takefocus 0, state disabled - takes the keyboard just as the pane does, because tk::TextButton1 does not check the state, and a dump after it must still hand the keyboard back to the CANVAS and spend the one-shot} \
  [list $F6_MSG $F6_LAND $F6_ARM $F6_FOCUS $F6_PEND] \
  {1 .rdw.s.msg 1 .drw 0}

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
# SECTION KS — ISSUE 1322: THE CAPTURE HAPPENS ON THE SHIPPED KEY PATH
# ============================================================================
# Issue 1322's fix makes `rdw::push` record WHAT A BLOCK WAS ABOUT — instance,
# symbol type, cell and sheet — at DUMP TIME, so a button pressed after a
# schematic load edits the device the block came from instead of re-resolving
# the header's bare name against whatever sheet is open. The window suite's
# section BS drives that through `rdw::push` directly, on both arms.
#
# ⚠ WHAT NO OTHER ROW IN EITHER SUITE DOES IS DRIVE IT THROUGH THE REAL
# KEYBINDING. The shipped path is
#     cadence_style_rc's `bind .drw <Key-1>` -> rdw::key -> rdw::_selected_instance
#     -> rdw::show -> rdw::open -> rdw::dump -> rdw::dump_devpath -> rdw::push
# and the capture sits at the very end of it. A capture wired only into a
# hand-called `push` would pass every row of section BS and record nothing at
# all for a user pressing 1 — which is the only way anyone will ever reach it.
# That is this batch's own recurring failure (a provider tested against its own
# tests, then met by its consumer), so it gets a row on the path the user uses.
#
# ⚠ AND `rdw::dump_devpath` (rdw.tcl:749-750) PUSHES `$blk` AND RETURNS `$blk`,
# not push's answer. Once push stamps, this row reads the STORE — which is what
# the buttons read too — so it stays true whichever way that return is fixed;
# row Q1b of the window suite is the one that pins the return itself.
#
# RED BEFORE THE FIX: KS1, for one reason — `rdw::block_subject` is not a
# command, so kx_ans answers NOPROC. Its first four legs are the control that
# says the key really arrived.

proc ks_key {blk k} {
  set s [kx_ans ::rdw::block_subject $blk]
  if {[kx_bad $s]} { return $s }
  if {$s eq {}} { return NOSUBJ }
  if {[catch {dict get $s $k} v]} { return "NOKEY:$k" }
  return $v
}
proc ks_tail {blk k} {
  set v [ks_key $blk $k]
  if {[kx_bad $v] || $v eq {NOSUBJ} || [string match {NOKEY:*} $v]} { return $v }
  return [file tail $v]
}

kx_ans ::rdw::pick_end
kx_reset
xschem unselect_all
## The list is parked on `summary` first, so the bare 1 below moves it to
## `annotation` and that move is a POSITIVE RECEIPT that the cadence bind
## delivered and rdw::key ran — section D3's own idiom, one key over.
kx_ans ::rdw::set_list summary
xschem select instance M1
update idletasks
set KS1_LK0 [kx_listkind]
set KS1_N0 [kx_nblocks]
set KS1_SEL0 [kx_sel]
focus -force .drw ; update idletasks
event generate .drw <Key-1> -when now
update
set KS1_BLK [lindex $::rdw::blocks 0]
## Snapshotted BEFORE the second load below, because the load clears the
## editor's selection and this leg is about what the KEY did to it.
set KS1_LK1  [kx_listkind]
set KS1_N1   [kx_nblocks]
set KS1_HDR1 [kx_top_hdr]
set KS1_SELOK [expr {[kx_sel] eq $KS1_SEL0 ? 1 : 0}]

## ⚠ AND THE SECOND HALF IS WHAT MAKES THE FIRST ONE MEAN ANYTHING, MEASURED BY
## THIS ITEM'S OWN SABOTAGE RUN. With `rdw::block_subject` replaced by a LIVE
## re-resolution - the shipped defect restored exactly, sabotage variant
## SAB-RESOLVE-LATE - every leg above STILL PASSED, because the sheet the key
## was pressed on is still the sheet that is open. A fence that the deletion of
## its own subject cannot red is this batch's recurring failure, met for the
## ninth time. So the row now loads a SECOND top-level sheet whose `M1` is a
## DIFFERENT type - `M1` being the default template name of every device symbol
## in this tree, which is why the collision is the ordinary case - and reads the
## stored subject again. It must still name b4dev, b4dev.sym and b4top.sch while
## the editor is showing something else, and the live re-resolution leg is the
## receipt that the sheet really changed under it.
set KS_OSYM [file join $scratch ksother.sym]
set fd [open $KS_OSYM w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}"
puts $fd "G {}"
puts $fd "K {type=ksdev"
puts $fd {format="@spiceprefix@name @pinlist @model"}
puts $fd "template=\"name=M1 model=ksdev spiceprefix=X\""
puts $fd "}"
puts $fd "V {}"
puts $fd "S {}"
puts $fd "E {}"
puts $fd "L 4 -20 -20 20 -20 {}"
puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
close $fd
set KS_OSCH [file join $scratch ksother.sch]
set fd [open $KS_OSCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$KS_OSYM\} 300 -300 0 0 \{name=M1\}"
close $fd
xschem unselect_all
xschem load $KS_OSCH
update idletasks
set KS1_LIVE [kx_ans ::op_annot::type M1]
set KS1_SCH2 [file tail [kx_ans xschem get schname]]
set KS1_BLK2 [lindex $::rdw::blocks 0]
## ⚠ SNAPSHOTTED WHILE THE OTHER SHEET IS STILL OPEN, AND THAT IS THE WHOLE
## ROW. `check` evaluates its argument list when it is CALLED, so reading these
## three after the restore below would re-ask the question with the original
## sheet back on screen - and a live re-resolution would answer b4dev again and
## pass. Measured: the first version of this leg did exactly that, and sabotage
## variant SAB-RESOLVE-LATE stayed green through it.
set KS1_T2 [ks_key  $KS1_BLK2 type]
set KS1_C2 [ks_tail $KS1_BLK2 cellname]
set KS1_S2 [ks_tail $KS1_BLK2 schname]
xschem load $KX_SCH
xschem zoom_full
update idletasks
check {KS1 THE CAPTURE IS ON THE SHIPPED PATH, AND IT SURVIVES A LOAD: a real bare 1 on the canvas over a SELECTED device runs the whole noun-verb chain - bind, rdw::key, rdw::show, rdw::dump, rdw::dump_devpath, rdw::push - and the block it stores carries the subject of THAT device, named by its own symbol type, its own cell and the sheet it was dumped from; the list identity moving from summary to annotation is the receipt that the key arrived, and after a SECOND top-level sheet whose own M1 is a different type is loaded the stored block still names the first one while a live re-resolution answers the second} \
  [list $KS1_LK0 $KS1_N0 $KS1_LK1 $KS1_N1 $KS1_HDR1 \
        $KS1_SELOK \
        [ks_key $KS1_BLK instname] [ks_key $KS1_BLK type] \
        [ks_tail $KS1_BLK cellname] [ks_tail $KS1_BLK schname] \
        $KS1_LIVE $KS1_SCH2 $KS1_T2 $KS1_C2 $KS1_S2] \
  [list summary 0 annotation 1 {M1:/} 1 M1 b4dev b4dev.sym b4top.sch \
        ksdev ksother.sch b4dev b4dev.sym b4top.sch]

kx_ans ::rdw::close
kx_reset
xschem unselect_all
kx_ans ::rdw::set_list annotation
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

# ============================================================================
# SECTION SD — ITEM B5: THE SCOPE DIALOG, DRIVEN FOR REAL AND NEVER HANGING
# ============================================================================
# ⚠ THIS IS THE ROW SET ISSUE 0803 IS ABOUT, AND IT IS WHY THE DIALOG'S SHAPE
# WAS FIXED IN B5's FIRST COMMIT RATHER THAN RETROFITTED. A suite that reaches
# a `tkwait window` with nobody to click it does not FAIL - it HANGS, and takes
# the whole audit with it. The tree has exactly one place that exercises a real
# modal safely, tests/headless/test_ase_bus_bits_0159.tcl:387-407, and this
# section was copied from it verbatim in shape:
#   after 100  {invoke the widgets}      drives it while it is blocked
#   after 5000 {destroy the toplevel}    the DEADMAN: if the first timer never
#                                        fires the window goes away anyway and
#                                        tkwait returns, so this can never hang
# ⚠ AND THE FIRST HALF OF THAT IDIOM IS NOW GONE, BECAUSE IT FLAKED (issue
# 1332). `after 100` is a BET that the dialog is up by then, and it was lost on
# 2 of 2 runs on the user's own VcXsrv server. The invoke half is now a POLL
# (`sd_arm` / `sd_poll_modal`, just below the fixture) that waits for the
# dialog to exist AND hold its grab; the deadman half is unchanged and still
# not optional. The two shapes the bet loses, and what each costs, are measured
# in the comment on `sd_arm` and fenced by rows SD5, SD6 and SD7.
# The consumer rows - what a Delete or an Add DOES with the answer - are in
# test_rdw_window_1245.tcl's section BT, under the `rename`-not-`proc` stub
# idiom, and run on BOTH arms. This section drives the widgets themselves,
# which needs a display and therefore lives here.
#
# ⚠ AND THE OTHER HALF OF THE 0803 ANSWER IS ASSERTED IN THE WINDOW SUITE, NOT
# HERE: row BT9 drives the real wrapper on the --nogui arm, where it must
# answer Cancel and RETURN rather than block. A dialog that can only be safe
# when a display is present is not safe.
#
# THE CONTRACT (spelled in full in test_rdw_window_1245.tcl's section BT):
#   rdw::scope_dialog {op subject listname} -> {scope narrow|broad list
#         annotation|summary}, or {} for Cancel
#   .rdw.scope             the child toplevel
#   .rdw.scope.sc.narrow   .rdw.scope.sc.broad          the scope choice
#   .rdw.scope.li.annotation .rdw.scope.li.summary      the which-list choice,
#                          built only when the identity is `all`
#   .rdw.scope.btns.ok     .rdw.scope.btns.cancel
#
# RED BEFORE B5: all three, for one reason - rdw::scope_dialog is not a command
# and rdw::button is not either.

if {[kx_ans ::rdw::have_tk] eq {1}} {
  set SD_ROOT [file join $scratch b5sd]
  file mkdir $SD_ROOT
  proc sd_mksym {path type} {
    set fd [open $path w]
    puts $fd "v {xschem version=3.4.5 file_version=1.2}"
    puts $fd "G {}"
    puts $fd "K {type=$type"
    puts $fd {format="@spiceprefix@name @pinlist @model"}
    puts $fd "template=\"name=M1 model=$type spiceprefix=X\""
    puts $fd "}"
    puts $fd "V {}"
    puts $fd "S {}"
    puts $fd "E {}"
    puts $fd "L 4 -20 -20 20 -20 {}"
    puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
    puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
    close $fd
  }
  set SD_SYMN [file join $SD_ROOT b5n.sym]
  set SD_SYMP [file join $SD_ROOT b5p.sym]
  sd_mksym $SD_SYMN b5ndev
  sd_mksym $SD_SYMP b5pdev
  set SD_SCH [file join $SD_ROOT b5.sch]
  set _fd [open $SD_SCH w]
  puts $_fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$SD_SYMN\} 300 -300 0 0 \{name=M1\}
C \{$SD_SYMP\} 300 -120 0 0 \{name=M2\}"
  close $_fd
  catch {xschem raw clear}
  set SD_LOAD [catch {xschem load $SD_SCH}]
  update idletasks
  set SD_DESC [list devpath {\@m.@path@name} \
                    params {{id ids 0} {gm gm 1} {gds gds 1}}]
  catch {op_annot::register b5ndev $SD_DESC}
  catch {op_annot::register b5pdev $SD_DESC}
  kx_ans ::op_param_lists::reset
  kx_ans ::op_param_lists::set_class b5ndev b5cls
  kx_ans ::op_param_lists::set_class b5pdev b5cls
  set SD_CELL1 [expr {[catch {xschem getprop instance M1 cell::name} _c] ? {} : $_c}]
  set SD_SUBJ [dict create instname M1 type b5ndev class b5cls cellname $SD_CELL1]

  proc sd_pair {d} {
    if {[kx_bad $d]} { return $d }
    if {$d eq {}} { return CANCELLED }
    if {[catch {list [dict get $d scope] [dict get $d list]} p]} { return "BADANS:$d" }
    return $p
  }
  proc sd_blk {inst dp pairs} {
    set ans [dict create devices [list $dp $pairs] absent {} nonfinite {} \
                         complete 0 state ok]
    set ctx [dict create header "$inst:/" devpath $dp simtype op instname $inst \
                         sim ngspice]
    return [kx_ans ::rdw::format_answer $ans $ctx]
  }
  proc sd_blocks {} {
    set ::rdw::blocks {}
    kx_ans ::rdw::push [sd_blk M1 @m.m1 {{ids 1.2e-05} {gm 3.4e-05} {gds 5.6e-06}}]
    kx_ans ::rdw::push [sd_blk M2 @m.m2 {{ids 9.9e-06}}]
    return {}
  }

  # --- THE MODAL DRIVER: A POLL, NEVER A FIXED DELAY (issue 1332) -----------
  ## ⚠ THIS SECTION USED TO ARM ITS DRIVER ON A BARE `after 100`, COPIED IN
  ## SHAPE FROM tests/headless/test_ase_bus_bits_0159.tcl:387-407, AND IT
  ## FLAKED FOR IT. The delay is a bet that the dialog is up by then. Losing
  ## the bet is not a hang and not a loud failure - every `catch` inside the
  ## driver hits nothing, the deadman cancels the dialog 4.9 s later, and the
  ## row reports a PLAUSIBLE all-zeros tuple.
  ##
  ## MEASURED, both losing shapes, deterministically (scratchpad probes; the
  ## delay was installed on a wrapper around `rdw::scope_dialog_build` and the
  ## repo file was never touched):
  ##
  ##   delay BEFORE the toplevel is built (300 ms):
  ##     fixed `after 100` -> {0 0 0 {} 0 0 {}} in 5004 ms   <- issue 1332's
  ##                          own recorded tuple, byte for byte
  ##     poll              -> the expected tuple in 315 ms
  ##   delay AFTER the build but BEFORE `focus -force $w` (200 ms):
  ##     fixed `after 100` -> the Escape is REDIRECTED to the display's focus
  ##                          window, which is still `.drw`, so it ends the
  ##                          user's canvas command mode: run1 0, expected 1
  ##                          - that is SD2's failure on the user's VcXsrv
  ##     poll              -> run1 1, in 205 ms
  ##
  ## So the poll waits for BOTH conditions, and they are the right two:
  ## `rdw::scope_dialog` sets the grab and forces the focus with NO event loop
  ## between them and `tkwait window`, so a driver that sees a grab is running
  ## from inside `tkwait` on a dialog that is fully modal and already holds the
  ## keyboard. Waiting on `winfo exists` alone would still lose the second
  ## shape: the toplevel exists all through the build's own `update`.
  ##
  ## THE DEADMAN IS UNCHANGED AND STILL NOT OPTIONAL (issue 0803): `tkwait`
  ## must return even if the driver never runs. The poll gives up on whichever
  ## comes first, 900 polls or a wall-clock deadline 500 ms short of the
  ## deadman, so a poll that never sees its dialog stops rather than driving
  ## whatever is on screen later. ⚠ THE POLL COUNT ALONE IS NOT THE 4.5 s THIS
  ## PARAGRAPH USED TO CLAIM: `after 5` is a floor, and a measured give-up ran
  ## 6.5 s at load avg 54 - past the deadman, under exactly the contention the
  ## poll exists for. See the deadline comment on `sd_arm`.
  ##
  ## AND BOTH TIMERS ARE CANCELLED WHEN THE ROW ENDS. They used to be left
  ## armed: SD1's 5 s deadman was still live while SD3b's dialog was up, one
  ## `catch {destroy .rdw.scope}` away from cancelling a dialog a later row was
  ## in the middle of driving.
  set ::SD_POLL_ID {} ; set ::SD_DEADMAN {} ; set ::SD_POLLS 0
  set ::SD_GAVEUP 0   ; set ::SD_RAN 0 ; set ::SD_DEADLINE 0
  ## ⚠ ARMING DISARMS FIRST, AND THAT IS NOT TIDINESS. Blanking `::SD_POLL_ID`
  ## and overwriting `::SD_DEADMAN` throws the previous chain's handles away
  ## while the chain itself keeps running, so `sd_disarm` can no longer reach
  ## it. Under the old fixed `after 100` a stray timer was a ONE-SHOT that
  ## fired once within 100 ms and almost certainly inside its own row; a poll
  ## is a SELF-RE-ARMING chain that lives seconds, i.e. across several rows,
  ## and it will press broad+OK on whatever dialog a later row has up. DRIVEN
  ## by issue 1332's adversary: one extra `sd_arm` before SD2's own, with no
  ## dialog in that row, reds SD2. The chain is a stronger version of the very
  ## flake class this section was written to remove.
  proc sd_arm {script {budget 900} {deadman 5000}} {
    sd_disarm
    set ::SD_POLLS 0 ; set ::SD_GAVEUP 0 ; set ::SD_RAN 0
    ## ⚠ AND THE GIVE-UP IS A WALL-CLOCK DEADLINE AS WELL AS A POLL COUNT.
    ## `after 5` is a FLOOR, not a period: this comment used to call 900 polls
    ## "4.5 s, deliberately INSIDE the 5 s deadman", and issue 1332's
    ## adversary measured a full give-up at 4856-4986 ms at load avg 25 and
    ## 6028-6524 ms at load avg 54 - 1.0 to 1.5 s PAST the deadman it was
    ## claimed to sit inside, under exactly the contention the poll exists
    ## for. Whichever limit is reached first stops the chain, so the stated
    ## safety property is now true at any load, and a SMALL budget (SD7A
    ## passes 10) still gives up on its poll count the way that row asserts.
    set ::SD_DEADLINE [expr {[clock milliseconds] + $deadman - 500}]
    set ::SD_POLL_ID {}
    set ::SD_DEADMAN [after $deadman {catch {destroy .rdw.scope}}]
    sd_poll_modal $script $budget
    return {}
  }
  proc sd_poll_modal {script budget} {
    set ::SD_POLL_ID {}
    incr ::SD_POLLS
    ## ⚠ THE GRAB MUST BE THE DIALOG'S. A bare `grab current` answers for
    ## EVERY grab this application holds on any display, so the "exact pair"
    ## the comment above describes was not exact: issue 1332's adversary
    ## armed one unrelated `grab set .rdw` and the poll fired during the
    ## build's own `update`, with the focus still on `.drw`, reding SD2
    ## exactly as the old fixed timer did. Naming the window restores the
    ## pair the comment claims.
    if {[winfo exists .rdw.scope] && [grab current] eq {.rdw.scope}} {
      set ::SD_RAN 1
      uplevel #0 $script
      return
    }
    if {$::SD_POLLS >= $budget || [clock milliseconds] >= $::SD_DEADLINE} {
      set ::SD_GAVEUP 1 ; return
    }
    set ::SD_POLL_ID [after 5 [list sd_poll_modal $script $budget]]
  }
  proc sd_disarm {} {
    if {$::SD_POLL_ID ne {}} { catch {after cancel $::SD_POLL_ID} }
    if {$::SD_DEADMAN ne {}} { catch {after cancel $::SD_DEADMAN} }
    set ::SD_POLL_ID {} ; set ::SD_DEADMAN {} ; set ::SD_DEADLINE 0
    return {}
  }
  ## The sabotage rows below delay the real build by spinning the EVENT LOOP,
  ## which is what display contention does to this path on a loaded box - a
  ## busy-wait would prove nothing, because no timer can fire while Tcl is not
  ## in the event loop. `rename`, never `proc` (test_ase_bus_bits_0159.tcl:129).
  proc sd_slow_install {when ms} {
    set ::SD_SLOW_WHEN $when ; set ::SD_SLOW_MS $ms
    if {![llength [info commands ::rdw::sd_real_build]]} {
      rename ::rdw::scope_dialog_build ::rdw::sd_real_build
    }
    proc ::rdw::scope_dialog_build {args} {
      if {$::SD_SLOW_WHEN eq {before}} { sd_spin $::SD_SLOW_MS }
      set w [uplevel 1 [linsert $args 0 ::rdw::sd_real_build]]
      if {$::SD_SLOW_WHEN eq {after}} { sd_spin $::SD_SLOW_MS }
      return $w
    }
    return {}
  }
  proc sd_slow_none {} {
    set ::SD_SLOW_WHEN none
    if {![llength [info commands ::rdw::sd_real_build]]} {
      rename ::rdw::scope_dialog_build ::rdw::sd_real_build
    }
    proc ::rdw::scope_dialog_build {args} { return NO-DIALOG-EVER-BUILT }
    return {}
  }
  proc sd_slow_remove {} {
    if {[llength [info commands ::rdw::sd_real_build]]} {
      catch {rename ::rdw::scope_dialog_build {}}
      rename ::rdw::sd_real_build ::rdw::scope_dialog_build
    }
    set ::SD_SLOW_WHEN none
    return [llength [info commands ::rdw::scope_dialog_build]]
  }
  proc sd_spin {ms} {
    set ::SD_SPIN_GATE 0
    after $ms {set ::SD_SPIN_GATE 1}
    vwait ::SD_SPIN_GATE
    return {}
  }

  # --- SD1  THE REAL MODAL, DRIVEN, WITH A DEADMAN --------------------------
  ## ⚠ THE POINTER IS PARKED SOMEWHERE NEUTRAL FIRST (issue 1269). A raise
  ## followed by a focus-dependent read INHERITS the pointer position, and
  ## parking it onto the very window whose state is asserted is the same bug
  ## wearing a fix. The canvas is not the dialog and not the button column.
  catch {event generate .drw <Motion> -x 5 -y 5 -when now}
  update
  kx_ans ::rdw::open
  sd_blocks
  update idletasks
  set SD1_TL {}
  sd_arm {
    catch {set ::SD1_TL [bindtags .rdw.scope]}
    catch {.rdw.scope.sc.narrow invoke}
    catch {.rdw.scope.btns.ok invoke}
  }
  set SD1_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  update
  sd_disarm
  check {SD1 the REAL scope dialog, through its real wrapper and its real widgets: narrow + OK answers this device flavor only for the list it was opened on, and it leaves NO grab and NO window behind - driven with a timer and a deadman, so it cannot hang the suite (issue 0803)} \
    [list [sd_pair $SD1_GOT] \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] \
          [grab current] \
          [expr {[llength $SD1_TL] > 0 && [lsearch -exact $SD1_TL .rdw] < 0 ? 1 : 0}]] \
    [list {narrow annotation} 0 {} 1]

  # --- SD2  ESCAPE IS CANCEL, AND IT DOES NOT END THE CANVAS MODE -----------
  ## ⚠ SD1's LAST LEG READS THE BINDTAGS FROM INSIDE THE TIMER, WHILE THE
  ## DIALOG IS ALIVE, AND REQUIRES THEM TO BE NON-EMPTY. A bare `lsearch < 0`
  ## over an empty list is TRUE, so the leg would have passed in the RED state
  ## - where no dialog is ever built - and gone on passing against a dialog
  ## that never existed. This row's whole subject is measured below.
  ## MEASURED while planning B5: a child toplevel `.rdw.scope` has bindtags
  ## {.rdw.scope Toplevel all} and does NOT inherit `.rdw`'s ruling DD-12
  ## Escape, so the dialog can bind its own Cancel with no collision. This row
  ## is that measurement as a fence: a dialog that inherited `.rdw`'s binding
  ## would silently END THE COMMAND MODE the user is in the middle of.
  kx_ans ::rdw::pick_start
  set SD2_RUN0 [kx_ans ::rdw::pick_running]
  sd_arm {catch {event generate .rdw.scope <Key-Escape> -when now}}
  set SD2_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  update
  sd_disarm
  set SD2_RUN1 [kx_ans ::rdw::pick_running]
  kx_ans ::rdw::pick_end
  check {SD2 Escape on the scope dialog is CANCEL - it answers nothing and stores nothing - and it does NOT end a live canvas command mode, because the child toplevel does not inherit the window's own DD-12 Escape} \
    [list $SD2_RUN0 [sd_pair $SD2_GOT] $SD2_RUN1 \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] [grab current]] \
    [list 1 CANCELLED 1 0 {}]

  # --- SD3  THE CURSOR RULE, END TO END, WITH A REAL CLICK ------------------
  ## nhse's own rule - "the row your cursor is in" - through a REAL Button-1 in
  ## a `-state disabled` text pane and a REAL button invoke, with the store
  ## read back afterwards. The dialog is stubbed for this row only: the subject
  ## here is the TARGET, not the modal, and SD1 already drove the modal.
  ## `rename`, never `proc` (test_ase_bus_bits_0159.tcl:129).
  if {[llength [info commands ::rdw::scope_dialog]]} {
    rename ::rdw::scope_dialog ::rdw::sd_real_scope_dialog
  }
  ## ⚠ THE TWO TYPES ARE IN TWO DIFFERENT CLASSES, BY ITEM B5-2 (issue 1314).
  ## They used to share `b5cls`, and with one class "the newest block" and "the
  ## row the cursor is in" write a BYTE-IDENTICAL store - the row was measured
  ## green under two opposite sabotages. Giving M2 a parameter M1 lacks does not
  ## help either: the parameter is read from `rdw::_locate`'s pane line and
  ## never from the subject, so the store write is unchanged. Only a differing
  ## CLASS makes the two rules disagree, and the last leg is where it shows.
  proc ::rdw::scope_dialog {args} { return {scope broad list annotation} }
  kx_ans ::op_param_lists::reset
  kx_ans ::op_param_lists::set_class b5ndev b5cls
  kx_ans ::op_param_lists::set_class b5pdev b5pcls
  sd_blocks
  kx_ans ::rdw::set_list annotation
  update idletasks
  set SD3_BB {}
  catch {set SD3_BB [.rdw.p.t bbox 9.4]}
  if {[llength $SD3_BB] == 4} {
    set _px [expr {[lindex $SD3_BB 0] + 1}]
    set _py [expr {[lindex $SD3_BB 1] + [lindex $SD3_BB 3] / 2}]
    catch {event generate .rdw.p.t <Motion>          -x $_px -y $_py -when now}
    catch {event generate .rdw.p.t <ButtonPress-1>   -x $_px -y $_py -when now}
    catch {event generate .rdw.p.t <ButtonRelease-1> -x $_px -y $_py -when now}
    update
  }
  set SD3_LINE [kx_ans ::rdw::_target_line]
  catch {.rdw.b.delete invoke}
  update
  ## ⚠ AND THE NO-SELECTION CONDITION IS A LEG, NOT AN ASSUMPTION.  Since the
  ## user's ruling a standing selection is what Add and Delete act on; the
  ## shaded row is the target when there is none, which is exactly what a real
  ## <Button-1> leaves behind (the Text class binding clears `sel`).  Asserting
  ## it keeps this row a statement about the CURSOR rather than a row that is
  ## green because of a state nobody wrote down.
  set SD3_SEL 0
  catch {set SD3_SEL [llength [.rdw.p.t tag ranges sel]]}
  check {SD3 the cursor rule end to end: a REAL Button-1 in the read-only pane clears any selection and sets the target row, and a REAL Delete invoke then acts on THAT row and no other - the store loses `ids`, keeps the two rows the cursor was not on, and the NEWEST block's own class is left unowned, so acting on the newest dump instead of the cursor's would red this row} \
    [list [expr {[llength $SD3_BB] == 4 ? 1 : 0}] $SD3_LINE $SD3_SEL \
          [kx_ans ::op_param_lists::owns class b5cls annotation] \
          [kx_ans ::op_param_lists::get_list class b5cls annotation] \
          [kx_ans ::op_param_lists::owns class b5pcls annotation]] \
    [list 1 9 0 1 {{gm gm 1} {gds gds 1}} 0]

  # --- SD3b  THE REAL DIALOG, WITH NO STUB ANYWHERE (issue 1314) ------------
  ## ⚠ THE REAL SCOPE DIALOG GOES BACK BEFORE THIS ROW, AND THAT IS THE ROW'S
  ## WHOLE SUBJECT. Rows BT10, BT12 and BT17 of the window suite install their
  ## answer by RENAMING `rdw::scope_dialog`, and SD3 above does the same - so
  ## every one of them stays green under a sabotage in which no toplevel is ever
  ## CONSTRUCTED. Nothing on the --nogui arm can see that, and nothing here saw
  ## it either until this row existed. SD1 drives `rdw::scope_dialog` directly;
  ## this row drives it the way a user does, through `.rdw.b.delete invoke`, so
  ## the widget, the greying fence, the target rule, the modal and the store are
  ## all on one path with no stub between them.
  ##
  ## THE DEADMAN IS NOT OPTIONAL (issue 0803). `after 100` drives the dialog
  ## while it is blocked in `tkwait`; `after 5000` destroys the toplevel if the
  ## first timer never fires, so `tkwait` returns either way and the suite
  ## cannot hang. Copied in shape from tests/headless/test_ase_bus_bits_0159.tcl
  ## lines 263-280, the tree's only safe real-modal drive.
  catch {rename ::rdw::scope_dialog {}}
  if {[llength [info commands ::rdw::sd_real_scope_dialog]]} {
    rename ::rdw::sd_real_scope_dialog ::rdw::scope_dialog
  }
  kx_ans ::op_param_lists::reset
  kx_ans ::op_param_lists::set_class b5ndev b5cls
  kx_ans ::op_param_lists::set_class b5pdev b5pcls
  kx_ans ::op_param_lists::said_clear
  sd_blocks
  kx_ans ::rdw::set_list annotation
  kx_ans ::rdw::set_row 10
  update idletasks
  set ::SD3B_SEEN 0
  set ::SD3B_GRAB {}
  sd_arm {
    catch {set ::SD3B_SEEN [expr {[winfo exists .rdw.scope] ? 1 : 0}]}
    catch {set ::SD3B_GRAB [grab current]}
    catch {.rdw.scope.sc.broad invoke}
    catch {.rdw.scope.btns.ok invoke}
  }
  catch {.rdw.b.delete invoke}
  update
  sd_disarm
  check {SD3b a REAL .rdw.b.delete invoke really BUILDS the scope dialog - no stub anywhere on the path - the dialog held a grab while it was up, broad + OK moved the class list the cursor's own block belongs to, the OTHER class was left unowned, and nothing is left behind (issue 0803's deadman, issue 1314's stub shadow)} \
    [list $::SD3B_SEEN \
          [expr {$::SD3B_GRAB ne {} ? 1 : 0}] \
          [kx_ans ::op_param_lists::owns class b5cls annotation] \
          [kx_ans ::op_param_lists::get_list class b5cls annotation] \
          [kx_ans ::op_param_lists::owns class b5pcls annotation] \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] \
          [grab current]] \
    [list 1 1 1 {{id ids 0} {gds gds 1}} 0 0 {}]


  # --- SD5  THE FLAKE ITSELF, MADE DETERMINISTIC (issue 1332) ---------------
  ## THE ROW THAT WOULD HAVE CAUGHT IT. SD3b's shape with the dialog's
  ## construction deliberately delayed past the old 100 ms timer, by spinning
  ## the EVENT LOOP - which is what a contended X display does to this path,
  ## and the only kind of delay a timer can fire during. Under the old
  ## `after 100` this row is issue 1332's own recorded failure, byte for byte:
  ##     {0 0 0 {} 0 0 {}}  in 5004 ms, the deadman
  ## and note what that tuple LOOKS like - a plausible "nothing happened",
  ## not a crash and not a hang. Under the poll the driver waits and the store
  ## moves. The elapsed time is a leg, so a poll quietly reverted to a fixed
  ## delay cannot pass this row by accident.
  sd_slow_install before 300
  kx_ans ::op_param_lists::reset
  kx_ans ::op_param_lists::set_class b5ndev b5cls
  kx_ans ::op_param_lists::set_class b5pdev b5pcls
  kx_ans ::op_param_lists::said_clear
  sd_blocks
  kx_ans ::rdw::set_list annotation
  kx_ans ::rdw::set_row 10
  update idletasks
  set ::SD5_SEEN 0 ; set ::SD5_GRAB {}
  sd_arm {
    catch {set ::SD5_SEEN [expr {[winfo exists .rdw.scope] ? 1 : 0}]}
    catch {set ::SD5_GRAB [grab current]}
    catch {.rdw.scope.sc.broad invoke}
    catch {.rdw.scope.btns.ok invoke}
  }
  set SD5_T0 [clock milliseconds]
  catch {.rdw.b.delete invoke}
  update
  set SD5_DT [expr {[clock milliseconds] - $SD5_T0}]
  sd_disarm
  check {SD5 the driver is a POLL and not a bet: with the dialog's construction delayed 300 ms - past the old fixed 100 ms timer, and delayed by spinning the event loop the way a contended display does - the driver still lands on a real modal holding a real grab, broad + OK still moves the cursor's own class list, and it all happens in well under the 5 s deadman. Under `after 100` this row is issue 1332's own tuple: {0 0 0 {} 0 0 {}} at 5004 ms} \
    [list $::SD5_SEEN \
          [expr {$::SD5_GRAB ne {} ? 1 : 0}] \
          [kx_ans ::op_param_lists::owns class b5cls annotation] \
          [kx_ans ::op_param_lists::get_list class b5cls annotation] \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] [grab current] \
          [expr {$SD5_DT >= 250 ? 1 : 0}] [expr {$SD5_DT < 3000 ? 1 : 0}] \
          $::SD_RAN $::SD_GAVEUP] \
    [list 1 1 1 {{id ids 0} {gds gds 1}} 0 {} 1 1 1 0]

  # --- SD6  THE OTHER LOSING SHAPE: THE KEYBOARD IS NOT THERE YET -----------
  ## SD2's Escape, with the delay moved to AFTER the toplevel is built and
  ## BEFORE `rdw::scope_dialog` forces the keyboard onto it. A driver that
  ## waited only on `winfo exists .rdw.scope` would fire HERE, and Tk redirects
  ## a key event to the DISPLAY's focus window rather than to the window the
  ## event names - so the Escape lands on `.drw` and silently ENDS the user's
  ## canvas command mode, which is the very thing SD2 exists to forbid.
  ## MEASURED under the old `after 100`, delay 200 ms: run1 0, expected 1, and
  ## the dialog then sat there until the deadman at 5000 ms. That is SD2's
  ## failure on the user's own VcXsrv, reproduced without one. This row is why
  ## `sd_poll_modal` waits on the GRAB and not merely on the window.
  sd_slow_install after 200
  kx_ans ::rdw::pick_start
  set SD6_RUN0 [kx_ans ::rdw::pick_running]
  set ::SD6_FOCUS UNSET
  sd_arm {
    catch {set ::SD6_FOCUS [focus]}
    catch {event generate .rdw.scope <Key-Escape> -when now}
  }
  set SD6_T0 [clock milliseconds]
  set SD6_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  update
  set SD6_DT [expr {[clock milliseconds] - $SD6_T0}]
  sd_disarm
  set SD6_RUN1 [kx_ans ::rdw::pick_running]
  kx_ans ::rdw::pick_end
  check {SD6 and the poll waits for the KEYBOARD, not just for the window: with the delay moved between the build and rdw::scope_dialog's own `focus -force`, the driver still finds the focus on the dialog, the Escape cancels the dialog instead of being redirected to the canvas, and the user's command mode is STILL RUNNING afterwards - under a fixed `after 100`, or under a poll that waited on `winfo exists` alone, this row reds with run1 0 and burns the full 5 s deadman} \
    [list $SD6_RUN0 [sd_pair $SD6_GOT] $SD6_RUN1 \
          $::SD6_FOCUS \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] [grab current] \
          [expr {$SD6_DT >= 150 ? 1 : 0}] [expr {$SD6_DT < 3000 ? 1 : 0}] \
          $::SD_RAN $::SD_GAVEUP] \
    [list 1 CANCELLED 1 .rdw.scope 0 {} 1 1 1 0]

  # --- SD7  A POLL THAT NEVER SEES ITS DIALOG GIVES UP, AND LOUDLY ----------
  ## The acceptance clause of issue 1332, and the half a poll could get wrong
  ## in a NEW way: a self-re-arming timer that never finds its subject must
  ## stop, and it must stop INSIDE the deadman rather than living on to drive
  ## whatever toplevel a later row happens to put on screen. Two legs, one
  ## fixture each:
  ##   (a) no dialog is ever CONSTRUCTED - the wrapper returns a string, so
  ##       `rdw::scope_dialog`'s own `winfo exists` guard returns Cancel at
  ##       once; the poll must give up on its budget and its script must never
  ##       have run;
  ##   (b) a REAL dialog is built and NOBODY drives it - `tkwait` is entered
  ##       for real and only the deadman can end it. Issue 0803's property,
  ##       asserted under the poll rather than assumed. A short deadman is
  ##       passed so the row costs a third of a second, not five.
  sd_slow_none
  sd_arm {catch {.rdw.scope.btns.ok invoke}} 10
  set SD7A_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  update
  ## ⚠ `after 120` ALONE WOULD PROVE NOTHING - a bare `after ms` BLOCKS and
  ## enters no event loop, so the poll's own timers cannot fire during it and
  ## the budget is never spent. Measured: the give-up leg read 0 that way. The
  ## spin below is a `vwait`, which is the event loop.
  sd_spin 120
  update
  set SD7A_RAN $::SD_RAN ; set SD7A_GAVE $::SD_GAVEUP
  sd_disarm
  set SD7_RESTORED [sd_slow_remove]
  sd_arm {} 900 300
  set SD7_T0 [clock milliseconds]
  set SD7B_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  update
  set SD7_DT [expr {[clock milliseconds] - $SD7_T0}]
  sd_disarm
  check {SD7 the poll can fail but it cannot lie or linger: with no dialog ever CONSTRUCTED the driver script never runs and the poll gives up on its own budget instead of re-arming forever into the next row; and with a real dialog built and NOBODY driving it, the deadman still ends it - tkwait returns, the answer is Cancel, no grab and no window are left, and the real scope_dialog_build is back in place afterwards (issue 0803 under the poll, issue 1314's rename-not-proc)} \
    [list [sd_pair $SD7A_GOT] $SD7A_RAN $SD7A_GAVE \
          $SD7_RESTORED \
          [sd_pair $SD7B_GOT] \
          [expr {$SD7_DT >= 250 ? 1 : 0}] [expr {$SD7_DT < 2000 ? 1 : 0}] \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] [grab current] \
          [expr {[llength [info commands ::rdw::sd_real_build]] == 0 ? 1 : 0}]] \
    [list CANCELLED 0 1 1 CANCELLED 1 1 0 {} 1]

  # --- SD8  THE GRAB THE POLL WAITS FOR MUST BE THE DIALOG'S ----------------
  ## Issue 1332's adversary refuted the poll's own justification. The comment
  ## on `sd_arm` says a driver that sees a grab "is running from inside
  ## `tkwait` on a dialog that is fully modal and already holds the keyboard".
  ## That is true of the DIALOG'S grab. `grab current` with no window argument
  ## answers for EVERY grab this application holds, so one unrelated grab
  ## anywhere in the program satisfied the condition and the poll fired during
  ## the build's own `update` - with the focus still on `.drw`, which is
  ## precisely the losing shape SD6 exists to forbid.
  ##
  ## THE FIXTURE IS SD6's, PLUS A FOREIGN GRAB. The delay sits between the
  ## build and `rdw::scope_dialog`'s `focus -force`, and `.rdw` holds a local
  ## grab across the whole row. Under `[grab current] ne {}` the driver runs
  ## in that window and reads grab `.rdw` and focus `.drw`; under
  ## `eq {.rdw.scope}` it waits for the real thing.
  sd_slow_install after 200
  catch {grab set .rdw}
  set ::SD8_GRAB UNSET ; set ::SD8_FOCUS UNSET
  sd_arm {
    catch {set ::SD8_GRAB [grab current]}
    catch {set ::SD8_FOCUS [focus]}
    catch {.rdw.scope.btns.ok invoke}
  }
  set SD8_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  update
  sd_disarm
  catch {grab release .rdw}
  set SD8_RESTORED [sd_slow_remove]
  check {SD8 a grab held ANYWHERE ELSE in the program is not this dialog's grab: with `.rdw` holding one and the build delayed past its own `focus -force`, the driver still waits for `.rdw.scope` to own the grab AND the keyboard before it presses anything, so the answer is the one the buttons gave and not the one a canvas got - under a bare `[grab current] ne {}` this row reads grab .rdw, focus .drw, and reds the way the old fixed timer did} \
    [list $::SD_RAN $::SD8_GRAB \
          [expr {$::SD8_FOCUS eq {.rdw.scope} || [string match {.rdw.scope.*} $::SD8_FOCUS] ? 1 : 0}] \
          [sd_pair $SD8_GOT] \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] [grab current] \
          $SD8_RESTORED] \
    [list 1 .rdw.scope 1 {broad annotation} 0 {} 1]

  # --- SD9  ARMING AGAIN CANCELS THE CHAIN IT REPLACES ----------------------
  ## Issue 1332's adversary again. `sd_arm` used to blank `::SD_POLL_ID` and
  ## overwrite `::SD_DEADMAN`, which throws the previous chain's HANDLES away
  ## while the chain keeps running - so `sd_disarm` could no longer reach it.
  ## Under the old fixed `after 100` a stray timer was a one-shot that fired
  ## once within 100 ms, almost certainly inside its own row. A poll is a
  ## self-re-arming chain that lives seconds, i.e. ACROSS rows, and it presses
  ## buttons on whatever dialog a later row puts up. That is a stronger form
  ## of the very flake this section removed, introduced by the fix for it.
  ##
  ## DRIVEN: chain A is armed against a fixture where no dialog is ever built,
  ## so it is still polling; chain B is then armed for a REAL dialog. Only B's
  ## script may run. Pre-fix both chains see the dialog and A's script fires.
  sd_slow_none
  set ::SD9_A 0 ; set ::SD9_B 0
  sd_arm {set ::SD9_A 1}
  set SD9_RESTORED [sd_slow_remove]
  sd_arm {set ::SD9_B 1 ; catch {.rdw.scope.btns.ok invoke}}
  set SD9_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  update
  sd_disarm
  check {SD9 a second arm cancels the first, it does not orphan it: with a chain left polling for a dialog that was never built and a second chain armed for a real one, only the second chain's script runs - pre-fix the first chain's handles were thrown away while the chain lived on, and it pressed buttons in a row it was never armed for} \
    [list $::SD9_A $::SD9_B $SD9_RESTORED \
          [sd_pair $SD9_GOT] \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] [grab current] \
          $::SD_POLL_ID $::SD_DEADMAN] \
    [list 0 1 1 {broad annotation} 0 {} {} {}]

  # --- SD10  THE GIVE-UP IS A CLOCK, NOT A COUNT ----------------------------
  ## `after 5` is a FLOOR, not a period. The comment on this section used to
  ## call 900 polls "4.5 s, deliberately INSIDE the 5 s deadman"; issue 1332's
  ## adversary timed a full give-up at 4856-4986 ms at load avg 25 and
  ## 6028-6524 ms at load avg 54 - past the deadman it was claimed to sit
  ## inside, under exactly the contention the poll exists for. A give-up that
  ## arrives after the deadman is the orphan chain of SD9 wearing a budget.
  ##
  ## DRIVEN with the two limits pulled apart: a budget so large no run could
  ## ever spend it, and a short deadman. Only a wall-clock deadline can stop
  ## this chain. Pre-fix it is still polling when the row reads it.
  sd_slow_none
  set ::SD10_SCRIPT 0
  sd_arm {set ::SD10_SCRIPT 1} 100000 800
  set SD10_T0 [clock milliseconds]
  set SD10_GOT [kx_ans ::rdw::scope_dialog delete $SD_SUBJ annotation]
  sd_spin 600
  set SD10_DT [expr {[clock milliseconds] - $SD10_T0}]
  set SD10_GAVE $::SD_GAVEUP ; set SD10_POLLS $::SD_POLLS
  set SD10_RAN $::SD_RAN
  sd_disarm
  set SD10_RESTORED [sd_slow_remove]
  check {SD10 the poll gives up on a clock as well as on a count: with a budget of 100000 polls that no run could ever spend and a 800 ms deadman, the chain has stopped itself before the deadman fires - it spent only a few dozen polls, its script never ran, and it is not still re-arming into the next row. Pre-fix the count was the only limit and this chain was still alive} \
    [list $SD10_GAVE $SD10_RAN $::SD10_SCRIPT \
          [expr {$SD10_POLLS > 0 ? 1 : 0}] [expr {$SD10_POLLS < 1000 ? 1 : 0}] \
          [expr {$SD10_DT < 800 ? 1 : 0}] \
          [sd_pair $SD10_GOT] $SD10_RESTORED] \
    [list 1 0 0 1 1 1 CANCELLED 1]

  ## HYGIENE for this section: the real dialog is already back (SD3b needed it),
  ## so forget the fixture and leave no settings file anywhere near the
  ## developer's own tree.
  catch {rename ::rdw::sd_stub_scope_dialog {}}
  kx_ans ::op_param_lists::reset
  catch {op_annot::register b5ndev {}}
  catch {op_annot::register b5pdev {}}
  set ::rdw::blocks {}
  kx_ans ::rdw::set_list annotation
  kx_ans ::rdw::status {}
  catch {destroy .rdw.scope}
  kx_ans ::rdw::close
  update idletasks
  check {SD4 HYGIENE section SD leaves nothing behind: no dialog, no window, no grab, no untitled* anywhere, and the repo's own project settings file is byte-for-byte as section SD found it - which is the developer's file when they have one and still no file when they do not (issue 1381)} \
    [list [expr {[winfo exists .rdw.scope] ? 1 : 0}] \
          [expr {[winfo exists .rdw] ? 1 : 0}] \
          [grab current] \
          [expr {[kx_conf_stamp] eq $S1_CONF0 ? 1 : 0}] \
          [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S1_ROOT0 ? 1 : 0}] \
          [llength [glob -nocomplain -directory $scratch -tails untitled*]]] \
    {0 0 {} 1 1 0}
}

# ============================================================================
# SECTION CU — ITEM R1, ISSUE 1337: THE LINE CURSOR, CLICKED FOR REAL
# ============================================================================
# The user's words: "clicking on any line makes the entire line a shade darker
# (noticeably)."  Driver decisions DD-1 (one cursor; a new block clears it) and
# DD-2 (the shade is DERIVED from the palette, never hard-coded).  The palette
# half and DD-1's headless half are section CU of
# tests/headless/test_rdw_window_1245.tcl; everything here needs a MAPPED pane,
# a real <Button-1> and real pixel coordinates, so it lives on the display arm.
#
# ⚠ THE CURSOR THIS ITEM MAKES VISIBLE ALREADY EXISTS.  `rdw::set_row` /
# `rdw::_target_line` (src/rdw.tcl:1940, :1954) are item B5's target row, and
# `rdw::_subject`'s own comment already calls it "the block the CURSOR is in":
# Delete, Add, Up and Down act on it today and the user cannot see it.  R1
# must SHADE THAT ROW.  A `cursor` tag that tracked its own private variable
# would give the window TWO cursors — a visible one and the one the buttons
# obey — and every row in section BT of the other suite would still pass while
# Delete deleted a line the user was not looking at.  Rows CU9, CU12 and CU14
# are that fence, and `cu_agree` is the predicate they share.
#
# ⚠ AND IT MUST NOT COST THE SELECTION.  A `<Button-1>` binding on the pane
# that ends in `break` shadows Tk's Text class binding, which is what sets the
# anchor a drag extends from — and the selection is the entire reason this
# window is a Text and not a CIW dump (item R3, issue 1339, is already about a
# selection the user cannot make reliably).  Row CU10 drives a real
# press-drag-release and is GREEN TODAY on its first three legs: it is the
# fence, not the feature.  Its fourth leg — the `cursor` tag must sit BELOW
# `sel` in priority — is red, and is why: a tag created after `sel` outranks
# it, and a full-width background above `sel` hides the selection completely.
# Measured on this binary: `tag names` answers `sel hdr dim dev note`, so `sel`
# is already the LOWEST-priority tag in the pane and a new one lands above it.
#
# THE THREE OTHER INPUTS MOST LIKELY TO BREAK THIS CHANGE, EACH WITH A ROW:
#   * a WRAPPED line.  The pane is `-wrap word` and the fixture's line 3 really
#     does wrap — measured, `count -displaylines` over line 3 is >= 1, i.e. two
#     display rows or more.  A cursor computed in display rows shades half a
#     line, or the wrong one.  (The wrapping note was DD-1's incompleteness
#     sentence until issue 1374 cut it to 57 characters; it is ruling DD-5's
#     analysis sentence now.  See `cu_block`.)                          -> CU11
#   * a click BELOW THE TEXT.  `index @x,y` CLAMPS: measured, a click in the
#     pane's empty lower half answers line 13 of a 12-line render — the
#     widget's own trailing artifact, a line no block owns.  `rdw::_locate`
#     already answers {} for exactly those lines and is the fence.      -> CU12
#   * a cursor that OUTLIVES ITS LINE.  Key 4 (`rdw::keep_latest`) throws older
#     blocks away and repaints; a cursor left pointing into a discarded block
#     is item R2's Up/Down aimed at nothing.                            -> CU14
#
# RED BEFORE R1, MEASURED 2026-09-05 AT HEAD 077bdfe4: `.rdw.p.t tag names`
# answers `sel hdr dim dev note` — there is no `cursor` tag; `bind .rdw.p.t
# <Button-1>` is the EMPTY STRING; and a real click moves the pane's `insert`
# mark (measured: 3.15 after a drag) and paints nothing at all.  CU6..CU14 red.

if {[kx_ans ::rdw::have_tk] eq {1}} {
  ## A widget expression that must not abort the suite (kx_ans's twin).
  proc cu_w {args} {
    set rc [catch {uplevel #0 $args} r]
    if {$rc} { return "ERR:$r" }
    return $r
  }
  ## THE WHOLE LINE, INCLUDING ITS NEWLINE.  A tag that stops at `lineend`
  ## stops at the last character, and the user's words are "the ENTIRE line" —
  ## on a 96-column pane holding a 12-character parameter row that is a stub of
  ## colour, not a line.  n.0 -> n+1.0 is what paints to the right edge.
  proc cu_span {n} { return [list $n.0 [expr {$n + 1}].0] }
  proc cu_ranges {} {
    set r {}
    if {[catch {.rdw.p.t tag ranges cursor} r]} { return ERR }
    return $r
  }
  ## A real mouse click, delivered the way the user's hand delivers it.
  proc cu_click {x y} {
    catch {event generate .rdw.p.t <Motion>          -x $x -y $y -when now}
    catch {update}
    catch {event generate .rdw.p.t <ButtonPress-1>   -x $x -y $y -when now}
    catch {event generate .rdw.p.t <ButtonRelease-1> -x $x -y $y -when now}
    catch {update}
  }
  ## Click the first character cell of pane line n. The coordinates are READ
  ## FROM THE WIDGET, never transcribed - the fixture's line heights are the
  ## display's, not this file's.
  proc cu_click_line {n} {
    set bb {}
    if {[catch {.rdw.p.t bbox $n.0} bb]} { return NOBBOX }
    if {[llength $bb] != 4} { return NOBBOX }
    cu_click [expr {[lindex $bb 0] + 2}] [expr {[lindex $bb 1] + 2}]
    return OK
  }
  ## THE ONE-CURSOR PREDICATE.  1 when the shading and the row the buttons act
  ## on say the same thing - including when they agree there is NO row.
  proc cu_agree {} {
    set t [kx_ans ::rdw::_target_line]
    set r [cu_ranges]
    if {[kx_bad $t]} { return BADTARGET }
    if {$r eq {ERR}} { return NOTAG }
    if {![string is integer -strict $t] || $t <= 0} {
      return [expr {[llength $r] == 0 ? 1 : 0}]
    }
    return [expr {$r eq [cu_span $t] ? 1 : 0}]
  }
  ## TWO DUMPS, SIX LINES EACH: hdr / devpath / ONE LONG NOTE THAT REALLY WRAPS
  ## / two parameter rows / the separator.  Lines 1-6 are the newest block and
  ## 7-12 the older one, which is what row CU14 needs.
  ##
  ## ⚠ THE WRAPPING NOTE IS RULING DD-5's ANALYSIS SENTENCE (~236 characters),
  ## AND IT USED TO BE DD-1's INCOMPLETENESS SENTENCE.  Issue 1374 cut that one
  ## to 57 characters on the user's ruling ("This is too verbose!"), so it no
  ## longer wraps at this pane's width and the fixture stopped exercising the
  ## thing rows CU11 and CP1 exist for.  The pane is STILL `-wrap word` and the
  ## long sentences still wrap, so the fixture keeps a wrapping line by
  ## swapping WHICH long note it carries -- `simtype dc` raises the analysis
  ## line and `complete 1` drops the incompleteness line, which is six lines
  ## again with a note on line 3.  Deleting the wrap instead would have left
  ## CU11 and CP1 passing over a fixture that cannot fail them.
  proc cu_block {} {
    set ans [dict create devices [dict create {@m.x1.mcu} {{id 1.234} {vth 0.5}}] \
                         absent {} nonfinite {} complete 1 state ok]
    set ctx [dict create header {MCU:/} devpath {@m.x1.mcu} simtype dc \
                         instname MCU sim ngspice]
    return [kx_ans ::rdw::format_answer $ans $ctx]
  }
  proc cu_fixture {} {
    set ::rdw::blocks {}
    kx_ans ::rdw::set_row 0
    kx_ans ::rdw::push [cu_block]
    kx_ans ::rdw::push [cu_block]
    kx_ans ::rdw::render_pane
    catch {update idletasks}
    catch {focus -force .rdw.p.t}
    catch {update}
    return {}
  }

  kx_ans ::rdw::open
  catch {update idletasks}
  cu_fixture

  # --- CU6  the tag exists, is the palette's shade, and is BELOW sel ---------
  ## ⚠ `tag names` IS READ FIRST AND STORED.  `tag cget` on an unknown tag
  ## CREATES it in some Tk builds, which would make the very first leg true by
  ## the act of measuring the third.
  set CU6_NAMES [cu_w .rdw.p.t tag names]
  set CU6_BG    [cu_w .rdw.p.t tag cget cursor -background]
  set CU6_PANE  [cu_w .rdw.p.t cget -background]
  set CU6_IC [lsearch -exact $CU6_NAMES cursor]
  set CU6_IS [lsearch -exact $CU6_NAMES sel]
  check {CU6 the pane really carries a `cursor` tag, its background is the palette's derived shade and not the pane's own colour, and it sits BELOW `sel` in priority so a selection drawn over a cursored line is still visible - a full-width background above sel would hide the selection the whole window exists to produce} \
    [list [expr {$CU6_IC >= 0 ? 1 : 0}] \
          [expr {$CU6_IC >= 0 && $CU6_IS >= 0 && $CU6_IC < $CU6_IS ? 1 : 0}] \
          [expr {$CU6_BG eq [kx_ans ::rdw::color cursor] ? 1 : 0}] \
          [expr {$CU6_BG ne $CU6_PANE && ![string match {ERR:*} $CU6_BG] ? 1 : 0}]] \
    {1 1 1 1}

  # --- CU7  a click shades the WHOLE line, and changes nothing else ---------
  cu_fixture
  set CU7_TXT0 [cu_w .rdw.p.t get 1.0 end]
  set CU7_CLK  [cu_click_line 4]
  set CU7_R    [cu_ranges]
  set CU7_TXT1 [cu_w .rdw.p.t get 1.0 end]
  check {CU7 clicking a line shades THAT WHOLE LINE - the tag runs from its start to the start of the next, so the colour reaches the right edge past the last character - and nothing else moves: exactly one range, the pane still -state disabled, not one byte of the buffer changed, and the keyboard still in the pane (issue 1308)} \
    [list $CU7_CLK $CU7_R [llength $CU7_R] \
          [cu_w .rdw.p.t cget -state] \
          [expr {$CU7_TXT1 eq $CU7_TXT0 ? 1 : 0}] \
          [focus]] \
    [list OK [cu_span 4] 2 disabled 1 .rdw.p.t]

  # --- CU8  ONE cursor: a second click MOVES it (DD-1) ----------------------
  cu_fixture
  cu_click_line 2
  set CU8_A [cu_ranges]
  cu_click_line 5
  set CU8_B [cu_ranges]
  check {CU8 DD-1 there is ONE cursor: clicking a second line MOVES the shading rather than adding to it, so exactly one range is ever painted} \
    [list $CU8_A $CU8_B [llength $CU8_B]] \
    [list [cu_span 2] [cu_span 5] 2]

  # --- CU9  the shaded line IS the row the buttons act on -------------------
  ## Both directions, because either one alone permits two cursors: a click
  ## must move the TARGET, and rdw::set_row must move the SHADING.
  cu_fixture
  cu_click_line 4
  set CU9_T1 [kx_ans ::rdw::_target_line]
  set CU9_A1 [cu_agree]
  kx_ans ::rdw::set_row 9
  catch {update idletasks}
  set CU9_R2 [cu_ranges]
  set CU9_T2 [kx_ans ::rdw::_target_line]
  set CU9_A2 [cu_agree]
  ## ⚠ "WITH NO SELECTION STANDING" IS PART OF THE CLAIM NOW, AND IS ASSERTED.
  ## The user's ruling gave Add and Delete the selected rows when a selection
  ## is standing; the shaded row is the target when none is, which is what a
  ## real click leaves behind.  Without this leg the row would read as "the
  ## shaded row is always the target", which is no longer true.
  set CU9_SEL [llength [cu_w .rdw.p.t tag ranges sel]]
  check {CU9 with no selection standing - asserted, not assumed - the shaded line and the row Delete/Add/Up/Down act on are ONE row: a click moves the target the buttons read, and rdw::set_row moves the shading the user sees - two cursors would let a button edit a line nobody is looking at, and every row in section BT would still pass} \
    [list $CU9_T1 $CU9_A1 $CU9_R2 $CU9_T2 $CU9_A2 $CU9_SEL] \
    [list 4 1 [cu_span 9] 9 1 0]

  # --- CU10  THE FENCE: the selection still works, and still SHOWS ----------
  ## GREEN TODAY on legs 1-3 and it must stay green. A <Button-1> binding that
  ## ends in `break` shadows the Text class binding that sets the drag anchor,
  ## and this window exists to be selected and pasted into a design-review
  ## document (item R3, issue 1339).
  cu_fixture
  cu_click_line 3
  set CU10_BB [cu_w .rdw.p.t bbox 3.0]
  set CU10_Y  [expr {[lindex $CU10_BB 1] + 2}]
  cu_w .rdw.p.t tag remove sel 1.0 end
  catch {event generate .rdw.p.t <ButtonPress-1>   -x 4   -y $CU10_Y -when now}
  catch {update}
  catch {event generate .rdw.p.t <B1-Motion>       -x 124 -y $CU10_Y -when now}
  catch {update}
  catch {event generate .rdw.p.t <ButtonRelease-1> -x 124 -y $CU10_Y -when now}
  catch {update}
  set CU10_SEL {}
  catch {set CU10_SEL [.rdw.p.t get sel.first sel.last]}
  set CU10_RNG   [cu_w .rdw.p.t tag ranges sel]
  set CU10_LINE  [cu_w .rdw.p.t get 3.0 {3.0 lineend}]
  set CU10_NAMES [cu_w .rdw.p.t tag names]
  set CU10_IC [lsearch -exact $CU10_NAMES cursor]
  set CU10_IS [lsearch -exact $CU10_NAMES sel]
  check {CU10 FENCE a real press-drag-release on the cursored line still makes a selection - the cursor binding must not `break` the Text class binding the drag anchor comes from - and the `cursor` tag stays BELOW `sel`, so the selection is still visible on the line the cursor shades} \
    [list [expr {[string length $CU10_SEL] >= 8 ? 1 : 0}] \
          [expr {[llength $CU10_RNG] == 2 ? 1 : 0}] \
          [expr {$CU10_SEL ne {} && [string first $CU10_SEL $CU10_LINE] >= 0 ? 1 : 0}] \
          [expr {$CU10_IC >= 0 && $CU10_IS >= 0 && $CU10_IC < $CU10_IS ? 1 : 0}]] \
    {1 1 1 1}

  # --- CU11  a WRAPPED line is shaded whole ---------------------------------
  ## The pane is -wrap word and line 3 of the fixture really wraps (`cu_block`
  ## carries ruling DD-5's analysis sentence for exactly this reason; issue
  ## 1374 cut DD-1's, which used to be the one that wrapped here).  The second
  ## display row is FOUND from the widget's own bbox, never transcribed.
  cu_fixture
  set CU11_DL [cu_w .rdw.p.t count -displaylines 3.0 {3.0 lineend}]
  set CU11_B0 [cu_w .rdw.p.t bbox 3.0]
  set CU11_B1 [cu_w .rdw.p.t bbox {3.0 lineend -2c}]
  set CU11_PRE [expr {[string is integer -strict $CU11_DL] && $CU11_DL >= 1
                      && [llength $CU11_B0] == 4 && [llength $CU11_B1] == 4
                      && [lindex $CU11_B1 1] > [lindex $CU11_B0 1] ? 1 : 0}]
  cu_click [expr {[lindex $CU11_B1 0] + 2}] [expr {[lindex $CU11_B1 1] + 2}]
  check {CU11 a line that WRAPS is one line: clicking its second display row shades the whole logical line and cursors that row, not the next one - the pane is -wrap word and a cursor computed in display rows would shade half a line} \
    [list $CU11_PRE [cu_ranges] [kx_ans ::rdw::_target_line] [cu_agree]] \
    [list 1 [cu_span 3] 3 1]

  # --- CU12  a click where there is NO line changes nothing -----------------
  ## `index @x,y` CLAMPS to the last line, which after a 12-line render is line
  ## 13 - the widget's own trailing artifact, owned by no block. rdw::_locate
  ## already answers {} for it. An empty pane is the same question with no
  ## lines at all.
  cu_fixture
  cu_click_line 3
  set CU12_R0 [cu_ranges]
  set CU12_B  [cu_w .rdw.p.t bbox 12.0]
  set CU12_Y  [expr {[llength $CU12_B] == 4
                     ? [lindex $CU12_B 1] + [lindex $CU12_B 3] + 6 : -1}]
  set CU12_PRE [expr {$CU12_Y > 0 && $CU12_Y < [winfo height .rdw.p.t] - 2 ? 1 : 0}]
  cu_click 10 $CU12_Y
  set CU12_R1 [cu_ranges]
  set CU12_T1 [kx_ans ::rdw::_target_line]
  set ::rdw::blocks {}
  kx_ans ::rdw::set_row 0
  kx_ans ::rdw::render_pane
  catch {update idletasks}
  cu_click 10 10
  set CU12_R2 [cu_ranges]
  set CU12_T2 [kx_ans ::rdw::_target_line]
  check {CU12 a click in the pane's empty space below the text hits no line and changes nothing - the cursor stays where the user put it - and a click in an EMPTY pane cursors nothing at all: the shading never lands on a line no block owns} \
    [list $CU12_PRE $CU12_R0 $CU12_R1 $CU12_T1 $CU12_R2 $CU12_T2] \
    [list 1 [cu_span 3] [cu_span 3] 3 {} 0]

  # --- CU13  DD-1 on screen: a new dump clears the shading ------------------
  cu_fixture
  cu_click_line 8
  set CU13_R0 [cu_ranges]
  set CU13_T0 [kx_ans ::rdw::_target_line]
  kx_ans ::rdw::push [cu_block]
  catch {update idletasks}
  check {CU13 DD-1 on screen: a new dump CLEARS the cursor - no shading anywhere and no target row - because push PREPENDS and the line the user clicked now holds a different block's text} \
    [list $CU13_R0 $CU13_T0 [cu_ranges] [kx_ans ::rdw::_target_line] [cu_agree] \
          [llength $::rdw::blocks]] \
    [list [cu_span 8] 8 {} 0 1 3]

  # --- CU14  the cursor never outlives the line it points at ----------------
  cu_fixture
  cu_click_line 8
  set CU14_R0 [cu_ranges]
  kx_ans ::rdw::keep_latest
  catch {update idletasks}
  set CU14_R1 [cu_ranges]
  set CU14_T1 [kx_ans ::rdw::_target_line]
  set CU14_A1 [cu_agree]
  set CU14_NB [llength $::rdw::blocks]
  cu_fixture
  cu_click_line 4
  set CU14_A2 [cu_agree]
  kx_ans ::rdw::close
  catch {update idletasks}
  kx_ans ::rdw::open
  catch {update idletasks}
  set CU14_A3 [cu_agree]
  check {CU14 the cursor never outlives the line it points at: key 4 throws the older dumps away and the cursor that pointed into one goes with them, and a close-and-reopen leaves the shading and the target still saying the same thing - a target with no shading is the invisible cursor this item exists to abolish} \
    [list $CU14_R0 $CU14_R1 $CU14_T1 $CU14_A1 $CU14_NB $CU14_A2 $CU14_A3] \
    [list [cu_span 8] {} 0 1 1 1 1]

  ## HYGIENE for this section: no dumps, no cursor, no window, no status.
  set ::rdw::blocks {}
  kx_ans ::rdw::set_row 0
  kx_ans ::rdw::set_list annotation
  kx_ans ::rdw::status {}
  kx_ans ::rdw::close
  catch {update idletasks}
  check {CU15 HYGIENE section CU leaves nothing behind: no window, no stored dumps, no cursored row and no untitled* anywhere} \
    [list [expr {[winfo exists .rdw] ? 1 : 0}] \
          [llength $::rdw::blocks] \
          [kx_ans ::rdw::_target_line] \
          [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S1_ROOT0 ? 1 : 0}] \
          [llength [glob -nocomplain -directory $scratch -tails untitled*]]] \
    {0 0 0 1 0}
}


# ============================================================================
# SECTION RD — ITEM R2, ISSUE 1338: THE PANE REALLY REPAINTS, ON A MAPPED
# WINDOW, WITH A REAL BUTTON PRESS
# ============================================================================
# The user's words: "Promote/demote using Up/Down arrow should be reflected in
# the Results Display Window as well as the schematic annotation."  The store
# half, the block-model half and DD-4 are section RE of
# tests/headless/test_rdw_window_1245.tcl and run on both arms; what needs a
# MAPPED pane is the last step of the chain, and it is exactly the step this
# batch keeps shipping green and wrong.
#
# ⚠ ::rdw::blocks IS NOT THE PANE.  `rdw::render_pane` is what projects the
# store onto `.rdw.p.t`, and it returns early with no Tk - so an implementation
# that re-orders the block model and forgets to repaint passes EVERY row of
# section RE, on both arms, while the window on screen still shows the order
# the user just changed.  That is the same shape as issue 1283's three gaps and
# as B2c's 79 green checks over deleted rows: the fence saw the model, not the
# screen.  This section reads `.rdw.p.t get` and the `cursor` tag's own range,
# and drives the reorder through the REAL `.rdw.b.up` widget rather than
# through `rdw::button`, so the command the user's finger reaches is the one
# under test.
#
# RED BEFORE R2, MEASURED 2026-09-05 AT HEAD 27122ca4: a real `.rdw.b.up
# invoke` moves the store, re-renders the sheet and leaves the pane text byte
# for byte as it was, with the shading still on the line the parameter has
# LEFT.
#
# ⚠ The floor below is raised by the two rows this section adds.  A display
# that fails to come up drops the whole section silently, which is what the
# floor is for.

if {[kx_ans ::rdw::have_tk] eq {1}} {
  set RD_ROOT [file join $scratch r2rd]
  file mkdir $RD_ROOT
  proc rd_mksym {path type} {
    set fd [open $path w]
    puts $fd "v {xschem version=3.4.5 file_version=1.2}"
    puts $fd "G {}"
    puts $fd "K {type=$type"
    puts $fd {format="@spiceprefix@name @pinlist @model"}
    puts $fd "template=\"name=M1 model=$type spiceprefix=X\""
    puts $fd "}"
    puts $fd "V {}"
    puts $fd "S {}"
    puts $fd "E {}"
    puts $fd "L 4 -20 -20 20 -20 {}"
    puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
    puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
    close $fd
  }
  set RD_SYMN [file join $RD_ROOT rdn.sym]
  rd_mksym $RD_SYMN rdndev
  set RD_SCH [file join $RD_ROOT rd.sch]
  set _fd [open $RD_SCH w]
  puts $_fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$RD_SYMN\} 300 -300 0 0 \{name=M1\}"
  close $_fd
  catch {xschem raw clear}
  set RD_LOAD [catch {xschem load $RD_SCH}]
  update idletasks
  set RD_DESC [list devpath {\@m.@path@name} \
                    params {{id ids 0} {gm gm 1} {gds gds 1}}]
  catch {op_annot::register rdndev $RD_DESC}
  kx_ans ::op_param_lists::reset
  kx_ans ::op_param_lists::set_class rdndev rdcls

  proc rd_w {args} {
    set rc [catch {uplevel #0 $args} r]
    if {$rc} { return "ERR:$r" }
    return $r
  }
  proc rd_span {n} { return [list $n.0 [expr {$n + 1}].0] }
  proc rd_ranges {} {
    set r {}
    if {[catch {.rdw.p.t tag ranges cursor} r]} { return ERR }
    return $r
  }
  ## The pane's own text, one line per element, the trailing empty line the
  ## widget always carries dropped.  READ FROM THE WIDGET, never from the
  ## store: that is this section's whole purpose.
  proc rd_panelines {} {
    set t {}
    if {[catch {.rdw.p.t get 1.0 {end - 1c}} t]} { return ERR }
    return [split $t "\n"]
  }
  ## The parameter names the PANE shows, in pane order - scraped out of the
  ## rendered text with rdw::format_answer's own row shape.
  proc rd_paneparams {} {
    set out {}
    set l [rd_panelines]
    if {$l eq {ERR}} { return ERR }
    foreach line $l {
      if {[regexp {^[ ]+(\S+)[ ]+:} $line -> p]} { lappend out $p }
    }
    return $out
  }
  proc rd_lparams {} {
    set l [kx_ans ::op_param_lists::effective rdcls annotation]
    if {[kx_bad $l]} { return $l }
    set out {}
    foreach t $l { lappend out [lindex $t 1] }
    return $out
  }
  proc rd_blk {} {
    set ans [dict create devices {@m.m1 {{ids 1.2e-05} {gds 5.6e-06}}} \
                         absent {} nonfinite {{@m.m1 gm nan}} complete 0 state ok]
    set ctx [dict create header {M1:/} devpath {@m.m1} simtype op \
                         instname M1 sim ngspice]
    return [kx_ans ::rdw::format_answer $ans $ctx]
  }
  ## ONE block, six lines plus the separator, and the SAME order-divergence the
  ## other suite's section RE uses: `gm` is non-finite, so the pane shows
  ##      4  ids : 1.2e-05      5  gds : 5.6e-06      6  gm  : (did not converge)
  ## while the list holds ids / gm / gds.
  proc rd_fixture {} {
    kx_ans ::op_param_lists::reset
    kx_ans ::op_param_lists::set_class rdndev rdcls
    catch {op_annot::register rdndev $::RD_DESC}
    set ::rdw::blocks {}
    kx_ans ::rdw::set_row 0
    kx_ans ::rdw::push [rd_blk]
    kx_ans ::rdw::set_list annotation
    kx_ans ::rdw::status {}
    kx_ans ::rdw::render_pane
    catch {update idletasks}
    return {}
  }

  kx_ans ::rdw::open
  catch {update idletasks}
  rd_fixture

  # --- RD1  THE PANE ITSELF, AND THE SHADING WITH IT ------------------------
  ## Two presses of the REAL widget, for section RE's own reason: the first
  ## re-order is one the pane already agrees with and must leave the text
  ## alone, the second is one it does not and must change it.  The shading is
  ## read from the widget's tag ranges both times, so a repaint that dropped
  ## the cursor - or left it on the line the parameter has left - reds here.
  rd_fixture
  set RD1_P0   [rd_paneparams]
  set RD1_L0   [rd_lparams]
  kx_ans ::rdw::set_row 5
  catch {update idletasks}
  set RD1_R0   [rd_ranges]
  set RD1_TXT0 [rd_w .rdw.p.t get 1.0 end]
  rd_w .rdw.b.up invoke
  catch {update idletasks}
  set RD1_P1   [rd_paneparams]
  set RD1_L1   [rd_lparams]
  set RD1_R1   [rd_ranges]
  set RD1_SAME [expr {[rd_w .rdw.p.t get 1.0 end] eq $RD1_TXT0 ? 1 : 0}]
  rd_w .rdw.b.up invoke
  catch {update idletasks}
  set RD1_P2   [rd_paneparams]
  set RD1_L2   [rd_lparams]
  set RD1_R2   [rd_ranges]
  set RD1_T2   [kx_ans ::rdw::_target_line]
  check {RD1 the PANE repaints, not just the block model: a real .rdw.b.up press re-orders the store and the text in the widget follows it - a re-order the pane already agreed with leaves the text byte-identical, the next one really moves the line, and the cursor shading lands on the row the parameter moved TO, not on the line it left} \
    [list $RD1_P0 $RD1_L0 $RD1_R0 \
          $RD1_P1 $RD1_L1 $RD1_SAME $RD1_R1 \
          $RD1_P2 $RD1_L2 $RD1_R2 $RD1_T2 \
          [rd_w .rdw.p.t cget -state]] \
    [list {ids gds gm} {ids gm gds} [rd_span 5] \
          {ids gds gm} {ids gds gm} 1 [rd_span 5] \
          {gds ids gm} {gds ids gm} [rd_span 4] 4 \
          disabled]

  # --- RD2  HYGIENE ---------------------------------------------------------
  kx_ans ::op_param_lists::reset
  catch {op_annot::register rdndev {}}
  set ::rdw::blocks {}
  kx_ans ::rdw::set_row 0
  kx_ans ::rdw::set_list annotation
  kx_ans ::rdw::status {}
  kx_ans ::rdw::close
  catch {update idletasks}
  check {RD2 HYGIENE section RD leaves nothing behind: no window, no stored dumps, no cursored row, no owned list and no untitled* anywhere} \
    [list [expr {[winfo exists .rdw] ? 1 : 0}] \
          [llength $::rdw::blocks] \
          [kx_ans ::rdw::_target_line] \
          [kx_ans ::op_param_lists::owns class rdcls annotation] \
          [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S1_ROOT0 ? 1 : 0}] \
          [llength [glob -nocomplain -directory $scratch -tails untitled*]]] \
    {0 0 0 0 1 0}
}

# ============================================================================
# SECTION RA — ITEM R4, ISSUE 1340: A DUMP RAISES THE WINDOW AND TAKES NOTHING
# ============================================================================
# The user's words: "When user sends info to the Results Display Window (RDW),
# the RDW needs to be raised (no need to focus, just raise), just as the
# Library Manager is raised when one does Ctrl-Alt-S."
#
# `rdw::push` is the single door every dump goes through, so that is where the
# rows drive it - and RA3 drives the SHIPPED key path on top, because a raise
# wired only into a hand-called push would satisfy every row that calls push
# and do nothing at all for a user pressing 1. That is this batch's own
# recurring failure, met on the previous item.
#
# ⚠ WHY A DECOY TOPLEVEL AND `wm stackorder`. There is no way to ask a window
# "are you on top" except relative to another one, so every row parks a second
# toplevel over .rdw first and asserts the BEFORE state as a leg. `.radecoy` is
# created once and re-parked per row by `ra_park`, which POLLS rather than
# sleeping - issue 1332's lesson, three rows of section SD up this same file
# arm a modal on a fixed `after 100` and flake for it.
#
# ⚠ THE TRAP THIS SECTION EXISTS FOR, MEASURED ON :99 BEFORE IT WAS WRITTEN.
# Ruling DD-6 says to reuse `raise_activate_toplevel`'s body - `wm withdraw` +
# `wm deiconify` - because a plain `raise` is an inert no-op on the window
# manager issue 0054 was filed against. Measured here, openbox on :99, with
# nothing else changed and the keyboard parked on the canvas first:
#     plain raise            Map 0  Unmap 0   above 1   keyboard stays on .drw
#     withdraw + deiconify   Map 1  Unmap 1   above 1   KEYBOARD MOVES TO .rdw
# and it stays there through every later `update`. A window manager grants
# focus to a newly MAPPED toplevel, and the one thing in this file that catches
# that grant - `rdw::_arm_focus_handback` - returns 0 WITHOUT ARMING when .rdw
# already exists and is mapped, which is exactly the case this item is about.
# So the obvious implementation of R4 takes the keyboard off the schematic on
# every dump into an open window, and the user forbade that in the same
# sentence as the request. Every row below reads `focus` after settling.
# ⚠ AND IT IS SATISFIABLE, measured the same way rather than assumed: with
# `::rdw::focus_pending` set to 1 before the re-map, the keyboard is back on
# .drw afterwards and the flag is cleared. The demand is met by ARMING the
# existing hand-back, not by inventing a second focus path.
#
# ⚠ AND `:99` CANNOT SEE THE DEFECT THE USER REPORTED. A plain `raise` scores
# `above 1` here and does nothing on their server. That is what the Map/Unmap
# counters are for: they are read from real X events on .rdw and say the window
# was really RE-MAPPED, which is the Library Manager's own idiom and the only
# thing that works there. They cannot be satisfied by scheduling
# `_remap_verify` alone, and `_remap_verify` cannot be satisfied by a re-map
# that forgot issue 0843's recovery - so both are read, and neither alone.
#
# ⚠ AND ONE LEG HERE HAS NO TEETH ON THIS DISPLAY, SAID OUT LOUD RATHER THAN
# LEFT TO BE TRUSTED. The `wm geometry` legs fence issue 0054's north-west
# creep - a re-map that forgets to put the geometry back. Measured against a
# prototype with the geometry restore DELETED: openbox on :99 puts the window
# back by itself and the suite scores ALL PASS 59/59. So those legs are a fence
# for the window manager the user actually runs, and this display cannot fail
# them. They stay, because the cost is one comparison and the alternative is no
# fence at all; what may not happen is anyone reading a green run here as
# evidence that the geometry is safe.
#
# FIVE PROTOTYPES WERE RUN BEFORE THIS SECTION WAS COMMITTED, none of them
# touching src/ - each redefines `rdw::push` in the running interpreter and
# sources this file - and the table is what the rows are worth:
#   the shipped tree, nothing added        RA1 RA2 RA3 RA4 red
#   a plain `raise` (right on :99, inert
#     on the server the user reported from) RA2 RA3 red
#   the re-map with the hand-back NOT armed
#     (the obvious implementation)          RA1 RA2 RA4 red, on `focus` = .rdw
#   `raise_activate_toplevel` unchanged     RA1 RA2 RA3 RA4 red, on activation
#   the geometry restore deleted            NOTHING red - see above
#   the faithful DD-6 version               ALL PASS 59
#
# RED BEFORE R4, measured on this tree at HEAD 0122c9a7:
#   RA1  nothing raises at all         got above-after 0, exp 1
#   RA2  no re-map, no deferred verify  got 0 0 0 0, exp 1 1 1 1
#   RA3  the key path raises by rdw::open's plain `raise` only - above is
#        already 1, and the re-map legs are 0
#   RA4  an iconified window stays iconic through a dump
# GREEN BEFORE AND AFTER, and saying so is the point:
#   RA5  the fence that says the SPLIT left the Library Manager, the CIW,
#        create_instance and copy_form still ACTIVATING. Deleting the last line
#        of `raise_activate_toplevel` instead of splitting it satisfies every
#        other row in this section and silently stops four other windows taking
#        the focus they are entitled to.
#   RA6  hygiene.

if {[kx_ans ::rdw::have_tk] eq {1}} {

  ## ---- the settle, the spies and the parking ------------------------------
  ## A real wait, not `update`: the window manager's map-time focus grant and
  ## the `after 150` deferred re-map verify both arrive on a timer.
  proc ra_settle {ms} {
    set ::ra_tick 0
    after $ms {set ::ra_tick 1}
    vwait ::ra_tick
    catch {update}
    return {}
  }
  proc ra_w {args} {
    set rc [catch {uplevel #0 $args} r]
    if {$rc} { return "ERR:$r" }
    return $r
  }
  ## Relative stacking, the only question X can answer. ERR while a window is
  ## iconic, which row RA4 relies on and therefore does not read then.
  proc ra_above {} {
    set r ERR
    catch {set r [wm stackorder .rdw isabove .radecoy]}
    return $r
  }
  proc ra_zero {} {
    set ::RA_MAP 0 ; set ::RA_UNMAP 0 ; set ::RA_RV 0 ; set ::RA_ACT 0
    return {}
  }
  ## The Map/Unmap counters live on .rdw itself and must be re-armed every time
  ## the window is rebuilt. `%W` is filtered because the toplevel's name is in
  ## every child's bindtags, so a child's Map would otherwise count as the
  ## window's own.
  proc ra_watch {} {
    if {![winfo exists .rdw]} { return 0 }
    bind .rdw <Map>   {if {[string equal %W .rdw]} {incr ::RA_MAP}}
    bind .rdw <Unmap> {if {[string equal %W .rdw]} {incr ::RA_UNMAP}}
    return 1
  }
  ## POLL the fixture into place - decoy on top, keyboard on the canvas - and
  ## SAY whether it got there. Every row asserts this answer as a leg, so a row
  ## can never measure a raise against a window that was already on top.
  proc ra_park {} {
    for {set i 0} {$i < 20} {incr i} {
      catch {raise .radecoy}
      catch {focus -force .drw}
      catch {update}
      ra_settle 60
      if {[ra_w focus] eq {.drw} && [ra_above] eq {0}} { return 1 }
    }
    return 0
  }
  proc ra_blk {} {
    set ans [dict create devices [dict create {@m.x1.mra} {{id 1.234} {vth 0.5}}] \
                         absent {} nonfinite {} complete 0 state ok]
    set ctx [dict create header {MRA:/} devpath {@m.x1.mra} simtype op \
                         instname MRA sim ngspice]
    return [kx_ans ::rdw::format_answer $ans $ctx]
  }
  proc ra_panehas {needle} {
    set t [ra_w .rdw.p.t get 1.0 end]
    if {[string match {ERR:*} $t]} { return ERR }
    return [expr {[string first $needle $t] >= 0 ? 1 : 0}]
  }
  ## .rdw open and mapped, the store empty, the decoy on top, the keyboard on
  ## the canvas, the counters zeroed.  Answers ra_park's verdict.
  proc ra_fixture {} {
    set ::rdw::blocks {}
    kx_ans ::rdw::set_row 0
    kx_ans ::rdw::status {}
    kx_ans ::rdw::open
    catch {update}
    ra_settle 150
    ra_watch
    set ok [ra_park]
    ra_zero
    return $ok
  }

  set ::RA_MAP 0 ; set ::RA_UNMAP 0 ; set ::RA_RV 0 ; set ::RA_ACT 0
  ## The activation spy. An EXECUTION TRACE and not a rename: `xschem` is a C
  ## command that every row in this file leans on, and a Tcl wrapper around it
  ## would have to reproduce its result and error behaviour exactly. Measured:
  ## `trace add execution` attaches to the C command and fires.
  proc ra_spy_act {args} {
    if {[string match {*activate_window*} [lindex $args 0]]} { incr ::RA_ACT }
    return {}
  }
  proc ra_spy_rv {args} { incr ::RA_RV ; return {} }
  set RA_TX [catch {trace add execution xschem enter ::ra_spy_act}]
  set RA_TR [catch {trace add execution ::_remap_verify enter ::ra_spy_rv}]

  catch {destroy .radecoy}
  toplevel .radecoy
  wm title .radecoy {RDW raise decoy}
  wm geometry .radecoy 380x260+60+60
  text .radecoy.t -width 20 -height 4
  pack .radecoy.t
  catch {update}
  ra_settle 200

  # --- RA1  THE DOOR RAISES, AND THE KEYBOARD DOES NOT MOVE -----------------
  set RA1_OK  [ra_fixture]
  set RA1_M0  [ra_w winfo ismapped .rdw]
  set RA1_AB0 [ra_above]
  set RA1_F0  [ra_w focus]
  set RA1_G0  [ra_w wm geometry .rdw]
  set RA1_R   [kx_ans ::rdw::push [ra_blk]]
  catch {update}
  ra_settle 500
  check {RA1 A DUMP RAISES THE WINDOW: with .rdw open and mapped but parked UNDER another toplevel and the keyboard on the schematic, one push puts .rdw above that toplevel and leaves everything else exactly where it was - the other window still mapped, .rdw the same size and in the same place as before (issue 0054's north-west creep), the keyboard still on the canvas because the user said no need to focus, no _NET_ACTIVE_WINDOW asked for at all (ruling DD-6), and the block itself both stored and on screen} \
    [list $RA1_OK $RA_TX $RA_TR $RA1_M0 $RA1_AB0 $RA1_F0 \
          [kx_bad $RA1_R] \
          [ra_above] [ra_w winfo ismapped .rdw] [ra_w winfo ismapped .radecoy] \
          [expr {[ra_w wm geometry .rdw] eq $RA1_G0 ? 1 : 0}] \
          [ra_w focus] $::RA_ACT [kx_nblocks] [ra_panehas MRA]] \
    [list 1 0 0 1 0 .drw 0 1 1 1 1 .drw 0 1 1]

  # --- RA2  IT IS THE LIBRARY MANAGER'S RAISE, NOT A BARE `raise` -----------
  ## The row :99 cannot otherwise reach. A plain `raise` scores everything RA1
  ## asks for on THIS display and nothing at all on the one the user reported
  ## from, so this row reads the two receipts of the re-map idiom itself: real
  ## Unmap+Map events on .rdw (issue 0054), and the deferred `_remap_verify`
  ## that recovers a dropped re-map (issue 0843). Both, because either alone
  ## can be faked by half the idiom.
  set RA2_OK [ra_fixture]
  set RA2_G0 [ra_w wm geometry .rdw]
  set RA2_R  [kx_ans ::rdw::push [ra_blk]]
  catch {update}
  ra_settle 500
  check {RA2 THE RAISE IS THE ONE THE USER NAMED - the Library Manager's, which does not trust a plain raise: the window is really RE-MAPPED, one Unmap and one Map arriving on .rdw itself, and issue 0843's deferred _remap_verify is scheduled and runs, so a window manager that drops the re-map still gets it back - and after all of that the window is mapped, on top, the same size and place, the keyboard is still on the canvas and nothing asked for activation} \
    [list $RA2_OK [kx_bad $RA2_R] \
          [expr {$::RA_UNMAP >= 1 ? 1 : 0}] [expr {$::RA_MAP >= 1 ? 1 : 0}] \
          [expr {$::RA_RV >= 1 ? 1 : 0}] \
          [ra_above] [ra_w winfo ismapped .rdw] \
          [expr {[ra_w wm geometry .rdw] eq $RA2_G0 ? 1 : 0}] \
          [ra_w focus] $::RA_ACT] \
    [list 1 0 1 1 1 1 1 1 .drw 0]

  # --- RA3  THE SHIPPED KEY PATH, NOT A HAND-CALLED push --------------------
  ## A real bare 1 on the canvas over a selected device, the whole chain:
  ## bind -> rdw::key -> rdw::show -> rdw::open -> rdw::dump -> dump_devpath
  ## -> push. The list identity moving from summary to annotation is the
  ## receipt that the key really arrived, so no leg here can pass by nothing
  ## happening.
  xschem load $KX_SCH
  xschem zoom_full
  catch {update idletasks}
  set RA3_OK [ra_fixture]
  kx_ans ::rdw::set_list summary
  xschem unselect_all
  xschem select instance M1
  catch {update idletasks}
  set RA3_SEL [expr {[llength [kx_sel]] > 0 ? 1 : 0}]
  set RA3_LK0 [kx_listkind]
  set RA3_N0  [kx_nblocks]
  set RA3_AB0 [ra_above]
  set RA3_G0  [ra_w wm geometry .rdw]
  ra_zero
  catch {focus -force .drw}
  catch {update}
  event generate .drw <Key-1> -when now
  catch {update}
  ra_settle 500
  check {RA3 AND IT HAPPENS ON THE PATH THE USER'S HAND TAKES: a real bare 1 over a selected device runs the whole noun-verb chain and the window it dumps into is re-mapped to the front - the list identity moving from summary to annotation and the store gaining a block are the receipts that the key arrived, and afterwards the keyboard is back on the schematic, not in the window, which is where a raise wired without arming the hand-back leaves it} \
    [list $RA3_OK $RA3_SEL $RA3_LK0 $RA3_N0 $RA3_AB0 \
          [kx_listkind] [kx_nblocks] \
          [expr {$::RA_UNMAP >= 1 ? 1 : 0}] [expr {$::RA_MAP >= 1 ? 1 : 0}] \
          [expr {$::RA_RV >= 1 ? 1 : 0}] \
          [ra_above] [ra_w winfo ismapped .rdw] \
          [expr {[ra_w wm geometry .rdw] eq $RA3_G0 ? 1 : 0}] \
          [ra_w focus] $::RA_ACT] \
    [list 1 1 summary 0 0 annotation 1 1 1 1 1 1 1 .drw 0]

  # --- RA4  A CLOSED WINDOW IS NOT CONJURED, AN ICONIFIED ONE COMES BACK ----
  ## Two cases the raise must tell apart, and the first is the one an
  ## `rdw::open` bolted onto push would break: `rdw::open` is this window's ONE
  ## constructor (row N1 of the window suite), the dumps deliberately survive a
  ## close, and a store push under a closed window must stay a store push.
  ## The second is the Library Manager's own answer to Ctrl-Alt-S on an
  ## iconified window: it comes back.
  kx_ans ::rdw::close
  catch {update}
  ra_settle 150
  set ::rdw::blocks {}
  kx_ans ::rdw::set_row 0
  ra_zero
  set RA4_R1 [kx_ans ::rdw::push [ra_blk]]
  catch {update}
  ra_settle 150
  set RA4_EX [expr {[winfo exists .rdw] ? 1 : 0}]
  set RA4_N1 [kx_nblocks]
  set RA4_OK [ra_fixture]
  ra_w wm iconify .rdw
  catch {update}
  ra_settle 400
  set RA4_M0  [ra_w winfo ismapped .rdw]
  set RA4_ST0 [ra_w wm state .rdw]
  ra_zero
  set RA4_R2 [kx_ans ::rdw::push [ra_blk]]
  catch {update}
  ra_settle 600
  check {RA4 A DUMP WITH NO WINDOW BUILDS NONE - rdw::open is the one constructor and the dumps survive a close, so a push into a closed window still just stores the block - and a dump into an ICONIFIED window brings it back the way Ctrl-Alt-S brings the Library Manager back: mapped again, in the normal state, on top, and still without taking the keyboard off the schematic} \
    [list [kx_bad $RA4_R1] $RA4_EX $RA4_N1 \
          $RA4_OK $RA4_M0 $RA4_ST0 \
          [kx_bad $RA4_R2] \
          [ra_w winfo ismapped .rdw] [ra_w wm state .rdw] [ra_above] \
          [ra_w focus] $::RA_ACT] \
    [list 0 0 1 1 0 iconic 0 1 normal 1 .drw 0]

  # --- RA5  FENCE the four other callers still ACTIVATE ---------------------
  ## GREEN BEFORE AND AFTER. Ruling DD-6 drops the LAST LINE of
  ## `raise_activate_toplevel` for the RDW only - by splitting the proc or by
  ## adding an argument, never by deleting the line. Deleting it satisfies
  ## every row above and silently stops the Library Manager, the CIW,
  ## create_instance and copy_form taking the focus they are entitled to, on a
  ## path no row in this batch's four suites walks. This row is also the
  ## NON-VACUITY control for the `$::RA_ACT 0` leg every row above carries: if
  ## the trace never attached, those legs are worthless and this one reds.
  ## ⚠ .rdw IS PUT BACK TO `normal` FIRST AND ra_park's ANSWER IS A LEG. Row
  ## RA4 leaves the window ICONIC until R4 lands, and `wm stackorder` RAISES
  ## against an iconic window rather than answering 0 - so without this the
  ## fence would red for RA4's reason and say nothing about its own subject.
  catch {wm deiconify .rdw}
  catch {update}
  ra_settle 250
  set RA5_P [ra_park]
  ra_zero
  set RA5_R [kx_ans ::raise_activate_toplevel .radecoy]
  catch {update}
  ra_settle 400
  check {RA5 FENCE the shared raise still ACTIVATES for its other four callers - the Library Manager, the CIW, create_instance and copy_form ask for the focus the RDW must not take, and this row is also the control that says the activation spy every row above trusts is really attached} \
    [list $RA5_P [kx_bad $RA5_R] [expr {$::RA_ACT >= 1 ? 1 : 0}] \
          [ra_w winfo ismapped .radecoy] [ra_above]] \
    [list 1 0 1 1 0]

  # --- RA6  HYGIENE ---------------------------------------------------------
  catch {trace remove execution xschem enter ::ra_spy_act}
  catch {trace remove execution ::_remap_verify enter ::ra_spy_rv}
  set RA6_TX {}
  catch {set RA6_TX [trace info execution xschem]}
  set RA6_TR {}
  catch {set RA6_TR [trace info execution ::_remap_verify]}
  catch {destroy .radecoy}
  kx_ans ::rdw::close
  set ::rdw::blocks {}
  kx_ans ::rdw::set_row 0
  kx_ans ::rdw::set_list annotation
  kx_ans ::rdw::status {}
  xschem unselect_all
  catch {focus -force .drw}
  catch {update}
  ra_settle 150
  check {RA6 HYGIENE section RA leaves nothing behind: no decoy toplevel, no window, no stored dumps, no cursored row, neither execution trace still attached, the keyboard back on the canvas and no untitled* anywhere} \
    [list [expr {[winfo exists .radecoy] ? 1 : 0}] \
          [expr {[winfo exists .rdw] ? 1 : 0}] \
          [llength $::rdw::blocks] \
          [kx_ans ::rdw::_target_line] \
          [expr {[string first ra_spy_act $RA6_TX] >= 0 ? 1 : 0}] \
          [expr {[string first ra_spy_rv $RA6_TR] >= 0 ? 1 : 0}] \
          [ra_w focus] \
          [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S1_ROOT0 ? 1 : 0}] \
          [llength [glob -nocomplain -directory $scratch -tails untitled*]]] \
    [list 0 0 0 0 0 0 .drw 1 0]
}


# ============================================================================
# SECTION CP — ITEM R3, ISSUE 1339: SELECT, AND ACTUALLY GET THE TEXT OUT
# ============================================================================
# The user's words: "Select and then press CTRL-C doesn't work. (Using VcXsrv
# for now). Double-click to start selection and then extend selection with
# press-and-drag seemed to work once, but not reliably. It's only worked one
# time."
#
# This is the item that decides whether the window is usable at all: the whole
# stated reason it is a Text widget and not a CIW dump is that a block can be
# selected and pasted into a design-review document.
#
# ⚠ THE OBVIOUS ROW IS GREEN TODAY, AND IT MEASURES NOTHING. Measured here on
# :99 before this section was written: with the keyboard in the pane and a
# selection standing, a real <Control-Key-c> ALREADY puts the line on the
# CLIPBOARD -- Tk 8.6.17's Text class binding for <<Copy>> does it, and on this
# build <<Copy>> resolves to
#     <Control-Key-c> <Key-F16> <Control-Lock-Key-C> <Meta-Key-w>
#     <Lock-Meta-Key-W> <Control-Key-Insert>
# so <Control-Key-Insert> is already carried too. A row that selected a line,
# pressed Ctrl-C at the pane and asserted the clipboard would pass on the
# unmodified tree and tell the user nothing. Every red row below is therefore
# built on a state the USER is actually in and this suite was not.
#
# THE FOUR THINGS THAT ARE ACTUALLY BROKEN, EACH MEASURED ON THIS BINARY,
# 2026-09-05, ON :99, BEFORE ANY src CHANGE:
#
#   1. ANOTHER CLIENT TAKES THE X PRIMARY SELECTION AND THE SELECTION VANISHES.
#      The pane is -exportselection 1 (rdw::_exportsel). A Tk text widget that
#      loses PRIMARY DELETES ITS OWN sel TAG: measured, `selection own
#      -selection PRIMARY .` leaves `tag ranges sel` EMPTY, `get sel.first
#      sel.last` raising "text doesn't contain any characters tagged with sel",
#      and a following Ctrl-C copying NOTHING AT ALL -- tk_textCopy's catch
#      swallows it and the clipboard is never written. That is both halves of
#      the user's report in one mechanism, and VcXsrv is exactly where it
#      bites: its Windows clipboard bridge takes PRIMARY on its own schedule,
#      which is why the gesture "worked one time".                     -> CP3
#
#   2. THE KEYBOARD IS USUALLY NOT IN THE PANE. Every copy today rides the Text
#      CLASS binding, so it exists only while the keyboard is on .rdw.p.t.
#      Measured: with the keyboard on the Up button of this very window a real
#      Ctrl-C copies nothing (the CLIPBOARD does not even come into existence),
#      and with it on the toplevel .rdw the same. Both are one click away --
#      the button column is what item R2 just made worth pressing, and
#      rdw::_arm_focus_handback deliberately hands the keyboard to the CANVAS
#      after a dump, so "press a button, then copy" is the ordinary path.  -> CP2
#
#   3. THERE IS NO WAY TO COPY WITHOUT THE KEYBOARD. Measured: `bind .rdw.p.t
#      <Button-3>`, `bind Text <Button-3>` and `bind all <Button-3>` are all the
#      EMPTY STRING and .rdw has three children, none of them a menu. Ruling
#      DD-5 requires a right-click Copy / Select All, so that a chord a window
#      manager or an X server eats can never leave the user with no way to get
#      the text out -- which is the whole point of the window.          -> CP4
#
#   4. DOUBLE-CLICK-THEN-PRESS-AND-DRAG THROWS THE SELECTION AWAY. Measured
#      five times out of five, deterministically, on line 3 of the fixture:
#      the double-click selects `complete` at 3.6-3.14; a separate press at
#      3.10 followed by a drag to 3.40 answers 3.10-3.40 -- `lete list: these
#      are the opera`. The word the user double-clicked is CUT IN HALF. The
#      gesture that does work is holding the second click down (word-wise
#      extension, 3.6-3.44) and so does shift-click, which is why it "seemed to
#      work once": the user's hand sometimes held the second click.     -> CP6
#
# ⚠ AND THE INPUT MOST LIKELY TO BREAK THE FIX, WITH A ROW OF ITS OWN. Ruling
# DD-5 spells the copy as `clipboard clear` + `clipboard append`. Written in
# that order with no selection to append, it WIPES THE USER'S CLIPBOARD -- the
# document they were about to paste into, gone, because they pressed Ctrl-C in
# the wrong window. Tk's own tk_textCopy guards it with a catch and today's
# behaviour is safe (measured: a sentinel survives). CP5 is that fence, and it
# is written as a fence rather than a feature on purpose.
#
# ⚠ THE SECOND-LIKELIEST: AN EXTEND THAT EXTENDS EVERYTHING. If a press-and-drag
# always extends, the user can never make a SMALL selection - the second one
# grows out of the first for ever. CP7 presses OUTSIDE the standing selection
# and requires a FRESH one, alongside the two gestures that work today.
#
# WHERE THE ROWS LIVE. All of it needs a mapped pane, real button and key
# events, a real X selection and a real clipboard, so all of it is here rather
# than in the structural suite, and all of it must be run through
#     GUI_GATE=0 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q \
#         --nolog --script tests/headless/test_rdw_keys_1245.tcl
#
# ⚠ RULING DD-8: :99 IS NOT ENOUGH FOR THIS ITEM. $DISPLAY is the VcXsrv /
# HC-Consult server the user actually looks at and AUDIT_DISPLAY=:0 is WSLg's
# Xwayland - three different servers (CLAUDE.md's table), and selection and
# clipboard are precisely where they differ. A green run here is necessary and
# not sufficient; the item is not done until it has run on $DISPLAY.

if {[kx_ans ::rdw::have_tk] eq {1}} {

  ## The widget-expression wrapper this section needs (cu_w's twin, kept
  ## separate so a rename in one section cannot silently change another).
  proc cp_w {args} {
    set rc [catch {uplevel #0 $args} r]
    if {$rc} { return "ERR:$r" }
    return $r
  }
  ## ⚠ `clipboard get` RAISES when nothing owns the CLIPBOARD, and that is the
  ## state a failed copy leaves. A bare read would abort the suite mid-run.
  proc cp_clip {} {
    set v {}
    if {[catch {clipboard get} v]} { return NOCLIP }
    return $v
  }
  proc cp_setclip {s} { catch {clipboard clear} ; catch {clipboard append -- $s} }
  proc cp_sel {} {
    set v {}
    if {[catch {.rdw.p.t get sel.first sel.last} v]} { return NOSEL }
    return $v
  }
  proc cp_selrng {} {
    set v {}
    if {[catch {.rdw.p.t tag ranges sel} v]} { return ERR }
    return $v
  }
  proc cp_cmp {a op b} {
    set r {}
    if {[catch {.rdw.p.t compare $a $op $b} r]} { return ERR }
    return $r
  }
  proc cp_status {} {
    if {![info exists ::rdw::statusmsg]} { return NO-VAR }
    return $::rdw::statusmsg
  }
  ## ⚠ THE STATUS SURFACE IS A `text` SINCE ISSUE 1362, so the three calls
  ## below are the text spelling of what CP14 and CP16 used to say to an
  ## `entry`.  Neither row's PROPERTY moved and neither row's expected values
  ## moved; only the widget's own vocabulary did -- `selection present/range/
  ## clear` for an entry is `tag ranges/add/remove sel` for a text.  The
  ## difference that matters is underneath: an entry's selection was a pair of
  ## INDICES that survived a rewrite (issue 1351's defect), while a `sel` tag
  ## is a hold on the characters and dies with the repaint.  CP16's last leg is
  ## therefore the leg that carries the row now: `rdw::status` repaints only
  ## when the text really changed, so a line rewritten to what it already said
  ## must still keep the user's selection.
  proc cp_smsg_present {} {
    set r [cp_w .rdw.s.msg tag ranges sel]
    if {[string match {ERR:*} $r]} { return $r }
    return [expr {[llength $r] >= 2 ? 1 : 0}]
  }
  proc cp_smsg_range {a b} { catch {.rdw.s.msg tag add sel 1.$a 1.$b} }
  proc cp_smsg_clear {} { catch {.rdw.s.msg tag remove sel 1.0 end} }
  ## ⚠ EVENTS CARRY AN EXPLICIT, MONOTONIC TIME. Tk decides double-click from
  ## the event's own `time` field, so two presses generated back to back are a
  ## double only by accident of the clock - and `event generate` REFUSES a
  ## Double modifier outright ("Double, Triple, or Quadruple modifier not
  ## allowed", measured). Stamping the times is what makes CP6 deterministic
  ## instead of a race, which is issue 1332's lesson applied before the fact.
  set ::CP_T 100000
  proc cp_ev {w seq args} {
    incr ::CP_T 40
    catch {eval [list event generate $w $seq -when now -time $::CP_T] $args}
  }
  ## Past the multiple-click time: the next press is a FRESH one, not a triple.
  proc cp_gap {} { incr ::CP_T 900 }
  ## POLL for the keyboard, never `after`. The window manager's grant to a
  ## freshly re-mapped toplevel (item R4 re-maps on every dump) arrives on a
  ## MapNotify round trip and can land after a `focus -force`.
  proc cp_focus {w} {
    for {set i 0} {$i < 60} {incr i} {
      catch {focus -force $w}
      catch {update}
      if {[focus] eq $w} { return $w }
      after 10
    }
    return [focus]
  }
  ## Every Menu widget in the application, and the posted ones. Walked from `.`
  ## because a popup may be a child of .rdw or of the main window, and DIFFED
  ## before/after: xschem's own menubar carries a Copy entry, so "a menu that
  ## has a Copy label" is not by itself evidence that the pane posted one.
  proc cp_menus {} {
    set out {}
    set q [list .]
    while {[llength $q]} {
      set w [lindex $q 0]
      set q [lrange $q 1 end]
      if {![winfo exists $w]} { continue }
      if {[winfo class $w] eq {Menu}} { lappend out $w }
      foreach c [winfo children $w] { lappend q $c }
    }
    return [lsort $out]
  }
  proc cp_posted_menus {} {
    set out {}
    foreach m [cp_menus] { if {[cp_w winfo ismapped $m] eq {1}} { lappend out $m } }
    return $out
  }
  ## The index of the first entry whose label matches, or -1.
  ## ⚠ `set l {}` INSIDE the loop: a separator has no -label at all and the
  ## catch would otherwise leave the PREVIOUS entry's label standing, so a
  ## separator following Copy would answer to *copy* as well.
  proc cp_entry {m pat} {
    set n {}
    if {[catch {$m index end} n]} { return -1 }
    if {![string is integer -strict $n]} { return -1 }
    for {set i 0} {$i <= $n} {incr i} {
      set l {}
      catch {set l [$m entrycget $i -label]}
      if {[string match -nocase $pat $l]} { return $i }
    }
    return -1
  }
  ## Is the span a..b still HIGHLIGHTED - covered by some tag the user can see?
  ## ⚠ THE FOUR RENDER TAGS AND THE CURSOR ARE EXCLUDED, AND WITHOUT THAT THIS
  ## PREDICATE IS A LIE: hdr / dim / dev / note each cover a WHOLE LINE of the
  ## fixture and `cursor` covers the whole cursored line, so any of them would
  ## answer yes for a span inside that line and CP3 would pass with the
  ## selection long gone. What is left is `sel` - or a tag an implementation
  ## introduces to keep the highlight alive across a PRIMARY theft, which is
  ## the point: this asks whether the user can still SEE what they selected,
  ## not which tag is doing it.
  proc cp_highlighted {a b} {
    set names {}
    if {[catch {.rdw.p.t tag names} names]} { return ERR }
    foreach t $names {
      if {[lsearch -exact {cursor hdr dim dev note} $t] >= 0} { continue }
      set r {}
      catch {set r [.rdw.p.t tag ranges $t]}
      foreach {s e} $r {
        if {[cp_cmp $s <= $a] eq {1} && [cp_cmp $e >= $b] eq {1}} { return $t }
      }
    }
    return {}
  }
  ## The fixture: ONE block, six lines - header / devpath / ONE LONG NOTE THAT
  ## REALLY WRAPS / two parameter rows / the separator.
  ##
  ## ⚠ THE WRAPPING NOTE IS RULING DD-5's ANALYSIS SENTENCE (~236 characters).
  ## It was DD-1's incompleteness sentence until issue 1374 cut that one to 57
  ## characters on the user's ruling, at which point line 3 stopped wrapping,
  ## CP1's control leg went false and rows CP6/CP7 -- which drag between
  ## columns 10 and 60 of line 3 -- were dragging past the end of it.  `simtype
  ## dc` raises the analysis line, `complete 1` drops the incompleteness line,
  ## and the block is six lines again with a long note on line 3.  The wrap is
  ## load-bearing for the whole section: `rdw::_copy_lines` counts LOGICAL
  ## lines, and a fixture with no wrapped line cannot tell that from display
  ## rows.
  proc cp_block {} {
    set ans [dict create devices [dict create {@m.x1.mcu} {{id 1.234} {vth 0.5}}] \
                         absent {} nonfinite {} complete 1 state ok]
    set ctx [dict create header {MCU:/} devpath {@m.x1.mcu} simtype dc \
                         instname MCU sim ngspice]
    return [kx_ans ::rdw::format_answer $ans $ctx]
  }
  proc cp_fixture {} {
    catch {clipboard clear}
    set ::rdw::blocks {}
    kx_ans ::rdw::set_row 0
    kx_ans ::rdw::push [cp_block]
    kx_ans ::rdw::render_pane
    catch {update idletasks}
    ## ⚠ SPEND THE ONE-SHOT BY HAND. rdw::push re-maps the window (item R4) and
    ## arms rdw::_arm_focus_handback with it; every row below reads the
    ## KEYBOARD, and a hand-back firing in the middle of one would measure
    ## issue 1306 instead of this item. Asserted as a leg of CP1.
    catch {set ::rdw::focus_pending 0}
    catch {.rdw.p.t tag remove sel 1.0 end}
    cp_focus .rdw.p.t
    catch {update}
    return {}
  }

  kx_ans ::rdw::open
  catch {update idletasks}
  cp_fixture

  # --- CP1  CONTROL: the fixture, so no row below can pass vacuously --------
  set CP1_L1 [cp_w .rdw.p.t get 1.0 {1.0 lineend}]
  set CP1_L3 [cp_w .rdw.p.t get 3.0 {3.0 lineend}]
  set CP1_B3 [cp_w .rdw.p.t bbox 3.10]
  set CP1_DL [cp_w .rdw.p.t count -displaylines 3.0 {3.0 lineend}]
  cp_w .rdw.p.t tag add sel 1.0 {1.0 lineend}
  catch {update}
  set CP1_SEL [cp_sel]
  check {CP1 CONTROL the fixture every row below stands on: the pane is mapped, still read-only, holds the six-line block whose third line really WRAPS, the keyboard is in the pane, the focus hand-back one-shot is spent, and a selection made by hand really reads back as the line it covers - without all of that the copy rows measure nothing} \
    [list [cp_w winfo ismapped .rdw.p.t] \
          [cp_w .rdw.p.t cget -state] \
          [focus] \
          [kx_pending] \
          [expr {$CP1_L1 eq {MCU:/} ? 1 : 0}] \
          [expr {[string length $CP1_L3] > 60 ? 1 : 0}] \
          [expr {[string is integer -strict $CP1_DL] && $CP1_DL >= 1 ? 1 : 0}] \
          [expr {[llength $CP1_B3] == 4 ? 1 : 0}] \
          [expr {$CP1_SEL eq $CP1_L1 ? 1 : 0}]] \
    {1 disabled .rdw.p.t 0 1 1 1 1 1}

  # --- CP2  Ctrl-C copies from ANYWHERE inside the window -------------------
  ## THE USER'S FIRST SENTENCE. Today the copy is Tk's Text CLASS binding and
  ## therefore exists only while .rdw.p.t itself holds the keyboard. One click
  ## on the button column item R2 just made worth pressing - or the hand-back
  ## that follows every dump - and Ctrl-C is dead. Each leg FOCUSES the widget,
  ## asserts the keyboard really landed there, and then delivers the chord to
  ## whatever holds it, because Tk redirects key events to the focus window and
  ## a chord generated at a widget that is not focused would be answered by the
  ## pane and pass while the user's own keystroke is lost.
  cp_fixture
  cp_w .rdw.p.t tag add sel 1.0 {1.0 lineend}
  catch {update}
  set CP2_WANT [cp_sel]
  set CP2_GOT {}
  set CP2_EXP {}
  foreach cpw {.rdw.p.t .rdw.b.up .rdw.b.save .rdw} {
    foreach cpseq {<Control-Key-c> <Control-Key-Insert>} {
      set here [cp_focus $cpw]
      catch {clipboard clear}
      cp_ev $here $cpseq
      catch {update}
      lappend CP2_GOT [list $cpw $here [expr {[cp_clip] eq $CP2_WANT ? 1 : 0}]]
      lappend CP2_EXP [list $cpw $cpw 1]
    }
  }
  check {CP2 Ctrl-C and Ctrl-Insert copy the selection from ANY widget inside the Results Display Window - the text pane, the Up button, the Save button and the toplevel itself - because the user presses the chord where their hands are and not where Tk keeps its focus, and one press of a button column is all it takes to lose the class binding the copy rides today} \
    [list $CP2_GOT [cp_sel] [cp_w .rdw.p.t cget -state]] \
    [list $CP2_EXP $CP2_WANT disabled]

  # --- CP3  the copy survives another client taking PRIMARY -----------------
  ## THE MECHANISM, DRIVEN RATHER THAN CITED. `selection own -selection PRIMARY
  ## .` is another X client taking the primary selection, which is what VcXsrv's
  ## Windows clipboard bridge does on its own schedule. Measured on the
  ## unmodified tree: the pane's sel tag is DELETED, the highlight the user is
  ## looking at disappears, and Ctrl-C then writes nothing at all.
  cp_fixture
  cp_w .rdw.p.t tag add sel 2.0 {2.0 lineend}
  catch {update}
  set CP3_WANT [cp_sel]
  set CP3_LINE [cp_w .rdw.p.t get 2.0 {2.0 lineend}]
  proc cp_steal_handler {args} { return {STOLEN-BY-ANOTHER-CLIENT} }
  catch {selection handle . cp_steal_handler}
  catch {selection own -selection PRIMARY .}
  catch {update}
  set CP3_PRIM NOPRIM
  catch {set CP3_PRIM [selection get -selection PRIMARY]}
  set CP3_VIS [cp_highlighted 2.0 {2.0 lineend}]
  set CP3_HERE [cp_focus .rdw.p.t]
  catch {clipboard clear}
  cp_ev $CP3_HERE <Control-Key-c>
  catch {update}
  set CP3_CLIP [cp_clip]
  catch {selection clear -selection PRIMARY}
  catch {selection handle . {}}
  catch {update}
  check {CP3 THE MECHANISM THE USER IS ON: after another X client takes the PRIMARY selection - which is what the VcXsrv clipboard bridge does on its own schedule - the text the user selected is STILL highlighted in the pane and Ctrl-C still puts exactly that text on the CLIPBOARD. A Tk text widget that exports the selection answers a theft by deleting its own sel tag, so today the highlight vanishes under the user and the copy writes nothing} \
    [list [expr {$CP3_WANT eq $CP3_LINE && $CP3_LINE ne {} ? 1 : 0}] \
          [expr {$CP3_PRIM eq {STOLEN-BY-ANOTHER-CLIENT} ? 1 : 0}] \
          [expr {$CP3_VIS ne {} && $CP3_VIS ne {ERR} ? 1 : 0}] \
          [expr {$CP3_CLIP eq $CP3_WANT ? 1 : 0}]] \
    {1 1 1 1}

  # --- CP4  a Copy that needs no keyboard at all (ruling DD-5) --------------
  cp_fixture
  cp_w .rdw.p.t tag add sel 4.0 {4.0 lineend}
  catch {update}
  set CP4_WANT [cp_sel]
  set CP4_M0 [cp_posted_menus]
  set CP4_BB [cp_w .rdw.p.t bbox 4.0]
  set CP4_X [expr {[llength $CP4_BB] == 4 ? [lindex $CP4_BB 0] + 4 : 10}]
  set CP4_Y [expr {[llength $CP4_BB] == 4 ? [lindex $CP4_BB 1] + 4 : 10}]
  catch {clipboard clear}
  cp_ev .rdw.p.t <ButtonPress-3>   -x $CP4_X -y $CP4_Y
  cp_ev .rdw.p.t <ButtonRelease-3> -x $CP4_X -y $CP4_Y
  catch {update}
  set CP4_MENU {}
  foreach m [cp_posted_menus] {
    if {[lsearch -exact $CP4_M0 $m] < 0} { set CP4_MENU $m ; break }
  }
  set CP4_ICOPY -1
  set CP4_IALL -1
  if {$CP4_MENU ne {}} {
    set CP4_ICOPY [cp_entry $CP4_MENU {*copy*}]
    set CP4_IALL  [cp_entry $CP4_MENU {*select*all*}]
  }
  set CP4_CLIP NOCLIP
  if {$CP4_MENU ne {} && $CP4_ICOPY >= 0} {
    catch {$CP4_MENU invoke $CP4_ICOPY}
    catch {update}
    set CP4_CLIP [cp_clip]
  }
  catch {$CP4_MENU unpost}
  catch {grab release $CP4_MENU}
  catch {update}
  set CP4_ALL ERR
  if {$CP4_MENU ne {} && $CP4_IALL >= 0} {
    cp_ev .rdw.p.t <ButtonPress-3>   -x $CP4_X -y $CP4_Y
    cp_ev .rdw.p.t <ButtonRelease-3> -x $CP4_X -y $CP4_Y
    catch {update}
    catch {$CP4_MENU invoke $CP4_IALL}
    catch {update}
    set CP4_ALL [cp_selrng]
  }
  catch {$CP4_MENU unpost}
  catch {grab release $CP4_MENU}
  catch {update}
  ## THE MENU IS A SECOND DOOR ONTO THE CLIPBOARD AND IT NEEDS THE SAME GUARD.
  ## CP5 fences the chord against DD-5's `clipboard clear` + `clipboard append`
  ## wiping a clipboard there is nothing to append to; a Copy ITEM written the
  ## same way destroys the user's clipboard through the other door, and a fix
  ## that routes both through one proc passes both legs for free.
  set CP4_EMPTY NOCLIP
  if {$CP4_MENU ne {}} {
    catch {.rdw.p.t tag remove sel 1.0 end}
    catch {update}
    cp_setclip {SENTINEL-MENU-DO-NOT-WIPE}
    cp_ev .rdw.p.t <ButtonPress-3>   -x $CP4_X -y $CP4_Y
    cp_ev .rdw.p.t <ButtonRelease-3> -x $CP4_X -y $CP4_Y
    catch {update}
    if {$CP4_ICOPY >= 0} { catch {$CP4_MENU invoke $CP4_ICOPY} }
    catch {update}
    set CP4_EMPTY [cp_clip]
    catch {$CP4_MENU unpost}
    catch {grab release $CP4_MENU}
    catch {update}
  }
  check {CP4 RULING DD-5 there is a way to copy that does not depend on the keyboard: a right-click in the pane posts a menu carrying Copy and Select All, its Copy puts exactly the selected text on the CLIPBOARD, its Select All selects the whole pane, and its Copy with nothing selected leaves the user's clipboard alone - a chord a window manager or an X server eats must never leave the user with no way to get the text out, which is the entire purpose of this window} \
    [list [expr {$CP4_MENU ne {} ? 1 : 0}] \
          [expr {$CP4_ICOPY >= 0 ? 1 : 0}] \
          [expr {$CP4_IALL >= 0 ? 1 : 0}] \
          [expr {$CP4_CLIP eq $CP4_WANT && $CP4_WANT ne {NOSEL} ? 1 : 0}] \
          [expr {[llength $CP4_ALL] == 2 && [lindex $CP4_ALL 0] eq {1.0} \
                 && [cp_cmp [lindex $CP4_ALL 1] >= {end - 1c}] eq {1} ? 1 : 0}] \
          [expr {$CP4_EMPTY eq {SENTINEL-MENU-DO-NOT-WIPE} ? 1 : 0}] \
          [cp_w .rdw.p.t cget -state]] \
    {1 1 1 1 1 1 disabled}

  # --- CP5  FENCE plus the silence the bug report is made of ----------------
  ## THE INPUT MOST LIKELY TO BREAK THIS CHANGE. DD-5 spells the copy as
  ## `clipboard clear` + `clipboard append`; in that order with nothing
  ## selected it DESTROYS whatever the user had on the clipboard - very likely
  ## the thing they were about to paste the dump next to. Legs 1 and 2 are a
  ## fence and are green today, because Tk's own tk_textCopy guards it with a
  ## catch. Legs 3-5 are not: a copy that does nothing and says nothing cannot
  ## be told from a broken one, and "doesn't work" is precisely the report this
  ## item is answering.
  cp_fixture
  catch {.rdw.p.t tag remove sel 1.0 end}
  catch {update}
  cp_setclip {SENTINEL-DO-NOT-WIPE}
  kx_ans ::rdw::status {}
  set CP5_HERE [cp_focus .rdw.p.t]
  cp_ev $CP5_HERE <Control-Key-c>
  catch {update}
  set CP5_CLIP [cp_clip]
  set CP5_MSG [cp_status]
  cp_w .rdw.p.t tag add sel 1.0 {1.0 lineend}
  catch {update}
  kx_ans ::rdw::status {}
  catch {clipboard clear}
  cp_ev $CP5_HERE <Control-Key-c>
  catch {update}
  set CP5_CLIP2 [cp_clip]
  set CP5_MSG2 [cp_status]
  check {CP5 a Ctrl-C with nothing selected must not destroy the clipboard the user was about to paste into - and it must SAY so, because a copy that quietly does nothing is indistinguishable from the broken one this item exists to fix; a copy that succeeded says something different} \
    [list [expr {$CP5_CLIP eq {SENTINEL-DO-NOT-WIPE} ? 1 : 0}] \
          $CP5_HERE \
          [expr {[string trim $CP5_MSG] ne {} && $CP5_MSG ne {NO-VAR} ? 1 : 0}] \
          [kx_oneline $CP5_MSG] \
          [expr {[string trim $CP5_MSG2] ne {} && $CP5_MSG2 ne {NO-VAR} ? 1 : 0}] \
          [expr {$CP5_MSG2 ne $CP5_MSG ? 1 : 0}] \
          [expr {$CP5_CLIP2 eq [cp_sel] ? 1 : 0}]] \
    [list 1 .rdw.p.t 1 1 1 1 1]

  # --- CP6  double-click, then press-and-drag, EXTENDS - five times over ----
  ## THE USER'S SECOND SENTENCE, DRIVEN AS THEIR HAND DRIVES IT: double-click a
  ## word, let go, then press and drag. Measured 5/5 on the unmodified tree:
  ## the double-click selects `complete` and the drag REPLACES it with a
  ## character run starting where the second press landed, cutting the word in
  ## half. Every index below is read from the widget; none is transcribed.
  cp_fixture
  set CP6_Y  [expr {[lindex [cp_w .rdw.p.t bbox 3.0] 1] + 2}]
  set CP6_X0 [expr {[lindex [cp_w .rdw.p.t bbox 3.10] 0] + 2}]
  set CP6_X1 [expr {[lindex [cp_w .rdw.p.t bbox 3.40] 0] + 2}]
  proc cp_dbl_then_drag {x0 x1 y} {
    catch {.rdw.p.t tag remove sel 1.0 end}
    catch {update}
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x0 -y $y
    catch {update}
    set word [cp_selrng]
    cp_gap
    cp_ev .rdw.p.t <ButtonPress-1> -x $x0 -y $y
    catch {update}
    for {set px $x0} {$px <= $x1} {incr px 12} { cp_ev .rdw.p.t <B1-Motion> -x $px -y $y }
    cp_ev .rdw.p.t <B1-Motion> -x $x1 -y $y
    catch {update}
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x1 -y $y
    catch {update}
    return [list $word [cp_selrng]]
  }
  set CP6_R {}
  for {set n 0} {$n < 5} {incr n} {
    lappend CP6_R [cp_dbl_then_drag $CP6_X0 $CP6_X1 $CP6_Y]
  }
  set CP6_DRAGIX [cp_w .rdw.p.t index @$CP6_X1,$CP6_Y]
  set CP6_WORD [lindex [lindex $CP6_R 0] 0]
  set CP6_EXT  [lindex [lindex $CP6_R 0] 1]
  check {CP6 THE USER'S OWN GESTURE: double-click a word, let go, then press and drag - the selection must GROW, keeping the whole word that was double-clicked and reaching the point the drag ended, and it must do it five times running and not once. Today the second press throws the word away and starts a fresh character run from wherever it landed, which is why the user saw it work exactly one time} \
    [list [expr {[llength $CP6_WORD] == 2 ? 1 : 0}] \
          [cp_cmp [lindex $CP6_WORD 1] < $CP6_DRAGIX] \
          [cp_cmp [lindex $CP6_EXT 0] <= [lindex $CP6_WORD 0]] \
          [cp_cmp [lindex $CP6_EXT 1] >= $CP6_DRAGIX] \
          [llength [lsort -unique $CP6_R]]] \
    {1 1 1 1 1}

  # --- CP7  FENCE: the two gestures that DO work, and the small selection ---
  ## Legs 1-3 are green today and must stay green: holding the second click and
  ## dragging extends by word, and a shift-click extends to the click. Legs 4-5
  ## are the fence around CP6's fix - a press OUTSIDE the standing selection
  ## must start a FRESH one, or the user can never make a small selection again
  ## because every drag grows the previous one.
  cp_fixture
  set CP7_X2 [expr {[lindex [cp_w .rdw.p.t bbox 3.60] 0] + 2}]
  proc cp_held_drag {x0 x1 y} {
    catch {.rdw.p.t tag remove sel 1.0 end}
    catch {update}
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    catch {update}
    set word [cp_selrng]
    for {set px $x0} {$px <= $x1} {incr px 12} { cp_ev .rdw.p.t <B1-Motion> -x $px -y $y }
    cp_ev .rdw.p.t <B1-Motion> -x $x1 -y $y
    catch {update}
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x1 -y $y
    catch {update}
    return [list $word [cp_selrng]]
  }
  proc cp_dbl_then_shift {x0 x1 y} {
    catch {.rdw.p.t tag remove sel 1.0 end}
    catch {update}
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x0 -y $y
    catch {update}
    set word [cp_selrng]
    cp_gap
    cp_ev .rdw.p.t <Shift-ButtonPress-1> -x $x1 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1>     -x $x1 -y $y
    catch {update}
    return [list $word [cp_selrng]]
  }
  proc cp_fresh_drag {x0 x1 x2 y} {
    catch {.rdw.p.t tag remove sel 1.0 end}
    catch {update}
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonPress-1>   -x $x0 -y $y
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x0 -y $y
    catch {update}
    set word [cp_selrng]
    cp_gap
    cp_ev .rdw.p.t <ButtonPress-1> -x $x1 -y $y
    catch {update}
    for {set px $x1} {$px <= $x2} {incr px 12} { cp_ev .rdw.p.t <B1-Motion> -x $px -y $y }
    cp_ev .rdw.p.t <B1-Motion> -x $x2 -y $y
    catch {update}
    cp_ev .rdw.p.t <ButtonRelease-1> -x $x2 -y $y
    catch {update}
    return [list $word [cp_selrng]]
  }
  set CP7_H [cp_held_drag $CP6_X0 $CP6_X1 $CP6_Y]
  set CP7_S [cp_dbl_then_shift $CP6_X0 $CP6_X1 $CP6_Y]
  set CP7_F [cp_fresh_drag $CP6_X0 $CP6_X1 $CP7_X2 $CP6_Y]
  set CP7_MID [cp_w .rdw.p.t index @$CP6_X1,$CP6_Y]
  check {CP7 FENCE the two gestures that already work keep working - holding the second click of a double and dragging still extends, and a double-click then a shift-click still extends to the shift-click - and a press that lands OUTSIDE the standing selection still starts a FRESH one, without which the user could never make a small selection again because every drag would grow the last} \
    [list [cp_cmp [lindex $CP7_H 1 0] <= [lindex $CP7_H 0 0]] \
          [cp_cmp [lindex $CP7_H 1 1] >= [lindex $CP7_H 0 1]] \
          [cp_cmp [lindex $CP7_S 1 1] >= [lindex $CP7_S 0 1]] \
          [cp_cmp [lindex $CP7_F 1 0] >= $CP7_MID] \
          [cp_cmp [lindex $CP7_F 1 0] > [lindex $CP7_F 0 0]]] \
    {1 1 1 1 1}

  # --- CP8  FENCE: what lands on the clipboard is exactly the selection -----
  ## The pane is -wrap word and line 3 really does wrap (asserted at CP1), so a
  ## copy taken in DISPLAY lines would arrive in the design-review document
  ## broken across the pane's width. The paste shape is the whole deliverable.
  cp_fixture
  cp_w .rdw.p.t tag add sel 1.0 4.0
  catch {update}
  set CP8_WANT [cp_sel]
  set CP8_HERE [cp_focus .rdw.p.t]
  catch {clipboard clear}
  cp_ev $CP8_HERE <Control-Key-c>
  catch {update}
  set CP8_CLIP [cp_clip]
  set CP8_NAMES [cp_w .rdw.p.t tag names]
  set CP8_IC [lsearch -exact $CP8_NAMES cursor]
  set CP8_IS [lsearch -exact $CP8_NAMES sel]
  check {CP8 FENCE what reaches the clipboard is byte-for-byte the selection and nothing else: three LOGICAL lines even though the middle one wraps on screen, the selection still standing afterwards so a second copy is possible, the pane still read-only, and the line cursor still below sel so the user can see what they selected} \
    [list [expr {$CP8_CLIP eq $CP8_WANT && $CP8_WANT ne {NOSEL} ? 1 : 0}] \
          [llength [split $CP8_WANT "\n"]] \
          [expr {[cp_selrng] ne {} && [cp_selrng] ne {ERR} ? 1 : 0}] \
          [cp_w .rdw.p.t cget -state] \
          [expr {$CP8_IC >= 0 && $CP8_IS >= 0 && $CP8_IC < $CP8_IS ? 1 : 0}]] \
    [list 1 4 1 disabled 1]

  # --- CP10 FENCE: the selection still reaches the X PRIMARY selection ------
  ## ⚠ THE ONE PROMISE A CHEAP FIX FOR CP3 WOULD SPEND, AND THIS ROW IS HERE SO
  ## THAT SPENDING IT IS VISIBLE. CP3's theft cannot happen at all if the pane
  ## stops exporting the selection - `rdw::_exportsel` is a one-line accessor
  ## whose own comment says it exists so a reviewer can flip it and watch the
  ## suite say which promise broke, and this is that row. Flipping it to 0
  ## makes CP3 pass and costs the X select-then-middle-click paste that
  ## rdw::_exportsel calls "the user's stated reason the window exists at all".
  ## The row is GREEN TODAY and it is not a veto: it is the receipt that
  ## somebody decided, rather than a promise that disappeared quietly.
  cp_fixture
  cp_w .rdw.p.t tag add sel 5.0 {5.0 lineend}
  catch {update}
  set CP10_WANT [cp_sel]
  set CP10_PRIM NOPRIM
  catch {set CP10_PRIM [selection get -selection PRIMARY]}
  check {CP10 FENCE a selection made in the pane still reaches the X PRIMARY selection, so select-then-middle-click-paste into another application keeps working - the theft CP3 is about cannot happen to a pane that exports nothing, and this row is what makes paying that price a decision somebody took rather than one that vanished quietly} \
    [list [expr {$CP10_WANT ne {NOSEL} && $CP10_WANT ne {} ? 1 : 0}] \
          [expr {$CP10_PRIM eq $CP10_WANT ? 1 : 0}] \
          [cp_w .rdw.p.t cget -exportselection] \
          [kx_ans ::rdw::_exportsel]] \
    {1 1 1 1}

  # --- CP11 FENCE: the CANVAS keeps its own Ctrl-C -------------------------
  ## CP2 asks for a chord that works from every widget INSIDE this window. The
  ## cheap way to get that is a binding on `all`, and `all` reaches the design
  ## canvas, where Ctrl-C is xschem's own copy-selected-objects. Sections B3,
  ## B4 and B5 of this file already fence the four bare digit keys the same
  ## way, for the same reason: the collateral is what a greedy binding costs,
  ## and it is green now precisely so that breaking it reds a row.
  cp_fixture
  cp_w .rdw.p.t tag add sel 1.0 {1.0 lineend}
  catch {update}
  cp_setclip {SENTINEL-CANVAS-KEEPS-ITS-CHORD}
  set CP11_HERE [cp_focus .drw]
  cp_ev $CP11_HERE <Control-Key-c>
  catch {update}
  set CP11_CLIP [cp_clip]
  check {CP11 FENCE a Ctrl-C on the design canvas is still the schematic's own copy and does not put the Results window's text on the clipboard - the cheap way to satisfy CP2 is a binding on `all`, and `all` reaches the canvas} \
    [list $CP11_HERE \
          [expr {$CP11_CLIP eq {SENTINEL-CANVAS-KEEPS-ITS-CHORD} ? 1 : 0}]] \
    [list .drw 1]

  # --- CP12 FENCE: a new dump must not leave the copy on the old text -------
  ## ⚠ THE INPUT MOST LIKELY TO BREAK THE FIX, AND NO ROW ABOVE SEES IT. The
  ## repair for CP3 has to REMEMBER the selection in namespace state, and a
  ## text INDEX never fails to resolve - Tk clamps it rather than refusing it -
  ## so a span left standing across a repaint goes on copying, silently and
  ## plausibly, whatever slid under those line numbers. That is issue 1324's
  ## shape (a mark left to drift while a variable still named the old row)
  ## pointed at the clipboard, and every other row in this section selects and
  ## copies inside ONE fixture, so not one of them would ever see it. Item R2
  ## made a second dump the ordinary thing and item R4 raises the window for
  ## it, so this is not an exotic path: it is Tuesday.
  ##
  ## ⚠ AND IT IS DRIVEN FROM THE POST-THEFT STATE, WHICH IS THE WHOLE POINT.
  ## MEASURED while writing this row: with `sel` still standing, the repaint's
  ## own `delete 1.0 end` empties the tag and Tk fires <<Selection>>, which any
  ## sane mirror already listens to - so a row that pushes over a LIVE
  ## selection passes with the sweep deleted and fences nothing (it did:
  ## ALL PASS 71 with rdw::_forget_selection commented out of render_pane).
  ## After a theft `sel` is ALREADY empty, the repaint changes nothing, no
  ## event fires, and the remembered span is the only thing left pointing into
  ## the old buffer. That is the reachable defect and it is CP3's own state.
  cp_fixture
  cp_w .rdw.p.t tag add sel 1.0 {1.0 lineend}
  catch {update}
  set CP12_WAS [cp_sel]
  catch {selection handle . cp_steal_handler}
  catch {selection own -selection PRIMARY .}
  catch {update}
  set CP12_LIVE [cp_highlighted 1.0 {1.0 lineend}]
  kx_ans ::rdw::push [cp_block]
  kx_ans ::rdw::render_pane
  catch {update}
  catch {selection clear -selection PRIMARY}
  catch {selection handle . {}}
  catch {set ::rdw::focus_pending 0}
  set CP12_HERE [cp_focus .rdw.p.t]
  cp_setclip {SENTINEL-STALE-SPAN}
  cp_ev $CP12_HERE <Control-Key-c>
  catch {update}
  check {CP12 FENCE a new dump does not leave the copy pointing at text that has moved: the span remembered so that CP3's theft cannot cost the user their selection is a pair of text INDICES into a buffer rdw::render_pane has just rewritten, and Tk resolves a stale index rather than refusing it - so after a dump the highlight must be gone and a Ctrl-C must leave the user's clipboard alone, not silently hand them whichever line now sits at those numbers} \
    [list [expr {$CP12_WAS ne {NOSEL} ? 1 : 0}] \
          [expr {$CP12_LIVE ne {} && $CP12_LIVE ne {ERR} ? 1 : 0}] \
          $CP12_HERE \
          [cp_highlighted 1.0 {1.0 lineend}] \
          [cp_clip] \
          [cp_sel]] \
    [list 1 1 .rdw.p.t {} {SENTINEL-STALE-SPAN} NOSEL]

  # --- CP13 A COPY OF NOTHING MUST NEVER TOUCH THE CLIPBOARD ---------------
  ## ⚠ ISSUE 1344 DEFECT a: THE HARM CP5 EXISTS TO PREVENT, ARRIVING THROUGH
  ## THE DOOR CP4 TESTS, ON A FIXTURE NEITHER OF THEM HAS. `Tools > Results
  ## Display Window` with no dumps, then right-click -> Select All -> Copy:
  ## three clicks, no simulation, the first thing a new user does.
  ##
  ## A Tk text widget always holds one mandatory trailing newline, so on an
  ## EMPTY pane `tag add sel 1.0 end` is the two-element range {1.0 2.0} over a
  ## character the user never put there. rdw::select_all's `llength $r < 2`
  ## guard therefore never fired on the one window it exists for, and
  ## rdw::copy's `$txt eq {}` could not fire either because that character is a
  ## newline. MEASURED before the fix, identically on :99 and on the user's
  ## VcXsrv: clipboard `MY-IMPORTANT-DOCUMENT-TEXT` -> a bare newline, with
  ## "Selected the whole window, 1 line." and then "Copied 2 lines, 1
  ## characters, to the clipboard." Three false sentences and a wiped clipboard.
  ##
  ## ⚠ WHY NO ROW ABOVE SEES IT. CP4 drives Select All only on a POPULATED
  ## fixture; CP5 drives the empty-selection guard only through the chord and
  ## only after `tag remove sel`, which leaves `sel` nothing to be wrong about.
  ## The empty WINDOW is a third state, and it is the one a user reaches first.
  ##
  ## ⚠ AND THE GUARD THAT MATTERS IS NOT "IS THE STRING EMPTY", SO PART 2 ASKS
  ## THE GENERAL QUESTION. `get first last` with first < last always yields at
  ## least one character, so `$txt eq {}` was dead for every span this window
  ## can make. The reachable class is a span holding nothing but BLANK SPACE -
  ## the empty window is one instance and a block's own trailing separator line
  ## is another, reachable with one drag on a populated pane.
  set ::rdw::blocks {}
  kx_ans ::rdw::set_row 0
  kx_ans ::rdw::close
  catch {destroy .rdw}
  kx_ans ::rdw::open
  catch {update idletasks}
  catch {set ::rdw::focus_pending 0}
  set CP13_CHARS [string length [cp_w .rdw.p.t get 1.0 end]]
  cp_setclip {SENTINEL-EMPTY-WINDOW}
  set CP13_M0 [cp_posted_menus]
  set CP13_BB [cp_w .rdw.p.t bbox 1.0]
  set CP13_X [expr {[llength $CP13_BB] == 4 ? [lindex $CP13_BB 0] + 2 : 10}]
  set CP13_Y [expr {[llength $CP13_BB] == 4 ? [lindex $CP13_BB 1] + 2 : 10}]
  cp_gap
  cp_ev .rdw.p.t <ButtonPress-3>   -x $CP13_X -y $CP13_Y
  cp_ev .rdw.p.t <ButtonRelease-3> -x $CP13_X -y $CP13_Y
  catch {update}
  set CP13_MENU {}
  foreach m [cp_posted_menus] {
    if {[lsearch -exact $CP13_M0 $m] < 0} { set CP13_MENU $m ; break }
  }
  set CP13_IALL  [expr {$CP13_MENU ne {} ? [cp_entry $CP13_MENU {*select*all*}] : -1}]
  set CP13_ICOPY [expr {$CP13_MENU ne {} ? [cp_entry $CP13_MENU {*copy*}] : -1}]
  if {$CP13_MENU ne {} && $CP13_IALL >= 0} {
    catch {$CP13_MENU invoke $CP13_IALL}
    catch {update}
  }
  set CP13_RNG [cp_selrng]
  set CP13_MSG1 [cp_status]
  catch {$CP13_MENU unpost}
  catch {grab release $CP13_MENU}
  catch {update}
  cp_gap
  cp_ev .rdw.p.t <ButtonPress-3>   -x $CP13_X -y $CP13_Y
  cp_ev .rdw.p.t <ButtonRelease-3> -x $CP13_X -y $CP13_Y
  catch {update}
  if {$CP13_MENU ne {} && $CP13_ICOPY >= 0} {
    catch {$CP13_MENU invoke $CP13_ICOPY}
    catch {update}
  }
  catch {$CP13_MENU unpost}
  catch {grab release $CP13_MENU}
  catch {update}
  set CP13_MSG2 [cp_status]
  set CP13_CLIP [cp_clip]
  ## PART 2: a populated pane, and a drag that covers a BLANK line only. The
  ## line is found at run time rather than hard-coded, so the row cannot go
  ## vacuous if the block's shape changes; leg 7 asserts one was found.
  cp_fixture
  set CP13_LAST [lindex [split [cp_w .rdw.p.t index {end - 1c}] .] 0]
  set CP13_BLANK 0
  if {[string is integer -strict $CP13_LAST]} {
    for {set _i 1} {$_i <= $CP13_LAST} {incr _i} {
      set _t [cp_w .rdw.p.t get $_i.0 "$_i.0 lineend"]
      if {![string match {ERR:*} $_t] && [string trim $_t] eq {}} {
        set CP13_BLANK $_i
        break
      }
    }
  }
  set CP13_BTXT {}
  if {$CP13_BLANK > 0} {
    cp_w .rdw.p.t tag add sel $CP13_BLANK.0 [expr {$CP13_BLANK + 1}].0
    catch {update}
    set CP13_BTXT [cp_sel]
  }
  cp_setclip {SENTINEL-BLANK-SPAN}
  set CP13_HERE [cp_focus .rdw.p.t]
  cp_ev $CP13_HERE <Control-Key-c>
  catch {update}
  set CP13_BCLIP [cp_clip]
  set CP13_BMSG [cp_status]
  check {CP13 A COPY OF NOTHING MUST NEVER TOUCH THE CLIPBOARD: in a Results Display Window that has never been given a dump - three clicks from the Tools menu, no simulation - the right-click Select All must select nothing and say so, and its Copy must leave the user's clipboard exactly as it was; and on a populated pane a drag covering nothing but a blank line is the same non-copy. A Tk text widget's mandatory trailing newline makes `tag add sel 1.0 end` a real range on an EMPTY pane, so both guards were dead and the user's document text was replaced by a newline} \
    [list $CP13_CHARS \
          [expr {$CP13_MENU ne {} && $CP13_IALL >= 0 && $CP13_ICOPY >= 0 ? 1 : 0}] \
          $CP13_RNG \
          $CP13_CLIP \
          [string match {Copied *} $CP13_MSG2] \
          [expr {[kx_oneline $CP13_MSG1] && [kx_oneline $CP13_MSG2] ? 1 : 0}] \
          [expr {$CP13_BLANK > 0 ? 1 : 0}] \
          [expr {[string length $CP13_BTXT] > 0 && [string trim $CP13_BTXT] eq {} ? 1 : 0}] \
          $CP13_BCLIP \
          [string match {Copied *} $CP13_BMSG]] \
    [list 1 1 {} {SENTINEL-EMPTY-WINDOW} 0 1 1 1 {SENTINEL-BLANK-SPAN} 0]

  # --- CP14 THE SELECTION IN THIS WINDOW'S OWN STATUS LINE ------------------
  ## ⚠ ISSUE 1344 DEFECTS b AND c. `.rdw.s.msg` is a disabled `text` with
  ## -exportselection 1 and a real drag selects in it (issue 1362 changed the
  ## class from a readonly `entry` so a long verdict could wrap instead of
  ## being amputated; tk::TextButton1 declines the keyboard on a non-normal
  ## state exactly as tk::EntryButton1 did, so issue 1308 is untouched) -
  ## driven below with ButtonPress / B1-Motion / ButtonRelease, not with a
  ## hand-added `sel` tag - and
  ## it is where item B5 writes the settings-file path, the single most
  ## copy-worthy string in the window. Ruling DD-5 gave this window a copy that
  ## works from anywhere in it; "anywhere in it" has to include that widget.
  ##
  ## b: selecting there takes PRIMARY off the pane, and
  ## rdw::_selection_changed used to test only `$own eq {.rdw.p.t}` - so a
  ## LOCAL widget of this same toplevel was scored a FOREIGN theft, the stale
  ## mirror was kept, and the chord (which is on the `.rdw` bindtag that entry
  ## carries) copied the PANE. MEASURED before the fix on :99 and on the user's
  ## VcXsrv, byte-identical: PRIMARY `/home/analog/.xschem/op_param_lists.tcl`,
  ## clipboard `MCU:/`, status "Copied 1 line, 5 characters, to the clipboard."
  ##
  ## c: and the same chord DESTROYED the text being copied. rdw::copy's
  ## no-selection branch calls rdw::status, which writes ::rdw::statusmsg - the
  ## -textvariable of the very entry holding the live selection - so the path
  ## vanished under the user's own selection while the sentence claimed nothing
  ## was selected, which was false.
  ##
  ## ⚠ AND THE LAST TWO LEGS ARE THE FENCE ROUND THE FIX. A copy that prefers a
  ## sibling widget unconditionally would break the ordinary gesture this whole
  ## section is about, so the row puts the entry's selection down, selects in
  ## the PANE again and requires the same chord to copy the pane.
  cp_fixture
  cp_w .rdw.p.t tag add sel 1.0 {1.0 lineend}
  catch {update}
  set CP14_PANELINE [cp_sel]
  kx_ans ::rdw::status {/home/analog/.xschem/op_param_lists.tcl}
  catch {update}
  set CP14_WANT [cp_status]
  catch {update idletasks}
  set CP14_EW [cp_w winfo width .rdw.s.msg]
  set CP14_EH [cp_w winfo height .rdw.s.msg]
  set CP14_EY [expr {[string is integer -strict $CP14_EH] ? $CP14_EH / 2 : 8}]
  cp_gap
  cp_ev .rdw.s.msg <ButtonPress-1> -x 3 -y $CP14_EY
  if {[string is integer -strict $CP14_EW]} {
    for {set _x 3} {$_x < $CP14_EW - 4} {incr _x 10} {
      cp_ev .rdw.s.msg <B1-Motion> -x $_x -y $CP14_EY
    }
    cp_ev .rdw.s.msg <B1-Motion>       -x [expr {$CP14_EW - 5}] -y $CP14_EY
    cp_ev .rdw.s.msg <ButtonRelease-1> -x [expr {$CP14_EW - 5}] -y $CP14_EY
  }
  catch {update}
  set CP14_PRESENT [cp_smsg_present]
  set CP14_PRIM NOPRIM
  catch {set CP14_PRIM [selection get -selection PRIMARY]}
  set CP14_MIRROR $::rdw::selspan
  cp_setclip {SENTINEL-STATUS-LINE}
  set CP14_HERE [cp_focus .rdw.p.t]
  cp_ev $CP14_HERE <Control-Key-c>
  catch {update}
  set CP14_CLIP [cp_clip]
  set CP14_AFTER [cp_status]
  set CP14_STILL [cp_smsg_present]
  cp_smsg_clear
  catch {update}
  cp_w .rdw.p.t tag add sel 2.0 {2.0 lineend}
  catch {update}
  set CP14_L2 [cp_sel]
  cp_setclip {SENTINEL-BACK-TO-THE-PANE}
  set CP14_HERE2 [cp_focus .rdw.p.t]
  cp_ev $CP14_HERE2 <Control-Key-c>
  catch {update}
  set CP14_CLIP2 [cp_clip]
  check {CP14 A SELECTION IN ANY WIDGET OF THIS WINDOW IS THE USER'S SELECTION: after a real drag across the settings-file path in the status line, Ctrl-C must put THAT PATH on the clipboard and not the pane's first line, must leave the path standing in the status line rather than overwriting it with a receipt for itself, and must leave the selection alive so a second copy works - and a selection made in the pane afterwards must still be what the same chord copies} \
    [list $CP14_PRESENT \
          [expr {$CP14_PRIM eq $CP14_WANT && $CP14_WANT ne {} ? 1 : 0}] \
          [llength $CP14_MIRROR] \
          [expr {$CP14_CLIP eq $CP14_WANT ? 1 : 0}] \
          [expr {$CP14_CLIP eq $CP14_PANELINE ? 1 : 0}] \
          [expr {$CP14_AFTER eq $CP14_WANT ? 1 : 0}] \
          $CP14_STILL \
          [expr {$CP14_L2 ne {NOSEL} && $CP14_CLIP2 eq $CP14_L2 ? 1 : 0}]] \
    [list 1 1 0 1 0 1 1 1]

  # --- CP15 THE TWO SENTENCES MUST AGREE ABOUT ONE AND THE SAME CONTENT -----
  ## ⚠ ISSUE 1344 DEFECT d. rdw::select_all counted the LINE NUMBER of
  ## `end - 1c` and rdw::copy counted the elements of `split $txt \n`, so for
  ## one and the same Select All the window said "Selected the whole window, 7
  ## lines." and then "Copied 8 lines, 170 characters, to the clipboard." Both
  ## numbers were wrong, they were wrong by different amounts, and the extra
  ## line in the copy was the widget's own mandatory trailing newline riding
  ## along on to the clipboard.
  ##
  ## The third leg is what makes this more than an equality: the number both
  ## sentences give must be the number of lines the paste really occupies,
  ## counted here from the clipboard's own bytes.
  cp_fixture
  kx_ans ::rdw::select_all
  catch {update}
  set CP15_SA [cp_status]
  set CP15_RNG [cp_selrng]
  cp_setclip {SENTINEL-COUNTS}
  kx_ans ::rdw::copy
  catch {update}
  set CP15_CP [cp_status]
  set CP15_CLIP [cp_clip]
  set CP15_N1 -1
  set CP15_N2 -1
  regexp {whole window, ([0-9]+) lines?\.} $CP15_SA -> CP15_N1
  regexp {^Copied ([0-9]+) lines?,} $CP15_CP -> CP15_N2
  ## The paste's own shape: a trailing newline ENDS the last line, it does not
  ## start an empty new one. Counted from the bytes, not from rdw::_copy_lines.
  set CP15_REAL [expr {[regexp -all "\n" $CP15_CLIP] \
                       + ([string index $CP15_CLIP end] eq "\n" ? 0 : 1)}]
  set CP15_PANE [cp_w .rdw.p.t get 1.0 {end - 1c}]
  check {CP15 THE WINDOW MUST NOT CONTRADICT ITSELF ABOUT WHAT IT JUST DID: Select All and the Copy that follows it describe ONE piece of content, so they must give the SAME number of lines, that number must be the number of lines the paste really occupies, and what reaches the clipboard must be the pane's own text and not the pane's text plus the Tk text widget's mandatory trailing newline} \
    [list [expr {$CP15_N1 >= 0 && $CP15_N2 >= 0 ? 1 : 0}] \
          [expr {$CP15_N1 == $CP15_N2 ? 1 : 0}] \
          [expr {$CP15_N1 == $CP15_REAL ? 1 : 0}] \
          [expr {$CP15_CLIP eq $CP15_PANE && $CP15_PANE ne {} ? 1 : 0}] \
          [cp_cmp [lindex $CP15_RNG 1] == {end - 1c}]] \
    [list 1 1 1 1 1]

  # --- CP16 A REWRITTEN STATUS LINE PUTS DOWN THE SELECTION IT INVALIDATES --
  ## ⚠ ISSUE 1351, found by issue 1344's own adversary, in TWO presses of the
  ## chord item R3 added. An entry's selection is a pair of INDICES, not a hold
  ## on the characters. `rdw::status` replaces `::rdw::statusmsg`, which was
  ## the -textvariable of `.rdw.s.msg`, and the range used to survive that
  ## rewrite verbatim - so it came to cover a slice of the NEW sentence, text
  ## the user had never selected.
  ##
  ## ⚠ AND THE ROW SURVIVES ISSUE 1362'S WIDGET SWAP ON PURPOSE. A `sel` tag
  ## dies with the repaint, so the stale-range half is now structurally
  ## impossible - but only because the repaint happens, and `rdw::status`
  ## repaints only when the text really changed. The LAST leg is what holds
  ## that: a line rewritten to the string it already held keeps the user's
  ## selection. Delete the change guard and this row is the one that says so.
  ##
  ## MEASURED before the fix: the line reads `alpha    beta`; the user selects
  ## the four spaces (a double-click on the gap does exactly this); Ctrl-C is
  ## refused, because a whitespace-only span is not worth copying - and the
  ## refusal is deliberately NOT routed through rdw::_copy_report, so it
  ## REPLACES the line. Range 5-9 now covers ` is ` of the refusal sentence,
  ## and a SECOND Ctrl-C copies ` is ` to the clipboard SILENTLY, because the
  ## source is still that entry and _copy_report says nothing for it. That is
  ## item R3's own quoted defect class -- "silently handed you the wrong text".
  ##
  ## ⚠ THE LAST LEG IS THE FENCE. Clearing on EVERY call would drop a live
  ## selection for nothing; a status line reset to what it already says has
  ## invalidated no index, so the selection must survive that.
  cp_fixture
  kx_ans ::rdw::status {alpha    beta}
  catch {update}
  set CP16_LINE0 [cp_status]
  cp_smsg_range 5 9
  catch {update}
  set CP16_PRESENT0 [cp_smsg_present]
  set CP16_SEL0 NOSEL
  catch {set CP16_SEL0 [selection get -selection PRIMARY]}
  cp_setclip {SENTINEL-CP16}
  set CP16_HERE [cp_focus .rdw.p.t]
  cp_ev $CP16_HERE <Control-Key-c>
  catch {update}
  set CP16_CLIP1 [cp_clip]
  set CP16_LINE1 [cp_status]
  set CP16_PRESENT1 [cp_smsg_present]
  cp_ev $CP16_HERE <Control-Key-c>
  catch {update}
  set CP16_CLIP2 [cp_clip]
  ## AND THE FENCE: the same text again must NOT put a live selection down.
  kx_ans ::rdw::status {alpha    beta}
  catch {update}
  cp_smsg_range 0 5
  catch {update}
  kx_ans ::rdw::status {alpha    beta}
  catch {update}
  set CP16_KEPT [cp_smsg_present]
  cp_smsg_clear
  check {CP16 A REWRITTEN STATUS LINE MUST NOT LEAVE A SELECTION STANDING OVER TEXT THE USER NEVER CHOSE: a refused copy replaces that line, so the indices the user's selection was made of no longer mean what they meant - they must be put down, or the very next press of the same chord silently copies a slice of the refusal sentence. And a line rewritten to the string it already held has invalidated nothing, so a selection standing in it survives} \
    [list [expr {$CP16_LINE0 eq {alpha    beta} ? 1 : 0}] \
          $CP16_PRESENT0 \
          [expr {$CP16_SEL0 eq {    } ? 1 : 0}] \
          [expr {$CP16_CLIP1 eq {SENTINEL-CP16} ? 1 : 0}] \
          [expr {$CP16_LINE1 ne $CP16_LINE0 ? 1 : 0}] \
          $CP16_PRESENT1 \
          [expr {$CP16_CLIP2 eq {SENTINEL-CP16} ? 1 : 0}] \
          $CP16_KEPT] \
    [list 1 1 1 1 1 0 1 1]

  # --- CP9  HYGIENE ---------------------------------------------------------
  catch {selection clear -selection PRIMARY}
  catch {selection handle . {}}
  foreach m [cp_posted_menus] { catch {$m unpost} ; catch {grab release $m} }
  catch {update}
  set CP9_GRAB [cp_w grab current]
  set CP9_POSTED [cp_posted_menus]
  cp_setclip {}
  set ::rdw::blocks {}
  kx_ans ::rdw::set_row 0
  kx_ans ::rdw::set_list annotation
  kx_ans ::rdw::status {}
  kx_ans ::rdw::close
  catch {destroy .rdw}
  catch {set ::rdw::focus_pending 0}
  xschem unselect_all
  cp_focus .drw
  catch {update}
  check {CP9 HYGIENE section CP leaves nothing behind: no posted menu, no grab, no window, no stored dumps, no cursored row, the hand-back one-shot spent, the keyboard back on the canvas and no untitled* anywhere} \
    [list [expr {$CP9_GRAB eq {} || $CP9_GRAB eq {ERR:} ? 1 : 0}] \
          [llength $CP9_POSTED] \
          [expr {[winfo exists .rdw] ? 1 : 0}] \
          [llength $::rdw::blocks] \
          [kx_ans ::rdw::_target_line] \
          [kx_pending] \
          [focus] \
          [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S1_ROOT0 ? 1 : 0}] \
          [llength [glob -nocomplain -directory $scratch -tails untitled*]]] \
    [list 1 0 0 0 0 0 .drw 1 0]
}



# ============================================================================
# SECTION KN — ISSUE 1300, END TO END THROUGH THE REAL KEYBINDINGS
# ============================================================================
# The user's first complaint is about a KEY, so it is answered with a key.
# Section NW of test_rdw_window_1245.tcl fences every decision as a pure
# function on both arms; these two rows are the ones that could not be written
# there, because they need the cadence bind, a real canvas, a real selection
# and the live list identity that `rdw::key` moves.
#
# The fixture's class `b4dev` declares {zid zgm}, and the raw carries both for
# M1.  The ANNOTATION list is owned here with `zid` alone, so the run really
# does publish a column the list does not declare -- which is the shape the
# user met (six declared, eighty-eight published) with the numbers made small
# enough to gold.  The SUMMARY list is left unowned so it answers the PDK seed
# and differs from the annotation list, which is what makes KN2 a measurement
# of issue 1300's headline and not of a store write.
#
# RED BEFORE THE FIX: both.  MEASURED on the unmodified tree at 79b0a0ce, key 1
# and key 3 produced byte-identical text and key 1's block carried `zgm`.

xschem load $KX_SCH
xschem zoom_full ; update idletasks
kx_annot
kx_ans ::op_param_lists::set_list class b4dev annotation {{zid zid 0}}
kx_ans ::rdw::pick_end
kx_reset
xschem unselect_all
xschem select instance M1
update idletasks

proc kn_text {} {
  if {![llength $::rdw::blocks]} { return NO-BLOCK }
  return [kx_ans ::rdw::block_text [lindex $::rdw::blocks 0]]
}
proc kn_press {k} {
  focus -force .drw ; update idletasks
  event generate .drw <Key-$k> -when now
  update
  return [kn_text]
}

set KN_T1 [kn_press 1]
set KN_T3 [kn_press 3]
set KN_T2 [kn_press 2]

check {KN1 THE USER'S OWN GESTURE, ANSWERED: a bare 1 over a selected device prints the class's annotation list - the row it declares and NOT the row this run also published - and says which list withheld what, while a bare 3 still prints everything the run published with no narrowing sentence at all} \
  [list [kx_has $KN_T1 { zid }] \
        [kx_has $KN_T1 { zgm }] \
        [kx_has $KN_T1 {Narrowed to the b4dev annotation list at this dump: 1 of 2 columns.}] \
        [kx_has $KN_T3 { zid }] \
        [kx_has $KN_T3 { zgm }] \
        [kx_has $KN_T3 {Narrowed to the}] \
        [kx_listkind]] \
  {1 0 1 1 1 0 summary}

check {KN2 ISSUE 1300's HEADLINE MEASUREMENT, INVERTED: on the user's own tree keys 1, 2 and 3 rendered BYTE-IDENTICAL blocks for one device - here the three are pairwise different, key 2 answers the unowned summary list's PDK seed and says so in its own words, and every one of the three blocks still names the same device} \
  [list [expr {$KN_T1 eq $KN_T2 ? 1 : 0}] \
        [expr {$KN_T1 eq $KN_T3 ? 1 : 0}] \
        [expr {$KN_T2 eq $KN_T3 ? 1 : 0}] \
        [kx_has $KN_T2 {Narrowed to the b4dev summary list at this dump: 2 of 2 columns.}] \
        [kx_has $KN_T1 {M1:/}] [kx_has $KN_T2 {M1:/}] [kx_has $KN_T3 {M1:/}] \
        [kx_nblocks]] \
  {0 0 0 1 1 1 1 3}

# ============================================================================
# SECTION LK — ISSUE 1355, END TO END THROUGH THE REAL KEYS AND THE REAL MODAL
# ============================================================================
# The user's second complaint is about a KEY and a POP-UP, so both are driven
# as such.  Section LX of test_rdw_window_1245.tcl fences every decision as a
# pure function on both arms; these two rows are the ones that could not be
# written there, because they need the cadence bind, a real canvas, a real
# selection and a real modal with a real grab.
#
# RED BEFORE THE FIX: both.  `.rdw.hdr` does not exist, the title is the bare
# `Results Display Window` whatever key was pressed, and the dialog a real
# Delete raises on the summary list carries no `.rdw.scope.q2` at all.

if {[kx_ans ::rdw::have_tk] eq {1}} {
  xschem unselect_all
  xschem select instance M1
  update idletasks
  proc lk_hdr {} {
    if {![winfo exists .rdw.hdr]} { return NO-WIDGET }
    if {[catch {.rdw.hdr cget -text} t]} { return "ERR:$t" }
    return $t
  }
  proc lk_title {} {
    if {![winfo exists .rdw]} { return NO-WINDOW }
    if {[catch {wm title .rdw} t]} { return "ERR:$t" }
    return $t
  }
  proc lk_press {k} {
    focus -force .drw ; update idletasks
    event generate .drw <Key-$k> -when now
    update
    return [list [kx_listkind] [lk_hdr] [lk_title]]
  }
  set LK1_A [lk_press 1]
  set LK1_S [lk_press 2]
  set LK1_W [lk_press 3]
  check {LK1 THE USER'S SECOND COMPLAINT, ANSWERED BY THE KEY THAT CAUSED IT: a bare 1, 2 or 3 on the canvas moves the window's own chrome line AND its title along with the identity, so "the RDW doesn't say summary view" is answered on two surfaces without the user having to read the button greying} \
    [list $LK1_A $LK1_S $LK1_W] \
    [list [list annotation [kx_ans ::rdw::_chrome_line annotation] [kx_ans ::rdw::_title annotation]] \
          [list summary    [kx_ans ::rdw::_chrome_line summary]    [kx_ans ::rdw::_title summary]] \
          [list all        [kx_ans ::rdw::_chrome_line all]        [kx_ans ::rdw::_title all]]]

  ## THE REAL MODAL.  A real `.rdw.b.delete` invoke on the SUMMARY list, read
  ## while the dialog is up and its grab is the dialog's own, then cancelled -
  ## the sd_arm machinery section SD already uses, for the reason it records:
  ## a fixed timer is a coin toss under display contention and a dialog nobody
  ## clicks hangs the suite (issue 0803).
  event generate .drw <Key-2> -when now ; update
  set LK2_ROW 0
  set LK2_N 0
  foreach _b $::rdw::blocks {
    foreach _e $_b {
      incr LK2_N
      if {$LK2_ROW == 0 && [kx_ans ::rdw::_row_param $_e] ne {}} { set LK2_ROW $LK2_N }
    }
  }
  kx_ans ::rdw::set_row $LK2_ROW
  set ::LK2_Q2 NOT-RUN
  set ::LK2_TITLE NOT-RUN
  sd_arm {
    set ::LK2_Q2 [expr {[winfo exists .rdw.scope.q2] ? [.rdw.scope.q2 cget -text] : {ABSENT}}]
    set ::LK2_TITLE [wm title .rdw.scope]
    rdw::scope_dialog_done .rdw.scope cancel
  }
  .rdw.b.delete invoke
  sd_disarm
  catch {destroy .rdw.scope}
  update idletasks
  check {LK2 THE USER'S OWN POP-UP, ANSWERED: the dialog a real Delete raises while the SUMMARY list is in force now says which list it is about, in the slot list 3 already used for its question - "it doesn't say summary list, which would be good for the user to know", driven through the real button, the real modal and the real grab} \
    [list $::SD_RAN $::LK2_Q2 $::LK2_TITLE [kx_listkind] \
          [expr {[winfo exists .rdw.scope] ? 1 : 0}] [grab current]] \
    [list 1 [kx_ans ::rdw::_scope_statement delete summary] {Which devices?} summary 0 {}]
  kx_ans ::rdw::set_list summary

  ## LK3 — THE PREFIX NAMES A KEYBOARD, SO THE KEYBOARD IS WHAT IS ASKED.
  ##
  ## The chrome line opened "Keys 1/2/3:" on every open of this window, and
  ## src/xschem.tcl adds the Tools entry that opens it UNCONDITIONALLY while
  ## the four digit binds live in src/cadence_style_rc alone (ruling D-2).
  ## MEASURED with no cadence rc sourced: `bind .drw <Key-1>` is the empty
  ## string, real Key-1/2/3 events on the canvas leave `::rdw::listkind` where
  ## it stood, and the label named them anyway.  This row is the other end of
  ## test_rdw_window_1245.tcl's LX14: that one drives the pure text builder at
  ## both values, this one takes the value off the REAL binds of the REAL
  ## canvas and puts the binds back.
  ## ⚠ AND IT TAKES BOTH KEYBOARDS, NOT ONE (issue 1367).  This row used to
  ## strip the CANVAS's three binds and require the answer to fall to 0.  That
  ## was right until issue 1358 bound the same digits on `.rdw` itself so the
  ## window could hear its own refresh keys: after that, stripping the canvas
  ## leaves the keys genuinely WORKING with the keyboard inside the window, and
  ## a row demanding 0 there was demanding the sentence lie in the other
  ## direction.  So the middle arm now strips the canvas ALONE and requires the
  ## answer to STAY 1 -- the honest reading -- and a third arm strips both and
  ## requires 0.  The two binds are spelled differently (`rdw::key` on the
  ## canvas, `rdw::_digit` on the window) and `rdw::_digit`'s only act is to
  ## call `rdw::key`, so the name test has to know both spellings.
  set LK3_B {}
  foreach _k {1 2 3} { lappend LK3_B [bind .drw <Key-$_k>] }
  set LK3_W {}
  foreach _k {1 2 3} { lappend LK3_W [bind .rdw <Key-$_k>] }
  set LK3_ON [list [kx_ans ::rdw::_keys_bound] \
                   [string match {Keys 1/2/3:*} [lk_hdr]]]
  foreach _k {1 2 3} { bind .drw <Key-$_k> {} }
  kx_ans ::rdw::apply_list_state ; update idletasks
  set LK3_CANVASGONE [list [kx_ans ::rdw::_keys_bound] \
                           [string match {Keys 1/2/3:*} [lk_hdr]]]
  foreach _k {1 2 3} { bind .rdw <Key-$_k> {} }
  kx_ans ::rdw::apply_list_state ; update idletasks
  set LK3_OFF [list [kx_ans ::rdw::_keys_bound] \
                    [string match {Keys 1/2/3:*} [lk_hdr]] \
                    [string match {Showing *} [lk_hdr]]]
  foreach _k {1 2 3} { bind .drw <Key-$_k> [lindex $LK3_B [expr {$_k - 1}]] }
  foreach _k {1 2 3} { bind .rdw <Key-$_k> [lindex $LK3_W [expr {$_k - 1}]] }
  kx_ans ::rdw::apply_list_state ; update idletasks
  set LK3_BACK [list [kx_ans ::rdw::_keys_bound] \
                     [expr {[bind .drw <Key-1>] eq [lindex $LK3_B 0] ? 1 : 0}] \
                     [expr {[bind .rdw <Key-1>] eq [lindex $LK3_W 0] ? 1 : 0}] \
                     [expr {[bind .drw <Key-3>] eq [lindex $LK3_B 2] ? 1 : 0}] \
                     [lk_hdr]]
  check {LK3 THE CHROME NAMES THE 1/2/3 KEYS ONLY WHEN THE 1/2/3 KEYS ARE REALLY BOUND, taken off the real widgets rather than assumed: the prefix is there under the cadence profile, it SURVIVES the canvas binds being stripped because issue 1358 put the same digits on the window itself and they still work there, it goes only when BOTH keyboards are gone, and putting both back puts the prefix back - so the one sentence in this window that promises the user a keyboard cannot outlive the keyboard, and cannot deny one that is live either} \
    [list $LK3_ON $LK3_CANVASGONE $LK3_OFF $LK3_BACK] \
    [list {1 1} {1 1} {0 0 1} \
          [list 1 1 1 1 [kx_ans ::rdw::_chrome_line [kx_listkind]]]]
}


# ============================================================================
# SECTION KD — ISSUE 1358: THE USER'S OWN THIRD SYMPTOM, DRIVEN WITH THE
# KEYBOARD WHERE THEIR CLICK LEAVES IT
# ============================================================================
# THEIR WORDS: "The delete did not have an effect (I left settings on the
# pop-up at default). Then, I tried deleting one at a time. That also did not
# have an effect next time I printed summary."
#
# ⚠ AND EVERY EARLIER ROW IN THIS BATCH THAT CLAIMED THE SYMPTOM WAS DEAD
# BOUGHT IT WITH A `focus -force .drw` IMMEDIATELY BEFORE THE KEY PRESS -- the
# one step the user's hand does not make.  `kn_press` and `lk_press` twenty
# lines above both do it, correctly, because their subject is the CANVAS
# binding.  This row's subject is the OTHER end: the keyboard is wherever the
# user's last click left it, and the user MUST click a parameter row, because
# the window's own status line tells them to ("click a parameter row, which
# shades to show it is the target, then press Delete again").
#
# So KD1 presses the digit at `[focus]` and asserts, as a LEG, that `[focus]`
# really is `.rdw.p.t` -- without that leg the row would be the same
# self-granted focus wearing a different name.
#
# RED BEFORE THE FIX, MEASURED: the store moves (`effective b4dev summary`
# {zid zgm} -> {zgm}) and the status line says so, and then the digit reaches
# nothing at all -- nblocks stays 1, the pane is byte-identical, the newest
# block still carries the row the store no longer has.
#
# KD2 IS THE FENCE ON THE FIX'S OWN RISK.  This window exists so a block can be
# selected and pasted into a design review (ruling DD-5), so a keyboard fix
# that ate the copy chord, dropped the pane's selection or answered a chord
# would be worse than the bug.
#
# ⚠ AND KD2 IS GREEN ON THE UNFIXED SOURCE, SAID OUT LOUD RATHER THAN LEFT TO
# BE FOUND.  It is a FENCE, not a red: before the fix there are no digit
# bindings to break the copy with, so it can only be non-vacuous against the
# FIXED code.  It is, measured: with `rdw::_digit` made to clear the pane's
# `sel` tag before it decides -- a digit that drops the user's selection, which
# is exactly the harm this row exists to forbid -- the keys suite reds 1
# FAILED, KD2 EXACTLY, and test_rdw_window_1245 stays ALL PASS (182).
#
# ⚠ KD1 REDS ON `:0` AND IT IS THE ENVIRONMENT, NOT THE ROW -- MEASURED BOTH
# WAYS SO NOBODY HAS TO RE-DERIVE IT.  On WSLg's Xwayland (`:0`) this suite's
# whole keyboard half is dead: `[focus]` answers the EMPTY STRING, so real key
# events reach no binding at all.  PRE-FIX, HEAD sources, `DISPLAY=:0`:
# 16 FAILED (69 passed), red = F1 F3 C2 B2 B3 B4 B5 V2 D1 CU7 RA1..RA6 -- note
# B2, whose whole subject is a real bare digit on the canvas, answering
# `{annotation {} {} {}}`.  POST-FIX, same display: 16 FAILED (71 passed),
# the SAME fifteen rows plus KD1, whose `$KD1_FOCUS` and `$KD1_WHERE` legs both
# read `{}`.  The window suite is ALL PASS (182) on `:0` in both states.  KD1
# refusing to pass where there is no keyboard is the leg doing its job; a row
# that passed there would be measuring nothing.  Everything else in this
# section was taken on `:99` (Xvfb 1920x1080x24, openbox 3.6.1 live) with
# `pgrep -f 'xschem|run_regression'` checked clean first.
#
# KD1's OWN SABOTAGE IS THE REJECTED ALTERNATIVE ITSELF.  Adding
# `rdw::_focus_canvas` to the end of `rdw::button`'s successful-edit arm -- the
# other candidate fix, handing the keyboard back to the canvas after a press --
# reds 1 FAILED, KD1 EXACTLY (its `$KD1_WHERE` leg), with the window suite ALL
# PASS (182).  That leg is deliberate: this window is entitled to keep the
# keyboard the user's click gave it (issue 1306, ruling DD-5), and a future
# pass that decides otherwise has to re-take that decision in the open.

if {[kx_ans ::rdw::have_tk] eq {1}} {
  proc kd_focus {w} {
    for {set i 0} {$i < 60} {incr i} {
      catch {focus -force $w} ; catch {update}
      if {[focus] eq $w} { return $w }
      after 10
    }
    return [focus]
  }
  proc kd_newest {} {
    if {![llength $::rdw::blocks]} { return NO-BLOCK }
    return [kx_ans ::rdw::block_text [lindex $::rdw::blocks 0]]
  }
  proc kd_nth {n} {
    if {[llength $::rdw::blocks] <= $n} { return NO-BLOCK }
    return [kx_ans ::rdw::block_text [lindex $::rdw::blocks $n]]
  }
  ## The first parameter row in the pane, and a real click on it.
  proc kd_click_first_param {} {
    set n 0
    foreach L [split [.rdw.p.t get 1.0 end-1c] \n] {
      incr n
      if {[regexp {^\s+\S+\s+:\s} $L]} {
        lassign [.rdw.p.t bbox $n.0] bx by bw bh
        if {$bx eq {}} { return 0 }
        event generate .rdw.p.t <Button-1> -x [expr {$bx + 2}] -y [expr {$by + 2}] -when now
        event generate .rdw.p.t <ButtonRelease-1> -x [expr {$bx + 2}] -y [expr {$by + 2}] -when now
        update
        return $n
      }
    }
    return 0
  }

  kx_ans ::op_param_lists::set_list class b4dev summary {{zid zid 0} {zgm zgm 1}}
  kx_ans ::rdw::set_list summary
  kx_reset
  xschem unselect_all
  xschem select instance M1
  update idletasks

  ## 1. THE USER PRESSES 2 ON THE CANVAS.  This `focus -force` is the START
  ## state, not the cheat: the user really is on the canvas when they press it.
  kd_focus .drw
  event generate .drw <Key-2> -when now
  update
  set KD1_NB_A [kx_nblocks]

  ## 2. THEY CLICK THE ROW THE STATUS LINE TOLD THEM TO CLICK.
  set KD1_ROW [kd_click_first_param]
  set KD1_FOCUS [focus]

  ## 3. THEY PRESS DELETE AND ACCEPT THE DEFAULTS.
  set KD1_EFF0 [kx_ans ::op_param_lists::effective b4dev summary]
  sd_arm { rdw::scope_dialog_done .rdw.scope ok }
  .rdw.b.delete invoke
  sd_disarm
  catch {destroy .rdw.scope}
  update idletasks
  set KD1_EFF1 [kx_ans ::op_param_lists::effective b4dev summary]
  set KD1_WHERE [focus]
  set KD1_NB_B [kx_nblocks]
  set KD1_SHOWN [kd_newest]

  ## 4. THEY PRESS 2 AGAIN TO LOOK -- WHEREVER THE KEYBOARD IS.
  event generate [focus] <Key-2> -when now
  update
  set KD1_NB_C [kx_nblocks]
  set KD1_NEW [kd_newest]

  ## ⚠ TWO LEGS HERE REVERSED WITH THE USER'S RULING (item: blocks follow a
  ## list edit).  They used to gold the FROZEN RECORD: the block already in the
  ## pane kept `zid` after `zid` was deleted, because `_reslot_block` is a
  ## strict permutation and could re-order rows but never drop one.  The user's
  ## report was "Delete is not affecting the current display.  Only future
  ## items sent to the RDW are conforming to the new list", and the ruling was
  ## REBUILD THEM -- so a block whose device belongs to the edited class is
  ## re-dumped from the loaded raw, and BOTH the block on screen at the moment
  ## of the press (leg 7) and the older one still in the store (leg 12) now
  ## lose the row.  The cost was stated and accepted: a block stops being a
  ## frozen record of the run and an older dump changes under its reader.
  ## The row's own subject -- the keyboard is on the pane and stays there -- is
  ## untouched, and legs 9..11 still prove the press produced a NEW dump.
  check {KD1 THE USER'S THIRD SYMPTOM, DRIVEN WITHOUT GRANTING THE FOCUS THE SHIPPED CODE NEVER GRANTS: press 2 on the canvas, click the parameter row the status line tells you to click - which parks the keyboard on the pane, asserted as a leg - press Delete and accept the defaults, then press 2 again where your hands are, and the window shows the store you just changed instead of the row you just deleted - and by the user's ruling the block ALREADY in the pane lost the deleted row the moment Delete succeeded, without waiting for that second press} \
    [list $KD1_NB_A [expr {$KD1_ROW > 0 ? 1 : 0}] $KD1_FOCUS \
          $KD1_EFF0 $KD1_EFF1 $KD1_WHERE \
          [kx_has $KD1_SHOWN { zid }] [kx_has $KD1_SHOWN { zgm }] $KD1_NB_B \
          $KD1_NB_C [kx_has $KD1_NEW { zgm }] [kx_has $KD1_NEW { zid }] \
          [kx_has [kd_nth 1] { zid }] [kx_has [kd_nth 1] { zgm }]] \
    [list 1 1 .rdw.p.t {{zid zid 0} {zgm zgm 1}} {{zgm zgm 1}} .rdw.p.t \
          0 1 1 2 1 0 0 1]

  ## KD2 -- THE COPY MUST SURVIVE THE NEW KEYBOARD.
  set KD2_L0 [.rdw.p.t bbox 4.0]
  set KD2_L1 [.rdw.p.t bbox 6.0]
  if {[llength $KD2_L0] == 4 && [llength $KD2_L1] == 4} {
    event generate .rdw.p.t <Button-1> -x [expr {[lindex $KD2_L0 0] + 1}] \
      -y [expr {[lindex $KD2_L0 1] + 1}] -when now
    update
    for {set i 1} {$i <= 6} {incr i} {
      event generate .rdw.p.t <B1-Motion> -state 256 \
        -x [expr {[lindex $KD2_L0 0] + 1}] \
        -y [expr {int([lindex $KD2_L0 1] + ([lindex $KD2_L1 1] - [lindex $KD2_L0 1]) * $i / 6.0) + 1}] \
        -when now
      update
    }
    event generate .rdw.p.t <ButtonRelease-1> -x [expr {[lindex $KD2_L1 0] + 1}] \
      -y [expr {[lindex $KD2_L1 1] + 1}] -when now
    update
  }
  set KD2_SEL {} ; catch {set KD2_SEL [.rdw.p.t get sel.first sel.last]}
  set KD2_NB0 [kx_nblocks]
  set KD2_KIND0 [kx_listkind]
  kd_focus .rdw.p.t
  event generate .rdw.p.t <Control-Key-2> -when now
  update
  set KD2_NB1 [kx_nblocks]
  set KD2_SEL1 {} ; catch {set KD2_SEL1 [.rdw.p.t get sel.first sel.last]}
  catch {clipboard clear}
  event generate .rdw.p.t <Control-Key-c> -when now
  update
  set KD2_CLIP NOCLIP ; catch {set KD2_CLIP [clipboard get]}
  check {KD2 THE NEW KEYBOARD MUST NOT COST THE WINDOW ITS REASON FOR EXISTING: with a real multi-line drag standing in the pane, a real Control-2 answers NOTHING - no dump, no list change, and the selection is still there - and a real Control-C still puts exactly the selected text on the clipboard, so ruling DD-5's select-and-paste-into-a-design-review path is untouched by the digits} \
    [list [expr {[string length $KD2_SEL] > 0 ? 1 : 0}] \
          [expr {$KD2_NB1 == $KD2_NB0 ? 1 : 0}] \
          [expr {[kx_listkind] eq $KD2_KIND0 ? 1 : 0}] \
          [expr {$KD2_SEL1 eq $KD2_SEL ? 1 : 0}] \
          [expr {$KD2_CLIP eq $KD2_SEL ? 1 : 0}]] \
    {1 1 1 1 1}

  catch {clipboard clear}
  kx_ans ::rdw::set_list summary
}

# ============================================================================
# SECTION HP — ISSUE 1384, THROUGH THE REAL KEYBOARD AND THE REAL STATUS BAR
# ============================================================================
# The sentence, the slot, the tooltip arithmetic and all four exits are section
# HT of test_rdw_window_1245.tcl, which drives `rdw::key` as a COMMAND.  What
# only this file can add is the user's actual gesture: a bare `1` on the design
# canvas under src/cadence_style_rc, which is where ruling D-2 put those keys
# and which cannot be sourced under --nogui at all.
#
# ⚠ NO WIDTH IS ASSERTED HERE.  The tooltip half is width-dependent and the
# main window's width is restored per schematic FILE out of the user's
# `~/.xschem/geometry` (issue 1385), so it is measured in the window suite,
# which sets its own geometry.  These two rows are about text on a label.
if {[kx_ans ::rdw::have_tk] eq {1} && [winfo exists .statusbar.10]} {
  set HP_SLOT [kx_ans ::rdw::_hint_slot [xschem get current_win_path]]
  set HP_ANN {Click on instance for annotation OP info in Results Display Window}
  proc hp_txt {} { global HP_SLOT ; set r {} ; catch {set r [$HP_SLOT cget -text]} ; return $r }
  proc hp_st  {} { global HP_SLOT ; set r {} ; catch {set r [$HP_SLOT cget -state]} ; return $r }
  proc hp_pumping {} { return [expr {[info exists ::rdw::hint(after)] ? 1 : 0}] }
  ## The mode's private binding tag on the design canvas -- the SYNCHRONOUS
  ## re-assert, which is what actually keeps the sentence on screen while the
  ## pointer moves (the 80 ms timer alone was measured to lose 16-40% of the
  ## time to C's per-event blank).  Asked for by name from the proc that owns
  ## it, so this reader cannot drift from the code.
  proc hp_tagged {} {
    set t [kx_ans ::rdw::_hint_tag]
    if {![winfo exists .drw]} { return NO-CANVAS }
    return [expr {[lsearch -exact [bindtags .drw] $t] >= 0 ? 1 : 0}]
  }
  proc hp_settle {{n 8}} { for {set i 0} {$i < $n} {incr i} { catch {update} ; after 30 } }

  ## -------------------------------------------------------------------------
  ## HP1 — THE USER'S OWN GESTURE, END TO END.
  ## Bare `1` on the canvas with nothing selected: cadence_style_rc's bind ->
  ## rdw::key -> the `none` branch -> pick_start -> the sheet says what the
  ## mode is waiting for.  Then the mode's own documented exit, a real ESC on
  ## the canvas, takes it away again.  The slot is asserted BLANK first, so a
  ## label that already said this cannot make the row pass.
  kx_ans ::rdw::pick_end
  kx_reset
  hp_settle 4
  set HP1_PRE [list [hp_txt] [hp_st] [hp_pumping] [hp_tagged]]
  focus -force .drw ; update idletasks
  event generate .drw <Key-1> -when now
  update
  hp_settle 6
  set HP1_UP [list [hp_txt] [hp_st] [hp_pumping] [hp_tagged] [seized] [kx_listkind]]
  ## THE MOUSE MOVES, WHICH IS WHAT THE SENTENCE IS ASKING FOR.  C blanks
  ## `.statusbar.10` at the top of `callback()` on every canvas event, so a row
  ## that reads the label without ever moving the pointer reads a label nothing
  ## attacked.  These are real motions on the real canvas, delivered `-when now`
  ## so no timer can have run between the last one and the read: what survives
  ## them is the binding tag's work.
  for {set _i 0} {$_i < 8} {incr _i} {
    event generate .drw <Motion> -x [expr {60 + $_i * 13}] -y [expr {60 + $_i * 9}] -when now
  }
  set HP1_MOVED [list [hp_txt] [hp_st] [hp_tagged]]
  focus -force .drw ; update idletasks
  event generate .drw <Key-Escape> -when now
  update
  set HP1_DOWN [list [hp_txt] [hp_st] [hp_pumping] [hp_tagged] [seized]]
  check {HP1 A BARE 1 ON THE DESIGN CANVAS, WITH NOTHING SELECTED, MAKES THE SHEET SAY WHAT THE COMMAND MODE IS WAITING FOR AND KEEPS SAYING IT WHILE THE HAND MOVES - and a real ESC on the canvas takes it back: the profile's own keybinding reaches rdw::key, the none branch arms the pick, .statusbar.10 carries the user's annotation sentence in the -state active C uses for its own mode prompts, the private binding tag is on the canvas and the backstop timer is armed; eight real hover motions delivered synchronously leave the sentence STANDING, which is C's per-event blank being undone in the same binding invocation it happened in; and after the mode's documented exit the label is blank, normal, untagged and unpumped again with the canvas handed back} \
    [list $HP1_PRE $HP1_UP $HP1_MOVED $HP1_DOWN] \
    [list [list { } normal 0 0] [list $HP_ANN active 1 1 1 annotation] \
          [list $HP_ANN active 1] [list { } normal 0 0 0]]

  ## -------------------------------------------------------------------------
  ## HP2 — THE RULING, THROUGH THE REAL KEYBOARD.
  ## "If an instance is selected and user presses 1/2/3, only the selected
  ## instance is processed.  One does not enter command mode in this case."
  ## Driven at HEAD before the hint existed and already true; what this row
  ## adds is that the SHEET stays silent on that branch, and it asserts the
  ## dump really happened so the silence is not the silence of a dead key.
  kx_ans ::rdw::pick_end
  kx_reset
  hp_settle 4
  xschem unselect_all
  xschem select instance M1
  set HP2_SEL [xschem get lastsel]
  focus -force .drw ; update idletasks
  event generate .drw <Key-1> -when now
  update
  hp_settle 6
  set HP2 [list [hp_txt] [hp_st] [hp_pumping] [hp_tagged] [seized] \
                [expr {[kx_nblocks] >= 1 ? 1 : 0}]]
  xschem unselect_all
  kx_ans ::rdw::close
  kx_reset
  check {HP2 WITH AN INSTANCE SELECTED THE SAME KEY SAYS NOTHING ON THE SHEET, WHICH IS THE USER'S OWN RULING: a real bare 1 with M1 selected dumps M1 and enters NO command mode, so .statusbar.10 is still blank and normal, no backstop timer is running, no binding tag is left on the canvas and the canvas is not seized - and the dump leg is there so the silence cannot be the silence of a key that did nothing} \
    [list $HP2_SEL $HP2] \
    [list 1 [list { } normal 0 0 0 1]]

  kx_ans ::rdw::set_list summary
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
## ⚠ RAISED 35 -> 36 BY ITEM B5-a, WHICH ADDED ROW KS1. A floor is raised when
## rows are added and NEVER lowered to make a run pass — lowering it is the one
## move that would put the skipped-row defect straight back.
## ⚠ AND RAISED 36 -> 41 BY ITEM B5-2, IN THE SAME COMMIT AS THE FIVE ROWS IT
## COVERS: section SD's SD1, SD2, SD3, SD3b and SD4. The whole section is
## guarded by `if {[kx_ans ::rdw::have_tk] eq {1}}`, so a display that fails to
## come up drops all five silently - which is exactly what a floor is for.
## ⚠ AND RAISED 41 -> 51 BY ITEM R1 (issue 1337), IN THE SAME COMMIT AS THE
## TEN ROWS IT COVERS: section CU's CU6..CU15, the line cursor driven with real
## clicks on a mapped pane. The whole section is guarded by
## `[kx_ans ::rdw::have_tk] eq 1`, so a display that fails to come up drops all
## ten silently - which is exactly what a floor is for.
## ⚠ AND RAISED 51 -> 53 BY ITEM R2 (issue 1338), IN THE SAME COMMIT AS THE
## TWO ROWS IT COVERS: section RD's RD1 and RD2, the pane itself repainting
## after a real `.rdw.b.up` press.  That section is guarded by
## `[kx_ans ::rdw::have_tk] eq 1` too, so a display that fails to come up drops
## both silently - which is exactly what a floor is for.
## ⚠ AND RAISED 53 -> 59 BY ITEM R4 (issue 1340), IN THE SAME COMMIT AS THE
## SIX ROWS IT COVERS: section RA's RA1..RA6, a dump raising the window the
## way Ctrl-Alt-S raises the Library Manager, driven against a real decoy
## toplevel on a real stacking order.  That section is guarded by
## `[kx_ans ::rdw::have_tk] eq 1` too, so a display that fails to come up drops
## all six silently - which is exactly what a floor is for.
## ⚠ AND RAISED 59 -> 70 BY ITEM R3 (issue 1339), IN THE SAME COMMIT AS THE
## ELEVEN ROWS IT COVERS: section CP's CP1..CP11, select-and-copy driven with real
## chords, a real right-click and real double-click-then-drag gestures against
## a real X selection and a real clipboard.  That section is guarded by
## `[kx_ans ::rdw::have_tk] eq 1` too, so a display that fails to come up drops
## all eleven silently - which is exactly what a floor is for.
## ⚠ AND RAISED 70 -> 71 BY R3's IMPLEMENTING CREW, IN THE SAME COMMIT AS THE
## ONE ROW IT COVERS: CP12, the stale remembered span. The RED agent's eleven
## rows all select and copy inside a single fixture; CP12 is the input the FIX
## introduces - namespace state holding text indices - and it is in section CP,
## behind the same have_tk guard, so it drops with the rest when no display
## comes up.
## ⚠ AND RAISED 71 -> 74 BY THE REPAIR OF ISSUE 1344, IN THE SAME COMMIT AS
## THE THREE ROWS IT COVERS: CP13, CP14 and CP15 - the empty window's copy, the
## selection in the window's own status line, and the two sentences that
## disagreed about one and the same content.  All three are in section CP,
## behind the same have_tk guard, so they drop with the rest when no display
## comes up.  A floor is raised when rows are added and NEVER lowered to make a
## run pass.
## ⚠ AND RAISED 74 -> 77 BY THE REPAIR OF ISSUE 1332, WHICH ADDED SD5, SD6
## AND SD7 AND FORGOT TO RAISE IT - caught by that repair's adversary, not by
## the suite, which is the point: the floor had three rows of slack, and the
## three rows it could no longer see were the three that fence issue 1332
## itself.  Section SD is EIGHT rows now, not the five the B5-2 paragraph
## above lists (that paragraph is correct about its own raise and is not an
## inventory of the section).  All eight sit behind the same
## `[kx_ans ::rdw::have_tk] eq {1}` guard, so they drop together when no
## display comes up.  A floor is raised when rows are added and NEVER lowered
## to make a run pass.
## ⚠ AND RAISED 77 -> 80 IN THE SAME COMMIT AS SD8, SD9 AND SD10, the three
## rows that fence what issue 1332's adversary found in the fix for 1332: a
## grab belonging to any other window satisfied the poll, a second arm
## orphaned the chain it replaced instead of cancelling it, and the give-up
## was a poll count that ran PAST the deadman it was said to sit inside.
## Section SD is ELEVEN rows now.  All eleven are behind the same
## `[kx_ans ::rdw::have_tk] eq {1}` guard.
## ⚠ AND RAISED 80 -> 81 IN THE SAME COMMIT AS CP16, the row that fences issue
## 1351: a status line rewritten under a live selection used to leave the
## indices standing over the new text, so the next press of the chord copied a
## slice of the refusal sentence, silently.  CP16 is in section CP, behind the
## same guard, so it drops with the rest when no display comes up.
## ⚠ AND RAISED 81 -> 83 IN THE SAME COMMIT AS KN1 AND KN2, the two rows that
## answer issue 1300 through the real keybindings: a bare 1 over a selected
## device prints the class's annotation list and not the row the run also
## published, and keys 1, 2 and 3 stop rendering the byte-identical blocks the
## user met.  Section KN is NOT behind the `have_tk` guard - it drives real key
## events on a real canvas, which this suite cannot run without at all - so the
## two rows are always in the denominator.  A floor is raised when rows are
## added and NEVER lowered to make a run pass.
## ⚠ AND RAISED 83 -> 85 IN THE SAME COMMIT AS LK1 AND LK2, the two rows that
## answer the user's SECOND complaint through the real keys and the real modal:
## a bare 1, 2 or 3 moving the window's chrome line and its title along with the
## identity, and the pop-up a real Delete raises on the summary list finally
## naming the list it is about.  Both are inside this file's
## `[kx_ans ::rdw::have_tk] eq {1}` guard - a display that fails to come up
## drops both silently, which is exactly what a floor is for.  Issue 1355's
## pure decisions are section LX of test_rdw_window_1245.tcl.  A floor is
## raised when rows are added and NEVER lowered to make a run pass.
## ⚠ AND RAISED 85 -> 87 IN THE SAME COMMIT AS KD1 AND KD2, the two rows that
## answer the user's THIRD complaint - "I tried deleting one at a time. That
## also did not have an effect next time I printed summary." - by driving the
## digit AT THE FOCUS THEIR OWN CLICK LEAVES, with no `focus -force` in front
## of it, and by fencing that the new keyboard costs this window neither its
## selection nor its copy chord.  Both are inside this file's
## `[kx_ans ::rdw::have_tk] eq {1}` guard - a display that fails to come up
## drops both silently, which is exactly what a floor is for.  Issue 1358's
## pure decisions are section KB of test_rdw_window_1245.tcl.  A floor is
## raised when rows are added and NEVER lowered to make a run pass.
## ⚠ AND RAISED 87 -> 88 IN THE SAME COMMIT AS LK3, the row that takes the
## chrome line's `Keys 1/2/3:` prefix off the REAL binds of the REAL canvas -
## removing them, watching the label drop the prefix, and putting them back -
## because src/xschem.tcl offers this window from the Tools menu in every
## profile while the four digit binds live in src/cadence_style_rc alone
## (ruling D-2), so the sentence was false on every open outside that profile.
## LK3 is inside this file's `[kx_ans ::rdw::have_tk] eq {1}` guard - a display
## that fails to come up drops it silently, which is exactly what a floor is
## for.  The pure half is row LX14 of test_rdw_window_1245.tcl, which drives
## the text builder at both values with no display at all.  A floor is raised
## when rows are added and NEVER lowered to make a run pass.
## ⚠ AND RAISED 88 -> 90 BY THE REPAIR OF ISSUE 1369, IN THE SAME COMMIT AS
## F5 AND F6 - the two rows that make a dump's focus grant arrive AFTER the
## user's own click in this window, once on the results pane and once on the
## status line, and require the keyboard back on the canvas and the one-shot
## spent.  Neither is behind the `[kx_ans ::rdw::have_tk] eq {1}` guard: they
## are in section F, which this suite cannot run without a display at all, so
## both are always in the denominator.  Row F3 is RE-SPELLED by the same commit
## rather than added - its last leg moves 1 -> 0 because the deliberate click
## now spends the one-shot - so it does not move the count.  Issue 1369's
## structural row is K18 of test_rdw_window_1245.tcl.  A floor is raised when
## rows are added and NEVER lowered to make a run pass.
## ⚠ AND RAISED 90 -> 92 BY ISSUE 1384, IN THE SAME COMMIT AS HP1 AND HP2 -
## the two rows that press a bare `1` on the design canvas under this profile's
## own binding and read the SHEET's status bar: once with nothing selected,
## where the pick mode arms and the sentence appears and a real ESC takes it
## away, and once with an instance selected, where the user's ruling says only
## that instance is processed and no command mode is entered, so the sheet must
## stay silent.  Both are behind this file's `[kx_ans ::rdw::have_tk] eq {1}`
## guard plus a `winfo exists .statusbar.10`, so a display that fails to come
## up drops them silently - which is exactly what a floor is for.  The
## sentence, the slot arithmetic, the tooltip and all four exits are section HT
## of test_rdw_window_1245.tcl, whose RW_FLOOR moves 193 -> 197 in the same
## commit.  A floor is raised when rows are added and NEVER lowered to make a
## run pass.
set KX_FLOOR 92
set KX_RAN [expr {$npass + $fail}]
if {$KX_RAN < $KX_FLOOR} {
  puts "FAIL: KXFLOOR the suite ran only $KX_RAN checks, below its floor of\
$KX_FLOOR — rows were SKIPPED, and a skipped row is not a passing one : FAIL"
  incr fail
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
