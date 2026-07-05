# Phase 2 (nice_drag_rerouting §6) -- the escape-normal C getter get_pin_escape_normal(),
# exposed as `xschem pin_escape_normal <inst> name <pin>`. Geometry-only (nearest body edge),
# per the resolved §10.1 decision. Unit-tested across a spread of real symbols and orientations
# (spec Phase 2: "unit-test the normal across real symbols before building routing on it").
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_28_escape_normal.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc c_norm {inst pin} { xschem pin_escape_normal $inst name $pin }   ;# the C getter

# --- absolute normals, rot 0 ------------------------------------------------
we_reset 0 0
xschem instance devices/res 0 0 0 0 {name=RA}       ;# pins P(0,-30) M(0,30)
check "res pin M -> +Y (up)"   [expr {[c_norm RA M] eq {0 1}}]
check "res pin P -> -Y (down)" [expr {[c_norm RA P] eq {0 -1}}]

we_reset 0 0
xschem instance devices/nmos4 0 0 0 0 {name=M1}      ;# d(20,-30) g(-20,0) s(20,30) b(20,0)
check "nmos4 gate g -> -X (left)"   [expr {[c_norm M1 g] eq {-1 0}}]
check "nmos4 source s -> +Y (up)"   [expr {[c_norm M1 s] eq {0 1}}]
check "nmos4 drain d -> -Y (down)"  [expr {[c_norm M1 d] eq {0 -1}}]
# bulk b is a near-centre pin -- ambiguous normal is ACCEPTED (crude by design); it must still
# resolve to SOME unit axis vector, not garbage.
check "nmos4 bulk b -> some axis vector" [expr {[c_norm M1 b] in {{0 1} {0 -1} {1 0} {-1 0}}}]

# --- unresolved / missing pin -> empty (no crash) ---------------------------
check "missing pin -> empty" [expr {[c_norm M1 NOSUCH] eq {}}]

# --- port fidelity: the C getter must equal the Tcl reference (predicates.tcl
#     pin_escape_normal) for every pin across all orientations. Both read the same
#     world bbox + world pin coord, so rotation/flip must agree. --------------
foreach {rot flip} {0 0  1 0  2 0  3 0  0 1  2 1} {
  we_reset 0 0
  xschem instance devices/res 0 0 $rot $flip {name=RA}
  foreach pin {P M} {
    check "res rot$rot flip$flip $pin: C getter == Tcl reference" \
      [expr {[c_norm RA $pin] eq [pin_escape_normal RA $pin]}]
  }
  we_reset 0 0
  xschem instance devices/nmos4 0 0 $rot $flip {name=M1}
  foreach pin {d g s b} {
    check "nmos4 rot$rot flip$flip $pin: C getter == Tcl reference" \
      [expr {[c_norm M1 $pin] eq [pin_escape_normal M1 $pin]}]
  }
}

we_result
