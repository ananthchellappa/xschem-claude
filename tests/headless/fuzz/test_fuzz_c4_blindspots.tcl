# Hardening sprint Track C / step C4 -- blind-spot fixtures as XFAIL TRIPWIRES.
# Spec: doc/claude/suggestions/hardening_sprint_plan.md (C4); WIRING.md §11 (open risks).
#
# Four fixtures, each ONE edit from before_8 (built in harness.tcl as c4_* in-memory builders,
# so the sweep can run them: FUZZ_FIXTURES=c4_transistor, FUZZ_TARGET=lx, the `mixed` gesture).
# Each targets a KNOWN blind spot and currently produces a non-GREEN verdict. This file PINS
# that verdict as an xfail tripwire (the 0104 mechanism, WIRING.md §0.6): the check asserts the
# CURRENT reality, so if the engine later changes the outcome -- most importantly a blind spot
# getting REPAIRED (flip to GREEN) -- the test FAILS loudly, telling you to update the baseline.
# An xfail flip is a SIGNAL, never a silent pass.
#
# Note the shipped default (B3 enforcement ON) MITIGATES most of these to REFUSED (the short is
# refused, geometry left pristine) rather than a saved RED -- so the xfail baseline distinguishes
# "repaired route" (GREEN, the goal), "refused move" (REFUSED, B3 caught it, repair still owed),
# and "saved corruption" (RED, an ENFORCEMENT GAP). The enforce-OFF column shows the raw router's
# corruption the same drop would save without B3.
#
# True headless:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/fuzz/test_fuzz_c4_blindspots.tcl
source [file join [file dirname [info script]] harness.tcl]

# xfail tripwire: run the drop under enforcement mode $enf; assert the verdict == the pinned
# baseline. A mismatch fails -- and the message says whether the blind spot was (likely) FIXED.
proc xfail {risk label fixture gesture enf expect} {
  set ::fuzz_enforce $enf
  set d [fuzz_drop $fixture $gesture]
  set got [dict get $d verdict]
  set ok [expr {$got eq $expect}]
  set note ""
  if {!$ok} {
    if {$got eq "GREEN"} { set note "  <-- TRIPWIRE: blind spot may be FIXED; if intended, re-baseline to GREEN" } \
    else                 { set note "  <-- TRIPWIRE: outcome changed ($expect -> $got); re-check the risk + re-baseline" }
  }
  check "risk #$risk (enf=$enf): $label == $expect (got $got, fails={[dict get $d fails]})$note" $ok
}

# --- risk #1: named-rail blackout (WIRING.md §11.1). A short onto lab_pin VDD is unrepairable
# (de-shorters blackout on explicit-lab copper); B3 REFUSES it, repair still owed. -------------
xfail 1 "labeled_rail: drag R18 onto the VDD backbone" \
  c4_labeled_rail {target R18 type stretch dx -40 dy -40} 1 REFUSED
xfail 1 "labeled_rail: same drag, B3 OFF -> the short SAVES" \
  c4_labeled_rail {target R18 type stretch dx -40 dy -40} 0 RED

# --- risk #3: multi-pin device (WIRING.md §11.3). nmos non-axis pin pairs + a 4-pin follow set
# the 2-pin logic doesn't cover. Two faces: -----------------------------------------------------
#  (3a) drag R18 so a leg shorts M1's pins -> B3 REFUSES.
xfail 3 "transistor: drag R18, a leg shorts nmos pins" \
  c4_transistor {target R18 type stretch dx -40 dy -40} 1 REFUSED
#  (3b) drag the NMOS ITSELF -> its pins DISCONNECT (P1). B3 does NOT refuse disconnects
#       (WIRING.md §9: disconnect is log-only) -> a saved P1 corruption RED *even under B3*.
#       This is an ENFORCEMENT GAP the sweep surfaces -- the headline C4 find.
xfail 3 "transistor: drag the nmos itself -> pin DISCONNECT escapes B3" \
  c4_transistor {target M1 type stretch dx 20 dy -80} 1 RED

# --- risk #5: 1-pin label mover (WIRING.md §11.5). Dragging a lab_pin (no owner pass) onto
# foreign copper bridges nets; B3 REFUSES the merge. ------------------------------------------
xfail 5 "netlabel: drag the label lx onto the backbone" \
  c4_netlabel {target lx type stretch dx -40 dy -40} 1 REFUSED
xfail 5 "netlabel: same drag, B3 OFF -> the merge SAVES" \
  c4_netlabel {target lx type stretch dx -40 dy -40} 0 RED

# --- risk #2: mixed selection (WIRING.md §11.2, pairs with B2). R18 + a decoy wire selected
# (fluid_startsel_wires>0). B2 armed the safety net: a degenerate pure-axis plow is REFUSED, a
# repairable diagonal lands (may be AMBER on route quality). --------------------------------
xfail 2 "mixed: pure-axis plow is caught (B2 net + B3 refuse)" \
  c4_mixed {target R18 type mixed dx -40 dy -40} 1 REFUSED
xfail 2 "mixed: a landing drop keeps a route-quality AMBER" \
  c4_mixed {target R18 type mixed dx 60 dy 60} 1 AMBER

we_result
