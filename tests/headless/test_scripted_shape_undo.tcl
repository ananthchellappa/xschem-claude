# Regression for issue 0127: the scripted coordinate forms `xschem rect x1 y1
# x2 y2`, `xschem line x1 y1 x2 y2` and `xschem arc x y r a b layer` stored the
# shape + set_modify(1) but pushed NO undo checkpoint, so one undo after a
# scripted shape rode the PREVIOUS checkpoint and destroyed unrelated edits
# (live repro: wire + rect, one undo -> the wire vanished with the rect).
# The fix is one xctx->push_undo() per coord arm, mirroring the wire coord
# branch and the interactive twins (new_rect/new_line/new_arc); the arc push
# sits INSIDE the layer-validity gate so a refused invalid-layer arc still
# pushes nothing (0121/0125 spurious-undo class).
#
# Headless, own process, run from repo root (full_audit default runner):
#   src/xschem --pipe -q --nolog --script tests/headless/test_scripted_shape_undo.tcl
# Everything runs on the launch untitled buffer via `xschem clear force`;
# nothing is ever saved. `xschem set rectcolor 4` after each clear keeps the
# storage layer deterministic.

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# The undo ring persists across `xschem clear force` (clear_schematic never
# calls clear_undo), so each block empties the ring first or its second-undo
# checks would walk into the previous block's snapshots. Same trick as
# test_undo_selection.tcl: switching undo_type resets the other type's ring;
# the double toggle ends on a clean disk stack from either starting type.
proc reset_undo {} {
  xschem undo_type memory
  xschem undo_type disk
}

# ---------------------------------------------------------------- rect block
xschem clear force
reset_undo
xschem set rectcolor 4
xschem wire 0 0 100 0               ;# prior edit - pushes per call (precedent)
xschem rect 300 -100 400 -50        ;# the fixed arm - must push

check "SSU-R1 rect stored" \
  [expr {[llength [xschem objects -type rect]] == 1}] \
  "(rects=[llength [xschem objects -type rect]])"
xschem undo
check "SSU-R2 prior wire survives one undo" \
  [expr {[xschem get wires] == 1}] \
  "(wires=[xschem get wires])"
check "SSU-R3 undo removed the rect" \
  [expr {[llength [xschem objects -type rect]] == 0}] \
  "(rects=[llength [xschem objects -type rect]])"
xschem undo
check "SSU-R4 second undo peels the wire (exactly one push)" \
  [expr {[xschem get wires] == 0}] \
  "(wires=[xschem get wires])"

# SSU-RD1 (redo control): two redos restore wire + rect.
xschem redo
xschem redo
check "SSU-RD1 two redos restore wire + rect" \
  [expr {[xschem get wires] == 1 && [llength [xschem objects -type rect]] == 1}] \
  "(wires=[xschem get wires] rects=[llength [xschem objects -type rect]])"

# ---------------------------------------------------------------- line block
xschem clear force
reset_undo
xschem set rectcolor 4
xschem wire 0 0 100 0
xschem line 0 -200 100 -200

check "SSU-L1 line stored" \
  [expr {[llength [xschem objects -type line]] == 1}] \
  "(lines=[llength [xschem objects -type line]])"
xschem undo
check "SSU-L2 prior wire survives one undo" \
  [expr {[xschem get wires] == 1}] \
  "(wires=[xschem get wires])"
check "SSU-L3 undo removed the line" \
  [expr {[llength [xschem objects -type line]] == 0}] \
  "(lines=[llength [xschem objects -type line]])"
xschem undo
check "SSU-L4 second undo peels the wire (exactly one push)" \
  [expr {[xschem get wires] == 0}] \
  "(wires=[xschem get wires])"

# ---------------------------------------------------------------- arc block
xschem clear force
reset_undo
xschem set rectcolor 4
xschem wire 0 0 100 0
xschem arc 300 -300 50 0 180 4

check "SSU-A1 arc stored" \
  [expr {[llength [xschem objects -type arc]] == 1}] \
  "(arcs=[llength [xschem objects -type arc]])"
xschem undo
check "SSU-A2 prior wire survives one undo" \
  [expr {[xschem get wires] == 1}] \
  "(wires=[xschem get wires])"
check "SSU-A3 undo removed the arc" \
  [expr {[llength [xschem objects -type arc]] == 0}] \
  "(arcs=[llength [xschem objects -type arc]])"
xschem undo
check "SSU-A4 second undo peels the wire (exactly one push)" \
  [expr {[xschem get wires] == 0}] \
  "(wires=[xschem get wires])"

# SSU-A5 (arc refusal pushes nothing - guards the push placement inside the
# layer-validity gate): an invalid-layer arc returns "0", stores nothing and
# must leave NO extra undo slot, so the single undo peels the wire itself.
xschem clear force
reset_undo
xschem set rectcolor 4
xschem wire 0 0 100 0
set r [xschem arc 300 -300 50 0 180 999]
xschem undo
check "SSU-A5 refused arc left no undo slot" \
  [expr {$r == 0 && [llength [xschem objects -type arc]] == 0 \
         && [xschem get wires] == 0}] \
  "(r=$r arcs=[llength [xschem objects -type arc]] wires=[xschem get wires])"

# ------------------------------------------- modified + readonly controls
xschem clear force
reset_undo
xschem set rectcolor 4
xschem rect 300 -100 400 -50        ;# real edit

# SSU-M1 (unchanged-behavior control): set_modify still fires on the coord arm.
check "SSU-M1 scripted rect sets modified" \
  [expr {[xschem get modified] == 1}] \
  "(modified=[xschem get modified])"

xschem set_modify 0
xschem set readonly 1

set rcR [catch {xschem rect 500 -100 600 -50} errR]
check "SSU-RO1 readonly rect refused" \
  [expr {$rcR == 1 && [string match "*read-only*" $errR] \
         && [llength [xschem objects -type rect]] == 1}] \
  "(rc=$rcR rects=[llength [xschem objects -type rect]] msg=[string range $errR 0 50])"

set rcL [catch {xschem line 0 -400 100 -400} errL]
check "SSU-RO2 readonly line refused" \
  [expr {$rcL == 1 && [string match "*read-only*" $errL] \
         && [llength [xschem objects -type line]] == 0}] \
  "(rc=$rcL lines=[llength [xschem objects -type line]] msg=[string range $errL 0 50])"

set rcA [catch {xschem arc 300 -500 50 0 180 4} errA]
check "SSU-RO3 readonly arc refused" \
  [expr {$rcA == 1 && [string match "*read-only*" $errA] \
         && [llength [xschem objects -type arc]] == 0 \
         && [xschem get modified] == 0}] \
  "(rc=$rcA arcs=[llength [xschem objects -type arc]] modified=[xschem get modified])"

xschem set readonly 0

puts ""
puts [expr {$fail == 0 ? "RESULT: ALL PASS" : "RESULT: $fail FAILED"}]
flush stdout
if {$fail != 0} { exit 1 }
xschem exit closewindow force
