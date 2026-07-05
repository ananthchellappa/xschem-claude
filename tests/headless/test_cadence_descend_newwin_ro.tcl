# Ctrl-Shift-X: descend into the ONE selected instance's schematic view in a NEW
# window, read-only -- the E-dialog "New Window" path (cadence::descend_into_inst_newwin_ro).
# See doc/claude/specs/cadence_descend_newwin_ro.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_cadence_descend_newwin_ro.tcl
#
# Reuses the hi_descend fixture (top.sch with instance x1 that has a schematic view).
# The exactly-one-instance GATE and the read-only new-window descend are both scriptable
# headless (the new-window descend is already exercised by SELNW in test_hi_descend.tcl).

set here    [file normalize [file dirname [info script]]]
set utils   [file normalize [file join $here .. .. utils]]
set fixroot [file normalize [file join $here fixtures hi_descend]]
set lib     [file join $fixroot hidlib]
lappend pathlist $lib                 ;# register hidlib (lib/cell/view layout) via auto-discovery
set top     [file join $lib top schematic top.sch]

if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils cadence_nav.tcl]

set fails 0
proc check {name ok detail} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name $detail"; flush stdout
  if {!$ok} {incr ::fails}
}
proc schname {} { return [xschem get schname] }
proc has {needle} { return [expr {[string first $needle [schname]] >= 0}] }
# reload top fresh, close any windows a prior subtest opened, clear selection/override
proc reload {} {
  global top
  catch {xschem new_schematic destroy_all force}
  set ::hi_descend_view_path {}
  xschem load $top
  xschem unselect_all
}

# --- GATE-none: nothing selected -> silent no-op (no window, no descend) ----------
reload
set w0 [llength [xschem windows]]
cadence::descend_into_inst_newwin_ro
check "GATE-none nothing selected is a no-op" \
  [expr {[llength [xschem windows]] == $w0 && [xschem get currsch] == 0 && [has top.sch]}] \
  "(wins=$w0->[llength [xschem windows]] currsch=[xschem get currsch] name=[schname])"

# --- GATE-multi: instance + wire selected -> no-op (needs EXACTLY one instance) ----
reload
set w0 [llength [xschem windows]]
xschem select instance x1 fast
xschem select wire 0 fast
cadence::descend_into_inst_newwin_ro
check "GATE-multi instance+wire selection is a no-op" \
  [expr {[llength [xschem windows]] == $w0 && [xschem get currsch] == 0 && [has top.sch]}] \
  "(wins=$w0->[llength [xschem windows]] currsch=[xschem get currsch] name=[schname])"

# --- DESCEND: exactly one instance -> new window, REAL descend, read-only ----------
reload
set w0 [llength [xschem windows]]
xschem select instance x1 fast
cadence::descend_into_inst_newwin_ro
check "DESCEND opens a NEW window" \
  [expr {[llength [xschem windows]] == $w0 + 1}] \
  "(wins=$w0->[llength [xschem windows]])"
check "DESCEND is a REAL descend into x1's schematic" \
  [expr {[xschem get currsch] == 1 && [xschem get sch_path] eq {.x1.} && [has /schematic/leaf.sch]}] \
  "(currsch=[xschem get currsch] path=[xschem get sch_path] name=[schname])"
check "DESCEND child is READ-ONLY" \
  [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"
catch {xschem new_schematic destroy_all force}

puts "cadence_descend_newwin_ro headless: [expr {$fails ? "$fails FAILURE(S)" : {all checks passed}}]"
