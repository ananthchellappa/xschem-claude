# Issue 0076 regression: `xschem callback` with too few args must return a Tcl ERROR,
# never crash. Before the fix the branch read argv[2..9] with no argc guard, so
# `xschem callback` (argc==2) passed argv[2]==NULL as win_path into callback() ->
# NULL deref -> SIGSEGV -> emergency-save -> the whole editor died (same class as the
# select_inside typo, issue 0075). callback needs argc>=10
# (win_path event mx my key button aux state).
#
# The script reaching "OVERALL: ok" is itself the core assertion: a crash on any short
# form kills the process before the sentinel and run_regression scores it FAIL.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_callback_argc.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# Every short-argc form (argc 2..9) must ERROR, not crash. Getting through the whole
# loop proves none SIGSEGV'd.
foreach {label cmd} {
  "no args (argc 2)"        {xschem callback}
  "win only (argc 3)"       {xschem callback .drw}
  "partial (argc 6)"        {xschem callback .drw 5 0 0}
  "one short (argc 9)"      {xschem callback .drw 5 0 0 0 0 0}
} {
  check "short errors: $label" [catch $cmd] 1
}

catch {xschem callback} emsg
check "usage message" [string match {*callback: usage*} $emsg] 1

# =============================================================================
# ISSUE 1483 -- the same class as this file's subject, reached through a
# different verb: an `xschem` subcommand that dereferences the X `display`
# global while has_x is 0.
#
# ⚠ WHY THESE ROWS RUN ON EVERY BOX AND NOT ONLY ON A HEADLESS ONE.
# `display` is assigned ONLY inside `if(has_x)` (xinit.c). With has_x 0 it is
# either NULL -- no DISPLAY, xserver_ok() (draw.c) never assigns it -- or a
# pointer xserver_ok() has already XCloseDisplay()d, which is what `--nogui`
# with a live DISPLAY leaves behind. So the value rows below assert the OPPOSITE
# thing on the two sides of that guard, and they must say which side they are on
# -- see "THIS FILE RUNS ON THREE ARMS" below.
# 1483 survived because the only arm anyone ran had DISPLAY set AND --nogui,
# where the SAME bad pointer merely read freed memory instead of faulting.
# Measured on the unfixed binary, --nogui with DISPLAY set: `XMaxRequestSize=4`
# against a true 65535 -- a fabricated number, silently. With DISPLAY unset the
# same statement took four T1 suites down with SIGSEGV.
#
# ⚠ THIS FILE RUNS ON THREE ARMS, NOT ONE. run_regression.tcl hard-codes
# --nogui (has_x 0), but this suite is NOT in full_audit.sh's `nogui_tests`
# list, and neither full_audit.sh nor `run_suites.sh test_callback_argc` passes
# --nogui -- so on a developer box with a display those two run it with has_x 1,
# where the product correctly reports the real numbers. An unconditional
# "neither field is a number" row is therefore WRONG on the very arm CLAUDE.md
# documents as the trustworthy signal; it was written that way in the first
# round and reddened both drivers (measured: `-> {1 1} (exp {0 0})`).
# `::has_x` is the codebase's own mirror of the C guard -- xinit.c sets it to 1
# inside `if(has_x)` and nowhere else, so `[info exists ::has_x]` is exactly
# has_x==1 (the idiom ase.tcl, ase_window.tcl and op_annot.tcl already use).
# Branching on it keeps ONE row either way, so the count is 8 on every arm, and
# it buys a real assertion on the X path, which nothing else in the tree makes:
# a guard that short-circuited the X path would redden the positive branch.
#
# NARROW BY CHOICE: this pins `xschem globals`, the one command 1483 was filed
# against, not the many other `display` dereferences in src/ (deliberately not a
# count: three passes have produced three different ones -- see B-verify.md
# §4.1). A reader adding a new X call to a Tcl-reachable command is not caught
# by these rows; guard it on has_x.
set g1483 {}
check "1483 `xschem globals` survives (display NULL, closed, or live)" \
  [catch {xschem globals} g1483] 0

# The keys must still be THERE -- a guard that deleted the section would hide
# the regression from any reader looking for it. UNIX ONLY: the whole
# "Xserver options" block, header included, is inside `#ifdef __unix__`
# (scheduler.c), so on a Windows build the keys are absent and the product is
# still correct. READ from the source, not measured -- the suites only ever run
# on Linux here -- hence the expectation tracks the platform rather than
# asserting a unix truth everywhere.
set x1483_unix [expr {$::tcl_platform(platform) eq "unix"}]
set x1483_max {} ; set x1483_ext {}
foreach l [split $g1483 "\n"] {
  if {[regexp {^XMaxRequestSize=(.*)$} $l -> v]} { set x1483_max $v }
  if {[regexp {^XExtendedMaxRequestSize=(.*)$} $l -> v]} { set x1483_ext $v }
}
check "1483 both Xserver keys are reported wherever the block is compiled" \
  [list [expr {$x1483_max ne {}}] [expr {$x1483_ext ne {}}]] \
  [list $x1483_unix $x1483_unix]

if {[info exists ::has_x] && $x1483_unix} {
  # has_x 1: a live Display*, and the two fields must carry the real figures.
  # This is the arm full_audit.sh and run_suites.sh actually use.
  check "1483 both X fields carry a real number when a display exists" \
    [list [string is integer -strict $x1483_max] [string is integer -strict $x1483_ext]] {1 1}
} else {
  # has_x 0: each must say there is no display rather than carry a number. A
  # bare integer here is the unfixed code reading a NULL or closed Display* and
  # getting away with it -- the exact shape that made the defect invisible.
  check "1483 neither X field fabricates a number when there is no display" \
    [list [string is integer -strict $x1483_max] [string is integer -strict $x1483_ext]] {0 0}
}

# =============================================================================
# THE HEADLESS-CRASH CLASS -- issues 1493, 0227/0834/0467 and 1492, plus three
# entry points that were in no issue file until the item-A map drove for them
# (doc/claude/headless_crashes_batch/receipts/A-map.md).
#
# WHY THEY LIVE HERE. This file is the T1 case for "a Tcl-reachable `xschem`
# subcommand must ERROR, never crash" (issue 0076), and run_regression.tcl
# hard-codes --nogui, so has_x is 0 in T1 ON EVERY BOX -- including a developer
# desktop with a display. The four suites that witnessed the class
# (test_keybind_snap_grid, test_undo_selection, test_hilight_case_senders,
# test_window_switch_bogus_enter) are NOT T1 cases and are not in
# full_audit.sh's `nogui_tests` either, which is precisely why a green T1 --
# the first headless ZERO this tree ever had -- said nothing about a defect
# that killed the process on five different entry points.
#
# ⚠ THE ROWS ARE NOT THE WHOLE ASSERTION. `catch` cannot catch a SIGSEGV: on
# the unfixed binary each of these lines ENDED THE PROCESS, so the file never
# reached its sentinel and run_regression scored it FAIL. Reaching
# "OVERALL: ok" is the core assertion; the named rows say WHICH door, and add
# the contract (a proper Tcl error, with a message that names the cause).
#
# ⚠ THE X ARM. As the 1483 block above explains, this file runs on three arms
# and only T1's passes --nogui. Rows whose subject IS the no-display contract
# cannot be measured with a display, and three of the verbs are actively unsafe
# to drive there -- `compare_schematics` with no argument opens a MODAL FILE
# DIALOG and hangs (measured: rc 124), the Ctrl-'=' fill toggle pops an alert_
# and hangs the same way, and `grabscreen` takes a GLOBAL POINTER GRAB. Those
# rows therefore print `skip:` with their reason on a has_x 1 arm rather than
# passing silently (CLAUDE.md, XSCHEM_TEST_REAL_HOME: "a row that finds nothing
# prints skip:, never a silent pass"). T1 runs them all.
# =============================================================================

proc hc_skip {name why} { puts "skip: $name -- $why" }

# --- 0227 / 0834 / 0467: update_statusbar() -> XGetKeyboardControl(display) ---
# Called UNCONDITIONALLY at the top of callback(), before any dispatch, so EVERY
# `xschem callback` died -- all 540 window x event x key/button combinations the
# map drove. Safe on both arms: with a display these are ordinary synthetic
# events. 0834's open question ("is window `.` a second defect at the window-name
# lookup?") is settled by driving `.` as well as `.drw`: both reached the same
# statement and nothing else.
check "0227 callback KeyPress on .drw survives (update_statusbar guard)" \
  [catch {xschem callback .drw 2 100 100 103 0 0 0}] 0
# Same event as the row above, differing ONLY in the window path -- which is
# 0834's own open question ("0834's repro uses window `.`; 0227's uses `.drw`;
# whether `.` is a second defect at the window-name lookup is not settled").
# The map drove all three paths and every one reached callback.c's
# update_statusbar() and nothing else, refuting the second candidate; this row
# keeps that settled. 0834's literal repro passes key 73 ('I'), which opens a
# symbol chooser and prints a Tk error on the way past -- the key is not the
# subject, so it is the neighbouring row's harmless one.
check "0834 callback KeyPress on window . survives (same event, window . not .drw)" \
  [catch {xschem callback . 2 100 100 103 0 0 0}] 0
check "0227 callback MotionNotify survives" \
  [catch {xschem callback .drw 6 100 100 0 0 0 0}] 0

# --- NEW (no issue file): handle_expose() -> MyXCopyArea on a NULL gc[0] -------
# Needs no state at all. This is the SECOND landmine in callback(): with 0227's
# one-line update_statusbar() guard applied and nothing else, this still
# segfaulted, which is what 0227's own "the rest of that function is unproven
# headless" warned about.
check "1492-class callback Expose survives (handle_expose guard)" \
  [catch {xschem callback .drw 12 100 100 0 0 0 0}] 0

# --- NEW (no issue file): the crosshair and snap-cursor families --------------
# draw_crosshair()/draw_snap_cursor() were dispatched on a Tcl variable and the
# event type alone, and erase_crosshair()/erase_snap_cursor() copy from
# xctx->save_pixmap through xctx->gc[0] -- all 0/NULL with has_x 0. Note these
# fault on a NULL GC, NOT on a NULL Display*, so issue 1493's nulled global
# cannot help them and only a has_x guard can. Restore both variables
# afterwards: this file is not the place to change global draw modes.
#
# ⚠ THESE THREE ROWS (Expose above, and the two below) ARE LIVENESS ONLY, and
# the fix round says so rather than leaving the reader to assume otherwise. A
# `catch == 0` cannot tell a correctly conditional guard from a dead function:
# forcing all three guards to `if(1) return;` -- which kills the crosshair, the
# snap cursor and every Expose repaint for every GUI user -- leaves this suite,
# and a whole T1, green (MEASURED by the verify round). What these rows own is
# the crash. Their CONDITIONALITY is owned by the GX* source rows at the end of
# this file, which redden on exactly that sabotage, and the behavioural positive
# for the statusbar guard lives in test_headless_guards_xarm_1492.tcl, a dcase
# that runs with a display. The glyphs themselves are eyeball-only: both are
# painted straight to the window with draw_pixmap = 0, so nothing in the tree
# can read them back (the same limit test_wave_snap.tcl states for its diamond).
set hc_xh $draw_crosshair ; set hc_sc $snap_cursor
set draw_crosshair 1 ; set snap_cursor 0
catch {xschem callback .drw 7 100 100 0 0 0 0}    ;# EnterNotify: mouse_inside
check "1492-class crosshair motion survives (draw_crosshair guard)" \
  [list [catch {xschem callback .drw 6 100 100 0 1 0 0}] \
        [catch {xschem callback .drw 6 200 200 0 1 0 0}]] {0 0}
set draw_crosshair 0 ; set snap_cursor 1
catch {xschem callback .drw 7 100 100 0 0 0 0}
check "1492-class snap-cursor motion survives (draw_snap_cursor guard)" \
  [list [catch {xschem callback .drw 6 100 100 0 1 0 0}] \
        [catch {xschem callback .drw 6 200 200 0 1 0 0}]] {0 0}
set draw_crosshair $hc_xh ; set snap_cursor $hc_sc

# --- 1492: copy_hilights -- NOT a display defect, and the row says so ---------
# 1492 files this verb in the no-display family; the map re-took the backtrace
# and it is a NULL `old_xctx` in hilight.c, it touches zero display sites, and
# it CRASHES IDENTICALLY WITH A FULL GUI (measured on has_x 1). So this row is
# unconditional on purpose: it is the one row in this block that must hold on
# every arm, and a has_x guard here would have left the crash live on the arm
# everybody runs. `old_xctx` is set only by a window/tab switch, so in this
# suite -- which never opens a second window -- it is NULL and the verb must
# refuse rather than die.
set hc_ch {}
check "1492 copy_hilights errors with no previous window (both arms)" \
  [catch {xschem copy_hilights} hc_ch] 1
check "1492 copy_hilights says WHY it refused" \
  [string match {*no previous window or tab*} $hc_ch] 1

# --- 1492 + NEW: the verbs whose whole job needs a display -------------------
# The contract is 0834 §4: "reject the verb when has_x is false with a proper
# Tcl error ... a clear error is strictly better than a signal 11 plus an
# emergency-save directory". Asserting the MESSAGE as well as the refusal is
# what keeps this from being satisfiable by any old error: a guard that skipped
# the work and returned TCL_OK, or one that failed for an unrelated reason,
# fails these rows.
#
# fill_reset carries the ANTI-HOLLOW half and is therefore branched rather than
# skipped, in the 1483 rows' idiom: ONE row either way, so T1 gains no `skip:`.
# The shared refusal must be CONDITIONAL -- a guard written `if(1)`, or one that
# refused on the wrong condition (which is exactly how these four branches
# already read before the fix: they guarded !xctx and walked into the Xlib call)
# would break the verb for every GUI user, and no headless row could see it.
# fill_reset is the one of the four safe to drive on a live display: it rebuilds
# the GCs and redraws, with no modal dialog and no pointer grab.
if {[info exists ::has_x]} {
  set hc_fr {}
  check "1492 xschem fill_reset still WORKS when a display exists (the guard is conditional)" \
    [catch {xschem fill_reset nodraw} hc_fr] 0
} else {
  set hc_fr {}
  check "1492 xschem fill_reset errors, not signal 11, with no display\
 (free_gc()/create_gc() -> XFreeGC/XCreateBitmapFromData)" \
    [catch {xschem fill_reset} hc_fr] 1
  check "1492 xschem fill_reset names the missing display" \
    [string match {*no X server connection*} $hc_fr] 1
}

foreach {hc_v hc_why} {
  fullscreen          {toggle_fullscreen() -> XQueryTree + window_state}
  compare_schematics  {create_gc() -> XCreateBitmapFromData (exited 139: never reached xschem's own handler)}
  grabscreen          {arms ui_state |= GRABSCREEN, then any canvas event faults in grabscreen()}
} {
  if {[info exists ::has_x]} {
    hc_skip "1492 xschem $hc_v refuses with no display" \
      "has_x 1 on this arm, and a refusal that needs no display cannot be measured with one"
    continue
  }
  set hc_m {}
  check "1492 xschem $hc_v errors, not signal 11, with no display ($hc_why)" \
    [catch [list xschem $hc_v] hc_m] 1
  check "1492 xschem $hc_v names the missing display" \
    [string match {*no X server connection*} $hc_m] 1
}

# grabscreen's row above drives the VERB; the crash needs the SEQUENCE. The verb
# arms xctx->ui_state |= GRABSCREEN and callback() then dispatches EVERY canvas
# event into grabscreen() (draw.c) on that bit alone -- no event type, no has_x
# -- where WhitePixel(display, screen_number) faulted. TWO guards stand between
# a script and that: the verb refuses to arm the bit, and grabscreen() returns
# early. Only this row drives both.
#
# ⚠ UPDATED BY THE FIX ROUND. The line that used to stand here said removing
# just one of the two "leaves the suite green", and that is no longer true in
# either direction: removing the verb refusal reddens this row and the two
# refusal rows above it (sabotage S10'), and removing grabscreen()'s entry guard
# reddens GX8 below. It was never true for the reason it gave, either -- the
# entry guard was reachable all along through the XK_Print key, which nothing
# here drove until the fix round added the sequence rows further down.
if {[info exists ::has_x]} {
  hc_skip "1492-class grabscreen then ButtonPress survives" \
    "has_x 1 on this arm; `xschem grabscreen` takes a GLOBAL POINTER GRAB there"
} else {
  check "1492-class grabscreen then ButtonPress survives (verb refusal AND entry guard)" \
    [list [catch {xschem grabscreen}] [catch {xschem callback .drw 4 100 100 0 1 0 0}]] {1 0}
}

# --- NEW (no issue file): Ctrl-'=' toggles fill patterns on NULL stipple GCs --
# `xschem callback .drw 2 100 100 61 0 0 4`. The map classed these four
# XSetFillStyle() sites as "not reached by this workload"; they are reached from
# a two-line script, and they faulted as soon as the 0227 guard stopped masking
# them. Driven only headless: with a display the alert_ this key pops is modal
# and hangs the suite (measured: rc 124).
if {[info exists ::has_x]} {
  hc_skip "1492-class Ctrl-'=' fill toggle survives" \
    "has_x 1 on this arm; the alert_ this key pops is modal and would hang the suite"
} else {
  # Pressed twice: fill_pattern is a two-state toggle (0->1->0), so the mode the
  # session started in is the mode it ends in.
  check "1492-class Ctrl-'=' fill toggle survives (XSetFillStyle guards)" \
    [list [catch {xschem callback .drw 2 100 100 61 0 0 4}] \
          [catch {xschem callback .drw 2 100 100 61 0 0 4}]] {0 0}
}

# --- 1493: the two has_x == 0 arms must AGREE --------------------------------
# 1493 step 4 in one row. xserver_ok() (draw.c) opens a probe connection, closes
# it, and NULLS the global; before that it left it dangling, so has_x 0 had two
# different pointer states and a missed guard faulted on the DISPLAY-unset arm
# while reading freed memory on the DISPLAY-set one -- measured as a fabricated
# XMaxRequestSize=4 against a true 65535, and as an abort inside libxcb further
# down the same freed connection. `xschem globals` reports the POINTER (it never
# dereferences it), so this row says: with has_x 0 there is no connection,
# whatever DISPLAY says.
#
# ⚠ WHAT THIS ROW CAN AND CANNOT CATCH. Revert `display = NULL;` and it reddens
# on a box WITH a DISPLAY (T1's own arm here, since run_regression.tcl passes
# --nogui but does not unset DISPLAY). On a truly headless box the global was
# never assigned, so the row passes either way and the sabotage is invisible --
# which is the same asymmetry that hid 1483, stated as a limit of the row
# rather than left to be rediscovered.
set x1493_disp {}
foreach l [split $g1483 "\n"] {
  if {[regexp {^display=(.*)$} $l -> v]} { set x1493_disp $v }
}
if {!$x1483_unix} {
  hc_skip "1493 the display global agrees with has_x" \
    "the Xserver options block of `xschem globals` is #ifdef __unix__"
} elseif {[info exists ::has_x]} {
  check "1493 the display global reports a connection when has_x is 1" \
    [expr {$x1493_disp eq "connected"}] 1
} else {
  check "1493 the display global reports NO connection when has_x is 0 (either arm)" \
    [expr {$x1493_disp ne "" && $x1493_disp ne "connected"}] 1
}

# =============================================================================
# THE FIX ROUND -- six more doors of the same class, none of which the implement
# round's 323-verb sweep could reach, and one guard that had turned a crash into
# something worse. Each row below was RED-FIRST on the landed binary: five of
# them ENDED THE PROCESS (so this file never printed its banner) and the sixth
# silently swallowed every later event.
#
# WHY THE FIRST SWEEP MISSED THEM, in one line each -- this is the part worth
# carrying forward, because it is a statement about the METHOD, not the bugs:
#   * the sweep drove every verb BARE, so bodies inside `if(argc > 3)` (fill_type)
#     and `if(argc == 4)` (preview_window) were never entered;
#   * it never ran `xschem load`, so waves_selected() always declined and the
#     graph handler was never called;
#   * it held key and state fixed, so the ONE lethal keystroke ('\', which
#     reaches toggle_fullscreen() the scheduler branch was guarding) never fired;
#   * it enumerated dereferences of the `display` GLOBAL, which is blind to a
#     LOCAL of the same name (windowid()) and to handles stored in xctx
#     (waves_callback's cairo contexts) -- blind spots (b) and (c) of A-map.md §6,
#     each of which turned out to hide a live crash.
# =============================================================================

# --- 1492 family: the backslash key reaches toggle_fullscreen() ---------------
# The implement round guarded the `xschem fullscreen` VERB; handle_key_press()
# case '\\' calls the same function with no verb in between, and still died at
# XQueryTree(). An exhaustive KeyPress sweep (ASCII 32-126 plus 60 keysyms x
# five modifier states) found this to be the only survivor-failure, which is the
# argument for guarding the FUNCTION -- the choice this file's Expose/crosshair
# rows already document. Not drivable with a display: it would make the toplevel
# fullscreen under a window manager and leave the rest of the suite there.
if {[info exists ::has_x]} {
  hc_skip "1492 the '\\' key (toggle_fullscreen) survives with no display" \
    "has_x 1 on this arm; this key would put the real toplevel in fullscreen"
} else {
  check "1492 the '\\' key survives with no display (toggle_fullscreen guard, not just the verb)" \
    [catch {xschem callback .drw 2 100 100 92 0 0 0}] 0
}

# --- THE GUARD THAT MADE THINGS WORSE: XK_Print arms GRABSCREEN ---------------
# `xschem callback .drw 2 <x> <y> 65377 0 0 0` -- the Print key -- armed
# xctx->ui_state |= GRABSCREEN with no has_x test, a SECOND arming site the
# implement round did not find (it guarded the verb). callback() then routes
# EVERY canvas event into grabscreen() on that bit alone, and grabscreen()'s new
# entry guard returned WITHOUT clearing it: from one keystroke onward the whole
# event switch was dead for the life of the process. MEASURED on the landed
# binary: after Print, the zoom-full key left `xorigin yorigin zoom` at
# `10 -870 1` (unchanged); without Print the same key moved it. That is a loud
# crash converted into a silent, permanent swallow of work the user asked for --
# PLAN.md criterion 3's own failure shape, so it gets a row that can SEE it: a
# `catch == 0` liveness row cannot.
#
# The control row first, so a change in the zoom-full key itself cannot be
# mistaken for the swallow.
if {[info exists ::has_x]} {
  hc_skip "1492 the Print key does not swallow every later event" \
    "has_x 1 on this arm; the Print key takes a GLOBAL POINTER GRAB there"
} else {
  xschem zoom_out
  set hc_v0 [list [xschem get xorigin] [xschem get yorigin] [xschem get zoom]]
  catch {xschem callback .drw 2 100 100 102 0 0 0}   ;# 'f' == zoom full
  set hc_v1 [list [xschem get xorigin] [xschem get yorigin] [xschem get zoom]]
  check "1492 control: the zoom-full key moves the view at all (no Print key)" \
    [expr {$hc_v1 ne $hc_v0}] 1
  xschem zoom_out
  set hc_v2 [list [xschem get xorigin] [xschem get yorigin] [xschem get zoom]]
  catch {xschem callback .drw 2 100 100 65377 0 0 0} ;# Print: arms GRABSCREEN
  catch {xschem callback .drw 2 100 100 102 0 0 0}   ;# 'f' must still work
  set hc_v3 [list [xschem get xorigin] [xschem get yorigin] [xschem get zoom]]
  check "1492 the Print key does not swallow every later event (grabscreen disarms)" \
    [expr {$hc_v3 ne $hc_v2}] 1
}

# --- 1492 family: windowid() -- a LOCAL `display` that shadows the global -----
# `xschem windowid .drw` -> Tk_Display(Tk_MainWindow(interp)) on a NULL Tk main
# window. Branched rather than skipped, in the fill_reset idiom, because the
# has_x 1 side is the ANTI-HOLLOW half: with a display the verb must still work.
if {[info exists ::has_x]} {
  check "1492 xschem windowid still WORKS when a display exists (the guard is conditional)" \
    [catch {xschem windowid .drw}] 0
} else {
  set hc_wi {}
  check "1492 xschem windowid errors, not signal 11, with no display (Tk_Display on a NULL mainwindow)" \
    [catch {xschem windowid .drw} hc_wi] 1
  check "1492 xschem windowid names the missing display" \
    [string match {*no X server connection*} $hc_wi] 1
}

# --- 1492 family: preview_window() -> Tk_NameToWindow on a NULL mainwindow ----
# Already named as a known headless death in test_raw_read_dispatch.tcl's
# comment block, and verb 203 of the implement round's corpus -- which could not
# see it, because this branch needs arguments. Same branched shape: with a
# display the verb must still answer.
if {[info exists ::has_x]} {
  check "1492 xschem preview_window still WORKS when a display exists (the guard is conditional)" \
    [catch {xschem preview_window create .hcprev .hcprev.drw}] 0
} else {
  set hc_pw {}
  check "1492 xschem preview_window errors, not signal 11, with no display (Tk_NameToWindow)" \
    [catch {xschem preview_window create .hcprev .hcprev.drw} hc_pw] 1
  check "1492 xschem preview_window names the missing display" \
    [string match {*no X server connection*} $hc_pw] 1
}

# --- 1492 family: waves_callback() -- cairo_save() on a NULL cairo_save_ctx ---
# THE BLOCKER of the fix round, and the one with the widest blast radius: 23 of
# the 60 schematics in xschem_library/examples killed the process on a single
# mouse motion, because `xctx->cairo_save_ctx` is NULL with has_x 0 and the
# cairo_save() pair at the head of that function is unconditional. Three Tcl
# lines are the whole repro. It runs on BOTH arms: with a display this is an
# ordinary hover over an embedded graph.
set no_recent_files 1
set hc_repo [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]
set hc_ex [file join $hc_repo xschem_library examples cmos_example.sch]
if {![file readable $hc_ex]} {
  hc_skip "1492 a motion over a graph survives (waves_callback guard)" \
    "fixture not readable: $hc_ex"
} else {
  check "1492 load + zoom_full + motion over a graph survives (waves_callback guard)" \
    [list [catch {xschem load $hc_ex}] \
          [catch {xschem zoom_full}] \
          [catch {xschem callback .drw 6 500 400 0 0 0 0}]] {0 0 0}
}

# --- 1492 family: fill_type, and why it GUARDS where fill_reset REFUSES -------
# `xschem fill_type <n> <type>` ran the identical free_gc()/create_gc() sequence
# fill_reset does, fourteen lines below the branch that got the refusal, and
# died in the same frame -- invisible to a sweep that drove every verb bare,
# since this body is inside `if(argc > 3)`.
#
# It is guarded rather than refused because xctx->fill_type[] is read by the
# HEADLESS exporters too -- psprint.c (four sites) and svgdraw.c (three) -- so
# this verb has real display-free work to do, and refusing it would be criterion
# 3's other failure. The second row is that claim, MEASURED rather than
# asserted: the same schematic exported to PostScript before and after the verb
# must differ. On the landed binary the first row killed the process.
if {![file readable $hc_ex]} {
  hc_skip "1492 xschem fill_type survives and still does its display-free half" \
    "fixture not readable: $hc_ex"
} else {
  check "1492 xschem fill_type survives with no display (free_gc()/create_gc() guarded, not refused)" \
    [catch {xschem fill_type 4 empty}] 0
  set hc_ch1 [file tempfile hc_ps1] ; close $hc_ch1
  set hc_ch2 [file tempfile hc_ps2] ; close $hc_ch2
  set hc_e1 [catch {xschem print ps $hc_ps1}]
  set hc_e2 [catch {xschem fill_type 4 solid}]
  set hc_e3 [catch {xschem print ps $hc_ps2}]
  if {$hc_e1 || $hc_e3} {
    hc_skip "1492 xschem fill_type still changes what a headless export draws" \
      "`xschem print ps` did not produce a file on this arm (rc $hc_e1/$hc_e3)"
  } else {
    set hc_f [open $hc_ps1 rb] ; set hc_b1 [read $hc_f] ; close $hc_f
    set hc_f [open $hc_ps2 rb] ; set hc_b2 [read $hc_f] ; close $hc_f
    check "1492 xschem fill_type still changes what a headless export draws (the work is not skipped)" \
      [list $hc_e2 [expr {$hc_b1 ne $hc_b2}] [expr {[string length $hc_b1] > 0}]] {0 1 1}
  }
  file delete -force $hc_ps1 $hc_ps2
}

# =============================================================================
# GX* -- THE GUARDS ARE CONDITIONAL, AND THIS IS THE ONLY ARM THAT CAN SAY SO
#
# ⚠ READ THIS BEFORE TRUSTING THE ROWS ABOVE. Every behavioural row in this
# block is a LIVENESS row: it proves the process did not die. None of them can
# fail if a guard is written `if(1) return;` instead of `if(!has_x) return;` --
# MEASURED by the verify round, which forced all seven of the implement round's
# guards to fire unconditionally, rebuilt, and ran twenty display-arm suites
# plus a whole T1: every result line was byte-identical and T1 was
# `counted_failures=0`. That sabotage kills the crosshair, the snap cursor,
# every Expose repaint and the statusbar for every GUI user.
#
# The behavioural answer needs a display, and T1's only display arm is the
# `dcases` loop -- so the positives that CAN be observed there now live in
# tests/headless/test_headless_guards_xarm_1492.tcl, which is a dcase. What
# cannot be observed anywhere is the painting itself: the crosshair and the snap
# cursor go straight to the window with draw_pixmap = 0, and an Expose repaint
# is a copy INTO the window, so no pixmap dump and no `xschem get` can read them
# back. For those three, conditionality is pinned HERE, textually, in the idiom
# test_wave_snap.tcl uses for the same reason ("source tripwires for what
# behaviour cannot reach").
#
# These rows are deliberately EXACT about the condition, not just about the
# presence of a guard: `if(1)`, `if(0)` or a guard moved to the wrong side of
# the work all redden them. They run on every arm and add no `skip:` to T1.
# =============================================================================

proc hc_src {path} {
  if {![file readable $path]} { return "" }
  set f [open $path r] ; set s [read $f] ; close $f ; return $s
}
# The text of one C function: from its signature to the next line that is a bare
# `}` in column 0. Enough to keep a per-function assertion honest without
# parsing C, and it is why these rows cannot be satisfied by a guard that sits
# in some OTHER function of the same file.
proc hc_body {src sig} {
  # ⚠ THE DEFINITION, NOT THE FORWARD DECLARATION. callback.c declares
  # draw_snap_cursor() 3500 lines above it defines it, and taking the first
  # match made this row read a stranger's body (measured: GX3 red on correct
  # code). So: the first occurrence whose next non-blank character opens a
  # block.
  set i -1
  while {1} {
    set i [string first $sig $src [expr {$i + 1}]]
    if {$i < 0} { return "" }
    set after [string trimleft [string range $src \
                 [expr {$i + [string length $sig]}] [expr {$i + [string length $sig] + 40}]]]
    if {[string index $after 0] eq "\{"} { break }
  }
  set rest [string range $src $i end]
  # ⚠ the close brace below is BACKSLASH-ESCAPED, and so is every one in this
  # proc's comments: Tcl counts braces inside a braced body regardless of
  # quoting or comments, so a bare one here ends the proc early
  # ("extra characters after close-brace", measured twice while writing this).
  set j [string first "\n\}" $rest]
  if {$j < 0} { return $rest }
  return [string range $rest 0 $j]
}
set hc_cb [hc_src [file join $hc_repo src callback.c]]
set hc_dr [hc_src [file join $hc_repo src draw.c]]
set hc_sc2 [hc_src [file join $hc_repo src scheduler.c]]
set hc_xi [hc_src [file join $hc_repo src xinit.c]]

if {$hc_cb eq "" || $hc_dr eq "" || $hc_sc2 eq "" || $hc_xi eq ""} {
  hc_skip "GX* the has_x guards are conditional" \
    "src/*.c not readable from [file join $hc_repo src] (not a checkout?)"
} else {
  # GX1 -- 0227's guard is at the CALL SITE and tests has_x. `if(0)` or a
  # deleted call kills the statusbar for every GUI user and no headless row sees it.
  check "GX1 update_statusbar is called under has_x, not unconditionally and not never" \
    [regexp {if\(has_x\) update_statusbar\(persistent_command, wire_draw_active\);} $hc_cb] 1
  # GX2..GX5 -- the four drawing/gesture entry guards, each inside ITS OWN
  # function body, each testing has_x.
  check "GX2 draw_crosshair()'s entry guard is has_x" \
    [regexp {if\(!has_x\) return;} [hc_body $hc_cb "void draw_crosshair(int what, int state)"]] 1
  check "GX3 draw_snap_cursor()'s entry guard is has_x" \
    [regexp {if\(!has_x\) return;} [hc_body $hc_cb "static void draw_snap_cursor(int action)"]] 1
  check "GX4 handle_expose()'s entry guard is has_x" \
    [regexp {if\(!has_x\) return;} [hc_body $hc_cb "static void handle_expose(int mx,int my,int button,int aux)"]] 1
  check "GX5 waves_callback()'s entry guard is has_x (fix round)" \
    [regexp {if\(!has_x\) return 0;} [hc_body $hc_cb \
       "static int waves_callback(int event, int mx, int my, KeySym key, int button, int aux, int state)"]] 1
  # GX6 -- all three stipple loops of the Ctrl-'=' toggle, and NOT the
  # fill_pattern state above them, which must still change with no display.
  check "GX6 the three Ctrl-'=' XSetFillStyle loops are under has_x" \
    [regexp -all {if\(has_x\) for\(x=0;x<cadlayers;} $hc_cb] 3
  # GX7 -- the Print key must not arm GRABSCREEN with no display, and
  # GX8 -- grabscreen() must DISARM rather than return with the bit set. Two
  # rows because either one alone still leaves an editor that swallows events.
  check "GX7 the XK_Print key arms GRABSCREEN only under has_x" \
    [regexp {if\(has_x\) \{\s*\n\s*xctx->ui_state \|= GRABSCREEN;} $hc_cb] 1
  check "GX8 grabscreen() CLEARS the armed bit when there is no display" \
    [regexp {if\(!has_x\) \{\s*\n\s*xctx->ui_state &= ~GRABSCREEN;\s*\n\s*return 0;} $hc_dr] 1
  # GX9 -- the shared refusal is conditional. A `scheduler_needs_x_reject()`
  # that always rejected would break five verbs for every GUI user; the
  # anti-hollow row for that lives on the display arm, which T1 does not run, so
  # this is T1's only sight of it.
  check "GX9 scheduler_needs_x_reject() returns 0 when has_x is 1" \
    [regexp {if\(has_x\) return 0;} [hc_body $hc_sc2 \
       "static int scheduler_needs_x_reject(Tcl_Interp \*interp, const char \*subcmd)"]] 1
  # GX10..GX12 -- the three xinit.c function guards added by the fix round.
  check "GX10 toggle_fullscreen()'s entry guard is has_x (the keyboard route)" \
    [regexp {if\(!has_x\) return;} [hc_body $hc_xi "void toggle_fullscreen(const char *topwin)"]] 1
  check "GX11 windowid()'s entry guard is has_x" \
    [regexp {if\(!has_x\) return;} [hc_body $hc_xi "void windowid(const char *win_path)"]] 1
  check "GX12 preview_window()'s entry guard is has_x, and is before the semaphore" \
    [regexp {if\(!has_x\) return 0;(.|\n)*if\(semaphore\) return 0;} \
       [hc_body $hc_xi "int preview_window(const char *what, const char *win_path, const char *fname)"]] 1
  # GX13 -- fill_type keeps its display-free half. A refusal here would pass
  # every liveness row above while removing work psprint.c and svgdraw.c do.
  check "GX13 fill_type guards the GC rebuild instead of refusing the verb" \
    [expr {[regexp {if\(has_x\) \{\s*\n\s*free_gc\(\);\s*\n\s*create_gc\(\);} $hc_sc2] &&
           ![regexp {scheduler_needs_x_reject\(interp, "fill_type"\)} $hc_sc2]}] 1
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
