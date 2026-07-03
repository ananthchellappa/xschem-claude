#
#  File: run_regression.tcl
#
#  This file is part of XSCHEM,
#  a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
#  simulation.
#  Copyright (C) 1998-2023 Stefan Frederik Schippers
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

set tcases [list "create_save" "open_close" "netlisting"]
# Headless (--nogui) xschem-script self-checks: no gold folder needed; each prints
# "ok - ..." per pass and "... : FAIL" per failure and exits nonzero on any failure.
# summarize_all greps FAIL$, so failures are counted like the golden cases.
set hcases [list "hilight_hier_oracle" "hilight_hier_dump_replay" \
                 "hilight_xwin_sync_headless" "buried_hilight"]
set log_fn "results.log"

proc summarize_all {fn fd} {
  puts $fd "$fn"
  set b [catch "open \"$fn\" r" fdread]
  set num_fail 0
  if (!$b) {
    while {[gets $fdread line] >=0} {
      if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
        puts $fd $line
        incr num_fail
      }
    }
    puts $fd "Total num fail: $num_fail"
    close $fdread
  } else {
    puts $fd "Couldn't open $fn to read"
  }
}

source test_utility.tcl  ;# defines $xschem_cmd (used by the headless cases below) + helpers

set a [catch "open \"$log_fn\" w" fd]
if {!$a} {
foreach tc $tcases {
    puts "Start source ${tc}.tcl"
    if {[catch {eval exec {tclsh ${tc}.tcl} > ${tc}_output.txt} msg]} {
      puts "Something seems to have gone wrong with $tc, but we will ignore it: $msg"
    }
    summarize_all ${tc}.log $fd
    puts "Finish source ${tc}.tcl"
  }
  # Headless hilight self-checks driven directly through the built binary (needs xschem to
  # resolve its share dir: installed, or a source-tree run with XSCHEM_SHAREDIR set). Each case
  # prints "... : FAIL" per failed check (counted by summarize_all's FAIL$ grep), exits 0 only on
  # success, and prints a final "OVERALL: ok" sentinel. A pass requires BOTH: exit code 0 AND the
  # sentinel present. The exit code alone is NOT enough -- xschem --nogui --pipe exits 0 on an
  # uncaught MID-SCRIPT Tcl error, so a case that aborts after printing only "ok" lines would
  # otherwise be a hollow pass; the missing sentinel catches it. A startup crash (missing share
  # dir) exits nonzero and also lacks the sentinel. On either miss we synthesize a FAIL line so
  # summarize_all counts the case as failed regardless of log contents.
  foreach hc $hcases {
    puts "Start ${hc}.tcl (headless)"
    set childcode 0
    if {[catch {eval exec {$xschem_cmd --nogui --pipe -q --script ${hc}.tcl} > ${hc}.log 2>@1} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
    }
    set sentinel 0
    if {![catch {open ${hc}.log r} rf]} { set body [read $rf]; close $rf; set sentinel [regexp -line {^OVERALL: ok$} $body] }
    if {$childcode != 0 || !$sentinel} {
      set af [open ${hc}.log a]
      puts $af "HARNESS: ${hc} did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel) -- crashed, aborted mid-script, or a check failed: FAIL"
      close $af
    }
    summarize_all ${hc}.log $fd
    puts "Finish ${hc}.tcl (headless)"
  }
  close $fd
} else {
  puts "Couldn't open $log_fn to write.  Investigate please."
}

exec $xschem_cmd --nogui --pipe -q --script xschemtest.tcl > stefan_xschemtest.log 2>@1
