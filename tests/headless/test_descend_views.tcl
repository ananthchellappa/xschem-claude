# Phase 4 (library-manager) — descend & symbol<->schematic association by view.
# Descending into an instance must open the cell's SCHEMATIC VIEW
# (<lib>/<cell>/schematic/<cell>.sch), not the legacy ".sch next to the symbol"
# location (which for the new layout would wrongly be <cell>/symbol/<cell>.sch).
#   D1  descend a lib-qualified subcircuit -> its schematic view
#   D2  an instance 'schematic=<lib/other>' override -> other's schematic view
#   D3  a legacy flat subcircuit still descends to the flat <cell>.sch (compat)
#
# Run under X with --pipe from src/:
#   ./xschem --pipe -q --script ../tests/headless/test_descend_views.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc norm {p} { return [file normalize $p] }

# --- fixture: new-layout library 'tlib' (cells sub, other) + a flat 'flatlib' ---
# cmos_inv.{sym,sch} is a real type=subcircuit cell, reused as the cell bodies.
# Paths derived from [info script], never [pwd] (cwd-independence, cf. 389c5319):
# the old [pwd]/../xschem_library only resolved when launched from src/, and under
# full_audit (cwd = repo root) the failed copy raised a blocking error popup.
set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set tmp /tmp/_desc_test_[pid]
file delete -force $tmp
set SYMSRC [file join $REPO xschem_library/examples/cmos_inv.sym]
set SCHSRC [file join $REPO xschem_library/examples/cmos_inv.sch]
file mkdir $tmp/tlib/sub/symbol   $tmp/tlib/sub/schematic
file mkdir $tmp/tlib/other/symbol $tmp/tlib/other/schematic
file mkdir $tmp/flatlib
file copy $SYMSRC $tmp/tlib/sub/symbol/sub.sym
file copy $SCHSRC $tmp/tlib/sub/schematic/sub.sch
file copy $SYMSRC $tmp/tlib/other/symbol/other.sym
file copy $SCHSRC $tmp/tlib/other/schematic/other.sch
file copy $SYMSRC $tmp/flatlib/fsub.sym
file copy $SCHSRC $tmp/flatlib/fsub.sch

set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
lappend ::pathlist "$tmp/flatlib"

# build a one-instance parent, save it (so descend won't try to save), select the
# instance, descend, read the loaded schematic path, then return to the top.
proc descend_to {parent ref props} {
  xschem clear force schematic
  xschem instance $ref 0 0 0 0 $props
  xschem saveas $parent schematic
  xschem select instance x1
  xschem descend
  set got [xschem get schname]
  xschem go_back 2
  return $got
}

set SUBSCH   $tmp/tlib/sub/schematic/sub.sch
set OTHERSCH $tmp/tlib/other/schematic/other.sch
set FSUBSCH  $tmp/flatlib/fsub.sch

# --- D1 — lib-qualified subcircuit descends to its schematic view ------------
set g1 [descend_to $tmp/p1.sch tlib/sub {name=x1}]
check "D1 descend lib-qualified -> schematic view" [expr {[norm $g1] eq [norm $SUBSCH]}] "(=> $g1)"

# --- D2 — schematic= override (lib-qualified) -> other's schematic view ------
set g2 [descend_to $tmp/p2.sch tlib/sub {name=x1 schematic=tlib/other}]
check "D2 schematic= override -> override view" [expr {[norm $g2] eq [norm $OTHERSCH]}] "(=> $g2)"

# --- D3 — legacy flat subcircuit still descends to the flat .sch -------------
set g3 [descend_to $tmp/p3.sch fsub.sym {name=x1}]
check "D3 legacy flat descend unchanged" [expr {[norm $g3] eq [norm $FSUBSCH]}] "(=> $g3)"

# --- D4 — hierarchical netlist resolves the lib-qualified subcircuit ---------
# The netlister calls the SAME get_sch_from_sym (with inst=-1) to find a
# subcircuit's schematic view, so its .subckt must appear in the spice netlist.
xschem set netlist_type spice
set ::netlist_dir $tmp
xschem clear force schematic
xschem instance tlib/sub 0 0 0 0 {name=x1}
xschem saveas $tmp/top.sch schematic
xschem netlist
set ndef 0
set nl [file join $tmp top.spice]
if {[file exists $nl]} {
  set fp [open $nl r]; set d [read $fp]; close $fp
  # require the .subckt header AND its real body (the two cmos_inv transistors):
  # the header alone is emitted from the symbol pins even when the schematic view
  # is not found, so the M1/M2 lines are what prove the schematic was netlisted.
  set ndef [expr {[regexp -nocase {\.subckt\s+sub\M} $d] &&
                  [regexp -line {^M1 } $d] && [regexp -line {^M2 } $d]}]
}
check "D4 hierarchical netlist emits .subckt sub with body" $ndef {}

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
