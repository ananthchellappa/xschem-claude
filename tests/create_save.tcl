#
#  File: create_save.tcl
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
set testname "create_save"
set pathlist {}
set num_fatals 0

# ⚠ PER-RUN RESULTS ROOT (issue 1476, faces 1 and 2) -- see the long note in
# open_close.tcl for what the shared `$testname/results` did to two concurrent
# runs: the startup wipe raises when another run is writing inside the tree, and
# an unguarded raise here kills the case with no banner and no `Total num fail:`
# line at all. The canonical `create_save/results` name is restored by
# publish_results at the end, so gold promotion is unchanged.
file delete -force $testname/results.[pid]
set resdir "$testname/results.[pid]"
file mkdir $resdir
sweep_dead_run_dirs $testname

set cwd [pwd]
# Scratch is per-run AND outside the results tree: pid-scoping it inside was
# measured to change nothing, because results itself was the shared object.
set workroot "$testname/.work.[pid]"
file mkdir $workroot

# Job records, in walk order. Each: {output fn_sch status cmd}
# (output/fn_sch are paths relative to results_dir, for cleanup + pathlist)
set jobs {}

# PLAN: write each seed .sch (cheap, sequential) and build the xschem command.
# These jobs use distinct file names and no `cd`, so they're trivially parallel-safe.
proc create_save_plan {} {
  global testname xschem_cmd cwd workroot resdir jobs
  set results_dir $resdir
  if {[file exists ${testname}/tests]} {
    set ff [lsort [glob -directory ${testname}/tests -tails \{.*,*\}]]
    foreach f $ff {
      if {$f eq {..} || $f eq {.}} {continue}
      if {[regexp {\.(tcl)$} $f ]} {
        set fn_sch [regsub {tcl$} $f {sch}]
        set a [catch "open \"$results_dir/$fn_sch\" w" fd]
        if {!$a} {
          puts $fd "v {xschem version=2.9.5 file_version=1.1}"
          puts $fd "G {}"
          puts $fd "V {}"
          puts $fd "S {}"
          puts $fd "E {}"
          close $fd
          set filename [regsub {\.tcl$} $f {}]
          set output ${filename}_debug.txt
          set idx [llength $jobs]
          set status "$cwd/$workroot/$idx.status"
          # Private XSCHEM_TMP_DIR per job (see open_close.tcl / the design note in
          # doc/claude/suggestions/parallel_regression_tests.md) to avoid same-second tmp-dir
          # name collisions between sibling xschem processes.
          set tmpdir "$cwd/$workroot/$idx.tmp"
          set cmd "mkdir -p '$tmpdir' && '$xschem_cmd' '$cwd/$results_dir/$fn_sch' --nogui --pipe -d 1 --script '$cwd/$testname/tests/$f' --preinit 'set XSCHEM_TMP_DIR {$tmpdir}' 2> '$cwd/$results_dir/$output'; echo \$? > '$status'"
          lappend jobs [list $output $fn_sch $status $cmd]
        }
      }
    }
  }
}

create_save_plan

# EXECUTE: bounded parallel pool, sized to CPUs-4.
set njobs [test_njobs]
puts "Running [llength $jobs] create_save jobs on $njobs parallel workers"
set cmds {}
foreach j $jobs { lappend cmds [lindex $j 3] }
run_parallel_cmds $cmds $njobs

# COLLATE: sequential, in walk order, reproducing the original pass/FATAL logic.
set results_dir $resdir
set cleanlist {}
foreach j $jobs {
  lassign $j output fn_sch status cmd
  set rc [read_job_status $status]
  if {$rc != 0} {
    puts "FATAL: $cmd : [job_status_reason $rc $status]"
    incr num_fatals
  } else {
    lappend pathlist $output
    lappend pathlist [regsub {_debug.txt$} $output {}].sch
    lappend cleanlist ${results_dir}/$output
    lappend cleanlist ${results_dir}/$fn_sch
  }
}
cleanup_debug_files $cleanlist $njobs
file delete -force $workroot
print_results $testname $pathlist $num_fatals $resdir
publish_results $testname $resdir