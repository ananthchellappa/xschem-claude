# Smoke for the generated keybindings cheat-sheet. Run with --pipe (no X needed
# for the text generator, but the binary sources the registry):
#   DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_keybindings_help.tcl
set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

set txt [generate_keybindings_text]

# Migrated keys are flagged with '*' and carry their table accel.
foreach pat {"* U " "* Shift+U " "* Shift+Z " "* Ctrl+Z "} {
  check "starred: $pat" [expr {[string first $pat $txt] >= 0}] {}
}
# A non-migrated shortcut is present but NOT starred.
check "Ctrl+C present unstarred" \
  [expr {[string first "Ctrl+C" $txt] >= 0 && [string first "* Ctrl+C" $txt] < 0}] {}

# Exactly the migrated command-rows-with-accel are starred (batch 1 == 4).
set starred 0
foreach line [split $txt "\n"] {
  if {[regexp {^  \* [^=]} $line]} { incr starred } ;# exclude the legend line
}
check "starred line count == migrated rows" [expr {$starred == 4}] "(=> $starred)"

# Cross-check: generator stays in sync if the table changes. Remap drops the old
# accel's star and the cheat-sheet reflects the new accel immediately.
remap_action_accel view.zoom_in {Ctrl+Shift+Z} .drw
set txt2 [generate_keybindings_text]
check "cheat-sheet follows remap" \
  [expr {[string first "* Ctrl+Shift+Z " $txt2] >= 0 && [string first "* Shift+Z " $txt2] < 0}] {}
remap_action_accel view.zoom_in {Shift+Z} .drw

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
