# Sweep-diff regression over the tests/test_sweep_diff/ library fixture (imported
# from PR #4 — a 12-library tree of real-world cells). For every .sym and .sch it
# asserts two things:
#
#   1. it LOADS without crashing the file parser, and
#   2. it ROUND-TRIPS identically:  load -> saveas A -> load A -> saveas B,  A == B.
#
# (2) catches save/load asymmetries (a real bug class in save.c / the loader) with
# no false positives: we never diff against the original on-disk formatting — we
# compare two xschem-produced files (A vs B), which must be byte-identical.
# Unresolved symbol refs from the migrated tree are fine; they round-trip too.
#
# Portable by design:
#   * locates the fixture relative to this script ([info script]) — cwd-independent,
#   * pure-Tcl byte comparison — no `exec diff`, so it runs on Windows too,
#   * true headless: no X needed (run with --nogui).
# A crash aborts the process mid-sweep, so the last "at:" line names the offending
# cell and the harness sees no "RESULT:" line -> failure.
#
# Run:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sweep_diff.tcl

set here    [file dirname [file normalize [info script]]]
set fixroot [file normalize [file join $here .. test_sweep_diff]]
if {![file isdirectory $fixroot]} {
  puts "RESULT: SKIP (fixture not found at $fixroot)"; flush stdout; exit 0
}

# best-effort symbol resolution (the round-trip invariant holds regardless)
if {![info exists ::XSCHEM_LIBRARY_PATH]} { set ::XSCHEM_LIBRARY_PATH {} }
set ::XSCHEM_LIBRARY_PATH "$fixroot:$::XSCHEM_LIBRARY_PATH"

set work [file join [file dirname $fixroot] _sweep_work_[pid]]
file delete -force $work; file mkdir $work

# recursive file finder (Tcl 8.6 has no glob **), so the test is structure-agnostic
proc findfiles {dir pat} {
  set res {}
  foreach d [glob -nocomplain -type d -directory $dir *] { lappend res {*}[findfiles $d $pat] }
  lappend res {*}[glob -nocomplain -type f -directory $dir $pat]
  return $res
}
proc slurp {f} { set h [open $f rb]; set d [read $h]; close $h; return $d }

set syms [lsort [findfiles $fixroot *.sym]]
set schs [lsort [findfiles $fixroot *.sch]]
set fail 0; set n 0
foreach f [concat $syms $schs] {
  incr n
  set type [expr {[string match *.sym $f] ? {symbol} : {schematic}}]
  set ext  [expr {$type eq {symbol} ? {.sym} : {.sch}}]
  set a [file join $work a$ext]
  set b [file join $work b$ext]
  set rel [string range $f [expr {[string length $fixroot] + 1}] end]
  puts "at: $rel"; flush stdout                ;# crash attribution: last line before a SIGSEGV
  if {[catch {xschem load $f ; xschem saveas $a $type} e]} {
    puts "FAIL: $rel -- load/save errored: $e"; incr fail; continue
  }
  if {[catch {xschem load $a ; xschem saveas $b $type} e]} {
    puts "FAIL: $rel -- reload/save errored: $e"; incr fail; continue
  }
  if {[slurp $a] ne [slurp $b]} {
    puts "FAIL: $rel -- non-idempotent round-trip (saveas A != saveas B)"; incr fail; continue
  }
}
file delete -force $work
puts "swept $n cells ([llength $syms] sym + [llength $schs] sch)"
if {$fail == 0} { puts "RESULT: ALL PASS ($n cells)" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
