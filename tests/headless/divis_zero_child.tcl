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
#   DZ_MODE  mem | win | dsw
#   DZ_EXPR  dsw mode only: which expression of the band's list to evaluate
#
# Mode `dsw` serves issue 1650's band DS9: the EVALUATED WINDOW the engine
# settles on after its token scan is visible in nothing but
# plot_raw_custom_data()'s own dbg(1) line, so "each dataset is evaluated as its
# own sweep, and the backward widening never leaves that dataset" can only be
# asserted from a -d 1 child.  ONE expression per process on purpose: stdout is
# buffered and dbg() is not, so attributing interleaved window lines to the
# expression that produced them is a guess, while one process is a fact.
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

  # ISSUE 1650.  raw_add_vector() now calls the evaluator ONCE PER DATASET, so
  # every `p == first` reset and every backward subscript happens once per
  # dataset instead of once per file, and ravg_store()'s arr[] row — sized
  # `last + 1` at its first store and never resized — is allocated afresh per
  # call.  Each expression below is read BACK through Tcl, so a column element
  # the evaluator filled from outside its own window is an uninitialised-value
  # USE and not merely an unread allocation.  The compounds chain several
  # stateful opcodes in one expression, which is how the del()/ravg() store is
  # reached with a prevp that has walked.
  dz_mkraw $dir/child_ds.raw [list [dz_plot 8 1.0 3] [dz_plot 8 101.0 6]]
  xschem raw_read $dir/child_ds.raw tran
  set i 0
  foreach e [list {v(a) integ()} {v(a) deriv()} {v(a) deriv0()} {v(a) deriv2()} \
                  {v(a) deriv20()} {v(a) prev()} {v(a) cph()} {v(a) avg()} \
                  {v(a) 3e-09 ravg()} {v(a) 3e-09 del()} {idx()} \
                  {v(a) v(z) /} \
                  {v(a) integ() 3e-09 del()} \
                  {v(a) deriv() integ() prev() avg()} \
                  {v(a) dup() * integ() sqrt()} \
                  {v(a) 3e-09 ravg() deriv2() prev() 2e-09 del() integ()}] {
    xschem raw add ds_$i $e
    set col {}
    for {set k 0} {$k < 16} {incr k} { lappend col [xschem raw value ds_$i $k] }
    puts "CHILD ds_$i: $col"
    incr i
  }
  xschem raw clear

  # ISSUE 1650's MULTI-OP EXEMPTION, under valgrind.  raw_dataset_start()'s new
  # condition reads xctx->raw->sim_type and npoints[0] on a database the clamp
  # is reached with `first == last`, and the marker door then evaluates stateful
  # opcodes over a window the token scan widened BACKWARDS across what the
  # dataset table calls a boundary.  Nothing else in band DZ5 drives a
  # multi-dataset Operating Point raw, so without this leg the gate's only
  # memory witness never sees the code the repair added.
  set fp [open $dir/child_op.raw w]
  foreach {x y} {1.0 2.0 2.0 5.0 4.0 13.0 7.0 22.0} {
    puts -nonewline $fp "Plotname: Operating Point\nFlags: real\nNo. Variables: 2\nNo. Points: 1\nVariables:\n\t0\tsweep\tvoltage\n\t1\tv(out)\tvoltage\nValues:\n0\t$x\n\t$y\n\n"
  }
  close $fp
  xschem raw_read $dir/child_op.raw
  xschem set rectcolor 2
  xschem rect 0 0 800 400 -1 {flags=graph} 0
  foreach {t v} [list x1 -1e9 x2 1e9 y1 -1e9 y2 1e9 divx 5 divy 5 dataset -1] {
    xschem setprop rect 2 0 $t $v
  }
  foreach e [list {v(out) deriv()} {v(out) prev()} {v(out) integ()} {v(out) deriv2()} \
                  {v(out) 3.0 del()} {v(out) 1 *}] {
    xschem setprop rect 2 0 node $e
    set col {}
    foreach d {0 1 2 3} {
      set n [xschem graph_marker add_at 0 0 $d $d]
      if {$n eq ""} { lappend col NOMARKER ; continue }
      foreach m [xschem graph_marker list] {
        if {[lindex $m 0] eq $n} { lappend col [lindex $m 6] }
      }
    }
    puts "CHILD op {$e}: $col"
    # ...and through the Tcl door too, which is where the coalesce runs
    xschem raw add op_[string length $e] $e
  }
  xschem raw clear
  puts "CHILD mem done"
} elseif {$mode eq "dsw"} {
  set fixture [file join [file dirname [info script]] data calc_fixture.raw]
  set exprs [list {v(sq)} {v(sq) integ()} {v(sq) deriv()} {v(sq) deriv2()} \
                  {v(sq) prev()} {v(sq) integ() 0.003 del()}]
  set e [lindex $exprs $::env(DZ_EXPR)]
  xschem raw clear
  xschem raw_read $fixture
  xschem raw add dsw_win $e
  xschem raw clear
  puts "CHILD dsw done"
} elseif {$mode eq "gwin"} {
  # ISSUE 1650, bands DS15/DS16.  The VISIBLE-RUN family of graph-door callers,
  # which is the other half of the eight `plot_raw_custom_data()` call sites in
  # src/draw.c: `calc_custom_data_yrange()` walks the points of each dataset,
  # finds the run that falls inside the graph's x window, and calls the
  # evaluator with that run's own `first`/`last`.  That `first` is a MID-DATASET
  # index, not a dataset offset, so it is the one shape where the clamp must NOT
  # fire -- and it is reached by `xschem setprop rect <l> <n> fullyzoom`, which
  # needs no DISPLAY.
  #
  # ONE LEG PER PROCESS, for the same reason mode `dsw` is one expression per
  # process: stdout is buffered and dbg() is not, so attributing interleaved
  # window lines to the leg that produced them is a guess.
  #
  # The y1/y2 written back by graph_fullyzoom() are printed too: that is the
  # Y-AUTORANGE door, where dataset 0's contribution really does move (the
  # previous dataset's last point is overwritten by the next dataset's reset
  # BEFORE the min/max scan reads it).
  set fixture [file join [file dirname [info script]] data calc_fixture.raw]
  set legs [list \
      {{v(sq) integ()}      0.005 0.01 } \
      {{v(sq) integ()}      0     0.005} \
      {{v(div) 0.003 del()} 0.005 0.01 } \
      {{v(sq) integ()}      0     0.01 } ]
  foreach {gw_e gw_x1 gw_x2} [lindex $legs $::env(DZ_EXPR)] break
  xschem raw clear
  xschem raw_read $fixture
  xschem set rectcolor 2
  xschem rect 0 0 800 400 -1 {flags=graph} 0
  foreach {t v} [list x1 $gw_x1 x2 $gw_x2 y1 -1000 y2 1000 divx 5 divy 5 \
                      dataset -1 sim_type tran] {
    xschem setprop rect 2 0 $t $v
  }
  xschem setprop rect 2 0 node $gw_e
  xschem setprop rect 2 0 fullyzoom
  puts "CHILD gwin y1=[xschem getprop rect 2 0 y1] y2=[xschem getprop rect 2 0 y2]"
  xschem raw clear
  puts "CHILD gwin done"
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
