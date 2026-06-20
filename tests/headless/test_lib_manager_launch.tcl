# Library Manager launch behavior (specs/library_manager_launch.md):
#   - `xschem library_manager` opens the window (replayable / bindable command)
#   - it is a SINGLE window: a second launch raises+focuses, never rebuilds
#   - a re-launch deiconifies a minimized window
#   - the launch_library_manager rc flag defaults off; the raw proc still works
#   - the Tools menu is wired to the logged command
#
# Needs X (creates toplevels). Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_lib_manager_launch.tcl

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
# (specs/library_manager_launch.md).

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

catch {destroy .libmgr}
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
