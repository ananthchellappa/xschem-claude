# TC1 (Issue A, guard) — stretch toggle OFF: a plain move must NOT drag the wire.
# Spec: doc/claude/code_analysis/wire_editing_spec_and_plan.md.
source [file join [file dirname [info script]] fixtures.tcl]
we_reset 0 0                 ;# enable_stretch OFF
we_device 0 0                ;# pin M (0,30)
we_wire 0 30 0 130           ;# on pin M
xschem unselect_all; xschem select instance 0
we_move 40 0                 ;# plain move of just the device
check "TC1 wire unchanged (does not follow)" [has_seg 0 30 0 130]
check "TC1 exactly one wire" [expr {[nwires] == 1}]
we_result
