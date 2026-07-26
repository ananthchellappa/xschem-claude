#
#  File: xschem_test_utility.tcl
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

set OS [lindex $tcl_platform(os) 0]

# Resolve the xschem binary (issue 0147). Priority: $XSCHEM override, then the
# IN-TREE build, then a bare name for an installed copy on PATH. Before this, the
# bare name was the only option, so in an uninstalled dev workarea EVERY case
# died on spawn -- headless cases as a synthesized "did not complete cleanly"
# FAIL, golden cases as thousands of silent `exit 127` sh jobs -- and the suite
# reported a mixture of phantom and hidden results.
# The path MUST be absolute: it is interpolated into /bin/sh job strings that
# `cd` elsewhere first (netlisting.tcl, open_close.tcl, create_save.tcl), so a
# relative one would resolve against the wrong directory. `info script` is this
# file, so the anchor holds no matter where the case was launched from. Mirrors
# tests/headless/full_audit.sh's XSCHEM="${XSCHEM:-$REPO/src/xschem}".
set xschem_cmd "xschem"
if {[info exists env(XSCHEM)] && $env(XSCHEM) ne ""} {
  # Only absolutise something that IS a path. A bare `XSCHEM=xschem` means "find
  # it on PATH"; normalizing that would invent a bogus cwd-relative path and
  # destroy the very fallback it asked for.
  if {[string first / $env(XSCHEM)] >= 0} {
    set xschem_cmd [file normalize $env(XSCHEM)]
  } else {
    set xschem_cmd $env(XSCHEM)
  }
} else {
  set _xs_tree [file normalize \
      [file join [file dirname [file normalize [info script]]] .. src xschem]]
  if {[file executable $_xs_tree]} { set xschem_cmd $_xs_tree }
  unset _xs_tree
}

# ---------------------------------------------------------------------------
# Parallel-dispatch helpers (see doc/claude/suggestions/parallel_regression_tests.md).
#
# The regression cases are thousands of independent, short xschem spawns. We run
# them through a bounded xargs pool instead of a sequential foreach. Each job is a
# self-contained /bin/sh command string so that any `cd` and redirection stays
# isolated to the child process (the Tcl interpreter's cwd is never touched), and
# each job writes only into a private work dir so concurrent writers never collide.
# ---------------------------------------------------------------------------

# Number of parallel jobs: all online CPUs minus 4 (leave headroom for an
# interactive machine), with a hard floor of 1. No user-facing knob by design.
proc test_njobs {} {
  set n 0
  if {![catch {exec nproc} out]} { set n [string trim $out] }
  if {(![string is integer -strict $n] || $n <= 0) && \
      ![catch {exec getconf _NPROCESSORS_ONLN} out]} { set n [string trim $out] }
  if {![string is integer -strict $n] || $n <= 0} { set n 1 }
  set j [expr {$n - 4}]
  if {$j < 1} { set j 1 }
  return $j
}

# Run a list of shell command strings with bounded parallelism.
# Each element of $cmds is an arbitrary /bin/sh command line (it may contain cd,
# redirections, ';', '$?', etc.). NUL-delimiting them lets xargs hand each command
# verbatim to a fresh shell as $0, which `eval "$0"` then executes.
proc run_parallel_cmds {cmds njobs} {
  if {[llength $cmds] == 0} { return }
  set tmp [file join [pwd] .parallel_jobs.[pid]]
  set fd [open $tmp w]
  fconfigure $fd -translation binary
  foreach c $cmds {
    puts -nonewline $fd $c
    puts -nonewline $fd "\x00"
  }
  close $fd
  # xargs exits nonzero if any job did; that's expected (per-job status files carry
  # the real outcome), so swallow it.
  catch {exec xargs -0 -P $njobs -n1 sh -c {eval "$0"} < $tmp 2>@ stderr}
  file delete -force $tmp
}

# Normalize a batch of debug/result files in parallel.
# The original cleanup spawned one awk per file; with thousands of files that serial
# spawn cost dwarfs the (now parallel) xschem work. cleanup_debug_file.awk already
# handles many files in one process (its beginfile/endfile logic writes each FILENAME
# back independently), so we batch files per awk and run batches through the pool.
# Files are disjoint across batches, so parallel awks never touch the same file.
proc cleanup_debug_files {files njobs} {
  if {[llength $files] == 0} { return }
  set tmp [file join [pwd] .cleanup_files.[pid]]
  set fd [open $tmp w]
  fconfigure $fd -translation binary
  foreach f $files {
    puts -nonewline $fd $f
    puts -nonewline $fd "\x00"
  }
  close $fd
  catch {exec xargs -0 -P $njobs -n 64 awk -f cleanup_debug_file.awk < $tmp 2>@ stderr}
  file delete -force $tmp
}

# Read an integer exit status written by a job's `echo $? > status` tail.
# Missing/garbled file => treat as a hard failure (-1).
proc read_job_status {statusfile} {
  if {![file exists $statusfile]} { return -1 }
  set fd [open $statusfile r]
  set s [string trim [read $fd]]
  close $fd
  if {![string is integer -strict $s]} { return -1 }
  return $s
}

# From Glenn Jackman (Stack Overflow answer)
proc comp_file {file1 file2} {
  # optimization: check file size first
  set equal 0
  if {[file size $file1] == [file size $file2]} {
    set fh1 [open $file1 r]
    set fh2 [open $file2 r]
    set equal [string equal [read $fh1] [read $fh2]]
    close $fh1
    close $fh2
  }
  return $equal
}

# Write <testname>.log for summarize_all. ALWAYS writes the log (issue 0147):
# it used to bail silently when <testname>/gold was absent, which discarded
# num_fatals too -- so a case in which every single job failed to even start
# contributed NOTHING to the run's failure count. Now a missing gold dir is
# reported as a non-counting NOGOLD line (absent baseline is a setup state, not a
# regression) while FATALs are always emitted, and summarize_all counts those via
# its ^FATAL pattern.
proc print_results {testname pathlist num_fatals} {

    set a [catch "open \"$testname.log\" w" fd]
    if {$a} {
      puts "Couldn't open $testname.log"
    } else {
     if {[file exists ${testname}/gold]} {
      set i 0
      set num_fail 0
      set num_gold 0
      foreach f $pathlist {
        incr i
        if {![file exists $testname/gold/$f]} {
          puts $fd "$i. $f: GOLD?"
          incr num_gold
          continue
        }
        if {![file exists $testname/results/$f]} {
          puts $fd "$i. $f: RESULT?"
          continue
        }
        if ([comp_file $testname/gold/$f $testname/results/$f]) {
          puts $fd "$i. $f: PASS"
        } else {
          puts $fd "$i. $f: FAIL"
          incr num_fail
        }
      }
      puts $fd "Summary:"
      puts $fd "Num failed: $num_fail      Num missing gold: $num_gold      Num passed: [expr $i-$num_fail-$num_gold]"
     } else {
      # No baseline to compare against: say so IN THE LOG (not just on stdout,
      # where summarize_all can never see it). Deliberately not counted as a
      # failure -- but any FATALs below still are.
      puts $fd "NOGOLD: $testname has no gold/ directory -- [llength $pathlist]\
 result file(s) produced, none verified.  Set results as gold please."
      puts "No gold folder.  Set results as gold please."
     }
      if {$num_fatals} {
        puts $fd "FATAL: $num_fatals.  Please search for FATAL in its output file for more detail"
      }
      close $fd
    }
}

# Edit lines that change each time regression is ran
proc cleanup_debug_file {output} {
  eval exec {awk -f cleanup_debug_file.awk $output}
}
