# tests/headless/tools/unused_attr_sweep.tcl -- A MEASURING TOOL, NOT A TEST.
#
# ⚠ IT IS DELIBERATELY NOT NAMED test_*.tcl AND IS NOT REGISTERED ANYWHERE.
# Nothing in the tree runs it, and nothing should: it netlists every schematic
# under xschem_library/ to SPICE and prints the netlist-time "you typed this and
# it had no effect" warnings, so its output is a MEASUREMENT of how loud that
# diagnostic is on shipped data. It has no pass/fail and no golden file. The
# rows that hold the diagnostic still live in
# tests/headless/test_unused_attr_0970.tcl.
#
# WHY IT IS COMMITTED AT ALL. The number this prints -- sheets / lines / false --
# is the noise budget, and it is the number every pass on this diagnostic has
# been judged by: 18 sheets / 149 lines / 43 false (issue 0970 as shipped),
# 11 / 98 / 0 (issue 0980's correction), and whatever it says now. Two earlier
# passes rewrote this script from scratch because the previous one was left in
# /tmp, and a budget nobody can re-measure is a budget nobody checks.
#
# HOW TO READ IT:
#   sheets_with_lines  how many shipped sheets say anything at all
#   lines              how many sentences in total
#   A / B              A accuses -- nothing anywhere reads the setting, take it
#                      off. B says the SPICE deck drops it while another netlist
#                      of the same cell carries it, so do NOT take it off.
#   suspect            a line whose deck contains the literal <setting>=<value>
#                      the sentence names -- the cheap test for a FALSE line,
#                      because a setting that reached the deck is written that
#                      way in it. It still over-reports: the .subckt line carries
#                      the CELL DEFAULT in the same spelling, so an instance that
#                      typed the default value looks like a hit. Every suspect
#                      must be opened by hand and judged by whether the value
#                      reached the instance it was typed on. A line that survives
#                      that reading is a real defect in the diagnostic, and the
#                      count of those must be zero.
#   loose              the older, blunter test: the value TEXT occurs anywhere in
#                      the deck. Kept only because it is what earlier passes
#                      counted; a value of "1" matches almost any deck, so it is
#                      not a defect count and must not be read as one.
#
# RUN:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/tools/unused_attr_sweep.tcl

set no_recent_files 1
set repo [file normalize [file join [file dirname [info script]] .. .. ..]]
set out [expr {[info exists ::env(UA_SWEEP_OUT)] ? $::env(UA_SWEEP_OUT) : "/tmp/ua_sweep"}]
file mkdir $out
set ::netlist_dir $out

proc ua_lines {} {
  set o {}
  foreach ln [split [xschem get infowindow_text] \n] {
    if {[string first {did not reach the simulator} $ln] >= 0} { lappend o [string trim $ln] }
  }
  return $o
}
proc ua_kind {l} {
  set b [expr {[string first {does not pass} $l] >= 0 &&
               [string first {SPICE netlist of} $l] >= 0}]
  set a [expr {[string first {never reads} $l] >= 0}]
  if {$a && $b} { return AB }
  if {$b} { return B }
  if {$a} { return A }
  return ?
}
## The setting and the value the sentence names, pulled back out of it.
proc ua_setting {l} {
  if {[regexp { sets ([^=]+)=(.*?), but } $l -> p v]} { return [list $p $v] }
  return {}
}
proc ua_slurp {path} {
  if {![file exists $path]} { return {} }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}

set sheets 0 ; set spoke 0 ; set lines 0
set nA 0 ; set nB 0 ; set nOther 0 ; set suspect 0 ; set loose 0
foreach f [lsort [glob -nocomplain -directory [file join $repo xschem_library] \
                    -types f */*.sch */*/*.sch *.sch]] {
  incr sheets
  catch {xschem load $f}
  catch {xschem set netlist_type spice}
  catch {xschem netlist}
  set l [ua_lines]
  if {[llength $l] == 0} { continue }
  incr spoke
  incr lines [llength $l]
  set deck [ua_slurp [file join $out "[file rootname [file tail $f]].spice"]]
  puts "SHEET [file join [file tail [file dirname $f]] [file tail $f]] [llength $l]"
  foreach x $l {
    set k [ua_kind $x]
    switch -- $k { A { incr nA } B { incr nB } default { incr nOther } }
    set pv [ua_setting $x]
    set mark ok
    if {[llength $pv] == 2} {
      set v [lindex $pv 1]
      if {$v ne {} && [string first {...} $v] < 0 && [string first $v $deck] >= 0} {
        set mark loose ; incr loose
      }
      if {$v ne {} && [string first {...} $v] < 0 &&
          [string first "[lindex $pv 0]=$v" $deck] >= 0} {
        set mark SUSPECT ; incr suspect
      }
    }
    puts "  LINE $k $mark: $x"
  }
}
puts "SWEEP sheets_scanned=$sheets sheets_with_lines=$spoke lines=$lines\
 A=$nA B=$nB other=$nOther suspect=$suspect loose=$loose"
exit 0
