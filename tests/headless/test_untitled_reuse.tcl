# Editor-style reuse of the launch "untitled" scratch buffer (NEdit/Notepad++):
# opening a file consumes a pristine untitled buffer instead of leaving it orphaned
# beside the file -- so untitled.sch only exists when nothing else is open. A scratch
# buffer the user has drawn in (modified) is preserved, not clobbered.
# Backend: is_pristine_untitled() + load_new_window reuse (scheduler.c).
#
# Needs X (creates windows). Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_untitled_reuse.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {n} { global repo; return [file join $repo xschem_library examples $n] }
set ::tabbed_interface 1

# UR1 — launch state is a single pristine untitled buffer
catch {xschem new_schematic destroy_all {}}
check "UR1 launch shows a single untitled buffer" \
  [expr {[string match {untitled*} [xschem get current_name]] && [llength [xschem windows]] == 1 \
         && [xschem get modified] == 0}] \
  "(name=[xschem get current_name] windows=[llength [xschem windows]])"

# UR2 — first open (even with -window / "New window") REUSES the untitled buffer:
# the file lands in the same window, no second window, no orphaned untitled.
xschem load_new_window -window [ex nand2.sch]
update
check "UR2 first open reuses untitled (in place, no new window)" \
  [expr {[string match {*nand2.sch} [xschem get current_name]] && [llength [xschem windows]] == 1}] \
  "(name=[xschem get current_name] windows=[llength [xschem windows]])"

# UR3 — once a real file occupies the buffer, the next open makes a NEW window
xschem load_new_window -window [ex dlatch.sch]
update
set names [lmap e [xschem windows] {file tail [lindex $e 4]}]
check "UR3 second open creates a new window (untitled gone, both files present)" \
  [expr {[llength [xschem windows]] == 2 && [lsearch $names untitled.sch] < 0 \
         && [lsearch $names nand2.sch] >= 0 && [lsearch $names dlatch.sch] >= 0}] \
  "(windows=$names)"

# UR4 — a MODIFIED untitled scratch is NOT reused: the user's work is preserved and
# the open goes to a new window instead.
catch {xschem new_schematic destroy_all {}}
xschem clear force            ;# fresh pristine untitled in the main window
xschem wire 100 100 200 100   ;# draw in untitled -> modified
check "UR4a drawing marks the untitled buffer modified" [expr {[xschem get modified] == 1}] {}
xschem load_new_window -window [ex nand2.sch]
update
set names [lmap e [xschem windows] {file tail [lindex $e 4]}]
check "UR4b modified untitled is preserved (open goes to a new window)" \
  [expr {[llength [xschem windows]] == 2 && [lsearch $names untitled.sch] >= 0}] \
  "(windows=$names)"

catch {xschem new_schematic destroy_all {}}
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
