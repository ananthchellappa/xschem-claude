# Regression for issue 0128: the scripted/menu `xschem edit_vi_prop` verb (Properties >
# "Edit with editor", Shift+Q menu accelerator, actions.csv row) had NO readonly gate —
# under X it launched the external editor and APPLIED the edit on a read-only cell,
# silently (set_modify's ro_suppress hid the modified flag) and with a spurious
# push_undo slot. Both keyboard entries (Q key, verb-noun 11) were already gated via
# readonly_block; the fix closes the asymmetry with one scheduler_readonly_reject at
# the branch top (after !xctx, before edit_property), per the setprop/wire/
# apply_properties (0126) convention.
#
# The external editor exec seam is the Tcl proc `edit_vi_prop` (xschem.tcl): redefining
# it here fully stubs the editor (no external process can ever launch), and the stub is
# defined FIRST so even a red/sabotaged binary cannot block. Mutation-side checks are
# GUI-conditional (edit_property no-ops at !has_x); the refusal checks (EVP3/EVP4) run
# unconditionally — the gate sits in the scheduler, before edit_property.
#
# Headless, own process, run from repo root (full_audit default runner):
#   src/xschem --pipe -q --nolog --script tests/headless/test_edit_vi_prop_readonly.tcl

# Witness stub BEFORE any `xschem edit_vi_prop` call — no-blocking guarantee.
# Contract (xschem.tcl proc): read $tctx::retval, write new content back to
# tctx::retval, set tctx::rcode ok (or {} for "unchanged/cancel").
set ::evp_calls 0
proc edit_vi_prop {txtlabel} {
  incr ::evp_calls
  set tctx::retval "$tctx::retval\n** stub_edit **"
  set tctx::rcode ok
  return ok
}

if {![info exists env(REPO)]} {
  set env(REPO) [file normalize [file join [file dirname [info script]] .. ..]]
}
set sch $env(REPO)/xschem_library/examples/Q1.sch

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# has_x probe: `winfo` exists iff Tk is up (main.c: Tk_Main only when has_x).
set has_gui [expr {[info commands winfo] ne {}}]
puts "info: has_gui=$has_gui"

xschem load $sch            ;# editable, never saved; all checks in-memory
xschem unselect_all         ;# lastsel==0 -> GLOBAL prop arm (schprop, spice default)
set orig [xschem get schprop]

# EVP1 (control, editable path unchanged): rc==0; if has_gui also: stub called once,
# schprop now contains "stub_edit", modified==1.
set rc1 [catch {xschem edit_vi_prop} r1]
if {$has_gui} {
  check "EVP1 editable edit_vi_prop works" \
    [expr {$rc1 == 0 && $::evp_calls == 1 \
           && [string match "*stub_edit*" [xschem get schprop]] \
           && [xschem get modified] == 1}] \
    "(rc=$rc1 calls=$::evp_calls modified=[xschem get modified])"
} else {
  check "EVP1 editable edit_vi_prop works" [expr {$rc1 == 0}] "(rc=$rc1, no-X: rc only)"
}

if {$has_gui} {
  # EVP2 (control, undo unchanged): global arm pushes undo BEFORE the strdup, so one
  # undo restores the original schprop.
  xschem undo
  check "EVP2 undo restores original schprop" \
    [expr {[xschem get schprop] eq $orig}] \
    "(schprop=[string range [xschem get schprop] 0 40])"
  # EVP5-setup: one more stubbed edit so the undo head is a REAL edit.
  set rc2 [catch {xschem edit_vi_prop} r2]
  set pre2 [xschem get schprop]
  check "EVP5-setup real edit applied" \
    [expr {$rc2 == 0 && [string match "*stub_edit*" $pre2]}] "(rc=$rc2)"
  xschem set_modify 0   ;# there is no `xschem set modified`; set_modify(0) clears it
} else {
  puts "skip: EVP2 undo control (no X)"
  puts "skip: EVP5-setup (no X)"
  set pre2 [xschem get schprop]
}

xschem set readonly 1
set ::evp_calls 0

# EVP3 (the bug): readonly edit_vi_prop must be REFUSED with the message.
set rc [catch {xschem edit_vi_prop} err]
check "EVP3 readonly edit_vi_prop refused" \
  [expr {$rc == 1 && $err ne {} && [string match "*read-only*" $err]}] \
  "(rc=$rc msg=[string range $err 0 50])"

# EVP4 (gate fires BEFORE the editor): editor never launched, schprop unchanged
# since the gate, modified stays 0.
check "EVP4 no editor launch / no mutation on refusal" \
  [expr {$::evp_calls == 0 && [xschem get schprop] eq $pre2 \
         && [xschem get modified] == 0}] \
  "(calls=$::evp_calls modified=[xschem get modified])"

if {$has_gui} {
  # EVP5 (no spurious undo slot): the refusal pushed nothing, so one undo peels
  # the REAL second edit and restores the pre-second-edit value ($orig).
  xschem set readonly 0
  xschem undo
  check "EVP5 single undo peels the real edit" \
    [expr {[xschem get schprop] eq $orig}] \
    "(schprop=[string range [xschem get schprop] 0 40])"
} else {
  puts "skip: EVP5 spurious-undo check (no X)"
}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
