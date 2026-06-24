## File: harness.tcl
## Headless driver for the xschem test harness. Invoked as:
##   xschem --rcfile minrc --netlist_path <dir> --pipe -q --script harness.tcl
## Environment:
##   REPO       absolute repo root
##   CASES_FILE manifest of schematics (paths relative to REPO)
## Emits a deterministic per-case state report on stdout and writes one
## SPICE netlist per case into the pinned netlist directory.

set repo $env(REPO)
set cases_file $env(CASES_FILE)

proc read_cases {f} {
  set out {}
  set fd [open $f r]
  while {[gets $fd line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string index $line 0] eq "#"} continue
    lappend out $line
  }
  close $fd
  return $out
}

puts "HARNESS_BEGIN"
puts "xschem_version=[xschem get version]"

foreach rel [read_cases $cases_file] {
  set path $repo/$rel
  if {![file exists $path]} {
    puts "== $rel =="
    puts "  ERROR missing_file"
    continue
  }
  if {[catch {xschem load $path} e]} {
    puts "== $rel =="
    puts "  ERROR load_failed $e"
    continue
  }
  set inst  [xschem get instances]
  set wires [xschem get wires]
  ## Guard against the silent "loaded an empty schematic" failure mode:
  ## every manifest case is expected to contain at least one instance.
  set empty [expr {$inst == 0 ? " EMPTY!" : ""}]
  if {[catch {xschem netlist} e]} {
    puts "== $rel =="
    puts "  instances=$inst wires=$wires$empty"
    puts "  ERROR netlist_failed $e"
    continue
  }
  puts "== $rel =="
  puts "  instances=$inst wires=$wires$empty"
}

puts "HARNESS_END"
exit 0
