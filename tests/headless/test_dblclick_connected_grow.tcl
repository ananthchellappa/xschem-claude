# Cadence double-click incremental connected-select -- engine, subcommand, gesture.
# doc/claude/specs/dblclick_connected_select.md
#
# `xschem select_grow_connected [x y]` runs ONE escalation step keyed on a seed:
#   1st call on a seed -> ring1 (seed + directly-touching wire segments)
#   2nd  -> ring2 (one more ring)
#   3rd  -> whole net (geometric flood)
#   4th+ -> no-op (already whole)
# and, since the ruling of 2026-11-21, every step also takes the NET-NAME LABELS whose
# pin touches a wire it selected (lab_pin, lab_wire and the other symbols of type
# `label` that carry no `global`; not vdd/gnd, not ports, probes or devices).
# A different seed, or an external selection change, resets the escalation.
#
# TWO ARMS. The command forms need no X window: they pick with the same code as
# `xschem select_at` and draw only when there is something to draw on. So the engine
# rows (T1-T6, every L row that drives a command) run under --nogui as well, and the
# rows that send events to the canvas (T7-T10, the G rows, the Edit Properties rows)
# run where there is one. A band that cannot run on an arm says so with one `skip:`
# line; it is never a silent pass. The rows about the action log need a log file,
# which the arm that passes --logdir has.
#
#   tests/headless/run_suites.sh --nogui test_dblclick_connected_grow    (engine)
#   tests/headless/run_suites.sh         test_dblclick_connected_grow    (+ gestures)
#   tests/headless/run_suites.sh --logdir test_dblclick_connected_grow   (+ the log)
#
# `check` takes a BOOLEAN and an optional detail; `same` takes a value and the wanted
# value and prints both when they differ. A failing row ends in the word the
# regression's verdict counts, so the verdict names the row.

# the stall bound: a property form that waits, or a gesture that never returns,
# ends this suite by name instead of holding its driver
source [file join [file dirname [info script]] scratch.tcl]

set ::TK [expr {[info commands winfo] ne {}}]
set WIN .drw
set ::XWIN 0
if {$::TK} {
  catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
  if {![catch {winfo viewable $WIN} vv] && $vv} { set ::XWIN 1 }
}
if {$::XWIN} {
  update idletasks
  catch { focus -force $WIN }
  update idletasks
}
set ::LOG [xschem get actionlog_filename]

set ::fails 0
set ::npass 0
proc check {name ok {info {}}} {
  if {$info ne {}} { set name "$name  ($info)" }
  if {$ok} { puts "ok:   $name" ; incr ::npass } else { puts "FAIL: $name : FAIL" ; incr ::fails }
  flush stdout
}
proc same {name got want} {
  if {$got eq $want} { puts "ok:   $name" ; incr ::npass } \
  else { puts "FAIL: $name -> {$got} (want {$want}) : FAIL" ; incr ::fails }
  flush stdout
}
proc nsel      {}  { llength [xschem selection] }
proc nsel_type {t} { set c 0; foreach e [xschem selection] { if {[lindex $e 0] eq $t} {incr c} }; return $c }
proc grow      {args} { eval xschem select_grow_connected $args }
# the display is refreshed only where there is one
proc settle {} { if {$::XWIN} { xschem redraw ; update idletasks } }

# the engine rows run in the stock editing mode, whatever an earlier run left behind
set ::cadence_compat 0
set ::autotrim_wires 0
set ::label_splits_wires 0

# --- fixture: a linear chain of 5 DISTINCT (perpendicular-jointed, so never
# merged) wire segments W0..W4, each touching the next at an endpoint. Seed W0 at
# its mid-point (50,0).
proc build_chain {} {
  xschem clear force
  xschem wire   0   0  100   0    ;# W0  seed, hit at (50,0)
  xschem wire 100   0  100 100    ;# W1  touches W0 at (100,0)
  xschem wire 100 100  200 100    ;# W2  touches W1 at (100,100)
  xschem wire 200 100  200 200    ;# W3  touches W2 at (200,100)
  xschem wire 200 200  300 200    ;# W4  touches W3 at (200,200)
  xschem unselect_all
  settle
}

# ---------------------------------------------------------------------------
# T1 -- ring escalation from a wire seed: 2 -> 3 -> 5, then saturates.
# ---------------------------------------------------------------------------
build_chain
# a net-label sitting on W2's interior (150,100): it arrives with W2, not before
xschem instance devices/lab_wire 150 100 0 0 {name=l1 lab=NET}
xschem unselect_all
settle

set l1 [grow 50 0]
check "T1a click1 -> level 1"            [expr {$l1 == 1}]           "level=$l1"
check "T1a click1 -> 2 wires (W0,W1)"    [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
check "T1a click1 -> no instance in sel" [expr {[nsel_type instance] == 0}]

set l2 [grow 50 0]
check "T1b click2 -> level 2"            [expr {$l2 == 2}]           "level=$l2"
check "T1b click2 -> 3 wires"            [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
same  "T1b click2 -> the label on W2 arrives with W2" [lsort [xschem selected_set]] {l1}

set l3 [grow 50 0]
check "T1c click3 -> level 3"            [expr {$l3 == 3}]           "level=$l3"
check "T1c click3 -> all 5 wires"        [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"

set l4 [grow 50 0]
check "T1d click4 -> saturates at 3"     [expr {$l4 == 3}]           "level=$l4"
check "T1d click4 -> still 5 wires"      [expr {[nsel_type wire] == 5}]

# ---------------------------------------------------------------------------
# T6 -- the whole net holds its one label and nothing else that is not a wire.
# (Until 2026-11-21 this row read "rings are wires only, 0 instances".)
# ---------------------------------------------------------------------------
same "T6 whole net: the five wires and exactly the one label on them" \
  [list [nsel_type wire] [lsort [xschem selected_set]] [nsel]] {5 l1 6}

# ---------------------------------------------------------------------------
# T2 -- seed already selected: first grow still yields ring1 (same as T1a).
# ---------------------------------------------------------------------------
build_chain
xschem select_at 50 0                      ;# pre-select W0 (plain click)
check "T2 pre-select: 1 wire selected"     [expr {[nsel_type wire] == 1}]
set l [grow 50 0]
check "T2 grow on pre-selected -> level 1" [expr {$l == 1}]            "level=$l"
check "T2 grow on pre-selected -> 2 wires" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T3 -- non-wire seed (instance/net-label): grows the touching wire, keeps inst.
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/lab_wire 0 0 0 0 {name=l1 lab=NET}   ;# instance index 0
set pc [xschem instance_pin_coord l1 name p]
set px [lindex $pc 1]; set py [lindex $pc 2]
xschem wire $px $py [expr {$px + 100}] $py                    ;# wire from the label pin
xschem unselect_all
settle
xschem select instance 0                                     ;# seed = the label instance
set l [grow]                                                 ;# coordless step on current sel
check "T3 label seed -> level 1"           [expr {$l == 1}]            "level=$l"
check "T3 label seed keeps instance"       [expr {[nsel_type instance] == 1}] "sel=[xschem selection]"
check "T3 label seed grows touching wire"  [expr {[nsel_type wire] == 1}]     "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T4 -- different seed resets the escalation (level back to 1, not 3).
# ---------------------------------------------------------------------------
build_chain
grow 50 0 ; grow 50 0                       ;# W0 up to level 2
set l [grow 250 200]                        ;# seed W4 (mid at (250,200)) -> reset
check "T4 different seed resets to level 1" [expr {$l == 1}] "level=$l"

# ---------------------------------------------------------------------------
# T5 -- coord-form escalation is SEED-driven: it recomputes the selection from
# the seed each call, so it SURVIVES an external unselect_all (repeated
# double-clicks on the same object keep escalating). Reset happens on SEED CHANGE
# (T4), not on selection clearing. This is deliberate: the interactive gesture
# cannot reliably observe an intervening deselect (its own press re-selects the
# seed before -3 fires), so the coord path keys off seed identity, not selection.
# ---------------------------------------------------------------------------
build_chain
set l [grow 50 0]
check "T5 first grow -> level 1"                     [expr {$l == 1}] "level=$l"
xschem unselect_all
set l [grow 50 0]
check "T5 same seed after unselect_all -> level 2"   [expr {$l == 2}] "level=$l"
check "T5 recompute-from-seed yields ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T5b -- the COORDLESS form is incremental and DOES reset on external selection
# change (sel_sig). Used for scripting.
# ---------------------------------------------------------------------------
build_chain
xschem select_at 50 0
set l [xschem select_grow_connected]
check "T5b coordless after fresh select -> level 1" [expr {$l == 1}] "level=$l"
check "T5b coordless ring1 (2 wires)"               [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
xschem unselect_all
xschem select_at 50 0
set l [xschem select_grow_connected]
check "T5b coordless resets on external change -> level 1" [expr {$l == 1}] "level=$l"

# ===========================================================================
# THE LABEL BANDS (ruling of 2026-11-21: the grow takes the net-name labels on
# the wires it selects). The L rows drive the command forms and run on both arms;
# the G rows further down drive the same statements as gestures. An LF row says
# the fixture is what the rows beside it need it to be.
#
# Wires are read by NAME: the fixture files each wire's end points under a name
# and a selected wire is looked up by the end points the product reports for it.
# A row that looks at the wires of the sheet walks all of them (`allw`, `allwc`,
# `on_wire`); none asks for a wire by its place in the wire array. Instances are
# read by name off `xschem selected_set`.
#
# A row about what a step selected compares the EXACT sets, wires and instances,
# so "the device is not selected" cannot pass on an empty selection. The rows
# that ask about one name only say here what stands beside them: L2a (L1 has just
# compared the exact sets of the same state), the L11 rows (every instance on the
# sheet is asked about by name, L11n counts them against the sheet, and the wires
# are compared whole) and L13b (a name that must be IN the selection).
# ===========================================================================
set ::REPO [__scratch_repo]   ;# resolved by scratch.tcl when it was sourced
set ::WN [dict create]
proc wkey {x1 y1 x2 y2} {
  return [lsort [list [list [expr {double($x1)}] [expr {double($y1)}]] \
                      [list [expr {double($x2)}] [expr {double($y2)}]]]]
}
proc w {name x1 y1 x2 y2 args} {
  eval [list xschem wire $x1 $y1 $x2 $y2] $args
  dict set ::WN [wkey $x1 $y1 $x2 $y2] $name
}
proc wname {i} {
  set c [xschem wire_coord $i]
  set k [eval wkey $c]
  if {[dict exists $::WN $k]} { return [dict get $::WN $k] }
  return "?[join $c ,]"
}
proc selw {} {
  set r {}
  foreach e [xschem selection] { if {[lindex $e 0] eq {wire}} { lappend r [wname [lindex $e 1]] } }
  return [lsort $r]
}
proc seli {} { return [lsort [xschem selected_set]] }
proc sel2 {} { return [list [selw] [seli]] }
proc allw {} {
  set r {}
  for {set i 0} {$i < [xschem get wires]} {incr i} { lappend r [wname $i] }
  return [lsort $r]
}
proc alli {} {
  set r {}
  for {set i 0} {$i < [xschem get instances]} {incr i} { lappend r [xschem getprop instance $i name] }
  return [lsort $r]
}
# the end points of every wire on the sheet as the product stores them, sorted
proc allwc {} {
  set r {}
  for {set i 0} {$i < [xschem get wires]} {incr i} { lappend r [xschem wire_coord $i] }
  return [lsort $r]
}
# the coordinate of a pin; without a pin name, the instance's first pin
proc pinxy {inst {pin {}}} {
  if {$pin eq {}} { set pin [lindex [lindex [xschem pinlist $inst name] 0] 1] }
  return [lrange [xschem instance_pin_coord $inst name $pin] 1 2]
}
# is (x,y) on a wire that has a length? Its own arithmetic, end points in either order
proc on_wire {x y} {
  for {set i 0} {$i < [xschem get wires]} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    if {$x1 == $x2 && $y1 == $y2} continue
    if {($x2 - $x1) * ($y - $y1) != ($y2 - $y1) * ($x - $x1)} continue
    if {$x < min($x1,$x2) || $x > max($x1,$x2) || $y < min($y1,$y2) || $y > max($y1,$y2)} continue
    return 1
  }
  return 0
}
# every instance of type `label` on the sheet with its pin, as the product reports both
proc label_pins {} {
  set r {}
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[xschem getprop instance $i cell::type] ne {label}} continue
    lappend r [xschem getprop instance $i name] [pinxy $i]
  }
  return $r
}
# of the named labels, the ones whose pin is on no wire
proc off_copper {names} {
  set r {}
  foreach n $names { lassign [pinxy $n] x y ; if {![on_wire $x $y]} { lappend r $n } }
  return $r
}
proc lab {name x y {more {}} {net NA}} {
  xschem instance devices/lab_pin.sym $x $y 0 0 "name=$name lab=$net $more"
}
proc chain {} {
  set ::WN [dict create]
  xschem clear force
  w W0   0   0  100   0
  w W1 100   0  100 100
  w W2 100 100  200 100
  w W3 200 100  200 200
  w W4 200 200  300 200
}
proc done_building {} { xschem unselect_all ; settle }
# The net of the label rows: the chain; LA on W1's interior, LB on W2's, LC on W4's;
# a resistor whose pin P is exactly W4's free end; an island wire WD with a label LD
# of the SAME net name; a label LE of that name on no copper at all.
proc build_net {} {
  chain
  w WD   0 400  100 400
  lab LA 100  50
  lab LB 150 100
  lab LC 250 200
  lab LD  50 400
  lab LE 500 -200
  xschem instance devices/res.sym 300 230 0 0 {name=R1 value=1k}
  done_building
}
# The bare form restarts its level only when the selection COUNT differs from the count
# it stored on its last step. So a row about the bare form first stores the count of
# everything on the sheet and then picks ONE object: the two cannot be equal on a sheet
# with more than one object, on either side of the change these rows are about.
proc bare_restart {x y} {
  xschem select_all
  xschem select_grow_connected
  xschem unselect_all
  xschem select_at $x $y
}
set ::S1 {{W0 W1} LA}
set ::S2 {{W0 W1 W2} {LA LB}}
set ::S3 {{W0 W1 W2 W3 W4} {LA LB LC}}

# --- LF: the fixture --------------------------------------------------------
build_net
same "LF1 the resistor's pin P is exactly the free end of W4, read back from the product" \
  [pinxy R1 P] {300 200}
same "LF2 the five labels sit where the rows need them: three on the chain, one on the island, one on no wire" \
  [list [label_pins] [off_copper {LA LB LC LD LE}]] \
  {{LA {100 50} LB {150 100} LC {250 200} LD {50 400} LE {500 -200}} LE}
same "LF3 neither seed point of these rows is the pin of a label" \
  [list [lsearch -exact [label_pins] {50 0}] [lsearch -exact [label_pins] {225 200}]] {-1 -1}

# --- L1-L4: one more ring per call, each with the labels on it ---------------
build_net
set lv [grow 50 0]
same "L1 first step from W0: level 1, wires W0 W1, and the label on W1" [list $lv [selw] [seli]] [concat 1 $::S1]
same "L2a the label on W2 is on the sheet and is not taken at level 1" \
  [list [expr {[lsearch -exact [alli] LB] >= 0}] [expr {[lsearch -exact [seli] LB] >= 0}]] {1 0}
set lv [grow 50 0]
same "L2b second step: level 2, W2 joins, and its label with it" [list $lv [selw] [seli]] [concat 2 $::S2]
set lv [grow 50 0]
same "L3 third step: level 3, the five wires and the three labels on them, no device" \
  [list $lv [selw] [seli]] [concat 3 $::S3]
same "L3b the selection holds wires and instances only: no pin row" \
  [lsort -unique [lmap e [xschem selection] {lindex $e 0}]] {instance wire}
set lv [grow 50 0]
same "L4 a fourth step changes nothing" [list $lv [selw] [seli]] [concat 3 $::S3]

# --- L5: the device is never selected, from the other end either -------------
# Seeded on W4, the wire the resistor's pin touches, at a point that is not LC's pin.
build_net
set got {}
foreach k {1 2 3} { lappend got [list [grow 225 200] [selw] [seli]] }
same "L5 seeded on the wire the resistor hangs on: three levels, the resistor in none of them" $got \
  {{1 {W3 W4} LC} {2 {W2 W3 W4} {LB LC}} {3 {W0 W1 W2 W3 W4} {LA LB LC}}}

# --- L6: Delete after the whole net, and one undo ----------------------------
build_net
grow 50 0 ; grow 50 0 ; grow 50 0
xschem delete
same "L6a Delete after level 3 leaves the resistor, the island and the two labels off the chain" \
  [list [allw] [alli]] {WD {LD LE R1}}
xschem undo
same "L6b one undo brings back the five wires and the three labels" \
  [list [allw] [alli]] {{W0 W1 W2 W3 W4 WD} {LA LB LC LD LE R1}}

# --- L7: the rings stay geometric --------------------------------------------
# The island and the off-copper label carry the chain's net name. The grow reaches
# neither; the name-wise select on the same seed reaches both, which is what makes
# them decoys and not bystanders.
build_net
grow 50 0 ; grow 50 0 ; grow 50 0
same "L7a at level 3 the selection is the chain and its three labels: not the island wire, not its label, not the label on no copper" \
  [list [selw] [seli]] $::S3
xschem unselect_all
xschem select_same_net 50 0
same "L7b the name-wise select on the same seed does take all three" \
  [list [selw] [seli]] {{W0 W1 W2 W3 W4 WD} {LA LB LC LD LE}}

# --- L8: labels are leaves ---------------------------------------------------
# Two wires that cross and share no end point, with a label on the crossing point.
proc build_cross {} {
  set ::WN [dict create]
  xschem clear force
  w P    0    0  200   0
  w Q  100 -100  100 100
  xschem instance devices/lab_pin.sym 100 0 0 0 {name=LX lab=NX}
  done_building
}
build_cross
same "LF4 the two wires share no end point and the label's pin is on both" \
  [list [allwc] [pinxy LX]] {{{0 0 200 0} {100 -100 100 100}} {100 0}}
set gw {} ; set gi {}
foreach k {1 2 3} { grow 50 0 ; lappend gw [selw] ; lappend gi [seli] }
same "L8a with coordinates, seeded on one wire: the crossing wire is selected at no level" $gw {P P P}
same "L8b ... and the label on the crossing is taken at every level" $gi {LX LX LX}
build_cross
bare_restart 50 0
set gl {} ; set gw {} ; set gi {}
foreach k {1 2 3} { lappend gl [xschem select_grow_connected] ; lappend gw [selw] ; lappend gi [seli] }
same "L8c the bare form after a pick of that wire: levels 1 2 3 and never the crossing wire" \
  [list $gl $gw] {{1 2 3} {P P P}}
same "L8d ... and the label is taken at every one of them" $gi {LX LX LX}
# The one change to the WIRE set: a label the caller selected by hand, sitting on a
# crossing, with a selected wire already under its pin. Before 2026-11-21 its pin pulled
# the crossing wire in (the answer then was wires P and Q); now the label is a leaf.
build_cross
bare_restart 50 0
xschem select instance LX fast
set lv [xschem select_grow_connected]
same "L8e a label picked by hand on a crossing, with a selected wire under it, does not pull in the crossing wire" \
  [list $lv [selw] [seli]] {1 P LX}
# ... while a label seed with NO selected wire under it still reaches every wire at its pin
build_cross
xschem select_all ; xschem select_grow_connected ; xschem unselect_all
xschem select instance LX fast
set lv [xschem select_grow_connected]
same "L8f a label seed with no selected wire under it takes both wires at its pin" \
  [list $lv [selw] [seli]] {1 {P Q} LX}
# Which labels are leaves is settled before the first wire of a ring is selected. Two
# labels picked by hand on ONE wire, the second on a crossing, nothing else selected:
# both are seeds of this ring, so the second still reaches the crossing wire. Were the
# question asked while the ring runs, the first label's wire would make the second a leaf.
set ::WN [dict create]
xschem clear force
w P    0    0  200   0
w X  150  -50  150  50
xschem instance devices/lab_pin.sym  50 0 0 0 {name=L1 lab=NX}
xschem instance devices/lab_pin.sym 150 0 0 0 {name=L2 lab=NX}
done_building
xschem select_all ; xschem select_grow_connected ; xschem unselect_all
xschem select instance L1 fast
xschem select instance L2 fast
set lv [xschem select_grow_connected]
same "L8g two hand-picked labels on one wire, the second on a crossing: one bare call takes their wire AND the crossing wire" \
  [list $lv [selw] [seli]] {1 {P X} {L1 L2}}
# Only a label the grow can TAKE is a leaf. A power symbol is of type `label` too, the
# grow never takes it, and picked by hand it is a seed like a device: with a selected
# wire under its pin it still reaches the crossing wire. (This leg reads the same on
# both sides of the ruling; it is here against a leaf test that asks for the type only.)
set ::WN [dict create]
xschem clear force
w P    0    0  200   0
w Q  100 -100  100 100
xschem instance devices/vdd.sym 100 0 0 0 {name=VX lab=VDD}
done_building
same "LF13 the power symbol is of type label, says it is global, and its pin is on the crossing" \
  [list [xschem getprop instance VX cell::type] [xschem getprop instance VX cell::global] [pinxy VX]] {label true {100 0}}
bare_restart 50 0
xschem select instance VX fast
set lv [xschem select_grow_connected]
same "L8h a power symbol picked by hand on a crossing, with a selected wire under it, is no leaf: the crossing wire comes" \
  [list $lv [selw] [seli]] {1 {P Q} VX}

# --- L9: the bare form, three levels -----------------------------------------
# The fence for WHERE the labels are taken: they are counted in the count the bare
# form stores, so the second bare call is a continuation and not a restart.
build_net
bare_restart 50 0
set got {}
foreach k {1 2 3 4} { lappend got [list [xschem select_grow_connected] [selw] [seli]] }
same "L9 a pick and then four bare calls: levels 1 2 3 3 with the sets of L1 to L4" $got \
  [list [concat 1 $::S1] [concat 2 $::S2] [concat 3 $::S3] [concat 3 $::S3]]

# --- L10: a label as the seed ------------------------------------------------
build_net
lab LA2 100 25
done_building
xschem select_all ; xschem select_grow_connected ; xschem unselect_all
xschem select instance LA fast
set lv [xschem select_grow_connected]
same "L10a a selected label and one bare call: it stays, its wire is ring 1, the other label on that wire comes" \
  [list $lv [selw] [seli]] {1 W1 {LA LA2}}
# with coordinates: a point inside the label's body and off every wire picks the label
lassign [lrange [lindex [split [xschem instance_bbox LA] \n] 0] 1 4] bx1 by1 bx2 by2
set lax [expr {$bx1 + 3.0}] ; set lay [expr {($by1 + $by2) / 2.0}]
same "LF5 that point picks the label and is on no wire" \
  [list [lindex [xschem object_at $lax $lay] 0] [on_wire $lax $lay]] {instance 0}
set got {}
foreach k {1 2 3} { lappend got [list [grow $lax $lay] [selw] [seli]] }
same "L10b a double click on the label's body: three levels from its wire, the labels on each" $got \
  {{1 W1 {LA LA2}} {2 {W0 W1 W2} {LA LA2 LB}} {3 {W0 W1 W2 W3 W4} {LA LA2 LB LC}}}

# --- L11: the scope, by name, at level 3 -------------------------------------
# name, symbol, where, attributes, and what the ruling says. A `label` symbol with no
# `global` is in (lab_pin, lab_wire, lab_generic, bus_connect); a `global` that is
# `ground` or a true boolean is out, read from the instance first and then from the
# symbol, so a vdd whose instance says global=false is in and a lab_pin whose instance
# says global=true is out. Ports, lab_show, a probe and a bus tap are out. The power
# symbols of the gschem import library are of type `label` and carry NO `global`, so by
# the same test they are in, like a lab_pin: the ruling tells a power symbol by that
# attribute and by nothing else.
# A bare symbol name is a symbol of devices/; one with a directory is looked up under
# xschem_library/. x and y are where the instance is placed; LF6 says the first pin of
# every one of them landed on the chain.
set ::SCOPE {
  SW   lab_wire     25   0  {lab=NA}              in
  SG   lab_generic  75   0  {lab=NA}              in
  SBC  bus_connect  240 210 {lab=NA}              in
  SVF  vdd          100  25 {lab=NA global=false} in
  SGV  gschem_import/sym/vdd-1 255 200 {lab=Vdd}  in
  SGG  gschem_import/sym/gnd-1 190 155 {lab=GND}  in
  SVD  vdd          100  75 {lab=VDD}             out
  SGN  gnd          125 100 {lab=0}               out
  SGL  lab_pin      175 100 {lab=NA global=true}  out
  SIP  ipin           0   0 {lab=NA}              out
  SOP  opin         100 100 {lab=NA}              out
  SIO  iopin        200 100 {lab=NA}              out
  SLS  lab_show     200 150 {}                    out
  SPR  spice_probe  200 200 {}                    out
  SBT  bus_tap      190 185 {lab=[0]}             out
}
proc symref {sym} {
  if {[string first / $sym] < 0} { return devices/$sym.sym }
  return [file join $::REPO xschem_library $sym.sym]
}
chain
foreach {nm sym x y attrs want} $::SCOPE {
  xschem instance [symref $sym] $x $y 0 0 "name=$nm $attrs"
}
done_building
set types {} ; set globals {} ; set offw {}
foreach {nm sym x y attrs want} $::SCOPE {
  lappend types [xschem getprop instance $nm cell::type]
  lappend globals [xschem getprop instance $nm cell::global]
  lassign [pinxy $nm] qx qy
  if {![on_wire $qx $qy]} { lappend offw $nm }
}
same "LF6 every symbol of the scope table was placed, has the type the row is about, and has its pin on the chain" \
  [list [expr {[xschem get instances] == [llength $::SCOPE] / 6}] $types $offw] \
  {1 {label label label label label label label label label ipin opin iopin show_label probe bus_tap} {}}
same "LF6b what each of those symbols says about `global` in its own file: only the vdd and gnd of devices/ say anything" \
  $globals {{} {} {} true {} {} true ground {} {} {} {} {} {} {}}
grow 50 0 ; grow 50 0 ; grow 50 0
same "L11 at level 3 the five wires are selected" [selw] {W0 W1 W2 W3 W4}
set asked 0
foreach {nm sym x y attrs want} $::SCOPE {
  same "L11 $nm ($sym $attrs) is $want" \
    [expr {[lsearch -exact [seli] $nm] >= 0 ? {in} : {out}}] $want
  incr asked
}
same "L11n every instance on the sheet was asked about by name" $asked [xschem get instances]

# --- L12: the pin stub -------------------------------------------------------
# A device pin, a stub wire from it, a lab_pin at the stub's far end.
set ::WN [dict create]
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=R2 value=1k}
lassign [pinxy R2 M] mx my
w STUB $mx $my $mx [expr {$my + 40}]
xschem instance devices/lab_pin.sym $mx [expr {$my + 40}] 0 0 {name=LS lab=NS}
done_building
set lv [grow $mx [expr {$my + 20}]]
same "L12a one step on the stub: the stub and its label, not the device" [list $lv [selw] [seli]] {1 STUB LS}
xschem delete
same "L12b Delete then leaves the device with its bare pin" [list [xschem get wires] [alli]] {0 R2}
# ... and on the stubs the product draws itself (the Space key's command), on every
# side of a device: a resistor upright and one turned a quarter, so that in each pair
# one stub runs from its pin toward smaller coordinates. Until 2026-11-22 such a stub
# was stored end-first: a point on its middle picked nothing and nothing touched it, so
# a grow seeded there selected nothing and a grow from its device reached neither it nor
# its label, until the sheet was saved and loaded again. Each stub is named here after
# the label at its far end.
proc samept {a b} { return [expr {[lindex $a 0] == [lindex $b 0] && [lindex $a 1] == [lindex $b 1]}] }
proc build_stubs {rot} {
  set ::WN [dict create]
  xschem clear force
  xschem instance devices/res.sym 0 0 $rot 0 {name=R2 value=1k}
  xschem unselect_all
  xschem select instance R2 fast
  xschem add_pin_stubs
  done_building
  set pins [list [pinxy R2 P] [pinxy R2 M]]
  set r {}
  for {set i 0} {$i < [xschem get wires]} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    set near {} ; set far {} ; set lbl {}
    foreach e [list [list $x1 $y1] [list $x2 $y2]] {
      if {[samept $e [lindex $pins 0]] || [samept $e [lindex $pins 1]]} { set near $e } else { set far $e }
    }
    foreach {nm pc} [label_pins] { if {$far ne {} && [samept $pc $far]} { set lbl $nm } }
    dict set ::WN [wkey $x1 $y1 $x2 $y2] ST_$lbl
    lappend r [list ST_$lbl $lbl [list $x1 $y1 $x2 $y2] $near $far]
  }
  return $r
}
set nst 0 ; set nlab 0 ; set ndown 0
set shape {} ; set step {} ; set seedl {} ; set stepwant {} ; set dev {} ; set devwant {} ; set left {}
foreach rot {0 1} {
  set stubs [build_stubs $rot]
  set wns {} ; set lbls {}
  foreach s $stubs {
    lassign $s wn lbl c near far
    lassign $c x1 y1 x2 y2
    incr nst
    if {$lbl ne {}} { incr nlab }
    if {$near ne {} && $far ne {} && ([lindex $far 0] < [lindex $near 0] || [lindex $far 1] < [lindex $near 1])} { incr ndown }
    lappend wns $wn ; lappend lbls $lbl
    set mx [expr {($x1 + $x2) / 2.0}] ; set my [expr {($y1 + $y2) / 2.0}]
    lappend shape [list [expr {$x1 < $x2 || ($x1 == $x2 && $y1 < $y2)}] [lindex [xschem object_at $mx $my] 0]]
    lappend stepwant [list $wn $lbl]
    xschem unselect_all
    grow $mx $my
    lappend step [sel2]
    xschem select_all ; xschem select_grow_connected ; xschem unselect_all
    if {$lbl ne {}} { xschem select instance $lbl fast }
    xschem select_grow_connected
    lappend seedl [sel2]
  }
  xschem unselect_all
  grow 0 0
  lappend dev [sel2]
  lappend devwant [list [lsort $wns] [lsort [concat R2 $lbls]]]
  xschem delete
  lappend left [list [xschem get wires] [alli]]
}
same "LF7 the product's own command drew a stub with a label at its far end on each pin of a resistor upright and of one turned a quarter, and in each pair one stub runs toward smaller coordinates" \
  [list $nst $nlab $ndown] {4 4 2}
same "L12c every stub the product drew is stored with its end points in order, and a point on its middle picks it" \
  [lsort -unique $shape] {{1 wire}}
same "L12d one step on each of those stubs: that stub and the label at its end, not the device" $step $stepwant
same "L12e the label at a stub's end as the seed (picked by hand, one bare call): the label and its stub" $seedl $stepwant
same "L12f one step on the device: both of its stubs and the label at the end of each" $dev $devwant
same "L12g Delete after that step leaves nothing of the device, its stubs or their labels" $left {{0 {}} {0 {}}}
set again {}
foreach rot {0 1} {
  build_stubs $rot
  set w0 [xschem get wires] ; set i0 [xschem get instances]
  xschem select instance R2 fast
  xschem add_pin_stubs
  xschem unselect_all
  lappend again [list [expr {[xschem get wires] - $w0}] [expr {[xschem get instances] - $i0}]]
}
same "L12h the command run a second time on the same device adds nothing: each pin reads as wired to its stub" \
  $again {{0 0} {0 0}}
# ... and on a stub that comes in through the MERGE door from a file that writes it
# the other way round: each wire of this band's file is written toward smaller
# coordinates and ends on a label, the way the stubs above were stored until
# 2026-11-22. Until that day the merge door stored a wire as its file wrote it. The
# rows drop the pending placement where it lies (`xschem unselect_all`), so nothing
# but that door has stored these wires. LF17 says what the file is: read as text, its
# wires are written end-first; opened, the loader stores them in order; typed to the
# wire command in the file's order, so does that.
set ::SCR [test_scratch dblgrow]
set endfirst [file join $::SCR stubs_endfirst.sch]
set fd [open $endfirst w]
puts $fd "v {xschem version=3.4.8RC file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nE {}"
puts $fd "N 0 -30 0 -70 {}\nN -30 0 -70 0 {}"
puts $fd "C {devices/lab_pin.sym} 0 -70 1 0 {name=LUP lab=NUP}"
puts $fd "C {devices/lab_pin.sym} -70 0 0 0 {name=LLF lab=NLF}"
close $fd
# are the end points x1 y1 x2 y2 in the order the product keeps a wire in: left to
# right, and for a vertical wire toward larger y
proc in_order {c} {
  lassign $c x1 y1 x2 y2
  return [expr {$x1 < $x2 || ($x1 == $x2 && $y1 < $y2)}]
}
proc wire_orders {} { set r {} ; foreach c [allwc] { lappend r [in_order $c] } ; return $r }
set fd [open $endfirst r] ; set ftext [read $fd] ; close $fd
set written {}
foreach l [split $ftext \n] { if {[string match {N *} $l]} { lappend written [lrange $l 1 4] } }
set wrote {} ; foreach c $written { lappend wrote [in_order $c] }
xschem clear force
xschem load $endfirst
set opened [list [xschem get wires] [lsort -unique [wire_orders]]]
set typed {}
foreach c $written {
  xschem clear force
  eval xschem wire $c
  lappend typed [wire_orders]
}
same "LF17 the file writes each of its wires end-first; opened, each is stored in order; typed to the wire command as written, each is stored in order" \
  [list $wrote $opened $typed] [list {0 0} [list [llength $written] 1] {1 1}]
set ::WN [dict create]
xschem clear force
xschem merge $endfirst
xschem unselect_all
settle
set shape {} ; set step {}
for {set i 0} {$i < [xschem get wires]} {incr i} {
  set c [xschem wire_coord $i]
  lassign $c x1 y1 x2 y2
  set lbl {}
  foreach {nm pc} [label_pins] {
    if {[samept $pc [list $x1 $y1]] || [samept $pc [list $x2 $y2]]} { set lbl $nm }
  }
  dict set ::WN [wkey $x1 $y1 $x2 $y2] ST_$lbl
  set mx [expr {($x1 + $x2) / 2.0}] ; set my [expr {($y1 + $y2) / 2.0}]
  lappend shape [list [in_order $c] [lindex [xschem object_at $mx $my] 0]]
  xschem unselect_all
  grow $mx $my
  lappend step [sel2]
}
same "L12i every wire the merged file brought is on the sheet, is stored with its end points in order, and a point on its middle picks it" \
  [list [xschem get wires] [lsort -unique $shape]] [list [llength $written] {{1 wire}}]
same "L12j one step on each merged stub: that stub and the label at its end" \
  [lsort $step] {{ST_LLF LLF} {ST_LUP LUP}}

# --- L13: a label directly on a pin of the seed device, with no wire there ---
# The rule is about wires: such a label is not taken. The older one-shot
# (`xschem connected_nets`) does take it, which is the leg that shows it sits there.
build_net
eval [list xschem instance devices/lab_pin.sym] [pinxy R1 M] [list 0 0 {name=LP lab=NP}]
done_building
same "LF8 the label is exactly on the device's other pin, on no wire, and the seed point picks the device" \
  [list [expr {[pinxy LP] eq [pinxy R1 M]}] [eval on_wire [pinxy LP]] [lindex [xschem object_at 300 230] 0]] \
  {1 0 instance}
set got {}
foreach k {1 2 3} { lappend got [list [grow 300 230] [selw] [seli]] }
same "L13a seeded on the device: its wire and the labels on the wires, never the label on its bare pin" $got \
  {{1 W4 {LC R1}} {2 {W3 W4} {LC R1}} {3 {W0 W1 W2 W3 W4} {LA LB LC R1}}}
xschem unselect_all
xschem select instance R1 fast
xschem connected_nets
same "L13b the older one-shot from the same device does take that label" \
  [expr {[lsearch -exact [seli] LP] >= 0}] 1

# --- LK: locked labels follow locked wires ------------------------------------
# The wire walk selects a locked wire; a locked label on it is taken the same way.
set ::WN [dict create]
xschem clear force
w W0   0   0  100   0
w W1 100   0  100 100
w W2 100 100  200 100 -1 {lock=true}
lab LA 100  50
lab LB 150 100 {lock=true}
done_building
set locked {}
for {set i 0} {$i < [xschem get wires]} {incr i} {
  if {[xschem getprop wire $i lock] eq {true}} { lappend locked [wname $i] }
}
same "LF9 the wire and the label of this row really carry the lock" \
  [list [xschem getprop instance LB lock] $locked] {true W2}
grow 50 0 ; set lv [grow 50 0]
same "LK at level 2 the locked wire is selected and the locked label on it is taken" \
  [list $lv [selw] [seli]] {2 {W0 W1 W2} {LA LB}}
xschem delete
same "LKb Delete then removes the locked wire and the locked label with the rest" [list [allw] [alli]] {{} {}}

# --- LZ: a wire of no length names no label -----------------------------------
# A zero-length wire on W0's row is reached by the wire walk (it answers "touching"
# for every point of its row). A label further along that row, on no wire, is not on it.
set ::WN [dict create]
xschem clear force
w W0 0 0 100 0
w Z 150 0 150 0
xschem instance devices/lab_pin.sym 170 0 0 0 {name=LZ lab=NZ}
done_building
set lv [grow 50 0]
same "LF10 the sheet holds a wire of no length" [expr {[lsearch -exact [allwc] {150 0 150 0}] >= 0}] 1
same "LZ the walk selects that wire, and the label on its row, on no real wire, is not taken" \
  [list [selw] [seli]] {{W0 Z} {}}

# --- LN: a label symbol with no pin is on no wire -----------------------------
# Asked for a pin it does not have, the editor answers the sheet's origin, and W0 ends
# exactly there. A `label` symbol with no pin rectangle, placed away from every wire,
# must not be taken for a label on W0.
set nopin [file join $::SCR nopin_label.sym]
set fd [open $nopin w]
puts $fd "v {xschem version=3.4.4 file_version=1.2}\nG {}\nK {type=label\nformat=\"*.alias @lab\"\ntemplate=\"name=p1 lab=xxx\"\n}\nV {}\nS {}\nE {}\nL 4 -10 0 0 0 {}\nT {@lab} -7.5 -8.125 0 1 0.33 0.33 {}"
close $fd
chain
xschem instance $nopin 400 -300 0 0 {name=LN lab=NA}
lab LA 100 50
done_building
same "LF12 that symbol is a label, has no pin, and a wire of the chain ends on the sheet's origin" \
  [list [xschem getprop instance LN cell::type] [llength [xschem pinlist LN name]] [on_wire 0 0]] {label 0 1}
grow 50 0 ; grow 50 0 ; grow 50 0
same "LN at level 3 the label without a pin is not taken; the label on the chain is" \
  [list [selw] [seli]] {{W0 W1 W2 W3 W4} LA}

# --- LP: ON a wire means on it, its end points included, and nothing beside it ---
# A label on each free end of the chain (the first end point of W0, the last of W4)
# is taken with its wire. A wire WN that runs beside W0 one grid pitch away and touches
# nothing, the label LNW on it, and a label LOF half a pitch off W0 on no wire at all
# are NEAR the selection and not on it: they are in no set. Seeded on WN itself, that
# wire and its label are the whole selection at every level, which is what says WN is
# an island and LNW an ordinary label on a wire.
proc build_near {} {
  chain
  w WN 0 20 80 20
  lab L0    0   0
  lab LA  100  50
  lab LB  150 100
  lab LC  250 200
  lab L4  300 200
  lab LNW  40  20
  lab LOF  60  10
  done_building
}
set ::N1 {{W0 W1} {L0 LA}}
set ::N2 {{W0 W1 W2} {L0 LA LB}}
set ::N3 {{W0 W1 W2 W3 W4} {L0 L4 LA LB LC}}
build_near
same "LF14 a label sits on each free end of the chain, one on the wire beside W0, one beside W0 on no wire; the seed point is no label's pin" \
  [list [pinxy L0] [pinxy L4] [pinxy LNW] [on_wire 40 20] [pinxy LOF] [on_wire 60 10] [lsearch -exact [label_pins] {50 0}]] \
  {{0 0} {300 200} {40 20} 1 {60 10} 0 -1}
set got {}
foreach k {1 2 3} { grow 50 0 ; lappend got [sel2] }
same "LP1 with coordinates, three levels from W0: the labels on the two free ends come with their wires, the wire beside W0 and the two labels near it never" \
  $got [list $::N1 $::N2 $::N3]
build_near
bare_restart 50 0
set got {}
foreach k {1 2 3} { xschem select_grow_connected ; lappend got [sel2] }
same "LP2 the bare form after a pick of W0: the same three sets" $got [list $::N1 $::N2 $::N3]
build_near
set got {}
foreach k {1 2 3} { grow 225 200 ; lappend got [sel2] }
same "LP3 seeded on W4: the label on its free end is taken at the first level" \
  $got {{{W3 W4} {L4 LC}} {{W2 W3 W4} {L4 LB LC}} {{W0 W1 W2 W3 W4} {L0 L4 LA LB LC}}}
build_near
set got {}
foreach k {1 2 3} { grow 70 20 ; lappend got [sel2] }
same "LP4 seeded on the wire beside W0: that wire and its own label at every level, nothing of the chain" \
  $got {{WN LNW} {WN LNW} {WN LNW}}

# --- LM: a net that carries more than one name ---------------------------------
# The labels on one piece of copper need not agree (an alias, or two nets shorted by
# mistake). The rule asks where a label's pin is, never what the label says.
chain
lab LA 100  50 {} NA
lab LB 150 100 {} NB
lab LC 250 200 {} NC
done_building
same "LF15 the three labels on the chain carry three different net names" \
  [lmap n {LA LB LC} {xschem getprop instance $n lab}] {NA NB NC}
set got {}
foreach k {1 2 3} { grow 50 0 ; lappend got [sel2] }
same "LM1 labels of different names on one net: each is taken with its wire" $got [list $::S1 $::S2 $::S3]
xschem delete
same "LM2 Delete after level 3 removes every one of them with the net" [list [allw] [alli]] {{} {}}

# --- L17: moving and copying the grown selection ------------------------------
# A selected label is placed by the move itself. What must hold: every label the grow
# selected still has its pin on a wire afterwards.
set ::MOVES {{} kissing {stretch kissing}}
set ::RAN_A 0 ; set ::RAN_B 0
foreach mode $::MOVES {
  build_net
  grow 50 0 ; grow 50 0 ; grow 50 0
  eval [list xschem move_objects 40 30] $mode
  same "L17a level 3 moved by (40,30) [expr {$mode eq {} ? {plain} : $mode}]: the three labels moved with their wires and none is off copper" \
    [list [pinxy LA] [pinxy LB] [pinxy LC] [off_copper {LA LB LC}]] {{140 80} {190 130} {290 230} {}}
  incr ::RAN_A
}
# level 1 with a label on the joint between a selected wire and one that stays
foreach mode $::MOVES {
  build_net
  lab LJ 100 100
  done_building
  set lv [grow 50 0]
  set before [list $lv [selw] [seli]]
  eval [list xschem move_objects 40 30] $mode
  same "L17b level 1 with a label on the joint to an unselected wire, moved [expr {$mode eq {} ? {plain} : $mode}]: the joint label was taken, went with its wire, and no label of the net is off copper" \
    [list $before [pinxy LA] [pinxy LJ] [off_copper {LA LB LC LJ}]] {{1 {W0 W1} {LA LJ}} {140 80} {140 130} {}}
  incr ::RAN_B
}
# counted where each loop body ends: a list of ways that is empty, or a body that
# leaves early, shows here
same "L17n each of the two move loops ran its rows, once for every way of moving in the list" \
  [list [expr {$::RAN_A > 0}] $::RAN_A $::RAN_B] [list 1 [llength $::MOVES] [llength $::MOVES]]
build_net
grow 50 0 ; grow 50 0 ; grow 50 0
set i0 [alli] ; set w0 [xschem get wires]
xschem copy_objects 0 300
set new {}
foreach n [alli] { if {[lsearch -exact $i0 $n] < 0} { lappend new $n } }
set newpins {}
foreach n $new { lappend newpins [pinxy $n] }
same "L17c a copy of level 3 carries five wires and three labels, the copies on the copied wires, no device" \
  [list [expr {[xschem get wires] - $w0}] [llength $new] [lsort $newpins] [off_copper $new] \
        [lsort -unique [lmap n $new {xschem getprop instance $n cell::type}]]] \
  {5 3 {{100 350} {150 400} {250 500}} {} label}
# The stated limit of the two commands that turn every selected object about its own
# origin (`xschem rotate_in_place`, `xschem flip_in_place`: what ALT-R and ALT-F run):
# a selected label turns about its own pin, so its pin stays where it was while the
# wires turn away from under it. These rows pin that answer as it stands.
foreach {tag verb lv labels off} {
  L17d rotate_in_place 1 LA         LA
  L17e rotate_in_place 3 {LA LB LC} {LA LC}
  L17f flip_in_place   3 {LA LB LC} {LB LC}
} {
  build_net
  for {set k 0} {$k < $lv} {incr k} { grow 50 0 }
  set before [seli]
  xschem $verb
  same "$tag level $lv, then $verb: the pin of every label stays where it was, and the labels named are left off the turned wires" \
    [list $before [pinxy LA] [pinxy LB] [pinxy LC] [off_copper {LA LB LC}]] \
    [list $labels {100 50} {150 100} {250 200} $off]
}

# ===========================================================================
# THE GESTURE BANDS -- they send events to the canvas, so they need one.
# ===========================================================================
if {!$::XWIN} {
  puts "skip: gesture rows T7-T10, G12, G14-G18 and GQ -- they send events to a canvas window and this arm has none; the display arm of this suite runs them"
} else {

# ---------------------------------------------------------------------------
# T7 -- the REAL cadence_compat double-click GESTURE, full Tk event sequence
# (press, release, press, Double(-3), release). This is the case that a bare -3
# misses: with the cadence profile (fluid_editing + en_pin_select) the 2nd press
# arms a transient STARTMOVE / pin STARTWIRE, so -3 must abort it and the release
# must not collapse the grown selection. Escalates ring1 -> ring2 -> whole chain.
# ---------------------------------------------------------------------------
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  list [expr {int(($sx + $xo)/$z)}] [expr {int(($sy + $yo)/$z)}]
}
proc real_dblclick {sx sy} {
  global WIN
  lassign [screen $sx $sy] SX SY
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 1
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 2
  xschem callback $WIN -3 $SX $SY 0 1 0 0    ;# Double-Button-1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 2
  update idletasks
}
set cc_save [set ::cadence_compat]
set fe_save [set ::fluid_editing]
set ps_save [set ::en_pin_select]
set at_save [set ::autotrim_wires]
set ::cadence_compat 1
set ::fluid_editing 1
set ::en_pin_select 1
build_chain
xschem unselect_all
real_dblclick 50 0
check "T7 real gesture dblclick1 -> ring1 (2 wires)" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
real_dblclick 50 0
check "T7 real gesture dblclick2 -> ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
real_dblclick 50 0
check "T7 real gesture dblclick3 -> whole chain (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
set ::cadence_compat $cc_save
set ::fluid_editing $fe_save
set ::en_pin_select $ps_save

# ---------------------------------------------------------------------------
# T8 -- the GESTURE escalation RESETS on ANY intervening non-double gesture, so the
# next double-click on the seed restarts at ring1 instead of jumping to whole-net.
# This is the click-path counterpart to T5's coord-form (which deliberately survives
# an explicit `unselect_all`). The reset is event-driven: a button-1 RELEASE that is
# not a double-click's release2 snapshots+zeroes the level; the double's following -3
# restores the snapshot. Here: empty-space click and different-object click.
# ---------------------------------------------------------------------------
proc real_click {sx sy} {
  global WIN
  lassign [screen $sx $sy] SX SY
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 1
  update idletasks
}
set ::cadence_compat 1
set ::fluid_editing 1
set ::en_pin_select 1
build_chain
xschem unselect_all
real_dblclick 50 0 ; real_dblclick 50 0 ; real_dblclick 50 0
check "T8 escalate to whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
real_click 400 400                          ;# empty space -> deselect
check "T8 empty click deselects (0 wires)" [expr {[nsel_type wire] == 0}] "sel=[xschem selection]"
real_dblclick 50 0
check "T8 re-dblclick after deselect -> ring1 (2 wires), NOT whole" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
# and the full escalation works again from the restart
real_dblclick 50 0
check "T8 re-escalate ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
real_dblclick 50 0
check "T8 re-escalate whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
# clicking a DIFFERENT object also resets: dblclick back to the seed -> ring1
real_click 250 200                          ;# click W4 (a different segment)
real_dblclick 50 0
check "T8 different-object click then re-dblclick seed -> ring1 (2 wires)" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T9 -- the hard case: a single click ON the seed itself. Under cadence deferred
# selection this leaves the selection VISUALLY UNCHANGED (the seed stays selected,
# the ring stays selected), so no selection- or seed-identity check can see it --
# only the event stream (a non-double button-1 release) reveals it. It must still
# reset the escalation: re-dblclick the seed -> ring1, not whole-net.
# ---------------------------------------------------------------------------
build_chain
xschem unselect_all
real_dblclick 50 0 ; real_dblclick 50 0 ; real_dblclick 50 0
check "T9 escalate to whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
real_click 50 0                             ;# plain single click ON the seed W0
real_dblclick 50 0
check "T9 single-click ON seed then re-dblclick -> ring1 (2 wires)" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
real_dblclick 50 0
check "T9 re-escalate after seed-click ring2 (3 wires)" \
  [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"

# ---------------------------------------------------------------------------
# T10 -- drive the REAL Tk double-click event stream. Ground truth (verified via
# Tk `event generate`): a double-click fires  P1, R1, <Double>(-3), R2 -- the 2nd
# press emits ONLY the -3 (Double-Button-1 is more specific than the generic
# <ButtonPress> binding), NOT a second callback-4. The other procs here inject a
# synthetic extra press2 (4,5,4,-3,5); this proc uses the real 4,5,-3,5 so the
# escalation + reset are proven under actual dispatch, not just the synthetic model.
# ---------------------------------------------------------------------------
proc realtk_dbl {sx sy} {
  global WIN
  lassign [screen $sx $sy] SX SY
  xschem callback $WIN 4 $SX $SY 0 1 0 0     ;# ButtonPress 1
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 1
  xschem callback $WIN -3 $SX $SY 0 1 0 0    ;# Double-Button-1 (press2 == only this)
  xschem callback $WIN 5 $SX $SY 0 1 0 0     ;# ButtonRelease 2
  update idletasks
}
build_chain
xschem unselect_all
realtk_dbl 50 0
check "T10 realTk dbl1 -> ring1 (2 wires)" [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"
realtk_dbl 50 0
check "T10 realTk dbl2 -> ring2 (3 wires)" [expr {[nsel_type wire] == 3}] "sel=[xschem selection]"
realtk_dbl 50 0
check "T10 realTk dbl3 -> whole (5 wires)" [expr {[nsel_type wire] == 5}] "sel=[xschem selection]"
real_click 50 0                             ;# single click on seed
realtk_dbl 50 0
check "T10 realTk single-click ON seed then re-dbl -> ring1 (2 wires)" \
  [expr {[nsel_type wire] == 2}] "sel=[xschem selection]"

set ::cadence_compat $cc_save
set ::fluid_editing $fe_save
set ::en_pin_select $ps_save
set ::autotrim_wires $at_save

# ===========================================================================
# G -- the label rows as GESTURES, under the profile the gesture ships in.
#
# THE PROFILE IS READ FROM src/cadence_style_rc, not listed here: every line of that
# file that sets a variable to a number is applied, except the ones that reconfigure
# the libraries or the startup (their names start with `library_` or `launch_`), which
# must not change under a fixture that is already built. The rc is not sourced: it
# also rebinds keys, sources helpers and points the library registry elsewhere.
#
# The streams carry the modifier state a real pointer carries: 0 on a press and on
# the double, the button-1 mask on a release. (T7-T10 above send 0 everywhere.)
# ===========================================================================
set ::PROFILE {}
set rcf [file join [file dirname [info script]] .. .. src cadence_style_rc]
if {![catch {open $rcf r} fd]} {
  foreach line [split [read $fd] \n] {
    if {![regexp {^set ([a-z_]+) (-?[0-9]+)[ \t]*$} $line -> pn pv]} continue
    if {[string match library_* $pn] || [string match launch_* $pn]} continue
    lappend ::PROFILE $pn $pv
  }
  close $fd
}
set need {}
foreach pn {cadence_compat fluid_editing en_pin_select persistent_command infix_interface} {
  if {![dict exists $::PROFILE $pn]} { lappend need $pn }
}
proc pget {k} { if {[dict exists $::PROFILE $k]} { return [dict get $::PROFILE $k] } ; return MISSING }
same "LF11 the profile read from the rc sets the switches the gesture depends on, each to what the rc says" \
  [list $need [pget cadence_compat] [pget persistent_command] [pget infix_interface]] {{} 1 1 0}
proc profile_on {} {
  set ::PSAVE {} ; set ::PNEW {}
  foreach pn [concat [dict keys $::PROFILE] autotrim_wires] {
    if {[info exists ::$pn]} { lappend ::PSAVE $pn [set ::$pn] } else { lappend ::PNEW $pn }
  }
  dict for {pn pv} $::PROFILE { set ::$pn $pv }
}
proc profile_off {} {
  foreach {pn pv} $::PSAVE { set ::$pn $pv }
  foreach pn $::PNEW { unset -nocomplain ::$pn }
}
proc px {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  list [expr {int(round(($sx + $xo)/$z))}] [expr {int(round(($sy + $yo)/$z))}]
}
# one canvas event at a schematic point, and a count of the times the editor's own
# pointer did not land where the event said
set ::PTR_OFF {}
proc ev {type sx sy button state} {
  lassign [px $sx $sy] X Y
  xschem callback $::WIN $type $X $Y 0 $button 0 $state
  set z [xschem get zoom]
  if {abs([xschem get mousex] - $sx) > $z || abs([xschem get mousey] - $sy) > $z} {
    lappend ::PTR_OFF "wanted=$sx,$sy got=[xschem get mousex],[xschem get mousey]"
  }
}
# what Tk emits for a double click: press, release, the double, release
proc stream_tk {sx sy} {
  ev 4 $sx $sy 1 0 ; ev 5 $sx $sy 1 256 ; ev -3 $sx $sy 1 0 ; ev 5 $sx $sy 1 256
  update idletasks
}
# the same with a second press ahead of the double: the press that arms a move
proc stream_2p {sx sy} {
  ev 4 $sx $sy 1 0 ; ev 5 $sx $sy 1 256 ; ev 4 $sx $sy 1 0 ; ev -3 $sx $sy 1 0 ; ev 5 $sx $sy 1 256
  update idletasks
}
proc stream_click {sx sy} {
  ev 4 $sx $sy 1 0 ; ev 5 $sx $sy 1 256
  update idletasks
}
# a press, the pointer dragged with the button held, a release
proc stream_drag {sx sy dx dy} {
  ev 4 $sx $sy 1 0
  foreach f {0.25 0.5 0.75 1.0} { ev 6 [expr {$sx + $f * $dx}] [expr {$sy + $f * $dy}] 0 256 }
  ev 5 [expr {$sx + $dx}] [expr {$sy + $dy}] 1 256
  update idletasks
}
proc show_net {} { xschem zoom_full ; update ; update idletasks }
# move, copy, wire-draw: the states a gesture must not leave armed
proc armed {} { return [expr {[xschem get ui_state] & (1 | 32 | 64)}] }

profile_on

# --- G14: the two streams, three double clicks each --------------------------
foreach {tag stream} {G14a stream_tk G14b stream_2p} {
  build_net
  show_net
  set w0 [xschem get wires] ; set i0 [xschem get instances] ; set p0 [label_pins]
  set got {}
  foreach k {1 2 3} { $stream 50 0 ; lappend got [list [selw] [seli]] }
  same "$tag three double clicks on W0 ($stream): the sets of L1, L2 and L3" $got [list $::S1 $::S2 $::S3]
  same "$tag ... and afterwards no wire or instance was made or lost, no label moved, nothing is left armed" \
    [list [expr {[xschem get wires] - $w0}] [expr {[xschem get instances] - $i0}] \
          [expr {[label_pins] eq $p0}] [armed]] {0 0 1 0}
}

# --- G14c: what the second press of the second stream arms ---------------------
# The double-click branch aborts a gesture that a press between the first release and
# the double has armed. Under the profile such a press arms a move, on a wire and on a
# device body alike; this row says the stream of G14b really carries one, and that the
# double leaves nothing armed. (No leg presses a device PIN twice: see the note on the
# pin stream in the spec's "Interactive reality" section.)
set arms {}
foreach {sx sy} {50 0  300 230} {
  build_net
  show_net
  ev 4 $sx $sy 1 0 ; ev 5 $sx $sy 1 256 ; ev 4 $sx $sy 1 0
  lappend arms [expr {[xschem get ui_state] & 32}]
  ev -3 $sx $sy 1 0 ; ev 5 $sx $sy 1 256
  update idletasks
  lappend arms [armed]
}
same "G14c a second press ahead of the double arms a move, on a wire and on a device body, and the double leaves nothing armed" \
  $arms {32 0 32 0}

# --- G15: a single click on the seed restarts, with labels selected ----------
build_net
show_net
stream_tk 50 0 ; stream_tk 50 0 ; stream_tk 50 0
set at3 [list [selw] [seli]]
stream_click 50 0
stream_tk 50 0
same "G15 three double clicks, one single click ON the seed, one double click: level 1 again, not the whole net" \
  [list $at3 [selw] [seli]] [list $::S3 {W0 W1} LA]

# --- G16: one REAL Tk double click -------------------------------------------
# Generated pointer events with time stamps on one pixel, so Tk itself decides that
# the second press is a double; a trace on the editor's command records which canvas
# events reached it and with what modifier state. A timer closes whatever window a
# stray press could open, and names it.
set ::CB {}
proc cbtrace {cmd op} {
  if {[lindex $cmd 1] ne {callback}} return
  set e [lindex $cmd 3]
  if {$e eq {4} || $e eq {5} || $e eq {-3}} { lappend ::CB [list $e [lindex $cmd 9]] }
}
proc tops {} {
  set out {}
  foreach t [winfo children .] {
    if {[winfo toplevel $t] eq $t && [winfo ismapped $t]} { lappend out $t }
  }
  return [lsort $out]
}
set ::POPPED {}
set ::POPALL {}
proc dismiss {before} {
  foreach t [tops] {
    if {[lsearch -exact $before $t] >= 0} continue
    lappend ::POPPED $t
    lappend ::POPALL $t
    catch {destroy $t}
  }
}
set ::EVT 900000
proc tk_dblclick {sx sy} {
  lassign [px $sx $sy] X Y
  update
  event generate $::WIN <Motion> -x $X -y $Y
  update
  set z [xschem get zoom]
  if {abs([xschem get mousex] - $sx) > $z || abs([xschem get mousey] - $sy) > $z} {
    lappend ::PTR_OFF "motion wanted=$sx,$sy got=[xschem get mousex],[xschem get mousey]"
  }
  incr ::EVT 5000
  set ::POPPED {}
  set before [tops]
  set deadman [after 1500 [list dismiss $before]]
  event generate $::WIN <ButtonPress-1>   -x $X -y $Y -time $::EVT
  event generate $::WIN <ButtonRelease-1> -x $X -y $Y -time [expr {$::EVT + 70}] -state 256
  update
  event generate $::WIN <ButtonPress-1>   -x $X -y $Y -time [expr {$::EVT + 180}]
  event generate $::WIN <ButtonRelease-1> -x $X -y $Y -time [expr {$::EVT + 250}] -state 256
  update
  after cancel $deadman
  dismiss $before
  update
}
build_net
show_net
set got {}
set ::CB {}
set ::POPALL {}
trace add execution xschem enter cbtrace
foreach k {1 2 3} { tk_dblclick 50 0 ; lappend got [list [selw] [seli]] }
trace remove execution xschem enter cbtrace
same "G16a a real Tk double click reaches the editor as press, release, the double, release -- three times over" \
  $::CB [concat {{4 0} {5 256} {-3 0} {5 256}} {{4 0} {5 256} {-3 0} {5 256}} {{4 0} {5 256} {-3 0} {5 256}}]
same "G16b ... and three of them give the sets of L1, L2 and L3, with no window opened" \
  [list $got $::POPALL] [list [list $::S1 $::S2 $::S3] {}]

# --- G16c: a real Tk double click on a device pin ------------------------------
# Under the profile a press on a free pin arms a wire-draw that the release takes back.
# The double click then seeds on the device; nothing of that wire-draw is left behind:
# the next single click on the device body selects the device and draws nothing.
build_net
show_net
set w0 [xschem get wires]
lassign [pinxy R1 M] qx qy
set ::POPALL {}
tk_dblclick $qx $qy
set s1 [sel2]
stream_click 300 230
same "G16c a real Tk double click on a free pin of the device takes the device, the wire at its other pin and the label on that wire; a single click on the device afterwards selects it alone, draws no wire and arms nothing" \
  [list $s1 [sel2] [expr {[xschem get wires] - $w0}] [armed] $::POPALL] {{W4 {LC R1}} {{} R1} 0 0 {}}

# --- G17: a real connected drag of the grown selection -----------------------
build_net
show_net
stream_tk 50 0 ; stream_tk 50 0 ; stream_tk 50 0
stream_drag 50 0 40 30
same "G17a level 3 dragged by (40,30) with the pointer: the three labels went along with their wires, none is off copper, nothing is left armed" \
  [list [pinxy LA] [pinxy LB] [pinxy LC] [off_copper {LA LB LC}] [armed]] {{140 80} {190 130} {290 230} {} 0}
build_net
lab LJ 100 100
done_building
show_net
stream_tk 50 0
set at1 [list [selw] [seli]]
stream_drag 50 0 40 30
same "G17b level 1 with a label on the joint to an unselected wire, dragged by (40,30): it was taken, both labels went along, and no label of the net is off copper" \
  [list $at1 [pinxy LA] [pinxy LJ] [off_copper {LA LB LC LJ}] [armed]] {{{W0 W1} {LA LJ}} {140 80} {140 130} {} 0}

# --- G12: the stubs the Space key's command draws, as gestures -----------------
# The stub that runs UPWARD out of the resistor is the one that was stored end-first.
set up {}
foreach s [build_stubs 0] {
  lassign $s wn lbl c near far
  if {$near ne {} && $far ne {} && [lindex $far 1] < [lindex $near 1]} { set up $s }
}
show_net
lassign $up wn lbl c near far
lassign $c x1 y1 x2 y2
if {$up ne {}} { stream_tk [expr {($x1 + $x2) / 2.0}] [expr {($y1 + $y2) / 2.0}] }
same "G12a a double click on the stub that runs upward out of the device: that stub and the label at its end" \
  [list [expr {$up ne {}}] [selw] [seli]] [list 1 $wn $lbl]
build_stubs 0
show_net
stream_tk 0 0 ; stream_tk 0 0 ; stream_tk 0 0
set at3 [sel2]
xschem delete
same "G12b three double clicks on the device take both stubs and both labels, and Delete then leaves nothing" \
  [list $at3 [xschem get wires] [alli]] {{{ST_l0 ST_l1} {R2 l0 l1}} 0 {}}

# --- GQ: Edit Properties after the grow --------------------------------------
# Edit Properties prefers an instance in a mixed selection. So after a grow seeded on
# a WIRE that took a label it opens that label's form, where before 2026-11-21 it
# opened the wire's. A stated limit (the choice is in a primitive other gestures
# share); these rows pin what it does. Both doors are swapped for recorders, so no
# form opens.
proc q_target {} {
  set ::QREC {}
  rename ::text_line ::__q_text_line
  rename ::edit_prop ::__q_edit_prop
  proc ::text_line {args} { lappend ::QREC wire ; set ::tctx::rcode {} ; return {} }
  proc ::edit_prop {args} { lappend ::QREC [xschem get_tok $::tctx::retval name 2] ; return {} }
  catch {xschem edit_prop}
  rename ::text_line {}
  rename ::edit_prop {}
  rename ::__q_text_line ::text_line
  rename ::__q_edit_prop ::edit_prop
  return $::QREC
}
build_net
show_net
stream_tk 50 0
same "GQ1 after a double click on a wire that took a label, Edit Properties opens the label's form (the stated limit)" \
  [list [selw] [seli] [q_target]] {{W0 W1} LA LA}
build_net
show_net
stream_tk 300 230
same "GQ2 after a double click on a device, Edit Properties stays on the device" \
  [list [selw] [seli] [q_target]] {W4 {LC R1} R1}
build_net
show_net
stream_tk 50 0
stream_click 50 0
same "GQ3 the way back to the wire's form: one single click on the wire after the grow leaves the wire alone, and Edit Properties opens its form" \
  [list [selw] [seli] [q_target]] {W0 {} wire}
# a LABEL as the seed: Edit Properties stays on it, though the grow selected another
# label that comes before it on the sheet
build_net
show_net
lassign [lrange [lindex [split [xschem instance_bbox LC] \n] 0] 1 4] bx1 by1 bx2 by2
set lcx [expr {$bx1 + 3.0}] ; set lcy [expr {$by1 + 3.0}]
same "LF16 that point picks the label LC and is on no wire, and LC is not the first instance of the sheet" \
  [list [lindex [xschem object_at $lcx $lcy] 0] [xschem getprop instance [lindex [xschem object_at $lcx $lcy] 1] name] \
        [on_wire $lcx $lcy] [xschem getprop instance 0 name]] {instance LC 0 LA}
stream_tk $lcx $lcy ; stream_tk $lcx $lcy ; stream_tk $lcx $lcy
same "GQ4 after three double clicks on a label, Edit Properties stays on that label" \
  [list [selw] [seli] [q_target]] {{W0 W1 W2 W3 W4} {LA LB LC} LC}

profile_off

# --- G18: the stock profile is unchanged -------------------------------------
# A real double click on W0 with the profile off: Edit Properties comes up for the
# wire (the timer closes it and names it), W0 alone is selected, no label is.
set ::FORMS {}
proc formtrace {cmd op} { lappend ::FORMS [lindex $cmd 0] }
build_net
show_net
trace add execution text_line enter formtrace
trace add execution edit_prop enter formtrace
tk_dblclick 50 0
trace remove execution text_line enter formtrace
trace remove execution edit_prop enter formtrace
same "G18 stock profile, a real double click on W0: the wire's property form opened, and W0 alone is selected" \
  [list $::FORMS [expr {[llength $::POPPED] > 0}] [selw] [seli]] {text_line 1 W0 {}}
catch {destroy .dialog}
update

same "GP every canvas event of the G rows landed where it was aimed" $::PTR_OFF {}

}
# end of the gesture bands

# ===========================================================================
# THE LOG BAND -- one replayable line per gesture and per command, and a replay.
# select_grow_connected_step() logs at its CORE (select.c); handle_double_click()
# calls that core directly (callback.c), so the gesture and the subcommand each
# write exactly one line and the subcommand's branch writes none of its own.
# See doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md.
# ===========================================================================
proc grow_lines {} {
  if {[catch {open [xschem get actionlog_filename] r} fd]} { return {} }
  set body [read $fd]; close $fd
  set r {}
  foreach line [split $body \n] {
    if {[string match "xschem select_grow_connected*" $line]} { lappend r $line }
  }
  return $r
}
if {$::LOG eq {}} {
  puts "skip: log rows T11a T11b L19 G18L -- no action log on this arm; the arm that passes --logdir runs them"
} else {
  if {$::XWIN} {
    set ::cadence_compat 1 ; set ::fluid_editing 1 ; set ::en_pin_select 1
    build_chain
    xschem unselect_all
    # (a) the real double-click GESTURE logs
    set before [llength [grow_lines]]
    realtk_dbl 50 0
    set after_gesture [llength [grow_lines]]
    check "T11a real dblclick GESTURE logs one select_grow_connected line" \
      [expr {$after_gesture == $before + 1}] "before=$before after=$after_gesture"
    set ::cadence_compat $cc_save ; set ::fluid_editing $fe_save ; set ::en_pin_select $ps_save
    set ::autotrim_wires $at_save
    # the stock double click of G18 again, for its log: no grow line is written
    build_net
    show_net
    set before [llength [grow_lines]]
    tk_dblclick 50 0
    catch {destroy .dialog}
    update
    same "G18L stock profile: the double click wrote no grow line to the log" \
      [expr {[llength [grow_lines]] - $before}] 0
  }
  # (b) the script subcommand logs EXACTLY ONCE (core logs; branch does not double)
  build_chain
  set before [llength [grow_lines]]
  xschem select_grow_connected 50 0
  check "T11b script subcommand logs exactly once (no double, no drop)" \
    [expr {[llength [grow_lines]] == $before + 1}] "delta=[expr {[llength [grow_lines]] - $before}]"
  # (c) the logged lines, run again on a rebuilt fixture, give level 3 with its labels
  build_net
  set before [llength [grow_lines]]
  grow 50 0 ; grow 50 0 ; grow 50 0
  set mine [lrange [grow_lines] $before end]
  build_net
  foreach line $mine { uplevel #0 $line }
  same "L19 three commands wrote three lines, and those lines replayed on a rebuilt fixture give level 3 with its labels" \
    [list [llength $mine] [selw] [seli]] [concat 3 $::S3]
}

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
if {$::TK} { catch {destroy .ciw}; update }

# ---------------------------------------------------------------------------
puts ""
if {$::fails == 0} {
  puts "OVERALL: ok  (all checks passed)"
  puts "RESULT: ALL PASS ($::npass checks)"
} else {
  puts "OVERALL: FAIL  ($::fails failed)"
  puts "RESULT: $::fails FAILED ($::npass passed)"
}
exit [expr {$::fails == 0 ? 0 : 1}]
