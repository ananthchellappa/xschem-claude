# Phase 5 (library-manager) — integration: the Python migrator's output is
# consumable by the real xschem engine (Phases 1-4). Migrates a flat fixture
# with tools/migrate/xschem_libmigrate.py, points xschem at the GENERATED
# library.defs, then loads + netlists the migrated schematic.
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_migrate_engine.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }

set repo [file normalize [file join [pwd] ..]]
set tool [file join $repo tools/migrate/xschem_libmigrate.py]

# --- flat source fixture: real resistor symbol + a schematic referencing it ---
set tmp [file join [pwd] _migeng_[pid]]
file delete -force $tmp
file mkdir $tmp/src/devices $tmp/src/des
file copy [file join $repo xschem_library/devices/res.sym]     $tmp/src/devices/res.sym
file copy [file join $repo xschem_library/devices/lab_pin.sym] $tmp/src/devices/lab_pin.sym
set fp [open $tmp/src/des/tb.sch w]
puts $fp "v {xschem version=3.4.0 file_version=1.3}"
puts $fp "C {res.sym} 0 0 0 0 {name=R1 value=1k}"
puts $fp "C {lab_pin.sym} 0 -30 0 0 {name=l1 lab=A}"
puts $fp "C {lab_pin.sym} 0 30 0 0 {name=l2 lab=B}"
close $fp

# --- run the Python migrator -------------------------------------------------
set out $tmp/out
set rc [catch {exec python3 $tool --dst $out \
  --lib devices=$tmp/src/devices --lib des=$tmp/src/des 2>@1} msg]
check "ME0 migrator ran" [expr {$rc == 0}] "($msg)"

# --- the engine consumes the generated tree ---------------------------------
set ::XSCHEM_LIBRARY_DEFS $out/library.defs
set ::netlist_dir $tmp
xschem set netlist_type spice

set mig $out/des/tb/schematic/tb.sch
check "ME1 migrated schematic exists" [file isfile $mig] "($mig)"
check "ME2 refs rewritten lib-qualified" \
  [expr {[regexp {C \{devices/res\}} [slurp $mig]] && [regexp {C \{devices/lab_pin\}} [slurp $mig]]}] {}

xschem load $mig
check "ME3 engine loaded all instances" [expr {[xschem get instances] == 3}] "(=> [xschem get instances])"
check "ME4 cellview resolves migrated symbol" \
  [expr {[xschem cellview_path devices/res symbol] eq "$out/devices/res/symbol/res.sym"}] \
  "(=> [xschem cellview_path devices/res symbol])"

xschem netlist
set spice $tmp/tb.spice
set ok [expr {[file exists $spice] && [regexp -line {^R1 A B 1k} [slurp $spice]]}]
check "ME5 netlist correct (R1 A B 1k)" $ok {}

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
