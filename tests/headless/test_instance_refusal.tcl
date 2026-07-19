# Regression for issue 0125: the scheduler `instance` branch discarded
# place_symbol's 1-placed/0-refused rc and unconditionally ran set_modify(1) +
# leaked whatever stale interp result the internals left behind (observed ``,
# `0`, `@spice_get_node`).  A refused placement (symbol-view guard, empty name,
# scope-ammeter no-selection bail) dirtied the buffer and reported garbage.
# The fix captures the rc into `placed`, gates set_modify(1) + the W3
# maintain_wire_segments pass on it, and returns a deterministic "1"/"0"
# (TCL_OK kept; consumer audit 2026-07-18: nobody read the old stale result).
# RESIDUAL fix (issue 0125, batch item 6): the scope-ammeter bail in
# place_symbol is now pre-flighted BEFORE push_undo (no burnt undo slot, IR8
# flipped) and the in-body backstop bail balances its bbox(START) so the NEXT
# placement is clean (IR11); IR12 pins the scope-success control.
#
# Headless, own process, run from repo root (full_audit default runner):
#   src/xschem --pipe -q --nolog --script tests/headless/test_instance_refusal.tcl
# No fixture: everything runs on the launch untitled buffer via
# `xschem clear force`.  Nothing is ever saved.
#
# Five refusal variants each record THREE facts (result string, modified flag
# read right after the call, instances delta == 0); ONE consolidated check
# IR-REF asserts all of them at the end so each sabotage fails exactly one check.

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# Refusal-variant fact accumulator: result string, modified flag, instance delta.
array set V {}
proc record_variant {name res inst_before} {
  global V
  set V($name,res)   $res
  set V($name,mod)   [xschem get modified]
  set V($name,delta) [expr {[xschem get instances] - $inst_before}]
}

# Counting stub for alert_ over the WHOLE test: still guards the X-attached
# full_audit run against tkwait-flaking popups (the has_x-gated scope-ammeter
# no-selection alert, B7 — see the item-5 receipt), and now also WITNESSES
# that no alert fires where none should: the reentrant-bbox alert_ from
# select.c bbox() (unconditional, not has_x-gated) that the unbalanced bail
# used to trigger on the NEXT placement is asserted absent by IR11 via
# ::alert_count.  Restored before exit.
set ::alert_count 0
rename alert_ alert_orig_0125
proc alert_ {args} {incr ::alert_count; return 1}

# ------------------------------------------------ B1 IR1: success contract (argc==8)
xschem clear force
xschem set_modify 0
set r [xschem instance devices/lab_pin.sym 0 0 0 0 {name=l1 lab=clk}]
check "IR1 placed instance: stored + modified + result 1" \
  [expr {[xschem get instances] == 1 && [xschem get modified] == 1 && $r eq "1"}] \
  "(instances=[xschem get instances] modified=[xschem get modified] r='$r')"

# ------------------------------------------------ B2 V1: empty name (argc==7)
xschem clear force
xschem set_modify 0
set ib [xschem get instances]
set r [xschem instance {} 100 100 0 0]
record_variant V1 $r $ib

# ------------------------------------------------ B3 V2: whitespace name (argc==8)
xschem clear force
xschem set_modify 0
set ib [xschem get instances]
set r [xschem instance {   } 100 100 0 0 {name=x1}]
record_variant V2 $r $ib

# ------------------------------------------------ B4 V3: batch-form refusal (argc==9)
xschem clear force
xschem set_modify 0
set ib [xschem get instances]
set r [xschem instance {} 100 100 0 0 {name=x1} 0]
record_variant V3 $r $ib

# ---------------- B5 IR4: batch success + first_call dance + undo depth
# wire pushes one slot (snapshot: empty); batch first call (argv[8]==0) pushes
# ONE slot for all three placements; calls 2..3 (argv[8]!=0) push nothing.
xschem clear force
xschem wire 0 0 100 0
xschem set_modify 0
for {set i 0} {$i < 3} {incr i} {
  xschem instance devices/lab_pin.sym [expr {100*$i}] -100 0 0 "name=p$i lab=n$i" $i
}
check "IR4a batch placed 3 + modified" \
  [expr {[xschem get instances] == 3 && [xschem get modified] == 1}] \
  "(instances=[xschem get instances] modified=[xschem get modified])"
xschem undo
check "IR4b one undo removes the whole batch, wire survives" \
  [expr {[xschem get instances] == 0 && [xschem get wires] == 1}] \
  "(instances=[xschem get instances] wires=[xschem get wires])"
xschem undo
check "IR4c second undo peels the wire" \
  [expr {[xschem get wires] == 0}] \
  "(wires=[xschem get wires])"

# ---------------- B6 IR6: refusal adds no undo slot (control)
xschem clear force
xschem wire 0 0 100 0
xschem instance {} 0 0 0 0
xschem undo
check "IR6 refusal pushed nothing: single undo peels the wire" \
  [expr {[xschem get wires] == 0}] \
  "(wires=[xschem get wires])"

# ---------------- B7 V4 + IR7 + IR8: scope-ammeter no-selection bail
# scope_ammeter.sym is type=scope with zero pin rects; with nothing selected
# place_symbol bails at actions.c scope-ammeter path AFTER push_undo + real
# mutations, manually rolls the instance back and returns 0.  (alert_ already
# stubbed globally above.)
xschem clear force
xschem wire 0 0 100 0
xschem set_modify 0
xschem unselect_all
set ib [xschem get instances]
set wb [xschem get wires]
set r [xschem instance devices/scope_ammeter.sym 300 300 0 0]
record_variant V4 $r $ib
check "IR7 scope-ammeter bail rolled the instance back, wire untouched" \
  [expr {[xschem get instances] == 0 && [xschem get wires] == $wb}] \
  "(instances=[xschem get instances] wires=[xschem get wires] wires_before=$wb)"
xschem undo
# RESIDUAL FIXED (issue 0125, batch item 6): the scope-ammeter refusal is now
# pre-flighted BEFORE push_undo (option (a) — no undo-discard primitive
# needed), so no slot is burnt and undo #1 peels the wire in ONE step.  This
# consciously flips the old IR8 burnt-slot pin.  Only the theoretical
# translate-swapped-symbol path reaching the in-body backstop bail still
# burns a slot (documented residual in the issue file).
check "IR8 scope refusal burns no undo slot: undo #1 peels the wire" \
  [expr {[xschem get wires] == 0}] "(wires=[xschem get wires])"
xschem clear force

# B7b IR11: the bail must not poison bbox state for the NEXT placement
xschem clear force
xschem unselect_all
xschem instance devices/scope_ammeter.sym 300 300 0 0   ;# refusal
set ::alert_count 0                                     ;# window starts AFTER the refusal
set r [xschem instance devices/lab_pin.sym 0 0 0 0 {name=lbb lab=bb}]
check "IR11 placement after scope bail: clean (no reentrant-bbox alert)" \
  [expr {$r eq "1" && [xschem get instances] == 1 && $::alert_count == 0}] \
  "(r='$r' instances=[xschem get instances] alerts=$::alert_count)"
xschem clear force

# B7c IR12: with exactly one selected ELEMENT the scope placement must SUCCEED
xschem clear force
xschem instance devices/res.sym 100 100 0 0 {name=R1 value=1k}
xschem select instance R1
set ls [xschem get lastsel]   ;# forces rebuild_selected_array (select_element only flags)
set r [xschem instance devices/scope_ammeter.sym 400 400 0 0]
check "IR12 scope+selected-device still places (control)" \
  [expr {$ls == 1 && $r eq "1" && [xschem get instances] == 2}] \
  "(lastsel=$ls r='$r' instances=[xschem get instances])"
xschem clear force

# ---------------- B8 IR9: bad name is a MUTATION, not a refusal (semantic pin)
# match_symbol never returns -1: an unknown name places systemlib/missing.sym,
# a real mutation - set_modify(1) and rc 1 are CORRECT here.
xschem clear force
xschem set_modify 0
xschem instance no_such_symbol_0125.sym 200 200 0 0
check "IR9 unknown symbol places missing.sym (real mutation)" \
  [expr {[xschem get instances] == 1 && [xschem get modified] == 1}] \
  "(instances=[xschem get instances] modified=[xschem get modified])"

# ---------------- B9 IR10: readonly control (unchanged behavior)
xschem clear force
xschem set readonly 1
set rc [catch {xschem instance devices/res.sym 0 0 0 0} msg]
check "IR10 readonly instance refused with error" \
  [expr {$rc == 1 && [string match "*read-only*" $msg] && [xschem get instances] == 0}] \
  "(rc=$rc instances=[xschem get instances] msg=[string range $msg 0 50])"
xschem set readonly 0

# ---------------- B10 V5: symbol-view guard (LAST - leaves the schematic buffer)
xschem load -force xschem_library/devices/res.sym
xschem set_modify 0
set ib [xschem get instances]
set r [xschem instance devices/capa.sym 0 0 0 0]
record_variant V5 $r $ib

# ---------------- Final consolidated refusal check
puts "refusal variant facts:"
set refok 1
foreach v {V1 V2 V3 V4 V5} {
  puts "  $v: result='$V($v,res)' modified=$V($v,mod) inst_delta=$V($v,delta)"
  if {!($V($v,res) eq "0" && $V($v,mod) == 0 && $V($v,delta) == 0)} { set refok 0 }
}
check "IR-REF every refusal: result 0, modified 0, no instance" $refok ""

rename alert_ {}
rename alert_orig_0125 alert_

puts ""
puts [expr {$fail == 0 ? "RESULT: ALL PASS" : "RESULT: $fail FAILED"}]
flush stdout
if {$fail != 0} { exit 1 }
xschem exit closewindow force
