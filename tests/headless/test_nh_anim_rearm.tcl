# Net highlight animation — re-arm from WITHIN a callback (semaphore held) must NOT freeze the tick.
#
# Bug (user report): with an animated highlight visible (blink / marching ants), applying a highlight
# interactively — press 9 with nothing selected (verb-noun), then click a wire; or the plain `k`
# highlight key — gives a STATIC highlight and FREEZES the existing animations. The animation only
# resumes after switching schematic level (descend/ascend). Root cause: the whole GUI callback runs
# with xctx->semaphore held (callback.c), so when the highlight path re-arms the tick via
# net_hilight_anim_update(), net_hilight_has_animation() sees net_hilight_ctx_busy() (semaphore) and
# returns 0 — the Tcl net_hilight_anim_update then CANCELS the tick instead of arming it, and nothing
# re-arms it until a later (semaphore-free) anim_update on a level switch.
#
# This test drives the REAL `xschem callback` event (so the semaphore is held exactly as in interactive
# use) and asserts the animation tick survives. The trigger is the `k` highlight key on a selected wire
# (coordinate-free → a guaranteed hit; same root cause as the verb-noun click, which also routes through
# net_hilight_anim_update() mid-callback).
#
# GUI only (a real Tk event loop is required for the `after`-based tick):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_anim_rearm.tcl

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }

set win .drw

# count animation-tick fires (wrap the tick proc) and count re-arm invocations (wrap the update proc)
set ::ticks 0
if {[llength [info commands net_hilight_anim_tick]] && ![llength [info commands net_hilight_anim_tick_real]]} {
  rename net_hilight_anim_tick net_hilight_anim_tick_real
  proc net_hilight_anim_tick {win} { incr ::ticks; net_hilight_anim_tick_real $win }
}
set ::rearms 0
if {[llength [info commands net_hilight_anim_update]] && ![llength [info commands net_hilight_anim_update_real]]} {
  rename net_hilight_anim_update net_hilight_anim_update_real
  proc net_hilight_anim_update {win} { incr ::rearms; net_hilight_anim_update_real $win }
}

# a blinking style at index 0 so the highlighted net animates; a wire highlighted via the style cursor
set ::net_hilight_style {{0 4 2 {} 0 400 none 0}}
catch {xschem update_net_hilight_style}
xschem clear force ; xschem set_modify 0
xschem wire 0 0 200 0
xschem unselect_all ; xschem select wire 0 ; xschem hilight
catch {xschem net_hilight_anim_update_all}
update idletasks

check "R1 animated highlight present + tick armed" \
  [expr {[xschem get net_hilight_animated $win] == 1 && [info exists ::net_hilight_after($win)]}] \
  "(animated=[xschem get net_hilight_animated $win] after=[array names ::net_hilight_after])"

# sanity (not green-but-hollow): the tick really fires before we perturb it
set ::ticks 0
after 700 {set ::s1 1} ; vwait ::s1
check "R2 tick fires while idle (harness genuinely animates)" [expr {$::ticks > 0}] "(ticks=$::ticks)"

# --- apply a highlight INTERACTIVELY (mid-callback, semaphore held) via the real callback event ---
xschem unselect_all ; xschem select wire 0
set ::rearms 0
# event 2 = KeyPress; keysym 107 = 'k' (hilight.highlight_selected_net_pins). Routed through callback(),
# which holds xctx->semaphore for the whole event, so this exercises the re-arm-under-semaphore path.
catch {xschem callback $win 2 100 100 107 0 0 0}
update idletasks

check "R3 the highlight re-armed the tick during the callback" [expr {$::rearms >= 1}] "(rearms=$::rearms)"
check "R4 tick is STILL armed after the interactive highlight" [expr {[info exists ::net_hilight_after($win)]}] \
  "(after=[array names ::net_hilight_after])"
check "R5 highlight still animating (style present)" [expr {[xschem get net_hilight_animated $win] == 1}] \
  "(animated=[xschem get net_hilight_animated $win])"

# behavioral: the animation keeps running (does not freeze) after the interactive highlight
set ::ticks 0
after 700 {set ::s2 1} ; vwait ::s2
check "R6 tick keeps firing after the interactive highlight (NOT frozen)" [expr {$::ticks > 0}] "(ticks=$::ticks)"

catch {xschem unhilight_all}
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
