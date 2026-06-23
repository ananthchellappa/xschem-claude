# Issue 0021: handle_window_switching() must not dereference save_xctx[n] when n is
# out of range. get_tab_or_window_number() returns -1 for an unknown win_path; the
# widened switch condition (cur_is_real, with no n>0 guard) lets the EnterNotify path
# run in tabbed mode while a real (detached) window is current, reaching
# `save_xctx[n]->ui_state` with n == -1 -> out-of-bounds read.
#
# This fires an EnterNotify (event type 9) for a bogus, unregistered window path while
# a real window is the current context, and asserts the process survives and the
# current context is unchanged. (The unfixed read is an OOB access; whether it faults
# is allocator-dependent, so this primarily locks the safe post-fix behavior.)
#
# Needs X. Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_window_switch_bogus_enter.tcl

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
xschem load [ex nand2.sch]

# create a real window and make it the current context (cur_is_real == 1)
xschem new_schematic create_window .x1 [ex dlatch.sch]
update
xschem new_schematic switch .x1.drw
update
set before [xschem get current_win_path]

# EnterNotify (9) on a bogus, unregistered window path -> get_tab_or_window_number==-1
catch {xschem callback .bogus_nonexistent_xyz.drw 9 100 100 0 0 0 0} e
update

set after [xschem get current_win_path]
check "WSB1 process survived an EnterNotify on an unknown window path" \
  [expr {[string match {*.drw} $after]}] "(after=$after err={$e})"
check "WSB2 current context unchanged by a bogus enter event" \
  [expr {$after eq $before}] "(before=$before after=$after)"

catch {xschem new_schematic destroy_all {}}
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
