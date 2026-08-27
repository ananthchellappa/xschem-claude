# A waveform viewer owns its window title (issue 0851).
#
# set_modify() re-derives a toplevel's title from the schematic name. A viewer's buffer
# IS `untitled.sch` by construction, so any code path that lands set_modify() on a viewer
# context renames "Waveforms <cell> (<state>)" to "xschem [N] - untitled.sch (read-only)".
#
# The user hit this and reported it as "there is no waveform window" -- exactly right:
# the window was on screen, mapped, on top, and no longer said it was a waveform window.
# Their action log caught it in two window_report censuses 700ms apart, the first with
# the viewer title and the second with the derived one.
#
# It surfaced with issue 0848: before that fix the redraw-only restore hit switch_window's
# "already there" early return and never reached set_modify(-1); once the forward switch
# really happened the restore had somewhere to come back FROM, and clobbered the title.
#
# ⚠ THE TRIGGER IS NOT `xschem set_modify`. Measured, with the guard removed and the
# viewer context asserted current: driving that verb at -1, 0, 1, 2 and 3 never changes
# the title. The clobber comes from callback()'s Expose handling -- the redraw-only
# switch to another window and the restore back. So this suite delivers a real Expose.
#
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_viewer_title.tcl

set ::fail 0
proc check {n ok {d {}}} {
  if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d" ; incr ::fail }
}
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; real toplevels are the subject)" ; flush stdout ; exit 0 }

source [file join [file dirname [info script]] scratch.tcl]
set dir [test_scratch vtitle]
set libs [glob -nocomplain [file join [pwd] xschem_library * *.sch]]
if {[llength $libs] < 1} { set libs [glob -nocomplain [file join [pwd] xschem_library *.sch]] }
set fa [file join $dir a.sch]
file copy -force [lindex $libs 0] $fa
proc pump {ms} { for {set i 0} {$i < $ms} {incr i 50} { update ; after 50 } }

xschem load $fa
pump 300

# a second real window, branded a viewer and titled like one
set before [winfo children .]
xschem load_new_window -window {}
pump 400
set vtop {}
foreach t [winfo children .] {
  if {[lsearch -exact $before $t] >= 0} continue
  if {[winfo exists $t.drw]} { set vtop $t }
}
check "T1 a second real window exists" [expr {$vtop ne {}}] "(=> $vtop)"
if {$vtop eq {}} { puts "RESULT: $::fail FAILED" ; flush stdout ; exit 1 }
set vdrw $vtop.drw
xschem set wave_viewer 1
check "T2 ... and it is branded a waveform viewer" [expr {[xschem get wave_viewer] == 1}]
set want {Waveforms probe_cell (ngspice_state1)}
wm title $vtop $want
pump 200
check "T3 the viewer carries its own title" [expr {[wm title $vtop] eq $want}] "(=> [wm title $vtop])"

# ⚠ PRECONDITION AS A ROW: if the viewer context is not current, the restore below lands
# somewhere else and the check passes while measuring nothing.
catch {xschem new_schematic switch $vdrw}
set ctx {}
catch {set ctx [xschem get current_win_path]}
check "T4 (PRECONDITION) the viewer context is current, so the restore lands on it" \
  [expr {$ctx eq $vdrw}] "(=> $ctx)"

# THE REAL PATH: an Expose on the DESIGN canvas while the viewer context is current makes
# callback() switch to the design window for a redraw and then restore -- and the restore
# lands set_modify(-1) on the viewer. Event type 12 == Expose.
catch {xschem callback .drw 12 0 0 0 [winfo width .drw] [winfo height .drw] 0}
pump 400
check "T5 THE ROW: an Expose-driven redraw-only switch LEAVES the viewer title alone" \
  [expr {[wm title $vtop] eq $want}] "(=> [wm title $vtop])"

# POSITIVE TWIN: the guard is about VIEWERS. An ordinary window must still get its title
# derived, or the fix has simply turned titling off everywhere.
#
# ⚠ IT HAS TO FORCE A RE-DERIVE, not read a title that is already right. Reading it
# straight after the switch passes even when the guard is widened to every window --
# measured -- because nothing recomputed it. So: corrupt the title, then run the SAME
# Expose path in the other direction (an Expose on the VIEWER canvas while the DESIGN
# context is current lands the restore's set_modify(-1) on the design window).
catch {xschem new_schematic switch .drw}
pump 200
set ctx2 {}
catch {set ctx2 [xschem get current_win_path]}
check "T6 (PRECONDITION) the design context is current" [expr {$ctx2 eq {.drw}}] "(=> $ctx2)"
wm title . {ZZ-not-a-real-title}
pump 200
catch {xschem callback $vdrw 12 0 0 0 [winfo width $vdrw] [winfo height $vdrw] 0}
pump 400
check "T6 POSITIVE TWIN: an ordinary window's title IS still re-derived" \
  [string match {xschem*} [wm title .]] "(=> [wm title .])"

puts [expr {$::fail == 0 ? "RESULT: ALL PASS (7 checks)" : "RESULT: $::fail FAILED"}]
flush stdout
exit [expr {$::fail != 0}]
