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
                 "headless/test_ase_preflight" \
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
                 "headless/test_recent_conf_compat_0924" \
                 "headless/test_ase_simreg_0931" \
                 "headless/test_ase_simcaps_0948" \
                 "headless/test_ase_optier_0963" \
                 "headless/test_unused_attr_0970" \
                 "headless/test_auto_specialize_1201" \
                 "headless/test_hash_extra_node_warn_0165" \
                 "headless/test_lib_new_path_guards_0799" \
                 "headless/test_descend_doors_1228" \
                 "headless/test_ase_simdlg_0937" \
                 "headless/test_suite_watchdog_1403" \
                 "headless/test_ase_core" \
                 "headless/test_ase_dialogs" \
                 "headless/test_ase_persist" \
                 "headless/test_ase_options_1437" \
                 "headless/test_ase_predeck_1439" \
                 "headless/test_ase_optsheet_1441" \
                 "headless/test_ase_effective_1442" \
                 "headless/test_ase_meas_1443"]
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
# ⚠ AND THREE ASE SUITES JOINED `hcases` ABOVE IN ISSUE 1413, BECAUSE T1 WAS
# BEING QUOTED FOR COVERAGE IT DID NOT HAVE. Measured before that change: T1 ran
# exactly FOUR `test_ase_*` suites -- simreg_0931, simcaps_0948, optier_0963 and
# simdlg_0937 -- and ran `test_ase_core`, `test_ase_dialogs` and `test_ase_persist`
# on NEITHER arm. Seven commits of the analyses batch were reported as "T1 at
# zero", which was true and which said NOTHING about test_ase_core's 289 checks --
# where the analysis registry, the four-state resolver and the Stop warning all
# live. The suites were run separately every time, so the work was verified; the
# NUMBER was quoted for more than it covered.
#
# ⚠ THEY GO IN `hcases`, NOT HERE. test_ase_dialogs is 37 checks headless against
# 236 on a display and test_ase_persist is 44 against 148 -- the headless arm of
# each is a measurement of a MUCH SMALLER THING, not a weaker measurement of the
# same one (issue 1405 cost 100 checks to that distinction). Putting them in
# `dcases` as well is a bigger change than this one and wants its own measurement
# of what the display arm costs in wall-clock here.
#
# ⚠ `test_ase_optsheet_1441` IS IN BOTH, AND THE MEASUREMENT IS WHY (issue 1441).
# The paragraph above asks for the wall-clock cost before a `test_ase_*` suite
# joins this list; measured 2026-09-13 on the dev display, its display arm is
# **0.40 s** against 0.10 s headless -- 87 checks against 62 (driver-measured
# 2026-09-13; an earlier draft of this comment said 80 against 55). It is the only
# suite in Stage 7 whose subject is a WINDOW (the options sheet: search,
# changed-only, groups, the badge and the live deck preview), so a T1 that ran
# only its headless arm would cover the schema and none of the pixels. That is
# exactly the gap issue 0891 was filed about, at three tenths of a second.
#
# ⚠ `test_ase_effective_1442` IS DELIBERATELY **NOT** HERE, AND THE SAME
# MEASUREMENT IS WHY. Measured 2026-09-13 on both arms: **92 checks headless and
# 92 on the dev display, the same rows.** Its section UI drives two PURE procs
# (`optsheet_stamp` reads an array, `optsheet_where` reads the catalogue) and
# creates no widget, so the display arm is a weaker measurement of the SAME
# thing rather than a bigger one -- which is the half of issue 1405's
# distinction that argues for leaving a suite out. The day it grows a row that
# maps a window, it earns a line here and the counts will say so.
# ⚠ `test_ase_meas_1443` IS NOT HERE EITHER, FOR `test_ase_effective_1442`'s
# REASON AND WITH THE SAME MEASUREMENT. Measured 2026-09-13 on both arms: **100
# checks headless and 100 on the dev display, the same rows.** (This comment said
# 86/86 until the driver re-ran it from a `RESULT:` line at collection time: the
# suite grew after the sentence was written. Take a suite's number from its
# verdict line, never from a paragraph -- twice already in this batch.) Stage 8 task 1 is
# the DECK half -- the `measurements` state list, the refusal evaluator, the
# `meas` speller and the post-processing producers -- and it creates no widget
# at all: the Measurements sub-dialog, the template picker and the Value-column
# rows are Stage 8 task 2. The day that lands it earns a line here, and its
# counts will say so.
set dcases [list "headless/test_op_annot" "headless/test_annot_show_menu" \
                 "headless/test_annot_stale_0684" \
                 "headless/test_annot_blank_cause_0909" \
                 "headless/test_lib_new_path_guards_0799" \
                 "headless/test_ase_simdlg_0937" \
                 "headless/test_ase_optsheet_1441"]
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

## ---------------------------------------------------------------------------
## EVERY CHILD GETS A DEADLINE (issue 1403)
## ---------------------------------------------------------------------------
## This driver had NO timeout on any of its four `exec` sites, so one wedged
## case stopped the whole of T1 for as long as anybody was willing to wait. That
## is not hypothetical: on 2026-09-11 a hand-rolled loop with the same hole sat
## on a hung display-arm suite for EIGHT HOURS AND SEVEN MINUTES
## (doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md). The other
## two drivers have had this all along -- `run_suites.sh` wraps every arm in
## `timeout 200` and `full_audit.sh` in `timeout 300` -- and T1, the one suite
## whose baseline is ZERO, was the one without it.
##
## ⚠ THE DISPLAY ARM IS WHY THE NUMBER IS GENEROUS. `dcases` runs six suites
## under a real X display where a modal dialog can be raised that nothing in a
## `--script` run can click (issue 1375), and a display-arm case is slower than
## its headless twin by a wide margin. 900 s is ~3x full_audit's cap, so it
## bounds a hang without redefining "slow".
##
## ⚠ AND IT SIGNALS THE WHOLE PROCESS GROUP. `timeout` puts the child in its own
## process group and signals the group, so the 16 parallel `xargs` workers that
## `open_close` fans out are reached too -- measured 2026-09-11. Without that a
## kill would orphan them and the next run would inherit the mess.
##
##     T1_CASE_TIMEOUT   seconds per case; 0 disables; unset -> 900
proc t1_timeout {} {
  if {[info exists ::env(T1_CASE_TIMEOUT)]} {
    set v [string trim $::env(T1_CASE_TIMEOUT)]
    if {[string is integer -strict $v] && $v >= 0} { return $v }
  }
  return 900
}
set t1_tmo [t1_timeout]
## The words every child is prefixed with; empty when disabled. --kill-after
## upgrades to SIGKILL for a child that ignores SIGTERM, so "timed out" cannot
## itself become the thing that hangs.
set t1_pre {}
if {$t1_tmo > 0} { set t1_pre [list timeout --kill-after=20 $t1_tmo] }

## ⚠ A TIMEOUT IS A NAMED OUTCOME, NEVER A GAP IN THE LOG. rc 124 is the answer
## "it hung", and it must reach results.log as a counted FAIL that says so --
## otherwise a killed case leaves only whatever it managed to print, which reads
## like a case that merely failed some checks.
proc t1_why {childcode secs} {
  if {$childcode == 124 || $childcode == 137} {
    return "TIMED OUT after ${secs}s and was killed -- nothing after this point ran"
  }
  return "crashed, aborted mid-script, or a check failed"
}

set a [catch "open \"$log_fn\" w" fd]
if {!$a} {
foreach tc $tcases {
    puts "Start source ${tc}.tcl"
    # Drop any previous run's log FIRST (issue 0147): nothing else deletes it, so
    # a stale <case>.log left on disk was re-grepped and its old FAILs replayed as
    # if they were this run's -- and it survives a "reproduce on a clean baseline"
    # recheck, which makes phantom failures look confirmed.
    file delete -force ${tc}.log
    set childcode 0
    set tccmd [concat $t1_pre [list tclsh ${tc}.tcl]]
    if {[catch {eval exec $tccmd > ${tc}_output.txt} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
      puts "Something seems to have gone wrong with $tc, but we will ignore it: $msg"
    }
    ## A kill leaves ${tc}.log as whatever the case had written by then, which
    ## summarize_all would read as an ordinary partial result. Say so instead.
    if {$childcode == 124 || $childcode == 137} {
      set af [open ${tc}.log a]
      puts $af "HARNESS: ${tc} [t1_why $childcode $t1_tmo]: FAIL"
      close $af
      puts "TIMEOUT: ${tc} killed after ${t1_tmo}s"
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
    set hccmd [concat $t1_pre [list $xschem_cmd --nogui --pipe -q --script ${hc}.tcl]]
    if {[catch {eval exec $hccmd > ${hc}.log 2>@1} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
    }
    set body ""
    if {![catch {open ${hc}.log r} rf]} { set body [read $rf]; close $rf }
    set sentinel [banner_complete $body]
    set died     [banner_died $body]
    if {[regression_case_failed $childcode $body]} {
      set af [open ${hc}.log a]
      puts $af "HARNESS: ${hc} did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel, died=$died) -- [t1_why $childcode $t1_tmo]: FAIL"
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
  ## ⚠ AND EVERY CHILD GETS ITS OWN --logdir (issue 1359).  A GUI xschem
  ## launched WITHOUT one writes its action log to /tmp/Xschem.log.N, taking the
  ## lowest free N -- which is exactly where the USER'S OWN interactive sessions
  ## put theirs.  There are ~20 display-arm cases, so one T1 run claimed the
  ## first ~20 slots and overwrote whatever was in them.  MEASURED: a single
  ## solo run destroyed five of the nine /tmp/Xschem.log.* files on this
  ## machine, and a later one destroyed the log the whole RDW batch had been
  ## diagnosed from.  The --nogui arms are safe -- a headless run with no
  ## --logdir creates no log at all (test_action_log.sh case 4) -- so it is
  ## ONLY this arm, and this is the only line that has to change.
  ##
  ## Under the results directory rather than a temp dir, because a display-arm
  ## case that WANTS its action log (there are such cases) can then read it,
  ## and because a stray log left behind is a test artifact where a reader
  ## expects test artifacts.
  set dlogdir [file join [pwd] results .actionlogs]
  file mkdir $dlogdir
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
    ## ⚠ THE TIMEOUT GOES INSIDE devdisplay.sh's exec, NOT AROUND IT.
    ## `devdisplay.sh exec` runs the command as an ordinary child and stays its
    ## parent, so a `timeout` wrapped around the SCRIPT would signal the shell
    ## and leave xschem orphaned on :99. Prefixed here, `timeout` is xschem's
    ## own direct parent and its process group is the one that gets signalled.
    ## ⚠ ON ONE LINE, AND THAT IS LOAD-BEARING. Row V57 of test_op_annot.tcl
    ## isolates the single line in this loop that names $xschem_cmd and demands
    ## the devdisplay routing be on THAT line -- because issue 0894 measured that
    ## a grep over the whole loop answers 1 even with the routing stripped out
    ## entirely (the liveness var is $dd_alive and the NODISPLAY prose contains
    ## the words "devdisplay.sh start"). Splitting this across a continuation
    ## reddened V57 on both arms in T1; do not re-wrap it.
    set dccmd [concat [list $dd exec] $t1_pre [list $xschem_cmd --pipe -q --logdir $dlogdir --script ${dc}.tcl]]
    if {[catch {eval exec $dccmd > ${dc}.disp.log 2>@1} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
    }
    set body ""
    if {![catch {open ${dc}.disp.log r} rf]} { set body [read $rf]; close $rf }
    set sentinel [banner_complete $body]
    set died     [banner_died $body]
    if {[regression_case_failed $childcode $body]} {
      set af [open ${dc}.disp.log a]
      puts $af "HARNESS: ${dc} (display arm) did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel, died=$died) -- [t1_why $childcode $t1_tmo]: FAIL"
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
  set xtcmd [concat $t1_pre [list $xschem_cmd --nogui --pipe -q --script xschemtest.tcl]]
  if {[catch {eval exec $xtcmd > stefan_xschemtest.log 2>@1} msg]} {
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
