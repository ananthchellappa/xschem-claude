# incremental_wire_reroute.md Layer 2 -- BOTH-ORIENTATIONS-BLOCKED rip-up-and-reroute detour.
#
# Layer 1 (Phase III, test_34) flips the manhattan L when ONE orientation bridges a stationary
# device and the OTHER is clear. When BOTH orientations are blocked the flip DECLINES and the naive
# route lays a leg straight across a device between two of its distinct-net pins -> a P2 device short
# with only a log-only warning. Layer 2 closes that gap: at the pre-trim seam it re-detects the
# residual single-wire straddle and rips it up, routing the moving pin's riser AROUND the device to
# a column one grid outside the same-net pin, landing on the anchor net with a visible junction and
# never continuing across the device.
#
# Two shapes, both RED @ ffe5f092 (they short today), GREEN after Layer 2:
#   (a) STRAIGHT-THROUGH: a moved pin lands on the device's pin row (degenerate L, unflippable) so
#       the follow leg sweeps end-to-end through the device. Driven BOTH stepwise (per-snap
#       move_objects RUBBER) and one-shot release; the two must agree AND be no-short.
#   (b) BOXED: the natural (below-row) detour is itself blocked by a second obstacle, so the reroute
#       must take the other (above-row) side -- the "boxed between two devices" case.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_36_both_blocked_detour.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap $inst]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}
proc point_on_any_wire {x y} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 == $x2 && $x == $x1 && $y >= min($y1,$y2) && $y <= max($y1,$y2)} { return 1 }
    if {$y1 == $y2 && $y == $y1 && $x >= min($x1,$x2) && $x <= max($x1,$x2)} { return 1 }
  }
  return 0
}
proc gates {} {
  uplevel #0 {set cadence_compat 1}; uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}; uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}; uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
}

# ---- shape (a): straight-through -----------------------------------------------------------------
# v8 ammeter (rot3): plus=(-390,140) net NA, minus=(-330,140) net NB, body x in [-392.5,-327.5].
# NA anchor bus extends left of plus (to -550); NB stubs DOWN off the row. RM's M riser rises to the
# bus corner at (-420,140). Dragging RM by (+110,+60) lands M at (-310,140) -- ON the bus row, right
# of v8 -- so the follow leg is a single horizontal wire sweeping through v8 (degenerate L => no flip
# possible). The clear detour side is BELOW (y<112).
proc setup_a {} {
  xschem clear force
  gates
  xschem instance devices/ammeter -360 140 3 0 {name=v8}
  xschem wire -550 140 -420 140
  xschem wire -420 140 -390 140
  xschem instance devices/lab_pin -550 140 0 0 {lab=NA name=lna}
  xschem wire -330 140 -330 80
  xschem instance devices/lab_pin -330 80 0 0 {lab=NB name=lnb}
  xschem instance devices/res -420 50 0 0 {name=RM m=1 value=100}
  xschem wire -420 80 -420 140
}
proc assert_a {tag before} {
  check "$tag P2: v8.plus(NA) and v8.minus(NB) resolve DISTINCT (ammeter not shorted)" \
    [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
  check "$tag P2: device-pin-merge detector passes" [p2_no_device_merge $before]
  check "$tag style: no wire crosses v8 body centre (-360,140)" [expr {![point_on_any_wire -360 140]}]
  check "$tag style: nothing bridges strictly between the pins at (-350,140)" \
    [expr {![point_on_any_wire -350 140]}]
  check "$tag conn: a wire still reaches v8.plus (-390,140)" [point_on_any_wire -390 140]
  check "$tag P1: RM.M still reaches NA (same net as v8.plus)" \
    [expr {[pinnet RM M] eq [pinnet v8 plus]}]
  check "$tag P1: RM.M is NA" [expr {[pinnet RM M] eq {NA}}]
  check "$tag P1: v8.minus restored to NB" [expr {[pinnet v8 minus] eq {NB}}]
  check "$tag P1: RM.P still on its own net (#net*, distinct from M)" \
    [expr {[pinnet RM P] ne [pinnet RM M] && [pinnet RM P] ne {}}]
}

# Drive 1: one-shot release
setup_a
set beforeA [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 110 60
set segReleaseA [segset]
assert_a "a/release:" $beforeA

# Drive 2: stepwise (per-snap RUBBER; restore-and-reapply total delta each step)
setup_a
set beforeA2 [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {20 10  40 25  60 35  80 45  100 55  110 60} { xschem move_objects step $sx $sy }
xschem move_objects end 110 60
set segStepA [segset]
assert_a "a/stepwise:" $beforeA2

check "a: release == stepwise (committed route identical both ways)" [expr {$segStepA eq $segReleaseA}]

# ---- shape (b): boxed (below-detour blocked -> reroute goes above) --------------------------------
# Same as (a) plus v9 straddling the BELOW detour row (y~110) between two distinct nets NC/ND, so the
# natural below detour would short v9. The reroute must take the ABOVE side (y>147.5) instead.
proc setup_b {} {
  setup_a
  xschem instance devices/ammeter -360 110 3 0 {name=v9}
  xschem wire -390 110 -390 70
  xschem instance devices/lab_pin -390 70 0 0 {lab=NC name=lnc}
  xschem wire -330 110 -330 60
  xschem instance devices/lab_pin -330 60 0 0 {lab=ND name=lnd}
}
setup_b
set beforeB [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 110 60
check "b P2: v8 not shorted (plus NA != minus NB)" [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
check "b P2: v9 not shorted by the detour (plus NC != minus ND)" \
  [expr {[pinnet v9 plus] ne [pinnet v9 minus]}]
check "b P2: device-pin-merge detector passes (no device merged)" [p2_no_device_merge $beforeB]
check "b P1: RM.M still reaches NA" [expr {[pinnet RM M] eq {NA}}]
check "b style: no wire crosses v8 body centre (-360,140)" [expr {![point_on_any_wire -360 140]}]
check "b style: no wire crosses v9 body centre (-360,110)" [expr {![point_on_any_wire -360 110]}]

# ---- shape (c): a FOREIGN wire T's onto the natural (below) detour row -> reroute takes above ------
# The detour must never make a stray junction onto another net's wire. NX's endpoint lands on the
# below detour row (y=110) inside the detour span, so the below legs would merge NX into NA. The
# reroute must instead take the ABOVE side; NX and v8 both stay un-shorted. (getprop wire lab, not the
# label-echoing pinnet, is the reliable net-merge probe for a label net.)
proc net_of_wire_at {x y} {
  xschem resolved_net 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {($x1==$x && $y1==$y) || ($x2==$x && $y2==$y)} { return [xschem getprop wire $i lab] }
  }
  return {}
}
setup_a
xschem wire -350 110 -350 60
xschem instance devices/lab_pin -350 60 0 0 {lab=NX name=lnx}
set beforeC [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 110 60
check "c P2: v8 not shorted (plus NA != minus NB)" [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
check "c P2: foreign NX wire NOT merged into NA (stray-contact guard)" \
  [expr {[net_of_wire_at -350 60] ne [net_of_wire_at -390 140]}]
check "c P2: device-pin-merge detector passes" [p2_no_device_merge $beforeC]
check "c P1: RM.M still reaches NA" [expr {[pinnet RM M] eq {NA}}]
check "c route: detour took the ABOVE row (a leg passes (-350,150))" [point_on_any_wire -350 150]

# ---- shape (d): BOTH detour rows blocked by foreign wires -> clean DECLINE (never worse) -----------
# Foreign wires T onto BOTH the below (y=110) and above (y=150) rows in the detour span. No safe
# detour exists, so Layer 2 declines: the baseline v8 short remains, but NO NEW foreign net is merged
# (never worse than fluid-off) -- P2's "the router may not introduce a short it could avoid" holds by
# leaving the pre-existing one untouched and adding nothing.
setup_a
xschem wire -350 110 -350 60
xschem instance devices/lab_pin -350 60 0 0 {lab=NX name=lnx}
xschem wire -350 150 -350 200
xschem instance devices/lab_pin -350 200 0 0 {lab=NY name=lny}
set beforeD [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 110 60
check "d never-worse: foreign NX stays distinct from NA (no stray merge below)" \
  [expr {[net_of_wire_at -350 60] ne [net_of_wire_at -390 140]}]
check "d never-worse: foreign NY stays distinct from NA (no stray merge above)" \
  [expr {[net_of_wire_at -350 200] ne [net_of_wire_at -390 140]}]

# ---- shape (e): VERTICAL straddle (axis-generic path; transpose of shape a) ------------------------
# ammeter rot0 has vertically-stacked pins (plus=(140,-390), minus=(140,-330)); the follow riser
# sweeps straight DOWN the x=140 column through v8. The detour must work along the other axis (route
# sideways around the body). Proves the horiz/vert generalisation and the insert_exit_stubs interplay.
proc setup_e {} {
  xschem clear force
  gates
  xschem instance devices/ammeter 140 -360 0 0 {name=v8}
  xschem wire 140 -550 140 -420; xschem wire 140 -420 140 -390
  xschem instance devices/lab_pin 140 -550 0 0 {lab=NA name=lna}
  xschem wire 140 -330 80 -330; xschem instance devices/lab_pin 80 -330 0 0 {lab=NB name=lnb}
  xschem instance devices/res 80 -450 0 0 {name=RM m=1 value=100}
  xschem wire 80 -420 140 -420
}
setup_e
set beforeE [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 60 110
check "e P2: v8 not shorted (plus NA != minus NB)" [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
check "e P2: device-pin-merge detector passes" [p2_no_device_merge $beforeE]
check "e P1: RM.M still reaches NA" [expr {[pinnet RM M] eq {NA}}]
check "e P1: v8.minus restored to NB" [expr {[pinnet v8 minus] eq {NB}}]
check "e style: no wire crosses v8 body centre (140,-360)" [expr {![point_on_any_wire 140 -360]}]

# ---- shapes (f)/(g): landing must NOT tear the moving pin off its net (adversarial review wf_838ec39f)
# The up-leg lands AT the same-net device pin (always NF, connected) and only shifts one grid outward
# when a real NF wire covers the pin->offset span. Two confirmed-disconnect fixtures the earlier
# net-blind landing broke:
#   (f) the follow riser runs STRAIGHT to plus (no bus past the pin); NA continues UP off plus. The
#       old code landed one grid BEYOND plus on a transient/degenerate match -> M torn onto a floating
#       #net. Now it lands AT plus.
#   (g) same, plus an isolated FOREIGN-net wire ending exactly at the offset column C. The old code
#       landed on it -> M shorted onto the foreign net. Now it lands AT plus, foreign net untouched.
proc setup_fg {foreign} {
  xschem clear force
  gates
  xschem instance devices/ammeter -360 140 3 0 {name=v8}
  xschem wire -390 140 -390 220
  xschem instance devices/lab_pin -390 220 0 0 {lab=NA name=lna}
  xschem wire -330 140 -330 80; xschem instance devices/lab_pin -330 80 0 0 {lab=NB name=lnb}
  xschem instance devices/res -390 50 0 0 {name=RM m=1 value=100}
  xschem wire -390 80 -390 140
  if {$foreign} { xschem wire -400 140 -400 90; xschem instance devices/lab_pin -400 90 0 0 {lab=FOR name=lfor} }
}
setup_fg 0
set beforeF [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 120 60
check "f P1: RM.M NOT disconnected (still on plus's net NA)" [expr {[pinnet RM M] eq [pinnet v8 plus]}]
check "f P1: RM.M is NA" [expr {[pinnet RM M] eq {NA}}]
check "f P2: v8 not shorted (plus NA != minus NB)" [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
check "f P2: device-pin-merge detector passes" [p2_no_device_merge $beforeF]

setup_fg 1
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 120 60
check "g P2: foreign FOR net NOT captured by the up-leg (RM.M != FOR wire net)" \
  [expr {[pinnet RM M] ne [net_of_wire_at -400 90]}]
check "g P1: RM.M still on NA (not torn onto FOR)" [expr {[pinnet RM M] eq {NA}}]
check "g P2: v8 not shorted" [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]

# ---- shape (h): the MOVING device's OWN co-dragged pins must not be plowed onto NF -----------------
# A rigidly-dragged multi-terminal device (nmos4) carries its gate/bulk/drain to fixed offsets near
# the follow pin (source). The detour must route around them: a leg crossing a co-moving pin solders
# it onto NF -> a new device short (gate=source). The reroute takes the clear (above) side instead.
# (Confirmed P2-short in adversarial re-review wf_582991bf; RED before the moving-pin guard.)
proc pins {n} { xschem resolved_net 0; set r [dict create]; foreach {p nn} [lrange [xschem instance_nodemap $n] 1 end] { dict set r $p $nn }; return $r }
xschem clear force
gates
xschem instance devices/ammeter -360 140 3 0 {name=v8}
xschem wire -550 140 -420 140; xschem wire -420 140 -390 140
xschem instance devices/lab_pin -550 140 0 0 {lab=NA name=lna}
xschem wire -330 140 -330 80; xschem instance devices/lab_pin -330 80 0 0 {lab=NB name=lnb}
xschem instance devices/nmos4 -440 50 0 0 {name=RM model=nmos w=5u l=0.18u m=1}
xschem wire -420 80 -420 140
set beforeH [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]
we_move_stretch 110 60
set H [pins RM]
check "h P1: RM.s (follow pin) reaches NA" [expr {[dict get $H s] eq {NA}}]
check "h P2: RM.g NOT merged onto source net (gate stays distinct)" \
  [expr {[dict get $H g] ne [dict get $H s]}]
check "h P2: RM.b NOT merged onto source net (bulk stays distinct)" \
  [expr {[dict get $H b] ne [dict get $H s]}]
check "h P2: RM.d stays distinct from source" [expr {[dict get $H d] ne [dict get $H s]}]
check "h P2: device-pin-merge detector passes (no device merged)" [p2_no_device_merge $beforeH]
check "h P2: v8 (the target) IS un-shorted (plus NA != minus NB)" \
  [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]

# ---- shape (i): a co-dragged pin sub-grid-near M must NOT be exempted as M ------------------------
# The follow-pin (M) exemption in the moving-pin guard is EXACT-coincidence, not cadsnap/2 tolerance:
# a DISTINCT co-dragged pin landing within cadsnap/2 of M (here an off-grid label FX landing at
# (-310,135), 5 units below M=(-310,140)) must not be soldered onto NF. Because FX brackets both detour
# risers (on the below one; within tolerance of the above one's start), the reroute cleanly DECLINES to
# the baseline -- FX stays floating, never merged onto NA (adversarial re-review wf_eade2790, RED with
# the old point_near_pin exemption). "Never worse than fluid-off" is the invariant here, not a fixed v8.
xschem clear force
gates
xschem instance devices/ammeter -360 140 3 0 {name=v8}
xschem wire -550 140 -420 140; xschem wire -420 140 -390 140
xschem instance devices/lab_pin -550 140 0 0 {lab=NA name=lna}
xschem wire -330 140 -330 80; xschem instance devices/lab_pin -330 80 0 0 {lab=NB name=lnb}
xschem instance devices/res -420 50 0 0 {name=RM m=1 value=100}
xschem wire -420 80 -420 140
xschem instance devices/lab_pin -420 75 0 0 {lab=FX name=lfx}   ;# off-grid: lands (-310,135), 5u from M
set beforeI [dev_pin_map]
xschem unselect_all; xschem select instance [inst_by_name RM]; xschem select instance [inst_by_name lfx]
we_move_stretch 110 60
check "i P2: FX (co-pin 5u from M) NOT soldered onto the follow net (its pin carries no wire)" \
  [expr {![point_on_any_wire -310 135]}]
check "i P1: RM.M still on NA" [expr {[pinnet RM M] eq {NA}}]
# never-worse: the ONLY device merge is v8's pre-existing baseline short (present with fluid OFF too);
# no foreign device is newly merged. (FX is a label -- its merge shows as a soldered wire, asserted above.)
check "i never-worse: no device short beyond v8's baseline (RM's own pins stay distinct)" \
  [expr {[pinnet RM M] ne [pinnet RM P]}]

we_result
