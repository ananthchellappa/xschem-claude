#
#  File: cadence_new_window.tcl
#
#  Headless regression for Ctrl-N -> "open a new blank editor window".
#  See doc/claude/specs/cadence_new_blank_window.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script cadence_new_window.tcl
#
#  Verifies the helper opens a fresh blank untitled window AND leaves the schematic
#  the user was in untouched (non-destructive). The key-press->helper and focus are
#  manual GUI.  (The `clone_canvas_bindings ... winfo` line under --nogui is a Tk-absent
#  artifact; the window is still created.)
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
set fix   [file join $here buried_hilight]

if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils cadence_nav.tcl]

set nfail 0
proc check {d g w} {
  global nfail
  if {$g eq $w} { puts "ok   - $d" } else { puts "$d (got '$g' want '$w'): FAIL" ; incr nfail }
}

cd $fix
xschem load {a.sch}
set orig [xschem get current_win_path]
check "start: original has a.sch (1 inst)" [xschem get instances] 1

cadence::new_blank_window

check "new window is current (not original)" \
      [expr {[xschem get current_win_path] ne $orig ? 1 : 0}] 1
check "new window is blank (0 insts)"        [xschem get instances]              0
check "new window is untitled.sch"           [file tail [xschem get schname]]    untitled.sch
check "two windows now"                      [llength [xschem windows]]          2

# A SECOND blank window must NOT collide with the unsaved untitled.sch above: it
# iterates to untitled-1.sch, a third to untitled-2.sch (issue 0056). All open at once.
cadence::new_blank_window
check "2nd blank window is untitled-1.sch"   [file tail [xschem get schname]]    untitled-1.sch
check "three windows now"                    [llength [xschem windows]]          3
cadence::new_blank_window
check "3rd blank window is untitled-2.sch"   [file tail [xschem get schname]]    untitled-2.sch
check "four windows now"                     [llength [xschem windows]]          4

# non-destructive: switch back to the original window, it must be unchanged
xschem new_schematic switch $orig
check "back in original window"              [xschem get current_win_path]       $orig
check "original still has a.sch (1 inst)"    [xschem get instances]              1
check "original still a.sch"                 [file tail [xschem get schname]]    a.sch

if {$nfail} { puts "cadence_new_window: $nfail check(s): FAIL" } \
else        { puts "cadence_new_window: all checks PASS" }
