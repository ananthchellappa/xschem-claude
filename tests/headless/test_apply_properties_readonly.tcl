# Regression for issue 0126: the scripted `xschem apply_properties` verb had NO
# readonly gate — a script/CIW/replay call mutated a read-only cell silently
# (set_modify's ro_suppress even hid the modified flag). The fix is one
# scheduler_readonly_reject at the branch top, before argc validation, per the
# setprop/wire convention. Controls first (editable path + undo untouched), then
# the readonly refusal (message, no mutation, no spurious undo slot).
#
# Headless, own process, run from repo root (full_audit default runner):
#   src/xschem --pipe -q --nolog --script tests/headless/test_apply_properties_readonly.tcl
if {![info exists env(REPO)]} {
  set env(REPO) [file normalize [file join [file dirname [info script]] .. ..]]
}
set sch $env(REPO)/xschem_library/examples/Q1.sch

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

xschem load $sch                                     ;# editable, never saved
set orig [xschem getprop instance 0]
set id   [xschem instance_id [xschem getprop instance 0 name]]
set new  [xschem subst_tok $orig name ZZ99]

# APRO1 (control, editable path unchanged): apply returns "1", prop changed,
# modified flag set.
set rc1 [catch {xschem apply_properties current $id $new $orig 1} r]
check "APRO1 editable apply works" \
  [expr {$rc1 == 0 && $r eq "1" && [xschem getprop instance 0] ne $orig \
         && [xschem get modified] == 1}] \
  "(rc=$rc1 r=$r modified=[xschem get modified])"

# APRO2 (control, undo unchanged): one undo restores the original prop.
xschem undo
check "APRO2 undo restores original" \
  [expr {[xschem getprop instance 0] eq $orig}] \
  "(prop=[string range [xschem getprop instance 0] 0 40])"

# APRO5 setup: one REAL edit so the undo stack head is known.
set id [xschem instance_id [xschem getprop instance 0 name]]   ;# re-fetch post-undo
set rc2 [catch {xschem apply_properties current $id $new $orig 1} r2]
check "APRO5-setup real edit applied" \
  [expr {$rc2 == 0 && $r2 eq "1" && [xschem getprop instance 0] eq $new}] \
  "(rc=$rc2 r2=$r2)"
xschem set_modify 0    ;# there is no `xschem set modified`; set_modify(0) clears the flag
xschem set readonly 1

# APRO3 (the bug): full-arg apply on readonly must be REFUSED with the message.
set rc [catch {xschem apply_properties current $id $orig $new 1} err]
check "APRO3 readonly apply refused" \
  [expr {$rc == 1 && $err ne {} && [string match "*read-only*" $err]}] \
  "(rc=$rc msg=[string range $err 0 50])"

# APRO4 (no mutation): prop untouched, modified stays 0.
check "APRO4 no mutation on refusal" \
  [expr {[xschem getprop instance 0] eq $new && [xschem get modified] == 0}] \
  "(modified=[xschem get modified])"

# APRO5 (no spurious undo slot): one undo peels the REAL edit — the refusal
# pushed nothing onto the undo stack.
xschem set readonly 0
xschem undo
check "APRO5 single undo peels the real edit" \
  [expr {[xschem getprop instance 0] eq $orig}] \
  "(prop=[string range [xschem getprop instance 0] 0 40])"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
