# Read-only viewing — file-protection layer. A per-window xctx->readonly flag:
#   - auto-set when a loaded file is not writable on disk (the edit->view fallback)
#   - blocks the save-to-file path (the file can never be clobbered)
#   - Save As still works and re-derives the flag from the new file
#   - get/set via `xschem get/set readonly`, toggled by the toggle_readonly proc
# Viewing (pan/zoom/select/inspect) is intentionally unaffected — that is a GUI
# eyeball item, not covered here.
#
# Headless. Run with --pipe from src/:
#   ./xschem --pipe -q --script ../tests/headless/test_readonly.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }
proc emptysch {f} {
  file mkdir [file dirname $f]
  set fp [open $f w]
  puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
  foreach r {G K V S E} { puts $fp "$r \{\}" }
  close $fp
}

source [file join [file dirname [info script]] scratch.tcl]
set tmp [test_scratch ro]

# === RO1 — get/set round-trip ===============================================
emptysch $tmp/t.sch
xschem load $tmp/t.sch
xschem set readonly 1
check "RO1a set readonly 1" [expr {[xschem get readonly] == 1}] "(=> [xschem get readonly])"
xschem set readonly 0
check "RO1b set readonly 0" [expr {[xschem get readonly] == 0}] "(=> [xschem get readonly])"

# === RO2 — save is blocked while read-only, allowed otherwise ================
xschem load $tmp/t.sch
set before [slurp $tmp/t.sch]
xschem set readonly 1
set rc [catch {xschem save} e]
check "RO2a save errors when read-only" [expr {$rc == 1}] "(=> rc=$rc)"
check "RO2b file untouched by blocked save" [expr {[slurp $tmp/t.sch] eq $before}] {}
xschem set readonly 0
set rc [catch {xschem save} e]
check "RO2c save allowed again when editable" [expr {$rc == 0}] "(=> rc=$rc '$e')"

# === RO3 — auto read-only when the file is not writable on disk ==============
emptysch $tmp/ro.sch
file attributes $tmp/ro.sch -permissions 00444
xschem load $tmp/ro.sch
check "RO3a non-writable file loads read-only" [expr {[xschem get readonly] == 1}] "(=> [xschem get readonly])"
emptysch $tmp/rw.sch
xschem load $tmp/rw.sch
check "RO3b writable file loads editable" [expr {[xschem get readonly] == 0}] "(=> [xschem get readonly])"

# === RO4 — Save As works while read-only and clears the flag ================
xschem load $tmp/ro.sch                ;# read-only again
check "RO4a still read-only" [expr {[xschem get readonly] == 1}] {}
xschem saveas $tmp/copy.sch schematic
check "RO4b saveas wrote the copy" [file isfile $tmp/copy.sch] {}
check "RO4c readonly cleared after saveas to writable file" [expr {[xschem get readonly] == 0}] "(=> [xschem get readonly])"

# === RO5 — toggle_readonly proc flips the current window ====================
xschem set readonly 0
toggle_readonly
check "RO5a toggle on"  [expr {[xschem get readonly] == 1}] "(=> [xschem get readonly])"
toggle_readonly
check "RO5b toggle off" [expr {[xschem get readonly] == 0}] "(=> [xschem get readonly])"

file attributes $tmp/ro.sch -permissions 00644
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
