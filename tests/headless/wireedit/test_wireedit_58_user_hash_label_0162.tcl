# issue 0162 -- a USER-authored `#` net name must get the same protection as any other name.
#
# The fluid label guards read `lab[0] != '#'` as "user-authored, protect it":
#   fluid_wire_explicit_lab()  (move.c ~:2945) -- the universal hard decline for named copper
#   fluid_loop_eligible()      (move.c ~:3196) -- the H2 sole-carrier doom guard
# Both predate the issue-0156 policy that `#` is RESERVED for the engine. A user CAN still have
# a `lab=#foo` net in an existing file (nothing rewrites it; only addlabel::name_ok blocks NEW
# ones), and for such a net these guards conclude the copper is engine-generated and disposable.
# So a reshape/collapse treats a real user net as scratch copper. WIRING.md open risk 15.
#
# The fix swaps both tests to `is_auto_net_name()` (netlist.c) = strictly `#net<digits>`, which
# is the only thing the engine actually generates.
#
# The discriminator in every case below is a THREE-way comparison, because the fix must move
# `#foo` WITHOUT moving `#net<N>` (rule 8a: what does the new guard over-protect?):
#   VDD / FOO   an ordinary name  -> protected, today and after
#   #foo        a user `#` name   -> NOT protected today (the defect), protected after
#   #net99      an engine name    -> NOT protected, today and after (must not change)
#
# Case A (fluid_wire_explicit_lab, issue-0105 topology + the 0123/B3 enforcement gate):
#   R18 dragged (-90,-40) drops both pins on a named backbone -> device self-short. Every
#   de-shorter blackouts on named copper, so the short is unrepairable and the END gate REFUSES
#   the move (geometry byte-identical). With `lab=#foo` the blackout does not fire: the jog
#   reshapes the user's net instead (measured: 16 -> 17 wires, the y=-40 backbone rebuilt as a
#   y=-50 jog).
# Case B (fluid_loop_eligible H2, issue-0088 topology):
#   with the label on the (-420,-90) corner, the redundant rectangle is NOT collapsed for a
#   named net (the sole-carrier guard) but IS collapsed for `#foo` (measured: 10 -> 8 wires,
#   two of the user's four wires deleted).
#
# True headless:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_58_user_hash_label_0162.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap [inst_by_name $inst]]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}
# canonical, endpoint-order-independent snapshot of every wire span + its resolved lab
proc wireset {} {
  xschem resolved_net 0
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 > $x2 || ($x1 == $x2 && $y1 > $y2)} { lassign [list $x2 $y2 $x1 $y1] x1 y1 x2 y2 }
    lappend L [list $x1 $y1 $x2 $y2 [xschem getprop wire $i lab]]
  }
  return [lsort $L]
}
# spans of the wires resolving to net $want, canonicalized
proc spans_on_net {want} {
  set out {}
  foreach w [wireset] {
    if {[lindex $w 4] eq $want} { lappend out [lrange $w 0 3] }
  }
  return [lsort $out]
}

# --- Case A fixture: 0105 topology, the y=-40 backbone named by a lab_pin -------------------
proc setupA {lab} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 0}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  uplevel #0 {set fluid_enforce_invariants 1}
  xschem instance devices/capa    -320 -190 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res      -40    0 3 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  xschem instance devices/lab_pin -200  -40 0 0 [list name=lvdd lab=$lab]
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140} {-550 140 -400 140}
    {-400 140 -390 140} {-400 -40 -400 140} {-320 -300 -320 -220} {-420 -300 -320 -300}
    {-320 -160 -320 -150} {-320 -150 -80 -150} {-400 -40 0 -40} {-80 -150 -80 0}
    {0 -40 0 0} {-80 0 -70 0} {-10 0 0 0}
  } { xschem wire {*}$w }
}
# run case A for one label; returns {untouched pins_distinct}
proc runA {lab} {
  setupA $lab
  set w0 [wireset]
  xschem unselect_all; xschem select instance [inst_by_name R18]
  xschem move_objects -90 -40 stretch kissing
  return [list [expr {$w0 eq [wireset]}] [expr {[pinnet R18 P] ne [pinnet R18 M]}]]
}

lassign [runA VDD] a_vdd_untouched a_vdd_distinct
check "A1 (control) an ordinary name is a repair blackout -> the move is REFUSED, geometry\
 byte-identical" $a_vdd_untouched
check "A1b (control) ... and the device is not shorted" $a_vdd_distinct

lassign [runA {#foo}] a_hash_untouched a_hash_distinct
check "A2 a user '#foo' net gets the SAME blackout -> REFUSED, geometry byte-identical" \
  $a_hash_untouched
check "A2b ... and the device is not shorted" $a_hash_distinct

lassign [runA {#net99}] a_auto_untouched a_auto_distinct
check "A3 (control, anti-over-protection) an ENGINE '#net99' net is still reshapeable -> the\
 repair runs and the geometry changes" [expr {!$a_auto_untouched}]
check "A3b (control) ... and that repair leaves the device unshorted" $a_auto_distinct

# --- Case B fixture: 0088 topology, the label on the (-420,-90) rectangle corner ------------
proc setupB {lab} {
  xschem clear force
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 1}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
  xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res     -400  -40 0 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140} {-400 -10 -400 140}
    {-420 -90 -400 -90} {-550 140 -400 140} {-400 140 -390 140} {-420 -170 -420 -90}
    {-400 -90 -400 -70}
  } { xschem wire {*}$w }
  xschem instance devices/lab_pin -420 -90 0 0 [list name=lp1 lab=$lab]
}
# run case B for one label; returns the labeled net's surviving spans
proc runB {lab} {
  setupB $lab
  xschem unselect_all; xschem select instance [inst_by_name R18]
  xschem move_objects -20 -60 stretch kissing
  return [spans_on_net $lab]
}

## the four spans a NAMED net keeps (coords only -- the net name is the filter): the loop is
## left alone, the sole-carrier guard wins
set B_KEPT [lsort [list \
  [list -420 -170 -420 -130] \
  [list -420 -130 -400 -130] \
  [list -420 -90 -400 -90] \
  [list -400 -130 -400 -90]]]

set b_foo [runB FOO]
check "B1 (control) an ordinary name keeps all four loop wires (H2 sole-carrier guard)" \
  [expr {$b_foo eq $B_KEPT}]

set b_hash [runB {#foo}]
check "B2 a user '#foo' net keeps them too -- the loop collapse must not doom user copper" \
  [expr {$b_hash eq $B_KEPT}]

set b_auto [runB {#net99}]
check "B3 (control, anti-over-protection) an ENGINE '#net99' loop still collapses to the two\
 riser wires" [expr {[llength $b_auto] == 2}]

we_result
