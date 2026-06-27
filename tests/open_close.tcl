#
#  File: open_close.tcl
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
set testname "open_close"
set pathlist {}
set num_fatals 0

if {![file exists $testname]} {
  file mkdir $testname
}

file delete -force $testname/results
file mkdir $testname/results

set xschem_library_path "../xschem_library"

set cwd [pwd]
set workroot "$testname/results/.work"
file mkdir $workroot

# Job records, in walk order. Each: {fn_debug output_path status cmd}
set jobs {}

# PLAN: walk the library exactly as before and build a self-contained shell
# command per file. The command does its own `cd` (isolated to the child sh) and
# records its exit code, so nothing here mutates the interpreter's cwd.
proc open_close {dir fn} {
  global xschem_library_path testname xschem_cmd cwd workroot jobs
  if { [regexp {\.(sym|sch)$} $fn ] } {
    puts "Testing (open_close) $dir/$fn"
    set output_dir $dir
    regsub -all $xschem_library_path $output_dir {} output_dir
    regsub {^/} $output_dir {} output_dir
    regsub {/} $output_dir {,} output_dir
    set fn_debug [join [list $output_dir , [regsub {\.} $fn {_}] "_debug.txt"] ""]
    set output [join [list $testname / results / $fn_debug] ""]
    set idx [llength $jobs]
    set status "$cwd/$workroot/$idx.status"
    # Private XSCHEM_TMP_DIR per job: xschem creates a temp/undo dir on load whose
    # name comes from rand() seeded with 16-bit time(NULL); same-second sibling
    # processes generate the same name and collide in a shared /tmp. A private parent
    # dir makes that impossible. See doc/claude/suggestions/parallel_regression_tests.md.
    set tmpdir "$cwd/$workroot/$idx.tmp"
    set cmd "mkdir -p '$tmpdir' && cd '$cwd/$dir' && $xschem_cmd '$fn' -q --nogui -r -d 1 --preinit 'set XSCHEM_TMP_DIR {$tmpdir}' 2> '$cwd/$output'; echo \$? > '$status'"
    lappend jobs [list $fn_debug "$cwd/$output" $status $cmd]
  }
}

proc open_close_dir {dir} {
  set ff [lsort [glob -directory $dir -tails \{.*,*\}]]
  foreach f $ff {
    if {$f eq {..} || $f eq {.}} {
      continue
    }
    set fpath "$dir/$f"
    if {[file isdirectory $fpath]} {
      open_close_dir $fpath
    } else {
      open_close $dir $f
    }
  }
}

open_close_dir $xschem_library_path

# EXECUTE: bounded parallel pool, sized to CPUs-4.
set njobs [test_njobs]
puts "Running [llength $jobs] open_close jobs on $njobs parallel workers"
set cmds {}
foreach j $jobs { lappend cmds [lindex $j 3] }
run_parallel_cmds $cmds $njobs

# COLLATE: sequential, in walk order, reproducing the original pass/FATAL logic.
# Defer the awk cleanup into one batched-parallel pass (see cleanup_debug_files).
set cleanlist {}
foreach j $jobs {
  lassign $j fn_debug output status cmd
  set rc [read_job_status $status]
  if {$rc != 0} {
    puts "FATAL: $cmd : exit $rc"
    incr num_fatals
  } else {
    lappend pathlist $fn_debug
    lappend cleanlist $output
  }
}
cleanup_debug_files $cleanlist $njobs
file delete -force $workroot
print_results $testname $pathlist $num_fatals