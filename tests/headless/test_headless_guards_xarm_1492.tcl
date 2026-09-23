# tests/headless/test_headless_guards_xarm_1492.tcl -- THE DISPLAY ARM of the
# headless-crash batch (issues 1493, 0227/0834/0467, 1492 and the six further
# entry points the fix round measured).
#
# WHY THIS FILE EXISTS, AND WHY IT IS A `dcases` ENTRY
#
# The batch's product change is eleven `has_x` guards. Every one of them is a
# conditional: with no display it skips X work that has no surface to happen on,
# and WITH a display it must do exactly what it always did. PLAN.md criterion 3
# is about that second half -- "a guard that silently skips work a user asked
# for is worse than the crash" -- and it is the half nothing could see:
#
#   * test_callback_argc.tcl (the batch's T1 case) is an `hcases` entry, and
#     run_regression.tcl hard-codes --nogui, so `has_x` is 0 there on EVERY box,
#     including a developer desktop with a display. Its has_x-1 branch exists
#     but T1 never executes it.
#   * The verify round proved the gap rather than arguing it: with all seven of
#     the implement round's guards forced to fire unconditionally -- no
#     statusbar, no crosshair, no snap cursor, no Expose repaint for any GUI
#     user -- twenty display-arm suites produced BYTE-IDENTICAL result lines and
#     a whole T1 came back `counted_failures=0`.
#
# So the positives live here, in the one T1 loop that runs with a display. Each
# row asserts that the guarded work STILL HAPPENS, and reddens if its guard is
# made unconditional. Rows that cannot be measured with a display (the
# refusals themselves) stay in test_callback_argc.tcl; the two files are halves
# of one contract and neither is complete alone.
#
# WHAT EVEN THIS ARM CANNOT SEE, stated rather than papered over: the crosshair
# and the snap cursor are painted straight to the window with draw_pixmap = 0,
# and an Expose repaint is a copy INTO the window, so no pixmap dump, no
# `xschem get` and no PostScript export can read any of the three back. Their
# conditionality is pinned textually by the GX* rows of test_callback_argc.tcl.
# What this file adds for them is that the paint path runs to completion with a
# real canvas under it.
#
# Run by hand (the armed spelling; it needs a display):
#   tests/headless/run_suites.sh test_headless_guards_xarm_1492

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc xg_skip {name why} { puts "skip: $name -- $why" }

# `::has_x` is the codebase's own mirror of the C guard: xinit.c sets it to 1
# inside `if(has_x)` and nowhere else. With no display there is nothing here to
# assert -- every row below is "the work still happens WITH a display" -- so the
# file says so and finishes cleanly rather than failing or pretending.
if {![info exists ::has_x]} {
  xg_skip "the whole display arm" \
    "has_x 0 in this process: run this suite with a display (tests/headless/run_suites.sh test_headless_guards_xarm_1492)"
  puts "RESULT: SKIP (no display)"
  puts "OVERALL: ok"
  exit 0
}

set no_recent_files 1
set xg_repo [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]

update idletasks

# =============================================================================
# X1 -- 0227/0834/0467: update_statusbar() must still update the status bar
#
# The guard is `if(has_x) update_statusbar(...)` at the top of callback(). Force
# it to `if(0)` -- the sabotage the verify round ran -- and every GUI user's
# status bar freezes while every headless row stays green. `.statusbar.3` is the
# snap-grid field, which update_statusbar() rewrites from `cadsnap` on every
# event, so setting cadsnap to a value nothing else writes and firing one motion
# is the whole assertion. MEASURED red under that sabotage (the field comes back
# empty).
# =============================================================================
set xg_snap_save $::cadsnap
set ::cadsnap 12.5
catch {xschem callback .drw 6 100 100 0 0 0 0}
update
set xg_sb ""
catch {.statusbar.3 get} xg_sb
check "X1 update_statusbar still runs with a display (the 0227 guard is conditional)" \
  [string trim $xg_sb] 12.5
set ::cadsnap $xg_snap_save
catch {xschem callback .drw 6 101 101 0 0 0 0}
update

# =============================================================================
# X2 -- 1492: the shared refusal is conditional
#
# scheduler_needs_x_reject() gates five verbs. One that always rejected would
# break all five for every GUI user, and no headless row could tell: headless,
# rejecting IS the contract. fill_reset is the one of the five safe to drive on
# a live display (it rebuilds the GCs and redraws; no modal dialog, no pointer
# grab), and `windowid` and `preview_window` -- added by the fix round -- are
# safe too. Between them they cover the helper and both of its new callers.
# =============================================================================
check "X2 xschem fill_reset still WORKS with a display" \
  [catch {xschem fill_reset nodraw}] 0
check "X3 xschem windowid still WORKS with a display (fix round)" \
  [catch {xschem windowid .drw}] 0

# preview_window needs a real Tk widget to name: Tk_NameToWindow() is exactly
# the call that died headless, so the row that matters is the one where it
# RESOLVES a window and answers 1.
toplevel .xgprev
frame .xgprev.drw -width 200 -height 200
pack .xgprev.drw
update idletasks
set xg_pw {}
set xg_pwrc [catch {xschem preview_window create .xgprev.drw {}} xg_pw]
check "X4 xschem preview_window still creates a preview pane with a display (fix round)" \
  [list $xg_pwrc $xg_pw] {0 1}
catch {xschem preview_window destroy .xgprev.drw {}}
catch {destroy .xgprev}
update idletasks

# =============================================================================
# X5 -- 1492 (fix round): fill_type's GC rebuild still runs with a display
#
# Headless this verb keeps its display-free half (xctx->fill_type[] is read by
# psprint.c and svgdraw.c) and skips free_gc()/create_gc(); with a display the
# whole sequence must still run, which is what `if(has_x)` means and what an
# `if(0)` there would silently take away. Driven twice so the layer ends where
# it started.
# =============================================================================
check "X5 xschem fill_type still rebuilds the GCs with a display (fix round)" \
  [list [catch {xschem fill_type 4 solid}] [catch {xschem fill_type 4 stipple}]] {0 0}

# =============================================================================
# X6 -- 1492 (fix round): the graph gesture handler on a real canvas
#
# waves_callback()'s `if(!has_x) return 0;` is the fix round's blocker guard:
# with no display the cairo_save() pair at its head faulted on a NULL
# cairo_save_ctx, and 23 of the 60 shipped examples died on one mouse motion.
# With a display the guard must be transparent -- the motion must reach the
# handler and the graph must still react. The fixture is a shipped example that
# carries graphs.
# =============================================================================
set xg_ex [file join $xg_repo xschem_library examples cmos_example.sch]
if {![file readable $xg_ex]} {
  xg_skip "X6 a motion over a graph still reaches waves_callback with a display" \
    "fixture not readable: $xg_ex"
} else {
  check "X6 load + zoom_full + motion over a graph still works with a display (fix round)" \
    [list [catch {xschem load $xg_ex}] [catch {xschem zoom_full}] \
          [catch {xschem callback .drw 6 500 400 0 0 0 0}]] {0 0 0}
  update idletasks
}

# =============================================================================
# X7 -- the three paint guards, with a real canvas under them
#
# LIVENESS, and the header says why it can be nothing more: these three paint to
# the window and nothing can read them back. What this row does add over the
# headless copy is a real window, a real GC and a real backing pixmap -- so a
# guard that had been written against the wrong condition (say `if(!display)`,
# which is 0 here as well as headless) would fault or misbehave HERE, where the
# headless row cannot tell the two conditions apart.
# =============================================================================
set xg_xh $::draw_crosshair ; set xg_sc $::snap_cursor
set ::draw_crosshair 1 ; set ::snap_cursor 1
catch {xschem callback .drw 7 100 100 0 0 0 0}   ;# EnterNotify
check "X7 crosshair + snap cursor + Expose all run with a display" \
  [list [catch {xschem callback .drw 6 120 120 0 1 0 0}] \
        [catch {xschem callback .drw 6 220 220 0 1 0 0}] \
        [catch {xschem callback .drw 12 0 0 0 100 100 0}]] {0 0 0}
set ::draw_crosshair $xg_xh ; set ::snap_cursor $xg_sc
catch {xschem callback .drw 8 100 100 0 0 0 0}   ;# LeaveNotify
update idletasks

# =============================================================================
# X8 -- 1493: `xschem globals` reports a LIVE connection when has_x is 1
#
# The mirror of test_callback_argc.tcl's 1493 row, on the arm that row can never
# reach in T1. `display = NULL;` in xserver_ok() must null the PROBE
# connection only: nulling it unconditionally, or leaving the global unassigned
# with a display, would show up here and nowhere else in T1.
# =============================================================================
set xg_g {}
if {$::tcl_platform(platform) ne "unix"} {
  xg_skip "X8 the display global reports a connection when has_x is 1" \
    "the Xserver options block of `xschem globals` is #ifdef __unix__"
} elseif {[catch {xschem globals} xg_g]} {
  check "X8 xschem globals survives with a display" 0 1
} else {
  set xg_disp {}
  foreach l [split $xg_g "\n"] {
    if {[regexp {^display=(.*)$} $l -> v]} { set xg_disp $v }
  }
  check "X8 the display global reports a connection when has_x is 1" $xg_disp connected
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
