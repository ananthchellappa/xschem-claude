# RED-first regression for issue 0220 --
#   doc/claude/issues/0220-signal-short-silent-on-nohier-and-dead-highlight.md
#
# Defect A: signal_short() was gated on `xctx->netlist_count`, which stays 0 for the whole run
#   whenever the hierarchy is not descended. `xschem netlist -nohier` (scheduler.c:8145) and the
#   Shift-N current-level netlist (callback.c:6561) therefore merged two differently-named nets
#   and said nothing.  The short IS reported on a default hierarchical netlist -- every backend
#   runs a second prepare_netlist_structs(1) on the reloaded top level -- so that path is a
#   control here, not the defect.
# Defect B: the highlight branch inside signal_short() required `!netlist_count` while the outer
#   gate required `netlist_count`.  Mutually exclusive: shorted nets were never coloured.
#
# Fix: gate on `print_erc` (hoisted to file scope); leave the inner `!netlist_count` alone.
#
# Prerequisite of doc/claude/specs/wire_label_ride.md (S0): signal_short is the only diagnostic
# for a contested-name regression, and every later stage of that spec is blind without it.
# See also issue 0221 -- the record-order-dependent name selection this makes audible.
#
# Pure headless.  Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_signal_short_nohier_0220.tcl
# Prints "RESULT: ALL PASS" / "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

source [file join [file dirname [info script]] scratch.tcl]
set dir [test_scratch sigshort_0220]

# short.sch: two lab_pin instances with DIFFERENT names on ONE wire -- a naming short.
# clean.sch: byte-identical except both labels say AAA.  The single-token difference is what
# keeps the controls honest.
proc build {path labA labB} {
  xschem clear force
  xschem wire 0 0 300 0
  xschem instance {lab_pin.sym} 0   0 0 0 [list name=l1 lab=$labA]
  xschem instance {lab_pin.sym} 300 0 0 0 [list name=l2 lab=$labB]
  xschem instance {res.sym} 100 -100 0 0 {name=R1 value=1k}
  xschem unselect_all
  xschem saveas $path schematic
}
set shortf [file join $dir short.sch]
set cleanf [file join $dir clean.sch]
build $shortf AAA BBB
build $cleanf AAA AAA

# signal_short reports through statusmsg(str,2), which appends to xctx->infowindow_text.
proc erc {file args} {
  xschem clear force
  xschem load $file
  xschem set infowindow_text {}
  eval [linsert $args 0 xschem netlist -erc -messages]
  return [xschem get infowindow_text]
}
proc n_shorts {txt} {
  set n 0
  foreach line [split $txt \n] { if {[string first "shorted:" $line] >= 0} { incr n } }
  return $n
}

# ---------------------------------------------------------------------------
# A. Defect A.  -nohier is the broken path; the hierarchical run is the control that shows the
#    fixture really does short (it reported even before the fix).
# ---------------------------------------------------------------------------
check "A0 hierarchical netlist reports the short (control)" [n_shorts [erc $shortf]]         1
check "A1 -nohier reports the short (defect A)"             [n_shorts [erc $shortf -nohier]] 1

# ---------------------------------------------------------------------------
# B. A clean schematic must stay quiet on BOTH paths.  Without these, "print unconditionally"
#    would pass A (green-but-hollow, WIRING.md §10).
# ---------------------------------------------------------------------------
check "B0 clean schematic, hierarchical -> silent" [n_shorts [erc $cleanf]]         0
check "B1 clean schematic, -nohier      -> silent" [n_shorts [erc $cleanf -nohier]] 0

# ---------------------------------------------------------------------------
# C. Exactly once.  print_erc exists to suppress the second, re-name-only
#    prepare_netlist_structs() pass over the reloaded top level; a hoist that lost that term
#    would double the message on the hierarchical path.  (A0/A1 already assert the count, C
#    states the intent separately so a future change reads the reason.)
# ---------------------------------------------------------------------------
check "C0 not double-printed on the hierarchical path" [n_shorts [erc $shortf]] 1

# ---------------------------------------------------------------------------
# D. Defect B -- the highlight branch is reachable again.
#    Probed through list_hilights (hilight.c:4359), which runs prepare_netlist_structs(1)
#    WITHOUT the netlist backends' traverse_node_hash() pass.  That matters: traverse_node_hash
#    highlights every undriven / open / goes-nowhere net too, so on a netlist run the shorted
#    names would light up whether or not signal_short's branch works.  On this path signal_short
#    is the ONLY thing that can insert into the hilight table, so the check is a real
#    discriminator -- and it also pins the behaviour change issue 0220 flagged as a risk
#    ("restoring reports to the two hilight.c callers"), which is intended, not accidental.
# ---------------------------------------------------------------------------
proc hilight_probe {file} {
  xschem clear force
  xschem load $file
  xschem unhilight_all
  xschem set infowindow_text {}
  set nets [xschem list_hilights all_nets]
  return [list $nets [xschem get infowindow_text]]
}
set p [hilight_probe $shortf]
check "D0 hilight-only pass reports the short"   [n_shorts [lindex $p 1]] 1
check "D1 ... and highlights the first net"      [expr {[string first "AAA" [lindex $p 0]] >= 0}] 1
check "D2 ... and highlights the second net"     [expr {[string first "BBB" [lindex $p 0]] >= 0}] 1
set p [hilight_probe $cleanf]
check "D3 clean schematic: hilight-only pass silent"     [n_shorts [lindex $p 1]] 0
check "D4 clean schematic: nothing highlighted"          [string trim [lindex $p 0]] {}

# ---------------------------------------------------------------------------
# E. prepare_netlist_structs(0) callers stay silent.  print_erc carries the `&& for_netlist`
#    term, so the fluid engine's END invariant check (which runs prepare_netlist_structs(0) on
#    every move) must not start emitting ERC text -- that would make every drag on a schematic
#    with a pre-existing naming short print an error.
# ---------------------------------------------------------------------------
xschem clear force
xschem load $shortf
set fluid_editing 1
xschem set infowindow_text {}
xschem unselect_all
xschem select instance 2
xschem move_objects 0 100
check "E0 a move (prepare_netlist_structs(0)) emits no ERC text" \
      [n_shorts [xschem get infowindow_text]] 0

catch {file delete -force $dir}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
