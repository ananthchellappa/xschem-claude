# Phase 2 (nice_drag_rerouting §6) -- the escape-normal C getter get_pin_escape_normal(),
# exposed as `xschem pin_escape_normal <inst> name <pin>`. Unit-tested across a spread of real
# symbols and orientations (spec Phase 2: "unit-test the normal across real symbols before
# building routing on it").
#
# issue 0134 (candidate #1): the getter now derives the TRUE outward normal from the symbol LEAD
# geometry (the short connector L line from the body edge to the pin tip) when fluid_editing is on,
# instead of the text-inflated-bbox nearest-edge PROXY. The lead is exact on asymmetric/corner and
# near-centre pins where the proxy ties out or mis-picks; on symmetric symbols the two agree. The
# legacy path (fluid_editing off, the wire_exit_stub feature) keeps the proxy byte-identical, and it
# is still the exact port of the Tcl reference predicates.tcl pin_escape_normal.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_28_escape_normal.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc c_norm {inst pin} { xschem pin_escape_normal $inst name $pin }   ;# the C getter

# --- absolute normals, rot 0 (fluid on: the real routing mode; lead-accurate) ---------------
set ::fluid_editing 1
we_reset 0 0
xschem instance devices/res 0 0 0 0 {name=RA}       ;# pins P(0,-30) M(0,30)
check "res pin M -> +Y (up)"   [expr {[c_norm RA M] eq {0 1}}]
check "res pin P -> -Y (down)" [expr {[c_norm RA P] eq {0 -1}}]

we_reset 0 0
xschem instance devices/nmos4 0 0 0 0 {name=M1}      ;# d(20,-30) g(-20,0) s(20,30) b(20,0)
check "nmos4 gate g -> -X (left)"   [expr {[c_norm M1 g] eq {-1 0}}]
check "nmos4 source s -> +Y (up)"   [expr {[c_norm M1 s] eq {0 1}}]
check "nmos4 drain d -> -Y (down)"  [expr {[c_norm M1 d] eq {0 -1}}]
# bulk b: its lead (L 4 10 0 20 0) points +X -- east, the SAME side as d and s, the TRUE outward
# normal. The nearest-edge proxy mis-picks -Y for this near-centre pin (0134); the lead corrects it.
check "nmos4 bulk b -> +X (lead-correct, proxy said -Y)" [expr {[c_norm M1 b] eq {1 0}}]
we_reset 0 0
xschem instance devices/nmos4 0 0 1 0 {name=M1}      ;# rot1: symbol +X lead -> world +Y
check "nmos4 bulk b rot1 -> +Y (lead rotates cleanly)" [expr {[c_norm M1 b] eq {0 1}}]

# --- unresolved / missing pin -> empty (no crash) ---------------------------
we_reset 0 0
xschem instance devices/nmos4 0 0 0 0 {name=M1}
check "missing pin -> empty" [expr {[c_norm M1 NOSUCH] eq {}}]

# --- LEGACY path fidelity: with fluid_editing OFF the C getter must equal the Tcl reference
#     (predicates.tcl pin_escape_normal, the nearest-edge proxy) for every pin across all
#     orientations -- byte-identical, forever. This is the port-fidelity regression guard for the
#     legacy wire_exit_stub path; my 0134 change must not touch it. ---------------------------
set ::fluid_editing 0
foreach {rot flip} {0 0  1 0  2 0  3 0  0 1  2 1} {
  we_reset 0 0
  xschem instance devices/res 0 0 $rot $flip {name=RA}
  foreach pin {P M} {
    check "legacy: res rot$rot flip$flip $pin: C proxy == Tcl reference" \
      [expr {[c_norm RA $pin] eq [pin_escape_normal RA $pin]}]
  }
  we_reset 0 0
  xschem instance devices/nmos4 0 0 $rot $flip {name=M1}
  foreach pin {d g s b} {
    check "legacy: nmos4 rot$rot flip$flip $pin: C proxy == Tcl reference" \
      [expr {[c_norm M1 $pin] eq [pin_escape_normal M1 $pin]}]
  }
}

# --- FLUID path accuracy + DOCUMENTED divergence: with fluid_editing ON the lead getter agrees
#     with the proxy on symmetric symbols and clean edge pins (no regression), and DIVERGES from
#     (correcting) the proxy on the near-centre bulk pin in EVERY orientation. This section is RED
#     on the pre-0134 all-proxy binary (there C always == proxy, so "lead != proxy" is false). --
set ::fluid_editing 1
foreach {rot flip} {0 0  1 0  2 0  3 0  0 1  2 1} {
  we_reset 0 0
  xschem instance devices/res 0 0 $rot $flip {name=RA}    ;# symmetric: lead == proxy
  foreach pin {P M} {
    check "fluid: res rot$rot flip$flip $pin: lead == proxy (symmetric, no regression)" \
      [expr {[c_norm RA $pin] eq [pin_escape_normal RA $pin]}]
  }
  we_reset 0 0
  xschem instance devices/nmos4 0 0 $rot $flip {name=M1}
  foreach pin {d g s} {                                    ;# clean edge pins: lead == proxy
    check "fluid: nmos4 rot$rot flip$flip $pin: lead == proxy (clean edge pin)" \
      [expr {[c_norm M1 $pin] eq [pin_escape_normal M1 $pin]}]
  }
  # bulk b: lead corrects the proxy's near-centre mis-pick -> the two DIVERGE.
  check "fluid: nmos4 rot$rot flip$flip b: lead != proxy (0134 correction)" \
    [expr {[c_norm M1 b] ne [pin_escape_normal M1 b]}]
}

we_result
