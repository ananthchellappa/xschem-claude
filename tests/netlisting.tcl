#
#  File: netlisting.tcl
#
#  This file is part of XSCHEM,
#  a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
#  simulation.
#  Copyright (C) 1998-2022 Stefan Frederik Schippers
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

source test_utility.tcl
set testname "netlisting"
set pathlist {}
set num_fatals 0

if {![file exists $testname]} {
  file mkdir $testname
}

# ⚠ PER-RUN RESULTS ROOT (issue 1476, faces 1 and 2) -- see the long note in
# open_close.tcl for what the shared `$testname/results` did to two concurrent
# runs: the startup wipe raises when another run is writing inside the tree, and
# an unguarded raise here kills the case with no banner and no `Total num fail:`
# line at all. The canonical `netlisting/results` name is restored by
# publish_results at the end, so gold promotion is unchanged.
file delete -force $testname/results.[pid]
set resdir "$testname/results.[pid]"
file mkdir $resdir
sweep_dead_run_dirs $testname

set xschem_library_path "../xschem_library"

set cwd [pwd]
# Scratch is per-run AND outside the results tree: pid-scoping it inside was
# measured to change nothing, because results itself was the shared object.
set workroot "$testname/.work.[pid]"
file mkdir $workroot

# Job records, in walk order.
# Each: {fn_debug fn_netlist output workdir status cmd}
set jobs {}

proc netlisting {dir fn} {
  global xschem_library_path testname xschem_cmd
  if { [regexp {\.sch$} $fn ] } {
    puts "Testing ($testname) $dir/$fn"
    set output_dir $dir
    regsub -all $xschem_library_path $output_dir {} output_dir
    regsub {^/} $output_dir {} output_dir
    plan_xschem_netlist vhdl $output_dir $dir $fn
    plan_xschem_netlist v $output_dir $dir $fn
    plan_xschem_netlist tdx $output_dir $dir $fn
    plan_xschem_netlist spice $output_dir $dir $fn
  }
}

proc netlisting_dir {dir} {
  set ff [lsort [glob -directory $dir -tails \{.*,*\}]]
  foreach f $ff {
    if {$f eq {..} || $f eq {.}} {
      continue
    }
    set fpath "$dir/$f"
    if {[file isdirectory $fpath]} {
      netlisting_dir $fpath
    } else {
      netlisting $dir $f
    }
  }
}

# PLAN one netlist job. Each job netlists into its OWN private -o dir so concurrent
# jobs never share an output directory (the library has duplicate .sch basenames,
# and xschem also drops intermediate dotfiles into -o). The finished netlist is
# moved into the shared results dir later, sequentially, in walk order.
proc plan_xschem_netlist {type output_dir dir fn} {
  global testname xschem_cmd cwd workroot resdir jobs
  set fn_debug [join [list $output_dir , [regsub {\.} $fn {_}] "_${type}_debug.txt"] ""]
  regsub {./} $fn_debug {_} fn_debug
  set sch_name [regsub {\.sch} $fn {}]
  set fn_netlist [join [list $sch_name "." $type] ""]
  set output [join [list $cwd / $resdir / $fn_debug] ""]
  set opt s
  if {$type eq "vhdl"} {set opt V}
  if {$type eq "v"} {set opt w}
  if {$type eq "tdx"} {set opt t}
  set idx [llength $jobs]
  set workdir "$cwd/$workroot/$idx.d"
  set status "$cwd/$workroot/$idx.status"
  # Private XSCHEM_TMP_DIR per job: xschem's temp/undo/web dirs are named from a
  # rand() seeded with (16-bit) time(NULL), so processes starting in the same second
  # generate identical names and collide in a shared /tmp -> create_tmpdir aborts
  # (exit 1). A private parent dir makes the collision impossible. We reuse this
  # job's private -o dir; the netlist file we extract has a distinct name.
  set cmd "mkdir -p '$workdir' && cd '$cwd/$dir' && '$xschem_cmd' '$fn' -q --nogui -r -$opt -o '$workdir' -n --preinit 'set XSCHEM_TMP_DIR {$workdir}' 2> '$output'; echo \$? > '$status'"
  lappend jobs [list $fn_debug $fn_netlist $output $workdir $status $cmd]
}

netlisting_dir $xschem_library_path

# EXECUTE: bounded parallel pool, sized to CPUs-4.
set njobs [test_njobs]
puts "Running [llength $jobs] netlisting jobs on $njobs parallel workers"
set cmds {}
foreach j $jobs { lappend cmds [lindex $j 5] }
run_parallel_cmds $cmds $njobs

# COLLATE: sequential, in walk order. Reproduce the original exit-code logic
# (exit 10 = expected netlist error, ignored; other nonzero = FATAL) and move each
# finished netlist into the shared results dir last-writer-wins by walk order.
set results "$cwd/$resdir"
set cleanlist {}
foreach j $jobs {
  lassign $j fn_debug fn_netlist output workdir status cmd
  set rc [read_job_status $status]
  if {$rc != 0 && $rc != 10} {
    puts "FATAL: $cmd : [job_status_reason $rc $status]"
    incr num_fatals
  } else {
    if {[file exists "$workdir/$fn_netlist"]} {
      file rename -force "$workdir/$fn_netlist" "$results/$fn_netlist"
      # ⚠ AND THE NETLIST ITSELF IS NORMALIZED NOW (issue 1476). Only the debug
      # files were ever passed to the awk, so nothing normalized the netlists --
      # and two of them carry an `.include <workroot>/<idx>.d/model_*.txt` line
      # pointing into this job's private scratch. That path is per-run since the
      # workroot moved, so those two files would otherwise differ from their own
      # gold on every run. Measured before adding them: with the current pattern
      # set the awk changes 0 of the 724 netlist files, so this costs nothing
      # anywhere else.
      lappend cleanlist "$results/$fn_netlist"
    }
    lappend pathlist $fn_debug
    lappend pathlist $fn_netlist
    lappend cleanlist $output
  }
}
cleanup_debug_files $cleanlist $njobs
file delete -force $workroot

print_results $testname $pathlist $num_fatals $resdir
publish_results $testname $resdir
