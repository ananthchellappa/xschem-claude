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

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
