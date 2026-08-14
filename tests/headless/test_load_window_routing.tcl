# `xschem load` window routing (doc/claude/specs/load_window_routing.md):
# an INTERACTIVE (-gui) open must not clobber an occupied editor window. It reuses
# the current window only when it is a pristine empty untitled scratch; otherwise
# it opens a new window. Bare `xschem load` (force) and scripted loads stay in
# place (the regression suite relies on that). `-window <winpath>` targets a
# specific existing window and prompts "Save changes?" if that window is modified.
#
# Needs X (creates windows). Run from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_load_window_routing.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {n} { global repo; return [file join $repo xschem_library examples $n] }
set ::tabbed_interface 1

# Configurable ask_save stub (the real dialog is GUI). save(1,0) reads its result:
# "" => Cancel (returns -1), "yes" => save, anything else ("no") => discard.
set ::answer no
set ::asks 0
proc ask_save {{msg {}} {cancel 1}} { incr ::asks; return $::answer }

proc names {} { return [lmap e [xschem windows] {file tail [lindex $e 4]}] }
proc winpath_of {tail} {
  foreach e [xschem windows] { if {[file tail [lindex $e 4]] eq $tail} { return [lindex $e 0] } }
  return {}
}
proc reset {} { catch {xschem new_schematic destroy_all {}}; update; xschem clear force; update }

# ---- LR1: occupied current window + -gui open -> NEW window, current untouched ----
reset
xschem load [ex nand2.sch]          ;# bare load fills the pristine untitled in place
update
check "LR1a current now holds a real cellview (nand2)" \
  [expr {[string match {*nand2.sch} [xschem get current_name]] && [llength [xschem windows]] == 1}] \
  "(name=[xschem get current_name])"
xschem load -gui [ex dlatch.sch]    ;# -gui into an OCCUPIED window -> new window
update
check "LR1b -gui open of occupied window creates a NEW window (nand2 preserved)" \
  [expr {[llength [xschem windows]] == 2 && [lsearch [names] nand2.sch] >= 0 \
         && [lsearch [names] dlatch.sch] >= 0}] \
  "(windows=[names])"

# ---- LR2: pristine untitled + -gui open -> REUSE in place (no new window) ----
reset
check "LR2a fresh state is a pristine untitled buffer" \
  [expr {[string match {untitled*} [xschem get current_name]] && [llength [xschem windows]] == 1}] \
  "(name=[xschem get current_name])"
xschem load -gui [ex nand2.sch]
update
check "LR2b -gui open of pristine untitled reuses it in place (still 1 window)" \
  [expr {[string match {*nand2.sch} [xschem get current_name]] && [llength [xschem windows]] == 1}] \
  "(name=[xschem get current_name] windows=[llength [xschem windows]])"

# ---- LR3: BARE load into an occupied window stays IN PLACE (routing must not leak) ----
# From LR2 state: current = nand2, one window. A bare load replaces it in place.
xschem load [ex dlatch.sch]
update
check "LR3 bare load of occupied window replaces in place (no new window)" \
  [expr {[string match {*dlatch.sch} [xschem get current_name]] && [llength [xschem windows]] == 1}] \
  "(name=[xschem get current_name] windows=[llength [xschem windows]])"

# ---- LR4: -window <winpath> loads into a specific existing (clean) window ----
reset
xschem load [ex nand2.sch]                 ;# window A (main) = nand2
xschem load_new_window -window [ex dlatch.sch]  ;# window B = dlatch (real top-level)
update
set bpath [winpath_of dlatch.sch]
check "LR4a two windows exist, B path resolved" \
  [expr {[llength [xschem windows]] == 2 && $bpath ne {}}] "(B=$bpath windows=[names])"
set ::asks 0
xschem load -window $bpath [ex nand2.sch]  ;# target B (clean) -> loads nand2 into B
update
check "LR4b -window clean target: no save prompt, still 2 windows" \
  [expr {$::asks == 0 && [llength [xschem windows]] == 2}] "(asks=$::asks windows=[names])"
check "LR4c both windows now hold nand2 (B was retargeted, none created/destroyed)" \
  [expr {[llength [lsearch -all [names] nand2.sch]] == 2}] "(windows=[names])"

# ---- LR5: -window on a MODIFIED target pops "Save changes?"; Cancel ABORTS ----
reset
xschem load [ex nand2.sch]                      ;# window A = nand2
xschem load_new_window -window [ex dlatch.sch]  ;# window B = dlatch
update
set bpath [winpath_of dlatch.sch]
# dirty B: switch to it, draw, switch back to A
xschem new_schematic switch $bpath
xschem wire 100 100 200 100
check "LR5a target window B is modified" [expr {[xschem get modified] == 1}] {}
set apath [winpath_of nand2.sch]
xschem new_schematic switch $apath
# Cancel the save prompt -> load must abort, B untouched, focus back on A
set ::answer {}
set ::asks 0
xschem load -window $bpath [ex nand2.sch]
update
check "LR5b modified target -> save prompt fired" [expr {$::asks == 1}] "(asks=$::asks)"
check "LR5c Cancel aborts: B still dlatch and still modified" \
  [expr {[string match {*dlatch.sch} [lindex [lsearch -inline -index 0 [xschem windows] $bpath] 4]] \
         && [llength [xschem windows]] == 2}] \
  "(windows=[names])"
check "LR5d Cancel restores focus to caller window A (nand2)" \
  [expr {[string match {*nand2.sch} [xschem get current_name]]}] "(current=[xschem get current_name])"
# Now discard (answer "no") -> load proceeds into B
set ::answer no
set ::asks 0
xschem load -window $bpath [ex nand2.sch]
update
check "LR5e discard -> load proceeds, B retargeted to nand2 (prompt fired once)" \
  [expr {$::asks == 1 && [llength [lsearch -all [names] nand2.sch]] == 2}] \
  "(asks=$::asks windows=[names])"

# ---- LR6: -window on an unknown window path errors ----
reset
set rc [catch {xschem load -window .nope.drw [ex nand2.sch]} emsg]
check "LR6 -window unknown path errors" [expr {$rc != 0 && [string match {*no such window*} $emsg]}] \
  "(rc=$rc msg=$emsg)"

catch {xschem new_schematic destroy_all {}}
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
