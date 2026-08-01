# SIGSEGV on '#'-leading net labels (issue 0156).
#
# '#' is the engine's PRIVATE marker for an auto-named net: get_unnamed_node()
# mints "#net<N>" for every unlabeled cluster (netlist.c), and the netlister
# strips the '#' again. Nothing stops a user from typing lab=#foo, and nothing
# stops a hand edit or a converter from putting any '#' name in a file -- there
# are 4,756 committed lab=#netN records in the shipped libraries, so '#' names
# round-trip through disk by design.
#
# TWO independent crashes, both from get_unnamed_node() indexing xctx->node_mult
# with no NULL and no bounds check (netlist.c ~805 for what==2, ~810 for what==3):
#
#  H-A  A wire whose established net name starts with '#', carrying a SECOND
#       label, reaches set_inst_node()'s '#' branch (netlist.c ~970), which calls
#       get_unnamed_node(2, ..., atoi(node+4)).  prepare_netlist_structs() FREES
#       node_mult at its start (get_unnamed_node(0,0,0)) and only repopulates it
#       in name_unlabeled_nets(), which runs AFTER this pass -- so node_mult is
#       unconditionally NULL here.  NULL deref.
#       Note this fires for the engine's OWN format too: #net1 + #net2 crashes.
#       Order matters: `#foo` then `foo` crashes, `foo` then `#foo` does not,
#       because the FIRST label wins and only a '#' winner enters the branch.
#
#  H-B  A large well-formed auto-name (lab=#net99999999) makes node_hash.c's
#       VHDL/Verilog declaration pass call get_unnamed_node(3, 0, atoi(tok+4)),
#       indexing node_mult far past node_mult_size.  Out-of-bounds read.
#       Reachable from `xschem netlist` in vhdl and verilog modes.
#
# Neither crash is fixed by making the auto-name test strict ("#net"+digits):
# #net1/#net2 and #net99999999 are all strictly well-formed.  The bounds/NULL
# guard is the fix; strictness (this file's S* legs) is a separate correctness
# matter -- atoi("#12345"+4) is 45, silently corrupting an unrelated node's
# multiplicity.
#
# Legs:
#   HA*  the shared-wire NULL deref, and the shapes that must stay unaffected
#   HB*  the out-of-range read via vhdl/verilog netlisting
#   S*   '#' is reserved: a user-authored '#' label is rejected at the entry
#        points and reported once by ERC, and is no longer mistaken for an
#        engine auto-name
#   C*   controls: engine #netN semantics and fly-lines A6 are UNCHANGED
#
# The crash legs run the binary as a SUBPROCESS (exec) so a regression shows up
# as a failed leg instead of killing this test file.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_hash_label_crash_0156.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch hash_label_0156]
set xbin    [file join $repo src xschem]

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

if {[catch {

# --- fixture writer ----------------------------------------------------------
# labs: labels to drop. sep=1 puts each on its own wire, sep=0 shares one wire.
proc write_fx {path labs sep {extra_dev 0}} {
  set f [open $path w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  foreach k {G K V S F E} { puts $f "$k {}" }
  if {$sep} {
    set y 0
    foreach l $labs { puts $f "N 0 $y 300 $y {}" ; incr y -100 }
  } else {
    puts $f {N 0 0 300 0 {}}
  }
  set i 0
  foreach l $labs {
    set y [expr {$sep ? -100*$i : 0}]
    puts $f "C {devices/lab_wire} [expr {40 + $i*80}] $y 0 0 {name=l$i lab=$l}"
    incr i
  }
  if {$extra_dev} { puts $f "C {devices/res} 260 0 0 0 {name=Rx value=1k}" }
  close $f
}

# Run <script> in a fresh --nogui child. Returns "ok" if it exited 0 having
# printed SURVIVED, else a short diagnosis. A segfault yields "signal".
proc child {tag body} {
  global scratch xbin
  set sp [file join $scratch child_$tag.tcl]
  set f [open $sp w]
  puts $f "set no_recent_files 1"
  puts $f "set ::XSCHEM_LIBRARY_DEFS [list $::XSCHEM_LIBRARY_DEFS]"
  puts $f {set ::library_registry_defs_only 1}
  puts $f {set ::XSCHEM_LIBRARY_PATH {}}
  puts $f "set ::netlist_dir [list $scratch]"
  puts $f $body
  puts $f {puts SURVIVED ; flush stdout ; exit 0}
  close $f
  set out {}
  set rc [catch {exec $xbin --nogui --pipe -q --nolog --script $sp 2>@1} out]
  if {[string match {*SURVIVED*} $out]} { return ok }
  if {[string match {*signal 11*} $out] || [string match {*SIGSEGV*} $out] \
      || [string match {*Segmentation*} $out]} { return signal }
  return "rc=$rc other"
}

# --- HA: the shared-wire NULL deref ------------------------------------------
foreach {tag labs sep expect desc} {
  a  {#foo #foo}       0 ok "two identical '#' labels on ONE wire"
  b  {#foo #bar}       0 ok "two DIFFERENT '#' labels on one wire"
  c  {#net1 #net2}     0 ok "the engine's OWN format, two labels on one wire"
  d  {#foo #foo #foo}  0 ok "three '#' labels on one wire"
  e  {#foo foo}        0 ok "'#' label first, plain label second"
} {
  set fx [file join $scratch ha_$tag.sch]
  write_fx $fx $labs $sep
  check "HA-$tag `xschem nets` survives: $desc" \
    [child ha_$tag "xschem load [list $fx]\nxschem nets"] $expect
}

# shapes that never crashed -- they must keep working, and they pin the
# characterization (order matters; the sharing is what matters)
set fx [file join $scratch ha_f.sch] ; write_fx $fx {foo #foo} 0
check "HA-f (control) plain label first, '#' second -- the wire is named foo" \
  [child ha_f "xschem load [list $fx]\nxschem nets"] ok
set fx [file join $scratch ha_g.sch] ; write_fx $fx {#foo #foo} 1
check "HA-g (control) two '#' labels on SEPARATE wires" \
  [child ha_g "xschem load [list $fx]\nxschem nets"] ok

# an unlabeled net elsewhere must NOT rescue it: node_mult is freed at prep
# start and refilled only in the later pass. This is what proves NULL deref
# rather than a merely out-of-range index.
set fx [file join $scratch ha_h.sch] ; write_fx $fx {#foo #foo} 0 1
check "HA-h an unrelated auto-named net present -- still must not crash" \
  [child ha_h "xschem load [list $fx]\nxschem nets"] ok

# --- HB: out-of-range read in the vhdl/verilog declaration pass --------------
set fx [file join $scratch hb.sch] ; write_fx $fx {#net99999999} 0 1
foreach fmt {vhdl verilog} {
  check "HB-$fmt `xschem netlist` survives lab=#net99999999" \
    [child hb_$fmt "xschem load [list $fx]\nxschem set netlist_type $fmt\nxschem netlist"] ok
}
set fx [file join $scratch hb2.sch] ; write_fx $fx {#net2000000000} 0 1
check "HB-huge INT_MAX-ish auto-name index does not read out of bounds" \
  [child hb_huge "xschem load [list $fx]\nxschem set netlist_type verilog\nxschem netlist"] ok

# --- S: '#' is reserved ------------------------------------------------------
# The Add Wire Label form is the only label validator that exists today
# (addlabel::name_ok, src/xschem.tcl). It must refuse the engine's namespace.
check "S1 name_ok rejects a user-authored '#foo'"   [addlabel::name_ok {#foo}]  0
check "S2 name_ok rejects the engine format '#net1'" [addlabel::name_ok {#net1}] 0
check "S3 name_ok still accepts an ordinary name"    [addlabel::name_ok {net1}]  1
check "S4 name_ok still accepts SPICE ground 0"      [addlabel::name_ok {0}]     1
check "S5 name_ok still accepts a bus name"          [addlabel::name_ok {A[3:0]}] 1

# --- E: the ERC warning ------------------------------------------------------
# statusmsg(str,2) accumulates into xctx->infowindow_text whether or not there is
# a display, and `xschem get infowindow_text` reads it back -- so this leg has
# teeth in both arms. print_erc is only set for a netlist run, hence `xschem
# netlist` rather than `xschem nets`.
set ::netlist_dir $scratch
proc erc_for {lab} {
  global scratch
  set fx [file join $scratch erc.sch]
  set f [open $fx w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  foreach k {G K V S F E} { puts $f "$k {}" }
  puts $f {N 0 0 300 0 {}}
  puts $f "C {devices/lab_wire} 40 0 0 0 {name=l0 lab=$lab}"
  puts $f {C {devices/res} 260 0 0 0 {name=Rx value=1k}}
  close $f
  xschem load $fx
  catch {xschem netlist}
  set t {}
  catch {set t [xschem get infowindow_text]}
  return [string match {*reserved for auto-named nets*} $t]
}
check "E1 a user-authored '#foo' label raises the reserved-namespace ERC warning" \
  [erc_for {#foo}] 1
# the C-side tooth for is_auto_net_name(): the engine's OWN name must not warn
check "E2 the engine's own '#net1' does NOT warn (strict predicate, not a bare '#')" \
  [erc_for {#net1}] 0
check "E3 an ordinary label does not warn" [erc_for {sig}] 0

# --- N: the emitted netlist ---------------------------------------------------
# net_name() (token.c) is a HYBRID site: its '#' test gates both the multiplicity
# lookup AND the '#'-stripping of the emitted name. The index is now strict while
# the strip stays loose, so a user '#foo' must still reach the deck as `foo` and
# must be SCALAR -- before the fix it borrowed node_mult[atoi("o")] == node 0's
# multiplicity, which can declare a scalar user net as a bus.
proc spice_deck {lab} {
  global scratch
  set fx [file join $scratch nl.sch]
  set f [open $fx w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  foreach k {G K V S F E} { puts $f "$k {}" }
  puts $f {N 0 0 300 0 {}}
  puts $f "C {devices/lab_wire} 40 0 0 0 {name=l0 lab=$lab}"
  puts $f {C {devices/res} 260 0 0 0 {name=Rx value=1k}}
  puts $f {N 260 -100 260 0 {}}
  puts $f {C {devices/gnd} 260 -100 0 0 {name=GND1 lab=GND}}
  close $f
  xschem load $fx
  xschem set netlist_type spice
  catch {xschem netlist}
  set out [file join $scratch nl.spice]
  if {![file exists $out]} { return "NO-DECK" }
  set fh [open $out r] ; set t [read $fh] ; close $fh
  return $t
}
set deck [spice_deck {#foo}]
check "N1 a user '#foo' net still reaches the deck with the '#' stripped" \
  [expr {[string match {*foo*} $deck] && ![string match {*#foo*} $deck]}] 1
check "N2 it is emitted SCALAR, not widened into a bus" \
  [string match {*foo\[*} $deck] 0

# --- C: controls that must not move -----------------------------------------
# Fly-lines rule A6 excludes ANY '#' net by design (spec hover_flylines §4) --
# this fix must not relax it.
set fx [file join $scratch c1.sch] ; write_fx $fx {#foo} 0 1
xschem load $fx
set fl {}
catch {set fl [dict get [xschem flylines at 150 0] net]}
check "C1 fly-lines A6 still excludes a '#' net (empty result)" $fl {}

# the engine still auto-names unlabeled clusters, and those names still work
set fx [file join $scratch c2.sch]
set f [open $fx w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
foreach k {G K V S F E} { puts $f "$k {}" }
puts $f {N 0 0 300 0 {}}
puts $f {C {devices/res} 150 0 0 0 {name=Rx value=1k}}
close $f
xschem load $fx
check "C2 an unlabeled cluster still gets an engine auto-name" \
  [expr {[llength [lsearch -all -inline [xschem nets] {name {#net*}}]] >= 1}] 1

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
