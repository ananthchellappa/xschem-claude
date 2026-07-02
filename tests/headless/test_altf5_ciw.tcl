# test_altf5_ciw.tcl
#
# Verifies the default Alt-F5 -> raise/open CIW binding (tools.raise_ciw):
#   - the action is registered (bindable via `xschem bind`);
#   - pressing Alt-F5 on the canvas raises/opens the CIW (wm state -> normal);
#   - the binding is user-overridable: un-binding it makes Alt-F5 a no-op, and
#     rebinding restores it.
#
# Needs Tk (the CIW is a real toplevel). Run under X with --pipe + --logdir:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_altf5_ciw.tcl

set ::fail 0
proc check {name ok} {
  if {$ok} { puts "ok   - $name" } else { puts "FAIL - $name" ; set ::fail 1 }
}
# KeyPress driver: event type 2, keysym, state (Alt = Mod1Mask = 8).
proc key {ks {st 0}} { xschem callback .drw 2 400 300 $ks 0 0 $st ; update idletasks }
set F5 65474 ; set ALT 8

check "action registered / bindable" \
  [expr {![catch {xschem bind key $F5 alt canvas tools.raise_ciw}]}]

# start from a withdrawn CIW so a state change to 'normal' is unambiguous
if {[winfo exists .ciw]} { wm withdraw .ciw ; update idletasks }

key $F5 $ALT
check "Alt-F5 raises/opens the CIW" \
  [expr {[winfo exists .ciw] && [wm state .ciw] eq "normal"}]

# override: un-bind Alt-F5, withdraw, press again -> must stay withdrawn
wm withdraw .ciw ; update idletasks
xschem unbind key $F5 alt canvas
key $F5 $ALT
check "un-bound Alt-F5 no longer raises CIW" [expr {[wm state .ciw] eq "withdrawn"}]

# rebind restores the behavior
xschem bind key $F5 alt canvas tools.raise_ciw
key $F5 $ALT
check "rebound Alt-F5 raises CIW again" [expr {[wm state .ciw] eq "normal"}]

if {$::fail} { puts "RESULT: FAIL" } else { puts "RESULT: ALL PASS" }
