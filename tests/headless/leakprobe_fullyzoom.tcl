## File: tests/headless/leakprobe_fullyzoom.tcl
##
## THE CHILD OF test_node_token_split.tcl's NDK LEAK LEG (batch F item 2, issue
## 0305 residual (b)). NOT named test_*.tcl on purpose: full_audit.sh globs
## test_*.tcl and would score this zero-check file FAIL forever.
##
## graph_fullyzoom()'s two refusals used to be bare `return 0`s that hand-copied
## a subset of the function's my_free()s -- and `ntok_copy`, the only per-entry
## allocation node_token_split() hands out, was in NEITHER subset. So every
## refused fullyzoom leaked strlen(the node token) + 1 bytes. That is a LEAK, and
## a leak is not provable by reading the source: this script makes K refusals in
## one process so a parent can run it twice with two different K under
## `-d 3 -l <log>` and take the SLOPE from src/track_memory.awk.
##
## The differential is the measurement. With _ALLOC_ID_ left as the placeholder 0
## (the normal build) every allocation carries the same id, so the absolute
## "unfreed" total is meaningless noise -- process teardown, Tcl, the fixture --
## and only its CHANGE per refusal says anything. Slope 0 = nothing leaks.
##
## Run standalone:
##   ND_LEAK_K=5 ./src/xschem --pipe -q --nolog --nogui -d 3 -l /tmp/k5.log \
##       --script tests/headless/leakprobe_fullyzoom.tcl
##   awk -f src/track_memory.awk /tmp/k5.log nosource | tail -2

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch ndleak]
set ::XSCHEM_LIBRARY_PATH {}

set K 5
if {[info exists ::env(ND_LEAK_K)] && [string is integer -strict $::env(ND_LEAK_K)]} {
  set K $::env(ND_LEAK_K)
}

proc wr {p s} { set fp [open $p w]; puts -nonewline $fp $s; close $fp }

## the strip's GRAPH-level database: it must RESOLVE, so that the per-trace
## refusal below happens with the graph-level switch outstanding -- the only
## shape in which the old `return 0` both leaked and stranded the session.
proc mkraw_wide {path {tmax 2.0e-9} {n 41}} {
  set body "Title: nd-wide\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(wonly)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$i * $tmax / ($n - 1)}]
    set v [expr {0.60 + 0.05 * $t / $tmax}]
    append body "$i\t$t\n\t$v\n\n"
  }
  wr $path $body
}

set widef  [file join $scratch wide.raw]
set nosuch [file join $scratch nosuch_pertrace.raw]
mkraw_wide $widef

xschem clear force
xschem raw clear
xschem raw read $widef tran

## entry 1 resolves in the graph's database, so node_token_split() has handed out
## an ntok_copy by the time entry 2's `%<rawfile>` fails to resolve: that is the
## outstanding allocation the old bypass walked away from.
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem setprop rect 2 0 node "v(wonly)\n\\\"bad;v(wonly)%$nosuch tran\\\""
foreach {t v} [list x1 0 x2 2e-9 y1 0.4 y2 0.6] { xschem setprop rect 2 0 $t $v }
xschem setprop rect 2 0 rawfile $widef
xschem setprop rect 2 0 sim_type tran

for {set k 0} {$k < $K} {incr k} {
  xschem setprop rect 2 0 fullyzoom
}
puts "LEAKPROBE: K=$K done"
exit 0
