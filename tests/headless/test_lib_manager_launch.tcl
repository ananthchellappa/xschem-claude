# Library Manager launch behavior (doc/claude/specs/library_manager_launch.md):
#   - `xschem library_manager` opens the window (replayable / bindable command)
#   - it is a SINGLE window: a second launch raises+focuses, never rebuilds
#   - a re-launch deiconifies a minimized window
#   - the launch_library_manager rc flag defaults off; the raw proc still works
#   - the Tools menu is wired to the logged command
#
# Needs X (creates toplevels). Run under X with --pipe from src/:
#   ./xschem --pipe -q --script ../tests/headless/test_lib_manager_launch.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

catch {destroy .libmgr}

# LL1 — the command opens the window
xschem library_manager
update idletasks
check "LL1 xschem library_manager opens .libmgr" [winfo exists .libmgr] {}

# LL2 — a second launch does not rebuild the window (same X id => raised, not recreated)
set id1 [winfo id .libmgr]
xschem library_manager
update idletasks
check "LL2 single window: same window id on re-launch" \
  [expr {[winfo exists .libmgr] && [winfo id .libmgr] eq $id1}] "(=> $id1 / [winfo id .libmgr])"

# NOTE — window-manager behaviors (deiconify, raise, and especially grabbing
# keyboard focus across toplevels when another window such as the CIW is active)
# are deliberately NOT asserted here. Under WSLg/Xvfb a scripted new toplevel is
# auto-focused/auto-mapped by the WM regardless of whether the code calls
# focus/deiconify at all (verified: the assertions pass even with the fix
# removed), so they cannot tell the bug from the fix. The code uses
# `focus -force` + `wm deiconify` + `raise` (libmgr::raise_to_front) on BOTH the
# create and raise paths; that cross-window focus is a manual eyeball item
# (doc/claude/specs/library_manager_launch.md).

# LL5 — the autostart flag exists and defaults off
check "LL5 launch_library_manager defaults to 0" \
  [expr {[info exists ::launch_library_manager] && $::launch_library_manager == 0}] "(=> [set ::launch_library_manager])"

# LL6 — the raw Tcl proc still opens the window (back-compat entry point)
destroy .libmgr; update
library_manager
update idletasks
check "LL6 raw 'library_manager' proc still opens the window" [winfo exists .libmgr] {}

# LL7 — the Tools menu entry is wired to the logged command
set m .menubar.tools
set cmd {}
if {[winfo exists $m]} {
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {![catch {$m entrycget $i -label} lbl] && $lbl eq "Library Manager"} { set cmd [$m entrycget $i -command] }
  }
}
check "LL7 Tools menu wired to 'xschem library_manager'" [expr {$cmd eq {xschem library_manager}}] "(=> '$cmd')"

# LL8 — issue 0831: the optional lcv argument must not EXECUTE.
# `scheduler.c:8097` builds the call by C string concatenation:
#     tclvareval("libmgr::open {", argv[2], "}", NULL);
# so a `}` in the argument closes the brace group and everything after it parses
# as script. ⚠ 0831 §3 is binding: this is NOT "protected because libmgr::open
# errors on wrong args" — a wrong-args abort is an accident of payload shape,
# and the payload below is shaped for the sink. Measured at head on the dev
# display: the host file is created and the verb ANSWERS `y`, the payload's own
# `list {y}` tail, which is the receipt that the argument was parsed as SCRIPT.
# The host file lives outside the repo so nothing is left behind either way.
#
# ⚠ ANTI-HOLLOW (issue 0828): the positive twin is LL9 below, NOT LL1.
# This comment used to name LL1 and that was WRONG, disproved by sabotage
# (issue 0835): LL1 and LL6 launch with NO argument, so they take scheduler.c's
# untouched `else tcleval("libmgr::open")` branch and never reach the converted
# `tcl_call("libmgr::open", argv[2], ...)`. Measured: with that call gutted to a
# no-op the whole file still scored RESULT: ALL PASS. A negative row plus a
# same-file positive row that exercises a DIFFERENT branch is not anti-hollow
# coverage — name the row that drives the converted path, not the nearest
# green one.
#
# ⚠ WHAT THIS ROW DOES NOT COVER: the SAME branch also writes an UNGUARDED
# action-log line, `log_action("xschem library_manager {%s}", argv[2])`
# (scheduler.c:8096), and the action log is a replayable Tcl script by design —
# its four siblings are `tcl_braceable()`-guarded and this one is not. That is a
# separate finding (issue 0832) and LL8 asserts nothing about it.
set LL_TMPD [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : "/tmp"}]
set LL_H [file join $LL_TMPD "HOST_LL8_[pid]"]
catch {file delete -force $LL_H}
set ::SC_PWNED 0
set LL_PAY "x\} ; set ::SC_PWNED 1; exec touch $LL_H; list \{y"
catch {xschem library_manager $LL_PAY} LL_R
update idletasks
set LL_E [file exists $LL_H]
catch {file delete -force $LL_H}
check "LL8 library_manager lcv argument does not execute (0831, scheduler.c:8097)" \
  [expr {$::SC_PWNED == 0 && $LL_E == 0}] \
  "(=> pwned=$::SC_PWNED host=$LL_E answer='$LL_R')"

# LL9 — issue 0835: THE POSITIVE TWIN FOR THE CONVERTED ARGUMENT PATH.
# LL8 proves the lcv argument does not EXECUTE; this proves it still ARRIVES.
# `xschem library_manager {lib cell view}` must reach `libmgr::open` with the
# list intact and pre-select all three panes (libmgr::open -> libmgr::locate).
# Nothing else in the repo drives the argument form of this verb: every other
# call site, here and in test_action_log_libmgr, launches bare. Without this row
# a misspelled proc name or a dropped argument at scheduler.c:8109 is invisible.
# NOTE the registry: the launch suite's default `library_defs_registry` is EMPTY,
# so this row points XSCHEM_LIBRARY_DEFS at the in-repo OA registry the way
# test_lib_manager_locate.tcl does, and restores both globals afterwards.
set LL_SAVE_DEFS [expr {[info exists ::XSCHEM_LIBRARY_DEFS] ? $::XSCHEM_LIBRARY_DEFS : {}}]
set LL_SAVE_ONLY [expr {[info exists ::library_registry_defs_only] ? $::library_registry_defs_only : {}}]
set LL_REPO [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]
set ::XSCHEM_LIBRARY_DEFS [file join $LL_REPO xschem_libraries_oa library.defs]
set ::library_registry_defs_only 1
set LL_LIB  [lindex [dict keys [library_defs_registry]] 0]
set LL_CELL [lindex [xschem lib_cells $LL_LIB] 0]
set LL_VIEW [lindex [xschem cell_views $LL_LIB $LL_CELL] 0]
catch {destroy .libmgr}; update
xschem library_manager [list $LL_LIB $LL_CELL $LL_VIEW]
update
set LL_S1 [.libmgr.pw.lib.lb selection]
set LL_S2 [.libmgr.pw.cell.lb selection]
set LL_S3 [.libmgr.pw.view.lb selection]
check "LL9 library_manager lcv argument still ARRIVES and pre-selects (0835)" \
  [expr {$LL_LIB ne {} && $LL_S1 eq $LL_LIB && $LL_S2 eq $LL_CELL && $LL_S3 eq $LL_VIEW}] \
  "(=> got $LL_S1/$LL_S2/$LL_S3 want $LL_LIB/$LL_CELL/$LL_VIEW)"
if {$LL_SAVE_DEFS eq {}} { catch {unset ::XSCHEM_LIBRARY_DEFS} } else { set ::XSCHEM_LIBRARY_DEFS $LL_SAVE_DEFS }
if {$LL_SAVE_ONLY eq {}} { catch {unset ::library_registry_defs_only} } else { set ::library_registry_defs_only $LL_SAVE_ONLY }

catch {destroy .libmgr}
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
