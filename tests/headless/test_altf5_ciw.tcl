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

# --- cadence_style_rc coexistence -------------------------------------------
# cadence_style_rc binds plain F5 to a net-highlight on .drw. That binding and the
# generic .drw <Key> -> C dispatch share the same bindtag, so Tk runs only the more
# specific <Key-F5> for ANY F5 -- it must forward modified F5 to the dispatch itself,
# or Alt-F5 never reaches tools.raise_ciw. Assert the shipped rc does that. (Driven
# by inspecting the installed binding: headless `event generate` of compound key
# chords is unreliable, so key routing is asserted structurally + via the direct
# `xschem callback` dispatch checks above -- the same pattern the other key tests use.)
if {[catch {source src/cadence_style_rc} err] && \
    [catch {source ../../src/cadence_style_rc} err]} {
  check "cadence_style_rc sources" 0
} else {
  check "cadence_style_rc sources" 1
  set b [bind .drw <Key-F5>]
  check "cadence F5 forwards Alt-F5 to the C dispatch" \
    [string match {*if {%s & 8}*xschem callback*} $b]
  check "cadence F5 keeps plain-F5 highlight" [string match {*apply_hilight*} $b]
}

if {$::fail} { puts "RESULT: FAIL" } else { puts "RESULT: ALL PASS" }
