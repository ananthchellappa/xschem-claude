# Issue 0025: closing a real (detached) window while in tabbed mode must return to the
# tab the user came from, not unconditionally the main window. destroy_tab consults
# tab_queue PREVIOUS; destroy_window did not, so a cross-kind close (close a window
# while a tab was the prior context) dropped the user on .drw.
#
# RED before fix: after closing the focused window, current context is .drw.
# GREEN after fix: current context is the previously-active tab (.x1.drw).
#
# Needs X. Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_close_window_restores_prev_tab.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {n} { global repo; return [file join $repo xschem_library examples $n] }

set ::tabbed_interface 1
catch {xschem new_schematic destroy_all {}}
xschem load [ex nand2.sch]              ;# main .drw (a tab in tabbed mode)
xschem new_schematic create .x1 [ex dlatch.sch]        ;# a TAB sharing the main canvas
xschem new_schematic create_window .x2 [ex flop.sch]   ;# a real WINDOW
update idletasks

# be on the tab, then move to the window (this is the context the user "came from")
xschem new_schematic switch .x1.drw
update idletasks
check "CW0 on the tab before opening the window" \
  [expr {[xschem get current_win_path] eq {.x1.drw}}] "(cur=[xschem get current_win_path])"

xschem new_schematic switch .x2.drw
update idletasks
check "CW1 on the window after switching to it" \
  [expr {[xschem get current_win_path] eq {.x2.drw}}] "(cur=[xschem get current_win_path])"

# close the focused window -> should return to the tab (.x1.drw), not main (.drw)
xschem new_schematic destroy .x2.drw {}
update idletasks
check "CW2 closing the window returns to the previously-active tab, not main" \
  [expr {[xschem get current_win_path] eq {.x1.drw}}] \
  "(cur=[xschem get current_win_path] want .x1.drw)"
check "CW2b the window's toplevel is gone (no zombie)" \
  [expr {![winfo exists .x2]}] "(.x2 exists=[winfo exists .x2])"

catch {xschem new_schematic destroy_all {}}
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
