# del_negative_arg_child.tcl — the CHILD process of test_del_negative_arg.tcl.
#
# NOT a suite (deliberately not named test_*.tcl: full_audit.sh globs those and
# would score a zero-check file FAIL forever).  It exists because two of that
# suite's obligations cannot be met from inside the parent:
#
#  * "a negative del() must not read out of bounds" is a MEMORY property, and
#    the only witness in this tree is valgrind — which has to wrap a whole
#    process.  Parent DN11 runs this file under
#    `valgrind -q --error-exitcode=42` and asserts the exit status.
#  * the del() window widening (`first` pulled back to the dataset start,
#    spec §3.2) is only visible when the CALLER passes a first > 0, and the
#    only caller that does is the graph redraw (src/draw.c:9171, :9221).
#    Parent DN12 runs mode `node` under `-d 1` and reads the two
#    plot_raw_custom_data() window lines back.
#
# Driven by environment variables, so the parent controls it without argv:
#   DN_DIR   scratch directory (required) — every file is written under it
#   DN_MODE  mem  | node
#   DN_EXPR  the RPN put in the graph's node= (node mode)
#   DN_X1    graph x1, i.e. how much of the wave is clipped off the left
#            (node mode; a value > 0 is what makes the caller's first > 0)
#
# mode `mem` is true headless and exercises, in one process:
#   - a positive del()               (the behaviour under protection)
#   - a rejected negative del() into an EXISTING column
#   - a rejected negative del() into a NEW vector, whose values are then read
#     back through Tcl  (issue 0325: raw_add_vector() must have zeroed it, or
#     this reads uninitialised heap)
#   - a rejection that follows a ravg() on a SMALL raw, then a bigger raw and a
#     plain ravg()  (issue 0325: the guard must release ravg_store()'s static
#     arr[] on the way out, or the next ravg() writes past rows sized for the
#     old, shorter window)
#
# mode `node` is the shipped GUI door: a graph rect carrying node=<expr>,
# redrawn twice.  Needs a DISPLAY.

proc dn_mkraw {path np} {
  set body "Title: del negative arg child\nDate: Thu Jan  1 00:00:00 2026\n"
  append body "Plotname: Transient Analysis\nFlags: real\n"
  append body "No. Variables: 2\nNo. Points: $np\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $np} {incr i} {
    append body "$i\t[expr {$i * 1e-9}]\n\t[expr {double($i)}]\n\n"
  }
  set fp [open $path w] ; puts -nonewline $fp $body ; close $fp
}

set dir $::env(DN_DIR)
set mode $::env(DN_MODE)

if {$mode eq "mem"} {
  dn_mkraw $dir/child_small.raw 8
  dn_mkraw $dir/child_big.raw   64
  xschem raw clear
  xschem raw_read $dir/child_small.raw tran
  # the control: a positive del() must still be walked
  xschem raw add k {v(a) 2.6e-09 del()}
  # the defect: rejected into an EXISTING column
  xschem raw add k {v(a) -2.6e-09 del()}
  # the defect: rejected into a NEW vector — then READ, so an unzeroed column
  # is an uninitialised-value use and not merely an unread allocation
  xschem raw add brandnew {v(a) -2.6e-09 del()}
  set col {}
  for {set i 0} {$i < 8} {incr i} { lappend col [xschem raw value brandnew $i] }
  puts "CHILD brandnew: $col"
  # the static scratch: ravg() stores into arr[i] sized for THIS window, then
  # the del() is rejected; the next raw is longer
  xschem raw add rv {v(a) 2e-09 ravg() -1 del()}
  xschem raw clear
  xschem raw_read $dir/child_big.raw tran
  xschem raw add rv2 {v(a) 2e-09 ravg()}
  xschem raw clear
  puts "CHILD mem done"
} elseif {$mode eq "node"} {
  set e $::env(DN_EXPR)
  set x1 [expr {[info exists ::env(DN_X1)] ? $::env(DN_X1) : 0}]
  dn_mkraw $dir/child_node.raw 8
  # build the graph rect the way the other graph suites do (the `\n`-escaped
  # property blob written straight into a .sch comes back with the backslashes
  # eaten, so x1/x2/node never take)
  xschem set rectcolor 2
  xschem rect 0 0 800 400 -1 {flags=graph} 0
  foreach {t v} [list x1 $x1 x2 7e-09 y1 -1 y2 8 divx 5 divy 5 \
                      dataset -1 sim_type tran rawfile $dir/child_node.raw] {
    xschem setprop rect 2 0 $t $v
  }
  xschem setprop rect 2 0 node $e
  xschem raw clear
  xschem raw_read $dir/child_node.raw tran
  xschem redraw
  xschem redraw
  xschem raw clear
  puts "CHILD node done"
} else {
  puts "CHILD unknown mode: $mode"
  exit 2
}
flush stdout
exit 0
