# Regression for issue 0125: the scheduler `instance` branch discarded
# place_symbol's 1-placed/0-refused rc and unconditionally ran set_modify(1) +
# leaked whatever stale interp result the internals left behind (observed ``,
# `0`, `@spice_get_node`).  A refused placement (symbol-view guard, empty name,
# scope-ammeter no-selection bail) dirtied the buffer and reported garbage.
# The fix captures the rc into `placed`, gates set_modify(1) + the W3
# maintain_wire_segments pass on it, and returns a deterministic "1"/"0"
# (TCL_OK kept; consumer audit 2026-07-18: nobody read the old stale result).
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

# Stub alert_ for the WHOLE test so no has_x-gated popup can tkwait-flake an
# X-attached full_audit run.  Two popups are reachable here: the scope-ammeter
# no-selection alert (B7) and - pre-existing residual, same bail - the
# reentrant-bbox alert fired by the NEXT placement (B8), because the bail
# returns 0 after bbox(START) without the matching bbox(END) (select.c bbox()
# calls alert_ directly; live-verified hang without this stub).  Restored
# before exit.
rename alert_ alert_orig_0125
proc alert_ {args} {return 1}

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
# RESIDUAL DOC (issue 0125 part (b), left OPEN): the bail's push_undo fired
# before the rollback, so the slot survives and undo #1 is a no-op restoring
# the same {wire} state.  This check deliberately pins TODAY's burnt-slot
# behavior; it is EXPECTED TO FLIP when an undo-discard primitive ever fixes
# the residual - flip it consciously then.
check "IR8 residual-doc: burnt slot makes undo #1 a no-op (wire still there)" \
  [expr {[xschem get wires] == 1}] \
  "(wires=[xschem get wires])"
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
