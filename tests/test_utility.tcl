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
#
# ⚠ AND ONE MISSING FILE USED TO COST ITS WHOLE BATCH, SILENTLY (issue 1476,
# face 3). gawk's "cannot open file" is a FATAL, not a warning: it aborts the awk
# process, so the up-to-63 files batched WITH the missing one are left
# un-normalized too -- cleanup_debug_file.awk writes a file back from endfile(),
# and END{endfile()} is the only thing that flushes the last file of a batch.
# Then `catch {exec ...}` with no result variable discarded the message as well,
# so the caller was told nothing at all. Reproducible in two awk spawns with no
# concurrency whatever (test_regression_concurrency_1476.tcl section C).
# Absent files are now dropped BEFORE batching -- a file that vanished costs only
# itself -- and whatever went wrong is both printed and RETURNED to the caller.
proc cleanup_debug_files {files njobs} {
  if {[llength $files] == 0} { return {} }
  set present {}
  set missing {}
  foreach f $files {
    if {[file exists $f]} { lappend present $f } else { lappend missing $f }
  }
  # ⚠ AND DEDUPED, because the batches must stay disjoint: two parallel awks
  # rewriting one file at once is a corrupted file, and that invariant is the
  # only reason this may be run in parallel at all. netlisting's last-writer-wins
  # rename can put one published netlist path in the list twice (the library has
  # duplicate .sch basenames).
  set present [lsort -unique $present]
  set problems {}
  if {[llength $missing]} {
    set m "cleanup_debug_files: [llength $missing] result file(s) gone before\
 normalization (first: [lindex $missing 0]) -- another run in this tree is the\
 usual cause (issue 1476)"
    lappend problems $m
    puts "FATAL: $m"
  }
  if {[llength $present]} {
    set tmp [file join [pwd] .cleanup_files.[pid]]
    set fd [open $tmp w]
    fconfigure $fd -translation binary
    foreach f $present {
      puts -nonewline $fd $f
      puts -nonewline $fd "\x00"
    }
    close $fd
    if {[catch {exec xargs -0 -P $njobs -n 64 awk -f cleanup_debug_file.awk \
                     < $tmp 2>@ stderr} err]} {
      set e [string trim $err]
      if {$e eq {}} { set e "awk exited nonzero" }
      lappend problems "cleanup_debug_files: $e"
      puts "FATAL: cleanup_debug_files: $e -- result files may be un-normalized"
    }
    file delete -force $tmp
  }
  return $problems
}

# ---------------------------------------------------------------------------
# Job status: the two ways a status can fail to BE a status (issue 1476).
#
# `echo $?` writes 0..255, so neither sentinel can collide with a code a job
# really wrote -- which is the entire point of them. Both used to be -1 and the
# three callers printed `FATAL: <cmd> : exit -1`: a phantom failure of a job that
# had run perfectly, wearing the exact shape of a real crash. 656 of them in one
# measured collision, and `exit -1` is not a code any xschem process writes --
# that tell is what identified the defect in the first place.
#
# A MISSING status file means somebody deleted it (the other run in this tree);
# a GARBLED one means the job wrote nonsense. Different defects, different words.
set JOB_STATUS_MISSING -1001
set JOB_STATUS_GARBLED -1002

# Read an integer exit status written by a job's `echo $? > status` tail.
proc read_job_status {statusfile} {
  if {![file exists $statusfile]} { return $::JOB_STATUS_MISSING }
  # The file can vanish between the test and the open -- that race IS the defect.
  if {[catch {open $statusfile r} fd]} { return $::JOB_STATUS_MISSING }
  set s [string trim [read $fd]]
  close $fd
  if {![string is integer -strict $s]} { return $::JOB_STATUS_GARBLED }
  return $s
}

# The FATAL detail line for a status that is not a clean exit.
# ⚠ A REAL exit code is still reported exactly as it always was -- `exit 139` --
# so a genuine crash keeps the shape every reader, grep and habit in this tree
# already knows. Only the two not-a-status cases get their own words.
proc job_status_reason {rc statusfile} {
  if {$rc == $::JOB_STATUS_MISSING} {
    return "NO STATUS FILE ($statusfile) -- this job's exit code was never\
 written or was deleted by another run in this tree (issue 1476); the job itself\
 may well have succeeded"
  }
  if {$rc == $::JOB_STATUS_GARBLED} {
    return "UNREADABLE STATUS FILE ($statusfile) -- its contents are not an exit\
 code, so this job's real outcome is unknown"
  }
  return "exit $rc"
}

# ---------------------------------------------------------------------------
# Per-run LOG names (issue 1478; ruling R1 as re-decided 2026-09-17)
# ---------------------------------------------------------------------------
# A full T1 run writes 88 fixed-name files under tests/, of which 83 are verdict
# INPUTS -- the driver reads each case's log back and scores it. Two runs in one
# tree therefore scored each other's bodies, and the verdict lock protected
# exactly ONE of the 88. Measured 2026-09-17 on a forced collision, using this
# tree's own banner_rule.tcl as the scorer, wrong in BOTH directions: run A's two
# real failures silently counted as ZERO, and a phantom failure charged to the
# run that passed.
#
# ⚠ THE TAG IS THE DRIVER'S PID AND IT TRAVELS IN THE ENVIRONMENT, which looks
# indirect until you notice who writes this file: print_results runs in the
# CASE's process (`tclsh open_close.tcl`), not the driver's, so the two cannot
# both reach for `[pid]` and get the same answer. run_regression.tcl sets
# T1_LOG_TAG to its own pid; both sides then spell the name with this one proc,
# so they cannot drift.
#
# ⚠ AND AN UNSET TAG MEANS THE OLD NAME, DELIBERATELY. `cd tests && tclsh
# open_close.tcl` is the documented way to run one case by hand (CLAUDE.md says
# so), and it must go on producing `open_close.log` -- a private name for a solo
# run would be a new thing to learn for no benefit.
proc t1_log_tag {} {
  if {[info exists ::env(T1_LOG_TAG)]} {
    set v [string trim $::env(T1_LOG_TAG)]
    if {[string is integer -strict $v] && $v > 0} { return $v }
  }
  return {}
}

# "$stem$suffix" solo, "$stem.<tag>$suffix" under a driver. The suffix is passed
# rather than assumed because the four shapes differ: `.log`, `.disp.log` and
# `_output.txt` are not one extension with one spelling.
proc t1_run_file {stem suffix} {
  set t [t1_log_tag]
  if {$t eq {}} { return "$stem$suffix" }
  return "$stem.$t$suffix"
}

# ---------------------------------------------------------------------------
# Per-run results roots (issue 1476, faces 1 and 2)
# ---------------------------------------------------------------------------
# Each case works in <case>/results.<pid> and publishes it under the canonical
# <case>/results name when the verdict is already computed. Two helpers support
# that; the wipe and the workroot themselves stay in the case files, where a
# reader looking for "what does this case destroy at startup" will find them.

# Restore the canonical <case>/results name from this run's private root.
# `<case>/results/` is the name CLAUDE.md documents, the name a gold baseline is
# promoted FROM, and the name a human looks in. Last run wins -- exactly what a
# second SEQUENTIAL run has always done to this directory.
#
# It runs AFTER print_results has computed the verdict from the private root, so
# nothing here can change a result. A failure is therefore a warning and never a
# death: the files simply stay under their per-run name, which the message says.
proc publish_results {testname resdir} {
  set canon $testname/results
  if {$resdir eq $canon || ![file isdirectory $resdir]} { return 0 }
  if {[catch {
        file delete -force $canon
        file rename -force $resdir $canon
      } e]} {
    puts "WARNING: could not publish $resdir as $canon ($e) -- this run's result\
 files are in $resdir"
    return 0
  }
  return 1
}

# Remove per-run roots left behind by runs that are no longer alive.
# Before per-run roots a killed run's mess was cleaned by the NEXT run's wipe of
# the shared `results`; per-run roots would otherwise accumulate one directory
# per killed run for ever, and open_close's is 1898 files. T1 kills cases for
# real (issue 1403's 900 s per-case timeout), so this is not hypothetical.
#
# The canonical `results` can never match -- it has no `.<pid>` suffix -- and a
# pid that is still alive is left alone even if it is not a regression run: the
# failure direction here must always be "a leftover survives", never "a live
# run's tree is deleted". Where pid liveness cannot be established (no /proc,
# i.e. not Linux) nothing is swept at all.
proc sweep_dead_run_dirs {testname} {
  if {![file isdirectory /proc/[pid]]} { return {} }
  set swept {}
  foreach d [glob -nocomplain -directory $testname -types d -- results.* .work.*] {
    if {![regexp {\.([0-9]+)$} [file tail $d] -> p]} { continue }
    if {$p == [pid] || [file exists /proc/$p]} { continue }
    if {![catch {file delete -force $d}]} { lappend swept [file tail $d] }
  }
  if {[llength $swept]} {
    puts "swept [llength $swept] dead per-run dir(s) under $testname: $swept"
  }
  return $swept
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
# $resdir is this run's results root; it defaults to the canonical
# <case>/results for any caller that has not got one (issue 1476 made the three
# regression cases work in <case>/results.<pid> and publish afterwards, so the
# comparison has to be told where the files it is judging actually are).
proc print_results {testname pathlist num_fatals {resdir {}}} {
    if {$resdir eq {}} { set resdir $testname/results }

    ## ⚠ PER-RUN NAME (issue 1478). This log is a VERDICT INPUT -- the driver
    ## reads it back and counts the lines in it -- and it used to be one fixed
    ## slot per case NAME rather than per RUN, so a second run in the tree
    ## overwrote it between this case exiting and the driver summarizing it.
    ## The driver publishes it back to `$testname.log` afterwards, so every
    ## reader's spelling survives.
    set logname [t1_run_file $testname .log]
    set a [catch "open \"$logname\" w" fd]
    if {$a} {
      puts "Couldn't open $logname"
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
        if {![file exists $resdir/$f]} {
          puts $fd "$i. $f: RESULT?"
          continue
        }
        if ([comp_file $testname/gold/$f $resdir/$f]) {
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
