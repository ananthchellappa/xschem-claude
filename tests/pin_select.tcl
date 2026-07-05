#
#  File: pin_select.tcl
#
#  Headless regression for selectable instance pins.
#  See doc/claude/specs/pin_selection.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script pin_select.tcl
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# Clean slate + one 2-pin device (res.sym: pin 0 = "P", pin 1 = "M").
xschem clear force
xschem instance devices/res.sym 100 100 0 0 {name=R1}
xschem unselect_all
set ninst [xschem get instances]
check "placed one instance"            $ninst 1
check "baseline empty selection"       [xschem get lastsel] 0

# --- enable the feature, then drive pin selection from script -------------
xschem set en_pin_select 1

check "select pin 0 returns 1"         [xschem select pin R1 0] 1
check "exactly one pin selected"       [xschem get lastsel] 1
set row [lindex [xschem selection] 0]
check "selection row type is pin"   [lindex $row 0] pin
check "selection instance index 0"  [lindex $row 1] 0
check "selection pin index 0"       [lindex $row 2] 0
# pin selection must NOT mark the whole instance (inert): no ELEMENT entry exists
check "no whole-instance ELEMENT entry" \
  [llength [lsearch -all -inline -index 0 [xschem selection] instance]] 0

# --- a second pin on the same instance -----------------------------------
check "select pin 1 returns 1"         [xschem select pin R1 1] 1
check "two pins selected"              [xschem get lastsel] 2

# --- deselect one pin via the 'clear' form -------------------------------
xschem select pin R1 0 clear
check "one pin left after clear"       [xschem get lastsel] 1

# --- unselect_all empties the pin selection ------------------------------
xschem unselect_all
check "unselect_all clears pins"       [xschem get lastsel] 0

# --- bad arguments are rejected, not crashed -----------------------------
check "pin index out of range -> 0"    [xschem select pin R1 99] 0
check "negative pin index -> 0"        [xschem select pin R1 -1] 0
check "unknown instance -> 0"          [xschem select pin NOPE 0] 0
check "nothing got selected by bad args" [xschem get lastsel] 0

# --- D1: a pins-only selection is INERT to delete ------------------------
xschem select pin R1 0
xschem delete
check "delete leaves the instance (pins inert)" [xschem get instances] $ninst
xschem unselect_all

# --- toggle OFF: scriptable path still resolves but feature is opt-in -----
# (the GUI click path is gated by en_pin_select; the script form is a test hook
#  and stays available, so we only assert the C field round-trips behaviourally
#  by selecting then clearing once more.)
xschem set en_pin_select 0
xschem select pin R1 1
check "script pin-select still works"  [xschem get lastsel] 1
xschem unselect_all
check "final selection empty"          [xschem get lastsel] 0

# --- v2 (D6) data-model guard: pins on TWO instances selected at once ------
# The multi-pin gesture (SHIFT+click, GUI) rests on this: pin_sel[] holds N pins
# across instances and rebuild_selected_array emits one INST_PIN row each. Clearing
# one instance's pin must leave the other's intact.
xschem set en_pin_select 1
xschem instance devices/res.sym 300 100 0 0 {name=R2}
xschem unselect_all
xschem select pin R1 0
xschem select pin R2 1
check "two pins on two instances selected" [xschem get lastsel] 2
set pins [lsearch -all -inline -index 0 [xschem selection] pin]
check "selection has 2 pin rows"           [llength $pins] 2
xschem select pin R1 0 clear
check "clearing R1's pin leaves R2's"      [xschem get lastsel] 1
set row [lindex [lsearch -all -inline -index 0 [xschem selection] pin] 0]
check "remaining pin is on R2 pin 1"       [list [lindex $row 2]] 1
xschem unselect_all
check "multi-instance cleanup empty"       [xschem get lastsel] 0

if {$nfail} { puts "pin_select: $nfail check(s): FAIL" } \
else        { puts "pin_select: all checks PASS" }
