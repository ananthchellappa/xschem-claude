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
                 "hilight_xwin_sync_headless" "buried_hilight" \
                 "headless/test_ciw_interactive_load" \
                 "headless/test_select_inside_argc" \
                 "headless/test_callback_argc" \
                 "headless/test_getprop_index_bounds" \
                 "headless/test_descend_log_absorb" \
                 "headless/test_fluid_editing" \
                 "headless/test_wire_split" \
                 "headless/test_label_strand_oracle" \
                 "headless/test_label_ride" \
                 "headless/test_signal_short_nohier_0230" \
                 "headless/test_sch_add_pin" \
                 "headless/test_add_pin_lib_symbol_view" \
                 "headless/test_add_wire_label" \
                 "headless/test_placement_wire_gate" \
                 "headless/test_crossview_paste" \
                 "headless/test_pin_type_edit" \
                 "headless/test_find_helper" \
                 "headless/test_instance_update" \
                 "headless/test_sky130a_libmgr" \
                 "headless/test_gf180mcud_libmgr" \
                 "headless/test_ihp_sg13g2_libmgr" \
                 "headless/test_pdk_launcher" \
                 "headless/test_ciw_actionlog_output"]
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
      } elseif { [regexp {^NOGOLD} $line] } {
        # Surface "this case verified NOTHING" in the summary without counting it
        # as a regression (issue 0147). Without this, a case with no baseline
        # reports a bare "Total num fail: 0" and reads exactly like a pass.
        puts $fd $line
      }
    }
    puts $fd "Total num fail: $num_fail"
    close $fdread
  } else {
    # Fail CLOSED (issue 0147): print_results now always writes its log, so a
    # missing one means the case died before reporting. This used to be a
    # non-counting note, which is how 2654 dead jobs summarized as zero failures.
    puts $fd "HARNESS: $fn missing -- case produced no log (never ran?): FAIL"
    puts $fd "Total num fail: 1"
  }
}

source test_utility.tcl  ;# defines $xschem_cmd (used by the headless cases below) + helpers

set a [catch "open \"$log_fn\" w" fd]
if {!$a} {
foreach tc $tcases {
    puts "Start source ${tc}.tcl"
    # Drop any previous run's log FIRST (issue 0147): nothing else deletes it, so
    # a stale <case>.log left on disk was re-grepped and its old FAILs replayed as
    # if they were this run's -- and it survives a "reproduce on a clean baseline"
    # recheck, which makes phantom failures look confirmed.
    file delete -force ${tc}.log
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
    if {[catch {exec $xschem_cmd --nogui --pipe -q --script ${hc}.tcl > ${hc}.log 2>@1} msg opt]} {
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
  # xschemtest.tcl: the broad functional/perf harness. GUARDED (issue 0147) --
  # it used to run AFTER results.log was closed and with no catch, so any failure
  # (e.g. an unresolvable binary) aborted the interpreter with a raw Tcl stack
  # trace and never appeared in the summary at all. Now its outcome is recorded.
  puts "Start xschemtest.tcl"
  if {[catch {exec $xschem_cmd --nogui --pipe -q --script xschemtest.tcl \
              > stefan_xschemtest.log 2>@1} msg]} {
    puts $fd "xschemtest.tcl"
    puts $fd "HARNESS: xschemtest.tcl did not run cleanly ($msg): FAIL"
    puts $fd "Total num fail: 1"
    puts "xschemtest.tcl FAILED: $msg"
  }
  puts "Finish xschemtest.tcl"
  close $fd
} else {
  puts "Couldn't open $log_fn to write.  Investigate please."
}
