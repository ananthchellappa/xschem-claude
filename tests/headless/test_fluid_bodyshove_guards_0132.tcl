# issue 0132 §11.9c guards — regression net for the adversarial-review findings on
# fluid_shove_body_crossing_backbone (review wf_cff67bed). Five cases:
#   G1 CRITICAL over-fire: dragging a 1-pin lab_pin onto its own backbone must NOT shove (the
#      label's graphic straddles the pin, the backbone is pin-less -> both partition verifies were
#      blind and the user's backbone was deleted). Fixed by the npins>=2 instance gate.
#   G2 MAJOR union-fling: a co-selected unrelated instance far ahead of the motion must NOT drag
#      the shove target past itself (ct now derives from the OWNING instance's body, not the union).
#   G3 MAJOR bus-spur: a bus-flagged same-net spur ending on the run must DECLINE the shove (it can
#      neither be translated nor severed -- severance is verify-blind for pin-less copper).
#   G4 stationary-neighbor body: a bystander device whose pin-inclusive body spans the ct column
#      must DECLINE the shove (never park the rebuilt backbone through a neighbor).
#   G5 duplicate-overlap: pin-row attachments (behind or ahead-inside) must not leave collinear
#      fully/partially overlapping copper under the jog.
#
#   src/xschem -q --pipe -x --script tests/headless/test_fluid_bodyshove_guards_0132.tcl

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set XSCHEM_LIBRARY_DEFS [file join $repo xschem_libs_newsym library.defs]
set library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH {}
set library_default_layout nested
set cadence_compat 1
set fluid_editing 1
set orthogonal_wiring 1

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc share_net {a b} {
  xschem resolved_net 0
  set am [xschem instance_nodemap [inst_by_name $a]]
  set bm [xschem instance_nodemap [inst_by_name $b]]
  set an {}; foreach {p nn} [lrange $am 1 end] { if {$nn ne {}} { lappend an $nn } }
  foreach {p nn} [lrange $bm 1 end] { if {$nn ne {} && [lsearch -exact $an $nn] >= 0} { return 1 } }
  return 0
}
# verticals of net $lab at column $x (list of {ylo yhi})
proc net_verticals_at {lab x} {
  set out {}; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    if {[xschem getprop wire $k lab] ne $lab} continue
    lassign [xschem wire_coord $k] a b c d
    if {$a == $x && $c == $x && $b != $d} { lappend out [list [expr {min($b,$d)}] [expr {max($b,$d)}]] }
  }
  return $out
}
# collinear overlapping same-net pairs (>0 shared length)
proc overlap_pairs {} {
  set out {}; set nw [xschem get wires]
  for {set k 0} {$k < $nw} {incr k} {
    lassign [xschem wire_coord $k] a b c d
    set lk [xschem getprop wire $k lab]
    for {set j [expr {$k+1}]} {$j < $nw} {incr j} {
      lassign [xschem wire_coord $j] e f g h
      if {[xschem getprop wire $j lab] ne $lk} continue
      if {$b == $d && $f == $h && $b == $f} {
        set o [expr {min(max($a,$c),max($e,$g)) - max(min($a,$c),min($e,$g))}]
        if {$o > 0} { lappend out [list H $b $k $j] }
      } elseif {$a == $c && $e == $g && $a == $e} {
        set o [expr {min(max($b,$d),max($f,$h)) - max(min($b,$d),min($f,$h))}]
        if {$o > 0} { lappend out [list V $a $k $j] }
      }
    }
  }
  return $out
}
# write a variant of before_10.sch with $extra lines inserted before the first C record
proc make_variant {extra dst} {
  global repo
  set f [open [file join $repo tests/from_user/before_10.sch] r]; set txt [read $f]; close $f
  regsub {C \{SANDBOX/solar_ctl\}} $txt "$extra\nC \{SANDBOX/solar_ctl\}" txt
  set f [open $dst w]; puts -nonewline $f $txt; close $f
}
set scratch [file join $here bodyshove_guards_scratch]
file mkdir $scratch

# ---- G1: label drop onto its own backbone -- shove must NOT fire, backbone survives -------------
xschem clear force
xschem wire 0 0 100 0
xschem wire 100 0 200 0
xschem wire 100 -100 100 -50
xschem wire 100 -50 100 0
xschem instance {devices/lab_pin} 100 -50 0 0 {name=l1 sig_type=std_logic lab=A}
xschem unselect_all
xschem select instance l1
xschem move_objects 0 50 stretch kissing
lassign [xschem instance_coord l1] a b lx ly
set cover_lo 1e30; set cover_hi -1e30
set nw [xschem get wires]
for {set k 0} {$k < $nw} {incr k} {
  lassign [xschem wire_coord $k] x1 y1 x2 y2
  if {$y1 == 0 && $y2 == 0} {
    if {[expr {min($x1,$x2)}] < $cover_lo} { set cover_lo [expr {min($x1,$x2)}] }
    if {[expr {max($x1,$x2)}] > $cover_hi} { set cover_hi [expr {max($x1,$x2)}] }
  }
}
check "G1: label landed on the wire (100,0)" [expr {$lx==100 && $ly==0}] "got ($lx,$ly)"
check "G1: y=0 backbone still spans \[0,200\] (no verify-blind deletion)" \
  [expr {$cover_lo <= 0 && $cover_hi >= 200}] "cover=\[$cover_lo,$cover_hi\]"

# ---- G2: co-selected far instance must not fling the shove target ------------------------------
xschem load [file join $repo tests/from_user/before_10.sch]
xschem set readonly 0
xschem place_symbol devices/res 600 300
set ri [expr {[xschem get instances]-1}]
xschem setprop instance $ri name Rfar fast
xschem unselect_all
xschem select instance x1
xschem select instance Rfar
xschem move_objects 20 0 stretch kissing
check "G2: P1 CTRL1 intact" [share_net x1 l1]
check "G2: shove landed at OWN body edge x=160 (not flung by Rfar)" \
  [expr {[llength [net_verticals_at CTRL1 160]] > 0}] "v160=[net_verticals_at CTRL1 160]"
set far 0
set nw [xschem get wires]
for {set k 0} {$k < $nw} {incr k} {
  if {[xschem getprop wire $k lab] ne "CTRL1"} continue
  lassign [xschem wire_coord $k] a b c d
  if {[expr {max($a,$c)}] > 220} { set far 1 }
}
check "G2: no CTRL1 copper past the l1 rail (x<=220)" [expr {!$far}]

# ---- G3: bus-flagged spur ending on the run -> whole shove DECLINES ----------------------------
set v [file join $scratch busspur.sch]
make_variant "N 140 40 200 40 \{lab=CTRL1 bus=true\}" $v
xschem load $v
xschem set readonly 0
xschem select instance x1
xschem move_objects 20 0 stretch kissing
check "G3: P1 CTRL1 intact" [share_net x1 l1]
check "G3: shove declined (no CTRL1 vertical at 160)" \
  [expr {[llength [net_verticals_at CTRL1 160]] == 0}] "v160=[net_verticals_at CTRL1 160]"
set bus_ok 0
set nw [xschem get wires]
for {set k 0} {$k < $nw} {incr k} {
  lassign [xschem wire_coord $k] a b c d
  if {($a==140 && $b==40 && $c==200 && $d==40) || ($a==200 && $b==40 && $c==140 && $d==40)} { set bus_ok 1 }
}
check "G3: bus spur untouched at (140,40)-(200,40)" $bus_ok
set anchored 0
foreach v140 [net_verticals_at CTRL1 140] { lassign $v140 lo hi
  if {$lo <= 40 && $hi >= 40} { set anchored 1 } }
check "G3: bus spur anchor column x=140 still carries the backbone" $anchored

# ---- G4: stationary neighbor body spanning the ct column -> DECLINE ----------------------------
set v [file join $scratch neighbor.sch]
make_variant "C \{devices/res\} 185 30 1 0 \{name=r99 value=1k\}" $v
xschem load $v
xschem set readonly 0
xschem select instance x1
xschem move_objects 20 0 stretch kissing
check "G4: P1 CTRL1 intact" [share_net x1 l1]
check "G4: shove declined (no CTRL1 vertical at 160 through r99's body)" \
  [expr {[llength [net_verticals_at CTRL1 160]] == 0}] "v160=[net_verticals_at CTRL1 160]"

# ---- G5: pin-row attachments leave no overlapping duplicate copper -----------------------------
set v [file join $scratch pinrow.sch]
make_variant "N 125 80 140 80 \{lab=CTRL1\}" $v
xschem load $v
xschem set readonly 0
xschem select instance x1
xschem move_objects 20 0 stretch kissing
check "G5: P1 CTRL1 intact" [share_net x1 l1]
check "G5: shove fired (CTRL1 vertical at 160)" \
  [expr {[llength [net_verticals_at CTRL1 160]] > 0}] "v160=[net_verticals_at CTRL1 160]"
check "G5: no collinear overlapping same-net copper" \
  [expr {[llength [overlap_pairs]] == 0}] "pairs=[overlap_pairs]"

file delete -force $scratch
puts "RESULT: [expr {$::fails==0 ? {ALL PASS} : {FAIL}}] ($::npass ok, $::fails fail)"
puts "OVERALL: [expr {$::fails==0 ? {ok} : {FAIL}}]"
