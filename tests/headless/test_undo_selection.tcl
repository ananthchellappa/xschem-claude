# Issue 0007 — undo/redo must NOT drop the selection.
# Today both undo backends call unselect_all() during a restore, so undoing a
# property edit reverts the edit AND silently deselects the object. This proves
# the fix: after an undo (and redo) that restores a still-present object, the
# previously-selected object(s) stay selected — on BOTH backends (the fix keys off
# array position, not stable id, precisely because the default 'disk' backend
# re-mints ids on reload). Plan: doc/claude/code_analysis/undo_keep_selection_decision.md.
#
# Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_undo_selection.tcl
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# two instances, fresh schematic
proc setup {} {
  xschem set no_undo 0
  xschem clear force schematic
  xschem instance res.sym   0 0 0 0 {name=R1 value=1k}
  xschem instance res.sym 200 0 0 0 {name=R2 value=1k}
  update idletasks
}
proc inst_prop {nm} { return [xschem getprop instance $nm] }

# Core invariant under the CURRENT backend: select R1, make an undoable property
# edit, undo -> R1 stays selected and the edit is actually reverted; redo keeps it.
proc core_check {tag} {
  setup
  xschem select instance R1
  check "$tag precondition: R1 selected" [expr {[xschem get lastsel] == 1}] "(lastsel=[xschem get lastsel])"
  xschem setprop instance R1 value 30k          ;# undoable (push_undo)
  check "$tag edit applied (value=30k)" [string match {*value=30k*} [inst_prop R1]] "([inst_prop R1])"

  xschem undo
  update idletasks
  check "$tag undo KEEPS the selection (lastsel==1)" [expr {[xschem get lastsel] == 1}] "(lastsel=[xschem get lastsel])"
  check "$tag undo keeps the SAME object (R1)" [expr {[string first {R1} [xschem selected_set]] >= 0}] "([xschem selected_set])"
  check "$tag the edit was actually undone (value back to 1k)" [string match {*value=1k*} [inst_prop R1]] "([inst_prop R1])"

  xschem redo
  update idletasks
  check "$tag redo keeps the selection (lastsel==1)" [expr {[xschem get lastsel] == 1}] "(lastsel=[xschem get lastsel])"
  check "$tag redo re-applies the edit (value=30k)" [string match {*value=30k*} [inst_prop R1]] "([inst_prop R1])"
}

# --- US1/US2: the core invariant on the DEFAULT (disk) backend --------------
xschem undo_type memory; xschem undo_type disk   ;# force a clean disk stack
core_check "US1/2(disk)"

# --- US4: multi-select — edit one, undo, BOTH stay selected -----------------
xschem undo_type memory; xschem undo_type disk
setup
xschem select instance R1
xschem select instance R2
check "US4 precondition: 2 selected" [expr {[xschem get lastsel] == 2}] "(lastsel=[xschem get lastsel])"
xschem setprop instance R1 value 47k
xschem undo
update idletasks
check "US4 undo keeps BOTH selected (lastsel==2)" [expr {[xschem get lastsel] == 2}] "(lastsel=[xschem get lastsel])"
check "US4 both objects still in the selection" \
  [expr {[string first {R1} [xschem selected_set]] >= 0 && [string first {R2} [xschem selected_set]] >= 0}] \
  "([xschem selected_set])"

# --- US3: nothing-to-undo must leave the selection untouched (no regression) -
xschem undo_type memory; xschem undo_type disk
setup
xschem undo_type memory; xschem undo_type disk   ;# reset stack to tail (objects remain)
xschem select instance R1
set us3_ls [xschem get lastsel]
set us3_ni [xschem get instances]
xschem undo                                       ;# cur==tail -> early return -> no-op
update idletasks
check "US3 no-op undo leaves the selection untouched" \
  [expr {[xschem get lastsel] == $us3_ls && $us3_ls == 1 && [xschem get instances] == $us3_ni}] \
  "(lastsel=[xschem get lastsel] inst=[xschem get instances])"

# --- US5: a STRUCTURAL undo (object population changes) is clean, no crash ---
xschem undo_type memory; xschem undo_type disk
setup
xschem select instance R1
xschem delete                                     ;# delete R1 (undoable, structural)
check "US5 precondition: one instance left" [expr {[xschem get instances] == 1}] "(inst=[xschem get instances])"
xschem undo                                       ;# undo the delete: R1 reappears
update idletasks
check "US5 structural undo restores the model (no crash, instances==2)" \
  [expr {[xschem get instances] == 2}] "(inst=[xschem get instances])"

# --- US6: the SAME core invariant must hold on the MEMORY backend -----------
xschem undo_type disk; xschem undo_type memory   ;# force a clean memory stack
core_check "US6(memory)"
xschem undo_type memory; xschem undo_type disk   ;# restore default

# --- US7: the GUI undo via the 'u' KEY (not the `xschem undo` command) -------
# Guards the key route. On the action-registry feature branches 'u' is Tcl-backed
# -> `xschem undo` (the wrapped path); on master it is a direct C pop_undo call.
# Branch-agnostic in outcome: the selection must survive either way. keysym u=117,
# X11 KeyPress = event 2.
xschem undo_type memory; xschem undo_type disk
setup
xschem select instance R1
xschem setprop instance R1 value 55k
xschem callback .drw 2 100 100 117 0 0 0          ;# press 'u' -> undo
update idletasks
check "US7 'u'-KEY undo keeps the selection" [expr {[xschem get lastsel] == 1}] "(lastsel=[xschem get lastsel])"
check "US7 'u'-KEY undo reverted the edit (value=1k)" [string match {*value=1k*} [inst_prop R1]] "([inst_prop R1])"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
