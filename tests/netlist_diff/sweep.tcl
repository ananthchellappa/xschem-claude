# Netlist every schematic under a library root, in every backend, into $OUTDIR.
# Driven by tests/netlist_diff/netlist_diff.sh -- see the README there.
#
# Environment:
#   OUTDIR    where the netlists go (created, wiped first). REQUIRED.
#   LIBROOT   library root to walk. Default: <repo>/xschem_library
#   FORMATS   backends to run. Default: spice spectre verilog vhdl tedax
#
# Deliberately catches per-design errors rather than aborting: a design that
# cannot be netlisted must not hide the 900 that can, and "errored in both arms"
# is itself a comparison the caller can make.

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]

if {![info exists ::env(OUTDIR)]} { puts "sweep.tcl: OUTDIR not set" ; exit 1 }
set out $::env(OUTDIR)
set libroot [expr {[info exists ::env(LIBROOT)] ? $::env(LIBROOT) : [file join $repo xschem_library]}]
set formats [expr {[info exists ::env(FORMATS)] ? $::env(FORMATS) : {spice spectre verilog vhdl tedax}}]

file delete -force $out
file mkdir $out
set ::netlist_dir $out

# Three glob levels covers xschem_library's actual depth. Sorted so the two arms
# visit designs in the same order -- netlisting is not order-dependent, but a
# deterministic order makes a partial run comparable to a complete one.
set files [lsort [glob -nocomplain -directory $libroot -types f *.sch */*.sch */*/*.sch]]
puts "sweep: [llength $files] schematics x [llength $formats] backends"

set runs 0 ; set errs 0
foreach fmt $formats {
  foreach f $files {
    if {[catch { xschem load $f ; xschem set netlist_type $fmt ; xschem netlist } e]} {
      incr errs
      puts "ERR \[$fmt\] [file tail $f]: $e"
    }
    incr runs
  }
}
puts "sweep: RUNS=$runs ERRORS=$errs"
flush stdout
exit 0
