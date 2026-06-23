# Issue 0023: is_pristine_untitled() must identify the scratch buffer by its BASENAME
# (untitled.sch / untitled-<n>.sch), not by strstr(full_path, "untitled"). A real,
# empty, unmodified schematic that merely lives under a directory containing the word
# "untitled" must NOT be treated as a reusable scratch buffer and silently replaced.
#
# RED before fix: opening another file reuses (clobbers) the real file in place ->
# one window, real.sch gone. GREEN after fix: the open lands in a new window, real.sch
# stays open.
#
# Needs X. Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_pristine_untitled_basename.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {n} { global repo; return [file join $repo xschem_library examples $n] }

set ::tabbed_interface 1

# a real, empty schematic whose DIRECTORY name contains "untitled"
set d /tmp/untitled_dir_xtest
file delete -force $d; file mkdir $d
catch {xschem new_schematic destroy_all {}}
xschem clear force
xschem saveas $d/real.sch
xschem load $d/real.sch     ;# reload fresh so modified==0, clean
update

set nm0 [xschem get current_name]
check "UT0 a real empty file is open under an 'untitled' path, unmodified" \
  [expr {[string match {*untitled*} $nm0] && [file tail $nm0] eq "real.sch" \
         && [xschem get instances] == 0 && [xschem get wires] == 0 && [xschem get modified] == 0}] \
  "(name=$nm0 inst=[xschem get instances] wires=[xschem get wires] mod=[xschem get modified])"

# open another file: real.sch is NOT a scratch buffer, so it must survive
xschem load_new_window [ex nand2.sch]
update
set names [lmap e [xschem windows] {file tail [lindex $e 4]}]
check "UT1 opening a file does NOT clobber the real empty 'untitled'-path file" \
  [expr {[lsearch $names real.sch] >= 0 && [lsearch $names nand2.sch] >= 0 \
         && [llength [xschem windows]] == 2}] \
  "(windows=$names)"

file delete -force $d
catch {xschem new_schematic destroy_all {}}
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
