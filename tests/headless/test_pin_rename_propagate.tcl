# Cadence-style pin-rename label propagation.
# Spec: doc/claude/specs/pin_rename_propagation.md
#
# When an interface PIN's `lab` is renamed in a schematic, every NET LABEL in the
# same schematic that carried the old name follows it, so the connectivity the
# user drew survives the rename (Virtuoso does this silently).
#
# RED-first: every check below fails on a tree without the feature — the labels
# keep the OLD name while the pin moves to the new one, silently disconnecting
# them. Verified before implementation.
#
# True headless, no X needed:
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_pin_rename_propagate.tcl

set fail 0
proc check {name got want} {
  global fail
  if {$got eq $want} { puts "ok:   $name (=> $got)" } else { puts "FAIL: $name (=> $got, want $want)"; incr fail }
}
proc inst_lab {i}  { return [xschem getprop instance $i lab] }
# every refusal warns on two channels; statusmsg(msg,2) is the headless-readable one
proc clear_info {} { xschem set infowindow_text {} }
proc info_has {pat} { return [expr {[string first $pat [xschem get infowindow_text]] >= 0}] }
proc inst_sym {i}  { return [file tail [xschem getprop instance $i cell::name]] }
proc inst_name {i} { return [xschem getprop instance $i name] }

# labs of every instance, in placement order — the whole-schematic oracle
proc labs {} {
  set out {}
  for {set i 0} {$i < [xschem get instances]} {incr i} { lappend out [inst_lab $i] }
  return $out
}
proc idx_of {name} {
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[inst_name $i] eq $name} { return $i }
  }
  return -1
}

# One pin + two labels on its net + one label on a different net.
proc scene {{pinlab A}} {
  xschem clear force
  xschem instance [find_file_first ipin.sym]     0 0 0 0 [list name=p1 lab=$pinlab]
  xschem instance [find_file_first lab_pin.sym]  100 0 0 0 [list name=l1 lab=$pinlab]
  xschem instance [find_file_first lab_wire.sym] 200 0 0 0 [list name=l2 lab=$pinlab]
  xschem instance [find_file_first lab_pin.sym]  300 0 0 0 {name=l3 lab=B}
}

# --- P1: the headline. Rename the pin, the labels on its net follow ---------
scene
check "P1a scene built"                [labs] {A A A B}
check "P1b symbols are pin,label,label,label" \
  [list [inst_sym 0] [inst_sym 1] [inst_sym 2] [inst_sym 3]] \
  {ipin.sym lab_pin.sym lab_wire.sym lab_pin.sym}
xschem setprop instance p1 lab AA
check "P1c pin renamed"                [inst_lab 0] AA
check "P1d lab_pin on that net follows"  [inst_lab 1] AA
check "P1e lab_wire on that net follows" [inst_lab 2] AA
check "P1f label on another net untouched" [inst_lab 3] B

# --- P2: one user action == one undo step ----------------------------------
xschem undo
check "P2 a single undo restores pin AND labels" [labs] {A A A B}

# --- P3: the property-dialog path propagates too ---------------------------
# apply_properties is what the Edit Properties form calls; setprop is the
# scripted path. Both must propagate or the GUI and scripts disagree.
scene
# the form normally seeds these; a scripted apply must too
set ::symbol [xschem getprop instance 0 cell::name]
set ::no_change_attrs 0
set ::user_wants_copy_cell 0
set id [xschem instance_id p1]
xschem apply_properties current $id {name=p1 lab=CC} {name=p1 lab=A} 1
check "P3a dialog path renames the pin"   [inst_lab 0] CC
check "P3b dialog path moves the labels"  [list [inst_lab 1] [inst_lab 2]] {CC CC}
check "P3c and leaves the other net"      [inst_lab 3] B

# --- P4: asymmetry. Renaming a LABEL must NOT rename the pin ---------------
# Cadence propagates pin -> labels only: a label rename is how a user
# deliberately moves one wire onto a different net.
scene
xschem setprop instance l1 lab ZZ
check "P4a the renamed label moved"       [inst_lab 1] ZZ
check "P4b the pin did NOT follow"        [inst_lab 0] A
check "P4c the sibling label did NOT follow" [inst_lab 2] A

# --- P5: exact-name match, and the bus-overlap refusal ---------------------
# Names match exactly: A[3:0] and A[2] are different label texts, and there is no
# defined semantics for renaming PART of a bus. But rewriting only the exact
# label would strand A[2] as an unrelated floating net with nothing reporting it
# — signal_short only fires when two names meet on one conductor. So an
# overlapping-but-not-equal label refuses the WHOLE propagation and warns,
# leaving the loud pre-feature failure intact.
xschem clear force
xschem instance [find_file_first ipin.sym]    0 0 0 0 {name=p1 lab=A[3:0]}
xschem instance [find_file_first lab_pin.sym] 100 0 0 0 {name=l1 lab=A[3:0]}
xschem instance [find_file_first lab_pin.sym] 200 0 0 0 {name=l2 lab=A[2]}
xschem instance [find_file_first lab_pin.sym] 300 0 0 0 {name=l3 lab=AB}
clear_info
xschem setprop instance p1 lab {D[3:0]}
check "P5a bit-overlap refuses the whole propagation" [inst_lab 1] {A[3:0]}
check "P5b the overlapping label is left alone"       [inst_lab 2] {A[2]}
check "P5c the pin is still renamed"                  [inst_lab 0] {D[3:0]}
check "P5d and it warns"  [info_has "bus label overlaps"] 1

# no overlap -> the exact bus label follows normally
xschem clear force
xschem instance [find_file_first ipin.sym]    0 0 0 0 {name=p1 lab=A[3:0]}
xschem instance [find_file_first lab_pin.sym] 100 0 0 0 {name=l1 lab=A[3:0]}
xschem instance [find_file_first lab_pin.sym] 300 0 0 0 {name=l3 lab=AB}
xschem setprop instance p1 lab {D[3:0]}
check "P5e exact bus label follows"        [inst_lab 1] {D[3:0]}
check "P5f prefix-sharing label untouched" [inst_lab 2] AB

# --- P6: nothing to do cases ------------------------------------------------
scene
xschem setprop instance p1 lab A
check "P6a renaming to the same name is a no-op" [labs] {A A A B}
scene
xschem setprop instance p1 lab {}
check "P6b clearing the pin name does not rewrite labels" \
  [list [inst_lab 1] [inst_lab 2] [inst_lab 3]] {A A B}

# --- P7: a second pin still holding the old name blocks the rewrite --------
# Two pins named A means the labels belong to BOTH. Following the renamed one
# would silently disconnect the other, so the propagation refuses and the user
# is left with exactly the edit they asked for.
xschem clear force
xschem instance [find_file_first ipin.sym]    0 0 0 0 {name=p1 lab=A}
xschem instance [find_file_first opin.sym]    50 0 0 0 {name=p2 lab=A}
xschem instance [find_file_first lab_pin.sym] 100 0 0 0 {name=l1 lab=A}
xschem setprop instance p1 lab AA
check "P7a the edited pin is renamed"     [inst_lab 0] AA
check "P7b the other pin keeps the name"  [inst_lab 1] A
check "P7c the ambiguous label is left alone" [inst_lab 2] A

# --- P8: a non-pin instance's rename never propagates ----------------------
# Only ipin/opin/iopin are interface pins. A `show_label`-ish or ordinary
# symbol carrying lab= is not a pin and must not drag labels around.
xschem clear force
xschem instance [find_file_first lab_pin.sym] 0 0 0 0 {name=l1 lab=A}
xschem instance [find_file_first lab_pin.sym] 100 0 0 0 {name=l2 lab=A}
xschem setprop instance l1 lab QQ
check "P8 label-to-label never propagates" [list [inst_lab 0] [inst_lab 1]] {QQ A}

# --- P12: the whole-property-string form of setprop ------------------------
# `setprop instance <ref> allprops <string>` replaces the entire property string
# rather than substituting one token. The old name is read before the write, so
# this route propagates too.
scene
xschem setprop instance p1 allprops {name=p1 lab=WW}
check "P12a allprops renames the pin"  [inst_lab 0] WW
check "P12b allprops moves the labels" [list [inst_lab 1] [inst_lab 2]] {WW WW}

# --- P11: the real GUI route for renaming a pin ----------------------------
# `q` on a port instance does NOT open the generic property form: property_form.tcl
# hands off to schpin::edit_form, whose Apply issues `xschem setprop instance
# <inst> lab <name>` (xschem.tcl). Drive that proc directly — it is the path a
# user actually takes, and it must propagate like the others.
scene
set schpin::inst  p1
set schpin::name  RR
set schpin::name0 A
set schpin::dir   in
set schpin::dir0  in
schpin::apply
check "P11a schpin form renames the pin"  [inst_lab 0] RR
check "P11b schpin form moves the labels" [list [inst_lab 1] [inst_lab 2]] {RR RR}
check "P11c and leaves the other net"     [inst_lab 3] B

# --- P10: a SELECTED label is never rewritten ------------------------------
# change_index.tcl's +/- keys loop `setprop` over `xschem selected_set`. With a
# pin and its label both selected, propagating onto the label would bump it
# twice: pin A[3]->A[4], label propagated to A[4], then the loop's own bump to
# A[5]. Propagation skips the selection, so each caller gets exactly its edits.
proc change_index_like {incr} {
  foreach i [xschem selected_set] {
    set mylabel [xschem getprop instance $i lab]
    regsub {.*\[} $mylabel {} myindex
    regsub {\].*} $myindex {} myindex
    regsub {\[.*} $mylabel {} mybasename
    if { [regexp {^[0-9][0-9]*$} $myindex] } {
      xschem setprop instance $i lab "$mybasename\[[expr {$myindex + $incr}]\]"
    }
  }
}
xschem clear force
xschem instance [find_file_first ipin.sym]    0 0 0 0 {name=p1 lab=A[3]}
xschem instance [find_file_first lab_pin.sym] 100 0 0 0 {name=l1 lab=A[3]}
xschem select instance 0
xschem select instance 1
change_index_like 1
check "P10a bus-index bump: pin"   [inst_lab 0] {A[4]}
check "P10b bus-index bump: label bumped once, not twice" [inst_lab 1] {A[4]}
# unselected labels still follow
xschem clear force
xschem instance [find_file_first ipin.sym]    0 0 0 0 {name=p1 lab=A}
xschem instance [find_file_first lab_pin.sym] 100 0 0 0 {name=l1 lab=A}
xschem select instance 0
xschem setprop instance p1 lab AA
check "P10c an unselected label still follows" [inst_lab 1] AA

# --- P9: the preference gates it -------------------------------------------
scene
# MIRRORED IN TCL: C reads it with tclgetboolvar. catch on the read so a tree
# without the feature still reaches the banner instead of dying on the variable.
set saved x
catch {set saved $::pin_rename_propagate}
check "P9a default is enabled"           $saved 1
set ::pin_rename_propagate 0
xschem setprop instance p1 lab NN
check "P9b disabled: pin renamed"        [inst_lab 0] NN
check "P9c disabled: labels stay put"    [list [inst_lab 1] [inst_lab 2]] {A A}
set ::pin_rename_propagate 1

# --- P13: global nets refuse in both directions ----------------------------
# Globals span the hierarchy; this rewrite is sheet-local. Moving the vdd
# instances on ONE sheet would split the power net from every other sheet, and
# renaming a signal pin onto VDD/0 is a design-wide short that no ERC reports.
xschem clear force
xschem instance [find_file_first ipin.sym]    0 0 0 0 {name=p1 lab=VCC}
xschem instance [find_file_first vdd.sym]     100 0 0 0 {name=l1 lab=VCC}
clear_info
xschem setprop instance p1 lab VCC2
check "P13a old name global: label untouched" [inst_lab 1] VCC
check "P13b old name global: warns"           [info_has "old name is a global net"] 1

xschem clear force
xschem instance [find_file_first ipin.sym]    0 0 0 0 {name=p1 lab=SIG}
xschem instance [find_file_first lab_pin.sym] 100 0 0 0 {name=l1 lab=SIG}
xschem instance [find_file_first vdd.sym]     200 0 0 0 {name=l2 lab=VCC}
clear_info
xschem setprop instance p1 lab VCC
check "P13c new name global: label untouched" [inst_lab 1] SIG
check "P13d new name global: warns"           [info_has "new name is a global net"] 1

# --- P14: a fan-out Apply never propagates ---------------------------------
# scope=all/selected gives EVERY pin in the set the same new name. Propagating
# per target would merge three distinct nets sheet-wide and then erase the
# evidence: sym_vs_sch_pins sees no orphan labels, and signal_short never fires
# on two nets that merely share a name.
xschem clear force
foreach {nm x} {p1 0 p2 100 p3 200} {
  xschem instance [find_file_first ipin.sym] $x 0 0 0 [list name=$nm lab=N$nm]
}
foreach {nm x} {l1 300 l2 400 l3 500} {
  xschem instance [find_file_first lab_pin.sym] $x 0 0 0 [list name=$nm lab=Np[string index $nm 1]]
}
set ::symbol [xschem getprop instance 0 cell::name]
set ::no_change_attrs 0
set ::user_wants_copy_cell 0
xschem apply_properties all [xschem instance_id p1] {name=p1 lab=Z} {name=p1 lab=Np1} 1
check "P14a fan-out renamed all three pins" \
  [list [inst_lab 0] [inst_lab 1] [inst_lab 2]] {Z Z Z}
check "P14b fan-out did NOT merge the three label nets" \
  [list [inst_lab 3] [inst_lab 4] [inst_lab 5]] {Np1 Np2 Np3}

# --- P15: -fast is excluded ------------------------------------------------
# -fast pushes no undo and skips draw(); utils/bus_resize.tcl issues one per
# selected pin AND label under a single outer undo, so propagating there would
# double-edit exactly what the loop is about to edit.
scene
xschem setprop -fast instance p1 lab FF
check "P15a -fast renames the pin"      [inst_lab 0] FF
check "P15b -fast does not propagate"   [list [inst_lab 1] [inst_lab 2]] {A A}

# --- P16: merging onto an existing net proceeds, but says so ---------------
scene
clear_info
xschem setprop instance p1 lab B
check "P16a labels follow onto the existing net" [list [inst_lab 1] [inst_lab 2]] {B B}
check "P16b and it warns about the merge"        [info_has "existing net"] 1

# --- P17: reset_inst_prop is not a rename ----------------------------------
# It discards the instance's attributes back to the symbol template. That is a
# logged, undoable pin-`lab` rewrite that deliberately does NOT propagate: the
# invariant is push_undo <=> propagate for RENAMES, not for every logged write.
scene
xschem reset_inst_prop p1
check "P17 reset_inst_prop leaves the labels alone" \
  [list [inst_lab 1] [inst_lab 2]] {A A}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
if {$fail} { exit 1 }
exit 0
