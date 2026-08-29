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
                 "headless/test_shape_draw_gate" \
                 "headless/test_crossview_paste" \
                 "headless/test_paste_modify_flag_0244" \
                 "headless/test_pin_type_edit" \
                 "headless/test_find_helper" \
                 "headless/test_instance_update" \
                 "headless/test_sky130a_libmgr" \
                 "headless/test_gf180mcud_libmgr" \
                 "headless/test_ihp_sg13g2_libmgr" \
                 "headless/test_pdk_launcher" \
                 "headless/test_ciw_actionlog_output" \
                 "headless/test_zero_point_raw_0836" \
                 "headless/test_zero_point_pos_at_0852" \
                 "headless/test_op_annot" \
                 "headless/test_backannotate_digital" \
                 "headless/test_results_freshness" \
                 "headless/test_annot_stale_0684" \
                 "headless/test_annot_blank_cause_0909" \
                 "headless/test_annot_hier_0911" \
                 "headless/test_spice_get_node_0861" \
                 "headless/test_recent_conf_compat_0924"]
# ISSUE 0891 -- THE SAME SUITE, RUN AGAIN ON A REAL DISPLAY, BECAUSE THE ARM THE
# USER HAS IS NOT THE ARM THIS RUNNER WAS RUNNING.
#
# A reader would otherwise assume the hcases loop above covers these suites. It
# does not: it hard-codes --nogui, where there is no Tk at all, so every product
# guard of the form "is the waveform window still alive" is unreachable and every
# row that depends on one passes for the wrong reason. Measured: test_op_annot
# was "RESULT: ALL PASS (447 checks)" headless and "RESULT: 2 FAILED" on the dev
# display, on the same binary, for a whole feature -- and the two red rows were
# the acceptance rows of the issue that feature closed. A suite whose subject is
# a WINDOW gets a second run where windows exist.
#
# These run on the PERSISTENT DEV DISPLAY (tests/headless/devdisplay.sh, :99,
# Xvfb + a window manager), never on the invoking $DISPLAY -- that is the human's
# real screen and flooding it is the thing devdisplay.sh exists to stop.
# devdisplay.sh's own `exec` sets GUI_GATE=0 for the child only, so the user's
# Pause/Stop panel is left alone.
set dcases [list "headless/test_op_annot" "headless/test_annot_show_menu" \
                 "headless/test_annot_stale_0684" \
                 "headless/test_annot_blank_cause_0909"]
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
      } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
        # Surface "this case verified NOTHING" in the summary without counting it
        # as a regression (issue 0147). Without this, a case with no baseline
        # reports a bare "Total num fail: 0" and reads exactly like a pass.
        #
        # NODISPLAY is issue 0891's own instance of the same rule: a box with no
        # dev display cannot run the display arm, and turning that into a red
        # would make every headless CI box fail. Turning it into SILENCE is what
        # 0891 actually was, so it is printed, loudly, and not counted.
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
source banner_rule.tcl   ;# banner_complete / banner_died / regression_case_failed (issue 0689)

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
  # Headless self-checks driven directly through the built binary (needs xschem to resolve its
  # share dir: installed, or a source-tree run with XSCHEM_SHAREDIR set). Each case prints
  # "... : FAIL" per failed check (counted by summarize_all's FAIL$ grep) and ends with a
  # completion banner.
  #
  # THE CONTRACT (issue 0689, and the rule itself lives in banner_rule.tcl so the three readers
  # cannot drift): a case passes only if ALL THREE hold --
  #   1. exit code 0                       -- a startup crash (missing share dir) exits nonzero;
  #                                           a binary that never launched raises a
  #                                           non-CHILDSTATUS error and lands here as 1.
  #   2. a whole-line completion banner    -- tolerating the "(N checks)" trailer that seven
  #                                           suites in this tree append. The OLD predicate here
  #                                           was anchored at both ends and scored those a
  #                                           HARNESS failure while every check passed; that
  #                                           false red was filed four times before it was fixed.
  #   3. no column-0 death marker          -- and THIS is the half that was missing. The exit
  #                                           code alone is NOT enough: xschem --nogui --pipe
  #                                           exits 0 on an uncaught MID-SCRIPT Tcl error. The
  #                                           banner alone is NOT enough either, which the old
  #                                           comment here wrongly claimed -- a case that printed
  #                                           a bare banner and THEN died satisfied it and was
  #                                           scored a silent pass. summarize_all never saw that
  #                                           death line either (it neither ends in FAIL nor
  #                                           starts with FATAL).
  # On any miss we synthesize a FAIL line so summarize_all counts the case as failed regardless
  # of log contents, and the line names which of the three conditions gave way.
  foreach hc $hcases {
    puts "Start ${hc}.tcl (headless)"
    set childcode 0
    if {[catch {exec $xschem_cmd --nogui --pipe -q --script ${hc}.tcl > ${hc}.log 2>@1} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
    }
    set body ""
    if {![catch {open ${hc}.log r} rf]} { set body [read $rf]; close $rf }
    set sentinel [banner_complete $body]
    set died     [banner_died $body]
    if {[regression_case_failed $childcode $body]} {
      set af [open ${hc}.log a]
      puts $af "HARNESS: ${hc} did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel, died=$died) -- crashed, aborted mid-script, or a check failed: FAIL"
      close $af
    }
    summarize_all ${hc}.log $fd
    puts "Finish ${hc}.tcl (headless)"
  }
  # ISSUE 0891 -- THE DISPLAY ARM. Same three-condition verdict as the headless
  # loop above and the same banner rule out of banner_rule.tcl (never a private
  # predicate: test_audit_classifier.tcl section K locks the three readers
  # together). The ONE difference is the arm: no --nogui, and the child is
  # launched through devdisplay.sh so it lands on :99 and not on the human's
  # screen. Row V57 of tests/headless/test_op_annot.tcl asserts that this loop
  # exists, routes through devdisplay.sh and does NOT pass --nogui -- because a
  # restored arm that nothing notices the removal of is the trap 0891 already
  # sprang once.
  set dd [file join headless devdisplay.sh]
  catch {exec $dd start 2>@1}
  set dd_st {}
  catch {exec $dd status 2>@1} dd_st
  set dd_alive [expr {[string match {*state:*alive*} $dd_st] ? 1 : 0}]
  foreach dc $dcases {
    puts "Start ${dc}.tcl (display arm)"
    file delete -force ${dc}.disp.log
    if {!$dd_alive} {
      puts $fd "${dc}.disp.log"
      puts $fd "NODISPLAY: ${dc} display arm NOT RUN -- the persistent dev display is not up, so THIS ARM VERIFIED NOTHING. Start it with tests/headless/devdisplay.sh start and run again."
      puts $fd "Total num fail: 0"
      puts "NODISPLAY: ${dc} display arm NOT RUN -- this arm verified NOTHING"
      continue
    }
    set childcode 0
    if {[catch {exec $dd exec $xschem_cmd --pipe -q --script ${dc}.tcl > ${dc}.disp.log 2>@1} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
    }
    set body ""
    if {![catch {open ${dc}.disp.log r} rf]} { set body [read $rf]; close $rf }
    set sentinel [banner_complete $body]
    set died     [banner_died $body]
    if {[regression_case_failed $childcode $body]} {
      set af [open ${dc}.disp.log a]
      puts $af "HARNESS: ${dc} (display arm) did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel, died=$died) -- crashed, aborted mid-script, or a check failed: FAIL"
      close $af
    }
    summarize_all ${dc}.disp.log $fd
    puts "Finish ${dc}.tcl (display arm)"
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
