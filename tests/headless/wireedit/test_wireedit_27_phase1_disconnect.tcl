# Phase 1 (nice_drag_rerouting §8) -- runtime DISCONNECT guard (P1) at move END.
# move.c snapshots the instance-pin net partition at move START and compares it at END; a pin
# that changed net group is a possible disconnect. The compare uses a canonical first-seen
# relabeling keyed to pin POSITION, so a pure #net rename (same groups) must NOT flag. Count
# is published to Tcl var fluid_last_move_disconnects.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_27_phase1_disconnect.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}

# --- a connectivity-preserving STRETCH move -> 0 disconnects ----------------
we_reset 1 1
set fluid_editing 1
xschem instance devices/res 0 0 0 0 {name=RA}      ;# pins P(0,-30) M(0,30)
xschem wire 0 30 0 130
xschem instance {lab_pin.sym} 0 130 0 0 {name=LM lab=NETM}
xschem unselect_all; xschem select instance [inst_by_name RA]
we_move_stretch 40 0                                ;# wire follows -> connectivity kept
check "stretch move (connectivity preserved) flags 0 disconnects" \
  [expr {[info exists ::fluid_last_move_disconnects] && $::fluid_last_move_disconnects == 0}]

# --- NO FALSE POSITIVE on an unnamed #net whose name may change -------------
we_reset 1 1
set fluid_editing 1
xschem instance devices/res 0 0   0 0 {name=RA}     ;# RA.M (0,30)
xschem instance devices/res 0 200 0 0 {name=RB}     ;# RB.P (0,170)
xschem wire 0 30 0 170                              ;# RA.M--RB.P on an UNNAMED net (#net)
xschem unselect_all; xschem select instance [inst_by_name RA]
we_move_stretch 40 0                                ;# reroutes; partition unchanged
check "stretch of an unnamed #net flags 0 disconnects (no rename false-positive)" \
  [expr {$::fluid_last_move_disconnects == 0}]

# --- a RIGID move that tears a pin off its wire -> >=1 disconnect -----------
we_reset 1 1
set fluid_editing 1
xschem instance devices/res 0 0 0 0 {name=RA}
xschem wire 0 30 0 130
xschem instance {lab_pin.sym} 0 130 0 0 {name=LM lab=NETM}
xschem unselect_all; xschem select instance [inst_by_name RA]
we_move 40 0                                        ;# RIGID (no stretch): pin M leaves the wire
check "rigid move tearing a pin off its net flags >=1 disconnect" \
  [expr {$::fluid_last_move_disconnects >= 1}]

we_result
