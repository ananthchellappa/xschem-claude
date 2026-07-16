# Phase 1 (nice_drag_rerouting §8) -- runtime invariant guard at move END.
# move.c fluid_check_move_invariants() runs the P1/P2 no-short/merge check in the interactive
# runtime (gated on fluid_editing, log-only) and publishes the violation count to the Tcl var
# fluid_last_move_violations. This test drives real moves through `xschem move_objects` (the
# byte-identical drag-release path) and asserts the guard's verdict.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_26_phase1_runtime_guard.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}

# --- a CLEAN move keeps every label on its own net -> 0 violations -----------
we_reset 0 1
set cadence_compat 1; set autotrim_wires 1; set fluid_editing 1
xschem wire -100 -60 110 -60
xschem instance devices/res     0 -30 0 1 {name=R7 m=1 value=320}
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}
xschem unselect_all; xschem select instance [inst_by_name l8]
we_move_stretch 0 -50
check "clean move records 0 invariant violations" \
  [expr {[info exists ::fluid_last_move_violations] && $::fluid_last_move_violations == 0}]

# --- a SHORTING move (F5: drag a device pin onto an adjacent net) -> >=1 ------
we_reset 1 1
set cadence_compat 1; set autotrim_wires 1; set fluid_editing 1
xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}
xschem wire 0 30 0 130
xschem instance {lab_pin.sym} 0 130 0 0 {name=LA lab=NETA}
xschem wire 40 30 40 130
xschem instance {lab_pin.sym} 40 130 0 0 {name=LB lab=NETB}
xschem unselect_all; xschem select instance [inst_by_name RA]
we_move_stretch 40 0
check "shorting move flags >=1 invariant violation" \
  [expr {$::fluid_last_move_violations >= 1}]

# --- the guard is GATED: with fluid_editing off it never runs (var not set) ---
unset -nocomplain ::fluid_last_move_violations
we_reset 1 1
set cadence_compat 1; set autotrim_wires 1; set fluid_editing 0
xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}
xschem wire 0 30 0 130
xschem instance {lab_pin.sym} 0 130 0 0 {name=LA lab=NETA}
xschem wire 40 30 40 130
xschem instance {lab_pin.sym} 40 130 0 0 {name=LB lab=NETB}
xschem unselect_all; xschem select instance [inst_by_name RA]
we_move_stretch 40 0
check "guard skipped when fluid_editing off (var not published)" \
  [expr {![info exists ::fluid_last_move_violations]}]

we_result
