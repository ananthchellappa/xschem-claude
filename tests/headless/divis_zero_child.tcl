# divis_zero_child.tcl — the CHILD process of test_divis_zero_1628.tcl.
#
# NOT a suite (deliberately not named test_*.tcl: full_audit.sh globs those and
# would score a zero-check file FAIL forever).  Same shape, and for the same two
# reasons, as tests/headless/del_negative_arg_child.tcl — issue 0325's helper,
# which is this file's template because 1628 is the same defect class in the
# same function:
#
#  * "x/0 at the first point must not read before the destination column" is a
#    MEMORY property, and the only witness in this tree is valgrind, which has
#    to wrap a whole process.  Parent band DZ5 runs mode `mem` under
#    `valgrind -q --error-exitcode=42` and asserts the exit status.
#  * "the graph door passes a first > 0" is a claim about a CALLER, and the only
#    place the number is visible is plot_raw_custom_data()'s own `-d 1` line.
#    Parent band DZ2 runs mode `win` under `-d 1` and reads those lines back.
#
# Driven by environment variables, so the parent controls it without argv:
#   DZ_DIR   scratch directory (required) — every file is written under it
#   DZ_MODE  mem | win
#
# Both modes are true headless: the graph-marker door (`xschem graph_marker
# add_at` -> graph_marker_create_at -> graph_marker_sample -> the evaluator)
# needs no DISPLAY, which is why this suite can be an `hcases` entry at all.

# A single-dataset ascii transient raw.  read_dataset() takes Plotname then the
# ascii Values: block.  Columns:
#   v(a) = i + 1      the numerator, never zero
#   v(z) = 0          a divisor that is zero at EVERY point
#   v(m) = 2, but 0 at point 3   a divisor that goes to zero MID-window
proc dz_plot {np base zero_at} {
  set b "Plotname: Transient Analysis\nFlags: real\n"
  append b "No. Variables: 4\nNo. Points: $np\nVariables:\n"
  append b "\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(z)\tvoltage\n\t3\tv(m)\tvoltage\n"
  append b "Values:\n"
  for {set i 0} {$i < $np} {incr i} {
    append b "$i\t[expr {$i * 1e-9}]\n\t[expr {double($i) + $base}]\n\t0\n"
    append b "\t[expr {$i == $zero_at ? 0 : 2.0}]\n\n"
  }
  return $b
}
proc dz_mkraw {path plots} {
  set body "Title: divis zero child\nDate: Thu Jan  1 00:00:00 2026\n"
  foreach p $plots { append body $p }
  set fp [open $path w] ; puts -nonewline $fp $body ; close $fp
}

# The graph door, built the way del_negative_arg_child.tcl builds it: the
# `\n`-escaped property blob written straight into a .sch comes back with the
# backslashes eaten, so x1/x2/node never take — set each token with setprop.
proc dz_graph {expr_ rawpath} {
  xschem set rectcolor 2
  xschem rect 0 0 800 400 -1 {flags=graph} 0
  foreach {t v} [list x1 0 x2 7e-09 y1 -1000 y2 1000 divx 5 divy 5 \
                      dataset -1 sim_type tran] {
    xschem setprop rect 2 0 $t $v
  }
  xschem setprop rect 2 0 node $expr_
}

set dir $::env(DZ_DIR)
set mode $::env(DZ_MODE)

if {$mode eq "mem"} {
  dz_mkraw $dir/child_one.raw [list [dz_plot 8 1.0 3]]
  xschem raw clear
  xschem raw_read $dir/child_one.raw tran
  # the control: an ordinary quotient and the mid-window hold must still run
  xschem raw add ctl {v(a) v(m) /}
  # the defect at p == first == 0, into a NEW vector — then READ back through
  # Tcl, so a column the evaluator filled from before its own start is an
  # uninitialised-value USE and not merely an unread allocation
  xschem raw add zer {1 0 /}
  set col {}
  for {set i 0} {$i < 8} {incr i} { lappend col [xschem raw value zer $i] }
  puts "CHILD zer: $col"
  # ...and with a VECTOR numerator, which is the shape a user types
  xschem raw add zer2 {v(a) v(z) /}
  set col {}
  for {set i 0} {$i < 8} {incr i} { lappend col [xschem raw value zer2 $i] }
  puts "CHILD zer2: $col"
  xschem raw clear

  # the graph-marker door, first > 0: dataset 1 starts at absolute point 8, and
  # its divisor column is zero at that very point
  dz_mkraw $dir/child_two.raw [list [dz_plot 8 1.0 3] [dz_plot 8 101.0 0]]
  xschem raw_read $dir/child_two.raw tran
  dz_graph {v(a) v(m) /} $dir/child_two.raw
  foreach {ds pt} {0 3 1 8 1 9} {
    set n [xschem graph_marker add_at 0 0 $ds $pt]
    puts "CHILD marker ds=$ds pt=$pt -> n=$n"
  }
  puts "CHILD marker list: [xschem graph_marker list]"
  xschem raw clear
  puts "CHILD mem done"
} elseif {$mode eq "win"} {
  # -d 1 mode: the ONLY place the caller's `first` is visible is
  # plot_raw_custom_data()'s own dbg(1) line.  Place a marker on dataset 1 so
  # the evaluator is called with that dataset's offset.
  dz_mkraw $dir/child_two.raw [list [dz_plot 8 1.0 3] [dz_plot 8 101.0 0]]
  xschem raw clear
  xschem raw_read $dir/child_two.raw tran
  dz_graph {v(a) v(m) /} $dir/child_two.raw
  xschem graph_marker add_at 0 0 1 9
  xschem raw clear
  puts "CHILD win done"
} else {
  puts "CHILD unknown mode: $mode"
  exit 2
}
flush stdout
exit 0
